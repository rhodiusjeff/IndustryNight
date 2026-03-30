# Industry Night — Project Context for AI Assistants

This file captures context that AI assistants should understand when working on this project.

---

## Stakeholder Profile (Jeff)

**Background:**
- Built BIG systems — but that was pre-cloud era
- Knows K8S and AWS conceptually, uses them in this project
- NOT a "cloud-native CI/CD heavyweight" — and is completely fine acknowledging that
- This is a knowledge/practitioner gap, not a competence issue

**Strengths:**
- App architecture and product design — genuinely strong; has built the full platform from scratch
- Building governance frameworks — CODEX is a novel AI-assisted development protocol being actively developed
- Product thinking — unified customer model, event publish gates, token family separation all show mature judgment
- Not vibe coding — systematic, documented, uses structured prompts with acceptance criteria
- Direct quote: "Creating apps? I fucking rock at that."

**Self-identified gaps:**
- Production CI/CD in modern environments — has not done this before; needs guidance here
- This is explicitly acknowledged, not a blind spot
- Direct quote: "I don't have a problem with that. That's just a knowledge gap and practitioner skill development."
- **He will lean on AI for CI/CD help. Be ready to teach, not judge.**

**Working style:**
- Solo developer building a real platform, not a toy project
- Uses AI as a force multiplier, not a crutch
- Will push back when AI assessments miss context — expects accuracy, not flattery
- Pre-production: tolerates some technical debt with defined triggers for addressing it
- Direct quote: "We are a long way from a real system." — self-aware about what's built vs. what's needed

---

## Project Stage (as of March 2026)

- **Pre-production** — no live users, no live money
- **Monthly event cadence** — natural deployment windows; not 24/7 uptime critical
- **Can tolerate 1-day downtime** at launch if needed — not ideal, but acceptable for stage
- **CODEX framework under active development** — the governance model itself is part of the work
- **Two apps + shared backend** — Flutter social app, React admin (replacing Flutter admin), Node/Express API

---

## Risk Acceptance Posture

| Item | Status | Trigger |
|------|--------|---------|
| CI automation on PR push | Deferred | Production launch |
| Token revocation | Deferred | Before real users |
| File upload limits | Deferred | Before real users |
| Full production hardening | Deferred | Series A or revenue |

The discipline exists (closeout-test.sh, 4-gate model, adversarial review). Infrastructure automation is sequenced behind feature velocity because that's rational prioritization for a solo pre-launch founder.

---

## CI/CD Help Expectations

**Context from March 2026 conversation:**

Jeff explicitly asked for help with CI/CD and will rely on AI assistants for this. The expectation:

1. **Teach, don't judge** — the gap is acknowledged; no need to lecture about why CI matters
2. **Ground-up explanations** — like the "CI/CD for neophytes" walkthrough that was done; context-rich, no assumptions
3. **Write the actual files** — draft `.github/workflows/*.yml` tuned to this repo's structure
4. **Debug together** — CI always fails the first run; expect to iterate
5. **Connect to what he knows** — he has K8S, AWS, deploy scripts; CI is the layer on top

**When CI time comes, the workflow is:**
1. Jeff says "let's do CI"
2. AI drafts `ci.yml` for the repo (testcontainers, Flutter, specific paths)
3. Jeff pushes, opens test PR
4. It fails (always does first time)
5. Jeff pastes error, AI explains fix
6. Repeat until green
7. Enable branch protection

**This is a 2-4 hour working session, not a project. The hard parts (tests, deploy scripts, architecture) are already done.**

---

## How to Work With This Project

1. **Be accurate** — Jeff will catch overstatements and push back
2. **Acknowledge process discipline** — tests ARE run, just not automated; the 4-gate model IS enforced
3. **Know the CODEX model** — prompts, tracks, gates, carry-forward; it's not standard Agile
4. **Respect the pre-production context** — risk tolerance is calibrated to stage, not to Netflix-scale operations
5. **Help with CI/CD when asked** — this is a genuine knowledge gap, not stubbornness

---

*Last updated: March 26, 2026*
