# Length-bounded directed simple-cycle count on the 3x2 SCC.
# Loads the graph from independent_graph_check.py's functions.
import sys
sys.path.insert(0, '/Users/alex/Project/Zig/weizigo/docs/evidence/AUDIT-2B-2')
from independent_graph_check import build_graph, tarjan

MAX_LEN = int(sys.argv[1]) if len(sys.argv) > 1 else 14

visited, adj, rev = build_graph()
Vlist = [sid for sid in range(len(visited)) if visited[sid]]
sorted_ids = sorted(Vlist)
dense = {sid: i for i, sid in enumerate(sorted_ids)}

sccs = tarjan(adj, sorted_ids)
nontriv = [scc for scc in sccs if len(scc) >= 2]
scc = set(nontriv[0])
# local ids 0..1695 preserving linear order
local_sorted = sorted(scc)
local_index = {sid: i for i, sid in enumerate(local_sorted)}
sub_adj = [[] for _ in range(len(local_sorted))]
for sid in local_sorted:
    u = local_index[sid]
    for nid in adj[sid]:
        if nid in local_index:
            sub_adj[u].append(local_index[nid])

def count_bounded(max_len):
    total = 0
    hist = [0]*(max_len+1)
    N = len(local_sorted)
    on_path = [False]*N
    for start in range(N):
        on_path[start] = True
        path = [start]
        # iterative stack of (v, next_child_index)
        stack = [(start, 0)]
        while stack:
            v, ni = stack[-1]
            if ni < len(sub_adj[v]):
                stack[-1] = (v, ni+1)
                w = sub_adj[v][ni]
                if w < start:
                    continue
                if w == start:
                    if len(path) >= 2 and len(path) <= max_len:
                        total += 1
                        hist[len(path)] += 1
                    continue
                if on_path[w]:
                    continue
                if len(path) < max_len:
                    on_path[w] = True
                    path.append(w)
                    stack.append((w, 0))
            else:
                stack.pop()
                on_path[v] = False
                if path:
                    path.pop()
        on_path[start] = False
    return total, hist

total, hist = count_bounded(MAX_LEN)
print(f"MAX_LEN={MAX_LEN}")
print(f"total bounded simple cycles = {total}")
for l, c in enumerate(hist):
    if c:
        print(f"  length {l}: {c}")
