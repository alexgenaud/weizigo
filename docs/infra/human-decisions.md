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
- **2026-08-18 — DeepSeek default seat.** The TEMP rule making `deepseek-v4-flash` the default
  for all dispatches lapsed 2026-08-12. Operator's standing question: **where does
  `deepseek-v4-pro` shine enough to earn its cost**, and how do both compare to Opus and Fable.
  Forced binary choice today is **Flash** (much cheaper). Awaiting a ruling on evidence from
  the new-epoch races; do not aggregate across the 2026-08-18 DeepSeek epoch boundary.
- **2026-08-18 — T443 storage-durability policy P1–P6** (`untracked/T443-policy-draft.md`):
  operator ratifies. Includes the **branch-archival idea** — commit epic/sprint binary data to a
  git branch, delete the binary before squash/merge. Caution to weigh in the ruling: a committed
  binary enters the object store and branch deletion alone does not reclaim it (needs unreachable
  + gc, and it bloats clones meanwhile); an **orphan branch never merged**, or P3's manifest +
  off-disk archive, likely dominates. Do not default into it.

## Recently ruled (keep short; drop items older than the current milestone)

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
