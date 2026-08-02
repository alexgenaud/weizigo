# Grand Audit arm: infrastructure and tooling

Role: audit arm (subagent of Grand Auditor) · Model: Claude Fable 5 (subagent instance) ·
Date: 2026-08-02 · At HEAD `e714fd4`. Raw findings, unedited; synthesis in `GRAND-AUDIT.md`.

## (a) Confirmed defects

**D1 — `ephemeral` is a plain empty directory, not the prescribed symlink.** AGENTS.md:187-190 prescribes `ln -s /tmp/weizigo ephemeral`; on disk `/Users/alex/Project/Zig/weizigo/ephemeral` is a real empty directory (`file ephemeral` → "directory", created Aug 1 02:10). Anything written "to ephemeral" lands inside the repo, defeating the disposable/durable split the B44 evidence-loss postmortem created.

**D2 — claimlint is RED at HEAD, on a commit titled "shut down clean".** `./bin/weizigo-claimlint` exits **1** at e714fd4 (clean tree): C1a=10 orphans, **C2=14 dangling evidence paths** (recorded honest-debt floor was 12 — debt grew by 2), C7=4 unabsorbed findings. The failure is real, not a stale binary: `zig-out/bin/weizigo-claimlint` (built Aug 2 03:53) produces byte-identical stdout.

**D3 — C7 unabsorbed findings include a permanent, by-design failure.** `findings/T264-version-stamping.json` proposes claims `T264-V1..V3` that were never added to CLAIMS.md (register says "NO SUCH ID") even though T264 is closed `pass` and commit f92e297 "absorbed the session". Worse: `T212-wzo2-rebuild.json` says `WZO2-4X4-VALID` PROVEN while the register deliberately recorded it FALSE-AS-SCOPED (f92e297: "T212's proposal, recorded and REFUTED"). Findings files are immutable (findings/README.md:12-14) and C7 has no "absorbed-with-rejection" state — so a correctly refuted finding fails C7 forever. Schema gap.

**D4 — stale/misnamed binaries at repo root.** `./managent` (2.8 MB, Jul 30) is a pre-T264 build with no version stamp that still runs and writes the same `tasks.json` (it walks up for `.git`) — a stale-binary hazard four days behind `bin/managent`. `./gtp` (3.3 MB, Jul 31) is actually a **weizigo-oracle** binary (`./gtp --version` → "weizigo-oracle: cannot load artifact"), misnamed and superseded by T263's `bin/weizigo-gtp`. Both gitignored but sitting on `$PATH`-adjacent ground.

**D5 — `bin/` binary drift, proven by the version stamp itself.** `bin/weizigo-claimlint` (built 02:35, 2.7 MB — looks like a Debug build) is **older than src/claimlint.zig (02:49)** and prints **no version banner**, while `zig-out/bin/weizigo-claimlint` does (`weizigo-claimlint 626ec55-dirty …`). `bin/weizigo-absorb --version` prints only usage; `bin/weizigo-oracle` treats `--version` as an artifact path; `bin/weizigo-arena`/`-chainability`/`-engine-vs-engine`/`-reachcensus` date from Jul 27-28. T264's finding "All 10 tools print version stamp" is true only of fresh `zig-out` builds, not the shipped `bin/`. `managent audit` has a staleness check for exactly one tool (`zig-out/bin/managent` newer than `bin/managent` → cp it, spec.md:512) — the other nine have no guard, and claimlint proves the gap. Also `bin/weizigo-oracle.dSYM/` debris.

**D6 — every stamped binary says `-dirty`.** `managent`, `weizigo-gtp`, fresh claimlint all report `626ec55-dirty` — built from an uncommitted tree, so the stamp cannot reconstruct the source. The stamping mechanism (tools/gen-version.sh — sha, dirty flag, date, zig version) **works as designed**; the build discipline around it doesn't. Note also `git diff --quiet` in gen-version.sh ignores staged-but-uncommitted and untracked files (no `--cached` check), so some dirty states stamp as clean.

**D7 — two runner docs, and AGENTS.md points at the stale one.** AGENTS.md:85 says "the runner is `docs/infra/runner.md`"; that file still describes the pre-T214 design ("three ceilings, all default-on", no mention of the progress watchdog). The current doc is `docs/infra/host/runner.md` (updated 2026-08-01, T214). Direct violation of the "one canonical unsuffixed doc per phase" doctrine.

**D8 — runner doc contradicts runner code on the safety-critical guard.** docs/infra/host/runner.md:18-20 claims the runner "**sums RSS across all descendants**". The code (tools/runner:649-674) checks **per-PID** RSS only — `if args.rss_cap_mb and rss > cap_bytes` per member; nothing is ever summed. Eight children at 3.9 GB each (32 GB total) pass the guard. The 2026-07-29 incident was a single 12.5 GB process, so the guard fits the precedent, but the doc promises more than the code delivers.

**D9 — managent `--help` omits five implemented commands.** `verdict`, `reopen`, `purge`, `set`, `needs` exist (probed: `managent verdict` and `managent reopen` print usage) and are in spec.md:26-29, but none appear in `--help`. Conversely `suggest`, `tell`, `inbox`, `ping`, `liveness` are in `--help` but absent from spec.md's "Eighteen commands" interface block (which itself lists 19). Spec, help, and binary are three different command sets.

**D10 — 18 of 46 registered tasks have vanished bundle files**, including three in `/tmp` (T240 `/tmp/T227-test-bundle.md`, T247, T248 — direct violations of the untracked/ vs /tmp doctrine, AGENTS.md:174-185). All 18 are `done`, so no operational block, but the kanban's `follow <bundle>` lines are dead links and `managent audit` has **no missing-bundle check**.

**D11 — spec.md regression contract broken by the banner.** spec.md:52-53: "`status 1>/dev/null` is silent on a clean run." Observed: the version banner prints to stderr on every invocation. Trivial, but it's a stated regression check that now fails.

## (b) Systemic weaknesses

**W1 — runner guard escape routes.** (i) Descendants found by ppid-walk (tools/runner:361-382); a daemonizing child reparents to PID 1 and escapes both RSS monitoring and the `killpg` (line 724). (ii) The child is its own session leader (line 540); a grandchild calling `setsid` leaves the process group and survives the SIGKILL. (iii) `prepend_releasefast` (lines 251-275) only rewrites a literal `zig` argv[0]; `sh -c "zig build-exe …"` or a Makefile spawns Debug zig unguarded (RSS cap still applies; the ReleaseFast discipline silently doesn't). (iv) `--rss-cap-mb 0` disables the one "safety-critical, always on" guard with no ceremony. (v) The `"/proc" in str(e)` NOPROC heuristic (lines 409-416) is always true for a missing `/proc/<pid>/status`, so the code's claimed dead-pid/no-proc distinction doesn't exist — harmless on darwin, misleading comment.

**W2 — runner↔managent integration is fragile.** With `--task-id`, agent attribution comes from `PI_MODEL` env defaulting to `"unknown"` (line 569); managent's attribution enforcement then **refuses `done` for unknown agents**, so the auto-done at line 759 fails after a successful run → exit 1 on green work. Exit 124 is also overloaded: guard kill (line 739) and pending pause/kill directive (line 565) are indistinguishable to callers.

**W3 — `managent audit` exits 0 with 62 findings.** All WARN-level: ~30 done tasks with no `acceptance=` ("no runnable green condition") and ~25 with deliverables cited nowhere; T259 closed `fail-found` naming no follow-up task ("finding may be lost"). Per spec this is correct behavior (FIX-only gating), but the WARN tier has accumulated into a swamp nothing drains — the T227 saga alone left 15 abandoned tasks (T228-T251) as permanent WARN noise. `purge` exists precisely for this and hasn't been run.

**W4 — the claimlint gate isn't wired to anything.** It exits 1 today and the session still "shut down clean" (e714fd4). Nothing (pre-commit hook, CI, audit FIX-level finding) forces the red state to block anything; the honest-debt floor (C2 12→14) grows unenforced.

**W5 — `log/` accretes at repo root**: 229 GTP/Sabaki logs (gitignored). By the project's own doctrine these are disposable outputs that belong in `/tmp/weizigo/` — and they'd be there if D1's symlink existed.

**W6 — tracked root cruft**: `msg_from_glm.md` / `msg_from_opus.md` are Jul-28 "MOVED" tombstones ("may be deleted once GLM has read 003") still tracked in git; `tools/t265_diagnostic.zig` is a tracked one-off diagnostic parked in `tools/` next to operational scripts.

## (c) Genuine strengths

**S1 — artifact integrity is perfect.** `shasum -a 256 -c artifacts/SHA256SUMS`: **all 10 OK**, including the 258 MB `data/` checkpoints and the untracked oracle-v2 wzo2 (0c3366f0… matches the handover memory). The "no silent writes" rule is being honored — `data/` contains exactly the three hashed .wzo files plus a baseline dir, nothing unhashed.

**S2 — register↔git coherence is real.** tasks.json (46 tasks: 40 done, 6 dispatchable, 0 stuck in_progress/blocked, no done-without-verdict, no done-without-agent) matches git history precisely: T264 closed at 4a598b1, T265 at 626ec55/77083f4, T266-T270 *registered* (not closed) at e714fd4 and correctly shown dispatchable. Statuses and commit messages tell the same story.

**S3 — claimlint is a serious instrument.** It implements everything the docs claim and more: C0 parse (282/282 rows, 0 unparsed), C1a/C1b orphan detection with negation-edge semantics, C2-C7, narrowing smells, weak-evidence reporting — and a **built-in calibration battery** (6 known-bad seeded defects, all CAUGHT; known-goods SILENT) that runs on every invocation. This is the "never trust a green test" doctrine executed in code. C7 genuinely gates on `findings/*.json` as findings/README.md:96-98 claims.

**S4 — the findings pipeline is coherent** — schema documented, 37 well-formed JSON files, immutability rule stated, `weizigo-absorb` closes the loop — modulo the D3 absorbed-with-rejection gap.

**S5 — version stamping (T264) fundamentally works**: fresh builds of all tools print `<tool> <sha>[-dirty] built <date> zig <ver>`; the `-dirty` flag correctly exposed that every current binary came from an uncommitted tree — the instrument catching exactly what it was built to catch.

**S6 — the runner's core promise holds**: default 4 GB cap (tools/runner:479), per-poll check (line 670), SIGKILL of the process group (line 724), exit 124, heartbeat on every exit path including guard kills — plus honest fallback tiers for silent children. The design writeup in the file header is exemplary.
