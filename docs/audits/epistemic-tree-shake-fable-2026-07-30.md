<!--managent set=A-->

Task: user-dispatched tree-shake · Role: Auditor · Model: Fable 5 · Date: 2026-07-30

# Shaking the epistemic tree — weakest joints, missing leaves, and the region map

**Question asked (the user, verbatim in substance):** walk the epistemic tree
and shake it. Where are the connections weakest? Where do we need to fill in
leaves (add proofs, confirm, retest, rewrite tests in another language)? Do we
have table regions of perfect play, of optimal, of good, of guesses? Can we
divide and conquer the regions of uncertainty rather than the entire goban and
all table regions?

**Companion piece** to `epistemic-trajectory-audit-fable-2026-07-30.md` (T100),
which judged the trajectory. This file judges the *structure*: what holds the
tree up, what is rotten, and where the uncertainty actually lives.

Scope walked: `CLAIMS.md` (256 rows, 290 edges, §3 in-degree ranking, §4
consequence analysis, §5 inheritance audit I1–I25, §6 discrepancies D1–D18, §7
evidence-integrity), all five `boards/*/EPISTEMIC.md`, `boards/CONCEPTS.md`,
`knowledge-ladder.md`, the EXP-4 write-up, and a live `weizigo-claimlint` run
(2026-07-30: calibration PASS; 10 C1a orphans + 11 dangling paths FAILING; 76
PROVEN rows without committed evidence; 75 PROVEN rows with unknown
wrong-answer-pass-rate).

---

## 1. The region map — what kind of knowledge covers which slots

The table is not uniformly known. Every goban decomposes into three regions,
and the regions have sharply different epistemic quality. Rungs are the
knowledge-ladder's (K0 certified … K5 guess).

### 1.1 Fresh-start knowledge (the question the tables actually answer)

| goban | settled / terminal | single-score (L==H) | ko-sensitive |
|---|---|---|---|
| 2×2 | K1 | **K0/K1** — exact-solver match, writes-off artifact, byte-identical repro | trivial (no reachable non-root cycles) |
| 3×2 | K1 | **K1** — 540/540 L==H slots, 0 mismatches vs exact solver | **K4** — 378 slots (38.65%); generated under the falsified F1 guard |
| 3×3 | K1 | **CLAIMED only** — anchors + symmetry; artifact is the writes-ON (buggy-path) build; no exact-solver ground truth | **K4** — 8,698 slots (34.3%) |
| 4×3 | K1ᴵᴺᴴ (S4 inherited, not re-proven) | **CLAIMED/inferred** — writes-ON artifact, no ground truth | **K4** — 170,276 slots (26.47%) |
| 4×4 | K1ᴵᴺᴴ (S4 inherited) | **K3/K4** — Bellman-self-consistent EXHAUSTIVELY (M4: 0 violations over 48.6M slots, vb/vw form) but **no independent ground truth exists or can exist** (C1 untested; exact solve intractable) | **K4/K5** — 10,367,922 slots (21.32%), **including the empty goban** (bracket [−6,+16]) |

### 1.2 Real-game knowledge (any history) — the honest row

Under PSK with real histories, **every region above caps at K4**, because:
C2 is FALSE-AS-SCOPED at 3×2 (single-score values are *not*
history-independent), C3 is FALSE-AS-SCOPED at 3×3 (the bracket does not bound
real-game scores), and C4 is false by construction. There are no regions of
real-game perfect play anywhere in the shipped tables. This is settled, not
pending.

### 1.3 Play-weight vs slot-count — the trap in the region map

The ko-sensitive region is 21.32% of 4×4 slots but carries most of the *play*:
M5 shows 16 of 19 plies in both saved regression games are KO_SENSITIVE, and
the empty goban itself is. **Region size understates region importance by
roughly 4×.** Any divide-and-conquer plan must weight regions by reachability
and play frequency, not slot count — certifying 78.68% of slots certifies a
minority of actual game states visited.

### 1.4 The new-rule (basic ko + TIE=0) region structure — where this is heading

EXP-4's 3×2 pin census: L==H on **2,220/2,586 states (85.9%)**, pinned (TIE or
one-sided) on 366 (14.1%). Under loopy-fixpoint semantics the game is Markovian
*by definition*, so the C2 history problem dissolves by construction — that is
the entire point of the pivot. But EXP-4 also proved the divide is not free:
the 24/172 fixpoint-vs-truncation divergences at 2×2 are **all L==H states**
(L=H=±4). So under the new rule, "L==H" does **not** mean
"semantics-independent". The regions that matter there are:

- **agreement region** — fixpoint == first-revisit truncation, verified by
  within-budget brute force (2×2: 148/172; 3×2: 165/165 *within budget*);
- **divergence region** — enumerable, currently 24 known states at 2×2;
- **unknown region** — brute-force budget-exhausted (3×2: **335/500 sampled
  states**), which is exactly where the cycles live.

Whether "regions of perfect play" can exist at all is decided by the
trajectory audit's R1 adjudication: under option (a) (loopy fixpoint is the
deliverable) the L==H region is perfect-as-scoped and the divergence region is
a measured footnote; under option (b) (truncation is the rule) no table region
is ever more than K3 and the pinned region is unsalvageable. **The semantics
ruling is not just a reporting question — it decides whether the region map
can contain a "perfect" cell.**

---

## 2. The weakest joints, ranked

Ranked by (load carried) × (weakness of the joint). Citations are to the
register's own analysis where it exists — much of this the project has already
found; what it has not done is *act* on it.

**W1 — The eye-prune (ADR-0006): widest blast radius in the tree.**
A precondition of **every forward search ever used as ground truth** — the
2×2/3×2 exact solvers behind the only K0/K1 cells in the region map, the T13
C2-probe, the E2 player, the finisher — validated on **one position**
(`dead_white`, +25). If it is unsound, the "proven" cells of §1.1 fall with it:
the tree's strongest leaves all hang from this one branch. `CLAIMS.md` §4.2
calls it the experiment with the widest blast radius; `ADR0006-FALSIFY` is
registered and unstarted.

**W2 — T13 and the untracked/ evidence graveyard: the keystone is
unreproducible.** T13 (12/508 mismatches) is the falsification the entire
fresh-start reframe rests on, and its probe source is deleted. Same mechanism
took T02 (B1 least-fixpoint evidence), T07 (the eight findings that rewrote the
4×4 tree — its `[T07-N]` tags now cite a lost source), B05 (the reframe scope),
and D18 shows it **happening again live**: the H1-CENSUS reconciling BFS lives
in `/tmp`, uncommitted, already dangling in claimlint. One branch of the tree
is load-bearing citations into files that no longer exist.

**W3 — The O1 orphan chain: every shipped ko-sensitive value derives from a
falsified premise, and the register says so.** `GLOBAL.F2` (bracket-guided
finisher) ⟵ ADR-0010-CUT ⟵ C3, FALSE-AS-SCOPED at 3×3. O2/O3 (3×3 and 4×3 C1
CLAIMED), O4 (anchor-as-validation), O6 (the sha256 gate targets a hash of the
*buggy* artifact — reproducing it byte-identically would certify the bug) all
inherit it. The ko-sensitive column of §1.1 is K4 not because it is untested
but because its generator's soundness argument is *known-broken*.

**W4 — The semantic fork (trajectory audit §2).** Restated here because it is
also a structural joint: the EXP ladder's tables and ADR-0019's rule are two
different games, divergent on 24 known states, and every downstream leaf
(EXP-5/6/7, the K2 target itself) hangs on which one is the deliverable.

**W5 — 4×4 C1 has no possible direct test, and its sole support is
single-sourced.** Nine claims cite `4x4.M4`, all measured by **one tool**
(`weizigo-chainability`) on **one checkpoint file** whose byte-identity to the
gate-passed artifact is nowhere stated (D16). The lo/hi bracket form of the
FP1 check remains untested (the artifact carries no bracket columns). A
defect in that single tool silently corrupts nine rows. No independent
re-implementation of the Bellman-identity checker exists — and independent
re-implementation is the only method that has ever found a defect here.

**W6 — Contradictory statuses between goban files (D2/D3/D4/D6).** C3-at-4×4:
"falsified by analogy, not open" in the 4×4 file; the identical inference
*refused* at 4×3. FP3: ⬜ᴵᴺᴴ at 4×4, ✅ PROVEN at 4×3, same theorem, same
justification. S2 means the theorem in one file and the implementation in
another, with a 4×3 note claiming an S2-4×4 pass that the 4×4 file says never
ran. ADR-0016 ruled on the inheritance *rule*; **zero of the 25 audited
inheritance rows (I1–I25) have had their argument written down or withdrawn.**
The tree's cross-goban grafts are all unglued.

**W7 — The ledger's own hygiene: failing and drifting.** 10 C1a orphans + 11
dangling paths (FAILING now), 76/256 PROVEN rows with no committed evidence,
75 PROVEN rows whose checker has unknown wrong-answer-pass-rate (only 4 rows
have a measured discriminating rate). The ladder rule "losing evidence drops a
rung" is stated but unenforced — the linter does not yet demote.

**W8 — D7's unreconciled denominators below 4×4.** The census-vs-sweep
ko-sensitive gap is reconciled at 4×4 only (settled-slot exemption); at 2×2 the
gap is 5.36 pp and unexplained. Small gobans are the calibration set for every
big-goban instrument — a 5 pp unexplained disagreement in the calibration set
is not cosmetic.

---

## 3. Leaves to fill — and leaves to prune

The user's question implies filling; shaking also drops dead leaves. Both
lists, cheapest first. "Another language" = the standing independent
re-implementation rule (the only defect-finding method with a track record
here).

### 3.1 Fill (ordered by cost × payoff)

| # | leaf | what | cost | pays for |
|---|---|---|---|---|
| L1 | `4x4.FP1-C1/C2` | seed + zero-change checks — **post-hoc reads of existing logs/artifact**, check 3 already passes | hours | finishes an acceptance test two-thirds done; FP1 at 4×4 |
| L2 | D18 BFS | re-derive and **commit** the H1-CENSUS reconciling BFS | hours | stops the T13 mechanism recurring; un-dangles 3 rows |
| L3 | claimlint red | fix 10 orphans + 11 dangling paths | hours | ledger back to green; mechanical |
| L4 | `S2-impl` at 4×4 and 4×3 | Benson implementation regression battery | cheap | resolves D6; Wave-0 item, artifact-independent |
| L5 | `S4` at 4×4/4×3 | area-scoring battery vs an **independent reference scorer** (tiny Tromp–Taylor scorer in another language) | cheap | removes the ⬜ᴵᴺᴴ under every terminal value on the two biggest gobans |
| L6 | **T13 re-implementation** (Python or other) | rebuild the C2 probe from the surviving spec in `c2-falsification-3x2.md`, reproduce the 12/508 | medium | restores the keystone falsification to reproducible; trajectory-audit R4 |
| L7 | **EXP-4 divergence tracer** (Python) | trace 1–3 of the 24 mismatched 2×2 states end-to-end under both semantics | medium | feeds the R1 semantics adjudication with facts; EXP-4 §10 asks for exactly this |
| L8 | independent chainability checker | re-implement the Bellman-identity sweep in another language, run on the same checkpoint | medium | de-single-sources `4x4.M4` and the nine rows on it (W5) |
| L9 | `ADR0006-FALSIFY` | direct eye-prune falsification battery (retrograde-vs-forward disagreement harness already sketched in ADR-0009) | medium | W1 — the widest blast radius in the tree |
| L10 | ko-composition census at 4×4 | measure single-ko vs multi-ko fraction of the 10.4M ko-sensitive slots (B23 found 0% multi-ko at 3×3; B32's single-ko solver was byte-identical at 3×3) | cheap run | the enabling measurement for §4's divide-and-conquer |
| L11 | `4x4.S3b` test design | ko-legality-under-history: the only top-5 load-bearing unknown with **no experiment designed at all** | design work | closes the "no test even on paper" hole |
| L12 | D7 small-goban reconciliation | one settled-slot count per small goban | cheap | W8 |

### 3.2 Prune (dead or superseded leaves — decide, don't drift)

- **The Track A PSK branch (D3, F2/F3 regen, F4 byte-compare).** These are the
  top-ranked load-bearing unknowns in the register — *for the PSK deliverable*.
  The pivot makes the new-rule table the deliverable and PSK a reference point
  (EXP-8 gap measurement). If that stands, a full 4×4 writes-off PSK regen is a
  **reference-quality** expense, not a deliverable gate, and should be
  explicitly deprioritised or dropped rather than left ranked #1–#2. User
  decision; the register should record it either way.
- **O5/O6 documentation orphans**: `retrograde-4x4.md` still opens with the
  retracted "complete, validated 4×4 oracle" claim, no erratum banner; the
  sha256 gate targets the buggy artifact's hash. Both are one-paragraph fixes.
- **I1–I25**: each inheritance row gets its structural argument written down
  (per ADR-0016) or its inherited status withdrawn. Bulk documentation pass,
  parallelisable per goban file.

---

## 4. Divide and conquer — yes, and the tree already knows how

The uncertainty is **not** uniformly smeared over the goban or the table. It
is concentrated, flagged per-slot, and decomposable. Four divisions, in order
of leverage:

**4.1 Divide by slot flag (already computed).** The KO_SENSITIVE bit
partitions every table today. The single-score region is exhaustively
Bellman-chainable (M4: zero violations outside the flag, all five gobans) —
uncertainty about *fresh-start* values lives entirely inside the flag. The
attack surface is 10.4M slots at 4×4, not 48.6M.

**4.2 Subdivide the ko region by composition, then conquer the easy part.**
L10's census is the scout. At 3×3, 100% of ko-sensitive slots were single-ko
and the dedicated single-ko solver reproduced the finisher **byte-identically**.
If 4×4's ko-sensitive region is predominantly single-ko, a certified single-ko
sub-solver converts that fraction from K4 to K1 *without touching the general
finisher problem* — the classic divide: solve the structured subclass exactly,
quarantine the rest. The remainder (multi-ko tangles) becomes a small,
enumerable hard core that can be attacked per-SCC, bottom-up from the terminal
layers, each sub-solve independent.

**4.3 Divide by semantics-agreement under the new rule.** Post-R1, the
new-rule table splits into: (a) the fixpoint/truncation **agreement region**
(brute-force verified within budget), (b) the **divergence region** (24 states
at 2×2 — small, enumerable, and the right standing calibration fixture, per
trajectory-audit R2), and (c) the **budget-exhausted unknown** (335/500 at
3×2). Region (c) is the honest frontier: it needs either a smarter bounded
verifier (another-language re-implementation with transposition awareness) or
an explicit "verified only in regions (a)/(b)" scope line on every claim.

**4.4 Divide by play-reachability, not colex order.** §1.3's trap inverted
into a strategy: certify slots in order of *game relevance* — the reachable
set from the empty goban under alternating play (the kostate census machinery
already computes this: 45.7M of 48.6M at 4×4) intersected with the ko region,
stratified by depth. A table that is K1 on every state reachable in ≤N plies
of optimal play is a stronger *play* deliverable than one that is K1 on 90% of
colex space; the certification frontier should be a ply-depth contour, not a
percentage.

**What divide-and-conquer cannot do:** rescue real-game PSK claims. C2/C3 are
falsified — no partition of the *table* restores history-independence under
PSK, because the defect is in the state, not the coverage. Regional conquest
is worth doing only under the Markovian new rule (where regions, once
certified, stay certified) — one more reason the R1 semantics ruling is the
gate for everything in this section.

---

## 5. Recommended order

1. **R1 semantics adjudication** (from T100 — decides whether "perfect
   regions" can exist).
2. **L1–L5** in one cheap wave (hours each, no builds, three of them retire
   red linter state and two D-discrepancies).
3. **L6–L8** as the re-implementation wave (the method with the track
   record), one seat each, independent.
4. **L9 + L10** — the blast-radius test and the scout census that decides
   whether §4.2's conquest is available.
5. **Prune decisions** (§3.2) recorded in the register — one user ruling on
   Track A, then bulk I-row cleanup delegated.

The tree is load-bearing and mostly sound: the trunk (colex, kernel, OEIS
anchor, Knaster–Tarski) is K0, the scaffolding knows its own weak joints
(§4–§7 of the register found most of this before I did), and the rot is
concentrated in exactly three places — one unvalidated premise under the
strongest leaves (eye-prune), one deleted-evidence mechanism (untracked/), and
one unadjudicated fork (semantics). Shake those three and everything that
falls was already dead; what remains is a certifiable, regionally
conquerable structure.

— Fable 5 / Auditor, 2026-07-30
