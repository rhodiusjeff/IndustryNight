# Control Prompt: Post-Run Carry-Forward

Use this prompt in control context immediately after a prompt finishes.

Goal
- Convert lane outcomes into forward-only improvements without changing historical prompt specs.

---

## Input Location Conventions

Before running this prompt, verify you have:

| Input | Expected Location |
|-------|------------------|
| Prompt spec | `docs/codex/track-{X}/{ID}-{name}.md` |
| Completion report (execution agent) | `docs/codex/log/track-{X}/{ID}/completion-report.md` (or equivalent) |
| Control decision log | `docs/codex/log/track-{X}/{ID}/control-decision.md` |
| Adversarial review (A/B only) | `docs/codex/reviews/{ID}-adversarial-review.md` |
| Carry-forward template | `docs/codex/carry-forward/_TEMPLATE.md` |
| Tracks master state | `docs/codex/tracks.md` |
| Operational context | `docs/codex/EXECUTION_CONTEXT.md` (update if API ground truth changed) |

For A/B prompts, both lane completion reports are required before proceeding.

---

Inputs
- Completed prompt spec
- Completion report(s)
- Test outputs
- Review artifacts (adversarial review for A/B)
- Any merge or hotfix notes
- Local review gate evidence (required)
- GitHub PR review gate evidence (required)

Instructions
0. Verify review gates first. If either review gate is missing, output "blocked" and list missing evidence.
1. Evaluate acceptance criteria outcome and classify: pass, pass with deviations, or blocked.
2. Extract objective lessons only. Separate implementation lessons from process lessons.
3. For A/B prompts, record model-specific strengths and failure patterns.
4. Propose carry-forward changes only for prompts not yet executed.
5. Propose updates to shared protocol/templates only when the lesson is cross-cutting.
6. Do not modify prior executed prompt specs unless there is a factual metadata error.
7. Produce a carry-forward report using the template at docs/codex/carry-forward/_TEMPLATE.md.
8. Provide a patch plan listing exact files to update and why.

---

## CLAUDE.md Staleness Check (Required Step)

After extracting lessons, explicitly check if any of these need updating in `CLAUDE.md`:
- New API endpoints added as unspecced work (add to Admin API endpoints table)
- New tables added (add to Tables section)
- Publish gate requirements changed (update Event publishing gate section)
- New environment variables introduced (add to Environment Variables section)
- New gotchas discovered (add to Key Gotchas section with number)
- Test counts changed (update Testing Plan section)

If CLAUDE.md needs updates, include them in the patch plan with the specific line ranges.

Also check if `docs/codex/EXECUTION_CONTEXT.md` needs updating:
- New API ground truth (Section 3)
- New codebase patterns (Section 5)
- Updated dependency map (Appendix)

---

Output format
- Outcome classification
- Review gate status (local + GitHub)
- Top 3 lessons
- CLAUDE.md staleness disposition (updated / no-change-needed / deferred with reason)
- EXECUTION_CONTEXT.md staleness disposition
- Forward-only file update plan
- Risks and mitigations for next prompt
- Go or no-go recommendation

---

## Mandatory Output Artifacts

This prompt MUST produce:

| Artifact | Path | Owner |
|----------|------|-------|
| Control decision log | `docs/codex/log/track-{X}/{ID}/control-decision.md` | Control agent |
| Carry-forward report | `docs/codex/carry-forward/{ID}-post-run-carry-forward.md` | Control agent |
| Tracker row update | Flagged table for human operator (CODEX_TRACKER.xlsx) | Human operator |
| Prompt patches | Listed in carry-forward patch plan | Control agent |

The prompt is NOT complete until all four artifacts exist and the tracker update table has been output.

---

Quality bar
- No vague lessons
- Every lesson must map to one concrete update target
- Every update target must include effective-from prompt ID
- CLAUDE.md and EXECUTION_CONTEXT.md staleness must be explicitly dispositioned (not silently skipped)

