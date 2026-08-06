#!/usr/bin/env python3
"""
T391 — third-route I5 verification at 3×2 (and all-legal mode).

Independent re-implementation, written 2026-08-06 for T391 adjudication.
Deliberately does NOT import or mirror any existing instrument's code beyond
the two things that are fixed by contract and cannot be chosen independently:

  1. The WZO1 artifact layout (src/artifact.zig:40-55) — the file format.
  2. The layered-colex index (ADR-0007) — the artifact's address space.

Everything else (basic-ko move generator, pass semantics, BFS, Tarjan,
cycle-reachable, KO_SENSITIVE census) is written here from the rule
statements, in this file's own style.

The two-pass terminal rule (the point of the adjudication):
  passes ∈ {0,1,2}; a state with passes == 2 has NO outgoing moves (two
  passes end the game — "pass edges are terminal cut-edges", the committed
  model). The buggy variant --buggy removes this guard and lets a passes=2
  state make placement moves (as src/vb_graph.zig does today), to
  demonstrate that this single difference produces the general instrument's
  inflated E / maxSCC / cycle-reachable readings.

The ko rule (F5 fix, QA-023 / ko-fix-rerun-2026-07-29.md §1): a placement
sets a ko point iff (a) exactly one opponent stone is captured AND (b) the
placed stone's resulting chain has size 1 AND exactly 1 liberty (which, given
(a), is necessarily the vacated cell).

Usage:
  python3 t391-third-route.py 3x2            # true-root reachable graph
  python3 t391-third-route.py 3x2 --buggy    # vb_graph's passes=2 behaviour
  python3 t391-third-route.py 3x2 --alllegal # seed all legal positions
Output: key=value lines on stdout.
"""
import math
import struct
import sys
import time
from collections import deque

WZO1_HDR = 32

# ─────────────────────────────────────────────────────────────────────────────
# WZO1 reader (artifact.zig:40-55 contract)
# ─────────────────────────────────────────────────────────────────────────────

def read_wzo1(path):
    with open(path, "rb") as f:
        b = f.read()
    assert b[0:4] == b"WZO1", "bad magic"
    assert b[4] == 1, "bad format version"
    w, h = b[6], b[7]
    total = struct.unpack("<Q", b[12:20])[0]
    assert total == 3 ** (w * h)
    assert len(b) == WZO1_HDR + 6 * total
    fb = b[WZO1_HDR + 2 * total : WZO1_HDR + 3 * total]
    fw = b[WZO1_HDR + 3 * total : WZO1_HDR + 4 * total]
    return w, h, fb, fw


# ─────────────────────────────────────────────────────────────────────────────
# Layered colex (ADR-0007) — written here from the spec, using math.comb
# ─────────────────────────────────────────────────────────────────────────────

class Colex:
    def __init__(self, n):
        self.n = n
        # layer_offset[k] = number of positions with < k stones
        self.layer_offset = [0] * (n + 2)
        for k in range(n + 1):
            self.layer_offset[k + 1] = self.layer_offset[k] + math.comb(n, k) * (1 << k)
        self.total = self.layer_offset[n + 1]

    def encode(self, pos):
        """pos: tuple of 0/+1/-1 in row-major cell order. → colex index."""
        k = 0
        subset = 0
        colours = 0
        for cell, v in enumerate(pos):
            if v == 0:
                continue
            if v > 0:
                colours |= 1 << k
            k += 1
            subset += math.comb(cell, k)
        return self.layer_offset[k] + subset * (1 << k) + colours

    def decode(self, idx):
        n = self.n
        k = 0
        while idx >= self.layer_offset[k + 1]:
            k += 1
        layer = idx - self.layer_offset[k]
        subset = layer >> k
        colours = layer & ((1 << k) - 1)
        pos = [0] * n
        for i in range(k, 0, -1):  # i = 1-based stone rank, from last to first
            cell = n - 1
            while math.comb(cell, i) > subset:
                cell -= 1
            subset -= math.comb(cell, i)
            pos[cell] = 1 if ((colours >> (i - 1)) & 1) else -1
        return tuple(pos)


# ─────────────────────────────────────────────────────────────────────────────
# Basic-ko engine — written from the F5 rule statement
# ─────────────────────────────────────────────────────────────────────────────

class Rules:
    def __init__(self, w, h):
        self.w = w
        self.h = h
        self.n = w * h
        self.KO_NONE = self.n

    def _chain(self, pos, seed):
        """Flood the chain of pos[seed]. Returns (has_liberty, chain_cells)."""
        colour = 1 if pos[seed] > 0 else -1
        seen = {seed}
        stack = [seed]
        chain = [seed]
        has_lib = False
        while stack:
            q = stack.pop()
            r, c = divmod(q, self.w)
            for nb in (
                (q - self.w) if r > 0 else None,
                (q + self.w) if r + 1 < self.h else None,
                (q - 1) if c > 0 else None,
                (q + 1) if c + 1 < self.w else None,
            ):
                if nb is None:
                    continue
                if pos[nb] == 0:
                    has_lib = True
                elif pos[nb] == colour and nb not in seen:
                    seen.add(nb)
                    stack.append(nb)
                    chain.append(nb)
        return has_lib, chain

    def is_legal(self, pos):
        seen = set()
        for i, v in enumerate(pos):
            if v == 0 or i in seen:
                continue
            has_lib, chain = self._chain(pos, i)
            if not has_lib:
                return False
            seen.update(chain)
        return True

    def place(self, pos, colour, cell, ko_forbidden):
        """Try placing `colour` at `cell`. Returns (new_pos, new_ko) or None."""
        if pos[cell] != 0:
            return None
        if cell == ko_forbidden:
            return None

        nxt = list(pos)
        nxt[cell] = colour
        opp = -colour

        # capture opponent chains with no liberty
        r, c = divmod(cell, self.w)
        for nb in (
            (cell - self.w) if r > 0 else None,
            (cell + self.w) if r + 1 < self.h else None,
            (cell - 1) if c > 0 else None,
            (cell + 1) if c + 1 < self.w else None,
        ):
            if nb is None or nxt[nb] != opp:
                continue
            has_lib, chain = self._chain(tuple(nxt), nb)
            if not has_lib:
                for m in chain:
                    nxt[m] = 0

        # suicide check
        has_lib, _ = self._chain(tuple(nxt), cell)
        if not has_lib:
            return None

        # ko point (F5): exactly one capture AND lone placed stone with
        # exactly one liberty.
        captured = sum(1 for a, b in zip(pos, nxt) if a == opp and b == 0)
        new_ko = self.KO_NONE
        if captured == 1:
            chain_size = 0
            liberties = 0
            r2, c2 = divmod(cell, self.w)
            for nb in (
                (cell - self.w) if r2 > 0 else None,
                (cell + self.w) if r2 + 1 < self.h else None,
                (cell - 1) if c2 > 0 else None,
                (cell + 1) if c2 + 1 < self.w else None,
            ):
                if nb is None:
                    continue
                if nxt[nb] == colour:
                    chain_size += 1
                elif nxt[nb] == 0:
                    liberties += 1
            if chain_size == 0 and liberties == 1:
                for i in range(self.n):
                    if pos[i] == opp and nxt[i] == 0:
                        new_ko = i
                        break
        return tuple(nxt), new_ko


# ─────────────────────────────────────────────────────────────────────────────
# Graph build: BFS from seeds, adjacency, Tarjan, cycle-reachable
# ─────────────────────────────────────────────────────────────────────────────

def build_graph(w, h, seeds, buggy):
    """BFS from `seeds` (list of (colex, side, ko, passes) states).

    Returns (adjacency, vertices, root_to_v) where vertices[i] is the
    (colex, side, ko, passes) state. If buggy, passes=2 states still make
    placement moves (the vb_graph defect); pass edges are still capped at 2.
    """
    R = Rules(w, h)
    C = Colex(w * h)
    n = w * h

    adj = []          # adjacency[i] = list of dense child ids
    vertices = []     # vertices[i] = (colex, side, ko, passes)
    vid = {}          # state -> dense id

    q = deque()
    for seed in seeds:
        if seed not in vid:
            vid[seed] = len(vertices)
            vertices.append(seed)
            q.append(seed)

    while q:
        colex, side, ko, passes = q.popleft()
        pos = C.decode(colex)
        colour = 1 if side == 0 else -1
        other = 1 - side
        children = []

        if not (passes >= 2 and not buggy):
            # placement successors (skip entirely for terminal passes=2 in
            # the correct model)
            for cell in range(n):
                if pos[cell] != 0:
                    continue
                res = R.place(pos, colour, cell, ko)
                if res is None:
                    continue
                npos, nko = res
                child = (C.encode(npos), other, nko, 0)
                if child not in vid:
                    vid[child] = len(vertices)
                    vertices.append(child)
                    q.append(child)
                children.append(vid[child])
        if passes < 2:
            # pass successor
            child = (colex, other, R.KO_NONE, passes + 1)
            if child not in vid:
                vid[child] = len(vertices)
                vertices.append(child)
                q.append(child)
            children.append(vid[child])
        adj.append(children)

    return adj, vertices


def tarjan(adj):
    """Iterative Tarjan. Returns (comp_id per vertex, n_components)."""
    n = len(adj)
    index = [-1] * n
    low = [0] * n
    onstk = [False] * n
    comp = [0] * n
    stk = []
    counter = [0]
    ncomp = [0]

    for root in range(n):
        if index[root] != -1:
            continue
        frames = [(root, 0)]
        while frames:
            v, ci = frames[-1]
            if ci == 0:
                index[v] = low[v] = counter[0]
                counter[0] += 1
                stk.append(v)
                onstk[v] = True
            recurse = False
            i = ci
            while i < len(adj[v]):
                w = adj[v][i]
                frames[-1] = (v, i + 1)
                i += 1
                if index[w] == -1:
                    frames.append((w, 0))
                    recurse = True
                    break
                elif onstk[w]:
                    if index[w] < low[v]:
                        low[v] = index[w]
            if recurse:
                continue
            if low[v] == index[v]:
                while True:
                    w = stk.pop()
                    onstk[w] = False
                    comp[w] = ncomp[0]
                    if w == v:
                        break
                ncomp[0] += 1
            frames.pop()
            if frames:
                u = frames[-1][0]
                if low[v] < low[u]:
                    low[u] = low[v]
    return comp, ncomp[0]


def cycle_reachable(adj, comp, comp_size):
    """Reverse BFS from vertices in non-trivial (size>=2) SCCs. → bool list."""
    n = len(adj)
    cr = [False] * n
    q = deque()
    for v in range(n):
        if comp_size[comp[v]] >= 2:
            cr[v] = True
            q.append(v)
    rev = [[] for _ in range(n)]
    for v, ch in enumerate(adj):
        for c in ch:
            rev[c].append(v)
    while q:
        v = q.popleft()
        for p in rev[v]:
            if not cr[p]:
                cr[p] = True
                q.append(p)
    return cr


# ─────────────────────────────────────────────────────────────────────────────
# main
# ─────────────────────────────────────────────────────────────────────────────

def run(goban, artifact_path, mode):
    w, h = {"2x2": (2, 2), "3x2": (3, 2), "4x3": (4, 3)}[goban]
    n = w * h
    aw, ah, fb, fw = read_wzo1(artifact_path)
    assert (aw, ah) == (w, h)
    C = Colex(n)
    R = Rules(w, h)
    buggy = (mode == "buggy")

    t0 = time.monotonic()

    # seeds
    if mode == "alllegal":
        seeds = []
        # odometer over all 3^n positions
        digits = [0] * n
        pos = [0] * n
        while True:
            if R.is_legal(tuple(pos)):
                colex = C.encode(tuple(pos))
                for s in (0, 1):
                    seeds.append((colex, s, R.KO_NONE, 0))
            i = 0
            while i < n:
                if digits[i] == 2:
                    digits[i] = 0
                    pos[i] = 0
                    i += 1
                    continue
                digits[i] += 1
                pos[i] = 1 if digits[i] == 1 else -1
                break
            if i == n:
                break
        print(f"all_legal_seeds={len(seeds)}")
    else:
        empty = tuple([0] * n)
        seeds = [(C.encode(empty), 0, R.KO_NONE, 0)]

    adj, vertices = build_graph(w, h, seeds, buggy)
    V = len(vertices)
    E = sum(len(a) for a in adj)

    p0 = p1 = p2 = 0
    for colex, side, ko, passes in vertices:
        if passes == 0:
            p0 += 1
        elif passes == 1:
            p1 += 1
        else:
            p2 += 1

    comp, ncomp = tarjan(adj)
    comp_size = [0] * ncomp
    for c in comp:
        comp_size[c] += 1
    non_trivial = sum(1 for s in comp_size if s >= 2)
    max_scc = max(comp_size)
    cycle_involved = sum(s for s in comp_size if s >= 2)

    cr = cycle_reachable(adj, comp, comp_size)
    cycle_reachable_count = sum(1 for b in cr if b)

    # KO_SENSITIVE
    ko_raw_census = sum(1 for x in fb if x & 1) + sum(1 for x in fw if x & 1)
    ko_graph = 0
    ko_not_cr = 0
    for i, (colex, side, ko, passes) in enumerate(vertices):
        if ko == R.KO_NONE and passes == 0:
            flag = (fb[colex] if side == 0 else fw[colex]) & 1
            if flag:
                ko_graph += 1
                if not cr[i]:
                    ko_not_cr += 1

    elapsed = time.monotonic() - t0
    print(f"goban={goban} mode={mode} buggy={int(buggy)}")
    print(f"V={V}")
    print(f"E={E}")
    print(f"p0={p0} p1={p1} p2={p2}")
    print(f"sccs_total={ncomp}")
    print(f"sccs_non_trivial={non_trivial}")
    print(f"max_scc={max_scc}")
    print(f"cycle_involved={cycle_involved}")
    print(f"cycle_reachable={cycle_reachable_count}")
    print(f"ko_sensitive_raw_census={ko_raw_census}")
    print(f"ko_sensitive_graph={ko_graph}")
    print(f"ko_not_cr={ko_not_cr}")
    print(f"verdict={'fail' if ko_not_cr > 0 else 'pass'}")
    print(f"elapsed_s={elapsed:.2f}")
    return V, E, max_scc, cycle_reachable_count, ko_graph, ko_not_cr


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("usage: t391-third-route.py 3x2 [--buggy|--alllegal]")
        sys.exit(2)
    mode = "reachable"
    if "--buggy" in sys.argv:
        mode = "buggy"
    elif "--alllegal" in sys.argv:
        mode = "alllegal"
    run(sys.argv[1], f"artifacts/oracle-{sys.argv[1]}.wzo", mode)
