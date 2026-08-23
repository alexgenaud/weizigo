# GLOSSARY — reserved terms (infra & process)

**Status: living reference. [Current.]** Created by deepseek-v4-flash/T737, 2026-08-23, per the
operator ruling of 2026-08-23 (reserved terms live in a canonical glossary; one term per entry,
one sentence each, a citation to the defining doc, a CONFLICTS note where a collision exists
today). Companion to the epistemic vocabulary in `docs/epistemic/GLOSSARY.md` — this file is
about *process/workflow* terms; that one is about *engine/Go* terms. Where a term appears in both
(e.g. "pass", "phase"), this file owns the process sense and flags the other.

## The work hierarchy: epic > landmark > waypoint > sprint > pass > phase > step

The canonical path is `docs/epics/<epic>/<landmark>/S<n>-<slug>/pass<n>/<phase>.md` — a sprint
lives under its PRIMARY landmark (`docs/status/refactor-migration-map.md:9-10`).

The hierarchy is coarsest-to-finest, and two of its levels overlap on purpose: **landmarks are
points** (observations a human verifies) while **waypoints are paths** (dependency-ordered work),
so a landmark can sit inside a waypoint or straddle two. A sprint may be predefined early or
defined only at its close; both are sprints (operator ruling R4, 2026-08-23,
`findings/T745-terminology.json`).

**`L<n>` is reserved project-globally for the landmark checkpoints defined in
`docs/epics/E1-markovian/LANDMARKS.md`, and is unique there.** No other axis may mint an L token —
in particular the retired fleet-versus-science binary area tags of the D041 era, whose residue
survives only verbatim in as-run findings. `L0`–`L7` are landmarks; `L8` and `L9` are *proposals*
in `docs/status/landmark-assignment-2026-08-19.md`, not landmarks until LANDMARKS.md carries them.

- **epic** — an arena directory (`docs/epics/<epic>/`) holding spec, decisions and sprints,
  whose goal emerges from completed sprints and which is never delegated as a unit
  (`docs/infra/sprint.md` "The ladder"; `docs/audits/2026-08-02-grand-audit/DIRECTION.md` §2:
  "an epic is a claim chain, not code").
  CONFLICTS: the legacy path `docs/epic-01-markovian/` predates the `docs/epics/` plural
  (S1 directory refactor, `docs/status/ROADMAP-2026-08-21.md`); only `docs/epics/` is live.
- **landmark** — a checkpoint the operator can verify without reading a task brief, ID L0–L7,
  every ID written with its short name (`L4 (the ledger is clean)`, never a bare `L4`)
  (`docs/epics/E1-markovian/LANDMARKS.md`; `AGENTS.md` "Landmarks").
  CONFLICTS: the old IDs `M<n>` (milestone) now belong to the **mutants** in
  `sprints/verify-battery/pass1/mutants.md` — that collision is exactly why M→L happened; sealed
  race packets and as-run records still say "milestone M<n>" by design (read as `L<n>`).
- **sprint** — a coherent collection of work with a defined goal, reached through one or more
  passes, with spec/plan/accept bookends (`docs/infra/sprint.md`; the ladder there is
  task → sprint → epic).
  CONFLICTS: none.
- **pass** — one iteration within a sprint (pass0 = MVP, pass1 = deferred scope); the `N` in
  `passN/` (`docs/infra/sprint.md`).
  CONFLICTS: in the engine, "pass" is a Go move that yields the turn (state bit `passes`,
  `double-pass terminal` in `docs/epistemic/GLOSSARY.md`) — same word, different domain; the
  process sense is always "pass <number>", the engine sense is a bare "pass".
- **phase** — one document within a pass: spec, research, scope/ACs, design, plan, build,
  verify, accept, integrate, plus audit loops (`docs/infra/sprint.md` passN/ file list;
  `docs/status/ROADMAP-2026-08-21.md` pass protocol).
  CONFLICTS: none in the process vocabulary — the program ladder that used to share this word is
  **waypoint** (see "The three ladders" below); in the engine, "phase" is not a reserved term.

## The three ladders — waypoint, stage, phase

Three ladders run here, one word each: **waypoints** order the program's work, **stages** narrate
the operator's course, **phases** are the documents inside a pass. No two share a word, and none
of the three numbers another.

| ladder | word | numbering | defining doc |
|---|---|---|---|
| program ladder | **waypoint** 0–4 | 0 theorem and axioms · 1 acceptance battery before code · 2 kernel extraction · 3 A–Z reverification · 4 the swap | `docs/audits/2026-08-02-grand-audit/DIRECTION.md` §5 |
| operator course | **stage** 0–4 | 0 handover · 1 L1-into-tooling · 2 the races · 3 the L2 foundation · 4 the clean story | `docs/status/ROADMAP-2026-08-20.md` |
| pass-internal document | **phase** | spec, research, scope/ACs, design, plan, build, verify, accept, integrate + audit loops | `docs/infra/sprint.md` |

- **waypoint** — one of the five dependency-ordered steps of the grand-audit program, W0–W4;
  waypoint order is dependency order, not calendar order, and no waypoint gates the dispatch of
  another (`docs/audits/2026-08-02-grand-audit/DIRECTION.md` §5 + Amendment 2; task mapping in
  `docs/epics/E1-markovian/WAYPOINTS.md`).
- **stage** — one arc of the operator's course, Stage 0–4, describing who is doing what and when,
  and freely subdivided in place ("race Stage 2a", "Stage 3.1/3.2/3.4")
  (`docs/status/ROADMAP-2026-08-20.md` §§Stage 0–4; one-page map `docs/status/ROADMAP-2026-08-21.md`).
- **landmark** — a checkpoint the operator can verify without reading a task brief; defined in full
  at its own entry above and in its home file (`docs/epics/E1-markovian/LANDMARKS.md`).
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
so never derive one ladder's position from the other's, and never write "Stage N = Waypoint M".
The same table, kept with the task mapping, is in `docs/epics/E1-markovian/WAYPOINTS.md`.

### Usage

| write this | not this |
|---|---|
| Waypoint 3 gates promotion on mutation adequacy | Phase 3 gates promotion on mutation adequacy |
| W1's battery is calibrated on synthetic defects | Stage 1's battery is calibrated on synthetic defects |
| Stage 3 resumes the critical path | Waypoint 3 resumes the critical path |
| the build phase of pass0 landed red→green | the build waypoint of pass0 landed red→green |
| step 4 of the accept phase | task 4 of the accept phase |
| `L4 (the ledger is clean)` | a bare `L4`, or `L2` meaning "a science row" |

Documents sealed before 2026-08-23 number the program ladder `Phase 0–4`; read those as waypoints
(rename ratified 2026-08-23, `findings/T745-terminology.json` R1). This is the only note in this
file that carries the old word.

## Queue, surface, and roles

- **model short names** — human surfaces (tables, prose, dashboards) use short names
  (`opus`, `dspro`, `dsflash`, `oxalpha`, …); stores and ledgers keep canonical labels
  (operator ruling 2026-08-23). The one short-name table lives in
  `docs/infra/model-registry.md` — no second mapping anywhere.
- **kanban** — the `bin/managent` task queue: tasks, sets, holds, needs, claims, columns; never
  "board" in prose (`AGENTS.md` terminology ruling 2026-07-29, extended to *goban* 2026-07-31;
  spec: `docs/infra/managent/spec.md`).
  CONFLICTS: none live — the ruling retired "board" from both senses; GTP `boardsize`, code
  identifiers, `boards/` path segments and quoted titles are exempt.
- **goban** — the Go playing surface (2×2, 3×2, 4×4); goban size, goban state; never "board" in
  prose (same ruling as kanban).
  CONFLICTS: "board" survives only where it is not prose (GTP command, code identifiers, quoted
  third-party titles, English idioms).
- **landmark IDs L0–L4** — L0 (the table and the instruments exist) · L1 (the dashboard tells
  the truth) · L2 (proven 4×4 values) · L3 (the new engine outplays the old one) · L4 (the
  ledger is clean); the map continues L5 (one rulebook) · L6 (small Go solved, certifiably) ·
  L7 (the 5×5 decision, costed) (`docs/epics/E1-markovian/LANDMARKS.md`).
  CONFLICTS: see "landmark" (the M<n>→L<n> collision with the mutant IDs) and the `L<n>`
  reservation rule under "The work hierarchy".
- **duty** — work that is always beneficial, never critical, and cannot exhaustively finish;
  identified by a stable UID (DCLAIM, DRPLAY, DARGUS, DFLEET), runs one chunk per invocation,
  always yields to a task, and a landmark may not be declared reached while any duty is overdue
  (`docs/infra/duties.md`).
  CONFLICTS: "duty" in the plain sense of a seat's recurring responsibilities ("duties current
  by the gate", `docs/status/ROADMAP-2026-08-20.md`) and the kanban's `duty`/`why` fields are
  NOT the reserved sense — the reserved sense is the D-UID duty row.
- **standing row** — a kanban row auto-registered by a `managent standing` trigger
  (STANDING-ABSORB, STANDING-CLEANUP, STANDING-REEVIDENCE, STANDING-CONSOLIDATE,
  STANDING-HOLISTIC-AUDIT); a done/failed standing row re-registers rather than staying inert
  (`docs/infra/managent/spec.md` §"managent standing"; `docs/infra/orcha-doctor-2026-08-08.md`).
  CONFLICTS: four "standing" senses — standing row (this), standing-tier (dispatchable tasks
  with no in-flight work, `docs/infra/delegation/ROLES.md`), standing assignment (a model bound
  to a role, ROLES.md), and the idiomatic "standing rule" (`AGENTS.md`); context
  disambiguates, and only the kanban sense names a row.
- **lane** — a race participant: one model running one byte-identical brief in a race (grand
  race: 7 lanes; science arm: 5 science lanes), lane output committed before any grading
  (`docs/epics/E1-markovian/L1-dashboard/S02-model-delegation/grand-race.md` §2;
  `race-g-claim-doubt/race-g-science-arm-brief.md`).
  CONFLICTS: claimlint uses "lane" for a sibling task's working-tree partition
  (`src/claimlint.zig:4088`), and the course distinguishes "fleet rows and not race lanes"
  (`docs/status/ROADMAP-2026-08-20.md`).
- **seat** — a thinking-manager role (Orchestrator, Auditor, Dabir), persistent and invoked by
  role, not by model; "seat-authored" = produced from the role's own console
  (`docs/infra/delegation/ROLES.md`; the court, DIRECTION §6).
  CONFLICTS: "seat" is also used loosely for the operator's console ("the new seat's first arc"
  = the incoming Orchestrator, `ROADMAP-2026-08-20.md`), and "court" (DIRECTION §6) is the
  collective name for the seats.
- **console** — a running agent session/instance of a model; a fresh console has no cross-session
  memory, and a worker console of a model is not the same agent as that model's
  Orchestrator/Auditor instance (`docs/infra/delegation/ROLES.md` §"Instance vs model";
  `docs/infra/agent-identity-and-worker-channel.md`).
  CONFLICTS: "console" also means the operator's human terminal (the copy/paste boundary rules
  in `AGENTS.md`); context distinguishes them ("a fresh console" = agent session, "at console"
  = the human).
- **court** — the collective name for the thinking-manager seats: Orchestrator, Auditor, sprint
  worker managers + phase workers, and Dabir (optional but defined)
  (`docs/audits/2026-08-02-grand-audit/DIRECTION.md` §6).
  CONFLICTS: a metaphor, not an ID; the msgbus addresses court messages by role
  (`docs/infra/managent/SPEC-msgbus.md`).

## Race vocabulary

- **race arm (bare / instructed)** — one treatment condition of a race over the same sealed
  target set: the bare arm runs the unadorned brief (measures disposition), the instructed arm
  prepends the ratified "do science" preamble (measures the ceiling); production lanes are
  instructed, so the instructed arm is the deployed condition
  (`docs/epics/E1-markovian/L1-dashboard/S02-model-delegation/race-g-claim-doubt/race-g-science-arm-brief.md`).
  CONFLICTS: "arm" also names the four grand-audit audit arms (arm-code-tests,
  arm-epistemology-claims, arm-infra-tooling, arm-orchestration-process) and the science lane's
  "adversarial arm" (T727/T729 batches) — "arm" is a branch of an experiment/audit, never an ID.
- **two-field verdict** — the binding verdict format for the race-G science lanes: fields
  `headline_status_correct` and `rationale_fresh`, each `correct` / `incorrect` /
  `unverifiable-at-head`, dual-keyed (G<nn> label and backtick-quoted register claim id)
  (`docs/epics/E1-markovian/L1-dashboard/S02-model-delegation/race-g-claim-doubt/science-arm-sprint/spec.md`
  §3.1).
  CONFLICTS: the science-arm preamble's own step-6 vocabulary (VERIFIED / REFUTED /
  UNVERIFIABLE-AT-HEAD) is subordinate to the two-field format — that contradiction broke the
  T720/T721 pilots, and the binding-constraint ruling settled it in favour of the two-field
  format.
