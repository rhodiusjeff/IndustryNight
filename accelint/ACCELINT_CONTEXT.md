# Accelint — Context Handoff Document

**Owner:** Jeff Simpson (jeff@rhodiuslabs.com)
**Role:** Transformation Lead (new internal hire)
**Last Updated:** March 22, 2026
**Status:** Early-stage ramp-up — see §8 for known gaps

---

## 1. What This Document Is

This is the context handoff document for the Accelint AI-assisted development transformation initiative. It exists so any AI assistant (or new session) can pick up immediately with full situational awareness — the same pattern used in the Industry Night project (`industry_night_app_developer_context_handoff.md`).

When starting a new session on Accelint work, load this document and say: *"Read ACCELINT_CONTEXT.md and tell me what we're working on."*

---

## 2. The Company: Accelint

Accelint is a defense software company whose development teams build next-generation applications for the US military and allied nation militaries. Primary domains:

- **Command & Control (C2)** — decision support, situational awareness, operational coordination
- **ISR (Intelligence, Surveillance, Reconnaissance)** — sensor fusion, data pipelines, analysis tooling
- **Logistics & Planning** — supply chain, mission planning, resource allocation applications

The software these teams produce is mission-critical. Some of it runs in contested, degraded, or disconnected environments (DDIL). Some interfaces with systems where errors have operational consequences. This is not a typical commercial software shop.

---

## 3. Jeff's Role and Mandate

**Title:** Transformation Lead (internal hire — not external consultant)
**Mandate:** Agent of change — transition Accelint's development teams from traditional to AI-assisted development practices
**Reporting:** TBD / still being established
**Tenure:** New — actively ramping up

The transformation is not being imposed top-down by leadership as a fait accompli. Jeff is entering an environment where:

- Most "mainline programmers" have not made the transition to AI-assisted development
- Some individuals may have personal experience with AI tools, but it's not institutionalized
- The culture is military-software-adjacent: rigorous, process-oriented, potentially skeptical of anything that smells like "vibe coding"
- There is no single homogeneous tech stack — multiple programs, multiple stacks

Jeff's job is to earn trust, demonstrate value, build a repeatable practice, and make the case to multiple audiences (developers, product managers, executives, program offices) that this transition is both possible and necessary.

---

## 4. The Transformation Vision

### What "AI-Assisted Development" Means Here

This is NOT:
- AI writing code without human review
- Replacing engineers with AI tools
- Moving fast and breaking things
- Using unapproved tools on classified networks

This IS:
- Engineers using AI as a force multiplier for the work they already do well
- Automating the expensive, repetitive, low-value parts of software development (boilerplate, documentation, test scaffolding, refactoring)
- Elevating code review, architecture, and mission-critical design — the parts that require human judgment
- Building institutional knowledge about which tools work, under what conditions, with what guardrails

### Why It Matters Now

The commercial software industry has already normalized AI-assisted development. The productivity gap between AI-assisted and non-AI-assisted teams is measurable and widening. Defense software programs face budget pressure, schedule pressure, and talent competition. The transition is not optional in the long run — the question is whether Accelint leads it or reacts to it.

---

## 5. The Defense Software Context: Constraints That Cannot Be Ignored

This section is critical. Many AI adoption playbooks written for commercial software are not directly applicable in a defense context. The following constraints shape every tooling recommendation.

### 5.1 Classification and Network Topology

Defense development environments typically span multiple classification levels:

| Network | Classification | AI Tool Access |
|---------|---------------|----------------|
| NIPR (NIPRNet) | Unclassified / CUI | Commercial cloud AI tools *may* be usable with controls |
| SIPR (SIPRNet) | Secret | Air-gapped — no commercial cloud AI; local/on-prem models only |
| JWICS / SAP | TS/SCI and above | Fully air-gapped — local models only, with additional vetting |

**Implication:** Any tool recommendation must specify which networks it applies to. A blanket "use GitHub Copilot" recommendation is incomplete — it may be valid on NIPR and completely inappropriate on SIPR.

> ⚠️ **Gap:** The classification posture of Accelint's specific programs is not yet fully known. The framework below is written to be adaptable. As program-specific constraints become clear, update the tooling recommendations accordingly.

### 5.2 Regulatory and Compliance Framework

| Framework | Relevance |
|-----------|-----------|
| **ITAR** (International Traffic in Arms Regulations) | Restrictions on sharing controlled technical data with AI tools — input data matters, not just output |
| **CMMC** (Cybersecurity Maturity Model Certification) | Level 2/3 requirements govern how CUI is handled, including AI-generated code containing CUI |
| **FedRAMP** | Cloud AI tools used for government work must be FedRAMP-authorized (High, where required) |
| **NIST SP 800-171** | CUI handling controls; AI tool selection must not create uncontrolled disclosure vectors |
| **Program-specific AIS/ATO** | Individual programs may have Authority to Operate (ATO) requirements that gate tool adoption |

**Implication:** The governance framework (§7 below) must integrate with existing compliance posture, not sit beside it.

### 5.3 The Cultural Terrain

Military-adjacent software developers tend to be:

- **Rigorous and process-oriented** — they have formal code review, testing requirements, and documentation standards because the stakes demand it
- **Skeptical of hype** — they've seen many "next big thing" tools come and go; AI needs to demonstrate value, not just promise it
- **Protective of correctness** — any tool that introduces risk to mission-critical logic will be resisted, and rightly so
- **Responsive to demonstrated capability** — if you show it works, with evidence, they'll adopt it

The framing of this initiative matters enormously. "AI writes your code" is a losing message. "AI handles the busywork so you can focus on the hard problems" is the right message.

---

## 6. The Transformation Roadmap (Provisional)

This is an early-stage framework. It will be refined as Jeff gets the lay of the land at Accelint.

### Phase 0 — Reconnaissance (Weeks 1–4)
- Map the programs, stacks, and team structures
- Identify classification posture per program
- Find the early adopters (there are always a few — find them)
- Audit existing tool approvals and procurement vehicles
- Understand the SDLC: how code gets written, reviewed, tested, and shipped today

### Phase 1 — Foundation (Weeks 4–12)
- Establish governance framework: approved tools list, data handling rules, red lines
- Stand up a pilot on a non-classified, lower-stakes program or feature
- Train the first cohort of 5–10 developers
- Instrument measurement baseline: velocity, defect rate, documentation quality

### Phase 2 — Proof (Months 3–6)
- Publish pilot results internally
- Expand to 2–3 additional programs
- Begin building internal capability: champions, documentation, internal training
- First executive briefing with data

### Phase 3 — Scale (Months 6–18)
- Institutionalize: AI-assisted development is the default, not the exception
- Integrate into onboarding for new developers
- Governance model is self-sustaining
- Continuous improvement loop: new tools evaluated against the approved framework

---

## 7. Governance Framework (First Draft)

### Approved Use Cases (Unclassified Environments, Subject to Tool Approval)
- Code completion and suggestion (GitHub Copilot, Tabnine, or equivalent)
- Documentation generation (docstrings, API docs, MIL-STD artifacts)
- Test case generation and coverage analysis
- Code review assistance (vulnerability scanning, style enforcement)
- Refactoring legacy code (particularly C++ and Java modernization)
- Architecture analysis and diagramming
- Boilerplate and scaffolding generation
- Regex, SQL, and configuration file generation

### Approved Use Cases (Air-Gapped / Classified Environments)
Same list as above, but only with **locally-deployed models** that have been vetted and approved for the classification level. This includes:
- Ollama-hosted open-source models (Llama, Code Llama, Mistral, etc.) on approved hardware
- Government-cloud AI services with appropriate ATO (Azure Government OpenAI, AWS GovCloud Bedrock)

### Red Lines — Non-Negotiable
1. **No classified or CUI data in unapproved AI tools.** This is not a gray area.
2. **No AI-generated code for safety-critical or mission-critical logic without explicit human expert review.** AI suggests; engineers decide.
3. **No tool adoption without program-level ATO or compliance review.**
4. **No AI-generated code committed without human review.** AI is not a committer.
5. **No ITAR-controlled technical data as AI input** unless the tool has been specifically evaluated and cleared for that data.

### The Human-in-the-Loop Requirement
AI outputs in this context are always suggestions, never decisions. The engineer is responsible for every line of code that ships. This is both a cultural norm and, in some programs, a contractual requirement.

---

## 8. Known Gaps (as of March 22, 2026)

These are the things Jeff does not yet know, which will shape the specifics of the transformation approach:

| Gap | Why It Matters | How to Close It |
|-----|---------------|-----------------|
| Classification posture by program | Determines which tools can be recommended | Program office conversations in Phase 0 |
| Existing approved tool inventory | May already have Copilot/etc. approved — don't reinvent | IT/ISSO conversation |
| Primary development stacks | Tooling effectiveness varies by language | Team mapping in Phase 0 |
| Team size and distribution | Shapes pilot selection and rollout pace | Org chart + team leads |
| SDLC maturity | Determines where AI integrates (pre-commit, CI, review, docs) | Code review + CI pipeline review |
| Key stakeholders to win | Who can block, who can champion | Stakeholder mapping |
| Existing AI anxiety or resistance | Shapes the communication strategy | Developer conversations, 1:1s |
| Budget and procurement vehicles | Determines which commercial tools are accessible | Program manager / contracting |

---

## 9. Deliverables Being Created

The following materials are being developed as part of the initial Accelint engagement setup:

| Deliverable | Purpose | Audience | Status |
|-------------|---------|---------|--------|
| `ACCELINT_CONTEXT.md` (this file) | AI session context handoff | AI assistants, Jeff | ✅ Draft |
| `ai-dev-playbook.md` | Transformation methodology guide | Internal reference | 🔵 In progress |
| Adversarial Panel Review | Multi-evaluator critique of the playbook | Jeff's QA | ⬜ Pending |
| Developer Briefing Deck (.pptx) | "Here's what changes and what doesn't" | Accelint developers | ⬜ Pending |
| Exec/Product/Mgmt Briefing Deck (.pptx) | Business case + roadmap + governance | Leadership, program managers | ⬜ Pending |

---

## 10. Industry Night as a Case Study Reference

[Industry Night](../CLAUDE.md) is a separate project — a platform for discovering and managing industry night events (hair stylists, makeup artists, photographers, creative workers). It is Jeff's ongoing development project and serves as the **primary live case study** for AI-assisted development practices.

**Why it's relevant to Accelint:**

Industry Night is built with a full modern stack (Flutter/Dart, Node.js/TypeScript, PostgreSQL, AWS/EKS) and is being developed using the CODEX prompt library — a structured set of AI execution prompts, each with acceptance criteria, test suites, and adversarial panel review. This is the methodology being generalized for Accelint.

**Key concepts from IN that translate directly:**
- **CODEX prompt library** (`docs/codex/`) — structured AI execution prompts with stated goals, acceptance criteria, and test suites. This is the template for how Accelint should structure AI-assisted work: not "ask the AI to write code" but "give the AI a prompt with a contract."
- **Adversarial panel review** — four role-specialized evaluators (Correctness, Security, Test Coverage, Patterns) review AI-generated code before merge. Directly applicable to defense software where code review rigor matters.
- **A/B branch protocol** — running the same prompt on two AI models on separate branches, then comparing outputs. Useful for calibrating which models work best for which types of tasks.
- **CLAUDE.md / context handoff pattern** — the discipline of maintaining a living context document so AI sessions are always fully oriented. This document is that pattern applied to Accelint.
- **Completion Report + Interrogative Session** — each AI execution produces a structured self-report and a human qualitative review. Creates institutional memory and enables retrospective analysis.

**What NOT to use from IN directly:**
- The specific tech stack (Flutter, PostgreSQL, etc.) is not relevant unless Accelint uses similar tools
- The specific schema and API design are IN-specific
- The business domain (events, creative workers) is obviously not applicable

When referencing Industry Night in Accelint briefings, frame it as: *"Here is a real project where this methodology is being applied right now. These are the tools, this is the process, these are the results."*

---

## 11. Jeff's Working Philosophy

A few principles that should inform how any AI assistant works with Jeff on this initiative:

1. **Honest over comfortable.** Jeff wants to know what doesn't work, what the risks are, and where the gaps are. Don't paper over hard problems.
2. **Practical over theoretical.** Recommendations need to be actionable. "It depends" is a valid answer only when followed by what it depends on and how to find out.
3. **Context-preserving.** Jeff works across long sessions and multiple projects. Document decisions, rationale, and open questions explicitly — don't assume context will survive a context reset.
4. **Military software demands rigor.** The Accelint audience is not a consumer startup. They need to see that AI-assisted development increases, not decreases, rigor and correctness. Lead with quality, not velocity.
5. **Earn trust before asking for change.** The transition will fail if it's imposed. The approach is to demonstrate value on small, real problems, then let adoption spread organically from the early adopters.

---

## 12. Quick Reference: Key Files

| File | Location | Purpose |
|------|----------|---------|
| This document | `accelint/ACCELINT_CONTEXT.md` | Session context handoff |
| Transformation playbook | `accelint/docs/ai-dev-playbook.md` | Full methodology guide |
| Adversarial panel template | `accelint/panel/adversarial-panel-review.md` | Review framework |
| Developer deck | `accelint/decks/developer-briefing.pptx` | Developer-facing slides |
| Exec deck | `accelint/decks/exec-briefing.pptx` | Leadership-facing slides |
| IN CODEX library | `../docs/codex/` | Live case study reference |
| IN CLAUDE.md | `../CLAUDE.md` | IN project context |

---

*This document is living. Update §8 (Known Gaps) as Jeff learns more during Phase 0 reconnaissance. Update §6 (Roadmap) when the program landscape becomes clearer.*
