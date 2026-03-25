# Local Review Prompt: A0 Integration Mopup (PR #54)

Use this prompt exactly for reviewing feature/A0-integration-mopup against integration.

Context for reviewer
- Repository: IndustryNight
- Base branch: integration
- Review branch: feature/A0-integration-mopup
- PR: #54
- Scope note: mopup includes schema, API, and Flutter/mobile verification-related changes.

Prompt to run

You are a strict code reviewer for A0 closeout mopup. Perform a findings-first review of PR #54 and the branch diff feature/A0-integration-mopup against integration.

Primary objectives
1. Verify A0 closeout changes are safe and production-appropriate.
2. Detect regressions introduced by mopup.
3. Confirm cross-layer compatibility (schema, API, shared, Flutter app).
4. Confirm tests actually prove the intended behavior.

Focus areas (required)

A. Database and schema changes
- Validate migration safety and data integrity.
- Check foreign key cascade behavior and audit_log preservation expectations.
- Identify destructive or high-risk migration behavior.

B. API behavior
- Auth and refresh flows return expected status codes and message shapes.
- Twilio-default OTP behavior is preserved.
- Request/response contracts remain backward compatible with clients.
- No new auth bypass or privilege escalation vectors.

C. Flutter and shared package interactions
- Shared model changes align with API response shapes.
- Flutter UI paths are resilient on both success and failure.
- Any new widget tests are meaningful and not tautological.

D. Test quality
- Ensure tests assert behavior, not implementation details only.
- Verify negative and edge cases are covered for changed logic.
- Call out missing tests that should block closeout.

E. Operational readiness
- Identify runtime config coupling risks (dev vs prod).
- Check for deploy-time hazards or hidden assumptions.

Required output format

Section 1: Findings (ordered by severity)
For each finding include:
- Severity: High | Medium | Low
- Location: path and function/symbol
- Problem
- Impact
- Recommended fix
- Gate: blocker or non-blocker

Section 2: Review coverage summary
- What was reviewed fully.
- What was sampled only.

Section 3: Test and validation gaps
- Missing automated tests.
- Missing manual/runtime validations.

Section 4: Verdict
- Pass
- Pass with required mopup
- Blocked

Section 5: Minimal required follow-ups before A0 closeout
- List exact items required for control signoff.

Additional instruction
- If there are no findings, explicitly state no findings, then list residual risk and confidence limits.
