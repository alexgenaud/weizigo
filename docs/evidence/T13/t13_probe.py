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
#        for, no purpose fit,              #
#        'tis unmerchantable shit.         #
#    Liability for damages denied.         #
#                                          #
############################################
#
# T13 C2-pilot-3x2 -- RE-IMPLEMENTATION (2026-07-30, task T110).
#
# The original probe (`untracked/c2pilot_3x2.zig`) was swept with `untracked/`
# and cannot be recovered.  This file is an INDEPENDENT re-implementation in
# Python from two durable descriptions:
#
#   - docs/research/c2-falsification-3x2.md  (the method, the census numbers,
#     the ban-set distribution and all 12 contradiction lines)
#   - docs/epistemic/PROGRESS.md 3.1, docs/epistemic/CLAIMS.md `3x2.T13`
#
# It is a port of the Zig semantics, not of the lost probe's code: every
# primitive below is a line-by-line port of the committed source that the
# original probe called, so a disagreement between this file and T13 is a
# disagreement about the *probe*, never about the rules.
#
#   colex index         src/colex.zig      Indexer(3,2)
#   is_legal            src/enumerate.zig  Enumerator.is_legal
#   pos_from_move       src/rules.zig      Rules.pos_from_move
#   area_score          src/rules.zig      Rules.area_score
#   benson_alive        src/rules.zig      Rules.benson_alive
#   is_settled          src/rules.zig      Rules.is_settled
#   is_own_eye          src/rules.zig      Rules.is_own_eye
#   seed/sweep/         src/retro.zig      Retro(3,2).seed/sweep/converge/
#     converge/finalize                      finalize
#   ab_solve            src/retro.zig      Retro(3,2).ab_solve, with
#                                            memo=false, brackets=false,
#                                            deps=false, window [-127,127]
#
# CONVENTIONS.  Cells are row-major: 0,1,2 top row; 3,4,5 bottom row.
# A position is a 6-tuple over {+1 Black, 0 empty, -1 White}.  Scores are
# Black-positive area (Chinese) scores in -6..+6.  "colex" is the layered
# colex ADDRESS of src/colex.zig -- NOT a base-3 digit string (the QA-023
# probe family uses base-3; T13's history lines are colex).
#
# USAGE
#   python3 t13_probe.py                 # everything (~5 min)
#   python3 t13_probe.py test            # port self-tests            (<1 s)
#   python3 t13_probe.py census          # tables + census            (<1 s)
#   python3 t13_probe.py replay          # the 12 recorded lines      (<1 s)
#   python3 t13_probe.py adr0006         # eye-prune sensitivity      (~1 s)
#   python3 t13_probe.py sanity          # fresh-start over 540 slots (~7 s)
#   python3 t13_probe.py search          # T13's own step 3-5         (~7 s)
#   python3 t13_probe.py exhaustive      # every reachable history    (~5 min)
#   python3 t13_probe.py exhaustive-serial   # ditto, 1 process       (~30 min)

import os
import sys
from math import comb

W, H = 3, 2
N = W * H
UNDEF = -128

# ---- geometry ---------------------------------------------------------------

NEIGH = []
for _p in range(N):
    _r, _c = divmod(_p, W)
    _nb = []
    if _r > 0:
        _nb.append(_p - W)
    if _r + 1 < H:
        _nb.append(_p + W)
    if _c > 0:
        _nb.append(_p - 1)
    if _c + 1 < W:
        _nb.append(_p + 1)
    NEIGH.append(tuple(_nb))

EMPTY = (0,) * N

# ---- colex index (src/colex.zig) --------------------------------------------

LAYER_OFFSET = [0]
for _k in range(N + 1):
    LAYER_OFFSET.append(LAYER_OFFSET[_k] + comb(N, _k) * (1 << _k))
TOTAL = LAYER_OFFSET[N + 1]  # == 3^6 == 729
assert TOTAL == 3 ** N


def colex_from_pos(pos):
    """Board -> its serial address in 0..3^n-1.  Port of colex_from_pos."""
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
        subset += comb(cell, k)
    return LAYER_OFFSET[k] + subset * (1 << k) + colours


def pos_from_colex(idx):
    """Inverse of colex_from_pos."""
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
        while comb(cell, i) > subset:
            cell -= 1
        subset -= comb(cell, i)
        pos[cell] = 1 if (colours >> (i - 1)) & 1 else -1
    return tuple(pos)


# ---- rules (src/enumerate.zig, src/rules.zig) --------------------------------


def is_legal(pos):
    """No chain may be without a liberty.  Port of Enumerator.is_legal."""
    visited = [False] * N
    for p in range(N):
        if pos[p] == 0 or visited[p]:
            continue
        colour = pos[p]
        stack = [p]
        visited[p] = True
        has_liberty = False
        while stack:
            q = stack.pop()
            for t in NEIGH[q]:
                if pos[t] == 0:
                    has_liberty = True
                elif pos[t] == colour and not visited[t]:
                    visited[t] = True
                    stack.append(t)
        if not has_liberty:
            return False
    return True


def _chain_captured(pos, seed_cell):
    """Flood the chain at seed_cell; return (cells, has_no_liberty)."""
    colour = 1 if pos[seed_cell] > 0 else -1
    visited = [False] * N
    visited[seed_cell] = True
    stack = [seed_cell]
    chain = [seed_cell]
    has_liberty = False
    while stack:
        q = stack.pop()
        for r in NEIGH[q]:
            v = pos[r]
            if v == 0:
                has_liberty = True
            elif v != 0 and (v > 0) == (colour > 0) and not visited[r]:
                visited[r] = True
                stack.append(r)
                chain.append(r)
    return chain, (not has_liberty)


def pos_from_move(pos, colour, cell):
    """Place, capture, reject suicide.  None == illegal (Occupied|Suicide)."""
    if pos[cell] != 0:
        return None
    nxt = list(pos)
    nxt[cell] = colour
    for q in NEIGH[cell]:
        if nxt[q] * colour < 0:
            chain, captured = _chain_captured(nxt, q)
            if captured:
                for c in chain:
                    nxt[c] = 0
    _, suicide = _chain_captured(nxt, cell)
    if suicide:
        return None
    return tuple(nxt)


def area_score(board):
    """Chinese / area score, Black-positive.  Port of Rules.area_score."""
    black = 0
    white = 0
    visited = [False] * N
    for p in range(N):
        if board[p] > 0:
            black += 1
            continue
        if board[p] < 0:
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
            for r in NEIGH[q]:
                if board[r] > 0:
                    tb = True
                elif board[r] < 0:
                    tw = True
                elif not visited[r]:
                    visited[r] = True
                    stack.append(r)
        if tb and not tw:
            black += size
        if tw and not tb:
            white += size
    return black - white


def benson_alive(board, colour):
    """Benson unconditional life.  Port of Rules.benson_alive."""
    alive = [False] * N
    chain_id = [-1] * N
    num_chains = 0
    visited = [False] * N
    for p in range(N):
        if board[p] * colour <= 0 or visited[p]:
            continue
        cid = num_chains
        num_chains += 1
        visited[p] = True
        stack = [p]
        while stack:
            q = stack.pop()
            chain_id[q] = cid
            for r in NEIGH[q]:
                if board[r] * colour > 0 and not visited[r]:
                    visited[r] = True
                    stack.append(r)
    if num_chains == 0:
        return alive

    region_id = [-1] * N
    num_regions = 0
    visited = [False] * N
    for p in range(N):
        if board[p] * colour > 0 or visited[p]:
            continue
        rid = num_regions
        num_regions += 1
        visited[p] = True
        stack = [p]
        while stack:
            q = stack.pop()
            region_id[q] = rid
            for r in NEIGH[q]:
                if board[r] * colour <= 0 and not visited[r]:
                    visited[r] = True
                    stack.append(r)

    region_empty = [0] * num_regions
    borders = [[False] * num_chains for _ in range(num_regions)]
    empty_adj = [[0] * num_chains for _ in range(num_regions)]
    for p in range(N):
        ru = region_id[p]
        if ru < 0:
            continue
        if board[p] == 0:
            region_empty[ru] += 1
            seen = set()
            for r in NEIGH[p]:
                if board[r] * colour > 0:
                    cid = chain_id[r]
                    if cid not in seen:
                        seen.add(cid)
                        empty_adj[ru][cid] += 1
        for r in NEIGH[p]:
            if board[r] * colour > 0:
                borders[ru][chain_id[r]] = True

    vital = [[False] * num_chains for _ in range(num_regions)]
    for ru in range(num_regions):
        if region_empty[ru] == 0:
            continue
        for cu in range(num_chains):
            if empty_adj[ru][cu] == region_empty[ru]:
                vital[ru][cu] = True

    chain_in = [True] * num_chains
    region_in = [True] * num_regions
    changed = True
    while changed:
        changed = False
        for cu in range(num_chains):
            if not chain_in[cu]:
                continue
            vcount = sum(1 for ru in range(num_regions) if region_in[ru] and vital[ru][cu])
            if vcount < 2:
                chain_in[cu] = False
                changed = True
        for ru in range(num_regions):
            if not region_in[ru]:
                continue
            for cu in range(num_chains):
                if borders[ru][cu] and not chain_in[cu]:
                    region_in[ru] = False
                    changed = True
                    break

    for p in range(N):
        if board[p] * colour > 0 and chain_in[chain_id[p]]:
            alive[p] = True
    return alive


def is_settled(board):
    """Decided-terminal test.  Port of Rules.is_settled."""
    balive = benson_alive(board, 1)
    walive = benson_alive(board, -1)
    for p in range(N):
        if board[p] > 0 and not balive[p]:
            return False
        if board[p] < 0 and not walive[p]:
            return False
    visited = [False] * N
    for p in range(N):
        if board[p] != 0 or visited[p]:
            continue
        stack = [p]
        visited[p] = True
        tb = tw = False
        while stack:
            q = stack.pop()
            stone_nbr = False
            for r in NEIGH[q]:
                if board[r] > 0:
                    tb = True
                    stone_nbr = True
                elif board[r] < 0:
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


def is_own_eye(pos, p, colour, alive):
    """ADR-0006 eye-prune predicate.  Port of Rules.is_own_eye."""
    for q in NEIGH[p]:
        if pos[q] * colour <= 0 or not alive[q]:
            return False
    return True


# ---- the retrograde L/H tables (src/retro.zig) -------------------------------


class Tables:
    """Retro(3,2).Tables: seed -> converge -> finalize.

    lo/hi are the least/greatest fixpoints of the same Bellman map, seeded
    -n / +n on every non-settled slot.  Each has four columns: b0/w0 (no pass
    pending -- the oracle value) and b1/w1 (one pass already made).
    """

    def __init__(self):
        self.legal = [False] * TOTAL
        self.settled = [False] * TOTAL
        self.score = [0] * TOTAL
        self.lo = {c: [0] * TOTAL for c in ("b0", "w0", "b1", "w1")}
        self.hi = {c: [0] * TOTAL for c in ("b0", "w0", "b1", "w1")}
        self.vb = [UNDEF] * TOTAL
        self.vw = [UNDEF] * TOTAL
        self.ko_b = [False] * TOTAL
        self.ko_w = [False] * TOTAL
        self.sweeps = 0
        self.legal_count = 0
        self.settled_count = 0
        self.ko_sensitive_b = 0
        self.ko_sensitive_w = 0
        self.pos = [pos_from_colex(i) for i in range(TOTAL)]

    def seed(self):
        for i in range(TOTAL):
            pos = self.pos[i]
            ok = is_legal(pos)
            self.legal[i] = ok
            if not ok:
                continue
            self.legal_count += 1
            sc = area_score(pos)
            self.score[i] = sc
            st = is_settled(pos)
            self.settled[i] = st
            if st:
                self.settled_count += 1
                for q in (self.lo, self.hi):
                    for c in ("b0", "w0", "b1", "w1"):
                        q[c][i] = sc
            else:
                for q, v in ((self.lo, -N), (self.hi, N)):
                    for c in ("b0", "w0", "b1", "w1"):
                        q[c][i] = v

    def _sweep(self, q):
        """One Bellman sweep, stone-count DESCENDING (Gauss-Seidel).

        NOTE (faithful port): the retrograde sweep does NOT apply the ADR-0006
        eye-prune -- Retro.apply_eye_prune is false in the committed source --
        while ab_solve below DOES.  That asymmetry is in the Zig too.
        """
        changes = 0
        b0, w0, b1, w1 = q["b0"], q["w0"], q["b1"], q["w1"]
        for layer in range(N, -1, -1):
            for i in range(LAYER_OFFSET[layer], LAYER_OFFSET[layer + 1]):
                if not self.legal[i] or self.settled[i]:
                    continue
                pos = self.pos[i]
                for side in (1, -1):
                    maximizing = side > 0
                    have_move = False
                    m = 0
                    for p in range(N):
                        if pos[p] != 0:
                            continue
                        child = pos_from_move(pos, side, p)
                        if child is None:
                            continue
                        ci = colex_from_pos(child)
                        cv = w0[ci] if maximizing else b0[ci]
                        if not have_move:
                            m = cv
                            have_move = True
                        elif maximizing:
                            m = max(m, cv)
                        else:
                            m = min(m, cv)
                    v1 = self.score[i]
                    v0 = w1[i] if maximizing else b1[i]
                    if have_move:
                        if maximizing:
                            v1 = max(m, v1)
                            v0 = max(m, v0)
                        else:
                            v1 = min(m, v1)
                            v0 = min(m, v0)
                    a1 = b1 if maximizing else w1
                    a0 = b0 if maximizing else w0
                    if a1[i] != v1:
                        a1[i] = v1
                        changes += 1
                    if a0[i] != v0:
                        a0[i] = v0
                        changes += 1
        return changes

    def converge(self):
        self.sweeps = 0
        while True:
            c = self._sweep(self.lo) + self._sweep(self.hi)
            self.sweeps += 1
            if c == 0:
                break
            if self.sweeps >= 10000:
                raise RuntimeError("value iteration exceeded MAX_SWEEPS")

    def finalize(self):
        for i in range(TOTAL):
            if not self.legal[i]:
                continue
            if self.settled[i]:
                self.vb[i] = self.score[i]
                self.vw[i] = self.score[i]
                continue
            if self.lo["b0"][i] == self.hi["b0"][i]:
                self.vb[i] = self.lo["b0"][i]
            else:
                self.ko_b[i] = True
                self.ko_sensitive_b += 1
            if self.lo["w0"][i] == self.hi["w0"][i]:
                self.vw[i] = self.lo["w0"][i]
            else:
                self.ko_w[i] = True
                self.ko_sensitive_w += 1

    # bracket accessors, used ONLY for move ordering here (brackets=false)
    def lo_node(self, idx, side, passes):
        if passes >= 2:
            return self.score[idx]
        if passes == 0:
            return self.lo["b0"][idx] if side > 0 else self.lo["w0"][idx]
        return self.lo["b1"][idx] if side > 0 else self.lo["w1"][idx]

    def hi_node(self, idx, side, passes):
        if passes >= 2:
            return self.score[idx]
        if passes == 0:
            return self.hi["b0"][idx] if side > 0 else self.hi["w0"][idx]
        return self.hi["b1"][idx] if side > 0 else self.hi["w1"][idx]


def build_tables(verbose=True):
    t = Tables()
    t.seed()
    t.converge()
    t.finalize()
    if verbose:
        print(f"tables: legal={t.legal_count} settled={t.settled_count} "
              f"ko_sensitive_b={t.ko_sensitive_b} ko_sensitive_w={t.ko_sensitive_w} "
              f"sweeps={t.sweeps}")
    return t


def lh_slots(t):
    """The L==H slots: (idx, side) over NON-settled legal positions where the
    two fixpoints agree.  The T13 write-up counts 540 of these at 3x2."""
    out = []
    for i in range(TOTAL):
        if not t.legal[i] or t.settled[i]:
            continue
        if t.lo["b0"][i] == t.hi["b0"][i]:
            out.append((i, 1))
        if t.lo["w0"][i] == t.hi["w0"][i]:
            out.append((i, -1))
    return out


# ---- history-aware exact solve (retro.ab_solve, memo/brackets OFF) -----------


class Budget(Exception):
    pass


class Solver:
    """retro.ab_solve with ctx.memo=false, ctx.brackets=false, ctx.deps=false.

    With no memo and no bracket cuts this is plain fail-soft alpha-beta over
    the PSK game graph, which is exact: alpha-beta never changes the minimax
    value of the root, and with no cross-history reuse there is no GHI risk.
    The [L,H] tables survive only as a move-ordering heuristic (`order`), which
    cannot affect the returned value.
    """

    def __init__(self, t, budget=0, eye_prune=True):
        self.t = t
        self.budget = budget
        self.nodes = 0
        # ADR-0006 sensitivity switch.  The retrograde sweep does NOT eye-prune
        # (Retro.apply_eye_prune = false) while ab_solve DOES, so the stored
        # L==H value and the probe's history value are computed over different
        # move sets.  If ADR-0006 is wrong, that asymmetry alone could
        # manufacture a mismatch.  eye_prune=False removes the asymmetry.
        self.eye_prune = eye_prune

    def solve(self, pos, to_move, passes, alpha, beta, hist):
        t = self.t
        self.nodes += 1
        if self.budget and self.nodes > self.budget:
            raise Budget()
        idx = colex_from_pos(pos)
        if passes >= 2 or t.settled[idx]:
            return t.score[idx]

        maximizing = to_move > 0
        # gather edges: board moves (PSK-legal, eye-pruned) + the pass edge
        edges = []
        own_alive = benson_alive(pos, to_move) if self.eye_prune else None
        for p in range(N):
            if pos[p] != 0:
                continue
            if self.eye_prune and is_own_eye(pos, p, to_move, own_alive):
                continue
            child = pos_from_move(pos, to_move, p)
            if child is None:
                continue
            if child in hist:  # PSK: positional superko ban
                continue
            ci = colex_from_pos(child)
            order = t.lo_node(ci, -to_move, 0) + t.hi_node(ci, -to_move, 0)
            edges.append((order, child, False))
        order = t.lo_node(idx, -to_move, passes + 1) + t.hi_node(idx, -to_move, passes + 1)
        edges.append((order, pos, True))
        edges.sort(key=lambda e: e[0], reverse=maximizing)

        best = -127 if maximizing else 127
        for _order, child, is_pass in edges:
            if is_pass:
                v = self.solve(pos, -to_move, passes + 1, alpha, beta, hist)
            else:
                hist.append(child)
                v = self.solve(child, -to_move, 0, alpha, beta, hist)
                hist.pop()
            if maximizing:
                if v > best:
                    best = v
                if best > alpha:
                    alpha = best
            else:
                if v < best:
                    best = v
                if best < beta:
                    beta = best
            if alpha >= beta:
                break
        return best

    def value_under_history(self, pos, to_move, hist):
        """T13 step 4: full window [-127,127], history pre-populated."""
        self.nodes = 0
        return self.solve(pos, to_move, 0, -127, 127, list(hist))


# ---- step 6: fresh-start sanity ---------------------------------------------


def fresh_start_sanity(t, verbose=True):
    """Every L==H slot, solved with the history seeded only with the root.
    T13 reported 0 mismatches on all 540 slots."""
    slots = lh_slots(t)
    s = Solver(t)
    bad = []
    for idx, side in slots:
        pos = t.pos[idx]
        stored = t.vb[idx] if side > 0 else t.vw[idx]
        got = s.value_under_history(pos, side, [pos])
        if got != stored:
            bad.append((idx, side, stored, got))
    if verbose:
        print(f"fresh-start sanity: {len(bad)} mismatches / {len(slots)} L==H slots")
        for idx, side, exp, got in bad:
            print(f"  idx={idx} side={'B' if side > 0 else 'W'} expected={exp:+d} got={got:+d}")
    return len(slots), bad


# ---- steps 3-5: line enumeration + the history-aware probe -------------------


def enumerate_lines(t, max_ply=10, line_budget=2_000_000, eye_prune=False):
    """T13 step 3: PSK-legal PLACEMENT-ONLY lines (no passes) of up to
    `max_ply` positions, from every legal start position, Black to move first.

    Yields (line, side_to_move) for every prefix, `line` being the list of
    boards including the start.  `line_budget` bounds the DFS node count and
    is reported, never silently absorbed.

    NO EYE-PRUNE, deliberately, and this was got wrong once.  ADR-0006 is a
    *dominance* argument about optimal play -- filling your own Benson-alive
    eye cannot improve your area score -- so `ab_solve` may skip such moves
    when searching.  It says nothing about which lines a real game can walk
    down, and a reachable PSK history is exactly a line a real game can walk
    down.  Pruning here would silently shrink the set of histories under test.

    T13's own record proves it did not prune either: three of its twelve
    contradiction lines contain an eye-filling move and would not exist
    otherwise (`2 16 84 112 260 500 61 162 346` at ply 4, B fills cell 3 of
    `BBW/.B.`; `1 19 77 325 105 253 477 64 167 359` at ply 5; and
    `4 24 172 128 263 567 25 91 347` at ply 4).  `eye_prune=True` reproduces
    the mistake for comparison.
    """
    nodes = 0
    exhausted = False
    starts = [i for i in range(TOTAL) if t.legal[i]]
    for start in starts:
        pos0 = t.pos[start]
        stack = [(pos0, 1, [pos0])]
        while stack:
            pos, side, line = stack.pop()
            nodes += 1
            if nodes > line_budget:
                exhausted = True
                break
            yield line, side
            if len(line) >= max_ply:
                continue
            own_alive = benson_alive(pos, side) if eye_prune else None
            for p in range(N):
                if pos[p] != 0:
                    continue
                if eye_prune and is_own_eye(pos, p, side, own_alive):
                    continue
                child = pos_from_move(pos, side, p)
                if child is None:
                    continue
                if child in line:  # PSK
                    continue
                stack.append((child, -side, line + [child]))
        if exhausted:
            break
    if exhausted:
        print(f"!! line budget {line_budget} EXHAUSTED -- coverage is partial")


def probe(t, max_ply=10, line_budget=2_000_000, verbose=True):
    """T13 steps 3-5.  One history per L==H slot (the first the DFS reaches),
    which is what makes the write-up's ban-set distribution a per-slot table."""
    s = Solver(t)
    tested = {}          # (idx, side) -> line
    lines_examined = 0
    mismatches = []
    for line, side in enumerate_lines(t, max_ply, line_budget):
        lines_examined += 1
        pos = line[-1]
        idx = colex_from_pos(pos)
        if t.settled[idx]:
            continue
        stored = t.vb[idx] if side > 0 else t.vw[idx]
        if stored == UNDEF:      # ko-sensitive slot: L != H, not a C2 subject
            continue
        key = (idx, side)
        if key in tested:
            continue
        tested[key] = line
        got = s.value_under_history(pos, side, line)
        if got != stored:
            mismatches.append((idx, side, len(line), stored, got, line))

    dist = {}
    for line in tested.values():
        dist[len(line)] = dist.get(len(line), 0) + 1

    if verbose:
        print(f"lines examined        : {lines_examined}")
        print(f"histories tested      : {len(tested)}")
        print(f"history-aware mismatch: {len(mismatches)}")
        print("\nban-set size distribution (positions in line, size 1 = fresh-start)")
        print("| size | count |")
        print("|---|---|")
        for k in sorted(dist):
            print(f"| {k} | {dist[k]} |")
        print("\ncontradictions")
        for idx, side, depth, exp, got, line in sorted(
                mismatches, key=lambda m: [colex_from_pos(b) for b in m[5]]):
            hs = " ".join(str(colex_from_pos(b)) for b in line)
            print(f"idx={idx} side={'B' if side > 0 else 'W'} depth={depth} "
                  f"expected={exp:+d} got={got:+d} history={hs}")
    return tested, mismatches


def _exhaustive_one_start(args):
    """One start position's share of probe_exhaustive.  Module-level so it can
    be pickled by multiprocessing.  Returns (pairs, slots, bad, cache_size)."""
    start, max_ply = args
    t = _WORKER_TABLES
    s = Solver(t)
    cache = {}
    pairs = 0
    slots = set()
    bad = {}
    pos0 = t.pos[start]
    stack = [(pos0, 1, [pos0])]
    while stack:
        pos, side, line = stack.pop()
        idx = colex_from_pos(pos)
        if not t.settled[idx]:
            stored = t.vb[idx] if side > 0 else t.vw[idx]
            if stored != UNDEF:
                slots.add((idx, side))
                pairs += 1
                key = (pos, side, frozenset(line))
                got = cache.get(key)
                if got is None:
                    got = s.value_under_history(pos, side, line)
                    cache[key] = got
                if got != stored:
                    bad.setdefault((idx, side), []).append((stored, got, len(line)))
        if len(line) >= max_ply:
            continue
        for p in range(N):
            if pos[p] != 0:
                continue
            child = pos_from_move(pos, side, p)
            if child is None or child in line:
                continue
            stack.append((child, -side, line + [child]))
    return pairs, slots, bad, len(cache)


_WORKER_TABLES = None


def _worker_init():
    global _WORKER_TABLES
    _WORKER_TABLES = build_tables(verbose=False)


def probe_exhaustive_parallel(t, max_ply=10, jobs=None, verbose=True):
    """probe_exhaustive across processes, one task per start position.

    Every reported quantity is an aggregate over all (slot, history) pairs, so
    it is independent of the order the pairs are visited -- the split is safe.
    Verified against the serial implementation, which is kept below as the
    reference.
    """
    import multiprocessing as mp

    starts = [i for i in range(TOTAL) if t.legal[i]]
    if jobs is None:
        jobs = max(1, (os.cpu_count() or 2) - 1)
    pairs_tested = 0
    slots_seen = set()
    bad_slots = {}
    cache_total = 0
    with mp.Pool(jobs, initializer=_worker_init) as pool:
        for pairs, slots, bad, csize in pool.imap_unordered(
                _exhaustive_one_start, [(s, max_ply) for s in starts], chunksize=8):
            pairs_tested += pairs
            slots_seen |= slots
            cache_total += csize
            for k, v in bad.items():
                bad_slots.setdefault(k, []).extend(v)
    bad_pairs = sum(len(v) for v in bad_slots.values())
    if verbose:
        _report_exhaustive(t, pairs_tested, cache_total, slots_seen,
                           bad_pairs, bad_slots, jobs)
    return slots_seen, bad_pairs, bad_slots


def _report_exhaustive(t, pairs_tested, cache_total, slots_seen,
                       bad_pairs, bad_slots, jobs=None):
    all_slots = lh_slots(t)
    print(f"(slot, history) pairs tested : {pairs_tested}")
    print(f"distinct ban-sets solved     : {cache_total}"
          + (f"  (summed over {jobs} workers)" if jobs else ""))
    print(f"L==H slots reached           : {len(slots_seen)} / {len(all_slots)}")
    print(f"falsifying (slot, history) pairs : {bad_pairs}")
    print(f"L==H slots with >=1 falsifying history : {len(bad_slots)}"
          f"  ({100.0 * len(bad_slots) / max(1, len(slots_seen)):.1f}% of reached)")
    vals = sorted({g for rows in bad_slots.values() for _s, g, _l in rows})
    print(f"distinct falsifying values seen : {', '.join(f'{v:+d}' for v in vals)}")
    print("\n| idx | side | board | stored | falsifying values seen | "
          "falsifying histories | shortest |")
    print("|---|---|---|---|---|---|---|")
    for (idx, side), rows in sorted(bad_slots.items()):
        seen = sorted({r[1] for r in rows})
        shortest = min(r[2] for r in rows)
        print(f"| {idx} | {'B' if side > 0 else 'W'} | `{fmt_board(t.pos[idx])}` | "
              f"{rows[0][0]:+d} | {', '.join(f'{v:+d}' for v in seen)} | "
              f"{len(rows)} | {shortest} |")


def probe_exhaustive(t, max_ply=10, line_budget=2_000_000, verbose=True):
    """The ORDER-INDEPENDENT measurement T13 did not make.

    T13 (and `probe()` above) tests ONE history per L==H slot -- whichever the
    enumeration reaches first -- so its "12 mismatches" counts falsifying
    (slot, history) PAIRS drawn from an order-dependent sample of 508.  Here
    every reachable history of every slot is tested, and the reported quantity
    is the number of L==H SLOTS admitting at least one falsifying history.
    That number does not depend on enumeration order.

    The root-level cache is keyed on (pos, side, frozenset(history)): the
    search reads the history only through a membership test, so two histories
    with the same board SET pose the same question.  It is a de-duplication of
    identical queries, not a cross-history memo -- the inner search stays
    memo-free.
    """
    s = Solver(t)
    cache = {}
    pairs_tested = 0
    slots_seen = set()
    bad_pairs = []
    bad_slots = {}
    for line, side in enumerate_lines(t, max_ply, line_budget):
        pos = line[-1]
        idx = colex_from_pos(pos)
        if t.settled[idx]:
            continue
        stored = t.vb[idx] if side > 0 else t.vw[idx]
        if stored == UNDEF:
            continue
        slots_seen.add((idx, side))
        pairs_tested += 1
        key = (pos, side, frozenset(line))
        got = cache.get(key)
        if got is None:
            got = s.value_under_history(pos, side, line)
            cache[key] = got
        if got != stored:
            bad_pairs.append((idx, side, len(line), stored, got, line))
            bad_slots.setdefault((idx, side), []).append((stored, got, line))

    if verbose:
        print(f"(slot, history) pairs tested : {pairs_tested}")
        print(f"distinct ban-sets solved     : {len(cache)}")
        print(f"L==H slots reached           : {len(slots_seen)} / {len(lh_slots(t))}")
        print(f"falsifying (slot, history) pairs : {len(bad_pairs)}")
        print(f"L==H slots with >=1 falsifying history : {len(bad_slots)}")
        print("\n| idx | side | board | stored | falsifying values seen | "
              "falsifying histories | shortest |")
        print("|---|---|---|---|---|---|---|")
        for (idx, side), rows in sorted(bad_slots.items()):
            vals = sorted({r[1] for r in rows})
            shortest = min(len(r[2]) for r in rows)
            print(f"| {idx} | {'B' if side > 0 else 'W'} | `{fmt_board(t.pos[idx])}` | "
                  f"{rows[0][0]:+d} | {', '.join(f'{v:+d}' for v in vals)} | "
                  f"{len(rows)} | {shortest} |")
    return slots_seen, bad_pairs, bad_slots


# ---- the 12 recorded contradictions -----------------------------------------

RECORDED = [
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


def adr0006_sensitivity(t, verbose=True):
    """Is the falsification an artefact of the ADR-0006 eye-prune?

    `ADR0006-FALSIFY` records the worry directly: every forward search the
    project treats as ground truth applies the prune, T13 included, so if
    ADR-0006 is wrong then T13 is contaminated.  Here each recorded line is
    re-solved with the prune OFF, which makes the probe's move set identical
    to the retrograde sweep's.  A counterexample that survives both settings
    does not depend on ADR-0006.
    """
    on = Solver(t, eye_prune=True)
    off = Solver(t, eye_prune=False)
    rows = []
    for idx, side, depth, exp, got, hist_idx in RECORDED:
        pos = pos_from_colex(hist_idx[-1])
        boards = [pos_from_colex(i) for i in hist_idx]
        stored = t.vb[idx] if side > 0 else t.vw[idx]
        v_on = on.value_under_history(pos, side, boards)
        v_off = off.value_under_history(pos, side, boards)
        f_on = on.value_under_history(pos, side, [pos])
        f_off = off.value_under_history(pos, side, [pos])
        rows.append((idx, side, stored, v_on, v_off, f_on, f_off))
    if verbose:
        print("| idx | side | stored | history value (prune on) | (prune off) | "
              "fresh (prune on) | (prune off) | still a counterexample |")
        print("|---|---|---|---|---|---|---|---|")
        for idx, side, stored, v_on, v_off, f_on, f_off in rows:
            survives = v_off != stored and f_off == stored
            print(f"| {idx} | {'B' if side > 0 else 'W'} | {stored:+d} | {v_on:+d} | "
                  f"{v_off:+d} | {f_on:+d} | {f_off:+d} | "
                  f"{'yes' if survives else 'NO'} |")
        n_surv = sum(1 for r in rows if r[4] != r[2] and r[5] == r[2])
        n_same = sum(1 for r in rows if r[3] == r[4] and r[5] == r[6])
        print(f"\ncounterexamples surviving with the eye-prune OFF: {n_surv}/{len(rows)}")
        print(f"values unchanged by the prune setting: {n_same}/{len(rows)}")
    return rows


def fmt_board(pos):
    ch = {1: "B", -1: "W", 0: "."}
    return "/".join("".join(ch[pos[r * W + c]] for c in range(W)) for r in range(H))


def check_line_wellformed(t, hist_idx, side):
    """Is the recorded history a legal placement-only PSK line, and does its
    parity agree with the recorded side to move?  Returns (ok, notes)."""
    notes = []
    boards = [pos_from_colex(i) for i in hist_idx]
    for i, b in zip(hist_idx, boards):
        if not t.legal[i]:
            notes.append(f"position {i} is ILLEGAL")
    mover = 1
    for k in range(len(boards) - 1):
        cur, nxt = boards[k], boards[k + 1]
        found = None
        for p in range(N):
            if cur[p] != 0:
                continue
            child = pos_from_move(cur, mover, p)
            if child == nxt:
                found = p
                break
        if found is None:
            notes.append(f"ply {k}->{k+1}: no {'B' if mover > 0 else 'W'} placement "
                         f"maps {hist_idx[k]} to {hist_idx[k+1]}")
            return False, notes
        if nxt in boards[:k + 1]:
            notes.append(f"ply {k+1}: PSK repeat")
            return False, notes
        mover = -mover
    if mover != side:
        notes.append(f"parity: line implies {'B' if mover > 0 else 'W'} to move, "
                     f"record says {'B' if side > 0 else 'W'}")
        return False, notes
    return True, notes


def replay_recorded(t, verbose=True):
    """Re-execute each recorded contradiction line verbatim."""
    s = Solver(t)
    rows = []
    for idx, side, depth, exp, got, hist_idx in RECORDED:
        pos = pos_from_colex(hist_idx[-1])
        boards = [pos_from_colex(i) for i in hist_idx]
        ok, notes = check_line_wellformed(t, hist_idx, side)
        stored = t.vb[idx] if side > 0 else t.vw[idx]
        lh = (t.lo["b0"][idx] == t.hi["b0"][idx]) if side > 0 else \
             (t.lo["w0"][idx] == t.hi["w0"][idx])
        mine = s.value_under_history(pos, side, boards)
        fresh = s.value_under_history(pos, side, [pos])
        rows.append({
            "idx": idx, "side": side, "depth": depth,
            "rec_expected": exp, "rec_got": got,
            "tail_idx_ok": colex_from_pos(pos) == idx,
            "line_ok": ok, "notes": notes,
            "is_lh": lh, "stored": stored,
            "mine": mine, "fresh": fresh,
            "board": fmt_board(pos),
        })
    if verbose:
        print("| idx | side | depth | board | L==H | stored | T13 expected | T13 got | "
              "re-impl got | fresh-start | line legal |")
        print("|---|---|---|---|---|---|---|---|---|---|---|")
        for r in rows:
            print(f"| {r['idx']} | {'B' if r['side'] > 0 else 'W'} | {r['depth']} | "
                  f"`{r['board']}` | {'yes' if r['is_lh'] else 'NO'} | "
                  f"{r['stored']:+d} | {r['rec_expected']:+d} | {r['rec_got']:+d} | "
                  f"{r['mine']:+d} | {r['fresh']:+d} | "
                  f"{'yes' if r['line_ok'] else 'NO'} |")
        agree = sum(1 for r in rows if r["mine"] == r["rec_got"]
                    and r["stored"] == r["rec_expected"] and r["line_ok"])
        contradicts = sum(1 for r in rows if r["mine"] != r["stored"])
        print(f"\nreproduced exactly (line legal, stored==expected, value==got): "
              f"{agree}/{len(rows)}")
        print(f"still a C2 counterexample under this re-implementation "
              f"(history value != stored L==H value): {contradicts}/{len(rows)}")
        for r in rows:
            for note in r["notes"]:
                print(f"  note idx={r['idx']}: {note}")
    return rows


# ---- self-tests --------------------------------------------------------------


def self_test():
    """Cheap invariants that would catch a port error before it becomes a
    finding.  Each is checkable by hand against the Zig."""
    ok = True

    # colex is a bijection over the whole 3^n space
    seen = set()
    for i in range(TOTAL):
        p = pos_from_colex(i)
        assert colex_from_pos(p) == i, f"round trip {i}"
        seen.add(p)
    assert len(seen) == TOTAL
    print(f"self-test: colex bijection over all {TOTAL} boards OK")

    # colour-bit convention from src/colex.zig's own test, on this board
    assert colex_from_pos((0,) * N) == 0
    ww = colex_from_pos((-1, -1, 0, 0, 0, 0))
    bw = colex_from_pos((1, -1, 0, 0, 0, 0))
    wb = colex_from_pos((-1, 1, 0, 0, 0, 0))
    bb = colex_from_pos((1, 1, 0, 0, 0, 0))
    assert bw == ww + 1 and wb == ww + 2 and bb == ww + 3
    print("self-test: colour-bit convention OK")

    # capture and suicide
    #   . . .      W B .        B B .
    #   . . .  ->  B . .   :  B at 3 captures W at 0
    b = (-1, 1, 0, 0, 0, 0)
    after = pos_from_move(b, 1, 3)
    assert after == (0, 1, 0, 1, 0, 0), after
    # White alone into a Black-surrounded point is suicide
    b = (0, 1, 0, 1, 0, 0)
    assert pos_from_move(b, -1, 0) is None
    print("self-test: capture / suicide OK")

    # area score: a lone Black stone owns the whole 3x2 board
    one = (0, 1, 0, 0, 0, 0)
    assert area_score(one) == N, area_score(one)
    assert area_score(EMPTY) == 0
    print("self-test: area_score OK")

    # is_legal rejects a zero-liberty chain
    assert not is_legal((-1, 1, 0, 1, 0, 0))
    assert is_legal(EMPTY)
    print("self-test: is_legal OK")
    return ok


# ---- driver ------------------------------------------------------------------


def main():
    what = sys.argv[1] if len(sys.argv) > 1 else "all"
    if what in ("all", "test"):
        self_test()
        print()
    t = build_tables()
    slots = lh_slots(t)
    print(f"L==H slots (non-settled legal x side): {len(slots)}")
    print()
    if what in ("all", "census"):
        if what == "census":
            return
    if what in ("all", "replay"):
        print("== step 7: the 12 recorded contradictions, replayed ==")
        replay_recorded(t)
        print()
    if what in ("all", "adr0006"):
        print("== robustness: does the falsification depend on ADR-0006? ==")
        adr0006_sensitivity(t)
        print()
    if what in ("all", "sanity"):
        print("== step 6: fresh-start sanity ==")
        fresh_start_sanity(t)
        print()
    if what in ("all", "search"):
        print("== steps 3-5: independent line enumeration + history-aware probe ==")
        probe(t)
        print()
    if what in ("all", "exhaustive"):
        print("== extension: every reachable history, not one per slot ==")
        probe_exhaustive_parallel(t)
        print()
    if what == "exhaustive-serial":
        print("== extension (serial reference implementation) ==")
        probe_exhaustive(t)
        print()


if __name__ == "__main__":
    main()
