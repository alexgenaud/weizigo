# Census method — the denominator, not another arm

**Task:** T898 · **Worker:** claude-sonnet-5 · **Date:** 2026-08-24
**Landmark:** advances `L1 (the dashboard tells the truth)` — stream2-whatis, the row that answers
*what is the denominator?* instead of drawing a fourth sample.

**Why this row exists.** Three blind arms (T858, T860, T869 — the `stream2-whatis/whatis.md`
union) produced **48 distinct sites**, of which **94% were found by exactly one arm**. Near-zero
overlap between independent samples is the signature of sampling a population much larger than the
sample, not of thoroughness. This row stops sampling and counts the population instead.

**Do not classify.** Per the brief's own constraint, this document produces a method and a
denominator. It does not judge any emission point honest or dishonest — that is the classification
wave's job, and it needs this row's inventory first.

---

## §1 What is a "site"? — the emission point, defined

Before this row, "site" meant, loosely, "a place one of four defect classes occurs" — a unit
defined by its *symptom*. A census needs a unit defined by its *existence*, independent of whether
anything is wrong with it.

**Definition.** An **emission point** is a call site, in tracked source, that either

  (a) places bytes on **stdout** — the channel this repository's own code already declares, in two
      independent places, as the fact channel: `src/util.zig:1-4` ("`out()` → stdout
      (parseable/filterable/redirectable output). `note()`/`warn()` → stderr (diagnostics,
      progress, warnings, errors)"), and `src/managent/main.zig:33-54` (`Writers.data` — "Write data
      to stdout — anything a caller might parse, filter, or redirect" — versus `Writers.diag` —
      "Write diagnostics to stderr"); or

  (b) **ends the process** with an observable exit status (`std.process.exit`, `sys.exit`,
      `os._exit`, a bare shell `exit N`) — the one fact every caller can read without reading a
      single byte of output.

**Excluded, by rule, not by omission: stderr.** Diagnostics, progress chatter, and warnings are not
counted. This is not a convenience — it is the boundary the code itself draws, in two places,
independently (`util.zig` and `main.zig`'s `Writers`), which is itself the first finding of this
census (§4). The exclusion is not silent: the script counts and reports how many diagnostic calls it
excluded, so the boundary is inspectable rather than asserted (764 in the current tree — see §2).

**What is out, explicitly:**
- **Comments and prose.** Only executable call sites count.
- **`return` statements.** A function returning a value to its caller *inside the process* is
  control flow, not emission — the brief's own hint (item 1) is right to distinguish "the unit of
  enumeration" from "the unit of defect," and internal returns are neither: enumerating all ~60,000
  Zig `return` statements in this repository would not answer "how many facts does this repo tell a
  human," it would just count the language's control-flow density.
- **File writes read back by other tooling as data** (e.g. a findings JSON, `store-census.json`).
  These are real facts and a real future category, but they need a different mechanical rule (which
  writes are read back as fact vs. which are scratch/log) that this pass does not yet have. Named
  as a blind spot, not silently folded into stdout (§5).
- **Engine-side Go tooling** (`weizigo-arena`, `weizigo-oracle`, `weizigo-gtp`,
  `weizigo-engine-vs-engine`, `weizigo-reachcensus`, `weizigo-chainability`, and the ~100
  research/experiment files under `src/*.zig` not part of the dispatcher or a checker). The brief's
  own scope (item 2) names `bin/*`, `tools/*`, `src/managent`, the hooks, and the checkers —
  deliberately not the whole tree. This matches whatis.md §6 item 6, which already named the
  engine-side tooling as unexamined by all three arms; this census does not close that blind spot
  either, and says so rather than quietly enumerating the whole repository to look complete.

**Scope, precisely** (git-tracked only — an untracked path is not citable per the commit gate):
`bin/argus`, `bin/dispatch`, `bin/subagent`; every tracked file under `tools/`; `src/managent/*.zig`;
`src/claimlint.zig` and `src/absorb.zig` ("the checkers" — `weizigo-claimlint`, `weizigo-absorb`).

---

## §2 The instrument — a committed, re-runnable script

**`tools/emission-census.py`** (committed alongside this document). It does not read files by
eye — it parses. Python files are walked with the standard library's `ast` module (a real parse,
not a regex guess at where a string ends); Zig and shell files, which have no equally convenient
parser here, are scanned with a small set of literal, documented call-form patterns (§1's two
citations) rather than a general-purpose grammar — named as the weaker leg of the method (§5).

Run: `python3 tools/emission-census.py` (`--json` for the full inventory, `--self-test` for the
controls below).

**Not yet wired into `zig build test`.** `build.zig` is held, uncommitted, by another in-flight
row (T891) at the time this document is written; landing a second hunk there now would stage and
commit that row's unreviewed work under this task's message — precisely the shared-index hazard
`tools/git-commit-mine`'s own header names (T268/T278). Wiring this script into the suite (so it
does not join the eight-unwired-checker class whatis.md §3b exists to name) is named here as owed,
explicit follow-up work, not silently skipped — the same "no silent gaps" rule this document holds
everything else to.

### The count, as of HEAD `21c7689`-dirty, 2026-08-24

| | scope files | files w/ ≥1 emission point | stdout | exit | **total** | diagnostics excluded |
|---|---|---|---|---|---|---|
| **everything in scope** | 154 | 125 | 5,580 | 424 | **6,004** | 764 |
| — of which `tools/regression-*.sh` (90 files) | | | | | 4,527 | |
| **product surfaces** (scope minus regression scripts) | | 35 | | | **1,477** | |

**The population is not one number — it forks on a real methodological choice, named rather than
picked silently.** 75% of the raw total (4,527 of 6,004) is test-narration inside
`tools/regression-*.sh` — each script's own `echo "PASS: ..."` / `echo "FAIL: ..."` lines announcing
its assertions passed or failed. That is a fact a human reads, so it is honestly an emission point
by §1's definition — but it is a fact about a *test*, not a fact about the *product*, and it is not
the kind of surface any of the three arms were enumerating (none of D1–D15/C1–C10/R1–R9/J1–J14 cites
a regression script's own PASS/FAIL narration as the defect). **Both denominators are reported; §3
uses the 1,477 product-surface figure** as the one commensurable with the three arms' union, and
names the 6,004 figure as the honest total of everything this census's rule actually catches.

Neither number is "68," arm B's reporting-surface count from whatis.md §1 — and it should not be:
arm B counted at the grain of **one row per CLI verb/mode** (`managent orient` is one row for six
sub-readings); this census counts at the grain of **one row per print/exit call site**. `orient`
alone contains dozens of `w.data(` calls behind that one verb. The two denominators measure
different things and neither converts to the other by a formula — see §3 for how they are reconciled
without pretending they are the same unit.

---

## §3 Controls — the count does not count until it has caught what it must catch

Per the brief's acceptance condition 2, and the sprint's own instrument doctrine (never trust a
green reading with no seeded-defect control): `tools/emission-census.py --self-test` runs both,
against synthetic scratch trees under `tempfile.TemporaryDirectory` (never the live repo):

```
$ python3 tools/emission-census.py --self-test
null control:   0 emission points on a call-free tree (5 scope files) — PASS
seeded control: 6 stdout + 3 exit planted, all found; 4 diagnostics planted, all
correctly excluded — PASS
```

- **Null control.** A scratch tree with the right file shapes (a `src/managent/main.zig`, a
  `src/claimlint.zig`, a `src/absorb.zig`, a `tools/example.py`, a `tools/example.sh`) but zero
  calls of any kind. The census reports **0**, not an error and not a vacuous skip — proving it
  distinguishes "nothing found" from "nothing scanned."
- **Seeded-defect control.** The same tree shape, each file now carrying two stdout emissions, one
  exit emission, and one-or-two diagnostic calls in the excluded forms (`util.note`, `std.debug.print`,
  `print(..., file=sys.stderr)`, `echo ... >&2`). The census must find **exactly** 6 stdout + 3 exit,
  and must report exactly 4 diagnostics excluded — not "some," not "at least." A script that merely
  didn't crash on real code is not the same as a script proven to fire on a planted true positive and
  stay silent on a planted true negative in the same run; both are required together (`--self-test`
  fails if either count is off by one), matching the acceptance test the sprint has already used for
  `regression-store-census.sh`.

**A third, unplanned corroboration on real code**, found while validating the tool rather than staged
for it: `tools/model_tags.py` — the file R6 in whatis.md names by contrast as "the strict reader"
that `raises UnknownModelTag` instead of printing — scores **zero** emission points. That is not an
instrument failure; it is the file behaving exactly as whatis.md's own citation says it does (it
raises, it does not emit), which is independent confirmation the rule generalizes past the synthetic
fixtures. Two other whatis.md-cited files, `tools/regression-runner-host-guard.sh` and
`tools/regression-subagent-resident-gate.sh` (C5/C6, the "retired stubs [...] cannot be repaired into
passing"), also score zero — because they no longer exist: T872's delete wave (`12e7055`) removed both
the same evening. Confirmed via `git log --diff-filter=D`. This is not a bug either; it is the
post-audit drift whatis.md already names for a sibling case (D11/C8, the deleted `claimlint-green`
slug) — the census, run today, correctly sees today's tree.

---

## §4 The many-ways-to-do-one-job class, ranked by drift

whatis.md §5 already counts 14 shared-job clusters (J1–J14). This census adds concrete, file:line
detail to three of them and ranks the union by **how far the copies have actually diverged**, per
the brief's instruction (drift is the defect, not duplication itself). **Nothing is deleted; the
production copy is named and the rest are demoted to fixtures/oracles**, per the sprint's own rule.

| rank | job | copies (production copy marked ▶) | drift observed |
|---|---|---|---|
| 1 | **model-label canonicalization** (J1) | ▶ `src/managent/main.zig` `canonical_models[]`/`serving_tag_map` (`:249`); `bin/dispatch` `MODELS`/`canonicalize_model` (`:120-155`); `bin/subagent` `PI_TAG_TO_CANONICAL`/`CANONICAL_TO_OLLAMA_TAG`/`CANONICAL_TO_PI_TAG` (`:190-219`); `tools/model_tags.py` (strict); `tools/attribution-backfill.py` (lenient + stale fallback, `:77-118`) | **Highest drift of the set.** Three independent label↔tag tables (managent, dispatch, subagent) plus two independent readers (strict/lenient) — five copies of one fact. `bin/subagent`'s own comment at `:200-211` admits the shape: it re-derives the live tag "instead of passing raw_model through," specifically because it was *not* immune to a defect `bin/dispatch` already didn't have — and the fix (T890) is a **regression guard that asserts the copies agree**, not a unification. The guard is `tools/regression-serving-tag-single-path.sh`; agreement is tested, not structural. |
| 2 | **the stdout/stderr split itself** (new; not in whatis.md's 14) | ▶ `src/util.zig` `out()`/`note()`/`warn()` (`:37-51`, used by `claimlint.zig`, `absorb.zig`, and ~20 other `src/*.zig` files); `src/managent/main.zig` `Writers.data()`/`Writers.diag()` (`:35-54`), independently built for one file | The architecture — "stdout for data, stderr for diagnostics" — is duplicated at the level of *design*, not just helper code: two structurally near-identical doc comments (compare `util.zig:1-4` to `main.zig:33-34`), two independent implementations, never unified into one shared module despite living in the same `src/` tree and being invoked by the same binary family. This is why §1's definition needed two citations instead of one — the census itself is evidence of the drift it had to route around. |
| 3 | **per-provider argv construction** (part of J5, dispatch paths) | `bin/subagent`, one `elif` chain, four bodies: `deepseek` (`:833-849`), `claude` (`:850-867`), `pi` (`:868-878`), `ollama` (`:879-889`) | Four independently-shaped `cmd` lists for the same job ("build the argv for `tools/runner`"): the prompt lands as a trailing positional in three of four and inside a `--session ... -p` pair in the fourth; `--model` carries the canonical label in one branch and the derived live tag in three; the ollama branch wraps its inner `pi` invocation inside an `ollama launch pi ...` shell not present in any other branch. The brief calls this "drifted twice" — each provider's addition (T732 pi, T890 live-tag derivation) touched one branch and not the others' shared shape. |

**Method note.** Ranking by drift, not duplication count, means J1 (5 copies) outranks a
hypothetical 6-copy cluster that all agreed byte-for-byte — agreement, even duplicated, is not the
risk; divergence is. Row 1 and row 3 both involve the *same* underlying fact (canonical label →
serving tag) at two different altitudes (the table vs. the argv that consumes it); they are counted
once each because the drift each names is a different mechanism (which table is authoritative, vs.
how the resolved value is threaded into four dissimilar command shapes).

---

## §5 Round trips — where a defect invisible in one function is obvious end to end

The brief's item 3 asks for round trips, not files. Two are traced here, grounded in the citations
this row and whatis.md have already opened; both are illustrative, not an exhaustive catalogue (that
catalogue is stream4's job, once classification exists).

**Round trip A — dispatch → run → record → close → report.**
`bin/subagent` resolves the model and builds argv (§4 row 3) → launches under `tools/runner`, which
propagates `MANAGENT_TASK_ID` and emits a per-lane heartbeat (`tools/runner:88-97`) → the worker calls
`bin/managent claim`/`done` (`cmdClaim` `src/managent/main.zig:3915`, `cmdDone` `:4687`) → the row's
state is read back by `managent orient`/`resume`/`status` (`cmdStatus` `:6042`, `cmdOrient` `:6949`).
**Reading `cmdOrient` alone does not show D1/D2** (the missing-floor-key-emits-0, the swallowed
lanes-scan error) — those are visible only by walking claim→…→orient and asking "what does the
*reader* see when the *writer* failed silently," which is exactly this round trip.

**Round trip B — register → claim → commit → verify.**
A findings JSON is written (`findings/<id>-<slug>.json`, `findings/README.md`'s schema) → a worker
runs `bin/managent claim`/`done` → `git commit` invokes `tools/hooks/pre-commit`, which resolves
`weizigo-claimlint` (`tools/hooks/pre-commit:56-67`) and runs it before the commit lands
(`:209-224`) → `claimlint c7`/`verify` reads the findings file against `CLAIMS.md` and either passes
or blocks (`src/claimlint.zig`, dispatch at `:1645-1657`). The round trip is where R2 (the
unknown-flag drop) actually bites: a mistyped flag anywhere in this chain is silently accepted by
`managent`'s dispatcher and only the *separate* impression gate — a backstop for the same defect —
catches a resulting bad close (whatis.md §3c, §8 S7). Reading `cmdDone` in isolation shows the
default; only the round trip shows why the default matters.

---

## §6 The three arms against the denominator — the coverage fraction

**Unit mismatch, named before it is glossed over.** whatis.md's 48 sites are *mechanisms* (a check
that cannot fire, a value that stands in for absence, a reinterpretation, a shared job) — each one
typically **cited at the mechanism's cause** (a `catch null`, a default branch, a missing case), not
at the print/exit call that later surfaces its effect. Emission points, as this census counts them,
are the print/exit calls themselves — typically *downstream* of the mechanism. D2's citation, for
example, is `scanLanes(...) catch null` at `main.zig:7010`; the `w.data(...)` call that actually
prints the (possibly silently-omitted) `lanes:` line is a different line entirely. **Line-level
overlap between the union and this census is therefore not a meaningful fraction to compute** — the
two artifacts are looking at adjacent but distinct points in the same control-flow graph.

**File-level coverage is the honest grain.** Of the 48 union sites, the distinct **in-scope** files
they cite are: `src/managent/main.zig`, `src/claimlint.zig`, `bin/argus`, `bin/dispatch`,
`bin/subagent`, `tools/runner`, `tools/suite-truth.sh`, `tools/dispatch_verify.py`,
`tools/attribution-backfill.py`, `tools/model_tags.py`, `tools/fleet-keeper.sh`,
`tools/git-commit-mine-lib.sh`, `tools/orcha-acceptance.sh`, `tools/regression-arbiter.sh`,
`tools/regression-managent-done-git.sh`, `tools/regression-managent-memory-safety.sh`,
`tools/regression-process-ownership.sh`, `tools/regression-race-collect.sh`,
`tools/regression-request-accounting.sh`, `tools/regression-scratch-repo.sh`,
`tools/regression-task-identity.sh`, `tools/regression-runner-host-guard.sh`,
`tools/regression-subagent-resident-gate.sh` — **23 files.** Two of those (the last two) no longer
exist (§3) and one (`tools/model_tags.py`) legitimately emits nothing (§3) — **20 files the arms'
findings actually land in**, out of a possible **23**.

```
coverage = (files the three arms actually touched) / (files this census found to have ≥1 emission point)
         = 20 / 125  =  16.0%           (against the full in-scope population)
         = 20 / 35   =  57.1%           (against the "product surfaces" population, §2)
```

**Arithmetic, shown rather than asserted.** 125 is the file-count row of §2's first table (files
with ≥1 emission point across the whole 154-file scope, regression scripts included); 35 is the
non-regression "product surfaces" row. The three arms never opened a `regression-*.sh` file except
the ones whatis.md's §3a/§3b already name (the two retired stubs and the "8 unwired" set) — so the
57.1% figure is the fairer one for "how much of the surface the arms were actually sampling from have
they covered," and the 16.0% figure is the honest one for "how much of everything this rule catches."
**Both are floors, not totals** — a file with zero union citations was not verified clean, only
unvisited.

---

## §7 Is a fourth reading pass warranted?

**No — not another blind arm.** The brief's own framing is the correct one, and this census's
numbers make the case, not just the argument: with a **57.1%** file-level gap on the very population
the three arms were sampling from (§6), and **1,477 individual product emission points** now
enumerated with none of them yet classified, a fourth arm would do exactly what the third one did —
draw another disjoint sample and add a few more single-arm rows to a union that is already 94%
single-arm. That teaches the sprint the terrain is big, which it already knows. **What is not yet
done is classifying the population that is already enumerated** — walking the 1,477 product
emission points (or the 35 files that hold them) and marking each honest / dishonest / not-yet-looked-at,
which turns "45 of 48 sites are single-arm, provisional" into an actual coverage number that rises
monotonically as real work happens, instead of a sample count that rises because more people keep
drawing.

**The one class a mechanical enumerator provably cannot see, named concretely rather than gestured
at:** file *writes* read back as data (findings JSON, `store-census.json`, run records) are outside
this census's rule (§1) — a write-then-misread round trip (the write is honest, the reader
mis-parses it, or vice versa) requires reading the writer and the reader together, which is exactly
the round-trip method of §5, not a bigger grep. That is the one kind of future pass this document
can defend: not a fourth blind sample of "what looks wrong," but a targeted extension of *this*
census's own rule to cover file-based facts, followed by classification. Everything else the arms'
blind spots named (engine-side Go tooling, full reads of ungrepped shell scripts, live reproduction
of `could`-grade findings) is real work, but it is **classification-adjacent, not enumeration-shaped**
— it does not need a fourth arm's method, it needs the classification wave whatis.md §9 already
called for.

---

## Acceptance, checked against the brief

1. **Committed inventory with a count, from a re-runnable script:** `tools/emission-census.py`,
   `python3 tools/emission-census.py --json`. Count: 6,004 total / 1,477 product-surface (§2).
2. **Null + seeded-defect controls:** `--self-test`, both PASS, plus unplanned corroboration on real
   code (§3).
3. **Coverage fraction, with its arithmetic:** §6 — 16.0% of the full population, 57.1% of the
   population the arms were actually drawing from.
4. **Is a further reading pass warranted:** §7 — no blind arm; the named exception is a rule
   extension (file-write facts), not a fourth sample.
