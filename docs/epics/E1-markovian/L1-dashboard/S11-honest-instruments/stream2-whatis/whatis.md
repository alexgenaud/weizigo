# Honest instruments — what this repository does today (the verified union)

**Task:** T866 (audit the two what-is inventories) · **Worker:** glm-5.2/T866 · **Date:** 2026-08-24
**Landmark:** advances `L1 (the dashboard tells the truth)` — Stream 2's single final document.
**Inputs audited:** two independent inventories produced against HEAD `faa5628-dirty` on 2026-08-24 —
arm A (deepseek-v4-pro/T858) and arm B (ox-alpha/T860), both held in the untracked `stream2-whatis`
working area (cited only in prose here; a path citation to `untracked/` fails the commit gate).

**This is an audit, not a grade.** Per the operator ruling, no author is penalised unless they wrote
a demonstrably false assertion or missed an obviously important detail. Every cited `file:line` below
was opened and checked: each is marked **confirmed**, **misread**, **citation drifted**, or
**unverifiable**. A misread is a finding about the *assertion*, not the author.

**Method.** For each instance in both arms I opened the cited line in the working tree at
`faa5628-dirty`, read enough context to judge the claim, and where the arm said it ran the instrument
live I reproduced the run. Section §6 records what I could not check. Line numbers cite the committed
source, not the git-ignored `bin/` binaries.

---

## §1 Reporting surfaces — and the reconciled denominator

The two arms report **30** (arm A) versus **68** (arm B) reporting surfaces. This is a denominator
difference by definition, not a contradiction:

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

The full surface-by-surface enumeration lives in the two arms; this document does not re-list all 68.
What follows is the *union of the problems* the two surfaces expose.

---

## §2 Surfaces that emit a value where the honest answer is "cannot determine"

Arm A found **6**, arm B found **6**, and **the twelve do not overlap** — exactly the disjoint-halves
pattern the brief predicted. The union is **12**, and it is a **floor, not a total**: two independent
passes each found roughly half, so a third pass would find more.

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

**Union: 12 dishonest surfaces (floor).** The stubs and honest `UNKNOWN`/`?`/`-`/`-- none --`
emissions are *not* counted here — they distinguish absence correctly. The twelve above are the cases
where absence or failure is rendered as a zero, a blank, an empty frame, a false CLEAN, or silence.

---

## §3 Checks — what would have to break for each to fail

### 3a Checks that cannot fail under any input — union: 8

The arms found **disjoint** sets of 4 each. Union = 8.

| # | check | why it cannot fire | citation | state | arm |
|---|---|---|---|---|---|
| C1 | battery I8 (truncation-gap) | `checkI8` always returns `.not_applicable`; the real fixture runs externally (`src/vb_fixpoint.zig:391`) | `src/vb_fixpoint.zig:388-397` | **confirmed** | A |
| C2 | battery I11 (move-set consistency) | `checkI11` always returns `.not_applicable` (GAP-5, dump format unspecified) (`src/vb_fixpoint.zig:474`) | `src/vb_fixpoint.zig:468-476` | **confirmed** | A |
| C3 | `managent standing` STANDING-REEVIDENCE trigger | `triggered = c3_debt > c3_prior and c3_prior > 0`; `parseStateJson` drops `_`-prefixed keys (`src/managent/main.zig:2727`), so after any non-`standing` store write `c3_prior` reads 0 and the `c3_prior > 0` half is false. The sibling defect is documented in the code itself at `src/managent/main.zig:10689` | `src/managent/main.zig:10503`, `:2727`, `:10689` | **confirmed** | A |
| C4 | `suite-truth.sh` count comparisons | `steps-failed`/`tests-crashed`/`tests-failed` are compared only `[ -n "$OBS_…" ]`; a Build Summary whose format the regex no longer matches makes all three comparisons silently vacuous (one class) | `tools/suite-truth.sh:519`, `:523` | **confirmed** | A |
| C5 | `tools/regression-runner-host-guard.sh` | retired stub (T821): echoes three lines, `exit 0` unconditionally; its own header says it "cannot be repaired into passing". Still wired into `zig build test` | `tools/regression-runner-host-guard.sh:33-36`; wired `build.zig:333` | **confirmed** | B |
| C6 | `tools/regression-subagent-resident-gate.sh` | same shape, same retirement rationale | `tools/regression-subagent-resident-gate.sh:33-36`; wired `build.zig:352` | **confirmed** | B |
| C7 | `tools/orcha-acceptance.sh` AC3 | `say AC3 PASS "enforced by tools/hooks/pre-commit (T455); this check reports, the hook blocks"` — an unconditional PASS with no measurement behind it | `tools/orcha-acceptance.sh:89-90` | **confirmed** | B |
| C8 | `argus` checklist slug `claimlint-green` | already listed as D11 (dishonest surface); it is also a check that cannot fail. Counted once here as a check; the dishonest-emission facet is counted once in §2 | `bin/argus:419-427` | **confirmed** | B |

Note: C8 and D11 are the same mechanism under two lenses (a check that cannot fail *and* a surface that
emits a false "at floor"). The union counts it once per lens; the §2 and §3a totals are not meant to be
summed into a single grand total.

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

Arm A found **3** sites, arm B found **6**. They overlap on **1** (arm A's `done` unknown-flag drop is
the specific instance of arm B's general "no unknown-flag rejection anywhere in the dispatcher").
Union = **8** distinct mechanisms.

| # | place | behaviour | citation | state | arm |
|---|---|---|---|---|---|
| R1 | `managent` leading flag → `status` | `const cmd = if (args.len >= 2 and !startsWith(args[1], "-")) args[1] else "status"` — an unrecognised leading flag (e.g. `--version`) silently runs `status` | `src/managent/main.zig:1361` | **confirmed** | A |
| R2 | `managent` unknown flag on any verb | `hasFlag`/`getFlagValue` are positive-match only; a misspelled flag (e.g. `--verdict`, `--staus`) is silently dropped and the default applies. On `done`, `--status` defaults to `pass` | `src/managent/main.zig:3484` (`getFlagValue`), `:4650`/`:4688-4696` (done default) | **confirmed (live, see §3c)** | A+B (A: the `done` instance; B: the general property) |
| R3 | `claimlint` verify-path unknown flag | `if (startsWith(a, "--")) continue` — unknown flags to the verify path are silently ignored | `src/claimlint.zig:1697` | **confirmed** | A |
| R4 | `managent` non-numeric staleness override | `--stale-min abc` / `LIVENESS_STALE_MIN=abc` fall through `parseFloat` failure to the hardcoded 5.0 minutes with no diagnostic | `src/managent/main.zig:11421-11430` (same pattern in `cmdReap`) | **confirmed** | B |
| R5 | `bin/subagent` accepts any `--anything` | `parse_argv` stores every `--x` (bare or `=value`) without validating names; a typo is accepted and ignored. The space-separated form of a value flag not in the `("--model","--wall","--provider")` tuple (e.g. `--rss-cap-mb 4096`) misparses: the flag becomes boolean True and the value becomes a positional | `bin/subagent:428-444` | **confirmed** | B |
| R6 | `tools/attribution-backfill.py` lenient canonicalize | `canonicalize` passes unrecognized tags through unchanged (`ALIASES.get(raw, raw)`), and when `bin/managent` is absent it falls back to an in-file copy `FALLBACK_CANONICAL` — a stale-copy risk plus pass-through of unrecognized input. Contrast `tools/model_tags.py:165-177` which *raises* `UnknownModelTag` | `tools/attribution-backfill.py:109-118` (lenient), `:77-107` (fallback) | **confirmed** | B |
| R7 | `argus` doctor accepts retired liveness formats | the parser keeps backward compat for `[never beat` and `beats stopped` alongside the current `UNKNOWN — no assertion`; an old-format string is consumed as a valid present-day reading | `bin/argus:858-872` | **confirmed** | B |
| R8 | `argus` `_extract_command` reinterprets free text | if no backtick or em-dash convention matches, the **entire field string** becomes the command handed to the shell | `bin/argus:107-123` | **confirmed** | B |

**Union: 8 reinterpretation mechanisms (floor).**

Counter-examples both arms recorded (places that DO refuse): `managent` unknown *command*
(`unknown command: …`, exit 1 — `src/managent/main.zig:1521`); GTP unknown commands (`? unknown
command` — `src/gtp.zig:1845`); `claimlint` unknown verb (`src/claimlint.zig:1681`); `bin/dispatch`
unknown flag (`bin/dispatch:271`); `tools/fleet-keeper.sh` unknown argument (exit 2);
`tools/suite-truth.sh` unknown argument (exit 2); `tools/runner`/`bin/argus`/Python tools unknown
flags (stdlib `argparse`, exit 2); `tools/model_tags.py` strict boundary; `done --status nonsense`
(validated enum).

---

## §5 Shared jobs — two or more mechanisms doing the same thing

Arm A found **7**, arm B found **7**. They overlap on **2** jobs (model-label canonicalization, and
liveness). Union = **12** distinct jobs.

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

**Union: 12 shared jobs (floor).** Named, not ranked, not merged.

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
7. **The two arms themselves are untracked.** They are cited in prose ("arm A", "arm B"), never by
   path, per the commit gate. They survive only on the host that created them.

---

## §7 Four-way resolution of every contradiction

| # | question | arm A | arm B | verdict |
|---|---|---|---|---|
| Q1 | how many reporting surfaces? | 30 (behaviour-differs) | 68 (verb/mode enum) | **a third reading is better — both denominators are valid; pick 68 as primary (§1)** |
| Q2 | how many dishonest surfaces? | 6 | 6 (disjoint set) | **both right — union is 12, a floor** |
| Q3 | how many checks cannot fail? | 4 | 4 (disjoint set) | **both right — union is 8 (+ 8 unwired, a distinct category)** |
| Q4 | how many reinterpretation sites? | 3 | 6 (overlap of 1) | **both right — union is 8; R2 is A's instance of B's general property** |
| Q5 | how many shared jobs? | 7 | 7 (overlap of 2) | **both right — union is 12** |
| Q6 | regression script totals | 83 scripts, 7 unwired | 86 scripts, 8 unwired | **arm B right on the load-bearing count (8 unwired); arm A undercounts. Actual: 88 scripts, 80 wired, 8 unwired** |
| Q7 | purpose of `_sync` | UNKNOWN — "no tracked code writes `_sync`" | (not addressed) | **arm A wrong (misread): `writeSyncData` `src/managent/main.zig:9305` writes `_sync`; its purpose is the per-role message-read cursor for `managent sync`. The sibling defect (serializeState drops `_`-keys, so any other mutation erases them) is still accurate — that is C3, not this** |
| Q8 | purpose of `managent treekill` | (not addressed) | UNKNOWN — no brief/doc found | **arm B under-searched: the contract is in the help text (`src/managent/main.zig:8051`) and the module banner (`:11707`): enumerate/kill a process tree. A third reading is better** |
| Q9 | purpose of argus `--mode sweep`/`checklist` | UNKNOWN — no tracked consumer found | (checklist mode is dead — registry gone) | **arm A right: no production consumer (DARGUS runs `--mode doctor` only; `checklist` is exercised only by a regression test with a synthetic registry)** |
| Q10 | is the `_standing`/`_sync` key-drop a real defect? | yes (C3, documented in code) | (not addressed) | **arm A right — confirmed at `src/managent/main.zig:10689` and `:2727`** |

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

**No code, tests, or status documents were changed. Describing is the whole job.**