# oracle-v2 M1 design — Pass-1 Audit

```
Auditor:  Opus 5 (claude-opus-5) · Task O-4 · Role: worker · Date: 2026-07-31
Target:   docs/design/oracle-v2/pass1/design-M1.md (PROPOSED, O-3, 2026-07-31)
Against:  docs/infra/oracle-v2/spec.md (pass 1, ratified G1)
Verdict:  NEEDS-FIX
```

## Verdict

**NEEDS-FIX.** The format architecture is sound — grouped-inline with a
4-byte colex group key and a 1-byte packed `(side, ko, passes)` entry key is
the right shape, and the R8 inventory (§7) is the most useful part of the
document. But the artifact cannot be frozen at G2 in this state:

- **Two blockers.** The file layout is specified two incompatible ways in the
  same document (BLOCKER-1), and the DTT column — the whole of R3 — is
  undefined as a quantity, with a literal reading that collapses every state
  to DTT ≤ 2 (BLOCKER-2). M2b and M3 are dispatched concurrently off this
  contract; neither defect survives contact with two independent implementers.
- **The F2 conclusion is right but the derivation is not, and the recommended
  remedy is wrong.** G and N are both already measured in this repo; the
  derived budget is **614.7–617.3 MB**, not the "595.7–643.2 MB" range in
  §5.1 — a breach of 2.5–2.9%, tighter and more certain than the design
  claims (MUST-1). But the design recommends amending a ratified requirement
  (R9) when a **1-byte schema change it never considered** clears the ceiling
  by 82 MB (CRITICAL-2). Re-scoping should be the last option on the table,
  not the first.
- **The integrity story does not hold.** The header SHA-256 covers 40 bytes
  of header and none of the ~600 MB payload, so A6's "one perturbed value"
  corruption is detectable by no format-level check at all (CRITICAL-1).

None of this is architectural. Every finding below is fixable in one revision
of the same document; no rewrite is required. The recommended path is a rev 1
of `design-M1.md` addressing BLOCKER/CRITICAL/MUST, then G2.

---

## What the design gets right

Recorded so the revision does not churn what is already correct:

- **R1 is honoured with no projection.** `(colex, side, ko_point, passes)` all
  survive to disk. The passes=2 omission (§2.3) is a genuine terminal contract
  per R10, not a projection — verified against `exp6_solve.zig:454-460`
  (3×2/3×3 path) and `:1179-1184` (4×4 child handling): passes=2 is absorbing,
  `L = H = genericAreaScore`, zero children.
- **R2 is honoured.** `L` and `H` are separate `i8` columns (§3). No pinned
  `V` anywhere in the format. The reader-side selection R2 requires is left to
  M3. This is the requirement v1 violated and the design does not repeat it.
- **The colex/key_byte split is the right compression.** §5.2 option 3's flat
  9-byte alternative (851 MB) is correctly rejected; the grouped form is
  already the compression, and D1's rejection of a separate group index is
  correct arithmetic.
- **KO_BITS derivation is correct** and `ko = n` for "none" matches the solver
  exactly (`exp6_solve.zig:882`: `pub const KO_NONE4: u5 = @intCast(N4);` — 16
  for 4×4, as §2.2's table requires).
- **§7's R8 baseline inventory** discharges F8 in substance: 11 format-level
  checks, 7 state-level, and — the part that shows real care — 3 checks the
  format explicitly does *not* support alone (§7.3). The I11 sidecar
  observation is a real M2b requirement the spec had not surfaced.
- **Naming (§6) matches spec §4 F9 exactly**, including the `untracked/`
  build discipline and the hash-then-deploy order. Nothing to fix.

---

## The byte budget, re-derived independently

The brief's core ask. I derived the budget from primary sources without using
§5.1's arithmetic.

### G — distinct gobans — is measured, to within 2%

§5.1 estimates `G ∈ 22M–25M` and §9.1 states the exact count "is not directly
measured by any census." Both bounds are in the repo:

| bound | value | source |
|---|---|---|
| **G ≥ 23,802,969** | `ko_point = none` addresses at 4×4 | `docs/evidence/GLOBAL.H1-CENSUS/4x4-standard.txt:41` |
| **G ≤ 24,318,165** | legal positions at 4×4 | `4x4-standard.txt:37`; census table row |

The lower bound holds because each `ko=none` address is a distinct board
reachable at passes=0, hence a stored group. The upper bound holds because
every group's colex must be a legal position. A third, near-coincident figure
— **23,813,121** distinct boards under the ko-disabled walk
(`4x4-ko-disabled.txt:40`) — sits inside the bracket and confirms it.

So `G = 23.80M–24.32M`, a 2.2% bracket worth 2.6 MB of file. The 22M and 20M
rows of §5.1's table are excluded by measurement; the 29.5M row conflates
*addresses* with *gobans* and overstates the upper bound by 21%.

### N — stored entries — is measured, and 99,133,036 is the right number

`exp6_solve.zig:1113` prints `# 4x4 compact states (passes ∈ {0,1}): {d}` —
this is a direct count of exactly the set the artifact stores. **N =
99,133,036 is correct and the design's choice of it is right.** Its *reason*
is wrong; see SHOULD-6.

### Result

```
size = 128 + G × 5 + N × 5
```

| G | N | size (bytes) | vs 600 MB |
|---|---|---|---|
| 23,802,969 (measured lower) | 99,133,036 | 614,680,153 | **+2.45% over** |
| 24,318,165 (hard upper) | 99,133,036 | 617,256,133 | **+2.88% over** |
| 24,318,165 | 102,838,092 (census ×2) | 635,781,413 | +5.96% over |

**Derived budget: 614.7–617.3 MB. The F2 breach is confirmed** — and it is a
*tight* breach: 14.7–17.3 MB, 2.4–2.9%. §5.2's verdict ("~605–620 MB") lands
in the right place by luck, on a range whose low end is refuted by evidence.

### The unit decides the gate — and the unit is decimal MB

At 614,680,153 bytes the artifact is **586.2 MiB** — *under* a 600 MiB
ceiling. The entire F2 verdict turns on whether "600 MB" is 10⁶ or 2²⁰, and
the design never says (and contradicts itself — MUST-2).

It is decimal. The spec's own reference point settles it: R9 records v1 at
"258 MB", and `data/oracle-4x4-basicko-tie-area.wzo` is **258,280,358 bytes**
= 258.3 MB decimal = 246.3 MiB. The revision must state this, because a reader
who assumes MiB will conclude there is no breach.

### The breach is removable without touching R9 — see CRITICAL-2

At 4 bytes per entry the same design yields **515.5–518.1 MB**, 14% under the
ceiling, with no compression, no re-scope, and no change to the key encoding.

---

## Findings

### BLOCKER-1 — the file layout is specified two incompatible ways

§1.1's diagram shows group headers **interleaved** with their entries:

```
Group 0: colex, count, entry 0, entry 1, …
Group 1: colex, count, entries…
```

§1's prose and Appendix A's pseudocode assume the opposite — a **segregated**
layout, all `G` group headers contiguous from `data_offset`, then all `N`
entries:

- §1: "the engine loads all 5-byte group headers into memory at startup",
  §1.1: "the reader can seek all group headers in one read (`n_groups × 5`
  bytes)" — impossible if they are scattered between entry runs.
- Appendix A: `readU32BE(groups[mid * 5 ..][0..4])` indexes group `mid` at
  `data_offset + mid×5`, and computes `entry_base = data_offset + n_groups × 5
  + entries_before_group × 5`.

The file-size formula `128 + G×5 + N×5` is identical under both layouts, so
the validation check cannot detect the disagreement. Concretely: under the
diagram, group 1's header for the 4-entry root group begins at byte 153; under
the pseudocode the reader looks for it at byte 133 and reads the middle of an
entry as a colex.

M2b (writer) and M3 (reader) are dispatched to different agents off a frozen
contract that says both things. This is the EXP-4→EXP-7 aliasing failure mode
the spec invokes in §5, arriving through the document rather than the code.

**Fix:** adopt the segregated layout (it is the one the reader needs, and the
only one where "read all group headers in one read" is true), redraw §1.1, and
state the three regions with their byte extents explicitly.

### BLOCKER-2 — DTT is not defined; the literal reading makes it worthless

R3 exists because "a value table is not a policy — under TIE=0 a winning
player can shuffle forever without a progress measure." The design specifies
DTT's *encoding* (§3.2: 0 / 1–254 / 255) but never its *definition*. Two
consequences:

**(a) The pass–pass collapse.** §3.2 says "steps to nearest terminal under
optimal play"; §7.2's I7 check says "every non-terminal's DTT ... ≤ a child's
DTT+1"; A8 says "every non-terminal's DTT exceeds at least one child's". All
three describe a plain minimum over children. But a pass is always legal, and
`exp6_solve.zig:964` shows the pass child of a passes=1 state is a passes=2
terminal with DTT=0. So under the minimum-over-all-children reading:

```
DTT(any passes=1 state) = 1        (pass → terminal)
DTT(any passes=0 state) = 2        (pass → passes=1)
```

Every state in the artifact gets DTT ∈ {1, 2}. A8 ("DTT is non-constant")
would *pass* — two distinct values, terminals at 0 — while the column carries
no information whatsoever. This is the v1 failure (one distinct value across
43,046,721 slots) reproduced in a form the acceptance criterion cannot catch.

The intended quantity is almost certainly distance to terminal **restricted to
value-preserving children**, with the standard adversarial asymmetry (the side
that gains by ending minimises; the side that loses maximises). That is not a
detail M2b can be left to invent: it changes the number in every row, and A8
and I7 are both stated against it.

**(b) DTT=0 is assigned to states that are not absorbing.** §3.2 says DTT 0
means "terminal (passes=2, **or passes∈{0,1} with no legal moves**)". A
passes=0 state with no legal placement is not absorbing — it has a pass child,
and the game ends two plies later. Giving it DTT=0 tells the engine "we are
done" when two moves remain, and breaks the I7 invariant for its *parents*: a
parent whose best child is such a state gets DTT=1 while the true distance is
3. §3.1's `TERMINAL` flag conflates the same two notions ("no legal non-pass
moves") with R10's absorbing passes=2 terminal, and §3.2 inherits the
conflation.

**Fix:** state the DTT recurrence explicitly (base case, child restriction,
min/max by side), reserve DTT=0 for absorbing terminals only, and give
no-legal-move states their true distance. Re-state A8/I7 against the
definition. If M1 judges the recurrence to be M2b's to choose, then it must
say so and A8/I7 must move with it — but then §3.2's semantics table cannot
stand as written.

### CRITICAL-1 — the SHA-256 protects 40 bytes and none of the data

The header field at offset 40 is "SHA-256 of all bytes before this field", and
validation step 6 confirms: "SHA-256 of bytes 0–39". The other ~614,680,000
bytes are unhashed.

§7.1 nevertheless lists "SHA-256 integrity" as a format-level check that is
"Computed post-build by M2b and verified on load", and pairs it with "File
size consistency ... Verifies no truncation or appendage" — the size check
does that work; the hash as specified does not.

This breaks A6 directly. Of A6's three named corruptions, **"one perturbed
value"** — flip one byte of one `L` column — passes every format-level check
in §7.1: magic, version, size, entry_size, ko_bits, group order, and the
header hash all still verify. It is caught only by I4 (Bellman residual),
which needs the full battery and a move engine. A6 requires the failure be
*named*; the format names nothing.

**Fix:** hash the whole file with the 32-byte slot zeroed, i.e. bytes
`0..40 ∥ 72..EOF` (or define the covered range explicitly). Make full
verification a load-time option (`--verify-hash`) rather than mandatory —
reading 600 MB to hash it defeats the mmap-lazy design — but make it
mandatory in M4a's A6 fixture path. Also state the relationship to R7's
recorded hash: R7's is of the *finished file including* the embedded slot;
they are two different digests and the document currently implies one.

### CRITICAL-2 — the recommended F2 remedy amends a ratified requirement when a 1-byte schema change suffices

§5.2 enumerates four options and recommends option 1: raise R9's ceiling to
650 MB. Options 2–4 (compress, flatten, store passes=2) are correctly
rejected. The option not on the list is **drop the `flags` byte**:

- **`KO_SENSITIVE` is redundant by the design's own admission** (§3.1: "is
  redundant with `L != H` but is stored explicitly so the reader can filter
  without comparing L and H"). Saving a comparison is not worth 99 MB.
- **`TERMINAL` fits in a bit the key_byte already has spare.** §2.2 allocates
  2 bits to `passes`, but §2.3 establishes that passes=2 is never stored — the
  field holds one bit of information. Re-layout as
  `[passes:1][ko:KO_BITS][side:1][terminal:1]`: 8 bits exactly at 4×4 (and at
  5×5), 6 bits at 2×2/3×2. Sort order is unaffected — `(passes, ko, side)` is
  unique within a group, so appending `terminal` as the LSB refines a total
  order into itself. Lookup masks bit 0 before comparing: `entry[0] & 0xFE ==
  target_kb`.

Entries become 4 bytes: `[key_byte][L][H][DTT]`.

| schema | G = 23.80M | G = 24.32M | with census N = 102.84M |
|---|---|---|---|
| 5 B/entry (as designed) | 614.7 MB | 617.3 MB | 635.8 MB |
| **4 B/entry (flags dropped)** | **515.5 MB** | **518.1 MB** | **532.9 MB** |

The breach is 14.7–17.3 MB. The flags byte is 99.1 MB. Dropping it clears the
ceiling by 82–84 MB — under every value of G and N considered, including the
paranoid census count. No compression, no re-scope, no change to the colex
group key, no loss of information.

D3's reasoning against bit-packing `L`/`H` is sound and should stand — that
proposal breaks byte alignment for a 50 MB saving. This one does not: all four
columns stay byte-aligned and the entry stays a fixed stride.

**Fix:** adopt 4-byte entries, or state a concrete reason not to. Do not carry
a spec amendment to G2 while a byte of admitted redundancy is in the schema.
If some future column is wanted, `entry_size` is in the header and 56 reserved
bytes are available — the format can widen later.

### MUST-1 — G and N are presented as unmeasured when both are measured

§5.1: "**G** is not directly measured by any census." §9.1: "The exact
distinct goban count G for 4×4 ... M2a's reachability builder will produce the
exact count; until then the budget is a range, not a point estimate."

Both bounds were available at design time — see "The byte budget, re-derived"
above: `4x4-standard.txt:41` (23,802,969) and the legal-position count
(24,318,165), from the same census document §5.1 already cites. The 3×3
extrapolation (13.5% → "plausibly 15–25%") is unnecessary, and its ground
truth is checkable: at 3×3 the design's formula gives 12,101 against an actual
12,149 distinct boards (`3x3-ko-disabled.txt:27`), a 0.4% undercount it never
validated.

The consequence is not cosmetic. §5.1's range admits a 595.7 MB row that is
refuted by evidence, which makes the breach look marginal and arguable when it
is neither. Spec §8 Q6 asks precisely whether the F2 gate can be satisfied
"with another projection instead of a derivation" — an estimated range where a
measurement exists is the soft spot that question was aimed at.

**Fix:** replace §5.1's estimate with the measured bracket, cite the evidence
files, and delete §9.1's claim. Keep the M2a cross-check as a confirmation
step, not as the source.

### MUST-2 — MB vs MiB is never stated, and the document uses both

- §5.1: 99,133,036 × 5 = 495,665,180 bytes reported as part of "595.7 MB" —
  decimal, 10⁶.
- §5.3: the same 495,665,180 bytes reported as "**~473 MB**" — that is
  472.7 **MiB**, 2²⁰.

The gate is decided by 2.5%. Under MiB the design's own numbers pass and §5.2
is moot. The spec's convention is decimal (v1: "258 MB" = 258,280,358 bytes),
so the breach is real — but the document must say so rather than leave a
reader to discover that two of its sections disagree.

**Fix:** state "MB = 10⁶ bytes throughout; the R9 ceiling is 600,000,000
bytes" in §5, and correct §5.3's figures.

### MUST-3 — `rules_id` points at the wrong file, has no allocated value, and is never validated

§4's header table: "`rules_id` | u16 | ruleset identifier (match
`src/rules.zig`)". Three problems:

1. **`src/rules.zig` contains no `rules_id`** (0 occurrences). The enumeration
   is `src/artifact.zig:76-77`: `RULES_CHINESE_PSK = 1`,
   `RULES_BASICKO_TIE_AREA = 2`, with names at `artifact.zig:82-88`.
2. **Neither existing value describes a WZO2 artifact.** Value 2 means
   "Chinese area, komi 0, basic ko, **TIE=0 on cycles**" — the pinned
   convention R2 explicitly removes. Writing 2 into a header whose whole point
   is that no convention is baked in would re-assert v1's defect in the one
   field R4 exists to make self-describing.
3. **The load-validation list (§4, steps 1–6) never checks `rules_id`.** Spec
   §3.1 makes the entire enforcement-mode decision — including
   `RULES-MISMATCH-FATAL` — a function of this field. The format contract must
   at minimum state that the reader compares it to the selected mode; today's
   engine hard-refuses anything but PSK (`gtp.zig:624`).

**Fix:** allocate a new id (3 = "Chinese area, komi 0, basic ko, convention-free
L/H bracket"), state the value the builder writes, correct the file reference,
add the §3.1 comparison as validation step 7, and note that `artifact.zig`'s
`rulesName` needs the new arm (an M3 edit, flagged here so it is not lost).

### MUST-4 — the header table is internally inconsistent and misaligned

**(a) `ko_bits` contradicts itself.** Row: `| 36 | 2 | ko_bits | u8 |`. Size
says 2 bytes, type says `u8`. The offsets only close if it occupies 2 (36→38,
38→40), so one of the three is wrong. `reserved2` has the same shape
(`| 38 | 2 | reserved2 | u8[2] |`) but is at least self-consistent.

**(b) Every u64 is misaligned.** `n_groups` at 12, `n_entries` at 20,
`data_offset` at 28 — all ≡ 4 (mod 8). A Zig `extern struct` mapped over the
mmap'd header will insert padding and silently not match this table; the
builder and reader must use byte-wise `std.mem.readInt`/`writeInt`. Given that
M2b and M3 are different agents, this needs to be an instruction, not a
hazard: either say "no struct overlay, accessors only", or move `rules_id`/
`entry_size`/`ko_bits` ahead of the u64 block so the layout is naturally
aligned. The latter is free — the header is being defined now.

### MUST-5 — the R8 inventory omits four of the nine acceptance criteria

R8 defines the baseline as "the A1–A9 harness in §4 **plus** the reader-side
checks that M1's `design.md` enumerates". §7 covers A2/A3/A4/A5/A8 (under
their I-numbers) and the I-series, but **A1, A6, A7 and A9 appear nowhere**.
A1 and A7 are fairly M3/M4b concerns, but two are format-load-bearing:

- **A6 (known-bad calibration)** names three corruptions — one perturbed
  value, one dropped ko state, one zeroed DTT column. The inventory must map
  each to the check that names it. As the format stands: perturbed value →
  *nothing* (CRITICAL-1); dropped ko state → only I6/UNDEF census, since a
  self-consistently rebuilt file with `n_entries` decremented passes the size
  check; zeroed DTT column → I7, and only if DTT is defined (BLOCKER-2). A6 is
  the criterion the spec §6 says makes every other criterion interpretable;
  the format is where it is either detectable or not.
- **A9 (reproducibility)** requires a byte-identical rebuild, and the design
  never states a determinism contract. It should: reserved bytes zeroed
  (§4 says so for the fields — say it as a rule), canonical sort order (§2.4
  covers entries; state it for groups too), no timestamps or build metadata in
  the header (currently true by omission — make it explicit), and the exact
  hash-slot procedure (zero, hash, write in place).

**Fix:** add an A1–A9 column or a short subsection to §7 stating, for each,
whether the format supports it, supports it partially, or does not bear on it.

### SHOULD-1 — §5.3's load-time RAM figure contradicts Appendix A

§5.3: "load_RAM = G × 5 bytes ... The engine's working set is ~120 MB". But
Appendix A establishes that the reader also needs `entries_before_group`, "and
the array of offsets adds `G × 4` bytes (~100 MB) to the load-time memory."
The real figure is ~215 MB, not ~120 MB. Well inside the 4 GB cap either way,
but the two sections should not disagree.

The cheap fix is worth stating in the contract, since M3 will otherwise
allocate the full array: sample the prefix sum — store the cumulative entry
index every 256th group (G/256 × 4 ≈ **372 KB**) and sum ≤ 255 count bytes at
lookup time. Group counts are already in cache-resident order.

### SHOULD-2 — big-endian colex (D4) buys nothing as designed

D4's rationale is that BE "ensures the on-disk sort matches numeric colex
order, so binary search on the in-memory array works without byte-order
correction." But Appendix A's search reads `readU32BE(...)` and compares
*numerically* — that is correct for any byte order, and on a little-endian
host it costs a `bswap` on each of ~25 probes per lookup. BE would matter for
a raw `memcmp` over 5-byte records, or for an external merge sort during the
build; neither is described.

D5 states the principle ("each field uses the endianness that makes its
primary consumer correct") and then applies it to a consumer that does not
exist. Either commit to LE throughout — the Zig-native choice, matching the
header — or name the memcmp/sort path that justifies the exception. A
deliberate mixed-endian format needs a stronger reason than a byte-swap that
the code does not perform.

### SHOULD-3 — §2.4's within-group ordering is wrong for multi-ko groups

§2.4 claims entries sort as "passes=0 side=B, passes=0 side=W, passes=1
side=B, passes=1 side=W, with ko variants interleaved naturally." With the
stated bit layout `[passes][ko][side]`, the order is `(passes, ko, side)` — so
for a board with two ko values the sequence is (p0,ko_none,B), (p0,ko_none,W),
(p0,ko_c,B), (p0,ko_c,W), (p1,…). The four-element list holds only for
single-ko groups. Minor, but M2b will implement the writer's comparator from
this sentence.

### SHOULD-4 — §2.3's passes=2 value is described as side-dependent, and the sign convention has no provenance

§2.3: "`L = H = genericAreaScore(goban)` (using the side-to-move in the lookup
key)". Area score does not depend on the side to move. Verified: the fixpoint
pins both terminals to the same `genericAreaScore(...)` regardless of side
(`exp6_solve.zig:458-459`) and treats side only as the min/max selector
(`const maximizing = side == 0`, `:485`). The stored bracket is therefore
**absolute, Black-positive** — which §3 asserts but never sources.

This matters more than the parenthetical: A3's colour-inversion identity and
M3's child-value comparisons are both stated against the convention, and a
reader who assumes side-relative (negamax) values will produce an artifact
that fails A3 exhaustively. Cite `exp6_solve.zig:444-531` and delete the
parenthetical.

### SHOULD-5 — a free invariant is missed: passes ≥ 1 ⇒ ko = none

The pass move resets the ko point: `encodeState4(board_idx, 1 - side,
KO_NONE4, passes + 1)` (`exp6_solve.zig:964`). Every state with passes ≥ 1 is
reached by a pass, so **every stored entry with passes=1 has ko = none**.

Three uses, all free:

1. **An R8 format-level check** — "no stored entry has passes=1 and ko ≠ none"
   — costs one mask per row and catches a whole class of writer bug (key
   packing, field order, off-by-one in the ko field) that no current check in
   §7.1 would notice.
2. **It tightens the group bound** — max entries per group is 2 sides × 17 ko
   at passes=0 plus 2 at passes=1 = **36**, not 68 (COULD-1).
3. **It strengthens D2** — passes=2 states also all carry ko=none, so the
   omitted set is at most 2 × 23.8M = 47.6M entries, which bounds D2's "~50M"
   claim instead of estimating it.

### SHOULD-6 — the stated reason for choosing N is wrong, and 102,838,092 is not an upper bound

§5.1 says "the solver's count is 3.6% lower, likely due to more restrictive
reachability accounting" and §9.2 calls the census figure "an upper bound".
Neither holds:

- **The census's "with passes" column is arithmetic, not a measurement.**
  `src/kostate_census.zig:663`: `triples_with_passes = if (passdim) triples * 2
  else triples`. The census walk has no passes dimension and generates no pass
  edges (successor generation, `:468-496`, enumerates placements only). The
  102,838,092 figure is 51,419,046 × 2, and the evidence file prints it as
  such: `(a') with passes in {0,1} (x2)`.
- **It is therefore not a bound in either direction.** A pass lets one side
  move twice in effect, so the solver's walk reaches `(b, side, ko)`
  combinations a strictly-alternating placement walk cannot. The arithmetic
  shows the two counts are not comparable: `#passes=1 ≤ 2 × 23,802,969 =
  47,605,938` (by SHOULD-5), which with the census's 51,419,046 triples caps a
  census-derived total at 99,024,984 — **below** the solver's measured
  99,133,036. The solver's set is broader, not "more restrictive".

The number the design chose is right; N = 99,133,036 is a direct count of the
stored set (`exp6_solve.zig:1113`). The revision should say that, cite the
line, and state that EXP-3 cannot cross-check it — which makes §9.2's residual
uncertainty (M2b's own count is the only authority) real and worth keeping.

### COULD-1 — state and assert the entry-count bound

`entry_count` is `u8`. Max entries per group is 36 at 4×4 (SHOULD-5), 68 by
the naive bound, 104 at 5×5 — all fit, but the writer should assert it rather
than truncate silently, and the contract should record the bound.

### COULD-2 — the u32 colex caps the format at 20 cells, not 5×5

§3 notes `i8` L/H suffice "for all gobans through 5×5 (n=25)", which invites
the inference that the format reaches 5×5. It does not: `3^25 = 8.47 × 10¹¹`
overflows the u32 colex. The format's real ceiling is 20 cells
(`3^20 = 3.49 × 10⁹`, i.e. 4×5). Worth one sentence so a future goban does not
inherit a silent truncation.

### COULD-3 — interval typo

§2.1: "a u32 in `[0, 3^(w·h) − 1)`" — the interval is closed,
`[0, 3^(w·h) − 1]`.

### COULD-4 — group header size is not self-describing

`entry_size` is a header field, but the group header's 5 bytes are hard-coded
in the size formula and the reader. Either add `group_header_size` for
symmetry or state that 5 is fixed by the format version.

### COULD-5 — no header bit records that passes=2 is omitted by contract

R4 asks that the key encoding be inferable from the artifact. A future reader
cannot distinguish "this artifact omits passes=2 by design" from "this
artifact is missing its passes=2 entries". One reserved bit, or one sentence
in `format.md`, closes it.

---

## Brief-mandated checks

| check | result |
|---|---|
| **Byte budget ≤ 600 MB** | **FAIL as designed** — 614.7–617.3 MB, breach confirmed at +2.5–2.9% (MUST-1, MUST-2). **Recoverable without re-scope**: 515.5–518.1 MB at 4 B/entry (CRITICAL-2). |
| **Key encoding uses 51.4M triples, passes NOT folded** | **PASS on substance, FAIL on citation.** Passes is genuinely not folded — passes=0 and passes=1 are distinct stored keys (§2.2, §2.4), which is what F2 demanded. But the operating count is the solver's 99,133,036, not the census's 51,419,046 × 2; that is the *correct* choice and the wrong justification (SHOULD-6). |
| **Column schema stores L/H separately** | **PASS.** Separate `i8` columns, no pinned V, reader-side convention (§3, R2). Range `[−n,+n]` correct. DTT column present but undefined (BLOCKER-2); `flags` redundant (CRITICAL-2). |
| **Header layout** | **NEEDS-FIX.** 128 B fixed, offsets close, magic/version/size validation sound. But: `ko_bits` size/type contradiction and u64 misalignment (MUST-4); `rules_id` unallocated and unvalidated (MUST-3); SHA-256 covers 40 bytes (CRITICAL-1). |
| **Naming convention** | **PASS.** `data/oracle-{goban}-v2.wzo2` matches spec §4 F9 exactly; `untracked/oracle-v2/` build discipline, hash-then-deploy order, and `.wzo2`/`.wzo` coexistence all correct. No findings. |

---

## End-to-end trace (review standard SF2 rule 1)

Traced the 4×4 root — empty goban, Black to move, no ko, no passes — from key
to bytes and back.

**Encode.** colex = 0 (empty board, base-3 rank 0). side = 0 (Black).
ko = KO_NONE4 = 16 (`exp6_solve.zig:882`). passes = 0.
key_byte = `[passes:2=00][ko:5=10000][side:1=0]` = `0b00100000` = **0x20**.

**The group.** Colex 0's stored entries are the states with an empty board and
passes ∈ {0,1}. The solver seeds both sides at passes=0
(`exp6_solve.zig:1002`) and the pass child `linearIndex4(0, 1, KO_NONE4, 1)`
(`:1256`) is reachable, so the group holds 4 entries with key bytes 0x20
(p0,B), 0x21 (p0,W), 0x60 (p1,B), 0x61 (p1,W) — ascending, matching §2.4's
`(passes, ko, side)` order (this group has one ko value, the case where
§2.4's prose happens to be right; see SHOULD-3).

**Locate.** Header parsed from bytes 0–127; `data_offset` = 128. Group array
begins at 128; group 0's colex is bytes 128–131 = `00 00 00 00` (BE),
`entry_count` = byte 132 = `04`. Binary search terminates immediately at
index 0. `entries_before_group` = 0, so `entry_base = 128 + G×5`.
At G = 23,802,969 that is byte **119,014,973**. Entry 0 occupies bytes
119,014,973–119,014,977: `[0x20][L][H][DTT][flags]`.

**Decode.** `L = @bitCast(entry[1])`, `H = @bitCast(entry[2])` as i8,
Black-positive; DTT = `entry[3]`; flags = `entry[4]`. Round-trip of the key is
lossless — colex and key_byte reconstruct `(goban, side, ko, passes)` exactly,
which is A5's claim at the format level.

**What the trace found.** Under §1.1's diagram instead of the pseudocode, group
0's header still sits at 128 but its four entries occupy bytes 133–152 and
group 1's header begins at 153 — where the reader computed 133 and would parse
entry bytes as a colex, then binary-search a non-monotone array. The two
layouts diverge at the second group and never resync. This is BLOCKER-1, and
it is invisible to every validation check in §4 because the file size is
identical under both.

Second observation from the trace: the `flags` byte at 119,014,977 carries at
most 2 bits, one of them (`KO_SENSITIVE`) recomputable from the two bytes
preceding it. Multiplied by N that is the 99 MB of CRITICAL-2.

---

## Summary

| Grade | Count | IDs |
|-------|-------|-----|
| **BLOCKER** | 2 | BLOCKER-1 (layout specified two ways), BLOCKER-2 (DTT undefined; pass–pass collapse) |
| **CRITICAL** | 2 | CRITICAL-1 (SHA-256 covers 40 B, not the payload), CRITICAL-2 (re-scope recommended over a 1-byte fix that clears the ceiling) |
| **MUST** | 5 | MUST-1 (G and N are measured), MUST-2 (MB vs MiB decides the gate), MUST-3 (`rules_id` wrong file, no value, unvalidated), MUST-4 (header inconsistency + misalignment), MUST-5 (R8 inventory omits A1/A6/A7/A9) |
| **SHOULD** | 6 | SHOULD-1 (load-RAM contradiction), SHOULD-2 (BE colex buys nothing), SHOULD-3 (ordering prose), SHOULD-4 (side-dependent area score; convention provenance), SHOULD-5 (passes≥1 ⇒ ko=none, a free invariant), SHOULD-6 (N's justification; census ×2 is arithmetic) |
| **COULD** | 5 | COULD-1 (entry-count bound), COULD-2 (u32 colex caps at 20 cells), COULD-3 (interval typo), COULD-4 (group header size), COULD-5 (passes=2 omission not self-described) |

**Not ready for G2.** Recommended sequence: revise `design-M1.md` for
BLOCKER-1/2, CRITICAL-1/2 and the five MUSTs; the SHOULDs are cheap and should
go in the same pass. The revision does not need a fresh design task — every
finding is local to a section, and §§2, 6 and 7 are largely sound as they
stand.

**One item is for the Orchestrator, not M1.** §5.2's re-scope request should be
held, not forwarded: if CRITICAL-2 is adopted the derived budget is 515.5–518.1
MB and R9 needs no amendment. Only if the 4-byte schema is rejected for a
reason M1 can state does the F2 gate genuinely return the sprint for
re-scoping.

## What I could not establish

1. **Whether M2b's entry count will match 99,133,036.** The design flags this
   (§9.2) and it is real, but for a different reason than stated: EXP-3's
   census cannot bound it (SHOULD-6), so the solver's own walk is the only
   authority until M2b runs. The budget's sensitivity is low — ±1M entries is
   ±4–5 MB — and the 4-byte schema absorbs far more than that.
2. **The true DTT maximum**, and therefore whether the 254 cap binds. This is
   unanswerable until DTT is defined (BLOCKER-2); §9.3's claim that the FAR
   sentinel degrades "gracefully" is not supportable as written, because
   §3.2's own verifier rule and A8 both treat 255 on a non-cycle state as a
   failure.
3. **Whether the group set G matches the census bracket under M2b's walk.**
   The lower bound (23,802,969) is safe — the census's reachable set is a
   subset of the solver's. The upper bound I used is the legal-position count,
   which is unconditional. A walk-specific figure needs M2a.
