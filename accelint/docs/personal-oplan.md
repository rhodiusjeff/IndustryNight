# Personal OPLAN — AI Transformation at Accelint

**Classification:** Personal / Private
**Owner:** Jeff Simpson
**Date:** March 22, 2026
**Status:** Living document — update as terrain becomes clear

> This is a commander's personal estimate. Written to be honest, not comfortable. If this document ever leaves your hands, that's a security failure — treat it accordingly.

---

## 1. Situation

### 1.1 The Terrain

Accelint is not a cohesive company. It is a five-company roll-up (Hypergiant, Forward Slope, Highbury Defense Group, SoarTech, Systems Innovation Engineering) unified under a single brand since 2024, backed by Trive Capital. The companies have different cultures, different tech stacks, different contract vehicles, and different levels of institutional maturity. They are still figuring out what "Accelint" means.

This matters because:
- There is no single development culture to transform — there are at least five.
- Program offices may have more real authority than any Accelint corporate function.
- Loyalties are often to the legacy company, not the Accelint umbrella.
- Change is already happening (new CEO, brand consolidation) — yours is not the only disruption in flight.

The environment is classified-network-aware, process-oriented, and contract-driven. Nothing moves without authority, documentation, and precedent. Speed is not a default virtue here. Correctness and survivability are.

### 1.2 Friendly Forces — Assets and Relationships

| Name | Role | Relationship | Strategic Value |
|------|------|-------------|-----------------|
| **Andrew Nugent** | CTO | Interviewed and hired me | Executive sponsor; controls technical direction; can open any door |
| **Daniel Gelyana** | President, Global C2 & Cyber Solutions | Interviewed and hired me | Senior portfolio authority; visibility into a major segment; politically heavyweight |
| **Rob Peabody** | Chief Engineer | Personal colleague, 15+ years | Technical credibility validator; can vouch for my judgment to skeptical engineers; not in my reporting chain |
| **Carlos Perishetti** | Former CEO | Personal colleague and friend, 15+ years | Informal institutional knowledge; relationship capital; knows the culture and the landmines |

**How to use these assets:** These relationships are not levers to pull casually or to win arguments. They are insurance and access. Use Nugent and Gelyana to open doors in Phase 0 that would otherwise take months. Use Peabody to technically validate the approach with engineers who need to hear it from someone who has bled in their world. Use Carlos for off-the-record intelligence — who are the real power brokers, where are the bodies buried, what has been tried and failed before.

**Important discipline:** Never go around Jason Mak in a way that is visible. If Nugent or Gelyana reach in directly, that will make Mak defensive and adversarial. The goal is to use executive access to shape conditions and context, not to route around the org chart on tactical decisions.

### 1.3 Friction Points

**Jason Mak — VP of Software**
This is the most important relationship to manage, and it starts in a structurally awkward position. He did not have input on my hire. A senior transformation mandate was placed inside his organization without his consent. This is a flag.

What Mak likely feels: his authority over his engineers is being implicitly questioned. The message he received, whether intended or not, is "your team needs to change, and we're bringing someone in from outside to make that happen." That is a threat to a VP, regardless of how compelling the transformation rationale is.

What Mak is probably not: a villain. He's likely a capable technical manager who has built something he's protective of. The correct frame is not "how do I get around him" but "how do I make him believe this makes his organization better and makes him look good."

Threat modes to watch for:
- **Access friction** — I "need to get on his calendar" to meet with engineers; meetings get delayed
- **Information filtering** — I only hear about the teams and programs he wants me to see
- **Silent non-compliance** — he nods at the initiative in meetings and does nothing to facilitate it
- **Credit and narrative capture** — if the transformation starts working, he reframes it as his initiative
- **Failure amplification** — any stumble in the pilot gets surfaced upward as evidence the approach doesn't work

None of these require Mak to be malicious. Most can happen through normal managerial self-protection.

**The legacy company loyalists**
In each of the five constituent companies, there are senior engineers and leads who built the culture that exists. They did not ask for transformation, and some will view it as an implicit criticism of how they work. The most dangerous are the ones who are highly regarded and have deep program relationships — they have the standing to make my life difficult without corporate consequences.

**The weak-fundamentals contingent**
There are engineers on these teams who have job security through complexity — through being the one person who understands a legacy system, through working slowly in ways that are hard to audit, or through accumulating institutional knowledge that nobody else has. AI-assisted development will make this kind of job security much harder to maintain. They will not say this out loud. But they will feel it, and some will act on it.

### 1.4 Unknown Quantities

| Unknown | Why It Matters | How to Resolve |
|---------|---------------|----------------|
| Classification posture by program | Determines which tools can be used where | Phase 0 program office visits |
| Existing approved tool inventory | May already have Copilot, etc. — don't reinvent | ISSO/IT conversation early |
| Primary development stacks per team | Tool effectiveness varies by language | Team mapping in Phase 0 |
| SDLC maturity per legacy company | Where AI integrates depends on current process | PR/CI pipeline review |
| Who the real early adopters are | Always 2-3 people already using AI — find them fast | Developer 1:1s in Phase 0 |
| What has been tried before | If AI tools have been floated and failed, need to know why | Carlos + historical intel |
| Budget and procurement vehicles | Determines which commercial tools are accessible | Program manager / contracting conversation |

---

## 2. Mission

Establish AI-assisted development as the default practice across Accelint's engineering organization within 18 months, starting from zero institutional practice and against active cultural resistance, in a classified-network-constrained environment.

Success is not adoption of a specific tool. Success is a measurable, documented change in team velocity, defect rates, and documentation quality — with a self-sustaining internal capability that does not depend on my continued presence.

---

## 3. Commander's Intent

At 18 months, I want to be able to walk out of Accelint and have the transformation continue without me. That means:

- At least 3 internal champions who can train and evangelize independently
- A documented governance framework integrated into existing compliance posture (not bolted on the side)
- Pilot data published internally: before/after velocity, defect rate, documentation quality
- A tool-approval process that is routine, not a heroic exception
- Jason Mak understanding this was good for his organization

If I'm still fighting for permission to run a pilot at month 6, I have failed at Phase 0.

---

## 4. Execution

### Phase 0 — Reconnaissance (Weeks 1–6)
*Goal: Know the terrain before making any commitments.*

**Priority tasks:**
1. **Map every program's classification posture.** Don't recommend tools until you know which networks they operate on. One bad tool recommendation on a SIPR program will permanently damage credibility.
2. **Meet every key engineering lead.** Not to pitch — to listen. Understand their stack, their pain points, their current workflow. Don't mention AI transformation in the first meeting. Ask about what slows them down.
3. **Find the early adopters.** Ask indirectly: "Do you use any AI tools personally?" There are always 2-3 people already doing this quietly. They become your first cohort.
4. **Get the approved tool inventory from IT/ISSO.** Work with what's already approved before fighting procurement battles.
5. **Audit the SDLC by legacy company.** How does code get from written to shipped? Where are the friction points? Where would AI most naturally integrate?
6. **Understand Jason Mak's priorities.** What is he measured on? What keeps him up at night? Find the overlap with what this transformation delivers.
7. **Run Carlos for background.** Off the record: who are the real power brokers? What has been tried and failed? Where are the landmines?

**What NOT to do in Phase 0:**
- Don't announce the transformation broadly
- Don't make tool recommendations before knowing classification posture
- Don't hold workshops or training before you have a pilot cohort
- Don't go around Mak, visibly

**Phase 0 deliverable:** A briefing for Nugent and Gelyana (and Mak) with: program map, classification posture by team, approved tool inventory, identified pilot candidates, and recommended Phase 1 approach. This briefing IS the transition from Phase 0 to Phase 1.

---

### Phase 1 — Foundation (Months 1–3)
*Goal: Run one successful, documented pilot. Generate evidence.*

**Pilot selection criteria:**
- Unclassified or CUI-minimum program (not SIPR for the first pilot)
- Team with at least one willing early adopter
- Work that has measurable output (velocity, defect rate, documentation quality)
- Low enough stakes that a stumble doesn't become a narrative weapon
- High enough visibility that a success gets noticed

**Establish governance before the pilot starts.** This is not optional in a defense environment. The governance framework gives skeptics a process to trust even if they don't trust the technology. It also protects you — if something goes wrong, the response is "our governance framework caught it and here's what we learned," not "we were experimenting without guardrails."

Minimum governance elements for the pilot:
- Approved tools list (even if it's one tool)
- Data handling rules (what can go into the tool, what cannot)
- Review requirement (all AI-generated code requires human review before commit)
- Escalation path (who gets called if something feels wrong)

**Train the first cohort.** 5–10 engineers. Hands-on, not lecture. Pick people who already have strong fundamentals — the AI amplification effect is most visible and most legible on engineers who know what they're doing.

**Instrument a baseline before you start.** You cannot show improvement without a before. Measure: commit velocity, PR review cycle time, defect density, documentation coverage. Even imperfect measurement is better than none.

---

### Phase 2 — Proof (Months 3–6)
*Goal: Publish results. Expand. First executive briefing with data.*

**Publish the pilot results internally** — not just the numbers, but the narrative. What did engineers actually do differently? What did they say? What surprised them? Case studies with names (with permission) are more persuasive than dashboards.

**Expand to 2–3 additional programs.** Prioritize programs where you have a sympathetic lead or where the early adopter is already seeding interest.

**Brief Nugent and Gelyana with data.** This is the moment where the initiative gets institutionalized or stays a pilot. Come with: before/after metrics, engineer testimonials, a proposed governance model for scale, and a budget ask if needed.

**Develop internal champions.** At least one person per pilot program who can train others without you. This is how the initiative survives budget cuts, personnel changes, or political shifts.

**Brief Mak separately before the executive briefing.** Give him the results first. Let him have input on the narrative. This is how you make him a collaborator instead of a bystander who hears about his organization's results secondhand.

---

### Phase 3 — Scale (Months 6–18)
*Goal: AI-assisted development is the default. Self-sustaining.*

- Integrate into onboarding for new engineers
- Governance model maintained by a standing working group (not just me)
- Tool evaluation pipeline: new tools assessed against the framework routinely
- Continuous measurement loop: velocity, defects, documentation quality tracked program-wide
- Begin classified environment strategy (SIPR/JWICS local model deployment)

---

## 5. Political Navigation — Rules of Engagement

**The Mak Principle: Make him the hero.**
Every initiative that succeeds should be something Jason Mak can claim credit for facilitating. This is not sycophancy — it's smart. A VP who feels ownership of a transformation is a completely different animal from one who feels like it was done to him. Give him early access to results. Ask for his input before decisions are made. When things work, use language like "Jason's teams have been early adopters here." He will reward this with access, cooperation, and eventually, advocacy.

**Use executive access surgically.**
Nugent and Gelyana opened the door. That is different from a standing invitation to bypass the chain. Use them to: set the mandate clearly at the start, open specific doors that are blocked (a program that won't engage, a tool approval that's stalled), and validate results publicly. Do not use them to win internal arguments with Mak or individual program leads — that creates resentment that outlasts the win.

**Peabody as technical conscience.**
Rob Peabody's value is in the engineering community, not in executive meetings. The engineers who are skeptical of me — a "transformation lead" who may or may not understand what they actually do — will be more open if Peabody signals that this is technically credible. Engage him early and often on the technical methodology. Let him poke holes in the approach; if he ends up endorsing it, that endorsement carries real weight.

**Carlos for intelligence.**
Carlos should be an off-the-record resource, not a public one. Using a former CEO as a visible ally will make current leadership uncomfortable. Use the relationship for intelligence, pattern-matching, and frank feedback — not for positioning.

**Documentation as protection.**
In an environment where sabotage is possible, documentation is armor. Every decision, every recommendation, every result should be written down and shared with the relevant stakeholders. This serves three purposes: it makes my reasoning auditable, it makes it harder to rewrite history after a success, and it makes it impossible to claim "nobody told me" if an initiative gets obstructed.

**Earn technical credibility early.**
I will be assumed to be a management consultant with a PowerPoint until proven otherwise. The fastest way to earn credibility with engineers is to sit next to them, look at their actual code, understand their actual tools and constraints, and demonstrate that I know what I'm talking about technically. The AI-assisted development methodology is not abstract — it has concrete, demonstrable practices. Show them, don't tell them.

---

## 6. Threat Assessment and Countermeasures

### Technical Resistance
**Form:** "AI tools don't work for our domain / stack / classification level / problem type"
**Reality:** Often partially true. Defense software problems are real and different. Acknowledge it.
**Countermeasure:** Never claim AI tools solve every problem. Lead with specific, relevant use cases (test generation, documentation, boilerplate) that are defensible regardless of domain. Let early adopters demonstrate domain-specific value; their word carries more weight than mine.

### Political Resistance
**Form:** Delayed meetings, vague commitments, "I need to check with X" indefinitely, budget questions that never resolve
**Reality:** Passive obstruction that is plausibly deniable
**Countermeasure:** Create written commitments with timelines wherever possible. Use meeting follow-up emails to document what was agreed. Escalate through Nugent/Gelyana only after documented attempts to resolve at the appropriate level. Never escalate on the first or second block — that looks reactive. The third documented block with a clear paper trail is a different conversation.

### Failure Amplification
**Form:** A stumble in the pilot gets surfaced as "evidence it doesn't work"
**Reality:** Every pilot has stumbles; the question is whether they're treated as learning or as verdict
**Countermeasure:** Frame the pilot explicitly as a learning exercise from the start, not a proof. Publish a "what we learned" alongside "what worked." Pre-define what constitutes failure and success with stakeholders before the pilot starts — if nobody agreed on success criteria upfront, any outcome can be spun.

### Credit Capture
**Form:** If the transformation works, others claim it; if it fails, I own it
**Reality:** Classic organizational politics
**Countermeasure:** Maintain a documented record of decisions, recommendations, and results. Brief Nugent/Gelyana directly and regularly with dated updates. This is not about credit — it's about having an accurate institutional record.

### The Weak-Fundamentals Threat
**Form:** Engineers who feel threatened by AI tooling becoming active resistors or manufacturing political friction
**Reality:** They will rarely say "I'm threatened by this." They will say "this doesn't work for our problem" or "the security risk is unacceptable" or "our team doesn't have time for training"
**Countermeasure:** Do not engage this argument at the level of the objection. Acknowledge the concern, address the surface-level issue, and keep moving. The natural selection that happens as AI-assisted development matures is not something I need to manage proactively — it will surface through standard performance dynamics. My job is to create the conditions; I am not responsible for every individual's adaptation.

---

## 7. Personal Conduct Rules

1. **Never threaten.** Every communication — verbal, written, in a briefing — should feel collaborative, not evaluative. I am not auditing these teams. I am offering them a capability they didn't have.

2. **Always bring evidence.** Opinion without evidence gets dismissed in a defense culture. Every recommendation should have a citation: a benchmark, a case study, an internal data point. The CODEX methodology and the Industry Night case study are not just process artifacts — they are evidence that this approach produces results.

3. **Acknowledge the constraints.** Defense software is not a consumer startup. ITAR, CMMC, FedRAMP, ATOs — these are real constraints and treating them as bureaucratic nuisances will permanently damage credibility. Lead with constraint-awareness, not tool evangelism.

4. **Don't outpace the culture.** Velocity is not a virtue in this environment. A change that sticks is worth more than a change that moves fast and gets reversed.

5. **Separate transformation from performance management.** If an engineer is underperforming, that is Jason Mak's problem to manage, not mine. Do not let the AI transformation become a mechanism for personnel decisions — it will poison the well and create exactly the resistance I'm trying to avoid.

6. **Protect the methodology.** The CODEX framework — structured prompts with acceptance criteria, adversarial review, A/B testing, completion reports — is the intellectual core of what I'm bringing. Be willing to adapt the tooling to the environment, but protect the methodology. The methodology is what makes this rigor, not chaos.

7. **Keep a personal log.** At the end of every significant week: what happened, what I learned, what I'm changing. This is not for anyone else — it's for my own context maintenance and pattern recognition.

---

## 8. Success Metrics — Personal

| Metric | 3 Months | 6 Months | 18 Months |
|--------|----------|----------|-----------|
| Pilot programs running | 1 | 2–3 | All willing programs |
| Trained engineers | 5–10 | 25–50 | 100+ |
| Internal champions | 1–2 | 5–8 | 15+ |
| Tool approvals secured | 1 | 3–5 | Ongoing process |
| Mak relationship | Neutral → Cooperative | Cooperative | Advocate |
| Nugent/Gelyana confidence | Maintained | Growing | "This is working" |
| Executive briefing delivered | Phase 0 report | Results briefing | Annual review |

---

*Update this document after Phase 0 reconnaissance is complete. The terrain will look different once you've been inside for 30 days.*
