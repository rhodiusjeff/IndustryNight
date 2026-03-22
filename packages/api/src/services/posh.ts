import { query, queryOne } from '../config/database';
import { sendSms } from './sms';
import { sendEmail } from './email';

function digitsOnly(value: string): string {
  return value.replace(/\D/g, '');
}

async function tryImmediateReconcile(
  poshOrderId: string,
  eventId: string | null,
  accountPhone: string | undefined,
  orderNumber: string,
  total: number,
  purchasedAt: string | null,
): Promise<void> {
  if (!accountPhone) return;

  const fullDigits = digitsOnly(accountPhone);
  const localDigits = fullDigits.length > 10 ? fullDigits.slice(-10) : fullDigits;

  const user = await queryOne<{ id: string }>(
    `SELECT id FROM users
     WHERE phone IS NOT NULL
       AND (
         regexp_replace(phone, '[^0-9]', '', 'g') = $1
         OR regexp_replace(phone, '[^0-9]', '', 'g') = $2
         OR regexp_replace(phone, '[^0-9]', '', 'g') = ('1' || $2)
       )
     LIMIT 1`,
    [fullDigits, localDigits]
  );

  if (!user) return;

  await query(
    'UPDATE posh_orders SET user_id = $1 WHERE id = $2',
    [user.id, poshOrderId]
  );

  if (!eventId) return;

  await query(
    `INSERT INTO tickets (user_id, event_id, posh_order_id, ticket_type, price, status, purchased_at)
     SELECT $1, $2, $3, 'Posh', COALESCE($4::numeric, 0), 'purchased', COALESCE($5::timestamptz, NOW())
     WHERE NOT EXISTS (
       SELECT 1
       FROM tickets t
       WHERE t.event_id = $2
         AND t.user_id = $1
         AND t.status NOT IN ('cancelled', 'refunded')
     )`,
    [user.id, eventId, orderNumber, total, purchasedAt ? new Date(purchasedAt) : null]
  );
}

// ────────────────────────────────────────────────────────────
// Posh webhook payload types (based on actual Posh webhook format)
// ────────────────────────────────────────────────────────────

interface PoshItem {
  item_id: string;
  name: string;
  price: number;
}

interface PoshNewOrderPayload {
  type: 'new_order';
  account_first_name: string;
  account_last_name: string;
  account_email?: string;
  account_phone?: string;
  items: PoshItem[];
  date_purchased: string;
  order_number: number;
  promo_code?: string;
  subtotal: number;
  total: number;
  event_name: string;
  event_start: string;
  event_end: string;
  event_id: string;
  tracking_link?: string;
}

type PoshWebhookPayload =
  | PoshNewOrderPayload
  | { type: string; [key: string]: unknown };

// ────────────────────────────────────────────────────────────
// Entry point called from the webhook route
// ────────────────────────────────────────────────────────────

export async function processPoshWebhook(payload: PoshWebhookPayload): Promise<void> {
  console.log('Processing Posh webhook:', payload.type);

  switch (payload.type) {
    case 'new_order':
      await handleNewOrder(payload as PoshNewOrderPayload);
      break;
    default:
      console.log('Unhandled Posh webhook type:', payload.type);
  }
}

// ────────────────────────────────────────────────────────────
// new_order handler
// ────────────────────────────────────────────────────────────

async function handleNewOrder(data: PoshNewOrderPayload): Promise<void> {
  const orderNumberStr = String(data.order_number);

  // Find the matching IN event by Posh event ID (may not exist yet if admin
  // hasn't linked it — we still store the order and can reconcile later)
  const event = await queryOne<{ id: string; name: string }>(
    'SELECT id, name FROM events WHERE posh_event_id = $1',
    [data.event_id]
  );

  if (!event) {
    console.log('No IN event found for Posh event ID:', data.event_id, '— storing order for later reconciliation');
  }

  // Upsert posh_order — idempotent on order_number so retries are safe
  const inserted = await queryOne<{ id: string; invite_sent_at: string | null }>(
    `INSERT INTO posh_orders (
       posh_event_id, order_number, event_id,
       account_first_name, account_last_name, account_email, account_phone,
       items, subtotal, total, promo_code, date_purchased, raw_payload
     ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)
     ON CONFLICT (order_number) DO NOTHING
     RETURNING id, invite_sent_at`,
    [
      data.event_id,
      orderNumberStr,
      event?.id ?? null,
      data.account_first_name,
      data.account_last_name,
      data.account_email ?? null,
      data.account_phone ?? null,
      JSON.stringify(data.items),
      data.subtotal,
      data.total,
      data.promo_code ?? null,
      data.date_purchased ? new Date(data.date_purchased) : null,
      JSON.stringify(data),
    ]
  );

  if (!inserted) {
    // ON CONFLICT DO NOTHING — duplicate order, already processed
    console.log('Duplicate Posh order, skipping:', orderNumberStr);
    return;
  }

  // Reconcile immediately when the buyer already exists in the app.
  // If no user is found, verify-code flow will reconcile later.
  await tryImmediateReconcile(
    inserted.id,
    event?.id ?? null,
    data.account_phone,
    orderNumberStr,
    data.total,
    data.date_purchased,
  );

  // Send invite to buyer so they can download the app and set up their profile
  const firstName = data.account_first_name || 'there';
  const eventName = event?.name ?? data.event_name;

  const smsSent = await trySendInviteSms(data.account_phone, firstName, eventName);
  const emailSent = await trySendInviteEmail(data.account_email, firstName, eventName);

  if (smsSent || emailSent) {
    await query(
      'UPDATE posh_orders SET invite_sent_at = NOW() WHERE id = $1',
      [inserted.id]
    );
  }
}

// ────────────────────────────────────────────────────────────
// Invite helpers — both gracefully no-op if contact info missing
// ────────────────────────────────────────────────────────────

async function trySendInviteSms(
  phone: string | undefined,
  firstName: string,
  eventName: string
): Promise<boolean> {
  if (!phone) return false;
  try {
    const message =
      `Hey ${firstName}! You've got tickets to ${eventName}. ` +
      `Download the Industry Night app to connect with other creatives and check in at the door: ` +
      `https://industrynight.net/download`;
    await sendSms(phone, message);
    return true;
  } catch (err) {
    console.error('Failed to send invite SMS:', err);
    return false;
  }
}

async function trySendInviteEmail(
  email: string | undefined,
  firstName: string,
  eventName: string
): Promise<boolean> {
  if (!email) return false;
  try {
    await sendEmail({
      to: email,
      subject: `You're going to ${eventName} — get the Industry Night app`,
      html: `
        <h2>Hey ${firstName}!</h2>
        <p>Your ticket to <strong>${eventName}</strong> is confirmed.</p>
        <p>Download the <strong>Industry Night</strong> app to connect with other creatives,
           unlock exclusive perks, and check in at the door.</p>
        <p>
          <a href="https://industrynight.net/download"
             style="background:#7c3aed;color:#fff;padding:12px 24px;border-radius:6px;text-decoration:none;display:inline-block;">
            Get the App
          </a>
        </p>
        <p style="color:#888;font-size:12px;">
          You received this because you purchased a ticket on Posh.
        </p>
      `,
      text:
        `Hey ${firstName}! Your ticket to ${eventName} is confirmed. ` +
        `Download the Industry Night app at https://industrynight.net/download ` +
        `to connect with other creatives and check in at the door.`,
    });
    return true;
  } catch (err) {
    console.error('Failed to send invite email:', err);
    return false;
  }
}
