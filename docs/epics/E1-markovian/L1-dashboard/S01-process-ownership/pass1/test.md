# Pass 1 — acceptance tests (`03-test.md`)

**Owner:** deepseek-v4-pro / T556 · **Date:** 2026-08-21 · **Status:** PROPOSED ·
**Inputs:** `01-spec.md` §5 (arms) + the phase-3 disposition (corrections cited per arm) ·
**Rule:** written **before** implementation; run red first, then the verb, then green.

## 0. The script

New file `tools/regression-process-ownership.sh` — **not** folded into the T364 kanban-orphan
script (different concern; the `reap` name collision is documented in `01-spec.md` §2, not
resolved by renaming). Conventions per the T364 script (`tools/regression-orphan-reaper.sh`):

- scratch tree under `/tmp/weizigo/own-regression/`; the live kanban, live `untracked/`, and
  the live repo are never touched (D-26).
- `$MANAGENT_BIN` resolution: `zig-out/bin/managent` → `bin/managent` (`:48` pattern).
- **skip-loudly** when the verb is absent (D-13: "skip-loudly when absent; fail red when the
  verb exists but is wrong"), except I1/I2 which fail red on the *current* runner behaviour.
- FAIL counter; exit 0/1. stdout = data, stderr = diagnostics; every arm checks the stream
  split (`2>/dev/null` emits data, `1>/dev/null` silent) at least once.
- Per-arm denominators (tree sizes, sleeps, settle-ms, iteration counts) are **fixed in the
  script**, never left to the runner.

## 1. Null arms

| arm | seed | asserts |
|---|---|---|
| N1 | a pid that never existed (`2^31−1`) | exit 0, `claimed=0 root=dead`, one parseable stdout line, `ps` unchanged |
| N2 | a second tree in its own session built by the same generator as S1, plus a **fabricated** run record for another in-progress row (D-26: not a live worker — the scratch rule) | after `--kill` on A's tree: every pid of tree B alive and unstopped (no `T` state), B's row untouched (OWN-3, scoped) |
| N3 | read-only invocation on a live tree | full report printed, **nothing signaled, nothing stopped afterwards** (D-20: freeze is `--kill`-gated, so read-only is truly inert) |
| N4 | two concurrent `--kill` runs on one tree | both exit 0, no double-kill report |
| N5 | unreadable `--ps-fixture` path (forces the ps read to fail) | exit 3 with a named reason; never a bare exit-0 empty-set report (D-40's degenerate-read arm) |

## 2. Seeded arms

| arm | seed | asserts |
|---|---|---|
| S1 | deep tree (≥4 levels, ~15 pids) built with **two** session boundaries — harness → tool shell (`setsid`) → runner → command (`setsid`, `tools/runner:1210`) → grandchild sleepers; root live; `--anchor` named (D-28) | every seeded pid dead by `ps` oracle; caller alive; zero collateral **scoped to target ∪ {R}** (D-8/D-29); verb counters agree with the oracle; OWN-5 |
| S2 | same two-session tree, SIGKILL the root/anchor, wait for reparent to ppid 1 (assert it — the measured leak shape), then `treekill --anchor <root>` | reparented members dead; no live pid with `sid == root` in the final scan; exit 0 (D-28 gives the `sid==anchor` members the arm needs) |
| S3 | nested-session orphan: tool-shell level setsids and dies with the runner child, leaving a grandchild session orphaned; verb called with and without `--seed` | without `--seed`: **verb exits 0 (claims nothing — the orphan is invisible) and the independent `ps` scan counts it alive** — this measures residue r3, the gap `--seed` closes (D-21: it does not measure r4); with `--seed` from a pre-death walk: zero survivors, exit 0 |
| S4 | a spawner forking a new sleeper every 0.5 s during the reap; ≥20 iterations | zero survivors every iteration; wall bounded; a single pass proves nothing about a race |
| S5 | `--anchor 1`, `--anchor $PPID`, a root-owned pid, an other-uid member (sudo; skip-loudly if unavailable) | exits 4 / `refused` counted via **pre-filter, not signal-and-observe** (D-34); nothing outside the target ever dies; bystander unstopped |
| S6 | churn-free tree; Zig closure vs the runner's `_descendant_pids_ps` (`tools/runner:609`) on the same snapshot | identical pid sets **on a tree built for equality**; OWN-1 is stated as a superset in general (D-27) |
| S7 | `--ps-fixture` with a member older than `--since`; fixture **carries a `sid` column** (D-37) | older member excluded (G4); `--kill --ps-fixture` exits 2 (G9); stream split; the sid edge is exercised in fixture mode |
| S8 | a **fabricated** run record for another in-progress row whose pid sits inside the closure | exit 4, zero signals, diagnostic names the task id, and every frozen pid is running again afterwards (G5/G6/G7 rollback; D-32 notes the no-record/expiry limits, recorded not solved here) |
| S9 | a live tree killed under the `kill-parity` mutation — odd pids survive the SIGKILL (marked killed, actually alive), even pids really die | exit 5 with `rounds` = the full `--rounds` budget (the retry path B-3 added, unexercised by S3/S4/M1 — Opus B-3 review, 2026-08-21); `killed=` honest across rounds (no pid downgraded to `vanished` — N4); the reported survivors are genuinely alive and the reported killed are genuinely dead by the independent `ps` oracle |

## 3. Integration arms (the three that fail red today)

| arm | seed | asserts |
|---|---|---|
| I1 | real `tools/runner` runs a command that backgrounds a sleeper and exits 0 | after the runner exits, the sleeper is dead — **fails today** (nothing after `tools/runner:1587` reaps); red first |
| I2 | real `tools/runner`, low `--rss-cap-mb`, a command that spawns a **session-escaping** tree (D-7: the escaping shape is required or I2 passes today by accident) | after exit 124, zero live descendants; red first; pins C1 as equivalent-or-better than today's `killpg` at `:1554` |
| I3 | real `tools/runner` runs a command that backgrounds a sleeper, then the runner **raises** (the `RUNNER_TEST_RAISE` injection hook — the same inject-don't-exhaust pattern as `WEIZIGO_HOST_MEM_AVAIL_MB`) forcing the exception path (C3) | after the exception propagates, the sleeper is dead — C3 reaps before the re-raise; red first |

## 4. Instrument-mutation controls (the arms that test the arms)

No instrument's first reading counts before a seeded-defect control. Each of the following
must make its arm fail; an arm that cannot be made to fail by deleting the code it covers is
decoration, not a control.

| mutate | arm that must fail |
|---|---|
| freeze disabled | S4 |
| start-time filter disabled | S7 |
| protected-set check disabled | S8 |
| rollback (SIGCONT-on-refusal) disabled | S8's running-again clause |

Acceptance also includes **one hand-traced end-to-end audit** of a single reap, pid from
spawn to death (the standing rule: an auditor must trace one complete evaluation end-to-end).

## 5. Red-first, spelled out (so "red" is not a slogan)

1. Write `tools/regression-process-ownership.sh` now, against the **corrected** spec.
2. Run it with the verb absent: **I1 fails red** (the normal-exit leak is real), **I2 fails
   red** (the ceiling path escapes), **N1/N3/N4 and S5/S7/S8 skip-loudly or pass their
   null/guard halves**, the seeded arms that call `treekill` skip-loudly with a named reason.
3. Build the verb (phase 7), re-run: the skipped arms now run and must go green, I1/I2 go
   green once C1/C2/C3 are wired.
4. Green is claimed only when every arm passes **and** its independent `ps` oracle agrees —
   never on the verb's own counters (standing rule: impossibly clean counters are red flags).

## 6. Open items the test doc does not resolve (carried to design)

- D-22/D-23: the exact `--since` value shape (epoch, pre-spawn) the runner records — the
  test doc only asserts the guard's *behaviour* (older-than-floor excluded, post-death reuse
  honestly a residue), not the storage format.
- D-39: whether `--rounds` is a shared budget across the fixpoint and verify loops — S4's
  "wall bounded" assertion depends on it; the test fixes a wall, the design fixes the budget.
- D-40: the internal-failure exit code number — the tests assert "loud failure on a degenerate
  `ps` read", the design picks the code.
