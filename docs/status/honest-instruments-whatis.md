# Honest instruments — what this repository does today

**Task:** T858 · **Worker:** deepseek-v4-pro/T858 · **Date:** 2026-08-24 ·
**Landmark:** advances L1 (the dashboard tells the truth) — the baseline that has to come down.

**Mandate:** describe, do not judge, do not fix. Every mechanism carries a `file:line`
citation, verified to resolve. Where a surface reports a value, this records exactly what it
emits when it has no data. Where a check exists, this records what would have to break for it
to fail — including "nothing". Where two mechanisms do the same job, both are named. Where the
purpose of a mechanism cannot be established from evidence, it is written UNKNOWN.

**Scope of this file:** the property under study is *honest instruments* — every reading is
known, unknown, or refused, and unrecognised input is refused rather than reinterpreted. The six
counts at the end are the baseline measurement for this whole scope.

---

## §1 Reporting surfaces — what each emits when it has no data

"Reporting surface" = anything a human or script reads a value from. Grouped by owner. Line
references are to the committed source, not to the compiled `bin/` binaries (which are build
artifacts and git-ignored).

### 1.1 The kanban CLI (`src/managent/main.zig`, one file)

| surface | the line that decides | what it emits with no data |
|---|---|---|
| `managent status` (text) — section rows | `printSection` `src/managent/main.zig:6102`, empty branch at `:6105` | `-- none --` (explicit, not a zero) |
| `managent status --json` — `printStatusJson` | `src/managent/main.zig:6140` | a JSON array; an empty store is `[]` (empty array is the no-data form) |
| `managent orient` — claimlint counts | `src/managent/main.zig:6993` (unavailable) and `:6996` (per-count `?`) | binary absent/not run → `claimlint: unavailable (… not built …)`; a count the parser could not extract → `C1a=?` (an explicit unknown marker) |
| `managent orient` — floor counts | `readResumeFloor` `src/managent/main.zig:6325`, struct default at `:6318` | file absent/unparseable → `floor: tools/hooks/claimlint-floor.json unreadable`; **but a floor that parses yet is missing a key emits `0` for that key** — see §3 |
| `managent orient` — lanes census | `scanLanes` called at `src/managent/main.zig:7010` | if `scanLanes` errors, the whole `lanes:` line is **silently omitted** (the `catch null` at `:7010`) — no "unknown" line |
| `managent orient` — in-progress liveness label | `src/managent/main.zig:7035` | heartbeat absent → `UNKNOWN`; present but unparseable timestamp → `?`; present+stale → `stalled`; present+fresh → `beating` |
| `managent orient` — fresh activity | `src/managent/main.zig:7070` | empty `git log` → `-- no commits yet --` |
| `managent liveness` | `src/managent/main.zig:11482` (beating), `:11486`/`:11488` (beats stopped), `:11492` (unparseable ts), `:11505`/`:11507` (UNKNOWN), `:11512` (no tasks) | three honest states plus `UNKNOWN — no assertion` for a row with no heartbeat, and `-- no in_progress tasks --`; the `wall/cpu/rss` line is printed only when `hb.wall > 0` (`src/managent/main.zig:11499`), so an absent or zero reading is omitted, not marked |
| `managent lanes` | `src/managent/main.zig:11321` | counts are always printed; the reverse scan (done rows whose findings never landed) skips a row silently when its bundle cannot be parsed — `parseDeliverablesFromBundle(…) catch continue` at `src/managent/main.zig:11298` |
| `managent status` unmet-dependency warnings | `src/managent/main.zig:6057` | only printed when some in-progress row has unmet needs; otherwise nothing (a genuine "none" is silence, not a stated none) |
| `managent reap` (report-only) | `src/managent/main.zig:11533` | lists orphans; an empty result is not given an explicit "none" line in the report path |

The two output writers themselves: `Writers.data` `src/managent/main.zig:47` and `util.out`
`src/util.zig:39` both swallow write and allocation errors with `catch {}` / `catch return`.
A surface whose write fails emits **nothing**, with no error on either stream — the reader
cannot distinguish "no data" from "the writer failed".

### 1.2 `weizigo-claimlint` (`src/claimlint.zig`)

| surface | the line that decides | what it emits with no data |
|---|---|---|
| the verify report (C0/C1/C2/C6/… sections) | `runVerify` `src/claimlint.zig:1704`; `(none)` for C1a at `:1785` | each check prints `(none)` when it found nothing; the C0 parse section prints `rows UNPARSED: N` and fails hard if the register parsed 0 rows — `src/claimlint.zig:1720` |
| the calibration line (five named cases) | `src/claimlint.zig:128` (comment) and the calibration runner | five named cases must be caught/silent; a calibration failure exits non-zero on its own (exit code 2 — `src/claimlint.zig:135`) |
| `claimlint c7 --json` | `runC7` via `src/claimlint.zig:1661` | per-file JSON objects; the `--findings-scope-file` variant scopes to a named file list |

### 1.3 The commit gate (`tools/hooks/pre-commit`)

| surface | the line that decides | what it emits with no data |
|---|---|---|
| gate summary line | `tools/hooks/pre-commit:519` (the `all clear` echo) | prints `claimlint C1a=… C6=… C7-nonconforming=… — ≤ floor, allowed` — each count is an `awk`-extracted token; a missing token is caught by `regression()` at `:315` which blocks with "could not parse current" rather than emitting a zero |
| suite verdict surface | `tools/hooks/pre-commit:422` (the `suite-truth.sh --read-result` call) | a stale/absent result reads `UNKNOWN` (see 1.6), surfaced non-blocking |
| test-gate per-script PASS/FAIL | `tools/hooks/pre-commit:493` | one `PASS`/`FAIL <script>` line per selected pool script; an over-budget-but-passing tier warns rather than fails (`:406`) |

### 1.4 `tools/smoke.sh`

| surface | the line that decides | what it emits with no data |
|---|---|---|
| three functional checks + deploy check | `tools/smoke.sh:23`/`:35`/`:45` (string-match asserts), `:83` (stamp parse) | each check prints `PASS`/`FAIL` by substring match on captured output; a missing/unstamped binary → `FAIL: <tool>: … missing or unstamped` (`tools/smoke.sh:94`); a stale binary prints `STALE: …` and does **not** fail (`tools/smoke.sh:121`) — staleness is "not verified", not "broken" |

### 1.5 `tools/suite-truth.sh` (the full-suite gate)

| surface | the line that decides | what it emits with no data |
|---|---|---|
| reds/surfaces comparison | `tools/suite-truth.sh:519`/`:523` (count mismatches) | a `NEW RED` or `FIXED` line per set difference; **the `steps-failed`/`tests-crashed`/`tests-failed` count comparisons are wrapped in `[ -n "$OBS_…" ]` — when the regex extracts nothing, the comparison is silently skipped**, no "unknown" |
| `--read-result` verdict | `tools/suite-truth.sh:169` (the embedded python) | absent/unreadable → `UNKNOWN` (exit 3); RED stays RED regardless of age; a stale green → `UNKNOWN` (exit 2) |
| evidence-artifact surface | `tools/suite-truth.sh:501` (the `EVIDENCE` loop's `MISSING READING`) | a declared reading that stopped appearing → `MISSING READING: <prefix>`, which reds the gate |

### 1.6 The fleet instruments (`tools/`)

| surface | the line that decides | what it emits with no data |
|---|---|---|
| `tools/request-accounting.py` report | `build_report` `tools/request-accounting.py:397`; `empty-window` branch `:407` | no attempts in window → `EMPTY WINDOW: no dispatch attempts found … not a measured-zero fleet`; an unattributable attempt is `unattributable` + a named reason, never folded into a total (the honesty rule, `tools/request-accounting.py:14`) |
| `tools/token-capture.py` report | `read_pi_session` `tools/token-capture.py:345` | a caller must treat `ok=False` as UNKNOWN, "never 0, never the total" (`:358`); a session with no assistant turns returns None (`:556`) |
| `tools/fleet-keeper.sh` keeper log | `tools/fleet-keeper.sh:169`/`:174` (arg guard); the per-iteration dispatch line | emits `at cap (N/M) — no dispatch` when the fleet is full; an empty candidate set is a no-op line, not a stated zero |
| `bin/argus` (`--mode doctor/sweep/checklist`) | `bin/argus:1875` (argparse `--mode` choices) | findings are only surfaced when run; between runs they are silent (the duty `DARGUS` is the only scheduled reader) |
| the live fleet dashboard (the tracked copy is the regression `tools/regression-watch-fleet.sh`; the live script lives in the untracked work area and is therefore **not cited by path here**) | `rate_of` and `freshness_of` helpers, pinned by `tools/regression-watch-fleet.sh` arms | `rate_of` renders `UNKNOWN` for a missing/non-numeric/zero-elapsed reading (never 0); `freshness_of` renders `-` for a missing reading; a failed `managent status --json` falls back to an empty `[]` frame, so a store that cannot be read renders as an empty dashboard rather than "unreadable" |

### 1.7 The engine surfaces

| surface | the line that decides | what it emits with no data |
|---|---|---|
| `weizigo-gtp` / `weizigo-oracle` GTP replies | `src/gtp.zig:1846` and `:2104` (`unknown command`), `:2089` (`no goban loaded`) | an unrecognised GTP command → `unknown command`; a command before `boardsize` → `no goban loaded — use boardsize N to load an artifact` |
| engine progress/heartbeats | `src/util.zig:39` (`out`) and `:49` (`note`) | engine data goes to stdout via `out`, diagnostics to stderr via `note`; both swallow write errors (see 1.1) |

---

## §2 Checks — what would have to break for each to fail

"Check" = something that must go red to catch a defect, or that reports pass/fail/verdict.
For each: the failure condition, and — where the answer is "nothing" — that stated plainly.

| check | failure condition | cannot fail? |
|---|---|---|
| claimlint calibration (5 named cases: 3 known-bad must be caught, 2 known-good must stay silent) | a known-bad case goes uncaught, or a known-good case is flagged | no — the calibration runs every verify and exits 2 on its own (`src/claimlint.zig:128`) |
| claimlint C0 "FATAL parsed 0 rows" | the register parses to 0 rows or a wrong-column header (`src/claimlint.zig:1720`) | no — but this is exactly the guard that closes the "empty register reads clean" failure |
| claimlint C1a/C1b/C2/C6/C7/C9/C10/C11/C12 | the respective condition holds for ≥1 register/findings entry | no — each has real-data and/or synthetic-calibration teeth |
| pre-commit claimlint floor gate (`regression()`, `tools/hooks/pre-commit:315`) | any extracted count `> floor`, or a count that cannot be parsed (empty) | no — an empty extraction blocks with "could not parse current", not a pass |
| pre-commit staged-path scope backstop (scope resolved `tools/hooks/pre-commit:100`, refusal `:115`) | a staged path outside the task's declared scope | no (identity-known path); but identity-absent/unresolvable/`--explicit` paths **warn-and-allow** by design (`tools/hooks/pre-commit:141`, `:152`, `:164`) — those arms cannot refuse |
| pre-commit fast test tier (`tools/hooks/pre-commit:385`) | a selected pool script exits non-zero | no; but `TEST_GATE_BYPASS=<reason>` is a designed escape (`:370`), and an empty reason is refused (`:366`) |
| `tools/git-commit-mine` worktree guard | `core.worktree` set, or HEAD below a file-count floor | no — verified red-then-green (see `docs/status/moving-parts-inventory.md` §12) |
| S10 store-loss detector (`checkCensusRead` `src/managent/main.zig:2557`, `checkCensusBeforeWrite`) | the live store's row count is smaller than the committed census | no — but see the fixture false-positive class in §4 |
| `suite-truth.sh` reds comparison | observed failing set ≠ manifest | no for the module/script sets; **yes for the three count comparisons** — `steps-failed`/`tests-crashed`/`tests-failed` are compared only `[ -n "$OBS_…" ]` (`tools/suite-truth.sh:519`/`:523`), so a Build Summary whose format the regex no longer matches makes those three comparisons silently vacuous |
| `tools/smoke.sh` three functional checks | the captured output does not contain the exact success string (`All 3 tests passed` / `All 2 tests passed` / `81/81 agree`) | no — a format drift makes them fail loudly (they assert exact counts), but the `|| true` at `:22`/`:34`/`:44` means the *exit code* of the measured command is discarded and only the substring is believed |
| `managent standing` STANDING-REEVIDENCE trigger | `c3_debt > c3_prior and c3_prior > 0` (`src/managent/main.zig:10503`) | **cannot fire** — `c3_prior` is read from the `_standing` key, and `parseStateJson` skips `_`-prefixed keys when building the state map (`src/managent/main.zig:2727`), so a later `writeStateLocked` re-serializes without it; after any non-`standing` mutation `c3_prior` reads 0 and the `c3_prior > 0` half is false. The code itself documents this sibling defect at `src/managent/main.zig:10691` |
| battery I8 (truncation-gap) | compares two evaluators | **cannot fail** — `checkI8` always returns `.not_applicable` with a note that the real fixture runs externally (`src/vb_fixpoint.zig:391`) |
| battery I11 (move-set consistency) | compares the battery's move set to the solver's | **cannot fail** — `checkI11` always returns `.not_applicable` (GAP-5, dump format unspecified) (`src/vb_fixpoint.zig:474`) |
| battery I3 (L ≤ H) | L > H on a decoded artifact | **cannot run** on WZO1 artifacts — `notApplicableOnWZO1` (`src/vb_common.zig:138`) returns true, so the check reports not-applicable at 2×2/3×2/3×3/4×3 rather than a pass |

Note on the "reported success while measuring nothing" class: the scope this file feeds was opened
after a run of such defects (a regression arm passing because the measured thing was empty rather
than because the property held, and a smoke check whose pipes inverted a pass into a fail). Those
specific instances are recorded in `docs/status/OPEN.md` rows B32/B33 and the T855/T856 findings;
this inventory records the mechanisms as they stand now, including the stub checks above whose
status is honestly "not-applicable" rather than "pass".

---

## §3 Unrecognised input — where it is silently reinterpreted rather than refused

| place | behaviour | citation |
|---|---|---|
| `managent` first argument is a flag | `const cmd = if (args.len >= 2 and !startsWith(args[1], "-")) args[1] else "status"` — an unrecognised leading flag (e.g. `--version`) silently runs `status` | `src/managent/main.zig:1361` |
| `managent done` unknown flags | `--status`/`--note`/… are read via `getFlagValue` which returns null for anything unrecognised; a misspelled or nonexistent flag (e.g. `--verdict`) is silently dropped and the default (`pass`) applies | `getFlagValue` `src/managent/main.zig:3484`; `cmdDone` reads only its known set at `src/managent/main.zig:4651` |
| `managent` unknown *command* | refused with `unknown command: {s}` and exit 1 | `src/managent/main.zig:1522` |
| `claimlint` unknown verb | refused — `unknown verb '{s}'` + usage + exit 1 | `src/claimlint.zig:1681` |
| `claimlint` unknown *flag* to the verify path | silently ignored — `if (startsWith(a, "--")) continue` | `src/claimlint.zig:1697` |
| `bin/dispatch` unknown flag | refused — any unrecognised `--` argument exits with the usage doc (non-zero) | `bin/dispatch:271` |
| `tools/fleet-keeper.sh` unknown argument | refused — `unknown argument` + exit 2, with a special message pointing cooldown verbs at `tools/fleet-cooldown.sh` | `tools/fleet-keeper.sh:169`/`:174` |
| `tools/suite-truth.sh` unknown argument | refused — `unknown argument '…'` + exit 2 | `tools/suite-truth.sh:154` |
| `tools/runner`, `bin/argus`, `tools/token-capture.py`, `tools/request-accounting.py` unknown flags | refused — stdlib `argparse.parse_args` (no `parse_known_args`) exits 2 | `tools/runner:2958`, `bin/argus:1898`, `tools/token-capture.py:773`, `tools/request-accounting.py:489` |
| `managent` attribution when no model is named | falls back to the literal string `unknown` in the identifier (`agentIdentifier`), the documented honest fallback | `src/managent/main.zig:3432` |

---

## §4 Shared jobs — two or more mechanisms doing the same thing

Named, not ranked, not merged.

1. **Model-label canonicalization.** The single source is `canonical_models[]` in
   `src/managent/main.zig` (per the orient principle "one spelling per model"), exposed three ways:
   `managent models` (`src/managent/main.zig:7401`), `managent canonicalize`
   (`src/managent/main.zig:7473`), and `canonicalizeModelTag` used internally. The dispatch/subagent/
   keeper/watch-fleet shells all shell out to `managent models` rather than redefining it.
2. **Task-status resolution.** `resolveStatus` (`src/managent/main.zig:8655`) is the single resolver
   used by status/orient/liveness/lanes; the assertion ledger (`readLedgerStatuses`,
   `src/managent/main.zig:8537`) is its input. (This is the consolidation of a formerly-duplicated job.)
3. **Kill records.** Four places record a killed run: the per-run record in the untracked `runs/`
   area (written by `tools/runner`), the untracked `log/` area, the untracked token ledger
   (`tools/token-capture.py`), and the tracked `docs/infra/dispatch-heals.jsonl` — the last of which
   records *heals*, not kills (see `docs/status/moving-parts-inventory.md` §6).
4. **Test runners.** Six ways to run tests: `tools/smoke.sh`, `tools/suite-truth.sh`,
   `zig build test` (`build.zig`), the Python unit tests under `tests/unit/`, the round-trip tests
   under `tests/roundtrip/`, and the 83 individual `tools/regression-*.sh` scripts (7 of which are
   not wired into `build.zig`) — see `docs/status/moving-parts-inventory.md` §5.
5. **Dispatch paths.** `bin/dispatch` (headless, caps, windows, heals), `tools/fleet-keeper.sh`
   (the auto-dispatch loop), and `bin/subagent` (the `odeeppi`/`oflashpi` subdelegation launcher)
   each contain dispatch logic; the delegation cap is implemented in both `bin/dispatch` and
   `bin/subagent` (per `bin/dispatch:291`).
6. **Liveness.** `managent liveness` (`src/managent/main.zig:11409`), the run records written by
   `tools/runner`, the heartbeat file (read by `readHeartbeats`, `src/managent/main.zig:8690`), and
   the session transcripts read by `tools/token-capture.py` all carry a liveness/health signal, and
   the dashboard composes several of them.
7. **The staged-path scope gate.** Implemented once in `tools/git-commit-mine-lib.sh`, called by both
   the wrapper (`tools/git-commit-mine`) and the pre-commit hook (`tools/hooks/pre-commit:81`) —
   deliberately one implementation with two callers, documented to prevent drift.

---

## §5 Purpose unknown

- **UNKNOWN** — `bin/argus`'s `--mode checklist` and `--mode sweep` outputs beyond what the
  `DARGUS` duty reads: the read-only doctor/watchdog is documented (see
  `docs/infra/roles/ARGUS.md`), but what specifically consumes the `sweep`/`checklist` reports in
  between duty runs could not be established from tracked callers.
- **UNKNOWN** — the `_sync` key in the store (a sibling of `_standing`): `persistStandingState`
  (`src/managent/main.zig:10686`) mentions `_sync` in its comment, and `parseStateJson` drops both
  `_`-prefixed keys (`src/managent/main.zig:2727`), but no tracked code writes `_sync`. Its purpose could not be
  established from evidence.

---

## §6 Blind spots — what this search could not see

Method: grep over committed sources (`src/`, `tools/`, `bin/` tracked entries, `build.zig`) plus the
three dated status inventories, then read each cited line to verify it resolves. This has holes:

1. **Python module-name imports.** A `import window_policy` with a `sys.path` insert or an
   `importlib` load by module name does not appear in a basename grep. `tools/request-accounting.py`
   loads its siblings this way (`_load_sibling`, `tools/request-accounting.py:50`), and the prior
   inventory already mis-flagged `window_policy.py` as dead for exactly this reason.
2. **The live fleet dashboard is untracked.** The live `watch-fleet` script lives in the untracked
   work area and is therefore not cited by path anywhere in this file; its behaviour is described
   only through its tracked regression (`tools/regression-watch-fleet.sh`) and the T855/T856
   findings. Its actual current bytes could have drifted from what the regression pins.
3. **Volatile data files.** `untracked/heartbeat.jsonl`, the `runs/` and `tokens/` areas are
   untracked; this file cites only the tracked code that reads/writes them, never the data files
   themselves (a new citation to an untracked path would fail the commit gate).
4. **Lazy/in-function imports and generated code.** `src/version.zig` is generated
   (`tools/gen-version.sh`) and git-ignored; this file cites `version.banner` only indirectly.
   Any Zig `@import` resolved lazily inside a generic instantiation is visible in the source but not
   in a grep for the module basename.
5. **Path-in-a-variable invocation.** Commands built by string concatenation (e.g. `"$CLAIMLINT_BIN"`
   in `tools/hooks/pre-commit:58`, `"$TG_ROOT/tools/runner"` at `:392`) resolve only at runtime;
   a grep cannot trace which binary a variable names.
6. **The 83 regression scripts were not all read line-by-line.** Each is a check (see §2), and the
   count of checks "that cannot fail" below counts the ones this inventory opened and read; a
   vacuous assertion inside one of the unread scripts would not be in the count.

---

## §7 The six counts (baseline for this scope)

Stated with the method, because these are the numbers that have to come down.

1. **Reporting surfaces inventoried: 30.** Counted as the rows of §1.1–§1.7 (each table row = one
   surface). A "surface" is one place a human or script reads a value; two different verbs that
   share one printer (e.g. `status` text and `status --json`) count once each only where their
   no-data behaviour differs.
2. **Surfaces that emit a value where the honest answer is "cannot determine": 6.** Counted as the
   concrete instances in this file where absence or failure is rendered as a zero, a blank, an
   empty frame, or silence: (a) `orient` floor key missing → `0` (`src/managent/main.zig:6318`);
   (b) `orient` lanes census error → line omitted (`src/managent/main.zig:7010`); (c) `liveness` wall/cpu/rss absent →
   line omitted (`src/managent/main.zig:11499`); (d) `lanes` unparseable bundle → row silently skipped (`src/managent/main.zig:11298`);
   (e) `suite-truth` empty count → comparison silently skipped (`tools/suite-truth.sh:519`);
   (f) the dashboard's failed `status --json` → empty `[]` frame. The stubs and honest `UNKNOWN`/
   `?`/`-`/`-- none --` emissions are **not** counted here — they distinguish absence correctly.
3. **Checks that cannot fail: 4.** Counted as the checks in §2 whose failure condition can never be
   met under any input in the current code: battery I8, battery I11, the STANDING-REEVIDENCE
   trigger, and the suite-truth `steps-failed`/`tests-crashed`/`tests-failed` count comparisons
   (counted once, as one class — they share one vacuous-guard idiom).
4. **Places that reinterpret unrecognised input: 3.** Counted as the §3 rows that silently accept
   rather than refuse: the leading-flag → `status` fallthrough (`src/managent/main.zig:1361`), the
   `done` unknown-flag drop (`getFlagValue`, `src/managent/main.zig:3484`), and the claimlint verify-path unknown-flag
   skip (`src/claimlint.zig:1697`).
5. **Jobs with more than one implementation: 7.** Counted as the numbered items of §4.
6. **Stated blind spots: 6.** Counted as the numbered items of §6.
