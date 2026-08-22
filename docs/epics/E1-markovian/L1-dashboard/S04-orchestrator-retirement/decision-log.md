# S04 phase 0 — the decision-log study (the counted table)

**Row:** T579 · **Author:** claude-opus-5/T579, 2026-08-22 · **Read-only study.**
**Machine-readable form (every row, every citation):** `findings/T579-decision-log-study.json`
(`study.rows`). This doc is the same table so the spec author never has to open the JSON.

**What this answers.** S04 seed §4: classify every decision the orchestrator seat has actually
made across its lifetime into **(a) mechanized** — a tool already refuses/does it; **(b) lookup**
— decidable from a data table; **(c) judgment** — verdict evaluation, escalation triage, novel
situations. The seed says the sprint's scope is *derived from this table, not designed from
intuition*, and that "if the table shows (c) is small, the sprint shrinks accordingly."

---

## 1. The denominator, stated exactly

| | count | definition |
|---|---|---|
| **distinct seat decisions** | **129** | one row per decision. A decision broadcast to N lanes, or executed against N rows, is ONE row with `events=N`. Includes decisions issued by sprint-console/delegator seats (`kind=console`, 4 rows), which held the same routing authority. |
| decision **events** | **152** | the same population counted once per lane/row touched. Use this for *how often did the seat have to act*; use the 129 for *how many distinct calls did it have to make*. |
| excluded — instrument probe | 10 | eight `tell`/`inbox` self-tests, one record with no `note` field, one epitaph reading `test`. No decision content. |
| excluded — inbound escalation | 4 | worker→seat messages. The seat's *answer* was a decision, but the *record* is the worker's; counted separately in §5. |
| excluded — peer coordination | 4 | worker→worker, no seat in the loop. |
| **total records examined** | **170** | 129 + 10 + 4 + 4 (+ multiplicity). |

### Sources, and the extraction rule per source

| source | what was mined | yield |
|---|---|---|
| `docs/infra/managent/directives.jsonl` | **exhaustive** — every record classified, none skipped. The file is 191 lines but holds **105 objects** (notes embed literal newlines). IDs are **not unique**: the counter reset on 2026-08-19, so `D021`–`D054` each appear twice with different targets and timestamps. | 88 seat/console · 9 probe · 4 inbound · 4 peer |
| `docs/infra/managent/archive.json` | **exhaustive** — 104 archived rows; 31 carry a seat close/retire/adjudicate decision (20 test-leakage phantom closes, T203's foreclosure, 8 epitaphs, 3 verdict adjudications). | 8 distinct (31 events) + 1 excluded probe epitaph |
| `docs/status/orcha-decisions-2026-08-19.md` | numbered decisions D1–D5 (`:12`, `:42`, `:58`, `:79`, `:91`) | 5 |
| `docs/status/ROADMAP-2026-08-20.md` | the rev-3 ruling queue, rulings 1–8 (`:214`…`:262`, section head at `:207`) | 8 |
| `docs/status/handover-orcha-flash-2026-08-19.md` | §3 acceptance criteria AC1–AC10 (`:33`–`:42`) + §6 pre-registered kill rule (`:80`–`:86`) | 11 |
| `findings/T568-orcha-successor-seat.json` | enumerated decisions in `notes` | 6 |
| `docs/status/handover-t557-2026-08-21.md` | enumerated decisions (`:17`–`:19`, `:21`–`:27`, `:29`–`:32`) | 3 |

**Extraction rule.** The two machine-readable sources are enumerated exhaustively. The prose
handover docs are mined **only for numbered or enumerated decision items**, so anyone opening the
cited lines re-derives the same count; unnumbered narrative in those docs is deliberately not
counted. That makes column (c) a **lower bound** and the mechanized fraction correspondingly an
**upper bound** — the bias runs against this study's own conclusion, which is the safe direction.

**Deliberately not counted.** `orchestration-layer-spec.md` §7/§7b rulings 1–10 are **operator**
rulings the seat recorded, not seat decisions. `ROADMAP-2026-08-21` §"Ruling queue — open" items
1–4 are escalations still open — decisions *not* made.

---

## 2. The counted table

| class | distinct | % of 129 | events | % of 152 |
|---|---|---|---|---|
| **(a) mechanized** | **61** | **47.3 %** | 84 | 55.3 % |
| **(b) lookup** | **12** | **9.3 %** | 12 | 7.9 % |
| **(c) judgment** | **56** | **43.4 %** | 56 | 36.8 % |
| total | 129 | 100 % | 152 | 100 % |

### (a) — which existing mechanism already covers it

Every (a) row names a mechanism **verified present at HEAD `2b03b6b-dirty`**. No row is classed
(a) on the strength of a tool that could exist.

| mechanism class | n | the refusal, named |
|---|---|---|
| one-writer | 12 | `claim` → `REJECTED: holds conflict on file` (`src/managent/main.zig:2059`, `:2121`) |
| acceptance-check | 10 | `sh tools/orcha-acceptance.sh` (AC1–AC10) |
| process-guard | 8 | `tools/runner` wall/RSS/CPU guards · `managent liveness` · `reap` · `treekill` |
| needs-satisfied | 6 | `claim` → `UNMET NEEDS` (`:2038`); `needsMet` recomputes on every close (`:8710`) |
| attribution | 4 | `bin/argus --mode doctor` · `managent audit` · `managent whoami` · `bin/dispatch` writes model + dispatched_to |
| store-isolation | 3 | `MANAGENT_STORE` · `MANAGENT_TEST=1` · fixture-pattern id refusal (T427) |
| state-read | 3 | the answer is a command: `git diff`, `git ls-files`, `bin/weizigo-claimlint` |
| kill-protocol | 3 | `managent tell <id> kill` — the graceful wind-down already is a verb |
| close-gate | 3 | `done` → C7 non-conforming/unabsorbed (`:2677`), deliverables not cleanly in git (`:2855`) |
| message-transport | 3 | none — see F8; these exist *because* directive text was mangled |
| duplicate-dispatch | 2 | `claim` → `ALREADY CLAIMED` (`:2098`); `dispatch` → `REJECTED: already dispatched` (`:2212`) |
| registration | 2 | `managent add <id> --bundle <path> --holds …` · `managent holds --sync` (`:511`, `:904`–`:919`) |
| inbox-ack | 1 | `managent inbox <id> --ack` |
| fleet-quiet | 1 | `managent status --json` in_progress census + the keeper's cap |
| **total** | **61** | |

### (b) — which data table decides it

| table | n | rows |
|---|---|---|
| provider quota / appetite | 7 | Ollama cooldown, token-cost stop, two wind-downs, weekly exhaustion, the Claude 15:30 reset, the reset-driven reorder |
| model fit | 2 | exploration-first standing default; family-independence for auditors |
| ordering | 2 | the two successor queue orders (T568, T557) |
| measurement validity | 1 | a wall-clock reading taken under a competing 18 GB local model |
| **total** | **12** | |

### (c) — sub-split, and where the reconciler's boundary actually falls

Every (c) row carries a `c_kind`.

| c_kind | n | meaning | inside S04 §9 scope? |
|---|---|---|---|
| **verdict** | **15** | evaluating a worker's or an instrument's result | **yes** |
| **triage** | **10** | escalation / stall / ownership / novel-situation routing | **yes** |
| relay | 15 | operator-originated content the seat carried and interpreted | no |
| doctrine | 10 | a rule or policy the seat authored | no |
| scope | 6 | re-specifying a live row's brief mid-flight | no |
| total | 56 | | |

> **The number the spec's scope should be derived from: 25 of 129 = 19.4 %.**
> S04 seed §9 scopes the reconciler to steady state only — routing, health, closure, escalation —
> and leaves sprint decomposition, spec authorship, grand audits and direction to the
> operator-and-strong-agent conversation. `relay` + `doctrine` + `scope` (31 rows) *are* that
> conversation. So (c) is 43.4 % of the seat's history, but the reconciler's share of (c) is
> 25 rows, under a fifth of the whole record.

---

## 3. Findings

**F1 — the sprint shrinks, as the seed anticipated.** (c) is 56/129 (43.4 %), but only 25/129
(19.4 %) is reconciler work. The verb set must cover verdict evaluation and triage, not 43 % of
the record.

**F2 — the mechanized share is bigger by events than by decisions** (55.3 % vs 47.3 %). The gap
is pure broadcast: the seat repeated one mechanical decision to two or three lanes at a time
(`DIR-022`–`024` suite stop, `DIR-025`–`027` resume, `DIR-028`–`030` kill, `DIR-065`–`068` the
`git add -A` sweep and its follow-up). A queue-level condition reaches every lane at once; that
repetition is seat tax that vanishes with the mechanism.

**F3 — column (b) is one table, mostly.** 7 of 12 are provider quota/appetite. Absorbing (b) needs
a provider/appetite table first and an ordering table second — both already named in
`orchestration-layer-spec.md` §3 (conditions) and §7 rulings 1–2. **No new design is owed for (b);
it is data entry.**

**F4 — the highest-yield fix in this table is not the reconciler.** The largest (a) family is
one-writer: 12 seat rows, plus 3 more recorded as peer coordination (15 records), plus 2
registration rows. `managent claim` has refused on holds conflict for the entire period
(`:2059`, `:2121`) — so all 15 are conflicts the mechanism could already have prevented and did
not, because `holds=` was never registered. `DIR-098` is the sharpest case: **the seat itself**
dispatched T545 onto `src/managent/main.zig` without declaring holds, then had to pause T544 by
hand. T568's closing lesson reaches the same conclusion independently (`suggest` mints the row
before the bundle header exists, so `holds=` never records; register bundle-FIRST). Making
`holds=` mandatory at mint is cheaper than anything in the reconciler design.

**F5 — the directive log is not a clean decision log.** 9 of 105 records carry no decision (eight
self-test probes, one empty record) and 4 more are peer coordination with no seat involved. Any
metric over raw `directives.jsonl` overstates seat activity by ~12 %. The reconciler's run records
should keep the instrument-test channel separate.

**F6 — self-correction is a real line item.** The seat corrected or superseded its own prior
directive **6 times** (`DIR-035`, `DIR-041`, `DIR-101`, `DIR-050`, `DIR-096`, `DIR-105`) and twice
apologised for damage it caused itself (`DIR-065`–`068`, `DIR-098`). A stateless per-wake
reconciler cannot accumulate that debt the same way — but the escalation contract must explicitly
permit one wake to retract a previous wake's action **through the store**, or the same correction
just becomes an escalation.

**F7 — the inbound half of the escalation contract is tiny, and has one shape.** Only 4
escalations were ever received (`DIR-072`, `DIR-083`, `DIR-084`, `DIR-095`). Two are genuine
blocks and both are identical in shape: *a gate fired correctly and the unblock needed a
cross-lane routing decision* (the done gate on a dirty tracked deliverable; the pre-commit C7 gate
on another console's non-conforming findings file). The other two are status reports the store
already contained. It has recurred, so by S04 §6's corollary it owes a **rule** — route the
blocking file to its owning row — not a reconciler judgment. And the contract should forbid
"report" as an escalation category outright, since `managent done` already records it.

**F8 — three of the seat's decisions were spent repairing its own message formatting**
(`DIR-067`, `DIR-068`, `DIR-101`: a failed interpolation and a shell-quoting mangle). The
reconciler must emit directives through a template, not a shell string.

---

## 4. What this implies for the spec (offered, not ruled)

1. **Scope the reconciler at the 25 rows**, and state the 19.4 % in the spec so the scope is
   traceable to evidence rather than to intuition.
2. **Verdict (15) is the larger half and is partly gate-able already**: S04 §5 already restricts
   `done` to rows whose acceptance command exits 0, which converts part of `verdict` into (a).
   The spec should say how much — this study cannot, because the archived rows predate
   `acceptance=`.
3. **Two data tables discharge column (b) entirely** (F3). They are prerequisites, not reconciler
   design.
4. **Register `holds=` at mint** (F4). It is the single largest mechanized family and it kept
   firing anyway.
5. **The escalation contract needs one inbound rule** (F7) and an explicit retraction path (F6).

---

## 5. Full row table — 147 rows, every count re-derivable

`cls`: a / b / c / x(excluded). `tag`: the mechanism class (a), the data table (b), or the
`c_kind` (c). `kind`: seat · console · inbound · peer · probe. `ev`: events (multiplicity).
Directive rows are cited as *record N of 105* in the JSON, with the full `id`/`target`/`ts`/`from`
tuple — IDs alone are not unique.

| row | date | cls | tag | kind | ev | decision | basis |
|---|---|---|---|---|---|---|---|
| `ARCH-1` | 2026-08-20 | a | store-isolation | seat | 20 | Close 20 test-leakage phantom rows (T228-T251 block) with verdict abandoned | MANAGENT_STORE / MANAGENT_TEST=1 / fixture-pattern id refusal now prevent the leak; `managent reap --close` closes what does leak |
| `ARCH-2` | 2026-08-20 | c | scope | seat | 1 | T203 foreclosed by DIRECTION.md §2 — its whole deliverable (the migration) is superseded by a ratified direction | a ratified direction invalidating a registered row; irreducible |
| `ARCH-3` | 2026-08-21 | a | process-guard | seat | 5 | Retire the five surviving T559 load-test dummy lanes (TL1B-F) whose close never landed | `managent reap --close` + `managent liveness`; T572 is the durable store-pollution fix |
| `ARCH-4` | 2026-08-21 | x | — | probe | 1 | TL1A retired with epitaph 'test' | instrument probe |
| `ARCH-5` | 2026-08-20 | c | triage | seat | 1 | Retire T466 as superseded by T469; re-register its two open questions as T470; record 'the brief was too big' as the finding | supersession + partial re-registration + a lesson drawn from a wall-kill |
| `ARCH-6` | 2026-08-21 | a | registration | seat | 1 | Retire T570 — registration predated the bundle header so holds= never recorded; re-registered as T572 | `managent add <id> --bundle <path> --holds ...` + `managent holds --sync` (main.zig:511, 904-919) |
| `ARCH-7` | 2026-08-20 | c | verdict | seat | 1 | Adjudicate T332: fail-found stands — plan-audit found a critical closure/artifact-format mismatch | verdict evaluation on a completed audit |
| `ARCH-8` | 2026-08-20 | c | verdict | seat | 1 | Adjudicate T258: fail-found stands — I7 fails on all artifacts, I4/I5/I7 unimplemented at 4x4 | verdict evaluation |
| `ARCH-9` | 2026-08-20 | c | verdict | seat | 1 | Adjudicate T259: fail-found stands — Bellman violations systematic, A1/A2/A8 fail at 3x3+4x4 | verdict evaluation |
| `DIR-001` | 2026-08-01 | c | verdict | seat | 1 | P1 differential metric measures output-value groups, not implementation disagreement — re-derived from source | technical verdict on an instrument's semantics; no tool reads intent |
| `DIR-002` | 2026-08-01 | c | doctrine | seat | 1 | Standing requirement: null control + seeded-defect control before any instrument's first reading | doctrine formation from a defect class; became project doctrine, not a check |
| `DIR-003` | 2026-08-01 | a | store-isolation | seat | 1 | STOP — regression tests writing to the live kanban; 14 phantom rows; demand an explicit store override | MANAGENT_STORE / MANAGENT_TEST=1 + fixture-pattern id refusal (main.zig help, T427) now refuse this outright |
| `DIR-004` | 2026-08-01 | c | relay | seat | 1 | Three standing requirements relayed from the operator (one instance per function; clones vs independents; …) | operator direction relayed and interpreted into sprint scope |
| `DIR-005` | 2026-08-02 | a | needs-satisfied | seat | 1 | HOLD until T266 and T270 report — three memory-heavy jobs in flight, per-PID RSS cap does not sum | claim refuses on unmet needs (main.zig:2038 UNMET NEEDS) + tools/runner host guard + fleet-keeper cap |
| `DIR-006` | 2026-08-02 | a | one-writer | seat | 1 | build.zig is co-owned this session; T267 goes first, re-read before touching | claim refuses on holds conflict (main.zig:2059/2121 REJECTED: holds conflict on file) |
| `DIR-007` | 2026-08-02 | a | one-writer | seat | 1 | Do the tasks.json sweep LAST and only when nothing is in progress | holds conflict refusal + `managent status` in_progress count; the queue's fleet-quiet condition |
| `DIR-008` | 2026-08-02 | c | scope | seat | 1 | Descope the empirical half — brackets are TIE-independent analytically, three 53-min runs would confirm a formula | scope change justified by a derivation the seat performed |
| `DIR-009` | 2026-08-02 | a | needs-satisfied | seat | 1 | D011 lifted: T266 and T270 have reported and the tree builds clean | needs-satisfied is computed (needsMet, main.zig:1602) — a pause keyed to a dependency lifts itself |
| `DIR-010` | 2026-08-02 | a | one-writer | seat | 1 | Do not install core.hooksPath mid-fleet — it blocks every other console's commits | holds on shared infra + `managent status` in_progress; same class as the one-writer refusal |
| `DIR-011` | 2026-08-02 | a | one-writer | seat | 1 | You are editing shared infrastructure three live consoles use right now | holds conflict refusal at claim |
| `DIR-012` | 2026-08-02 | a | one-writer | seat | 1 | Do not deploy a rebuilt bin/managent while other consoles are running | holds on bin/managent + in_progress census |
| `DIR-013` | 2026-08-03 | c | verdict | seat | 1 | Read the new brief section: mutants 1/2/4/8 will most likely be killed by nothing — that is the expected result | predicting an instrument's outcome from a coverage spec |
| `DIR-014` | 2026-08-03 | c | verdict | seat | 1 | Your two failing tests are the EXPECTED result, not bugs to fix | verdict evaluation — distinguishing a true negative from a defect |
| `DIR-015` | 2026-08-04 | x | — | probe | 1 | tell/inbox self-test ('test') | instrument probe, not a decision |
| `DIR-016` | 2026-08-04 | x | — | probe | 1 | tell/inbox self-test ('test ack') | instrument probe |
| `DIR-017` | 2026-08-04 | x | — | probe | 1 | tell/inbox self-test ('resume test 1') | instrument probe |
| `DIR-018` | 2026-08-04 | x | — | probe | 1 | tell/inbox self-test ('resume test 2') | instrument probe |
| `DIR-019` | 2026-08-04 | c | relay | seat | 1 | Ten claimlint output names RATIFIED by the operator; keep the ID as key, print both | operator ratification relayed; naming is a judgment the ledger cannot compute |
| `DIR-020` | 2026-08-04 | c | relay | seat | 1 | SPEC AMENDED to Rev 5 (operator ruling): 4x3 becomes ladder rung 4, no 4x4 reading before it passes | scope change to a ratified spec |
| `DIR-021` | 2026-08-04 | a | state-read | seat | 1 | UNBLOCK: there are NO uncommitted build.zig changes from the seat — measured, both diffs empty | `git diff` / `git diff --cached`; `managent audit` holds-vs-git checks answer 'is anything of mine pending' |
| `DIR-022` | 2026-08-04 | a | process-guard | seat | 1 | STOP running 'zig build test' — unbounded recursion, five binaries spinning, load 16 | tools/runner wall+RSS+CPU guards, `managent liveness`, `managent treekill`, host guard (all post-date this) |
| `DIR-023` | 2026-08-04 | a | process-guard | seat | 1 | (broadcast of D028 to a second lane) | same mechanism; a queue-level pause reaches every lane at once |
| `DIR-024` | 2026-08-04 | a | process-guard | seat | 1 | (broadcast of D028 to a third lane) | same mechanism |
| `DIR-025` | 2026-08-04 | a | needs-satisfied | seat | 1 | Suite unblocked at 00bd3cb; the remaining red is T360's, expected, do not raise NODE_BUDGET | the pause was keyed to a row (T360); its close lifts the pause — needsMet/blocked-unblock path (main.zig:8710) |
| `DIR-026` | 2026-08-04 | a | needs-satisfied | seat | 1 | (broadcast of D031) | same mechanism |
| `DIR-027` | 2026-08-04 | a | needs-satisfied | seat | 1 | (broadcast of D031) | same mechanism |
| `DIR-028` | 2026-08-04 | a | kill-protocol | seat | 1 | Session closed by the operator — commit, write findings/<id>-context.json, exit | `managent tell <id> kill` is exactly this protocol; the INBOX LOOP contract executes it without a seat |
| `DIR-029` | 2026-08-04 | a | kill-protocol | seat | 1 | (broadcast of D034) | same mechanism |
| `DIR-030` | 2026-08-04 | a | kill-protocol | seat | 1 | (broadcast of D034) | same mechanism |
| `DIR-031` | 2026-08-05 | c | verdict | seat | 1 | zig build test is RED at HEAD pre-existing — build.zig:407 clears vb_i11's import table | root-cause diagnosis across two files; the red itself is measurable, the attribution is not |
| `DIR-032` | 2026-08-05 | c | triage | seat | 1 | Seat-handover ruling: the red is not your doing; ownership of the build.zig fix assigned | ownership adjudication between two rows |
| `DIR-033` | 2026-08-05 | c | triage | seat | 1 | Same red-at-HEAD ruling; registered as T369 which owns build.zig | ownership adjudication + row minting |
| `DIR-034` | 2026-08-05 | a | attribution | seat | 1 | Your row reads dispatchable with agent null but your artifacts are in the tree — claim it now | `bin/argus --mode doctor` + `managent audit`/`liveness` detect active-but-unclaimed rows |
| `DIR-035` | 2026-08-05 | c | triage | seat | 1 | CORRECTION superseding D038 on one point; D037 stands — you own the wiring fix | self-correction of a prior ruling; irreducible |
| `DIR-036` | 2026-08-05 | c | scope | seat | 1 | SCOPE CORRECTION: the brief's question 2 rests on a false premise — src/retro.zig does not enumerate predecessors | brief premise refuted by reading code; novel |
| `DIR-037` | 2026-08-06 | c | relay | seat | 1 | Four refinements after operator pushback; the seat's pigeonhole correction was beside the point | the seat concedes its own error and re-specifies |
| `DIR-038` | 2026-08-06 | c | relay | seat | 1 | Clarification of the operator's design (b) — the seat had explained it back wrongly | operator-design interpretation |
| `DIR-039` | 2026-08-06 | a | duplicate-dispatch | seat | 1 | STAND DOWN — duplicate dispatch, the row is already claimed and closed | `claim` refuses ALREADY CLAIMED (main.zig:2098); `dispatch` refuses re-dispatch (2212); G6 protected-set guard |
| `DIR-040` | 2026-08-06 | a | duplicate-dispatch | seat | 1 | DUPLICATE DISPATCH — one of you must stand down now | same: ALREADY CLAIMED refusal + dispatch_verify |
| `DIR-041` | 2026-08-06 | a | attribution | seat | 1 | CORRECTION to D048: the kanban's recorded model is a stale dispatch-time value, not the truth | bin/dispatch now writes model + dispatched_to (T544); `managent whoami` resolves the identifier |
| `DIR-042` | 2026-08-06 | c | scope | seat | 1 | Brief re-diagnosed: the chokepoint is not managent dispatch — the operator pastes prompts, so there is no dispatch event | re-diagnosis of a workflow, not a state read |
| `DIR-043` | 2026-08-06 | c | verdict | seat | 1 | Your premise may be stale — establish the real failing set before bisecting | reconciling two conflicting run reports |
| `DIR-044` | 2026-08-06 | c | triage | seat | 1 | STOP reverse-engineering the test binary — ten hours in; a bisect needs one bit per commit | escalation triage: a lane burning wall on the wrong sub-problem |
| `DIR-045` | 2026-08-06 | c | doctrine | seat | 1 | Three procedural bars: timestamp the 4x3 prediction before measuring it (out-of-sample vs postdiction) | methodology ruling |
| `DIR-046` | 2026-08-06 | c | verdict | seat | 1 | STOP — you are debugging the wrong function; the hang is a u6 overflow at src/t387_budget.zig:717-719 | the seat solved the lane's bug itself |
| `DIR-047` | 2026-08-07 | c | relay | seat | 1 | T407 brief changed: four games per position, not six (self-play makes colour-swap a replay) | operator correction + a derivation about wasted budget |
| `DIR-048` | 2026-08-07 | c | relay | seat | 1 | Brief sharpened by the operator — the sibling test replaces Q1 | operator design relayed |
| `DIR-049` | 2026-08-07 | a | one-writer | console | 1 | CONSOLE HOLD: do not run 'zig build deploy' or smoke until released | holds on the deployed binary + the queue's fleet-quiet condition; a deploy window is a lock, not a judgment |
| `DIR-050` | 2026-08-07 | c | relay | seat | 1 | CORRECTION to D056: the test belongs on cycles, not on positions | operator refinement; a sharper formulation of a measurement |
| `DIR-051` | 2026-08-07 | a | needs-satisfied | console | 1 | CONSOLE RELEASE: T412 and T413 are both closed, deploy window open | needs-satisfied lifts the hold automatically |
| `DIR-052` | 2026-08-07 | c | triage | seat | 1 | Follow-up proposal for the sprint manager to mint: env hygiene for standing regressions | minting a new row from a discovered defect — S04 §5 keeps minting outside the reconciler's verbs |
| `DIR-053` | 2026-08-08 | a | process-guard | console | 1 | CONTINUATION after an infra kill — SIGKILL by the 4 GB RSS guard is not a worker defect | reap fields + re-dispatch policy; tools/runner records the guard that fired |
| `DIR-054` | 2026-08-08 | a | process-guard | console | 1 | SECOND continuation — killed again because budgets were probed concurrently | same: guard attribution + re-dispatch; concurrency cap is a keeper setting |
| `DIR-055` | 2026-08-08 | a | close-gate | seat | 1 | EVIDENCE PATHS: /tmp is not evidence — fix before you close | `bin/argus --mode doctor` reports volatile citations; claimlint evidence-path checks; the done gate refuses uncommitted deliverables (main.zig:2855) |
| `DIR-056` | 2026-08-08 | c | scope | seat | 1 | One scope addition: the seat rescued T420's /tmp records; absorb them into your run | re-assigning rescued work to a live row — a scope change |
| `DIR-057` | 2026-08-08 | a | attribution | seat | 1 | Your row is closed and committed — the seat claimed it retroactively to protect the commit | the retroactive claim exists because a row read dispatchable while active; argus doctor + liveness detect exactly that |
| `DIR-058` | 2026-08-08 | c | verdict | seat | 1 | Phase 1 audited PASS-WITH-FINDINGS, phase 2 may proceed; two process corrections (you do not ask the operator to paste your dispatches) | verdict evaluation + a process ruling |
| `DIR-059` | 2026-08-08 | a | one-writer | seat | 1 | REPORT AND STAND DOWN — T430 is a live console on the same files | holds conflict refusal |
| `DIR-060` | 2026-08-08 | x | — | probe | 1 | PROBE measuring whether a working console reads its inbox unprompted | instrument probe, not a routing decision |
| `DIR-061` | 2026-08-08 | x | — | probe | 1 | read-attribution test directive | instrument probe |
| `DIR-062` | 2026-08-08 | x | — | probe | 1 | attribution-test | instrument probe |
| `DIR-063` | 2026-08-18 | a | state-read | seat | 1 | Your brief's 'C9=1' is stale — measured at HEAD with a clean tree: C9=0, C7=8 + 1 non-conforming | `bin/weizigo-claimlint` at rest; `managent orient` prints the live gate line |
| `DIR-064` | 2026-08-18 | b | measurement-validity | seat | 1 | Timing caveat: an 18 GB local model runs on this host — wall-clock readings in this window are load-contaminated | host load + lane roster are readings; measurement-methodology §3/§5 says when a reading counts |
| `DIR-065` | 2026-08-18 | a | one-writer | seat | 1 | SEAT ERROR: 'git add -A' swept your edit into the seat's commit | tools/git-commit-mine stages by name; the staging rule mechanizes the whole class |
| `DIR-066` | 2026-08-18 | a | one-writer | seat | 1 | (broadcast of D073 to the second victim lane) | same mechanism |
| `DIR-067` | 2026-08-18 | a | message-transport | seat | 1 | Follow-up: the file name did not interpolate in D073 — it was src/t419_taxonomy.zig | a message-formatting defect; a templated directive removes the class |
| `DIR-068` | 2026-08-18 | a | message-transport | seat | 1 | (broadcast of D075) | same mechanism |
| `DIR-069` | 2026-08-19 | c | relay | seat | 1 | Operator refined the design after seeing output: FOUR kanban sections, not one | operator design change relayed into a live row's scope |
| `DIR-070` | 2026-08-19 | a | process-guard | seat | 1 | RESUME: a prior console was wall-killed before committing; its work is still in the tree — do not start over | T477 orphan self-heal (dispatcher reopens what it watched die) + `managent reap`; runner records the wall kill |
| `DIR-071` | 2026-08-19 | a | process-guard | seat | 1 | (same class, different files: tools/pilot_gate.sh) | same mechanism |
| `DIR-072` | 2026-08-19 | c | triage | inbound | 1 | T466: close blocked — untracked/watch-fleet.sh is tracked+dirty with the operator's personal WIP | escalation received: the done gate fired correctly and the resolution touches the operator's own working tree |
| `DIR-073` | 2026-08-19 | b | provider-quota | seat | 1 | OPERATOR DIRECTIVE: model cooldown window — dispatch no Ollama models until 02:00 local | a model-availability/cooldown table; S04 §4 calls this queue data |
| `DIR-074` | 2026-08-19 | c | relay | seat | 1 | DESIGN CORRECTION (operator rejected 'dispatch-anyway after N minutes'): a logjam pressures the delegator to cool down | a design ruling that later became ruling 1 (aging-priority) — judgment that produced a table |
| `DIR-075` | 2026-08-20 | b | provider-quota | seat | 1 | TOKEN COST CORRECTION: stop the broad battery, run only the targeted test | appetite/cost table + the row's declared acceptance= command |
| `DIR-076` | 2026-08-20 | c | relay | seat | 1 | FRAMEWORK EXTENSION (operator): add the head-to-head comparison doctrine to model-perf | methodology doctrine |
| `DIR-077` | 2026-08-20 | a | inbox-ack | seat | 1 | Confirm you received the head-to-head doctrine directive | `managent inbox <id> --ack` is the read receipt; the seat was polling by hand |
| `DIR-078` | 2026-08-20 | c | relay | seat | 1 | DIMENSION TAXONOMY, FINAL: eight dimensions mapped to task types and roles | authoring the taxonomy is judgment; every later *use* of it is (b) |
| `DIR-079` | 2026-08-20 | b | provider-quota | seat | 1 | GRACEFUL HANDOVER: Ollama tokens are expiring — wind down now | provider quota table triggers a wind-down whose steps are already the kill protocol |
| `DIR-080` | 2026-08-20 | b | provider-quota | seat | 1 | (broadcast of the wind-down to a second lane) | same table |
| `DIR-081` | 2026-08-20 | a | one-writer | peer | 1 | T432 to T430: bin/argus is also my deliverable — preserve my hunks when you commit | two rows holding one file; the holds refusal prevents the situation entirely |
| `DIR-082` | 2026-08-20 | a | one-writer | peer | 1 | T430 to T432: your hunks are preserved, diff verified | same: the reply exists only because the conflict was allowed |
| `DIR-083` | 2026-08-20 | a | state-read | inbound | 1 | T432 close report: deliverables committed, verdict pass-with-findings | `managent done` already records verdict + deliverables; the report is redundant with the store |
| `DIR-084` | 2026-08-20 | c | triage | inbound | 1 | T353: my close is blocked by the pre-commit C7 gate on ANOTHER console's non-conforming findings file | cross-lane deadlock: the gate is correct, the unblock needs a routing decision |
| `DIR-085` | 2026-08-20 | x | — | probe | 1 | empty directive (no note field) | malformed record, no content |
| `DIR-086` | 2026-08-20 | a | one-writer | peer | 1 | T353 to T364: src/managent/main.zig has your uncommitted edits and it is my deliverable too — commit when your step lands | shared-deliverable contention; holds + the done gate's dirty-deliverable refusal cover it |
| `DIR-087` | 2026-08-20 | b | provider-quota | seat | 1 | Ollama weekly tokens exhausted: ship FLEET_MODEL_DENY as a durable default, not a shell export | a model deny-list is the archetypal queue data table |
| `DIR-088` | 2026-08-20 | a | store-isolation | seat | 1 | Your unknown-flag probe left a live bundle with no owning store row; it collided with a real T542 | fixture-pattern id refusal + MANAGENT_STORE; `managent audit` flags bundle/row mismatch; claim refuses 'no bundle found' |
| `DIR-089` | 2026-08-20 | b | provider-quota | seat | 1 | OPERATOR CORRECTION: the 15:30 reset replenishes Claude allowance — unspent tokens are wasted; dispatch all seven lanes now | a provider reset-clock table + the parallel cap |
| `DIR-090` | 2026-08-20 | a | one-writer | seat | 1 | T543 is running tools/bakeoff.sh from a snapshot while you rewrite it — land coherent whole-file saves | holds on tools/bakeoff.sh; the refusal makes the warning unnecessary |
| `DIR-091` | 2026-08-20 | c | triage | peer | 1 | T538 to T537: dispatch-verify now emits verified=unreached for 429/401/403; ~80 historical 'fail=row' lines remain | a worker routing a finding to the row that owns it |
| `DIR-092` | 2026-08-20 | b | provider-quota | seat | 1 | URGENT REORDER before the ~15:30 reset; no artifact produced in 10 minutes | quota clock + ordering; the stall detection is `managent liveness` |
| `DIR-093` | 2026-08-20 | x | — | probe | 1 | PERSISTENCE-PROBE-145142 | instrument probe |
| `DIR-094` | 2026-08-20 | c | verdict | seat | 1 | G1 is RUN-TIME, not retroactive: tokens are captured at dispatch or lost; bin/subagent:260 hardcodes --output-format text | a measurement correction that overturned the seat's own plan mid-flight |
| `DIR-095` | 2026-08-20 | c | triage | inbound | 1 | T543 race official: NOT blocked; lanes fired from a fresh worktree; bakeoff CANONICAL set lacks qwen3.8:27b-mlx | escalation received from a delegated official, with a roster gap attached |
| `DIR-096` | 2026-08-20 | c | verdict | seat | 1 | G1 CORRECTION: do not rely on retroactive token recovery — the seat was wrong; fix in flight | the same correction re-issued to the race lane; the seat retracting its own instruction |
| `DIR-097` | 2026-08-20 | a | close-gate | seat | 1 | BLOCKING THE WHOLE FLEET: findings/DARGUS-chunk.json has a literal newline inside a JSON string | claimlint C7 non-conforming + the pre-commit hook already refuse it; the done gate refuses the close (main.zig:2677) |
| `DIR-098` | 2026-08-20 | a | one-writer | seat | 1 | PAUSE — the seat dispatched T545 without declaring holds, so you and T545 are both live on src/managent/main.zig | holds conflict refusal — and the seat's own error is exactly what the mechanism prevents |
| `DIR-099` | 2026-08-20 | c | triage | seat | 1 | SCOPE ADDITION, live case: T527/T529 exited rc=124 with NO runner guard exceeded (~8s CPU against a 3600s budget) | an unexplained kill — a novel situation with no existing classifier |
| `DIR-100` | 2026-08-20 | a | attribution | seat | 1 | SCOPE EXTENSION: the kanban is actively mis-attributing closed rows across three independent sources | cross-source attribution mismatch is `managent audit`'s job; root cause was bin/dispatch writing neither field |
| `DIR-101` | 2026-08-20 | a | message-transport | seat | 1 | CORRECTION to D049 — its text was mangled by a shell-quoting error in the seat | a message-transport defect; templated directives remove the class |
| `DIR-102` | 2026-08-20 | a | fleet-quiet | seat | 1 | PRECONDITION NOT MET: the keeper dispatched you into a busy fleet (cap 3/3) — the exact condition your row forbids | the queue's fleet-quiet condition; the row's own precondition is checkable before dispatch |
| `DIR-103` | 2026-08-20 | c | verdict | seat | 1 | ROUND 2 PARTIAL: 17 of 22 lanes captured, all 17 carry token readings — first real cost data; then killed by two guards | verdict evaluation on a partial result, plus deciding what the partial buys |
| `DIR-104` | 2026-08-20 | c | relay | seat | 1 | Both artifacts revised since your dispatch — rule on the REVISED versions; not winner-takes-all | re-scoping a review after the operator corrected the seat |
| `DIR-105` | 2026-08-20 | c | scope | seat | 1 | SUPERSEDES D053: the seat had merged its objections into the operator's text — the three inputs are now separated | the seat retracting a conflation of its own voice with the operator's |
| `RQ-1` | 2026-08-20 | c | verdict | seat | 1 | L2 discharge — DISCHARGED at T510's commit | verdict evaluation over six value conditions + two auditors |
| `RQ-2` | 2026-08-20 | c | doctrine | seat | 1 | Amendment-2 mutation gate — KEPT AS WRITTEN; 6/10 does not satisfy it | refusing to weaken a gate to match its reading |
| `RQ-3` | 2026-08-20 | a | state-read | seat | 1 | F09 — CLOSED AS MOOT: HUMAN.md is already untracked and gitignored | `git ls-files HUMAN.md` (empty) + .gitignore:27 — two commands answer it |
| `RQ-4` | 2026-08-20 | c | doctrine | seat | 1 | T351 bars conflict — RULED no conflict: summary = console, evidence = artifact | reconciling two contradictory acceptance bars |
| `RQ-5` | 2026-08-20 | c | doctrine | seat | 1 | D1-D5 RATIFIED by default; D1 amended — push currency replaces the cloud copy; archive branch pushed | re-deriving a durability mechanism after the operator refuted the premise |
| `RQ-6` | 2026-08-20 | b | model-fit | seat | 1 | Interim model allocation — exploration-first is the standing default until race data supersedes it | this IS the model-fit data table (D027 task types + the cost stance) |
| `RQ-7` | 2026-08-20 | c | relay | seat | 1 | Races — aspect races GO now; the full 8-lane roster authorized | a spend decision gated on operator authorization |
| `RQ-8` | 2026-08-20 | c | relay | seat | 1 | Seat at handover — pre-registered rule fires on the final acceptance paste (later VETOED by the operator) | seat allocation; the veto proves it was the operator's to make |
| `AC1` | 2026-08-19 | a | acceptance-check | seat | 1 | orphan heal — in_progress with no worker process → 0 or reopened within one cycle | `managent liveness` + `managent reap --close` + T477 self-heal |
| `AC10` | 2026-08-19 | a | acceptance-check | seat | 1 | findings exist — tasks closed with no findings file → 0 | deliverables= header checked by the done gate |
| `AC2` | 2026-08-19 | a | acceptance-check | seat | 1 | fleet idle — in_progress==0 while dispatchable>0 → never longer than one cycle | `managent status --json`; the queue's own dispatch loop |
| `AC3` | 2026-08-19 | a | acceptance-check | seat | 1 | scope — commits touching a path held by another live task → 0 | holds conflict refusal at claim + `managent audit` holds-vs-git |
| `AC4` | 2026-08-19 | a | acceptance-check | seat | 1 | landmark chain — dispatched tasks whose brief names no landmark → 0 | bundle-header check in tools/orcha-acceptance.sh |
| `AC5` | 2026-08-19 | a | acceptance-check | seat | 1 | duty currency — duties overdue when a landmark is declared → 0 | `managent landmark <Ln> --declare` refuses on overdue/failed duties (T478) |
| `AC6` | 2026-08-19 | a | acceptance-check | seat | 1 | verification — dispatches closed without a dispatch-verify pass, unexplained → 0 | tools/dispatch_verify.py + bin/dispatch |
| `AC7` | 2026-08-19 | a | acceptance-check | seat | 1 | brief size — tasks wall-killed with no output → <=1/day | tools/runner wall guard + run records |
| `AC8` | 2026-08-19 | a | acceptance-check | seat | 1 | absorption — claimlint C7 unabsorbed → 0 for closed tasks | the done gate refuses a close on C7 (main.zig:2603-2677) |
| `AC9` | 2026-08-19 | a | acceptance-check | seat | 1 | findings conform — claimlint non-conforming → 0 | same done gate + the pre-commit hook |
| `KILL-CRIT` | 2026-08-19 | c | doctrine | seat | 1 | Pre-register the seat's own kill criteria (AC fails 3 days running / T445-class incident / relays above baseline / a silent session) | authoring a hand-back rule for its own seat |
| `T557-1` | 2026-08-21 | b | ordering | seat | 1 | Successor queue order (six items) with the two operator-gated items named | ordering + a declared gate |
| `T557-2` | 2026-08-21 | a | one-writer | seat | 1 | Do NOT touch tools/suite-truth.sh, tools/regression-suite-surfaces.sh, src/oracle_v2_accept.zig — a console owns them | holds conflict refusal at claim |
| `T557-3` | 2026-08-21 | a | close-gate | seat | 1 | Discipline: every dispatch prompt names an exact output file; run git status/ls -la before any claim about an artifact | the bundle `deliverables=` header + the done gate's dirty/missing-deliverable refusal (main.zig:2839-2855) |
| `D1-storage` | 2026-08-19 | c | doctrine | seat | 1 | T443 storage policy: the four-layer taxonomy; naming convention; keep the nine duplicates | a risk-accepting policy choice with no table to read |
| `D2-audit` | 2026-08-19 | c | doctrine | seat | 1 | Audit policy: adopt tiers A/B/C, 1-in-5 sampling, the failure-is-success sentence verbatim | sets the sampling dial from a measured base rate — the rate is data, the dial is judgment |
| `D3-absorption` | 2026-08-19 | c | doctrine | seat | 1 | Absorption spec (T481): adopt the mechanism; ratify the multi-writer and 'no tolerance' overturns | adopting a mechanism and overturning two prior rulings |
| `D4-landmarks` | 2026-08-19 | c | doctrine | seat | 1 | Adopt landmarks L8 (unambiguous language) and L9 (fleet can race its own workers) | minting map rows — scope-changing by construction |
| `D5-independence` | 2026-08-19 | c | triage | seat | 1 | Auditor independence (T471): record as closed — already ruled by commit c7f124d; the handover pack's open-list is stale | a staleness finding against a prose open-list; would be (b) if the ruling queue were a data table (see NOTE-1) |
| `T568-1` | 2026-08-22 | c | triage | seat | 1 | DARGUS duty chunk FAILED — argus doctor crashed on invalid UTF-8 from a liveness byte-slice truncation; diagnosed and minted T569 | root-cause diagnosis of a crash + minting the fix row |
| `T568-2` | 2026-08-22 | c | verdict | seat | 1 | T567: the brief's resurrection hypothesis is REFUTED — `git log -G` shows the close never landed; root cause is runner --task-id auto-claiming in the live store | historical reconstruction that overturned the brief's premise |
| `T568-3` | 2026-08-22 | c | triage | seat | 1 | Defer the durable store-pollution fix + regression to T572 rather than patch it inside T567 | a deferral/minting decision |
| `T568-4` | 2026-08-22 | b | ordering | seat | 1 | Queue order for the successor: T572, T573, T571, pass-2 re-audit, S03 audit, pass-2 scope->plan->build, Fable at pass boundaries | ordering — roadmap priority then FIFO, exactly the queue's step 3 |
| `T568-5` | 2026-08-22 | b | model-fit | seat | 1 | Pass-2 re-audit and the S03 audit must go to Flash/DSPro lanes, NOT Claude — family independence | methodology §5 independence rule read off the author's family |
| `T568-6` | 2026-08-22 | a | registration | seat | 1 | Lesson: register bundle-FIRST via `managent add <id> --bundle <path> --holds ...`, because `suggest` mints before the header exists | `managent add --bundle --holds` + `managent holds --sync` already do this |

*Every source above was re-opened on disk while writing this table; the mechanism line
numbers were read out of `src/managent/main.zig` at `2b03b6b-dirty`, not recalled.*
