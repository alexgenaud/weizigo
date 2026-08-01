#!/usr/bin/env python3
"""
i5-reference-3x2.py — Committed Python reference for I5 calibration at 3×2.

Task: T186 · Worker: DSPro/T186 · Date: 2026-08-01

Produces the exact V, E, max-SCC, cycle-involved at the SAME PROJECTION LEVEL
as src/vb_graph.zig (T171-w1): BFS discovers reachable (board, side, ko, passes)
quadruples; iterative Tarjan runs on those quadruples; then each SCC is projected
to unique (board, side, ko) triples for the maxSCC and cycle-involved counts.

This replaces the self-calibrated [988,1012] gate in the Zig test with a
committed exact-value gate. The reference is a full independent re-implementation
— no imports from the Zig codebase, no shared code beyond the colex bijection
specification and the basic-ko rules correction (F5 fix, QA-023).

Output format: one key=value per line on stdout for easy parsing by the Zig
gate. Exit 0 on success.

Reference calibration data (from ko-fix-rerun-2026-07-29.stdout, quadruple level):
  42-seed:   V=2622  E=5668  maxSCC=1676  cycle-involved=1676  cycle-reachable=1704
  true-root: V=2583  E=5510  maxSCC=1676  cycle-involved=1676  cycle-reachable=1678

The Zig implementation uses true-root seeding (empty board only).
This reference reproduces the Zig projection: quadruple Tarjan → triple SCC sizes.
"""

from __future__ import annotations
import math


# ═══════════════════════════════════════════════════════════════════════════════
# Colex bijection — layered co-lexicographic index (ADR-0007, plan C)
# Identical semantics to src/colex.zig and the independent re-implementation
# in src/vb_graph.zig (Colex type).
# ═══════════════════════════════════════════════════════════════════════════════

def binomial(n: int, k: int) -> int:
    """C(n, k) — combinatorial number system binomial."""
    if k < 0 or k > n:
        return 0
    if k == 0 or k == n:
        return 1
    # multiplicative form for speed at small n
    k = min(k, n - k)
    r = 1
    for i in range(k):
        r = r * (n - i) // (i + 1)
    return r


class Colex:
    """Layered colex indexer for w×h goban."""
    def __init__(self, w: int, h: int):
        self.w = w
        self.h = h
        self.n = w * h
        # Pascal's triangle C(i,j) for i,j in 0..n
        self._C = [[0] * (self.n + 1) for _ in range(self.n + 1)]
        for i in range(self.n + 1):
            self._C[i][0] = 1
            for j in range(1, i + 1):
                self._C[i][j] = self._C[i - 1][j - 1] + self._C[i - 1][j]

        # layer_offset[k] = count of positions with < k stones
        self._layer_offset = [0] * (self.n + 2)
        for k in range(self.n + 1):
            nk = self._C[self.n][k]
            self._layer_offset[k + 1] = self._layer_offset[k] + nk * (1 << k)

        self.total = self._layer_offset[self.n + 1]  # 3^n

    def colex_from_pos(self, pos: tuple[int, ...]) -> int:
        """Encode a position (tuple of i8: 0, +1, -1) to its colex index."""
        k = 0
        subset = 0
        colours = 0
        for cell in range(self.n):
            v = pos[cell]
            if v == 0:
                continue
            if v > 0:
                colours |= (1 << k)
            k += 1
            subset += self._C[cell][k]  # C(cell, k) with k 1-based
        return self._layer_offset[k] + subset * (1 << k) + colours

    def pos_from_colex(self, idx: int) -> tuple[int, ...]:
        """Decode a colex index to a position."""
        assert 0 <= idx < self.total
        k = 0
        while idx >= self._layer_offset[k + 1]:
            k += 1
        layer_idx = idx - self._layer_offset[k]
        subset = layer_idx >> k
        colours = layer_idx & ((1 << k) - 1)

        pos = [0] * self.n
        for i in range(k, 0, -1):
            cell = self.n - 1
            while self._C[cell][i] > subset:
                cell -= 1
            subset -= self._C[cell][i]
            black = ((colours >> (i - 1)) & 1) == 1
            pos[cell] = 1 if black else -1
        return tuple(pos)


# ═══════════════════════════════════════════════════════════════════════════════
# Basic-ko rules engine — independent re-implementation
# Identical semantics to src/vb_graph.zig (BasicKo type).
# Uses the corrected single-stone ko rule (F5 fix, QA-023).
# ═══════════════════════════════════════════════════════════════════════════════

class BasicKo:
    """Basic-ko rules engine for w×h goban."""
    def __init__(self, w: int, h: int):
        self.w = w
        self.h = h
        self.n = w * h
        self.KO_NONE = self.n  # sentinel

    def neighbors(self, p: int) -> list[int]:
        """Neighbour cells of p (up to 4)."""
        nb = []
        row, col = divmod(p, self.w)
        if row > 0:
            nb.append(p - self.w)
        if row + 1 < self.h:
            nb.append(p + self.w)
        if col > 0:
            nb.append(p - 1)
        if col + 1 < self.w:
            nb.append(p + 1)
        return nb

    def _chain_captured(self, pos: tuple[int, ...], seed: int):
        """Flood the chain containing seed. Returns (has_liberty: bool, chain_cells: list)."""
        colour = 1 if pos[seed] > 0 else -1
        visited = {seed}
        stack = [seed]
        chain = [seed]
        has_liberty = False
        while stack:
            q = stack.pop()
            for r in self.neighbors(q):
                if pos[r] == 0:
                    has_liberty = True
                elif pos[r] * colour > 0 and r not in visited:
                    visited.add(r)
                    stack.append(r)
                    chain.append(r)
        return has_liberty, chain

    def is_legal_position(self, pos: tuple[int, ...]) -> bool:
        """Check if every group has at least one liberty."""
        visited = set()
        for i in range(self.n):
            if pos[i] == 0 or i in visited:
                continue
            has_liberty, chain = self._chain_captured(pos, i)
            if not has_liberty:
                return False
            visited.update(chain)
        return True

    def apply_move(self, pos: tuple[int, ...], colour: int, cell: int,
                   ko_forbidden: int) -> tuple[tuple[int, ...], int] | None:
        """Apply a stone move. Returns (new_pos, new_ko_point) or None if illegal.

        colour: +1 (Black) or -1 (White).  ko_forbidden: cell index or KO_NONE.
        Uses the corrected single-stone ko rule (F5 fix).
        """
        if pos[cell] != 0:
            return None
        if cell == ko_forbidden:
            return None

        next_pos = list(pos)
        next_pos[cell] = colour

        # Capture opponent chains with no liberty
        for q in self.neighbors(cell):
            if next_pos[q] * colour < 0:
                has_liberty, chain = self._chain_captured(tuple(next_pos), q)
                if not has_liberty:
                    for c in chain:
                        next_pos[c] = 0

        # Suicide check
        has_liberty, _ = self._chain_captured(tuple(next_pos), cell)
        if not has_liberty:
            return None

        # Determine new ko point (corrected single-stone rule)
        new_ko = self.KO_NONE
        opp_before = sum(1 for v in pos if v * colour < 0)
        opp_after = sum(1 for v in next_pos if v * colour < 0)
        if opp_before - opp_after == 1:
            # Find the single captured stone
            captured_cell = None
            for i in range(self.n):
                if pos[i] * colour < 0 and next_pos[i] == 0:
                    captured_cell = i
                    break
            if captured_cell is not None:
                empty_nbrs = 0
                friendly_nbrs = 0
                for q in self.neighbors(cell):
                    if next_pos[q] == 0:
                        empty_nbrs += 1
                    if next_pos[q] == colour:
                        friendly_nbrs += 1
                if empty_nbrs == 1 and friendly_nbrs == 0:
                    new_ko = captured_cell

        return tuple(next_pos), new_ko


# ═══════════════════════════════════════════════════════════════════════════════
# Linear graph address — mirrors Zig encodeNode/decodeNode
# ═══════════════════════════════════════════════════════════════════════════════

def encode_node(n: int, colex_idx: int, side: int, ko_point: int, passes: int) -> int:
    """Encode (colex_idx, side, ko_point, passes) → linear ID.

    side: 0=Black, 1=White.  ko_point: 0..n-1 = cell, n = KO_NONE.
    passes: 0, 1, or 2.
    """
    sub_stride = (n + 1) * 3
    stride = 2 * sub_stride
    ko_encoded = 0 if ko_point == n else ko_point + 1
    return colex_idx * stride + side * sub_stride + ko_encoded * 3 + passes


def decode_node(n: int, linear: int) -> tuple[int, int, int, int]:
    """Decode linear ID → (colex_idx, side, ko_point, passes)."""
    sub_stride = (n + 1) * 3
    stride = 2 * sub_stride
    colex_idx = linear // stride
    rem = linear % stride
    side = rem // sub_stride
    rem2 = rem % sub_stride
    ko_encoded = rem2 // 3
    passes = rem2 % 3
    ko_point = n if ko_encoded == 0 else ko_encoded - 1
    return colex_idx, side, ko_point, passes


# ═══════════════════════════════════════════════════════════════════════════════
# I5 graph construction + Tarjan SCC
# ═══════════════════════════════════════════════════════════════════════════════

def i5_calibrate_3x2() -> dict:
    """Run the I5 calibration at 3×2 — true-root reachable graph.

    Returns dict with keys: V, E, sccs_total, sccs_non_trivial,
    max_scc_triple, cycle_involved_triple, cycle_reachable_quad.
    """
    w, h = 3, 2
    n = w * h
    C = Colex(w, h)
    K = BasicKo(w, h)

    # ── Phase 1: BFS reachable-state discovery ──────────────────────────────

    # Seed: empty board, Black to move, ko=NONE, passes=0
    empty_pos = tuple([0] * n)
    empty_colex = C.colex_from_pos(empty_pos)
    start_linear = encode_node(n, empty_colex, 0, K.KO_NONE, 0)

    # visited: linear_id → dense_id
    visited = {}
    dense_to_linear = []
    queue = [start_linear]
    visited[start_linear] = 0
    dense_to_linear.append(start_linear)

    qhead = 0
    while qhead < len(queue):
        cur_linear = queue[qhead]
        qhead += 1
        colex_idx, side, ko_point, passes = decode_node(n, cur_linear)
        pos = C.pos_from_colex(colex_idx)
        colour = 1 if side == 0 else -1
        other_side = 1 - side

        # Placement successors
        for cell in range(n):
            if pos[cell] != 0:
                continue
            result = K.apply_move(pos, colour, cell, ko_point)
            if result is None:
                continue
            child_pos, child_ko = result
            child_colex = C.colex_from_pos(child_pos)
            child_linear = encode_node(n, child_colex, other_side, child_ko, 0)
            if child_linear not in visited:
                visited[child_linear] = len(dense_to_linear)
                dense_to_linear.append(child_linear)
                queue.append(child_linear)

        # Pass successor
        if passes < 2:
            pass_linear = encode_node(n, colex_idx, other_side, K.KO_NONE, passes + 1)
            if pass_linear not in visited:
                visited[pass_linear] = len(dense_to_linear)
                dense_to_linear.append(pass_linear)
                queue.append(pass_linear)

    V = len(dense_to_linear)

    # Count passes levels
    p0 = p1 = p2 = 0
    for lin in dense_to_linear:
        _, _, _, passes = decode_node(n, lin)
        if passes == 0:
            p0 += 1
        elif passes == 1:
            p1 += 1
        elif passes == 2:
            p2 += 1

    # ── Build adjacency for edge counting ──────────────────────────────────

    adjacency = []  # list of list of dense_ids
    E = 0
    for v, cur_linear in enumerate(dense_to_linear):
        colex_idx, side, ko_point, passes = decode_node(n, cur_linear)
        pos = C.pos_from_colex(colex_idx)
        colour = 1 if side == 0 else -1
        other_side = 1 - side

        children = []
        for cell in range(n):
            if pos[cell] != 0:
                continue
            result = K.apply_move(pos, colour, cell, ko_point)
            if result is None:
                continue
            child_pos, child_ko = result
            child_colex = C.colex_from_pos(child_pos)
            child_linear = encode_node(n, child_colex, other_side, child_ko, 0)
            child_dense = visited.get(child_linear)
            if child_dense is not None:
                children.append(child_dense)

        if passes < 2:
            pass_linear = encode_node(n, colex_idx, other_side, K.KO_NONE, passes + 1)
            pass_dense = visited.get(pass_linear)
            if pass_dense is not None:
                children.append(pass_dense)

        adjacency.append(children)
        E += len(children)

    # ── Phase 2: iterative Tarjan SCC ──────────────────────────────────────

    tarjan_index = [-1] * V
    tarjan_lowlink = [0] * V
    tarjan_onstack = [False] * V
    tarjan_comp = [0] * V  # component id for each vertex
    tarjan_stack = []       # stack of vertex indices
    tarjan_counter = 0
    tarjan_ncomp = 0

    # Iterative DFS frames: (v, child_idx)
    for root in range(V):
        if tarjan_index[root] != -1:
            continue

        frames = [(root, 0)]

        while frames:
            v, child_idx = frames[-1]

            if child_idx == 0:
                # First visit
                tarjan_index[v] = tarjan_counter
                tarjan_lowlink[v] = tarjan_counter
                tarjan_counter += 1
                tarjan_stack.append(v)
                tarjan_onstack[v] = True

            children = adjacency[v]
            recurse = False
            for i in range(child_idx, len(children)):
                w = children[i]
                frames[-1] = (v, i + 1)
                if tarjan_index[w] == -1:
                    # Tree edge
                    frames.append((w, 0))
                    recurse = True
                    break
                elif tarjan_onstack[w]:
                    # Back/cross edge to vertex on stack
                    if tarjan_index[w] < tarjan_lowlink[v]:
                        tarjan_lowlink[v] = tarjan_index[w]
            if recurse:
                continue

            # v is done — check if root of SCC
            if tarjan_lowlink[v] == tarjan_index[v]:
                while True:
                    popped = tarjan_stack.pop()
                    tarjan_onstack[popped] = False
                    tarjan_comp[popped] = tarjan_ncomp
                    if popped == v:
                        break
                tarjan_ncomp += 1

            frames.pop()  # v's frame done
            # Propagate lowlink to parent
            if frames:
                parent_v = frames[-1][0]
                if tarjan_lowlink[v] < tarjan_lowlink[parent_v]:
                    tarjan_lowlink[parent_v] = tarjan_lowlink[v]

    # ── Phase 3: project SCCs to triples (board, side, ko) ────────────────

    # Collect triples per SCC
    comp_triple_sets = [set() for _ in range(tarjan_ncomp)]
    for v, lin in enumerate(dense_to_linear):
        colex_idx, side, ko_point, _ = decode_node(n, lin)
        triple_key = colex_idx * (2 * (n + 1)) + side * (n + 1) + (0 if ko_point == n else ko_point + 1)
        comp_triple_sets[tarjan_comp[v]].add(triple_key)

    # Triple-level SCC sizes
    comp_triple_sizes = [len(s) for s in comp_triple_sets]

    max_scc_triple = max(comp_triple_sizes) if comp_triple_sizes else 0
    sccs_non_trivial = sum(1 for sz in comp_triple_sizes if sz >= 2)
    cycle_involved_triple = sum(sz for sz in comp_triple_sizes if sz >= 2)

    # ── Phase 4: cycle-reachable at quadruple level (reverse BFS) ──────────

    # Build reverse adjacency
    rev_adj = [[] for _ in range(V)]
    for v, children in enumerate(adjacency):
        for child in children:
            rev_adj[child].append(v)

    # Seed: cycle-involved vertices (those in non-trivial SCCs at triple level)
    cycle_reachable = [False] * V
    rev_queue = []
    for v in range(V):
        if comp_triple_sizes[tarjan_comp[v]] >= 2:
            cycle_reachable[v] = True
            rev_queue.append(v)

    rev_qhead = 0
    while rev_qhead < len(rev_queue):
        v = rev_queue[rev_qhead]
        rev_qhead += 1
        for parent in rev_adj[v]:
            if not cycle_reachable[parent]:
                cycle_reachable[parent] = True
                rev_queue.append(parent)

    cycle_reachable_quad = sum(1 for b in cycle_reachable if b)

    return {
        "V": V,
        "E": E,
        "p0": p0,
        "p1": p1,
        "p2": p2,
        "sccs_total": tarjan_ncomp,
        "sccs_non_trivial": sccs_non_trivial,
        "max_scc_triple": max_scc_triple,
        "cycle_involved_triple": cycle_involved_triple,
        "cycle_reachable_quad": cycle_reachable_quad,
    }


# ═══════════════════════════════════════════════════════════════════════════════
# main
# ═══════════════════════════════════════════════════════════════════════════════

if __name__ == "__main__":
    import sys
    import time

    t0 = time.monotonic()
    r = i5_calibrate_3x2()
    elapsed = time.monotonic() - t0

    # Emit key=value for the Zig gate (one per line)
    print(f"V={r['V']}")
    print(f"E={r['E']}")
    print(f"p0={r['p0']}")
    print(f"p1={r['p1']}")
    print(f"p2={r['p2']}")
    print(f"sccs_total={r['sccs_total']}")
    print(f"sccs_non_trivial={r['sccs_non_trivial']}")
    print(f"max_scc_triple={r['max_scc_triple']}")
    print(f"cycle_involved_triple={r['cycle_involved_triple']}")
    print(f"cycle_reachable_quad={r['cycle_reachable_quad']}")
    print(f"elapsed_s={elapsed:.3f}")

    # Sanity checks
    assert r["V"] == 2583, f"V mismatch: expected 2583, got {r['V']}"
    assert r["p0"] + r["p1"] + r["p2"] == r["V"]
    assert r["sccs_non_trivial"] <= r["sccs_total"]
    assert r["cycle_involved_triple"] <= r["V"]
    assert r["cycle_reachable_quad"] <= r["V"]

    print("# OK", file=sys.stderr)
    sys.exit(0)
