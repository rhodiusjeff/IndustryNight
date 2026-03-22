# Adversarial Panel Review Template — Option B

**Purpose:** Four role-specialized evaluator agents each assess one dimension of an A/B model comparison. Each evaluator receives the same inputs but focuses on a different lens. The combined verdicts produce a merge recommendation.

**Applies to:** A/B prompts only — C0, A0, B0, C3, D0.

---

## Inputs Required (same for all four evaluators)

Before running any evaluator, assemble these artifacts:

```
1. The CODEX prompt spec (the .md file from docs/codex/track-X/)
2. Claude branch output — full diff: `git diff integration feature/{id}/claude`
3. GPT branch output — full diff: `git diff integration feature/{id}/gpt`
4. Claude Completion Report (from the prompt's Completion Report section)
5. GPT Completion Report (from the prompt's Completion Report section)
6. Jeff's Interrogative Session responses for each branch
7. CLAUDE.md — project reference (for patterns evaluator especially)
```

---

## Evaluator 1 — Correctness Agent

**Role:** Verify that the code does exactly what the spec says. Nothing more, nothing less.

**Prompt to run:**

```
You are a Correctness Evaluator for a software implementation review.

Your job: compare two implementations (Claude's and GPT's) against the specification below and determine which one more completely and accurately fulfills the stated requirements.

## Spec
[paste full prompt spec here]

## Claude Implementation
[paste git diff for claude branch]

## GPT Implementation
[paste git diff for gpt branch]

## What to evaluate:
1. Go through every Acceptance Criterion in the spec. Mark each as:
   - ✅ Met — implementation clearly satisfies this criterion
   - ⚠️ Partial — implementation partially satisfies this criterion; describe the gap
   - ❌ Missing — criterion is not addressed in the implementation
   - ❓ Unverifiable — cannot determine from the diff alone (may require runtime check)

2. For each User Story, confirm that the implementation supports the described behavior.

3. Note any implementation that goes BEYOND the spec (scope creep, extra features, over-engineering).

4. Note any silent failures — cases where the code would silently do the wrong thing rather than fail loudly.

## Output format:
### Acceptance Criteria Scorecard
| Criterion (short) | Claude | GPT | Notes |
|---|---|---|---|
| [criterion 1] | ✅/⚠️/❌/❓ | ✅/⚠️/❌/❓ | |
...

### User Story Coverage
[brief paragraph for each story]

### Scope Creep / Over-engineering
[list or "None"]

### Silent Failures Identified
[list or "None"]

### Correctness Score
Claude: [X/10]
GPT: [X/10]

### Correctness Verdict
[Claude wins / GPT wins / Tie / Cherry-pick — specify which parts from each]
```

---

## Evaluator 2 — Security Agent

**Role:** Find vulnerabilities, auth bypasses, injection risks, and data exposure issues.

**Prompt to run:**

```
You are a Security Evaluator for a software implementation review.

Your job: assess both implementations for security vulnerabilities, with specific focus on the attack surfaces common to this codebase (Node.js/Express API, Flutter mobile app, PostgreSQL database, JWT auth).

## Spec
[paste full prompt spec here]

## Claude Implementation
[paste git diff for claude branch]

## GPT Implementation
[paste git diff for gpt branch]

## What to evaluate (check each category):

### SQL / NoSQL Injection
- Are all database queries using parameterized statements ($1, $2, etc.)?
- Any string interpolation of user-controlled values in queries?

### Authentication & Authorization
- Are all endpoints protected by the correct middleware (authenticate, requireAdmin, etc.)?
- Are there any authorization bypasses — e.g., a user accessing another user's data?
- Are JWT token families validated (social tokens rejected at admin endpoints and vice versa)?

### Input Validation
- Is user input validated before use (Zod schemas on backend, form validation on frontend)?
- Are there missing bounds checks (e.g., no max length on text fields)?

### Data Exposure
- Are sensitive fields (password_hash, fcm_token, internal IDs) excluded from API responses?
- Are error messages leaking implementation details (stack traces, SQL errors)?

### Token & Session Handling
- Are tokens stored securely (not in localStorage if httpOnly cookie is available)?
- Is token refresh properly guarded?

### File Upload / S3
- If uploads are handled, are file types validated?
- Are S3 URLs signed where appropriate, or is everything public-read as intended?

## Output format:

### Vulnerability Findings
| Severity | Category | Description | Claude | GPT |
|---|---|---|---|---|
| Critical/High/Medium/Low | [category] | [description] | Affected/Clean | Affected/Clean |

### Summary
[2-3 sentences per implementation]

### Security Score
Claude: [X/10]
GPT: [X/10]

### Security Verdict
[Claude wins / GPT wins / Tie / Both need fixes before merge — specify]
```

---

## Evaluator 3 — Test Coverage Agent

**Role:** Assess whether the tests are genuine, comprehensive, and would actually catch regressions.

**Prompt to run:**

```
You are a Test Coverage Evaluator for a software implementation review.

Your job: assess the quality and completeness of the test suites produced by each implementation.

## Spec (Test Suite section especially)
[paste full prompt spec here]

## Claude Implementation
[paste git diff for claude branch — focus on test files]

## GPT Implementation
[paste git diff for gpt branch — focus on test files]

## What to evaluate:

### Test Existence
- Does the implementation include all test types specified in the prompt (unit, integration, smoke)?
- Are test files in the correct locations?

### Test Quality — watch for these anti-patterns:
- "Happy path only" — tests that only verify success cases, not failures
- "Tautological tests" — tests that always pass regardless of implementation (e.g., expect(true).toBe(true))
- "Mock-heavy tests" — tests that mock so much they don't test real behavior
- "Missing error case coverage" — no tests for 401, 403, 404, 422, 500 responses
- "Untestable smoke tests" — smoke test scripts that would pass even if the feature is broken

### Test Completeness
Go through each Acceptance Criterion and confirm there is at least one test that would FAIL if that criterion were violated.

### Test Maintainability
- Are tests readable? Would a new engineer understand what they're testing?
- Are test fixtures/factories reusable, or is there a lot of copy-paste?

## Output format:

### Test Coverage Matrix
| Acceptance Criterion | Claude has test? | GPT has test? | Notes |
|---|---|---|---|
| [criterion 1] | ✅/⚠️/❌ | ✅/⚠️/❌ | |

### Anti-patterns Found
| Anti-pattern | Claude | GPT | Location |
|---|---|---|---|
| [pattern] | Yes/No | Yes/No | [file:line] |

### Test Coverage Score
Claude: [X/10]
GPT: [X/10]

### Test Verdict
[Claude wins / GPT wins / Tie / Cherry-pick]
```

---

## Evaluator 4 — Patterns Agent

**Role:** Confirm the implementation fits the Industry Night codebase — consistent style, follows CLAUDE.md gotchas, no unnecessary abstractions.

**Prompt to run:**

```
You are a Codebase Patterns Evaluator for a software implementation review.

Your job: assess whether each implementation fits naturally into the existing Industry Night codebase, follows documented conventions, and avoids introducing maintenance burdens.

## Project Reference
[paste CLAUDE.md in full, or the Key Gotchas section at minimum]

## Spec
[paste full prompt spec here]

## Claude Implementation
[paste git diff for claude branch]

## GPT Implementation
[paste git diff for gpt branch]

## What to evaluate:

### CLAUDE.md Gotcha Compliance
Check each implementation against the documented gotchas:
1. snake_case JSON: Are @JsonSerializable fields using fieldRename: FieldRename.snake?
2. GoRouter singleton: Not created inside Consumer/notifyListeners rebuild path?
3. Dialog context: Using dialogContext from builder, not parent context?
4. build_runner: Did the implementation trigger a build_runner run after model changes?
5. Flutter theme classes: CardThemeData not CardTheme, Color.withValues not withOpacity?
6. JWT auto-refresh: onTokenExpired wired up in AppState constructor?
7. Event detail screen: Takes only eventId, not event object?
8. S3 graceful degradation: Returns placeholder URL when not configured?
[assess all 15 gotchas relevant to this prompt]

### Code Style Consistency
- Does the implementation match the surrounding file's style (naming, spacing, patterns)?
- Are new abstractions justified, or is this over-engineering?
- Does TypeScript follow strict mode? No `any` types sneaking in?
- Dart: Does it follow the existing feature folder structure?

### New Patterns Introduced
- Did either model introduce a new pattern not used elsewhere? Is it better than the existing pattern, or just different?
- Would this pattern conflict with downstream prompts?

### CLAUDE.md Gotcha Violations
| Gotcha | Claude | GPT | Details |
|---|---|---|---|
| [gotcha name] | Pass/Fail | Pass/Fail | |

### Style Consistency Score
Claude: [X/10]
GPT: [X/10]

### Patterns Verdict
[Claude wins / GPT wins / Tie / Cherry-pick]
```

---

## Panel Summary — Final Recommendation

After all four evaluators have run, compile the summary:

```markdown
# Adversarial Review — [Prompt ID]: [Prompt Title]

**Date:** [ISO date]
**Claude branch:** feature/{id}/claude
**GPT branch:** feature/{id}/gpt

## Scorecard

| Dimension | Claude | GPT | Verdict |
|-----------|--------|-----|---------|
| Correctness | X/10 | X/10 | [winner] |
| Security | X/10 | X/10 | [winner] |
| Test Coverage | X/10 | X/10 | [winner] |
| Patterns | X/10 | X/10 | [winner] |
| **Total** | **X/40** | **X/40** | |

## Jeff's Qualitative Input
[Summarize Jeff's Interrogative Session responses for both branches]

## Panel Recommendation

**→ [CLAUDE WINS / GPT WINS / CHERRY-PICK / RE-RUN]**

### Rationale
[2-4 sentences]

### If Cherry-pick: take these specific pieces
- From Claude: [list files/functions]
- From GPT: [list files/functions]

### Known Issues to Address Before Merge
- [ ] [issue 1 — whichever branch wins]
- [ ] [issue 2]

### Calibration Notes for Future Prompts
[What did we learn about each model's strengths/weaknesses on this prompt type that should inform model selection going forward?]
```

---

## Recommended Model for Running Panel Evaluators

All four evaluator agents should run on **claude-opus-4-6** (or **gpt-5.4** if you prefer OpenAI for the review). The evaluation task requires careful multi-document reasoning and systematic rubric application — the strongest available model for analysis work. The review model should be different from the models being evaluated where possible to minimize self-promotion bias in scoring.
