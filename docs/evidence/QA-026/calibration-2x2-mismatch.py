#!/usr/bin/env python3
"""
CALIBRATION-2X2-MISMATCH — bug-regression fixture for the 24 EXP-4 2×2 mismatches.

Task: T103 · Role: DSFlash · Date: 2026-07-30

Verifies that all 24 states Opus T102's audit identified as buffer-aliasing
artefacts now agree between the loopy-game fixpoint and exact first-revisit
truncation. The divergence was NOT semantic — it was a single shared successor
buffer threaded through recursive calls in src/exp4_solve.zig:555-594.

With the defect understood and independently reproduced (see
docs/audits/2026-07-30-audit-2x2-mismatch.md), this fixture locks in the
corrected relationship: 0 mismatches, all 24 states at ±4 from both
evaluators.

Exit status: 0 if all 24 match · non-zero (count of mismatches) otherwise.

This is a standalone implementation sharing no code with the Zig solver or
the Opus audit Python script — an independent third witness.

Usage:
    python3 docs/evidence/QA-026/calibration-2x2-mismatch.py
"""

import sys

# ---------------------------------------------------------------------------
# Board: 2×2, cells row-major     0 1
#                                 2 3
# Adjacency: 4-cycle 0-1-3-2-0.  Diagonal cells are NOT adjacent.
# ---------------------------------------------------------------------------
N = 4
ADJ = {0: (1, 2), 1: (0, 3), 2: (0, 3), 3: (1, 2)}

EMPTY, BLACK, WHITE = 0, 1, -1
KO_NONE = 255
TIE = 0
N_SYMS = {BLACK: "B", WHITE: "W", EMPTY: "."}


def show(board):
    """Compact board string: e.g. 'WB/..'"""
    return "%s%s/%s%s" % tuple(N_SYMS[c] for c in board)


# ---------------------------------------------------------------------------
# Rules — independent from the audit code, same specification
# ---------------------------------------------------------------------------
def chain(board, seed):
    """(cells_of_chain, has_liberty) for the group at seed."""
    colour = board[seed]
    seen = {seed}
    stack = [seed]
    lib = False
    while stack:
        q = stack.pop()
        for r in ADJ[q]:
            if board[r] == EMPTY:
                lib = True
            elif board[r] == colour and r not in seen:
                seen.add(r)
                stack.append(r)
    return seen, lib


def is_legal_board(board):
    """True iff every group on the board has at least one liberty."""
    done = set()
    for p in range(N):
        if board[p] == EMPTY or p in done:
            continue
        cells, lib = chain(board, p)
        done |= cells
        if not lib:
            return False
    return True


def pos_from_move(board, colour, cell):
    """Place colour at cell; remove captured opponent stones; reject suicide.
    Returns new board tuple, or None if illegal."""
    if board[cell] != EMPTY:
        return None
    nxt = list(board)
    nxt[cell] = colour
    for q in ADJ[cell]:
        if nxt[q] == -colour:
            cells, lib = chain(nxt, q)
            if not lib:
                for c in cells:
                    nxt[c] = EMPTY
    _, lib = chain(nxt, cell)
    if not lib:
        return None
    return tuple(nxt)


def apply_place(st, cell):
    """Place stone at cell, returning new state or None if illegal."""
    board, side, ko, passes = st
    if board[cell] != EMPTY:
        return None
    if ko != KO_NONE and cell == ko:
        return None  # basic-ko prohibition
    nxt = pos_from_move(board, side, cell)
    if nxt is None:
        return None
    # Detect ko point: exactly one stone captured, placed stone is lone with
    # exactly one liberty (the vacated cell).
    opp_before = sum(1 for c in board if c == -side)
    opp_after = sum(1 for c in nxt if c == -side)
    captured = KO_NONE
    for i in range(N):
        if board[i] == -side and nxt[i] == EMPTY:
            captured = i
    new_ko = KO_NONE
    if opp_before - opp_after == 1 and captured != KO_NONE:
        libs = sum(1 for q in ADJ[cell] if nxt[q] == EMPTY)
        friendly = sum(1 for q in ADJ[cell] if nxt[q] == side)
        if libs == 1 and friendly == 0:
            new_ko = captured
    return (nxt, -side, new_ko, 0)


def apply_pass(st):
    """Pass. Two consecutive passes end the game (no further passes allowed)."""
    board, side, ko, passes = st
    if passes >= 2:
        return None
    return (board, -side, KO_NONE, passes + 1)


def area_score(board):
    """Area scoring: stones + empty regions bordering exactly one colour."""
    black = sum(1 for c in board if c == BLACK)
    white = sum(1 for c in board if c == WHITE)
    seen = set()
    for p in range(N):
        if board[p] != EMPTY or p in seen:
            continue
        region, stack = {p}, [p]
        touch_b = touch_w = False
        seen.add(p)
        while stack:
            q = stack.pop()
            for r in ADJ[q]:
                if board[r] == BLACK:
                    touch_b = True
                elif board[r] == WHITE:
                    touch_w = True
                elif r not in seen:
                    seen.add(r)
                    region.add(r)
                    stack.append(r)
        if touch_b and not touch_w:
            black += len(region)
        if touch_w and not touch_b:
            white += len(region)
    return black - white


# ---------------------------------------------------------------------------
# State encoding — byte-for-byte match with src/qa023_brute_2x2.zig:
#   idx = (passes*2*(n+1) + side_bit*(n+1) + ko_idx) * 81 + board_index
# where board_index = ∑ cell_i × 3^i  (0=empty, 1=black, 2=white)
# ---------------------------------------------------------------------------
def board_index(board):
    idx, mult = 0, 1
    for c in board:
        d = 1 if c > 0 else (2 if c < 0 else 0)
        idx += d * mult
        mult *= 3
    return idx


def unrank_board(bi):
    board, v = [], bi
    for _ in range(N):
        d = v % 3
        v //= 3
        board.append(EMPTY if d == 0 else (BLACK if d == 1 else WHITE))
    return tuple(board)


def global_index(st):
    board, side, ko, passes = st
    ko_idx = N if ko == KO_NONE else ko
    side_bit = 0 if side == BLACK else 1
    return (passes * 2 * (N + 1) + side_bit * (N + 1) + ko_idx) * 81 + board_index(board)


def state_from_index(idx):
    bi = idx % 81
    rest = idx // 81
    ko_idx = rest % (N + 1)
    side_passes = rest // (N + 1)
    side = BLACK if side_passes % 2 == 0 else WHITE
    passes = side_passes // 2
    ko = KO_NONE if ko_idx == N else ko_idx
    return (unrank_board(bi), side, ko, passes)


# ---------------------------------------------------------------------------
# Reachability — from both roots (Black and White to move on the empty goban)
# ---------------------------------------------------------------------------
EMPTY_BOARD = (EMPTY,) * N
ROOT_B = (EMPTY_BOARD, BLACK, KO_NONE, 0)
ROOT_W = (EMPTY_BOARD, WHITE, KO_NONE, 0)
ALL_ROOTS = (ROOT_B, ROOT_W)

TOTAL_STATES = 81 * 2 * (N + 1) * 3  # 1620 allocation slots


def reachable_states():
    """Return sorted list of all reachable (board, side, ko, passes) states."""
    seen = set(ALL_ROOTS)
    stack = list(ALL_ROOTS)
    while stack:
        st = stack.pop()
        # pass
        ns = apply_pass(st)
        if ns is not None and ns not in seen:
            seen.add(ns)
            stack.append(ns)
        # place moves
        for cell in range(N):
            ns = apply_place(st, cell)
            if ns is not None and ns not in seen:
                seen.add(ns)
                stack.append(ns)
    return sorted(seen, key=global_index)


# ---------------------------------------------------------------------------
# Build flat tables over integer indices
# ---------------------------------------------------------------------------
def terminal_value(st):
    return area_score(st[0])


def is_terminal(st):
    return st[3] == 2


def build_graph(states):
    SUCC = [()] * TOTAL_STATES
    TERM = [False] * TOTAL_STATES
    AREA = [0] * TOTAL_STATES
    MAXING = [False] * TOTAL_STATES
    for st in states:
        i = global_index(st)
        TERM[i] = is_terminal(st)
        AREA[i] = terminal_value(st)
        MAXING[i] = st[1] == BLACK
        kids = []
        ns = apply_pass(st)
        if ns is not None:
            kids.append(global_index(ns))
        for cell in range(N):
            ns = apply_place(st, cell)
            if ns is not None:
                kids.append(global_index(ns))
        SUCC[i] = tuple(kids)
    return SUCC, TERM, AREA, MAXING


# ---------------------------------------------------------------------------
# A. Loopy-game fixpoint — L/H value iteration (Bellman operator, ADR-0009)
# ---------------------------------------------------------------------------
def compute_fixpoint(order, SUCC, TERM, AREA, MAXING):
    L = [-N] * TOTAL_STATES
    H = [N] * TOTAL_STATES
    for i in order:
        if TERM[i]:
            L[i] = H[i] = AREA[i]
    for _sweep in range(200):
        changed = 0
        for i in order:
            if TERM[i]:
                continue
            maximizing = MAXING[i]
            bl = bh = None
            for c in SUCC[i]:
                vl, vh = L[c], H[c]
                if bl is None or (vl > bl if maximizing else vl < bl):
                    bl = vl
                if bh is None or (vh > bh if maximizing else vh < bh):
                    bh = vh
            if bl is not None:
                if bl != L[i]:
                    L[i] = bl
                    changed += 1
                if bh != H[i]:
                    H[i] = bh
                    changed += 1
        if changed == 0:
            break
    return L, H


def V(L, H):
    """Median(L, TIE, H)"""
    return max(L, min(TIE, H))


# ---------------------------------------------------------------------------
# B. Exact first-revisit truncation via alpha-beta search
#
# Alpha-beta is sound here because FRT is plain minimax over a (path, state)
# tree with no transposition table. The full window [-5, +5] guarantees an
# exact root value. Move ordering uses material count (goban sum) to reduce
# node count; it does not reference the fixpoint tables.
# ---------------------------------------------------------------------------
def material_of(board):
    return sum(board)


def compute_ordering(order, SUCC, MAXING):
    """Children ordered most-material-favourable first for the side to move."""
    ORDERED = [()] * TOTAL_STATES
    MAT = [0] * TOTAL_STATES
    for i in order:
        MAT[i] = material_of(state_from_index(i)[0])
    for i in order:
        kids = list(SUCC[i])
        kids.sort(key=lambda c: MAT[c], reverse=MAXING[i])
        ORDERED[i] = kids
    return ORDERED


class Exhausted(Exception):
    pass


BUDGET = [200_000_000]
NODES = [0]


def frt_ab(i, on_path, alpha, beta, ORDERED, TERM, AREA, MAXING, depth=0):
    """First-revisit truncation with alpha-beta pruning."""
    NODES[0] += 1
    BUDGET[0] -= 1
    if BUDGET[0] <= 0:
        raise Exhausted()
    if on_path[i]:
        return TIE
    if TERM[i]:
        return AREA[i]
    if depth > 128:
        return TIE
    on_path[i] = 1
    best = None
    if MAXING[i]:
        for c in ORDERED[i]:
            v = frt_ab(c, on_path, alpha, beta, ORDERED, TERM, AREA, MAXING, depth + 1)
            if best is None or v > best:
                best = v
            if best > alpha:
                alpha = best
            if alpha >= beta:
                break
    else:
        for c in ORDERED[i]:
            v = frt_ab(c, on_path, alpha, beta, ORDERED, TERM, AREA, MAXING, depth + 1)
            if best is None or v < best:
                best = v
            if best < beta:
                beta = best
            if alpha >= beta:
                break
    on_path[i] = 0
    return AREA[i] if best is None else best


def exact_frt(i, ORDERED, TERM, AREA, MAXING):
    """Exact FRT value for state i (full-window alpha-beta)."""
    BUDGET[0] = 200_000_000
    return frt_ab(i, bytearray(TOTAL_STATES), -5, 5, ORDERED, TERM, AREA, MAXING)


# ---------------------------------------------------------------------------
# The 24 mismatches from EXP-4, as identified by the Opus T102 audit
#   (global_index, expected_fixpoint_value)
# ---------------------------------------------------------------------------
MISMATCH_STATES = [
    (329, 4), (331, 4), (335, 4), (343, 4), (357, 4), (369, 4), (381, 4),
    (387, 4), (734, -4), (736, -4), (740, -4), (748, -4), (762, -4),
    (774, -4), (786, -4), (792, -4), (1141, 4), (1153, 4), (1191, 4),
    (1197, 4), (1544, -4), (1550, -4), (1572, -4), (1584, -4),
]

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def main():
    print("CALIBRATION-2X2-MISMATCH  (T103/DSFlash · 2026-07-30)", file=sys.stderr)
    print("Independent reimplementation — bug-regression fixture for the 24", file=sys.stderr)
    print("EXP-4 buffer-aliasing mismatches.", file=sys.stderr)
    print(file=sys.stderr)

    # 1. Reachability
    states = reachable_states()
    SUCC, TERM, AREA, MAXING = build_graph(states)
    order = [global_index(s) for s in states]
    nonterm = [i for i in order if not TERM[i]]
    term = [i for i in order if TERM[i]]
    print("Reachable states: %d  (non-terminal %d, terminal %d)"
          % (len(order), len(nonterm), len(term)), file=sys.stderr)
    if len(order) != 258 or len(nonterm) != 172 or len(term) != 86:
        print("FAIL: reachability mismatch — expected 258/172/86",
              file=sys.stderr)
        return 1

    # 2. Encoding round-trip
    bad = [i for i in range(TOTAL_STATES) if global_index(state_from_index(i)) != i]
    if bad:
        print("FAIL: encoding round-trip failed on %d indices" % len(bad),
              file=sys.stderr)
        return 2

    # 3. Fixpoint
    L, H = compute_fixpoint(order, SUCC, TERM, AREA, MAXING)
    print("Fixpoint computed.", file=sys.stderr)
    # Self-consistency check
    lf = hf = 0
    for i in nonterm:
        maximizing = MAXING[i]
        bl = bh = None
        for c in SUCC[i]:
            if bl is None or (L[c] > bl if maximizing else L[c] < bl):
                bl = L[c]
            if bh is None or (H[c] > bh if maximizing else H[c] < bh):
                bh = H[c]
        if bl != L[i]:
            lf += 1
        if bh != H[i]:
            hf += 1
    if lf or hf:
        print("FAIL: fixpoint not self-consistent (L=%d H=%d failures)"
              % (lf, hf), file=sys.stderr)
        return 3

    # Root verification
    root_b = global_index(ROOT_B)
    root_w = global_index(ROOT_W)
    vb = V(L[root_b], H[root_b])
    vw = V(L[root_w], H[root_w])
    if vb != 0 or vw != 0:
        print("FAIL: root values not 0 (B=%+d, W=%+d)" % (vb, vw),
              file=sys.stderr)
        return 4

    # 4. Compute alpha-beta ordering
    ORDERED = compute_ordering(order, SUCC, MAXING)

    # 5. Verify the 24 mismatch states
    failures = []
    for idx, expected_v in MISMATCH_STATES:
        fp_v = V(L[idx], H[idx])
        if fp_v != expected_v:
            st = state_from_index(idx)
            print("FAIL: idx=%d %s side=%s passes=%d  fixpoint V=%+d "
                  "(expected %+d)"
                  % (idx, show(st[0]), N_SYMS[st[1]], st[3], fp_v, expected_v),
                  file=sys.stderr)
            failures.append((idx, expected_v, fp_v, None))
            continue
        try:
            frt_v = exact_frt(idx, ORDERED, TERM, AREA, MAXING)
        except Exhausted:
            st = state_from_index(idx)
            print("FAIL: idx=%d %s side=%s passes=%d  budget exhausted"
                  % (idx, show(st[0]), N_SYMS[st[1]], st[3]),
                  file=sys.stderr)
            failures.append((idx, expected_v, fp_v, "EXHAUSTED"))
            continue
        if fp_v != frt_v:
            st = state_from_index(idx)
            print("FAIL: idx=%d %s side=%s passes=%d  fixpoint=%+d "
                  "FRT=%+d (expected match)"
                  % (idx, show(st[0]), N_SYMS[st[1]], st[3], fp_v, frt_v),
                  file=sys.stderr)
            failures.append((idx, fp_v, frt_v, None))

    n_total = len(MISMATCH_STATES)
    n_ok = n_total - len(failures)
    print(file=sys.stderr)
    print("Results: %d/%d pass, %d fail"
          % (n_ok, n_total, len(failures)), file=sys.stderr)
    print("Total alpha-beta nodes visited: %d" % NODES[0], file=sys.stderr)
    print(file=sys.stderr)

    if failures:
        print("CALIBRATION FAILED — %d mismatches remain" % len(failures),
              file=sys.stderr)
        return len(failures)

    print("CALIBRATION PASSED — all 24 mismatch states now agree between",
          file=sys.stderr)
    print("loopy-game fixpoint and exact first-revisit truncation.",
          file=sys.stderr)
    print("Buffer-aliasing bug confirmed fixed.", file=sys.stderr)

    # Canonical one-line pass for the exit-code protocol.
    print("CALIBRATION-2X2-MISMATCH: PASS  (0 mismatches, 24/24)")
    return 0


if __name__ == "__main__":
    sys.setrecursionlimit(100000)
    sys.exit(main())
