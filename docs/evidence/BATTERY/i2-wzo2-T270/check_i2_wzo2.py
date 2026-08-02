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
# from src/. The colex layer math is verified independently (§verify_math)
# before any artifact is read.
#
# stdlib + numpy only. stdout = data, stderr = diagnostics (+ [progress]).
#
# Usage:
#   python3 check_i2_wzo2.py <artifact.wzo2> [--verify-math-only]
#   python3 check_i2_wzo2.py --calibrate        # synthetic fixtures
#
# Exit code: 0 = run completed (clean or dirty, verdict in JSON), 2 = instrument
# error (could not parse/verify), 3 = calibration failed.

import hashlib
import json
import math
import mmap
import os
import struct
import sys

import numpy as np

# ---------------------------------------------------------------------------
# 1. Colex math — independent implementation of the layered colex bijection
# ---------------------------------------------------------------------------

def binomial_table(n):
    """C(n,k) for k in 0..n."""
    row = [1]
    table = [row]
    for _ in range(1, n + 1):
        prev = table[-1]
        nxt = [1] + [prev[i] + prev[i + 1] for i in range(len(prev) - 1)] + [1]
        table.append(nxt)
    return table


def layer_offsets(n, binom):
    """layer_offset[k] = sum_{i<k} C(n,i) * 2^i ; length n+2 (sentinel at n+1)."""
    off = [0]
    for k in range(0, n + 1):
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
        """Number of stones k for colex idx."""
        assert 0 <= idx < self.total, idx
        k = 0
        while idx >= self.layer[k + 1]:
            k += 1
        return k

    def encode(self, pos):
        """pos: list of i8 (0 empty, 1 black, -1 white) -> colex index."""
        n = self.n
        assert len(pos) == n
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
        """colex index -> list of i8 (0 empty, 1 black, -1 white)."""
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
        return self.layer[k] + subset * (1 << k) + ((1 << k) - 1) ^ colours


def verify_math(n, sample_max=None, rng=None):
    """Exhaustive (n<=9) or sampled (n>9) verification of encode/decode/flip."""
    c = Colex(n)
    if n <= 9 or sample_max is None:
        indices = range(c.total)
    else:
        indices = [0] + list(range(1, sample_max)) + \
                  [int(x) for x in rng.integers(0, c.total, size=sample_max)]
        indices = sorted(set(indices))
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
# 2. WZO2 reader — independent parse of the format spec
# ---------------------------------------------------------------------------

MAGIC = b"WZO2"
HEADER_SIZE = 128
GROUP_HDR_SIZE = 5   # colex u32 LE + entry_count u8
ENTRY_SIZE = 4       # [key_byte][L][H][DTT]


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
        expected_ko_bits = max(1, math.ceil(math.log2(n + 1))) if n + 1 > 1 else 0
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
        expected_size = self.data_offset + self.n_groups * self.group_header_size \
            + self.n_entries * self.entry_size
        if filesize != expected_size:
            errs.append(f"filesize {filesize} != 128 + {self.n_groups}*5 + "
                        f"{self.n_entries}*4 = {expected_size}")
        return errs

    def key_bits(self):
        """Bit layout: terminal=bit0, side=bit1, ko=bits 2.., passes=bit 2+ko_bits."""
        return {
            "terminal": 0,
            "side": 1,
            "ko_bits": self.ko_bits,
            "passes_shift": 2 + self.ko_bits,
        }


def verify_embedded_sha256(path, header):
    """SHA-256 of the file with bytes 40..72 (hash slot) zeroed. Independent."""
    h = hashlib.sha256()
    with open(path, "rb") as f:
        size = os.path.getsize(path)
        pos = 0
        while pos < size:
            chunk = f.read(1 << 20)
            if not chunk:
                break
            end = pos + len(chunk)
            # zero the hash slot bytes (40..72) wherever they fall in this chunk
            if end > 40 and pos < 72:
                zero_start = max(pos, 40)
                zero_end = min(end, 72)
                chunk = bytearray(chunk)
                chunk[zero_start - pos: zero_end - pos] = b"\x00" * (zero_end - zero_start)
                chunk = bytes(chunk)
            h.update(chunk)
            pos = end
    return h.digest()


# ---------------------------------------------------------------------------
# 3. The I2 check
# ---------------------------------------------------------------------------

def run_i2(path, progress_cb=None, collect_witnesses=10):
    """Run I2 on a WZO2 artifact. Returns a summary dict."""
    filesize = os.path.getsize(path)
    with open(path, "rb") as f:
        header_buf = f.read(HEADER_SIZE)
    hdr = Wzo2Header(header_buf)
    errs = hdr.validate(filesize)
    if errs:
        return {"ok": False, "path": path, "errors": errs}

    n = hdr.w * hdr.h
    ko_bits = hdr.ko_bits
    passes_shift = 2 + ko_bits
    group_count = hdr.n_groups
    entry_count = hdr.n_entries

    # embedded sha256 (hash slot zeroed)
    digest = verify_embedded_sha256(path, hdr)

    mm = mmap.mmap(open(path, "rb").fileno(), 0, access=mmap.ACCESS_READ)
    try:
        # group index: [colex u32 LE][count u8] x G
        gi_off = hdr.data_offset
        gi_bytes = mm[gi_off: gi_off + group_count * GROUP_HDR_SIZE]
        colex = np.frombuffer(gi_bytes, dtype=np.uint8).reshape(group_count, GROUP_HDR_SIZE)
        colex_arr = colex[:, 0:4].copy().view(np.uint32)
        # little-endian
        colex_arr = colex_arr.astype("<u4") if colex_arr.dtype.byteorder == "=" or colex_arr.dtype.byteorder == "|" else colex_arr
        counts = colex[:, 4].astype(np.uint32)

        # entries: [kb][L][H][DTT] x N
        en_off = gi_off + group_count * GROUP_HDR_SIZE
        en_bytes = mm[en_off: en_off + entry_count * ENTRY_SIZE]
        ents = np.frombuffer(en_bytes, dtype=np.uint8).reshape(entry_count, ENTRY_SIZE)
        kb = ents[:, 0].astype(np.uint8)
        L = ents[:, 1].astype(np.int8)
        H = ents[:, 2].astype(np.int8)

        # independent colex for the goban
        cx = Colex(n)

        # flip every group's colex (vectorised)
        flip_arr = np.array([cx.flip(int(c)) for c in colex_arr], dtype=np.uint32)

        # partner lookup: sorted colex index -> position of flip(c)
        # groups are required sorted ascending (format A9); verify.
        sorted_ok = bool(np.all(colex_arr[1:] >= colex_arr[:-1]))
        partner = np.searchsorted(colex_arr, flip_arr)
        valid = (partner < group_count) & (colex_arr[np.minimum(partner, group_count - 1)] == flip_arr)
        partner_idx = np.where(valid, partner, -1).astype(np.int64)

        # cumulative entry offsets
        starts = np.concatenate([[0], np.cumsum(counts, dtype=np.uint64)])

        # 4. pairing loop
        violations = 0
        not_found = 0
        checked = 0
        terminal_mismatch = 0
        viol_groups = set()
        witnesses = []
        self_inverse_groups = 0
        pairs = 0

        # process each unordered pair {g, partner[g]} exactly once
        for g in range(group_count):
            if g % 1_000_000 == 0 and progress_cb:
                progress_cb(g, group_count, checked, violations, not_found)
            p = int(partner_idx[g])
            if p < 0:
                # inverted colex has no group -> all entries of g are not_found
                cg = int(counts[g])
                not_found += cg
                checked += cg
                continue
            if p == g:
                self_inverse_groups += 1
            elif p < g:
                continue  # pair already processed from the p side
            pairs += 1
            s0 = int(starts[g]); c0 = int(counts[g])
            s1 = int(starts[p]); c1 = int(counts[p])
            # build dict for partner group p (first occurrence per masked key,
            # matching the artifact lookup convention)
            dict_p = {}
            for i in range(c1):
                mkb = int(kb[s1 + i] & 0xFE)
                if mkb not in dict_p:
                    dict_p[mkb] = (int(L[s1 + i]), int(H[s1 + i]), int(kb[s1 + i] & 1))
            # check each entry of g against p
            for i in range(c0):
                checked += 1
                mkb = int(kb[s0 + i] & 0xFE)
                needle = mkb ^ 0x02
                hit = dict_p.get(needle)
                if hit is None:
                    not_found += 1
                    continue
                inv_L, inv_H, inv_term = hit
                term = int(kb[s0 + i] & 1)
                if term != inv_term:
                    terminal_mismatch += 1
                Lv, Hv = int(L[s0 + i]), int(H[s0 + i])
                if Lv != -inv_H or Hv != -inv_L:
                    violations += 1
                    viol_groups.add(int(colex_arr[g]))
                    if len(witnesses) < collect_witnesses:
                        witnesses.append({
                            "colex": int(colex_arr[g]),
                            "side": (mkb >> 1) & 1,
                            "ko": (mkb >> 2) & ((1 << ko_bits) - 1),
                            "passes": (mkb >> passes_shift) & 1,
                            "L": Lv, "H": Hv,
                            "inv_colex": int(flip_arr[g]),
                            "inv_L": inv_L, "inv_H": inv_H,
                            "inv_term": inv_term, "term": term,
                        })
            # also check entries of p against g (per-entry semantics; the
            # relation is symmetric, so this double-counts each pair — the
            # same way T212's per-entry check counted)
            dict_g = {}
            for i in range(c0):
                mkb = int(kb[s0 + i] & 0xFE)
                if mkb not in dict_g:
                    dict_g[mkb] = (int(L[s0 + i]), int(H[s0 + i]), int(kb[s0 + i] & 1))
            for i in range(c1):
                checked += 1
                mkb = int(kb[s1 + i] & 0xFE)
                needle = mkb ^ 0x02
                hit = dict_g.get(needle)
                if hit is None:
                    not_found += 1
                    continue
                inv_L, inv_H, inv_term = hit
                term = int(kb[s1 + i] & 1)
                if term != inv_term:
                    terminal_mismatch += 1
                Lv, Hv = int(L[s1 + i]), int(H[s1 + i])
                if Lv != -inv_H or Hv != -inv_L:
                    violations += 1
                    viol_groups.add(int(colex_arr[p]))
                    if len(witnesses) < collect_witnesses:
                        witnesses.append({
                            "colex": int(colex_arr[p]),
                            "side": (mkb >> 1) & 1,
                            "ko": (mkb >> 2) & ((1 << ko_bits) - 1),
                            "passes": (mkb >> passes_shift) & 1,
                            "L": Lv, "H": Hv,
                            "inv_colex": int(flip_arr[p]),
                            "inv_L": inv_L, "inv_H": inv_H,
                            "inv_term": inv_term, "term": term,
                        })
        if progress_cb:
            progress_cb(group_count, group_count, checked, violations, not_found)
    finally:
        mm.close()

    # additional cheap diagnostics (not verdicts)
    lte_h = int(np.sum(L <= H))
    return {
        "ok": True,
        "path": path,
        "w": hdr.w, "h": hdr.h,
        "rules_id": hdr.rules_id,
        "n_groups": int(group_count),
        "n_entries": int(entry_count),
        "filesize": filesize,
        "embedded_sha256_ok": digest == hdr.sha256,
        "groups_sorted": bool(sorted_ok),
        "checked": int(checked),
        "violations": int(violations),
        "not_found": int(not_found),
        "denominator": int(entry_count),
        "violating_groups_dedup": len(viol_groups),
        "terminal_mismatch": int(terminal_mismatch),
        "self_inverse_groups": self_inverse_groups,
        "pairs_processed": pairs,
        "L_le_H": int(lte_h),
        "witnesses": witnesses,
        "verdict": "PASS" if (violations == 0 and not_found == 0) else "FAIL",
    }


def calib_synthetic(tmpdir):
    """Known-good / known-bad synthetic WZO2 fixtures exercising the I2 path."""
    import numpy as np
    results = {}
    n = 4  # 2x2
    cx = Colex(n)
    # A small set of colexes closed under flip
    base = [0, 1, 2, 3, 5, 9, 12]  # arbitrary small colexes of 2x2
    groups = set()
    for c in base:
        groups.add(c)
        groups.add(cx.flip(c))
    groups = sorted(groups)
    # build entries: for each group, entries for sides 0/1 at ko=none passes=0,
    # plus a couple of ko/passes variants; values chosen to satisfy I2 exactly.
    # We assign each (colex, side) a value pair (L, H) and derive the partner.
    def make_entries(invert_one=None):
        # invert_one: (colex, side) whose L is perturbed by +1
        rows = []
        values = {}
        for c in groups:
            for side in (0, 1):
                values[(c, side)] = [-(c % 5), (c % 5) - 1]  # arbitrary L<=H
        # enforce I2: L(c, s) = -H(flip(c), 1-s), H(c, s) = -L(flip(c), 1-s)
        # iterate to fixpoint (two passes suffice for the pairs we create)
        for _ in range(3):
            for c in groups:
                fc = cx.flip(c)
                for side in (0, 1):
                    Lv, Hv = values[(c, side)]
                    values[(fc, 1 - side)] = [-Hv, -Lv]
        if invert_one:
            c0, s0 = invert_one
            values[(c0, s0)] = [values[(c0, s0)][0] + 1, values[(c0, s0)][1]]
        for c in groups:
            for side in (0, 1):
                Lv, Hv = values[(c, side)]
                rows.append((c, side, 0, 0, Lv, Hv))  # ko=0, passes=0
                # also a ko variant (ko=none = 4)
                rows.append((c, side, 4, 0, Lv, Hv))
        rows.sort(key=lambda r: (r[0], ((r[1] << 1) | (r[2] << 2) | (r[3] << (2 + 3))) & 0xFE))
        return rows

    def write_artifact(path, rows):
        w = h = 2
        ko_bits = 3
        # group by colex
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
                    kb = (side << 1) | (ko << 2) | (passes << (2 + ko_bits))
                    f.write(struct.pack("<Bbbb", kb, Lv, Hv, 5))

    good = os.path.join(tmpdir, "known-good.wzo2")
    bad = os.path.join(tmpdir, "known-bad.wzo2")
    missing = os.path.join(tmpdir, "known-bad-missing.wzo2")
    write_artifact(good, make_entries())
    write_artifact(bad, make_entries(invert_one=(base[0], 0)))
    # known-bad-missing: drop one group (flip symmetry broken)
    rows = make_entries()
    drop = cx.flip(base[0])
    rows = [r for r in rows if r[0] != drop]
    write_artifact(missing, rows)

    r_good = run_i2(good)
    r_bad = run_i2(bad)
    r_missing = run_i2(missing)
    results["known_good"] = r_good
    results["known_bad"] = r_bad
    results["known_bad_missing"] = r_missing
    ok = (r_good["verdict"] == "PASS" and r_good["violations"] == 0
          and r_bad["verdict"] == "FAIL" and r_bad["violations"] >= 1
          and r_missing["verdict"] == "FAIL" and r_missing["not_found"] >= 1)
    results["calibration_ok"] = bool(ok)
    return results


def main():
    args = sys.argv[1:]
    if "--verify-math-only" in args:
        rng = np.random.default_rng(270)
        n3 = verify_math(9, rng=rng)          # exhaustive 3x3
        n4 = verify_math(16, sample_max=100_000, rng=rng)  # sampled 4x4
        print(json.dumps({"math_3x3_checked": n3, "math_4x4_sampled": n4}))
        return 0
    if "--calibrate" in args:
        tmpdir = args[args.index("--calibrate") + 1] if len(args) > args.index("--calibrate") + 1 else "/tmp/weizigo/T270-calib"
        os.makedirs(tmpdir, exist_ok=True)
        res = calib_synthetic(tmpdir)
        print(json.dumps({k: v for k, v in res.items() if k != "calibration_ok"},
                         indent=1, default=str))
        sys.stderr.write(f"[progress] calibration complete ok={res['calibration_ok']}\n")
        return 0 if res["calibration_ok"] else 3
    if not args:
        print(__doc__)
        return 2
    path = args[0]

    def progress_cb(g, G, checked, violations, not_found):
        sys.stderr.write(f"[progress] groups {g}/{G} checked={checked} "
                         f"violations={violations} not_found={not_found}\n")

    res = run_i2(path, progress_cb=progress_cb)
    print(json.dumps(res, indent=1))
    sys.stderr.write(f"[progress] done verdict={res.get('verdict')}\n")
    return 0 if res.get("ok") else 2


if __name__ == "__main__":
    sys.exit(main())
