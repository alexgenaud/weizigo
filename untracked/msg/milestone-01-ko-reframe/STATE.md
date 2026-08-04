# STATE — milestone-01-ko-reframe

**THE CRASH-RECOVERY ANCHOR. Read this file first, before any message.**
Overwritten in place; always current.

Last updated: **2026-08-04, Opus 5 seated as Orcha** (handover from Fable completed; that
seat's account of the tree checked out — nothing was half-written).
Fable stays available for subtasks and audits under this Orcha's delegation.
Resume: `bin/managent resume`, then this file top to bottom.

## This seat's session (2026-08-04, Opus 5) — read before the Fable narrative below

**Three human rulings taken and executed:**

**T337 S5 restored the deploy gate (2026-08-04).** managent-integrity (T268) now wired into
zig build test — compares deployed bin/ stamps against committed source and FAILS the suite
on staleness.  Rule: commit → deploy → smoke, every time, or the suite is red for the whole
fleet.  The staleness gate that T295 §5 had turned into a warning is load-bearing again.
T337 S0 replaced the mkdir store mutex with flock(2) — the kernel releases on process death,
so exit(), SIGKILL and ESC'd consoles no longer wedge the fleet.

1. **The 4×4 artifact is deployed to `data/oracle-4x4-v2.wzo2`** (`98fae79`). This turned out
   not to be a naming question: **oracle-v2 spec §4 F9 had already ratified that path** with a
   hash-then-deploy rule, and the file had simply never been promoted out of the sprint build
   area. So it was *copied*, not moved — F9 says copy, and 48 tracked documents cite the
   `untracked/` path in as-run reproduction commands, which repointing would falsify. The copy
   was verified against the recorded build hash (`shasum -c artifacts/SHA256SUMS`, 12/12 OK)
   **and** engine-loaded (24,318,165 groups / 99,133,036 entries, 0 misses, 0 fallbacks) before
   anything was repointed. Both paths are pinned in `artifacts/SHA256SUMS`; the `untracked/`
   build stays the hash of record. Spec → **Rev 4**, plan → **Rev 3** (`6a0ece1`), path only —
   no check, number, edge, wave or decision touched, and the spec amendment log was backfilled
   with the Rev 2/Rev 3 rows the header had been carrying alone.
2. **`claude-fable-5` stays at 200 k** in `model-perf.md` (`952692d`). The mid-session jump to
   20.4%-of-1M is logged as a dated, unexplained anomaly, not a table change: a percentage a
   seat reads off its own status line is the subject reporting on itself, and the seat is gone.
   The note names the two evidence classes that would move the row.
3. **T328 (bake-off) runs after T317 lands** — a bake-off writes many rows on a store that is
   still lost-update-prone. The `needs T317` edge is **not yet recorded** (see owed list).

**T333 closed — plan Rev 2 delivered** (`0845ecb`), all six findings F1–F6 addressed, and the
worker did the instrument step: it parsed the WZO2 header itself and showed layout arithmetic
that checks out exactly (`128 + 24,318,165×5 + 99,133,036×4 = 518,123,097`).

**Its verdict field reads `blocked`, and that is wrong.** The row's declared deliverable was
`findings/T333-context.json`; the worker wrote the wrapper's `findings/T333-g3b-plan-rev2.json`,
hit the `done` deliverable gate, and closed `blocked` — reporting the two paths **with their
sources inverted**, believing the brief had named the wrapper's path. The gate-holder supplied
the dump (`61426af`, honestly attributed to this seat, since the worker's session was gone) and
re-stamped the agent to canonical `glm-5.2`. **`managent done` is terminal, so the verdict could
not be corrected** — hence this paragraph and `findings/T333-context.json`.

Three defects came out of that, all now written into T317's brief as scope items 5 and 6 with
seeded controls:

- **The brief-side defect (mine to own):** T329, T332 and T333 bundles each declared *only*
  `findings/<id>-context.json` and omitted the findings file, while `DELEGATOR.md:34-40`
  requires **both** by exact path — they are different artifacts, not two names for one. All
  three rows needed a remedial commit. Fixed at T334, which declares all three deliverables.
- **A misfire worth not repeating:** this seat added prose to T333's brief saying which of two
  findings filenames "wins". Prose naming two candidate paths gave a confused worker a coin to
  flip, and it flipped wrong. The wrapper must name the *declared* deliverables (T317 item 5);
  adjudicating prose is not the fix.
- **The ledger has no correction path** (T317 item 6): append-only `amend`, never a mutable
  verdict field.

**In flight right now:** **T334** (round-2 plan audit, kimi-k2.7, `bfhndw2fb`) — brief requires
an artifact parse with measured-vs-claimed numbers, because round 1's only critical finding came
from parsing a header after two document reviews missed the same defect. **Keep off the store
while it runs** (dispatches stay serialized, one worker in flight).

**T334 closed PASS-WITH-EDITS and the G3b pass0 plan is RATIFIED at Rev 5** (`fb22b9b`,
`2602e96`). The auditor did the instrument step: 17 header/memory figures independently
reproduced, including two the plan never claimed (max group `entry_count` = 8 against a bound
of 36; zero `passes=1` entries with `ko≠none`, the §2.5 invariant *checked* rather than quoted).
Its two findings: **N1** — a stale "spec Rev 3" reference that the gate-holder's own Rev 3
repoint had introduced (the gate caught the gate-holder); **N2** — MG-INV and KEY-4x4 both
declaring `holds=src/differential.zig`, substantively right but citing `spec.md:248`, a blank
line (the assignment is at `:278`). N2's first remedy was wrong and was corrected by reading
the source: `holdsConflict` (`src/managent/main.zig:976-991`) skips non-`in_progress` rows and
runs only at `claim`, so **declaring the hold is what mechanizes one-writer-at-a-time** and the
no-hold version would have enforced nothing. Rev 5 restored it.

## Human directives, 2026-08-04 — these change how this seat works

1. **Orcha delegates sprints; it does not manage their internals.** Given while this seat was
   hand-editing plan.md, writing dispositions and fixing a markdown table seam. Orcha's output
   is the delegation package and the set plan, not the artifacts inside it. Two console
   packages now exist for exactly this:
   - **T336 — fleet hardening** (dispatchable, set C): the seven orphaned rows run as one
     sprint. **T317 alone on a quiet fleet first**, then parallel sets S2-store
     (T319 → T322 → T326 → T327) ∥ S3-suite (T325) ∥ S4-register (T330) ∥ S5-bakeoff (T328,
     human-ruled after T317). Recommend **`deepseek-v4-pro`** — it must subdelegate.
   - **T335 — G3b build sprint** (blocked, set A): runs the whole pass-0 build phase per the
     ratified plan Rev 5 §11 waves, registers its own rows, holds its own gates, reports once
     at the pass boundary. Recommend **`deepseek-v4-pro`**, or `claude-sonnet-5` for a Claude
     seat — **not Fable**. Its kanban edge reads `needs T336`, which is **coarser than the real
     dependency**: the gate is T317 done + deployed. `managent` can only set `needs` at `add`
     time and cannot add or relax an edge afterwards, which is also why T328's ordering has to
     be enforced by a person. Worth a row of its own.
2. **`claude-fable-5`: hand over before 90% of 200 k, and use it sparingly.** A different
   billing regime is *believed* to apply below 200 k versus 200 k–1 M — the human's operating
   assumption, explicitly not officially confirmed, and not to be restated as fact. The rule
   binds either way, because the cost boundary and the window are different questions.
   Recorded in `model-perf.md` under the Fable row. Consequence: Fable is for highest
   value-per-token work only (deep holistic review, gate-holder verification of a
   fleet-critical control) — never cheap audits, never long-running orchestration.

## T336 ran and closed — the pass-boundary read (Orcha, 2026-08-04)

**4 of 7 rows delivered** by a `deepseek-v4-pro` console: **T317** (all six scope items,
including the store lock→re-read→write refactor, canonical-label validation, and the new
append-only `managent amend`), **T319** (`managent archive`; 96 rows archived, 10 live),
**T325** (10 consecutive suite runs, 0 failures — T314's flakiness did not reproduce),
**T322** (2 of 7 orphaned scripts wired, 5 deferred with reasons). Report:
`docs/infra/fleet-hardening-2026-08-04.md`. Verified by this seat rather than accepted:
`sh tools/smoke.sh` PASS with zero `STALE`, claimlint at floor.

**One fleet-critical regression found at the boundary, and the way it was found is the
point.** T317 item 2 canonicalized the model label and then passed the **canonical label**
to `ollama launch` instead of the **Ollama tag**. Control pair: `ollama show glm-5.2` and
`kimi-k2.7` → NOT FOUND; `glm-5.2:cloud` and `kimi-k2.7-code:cloud` → RESOLVE. **Every
Ollama dispatch would have failed, and four green suite runs said nothing.** Fixed at
`6a4023c` (launch uses `raw_model`; the canonical label stays in the claim/done lines, which
is what the item intended). It was found by dry-running a dispatch and probing both tags —
`sprint.md:93` again, for the third time in two days: instruments find defects, documents
and green suites do not. **The control that would have caught it is S1 of T337** and is why
that row goes first.

Smaller loose ends, all handed to T337: `findings/T323-orphaned-controls.json` actually holds
T322's findings (internal `task_id` is correct; the filename squats another row's namespace);
T322 closed `--skip-acceptance` on "suite passed prior to commit"; C7 unabsorbed findings is
at **9**, so `STANDING-ABSORB` should fire; 7 of 12 mutating commands still use the unhardened
`writeState` wrapper; `cmdShow` does not surface the `amendments[]` records that the new
`amend` command writes, so a corrected verdict is invisible in the surface a human reads.

**Two console packages are dispatchable now, both self-contained:**

- **T337 — fleet hardening round 2** (set C): S1 dispatcher control (first, alone) → S2-gtp
  T326 → T327 ∥ S3-register T330 ∥ S4-absorb ∥ S5-orphans (5 scripts) ∥ S6-store. Recommend
  **`deepseek-v4-pro`** — it must subdelegate, and the same model ran T336 well.
- **T335 — G3b build sprint** (set A): the whole pass-0 build phase per ratified plan Rev 5
  §11 waves. **Its `needs T336` edge is now satisfied** — T336 is done, T317 landed, the store
  is safer. Recommend **`deepseek-v4-pro`**, or `claude-sonnet-5` for a Claude seat. **Not
  Fable.**

## CLOSE-DOWN STATE, 2026-08-04 — two consoles were still live when this seat stopped

**READ THIS BEFORE ANYTHING ELSE. The tree was not quiesced at handover, by design:**

- **T335 — G3b build sprint: `in_progress`, and `bin/managent liveness` reports
  `stale: no heartbeat recorded`.** A console claimed it and never emitted a heartbeat, so
  whether it is working or dead cannot be told from the store. **At close-down its console was
  ALIVE** — two `pi` processes running, no commits yet. So: **`ps aux | grep "[p]i "` is the
  reliable signal, `bin/managent liveness` is not.** Check the process first, then
  `git log --oneline -15`. Only if the process is gone *and* there are no T335 commits is the
  row dead, and then `bin/managent done T335 --fail` with a note plus a re-registration against
  the same brief — do not silently re-dispatch a claimed row.

  **Why `liveness` is uninformative: nothing feeds it.** `managent ping` exists and workers do
  not call it, so every long-running row reads `stale: no heartbeat recorded` whether it is
  working or dead. An instrument with no input is worse than no instrument, because it reads
  like evidence. Either have the dispatch wrappers ping on the worker's behalf, or have
  `liveness` fall back to process inspection and say which signal it used. Unregistered —
  give it to T337's S6 or its own row.
- **T337 — fleet hardening round 2: delivered S1 and one loose end, but its row still reads
  `dispatchable`.** Commits `3cbaecf` (the dispatcher regression: 6 controls — 3 tag pairs,
  depth cap, the mechanized `OLLAMA_TAG_TO_CANONICAL` ↔ `canonical_models[]` cross-check, and
  a seeded defect — wired into `zig build test`) and `693f075` (the T322/T323 findings rename).
  Its console worked without holding the row, so the store understates what is done. Read
  `git log` before re-dispatching, or S1's work will be repeated.
- Two `pi` processes and a `zig build deploy && smoke` were running at close-down.

**The suite, measured properly (this seat, at HEAD):** `zig build test` → **EXIT=0**,
**3:14.12 wall, 269.99 s user, 145% CPU**. Green. But **T325's verdict says 39.9 s mean over
10 runs** — a 5× discrepancy in one evening. Candidates: the regression scripts newly wired by
T322 and T337 S1, `.zig-cache` contention from concurrent consoles (T325's own hypothesis for
T314's flakiness), or a colder cache than T325's runs. **Not resolved.** It matters because a
3-minute suite changes how often anyone runs it, and because four closes tonight cite "suite
green" without a time. This is the second half of T337's S1b row.

**Also unresolved, and recorded in T337 S1b:** the green suite prints **`failed command:` six
times**. Every instance follows legitimate diagnostic output (colex bijection VERIFIED, S2-4x4
Benson counts, I5 BFS/Tarjan metrics, `vb_mutants`' `A1 REFUSAL`/`A2 L-VIOLATION`/
`A2 H-VIOLATION` on `stored L=99 expected L=0` — seeded controls working). Best-supported
reading: Zig re-runs a test that writes to stderr without `--listen=-` to surface its output
and announces that with `failed command:`. `build.zig` declares no `expectExitCode`, so
nothing is tolerated by configuration — **confirm against the artifact hashes before acting.**
This seat first misread it as a red suite, which is the point: the gate's output is not legible.

**Absorption is queued, not done.** `STANDING-ABSORB` is registered and dispatchable (set H).
**C7 = 10 unabsorbed**, and claimlint FAILS on C7 (the pre-commit floor covers C1a/C1b/C2/C6
only, so commits still pass). Four are tonight's infrastructure claims
(`CODE.MANAGENT-MODEL-VALIDATION`, `CODE.MANAGENT-LOST-UPDATE`, `CODE.MANAGENT-AMEND`,
`CODE.MANAGENT-ARCHIVE`, `CODE.REGRESSION-WIRING`); the rest are older solver claims
(`CODE.T312-PARALLEL-FIXPOINT`, `GLOBAL.Z-R-MOVE-B1-EQUIV`, `CODE.PARALLEL-FIXPOINT-MEASURED`,
`CODE.WZO2-RELEASESAFE-INV`) whose absorption is **not** mechanical: DIRECTION Amendment 2
edge 5 gates promotion on mutation adequacy, so several belong at `CLAIMED` with a rationale
rather than at the status their findings propose. **This seat deliberately did not hand-edit
the register at close-down**: `CLAIMS.md` is single-owner, T330 is queued against it, and two
consoles were live. Sequence it: absorption **or** T330, never both.

**Dispatchable tomorrow, in this order:** `STANDING-ABSORB` (set H) · **T337** continued
(S1b → S2-gtp T326 → T327 ∥ S3-register T330 ∥ S4-absorb ∥ S5-orphans ∥ S6-store) · **T335**
re-checked or re-dispatched · T328 whenever. Recommend `deepseek-v4-pro` for both console
packages; `kimi-k2.7` for audit gates; `glm-5.2`/`minimax-m3` for leaf rows. **Never Fable** —
hand a Fable seat over before 90% of 200 k and use it sparingly (human directive above).

**What this seat got wrong tonight, for the next seat's calibration:** three of my own errors
were caught by instruments or auditors rather than by me — a stale spec-revision cross-reference
the round-2 auditor found, a markdown table seam from an append without a trailing newline, and
a `zig build test` piped into `tail` whose exit code I reported as the suite's. The fourth I
caught myself only by dry-running a dispatch: T317's canonicalization had broken every Ollama
dispatch while four green suites said nothing. The pattern is the project's own standing
lesson, and it applies to the Orchestrator seat as much as to any worker: **run the instrument,
do not read the document.**

**Where things stand — the G3b commissioning pipeline ran three gates tonight:**

- **T324 VERIFIED and RULED** (`b73c750`): retire 108, defer 8 — the eight ⚑ rows stay
  defer per the human's delegation; verification + a caveat (the "SOLE evidence" wording
  is overstated; every error conservative) in the sheet's §Ruling. Follow-up register
  surgery is **T330** (nine edge re-points in CLAIMS.md, completes the deferred 8).
- **G3b spec: RATIFIED at Revision 3.** Rev 2 (`f0769ac`): T329 spec audit (kimi,
  PASS-WITH-EDITS, 10 findings) dispositioned, one auditor edit rejected with rationale
  (I4 independence shortcut). Rev 3 (`ead66d0`): **premise fix — the sprint artifact is
  `untracked/oracle-v2/oracle-4x4-v2.wzo2` (WZO2, SHA-256 `0c3366f0…`), NOT
  `data/oracle-4x4.checkpoint.wzo`** (WZO1, 2026-07-21, PSK-era residue; no ko/passes
  dimension — cannot hold the k=1 state). Revisions 1–2 named the wrong file; both
  document reviews (T329 and the gate-holder) missed it; **T332's plan audit caught it by
  parsing the artifact header** — `sprint.md:93`/`:100` confirmed yet again: document
  review finds nothing, instruments that touch the artifact do.
- **G3b plan: Revision 1 is NEEDS-FIX** (T331 wrote it, `8e7f33b`; T332 audit at
  `ead66d0`-committed report `archive/plan-audit-r1.md`). Disposition (same file,
  §Gate-holder disposition): F1 confirmed + re-rooted into the spec (fixed by Rev 3;
  plan must rebuild §2.1 closure membership + memory budget against the real WZO2
  schema); F2–F5 accepted; **F6 added by gate-holder**: ko-dimension coverage — SMD1's
  `ko=NONE` slice makes I11 structurally blind to ko-rule disagreements at every rung
  (the spec's ko-recapture seeded control was blind by construction, fixed in Rev 3);
  MG-INV's differential must explicitly compare at ko≠NONE states. **T333 registered and
  dispatchable** (plan Rev 2, glm-5.2, brief `untracked/T333-g3b-plan-rev2.md`); round 2
  of 2 re-audit follows it (register T334, same T332 pattern — encourage artifact-parse,
  not just document review).

**The next Orcha owes, in order:**
1. **Dispatch T333** (plan Rev 2, glm — Ollama path works from a Claude seat:
   `bin/managent dispatch T333 --to glm-5.2 && bin/ollama-subagent T333 --model
   glm-5.2:cloud`). When it closes: register + dispatch the round-2 plan audit (T334,
   kimi worked well twice), disposition, ratify plan.md, then decompose build rows per
   the plan's §5 row table (MG-INV ∥ R8 is wave 1). **Re-stamp `bin/managent agent <id>
   <canonical>` after every Ollama claim** — the dispatcher injects raw tags
   (`kimi-k2.7-code:cloud`, `glm-5.2:cloud`), the pre-T317 wart.
2. **Dispatch T317 SOLO once the fleet is quiet** (human console — deepseek). Its brief
   carries the lost-update incident as scope item 4 (flock + reload-before-write, seeded
   interleaving control) **and** the ollama-subagent raw-tag injection fix (post-T317
   validation would otherwise refuse every Ollama claim).
3. **After T317:** T319 → T322 → T325 (minimax) and T330 (glm) — T330 is CLAIMS.md-only
   but held until T317's store fix lands (concurrent workers on the unfixed store is the
   lost-update recipe). T326 → T327 behind T322. T328 (bake-off, set A) whenever the
   human likes.
4. **Open with the human:** (a) T328 timing; (b) the Orcha-seat trial question
   (deepseek/glm, measured, T316-style) — partially mooted by the human seating Opus 5;
   (c) **a context-window observation for the ruled table**: the Fable seat measured a
   jump from 96%-of-200k to 20.4%-of-1M mid-session (2026-08-04) — contradicts
   `model-perf.md` §Context windows (Fable 200k, human-ruled); needs a ruling, not an
   edit; (d) the canonical 4×4 artifact lives under `untracked/` ("where evidence goes
   to die") — reproducible nine ways so low-risk, but naming it in a RATIFIED spec makes
   the wart load-bearing; consider promoting to `data/` or an ignored-but-blessed path.

**Division of labour (human-ruled at handover): Opus 5 = Orchestrator; Fable takes
subtasks and audits independently** — dispatch Fable-sized work (deep holistic review,
gate-holder verification) to a Fable console rather than spending the Orcha window on it.

**Lost-update incident (2026-08-03 late evening), kept for T317's worker:** T326's
registration (committed `d56744f`) was erased by a stale read-modify-write from the T323
worker's console; the erasure landed in Orcha's own `3aefed4`; re-registered at `0b75416`.
`managent` store writes need flock + reload-before-write (or CAS on a store generation),
not just per-command reads. T314's flaky-suite observation (T325) is the same lesson:
instruments and stores that are only *usually* consistent.

**Language ruling (human, 2026-08-03 late evening), binding on plan.md:** no Kotlin
immediately. **If/when a third re-implementation language is adopted, it will be Kotlin**
— not Go, not Rust; the Android aspiration is the tie-breaker. Until then the
re-implementation languages are Zig (production kernel) and Python (battery checks);
plan.md's feasibility row decides only *whether* the 4×4 sweep needs the third language,
not *which* it is. Other rulings tonight: credential-strip rejected; retirement decision
delegated inward (T324 sheet awaits Orcha verification + RULING pass); G3b sprint ruled
and commissioned by Orcha; Claude-dispatch rule clarified (harness, not dispatcher —
`subdelegation.md` §Clarified, commit `c98deed`); canonical context windows recorded in
`model-perf.md` (Fable 200 k, Opus 1 M, deepseek/glm 1 M, minimax 524 k, kimi-k2.7 262 k).

## Read this first: what a fresh seat needs to know

**The 4×4 artifact is reproducible three independent ways** — the original T184 build, T310's
ReleaseFast rebuild, and T313's **ReleaseSafe** rebuild with overflow and bounds checking on:
all three give SHA-256 `0c3366f0…` at 518,123,097 bytes, 31 sweeps, `root_B(L=1,H=16)`, and
T313 recorded **zero safety-check panics** through census, fixpoint, DTT and write. So G3a's
evidence no longer rests on one run, and the builder does not depend on undefined behaviour.
It says **nothing** about G3b value correctness — reproducibility reproduces bugs exactly.

**Three decisions are owed by the human** (see §Owed):
option (c) on credential stripping; the 116-row retirement ruling; whether the next sprint is
G3b.

**Three process facts learned the expensive way today**, all now costed:

1. **`sprint.md:93` already says document review has found zero of this project's real
   defects.** T316 spent three dispatches re-deriving that: single bounded worker 6/6 planted
   defects with 0 false positives; audit loop 0 new finds at 2× cost; sprint arm 4.5–5/6 with
   2–3 false positives. **Read `docs/infra/sprint.md` before designing any process work.** The
   gate that *does* find defects is `:100` — independent re-implementation, different model,
   ideally different language — and it remains untested here.
2. **Declare the files the work TOUCHES, not the artifact you imagine.** Five rows refused to
   close on invented deliverable paths, twice under `untracked/` which `sprint.md:62` calls
   where evidence goes to die. A row that lints needs `claimlint.zig`; a row that wires a test
   needs `build.zig`; a row that measures needs to compile — and **a row that merely compiles
   collides with whoever owns `build.zig`**, which killed T313's first attempt.
3. **Prefer tool-written records to agent narration, and never let a probe's subject produce
   its own proof.** `untracked/heartbeat.jsonl` (written by `tools/runner`) settled a question
   four agent reports had muddled. A probe must not contain its answer, and `exit 0` is not
   evidence a child returned anything.

**Delegation reach, now settled by real dispatches** (probe asked a question whose answer was
not supplied; every cell corroborated by heartbeat):

| dispatcher at depth unset | → DeepSeek | → Ollama |
|---|---|---|
| human console | works | works |
| `deepseek-v4-pro` | works 4.0 s | works 5.3 s |
| `glm-5.2` | **works 4.5 s** | works |
| `claude-opus-5` (this seat) | dry-run only | works (kimi 4.2 s, minimax 5.4 s) |

At depth ≥ 2 `bin/subagent` and `bin/ollama-subagent` refuse; **raw `ollama launch pi` does
not, and `DEEPSEEK_API_KEY` is readable inside Ollama workers.** So the cap is a safety
mechanism, not a boundary — exactly as `subdelegation.md` always claimed.

**Attribution: never ask a model who it is.** Asked to report `PI_MODEL`, 4/4 correct; asked
what model they *believe* they are, 2/2 wrong (`deepseek-v4-pro` → `claude-opus-4-5`,
`glm-5.2` → `GPT-5`, neither string on disk beforehand). `bin/subagent` now injects
`--agent <model>` into the claim and done lines (T315); `managent add` still has no `--model`,
so **run `bin/managent agent <id> <model>` right after registering a row** until T317 lands.

**Seven of sixteen regression scripts are orphaned** — present but not in `zig build test`:
`depth-enforcement`, `subagent-prompt`, `managent-integrity` (16 checks!), `managent-done-git`,
`managent-memory-safety`, `git-commit-mine` ×2, `T227`. Registered as a row; until it lands the
suite has blind spots and `managent-integrity` only runs when someone types it.

**Two live findings not yet fixed** — both are gates that stopped gating:

1. **T295 §5 turned smoke's staleness check from an error into a warning** (`FAIL=1`
   removed from the only staleness branch in `deploy_check`). It has now hidden a real
   condition **twice in one night**: T295's own undeployed fix, and T292's `build.zig`
   commit which staled all seven binaries while `zig build test` stayed green. T292's brief
   demanded "green on a correctly deployed tree" and its acceptance passed without that
   being true. **Recommend reverting to `FAIL=1`**, or narrowing scope to `build.zig`
   step-wiring. Until then, `sh tools/smoke.sh` output — not the suite's exit code — is the
   only evidence a tree is correctly deployed.
2. **claimlint truncates to 491 bytes when stdout is a regular file** (pipe/TTY give
   ~31 KB, and the `== SUMMARY ==` block is missing entirely from the fragment). Registered
   as T307. The hook pipes, so the floor is unaffected.

## How to resume (the surface changed on 2026-08-03)

`docs/status/CURRENT.md` **no longer exists** — T286 deleted it and replaced it with a
surface composed at read time. So:

1. **`bin/managent resume`** — kanban, gate counts against the floor, recent commits, tree
   state, and this file by reference. Nothing stored, so nothing to go stale.
2. **This file** for the narrative (what happened and why it matters).
3. `docs/audits/grand-audit-2026-08-02/DIRECTION.md` — ratified, governs, **plus
   Amendment 1** (ratified 2026-08-03).
4. `docs/epic-01-markovian/PHASES.md` — the tracked phase→task map, including the G3 split.

If `bin/managent resume` says "unknown command", `bin/` is stale: run `zig build deploy`.
That is also what a red `zig build test` means when 380/380 tests pass — smoke puts
`build.zig` in every tool's source scope, so any `build.zig` commit stales all seven
binaries at once (T295 §5 is ruling on it).

## The headline, 2026-08-03: the 4×4 is structurally complete and value-unverified

**The G3 blocker is gone, and that clears less than it sounds like.** `CODE.WZO2-INCOMPLETE`
is FALSE-AS-SCOPED: the ~6.77M missing entries were **131,068** genuinely unreachable
single-colour gobans — T261's figure came from the first 5,000 groups in colex file order,
overstated 51.7×. T266 measured it, **T277 independently re-derived all five checks with
fresh instruments** (zero exceptions over 24,318,165 groups), T279 absorbed it.

So **G3 is split** (`PHASES.md`): **G3a structural completeness — discharged**;
**G3b value correctness — untouched**. The L/H values inside the entries have been tested by
nothing; C-A1/C-A2 closure is specified and unrun and needs the Phase 2 kernel. Do not
describe the 4×4 as solved. `PROGRESS.md:463` still does — that is T296.

**The MIGOS +2 anchor was the wrong anchor.** MIGOS's long-cycle-tie value is 0 (ours) and
its **basic-ko 4×4 result is +1** (ours, thesis Table 5.1); the +2 comes from a different
cycle-resolution rule (T274). `GLOBAL.TIE-MIGOS` is FALSE-AS-SCOPED. The "acceptance
failure" was a comparison against a different game.

**The 716-gap escalation is ruled** (T287, Auditor): the *check* was wrong, the solver is
fine. 716 L<H at 2×2 is the genuine fixpoint — reproduced bit-identically, 0 Bellman
violations, one witness traced end to end — and axiom E3 says L<H is the honest output where
the state does not determine the value. Absorbed by T288.

## The ruling of 2026-08-03: phase order is dependency order

The human ruled that **phase sequence must not be ceremony**: prerequisites come first where
a real dependency exists, and otherwise Phase 0/1 work proceeds while Phase 2 is in flight.
"Battery before code" binds **promotion, not dispatch** — code may ship while its coverage is
incomplete, but no claim about it is promoted past `CLAIMED` until the battery kills the
mutants covering that function (a mutation-adequacy criterion: DeMillo–Lipton–Sayward 1978;
Budd 1980). The decisive evidence that this is §5's correct reading rather than a relaxation:
§5's own Phase 1 contents already depend on Phase 2 (C-A1/C-A2 need the kernel move
generator, `PHASES.md:82`), and T273 already held both kernel claims at `CLAIMED` "pending
Phase 3" in practice — only the rule was missing.

Five dependency edges replace phase-gating (full text is T304's payload, headed for
DIRECTION Amendment 2): closure checks ← kernel; moving a function ← an invariant that
**kills its own mutant** (the T265 tautology is why that clause exists); Phase 3 ← battery +
register-to-tree mapping; Phase 4 ← Phase 3 differentials; promotion ← mutation adequacy.
**The phase number is not a dependency.** The real serializer is file ownership — one writer
per file — enforced through managent sets. T304 (docs) and T307 (claimlint) are dispatchable
in parallel right now precisely because they share no file.

The Auditor (Fable 5) conceded F3's centre and contributed both hardenings above: record it
as a DIRECTION amendment rather than only in PHASES.md, and make edge 2 non-rubber-stamp by
requiring the invariant to kill its own mutant.

## Phase state

- **Phase 0 — done.** `docs/epic-01-markovian/AXIOMS.md`: theorem Z with Z1–Z5 and NC1–NC5,
  ruleset R as axioms A1–A6 + B1–B3 + C1–C4 + D1–D3 + E1–E3 each with a claim ID, the
  requirement tree top-down from Z, the MIGOS adjudication, and an amendment log (A5/B2/B3
  ko-pass contradiction fixed, B1's ply count derived, A6 forced pass added by T285).
- **Phase 1 — DONE (2026-08-03).** All three rows delivered. T292 landed golden-master
  baselines for all eight artifacts (`docs/evidence/BATTERY/baselines.json`, per check:
  status, exit_class, modes, numerator, **denominator**, seed, sample params) plus the
  fast-path comparison inside `zig build test` (+3.3 s) and the slow sweep behind
  `zig build battery-sweep`. Verified by this seat: perturbing one baseline denominator
  (57→58) makes the gate print the diff and exit 1; restored byte-exact. The gate uses
  `addArtifactArg`, so it always runs a **freshly built** battery and cannot read a stale
  one — better than smoke's approach. A5's stride-97 concern is discharged with an argument
  (group sizes {2,4,5,6,7,8} all < 97, so the stride hits at most one entry per group; the
  sample is deterministic, so coprimality is moot), and a check with `seed_source=auto` is
  explicitly **not** a golden master.
- **Phase 1 detail, as delivered.** T290 spec **done** (I1–I12 mapped onto the tree both ways;
  **G1/G3 `Z-R-STATE`/`Z-STATE-KEY` and G2 `Z-STATE-REACH` are critical and uncovered** —
  the T178/T193/T265 family has no battery check). T291 mutants **done**: 3/10 kill rate,
  the rest recorded as EXPECTED known-unkilled gaps that invert when the kernel lands.
  **T292 (baselines + wiring) is dispatchable and is the next substantive row.**
- **Phase 2 — T273 landed the kernel ko + state-key**; `gtp.zig` calls it, a
  deliberately-broken version fails the suite. Remaining: the fourth ko copy in
  `oracle_v2_accept.zig` (`CODE.ACCEPT-KOKEY`) and engine-unification pass1.
- **Phases 3–4 — not decomposed.** Phase 3 needs Phase 1's battery to exist.

## Gates and instruments (all mechanized this session)

- **Pre-commit gate installed**: `core.hooksPath = tools/hooks`, blocks *regressions*
  against `tools/hooks/claimlint-floor.json` (C1a ≤ 10, C2 ≤ 14, C6 = 0), **not** "green".
  `sh tools/regression-precommit.sh` proves a refusal. **The floor does not rise to
  accommodate a regression** — ARGUS.md allows lowering on evidence of a fix.
- **Commit through `tools/git-commit-mine <paths> -m <msg>`**, never `git add -A`: one
  shared `.git/index` swept three tasks' work into wrong commits on 2026-08-02, mine
  included. `managent done` now asks git whether deliverables are tracked and unmodified.
- **`STANDING-ABSORB`** fires at C7 > 5 (T294) — absorption stops depending on Orcha
  noticing. Two other triggers are firing and must **not** be auto-registered:
  `STANDING-CONSOLIDATE` (51 FALSE-AS-SCOPED) and `STANDING-HOLISTIC-AUDIT` — **no re-audit
  until Phase 1's deliverables exist.**
- **Context dumps**: `findings/<id>-context.json`, six keys, **`claims: []` and
  `new_rows: []`** — dumps are narrative, not proposals; carrying proposals double-counts C7.

## T314 closed (2026-08-03, commit `4ca8dbb`) — verified against its bars by this seat

All six rows ran, `N=1` control included, from one snapshotted binary (`efcec159…`):
speedup 1.00 / 0.97 / 1.59 / 2.07 / **2.89 / 2.91×** at N=1/2/4/6/12/16, **flattening at
N=12** with the memory-bandwidth signature (~3 GB of shared random-access reads per sweep;
N=12→16 adds +33% threads for +0.7%). RSS flat at 3,887±1 MB. **All six artifacts
byte-identical to `0c3366f0…`** — T312's iteration-order hypothesis is falsified; the 4×4
now reproduces **nine** independent ways. Durable doc:
`docs/research/parallel-fixpoint-measurement-2026-08-03.md`. Practical yield: a 4×4 build
is now 23 min (N=12) instead of 66, at 1.9× total CPU.

Two findings the worker left, both registered/actioned by Orcha:
- **`zig build test` is non-deterministic** (390/393 → 393/393 across consecutive runs,
  pre-existing at b3d0209) — registered as **T325**; a flaky suite quietly weakens every
  close that cites "suite green".
- `exp6_hchain_audit.zig:1100` holds a third, serial-only copy of `run_fixpoint_4x4` —
  labelled directly by Orcha with the duplication-as-oracle header comment (quick fix,
  no row).

**Queue (superseded — see the header's owed list):** T323 and T324 both dispatched and
closed same evening. T317 solo is next, then T319 (archive) → T322 → T325, with T326/T327
(Sabaki handicap, score-annotated board) queued behind T322/T326 in set C.

## The three decisions — ALL RULED 2026-08-03 evening

1. **Credential stripping (option c): REJECTED by the human.** Stripping only limits *how* a
   runaway agent misbehaves, not *whether*; no security or integrity issue is solved on a
   single-user machine. Recorded in `docs/infra/agents/subdelegation.md` §Depth-enforcement
   ruling. Posture stays (b) + honest documentation; Ollama→DeepSeek remains a live,
   documented path.
2. **The 116 retirements: DELEGATED by the human to Orcha/auditor/researcher.** The human
   wants the project's own judgment: what's the issue, what's the impact, is retirement
   better or worse. Registered as **T324** — a researcher fills a `RECOMMEND:` verdict with
   rationale per row on `docs/epic-01-markovian/retirement-ruling-sheet.md`; **Orcha
   ratifies** (fills `RULING:`) before anything touches the register. The eight ⚑
   sole-evidence rows stay non-candidates until re-pointed.
3. **Next sprint: DELEGATED to Orcha — ruled YES, G3b.** Commissioned as
   `sprints/g3b-value-correctness/`; the commissioning draft (msg 077) is the builder's
   input; **T323** is the spec-bookend row. The kernel move generator is the sprint's
   critical path.

**Model assignment at dispatch, as always.** Roster: Ollama (`glm-5.2`, `minimax-m3`,
`kimi-k2.7`) for leaf rows with no subtasks; DeepSeek where a row must subdelegate. Dispatch
line format is `--- <model>/T<nnn>` then the bare `Follow untracked/T<nnn>-….md` — **no
protocol reminders appended**; `DELEGATEE.md` §claim already covers them.

## First: DIRECTION.md governs

`docs/audits/grand-audit-2026-08-02/DIRECTION.md` — ratified by the human
2026-08-02, committed `2432d71` with the Grand Audit and its four arm reports.
Read it before this file's queue section; `docs/epic-01-markovian/PHASES.md` is
the tracked phase→task map. **When the kanban and DIRECTION disagree, DIRECTION
wins and the kanban is the bug.**

What it changes for this seat:

- **Epic-01 is unfinished, not failed** — completed in place, strictly k=1
  (state = position, side, ko, passes). No new epic directory, no migration of
  claims/decisions/docs (that retired T203).
- **All 282 register rows are presumed unverified**, falsifications included,
  until re-derived. The register is the map of what was once believed, not
  evidence.
- **Five phases**: 0 axioms → 1 battery-before-code → 2 kernel extraction →
  3 A–Z reverification → 4 the swap. **Phase 0 gates decomposition**: no Phase
  1–4 task may be registered until AXIOMS.md (T271) exists.
- **The kernel** — board/colex, rules (including the one ko/state-key function),
  state encoding, solver core, wzo2 I/O — is epic-independent, one implementation
  each; epic-01's existing implementations are demoted to frozen oracle fixtures.
- **Every gate is mechanized the day it is declared.** No re-audit until Phase
  0/1 deliverables exist; the next audit is the ephemeral gate on them.

---

## You can play it — Sabaki

| field | value |
|---|---|
| Path | `/Users/alex/Project/Zig/weizigo/bin/weizigo-gtp` |
| Arguments | `/Users/alex/Project/Zig/weizigo/untracked/oracle-v2/oracle-4x4-v2.wzo2` |
| Board | 4 × 4 · Komi 0 |

Engine `626ec55-dirty`. Both human games replay with 0 misses, 0 fallbacks.
Watch stderr: every lookup miss names its state; `weizigo-stats` gives totals.

## Operating rules that cost the most to learn

- **Subdelegation works**: `bin/subagent <T-ID> --dspro|--dsflash`. The
  documented `odeeppi`/`oflashpi` aliases are interactive-shell only and had
  silently blocked every dispatch. Workers run at depth 2 and cannot dispatch.
- **Scope a worker to one bounded deliverable** — read-and-write tasks
  complete; build-and-iterate tasks stall without reporting.
- **Workers often close their own tasks now** (T291, T293, T283 all did) — but check:
  several finished the work, committed, and left the row `in_progress`, or closed without
  `--agent` so the ledger read `unknown/<id>`. Orcha fixes the row; the work is fine.
- **The acceptance runner is FIXED (T295).** `std.Io.Threaded.init` defaulted `environ` to
  `.empty`, so every spawned child started with no environment at all; `/bin/sh` resolved
  (absolute path) but `zig` did not. Fix: pass `init.environ`. `managent done` now also
  distinguishes **CANNOT RUN** (exit 127/126, spawn failure, signal — an infrastructure
  fault) from **ACCEPTANCE FAILED** (a real non-zero exit), and `managent audit` surfaces
  every `--skip-acceptance` use. T292 was the first task whose acceptance actually ran, and
  it passed. Note the exec subtlety: with an empty environ the default PATH
  (`/usr/bin:/bin`) **did** find `/usr/bin/git`, so the T278 deliverable guard was never
  dead — only non-system tools (zig, anything under `/opt/homebrew`) failed.
- **Deploy discipline, now load-bearing.** Any commit touching `build.zig` stales all seven
  binaries, and since T295 §5 that no longer reddens the suite. So: commit, then
  `zig build deploy`, then `sh tools/smoke.sh` and check for zero `STALE` lines. Deploy
  **after** committing — deploying from a dirty tree stamps the binary `<sha>-dirty`, which
  smoke reads as stale and which no commit can reproduce (T295 and T292 both did this).
- **Ask every console for a context dump before killing it.** Thirteen dumps in
  `findings/*-context.json`; they yielded two P0 defects in same-day code.
- **Every instrument needs a null control and a seeded-defect control.** Four
  instruments were found broken today, all green beforehand.
- **The human observes at pass, sprint and epic boundaries.** A seat generating
  micro-dispatch traffic is malfunctioning.

## Seats

| seat | status |
|---|---|
| Orchestrator | **Opus 5 (`claude-opus-5`), seated 2026-08-04 by human order** — handed over from Fable 5 (`claude-fable-5`, seated 2026-08-03 evening), which ran the G3b commissioning pipeline (T324 ruling, spec Rev 2→3, plan Rev 1 + audit + disposition) |
| Subtasks/audits | **Fable 5 available independently** (human-ruled at handover) — deep holistic review, gate-holder verification; dispatch to a Fable console |
| Auditor | ephemeral — spun per gate, discarded after (DIRECTION §6). T287 (`deepseek-v4-pro`), T329/T332 (`kimi-k2.7`) were three |
| Dabir | unseated |

Canonical model labels (human's ruling): `deepseek-v4-pro`, `deepseek-v4-flash`. Every other
spelling is an alias and fragments `model-perf.md` — see `DELEGATEE.md` §Identity.
