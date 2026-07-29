#!/usr/bin/env python3
# PINRULE-SUFFICIENCY verifier — independent reimplementation (Python, stdlib only)
# Task: PINRULE-SUFFICIENCY · Worker: Kimi-k3 · Date: 2026-07-29
# Purpose: third implementation of the 3x2 rules + truncated evaluator, used to
# adjudicate the T3 (alpha-beta) vs T2 (plain minimax) divergence and the
# putative C1 witness at state (178,0,6,0).

W, H = 3, 2
N = W * H
TIE = 0

def rank(board):
    idx, mult = 0, 1
    for c in board:
        d = 1 if c > 0 else (2 if c < 0 else 0)
        idx += d * mult
        mult *= 3
    return idx

def unrank(idx):
    b = []
    v = idx
    for _ in range(N):
        d = v % 3
        v //= 3
        b.append(1 if d == 1 else (-1 if d == 2 else 0))
    return tuple(b)

def neighbors(p):
    r, c = divmod(p, W)
    out = []
    if r > 0: out.append(p - W)
    if r + 1 < H: out.append(p + W)
    if c > 0: out.append(p - 1)
    if c + 1 < W: out.append(p + 1)
    return out

def chain_captured(pos, seed):
    colour = 1 if pos[seed] > 0 else -1
    seen = {seed}
    stack = [seed]
    has_lib = False
    while stack:
        q = stack.pop()
        for r in neighbors(q):
            if pos[r] == 0:
                has_lib = True
            elif (pos[r] > 0) == (colour > 0) and pos[r] != 0 and r not in seen:
                seen.add(r)
                stack.append(r)
    return not has_lib

def pos_from_move(pos, colour, cell):
    if pos[cell] != 0: return None
    nxt = list(pos)
    nxt[cell] = colour
    for q in neighbors(cell):
        if nxt[q] * colour < 0 and chain_captured(tuple(nxt), q):
            # remove the chain
            seen = {q}
            stack = [q]
            while stack:
                x = stack.pop()
                for r in neighbors(x):
                    if nxt[r] == nxt[q] and r not in seen:
                        seen.add(r); stack.append(r)
            for c in seen: nxt[c] = 0
    if chain_captured(tuple(nxt), cell):
        return None
    return tuple(nxt)

def is_legal(pos):
    seen = set()
    for p in range(N):
        if pos[p] == 0 or p in seen: continue
        colour = pos[p]
        stack = [p]; seen.add(p)
        has_lib = False
        while stack:
            q = stack.pop()
            for r in neighbors(q):
                if pos[r] == 0: has_lib = True
                elif pos[r] == colour and r not in seen:
                    seen.add(r); stack.append(r)
        if not has_lib: return False
    return True

def area_score(board):
    black = white = 0
    seen = set()
    for p in range(N):
        if board[p] > 0: black += 1; continue
        if board[p] < 0: white += 1; continue
        if p in seen: continue
        stack = [p]; seen.add(p)
        size = 0; tb = tw = False
        while stack:
            q = stack.pop(); size += 1
            for r in neighbors(q):
                if board[r] > 0: tb = True
                elif board[r] < 0: tw = True
                elif r not in seen: seen.add(r); stack.append(r)
        if tb and not tw: black += size
        if tw and not tb: white += size
    return black - white

# state = (board_rank, side, ko, passes); side 0=Black 1=White; ko in 0..5, none=6
def apply_place(state, colour, cell):
    brank, side, ko, passes = state
    board = unrank(brank)
    if board[cell] != 0: return None
    if ko != N and cell == ko: return None
    nb = pos_from_move(board, colour, cell)
    if nb is None: return None
    opp_before = sum(1 for c in board if c == -colour)
    opp_after = sum(1 for c in nb if c == -colour)
    captured = [i for i in range(N) if board[i] == -colour and nb[i] == 0]
    new_ko = N
    if opp_before - opp_after == 1 and captured:
        libs = sum(1 for q in neighbors(cell) if nb[q] == 0)
        friendly = sum(1 for q in neighbors(cell) if nb[q] == colour)
        if libs == 1 and friendly == 0:
            new_ko = captured[0]
    return (rank(nb), 1 if colour == 1 else 0, new_ko, 0)

def apply_pass(state):
    brank, side, ko, passes = state
    if passes >= 2: return None
    return (brank, 1 - side, N, passes + 1)

def moves(state):
    if state[3] == 2: return []
    board = unrank(state[0])
    colour = 1 if state[1] == 0 else -1
    out = []
    np_ = apply_pass(state)
    if np_: out.append(np_)
    for cell in range(N):
        ns = apply_place(state, colour, cell)
        if ns: out.append(ns)
    return out

def linear(state):
    brank, side, ko, passes = state
    return ((passes * 2 + side) * (N + 1) + ko) * 729 + brank

def unlinear(lin):
    passes = lin // (2 * (N + 1) * 729)
    rest = lin % (2 * (N + 1) * 729)
    side = rest // ((N + 1) * 729)
    rest2 = rest % ((N + 1) * 729)
    ko = rest2 // 729
    brank = rest2 % 729
    return (brank, side, ko, passes)

# ---- truncated evaluators (path + arrival revisit => TIE) ----

class Count:
    def __init__(self): self.n = 0

def minimax(state, arrival_set, path_set, budget, cnt):
    cnt.n += 1
    if cnt.n > budget: raise TimeoutError
    if linear(state) in arrival_set: return TIE
    if linear(state) in path_set: return TIE
    if state[3] == 2: return area_score(unrank(state[0]))
    succs = [s for s in moves(state) if is_legal(unrank(s[0]))]
    if not succs: return area_score(unrank(state[0]))
    path_set = path_set | {linear(state)}
    if state[1] == 0:
        return max(minimax(s, arrival_set, path_set, budget, cnt) for s in succs)
    else:
        return min(minimax(s, arrival_set, path_set, budget, cnt) for s in succs)

def alphabeta(state, arrival_set, path_set, alpha, beta, budget, cnt):
    cnt.n += 1
    if cnt.n > budget: raise TimeoutError
    if linear(state) in arrival_set: return TIE
    if linear(state) in path_set: return TIE
    if state[3] == 2: return area_score(unrank(state[0]))
    succs = [s for s in moves(state) if is_legal(unrank(s[0]))]
    if not succs: return area_score(unrank(state[0]))
    path_set = path_set | {linear(state)}
    if state[1] == 0:
        best = -127
        for s in succs:
            v = alphabeta(s, arrival_set, path_set, alpha, beta, budget, cnt)
            best = max(best, v); alpha = max(alpha, best)
            if alpha >= beta: break
        return best
    else:
        best = 127
        for s in succs:
            v = alphabeta(s, arrival_set, path_set, alpha, beta, budget, cnt)
            best = min(best, v); beta = min(beta, best)
            if alpha >= beta: break
        return best

def replay(moves_str):
    state = (0, 0, N, 0)
    states = [state]
    toks = moves_str.split()
    for t in toks:
        if t == 'pass':
            ns = apply_pass(state)
        else:
            colour = 1 if t[0] == 'B' else -1
            ns = apply_place(state, colour, int(t[1:]))
        assert ns is not None, f"illegal move {t} from {state} board {unrank(state[0])}"
        state = ns
        states.append(state)
    return states

def fmt(state):
    b = unrank(state[0])
    sym = {1: 'B', -1: 'W', 0: '.'}
    return '[' + ' '.join(sym[c] for c in b) + f'] side={"B" if state[1]==0 else "W"} ko={state[2]} passes={state[3]}'

if __name__ == '__main__':
    import sys
    target = (178, 0, 6, 0)
    arrivals = {
        'bfs': 'B0 W1 B2 W4',
        'dfs1': 'B2 W3 B1 W4 B5 pass B0 pass B3 W4 pass W5 B0 W3 pass W1 pass W2 B0 W1 B2 W4',
        'dfs2': 'B3 W1 pass W5 pass W4 pass W0 pass W3 B2 W3 B5 pass B0 W4 B1 pass B3 W4 B0 pass B2 W1',
        'dfs3': 'pass W3 B0 W1 pass W0 B5 W2 B4 W2 pass W0 pass W1 B3 W1 B0 pass B2 W1 B0 pass B2 W4',
        'dfs4': 'B3 W1 pass W4 pass W2 pass W0 pass W3 B5 W2 B1 W4 B0 pass B2 pass B3 W4 B0 pass B2 W1',
    }
    budget = int(sys.argv[1]) if len(sys.argv) > 1 else 3_000_000
    print(f"# target {target} = {fmt(target)}  area={area_score(unrank(178))}  budget={budget}")
    for name, ms in arrivals.items():
        states = replay(ms)
        assert states[-1] == target, f"{name} does not arrive at target: {fmt(states[-1])}"
        arrival_set = {linear(s) for s in states[:-1]}  # exclusive of sigma
        for eng, fn in (('minimax', None), ('alphabeta', None)):
            cnt = Count()
            try:
                if eng == 'minimax':
                    v = minimax(target, arrival_set, frozenset(), budget, cnt)
                else:
                    v = alphabeta(target, arrival_set, frozenset(), -127, 127, budget, cnt)
                print(f"{name}: {eng} value={v} nodes={cnt.n}")
            except TimeoutError:
                print(f"{name}: {eng} EXHAUSTED (>{budget} nodes)")
