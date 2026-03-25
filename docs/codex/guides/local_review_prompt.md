# Local Review Prompt (Generic, Control-Owned)

Purpose
- Run a structured local code review before merge.
- Produce findings-first output with clear severity, evidence, and required actions.

When to use
- Any implementation branch before merge.
- Any mopup branch before closeout.

Inputs required
1. Prompt spec path.
2. Branch under review.
3. Base branch for comparison.
4. Relevant test outputs.
5. Runtime validation evidence if applicable.

Prompt to run

You are a strict code reviewer. Review the branch under test against the prompt spec and the base branch.

Review scope
- Correctness against acceptance criteria.
- Security and auth correctness.
- Behavioral regressions.
- Database safety and migration impact.
- API contract compatibility.
- Flutter/UI behavior and state transitions.
- Test quality and missing tests.
- Operational risk (deploy/runtime config).

Required review behavior
1. Findings first, ordered by severity.
2. Include file-level evidence and why it matters.
3. Distinguish blockers vs non-blockers.
4. If no findings, state that explicitly and list residual risks.

Output format

Section 1: Findings (required)
- Severity: High | Medium | Low
- Location: path and symbol/function
- Problem: what is wrong
- Impact: user/system risk
- Recommended fix: concrete action
- Gate: blocker or non-blocker

Section 2: Open Questions or Assumptions
- List unknowns that affect confidence.

Section 3: Test and Validation Gaps
- Missing tests or weak assertions.
- Missing runtime/manual checks.

Section 4: Verdict
- Pass
- Pass with required mopup
- Blocked

Scoring rubric (optional)
- Correctness: /10
- Security: /10
- Regression risk: /10
- Test quality: /10
- Operational readiness: /10

Review checklist
- Acceptance criteria map to code and tests.
- Invalid/expired auth paths return expected status codes.
- SQL usage is parameterized for user-controlled input.
- DB migration is safe and reversible enough for current stage.
- API responses remain compatible with clients.
- Flutter/UI paths cover both happy and failure states.
- No hidden config coupling that breaks dev/prod parity.
