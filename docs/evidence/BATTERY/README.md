# BATTERY — verify-battery evidence

Author: DSPro/T187 (P3-G) · 2026-08-01

## Files

| file | artifact | goban | status |
|---|---|---|---|
| `2x2-psk-stub.jsonl` | `artifacts/oracle-2x2.wzo` (SHA256 `1ed06e64…`) | 2×2 | stub passes (checks not wired) |
| `3x2-psk-stub.jsonl` | `artifacts/oracle-3x2.wzo` (SHA256 `d4d22c0d…`) | 3×2 | stub passes (checks not wired) |

## Schema version

`1.0.0` — header/result/trailer JSONL as per M1 spec (T168).

Each `.jsonl` file contains 14 lines:
- 1 header (kind=header): artifact metadata, CLI args, invariant list
- 12 results (kind=result): one per invariant I1–I12
- 1 trailer (kind=trailer): exit code, timing, counts

## Status

All invariants report `"status":"skipped"` or `"status":"not-applicable"`. This is the
M1 harness (T168) with stub checks. The real invariant implementations live in:

- `src/vb_table.zig` — I1, I2, I3, I6, I10, I12 (table invariants, T169)
- `src/vb_fixpoint.zig` — I4, I7, I8, I9, I11 (fixpoint invariants, T173)
- `src/vb_graph.zig` — I5 (SCC containment, T171)

These modules have their own `test` blocks wired into `zig build test` (P3-G, T187).

## Artifact notes

- Both artifacts are PSK (`rules_id=1`, "Chinese area, komi 0, positional superko").
- I3 (L≤H) reports **not-applicable** on WZO1 (no L/H columns).
- I10 (TIE median) reports **not-applicable** on WZO1 (no TIE column).
- I8 (truncation-gap regression) reports **not-applicable** (external fixture).
- I11 (move-set consistency) reports **not-applicable** (dump format unspecified per GAP-5).

## RSS HWM

RSS high water mark measured via:
- Linux: `/proc/self/status` `VmHWM` (kernel-maintained peak)
- macOS: `getrusage(RUSAGE_SELF)` → `ru_maxrss` (bytes → MB)

## JSON escaping

Proper JSON string escaping per RFC 8259 §7 (backslash, quote, control chars).
The previous `quoteJson` was a no-op; replaced with `escapeJsonToBuf` that handles
`\"`, `\\`, `\b`, `\f`, `\n`, `\r`, `\t`, and `\u00XX` for other control chars.
