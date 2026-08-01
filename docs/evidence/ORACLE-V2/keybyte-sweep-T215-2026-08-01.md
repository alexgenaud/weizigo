# T215 — key_byte encode/decode call-site sweep

```
Status:   COMPLETE — one defect found (T193, already fixed); all other sites correct
Task:     T215 · Worker: T215 · Date: 2026-08-01
Scope:    every encodeKeyByte, decodeKeyByte, keyByte* call site in src/
```

## 1. Summary

**Verdict: all production call sites are correct after the T193 fix.**
No second defect of the literal-swap class exists. The T193 bug was the only
instance of a literal `0` occupying the `passes` position where it did not
belong.

Two engineering concerns are flagged (§3) but neither is a live defect.

## 2. Call-site inventory

### 2.1 Canonical encoder — `artifact2.zig:60`

```zig
pub fn encodeKeyByte(side: u1, ko: u8, passes: u1, terminal: u1, ko_bits: u8) u8
```

Bit layout: `[passes:1][ko_point:ko_bits][side:1][terminal:1]` (MSB→LSB).

### 2.2 Production call sites

| # | File:Line | passes | terminal | ko_bits | Class | Verdict |
|---|---|---|---|---|---|---|
| C1 | `artifact2.zig:468` | `@intCast(passes)` | `0` | `a.header.ko_bits` | lookup | **OK** — `passes` from caller (u2→u1); terminal=0 for masked comparison |
| C2 | `oracle_v2_build.zig:370` | `0` | `0` | `kb` | 4×4 passes=0 builder | **OK** — literal 0 for passes=0 loop; terminal patched in Phase 3b |
| C3 | `oracle_v2_build.zig:387` | `1` | `0` | `kb` | 4×4 passes=1 builder | **OK (FIXED T193)** — was `0` before fix; now `1` for passes=1 loop |
| C4 | `oracle_v2_consumer_load.zig:271` | `0` | `terminal` | `kb` | 3×3 passes=0 builder | **OK** — literal 0 for passes=0 loop; terminal computed inline |
| C5 | `oracle_v2_consumer_load.zig:289` | `1` | `terminal` | `kb` | 3×3 passes=1 builder | **OK** — literal 1 for passes=1 loop; terminal computed inline |

All five sites use the canonical `artifact2.encodeKeyByte`. No call passes a
variable in the `passes` position; all use literal `0` or `1` keyed to the
loop they sit in. This is the exact shape of the T193 bug class, but the
literals now match their loops at every site.

#### C1 detail — `artifact2.lookup()` (line 468)

```zig
pub fn lookup(a: *const LoadedArtifact, colex: u32, side: i8, ko: u8, passes: u2) ?Row {
    ...
    const target_kb = encodeKeyByte(sideToU1(side), ko, @intCast(passes), 0, a.header.ko_bits);
```

- `passes: u2` → `@intCast(passes)` → `u1`. Panics in safe builds on passes∈{2,3}.
- The sole caller (`gtp.zig:bounds2`) shortcuts `passes >= 2` before calling.
  Safe in practice, but the `u2` signature on `lookup` overstates what it
  accepts. A future caller passing `passes=2` without a guard would hit a
  runtime cast failure in safe builds or silent truncation in fast builds.
- **Not a live defect; flagged as a latent hazard (§3.2).**

#### C2/C3 detail — 4×4 builder

```zig
// C2 (line 370) — passes=0 loop
for (0..exp6.KO_DIMS4) |ko_u| {
    for ([_]u1{ 0, 1 }) |side| {
        const kb_val = artifact2.encodeKeyByte(side, @intCast(ko_u), 0, 0, kb);

// C3 (line 387) — passes=1 loop
for ([_]u1{ 0, 1 }) |side| {
    const kb_val = artifact2.encodeKeyByte(side, exp6.KO_NONE4, 1, 0, kb);
```

- `ko` for C2: `@intCast(ko_u)` where ko_u ∈ 0..KODIMS4(17). All values fit in u8.
- `ko` for C3: `exp6.KO_NONE4` = 16. Correct — passes=1 always has no ko constraint.
- `terminal` is 0 in both; Phase 3b sets the terminal bit later.
- Construction order: ko-major, side-minor for passes=0; then passes=1 entries.
  This produces monotonic key_byte order (passes bit is MSB of the sort key).

#### C4/C5 detail — 3×3 consumer/builder

```zig
// C4 (line 271) — passes=0
.key_byte = artifact2.encodeKeyByte(side, @intCast(ko_u), 0, terminal, kb),

// C5 (line 289) — passes=1
.key_byte = artifact2.encodeKeyByte(side, none, 1, terminal, kb),
```

- `terminal` is computed inline (child_count check) rather than patched later.
  Semantically equivalent to the 4×4 builder approach.
- `none` = `@intCast(exp6.KO_NONE)` — same invariant as 4×4.
- Construction order same as 4×4 → monotonic key_bytes.

### 2.3 Duplicate encoder — `oracle_v2_accept.zig:121`

```zig
fn encodeKeyByte(side: u1, ko_point: u8, passes: u2, terminal: bool, ko_bits: u8) u8
```

Signature differs from canonical: `passes: u2` vs `u1`, `terminal: bool` vs `u1`.
Bit layout is **identical** to canonical — both shift `passes` by `2 + ko_bits`
(1 bit), both OR `terminal` into bit 0. The type differences are cosmetic but
mask the fact that this is a duplicate.

| # | File:Line | passes | Verdict |
|---|---|---|---|
| C6 | `oracle_v2_accept.zig:417` | `passes` (decoded from entry) | **OK** — A3 inverted lookup |
| C7 | `oracle_v2_accept.zig:510` | `passes` (decoded from entry) | **OK** — A5 round-trip |

Both sites decode `passes` via `keyBytePasses()` which reads 1 bit into a u2
(always 0 or 1). The re-encode uses the accept.zig encoder, not the canonical
one, but the bit layout is identical so the round-trip succeeds.

### 2.4 Decode call sites

| # | File:Line | Function | Used by | Verdict |
|---|---|---|---|---|
| D1 | `artifact2.zig:70` | `decodeKeyByte` (returns struct) | Tests only | **OK** — no production callers |
| D2 | `oracle_v2_accept.zig:391-394` | `keyByte{Terminal,Side,Ko,Passes}` | A3 check | **OK** — decode then inverse-encode |
| D3 | `oracle_v2_accept.zig:505-508` | `keyByte{Terminal,Side,Ko,Passes}` | A5 check | **OK** — decode then re-encode |

The production reader (`gtp.zig`) does not call `decodeKeyByte` — it uses
`artifact2.lookup()` which builds a target key_byte and scans for a match,
decoding fields only for the matching entry. No decode-site defect.

### 2.5 `koBits` — shared by all builders

```zig
pub fn koBits(n_cells: u8) u8 { ... }
```

- 4×4 (n=16): 5 bits ✓
- 3×3 (n=9): 4 bits ✓
- 3×2 (n=6): 3 bits ✓
- 2×2 (n=4): 3 bits ✓

All callers use the same function. No literal `ko_bits` values in production code.

### 2.6 Test call sites (not audited for defect potential)

Test-only call sites in `artifact2.zig` (lines 517, 528, 532, 537, 603-664)
and `oracle_v2_accept.zig` (lines 899, 918, 930, 933, 943, 950, 965, 966) are
not candidates for the T193 class — they don't produce artifacts. Noted for
completeness but not flagged.

## 3. Engineering concerns (not live defects)

### 3.1 Duplicate encoder (DRY violation)

`oracle_v2_accept.zig` has its own `encodeKeyByte` with a different signature.
If the canonical encoder's bit layout changes, the acceptance tool must change
in lockstep. The different types (`passes: u2` vs `u1`, `terminal: bool` vs
`u1`) mean the compiler will not flag an accidental semantic divergence.

**Recommendation:** Import `artifact2.encodeKeyByte` directly in
`oracle_v2_accept.zig` and delete the duplicate. The unit tests can adapt
to the canonical types.

### 3.2 `lookup()` signature overstates capability

`artifact2.lookup()` accepts `passes: u2` but `@intCast`s to `u1` internally.
A future caller passing `passes=2` (without the guard `bounds2` uses) would
panic in safe builds. The only current caller guards it, so no live defect.

**Recommendation:** Change the parameter to `passes: u1` to match the
encoder's type, and move the `passes >= 2` guard to the caller (it already is).
Alternatively, handle passes=2 in lookup itself (return a zero-DTT terminal
score).

### 3.3 `passes: u1` enables the T193 bug class

Every builder site passes a literal `0` or `1` for passes. The type `u1`
accepts both values silently — the compiler cannot distinguish "passes=0 for
the passes=0 loop" from "passes=0 for the passes=1 loop." Both are valid `u1`
literals. A named enum `Passes` would have made `Passes.one` visually distinct
from `0`, and an `enum { zero, one }` with `@intFromEnum` would fail to
compile if a raw integer were accidentally substituted.

**Recommendation:** Consider a dedicated enum or named struct fields for
`encodeKeyByte` in a follow-up task. Not implemented here — this is a sweep,
not a refactor.

## 4. What would falsify "all other sites are correct"

| hypothesis | how to test |
|---|---|
| C1: `@intCast(passes)` corrupts on passes≥2 | Call `lookup` with passes=2 in a test → expect panic or wrong result |
| C4/C5: consumer_load.zig terminal computation is wrong | A3/A5/A9 on a 3×3 artifact built by consumer_load — already passes (T193) |
| Duplicate encoder diverges from canonical | Compare bit layouts programmatically: encode the same (side,ko,passes,terminal) with both functions, compare byte |
| koBits wrong for some size | already tested in artifact2.zig:767 and accept.zig |
