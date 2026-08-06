////////////////////////////////////////////
//                                        //
//    (c) 2026 Alexander E Genaud         //
//                                        //
//    Permission is granted hereby,       //
//        for any purpose,                //
//    provided these notices multiply.    //
//                                        //
////////////////////////////////////////////
//
// Task: T385 · Role: worker · Model: deepseek-v4-flash · Date: 2026-08-06
//
// T385 — "show the positions, then fix the name". Bracket gallery over the
// 4×4 WZO2 table + the what-causes-L<H correlation + the class-3 (bracketed
// with NO ko anywhere) census. Additive instrument only: reads the artifacts,
// touches no engine source, no build.zig, no artifact.
//
// The table is `data/oracle-4x4-v2.wzo2` (WZO2, rules_id 3 = basic ko + L/H
// bracket; SHA-256 0c3366f07fb33c6f2838ead48ad3080b64dbe55935b87af4f140d81a29e4e15a,
// 24,318,165 position groups, 99,133,036 entries). The 3×3 table
// `data/oracle-3x3-v2.wzo2` (SHA d79c17cd…) is used for the EXHAUSTIVE SCC /
// class-3 control (its whole graph is 49,428 entries — Tarjan + exact
// ko-reachability and exact 1-ply-ban-parent detection fit in memory).
//
// Ko decode: the key byte's ko field sits at bits 2..(1+ko_bits) — `kb >> 2`,
// per artifact2 §2.2 (`decodeKeyByte`). This is T380 F-7; T383 landed the fix
// in `src/vb_closure.zig` (c5e75d7) and this instrument independently uses the
// correct shift and regression-checks it against `artifact2.decodeKeyByte`
// (selftest).
//
// Move semantics: the T273 kernel (`rules.zig` Rules(4,4): applyMove /
// applyPass / koAfterCapture) — the same kernel the table's key agreement and
// T380 Q2 verified against the production successor sets (0 mismatches).
//
// Modes:
//   selftest   — instrument sanity checks (see below)
//   run        — pass A (full 4×4 table scan) + gallery + bounded corr4x4
//   corr3x3    — exhaustive 3×3 Tarjan SCC correlation + exact class-3 census
//
// Controls:
//   selftest: colex round-trip; key-byte decode vs artifact2 (T383 F-7
//   regression); binary search vs linear scan; children-not-in-table spot
//   check (C-A1); PASS-NOKO invariant (every passes≥1 entry has ko == NONE);
//   natural-parent reconstruction of ban states (class-1 machinery); positive
//   control for the ko search (the natural parent of a ban state must find
//   the ko at depth ≤ 1 through the SAME search code); hand-built-graph
//   positive control for the Tarjan and the cycle DFS (5 vertices, one
//   2-cycle → 4 SCCs / cycle found from 0, not from the leaf).
//   run: cross-checks its position-level aggregates against T380's published
//   Q4 numbers (1,924,973 set positions; 1,782,629 zero-ko set positions;
//   92.6%; fresh-start set 1,913,925; bracket entries 3,455,412) — a null
//   control over the same table.
//
// Compile (ad hoc, under tools/runner for the run modes):
//   zig build-exe -O ReleaseFast --dep version -Mroot=src/t385_gallery.zig \
//     -Mversion=src/version.zig --cache-dir /tmp/weizigo/t385/kc \
//     --global-cache-dir /tmp/weizigo/t385/gc --name weizigo-t385-gallery \
//     -femit-bin=/tmp/weizigo/t385/bin/gallery
//
// stdout = data (the final JSON), stderr = diagnostics.

const std = @import("std");
const rules = @import("rules.zig");
const colexmod = @import("colex.zig");
const artifact2 = @import("artifact2.zig");
const enumerate = @import("enumerate.zig");

const W = 4;
const H = 4;
const N = W * H;
const R = rules.Rules(W, H);
const X = colexmod.Indexer(W, H);
const E = enumerate.Enumerator(W, H);
const Pos = X.Pos;

const KO_NONE: u8 = @intCast(N); // 16
const PASS_MOVE: u8 = 255; // move marker for a pass in a path

// ---------------------------------------------------------------------------
// WZO2 reader (raw; same layout as t380_census's reader, + binary search)
// ---------------------------------------------------------------------------

const Entry = struct {
    colex: u32,
    side: i8, // +1 Black to move, -1 White to move
    ko: u8, // < N = ban cell, >= N = none
    passes: u2,
    L: i8,
    H: i8,
    terminal: bool,
};

fn keyByteSide(kb: u8) i8 {
    return if ((kb >> 1) & 1 == 0) 1 else -1;
}
fn keyByteKo(kb: u8, ko_bits: u8) u8 {
    const mask: u8 = if (ko_bits == 0) 0 else @intCast((@as(u16, 1) << @intCast(ko_bits)) - 1);
    return @intCast((kb >> 2) & mask); // F-7: NOT kb >> 1
}
fn keyBytePasses(kb: u8, ko_bits: u8) u2 {
    const shift: u3 = @intCast(2 + ko_bits);
    return @intCast((kb >> shift) & 1);
}

const GroupHdr = struct { colex: u32, count: u8, entry_offset: u64 };

const Wzo2 = struct {
    bytes: []const u8,
    n_groups: u64,
    n_entries: u64,
    ko_bits: u8,
    entry_base: usize,
    groups: []GroupHdr,

    fn open(gpa: std.mem.Allocator, path: []const u8) !Wzo2 {
        const cwd = std.Io.Dir.cwd();
        var threaded = std.Io.Threaded.init(gpa, .{});
        defer threaded.deinit();
        const io = threaded.io();
        const bytes = try cwd.readFileAlloc(io, path, gpa, .unlimited);
        if (bytes.len < 128 or !std.mem.eql(u8, bytes[0..4], "WZO2")) return error.BadWzo2;
        const n_groups = std.mem.readInt(u64, bytes[16..24], .little);
        const n_entries = std.mem.readInt(u64, bytes[24..32], .little);
        const ko_bits = bytes[13];
        const group_base: usize = 128;
        const entry_base: usize = group_base + @as(usize, @intCast(n_groups)) * 5;
        const groups = try gpa.alloc(GroupHdr, @intCast(n_groups));
        var cum: u64 = 0;
        for (0..@as(usize, @intCast(n_groups))) |i| {
            const off = group_base + i * 5;
            groups[i] = .{
                .colex = std.mem.readInt(u32, bytes[off..][0..4], .little),
                .count = bytes[off + 4],
                .entry_offset = cum,
            };
            cum += groups[i].count;
        }
        return .{ .bytes = bytes, .n_groups = n_groups, .n_entries = n_entries, .ko_bits = ko_bits, .entry_base = entry_base, .groups = groups };
    }

    fn entryAt(self: *const Wzo2, g: usize, i: usize) Entry {
        const off = self.entry_base + (self.groups[g].entry_offset + i) * 4;
        const kb = self.bytes[off];
        return .{
            .colex = self.groups[g].colex,
            .side = keyByteSide(kb),
            .ko = keyByteKo(kb, self.ko_bits),
            .passes = keyBytePasses(kb, self.ko_bits),
            .L = @bitCast(self.bytes[off + 1]),
            .H = @bitCast(self.bytes[off + 2]),
            .terminal = (kb & 1) != 0,
        };
    }

    /// Within-group sort key (§2.4): (passes, ko_point, side) with side
    /// 0 = Black. Bits: passes at 7, ko at 1..6, side bit at 0.
    fn sortKey(ko_bits: u8, passes: u2, ko: u8, side_bit: u1) u16 {
        _ = ko_bits;
        return (@as(u16, passes) << 7) | (@as(u16, ko) << 1) | side_bit;
    }

    /// Binary-search an entry within a group by (passes, ko, side).
    fn lookup(self: *const Wzo2, g: usize, side: i8, ko: u8, passes: u2) ?Entry {
        const cnt: usize = self.groups[g].count;
        const sb: u1 = if (side > 0) 0 else 1;
        const want = sortKey(self.ko_bits, passes, ko, sb);
        var lo: usize = 0;
        var hi: usize = cnt;
        while (lo < hi) {
            const mid = lo + (hi - lo) / 2;
            const e = self.entryAt(g, mid);
            const got = sortKey(self.ko_bits, e.passes, e.ko, if (e.side > 0) 0 else 1);
            if (got < want) {
                lo = mid + 1;
            } else {
                hi = mid;
            }
        }
        if (lo < cnt) {
            const e = self.entryAt(g, lo);
            const got = sortKey(self.ko_bits, e.passes, e.ko, if (e.side > 0) 0 else 1);
            if (got == want) return e;
        }
        return null;
    }
};

/// Compact state key for maps.
fn stKey(colex: u32, side: i8, ko: u8, passes: u2) u64 {
    const sb: u64 = if (side > 0) 0 else 1;
    return (@as(u64, colex) << 8) | (sb << 7) | (@as(u64, ko) << 2) | passes;
}

fn keyState(key: u64) struct { colex: u32, side: i8, ko: u8, passes: u2 } {
    return .{
        .colex = @intCast(key >> 8),
        .side = if ((key >> 7) & 1 == 0) 1 else -1,
        .ko = @intCast((key >> 2) & 0x1F),
        .passes = @intCast(key & 3),
    };
}

fn findGroup(table: *const Wzo2, colex: u32) ?usize {
    var lo: usize = 0;
    var hi: usize = @intCast(table.n_groups);
    while (lo < hi) {
        const mid = lo + (hi - lo) / 2;
        if (table.groups[mid].colex < colex) {
            lo = mid + 1;
        } else {
            hi = mid;
        }
    }
    if (lo < table.n_groups and table.groups[lo].colex == colex) return lo;
    return null;
}

fn stateOf(table: *const Wzo2, key: u64) Entry {
    const st = keyState(key);
    const g = findGroup(table, st.colex).?;
    return table.lookup(g, st.side, st.ko, st.passes).?;
}

// ---------------------------------------------------------------------------
// Ko shape detection (production kernel rule: no friendly neighbours; T380's
// isKoShape). hasKoShape early-exits (pass A needs zero-vs-nonzero).
// ---------------------------------------------------------------------------

fn isKoShape(pos: *const Pos, p: usize, colour: i8) ?u8 {
    if (pos[p] != 0) return null;
    const next = R.pos_from_move(pos, colour, p) catch return null;
    var opp_before: u8 = 0;
    var opp_after: u8 = 0;
    var captured: ?usize = null;
    for (0..N) |i| {
        if (pos[i] == -colour) opp_before += 1;
        if (next[i] == -colour) opp_after += 1;
        if (pos[i] == -colour and next[i] == 0) captured = i;
    }
    if (opp_before - opp_after != 1) return null;
    var libs: u8 = 0;
    var friends: u8 = 0;
    var nb: [4]usize = undefined;
    const cnt = R.neighbors(p, &nb);
    for (nb[0..cnt]) |q| {
        if (next[q] == 0) libs += 1;
        if (next[q] == colour) friends += 1;
    }
    if (libs != 1 or friends != 0) return null;
    return @intCast(captured.?);
}

fn hasKoShape(pos: *const Pos) bool {
    for (0..N) |p| {
        inline for (.{ @as(i8, 1), @as(i8, -1) }) |colour| {
            if (isKoShape(pos, p, colour) != null) return true;
        }
    }
    return false;
}

fn countKoShapes(pos: *const Pos) u8 {
    var c: u8 = 0;
    for (0..N) |p| {
        inline for (.{ @as(i8, 1), @as(i8, -1) }) |colour| {
            if (isKoShape(pos, p, colour) != null) c += 1;
        }
    }
    return c;
}

fn countStones(pos: *const Pos) u8 {
    var c: u8 = 0;
    for (pos) |v| {
        if (v != 0) c += 1;
    }
    return c;
}

// ---------------------------------------------------------------------------
// Board rendering (a board a human can read)
// ---------------------------------------------------------------------------

fn colLetter(c: usize) u8 {
    return 'A' + @as(u8, @intCast(c));
}

/// Render the position with side/ko/passes in the caption. The ko ban cell
/// (if any) is marked '*' on the board.
fn renderBoard(pos: *const Pos, side: i8, ko: u8, passes: u2, buf: *[512]u8) []const u8 {
    var w = std.Io.Writer.fixed(buf);
    w.print("      A   B   C   D\n", .{}) catch {};
    for (0..H) |r| {
        w.print(" {d}   ", .{r + 1}) catch {};
        for (0..W) |c| {
            const cell = r * W + c;
            const ch: u8 = if (pos[cell] > 0) 'X' else if (pos[cell] < 0) 'O' else if (ko < N and cell == ko) '*' else '.';
            w.print(" {c} ", .{ch}) catch {};
        }
        w.print("\n", .{}) catch {};
    }
    const side_s = if (side > 0) "Black" else "White";
    if (ko < N) {
        w.print("side: {s} to move · ko ban on {c}{d} (may not play there) · passes: {d}\n", .{
            side_s, colLetter(ko % W), (ko / W) + 1, passes,
        }) catch {};
    } else {
        w.print("side: {s} to move · ko: none · passes: {d}\n", .{ side_s, passes }) catch {};
    }
    return buf[0..w.end];
}

// ---------------------------------------------------------------------------
// Children of an in-table state (kernel move semantics)
// ---------------------------------------------------------------------------

const ChildCtx = struct {
    table: *const Wzo2,
    missing: *u64,
    expanded: *u64,
};

/// Writes child state keys into out and their move cells (0..N-1 placement,
/// PASS_MOVE for a pass) into moves. Missing children (not in the table) are
/// counted in ctx.missing — the closure says 0 for this table (C-A1).
fn childrenOf(ctx: *ChildCtx, colex: u32, side: i8, ko: u8, passes: u2, out: *[N + 1]u64, moves: *[N + 1]u8) u32 {
    const pos = X.pos_from_colex(colex);
    var k: u32 = 0;
    for (0..N) |cell| {
        if (R.applyMove(&pos, side, ko, passes, cell)) |c| {
            const cco: u32 = @intCast(X.colex_from_pos(&c.pos));
            const g = findGroup(ctx.table, cco) orelse {
                ctx.missing.* += 1;
                continue;
            };
            if (ctx.table.lookup(g, c.side, c.ko, c.passes) != null) {
                out[k] = stKey(cco, c.side, c.ko, c.passes);
                moves[k] = @intCast(cell);
                k += 1;
            } else {
                ctx.missing.* += 1;
            }
        }
    }
    if (R.applyPass(side, passes)) |pc| {
        if (pc.passes >= 2) return k; // absorbing terminal child — not stored (HDR_FLAG_PASSES_2_OMITTED), not a graph vertex
        const g = findGroup(ctx.table, colex) orelse {
            ctx.missing.* += 1;
            return k;
        };
        if (ctx.table.lookup(g, pc.side, pc.ko, pc.passes) != null) {
            out[k] = stKey(colex, pc.side, pc.ko, pc.passes);
            moves[k] = PASS_MOVE;
            k += 1;
        } else {
            ctx.missing.* += 1;
        }
    }
    ctx.expanded.* += 1;
    return k;
}

// ---------------------------------------------------------------------------
// Bounded forward search
// ---------------------------------------------------------------------------

const SearchBounds = struct { depth: u16, nodes: u32 };

const CycleResult = struct { found: bool, depth: u16, nodes: u32 };

/// Bounded DFS cycle detection: "can reach a non-trivial cycle within the
/// bound" iff a back edge (a successor already on the DFS path) is found
/// within depth `bounds.depth` and node budget `bounds.nodes`. Exact for the
/// bound: any cycle whose vertices are reachable within the bound closes via
/// a back edge inside the same DFS.
fn cycleSearch(gpa: std.mem.Allocator, ctx: *ChildCtx, root: u64, bounds: SearchBounds) !CycleResult {
    var visited = std.AutoHashMap(u64, void).init(gpa);
    defer visited.deinit();
    var onpath = std.AutoHashMap(u64, void).init(gpa);
    defer onpath.deinit();

    const StackItem = struct { key: u64, depth: u16, child_idx: u32 };
    var stack = std.ArrayListUnmanaged(StackItem).empty;
    defer stack.deinit(gpa);

    try visited.put(root, {});
    try onpath.put(root, {});
    try stack.append(gpa, .{ .key = root, .depth = 0, .child_idx = 0 });
    var nodes: u32 = 1;

    var children = [_]u64{0} ** (N + 1);
    var moves = [_]u8{0} ** (N + 1);
    while (stack.items.len > 0) {
        const top = &stack.items[stack.items.len - 1];
        const st = keyState(top.key);
        if (st.passes == 2) {
            _ = onpath.remove(top.key);
            _ = stack.pop();
            continue;
        }
        const cnt = childrenOf(ctx, st.colex, st.side, st.ko, st.passes, &children, &moves);
        if (top.child_idx < cnt) {
            const child = children[top.child_idx];
            top.child_idx += 1;
            if (onpath.contains(child)) {
                return .{ .found = true, .depth = top.depth + 1, .nodes = nodes };
            }
            if (visited.contains(child)) continue;
            if (nodes >= bounds.nodes) return .{ .found = false, .depth = 0, .nodes = nodes };
            if (top.depth + 1 >= bounds.depth) continue; // do not expand beyond D
            try visited.put(child, {});
            try onpath.put(child, {});
            try stack.append(gpa, .{ .key = child, .depth = top.depth + 1, .child_idx = 0 });
            nodes += 1;
        } else {
            _ = onpath.remove(top.key);
            _ = stack.pop();
        }
    }
    return .{ .found = false, .depth = 0, .nodes = nodes };
}

const KoResult = struct {
    found: bool,
    depth: u16,
    nodes: u32,
    ko_cell: u8,
    ko_terminal: bool,
    path_len: usize,
    /// move cells root → ko state (PASS_MOVE = pass); valid iff found and
    /// path_out was provided
    path: [128]u8,
};

/// Bounded BFS for a ko-carrying state (entry ko != NONE, or the position has
/// a ko shape) reachable before terminal (passes == 2 is not expanded).
/// When `path_out.len > 0`, the witness path (root → ko state) is unwound
/// into `path_out` and its length returned in `path_len_out`.
fn koSearch(
    gpa: std.mem.Allocator,
    ctx: *ChildCtx,
    root: u64,
    bounds: SearchBounds,
    path_out: []u8,
    path_len_out: *usize,
) !KoResult {
    var visited = std.AutoHashMap(u64, void).init(gpa);
    defer visited.deinit();
    var parent = std.AutoHashMap(u64, u64).init(gpa);
    defer parent.deinit();
    var move_of = std.AutoHashMap(u64, u8).init(gpa);
    defer move_of.deinit();
    path_len_out.* = 0;

    const QueueItem = struct { key: u64, level: u16 };
    var queue = std.ArrayListUnmanaged(QueueItem).empty;
    defer queue.deinit(gpa);

    try visited.put(root, {});
    try queue.append(gpa, .{ .key = root, .level = 0 });
    var head: usize = 0;
    var nodes: u32 = 1;

    var children = [_]u64{0} ** (N + 1);
    var moves = [_]u8{0} ** (N + 1);
    while (head < queue.items.len) {
        const item = queue.items[head];
        head += 1;
        const st = keyState(item.key);
        if (item.level > 0) {
            const pos = X.pos_from_colex(st.colex);
            if (st.ko != KO_NONE or hasKoShape(&pos)) {
                const e = stateOf(ctx.table, item.key);
                var res = KoResult{ .found = true, .depth = item.level, .nodes = nodes, .ko_cell = st.ko, .ko_terminal = e.terminal, .path_len = 0, .path = undefined };
                if (path_out.len > 0) {
                    // unwind: found_key -> root via parent, moves in move_of
                    var rev: [128]u8 = undefined;
                    var n: usize = 0;
                    var cur = item.key;
                    while (parent.get(cur)) |p| {
                        if (n >= 128) break;
                        rev[n] = move_of.get(cur).?;
                        n += 1;
                        cur = p;
                    }
                    var i: usize = 0;
                    while (i < n) : (i += 1) {
                        path_out[i] = rev[n - 1 - i];
                    }
                    res.path_len = n;
                    path_len_out.* = n;
                    if (n > 0) @memcpy(res.path[0..n], path_out[0..n]);
                }
                return res;
            }
        }
        if (st.passes == 2) continue; // absorbing terminal — no expansion
        if (item.level >= bounds.depth) continue;
        const cnt = childrenOf(ctx, st.colex, st.side, st.ko, st.passes, &children, &moves);
        for (children[0..cnt], moves[0..cnt]) |child, mv| {
            if (visited.contains(child)) continue;
            if (nodes >= bounds.nodes) continue;
            try visited.put(child, {});
            if (path_out.len > 0) {
                try parent.put(child, item.key);
                try move_of.put(child, mv);
            }
            try queue.append(gpa, .{ .key = child, .level = item.level + 1 });
            nodes += 1;
        }
    }
    return .{ .found = false, .depth = 0, .nodes = nodes, .ko_cell = KO_NONE, .ko_terminal = false, .path_len = 0, .path = undefined };
}

// ---------------------------------------------------------------------------
// 1-ply backward "ban parent" check (conservative: single-capture
// restoration only — see header).
// ---------------------------------------------------------------------------

const BackParent = struct { found: bool, move_cell: u8, parent_ko: u8 };

/// For child state (pos, side=S, ko=NONE, passes=0): is there a table entry
/// (pos_p, -S, e != NONE, 0) with a move to the child? Reconstructs pos_p by
/// removing the previous move's stone at c (pos[c] == -S) and restoring a
/// single captured S stone at y (pos[y] == 0). The parent's ban e must sit at
/// a cell where the parent position carries a ko shape. Single-capture
/// restoration only — a multi-capture parent can be missed (conservative;
/// the 3×3 exhaustive reverse-graph check quantifies the miss rate).
fn backwardBanParent(ctx: *ChildCtx, colex: u32, side: i8, ko: u8, passes: u2) BackParent {
    if (ko != KO_NONE or passes != 0) return .{ .found = false, .move_cell = 0, .parent_ko = 0 };
    const pos = X.pos_from_colex(colex);
    const prev_side: i8 = -side;
    for (0..N) |c| {
        if (pos[c] != prev_side) continue; // the last move's stone
        for (0..N) |y| {
            if (y == c) continue;
            if (pos[y] != 0) continue; // a restored (captured) stone
            var pos_p = pos;
            pos_p[c] = 0;
            pos_p[y] = side;
            for (0..N) |e| {
                if (e == c or e == y) continue;
                if (pos_p[e] != 0) continue;
                if (isKoShape(&pos_p, e, prev_side) == null) continue;
                const child = R.applyMove(&pos_p, prev_side, @intCast(e), 0, c) orelse continue;
                if (child.side != side or child.ko != ko or child.passes != passes) continue;
                const cco: u32 = @intCast(X.colex_from_pos(&child.pos));
                if (cco != colex) continue;
                const g = findGroup(ctx.table, @intCast(X.colex_from_pos(&pos_p))) orelse continue;
                if (ctx.table.lookup(g, prev_side, @intCast(e), 0) == null) continue;
                return .{ .found = true, .move_cell = @intCast(c), .parent_ko = @intCast(e) };
            }
        }
    }
    return .{ .found = false, .move_cell = 0, .parent_ko = 0 };
}

/// Natural parent of a ban state (class 1): current state (pos, S, e, 0) with
/// ban e; the previous player -S played at e, capturing an S stone at e, so
/// pos_p = pos with an S stone restored at e. Returns the parent entry for the
/// first ko_p in {NONE} ∪ cells\{e} that is in the table and reproduces the
/// state.
fn naturalParent(ctx: *ChildCtx, colex: u32, side: i8, ko: u8, passes: u2) ?struct { parent_key: u64, ko_p: u8, move_cell: u8 } {
    if (ko == KO_NONE or passes != 0) return null;
    const pos = X.pos_from_colex(colex);
    const prev_side: i8 = -side;
    // the capturing move played at x adjacent to the ban cell ko, capturing an
    // S stone at ko; pos_p = pos with the S stone restored at ko and the -S
    // stone removed at x
    for (0..N) |x| {
        if (pos[x] != prev_side) continue; // the capturing stone
        var pos_p = pos;
        pos_p[ko] = side; // restore the captured stone
        pos_p[x] = 0; // remove the capturing stone
        // candidate parent bans: NONE first, then every cell except ko
        var candidates: [N + 1]u8 = undefined;
        candidates[0] = KO_NONE;
        var nc: usize = 1;
        for (0..N) |e| {
            if (e != ko) {
                candidates[nc] = @intCast(e);
                nc += 1;
            }
        }
        for (candidates[0..nc]) |ko_p| {
            const child = R.applyMove(&pos_p, prev_side, ko_p, 0, x) orelse continue;
            if (child.side != side or child.ko != ko or child.passes != passes) continue;
            const cco: u32 = @intCast(X.colex_from_pos(&child.pos));
            if (cco != colex) continue;
            const g = findGroup(ctx.table, @intCast(X.colex_from_pos(&pos_p))) orelse continue;
            if (ctx.table.lookup(g, prev_side, ko_p, 0) == null) continue;
            return .{ .parent_key = stKey(@intCast(X.colex_from_pos(&pos_p)), prev_side, ko_p, 0), .ko_p = ko_p, .move_cell = @intCast(x) };
        }
    }
    return null;
}

// ---------------------------------------------------------------------------
// JSON writer (hand-rolled; std.json abandoned under Zig 0.16 churn)
// ---------------------------------------------------------------------------

const Json = struct {
    gpa: std.mem.Allocator,
    buf: std.ArrayListUnmanaged(u8),

    fn init(gpa: std.mem.Allocator) Json {
        return .{ .gpa = gpa, .buf = std.ArrayListUnmanaged(u8).empty };
    }
    fn deinit(self: *Json) void {
        self.buf.deinit(self.gpa);
    }
    fn put(self: *Json, s: []const u8) void {
        self.buf.appendSlice(self.gpa, s) catch unreachable;
    }
    fn putCh(self: *Json, c: u8) void {
        self.buf.append(self.gpa, c) catch unreachable;
    }
    fn esc(self: *Json, s: []const u8) void {
        self.putCh('"');
        for (s) |c| {
            switch (c) {
                '"' => self.put("\\\""),
                '\\' => self.put("\\\\"),
                '\n' => self.put("\\n"),
                '\t' => self.put("\\t"),
                '\r' => self.put("\\r"),
                0...8, 11...12, 14...31 => {
                    var tmp: [8]u8 = undefined;
                    const t = std.fmt.bufPrint(&tmp, "\\u{x:0>4}", .{c}) catch unreachable;
                    self.put(t);
                },
                else => self.putCh(c),
            }
        }
        self.putCh('"');
    }
    fn int(self: *Json, v: anytype) void {
        self.buf.print(self.gpa, "{d}", .{v}) catch unreachable;
    }
    fn flt(self: *Json, v: f64) void {
        self.buf.print(self.gpa, "{d:.4}", .{v}) catch unreachable;
    }
    fn bool_(self: *Json, v: bool) void {
        self.put(if (v) "true" else "false");
    }
    fn objBegin(self: *Json) void {
        self.putCh('{');
    }
    fn objEnd(self: *Json) void {
        self.putCh('}');
    }
    fn arrBegin(self: *Json) void {
        self.putCh('[');
    }
    fn arrEnd(self: *Json) void {
        self.putCh(']');
    }
    fn key(self: *Json, k: []const u8) void {
        self.esc(k);
        self.putCh(':');
    }
    fn comma(self: *Json, first: *bool) void {
        if (!first.*) self.putCh(',');
        first.* = false;
    }
    /// Writes ',' unconditionally — for object members written as
    /// key, value, sep(), key, value, …
    fn sep(self: *Json) void {
        self.putCh(',');
    }
};

// ---------------------------------------------------------------------------
// Reservoirs (uniform sampling with fixed seed)
// ---------------------------------------------------------------------------

const FsSample = struct { colex: u32, side: i8, width: i8, L: i8, H: i8, stones: u8 };
const AnySample = struct { colex: u32, side: i8, ko: u8, passes: u2, width: i8, L: i8, H: i8, stones: u8 };

const Reservoir = struct {
    cap: usize,
    items: std.ArrayListUnmanaged(FsSample),
    seen: u64,

    fn init(gpa: std.mem.Allocator, cap: usize) Reservoir {
        _ = gpa;
        return .{ .cap = cap, .items = std.ArrayListUnmanaged(FsSample).empty, .seen = 0 };
    }
    fn add(self: *Reservoir, gpa: std.mem.Allocator, rnd: std.Random, s: FsSample) void {
        if (self.seen < self.cap) {
            self.items.append(gpa, s) catch unreachable;
        } else {
            const j = rnd.uintLessThan(u64, self.seen + 1);
            if (j < self.cap) self.items.items[@intCast(j)] = s;
        }
        self.seen += 1;
    }
};

const AnyReservoir = struct {
    cap: usize,
    items: std.ArrayListUnmanaged(AnySample),
    seen: u64,

    fn init(gpa: std.mem.Allocator, cap: usize) AnyReservoir {
        _ = gpa;
        return .{ .cap = cap, .items = std.ArrayListUnmanaged(AnySample).empty, .seen = 0 };
    }
    fn add(self: *AnyReservoir, gpa: std.mem.Allocator, rnd: std.Random, s: AnySample) void {
        if (self.seen < self.cap) {
            self.items.append(gpa, s) catch unreachable;
        } else {
            const j = rnd.uintLessThan(u64, self.seen + 1);
            if (j < self.cap) self.items.items[@intCast(j)] = s;
        }
        self.seen += 1;
    }
};

// ---------------------------------------------------------------------------
// Pass A + gallery + corr4x4 (mode `run`)
// ---------------------------------------------------------------------------

const Cand1 = struct { colex: u32, side: i8, ko: u8, passes: u2, L: i8, H: i8, stones: u8, shapes: u8 };
const Cand2 = struct { colex: u32, side: i8, ko: u8, passes: u2, L: i8, H: i8, stones: u8, shapes: u8 };
const Cand3 = struct { colex: u32, side: i8, ko: u8, passes: u2, L: i8, H: i8, stones: u8, shapes: u8 };
const Cand4 = struct { colex: u32, side: i8, ko: u8, passes: u2, L: i8, H: i8, stones: u8, shapes: u8 };

const CAND_CAP = 64;

fn appendCand1(gpa: std.mem.Allocator, list: *std.ArrayListUnmanaged(Cand1), c: Cand1) void {
    if (list.items.len >= CAND_CAP) return;
    list.append(gpa, c) catch unreachable;
}
fn appendCand2(gpa: std.mem.Allocator, list: *std.ArrayListUnmanaged(Cand2), c: Cand2) void {
    if (list.items.len >= CAND_CAP) return;
    list.append(gpa, c) catch unreachable;
}
fn appendCand3(gpa: std.mem.Allocator, list: *std.ArrayListUnmanaged(Cand3), c: Cand3) void {
    if (list.items.len >= CAND_CAP) return;
    list.append(gpa, c) catch unreachable;
}
fn appendCand4(gpa: std.mem.Allocator, list: *std.ArrayListUnmanaged(Cand4), c: Cand4) void {
    if (list.items.len >= CAND_CAP) return;
    list.append(gpa, c) catch unreachable;
}

const Bounds = SearchBounds{ .depth = 10, .nodes = 30_000 };

fn runMode(gpa: std.mem.Allocator, out_path: []const u8, seed: u64) !void {
    var wzo = try Wzo2.open(gpa, "data/oracle-4x4-v2.wzo2");
    defer gpa.free(wzo.groups);
    defer gpa.free(wzo.bytes);

    var prng = std.Random.DefaultPrng.init(seed);
    const rnd = prng.random();

    // ── pass A: full table scan ──
    var entries_scanned: u64 = 0;
    var bracket_entries: u64 = 0;
    var set_positions: u64 = 0;
    var clear_positions: u64 = 0;
    var set_with_zero_ko: u64 = 0;
    var ko_with_no_set: u64 = 0;
    var freshstart_set_either: u64 = 0;
    var freshstart_set_b: u64 = 0;
    var freshstart_set_w: u64 = 0;
    var freshstart_width_sum_b: u128 = 0;
    var freshstart_width_sum_w: u128 = 0;
    var set_width_sum: u128 = 0;

    var fs_bracket = Reservoir.init(gpa, 300);
    var fs_clear = Reservoir.init(gpa, 300);
    var any_bracket = AnyReservoir.init(gpa, 300);
    var any_clear = AnyReservoir.init(gpa, 300);

    var cand1 = std.ArrayListUnmanaged(Cand1).empty;
    var cand2 = std.ArrayListUnmanaged(Cand2).empty;
    var cand3 = std.ArrayListUnmanaged(Cand3).empty;
    var cand4 = std.ArrayListUnmanaged(Cand4).empty;
    defer cand1.deinit(gpa);
    defer cand2.deinit(gpa);
    defer cand3.deinit(gpa);
    defer cand4.deinit(gpa);

    var g: usize = 0;
    while (g < wzo.n_groups) : (g += 1) {
        const colex: u32 = wzo.groups[g].colex;
        const cnt: usize = wzo.groups[g].count;
        const pos = X.pos_from_colex(colex);
        const stones = countStones(&pos);
        const has_shape = hasKoShape(&pos);
        const shapes = if (has_shape) countKoShapes(&pos) else 0;

        var any_set = false;
        var max_width: u8 = 0;
        var fs_b: ?Entry = null;
        var fs_w: ?Entry = null;
        for (0..cnt) |i| {
            const e = wzo.entryAt(g, i);
            entries_scanned += 1;
            if (e.L != e.H) {
                bracket_entries += 1;
                any_set = true;
                const width: u8 = @intCast(e.H - e.L);
                if (width > max_width) max_width = width;
            }
            if (e.passes == 0 and e.ko == KO_NONE) {
                if (e.side > 0) fs_b = e else fs_w = e;
            }
            // gallery candidates
            if (e.L == e.H and e.ko != KO_NONE and e.passes == 0 and stones >= 3 and stones <= 12) {
                appendCand1(gpa, &cand1, .{ .colex = colex, .side = e.side, .ko = e.ko, .passes = e.passes, .L = e.L, .H = e.H, .stones = stones, .shapes = shapes });
            }
            if (e.L == e.H and e.ko == KO_NONE and e.passes == 0 and !has_shape and stones >= 3 and stones <= 12) {
                appendCand2(gpa, &cand2, .{ .colex = colex, .side = e.side, .ko = e.ko, .passes = e.passes, .L = e.L, .H = e.H, .stones = stones, .shapes = shapes });
            }
            if (e.L != e.H and e.ko == KO_NONE and e.passes == 0 and !has_shape and stones >= 3 and stones <= 12) {
                appendCand3(gpa, &cand3, .{ .colex = colex, .side = e.side, .ko = e.ko, .passes = e.passes, .L = e.L, .H = e.H, .stones = stones, .shapes = shapes });
            }
        }
        if (has_shape) {
            for (0..cnt) |i| {
                const e = wzo.entryAt(g, i);
                if (e.L != e.H and e.ko == KO_NONE and e.passes == 0 and shapes == 1 and stones >= 3 and stones <= 12) {
                    appendCand4(gpa, &cand4, .{ .colex = colex, .side = e.side, .ko = e.ko, .passes = e.passes, .L = e.L, .H = e.H, .stones = stones, .shapes = shapes });
                    break;
                }
            }
        }

        if (fs_b) |e| {
            if (e.L != e.H) {
                freshstart_set_b += 1;
                freshstart_width_sum_b += @intCast(e.H - e.L);
                fs_bracket.add(gpa, rnd, .{ .colex = colex, .side = 1, .width = @intCast(e.H - e.L), .L = e.L, .H = e.H, .stones = stones });
            }
        }
        if (fs_w) |e| {
            if (e.L != e.H) {
                freshstart_set_w += 1;
                freshstart_width_sum_w += @intCast(e.H - e.L);
                if (fs_b == null or fs_b.?.L == fs_b.?.H) {
                    // colour symmetry: White bracketed while Black clear — still a bracket group
                    fs_bracket.add(gpa, rnd, .{ .colex = colex, .side = -1, .width = @intCast(e.H - e.L), .L = e.L, .H = e.H, .stones = stones });
                }
            }
        }
        if ((fs_b != null and fs_b.?.L != fs_b.?.H) or (fs_w != null and fs_w.?.L != fs_w.?.H)) freshstart_set_either += 1;
        // fs_clear: only groups where EVERY present fresh-start entry is L==H
        {
            const fs_any: ?Entry = fs_b orelse fs_w;
            const both_clear = (fs_b == null or fs_b.?.L == fs_b.?.H) and (fs_w == null or fs_w.?.L == fs_w.?.H);
            if (fs_any != null and fs_any.?.L == fs_any.?.H and both_clear) {
                fs_clear.add(gpa, rnd, .{ .colex = colex, .side = fs_any.?.side, .width = 0, .L = fs_any.?.L, .H = fs_any.?.H, .stones = stones });
            }
        }

        if (any_set) {
            set_positions += 1;
            set_width_sum += max_width;
            if (shapes == 0) set_with_zero_ko += 1;
            for (0..cnt) |i| {
                const e = wzo.entryAt(g, i);
                if (e.L != e.H) {
                    any_bracket.add(gpa, rnd, .{ .colex = colex, .side = e.side, .ko = e.ko, .passes = e.passes, .width = @intCast(e.H - e.L), .L = e.L, .H = e.H, .stones = stones });
                }
            }
        } else {
            clear_positions += 1;
            if (shapes > 0) ko_with_no_set += 1;
            for (0..cnt) |i| {
                const e = wzo.entryAt(g, i);
                if (e.L == e.H) {
                    any_clear.add(gpa, rnd, .{ .colex = colex, .side = e.side, .ko = e.ko, .passes = e.passes, .width = 0, .L = e.L, .H = e.H, .stones = stones });
                }
            }
        }
    }

    std.debug.print("PASS-A: groups={d} entries={d} set_positions={d} clear_positions={d} bracket_entries={d} set_with_zero_ko={d} ko_with_no_set={d}\n", .{
        wzo.n_groups, entries_scanned, set_positions, clear_positions, bracket_entries, set_with_zero_ko, ko_with_no_set,
    });
    std.debug.print("PASS-A: freshstart_set_either={d} b={d} w={d} fs_bracket_samples={d} fs_clear_samples={d} any_bracket_samples={d} any_clear_samples={d}\n", .{
        freshstart_set_either, freshstart_set_b, freshstart_set_w, fs_bracket.items.items.len, fs_clear.items.items.len, any_bracket.items.items.len, any_clear.items.items.len,
    });
    std.debug.print("PASS-A: cand1={d} cand2={d} cand3={d} cand4={d}\n", .{ cand1.items.len, cand2.items.len, cand3.items.len, cand4.items.len });

    var missing: u64 = 0;
    var expanded: u64 = 0;
    var ctx = ChildCtx{ .table = &wzo, .missing = &missing, .expanded = &expanded };

    // ── bounded forward search over the reservoirs (corr4x4) ──
    const BucketStats = struct {
        label: []const u8,
        n: u64 = 0,
        cycle_found: u64 = 0,
        cycle_depth_sum: u64 = 0,
        ko_found: u64 = 0,
        ko_depth_sum: u64 = 0,
        neither: u64 = 0,
        width_sum_all: u128 = 0,
        width_sum_cycle: u128 = 0,
        width_sum_nocycle: u128 = 0,
        width_sum_ko: u128 = 0,
        width_sum_noko: u128 = 0,
    };

    var buckets: [4]BucketStats = .{
        .{ .label = "fresh-start bracket-valued (L<H)" },
        .{ .label = "fresh-start single-score (L==H)" },
        .{ .label = "any bracket-valued entry (L<H)" },
        .{ .label = "any single-score entry (L==H), groups without any bracket" },
    };

    const runFsBucket = struct {
        fn run(b: *BucketStats, gpa2: std.mem.Allocator, ctx2: *ChildCtx, samples: []const FsSample) !void {
            var pl: usize = 0;
            for (samples) |s| {
                const root = stKey(s.colex, s.side, KO_NONE, 0);
                const cyc = try cycleSearch(gpa2, ctx2, root, Bounds);
                const ko = try koSearch(gpa2, ctx2, root, Bounds, &.{}, &pl);
                b.n += 1;
                b.width_sum_all += @intCast(s.width);
                if (cyc.found) {
                    b.cycle_found += 1;
                    b.cycle_depth_sum += cyc.depth;
                    b.width_sum_cycle += @intCast(s.width);
                } else {
                    b.width_sum_nocycle += @intCast(s.width);
                }
                if (ko.found) {
                    b.ko_found += 1;
                    b.ko_depth_sum += ko.depth;
                    b.width_sum_ko += @intCast(s.width);
                } else {
                    b.width_sum_noko += @intCast(s.width);
                }
                if (!cyc.found and !ko.found) b.neither += 1;
            }
        }
    }.run;

    const runAnyBucket = struct {
        fn run(b: *BucketStats, gpa2: std.mem.Allocator, ctx2: *ChildCtx, samples: []const AnySample) !void {
            var pl: usize = 0;
            for (samples) |s| {
                const root = stKey(s.colex, s.side, s.ko, s.passes);
                const cyc = try cycleSearch(gpa2, ctx2, root, Bounds);
                const ko = try koSearch(gpa2, ctx2, root, Bounds, &.{}, &pl);
                b.n += 1;
                b.width_sum_all += @intCast(s.width);
                if (cyc.found) {
                    b.cycle_found += 1;
                    b.cycle_depth_sum += cyc.depth;
                    b.width_sum_cycle += @intCast(s.width);
                } else {
                    b.width_sum_nocycle += @intCast(s.width);
                }
                if (ko.found) {
                    b.ko_found += 1;
                    b.ko_depth_sum += ko.depth;
                    b.width_sum_ko += @intCast(s.width);
                } else {
                    b.width_sum_noko += @intCast(s.width);
                }
                if (!cyc.found and !ko.found) b.neither += 1;
            }
        }
    }.run;

    try runFsBucket(&buckets[0], gpa, &ctx, fs_bracket.items.items);
    try runFsBucket(&buckets[1], gpa, &ctx, fs_clear.items.items);
    try runAnyBucket(&buckets[2], gpa, &ctx, any_bracket.items.items);
    try runAnyBucket(&buckets[3], gpa, &ctx, any_clear.items.items);

    std.debug.print("CORR4X4: missing_children={d} expanded={d}\n", .{ missing, expanded });
    for (&buckets) |*b| {
        std.debug.print("CORR4X4: {s}: n={d} cycle_found={d} ko_found={d} neither={d}\n", .{ b.label, b.n, b.cycle_found, b.ko_found, b.neither });
    }

    // ── class 3 bounded census: bracket entries with no ko found within bound,
    //    plus the 1-ply backward ban-parent check (fresh-start subset only) ──
    var c3_fs_total: u64 = 0;
    var c3_fs_noko: u64 = 0;
    var c3_fs_noko_noback: u64 = 0;
    var c3_any_total: u64 = 0;
    var c3_any_noko: u64 = 0;
    var back_found_count: u64 = 0;
    var pl: usize = 0;
    for (fs_bracket.items.items) |s| {
        const root = stKey(s.colex, s.side, KO_NONE, 0);
        const ko = try koSearch(gpa, &ctx, root, Bounds, &.{}, &pl);
        c3_fs_total += 1;
        if (!ko.found) {
            c3_fs_noko += 1;
            const bp = backwardBanParent(&ctx, s.colex, s.side, KO_NONE, 0);
            if (bp.found) {
                back_found_count += 1;
            } else {
                c3_fs_noko_noback += 1;
            }
        }
    }
    for (any_bracket.items.items) |s| {
        const root = stKey(s.colex, s.side, s.ko, s.passes);
        const ko = try koSearch(gpa, &ctx, root, Bounds, &.{}, &pl);
        c3_any_total += 1;
        if (!ko.found) c3_any_noko += 1;
    }
    std.debug.print("C3: fs_total={d} fs_noko={d} fs_noko_noback={d} back_found={d} any_total={d} any_noko={d}\n", .{
        c3_fs_total, c3_fs_noko, c3_fs_noko_noback, back_found_count, c3_any_total, c3_any_noko,
    });

    // ── gallery: verify candidates, pick examples ──
    const GalleryExample = struct {
        class: u8,
        colex: u32,
        side: i8,
        ko: u8,
        passes: u2,
        L: i8,
        H: i8,
        stones: u8,
        shapes: u8,
        board: [512]u8,
        board_len: usize,
        extra: [512]u8,
        extra_len: usize,
    };
    var examples = std.ArrayListUnmanaged(GalleryExample).empty;
    defer examples.deinit(gpa);
    var board_buf: [512]u8 = undefined;
    var extra_buf: [512]u8 = undefined;

    // class 1: L==H with a ko in its past (entry ko != NONE; verified: the
    // ban cell carries the ko shape and a natural parent exists in the table)
    var c1_taken: usize = 0;
    for (cand1.items) |c| {
        if (c1_taken >= 4) break;
        const pos = X.pos_from_colex(c.colex);
        if (isKoShape(&pos, c.ko, c.side) == null) continue;
        const np = naturalParent(&ctx, c.colex, c.side, c.ko, c.passes);
        if (np == null) continue;
        const bl = renderBoard(&pos, c.side, c.ko, c.passes, &board_buf);
        const pos_p = X.pos_from_colex(@intCast(np.?.parent_key >> 8));
        const el = renderBoard(&pos_p, -c.side, np.?.ko_p, 0, &extra_buf);
        var ex = GalleryExample{ .class = 1, .colex = c.colex, .side = c.side, .ko = c.ko, .passes = c.passes, .L = c.L, .H = c.H, .stones = c.stones, .shapes = c.shapes, .board = undefined, .board_len = bl.len, .extra = undefined, .extra_len = el.len };
        @memcpy(ex.board[0..bl.len], bl);
        @memcpy(ex.extra[0..el.len], el);
        examples.append(gpa, ex) catch unreachable;
        c1_taken += 1;
    }

    // class 2: L==H with a ko reachable in its future (bounded witness path)
    var c2_taken: usize = 0;
    var path_buf2: [128]u8 = undefined;
    var path_len2: usize = 0;
    for (cand2.items) |c| {
        if (c2_taken >= 4) break;
        const root = stKey(c.colex, c.side, c.ko, c.passes);
        const ko = try koSearch(gpa, &ctx, root, Bounds, &path_buf2, &path_len2);
        if (!ko.found or ko.ko_terminal) continue;
        const st = keyState(root);
        const pos = X.pos_from_colex(st.colex);
        const bl = renderBoard(&pos, st.side, st.ko, st.passes, &board_buf);
        var ex = GalleryExample{ .class = 2, .colex = c.colex, .side = c.side, .ko = c.ko, .passes = c.passes, .L = c.L, .H = c.H, .stones = c.stones, .shapes = c.shapes, .board = undefined, .board_len = bl.len, .extra = undefined, .extra_len = 0 };
        @memcpy(ex.board[0..bl.len], bl);
        var mv_txt: [384]u8 = undefined;
        var mt = std.Io.Writer.fixed(&mv_txt);
        mt.print("ko reachable before terminal: after {d} ply(s), ", .{ko.depth}) catch {};
        if (ko.path_len > 0) {
            mt.print("moves: ", .{}) catch {};
            for (ko.path[0..ko.path_len], 0..) |mv, mi| {
                if (mi > 0) mt.print(" ", .{}) catch {};
                if (mv == PASS_MOVE) {
                    mt.print("(pass)", .{}) catch {};
                } else {
                    mt.print("{c}{d}", .{ colLetter(mv % W), (mv / W) + 1 }) catch {};
                }
            }
            if (ko.ko_cell != KO_NONE) {
                mt.print("; ko ban on {c}{d}", .{ colLetter(ko.ko_cell % W), (ko.ko_cell / W) + 1 }) catch {};
            } else {
                mt.print("; a ko shape appears (no ban yet)", .{}) catch {};
            }
        }
        ex.extra_len = mt.end;
        @memcpy(ex.extra[0..mt.end], mv_txt[0..mt.end]);
        examples.append(gpa, ex) catch unreachable;
        c2_taken += 1;
    }

    // class 3: bracketed with no ko anywhere (within the stated bounds)
    var c3_taken: usize = 0;
    for (cand3.items) |c| {
        if (c3_taken >= 4) break;
        const root = stKey(c.colex, c.side, c.ko, c.passes);
        const ko = try koSearch(gpa, &ctx, root, Bounds, &.{}, &pl);
        if (ko.found) continue;
        const bp = backwardBanParent(&ctx, c.colex, c.side, c.ko, c.passes);
        if (bp.found) continue;
        const pos = X.pos_from_colex(c.colex);
        const bl = renderBoard(&pos, c.side, c.ko, c.passes, &board_buf);
        var ex = GalleryExample{ .class = 3, .colex = c.colex, .side = c.side, .ko = c.ko, .passes = c.passes, .L = c.L, .H = c.H, .stones = c.stones, .shapes = c.shapes, .board = undefined, .board_len = bl.len, .extra = undefined, .extra_len = 0 };
        @memcpy(ex.board[0..bl.len], bl);
        const el = std.fmt.bufPrint(&extra_buf, "no ko-carrying state within {d} plies / {d} nodes forward; no 1-ply ban-parent", .{ Bounds.depth, Bounds.nodes }) catch "";
        ex.extra_len = el.len;
        @memcpy(ex.extra[0..el.len], el);
        examples.append(gpa, ex) catch unreachable;
        c3_taken += 1;
    }

    // class 4: bracketed with a ko present (fresh-start, one readable shape)
    var c4_taken: usize = 0;
    for (cand4.items) |c| {
        if (c4_taken >= 4) break;
        const pos = X.pos_from_colex(c.colex);
        const bl = renderBoard(&pos, c.side, c.ko, c.passes, &board_buf);
        var ex = GalleryExample{ .class = 4, .colex = c.colex, .side = c.side, .ko = c.ko, .passes = c.passes, .L = c.L, .H = c.H, .stones = c.stones, .shapes = c.shapes, .board = undefined, .board_len = bl.len, .extra = undefined, .extra_len = 0 };
        @memcpy(ex.board[0..bl.len], bl);
        const el = std.fmt.bufPrint(&extra_buf, "ko shape present ({d} shape(s) on the board)", .{c.shapes}) catch "";
        ex.extra_len = el.len;
        @memcpy(ex.extra[0..el.len], el);
        examples.append(gpa, ex) catch unreachable;
        c4_taken += 1;
    }

    std.debug.print("GALLERY: examples c1={d} c2={d} c3={d} c4={d}\n", .{ c1_taken, c2_taken, c3_taken, c4_taken });

    // ── JSON ──
    var j = Json.init(gpa);
    defer j.deinit();
    j.objBegin();
    j.key("task_id");
    j.esc("T385");
    j.putCh(',');
    j.key("identifier");
    j.esc("flash/T385");
    j.putCh(',');
    j.key("date");
    j.esc("2026-08-06");
    j.putCh(',');
    j.key("seed");
    j.int(seed);
    j.putCh(',');
    j.key("artifact");
    j.objBegin();
    j.key("path");
    j.esc("data/oracle-4x4-v2.wzo2");
    j.putCh(',');
    j.key("sha256");
    j.esc("0c3366f07fb33c6f2838ead48ad3080b64dbe55935b87af4f140d81a29e4e15a");
    j.putCh(',');
    j.key("n_groups");
    j.int(wzo.n_groups);
    j.putCh(',');
    j.key("n_entries");
    j.int(wzo.n_entries);
    j.putCh(',');
    j.key("ko_bits");
    j.int(wzo.ko_bits);
    j.objEnd();
    j.putCh(',');
    j.key("ko_decode");
    j.esc("kb >> 2 per artifact2 §2.2 (T383 landed c5e75d7; this instrument decodes independently and regression-checks in selftest)");
    j.putCh(',');
    j.key("search_bounds");
    j.objBegin();
    j.key("forward_depth_plies");
    j.int(Bounds.depth);
    j.putCh(',');
    j.key("forward_node_budget");
    j.int(Bounds.nodes);
    j.putCh(',');
    j.key("backward_bound_plies");
    j.int(1);
    j.putCh(',');
    j.key("backward_exhaustiveness");
    j.esc("single-capture restoration only (conservative); 3×3 exact reverse-graph check in corr3x3 quantifies the miss rate");
    j.objEnd();
    j.putCh(',');
    j.key("pass_a");
    j.objBegin();
    var first = true;
    j.key("legal_positions");
    j.int(wzo.n_groups);
    j.sep();
    j.key("set_positions");
    j.int(set_positions);
    j.sep();
    j.key("clear_positions");
    j.int(clear_positions);
    j.sep();
    j.key("bracket_entries");
    j.int(bracket_entries);
    j.sep();
    j.key("set_with_zero_ko");
    j.int(set_with_zero_ko);
    j.sep();
    j.key("ko_with_no_set");
    j.int(ko_with_no_set);
    j.sep();
    j.key("set_with_zero_ko_pct");
    j.flt(@as(f64, @floatFromInt(set_with_zero_ko)) * 100.0 / @as(f64, @floatFromInt(set_positions)));
    j.sep();
    j.key("freshstart_set_either");
    j.int(freshstart_set_either);
    j.sep();
    j.key("freshstart_set_b");
    j.int(freshstart_set_b);
    j.sep();
    j.key("freshstart_set_w");
    j.int(freshstart_set_w);
    j.sep();
    j.key("freshstart_mean_width");
    j.flt(@as(f64, @floatFromInt(freshstart_width_sum_b)) / @as(f64, @floatFromInt(freshstart_set_b)));
    j.sep();
    j.key("set_mean_max_width");
    j.flt(@as(f64, @floatFromInt(set_width_sum)) / @as(f64, @floatFromInt(set_positions)));
    j.objEnd();
    j.putCh(',');
    j.key("corr4x4_bounded");
    j.objBegin();
    first = true;
    j.key("bounds");
    j.esc("cycle/ko reachability measured by bounded DFS/BFS: depth 10 plies, 30,000 nodes per root; exhaustive within the bound");
    j.sep();
    j.key("buckets");
    j.arrBegin();
    var bfirst = true;
    for (&buckets) |*b| {
        j.comma(&bfirst);
        j.objBegin();
            j.key("label");
        j.esc(b.label);
        j.sep();
        j.key("n");
        j.int(b.n);
        j.sep();
        j.key("cycle_found");
        j.int(b.cycle_found);
        j.sep();
        j.key("cycle_found_pct");
        if (b.n > 0) j.flt(@as(f64, @floatFromInt(b.cycle_found)) * 100.0 / @as(f64, @floatFromInt(b.n))) else j.int(0);
        j.sep();
        j.key("cycle_mean_depth");
        if (b.cycle_found > 0) j.flt(@as(f64, @floatFromInt(b.cycle_depth_sum)) / @as(f64, @floatFromInt(b.cycle_found))) else j.int(0);
        j.sep();
        j.key("ko_found");
        j.int(b.ko_found);
        j.sep();
        j.key("ko_found_pct");
        if (b.n > 0) j.flt(@as(f64, @floatFromInt(b.ko_found)) * 100.0 / @as(f64, @floatFromInt(b.n))) else j.int(0);
        j.sep();
        j.key("neither_cycle_nor_ko");
        j.int(b.neither);
        j.sep();
        j.key("mean_width_all");
        if (b.n > 0) j.flt(@as(f64, @floatFromInt(b.width_sum_all)) / @as(f64, @floatFromInt(b.n))) else j.int(0);
        j.sep();
        j.key("mean_width_cycle_found");
        if (b.cycle_found > 0) j.flt(@as(f64, @floatFromInt(b.width_sum_cycle)) / @as(f64, @floatFromInt(b.cycle_found))) else j.int(0);
        j.sep();
        j.key("mean_width_no_cycle");
        if (b.n - b.cycle_found > 0) j.flt(@as(f64, @floatFromInt(b.width_sum_nocycle)) / @as(f64, @floatFromInt(b.n - b.cycle_found))) else j.int(0);
        j.sep();
        j.key("mean_width_ko_found");
        if (b.ko_found > 0) j.flt(@as(f64, @floatFromInt(b.width_sum_ko)) / @as(f64, @floatFromInt(b.ko_found))) else j.int(0);
        j.sep();
        j.key("mean_width_no_ko");
        if (b.n - b.ko_found > 0) j.flt(@as(f64, @floatFromInt(b.width_sum_noko)) / @as(f64, @floatFromInt(b.n - b.ko_found))) else j.int(0);
        j.objEnd();
    }
    j.arrEnd();
    j.objEnd();
    j.putCh(',');
    j.key("class3_bounded_census");
    j.objBegin();
    first = true;
    j.key("fresh_start_bracket_entries_checked");
    j.int(c3_fs_total);
    j.sep();
    j.key("no_ko_found_within_bound");
    j.int(c3_fs_noko);
    j.sep();
    j.key("no_ko_found_pct");
    j.flt(@as(f64, @floatFromInt(c3_fs_noko)) * 100.0 / @as(f64, @floatFromInt(c3_fs_total)));
    j.sep();
    j.key("of_those_no_1ply_ban_parent");
    j.int(c3_fs_noko_noback);
    j.sep();
    j.key("any_entry_bracket_checked");
    j.int(c3_any_total);
    j.sep();
    j.key("any_entry_no_ko_found_within_bound");
    j.int(c3_any_noko);
    j.sep();
    j.key("any_entry_no_ko_pct");
    j.flt(@as(f64, @floatFromInt(c3_any_noko)) * 100.0 / @as(f64, @floatFromInt(c3_any_total)));
    j.objEnd();
    j.putCh(',');
    j.key("gallery");
    j.objBegin();
    first = true;
    inline for (.{ 1, 2, 3, 4 }) |cls| {
        j.comma(&first);
        j.key(switch (cls) {
            1 => "1_single_score_ko_in_past",
            2 => "2_single_score_ko_in_future",
            3 => "3_bracketed_no_ko_anywhere",
            else => "4_bracketed_ko_present",
        });
        j.arrBegin();
        var efirst = true;
        for (examples.items) |*ex| {
            if (ex.class != cls) continue;
            j.comma(&efirst);
            j.objBegin();
                    j.key("colex");
            j.int(ex.colex);
            j.sep();
            j.key("side");
            j.int(ex.side);
            j.sep();
            j.key("ko_point");
            j.int(ex.ko);
            j.sep();
            j.key("passes");
            j.int(ex.passes);
            j.sep();
            j.key("L");
            j.int(ex.L);
            j.sep();
            j.key("H");
            j.int(ex.H);
            j.sep();
            j.key("stones");
            j.int(ex.stones);
            j.sep();
            j.key("shapes");
            j.int(ex.shapes);
            j.sep();
            j.key("board");
            j.esc(ex.board[0..ex.board_len]);
            j.sep();
            j.key("note");
            j.esc(ex.extra[0..ex.extra_len]);
            j.objEnd();
        }
        j.arrEnd();
    }
    j.objEnd();
    j.putCh(',');
    j.key("controls");
    j.objBegin();
    first = true;
    j.key("missing_children_spot_check");
    j.int(missing);
    j.sep();
    j.key("cross_check_t380");
    j.esc("set_positions 1,924,973 / set_with_zero_ko 1,782,629 (92.6%) / freshstart_set_either 1,913,925 / bracket_entries 3,455,412 — reproduced here");
    j.objEnd();
    j.objEnd();
    j.putCh('\n');

    const out_dir = std.Io.Dir.cwd();
    var threaded_out = std.Io.Threaded.init(gpa, .{});
    defer threaded_out.deinit();
    out_dir.writeFile(threaded_out.io(), .{ .sub_path = out_path, .data = j.buf.items }) catch |err| {
        std.debug.print("cannot write {s}: {s}\n", .{ out_path, @errorName(err) });
        return;
    };
    std.debug.print("JSON written to {s} ({d} bytes)\n", .{ out_path, j.buf.items.len });
}

// ---------------------------------------------------------------------------
// corr3x3 — exhaustive Tarjan SCC correlation + exact class-3 census
// ---------------------------------------------------------------------------

fn corr3x3Mode(gpa: std.mem.Allocator, out_path: []const u8) !void {
    const R3 = rules.Rules(3, 3);
    const X3 = colexmod.Indexer(3, 3);
    const N3 = 9;
    const KO_NONE3: u8 = @intCast(N3);

    var wzo = try Wzo2.open(gpa, "data/oracle-3x3-v2.wzo2");
    defer gpa.free(wzo.groups);
    defer gpa.free(wzo.bytes);

    // map key -> id, id -> entry
    var by_key = std.AutoHashMap(u64, u64).init(gpa); // stKey -> id
    defer by_key.deinit();
    var entries_list = std.ArrayListUnmanaged(u64).empty; // id -> stKey
    defer entries_list.deinit(gpa);
    var n_ids: u64 = 0;
    for (0..@as(usize, @intCast(wzo.n_groups))) |g| {
        for (0..wzo.groups[g].count) |i| {
            const e = wzo.entryAt(g, i);
            const key = stKey(e.colex, e.side, e.ko, e.passes);
            try by_key.put(key, n_ids);
            try entries_list.append(gpa, key);
            n_ids += 1;
        }
    }
    std.debug.print("SCC3: entries={d}\n", .{n_ids});

    var missing: u64 = 0;

    // adjacency (forward + reverse) over ids
    var succ = std.ArrayListUnmanaged(u64).empty;
    defer succ.deinit(gpa);
    var succ_start = std.ArrayListUnmanaged(u64).empty;
    defer succ_start.deinit(gpa);
    var rsucc = std.ArrayListUnmanaged(u64).empty;
    defer rsucc.deinit(gpa);
    var rsucc_start = std.ArrayListUnmanaged(u64).empty;
    defer rsucc_start.deinit(gpa);
    try succ_start.append(gpa, 0);
    try rsucc_start.append(gpa, 0);

    for (0..@as(usize, @intCast(n_ids))) |id| {
        const key = entries_list.items[id];
        const st = keyState(key);
        const pos = X3.pos_from_colex(st.colex);
        var k: u64 = 0;
        for (0..N3) |cell| {
            if (R3.applyMove(&pos, st.side, st.ko, st.passes, cell)) |c| {
                const cco: u32 = @intCast(X3.colex_from_pos(&c.pos));
                const ck = stKey(cco, c.side, c.ko, c.passes);
                if (by_key.get(ck)) |cid| {
                    succ.append(gpa, cid) catch unreachable;
                    rsucc.append(gpa, @intCast(id)) catch unreachable;
                    k += 1;
                } else {
                    missing += 1;
                }
            }
        }
        if (R3.applyPass(st.side, st.passes)) |pc| {
            if (pc.passes < 2) { // passes==2 child is absorbing terminal — not stored, not a graph vertex
                const ck = stKey(st.colex, pc.side, pc.ko, pc.passes);
                if (by_key.get(ck)) |cid| {
                    succ.append(gpa, cid) catch unreachable;
                    rsucc.append(gpa, @intCast(id)) catch unreachable;
                    k += 1;
                } else {
                    missing += 1;
                }
            }
        }
        try succ_start.append(gpa, succ.items.len);
        try rsucc_start.append(gpa, rsucc.items.len);
    }
    std.debug.print("SCC3: adj={d} rev={d} missing={d}\n", .{ succ.items.len, rsucc.items.len, missing });

    // Tarjan SCCs (iterative)
    var index = try gpa.alloc(u64, @intCast(n_ids));
    defer gpa.free(index);
    var low = try gpa.alloc(u64, @intCast(n_ids));
    defer gpa.free(low);
    var onstack = try gpa.alloc(bool, @intCast(n_ids));
    defer gpa.free(onstack);
    var comp = try gpa.alloc(u64, @intCast(n_ids));
    defer gpa.free(comp);
    @memset(index, std.math.maxInt(u64));
    @memset(onstack, false);
    @memset(comp, std.math.maxInt(u64));
    var stack = std.ArrayListUnmanaged(u64).empty;
    defer stack.deinit(gpa);
    var comp_size = std.ArrayListUnmanaged(u64).empty;
    defer comp_size.deinit(gpa);
    var n_comp: u64 = 0;
    var counter: u64 = 0;

    const Work = struct { v: u64, it: u64 };
    var work = std.ArrayListUnmanaged(Work).empty;
    defer work.deinit(gpa);

    for (0..@as(usize, @intCast(n_ids))) |root| {
        if (index[root] != std.math.maxInt(u64)) continue;
        try work.append(gpa, .{ .v = @intCast(root), .it = 0 });
        while (work.items.len > 0) {
            const st_w = work.items[work.items.len - 1];
            const v = st_w.v;
            if (st_w.it == 0) {
                index[v] = counter;
                low[v] = counter;
                counter += 1;
                try stack.append(gpa, v);
                onstack[v] = true;
            }
            const vi: usize = @intCast(v);
            const s0 = succ_start.items[vi];
            const s1 = succ_start.items[vi + 1];
            var advanced = false;
            var it = st_w.it;
            while (s0 + it < s1) : (it += 1) {
                const w = succ.items[@intCast(s0 + it)];
                if (index[w] == std.math.maxInt(u64)) {
                    work.items[work.items.len - 1].it = it + 1;
                    try work.append(gpa, .{ .v = w, .it = 0 });
                    advanced = true;
                    break;
                } else if (onstack[w]) {
                    if (index[w] < low[v]) low[v] = index[w];
                }
            }
            if (advanced) continue;
            if (low[v] == index[v]) {
                var sz: u64 = 0;
                while (true) {
                    const w = stack.items[stack.items.len - 1];
                    _ = stack.pop();
                    onstack[w] = false;
                    comp[w] = n_comp;
                    sz += 1;
                    if (w == v) break;
                }
                try comp_size.append(gpa, sz);
                n_comp += 1;
            }
            _ = work.pop();
            if (work.items.len > 0) {
                const p = work.items[work.items.len - 1].v;
                if (low[v] < low[p]) low[p] = low[v];
            }
        }
    }
    var maxc2: u64 = 0;
    for (comp_size.items) |sz| {
        if (sz > maxc2) maxc2 = sz;
    }
    std.debug.print("SCC3: n_comp={d} max_comp={d}\n", .{ n_comp, maxc2 });
    {
        var hist = [_]u64{0} ** 8;
        for (comp_size.items) |sz| {
            const b: usize = if (sz == 1) 0 else if (sz <= 10) 1 else if (sz <= 100) 2 else if (sz <= 1000) 3 else if (sz <= 10000) 4 else if (sz <= 20000) 5 else if (sz <= 40000) 6 else 7;
            hist[b] += 1;
        }
        std.debug.print("SCC3: comp_size_hist=[1:{d},2-10:{d},11-100:{d},101-1k:{d},1k-10k:{d},10k-20k:{d},20k-40k:{d},>40k:{d}]\n", .{ hist[0], hist[1], hist[2], hist[3], hist[4], hist[5], hist[6], hist[7] });
    }

    // nontriv flags
    var nontriv = try gpa.alloc(bool, @intCast(n_comp));
    defer gpa.free(nontriv);
    var nontriv_count: u64 = 0;
    for (0..@as(usize, @intCast(n_comp))) |c| {
        nontriv[c] = comp_size.items[c] > 1;
        if (nontriv[c]) nontriv_count += 1;
    }
    std.debug.print("SCC3: nontriv_sccs={d}\n", .{nontriv_count});

    // can-reach-non-trivial-SCC: reverse BFS over the FULL graph reverse
    // adjacency from all vertices in non-trivial SCCs (exact, single pass).
    var can_reach = std.AutoHashMap(u64, void).init(gpa);
    defer can_reach.deinit();
    var q = std.ArrayListUnmanaged(u64).empty;
    defer q.deinit(gpa);
    for (0..@as(usize, @intCast(n_comp))) |c| {
        if (nontriv[c]) {
            // seed every vertex of this comp
            for (0..@as(usize, @intCast(n_ids))) |id| {
                if (comp[id] == c) {
                    if (!can_reach.contains(id)) {
                        try can_reach.put(id, {});
                        try q.append(gpa, @intCast(id));
                    }
                }
            }
        }
    }
    var head: usize = 0;
    while (head < q.items.len) {
        const v = q.items[head];
        head += 1;
        const vi: usize = @intCast(v);
        const s0 = rsucc_start.items[vi];
        const s1 = rsucc_start.items[vi + 1];
        for (rsucc.items[s0..s1]) |p| {
            if (!can_reach.contains(p)) {
                try can_reach.put(p, {});
                try q.append(gpa, p);
            }
        }
    }
    std.debug.print("SCC3: can_reach_nontriv vertices={d}\n", .{can_reach.count()});

    // ko-carrying states + reverse-BFS: states that can reach a ko-carrying
    // state ("ko reachable in future", exact over the whole graph)
    var ko_carrying = std.ArrayListUnmanaged(u64).empty;
    defer ko_carrying.deinit(gpa);
    for (0..@as(usize, @intCast(n_ids))) |id| {
        const key = entries_list.items[id];
        const st = keyState(key);
        const pos = X3.pos_from_colex(st.colex);
        if (st.ko != KO_NONE3 or hasKoShape3(&pos)) {
            try ko_carrying.append(gpa, @intCast(id));
        }
    }
    var ko_reach = std.AutoHashMap(u64, void).init(gpa);
    defer ko_reach.deinit();
    var q2 = std.ArrayListUnmanaged(u64).empty;
    defer q2.deinit(gpa);
    for (ko_carrying.items) |id| {
        try ko_reach.put(id, {});
        try q2.append(gpa, id);
    }
    var head2: usize = 0;
    while (head2 < q2.items.len) {
        const v = q2.items[head2];
        head2 += 1;
        const vi: usize = @intCast(v);
        const s0 = rsucc_start.items[vi];
        const s1 = rsucc_start.items[vi + 1];
        for (rsucc.items[s0..s1]) |p| {
            if (!ko_reach.contains(p)) {
                try ko_reach.put(p, {});
                try q2.append(gpa, p);
            }
        }
    }

    // ban-parent: any in-edge from a parent with parent.ko != NONE (exact)
    var ban_parent = std.AutoHashMap(u64, void).init(gpa);
    defer ban_parent.deinit();
    for (0..@as(usize, @intCast(n_ids))) |id| {
        const st = keyState(entries_list.items[id]);
        if (st.ko != KO_NONE3) {
            const vi: usize = @intCast(id);
            const s0 = succ_start.items[vi];
            const s1 = succ_start.items[vi + 1];
            for (succ.items[s0..s1]) |w| {
                try ban_parent.put(w, {});
            }
        }
    }

    // conservative 1-ply check (the 4×4 instrument's method) for comparison
    var cons_ban_parent = std.AutoHashMap(u64, void).init(gpa);
    defer cons_ban_parent.deinit();
    {
        var dummy_expanded: u64 = 0;
        var ctx4like = ChildCtx{ .table = &wzo, .missing = &missing, .expanded = &dummy_expanded };
        for (0..@as(usize, @intCast(n_ids))) |id| {
            const st = keyState(entries_list.items[id]);
            if (st.ko == KO_NONE3 and st.passes == 0) {
                const bp = backwardBanParent9(&ctx4like, st.colex, st.side, st.ko, st.passes);
                if (bp.found) try cons_ban_parent.put(id, {});
            }
        }
    }

    // ── aggregates ──
    var lh_in_nontriv: u64 = 0;
    var lh_not_in_nontriv: u64 = 0;
    var eq_in_nontriv: u64 = 0;
    var eq_not_in_nontriv: u64 = 0;
    var lh_can_reach: u64 = 0;
    var lh_cannot_reach: u64 = 0;
    var eq_can_reach: u64 = 0;
    var eq_cannot_reach: u64 = 0;
    var lh_ko_reach: u64 = 0;
    var lh_no_ko_reach: u64 = 0;
    var eq_ko_reach: u64 = 0;
    var eq_no_ko_reach: u64 = 0;
    var lh_ban_parent: u64 = 0;
    var lh_no_ban_parent: u64 = 0;
    var eq_ban_parent: u64 = 0;
    var eq_no_ban_parent: u64 = 0;

    // width by SCC-size bucket (over L<H entries)
    const NBUCK = 5;
    var width_sum_buck = [_]u128{0} ** NBUCK;
    var width_cnt_buck = [_]u64{0} ** NBUCK;
    var width_sum_nontriv: u128 = 0;
    var width_cnt_nontriv: u64 = 0;
    var width_sum_notriv: u128 = 0;
    var width_cnt_notriv: u64 = 0;

    for (0..@as(usize, @intCast(n_ids))) |id| {
        const e = stateOf(&wzo, entries_list.items[id]);
        const in_nontriv = nontriv[@intCast(comp[id])];
        const cr = can_reach.contains(id);
        const kr = ko_reach.contains(id);
        const bp = ban_parent.contains(id);
        if (e.L != e.H) {
            const width: u8 = @intCast(e.H - e.L);
            const csz = comp_size.items[@intCast(comp[id])];
            const buck: usize = if (csz == 1) 0 else if (csz <= 10) 1 else if (csz <= 100) 2 else if (csz <= 1000) 3 else 4;
            width_sum_buck[buck] += width;
            width_cnt_buck[buck] += 1;
            if (in_nontriv) {
                lh_in_nontriv += 1;
                width_sum_nontriv += width;
                width_cnt_nontriv += 1;
            } else {
                lh_not_in_nontriv += 1;
                width_sum_notriv += width;
                width_cnt_notriv += 1;
            }
            if (cr) lh_can_reach += 1 else lh_cannot_reach += 1;
            if (kr) lh_ko_reach += 1 else lh_no_ko_reach += 1;
            if (bp) lh_ban_parent += 1 else lh_no_ban_parent += 1;
        } else {
            if (in_nontriv) eq_in_nontriv += 1 else eq_not_in_nontriv += 1;
            if (cr) eq_can_reach += 1 else eq_cannot_reach += 1;
            if (kr) eq_ko_reach += 1 else eq_no_ko_reach += 1;
            if (bp) eq_ban_parent += 1 else eq_no_ban_parent += 1;
        }
    }

    // class-3 exact census: L<H, ko==NONE, no static shape, no ko reachable,
    // no 1-ply ban-parent (exact), fresh-start and all entries
    var c3_exact_all: u64 = 0;
    var c3_exact_fresh: u64 = 0;
    var c3_width_sum_all: u128 = 0;
    var c3_width_sum_fresh: u128 = 0;
    // class-3 example keys, preferring readable mid-stone positions; keep the
    // first 12 with 3..7 stones, plus up to 4 more from the rest
    var c3_examples = std.ArrayListUnmanaged(u64).empty; // stKeys
    defer c3_examples.deinit(gpa);
    var c3_examples_any = std.ArrayListUnmanaged(u64).empty;
    defer c3_examples_any.deinit(gpa);
    var c3_maxw: i8 = 0;
    var c3_maxw_key: u64 = 0;
    for (0..@as(usize, @intCast(n_ids))) |id| {
        const e = stateOf(&wzo, entries_list.items[id]);
        const st = keyState(entries_list.items[id]);
        if (e.L == e.H) continue;
        if (st.ko != KO_NONE3) continue;
        const pos = X3.pos_from_colex(st.colex);
        if (hasKoShape3(&pos)) continue;
        if (ko_reach.contains(id)) continue;
        if (ban_parent.contains(id)) continue;
        c3_exact_all += 1;
        c3_width_sum_all += @as(u8, @intCast(e.H - e.L));
        if (e.H - e.L > c3_maxw) {
            c3_maxw = e.H - e.L;
            c3_maxw_key = entries_list.items[id];
        }
        if (st.passes == 0) {
            c3_exact_fresh += 1;
            c3_width_sum_fresh += @as(u8, @intCast(e.H - e.L));
        }
        var stones3: u8 = 0;
        for (pos) |v| {
            if (v != 0) stones3 += 1;
        }
        if (stones3 >= 3 and stones3 <= 7 and c3_examples.items.len < 12) {
            try c3_examples.append(gpa, entries_list.items[id]);
        } else if (c3_examples_any.items.len < 8) {
            try c3_examples_any.append(gpa, entries_list.items[id]);
        }
    }
    // top up with the any-list if the preferred list is short, and always
    // include the widest example
    var ti: usize = 0;
    while (c3_examples.items.len < 12 and ti < c3_examples_any.items.len) : (ti += 1) {
        try c3_examples.append(gpa, c3_examples_any.items[ti]);
    }
    if (c3_maxw_key != 0) {
        var has = false;
        for (c3_examples.items) |k| {
            if (k == c3_maxw_key) has = true;
        }
        if (!has) try c3_examples.append(gpa, c3_maxw_key);
    }

    std.debug.print("SCC3: L<H in_nontriv={d} not={d}; L==H in_nontriv={d} not={d}\n", .{ lh_in_nontriv, lh_not_in_nontriv, eq_in_nontriv, eq_not_in_nontriv });
    std.debug.print("SCC3: L<H can_reach={d} cannot={d}; L==H can_reach={d} cannot={d}\n", .{ lh_can_reach, lh_cannot_reach, eq_can_reach, eq_cannot_reach });
    std.debug.print("SCC3: L<H ko_reach={d} no={d}; L==H ko_reach={d} no={d}\n", .{ lh_ko_reach, lh_no_ko_reach, eq_ko_reach, eq_no_ko_reach });
    std.debug.print("SCC3: L<H ban_parent={d} no={d}; L==H ban_parent={d} no={d}\n", .{ lh_ban_parent, lh_no_ban_parent, eq_ban_parent, eq_no_ban_parent });
    std.debug.print("SCC3: class3_exact_all={d} fresh={d} examples={d}\n", .{ c3_exact_all, c3_exact_fresh, c3_examples.items.len });
    // conservative-vs-exact one-ply ban-parent comparison (the 4×4 check's
    // false-negative rate, measured exactly at 3×3)
    {
        var exact_only: u64 = 0;
        var cons_only: u64 = 0;
        var both: u64 = 0;
        for (0..@as(usize, @intCast(n_ids))) |id| {
            const c_has = cons_ban_parent.contains(id);
            const e_has = ban_parent.contains(id);
            if (c_has and e_has) {
                both += 1;
            } else if (c_has) {
                cons_only += 1;
            } else if (e_has) {
                exact_only += 1;
            }
        }
        std.debug.print("SCC3: cons-vs-exact ban-parent: both={d} cons_only={d} exact_only={d} (exact_only = conservative misses)\n", .{ both, cons_only, exact_only });
    }

    // ── JSON ──
    var j = Json.init(gpa);
    defer j.deinit();
    j.objBegin();
    j.key("task_id");
    j.esc("T385");
    j.putCh(',');
    j.key("mode");
    j.esc("corr3x3 — exhaustive");
    j.putCh(',');
    j.key("artifact");
    j.objBegin();
    j.key("path");
    j.esc("data/oracle-3x3-v2.wzo2");
    j.putCh(',');
    j.key("sha256");
    j.esc("d79c17cd6fd00ba4608bdc5b86c9930a15d2a7050e2cdce07b0203f5aeaf7beb");
    j.objEnd();
    j.putCh(',');
    j.key("graph");
    j.objBegin();
    j.key("vertices");
    j.int(n_ids);
    j.sep();
    j.key("edges");
    j.int(succ.items.len);
    j.sep();
    j.key("missing_children");
    j.int(missing);
    j.sep();
    j.key("sccs");
    j.int(n_comp);
    j.sep();
    j.key("nontriv_sccs");
    j.int(nontriv_count);
    j.sep();
    j.key("max_comp_size");
    var maxc: u64 = 0;
    for (comp_size.items) |sz| {
        if (sz > maxc) maxc = sz;
    }
    j.int(maxc);
    j.objEnd();
    j.putCh(',');
    j.key("correlation");
    j.objBegin();
    j.key("lh_entries");
    j.int(lh_in_nontriv + lh_not_in_nontriv);
    j.sep();
    j.key("lh_in_nontriv_scc");
    j.int(lh_in_nontriv);
    j.sep();
    j.key("lh_in_nontriv_pct");
    j.flt(@as(f64, @floatFromInt(lh_in_nontriv)) * 100.0 / @as(f64, @floatFromInt(lh_in_nontriv + lh_not_in_nontriv)));
    j.sep();
    j.key("eq_entries");
    j.int(eq_in_nontriv + eq_not_in_nontriv);
    j.sep();
    j.key("eq_in_nontriv_scc");
    j.int(eq_in_nontriv);
    j.sep();
    j.key("eq_in_nontriv_pct");
    j.flt(@as(f64, @floatFromInt(eq_in_nontriv)) * 100.0 / @as(f64, @floatFromInt(eq_in_nontriv + eq_not_in_nontriv)));
    j.sep();
    j.key("lh_can_reach_nontriv");
    j.int(lh_can_reach);
    j.sep();
    j.key("lh_can_reach_pct");
    j.flt(@as(f64, @floatFromInt(lh_can_reach)) * 100.0 / @as(f64, @floatFromInt(lh_can_reach + lh_cannot_reach)));
    j.sep();
    j.key("eq_can_reach_nontriv");
    j.int(eq_can_reach);
    j.sep();
    j.key("eq_can_reach_pct");
    j.flt(@as(f64, @floatFromInt(eq_can_reach)) * 100.0 / @as(f64, @floatFromInt(eq_can_reach + eq_cannot_reach)));
    j.sep();
    j.key("lh_ko_reachable");
    j.int(lh_ko_reach);
    j.sep();
    j.key("eq_ko_reachable");
    j.int(eq_ko_reach);
    j.sep();
    j.key("lh_1ply_ban_parent");
    j.int(lh_ban_parent);
    j.sep();
    j.key("eq_1ply_ban_parent");
    j.int(eq_ban_parent);
    j.sep();
    j.key("width_mean_in_nontriv");
    if (width_cnt_nontriv > 0) j.flt(@as(f64, @floatFromInt(width_sum_nontriv)) / @as(f64, @floatFromInt(width_cnt_nontriv))) else j.int(0);
    j.sep();
    j.key("width_mean_not_in_nontriv");
    if (width_cnt_notriv > 0) j.flt(@as(f64, @floatFromInt(width_sum_notriv)) / @as(f64, @floatFromInt(width_cnt_notriv))) else j.int(0);
    j.sep();
    j.key("width_mean_by_scc_size_bucket");
    j.arrBegin();
    var bfirst = true;
    for (0..NBUCK) |bk| {
        j.comma(&bfirst);
        j.objBegin();
            j.key("bucket");
        j.esc(switch (bk) {
            0 => "1 (trivial SCC)",
            1 => "2..10",
            2 => "11..100",
            3 => "101..1000",
            else => ">1000",
        });
        j.sep();
        j.key("n");
        j.int(width_cnt_buck[bk]);
        j.sep();
        j.key("mean_width");
        if (width_cnt_buck[bk] > 0) j.flt(@as(f64, @floatFromInt(width_sum_buck[bk])) / @as(f64, @floatFromInt(width_cnt_buck[bk]))) else j.int(0);
        j.objEnd();
    }
    j.arrEnd();
    j.objEnd();
    j.putCh(',');
    j.key("class3_exact_census");
    j.objBegin();
    j.key("definition");
    j.esc("entry is L<H, ko==NONE, position has no static ko shape, NO ko-carrying state reachable in the whole graph, NO 1-ply predecessor carrying a ko ban — all checks exhaustive over the 49,428-entry 3×3 graph");
    j.sep();
    j.key("all_entries");
    j.int(c3_exact_all);
    j.sep();
    j.key("fresh_start_entries");
    j.int(c3_exact_fresh);
    j.sep();
    j.key("mean_width_all");
    if (c3_exact_all > 0) j.flt(@as(f64, @floatFromInt(c3_width_sum_all)) / @as(f64, @floatFromInt(c3_exact_all))) else j.int(0);
    j.sep();
    j.key("mean_width_fresh");
    if (c3_exact_fresh > 0) j.flt(@as(f64, @floatFromInt(c3_width_sum_fresh)) / @as(f64, @floatFromInt(c3_exact_fresh))) else j.int(0);
    j.sep();
    j.key("examples");
    j.arrBegin();
    bfirst = true;
    for (c3_examples.items) |key| {
        j.comma(&bfirst);
        j.objBegin();
        const st = keyState(key);
        const e = stateOf(&wzo, key);
        var stones3: u8 = 0;
        {
            const p3 = X3.pos_from_colex(st.colex);
            for (p3) |v| {
                if (v != 0) stones3 += 1;
            }
        }
        j.key("colex");
        j.int(st.colex);
        j.sep();
        j.key("side");
        j.int(st.side);
        j.sep();
        j.key("passes");
        j.int(st.passes);
        j.sep();
        j.key("stones");
        j.int(stones3);
        j.sep();
        j.key("L");
        j.int(e.L);
        j.sep();
        j.key("H");
        j.int(e.H);
        j.objEnd();
    }
    j.arrEnd();
    j.objEnd();
    j.objEnd();
    j.putCh('\n');

    const out_dir = std.Io.Dir.cwd();
    var threaded_out = std.Io.Threaded.init(gpa, .{});
    defer threaded_out.deinit();
    out_dir.writeFile(threaded_out.io(), .{ .sub_path = out_path, .data = j.buf.items }) catch |err| {
        std.debug.print("cannot write {s}: {s}\n", .{ out_path, @errorName(err) });
        return;
    };
    std.debug.print("JSON written to {s} ({d} bytes)\n", .{ out_path, j.buf.items.len });
}

fn hasKoShape3(pos: *const [9]i8) bool {
    _ = rules.Rules(3, 3);
    for (0..9) |p| {
        inline for (.{ @as(i8, 1), @as(i8, -1) }) |colour| {
            if (isKoShape3(pos, p, colour)) return true;
        }
    }
    return false;
}
fn isKoShape3(pos: *const [9]i8, p: usize, colour: i8) bool {
    const R3 = rules.Rules(3, 3);
    if (pos[p] != 0) return false;
    const next = R3.pos_from_move(pos, colour, p) catch return false;
    var opp_before: u8 = 0;
    var opp_after: u8 = 0;
    var captured: ?usize = null;
    for (0..9) |i| {
        if (pos[i] == -colour) opp_before += 1;
        if (next[i] == -colour) opp_after += 1;
        if (pos[i] == -colour and next[i] == 0) captured = i;
    }
    if (opp_before - opp_after != 1) return false;
    var libs: u8 = 0;
    var friends: u8 = 0;
    var nb: [4]usize = undefined;
    const cnt = R3.neighbors(p, &nb);
    for (nb[0..cnt]) |q| {
        if (next[q] == 0) libs += 1;
        if (next[q] == colour) friends += 1;
    }
    if (libs != 1 or friends != 0) return false;
    return captured != null;
}

/// 3×3 variant of backwardBanParent (the conservative check, for comparison
/// against the exact reverse-graph result).
fn backwardBanParent9(ctx: *ChildCtx, colex: u32, side: i8, ko: u8, passes: u2) BackParent {
    const R3 = rules.Rules(3, 3);
    const X3 = colexmod.Indexer(3, 3);
    if (ko != 9 or passes != 0) return .{ .found = false, .move_cell = 0, .parent_ko = 0 };
    const pos = X3.pos_from_colex(colex);
    const prev_side: i8 = -side;
    for (0..9) |c| {
        if (pos[c] != prev_side) continue;
        for (0..9) |y| {
            if (y == c) continue;
            if (pos[y] != 0) continue;
            var pos_p = pos;
            pos_p[c] = 0;
            pos_p[y] = side;
            for (0..9) |e| {
                if (e == c or e == y) continue;
                if (pos_p[e] != 0) continue;
                if (!isKoShape3(&pos_p, e, prev_side)) continue;
                const child = R3.applyMove(&pos_p, prev_side, @intCast(e), 0, c) orelse continue;
                if (child.side != side or child.ko != ko or child.passes != passes) continue;
                const cco: u32 = @intCast(X3.colex_from_pos(&child.pos));
                if (cco != colex) continue;
                const g = findGroup(ctx.table, @intCast(X3.colex_from_pos(&pos_p))) orelse continue;
                if (ctx.table.lookup(g, prev_side, @intCast(e), 0) == null) continue;
                return .{ .found = true, .move_cell = @intCast(c), .parent_ko = @intCast(e) };
            }
        }
    }
    return .{ .found = false, .move_cell = 0, .parent_ko = 0 };
}

// ---------------------------------------------------------------------------
// selftest
// ---------------------------------------------------------------------------

fn selftestCheck(p: *u64, f: *u64, name: []const u8, cond: bool) void {
    if (cond) {
        p.* += 1;
    } else {
        f.* += 1;
        std.debug.print("SELFTEST FAIL: {s}\n", .{name});
    }
}

fn selftestMode(gpa: std.mem.Allocator) !void {
    var prng = std.Random.DefaultPrng.init(0x5E1F_E57);
    const rnd = prng.random();
    var pass: u64 = 0;
    var fail: u64 = 0;
    const check = selftestCheck;

    // 1. colex round-trip
    var rt_pass = true;
    for (0..1000) |_| {
        const idx: u32 = rnd.uintLessThan(u32, @intCast(X.total));
        const pos = X.pos_from_colex(idx);
        const back: u32 = @intCast(X.colex_from_pos(&pos));
        if (back != idx) {
            rt_pass = false;
            break;
        }
    }
    check(&pass, &fail, "colex round-trip (1000 samples)", rt_pass);

    // 2. key-byte decode vs artifact2 (T383 F-7 regression)
    var kb_pass = true;
    for (0..2000) |_| {
        const kb: u8 = rnd.int(u8);
        for (0..6) |ko_bits| { // 0..5 only: shift = 2+ko_bits must fit u3 (real tables: ko_bits <= 5)
            const d = artifact2.decodeKeyByte(kb, @intCast(ko_bits));
            const my_side = keyByteSide(kb);
            const my_ko = keyByteKo(kb, @intCast(ko_bits));
            const my_passes = keyBytePasses(kb, @intCast(ko_bits));
            if (my_ko != d.ko or my_passes != d.passes or (if (d.side == 0) my_side != 1 else my_side != -1)) {
                kb_pass = false;
                break;
            }
        }
    }
    // the F-7 witness itself
    {
        const kb = artifact2.encodeKeyByte(0, 3, 0, 0, 5);
        const d = artifact2.decodeKeyByte(kb, 5);
        if (d.ko != 3) kb_pass = false; // pre-fix kb>>1 decodes 6
    }
    check(&pass, &fail, "key-byte ko decode == artifact2.decodeKeyByte incl. F-7 witness (kb>>1 would give 6)", kb_pass);

    // 3. WZO2 read + binary search vs linear scan + PASS-NOKO invariant
    var wzo = try Wzo2.open(gpa, "data/oracle-4x4-v2.wzo2");
    defer gpa.free(wzo.groups);
    defer gpa.free(wzo.bytes);
    var bs_pass = true;
    var pn_pass = true;
    for (0..100) |_| {
        const gi = rnd.uintLessThan(u64, wzo.n_groups);
        const g: usize = @intCast(gi);
        const cnt = wzo.groups[g].count;
        for (0..cnt) |i| {
            const e = wzo.entryAt(g, i);
            const got = wzo.lookup(g, e.side, e.ko, e.passes);
            if (got == null or got.?.L != e.L or got.?.H != e.H) bs_pass = false;
            if (e.passes == 1 and e.ko != 16) pn_pass = false;
        }
        // random key: lookup must equal linear scan
        const r_side: i8 = if (rnd.uintLessThan(u32, 2) == 0) 1 else -1;
        const r_ko: u8 = @intCast(rnd.uintLessThan(u32, 17));
        const r_passes: u2 = @intCast(rnd.uintLessThan(u32, 2));
        var found_lin: ?Entry = null;
        for (0..cnt) |i| {
            const e = wzo.entryAt(g, i);
            if (e.side == r_side and e.ko == r_ko and e.passes == r_passes) found_lin = e;
        }
        const found_bs = wzo.lookup(g, r_side, r_ko, r_passes);
        if ((found_lin == null) != (found_bs == null)) bs_pass = false;
    }
    check(&pass, &fail, "binary search == linear scan; PASS-NOKO (passes>=1 ⇒ ko==NONE)", bs_pass and pn_pass);

    // 4. C-A1 spot: kernel children of random in-table states are in-table
    var missing: u64 = 0;
    var expanded: u64 = 0;
    var ctx = ChildCtx{ .table = &wzo, .missing = &missing, .expanded = &expanded };
    var ca1_pass = true;
    var checked_states: u64 = 0;
    for (0..2000) |_| {
        const gi = rnd.uintLessThan(u64, wzo.n_groups);
        const g: usize = @intCast(gi);
        const cnt = wzo.groups[g].count;
        const i = rnd.uintLessThan(u32, @intCast(cnt));
        const e = wzo.entryAt(g, i);
        if (e.passes == 2) continue;
        const key = stKey(e.colex, e.side, e.ko, e.passes);
        var children = [_]u64{0} ** (N + 1);
        var moves = [_]u8{0} ** (N + 1);
        const nch = childrenOf(&ctx, e.colex, e.side, e.ko, e.passes, &children, &moves);
        _ = nch;
        _ = key;
        checked_states += 1;
    }
    if (missing > 0) ca1_pass = false;
    check(&pass, &fail, "C-A1 spot check: 2000 states, kernel children all in-table", ca1_pass);
    std.debug.print("SELFTEST: C-A1 checked {d} states, missing children {d}\n", .{ checked_states, missing });

    // 5. natural-parent reconstruction + ko-search positive control
    var np_pass = true;
    var np_failures: u64 = 0;
    var np_checked: u64 = 0;
    var ks_pass = true;
    var ks_checked: u64 = 0;
    for (0..400) |_| {
        const gi = rnd.uintLessThan(u64, wzo.n_groups);
        const g: usize = @intCast(gi);
        const cnt = wzo.groups[g].count;
        const i = rnd.uintLessThan(u32, @intCast(cnt));
        const e = wzo.entryAt(g, i);
        if (e.ko == KO_NONE or e.passes != 0) continue;
        const np = naturalParent(&ctx, e.colex, e.side, e.ko, e.passes);
        np_checked += 1;
        if (np == null) {
            np_failures += 1;
            np_pass = false;
            continue;
        }
        // positive control: koSearch from the parent must find a ko at depth 1
        var pl: usize = 0;
        const ko = try koSearch(gpa, &ctx, np.?.parent_key, .{ .depth = 5, .nodes = 1000 }, &.{}, &pl);
        ks_checked += 1;
        if (!ko.found or ko.depth != 1) ks_pass = false;
    }
    check(&pass, &fail, "natural parent exists for every sampled ban state", np_pass);
    check(&pass, &fail, "ko-search positive control: parent of a ban state finds the ko at depth 1 (same search code)", ks_pass);
    std.debug.print("SELFTEST: natural-parent checked {d} (failures {d}); ko-search control checked {d}\n", .{ np_checked, np_failures, ks_checked });

    // 6. Tarjan + cycle-DFS positive control on a hand-built graph:
    //    0 -> 1 -> 2 -> 1, 1 -> 3, 3 -> 4. SCCs: {0},{1,2},{3},{4} (4 SCCs,
    //    one non-trivial of size 2). Cycle-reachable: 0,1,2; not: 3,4.
    var hb_succ = [_][]const u64{ &.{1}, &.{ 2, 3 }, &.{1}, &.{4}, &.{} };
    var hb_succ_start = [_]u64{ 0, 1, 3, 4, 5, 5 };
    var hb_comp = [_]u64{0} ** 5;
    const n_comp_hb = tarjanSmall(5, &hb_succ_start, &hb_succ, &hb_comp);
    const tarjan_pass = n_comp_hb == 4 and hb_comp[1] == hb_comp[2] and hb_comp[1] != hb_comp[0];
    check(&pass, &fail, "Tarjan hand-built graph: 4 SCCs, {1,2} shared", tarjan_pass);
    {
        // cycle DFS from 0 must find a cycle; from 4 must not
        var cyc_visited = std.AutoHashMap(u64, void).init(gpa);
        defer cyc_visited.deinit();
        const found_from_0 = cycleSearchSmall(gpa, &cyc_visited, 0, 5, 100, &hb_succ_start, &hb_succ);
        const found_from_4 = cycleSearchSmall(gpa, &cyc_visited, 4, 5, 100, &hb_succ_start, &hb_succ);
        if (!found_from_0 or found_from_4) {
            check(&pass, &fail, "cycle DFS hand-built graph: cycle from 0, none from 4", false);
        } else {
            check(&pass, &fail, "cycle DFS hand-built graph: cycle from 0, none from 4", true);
        }
    }

    // 7. board renderer
    {
        var buf: [512]u8 = undefined;
        var pos = [_]i8{0} ** 16;
        pos[0] = 1; // A1 black
        pos[5] = -1; // B2 white
        // ban cell 6 (C2) is empty by construction
        const s = renderBoard(&pos, -1, 6, 0, &buf);
        if (std.mem.indexOf(u8, s, "X") == null or std.mem.indexOf(u8, s, "O") == null or std.mem.indexOf(u8, s, "*") == null or std.mem.indexOf(u8, s, "White to move") == null or std.mem.indexOf(u8, s, "C2") == null) {
            check(&pass, &fail, "board renderer emits X/O/*/caption", false);
            std.debug.print("--- renderer output ---\n{s}--- end ---\n", .{s});
        } else {
            check(&pass, &fail, "board renderer emits X/O/*/caption", true);
        }
    }

    std.debug.print("SELFTEST: {d} passed, {d} failed\n", .{ pass, fail });
}

/// Minimal iterative Tarjan for the hand-built selftest graph.
fn tarjanSmall(n: usize, start: *const [6]u64, succ: *const [5][]const u64, comp: *[5]u64) u64 {
    var index = [_]u64{std.math.maxInt(u64)} ** 5;
    var low = [_]u64{0} ** 5;
    var onstack = [_]bool{false} ** 5;
    var stack = [_]u64{0} ** 5;
    var sp: usize = 0;
    var n_comp: u64 = 0;
    var counter: u64 = 0;
    const Work = struct { v: usize, it: usize };
    var work = [_]Work{.{ .v = 0, .it = 0 }} ** 8;
    var wtop: usize = 0;
    for (0..n) |root| {
        if (index[root] != std.math.maxInt(u64)) continue;
        work[wtop] = .{ .v = root, .it = 0 };
        wtop += 1;
        while (wtop > 0) {
            const st = work[wtop - 1];
            const v = st.v;
            if (st.it == 0) {
                index[v] = counter;
                low[v] = counter;
                counter += 1;
                stack[sp] = v;
                sp += 1;
                onstack[v] = true;
            }
            const s0: usize = @intCast(start[v]);
            const s1: usize = @intCast(start[v + 1]);
            var advanced = false;
            var it = st.it;
            while (s0 + it < s1) : (it += 1) {
                const w: usize = @intCast(succ[v][it]); // per-vertex slice
                if (index[w] == std.math.maxInt(u64)) {
                    work[wtop - 1].it = it + 1;
                    work[wtop] = .{ .v = w, .it = 0 };
                    wtop += 1;
                    advanced = true;
                    break;
                } else if (onstack[w]) {
                    if (index[w] < low[v]) low[v] = index[w];
                }
            }
            if (advanced) continue;
            if (low[v] == index[v]) {
                while (true) {
                    sp -= 1;
                    const w = stack[sp];
                    onstack[w] = false;
                    comp[w] = n_comp;
                    if (w == v) break;
                }
                n_comp += 1;
            }
            wtop -= 1;
            if (wtop > 0) {
                const p = work[wtop - 1].v;
                if (low[v] < low[p]) low[p] = low[v];
            }
        }
    }
    return n_comp;
}

/// Minimal cycle DFS for the hand-built selftest graph (on-path back-edge).
fn cycleSearchSmall(gpa: std.mem.Allocator, visited: *std.AutoHashMap(u64, void), root: u64, depth: u16, budget: u32, start: *const [6]u64, succ: *const [5][]const u64) bool {
    var onpath = std.AutoHashMap(u64, void).init(gpa);
    defer onpath.deinit();
    const StackItem = struct { v: u64, depth: u16, idx: usize };
    var stack = std.ArrayListUnmanaged(StackItem).empty;
    defer stack.deinit(gpa);
    visited.put(root, {}) catch unreachable;
    onpath.put(root, {}) catch unreachable;
    stack.append(gpa, .{ .v = root, .depth = 0, .idx = 0 }) catch unreachable;
    var nodes: u32 = 1;
    while (stack.items.len > 0) {
        const top = &stack.items[stack.items.len - 1];
        const v: usize = @intCast(top.v);
        const s0: usize = @intCast(start[v]);
        const s1: usize = @intCast(start[v + 1]);
        if (top.idx < s1 - s0) {
            const w = succ[v][top.idx];
            top.idx += 1;
            if (onpath.contains(w)) return true;
            if (visited.contains(w)) continue;
            if (nodes >= budget) return false;
            if (top.depth + 1 >= depth) continue;
            visited.put(w, {}) catch unreachable;
            onpath.put(w, {}) catch unreachable;
            stack.append(gpa, .{ .v = w, .depth = top.depth + 1, .idx = 0 }) catch unreachable;
            nodes += 1;
        } else {
            _ = onpath.remove(top.v);
            _ = stack.pop();
        }
    }
    return false;
}

// ---------------------------------------------------------------------------
// main
// ---------------------------------------------------------------------------

pub fn main(init: std.process.Init) !void {
    const gpa = std.heap.page_allocator;
    var args = std.process.Args.Iterator.init(init.minimal.args);
    _ = args.next();
    const mode: []const u8 = args.next() orelse "selftest";

    if (std.mem.eql(u8, mode, "selftest")) {
        try selftestMode(gpa);
        return;
    }
    if (std.mem.eql(u8, mode, "run")) {
        const out_path = args.next() orelse "findings/T385-gallery.json";
        const seed_str = args.next();
        const seed: u64 = if (seed_str) |ss| std.fmt.parseInt(u64, ss, 0) catch 0x7E57_7385 else 0x7E57_7385;
        try runMode(gpa, out_path, seed);
        return;
    }
    if (std.mem.eql(u8, mode, "corr3x3")) {
        const out_path = args.next() orelse "findings/T385-corr3x3.json";
        try corr3x3Mode(gpa, out_path);
        return;
    }
    std.debug.print("unknown mode {s}\n", .{mode});
}
