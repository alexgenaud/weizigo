# T755 — Race W lane output (claude-opus-5)

Replacement prose for T757 to drop in. Two sections, each self-contained.

**Drop-in notes for T757 (not part of the replacement text):**
1. Section A replaces the whole `## The three ladders — the collision triangle` section of
   `docs/infra/GLOSSARY.md`, heading included.
2. Every citation below names a path that exists at HEAD. Two of them are the ones your own
   sweep moves: `docs/epics/E1-markovian/PHASES.md` → `WAYPOINTS.md` and
   `docs/audits/2026-08-05-handover/LANDMARKS.md` → `docs/epics/E1-markovian/LANDMARKS.md`.
   Repoint both in the same commit as the `git mv`, so claimlint sees a valid path either way.
3. Two edits outside my sections that the rename obliges: the earlier heading
   `## The work hierarchy: epic > landmark > sprint > pass > phase` gains `waypoint` and `step`
   (the full line is in Section A), and the **phase** entry under it ends with
   `CONFLICTS: **the Phase collision**` — that sentence is now false and should go.

---

## Section A — replaces GLOSSARY.md "The three ladders — the collision triangle"

## The three ladders — waypoint, stage, phase

Three ladders run here, one word each: **waypoints** order the program's work,
**stages** narrate the operator's course, **phases** are the documents inside a pass. The
ratified hierarchy is **epic > landmark > waypoint > sprint > pass > phase > step**
(`findings/T745-terminology.json` R4, ratified 2026-08-23) — landmarks are *points* a human
observes, waypoints are *paths* of dependency-ordered work, and a sprint may be defined early
or named only at its close.

| ladder | word | numbering | defining doc |
|---|---|---|---|
| program ladder | **waypoint** 0–4 | 0 theorem and axioms · 1 acceptance battery before code · 2 kernel extraction · 3 A–Z reverification · 4 the swap | `docs/audits/2026-08-02-grand-audit/DIRECTION.md` §5 |
| operator course | **stage** 0–4 | 0 handover · 1 L1-into-tooling · 2 the races · 3 the L2 foundation · 4 the clean story | `docs/status/ROADMAP-2026-08-20.md` |
| pass-internal document | **phase** | spec, research, scope/ACs, design, plan, build, verify, accept, integrate + audit loops | `docs/infra/sprint.md` |

- **waypoint** — one of the five dependency-ordered steps of the grand-audit program, W0–W4;
  waypoint order is dependency order, not calendar order, and no waypoint gates the dispatch of
  another (`docs/audits/2026-08-02-grand-audit/DIRECTION.md` §5 + Amendment 2; task mapping in
  `docs/epics/E1-markovian/PHASES.md`).
- **stage** — one arc of the operator's course, Stage 0–4, describing who is doing what and when,
  and freely subdivided in place ("race Stage 2a", "Stage 3.1/3.2/3.4")
  (`docs/status/ROADMAP-2026-08-20.md` §§Stage 0–4; one-page map `docs/status/ROADMAP-2026-08-21.md`).
- **landmark** — a checkpoint the operator can verify without reading a task brief; defined in
  full at its own entry above and in its home file (`docs/audits/2026-08-05-handover/LANDMARKS.md`).
- **phase** — one document within a pass, unchanged in sense: the build phase of pass0 is a phase
  (`docs/infra/sprint.md` passN/ file list).
- **step** — the finest grain, one numbered instruction inside a phase document; a step is never a
  kanban row (`findings/T745-terminology.json` R4).

### Stage ↔ waypoint: not one-to-one

| Stage | waypoint territory |
|---|---|
| 0 — Flash wraps up and hands over | none — fleet arc, outside the ladder |
| 1 — L1: the orchestration job moves into tooling | none — tooling arc, outside the ladder |
| 2 — the races | none — measurement arc, outside the ladder |
| 3 — the L2 foundation | ≈ W2–W3 territory |
| 4 — the clean story | ≈ W3 finish, plus narrative that is no waypoint's work |

Stages track time and people; waypoints track dependencies. Stages 0–2 sit outside the ladder
entirely and **no stage covers W0, W1 or W4** — the overlay holds for two rows and nothing more,
so never derive one ladder's position from the other's.

### The `L<n>` reservation

`L<n>` tokens are reserved project-globally for LANDMARKS.md checkpoints, unique there, and
always written with the short name. No other axis may spend an L token — in particular the
retired fleet-vs-science binary area tags of the D041 era, whose residue survives only verbatim
in as-run findings (`findings/T745-terminology.json` R4). L0–L7 are defined; `L8` and `L9` are
*proposals* in `docs/status/landmark-assignment-2026-08-19.md`, not landmarks until LANDMARKS.md
carries them.

### Usage

| write this | not this |
|---|---|
| Waypoint 3 gates promotion on mutation adequacy | Phase 3 gates promotion on mutation adequacy |
| W1's battery is calibrated on synthetic defects | Stage 1's battery is calibrated on synthetic defects |
| Stage 3 resumes the critical path | Waypoint 3 resumes the critical path |
| the build phase of pass0 landed red→green | the build waypoint of pass0 landed red→green |
| step 4 of the accept phase | task 4 of the accept phase |
| `L4 (the ledger is clean)` | a bare `L4`, or `L2` meaning "a science row" |

---

## Section B — replaces DIRECTION.md §5 (heading + body)

## 5. The plan — five waypoints, gates mechanized from day one

Five waypoints carry epic-01 from its axioms to the swap. Each names what must hold before the
next is provable, not a month in which it happens.

- **Waypoint 0 — theorem and axioms.** AXIOMS.md written; requirement tree derived top-down from
  Z; old register rows mapped onto it; MIGOS/tie adjudicated. Deliverable: the theorem statement
  and the tree of lemmas it needs. W0 is the one hard gate: W1–W4 get no new tasks until it lands.
- **Waypoint 1 — acceptance battery before code.** The battery is built and **calibrated on
  synthetic defects first** — seeded from the historical defect catalogue (T178/T193/T265 key
  mismatches, the passes-bit collision, inversion violations, the stubbed battery, incompleteness
  as T261 described it). A check that cannot kill a seeded mutant is blind. The live `0c3366f0`
  artifact is a **regression input**: it must not newly fail, and a new failure is a finding to
  adjudicate (Amendment 1).
- **Waypoint 2 — kernel extraction.** One function, one owner; ko and state-key first. All
  harnesses wired into `zig build test`; nothing green that doesn't run.
- **Waypoint 3 — A–Z reverification.** Ladder 2×2 → 3×2 → 3×3 (anchor reconciled honestly) → 4×4.
  Kernel vs fixtures differentially at every rung; every register row re-derived, demoted, or
  retired against the requirement tree.
- **Waypoint 4 — the swap.** Kernel becomes production; epic-01 legacy code frozen into its
  fixture role; `src/` gains the engine/experiment boundary.

**Waypoint order is dependency order, not calendar order** (Amendment 2). "Acceptance battery
before code" and "calibrated on known-defective inputs first" bind **promotion, not dispatch**:
code may ship while its battery coverage is incomplete, and no claim about it is promoted past
`CLAIMED` until the battery kills the mutants covering the function the claim is about.

**Standing policy, from the audit's clearest lesson (prose rules rotted; coded rules held):**
every gate in this plan is mechanized — a hook, a lint check, a battery run — from the day it is
declared. A rule that stays prose is a rule we have chosen to re-learn.

### The header residue note (the only one this file may carry)

Insert as the last line of the header block, after the `Status:` line:

> Terminology: this document's five-step ladder is **Waypoint 0–4**. Sealed artifacts and audits
> written before 2026-08-23 number the same five steps `Phase 0–4`; read them as waypoints
> (rename ratified 2026-08-23, `findings/T745-terminology.json` R1).
