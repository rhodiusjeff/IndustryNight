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
| M-01 | Bad phone format on request code | POST /auth/request-code | failure | validation failure (currently gap to capture in audit) | In Progress | Pending | Validation middleware path |
| M-02 | Provider/Twilio send failure on request code | POST /auth/request-code | failure | request_code_failed | Pass | Pass | Confirmed in audit_log |
| M-03 | Wrong verification code (correct phone) | POST /auth/verify-code | failure | invalid_verification_code | Pass | Pass | Confirmed in audit_log |
| M-04 | Expired verification code | POST /auth/verify-code | failure | verification_code_expired | Pass | Retest Pending | Initially logged as verify_code_failed, classification patch deployed; confirm on next run |
| M-05 | Bad admin email | POST /admin/auth/login | failure | admin_not_found | Pending | Pending | Manual run pending |
| M-06 | Bad admin password | POST /admin/auth/login | failure | invalid_credentials | Pending | Pending | Manual run pending |
| M-07 | Missing auth header on protected social route | GET /auth/me | failure | missing_authorization_header | Pending | Pending | Manual/API tool trigger |
| M-08 | Wrong token family on social route | GET /auth/me | failure | token_family_mismatch | Pending | Pending | Manual/API tool trigger |
| M-09 | Wrong token family on admin route | GET /admin/dashboard | failure | token_family_mismatch | Pending | Pending | Manual/API tool trigger |
| M-10 | Invalid webhook signature | POST /webhooks/posh | failure | invalid_signature | Pending | Pending | Manual script/curl |
| M-11 | Malformed webhook payload | POST /webhooks/posh | failure | malformed_payload | Pending | Pending | Manual script/curl |

## Known Gaps
- Validation middleware failures (for example malformed phone input) are not yet explicitly audited as security events.
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
- M-04 observed: expired attempt logged as verify_code_failed before patch; patch deployed and awaiting re-validation.
