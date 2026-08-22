# S05 — spec: one verb to orient any agent (`managent orient --role`)

**Artifact type: SPEC** (`docs/infra/sprint.md` — a spec says what we want, testably, for one
pass). **Owner:** deepseek-v4-pro/T583 · **Date:** 2026-08-22 · **Status:** PROPOSED — audited
before anything is built. Not a worker brief, not a plan, no code.

**Sits on:** the seed (`seed.md`, this directory), the census (`findings/T583-startup-census.json`,
this task; prior helper census `findings/T585-startup-census.json`), `docs/infra/sprint.md` (pass
protocol, audit loop), `docs/status/orchestration-layer-spec.md` §7c (rulings in force),
`docs/infra/delegation/ROLES.md` (the role taxonomy and concurrency authority).

**Inputs.** `seed.md` §1–§5 · `findings/T583-startup-census.json` (24 surfaces, 9 archaeology
items A1–A9) · `orchestration-layer-spec.md` §7c.21 (audit-loop cap 3), §7c.29 (orchestrator work
boundary), §7c.22 (never-idle) · `sprint.md` (spec/plan/accept bookends, TDD, archive-gate
citation invariant).

**One line.** `managent orient [--role <r>]` becomes the single startup verb: any agent, any
model, any seat, at any time receives a current, contradiction-free, role-sized orientation
composed at read time from the store and a small audited source set — and no agent assembles its
own startup reading list again.

**Citation pins.** Every `file:line` in this document is against `HEAD` at authoring time, commit
`e58fcec` (2026-08-22). References to other spec documents are by **§ref**; each §ref is tagged
with its document's rev/pin where load-bearing. A citation that no longer resolves at `e58fcec`
is a spec defect, not a reader's problem.

---

## 0. How to read this document

Every normative statement carries an id (`SURF-*` for the census/archaeology half, `ORIENT-*`
for the orient/role/control half). §6 is the control table: the seed's named controls (§5) are
the **mandatory core**; the test phase writes one seeded arm (flip) and one null arm (green) for
**every** normative id before the first live reading. An id with no control is not a requirement,
it is a wish (the project's standing rule: *an instrument earns its first reading only after a
null control and a seeded-defect control*).

The sprint is five phases. Phase 1 (census) is **done** — its result is the census file, and it is
the evidence base for everything after it. Phases 2–5 are sequenced in §3–§6; none of them starts
before the census is absorbed, because the whole point of the sprint is that `orient` composes
from **clean** inputs (seed §3.2: "prose is not a remedy" — a contradiction is fixed at its
source or the source is deleted).

---

## 1. Goal and scope

**SURF-GOAL-1 (the goal).** One verb, `managent orient [--role <r>]`, orients any agent at any
time: a current, contradiction-free, role-sized orientation composed at read time from the store
and a small set of audited sources (seed §1). The inverse of today: the principles section is
hard-coded (census A9), the output is one-size-fits-all, and the sources that feed it are
unaudited (seed §2).

**SURF-GOAL-2 (what is out, named).** No new documents — the sprint deletes more than it writes
(seed §4). No change to the sprint pass protocol (`sprint.md`). No memory-system changes: Claude
auto-memory is harness-scoped convenience, not a project surface, and nothing project-critical
may live only there (seed §4, census S24). The sprint does **not** build the queue, the
supervisor, the dashboard, or the reconciler — those are S01/S03/S04; this sprint touches only
the startup surface (`orient` + the documents it composes from).

**SURF-GOAL-3 (the deliverable boundary).** The sprint's outputs are: (a) the census
(`findings/T583-startup-census.json`) — done; (b) the archaeology fixes (edits or deletions to
the census-cited files, §3); (c) the role-sized `orient --role` verb with its controls
(`src/managent/main.zig` + snapshot/contradiction tests, §4–§6). Anything else is a separate row.

---

## 2. Phase 1 — census (done, read-only)

**SURF-CENSUS-1 (enumeration).** The census enumerates every startup-read surface and classifies
each. Result: **24 surfaces** across the seed's 10 named categories plus `ROLES.md` and the two
commands (`orient`, `resume`) and Claude auto-memory — with a breakdown of **12 clean · 8
contradictory · 3 deliberately-stale stubs · 1 clean-but-miscategorized** (see
`findings/T583-startup-census.json` `denominators`).

**SURF-CENSUS-2 (archaeology).** The census records **9 archaeology items (A1–A9)**: 4 must
(A1 stale tool name in `DELEGATEE.md`; A3 superseded DeepSeek cap in `sprint.md` +
`manager-brief-template.md`; A4 stale succession template `docs/status/HANDOVER.md`; A8
contradicted `claims`-array rule in `manager-brief-template.md`) · 3 should (A2 drifted citation;
A5 duplicated `argus`-mode omission; A9 hard-coded orient principles) · 1 could (A7 miscategorized
directory) · 1 note (A6 navigator not recorded). Every item cites a `file:line` verified against
the working tree at `e58fcec`.

**SURF-CENSUS-3 (provenance).** The load-bearing archaeology items (A1, A2, A3, A4, A5, A8, A9)
were independently re-verified by this worker, not taken on faith from the prior helper census
(`findings/T585-startup-census.json`, claude-sonnet-5/T585). The census is self-contained: a
reader of `findings/T583-startup-census.json` needs no other file.

---

## 3. Phase 2 — archaeology deletion (mutation, audited)

**SURF-ARCH-1 (fix at source or delete; prose is not a remedy).** Each of A1–A9 is disposed
**at its source**: an in-place edit that removes the stale/superseded/contradictory text, or a
deletion of the file. No finding is "resolved" by adding a note that a contradiction exists —
the seed is explicit that this is the failure mode the sprint exists to end (seed §3.2).

**SURF-ARCH-2 (the fix map).** Each archaeology item resolves to a bounded edit, stated here so
the mutation phase is a checklist, not a re-diagnosis:

| item | fix |
|---|---|
| A1 | `DELEGATEE.md:83` — delete the `bin/ollama-subagent` reference; keep `bin/subagent` |
| A2 | `DIRECTION.md:244` — re-pin the `AGENTS.md` citation to current lines (or add the commit pin the file lacks) |
| A3 | `sprint.md:132` + `manager-brief-template.md:22` — delete the "max 2 DeepSeek" cap; point at `ROLES.md` §Concurrency (2026-08-19 no-fleet-cap) |
| A4 | `ORCHESTRATOR.md:5` — re-point the succession template away from the stale `docs/status/HANDOVER.md`; the correct target is decided in design (the recent `handover-*.md` examples are clean, census S8) |
| A5 | `ARGUS.md:3` + `ORCHESTRATOR.md:13` — add `--mode doctor` to both invocation/cadence lines |
| A6 | no edit — carried into §5 (navigator adoption) |
| A7 | `docs/infra/agents/` — move the dated measurement report out of the instruction directory (a move, not a new document) |
| A8 | `manager-brief-template.md:105` — change "must be non-empty" to match the schema ("empty array when none are touched") |
| A9 | no Phase-2 edit — carried into §4 (orient composition) |

**SURF-ARCH-3 (citation invariant).** A file this sprint deletes (S13/S14/S15, the three
retired stubs, are candidates) must be promoted first if the register cites it — the `sprint.md`
archive-gate rule and claimlint C2 apply to deletions exactly as they do to archive sweeps. A
deletion that leaves a dangling `CLAIMS.md` citation is a failed mutation.

**SURF-ARCH-4 (one writer per file, holds declared).** Every Phase-2 edit is a MUTATION task: it
declares its `holds=` on the files it edits, runs serial per held file, and cites the census
item it discharges (`ROLES.md` §Concurrency, `AGENTS.md` foreclosures). Phase 2 is a backlog of
9 bounded mutations, not one big edit.

**SURF-ARCH-5 (audit loop, cap 3).** Phase 2 is audited per the ruled loop (`§7c.21`): red flags
are addressed in-phase and re-audited; past a third red audit the phase blocks and escalates.
The audit's object is the **diff** (did the edit remove the contradiction without introducing
one), not the prose around it.

---

## 4. Phase 3 — role-sized orient (build)

**ORIENT-ROLE-1 (the role set).** `orient --role <r>` accepts exactly:
`leaf | console | auditor | reconciler | navigator`. Default (no `--role`) is `leaf` — the most
common seat. The current one-size output (census S22) becomes the `console` variant's starting
point.

**ORIENT-ROLE-2 (only what the role acts on).** Each variant contains **only** what that role
acts on. A leaf does not get the kanban (it dispatches nothing); an auditor does not get the
dispatch surface; a console gets the full surface. The content-per-role matrix is the design
phase's to fill, but the principle is normative and the snapshot tests (§6) pin whatever matrix
is chosen.

**ORIENT-ROLE-3 (line budgets — stated, enforced).** Each variant is `≤` a stated line budget,
and the gate fails a variant over budget (seed §3.3 "each ≤ a stated line budget"). Starting
proposals (design may tune downward, never upward without the operator):

| role | acts on | budget |
|---|---|---|
| `leaf` (default) | one claimed task: principles, live gates, own-brief pointer | ≤ 60 |
| `console` | a sprint/queue: principles, gates, kanban + holds, fresh activity, handover head | ≤ 150 |
| `auditor` | a scope: scope framing, verification principles, live gates | ≤ 70 |
| `reconciler` | verdict + triage: verb whitelist, escalation contract, tables, gates | ≤ 80 |
| `navigator` | recovery: store state, roadmap, rulings, seeds, git, one-question instruction | ≤ 120 |

**ORIENT-ROLE-4 (principles are composed, not baked — fixes A9).** The principles section must
track its sources: a change to the source docs' rules is reflected in `orient`'s principles, or
it is detected — never silently stale. The census found the current 8 lines are Zig literals with
a provenance header that is false (A9). The requirement is the inverse: the header must be true.
The mechanism is design's to choose from at least three candidates, named here because the choice
changes the control's shape: (a) parse the existing docs at read time; (b) add a machine-readable
marker to the existing docs (an edit to existing files, not a new document — consistent with
seed §4) that `orient` reads; (c) keep a small enumerated set in code but ship a **drift test**
that greps each source doc for its principle's provenance and fails red on drift. (c) is the
minimum bar: it does not change the composition, but it makes drift loud instead of silent, which
is exactly what A9 lacks today.

**ORIENT-ROLE-5 (contradiction detection at compose time).** A contradiction between two audited
sources is **detected** at compose time and reported, never silently harmonized (seed §5). This
is the sprint's hardest requirement and its own control (§6 C5/C6). The scope of "contradiction"
is the census's archaeology classes — superseded rules, drifted citations, stale tool names —
detected mechanically rather than by the next prose sweep.

---

## 5. Phase 4 — the navigator role (adopt deliberately)

**ORIENT-NAV-1 (adopted, with the seed's emission spec).** The navigator role is **adopted** as a
first-class `orient --role navigator`, because the operator named it ("Fable, get us back on
course", seed header) — it is not left as an unrecorded convention. Its emission is the ordered
ground-truth walk, in this order (seed §3.4):

1. **store state first** — `managent status` / `managent audit`;
2. **the newest roadmap** — `docs/epistemic/roadmap-*.md` (or its successor);
3. **rulings in force** — `docs/status/orchestration-layer-spec.md` §7*;
4. **live sprint seeds** — the `S0*-*/seed.md` set;
5. **recent git** — `git log`;
6. the standing instruction: **judge docs against reality; record deviations and corrections
   against the landmarks (`docs/audits/2026-08-05-handover/LANDMARKS.md`); ask the operator at
   most one question.**

The reading list lives in the verb, not in anyone's memory (seed §3.4).

**ORIENT-NAV-2 (the old Navigator is retired, and distinct).** The 2026-07-31 "Navigator" — a
one-round planning seat that set course and retired (census A6, 14 channel messages) — is
recorded as **retired** and is **not** this role. The new navigator is a recovery/orientation
session with no dispatch authority and no queue ownership; the old one was a planning seat. The
two share a name and nothing else; the spec says so to prevent the conflation the census found
(A6: no role file records either).

**ORIENT-NAV-3 (recorded, not memorized).** The adopted role is recorded in the role taxonomy
(`ROLES.md`'s role table) or its own role file — the "adopt deliberately" half of the seed's
§3.4 instruction. Which home is a design decision; "recorded nowhere" is not an acceptable
outcome after this sprint.

---

## 6. Phase 5 — controls (never trust a green preamble)

**ORIENT-CTRL-1 (the battery, scripted against a scratch store).** Each control is scripted
against a scratch store (`MANAGENT_STORE`), regression-suite style. Every normative id in §3–§5
has at least one arm; the seed's named controls are the mandatory core:

| # | control | seeded defect | expected | flips |
|---|---|---|---|---|
| C1 | null | clean sources, quiet store | composes without error, states its line count | SURF-GOAL-1, ORIENT-ROLE-1 |
| C2 | role budget | a `leaf` variant over 60 lines | gate fails, names the role and the overage | ORIENT-ROLE-3 |
| C3 | role isolation | a `leaf` output containing the kanban | gate fails (leaf does not dispatch) | ORIENT-ROLE-2 |
| C4 | provenance | a source principle edited, `orient` re-run | drift detected (header true or drift test red) — never a silently-stale principle | ORIENT-ROLE-4 |
| C5 | contradiction (null arm) | no contradiction between sources | composes cleanly | ORIENT-ROLE-5 |
| C6 | contradiction (seeded) | two sources assert opposite facts on one rule | **detected at compose time** and reported, not silently harmonized | ORIENT-ROLE-5 |
| C7 | navigator walk | `--role navigator` on a live store | emits the §5 ordered walk, one-question instruction last | ORIENT-NAV-1 |
| C8 | snapshot | each role's output vs a pinned snapshot | byte-stable across runs at the same store | ORIENT-ROLE-1/2/3 |

**ORIENT-CTRL-2 (red first).** The first live reading counts only after C1 (null) **and** the
seeded-defect controls pass — red first, then green (seed §5; `sprint.md` TDD; the 2B-5
positive-control failure is the local scar). The controls are written **before** implementation.

**ORIENT-CTRL-3 (the seeded contradiction is a synthetic fixture, not a live doc).** C6's two
contradicting sources are synthetic fixtures under the scratch store — live faults get fixed,
and a check against live data then silently tests nothing (calibration rule).

**ORIENT-CTRL-4 (acceptance).** The sprint's acceptance is `gate: <command>` where possible —
the snapshot tests (C8) and the seeded-contradiction control (C6) as a `zig build test`-wired
regression — with the final acceptance `gate: audit` (seed §5). The audit loop caps at 3
(`§7c.21`): a third red audit blocks and escalates; the sprint cannot close itself past that.

---

## 7. Open questions — resolved at spec vs deferred to design

**Resolved at spec:**

1. **Is Navigator a recorded role?** → No (census A6). Adopted deliberately as
   `orient --role navigator` (ORIENT-NAV-1), distinct from the retired 2026-07-31 seat
   (ORIENT-NAV-2).
2. **Does the default `orient` change?** → Yes: default becomes `leaf`; the current full
   preamble is the `console` variant's starting point (ORIENT-ROLE-1).
3. **Are the principles hard-coded or composed?** → Composed (or drift-tested) — hard-coding is
   the A9 defect, and the requirement is the inverse (ORIENT-ROLE-4).

**Deferred to design (the seed asked, the spec does not invent):**

- the concrete principles-extraction mechanism — (a) parse, (b) in-doc markers, or (c) drift
  test, per ORIENT-ROLE-4;
- the content-per-role matrix (which lines go to which role) inside the ORIENT-ROLE-2 principle;
- the A4 fix target — where the succession template points once `docs/status/HANDOVER.md` is
  retired as a template (the recent `handover-*.md` examples are the clean reference, census S8);
- the A7 move destination for the dated measurement report;
- the navigator's recording home (ROLES.md table vs its own role file).

**Pending operator numbers (spec defaults hold meanwhile, per §7b convention):**

- the five line budgets in ORIENT-ROLE-3 are starting proposals; the navigator's is the one the
  operator named and may want to set himself. The control enforces whatever number is ratified;
  the number itself is tunable, the "≤ stated budget, gate fails on overage" is not.

---

## 8. Rulings traceability — no ruling silently dropped

| ruling / finding | spec home |
|---|---|
| seed §1 (one verb) | SURF-GOAL-1 |
| seed §3.1 (census) | SURF-CENSUS-1/2 |
| seed §3.2 (fix at source / delete, prose not a remedy) | SURF-ARCH-1 |
| seed §3.3 (role-size, line budget) | ORIENT-ROLE-1/2/3 |
| seed §3.4 (navigator) | ORIENT-NAV-1/2/3 |
| seed §4 (no new documents; no memory changes) | SURF-GOAL-2 |
| seed §5 (seeded contradiction, budget gate, snapshot, gate: audit) | ORIENT-CTRL-1/3/4 |
| §7c.21 (audit-loop cap 3) | SURF-ARCH-5, ORIENT-CTRL-4 |
| §7c.29 (orchestrator work boundary) | SURF-GOAL-3 (sprint outputs are the three named artifacts, nothing else) |
| §7c.22 (never-idle) | phases are sequenced, not gated on idle — the sprint is finite and each phase starts when its predecessor closes |
| `sprint.md` archive-gate citation invariant / claimlint C2 | SURF-ARCH-3 |
| `ROLES.md` §Concurrency (one writer, holds) | SURF-ARCH-4 |
| census A1–A9 | SURF-ARCH-2 (fix map), ORIENT-ROLE-4 (A9), ORIENT-NAV-2 (A6) |
