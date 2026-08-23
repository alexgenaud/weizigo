# T741 — Waypoint-3 (DIRECTION "Phase 3") decomposition spec

Lane: claude-sonnet-5/T741 · one of five independent lanes on the shared brief
`untracked/race-i-waypoint3-brief.md`. This is a proposal for the synthesizing
seat, not a registration — no kanban rows were created.

**Naming.** The brief calls this "Waypoint 3"; DIRECTION.md calls it "Phase 3";
`docs/infra/GLOSSARY.md` records the collision and a T737 rename proposal to
"Program step 0–4" that is **NOT ratified**. I use "Waypoint 3" only because the
brief does; every citation below uses DIRECTION's actual term, **Phase 3**, so
this document doesn't mint a fourth spelling. OPEN: which term the operator
ratifies is unrelated to the decomposition itself — the row set below is
identical either way.

## 0. What ground-truth check changed the shape of this decomposition

Before decomposing, I checked what state Phase 3's inputs are actually in
(static reads, HEAD, plus a live `bin/weizigo-claimlint` run — commands below
are reproducible). Three things are **not what the phase docs currently say**,
and they change the row set materially:

1. **PHASES.md's "G3b — untouched … C-A1/C-A2 are specified and unrun" is
   stale.** `docs/infra/managent/tasks.json` T383/T475 (2026-08-19) already ran
   C-A1/C-A2 **exhaustively** at 4×4 with the corrected kernel-successor
   ko-decode: children-not-in-table **0 / 616,030,190**, reachable-not-in-table
   **0 / 99,133,034**. `docs/epistemic/CLAIMS.md:328` (`4x4.C1`) already carries
   these numbers and says in its own text **"CLAIMED is the ceiling pending
   Phase 3 — nothing here is PROVEN."** That sentence is the clearest existing
   definition of what Phase 3 does to an already-measured row: not
   re-measurement, a **promotion act**.
2. **The mutation kill-matrix figure in the brief and in `orient` (6/10) is
   stale.** `sprints/verify-battery/pass1/mutants.md`'s amendment log records
   **T530 (2026-08-20): 6/10 → 10/10** — M1/M2/M3/M4 now have per-mutant
   red-then-green kill-verification fixtures in `src/vb_mutants.zig`, closing
   gap G1/G3 for the ten-mutant historical-defect catalogue. Live
   `bin/weizigo-claimlint` confirms `C8 mutation-adequacy violations: 0`.
   What is **not** covered (mutants.md §7, unchanged): per-invariant mutants
   for I4 (Bellman)/I1/I8/I9, and any WZO2-specific mutant — this is the real
   remaining mutation-adequacy gap, not the headline ratio.
3. **`register-tree-map.md` §5 item 5 ("Z-COMPLETE-ENUM at 4×4 … closure
   untested") is superseded by the same T383/T475 evidence** — the map
   predates it (T305, 2026-08-03).
4. **There is an existing but broken attempt at exactly this kind of audit.**
   `docs/infra/managent/tasks.json` carries a task literally named `"--bundle"`
   (set S, `needs: [T428]`, bundle path `untracked/T430-phase2-audit.md`,
   status `dispatchable`) — the bundle file does not exist on disk and never
   has. `T428` (the need) is `done`. This row is a stub, not a live phase-2
   audit; it is the most likely place this document's §1 row **W3-00** (below)
   should land, or the seat should close it as superseded and register fresh
   rows instead of trying to repair a bundle path that was never written.

**Consequence for the decomposition:** Phase 3 is not starting from zero.
Some rungs (4×4 especially) have kernel-era, exhaustive, committed evidence
sitting under a `CLAIMED` status with no promotion act performed on it. The
row set below is organized to **cash in what's already measured before
commissioning new measurement**, per process doctrine (least ceremony that
preserves reliable knowledge capture — re-running an exhaustive 616M-entry
sweep that already exists would be waste, not rigor).

Reproduce §0's checks:
```
bin/weizigo-claimlint 2>&1 | tail -25          # rows parsed 231, C8/C9/C11 = 0
grep -n "T383" -A2 docs/infra/managent/tasks.json | grep verdict_note
tail -5 docs/epics/E1-markovian/sprints/verify-battery/pass1/mutants.md   # amendment log
grep -n '"--bundle"' -A20 docs/infra/managent/tasks.json
```

## 1. Ordered, registerable row set

Design rule threaded through every row: **holds on `docs/epistemic/CLAIMS.md`
are the scarce resource**, not compute. Every live row in the 231-row register
that Phase 3 touches ultimately needs a status edit to that one file (one
writer per file, `AGENTS.md`). So the row set is split into **measurement rows**
(parallel, hold only instrument/source files, never touch CLAIMS.md, produce a
`findings/*.json` with proposed transitions) and **register-write rows**
(serialized, hold CLAIMS.md + register-tree-map.md exclusively, apply
transitions with `audited_by` per the C11 tier-A gate). This mirrors the
kernel's own "one production implementation, one owner" doctrine applied to
the register file instead of a `.zig` file, and it's why measurement work can
run all four ladder rungs concurrently while the paperwork stays serial and
cheap.

Per-goban independence (`GLOBAL.ADR0016-INHERIT`, NC3) licenses running the
four ladder rungs in parallel rather than waiting for 2×2 before starting 4×4;
DIRECTION's "ladder 2×2 → 3×2 → 3×3 → 4×4" states an evidentiary order
(smaller rungs corroborate the method before trusting it at scale), not a
dispatch order — consistent with Amendment 2 ("phase order is dependency
order, not calendar order," the same ruling that unblocks Phase 3 dispatch
today).

| # | slug | title (≤40) | needs | holds (exclusive) | size |
|---|---|---|---|---|---|
| 1 | `w3-00-inventory` | Waypoint-3 inventory & staleness sweep | — | `PHASES.md` | M |
| 2 | `w3-01-retire-ratify` | Retirement ratification, by family | — | none (proposal only) | S |
| 3 | `w3-02-axiom-closure` | Z-R axiom joint-closure instrument | — | new file + `differential.zig`* | M |
| 4 | `w3-03-key-adversarial` | Adversarial key-agreement coverage | `w3-02` (file hold) | `differential.zig`* | M |
| 5 | `w3-2x2-diff` | 2×2 kernel-vs-fixture differential | `w3-00` | none (read-only + own findings) | S |
| 6 | `w3-3x2-diff` | 3×2 kernel-vs-fixture differential | `w3-00` | none | S |
| 7 | `w3-3x3-diff` | 3×3 kernel-vs-fixture differential | `w3-00` | none | M |
| 8 | `w3-3x3-anchor` | 3×3 anchor: retire finisher lineage | `w3-3x3-diff` | none | S |
| 9 | `w3-4x4-diff` | 4×4 kernel-vs-fixture differential | `w3-00` | none | L (mostly citation, §0.1) |
| 10 | `w3-mutate-topup` | Per-invariant mutant top-up | — | `vb_mutants.zig`, `vb_i4.zig`-family | L |
| 11 | `w3-write-all` | Register write-back, all rungs | `w3-01`,`w3-02`,`w3-03`,5–9,`w3-mutate-topup` | `CLAIMS.md`, `register-tree-map.md` | M |
| 12 | `w3-gate` | Waypoint-3 completion gate (new claimlint check) | `w3-write-all` | `claimlint.zig` | M |

\* rows 3–4 both touch `differential.zig`; `w3-03` declares `needs: w3-02` purely
to serialize the file hold (not a logical dependency — the two checks are
independent) rather than have both lanes contend for the same hold at once.

None of the twelve rows needs a human mid-flight: row 2 packages a ratification
*ask* and completes on delivery of that ask, not on receiving an answer — any
family the human hasn't ruled on by the time `w3-write-all` runs is treated
conservatively as **still live** (DIRECTION's default: unverified until
re-derived), so nothing stalls waiting on the human. Rows 3, 4, and 10 build
new instruments and are themselves the risky/uncertain-size items; everything
else is bounded by an artifact that already exists.

### Row detail

**1. `w3-00-inventory`** — Deliverables: `findings/<id>-w3-inventory.json`, one
entry per live register row (231, per live claimlint C0) recording
`{id, tree_node, current_status, has_kernel_era_evidence: bool, evidence_ref,
action: "promote-only" | "re-derive" | "no-op-already-Phase3-clean"}`; plus a
rewrite of `PHASES.md`'s Phase-3 line and the G3b table row to remove the two
staleness items in §0. Acceptance: every row of CLAIMS.md appears exactly once
in the inventory (mechanically diffable against claimlint's row list); PHASES.md
no longer contradicts a committed finding newer than itself. This is the actual
decomposition input the brief's §1 needs and DIRECTION never had — without it,
rows 5–9 don't know what's promote-only vs needs-new-measurement, and would
over-commission compute.

**2. `w3-01-retire-ratify`** — Deliverables: one packaged decision request per
`register-tree-map.md` §2 family (ruleset-choice, old-artifact, player,
process, design, crisis-diagnostic, absorption, falsified-foundation — 8
asks, not 116+ individual ones) plus any rows §1's RETIRED cells still carry
live (unarchived) that the operator hasn't ruled on. Acceptance: 8 (or fewer,
if some are already ratified — check first) yes/no asks delivered in one
findings file; no CLAIMS.md edit.

**3. `w3-02-axiom-closure`** — closes register-tree-map §5 item 1 (Z-R has no
row: axioms are never checked to *collectively* define a computable ruleset).
Deliverable: a differential harness — two independently-authored legality
transcriptions run over a shared position sample, diff on disagreement.
Controls (mandatory, this is new instrument work): null = kernel vs itself,
0 disagreements; seeded-defect = one transcription with suicide-check
disabled, must disagree ≥1. Acceptance: harness wired into `zig build test`,
both controls pass, `findings/<id>-axiom-closure.json` states the sample and
denominator.

**4. `w3-03-key-adversarial`** — closes register-tree-map §5 item 2. Extends
the T267/T345 key-agreement machinery from first-legal-move self-play to
adversarial (e.g. minimax-guided) move selection, so cycle-intensive ko
positions are actually exercised — the existing invariant's own documented
caveat. Controls: reuse T345's KEY-4x4 colex-bit-flip seed (already proven
sensitive), add one adversarial-path-specific seed. Acceptance: adversarial
sweep run at ≥1 size with a stated denominator, committed.

**5–9. `w3-{2x2,3x2,3x3,4x4}-diff`** — one row per ladder rung. Deliverable:
run the applicable battery invariants (I1–I12 per `instrument-coverage.md`'s
coverage map) plus C-A1/C-A2 closure (parametric on board size already,
`src/vb_closure.zig:81-82` reads `w,h` from the artifact header — no new code
needed to point it at 2×2/3×2/3×3) against that rung's frozen fixture, kernel
vs fixture, differentially. **Where `w3-00` marks a node "promote-only"** (this
is expected to be most of 4×4 per §0.1), the row's job is to re-cite the
existing exhaustive evidence under a Phase-3 task ID, not recompute it — do
not re-run a 616M-entry sweep that already has a committed, reproducible
result. Deliverable: `findings/<id>-<size>-w3-differential.json`,
`{node, status_measured, denominator, promote_only: bool, evidence_ref}` per
tree node applicable at that size. No CLAIMS.md write. Acceptance: every tree
node with a row at that size (per `register-tree-map.md` §1) has an entry;
zero silent skips.

**8. `w3-3x3-anchor`** — DIRECTION §5 names this rung specifically
("3×3 anchor reconciled honestly"), and `CLAIMS.md`'s falsified-foundation
family confirms why: `3x3.C1` still carries `d:3x3.F2`, and `GLOBAL.F2`
(bracket-guided finisher soundness) is the row `register-tree-map.md` §2.8
lists as foundation-falsified. Deliverable: re-derive `3x3.C1` directly from
the kernel's ADR-0020 loopy-game fixpoint build, with **no dependency edge to
`GLOBAL.F2` or any finisher-lineage row** — the same "median build without the
finisher" pattern `GLOBAL.F2-REMEDY` already established. Acceptance: `3x3.C1`
has a clean dependency chain not passing through a FALSE-AS-SCOPED or
falsified-foundation ancestor (this is C1a's own check — kill two birds:
running C1a on the new edge set is the acceptance test).

**10. `w3-mutate-topup`** — the real remaining mutation-adequacy gap
(§0 item 2): per-invariant synthetic mutants for I4 (Bellman residual), I1
(pin census), I8 (truncation-gap), I9 (anchors) — none exist yet, per
mutants.md §7 and T290's original A1a–A1l acceptance-criteria list (never
executed as T292 apparently only wired golden-master baselines, not this
per-invariant set — OPEN, verify against T292's actual deliverable before
assuming the gap). Deliverable: one mutant + kill-verification fixture per
named invariant in `src/vb_mutants.zig`, red-then-green, wired into
`zig build test`. **This row gates promotion, not dispatch** (Amendment 2 edge
5): rows 5–9 and 3–4 can run and even reach `w3-write-all` without this row
landing first, but no claim whose function these mutants cover may move past
`CLAIMED` to `PROVEN` until this row's kill matrix is green. Size L because a
new mutant per invariant is new adversarial-thinking work, not mechanical.

**11. `w3-write-all`** — the single serialized register-edit pass. Applies
every transition proposed by rows 2 (ratified families only), 3, 4, 5–9, and
gated by 10 (promotions only where the covering mutants are killed;
otherwise the row stays at its current status with the new evidence cited but
no status change — "re-derived, not promoted" is itself a valid, honest
outcome DIRECTION licenses). Every tier-A transition (→PROVEN, →FALSE/
FALSE-AS-SCOPED, →retired) carries `audited_by` per the existing C11 policy.
Deliverable: the CLAIMS.md + register-tree-map.md edits, one commit.
Acceptance: `bin/weizigo-claimlint` C1a/C1b/C6/C9/C11 all still 0 (floor never
rises), C0 row count reconciles against the inventory from row 1.
**Alternative considered:** four smaller per-rung write rows instead of one
combined row, for incremental landmark visibility. Rejected as the default
because the CLAIMS.md hold makes them serial anyway (no parallelism gained)
and four small commits to one file cost more merge/lock overhead than one
combined commit; if the synthesizing seat wants earlier partial visibility
(e.g. to declare 4×4 progress before 2×2 lands), split this row back into
four — the row boundary is a judgement call, not a correctness requirement.

**12. `w3-gate`** — mechanizes "Phase 3 complete" (point 4 of the brief).
New claimlint check, next free ID after C14: **C15 REVERIFIED**. Fails if any
live, non-retired register row's evidence column lacks a citation to a
Phase-3-era task ID (rows 1–11 above establish the citation convention — reuse
the existing `e:`/evidence-path convention, tagged with the task ID, rather
than inventing a twelfth register column; C9's mapping-document pattern is the
precedent for "additive, not a new column"). Composite gate =
**C9 = 0** (mapping intact, already true) **AND C11 = 0** (tier-A audits
present, already true) **AND new C15 = 0** **AND C8 promoted from
report-only to floor-gated at 0** (currently 0 anyway, but not yet enforced —
promoting it to a hard gate is this row's actual mechanism-not-prose act)
**AND `zig build test` green AND `zig build battery-sweep` green** (or, for
rungs where the full sweep is genuinely gated behind an env var for scale
reasons — `WEIZIGO_CLOSURE_4X4_FULL=1`, already true of 4×4 — a committed
run's output stands in for a live CI run, same convention T383's finding
already uses). Deliverable: the check plus its own known-good/known-bad
calibration pair (per DIRECTION §7 — a new instrument ships with both
controls or it doesn't ship), added to `tools/hooks/claimlint-floor.json` at
`C15: 0`.

## 2. Sequencing rationale

The five Amendment-2 dependency edges, applied:

- **Edge 1** (C-A1/C-A2 ← Phase-2 kernel move generator) and **edge 2**
  (moving a function ← an invariant that kills its own mutant) are **already
  satisfied** — T273 (kernel extraction) and T530 (10/10 catalogue kill rate)
  both closed in 2026-08. This is why rows 5–9 can dispatch today with no
  further Phase-2 work as a prerequisite.
- **Edge 3** (Phase-3 row re-derivation ← battery exists AND register-tree
  mapping exists) is **already satisfied** — the battery is wired into
  `zig build test`/`battery-sweep`, and `register-tree-map.md` exists with
  live C9 = 0. This is the edge DIRECTION names as the hard gate on Phase-3
  *dispatch*, and it is clear. **Phase 3 has been dispatchable since T305/T292
  closed (2026-08-03/04); it was never decomposed, not because it was
  blocked.**
- **Edge 4** (Phase-4 swap ← Phase-3 differential verification) means nothing
  downstream of `w3-gate` is chartered here — the swap is a separate,
  future decomposition that takes `w3-gate`'s green state as its own
  precondition.
- **Edge 5** (promotion past CLAIMED ← mutants killed for that function) is
  the edge that actually **shapes this decomposition's row split**: it is why
  measurement (rows 3–9) and mutation top-up (row 10) are independent,
  parallel-eligible rows rather than one row each, and why `w3-write-all`
  must treat "re-derived but not promoted" as a legitimate terminal state per
  row rather than blocking on row 10 to even start.

Within that frame, rows 1–2 (inventory, retirement) come first because they
shrink and de-risk everything downstream — 1 prevents re-computing work T383/
T475/T530 already did, 2 shrinks the row-11 denominator by however many
families the operator retires. Rows 3–4 (new instruments) and 5–9 (per-rung
differentials) are mutually independent and should dispatch in parallel; the
DIRECTION ladder order (2×2→3×2→3×3→4×4) is evidentiary, not a dispatch
gate, per Amendment 2 and NC3's per-goban independence. Row 10 runs in
parallel with everything else and only gates the *promotion* half of row 11's
work, not row 11's dispatch. Row 12 is last by construction — it can only
mechanize completion once there's something to check completion of.

## 3. Controls

Per never-trust-a-green-test / DIRECTION §7 ("every instrument carries a null
control and a seeded-defect control before its first reading counts"):

| instrument | reused as-is? | null control | seeded-defect control |
|---|---|---|---|
| battery I1–I12 (`vb_*.zig`, `zig build test`) | **yes** | in-memory clean synthetic artifact | `vb_mutants.zig` M1–M10 catalogue, 10/10 killed (T530) |
| claimlint C1–C14 | **yes** | 15 known-good synthetic arms (printed every run) | 18 known-bad synthetic arms; `calibration: PASS` live |
| C-A1/C-A2 closure (`vb_closure.zig`) | **yes**, parametric on size already | 3×3 exhaustive test in suite (0 violations) | T342's one-entry-deleted 3×3 WZO2 fixture (forward closure 0→2, backward 0→1, restore 0/0) — **OPEN: confirm an equivalent seeded fixture exists for 2×2/3×2, or mint one as part of rows 5–6; not confirmed by this reading** |
| I11 differential (`vb_i11.zig`) | **yes** | kernel-vs-alias-of-kernel → 0 vacuously | allows-suicide mutant → nonzero (T346) |
| key-agreement (`differential.zig`, T267/T345) | **yes** for first-legal-move coverage | producer==consumer on clean fixture | colex-bit-flip mutant (T345 KEY-4x4), passes-bit-drop / pre-T265-ko mutants (T530, now per-mutant-verified) |
| Z-R axiom joint-closure (row 3) | **no — new** | must ship: kernel vs itself, 0 disagreements | must ship: one transcription with a named axiom disabled, ≥1 disagreement |
| adversarial key coverage (row 4) | **no — new** | reuse T345's clean-fixture null | must ship: an adversarial-path-specific seeded mutant, distinct from the first-legal-move-era ones |
| per-invariant mutants I1/I4/I8/I9 (row 10) | **no — new** | each ships its own | each ships its own, red-then-green, per DIRECTION §7 |
| `w3-gate`'s new C15 check | **no — new** | a register with every row Phase-3-cited → silent | a register with one row missing the citation → caught |

## 4. The finish line

**Waypoint 3 / Phase 3 is complete when `w3-gate`'s composite check (row 12,
§1) passes**, i.e. a single command's exit code, not a prose declaration:

```
bin/weizigo-claimlint   # C9=0, C11=0, C15=0, C8=0-and-floor-gated
zig build test          # green, includes all battery + claimlint gates
zig build battery-sweep # green, or a committed run stands in per the
                         # WEIZIGO_CLOSURE_4X4_FULL=1 convention already in use
```

This is deliberately a **stricter** bar than "every row re-derived" in the
loose sense — it requires every re-derivation to be *citable* (C15) and every
promotion to be *mutation-backed* (C8 floor-gated), so a future row can't
quietly mark itself Phase-3-done by prose alone. It is also **not** the same
bar as "every row is PROVEN" — DIRECTION never asks for that, and edge 5 makes
some rows' honest terminal state "CLAIMED, re-derived, Phase-3-cited,
promotion blocked on row 10" rather than PROVEN. C15's job is to make that
distinction mechanically checkable rather than a matter of who remembers.

## 5. Assumptions stated as OPEN

- Whether T292 already delivered the per-invariant A1a–A1l mutant set that row
  10 assumes is missing — I read mutants.md's own §7 gap list and T290's
  acceptance-criteria naming, not T292's shipped diff; verify before
  registering row 10 at size L.
- Whether a seeded-defect fixture for C-A1/C-A2 closure exists at 2×2/3×2 (only
  confirmed at 3×3, T342) — rows 5–6 should mint one if not.
- The exact count of live (unarchived) rows still carrying an unruled `RETIRED`
  disposition inside CLAIMS.md's own table, distinct from the 132 already moved
  to `archives/register/` — row 1's inventory settles this; I did not enumerate
  it by hand here.
- Whether "Waypoint" or "Phase" is the ratified term by the time this is read
  (§ Naming) — does not change the row set.
- Whether the malformed `"--bundle"` / `T430-phase2-audit.md` kanban row (§0
  item 4) should be repaired to point at this document, or closed as
  superseded — a housekeeping call for the synthesizing seat, not a Phase-3
  substance question.
