# RESUME — 2026-08-25 midday. Written for a fresh seat, and for the seat's retirement.

Outgoing: `claude-opus-5`/T914, 2026-08-25 ~02:00–11:00Z. **21 commits.** Supersedes
`RESUME-orcha-2026-08-25-dawn.md` for seat state; that file's traps still bind.

**Read the operator's direction first — it changes the job.**

## 0. The direction (operator, 2026-08-25, verbatim intent)

> *"I want to get the tooling stable, reliable, simplified, and eliminate the orchestrator role."*
> *"It's reasonable to work with an agent to carry a stream forward, but you should not be
> orchestrating unrelated tasks, nor other streams run by other agents and consoles. A task may
> require independency, but that should be managed via the queue and blocking mechanisms, mostly or
> fully automated with managent and a periodic loop."*
> *"I would like the backlog of well-specified, obviously beneficial tasks to methodically execute.
> Not in haste, perhaps serially, but automatically pop off the stack and run. I would then prefer
> to discuss with agents those tasks that are not well-specified or risky."*

And on how to work: **decide, tell him, act.** He reserves veto. Asking for permission on a
decision you have already reasoned through is the thing he corrected.

**Consequence: do not orchestrate. Carry a stream. Let the queue do the sequencing.**

## 1. What is measured about 4×4 — the headline

Three rows in sequence turned "4×4 is out of reach" into "4×4 is an overnight job", and each
corrected the one before it.

| row | result |
|---|---|
| **T924** (ox-alpha) | ladder 2×2→4×4 writes-off. Clean through 4×3 (20,878/20,878, zero skips). 4×4: **125 of 1,287 sampled roots unsolved** at a 20 M-node cap. Projected **202.5–1,620 h** single-threaded. |
| **T929** (dsflash) | that mean was **unweighted** and distorted by per-layer sampling caps. Population-weighted: **282,104.8 nodes/root, 7.585× lower**, projecting **26.8–214.7 h**. And the shape: **the 125 capped roots are 9.71% of samples but 92.6% of measured nodes** — a pathological tail on a cheap bulk. |
| **T930** (dspro) | `finishParallel` scales **5.1× at 18 cores** with contiguous chunks, **11.5× at 16** round-robin. Cause named: the work list is deepest-first, so cheap roots pile into low thread ids. 4×4 becomes **~1–6 days realistic**. |

**T932 is running now** — implement the round-robin partition in `src/retro.zig`. That is the
change that makes 4×4 reachable. It must preserve byte-identical node counts (T930 proved that
property held across its sweep; it is why the result is trustworthy).

`4x4.D3` is answered: **not tractable single-threaded, plausibly tractable parallel.** `docs/research/`
carries `4x4-d3-tractability.md`, `4x4-d3-weighted-projection.md`, `parallel-finisher-cost.md`.
Raw evidence at `docs/evidence/T924/per-root.csv` (1,354 rows) and `docs/evidence/T929/`.

## 2. The stack is classified. Use it.

`docs/infra/dispatch-queue.tsv` — every dispatchable row with a rank, an estimated wall, and a
**lane**:

- **AUTO (21 rows, 29.8 h serial)** — well-specified, reversible, no ruling needed, no host
  exclusivity. `tools/pop-next.sh` pops exactly one, in rank order. `MAX_LANES` defaults to **1**.
- **DISCUSS (18 rows)** — each with its reason: needs an operator ruling, is a race needing blind
  adjudication, is under-specified, or edits a live dispatch path where a wrong change stops the
  fleet (T712, T709). **Never popped. Discuss these; a loop cannot have a conversation.**

`tools/pop-next.sh` does not supervise, close or judge — `bin/dispatch` already enforces caps,
admission, holds and depth. It refuses rather than guesses, and it excludes rows with a live runner
whatever the store says (a dispatched row reads `dispatchable` until its worker claims itself; that
window is the T350/T376/T389 duplicate class).

`untracked/pop-next.stop` is the brake.

## 3. The keeper: why it is still paused, and what unblocks it

`tools/fleet-keeper.sh` is complete — queue read, dispatch, caps, single-instance lease, arg guard,
depth guard — and stopped by `untracked/fleet-keeper.cooldown` (set 2026-08-24 10:22).

**Do not unpause it yet.** Two reasons, both fixable: it orders by whatever `managent status --json`
returns, so it does not know the rank file; and its cap is global with no per-family scope, which is
why it was paused. **T894 (running, sonnet)** puts rank + estimate into `managent`. When T894 lands,
unpause.

## 4. Absorption: the mechanism exists and is switched off

Two close gates:

- **`deliverables=`** — the files must exist. **Live, and it works**: it declined T924's auto-close.
- **`acceptance=`** — an executable command `managent done` runs (`main.zig:5544`, T217); a failing
  command refuses the close. **Zero of 36 dispatchable rows carry one.** 183 of 835 briefs on disk
  do, so the convention drifted.

**This is the answer to "how do we absorb results without an orchestrator."** A row that writes
nothing is caught today. A row that writes wrong numbers closes clean — T924 did exactly that, and
only a hand-dispatched second reading (T929) found the 7.6× error. `acceptance=` makes that check
automatic, and for most rows it is the regression script the row already owes.

**Trap:** `acceptance` is written **only** in `cmdAdd`. Editing a brief after registration is inert
and nothing reports the disagreement. Five briefs (T915, T922, T923, T926, T927) now carry it and
are inert until **T931** lands the general sync. T880's `holds --sync` is the precedent; generalise,
do not add another per-field verb.

## 5. ox-alpha: the diagnosis was wrong for weeks

**B4 said "does not reliably echo the dispatch nonce — protocol compliance unreliable". That was
wrong.** The operator produced the cause from his console: **HTTP 429,
`limit_source: upstream_provider_shared_pool`**. The lane log holds **40 occurrences of 429** —
twenty retries, all refused — and `tools/runner` recorded **exit 0**.

The lanes were never non-compliant. **They were never served.** Our dispatch rate was 18 claims in
nine hours, so the pressure is other users of a shared pool.

**ox-alpha is off the dispatch list** until telemetry can tell provider death from model behaviour.
Its *capability* reading stands — 37/40, best in the C3 field, and T924's ladder was first-rate
science. This is a lane-reliability finding.

**T934** registered: a provider refusing service must not exit 0. Three cases are currently one —
ran and finished, ran and was killed, **never served**.

## 6. Instruments that lied this shift — mine included

The recurring failure is a **generic symptom hiding a specific cause**, now at four instances: a
nonexistent model as "did not echo the nonce"; a closed-but-running lane as UNKNOWN tokens/s; a
memory kill as bare rc=124; a 429 as success.

**And three of my own instruments were the unreliable part:**

- `goban-scaling-capture.sh` shipped with **no control run** while a live lane already depended on
  it. It under-reports RSS (samples one process, not the tree) and appends only on completion, so a
  killed run — the expensive case — writes nothing. **T926.**
- A drain monitor grepped `--arbiter-id` out of `ps` with no check against the store, so **test
  fixtures read as live lanes** (T8620, T8622). Rebuilt to require ledger *and* process agreement.
- A "solver" watch matched `/usr/libexec/smd`, a macOS daemon.

The project's own rule covers all three: no mechanical reading enters from a pattern match without
a known-good and known-bad control. I was not applying it to my own monitoring.

## 7. Also landed this shift

- **The repository-wide commit freeze is lifted** (`b3a841c`). The S09 contract declared a test
  script T872 had deleted, so every commit staging `tools/runner` selected a missing file and was
  refused. **T915** owes the real coverage.
- **`watch-fleet.sh`**: PROGRESS gains **PID**; OPEN is a **queue with 3-char ETAs** simulated from
  rank + holds + lanes; DONE gains **model, elapsed, whole-run average rate**.
- **The token ledger join is broken** — records `tokens_out: null, "no session matched"` while the
  session file holds 100,258 tokens. Very likely why `cost` is null in **52 of 52** perf rows and
  **no tier has ever been emitted**. **T933.** DONE reads the session directly as a deliberate,
  shallow workaround to be deleted when the ledger is right.
- **`build.zig` is an undeclared shared writer** (T922); **the commit gate reads the worktree, not
  the index** (T923) — my own commit `b3a841c` recorded `C3=17` from another lane's uncommitted
  files.
- **Nothing calls `caffeinate`** (T927, running). 2026-08-24 slept **24 times**; any wall from that
  day is suspect. 2026-08-25 slept zero, so this shift's numbers are clean by luck.
- **`docs/infra/host/goban-scaling.md`** — WZO1 is exactly `6 × 3^(w·h) + 32` bytes, verified
  byte-for-byte against all four artifacts. **5×4 = 19.5 GB, 5×5 = 4.62 TB.** WZO1 has no mmap
  path, so 5×4 is a **RAM wall** that post-hoc compression cannot move. WZO2 is already the sparse
  mmapped design. **T925** rules on which 5×N uses.

## 8. Owed to the operator

OPEN.md **A2, A3, A4** remain undecided. **T925** wants a format ruling. **T931** asks whether
`unspec` should refuse dispatch — my recommendation is written there: not until the backfill is
done, then yes.

## 9. Before believing any status

`bin/managent reap`, then check the process table for a live `--arbiter-id` runner before trusting
an orphan verdict. Then: repo points at itself, `core.worktree` unset, HEAD file count >2,700,
`.gitignore` 46 lines, last author `alex@genaud.net`. Re-verify after every commit.

**A hard kill leaves a stale arbiter admission that refuses the next run.** Release it:
`tools/runner --arbiter-release --arbiter-id T<nnn>`.

## 10. In flight at handover

| row | model | what |
|---|---|---|
| T932 | dspro | round-robin partition — the 4×4 unlock |
| T927 | glm | sleep guard |
| T894 | sonnet | queue head + estimates — unblocks the keeper |

Store: 509 done, 42 dispatchable, 6 in progress, 3 blocked.
