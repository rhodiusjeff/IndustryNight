import { query, queryOne, transaction } from '../config/database';

interface PoshTicketPurchase {
  event_id: string;
  order_id: string;
  ticket_id: string;
  ticket_type: string;
  price: number;
  buyer: {
    phone: string;
    email?: string;
    name?: string;
  };
}

interface PoshWebhookPayload {
  type: 'ticket.purchased' | 'ticket.refunded' | 'ticket.transferred';
  data: PoshTicketPurchase;
}

export async function processPoshWebhook(payload: PoshWebhookPayload): Promise<void> {
  console.log('Processing Posh webhook:', payload.type);

  switch (payload.type) {
    case 'ticket.purchased':
      await handleTicketPurchase(payload.data);
      break;
    case 'ticket.refunded':
      await handleTicketRefund(payload.data);
      break;
    case 'ticket.transferred':
      // Handle ticket transfer if needed
      break;
    default:
      console.log('Unknown webhook type:', payload.type);
  }
}

async function handleTicketPurchase(data: PoshTicketPurchase): Promise<void> {
  await transaction(async ({ query: txQuery }) => {
    // Normalize phone number
    const phone = normalizePhone(data.buyer.phone);

    // Find or create user
    let user = await queryOne<{ id: string }>(
      'SELECT id FROM users WHERE phone = $1',
      [phone]
    );

    if (!user) {
      // Create new user from Posh
      const result = await txQuery<{ id: string }>(
        `INSERT INTO users (phone, email, name, source)
         VALUES ($1, $2, $3, 'posh')
         RETURNING id`,
        [phone, data.buyer.email, data.buyer.name]
      );
      user = result[0];
    }

    // Find event by Posh ID
    const event = await queryOne<{ id: string }>(
      'SELECT id FROM events WHERE posh_event_id = $1',
      [data.event_id]
    );

    if (!event) {
      console.log('Event not found for Posh event ID:', data.event_id);
      return;
    }

    // Create ticket
    await txQuery(
      `INSERT INTO tickets (user_id, event_id, posh_ticket_id, posh_order_id, ticket_type, price, status, purchased_at)
       VALUES ($1, $2, $3, $4, $5, $6, 'purchased', NOW())
       ON CONFLICT (posh_ticket_id) DO NOTHING`,
      [user.id, event.id, data.ticket_id, data.order_id, data.ticket_type, data.price]
    );
  });
}

async function handleTicketRefund(data: PoshTicketPurchase): Promise<void> {
  await query(
    `UPDATE tickets SET status = 'refunded' WHERE posh_ticket_id = $1`,
    [data.ticket_id]
  );
}

function normalizePhone(phone: string): string {
  const digitsOnly = phone.replace(/\D/g, '');
  if (digitsOnly.length === 10) {
    return `+1${digitsOnly}`;
  }
  if (digitsOnly.length === 11 && digitsOnly.startsWith('1')) {
    return `+${digitsOnly}`;
  }
  return `+${digitsOnly}`;
}
