# oracle-v2 M1 — WZO2 format design

```
Task:    O-3 · Role: worker · Model: not stated at dispatch · Date: 2026-07-31
Deliverable: docs/design/oracle-v2/pass1/design-M1.md
Status:   PROPOSED — awaiting audit (O-4), then G2 human ratification
Target:   docs/infra/oracle-v2/spec.md (pass 1, ratified G1)
```

## 1. Design overview

The WZO2 artifact stores the oracle's value table for the full Markov key
`(goban, side, ko_point, passes)` per spec R1, with `L` and `H` stored
separately (R2), computed DTT (R3), and a self-describing header (R4).

**Format: grouped inline.** Entries are sorted by `(colex_index, side,
ko_point, passes)` and grouped by goban. Each group carries the colex once,
then a sequence of fixed-width entries. A group index is **not** stored on
disk — the engine loads all 5-byte group headers into memory at startup
(~120 MB for 24M groups), builds a sorted array, and binary-searches on
colex. Within a group, entries are scanned linearly (typically 1–6 entries).

### 1.1 File layout

```
┌────────────────────────────────────────────────┐
│ Header                   128 bytes             │
├────────────────────────────────────────────────┤
│ Group 0:                                       │
│   colex_index            u32 (4 bytes)          │
│   entry_count            u8  (1 byte)           │
│   entry 0: key_byte L H DTT flags  (5 bytes)   │
│   entry 1: …                                   │
│   …                                            │
├────────────────────────────────────────────────┤
│ Group 1:   colex_index, count, entries…        │
│ …                                              │
├────────────────────────────────────────────────┤
│ Group G-1: last group                          │
└────────────────────────────────────────────────┘
```

**No end-of-data sentinel.** The header carries `n_groups` and `n_entries`;
the reader can seek all group headers in one read (`n_groups × 5` bytes) and
validate total file size as `128 + n_groups × 5 + n_entries × 5`.

## 2. Key encoding

The full Markov key per R1 is `(goban, side, ko_point, passes)`.

### 2.1 Colex index (goban)

The goban pattern is encoded as its base-3 colex index — a u32 in `[0,
3^(w·h) − 1)`. This is the same colex as the v1 artifact and the engine's
internal addressing.  For 4×4: `3^16 = 43,046,721` possible patterns, fitting
in 32 bits.

Colex is stored **big-endian** in the group header — this ensures
lexicographic sort on disk matches numeric colex order, so binary search on
the in-memory array works without byte-order correction.

### 2.2 Key byte (side, ko_point, passes)

Packed into one byte per entry — not stored in the group header because
passes=0 and passes=1 states of the same goban/side/ko share the same group.

Bit layout (MSB→LSB):

```
[passes:2][ko_point:KO_BITS][side:1]
```

| field | bits | values | notes |
|---|---|---|---|
| `side` | 1 | 0=Black, 1=White | |
| `ko_point` | ceil(log₂(n+1)) | 0…n-1 = cell, n = none | n = w·h |
| `passes` | 2 | 0, 1 (2 is terminal — handled by reader, not stored) | |

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

Per spec R10 and the design observation in §2.2: passes=2 states are **not
stored in the artifact**. They are terminals with no free parameters:

- `L = H = genericAreaScore(goban)` (using the side-to-move in the lookup
  key)
- `DTT = 0`
- `flags = TERMINAL`

The engine (M3) detects `passes == 2` before consulting the artifact and
returns the terminal value directly. This saves storing ~50M redundant
entries — roughly one-third of the key space — and is the single largest
factor keeping the budget near 600 MB.

### 2.4 Sort order

Entries are sorted by `(colex_index, passes, ko_point, side)` — equivalently
`(colex_index, key_byte)`. The `key_byte`'s bit layout (passes in MSBs)
ensures that entries within a group sort as: passes=0 side=B, passes=0
side=W, passes=1 side=B, passes=1 side=W, with ko variants interleaved
naturally.

## 3. Column schema

Per spec R2 (separate L/H) and R3 (computed DTT).

| column | type | size | range | description |
|---|---|---|---|---|
| `key_byte` | u8 | 1 B | — | side + ko_point + passes (see §2.2) |
| `L` | i8 | 1 B | [−n, +n] | lower bound (Black-positive convention) |
| `H` | i8 | 1 B | [−n, +n] | upper bound (Black-positive convention) |
| `DTT` | u8 | 1 B | 0–254 = steps, 255 = FAR | depth-to-terminal |
| `flags` | u8 | 1 B | — | bit flags (see §3.1) |

**Total per entry: 5 bytes** (1 key + 4 value columns).

The `L`/`H` range of `[−n, +n]` for an n-cell goban fits in `i8` for all
gobans through 5×5 (n=25). For 4×4, range is [−16, +16] = 33 values.

### 3.1 Flags byte

| bit | name | meaning |
|---|---|---|
| 0 | `KO_SENSITIVE` | `L != H` — the value is a bracket, not a point |
| 1 | `TERMINAL` | no legal non-pass moves exist for this side from this state |
| 2–7 | reserved | zero |

`KO_SENSITIVE` is redundant with `L != H` but is stored explicitly so the
reader can filter without comparing L and H — useful for the pin census and
for the engine's move ordering.

`TERMINAL` is set when M2b determines that the state has no legal non-pass
moves. It is distinct from passes=2 terminals (which are not stored). A
passes=0 or passes=1 state with `TERMINAL` set means the side has no
board play — they must pass.

### 3.2 DTT encoding

| value | meaning |
|---|---|
| 0 | terminal (passes=2, or passes∈{0,1} with no legal moves) |
| 1–254 | steps to nearest terminal under optimal play |
| 255 | FAR — not computed or no path to terminal known (sentinel) |

DTT 255 is a legitimate sentinel, not an error. States in cycle-affected
regions where no path to a terminal exists under all policies will have
DTT=255. The verifier (I7) checks that non-terminals without `KO_SENSITIVE`
set have non-255 DTT, and that terminals have DTT=0.

## 4. Header layout

128 bytes, fixed size. All multi-byte integers are **little-endian** except
where noted.

| offset | size | field | type | description |
|---|---|---|---|---|
| 0 | 4 | `magic` | u8[4] | `'W' 'Z' 'O' '2'` = `0x57 0x5A 0x4F 0x32` |
| 4 | 2 | `version` | u16 | format version = 1 |
| 6 | 1 | `w` | u8 | goban width |
| 7 | 1 | `h` | u8 | goban height |
| 8 | 2 | `rules_id` | u16 | ruleset identifier (match `src/rules.zig`) |
| 10 | 2 | `entry_size` | u16 | bytes per entry = 5 |
| 12 | 8 | `n_groups` | u64 | number of goban groups |
| 20 | 8 | `n_entries` | u64 | total entries (passes∈{0,1}) |
| 28 | 8 | `data_offset` | u64 | byte offset to first group = 128 |
| 36 | 2 | `ko_bits` | u8 | ceil(log₂(w·h+1)) bits used for ko in key_byte |
| 38 | 2 | `reserved2` | u8[2] | zero |
| 40 | 32 | `sha256` | u8[32] | SHA-256 of all bytes before this field; zero at build time |
| 72 | 56 | `reserved` | u8[56] | zero; available for future header extensions |

**Validation on load:**

1. `magic` == `"WZO2"` — wrong magic → fatal, "not a WZO2 artifact"
2. `version` == 1 — wrong version → fatal, "unsupported version N"
3. `w` and `h` match the engine's goban size — mismatch → fatal
4. `entry_size` == 5 — mismatch → fatal, "corrupt or unsupported entry size"
5. File size == `data_offset + n_groups × 5 + n_entries × entry_size`
6. SHA-256 of bytes 0–39 (the header minus the hash slot) matches `sha256`
   — mismatch → fatal, "checksum failure"

## 5. F2 byte budget

### 5.1 Derivation

The file size is:

```
size = 128 + G × 5 + N × 5   bytes
```

where:
- `G` = number of distinct gobans (colex indices) with at least one reachable
  (side, ko, passes∈{0,1}) state
- `N` = total reachable (goban, side, ko, passes∈{0,1}) states

**N** is given by the solver's compact state count. The spec §1 reports
99,133,036 compact states for the full Markov key at 4×4. The EXP-3 census
(a′) reports 102,838,092 — the solver's count is 3.6% lower, likely due to
more restrictive reachability accounting. **Use the solver's count as the
operating value**: `N = 99,133,036`.

**G** is not directly measured by any census. The EXP-3 census reports
29,497,329 distinct `(b, ko)` addresses. A goban appears:
- Once when reachable only with `ko = none`
- Twice when reachable with both `ko = none` and `ko = cell_X`

So `G = distinct_addresses − gobans_with_dual_ko`. From the 3×3 census:
1,896 of 13,997 addresses (13.5%) are `ko = cell`. For 4×4, with 17 ko
values vs 3×3's 10, the dual-ko fraction is plausibly 15–25%. This gives
G in the range **22M–25M**.

| G (estimate) | N | size | vs 600 MB |
|---|---|---|---|
| 20.0M | 99,133,036 | 595.7 MB | **under** (−0.7%) |
| 22.0M | 99,133,036 | 605.7 MB | **over** (+0.9%) |
| 24.0M | 99,133,036 | 615.7 MB | **over** (+2.6%) |
| 25.0M | 99,133,036 | 620.7 MB | **over** (+3.4%) |
| 29.5M (upper bound) | 99,133,036 | 643.2 MB | **over** (+7.2%) |

Threshold: `G + N ≤ 119,999,974` for ≤ 600 MB. With N = 99,133,036, need
`G ≤ 20,866,938`.

### 5.2 Verdict

**Derived budget: ~605–620 MB for the most probable G range (22–25M).**
This exceeds the 600 MB ceiling by 0.9–3.4%.

Per spec §4 F2 gate: **a derived budget > 600 MB returns the sprint to the
Orchestrator for re-scoping.** The following options exist:

1. **Re-scope the ceiling to 650 MB.** The host's 4 GB RSS cap is the hard
   constraint; the 600 MB artifact ceiling is a guess with headroom from the
   spec's own words (§4, "R9's 600 MB ceiling is a guess with headroom, not a
   derivation"). The v1 artifact is 258 MB. The v2 artifact being ~2.4× that
   size is proportionate to the ~2× increase in stored states (passes=0/1 vs
   passes=0 only) and is still 7× smaller than the 4 GB RSS cap. **This is the
   recommended path.**

2. **Compress the artifact.** gzip on the grouped format (highly repetitive
   structure: many gobans have identical entry counts) could compress to
   ~40–60% of raw size. However, this adds a decompression step to every load,
   complicates R7 (reproducibility — the SHA-256 is of the compressed or
   uncompressed data?), and is a scope increase for M2b/M3. Deferred unless
   re-scoping is rejected.

3. **Eliminate the colex per group.** Storing entries as a flat sorted array
   of `[colex:4][key_byte:1][L:1][H:1][DTT:1][flags:1]` (9 bytes/entry)
   eliminates G from the budget equation entirely. Size: `128 + N × 9 =
   892,197,452 bytes ≈ 851 MB` — worse, not better. The grouped format is
   already the compression.

4. **Store passes=2 entries and drop the reader-side terminal computation.**
   This adds ~50M entries (`N ≈ 149M`) and pushes the budget to ~870 MB. Not
   viable.

**Action: flag for re-scope.** The M1 design audit (O-4) should confirm the
derivation independently. M2b must not dispatch until the budget question is
resolved.

### 5.3 Memory budget at load time

The engine (M3) must load group headers into memory for binary search:

```
load_RAM = G × 5 bytes   (group headers, kept in memory)
         + N × 5 bytes   (entry data, mmap'd or read on demand)
```

Group headers: 22–25M × 5 = 110–125 MB.  Entry data (mmap'd): ~473 MB
virtual, but only faulted pages consume RSS. The engine's working set is
~120 MB + per-lookup page faults — well within the host's budget.

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

## 7. R8 baseline inventory

Per spec R8 (format must support reader/verifier checks) and the verify-battery
spec §6a. The format contract enables the following checks. Any relaxation of
these in M3's reader or the verify-battery must be called out explicitly.

### 7.1 Format-level checks (valid on any artifact, no fixpoint needed)

| check | how the format supports it |
|---|---|
| **Magic + version** | Fixed-offset magic field `WZO2` at byte 0; version at byte 4. Checked on every load. |
| **Goban size match** | `w` and `h` at bytes 6–7. Checked on load; mismatch → fatal. |
| **SHA-256 integrity** | 32-byte slot at offset 40. Covers bytes 0–39. Computed post-build by M2b and verified on load. |
| **File size consistency** | `size == data_offset + n_groups × 5 + n_entries × entry_size`. Verifies no truncation or appendage. |
| **Entry size invariant** | `entry_size == 5`. Guards against future format changes that the reader doesn't support. |
| **Colour inversion (I2)** | Keys are explicit. For every stored entry `(colex, s, ko, p)` the inverted key is `(colour_flip(colex), 1-s, ko, p)`. Check `L(pos, side) == -H(inverted)`. Requires the battery to compute colour-flip of colex (rank from inverted position); doable with the independent re-implementation (R8). |
| **L ≤ H (I3)** | `L` and `H` are stored per entry; check on every row. |
| **Score range (I12)** | `L, H ∈ [−n, +n]` where `n = w·h`. Exhaustive scan. |
| **Round-trip identity (A5)** | `decode(encode(key)) == key` and `decode(encode(cols)) == cols` for all entries. The key encoding is lossless by construction (colex + key_byte), but the check verifies that the writer and reader agree on endianness and bit packing. |
| **Ko bits match goban size** | `ko_bits == ceil(log₂(w·h+1))`. Prevents misinterpretation of key_byte. |
| **Group order** | Groups must appear in strictly increasing colex order. A single backward step invalidates binary search. |

### 7.2 State-level checks (require fixpoint or move relation)

| check | how the format supports it |
|---|---|
| **Bellman residual (I4)** | Keys are explicit. Battery reconstructs the state from key, generates children via its own move engine (R8), and checks `L = Φ(L)`, `H = Φ(H)`. |
| **Pin census (I1)** | `L == H` vs `L < H` computed from stored L/H. `pin_T` = states where `TIE_pin` matches 0 (or the selected convention). |
| **DTT sanity (I7)** | DTT column is stored. Terminals must have DTT=0. Non-terminals with paths to terminal must have DTT > 0 and ≤ a child's DTT+1. |
| **KO_SENSITIVE ⊆ cycle-reachable (I5)** | Flags.`KO_SENSITIVE` is stored. Battery computes SCCs on its own move graph and verifies containment. |
| **UNDEF census (I6)** | Every legal position has a determinable lookup: in-artifact (found) or not (UNDEF). Battery enumerates all legal positions and checks coverage. |
| **Anchor values (I9)** | Specific keys' L/H values must match committed anchors. Keys are explicit — the battery looks up the known root state. |
| **Terminal flag consistency** | Flags.`TERMINAL` must match the condition "no legal non-pass moves for this side." Battery computes move set independently and checks. |

### 7.3 Checks the format does NOT support alone

These require the fixpoint solver's cooperation (M2a/M2b) and are included for
completeness — the verifier must coordinate:

| check | what's needed beyond the format |
|---|---|
| **Move-set consistency (I11)** | M2b must emit a sidecar dump of the legal-move set used during the fixpoint, for the battery's independent move engine to compare against. Not a format requirement — an M2b deliverable. |
| **Truncation-gap regression (I8)** | 2×2 only; the 24 formerly-mismatched states must be pinned in the format as entries and their values compared. The format carries the values; the battery checks them. |
| **TIE median (I10)** | The artifact stores L and H, not TIE. TIE is computed by the reader as `median(L, convention, H)`. The battery checks this by recomputing TIE from stored L/H and verifying `TIE ∈ [L, H]`. |

## 8. Design decisions and rationale

**D1: Grouped inline, not a separate group index.** A separate group index
(adds 8 bytes per group: 4 colex + 4 offset) costs ~200 MB at G=25M, pushing
the file over 800 MB. Storing colex inline with the group header (5 bytes
per group, including the count byte) saves ~3 bytes/group and keeps the
budget near 600 MB. The trade: the engine must read all group headers into
memory (~120 MB) for binary search, which is acceptable given the host's
4 GB RSS cap.

**D2: Passes=2 terminal computation in the reader, not stored.** R10 defines
passes=2 states as terminals with no free parameters. Storing them would add
~50M redundant entries (~250 MB). The reader (M3) handles passes=2 by
computing area score on the fly. This is a pure format-design decision and
does not affect the solver (which already excludes passes=2 from its compact
working array).

**D3: i8 for L and H, not a packed narrower type.** L and H for 4×4 need 6
bits each (33 values, [−16, +16]). Packing them into 12 bits would save 4
bits per entry (~50 MB total) but would require bit-shift operations on every
lookup, complicate the column layout, and break byte-alignment for the other
columns. The simpler byte-aligned layout is preferred for debuggability and
code simplicity. The 50 MB savings are not worth the complexity given the
budget is already near 600 MB (and would be ~550 MB with packing — still
close to the line).

**D4: colex stored big-endian in groups.** Ensures the on-disk sort matches
the in-memory sort without byte-swap during binary search.

**D5: Little-endian header (except colex).** The header's multi-byte fields
(u16, u64) use LE per the Zig convention. The colex is explicitly BE for
sort-order correctness. This is a deliberate inconsistency — each field uses
the endianness that makes its primary consumer correct.

**D6: No compression.** The format is uncompressed so that (a) the SHA-256 in
the header covers the exact bytes the reader reads, (b) the reader can mmap
and seek without a decompression step, and (c) the reproducibility command
(R7) is a single `zig build` invocation, not a pipeline with an external
compressor. If the budget requires compression, that is a separate decision
to be made at re-scope.

## 9. What I could not establish

1. **The exact distinct goban count G for 4×4.** The EXP-3 census reports
   distinct `(b, ko)` addresses (29,497,329) but not distinct gobans. The
   budget derivation uses an estimated range (22–25M). M2a's reachability
   builder will produce the exact count; until then the budget is a range,
   not a point estimate.

2. **Whether the solver's compact count (99,133,036) exactly matches the
   number of entries M2b will produce.** The solver excludes some states
   (e.g., unreachable under its narrower walk), and M2b will follow the
   same reachability. The census count (102,838,092) is an upper bound. The
   exact N is an M2b output.

3. **DTT maximum value.** It is possible that 1 byte is insufficient if the
   longest path to terminal exceeds 254 steps. For a state graph with ~100M
   nodes, the longest simple path could be large, but DTT is the *shortest*
   path to terminal, which is bounded by the number of states in the
   cycle-free portion. Empirical data from the 3×3 solve suggests DTT stays
   under 100. If 4×4 exceeds 254, the FAR sentinel (255) handles it
   gracefully — the only loss is DTT precision on very deep states, not
   correctness.

4. **The F2 resolution.** The derived budget exceeds 600 MB per the spec's
   own gate. The recommended re-scope is to raise the ceiling to 650 MB.

## 10. What to check next

1. **O-4 audit** — independently verify the byte budget derivation and the
   key encoding.
2. **M2a reachability builder** — produces the exact G and N counts. Until
   then the budget remains a range.
3. **M2b start gate** — do not dispatch until the F2 budget question is
   resolved (re-scope decision from Orchestrator).

## A. Example lookup pseudocode

```zig
fn lookup(artifact: []const u8, colex: u32, side: Side, ko: u8, passes: u2) ?Row {
    // Terminal shortcut
    if (passes == 2) {
        return terminalRow(colex, side); // area score, DTT=0, TERMINAL flag
    }

    const header = parseHeader(artifact[0..128]);

    // Binary search groups on colex_index (big-endian)
    const groups = artifact[header.data_offset..];
    var lo: usize = 0;
    var hi: usize = header.n_groups;
    while (lo < hi) {
        const mid = lo + (hi - lo) / 2;
        const mid_colex = readU32BE(groups[mid * 5 ..][0..4]);
        if (mid_colex < colex) lo = mid + 1
        else if (mid_colex > colex) hi = mid
        else { lo = mid; break; }
    }
    if (lo >= header.n_groups) return null;
    const grp_colex = readU32BE(groups[lo * 5 ..][0..4]);
    if (grp_colex != colex) return null;

    const count: u8 = groups[lo * 5 + 4];
    const target_kb = encodeKeyByte(side, ko, passes, header.ko_bits);

    // Linear scan within group
    const entry_base = header.data_offset +
        header.n_groups * 5 +  // skip all group headers
        (entries_before_group) * 5;  // prefix sum of counts

    for (0..count) |i| {
        const entry = artifact[entry_base + i * 5 ..][0..5];
        if (entry[0] == target_kb) {
            return Row{
                .L = @bitCast(entry[1]),
                .H = @bitCast(entry[2]),
                .DTT = entry[3],
                .flags = entry[4],
            };
        }
    }
    return null; // state not in artifact (unreachable under artifact's rules_id)
}
```

Note: `entries_before_group` requires a prefix sum over group counts. This can
be precomputed at load time (one pass, O(G)) and cached alongside the group
headers, or computed on the fly with a cumulative scan during binary search.
The cost is marginal (~25M additions at load, <0.1s) and the array of offsets
adds `G × 4` bytes (~100 MB) to the load-time memory. If memory pressure is a
concern, the engine can compute the prefix sum regionally (per page of groups)
rather than caching the full offset array.
