#!/usr/bin/env python3
"""
AUDIT SCAFFOLDING (2B-2-AUDIT, Opus 5) -- independent re-implementation of the
3x2 basic-ko state graph, transcribed from the *semantics* documented in
src/qa023_probe.zig (apply_place / apply_pass / moves / seed_roots), not from
its graph code.  Computes: reachable V, directed E, SCCs, cycle-involved,
cycle-reachable.  Writes an edge list for the C cycle enumerator.

Committed by 2B-FIX-KO as the corroborating second implementation:
`corrected.py` swaps in the lone-stone ko condition and its 42-seed line
must match the Zig `cycle-census-3x2` output digit for digit.
"""
import sys
from collections import deque

W, H = 3, 2
N = W * H              # 6
KO_NONE = N            # 6 == "no ko" sentinel in the ko dimension
KO_DIMS = N + 1        # 7
RAW = 3 ** N           # 729
TOTAL = RAW * 2 * KO_DIMS * 3   # 30618

# ---- goban (de)ranking: digit i (base 3, little-endian) 0=empty 1=black 2=white
def unrank(idx):
    b = []
    v = idx
    for _ in range(N):
        d = v % 3
        v //= 3
        b.append(0 if d == 0 else (1 if d == 1 else -1))
    return tuple(b)

def rank(b):
    idx = 0
    m = 1
    for i in range(N):
        d = 1 if b[i] > 0 else (2 if b[i] < 0 else 0)
        idx += d * m
        m *= 3
    return idx

NBR = []
for p in range(N):
    r, c = divmod(p, W)
    ns = []
    if r > 0:      ns.append(p - W)
    if r + 1 < H:  ns.append(p + W)
    if c > 0:      ns.append(p - 1)
    if c + 1 < W:  ns.append(p + 1)
    NBR.append(tuple(ns))

def chain(pos, seed):
    """(chain_cells, captured?) for the same-colour chain containing seed."""
    colour = 1 if pos[seed] > 0 else -1
    seen = {seed}
    stack = [seed]
    cells = [seed]
    lib = False
    while stack:
        q = stack.pop()
        for r in NBR[q]:
            if pos[r] == 0:
                lib = True
            elif (pos[r] > 0) == (colour > 0) and pos[r] != 0 and r not in seen:
                seen.add(r)
                stack.append(r)
                cells.append(r)
    return cells, (not lib)

def pos_from_move(pos, colour, cell):
    """None on Occupied/Suicide."""
    if pos[cell] != 0:
        return None
    nxt = list(pos)
    nxt[cell] = colour
    for q in NBR[cell]:
        if nxt[q] * colour < 0:
            cells, cap = chain(nxt, q)
            if cap:
                for c in cells:
                    nxt[c] = 0
    _, cap = chain(nxt, cell)
    if cap:
        return None            # suicide
    return tuple(nxt)

def is_legal(pos):
    seen = set()
    for p in range(N):
        if pos[p] == 0 or p in seen:
            continue
        cells, cap = chain(pos, p)
        seen.update(cells)
        if cap:
            return False
    return True

# ---- state tuple: (board_rank, side, ko, passes); side 0 = Black to move
def linear(board, side, ko, passes):
    return ((passes * 2 + side) * KO_DIMS + ko) * RAW + board

def delinear(lin):
    board = lin % RAW
    rest = lin // RAW
    ko = rest % KO_DIMS
    rest //= KO_DIMS
    side = rest % 2
    passes = rest // 2
    return board, side, ko, passes

def apply_place(board_rank, side, ko, passes, cell):
    board = unrank(board_rank)
    colour = 1 if side == 0 else -1
    if board[cell] != 0:
        return None
    if ko != KO_NONE and cell == ko:
        return None
    nxt = pos_from_move(board, colour, cell)
    if nxt is None:
        return None
    opp_before = sum(1 for i in range(N) if board[i] == -colour)
    opp_after = sum(1 for i in range(N) if nxt[i] == -colour)
    captured_cell = None
    for i in range(N):
        if board[i] == -colour and nxt[i] == 0:
            captured_cell = i          # last match, as in the Zig
    new_ko = KO_NONE
    if opp_before - opp_after == 1 and captured_cell is not None:
        libs = sum(1 for q in NBR[cell] if nxt[q] == 0)
        if libs == 1:
            new_ko = captured_cell
    new_side = 1 if colour == 1 else 0
    return (rank(nxt), new_side, new_ko, 0), nxt

def apply_pass(board_rank, side, ko, passes):
    if passes >= 2:
        return None
    return (board_rank, 1 - side, KO_NONE, passes + 1), unrank(board_rank)

def successors(lin):
    board_rank, side, ko, passes = delinear(lin)
    if passes == 2:
        return []
    out = []
    p = apply_pass(board_rank, side, ko, passes)
    if p:
        out.append(p)
    for cell in range(N):
        r = apply_place(board_rank, side, ko, passes, cell)
        if r:
            out.append(r)
    return out

# ---- reachability fixpoint ------------------------------------------------
def reach_from(roots, legality_filter=True):
    seen = set(roots)
    dq = deque(roots)
    while dq:
        lin = dq.popleft()
        for (st, nb) in successors(lin):
            if legality_filter and not is_legal(nb):
                continue
            cl = linear(*st)
            if cl not in seen:
                seen.add(cl)
                dq.append(cl)
    return seen

# the 42 seeds actually used by seed_roots()/run_census_3x2()
ROOTS_42 = [linear(0, s, k, p) for s in (0, 1) for p in (0, 1, 2) for k in range(KO_DIMS)]
# the semantically coherent subset: empty goban can never carry a ko point
ROOTS_6 = [linear(0, s, KO_NONE, p) for s in (0, 1) for p in (0, 1, 2)]
# the single true game root
ROOTS_1 = [linear(0, 0, KO_NONE, 0)]

def build(seen):
    verts = sorted(seen)
    vid = {l: i for i, l in enumerate(verts)}
    adj = [[] for _ in verts]
    E = 0
    for l in verts:
        for (st, nb) in successors(l):
            cl = linear(*st)
            if cl in vid:
                adj[vid[l]].append(vid[cl])
                E += 1
    return verts, vid, adj, E

# ---- Tarjan SCC (iterative, independent transcription) --------------------
def sccs(adj):
    V = len(adj)
    index = [-1] * V
    low = [0] * V
    onstk = [False] * V
    comp = [-1] * V
    stk = []
    ncomp = 0
    counter = 0
    for root in range(V):
        if index[root] != -1:
            continue
        work = [(root, 0)]
        index[root] = low[root] = counter; counter += 1
        stk.append(root); onstk[root] = True
        while work:
            v, ci = work[-1]
            if ci < len(adj[v]):
                work[-1] = (v, ci + 1)
                w = adj[v][ci]
                if index[w] == -1:
                    index[w] = low[w] = counter; counter += 1
                    stk.append(w); onstk[w] = True
                    work.append((w, 0))
                elif onstk[w]:
                    low[v] = min(low[v], index[w])
            else:
                work.pop()
                if low[v] == index[v]:
                    while True:
                        w = stk.pop(); onstk[w] = False; comp[w] = ncomp
                        if w == v: break
                    ncomp += 1
                if work:
                    u = work[-1][0]
                    low[u] = min(low[u], low[v])
    return comp, ncomp

def report(label, roots):
    seen = reach_from(roots)
    verts, vid, adj, E = build(seen)
    V = len(verts)
    comp, ncomp = sccs(adj)
    sizes = {}
    for c in comp:
        sizes[c] = sizes.get(c, 0) + 1
    nontriv = [c for c, s in sizes.items() if s >= 2]
    maxsz = max(sizes.values())
    # a vertex lies on a cycle iff its SCC is non-trivial, or it has a self-loop
    selfloop = any(v in adj[v] for v in range(V))
    on_cycle = set(v for v in range(V) if sizes[comp[v]] >= 2)
    # cycle-reachable: reverse-BFS from on_cycle
    radj = [[] for _ in range(V)]
    for v in range(V):
        for w in adj[v]:
            radj[w].append(v)
    vis = set(on_cycle)
    dq = deque(on_cycle)
    while dq:
        v = dq.popleft()
        for u in radj[v]:
            if u not in vis:
                vis.add(u); dq.append(u)
    # tallies by dimension
    ko_real = sum(1 for l in verts if delinear(l)[2] != KO_NONE)
    term = sum(1 for l in verts if delinear(l)[3] == 2)
    side_b = sum(1 for l in verts if delinear(l)[1] == 0)
    boards = set(delinear(l)[0] for l in verts)
    legal_boards = set(b for b in boards if is_legal(unrank(b)))
    print(f"=== {label}: seeds={len(roots)}")
    print(f"  V = {V}   E = {E}   self-loop present = {selfloop}")
    print(f"  ko=none {V-ko_real}  ko=real {ko_real}   side B/W {side_b}/{V-side_b}   terminals {term}")
    print(f"  distinct boards {len(boards)} (legal {len(legal_boards)})")
    print(f"  SCC total {ncomp}  non-trivial {len(nontriv)}  max size {maxsz}")
    print(f"  cycle-involved (in a non-trivial SCC) {len(on_cycle)}")
    print(f"  cycle-reachable (reverse closure)     {len(vis)}")
    return verts, vid, adj, comp, sizes, on_cycle

if __name__ == "__main__":
    v42 = report("SEEDS AS IMPLEMENTED (42: empty board x side x passes x ALL ko)", ROOTS_42)
    v6 = report("SEEDS COHERENT (6: empty board x side x passes, ko=none)", ROOTS_6)
    v1 = report("SEEDS TRUE GAME ROOT (1: empty, Black, ko=none, passes=0)", ROOTS_1)

    # dump edge list of the as-implemented graph for the C cycle enumerator
    verts, vid, adj, comp, sizes, on_cycle = v42
    with open(sys.argv[1] if len(sys.argv) > 1 else "graph42.txt", "w") as f:
        f.write(f"{len(verts)} {sum(len(a) for a in adj)}\n")
        for v in range(len(verts)):
            f.write(f"{v} {len(adj[v])} " + " ".join(map(str, adj[v])) + "\n")
        f.write("COMP\n")
        f.write(" ".join(map(str, comp)) + "\n")
    print("edge list written")
