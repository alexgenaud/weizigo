#!/usr/bin/env python3
"""
Task: T277 · Role: worker · Model: deepseek-v4-pro · Date: 2026-08-02

Memory-efficient numpy-based 4x4 scan — independent of t266_scan.py.
"""
import sys
import struct
import numpy as np
from math import comb


def layer_offsets(n):
    off = [0]
    for k in range(n + 1):
        off.append(off[-1] + comb(n, k) * (2 ** k))
    return np.array(off, dtype=np.int64)


def scan_np(path):
    with open(path, 'rb') as f:
        hdr = f.read(128)
    w, h = hdr[6], hdr[7]
    ko_bits = hdr[13]
    n_groups = struct.unpack('<Q', hdr[16:24])[0]
    n_entries = struct.unpack('<Q', hdr[24:32])[0]
    n = w * h

    print(f'## {path}')
    print(f'#  {w}x{h}  ko_bits={ko_bits}  groups={n_groups}  entries={n_entries}')

    # Group index via memmap
    gi = np.memmap(path, dtype=np.uint8, mode='r', offset=128, shape=(n_groups, 5))
    colex = (gi[:, 0].astype(np.uint32) | (gi[:, 1].astype(np.uint32) << 8)
             | (gi[:, 2].astype(np.uint32) << 16) | (gi[:, 3].astype(np.uint32) << 24))
    counts = np.array(gi[:, 4], dtype=np.int64)
    del gi
    assert counts.sum() == n_entries
    assert np.all(np.diff(colex.astype(np.int64)) > 0)

    # Entry rows via memmap
    er = np.memmap(path, dtype=np.uint8, mode='r',
                   offset=128 + 5 * n_groups, shape=(n_entries, 4))
    kb = np.array(er[:, 0])
    del er

    # Decode key bytes
    passes_shift = 2 + ko_bits
    passes1 = ((kb >> passes_shift) & 1).astype(bool)
    passes0 = ~passes1
    side = (kb >> 1) & 1  # 0=Black to move
    ko_field = (kb >> 2) & ((1 << ko_bits) - 1)

    # Cumulative starts
    starts = np.zeros(n_groups, dtype=np.int64)
    np.cumsum(counts[:-1], out=starts[1:])

    # Per-group presence of each side/passes combo
    p1_s0 = (passes1 & (side == 0)).astype(np.int32)
    p1_s1 = (passes1 & (side == 1)).astype(np.int32)
    p0_s0 = (passes0 & (side == 0)).astype(np.int32)
    p0_s1 = (passes0 & (side == 1)).astype(np.int32)

    has_p1s0 = np.add.reduceat(p1_s0, starts) > 0
    has_p1s1 = np.add.reduceat(p1_s1, starts) > 0
    has_p0s0 = np.add.reduceat(p0_s0, starts) > 0
    has_p0s1 = np.add.reduceat(p0_s1, starts) > 0
    del p1_s0, p1_s1, p0_s0, p0_s1

    # Classify groups by goban content
    off = layer_offsets(n)
    k = np.searchsorted(off, colex.astype(np.int64), side='right') - 1
    within = colex.astype(np.int64) - off[k]
    colour_bits = within & ((np.int64(1) << k) - 1)

    # Count black stones per group via popcount of colour bits
    black = np.zeros(n_groups, dtype=np.int64)
    for b in range(n):
        black += (colour_bits >> b) & 1
    white = k - black

    mono_b = (k >= 1) & (white == 0)
    mono_w = (k >= 1) & (black == 0)
    empty = (k == 0)

    n_mono_b = int(np.count_nonzero(mono_b))
    n_mono_w = int(np.count_nonzero(mono_w))
    print(f'#  groups: empty={int(np.count_nonzero(empty))} mono-black={n_mono_b} mono-white={n_mono_w}')

    total_p0 = int(np.count_nonzero(passes0))
    total_p1 = int(np.count_nonzero(passes1))
    bad_ko_p1 = int(np.count_nonzero(passes1 & (ko_field != n)))
    print(f'#  entries: passes=0 {total_p0}  passes=1 {total_p1}')
    print(f'#  passes=1 with ko != KO_NONE({n}): {bad_ko_p1}')

    # C-B4: key byte ordering
    masked = (kb & 0xFE).astype(np.int32)
    step_ok = np.diff(masked) > 0
    at_boundary = np.zeros(n_entries - 1, dtype=bool)
    at_boundary[starts[1:] - 1] = True
    bad_order = int(np.count_nonzero(~(step_ok | at_boundary)))
    print(f'#  C-B4 mis-ordered: {bad_order}  (denom {n_entries - n_groups})')

    # C-B3: ko point on occupied cell
    p0_has_ko = passes0 & (ko_field != n)
    sel = np.flatnonzero(p0_has_ko)
    n_p0_ko = len(sel)
    gid = np.searchsorted(starts, sel, side='right') - 1

    # Unrank occupied cells per group (vectorised)
    subset_idx = (colex.astype(np.int64) - off[k]) >> k
    occ = np.zeros(n_groups, dtype=np.int64)
    rem = subset_idx.copy()
    for j in range(n, 0, -1):
        tbl = np.array([comb(c, j) for c in range(n + 1)], dtype=np.int64)
        c = np.searchsorted(tbl, rem, side='right') - 1
        act = k >= j
        occ |= np.where(act, np.int64(1) << c, 0)
        rem -= np.where(act, tbl[c], 0)

    ko_occupied = int(np.count_nonzero((occ[gid] >> ko_field[sel].astype(np.int64)) & 1))
    print(f'#  C-B3 ko-on-occupied: {ko_occupied}  (denom {n_p0_ko})')

    # C-B2: monochrome-side law
    p0_sel = np.flatnonzero(passes0)
    g0 = np.searchsorted(starts, p0_sel, side='right') - 1
    s0 = side[p0_sel]
    needs_white = (s0 == 0)
    viol = int(np.count_nonzero((needs_white & mono_b[g0]) | (~needs_white & mono_w[g0])))
    print(f'#  C-B2 monochrome-side violations: {viol}  (denom {total_p0})')

    # H1: absent_s0 <=> mono_w, absent_s1 <=> mono_b
    absent_s0 = ~has_p1s0
    absent_s1 = ~has_p1s1
    a_s0 = int(np.count_nonzero(absent_s0))
    a_s1 = int(np.count_nonzero(absent_s1))

    absent_not_mono_s0 = int(np.count_nonzero(absent_s0 & ~mono_w))
    absent_not_mono_s1 = int(np.count_nonzero(absent_s1 & ~mono_b))
    mono_but_present_s0 = int(np.count_nonzero(~absent_s0 & mono_w))
    mono_but_present_s1 = int(np.count_nonzero(~absent_s1 & mono_b))

    print(f'#  absent (s0,p1): {a_s0}  mono-w: {n_mono_w}  | absent-not-mono={absent_not_mono_s0}  mono-but-present={mono_but_present_s0}')
    print(f'#  absent (s1,p1): {a_s1}  mono-b: {n_mono_b}  | absent-not-mono={absent_not_mono_s1}  mono-but-present={mono_but_present_s1}')
    print(f'#  one-sided at passes=1: {int(np.count_nonzero(absent_s0 ^ absent_s1))}')

    h1_ok = (absent_not_mono_s0 == 0 and absent_not_mono_s1 == 0 and
             mono_but_present_s0 == 0 and mono_but_present_s1 == 0)
    print(f'#  T266-H1: {"CONFIRMED" if h1_ok else "REFUTED"}')

    # H2: pass-edge closure
    dropped_s0 = int(np.count_nonzero(has_p0s1 & ~has_p1s0))
    dropped_s1 = int(np.count_nonzero(has_p0s0 & ~has_p1s1))
    orphan_s0 = int(np.count_nonzero(~has_p0s1 & has_p1s0))
    orphan_s1 = int(np.count_nonzero(~has_p0s0 & has_p1s1))
    print(f'#  H2 dropped: s0={dropped_s0} s1={dropped_s1}  orphans: s0={orphan_s0} s1={orphan_s1}')
    h2_ok = (dropped_s0 == 0 and dropped_s1 == 0 and orphan_s0 == 0 and orphan_s1 == 0)
    print(f'#  T266-H2: {"CONFIRMED" if h2_ok else "REFUTED"}')

    missing_total = a_s0 + a_s1
    predicted = 2 * n_groups - missing_total
    print(f'#  missing passes=1 side-entries: {missing_total}  (denom {2 * n_groups})')
    print(f'#  stored passes=1: {total_p1}  predicted: {predicted}  match={total_p1 == predicted}')
    print()


if __name__ == '__main__':
    for p in sys.argv[1:]:
        scan_np(p)
