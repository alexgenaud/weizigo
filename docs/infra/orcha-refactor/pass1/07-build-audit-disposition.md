# Pass 1 — phase-7 build audit disposition (opus/T556)

**Owner:** deepseek-v4-pro / T556 · **Date:** 2026-08-21 · **Auditor:** claude-opus-5
(independent re-implementation, the ladder's "different model" gate) · **Verdict:**
PASS-WITH-FINDINGS, safe to run on a live host.

Closure reproduced byte-for-byte against an independent Python oracle on three fixtures
(live deep tree, dead-root reparent, adversarial D-19); downward constraint proven
load-bearing; read-only inert; zero collateral. 11 findings, all ACCEPT (none reject/defer).

| ID | finding (severity) | disposition / fix location |
|---|---|---|
| B-1 | r4 escapee reported as a clean reap — `survivors=0 exit 0 reap_ok=True` while an unreachable `setsid` helper survives (critical) | **ACCEPT.** `_reap_tree` must record `unknown-partial` (never `clean`) when `last_poll_pids` is empty — the child exited before the first poll, so completeness is unattestable. Spec §2 caller-obligations already mandates this; the runner doesn't implement it. |
| B-2 | S3 exit-5 control inverted — script asserts `RC -eq 0` where spec/03-test require `exit 5`; suite grades a measured leak as PASS (critical) | **ACCEPT.** One-line: S3 without-`--seed` asserts exit 5. |
| B-3 | `--rounds` is not the shared budget — kill/verify run once after the fixpoint loop, so up to 4 rounds unspent (must) | **ACCEPT — CLOSED (D27, corrected D33).** Fixed by the DSPro diff from the B-3 race: validate→kill→verify moved inside the `--rounds` loop (`if (grew) continue` keeps converge-before-kill; N4 guard added to both kill paths; exit 5 only on `!converged` or `survivors>0`). Winner of 5 lanes; applied, `zig build` + regression green. **Scorecard corrected in D33** (fresh Opus review): the D27 "fabricated verification" charge was retracted (both Claude lanes DEFEND); dspro stands on cost/appetite + the extra N4 guard, not honesty. Acceptance gap closed by arm **S9** (`kill-parity` mutation forces a SIGKILL survivor; asserts budget spent + honest `killed=` + exit 5). |
| B-4 | N5 (ps-read failure ⇒ exit 3) and I3 (exception path) arms missing from 03-test.md — lost at phase 3 (must) | **ACCEPT — CLOSED (D28).** N5 + I3 added to `03-test.md` §1/§3 and `tools/regression-process-ownership.sh`; I3 uses a new inert-by-default `RUNNER_TEST_RAISE` hook (inject-don't-exhaust, like `WEIZIGO_HOST_MEM_AVAIL_MB`). Both arms PASS. |
| B-5 | C4 host-guard cull's reap invisible in the ledger — C6's stated harm unclosed at the incident's own call site (must) | **ACCEPT — CLOSED (D29).** `tools/runner` now appends each C4 cull's `pid/claimed/survivors/ok/reason/unknown_partial` to `run_record["cull_reaps"]` (a list; the exit-path reap's `reap_*` fields never overwrite it). Also fixed a pre-existing RED in `regression-runner-guard.sh` (stale `killed largest member` grep vs the renamed `reaping largest member` message). |
| B-6 | Mechanized deletion gate not in T556's kanban acceptance command (must) | **ACCEPT — CLOSED (D30).** T556 `acceptance` set to the three predicates (killpg count=0; `_WALKER_FN` count=3 with no kill/SIGKILL/treekill token; §7.1 family-token grep scoped to the two sentinel comments). Command verified exit 0 via `/bin/sh -c`. |
| B-7 | A seeded session-leader escalates the closure upward past D-19 (should) | **ACCEPT.** Downward-test seeds (or document the trap as a caller contract — today's call sites pass only descendants). |
| B-8 | Downward constraint enforced on the pgid edge only; sid edge correct by construction, untested (should) | **ACCEPT.** Add a mutation control for the sid-edge downwardness. |
| B-9 | Verb exits 1 when cwd has no `.git` above it, outside its own exit-code table (should) | **ACCEPT.** Degrade to an empty protected set; `treekill` only needs the root for G6. |
| B-10 | `--anchor -1` exits 2, where `pid ≤ 1` ⇒ exit 4 (could) | **ACCEPT.** Distinguish the "missing anchor" sentinel from a parsed negative. |
| B-11 | G4's live-path `etime`→epoch arithmetic has no control (could) | **ACCEPT.** Add a live-path S7 control; cross-validated against `lstart` already. |

**Fix order (smaller-parts):** B-2 (one line) and B-1 (runner ledger honesty) first — the two
criticals — then B-3/B-4/B-5/B-6 (musts), then B-7..B-11. All bounded, none require touching
the closure itself.
