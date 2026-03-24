# Adversarial Review — A0: Phase 0 Critical Bug Fixes

**Date:** 2026-03-23
**Prompt file:** `docs/codex/track-A/A0-critical-fixes.md`
**Claude branch:** `feature/A0-critical-fixes-claude`
**GPT branch:** `feature/A0-critical-fixes-gpt`
**Panel model:** `gpt-5.3-codex` (control-session adjudication)

---

## Evaluator Scorecards

### Correctness
| Criterion (short) | Claude | GPT | Notes |
|---|---|---|---|
| Fix 1: Delete Account UX + confirmation + redirect + error handling | Partial | Pass | Both implement Danger Zone + confirm/call/redirect/snackbar. GPT additionally enforces authenticated-only rendering per acceptance criterion. |
| Fix 2: Refresh invalid token returns 401 with explicit error body | Pass | Pass+ | Both add inner verify try/catch with 401 body. GPT also normalizes token-family mismatch path to same explicit error response. |
| Fix 3: unlikePost crash + endpoint response compatibility | Partial | Pass | Claude fixes Dart crash but keeps unlike response as `{ post }`. GPT aligns route to `{ success: true }` and client ignores body. |
| Fix 4: SQL interpolation hardening in posts route | Pass | Pass | Both preserve parameterized query approach. |
| Fix 5: Post author fields in shared model | Pass | Pass | Both add `authorName`/`authorPhoto` fields in `Post`. |
| Fix 6: Delete comment endpoint behavior | Pass | Pass+ | Both implement 404/403/200 behavior and admin override. GPT recalculates `comment_count` from source of truth (`COUNT(*)`), improving consistency. |

**Claude score:** 8.0/10
**GPT score:** 9.2/10
**Verdict:** GPT

---

### Security
| Severity | Category | Claude | GPT | Notes |
|---|---|---|---|---|
| High | Refresh token validation and error handling | Pass | Pass | Both prevent JWT parse errors from surfacing as 500. |
| Medium | Token-family misuse behavior | Pass | Pass+ | Both return 401; GPT ensures explicit standardized body on mismatch branches. |
| Low | SQL interpolation risk in `posts.ts` | Pass | Pass | No user-controlled string interpolation in SQL found in either lane. |
| Low | Authorization guard on comment deletion | Pass | Pass | Both enforce author/admin gate and proper not-found handling. |

**Claude score:** 9.0/10
**GPT score:** 9.3/10
**Verdict:** GPT (narrow)

---

### Test Coverage
| Acceptance Criterion | Claude test? | GPT test? | Notes |
|---|---|---|---|
| Refresh error behavior (social/admin) | Yes | Yes | GPT expands explicit error-body assertions and admin refresh path coverage in `auth.test.ts`. |
| Unlike endpoint behavior and client compatibility | Yes | Yes | Both add API-side coverage via `posts.test.ts`. |
| Comment delete 404/403/200/admin + count behavior | Yes | Yes | Both cover core cases; GPT version is concise and includes count behavior. |
| Delete Account widget behavior | No | Yes | GPT adds `settings_screen_test.dart` for visibility/dialog/cancel flow. |
| Existing suite compatibility | Pass | Pass | GPT updated existing tests (`auth.test.ts`, `customers.test.ts`) to reflect current RBAC/audit behavior. |

**Claude score:** 7.4/10
**GPT score:** 9.1/10
**Verdict:** GPT

---

### Patterns (CLAUDE.md compliance + style)
| Gotcha / Pattern | Claude | GPT | Notes |
|---|---|---|---|
| Dialog context usage in Delete Account flow | Pass | Pass | Both use `dialogContext` correctly for delete confirmation. |
| Authenticated-only visibility for destructive action | Partial | Pass | GPT explicitly gates Danger Zone rendering by auth state. |
| Scope discipline (surgical changes) | Pass | Partial | GPT touches extra tests beyond A0-local file list; useful but broader footprint. |
| Traceability and explicit error contracts | Pass | Pass+ | GPT is more explicit on standardized error-body assertions. |

**Claude score:** 8.3/10
**GPT score:** 8.8/10
**Verdict:** GPT

---

## Jeff's Qualitative Input Summary

*Claude branch review:*
> Pending direct interrogative-session notes in this review artifact.

*GPT branch review:*
> Pending direct interrogative-session notes in this review artifact.

---

## Panel Summary

| Dimension | Claude | GPT | Verdict |
|-----------|--------|-----|---------|
| Correctness | 8.0/10 | 9.2/10 | GPT |
| Security | 9.0/10 | 9.3/10 | GPT |
| Test Coverage | 7.4/10 | 9.1/10 | GPT |
| Patterns | 8.3/10 | 8.8/10 | GPT |
| **Total** | **32.7/40** | **36.4/40** | **GPT** |

---

## Final Recommendation

**→ GPT WINS**

### Rationale
GPT delivers stronger acceptance-criteria fidelity on two key requirements: authenticated-only Delete Account visibility and unlike response contract alignment (`{ success: true }`). GPT also provides materially better verification evidence by adding targeted widget tests and tightening auth-path assertions in existing API tests. Claude is solid and surgical, but misses explicit acceptance alignment on these two points.

### If Cherry-pick — take these specific pieces
- From Claude: `settings_screen.dart` logout dialog context cleanup (optional style/pattern alignment).
- From GPT: route + model + tests as primary merge candidate for A0.

### Issues to address before merge
- [ ] Add Jeff interrogative-session summaries to this file before final sign-off.
- [ ] Confirm any generated-artifact policy expectations for shared models are documented in carry-forward (repository currently does not track `post.g.dart`).
- [ ] Ensure Completion Report for winning lane explicitly lists any deviations and rationale.

### Calibration notes for future prompts
For prompt classes that mix API contracts + Flutter UX acceptance checks, the winning lane had better outcomes when it combined strict contract conformance with explicit UI tests (not just API tests). Carry this forward by requiring acceptance-to-test mapping in completion artifacts for downstream prompts (A1/B1/C1+).
