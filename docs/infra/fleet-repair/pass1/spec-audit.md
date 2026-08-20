# T550 · fleet-repair pass 1 — Spec audit

| | |
|---|---|
| Sprint | `fleet-repair`, pass 1 |
| Phase | audit gate for Spec (`docs/infra/fleet-repair/pass1/spec.md`, Revision 1, PROPOSED) |
| Auditor | claude-fable-5/T550 (author was deepseek-v4-flash/T549.2 — different family, per `CYCLE.md`) |
| Instrument | document review, fresh session (`docs/infra/sprint.md` §Audit gates) |
| Date | 2026-08-20 |
| Round | 1 of 2 (two-round cap) |

## Verdict: **PASS-WITH-EDITS**

No blocker, no critical. Four **must** findings (A1–A4), each fixable by a diff to
the spec's text; two **should** (A5–A6, A6 being the ruling the spec invited); one
**could** basket (A7). Nothing here says the sprint would build the wrong thing —
the defects are in the spec's own bookkeeping (an arithmetic that does not close, a
grouping criterion the groups don't follow, success-condition counts frozen against
a moving population, and one fix surface named that does not exist). The evidence
base is unusually strong: **30 of the spec's ≈70 checkable citations were
spot-checked against the live tree and 28 verified exact** (§Spot-checks below);
the two misses are both live-census numbers that drifted, one of which is finding A3.

---

## Findings

### A1 — **must** — §2.1's family count does not close: claims 12-of-15, enumerates 11, omits D5 and D8, double-counts D9

§2.1 bullet 1 claims *"12 of 15 distinct defects fit the family"* and enumerates:
D2/D12 + D14 (missing-representation, = 2 distinct defects) and D3, D11, D13, D17,
D4, D6/D16, D7, D9, D10 (mis-reporting, = 9 distinct defects). That is **11**, not
12. D5 (tokens silently lost at dispatch — non-reporting) and D8 (`tell` reports
success for a write that never landed — the family's archetype) appear nowhere in
the classification, though both fit it more plainly than most of the listed nine.
Bullet 3 then names D9 as "one is residue" — but D9 is already inside bullet 1's
fit list, so the 15 are covered by 11 + 2 (refute) + 1 (residue) + 2 (unmentioned)
with one defect counted twice. The verdict direction ("confirmed in shape")
*survives* the correction — with D5/D8 in, the count is **13 of 15**, stronger than
claimed — but as written the number is not reproducible from the text, which fails
the spec's own L1 bar (§7.1: "every gauge number reproducible").

**Route:** editorial, diff below. **Diff:**
- §2.1 bullet 1: `12 of 15 distinct defects` → `13 of 15 distinct defects`; extend
  the mis-reporting list `… D7, D9, D10` → `… D7, D9, D10, D5, D8` (D5 non-reported
  tokens, D8 falsely-reported success).
- §2.1 bullet 3: `One is residue: D9 …` → `D9 (counted in the 13) is additionally
  residue: the root is fixed, the existing duplicates remain to be reconciled.`

### A2 — **must** — the grouping criterion as stated is not the criterion the groups apply, and the mismatch hides two unserialized shared holds in §4.2

§2's criterion is internally inconsistent: it declares defects the *same* when they
"share the … same fix surface, **file hold**, or instrument contract", then rejects
"grouping by file alone". And the four groups follow neither reading — they are
theme buckets of exactly the kind §2 says it rejects:

- `tools/fleet-keeper.sh` is mutated by D2/D12 (G1) **and** D13, D14, D11 (G3) —
  one file's changes split across two groups (the stated reason symptom-grouping
  was rejected).
- `bin/dispatch` is mutated by D4 (G2) **and** D10 (G4) — same split.
- G4 merges four disjoint fix surfaces (findings write path, `bin/dispatch`,
  `bin/subagent`, `managent tell`) that the criterion's own distinctness test
  ("a change to one would not touch the other") declares distinct.

Where the criterion IS correctly applied is the 17→15 identity collapse (D2=D12,
D6=D16) — that argument holds and I verified its inventory citations. The
consequence of the mismatch is concrete: §4.2 adds serialization notes for
`src/managent/main.zig` (orders 1→5) and `tools/runner` (order 2, Refinement A),
and flags order 7 sharing the keeper with order 6 — but **order 4 (D2/D12) also
mutates the keeper** and is unflagged, and **orders 5 and 8 both mutate
`bin/dispatch`** (T544's D4 write-path is in `bin/dispatch`; D10 is too) and are
unflagged. Those are the same shared-surface hazard class this sprint exists to
repair (D15).

**Route:** must, diff below; the criterion restatement is judgment-adjacent, so the
sprint owner should see this rationale at ratification. **Diff:**
- §2 criterion paragraph, replace the two rejection sentences with: *"That
  criterion governs defect **identity** (the 17→15 collapse). The four **groups**
  below are repair themes — a reading order, not identity classes; where one file
  serves two themes, §4.2 must carry the serialization."*
- §4.2 order 4 note: append *"; holds `tools/fleet-keeper.sh` — same hold as
  orders 6 and 7, the three keeper slots are serial."*
- §4.2 order 5 note: append *"; also holds `bin/dispatch` (the D4 dispatch-time
  write), which order 8's D10 shares — serialize or batch."*
- §4.2 order 8 note: append *"; D10 holds `bin/dispatch` after 5 clears."*

### A3 — **must** — S4 freezes attribution counts that were stale before ratification

S4 grades Accept against "56 backfilled …, 96 marked `unattributed-pre-T544`" —
the T544 brief's census (152 null-model of 193 closed rows). The live store at
audit time holds **160 null-model closed rows of 210 closed** (measured 2026-08-20,
`docs/infra/managent/tasks.json`, closed partition): eight more null closes landed
after the census, because D4 is still live — **T549's own row closed with
`model: null`** (store: `agent: deepseek-v4-flash, model: null`). Any frozen count
is guaranteed wrong at Accept: the gate would either fail a correct fix or pass
while leaving the post-census rows unexamined.

**Route:** must, diff below. **Diff** — restate S4 as an invariant over a fix-time
census: *"S4 — attribution: 0 null-model closed rows after T544; every null-model
closed row **as of the fix commit** is either backfilled with a recorded source or
explicitly marked `unattributed-pre-T544` (at the brief's census: 56 and 96 of 152;
re-measure at fix time and quote both censuses); every per-model aggregator states
its denominator and distinguishes attributed/backfilled/unattributed. Denominator:
`docs/infra/managent/tasks.json`, closed partition at the fix commit."*

### A4 — **must** — D7's named fix surface ("the duty/findings harness" write path) does not exist; the existing scoped close-time gate goes unmentioned

G4/D7 requires "validate-on-write in the duty/findings harness: the writer rejects
a nonconforming file … before claimlint's global floor ever sees it". There is no
findings writer harness: findings files are hand-written by workers per
`findings/README.md` — no single write path exists to instrument, so no red-first
control can be built against the surface as named, and the Design phase would
either flounder or invent a new tool (a silent scope expansion of the kind §5
exists to prevent). Meanwhile the natural choke point **already exists and the
spec never mentions it**: `managent done` runs claimlint C7 **scoped to the closing
task's findings files** and refuses the close (`src/managent/main.zig:2539`,
`:2814-2831`, the T485 absorption gate). The defect D7 describes is real — the
*global* pre-commit floor (`C7-nonconforming: 0`, verified in
`tools/hooks/claimlint-floor.json`) blocks every fleet commit for one writer's bad
file — but the fix belongs at the scoped close-time gate (extend it to JSON
well-formedness), and/or in narrowing the pre-commit floor's blast radius to the
offending path, not in a write harness that would have to be invented.

**Route:** must, diff below. **Diff** — G4 table, D7 row, "what must change":
*"a nonconforming findings file is rejected at the scoped close-time gate
(`managent done`'s per-task C7 check, `src/managent/main.zig:2814-2831`) naming the
file and line, and the global pre-commit floor stops being the first line of
defense — one writer's malformed file must not lock the fleet's commits. If the
Design phase instead proposes a findings-write helper, that is NEW scope and must
be argued as such."* Mirror the same wording in §3 G4 D7.

### A5 — **should** — two accept-criteria are not yet control-buildable as written

1. **D2/D12 weight classes have no defined input surface.** §3 G1's fixture ("one
   suite-weight row plus one text-weight row") presupposes the keeper can tell
   which rows are suite-weight — bundle metadata? name pattern? declared field?
   Nothing says. The spec correctly flagged its other open design choices (D1's
   branch, D17's grandfathering, §7.3/§7.4) but not this one. The weights
   themselves are fine (7.0 GB / 60 MB both verified measured, commit `add986c`).
   **Diff:** add §7 item 7: *"Where does a row's weight class come from? (bundle
   header field vs heuristic — Design decision; the D2 control cannot be built
   until it is made.)"*
2. **S2's "zero host-pressure culls attributable to admission"** — "attributable"
   is an escape hatch with no attribution procedure. **Diff:** either drop the
   qualifier (*"zero host-pressure culls during the verify runs"*) or name who
   attributes and how.

### A6 — **should** — sweeper ruling (invited by §5.1): ACCEPTED as scoped, with one tightening

The spec invited the audit to rule on whether the orphan sweeper violates non-goal
1. **Ruling: the resource-collector scoping stands.** The three guards (match only
`.zig-cache/o/*/test`; ancestry walk skipping live chains; two-pass 45 s
confirmation) are verbatim the T548 brief's minimum ("What to build" §3, verified),
the brief is an operator-registered row, and a collector of orphaned cache trees
watches resources, not worker health — it is not the torn-down stack returning.
One tightening: guards (a)–(c) do not say **where the sweeper runs**. `ec72cdb`'s
line is one dispatcher and no new watchers; a freestanding sweeper daemon or timer
is a new long-lived process even if it only reads cache trees. The T548 brief
already offers "on a timer **or in the keeper's loop**" — strike the freestanding
option. **Diff:** §5.1 guard (c): *"… it grows no state and no sibling processes,
**and it runs inside an existing loop (the keeper's iteration or the runner's exit
path), never as a new daemon or timer process**."*

### A7 — **could** — editorial basket

1. §4.2 order 3 justifies running D3 parallel to order 2 by "the analysis-parallel
   rule" — but D3 *mutates* `tools/dispatch_verify.py`; what permits the
   parallelism is mutation-serial-**per-held-file** on a file nobody else holds.
   Cite the right rule.
2. D9 ("refuses (or re-issues …)") and D10 ("warns (or refuses)") each carry a
   two-branch acceptance without the explicit "either branch, but not a third"
   framing D1 got. Pick one, or frame it as D1 does.
3. §1.3's C7 census (54/157 blank) had drifted to **56/159** by audit time — the
   blank-line writer appended two more lines within hours. Worth one sentence in
   §1.3: the dirtying is *active*, so any C7 census will drift mid-sprint.
4. §7.6's model-drift note checks out (CYCLE.md assigns T549 `dspro`; the store
   row carries `agent: deepseek-v4-flash`) — no edit needed, recorded here so the
   ledger comparison has an independent confirmation.

---

## Disposition table (audit-loop routing)

| ID | severity | route | disposition |
|---|---|---|---|
| A1 | must | PASS-WITH-EDITS diff | diff supplied above |
| A2 | must | diff + owner sees rationale at ratification | diff supplied above |
| A3 | must | PASS-WITH-EDITS diff | diff supplied above |
| A4 | must | PASS-WITH-EDITS diff | diff supplied above |
| A5 | should | PASS-WITH-EDITS diff | diff supplied above |
| A6 | should | judgment — ruling invited by §5.1 | ruled: accepted with tightening diff |
| A7 | could | editorial | diffs/no-ops as listed |

No finding escalates; none is structural (nothing balloons this pass). The spec's
author or the sprint owner applies the diffs; the audit does not edit `spec.md`.

## Spot-checks (the sample, per the brief's item 3)

30 checked of ≈70 checkable citations (paths, lines, commands, counts) the spec
makes. **28 exact, 2 numeric drifts** (marked ✗):

| # | claim | result |
|---|---|---|
| 1 | `tools/runner:316` pause/kill stops list | ✓ exact |
| 2 | `tools/runner:1221-1222` exit 124 on pending directive | ✓ |
| 3 | `tools/runner:1161` `os.setsid` child | ✓ |
| 4 | `tools/runner:1435` `KILL: host memory pressure` line | ✓ |
| 5 | `tools/runner:1503-1505` `os.killpg` SIGKILL | ✓ |
| 6 | runner host floor `hw.memsize // 8` (`:18-22`) | ✓ (comment block :14-24) |
| 7 | `dispatch_verify.py:66-98` `PROVIDER_REFUSAL_SIGNATURES` | ✓ |
| 8 | no host-memory pattern anywhere in the classifier | ✓ (grep: none) |
| 9 | `dispatch_verify.py:662-666` wall-kill rc==124 distinct path | ✓ |
| 10 | `main.zig:1538-1544` `needsMet` checks `status == .done` only | ✓ exact |
| 11 | `main.zig:854-865` `effectiveHolds` warning | ✓ |
| 12 | `main.zig:2138-2143` dispatch-side holds warning | ✓ |
| 13 | `bin/dispatch` writes no model/store anywhere | ✓ (only reads `status --json`) |
| 14 | `bin/dispatch` has no holds check | ✓ |
| 15 | `bin/subagent:257-264` `--output-format json` (D5 fixed) | ✓ |
| 16 | `git-commit-mine:146-148` fd-9 flock mutex | ✓ |
| 17 | `git-commit-mine:258+` holds check before staging | ✓ |
| 18 | `fleet-keeper.sh:286-290` hardcoded 5-model list, no Claude | ✓ |
| 19 | `fleet-keeper.sh:679-684` pressure bookkeeping | ✓ |
| 20 | `claimlint-floor.json` `C7-nonconforming: 0` | ✓ |
| 21 | D041/D042/D043 each appear twice in `directives.jsonl` | ✓ (2/2/2) |
| 22 | directives blank census 54/157 | ✗ live 56/159 (A7.3 — active dirtying) |
| 23 | T535 needs 7 rows; only T544/T548 still gate it | ✓ (T536/T539/T541/T545/T547 done) |
| 24 | T541 closed `blocked` yet satisfies `needsMet` | ✓ (store: `status: done, verdict: blocked`) |
| 25 | commit `add986c` = 7.0 GB suite / 60 MB text measurement | ✓ |
| 26 | commits `784235a` (T521), `ec72cdb` (stand-down) exist as described | ✓ |
| 27 | inventory doc exists; §D12 "same gap as D2"; pattern sentence | ✓ |
| 28 | `CYCLE.md` rules 2/4/5 + model table (T549→dspro) | ✓ |
| 29 | T548 brief sweeper §2 + three guards | ✓ verbatim |
| 30 | S4's 56/96 provenance (T544 brief: 152 of 193) | ✗ live 160 of 210 (finding A3) |

The spec's line citations are the most accurate I have seen in this repo's phase
documents — 20 consecutive path:line cites landed exactly on the current tree.
The defects the audit found are in the spec's *derived* numbers and
self-consistency, not in its evidence.

**Human summary:** the fleet-repair spec is sound in evidence and direction and is
PASSED WITH EDITS. Four things must change in the text before ratification: the
family-count arithmetic in §2.1 (it says 12-of-15 but enumerates 11 and forgets
D5/D8 — corrected, the hypothesis holds *better*, 13-of-15); the grouping section
must stop claiming a fix-surface criterion its own groups violate, and §4.2 must
serialize two shared file holds it missed (the keeper at orders 4/6/7,
`bin/dispatch` at orders 5/8); S4's frozen 56/96 attribution counts were stale
before the spec was ratified (live: 160 null of 210 closed — even the spec
author's own row closed unattributed) and must become a fix-time invariant; and
D7's fix names a findings-write harness that does not exist while missing the
close-time gate that does. The orphan sweeper is ruled in scope as a resource
collector, with one tightening: it must live inside an existing loop, never as a
new daemon.
