# T433 — AUDIT of T428 Phase 2: `02-scope.md`

**VERDICT: PASS WITH FINDINGS** — Phase 3 may proceed; five non-blocking findings below. None block.

| | |
|---|---|
| Auditor | glm-5.2/T433 |
| Date | 2026-08-08 |
| Subject | `docs/infra/tool-consolidation/02-scope.md` (writer: deepseek-v4-pro/T428.2) |
| Landmark | gate for `T428 (tool consolidation sprint)` Phase 2 → Phase 3 |

Independence is the mechanism: I did not write the scope document, and I re-ran every
load-bearing measurement myself at commit `9a96f8b` rather than inheriting the doc's numbers.
Commands I ran are named below; a number I did not re-run is marked UNVERIFIED, not adopted.

The kanban claim of this row was blocked (dependency `T428` still `in_progress`); the human
dispatched the audit directly and the document under audit exists on disk, so the substantive
work proceeded. That context is recorded here so the Orchestrator can see it.

---

## 1. Question answered — PASS

The Phase-2 question from the brief was *which tools are in, which are explicitly out, and why?*
The document decides it — not merely describes. §3 returns a binding IN / OUT / ASSESS verdict
for every tool with a stated reason, §4 collapses it to a summary table, and §8 restates the
answer against the question. Each IN decision is falsifiable (strategy §7 refutation criteria
carried forward), each OUT cites a precedent or a scale argument, and the one ASSESS
(`gen-indices`) is correctly deferred to Phase 4 rather than silently dropped. This is a
decision, not an inventory.

## 2. Measurements re-run — PASS (all line counts match; overlap drifts)

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
(`9a96f8b`) is reproduced: at `0fc18b7` I measure 193 and 246 exactly. F1 (the Phase 1
managent drift 6,451→6,455) is correctly closed — the doc now states 6,455 and measures at a
named commit. Good.

The subagent-pair overlap (§3.2 / §6) does **not** reproduce at `9a96f8b`; see F1 below.

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
  → 9a96f8b:src/absorb.zig:const cr = @import("claims_register.zig");
```

claimlint imports only `std`, `version`, `util.zig`. The sole importer of
`claims_register.zig` is `src/absorb.zig:34`. The doc's §2.1/§2.2 topology is **correct and
reproduced**. This is the foundation of the claimlint+absorb merge and it holds.

Function-name line citations in §2.1 (`parseRegister` 769, `parseStatus` 723, `parseNarrowed`
738, `parseRate` 744, `backtickSpans` 753, `claimIdOf` 903, `isQaId` 915, `Register` 713) all
match the source at `9a96f8b`. The §2.4 managent shallow-read site (`ORCHA-TOOLS R3` at line
4910) is real, and the §2.5 argus site (line 1181, "CLAIMS.md row count vs register-tree-map.md
§1") is real. The five-site topology is verified.

Two line/quote citations in §2.1 and §2.2 are imprecise — see F4 and F5 below. The §2.6 stale
header is real but its line citation is off — see F3.

## 4. F1–F3 (Phase 1 audit findings) — addressed, with caveats

- **F1 (measurement drift).** ADDRESSED. Everything is measured at `9a96f8b` via `git show`,
  and every line count reproduces (§2 above). The doc says so in §0 and §1 and it is true.
- **F2 (method unspecified).** PARTIALLY ADDRESSED. The method is now stated (§2.3 / §3.2:
  `grep -v '^[[:space:]]*#' | sed '/^[[:space:]]*$/d' | sed strip | sort | uniq`, then `comm`).
  I applied that method verbatim and the numbers do **not** reproduce — see F1 below. The
  method is stated; the numbers are wrong for the commit claimed.
- **F3 (stale header).** ADDRESSED, with a line-citation drift (F3 below). The header text is
  quoted accurately and §2.6 carries it as a full subsection with the measured topology side
  by side — it is evidence, not a footnote, satisfying D066 correction 2.

## 5. D066 corrections — DONE (one with a caveat)

- **Correction 1 (measure at a committed tree).** DONE for line counts, imports, and the
  parser topology. NOT done for the subagent overlap (F1): the doc claims a re-measurement at
  `9a96f8b` that does not reproduce.
- **Correction 2 (dispatch own audits).** DONE. The audit row was registered by the Phase 2
  writer: `T433` (this row), plus a malformed sibling whose `managent` id is literally
  `--bundle` (the `--bundle` flag leaked into the id field of an `add` call). Both are blocked
  on `T428`; the human dispatched this one directly. Registration happened; dispatch is
  pending the dependency, which is the kanban's design, not a defect of the doc.

## 6. Scope decisions — PASS (sound, each follows from the evidence)

Re-checked each verdict against the verified evidence:

- **claimlint + absorb → IN.** Sound. Same language (Zig), same primary data source
  (`CLAIMS.md` + `findings/`), same role (row close), and the merge retires the inline
  claimlint parser so `claims_register.zig` becomes the single source — making the T406
  shape (same register, two Zig verdicts, no alarm) structurally impossible. The verified
  topology (§3) is exactly the evidence this rests on. The two `−` in §6 (stability,
  separation of concerns) are honestly named, not hidden.
- **subagent + ollama-subagent → IN.** Sound. Shared `dispatch_verify.py` (verified: both
  import it), substantial overlap (verified ~51%, F1's exact number aside), small blast
  radius. The merge does not attack P2 and the doc says so honestly.
- **managent → OUT.** Sound. 6,455 lines is more than the other five combined (6,233;
  verified), unique write concern, §10 precedent. No parser duplication to resolve (shallow
  citation read, not a `parseRegister` copy).
- **argus → OUT.** Sound. §10 precedent ("managent writes it; argus reads it. No
  `bin/weizigo-assertion`") is reproduced at `docs/infra/assertion-ledger/spec.md` §10 and
  the scope honors it.
- **gen-indices → ASSESS.** Sound. It is the third register parser (§2.3 verified: line 11
  "Edge parsing mirrors src/claims_register.zig"). Deferring the consume-vs-rewrite question
  to Phase 4 is correct — it is not a row-close tool.
- **dispatch_verify.py → OUT, runner → OUT.** Sound and consistent with strategy §4.

I find no tool that should be IN that is OUT, or OUT that is IN.

## 7. Eight-quality table — PASS (honest)

§6 scores both merges against all eight qualities. The two `−` entries are both on the
claimlint+absorb merge (stability: 3,900-line binary; separation of concerns: verify and
transform in one binary) and both are anticipated by strategy §7's evidence-against. The
subagent merge carries no `−`, which is honest given it is the low-risk half (small scripts,
shared scaffold already tested). I considered whether the subagent merge's `performance +`
("one Python invocation check instead of two") should be `0` — it is marginal but defensible;
not a finding. No `−` is missing; no `+` is clearly overstated.

## 8. Precedents honored — PASS

`docs/infra/assertion-ledger/spec.md` §10 ("What this spec explicitly does NOT build") item 1:
*"A separate CLI tool for the assertion ledger. `managent` writes it; `argus` reads it. No
`bin/weizigo-assertion`."* Verified verbatim. The scope honors it twice — managent stays OUT
(§3.3) and argus stays OUT as a reader (§3.4). The doc's framing of argus as a potential
*consumer* of the shared parser (not a merge) preserves the writer/reader boundary.

## 9. Process contract — PASS (one process nit)

- Landmark line present (close).
- Human summary present (close).
- Header names the writer (`deepseek-v4-pro/T428.2`), the commit (`9a96f8b`), and an absolute
  date (2026-08-08).
- "Dispatch its own audit" — DONE: the audit row `T433` was registered by the Phase 2 writer.
  Process nit (not the doc's defect): a sibling row with id `--bundle` was also created, a
  malformed `managent add` (the `--bundle` flag value leaked into the id). The Orchestrator
  should purge `--bundle` to keep the kanban clean.

---

## Findings (none blocking)

- **F1 (non-blocking, overlap numbers not reproducible at the claimed commit).** §0 asserts
  "The actual numbers are re-measured at `9a96f8b`" and §3.2/§6 report `117 common / 45
  subagent-unique / 66 ollama-unique / 228 total`. Running the doc's own stated method
  verbatim at `9a96f8b` gives `113 / 45 / 64 / 222`. The `117` matches the Phase 1 audit's
  re-run at the *earlier* commit (`db640dc`), where the files were 193/246; at `9a96f8b` they
  are 205/248 and the overlap has shifted. The number looks carried over, not re-measured —
  which is the exact F2 defect the doc claimed to close. The conclusion (substantial overlap,
  ~51%: 113/222 = 50.9% vs the doc's 117/228 = 51.3%) is unchanged and the merge stays sound;
  the numbers should be corrected to 113/45/64/222 (or re-measured and reconciled).
- **F2 (non-blocking, the depth-enforcement claim is false).** §3.2 costs/risks: "ollama
  enforces depth ≤2, subagent doesn't." Both scripts carry *identical* depth-cap logic at
  `9a96f8b`: `MAX_DEPTH = 3`, `if depth >= MAX_DEPTH: sys.exit("…REFUSED…")`, and
  `DEPTH_VAR = str(depth + 1)` on the child env. There is no divergence to "preserve" — the
  "preserve both behaviors, not silently unify them" risk as stated does not exist; the
  merge is simpler than the doc implies. Does not change the decision (still IN, still
  low-risk), but the stated divergence is wrong and should be corrected so Phase 4 does not
  invent a difference to preserve.
- **F3 (non-blocking, line-citation drift in the F3 evidence block).** §2.6 cites the stale
  header at "`src/claims_register.zig` lines 18–19". The quoted text ("Used by claimlint
  (checker) and absorb (knowledge-capture tool). Extracted from claimlint.zig 2026-08-01
  (T194/D5)…") actually begins at **line 21** (lines 18–19 are the blank/comment tail of
  the copyright banner). The quote is accurate; only the line numbers are off. (The Phase 1
  audit placed the same text at line 16; the real line is 21 — the citation has drifted both
  ways across the two docs.) Fix the line to 21.
- **F4 (non-blocking, misattributed and misquoted line in §2.2).** §2.2 attributes "line 328:
  `if (reg.header_cols != REGISTER_COLS) { return error... }`" to absorb's hard error. Line
  328 is in `claims_register.zig` (the shared parser absorb calls), and it does not
  `return error` — it appends to `reg.unparsed` and sets `reg.format_ok = false`. Absorb's
  own hard error is `std.process.exit(1)` at **line 527**, gated by
  `if (reg.rows.items.len == 0 or !reg.format_ok)` at **line 516**. The substance (T406 made
  empty-parse fatal in absorb) is correct; the line and the quoted guard are wrong.
- **F5 (non-blocking, misquoted guard in §2.1).** §2.1: "The inline `parseRegister` at line
  812 expects 11 columns: `if (first.len < 11) { ... }`." The actual guard at **line 810** is
  `if (c.len != 13)` with the message `"expected 11 columns, found {d}"` (using `c.len - 2`).
  The quoted code `if (first.len < 11)` does not exist in the file; the line number 812 is ~2
  off. Substance (claimlint expects 11 columns) is correct.

None of F1–F5 block Phase 3. The load-bearing claims — five-site parser topology (verified),
T406 silent-divergence shape (verified), §10 registration/display precedent (verified),
scope decisions that follow from the evidence (verified), eight-quality table with `−`
entries named not hidden (verified) — all survive independent re-measurement. F1 is the
most notable because it is the same class of defect the doc claimed to fix; F2 is the only
finding that touches a *reasoning* premise (a stated divergence that does not exist), and
even it leaves the merge decision intact.

---

**Landmark:** advances `L4 (the ledger is clean)` — Phase 2 scope now names exactly two
consolidation targets on a verified evidence base: the parser topology (claimlint does not
import `claims_register.zig`; absorb does) and the §10 registration/display precedent both
reproduce at `9a96f8b`, and every scope decision follows from them. What remains: Phase 3
(acceptance) must write the union-of-suites tests before any design, and the five findings
above — the overlap numbers (F1) and the depth-enforcement claim (F2) in particular — should
be corrected in the scope doc or carried forward as design inputs so Phase 4 does not build
on a divergence that is not there.

**Human summary:** the Phase 2 scope passes audit with five non-blocking findings — Phase 3
may proceed. I re-ran every load-bearing measurement at `9a96f8b`: all eight line counts and
the six-tool total reproduce exactly, the parser topology (claimlint does NOT import
`claims_register.zig`, absorb does) reproduces exactly, and the §10 "managent writes / argus
reads" precedent is verified verbatim. Both merge decisions (claimlint+absorb; subagent+
ollama-subagent) and both OUT decisions (managent; argus) are sound. The one notable finding:
the subagent-overlap numbers (117/45/66/228) do not reproduce at the claimed commit — my
verbatim re-run gives 113/45/64/222 — and the `117` matches the Phase 1 audit's earlier
commit, so it looks carried over rather than re-measured, the exact defect F2 was meant to
close. A second finding: §3.2's claim that "ollama enforces depth ≤2, subagent doesn't" is
false — both scripts have identical depth-cap logic. Three more are line/quote citation
drifts in the parser-topology section. None change any scope decision.