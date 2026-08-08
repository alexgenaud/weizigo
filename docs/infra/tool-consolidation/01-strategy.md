# T428 · Phase 1 — Strategy: what problem is consolidation solving, and what would tell us it failed?

| | |
|---|---|
| Sprint | T428 (tool consolidation), set S |
| Phase | 1 of 8 — **strategy** |
| Writer | deepseek-v4-flash/T428 |
| Date | 2026-08-08 |
| Audit | T429 (different agent — pending dispatch; this document is not accepted until its audit PASSes) |
| Status | PROPOSED — awaits independent audit before Phase 2 begins |

---

## 1. The operator's ask

> "I think we should consolidate (and/or separate by concerns) the many tools: managent, argus,
> claimlint, absorb, subagent, ollama-subagent. Particularly those written in the same language
> used by the same agent roles, with similar purpose should be combined, tested, and optimized."
> — operator, 2026-08-08 (T428 brief)

> "I do not want utility or tool proliferation. I want reuse, testability, predictability,
> transparency, stability, agility, performance, separation of concerns."
> — operator constraint, 2026-08-08 (T428 brief)

This document answers the Phase-1 question — *what problem is consolidation solving, and what
would tell us it failed* — with the toolchain measured, not described. Every claim below cites
the file or commit it was measured from. Nothing in this document is a design decision; the
design (one binary with verbs? a shared library?) is Phase 4. Phase 1 sets the problem, the
yardstick, the refutation criteria, and the hypothesis to test.

## 2. The measured inventory

| tool | language | lines (measured 2026-08-08) | concern | calls it | regression scripts |
|---|---|---|---|---|---|
| `managent` | Zig | 6,451 (`src/managent/main.zig`) | registration — kanban state | every agent | claim-lifecycle, done-git, done-two-phase, integrity, lock, memory-safety, resume, standing, task-identity, duplicate-dispatch, inbox-loop, directive-integrity |
| `weizigo-claimlint` | Zig | 3,200 (`src/claimlint.zig`) | verification — register/findings integrity | Orchestrator, every row at close, pre-commit gate | claimlint-output, claimlint-promotion, claimlint-volatile |
| `weizigo-absorb` | Zig | 657 (`src/absorb.zig`) | transformation — findings → register | absorb rows | absorption-machinery |
| `argus` | Python | 1,923 (`bin/argus`) | watchdog — read-only sweep (checklist/sweep/doctor) | Orchestrator, operator | argus-doctor |
| `subagent` | Python | 193 (`bin/subagent`) | dispatch — DeepSeek path | sprint consoles | subagent-prompt, dispatch-verification |
| `ollama-subagent` | Python | 246 (`bin/ollama-subagent`) | dispatch — Ollama path | sprint consoles | ollama-dispatcher, dispatch-verification, depth-enforcement |
| **total** | 3 languages | **12,670** | — | — | 29 scripts in `tools/regression-*.sh` |

Plus shared modules that already exist — the reuse the fleet already has, to be preserved, not
invented:

- `src/claims_register.zig` (449 lines) — register parser, imported by **absorb only**.
- `tools/dispatch_verify.py` (258 lines) — worker-work verification, imported by **both subagents**.
- `tools/gen-indices` (Python) — **third** register parser (see §3).
- `tools/runner` — build/RSS guard, orthogonal to the six; out of scope unless a phase argues otherwise.

## 3. The problem consolidation solves — four named pains, each with evidence

### P1 — Tool proliferation: six entry points, three languages, one role's workflow spans four of them

Every row close runs, in order: `managent done` (registration) → `weizigo-claimlint`
(verification) → `weizigo-absorb` (transformation) → commit via `tools/git-commit-mine`. A
single Orchestrator workflow walks four tools in two languages. An agent at session start walks
`managent claim` → possibly `subagent`/`ollama-subagent` dispatch. The operator's question "who
runs what, why three CLIs for one workflow?" is answered only by reading three spec files
(`docs/infra/managent/spec.md`, `src/claimlint.zig` header, `src/absorb.zig` header).

Proliferation is not decorative: each tool is a build/deploy path (`build.zig` installs several
binaries), a set of regression scripts, a staleness check in `tools/smoke.sh`, and a parser of
at least one shared data source. Six tools × (build + test + deploy + parse) is the maintenance
surface.

### P2 — The register is parsed at FIVE independent sites; T406 proved they diverge SILENTLY

`docs/epistemic/CLAIMS.md` is read by, at minimum, five sites in three languages:

| # | site | language | how it reads | notes |
|---|---|---|---|---|
| 1 | `src/claimlint.zig` (≈line 711+) | Zig | full parser, inline copy (`Register`, `parseStatus`, `parseRate`, `backtickSpans`, `parseRegister`, `claimIdOf`, `isQaId` — same function names as `claims_register.zig`) | the checker's own copy |
| 2 | `src/absorb.zig` via `src/claims_register.zig` | Zig | full parser, the *shared* one (header: "Extracted from claimlint.zig 2026-08-01 (T194/D5)") | **the T406 victim** |
| 3 | `tools/gen-indices` | Python | mirror parser ("Edge parsing mirrors src/claims_register.zig") | **the second T406 victim** |
| 4 | `src/managent/main.zig` (ORCHA-TOOLS R3, line 4910+) | Zig | wholesale read for citation checks | shallow, but a reader |
| 5 | `bin/argus` (row-count vs register-tree-map, line 1181) | Python | row-count/floor checks | shallow, but a reader |

The T406 incident (commit `b1c443f`, 2026-08-08) is the proof that this topology is broken:
the register moved to an 11-column format (T305), the **shared parser (`claims_register.zig`)
still expected 10 columns, and it returned "0 rows" from a 221-row register without erroring** —
`weizigo-absorb` reported "nothing to do" (T404 had to absorb by hand) and `gen-indices` wrote
empty INDEX files while reporting success. The forked copy inside `claimlint.zig` happened to
handle 11 columns, so the same file got **two verdicts on the same day: claimlint said 221 rows,
absorb said 0.** Nothing flagged the disagreement; a hard error had to be added by T406.

The T428 brief's phrase "they share a parser — by finding it broken in both" is, measured
precisely: claimlint and absorb were *meant* to share (claims_register was extracted from
claimlint for exactly that purpose, T194/D5) but claimlint today does **not** import it — it
carries its own copy. The result is **three full register parsers in two languages, none of
which can detect divergence from the others.** T406 caught one divergence; the strategy must
treat the other two as latent.

### P3 — The failure mode of this toolchain is "reports success while doing nothing"

The defect week of 2026-08-03 was entirely tooling (AGENTS.md standing table):

| defect | shape |
|---|---|
| `t387_budget.zig` infinite loop | only manifests under ReleaseFast — a silent wrong answer in the harness |
| `gtp.zig` list_commands overflow | crashed on a command every GUI sends — the tool did not survive its own handshake |
| `managent` unescaped note → corrupt `tasks.json` | corrupted the live kanban **twice** |
| `absorb` parser read a 221-row register as **empty** | "nothing to absorb" instead of failing |

And this week: **T425 wrote 16 fixture rows into the LIVE kanban** during a scratch exercise
(T427 is fixing it in the working tree as this document is written). The common shape — a tool
that *reports a clean result while doing nothing, or writes where it should not* — is the
project's most expensive recurring defect, and every instance so far has been in the
delegation toolchain, not the engine. Consolidation is not tidiness; it is the attack on this
shape.

### P4 — Test coverage is real but asymmetrical, and the suite is a cost

29 regression scripts are wired into `zig build test`; the suite was measured at **609.7 s**
(T406 console, 2026-08-08). Rough control counts by grep (denominators to be made exact in
Phase 3): argus-doctor 68, ollama-dispatcher 36, absorption-machinery 26, dispatch-verification
24, subagent-prompt 19, claimlint ×3 ≈ 36, managent ×12 varies. Two honest observations:

1. **The regressions exist and the defects still happened.** The 2026-08-03 defects were found
   by audits and absorption checks, not by the scripts that were supposed to guard them. Tests
   that cannot fail (a positive control exercising a parallel code path, an impossible counter)
   are the standing QA-023 lesson. Phase 3 must therefore write the acceptance tests *before*
   design, and Phase 7 must show every control RED first — the operator's own delivery pattern.
2. **The suite is 10 minutes and every tool multiplies it.** Fewer binaries means fewer copies
   into scratch repos per regression, and one build instead of several. Performance is a real,
   if modest, consolidation dividend — not the primary one.

## 4. What consolidation is NOT solving

Scope discipline, stated so Phase 2 can enforce it:

- **Not the goban engine.** `src/retro.zig`, `oracle.zig`, `rules.zig`, `solve.zig`, the
  `vb_*` modules and their mutants are out. They have their own ownership and their own
  auditors; the delegation toolchain must not absorb them.
- **Not the kanban data model.** `tasks.json` schema, lifecycle semantics, flock protocol —
  `docs/infra/managent/spec.md` owns those; consolidation reorganizes the CLIs, not the store.
- **Not the claim semantics.** CLAIMS.md statuses, `d:`/`e:`/`n:` edges, the C1–C10 check
  semantics are epistemic content; consolidation reorganizes *who parses the file*, not *what
  the file means*.
- **Not the assertion-ledger design.** `docs/infra/assertion-ledger/spec.md` is a separate
  accepted spec; §10 of it is a binding precedent for this sprint (below).
- **Not a rewrite.** No tool is re-implemented "more cleanly" for its own sake. A merge that
  preserves behavior and tests is in; a rewrite that re-derives behavior from the spec is out
  (it would be a new tool with old names — the opposite of consolidation).

## 5. The yardstick — the eight qualities, operationally defined

Every proposal in Phases 2–5 is scored against exactly these eight, in a table, with a `+`/`0`/`−`
and a one-line reason. The definitions below are what this sprint means by each word, so the
score cannot be argued by redefinition later.

| quality | operational meaning in this sprint | measured by |
|---|---|---|
| **reuse** | duplicated code is replaced by shared code with one owner | parser sites (5 → target 1); common lines between the subagent pair; `git diff` of merged tools vs union of old |
| **testability** | every behavior has a regression that fails when the behavior breaks; controls shown RED first | control counts per tool; Phase 3 acceptance suite; the union-of-suites bar (below) |
| **predictability** | same input → same output; stable exit codes; a tool does what its name says; no mode surprises | byte-identical outputs across runs (claimlint redirect test is the model); exit-code contract |
| **transparency** | the operator can see what a tool did and why; stdout = data, stderr = diagnostics; no silent success | `2>/dev/null` emits data, `1>/dev/null` silent (AGENTS.md regression); every action visible in an audit trail |
| **stability** | the live toolchain never breaks; `bin/` stays live; cutover is a stated event, not a surprise | zero fleet outages; every tool's regressions green at every commit; stated cutover lines |
| **agility** | a fix ships in one row; suite runtime does not explode; a change to one concern does not ripple into others | files touched per fix; suite wall time (609.7 s baseline); commit count per defect |
| **performance** | invocation latency and suite wall time stay bounded; no exponential behaviors in tooling | suite time; per-invocation time; memory (runner RSS guard) |
| **separation of concerns** | registration vs display; write vs read; verify vs transform — each concern has exactly one owner, and a merge keeps the verb boundaries crisp | §10 precedent compliance; the ownership table (who writes, who reads) stays unambiguous |

A proposal that improves one quality and harms another is a **trade**, not a win, and must be
argued as one in the phase that proposes it — the operator's constraint sentence is the
constitution, and trading separation for reuse without saying so is the failure this yardstick
exists to catch.

## 6. Binding precedents

1. **`docs/infra/assertion-ledger/spec.md` §10** (accepted 2026-08-08, commit `fe6f05b`): "A
   separate CLI tool for the assertion ledger" is explicitly NOT built. **`managent` writes it;
   `argus` reads it. No `bin/weizigo-assertion`.** This sprint inherits the ruling as a
   precedent: a read/write pair does not become one binary just because the data is shared.
   Registration and display remain different concerns.
2. **Registration and display are different concerns** (operator ruling, 2026-08-08, restated
   in the T428 brief): a merge must not blur them even if it shares code beneath them. This is
   the immediate bar on any proposal that would fold `argus` (display/watchdog) into `managent`
   (registration).
3. **stdout = data, stderr = diagnostics** (AGENTS.md): survives any merge; the merged tool
   inherits the contract of every tool it absorbs.
4. **The #2 self-consistency auditor is a mandatory pre-commit gate** for engine changes; the
   tooling analogue is the independent phase audit of this sprint. "Sound by construction"
   claims are insufficient (the `ko_ref >= d` lesson, ADR-0013) — the independent seat is the
   mechanism.
5. **No silent writes to `data/` or `artifacts/`; never the live kanban for exercises** —
   `MANAGENT_STORE` for scratch, `tasks.json` byte-identical after every exercise (T425's 16
   fixture rows are the standing warning; T427 is the fix in flight).

## 7. The hypothesis to test — and its refutation criteria

The T428 brief's candidate: **merge `claimlint` + `absorb`** (same language, same data source,
same role). Refute or confirm at strategy level; do not start from it.

**Evidence in favor (measured above):**
- Same language (Zig), same input (`CLAIMS.md` + `findings/`), same role (Orchestrator at row
  close), same failure history (both were the "safety net that broke" story of T404/T406).
- The merge would force **one Zig parser** (consuming `claims_register.zig`, retiring
  claimlint's inline copy), directly attacking P2 — the strongest single move available in this
  toolchain. After the merge, the file claimlint verifies is parsed by the same code absorb
  transforms; the T406 two-verdicts-same-file shape becomes structurally impossible in Zig.
- Verify-then-transform is a pipeline: `claimlint`'s verdict gates `absorb`'s proposal. One
  binary with verbs (`verify` / `absorb`) makes the pipeline visible in one help screen.

**Evidence against / costs (must be argued as trades in Phase 4):**
- claimlint (3,200) + absorb (657) ≈ 3,900-line binary: the biggest tool in the fleet after
  managent. A parser defect now hits both verbs at once — concentration of failure. The
  mitigation is exactly the union-of-suites bar (below) plus the empty-parse hard error T406
  already added.
- Verify and transform are **different concerns**; the merge is only acceptable if the verb
  boundary keeps them distinct (like `git fsck` vs `git filter-branch` — same binary, opposite
  intents, shared object model).
- 6 → 5 tools is a modest count reduction. If the merge's only dividend is the count, it is
  not worth the risk; if its dividend is one parser + one pipeline, it is.

**Refutation criteria (what would end the hypothesis in a later phase):**
- If Phase 3's acceptance suite cannot express the union of both suites with shared code (a
  merged binary whose test story is weaker than two separate ones), the merge fails.
- If the merged verb boundary blurs registration/display or write/read in any way ruled by §10,
  the merge fails.
- If claimlint's inline parser and `claims_register.zig` turn out to differ in a way that
  makes consolidation a rewrite rather than a merge (measured by diff in Phase 2), the merge
  becomes a rewrite and is out per §4.

**The other candidate — `subagent` + `ollama-subagent`:** already share `tools/dispatch_verify.py`
(good reuse exists); 120 common non-comment lines vs 99 differing (measured). The operator's own
suggestion is one `subagent` with a provider flag. Strategy-level read: plausible and lower-risk
than claimlint+absorb (small files, clear shared scaffold), but it does not attack P2 (the
register) at all — it attacks P1/P4 only. **Do not let the dispatch pair consume the sprint at
the expense of the parser problem.** Phase 2 decides inclusion.

**`argus`:** out of merge consideration at strategy level by precedent (§6.2) — display/watchdog
is a distinct concern from every writer. It may *gain* parser reuse (argus reads CLAIMS.md too),
but as a consumer of the one shared parser, not as a merged tool.

## 8. Success and failure — what would tell us this strategy failed

The strategy is falsifiable or it is decoration. These criteria are decided now, before any
design, so later phases cannot move the goalposts.

**Success (the sprint ships and it was worth it):**
- S1. The register is parsed by exactly one code path in production Zig tooling, and the
  T406 shape (same file, two verdicts, no alarm) is structurally impossible, not merely
  unobserved.
- S2. Tool count drops (6 → ≤5) with **zero capability loss**: every old invocation either
  works unchanged, or has a stated cutover line with the old entry point alive during the
  transition (§Bar 2 of the brief).
- S3. Every merged tool's regression suite is the **union** of both suites (test count before
  and after reported in `07-test.md`), and every control was shown RED before the fix.
- S4. The eight-quality table is filled in for every proposal; every `−` is argued as a trade,
  none is hidden.
- S5. §10 and registration/display boundaries hold in the shipped artifact — an auditor can
  point at the write/read ownership table and it is unambiguous.
- S6. No live-store incident during the sprint: every exercise uses `MANAGENT_STORE`, and
  `tasks.json` is byte-identical before/after each (T425 is the standing counterexample).

**Failure (stop, or ship `08-accept.md` as partial/abandoned with the honest reason):**
- F1. A merge ships with a test story weaker than the union of its parts (the "rewritten
  subset" the brief forbids).
- F2. A cutover breaks a live console — `bin/` replaced without a stated cutover, or a
  half-migrated toolchain left in place.
- F3. The merged CLI is *less* predictable/transparent than the separate tools (verb sprawl,
  hidden modes, state that a one-screen read cannot answer) — measured by the operator's own
  test: can he answer "what did this tool do?" from one screen?
- F4. Any phase audit is skipped or rubber-stamped (the independence mechanism is the point of
  the eight-phase pattern; violating it is a process failure regardless of the artifact).
- F5. The same phase fails audit twice → stop rule fires, report to the operator (brief Bar).
- F6. A document claims a measurement it does not show (no denominator, no command, no file) —
  the tooling twin of the QA-023 "state every denominator" rule.

**Valid outcome that is NOT a failure:** Phase 1 or 2 concludes consolidation is not worth it
and `08-accept.md` documents "we should not do this." A documented no is a success; a
rubber-stamped yes is not.

## 9. Phase map and gates (from the brief, restated as the contract)

| # | phase | document | gate |
|---|---|---|---|
| 1 | strategy | `01-strategy.md` (this) | audit by a different agent (T429) |
| 2 | scope | `02-scope.md` | audit |
| 3 | **acceptance** | `03-acceptance.md` — tests written BEFORE any design | audit |
| 4 | design | `04-design.md` — boundary, scored against the eight | audit |
| 5 | plan | `05-plan.md` — ordered, revertible steps + migration risk | audit; **no code before this passes** |
| 6 | build | `06-build.md` — what was built vs plan, deviations named | audit |
| 7 | test | `07-test.md` — acceptance results, every control RED first | audit |
| 8 | accept | `08-accept.md` — shipped / partial / abandoned | sprint close; satisfies `test -s docs/infra/tool-consolidation/accept.md` |

Every phase audit is a separate document (`NN-<phase>-audit.md`) written by a different agent
than the phase writer, recorded in each document's header. Stop rules and bars from the brief
apply verbatim.

## 10. What this strategy commits the sprint to

1. Measure everything it claims (this document's numbers were all produced by commands run on
   2026-08-08; Phase 2 re-measures the parser topology precisely — a diff of claimlint's inline
   parser against `claims_register.zig`, and the shallow-reader sites — before anything is
   designed).
2. Score every proposal against the eight qualities in a table, no hidden `−`.
3. Write acceptance tests before design (Phase 3), show every control RED first (Phase 7),
   keep the union of suites.
4. Honor §10 and the registration/display boundary in every artifact.
5. Treat "we should not consolidate" as a first-class deliverable if the evidence says so.
6. Never touch the live kanban except through the normal verbs; scratch stores only.

---

**Landmark:** advances `L4 (the ledger is clean)` and fleet reliability — the strategy that will
be judged by whether the T406 shape (same register, two verdicts, no alarm) becomes impossible
and the tool count drops with the union of tests intact. What remains: an independent audit of
this document, then the scope decision (Phase 2) that names what is in and what is out.

**Human summary:** the six delegation tools (12,670 lines, three languages) are measured, and
the problem consolidation is solving is not tidiness but a named, evidenced failure mode: the
register `CLAIMS.md` is parsed at five independent sites, two of which silently read a 221-row
file as empty on the same day (T406), and the toolchain's worst defects all share the shape
"reports success while doing nothing" (including T425's 16 fixture rows in the live kanban).
The strategy commits to eight explicit quality yardsticks, the §10 precedent (managent writes,
argus reads — no blurring), refutation criteria for the claimlint+absorb hypothesis, and
falsifiable success/failure criteria. Next: independent audit, then scope.
