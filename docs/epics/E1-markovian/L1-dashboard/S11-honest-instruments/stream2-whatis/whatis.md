# Honest instruments — what this repository does today (the verified union)

**Task:** T866 (audit the two what-is inventories) + T896 (absorb arm C, revision 2) · **Worker:**
glm-5.2/T866, then deepseek-v4-flash/T896 · **Date:** 2026-08-24
**Landmark:** advances `L1 (the dashboard tells the truth)` — Stream 2's single final document.
**Inputs audited:** three independent inventories produced against HEAD `faa5628-dirty` on 2026-08-24 —
arm A (deepseek-v4-pro/T858), arm B (oxalpha/T860), and arm C (claude-sonnet-5/T869, the blind third
pass) — all held in the untracked `stream2-whatis` working area (cited only in prose here; a path
citation to `untracked/` fails the commit gate).

**Revision 2 (T896).** Arm C landed after revision 1 and was never absorbed; this revision absorbs it
with the same bar — every arm-C citation was opened and marked **confirmed** / **misread** /
**citation drifted** / **unverifiable** at its **current** location (the working tree has drifted from
the arms' `faa5628-dirty` numbering: HEAD is now `701ef0c` plus an uncommitted T895 diff on
`src/managent/main.zig` that does not affect any cited line's substance). Arm-C citations were
re-verified at their current locations; A/B citations keep revision 1's numbers, and the one known
post-revision-1 drift — T872's deletion of the `claimlint-green` checklist slug from `bin/argus` — is
noted in §3a. The union is recounted with arm-provenance, and §9 answers whether a fourth pass is
warranted. **No author penalty for a misread** — a misread is a finding about the assertion, not the
author.

**This is an audit, not a grade.** Per the operator ruling, no author is penalised unless they wrote
a demonstrably false assertion or missed an obviously important detail. Every cited `file:line` below
was opened and checked: each is marked **confirmed**, **misread**, **citation drifted**, or
**unverifiable**. A misread is a finding about the *assertion*, not the author.

**Method.** For each instance in all three arms I opened the cited line and read enough context to
judge the claim (revision 1 against `faa5628-dirty`; revision 2 re-opened every arm-C citation against
the current working tree), and where the arm said it ran the instrument live I reproduced the run.
Section §6 records what I could not check. Line numbers cite the committed source at their current
locations, not the git-ignored `bin/` binaries.

---

## §1 Reporting surfaces — and the reconciled denominator

Arm A reports **30** and arm B **68** reporting surfaces; arm C contributed no surface count (its
sweep was mechanism-targeted, and its three new dishonest surfaces are behaviours of surfaces already
inside the 68 — §2 D13–D15). The A-vs-B difference is a denominator difference by definition, not a
contradiction:

- **Arm A** counted *places whose no-data behaviour differs* — two verbs that share one printer count
  once each only where their no-data form differs (e.g. `status` text and `status --json` are two
  surfaces; `orient`'s six sub-readings are six). Its denominator is an analytical lens.
- **Arm B** enumerated *every verb and mode* — all 38 `managent` verbs, 3 `argus` modes, every `bin/`
  tool, the runner/fleet shells, the suite gates. Its denominator is a reproducible census.

**Denominator picked for this document: 68 (verb/mode enumeration).** Reason: it is the more complete
census and its method ("enumerate every entrypoint") is reproducible without a per-pair judgement
call; arm A's behaviour-differs grouping is retained as the lens for §2 (it is exactly the lens that
surfaces the dishonest emissions). Arm B's own §6 count table sums to 69 (38+3+10+6+8+4); one of its
sub-totals is off by one against the enumeration in its §1 tables — a minor internal inconsistency,
not a load-bearing error. **Both denominators are floors.**

The full surface-by-surface enumeration lives in the three arms; this document does not re-list all 68.
What follows is the *union of the problems* the surfaces expose. Arm C did not re-enumerate surfaces
(it was a targeted anti-pattern sweep), so the 68 denominator is unchanged; its three new dishonest
surfaces are behaviours of surfaces already inside the 68 (§2, D13–D15).

---

## §2 Surfaces that emit a value where the honest answer is "cannot determine"

Arm A found **6**, arm B found **6**, arm C found **3** — and none of the fifteen overlaps any other.
The union is **15**, and it is a **floor, not a total**: three passes with pairwise-disjoint finds is
evidence the terrain is under-sampled, not covered (§9).

| # | surface | the line that decides | what it emits | state | arm |
|---|---|---|---|---|---|
| D1 | `managent orient` floor key missing | `ResumeFloor` struct default `src/managent/main.zig:6318` (`c1a: i64 = 0`, …); key lookup at `:6340` | a missing floor key emits `0`, indistinguishable from a real zero | **confirmed** | A |
| D2 | `managent orient` lanes census error | `scanLanes(...) catch null` `src/managent/main.zig:7010` | a scan error silently omits the whole `lanes:` line | **confirmed** | A |
| D3 | `managent liveness` wall/cpu/rss absent | `if (hb.wall > 0)` `src/managent/main.zig:11499` | an absent/zero resource reading is omitted, not marked | **confirmed** | A |
| D4 | `managent lanes` unparseable bundle | `parseDeliverablesFromBundle(...) catch continue` `src/managent/main.zig:11298` | a row whose bundle cannot be parsed is silently skipped | **confirmed** | A |
| D5 | `suite-truth.sh` empty count | `if [ -n "$OBS_STEPS_FAILED" ]` `tools/suite-truth.sh:519` (and `:523`) | a count the regex could not extract makes the comparison silently vacuous | **confirmed** | A |
| D6 | live fleet dashboard, failed `status --json` | described via the tracked regression `tools/regression-watch-fleet.sh` (the live script is untracked and not cited by path) | a store that cannot be read renders as an empty `[]` frame, not "unreadable" | **confirmed (via regression pin; live script not path-cited, see §6)** | A |
| D7 | `managent why <id>` for an absent id | `if (!found) w.data("    -- no tasks reference this claim --\n")` `src/managent/main.zig:7834` | an unknown id and a known claim with zero tasks print the **same** line — zero stands in for not-found. **Reproduced live:** `bin/managent why T999` printed exactly that line. | **confirmed (live)** | B |
| D8 | `managent audit` unreadable citable surface | `readFileAlloc(...) catch ""` `src/managent/main.zig:9521-9546` | an unreadable CLAIMS/PROGRESS/DECISIONS corpus becomes an empty string; every substring probe then misses and rows read as uncited | **confirmed** | B |
| D9 | `argus --mode doctor` conservative-CLEAN fallback | `bin/argus:893-897` ("Conservatively call CLEAN since no marker fired") | an unparseable liveness output is graded CLEAN, not UNKNOWN | **confirmed** | B |
| D10 | `argus` orphan-gate baseline-parse skip | `baseline_count` stays `None` when `findings=(\d+)` does not match; `exceeded = (baseline_count is not None and …)` `bin/argus:533` | an unparseable baseline makes the violation check silently skip | **confirmed** | B |
| D11 | `argus` checklist slug `claimlint-green` | regexes `bin/argus:385-391`, always-green branch `bin/argus:419-427` | all four parse regexes match nothing in current claimlint output (verified empirically); the check always emits "at or below floor" | **confirmed** | B |
| D12 | `tools/runner` heartbeat write swallow | `except OSError: pass` `tools/runner:701-704` | a heartbeat write failure is invisible; downstream liveness then honestly reports UNKNOWN, but the beat-loss itself is not surfaced | **confirmed** | B |
| D13 | `tools/dispatch_verify.py` store-unreadable = task-not-found | `read_store` returns `None` on ANY exception — missing file, unreadable, malformed JSON — indistinguishable from a valid empty store (`tools/dispatch_verify.py:573-578`); `task_state` folds a `None`-store, a `{}`-store and a genuinely-absent task into the same `(None, None)` (`:581-586`); the T-ID verification consumer reports a transient read failure with the same hard worded verdict as a genuine absence — "worker reported success; verification FAILED: task %s not found in store %s" (`:1029-1035`); the heal site collapses the same ambiguity into a bare `return (False, "")` (`:1234-1236`) | a store that cannot be read reads as "no such task" / "nothing to heal" — there is no UNKNOWN path | **confirmed** | C |
| D14 | `tools/dispatch_verify.py` unreadable bundle = "nothing declared" | `parse_deliverables` wraps the bundle-header parse in `except Exception: pass` (`tools/dispatch_verify.py:523-524`); a vanished/permission/encoding error or a future regex change falls through to the same `return [fallback] if fallback else []` as a header that genuinely declares nothing (`:499-525`) | "I could not read this" is indistinguishable from "I read this and it says nothing" | **confirmed** | C |
| D15 | `bin/argus` artifact-loadable zero-artifacts vacuous pass | `_check_artifact_loadable` globs `artifacts/*.wzo` and `data/*.wzo` (`bin/argus:416`, `:420`); with an empty candidate list `any_fail = any(...)` is vacuously `False` (`:433`) and the finding reads "artifact-loadable: 0 artifacts checked, all pass" at grade `could` (`:436-437`) — indistinguishable from a run that loaded N artifacts and found zero failures. "could"-grade findings never surface as violations (the violations filters keep only must/critical/should — `bin/argus:1652`, `:1671`, `:1923`) | zero artifacts checked emits "all pass", not "nothing to verify" | **confirmed** | C |

**Union: 15 dishonest surfaces (floor).** The stubs and honest `UNKNOWN`/`?`/`-`/`-- none --`
emissions are *not* counted here — they distinguish absence correctly. The fifteen above are the cases
where absence or failure is rendered as a zero, a blank, an empty frame, a false CLEAN, a false "not
found", or silence. **Provenance: zero of the 15 was found by more than one arm** — 6 by arm A
(D1–D6), 6 by arm B (D7–D12), 3 by arm C (D13–D15), and the three sets are pairwise disjoint. Every
count here is therefore single-source and **provisional** until a second source corroborates it; the
"floor, not total" language is load-bearing (§9).

---

## §3 Checks — what would have to break for each to fail

### 3a Checks that cannot fail under any input — union: 10

The arms found **disjoint** sets of 4, 4 and 2. Union = 10.

| # | check | why it cannot fire | citation | state | arm |
|---|---|---|---|---|---|
| C1 | battery I8 (truncation-gap) | `checkI8` always returns `.not_applicable`; the real fixture runs externally (`src/vb_fixpoint.zig:391`) | `src/vb_fixpoint.zig:388-397` | **confirmed** | A |
| C2 | battery I11 (move-set consistency) | `checkI11` always returns `.not_applicable` (GAP-5, dump format unspecified) (`src/vb_fixpoint.zig:474`) | `src/vb_fixpoint.zig:468-476` | **confirmed** | A |
| C3 | `managent standing` STANDING-REEVIDENCE trigger | `triggered = c3_debt > c3_prior and c3_prior > 0`; `parseStateJson` drops `_`-prefixed keys (`src/managent/main.zig:2727`), so after any non-`standing` store write `c3_prior` reads 0 and the `c3_prior > 0` half is false. The sibling defect is documented in the code itself at `src/managent/main.zig:10689` | `src/managent/main.zig:10503`, `:2727`, `:10689` | **confirmed** | A |
| C4 | `suite-truth.sh` count comparisons | `steps-failed`/`tests-crashed`/`tests-failed` are compared only `[ -n "$OBS_…" ]`; a Build Summary whose format the regex no longer matches makes all three comparisons silently vacuous (one class) | `tools/suite-truth.sh:519`, `:523` | **confirmed** | A |
| C5 | `tools/regression-runner-host-guard.sh` | retired stub (T821): echoes three lines, `exit 0` unconditionally; its own header says it "cannot be repaired into passing". Still wired into `zig build test` | `tools/regression-runner-host-guard.sh:33-36`; wired `build.zig:333` | **confirmed** | B |
| C6 | `tools/regression-subagent-resident-gate.sh` | same shape, same retirement rationale | `tools/regression-subagent-resident-gate.sh:33-36`; wired `build.zig:352` | **confirmed** | B |
| C7 | `tools/orcha-acceptance.sh` AC3 | `say AC3 PASS "enforced by tools/hooks/pre-commit (T455); this check reports, the hook blocks"` — an unconditional PASS with no measurement behind it | `tools/orcha-acceptance.sh:89-90` | **confirmed** | B |
| C8 | `argus` checklist slug `claimlint-green` | already listed as D11 (dishonest surface); it is also a check that cannot fail. Counted once here as a check; the dishonest-emission facet is counted once in §2 | `bin/argus:419-427` | **confirmed** (at revision 1; see drift note below) | B |
| C9 | `argus` SHA256SUMS "pinned" exemption is a path-string match, never a hash check | both `_check_ephemera_creep` and `_sweep_untracked` parse `line.split(None, 1)` and use only `parts[1]` (the path); `parts[0]` (the recorded hash) is read and discarded (`bin/argus:524-531`, `:1433-1443`). A pinned 10 MB+ artifact can be swapped for any other file under the same path — corrupted, truncated, unrelated — and both checks still report "all large files are SHA256SUMS-pinned" at grade `could` (`:570`) | the property claimed ("pinned deliverables") and the property verified ("a path string appears in a manifest") are different properties | **confirmed** | C |
| C10 | `argus` `_check_generic` grades by exit code alone | the fallback for any checklist slug with no dedicated handler (`_run_slug`'s static elif chain dispatches only 4 slugs, `bin/argus:345-359`) runs `check_cmd.split()`, records `current = "exit={exit_code}"`, and grades `grade if exit_code != 0 else "could"` (`:580-598`, grade at `:589`) — the registry's `baseline` column is carried through as inert display text (`:597`) and never parsed or compared against `current` | a slug is monitored for "does the command crash" and nothing else, no matter what its baseline says it should be watching | **confirmed** | C |

Note: C8 and D11 are the same mechanism under two lenses (a check that cannot fail *and* a surface that
emits a false "at floor"); C9 and J14 (arm C's SHA256SUMS hash-blindness, §5) are likewise one
mechanism under the check lens and the shared-job lens. The union counts each once per lens; the §2 and
§3a totals are not meant to be summed into a single grand total.

**Post-revision-1 drift:** T872 (2026-08-24, the delete wave) deleted the `claimlint-green` checklist
slug and its `_check_claimlint` from `bin/argus`, so D11/C8's citations at `bin/argus:385-391` and
`:419-427` no longer resolve. The mechanism is *gone*, which is the fix; the rows are retained as the
historical record. The remaining `CLAIMLINT_FLOOR` attribute (`bin/argus:365`) survives for doctor/sweep
and is noted in J8/S6.

**Union: 10 checks that cannot fail (floor), plus 8 unwired (§3b).** Provenance: 4 by arm A (C1–C4),
4 by arm B (C5–C8), 2 by arm C (C9–C10) — again pairwise disjoint. Every count is single-source and
**provisional** until a second source corroborates it.

### 3b Checks the gate cannot see — 8 scripts wired to nothing

Arm B found 8 regression scripts that **can fail when run by hand** but that nothing wires into
`zig build test`:

`tools/regression-arbiter.sh` · `regression-managent-done-git.sh` ·
`regression-managent-memory-safety.sh` · `regression-process-ownership.sh` ·
`regression-race-collect.sh` · `regression-request-accounting.sh` ·
`regression-scratch-repo.sh` · `regression-task-identity.sh`.

**Verified.** Method: `comm` of `ls tools/regression-*.sh` basenames against the `tools/regression-*.sh`
references in `build.zig` (case-insensitive — `regression-T227.sh` is wired at `build.zig:811` and a
case-sensitive grep falsely flags it). Each of the 8 has no `addSystemCommand` entry in `build.zig`;
the only tracked invokers are self-references or comment mentions in the two retired stubs, plus
`regression-process-ownership.sh` which is also invoked by *untracked* bakeoff scripts (not a build
wiring). **The replacement coverage is itself unwired:** `regression-arbiter.sh` was created by T821
as the replacement for the retired `regression-runner-host-guard.sh` (C5), and the replacement is in
this 8 — one vacuous check was replaced by one unreachable check.

Denominators: arm A said "83 scripts, 7 unwired" (undercounts — actual is **88 scripts, 8 unwired,
80 wired**); arm B said "86 scripts, 78 wired, 8 unwired" (the unwired count is correct; the total and
wired counts undercount by 2). The load-bearing structural finding — **8 unwired** — is arm B's and is
correct.

### 3c Checks that can fail (samples read in detail, not re-listed)

Both arms read the suite-truth ratchet, the pre-commit claimlint floor gate, the store-census
detector (S10), the `done` impression gate, the fleet-keeper guards, and the GTP boardsize regression
in detail and agree these can fail and what breaks them. Not re-listed here; the arms are the
audit trail. **One reproduced live:** `bin/managent done T866 --verdict pass` → REJECTED (rc=1) by the
impression gate — the `--verdict` flag is silently dropped (see §4 R2), status defaults to `pass`, and
the separate impression gate is what refuses the silent close. And `bin/managent done T866 --status
nonsense` → rc=1 (the enum is validated). Both as arm B reported.

---

## §4 Unrecognised input — where it is silently reinterpreted rather than refused

Arm A found **3** sites, arm B found **6**, arm C found **2** (one new). A and B overlap on **1**
(arm A's `done` unknown-flag drop is the specific instance of arm B's general "no unknown-flag
rejection anywhere in the dispatcher"); arm C's one overlap is that same mechanism (R2), found
independently a third time. Union = **9** distinct mechanisms.

| # | place | behaviour | citation | state | arm |
|---|---|---|---|---|---|
| R1 | `managent` leading flag → `status` | `const cmd = if (args.len >= 2 and !startsWith(args[1], "-")) args[1] else "status"` — an unrecognised leading flag (e.g. `--version`) silently runs `status` | `src/managent/main.zig:1361` | **confirmed** | A |
| R2 | `managent` unknown flag on any verb | `hasFlag`/`getFlagValue` are positive-match only; a misspelled flag (e.g. `--verdict`, `--staus`) is silently dropped and the default applies. On `done`, `--status` defaults to `pass` | `src/managent/main.zig:3484` (`getFlagValue`), `:4650`/`:4688-4696` (done default; current locations `:3553-3568` and `:4739-4745`) | **confirmed (live, see §3c); also re-derived independently by arm C at its current locations** | A+B+C (A: the `done` instance; B: the general property; C: both, independently) |
| R3 | `claimlint` verify-path unknown flag | `if (startsWith(a, "--")) continue` — unknown flags to the verify path are silently ignored | `src/claimlint.zig:1697` | **confirmed** | A |
| R4 | `managent` non-numeric staleness override | `--stale-min abc` / `LIVENESS_STALE_MIN=abc` fall through `parseFloat` failure to the hardcoded 5.0 minutes with no diagnostic | `src/managent/main.zig:11421-11430` (same pattern in `cmdReap`) | **confirmed** | B |
| R5 | `bin/subagent` accepts any `--anything` | `parse_argv` stores every `--x` (bare or `=value`) without validating names; a typo is accepted and ignored. The space-separated form of a value flag not in the `("--model","--wall","--provider")` tuple (e.g. `--rss-cap-mb 4096`) misparses: the flag becomes boolean True and the value becomes a positional | `bin/subagent:428-444` | **confirmed** | B |
| R6 | `tools/attribution-backfill.py` lenient canonicalize | `canonicalize` passes unrecognized tags through unchanged (`ALIASES.get(raw, raw)`), and when `bin/managent` is absent it falls back to an in-file copy `FALLBACK_CANONICAL` — a stale-copy risk plus pass-through of unrecognized input. Contrast `tools/model_tags.py:165-177` which *raises* `UnknownModelTag` | `tools/attribution-backfill.py:109-118` (lenient), `:77-107` (fallback) | **confirmed** | B |
| R7 | `argus` doctor accepts retired liveness formats | the parser keeps backward compat for `[never beat` and `beats stopped` alongside the current `UNKNOWN — no assertion`; an old-format string is consumed as a valid present-day reading | `bin/argus:858-872` | **confirmed** | B |
| R8 | `argus` `_extract_command` reinterprets free text | if no backtick or em-dash convention matches, the **entire field string** becomes the command handed to the shell | `bin/argus:107-123` | **confirmed** | B |
| R9 | `argus` artifact-loadable glob silently excludes `*.wzo2` | `_check_artifact_loadable` globs only `*.wzo` (`bin/argus:416`, `:420`); `data/oracle-3x3-v2.wzo2` and `data/oracle-4x4-v2.wzo2` (both present today under `data/`, recorded in `artifacts/SHA256SUMS`) are invisible to the check with no "N files skipped, unrecognized extension" signal — a newer container format is silently treated as nonexistent rather than refused or flagged. **Arm C's location detail is misread** (it placed the files in `artifacts/`; they are in `data/` and `untracked/oracle-v2/`) — the mechanism is unaffected and slightly stronger than stated, because `data/` IS scanned and the v2 files are still invisible | a newer artifact format silently reads as absent | **confirmed (mechanism); misread (file location)** | C |

**Union: 9 reinterpretation mechanisms (floor).** Provenance: R1, R3 by arm A; R4–R8 by arm B; R9 by
arm C; R2 — the unknown-flag drop — is the one mechanism all three arms found independently (arm A's
`done` instance, arm B's general property, arm C's re-derivation of both). Eight of the nine are
single-arm and **provisional**; R2 is triple-arm.

Counter-examples both arms recorded (places that DO refuse): `managent` unknown *command*
(`unknown command: …`, exit 1 — `src/managent/main.zig:1521`); GTP unknown commands (`? unknown
command` — `src/gtp.zig:1845`); `claimlint` unknown verb (`src/claimlint.zig:1681`); `bin/dispatch`
unknown flag (`bin/dispatch:271`); `tools/fleet-keeper.sh` unknown argument (exit 2);
`tools/suite-truth.sh` unknown argument (exit 2); `tools/runner`/`bin/argus`/Python tools unknown
flags (stdlib `argparse`, exit 2); `tools/model_tags.py` strict boundary; `done --status nonsense`
(validated enum).

---

## §5 Shared jobs — two or more mechanisms doing the same thing

Arm A found **7**, arm B found **7**, arm C found **2**. A and B overlap on **2** jobs
(model-label canonicalization, and liveness); arm C's two are new. Union = **14** distinct jobs.

| # | job | implementations (union) | state | arm |
|---|---|---|---|---|
| J1 | Model-label canonicalization | `canonical_models[]`/`canonicalizeModelTag` `src/managent/main.zig`; `managent models` `:7401`; `managent canonicalize` `:7473`; `tools/model_tags.py` (strict, T801); `tools/attribution-backfill.py:77-118` (lenient + stale fallback); `docs/infra/model-registry.md` (prose registry) | **confirmed** | A+B (overlap; B found the divergent strict/lenient boundary) |
| J2 | Task-status resolution | `resolveStatus` `src/managent/main.zig:8655`, fed by `readLedgerStatuses` `:8537` — the single resolver after a consolidation | **confirmed** | A |
| J3 | Kill records | the per-run record (`tools/runner`), the untracked `log/` area, the token ledger (`tools/token-capture.py`), and `docs/infra/dispatch-heals.jsonl` (the last records *heals*, not kills) | **confirmed** | A |
| J4 | Test runners | `tools/smoke.sh`, `tools/suite-truth.sh`, `zig build test` (`build.zig`), `tests/unit/`, `tests/roundtrip/`, and the 88 `tools/regression-*.sh` scripts (8 unwired — see §3b) | **confirmed** | A |
| J5 | Dispatch paths | `bin/dispatch` (headless, caps, windows, heals), `tools/fleet-keeper.sh` (auto loop), `bin/subagent` (subdelegation); the delegation cap is implemented in both `bin/dispatch:291` and `bin/subagent` | **confirmed** | A |
| J6 | Liveness / health signals | `managent liveness` `src/managent/main.zig:11409`; run records (`tools/runner`); heartbeat file (`readHeartbeats` `:8690`); session transcripts (`tools/token-capture.py`); `managent reap` `:11531`; watch-fleet FRESH column | **confirmed** | A+B (overlap on `liveness`; each found additional carriers) |
| J7 | Staged-path scope gate | one implementation `tools/git-commit-mine-lib.sh` called by the wrapper `tools/git-commit-mine:99` and the pre-commit hook `tools/hooks/pre-commit:89`/`:149` — deliberately one copy, two callers | **confirmed** | A |
| J8 | Claimlint floor (divergent copies) | enforced `tools/hooks/claimlint-floor.json` (C1a=0, C2=0, C3=42, C6=0); `argus`'s own `CLAIMLINT_FLOOR = {"C1a": 10, "C2": 12, "C6": 0}` (`bin/argus:365`) — a looser second copy (moot only while the checklist mode is dead, §3a-C8) | **confirmed** | B |
| J9 | Per-task token reading | runner trailer line, heartbeat record token fields, `tokens.jsonl` ledger — named together by the code (`tools/runner:671-676`) | **confirmed** | B |
| J10 | Progress narrative | `managent orient` `:6884`; `managent resume` `:6493`; per-sprint `STATUS.md` files | **confirmed** | B |
| J11 | Artifact persistence | `src/artifact.zig` (ADR-0011 wzo) and `src/artifact2.zig` (wzo2, oracle-v2) — two formats, both live | **confirmed** | B |
| J12 | Suite-redness accounting | direct full-sweep census (S11 STATUS.md) and the `suite-truth` manifest (`docs/infra/suite-truth.md`) over different denominators (all 88 scripts vs the 80 wired + modules) | **confirmed** | B |
| J13 | Stale-threshold resolution | `cmdLiveness` (`src/managent/main.zig:11590-11600`) and `cmdReap` (`:11707-11717`) each independently re-implement, verbatim, "read `LIVENESS_STALE_MIN`, else `--stale-min`, else 5.0 minutes" as an inline `blk:` block; `cmdReap`'s comment "Same staleness threshold as liveness (T370)" (`:11704-11706`) documents the duplication as known and accepted rather than factored out. A future change applied to one site and not the other makes `liveness` and `reap` silently disagree about what "stale" means for the identical row. **Site-adjacent to R4** (arm B's silent parse-fallback lives inside the same block) but a distinct mechanism: fixing the duplication does not fix the silent fallback, and vice versa | **confirmed** | C |
| J14 | SHA256SUMS-pinned parse | `_check_ephemera_creep` (`bin/argus:524-531`) and `_sweep_untracked` (`:1433-1443`) are near-identical blocks (same `split(None, 1)`, same discarded hash field, same set-of-paths construction) doing the same job — deciding which large files are exempt from the ephemera-creep alarm — once for the mechanized checklist run and once for the free-form sweep. This is the shared-job lens of C9: the hash-blindness defect exists in two copies, and a fix to one without the other leaves the remaining copy silently exempting corrupted files | **confirmed** | C |

**Union: 14 shared jobs (floor).** Provenance: J1 and J6 were found by two arms (A and B —
canonicalization and liveness); J2–J5, J7 by arm A only; J8–J12 by arm B only; J13–J14 by arm C only.
Twelve of the fourteen are single-arm and **provisional**; J1 and J6 are dual-arm. Named, not ranked,
not merged.

---

## §6 Blind spots — what this audit could not check

1. **The live fleet dashboard script is untracked.** Both arms describe it through its tracked
   regression `tools/regression-watch-fleet.sh` only. Its current bytes could have drifted from the
   regression; D6 is therefore confirmed *via the regression pin*, not against the live script. A path
   citation to the live script would fail the commit gate, so it is not cited here.
2. **Bash composition in regression scripts.** Commands built in variables (`$SOME_CMD` invoked later)
   defeat a static scan; ~20 of the 88 scripts were read in full by arm B, the rest got structural
   scans. A vacuous assertion inside an unread script would not be in the §3 count.
3. **Python dynamic imports.** `importlib`/`__import__` and `WEIZIGO_CANONICALIZER_JSON` seams
   (`tools/model_tags.py:45-50`) mean some readers resolve code at runtime; the call-graph here is
   lexical only.
4. **Zig comptime and generated steps.** `build.zig` constructs steps programmatically; the 80-wired
   count comes from grepping literal `tools/regression-*.sh` strings. A step assembled from parts
   would be invisible (none found, but the method cannot exclude it). `src/version.zig` is generated
   and git-ignored.
5. **Deployed-binary vs source drift.** This audit cites sources; the `bin/` binaries may lag them
   (argus doctor's own staleness check flags deployed binaries stale vs zig-out). Behavior claims
   from live runs hold for the deployed binaries; source citations hold for HEAD.
6. **Engine-side instruments** (`weizigo-chainability`, `reachcensus`, arena replay internals, the
   `vb_*` family) were inventoried at entry-point level only.
7. **The three arms themselves are untracked.** They are cited in prose ("arm A", "arm B", "arm C"),
   never by path, per the commit gate. They survive only on the host that created them.
8. **Arm C's own blind spots, carried forward** (it named them plainly): ~110K lines of Zig outside the
   ~150 it opened in `main.zig`/`claimlint.zig` unexamined; only 2 of ~90 `tools/*.sh` scripts read in
   full (the rest grep-matched only, which misses anything whose defect is not in the substrings it
   searched for); the compiled-binary tools' Zig sources (`weizigo-arena`, `weizigo-oracle`,
   `weizigo-gtp`, `weizigo-engine-vs-engine`, `weizigo-reachcensus`, `weizigo-chainability`) not opened
   at all — any dishonest reporting surface in the Go-engine tooling is a total blind spot for arm C; a
   14-file grep hit for `eval(`/`exec(`/dynamic-import patterns in `tools/` was not followed up beyond
   the grep itself, even though dynamic dispatch is exactly the shape basename search misses.
9. **Arm C ran no live reproductions.** Every arm-C citation was verified by source tracing only, so
   its behavioural claims inherit the deployed-binary-vs-source drift caveat of item 5 (what the
   deployed `bin/argus` globs today is not verified).

---

## §7 Five-way resolution of every contradiction

| # | question | arm A | arm B | verdict |
|---|---|---|---|---|
| Q1 | how many reporting surfaces? | 30 (behaviour-differs) | 68 (verb/mode enum) | **a third reading is better — both denominators are valid; pick 68 as primary (§1)** |
| Q2 | how many dishonest surfaces? | 6 | 6 (disjoint set) | **all three right — union is 15, a floor; arm C's 3 (D13–D15) are also disjoint, so zero of the 15 was found by more than one arm** |
| Q3 | how many checks cannot fail? | 4 | 4 (disjoint set) | **all three right — union is 10 (+ 8 unwired, a distinct category)** |
| Q4 | how many reinterpretation sites? | 3 | 6 (overlap of 1) | **all three right — union is 9; R2 is A's instance of B's general property, re-derived independently by C** |
| Q5 | how many shared jobs? | 7 | 7 (overlap of 2) | **all three right — union is 14** |
| Q6 | regression script totals | 83 scripts, 7 unwired | 86 scripts, 8 unwired | **arm B right on the load-bearing count (8 unwired); arm A undercounts. Actual: 88 scripts, 80 wired, 8 unwired** |
| Q7 | purpose of `_sync` | UNKNOWN — "no tracked code writes `_sync`" | (not addressed) | **arm A wrong (misread): `writeSyncData` `src/managent/main.zig:9305` writes `_sync`; its purpose is the per-role message-read cursor for `managent sync`. The sibling defect (serializeState drops `_`-keys, so any other mutation erases them) is still accurate — that is C3, not this** |
| Q8 | purpose of `managent treekill` | (not addressed) | UNKNOWN — no brief/doc found | **arm B under-searched: the contract is in the help text (`src/managent/main.zig:8051`) and the module banner (`:11707`): enumerate/kill a process tree. A third reading is better** |
| Q9 | purpose of argus `--mode sweep`/`checklist` | UNKNOWN — no tracked consumer found | (checklist mode is dead — registry gone) | **arm A right: no production consumer (DARGUS runs `--mode doctor` only; `checklist` is exercised only by a regression test with a synthetic registry)** |
| Q10 | is the `_standing`/`_sync` key-drop a real defect? | yes (C3, documented in code) | (not addressed) | **arm A right — confirmed at `src/managent/main.zig:10689` and `:2727`** |

### 7b — Arm C against the union

| # | question | arm C | verdict |
|---|---|---|---|
| Q11 | does the disjoint-halves pattern hold through a third pass? | 8 of its 9 mechanisms are new to the union (89%); the single overlap is R2, the one mechanism A and B already shared | **yes — no convergence.** Three passes, 48 distinct sites, 45 found by exactly one arm (§9) |
| Q12 | is the SHA256SUMS "pinned" exemption really hash-blind? | yes — both copies read `parts[0]` and discard it (`bin/argus:524-531`, `:1433-1443`) | **arm C right — new union site C9/J14** (no other arm looked at SHA256SUMS) |
| Q13 | does `argus` grade any unhandled checklist slug by exit code alone? | yes — `_run_slug` dispatches only 4 slugs; the rest take `_check_generic`, exit-code-only (`bin/argus:345-359`, `:580-598`) | **arm C right — new union site C10**, and it corroborates Q9 (the checklist mode is mostly dead machinery) |
| Q14 | where are the `.wzo2` artifacts? | arm C said `artifacts/` | **misread detail — they are in `data/` and `untracked/oracle-v2/`** (recorded in `artifacts/SHA256SUMS`); the mechanism (glob misses `*.wzo2`) holds and is stronger, since `data/` is scanned (R9) |
| Q15 | did the purpose-unknown category converge? | arm C chased one candidate (`shape`), traced `selectForShape` (`src/managent/main.zig:1045`), withdrew it — zero survivors in its slice | **consistent with the audit's own resolutions** (Q7: A's `_sync` was wrong; Q8: B's `treekill` under-searched): candidates in this category tend to resolve under scrutiny; arm C's negative is an honest result for its slice, not a claim of coverage |

---

## §8 SHOULD-BE — intent, separated from what each mechanism does

For each mechanism where the evidence shows what it was *evidently trying to do* (a comment, a spec, a
name, a half-built path), the intent is recorded separately from what it does today. This is the most
valuable by-product of the reconciliation: reconciling an ideal against a stated intent is more
productive than reconciling it against present confusion.

| # | mechanism | what it does | what it was evidently trying to do (the should-be) | evidence of intent |
|---|---|---|---|---|
| S1 | STANDING-REEVIDENCE trigger (C3) | cannot fire — `c3_prior` reads 0 after any other store write | fire when C3 debt grows | the code's own comment: "A first-class `_standing` in StateMap is the real fix" `src/managent/main.zig:10689` |
| S2 | battery I8 (C1) | always `.not_applicable` | compare two evaluators (loopy fixpoint vs first-revisit) at 2×2 | the comment: "delegates the 2×2 check to a separate run of the Python fixture in the fleet (V-13)" `src/vb_fixpoint.zig:391` |
| S3 | battery I11 (C2) | always `.not_applicable` | compare the battery's move set to the solver's | "GAP-5 … dump format is unspecified. This invariant is stubbed until the format is defined" `src/vb_fixpoint.zig:474` |
| S4 | suite-truth count comparisons (C4) | silently vacuous when the regex extracts nothing | compare `steps-failed`/`tests-crashed`/`tests-failed` against the manifest | the comparisons exist; the guard `[ -n "$OBS_…" ]` was meant to skip only when there is genuinely nothing to compare, not when parsing failed `tools/suite-truth.sh:519` |
| S5 | argus checklist slug `claimlint-green` (C8/D11) | always "at or below floor" — regexes match nothing | grade claimlint against a floor | `bin/argus:365` carries its own `CLAIMLINT_FLOOR`; the slug was written when claimlint's output format matched those regexes |
| S6 | argus `CLAIMLINT_FLOOR` second copy (J8) | a looser divergent floor (`C1a:10, C2:12`) | the same floor as the commit gate | "the ratified honest-debt floor from the Phase-2 exit check (see ARGUS.md §Floor-grading rule)" `bin/argus:360-365` — it is meant to be the *same* floor, not a second one |
| S7 | `managent` unknown-flag drop (R2) | silently drop unknown flags; `done` defaults to `pass` | refuse unknown flags (or at least not let a misspelling become a confident wrong close) | the impression gate exists *because* the dispatcher does not refuse — the gate is a backstop for a defect the dispatcher could fix at the source `src/managent/main.zig:4794-4837` |
| S8 | `managent` leading-flag → `status` (R1) | run `status` for any leading `--flag` | refuse an unrecognised leading flag | the default-`status` was meant for *no argument*, not for a flag that is not a command `src/managent/main.zig:1361` |
| S9 | `claimlint` verify-path unknown-flag skip (R3) | silently ignore unknown flags | refuse unknown flags (the verb path does) | the verb path already refuses `unknown verb '{s}'` `src/claimlint.zig:1681`; the flag path is the inconsistency |
| S10 | `tools/attribution-backfill.py` lenient canonicalize (R6) | pass unrecognized tags through + a stale `FALLBACK_CANONICAL` copy | delegate to the one canonicalizer | the module docstring says it mirrors `canonicalizeModelTag`; `tools/model_tags.py` is the strict reader that does it right |
| S11 | `bin/subagent` accepts any `--anything` (R5) | store every `--x` without validating | validate flag names against a known set | the value-flag tuple `("--model","--wall","--provider")` shows the parser *knows* its real flags; bare flags were simply not given the same treatment `bin/subagent:428` |
| S12 | `argus` doctor retired liveness formats (R7) | consume old-format strings as current | flag unrecognizable formats (or drop the backward-compat now that T441 retired them) | the comment: "T441 changed `never beat` to `UNKNOWN — no assertion`; keep backward compat for any older output" `bin/argus:863-864` — the compat was a transition aid that never expired |
| S13 | `argus` `_extract_command` free text (R8) | execute the entire field as a command | refuse fields that match no convention | the function's own docstring lists the conventions it means to support (`bin/argus:101-105`); the fallthrough is the un-handled case |
| S14 | `managent why` zero-for-absent (D7) | print the same line for an unknown id and a zero-task claim | distinguish "no such claim" from "claim exists, zero references" | `show` already refuses unknown ids loudly (`src/managent/main.zig:7162`); `why` is the inconsistent sibling |
| S15 | `managent audit` empty-corpus degradation (D8) | an unreadable corpus reads as "uncited" | surface a read failure as "corpus unreadable" | the audit's purpose is to check citations *against* the corpus; an empty corpus is not a check result |
| S16 | `argus` conservative-CLEAN fallback (D9) | grade an unparseable liveness output as CLEAN | grade it UNKNOWN/WATCH | the rest of the doctor grades unknowns as `UNKNOWN — no assertion`; this branch is the exception |
| S17 | `argus` orphan-gate baseline-parse skip (D10) | skip the violation check when the baseline is unparseable | fail the check when the baseline cannot be parsed | the check exists to detect growth past a baseline; a missing baseline is exactly the case to alarm |
| S18 | `tools/runner` heartbeat write swallow (D12) | `except OSError: pass` | warn on a write failure | downstream liveness already honestly reports UNKNOWN; a warn would surface the beat-loss itself |
| S19 | `managent orient` floor key missing → `0` (D1) | emit `0` for a missing floor key | emit `?` (the unknown marker already used elsewhere in `orient`) | `orient` already renders `C1a=?` for an unparseable count (`src/managent/main.zig:6996`); the floor path is the inconsistency |
| S20 | `managent orient` lanes census error (D2) | silently omit the `lanes:` line | render "lanes: unavailable" | the floor path already renders "floor: … unreadable"; the lanes path is the inconsistency |
| S21 | `managent liveness` wall/cpu/rss omit (D3) | omit the line when `wall == 0` | state an absent reading as `?` | the rest of liveness already states `UNKNOWN — no assertion` for absence; the resource line is the inconsistency |
| S22 | `managent lanes` unparseable bundle skip (D4) | `catch continue` | flag the row whose bundle cannot be parsed | the reverse scan exists to find done rows whose findings never landed; an unparseable bundle is exactly the row to surface |
| S23 | dashboard failed `status --json` → empty `[]` (D6) | render an unreadable store as an empty frame | render "store unreadable" | `rate_of` already renders `UNKNOWN` for a missing reading; the frame fallback is the inconsistency |
| S24 | retired regression stubs (C5, C6) | `exit 0` unconditionally, wired into the build | be deleted (or moved to a retired/ namespace), not shipped as passing | their own headers say "cannot be repaired into passing" — they assert *deleted* controls; an exit-0 stub wired into the build inflates the passing count |
| S25 | `orcha-acceptance.sh` AC3 (C7) | print an unconditional PASS | either measure (read the hook's refusal log) or drop the check and rely on the hook | its own message: "this check reports, the hook blocks" — it admits it measures nothing |
| S26 | 8 unwired regression scripts (§3b) | can fail but nothing runs them | wire them into the build (or document why they run by hand only) | `regression-arbiter.sh` was created as the *replacement* for C5; the replacement is itself unwired — the retirement replaced one vacuous check with one unreachable check |
| S27 | `tools/dispatch_verify.py` store-unreadable = not-found (D13) | a read failure reads as "task not found" / "nothing to heal" | surface "store unreadable" as its own verdict | the verify path exists to give a hard worded verdict about the *row*; an unreadable store is not a row fact (`tools/dispatch_verify.py:1029-1035`) |
| S28 | `parse_deliverables` except-pass (D14) | any failure mode reads as "nothing declared" | distinguish "could not read" from "declares nothing" | the reverse-scan's whole purpose is finding done rows whose findings never landed; an unparseable bundle is exactly the row to surface, not to skip (`tools/dispatch_verify.py:499-525`) |
| S29 | artifact-loadable zero-artifacts pass (D15) | "0 artifacts checked, all pass" | emit "0 checked — nothing to verify" as a distinct state (or refuse the vacuous pass) | the check exists to verify artifacts load; an empty glob is not a pass result (`bin/argus:432-437`) |
| S30 | SHA256SUMS path-only pinning (C9, and its duplicate J14) | a file is "pinned" because its path string appears in the manifest; the recorded hash is read and discarded | verify the recorded hash against the file's current bytes (run `sha256sum`), once, in one shared parser | the comment claims "pinned deliverables… exempt"; pinning means content, not path — and there are two verbatim copies of the parse to fix (`bin/argus:524-531`, `:1433-1443`) |
| S31 | `_check_generic` exit-code-only grading (C10) | a slug is monitored for "does the command crash" and nothing else | parse and compare the registry's `baseline` column against `current`, as the 4 dedicated handlers do | the baseline column exists to be compared; carrying it as inert display text is the same report-vs-measure gap as S5 (`bin/argus:580-598`) |
| S32 | artifact-loadable glob misses `*.wzo2` (R9) | newer-format artifacts are invisible, with no skip signal | glob both `*.wzo` and `*.wzo2` (or refuse with "N files skipped, unrecognized extension") | the check's purpose is to verify loadable artifacts; a newer container format is an artifact (`bin/argus:416`, `:420`) |
| S33 | stale-threshold copy-paste (J13) | `liveness` and `reap` each re-implement the resolution verbatim | factor into one function (one resolution order, one parse-error policy) | the code's own comment — "Same staleness threshold as liveness (T370)" — documents the duplication as known and accepted (`src/managent/main.zig:11704-11706`) |

---

## §9 Arm C absorbed — disposition, union recount, and the fourth-pass question

### 9a Disposition of every arm-C assertion (count in, count out)

| arm-C inventory item | disposition | carried forward as |
|---|---|---|
| 1a `dispatch_verify.py` read_store/task_state collapse | **confirmed** (`tools/dispatch_verify.py:573-578`, `:581-586`; consumer `:1029-1035`; heal `:1234-1236`) | D13 |
| 1b `dispatch_verify.py` parse_deliverables except-pass | **confirmed** (`:499-525`, `except Exception: pass` at `:523-524`) | D14 |
| 1c `argus` artifact-loadable zero-artifacts vacuous pass | **confirmed** (`bin/argus:411-447`; vacuous `any` at `:433`; "all pass" text at `:436-437`); the supporting "`could` never surfaces as a violation" is confirmed (filters at `:1652`, `:1671`, `:1923`) | D15 |
| 2a `argus` SHA256SUMS pinned = path-only | **confirmed** (`bin/argus:524-531`; `:1433-1443`) | C9 (+ its duplicate-lens J14) |
| 2b `argus` `_check_generic` exit-code-only | **confirmed** (`bin/argus:580-598`, grade at `:589`; 4-slug elif chain at `:345-359`) | C10 |
| 3a managent no whole-argv flag validation | **confirmed** (`src/managent/main.zig:3553-3568`; cmdDone default-pass `:4739-4745`) — **but not a new union site**: this is exactly R2, already merged from A's instance and B's general property. Arm C is the third independent find; R2 is now the one mechanism found by all three arms | merged into R2 |
| 3b argus glob misses `*.wzo2` | **confirmed mechanism** (globs `bin/argus:416`/`:420` match `*.wzo` only; `data/oracle-3x3-v2.wzo2` and `data/oracle-4x4-v2.wzo2` exist in `data/`, recorded in `artifacts/SHA256SUMS`) — **location detail misread** (arm C placed them in `artifacts/`; they are in `data/` and `untracked/oracle-v2/`). The mechanism is unaffected and stronger: `data/` IS scanned, and the v2 files are still invisible | R9 |
| 4a stale-threshold copy-paste | **confirmed** (`src/managent/main.zig:11590-11600`; `:11707-11717`; "Same staleness threshold" comment at `:11704-11706`) | J13 |
| 4b SHA256SUMS parse duplication | **confirmed** (`bin/argus:524-531` vs `:1433-1443`, verbatim) | J14 (shared-job lens of C9) |
| 5 purpose-unknown: zero survivors | **confirmed as an honest negative** — its one candidate (`shape`) was correctly withdrawn (`selectForShape` at `src/managent/main.zig:1045` does gate a real algorithm choice, re-verified). Consistent with the audit's own category resolutions (Q7, Q8) | negative result; no union site |

**Count in: 9 mechanisms carried forward (8 new union sites + 1 merge into R2). Count out: 0
rejected.** One *detail* is misread and corrected (the `artifacts/` location of the `.wzo2` files, in
1c/3b) — a finding about the assertion, not the author, per the standing rule. No arm-C assertion was
dropped silently; every one appears above with its disposition.

### 9b The three-arm union, with provenance

| count | A only | B only | C only | 2 arms | 3 arms | union |
|---|---|---|---|---|---|---|
| dishonest surfaces (§2) | 6 | 6 | 3 | 0 | 0 | **15** (floor; every site single-arm — provisional) |
| checks that cannot fail (§3a) | 4 | 4 | 2 | 0 | 0 | **10** (floor; every site single-arm — provisional) |
| reinterpretation sites (§4) | 2 (R1, R3) | 5 (R4–R8) | 1 (R9) | 0 | 1 (R2) | **9** (floor; 8 single-arm provisional, R2 triple-arm) |
| shared jobs (§5) | 5 | 5 | 2 | 2 (J1, J6) | 0 | **14** (floor; 12 single-arm provisional) |
| **the four problem categories** | 17 | 20 | 8 | 2 | 1 | **48 distinct sites** |
| unwired scripts (§3b) | 0 | 8 | 0 | 0 | 0 | **8** (arm B only — provisional; a separate category — they CAN fail, just for nobody who would notice, and are not summed into the 48) |

A contributed 20 finds (6+4+3+7), B 23 (6+4+6+7 — 20 new, since R2, J1, J6 overlapped A), C 9 (8 new
— only R2 overlapped). New-site rates: A 100%, B 87%, C 89% (all in the four problem categories). The
per-category rows are not meant to be summed into a grand total beyond the distinct-site row (the
C8/D11 and C9/J14 lens notes in §3a apply).

### 9c Overlap analysis — the finding this row exists to produce

**The disjoint-halves pattern did NOT converge with a third pass — it re-asserted itself.** Of the 48
distinct sites in the union, **45 (94%) were found by exactly one arm**; 2 (J1, J6) by two; exactly 1
(R2, the unknown-flag drop) by all three. Arm C — the smallest and methodologically narrowest pass —
still contributed 8 new sites of 9. The only triple-overlap is R2, which is the single most
*structural* mechanism in the whole inventory: `hasFlag`/`getFlagValue` is the *entire* flag-parsing
primitive of `managent`, so every pass that examines flag handling at all must land on it.
Structural, shared-helper defects get found by everyone; instance-level defects are spread out over
the terrain.

The per-category per-pass counts are non-increasing (6, 6, 3 dishonest; 4, 4, 2 checks; 7, 7, 2
shared; 3, 6, 1 new reinterpretation) — but this is **not** convergence. If the counts were falling
because the terrain was being covered, new finds would increasingly overlap old ones. They don't: the
overlap rate across passes is flat (B's overall overlap 13%, C's 11%). The falling counts track the
shrinking *scope* of each pass (arm C's method was a grep anti-pattern sweep over a small slice), not
the exhaustion of the terrain.

**What it implies about a fourth pass: a fourth pass IS warranted.** Three passes produced 48 distinct
sites with 94% single-arm provenance; no pass has yet re-found another pass's *specific* finds (R2 is a
shared-helper generality, not a specific site). Arm C's method rotation (anti-pattern grep instead of
entrypoint census) was productive — it found things A and B's entrypoint-driven approaches missed — so
a fourth pass should rotate again, not repeat: full reads of the ~88 `tools/*.sh` scripts arm C
grep-matched and this audit only structurally scanned; the engine-side tooling (`weizigo-arena`,
`weizigo-oracle`, `weizigo-gtp`, `weizigo-engine-vs-engine`, `weizigo-reachcensus`,
`weizigo-chainability`) that every arm has so far only inventoried at entry-point level; and live
reproduction of the `could`-grade argus findings (D15/C9/C10), which this audit verified by source
reading only. The honest caveat: each pass is expensive and the marginal per-find yield is falling (C
found 3 dishonest surfaces to A and B's 6), so the fourth pass should be scoped to those named blind
spots, not re-run as another general census — and it should be costed against the alternative of
starting stream4 (fixing the 48 known sites) instead of counting more.

**No code or tests were changed. Describing is the whole job; the only status document touched is the
S11 STATUS surface's baseline (this stream's own progress surface, per the T896 brief).**