#!/usr/bin/env python3
"""DCLAIM chunk #3 — independent re-derivation of GLOBAL.S3a (Part A).

Claim under test — docs/epistemic/CLAIMS.md §2.1, row `GLOBAL.S3a` (PROVEN,
Tier B — committed prose only, no re-runnable probe):

    "The move/capture/suicide kernel is correct; OEIS A094777 attests the
     legal-position count and nothing more"

Re-derived assertion: the number of legal positions — Tromp-Taylor definition,
"legal = every chain has >= 1 liberty" (docs/research/enumeration-census.md) —
at each goban size equals the values the register asserts:

    1x1: 1, 2x2: 57, 3x2: 489, 3x3: 12675, 4x3: 321689, 4x4: 24318165

Square sizes 1x1/2x2/3x3/4x4 are asserted to equal OEIS A094777
(4x4.S3a row: "24,318,165 legal positions/side at 4x4 = OEIS A094777";
3x3.H1-CENSUS row: "OEIS A094777 known-good reproduced at 3x3: 12,675";
2x2/1x1 per src/enumerate.zig census, docs/research/enumeration-census.md).
4x3 = 321,689 is the project's own ground truth (A094777 is square-only;
4x3.S3a row caveat). 3x2 = 489 per docs/evidence/T13/verify-2026-07-30.log.

A legal position = every maximal connected group of same-colour stones has at
least one adjacent empty cell (liberty). A group with zero liberties cannot
arise in a game — the position-level statement of the suicide rule; this is
the part of the "move/capture/suicide kernel" that a position census attests.

Independence: written from scratch against that definition. Does not import,
link, or execute any weizigo source. Two independent legality predicates are
implemented and cross-checked exhaustively at 2x2 and 3x3:
  - legal_naive: literal per-group flood fill, trivially readable.
  - legal_fast:  bitmask formulation (dead stones = stones with no empty
    neighbour; a dead group exists iff some dead-connected component has no
    adjacent live same-colour stone).
The fast one is used for 4x3/4x4 where the naive one would take hours.

Usage: python3 probe_legal_count.py [size,size,...]
Exit 0 iff every asserted count is reproduced exactly (0 violations).
"""

import sys
import time

EXPECTED = {  # from the register rows cited above
    "1x1": 1,
    "2x2": 57,
    "3x2": 489,
    "3x3": 12675,
    "4x3": 321689,
    "4x4": 24318165,
}


def neighbor_masks(w, h):
    n = w * h
    nb = [0] * n
    for r in range(h):
        for c in range(w):
            i = r * w + c
            if r > 0:
                nb[i] |= 1 << (i - w)
            if r < h - 1:
                nb[i] |= 1 << (i + w)
            if c > 0:
                nb[i] |= 1 << (i - 1)
            if c < w - 1:
                nb[i] |= 1 << (i + 1)
    return nb


def adjacency_table(nb, n):
    """adjacency[mask] = union of the neighbours of every cell in mask."""
    tab = [0] * (1 << n)
    for m in range(1, 1 << n):
        lsb = m & -m
        tab[m] = tab[m ^ lsb] | nb[lsb.bit_length() - 1]
    return tab


# ---------------------------------------------------------------------------
# naive predicate — literal flood fill, written for readability
# ---------------------------------------------------------------------------
def legal_naive(black, white, w, h):
    n = w * h
    colours = [0] * n
    for i in range(n):
        if black >> i & 1:
            colours[i] = 1
        elif white >> i & 1:
            colours[i] = 2
    seen = [False] * n
    for start in range(n):
        if colours[start] == 0 or seen[start]:
            continue
        # flood-fill the group of `start`
        stack = [start]
        seen[start] = True
        cells = []
        while stack:
            j = stack.pop()
            cells.append(j)
            r, c = divmod(j, w)
            for dr, dc in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                rr, cc = r + dr, c + dc
                if 0 <= rr < h and 0 <= cc < w:
                    k = rr * w + cc
                    if not seen[k] and colours[k] == colours[j]:
                        seen[k] = True
                        stack.append(k)
        # liberties = adjacent empty cells
        has_liberty = False
        for j in cells:
            r, c = divmod(j, w)
            for dr, dc in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                rr, cc = r + dr, c + dc
                if 0 <= rr < h and 0 <= cc < w and colours[rr * w + cc] == 0:
                    has_liberty = True
        if not has_liberty:
            return False
    return True


# ---------------------------------------------------------------------------
# fast predicate — bitmask formulation
# ---------------------------------------------------------------------------
def legal_fast(black, white, adjtab, full):
    occ = black | white
    adj = adjtab[full ^ occ]          # cells adjacent to at least one empty cell
    for c in (black, white):
        dead = c & ~adj               # stones with no empty neighbour
        if not dead:
            continue
        livec = c & adj
        rem = dead
        while rem:
            seed = rem & -rem
            frontier = seed
            seen = seed
            while frontier:           # BFS through dead stones only
                nbr = 0
                f = frontier
                while f:
                    lsb = f & -f
                    nbr |= NEIGH_LOOKUP[lsb.bit_length() - 1]
                    f ^= lsb
                frontier = nbr & dead & ~seen
                seen |= frontier
            rem &= ~seen
            nbrc = 0
            f = seen
            while f:
                lsb = f & -f
                nbrc |= NEIGH_LOOKUP[lsb.bit_length() - 1]
                f ^= lsb
            if not (nbrc & livec):    # component has no live same-colour neighbour
                return False          # -> it IS a dead group -> position illegal
    return True


NEIGH_LOOKUP = []  # set per goban by count_legal_fast


# ---------------------------------------------------------------------------
# odometers
# ---------------------------------------------------------------------------
def count_legal_naive(w, h):
    n = w * h
    total = 3 ** n
    legal = 0
    for code in range(total):
        c = code
        black = 0
        white = 0
        for i in range(n):
            d = c % 3
            if d == 1:
                black |= 1 << i
            elif d == 2:
                white |= 1 << i
            c //= 3
        if legal_naive(black, white, w, h):
            legal += 1
    return legal


def chunk_tables(k):
    """black/white bitmasks for each base-3 code over k cells."""
    n3 = 3 ** k
    btab = [0] * n3
    wtab = [0] * n3
    for code in range(n3):
        c = code
        b = 0
        w = 0
        for i in range(k):
            d = c % 3
            if d == 1:
                b |= 1 << i
            elif d == 2:
                w |= 1 << i
            c //= 3
        btab[code] = b
        wtab[code] = w
    return btab, wtab


def count_legal_fast(w, h):
    global NEIGH_LOOKUP
    n = w * h
    nb = neighbor_masks(w, h)
    NEIGH_LOOKUP = nb
    full = (1 << n) - 1
    adjtab = adjacency_table(nb, n)
    k1 = n // 2
    k2 = n - k1
    b1, w1 = chunk_tables(k1)
    b2, w2 = chunk_tables(k2)
    n3_1 = 3 ** k1
    n3_2 = 3 ** k2
    legal = 0
    for c1 in range(n3_1):
        bb1 = b1[c1]
        ww1 = w1[c1]
        for c2 in range(n3_2):
            black = bb1 | (b2[c2] << k1)
            white = ww1 | (w2[c2] << k1)
            if legal_fast(black, white, adjtab, full):
                legal += 1
    return legal


def main():
    sizes = sys.argv[1:] if len(sys.argv) > 1 else sorted(EXPECTED, key=len)
    violations = []
    disagreements = 0
    for spec in sizes:
        w, h = spec.lower().split("x")
        w, h = int(w), int(h)
        t0 = time.time()
        if (w, h) in ((4, 3), (4, 4)):
            count = count_legal_fast(w, h)
        else:
            count = count_legal_naive(w, h)
        # cross-check fast vs naive where naive is cheap
        if (w, h) in ((2, 2), (3, 2), (3, 3), (1, 1)):
            cf = count_legal_fast(w, h)
            if cf != count:
                disagreements += 1
                print("INTERNAL DISAGREEMENT naive vs fast at %dx%d: %d vs %d"
                      % (w, h, count, cf))
        elapsed = time.time() - t0
        exp = EXPECTED.get(spec)
        ok = (exp is not None and count == exp)
        status = "OK" if ok else ("MISMATCH vs register" if exp is not None else "no register value")
        print("%s: legal = %d  register asserts %s  [%s, %.1fs]"
              % (spec, count, exp, status, elapsed))
        if not ok:
            violations.append((spec, count, exp))
    print()
    print("internal naive-vs-fast disagreements: %d" % disagreements)
    if violations:
        print("VIOLATIONS: %d" % len(violations))
        for v in violations:
            print("  %s: probe %s vs register %s" % (v[0], v[1], v[2]))
        return 1
    print("ALL ASSERTED COUNTS REPRODUCED — 0 violations / %d sizes" % len(sizes))
    return 0


if __name__ == "__main__":
    sys.exit(main())
