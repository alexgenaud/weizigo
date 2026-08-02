#!/usr/bin/env python3
# T270 — I2 colour-inversion check on WZO2 artifacts (independent re-implementation, R8)
#
# Task:    T270 · Role: worker · Model: deepseek-v4-flash · Date: 2026-08-02
# Brief:   untracked/T270-i2-on-wzo2.md
#
# Invariant (I2 / A3): for every stored entry (colex, side, ko, passes):
#     L(pos, side) == -H(inverted)  AND  H(pos, side) == -L(inverted)
# where inverted = (colour_flip(colex), 1-side, ko, passes).
#
# R8 independence: this module implements the WZO2 header parse, the colex
# bijection, colour flip, key-byte packing and the pairing loop from the
# format spec (docs/epic-01-markovian/sprints/oracle-v2/pass0/design-M1.md)
# and the invariant definition in DIRECTION.md §7.1/A3. It imports nothing
# from src/. Two independent implementations of the check itself:
#   * run_i2_reference — pure-Python per-group dict pairing
#   * run_i2_numpy     — vectorized composite-key searchsorted (chunked)
# They must agree on the 3x3 artifact and on synthetic fixtures; the numpy
# path then carries the 4x4 run.
#
# stdlib + numpy only. stdout = data, stderr = diagnostics (+ [progress]).
#
# Usage:
#   python3 check_i2_wzo2.py <artifact.wzo2> [--numpy|--reference]
#   python3 check_i2_wzo2.py --verify-math
#   python3 check_i2_wzo2.py --calibrate [tmpdir]
#
# Exit code: 0 = run completed (clean or dirty, verdict in JSON), 2 = instrument
# error, 3 = calibration failed.

import hashlib
import json
import math
import mmap
import os
import struct
import sys

import numpy as np

MAGIC = b"WZO2"
HEADER_SIZE = 128
GROUP_HDR_SIZE = 5   # colex u32 LE + entry_count u8
ENTRY_SIZE = 4       # [key_byte][L][H][DTT]


# ---------------------------------------------------------------------------
# 1. Colex math — independent layered-colex bijection
# ---------------------------------------------------------------------------

def binomial_table(n):
    """Rectangular (n+1)x(n+1) Pascal table: binom[i][j] = C(i,j) for j<=i else 0.
    The colex decode reads binom[cell][i+1] with cell possibly == i+1-1 == i,
    relying on C(i, i+1) = 0 as a sentinel."""
    table = [[0] * (n + 1) for _ in range(n + 1)]
    for i in range(n + 1):
        for j in range(i + 1):
            if j == 0 or j == i:
                table[i][j] = 1
            else:
                table[i][j] = table[i - 1][j - 1] + table[i - 1][j]
    return table


def layer_offsets(n, binom):
    off = [0]
    for k in range(n + 1):
        off.append(off[-1] + binom[n][k] * (1 << k))
    return off


class Colex:
    """Independent layered-colex encode/decode/flip for an n-cell goban."""

    def __init__(self, n):
        self.n = n
        self.binom = binomial_table(n)
        self.layer = layer_offsets(n, self.binom)
        self.total = 3 ** n
        assert self.layer[n + 1] == self.total, (n, self.layer[n + 1], self.total)

    def layer_of(self, idx):
        k = 0
        while idx >= self.layer[k + 1]:
            k += 1
        return k

    def encode(self, pos):
        n = self.n
        k = 0
        subset = 0
        colours = 0
        for cell in range(n):
            if pos[cell] == 0:
                continue
            if pos[cell] > 0:
                colours |= 1 << k
            k += 1
            subset += self.binom[cell][k]
        return self.layer[k] + subset * (1 << k) + colours

    def decode(self, idx):
        n = self.n
        k = self.layer_of(idx)
        layer_idx = idx - self.layer[k]
        subset = layer_idx >> k
        colours = layer_idx & ((1 << k) - 1)
        pos = [0] * n
        i = k
        while i > 0:
            i -= 1
            cell = n - 1
            while self.binom[cell][i + 1] > subset:
                cell -= 1
            subset -= self.binom[cell][i + 1]
            pos[cell] = 1 if (colours >> i) & 1 else -1
        return pos

    def flip(self, idx):
        """Colour-inverted colex: swap black<->white, same occupied cells."""
        k = self.layer_of(idx)
        if k == 0:
            return idx
        layer_idx = idx - self.layer[k]
        subset = layer_idx >> k
        colours = layer_idx & ((1 << k) - 1)
        return self.layer[k] + subset * (1 << k) + (((1 << k) - 1) ^ colours)

    def flip_vectorized(self, idx_arr):
        """Vectorised flip for a numpy array of colex indices."""
        a = np.asarray(idx_arr, dtype=np.uint64)
        layer = np.asarray(self.layer, dtype=np.uint64)
        k = (np.searchsorted(layer, a, side="right") - 1).astype(np.uint64)  # stones
        layer_k = layer[k]
        layer_idx = a - layer_k
        subset = layer_idx >> k
        mask = (np.uint64(1) << k) - np.uint64(1)
        colours = layer_idx & mask
        return layer_k + (subset << k) + (mask ^ colours)


def verify_math(n, sample_max=None, rng=None):
    """Exhaustive (n<=9) or sampled (n>9) verification of encode/decode/flip."""
    c = Colex(n)
    if n <= 9 or sample_max is None:
        indices = range(c.total)
    else:
        indices = sorted(set(
            [0, 1] + [int(x) for x in rng.integers(0, c.total, size=sample_max)]
        ))
    checked = 0
    for idx in indices:
        pos = c.decode(idx)
        assert c.encode(pos) == idx, (n, idx, c.encode(pos))
        swapped = [-p for p in pos]
        assert c.flip(idx) == c.encode(swapped), (n, idx, c.flip(idx), c.encode(swapped))
        assert c.flip(c.flip(idx)) == idx
        checked += 1
    return checked


# ---------------------------------------------------------------------------
# 2. WZO2 reader
# ---------------------------------------------------------------------------

class Wzo2Header:
    def __init__(self, buf):
        assert len(buf) >= HEADER_SIZE
        (magic, version, w, h, rules_id, entry_size, group_header_size,
         ko_bits, hdr_flags, reserved0, n_groups, n_entries, data_offset,
         sha256, reserved1) = struct.unpack("<4sHBBHHBBBBQQQ32s56s", buf)
        self.magic = magic
        self.version = version
        self.w = w
        self.h = h
        self.rules_id = rules_id
        self.entry_size = entry_size
        self.group_header_size = group_header_size
        self.ko_bits = ko_bits
        self.hdr_flags = hdr_flags
        self.n_groups = n_groups
        self.n_entries = n_entries
        self.data_offset = data_offset
        self.sha256 = sha256

    def validate(self, filesize):
        errs = []
        if self.magic != MAGIC:
            errs.append(f"magic {self.magic!r} != WZO2")
        if self.version != 1:
            errs.append(f"version {self.version} != 1")
        n = self.w * self.h
        expected_ko_bits = math.ceil(math.log2(n + 1))
        if self.entry_size != ENTRY_SIZE:
            errs.append(f"entry_size {self.entry_size} != 4")
        if self.group_header_size != GROUP_HDR_SIZE:
            errs.append(f"group_header_size {self.group_header_size} != 5")
        if self.ko_bits != expected_ko_bits:
            errs.append(f"ko_bits {self.ko_bits} != ceil(log2({n}+1)) = {expected_ko_bits}")
        if self.hdr_flags & 1 != 1:
            errs.append(f"hdr_flags bit0 (PASSES_2_OMITTED) = {self.hdr_flags & 1} != 1")
        if self.data_offset != HEADER_SIZE:
            errs.append(f"data_offset {self.data_offset} != 128")
        expected_size = (self.data_offset + self.n_groups * self.group_header_size
                         + self.n_entries * self.entry_size)
        if filesize != expected_size:
            errs.append(f"filesize {filesize} != 128 + {self.n_groups}*5 + "
                        f"{self.n_entries}*4 = {expected_size}")
        return errs


def verify_embedded_sha256(path, header):
    """SHA-256 of the file with bytes 40..72 (hash slot) zeroed."""
    h = hashlib.sha256()
    size = os.path.getsize(path)
    with open(path, "rb") as f:
        pos = 0
        while pos < size:
            chunk = f.read(1 << 20)
            if not chunk:
                break
            end = pos + len(chunk)
            if end > 40 and pos < 72:
                zs, ze = max(pos, 40), min(end, 72)
                chunk = bytearray(chunk)
                chunk[zs - pos: ze - pos] = b"\x00" * (ze - zs)
                chunk = bytes(chunk)
            h.update(chunk)
            pos = end
    return h.digest()


def load_artifact(path):
    """Parse header + group index + entries into numpy arrays. Raises on error."""
    filesize = os.path.getsize(path)
    with open(path, "rb") as f:
        hdr = Wzo2Header(f.read(HEADER_SIZE))
    errs = hdr.validate(filesize)
    if errs:
        raise ValueError("header validation failed: " + "; ".join(errs))
    n = hdr.w * hdr.h
    mm = mmap.mmap(os.open(path, os.O_RDONLY), 0, access=mmap.ACCESS_READ)
    gi_off = hdr.data_offset
    gi = np.frombuffer(mm, dtype=np.uint8,
                       count=hdr.n_groups * GROUP_HDR_SIZE, offset=gi_off) \
             .reshape(hdr.n_groups, GROUP_HDR_SIZE)
    colex = gi[:, 0:4].copy().view("<u4").reshape(-1).astype(np.uint32)
    counts = gi[:, 4].astype(np.uint32)
    en_off = gi_off + hdr.n_groups * GROUP_HDR_SIZE
    ents = np.frombuffer(mm, dtype=np.uint8,
                         count=hdr.n_entries * ENTRY_SIZE, offset=en_off) \
             .reshape(hdr.n_entries, ENTRY_SIZE)
    return hdr, colex, counts, ents, mm


# ---------------------------------------------------------------------------
# 3. The I2 check — reference implementation (pure Python)
# ---------------------------------------------------------------------------

def run_i2_reference(hdr, colex, counts, ents, collect_witnesses=10, progress_cb=None,
                     limit_groups=None):
    """Per-group dict pairing. Per-entry semantics: each stored entry is
    checked exactly once; its inverse is looked up by masked key (terminal
    bit cleared, matching the artifact lookup convention)."""
    n = hdr.w * hdr.h
    ko_bits = hdr.ko_bits
    passes_shift = 2 + ko_bits
    G = hdr.n_groups
    starts = np.concatenate([[0], np.cumsum(counts, dtype=np.uint64)])
    kb = ents[:, 0]
    L = ents[:, 1].astype(np.int8)
    H = ents[:, 2].astype(np.int8)
    cx = Colex(n)
    flip_arr = cx.flip_vectorized(colex)
    # partner lookup (groups must be sorted ascending by colex; verified by caller)
    partner = np.searchsorted(colex, flip_arr)
    valid = (partner < G) & (colex[np.minimum(partner, G - 1)] == flip_arr)
    partner_idx = np.where(valid, partner, -1).astype(np.int64)

    checked = 0
    violations = 0
    not_found = 0
    terminal_mismatch = 0
    viol_groups = set()
    witnesses = []
    self_inverse = 0
    pairs = 0
    partner_missing = 0
    limit = limit_groups

    def check_entries(s, c, other_dict, g_colex, inv_colex):
        """Check entries [s, s+c) against other_dict (masked kb -> (L,H,term))."""
        nonlocal checked, violations, not_found, terminal_mismatch, witnesses
        for i in range(c):
            checked += 1
            mkb = int(kb[s + i] & 0xFE)
            hit = other_dict.get(mkb ^ 0x02)
            term = int(kb[s + i] & 1)
            if hit is None:
                not_found += 1
                continue
            inv_L, inv_H, inv_term = hit
            if term != inv_term:
                terminal_mismatch += 1
            Lv, Hv = int(L[s + i]), int(H[s + i])
            if Lv != -inv_H or Hv != -inv_L:
                violations += 1
                viol_groups.add(g_colex)
                if len(witnesses) < collect_witnesses:
                    witnesses.append(dict(
                        colex=g_colex, side=(mkb >> 1) & 1,
                        ko=(mkb >> 2) & ((1 << ko_bits) - 1),
                        passes=(mkb >> passes_shift) & 1, L=Lv, H=Hv,
                        inv_colex=inv_colex,
                        inv_L=inv_L, inv_H=inv_H, inv_term=inv_term, term=term))

    def build_dict(s, c):
        d = {}
        for i in range(c):
            mkb = int(kb[s + i] & 0xFE)
            if mkb not in d:
                d[mkb] = (int(L[s + i]), int(H[s + i]), int(kb[s + i] & 1))
        return d

    for g in range(G if limit is None else min(limit, G)):
        if g % 250_000 == 0 and progress_cb:
            progress_cb(g, G, checked, violations, not_found)
        p = int(partner_idx[g])
        if limit is not None and p >= min(limit, G):
            # inverse lies outside the sampled window -> count as not_found,
            # matching the numpy path's windowed searchsorted semantics
            cg = int(counts[g])
            not_found += cg
            checked += cg
            continue
        if p < 0:
            partner_missing += 1
            cg = int(counts[g])
            not_found += cg
            checked += cg
            continue
        if p == g:
            self_inverse += 1
            pairs += 1
            s0, c0 = int(starts[g]), int(counts[g])
            d = build_dict(s0, c0)
            check_entries(s0, c0, d, int(colex[g]), int(flip_arr[g]))
            continue
        if p < g:
            continue  # pair already processed from the partner side
        pairs += 1
        s0, c0 = int(starts[g]), int(counts[g])
        s1, c1 = int(starts[p]), int(counts[p])
        d_p = build_dict(s1, c1)
        check_entries(s0, c0, d_p, int(colex[g]), int(flip_arr[g]))
        d_g = build_dict(s0, c0)
        check_entries(s1, c1, d_g, int(colex[p]), int(flip_arr[p]))

    return dict(
        checked=int(checked), violations=int(violations), not_found=int(not_found),
        violating_groups_dedup=len(viol_groups),
        terminal_mismatch=int(terminal_mismatch),
        self_inverse_groups=int(self_inverse),
        partner_missing_groups=int(partner_missing),
        pairs_processed=int(pairs),
        witnesses=witnesses,
        verdict="PASS" if (violations == 0 and not_found == 0) else "FAIL",
    )


# ---------------------------------------------------------------------------
# 4. The I2 check — vectorized implementation (numpy, chunked)
# ---------------------------------------------------------------------------

def run_i2_numpy(hdr, colex, counts, ents, collect_witnesses=10, progress_cb=None,
                 limit_groups=None):
    """Vectorised check via composite keys, chunked over groups to bound memory.

    Global entry key: comp = (colex << 8) | (kb & 0xFE). Entries are sorted by
    (colex, kb & 0xFE) in the artifact (format A9), so comp is globally sorted.
    The inverse of entry (colex c, masked key m) is (flip(c), m ^ 0x02), since
    bit 1 is the side and terminal is masked off. searchsorted(side='left')
    reproduces the first-match lookup convention of the artifact.
    """
    n = hdr.w * hdr.h
    ko_bits = hdr.ko_bits
    passes_shift = 2 + ko_bits
    G = hdr.n_groups
    N = hdr.n_entries

    kb = ents[:, 0]
    L = ents[:, 1].astype(np.int8)
    H = ents[:, 2].astype(np.int8)
    masked = (kb & 0xFE).astype(np.uint8)

    lim = G if limit_groups is None else min(limit_groups, G)
    N = int(hdr.n_entries)
    # count entries in the sampled window
    if lim < G:
        N = int(np.sum(counts[:lim]))

    # global sorted composite key array (format A9 guarantees order), built
    # chunk-wise so no full-size np.repeat intermediate ever exists:
    #   comp[entry] = (colex << 8) | (kb & 0xFE)
    starts = np.concatenate([[0], np.cumsum(counts, dtype=np.uint64)]).astype(np.uint32)
    comp = np.empty(int(N), dtype=np.uint64)
    CHUNK_G = 2_000_000
    for g0 in range(0, lim, CHUNK_G):
        g1 = min(g0 + CHUNK_G, lim)
        e0, e1 = int(starts[g0]), int(starts[g1])
        part = np.repeat(colex[g0:g1].astype(np.uint64) << 8, counts[g0:g1])
        part |= masked[e0:e1].astype(np.uint64)
        comp[e0:e1] = part
    sorted_ok = bool(np.all(comp[1:] >= comp[:-1]))
    if not sorted_ok:
        # do not trust searchsorted on an unsorted array; fall back to a
        # slower but order-independent method (per-group set membership)
        return run_i2_reference(hdr, colex, counts, ents,
                                collect_witnesses=collect_witnesses,
                                progress_cb=progress_cb,
                                limit_groups=limit_groups) | {"comp_sorted": False}

    cx = Colex(n)

    violations = 0
    not_found = 0
    terminal_mismatch = 0
    viol_groups = set()
    witnesses = []
    self_inverse = 0

    # process groups in chunks so transient arrays stay small
    for g0 in range(0, lim, CHUNK_G):
        g1 = min(g0 + CHUNK_G, lim)
        e0 = int(starts[g0])
        e1 = int(starts[g1])
        flip_chunk = cx.flip_vectorized(colex[g0:g1])
        self_inverse += int(np.count_nonzero(flip_chunk == colex[g0:g1]))
        sub = np.repeat(np.arange(g1 - g0, dtype=np.uint32), counts[g0:g1])
        inv_comp = (flip_chunk[sub].astype(np.uint64) << 8) | \
                   (masked[e0:e1].astype(np.uint64) ^ 0x02)
        del flip_chunk
        pos = np.searchsorted(comp, inv_comp, side="left")
        found = (pos < N) & (comp[np.minimum(pos, N - 1)] == inv_comp)
        not_found += int(np.count_nonzero(~found))
        subL = L[e0:e1]
        subH = H[e0:e1]
        hit_L = np.zeros(e1 - e0, dtype=np.int8)
        hit_H = np.zeros(e1 - e0, dtype=np.int8)
        term_hit = np.zeros(e1 - e0, dtype=np.int8)
        if np.any(found):
            hit_L[found] = L[np.minimum(pos[found], N - 1)]
            hit_H[found] = H[np.minimum(pos[found], N - 1)]
            term_hit[found] = (kb[np.minimum(pos[found], N - 1)] & 1).astype(np.int8)
        bad = found & ((subL != -hit_H) | (subH != -hit_L))
        violations += int(np.count_nonzero(bad))
        if np.any(bad):
            for c_ in np.unique(colex[g0:g1][sub[bad]]):
                viol_groups.add(int(c_))
            if len(witnesses) < collect_witnesses:
                for ii in np.flatnonzero(bad)[:collect_witnesses]:
                    i = int(ii)
                    mkb = int(masked[e0 + i])
                    pi = int(pos[i])
                    witnesses.append(dict(
                        colex=int(colex[g0:g1][sub[i]]), side=(mkb >> 1) & 1,
                        ko=(mkb >> 2) & ((1 << ko_bits) - 1),
                        passes=(mkb >> passes_shift) & 1,
                        L=int(subL[i]), H=int(subH[i]),
                        inv_colex=int(cx.flip(int(colex[g0:g1][sub[i]]))),
                        inv_L=int(hit_L[i]), inv_H=int(hit_H[i]),
                        inv_term=int(term_hit[i]), term=int(kb[e0 + i] & 1)))
        # terminal mismatches (only where inverse found)
        term_self = (kb[e0:e1] & 1).astype(np.int8)
        terminal_mismatch += int(np.count_nonzero(found & (term_self != term_hit)))
        if progress_cb:
            progress_cb(g1, lim, e1, violations, not_found)

    return dict(
        checked=int(N), violations=violations, not_found=not_found,
        violating_groups_dedup=len(viol_groups),
        terminal_mismatch=terminal_mismatch,
        self_inverse_groups=int(self_inverse),
        comp_sorted=sorted_ok,
        witnesses=witnesses,
        verdict="PASS" if (violations == 0 and not_found == 0) else "FAIL",
    )


# ---------------------------------------------------------------------------
# 5. Driver
# ---------------------------------------------------------------------------

def run_i2(path, impl="both", progress_cb=None, limit_groups=None):
    filesize = os.path.getsize(path)
    hdr, colex, counts, ents, mm = load_artifact(path)
    try:
        G = hdr.n_groups
        groups_sorted = bool(np.all(colex[1:] >= colex[:-1]))
        n = hdr.w * hdr.h
        L = ents[:, 1].astype(np.int8)
        H = ents[:, 2].astype(np.int8)
        lte_h = int(np.count_nonzero(L <= H))
        score_range_ok = bool(np.all((L >= -n) & (L <= n) & (H >= -n) & (H <= n)))
        ko_bits = hdr.ko_bits
        passes_shift = 2 + ko_bits
        kb = ents[:, 0]
        ko_field = (kb >> 2) & ((1 << ko_bits) - 1)
        passes_field = (kb >> passes_shift) & 1
        passes_ko_ok = bool(np.all((passes_field == 0) | (ko_field == n)))
        unused_mask = (0xFF << (passes_shift + 1)) & 0xFF
        unused_ok = bool(np.all((kb & unused_mask) == 0)) if unused_mask else True

        res = {
            "ok": True,
            "path": path,
            "w": hdr.w, "h": hdr.h,
            "rules_id": hdr.rules_id,
            "n_groups": int(G),
            "n_entries": int(hdr.n_entries),
            "filesize": filesize,
            "groups_sorted": groups_sorted,
            "embedded_sha256_ok": verify_embedded_sha256(path, hdr) == hdr.sha256,
            "L_le_H": int(lte_h),
            "score_range_ok": bool(score_range_ok),
            "passes_ko_invariant_ok": bool(passes_ko_ok),
            "unused_key_bits_zero": bool(unused_ok),
            "denominator": int(hdr.n_entries),
        }

        ref = run_i2_reference(hdr, colex, counts, ents, progress_cb=progress_cb,
                               limit_groups=limit_groups) \
            if impl in ("both", "reference") else None
        vec = run_i2_numpy(hdr, colex, counts, ents, limit_groups=limit_groups) \
            if impl in ("both", "numpy") else None

        if ref is not None and vec is not None:
            agree = (ref["violations"] == vec["violations"]
                     and ref["not_found"] == vec["not_found"]
                     and ref["checked"] == vec["checked"])
            res["impl_agreement"] = bool(agree)
            if not agree:
                res["impl_disagreement"] = {
                    "reference": {k: ref[k] for k in ("checked", "violations", "not_found")},
                    "numpy": {k: vec[k] for k in ("checked", "violations", "not_found")},
                }
        res["reference"] = ref
        res["numpy"] = vec
        res["verdict"] = (ref or vec)["verdict"]
        return res
    finally:
        try:
            mm.close()
        except BufferError:
            pass  # numpy views still reference the mmap; process exits anyway


def calib_synthetic(tmpdir):
    """Known-good / known-bad synthetic WZO2 fixtures exercising the I2 path."""
    n = 4  # 2x2
    cx = Colex(n)
    base = [0, 1, 2, 3, 5, 9, 12]
    groups = set()
    for c in base:
        groups.add(c)
        groups.add(int(cx.flip(c)))
    groups = sorted(groups)

    def make_entries(invert_one=None, drop_group=None):
        values = {}
        for c in groups:
            for side in (0, 1):
                values[(c, side)] = [-(c % 5), (c % 5) - 1]
        for _ in range(3):
            for c in groups:
                fc = int(cx.flip(c))
                for side in (0, 1):
                    Lv, Hv = values[(c, side)]
                    values[(fc, 1 - side)] = [-Hv, -Lv]
        if invert_one:
            c0, s0 = invert_one
            values[(c0, s0)][0] += 1
        rows = []
        for c in groups:
            for side in (0, 1):
                Lv, Hv = values[(c, side)]
                rows.append((c, side, 0, 0, Lv, Hv))  # ko=0
                rows.append((c, side, 4, 0, Lv, Hv))  # ko=none=4
        if drop_group is not None:
            rows = [r for r in rows if r[0] != drop_group]
        rows.sort(key=lambda r: (r[0], ((r[1] << 1) | (r[2] << 2) | (r[3] << 5)) & 0xFE))
        return rows

    def write_artifact(path, rows):
        w = h = 2
        ko_bits = 3
        from collections import OrderedDict
        grouped = OrderedDict()
        for r in rows:
            grouped.setdefault(r[0], []).append(r)
        colexes = sorted(grouped.keys())
        n_groups = len(colexes)
        n_entries = len(rows)
        filesize = HEADER_SIZE + n_groups * GROUP_HDR_SIZE + n_entries * ENTRY_SIZE
        hdr = struct.pack(
            "<4sHBBHHBBBBQQQ32s56s",
            MAGIC, 1, w, h, 3, ENTRY_SIZE, GROUP_HDR_SIZE, ko_bits,
            1, 0, n_groups, n_entries, HEADER_SIZE,
            b"\x00" * 32, b"\x00" * 56,
        )
        with open(path, "wb") as f:
            f.write(hdr)
            for c in colexes:
                f.write(struct.pack("<IB", c, len(grouped[c])))
            for c in colexes:
                for (cc, side, ko, passes, Lv, Hv) in grouped[c]:
                    kb = (side << 1) | (ko << 2) | (passes << 5)
                    f.write(struct.pack("<Bbbb", kb, Lv, Hv, 5))

    good = os.path.join(tmpdir, "known-good.wzo2")
    bad = os.path.join(tmpdir, "known-bad.wzo2")
    missing = os.path.join(tmpdir, "known-bad-missing.wzo2")
    write_artifact(good, make_entries())
    write_artifact(bad, make_entries(invert_one=(base[0], 0)))
    # drop the partner group of base[1] (flip(1)=2), breaking flip closure
    write_artifact(missing, make_entries(drop_group=int(cx.flip(base[1]))))

    r_good = run_i2(good, impl="both")
    r_bad = run_i2(bad, impl="both")
    r_missing = run_i2(missing, impl="both")
    ok = (r_good["verdict"] == "PASS" and r_good["reference"]["violations"] == 0
          and r_bad["verdict"] == "FAIL" and r_bad["reference"]["violations"] >= 1
          and r_missing["verdict"] == "FAIL" and r_missing["reference"]["not_found"] >= 1
          and r_good["impl_agreement"] and r_bad["impl_agreement"]
          and r_missing["impl_agreement"])
    return {"known_good": r_good, "known_bad": r_bad,
            "known_bad_missing": r_missing, "calibration_ok": bool(ok)}


def main():
    args = sys.argv[1:]
    if "--verify-math" in args:
        rng = np.random.default_rng(270)
        n3 = verify_math(9, rng=rng)
        n4 = verify_math(16, sample_max=200_000, rng=rng)
        print(json.dumps({"math_3x3_checked": n3, "math_4x4_sampled": n4}))
        return 0
    if "--calibrate" in args:
        idx = args.index("--calibrate")
        tmpdir = args[idx + 1] if len(args) > idx + 1 else "/tmp/weizigo/T270-calib"
        os.makedirs(tmpdir, exist_ok=True)
        res = calib_synthetic(tmpdir)
        sys.stderr.write(f"[progress] calibration ok={res['calibration_ok']}\n")
        print(json.dumps({k: v for k, v in res.items() if k != "calibration_ok"},
                         indent=1, default=str))
        return 0 if res["calibration_ok"] else 3
    if not args or all(a.startswith('--') for a in args):
        print(__doc__)
        return 2
    impl = "both"
    path = None
    limit_groups = None
    for a in args:
        if a == "--numpy":
            impl = "numpy"
        elif a == "--reference":
            impl = "reference"
        elif a.startswith("--limit-groups="):
            limit_groups = int(a.split("=", 1)[1])
        elif not a.startswith("--") and path is None:
            path = a

    def progress_cb(g, G, checked, violations, not_found):
        sys.stderr.write(f"[progress] groups {g}/{G} checked={checked} "
                         f"violations={violations} not_found={not_found}\n")

    res = run_i2(path, impl=impl, progress_cb=progress_cb, limit_groups=limit_groups)
    print(json.dumps(res, indent=1))
    sys.stderr.write(f"[progress] done verdict={res.get('verdict')}\n")
    return 0 if res.get("ok") else 2


if __name__ == "__main__":
    sys.exit(main())
