////////////////////////////////////////////
//                                        //
//    (c) 2026 Alexander E Genaud          //
//                                        //
//    Permission is granted hereby,       //
//    to copy, share, use, modify,        //
//        for purposes any,               //
//    for free or for money,              //
//    provided these notices multiply.    //
//                                        //
//    This work "as is" I provide,        //
//    no warranty express or implied,     //
//        for, no purpose fit,             //
//    'tis unmerchantable shit.            //
//    Liability for damages denied.       //
//                                        //
////////////////////////////////////////////
//
// T416_CYCLE — does the OPTIMAL-MOVE SUBGRAPH contain a cycle?
//
// Task: T416 · Role: worker · Model: glm-5.2 · Date: 2026-08-08
//
// The operator's central open question (the last unanswered piece of the
// loop thread).  T412 measured the *per-position* form (is every optimal
// child loopy?) and found ~87 % of forced-loop positions have exactly one
// optimal child and it is loopy.  But a loop needs BOTH players to keep
// choosing it.  Only a cycle in the optimal-move subgraph — where every
// state keeps only its optimal children (argmax for Black, argmin for
// White, ALL ties kept) — proves the loop is sustainable under optimal
// play by both sides.
//
// What this instrument does:
//   1. Build the optimal-move subgraph.  Every non-terminal table state
//      keeps an edge to each child whose pinned value equals the Bellman
//      best over ALL children (placements + pass).  Ties are ALL kept —
//      selecting one representative would fabricate acyclicity.
//   2. Detect cycles via iterative Tarjan SCC.  An SCC of size > 1, or a
//      size-1 SCC with a self-loop, is cycle-bearing.
//   3. Per cycle node, classify the mover:
//        - strictly-prefers-to-stay: every optimal child stays in the
//          same cyclic SCC (no equally-optimal exit).  The player will
//          not deviate.
//        - indifferent: an equally-optimal exit exists (an optimal child
//          that is a leaf/terminal, or lies outside the SCC).  The loop
//          is possible but not forced.
//      A cycle whose every node is strictly-preferring is a genuinely
//      forced loop under optimal play.
//   4. Verify value constancy around each cyclic SCC (an optimal cycle
//      cannot change the value; a mismatch means the subgraph or the
//      table is wrong — reported and stopped).
//
// Modes:
//   --mode exhaustive  (3x3 default): build the FULL optimal subgraph over
//     every non-terminal entry; cycle detection is exact for that goban.
//   --mode bfs         (4x4 default): reservoir-sample S seed non-terminal
//     states (declared seed), then BFS forward along optimal edges to a
//     node budget B, building the induced subgraph.  A cycle found is a
//     REAL cycle (honest positive); a negative covers only the sampled
//     reachable subgraph and is weaker than exhaustive — stated plainly.
//
// Controls (per AGENTS.md "Tooling gets the same pipeline"):
//   --seedctl null       : normal run (default).
//   --seedctl force_loopy: treat EVERY child as optimal (all-ties-every-
//     thing).  On a goban known to have ANY edge this must report a cycle;
//     a negative there means the detector is wrong.  This is the red-side
//     reading shown before the real run.
//   --null-graph         : build the graph but with NO edges (acyclic by
//     construction).  The detector must report zero cycles.  This is the
//     null control.
//
// Reads ONLY.  Compiles standalone:
//   zig build-exe -O ReleaseFast --dep version -Mroot=src/t416_cycle.zig \
//     -Mversion=src/version.zig --cache-dir /tmp/weizigo/t416/cache \
//     --global-cache-dir /tmp/weizigo/t416/global --name weizigo-t416-cyc \
//     -femit-bin=/tmp/weizigo/t416/t416-cyc
//
// Usage: weizigo-t416-cyc --size 3|4 [--wzo2 <p>] [--mode exhaustive|bfs]
//          [--seeds <N>] [--budget <N>] [--seed <N>] [--json <p>]
//          [--seedctl null|force_loopy] [--null-graph]

const std = @import("std");
const version = @import("version");
const rules = @import("rules.zig");
const artifact2 = @import("artifact2.zig");
const colex = @import("colex.zig");
const util = @import("util.zig");

// ═══════════════════════════════════════════════════════════════════════════
//  HELPERS
// ═══════════════════════════════════════════════════════════════════════════

fn pinnedValue(L: i8, H: i8) i8 {
    return @max(L, @min(0, H));
}

/// Dense key for (colex, side, ko, passes).  ko in 0..KO_NONE (KO_NONE = n),
/// so multiplier n+1 covers it.  passes 0/1, side 0/1.
fn nodeKey(colex_val: u32, side: i8, ko: u8, passes: u8, ko_none: u8) u64 {
    const s: u64 = if (side > 0) 0 else 1;
    const kmod: u64 = @as(u64, ko_none) + 1;
    return (((@as(u64, colex_val) * kmod + @as(u64, ko)) * 2 + @as(u64, passes)) * 2 + s);
}

// ═══════════════════════════════════════════════════════════════════════════
//  GRAPH
// ═══════════════════════════════════════════════════════════════════════════

const Node = struct {
    colex: u32,
    side: i8, // +1 Black, -1 White
    ko: u8,
    passes: u8,
    L: i8,
    H: i8,
    pinned: i8, // pinnedValue(L,H)
    // classification (filled after SCC):
    // n_optimal_total: total optimal children (incl. leaves)
    // n_optimal_leaf:  optimal children that are leaves/terminals (exits)
    n_optimal_total: u16 = 0,
    n_optimal_leaf: u16 = 0,
};

const Graph = struct {
    gpa: std.mem.Allocator,
    nodes: std.ArrayListUnmanaged(Node) = .empty,
    /// edges[i] = node IDs of NON-TERMINAL optimal children of node i.
    edges: std.ArrayListUnmanaged(std.ArrayListUnmanaged(u32)) = .empty,
    /// key -> node id
    key2id: std.AutoHashMap(u64, u32),
    ko_none: u8,

    fn init(gpa: std.mem.Allocator, ko_none: u8) Graph {
        return .{ .gpa = gpa, .key2id = std.AutoHashMap(u64, u32).init(gpa), .ko_none = ko_none };
    }

    fn deinit(g: *Graph) void {
        for (g.edges.items) |*e| e.deinit(g.gpa);
        g.edges.deinit(g.gpa);
        g.nodes.deinit(g.gpa);
        g.key2id.deinit();
    }

    fn keyOf(g: *const Graph, colex_val: u32, side: i8, ko: u8, passes: u8) u64 {
        return nodeKey(colex_val, side, ko, passes, g.ko_none);
    }

    /// Look up an existing node id, or null.
    fn idOf(g: *const Graph, colex_val: u32, side: i8, ko: u8, passes: u8) ?u32 {
        return g.key2id.get(g.keyOf(colex_val, side, ko, passes));
    }

    /// Add a node (no edges yet). Returns its id.
    fn addNode(g: *Graph, colex_val: u32, side: i8, ko: u8, passes: u8, L: i8, H: i8) !u32 {
        const id: u32 = @intCast(g.nodes.items.len);
        try g.nodes.append(g.gpa, .{
            .colex = colex_val,
            .side = side,
            .ko = ko,
            .passes = passes,
            .L = L,
            .H = H,
            .pinned = pinnedValue(L, H),
        });
        try g.edges.append(g.gpa, .empty);
        try g.key2id.put(g.keyOf(colex_val, side, ko, passes), id);
        return id;
    }

    fn addEdge(g: *Graph, from: u32, to: u32) !void {
        try g.edges.items[from].append(g.gpa, to);
    }
};

// ═══════════════════════════════════════════════════════════════════════════
//  ENUMERATE NON-TERMINAL ENTRIES
// ═══════════════════════════════════════════════════════════════════════════

const Entry = struct {
    colex: u32,
    side: i8,
    ko: u8,
    passes: u8,
    L: i8,
    H: i8,
};

fn enumerateNonTerminal(a2: *const artifact2.LoadedArtifact, gpa: std.mem.Allocator) ![]Entry {
    const G: usize = @intCast(a2.header.n_groups);
    const groups = a2.data[a2.group_base .. a2.group_base + G * artifact2.GROUP_HEADER_SIZE];
    var out: std.ArrayListUnmanaged(Entry) = .empty;
    var cum: u64 = 0;
    for (0..G) |g| {
        const colex_val = std.mem.readInt(u32, groups[g * artifact2.GROUP_HEADER_SIZE ..][0..4], .little);
        const count: usize = groups[g * artifact2.GROUP_HEADER_SIZE + 4];
        const entry_off = a2.entry_base + cum * artifact2.ENTRY_SIZE;
        for (0..count) |ei| {
            const eb = a2.data[entry_off + ei * artifact2.ENTRY_SIZE ..][0..artifact2.ENTRY_SIZE];
            const kb = eb[0];
            const decoded = artifact2.decodeKeyByte(kb, a2.header.ko_bits);
            if (decoded.terminal != 0) continue;
            const L: i8 = @bitCast(eb[1]);
            const H: i8 = @bitCast(eb[2]);
            try out.append(gpa, .{
                .colex = colex_val,
                .side = artifact2.u1ToSide(decoded.side),
                .ko = decoded.ko,
                .passes = decoded.passes,
                .L = L,
                .H = H,
            });
        }
        cum += count;
    }
    return out.toOwnedSlice(gpa);
}

// ═══════════════════════════════════════════════════════════════════════════
//  CHILD ENUMERATION + EDGE BUILDING
// ═══════════════════════════════════════════════════════════════════════════
//
// ChildResult: value + (if non-terminal & in-graph) target node id.
// A child with a table entry that is TERMINAL is treated as a leaf (no
// edge) — its value is pinned(L,H) but it has no outgoing moves.

const ChildResult = struct {
    v: i8, // pinned value of the child
    has_entry: bool, // a non-terminal table entry exists
    entry_terminal: bool, // entry exists but is terminal (leaf)
    target_colex: u32,
    target_side: i8,
    target_ko: u8,
    target_passes: u8,
};

const ChildEnum = struct {
    placements: [17]ChildResult = undefined,
    n_placements: usize = 0,
    pass: ChildResult = undefined,
    has_pass: bool = false,
};

fn enumChildren(
    comptime w: comptime_int,
    comptime h: comptime_int,
    a2: *const artifact2.LoadedArtifact,
    colex_val: u32,
    side: i8,
    ko: u8,
    passes: u8,
) ChildEnum {
    const R = rules.Rules(w, h);
    const X = colex.Indexer(w, h);
    const n = w * h;
    const KO_NONE: u8 = n;
    var ce = ChildEnum{};

    const pos = X.pos_from_colex(colex_val);

    for (0..n) |cell| {
        if (pos[cell] != 0) continue;
        if (ko < KO_NONE and cell == ko) continue;
        const child = R.pos_from_move(&pos, side, cell) catch continue;
        const child_ko = rules.koAfterCapture(&pos, &child, side, w, h, KO_NONE);
        const child_colex: u32 = @intCast(X.colex_from_pos(&child));
        if (artifact2.lookup(a2, child_colex, -side, child_ko, 0)) |row| {
            const term = row.terminal;
            ce.placements[ce.n_placements] = .{
                .v = pinnedValue(row.L, row.H),
                .has_entry = true,
                .entry_terminal = term,
                .target_colex = child_colex,
                .target_side = -side,
                .target_ko = child_ko,
                .target_passes = 0,
            };
        } else {
            ce.placements[ce.n_placements] = .{
                .v = R.area_score(&child),
                .has_entry = false,
                .entry_terminal = false,
                .target_colex = child_colex,
                .target_side = -side,
                .target_ko = child_ko,
                .target_passes = 0,
            };
        }
        ce.n_placements += 1;
    }

    // pass child
    if (passes >= 1) {
        // double pass -> terminal, scored
        ce.pass = .{
            .v = R.area_score(&pos),
            .has_entry = false,
            .entry_terminal = false,
            .target_colex = colex_val,
            .target_side = -side,
            .target_ko = KO_NONE,
            .target_passes = 0,
        };
        ce.has_pass = true;
    } else {
        const np: u2 = @intCast(passes + 1);
        if (artifact2.lookup(a2, colex_val, -side, KO_NONE, np)) |row| {
            ce.pass = .{
                .v = pinnedValue(row.L, row.H),
                .has_entry = true,
                .entry_terminal = row.terminal,
                .target_colex = colex_val,
                .target_side = -side,
                .target_ko = KO_NONE,
                .target_passes = np,
            };
        } else {
            ce.pass = .{
                .v = R.area_score(&pos),
                .has_entry = false,
                .entry_terminal = false,
                .target_colex = colex_val,
                .target_side = -side,
                .target_ko = KO_NONE,
                .target_passes = np,
            };
        }
        ce.has_pass = true;
    }

    return ce;
}

/// Compute Bellman best and tautology check.
fn bellmanBest(ce: *const ChildEnum, maximizing: bool) struct { best: i8, any: bool } {
    var best: i8 = if (maximizing) -127 else 127;
    var any = false;
    for (ce.placements[0..ce.n_placements]) |c| {
        any = true;
        if (maximizing) { if (c.v > best) best = c.v; } else { if (c.v < best) best = c.v; }
    }
    if (ce.has_pass) {
        any = true;
        if (maximizing) { if (ce.pass.v > best) best = ce.pass.v; } else { if (ce.pass.v < best) best = ce.pass.v; }
    }
    return .{ .best = best, .any = any };
}

/// Build edges + classification counts for a node already in the graph.
/// force_all_optimal: if true, treat EVERY child as optimal (seeded control).
/// null_graph: if true, add NO edges (null control).
fn wireNode(
    g: *Graph,
    a2: *const artifact2.LoadedArtifact,
    id: u32,
    comptime w: comptime_int,
    comptime h: comptime_int,
    force_all_optimal: bool,
    null_graph: bool,
    keep_one_tie: bool,
) !struct { tautology_ok: bool, n_opt: u16, n_loopy_opt: u16 } {
    const node = g.nodes.items[id];
    const maximizing = node.side > 0;
    const ce = enumChildren(w, h, a2, node.colex, node.side, node.ko, node.passes);
    const bb = bellmanBest(&ce, maximizing);
    // tautology: pinned == Bellman best (table is a fixpoint)
    const taut_ok = (!bb.any) or (node.pinned == bb.best);

    var n_opt: u16 = 0;
    var n_loopy_opt: u16 = 0;
    var n_leaf: u16 = 0;
    var edge_added: bool = false; // for keep_one_tie

    if (null_graph) {
        // record counts for reporting, but no edges (acyclic by construction)
        for (ce.placements[0..ce.n_placements]) |c| {
            const is_opt = force_all_optimal or (bb.any and c.v == bb.best);
            if (!is_opt) continue;
            n_opt += 1;
        }
        if (ce.has_pass) {
            const is_opt = force_all_optimal or (bb.any and ce.pass.v == bb.best);
            if (is_opt) n_opt += 1;
        }
        g.nodes.items[id].n_optimal_total = n_opt;
        g.nodes.items[id].n_optimal_leaf = n_opt; // all are "exits" in null graph
        return .{ .tautology_ok = taut_ok, .n_opt = n_opt, .n_loopy_opt = 0 };
    }

    // placements
    for (ce.placements[0..ce.n_placements]) |c| {
        const is_opt = force_all_optimal or (bb.any and c.v == bb.best);
        if (!is_opt) continue;
        n_opt += 1;
        // loopy = the child has L < H (bracketed value).  The child's L/H
        // come from the table entry; leaves have L==H==area_score.
        if (c.has_entry and !c.entry_terminal) {
            // look up L/H to decide loopy
            if (artifact2.lookup(a2, c.target_colex, c.target_side, c.target_ko, @intCast(c.target_passes))) |row| {
                if (row.L < row.H) n_loopy_opt += 1;
            }
            // edge to the child if it is in the graph
            if (keep_one_tie and edge_added) {
                // tie-handling control: only one optimal edge per node
                n_leaf += 1;
            } else if (g.idOf(c.target_colex, c.target_side, c.target_ko, @intCast(c.target_passes))) |tid| {
                try g.addEdge(id, tid);
                edge_added = true;
            } else {
                // in-graph closure: for exhaustive mode the child must be
                // present (all non-terminal entries are nodes).  If absent
                // it is a leaf/terminal-class exit.  Count as leaf exit.
                n_leaf += 1;
            }
        } else {
            // leaf (no entry, or terminal entry) -> exit
            n_leaf += 1;
        }
    }
    // pass
    if (ce.has_pass) {
        const c = ce.pass;
        const is_opt = force_all_optimal or (bb.any and c.v == bb.best);
        if (is_opt) {
            n_opt += 1;
            if (c.has_entry and !c.entry_terminal) {
                if (artifact2.lookup(a2, c.target_colex, c.target_side, c.target_ko, @intCast(c.target_passes))) |row| {
                    if (row.L < row.H) n_loopy_opt += 1;
                }
                if (keep_one_tie and edge_added) {
                    n_leaf += 1;
                } else if (g.idOf(c.target_colex, c.target_side, c.target_ko, @intCast(c.target_passes))) |tid| {
                    try g.addEdge(id, tid);
                    edge_added = true;
                } else {
                    n_leaf += 1;
                }
            } else {
                n_leaf += 1;
            }
        }
    }

    g.nodes.items[id].n_optimal_total = n_opt;
    g.nodes.items[id].n_optimal_leaf = n_leaf;
    return .{ .tautology_ok = taut_ok, .n_opt = n_opt, .n_loopy_opt = n_loopy_opt };
}

// ═══════════════════════════════════════════════════════════════════════════
//  TARJAN SCC (iterative)
// ═══════════════════════════════════════════════════════════════════════════

const SCC = struct {
    scc_id: []u32, // per node
    scc_size: std.ArrayListUnmanaged(u32), // size by scc id
    has_self_loop: std.ArrayListUnmanaged(bool), // per scc id
    n_scc: u32,

    fn deinit(s: *SCC, gpa: std.mem.Allocator) void {
        gpa.free(s.scc_id);
        s.scc_size.deinit(gpa);
        s.has_self_loop.deinit(gpa);
    }
};

const UNVISITED: u32 = 0xFFFFFFFF;

fn tarjanSCC(g: *const Graph, gpa: std.mem.Allocator) !SCC {
    const n: u32 = @intCast(g.nodes.items.len);
    const index = try gpa.alloc(u32, n);
    @memset(index, UNVISITED);
    const lowlink = try gpa.alloc(u32, n);
    @memset(lowlink, 0);
    const onstack = try gpa.alloc(bool, n);
    @memset(onstack, false);
    defer gpa.free(index);
    defer gpa.free(lowlink);
    defer gpa.free(onstack);

    const scc_id = try gpa.alloc(u32, n);
    @memset(scc_id, UNVISITED);

    var scc_size: std.ArrayListUnmanaged(u32) = .empty;
    var has_self_loop: std.ArrayListUnmanaged(bool) = .empty;
    var n_scc: u32 = 0;

    var stack: std.ArrayListUnmanaged(u32) = .empty;
    defer stack.deinit(gpa);

    // iterative DFS frame: (node, next edge index)
    const Frame = struct { node: u32, ei: u32 };
    var dfs: std.ArrayListUnmanaged(Frame) = .empty;
    defer dfs.deinit(gpa);

    var counter: u32 = 0;

    for (0..n) |start| {
        if (index[start] != UNVISITED) continue;
        try dfs.append(gpa, .{ .node = @intCast(start), .ei = 0 });
        index[start] = counter;
        lowlink[start] = counter;
        counter += 1;
        try stack.append(gpa, @intCast(start));
        onstack[start] = true;

        while (dfs.items.len > 0) {
            const fi = dfs.items.len - 1;
            const f = dfs.items[fi];
            const edges = g.edges.items[f.node];
            if (f.ei < edges.items.len) {
                const w = edges.items[f.ei];
                dfs.items[fi].ei += 1;
                if (index[w] == UNVISITED) {
                    index[w] = counter;
                    lowlink[w] = counter;
                    counter += 1;
                    try stack.append(gpa, w);
                    onstack[w] = true;
                    try dfs.append(gpa, .{ .node = w, .ei = 0 });
                } else if (onstack[w]) {
                    if (index[w] < lowlink[f.node]) lowlink[f.node] = index[w];
                }
            } else {
                // pop frame
                if (lowlink[f.node] == index[f.node]) {
                    // root of an SCC
                    const sid = n_scc;
                    n_scc += 1;
                    try scc_size.append(gpa, 0);
                    try has_self_loop.append(gpa, false);
                    var self_loop = false;
                    while (true) {
                        const v = stack.pop().?;
                        onstack[v] = false;
                        scc_id[v] = sid;
                        scc_size.items[sid] += 1;
                        // self-loop check: any edge v->v
                        const ev = g.edges.items[v];
                        for (ev.items) |e| {
                            if (e == v) { self_loop = true; break; }
                        }
                        if (v == f.node) break;
                    }
                    has_self_loop.items[sid] = self_loop;
                }
                _ = dfs.pop();
                if (dfs.items.len > 0) {
                    const parent = dfs.items[dfs.items.len - 1].node;
                    if (lowlink[f.node] < lowlink[parent]) lowlink[parent] = lowlink[f.node];
                }
            }
        }
    }

    return .{
        .scc_id = scc_id,
        .scc_size = scc_size,
        .has_self_loop = has_self_loop,
        .n_scc = n_scc,
    };
}

/// girth (shortest cycle length) within an SCC, via BFS from each node.
/// Returns 0 if no cycle found (should not happen for a cyclic SCC) or if
/// the SCC is too large (capped).  Only call for cyclic SCCs with size <= cap.
fn sccGirth(g: *const Graph, members: []const u32, gpa: std.mem.Allocator, cap: usize) usize {
    if (members.len > cap) return 0;
    // map member node id -> local index
    var idx = std.AutoHashMap(u32, u32).init(gpa);
    defer idx.deinit();
    for (members, 0..) |m, i| idx.put(m, @intCast(i)) catch return 0;
    const m = members.len;
    const best: usize = if (m <= 1) 0 else m + 1;
    var best_cycle = best;
    // adjacency restricted to SCC members
    var adj: std.ArrayListUnmanaged(std.ArrayListUnmanaged(u32)) = .empty;
    defer {
        for (adj.items) |*a| a.deinit(gpa);
        adj.deinit(gpa);
    }
    adj.appendNTimes(gpa, .empty, m) catch return 0;
    for (members) |node| {
        const i = idx.get(node).?;
        for (g.edges.items[node].items) |e| {
            if (idx.get(e)) |j| {
                adj.items[i].append(gpa, j) catch return 0;
            }
        }
    }
    // BFS from each node; shortest path back to start = cycle length
    var dist = gpa.alloc(u32, m) catch return 0;
    defer gpa.free(dist);
    var q: std.ArrayListUnmanaged(u32) = .empty;
    defer q.deinit(gpa);
    for (0..m) |s| {
        @memset(dist, 0xFFFFFFFF);
        dist[s] = 0;
        q.clearRetainingCapacity();
        q.append(gpa, @intCast(s)) catch return 0;
        var head: usize = 0;
        while (head < q.items.len) {
            const u = q.items[head];
            head += 1;
            const du = dist[u];
            for (adj.items[u].items) |v| {
                if (v == s) {
                    // found a cycle back to start: length du + 1
                    const clen = @as(usize, du) + 1;
                    if (clen < best_cycle) best_cycle = clen;
                    // don't expand s again; continue scanning other edges
                    continue;
                }
                if (dist[v] == 0xFFFFFFFF) {
                    dist[v] = du + 1;
                    // prune: only enqueue if still under current best
                    if (@as(usize, du) + 2 < best_cycle) {
                        q.append(gpa, v) catch return 0;
                    }
                }
            }
        }
    }
    return if (best_cycle <= m) best_cycle else 0;
}

// ═══════════════════════════════════════════════════════════════════════════
//  DRIVER
// ═══════════════════════════════════════════════════════════════════════════

const Result = struct {
    n_nodes: usize,
    n_edges: u64,
    tautology_checks: usize,
    tautology_mismatches: usize,
    n_scc: u32,
    n_cyclic_scc: u32, // size>1 or self-loop
    n_states_on_cycles: u64,
    n_forced_cycles: u32, // cyclic SCC all nodes strictly-preferring
    n_indifferent_cycles: u32, // cyclic SCC with >=1 indifferent node
    n_forced_states: u64,
    n_indifferent_states: u64,
    n_value_const_ok: u32, // cyclic SCCs with constant pinned value
    n_value_const_bad: u32, // cyclic SCCs where value changes (error)
    // SCC size distribution for cyclic SCCs
    min_cycle_size: u32,
    max_cycle_size: u32,
    // girth (shortest cycle) over cyclic SCCs small enough to measure
    min_girth: u32, // 0 = unmeasured
    max_girth: u32,
    n_girth_measured: u32,
    // examples (up to 3)
    examples: [3]?Example = .{ null, null, null },
    n_examples: u32 = 0,
};

const Example = struct {
    scc_size: u32,
    girth: u32, // 0 = unmeasured
    forced: bool,
    value: i8, // pinned value around the cycle (constancy)
    value_const: bool,
    n_strict: u32,
    n_indifferent: u32,
    members: [12]u32, // up to 12 member node ids (for board dump)
    n_members: u32,
};

fn classifyAndReport(
    g: *const Graph,
    scc: *const SCC,
    gpa: std.mem.Allocator,
) !Result {
    var r = Result{
        .n_nodes = g.nodes.items.len,
        .n_edges = 0,
        .n_scc = scc.n_scc,
        .tautology_checks = 0,
        .tautology_mismatches = 0,
        .n_cyclic_scc = 0,
        .n_states_on_cycles = 0,
        .n_forced_cycles = 0,
        .n_indifferent_cycles = 0,
        .n_forced_states = 0,
        .n_indifferent_states = 0,
        .n_value_const_ok = 0,
        .n_value_const_bad = 0,
        .min_cycle_size = 0xFFFFFFFF,
        .max_cycle_size = 0,
        .min_girth = 0xFFFFFFFF,
        .max_girth = 0,
        .n_girth_measured = 0,
    };
    for (g.edges.items) |e| r.n_edges += e.items.len;

    // collect members per scc
    var members: std.ArrayListUnmanaged(std.ArrayListUnmanaged(u32)) = .empty;
    defer {
        for (members.items) |*m| m.deinit(gpa);
        members.deinit(gpa);
    }
    try members.appendNTimes(gpa, .empty, scc.n_scc);
    for (g.nodes.items, 0..) |_, i| {
        try members.items[scc.scc_id[i]].append(gpa, @intCast(i));
    }

    var ex_idx: u32 = 0;

    var sid: u32 = 0;
    while (sid < scc.n_scc) : (sid += 1) {
        const sz = scc.scc_size.items[sid];
        const cyclic = (sz > 1) or scc.has_self_loop.items[sid];
        if (!cyclic) continue;
        r.n_cyclic_scc += 1;
        r.n_states_on_cycles += sz;
        if (sz < r.min_cycle_size) r.min_cycle_size = sz;
        if (sz > r.max_cycle_size) r.max_cycle_size = sz;

        // classify each member: strictly-prefers vs indifferent
        const mem = members.items[sid];
        var n_strict: u32 = 0;
        var n_indiff: u32 = 0;
        var first_value: i8 = 0;
        var have_first = false;
        var value_const = true;
        for (mem.items) |nid| {
            const node = g.nodes.items[nid];
            if (!have_first) { first_value = node.pinned; have_first = true; }
            if (node.pinned != first_value) value_const = false;
            // indifferent iff an optimal child is an exit:
            //   - an optimal leaf child (n_optimal_leaf > 0), OR
            //   - an optimal in-graph child whose SCC != sid
            var has_exit = node.n_optimal_leaf > 0;
            if (!has_exit) {
                for (g.edges.items[nid].items) |e| {
                    if (scc.scc_id[e] != sid) { has_exit = true; break; }
                }
            }
            if (has_exit) n_indiff += 1 else n_strict += 1;
        }
        if (n_indiff == 0) {
            r.n_forced_cycles += 1;
            r.n_forced_states += sz;
        } else {
            r.n_indifferent_cycles += 1;
            r.n_indifferent_states += sz;
        }
        if (value_const) r.n_value_const_ok += 1 else r.n_value_const_bad += 1;

        // girth for small SCCs
        var girth: u32 = 0;
        if (sz <= 64) {
            const gr = sccGirth(g, mem.items, gpa, 64);
            if (gr > 0) {
                girth = @intCast(gr);
                r.n_girth_measured += 1;
                if (girth < r.min_girth) r.min_girth = girth;
                if (girth > r.max_girth) r.max_girth = girth;
            }
        }

        // record up to 3 examples (prefer forced, then smallest)
        if (ex_idx < 3) {
            var ex = Example{
                .scc_size = sz,
                .girth = girth,
                .forced = (n_indiff == 0),
                .value = first_value,
                .value_const = value_const,
                .n_strict = n_strict,
                .n_indifferent = n_indiff,
                .members = undefined,
                .n_members = 0,
            };
            const take = @min(mem.items.len, ex.members.len);
            for (0..take) |i| ex.members[i] = mem.items[i];
            ex.n_members = @intCast(take);
            r.examples[ex_idx] = ex;
            ex_idx += 1;
            r.n_examples = ex_idx;
        }
    }

    if (r.min_cycle_size == 0xFFFFFFFF) r.min_cycle_size = 0;
    if (r.min_girth == 0xFFFFFFFF) r.min_girth = 0;

    return r;
}

fn runSize(
    comptime w: comptime_int,
    comptime h: comptime_int,
    io: std.Io,
    gpa: std.mem.Allocator,
    wzo2_path: []const u8,
    mode: []const u8,
    seeds: usize,
    budget: usize,
    seed: u64,
    json_path: []const u8,
    seedctl_force: bool,
    null_graph: bool,
    keep_one_tie: bool,
) !void {
    var a2 = try artifact2.load(io, std.Io.Dir.cwd(), wzo2_path, gpa);
    defer a2.deinit();

    const n_cells = w * h;
    const KO_NONE: u8 = n_cells;
    var g = Graph.init(gpa, KO_NONE);
    defer g.deinit();

    // ── Build node set ───────────────────────────────────────────────────
    const all_entries = try enumerateNonTerminal(&a2, gpa);
    defer gpa.free(all_entries);

    var tautology_checks: usize = 0;
    var tautology_mismatches: usize = 0;

    if (std.mem.eql(u8, mode, "exhaustive")) {
        util.note("[T416] {d}x{d} exhaustive: {d} non-terminal entries\n", .{ w, h, all_entries.len });
        for (all_entries) |e| {
            _ = try g.addNode(e.colex, e.side, e.ko, e.passes, e.L, e.H);
        }
        // wire edges
        var id: u32 = 0;
        while (id < g.nodes.items.len) : (id += 1) {
            const wr = try wireNode(&g, &a2, id, w, h, seedctl_force, null_graph, keep_one_tie);
            tautology_checks += 1;
            if (!wr.tautology_ok) tautology_mismatches += 1;
        }
    } else {
        // bfs mode: reservoir-sample seeds, then BFS forward along optimal
        // edges to a node budget.
        const s = @min(seeds, all_entries.len);
        const seed_entries = try gpa.alloc(Entry, s);
        defer gpa.free(seed_entries);
        if (s == all_entries.len) {
            @memcpy(seed_entries, all_entries);
        } else {
            for (0..s) |i| seed_entries[i] = all_entries[i];
            var t: usize = s;
            var prng = std.Random.DefaultPrng.init(seed);
            const rng = prng.random();
            for (s..all_entries.len) |i| {
                t += 1;
                const k = rng.uintLessThan(usize, t);
                if (k < s) seed_entries[k] = all_entries[i];
            }
        }
        util.note("[T416] {d}x{d} bfs: {d} seeds (of {d} non-terminal), budget {d}, seed={d}\n", .{ w, h, s, all_entries.len, budget, seed });

        // BFS queue of node ids that need wiring
        var queue: std.ArrayListUnmanaged(u32) = .empty;
        defer queue.deinit(gpa);
        // add seed nodes
        for (seed_entries) |e| {
            if (g.idOf(e.colex, e.side, e.ko, e.passes) == null) {
                const id = try g.addNode(e.colex, e.side, e.ko, e.passes, e.L, e.H);
                try queue.append(gpa, id);
            }
        }
        var head: usize = 0;
        while (head < queue.items.len and g.nodes.items.len <= budget) {
            const id = queue.items[head];
            head += 1;
            const wr = try wireNode(&g, &a2, id, w, h, seedctl_force, null_graph, keep_one_tie);
            tautology_checks += 1;
            if (!wr.tautology_ok) tautology_mismatches += 1;
            // enqueue optimal non-terminal children not yet in graph
            // Materialize optimal non-terminal children that are not yet
            // nodes (closure under optimal edges).  wireNode only added
            // edges to children already in the graph; children with a table
            // entry but not yet a node must be added here.
            const node = g.nodes.items[id];
            const ce = enumChildren(w, h, &a2, node.colex, node.side, node.ko, node.passes);
            const maximizing = node.side > 0;
            const bb = bellmanBest(&ce, maximizing);
            const children = ce.placements[0..ce.n_placements];
            for (children) |c| {
                const is_opt = seedctl_force or (bb.any and c.v == bb.best);
                if (!is_opt) continue;
                if (!(c.has_entry and !c.entry_terminal)) continue;
                if (g.idOf(c.target_colex, c.target_side, c.target_ko, @intCast(c.target_passes)) == null) {
                    if (g.nodes.items.len > budget) break;
                    // look up L/H
                    if (artifact2.lookup(&a2, c.target_colex, c.target_side, c.target_ko, @intCast(c.target_passes))) |row| {
                        if (row.terminal) continue; // safety: terminal is a leaf
                        const nid = try g.addNode(c.target_colex, c.target_side, c.target_ko, @intCast(c.target_passes), row.L, row.H);
                        try queue.append(gpa, nid);
                    }
                }
            }
            // pass child
            if (ce.has_pass) {
                const c = ce.pass;
                const is_opt = seedctl_force or (bb.any and c.v == bb.best);
                if (is_opt and c.has_entry and !c.entry_terminal) {
                    if (g.idOf(c.target_colex, c.target_side, c.target_ko, @intCast(c.target_passes)) == null) {
                        if (artifact2.lookup(&a2, c.target_colex, c.target_side, c.target_ko, @intCast(c.target_passes))) |row| {
                            if (!row.terminal) {
                                if (g.nodes.items.len <= budget) {
                                    const nid = try g.addNode(c.target_colex, c.target_side, c.target_ko, @intCast(c.target_passes), row.L, row.H);
                                    try queue.append(gpa, nid);
                                }
                            }
                        }
                    }
                }
            }
        }
        // Now re-wire all nodes so edges point to children that have since
        // been materialized (wireNode only added edges to children present
        // at wiring time; later-added children need linking).
        for (g.edges.items) |*e| e.clearRetainingCapacity();
        var id2: u32 = 0;
        tautology_checks = 0;
        tautology_mismatches = 0;
        while (id2 < g.nodes.items.len) : (id2 += 1) {
            const wr = try wireNode(&g, &a2, id2, w, h, seedctl_force, null_graph, keep_one_tie);
            tautology_checks += 1;
            if (!wr.tautology_ok) tautology_mismatches += 1;
        }
        util.note("[T416] {d}x{d} bfs: reached {d} nodes, {d} wired\n", .{ w, h, g.nodes.items.len, tautology_checks });
    }

    // ── SCC ──────────────────────────────────────────────────────────────
    var scc = try tarjanSCC(&g, gpa);
    defer scc.deinit(gpa);

    const r = try classifyAndReport(&g, &scc, gpa);

    // ── Report ───────────────────────────────────────────────────────────
    const verdict = if (r.n_cyclic_scc == 0) "ACYCLIC" else "CONTAINS-CYCLES";
    util.out("[T416] size={d}x{d} mode={s} seedctl={s} null_graph={s}\n", .{ w, h, mode, if (seedctl_force) "force_all_optimal" else "none", if (null_graph) "yes" else "no" });
    util.out("  nodes: {d}   edges: {d}   sccs: {d}\n", .{ r.n_nodes, r.n_edges, r.n_scc });
    util.out("  tautology V_p==Bellman-best: {d} checks, {d} mismatches  (regression guard)\n", .{ tautology_checks, tautology_mismatches });
    util.out("  === VERDICT: {s} ===\n", .{verdict});
    if (r.n_cyclic_scc == 0) {
        util.out("  no cycle in the optimal-move subgraph", .{});
        if (std.mem.eql(u8, mode, "bfs")) util.out(" (sampled reachable subgraph: {d} nodes from {d} seeds; weaker than exhaustive)", .{ r.n_nodes, seeds });
        util.out("\n", .{});
    } else {
        util.out("  cyclic SCCs: {d}   states on cycles: {d}\n", .{ r.n_cyclic_scc, r.n_states_on_cycles });
        util.out("  cycle-size range: {d}..{d}\n", .{ r.min_cycle_size, r.max_cycle_size });
        util.out("  FORCED cycles (all nodes strictly-preferring): {d}  ({d} states)\n", .{ r.n_forced_cycles, r.n_forced_states });
        util.out("  INDIFFERENT cycles (>=1 node has an optimal exit): {d}  ({d} states)\n", .{ r.n_indifferent_cycles, r.n_indifferent_states });
        util.out("  value-constancy around cycle: ok={d}  bad={d}  (bad => subgraph or table wrong)\n", .{ r.n_value_const_ok, r.n_value_const_bad });
        if (r.n_girth_measured > 0) {
            util.out("  girth (shortest cycle length) over {d} measured cyclic SCCs: {d}..{d}\n", .{ r.n_girth_measured, r.min_girth, r.max_girth });
        } else {
            util.out("  girth: not measured (no cyclic SCC of size <= 64)\n", .{});
        }
        // examples with boards
        const X = colex.Indexer(w, h);
        var i: u32 = 0;
        while (i < r.n_examples) : (i += 1) {
            const ex = r.examples[i].?;
            util.out("  --- example {d}: scc_size={d} girth={d} forced={s} value={d} const={s} strict={d} indifferent={d}\n", .{
                i + 1, ex.scc_size, ex.girth, if (ex.forced) "yes" else "no", ex.value, if (ex.value_const) "yes" else "NO", ex.n_strict, ex.n_indifferent,
            });
            var j: u32 = 0;
            while (j < @min(ex.n_members, 4)) : (j += 1) {
                const node = g.nodes.items[ex.members[j]];
                const pos = X.pos_from_colex(node.colex);
                util.out("    node[{d}] colex={d} side={d} ko={d} passes={d} L={d} H={d} pinned={d} opt={d} opt_leaf={d}\n", .{
                    j, node.colex, node.side, node.ko, node.passes, node.L, node.H, node.pinned, node.n_optimal_total, node.n_optimal_leaf,
                });
                // board dump
                var row: usize = 0;
                while (row < h) : (row += 1) {
                    var line: [17]u8 = undefined;
                    var col: usize = 0;
                    while (col < w) : (col += 1) {
                        const cell = pos[row * w + col];
                        line[col] = if (cell > 0) 'X' else if (cell < 0) 'O' else '.';
                    }
                    util.out("      {s}\n", .{line[0..w]});
                }
            }
        }
    }

    // ── JSON ─────────────────────────────────────────────────────────────
    var jb: std.ArrayListUnmanaged(u8) = .empty;
    defer jb.deinit(gpa);
    const app = struct {
        fn s(b: *std.ArrayListUnmanaged(u8), gp: std.mem.Allocator, str: []const u8) !void {
            try b.append(gp, '"');
            for (str) |c| {
                if (c == '"' or c == '\\') try b.append(gp, '\\');
                try b.append(gp, c);
            }
            try b.append(gp, '"');
        }
        fn n(b: *std.ArrayListUnmanaged(u8), gp: std.mem.Allocator, v: anytype) !void {
            var tmp: [32]u8 = undefined;
            const out = try std.fmt.bufPrint(&tmp, "{d}", .{v});
            try b.appendSlice(gp, out);
        }
        fn raw(b: *std.ArrayListUnmanaged(u8), gp: std.mem.Allocator, str: []const u8) !void {
            try b.appendSlice(gp, str);
        }
    };
    try app.raw(&jb, gpa, "{\n");
    try app.raw(&jb, gpa, "  \"task_id\": \"T416\", \"instrument\": \"t416_cycle\", \"size\": \"");
    try app.n(&jb, gpa, w); try app.raw(&jb, gpa, "x"); try app.n(&jb, gpa, h);
    try app.raw(&jb, gpa, "\",\n");
    try app.raw(&jb, gpa, "  \"wzo2_path\": "); try app.s(&jb, gpa, wzo2_path); try app.raw(&jb, gpa, ", ");
    try app.raw(&jb, gpa, "\"mode\": "); try app.s(&jb, gpa, mode); try app.raw(&jb, gpa, ", ");
    try app.raw(&jb, gpa, "\"seedctl\": "); try app.s(&jb, gpa, if (seedctl_force) "force_all_optimal" else "none"); try app.raw(&jb, gpa, ", ");
    try app.raw(&jb, gpa, "\"null_graph\": "); try app.s(&jb, gpa, if (null_graph) "yes" else "no"); try app.raw(&jb, gpa, ",\n");
    if (std.mem.eql(u8, mode, "bfs")) {
        try app.raw(&jb, gpa, "  \"seeds\": "); try app.n(&jb, gpa, seeds); try app.raw(&jb, gpa, ", ");
        try app.raw(&jb, gpa, "\"budget\": "); try app.n(&jb, gpa, budget); try app.raw(&jb, gpa, ", ");
        try app.raw(&jb, gpa, "\"seed\": "); try app.n(&jb, gpa, seed); try app.raw(&jb, gpa, ",\n");
    }
    try app.raw(&jb, gpa, "  \"verdict\": "); try app.s(&jb, gpa, verdict); try app.raw(&jb, gpa, ",\n");
    try app.raw(&jb, gpa, "  \"n_nodes\": "); try app.n(&jb, gpa, r.n_nodes); try app.raw(&jb, gpa, ", ");
    try app.raw(&jb, gpa, "\"n_edges\": "); try app.n(&jb, gpa, r.n_edges); try app.raw(&jb, gpa, ", ");
    try app.raw(&jb, gpa, "\"n_scc\": "); try app.n(&jb, gpa, r.n_scc); try app.raw(&jb, gpa, ",\n");
    try app.raw(&jb, gpa, "  \"tautology_checks\": "); try app.n(&jb, gpa, tautology_checks); try app.raw(&jb, gpa, ", ");
    try app.raw(&jb, gpa, "\"tautology_mismatches\": "); try app.n(&jb, gpa, tautology_mismatches); try app.raw(&jb, gpa, ",\n");
    try app.raw(&jb, gpa, "  \"n_cyclic_scc\": "); try app.n(&jb, gpa, r.n_cyclic_scc); try app.raw(&jb, gpa, ", ");
    try app.raw(&jb, gpa, "\"n_states_on_cycles\": "); try app.n(&jb, gpa, r.n_states_on_cycles); try app.raw(&jb, gpa, ",\n");
    try app.raw(&jb, gpa, "  \"n_forced_cycles\": "); try app.n(&jb, gpa, r.n_forced_cycles); try app.raw(&jb, gpa, ", ");
    try app.raw(&jb, gpa, "\"n_forced_states\": "); try app.n(&jb, gpa, r.n_forced_states); try app.raw(&jb, gpa, ", ");
    try app.raw(&jb, gpa, "\"n_indifferent_cycles\": "); try app.n(&jb, gpa, r.n_indifferent_cycles); try app.raw(&jb, gpa, ", ");
    try app.raw(&jb, gpa, "\"n_indifferent_states\": "); try app.n(&jb, gpa, r.n_indifferent_states); try app.raw(&jb, gpa, ",\n");
    try app.raw(&jb, gpa, "  \"n_value_const_ok\": "); try app.n(&jb, gpa, r.n_value_const_ok); try app.raw(&jb, gpa, ", ");
    try app.raw(&jb, gpa, "\"n_value_const_bad\": "); try app.n(&jb, gpa, r.n_value_const_bad); try app.raw(&jb, gpa, ",\n");
    try app.raw(&jb, gpa, "  \"min_cycle_size\": "); try app.n(&jb, gpa, r.min_cycle_size); try app.raw(&jb, gpa, ", ");
    try app.raw(&jb, gpa, "\"max_cycle_size\": "); try app.n(&jb, gpa, r.max_cycle_size); try app.raw(&jb, gpa, ", ");
    try app.raw(&jb, gpa, "\"min_girth\": "); try app.n(&jb, gpa, r.min_girth); try app.raw(&jb, gpa, ", ");
    try app.raw(&jb, gpa, "\"max_girth\": "); try app.n(&jb, gpa, r.max_girth); try app.raw(&jb, gpa, ", ");
    try app.raw(&jb, gpa, "\"n_girth_measured\": "); try app.n(&jb, gpa, r.n_girth_measured); try app.raw(&jb, gpa, "\n");
    // examples
    try app.raw(&jb, gpa, "  ,\"examples\": [\n");
    var i: u32 = 0;
    while (i < r.n_examples) : (i += 1) {
        const ex = r.examples[i].?;
        if (i > 0) try app.raw(&jb, gpa, ",\n");
        try app.raw(&jb, gpa, "    {");
        try app.raw(&jb, gpa, "\"scc_size\":"); try app.n(&jb, gpa, ex.scc_size); try app.raw(&jb, gpa, ",");
        try app.raw(&jb, gpa, "\"girth\":"); try app.n(&jb, gpa, ex.girth); try app.raw(&jb, gpa, ",");
        try app.raw(&jb, gpa, "\"forced\":"); try app.s(&jb, gpa, if (ex.forced) "yes" else "no"); try app.raw(&jb, gpa, ",");
        try app.raw(&jb, gpa, "\"value\":"); try app.n(&jb, gpa, ex.value); try app.raw(&jb, gpa, ",");
        try app.raw(&jb, gpa, "\"value_const\":"); try app.s(&jb, gpa, if (ex.value_const) "yes" else "no"); try app.raw(&jb, gpa, ",");
        try app.raw(&jb, gpa, "\"n_strict\":"); try app.n(&jb, gpa, ex.n_strict); try app.raw(&jb, gpa, ",");
        try app.raw(&jb, gpa, "\"n_indifferent\":"); try app.n(&jb, gpa, ex.n_indifferent); try app.raw(&jb, gpa, ",");
        try app.raw(&jb, gpa, "\"members\":[");
        var j: u32 = 0;
        while (j < ex.n_members) : (j += 1) {
            if (j > 0) try app.raw(&jb, gpa, ",");
            const node = g.nodes.items[ex.members[j]];
            try app.raw(&jb, gpa, "{\"colex\":"); try app.n(&jb, gpa, node.colex);
            try app.raw(&jb, gpa, ",\"side\":"); try app.n(&jb, gpa, node.side);
            try app.raw(&jb, gpa, ",\"ko\":"); try app.n(&jb, gpa, node.ko);
            try app.raw(&jb, gpa, ",\"passes\":"); try app.n(&jb, gpa, node.passes);
            try app.raw(&jb, gpa, ",\"L\":"); try app.n(&jb, gpa, node.L);
            try app.raw(&jb, gpa, ",\"H\":"); try app.n(&jb, gpa, node.H);
            try app.raw(&jb, gpa, ",\"pinned\":"); try app.n(&jb, gpa, node.pinned);
            try app.raw(&jb, gpa, ",\"n_optimal_total\":"); try app.n(&jb, gpa, node.n_optimal_total);
            try app.raw(&jb, gpa, ",\"n_optimal_leaf\":"); try app.n(&jb, gpa, node.n_optimal_leaf);
            try app.raw(&jb, gpa, "}");
        }
        try app.raw(&jb, gpa, "]}");
    }
    try app.raw(&jb, gpa, "\n  ]\n");
    try app.raw(&jb, gpa, "}\n");

    if (json_path.len > 0) {
        std.Io.Dir.cwd().writeFile(io, .{ .sub_path = json_path, .data = jb.items }) catch |err| {
            util.warn("[T416] failed to write json {s}: {s}\n", .{ json_path, @errorName(err) });
        };
    }
}

pub fn main(init: std.process.Init) !void {
    const gpa = std.heap.page_allocator;
    const io = init.io;
    _ = version;

    var args = std.process.Args.Iterator.init(init.minimal.args);
    _ = args.next();

    var opt_size: u8 = 3;
    var opt_wzo2: []const u8 = "";
    var opt_mode: []const u8 = "";
    var opt_seeds: usize = 20000;
    var opt_budget: usize = 2_000_000;
    var opt_seed: u64 = 42;
    var opt_json: []const u8 = "";
    var opt_force: bool = false;
    var opt_null: bool = false;
    var opt_keep_one: bool = false;

    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--size")) {
            opt_size = try std.fmt.parseInt(u8, args.next() orelse return error.MissingArgument, 10);
        } else if (std.mem.eql(u8, arg, "--wzo2")) {
            opt_wzo2 = args.next() orelse return error.MissingArgument;
        } else if (std.mem.eql(u8, arg, "--mode")) {
            opt_mode = args.next() orelse return error.MissingArgument;
        } else if (std.mem.eql(u8, arg, "--seeds")) {
            opt_seeds = try std.fmt.parseInt(usize, args.next() orelse return error.MissingArgument, 10);
        } else if (std.mem.eql(u8, arg, "--budget")) {
            opt_budget = try std.fmt.parseInt(usize, args.next() orelse return error.MissingArgument, 10);
        } else if (std.mem.eql(u8, arg, "--seed")) {
            opt_seed = try std.fmt.parseInt(u64, args.next() orelse return error.MissingArgument, 10);
        } else if (std.mem.eql(u8, arg, "--json")) {
            opt_json = args.next() orelse return error.MissingArgument;
        } else if (std.mem.eql(u8, arg, "--seedctl")) {
            const v = args.next() orelse return error.MissingArgument;
            if (std.mem.eql(u8, v, "force_loopy") or std.mem.eql(u8, v, "force_all_optimal")) opt_force = true else if (std.mem.eql(u8, v, "null")) opt_force = false else return error.InvalidArgument;
        } else if (std.mem.eql(u8, arg, "--null-graph")) {
            opt_null = true;
        } else if (std.mem.eql(u8, arg, "--keep-one-tie")) {
            opt_keep_one = true;
        } else {
            util.warn("unknown flag: {s}\n", .{arg});
            return error.InvalidArgument;
        }
    }

    if (opt_wzo2.len == 0) {
        opt_wzo2 = switch (opt_size) {
            3 => "data/oracle-3x3-v2.wzo2",
            4 => "data/oracle-4x4-v2.wzo2",
            else => return error.InvalidSize,
        };
    }
    if (opt_mode.len == 0) {
        opt_mode = switch (opt_size) {
            3 => "exhaustive",
            4 => "bfs",
            else => "exhaustive",
        };
    }
    if (opt_json.len == 0) {
        opt_json = switch (opt_size) {
            3 => "findings/T416-cycle-3x3.json",
            4 => "findings/T416-cycle-4x4.json",
            else => "findings/T416-cycle.json",
        };
    }

    switch (opt_size) {
        3 => try runSize(3, 3, io, gpa, opt_wzo2, opt_mode, opt_seeds, opt_budget, opt_seed, opt_json, opt_force, opt_null, opt_keep_one),
        4 => try runSize(4, 4, io, gpa, opt_wzo2, opt_mode, opt_seeds, opt_budget, opt_seed, opt_json, opt_force, opt_null, opt_keep_one),
        else => return error.InvalidSize,
    }
}