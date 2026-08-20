# T433 — AUDIT of T428 Phase 2: `02-scope.md`

**VERDICT: PASS WITH FINDINGS** — Phase 3 may proceed; six non-blocking findings below. None block.

| | |
|---|---|
| Auditor | deepseek-v4-flash/T433 |
| Date | 2026-08-20 |
| Subject | `docs/infra/tool-consolidation/02-scope.md` (writer: deepseek-v4-pro/T428.2) |
| Commit measured at | `9a96f8b` (doc's own stated commit, verified) |
| Doc state audited | post-fix: current working tree (fix commit `4134980` applied) |
| Supersedes | the 2026-08-08 glm-5.2/T433 audit (git `7f6f40a`), which was marked incomplete by dispatch-verify and predates the `4134980` fixes |
| Landmark | gate for `T428 (tool consolidation sprint)` Phase 2 → Phase 3 |

Independence is the mechanism: I did not write the scope document, and I re-ran every load-bearing
measurement myself at commit `9a96f8b` rather than inheriting the doc's numbers or the previous
audit's numbers. Commands I ran are named below; a number I did not re-run is marked UNVERIFIED,
not adopted.

Because the doc was fixed after the first audit (commit `4134980`, "fix audit findings F1–F5"), this
audit verifies both the doc's own claims and whether the first audit's findings were actually
closed. Summary: F1 and F2 are genuinely fixed and reproduce; F3/F4/F5's *line citations* were
**not** fixed despite the commit message claiming so — they are still wrong (F-a below).

---

## 1. Question answered — PASS

The Phase-2 question from the brief was *which tools are in, which are explicitly out, and why?*
The document decides it — not merely describes. §3 returns a binding IN / OUT / ASSESS verdict for
every tool with a stated reason, §4 collapses it to a summary table, §5 names the bin/-level
cutover, and §8 restates the answer against the question. Each IN decision is falsifiable
(strategy §7 refutation criteria carried forward), each OUT cites a precedent or a scale argument,
and the one ASSESS (`gen-indices`) is explicitly deferred to Phase 4 rather than silently dropped.
This is a decision, not an inventory.

## 2. Measurements re-run — PASS (all reproduce, including the fixed overlap numbers)

Every line count the brief listed was re-run via `git show 9a96f8b:<path> | wc -l`:

| path (doc claim) | re-run | verdict |
|---|---|---|
| `src/managent/main.zig` = 6,455 | **6,455** | MATCH |
| `src/claimlint.zig` = 3,200 | **3,200** | MATCH |
| `src/absorb.zig` = 657 | **657** | MATCH |
| `bin/argus` = 1,923 | **1,923** | MATCH |
| `bin/subagent` = 205 | **205** | MATCH |
| `bin/ollama-subagent` = 248 | **248** | MATCH |
| `src/claims_register.zig` = 449 | **449** | MATCH |
| `tools/dispatch_verify.py` = 258 | **258** | MATCH |
| six-tool total = 12,688 | **12,688** | MATCH (6455+3200+657+1923+205+248) |

The §1 note that the two subagent files grew from 193/246 (Phase 1, `0fc18b7`) to 205/248
(`9a96f8b`) is reproduced: at `0fc18b7` I measure 193 and 246 exactly (+12 and +2). The §3.3 claim
"6,455 lines is more than the other five combined" reproduces: 3200+657+1923+205+248 = 6,233.
The §0 F1 story is real: `01-strategy.md` §1 states managent as 6,451; the current doc states
6,455 and reproduces.

The subagent-pair overlap (§3.2 / §6) — the numbers the first audit flagged — **now reproduce**
verbatim with the doc's stated method (`grep -v '^[[:space:]]*#' | sed '/^[[:space:]]*$/d' |
sed strip | sort | uniq`, then `comm`):

```
common (comm -12): 113    subagent-unique: 45
ollama-unique:     64     total distinct: 222    → 50.9%
```

This is the F1 fix (117→113 / 66→64 / 228→222) landing correctly. F1 is genuinely closed.

## 3. Parser topology — PASS (the load-bearing claim, re-verified)

The brief calls this the load-bearing claim: *claimlint does NOT import `claims_register.zig`,
and absorb does.* Re-run at `9a96f8b`:

```
git show 9a96f8b:src/claimlint.zig | grep "@import"
  → const std = @import("std");
  → const version = @import("version");
  → const util = @import("util.zig");
  // claims_register.zig is NOT imported

git grep claims_register 9a96f8b -- src/
  → 9a96f8b:src/absorb.zig:34:const cr = @import("claims_register.zig");
```

claimlint imports only `std`, `version`, `util.zig`. The sole `src/` importer of
`claims_register.zig` is `src/absorb.zig:34`. The doc's §2.1/§2.2 topology is **correct and
reproduced** — this is the foundation of the claimlint+absorb merge and it holds.

The five-site topology, re-verified at `9a96f8b`:

- **Site 3 (`tools/gen-indices`):** line 11 "Edge parsing mirrors src/claims_register.zig (the
  authority claimlint…" — MATCH (§2.3).
- **Site 4 (managent):** line 4910 `// ── ORCHA-TOOLS R3: read CLAIMS.md and PROGRESS.md for
  citation checks ──`, followed by `readFileAlloc(… "docs/epistemic/CLAIMS.md")` — MATCH (§2.4);
  shallow read confirmed (no `parseRegister` call).
- **Site 5 (argus):** line 1181 `"""CLAIMS.md row count vs register-tree-map.md §1, and floor
  drift.` — MATCH (§2.5).
- **Function-name parity (§2.1):** both files expose `Register`, `parseRegister`, `parseStatus`,
  `parseNarrowed`, `parseRate`, `backtickSpans`, `claimIdOf`, `isQaId` (claimlint lines 713/769/
  723/738/744/753/903/915; shared module lines 98/291/161/191/197/208/273/246) — MATCH.
- **`REGISTER_COLS` (line 289):** `pub const REGISTER_COLS: usize = 11;` — MATCH.
- **T406 story (§2.2/§2.3):** consistent with the source's own comments ("T406: the old
  hard-coded 10 silently parsed the 11-column register as empty", `claims_register.zig` lines
  325–327) — the empty-parse-hard-error history is real.

## 4. F1–F3 (Phase 1 audit findings) — addressed; F2's fix verified this time

- **F1 (measurement drift).** ADDRESSED — everything measured at `9a96f8b` via `git show`, and
  every line count reproduces (§2). The doc says so in §0 and §1 and it is true.
- **F2 (method unspecified).** ADDRESSED — the method is stated precisely (§2.3 / §3.2) and the
  numbers now reproduce with that method verbatim (113/45/64/222; §2). The first audit's complaint
  is closed.
- **F3 (stale header).** ADDRESSED as *evidence* — §2.6 is a full subsection carrying the header
  quote and the measured topology side by side, satisfying D066 correction 2's "evidence, not a
  footnote" bar. The header text itself is quoted accurately. The *line citation* is wrong
  (F-a below).

## 5. D066 corrections — DONE (one caveat)

- **Correction 1 (measure at a committed tree).** DONE for line counts, imports, parser topology,
  and the overlap measurement — all re-derived from `9a96f8b` (§2, §3).
- **Correction 2 (dispatch own audits).** DONE. The audit row was registered by the Phase 2
  writer (`T433`, this row), plus a malformed sibling whose `managent` id is literally `--bundle`
  (the `--bundle` flag leaked into the id of an `add` call). Both were blocked on `T428`; the
  previous audit was dispatched directly by the human. **The malformed `--bundle` row is still
  live and dispatchable in the kanban** (bundle path `untracked/T430-phase2-audit.md` does not
  exist) — carried as F-d below.

## 6. Scope decisions — PASS (sound, each follows from the evidence)

Re-checked each verdict against the verified evidence:

- **claimlint + absorb → IN.** Sound. Same language (Zig), same primary data source, same row-close
  role, and the merge retires claimlint's inline parser so `claims_register.zig` becomes the single
  source of truth — making the T406 shape (same register, two Zig verdicts, no alarm) structurally
  impossible. The verified topology (§3) is exactly the evidence this rests on. The two `−` in §6
  (stability, separation of concerns) are honestly named.
- **subagent + ollama-subagent → IN.** Sound. Shared `dispatch_verify.py` (verified: both import
  it at `bin/subagent:35` and `bin/ollama-subagent:44`), verified ~51% overlap (113/222), small
  blast radius. The corrected depth-cap text (F2 fix) is accurate: both scripts carry identical
  `MAX_DEPTH = 3` / `if depth >= MAX_DEPTH: sys.exit(…REFUSED…)` / `DEPTH_VAR = str(depth + 1)`
  logic at `9a96f8b` (subagent lines 44/84–86/165; ollama lines 49/105–106/200) — no divergent
  behaviors to reconcile, exactly as the doc now says.
- **managent → OUT.** Sound. 6,455 lines > the other five combined (6,233; verified), unique write
  concern, §10 precedent, no parser duplication (shallow citation read, verified §2.4).
- **argus → OUT.** Sound. §10 precedent (verified, see §8) plus the operator's own ruling quoted
  in §3.4.
- **gen-indices → ASSESS.** Sound. It is the third register parser (§2.3 verified). Deferring the
  consume-vs-rewrite question to Phase 4 is correct — it is not a row-close tool.
- **dispatch_verify.py → OUT, runner → OUT.** Sound and consistent with strategy §4.

I find no tool that should be IN that is OUT, or OUT that is IN.

## 7. Eight-quality table — PASS (honest)

§6 scores both merges against all eight qualities. The two `−` entries are both on the
claimlint+absorb merge (stability: ~3,900-line binary — 3200+657=3,857, "second-largest after
managent" is true; separation of concerns: verify and transform in one binary) and both are
anticipated by strategy §7's evidence-against. The subagent merge carries no `−`, which is honest
given it is the low-risk half (small scripts, shared scaffold already tested). I considered the
subagent merge's `performance +` ("one Python invocation check instead of two") — a dispatch
never invoked both scripts, so the marginal gain is arguable; it is a borderline `+` at worst,
not a defect. No `−` is missing; no `+` is clearly overstated.

## 8. Precedents honored — PASS (with a staleness caveat, F-c)

The §10 precedent text is verified verbatim — *"A separate CLI tool for the assertion ledger.
`managent` writes it; `argus` reads it. No `bin/weizigo-assertion`."* — at `docs/infra/
assertion-ledger/spec.md` §10 item 1 **as of commit `9a96f8b`**, where the path was live. The
scope honors it twice: managent stays OUT (§3.3) and argus stays OUT as a reader with a possible
consumer relationship (§3.4), preserving the writer/reader boundary. The doc's framing of argus
as a potential *consumer* of the shared parser (not a merge) is the correct reading.

Caveat (F-c): the ledger was **retired on 2026-08-19 (T495)** — `docs/infra/assertion-ledger/
spec.md` no longer exists in the working tree; the spec is archived at `docs/infra/assertion-
ledger/archive/spec-2026-08-08.md`, and the directory README declares the ledger "not the
authority for any question." The doc's §3.3/§3.4/§7 citations of `spec.md` are dead links today
(they were live at the measured commit, so the doc is internally consistent). The OUT decisions
also rest on the operator's own ruling ("registration and display are different concerns", quoted
in §3.4), so they stand independently of the ledger's fate.

## 9. Process contract — PASS (two process notes)

- Header names the writer (`deepseek-v4-pro/T428.2`), the commit (`9a96f8b` — message verified:
  "Orcha: T431 closed pass; T428 sprint delegated to a single console for phases 2-8."), and an
  absolute date (2026-08-08). Present.
- Landmark line present (close). Human summary present (close). Status line honest ("PROPOSED —
  awaits independent audit before Phase 3 begins").
- "Dispatch its own audit" — DONE: the audit row `T433` was registered by the Phase 2 writer.
- **Phase 3 waited for the gate.** `03-acceptance.md` measures at `4134980` — the *fix* commit —
  so the sequence was: scope doc (`87d8f08`) → first audit → fixes (`4134980`) → Phase 3. The
  gate held even though this row's re-dispatch (the first run failed dispatch verification) lands
  after Phase 3 was written.
- Process note 1 (F-b): the fix commit `4134980` *claims* in its message to have fixed "line
  citations for stale header/F4/F5" but its diff touches only the overlap numbers (F1) and the
  depth-cap text (F2). The message overstates the diff.
- Process note 2 (F-d, carried from the first audit): the malformed `--bundle` kanban row is
  still dispatchable. Purge it.

---

## Findings (none blocking)

- **F-a (non-blocking — F3/F4/F5 line citations are still wrong; the fix commit did not fix
  them).** Commit `4134980`'s message claims "line citations fixed for stale header/F4/F5", but
  its diff contains no citation changes. Re-measured at `9a96f8b`, all four still miss:
  - §0 (line 36), §3.1 (line 167), §8 (line 388): the stale header is cited at
    `claims_register.zig` **line 18**; the quoted text ("Used by claimlint (checker) and absorb…")
    begins at **line 21** (lines 18–19 are the blank/comment tail of the copyright banner; the
    "CLAIMS REGISTER —" title line is 19).
  - §2.6 (line 134): "lines 18–19" — quoted text is at **21–23**.
  - §2.1 (line 101): "The inline `parseRegister` at line 812 expects 11 columns: `if (first.len
    < 11) { ... }`" — that code does not exist in the file. The real guard is `if (c.len != 13)`
    at **line 809**, with the message `"{d}: expected 11 columns, found {d} — `{s}`"` at **line
    812** (line 812 is the *message*, not the guard).
  - §2.2 (line 113): "T406 made the empty parse a hard error (line 328: `if (reg.header_cols !=
    REGISTER_COLS) { return error... }`)" — **line 328 is in `claims_register.zig`** (the shared
    parser, not absorb), and it does **not** `return error`: it appends to `reg.unparsed` and sets
    `format_ok = true` only in the else branch. Absorb's actual hard error is the
    `if (reg.rows.items.len == 0 or !reg.format_ok)` guard at **line 515** → `std.process.exit(1)`
    at **line 531**.
  These are exactly the first audit's F3/F4/F5, unchanged (its own line numbers were slightly off
  — guard at 809, not 810 — the substance is identical). The *substance* of every one of these
  sentences is correct (11-column format, T406 made empty parse fatal, the header is stale); only
  the citations are wrong. Fix: 21 (header), 809/812 (claimlint guard), 515/531 (absorb fatal).
  None changes a scope decision.
- **F-b (non-blocking — fix-commit message overclaims; process honesty).** `4134980`'s subject
  line promises citation fixes its diff does not contain. Whatever re-runs the numbers should
  re-check the citations, or the message should name only what it did. This is the same class of
  "reported done while not done" that the verification rules exist to catch — here it is a commit
  message rather than a tool, but the discipline is the same.
- **F-c (non-blocking — §10 citation path is dead in the current working tree).** The precedent
  the scope rests on is real and verbatim, but `docs/infra/assertion-ledger/spec.md` was retired
  (T495, 2026-08-19) and now lives at `docs/infra/assertion-ledger/archive/spec-2026-08-08.md`.
  The doc's §3.3/§3.4/§7 links 404 today. If the doc is ever touched again, point at the archive
  path or drop the precedent in favor of the operator ruling (which §3.4 already quotes). The OUT
  decisions do not depend on the link being live.
- **F-d (non-blocking — kanban hygiene; not the doc's defect, carried from the first audit).**
  The malformed `--bundle` row (added 2026-08-08T13:52:25Z; bundle `untracked/T430-phase2-audit.md`,
  a path that does not exist) is still `dispatchable` in the kanban. The Orchestrator should purge
  it so nobody accidentally dispatches it.
- **F-e (non-blocking — the brief/bundle path mismatch).** This row's kanban record names bundle
  `untracked/T430-phase2-audit.md` (nonexistent); the real brief is `untracked/T433-phase2-audit.md`,
  and it is itself a copy of the T430 brief template (its header names "glm-5.2/T430" and carries
  the T430 nonce). The substance (audit `02-scope.md`) is unambiguous, but the row's bundle field
  should be corrected to the real path so a future resume does not chase a ghost.
- **F-f (non-blocking — the doc's own audit line is stale).** The doc's header says "Audit: pending
  — row to be registered and dispatched after this document is written". At the time of writing it
  was true; the first audit ran and this re-audit closes it. If the doc is touched again, flip this
  line to name the audit row and its verdict.

None of F-a–F-f block Phase 3. The load-bearing claims — five-site parser topology (verified),
T406 silent-divergence shape (verified against source comments), §10 registration/display
precedent (verified verbatim), scope decisions that follow from the evidence (verified), and the
eight-quality table with `−` entries named not hidden (verified) — all survive independent
re-measurement. The doc's numbers are now honest at the stated commit; what remains wrong is a
set of line/quote citations and one dead link, all cosmetic to the decisions.

---

**Landmark:** advances `L4 (the ledger is clean)` — Phase 2 scope now stands on a fully
re-measured evidence base: all eight line counts, the six-tool total (12,688), the subagent
overlap (113/45/64/222), the parser topology (claimlint does NOT import `claims_register.zig`;
absorb does), the depth-cap parity, and the §10 precedent all reproduce at `9a96f8b`, and every
scope decision follows from them. What remains: Phase 3's acceptance suite is already written
(measured at `4134980`); Phase 4 design must not inherit the wrong line citations (F-a) as if
they were facts, and the dead §10 link (F-c) should be repointed if the doc is touched.

**Human summary:** the Phase 2 scope document passes audit with six non-blocking findings —
Phase 3 may proceed. I re-ran every load-bearing measurement at commit `9a96f8b`: all eight line
counts and the 12,688 total reproduce exactly, the subagent-overlap numbers the first audit
flagged as unreproducible are now correct (113/45/64/222), the parser topology (claimlint does
NOT import claims_register.zig, absorb does) reproduces exactly, and the §10 "managent writes /
argus reads" precedent is verified verbatim. Both merge decisions and both OUT decisions are
sound. The notable finding: the fix commit `4134980` claims to have fixed the F3/F4/F5 line
citations but did not — all four are still wrong (the doc quotes `if (first.len < 11)` which does
not exist, cites claims_register.zig line 328 as an absorb hard error when absorb's real fatal is
at lines 515/531, and places the stale header at lines 18–19 when it is at 21–23). A second
notable: the §10 precedent's citation path is now a dead link because the assertion ledger was
retired on 2026-08-19 — the decisions rest on the operator's ruling too, so they stand. None of
the findings changes any scope decision.
