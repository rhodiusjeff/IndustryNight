# Post-Run Carry-Forward Report

Scope: one completed prompt (single-model or A/B adjudicated)
Owner: control context
When: after completion report and review are finalized
Save location: `docs/codex/log/track-{X}/{ID}/post-run-carry-forward.md` (co-located with control-decision.md and completion-report.md)

## Header
- Prompt ID:
- Prompt title:
- Track:
- Date:
- Control owner:
- Branches reviewed:
- Winner model (A/B only):
- Merge target:

## Evidence Reviewed
- Prompt spec path:
- Completion report path(s):
- Review path(s):
- Test output summary:
- Deployment or smoke verification summary:

## Decision Summary
- Final status: pass, pass with deviations, or blocked
- What is accepted:
- What is rejected:
- Deviations from prompt and rationale:

## User Story Amendments

*Instructions: Review the TE's User Story Deviations section in the completion log. For each deviated story, determine TC action: Update (amend user-stories.md + amendment log), Accept (no change to doc — deviation is implementation detail, story stands as intent reference), or Flag (product intent changed, Jeff review required before carry-forward). Update `docs/product/user-stories.md` for all Update decisions.*

| Story (short label) | Original Text | Implemented As | TC Action | Reason |
|---------------------|--------------|----------------|-----------|--------|
| example | "original story text" | "what was actually built" | Update / Accept / Flag | rationale |

- Total stories in scope for this prompt:
- Stories confirmed as-implemented (no deviation):
- Stories amended (Update):
- Stories accepted as-is (Accept):
- Stories flagged for Jeff (Flag):
- `user-stories.md` updated: yes / no / N/A (no deviations)

## Lessons Learned
- What worked:
- What failed or drifted:
- Process gaps observed:
- Model behavior notes (A/B only):

## Carry-Forward Actions
- Rule added or updated:
- Effective from prompt ID:
- Files to update now (forward-only):
- Files explicitly frozen (no backward edits):

## Downstream Impact
- Immediate downstream prompts affected:
- New assumptions to include:
- Risks if ignored:

## Validation Gates for Next Prompts
- Required evidence gate:
- Required generated artifact gate:
- Required shared-dev cleanup gate:
- Required deviation disclosure gate:

## Follow-Up Tasks
- Task:
- Owner:
- Due by prompt ID:
- Status:

## Sign-Off
- Control sign-off:
- Product owner sign-off:
- Ready to proceed: yes or no
