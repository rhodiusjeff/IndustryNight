# Milestone: Posh RSVP to Check-in E2E

Date: 2026-03-17
Status: Achieved in dev

## Why This Is a Milestone

Industry Night now has a validated end-to-end event funnel across external ticketing and internal platform workflows:

1. Event discovery in social app.
2. Ticket purchase via Posh event URL.
3. Webhook ingest into Industry Night API.
4. Order reconciliation to known user by phone.
5. Ticket state availability in app after resume refresh.
6. Successful check-in and persisted checked-in state.

This validates cross-system reliability, not just feature-level implementation.

## Validated Path (Dev)

- Posh webhook `new_order` received.
- `posh_orders` row created and linked to user when phone matched.
- Ticket persisted as `purchased`.
- Social app reflected purchase after app resume.
- Check-in endpoint succeeded.
- Ticket persisted as `checkedIn` with `checked_in_at`.

## Scope Included in This Milestone

- Canonical `posh_event_url` support across DB/API/shared/admin/social.
- Webhook-time reconciliation for existing users.
- Verify-code fallback reconciliation path retained.
- Read endpoints no longer perform reconciliation side effects.
- Scanner duplicate-detection hardening.
- Admin event scheduling support for overnight events.

## Risks Still Open

- Android native app-link behavior for opening Posh app may vary by device/config.
- Production hardening still needed for expanded automated validation and post-deploy checks.

## Next Strategic Tracks

### Track A: Admin Business Use-Cases

1. Posh orders operational visibility for admins.
2. Customer/product lifecycle workflow quality.
3. Event partner assignment and auditing UX.
4. Event-day check-in operations views and exception handling.

### Track B: Admin Web Migration Preparation (Flutter Web -> React)

1. Define target React architecture and design system.
2. Freeze and document API contracts for admin surfaces.
3. Build P0/P1/P2 parity matrix by workflow criticality.
4. Choose route-by-route or cutover strategy with rollback criteria.
5. Define acceptance metrics for operator parity and task completion time.
