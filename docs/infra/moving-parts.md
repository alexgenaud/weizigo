# Moving Parts Inventory & Process Hygiene Policy

Short name: *what is running on this host because of us, and can we name a benefit for each one?*

**Landmark:** advances `L1 (the dashboard tells the truth)` — an undocumented daemon is a moving
part whose failures nobody attributes.

**Operator directive (2026-08-25):**
> *"I don't want any undocumented moving parts. I want very few moving parts, all well understood, with obvious purpose and benefit… Anything that is not clearly beneficial and productive should be examined and reviewed and possibly killed… Simplicity and reliability are of highest priority."*

---

## 1. Inventory of Moving Parts

The following table catalogs every executable moving part that can run on this host for `weizigo`. Every process matching a project pattern must appear in this table with an explicit disposition and stated rationale. Undocumented running processes cause `tools/regression-moving-parts.sh` to fail.

| Executable / Process | What starts it | What stops it | How you tell it is running | What it produces / Mutates | Disposition & Stated Benefit / Review |
|---|---|---|---|---|---|
| `tools/pop-next.sh --loop [N]` | Operator or script in interactive / detached shell | Loop iteration limit reached, `pop-next.stop` file created (graceful stop), queue has no dispatchable `AUTO` rows, or SIGINT/SIGTERM | `pgrep -f "pop-next.sh"` or `ps -axo pid,command \| grep pop-next.sh` | Pops highest-ranked `AUTO` task from `docs/infra/dispatch-queue.tsv` and dispatches it serially via `bin/dispatch` | **KEEP.** Direct fulfillment of operator directive (2026-08-25) for methodical, serial, automated backlog execution with hold/conflict safety and no autonomous manager ceremony. |
| `tools/fleet-keeper.sh` | Shell or launchd (`tools/weizigo.fleet-keeper.plist`) | `fleet-keeper.cooldown` (graceful stop), empty queue, SIGINT, or manual SIGKILL | `pgrep -f "fleet-keeper.sh"`, `tools/fleet-cooldown.sh status`, or log file | Autonomous multi-lane dispatch loop and logjam-pressure state machine | **RECOMMEND DELETE / RETIRE.** Ran for 4 days 19 hours (16,439 log lines) in cooldown without dispatching a single task, invisibly consuming system attention. Superseded by `pop-next.sh`. |
| `watch-fleet.sh` | Operator in interactive terminal | Ctrl+C (SIGINT) or closing terminal | `pgrep -f "watch-fleet.sh"` or active terminal window | Read-only live ANSI terminal dashboard of fleet progress, active tasks, CPU/RAM, token spend, done rates, and concerns | **KEEP.** Essential human monitoring console. Read-only dashboard with no store mutations. |
| `bin/dispatch` / `bin/subagent` | `pop-next.sh`, `fleet-keeper.sh`, or operator CLI (`bin/dispatch <T-ID> <model>`) | Child worker process exits and `tools/dispatch_verify.py` completes mechanical verification | `pgrep -f "subagent\|dispatch"` | Spawns worker under `tools/runner`, verifies worker outputs (nonce, deliverables, kanban status), appends telemetry to `docs/infra/model-perf.md` and `docs/infra/dispatch-heals.jsonl` | **KEEP.** Single front door, isolation barrier, and mechanical verification boundary for executing tasks. |
| `tools/runner` | `bin/subagent` or direct CLI tool invocation (`tools/runner -- ...`) | Child process exits, wall clock ceiling reached (`--max-wall`), RSS cap exceeded (`--ram-mb`), or SIGINT/SIGKILL | `pgrep -f "tools/runner"`, `--arbiter-id` in `ps`, heartbeats in heartbeat log, run records in runs store | Memory caps, admission control via arbiter, process group termination, heartbeats, run records | **KEEP.** Essential host safety container preventing out-of-memory kernel panics and runaway child processes. |
| `caffeinate -i -w <pid>` | `tools/runner` (sidecar child) or `tools/goban-scaling-capture.sh` | Auto-terminates when target `<pid>` exits (OS kernel monitors `<pid>`) | `pgrep -f "caffeinate -i -w"` | Prevents macOS idle sleep during active compute/benchmarking runs, ensuring wall clock measurements remain honest | **KEEP.** Sleep prevention safely bound to target process lifetime. Auto-releases on any process termination. |
| `caffeinate -i -t <secs>` (project-spawned) | Historical test scripts or ad-hoc manual execution | Timer expiration or manual SIGKILL | `pgrep -f "caffeinate -i -t"` | Prevents host sleep for fixed duration | **PROHIBIT / RETIRE.** Kept host awake after parent test died (e.g. hung test trees). Only `-w <pid>` is permitted. |
| `caffeinate -i -t <secs>` (harness / external) | External agent harnesses (e.g. Claude Code console `claude --dangerously-skip-permissions`, Pi) | Console closure or harness exit | `pgrep -f "caffeinate"` with parent PID outside project ancestry tree | Prevents macOS sleep while interactive or agent console session is open | **EXEMPT (NOT OURS).** Managed entirely by external agent harness infrastructure, outside project control. Has no project script in its ancestor chain. Scoped out of project process hygiene gate (T952) by ancestry check. |
| `zig build test` / `zig test` | Pre-commit hook, CI scripts, or manual developer invocation | All test steps pass, fail, or crash | `pgrep -f "zig build test"` or `pgrep -f "zig test"` | Compiles and executes test suite across engine, tooling, and regression suites | **KEEP.** Standard correctness and regression gate for the repository. |
| `tools/hooks/pre-commit` | `git commit` when `core.hooksPath` is configured | Verification checks complete or fail | Active only during `git commit` | Blocks regressions against claimlint floor, title length gate, staged file scope, and holder conflict rules | **KEEP.** Primary git repository integrity gate preventing invalid or contaminating commits. |
| `tools/weizigo.fleet-keeper.plist` | `launchctl load` | `launchctl unload` | `launchctl list \| grep com.weizigo` | Unattended background launchd daemon running `fleet-keeper.sh` | **RECOMMEND DELETE.** Decommissioned. Invisible background execution creates unmonitored moving parts. |
| `com.weizigo.suite-truth.plist` | `launchctl load` | `launchctl unload` | `launchctl list \| grep com.weizigo` | Unattended background launchd daemon running `suite-truth.sh` | **RECOMMEND DELETE.** Decommissioned; unlinked from LaunchAgents. |
| `tools/suite-truth.sh` | Operator CLI or pre-commit hook reader (`--read-result`) | Test suite run finishes and manifest comparison completes | `pgrep -f "suite-truth.sh"` | Runs guarded `zig build test` and compares observed reds against `docs/infra/suite-truth.md` manifest | **KEEP (as manual tool/hook reader).** Useful regression surface comparison tool; prohibited as background daemon. |
| `bin/argus` (`argus doctor`) | Operator CLI or duty runner (`DARGUS` brief) | Diagnostic checks complete | `pgrep -f "bin/argus"` | Diagnostic health report of git state, store consistency, and claimlint status | **KEEP.** On-demand diagnostics and health reporting tool. |
| `bin/managent` | CLI commands (`managent orient`, `claim`, `done`, `reap`, etc.) | Command completes | Active only during CLI command execution | Kanban queue management, task lifecycle transitions, and lockfile synchronization | **KEEP.** Core kanban and workflow coordination tool. |
| `tools/git-commit-mine` | Developer or script CLI | Commit creation completes | Active only during commit execution | Staged file isolation and commit authoring preventing cross-console staging contamination | **KEEP.** Primary fleet git isolation tool. |
| `tools/goban-scaling-capture.sh` | Operator / benchmark script | Solve completes | `pgrep -f "goban-scaling-capture"` | Measures wall time and peak RSS scaling across goban dimensions with sleep tracking | **KEEP.** Benchmarking instrument for engine scaling analysis. |
| `bin/weizigo-*` (oracle, arena, gtp, claimlint, reachcensus) | CLI / Sabaki GUI / automated benchmarks | Process exit / quit command | `pgrep -f "weizigo-"` | Core game engine binaries (solving, GTP play, reachability, arena battles, claimlint verification) | **KEEP.** Core game engine binaries. |
| `tools/smoke.sh` / `tools/deploy.sh` | Post-build verification / deployment script | Build stamp comparison completes | Active only during deployment | Rebuilds and deploys freshly compiled binaries to `bin/` and validates freshness stamps | **KEEP.** Essential deployment verification tool. |

---

## 2. Scratch Directory Lifecycle & Retention Rules

### 2.1 The Pinned Module Scratch Root Cause & Resolution
- **Observed State (2026-08-25):** 3,917 scratch directories accumulated in the temporary area (consuming hundreds of megabytes).
- **Root Cause:** Commit `2ea6f80` (T631) added `_load_pinned_dispatch_verify()` in `bin/subagent` to import `tools/dispatch_verify.py` from committed revision. It created a temporary directory on every single dispatch and test run, but **never registered an cleanup handler**.
- **Fix (T943):** Added `atexit.register(shutil.rmtree, tmp_dir, ignore_errors=True)` in `bin/subagent`. On process termination (normal, exception, or exit), the pinned module directory is immediately removed. Similar cleanup handlers were added to unit test suites (`tests/unit/test_dispatch_verify.py`, `tests/unit/test_token_capture.py`, `tools/regression-canonicalizer-parity.sh`).

### 2.2 Retention Rules
1. **The scratch area is strictly ephemeral.** Every process, script, or test that creates temporary files or directories MUST register an `EXIT` trap (bash) or `atexit` / `tearDown` handler (Python) to delete them on exit.
2. **No scratch directory may survive its creator.** If a test finishes or a worker exits, its scratch directory must be deleted immediately.
3. **Reboot & Maintenance Sweeps:** Any scratch directory older than 6 hours is subject to automatic pruning.
4. **Legitimate Persistent Data:** Persistent data must NEVER live in temporary scratch areas. It lives exclusively in git-tracked paths or documented persistent run/token stores:
   - Run records directory — dispatch and nested run records
   - Token store — token logs and session transcripts
   - Heartbeat log — live runner heartbeats
   - Persistent concerns store — persistent dashboard concern state

---

## 3. Orphan & Stale Process Policy

1. **No Undocumented Daemons:** Any process matching project patterns that is not explicitly documented in the table above is considered a rogue moving part.
2. **Orphan Processes (`ppid == 1`):** Project child processes (such as test runners, compilers, or child scripts) that become orphaned (`ppid == 1`) indicate a crashed parent that abandoned running jobs. Such processes must be reported and terminated.
3. **Wall Budget Ceilings:** Dispatches running under `tools/runner` are bound to their `--max-wall` budget (default 1800s/7200s). Processes exceeding their max wall time are killed with SIGKILL by `tools/runner`.
4. **Sleep Guard Discipline:** `caffeinate` spawned by project scripts or runners must ONLY be run as `caffeinate -i -w <pid>` where `<pid>` is an active parent runner process. Unattached or timed `caffeinate -i -t` commands in project ancestry are prohibited. External agent harness caffeinate instances (with no project scripts in their ancestor chain) are documented as exempt (T952).
5. **No Launchd / Cron Background Daemons:** Background schedulers are retired in favor of interactive or foreground loops (`tools/pop-next.sh --loop`).
