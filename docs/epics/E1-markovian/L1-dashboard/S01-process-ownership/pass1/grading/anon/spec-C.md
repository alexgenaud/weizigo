# Pass 1 — SPEC: process ownership

`managent own` — a verb that owns a process tree by enumerating it, freezing it, and proving it dead.

---

## 0. Scope finding, stated first

Pass 1 is the right first bite and the right size. Two boundary corrections, argued in §6:

1. **The brief's cannibalization list is one site short.** The measured incident was the *host guard* culling 12 workers; the host guard's kill is `os.kill(largest_pid, signal.SIGKILL)` — one pid, no tree (`tools/runner:1435`, inside the block at `tools/runner:1420–1445`). If pass 1 fixes `tools/runner:1505` and the normal-exit path but leaves 1435 killing a single pid, the verb ships without touching the line that produced the 2026-08-20 harm.
2. **"Every exit path" needs enumerating, or the non-goal is unfalsifiable.** `tools/runner` has four exit paths: ceiling/guard kill (`:1502–1512`), normal exit (`:1538`), runner exception (`:1539–1543`, the `except`/`finally` pair), and runner death by signal (no code, by definition). Pass 1 covers the first three. The fourth is `T548`. Say "three of four", not "every".

One addition I argue for as in-scope because it is the *stated harm*: the runner must record the verb's summary counts into the run record it already writes (`tools/runner:1247–1256`, `untracked/runs/<task>.json`, per `src/managent/main.zig:6045`). Without one field, pass 1 cannot demonstrate that it fixed anything measurable, and culls remain indistinguishable from model failures in the ledger the project exists to build.

---

## 1. What "owned" means, testably

Let `A` be the anchor pid — the pid the runner spawned (`tools/runner:1241`, which passes `preexec_fn` from `:1161`, so `A` is a session leader with `sid == pgid == A`).

**Definition (Owned).** `A` is *owned* iff, after `managent own --anchor A --kill` returns 0, both hold:

- **O1 (roll-call empty).** Every pid the verb printed on stdout as claimed is dead, verified by a *fresh* process-table snapshot taken after a settle window, not by the verb's own bookkeeping.
- **O2 (closure empty).** Recomputing the closure (§3) over that fresh snapshot from the recorded claimed-pid set — including the sid keys of every claimed session leader — yields zero live members.

O1 alone is what a naive implementation passes. O2 is what catches the reparent race: a child forked after the snapshot has a live ppid or sid pointing into the claimed set, so it appears in the recomputed closure even after its parent reparents to init.

**Corollary condition, for the arm that ties to the incident (§5, S3):** cohort RSS — the sum of `rss` over the closure — returns to within tolerance of its pre-spawn baseline. This is the condition the 9.1 GB observation violated; O1/O2 are the mechanism, RSS is the consequence.

**Non-condition.** "Robust", "reliably", "no orphans on the host". The host has processes that are not ours; a spec that asserts anything about them is untestable and unsafe.

---

## 2. The verb's contract

```
managent own --anchor <pid> [--kill] [--protect <pid>]... [--rounds <n>]
                            [--settle-ms <n>] [--json] [--ps-fixture <path>]
```

**Name.** `own`, not `reap`. `managent reap` already means *kanban* orphans (`src/managent/main.zig:471`, `:5464`; controls in `tools/regression-orphan-reaper.sh`). Reusing the word would re-commit the exact error the brief names: one word, two meanings, hidden for months.

**Mode.** Read-only by default. Without `--kill` the verb enumerates and prints; it signals nothing. `--kill` is the only path that signals. The safe mode is the default, so a mis-typed invocation is inert.

**Exit codes.**

| code | meaning | who reads it |
|---|---|---|
| 0 | converged; report printed, or all claimed pids dead | runner: proceed |
| 2 | usage error (missing/invalid `--anchor`; `--kill` with `--ps-fixture`) | control S6 |
| 3 | anchor already dead — `claimed=0`, well-formed output, **not an error** | runner normal-exit path, the common case |
| 4 | **refused by guard** — nothing was killed; anything frozen was resumed | controls S4, S5 |
| 5 | **not converged** — survivors remain after `--rounds`; the loud failure | controls S2, alerting |

Codes 3/4/5 deviate from `managent`'s prevailing blanket `std.process.exit(1)` (e.g. `src/managent/main.zig:489`, `:499`). The deviation is deliberate and load-bearing: a control cannot distinguish "correctly refused" from "failed to kill" through a shared code, and the runner must not treat "already dead" as a fault. Flag for consolidation if a stricter project-wide code map exists; `docs/infra/managent/spec.md` documents per-verb exit semantics only (`:38`, `:39`), not a global map.

**Output shape** (per `AGENTS.md:128–131`: stdout data, stderr diagnostics; regression check `<tool> 2>/dev/null` emits data, `1>/dev/null` is silent):

- stdout, one record per claimed pid, tab-separated (or JSON lines under `--json`):
  `pid  ppid  pgid  sid  start_iso  uid  rss_kb  state  action  command`
  where `action ∈ {report, frozen, killed, survived, exempt, protected}`.
- stdout, final line, always: `own anchor=<pid> claimed=<n> killed=<n> exempt=<n> survivors=<n> rounds=<r> rss_reclaimed_kb=<n>`. This line is what the runner copies into the run record.
- stderr: `[own] …` diagnostics only.

**Edge behaviour.**

| target | behaviour |
|---|---|
| already dead | exit 3, `claimed=0`, summary line still printed |
| `pid <= 1` | exit 4, refused, no signal. pid 1 is never claimable, never killable |
| not ours (`uid != geteuid()`) | excluded from the closure; if the *anchor* is not ours, exit 4 |
| the verb's own pid, or any ancestor of it | exit 4 (§4 G3) |
| pid reused since spawn | excluded: a member whose start time precedes the anchor's start time is never claimed (§4 G4) |

---

## 3. Building on the measured mechanism

Taken as given (measured 2026-08-20, this repo, production chain; `docs/epics/E1-markovian/L1-dashboard/S01-process-ownership/pass1/LADDER.md`): the console harness starts each tool command in a **new session**; zig creates none (`std/process.zig:397` — `pgid: ?posix.pid_t = null`, verified present in Zig 0.16.0 at `/opt/homebrew/Cellar/zig/0.16.0_1/lib/zig/std/process.zig:397`, and the only occurrence of `pgid`/`setsid`/`setpgid` in that file). Escapees are session leaders ⇒ group- and session-level kills are structurally insufficient.

**Corroboration measured inside this lane, 2026-08-20** (a `claude -p` tool command, one command, reproducible):
`os.getpid()=12988, ppid=12986`; `getsid(12986)=12986` and `getpgid(12986)=12986` — the tool-command shell **is** a session leader — while its parent `8068` has `getsid(8068)=8068`, a *different* session, and `8065` sits in session `281`. Two nested new sessions between the console and the command. Also confirmed: `ps -o pid,ppid,pgid,sess -p 12986` prints `SESS 0` — the `sess` column is useless on macOS, as the LADDER records.

**Measured negative, this host, 2026-08-20** (worth recording because it kills an attractive design): an inherited environment token is **not** usable as a cohort key. `ps eww -p <pid>` and `ps -E -o pid,args -p <pid>` on a same-uid child (`FOO_TOKEN=abc123 sleep 60`) printed the command line and **no environment**. The cohort must therefore be derived from the process table (`ppid`, `pgid`, `sid`, start time) plus `command`, which *is* readable.

### The algorithm the verb owes (freeze → fixpoint → kill → verify)

1. **Identify.** Snapshot the anchor's `start_time`. If absent → exit 3.
2. **Freeze round.** `SIGSTOP` the current frontier. A stopped process cannot fork and cannot exit, so it cannot reparent its children mid-walk. This converts the unbounded race into one bounded by fork latency of *not-yet-stopped* members.
3. **Close to fixpoint.** Re-snapshot the table. Add any process `P` (same uid, `start_time(P) >= start_time(A)`) where `ppid(P)` ∈ set, **or** `sid(P)` ∈ {pid of any claimed session leader} ∪ {sid of any member}, **or** `pgid(P)` ∈ {pgid of any member}. Repeat 2–3 until the set stops growing or `--rounds` (default 5) is exhausted.
   The sid/pgid edges are what recover trees already reparented to init — a reparented escapee loses its ppid edge but keeps its session, and its own children keep pointing at it.
4. **Validate** the whole closure against §4's guards **before any SIGKILL**. On refusal: `SIGCONT` everything frozen, exit 4. Freezing precedes validation by necessity (the closure is not known until the walk finishes), so the rollback is mandatory, not optional.
5. **Kill.** `SIGKILL` every claimed member. SIGKILL is delivered to stopped processes; no `SIGCONT` is needed first.
6. **Verify.** Sleep `--settle-ms` (default 250), re-snapshot, recompute O1 and O2. Survivors → one more round if budget remains, else exit 5 with each survivor printed as `action=survived`.

**Enumeration source.** One `ps -axo pid=,ppid=,pgid=,uid=,lstart=,rss=,stat=,command=` per round, executed through the existing helper `runCommand` (`src/managent/main.zig:8731`), parsed in Zig. `ps` has no session column that works on macOS (measured above), so `sid` comes from `getsid(2)` per candidate pid. **`getsid` is absent from Zig 0.16's std** — `grep -n "fn getsid" std/c.zig std/posix.zig` returns nothing; only `setsid` exists (`std/c.zig:11015`). One `extern "c" fn getsid(pid: std.c.pid_t) std.c.pid_t;` declaration covers it. The `sysctl(KERN_PROC_ALL)` route would deliver ppid, sid and start time in one syscall — `std.c.sysctl` exists (`std/c.zig:10720`) — but `kinfo_proc` does not (`grep -n "kinfo_proc" std/c.zig` returns nothing), so it needs a hand-written struct layout. Rejected for pass 1 on "fewer moving parts"; recorded as the pass-N optimization if `ps` cost measures badly.

### The per-family residual check (owed before seeded controls are finalized)

The measurement covers `claude -p` (`bin/subagent:261–264`). Two families are unmeasured: [SELF-IDENTIFICATION REDACTED] CLI (`bin/subagent:248–251`, `pi --provider deepseek`) and ollama (`bin/subagent:265–267`, `ollama launch pi`).

**One command per family**, run while a real dispatched worker is mid-run, output committed to the phase-4 artifact named in `LADDER.md`:

```sh
# $A = the runner's child pid, from untracked/runs/<task>.json ("pid")
ps -axo pid=,ppid=,pgid=,uid=,lstart=,rss=,command= |
  awk 'NR==FNR{next}1' /dev/null - > /tmp/own-snap-<family>.txt
python3 - <<'EOF'   # sid per pid; macOS `ps -o sess` prints 0 and is useless
import os,sys
for l in open("/tmp/own-snap-<family>.txt"):
    p=int(l.split()[0])
    try: print(p, os.getsid(p), os.getpgid(p))
    except ProcessLookupError: pass
EOF
```

Recorded per family: (a) does the tool command run as a session leader (`sid == pid`)? (b) is `pgid == pid`? (c) tree depth from `A` to the deepest compile child; (d) does any member reparent to `ppid == 1` while the run is live? If any family answers (a) *no*, its seeded control must still be built — the closure's sid edge is then redundant for that family, and the arm proves the verb does not over-claim.

---

## 4. Safety

This verb kills processes on a live machine. The seat ran an untested reaper with three hand-reasoned guards on 2026-08-20; every guard below is paired with a control in §5.

**Never killable, unconditionally.** pid 0, pid 1, any pid whose uid ≠ `geteuid()`, the verb's own pid, every pid on the verb's own ancestor chain (`ppid` walk to 1), and any process that is the session leader of a session containing the verb's own pid — that last one is the operator's console and login session.

| # | guard | failure mode it blocks |
|---|---|---|
| G1 | `--anchor` must be `> 1`, must exist, must be same-uid; else exit 4 | killing init or someone else's work |
| G2 | Read-only default; `--kill` required to signal | a mistyped invocation being destructive |
| G3 | Self/ancestor exclusion (above) | the verb killing the runner that called it, or the console |
| G4 | Start-time monotonicity: never claim `start_time(P) < start_time(A)` | pid reuse; a long-lived bystander that inherited a recycled pgid |
| G5 | **Atomic pre-flight**: the *whole* closure is validated before the first SIGKILL; any violation refuses the whole operation | half-killed trees, which are worse than untouched ones |
| G6 | **Protected set**: pids from `untracked/runs/*.json` belonging to *other* `in_progress` rows (schema at `src/managent/main.zig:6045`, `:6062–6064`), plus every `--protect <pid>` given. Intersection ⇒ exit 4 naming the task id | one worker's cleanup killing another worker |
| G7 | **Rollback**: refusal after freezing must `SIGCONT` every stopped pid before returning | a refused call leaving the fleet suspended — a silent, total outage |
| G8 | **Delegated-ownership exemption**: a subtree whose root's `command` contains the literal marker `--managent-detach` is excluded, with its root reported `action=exempt` | pass 1 killing a nested dispatch the worker legitimately detached (`bin/dispatch:301` sets `start_new_session=True`; a nested dispatch is a descendant of the worker) |
| G9 | `--ps-fixture` implies report-only; `--kill --ps-fixture` is exit 2 | ever killing live pids from a canned table |
| G10 | Bounded rounds (`--rounds`, default 5) and loud non-convergence (exit 5) | an unbounded loop against a fork-heavy tree |

**G8 is a real conflict, not a hypothetical**, and it is why ownership must be a *chain of anchors*, not one flat closure: a nested dispatch has its own runner, its own run record and therefore its own owner. Exempting it does not reopen the leak; it names who owns it. If consolidation prefers the alternative — forbid nested dispatch mid-run — that is also acceptable, but it must be *chosen*, because the current code permits it and the closure would kill it.

**What is never killable and never exempt:** the protected set (G6) cannot be waived by a flag. There is no `--force`.

---

## 5. The controls, named but not written

New file `tools/regression-process-ownership.sh` — **not** added to `tools/regression-orphan-reaper.sh`, which tests *kanban* orphans (its own header: "a task *row* whose worker died"). Same conventions as the existing arms: scratch tree under `/tmp/weizigo`, `$MANAGENT_BIN` → `zig-out/bin/managent` → `bin/managent`, SKIP loudly when the verb is absent. Tests land red, before implementation.

| arm | kind | asserts |
|---|---|---|
| **N1** leaf | null | anchor = a childless `sleep`: `claimed=1`; `--kill` kills exactly it; a full pre/post table diff shows no other pid changed state |
| **N2** bystander | null (**the mandated survivor**) | a second tree in its own session, built by the same generator as S1, plus a real `in_progress` row backed by a live worker: after `--kill` on A, every pid of tree B is alive, unstopped (`stat` has no `T`), and B's row is untouched |
| **N3** delegated | null | a subtree whose root argv carries `--managent-detach` survives `--kill` and is reported `action=exempt` (G8) |
| **S1** deep escape | seeded | 4-deep tree where level 2 calls `setsid` (reproducing "escapee is a session leader") and level 3's parent exits immediately so level 4 is reparented to init *before* the walk: zero survivors, O1 ∧ O2 |
| **S2** reparent race | seeded (**the whole point**) | a member that exits ~200 ms after the first snapshot while forking a long-lived child; run `--kill` ≥20 iterations; zero survivors *every* iteration. This arm is what the freeze phase exists for, and it is deliberately a repeat-count arm because a single pass proves nothing about a race |
| **S3** memory witness | seeded | a member touching ~1 GB: cohort RSS returns to baseline ± 5 % and `rss_reclaimed_kb` in the summary is within 10 % of the measured drop — the arm that ties to the 9.1 GB observation |
| **S4** guards | seeded | `--anchor 1` → exit 4, no signal; `--anchor <the calling shell>` → exit 4; `--anchor <a root-owned pid>` → exit 4; in all three, a live bystander is untouched *and unstopped* (G1, G3, G7) |
| **S5** protected set | seeded | a fabricated run record for another `in_progress` row whose pid sits inside A's closure ⇒ exit 4, zero signals, the diagnostic names the task id, and the frozen members are running again afterwards (G5, G6, G7) |
| **S6** parser / pid reuse | seeded | `--ps-fixture` with a hand-built table containing a member older than the anchor: excluded from the closure (G4); `--kill --ps-fixture` → exit 2 (G9) |
| **S7** already-dead + streams | seeded | anchor exited before the call ⇒ exit 3, `claimed=0`, summary line present; `own … 2>/dev/null` emits records, `own … 1>/dev/null` is silent (`AGENTS.md:128–131`) |
| **S8** differential oracle | seeded | on a churn-free tree, the Zig closure and the *existing* Python walker `_descendant_pids_ps` (`tools/runner:603`) produce the identical pid set from the same snapshot. The Python walker is demoted to a fixture, not deleted — it is the second implementation, so it is an oracle |

**Instrument controls (the arms that test the tests).** Per the standing rule that no instrument's first reading counts before a seeded-defect control:

- Freeze phase disabled ⇒ **S2 must fail**. If S2 still passes, S2 is not testing the race and must be strengthened (raise iterations, shorten the exit delay).
- Start-time filter disabled ⇒ **S6 must fail**.
- Protected-set check disabled ⇒ **S5 must fail**.
- Rollback (G7) disabled ⇒ **S5's "running again afterwards" clause must fail**.

An arm that cannot be made to fail by deleting the code it covers is not a control; it is decoration.

---

## 6. The cannibalization step

Pass 1 is done when the old code path is gone, not when the verb exists (`LADDER.md`: "Cannibalization is the deliverable, not the verb").

| # | site | today | after |
|---|---|---|---|
| C1 | `tools/runner:1505` | `os.killpg(proc.pid, signal.SIGKILL)`, and the message at `:1503` (`[runner] SIGKILL pgid …`) | `subprocess.run([managent, "own", "--anchor", str(proc.pid), "--kill"])`; message becomes the verb's summary line. `proc.wait(timeout=2.0)` at `:1509` stays |
| C2 | `tools/runner:1538` (normal exit, `ret = proc.wait()`) | reaps nothing | call the verb immediately after `:1538`, before `_capture_tokens` — the memory should be released before the token parse, not after |
| C3 | `tools/runner:1539–1543` (`except` path) | writes a heartbeat and a run record, reaps nothing | same call before `_finalize_run_record` at `:1542` |
| C4 | `tools/runner:1435` (host guard) | `os.kill(largest_pid, signal.SIGKILL)` — one pid | `own --anchor largest_pid --kill`. **§0's argument**: this is the line that culled 12 workers |
| C5 | `tools/runner:603` `_descendant_pids_ps` + `:641` `_WALKER_FN` | the runner's own working descendant walker, used for RSS peaks at `:1353` | **demoted to a test fixture** for S8, not deleted (two implementations are mutual oracles). Not called from any kill path |
| C6 | run record, `tools/runner:1247–1256` / `_finalize_run_record` | records pid, pgid, exit, signal, rss | plus `reaped_claimed` / `reaped_survivors` from the summary line, so a host cull is distinguishable from a model failure in the ledger |

**Mechanized deletion gate** (not prose): `grep -n killpg tools/runner` returns nothing, and `grep -n "_WALKER_FN" tools/runner` matches only the RSS path. Both belong in the acceptance command of the pass-1 build row so the gate is enforced by the kanban, not by a reviewer's memory.

**The most citable fact in this section:** `tools/runner` already enumerates the tree it fails to kill (`:603`, used at `:1353`). Pass 1 is not new knowledge; it is connecting two pieces the file already contains, in the one language where the connection can be owned and tested. Corollary worth recording: because reparented escapees drop out of that same BFS, the runner's `peak_rss` **under-reports** every leaked run — the observed 2.8 GB residue at 25–27 GB free was invisible to the instrument that was watching.

---

## 7. One dispatch interface for every harness

The verb's entire input is **a pid plus policy flags**. It contains no model label, no provider string, no harness name, no per-family branch — verifiable by a grep gate: `grep -nE "claude|deepseek|ollama|dspro|dsflash|qwen|glm|minimax|kimi" src/managent/own.zig` must return nothing, and that grep belongs in the acceptance command.

Family variation lives in the *data* — the shape of the snapshot — not in the code. Three consequences that make the verb serve the later single-dispatcher pass instead of needing a rewrite:

1. **Uniform closure rule.** The union of ppid, sid and pgid edges plus start-time filtering covers "child in same session" (ollama's likely shape), "child in a new session" (`claude -p`, measured) and "child reparented to init" (all families) with the same code. A family that turns out not to escape simply contributes no sid-edge members; the arm proving that is a null control, not a variant.
2. **The anchor is the interface.** Every family already routes through `tools/runner` (`bin/subagent:248`, `:261`, `:265`), which already writes the anchor pid into `untracked/runs/<task>.json` (`tools/runner:1247–1256`). The single dispatcher of the later pass therefore needs to supply nothing new: pid + policy is the whole contract, and "pid, child ps" from the operator's requirement is exactly the verb's stdout record shape.
3. **No per-family policy.** Guards are uid/pid/start-time/run-record facts, identical for every family. If a future family needed its own guard, that would be the signal that the verb has family knowledge and has drifted — worth stating as a review trigger, because it is the failure mode the operator's requirement names.

What *is* per-family is the **residual measurement** (§3) and its seeded arms — data and tests, not code paths. That is the correct place for family knowledge to live.

---

## 8. Explicit non-goals

- **No daemon.** `managent` stays a short-lived CLI, invoked and exited.
- **No new supervisory process of any kind** — no watcher, no cron reaper, no launchd agent, no periodic sweep. The fix is that the mechanism works, not that something watches it fail. A design that needs a watcher has failed this spec.
- **Runner death** (a SIGKILLed runner reaps nothing) — `T548`'s sweep, later the supervisor's held handles.
- **Supervisor rewrite, state consolidation, dashboards** — later passes.
- **The single dispatch interface itself** — later pass; §7 only constrains the verb's shape.
- **`bin/dispatch:301`'s `start_new_session=True`** stays as it is. Detachment is not the bug; unowned detachment is. Changing the dispatcher belongs to the dispatcher pass.
- **`managent reap`** (kanban orphans) is untouched, unrenamed, and its controls (`tools/regression-orphan-reaper.sh`) are not edited.
- **No memory policy.** RSS caps and host floors stay in `tools/runner`; the verb kills what it is pointed at and reports RSS, it never decides *whether* to kill on memory grounds.
- **Linux.** The closure is written to parse a `ps` table and would likely work, but only macOS is measured. Pass 1 claims macOS only; `/proc` fast paths are out of scope.
- **No `--force`, no `--all`, no "reap the host" mode.** There is no invocation that kills without an anchor.

---

## 9. Uncertainties, stated

1. **The environment-token design is dead on this host** — measured (§3): `ps eww` / `ps -E` print no environment for a same-uid child. I did not test whether a root or entitled path exists, and did not pursue it. If another lane's spec relies on an inherited env marker, this measurement contradicts it and should be re-run before consolidation accepts it.
2. **`getsid(2)` call cost is unmeasured.** One `getsid` per candidate row, up to ~1,000 rows, up to 5 rounds. Cheap in principle (a trivial syscall), unmeasured in fact. If it measures badly, the `sysctl(KERN_PROC_ALL)` route removes it entirely at the cost of a hand-written `kinfo_proc` layout.
3. **`ps -axo … lstart` parsing.** `lstart` prints a space-containing human date (`Thu Aug 20 19:39:03 2026`, measured), which makes positional parsing fragile if `command` is also requested. Options: put `command=` last and split on a fixed field count, or use `etime=` (elapsed, `02-06:54:27` format, also measured) for the monotonicity filter instead. I lean `etime` — coarser but unambiguous — and flag the choice for the design pass rather than deciding it here.
4. **Fork-faster-than-freeze is theoretically unbounded.** `--rounds` + exit 5 makes it loud rather than solved. Whether a real `zig build` tree ever needs more than 2 rounds is unmeasured; S1/S2 should record the observed round counts so the default is chosen from data.
5. **G8 is a judgement call, not a measurement.** I do not know of an active nested dispatch in the current fleet configuration. If nested dispatch is in fact forbidden mid-run, G8 and N3 should be deleted rather than implemented — one fewer moving part. This needs an operator or Orchestrator answer, and it is the one open question that changes the deliverable.
6. **Grading confidence.** Per `docs/epics/E1-markovian/L1-dashboard/S02-model-delegation/grand-race.md` §5 and its 2026-08-20b consequence, a [SELF-IDENTIFICATION REDACTED]-authored spec draws only three countable grades against qwen's six; any [SELF-IDENTIFICATION REDACTED]-vs-[SELF-IDENTIFICATION REDACTED] ordering including this document is low-confidence by the protocol's own record.

---

## 10. What to quarry from this spec

**Best contribution: §3's freeze → fixpoint → kill → verify loop together with G7's mandatory `SIGCONT` rollback.** The freeze is what converts the reparent race from "hope the walk wins" into a bounded, testable postcondition; the rollback is the non-obvious obligation it creates, because the closure cannot be validated until after the freeze, so a *refused* call is exactly the path that can leave the fleet suspended. I have not seen that consequence stated anywhere in the repo, and it is the kind of defect that would ship green.

Three more separable pieces, in order of what I would keep next:

- **§1's O1/O2 pair.** O2 (recompute the closure over a fresh snapshot, including sid keys) is the only postcondition that catches a child forked after the snapshot. O1 alone is the definition a naive implementation passes.
- **§6 C5 + S8.** The runner already owns a working descendant walker (`tools/runner:603`) that the kill path ignores; demoting it to a differential oracle rather than deleting it gives the Zig closure a second implementation to be checked against, for free.
- **§5's instrument controls.** The four "disable X ⇒ arm Y must fail" mutations are what make the seven arms evidence instead of decoration.

Weakest part, said plainly: §9.3's `lstart`/`etime` parsing question is unresolved, and G8 (§4) may be scope I invented — if nested dispatch is forbidden, delete it and the spec gets shorter.
