# 4×4 basic-ko + TIE WZO format

**Author:** DSFlash/T113 · **Date:** 2026-07-30  
**Task:** QA-026 — persist EXP-6's 4×4 fixpoint as a WZO1 artifact  
**Claim:** 4x4.BASICKO-TIE (fresh-start oracle, basic ko, TIE=0 for long cycles)

## File

`data/oracle-4x4-basicko-tie-area.wzo`

```
Size: 258,280,358 bytes (32 B header + 258,280,326 B payload)
SHA-256: <pending — run after write>
```

## Format

Standard WZO1 artifact (ADR-0011) with the following header:

| offset | length | field | value | meaning |
|---|---|---|---|---|
| 0 | 4 | magic | `WZO1` | Standard WZO1 magic |
| 4 | 1 | format_version | 1 | WZO1 format |
| 5 | 1 | colex_layout | 1 | RAW colex (3^n) |
| 6 | 1 | board_w | 4 | 4 columns |
| 7 | 1 | board_h | 4 | 4 rows |
| 8 | 1 | value_semantics | 1 | Fresh-start value (ADR-0008) |
| **9** | **1** | **rules_id** | **2** | **basic-ko + TIE=0** (see below) |
| 10 | 1 | column_count | 6 | Six schema columns |
| 11 | 1 | reserved | 0 | |
| 12 | 8 | total | 43,046,721 | 3¹⁶ colex address space |
| 20 | 8 | legal_count | 24,318,165 | unique colex indices with ≥1 valued side |
| 28 | 4 | payload_crc32 | — | CRC-32 (ISO-HDLC) of the whole payload |

### Rules ID 2

Rules ID 1 is `RULES_CHINESE_PSK` (Chinese area scoring, komi 0, positional superko,
Benson/double-pass terminal). This file uses **rules ID 2**, defined as:

- **Scoring:** Chinese area scoring, komi 0
- **Ko rule:** Basic ko (formalisation (i) in ADR-0013): a move that would repeat the
  immediately-preceding board position is illegal (single-point ko, no superko)
- **Long cycles:** Value = TIE (= 0) for any state that repeats within the search
  (i.e., encountered on the current DFS path). This replaces PSK's global ban-set.
- **Terminal:** Two consecutive passes end the game; the position is scored by area.

The standard `artifact.decode()` rejects this rules_id. To read this file, patch
byte 9 to 1 before calling `decode()`, or use a decoder that accepts rules_id 2.

### Payload (six columns, total bytes each)

| column | type | meaning |
|---|---|---|
| vb | i8 | value, Black to move (Black-positive; UNDEF=-128 = unreachable/illegal) |
| vw | i8 | value, White to move (still Black-positive; UNDEF=-128) |
| fb | u8 | flags, Black to move (bit 0 = L<H ko-sensitive) |
| fw | u8 | flags, White to move (bit 0 = L<H ko-sensitive) |
| db | u8 | dtt, Black to move (all 255 = FAR) |
| dw | u8 | dtt, White to move (all 255 = FAR) |

**Addressing:** colex RAW index `0..(3¹⁶-1)` over the 4×4 board. `genericIsLegal` is
NOT applied — unreachable or illegal colex slots store UNDEF(-128). A slot is
"valued" iff the fresh-start state (passes=0, ko=KO_NONE, side=side) is reachable
from the empty board under basic ko and appears in the compact fixpoint.

**Value rule:** `V = median(L, TIE, H) = max(L, min(TIE, H))` where TIE = 0.
This is the EXP-6/ADR-0013 convention: L and H bracket the exact value under
two-sided certification, the interval is collapsed to a single fresh-start score
at the tie-line.

**Root values:**

```
vb[0] = +1   (empty board, Black to move: V=+1  L=+1 H=+16  score-pinned)
vw[0] = -1   (empty board, White to move: V=-1  L=-16 H=-1   score-pinned)
```

The anchor +2 expected by van der Werf & Winands (ICGA 2009) is **not reproduced**
under basic ko + TIE=0. See `docs/evidence/QA-026/4x4/PROVENANCE.md`.

### Flags semantics

- **bit 0 (KO_SENSITIVE):** 1 if `L < H` (the bracket spans a range, so the
  fresh-start value is not a single resolved score)
- **bit 1 (FROM_FORWARD):** 0 for all entries (no forward-search reinforcement)

### DTT semantics

All dtt values are 255 (= FAR). The fixpoint computes equilibrium values; it does
not compute distance-to-terminal.

## Statistics (from the EXP-6 run, 2026-07-30)

```
Total reachable states (all passes): 147,638,298
Compact states (passes∈{0,1}):       99,133,036
Fresh-start states in compact:        48,505,262
Positions with ≥1 side valued:        24,318,165
Fixpoint sweeps:                      31
Peak RSS:                             3,629 MB
Wall time:                            3,606.8 s (~1 h)
```

## Production command

```
tools/runner --rss-cap-mb 8192 --max-wall 14400 --max-cpu 28800 -- \
  zig run -O ReleaseFast src/exp6_solve.zig
```

Source: `src/exp6_solve.zig` (includes WZO serialisation added by DSFlash/T113).

## Reading the file (Python)

```python
import struct, zlib

with open('data/oracle-4x4-basicko-tie-area.wzo', 'rb') as f:
    data = f.read()

magic = data[0:4]
w, h, rules_id = data[6], data[7], data[9]
total = struct.unpack('<Q', data[12:20])[0]
legal_count = struct.unpack('<Q', data[20:28])[0]
crc_stored = struct.unpack('<I', data[28:32])[0]
payload = data[32:]

# crc check (ISO-HDLC)
crc_calc = (zlib.crc32(payload) ^ 0xFFFFFFFF) & 0xFFFFFFFF
assert crc_calc == crc_stored, f'CRC mismatch: {crc_calc:#x} != {crc_stored:#x}'

vb = list(struct.iter_unpack('b', payload[0*total:1*total]))
vw = list(struct.iter_unpack('b', payload[1*total:2*total]))
fb = list(struct.iter_unpack('B', payload[2*total:3*total]))
fw = list(struct.iter_unpack('B', payload[3*total:4*total]))

# Root (index 0 = empty board)
print(f'Empty B: vb={vb[0][0]}, flags={fb[0][0]:#04b}')
print(f'Empty W: vw={vw[0][0]}, flags={fw[0][0]:#04b}')
```

## Related

- `docs/evidence/QA-026/4x4/PROVENANCE.md` — acceptance criteria and gate chain
- `docs/evidence/QA-026/4x4/exp6-solve-2026-07-29.stdout` — first EXP-6 run (without WZO write)
- `src/exp6_solve.zig` — solver with WZO serialisation
- `src/artifact.zig` — WZO1 format specification (ADR-0011)
