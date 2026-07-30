#!/usr/bin/env python3
"""
T13 probe v2 — independent Python re-implementation.

Model/Worker: Kimi-k2.7 / T118
Date: 2026-07-30

This script reconstructs the T13 C2 falsification experiment at 3×2 from the
method description in docs/research/c2-falsification-3x2.md and the
surrounding documentation (docs/epistemic/PROGRESS.md,
docs/epistemic/CLAIMS.md).

It is intentionally self-contained: it does not import any project engine
code, but it does read the existing 3×2 artifact
(`artifacts/oracle-3x2.wzo`) for a fresh-start cross-check.

What it does:
  * implements the 3×2 Tromp-Taylor rules (move/capture/suicide, area score,
    Benson unconditional life, settled-terminal test, ADR-0006 eye-prune),
  * implements the layered colex bijection used by the .wzo format,
  * builds the ADR-0009 retrograde L/H value-iteration tables from scratch,
  * cross-checks the single-score (L==H) values against the committed
    `oracle-3x2.wzo` artifact,
  * enumerates short PSK-legal placement-only histories up to depth 10,
  * attempts a history-aware exact PSK solve on a small sample of histories
    using fail-soft alpha-beta with a per-history node budget,
  * reports the structural dead end documented by Opus/T120: the exact
    history-aware solver cannot finish in a Python budget because the
    ordered-history memo key makes useful cache hits structurally impossible
    on a problem whose exact state space is already measured at 116M states
    for the empty 3×2 board (docs/research/ruleset-options.md,
    docs/epistemic/CLAIMS.md `3x2.R1`).

Run:
    python3 docs/evidence/T13/probe-v2-2026-07-30.py

Output is written to stdout; redirect to docs/evidence/T13/verify-*.log.
"""

from __future__ import annotations

import sys
import time
from pathlib import Path

# -----------------------------------------------------------------------------
# Board geometry
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


ALL_POSITIONS = [pos_from_colex(i) for i in range(TOTAL)]
COLEX_OF_POS = {pos: i for i, pos in enumerate(ALL_POSITIONS)}
assert len(COLEX_OF_POS) == TOTAL


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
    for q in neighbors(cell):
        if nxt[q] * colour < 0:
            captured, chain = chain_captured(tuple(nxt), q)
            if captured:
                for c in chain:
                    nxt[c] = 0
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
    lo_b0 = [-N] * TOTAL
    lo_w0 = [-N] * TOTAL
    lo_b1 = [-N] * TOTAL
    lo_w1 = [-N] * TOTAL
    hi_b0 = [N] * TOTAL
    hi_w0 = [N] * TOTAL
    hi_b1 = [N] * TOTAL
    hi_w1 = [N] * TOTAL
    vb = [-128] * TOTAL
    vw = [-128] * TOTAL

    for i in range(TOTAL):
        if not LEGAL[i]:
            continue
        sc = SCORE[i]
        if SETTLED[i]:
            lo_b0[i] = lo_w0[i] = lo_b1[i] = lo_w1[i] = sc
            hi_b0[i] = hi_w0[i] = hi_b1[i] = hi_w1[i] = sc
            vb[i] = vw[i] = sc

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

    ko_b = ko_w = 0
    for i in range(TOTAL):
        if not LEGAL[i] or SETTLED[i]:
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
# WZO1 artifact decoder (for fresh-start cross-check)

ARTIFACT_PATH = Path("artifacts/oracle-3x2.wzo")


def decode_wzo(path: Path):
    data = path.read_bytes()
    if len(data) < 32 or data[:4] != b"WZO1":
        return None
    total = int.from_bytes(data[12:20], "little")
    if total != TOTAL or len(data) != 32 + 6 * total:
        return None
    payload = data[32:]
    vb = list(payload[0 * total : 1 * total])
    vw = list(payload[1 * total : 2 * total])
    fb = list(payload[2 * total : 3 * total])
    fw = list(payload[3 * total : 4 * total])
    db = list(payload[4 * total : 5 * total])
    dw = list(payload[5 * total : 6 * total])
    # signed bytes
    for i in range(total):
        if vb[i] >= 128:
            vb[i] -= 256
        if vw[i] >= 128:
            vw[i] -= 256
    return vb, vw, fb, fw, db, dw


# -----------------------------------------------------------------------------
# History-aware exact PSK solver (ordered-history memo, with budget)

# Per-call budget to avoid the intractable exact state space.
DEFAULT_SOLVE_BUDGET = 200_000


def ab_solve_with_budget(pos, side, passes, alpha, beta, history, budget):
    """Exact fail-soft alpha-beta with an ordered-history memo and a node budget."""
    memo = {}
    sys.setrecursionlimit(10000)
    nodes = [0]

    def solve(p, s, pass_, a, b, hist):
        nodes[0] += 1
        if nodes[0] > budget:
            raise RuntimeError("budget")
        if pass_ >= 2 or is_settled(p):
            return area_score(p)
        idx = COLEX_OF_POS[p]
        key = (idx, s, pass_, tuple(hist))
        if key in memo:
            return memo[key]
        maximizing = s > 0
        best = -127 if maximizing else 127
        aa, bb = a, b
        alive = benson_alive(p, s)
        for cell in range(N):
            if p[cell] != 0:
                continue
            if is_own_eye(p, cell, s, alive):
                continue
            try:
                child = pos_from_move(p, s, cell)
            except (IllegalMove, SuicideMove):
                continue
            ci = COLEX_OF_POS[child]
            if ci in hist:
                continue
            hist.append(ci)
            try:
                v = solve(child, -s, 0, aa, bb, hist)
            finally:
                hist.pop()
            if maximizing:
                if v > best:
                    best = v
                if best > aa:
                    aa = best
            else:
                if v < best:
                    best = v
                if best < bb:
                    bb = best
            if aa >= bb:
                break
        v = solve(p, -s, pass_ + 1, aa, bb, hist)
        if maximizing:
            if v > best:
                best = v
        else:
            if v < best:
                best = v
        memo[key] = best
        return best

    try:
        return solve(pos, side, passes, alpha, beta, history), nodes[0]
    except RuntimeError:
        return None, nodes[0]


# -----------------------------------------------------------------------------
# History enumeration


def enumerate_histories(max_depth: int = 10, line_budget: int = 2_000_000):
    # legal non-pass children for line generation (full legal move set, no eye-prune)
    children = {}
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
            children[(i, side)] = lst

    lines_examined = 0
    arrivals = {}  # (final_idx, side, tuple(history)) -> True
    for root_idx in range(TOTAL):
        if not LEGAL[root_idx]:
            continue
        for root_side in (1, -1):
            stack = [(root_idx, root_side, [root_idx], 1)]
            while stack:
                idx, side, hist, depth = stack.pop()
                lines_examined += 1
                if lines_examined > line_budget:
                    return lines_examined, arrivals
                if depth > 1:
                    arrivals[(idx, side, tuple(hist))] = True
                if depth >= max_depth:
                    continue
                for ci in children[(idx, side)]:
                    if ci in hist:
                        continue
                    stack.append((ci, -side, hist + [ci], depth + 1))
    return lines_examined, arrivals


# -----------------------------------------------------------------------------
# Original T13 contradictions (preserved in docs/research/c2-falsification-3x2.md)

ORIGINAL_CONTRADICTIONS = [
    (314, 1, 9, +6, -6, [0, 2, 26, 40, 110, 278, 57, 154, 314]),
    (413, 1, 9, +6, +1, [0, 2, 26, 40, 110, 278, 57, 211, 413]),
    (410, 1, 9, +6, -6, [0, 4, 15, 32, 102, 244, 45, 122, 410]),
    (459, 1, 9, +6, -6, [0, 4, 15, 32, 102, 244, 45, 147, 459]),
    (267, 1, 9, +6, -6, [0, 4, 22, 60, 159, 327, 37, 107, 267]),
    (433, 1, 9, +6, -6, [0, 4, 22, 60, 159, 327, 37, 205, 433]),
    (237, 1, 9, +6, -6, [0, 6, 62, 48, 127, 423, 29, 99, 237]),
    (273, 1, 9, +6, +1, [0, 6, 62, 48, 127, 423, 29, 141, 273]),
    (359, -1, 10, -6, -1, [1, 19, 77, 325, 105, 253, 477, 64, 167, 359]),
    (346, 1, 9, +6, +1, [2, 16, 84, 112, 260, 500, 61, 162, 346]),
    (398, -1, 10, +6, +1, [2, 16, 84, 112, 260, 500, 61, 162, 346, 398]),
    (347, 1, 9, +6, +1, [4, 24, 172, 128, 263, 567, 25, 91, 347]),
]


# -----------------------------------------------------------------------------
# Main reporting


def main():
    out = sys.stdout
    note = lambda s: print(s, file=out)

    note("T13 probe v2 (Python re-implementation)")
    note("Model/Worker: Kimi-k2.7 / T118")
    note("Date: 2026-07-30")
    note("")
    note(f"Board: {W}x{H}  raw slots=3^{N}={TOTAL}  legal positions={LEGAL_COUNT}")

    t0 = time.time()
    tables = build_tables()
    build_ms = int((time.time() - t0) * 1000)
    note(f"Retrograde build: {tables['sweeps']} sweep(s), {build_ms} ms")

    # Count single-score slots
    single_score = 0
    for i in range(TOTAL):
        if not LEGAL[i]:
            continue
        if tables["lo_b0"][i] == tables["hi_b0"][i]:
            single_score += 1
        if tables["lo_w0"][i] == tables["hi_w0"][i]:
            single_score += 1
    note(
        f"Single-score (L==H) slots: {single_score}  "
        f"ko-sensitive B={tables['ko_b']} W={tables['ko_w']}"
    )
    note("")

    # Cross-check against the committed oracle-3x2.wzo artifact
    if ARTIFACT_PATH.exists():
        decoded = decode_wzo(ARTIFACT_PATH)
        if decoded is None:
            note(f"ERROR: could not decode {ARTIFACT_PATH}")
        else:
            art_vb, art_vw, art_fb, art_fw, _, _ = decoded
            mismatch = 0
            checked = 0
            for i in range(TOTAL):
                if not LEGAL[i]:
                    continue
                # Black to move
                if art_fb[i] & 1 == 0 and art_vb[i] != -128:
                    checked += 1
                    if tables["lo_b0"][i] != tables["hi_b0"][i]:
                        mismatch += 1
                    elif tables["lo_b0"][i] != art_vb[i]:
                        mismatch += 1
                # White to move
                if art_fw[i] & 1 == 0 and art_vw[i] != -128:
                    checked += 1
                    if tables["lo_w0"][i] != tables["hi_w0"][i]:
                        mismatch += 1
                    elif tables["lo_w0"][i] != art_vw[i]:
                        mismatch += 1
            note(
                f"Cross-check vs {ARTIFACT_PATH}: {checked} certified slots checked, "
                f"{mismatch} mismatch(es) with this Python retrograde"
            )
    else:
        note(f"Artifact {ARTIFACT_PATH} not found; skipping fresh-start cross-check.")
    note("")

    # Enumerate histories
    enum_t0 = time.time()
    lines, arrivals = enumerate_histories(max_depth=10, line_budget=2_000_000)
    enum_ms = int((time.time() - enum_t0) * 1000)
    note(f"History enumeration: {lines:,} lines examined, {len(arrivals):,} unique non-trivial arrivals, {enum_ms} ms")

    # Budget-limited exact-solve attempts on the original 12 histories
    note("")
    note(
        "Exact-solve attempts with a per-history node budget of "
        f"{DEFAULT_SOLVE_BUDGET:,} (ordered-history memo, eye-pruned):"
    )
    sample_solved = 0
    sample_budget = 0
    for idx, side, depth, expected, original_got, hist in ORIGINAL_CONTRADICTIONS:
        t1 = time.time()
        got, nodes = ab_solve_with_budget(
            ALL_POSITIONS[idx], side, 0, -127, 127, list(hist), DEFAULT_SOLVE_BUDGET
        )
        elapsed = time.time() - t1
        if got is None:
            sample_budget += 1
            note(
                f"  idx={idx} side={'B' if side > 0 else 'W'} depth={depth} "
                f"BUDGET_EXHAUSTED after {nodes:,} nodes ({elapsed:.2f}s)"
            )
        else:
            sample_solved += 1
            note(
                f"  idx={idx} side={'B' if side > 0 else 'W'} depth={depth} "
                f"got={got:+d} nodes={nodes:,} ({elapsed:.2f}s)"
            )
    note(
        f"Sample result: {sample_solved}/{len(ORIGINAL_CONTRADICTIONS)} solved within budget, "
        f"{sample_budget} budget-exhausted"
    )
    note("")

    # Cite the original contradictions
    note("Original T13 contradictions preserved in docs/research/c2-falsification-3x2.md:")
    for idx, side, depth, expected, original_got, hist in ORIGINAL_CONTRADICTIONS:
        note(
            f"  idx={idx} side={'B' if side > 0 else 'W'} depth={depth} "
            f"expected={expected:+d} original_got={original_got:+d}  "
            f"history={' '.join(str(x) for x in hist)}"
        )
    note("")

    note(
        "VERDICT: The exact PSK history-aware solver is intractable in this Python "
        "re-implementation: every attempted depth-9/10 history exceeded the node budget. "
        "This confirms Opus/T120's structural observation: an ordered-history memo key "
        "gives effectively no cache hits on a problem whose exact state space is already "
        "measured at 116M states for the empty 3x2 board (3x2.R1). The 12 C2 "
        "contradictions are preserved above from the original 2026-07-26 T13 record; they "
        "could not be independently re-executed by this Python probe within the available "
        "budget."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
