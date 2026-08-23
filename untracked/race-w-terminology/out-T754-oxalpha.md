# Race W output — ox-alpha lane (T754, 2026-08-23)

Two drop-in sections. Section A replaces `docs/infra/GLOSSARY.md`'s "The three ladders — the
collision triangle" section verbatim. Section B replaces `docs/audits/2026-08-02-grand-audit/DIRECTION.md`
§5 (heading through the standing-policy paragraph) and supplies the file's single header note.
Nothing else in either file changes; every path cited exists at HEAD.

---

## Section A — drop into `docs/infra/GLOSSARY.md`, replacing §"The three ladders — the collision triangle"

```markdown
## The ladders — waypoint, stage, landmark, phase, step

One meaning per reserved term (operator rulings R1–R5, 2026-08-23, recorded in
`findings/T745-terminology.json`). The canonical path is unchanged:
`docs/epics/<epic>/<landmark>/S<n>-<slug>/pass<n>/<phase>.md`.

- **waypoint** — one step of the program ladder W0–W4, dependency-ordered work toward the
  reconstruction, never a calendar slot (`docs/audits/2026-08-02-grand-audit/DIRECTION.md` §5;
  task mapping `docs/epics/E1-markovian/PHASES.md`).
  CONFLICTS: none remaining — the ladder word that used to collide with pass-phase "phase"
  was retired by the 2026-08-23 ruling (see the residue note below).
- **stage** — one leg of the operator's course, Stage 0–4
  (`docs/status/ROADMAP-2026-08-20.md` §§Stage 0–4); legs inside a stage take letters or
  decimals ("race Stage 2a", "Stage 3.1"), never a second ladder word.
  CONFLICTS: none — Stage is the course's word only; it does not number waypoints or passes.
- **landmark** — see the landmark entry above; its home is
  `docs/audits/2026-08-05-handover/LANDMARKS.md`. Landmarks are *points* (observations a human
  verifies); waypoints are *paths* (dependency-ordered work). CONFLICTS: none beyond the
  historical M<n>-mutant collision already recorded there.
- **phase** — one document within a pass (spec, research, scope/ACs, design, plan, build,
  verify, accept, integrate, plus audit loops) (`docs/infra/sprint.md` passN/ file list).
  CONFLICTS: none remaining — this is now the only process sense of the word.
- **step** — the finest grain inside a phase document; steps carry no IDs and never appear in
  paths. CONFLICTS: none.

The ratified seven-level hierarchy, coarsest to finest:

**epic > landmark > waypoint > sprint > pass > phase > step**

Sprints may be predefined early or defined at close; both are sprints. Landmarks observe,
waypoints build, phases document, steps enumerate.

### Stage ↔ Waypoint correspondence (honestly not 1-1)

| course stage | waypoint territory |
|---|---|
| Stage 0 handover · Stage 1 L1-into-tooling · Stage 2 the races | **none** — fleet/measurement arcs entirely outside the waypoint ladder |
| Stage 3 the L2 foundation | ≈ Waypoints 2–3 territory |
| Stage 4 the clean story | ≈ Waypoint 3 finish + narrative |

No stage maps to a unique waypoint and no waypoint to a unique stage; the table is territory,
not equivalence. Never write "Stage N = Waypoint M".

### Reserved ID tokens

**L<n> is reserved exclusively for LANDMARKS.md checkpoints and is project-globally unique.**
No other ladder or axis may mint L tokens — including the fleet/science binary axis. Waypoints
are W0–W4; stages carry no numeric token; phases are named files.

### Usage (correct / incorrect)

- ✅ "Waypoint 3 gates promotion on mutation adequacy."
  ❌ "Phase 3 gates promotion on mutation adequacy."
- ✅ "the acceptance battery lands in W1, before W2 kernel code."
  ❌ "Stage 1 lands before Phase 2 code." (stage ≠ waypoint; phase ≠ waypoint)
- ✅ "L2 (proven 4×4 values) needs W3's reverification ladder."
  ❌ "L2 is where we extract the kernel." (kernel extraction is W2; L2 is a landmark point)

Residue note (the single one permitted in this file): the 2026-08-23 ruling renamed this
ladder project-globally; documents written before that date may still use the old ladder word
in the DIRECTION sense — read such occurrences as Waypoint per `findings/T745-terminology.json`.
```

---

## Section B — drop into `docs/audits/2026-08-02-grand-audit/DIRECTION.md`

**(b1)** Replaces §5 in full — heading, waypoint list, and standing-policy paragraph:

```markdown
## 5. The plan — five waypoints, gates mechanized from day one

The reconstruction runs as five waypoints, W0–W4. Waypoint order is **dependency order, not
calendar order** (Amendment 2): no waypoint gates the dispatch of another, concurrency across
waypoints is permitted and expected, and the real serializer is file ownership — one writer per
file, enforced through managent sets.

- **W0 — theorem and axioms.** AXIOMS.md written; requirement tree derived top-down from Z;
  old register rows mapped onto it; MIGOS/tie adjudicated. Deliverable: the theorem statement
  and the tree of lemmas it needs. W0 gates decomposition.
- **W1 — acceptance battery before code.** The battery is built and **calibrated on synthetic
  defects first**, seeded from the historical defect catalogue (Amendment 1): every seeded
  known-bad must fail, or the instrument is blind. `0c3366f0` is a regression input — the
  battery must not newly fail it, and any new failure against it is a finding to adjudicate.
- **W2 — kernel extraction.** One function, one owner; ko and state-key first. All harnesses
  wired into `zig build test`; nothing green that doesn't run.
- **W3 — A–Z reverification.** Ladder 2×2 → 3×2 → 3×3 (anchor reconciled honestly) → 4×4.
  Kernel vs fixtures differentially at every rung; every register row re-derived, demoted, or
  retired against the requirement tree.
- **W4 — the swap.** Kernel becomes production; epic-01 legacy code frozen into its fixture
  role; `src/` gains the engine/experiment boundary.

**Standing policy, from the audit's clearest lesson (prose rules rotted; coded rules held):**
every gate in this plan is mechanized — a hook, a lint check, a battery run — from the day it
is declared, and promotion past `CLAIMED` is gated on mutation adequacy: the mutants covering
a claim's function are killed (Amendment 2, edge 5). A rule that stays prose is a rule we have
chosen to re-learn.
```

**(b2)** The header note — the ONLY "formerly Phase" residue permitted anywhere in this file.
Drop in immediately after the existing Status block at the top:

```markdown
> **Terminology (2026-08-23, operator ruling R1 — `findings/T745-terminology.json`):** the
> program ladder is written **Waypoint 0–4 (W0–W4)** project-globally; §5 below uses that
> vocabulary in full. The old ladder word "Phase" survives in this file only in pre-ruling
> prose (Amendments 1–2, §7) — read every such occurrence as Waypoint under this note, which
> is this document's sole sanctioned residue.
```

---

**Landmark:** advances `L4 (the ledger is clean)` — one meaning per reserved ladder term, with
the Stage↔Waypoint non-mapping stated honestly and L<n> locked to LANDMARKS.md — what remains
is T757's blind adjudication and the mechanical sweep of the 14 carrier files.
