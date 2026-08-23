# GLOSSARY — reserved terms (infra & process)

**Status: living reference. [Current.]** Created by deepseek-v4-flash/T737, 2026-08-23, per the
operator ruling of 2026-08-23 (reserved terms live in a canonical glossary; one term per entry,
one sentence each, a citation to the defining doc, a CONFLICTS note where a collision exists
today). Companion to the epistemic vocabulary in `docs/epistemic/GLOSSARY.md` — this file is
about *process/workflow* terms; that one is about *engine/Go* terms. Where a term appears in both
(e.g. "pass", "phase"), this file owns the process sense and flags the other.

## The work hierarchy: epic > landmark > sprint > pass > phase

The canonical path is `docs/epics/<epic>/<landmark>/S<n>-<slug>/pass<n>/<phase>.md` — a sprint
lives under its PRIMARY landmark (`docs/status/refactor-migration-map.md:9-10`).

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
  CONFLICTS: **the Phase collision** — see "DIRECTION Phase 0–4" and "Course Stage 0–4" below.

## The three ladders — the collision triangle

Three numbered step-ladders use overlapping words for their rungs. All three are live; the
collisions are real and currently resolved only by context.

| ladder | word | numbering | defining doc |
|---|---|---|---|
| pass-internal document | **phase** | spec, research, scope/ACs, design, plan, build, verify, accept, integrate + audit loops | `docs/infra/sprint.md` |
| program ladder | **Phase** 0–4 | 0 axioms · 1 battery · 2 kernel · 3 A–Z reverification · 4 swap | `docs/audits/2026-08-02-grand-audit/DIRECTION.md` §5 |
| operator course | **Stage** 0–4 | 0 handover · 1 L1-into-tooling · 2 races · 3 L2 foundation · 4 clean story | `docs/status/ROADMAP-2026-08-20.md` |

- **DIRECTION Phase 0–4** — the ratified program ladder of the grand audit: Phase 0 theorem and
  axioms, 1 acceptance battery before code, 2 kernel extraction, 3 A–Z reverification, 4 the
  swap; phase order is dependency order, not calendar order (Amendment 2, ruled 2026-08-03)
  (`docs/audits/2026-08-02-grand-audit/DIRECTION.md` §5 + Amendments; task mapping in
  `docs/epics/E1-markovian/WAYPOINTS.md`).
  CONFLICTS: collides with pass-phase "phase" above. **T737 rename proposal (NOT executed —
  follow-up row for the operator to ratify): "Program step 0–4".** The brief's other example,
  "Rung 0–4", is NOT recommended: "rung" is already taken by the goban-size verification ladder
  (Rung 1 = 2×2 … Rung 5 = 4×4, `docs/epics/E1-markovian/sprints/g3b-value-correctness/pass0/spec.md` §7)
  and the knowledge-ladder rungs (K0 certified … K5 guess,
  `docs/audits/2026-07-30-epistemic-tree-shake-fable.md`). "Program step" has zero existing
  usage in docs/ or untracked/ — it is the clean candidate. Census (T737): 14 tracked files use
  the DIRECTION sense; 59 tracked files contain "Phase N" (377 lines, senses mixed); 48
  untracked briefs contain "Phase N" (131 lines). Full file lists in
  `findings/T737-glossary.json`.
- **Course Stage 0–4** — the operator-facing course ladder: Stage 0 Flash wraps up and hands
  over, 1 L1: the orchestration job moves into tooling, 2 the races (inside the L1 arc), 3 the
  L2 foundation, 4 the clean story (`docs/status/ROADMAP-2026-08-20.md` §§Stage 0–4; one-page
  map: `docs/status/ROADMAP-2026-08-21.md`; handover: `docs/status/handover-orcha-incoming-2026-08-20.md`).
  CONFLICTS: third ladder — completes the collision triangle with DIRECTION Phase and pass-phase
  "phase". "Stage" is also reused *inside* the course for sub-steps ("race Stage 2a",
  "Stage 3.1/3.2/3.4") and a stale reference to "Phase C" of the course exists in
  `grand-race.md` §1 that no heading in `ROADMAP-2026-08-20.md` satisfies. 4 tracked files use
  "Stage N" (24 lines).

## Queue, surface, and roles

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
  CONFLICTS: see "landmark" (the M<n>→L<n> collision with the mutant IDs).
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
