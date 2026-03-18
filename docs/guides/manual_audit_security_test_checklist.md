# Manual Audit Security Test Checklist (Dev)

Purpose: track manual security test actions and verify corresponding audit_log rows.

## Test Session
- Date: 2026-03-17
- Environment: dev
- API host: https://dev-api.industrynight.net
- Tester: Jeff

## How To Use
1. Execute one manual action at a time.
2. Mark status as In Progress, Pass, or Fail.
3. Verify expected audit_log fields.
4. Add notes for mismatches or missing rows.

## Expected Core Fields For All Security Events
- action
- entity_type
- result
- failure_reason (for failures)
- route
- method
- status_code
- occurred_at
- request_id
- metadata

## Manual Scenarios

| ID | Scenario | Endpoint | Expected result | Expected failure_reason | Manual status | Audit status | Notes |
|---|---|---|---|---|---|---|---|
| M-01 | Bad phone format on request code | POST /auth/request-code | failure | validation_failed | Pass | Pass | request_id `e0ba9e9e-73f6-4ea7-82dc-33981f7f8b46` |
| M-02 | Provider/Twilio send failure on request code | POST /auth/request-code | failure | request_code_failed | Pass | Pass | Confirmed in audit_log |
| M-03 | Wrong verification code (correct phone) | POST /auth/verify-code | failure | invalid_verification_code | Pass | Pass | Confirmed in audit_log |
| M-04 | Expired verification code | POST /auth/verify-code | failure | verification_code_expired | Pass | Pass | request_id `fc0d7b4c-d7b9-4181-92f5-13fc5f50d753` |
| M-05 | Bad admin email | POST /admin/auth/login | failure | admin_not_found | Pass | Pass | request_id `b2ad9807-e8a8-445a-91c3-07d7090c8612` |
| M-06 | Bad admin password | POST /admin/auth/login | failure | invalid_credentials | Pass | Pass | request_id `5a6dd938-846c-4607-9976-1d5afb5ad870` |
| M-07 | Missing auth header on protected social route | GET /auth/me | failure | missing_authorization_header | Pass | Pass | request_id `26605148-6423-4358-9541-f85df44296f9` |
| M-08 | Wrong token family on social route | GET /auth/me | failure | token_family_mismatch | Pass | Pass | request_id `2e4fe347-9fc0-43fd-8dab-2de5fb9e2943` |
| M-09 | Wrong token family on admin route | GET /admin/dashboard | failure | token_family_mismatch | Pass | Pass | request_id `d9c6ea6f-d6bd-4a77-b41a-55e833983aea` |
| M-10 | Invalid webhook signature | POST /webhooks/posh | failure | invalid_signature | Pass | Pass | request_id `539672ed-4dff-4738-9633-77ae03c491a3` |
| M-11 | Malformed webhook payload | POST /webhooks/posh | failure | malformed_payload | Pass | Pass | request_id `0555bc2a-d835-408d-b1e2-661bc6bfb016` |

## Known Gaps
- Provider-specific Twilio error categorization is not yet normalized beyond request_code_failed.

## Verification Query Pattern
Use focused filters by route and time window to avoid mixing with unrelated failures.

Example columns to inspect:
- occurred_at
- action
- entity_type
- result
- failure_reason
- route
- method
- status_code
- metadata

## Session Notes
- M-02 confirmed: request_code_failed row present for /auth/request-code.
- M-03 confirmed: invalid_verification_code row present for /auth/verify-code.
- M-04 revalidated: expired attempt now logs `verification_code_expired`.
- M-01 revalidated: validation middleware logs `validation_failed` end-to-end in dev.
- M-05 through M-09 validated with matching failure reasons and request-level audit rows.
- Webhook negative tests now pass after wiring `POSH_WEBHOOK_SECRET` into the dev k8s secret and redeploying.
- Webhook handler now classifies malformed payloads as `malformed_payload` instead of falling through to `webhook_processing_failed`.
