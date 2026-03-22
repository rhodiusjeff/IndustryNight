# AI-Assisted Development — Team Education and Management Plan

**Owner:** Jeff Simpson
**Date:** March 22, 2026
**Audience:** Internal reference — Jeff's working document for team engagement strategy
**Status:** Living document — update as teams are mapped in Phase 0

---

## 1. The Honest Framing

Before planning how to teach this, it's important to be clear about what's actually true — not the marketing version, but the operational reality that needs to underpin every decision made about sequencing, messaging, and who gets trained first.

### What AI-Assisted Development Actually Is

AI-assisted development is a force multiplier. Like any force multiplier, it amplifies what's already there. A strong engineer with solid fundamentals, good architectural judgment, and the ability to communicate decisions clearly will become significantly more capable. A weak engineer who hides behind complexity, accumulates institutional knowledge as job security, and cannot communicate the reasoning behind their code will find AI-assisted development actively uncomfortable. The tool exposes the gap.

This is not something to announce. It does not belong in any training materials or briefing decks. But it must be understood clearly before making any decisions about who gets trained first, what success looks like, and how to handle the engineers who struggle.

### What Changes

- **Velocity changes.** A strong engineer with AI assistance can produce significantly more — more code, more tests, more documentation — per unit of time. This is measurable and will be visible quickly.
- **Code review becomes more important, not less.** AI-generated code must be reviewed by engineers who understand what the code is supposed to do. The review requirement goes up, not down. Engineers who cannot do effective code review become bottlenecks.
- **Communication becomes a primary skill.** Writing a precise prompt for an AI code agent is fundamentally an act of communication — defining the goal, the constraints, the acceptance criteria, the context. Engineers who communicate poorly will produce poor AI output regardless of the tool. The ability to articulate what you want precisely is now a core engineering competency.
- **The "I wrote this" accountability does not change.** Every line of code that ships is owned by a human engineer. AI suggests; engineers decide. In a defense environment, this is both an operational requirement and a contractual one in many programs.

### What Does Not Change

- Code review requirements
- Testing requirements
- Security controls
- Documentation standards — in fact, AI can dramatically improve documentation quality and coverage
- The engineer's responsibility for correctness
- Human-in-the-loop decision-making on mission-critical logic
- Classification controls — classified data does not go into unapproved tools, full stop

### The Natural Selection Reality

Some engineers will thrive with this transition. Some will struggle. The ones who thrive share identifiable characteristics: they have strong fundamentals, they communicate clearly, they are intellectually curious, and they are comfortable having their judgment questioned by a tool. The ones who struggle are often the opposite: they rely on accumulated complexity as protection, they communicate poorly, and they experience AI suggestions as a threat rather than an input.

This natural selection will happen on its own. It does not need to be managed as part of the transformation initiative. The job is to create conditions for adoption and measure results — not to make personnel decisions. Those surface through normal performance management channels, on their own timeline.

---

## 2. Team Segmentation

Every team has roughly the same distribution. Identify these groups before planning any training.

### Early Adopters (roughly 10–15% of any team)
These engineers are often already using AI tools personally — GitHub Copilot on personal projects, ChatGPT for debugging, Claude for documentation. They are not waiting for permission. They are waiting for acknowledgment, institutional support, and the opportunity to do this openly without feeling like they're doing something unauthorized.

**Strategy:** Find them in Phase 0 through direct conversation. Ask casually: "Do you use any AI tools personally?" They will tell you. These are your first cohort. Fast-track them. Give them structure (the CODEX methodology) and make them the proof of concept. Then make them champions — explicitly ask them to share their experience with peers.

### Pragmatic Majority (roughly 60–70% of any team)
These engineers do not have a strong prior position on AI tools. They will adopt if adoption is clearly beneficial, well-supported, and not a risk to them. They are watching the early adopters. If the early adopters succeed and speak positively about the experience, the pragmatic majority moves. If the early adopters struggle or if the tools feel threatening, they wait.

**Strategy:** Serve this group through evidence and social proof. Do not pitch them on the idea — show them results from colleagues they respect. Formal training happens here after the early adopters have demonstrated value.

### Skeptics (roughly 15–20% of any team)
These engineers have objections. Some objections are principled and correct ("this tool can't handle our classification requirements" or "AI-generated code in safety-critical systems needs more scrutiny"). Some are cultural and protective. Both deserve to be taken seriously.

**Strategy:** Do not try to convert skeptics in Phase 0 or Phase 1. Acknowledge their concerns explicitly. Address the legitimate ones with specific answers. Give them time. Skeptics who see results from colleagues they respect often become the most thoughtful and valuable practitioners — they push on the right things.

### Resistors (5–10% of any team)
These engineers will not adopt regardless of evidence, support, or social proof. Some are protecting job security. Some have philosophical objections. Some are simply done changing how they work.

**Strategy:** Do not spend resources trying to convert resistors. Do not make them adversaries by pressuring them. Let the initiative succeed around them. They will either quietly comply when the momentum is undeniable, or they will self-select out on their own timeline. This is not a transformation outcome — it is a performance management outcome, and it belongs there.

---

## 3. The Curriculum

AI-assisted development is a skill, not a tool preference. It requires learning. The curriculum below is progressive — each level builds on the last, and engineers should not advance before the previous level is practiced and comfortable.

### Level 0: Orientation — What This Is and Isn't
**Audience:** All teams, before any hands-on work
**Format:** 60-minute working session, not a lecture
**Goal:** Correct the misconceptions that create resistance before they harden

Key messages:
- AI does not write your code. You write your code. AI accelerates the process.
- Nothing about your review requirements, testing standards, or security controls changes.
- Your engineering judgment is what makes AI output usable. Without it, the output is noise.
- In classified environments, specific tools apply to specific networks. We will be precise about this.
- We are here because the commercial industry is already doing this, the productivity gap is widening, and our programs cannot afford to fall behind.

What to demonstrate: A live coding session where an engineer uses AI assistance on a real problem from their domain — boilerplate generation, test scaffolding, documentation. Not a synthetic demo. A real problem, with the messiness and iteration that comes with it.

---

### Level 1: AI as Pair Programmer
**Audience:** Early adopters first; pragmatic majority once early adopters are comfortable
**Format:** Hands-on lab, 3–4 hours
**Goal:** Productive daily use of AI for low-risk, high-frequency tasks

Skills taught:
- Effective prompting: how to be precise about what you want (goal, constraints, context, format)
- Code completion and suggestion workflows (how to use suggestions without accepting blindly)
- Documentation generation: docstrings, API documentation, inline comments
- Boilerplate and scaffolding: repetitive structural code, config files, schema definitions
- Debugging assistance: using AI to reason through errors and unexpected behavior

**The most important habit to establish at Level 1:** Every AI output gets read before it gets used. No blind acceptance. This is non-negotiable and must be established as muscle memory before the engineer advances.

Defense-specific considerations:
- Unclassified networks: use the approved commercial tools
- CUI environments: verify data handling requirements before any input
- SIPR/JWICS: locally-deployed models only (Ollama, Azure Government OpenAI, AWS GovCloud Bedrock — as applicable and approved)

---

### Level 2: AI as Reviewer
**Audience:** Engineers who have completed Level 1 and practiced for 2–4 weeks
**Format:** Hands-on lab, 2–3 hours, plus ongoing integration into code review workflow
**Goal:** Using AI as a first-pass reviewer to improve code quality before human review

Skills taught:
- Code review prompting: how to ask for specific vulnerability classes, style issues, and logic gaps
- Security-focused prompting: SQL injection patterns, input validation gaps, auth bypass risks
- Refactoring assistance: identifying and improving complex or poorly-structured code
- Test gap analysis: asking AI to identify cases not covered by existing tests

**The key discipline at Level 2:** AI review catches things; it does not catch everything. Human review is still required. AI review is a quality gate, not a quality ceiling. Engineers who treat AI review as a replacement for human review are making a mistake.

---

### Level 3: AI as Scaffolder — The CODEX Approach
**Audience:** Engineers who have completed Level 2; pilot teams with specific feature work to do
**Format:** Workshop + ongoing practice with real work
**Goal:** Structured, contract-driven AI execution that produces verifiable, reviewable output

This is where the Industry Night CODEX methodology becomes directly applicable. The core principle: you do not just "ask the AI to write something." You give the AI a contract — a structured prompt with a stated goal, acceptance criteria, context files, and a test specification. The AI's output is measurable against the contract.

A CODEX-style execution prompt contains:
- **Goal:** A precise 1–3 sentence description of what must be produced
- **Context:** Specific files, documentation, and constraints the AI must read before starting
- **Acceptance Criteria:** Verifiable, binary conditions the output must satisfy
- **Technical Spec:** Implementation constraints, function signatures, file locations, error handling requirements
- **Test Suite:** Specific test cases that will fail if the acceptance criteria are not met
- **Completion Report:** A structured self-report the AI fills in after execution
- **Interrogative Session:** A set of questions the human engineer asks to quality-check the AI's work before it goes to review

Why this matters in a defense context: structured prompts with acceptance criteria are directly analogous to requirements documents and test plans — artifacts the culture already understands and trusts. This is not "vibe coding." This is requirements-driven development with AI assistance.

---

### Level 4: AI-Native Workflow — Advanced Practice
**Audience:** Champions and senior practitioners; optional for the broader team
**Format:** Ongoing; not a single event
**Goal:** Full integration of AI assistance into the development workflow; mentorship and evangelism capability

Advanced practices:
- **A/B model testing:** Running the same prompt on two different AI models on separate branches, comparing outputs on correctness, security, test coverage, and codebase fit before merging
- **Adversarial panel review:** Four-dimensional review of AI-generated code (Correctness, Security, Test Coverage, Patterns) before high-stakes merges
- **Prompt library development:** Building a team-specific CODEX library of reusable, high-quality execution prompts for the team's common task types
- **Model selection discipline:** Knowing which tasks benefit from the most capable model vs. the fastest and most cost-effective one

---

## 4. What Changes in Management

The transformation is not just about tools. It changes how work looks, how it is measured, and what management needs to attend to. These changes need to be understood before they create friction.

### Velocity Expectations
Output per engineer increases — sometimes dramatically for well-scoped tasks. This is good news, but it creates management questions: Are we comparing engineers fairly if some are using AI assistance and some are not? Are we adjusting sprint capacity expectations? Are we re-evaluating which tasks are worth doing now that the cost of doing them has dropped?

These are questions for Jason Mak and program managers to work through. My job is to surface them, not answer them unilaterally.

### Code Review Volume and Importance
More code gets produced. That means more code gets reviewed. Code review capacity may become the constraint. Engineers who are good reviewers become more valuable. Programs that have weak review practices will feel the strain faster.

Implication: code review capability needs to scale with adoption. This may mean formalizing review processes that are currently ad-hoc, or training engineers specifically in effective AI-output review.

### Measuring Output vs. Activity
One of the most common ways engineers resist accountability is by conflating activity (hours worked, meetings attended, complexity of the problems they "own") with output (working code, passing tests, shipped features, good documentation). AI-assisted development makes output more visible and more comparable. Engineers who were protected by the opacity of their work will find that protection eroding.

This is not something to advertise. But it shapes what metrics to establish in the pilot and what management conversations to expect.

### The Communication Premium
The engineers who succeed most with AI-assisted development are the ones who communicate well — who can write a precise goal, who can articulate constraints clearly, who can specify acceptance criteria. These are also the engineers who write good commit messages, good PR descriptions, good design documents. The transformation effectively raises the floor on communication competence.

Teams with strong written communication culture will adopt faster. Teams with weak written communication culture will need foundational work alongside the AI tooling.

---

## 5. Training Delivery Principles

### Hands-On Over Lecture
Nothing about AI-assisted development is learned by watching a presentation. Every training session must include hands-on work with real tools on real problems — ideally from the engineer's own codebase and domain.

### Problems Over Demos
A curated demo where everything works is less persuasive than a live session where things go sideways and get recovered. The willingness to demonstrate messiness builds more trust than polish.

### Peer Instruction Over External Instruction
Once the early adopter cohort has 4–6 weeks of practice, they should be doing the Level 1 and Level 2 training for their own peers. My role shifts from instructor to curriculum designer and quality controller. Peer instruction is more credible and more scalable.

### Voluntary Before Mandatory
The pilot is voluntary. The first cohort should want to be there. Mandatory training — especially on something as culturally charged as AI tools — produces compliance, not adoption. Adoption happens when engineers choose to use the tools because they make their work better.

Mandates, if they ever become necessary, come after the transformation has demonstrated clear value. They should never be the mechanism that drives Phase 0 or Phase 1.

### Small Cohorts
Training cohorts should be 5–12 engineers. Larger than 12 and the hands-on work becomes a spectator sport. Smaller than 5 and there's not enough peer interaction to create social proof.

---

## 6. Metrics and Measurement

Measurement must begin before the pilot starts. Without a baseline, there is no before/after story.

### Baseline Metrics to Establish
- **Commit velocity:** commits per engineer per sprint
- **PR cycle time:** time from PR opened to PR merged
- **Defect density:** bugs found post-merge per sprint
- **Documentation coverage:** percentage of functions/modules with adequate documentation
- **Test coverage:** line/branch coverage by module

### Pilot Outcome Metrics
Measured at 4, 8, and 12 weeks after training for the pilot cohort vs. the control:
- Same metrics as baseline, plus:
- **Engineer satisfaction:** brief anonymous pulse (do you feel more or less productive with AI assistance?)
- **Code review feedback:** are reviewers noting quality differences?

### What to Do With the Numbers
Publish them internally. Not selectively — all of them, including the metrics that are flat or mixed. The credibility of the initiative depends on honest reporting. A transformation that cherry-picks its evidence will be found out, and the credibility damage is severe and lasting.

---

## 7. Classified Environment Strategy

This section requires significant refinement during Phase 0 reconnaissance. What follows is the preliminary framework.

### NIPR (Unclassified / CUI)
Commercial AI tools may be usable with appropriate controls:
- Tool must be FedRAMP-authorized (High, where required by program ATO)
- Data handling verified: no CUI input into tools not cleared for CUI
- Approved through IT/ISSO via existing procurement vehicles where possible
- GitHub Copilot, Tabnine, Amazon CodeWhisperer are common candidates — verify FedRAMP status and data handling policies before recommending

### SIPR (Secret) and JWICS (TS/SCI)
Commercial cloud AI tools are not appropriate. Local/on-premise model deployment only:
- **Ollama** with open-source models (Llama 3, Code Llama, Mistral, StarCoder) on approved hardware
- **Azure Government OpenAI** — if program has Azure Government presence and appropriate ATO
- **AWS GovCloud Bedrock** — similar; verify per-program ATO
- All model deployments require approval through the program ATO process

The classified environment strategy is the most complex part of this transformation. Do not make commitments here before Phase 0 reconnaissance is complete.

---

## 8. Quick Reference — The First 90 Days

| Week | Priority Action |
|------|----------------|
| 1–2 | Meet every engineering lead. Listen. Don't pitch. |
| 2–3 | Find the early adopters. Confirm their interest quietly. |
| 3–4 | Get the approved tool inventory from IT/ISSO. Map classification posture. |
| 4–6 | Run Phase 0 report for Nugent/Gelyana/Mak. |
| 6–8 | Stand up governance framework for the pilot. |
| 8–10 | Begin Level 0 orientation with pilot cohort. |
| 10–12 | Level 1 training with pilot cohort. Measure baseline first. |

---

*Update this document after the first cohort completes Level 1 training. Revise team segmentation estimates based on actual team composition observed in Phase 0.*
