#!/usr/bin/env python3
"""Independent 3x2 legal-move graph check for 2B-2-AUDIT.

Re-implements the (board, side, ko, passes) state graph from first
principles, using the same basic-ko formalization (i) described in
src/qa023_probe.zig (no engine imports).  Runs Tarjan's SCC on the graph
and checks the headline census numbers.

State linear id uses the same packing as the Zig code:
    id = (((passes * 2 + side) * KO_DIMS + ko) * BOARD_STATES + board)
where board is the base-3 index of the 6-cell colouring.
"""

from collections import deque
import sys

W, H = 3, 2
N = W * H
BOARD_STATES = 3 ** N
KO_DIMS = N + 1
NONE = N  # ko sentinel
TOTAL = BOARD_STATES * 2 * KO_DIMS * 3

def neighbors(cell):
    r, c = divmod(cell, W)
    out = []
    if r > 0: out.append(cell - W)
    if r + 1 < H: out.append(cell + W)
    if c > 0: out.append(cell - 1)
    if c + 1 < W: out.append(cell + 1)
    return out

NEI = [neighbors(i) for i in range(N)]

def decode_board(idx):
    board = [0] * N
    for i in range(N):
        d = idx % 3
        idx //= 3
        board[i] = (0, 1, -1)[d]
    return board

def encode_board(board):
    idx = 0
    mult = 1
    for v in board:
        idx += ((0, 1, 2)[1 if v > 0 else 2 if v < 0 else 0]) * mult
        mult *= 3
    return idx

def chain_captured(board, seed):
    colour = board[seed]
    if colour == 0:
        return False, []
    stack = [seed]
    seen = {seed}
    chain = [seed]
    has_lib = False
    while stack:
        q = stack.pop()
        for r in NEI[q]:
            if board[r] == 0:
                has_lib = True
            elif board[r] == colour and r not in seen:
                seen.add(r)
                stack.append(r)
                chain.append(r)
    return not has_lib, chain

def pos_from_move(board, colour, cell):
    if board[cell] != 0:
        return None
    nxt = list(board)
    nxt[cell] = colour
    opp = -colour
    captured_one = None
    for q in NEI[cell]:
        if nxt[q] == opp:
            cap, chain = chain_captured(nxt, q)
            if cap:
                for c in chain:
                    if nxt[c] == opp:
                        if captured_one is None:
                            captured_one = c
                        else:
                            captured_one = -1  # >1 stone captured
                        nxt[c] = 0
    cap, _ = chain_captured(nxt, cell)
    if cap:
        return None
    new_ko = None
    if captured_one is not None and captured_one != -1:
        # exactly one opponent stone removed; is the placed stone's only liberty that cell?
        libs = sum(1 for q in NEI[cell] if nxt[q] == 0)
        if libs == 1:
            new_ko = captured_one
    return nxt, new_ko

def is_legal(board):
    seen = [False] * N
    for p in range(N):
        if board[p] == 0 or seen[p]:
            continue
        colour = board[p]
        stack = [p]
        seen[p] = True
        has_lib = False
        while stack:
            q = stack.pop()
            for r in NEI[q]:
                if board[r] == 0:
                    has_lib = True
                elif board[r] == colour and not seen[r]:
                    seen[r] = True
                    stack.append(r)
        if not has_lib:
            return False
    return True

def apply_place(state, cell):
    board = decode_board(state[0])
    side = state[1]
    colour = 1 if side == 0 else -1
    ko = state[2]
    if ko != NONE and cell == ko:
        return None
    pm = pos_from_move(board, colour, cell)
    if pm is None:
        return None
    nxt, new_ko = pm
    if new_ko is None:
        new_ko = NONE
    return (encode_board(nxt), 1 - side, new_ko, 0)

def apply_pass(state):
    if state[3] >= 2:
        return None
    return (state[0], 1 - state[1], NONE, state[3] + 1)

def pack(state):
    board, side, ko, passes = state
    return (((passes * 2 + side) * KO_DIMS + ko) * BOARD_STATES + board)

def unpack(sid):
    board = sid % BOARD_STATES
    sid //= BOARD_STATES
    ko = sid % KO_DIMS
    sid //= KO_DIMS
    side = sid % 2
    passes = sid // 2
    return (board, side, ko, passes)

def legal_moves(state):
    if state[3] == 2:
        return []
    out = []
    p = apply_pass(state)
    if p is not None:
        out.append(p)
    for cell in range(N):
        q = apply_place(state, cell)
        if q is not None:
            out.append(q)
    return out

def build_graph():
    visited = bytearray(TOTAL)
    q = deque()
    # seed the same roots as the Zig code: empty goban, both sides, all ko, passes 0..2
    roots = []
    for side in (0, 1):
        for passes in (0, 1, 2):
            for ko in range(KO_DIMS):
                s = (0, side, ko, passes)
                sid = pack(s)
                if not visited[sid]:
                    visited[sid] = 1
                    q.append(s)
                    roots.append(sid)
    adj = {}
    rev = {}
    while q:
        s = q.popleft()
        sid = pack(s)
        adj.setdefault(sid, [])
        for ns in legal_moves(s):
            nid = pack(ns)
            if not is_legal(decode_board(ns[0])):
                continue
            adj[sid].append(nid)
            rev.setdefault(nid, []).append(sid)
            if not visited[nid]:
                visited[nid] = 1
                q.append(ns)
    # ensure every visited vertex has an adjacency entry
    for sid in range(TOTAL):
        if visited[sid]:
            adj.setdefault(sid, [])
            rev.setdefault(sid, [])
    return visited, adj, rev

def tarjan(adj, V):
    index = 0
    indices = {}
    lowlink = {}
    on_stack = set()
    stack = []
    sccs = []
    sys.setrecursionlimit(10000)

    def strongconnect(v):
        nonlocal index
        indices[v] = index
        lowlink[v] = index
        index += 1
        stack.append(v)
        on_stack.add(v)
        for w in adj[v]:
            if w not in indices:
                strongconnect(w)
                lowlink[v] = min(lowlink[v], lowlink[w])
            elif w in on_stack:
                lowlink[v] = min(lowlink[v], indices[w])
        if lowlink[v] == indices[v]:
            scc = []
            while True:
                w = stack.pop()
                on_stack.remove(w)
                scc.append(w)
                if w == v:
                    break
            sccs.append(scc)

    for v in V:
        if v not in indices:
            strongconnect(v)
    return sccs

def cycle_reachable_count(adj, rev, cycle_inv):
    seen = set(cycle_inv)
    q = deque(cycle_inv)
    while q:
        v = q.popleft()
        for u in rev.get(v, ()):
            if u not in seen:
                seen.add(u)
                q.append(u)
    return len(seen)

def main():
    print("Building 3x2 legal-move graph...")
    visited, adj, rev = build_graph()
    V = sum(visited)
    E = sum(len(adj[sid]) for sid in range(TOTAL) if visited[sid])
    Vlist = [sid for sid in range(TOTAL) if visited[sid]]
    dense = {sid: i for i, sid in enumerate(sorted(Vlist))}

    # counts
    per_ko = [0] * KO_DIMS
    per_side = [0, 0]
    terminals = 0
    legal_boards = set()
    for sid in Vlist:
        s = unpack(sid)
        per_ko[s[2]] += 1
        per_side[s[1]] += 1
        if s[3] == 2:
            terminals += 1
        if is_legal(decode_board(s[0])):
            legal_boards.add(s[0])

    print(f"Reachable V = {V}")
    print(f"Directed edges E = {E}")
    print(f"Distinct legal boards = {len(legal_boards)}")
    print(f"Terminals (passes==2) = {terminals}")
    print(f"By side: B={per_side[0]} W={per_side[1]}")
    print(f"By ko: none={per_ko[N]} real={V - per_ko[N]}")

    sccs = tarjan(adj, sorted(Vlist))
    nontriv = [s for s in sccs if len(s) >= 2]
    max_size = max((len(s) for s in nontriv), default=0)
    print(f"SCCs total = {len(sccs)}")
    print(f"Non-trivial SCCs = {len(nontriv)}")
    print(f"Largest SCC size = {max_size}")

    if len(nontriv) == 1:
        scc = set(nontriv[0])
        print(f"Cycle-involved vertices = {len(scc)} (entire SCC)")
        cr = cycle_reachable_count(adj, rev, scc)
        print(f"Cycle-reachable vertices = {cr}")

    # Verify a few of the sample cycles from the official stdout.
    sample_cycles = {
        6: [79, 563, 172, 660, 443, 546],
        8: [3, 687, 209, 700, 223, 1564, 160, 649],
        14: [1, 1484, 144, 592, 1025, 593, 1026, 618, 1051, 789, 51, 528, 961, 590],
    }
    sorted_ids = sorted(Vlist)
    for length, cyc in sample_cycles.items():
        ok = True
        for i, did in enumerate(cyc):
            sid = sorted_ids[did]
            nxt_sid = sorted_ids[cyc[(i + 1) % len(cyc)]]
            if nxt_sid not in adj[sid]:
                ok = False
                print(f"Sample cycle length {length}: edge {did}->{cyc[(i+1)%len(cyc)]} missing")
                break
        print(f"Sample cycle length {length}: {'VALID' if ok else 'INVALID'}")

if __name__ == "__main__":
    main()
