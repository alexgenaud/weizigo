# T452 design-race scores — glm-5.2 (second, independent grader)

**Grader:** glm-5.2/T460 · **Date:** 2026-08-19 · **Read-only:** no source edited, no build run.
Citations were opened and checked against the repository; results below.

**Blind grading note.** Lane B names itself ("MiniMax-M3 to Opus/Orcha") in its own
text. Per the brief I ignore self-naming and grade the reasoning only; lane identity is
sealed. I did not attempt to identify lanes and detected no favouritism from familiar
phrasing. One of these seven may be my own model's output; I scored what was in front of me.

**Key, as written (20 pts):** 1=mechanism (4) · 2=path-dependence settled (5) ·
3=memo = category error (3) · 4=fix preserving measured quantity (4) · 5=denominators (2) ·
6=no-bounded-fix proven + ruler named (2). Penalties: −3 raise NODE_BUDGET; −3 fabricated
citation; −2 path-(in)dependence asserted without argument.

---

## Score table

| lane | 1 mech (4) | 2 path-dep (5) | 3 memo cat-err (3) | 4 fix preserves (4) | 5 denominators (2) | 6 no-fix proven (2) | **total** |
|---|---|---|---|---|---|---|---|
| **A** | 4 | 5 | 3 | 0 | 2 | 2 | **16** |
| **B** | 4 | 5 | 3 | 3 | 2 | 1 | **18** |
| **C** | 4 | 5 | 3 | 4 | 2 | 0 | **18** |
| **D** | 4 | 5 | 3 | 0 | 2 | 2 | **16** |
| **E** | 4 | 5 | 3 | 0 | 2 | 2 | **16** |
| **F** | 4 | 5 | 3 | 4 | 2 | 0 | **18** |
| **G** | 4 | 5 | 3 | 4 | 2 | 0 | **18** |

No lane recommended raising `NODE_BUDGET` (all explicitly reject it → no −3).
No lane asserted path-(in)dependence without an argument (all exhibit witnesses or
constructions → no −2). No citation rose to fabrication (content exists in the corpus
for every load-bearing cite I checked); two of B's line ranges are inaccurate and are
recorded below, not penalised under the −3 fabrication bar.

### Per-criterion reasons

**Criterion 1 — mechanism (paths not states, cost = branching^depth).**
All seven name the path-local cycle check (`:216-217`/`:215-219`) and the
branching ≤5 × `DEPTH_LIMIT=64` interaction, citing the file's own `~5^64` comment
(`:186-188`). Full marks everywhere. C, F, G add measured node-count growth tables
(monotone f(22) > 20M); A exhibits a reachable 6-cycle that breaks the header's "no
cycles" premise; D gives the 5^11 > 20M arithmetic; E gives a tighter
1620·5·4^63 bound.

**Criterion 2 — path-dependence settled with an argument.**
All seven settle it. A exhibits a verified reachable 6-cycle and two equal-length
histories to one state (S6) that change the same child edge from TIE to recursion — a
concrete, hand-checkable witness (I traced it move-by-move; it closes). B leans on the
project's own proof-v2 §6.2 S0/S1 counterexample (`proof-v2:418-423`, accurate). C gives
a 58-state census of states taking two values **plus** a theorem + 264/264 exhaustive
check that the *root* value is path-independent (the deepest treatment). D and E give
reconvergence constructions (two ancestor sets P₁/P₂). F gives a measured demonstration
(`brute_value(a,∅)=-4` vs `brute_value(a,{a})=0`) and verifies the 160-state SCC witness
move-by-move. G gives a 58-witness census and the attractor-rank argument. 5/5 for all.

**Criterion 3 — memo is a category error, not a risky optimisation.**
All seven say "category error" explicitly and ground it in the patch's own concession
(`untracked/abandoned/T452-minimax-m3-memoization.patch:17-25`, verified) that "the
memoized value may disagree with a non-memoized brute." B, E, F, G additionally cite
`assertions.jsonl:14` (verified) and `EXP-2.md:150-151` "state-only memo assumes the
conclusion" (verified). G notes two latent patch defects (the `MEMO_NONE=127`/White-init
collision and the reentrance return preceding `nodes_visited += 1`). 3/3 for all.

**Criterion 4 — recommends a fix that preserves the measured quantity.**
This is the splitting criterion. C, F, G recommend a bounded fix (alpha-beta with no
transposition table and/or the retrograde L/H fixpoint) and **prove** it preserves the
root measured quantity: C via a theorem (root = median(L,TIE,H) when forced-win length ≤
DEPTH_LIMIT, measured max 3 ≪ 64) plus a 264/264 exhaustive cross-check kept as an
in-tree red-green fixture; F via Knuth–Moore exactness plus the committed audit's
339,959-node/state measurement (`audit-2x2-mismatch-zig.stdout:37-38`, verified) and
0/172 disagreements; G via the same audit figure plus a full alpha-beta diff sketch and a
seeded-defect control design. 4/4 each. B recommends the Part-A fixpoint and argues
preservation by re-reading what the tests assert ("the measured quantity the tests assert
is the Part-A value") plus the audit's 0/172 — a legitimate but citation-based argument
that does not itself prove root path-independence. 3/4. A, D, E recommend the state-graph
solver but **explicitly disclaim preservation** of the path-conditioned quantity (A: "this
is a definitional change, not a free optimization"; D: "no bounded fix exists" for the
path-conditioned function; E: "I cannot claim preservation, and I do not"). 0/4 each.

**Criterion 5 — denominator for every count.**
All seven provide denominators. A (§5), C (§4 table), F (§4), G (§4) are especially
thorough, giving state-space, reachable subset, branching, depth, budget, and node-count
figures each with a source line. D and E give denominators but quote the header's "1620"
for `TOTAL_STATES` at `:266` without flagging that the expression `81*2*(n+1)*3` evaluates
to **2430** for n=4 (the `// = 1620` comment is arithmetically wrong for the expression as
written). C, F, G flag this discrepancy explicitly. 2/2 for all (the discrepancy is a
citation-check note, not a missing denominator).

**Criterion 6 — concludes no bounded fix preserves semantics, proves it, names the ruler.**
A (§6), D (§5), E (§5) conclude no bounded fix preserves the full path-conditioned
semantics and prove it: A by a 3-step chain (the function depends on the visited-set, the
visited-set count is the exploding path count, so no exact algorithm can avoid
distinguishing them); E by the cleanest bound (≤1620×2^1620 ≈ 10^487 ancestor-sets); D by
the three-option trilemma. All three name the Orchestrator / ADR / Dabir as the ruler. 2/2
each. B, C, F, G conclude a bounded fix **exists**, so #6 does not apply (0/2); B picks up
1/2 because its §5 separately states the path-DFS-as-method is unbounded and names the
ruler, as a secondary verdict.

---

## Citation checks

I opened every load-bearing `file:line` a lane cited in support of a load-bearing claim.
Findings:

- **A** — `qa023_brute_2x2.zig:198,202-206,216-217,221,81,223,231,240,266,497-498,25-26,76-78,143,187-188`;
  `qa023_smoke_2x2.zig:4-5,13-17,19-20` — **all accurate** (smoke file lines 4-5 do say
  "2×2 has no reachable non-root cycles"; 19-20 do say "A build that returns +1 on 'empty
  B' has implemented PSK by accident"). A's 6-cycle witness is move-by-move legal under
  `apply_place`'s place→capture→suicide order; I confirmed it closes to the state after
  move 1.
- **B** — `qa023_probe.zig:33-35,106-108,155-217` **accurate**; `EXP-2.md:150-151,173-179`
  **accurate**; `proof-v2-2026-07-28.md:418-423` **accurate** (the S0/S1 counterexample).
  **Two inaccurate line ranges:** (i) B cites `proof-v2:680-696` for "audit finding F2 …
  keying on goban-only/(board,side)-only revisits defines a different evaluator" — F2 is at
  lines **662-680**; lines 680-696 are F3 (an unrelated Theorem-4.1 step). The substance B
  attributes to F2 is correct and exists verbatim at 662-680, but the cited range points at
  the wrong finding. (ii) B cites `reference-semantics-2026-07-29.md:88-90` for "the
  truncation-as-value failure the proof document calls out as banned" — lines 88-90 are
  smoke-expectation table rows, not a truncation ban; that concept lives in proof-v2
  Theorem 6.1 (`:396-406`) and F2 (`:662-680`). Both are mis-ranges, not fabrications
  (content exists in the corpus), so no −3; recorded as citation defects that lower B's
  citation-check score qualitatively.
- **C** — `qa023_brute_2x2.zig:201,216-217,221,266,321-336,497,501-508`;
  `rules.zig:103-170`; `newrule-2x2-3x2-2026-07-28.md:55-58` (the 24/172 divergence, **verified**);
  `untracked/T457-does-any-control-catch-a-semantics-change.md`;
  `findings/T457-semantics-change-detection.json:6` (**verified** — T457's note does say
  the memoized brute "returns -4 instead of 0" on the 1-ko state). C's claim that T457's
  headline is weakened by a wrong answer key is fairly argued. All citations accurate.
- **D** — `qa023_brute_2x2.zig:214,231,239,81,188,198,266,137,143`; `EXP-2.md:18-19,150-151,173-179`
  (**verified**); `ruleset-options.md:53-70,156-176` (**verified** — the RETRO_PLY / no-free-lunch
  section). Accurate. D quotes `TOTAL_STATES` as "1620 at :266" without flagging the 2430
  arithmetic — a missed discrepancy, not a mis-citation.
- **E** — `qa023_brute_2x2.zig:215-219,222,234,242,81,188,198,202,266,44,264,349`;
  `proof-v2:680-696` (cited for F2 — same off-by-~18-lines issue as B: F2 is at 662-680);
  `ruleset-options.md:53-70,156-176`; `ADR-0013:43` (**verified** — "the classic graph
  history interaction (GHI) failure"). E flags the 2430/1620 discrepancy correctly. The
  F2 range is inaccurate (same defect as B); not a fabrication.
- **F** — `qa023_brute_2x2.zig:202,204-207,217,221,231,239,188,189-191,266,497-498,501-508`;
  `goban-pathology-2026-08-05.md:159-176` (**verified** — V=1140, E=2042, one 160-state SCC);
  `audit-2x2-mismatch-zig.stdout:37-38` (**verified** — `alpha-beta nodes: total=20527408
  max-per-state=339959`); `audit-2x2-mismatch.md:26-27,283-285,300` (**verified**);
  `suite-truth.md:49-51` (**verified**); `exp4_solve.zig:555-594`; `audit_2x2_mismatch.zig:27-38,211-215`
  (**verified**); `retro.zig:1739` (**verified** — "every path is a unique ban set, so the
  memo barely reuses"). All accurate. F flags the 2430/1620 discrepancy.
- **G** — `qa023_brute_2x2.zig:202,203-207,217,225,254-257,81,221,188,198,501-508`;
  `audit-2x2-mismatch-zig.stdout:34-38` (**verified**); `audit-2x2-mismatch.md:26-27,283-285,300`
  (**verified**); `goban-pathology:159-160`; `suite-truth.md:49-51,58-63,68-70`;
  `ADR-0013:43`; `ADR-0010:42-53` (**verified** — "A memo write now requires ALL of…");
  `EXP-2.md:150-153,144-146`; `EXP-2B.md:44-58` (**verified**); `audit_2x2_mismatch.zig:211-215,27-38`
  (**verified**). All accurate. G flags the 2430/1620 discrepancy.

**No fabricated citations found.** Two lanes (B, E) cite `proof-v2:680-696` for finding F2;
F2 is at 662-680 and 680-696 is F3. The F2 substance they attribute is real and verbatim at
662-680, so this is an off-by-~18 line range, not a fabrication. B additionally cites
`reference-semantics:88-90` for a truncation ban that is not at those lines (it is in
proof-v2). Both are recorded as citation defects; neither clears the −3 fabrication bar.

---

## Disagreements between lanes

**1. The central split: does a bounded fix preserve what the search measures?**
- **No-fix camp (A, D, E):** the value function is path-dependent (interior), so no
  bounded fix preserves the path-conditioned semantics; the only bounded fix changes the
  definition to the state-graph value, which is a ruleset/ADR ruling, not a preservation.
- **Fix-exists camp (B, C, F, G):** a bounded fix exists (alpha-beta with no table, and/or
  the retrograde L/H fixpoint) and preserves the root measured quantity on 2×2.

**Who is right.** The fix-exists camp, and within it C/F/G over B. The no-fix camp proves
interior path-dependence (two visits to the same state under different ancestor-sets can
have different values) and then extrapolates to "no bounded fix preserves what the search
measures." That extrapolation is the error: the search's only entry point is `value(s)` =
`brute_value(s, ∅, 0)` (`:254-257`), the **root** value with empty history, and the root
value is path-independent on 2×2. C proves it (theorem: root = median(L,TIE,H) when the
forced-win length ≤ DEPTH_LIMIT; measured max forced-win = 3 ≪ 64; 264/264 exhaustive
cross-check); F and G prove it (Knuth–Moore alpha-beta exactness + the committed audit's
0/172 disagreements and 339,959-node/state cost). I independently verified the linchpin:
the 1-ko state's forced win is 3 plies (W@3 captures B@1 → Black has no legal placement,
cells 1 and 2 are both suicide → Black passes → White passes → terminal area_score = −4),
so neither the cycle check nor `DEPTH_LIMIT=64` can interfere with any forced line on 2×2.
The no-fix camp's impossibility proof is sound for the *full* function V(s, A) but does not
address the root, which is what `value(s)` measures. A's §6 chain, D's trilemma, and E's
10^487 ancestor-set bound all establish the full-function impossibility — a real result —
but they over-conclude about the root.

**2. The 1-ko smoke expectation (0 vs −4).**
- **C, F, G:** the true value of the 1-ko shape state (`board=[-1,1,0,0]`, W to move) is
  **−4** by a forced 3-ply line; the test's `expect(v == 0)` at `:508` is wrong and has
  been hidden by the budget crash (it never once measured anything).
- **A, B, D, E:** do not address it; B implicitly accepts 0 by listing the smoke anchors
  as holding under both quantities.

**Who is right.** C/F/G. I checked by hand: White@3 captures B@1 (B@1's liberties were
cell 3 alone); the resulting board `[-1,0,0,-1]` leaves Black no legal placement (B@1 and
B@2 each sit between two White stones, capture nothing, and die by suicide per
`rules.zig` Suicide), so Black must pass; White passes → terminal `area_score = −4`. −4 is
the global floor, so White's root value is exactly −4; no cycle or depth rule is consulted.
The `0` expectation is a non-sequitur (the test's own comment at `:497-498` admits the ko
shape cannot occur on 2×2, then leaps to "the 2×2 result must still be 0"). This also
retroactively weakens T457's "3 of 11 controls fire" headline, as C notes: the controls
were firing against a wrong answer key.

**3. The `TOTAL_STATES` arithmetic (1620 vs 2430).**
- **C, F, G (and E on the code figure):** flag that `pub const TOTAL_STATES: u64 = 81 * 2 *
  (n + 1) * 3;` at `:266` evaluates to **2430** for n=4 (81×2×5×3), while the inline
  comment `// = 1620 for 2x2` and the header at `:44`/`:264` say 1620 (counting only
  passes ∈ {0,1}). The bitset is allocated on the 2430 figure. Real discrepancy.
- **A, B, D:** quote 1620 uncritically.

**Who is right.** The flaggers. The expression and the comment disagree; the code allocates
2430. None of the lanes that quote 1620 are wrong about reachability (the reachable subset
is 258-282 regardless), but they miss a real defect.

**4. What to keep alongside the fix.**
- C, F, G keep the unpruned path search as a **demoted fixture / cross-check** (red-green
  in-tree on every run) and keep the loud budget + heartbeat. A, D, E treat the path search
  as something to replace. F and G additionally lower `NODE_BUDGET` toward the measured
  ~340k worst case to keep the alarm a real regression detector. The keep-the-fixture
  approach is stronger (it ships the equivalence proof with the fix, per the project's
  duplication-as-oracle doctrine).

---

## My verdict on the underlying question (independent of the lanes)

**Yes — a bounded fix that preserves what the search measures exists on 2×2.** Two shapes,
both measured-exact in the committed audit (`docs/audits/2026-07-30-audit-2x2-mismatch-zig.stdout`,
verified):

1. **Alpha-beta over the (path, state) tree with no transposition table** — Knuth–Moore
   exactness: the (path, state) tree is a plain minimax tree, full-window alpha-beta returns
   the exact root value regardless of move order, and nothing path-dependent is ever reused.
   Measured cost: 339,959 nodes/state worst case, 20,527,408 for all 172 reachable
   non-terminal states — three orders of magnitude under the 20M-per-query budget.
2. **The retrograde L/H fixpoint** over the ≤2430-tuple (reachable 258) state graph —
   converges in 4-6 sweeps; `value(s) = median(L(s), TIE, H(s))`. Agrees with the exact
   first-revisit root value on all 172/172 states (audit) and 264/264 (C's exhaustive
   check).

The reason preservation holds is a 2×2 fact: the maximum forced-win length over all
non-trivial states is **3 plies** (I confirmed one such line by hand for the 1-ko state),
so `DEPTH_LIMIT = 64` and the path-local cycle check never bind on a forced line — the
root value of the truncated path search equals the loopy-game (cycle = TIE) value, which is
history-independent. The earlier state-memo is still a **category error** (it caches
interior path-contaminated values, which are genuinely path-dependent, as A/D/E correctly
show) — but the root quantity it would have to cache is, on this goban, a function of the
state alone. The memo is "right answer, wrong reason, on this goban only" (F's framing),
which is exactly why it must not be taken as evidence for 3×2+ where C2 is falsified.

**The "no bounded fix" answer is too strong.** A, D, E prove the full path-conditioned
function V(s, A) is unbounded (the ancestor-set key space is exponential) — a real and
worth-stating result — but they conflate that with the root measured quantity, which is
bounded-computable. The honest scoped statement is: *no bounded fix computes the full
V(s, A); a bounded fix computes the root `value(s)` exactly on 2×2, and that is what the
search measures.* The definition change to the state-graph value (which A/D/E recommend and
C/F/G also offer as the fixpoint option) is only *required* if you want a method that
generalizes to 3×2+, where the root path-independence theorem's side condition
(forced-win ≤ DEPTH_LIMIT) is not known to hold and C2 is already falsified.

**One companion finding the fix must carry:** the 1-ko smoke expectation at `:508` must
change from `0` to `−4` (three independent evaluators agree; I verified the forced line by
hand). Per the project's assertion doctrine this needs a named author/timestamp and an
Orchestrator ruling, not a silent edit — but it is a correction of an expectation that the
budget crash had been laundering since the file's origin, not a widening of a test to fit a
broken implementation.

**Caveat on my own grading.** I did not run the Zig (the brief forbids writes); my
verification of the 1-ko forced line and the 6-cycle witness was by hand against
`rules.zig`'s move semantics, and my acceptance of the 339,959-node and 0/172-disagreement
figures rests on the committed audit stdout (line 37-38, opened and read), not on my own
run. The lanes that reported their own Python ports (C, F, G) all reproduced four
committed control numbers (legal boards = 57, reachable = 172, L/H fixpoint at the empty
goban, which smoke tests crash), which is the fidelity check I would want; I did not
re-port.

---

## Ranking and one-line characterisation

| rank | lane | total | character |
|---|---|---|---|
| 1 (tie) | **G** | 18 | Alpha-beta fix + seeded-defect control design; 58-witness path-dep census; flags 2430; identifies the −4 bug; explicit limits section (never ran Zig). Most rigorous about its own boundaries. |
| 1 (tie) | **F** | 18 | Alpha-beta fix with the audit's 339,959 measurement; four fidelity controls; traces the "24/172 divergence" to the EXP-4 shared-buffer artifact; flags 2430; identifies the −4 bug. Most measurement-grounded. |
| 1 (tie) | **C** | 18 | Retrograde fixpoint fix with a theorem + 264/264 exhaustive check kept as a red-green fixture; flags 2430; identifies the −4 bug and its implications for T457. Most theorem-heavy. |
| 4 | **B** | 18 | Correct fix-exists verdict via "the tests assert the Part-A value" + the audit's 0/172; strong path-dep via proof-v2 cite. Two inaccurate line ranges (F2 at 680-696 → 662-680; reference-semantics 88-90); no own witness or root-independence proof. |
| 5 (tie) | **A** | 16 | Clean "no bounded fix" with a verified 6-cycle witness and two-history demonstration; misses root path-independence, so disclaims preservation the fixpoint actually provides. |
| 5 (tie) | **E** | 16 | Cleanest impossibility proof (10^487 ancestor-sets); flags 2430; same F2 range slip as B. Misses root path-independence. |
| 5 (tie) | **D** | 16 | Solid trilemma + ruler named; quotes 1620 without flagging 2430; misses root path-independence. |

The three 16s are strong "no-fix" answers that happen to be wrong about the root (they
prove the full-function impossibility, which is real, and over-conclude). The four 18s are
the fix-exists camp; C/F/G are a clear tier above B on preservation rigor, all three
identifying the −4 bug and the 2430 defect that B and the no-fix camp miss.