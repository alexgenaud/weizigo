#!/usr/bin/env python3
# T507 — independent re-implementation of the t358 census reachability BFS,
# to cross-check the Zig instruments' numbers and verify the root-seeding
# convention (passes in {0} vs {0,1} are equivalent; ko=cell-on-empty is a
# real over-seed).  Pure stdlib.  Runs 2x2 and 3x2 (3x3/4x3 too slow in
# Python; those are cross-checked against committed artifact headers).
import sys

def census(w, h):
    n = w * h
    raw_total = 3 ** n
    ko_dims = n + 1
    ko_none = n
    total_states = raw_total * 2 * ko_dims * 3  # passes 3 * side 2 * ko (n+1) * board

    def unrank(idx):
        b = [0] * n
        for i in range(n):
            d = idx % 3
            idx //= 3
            b[i] = 0 if d == 0 else (1 if d == 1 else -1)
        return b

    def rank(b):
        idx = 0
        mult = 1
        for c in b:
            d = 0 if c == 0 else (1 if c > 0 else 2)
            idx += d * mult
            mult *= 3
        return idx

    def neighbors(cell):
        r = cell // w
        c = cell % w
        out = []
        if r > 0: out.append(cell - w)
        if r < h - 1: out.append(cell + w)
        if c > 0: out.append(cell - 1)
        if c < w - 1: out.append(cell + 1)
        return out

    def apply_place(board, side, ko, cell):
        # side: +1 Black, -1 White.  board entries: 0 empty, +1 B, -1 W.
        if board[cell] != 0:
            return None
        if ko != ko_none and cell == ko:
            return None
        nextb = list(board)
        nextb[cell] = side
        # capture opponent chains with 0 liberties
        opp = -side
        changed = True
        while changed:
            changed = False
            # find chains of opp
            visited = [False] * n
            for i in range(n):
                if nextb[i] == opp and not visited[i]:
                    # BFS chain
                    stack = [i]
                    visited[i] = True
                    chain = []
                    libs = 0
                    while stack:
                        q = stack.pop()
                        chain.append(q)
                        for nb in neighbors(q):
                            if nextb[nb] == opp and not visited[nb]:
                                visited[nb] = True
                                stack.append(nb)
                            elif nextb[nb] == 0:
                                libs += 1
                    if libs == 0:
                        for q in chain:
                            nextb[q] = 0
                        changed = True
        # suicide check: own chain at cell must have >= 1 liberty
        # (if the placed stone was captured by opp in the loop above, it's
        #  suicide only if it has 0 libs; but our capture loop only removes
        #  opp chains.  Check own chain liberty.)
        own = side
        visited = [False] * n
        stack = [cell]
        visited[cell] = True
        libs = 0
        while stack:
            q = stack.pop()
            for nb in neighbors(q):
                if nextb[nb] == own and not visited[nb]:
                    visited[nb] = True
                    stack.append(nb)
                elif nextb[nb] == 0:
                    libs += 1
        if libs == 0:
            return None  # suicide
        # ko determination: single-stone capture where placed stone is lone
        # and its sole liberty is the captured cell
        opp_before = sum(1 for x in board if x == opp)
        opp_after = sum(1 for x in nextb if x == opp)
        new_ko = ko_none
        if opp_before - opp_after == 1:
            captured = None
            for i in range(n):
                if board[i] == opp and nextb[i] == 0:
                    captured = i
            if captured is not None:
                # placed stone chain: liberties and friendly neighbours
                libs2 = 0
                friendly = 0
                for nb in neighbors(cell):
                    if nextb[nb] == 0: libs2 += 1
                    if nextb[nb] == side: friendly += 1
                if libs2 == 1 and friendly == 0:
                    new_ko = captured
        return (rank(nextb), -side, new_ko)

    def apply_pass(board, side, passes):
        if passes >= 2:
            return None
        return (rank(board), -side, ko_none)

    def linear(board_idx, side_idx, ko, passes):
        return ((passes * 2 + side_idx) * ko_dims + ko) * raw_total + board_idx

    def bfs(seed_passes):
        reach = bytearray(total_states)
        for side_idx in (0, 1):
            for passes in seed_passes:
                lin = linear(0, side_idx, ko_none, passes)
                reach[lin] = 1
        # iterative frontier BFS (mark & sweep over full space)
        new_marks = 1
        sweeps = 0
        while new_marks > 0 and sweeps < 64:
            sweeps += 1
            new_marks = 0
            # snapshot
            snap = bytes(reach)
            for lin in range(total_states):
                if snap[lin] == 0:
                    continue
                passes = lin // (2 * ko_dims * raw_total)
                if passes == 2:
                    continue
                rest = lin % (2 * ko_dims * raw_total)
                side_idx = rest // (ko_dims * raw_total)
                rest2 = rest % (ko_dims * raw_total)
                ko = rest2 // raw_total
                board_idx = rest2 % raw_total
                board = unrank(board_idx)
                side = 1 if side_idx == 0 else -1
                succ = []
                p = apply_pass(board, side, passes)
                if p is not None:
                    succ.append(linear(p[0], 0 if p[1] == 1 else 1, p[2], passes + 1))
                for cell in range(n):
                    r = apply_place(board, side, ko, cell)
                    if r is not None:
                        succ.append(linear(r[0], 0 if r[1] == 1 else 1, r[2], 0))
                for s in succ:
                    if reach[s] == 0:
                        reach[s] = 1
                        new_marks += 1
        total = sum(1 for x in reach if x)
        p01 = sum(1 for lin in range(total_states) if reach[lin] and lin // (2 * ko_dims * raw_total) < 2)
        p2 = total - p01
        by_side = [0, 0]
        legal_boards = set()
        for lin in range(total_states):
            if reach[lin]:
                rest = lin % (2 * ko_dims * raw_total)
                side_idx = (rest // (ko_dims * raw_total))
                by_side[side_idx] += 1
                board_idx = (rest % (ko_dims * raw_total)) % raw_total
                # a board is "legal" if it has no chain with 0 liberties
                b = unrank(board_idx)
                if _is_legal_board(b, w, h):
                    legal_boards.add(board_idx)
        return total, p01, p2, by_side, len(legal_boards), sweeps

    return total_states, bfs

def _is_legal_board(b, w, h):
    n = w * h
    def neighbors(cell):
        r = cell // w; c = cell % w; out = []
        if r > 0: out.append(cell - w)
        if r < h - 1: out.append(cell + w)
        if c > 0: out.append(cell - 1)
        if c < w - 1: out.append(cell + 1)
        return out
    for i in range(n):
        if b[i] != 0:
            col = b[i]
            visited = [False] * n
            stack = [i]; visited[i] = True; libs = 0
            while stack:
                q = stack.pop()
                for nb in neighbors(q):
                    if b[nb] == col and not visited[nb]:
                        visited[nb] = True; stack.append(nb)
                    elif b[nb] == 0:
                        libs += 1
            if libs == 0:
                return False
    return True

for (w, h) in [(2, 2), (3, 2)]:
    total_states, bfs = census(w, h)
    for seed_passes in ([0], [0, 1]):
        total, p01, p2, by_side, legal, sweeps = bfs(seed_passes)
        print(f"{w}x{h} seeds={seed_passes}: total={total} p01={p01} p2={p2} "
              f"B={by_side[0]} W={by_side[1]} legal={legal} sweeps={sweeps} "
              f"(space={total_states})")
