# CI/CD Hardening Context

Date: 2026-03-22
Status: Context Captured, Execution Deferred Until Post-Refactor

## Why This Document Exists

Industry Night has now validated the critical event funnel in dev:

1. Posh RSVP -> webhook ingest
2. order reconciliation -> ticket state
3. app resume refresh -> check-in completion

This document captures CI/CD hardening priorities so the team can return after the upcoming major refactor with clear, concrete implementation targets.

## Current Decision

We are intentionally not diving deep into CI/CD implementation right now because a major refactor is coming.

Goal for now: preserve a clear hardening roadmap and acceptance criteria so post-refactor work is faster and less error-prone.

## Hardening Scope to Revisit After Refactor

### 1. Deployment Safety Gates

- Add pre-deploy migration execution as a controlled step (or Kubernetes Job).
- Block rollout if migration fails.
- Ensure migration status is visible in CI logs and release artifacts.

### 2. Post-Deploy Validation

- Add required post-deploy smoke checks for core paths:
  - health endpoint
  - specialties/markets
  - RSVP-relevant event/ticket endpoints
- Fail deployment if smoke checks fail.

### 3. API Test Expansion

- Add coverage for:
  - auth lifecycle (request code, verify, refresh, logout)
  - user deletion cascade correctness
  - event publish gate requirements
  - webhook reconcile behaviors (existing user, fallback path, idempotency)
  - check-in edge cases (already checked-in, invalid activation code)

### 4. Runtime Observability

- Upgrade health checks to include DB connectivity verification.
- Track webhook outcome metrics by class:
  - received
  - unauthorized
  - malformed
  - reconciled
  - ticket created
  - duplicate ignored
- Add alert thresholds for webhook failures and check-in errors.

### 5. Operational Recovery

- Define rollback runbook for failed deploys.
- Add concise incident response checklist for event-day failures.
- Ensure runbooks are linked from deploy workflow output.

## Suggested Post-Refactor Execution Sequence

1. Lock final API contracts for refactored services.
2. Implement migration pre-deploy gate.
3. Add post-deploy smoke gate.
4. Expand integration tests for RSVP/check-in lifecycle.
5. Add observability + alerting.
6. Run one full game-day drill in dev.

## Definition of Done (CI/CD Hardening)

- A deployment that breaks RSVP -> ticket -> check-in is automatically blocked or failed.
- Webhook/check-in failure signals are visible quickly via logs + alerts.
- Recovery steps are documented and executable without tribal knowledge.

## Related Documents

- docs/product/milestone_posh_to_checkin_e2e.md
- docs/product/implementation_plan.md
