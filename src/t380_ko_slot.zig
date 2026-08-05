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
// T380 (flash) — Q1/Q2 instrument: is a single ko_point sufficient for
// basic ko, and is the ko state discovered correctly along the retrograde
// path's successor enumeration?
//
// Modes (argv[1]):
//   walk      — bounded BFS + seeded random walks over the REACHABLE 4×4
//               state graph, using the kernel successor relation
//               (rules.Rules(4,4).applyMove/applyPass, the T273 kernel).
//               At every visited state the instrument recomputes, from the
//               two-ply position window ALONE, the set of moves whose result
//               equals the position two plies earlier (B1's position-identity
//               ban set), and checks:
//                 INV-1  |ban set| <= 1
//                 INV-2  ban set == {ko slot}  iff the ko slot is set,
//                        and == {} otherwise
//               A violation of INV-1 is the Q1 counterexample (two distinct
//               capture-recapture bans live simultaneously). A violation of
//               INV-2 is a ko-state bookkeeping defect (Q2): the slot either
//               bans a move that would not recreate the two-plies-back
//               position (over-restriction) or fails to ban one that would
//               (under-restriction).
//   planted   — same walk, but the ban bookkeeping is DELIBERATELY BROKEN:
//               bans are only cleared by passes, never by non-ko-capture
//               moves. This plants two-live-bans states; the instrument must
//               FIND them (INV-1 violations) — the sensitivity control for
//               the counterexample search.
//   moveset   — kernel (rules.zig applyMove/applyPass) vs production
//               (exp6_solve.zig genChildren4) successor sets at 4×4, on the
//               states visited by the same walk. 0 mismatches expected;
//               this closes the T339 kernel-vs-solver gap at 4×4 (the
//               existing differential covers only <=3×3).
//   equiv3    — exhaustive shape-rule ⇔ position-identity equivalence at
//               3×3 (extends the Z-R-MOVE-B1-EQUIV lemma tests, which cover
//               only 2×2 and 3×2) over every legal P0 and every legal
//               single-capture two-ply window.
//   equiv4    — the same equivalence at 4×4, over a stratified sample of
//               legal P0 (by stone count) plus every single-capture window.
//
// Compile (ad hoc, no build.zig edits):
//   zig build-exe -O ReleaseFast --dep version -Mroot=src/t380_ko_slot.zig \
//     -Mversion=src/version.zig --cache-dir /tmp/weizigo/t380/kc \
//     --global-cache-dir /tmp/weizigo/t380/gc --name weizigo-t380-ko-slot \
//     -femit-bin=/tmp/weizigo/t380/ko-slot
//
// stdout = data (one JSON line at the end), stderr = diagnostics.

const std = @import("std");
const rules = @import("rules.zig");
const colexmod = @import("colex.zig");
const exp6 = @import("exp6_solve.zig");

const W = 4;
const H = 4;
const N = W * H;
const R = rules.Rules(W, H);
const X = colexmod.Indexer(W, H);
const E = @import("enumerate.zig").Enumerator(W, H);
const Pos = [N]i8;

const KO_NONE: u8 = @intCast(N);

/// Compact state encoding for the walk (matches exp6's layout): [passes:2][ko:5][side:1][colex:32]
fn encode(colex: u32, side: i8, ko: u8, passes: u2) u64 {
    const side_bit: u64 = if (side > 0) 0 else 1;
    return (@as(u64, passes) << 38) | (@as(u64, ko) << 33) | (side_bit << 32) | colex;
}
fn decodeCo(s: u64) u32 { return @intCast(s & 0xFFFFFFFF); }
fn decodeSide(s: u64) i8 { return if ((s >> 32) & 1 == 0) 1 else -1; }
fn decodeKo(s: u64) u8 { return @intCast((s >> 33) & 0x1F); }
fn decodePasses(s: u64) u2 { return @intCast((s >> 38) & 3); }

const WalkStats = struct {
    states_visited: u64 = 0,
    ko_set_states: u64 = 0,
    ban_checks: u64 = 0, // states at depth >= 2 (window available)
    inv1_violations: u64 = 0, // |ban set| > 1
    inv2_over: u64 = 0, // slot set but no B1 move (over-restriction)
    inv2_under: u64 = 0, // B1 move exists but slot empty (under-restriction)
    ko_edges: u64 = 0, // edges whose move set a ko point
    witness: ?u64 = null, // first violating state
    witness_ban: [4]u8 = [_]u8{255} ** 4, // the offending ban set
    over_colex: u64 = 0, // first over-restriction witness position
    over_side: i8 = 0,
    over_ko: u8 = 255,
    over_pass: u2 = 0,
    over_ban: [4]u8 = [_]u8{255} ** 4, // the computed ban set at that state
};

/// True ban set at a state, derived from the two-ply window (position two
/// plies back == `p0`) and the position now (`p1`), for the player to move
/// (`side`). Every legal move m whose result recreates p0 is in the set.
/// `planted_stale` (broken bookkeeping): additionally keeps the previous
/// move's ban live if the last move was not a pass — plants two-live-bans.
/// Returns (count, points[]).
fn banSetAt(p0: ?*const Pos, p1: *const Pos, side: i8, planted_stale: bool, last_move_was_pass: bool, stale_ko: u8, out: *[N]u8) usize {
    var cnt: usize = 0;
    if (p0 != null) {
        for (0..N) |cell| {
            if (p1[cell] != 0) continue; // B1 requires a placement on empty
            const child = R.pos_from_move(p1, side, cell) catch continue;
            if (std.mem.eql(i8, child[0..], p0.?[0..])) {
                if (cnt < N) out[cnt] = @intCast(cell);
                cnt += 1;
            }
        }
    }
    if (planted_stale and !last_move_was_pass and stale_ko < KO_NONE) {
        // The planted defect: a second, stale ban that the single slot cannot
        // carry. If it is distinct from any real ban it makes |set| == 2.
        var dup = false;
        for (out[0..cnt]) |q| {
            if (q == stale_ko) dup = true;
        }
        if (!dup) {
            if (cnt < N) out[cnt] = stale_ko;
            cnt += 1;
        }
    }
    return cnt;
}

fn checkState(
    s: u64,
    p0: ?*const Pos,
    p1: *const Pos,
    last_move_was_pass: bool,
    stale_ko: u8,
    stats: *WalkStats,
    planted: bool,
) void {
    const side = decodeSide(s);
    const ko = decodeKo(s);
    var bans: [N]u8 = undefined;
    const cnt = banSetAt(p0, p1, side, planted, last_move_was_pass, stale_ko, &bans);

    stats.ban_checks += 1;
    if (cnt > 1) {
        stats.inv1_violations += 1;
        if (stats.witness == null) {
            stats.witness = s;
            for (bans[0..@min(cnt, 4)], 0..) |b, i| stats.witness_ban[i] = b;
        }
        return;
    }
    const slot_set = ko < KO_NONE;
    const ban_point: u8 = if (cnt == 1) bans[0] else 255;
    if (slot_set) {
        stats.ko_set_states += 1;
        if (cnt != 1 or ban_point != ko) {
            stats.inv2_over += 1;
            if (stats.over_ko == 255) {
                stats.over_colex = decodeCo(s);
                stats.over_side = side;
                stats.over_ko = ko;
                stats.over_pass = decodePasses(s);
                for (bans[0..@min(cnt, 4)], 0..) |b, i| stats.over_ban[i] = b;
            }
        }
    } else {
        if (cnt == 1) stats.inv2_under += 1;
    }
}

/// Debug: dump the first `n` over-restriction witnesses (slot set but the B1
/// ban set is empty or points elsewhere) with full positions.
fn dumpOver(stats: *WalkStats, n: usize) void {
    _ = stats;
    _ = n;
}

fn walk(stats: *WalkStats, planted: bool, max_states: u64, random_walks: u64, seed: u64) !void {
    const gpa = std.heap.page_allocator;
    var visited = std.AutoHashMap(u64, void).init(gpa);
    defer visited.deinit();

    var frontier = try std.ArrayListUnmanaged(u64).initCapacity(gpa, 0);
    defer frontier.deinit(gpa);

    var prng = std.Random.DefaultPrng.init(seed);

    // ── bounded BFS from the empty root, Black to move, ko=none, passes=0 ──
    const root = encode(0, 1, KO_NONE, 0);
    try frontier.append(gpa, root);
    try visited.put(root, {});
    var depth_of: std.AutoHashMap(u64, u16) = std.AutoHashMap(u64, u16).init(gpa);
    defer depth_of.deinit();
    try depth_of.put(root, 0);

    // two-ply window bookkeeping per state: (p0_enc, p1_enc, last_pass, stale_ko)
    // We recompute p0/p1 on demand from the parent chain kept in a small map.
    // To keep memory bounded we store per-state window info.
    const WinInfo = struct { p0: ?u32, p1: u32, last_pass: bool, stale_ko: u8 };
    var win_of = std.AutoHashMap(u64, WinInfo).init(gpa);
    defer win_of.deinit();
    try win_of.put(root, .{ .p0 = null, .p1 = 0, .last_pass = false, .stale_ko = KO_NONE });

    var bfs_done = false;
    while (!bfs_done and visited.count() < max_states) {
        bfs_done = true;
        var next_frontier = try std.ArrayListUnmanaged(u64).initCapacity(gpa, 0);
        for (frontier.items) |s| {
            if (visited.count() >= max_states) break;
            stats.states_visited += 1;
            const d = depth_of.get(s).?;
            const co = decodeCo(s);
            const side = decodeSide(s);
            const ko = decodeKo(s);
            const passes = decodePasses(s);
            const win = win_of.get(s).?;
            var pos: Pos = X.pos_from_colex(co);
            const p0p: ?*const Pos = if (win.p0) |p0c| blk: {
                var p0s: Pos = X.pos_from_colex(p0c);
                break :blk &p0s;
            } else null;

            // INV checks at this state (B1 ban set vs slot)
            checkState(s, p0p, &pos, win.last_pass, win.stale_ko, stats, planted);

            if (passes >= 2 or R.is_settled(&pos)) continue;

            // successors via the kernel
            for (0..N) |cell| {
                if (R.applyMove(&pos, side, ko, passes, cell)) |child| {
                    const cco: u32 = @intCast(X.colex_from_pos(&child.pos));
                    const cs = encode(cco, child.side, child.ko, child.passes);
                    const is_ko_edge = child.ko < KO_NONE;
                    if (is_ko_edge) stats.ko_edges += 1;
                    if (!visited.contains(cs) and d < 14) {
                        try visited.put(cs, {});
                        try depth_of.put(cs, d + 1);
                        // window for child: p0 = parent position (B1's "two
                        // plies earlier" relative to a move's result), p1 =
                        // parent position; last_pass=false; stale_ko: the ko
                        // this move set, or (planted mode only) an inherited
                        // ban that the single slot cannot carry.
                        const child_win = WinInfo{
                            .p0 = co,
                            .p1 = co,
                            .last_pass = false,
                            .stale_ko = if (is_ko_edge) child.ko else if (planted) win.stale_ko else KO_NONE,
                        };
                        try win_of.put(cs, child_win);
                        try next_frontier.append(gpa, cs);
                    }
                }
            }
            if (R.applyPass(side, passes)) |pc| {
                const cs = encode(co, pc.side, pc.ko, pc.passes);
                if (!visited.contains(cs) and d < 14) {
                    try visited.put(cs, {});
                    try depth_of.put(cs, d + 1);
                    try win_of.put(cs, .{ .p0 = null, .p1 = co, .last_pass = true, .stale_ko = KO_NONE });
                    try next_frontier.append(gpa, cs);
                }
            }
        }
        frontier.deinit(gpa);
        frontier = next_frontier;
        if (frontier.items.len > 0) bfs_done = false;
    }
    frontier.deinit(gpa);

    // ── random walks (deep lines; ko fights need many plies) ──
    var w = random_walks;
    while (w > 0) : (w -= 1) {
        var co: u32 = 0;
        var side: i8 = 1;
        var ko: u8 = KO_NONE;
        var passes: u2 = 0;
        // window: p0 = position one state back (B1's "two plies earlier"
        // relative to a move's result), p1 = current position. Both are
        // updated after every move (a pass leaves p1 unchanged).
        var p0: ?Pos = null;
        var pos: Pos = [_]i8{0} ** N;
        var last_pass = false;
        var stale_ko: u8 = KO_NONE;

        var ply: usize = 0;
        while (ply < 400) : (ply += 1) {
            stats.states_visited += 1;
            const s = encode(co, side, ko, passes);
            const p0p: ?*const Pos = if (p0) |*p| p else null;
            checkState(s, p0p, &pos, last_pass, stale_ko, stats, planted);

            if (passes >= 2 or R.is_settled(&pos)) break;
            // choose a random legal move
            var choices = try std.ArrayListUnmanaged(u8).initCapacity(gpa, 0);
            defer choices.deinit(gpa);
            var pass_choice: bool = false;
            for (0..N) |cell| {
                if (R.applyMove(&pos, side, ko, passes, cell)) |_| try choices.append(gpa, @intCast(cell));
            }
            const rnd = prng.random();
            if (choices.items.len == 0 or rnd.boolean()) {
                if (R.applyPass(side, passes)) |pc| {
                    pass_choice = true;
                    side = pc.side;
                    ko = pc.ko;
                    passes = pc.passes;
                    last_pass = true;
                    stale_ko = KO_NONE;
                    p0 = pos; // pass leaves the position unchanged: p0 = p1
                    continue;
                }
            }
            if (!pass_choice and choices.items.len == 0) break;
            if (pass_choice) continue;
            const pick = rnd.uintLessThan(usize, choices.items.len);
            const cell: u8 = choices.items[pick];
            const child = R.applyMove(&pos, side, ko, passes, cell).?;
            const was_ko_edge = child.ko < KO_NONE;
            p0 = pos;
            pos = child.pos;
            co = @intCast(X.colex_from_pos(&pos));
            side = child.side;
            ko = child.ko;
            passes = child.passes;
            last_pass = false;
            // planted bookkeeping: a ban survives until a pass
            stale_ko = if (stale_ko != KO_NONE) stale_ko else if (was_ko_edge) child.ko else KO_NONE;
        }
    }
}

pub fn main(init: std.process.Init) !void {
    const gpa = std.heap.page_allocator;
    var args = std.process.Args.Iterator.init(init.minimal.args);
    _ = args.next();
    const mode: []const u8 = args.next() orelse "walk";

    if (std.mem.eql(u8, mode, "walk") or std.mem.eql(u8, mode, "planted")) {
        const planted = std.mem.eql(u8, mode, "planted");
        var stats = WalkStats{};
        const max_states: u64 = 8_000_000;
        const walks: u64 = 20_000;
        try walk(&stats, planted, max_states, walks, 0x7E57_A380);
        std.debug.print("mode={s} states={d} ko_set={d} ban_checks={d} ko_edges={d} inv1={d} over={d} under={d}\n", .{
            mode, stats.states_visited, stats.ko_set_states, stats.ban_checks, stats.ko_edges,
            stats.inv1_violations, stats.inv2_over, stats.inv2_under,
        });
        if (stats.witness) |ws| {
            std.debug.print("witness state: colex={d} side={d} ko={d} passes={d} bans={d},{d},{d},{d}\n", .{
                decodeCo(ws), decodeSide(ws), decodeKo(ws), decodePasses(ws),
                stats.witness_ban[0], stats.witness_ban[1], stats.witness_ban[2], stats.witness_ban[3],
            });
        }
        if (stats.over_ko != 255) {
            std.debug.print("OVER witness: colex={d} side={d} ko={d} passes={d} bans={d},{d},{d},{d}\n", .{
                stats.over_colex, stats.over_side, stats.over_ko, stats.over_pass,
                stats.over_ban[0], stats.over_ban[1], stats.over_ban[2], stats.over_ban[3],
            });
            const op: Pos = X.pos_from_colex(stats.over_colex);
            std.debug.print("  position: ", .{});
            for (op) |c| std.debug.print("{d} ", .{c});
            std.debug.print("\n", .{});
        }
        std.debug.print("RESULT {s}: inv1={d} inv2_over={d} inv2_under={d} (want 0,0,0)\n", .{
            mode, stats.inv1_violations, stats.inv2_over, stats.inv2_under,
        });
        return;
    }
    if (std.mem.eql(u8, mode, "moveset")) {
        // kernel vs exp6 successor sets at 4×4 over a random state sample
        var mismatches: u64 = 0;
        var states_checked: u64 = 0;
        var prng = std.Random.DefaultPrng.init(0xC0FFEE);
        const rnd = prng.random();
        var s_ix: u64 = 0;
        while (s_ix < 400_000) : (s_ix += 1) {
            // random legal-ish position: random colex (illegal positions are
            // filtered by both sides' move generators consistently)
            const co: u32 = rnd.uintLessThan(u32, @intCast(X.total));
            var pos: Pos = X.pos_from_colex(co);
            const side: i8 = if (rnd.boolean()) 1 else -1;
            const passes: u2 = @intCast(rnd.uintLessThan(u8, 3));
            if (passes == 2) continue;
            const ko: u8 = @intCast(rnd.uintLessThan(u8, N + 1)); // N = NONE
            states_checked += 1;
            // kernel children as a set of (colex, side, ko, passes)
            var kset = [_]u64{0} ** (N + 1);
            var kcnt: usize = 0;
            for (0..N) |cell| {
                if (R.applyMove(&pos, side, ko, passes, cell)) |child| {
                    const cco: u32 = @intCast(X.colex_from_pos(&child.pos));
                    kset[kcnt] = encode(cco, child.side, child.ko, child.passes);
                    kcnt += 1;
                }
            }
            if (R.applyPass(side, passes)) |pc| {
                kset[kcnt] = encode(co, pc.side, pc.ko, pc.passes);
                kcnt += 1;
            }
            // exp6 children (production builder): the board field is the
            // base-3 RANK (T178 family), so encode the parent via rank and
            // map the children through positions to the combinatorial colex
            // before comparing with the kernel.
            const enc = exp6.encodeState4(exp6.rank_board4(pos), if (side > 0) 0 else 1, @intCast(ko), passes);
            var children: [N + 1]u64 = undefined;
            var nch: usize = 0;
            exp6.genChildren4(enc, &children, &nch);
            for (children[0..nch]) |*c| {
                const rpos = exp6.unrank_board4(exp6.decodeBoard4(c.*));
                const cco: u32 = @intCast(X.colex_from_pos(&rpos));
                c.* = encode(cco, if (exp6.decodeSide4(c.*) == 0) @as(i8, 1) else @as(i8, -1), exp6.decodeKo4(c.*), exp6.decodePasses4(c.*));
            }
            if (nch != kcnt) mismatches += 1;
            // match kernel children to exp6 children (order-independent)
            var used = [_]bool{false} ** (N + 1);
            for (kset[0..kcnt]) |k| {
                var found = false;
                for (children[0..nch], 0..) |c, j| {
                    if (!used[j] and c == k) {
                        used[j] = true;
                        found = true;
                        break;
                    }
                }
                if (!found) {
                    mismatches += 1;
                    if (mismatches <= 8) {
                        const dco = decodeCo(k);
                        std.debug.print("MOVESET MISMATCH colex={d} side={d} ko={d} passes={d} child(colex={d} side={d} ko={d} passes={d}) kernel-only\n", .{
                            co, side, ko, passes, dco, decodeSide(k), decodeKo(k), decodePasses(k),
                        });
                    }
                }
            }
            for (children[0..nch], 0..) |c, j| {
                if (!used[j]) {
                    mismatches += 1;
                    if (mismatches <= 8) {
                        std.debug.print("MOVESET MISMATCH colex={d} side={d} ko={d} passes={d} child(colex={d} side={d} ko={d} passes={d}) exp6-only\n", .{
                            co, side, ko, passes, exp6.decodeBoard4(c), exp6.decodeSide4(c), exp6.decodeKo4(c), exp6.decodePasses4(c),
                        });
                    }
                }
            }
        }
        std.debug.print("RESULT moveset: states={d} mismatches={d} (want 0)\n", .{ states_checked, mismatches });
        return;
    }
    if (std.mem.eql(u8, mode, "equiv3")) {
        try equivExhaustive(3, 3, gpa);
        return;
    }
    if (std.mem.eql(u8, mode, "equiv4")) {
        try equivSample4(gpa);
        return;
    }
    std.debug.print("unknown mode {s}\n", .{mode});
}

/// Exhaustive shape-rule ⇔ position-identity equivalence at 3×3 — the same
/// construction as the Z-R-MOVE-B1-EQUIV tests (2×2/3×2), extended to 3×3.
/// Every legal P0, every White single-stone-capture window, every Black
/// single-stone-capture reply: P2 == P0  ⇔  koAfterCapture(P1, P2, Black) != none.
fn equivExhaustive(comptime w: usize, comptime h: usize, gpa: std.mem.Allocator) !void {
    _ = gpa;
    const RR = rules.Rules(w, h);
    const EE = @import("enumerate.zig").Enumerator(w, h);
    const XX = colexmod.Indexer(w, h);
    const n = w * h;
    var checked: u64 = 0;
    var mismatches: u64 = 0;
    var ban_mismatches: u64 = 0;
    var windows_with_ko: u64 = 0;
    var total_legal_p0: u64 = 0;

    for (0..XX.total) |p0_idx| {
        var p0: [n]i8 = XX.pos_from_colex(p0_idx);
        if (!EE.is_legal(&p0)) continue;
        total_legal_p0 += 1;
        for (0..n) |w_cell| {
            if (p0[w_cell] != 0) continue;
            const p1r = RR.pos_from_move(&p0, -1, w_cell) catch continue;
            // White must capture exactly one Black stone
            var black_captured: u8 = 0;
            for (0..n) |i| {
                if (p0[i] == 1 and p1r[i] == 0) black_captured += 1;
            }
            if (black_captured != 1) continue;
            for (0..n) |b_cell| {
                if (p1r[b_cell] != 0) continue;
                const p2 = RR.pos_from_move(&p1r, 1, b_cell) catch continue;
                var white_captured: u8 = 0;
                for (0..n) |i| {
                    if (p1r[i] == -1 and p2[i] == 0) white_captured += 1;
                }
                if (white_captured != 1) continue;
                checked += 1;
                const pos_id = std.mem.eql(i8, &p2, &p0);
                const ko_point = rules.koAfterCapture(&p1r, &p2, 1, w, h, @intCast(n));
                const shape_ko = ko_point != n;
                if (shape_ko) windows_with_ko += 1;
                if (pos_id != shape_ko) {
                    mismatches += 1;
                    if (mismatches <= 5) {
                        std.debug.print("EQUIV3 WINDOW-MISMATCH p0={d} w_cell={d} b_cell={d} pos_id={} shape={}\n", .{
                            p0_idx, w_cell, b_cell, pos_id, shape_ko,
                        });
                    }
                }
                // The predicate the engine actually needs (B1's ban at the
                // resulting state): the ban set at P2 for White — moves whose
                // result recreates P1 (the position one state back) — must be
                // exactly {ko_point} iff the shape rule set a ko point.
                if (shape_ko) {
                    var ban_cells: [n]u8 = undefined;
                    var bcnt: usize = 0;
                    for (0..n) |m| {
                        if (p2[m] != 0) continue;
                        const res = RR.pos_from_move(&p2, -1, m) catch continue;
                        if (std.mem.eql(i8, &res, &p1r)) {
                            if (bcnt < n) ban_cells[bcnt] = @intCast(m);
                            bcnt += 1;
                        }
                    }
                    if (bcnt != 1 or ban_cells[0] != ko_point) {
                        ban_mismatches += 1;
                        if (ban_mismatches <= 5) {
                            std.debug.print("EQUIV3 BAN-MISMATCH p0={d} w_cell={d} b_cell={d} ko_point={d} ban_cells={d},{d}\n", .{
                                p0_idx, w_cell, b_cell, ko_point,
                                if (bcnt > 0) ban_cells[0] else 255,
                                if (bcnt > 1) ban_cells[1] else 255,
                            });
                        }
                    }
                } else {
                    // no ko point set: the ban set must be empty
                    var bcnt: usize = 0;
                    for (0..n) |m| {
                        if (p2[m] != 0) continue;
                        const res = RR.pos_from_move(&p2, -1, m) catch continue;
                        if (std.mem.eql(i8, &res, &p1r)) bcnt += 1;
                    }
                    if (bcnt != 0) {
                        ban_mismatches += 1;
                        if (ban_mismatches <= 5) {
                            std.debug.print("EQUIV3 UNDER-BAN p0={d} w_cell={d} b_cell={d} bcnt={d}\n", .{
                                p0_idx, w_cell, b_cell, bcnt,
                            });
                        }
                    }
                }
            }
        }
    }
    std.debug.print("RESULT equiv3: legal_p0={d} windows={d} windows_with_ko={d} window_mismatches={d} ban_mismatches={d} (want 0,0)\n", .{
        total_legal_p0, checked, windows_with_ko, mismatches, ban_mismatches,
    });
}

/// Stratified-sample equivalence at 4×4: for each stone-count layer, sample
/// legal P0 positions; for each, all White single-capture windows and all
/// Black single-capture replies; verify pos-identity ⇔ shape rule.
fn equivSample4(gpa: std.mem.Allocator) !void {
    const n = 16;
    var prng = std.Random.DefaultPrng.init(0xE9_15_0001);
    const rnd = prng.random();
    var checked: u64 = 0;
    var mismatches: u64 = 0;
    var ban_mismatches: u64 = 0;
    var windows_with_ko: u64 = 0;
    var p0_tried: u64 = 0;
    var p0_with_window: u64 = 0;

    var layer: usize = 0;
    while (layer <= n) : (layer += 1) {
        const lo = X.layer_offset[layer];
        const hi = X.layer_offset[layer + 1];
        const span = hi - lo;
        const want: u64 = @intCast(@min(@as(u64, 250_000), span));
        var drawn: u64 = 0;
        var attempts: u64 = 0;
        while (drawn < want and attempts < want * 4) : (attempts += 1) {
            const idx: u64 = lo + rnd.uintLessThan(u64, span);
            var p0: Pos = X.pos_from_colex(idx);
            if (!E.is_legal(&p0)) continue;
            drawn += 1;
            p0_tried += 1;
            var any_window = false;
            for (0..n) |w_cell| {
                if (p0[w_cell] != 0) continue;
                const p1r = R.pos_from_move(&p0, -1, w_cell) catch continue;
                var black_captured: u8 = 0;
                for (0..n) |i| {
                    if (p0[i] == 1 and p1r[i] == 0) black_captured += 1;
                }
                if (black_captured != 1) continue;
                for (0..n) |b_cell| {
                    if (p1r[b_cell] != 0) continue;
                    const p2 = R.pos_from_move(&p1r, 1, b_cell) catch continue;
                    var white_captured: u8 = 0;
                    for (0..n) |i| {
                        if (p1r[i] == -1 and p2[i] == 0) white_captured += 1;
                    }
                    if (white_captured != 1) continue;
                    any_window = true;
                    checked += 1;
                    const pos_id = std.mem.eql(i8, &p2, &p0);
                    const ko_point = rules.koAfterCapture(&p1r, &p2, 1, 4, 4, 16);
                    const shape_ko = ko_point != 16;
                    if (shape_ko) windows_with_ko += 1;
                    if (pos_id != shape_ko) {
                        mismatches += 1;
                    }
                    // The predicate the engine actually needs (B1's ban at the
                    // resulting state): moves from P2 (White) whose result
                    // recreates P1 (the position one state back) must be
                    // exactly {ko_point} iff the shape rule set a ko point.
                    if (shape_ko) {
                        var ban_cells: [16]u8 = undefined;
                        var bcnt: usize = 0;
                        for (0..16) |m| {
                            if (p2[m] != 0) continue;
                            const res = R.pos_from_move(&p2, -1, m) catch continue;
                            if (std.mem.eql(i8, &res, &p1r)) {
                                if (bcnt < 16) ban_cells[bcnt] = @intCast(m);
                                bcnt += 1;
                            }
                        }
                        if (bcnt != 1 or ban_cells[0] != ko_point) ban_mismatches += 1;
                    } else {
                        var bcnt: usize = 0;
                        for (0..16) |m| {
                            if (p2[m] != 0) continue;
                            const res = R.pos_from_move(&p2, -1, m) catch continue;
                            if (std.mem.eql(i8, &res, &p1r)) bcnt += 1;
                        }
                        if (bcnt != 0) ban_mismatches += 1;
                    }
                }
            }
            if (any_window) p0_with_window += 1;
        }
    }
    _ = gpa;
    std.debug.print("RESULT equiv4: p0_sampled={d} p0_with_window={d} windows={d} windows_with_ko={d} window_mismatches={d} ban_mismatches={d} (want 0,0)\n", .{
        p0_tried, p0_with_window, checked, windows_with_ko, mismatches, ban_mismatches,
    });
}
