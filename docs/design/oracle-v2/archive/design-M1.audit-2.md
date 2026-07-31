# oracle-v2 M1 design rev 1 — Re-audit

```
Auditor:  Opus 5 (claude-opus-5) · Task T146 · Role: worker · Date: 2026-07-31
Target:   docs/design/oracle-v2/pass1/design-M1.md (PROPOSED rev 1, O-3-rev1, 2026-07-31)
Against:  docs/design/oracle-v2/pass1/design-M1-audit.md (O-4, Opus 5, 2026-07-31)
          docs/infra/oracle-v2/spec.md (pass 1, ratified G1)
Verdict:  NEEDS-FIX
```

## Verdict

**NEEDS-FIX.** Rev 1 is a large, honest revision. Both blockers are addressed,
both criticals are fixed and the F2 gate now **passes on a derivation I
re-verified independently** — 515.5–518.1 MB against a 600,000,000-byte
ceiling. Sixteen of the twenty-one filed findings are fully discharged, and I
re-checked every source citation the revision added: all of them resolve to the
line they claim.

Three things stop it at G2:

- **MUST-5 is not resolved — it is answered against the wrong criteria.**
  §7.1 maps "A1–A9", but **five of the nine A-numbers do not match spec §4**.
  The design's A1 is the spec's A4, its A2 is the spec's A3, its A4 is the
  spec's A2, its A7 is not an acceptance criterion at all, and its A3 (`L ≤ H`)
  is an I-check the spec never lists as an A. The spec's real **A1 (refusal
  rate — "the headline criterion") and A7 (gate chain reproduced) appear
  nowhere.** R8 defines the baseline inventory as "the A1–A9 harness in §4
  plus…"; M4a is dispatched to build "A3, A5, A6 fixtures, A9 recipe". Freezing
  this table gives M4a two incompatible definitions of A3. (NEW-1)
- **BLOCKER-2's replacement definition has substantive defects.** The two
  defects I named are genuinely fixed — the pass–pass collapse is broken and
  DTT=0 is reserved for absorbing terminals. But the new recurrence assigns
  min/max **by colour rather than by beneficiary**, which makes DTT not
  colour-inversion invariant and leaves White with no progress measure at all —
  defeating the one sentence of rationale R3 exists for (NEW-2). Its
  value-preservation test compares the wrong bound and admits value-losing
  children into a minimum (NEW-3). And step 5's FAR condition contradicts step
  3's max (NEW-4).
- **MUST-2 is half-fixed.** §5 correctly declares "MB = 10⁶ bytes throughout".
  §5.3 then reports 396,532,144 bytes as "**≈ 378 MB**" — that is 378.2 **MiB**.
  The same section reports group headers in decimal MB. This is the identical
  defect in the identical section; only the operand changed. (NEW-5)

None of this is architectural, and none of it touches the F2 conclusion. NEW-1
is a table rewrite against a document already in the repo; NEW-5 is one number;
NEW-2/3/4 are three sentences of §3.1. **REDO is not warranted** — §§1, 2, 4, 5,
6 and 8 are sound and should not be reopened.

---

## Disposition of the O-4 findings

| finding | claimed | verified | note |
|---|---|---|---|
| **BLOCKER-1** layout two ways | Fixed | ✅ **RESOLVED** | §1's region table, §1.1's diagram, and Appendix A now all describe the segregated layout. `entry_base = group_base + n_groups × 5` in the pseudocode matches the diagram's third region exactly. Byte extents stated. |
| **BLOCKER-2** DTT undefined | Fixed | ⚠️ **RESOLVED AS FILED — new findings** | Both named sub-defects are gone: (a) the pass–pass collapse is broken (step 3 ranges over placements only, so a passes=1 state no longer inherits DTT=1 from its terminal pass child); (b) DTT=0 is reserved for passes=2, and §3.2's "Key consequence" paragraph states the no-legal-placement case explicitly. The replacement definition has three defects of its own — NEW-2, NEW-3, NEW-4. |
| **CRITICAL-1** SHA-256 covers 40 B | Fixed | ✅ **RESOLVED** | §4.2: whole file with the 32-byte slot zeroed; the three-step write procedure is stated; `--verify-hash` is a load-time option, mandatory in M4a's A6 path and the verify-battery. The R7 relationship is stated correctly — R7's digest is of the finished file *including* the slot, so the two digests differ and both are reproducible. This was the specific ambiguity I asked to be closed. |
| **CRITICAL-2** re-scope over a 1-byte fix | Fixed | ✅ **RESOLVED** | 4-byte entries adopted; `flags` dropped; `terminal` in the key_byte LSB; KO_SENSITIVE computed as `L != H`. Arithmetic re-derived below — all three rows of §5.2 are correct to the byte. The R9 amendment request is withdrawn. |
| **MUST-1** G and N unmeasured | Fixed | ✅ **RESOLVED** | Both citations verified line-exact: `4x4-standard.txt:37` = 24,318,165 legal positions; `:41` = 23,802,969 `ko_point = none`; `4x4-ko-disabled.txt:40` = 23,813,121, inside the bracket. §9.1's "not directly measured" claim is gone; §9.3 keeps M2a as confirmation, not source. Correct. |
| **MUST-2** MB vs MiB | Fixed | ❌ **NOT RESOLVED** | §5 declares the unit correctly. §5.3 violates it — NEW-5. |
| **MUST-3** `rules_id` | Fixed | ✅ **RESOLVED** | id 3 allocated with a name; the enumeration table distinguishes v1/v2. Citations verified: `artifact.zig:76-77` are the two existing constants, `:82-88` is the `rulesName` switch body, `:191` is the load-validation line that rejects unknown ids. §4.3 step 7 adds the comparison and names `RULES-MISMATCH-FATAL` per spec §3.1. |
| **MUST-4** header inconsistent/misaligned | Fixed | ✅ **RESOLVED** | `ko_bits` is now u8/1 B. u64s sit at 16, 24, 32 — all 8-byte aligned. `group_header_size` added at 12. Offsets close: 4+2+1+1+2+2+1+1+1+1+8+8+8+32+56 = 128. One residual cosmetic issue against D7's stated overlay — NEW-7. |
| **MUST-5** R8 inventory omits A1/A6/A7/A9 | Fixed | ❌ **NOT RESOLVED** | §7 is restructured well, but the A-numbers are wrong — NEW-1. |
| **SHOULD-1** load-RAM contradiction | Fixed | ✅ | §5.3 and Appendix A now agree: group index G×5 ≈ 120 MB, sparse prefix sum every 256th group, ≤ 255 count-byte additions per lookup, < 1 MB extra. The design is better than the one I suggested — it reuses the count bytes already resident in the group index rather than materialising a second array. |
| **SHOULD-2** BE colex buys nothing | Fixed | ✅ | LE throughout; §2.1 and D4 both say so; Appendix A reads `.little`. |
| **SHOULD-3** ordering prose | Fixed | ✅ | §2.4 now states `(colex, passes, ko, side)` and its equivalence to `key_byte & 0xFE`, with the multi-ko sequencing described correctly. |
| **SHOULD-4** side-dependent area score | Fixed | ✅ | The parenthetical is gone; §2.3 states the value is absolute and Black-positive and cites the fixpoint. Citation is one line off (`:457-459`; the two assignments are `:458-459`, `:457` is the `unrank_board32` call) — immaterial. `:485` is exactly `const maximizing = side == 0;`. |
| **SHOULD-5** passes ≥ 1 ⇒ ko = none | Fixed | ✅ | §2.5 added, cited to `exp6_solve.zig:964` (verified: `encodeState4(board_idx, 1 - side, KO_NONE4, passes + 1)`), and actually *used* in three places — the §2.4 group bound, the §7.2 format check, and D2's sizing. |
| **SHOULD-6** N's justification | Fixed | ✅ | `exp6_solve.zig:1113` verified — it is the `# 4x4 compact states (passes ∈ {0,1})` print. §5.1 and §9.1 both state that the census ×2 is arithmetic and cannot cross-check. |
| **COULD-1** entry-count bound | Fixed | ✅ | `2 × (w·h + 2)` = 36 at 4×4, derived from §2.5 rather than asserted. Writer assert mandated. |
| **COULD-2** u32 caps at 20 cells | Fixed | ✅ | §2.1 states it. §3 still says "through 5×5 (n=25)" for the i8 range — true of i8, contradicted for the format; see NEW-9. |
| **COULD-3** interval typo | Fixed | ✅ | Closed interval. |
| **COULD-4** group header size | Fixed | ✅ | Header offset 12, validation step 5. |
| **COULD-5** passes=2 omission flag | Fixed | ✅ | `hdr_flags` bit 0 = `PASSES_2_OMITTED` at offset 14, with a §7.2 check. |

**Score: 16 fully resolved, 2 resolved-with-new-findings-against-the-fix
(BLOCKER-2, MUST-4), 2 not resolved (MUST-2, MUST-5), 1 partially (COULD-2).**

---

## The F2 budget, re-verified

I recomputed §5.2 from the primary counts rather than checking the design's
arithmetic.

```
size = 128 + G × 5 + N × 4
```

| G | N | bytes | MB (10⁶) | vs 600,000,000 |
|---|---|---|---|---|
| 23,802,969 | 99,133,036 | 515,547,117 | 515.5 | **−14.07%** (84.5 MB spare) |
| 24,318,165 | 99,133,036 | 518,123,097 | 518.1 | **−13.65%** (81.9 MB spare) |
| 24,318,165 | 102,838,092 | 532,943,321 | 532.9 | −11.18% (67.1 MB spare) |

All three rows are correct to the byte. **F2 passes.** The R9 amendment §5.2 of
rev 0 asked for is correctly withdrawn, and the Orchestrator item I flagged in
the O-4 audit ("hold the re-scope request") is discharged — R9 needs no
amendment.

**An unforced confirmation the design does not claim.** N/G = 99,133,036 /
23,802,969 = **4.16 entries per group**. §2.5's structure predicts exactly 4 for
the typical board — 2 sides at passes=0 with `ko = none`, plus 2 sides at
passes=1 (which §2.5 proves must have `ko = none`) — with the 0.16 excess
accounted for by the 5,694,360 ko-cell addresses at `4x4-standard.txt:42`. Two
independently measured numbers agreeing with a structural argument to 4% is
worth more than either measurement alone, and §1's "typically 1–6 entries per
group" is confirmed rather than estimated. Worth one sentence in §5.1.

---

## New findings

### NEW-1 (CRITICAL) — §7.1 maps a renumbered A-series that is not the spec's

This is MUST-5's replacement, and it is answered against criteria that do not
exist. Spec §4 (`docs/infra/oracle-v2/spec.md:118-126`) against §7.1:

| # | spec §4 says | design §7.1 says | |
|---|---|---|---|
| **A1** | **Refusal rate** — 0 `UNCHAINABLE` on ≥ 100 pinned-seed queries. *"This is the headline criterion."* | pin census | ❌ |
| **A2** | **Bellman residual = 0** after a decode round-trip | colour inversion | ❌ |
| **A3** | **Colour inversion, exhaustive** | `L ≤ H` | ❌ |
| **A4** | **Pin census** (`pin_L == pin_H`) | Bellman residual | ❌ |
| **A5** | Round-trip identity | round-trip identity | ✅ |
| **A6** | Known-bad calibration | known-bad calibration | ✅ |
| **A7** | **Gate chain reproduced** (2×2 = 0, 3×2 = 0, 3×3 = +9) | UNDEF census | ❌ |
| **A8** | DTT non-constant | DTT non-constant | ✅ |
| **A9** | Reproducibility | reproducibility | ✅ |

The spec's A1 and A7 are absent, and `L ≤ H` (spec I3) has been promoted into
the A-series where the spec never put it. The I-series numbering in §7.2/§7.3
is, by contrast, **exactly right** — I checked all twelve against
`docs/design/verify-battery/pass0/spec.md:64-72` and
`docs/infra/verify-battery/spec.md:95`; I1 pin, I2 colour inversion, I3 `L ≤ H`,
I4 Bellman, I5 KO_SENSITIVE ⊆ cycle-reachable, I6 UNDEF, I7 DTT, I8 the 24-state
2×2 truncation gap, I9 anchors, I10 TIE median, I11 move-set, I12 score range
all match. The verify-battery §6a citation resolves too. So the failure is
localised: the revision read the verify-battery spec for its I-numbers and did
not read `oracle-v2/spec.md` §4 for its A-numbers.

**Why this is CRITICAL rather than MUST.** R8 makes this table the frozen
baseline — "the A1–A9 harness in §4 plus the reader-side checks that M1's
`design.md` enumerates". M4a's scope (spec `:170`) is literally "A3, A5, A6
fixtures, A9 recipe". Under the spec A3 is colour inversion; under this table A3
is `L ≤ H`. M4a and M4b are dispatched to different agents off this contract, as
M2b and M3 were off BLOCKER-1's. It is the same failure mode, in the same
document, one section later — and this one is invisible to any format check
because it is a numbering collision, not a byte layout.

**Fix.** Rewrite §7.1's `criterion` column against spec §4 verbatim. Add the two
missing rows: **A1 (refusal rate)** — the format bears on it directly, since
`UNCHAINABLE` is what R1's full key exists to eliminate, and §2.3's passes=2
reader contract is what keeps A1 from refusing on game-over states; **A7 (gate
chain)** — format-supported by construction, the same writer path at 2×2/3×2/3×3
producing the published anchors, which is also I9. Keep the existing `L ≤ H` and
UNDEF rows — they are good content — under their true I-numbers in §7.2/§7.3,
where duplicates of both already sit.

### NEW-2 (MUST) — DTT's min/max is assigned by colour, not by beneficiary

§3.1 step 3: Black takes `1 + min`, White takes `1 + max`, unconditionally.

Two consequences, both fatal to the column's purpose:

**(a) DTT is not colour-inversion invariant.** A state and its colour-inverted
image have isomorphic game trees, so their distance-to-terminal must be equal.
Under a fixed colour rule the original evaluates a min and the image evaluates a
max, and the two disagree wherever the VP set has more than one distinct child
depth. This is checkable by hand at 2×2. Nothing in the current A/I inventory
catches it — A3/I2 covers `L`/`H` only — so it would ship.

**(b) White gets no progress measure.** R3's entire rationale is *"a value table
is not a policy — under TIE=0 a winning player can shuffle forever without a
progress measure."* The measure works by having the mover descend it. Black can:
`DTT(s) = 1 + min` means some VP child is strictly lower. White cannot:
`DTT(s) = 1 + max` means *every* VP child is lower-or-equal but White has no
reason to prefer any, and in a cyclic region White's max saturates to FAR (see
NEW-4). So on roughly the half of the state space where White is the winning
side, the column delivers nothing — which is the v1 defect R3 was written to
repair, restricted to one colour.

The standard construction assigns min/max by **who benefits from termination**,
not by colour. With a bracket that is not always well-defined, so the clean
choice here is **mover-minimises**: `DTT(s) = 1 + min` over the mover's
value-preserving moves, whichever colour moves. That is colour-inversion
invariant, gives both sides a descent, and is a least fixpoint computable by
backward BFS from the passes=2 terminals — which also makes step 5's sentinel
condition true as written.

**Fix.** Replace "min for Black, max for White" with "min over the mover's
value-preserving moves" in §3.1 step 3, in the §3.1 invariant list, and in
§7.3's I7 row. If the asymmetric quantity is genuinely wanted, the design must
say what it is for and how White is expected to make progress.

### NEW-3 (MUST) — the value-preservation test compares the wrong bound

§3.1 step 2: a placement child `c` is value-preserving if **Black: `H(c) ≥
L(s)`; White: `L(c) ≤ H(s)`**.

`H(c) ≥ L(s)` says Black's *optimistic* bound in `c` still reaches Black's
*guaranteed* value at `s` — i.e. `L(s)` is still achievable if White cooperates.
That is not preservation. Under the fixpoint's own recurrence
(`exp6_solve.zig:483-531`, Black maximising) `L(s) = max_c L(c)`, so the
children that actually preserve Black's guarantee are exactly `{c : L(c) ≥
L(s)}` — the argmax, always non-empty. The stated test is strictly weaker: it
admits every child whose bracket merely straddles `L(s)`, including children
with `L(c) ≪ L(s)`.

Because step 3 then takes a **minimum** over that set, the loosening is not
conservative — it actively selects the shortest path, which is disproportionately
likely to be one of the value-losing children the test should have excluded. An
M3 policy that plays "the value-preserving move with the lowest DTT" would then
drop `L` while believing it preserved it. The symmetric error applies to White.

**Fix.** Black: `L(c) ≥ L(s)`. White: `H(c) ≤ H(s)`. Both sets are non-empty by
the Bellman fixpoint, which also removes the need for step 4's special case —
see NEW-4's note.

### NEW-4 (MUST) — step 5's FAR condition contradicts step 3's max

§3.1 step 5 defines 255 as *"no value-preserving path reaches a passes=2
terminal."* Step 3 defines White nodes as `1 + max`. Take a White node with two
VP children, one FAR and one at DTT=5. The max is 255, so the node saturates to
FAR — yet a value-preserving path to terminal plainly exists through the second
child. The two clauses cannot both hold.

Under NEW-2's mover-minimises fix this disappears: min propagates finiteness, so
255 means exactly what step 5 says, and the whole column is a single least
fixpoint. If the asymmetric form is kept, step 5 must be restated as the
*computed* result of the recurrence, not as a reachability property.

**Related, and worth fixing in the same edit — 255 is overloaded.** The
recurrence can produce 255 arithmetically (`1 + 254`), which is indistinguishable
from the FAR sentinel. §3.1's invariant list says "non-terminal, non-cycle:
DTT ≤ 254" and §9.2 says I7 "must accept 255 as a valid non-error value for
cycle-affected states" — but a saturated deep *acyclic* state is not
cycle-affected and would read as an I7 failure. Either state that the writer
clamps at 254 and reserves 255 strictly for the cycle sentinel (accepting the
precision loss §9.2 already accepts), or add a second sentinel. One sentence.

**One note on step 4**, which is otherwise sound: with NEW-3's fix the pass move
can simply join the VP set — for Black, pass is value-preserving iff
`L(pass_child) ≥ L(s)`, and since `L(s) = max` over all children including the
pass child, that holds iff passing is exactly Black's best guarantee. The
pass–pass collapse does not return, because a state where Black can improve by
playing has `L(s) > L(pass_child)` and the pass is excluded automatically. Step 4
becomes unnecessary rather than a special case — which is the tell that the
strict test is the right one.

### NEW-5 (MUST) — MUST-2 is reintroduced in the same section it was filed against

§5 opens: *"MB = 10⁶ bytes throughout this document."* §5.3 then reads:

> Entry data (N × 4 ≈ **378 MB** virtual) is mmap'd

99,133,036 × 4 = 396,532,144 bytes = **396.5 MB** decimal. 378 is
396,532,144 / 2²⁰ = 378.2 **MiB**. Three lines above, the same section reports
group headers as "119.0–121.6 MB" — 23,802,969 × 5 = 119,014,845 — which *is*
decimal. So §5.3 still carries both units in one paragraph, which is verbatim
what MUST-2 filed.

The gate no longer turns on it (515.5 MB passes under either unit), so this is
MUST rather than CRITICAL — but the document declares a convention in §5 and
breaks it in §5.3, and MUST-2 exists because a reader who assumes the wrong unit
draws the wrong conclusion.

**Fix.** "≈ 397 MB". Also §5.3's "372 KB" is 380,928 bytes — KiB again; the
decimal figure is 380 KB (94,993 checkpoints × 4 at G = 24.32M).

### NEW-6 (SHOULD) — A6 is unsatisfiable as the spec writes it, for one of its three corruptions; escalate

Not an M1 defect, but M1's §7.1 is where it becomes visible and M1 is the last
gate before M4a builds the fixtures.

Spec A6: *"a deliberately corrupted artifact (one perturbed value, one dropped
ko state, one zeroed DTT column) **fails A1–A5**, and the failure is named."*
The DTT column appears in none of the spec's A1–A5 — A1 is refusal rate, A2
Bellman on `L`/`H`, A3 colour inversion on `L`/`H`, A4 pin census on `L`/`H`, A5
round-trip on keys. **A zeroed DTT column passes all five.** It fails A8, which
A6 does not reference.

Rev 1's §7.1 A6 row happens to route the zeroed-DTT case to I7 — correct in
substance, but it reaches that answer through the renumbering of NEW-1 rather
than from the spec, so the coincidence should not be relied on.

**Fix.** M1 states the mapping it can support and flags the gap; the
Orchestrator carries "A6 should read `fails A1–A5 or A8`" to the spec's next
pass. Do not let M4a build the fixture against the unsatisfiable reading.

### NEW-7 (COULD) — two header fields are both named `reserved`

Offsets 15 and 72 are both `reserved`. D7 exists specifically so *"a Zig `extern
struct` can overlay the mmap'd header directly"* — and a struct cannot have two
fields of the same name. Rename to `reserved0` / `reserved1` (rev 0 already used
`reserved2`, so the intent was there).

### NEW-8 (COULD) — `rules_id` is u16 in the header, u8 in the enumeration it points at

§4 declares `rules_id` as u16 at offset 8. `artifact.zig:76-77` declares
`RULES_CHINESE_PSK: u8` and `RULES_BASICKO_TIE_AREA: u8`, and v1 stores the id
in a single byte (`artifact.zig:191` reads `bytes[9]`). §10's action item says
"add `RULES_BASICKO_LH_AREA: u8 = 3`". Widening in the new format is fine and
probably right — but say so, so M2b and M3 do not each pick a width for the
shared constant.

### NEW-9 (COULD) — three loose ends

1. **§3 still says the i8 range holds "for all gobans through 5×5 (n=25)"**,
   which §2.1's 20-cell ceiling contradicts as a statement about the format.
   True of `i8`, misleading in context — COULD-2's original wording concern.
   Add "…though the u32 colex caps the format at 20 cells (§2.1)".
2. **§4.3's load list omits two checks §7.2 promises**: `ko_bits ==
   ceil(log₂(w·h+1))` and `hdr_flags` bit 0. §7.2 lists both as format-level
   checks "valid on any artifact"; §4.3 steps 1–8 do not include them. Add them
   or say they are verifier-only, not loader.
3. **Appendix A's `terminalRow(colex, side)` takes a `side`** that §2.3 has just
   established is irrelevant to the value. Drop the parameter, or the reader who
   implements it will wonder what it is for — this is the same confusion SHOULD-4
   removed from §2.3.

---

## Brief-mandated checks

| check | result |
|---|---|
| **Byte budget ≤ 600 MB** | **PASS.** 515.5–518.1 MB re-derived independently from `4x4-standard.txt:37,41` and `exp6_solve.zig:1113`; 82–84 MB of headroom, 67 MB under the paranoid census count. No compression, no re-scope, no R9 amendment. |
| **Key encoding uses the full key, passes NOT folded** | **PASS.** `(colex, side, ko, passes)` all reach disk; passes=0 and passes=1 are distinct stored keys. The passes=2 omission is R10's terminal contract, verified against `exp6_solve.zig:454-459`, not a projection. N's justification now cites the solver's own count and correctly states that the census ×2 cannot cross-check it. |
| **Column schema stores L/H separately** | **PASS.** Separate `i8` columns, no pinned `V`, reader-side convention. `flags` byte dropped; `terminal` in key_byte LSB with the `& 0xFE` mask stated; KO_SENSITIVE = `L != H`. DTT is now defined — with the defects at NEW-2/3/4. |
| **Header layout** | **PASS with two cosmetic items.** Offsets close to 128; u64s 8-byte aligned; `ko_bits` u8; `group_header_size` present; `rules_id` allocated and validated; SHA-256 covers the whole file. NEW-7 (duplicate field name) and NEW-8 (width) are the residue. |
| **Naming convention** | **PASS.** Unchanged from rev 0 and still exactly matches spec §4 F9, including the `untracked/` build discipline and hash-then-deploy order. |

**Four of five brief checks now PASS outright**, against one PASS in rev 0. The
F2 gate — the one the sprint was actually blocked on — is cleared.

---

## What I could not establish

1. **Whether the mover-minimises DTT (NEW-2) is computable inside M2b's
   budget.** As a least fixpoint it is a backward BFS from the passes=2
   terminals over ~99M states with a value-preservation filter on each edge —
   the same order of work as one fixpoint sweep, which is affordable. But the
   design specifies no DTT algorithm at all, only a recurrence, and R9's 4-hour
   wall is shared with the solve. M1 need not choose the algorithm; it should
   say whose choice it is. This is the one place the format contract still hands
   M2b an open question.
2. **The true DTT maximum**, and so whether the 254 cap binds. Unchanged from my
   first audit and still open — it cannot be answered before the definition
   settles. §9.2 is honest about this.
3. **Whether G falls in 23.80M–24.32M under M2b's walk.** The lower bound is
   safe (the census's reachable set is a subset of the solver's) and the upper
   is the unconditional legal-position count, so the bracket cannot be violated
   — but the exact value needs M2a. Unchanged, correctly carried in §9.3.

---

## Summary

| Grade | Count | IDs |
|-------|-------|-----|
| **CRITICAL** | 1 | NEW-1 (§7.1's A-series does not match spec §4; MUST-5 unresolved) |
| **MUST** | 4 | NEW-2 (DTT min/max by colour), NEW-3 (wrong bound in the VP test), NEW-4 (FAR condition contradicts the max; 255 overloaded), NEW-5 (MUST-2 reintroduced in §5.3) |
| **SHOULD** | 1 | NEW-6 (A6 unsatisfiable for the zeroed-DTT corruption — Orchestrator escalation) |
| **COULD** | 3 | NEW-7 (duplicate `reserved`), NEW-8 (`rules_id` width), NEW-9 (three loose ends) |

**NEEDS-FIX — one more revision, not a redo.** The remaining work is a rewrite
of §7.1's criterion column against `spec.md:118-126`, four sentences in §3.1,
and one number in §5.3. Sections 1, 2, 4, 5, 6 and 8 are sound and should not be
reopened; §7.2 and §7.3 are correct and need only to keep the rows §7.1 sheds.

**For the Orchestrator.** The rev-0 hold on §5.2's R9 amendment is discharged —
F2 passes and R9 stands unamended, so the M2b start gate is clear on budget
grounds. Two items do not belong to M1: NEW-6 (spec A6's corruption list) and
the NEW-1 collision with M4a's dispatched scope ("A3, A5, A6 fixtures, A9
recipe", spec `:170`) — if M4a has already been briefed, its A-numbers should be
re-read against the spec before it starts, independently of this revision.
