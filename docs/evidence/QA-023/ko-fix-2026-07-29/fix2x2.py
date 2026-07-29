#!/usr/bin/env python3
"""2x2 median-fixpoint V = median(L, TIE, H) over all 2,430 state tuples,
computed under the old ko rule and the corrected one, and diffed.

This is the 2B-0 sanctioned 2x2 evaluator (reference-semantics §2, "smoke
evaluator"), re-implemented independently. It answers: did correcting the
ko rule move any 2x2 value? The in-file zig tests cannot answer this — they
run the EXP-2A path-DFS (trilemma horn 1, the 10h22m hazard).
"""
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ko2x2 import N, NBR, chain, pos_from_move, ko_after

TIE = 0
KO_NONE = N  # sentinel: 0..3 cells, 4 = none


def rank(board):
    r = 0
    for i in reversed(range(N)):
        r = r * 3 + [0, 1, 2][[0, 1, -1].index(board[i])]
    return r


def unrank(r):
    b = []
    for _ in range(N):
        b.append([0, 1, -1][r % 3]); r //= 3
    return b


def area_score(board):
    """Tromp-Taylor: stones + territory reached only by one colour."""
    black = sum(1 for x in board if x == 1)
    white = sum(1 for x in board if x == -1)
    seen = set()
    for p in range(N):
        if board[p] != 0 or p in seen:
            continue
        region, stack, touch = {p}, [p], set()
        seen.add(p)
        while stack:
            q = stack.pop()
            for r in NBR[q]:
                if board[r] == 0:
                    if r not in region:
                        region.add(r); seen.add(r); stack.append(r)
                else:
                    touch.add(board[r])
        if touch == {1}:
            black += len(region)
        elif touch == {-1}:
            white += len(region)
    return black - white


STATES = [(b, s, k, p)
          for b in range(3 ** N) for s in (0, 1)
          for k in range(N + 1) for p in (0, 1, 2)]
IDX = {st: i for i, st in enumerate(STATES)}


def successors(st, corrected):
    b, side, ko, passes = st
    if passes == 2:
        return []
    board = unrank(b)
    colour = 1 if side == 0 else -1
    out = [(b, 1 - side, KO_NONE, passes + 1)]          # pass
    for cell in range(N):
        if board[cell] != 0:
            continue
        if ko != KO_NONE and cell == ko:
            continue
        nxt, new_ko = ko_after(board, colour, cell, corrected)
        if nxt is None:
            continue
        out.append((rank(nxt), 1 - side, KO_NONE if new_ko is None else new_ko, 0))
    return out


def fixpoint(corrected, init):
    """Least (init=-n) / greatest (init=+n) fixpoint of the Bellman operator."""
    n = N
    succ = [successors(st, corrected) for st in STATES]
    val = [area_score(unrank(st[0])) if st[3] == 2 else init for st in STATES]
    sweeps = 0
    while True:
        sweeps += 1
        changed = 0
        for i, st in enumerate(STATES):
            if st[3] == 2:
                continue
            kids = [val[IDX[c]] for c in succ[i]]
            nv = max(kids) if st[1] == 0 else min(kids)
            if nv != val[i]:
                val[i] = nv; changed += 1
        if changed == 0:
            return val, sweeps


def median(a, t, b):
    return sorted((a, t, b))[1]


res = {}
for corrected in (False, True):
    L, sl = fixpoint(corrected, -N)
    H, sh = fixpoint(corrected, +N)
    V = [median(L[i], TIE, H[i]) for i in range(len(STATES))]
    res[corrected] = V
    tag = "corrected" if corrected else "old"
    print(f"{tag:9s}: {len(STATES)} states, L sweeps={sl} H sweeps={sh}, "
          f"L==H at {sum(1 for i in range(len(STATES)) if L[i]==H[i])}")

diff = [STATES[i] for i in range(len(STATES)) if res[False][i] != res[True][i]]
print(f"\nstates whose V changed under the corrected ko rule: {len(diff)}")
for st in diff[:20]:
    i = IDX[st]
    print(f"   board={st[0]} side={st[1]} ko={st[2]} passes={st[3]}: "
          f"{res[False][i]} -> {res[True][i]}")

anchors = [
    ("empty B", (0, 0, KO_NONE, 0), 0),
    ("empty W", (0, 1, KO_NONE, 0), 0),
    ("full B", (rank([1] * N), 0, KO_NONE, 0), 4),
    ("passes=1", (0, 1, KO_NONE, 1), 0),
    ("passes=2", (0, 0, KO_NONE, 2), 0),
]
print("\nfive B1 anchors under the corrected rule:")
for name, st, want in anchors:
    got = res[True][IDX[st]]
    print(f"   {name:9s} v={got:+d} expected {want:+d}  "
          f"{'OK' if got == want else 'FAIL'}")
