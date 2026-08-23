# S06 orchestration refactor — STATUS

**This file is the sprint's live source of truth.** Per pass: its arms, their colour, what was
absorbed, what was deleted, what is owed. **Owner:** T802 · **Last updated:** 2026-08-23 at
`8c00704` by `claude-opus-5`/T802.

**Landmark:** advances **L1 (hands-off orchestration)** — the fleet stops having two ways to do
everything. The bar is `tools/orcha-acceptance.sh` green three consecutive days **on the new
mechanism**, plus one-edit model onboarding, plus one pane (ORC-ACC-1).

---

## Where the sprint is

**Pass 0 (the owed pre-work) — COMPLETE. Passes 1–6 — NOT STARTED, and BLOCKED on ratification.**

The spec is now **rev 2**: T778's eight audit findings are discharged and four more, found while
writing the arms, are recorded. **Three of those four change what a pass must build** (the fourth
cooldown mechanism, the dashboard's non-overlapping section set, the appetite dial that does not
exist), so pass 1 cannot begin on rev 1's instructions. **The one thing owed by someone other
than a worker row is operator ratification of rev 2.**

### Scope note on this row

T802's bundle describes a sprint console that writes and dispatches leaf briefs. Its dispatch
line said the opposite — *"You are a leaf: you are at the delegation cap and do not dispatch"* —
and the dispatch line governs. T802 therefore executed Pass 0 **itself** and dispatched nothing.
Passes 1–6 are leaf rows that still need minting and dispatching by a console that can dispatch;
the "owed" table below is the mint list.

---

## Pass 0 — owed before any absorption

| item | state | evidence |
|---|---|---|
| 1. Discharge T778's audit | **DONE** | `spec.md` §14 rows 1–8; 8/8 findings dispositioned in the ids they affect, not in an appendix |
| — arm the four load-bearing ids | **DONE** | POL-3, POL-4/GATE-2, DASH-4, ARB-4 armed; **armed count 22 of 31**, the 9 unarmed enumerated by id in ORC-CTRL-1 |
| 2. Characterization before repair | **DONE** | 13 GREEN characterization arms pinning today's behaviour of all six targets, each naming the ORC-PLAN-3 step it dies with |
| 3. The census question per target | **DONE** | the table below — absorb/delete decided per target on import/exec evidence |
| 4. Four findings of T802's own | **RECORDED** | `spec.md` §14 rows 9–12; `findings/T802-consolidation-sprint.json` |

### The arms Pass 0 added

`tests/unit/test_s06_conformance.py` — **24 arms, 0.04 s**, hermetic (stdlib only, no subprocess,
no writes; the `tests/unit/README.md` contract holds). It reads tracked source text, because the
facts under test are *declarations* in shell-with-embedded-Python, Zig and POSIX sh — none
importable, all declarative.

| group | arms | colour | label |
|---|---|---|---|
| `TestParsersHaveSubjects` | 2 | GREEN | null + seeded control **for this file's own regexes** — four extractions carry half the file, and a regex matching nothing would pass everything vacuously |
| `TestAppetiteDial` | 6 | 4 GREEN, 2 RED | POL-1/POL-3 |
| `TestCooldownMachine` | 3 | 2 GREEN, 1 RED | POL-4/GATE-2 |
| `TestOnePane` | 3 | 2 GREEN, 1 RED | DASH-1/DASH-4 |
| `TestAttestedIdentity` | 3 | 2 GREEN, 1 RED | ARB-4 |
| `TestDispositionCount` | 3 | GREEN | PLAN-4/PLAN-5 — null control, seeded control, live check |
| `TestAbsorptionTargetsAreLive` | 4 | GREEN | the census, on import/exec evidence |

**7 RED arms, every one correct to be red** (ORC-CTRL-2: red first). Each is
`@unittest.expectedFailure` naming the ORC-PLAN-3 step that owes the mechanism, so the suite stays
green while the debt stays visible and countable. **A pass is not done until its red arms are
green** — that is what makes them the pass gate rather than a wish list.

### Tier colours at `8c00704`

| tier | result | wall |
|---|---|---|
| `tests/unit/` | **324 tests, 0 failures, 9 recorded defects** (4 pre-existing + 5 new S06 RED) | 0.21 s |
| `tests/roundtrip/` | **exit 0** — 10 arms, 6 OUTCOME / 3 SCAFFOLD / 1 PINNED-DEFECT, its 2 recorded defects still open (T785/T773, T793). T802 added no arm here; its subjects were untouched | 68 s |
| `tools/smoke.sh` | **PASS** | 1 s |
| `tools/suite-truth.sh` | **not run by T802** — 906 s and it gates a *pass landing*, and no pass landed | — |

---

## The census — absorb or delete, one answer per target, on evidence

Never on static reachability alone: T771's correction is the precedent, where a basename grep
called a live gate dead. Two of these six were on a no-production-caller list and both gate every
dispatch.

| target | lines @`8c00704` | live? | evidence | verdict |
|---|---|---|---|---|
| `tools/window_policy.py` | 548 | **LIVE — gates every dispatch** | `import window_policy` at `bin/dispatch:88` **and** `bin/subagent:70` — both front doors | **ABSORB** (step 1) |
| `tools/directive_policy.py` | 176 | **LIVE** | `import directive_policy` at `bin/dispatch:87` **and** `tools/runner:128` | **ABSORB** (step 1) |
| `bin/dispatch` | 546 | **LIVE** | the front door; 205 of 364 provider executions | **ABSORB the gate, KEEP the door** (step 5) |
| `bin/subagent` | 858 | **LIVE** | the launch chokepoint; **+301 lines since `a1415fe`** | **ABSORB the provider seam, KEEP the chokepoint** (steps 5–6) |
| `untracked/watch-fleet.sh` | 311 | **LIVE — human-invoked only** | no `exec` from any producer; its caller is the operator's terminal | **KEEP as the thin wrapper; do NOT delete the pane** — see the open question below |
| `tools/fleet-keeper.sh` | 1169 | **RUNNING AND IDLE — 73 hours** | pid 99956, ppid 1, elapsed 3d04h; last dispatch `2026-08-20T18:25:26Z`; **8,747 consecutive** `cooldown flag set — no new dispatches` ticks; **21 rows dispatchable**; no code caller — its production shape is `tools/weizigo.fleet-keeper.plist`, and no launchd job is loaded | **ABSORB (steps 1–2), and the flag is the first thing the arbiter must own** |

**The keeper is the sprint's own headline, live.** It is not paused-and-forgotten in the abstract:
a zero-byte file with no owner, no reason and no expiry has stopped a running keeper from
dispatching for three days while 21 rows waited. Everything ORC-PAUSE-1 promises — scoped,
expiring, lapsing loudly, one dashboard row — is aimed exactly here, and rev 1's merge did not
include the mechanism (`spec.md` §14 row 9).

Two smaller facts from the same log, both live evidence for ids the spec argues on principle:

- **226 title-limit refusals across 6 rows.** The keeper's last two actions before going idle were
  refusals of T548 on a 41-character title. ORC-GATE-1 demotes display preferences to warnings on
  doctrine; this is the measurement — a taste gate blocked real dispatches, repeatedly.
- **`tools/fleet-keeper.sh` has no ox-alpha row at all**, so it resolves to `other` → SPEND by
  default fallthrough. It never honoured RESERVED for ox-alpha and is only accidentally correct
  since the 2026-08-23 ruling. Step 1's rule must be **unknown model → refusal, never a default
  appetite**.

---

## Passes 1–6 — arms, colour, and what is owed

Order per ORC-PLAN-3. Nothing has begun. Per pass: commit → deploy → smoke → the pass's own arms
green → then the next.

| pass | subject | its RED arms (the gate) | owed |
|---|---|---|---|
| 1 | policy file + `managent` policy reader | `test_appetite_dial_accepts_zero_through_nine_per_model` · `test_one_appetite_table_not_two` · `test_merge_list_names_every_cooldown_mechanism_that_exists` | design doc for the schema; the dial-vs-categorical `[design-open]`; **the flag file's replacement** |
| 2 | arbiter (+ absorbs T712, T713) | `test_store_write_authority_is_not_env_derived` | extend the existing `ps` reader, do not build a second (§14 row 12) |
| 3 | dashboard | `test_managent_renders_the_five_specified_sections` | **decide the section set first** (§14 row 10) — the specified five share nothing with today's five |
| 4 | registration flow | none yet — the registration battery is owed | one parser for `add`/`suggest`/`dispatch`; collision → refuse |
| 5 | dispatch/subagent rewire | none yet | **the 3 roundtrip SCAFFOLD arms die in this pass's commit**, per `tests/roundtrip/README.md` |
| 6 | provider seam | none yet | C14 measured against T732's 4 files / 65 insertions |

**ORC-PLAN-3's order, argued as the bundle asked.** The bundle invited an argument for putting the
**arbiter** first, since every guard defect routes through it. **The order stands: policy reader
first.** The arbiter's own store-write authority (ARB-4) and its shed decisions both need scoped,
owned, expiring entries to read, and the arbiter's first job is to own the flag file — which is a
*policy entry* problem, not a *dispatch loop* problem. Building the arbiter on four unmerged
cooldown mechanisms would make it the fifth place to look. The evidence that settles it: the
mechanism that has idled the fleet for 73 hours is a policy artifact with no owner, and step 1 is
where owners become required.

---

## The ten multi-way jobs — one door each?

Roadmap §6's census, plus an 11th found by T802. **Closed: 0 of 11.** Nothing has consolidated
yet; three rows are in flight and not T802's to redo.

| job | ways | state | owner |
|---|---|---|---|
| map short names | 2 | in flight | T800 |
| canonicalize a label | 4 | in flight | T801 |
| close a task | 2 | in flight (chained on `main.zig`) | T798 |
| dispatch an execution | 5 | **not started** | S06 pass 5 |
| register a task | 2 | **not started** | S06 pass 4 |
| record a kill | 4 stores | **not started** | S06 pass 2 (arbiter) + T798 |
| set a verdict | 2 flag names | **not started** | T775 (`main.zig` chain) |
| run tests | 6 entry points | **not started** | T789 (test-gate wiring) |
| name a task type | 2 taxonomies | **not started** | T786 (`main.zig` chain) |
| store a task | 2 files | **not started** | unowned — needs a row |
| **appetite table** | **2, disagreeing** | **found by T802, unowned** | S06 pass 1 |

Two rows here need naming, not just noting: **"store a task"** (two task stores) has no owner at
all, and **"appetite table"** is new. Both are pass-1/pass-4 work and neither is in the roadmap's
Started list.

---

## Open questions for the operator — the two bookends, nothing else

1. **Ratify spec rev 2?** (the shape bookend) Eight audit findings discharged plus four new ones,
   three of which change what a pass builds. Passes 1–6 are blocked until this is answered.
2. **The dashboard section set** — the one decision inside rev 2 that is a preference, not
   evidence. The five sections ORC-DASH-4 specifies share **nothing** with the five
   `watch-fleet.sh` renders today. Recommendation on record: render **both** groups as one pane
   under the omission rule, rather than replacing the daily task view with a fleet view.

Everything else in rev 2 was decided on evidence and recorded.

---

## Hard constraints in force (from the bundle, restated so a successor re-reads them)

- **`src/managent/main.zig` is serialized** behind `T772 → T767 → T768 → T775 → T786 → T798`.
  T802 held it for **nothing** — its arms only *read* it. Check `bin/managent status` before any
  pass-1 dispatch.
- `docs/infra/model-task-matrix.md` held by T800; `tools/token-capture.py`,
  `tools/model-profiles.py`, `tools/runner` held by T801. T802 wrote none of them.
- Titles ≤ 40 characters or dispatch refuses. **226 refusals in the keeper log say so.**
- `managent done` takes `--status`, not `--verdict`; an unrecognized flag is silently ignored and
  the verdict defaults to `pass` (T775 fixes it).
- No local model concurrently with a measured suite run; never co-launch a local model with cloud
  executions until the arbiter pass lands.
- **No new features, no new monitors while this sprint runs.** T802 added no monitor: it added
  arms to an existing tier and amended a spec.
