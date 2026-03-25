# Completion Log — [Prompt ID]: [Prompt Title]

**Prompt file:** `docs/codex/track-X/XX-title.md`
**Branch:** `feature/{prompt-id}-{short-name}-[claude|gpt]` (A/B) or `feature/{prompt-id}-{short-name}` (non-A/B)
**Model used:** [exact model string, e.g. claude-sonnet-4-6]
**A/B prompt:** Yes | No
**Date completed:** [YYYY-MM-DD]
**Execution duration:** [approx hours]

---

## Agent Self-Report

### What I implemented exactly as specced
- [item]
- [item]

### What I deviated from the spec and why
- [item — deviation + rationale]
- _or:_ None

### What I deferred or left incomplete
- [item — what + why deferred]
- _or:_ None

### Technical debt introduced
- [file:line — description of debt]
- _or:_ None

### What the next prompt in this track should know
- [gotcha, pattern established, decision made that affects downstream]

---

## Acceptance Criteria — Self-Check

| Criterion (short) | Status | Notes |
|---|---|---|
| [criterion 1] | ✅ Met / ⚠️ Partial / ❌ Not met | |
| [criterion 2] | | |

---

## Test Run Summary

```
[paste relevant test output here — suite name, pass/fail count, any failures]
```

---

## Review Gate Evidence (Required)

### Local Dev Review

- Reviewer:
- Date:
- Outcome: pass | fail
- Findings summary:

### GitHub PR Review

- PR URL:
- Reviewer(s):
- Copilot review used: yes | no
- Outcome: pass | fail
- Findings summary:

### Findings Disposition

| Finding | Severity | Disposition (fixed/accepted/deferred) | Evidence link |
|---|---|---|---|
| [item] | [high/med/low] | [status] | [PR/commit/log link] |

---

## Jeff's Interrogative Session (Optional)

If this section is skipped, record product-owner guidance (if any) in the carry-forward report.

**Date of review:** [YYYY-MM-DD] or Not provided

**Q1: Does the implemented behavior match your mental model of this feature?**
> Jeff: [answer]

**Q2: Is there anything that feels wrong that the acceptance criteria wouldn't catch — UX, naming, flow, edge cases?**
> Jeff: [answer]

**Q3: Any concerns you want flagged before this goes to adversarial review or merge?**
> Jeff: [answer]

_or:_ Not provided for this run.

---

## Outcome

**Ready for adversarial review / merge review:** ☐ Yes ☐ No — pending: [reason]

**Merge decision:** ☐ Merged to integration | ☐ Needs fixes | ☐ Replaced by other branch (A/B loser)

**Date merged:** [YYYY-MM-DD]

**Notes:**
