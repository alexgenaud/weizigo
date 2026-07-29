"""AUDIT SCAFFOLDING: recompute the census under the *textbook* simple-ko
condition (capture of exactly one stone AND the capturing stone is a lone
stone with exactly one liberty), to test whether B-VACUITY is robust to the
apply_place deviation from proof-v2 1.1."""
import indep_3x2 as M
from collections import deque

def apply_place_fixed(board_rank, side, ko, passes, cell):
    board = M.unrank(board_rank)
    colour = 1 if side == 0 else -1
    if board[cell] != 0: return None
    if ko != M.KO_NONE and cell == ko: return None
    nxt = M.pos_from_move(board, colour, cell)
    if nxt is None: return None
    opp_before = sum(1 for i in range(M.N) if board[i] == -colour)
    opp_after  = sum(1 for i in range(M.N) if nxt[i] == -colour)
    captured = [i for i in range(M.N) if board[i] == -colour and nxt[i] == 0]
    new_ko = M.KO_NONE
    if opp_before - opp_after == 1 and captured:
        cells, _ = M.chain(nxt, cell)                       # the placed stone's CHAIN
        libs = set(q for c in cells for q in M.NBR[c] if nxt[q] == 0)
        if len(cells) == 1 and len(libs) == 1:              # lone stone, one liberty
            new_ko = captured[-1]
    return (M.rank(nxt), 1 if colour == 1 else 0, new_ko, 0), nxt

M.apply_place = apply_place_fixed          # swap in the corrected rule

for label, roots in (("42-seed", M.ROOTS_42), ("true game root", M.ROOTS_1)):
    seen = M.reach_from(roots)
    verts, vid, adj, E = M.build(seen)
    comp, nc = M.sccs(adj)
    sz = {}
    for c in comp: sz[c] = sz.get(c, 0) + 1
    big = max(sz.values())
    on_cycle = set(v for v in range(len(verts)) if sz[comp[v]] >= 2)
    radj = [[] for _ in range(len(verts))]
    for v in range(len(verts)):
        for w in adj[v]: radj[w].append(v)
    vis = set(on_cycle); dq = deque(on_cycle)
    while dq:
        v = dq.popleft()
        for u in radj[v]:
            if u not in vis: vis.add(u); dq.append(u)
    kr = sum(1 for l in verts if M.delinear(l)[2] != M.KO_NONE)
    print(f"{label}: V={len(verts)} E={E} ko-real={kr} SCCs={nc} nontrivial={sum(1 for s in sz.values() if s>=2)} maxSCC={big} cycle-involved={len(on_cycle)} cycle-reachable={len(vis)}")
    if label == "42-seed":
        with open("graph_fixed.txt", "w") as f:
            f.write(f"{len(verts)} {sum(len(a) for a in adj)}\n")
            for v in range(len(verts)):
                f.write(f"{v} {len(adj[v])} " + " ".join(map(str, adj[v])) + "\n")
            f.write("COMP\n"); f.write(" ".join(map(str, comp)) + "\n")
