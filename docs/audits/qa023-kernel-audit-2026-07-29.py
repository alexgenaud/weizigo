#!/usr/bin/env python3
"""
QA023-KERNEL-AUDIT set B · Kimi-K2.7/QA023
Independent Python verifier for the fixpoint_kernel defect in src/qa023_probe.zig.

Reimplements from scratch:
  - 3x2 basic-ko rules (Tromp-Taylor area score, single-stone ko formalization i)
  - reachable (board, side, ko, passes) census from the four roots
  - as-shipped fixpoint_kernel (monotone-ascend L / monotone-descend H, wrong White guards)
  - corrected fixpoint_kernel (Black max / White min in BOTH, unconditional update)
  - pin census, Bellman residual, colour-inversion violations
  - single-successor check for the seven hand-adjudicated C2 states
  - budgeted first-revisit-truncation evaluator (alpha-beta) for spot C2 checks
  - 2x2 corrected fixpoint for cross-check against smoke_fixpoint_2x2

No Zig code is imported; the only shared assumption is the ruleset documented
in src/qa023_probe.zig and src/rules.zig.
"""

from __future__ import annotations
import sys
from collections import deque
from typing import List, Tuple, Optional, Set, Dict

# ---------------------------------------------------------------------------
# Goban geometry helpers (parameterised by width, height)
# ---------------------------------------------------------------------------

class Rules:
    def __init__(self, w: int, h: int):
        self.w = w
        self.h = h
        self.n = w * h
        # KO_NONE sentinel used in the dense linear encoding is n (not 255).
        self.KO_NONE_ENC = self.n

    def neighbors(self, p: int) -> List[int]:
        r, c = divmod(p, self.w)
        nb = []
        if r > 0:
            nb.append(p - self.w)
        if r + 1 < self.h:
            nb.append(p + self.w)
        if c > 0:
            nb.append(p - 1)
        if c + 1 < self.w:
            nb.append(p + 1)
        return nb

    def unrank_board(self, idx: int) -> Tuple[int, ...]:
        board = [0] * self.n
        v = idx
        for i in range(self.n):
            d = v % 3
            v //= 3
            board[i] = {0: 0, 1: 1, 2: -1}[d]
        return tuple(board)

    def rank_board(self, board: Tuple[int, ...]) -> int:
        idx = 0
        mult = 1
        for i in range(self.n):
            d = 1 if board[i] > 0 else (2 if board[i] < 0 else 0)
            idx += d * mult
            mult *= 3
        return idx

    def chain_captured(self, pos: Tuple[int, ...], seed: int) -> Tuple[bool, List[int]]:
        colour = 1 if pos[seed] > 0 else -1
        visited = [False] * self.n
        stack = [seed]
        visited[seed] = True
        chain = [seed]
        has_liberty = False
        while stack:
            q = stack.pop()
            for r in self.neighbors(q):
                if pos[r] == 0:
                    has_liberty = True
                elif (pos[r] > 0) == (colour > 0) and pos[r] != 0 and not visited[r]:
                    visited[r] = True
                    stack.append(r)
                    chain.append(r)
        return not has_liberty, chain

    def pos_from_move(self, pos: Tuple[int, ...], colour: int, cell: int) -> Optional[Tuple[int, ...]]:
        if pos[cell] != 0:
            return None
        nxt = list(pos)
        nxt[cell] = colour
        # capture opponent neighbour chains
        for q in self.neighbors(cell):
            if nxt[q] * colour < 0:
                captured, chain = self.chain_captured(tuple(nxt), q)
                if captured:
                    for c in chain:
                        nxt[c] = 0
        # suicide check
        captured, _ = self.chain_captured(tuple(nxt), cell)
        if captured:
            return None
        return tuple(nxt)

    def is_legal(self, pos: Tuple[int, ...]) -> bool:
        visited = [False] * self.n
        for p in range(self.n):
            if pos[p] == 0 or visited[p]:
                continue
            colour = pos[p]
            stack = [p]
            visited[p] = True
            has_liberty = False
            while stack:
                q = stack.pop()
                for r in self.neighbors(q):
                    if pos[r] == 0:
                        has_liberty = True
                    elif pos[r] == colour and not visited[r]:
                        visited[r] = True
                        stack.append(r)
            if not has_liberty:
                return False
        return True

    def area_score(self, board: Tuple[int, ...]) -> int:
        black = white = 0
        visited = [False] * self.n
        for p in range(self.n):
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
                for r in self.neighbors(q):
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


# ---------------------------------------------------------------------------
# State encoding for (board, side, ko, passes)
# side: 0 = Black (+1), 1 = White (-1)
# ko: 0..n-1 real cell, n = KO_NONE in the dense encoding
# passes: 0,1,2
# ---------------------------------------------------------------------------

class StateSpace:
    def __init__(self, rules: Rules):
        self.r = rules
        self.n = rules.n
        self.ko_dims = self.n + 1
        self.raw_total = 3 ** self.n
        self.total_states = self.raw_total * 2 * self.ko_dims * 3

    def linear(self, board_idx: int, side: int, ko: int, passes: int) -> int:
        return (((passes * 2) + side) * self.ko_dims + ko) * self.raw_total + board_idx

    def decode(self, li: int) -> Tuple[int, int, int, int, Tuple[int, ...]]:
        board_idx = li % self.raw_total
        rest = li // self.raw_total
        ko = rest % self.ko_dims
        rest //= self.ko_dims
        side = rest % 2
        passes = rest // 2
        return board_idx, side, ko, passes, self.r.unrank_board(board_idx)

    def all_legal_states(self) -> List[int]:
        legal = []
        for board_idx in range(self.raw_total):
            b = self.r.unrank_board(board_idx)
            if self.r.is_legal(b):
                for side in (0, 1):
                    for ko in range(self.ko_dims):
                        for passes in range(3):
                            legal.append(self.linear(board_idx, side, ko, passes))
        return legal


# ---------------------------------------------------------------------------
# Move application with basic-ko formalization (i)
# ---------------------------------------------------------------------------

class GameGraph:
    def __init__(self, rules: Rules):
        self.r = rules
        self.space = StateSpace(rules)
        self.KO_NONE = rules.KO_NONE_ENC  # dense encoding sentinel

    def apply_place(self, board_idx: int, side: int, ko: int, passes: int, cell: int) -> Optional[Tuple[int, Tuple[int, ...]]]:
        board = self.r.unrank_board(board_idx)
        colour = 1 if side == 0 else -1
        if board[cell] != 0:
            return None
        if ko != self.KO_NONE and cell == ko:
            return None
        nxt = self.r.pos_from_move(board, colour, cell)
        if nxt is None:
            return None
        # determine new ko point
        opp_before = sum(1 for i in range(self.r.n) if board[i] == -colour)
        opp_after = sum(1 for i in range(self.r.n) if nxt[i] == -colour)
        captured_cell = None
        for i in range(self.r.n):
            if board[i] == -colour and nxt[i] == 0:
                captured_cell = i
                break
        new_ko = self.KO_NONE
        if (opp_before - opp_after == 1) and (captured_cell is not None):
            liberties = 0
            friendly = 0
            for q in self.r.neighbors(cell):
                if nxt[q] == 0:
                    liberties += 1
                if nxt[q] == colour:
                    friendly += 1
            if liberties == 1 and friendly == 0:
                new_ko = captured_cell
        next_side = 1 if side == 0 else 0
        next_idx = self.r.rank_board(nxt)
        next_li = self.space.linear(next_idx, next_side, new_ko, 0)
        return next_li, nxt

    def apply_pass(self, board_idx: int, side: int, passes: int) -> Optional[int]:
        if passes >= 2:
            return None
        next_side = 1 if side == 0 else 0
        return self.space.linear(board_idx, next_side, self.KO_NONE, passes + 1)

    def moves(self, li: int) -> List[Tuple[int, Tuple[int, ...]]]:
        board_idx, side, ko, passes, _ = self.space.decode(li)
        if passes == 2:
            return []
        succs = []
        np = self.apply_pass(board_idx, side, passes)
        if np is not None:
            succs.append((np, self.r.unrank_board(board_idx)))
        for cell in range(self.r.n):
            ap = self.apply_place(board_idx, side, ko, passes, cell)
            if ap is not None:
                succs.append(ap)
        return succs

    def reachable(self, roots: Optional[List[int]] = None) -> Tuple[Set[int], Dict[int, List[int]]]:
        if roots is None:
            # Match src/qa023_probe.zig run_census_3x2 seeds:
            # empty goban (board=0), both sides, all ko values, passes 0/1/2.
            empty = self.r.rank_board(tuple([0] * self.r.n))
            roots = []
            for side in (0, 1):
                for passes in (0, 1, 2):
                    for ko in range(self.space.ko_dims):
                        roots.append(self.space.linear(empty, side, ko, passes))
        reach: Set[int] = set()
        adj: Dict[int, List[int]] = {}
        q = deque(roots)
        for r in roots:
            reach.add(r)
        while q:
            u = q.popleft()
            adj[u] = []
            for v, _ in self.moves(u):
                adj[u].append(v)
                if v not in reach:
                    reach.add(v)
                    q.append(v)
        return reach, adj


# ---------------------------------------------------------------------------
# Fixpoint kernels
# ---------------------------------------------------------------------------

class FixpointKernel:
    def __init__(self, graph: GameGraph, reach: Set[int], adj: Dict[int, List[int]]):
        self.g = graph
        self.r = graph.r
        self.space = graph.space
        self.reach = reach
        self.adj = adj
        self.n_val = self.r.n

    def _terminal_value(self, li: int) -> int:
        board_idx, _, _, passes, _ = self.space.decode(li)
        if passes != 2:
            raise ValueError("not terminal")
        return self.r.area_score(self.r.unrank_board(board_idx))

    def as_shipped(self, max_sweeps: int = 64) -> Tuple[List[int], List[int], int, int]:
        """Reproduce src/qa023_probe.zig fixpoint_kernel exactly."""
        L = [-self.n_val] * self.space.total_states
        H = [self.n_val] * self.space.total_states
        for li in self.reach:
            _, _, _, passes, _ = self.space.decode(li)
            if passes == 2:
                v = self._terminal_value(li)
                L[li] = H[li] = v
        sweeps = 0
        total_changes = 1
        l_changed = h_changed = 0
        while total_changes > 0 and sweeps < max_sweeps:
            sweeps += 1
            total_changes = 0
            l_changed = h_changed = 0
            # L sweep (ascending)
            for li in self.reach:
                _, side, _, passes, _ = self.space.decode(li)
                if passes == 2:
                    continue
                colour = 1 if side == 0 else -1
                best = None
                for v in self.adj[li]:
                    vl = L[v]
                    if best is None:
                        best = vl
                    elif (side == 0 and vl > best) or (side == 1 and vl < best):
                        best = vl
                # BUG: White guard uses best < L[li], impossible from -n seed.
                if best is not None:
                    if side == 0 and best > L[li]:
                        L[li] = best
                        l_changed += 1
                    elif side == 1 and best < L[li]:
                        L[li] = best
                        l_changed += 1
            # H sweep (descending)
            for li in self.reach:
                _, side, _, passes, _ = self.space.decode(li)
                if passes == 2:
                    continue
                best = None
                for v in self.adj[li]:
                    vh = H[v]
                    if best is None:
                        best = vh
                    elif (side == 0 and vh > best) or (side == 1 and vh < best):
                        best = vh
                # BUG: White guard uses best > H[li], impossible from +n seed.
                if best is not None:
                    if side == 0 and best < H[li]:
                        H[li] = best
                        h_changed += 1
                    elif side == 1 and best > H[li]:
                        H[li] = best
                        h_changed += 1
            total_changes = l_changed + h_changed
        return L, H, sweeps, total_changes

    def corrected(self, max_sweeps: int = 64, full_space: bool = False) -> Tuple[List[int], List[int], int, int]:
        """Correct monotone Gauss-Seidel: Black max / White min in BOTH tables,
        unconditional update (matches src/retro.zig operator and smoke_fixpoint_2x2).
        If full_space=True, sweep every raw state (used for 2x2 smoke cross-check)."""
        sweep_set = range(self.space.total_states) if full_space else self.reach
        L = [-self.n_val] * self.space.total_states
        H = [self.n_val] * self.space.total_states
        for li in sweep_set:
            _, _, _, passes, _ = self.space.decode(li)
            if passes == 2:
                v = self._terminal_value(li)
                L[li] = H[li] = v
        sweeps = 0
        total_changes = 1
        while total_changes > 0 and sweeps < max_sweeps:
            sweeps += 1
            changed = 0
            for li in sweep_set:
                _, side, _, passes, _ = self.space.decode(li)
                if passes == 2:
                    continue
                best_l = None
                best_h = None
                succs = self.adj.get(li, None)
                if succs is None:
                    succs = [v for v, _ in self.g.moves(li)]
                for v in succs:
                    vl = L[v]
                    vh = H[v]
                    if best_l is None:
                        best_l, best_h = vl, vh
                    else:
                        if side == 0:  # Black max
                            if vl > best_l:
                                best_l = vl
                            if vh > best_h:
                                best_h = vh
                        else:  # White min
                            if vl < best_l:
                                best_l = vl
                            if vh < best_h:
                                best_h = vh
                if best_l is None:
                    continue
                if best_l != L[li]:
                    L[li] = best_l
                    changed += 1
                if best_h != H[li]:
                    H[li] = best_h
                    changed += 1
            total_changes = changed
        return L, H, sweeps, total_changes

    @staticmethod
    def median(L: int, T: int, H: int) -> int:
        # max(L, min(T, H)) when L <= H
        if L > H:
            L, H = H, L
        if T < L:
            return L
        if T > H:
            return H
        return T

    def pin_census(self, L: List[int], H: List[int]) -> Dict[str, int]:
        stats = {"l_eq_h": 0, "pin_t": 0, "pin_l": 0, "pin_h": 0, "l_lt_h": 0}
        TIE = 0
        for li in self.reach:
            ll, hh = L[li], H[li]
            if ll == hh:
                stats["l_eq_h"] += 1
            else:
                stats["l_lt_h"] += 1
                if TIE < ll:
                    stats["pin_l"] += 1
                elif TIE > hh:
                    stats["pin_h"] += 1
                else:
                    stats["pin_t"] += 1
        return stats

    def bellman_residual(self, L: List[int], H: List[int]) -> Tuple[int, int]:
        """Count reachable non-terminals whose table entry is not the Bellman value."""
        l_res = h_res = 0
        for li in self.reach:
            _, side, _, passes, _ = self.space.decode(li)
            if passes == 2:
                continue
            # Bellman L/H using the same table (self-consistent)
            best_l = None
            best_h = None
            for v in self.adj[li]:
                vl = L[v]
                vh = H[v]
                if best_l is None:
                    best_l, best_h = vl, vh
                else:
                    if side == 0:
                        best_l = max(best_l, vl)
                        best_h = max(best_h, vh)
                    else:
                        best_l = min(best_l, vl)
                        best_h = min(best_h, vh)
            if best_l is not None and best_l != L[li]:
                l_res += 1
            if best_h is not None and best_h != H[li]:
                h_res += 1
        return l_res, h_res

    def inversion_violations(self, L: List[int], H: List[int]) -> int:
        """L(-S) == -H(S) over the reachable set."""
        viol = 0
        for li in self.reach:
            board_idx, side, ko, passes, _ = self.space.decode(li)
            inv_board = tuple(-x for x in self.r.unrank_board(board_idx))
            inv_idx = self.r.rank_board(inv_board)
            inv_li = self.space.linear(inv_idx, 1 - side, ko, passes)
            if inv_li not in self.reach:
                continue
            if L[li] != -H[inv_li]:
                viol += 1
        return viol

    def reachable_count(self) -> int:
        return len(self.reach)

    def nonterminal_count(self) -> int:
        return sum(1 for li in self.reach if self.space.decode(li)[3] != 2)


# ---------------------------------------------------------------------------
# First-revisit-truncation evaluator (spot checks)
# ---------------------------------------------------------------------------

class TruncatedEvaluator:
    def __init__(self, graph: GameGraph):
        self.g = graph
        self.space = graph.space
        self.nodes_evaluated = 0

    def evaluate(self, li: int, budget: int, history: Optional[Set[int]] = None,
                 alpha: int = -127, beta: int = 127) -> Tuple[Optional[int], int]:
        """Alpha-beta first-revisit truncation. Returns (value, nodes_used).
        None value means budget exhausted."""
        if history is None:
            history = set()
        self.nodes_evaluated = 0

        def rec(cur: int, hist: Set[int], a: int, b: int, nodes: int) -> Tuple[Optional[int], int]:
            nonlocal self
            self.nodes_evaluated += 1
            if self.nodes_evaluated > budget:
                return None, nodes
            board_idx, side, ko, passes, _ = self.space.decode(cur)
            if cur in hist:
                return 0, nodes  # TIE on first revisit
            if passes == 2:
                return self.g.r.area_score(self.g.r.unrank_board(board_idx)), nodes
            new_hist = hist | {cur}
            colour = 1 if side == 0 else -1
            succs = self.g.adj[cur] if hasattr(self.g, 'adj') and cur in self.g.adj else [v for v, _ in self.g.moves(cur)]
            best = None
            for v in succs:
                val, nodes = rec(v, new_hist, a, b, nodes)
                if val is None:
                    return None, nodes
                if colour == 1:
                    if best is None or val > best:
                        best = val
                    if best >= b:
                        return best, nodes
                    if best > a:
                        a = best
                else:
                    if best is None or val < best:
                        best = val
                    if best <= a:
                        return best, nodes
                    if best < b:
                        b = best
            # pass is always legal off-terminal, so best is set
            return best, nodes

        val, _ = rec(li, history, alpha, beta, 0)
        return val, self.nodes_evaluated


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def board_string(board: Tuple[int, ...], w: int, h: int) -> str:
    chars = {1: "B", -1: "W", 0: "."}
    rows = []
    for r in range(h):
        rows.append("".join(chars[board[r * w + c]] for c in range(w)))
    return " ".join(rows)


def run_3x2():
    rules = Rules(3, 2)
    graph = GameGraph(rules)
    print("# Building 3x2 reachable graph...")
    reach, adj = graph.reachable()
    graph.adj = adj
    kernel = FixpointKernel(graph, reach, adj)
    print(f"# reachable states: {len(reach)}")
    print(f"# reachable non-terminals: {kernel.nonterminal_count()}")

    print("\n# --- as-shipped fixpoint_kernel ---")
    L0, H0, s0, ch0 = kernel.as_shipped()
    print(f"# sweeps={s0} final_changes={ch0}")
    c0 = kernel.pin_census(L0, H0)
    print(f"# pin census: L==H={c0['l_eq_h']} pin_T={c0['pin_t']} pin_L={c0['pin_l']} pin_H={c0['pin_h']}")
    r0 = kernel.bellman_residual(L0, H0)
    print(f"# Bellman residual: L={r0[0]} H={r0[1]}")
    v0 = kernel.inversion_violations(L0, H0)
    print(f"# colour-inversion violations: {v0}")

    # White non-terminals pinned count
    white_pinned = 0
    white_nonterm = 0
    for li in reach:
        _, side, _, passes, _ = graph.space.decode(li)
        if passes == 2:
            continue
        if side == 1:
            white_nonterm += 1
            if L0[li] == -rules.n and H0[li] == rules.n:
                white_pinned += 1
    print(f"# White non-terminals: {white_nonterm}; pinned at (-n,+n): {white_pinned}")

    print("\n# --- corrected fixpoint_kernel ---")
    L1, H1, s1, ch1 = kernel.corrected()
    print(f"# sweeps={s1} final_changes={ch1}")
    c1 = kernel.pin_census(L1, H1)
    print(f"# pin census: L==H={c1['l_eq_h']} pin_T={c1['pin_t']} pin_L={c1['pin_l']} pin_H={c1['pin_h']}")
    r1 = kernel.bellman_residual(L1, H1)
    print(f"# Bellman residual: L={r1[0]} H={r1[1]}")
    v1 = kernel.inversion_violations(L1, H1)
    print(f"# colour-inversion violations: {v1}")

    # Distribution of (L,H) groups in corrected kernel
    groups: Dict[Tuple[int, int], int] = {}
    for li in reach:
        _, _, _, passes, _ = graph.space.decode(li)
        if passes == 2:
            continue
        key = (L1[li], H1[li])
        groups[key] = groups.get(key, 0) + 1
    print(f"\n# corrected (L,H) group count: {len(groups)}")
    for key in sorted(groups, key=lambda k: (k[0], k[1])):
        inv = (-key[1], -key[0])
        inv_n = groups.get(inv, 0)
        print(f"  (L={key[0]:>3},H={key[1]:>3}) {groups[key]:>4}  inversion-pair {inv}={inv_n}")

    # Seven hand-adjudicated C2 states
    seven = [
        (586, "+1"),
        (534, "+1"),
        (302, "+1"),
        (146, "+1"),
        (103, "+3"),
        (674, "-6"),
        (566, "-6"),
    ]
    print("\n# --- seven hand-adjudicated C2 states (single-successor check) ---")
    for rank, expected in seven:
        board = rules.unrank_board(rank)
        # We need state (rank, side=1 White, ko=KO_NONE, passes=1)
        li = graph.space.linear(rank, 1, rules.KO_NONE_ENC, 1)
        if li not in reach:
            print(f"  state {rank} NOT REACHABLE (unexpected)")
            continue
        succs = graph.moves(li)
        areas = rules.area_score(board)
        print(f"  rank={rank} board=[{board_string(board,3,2)}] area_score={areas:>3} expected={expected:>3} succs={len(succs)}")
        for v, _ in succs:
            bidx, side, ko, passes, _ = graph.space.decode(v)
            print(f"    -> rank={bidx} side={'B' if side==0 else 'W'} passes={passes}")

    # Spot-evaluate the seven states with first-revisit truncation
    print("\n# --- spot truncated evaluation of the seven states ---")
    ev = TruncatedEvaluator(graph)
    for rank, expected in seven:
        li = graph.space.linear(rank, 1, rules.KO_NONE_ENC, 1)
        val, nodes = ev.evaluate(li, budget=5_000_000)
        print(f"  rank={rank} truncated={val if val is not None else 'EXHAUSTED':>8} nodes={nodes} expected={expected}")

    # C1 witness: (178,0,6,0) with two distinct arrivals
    print("\n# --- C1 witness (178,0,6,0) ---")
    witness_state(graph, L1, H1, ev)

    return L1, H1, kernel, graph


def witness_state(graph: GameGraph, L: List[int], H: List[int], ev: TruncatedEvaluator) -> None:
    """Reproduce the PINRULE-SUFFICIENCY (178,0,6,0) C1 witness end-to-end."""
    rules = graph.r
    target_rank = 178
    target_li = graph.space.linear(target_rank, 0, rules.KO_NONE_ENC, 0)
    board = rules.unrank_board(target_rank)
    print(f"# target state rank={target_rank} board=[{board_string(board, rules.w, rules.h)}] area_score={rules.area_score(board)}")
    print(f"# corrected kernel L={L[target_li]} H={H[target_li]} median={FixpointKernel.median(L[target_li], 0, H[target_li])}")

    seq_a = "2 3 1 4 5 pass 0 pass 3 4 pass 5 0 3 pass 1 pass 2 0 1 2 4"
    seq_b = "3 1 pass 5 pass 4 pass 0 pass 3 2 3 5 pass 0 4 1 pass 3 4 0 pass 2 1"

    for name, seq in [("A", seq_a), ("B", seq_b)]:
        moves = ['pass' if t == 'pass' else int(t) for t in seq.split()]
        target, history = play_arrival(graph, moves)
        rank, side, ko, passes, _ = graph.space.decode(target)
        assert target == target_li, f"arrival {name} did not reach target"
        val, nodes = ev.evaluate(target, budget=20_000_000, history=history)
        print(f"  Arrival {name}: value={val if val is not None else 'EXHAUSTED'} nodes={nodes} history_size={len(history)}")


def play_arrival(graph: GameGraph, moves: List[object]) -> Tuple[int, Set[int]]:
    """Play a move sequence from the empty board; return (target_li, history exclusive of target)."""
    rules = graph.r
    empty = rules.rank_board(tuple([0] * rules.n))
    cur = graph.space.linear(empty, 0, rules.KO_NONE_ENC, 0)
    history: Set[int] = {cur}
    side = 0
    for mv in moves:
        board_idx, cur_side, ko, passes, _ = graph.space.decode(cur)
        assert cur_side == side
        if mv == 'pass':
            nxt = graph.apply_pass(board_idx, side, passes)
        else:
            nxt, _ = graph.apply_place(board_idx, side, ko, passes, mv)
        assert nxt is not None, f"illegal move {mv} from state {graph.space.decode(cur)[:4]}"
        cur = nxt
        history.add(cur)
        side = 1 - side
    history.remove(cur)
    return cur, history


def run_2x2_smoke():
    """Corrected fixpoint over 2x2 full state space; compare to smoke_fixpoint_2x2 outputs."""
    rules = Rules(2, 2)
    graph = GameGraph(rules)
    reach, adj = graph.reachable()
    graph.adj = adj
    kernel = FixpointKernel(graph, reach, adj)
    # smoke_fixpoint_2x2 sweeps over ALL raw states, not only reachable ones.
    L, H, sweeps, _ = kernel.corrected(full_space=True)
    print("\n# --- 2x2 corrected fixpoint full-space (reference cross-check) ---")
    print(f"# total raw states: {graph.space.total_states}  sweeps={sweeps}")
    c = kernel.pin_census(L, H)
    print(f"# pin census over REACHABLE: L==H={c['l_eq_h']} pin_T={c['pin_t']} pin_L={c['pin_l']} pin_H={c['pin_h']}")

    empty = rules.rank_board(tuple([0] * 4))
    full = rules.rank_board(tuple([1] * 4))
    checks = [
        (empty, 0, rules.KO_NONE_ENC, 0, 0, "empty B"),
        (empty, 1, rules.KO_NONE_ENC, 0, 0, "empty W"),
        (full, 0, rules.KO_NONE_ENC, 0, 4, "full B"),
        (empty, 1, rules.KO_NONE_ENC, 1, 0, "passes=1"),
        (empty, 0, rules.KO_NONE_ENC, 2, 0, "passes=2"),
    ]
    for bidx, side, ko, passes, expected, name in checks:
        li = graph.space.linear(bidx, side, ko, passes)
        v = FixpointKernel.median(L[li], 0, H[li])
        ok = "OK" if v == expected else "FAIL"
        print(f"  {name:12} v={v:>3} expected={expected:>3} {ok}")


if __name__ == "__main__":
    run_3x2()
    run_2x2_smoke()
