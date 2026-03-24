# Control Prompt: Post-Run Carry-Forward

Use this prompt in control context immediately after a prompt finishes.

Goal
- Convert lane outcomes into forward-only improvements without changing historical prompt specs.

Inputs
- Completed prompt spec
- Completion report(s)
- Test outputs
- Review artifacts (adversarial review for A/B)
- Any merge or hotfix notes

Instructions
1. Evaluate acceptance criteria outcome and classify: pass, pass with deviations, or blocked.
2. Extract objective lessons only. Separate implementation lessons from process lessons.
3. For A/B prompts, record model-specific strengths and failure patterns.
4. Propose carry-forward changes only for prompts not yet executed.
5. Propose updates to shared protocol/templates only when the lesson is cross-cutting.
6. Do not modify prior executed prompt specs unless there is a factual metadata error.
7. Produce a carry-forward report using the template at docs/codex/carry-forward/_TEMPLATE.md.
8. Provide a patch plan listing exact files to update and why.

Output format
- Outcome classification
- Top 3 lessons
- Forward-only file update plan
- Risks and mitigations for next prompt
- Go or no-go recommendation

Quality bar
- No vague lessons
- Every lesson must map to one concrete update target
- Every update target must include effective-from prompt ID
