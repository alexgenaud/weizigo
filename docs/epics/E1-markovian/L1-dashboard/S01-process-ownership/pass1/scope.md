# Pass 1 — scope (`02-scope.md`)

**Owner:** deepseek-v4-pro / T556 · **Date:** 2026-08-21 · **Status:** PROPOSED ·
**Inputs:** `01-spec.md`, `01-spec-audit-disposition.md` (41 findings, full roster),
`docs/evidence/orcha-pass1-perfamily-topology/` (phase 4).

## 1. What pass 1 is, one paragraph

Add one Zig verb `managent treekill` inside `src/managent/main.zig`; have `tools/runner`
call it on three of its four exit paths (ceiling C1, normal C2, exception C3) and the
host guard (C4); delete the old kill paths; record reap outcomes in the run record (C6).
The deliverable is **cannibalization** — `tools/runner:1554` and the normal-exit path
both call the verb and the old code is gone. Everything else in `01-spec.md` §8 stays a
non-goal.

## 2. MoSCoW

| tier | item | why |
|---|---|---|
| **Must** | correct `01-spec.md` per the 4 criticals + 12 musts (D-1..D-29); the corrected spec is the build's source of truth | the criticals are design-level contradictions (C4 would kill the whole run; read-only freezes; r4 unmeasured) — building from the uncorrected spec ships those bugs |
| **Must** | `managent treekill --anchor` verb: read-only default, `--kill`, `--seed`, `--since`, `--protect`, `--rounds`, `--settle-ms`, `--ps-fixture`; the five exit codes; the tab-separated output shape | the contract (§2) |
| **Must** | guards G1–G10 as *corrected* by D-1/D-3/D-19/D-22/D-23/D-25/D-32/D-34 (start-time floor honestly scoped; `pgid`/`sid` edges downward-restricted; field named; pre-filter cross-uid; read-only inert) | safety on a live machine |
| **Must** | cannibalization C1–C4 + C6 (run-record reap fields) with the mechanized grep gate | the deliverable; C4 must anchor on `proc.pid` and prune (D-19) |
| **Must** | `tools/regression-process-ownership.sh` with arms N1–N4, S1–S8, I1–I2, corrected per D-21/D-26/D-27/D-28/D-29/D-30/D-37; instrument-mutation controls; red-first | tests before implementation; a guard without a control is not a guard |
| **Should** | `--seed`/`last_poll_pids` persistence (D-11/D-35); `--since` as a pre-spawn epoch (D-23); loud `runCommand` failure (D-31); freeze completion oracle (D-30); `action=frozen` semantics (D-41); `--rounds` budget (D-39); internal-failure exit code (D-40) | correctness of the less-load-bearing edges |
| **Could** | ollama family: call `ollama stop <model>` (or equivalent) at the call sites so a daemon-owned model is actually released — the phase-4 consequence | the verb cannot reach the model by pid; but this is a per-family call-site addition, severable |
| **Won't (this pass)** | daemon; supervisor; runner-death sweep (T548); one-dispatch-interface build; state consolidation; cross-uid kill; Linux | `01-spec.md` §8 |

## 3. Finding → resolution map (the 41 findings)

Disposition `accept` means "fix it"; this table says *where* each fix lands. **Spec-text
(now)** = edit `01-spec.md` before anything else; **Design** = phase 6; **Build** = phase 7;
**Defer** = later pass (noted, not silently dropped).

| findings | resolution |
|---|---|
| D-19 (C4 whole-run kill), D-20 (read-only freeze), D-21 (r4 unmeasured), D-1 (G4 floor) | **Spec-text now** — the four criticals are contradictions in the spec's own body; they must be fixed in `01-spec.md` before design/test are written |
| D-2 (§7.1 grep), D-3 (G6 field), D-4 (getsid claim), D-5 (`:1303`), D-6 (Q6), D-7 (I2 arm), D-8/D-29 (OWN-3 diff), D-9 (OWN-4 arm), D-10 (exit-4 wording), D-11/D-35 (seed var), D-12 (SIGSTOP wording), D-13 (fail-red wording), D-14/D-40 (exit-1/internal), D-15 (G10 control), D-16 (r3 terminology), D-17 (G6/§10.1), D-18 (G6 coverage), D-22 (dead-anchor `--since`), D-23 (epoch), D-24 (C2 try-block), D-25 (never-killable semantics), D-26 (N2 fabricated), D-27 (OWN-1 equality), D-28 (S1/S2 two sessions), D-30 (freeze oracle), D-31 (runCommand fail-loud), D-32 (G6 expiry), D-33 (claude deposit), D-34 (cross-uid pre-filter), D-36 (SIGSTOP/SIGCONT ownership), D-37 (fixture sid), D-38 (gate prose), D-39 (rounds budget), D-41 (`frozen` action) | **Spec-text now** — all are wording, arm, guard, or citation corrections in `01-spec.md`; a single careful edit pass applies them |
| (none) | **Design** — no finding forces a design-phase-only change; the design phase (§3 algorithm, §4 guards) works from the corrected spec |
| C1–C6, the verb itself, the regression script | **Build** (phase 7) — tests written in phase 5 first (red), then the verb, then green |
| ollama `ollama stop` integration (phase-4 consequence) | **Could / Defer** — recorded as a scope item; severable if the pass must slim (it is the first cut, same rank as C6) |

## 4. The ollama consequence, stated as a scope decision

Phase 4 measured: the ollama family's heavy process (the model) is daemon-owned, so
`treekill --anchor <dispatched pid>` cannot reach it by pid. **Decision:** pass 1 ships the
verb for the compile family (where the heavy process *is* in the tree); the ollama call
sites additionally invoke `ollama stop <model>` (or the runner learns the daemon-owned
runner pid from `ollama ps`) as a **Could**. Rationale: the pass's stated harm (the
2026-08-20 compile-suite leak) is closed by the verb alone; ollama local-model dispatch is
a later concern, and the operator has ruled Gemma not worth further testing and qwen as
the only local model of interest — qwen's own dispatch failures are the same host-floor +
`killpg` crash, which C1/C4 fix, and its model residency is released by the ollama stop.

## 5. Open rulings still queued for the operator (unchanged)

1. G3 family-exclusion counting rule (round-2 analysis).
2. spec-C detach exemption (`01-spec.md` open question 1).

## 6. Cut order if the pass must slim

1. ollama `ollama stop` (Could) · 2. C6 run-record fields (severable, argued in-scope) ·
3. the Should-tier edge corrections (D-30/31/39/40/41). Never cut: the 4 criticals, the
verb, the guards, C1–C4, the regression script.
