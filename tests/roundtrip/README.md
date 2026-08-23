# tests/roundtrip — the dispatch-lifecycle round-trip tier

**Task:** T797 (round-trip tests on the stub seam) · **Landmark:** advances
`L1 (measurement integrity)` — the consolidation gets a safety net that
survives the consolidation.

This tier exercises the **dispatch → run → verify → close** lifecycle end to
end — with **no provider, no tokens, no cost and no wall clock beyond its own
sleeps**. It runs real processes (`bin/dispatch`, `bin/subagent`,
`bin/managent`, the stub worker) against a scratch git repo and a scratch
kanban under `/tmp/weizigo`. It exists so that the S06 consolidation
(ORC-PLAN-3: absorb the fleet scripts into `managent`) can move functionality
while a net catches every break.

**Run it (the one documented command):**

```sh
python3 tests/roundtrip/test_dispatch_lifecycle.py
```

(also: `python3 -m unittest discover -s tests/roundtrip -p 'test_*.py'`).
Measured wall on 2026-08-23: **70.6 s**, deterministic, no network, no
providers, no live-store or live-ledger writes.

## What this tier is NOT

This is **not a unit tier**. Every arm spawns processes; the arms are
black-box at the dispatch boundary. Per T789 it is a **pre-commit-adjacent /
pre-consolidation gate** — run it before any commit that touches
dispatch/subagent/verification behaviour — and it must **never be mixed into
`tests/unit/`**, whose contract is hermetic, function-level and
no-subprocess (tests/unit/README.md). The function-level half of this
subject already lives there (`tests/unit/test_dispatch_verify.py`,
`test_subagent.py`, `test_runner.py`); this tier is the end-to-end half.

The seam it rides on was built for exactly this and is 96% unused: only 3 of
75 `tools/regression-*.sh` arms use `--test-worker`/`--test-root`
(`regression-dispatch.sh`, `regression-dispatch-verification.sh`,
`regression-directive-kill.sh`). This tier is the seam's main customer.

## The two-plus-one labels (T797 rule)

Every arm is labelled, in its name or its first line, as exactly one of:

| label | meaning | life |
|---|---|---|
| **OUTCOME** | what the system must achieve, stated without naming which script achieves it. *"A dispatched row reaches a verified close." "A worker that never read its bundle fails." "A row left in_progress after the worker exits fails whatever the exit code."* | **Survive** both consolidation into `managent` and interface simplification. These are the net the consolidation swings on. |
| **SCAFFOLD** | today's interface: this flag, this stdout line, this file path. Written to catch *accidental* change while functionality moves. | **Deliberately deleted in the same commit that intentionally changes that interface.** Each SCAFFOLD arm names the ORC-PLAN-3 step it dies with. |
| **PINNED-DEFECT** | behaviour already known wrong, pinned faithfully with the owning row. Characterization preserves bugs consciously; consolidation carries them across unless they are marked (the T711 lesson: the control injected the tenant footprint and three lanes died to the detector's blindness). | **Recorded as `@unittest.expectedFailure`** so the tier stays runnable while the defect stays visible; the run summary counts them separately. |

An unlabelled arm is the defect this rule exists to prevent: an unlabelled
test is assumed OUTCOME by the next reader, and deleting it looks like
cheating.

## The arms

| arm | label | colour (2026-08-23) | what it pins |
|---|---|---|---|
| happy path: dispatch → stub works → row closes pass → work lands | OUTCOME | GREEN | the lifecycle itself, through `bin/dispatch` (nohup detach, poll to done, deliverable on disk) |
| exit 0 without reading the bundle fails on the nonce | OUTCOME | GREEN | the 2026-08-23 ox-alpha double-catch (two lanes, exit 0 in 38 s and 64 s) — a standing arm |
| declared deliverable absent at verification time fails on deliverables | OUTCOME | GREEN | sabotage model: write+commit+close, then delete — the only honest way to reach verification with a deliverable missing (the done gate refuses an uncommitted/missing deliverable, T278) |
| row left in_progress fails for exit 0 and non-zero; died worker leaves no zombie | OUTCOME | GREEN | the kimi incident (rc=0 + open row) and the died-worker case (rc≠0, healed back to dispatchable) |
| fail-found with the work done verifies PASS | OUTCOME | GREEN | "believe the work, not the text" (T411) — the verdict text is trusted in neither direction |
| **silent-but-working lane not failed as dead** | OUTCOME | **RED — owners T785/T773** | the T735 class: 40 turns, 19,060 output tokens across 600 s, recorded *"produced no output since launch (bundle never read?)"*. At the round-trip seam the runner's liveness fuse is not present (`--test-worker` bypasses `tools/runner`), so the round-trip manifestation is the verifier's nonce-echo check failing a fully-worked silent lane |
| **empty `deliverables=` reports unverifiable, never pass** | PINNED-DEFECT | **RED — owner T793** | same SHOULD as `tests/unit` `TestVerifyDispatchEmptyDeliverables` (`@unittest.expectedFailure` there too) — the two tiers agree. A PASS resting on the nonce alone is exactly the self-report the verifier refuses to trust |
| dispatch one data line + `untracked/log/t<id>.log` + `[verify] verification PASSED` | SCAFFOLD | GREEN | the surfaces the operator greps. **Dies with ORC-PLAN-3 step 5 (dispatch/subagent rewire)** |
| `--test-root=` / `--test-worker=` accepted by both front doors | SCAFFOLD | GREEN | the seam spelling the whole tier rides on. **Dies with ORC-PLAN-3 step 5** |
| the two verbatim nonce prompt lines reach the worker | SCAFFOLD | GREEN | the worker-side instruction contract (real agents parse these lines). **Dies with ORC-PLAN-3 step 5** |

Counts: **6 OUTCOME · 3 SCAFFOLD · 1 PINNED-DEFECT** = 10 arms.

### SCAFFOLD disposal schedule (one paragraph)

All three SCAFFOLD arms die with **ORC-PLAN-3 step 5 (dispatch/subagent
rewire)** — the step that reads the policy file + provider registry and moves
dispatch's gate logic into `managent`. They pin (a) `bin/dispatch`'s one data
line and the `untracked/log/t<id>.log` convention plus the `[verify]
verification PASSED` summary, (b) the `--test-root=` / `--test-worker=` seam
spelling on both front doors, and (c) the two verbatim nonce prompt lines
(`VERIFY-NONCE: …` / `Begin your final reply with exactly the line: …`).
When step 5 re-spells any of those, delete the corresponding arm **in the
same commit** and update this README's run instruction — the OUTCOME arms
carry the behaviour forward, so nothing is lost by the deletion. No SCAFFOLD
arm in this tier dies with steps 1–4 or 6: steps 1–3 (policy reader, arbiter,
dashboard) and 6 (provider seam) have no surface here, and step 4
(registration flow) is the surviving `regression-managent-*` suites' domain,
not the dispatch lifecycle's. The six OUTCOME arms and the PINNED-DEFECT arm
have no deletion trigger at all.

## The stub worker

One script, shared by every arm, parameterised **entirely by environment**
(`STUB_*`), written to the scratch repo as `stub.py` at arm setup. It parses
the task id, model, deliverables and nonce **out of the prompt** — exactly as
a real agent must — then behaves per its configuration:

| env | default | effect |
|---|---|---|
| `STUB_CLAIM` | 1 | run `managent claim <id> --agent <model>` |
| `STUB_WRITE` | 1 | write + git-commit every declared deliverable |
| `STUB_CLOSE` | 1 | sleep `STUB_SLEEP`, then `managent done --status STUB_VERDICT` |
| `STUB_ECHO_NONCE` | 1 | print the nonce as the final stdout line |
| `STUB_PROGRESS` | 0 | print interim working lines before the nonce |
| `STUB_SILENT` | 0 | print **nothing** (no nonce, no progress) |
| `STUB_VERDICT` | pass | the `done --status` value (e.g. fail-found) |
| `STUB_SABOTAGE` | 0 | delete the deliverables **after** done |
| `STUB_EXIT` | 0 | the stub's exit code |
| `STUB_SLEEP` | 11 | seconds between claim and done (the T390 claim-to-done gate demands >10 s; 11 is the fleet stubs' own choice) |
| `STUB_PROMPT_FILE` | — | write the whole prompt there (diagnostic side effect, not stdout) |
| `STUB_MARKER` | — | write the nonce there (diagnostic side effect, not stdout) |

Every failure mode the fleet has actually seen is one configuration:

| fleet failure | stub configuration |
|---|---|
| kimi lazy "OK." (exit 0, nothing) | `STUB_SILENT=1 STUB_CLAIM=0 STUB_CLOSE=0 STUB_WRITE=0 STUB_EXIT=0` |
| ox-alpha exit-0-without-work (2026-08-23, 38 s/64 s) | same as above |
| claimed-then-abandoned (rc=0, row open) | `STUB_CLAIM=1 STUB_CLOSE=0 STUB_WRITE=0 STUB_EXIT=0` |
| died worker (crash/timeout after claiming) | `STUB_CLAIM=1 STUB_CLOSE=0 STUB_WRITE=0 STUB_EXIT=1` |
| sabotage (deliverable destroyed after close) | `STUB_SABOTAGE=1` |
| silent-but-working (T735: stdout silence ≠ no work) | `STUB_SILENT=1` with full claim/write/close |
| honest fail-found | `STUB_VERDICT=fail-found` |
| empty `deliverables=` declaration | no stub change — the bundle header declares nothing |

## Isolation (never the live repo)

Each arm builds its own scratch repo under `/tmp/weizigo/t797-rt-*`
(disposable outputs only, per AGENTS.md) and points everything at it:

- `MANAGENT_STORE` — scratch kanban store
- `WEIZIGO_MODEL_PERF` / `WEIZIGO_DISPATCH_HEALS` — scratch telemetry
- `REAL_MG` — the real `bin/managent` binary, run with the scratch store
- a `bin/weizigo-claimlint` symlink + minimal `docs/epistemic/CLAIMS.md` in
  the scratch repo (the T485 done-gate substrate, exactly as
  `regression-dispatch*.sh` provision it)
- `WEIZIGO_AGENT_DEPTH` is unset (a stale depth stamp from a worker-run
  suite would trip the delegation-cap control)

`WEIZIGO_DISPATCH_VERIFY_UNPINNED=1` is set deliberately: `bin/subagent`
pins `tools/dispatch_verify.py` to HEAD (T631) to protect **live**
dispatches from a mid-edit verifier. This tier is not a live dispatch — it
is the consolidation net, whose job is to catch in-flight edits — so it
tests the **working tree**. If the tier ever runs as a pre-commit gate
(T789), the working tree is exactly the about-to-be-committed state.

## Wall budget (measured 2026-08-23)

**Total: 70.6 s.** The cost driver is the **T390 claim-to-done gate**: a
closing stub must sleep >10 s between claim and done (the honest path the
fleet actually runs — the existing regression suites sleep the same 11 s),
and **six of the ten arms close a row**: happy path 11.8 s · dispatch
data-line 11.8 s · empty-deliverables 11.4 s · silent-but-working 11.3 s ·
deliverables-absent 11.4 s · fail-found 11.4 s — **69 s of the 70.6 s**.
The four non-closing arms cost <1 s each (0.3–0.5 s). A tier nobody can run
rots the way `suite-truth.md` went stale while reading as authoritative —
at ~70 s this one is runnable before every consolidation commit, and the
moment the T390 window gains a test override, the tier's wall drops to
~2 s with no arm changes.

## What is out of scope here

Real providers, real tokens, real wall time (they belong to T790's use-case
suite in the scheduled tier — they cost money and need providers up). No
consolidation work is done by this tier; it only builds the net. `build.zig`,
`suite-truth.md`, `tests/unit/*` and the six absorption targets are
untouched.
