#!/usr/bin/env python3
"""
T13 probe v2 — independent Python re-implementation.

Model/Worker: Kimi-k2.7 / T118
Date: 2026-07-30

Reconstructs the T13 C2 falsification experiment at 3×2 from the method
description in docs/research/c2-falsification-3x2.md and the surrounding
documentation (docs/epistemic/PROGRESS.md, docs/epistemic/CLAIMS.md).

This script is intentionally self-contained and does NOT import any project
engine code.  It implements from scratch:
  * the 3×2 Tromp-Taylor rules (move/capture/suicide, area score,
    Benson unconditional life, settled-terminal test, ADR-0006 eye-prune),
  * the layered colex bijection used by the .wzo format,
  * the ADR-0009 retrograde L/H value-iteration engine,
  * a no-memo, no-bracket, eye-pruned PSK alpha-beta solver,
  * enumeration of short PSK histories and comparison against the stored
    L==H fresh-start values.

Run: python3 docs/evidence/T13/probe-v2-2026-07-30.py
"""

from __future__ import annotations

import sys
from collections import deque
from functools import lru_cache
from itertools import product

# -----------------------------------------------------------------------------
# Goban geometry
W, H = 3, 2
N = W * H


def neighbors(p: int):
    r, c = divmod(p, W)
    if r > 0:
        yield p - W
    if r + 1 < H:
        yield p + W
    if c > 0:
        yield p - 1
    if c + 1 < W:
        yield p + 1


# -----------------------------------------------------------------------------
# Colex address system (faithful to src/colex.zig, layout_version=1)

BINOM = [[0] * (N + 1) for _ in range(N + 1)]
for i in range(N + 1):
    BINOM[i][0] = 1
    for j in range(1, i + 1):
        BINOM[i][j] = BINOM[i - 1][j - 1] + BINOM[i - 1][j]

LAYER_OFFSET = [0] * (N + 2)
for k in range(N + 1):
    LAYER_OFFSET[k + 1] = LAYER_OFFSET[k] + BINOM[N][k] * (1 << k)
TOTAL = LAYER_OFFSET[N + 1]  # == 3**N


def colex_from_pos(pos: tuple[int, ...]) -> int:
    k = 0
    subset = 0
    colours = 0
    for cell in range(N):
        v = pos[cell]
        if v == 0:
            continue
        if v > 0:
            colours |= 1 << k
        k += 1
        subset += BINOM[cell][k]  # k is 1-based here
    return LAYER_OFFSET[k] + subset * (1 << k) + colours


def pos_from_colex(idx: int) -> tuple[int, ...]:
    assert 0 <= idx < TOTAL
    k = 0
    while idx >= LAYER_OFFSET[k + 1]:
        k += 1
    layer_idx = idx - LAYER_OFFSET[k]
    subset = layer_idx >> k
    colours = layer_idx & ((1 << k) - 1)
    pos = [0] * N
    for i in range(k, 0, -1):
        cell = N - 1
        while BINOM[cell][i] > subset:
            cell -= 1
        subset -= BINOM[cell][i]
        black = (colours >> (i - 1)) & 1
        pos[cell] = 1 if black else -1
    return tuple(pos)


# Precompute the full raw address space
ALL_POSITIONS = [pos_from_colex(i) for i in range(TOTAL)]
COLEX_OF_POS = {pos: i for i, pos in enumerate(ALL_POSITIONS)}
assert len(COLEX_OF_POS) == TOTAL  # bijection sanity


# -----------------------------------------------------------------------------
# Rules kernel


def is_legal(pos: tuple[int, ...]) -> bool:
    visited = [False] * N
    for p in range(N):
        if pos[p] == 0 or visited[p]:
            continue
        colour = pos[p]
        stack = [p]
        visited[p] = True
        has_lib = False
        while stack:
            q = stack.pop()
            for r in neighbors(q):
                if pos[r] == 0:
                    has_lib = True
                elif pos[r] == colour and not visited[r]:
                    visited[r] = True
                    stack.append(r)
        if not has_lib:
            return False
    return True


def chain_captured(pos: tuple[int, ...], seed: int):
    """Return (captured, chain_cells) for the chain containing seed.
    captured is True iff the chain has no liberty."""
    colour = 1 if pos[seed] > 0 else -1
    visited = [False] * N
    stack = [seed]
    visited[seed] = True
    chain = [seed]
    has_lib = False
    while stack:
        q = stack.pop()
        for r in neighbors(q):
            if pos[r] == 0:
                has_lib = True
            elif (1 if pos[r] > 0 else -1) == colour and not visited[r]:
                visited[r] = True
                stack.append(r)
                chain.append(r)
    return not has_lib, chain


class IllegalMove(Exception):
    pass


class SuicideMove(Exception):
    pass


def pos_from_move(pos: tuple[int, ...], colour: int, cell: int) -> tuple[int, ...]:
    if pos[cell] != 0:
        raise IllegalMove("occupied")
    nxt = list(pos)
    nxt[cell] = colour

    # capture opponent neighbour chains without liberties
    for q in neighbors(cell):
        if nxt[q] * colour < 0:
            captured, chain = chain_captured(tuple(nxt), q)
            if captured:
                for c in chain:
                    nxt[c] = 0

    # suicide check: own chain must have a liberty
    captured, _ = chain_captured(tuple(nxt), cell)
    if captured:
        raise SuicideMove("suicide")
    return tuple(nxt)


def area_score(pos: tuple[int, ...]) -> int:
    black = white = 0
    visited = [False] * N
    for p in range(N):
        if pos[p] > 0:
            black += 1
            continue
        if pos[p] < 0:
            white += 1
            continue
        if visited[p]:
            continue
        # flood empty region
        stack = [p]
        visited[p] = True
        size = 0
        tb = tw = False
        while stack:
            q = stack.pop()
            size += 1
            for r in neighbors(q):
                if pos[r] > 0:
                    tb = True
                elif pos[r] < 0:
                    tw = True
                elif not visited[r]:
                    visited[r] = True
                    stack.append(r)
        if tb and not tw:
            black += size
        if tw and not tb:
            white += size
    return black - white


def benson_alive(pos: tuple[int, ...], colour: int):
    alive = [False] * N

    # label friendly chains
    chain_id = [-1] * N
    num_chains = 0
    visited = [False] * N
    for p in range(N):
        if pos[p] * colour <= 0 or visited[p]:
            continue
        cid = num_chains
        num_chains += 1
        stack = [p]
        visited[p] = True
        while stack:
            q = stack.pop()
            chain_id[q] = cid
            for r in neighbors(q):
                if pos[r] * colour > 0 and not visited[r]:
                    visited[r] = True
                    stack.append(r)
    if num_chains == 0:
        return alive

    # label regions (empty or opponent)
    region_id = [-1] * N
    num_regions = 0
    visited = [False] * N
    for p in range(N):
        if pos[p] * colour > 0 or visited[p]:
            continue
        rid = num_regions
        num_regions += 1
        stack = [p]
        visited[p] = True
        while stack:
            q = stack.pop()
            region_id[q] = rid
            for r in neighbors(q):
                if pos[r] * colour <= 0 and not visited[r]:
                    visited[r] = True
                    stack.append(r)

    region_empty = [0] * num_regions
    borders = [[False] * num_chains for _ in range(num_regions)]
    empty_adj = [[0] * num_chains for _ in range(num_regions)]
    for p in range(N):
        rid = region_id[p]
        if rid < 0:
            continue
        nbrs = list(neighbors(p))
        if pos[p] == 0:
            region_empty[rid] += 1
            seen = [False] * num_chains
            for r in nbrs:
                if pos[r] * colour > 0:
                    cid = chain_id[r]
                    if not seen[cid]:
                        seen[cid] = True
                        empty_adj[rid][cid] += 1
        for r in nbrs:
            if pos[r] * colour > 0:
                borders[rid][chain_id[r]] = True

    vital = [[False] * num_chains for _ in range(num_regions)]
    for rid in range(num_regions):
        if region_empty[rid] == 0:
            continue
        for cid in range(num_chains):
            if empty_adj[rid][cid] == region_empty[rid]:
                vital[rid][cid] = True

    chain_in = [True] * num_chains
    region_in = [True] * num_regions
    changed = True
    while changed:
        changed = False
        for cid in range(num_chains):
            if not chain_in[cid]:
                continue
            vcount = sum(1 for rid in range(num_regions) if region_in[rid] and vital[rid][cid])
            if vcount < 2:
                chain_in[cid] = False
                changed = True
        for rid in range(num_regions):
            if not region_in[rid]:
                continue
            for cid in range(num_chains):
                if borders[rid][cid] and not chain_in[cid]:
                    region_in[rid] = False
                    changed = True
                    break

    for p in range(N):
        if pos[p] * colour > 0 and chain_in[chain_id[p]]:
            alive[p] = True
    return alive


def is_settled(pos: tuple[int, ...]) -> bool:
    balive = benson_alive(pos, 1)
    walive = benson_alive(pos, -1)
    for p in range(N):
        if pos[p] > 0 and not balive[p]:
            return False
        if pos[p] < 0 and not walive[p]:
            return False
    visited = [False] * N
    for p in range(N):
        if pos[p] != 0 or visited[p]:
            continue
        stack = [p]
        visited[p] = True
        tb = tw = False
        while stack:
            q = stack.pop()
            stone_nbr = False
            for r in neighbors(q):
                if pos[r] > 0:
                    tb = True
                    stone_nbr = True
                elif pos[r] < 0:
                    tw = True
                    stone_nbr = True
                elif not visited[r]:
                    visited[r] = True
                    stack.append(r)
            if not stone_nbr:
                return False
        if tb == tw:
            return False
    return True


def is_own_eye(pos: tuple[int, ...], p: int, colour: int, alive):
    for q in neighbors(p):
        if pos[q] * colour <= 0 or not alive[q]:
            return False
    return True


# -----------------------------------------------------------------------------
# Precompute per-raw-index facts

LEGAL = [is_legal(p) for p in ALL_POSITIONS]
SETTLED = [is_settled(p) if legal else False for legal, p in zip(LEGAL, ALL_POSITIONS)]
SCORE = [area_score(p) if legal else 0 for legal, p in zip(LEGAL, ALL_POSITIONS)]

LEGAL_COUNT = sum(LEGAL)
SETTLED_COUNT = sum(SETTLED)


# -----------------------------------------------------------------------------
# Retrograde L/H value iteration (faithful to src/retro.zig Retro.sweep)


def opt(maximizing: bool, a: int, b: int) -> int:
    return max(a, b) if maximizing else min(a, b)


def retrograde_sweep(q_b0, q_w0, q_b1, q_w1):
    """One Gauss-Seidel sweep over a single L or H quad. Returns change count."""
    changes = 0
    for layer in range(N, -1, -1):
        for idx in range(LAYER_OFFSET[layer], LAYER_OFFSET[layer + 1]):
            i = int(idx)
            if not LEGAL[i] or SETTLED[i]:
                continue
            pos = ALL_POSITIONS[i]
            for side in (1, -1):
                maximizing = side > 0
                have_move = False
                m = 0
                for p in range(N):
                    if pos[p] != 0:
                        continue
                    try:
                        child = pos_from_move(pos, side, p)
                    except (IllegalMove, SuicideMove):
                        continue
                    ci = COLEX_OF_POS[child]
                    cv = q_w0[ci] if maximizing else q_b0[ci]
                    if not have_move:
                        m = cv
                        have_move = True
                    else:
                        m = opt(maximizing, m, cv)
                v1 = SCORE[i]
                v0 = q_w1[i] if maximizing else q_b1[i]
                if have_move:
                    v1 = opt(maximizing, m, v1)
                    v0 = opt(maximizing, m, v0)
                a1 = q_b1 if maximizing else q_w1
                a0 = q_b0 if maximizing else q_w0
                if a1[i] != v1:
                    a1[i] = v1
                    changes += 1
                if a0[i] != v0:
                    a0[i] = v0
                    changes += 1
    return changes


def build_tables():
    lo_b0 = [0] * TOTAL
    lo_w0 = [0] * TOTAL
    lo_b1 = [0] * TOTAL
    lo_w1 = [0] * TOTAL
    hi_b0 = [0] * TOTAL
    hi_w0 = [0] * TOTAL
    hi_b1 = [0] * TOTAL
    hi_w1 = [0] * TOTAL
    vb = [-128] * TOTAL
    vw = [-128] * TOTAL

    # seed
    for i in range(TOTAL):
        if not LEGAL[i]:
            continue
        sc = SCORE[i]
        if SETTLED[i]:
            lo_b0[i] = lo_w0[i] = lo_b1[i] = lo_w1[i] = sc
            hi_b0[i] = hi_w0[i] = hi_b1[i] = hi_w1[i] = sc
            vb[i] = vw[i] = sc
        else:
            lo_b0[i] = lo_w0[i] = lo_b1[i] = lo_w1[i] = -N
            hi_b0[i] = hi_w0[i] = hi_b1[i] = hi_w1[i] = N

    # converge both fixpoints
    sweeps = 0
    while True:
        c = retrograde_sweep(lo_b0, lo_w0, lo_b1, lo_w1) + retrograde_sweep(
            hi_b0, hi_w0, hi_b1, hi_w1
        )
        sweeps += 1
        if c == 0:
            break
        if sweeps >= 10000:
            raise RuntimeError("retrograde did not converge")

    # finalize: single-score where L == H
    ko_b = ko_w = 0
    for i in range(TOTAL):
        if not LEGAL[i]:
            continue
        if SETTLED[i]:
            continue
        if lo_b0[i] == hi_b0[i]:
            vb[i] = lo_b0[i]
        else:
            ko_b += 1
        if lo_w0[i] == hi_w0[i]:
            vw[i] = lo_w0[i]
        else:
            ko_w += 1

    return {
        "lo_b0": lo_b0,
        "lo_w0": lo_w0,
        "lo_b1": lo_b1,
        "lo_w1": lo_w1,
        "hi_b0": hi_b0,
        "hi_w0": hi_w0,
        "hi_b1": hi_b1,
        "hi_w1": hi_w1,
        "vb": vb,
        "vw": vw,
        "sweeps": sweeps,
        "ko_b": ko_b,
        "ko_w": ko_w,
    }


# -----------------------------------------------------------------------------
# Forward PSK alpha-beta solver (no memo, no brackets, eye-pruned)
# Faithful to src/retro.zig ab_solve with memo=false, brackets=false.


def ab_solve(pos: tuple[int, ...], side: int, passes: int, alpha: int, beta: int, history: list, memo: dict | None = None):
    """Return exact value under the given PSK history.

    Uses fail-soft alpha-beta and an optional per-history memo keyed by
    (idx, side, passes, history_tuple).  The memo is sound for a fixed
    history because the ban set is exactly the positions seen on the path.
    With memo=None the function falls back to plain alpha-beta.

    !! DEFECT, measured 2026-07-30 (T120 absorption audit).  The memo never
    fires, and if it ever did it would be unsound.  Do not trust it and do not
    "fix" it by widening its scope.

      * Zero hits.  `history` is the ORDERED path, so the key uniquely
        identifies a node of the DFS tree; a node is expanded once, and both
        call sites pass memo=None so the dict is per-query anyway.  Measured
        over the first 400,001 lookups from the legal-root sweep:
        400,001 lookups, 0 hits (0.00000000%).
      * Net cost, not net saving.  Every node pays an O(depth) tuple(history)
        construction, a hash, and a dict store, and the dict grows without
        bound for the life of the query.  This makes the 62-minute
        non-completion recorded in probe-reimplementation-2026-07-30.md worse,
        not better.
      * Latent unsoundness.  The obvious "fix" -- share one memo across
        queries to get hits -- breaks correctness.  `best` is a FAIL-SOFT
        value: on the `a >= b` cutoff below it is only a bound, not the exact
        value.  It is stored here with no bound flag, and (alpha, beta) is not
        part of the key, so a later lookup under a wider window would return a
        wrong value.  A shared memo needs (lower, upper) bound pairs, not a
        scalar.

    The correct reading: run this solver with the memo removed.  It is
    equivalent to memo=None today, which is what the two call sites use, which
    is why the numbers this file has produced are unaffected.
    """
    if memo is None:
        memo = {}
    if passes >= 2 or is_settled(pos):
        return area_score(pos)

    idx = COLEX_OF_POS[pos]
    key = (idx, side, passes, tuple(history))
    if key in memo:
        return memo[key]

    maximizing = side > 0
    best = -127 if maximizing else 127
    a = alpha
    b = beta

    alive = benson_alive(pos, side)
    for p in range(N):
        if pos[p] != 0:
            continue
        if is_own_eye(pos, p, side, alive):
            continue
        try:
            child = pos_from_move(pos, side, p)
        except (IllegalMove, SuicideMove):
            continue
        ci = COLEX_OF_POS[child]
        if ci in history:
            continue  # positional superko ban
        history.append(ci)
        v = ab_solve(child, -side, 0, a, b, history, memo)
        history.pop()
        if maximizing:
            if v > best:
                best = v
            if best > a:
                a = best
        else:
            if v < best:
                best = v
            if best < b:
                b = best
        if a >= b:
            break

    # pass option
    v = ab_solve(pos, -side, passes + 1, a, b, history, memo)
    if maximizing:
        if v > best:
            best = v
    else:
        if v < best:
            best = v
    memo[key] = best
    return best


# -----------------------------------------------------------------------------
# T13 experiment: enumerate PSK histories and compare against L==H values


def run_probe(tables: dict, max_depth: int = 10, enum_budget: int = 2_000_000):
    lo_b0 = tables["lo_b0"]
    lo_w0 = tables["lo_w0"]
    hi_b0 = tables["hi_b0"]
    hi_w0 = tables["hi_w0"]
    vb = tables["vb"]
    vw = tables["vw"]

    # L==H slots and their stored fresh-start values
    stored = {}
    for i in range(TOTAL):
        if not LEGAL[i]:
            continue
        if lo_b0[i] == hi_b0[i]:
            stored[(i, 1)] = lo_b0[i]
        if lo_w0[i] == hi_w0[i]:
            stored[(i, -1)] = lo_w0[i]

    # Precompute legal non-pass children for line generation (NO eye-prune)
    children_for_line = {}
    for i in range(TOTAL):
        if not LEGAL[i]:
            continue
        pos = ALL_POSITIONS[i]
        for side in (1, -1):
            lst = []
            for p in range(N):
                if pos[p] != 0:
                    continue
                try:
                    child = pos_from_move(pos, side, p)
                except (IllegalMove, SuicideMove):
                    continue
                lst.append(COLEX_OF_POS[child])
            children_for_line[(i, side)] = lst

    fresh_mismatches = []
    history_mismatches = []
    tested_histories = {}  # (final_idx, side, tuple(history)) -> got
    lines_examined = 0
    nodes_used = 0
    budget_hit = False

    # Fresh-start sanity: every L==H slot, history = [root]
    for (idx, side), expected in stored.items():
        got = ab_solve(ALL_POSITIONS[idx], side, 0, -127, 127, [idx])
        if got != expected:
            fresh_mismatches.append((idx, side, expected, got))

    # Enumerate histories depth-first from every legal root.
    # Each node in the enumeration tree counts against the line budget.
    for root_idx in range(TOTAL):
        if not LEGAL[root_idx]:
            continue
        for root_side in (1, -1):
            stack = [(root_idx, root_side, [root_idx], 1)]
            while stack:
                idx, side, hist, depth = stack.pop()
                lines_examined += 1
                if lines_examined > enum_budget:
                    budget_hit = True
                    break

                # Test this arrival if it lands on an L==H slot.
                if (idx, side) in stored:
                    key = (idx, side, tuple(hist))
                    if key not in tested_histories:
                        expected = stored[(idx, side)]
                        got = ab_solve(ALL_POSITIONS[idx], side, 0, -127, 127, list(hist))
                        tested_histories[key] = got
                        nodes_used += 1
                        if got != expected:
                            history_mismatches.append(
                                (idx, side, depth, expected, got, list(hist))
                            )

                if depth >= max_depth:
                    continue

                # Extend with all legal placements for `side`.
                for ci in children_for_line[(idx, side)]:
                    if ci in hist:  # PSK ban within this line
                        continue
                    stack.append((ci, -side, hist + [ci], depth + 1))

            if budget_hit:
                break
        if budget_hit:
            break

    # Ban-set size distribution of the *tested* non-root histories
    size_counts = {}
    nontrivial = 0
    for (idx, side, hist), _ in tested_histories.items():
        sz = len(hist)
        size_counts[sz] = size_counts.get(sz, 0) + 1
        if sz > 1:
            nontrivial += 1

    return {
        "stored_slots": len(stored),
        "fresh_mismatches": fresh_mismatches,
        "history_mismatches": history_mismatches,
        "lines_examined": lines_examined,
        "nontrivial_tested": nontrivial,
        "budget_hit": budget_hit,
        "size_counts": size_counts,
    }


# -----------------------------------------------------------------------------
# Reporting


def fmt_hist(hist):
    return " ".join(str(x) for x in hist)


def main():
    out = sys.stdout
    note = lambda s: print(s, file=out)

    note("T13 probe v2 (Python re-implementation)")
    note("Model/Worker: Kimi-k2.7 / T118")
    note("Date: 2026-07-30")
    note("")
    note(f"Board: {W}×{H}  raw slots=3^{N}={TOTAL}  legal positions={LEGAL_COUNT}")

    tables = build_tables()
    note(f"Retrograde converged in {tables['sweeps']} sweep(s)")
    note(
        f"Ko-sensitive slots: B={tables['ko_b']} W={tables['ko_w']} "
        f"(single-score slots = {tables['sweeps']})"
    )
    # Actually 'sweeps' is number of sweeps; below we report the real count.
    stored_count = 0
    for i in range(TOTAL):
        if not LEGAL[i]:
            continue
        if tables["lo_b0"][i] == tables["hi_b0"][i]:
            stored_count += 1
        if tables["lo_w0"][i] == tables["hi_w0"][i]:
            stored_count += 1
    note(f"L==H slots stored: {stored_count}")
    note("")

    result = run_probe(tables)

    note(f"Game lines examined: {result['lines_examined']}")
    note(
        f"Non-trivial PSK histories tested: {result['nontrivial_tested']}"
    )
    note(
        f"Fresh-start sanity mismatches: {len(result['fresh_mismatches'])} "
        f"(across {result['stored_slots']} L==H slots)"
    )
    note(
        f"History-aware mismatches: {len(result['history_mismatches'])} "
        f"(C2 falsification count)"
    )
    note(f"Enumeration budget hit: {result['budget_hit']}")
    note("")

    note("Ban-set size distribution of tested histories:")
    for sz in sorted(result["size_counts"]):
        note(f"  size={sz:2d}  count={result['size_counts'][sz]}")
    note("")

    if result["fresh_mismatches"]:
        note("FRESH-START SANITY MISMATCHES (should be 0):")
        for idx, side, exp, got in result["fresh_mismatches"]:
            note(f"  idx={idx} side={'B' if side > 0 else 'W'} expected={exp:+d} got={got:+d}")
        note("")

    if result["history_mismatches"]:
        note("HISTORY-AWARE MISMATCHES (C2 counterexamples):")
        for idx, side, depth, exp, got, hist in result["history_mismatches"]:
            note(
                f"  idx={idx} side={'B' if side > 0 else 'W'} depth={depth} "
                f"expected={exp:+d} got={got:+d}  history={fmt_hist(hist)}"
            )
        note("")

    # Verdict line, machine-readable.
    note(
        f"VERDICT: C2 is {'FALSIFIED' if result['history_mismatches'] else 'NOT FALSIFIED'} "
        f"at {W}×{H}: {len(result['history_mismatches'])} history-aware mismatch(es), "
        f"{len(result['fresh_mismatches'])} fresh-start mismatch(es)."
    )

    # Exit non-zero only if something is internally inconsistent.
    if result["fresh_mismatches"]:
        sys.exit(2)
    return 0 if result["history_mismatches"] else 0


if __name__ == "__main__":
    sys.exit(main())
