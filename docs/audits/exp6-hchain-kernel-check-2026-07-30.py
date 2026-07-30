#!/usr/bin/env python3
"""
AUDIT-EXP6-HCHAIN · Kimi-k3 · 2026-07-30
Independent kernel check for DSPro/EXP-6 (src/exp6_solve.zig) and its audit
harness (src/exp6_hchain_audit.zig).

Re-derives, with NO Zig code imported, the loopy-game fixpoint (ADR-0020)
under area scoring / komi 0 / basic ko (formalization i) and diffs every
(state, L, H) tuple dumped by the Zig audit harness:

    #DUMP2  <board> <side(+1/-1)> <ko_point raw (255=NONE)> <passes> <L> <H>
    #DUMP32 <board> <side(0=B)> <ko (6=NONE)> <passes> <L> <H>   (reachable only)
    #DUMP3  <board> <side(0=B)> <ko (9=NONE)> <passes> <L> <H>   (reachable only)

The rules core (Rules/GameGraph/StateSpace/FixpointKernel.corrected) is the
independent re-implementation proven in the QA023 kernel audit
(docs/audits/qa023-kernel-audit-2026-07-29.py — the instrument that found the
F5 ko bug).  Only the harness-specific census seeding, dump parsing and
diffing are new.

Denominators are printed for every check (AGENTS.md verification rules).
"""

from __future__ import annotations
import sys
from collections import deque
from typing import List, Tuple, Optional, Set, Dict

# ---------------------------------------------------------------------------
# Rules core — copied from docs/audits/qa023-kernel-audit-2026-07-29.py
# (Kimi-K2.7/QA023).  Independent of all Zig sources.
# ---------------------------------------------------------------------------

class Rules:
    def __init__(self, w: int, h: int):
        self.w = w
        self.h = h
        self.n = w * h
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
        for q in self.neighbors(cell):
            if nxt[q] * colour < 0:
                captured, chain = self.chain_captured(tuple(nxt), q)
                if captured:
                    for c in chain:
                        nxt[c] = 0
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


class GameGraph:
    def __init__(self, rules: Rules):
        self.r = rules
        self.space = StateSpace(rules)
        self.KO_NONE = rules.KO_NONE_ENC

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

    def reachable_from_empty(self) -> Tuple[Set[int], Dict[int, List[int]]]:
        """EXP-6-equivalent census: seed (empty, both sides, KO_NONE, passes=0)
        — the 3x3 harness seeds exactly these; the 3x2 harness additionally
        seeds passes=1, which lies inside the same closure (pass from the
        opposite seed).  Children of a legal board are legal, so no legality
        filter is applied (asserted vacuous below)."""
        empty = 0
        roots = [self.space.linear(empty, side, self.KO_NONE, 0) for side in (0, 1)]
        reach: Set[int] = set(roots)
        adj: Dict[int, List[int]] = {}
        q = deque(roots)
        illeg = 0
        while q:
            u = q.popleft()
            adj[u] = []
            for v, bv in self.moves(u):
                if not self.r.is_legal(bv):
                    illeg += 1
                adj[u].append(v)
                if v not in reach:
                    reach.add(v)
                    q.append(v)
        if illeg:
            print(f"#   *** {illeg} ILLEGAL child boards generated during BFS (legality filter NOT vacuous)")
        return reach, adj


def corrected_fixpoint(rules: Rules, graph: GameGraph, sweep_set, adj: Dict[int, List[int]]):
    """Monotone Gauss-Seidel: Black max / White min in BOTH tables,
    unconditional update.  Terminals (passes==2) pinned to area score."""
    n_val = rules.n
    L = [-n_val] * graph.space.total_states
    H = [n_val] * graph.space.total_states
    sp = graph.space
    # terminal pin
    if isinstance(sweep_set, range):
        it = sweep_set
    else:
        it = sweep_set
    for li in it:
        board_idx, side, ko, passes, _ = sp.decode(li)
        if passes == 2:
            v = rules.area_score(rules.unrank_board(board_idx))
            L[li] = H[li] = v
    sweeps = 0
    changed = 1
    while changed > 0 and sweeps < 256:
        sweeps += 1
        changed = 0
        for li in it:
            _, side, _, passes, _ = sp.decode(li)
            if passes == 2:
                continue
            succs = adj.get(li)
            if succs is None:
                succs = [v for v, _ in graph.moves(li)]
            best_l = None
            best_h = None
            for v in succs:
                vl = L[v]
                vh = H[v]
                if best_l is None:
                    best_l, best_h = vl, vh
                elif side == 0:
                    if vl > best_l: best_l = vl
                    if vh > best_h: best_h = vh
                else:
                    if vl < best_l: best_l = vl
                    if vh < best_h: best_h = vh
            if best_l is None:
                continue
            if best_l != L[li]:
                L[li] = best_l
                changed += 1
            if best_h != H[li]:
                H[li] = best_h
                changed += 1
    return L, H, sweeps


# ---------------------------------------------------------------------------
# Dump parsing
# ---------------------------------------------------------------------------

def parse_dumps(path: str):
    d2, d32, d3 = {}, {}, {}
    with open(path) as f:
        for line in f:
            if line.startswith("#DUMP2 "):
                _, b, s, k, p, l, h = line.split()
                key = (int(b), int(s), int(k), int(p))
                assert key not in d2, f"duplicate DUMP2 key {key}"
                d2[key] = (int(l), int(h))
            elif line.startswith("#DUMP32 "):
                _, b, s, k, p, l, h = line.split()
                key = (int(b), int(s), int(k), int(p))
                assert key not in d32, f"duplicate DUMP32 key {key}"
                d32[key] = (int(l), int(h))
            elif line.startswith("#DUMP3 "):
                _, b, s, k, p, l, h = line.split()
                key = (int(b), int(s), int(k), int(p))
                assert key not in d3, f"duplicate DUMP3 key {key}"
                d3[key] = (int(l), int(h))
    return d2, d32, d3


# ---------------------------------------------------------------------------
# Per-board checks
# ---------------------------------------------------------------------------

def check_2x2(d2) -> bool:
    print("\n## 2x2 — full raw space (harness sweeps ALL 2,430 quadruples)")
    rules = Rules(2, 2)
    graph = GameGraph(rules)
    sp = graph.space
    print(f"#   python total_states={sp.total_states} dump_states={len(d2)}")
    if len(d2) != sp.total_states:
        print("#   *** DENOMINATOR MISMATCH")
        return False
    L, H, sweeps = corrected_fixpoint(rules, graph, range(sp.total_states), {})
    print(f"#   python fixpoint sweeps={sweeps}")
    mism = 0
    shown = 0
    for (b, s, k, p), (zl, zh) in d2.items():
        side01 = 0 if s == 1 else 1          # Brute2x2 prints side as +1/-1
        ko_enc = rules.KO_NONE_ENC if k == 255 else k   # 255 = KO_NONE raw
        li = sp.linear(b, side01, ko_enc, p)
        pl, ph = L[li], H[li]
        if (pl, ph) != (zl, zh):
            mism += 1
            if shown < 10:
                shown += 1
                print(f"#   MISMATCH (b={b},side={s},ko={k},p={p}): zig=({zl},{zh}) python=({pl},{ph})")
    root_b = sp.linear(0, 0, rules.KO_NONE_ENC, 0)
    root_w = sp.linear(0, 1, rules.KO_NONE_ENC, 0)
    print(f"#   mismatches: {mism}/{len(d2)}")
    print(f"#   python root_B(L={L[root_b]},H={H[root_b]}) root_W(L={L[root_w]},H={H[root_w]})")
    zrb = d2.get((0, 1, 255, 0))
    zrw = d2.get((0, -1, 255, 0))
    print(f"#   zig    root_B(L={zrb[0]},H={zrb[1]}) root_W(L={zrw[0]},H={zrw[1]})")
    return mism == 0


def check_board(name: str, w: int, h: int, dump) -> bool:
    print(f"\n## {name} — reachable census + fixpoint (dump covers reachable states only)")
    rules = Rules(w, h)
    graph = GameGraph(rules)
    sp = graph.space
    reach, adj = graph.reachable_from_empty()
    print(f"#   python reachable={len(reach)} dump_states={len(dump)}")
    dumped_keys = set()
    for (b, s, k, p) in dump:
        dumped_keys.add(sp.linear(b, s, k, p))
    only_py = reach - dumped_keys
    only_zig = dumped_keys - reach
    print(f"#   reachable-only-in-python={len(only_py)} dumped-only-in-zig={len(only_zig)}")
    for li in list(only_py)[:5]:
        b, s, k, p, _ = sp.decode(li)
        print(f"#     python-only: (b={b},s={s},ko={k},p={p})")
    for li in list(only_zig)[:5]:
        b, s, k, p, _ = sp.decode(li)
        print(f"#     zig-only:    (b={b},s={s},ko={k},p={p})")
    L, H, sweeps = corrected_fixpoint(rules, graph, reach, adj)
    print(f"#   python fixpoint sweeps={sweeps}")
    mism = 0
    for (b, s, k, p), (zl, zh) in dump.items():
        li = sp.linear(b, s, k, p)
        if (L[li], H[li]) != (zl, zh):
            mism += 1
            if mism <= 10:
                print(f"#   MISMATCH (b={b},s={s},ko={k},p={p}): zig=({zl},{zh}) python=({L[li]},{H[li]})")
    root_b = sp.linear(0, 0, rules.KO_NONE_ENC, 0)
    root_w = sp.linear(0, 1, rules.KO_NONE_ENC, 0)
    print(f"#   value mismatches: {mism}/{len(dump)}")
    print(f"#   python root_B(L={L[root_b]},H={H[root_b]}) root_W(L={L[root_w]},H={H[root_w]})  "
          f"V_B={max(L[root_b], min(0, H[root_b]))} V_W={max(L[root_w], min(0, H[root_w]))}")
    # phenomenon census: white-to-move, passes==1, white stone on board, H==top
    top = rules.n
    bad = 0
    for li in reach:
        b, s, k, p, board = sp.decode(li)
        if s == 1 and p == 1 and H[li] == top and any(c < 0 for c in board):
            bad += 1
            if bad <= 5:
                print(f"#   PHENOMENON-VIOLATION (python): (b={b},s={s},ko={k},p={p}) H={H[li]}")
    print(f"#   python white-to-move passes=1 with-white-stone H==top: {bad}  (MUST be 0)")
    # colour inversion, exhaustive over reachable
    viol = 0
    miss = 0
    for li in reach:
        b, s, k, p, board = sp.decode(li)
        inv = sp.linear(rules.rank_board(tuple(-x for x in board)), 1 - s, k, p)
        if inv not in reach:
            miss += 1
            continue
        if L[li] != -H[inv] or H[li] != -L[inv]:
            viol += 1
    print(f"#   python inversion violations={viol}/{len(reach)} inverse-misses={miss}")
    return mism == 0 and not only_py and not only_zig and bad == 0


def main() -> int:
    path = sys.argv[1] if len(sys.argv) > 1 else "/tmp/exp6-hchain-audit-2026-07-30.log"
    print(f"# AUDIT-EXP6-HCHAIN kernel check against {path}")
    d2, d32, d3 = parse_dumps(path)
    print(f"# parsed: DUMP2={len(d2)} DUMP32={len(d32)} DUMP3={len(d3)}")
    ok2 = check_2x2(d2)
    ok32 = check_board("3x2", 3, 2, d32)
    ok3 = check_board("3x3", 3, 3, d3)
    print(f"\n## VERDICT  2x2={'PASS' if ok2 else 'FAIL'}  3x2={'PASS' if ok32 else 'FAIL'}  3x3={'PASS' if ok3 else 'FAIL'}")
    return 0 if (ok2 and ok32 and ok3) else 1


if __name__ == "__main__":
    sys.exit(main())
