# Race W — deepseek-v4-pro lane (T756)

Lane: deepseek-v4-pro/T756. Blind output for T757's adjudication. The two sections below
are drop-in replacement text; the framing lines (this header and the `---` separators) are
NOT part of the replacement. Inputs read statically at HEAD: `findings/T737-glossary.json`,
`findings/T745-terminology.json` (R1–R5), `docs/infra/GLOSSARY.md`,
`docs/audits/2026-08-02-grand-audit/DIRECTION.md`, `docs/status/ROADMAP-2026-08-20.md`,
`docs/audits/2026-08-05-handover/LANDMARKS.md`.

---

## Section A — replaces GLOSSARY.md "The three ladders — the collision triangle"

## The three ladders — one word each

The collision triangle is resolved: the three numbered ladders keep their three words, and no
two share one (operator R1–R4, 2026-08-23). The program ladder is renamed **waypoint**; the
course ladder keeps **stage**; the pass-internal document keeps **phase**.

| ladder | word | numbering | defining doc |
|---|---|---|---|
| program ladder | **waypoint** (Waypoint 0–4) | 0 axioms · 1 battery · 2 kernel · 3 A–Z reverification · 4 swap | `docs/audits/2026-08-02-grand-audit/DIRECTION.md` §5 |
| operator course | **stage** (Stage 0–4) | 0 handover · 1 L1-into-tooling · 2 races · 3 L2 foundation · 4 clean story | `docs/status/ROADMAP-2026-08-20.md` |
| pass-internal document | **phase** | spec, research, scope/ACs, design, plan, build, verify, accept, integrate + audit loops | `docs/infra/sprint.md` |

- **waypoint** — one rung of the program ladder Waypoint 0–4 (Waypoint 0 theorem and axioms ·
  Waypoint 1 acceptance battery before code · Waypoint 2 kernel extraction · Waypoint 3 A–Z
  reverification · Waypoint 4 the swap), ordered by dependency, not calendar
  (`docs/audits/2026-08-02-grand-audit/DIRECTION.md` §5 + Amendment 2; task mapping in
  `docs/epics/E1-markovian/PHASES.md`).
- **stage** — one rung of the operator-facing course Stage 0–4 (Stage 0 handover · Stage 1
  L1-into-tooling · Stage 2 races · Stage 3 L2 foundation · Stage 4 clean story)
  (`docs/status/ROADMAP-2026-08-20.md`).
- **landmark** — a checkpoint the operator can verify without reading a brief, ID L0–L7, every
  ID written with its short name; see the landmark entry in "The work hierarchy" above and
  `docs/audits/2026-08-05-handover/LANDMARKS.md`.
- **phase** — one document within a pass: spec, research, scope/ACs, design, plan, build,
  verify, accept, integrate, plus audit loops (`docs/infra/sprint.md`); unchanged by the rename.
- **step** — the finest grain inside a phase document, the bottom of the hierarchy below phase
  (`docs/infra/GLOSSARY.md`).

**The ratified hierarchy** (operator, 2026-08-23): **epic > landmark > waypoint > sprint > pass
> phase > step** — landmarks are points (observations a human verifies), waypoints are paths
(dependency-ordered work); sprints may be predefined early or defined at close; "step" is the
finest grain inside a phase document.

**Stage ↔ Waypoint is NOT 1-1.** Stages are course arcs (time and people); waypoints are
dependency-ordered work. The honest correspondence:

| Stage (course) | Waypoint (program) |
|---|---|
| Stage 0 — handover | outside the waypoint ladder |
| Stage 1 — L1 into tooling | outside the waypoint ladder |
| Stage 2 — the races | outside the waypoint ladder |
| Stage 3 — L2 foundation | ≈ Waypoints 2–3 territory |
| Stage 4 — clean story | ≈ Waypoint 3 finish + narrative |

**L<n> reservation.** L<n> tokens are reserved exclusively for the LANDMARKS.md checkpoints
(L0–L7), project-globally unique; the fleet/science binary axis may not reuse L tokens. Write
`L4 (the ledger is clean)`, never a bare `L4`.

**Usage (correct / incorrect):**

- correct: "Waypoint 1 gates promotion on mutation adequacy." · incorrect: "Phase 1 gates
  promotion…" (a phase is a pass document, not a program rung).
- correct: "Stage 3 banks L2 (proven 4×4 values)." · incorrect: "Waypoint 3 banks L2" (the
  course arc is a Stage; the program rung is a Waypoint).
- correct: "the build phase of pass0" · incorrect: "the build step of pass0" (a step is finer
  than a phase document).

---

## Section B — replaces DIRECTION.md §5 heading + body, plus the single header residue note

## 5. The plan — five waypoints, gates mechanized from day one

Five waypoints carry epic-01 from the axioms to the swap; each gate is mechanized from the day
it is declared.

- **Waypoint 0 — theorem and axioms.** AXIOMS.md written; requirement tree derived top-down from
  Z; old register rows mapped onto it; MIGOS/tie adjudicated. Deliverable: the theorem
  statement and the tree of lemmas it needs.
- **Waypoint 1 — acceptance battery before code.** The battery is built and calibrated on
  **synthetic** defects seeded from the historical defect catalogue first — every historical
  defect (T178/T193/T265 key mismatches, incompleteness, inversion violations, the stubbed
  battery) becomes a seeded known-bad control, and the `0c3366f0` artifact is a regression
  input the battery must not newly fail (Amendment 1).
- **Waypoint 2 — kernel extraction.** One function, one owner; ko and state-key first. All
  harnesses wired into `zig build test`; nothing green that doesn't run.
- **Waypoint 3 — A–Z reverification.** Ladder 2×2 → 3×2 → 3×3 (anchor reconciled honestly) →
  4×4. Kernel vs fixtures differentially at every rung; every register row re-derived,
  demoted, or retired against the requirement tree.
- **Waypoint 4 — the swap.** Kernel becomes production; epic-01 legacy code frozen into its
  fixture role; `src/` gains the engine/experiment boundary.

**Waypoint order is dependency order, not calendar order** (Amendment 2). No waypoint gates the
dispatch of another; code may be written before its battery coverage is complete, but no claim
about that code may be promoted past `CLAIMED` until the battery kills the mutants covering the
function the claim is about (the mutation-adequacy promotion gate).

**Standing policy, from the audit's clearest lesson (prose rules rotted; coded rules held):**
every gate in this plan is mechanized — a hook, a lint check, a battery run — from the day it
is declared. A rule that stays prose is a rule we have chosen to re-learn.

### Header residue note (place once, at the top of DIRECTION.md)

> **Waypoint terminology (ratified 2026-08-23):** the plan in §5 was originally ratified as
> "five phases"; the operator renamed the program ladder to "Waypoint 0–4" (R1). This note is
> the only place in this file the old word survives.
