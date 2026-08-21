# Pass 1 — build plan (`05-plan.md`)

**Owner:** pass-1 builder seat (claude-opus-5), T556 lineage · **Date:** 2026-08-21 ·
**Status:** PROPOSED · **Gate:** document review, fresh session, different model
(`LADDER.md` phase 6) ·
**Inputs:** `01-spec.md` + `01-spec-audit-disposition.md` (D-1..D-41; **the disposition
wins where they differ**), `02-scope.md`, `03-test.md`,
`docs/evidence/orcha-pass1-perfamily-topology/`.

Phase 7 is a **single-lane serial build in the main tree**. Everything below is ordered;
nothing in §1 may be reordered without a recorded deviation in the phase-7 build log.

---

## 0. Preconditions before the first line of phase 7

**P1 — the corrected spec is the source of truth, and it is one writer's file.**
The `01-spec.md` correction pass (D-1..D-41) is landing concurrently and is *partial* as
of this writing: OWN-3's scoped diff (D-8/D-29), the exit-4 semantics (D-10), arm I3
(D-9), I2's escaping shape (D-7), G6's field + discriminator + limits (D-3/D-32), G8's
pre-filter (D-34), the downward constraint (D-19), `--kill`-only freeze (D-20), the C2
seed persistence (D-11/D-35) and the skip-vs-red rule (D-13) have landed. These have
**not**, and until they do the builder follows the disposition, not the spec text:

| still-stale spec text | the disposition the builder follows |
|---|---|
| `01-spec.md:340` C2 "immediately after `:1587`" | **D-24** — C2 goes *outside* the try, and `_reap_tree` is non-raising |
| `:342` C4 `--since <run start>` | **D-22/D-23** — a pre-spawn **epoch integer**, not the ISO string |
| `:346-349` deletion gate ("matches only the RSS/seed path") | **D-38** — mechanical predicates, not a human reading (§3 G-DELETE) |
| `:311` N2 "a real in-progress row backed by a live worker" | **D-26** — fabricated record; the live kanban/`untracked/`/repo are never touched |
| `:314-315` S1/S2 "level 2 setsids" (one boundary) | **D-28** — **two** session boundaries, and the arm names its `--anchor` |
| `:319` S6 "identical pid sets" | **D-27** — equality only on a tree built for equality; OWN-1 is a superset in general |
| `:320` S7 fixture | **D-37** — the fixture schema carries a `sid` column |
| `:318` S5 "refused counted" | **D-34** — by pre-filter, never signal-and-observe |
| `:112` `action ∈ {report, frozen, …}` | **D-41 + D-20** — `frozen` is unreachable once the freeze is `--kill`-gated (a frozen pid ends as `killed` or, after rollback, `refused`); **drop `frozen` from the enum** |

B1 (the control script) may be written now: `03-test.md` already encodes the per-arm
corrections. **B2 does not start until the correction pass is committed.** Re-read
`01-spec.md` at phase-7 entry; if a row above has landed, follow the spec.

**P2 — arm inventory is `03-test.md` plus two arms neither document yet lists.**
`03-test.md` §2-3 predates two accepted items:

- **I3** (exception path) — added by the corrected `01-spec.md:324` under OWN-4 (D-9).
  `03-test.md` §3 lists only I1/I2. Three red integration arms, not two.
- **S9** (mid-tree anchor, the D-19 two-sided control) — D-19's disposition says
  "state it, **add an arm**"; no arm was added. Without it the downward constraint has
  a one-sided control only: S1/S2 catch *under*-claiming, nothing catches *over*-reach,
  and over-reach is the failure that kills the run. **S9:** build S1's two-session tree,
  anchor a *middle* member (the C4 shape), `--kill`, then assert the runner-child root,
  its siblings, and every ancestor are **alive and unstopped**, and the claimed set is
  exactly that member's subtree. B1 writes it; `03-test.md`'s owner should absorb it.

Both are additions to `03-test.md`, not deviations from it. Flagged, then built.

**P3 — three carried design opens, settled here** (`03-test.md` §6 routed them to this
phase; the review gate may overturn any of them):

1. **D-22/D-23 — `--since` shape.** `tools/runner` captures
   `spawn_epoch = int(time.time())` on the line **before** the `Popen` at `:1290` and
   writes `"start_epoch": spawn_epoch` into the launch record at `:1301-1305`; the
   existing ISO-8601 string `"start"` (`:1304`) stays for readers. `_reap_tree` always
   passes `--since <spawn_epoch>`. A pre-spawn epoch is by construction ≤ the anchor's
   true start, so G4 can never exclude the anchor's own tree (D-23), and the dead-anchor
   call sites get a real floor instead of none (D-22). Old records lack the field;
   readers `.get` — same convention as C6.
2. **D-39 — `--rounds` is one shared budget.** `--rounds n` counts iterations of the
   whole body (freeze → close → validate → kill → verify); the fixpoint has no private
   counter. Wall bound = `n × (settle_ms + one ps + one getsid per candidate)`; at the
   defaults, 5 × 250 ms of sleep plus scan cost. S4 asserts a fixed wall in the script.
3. **D-40 — internal failure is `exit 3`.** Degenerate process-table read (D-31), a
   `getsid` error other than ESRCH, allocation failure. Nothing is killed; anything
   already frozen is SIGCONTed (G7's rollback path). Rationale for deviating from
   `managent`'s uniform `exit(1)` (D-14/D-40): a control must separate refused (4) from
   not-converged (5) from broken-instrument (3) without parsing stderr, and `treekill` never
   touches the store, so it never reaches `refuseLiveWrite`'s exit 1
   (`src/managent/main.zig:225-231`).

**P4 — owed, not blocking B1-B6.** D-33's `claude -p` evidence deposit
(`docs/evidence/orcha-pass1-perfamily-topology/claude-family.md`) — the founding
measurement is the only family without a checkable artifact. One probe, parallel-safe,
**blocks phase-9 accept**, not phase-7 build. Until it lands, arms S1-S3/I1-I3 are final
for the DeepSeek and ollama families (phase-4 records) and *claimed* for claude.

---

## 1. Build order (phase 7)

### B1 — `tools/regression-process-ownership.sh`, written and run RED

New file. Conventions cribbed from the T364 script (`tools/regression-orphan-reaper.sh`):
`set -u`, `HERE`/`PROJECT`, `FAIL` counter, `LEFTOVERS`, `cleanup()` trap, exit 0/1.

- Scratch: `WORK="$(mktemp -d /tmp/weizigo/own-regression-XXXXXX)" || { echo "FATAL — scratch mktemp failed; refusing to run (T445)" >&2; exit 2; }` — the T445 live-repo-escape guard verbatim (`tools/regression-orphan-reaper.sh:76`). Fabricated run records go under `$WORK/untracked/runs/`, never the live tree (D-26).
- Binary resolution: `MG="${MANAGENT_BIN:-}"` → `$PROJECT/zig-out/bin/managent` → `$PROJECT/bin/managent` (`:91-98` pattern).
- Presence probe: `HAVE_OWN=1` iff `"$MG" help 2>&1 | grep -q "managent treekill"` (`:99-101` pattern, `HAVE_REAP` there). This is why B2 adds the `printHelp` line: the probe is a help-string grep, not an exit-code guess.
- Helpers, one shell function each: `spawn_two_session_tree` (harness → tool shell `setsid` → runner stand-in `setsid` → command → 2 grandchild sleepers; ≥4 levels, ~15 pids; two boundaries per D-28; writes `pid<TAB>sid<TAB>ppid` per member to `$WORK/tree-<label>.pids`, which is the arm's oracle input and its `--seed` source), `ps_alive`, `ps_state` (the `T`-state check N2/S8/D-30 need), `sid_of` (`python3 -c 'import os,sys; print(os.getsid(int(sys.argv[1])))'` — macOS `ps -o sess` prints 0), `diff_scoped` (the OWN-3 diff, restricted to target ∪ {R} per D-8/D-29).
- Arms: N1-N4, S1-S8 (`03-test.md` §1-2), **S9** (P2), I1-I3 (P2), plus arm **G** = the three deletion/family predicates of §3 G-DELETE. Per-arm denominators fixed in the script.
- RED expectation, recorded verbatim in the build log: **I1, I2, I3 FAIL** (they exercise the *current* runner, which reaps on none of the three paths); every arm that calls `treekill` **SKIPs loudly with a named reason** (D-13: skip when absent, red when present-and-wrong); arm G FAILs (`killpg` is still at `:1554`). Script exits 1.
- Wire into `build.zig` in the same commit, `test_step.dependOn`, following the `orphan_reaper_regression` block (`build.zig:303-305`), with the same comment-block convention.
- **Measure S4's wall in B1 and report it.** If S4's ≥20 iterations exceed 60 s, S4 moves to its own explicit step (`b.step("treekill-race", …)`, the `battery-sweep` pattern at `build.zig:1180-1186`) and `zig build test` keeps every other arm. Stated as a rule, not a silent cap — a moved arm is announced in the build log with its wall.

### B2 — the verb core: read-only, signals nothing

One new region in `src/managent/main.zig`, fenced by two sentinel comments that the
family-independence predicate needs (D-2):
`// ── treekill: process-tree ownership (pass 1) ─────` … `// ── end treekill ─────`.

Names: `cmdTreekill`, `OwnOpts` + `parseOwnArgs`, `ProcRow { pid, ppid, pgid, sid, start_epoch, rss_kb, comm }`,
`readProcTable`, `readPsFixture`, `getsid` (extern), `closeOwnership`, `validateOwnership`,
`printOwnRecord`, `printOwnSummary`.

Dispatch placement — load-bearing, not cosmetic. `treekill` short-circuits in `main` **after**
`findRepoRoot` (it needs the repo root for G6's `untracked/runs/`) and **before** the
lock-migrate-write block at `src/managent/main.zig:387-407`, on the `models`
short-circuit precedent (`:333-336`). It must never take the kanban flock and never
migrate the store: it runs on **every** runner exit path, and putting `lockStore` on
every dispatch's exit adds a contention surface the pass exists to remove, while
`MANAGENT_TEST=1` would refuse the call outright. **Do not add `treekill` to `mutating_verbs`
(`:218-223`)** — it writes no state. Add one `printHelp` line (`managent treekill --anchor <pid> [--kill] …`).

Order inside B2 — each sub-step ends with its arm green:

1. **Spike `getsid` first** (~20 lines): `extern "c" fn getsid(pid: std.c.pid_t) std.c.pid_t;`, compile and call it. If it does not link on this target, stop and choose the fallback *before* the closure is written (see risk R9). Cheapest possible early failure.
2. Arg parse + usage errors → exit 2 (missing/non-decimal `--anchor`; `--kill --ps-fixture`, G9).
3. `readProcTable` via the existing `runCommand` (`:8731`) over `ps -axo pid=,ppid=,pgid=,uid=,lstart=,rss=,comm=`, plus `getsid(2)` per candidate. `runCommand` returns stdout and never inspects `term` — so `readProcTable` checks the row count itself and **exits 3 loudly** on a degenerate read (D-31: an empty table otherwise yields "converged, claimed=0", the verb's most dangerous silent success). Start-time parsing per OQ4: `lstart` embeds spaces, so parse it positionally to an epoch; `etime` is the fallback if the parse proves fragile.
4. `readPsFixture` with the extended schema **including a `sid` column** (D-37), fixture mode implies read-only.
5. `closeOwnership` — the fixpoint, with the **downward constraint** as an admission predicate, not an afterthought: a candidate P is admitted iff (a) P's ppid-chain over the current snapshot reaches a member or the anchor, or (b) P ∈ seed, or (c) `sid(P) ∈ {anchor} ∪ {pid of a claimed member that is a session leader}` **and** P's ppid-chain terminates in a member, the anchor, or pid 1 (the reparented case) — and in every case `start_epoch(P) ≥ since` (G4). Any candidate that is an ancestor of the anchor, the anchor's own session leader (unless it *is* the anchor), or a sibling of the anchor is **rejected, not followed** (D-19). Read-only mode stops here.
6. Guards that need no signal: G0 (the "refused-everything" list, `01-spec.md:265-269`), G1 (anchor > 1, same-uid), G3 (self / ancestor chain / own session leader), G4 (the floor), G8 (cross-uid **pre-filter**, excluded-and-counted, never an EPERM round trip — D-34, and D-25's two semantics kept apart).
7. Output: tab-separated record per claimed pid on **stdout**, the `treekill anchor=… claimed=… killed=… refused=… survivors=… rounds=…` summary line always last on stdout, `[treekill]`-prefixed diagnostics on **stderr**. `action ∈ {report, killed, vanished, refused, survived, protected}` (no `frozen`, P1).

**B2 gate:** N1, N3, S6, S7, S9's read-only half green; nothing in the tree has been
signaled by any arm. No signal code exists yet, so "read-only is inert" is true by
construction at this point, which is the cheapest possible proof of D-20.

### B3 — freeze, guards, kill, verify

1. `freezeFrontier` — SIGSTOP the frontier, **`--kill` only** (D-20). Then the completion oracle (D-30): poll `ps -o state=` until every frozen pid reads `T` or has vanished, bounded by `settle_ms`; still-unstopped after the bound → exit 3, never a silent proceed. SIGSTOP returns before the target stops and the verb is not the parent, so without this the bounded race is a claim, not a measurement.
2. `validateOwnership` — the atomic pre-flight over the **whole** closure (G5), including the protected set (G6): read `untracked/runs/*.json`, take the **`pgid` field** (the anchor pid, `tools/runner:1302`) of every *other* row (D-3), where "in-progress" = the record has no finalize field (`exit`/`signal`/`wall`) **and** its `pid` (the runner) is alive **and** that pid's actual start time matches the record's `start_epoch`. That last clause is the expiry D-32 asks for and it needs no arbitrary TTL: a SIGKILLed runner's permanently-unfinalized record stops protecting as soon as its pid is gone or recycled. Intersection ⇒ exit 4 naming the task id.
3. `resumeFrozen` — SIGCONT every frozen pid on **every** non-kill exit (refusal, exit 3, error). G7's rollback is mandatory because freezing precedes validation by necessity.
4. `killMembers` — SIGKILL every member (delivered to stopped processes; no SIGCONT needed).
5. `verifyClosure` — sleep `settle_ms`, re-snapshot, recompute the closure from the claimed set including the sid keys of every claimed leader (OWN-5); survivors → another round if the shared budget remains (P3.2), else exit 5 with each survivor printed `action=survived`.

**B3 gate:** N2, N4, S1-S5, S8, S9 green, each against its independent `ps` oracle, **and**
the four instrument mutations each fail their arm (§3 G-GREEN). I1-I3 are still red — no
call site is wired yet.

### B4 — the call sites: C1, C2, C3, C4, C6

All in `tools/runner`. One helper first, then five edits:

- `_reap_tree(anchor, seed=(), since=None, protect=())`, placed next to `_descendant_pids_ps` (`:609`). **Non-raising by contract** (D-24): it catches every exception, returns `{"claimed": n, "survivors": n, "ok": bool, "reason": str}`, logs one `[runner]` line to stderr from the verb's summary line, and never propagates. It shells `$MANAGENT_BIN` → `zig-out/bin/managent` → `bin/managent` with `treekill --anchor … --kill …` under `subprocess.run(..., timeout=30)` — a hung verb must not hang the runner's exit.
- **Seed persistence** (D-11/D-35): initialize `last_poll_pids = []` before the poll loop (near `:1340`) and assign it from `pids` right after `pids = _WALKER_FN(proc.pid)` at `:1402`. A run whose child exits before the first RSS poll (loop breaks at `:1349-1358`) seeds empty and the sid term alone carries the closure — `_reap_tree` logs `seed=0` so the ledger shows which case it was.
- **`spawn_epoch`** (P3.1): captured immediately before the `Popen` at `:1290`, written into the launch record at `:1301-1305`.
- **C1** (`:1554`): delete `os.killpg(proc.pid, signal.SIGKILL)`; call `_reap_tree(proc.pid, seed=last_poll_pids, since=spawn_epoch)`. Keep `proc.wait(timeout=2.0)` at `:1558` (it reaps the zombie). The `SIGKILL pgid` diagnostic at `:1552` becomes the verb's summary line. Note what this also fixes: today's `except ProcessLookupError` does **not** catch the `PermissionError: [Errno 1]` that killed `tools/runner` itself four times in ollama lanes (`docs/evidence/orcha-pass1-perfamily-topology/ollama-family.md` §Evidence 3, and `OWNER-LOG.md` on the tournament's qwen lane) — a non-raising helper closes that crash class as a side effect.
- **C4** (`:1481`): `_reap_tree(largest_pid, since=spawn_epoch)` — **no seed**. The seed list is the whole run's descendant set; passing it to a surgical single-member cull is exactly the widening D-19 forbids. The downward constraint confines the closure to `largest_pid`'s subtree. The `if largest_pid == proc.pid` branch at `:1471` is untouched (it escalates into the exit-124 route, which is C1).
- **C2**: **outside** the try (D-24) — after the `finally:` block ends at `:1595` and before `_capture_tokens` at `:1604`, so memory is released before the token parse. `ret = proc.wait()` stays at `:1587` inside the try. (`_reap_tree` is non-raising, so both placements are safe; the outside placement is the one the disposition names and it costs nothing.)
- **C3** (`:1588-1592`): `_reap_tree(proc.pid, seed=last_poll_pids, since=spawn_epoch)` **before** `_finalize_run_record` at `:1591`, so the record carries the reap outcome, then `raise`.
- **C6**: extend `_finalize_run_record` (`:398`) with `reap_claimed` / `reap_survivors` / `reap_ok` keyword arguments; pass them at `:1580` (ceiling), `:1591` (exception) and `:1622`/`:1626` (normal). Old records lack the fields; readers `.get`.

**B4 gate:** I1, I2, I3 go green; every B2/B3 arm stays green; `zig build test` shows no
new failure elsewhere.

### B5 — deletion, mechanized (arm G)

Three predicates, in the regression script **and** in the build row's kanban acceptance
command (D-38 — a grep whose result a human interprets is prose):

```sh
[ "$(grep -c 'killpg' tools/runner)" -eq 0 ]                                    # C1 deleted
[ "$(grep -c '_WALKER_FN' tools/runner)" -eq 3 ] &&
  ! grep '_WALKER_FN' tools/runner | grep -qE 'kill|SIGKILL|managent treekill'        # C5 is RSS/seed only
awk '/^\/\/ ── treekill: process-tree ownership/,/^\/\/ ── end treekill/' src/managent/main.zig |
  grep -qiE 'claude|deepseek|ollama|qwen|glm|minimax|kimi' && exit 1 || true     # §7.1, scoped (D-2)
```

The `_WALKER_FN` count (docstring `:641`, assignment `:647`, call `:1402`) is pinned, so
any new use is a deliberate edit that fails the gate until the count is updated with a
reason. The third predicate is why B2 emits the two sentinel comments: `grep` over the
whole 8,780-line file **cannot pass** — `src/managent/main.zig:116-125` is the
recognized-models table (D-2).

### B6 — green, hand-trace, hand-off

`zig build deploy-managent`, then `sh tools/regression-process-ownership.sh` with the
fleet quiet (§2). Green is claimed only under §3 G-GREEN. Then: one hand-traced
end-to-end reap (one pid, spawn → claim → freeze → kill → verified dead) written into
the phase-7 build log, and the G-REIMPL brief dispatched (§3).

---

## 2. Parallelism and isolation

**Isolation policy:** `LADDER.md` §"Isolation policy per phase type" (operator ruling
2026-08-20) — document phases parallel in the main tree, one unique output file per lane,
lanes read nothing else in the directory; build/test phases worktree-per-lane **or**
strictly serialized in the main tree. Phase 7 takes the serial branch, for a reason
specific to this pass:

**A worktree does not isolate the process table.** The shared mutable resource here is
not the checkout, it is the host's pid space and its memory. Two lanes running the
ownership arms in two worktrees would spawn and SIGKILL trees against one `ps`, read each
other's members in their diffs, and both report green while lying. So: **B1-B6 are one
lane, one writer per file, no concurrent build/test lane on this host.**

| may run concurrently | must be serial |
|---|---|
| the `01-spec.md` correction pass (P1) — different file, different owner | every step B1-B6, in order |
| this plan's review gate; the D-33 claude evidence probe (P4) | any `zig build test` / `zig build deploy-managent` on this host |
| the G-REIMPL lane's *writing* (it needs the corrected spec §3 and the fixture corpus, not the Zig) | the RED run (B1) and the GREEN run (B6), which read the live process table |
| unrelated document rows elsewhere in the fleet | — |

**Single-writer files for the whole of phase 7:** `src/managent/main.zig`,
`tools/runner`, `build.zig`, `tools/regression-process-ownership.sh`. All four are clean
in the working tree today; the builder holds them for the duration and no other row may
be dispatched against them.

**Fleet quiet for the RED and GREEN runs, an operator-visible scheduling ask.** The arms
read the process table; a hot fleet makes N2/S1/S4/S9 flaky. The scoped diffs
(D-8/D-29) and fabricated records (D-26) contain most of it, but the `T`-state and
"caller alive" assertions still read shared state. Ask for a quiet host for the two runs
that matter, and record the host state alongside each result.

---

## 3. Gates

| gate | when | instrument | pass condition |
|---|---|---|---|
| **G-RED** | end of B1 | the control script against the *current* tree | I1, I2, I3 **FAIL**; arm G FAILs; every `treekill`-calling arm SKIPs with a named reason; script exits 1; the whole output pasted into the phase-7 build log. Without this recording the later green means nothing (standing rule: never trust a green test) |
| **G-GREEN** | end of B4 | every arm + its independent `ps` oracle | every arm passes **and** the verb's counters agree with the oracle (a disagreement is a FAIL, not a rounding note — impossibly clean counters are red flags); the four instrument mutations each fail their arm: freeze disabled ⇒ S4 fails, start-time filter disabled ⇒ S7 fails, protected-set check disabled ⇒ S8 fails, rollback disabled ⇒ S8's running-again clause fails; plus one hand-traced end-to-end reap in the build log |
| **G-DELETE** | end of B5 | the three predicates of B5 | all three exit 0, in the script and in the kanban acceptance command |
| **G-REIMPL** | after B6 | independent re-implementation, **different model**, different language (`LADDER.md` phase 7) | see below |
| (phase 8/9, named not owned here) | after phase 7 | `zig build test`, `tools/suite-truth.sh`, claimlint, numbers audit | out of this plan's scope |

**G-REIMPL, concretely.** A model that is neither this builder nor the spec consolidator
writes `tools/treekill_oracle.py` — the **core closure only**: the fixpoint, the downward
constraint (D-19), the start-time floor (G4). Never the signalling. From the corrected
`01-spec.md` §3 alone; it must not read the Zig. Language: **Python**, and not as a
consolation prize for Kotlin — `tools/runner`'s `_descendant_pids_ps` (`:609`) is already
the working Python half of this primitive, so the re-implementation extends existing
production code into a full closure and then *stays* as arm S6's oracle. Duplication is
the oracle: `treekill_oracle.py` is kept as a fixture, demoted, never deleted, never a kill
path. It is an instrument only if it can find a defect: run it against the whole
`--ps-fixture` corpus **and** against ≥3 live seeded trees, and adjudicate every
disagreement by hand before either side is called correct.

**What is *not* a gate here: the #2 self-consistency auditor.** That gate is the *engine*
gate — the finisher / memo / ko-engine pre-commit check
(`docs/infra/tool-consolidation/01-strategy.md:181`, precedent 4, the `ko_ref >= d`
lesson of ADR-0013). `managent treekill` computes no game value and has no second engine to
be self-consistent with; its analogue is exactly G-REIMPL above. Stated so nobody adds a
ceremonial gate to a `tools/runner` + `managent` row — and so nobody argues the row is
ungated because that one is absent.

---

## 4. Effort and risks

### Effort

| step | scope | estimate |
|---|---|---|
| B1 | ~500-650 lines of shell: 15 arms + generator + 4 oracle helpers + `build.zig` hunk | 3-4 h |
| B2 | ~700-900 lines of Zig: parse, ps/fixture readers, `getsid`, the fixpoint, 5 guards, output | 4-5 h |
| B3 | ~300 lines of Zig: freeze + oracle, pre-flight, protected set, rollback, kill, verify | 3-4 h |
| B4 | ~120 lines of Python across 7 edits in `tools/runner` | 1.5-2 h |
| B5 | 3 predicates + the kanban acceptance command | 0.5 h |
| B6 | green run, hand-trace, build log, G-REIMPL brief | 1-2 h |
| **total (serial, one lane)** | | **~14-18 seat-hours** |
| G-REIMPL lane | `tools/treekill_oracle.py` + differential run | 2-3 h, parallel |

Wall for one green run: S4 alone is ≥20 × (spawn + reap + settle) ≈ 60-90 s; whole-script
target < 5 min. Measured in B1, reported, and the B1 decision rule applies if it misses.

### Risks

| # | risk | mitigation |
|---|---|---|
| R1 | **The D-19 downward constraint is both the load-bearing correctness property and the hardest to control.** Too restrictive ⇒ silent under-claiming (a leak reported clean); too loose ⇒ C4 kills the whole run. `03-test.md` has only the under-claiming side | **S9** (P2) is the over-reach control; both sides must be green before B4 wires C4 |
| R2 | The freeze is `--kill`-gated (D-20), so a read-only report is a snapshot under churn, not a stable set | N3 asserts inertness, never set-stability across two read-only runs |
| R3 | **ollama residency is not closed by the verb.** The model runs under `ollama serve`, a sibling of the dispatched tree (phase-4 record); `treekill` will honestly report a small `claimed` while gigabytes stay resident. `ollama stop` is a **Could** | if cut, the accept doc says so in words — a green suite must not imply the ollama leak closed. The `killpg` **crash** class is closed regardless (C1/C4) |
| R4 | Post-spawn pid reuse is residue, not closed (D-1) | never phrase any result as "no orphans"; the accept doc carries r4 and pid-reuse as stated unknowns (OQ2) |
| R5 | Host-wide process-table contention makes arms flaky | scoped diffs (D-8/D-29), fabricated records (D-26), quiet fleet for RED and GREEN (§2), host state recorded per run |
| R6 | Wiring the script into `zig build test` lengthens a suite that has historically run 52 min with 7 crashes | B1 measures S4's wall; the announced move to an explicit step if it exceeds 60 s |
| R7 | `treekill` now runs on **every** runner exit: one extra process spawn, a repo-root find, and one-plus `ps` scans per dispatch exit | the `models`-precedent dispatch placement (no flock, no migrate), the 30 s `subprocess.run` timeout, and a measured exit-path cost reported in the build log — if the verb becomes the slowest step of a dispatch's exit, say so rather than absorbing it |
| R8 | P1 is the single serialization point: if the correction pass slips, B2 cannot start | B1 is written from `03-test.md` meanwhile; the P1 errata table lets B2 start against the disposition if the operator rules the text non-blocking |
| R9 | `extern "c" fn getsid` may not link on this target (`getsid` is absent from zig 0.16's `c.zig`/`posix.zig` — present only in the Linux backend, D-4) | the B2.1 spike, before the closure exists. Fallbacks, in order: `sysctl(KERN_PROC_ALL)` with a hand-written `kinfo_proc` layout (OQ3's cost note), or — read-only mode only, never in the kill path — a `python3 -c os.getsid` shell-out, which costs a process per candidate and is therefore not acceptable where it matters |
| R10 | `readPsFixture` cannot carry live sids, so fixture-mode coverage of the sid edge is synthetic (D-37) | the fixture schema's `sid` column tests the *parser and predicate*; the edge itself is proven only by S2/S3 on live trees. Said plainly, not blurred |

---

## 5. Cut order if the pass must slim

Mirrors `02-scope.md` §6, with the phase-7 consequence of each cut spelled out:

1. **ollama `ollama stop` (Could).** The compile-family harm — the measured 2026-08-20 leak — still closes; ollama model residency does not, and the accept doc must say so.
2. **C6 run-record reap fields.** The reap becomes invisible to T548 and a host cull stays indistinguishable from a model failure in the ledger — the pass's *stated* harm. Severable, but cut only under real pressure.
3. **Should-tier edges, in this order:** D-39 (`--rounds` budget → S4 keeps a fixed wall, no reasoned bound) · D-41 (already free: `frozen` is dropped, no work to cut) · D-40 (exit 3 → internal failures read as exit 1, and controls lose the refused/broken distinction) · D-30 (freeze completion oracle → S4 becomes advisory, the bounded race becomes a claim again) · **D-31 last** (loud `runCommand` failure — cutting it restores the silent-success path where an empty `ps` reads as "converged, claimed=0").

**Never cut:** the four criticals (D-1, D-19, D-20, D-21), the verb, the guards, C1-C4,
the control script, **G-RED**, and **G-REIMPL**. A pass that ships the verb without the
red recording or the independent re-implementation has shipped an unmeasured instrument,
which is the failure mode this ladder exists to prevent.

---

## 6. What phase 7 does not touch

`managent reap` (the T364 kanban verb), `tools/regression-orphan-reaper.sh`, and the
`mutating_verbs` list · `bin/dispatch:301`'s `start_new_session=True` · runner death
(T548's sweep) · the one-dispatch-interface command (later pass; §7 constrains shape
only) · zig's spawn behaviour · any engine source. `01-spec.md` §8 is the full list.
