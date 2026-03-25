# Control Plane User Manual

Audience: human operators running CODEX execution and closeout (stakeholder + control agent).

Purpose: define the operating model for planning, execution control, review gates, validation gates, and prompt closeout.

---

## 1. Operating Model

The control plane separates responsibilities so implementation can move quickly without losing governance:

- Execution Agent: implements prompt scope and provides evidence.
- Control Agent: enforces gates, validates readiness, and updates process artifacts.
- Stakeholder: final decision maker for go/no-go, risk acceptance, and closeout signoff.

Control principle:
- A prompt is implemented by execution agents, but only closed by control after all gates pass.

---

## 2. Prompt Lifecycle

Use this state machine for every prompt ID:

1. Planned
2. In Progress
3. Implemented
4. Reviewing
5. Validated
6. Closed

Definitions:
- Implemented: code/tests complete by execution lane, but not yet approved by control.
- Reviewing: local and GitHub review gates are active.
- Validated: runtime/manual checks complete for affected surfaces.
- Closed: control artifacts and tracker state finalized.

---

## 3. Required Gates

A prompt cannot transition to Closed unless all four gates are green.

### Gate A: Implementation Evidence

Required evidence from execution lane:
- Branch and PR URL.
- Commit list and scope summary.
- Commands run and key outputs.
- Deviations and deferrals (or None).

### Gate B: Review Gate

Two-part review model:

1. Local Dev Review (required)
- Quick structural/self review before PR merge.
- Validate acceptance criteria coverage and regression risk.

2. GitHub PR Review (required)
- Human review required.
- Copilot review recommended.
- Findings must be dispositioned (fixed, accepted risk, or deferred with owner).

### Gate C: Validation Gate

Runtime/manual verification required for integration-affecting prompts:
- Smoke test results.
- Manual acceptance checks for user-facing changes.
- Environment declaration (local/shared-dev/AWS dev).

### Gate D: Control Evidence Gate

Control artifacts updated with links and outcomes:
- Prompt log entry completed.
- Carry-forward artifact finalized.
- Tracker row updated with final status and references.

---

## 4. Branching and Worktree Strategy

Recommended parallel model:

- Execution worktree/branch: feature/<prompt>-integration-mopup (or lane branch).
- Control worktree/branch: feature/<prompt>-control-closeout.

Rules:
- Do not mix feature fixes and control docs in the same branch.
- Keep one prompt scope per execution branch unless explicitly approved.
- If contamination occurs, stop and re-isolate before proceeding.

---

## 5. Handoff Contract: Execution -> Control

Execution handoff must include:

1. Prompt ID and branch.
2. PR URL and merge status.
3. Commit SHAs included.
4. Deploy commands and outcomes.
5. Smoke test outcomes.
6. Manual test matrix (pass/fail by criterion).
7. Open issues and disposition.
8. Cleanup actions performed.

If any item is missing, control requests a completion addendum before closeout.

---

## 6. Findings Disposition Standard

Every review finding gets one disposition:

- Fixed: include commit/PR link.
- Accepted Risk: include owner + rationale + expiry condition.
- Deferred: include owner + due prompt ID.

No orphan findings at closeout.

---

## 7. Closeout Checklist (Control)

Before marking Closed:

1. Integration includes required merge commits.
2. All review findings dispositioned.
3. Validation evidence linked.
4. Prompt log complete.
5. Carry-forward report finalized.
6. Tracker row updated.
7. Stakeholder signoff captured.

---

## 8. Recovery Playbooks

### Missed Review Gate

1. Freeze status at Reviewing (do not close).
2. Run retroactive review on merged PRs.
3. Open mopup branch for required fixes.
4. Re-run validation and update control artifacts.

### Branch Contamination

1. Stop edits.
2. Move control work to dedicated control branch/worktree.
3. Move feature fixes to execution branch.
4. Resume once branches are cleanly separated.

### Incomplete Evidence

1. Request evidence addendum from execution agent.
2. Keep prompt status as Implemented or Reviewing.
3. Do not advance to Validated/Closed.

---

## 9. Quick Start Runbooks

### Start Prompt Safely

1. Create execution branch/worktree from integration.
2. Confirm prompt dependencies are satisfied.
3. Run implementation with evidence capture.

### Close Prompt Safely

1. Ingest handoff package.
2. Pass review gate.
3. Pass validation gate.
4. Finalize logs/carry-forward/tracker.

### Run Mopup Safely

1. Branch from integration HEAD.
2. Fix only validated findings.
3. Re-deploy/re-test targeted surfaces.
4. Merge and return evidence to control.

---

## 10. Required Artifacts

Core docs used by control operators:

- docs/codex/README.md
- docs/codex/tracks.md
- docs/codex/log/_TEMPLATE.md
- docs/codex/carry-forward/CONTROL_POST_RUN_PROMPT.md
- docs/codex/carry-forward/_TEMPLATE.md
- docs/codex/guides/control_plane_user_manual.md

---

## 11. Governance Defaults

- Review is control-owned, not prompt-owned.
- Prompt completion is provisional until control gates pass.
- Prefer local-first validation, then shared-dev/AWS validation as required.
- Keep process changes in control branches and product changes in execution branches.
