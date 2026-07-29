# Handover — GLM-5.2 (Orchestrator) → Opus 5, 2026-07-29

**Read first on resume:** `untracked/msg/milestone-01-ko-reframe/STATE.md` (crash
anchor), then `bin/managent status`, then **`untracked/msg/milestone-01-ko-reframe/037-glm-to-opus-orchestrator-handover.md`** (the full handover message to Opus 5), then `docs/status/CURRENT.md`, then the role docs (`docs/infra/roles/ORCHESTRATOR.md`, `docs/infra/delegation/ROLES.md`).

## Role

**GLM-5.2 = outgoing Orchestrator** (standing down permanently). **Opus 5 = incoming Orchestrator** (the human's nomination). GLM-5.2 transitions to **Q&A-only**, as Opus 5 and the human coordinate. Per `ORCHESTRATOR.md` "Exactly one, ever" — there is never a second Orchestrator; the outgoing stands down and may not touch the board again (may advise when asked).

## The one thing that matters most

**2B-4 reports QA-023 FALSIFIED at 3×2 — pending the audit chain, NOT in CLAIMS.** The Opus 5 audit of 2B-2 found F5 (an `apply_place` ko-rule bug), so 2B-FIX-KO (DONE, Opus 5) was the gate; read its deliverable for whether the falsification holds under the corrected rule. The audit chain: 2B-2-AUDIT (Kimi, DONE) → 2B-5 (in progress, DeepSeek-Pro) → 2B-6 (blocked). 2B-3 audit suggested but not registered.

## Board at handover

```
dispatchable (0)
in progress (1):  2B-5 (calibration; DeepSeek-Pro)
blocked (5):      2B-6 · EXP-4 → EXP-5 → EXP-6 → EXP-7
done (8):         2B-0, 2B-1 (Fable 5) · 2B-2 (m3) · 2B-2-AUDIT (Kimi)
                  2B-2-AUDIT-OPUS (opus-5) · 2B-3, 2B-4 (DeepSeek-Pro)
                  2B-FIX-KO (opus-5)
failed (1):       EXP-2B (superseded by 2B-0…2B-6)
```

## What this session encoded (load-bearing — see ORCHESTRATOR.md)

D-8 (Orchestrator owns the board end-to-end: dispatch/claim/done/reopen/purge/set/needs/agent); proactive duties (read channel + check board + integrate + verify-don't-trust + commit); anti-spin-out (manic-catch-killer); model-in-brief (briefs don't specify models; human assigns; agent records; log to model-perf); bin/managent SSOT (sets are parallel-group labels; needs+holds are the gates); all builds through `tools/runner`; run `bin/weizigo-claimlint` after any CLAIMS edit; `cp zig-out/bin/managent bin/managent` after a rebuild.

## Loose ends for Opus 5

- Absorb 2B-FIX-KO's result (does QA-023 hold under the corrected ko rule?) → CLAIMS/PROGRESS/model-perf, after the audit chain agrees.
- Record the 2B-2/2B-3/2B-4/2B-2-AUDIT model-perf data points (m3/Pro/Pro/Opus).
- Register the 2B-3 audit (suggested; Pro's history-pair bug-fixes need verification).
- `docs/evidence/AUDIT-2B-2/` untracked (Kimi's 2B-2 audit) — fold + commit.
- Human's downstream goals: a 4×4 engine for Sabaki smoke-test; docs/epistemic cleanup + future direction.

## Key tools

`bin/managent` (the queue; spec `docs/infra/managent/spec.md`) · `tools/runner` (RSS/CPU guard for builds) · `bin/weizigo-claimlint` (the CLAIMS gate) · `untracked/msg/milestone-01-ko-reframe/` (the channel; STATE.md is the crash anchor).

— GLM-5.2 (outgoing Orchestrator), 2026-07-29. Tree is clean; everything load-bearing is in git. I remain for Q&A only.