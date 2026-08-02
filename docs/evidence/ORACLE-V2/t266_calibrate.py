#!/usr/bin/env python3
"""
Task: T266 · Role: worker · Model: claude-opus-5 · Date: 2026-08-02

Calibration for t266_scan.py — the seeded-defect controls.

t266_scan.py reports ZERO violations on every counter for both shipped
artifacts. Per AGENTS.md ("impossibly clean counters are red flags") and
DELEGATEE.md ("a checker ships with a known-good it passes and a known-bad it
catches; without the second it proves nothing"), those readings do not count
until the instrument is shown to be able to fail.

Each mutant below is SYNTHETIC — a byte-patched copy of the 3x3 artifact in a
scratch directory, never live data — and targets exactly one counter. The
harness asserts:

  K0  null control      unmutated copy   -> every counter 0
  K1  dropped pass edge                  -> CB1_dropped_pass_edge_* > 0
  K2  spurious entry (monochrome law)    -> CB2_monochrome_law > 0
  K3  ko point on an occupied cell       -> CB3_ko_on_occupied_cell > 0
  K4  passes bit flipped (T193 replayed) -> CB3_passes1_ko_not_none or CB4 > 0
  K5  duplicate / mis-ordered key byte   -> CB4_order_or_dup > 0

A mutant that the scanner does not catch fails this harness loudly.

Usage:  python3 docs/evidence/ORACLE-V2/t266_calibrate.py <3x3.wzo2> <scratchdir>
"""
import os
import struct
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from t266_scan import scan, layer_offsets  # noqa: E402


def load(path):
    buf = bytearray(open(path, 'rb').read())
    n_groups = struct.unpack('<Q', buf[16:24])[0]
    n_entries = struct.unpack('<Q', buf[24:32])[0]
    ko_bits = buf[13]
    n = buf[6] * buf[7]
    gbase = 128
    ebase = 128 + 5 * n_groups
    colex = np.frombuffer(bytes(buf[gbase:ebase]), dtype=np.uint8).reshape(n_groups, 5)
    cx = (colex[:, 0].astype(np.int64) | (colex[:, 1].astype(np.int64) << 8)
          | (colex[:, 2].astype(np.int64) << 16) | (colex[:, 3].astype(np.int64) << 24))
    counts = colex[:, 4].astype(np.int64)
    starts = np.zeros(n_groups, dtype=np.int64)
    np.cumsum(counts[:-1], out=starts[1:])
    return buf, dict(n_groups=n_groups, n_entries=n_entries, ko_bits=ko_bits, n=n,
                     ebase=ebase, cx=cx, counts=counts, starts=starts)


def classify(m):
    """Per-group stone counts, from the colex index (see t266_scan.layer_offsets)."""
    off = layer_offsets(m['n'])
    k = np.searchsorted(off, m['cx'], side='right') - 1
    within = m['cx'] - off[k]
    cbits = within & ((np.int64(1) << k) - 1)
    black = np.zeros(len(k), dtype=np.int64)
    for b in range(m['n']):
        black += (cbits >> b) & 1
    return k, black, k - black


def kb_fields(kb, ko_bits):
    return ((kb >> (2 + ko_bits)) & 1, (kb >> 1) & 1, (kb >> 2) & ((1 << ko_bits) - 1))


def write(buf, path):
    with open(path, 'wb') as f:
        f.write(bytes(buf))
    return path


def mutants(src, out_dir):
    """Yield (name, path, expected_counter_keys)."""
    os.makedirs(out_dir, exist_ok=True)
    base, m = load(src)
    ko_bits, n, ebase = m['ko_bits'], m['n'], m['ebase']
    k, black, white = classify(m)

    yield 'K0-null-control', write(bytearray(base), f'{out_dir}/K0.wzo2'), []

    # --- K1: drop a pass edge. Pick a NON-monochrome group that has both
    # passes=1 entries; retarget the side=0 one onto side=1 (size-preserving),
    # so side=0's pass child vanishes while its pass parent stays.
    buf = bytearray(base)
    done = False
    for g in range(m['n_groups']):
        if k[g] < 1 or black[g] == 0 or white[g] == 0:
            continue
        s0 = m['starts'][g]
        idxs = range(int(s0), int(s0 + m['counts'][g]))
        p1s0 = [i for i in idxs if kb_fields(buf[ebase + 4 * i], ko_bits)[:2] == (1, 0)]
        p1s1 = [i for i in idxs if kb_fields(buf[ebase + 4 * i], ko_bits)[:2] == (1, 1)]
        if p1s0 and p1s1:
            buf[ebase + 4 * p1s0[0]] |= (1 << 1)   # side 0 -> 1
            done = True
            break
    assert done, 'K1: no candidate group found'
    yield ('K1-dropped-pass-edge', write(buf, f'{out_dir}/K1.wzo2'),
           ['CB1_dropped_pass_edge_s0', 'h1_absent_not_mono_s0'])

    # --- K2: spurious entry violating the monochrome-side law. On a
    # monochrome-BLACK group, retarget its (White-to-move, passes=0) entry to
    # Black-to-move: a state no White placement could ever have produced.
    buf = bytearray(base)
    done = False
    for g in range(m['n_groups']):
        if k[g] < 1 or white[g] != 0:
            continue
        s0 = m['starts'][g]
        for i in range(int(s0), int(s0 + m['counts'][g])):
            pa, sd, _ = kb_fields(buf[ebase + 4 * i], ko_bits)
            if pa == 0 and sd == 1:
                buf[ebase + 4 * i] &= ~(1 << 1) & 0xFF   # side 1 -> 0
                done = True
                break
        if done:
            break
    assert done, 'K2: no candidate group found'
    yield ('K2-monochrome-law', write(buf, f'{out_dir}/K2.wzo2'), ['CB2_monochrome_law'])

    # --- K3: ko point naming an OCCUPIED cell of its own goban.
    buf = bytearray(base)
    done = False
    for g in range(m['n_groups']):
        if k[g] < 1:
            continue
        # lowest occupied cell of this goban, from the colex subset
        from math import comb
        off = layer_offsets(n)
        within = int(m['cx'][g] - off[int(k[g])])
        subset = within >> int(k[g])
        rem, cell = subset, None
        for j in range(int(k[g]), 0, -1):
            c = j - 1
            while comb(c + 1, j) <= rem:
                c += 1
            rem -= comb(c, j)
            cell = c
        s0 = m['starts'][g]
        for i in range(int(s0), int(s0 + m['counts'][g])):
            pa, _, _ = kb_fields(buf[ebase + 4 * i], ko_bits)
            if pa == 0:
                kb = buf[ebase + 4 * i]
                kb &= ~(((1 << ko_bits) - 1) << 2) & 0xFF
                kb |= (cell & ((1 << ko_bits) - 1)) << 2
                buf[ebase + 4 * i] = kb
                done = True
                break
        if done:
            break
    assert done, 'K3: no candidate group found'
    yield ('K3-ko-on-occupied-cell', write(buf, f'{out_dir}/K3.wzo2'),
           ['CB3_ko_on_occupied_cell'])

    # --- K4: flip the passes bit on one passes=0 entry that carries a real ko
    # point. This is T193's defect replayed: the resulting passes=1 entry
    # violates the design's ko==KO_NONE invariant (§2.5).
    buf = bytearray(base)
    done = False
    for i in range(m['n_entries']):
        pa, _, ko = kb_fields(buf[ebase + 4 * i], ko_bits)
        if pa == 0 and ko != n:
            buf[ebase + 4 * i] |= 1 << (2 + ko_bits)
            done = True
            break
    assert done, 'K4: no candidate entry found'
    yield ('K4-passes-bit-flip', write(buf, f'{out_dir}/K4.wzo2'),
           ['CB3_passes1_ko_not_none'])

    # --- K5: duplicate key byte inside a group (breaks the sort contract).
    buf = bytearray(base)
    g = int(np.flatnonzero(m['counts'] >= 2)[0])
    s0 = int(m['starts'][g])
    buf[ebase + 4 * (s0 + 1)] = buf[ebase + 4 * s0]
    yield ('K5-duplicate-key', write(buf, f'{out_dir}/K5.wzo2'), ['CB4_order_or_dup'])


def main():
    src, out_dir = sys.argv[1], sys.argv[2]
    print(f'# T266 calibration — instrument: t266_scan.py  known-good: {src}')
    print(f'# mutants written to {out_dir} (synthetic; live artifacts untouched)')
    print()
    failures = 0
    for name, path, expect in mutants(src, out_dir):
        res = scan(path, quiet=True)
        nz = {kk: v for kk, v in res.items() if kk != 'H1' and v}
        if not expect:
            ok = not nz and res['H1'] == 'CONFIRMED'
            verdict = 'PASS (clean, as required)' if ok else f'FAIL — counters fired: {nz}'
        else:
            missed = [e for e in expect if not res.get(e)]
            ok = not missed
            verdict = (f'PASS (caught: {nz})' if ok
                       else f'FAIL — NOT CAUGHT by {missed}; fired: {nz}')
        failures += 0 if ok else 1
        print(f'{name:26s} -> {verdict}')
    print()
    summary = ('PASS — instrument catches every seeded defect' if failures == 0
               else f'FAIL — {failures} mutant(s) mishandled')
    print(f'# calibration: {summary}')
    sys.exit(1 if failures else 0)


if __name__ == '__main__':
    main()
