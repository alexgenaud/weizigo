# Pass 2 — scope

**Owner:** deepseek-v4-pro/pass2-spec · **Date:** 2026-08-21 · **Status:** PROPOSED ·
**Inputs:** `spec.md` (this pass's), `pass1/spec.md` + `pass1/scope.md`,
`docs/status/refactor-roadmap-2026-08-20.md`, `docs/status/ROADMAP-2026-08-21.md`.

## 1. What pass 2 is, one paragraph

Add one long-lived mode `managent supervise` to the existing binary that **holds** every
worker it dispatches as a direct child and never detaches; move the fleet-fill loop
(fleet-keeper), the dispatch+verify+heal path (dispatch/subagent/dispatch_verify), and
the graceful-stop flag (fleet-cooldown) into it; make `managent supervise <id> <model>`
the one dispatch command for Pi and Claude; add the `ollama stop` per-family release
(Could); and close the five pass-1 deferred treekill findings (B-7..B-11). The
deliverable is **cannibalization** — the replaced scripts call the verb and the old code
is gone (spec §6, one task at a time until a full day runs on the supervisor).

## 2. MoSCoW

| tier | item | why |
|---|---|---|
| **Must** | `managent supervise` long-lived + oneshot modes; HOLD-1..6 (no detach, direct death observation, treekill containment, foreground, single instance, single writer) | the "held, not inferred" root cause; a supervisor that detaches is not the deliverable |
| **Must** | the guard table (§2.2): RSS cap, host-memory floor, wall/CPU ceiling, progress watchdog, directive poll, heartbeat, run record — all killing via `treekill`, not `killpg` | the measured leak shape is `killpg`-per-group; held handles + descendant walk replace it |
| **Must** | verify + heal inline in the held process (§2.3); nonce/deliverables/row-state; provider-refusal; wall-advisory; heal sole-owner | the dispatch-verify safety is the point of the path (T408/T411/T477/T538) |
| **Must** | one dispatch interface (§3): DP-1..3, the family-token grep gate, data-not-code launch templates | the operator's requirement; F7 (four drifting model definitions) |
| **Must** | fleet-fill loop behaviour-preserving (§2.1): eligibility ordering, one-writer invariant, pressure state machine, heal-cooldown, backoff + lane circuit-breaker, allow/deny | the tested asset (T500/T504/T536); swap mechanism, not policy |
| **Must** | cooldown verb (§2.4) + shutdown semantics SUP-STOP-1/2/3 | graceful stop is the operator's lever; hard stop must reap held children |
| **Must** | B-7..B-11 (§5), each with a control | five cheap fixes; the supervisor is the next treekill caller and must not inherit the traps |
| **Must** | `tools/regression-supervise.sh` arms N1–N3, S1–S9, B7–B11 + instrument-mutation controls, red-first | tests before implementation; a guard without a control is not a guard |
| **Should** | C7's cross-writer grep gate | cosmetic once HOLD-6 holds; pins the single-writer property |
| **Could** | `ollama stop` per-family release (§4) + arm S9 | daemon-owned model residency; severable (first cut) — local models idle under D036 |
| **Could** | `managent supervise status` held-children listing | fold into the later fleet view if the pass must slim |
| **Won't (this pass)** | full fleet view / `argus` / `orcha-acceptance` / `model-profiles` absorption; run-records-into-store (seed Pass 3); model-perf structured rows (seed Pass 4); deleting the Python `tools/runner` build-guard; supervisor-crash orphans (T548); Linux; cross-uid; nested-dispatch exemption (Open Q2) | spec §7 |

## 3. Cut order if the pass must slim

1. `ollama stop` (Could) · 2. `supervise status` listing (Could) · 3. C7 grep gate
(Should). Never cut: HOLD-1..6, the guard table, verify + heal, DP-1..3, B-7..B-11, the
cannibalization sites C1–C6.
