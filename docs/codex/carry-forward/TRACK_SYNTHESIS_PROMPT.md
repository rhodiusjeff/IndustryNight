# Control Prompt: Track Carry-Forward Synthesis

Use this prompt in control context after a full track completes.

Goal
- Synthesize all prompt-level carry-forward reports for one track into a single forward guidance artifact.

Inputs
- All carry-forward reports for the track
- Prompt specs and reviews for the track
- Tracker status and winner decisions

Instructions
1. Build a track-level timeline: prompt by prompt, key decision by key decision.
2. Identify repeated failures and repeated successes across the track.
3. Distill stable rules that should apply to other tracks.
4. Flag rules that are track-specific and should not be generalized.
5. Produce a short rollout list of updates for not-yet-run prompts in other tracks.
6. Produce a hardening list for protocol/templates in docs/codex.
7. Record which historical artifacts are frozen and untouched.

Output format
- Track summary
- Reusable rules
- Track-only rules
- Cross-track rollout plan
- Protocol hardening plan
- Control sign-off recommendation
