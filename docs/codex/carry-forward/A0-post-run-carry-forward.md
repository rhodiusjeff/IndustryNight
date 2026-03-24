# Post-Run Carry-Forward Report

Scope: one completed prompt (single-model or A/B adjudicated)
Owner: control context
When: after completion report and review are finalized

## Header
- Prompt ID: A0
- Prompt title: Phase 0 Critical Bug Fixes
- Track: A
- Date: 2026-03-24
- Control owner: control agent
- Branches reviewed: feature/A0-critical-fixes-claude, feature/A0-critical-fixes-gpt
- Winner model (A/B only): gpt-5.3-codex
- Merge target: integration

## Evidence Reviewed
- Prompt spec path: docs/codex/track-A/A0-critical-fixes.md
- Completion report path(s): not yet captured as dedicated completion-log artifacts
- Review path(s): docs/codex/reviews/A0-adversarial-review.md
- Test output summary: adjudication indicates stronger acceptance-to-test mapping on GPT lane; explicit output excerpts not yet centralized in completion logs
- Deployment or smoke verification summary: no authoritative A0 deploy-mode artifact found; local-first policy adopted for downstream prompts

## Decision Summary
- Final status: pass with deviations
- What is accepted:
  - Winner selection: GPT lane
  - Adversarial review scoring and rationale
  - Forward policy updates: local-first execution section added to all track prompts
- What is rejected:
  - Treating interrogative-session notes as a hard merge blocker for this cycle
- Deviations from prompt and rationale:
  - Jeff interrogative notes intentionally omitted by product-owner decision; guidance will be captured in control context before carry-forward or next-track execution when needed

## Lessons Learned
- What worked:
  - A/B adjudication with explicit acceptance-criteria scoring produced clear winner rationale
  - Prompt-level hardening with concrete execution stages improved operational control
- What failed or drifted:
  - Tracker state drifted from actual A0 progress (showed not started despite completed review)
  - Completion evidence was split across artifacts rather than centralized in a completion log
- Process gaps observed:
  - Interrogative session requirement was too rigid for practical control flow
  - Prompt completion package should explicitly include execution-mode declaration and command evidence
- Model behavior notes (A/B only):
  - GPT lane performed better on contract alignment and test evidence density for mixed API + Flutter acceptance checks

## Carry-Forward Actions
- Rule added or updated:
  - Interrogative session is optional; carry-forward artifacts can capture product-owner guidance when notes are omitted
  - Local-first execution policy is mandatory in track prompts
- Effective from prompt ID:
  - Interrogative-session optionality: effective immediately for A0 closeout and all downstream prompts
  - Local-first policy: effective A1/B1/C1 onward (already inserted in all track prompts)
- Files to update now (forward-only):
  - docs/codex/README.md
  - docs/codex/log/_TEMPLATE.md
  - docs/codex/tracks.md
- Files explicitly frozen (no backward edits):
  - Prompt intent/spec for completed execution branches remains frozen; only metadata/protocol clarifications applied

## Downstream Impact
- Immediate downstream prompts affected:
  - A1, A2, A3
  - B1, B2, B3
  - C1, C2, C3, C4
- New assumptions to include:
  - Every completion report must disclose execution mode and cleanup actions
  - Missing interrogative notes do not block review if control guidance is recorded
- Risks if ignored:
  - Reintroduced ambiguity on run environment (local vs shared-dev vs AWS)
  - Incomplete adjudication evidence for later audits

## Validation Gates for Next Prompts
- Required evidence gate:
  - Include exact commands run, pass/fail outputs, and whether execution was local/shared-dev/AWS
- Required generated artifact gate:
  - Completion log file per executed prompt must exist before merge recommendation
- Required shared-dev cleanup gate:
  - Record test identities and cleanup scripts/commands when shared-dev data is touched
- Required deviation disclosure gate:
  - Explicit list of spec deviations with rationale (or "None")

## Follow-Up Tasks
- Task: Create completion-log artifacts for A0 claude/gpt runs with test output excerpts
- Owner: control context
- Due by prompt ID: before A1 sign-off
- Status: open

- Task: Ensure A1 prompt execution outputs include execution mode + cleanup sections in completion artifacts
- Owner: executing agent + control context
- Due by prompt ID: A1
- Status: open

## Sign-Off
- Control sign-off: yes
- Product owner sign-off: pending
- Ready to proceed: yes
