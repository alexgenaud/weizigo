#!/usr/bin/env python3
############################################
#                                          #
#    (c) 2026 Alexander E Genaud           #
#                                          #
#    Permission is granted hereby,         #
#    to copy, share, use, modify,          #
#        for purposes any,                 #
#        for free or for money,            #
#    provided these notices multiply.      #
#                                          #
#    This work "as is" I provide,          #
#    no warranty express or implied,       #
#    for, no purpose fit,                  #
#    'tis unmerchantable shit.             #
#    Liability for damages denied.         #
#                                          #
############################################
#
# AUDIT-2X2-MISMATCH — independent reimplementation of the EXP-4 2x2 solver.
#
# Task: AUDIT-2X2-MISMATCH · Role: auditor · Model: Opus 5 · Date: 2026-07-30
#
# EXP-4 (docs/research/newrule-2x2-3x2-2026-07-28.md) reported 24 of 172
# reachable non-terminal 2x2 states where the loopy-game Bellman fixpoint
# gives +-4 but the "first-revisit truncation" brute-force gives 0, and
# interpreted the gap as *genuine semantic divergence*. This script is the
# adversarial cross-check the note itself asked for (its section 10):
# rules, state encoding, fixpoint, and truncation evaluator all rewritten
# from the specification, in a different language, with no shared code.
#
# It computes, for every reachable 2x2 state:
#   A. L / H / V = median(L, TIE, H)      -- loopy-game fixpoint
#   B. FRT(s)                             -- first-revisit truncation, correct
#   C. FRT_buggy(s)                       -- emulation of the ONE shared
#                                            successor buffer that
#                                            src/exp4_solve.zig threads
#                                            through its recursion
#
# Run: python3 docs/audits/2026-07-30-audit-2x2-mismatch.py

import sys

# ---------------------------------------------------------------------------
# Board: 2x2, cells row-major   0 1
#                               2 3
# The adjacency graph is the 4-cycle 0-1-3-2-0. Cells 0 and 3 are NOT
# adjacent, nor are 1 and 2 (they are diagonal).
# ---------------------------------------------------------------------------
N = 4
ADJ = {0: (1, 2), 1: (0, 3), 2: (0, 3), 3: (1, 2)}

EMPTY, BLACK, WHITE = 0, 1, -1
KO_NONE = 255
TIE = 0

SYM = {BLACK: "B", WHITE: "W", EMPTY: "."}


def show(board):
    return "%s%s/%s%s" % tuple(SYM[c] for c in board)


# ---------------------------------------------------------------------------
# Rules
# ---------------------------------------------------------------------------
def chain(board, seed):
    """Return (cells of the chain containing seed, has_liberty)."""
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
    """No chain on the board may be without liberties."""
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
    """Place `colour` at `cell`. Returns new board, or None if illegal
    (occupied / suicide). Opponent chains without liberties are removed
    first, then suicide is tested."""
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
        return None  # suicide
    return tuple(nxt)


def area_score(board):
    """Area scoring: stones plus empty regions bordering exactly one colour."""
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
# State = (board, side, ko, passes);  ko in 0..3 or KO_NONE
# ---------------------------------------------------------------------------
def apply_place(st, cell):
    board, side, ko, passes = st
    if board[cell] != EMPTY:
        return None
    if ko != KO_NONE and cell == ko:
        return None  # basic ko, formalization (i)
    nxt = pos_from_move(board, side, cell)
    if nxt is None:
        return None
    # New ko point: exactly one opposing stone removed, AND the placed stone
    # is a lone stone whose only liberty is the vacated cell.
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
    board, side, ko, passes = st
    if passes >= 2:
        return None
    return (board, -side, KO_NONE, passes + 1)


def successors(st):
    """Move order EXACTLY as src/exp4_solve.zig: pass first, then cells 0..3."""
    out = []
    p = apply_pass(st)
    if p is not None:
        out.append(("pass", p))
    for cell in range(N):
        c = apply_place(st, cell)
        if c is not None:
            out.append(("place %d" % cell, c))
    return out


def is_terminal(st):
    return st[3] == 2


def terminal_value(st):
    return area_score(st[0])


# ---------------------------------------------------------------------------
# Index encoding, byte-for-byte as src/qa023_brute_2x2.zig
#   idx = (passes*2*(n+1) + side_bit*(n+1) + ko_idx) * 81 + board_index
# ---------------------------------------------------------------------------
TOTAL_STATES = 81 * 2 * (N + 1) * 3  # 1620


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
# Reachability from the two roots (mirrors exp4_solve.zig PART 1)
# ---------------------------------------------------------------------------
EMPTY_BOARD = (EMPTY,) * N
ROOT_B = (EMPTY_BOARD, BLACK, KO_NONE, 0)
ROOT_W = (EMPTY_BOARD, WHITE, KO_NONE, 0)


def reachable():
    seen, stack = set(), [ROOT_B, ROOT_W]
    seen.add(ROOT_B)
    seen.add(ROOT_W)
    while stack:
        st = stack.pop()
        for _, ns in successors(st):
            if ns not in seen:
                seen.add(ns)
                stack.append(ns)
    return seen


# ---------------------------------------------------------------------------
# Flattened graph over integer indices. The tables below are built from the
# rule functions above; everything after this point works on `int` state
# indices so the deep searches run at tolerable speed.
#   SUCC[idx]  = tuple of child indices, in exp4_solve.zig's move order
#   MOVE[idx]  = tuple of matching move names
#   TERM[idx]  = True if passes == 2
#   AREA[idx]  = area score of the goban
#   MAXING[idx]= True if Black (maximizer) to move
# ---------------------------------------------------------------------------
SUCC = [()] * TOTAL_STATES
MOVE = [()] * TOTAL_STATES
TERM = [False] * TOTAL_STATES
AREA = [0] * TOTAL_STATES
MAXING = [False] * TOTAL_STATES


def build_tables(states):
    for st in states:
        i = global_index(st)
        TERM[i] = is_terminal(st)
        AREA[i] = area_score(st[0])
        MAXING[i] = st[1] == BLACK
        kids = successors(st)
        MOVE[i] = tuple(m for m, _ in kids)
        SUCC[i] = tuple(global_index(ns) for _, ns in kids)


# ---------------------------------------------------------------------------
# A. Loopy-game fixpoint: L seeded at -n (ascending), H at +n (descending),
#    SAME Bellman operator (ADR-0009); V = median(L, TIE, H).
# ---------------------------------------------------------------------------
def fixpoint(order):
    L = [-N] * TOTAL_STATES
    H = [+N] * TOTAL_STATES
    for i in order:
        if TERM[i]:
            L[i] = H[i] = AREA[i]
    sweeps = 0
    while True:
        sweeps += 1
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
            if bl is not None and bl != L[i]:
                L[i] = bl
                changed += 1
            if bh is not None and bh != H[i]:
                H[i] = bh
                changed += 1
        if changed == 0:
            break
        if sweeps > 200:
            raise RuntimeError("fixpoint did not converge")
    return L, H, sweeps


def median(l, h):
    return max(l, min(TIE, h))


# ---------------------------------------------------------------------------
# B. First-revisit truncation, correctly implemented: each recursion level
#    reads its OWN successor tuple. A state already on the current path
#    evaluates to TIE.
# ---------------------------------------------------------------------------
NODES = [0]


def frt(i, on_path, depth=0):
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
    maximizing = MAXING[i]
    best = None
    for c in SUCC[i]:  # private, immutable tuple -- cannot be clobbered
        v = frt(c, on_path, depth + 1)
        if best is None or (v > best if maximizing else v < best):
            best = v
    on_path[i] = 0
    return AREA[i] if best is None else best


# ---------------------------------------------------------------------------
# C. Emulation of the exp4_solve.zig defect.
#
#    fn brute_value_2x2(..., succs_buf: *[5]Brute2x2.State) ?i8 {
#        ... writes succs_buf[0..m] with this node's children ...
#        for (succs_buf[0..m]) |child| {
#            const v = brute_value_2x2(child, ..., succs_buf);   <-- SAME buffer
#        }
#    }
#
#    Zig's `for` over a slice loads element i at iteration i, so every child
#    after the first is read back AFTER the recursive call has overwritten
#    the buffer with a deeper node's children. One buffer is shared by the
#    whole recursion; there is no per-frame copy. We model it with a single
#    5-slot list.
# ---------------------------------------------------------------------------
SUCCS_BUF = [0] * 5


def frt_buggy(i, on_path, depth=0):
    NODES[0] += 1
    if on_path[i]:
        return TIE
    if TERM[i]:
        return AREA[i]
    if depth > 128:
        return TIE
    on_path[i] = 1
    kids = SUCC[i]
    m = len(kids)
    for k in range(m):
        SUCCS_BUF[k] = kids[k]  # write children into the SHARED buffer
    maximizing = MAXING[i]
    best = None
    for k in range(m):
        child = SUCCS_BUF[k]  # re-read: may have been clobbered below
        v = frt_buggy(child, on_path, depth + 1)
        if best is None or (v > best if maximizing else v < best):
            best = v
    on_path[i] = 0
    return AREA[i] if best is None else best


def fresh():
    return bytearray(TOTAL_STATES)


# ---------------------------------------------------------------------------
# B'. Exact first-revisit truncation with alpha-beta.
#
#     Plain FRT (above) does not fit in any reasonable node budget on 2x2 --
#     it enumerates simple paths, not states. Alpha-beta is sound here:
#     FRT is a plain minimax over a (path, state) tree, pruning only skips
#     subtrees, and there is no transposition table, so no path-dependent
#     value is ever reused across paths. With a full window the root value
#     is exact whatever the move order; ordering only changes node count.
#     Children are tried most-material-favourable first -- a heuristic read
#     off the goban alone, independent of the fixpoint tables.
# ---------------------------------------------------------------------------
MATERIAL = [0] * TOTAL_STATES
ORDERED = [()] * TOTAL_STATES


def build_ordering(order):
    for i in order:
        MATERIAL[i] = sum(state_from_index(i)[0])
    for i in order:
        kids = list(zip(MOVE[i], SUCC[i]))
        kids.sort(key=lambda mc: MATERIAL[mc[1]], reverse=MAXING[i])
        ORDERED[i] = tuple(kids)


class Exhausted(Exception):
    pass


BUDGET = [0]


def frt_ab(i, on_path, alpha, beta, depth=0):
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
        for _, c in ORDERED[i]:
            v = frt_ab(c, on_path, alpha, beta, depth + 1)
            if best is None or v > best:
                best = v
            if best > alpha:
                alpha = best
            if alpha >= beta:
                break
    else:
        for _, c in ORDERED[i]:
            v = frt_ab(c, on_path, alpha, beta, depth + 1)
            if best is None or v < best:
                best = v
            if best < beta:
                beta = best
            if alpha >= beta:
                break
    on_path[i] = 0
    return AREA[i] if best is None else best


def frt_exact(i, budget=200_000_000):
    """Exact FRT value, or None if the budget ran out."""
    BUDGET[0] = budget
    try:
        return frt_ab(i, fresh(), -5, 5)
    except Exhausted:
        return None


# ---------------------------------------------------------------------------
# Principal-variation trace, for the hand-verification write-up.
# ---------------------------------------------------------------------------
def pv(i, on_path=None, depth=0, out=None):
    """Best line under first-revisit truncation, as a list of
    (move name, child index, value) triples."""
    if on_path is None:
        on_path, out = fresh(), []
    if on_path[i] or depth > 40 or TERM[i]:
        return out
    on_path[i] = 1
    maximizing = MAXING[i]
    best = best_mv = best_ns = None
    for mv, c in zip(MOVE[i], SUCC[i]):
        BUDGET[0] = 200_000_000
        v = frt_ab(c, bytearray(on_path), -5, 5, depth + 1)
        if best is None or (v > best if maximizing else v < best):
            best, best_mv, best_ns = v, mv, c
    out.append((best_mv, best_ns, best))
    pv(best_ns, on_path, depth + 1, out)
    on_path[i] = 0
    return out


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
REPORTED = [
    (329, 4), (331, 4), (335, 4), (343, 4), (357, 4), (369, 4), (381, 4),
    (387, 4), (734, -4), (736, -4), (740, -4), (748, -4), (762, -4),
    (774, -4), (786, -4), (792, -4), (1141, 4), (1153, 4), (1191, 4),
    (1197, 4), (1544, -4), (1550, -4), (1572, -4), (1584, -4),
]

TRACE_TARGETS = [329, 734, 1141]

CHECKPOINT = "/tmp/audit-2x2-mismatch.log"


def ck(fh, msg):
    print(msg)
    fh.write(msg + "\n")
    fh.flush()


def main():
    fh = open(CHECKPOINT, "w")
    ck(fh, "# AUDIT-2X2-MISMATCH — independent Python verifier")
    ck(fh, "# Opus 5 · 2026-07-30 · cross-check of EXP-4 (DSPro) 2x2 mismatches")
    ck(fh, "")

    # --- encoding round-trip: our encoder must agree with the Zig one ------
    bad = [i for i in range(TOTAL_STATES) if global_index(state_from_index(i)) != i]
    ck(fh, "## 0. encoding round-trip over all %d indices: %s"
        % (TOTAL_STATES, "OK" if not bad else "FAIL %s" % bad[:5]))

    # --- reachability ------------------------------------------------------
    states = sorted(reachable(), key=global_index)
    build_tables(states)
    order = [global_index(s) for s in states]
    nonterm = [i for i in order if not TERM[i]]
    term = [i for i in order if TERM[i]]
    ck(fh, "## 1. reachable states: %d  (non-terminal %d, terminal %d)"
        % (len(order), len(nonterm), len(term)))
    ck(fh, "#    EXP-4 reported: 258 (172 non-terminal, 86 terminal)  -> %s"
        % ("MATCH" if (len(order), len(nonterm), len(term)) == (258, 172, 86)
           else "DIVERGENT"))

    # --- fixpoint ---------------------------------------------------------
    L, H, sweeps = fixpoint(order)
    ck(fh, "## 2. fixpoint converged in %d sweeps" % sweeps)
    for nm, r in (("empty B", global_index(ROOT_B)), ("empty W", global_index(ROOT_W))):
        ck(fh, "#    root %s: L=%+d H=%+d V=%+d"
            % (nm, L[r], H[r], median(L[r], H[r])))

    # Bellman self-consistency of our own tables.
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
    ck(fh, "#    self-consistency: L=Phi(L) failures=%d  H=Phi(H) failures=%d"
        % (lf, hf))

    # --- plain FRT is intractable: show that on one state -------------------
    build_ordering(order)
    ck(fh, "")
    ck(fh, "## 3a. plain (un-pruned, exp4 move order) FRT at exp4's own 500k budget")
    n_exh = 0
    for probe in nonterm:
        BUDGET[0] = 500_000
        NODES[0] = 0
        try:
            frt(probe, fresh())
        except Exhausted:
            n_exh += 1
    ck(fh, "#    exhausted 500k nodes on %d of %d non-terminal states"
        % (n_exh, len(nonterm)))
    ck(fh, "#    -> EXP-4 reported '2x2 budget-exhausted: 0' at this very budget.")
    ck(fh, "#       A correctly-implemented first-revisit-truncation search cannot")
    ck(fh, "#       resolve these states within it; the shared buffer was collapsing")
    ck(fh, "#       the tree as well as corrupting the values.")

    # --- exact FRT vs fixpoint over ALL reachable non-terminals -------------
    ck(fh, "")
    ck(fh, "## 3b. exact FRT (alpha-beta) vs fixpoint (all %d non-terminals)"
        % len(nonterm))
    mism_correct = []
    exhausted = []
    NODES[0] = 0
    for i in nonterm:
        v_fp = median(L[i], H[i])
        v_frt = frt_exact(i)
        if v_frt is None:
            exhausted.append(i)
        elif v_fp != v_frt:
            mism_correct.append((i, v_fp, v_frt))
    ck(fh, "#    nodes visited: %d" % NODES[0])
    ck(fh, "#    budget-exhausted: %d" % len(exhausted))
    ck(fh, "#    mismatches: %d" % len(mism_correct))
    for i, a, b in mism_correct[:24]:
        st = state_from_index(i)
        ck(fh, "#      idx=%d %s side=%s passes=%d  fixpoint=%+d frt=%+d"
            % (i, show(st[0]), SYM[st[1]], st[3], a, b))

    # --- buggy (shared-buffer) FRT vs fixpoint -----------------------------
    ck(fh, "")
    ck(fh, "## 4. shared-successor-buffer emulation vs fixpoint")
    mism_buggy = {}
    NODES[0] = 0
    for i in nonterm:
        v_fp = median(L[i], H[i])
        for k in range(5):
            SUCCS_BUF[k] = 0
        v_bug = frt_buggy(i, fresh())
        if v_fp != v_bug:
            mism_buggy[i] = (v_fp, v_bug)
    ck(fh, "#    nodes visited: %d" % NODES[0])
    ck(fh, "#    mismatches: %d  (EXP-4 reported 24)" % len(mism_buggy))
    got = sorted(mism_buggy.keys())
    want = sorted(i for i, _ in REPORTED)
    ck(fh, "#    index set identical to EXP-4's: %s" % (got == want))
    if got != want:
        ck(fh, "#      only here : %s" % sorted(set(got) - set(want)))
        ck(fh, "#      only EXP-4: %s" % sorted(set(want) - set(got)))
    vals_ok = all(mism_buggy[i][0] == fpv and mism_buggy[i][1] == 0
                  for i, fpv in REPORTED if i in mism_buggy)
    ck(fh, "#    per-state values identical to EXP-4's (fixpoint=+-4, brute=0): %s"
        % vals_ok)
    for i in got:
        a, b = mism_buggy[i]
        st = state_from_index(i)
        ck(fh, "#      idx=%d %s side=%s passes=%d  fixpoint=%+d buggy_brute=%+d"
            % (i, show(st[0]), SYM[st[1]], st[3], a, b))

    # --- hand traces -------------------------------------------------------
    for i in TRACE_TARGETS:
        st = state_from_index(i)
        ck(fh, "")
        ck(fh, "## TRACE idx=%d  board=%s  side=%s  ko=%s  passes=%d"
            % (i, show(st[0]), SYM[st[1]],
               "none" if st[2] == KO_NONE else st[2], st[3]))
        ck(fh, "#    L=%+d H=%+d V=median=%+d   |   FRT(exact)=%+d"
            % (L[i], H[i], median(L[i], H[i]), frt_exact(i)))
        for k in range(5):
            SUCCS_BUF[k] = 0
        ck(fh, "#    FRT(shared-buffer emulation)=%+d" % frt_buggy(i, fresh()))
        ck(fh, "#    children (exp4 move order):")
        for mv, c in zip(MOVE[i], SUCC[i]):
            cs = state_from_index(c)
            ck(fh, "#      %-9s -> %s side=%s ko=%s passes=%d  V=%+d FRT=%+d"
                % (mv, show(cs[0]), SYM[cs[1]],
                   "none" if cs[2] == KO_NONE else cs[2], cs[3],
                   median(L[c], H[c]), frt_exact(c)))
        ck(fh, "#    principal variation (exact FRT):")
        cur = i
        for mv, c, v in pv(i):
            ck(fh, "#      %s plays %-9s -> %s passes=%d  (value %+d)"
                % (SYM[state_from_index(cur)[1]], mv,
                   show(state_from_index(c)[0]), state_from_index(c)[3], v))
            cur = c
        ck(fh, "#      terminal area score = %+d" % AREA[cur])
        ck(fh, "#    CHECKPOINT idx=%d verified" % i)

    # --- the disputed anchor ----------------------------------------------
    ck(fh, "")
    ck(fh, "## 5. the '1-ko shape' anchor asserted as 0 in src/qa023_brute_2x2.zig")
    anchor = global_index(((WHITE, BLACK, EMPTY, EMPTY), WHITE, KO_NONE, 0))
    ck(fh, "#    board=W B/. . side=W passes=0 -> idx=%d" % anchor)
    ck(fh, "#    fixpoint V=%+d   exact FRT=%+d   asserted expectation=0"
        % (median(L[anchor], H[anchor]), frt_exact(anchor)))

    ck(fh, "")
    ck(fh, "# VERDICT: exact-FRT vs fixpoint mismatches = %d (budget-exhausted %d);"
        % (len(mism_correct), len(exhausted)))
    ck(fh, "#          shared-buffer-FRT vs fixpoint mismatches = %d (index set match: %s)"
        % (len(mism_buggy), got == want))
    fh.close()
    return 0


if __name__ == "__main__":
    sys.setrecursionlimit(100000)
    sys.exit(main())
