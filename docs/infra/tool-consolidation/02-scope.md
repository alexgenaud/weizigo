# T428 · Phase 2 — Scope: which tools are in, which are out, and why

| | |
|---|---|
| Sprint | T428 (tool consolidation), set S |
| Phase | 2 of 8 — **scope** |
| Writer | deepseek-v4-pro/T428.2 |
| Date | 2026-08-08 |
| Commit measured at | `9a96f8b` (HEAD, "Orcha: T431 closed pass; T428 sprint delegated to a single console for phases 2-8.") |
| Audit | pending — row to be registered and dispatched after this document is written |
| Status | PROPOSED — awaits independent audit before Phase 3 begins |

---

## 0. Phase 1 audit findings addressed

The Phase 1 audit (T429, glm-5.2, commit `0fc18b7`) returned PASS WITH FINDINGS. Three non-blocking
findings plus two process corrections from directive D066 — all addressed here before scope is drawn.

### F1 (measurement drift) — ADDRESSED

managent was stated as 6,451 lines in `01-strategy.md`; the actual count at the doc's own commit
was 6,455 (the file grew 4 lines before the doc was committed). This document measures everything at
a named commit (`9a96f8b`), every measurement via `git show 9a96f8b:<path> | wc -l`, so a later
reader can re-derive every number identically.

### F2 (method unspecified) — ADDRESSED

The subagent-pair overlap count ("120 common / 99 differing") was not reproducible without a stated
method. This document states the method precisely (§2.3): non-comment, non-blank, stripped lines;
`sort | uniq` per file; `comm -12` for common, `comm -23`/`comm -13` for unique. The actual numbers
are re-measured at `9a96f8b`.

### F3 (stale header) — CARRIED AS EVIDENCE

`src/claims_register.zig` line 18 says "Used by claimlint (checker) and absorb (knowledge-capture
tool)" — but claimlint does not import it (verified: `git show 9a96f8b:src/claimlint.zig | grep
"@import"` returns `std`, `version`, `util.zig` only; `git grep claims_register src/` returns only
`src/absorb.zig:34`). The module's own header contradicts the topology it describes. This is not a
footnote — it is P2 (five independent parser sites, silent divergence) stating itself in the source
code, and it is the central evidence for the claimlint+absorb merge. §3.1 below reproduces the stale
header and the measured topology side by side.

### D066 correction 1: measure at a COMMITTED tree — DONE

Every line count, import check, parser comparison, and overlap measurement in this document is taken
at commit `9a96f8b` via `git show`. A number a later reader cannot re-derive from this commit is not
used.

### D066 correction 2: dispatch own audits — IN EFFECT

This sprint console dispatches its own phase audits via `bin/ollama-subagent` or `bin/subagent`. No
hand-relay. The audit row for this document is registered by this console and dispatched by it.

---

## 1. Re-measured inventory at commit `9a96f8b`

| tool | language | lines (`git show 9a96f8b:<path> \| wc -l`) | concern | regression scripts |
|---|---|---|---|---|
| `managent` | Zig | 6,455 (`src/managent/main.zig`) | registration — kanban state | 12 |
| `weizigo-claimlint` | Zig | 3,200 (`src/claimlint.zig`) | verification — register/findings integrity | 3 |
| `weizigo-absorb` | Zig | 657 (`src/absorb.zig`) | transformation — findings → register | 1 |
| `argus` | Python | 1,923 (`bin/argus`) | watchdog — read-only sweep | 1 |
| `subagent` | Python | 205 (`bin/subagent`) | dispatch — DeepSeek path | 1 (subagent-prompt) |
| `ollama-subagent` | Python | 248 (`bin/ollama-subagent`) | dispatch — Ollama path | 1 (ollama-dispatcher) |
| **shared modules** | | | | |
| `claims_register.zig` | Zig | 449 (`src/claims_register.zig`) | register parser (absorb only) | — |
| `dispatch_verify.py` | Python | 258 (`tools/dispatch_verify.py`) | dispatch verification (both subagents) | 2 (shared) |
| `gen-indices` | Python | — (`tools/gen-indices`) | third register parser | — |
| `runner` | Python | — (`tools/runner`) | build/RSS guard | 1 |
| **total (six tools)** | 3 languages | **12,688** | — | 29 (`tools/regression-*.sh`) |

Note: subagent (205) and ollama-subagent (248) differ from the Phase 1 audit's numbers (193, 246)
because the audit was run at a different commit — the files grew 12 and 2 lines respectively between
`0fc18b7` and `9a96f8b`. Measuring at a named commit makes this detectable.

---

## 2. The parser topology — measured at `9a96f8b`, not described

Phase 1 established that `CLAIMS.md` is parsed at five sites. This section puts a diff under each so
Phase 4 (design) works from evidence, not recollection.

### 2.1 Site 1: claimlint's inline parser (`src/claimlint.zig`)

```
  git show 9a96f8b:src/claimlint.zig | grep "@import"
  → const std = @import("std");
  → const version = @import("version");
  → const util = @import("util.zig");
  // claims_register.zig is NOT imported
```

Functions: `parseRegister` (line 769), `parseStatus` (line 723), `parseNarrowed` (line 738),
`parseRate` (line 744), `backtickSpans` (line 753), `claimIdOf` (line 903), `isQaId` (line 915),
`Register` struct (line 713). These are **the same function names** as `claims_register.zig`'s public
API — the extraction at T194/D5 copied them out, and the inline copy has since diverged (handle
11-column format while the extracted copy still expected 10 until T406 fixed it).

The inline `parseRegister` at line 812 expects 11 columns: `if (first.len < 11) { ... }`. The
shared `claims_register.zig` at line 289 declares `REGISTER_COLS: usize = 11` (post-T406 fix).

### 2.2 Site 2: absorb's import of `claims_register.zig` (`src/absorb.zig`)

```
  git grep claims_register src/  (at 9a96f8b)
  → src/absorb.zig:34: const cr = @import("claims_register.zig");
```

The ONLY importer. This was the T406 victim — it called `parseRegister` from the shared module,
which silently returned 0 rows from a 221-row register because it expected 10 columns and got 11.
T406 made the empty parse a hard error (line 328: `if (reg.header_cols != REGISTER_COLS) { return
error... }`).

### 2.3 Site 3: `tools/gen-indices` (Python)

Mirror parser. Line 11: "Edge parsing mirrors src/claims_register.zig". This was the *second* T406
victim — same 10-column guard, same silent empty INDEX. T406 fixed it.

### 2.4 Site 4: managent's shallow read (`src/managent/main.zig`)

Line 4910+ (ORCHA-TOOLS R3): reads `docs/epistemic/CLAIMS.md` for citation checks. Shallow — parses
enough to extract citation paths from `d:`/`e:`/`n:` edges, not a full register parse. Does not
import `claims_register.zig`.

### 2.5 Site 5: argus's shallow read (`bin/argus`)

Line 1181: "CLAIMS.md row count vs register-tree-map.md §1". Shallow — row counting, not full
parse.

### 2.6 The stale header — F3 as evidence

`src/claims_register.zig` lines 18–19 (at `9a96f8b`):

> Used by claimlint (checker) and absorb (knowledge-capture tool). Extracted
> from claimlint.zig 2026-08-01 (T194/D5) so the absorption tool can read the
> register without duplicating the parser.

The actual topology at `9a96f8b`: claimlint does NOT import claims_register.zig. Absorb does.
The header describes the *intended* topology (the extraction was meant to deduplicate), and the
actual topology is the *divergent* one (claimlint kept its own copy, and the copies diverged
silently until T406). **This header is P2 stating itself in the source** — the module was created
to solve the problem and it did not solve the problem, and its own documentation says it did.

---

## 3. Scope decisions — by tool pair, with reasoning

The strategy's hypothesis (§7 of `01-strategy.md`) named two merge candidates and explicitly kept
argus out. This section makes binding scope decisions: IN, OUT, or ASSESS (for non-merge
interventions like parser extraction).

### 3.1 claimlint + absorb → IN (merge into one binary with verbs)

**Decision:** claimlint and absorb are merged into one Zig binary with subcommand verbs.

**Reasoning — the evidence case:**

1. **Same language** (Zig), **same primary data source** (`CLAIMS.md` + `findings/`), **same role**
   (Orchestrator at row close), and **same failure history** (both were the "safety net that broke"
   story of T404/T406).
2. **The register parser problem (P2) is the sprint's strongest single attack surface.** Merging
   these two tools forces ONE Zig parser — claimlint's inline copy is retired, `claims_register.zig`
   becomes the single source of truth, and the T406 shape (same register, two Zig verdicts, no
   alarm) becomes structurally impossible: if the parser is wrong, *both* verbs see the wrong data
   and the inconsistency is gone. The header at `claims_register.zig:18` is corrected to match the
   actual topology (§2.6 above is the evidence the fix is needed).
3. **Verify-then-transform is a pipeline**, not two unrelated operations. claimlint gates absorb:
   absorb should never propose an absorption if claimlint would reject it. One binary with `verify`
   and `absorb` verbs makes the pipeline visible in one help screen and one exit-code contract.
4. **Shared dependencies** already exist: both import `std`, `version`, and `util.zig`. Both parse
   the same file. The union of their regression suites (3 + 1 = 4 scripts) becomes the merged
   tool's suite — meeting the brief's "union of both suites, not a rewritten subset" bar.

**Costs / risks (to be argued as trades in Phase 4):**

- 3,200 + 657 ≈ 3,900-line binary: the second-largest tool after managent. A parser defect now
  hits both verbs at once — concentration of failure. Mitigation: the empty-parse hard error T406
  already added, plus the union-of-suites bar (Phase 3).
- Verify and transform are **different concerns**. The merge is only acceptable if the verb boundary
  keeps them distinct — `weizigo-claimlint verify` vs `weizigo-claimlint absorb`, with separate exit
  codes, separate stderr channels, and no shared mutable state between invocations.
- 6 → 5 tools is a modest count reduction. If the merge's only dividend is the count, it is not
  worth the risk. The dividend is one parser + one pipeline — the count is a side effect.

**Scope boundary — what is NOT merged:**
- The `gen-indices` Python parser (site 3) is a separate file in a separate language. It is not
  merged into the Zig binary; it is marked ASSESS below (§3.4).
- claim semantics (`CLAIMS.md` statuses, edges, C1–C10) are epistemic content, not tooling — out
  of scope (§4 of the strategy).

### 3.2 subagent + ollama-subagent → IN (merge into one script with a provider flag)

**Decision:** `bin/subagent` and `bin/ollama-subagent` are merged into one Python script,
`bin/subagent`, with a `--provider` flag (`deepseek` / `ollama`).

**Reasoning — the evidence case:**

1. **Already share the verification scaffold** (`tools/dispatch_verify.py`, imported by both). The
   non-comment, non-blank, stripped-line overlap measured at `9a96f8b`:

   ```
   method: grep -v '^[[:space:]]*#' <file> | sed '/^[[:space:]]*$/d' |
           sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | sort | uniq
   common (comm -12): 117 lines
   subagent-unique:    45 lines
   ollama-unique:      66 lines
   total distinct:    228 lines
   ```

   117 of 228 distinct lines are common — 51.3%. The differing lines are nearly all:
   - The provider-specific API call (subagent: DeepSeek API, ollama: `ollama run`)
   - Model-flag handling (ollama has `--model`, subagent infers from prompt)
   - The prompt file convention (ollama reads a brief file; subagent reads the brief + a
     DeepSeek-specific system prompt)

2. **Lowest risk.** The scripts are small (205 + 248 = 453 lines → merged ≈ 290 lines after
   dedup). A defect in the merged script affects dispatch, not the kanban store or the register.
3. **Operator's own suggestion** (T428 brief): "one `subagent` with a provider flag."
4. **Does not attack P2** (the register parser problem). This merge addresses P1 (proliferation)
   and P4 (test surface), but does nothing for the parser topology. The strategy's guard — "do not
   let the dispatch pair consume the sprint at the expense of the parser problem" — is binding:
   this merge is Phase 6 work but must not dominate the sprint's attention.

**Costs / risks:**

- The DeepSeek path requires an API key in the environment; the Ollama path requires a running
  local instance. The merged script's help must make the provider boundary obvious — a user who
  runs `bin/subagent` without `--provider` should get an error, not a cryptic API failure.
- The two paths currently have different depth-enforcement logic (ollama enforces depth ≤2,
  subagent doesn't). The merge must preserve both behaviors, not silently unify them.

**Scope boundary — what is NOT merged:**
- `tools/dispatch_verify.py` is already shared — no change needed. It stays as a separate module.
- The `T411` dispatch verification (nonce, deliverables) is preserved for both providers.

### 3.3 managent → OUT of merge scope

**Decision:** managent is NOT merged with any other tool.

**Reasoning:**

- **Registration is a unique concern** — no other tool writes the kanban. managent adds, claims,
  closes, reopens, dispatches, and sets task state. Every other tool is read-only or
  write-to-other-stores.
- **Scale and complexity:** 6,455 lines is more than the other five tools combined, and it has
  its own flock protocol, store schema, lifecycle semantics, and 12 regression scripts. Merging
  anything into it would be a rewrite, not a merge, and that is explicitly out (§4 of the
  strategy).
- **No parser duplication to resolve:** managent's shallow read of CLAIMS.md (site 4) is a
  citation-check concern, not a register-parse concern. It extracts enough to check that citation
  paths exist; it does not duplicate `parseRegister`. The cost of importing
  `claims_register.zig` for a shallow read is not justified by the reuse.
- **Precedent:** the assertion-ledger spec §10 ruled "no `bin/weizigo-assertion`" — managent
  writes, argus reads. Folding a reader into the writer blurs the boundary the precedent was
  written to protect.

**What managent MAY gain from this sprint:**
- If the merged claimlint+absorb binary exposes its parser as a library (Phase 4 decision),
  managent could optionally import it for its shallow CLAIMS.md reads. This is a Phase 4 design
  question, not a Phase 2 scope decision — it is noted here as "assess in design, do not commit
  now."

### 3.4 argus → OUT of merge scope, ASSESS for parser reuse

**Decision:** argus is NOT merged with any other tool. It MAY consume the shared parser if Phase 4
exposes one, but that is a consumer relationship, not a merge.

**Reasoning:**

- **Display/watchdog is a distinct concern** from every writer. The operator's own ruling is
  binding: "registration and display are different concerns" (T428 brief). The assertion-ledger
  spec §10 is binding: "managent writes it; argus reads it. No `bin/weizigo-assertion`."
- **Python vs Zig:** argus (Python) consuming a Zig parser would require either a Zig→Python
  bridge (overengineered), or argus calling the merged claimlint+absorb binary for parse output
  (a shell-out, feasible but adds latency). Phase 4 assesses whether this is worth it.
- **argus's CLAIMS.md read is shallow** (site 5: row counting, not full parse). The cost of a
  full parser dependency for a row count is high; the benefit is modest. Phase 4 decides.

### 3.5 gen-indices → ASSESS

**Decision:** `tools/gen-indices` is the third register parser (site 3, Python). It is a candidate
for either (a) consuming the shared Zig parser's output (if Phase 4 exposes one), or (b) being
rewritten to call the merged binary. It is NOT merged into the claimlint+absorb binary (different
language, different role — index generation is a build step, not a row-close step).

**Phase 4 question:** can `gen-indices` call `weizigo-claimlint parse --json` (or similar) and
consume structured output, retiring its mirror parser? This is worth assessing but not committing
to in scope.

### 3.6 tools/dispatch_verify.py → OUT (already shared, no change needed)

Already imported by both subagents. The subagent merge (§3.2) uses it as-is. No scope action.

### 3.7 tools/runner → OUT (orthogonal concern)

Build/RSS guard, orthogonal to the delegation toolchain. Out of scope unless a phase argues
otherwise — the strategy's §4 already placed it here.

---

## 4. Scope summary table

| tool | scope decision | action | attacks which pain |
|---|---|---|---|
| `weizigo-claimlint` | IN (merge with absorb) | merge into one Zig binary with `verify`/`absorb` verbs | P1, P2, P3, P4 |
| `weizigo-absorb` | IN (merge with claimlint) | same binary, `absorb` verb | P1, P2, P3, P4 |
| `bin/subagent` | IN (merge with ollama-subagent) | merge into one Python script with `--provider` flag | P1, P4 |
| `bin/ollama-subagent` | IN (merge with subagent) | same script, `--provider ollama` | P1, P4 |
| `managent` | OUT | no merge; may gain parser import in Phase 4 (assess) | — |
| `argus` | OUT | no merge; may consume parser output in Phase 4 (assess) | — |
| `tools/gen-indices` | ASSESS | may consume merged parser output in Phase 4 | P2 |
| `tools/dispatch_verify.py` | OUT | already shared; subagent merge uses it as-is | — |
| `tools/runner` | OUT | orthogonal | — |

**Tool count after consolidation (if both merges ship):** 6 → 4 (managent, claimlint+absorb,
subagent, argus), plus gen-indices.

---

## 5. What changes at the `bin/` level

Current `bin/` entry points (built + deployed):

| current | after |
|---|---|
| `bin/managent` | `bin/managent` (unchanged) |
| `bin/weizigo-claimlint` | `bin/weizigo-claimlint` (same name, now with `verify` and `absorb` verbs) |
| `bin/weizigo-absorb` | **retired** — `bin/weizigo-claimlint absorb` replaces it |
| `bin/argus` | `bin/argus` (unchanged) |
| `bin/subagent` | `bin/subagent` (now with `--provider deepseek\|ollama`) |
| `bin/ollama-subagent` | **retired** — `bin/subagent --provider ollama` replaces it |

**Cutover rule (from brief §Bar 2):** the old entry points stay alive during the transition.
`bin/weizigo-absorb` becomes a thin shell wrapper that calls `bin/weizigo-claimlint absorb "$@"`
and emits a deprecation notice on stderr. Same for `bin/ollama-subagent` →
`bin/subagent --provider ollama`. The wrappers are removed in a separate commit after every console
has been updated — a stated cutover, not a surprise.

---

## 6. Eight-quality score for the scope decisions

Scored at scope level (design trade-offs are Phase 4):

| quality | claimlint+absorb merge | subagent pair merge | combined effect |
|---|---|---|---|
| **reuse** | `+` — one parser instead of two; `claims_register.zig` becomes single source of truth | `+` — 117 common lines deduped; one script instead of two | `+` — 3→1 register parsers in Zig (gen-indices TBD); 2→1 dispatch scripts |
| **testability** | `+` — union of suites (3+1=4); one binary, one test harness | `+` — union of suites (1+1+2 shared=4); shared `dispatch_verify.py` already tested once | `+` — test count preserved or increased |
| **predictability** | `0` — verb boundary (verify/absorb) must be crisp; Phase 4 must demonstrate | `0` — `--provider` flag is a well-understood pattern; error on missing flag | `0` — neither merge introduces hidden modes |
| **transparency** | `+` — one help screen shows the pipeline; `2>/dev/null`/`1>/dev/null` contract preserved per verb | `+` — one help screen shows both providers; dispatch trace visible | `+` — fewer entry points to discover |
| **stability** | `−` — largest change: 3,900-line binary replaces two; cutover wrappers must work | `0` — small scripts, low blast radius | `−` — claimlint+absorb merge is the risky one; the subagent merge is safe |
| **agility** | `+` — one build target instead of two; a parser fix ships in one file | `+` — one file to edit for dispatch changes | `+` — fewer files touched per fix |
| **performance** | `+` — one build, one deploy; suite still runs the same scripts | `+` — one Python invocation check instead of two | `+` — marginal improvement |
| **separation of concerns** | `−` — verify and transform in one binary is a trade; §10 precedent says the verb boundary must hold | `0` — dispatch is one concern; the provider flag separates mechanism from policy | `−` — the claimlint+absorb merge must argue this trade explicitly in Phase 4 |

Two `−` entries: both on the claimlint+absorb merge, both anticipated by the strategy's own evidence-against
(§7 of `01-strategy.md`). Neither is hidden. The subagent merge has no `−` — it is the low-risk, low-reward
half of the sprint. The claimlint+absorb merge is the high-risk, high-reward half.

---

## 7. What is explicitly OUT (re-stated from strategy §4)

1. **The goban engine** (`src/retro.zig`, `oracle.zig`, `rules.zig`, `solve.zig`, `vb_*` modules,
   mutants).
2. **The kanban data model** (`tasks.json` schema, lifecycle semantics, flock protocol).
3. **Claim semantics** (CLAIMS.md statuses, `d:`/`e:`/`n:` edges, C1–C10 check semantics).
4. **The assertion-ledger design** (`docs/infra/assertion-ledger/spec.md`).
5. **A rewrite** — no tool is re-implemented "more cleanly" for its own sake. Merges preserve behavior
   and tests. A rewrite that re-derives behavior from the spec is out.
6. **The live kanban** — all exercises use `MANAGENT_STORE`; `tasks.json` is verified byte-identical
   before and after every exercise.

---

## 8. Phase 2 question answered

The Phase 2 question from the brief: *which tools are in, which are explicitly out, and why?*

- **IN:** claimlint+absorb (merge into one Zig binary with `verify`/`absorb` verbs); subagent+ollama-subagent
  (merge into one Python script with `--provider` flag).
- **OUT:** managent (unique concern, too large to merge without rewrite); argus (display/watchdog is a
  distinct concern per §10); dispatch_verify.py (already shared); runner (orthogonal).
- **ASSESS:** gen-indices (Phase 4 decides whether it can consume the merged parser's output).
- **Why:** the evidence case above (§3.1–§3.7) cites P1–P4, the stale header at `claims_register.zig:18`,
  the operator's own suggestion, the §10 precedent, and the strategy's own evidence-against. Both IN
  decisions are falsifiable: the refutation criteria from strategy §7 apply to both merges; if Phase 3's
  acceptance suite cannot express the union of suites, or if Phase 4's verb boundary blurs §10, the merge
  fails.

---

**Landmark:** advances `L4 (the ledger is clean)` — scope now names exactly two consolidation targets,
both measured at a named commit, both scored against the eight qualities with `−` entries named not hidden,
and both bounded by the strategy's "documented no is a success" escape hatch. What remains: Phase 3
(acceptance) must write the tests before any design, and an independent audit must verify this scope
document.

**Human summary:** two merges are in scope — claimlint+absorb (one Zig binary, one parser, attacks the
T406 silent-divergence shape at its root) and subagent+ollama-subagent (one Python script, `--provider`
flag, low-risk dedup). managent and argus stay separate per the §10 registration/display precedent.
gen-indices is assessed in Phase 4. Every measurement is at commit `9a96f8b`; every Phase 1 audit
finding (F1–F3) and D066 correction is addressed. Next: independent audit, then Phase 3 acceptance tests.
