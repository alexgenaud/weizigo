# Decisions that cannot be delegated

*(Tracked doctrine. The repo-root `HUMAN.md` is the operator's private scratch file and is gitignored — nothing canonical belongs there.)*

Everything not listed here is delegable. Agents act; they do not ask.

Each item states **why** an agent cannot decide it. If an agent can decide it, it does not
belong on this page.

## 1. Spend and seating

Which models run, how many consoles at once, and when to seat or retire one. An agent cannot
see the bill. Recorded in `docs/infra/model-perf.md`; current standing rule: plan
`claude-fable-5` against 200 k because crossing it costs money, and use it sparingly.

## 2. Which game we are solving

Ruleset choices are definitional, not technical: area scoring, komi 0, basic ko versus SIMPLE
ko, and how cycles resolve. These decide what "perfect play" *means*, so no amount of
verification can settle them. The cost of getting this wrong is on record: an agent compared
our 4×4 result against MIGOS's +2, called it an acceptance failure, and was measuring a
different game (T274) — the +2 comes from a different cycle-resolution rule.

## 3. Truth standards

What earns `PROVEN` rather than `CLAIMED`, and the threshold at which each claimlint check
starts failing rather than reporting. Promotion is currently gated on mutation adequacy
(DIRECTION Amendment 2 edge 5) by human ruling. **Floors move only downward, and only by the
Orchestrator on evidence of a committed fix** (`docs/infra/roles/ARGUS.md`) — an agent may
propose a floor, never raise one.

## 4. Destruction

Pruning archaeology destroys information permanently. Ratify the epitaph policy once — one line
per dead end, stating what was tried and what it cost — and agents apply it thereafter without
asking. Retirement of register rows follows the same shape: agents propose on a sheet, the
Orchestrator rules (T324's pattern).

## 5. Scope and stopping

How far past 4×4 to go, and what makes epic-01 finished. An agent will always find more to
verify; only the operator decides that a milestone is complete.

## 6. External publication

Any claim that leaves this repository. The register's internal standards are not a publication
standard, and 76 of 100 `PROVEN` rows currently lack committed evidence.

## 7. Seat allocation

Who holds the Orchestrator seat, and which roles exist. Recorded in the STATE anchor's §Seats.

---

## Open, awaiting a ruling

- **2026-08-04 — check names.** Names proposed to sit **alongside** the IDs, not replace them:
  `ORPHANED` (C1a), `STALE-NEGATION` (C1b), `DEAD-LINKS` (C2), **`UNBACKED`** (C3),
  `GHOST-IDS` (C4), `SHADOWED` (C5), `MISCITED` (C6), `UNABSORBED` (C7), `UNKILLED` (C8),
  `UNMAPPED` (C9). Registered as T356; ratify or rename the words before it lands.

## Recently ruled (keep short; drop items older than the current milestone)

- **2026-08-22 — Ruling 32, census denominators.** A measured ladder, tier, or matrix cell is
  publishable only when its denominator is a census: every row's model attribution verified,
  `killed_by = none` for every scored row, guard-killed rows present and labeled *censored*
  (never dropped, never scored), and skip counts printed alongside every published number.
  Implementing rows: T629 (killed_by schema), T544 (attribution backfill). Priors documents
  (Class C, e.g. `model-ladders.md`) are unaffected — they were never publishable as evidence.
- **2026-08-22 — Ruling 33, randomization is mechanized, never improvised.** When more than one
  qualified model would do for a row, the assignment is drawn by a `bin/managent` function from
  the candidate list, and the row records `candidates`, `method` (random | forced | preferred),
  and the draw. Neither human nor model generates randomness. Analysis treats only
  `method=random` rows as unconfounded; everything else is observational.
- **2026-08-22 — Ruling 34, solo rows ladder, panel rows compose.** Every row has a shape.
  **Solo** (implementation, bookkeeping, infra, single-lane anything): cheapest qualified model
  wins — the cost-ladder rule, applied after constraints (appetite, blocked families,
  harness-fits-scope) filter the qualified set. **Panel** (union-valued work: audits, races,
  adjudication): anchor first, then greedy marginal complementarity — the model adding the most
  expected unique catches per token given the seats already filled — until appetite or
  diminishing returns stops it. Races must reduce who-found-what into the complementarity
  record; a race that keeps only its ranking discards the panel data this ruling runs on.
- **2026-08-22 — Ruling 35, thoroughness and economy are separate facts.** Thoroughness =
  coverage of a pre-enumerated target set (denominator from the T627 scope field). Economy =
  verified findings per output token. Both stored as observed facts, never blended in the
  record; verbosity is priced as cost, and penalized as quality only where ruling already
  penalizes it — unverified load-bearing claims.
- **2026-08-22 — guards may stop, never attribute; no guard without controls.** Ratified after
  the 12:47Z Claude 5-hour-window outage, in which all three proxy-watching guards (directive
  gate, progress watchdog, startup-liveness fuse) produced false model-failure verdicts in one
  day. Two parts. **(a)** A harness guard may kill a lane, but attribution comes only from the
  runner's terminal record: verification records carry `killed_by` (guard id / provider / none),
  and the scoring pipeline refuses to score any row with `killed_by != none` — unscoreable **by
  construction**, retiring hand-written DO-NOT-SCORE annotations. **(b)** Every guard is an
  instrument: no guard ships without a null-control fixture and a seeded-defect fixture in the
  regression suite ("never trust a green test" applied to the harness). Implementation:
  T625 (classifier, landed 4aee950) + T628 (window resilience) + the schema change above;
  direction relayed to Opus/Orcha 2026-08-22. Operator observation, and it is
  empirical rather than stylistic: *he has never conflicted with a delegated worker; only
  Opus/Orcha has.* He does not conflict because he never touches the tree. The seat's output is
  a correct kanban, briefs, dispatches, absorbed findings and compiled results — **never a
  diff**. Verifying a worker's row means dispatching an independent check, not re-running it
  inline. Prohibitions and the failures that earned them are in
  `docs/infra/roles/ORCHESTRATOR.md` §"What the Orchestrator does NOT do".
- **2026-08-19 — staging procedure for every agent.** Keep your own list of files created or
  modified and stage them **by name**; never `git add -A`, `git add .`, or `git commit -a`. The
  rule already existed at `AGENTS.md:104` and did not bind, so it is now a procedure with the
  failure recorded, and `T455` builds the mechanism — an unlabelled commit currently bypasses
  the scope check entirely.
- **2026-08-18 — No binaries in git, and no worktrees to design for.** The branch-archival
  sketch is **rejected by the operator**: large artifacts do not go into a git branch even if the
  branch is later squashed or deleted. Diligent organization of `/tmp/weizigo` (scratch) and
  `untracked/` (host-local artifacts) is the working answer. The operator also rules that **this
  project has no need for worktrees**, so cross-branch and cross-worktree binary sharing is a
  problem we do not solve. *Standing caveat the ruling does not settle:* `/tmp` is where the
  9.4 GB `260707` archive was lost to tmp decay, and `untracked/` dies with the disk — durability
  still needs **one off-disk copy** (T443 P3), which is not a git question. Ratification of P1,
  P2, P4, P5, P6 as written still stands open.
- **2026-08-18 — No permanent default model; fill the matrix instead.** Repeatedly choosing the
  same model for the same task type, for lack of alternative experience, is an unsound habit and
  ends here. A model is selected for a task type only when evidence says it is the most
  appropriate for *that* type, and every model is to be tried across task types, head-to-head
  where the work allows. Cost stance **while Ollama credits are plentiful**: prefer Ollama models;
  otherwise `deepseek-v4-flash` over `deepseek-v4-pro` (cheaper, and on 2026-08-18's race also
  faster and better); `deepseek-v4-pro` is worth trying on **heavy, long-horizon, Opus/Fable-like**
  work, which is the one shape no race has yet measured. Coverage lives in
  `docs/infra/model-task-matrix.md`; an empty cell is a reason to dispatch, not a gap to hide.
- **2026-08-18** — **Ollama credits are plentiful:** use, test and compare `glm-5.2`,
  `minimax-m3`, `kimi-k2.7` liberally (K3 excluded on cost). A local `qwen3.x` trial is
  authorized for lightweight tasks — add the label to `canonical_models` first, and run no local
  inference during a measured suite run.
- **2026-08-18** — **Race, don't allocate by belief:** run the same safe, conflict-free task
  across five-to-eight models, in parallel or blindly comparable, and score it blind (bake-off
  protocol, `docs/infra/bakeoff.md`). Read-only audits are the ideal class; write rows need
  worktree isolation or sequential runs.
- **2026-08-04** — Fable: hand over before 90% of 200 k, use sparingly; the 200 k boundary is
  cost, not capacity, and the mechanism is undocumented and not to be restated as fact.
- **2026-08-04** — Orcha delegates sprints to consoles and does not manage their internals.
- **2026-08-04** — The 4×4 artifact is deployed at `data/oracle-4x4-v2.wzo2`; a ratified spec
  must not make `untracked/` load-bearing.
- **2026-08-04** — T328 (model bake-off) runs after the store-safety row landed.
- **2026-08-03** — If a third re-implementation language is ever adopted, it is Kotlin.
- **2026-08-04** — Archive, never delete. Rows leaving the live register move to `archives/`,
  preserved in full, with a one-line epitaph left behind. Priority target: nonsense and claims
  resting on falsified foundations (the `C1a ORPHANED` family). Because nothing is destroyed,
  agents may propose and move without per-item approval.
- **2026-08-04** — Claimlint check names ratified as proposed: `C1a ORPHANED`,
  `C1b STALE-NEGATION`, `C2 DEAD-LINKS`, `C3 UNBACKED`, `C4 GHOST-IDS`, `C5 SHADOWED`,
  `C6 MISCITED`, `C7 UNABSORBED`, `C8 UNKILLED`, `C9 UNMAPPED`.
- **2026-08-04** — IDs and canonical names are both kept; a name never replaces an ID. IDs are
  the stable reference in artifacts; names are how work is described to the operator, who does
  not keep an ID glossary in mind.
- **2026-08-03** — Credential stripping for subagents: rejected.
