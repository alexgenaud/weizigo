# oracle-v2 M1 — WZO2 format design (rev 3)

```
Task:    T148 (rev 2, DSPro) · rev 3: Fable/Navigator (claude-fable-5) · Date: 2026-07-31
Deliverable: docs/infra/oracle-v2/pass0/design-M1.md
Status:   PROPOSED (rev 3) — all T146 + T150 findings dispositioned; awaiting
          G2 human ratification (diff-scoped review recommended, no fourth audit round)
Target:   docs/infra/oracle-v2/pass0/spec.md (ratified G1)
Audit:    T146 (Opus 5) — NEW-2/3/4/7/8 resolved. T150 (DSPro) — NEW-1, NEW-5,
          NEW-9 resolved in rev 3; RV2-1 no-change-needed (see §11)
```

## 1. Design overview

The WZO2 artifact stores the oracle's value table for the full Markov key
`(goban, side, ko_point, passes)` per spec R1, with `L` and `H` stored
separately (R2), computed DTT (R3), and a self-describing header (R4).

**Format: grouped inline, segregated layout.** Entries are sorted by `(colex_index,
passes, ko_point, side)` and grouped by goban. The file has three contiguous regions:

| region | offset | size | content |
|---|---|---|---|
| Header | 0 | 128 | self-describing metadata (§4) |
| Group index | 128 | `n_groups × 5` | one 5-byte header per group: colex (u32 LE) + entry_count (u8) |
| Entry data | `128 + n_groups × 5` | `n_entries × 4` | packed entry rows (§3) |

The group index and entry data are **segregated** — all G group headers are
contiguous, then all N entries follow. This enables: a single read of the
group index at startup (`n_groups × 5` bytes), a sorted in-memory array, and
binary search on colex. Within a group, entries are scanned linearly
(typically 1–6 entries; max 36 at 4×4 — see §2.4).

The file-size formula validates the layout:

```
file_size = 128 + n_groups × 5 + n_entries × 4
```

### 1.1 File layout diagram

```
┌─────────────────────────────────────────────────┐
│ Header                    128 bytes              │  offset 0
├─────────────────────────────────────────────────┤
│ Group 0 header:  colex(u32 LE)  count(u8)       │  offset 128
│ Group 1 header:  colex(u32 LE)  count(u8)       │  offset 133
│ …                                               │
│ Group G-1 header                                 │  offset 128 + (G-1)×5
├─────────────────────────────────────────────────┤
│ Entry 0:  [key_byte][L][H][DTT]   (4 bytes)     │  offset 128 + G×5
│ Entry 1:  [key_byte][L][H][DTT]                 │
│ …                                               │
│ Entry N-1                                        │  offset 128 + G×5 + (N-1)×4
└─────────────────────────────────────────────────┘
```

**No end-of-data sentinel.** The header carries `n_groups` and `n_entries`;
the reader validates total file size as `128 + n_groups × 5 + n_entries × 4`.

## 2. Key encoding

The full Markov key per R1 is `(goban, side, ko_point, passes)`.

### 2.1 Colex index (goban)

The goban pattern is encoded as its base-3 colex index — a u32 in `[0,
3^(w·h) − 1]`. This is the same colex as the v1 artifact and the engine's
internal addressing. For 4×4: `3^16 = 43,046,721` possible patterns, fitting
in 32 bits.

Colex is stored **little-endian** in the group header, matching the header's
convention. The binary search reads u32 LE values and compares numerically;
no byte-order correction is needed for correctness (the sort key is the
parsed integer, not the raw bytes).

**Format ceiling:** `3^20 = 3.49 × 10^9` fits in u32; `3^21` does not. The
u32 colex caps the format at 20 cells (e.g. 4×5), not 5×5.

### 2.2 Key byte (side, ko_point, passes, terminal)

Packed into one byte per entry. Since passes=2 is never stored (§2.3),
`passes` needs only 1 bit (values 0 or 1). The freed bit carries the
`terminal` flag — whether the side has no legal placements.

Bit layout (MSB→LSB):

```
[passes:1][ko_point:KO_BITS][side:1][terminal:1]
```

| field | bits | values | notes |
|---|---|---|---|
| `terminal` | 1 (LSB) | 0 = has legal placement, 1 = no legal placement | §3 |
| `side` | 1 | 0=Black, 1=White | |
| `ko_point` | ceil(log₂(n+1)) | 0…n-1 = cell, n = none | n = w·h |
| `passes` | 1 (MSB of used bits) | 0, 1 | 2 is terminal — handled by reader, not stored (§2.3) |

Unused high bits (if `1 + 1 + KO_BITS + 1 < 8`) are zero.

KO_BITS per goban:

| goban | n | ko values (n+1) | KO_BITS | key_byte bits used |
|---|---|---|---|---|
| 2×2 | 4 | 5 | 3 | 6 / 8 |
| 3×2 | 6 | 7 | 3 | 6 / 8 |
| 3×3 | 9 | 10 | 4 | 7 / 8 |
| 4×3 | 12 | 13 | 4 | 7 / 8 |
| 4×4 | 16 | 17 | 5 | 8 / 8 |

All target gobans fit in 1 key byte.

### 2.3 Passes=2 terminal contract

Per spec R10: passes=2 states are **not stored in the artifact**. They are
absorbing terminals with no free parameters:

- `L = H = genericAreaScore(goban)` — the absolute, Black-positive area
  score of the final position. This value does **not** depend on the
  side-to-move in the lookup key; the fixpoint seeds both sides' passes=2
  entries identically (`exp6_solve.zig:457-459`). Side enters only as the
  min/max selector during child evaluation (`exp6_solve.zig:485`).
- `DTT = 0`
- `terminal` flag = 1 (by definition: no legal placements from a
  game-over state)

The engine (M3) detects `passes == 2` before consulting the artifact and
returns the terminal value directly. This saves storing ~47.6M redundant
entries (at most `2 × G` — every board reachable at passes=2 is also
reachable at passes∈{0,1} with `ko=none`; see invariant §2.5) and is the
single largest factor keeping the budget within 600 MB.

### 2.4 Sort order

Entries are sorted by `(colex_index, passes, ko_point, side)` — equivalently
`(colex_index, key_byte & 0xFE)` (masking off the `terminal` LSB, which
refines a total order into itself). The `key_byte`'s bit layout (passes in
MSBs of the used bits) ensures that within a group entries sequence as:
passes=0 entries in `(ko, side)` order, then passes=1 entries in `(ko, side)`
order.

**Group entry-count bound:** Per invariant §2.5, every stored passes=1 entry
has `ko = none`. A group therefore holds at most:
`2 sides × (n+1) ko_values` at passes=0 plus `2 sides × 1 ko_value` at
passes=1 = `2 × (n+2)` entries. At 4×4: `2 × 18 = 36`. This fits in `u8`
with room. The writer (M2b) must assert `entry_count ≤ 2 × (w·h + 2)` per
goban rather than truncating silently.

### 2.5 Invariant: passes ≥ 1 ⇒ ko = none

The pass move resets the ko point to `KO_NONE`
(`exp6_solve.zig:964`: `encodeState4(board_idx, 1 - side, KO_NONE4, passes +
1)`). Every state with passes ≥ 1 is reached by a pass, so **every stored
entry with passes=1 has `ko = none`**. (Passes=2 is not stored, but the same
holds for the omitted set.)

This is a format-level invariant usable by the verifier (§7.1).

## 3. Column schema

Per spec R2 (separate L/H) and R3 (computed DTT).

| column | type | size | range | description |
|---|---|---|---|---|
| `key_byte` | u8 | 1 B | — | side + ko_point + passes + terminal (see §2.2) |
| `L` | i8 | 1 B | [−n, +n] | lower bound (Black-positive convention) |
| `H` | i8 | 1 B | [−n, +n] | upper bound (Black-positive convention) |
| `DTT` | u8 | 1 B | 0–254 = steps, 255 = FAR | depth-to-terminal (see §3.1) |

**Total per entry: 4 bytes** (1 key + 3 value columns).

The `L`/`H` range of `[−n, +n]` for an n-cell goban fits in `i8` for all
gobans through 5×5 (n=25) — though the u32 colex caps the format itself at
20 cells (§2.1). For 4×4, range is [−16, +16] = 33 values.

**KO_SENSITIVE is not stored as a flag.** It is computed by the reader as
`L != H`. Storing it redundantly would cost `N` bytes (~99 MB at 4×4) for a
condition already derivable from the two preceding bytes. The pin census
and move ordering compute it from L/H; caching is an M3 concern.

**`terminal` is stored as bit 0 (LSB) of `key_byte`** (§2.2). Lookup masks
it off before comparing keys: `entry[0] & 0xFE == target_kb`. It means
"this side has no legal placement from this state." A passes=0 or passes=1
state with `terminal` set must pass — the game continues. It is distinct
from the passes=2 absorbing terminal (which is not stored).

### 3.1 DTT definition and encoding

DTT (depth-to-terminal) measures the number of plies to reach a passes=2
absorbing terminal, restricted to value-preserving play. It exists so that
a winning player cannot shuffle forever while preserving the value (spec
R3).

**Definition.** For a state `s = (goban, side, ko, passes)`:

1. **Base case:** If `passes == 2`, DTT = 0 (absorbing terminal).

2. **Value-preserving placements:** Let `P` be the set of legal non-pass
   moves (placements) from `s`. A placement child `c` is *value-preserving*
   if the moving side can still achieve its current bound in `c`:
   - Black (maximizer): `L(c) ≥ L(s)`
   - White (minimizer): `H(c) ≤ H(s)`

3. **Recurrence — placements exist:** If the set `VP` of value-preserving
   placements is non-empty:
   `DTT(s) = 1 + min_{c ∈ VP} DTT(c)`

4. **Recurrence — no legal placement:** If the side has no legal placement
   (`terminal` = 1): pass is the only move and is value-preserving by
   construction, so `DTT(s) = 1 + DTT(pass_child(s))`. For states with
   legal placements, `VP` is always non-empty under step 2's strict test
   (the argmax/argmin placements of the fixpoint satisfy the bound).

5. **Cycle sentinel:** If no value-preserving path reaches a passes=2
   terminal (the state is in a cycle-affected region), DTT = 255 (FAR).
   The writer clamps computed DTT at 254, reserving 255 strictly as the
   cycle sentinel; the recurrence cannot produce 255 arithmetically
   (`1 + 254 = 255` is clamped to 254 rather than colliding with FAR).

**Encoding:**

| value | meaning |
|---|---|
| 0 | absorbing terminal (passes=2; not stored in artifact) |
| 1–254 | plies to nearest terminal under value-preserving optimal play |
| 255 | FAR — no value-preserving path to terminal known (sentinel) |

**Key consequence:** A passes∈{0,1} state with no legal placements
(`terminal` = 1) has VP = ∅ by construction, so DTT ≥ 1 (it must pass at
least once). It is **not** assigned DTT=0 — DTT=0 is reserved for
passes=2 absorbing terminals only.

**Invariants (for I7 / A8):**
- Terminal (passes=2): DTT = 0 by definition.
- Non-terminal, non-cycle: DTT > 0 and DTT ≤ 254.
- For any non-terminal non-FAR state, `DTT(s) = 1 + min_{c ∈ VP(s)} DTT(c)`.
- States in cycle-affected regions where no value-preserving path to
  terminal exists: DTT = 255.

**DTT maximum:** Empirical 3×3 data suggests DTT stays well under 254 for
cycle-free states. The writer clamps computed DTT at 254 and reserves 255
strictly for the cycle sentinel (§3.1 step 5). The only loss is DTT
precision on very deep states, not correctness.

**Algorithm ownership.** This section specifies the recurrence, not the
computation. The algorithm that evaluates it — e.g. backward breadth-first
search from the passes=2 terminals with the value-preservation filter
applied per edge — is **M2b's choice**, within R9's shared 4-hour wall
budget. The format contract constrains only the stored result.

## 4. Header layout

128 bytes, fixed size. All multi-byte integers are **little-endian**. u64
fields are placed at 8-byte-aligned offsets so a Zig `extern struct` can
overlay the header directly.

| offset | size | field | type | description |
|---|---|---|---|---|
| 0 | 4 | `magic` | u8[4] | `'W' 'Z' 'O' '2'` = `0x57 0x5A 0x4F 0x32` |
| 4 | 2 | `version` | u16 | format version = 1 |
| 6 | 1 | `w` | u8 | goban width |
| 7 | 1 | `h` | u8 | goban height |
| 8 | 2 | `rules_id` | u16 | ruleset identifier = 3 (§4.1) |
| 10 | 2 | `entry_size` | u16 | bytes per entry = 4 |
| 12 | 1 | `group_header_size` | u8 | bytes per group header = 5 |
| 13 | 1 | `ko_bits` | u8 | ceil(log₂(w·h+1)) bits used for ko in key_byte |
| 14 | 1 | `hdr_flags` | u8 | bit 0 = `PASSES_2_OMITTED` (passes=2 not stored; §2.3) |
| 15 | 1 | `reserved0` | u8 | zero |
| 16 | 8 | `n_groups` | u64 | number of goban groups |
| 24 | 8 | `n_entries` | u64 | total entries (passes∈{0,1}) |
| 32 | 8 | `data_offset` | u64 | byte offset to first group = 128 |
| 40 | 32 | `sha256` | u8[32] | SHA-256 of file with this field zeroed (§4.2) |
| 72 | 56 | `reserved1` | u8[56] | zero; available for future header extensions |

### 4.1 Rules identifier

`rules_id` = 3: "Chinese area, komi 0, basic ko, convention-free L/H
bracket." This distinguishes the v2 artifact from v1:

| id | name | artifact format |
|---|---|---|
| 1 | Chinese area, komi 0, positional superko | v1 (`.wzo`) |
| 2 | Chinese area, komi 0, basic ko, TIE=0 on cycles | v1 (`.wzo`) |
| 3 | Chinese area, komi 0, basic ko, L/H bracket | v2 (`.wzo2`) |

The `rules_id` belongs to `src/artifact.zig`'s enumeration (`:76-77`), not
`src/rules.zig`. M3 must add the arm for id 3 to `artifact.zig`'s
`rulesName` switch (`:82-88`) and the load validation in `:191`. The
existing v1 loader rejects unknown ids — id 3 will be caught until M3
updates it. The header stores `rules_id` as u16; the writer fills the low
byte from `artifact.zig`'s `u8` constant and zeroes the high byte. The
reader validates only the low byte.

### 4.2 SHA-256 integrity

The `sha256` field at offset 40 holds the SHA-256 of **the entire file**
with bytes 40–71 (the hash slot itself) treated as zero. This covers the
header and all ~600 MB of payload.

The hash is computed by M2b after the file is fully written:
1. Write all data with `sha256` slot zeroed.
2. Compute SHA-256 of the complete file.
3. Write the digest into bytes 40–71 in-place.

This is distinct from R7's recorded hash — R7's is of the *finished file
including* the embedded slot. The two digests differ; both are reproducible.

**Load-time verification** (§4.3 step 10): full-file SHA-256 verification is
a command-line option (`--verify-hash`), not mandatory on every load
(computing a hash over 600 MB defeats the mmap-lazy design for interactive
use). It is mandatory in M4a's A6 fixture path and in the verify-battery.

### 4.3 Validation on load

1. `magic` == `"WZO2"` — wrong magic → fatal, "not a WZO2 artifact"
2. `version` == 1 — wrong version → fatal, "unsupported version N"
3. `w` and `h` match the engine's goban size — mismatch → fatal
4. `entry_size` == 4 — mismatch → fatal, "corrupt or unsupported entry size"
5. `group_header_size` == 5 — mismatch → fatal
6. `ko_bits` == ceil(log₂(w·h+1)) — mismatch → fatal, "ko_bits does not
   match goban size" (prevents misinterpreting the key_byte layout)
7. `hdr_flags` bit 0 (`PASSES_2_OMITTED`) == 1 — mismatch → fatal (this
   format version always omits passes=2 by contract, §2.3)
8. File size == `data_offset + n_groups × 5 + n_entries × entry_size`
9. `rules_id` == 3 — mismatch → fatal or warn per spec §3.1
   (`RULES-MISMATCH-FATAL`). The reader compares against its own compiled
   rules_id; a v1 engine loading a v2 artifact must refuse.
10. `--verify-hash`: SHA-256 of file with hash slot zeroed matches `sha256`
    — mismatch → fatal, "checksum failure"

## 5. F2 byte budget

**MB = 10⁶ bytes throughout this document.** The spec's convention follows
v1: "258 MB" = 258,280,358 bytes. The R9 ceiling is 600,000,000 bytes.

### 5.1 Derivation from measured counts

The file size is:

```
size = 128 + G × 5 + N × 4   bytes
```

where:
- `G` = number of distinct gobans (colex indices) with at least one
  reachable (side, ko, passes∈{0,1}) state
- `N` = total reachable (goban, side, ko, passes∈{0,1}) states

**N = 99,133,036** — direct count from the solver:
`exp6_solve.zig:1113` (`# 4x4 compact states (passes ∈ {0,1})`). This is
the operating value. The EXP-3 census figure (102,838,092) is an arithmetic
double of its triples count (51,419,046 × 2) and cannot cross-check the
solver's count (SHOULD-6 in audit); the solver's own walk is the only
authority until M2b runs.

**G — two bounds, both measured:**

| bound | value | source |
|---|---|---|
| **lower** | 23,802,969 | `docs/evidence/GLOBAL.H1-CENSUS/4x4-standard.txt:41` — `ko_point = none` addresses |
| **upper** | 24,318,165 | `4x4-standard.txt:37` — legal positions |

The lower bound holds because each `ko=none` address is a distinct board
reachable at passes=0, hence a stored group. The upper bound holds because
every group's colex must be a legal position. A confirming figure —
23,813,121 distinct boards under the ko-disabled walk
(`4x4-ko-disabled.txt:40`) — sits inside the bracket.

**G = 23.80M–24.32M** — a 2.2% bracket worth 2.6 MB of file.

### 5.2 Budget

| G | N | size (bytes) | size (MB) | vs 600 MB |
|---|---|---|---|---|
| 23,802,969 | 99,133,036 | 515,547,117 | 515.5 | **−14.1%** |
| 24,318,165 | 99,133,036 | 518,123,097 | 518.1 | **−13.6%** |
| 24,318,165 | 102,838,092 (census ×2) | 532,943,321 | 532.9 | −11.2% |

**The artifact is under the 600 MB ceiling under every value of G and N
considered**, including the paranoid census count. The 4-byte entry schema
(§3) clears the ceiling by 82–84 MB with zero compression, zero re-scope,
and no loss of information.

### 5.3 Memory budget at load time

The engine (M3) loads group headers into memory for binary search:

```
load_RAM = G × 5 bytes   (group headers, kept in memory)
```

Group headers: 23.80–24.32M × 5 = 119.0–121.6 MB.

The engine also needs cumulative entry offsets for the linear scan within
groups (Appendix A). Rather than storing a full `G × 4` byte offset array
(~95–97 MB), the engine stores a sparse prefix sum: the cumulative entry
index every 256th group (`G/256 × 4 ≈ 380 KB`). At lookup time it sums at
most 255 count bytes from the nearest checkpoint — all from the group index
already in cache. Total load-time allocation: **~120 MB**.

Entry data (N × 4 ≈ 397 MB virtual) is mmap'd; only faulted pages consume
RSS. The engine's working set is well within the host's 4 GB RSS cap.

## 6. Artifact naming convention

Per spec §4 F9:

```
data/oracle-{goban}-v2.wzo2
```

| goban | artifact path |
|---|---|
| 2×2 | `data/oracle-2x2-v2.wzo2` |
| 3×2 | `data/oracle-3x2-v2.wzo2` |
| 3×3 | `data/oracle-3x3-v2.wzo2` |
| 4×3 | `data/oracle-4x3-v2.wzo2` |
| 4×4 | `data/oracle-4x4-v2.wzo2` |

During the sprint, builds write to `untracked/oracle-v2/oracle-{goban}-v2.wzo2`
only. The single run that populates `data/` occurs after G3 ratification. The
recorded SHA-256 is of the `untracked/` build; the `data/` copy is verified
against that hash before deployment.

The `.wzo2` extension distinguishes the v2 format from v1 `.wzo` artifacts.
Both formats may coexist in `data/`.

## 7. R8 baseline inventory — acceptance criteria coverage

Per spec R8 (format must support reader/verifier checks) and the
verify-battery spec §6a. This section maps every acceptance criterion
(A1–A9) and invariant check (I-series) to the format's support.

### 7.1 Acceptance criteria (A1–A9)

**A-numbers below follow spec §4 verbatim** (`docs/infra/oracle-v2/pass0/spec.md` §4, A-table);
I-numbers follow the verify-battery inventory. The `L ≤ H` and UNDEF-census
checks formerly listed here as A-criteria are I-checks (I3, I6) and live in
§7.2/§7.3 where they always appeared.

| criterion | format support | notes |
|---|---|---|
| **A1 (refusal rate)** | **Format-supported — this is what the format exists for.** The full key (§2) gives every reachable `(goban, side, ko, passes)` state a stored entry, removing the v1 `UNCHAINABLE` substitutions. §2.3's reader contract answers passes=2 game-over states without a lookup, so terminal states cannot refuse. The ≥ 100-query pinned-seed sample is M4b harness work, not a format concern. | headline criterion |
| **A2 (Bellman residual after decode round-trip)** | **Format-supported.** Keys are explicit. Battery reconstructs state, generates children via its own move engine (R8), checks `L = Φ(L)`, `H = Φ(H)` on *decoded* values. | soundness gate |
| **A3 (colour inversion, exhaustive)** | **Format-supported.** For every stored entry `(colex, s, ko, p)` the inverted key is `(colour_flip(colex), 1-s, ko, p)`. Check `L(pos, side) == -H(inverted)` and `H(pos, side) == -L(inverted)`. Requires battery to compute colour-flip of colex. | = I2 |
| **A4 (pin census)** | **Format-supported.** `L == H` vs `L < H` computed from stored L/H columns; `pin_T`, `pin_L`, `pin_H` counted, `pin_L == pin_H` checked. KO_SENSITIVE recomputed per lookup, not stored. | = I1 |
| **A5 (round-trip identity)** | **Format-supported.** `decode(encode(key)) == key` for all entries. Key encoding is lossless by construction (colex + key_byte), but the check verifies writer/reader agreement on bit packing. | |
| **A6 (known-bad calibration)** | **Partially format-supported.** Three named corruptions: (a) *one perturbed value* → caught by SHA-256 (full-file, `--verify-hash`) or I4 (Bellman); (b) *one dropped ko state* → caught by I6 (UNDEF census) since `n_entries` would be wrong; (c) *one zeroed DTT column* → caught by I7/A8. SHA-256 is the only check that names all three at format level; the other two need the battery. **Spec-text gap (T146 NEW-6, escalated):** the zeroed-DTT corruption passes the spec's "fails A1–A5" as literally written and fails only A8; proposed amendment "fails A1–A5 or A8" is pending G2. | |
| **A7 (gate chain reproduced)** | **Format-supported by construction.** The same writer and decoder serve 2×2, 3×2, 3×3, and 4×4; the published anchors (2×2 = 0, 3×2 = 0, 3×3 = +9) are read back through this format and checked as I9 anchor values. A pipeline that cannot reproduce them is not trusted at 4×4. | = I9 at small gobans |
| **A8 (DTT is non-constant)** | **Format-supported.** DTT column is stored; check that non-terminal non-FAR entries span > 1 distinct value. The DTT recurrence (mover-minimises: `1 + min` over the mover's value-preserving children) ensures the column carries real information, not the pass-pass collapse described in BLOCKER-2, and is colour-inversion invariant. | |
| **A9 (reproducibility)** | **Format-supported by construction.** Determinism contract: (a) all reserved bytes zeroed (§4); (b) canonical sort order: groups strictly increasing colex, entries per §2.4; (c) no timestamps or build metadata; (d) SHA-256 slot zeroed before hash, then written in place (§4.2). A byte-identical rebuild is possible from the same solver inputs. | |

### 7.2 Format-level checks (valid on any artifact, no fixpoint needed)

| check | how the format supports it |
|---|---|
| **Magic + version** | Fixed-offset magic `WZO2` at byte 0; version at byte 4. Checked on every load. |
| **Goban size match** | `w` and `h` at bytes 6–7. Checked on load; mismatch → fatal. |
| **SHA-256 integrity** | 32-byte slot at offset 40. Covers entire file with slot zeroed (§4.2). Verified on `--verify-hash`. |
| **File size consistency** | `size == data_offset + n_groups × 5 + n_entries × entry_size`. |
| **Entry size invariant** | `entry_size == 4`. Guards against future format changes. |
| **Group header size invariant** | `group_header_size == 5`. |
| **Ko bits match goban size** | `ko_bits == ceil(log₂(w·h+1))`. Prevents misinterpretation of key_byte. |
| **Group order** | Groups must appear in strictly increasing colex order. A single backward step invalidates binary search. |
| **Colour inversion (I2)** | Keys are explicit; battery computes colour-flip of colex and checks `L(pos, side) == -H(inverted)`. |
| **L ≤ H (I3)** | Stored per entry; check on every row. |
| **Score range (I12)** | `L, H ∈ [−n, +n]` where `n = w·h`. Exhaustive scan. |
| **Round-trip identity (A5)** | `decode(encode(key)) == key` for all entries; verifies bit-packing agreement. |
| **Passes-ko invariant** | No stored entry has `passes=1` and `ko ≠ none` (§2.5). One mask per row. |
| **Entry count bound** | No group's `entry_count` exceeds `2 × (w·h + 2)` (§2.4). |
| **Key byte unused bits** | Unused MSBs in key_byte must be zero. |
| **Passes=2 omission flag** | `hdr_flags` bit 0 = 1 confirms passes=2 is omitted by contract (§2.3, COULD-5). |

### 7.3 State-level checks (require fixpoint or move relation)

| check | how the format supports it |
|---|---|
| **Bellman residual (I4)** | Keys are explicit. Battery reconstructs state, generates children via its own move engine (R8). |
| **Pin census (I1)** | Computed from stored L/H; `pin_T` = count where `L == H`. |
| **DTT sanity (I7)** | DTT column stored. Absorbing terminals (passes=2) have DTT=0. Non-terminals without KO_SENSITIVE must have 0 < DTT ≤ 254 and DTT(s) = 1 + min_{c ∈ VP(s)} DTT(c). |
| **KO_SENSITIVE ⊆ cycle-reachable (I5)** | Computed as `L != H`. Battery computes SCCs on its own move graph and verifies containment. |
| **UNDEF census (I6)** | Every legal position has a determinable lookup; battery checks coverage. |
| **Anchor values (I9)** | Specific keys' L/H values must match committed anchors. Keys are explicit. |
| **Terminal flag consistency** | `terminal` bit in key_byte must match "no legal placement for this side." Battery computes move set independently. |
| **Truncation-gap regression (I8)** | 2×2 only; the 24 formerly-mismatched states must be pinned and checked. |

### 7.4 Checks the format does NOT support alone

| check | what's needed beyond the format |
|---|---|
| **Move-set consistency (I11)** | M2b must emit a sidecar dump of the legal-move set used during the fixpoint, for the battery's independent move engine to compare against. Not a format requirement — an M2b deliverable. |
| **TIE median (I10)** | Artifact stores L and H, not TIE. TIE is computed by the reader as `median(L, convention, H)`. Battery checks `TIE ∈ [L, H]`. |

## 8. Design decisions and rationale

**D1: Grouped inline, segregated layout.** A separate group index (8 bytes
per group: 4 colex + 4 offset) would cost ~200 MB at G=24M. The segregated
inline layout — all group headers contiguous, then all entries — saves
~3 bytes/group and enables a single read of all group headers at startup
(~120 MB). Binary search on the in-memory array, then linear scan within
the group.

**D2: Passes=2 terminal computation in the reader, not stored.** R10 defines
passes=2 states as absorbing terminals with no free parameters. Storing them
would add at most `2 × G` (~47.6M) redundant entries (~190 MB). The reader
(M3) handles passes=2 by computing area score on the fly. This does not
affect the solver (which already seeds passes=2 but excludes it from the
compact working array).

**D3: i8 for L and H, not a packed narrower type.** L and H for 4×4 need 6
bits each (33 values, [−16, +16]). Packing them into 12 bits would save 4
bits per entry (~50 MB) but would break byte-alignment for DTT and require
bit-shift operations on every lookup. The 4-byte layout is already 82 MB
under the 600 MB ceiling — packing is unnecessary complexity.

**D4: Little-endian throughout.** All multi-byte fields (colex in group
headers, u16/u64 in the file header) use LE, matching Zig's native byte
order. Binary search reads u32 LE and compares numerically; correctness
does not depend on on-disk byte order, only on the writer writing colex in
strictly increasing order — which it does, since it iterates colex in order.

**D5: No `KO_SENSITIVE` flag.** `L != H` is a single byte comparison per
lookup. Storing it as a flag costs `N` bytes (99 MB at 4×4) for a
computation the reader already performs. The pin census and move ordering
derive it from L/H.

**D6: No compression.** The format is uncompressed so that (a) the SHA-256
covers the exact bytes the reader reads, (b) the reader can mmap and seek
without a decompression step, and (c) the reproducibility command (R7) is a
single `zig build` invocation, not a pipeline with an external compressor.

**D7: Aligned header for struct overlay.** u64 fields are placed at 8-byte
offsets (16, 24, 32) so a Zig `extern struct` can overlay the mmap'd header
directly. The builder and reader may use accessors as well; the alignment
means both approaches produce the same result.

## 9. What I could not establish

1. **Whether M2b's entry count will match 99,133,036.** The solver's own
   compact-state walk (`exp6_solve.zig:1113`) is the only authority. The
   EXP-3 census's "with passes" figure is an arithmetic double (51,419,046
   × 2) and does not bound the solver's count in either direction (audit
   SHOULD-6). The budget's sensitivity is low — ±1M entries is ±4 MB — and
   the 82 MB of headroom absorbs it.

2. **DTT maximum value.** It is possible that 1 byte is insufficient if the
   longest value-preserving path to terminal exceeds 254 plies. Empirical
   3×3 data suggests DTT stays well under 100. The writer clamps computed
   DTT at 254 (§3.1 step 5); the only loss is DTT precision on very deep
   states, not correctness. The verifier's I7 check must accept 255 as a
   valid non-error value for cycle-affected states.

3. **The exact distinct goban count G under M2b's walk.** The census lower
   bound (23,802,969) is safe — the census's reachable set is a subset of
   the solver's. The upper bound (24,318,165) is the unconditional
   legal-position count. M2a's reachability builder will produce the exact
   count; until then the bracket is 23.80M–24.32M, worth ±2.6 MB of file.

## 10. What to check next

1. **G2 human ratification** — the revised design must pass the F2 gate
   (derived budget < 600 MB) and all five brief-mandated checks.
2. **M2b start gate** — the F2 budget question is resolved (515.5–518.1 MB,
   no re-scope needed). M2b may dispatch.
3. **M3 header struct alignment** — verify the `extern struct` overlay
   matches this document's header layout byte-for-byte.
4. **artifact.zig** — add `RULES_BASICKO_LH_AREA: u8 = 3` and the
   corresponding `rulesName` arm and load-validation acceptance. The
   header `rules_id` is u16 (low byte = the `u8` constant, high byte = 0);
   M2b and M3 must agree on this width.

## 11. Audit resolution log

### O-4 audit (2026-07-31)

| finding | disposition |
|---|---|
| BLOCKER-1 (layout two ways) | **Fixed.** §1.1 diagram redrawn as segregated; three regions with byte extents stated in §1 table. |
| BLOCKER-2 (DTT undefined) | **Fixed — see T146 re-audit below.** DTT recurrence stated in §3.1: base case, value-preserving constraint, adversarial min/max, cycle sentinel. DTT=0 reserved for absorbing terminals. Defects in the replacement definition addressed in rev 2. |
| CRITICAL-1 (SHA-256 covers 40 B) | **Fixed.** §4.2: hash covers entire file with slot zeroed. `--verify-hash` load-time option; mandatory in A6/M4a path. |
| CRITICAL-2 (re-scope over 1-byte fix) | **Fixed.** 4-byte entries adopted (§3). `flags` byte dropped; `terminal` in key_byte LSB; `KO_SENSITIVE` = `L != H`. Budget: 515.5–518.1 MB, under ceiling by 82 MB. |
| MUST-1 (G and N unmeasured) | **Fixed.** §5.1 replaced with measured bracket from census evidence files. §9.1 deleted. |
| MUST-2 (MB vs MiB) | **Fixed.** §5 header states "MB = 10⁶ bytes"; §5.3 figures corrected. |
| MUST-3 (rules_id) | **Fixed.** §4.1: id = 3 allocated, source file corrected to `artifact.zig`, validation step added (§4.3 step 7). |
| MUST-4 (header inconsistency) | **Fixed.** `ko_bits` type corrected to u8/size=1. u64 fields moved to 8-byte-aligned offsets (16, 24, 32). `group_header_size` added at offset 12. |
| MUST-5 (R8 omits A1–A9) | **Fixed.** §7 restructured: §7.1 maps A1–A9 explicitly, §7.2 covers format-level checks, §7.3 state-level. |
| SHOULD-1 (load-RAM contradiction) | **Fixed.** §5.3 uses sparse prefix sum (every 256th group, ~380 KB) instead of full offset array. Appendix A updated. |
| SHOULD-2 (BE colex buys nothing) | **Fixed.** D4: LE adopted throughout (§2.1, §8). |
| SHOULD-3 (ordering prose) | **Fixed.** §2.4 rewritten for multi-ko groups. |
| SHOULD-4 (side-dependent area score) | **Fixed.** §2.3: side-dependence removed; provenance cited (`exp6_solve.zig:457-459,485`). |
| SHOULD-5 (passes≥1 ⇒ ko=none) | **Fixed.** §2.5 added as invariant; used in group bound (§2.4), format checks (§7.2), and D2 sizing. |
| SHOULD-6 (N justification) | **Fixed.** §5.1 cites `exp6_solve.zig:1113` directly; notes census ×2 is arithmetic, not a bound. |
| COULD-1 (entry-count bound) | **Fixed.** §2.4: max = `2 × (w·h + 2)`; writer assert stated. |
| COULD-2 (u32 colex cap) | **Fixed.** §2.1: "format ceiling: 20 cells." |
| COULD-3 (interval typo) | **Fixed.** §2.1: `[0, 3^(w·h) − 1]`. |
| COULD-4 (group header size) | **Fixed.** `group_header_size = 5` in header at offset 12; validation step 5. |
| COULD-5 (passes=2 omission flag) | **Fixed.** `hdr_flags` bit 0 = `PASSES_2_OMITTED` at header offset 14. |

### T146 re-audit (2026-07-31)

| finding | disposition |
|---|---|
| NEW-2 (DTT min/max by colour) | **Fixed.** §3.1 step 3: mover-minimises (`1 + min` regardless of colour). Invariant list, §7.1 A8, and §7.3 I7 updated. Colour-inversion invariant. |
| NEW-3 (VP test wrong bound) | **Fixed.** §3.1 step 2: Black `L(c) ≥ L(s)`, White `H(c) ≤ H(s)`. Sets are non-empty by the Bellman fixpoint; step 4's pass-fallback triggers only for `terminal`=1 states. |
| NEW-4 (FAR contradiction; 255 overload) | **Fixed.** Mover-minimises (NEW-2) resolves the max/FAR contradiction. Writer clamps at 254, reserving 255 strictly for the cycle sentinel (§3.1 step 5, DTT maximum paragraph). |
| NEW-7 (duplicate `reserved` field name) | **Fixed.** `reserved0` at offset 15, `reserved1` at offset 72. |
| NEW-8 (`rules_id` u16 vs u8) | **Fixed.** §4.1 and §10 note header stores u16, low byte from `artifact.zig`'s `u8` constant, high byte zero. |

### T150 re-audit (2026-07-31) — resolved in rev 3

| finding | disposition |
|---|---|
| NEW-1, CRITICAL (§7.1 A-series ≠ spec §4; carried from T146) | **Fixed.** §7.1 criterion column rewritten against spec §4 verbatim: A1 = refusal rate (headline), A2 = post-round-trip Bellman, A3 = colour inversion, A4 = pin census, A7 = gate chain. The former `L ≤ H` and UNDEF-census rows were I-checks (I3, I6) and remain in §7.2/§7.3 under their true numbers. §7.1 now states its numbering source. |
| NEW-5, MUST (MiB figures in §5.3; carried from T146) | **Fixed.** §5.3: "378 MB" → "397 MB" (396,532,144 bytes); "372 KB" → "380 KB" in §5.3 and Appendix A. |
| RV2-1, MUST (§2.3 omits DTT=0) | **No change needed — finding is not reproducible.** §2.3's bullet list already contains "`DTT = 0`" (present in rev 2 as audited, between the area-score and terminal-flag bullets). |
| NEW-6, SHOULD (spec A6 unsatisfiable for zeroed-DTT; carried) | **Escalated, not an M1 edit.** Amendment "fails A1–A5 **or A8**" applied to the live spec tagged *pending G2 ratification*; §7.1's A6 row records the gap. |
| NEW-9.1, COULD (i8 "through 5×5" vs 20-cell format ceiling) | **Fixed.** §3 cross-references the §2.1 ceiling. |
| NEW-9.2, COULD (§4.3 omits ko_bits and hdr_flags checks) | **Fixed.** §4.3 steps 6–7 added; list renumbered to 10 steps; §4.2's step reference corrected. |
| NEW-9.3, COULD (`terminalRow(colex, side)` takes irrelevant side) | **Fixed.** Appendix A: `terminalRow(colex)`; side-independence noted per §2.3. |
| — (T146 "could not establish" #1: whose choice is the DTT algorithm) | **Fixed.** §3.1 "Algorithm ownership": the recurrence is the contract; the algorithm is M2b's, within R9. |
| — (editorial) | Stale `§3.2` reference in §2.2's table corrected to `§3` (rev 2 merged old §3.2 into §3). |

## A. Example lookup pseudocode

```zig
fn lookup(artifact: []const u8, colex: u32, side: Side, ko: u8, passes: u2) ?Row {
    // Terminal shortcut — passes=2 is not stored (§2.3)
    if (passes == 2) {
        // Area score is side-independent (§2.3); DTT=0, terminal=1
        return terminalRow(colex);
    }

    const header = parseHeader(artifact[0..128]);

    // Binary search groups on colex_index (little-endian)
    const group_base: usize = header.data_offset;
    const groups = artifact[group_base .. group_base + header.n_groups * 5];
    var lo: usize = 0;
    var hi: usize = header.n_groups;
    while (lo < hi) {
        const mid = lo + (hi - lo) / 2;
        const mid_colex = std.mem.readInt(u32, groups[mid * 5 ..][0..4], .little);
        if (mid_colex < colex) lo = mid + 1
        else if (mid_colex > colex) hi = mid
        else { lo = mid; break; }
    }
    if (lo >= header.n_groups) return null;
    const grp_colex = std.mem.readInt(u32, groups[lo * 5 ..][0..4], .little);
    if (grp_colex != colex) return null;

    const count: u8 = groups[lo * 5 + 4];

    // Build target key_byte (terminal bit = 0 for lookup; masked off during scan)
    const target_kb = encodeKeyByte(side, ko, passes, header.ko_bits);

    // Sparse prefix sum: cumulative entry index at every 256th group
    const checkpoint_idx = lo >> 8;
    const entry_offset = entry_checkpoints[checkpoint_idx];
    var offset: usize = entry_offset;
    for (checkpoint_idx * 256 .. lo) |g| {
        offset += group_counts[g];
    }

    // Entry data begins after all G group headers
    const entry_base = group_base + header.n_groups * 5;

    // Linear scan within group
    for (0..count) |i| {
        const entry = artifact[entry_base + (offset + i) * 4 ..][0..4];
        // Mask off terminal LSB before comparing keys
        if (entry[0] & 0xFE == target_kb) {
            return Row{
                .L = @bitCast(entry[1]),
                .H = @bitCast(entry[2]),
                .DTT = entry[3],
                .terminal = (entry[0] & 1) != 0,
                .ko_sensitive = (entry[1] != entry[2]),
            };
        }
    }
    return null; // state not in artifact (unreachable under artifact's rules_id)
}
```

The sparse prefix-sum array `entry_checkpoints` and the per-group count
array `group_counts` are built at load time in one pass over the group
index (O(G)). The checkpoint array is `G/256 × 4 ≈ 380 KB` at 4×4;
the count array is `G × 1 ≈ 24 MB` (the group index, already in memory).
Total additional allocation beyond the group index: **< 1 MB**.
