#!/usr/bin/env python3
"""
Task: T266 · Role: worker · Model: claude-opus-5 · Date: 2026-08-02

T266 — WZO2 passes=1 incompleteness: exhaustive classification.

Independent re-implementation of the WZO2 reader (deliberately in Python, not
Zig, per AGENTS.md "independent re-implementation is what finds defects").
Reads only the frozen byte format documented in src/artifact2.zig:19-34; it
shares no code with the builder or the consumer.

For EVERY group in the artifact (denominator = all n_groups, not a sample) it
answers two questions and cross-tabulates them:

  Q_a  which of {(side=0,passes=1), (side=1,passes=1)} is present?
  Q_b  is the group's goban MONOCHROME (all stones one colour, >=1 stone)?

The hypothesis under test (T266-H1):

  (P, side=s, passes=1) is absent  <=>  P is monochrome in colour(1-s)

Rationale: passes=1 states are produced only as the pass child of a passes=0
state, and genChildren4 sets pass_child = (board, 1-side, KO_NONE, passes+1)
(src/exp6_solve.zig:927). So (P, s, 1) is reachable iff (P, 1-s, ko, 0) is
reachable for some ko. A passes=0 state is entered ONLY by a placement (pass
always raises passes), and a placement by colour c leaves >=1 stone of colour c
on the goban (suicide is illegal). (P, side=1, 0) is entered by a BLACK
placement, so it requires >=1 black stone on P; (P, side=0, 0) requires >=1
white stone. The empty goban is the sole exception: it is a seed root for both
sides.

Usage:  python3 docs/evidence/ORACLE-V2/t266_scan.py <artifact.wzo2> ...
"""
import sys
import struct
import numpy as np


def layer_offsets(n):
    """colex layered-index offsets: offset[k] = # gobans with < k stones."""
    from math import comb
    off = [0]
    for k in range(n + 1):
        off.append(off[-1] + comb(n, k) * (2 ** k))
    return np.array(off, dtype=np.int64)  # len n+2


def scan(path, quiet=False):
    """Returns a dict of violation counters. Every counter is 0 on a
    well-formed artifact; the calibration harness (t266_calibrate.py) seeds a
    defect per counter and requires it to become non-zero."""
    def emit(msg=''):
        if not quiet:
            print(msg)

    with open(path, 'rb') as f:
        hdr = f.read(128)
    assert hdr[0:4] == b'WZO2', 'not a WZO2 file'
    w, h = hdr[6], hdr[7]
    ko_bits = hdr[13]
    n_groups = struct.unpack('<Q', hdr[16:24])[0]
    n_entries = struct.unpack('<Q', hdr[24:32])[0]
    n = w * h
    passes_shift = 2 + ko_bits

    emit(f'## {path}')
    emit(f'#  goban {w}x{h}  ko_bits={ko_bits}  n_groups={n_groups}  n_entries={n_entries}')

    gi = np.memmap(path, dtype=np.uint8, mode='r', offset=128, shape=(n_groups, 5))
    colex = (gi[:, 0].astype(np.uint32)
             | (gi[:, 1].astype(np.uint32) << 8)
             | (gi[:, 2].astype(np.uint32) << 16)
             | (gi[:, 3].astype(np.uint32) << 24))
    counts = np.array(gi[:, 4], dtype=np.int64)
    del gi
    assert counts.min() >= 1, 'empty group present'
    assert counts.sum() == n_entries, 'group counts do not sum to n_entries'
    assert np.all(np.diff(colex.astype(np.int64)) > 0), 'group index not strictly colex-sorted'

    er = np.memmap(path, dtype=np.uint8, mode='r',
                   offset=128 + 5 * n_groups, shape=(n_entries, 4))
    kb = np.array(er[:, 0])
    del er

    passes1 = ((kb >> passes_shift) & 1).astype(bool)
    side = ((kb >> 1) & 1)
    ko_field = (kb >> 2) & ((1 << ko_bits) - 1)

    starts = np.zeros(n_groups, dtype=np.int64)
    np.cumsum(counts[:-1], out=starts[1:])

    f_p1s0 = (passes1 & (side == 0)).astype(np.int32)
    f_p1s1 = (passes1 & (side == 1)).astype(np.int32)
    has_p1s0 = np.add.reduceat(f_p1s0, starts) > 0
    has_p1s1 = np.add.reduceat(f_p1s1, starts) > 0
    del f_p1s0, f_p1s1

    # ko invariant on passes=1 entries (design §2.5): ko must be KO_NONE == n
    bad_ko_p1 = int(np.count_nonzero(passes1 & (ko_field != n)))

    # ---- classify each group's goban from its colex index ----
    off = layer_offsets(n)
    k = np.searchsorted(off, colex.astype(np.int64), side='right') - 1
    within = colex.astype(np.int64) - off[k]
    colour_bits = within & ((np.int64(1) << k) - 1)
    black = np.zeros(n_groups, dtype=np.int64)
    for b in range(n):
        black += (colour_bits >> b) & 1
    white = k - black

    mono_b = (k >= 1) & (white == 0)   # only black stones
    mono_w = (k >= 1) & (black == 0)   # only white stones
    empty = (k == 0)

    miss_s0 = ~has_p1s0   # (P, side=0=Black to move, passes=1) absent
    miss_s1 = ~has_p1s1

    def tab(name, miss, pred, pred_name):
        both = int(np.count_nonzero(miss & pred))
        miss_only = int(np.count_nonzero(miss & ~pred))
        pred_only = int(np.count_nonzero(~miss & pred))
        emit(f'#  {name}: absent={int(np.count_nonzero(miss))}  {pred_name}={int(np.count_nonzero(pred))}'
              f'  |  agree={both}  absent-but-not-{pred_name}={miss_only}'
              f'  {pred_name}-but-present={pred_only}')
        return miss_only, pred_only

    emit(f'#  groups: total={n_groups} empty-goban={int(np.count_nonzero(empty))} '
          f'mono-black={int(np.count_nonzero(mono_b))} mono-white={int(np.count_nonzero(mono_w))}')
    emit(f'#  entries: passes=0 {int(np.count_nonzero(~passes1))}  passes=1 {int(np.count_nonzero(passes1))}')
    emit(f'#  passes=1 entries with ko != KO_NONE({n}): {bad_ko_p1}')
    emit(f'#  groups with NO passes=1 entry at all: '
          f'{int(np.count_nonzero(~has_p1s0 & ~has_p1s1))}')
    emit(f'#  groups one-sided at passes=1: '
          f'{int(np.count_nonzero(miss_s0 ^ miss_s1))}')

    # H1: (P, side=0, passes=1) absent  <=>  P monochrome WHITE
    #     (P, side=1, passes=1) absent  <=>  P monochrome BLACK
    a1, b1 = tab('(side=0,passes=1)', miss_s0, mono_w, 'mono-white')
    a2, b2 = tab('(side=1,passes=1)', miss_s1, mono_b, 'mono-black')

    verdict = 'CONFIRMED' if (a1 == 0 and b1 == 0 and a2 == 0 and b2 == 0) else 'REFUTED'
    emit(f'#  T266-H1 on this artifact: {verdict}')

    # counter-examples, if any, for the report
    if verdict == 'REFUTED':
        for lbl, sel in (('absent-not-mono s0', miss_s0 & ~mono_w),
                         ('mono-present s0', ~miss_s0 & mono_w),
                         ('absent-not-mono s1', miss_s1 & ~mono_b),
                         ('mono-present s1', ~miss_s1 & mono_b)):
            idx = np.flatnonzero(sel)[:5]
            for i in idx:
                emit(f'#    {lbl}: colex={colex[i]} k={k[i]} black={black[i]} white={white[i]}')

    # ---- T266-H2: was any PASS EDGE dropped? ----
    # The pass child of (P, 1-s, ko, 0) is (P, s, KO_NONE, 1). So if the census
    # enumerated pass edges for both sides, then for every group:
    #     (P, s, passes=1) present  <=>  (P, 1-s, ko, passes=0) present for some ko
    # A group where the passes=0 side-entry exists but its pass child does not
    # is a DROPPED PASS EDGE -- a builder defect, not correct absence.
    f_p0s0 = ((~passes1) & (side == 0)).astype(np.int32)
    f_p0s1 = ((~passes1) & (side == 1)).astype(np.int32)
    has_p0s0 = np.add.reduceat(f_p0s0, starts) > 0
    has_p0s1 = np.add.reduceat(f_p0s1, starts) > 0
    del f_p0s0, f_p0s1
    dropped_s0 = int(np.count_nonzero(has_p0s1 & ~has_p1s0))  # (P,W,·,0) exists, (P,B,none,1) missing
    dropped_s1 = int(np.count_nonzero(has_p0s0 & ~has_p1s1))
    orphan_s0 = int(np.count_nonzero(~has_p0s1 & has_p1s0))   # pass child with no pass parent
    orphan_s1 = int(np.count_nonzero(~has_p0s0 & has_p1s1))
    emit(f'#  T266-H2 dropped pass edges: side=0 {dropped_s0}  side=1 {dropped_s1}'
          f'   | orphaned passes=1 (no pass parent): side=0 {orphan_s0} side=1 {orphan_s1}')
    emit(f'#  T266-H2: {"CONFIRMED (no pass edge dropped)" if dropped_s0 == 0 and dropped_s1 == 0 else "REFUTED"}')

    # ---- C-B3 ko-field domain / C-B4 entry ordering (exact, whole artifact) ----
    # C-B4: masked key bytes must be STRICTLY increasing inside each group.
    # key_byte = [passes][ko][side][terminal], so numeric ascent == the format
    # contract's (passes, ko, side) sort, and strictness == no duplicate keys.
    masked = (kb & 0xFE).astype(np.int32)
    step_ok = np.diff(masked) > 0
    at_boundary = np.zeros(n_entries - 1, dtype=bool)
    at_boundary[starts[1:] - 1] = True
    bad_order = int(np.count_nonzero(~(step_ok | at_boundary)))
    emit(f'#  C-B4 entries mis-ordered or duplicated within a group: {bad_order}'
          f'   (denominator {n_entries - n_groups} intra-group steps)')

    # C-B3: a stored ko point must name an EMPTY cell of its own goban.
    # Unrank each group's occupied-cell set from its colex index (vectorised
    # combinatorial number system, src/colex.zig:127).
    from math import comb
    off_l = off[k]
    subset_idx = (colex.astype(np.int64) - off_l) >> k
    occ = np.zeros(n_groups, dtype=np.int64)  # bitmask of occupied cells
    rem = subset_idx.copy()
    for j in range(n, 0, -1):
        tbl = np.array([comb(c, j) for c in range(n + 1)], dtype=np.int64)
        c = np.searchsorted(tbl, rem, side='right') - 1
        act = k >= j
        occ |= np.where(act, np.int64(1) << c, 0)
        rem -= np.where(act, tbl[c], 0)
    assert int(np.count_nonzero(rem[k > 0])) == 0, 'colex unranking did not consume subset_idx'

    sel = np.flatnonzero((~passes1) & (ko_field != n))
    gid = np.searchsorted(starts, sel, side='right') - 1
    ko_occupied = int(np.count_nonzero((occ[gid] >> ko_field[sel].astype(np.int64)) & 1))
    emit(f'#  C-B3 passes=0 entries whose ko point is an OCCUPIED cell: {ko_occupied}'
          f'   (denominator {len(sel)} entries with ko != none)')

    # C-B2: (P, side=s, ., 0) requires >=1 stone of colour(1-s) on P, unless P empty.
    #       side_u1 0 = Black to move -> needs a WHITE stone; 1 -> needs a BLACK stone.
    p0 = np.flatnonzero(~passes1)
    g0 = np.searchsorted(starts, p0, side='right') - 1
    s0 = side[p0]
    needs_white = (s0 == 0)
    viol = np.count_nonzero(((needs_white & mono_b[g0]) | (~needs_white & mono_w[g0])))
    emit(f'#  C-B2 passes=0 entries violating the monochrome-side law: {int(viol)}'
          f'   (denominator {len(p0)} passes=0 entries)')
    del p0, g0, s0

    # missing side-entry total, the number T261 estimated at ~6.77M
    emit(f'#  MISSING side-entries at passes=1 (total): '
          f'{int(np.count_nonzero(miss_s0)) + int(np.count_nonzero(miss_s1))}')
    emit(f'#  denominator (2 x n_groups): {2 * n_groups}')
    emit()
    return {
        'H1': verdict,
        'h1_absent_not_mono_s0': a1, 'h1_mono_but_present_s0': b1,
        'h1_absent_not_mono_s1': a2, 'h1_mono_but_present_s1': b2,
        'CB1_dropped_pass_edge_s0': dropped_s0,
        'CB1_dropped_pass_edge_s1': dropped_s1,
        'CB1_orphan_s0': orphan_s0, 'CB1_orphan_s1': orphan_s1,
        'CB2_monochrome_law': int(viol),
        'CB3_ko_on_occupied_cell': ko_occupied,
        'CB3_passes1_ko_not_none': bad_ko_p1,
        'CB4_order_or_dup': bad_order,
    }


def lookup(path, colex_q, side_u1, ko, passes):
    """Point lookup, independent of src/artifact2.zig's binary search."""
    with open(path, 'rb') as f:
        hdr = f.read(128)
    ko_bits = hdr[13]
    n_groups = struct.unpack('<Q', hdr[16:24])[0]
    n_entries = struct.unpack('<Q', hdr[24:32])[0]
    gi = np.memmap(path, dtype=np.uint8, mode='r', offset=128, shape=(n_groups, 5))
    colex = (gi[:, 0].astype(np.uint32) | (gi[:, 1].astype(np.uint32) << 8)
             | (gi[:, 2].astype(np.uint32) << 16) | (gi[:, 3].astype(np.uint32) << 24))
    i = int(np.searchsorted(colex, np.uint32(colex_q)))
    if i >= n_groups or int(colex[i]) != colex_q:
        return None, 'group absent'
    counts = np.array(gi[:, 4], dtype=np.int64)
    start = int(counts[:i].sum())
    cnt = int(counts[i])
    er = np.memmap(path, dtype=np.uint8, mode='r',
                   offset=128 + 5 * n_groups, shape=(n_entries, 4))
    rows = np.array(er[start:start + cnt])
    target = (side_u1 << 1) | (ko << 2) | (passes << (2 + ko_bits))
    for r in rows:
        if int(r[0]) & 0xFE == target:
            return (np.int8(r[1]).item(), np.int8(r[2]).item(), int(r[3]),
                    int(r[0]) & 1), 'present'
    return None, f'group present ({cnt} entries) but key absent'


def pos_from_colex(idx, n):
    """Inverse of colex.Indexer(w,h).colex_from_pos -- see src/colex.zig:127."""
    from math import comb
    off = layer_offsets(n)
    k = int(np.searchsorted(off, idx, side='right')) - 1
    within = idx - int(off[k])
    subset_idx = within >> k
    colour_bits = within & ((1 << k) - 1)
    # unrank the combinatorial number system: c1<c2<...<ck, sum C(cj, j)
    cells = []
    rem = subset_idx
    for j in range(k, 0, -1):
        c = j - 1
        while comb(c + 1, j) <= rem:
            c += 1
        cells.append(c)
        rem -= comb(c, j)
    cells.reverse()
    pos = [0] * n
    for j, c in enumerate(cells):
        pos[c] = 1 if (colour_bits >> j) & 1 else -1
    return pos


def dump_group(path, colex_q):
    with open(path, 'rb') as f:
        hdr = f.read(128)
    w, h, ko_bits = hdr[6], hdr[7], hdr[13]
    n = w * h
    n_groups = struct.unpack('<Q', hdr[16:24])[0]
    n_entries = struct.unpack('<Q', hdr[24:32])[0]
    gi = np.memmap(path, dtype=np.uint8, mode='r', offset=128, shape=(n_groups, 5))
    colex = (gi[:, 0].astype(np.uint32) | (gi[:, 1].astype(np.uint32) << 8)
             | (gi[:, 2].astype(np.uint32) << 16) | (gi[:, 3].astype(np.uint32) << 24))
    i = int(np.searchsorted(colex, np.uint32(colex_q)))
    pos = pos_from_colex(colex_q, n)
    print(f'colex={colex_q}  {w}x{h}  goban (X=black O=white, cell 0 top-left, row-major):')
    for r in range(h):
        print('   ' + ' '.join('X' if pos[r * w + c] > 0 else 'O' if pos[r * w + c] < 0 else '.'
                               for c in range(w)))
    print(f'   black={sum(1 for x in pos if x > 0)} white={sum(1 for x in pos if x < 0)}')
    if i >= n_groups or int(colex[i]) != colex_q:
        print('   GROUP ABSENT')
        return
    counts = np.array(gi[:, 4], dtype=np.int64)
    start = int(counts[:i].sum())
    cnt = int(counts[i])
    er = np.memmap(path, dtype=np.uint8, mode='r',
                   offset=128 + 5 * n_groups, shape=(n_entries, 4))
    print(f'   {cnt} entries:')
    for r in np.array(er[start:start + cnt]):
        kb = int(r[0])
        sd = (kb >> 1) & 1
        ko = (kb >> 2) & ((1 << ko_bits) - 1)
        pa = (kb >> (2 + ko_bits)) & 1
        print(f'      side={sd}({"B" if sd == 0 else "W"}) ko={ko}'
              f'{" (none)" if ko == n else ""} passes={pa} term={kb & 1}'
              f'  L={np.int8(r[1]).item()} H={np.int8(r[2]).item()} DTT={int(r[3])}')


if __name__ == '__main__':
    if len(sys.argv) > 2 and sys.argv[1] == '--group':
        dump_group(sys.argv[2], int(sys.argv[3]))
        sys.exit(0)
    if len(sys.argv) > 2 and sys.argv[1] == '--lookup':
        # --lookup <file> <colex> <side_u1> <ko> <passes>
        p = sys.argv[2]
        cq, sd, ko, pa = (int(x) for x in sys.argv[3:7])
        res, why = lookup(p, cq, sd, ko, pa)
        print(f'lookup colex={cq} side_u1={sd}({"B" if sd == 0 else "W"}) ko={ko} '
              f'passes={pa} -> {why}' + (f'  L={res[0]} H={res[1]} DTT={res[2]} term={res[3]}'
                                         if res else ''))
        sys.exit(0)
    rc = 0
    for p in sys.argv[1:]:
        r = scan(p)
        if any(v for kk, v in r.items() if kk != 'H1') or r['H1'] != 'CONFIRMED':
            rc = 1
    sys.exit(rc)
