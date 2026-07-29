#!/usr/bin/env python3
"""Reachable 2x2 legal-move graph + SCC, under the old and corrected ko rule.

Settles whether `2x2.T12` ("2x2 admits no reachable non-root cycles"), which
reference-semantics-2026-07-29.md §2 leans on to argue the 2x2 smoke is not
circular, survives the F5 correction.
"""
import os
import sys
from collections import deque
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from fix2x2 import STATES, IDX, successors, unrank, KO_NONE, N


def reach(corrected, roots):
    seen, dq = set(roots), deque(roots)
    while dq:
        st = dq.popleft()
        for c in successors(st, corrected):
            if c not in seen:
                seen.add(c); dq.append(c)
    return seen


def tarjan(verts, adj):
    """Iterative Tarjan; returns component id per vertex."""
    n = len(verts)
    index = [-1] * n; low = [0] * n; onstk = [False] * n
    stk, comp, counter, ncomp = [], [-1] * n, [0], [0]
    for root in range(n):
        if index[root] != -1:
            continue
        work = [(root, 0)]
        while work:
            v, pi = work[-1]
            if pi == 0:
                index[v] = low[v] = counter[0]; counter[0] += 1
                stk.append(v); onstk[v] = True
            recurse = False
            for i in range(pi, len(adj[v])):
                w = adj[v][i]
                if index[w] == -1:
                    work[-1] = (v, i + 1); work.append((w, 0))
                    recurse = True; break
                elif onstk[w]:
                    low[v] = min(low[v], index[w])
            if recurse:
                continue
            if low[v] == index[v]:
                while True:
                    w = stk.pop(); onstk[w] = False; comp[w] = ncomp[0]
                    if w == v: break
                ncomp[0] += 1
            work.pop()
            if work:
                u = work[-1][0]
                low[u] = min(low[u], low[v])
    return comp, ncomp[0]


# The true game root only: empty board, Black to move, no ko, 0 passes.
TRUE_ROOT = [(0, 0, KO_NONE, 0)]
# The seed set the code actually uses at 3x2 (empty board x side x passes x ko).
SEEDS_ALL = [(0, s, k, p) for s in (0, 1) for k in range(N + 1) for p in (0, 1, 2)]

for label, roots in (("true root", TRUE_ROOT), ("all-seed", SEEDS_ALL)):
    for corrected in (False, True):
        seen = sorted(reach(corrected, roots))
        vid = {st: i for i, st in enumerate(seen)}
        adj = [[vid[c] for c in successors(st, corrected)] for st in seen]
        E = sum(len(a) for a in adj)
        comp, nc = tarjan(seen, adj)
        sz = {}
        for c in comp:
            sz[c] = sz.get(c, 0) + 1
        nontriv = [c for c, s in sz.items() if s >= 2]
        # self-loops would also be cycles; check none exist
        selfloop = sum(1 for v in range(len(seen)) if v in adj[v])
        on_cycle = sum(1 for v in range(len(seen)) if sz[comp[v]] >= 2)
        tag = "corrected" if corrected else "old      "
        print(f"{label:9s} {tag}: V={len(seen):4d} E={E:4d} SCCs={nc:4d} "
              f"non-trivial={len(nontriv)} maxSCC={max(sz.values()):3d} "
              f"cycle-involved={on_cycle:3d} self-loops={selfloop}")
