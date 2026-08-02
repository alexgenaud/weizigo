# Dispatch — running experiments from independent consoles

**Created 2026-07-28.** One file per experiment in this directory. A fresh
console should be able to pick one up cold, with no other context than the read
order below.

---

## Read order for any console (do this first, every time)

1. `AGENTS.md` (repo root) — behaviour rules and foreclosures. Non-negotiable.
2. `docs/infra/delegation/DELEGATEE.md` — your worker role: **claim the task on
   start (`managent claim <id> --agent <name>`), mark `done` on finish
   (`managent done <id>`, or `--fail`)**, build through `tools/runner`. The
   word "claim" in your brief means the *epistemic* claim ID (`CLAIMS.md`),
   not this goban action — do both.
3. `docs/epistemic/roadmap-2026-07-28.md` — which Go we are solving and why.
4. `docs/epistemic/critique-2026-07-28.md` — what is known-wrong. §4 especially.
5. `docs/epistemic/CLAIMS.md` — the claim graph. Find the IDs your task closes.
6. Your brief: `docs/infra/dispatch/EXP-N.md`.

Do not start work before step 6. Several of these experiments have already been
run in a different form and **failed**; the briefs say which, and re-running a
foreclosed variant is the most common way to waste a console.

---

## The dependency graph — what can run in parallel right now

```
EXP-1  PSK binding rate ................ DONE 2026-07-28
   |
EXP-2  Prove or kill QA-023 ............ THE GATE — run first, alone if need be
   |          (a proof, plus an exhaustive 2x2 check)
   |
   +---------------------------+
   |                           |
EXP-3  state census            |        <-- INDEPENDENT of EXP-2, run in parallel
   (counting, not semantics)   |
   |                           |
   +---------------------------+
                   |
        EXP-4  2x2 + 2x3 under the new rule    <-- the falsification gate: must return 0, not +1
                   |
        EXP-5  3x3 (expect +9)
                   |
        EXP-6  4x4 (expect +2, and a FILLED root)
                   |
        +----------+----------+
        |                     |
   EXP-7 certified fraction   EXP-8 PSK divergence (S2)
   (predicts 100%)            (harness can be built earlier)
```

**Runnable in parallel today:** EXP-2, EXP-3, and the cleanup waves.
**Everything from EXP-4 down is gated on EXP-2 passing.** If EXP-2 fails, stop
and escalate — Phases 1-3 fail with it, and the project needs a new strategy,
not a workaround.

---

## Concurrency rules for multiple consoles

These are AGENTS.md rules made operational. Violating them corrupts work
silently, which is worse than failing loudly.

**File ownership.** Every console declares its owned files via the kanban
`holds=` field before editing (`managent show <id>`; `bin/managent resume`
lists every held path), and clears the hold when done. Two consoles must never hold the same
file.

**Never two consoles on an engine file.** `src/retro.zig`, `src/oracle.zig`,
`src/rules.zig`, `src/solve.zig` — one writer, ever. Most of these experiments
should need *none* of them; prefer a new file.

**`docs/epistemic/CLAIMS.md` has exactly one owner.** Everyone else records
findings in their own document and the owner folds them in. It is the spine; a
merge conflict there is expensive.

**Build isolation.** Distinct binary names per console (`weizigo-<exp>-<id>`),
and set `ZIG_LOCAL_CACHE_DIR` / `ZIG_GLOBAL_CACHE_DIR` under
`/tmp/weizigo-zigcache`. Root build outputs are gitignored.

**No silent artifact writes.** Never overwrite anything in `data/` or
`artifacts/`. New rule, new file, new name — e.g.
`data/oracle-4x4-basicko-area.wzo`. Tag artifacts by `(size, ruleset)`; the
project has already decided to keep every table (`ruleset-options.md`).

**Long runs need a persistent session.** Retrograde builds are minutes to hours
and produce 258 MB artifacts. Start it, watch the heartbeat, do not restart.

---

## Definition of done — every experiment, no exceptions

**Kanban lifecycle (operational, do this too):** `managent done <id>` (or
`--fail`) is run on completion — see `DELEGATEE.md`. Work not marked done is
work the project cannot see, and it blocks every task that `needs` it. (The
list below is the *epistemic* definition of done; the kanban command is the
*operational* one. Both are required.)

1. **The claim ID it closes** is named, and `CLAIMS.md` is updated (by its
   owner) with the new status.
2. **Evidence is committed** under `docs/evidence/<claim-id>/` — probe source
   *and* output. Per `roadmap-2026-07-28.md` §4 P1: a claim may be marked PROVEN
   only if its evidence is in git. `untracked/` is for drafts nobody will cite;
   the project has already destroyed the evidence for T13, T02/B1, T07 and B05
   by writing it there (`docs/evidence/README.md`).
3. **The acceptance criterion is met, or an honest negative is recorded.** A
   negative result is a deliverable. Most of what this project actually knows
   came from falsifications.
4. **Every checker ships with calibration** — a known-good case it passes and a
   known-bad case it catches. An auditor with no passing case cannot tell "bug"
   from "definition"; this has already cost the project once.
5. **Numbers cite their run** — command, flags, seed, goban size. And state the
   **denominator**: a mislabelled counter in `weizigo-chainability` seeded a
   three-way percentage confusion across four documents.
6. **No cross-goban extrapolation.** Per-goban epistemic independence. If you
   want to claim it transfers, supply a monotonicity argument.

---

## Escalation

- **EXP-2 fails** → stop everything downstream. Escalate to the user and the Auditor.
- **A foreclosure looks wrong** → write an ADR that supersedes it with evidence.
  Do not just act against it.
- **A number disagrees with a committed document** → stop and report the
  disagreement. Do not write the new number over the old one. `CLAIMS.md` §6
  already tracks 17 such discrepancies; adding an 18th silently is worse than
  leaving it.
