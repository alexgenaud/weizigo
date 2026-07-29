#!/usr/bin/env python3
"""Does basic-ko formalization (i) ever fire on 2x2 — old rule vs corrected?

Independent transcription of Brute2x2.State.apply_place. Exhaustive over all
3^4 boards x 2 sides x 4 empty cells. Substitutes for the in-file zig tests,
which run the EXP-2A path-DFS (the 10h22m hazard) and cannot be executed.
"""
W = H = 2
N = W * H
NBR = []
for p in range(N):
    r, c = divmod(p, W)
    ns = []
    if r > 0: ns.append(p - W)
    if r < H - 1: ns.append(p + W)
    if c > 0: ns.append(p - 1)
    if c < W - 1: ns.append(p + 1)
    NBR.append(ns)


def chain(board, p):
    col = board[p]
    seen, stack, libs = {p}, [p], set()
    while stack:
        q = stack.pop()
        for r in NBR[q]:
            if board[r] == 0:
                libs.add(r)
            elif board[r] == col and r not in seen:
                seen.add(r); stack.append(r)
    return seen, libs


def pos_from_move(board, colour, cell):
    """Tromp-Taylor place: put stone, remove opponent groups with no liberty,
    then reject if the placed group is itself dead (suicide)."""
    nxt = list(board)
    nxt[cell] = colour
    for q in NBR[cell]:
        if nxt[q] == -colour:
            cells, libs = chain(nxt, q)
            if not libs:
                for c in cells:
                    nxt[c] = 0
    _, libs = chain(nxt, cell)
    if not libs:
        return None  # suicide
    return nxt


def ko_after(board, colour, cell, corrected):
    nxt = pos_from_move(board, colour, cell)
    if nxt is None:
        return None, None
    opp_before = sum(1 for i in range(N) if board[i] == -colour)
    opp_after = sum(1 for i in range(N) if nxt[i] == -colour)
    captured = [i for i in range(N) if board[i] == -colour and nxt[i] == 0]
    ko = None
    if opp_before - opp_after == 1 and captured:
        empty_nbrs = sum(1 for q in NBR[cell] if nxt[q] == 0)
        if corrected:
            friendly = sum(1 for q in NBR[cell] if nxt[q] == colour)
            if empty_nbrs == 1 and friendly == 0:
                ko = captured[-1]
        else:
            if empty_nbrs == 1:
                ko = captured[-1]
    return nxt, ko


def main():
  for corrected in (False, True):
    fires = []
    for code in range(3 ** N):
        board, c = [], code
        for _ in range(N):
            board.append([0, 1, -1][c % 3]); c //= 3
        for colour in (1, -1):
            for cell in range(N):
                if board[cell] != 0:
                    continue
                nxt, ko = ko_after(board, colour, cell, corrected)
                if ko is not None:
                    fires.append((tuple(board), colour, cell, ko))
    label = "corrected (lone-stone)" if corrected else "as-implemented (old)"
    print(f"2x2, {label:24s}: ko-setting placements = {len(fires)}")
    for f in fires[:10]:
        print("   ", f)


if __name__ == "__main__":
    main()
