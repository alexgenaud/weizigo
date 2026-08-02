#!/usr/bin/env python3
"""
Task: T277 · Role: worker · Model: deepseek-v4-pro · Date: 2026-08-02

Independent re-implementation of the WZO2 scanner for the incompleteness
verification. This shares NO code with t266_scan.py — it is a fresh
implementation to independently verify T266-H1 (the monochrome-side law
for passes=1 entries) and the census invariants.

Reads the WZO2 format from the byte-level spec in src/artifact2.zig:19-34.
"""
import sys
import struct
import os
from math import comb


# ---------------------------------------------------------------------------
# WZO2 reader — independent byte-level parse
# ---------------------------------------------------------------------------

def read_wzo2(path):
    """Read a WZO2 file and return header + arrays. No numpy dependency."""
    with open(path, 'rb') as f:
        hdr = f.read(128)
    magic = hdr[0:4]
    assert magic == b'WZO2', f'not a WZO2 file: {magic}'
    w = hdr[6]
    h = hdr[7]
    ko_bits = hdr[13]
    n_groups = struct.unpack('<Q', hdr[16:24])[0]
    n_entries = struct.unpack('<Q', hdr[24:32])[0]

    # Group index: 5 bytes per group (4 bytes colex LE + 1 byte count)
    colex = []
    counts = []
    with open(path, 'rb') as f:
        f.seek(128)
        for _ in range(n_groups):
            raw = f.read(5)
            cx = raw[0] | (raw[1] << 8) | (raw[2] << 16) | (raw[3] << 24)
            colex.append(cx)
            counts.append(raw[4])
    assert min(counts) >= 1, 'empty group present'
    assert sum(counts) == n_entries, 'counts do not sum to n_entries'
    assert all(colex[i] < colex[i+1] for i in range(n_groups-1)), 'colex not strictly increasing'

    # Entry rows: 4 bytes each
    entries = []
    with open(path, 'rb') as f:
        f.seek(128 + 5 * n_groups)
        for _ in range(n_entries):
            raw = f.read(4)
            entries.append((raw[0], raw[1], raw[2], raw[3]))  # kb, L, H, dtt

    return {
        'w': w, 'h': h, 'n': w * h,
        'ko_bits': ko_bits, 'ko_none': w * h,
        'n_groups': n_groups, 'n_entries': n_entries,
        'colex': colex, 'counts': counts,
        'entries': entries,
    }


def decode_kb(kb, ko_bits, ko_none):
    """Decode the key byte into (side, ko, passes, terminal)."""
    terminal = kb & 1
    side = (kb >> 1) & 1        # 0 = Black to move
    ko = (kb >> 2) & ((1 << ko_bits) - 1)
    passes = (kb >> (2 + ko_bits)) & 1
    return side, ko, passes, terminal


# ---------------------------------------------------------------------------
# Colex decode — independent from src/colex.zig
# ---------------------------------------------------------------------------

def colex_layer_offsets(n):
    """Number of gobans with < k stones, per layer."""
    off = [0]
    for k in range(n + 1):
        off.append(off[-1] + comb(n, k) * (2 ** k))
    return off


def colex_to_position(colex_val, n):
    """Inverse of the colex indexer: (subset, colour-bits) → board vector.
    Based on the combinatorial number system in src/colex.zig:127."""
    off = colex_layer_offsets(n)
    # Find stone count k
    k = 0
    while k <= n and off[k] <= colex_val:
        k += 1
    k -= 1
    within = colex_val - off[k]
    subset_idx = within >> k
    colour_bits = within & ((1 << k) - 1)

    # Unrank subset via combinatorial number system
    cells = []
    rem = subset_idx
    for j in range(k, 0, -1):
        c = j - 1
        while comb(c + 1, j) <= rem:
            c += 1
        cells.append(c)
        rem -= comb(c, j)

    # Build board: 0=empty, 1=black, -1=white
    board = [0] * n
    for i, cell in enumerate(reversed(cells)):
        board[cell] = 1 if (colour_bits >> i) & 1 else -1
    return board, k


def position_colours(board):
    """Return (has_black, has_white, is_mono_black, is_mono_white)."""
    stones = [c for c in board if c != 0]
    has_black = any(c == 1 for c in stones)
    has_white = any(c == -1 for c in stones)
    if not stones:
        return False, False, False, False  # empty
    return has_black, has_white, (has_black and not has_white), (has_white and not has_black)


# ---------------------------------------------------------------------------
# The scan — independent from t266_scan.py
# ---------------------------------------------------------------------------

def scan_artifact(data, label):
    """Run all checks on a parsed WZO2 artifact. Returns a verdict dict."""
    ko_bits = data['ko_bits']
    ko_none = data['ko_none']
    n = data['n']
    n_groups = data['n_groups']
    n_entries = data['n_entries']
    colex = data['colex']
    counts = data['counts']
    entries = data['entries']

    print(f'## {label}')
    print(f'#  {data["w"]}x{data["h"]}  ko_bits={ko_bits}  groups={n_groups}  entries={n_entries}')

    # Build start offsets for each group
    starts = [0]
    for c in counts[:-1]:
        starts.append(starts[-1] + c)

    # Classify every group
    mono_black = [False] * n_groups
    mono_white = [False] * n_groups
    is_empty = [False] * n_groups
    k_vals = [0] * n_groups
    b_counts = [0] * n_groups
    w_counts = [0] * n_groups

    for g in range(n_groups):
        board, k = colex_to_position(colex[g], n)
        has_b, has_w, mb, mw = position_colours(board)
        mono_black[g] = mb
        mono_white[g] = mw
        is_empty[g] = (k == 0)
        k_vals[g] = k
        b_counts[g] = sum(1 for c in board if c == 1)
        w_counts[g] = sum(1 for c in board if c == -1)

    n_mono_b = sum(mono_black)
    n_mono_w = sum(mono_white)
    n_empty = sum(is_empty)
    print(f'#  groups: empty={n_empty} mono-black={n_mono_b} mono-white={n_mono_w}')

    # Per-group: which (side, passes) combos are present?
    has_s0p1 = [False] * n_groups  # (side=0=Black to move, passes=1)
    has_s1p1 = [False] * n_groups  # (side=1=White to move, passes=1)
    has_s0p0 = [False] * n_groups  # (side=0, passes=0)
    has_s1p0 = [False] * n_groups  # (side=1, passes=0)

    # Entry-level counters
    total_p0 = 0
    total_p1 = 0
    bad_ko_p1 = 0
    ko_on_occupied = 0
    p0_with_ko = 0
    bad_order = 0

    for g in range(n_groups):
        g_start = starts[g]
        g_end = g_start + counts[g]
        group_entries = entries[g_start:g_end]

        # Check key byte ordering (C-B4): masked bytes must be strictly increasing
        masked = [e[0] & 0xFE for e in group_entries]
        for i in range(1, len(masked)):
            if masked[i] <= masked[i - 1]:
                bad_order += 1

        # Classify each entry
        for kb, L, H, dtt in group_entries:
            side, ko, passes, term = decode_kb(kb, ko_bits, ko_none)

            if passes == 0:
                total_p0 += 1
                if side == 0:
                    has_s0p0[g] = True
                else:
                    has_s1p0[g] = True

                if ko != ko_none:
                    p0_with_ko += 1
                    # C-B3: ko point must be empty on this goban
                    board, _ = colex_to_position(colex[g], n)
                    if board[ko] != 0:
                        ko_on_occupied += 1

                    # C-B2: monochrome-side law
                    if side == 0:  # Black to move — requires a WHITE stone
                        if mono_black[g]:
                            pass  # violation handled below
                    else:  # White to move — requires a BLACK stone
                        if mono_white[g]:
                            pass

            else:  # passes == 1
                total_p1 += 1
                if ko != ko_none:
                    bad_ko_p1 += 1
                if side == 0:
                    has_s0p1[g] = True
                else:
                    has_s1p1[g] = True

    # C-B2: monochrome-side law — every passes=0 entry must have the right colour stone
    cb2_violations = 0
    for g in range(n_groups):
        g_start = starts[g]
        g_end = g_start + counts[g]
        for i in range(g_start, g_end):
            kb = entries[i][0]
            side, ko, passes, term = decode_kb(kb, ko_bits, ko_none)
            if passes == 0 and not is_empty[g]:
                if side == 0 and mono_black[g]:  # Black to move needs a white stone, but board is mono-black
                    cb2_violations += 1
                elif side == 1 and mono_white[g]:  # White to move needs a black stone, but board is mono-white
                    cb2_violations += 1

    print(f'#  entries: passes=0 {total_p0}  passes=1 {total_p1}')
    print(f'#  passes=1 with ko != KO_NONE({ko_none}): {bad_ko_p1}')
    print(f'#  entries mis-ordered within a group (C-B4): {bad_order}')
    print(f'#  passes=0 entries with ko≠none: {p0_with_ko}')
    print(f'#  ko-on-occupied violations (C-B3): {ko_on_occupied}')
    print(f'#  monochrome-side violations (C-B2): {cb2_violations}')

    # --- T266-H1 verification ---
    # (P, side=0=Black, passes=1) absent <=> P monochrome-white
    # (P, side=1=White, passes=1) absent <=> P monochrome-black
    absent_s0 = 0
    absent_s1 = 0
    absent_not_mono_s0 = 0
    absent_not_mono_s1 = 0
    mono_but_present_s0 = 0
    mono_but_present_s1 = 0
    no_p1_at_all = 0

    for g in range(n_groups):
        if not has_s0p1[g]:
            absent_s0 += 1
            if not mono_white[g]:
                absent_not_mono_s0 += 1
        else:
            if mono_white[g]:
                mono_but_present_s0 += 1

        if not has_s1p1[g]:
            absent_s1 += 1
            if not mono_black[g]:
                absent_not_mono_s1 += 1
        else:
            if mono_black[g]:
                mono_but_present_s1 += 1

        if not has_s0p1[g] and not has_s1p1[g]:
            no_p1_at_all += 1

    one_sided = absent_s0 + absent_s1 - no_p1_at_all  # groups missing exactly one side

    print(f'#  absent (side=0,passes=1): {absent_s0}  mono-white: {n_mono_w}'
          f'  | absent-but-not-mono={absent_not_mono_s0}  mono-but-present={mono_but_present_s0}')
    print(f'#  absent (side=1,passes=1): {absent_s1}  mono-black: {n_mono_b}'
          f'  | absent-but-not-mono={absent_not_mono_s1}  mono-but-present={mono_but_present_s1}')
    print(f'#  groups one-sided at passes=1: {one_sided}')
    print(f'#  groups with NO passes=1 entry: {no_p1_at_all}')

    h1_ok = (absent_not_mono_s0 == 0 and absent_not_mono_s1 == 0 and
             mono_but_present_s0 == 0 and mono_but_present_s1 == 0)
    print(f'#  T266-H1: {"CONFIRMED" if h1_ok else "REFUTED"}')

    # --- T266-H2: pass-edge closure ---
    # (P, s, KO_NONE, 1) present <=> (P, 1-s, *, 0) present
    dropped_s0 = 0  # (P, side=1, *, 0) exists but (P, side=0, none, 1) missing
    dropped_s1 = 0
    orphan_s0 = 0   # (P, side=0, none, 1) exists but (P, side=1, *, 0) missing
    orphan_s1 = 0

    for g in range(n_groups):
        if has_s1p0[g] and not has_s0p1[g]:
            dropped_s0 += 1
        if has_s0p0[g] and not has_s1p1[g]:
            dropped_s1 += 1
        if not has_s1p0[g] and has_s0p1[g]:
            orphan_s0 += 1
        if not has_s0p0[g] and has_s1p1[g]:
            orphan_s1 += 1

    print(f'#  T266-H2 dropped pass edges: s0={dropped_s0} s1={dropped_s1}'
          f'  orphans: s0={orphan_s0} s1={orphan_s1}')
    h2_ok = (dropped_s0 == 0 and dropped_s1 == 0 and orphan_s0 == 0 and orphan_s1 == 0)
    print(f'#  T266-H2: {"CONFIRMED" if h2_ok else "REFUTED"}')

    # --- Stored-passes-1 accounting ---
    predicted_p1 = 2 * n_groups - (absent_s0 + absent_s1)
    print(f'#  stored passes=1: {total_p1}  predicted (2*n_groups - absences): {predicted_p1}'
          f'  match={total_p1 == predicted_p1}')

    print()
    return {
        'H1': 'CONFIRMED' if h1_ok else 'REFUTED',
        'H2': 'CONFIRMED' if h2_ok else 'REFUTED',
        'absent_s0': absent_s0,
        'absent_s1': absent_s1,
        'absent_not_mono_s0': absent_not_mono_s0,
        'absent_not_mono_s1': absent_not_mono_s1,
        'mono_but_present_s0': mono_but_present_s0,
        'mono_but_present_s1': mono_but_present_s1,
        'dropped_s0': dropped_s0,
        'dropped_s1': dropped_s1,
        'orphan_s0': orphan_s0,
        'orphan_s1': orphan_s1,
        'cb2_violations': cb2_violations,
        'cb3_ko_occupied': ko_on_occupied,
        'cb3_bad_ko_p1': bad_ko_p1,
        'cb4_bad_order': bad_order,
        'one_sided': one_sided,
        'mono_b': n_mono_b,
        'mono_w': n_mono_w,
        'total_p1': total_p1,
    }


# ---------------------------------------------------------------------------
# Point lookup — independent
# ---------------------------------------------------------------------------

def lookup_entry(data, colex_q, side, ko, passes):
    """Point lookup in a WZO2 artifact."""
    colex = data['colex']
    counts = data['counts']
    entries = data['entries']
    ko_bits = data['ko_bits']
    ko_none = data['ko_none']

    # Binary search for group
    lo, hi = 0, len(colex)
    while lo < hi:
        mid = (lo + hi) // 2
        if colex[mid] < colex_q:
            lo = mid + 1
        else:
            hi = mid
    if lo >= len(colex) or colex[lo] != colex_q:
        return None, 'group absent'

    g = lo
    start = sum(counts[:g])
    cnt = counts[g]
    target = (side << 1) | (ko << 2) | (passes << (2 + ko_bits))

    for i in range(start, start + cnt):
        kb = entries[i][0]
        if kb & 0xFE == target:
            return (entries[i][1], entries[i][2], entries[i][3], kb & 1), 'present'

    return None, f'group present ({cnt} entries) but key absent'


# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print('usage: python3 t277_verify.py <artifact.wzo2>...', file=sys.stderr)
        sys.exit(1)

    for path in sys.argv[1:]:
        data = read_wzo2(path)
        result = scan_artifact(data, path)
