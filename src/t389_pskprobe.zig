////////////////////////////////////////////
//
// T389 auxiliary probe (disposable, /tmp): does the fA-o06-B ply-3 bracket
// escape come from the new engine being PSK-restricted in frame A against its
// own basic-ko table?
//
// Replays the committed fA-o06-B line to ply 3 (the first violated node,
// bracket [1,1], final B+16) and compares the new engine's live choice under
// basic-ko enforcement vs under PSK enforcement at that node, plus whether the
// basic-ko optimal move would be PSK-legal (repeats history or not).
//
// Standalone build, additive (no build.zig, no engine-source edits).

const std = @import("std");
const rules = @import("rules.zig");
const artifact2 = @import("artifact2.zig");
const gtp = @import("gtp.zig");
const colex = @import("colex.zig");

const W: usize = 4;
const H: usize = 4;
const R = rules.Rules(W, H);
const X = colex.Indexer(W, H);
const S = gtp.Session(W, H);

fn cellFromVertex(token: []const u8) ?usize {
    if (token.len != 2) return null;
    if (token[0] < 'a' or token[0] >= 'a' + W) return null;
    if (token[1] < 'a' or token[1] >= 'a' + H) return null;
    const col: usize = token[0] - 'a';
    const row: usize = token[1] - 'a';
    return row * W + col;
}


pub fn main2(init: std.process.Init) !void {
    const gpa = std.heap.page_allocator;
    const io = init.io;
    var a2 = artifact2.load(io, std.Io.Dir.cwd(), "data/oracle-4x4-v2.wzo2", gpa) catch return;
    defer a2.deinit();
    const moves = [_][]const u8{ "ca", "bc", "cc", "bb", "cb", "cd", "ba", "ab", "ac", "ad", "dc", "da", "aa", "pass", "db", "dd", "bd", "pass", "ac", "pass", "pass" };
    var s = S{ .d = null, .a2 = &a2, .enforcement = .psk };
    s.reset();
    var side: i8 = 1;
    var final: i8 = 0;
    for (moves, 0..) |mv, ply| {
        if (s.passes >= 2) { final = R.area_score(&s.pos); break; }
        const colex_val: u32 = @intCast(X.colex_from_pos(&s.pos));
        const row = artifact2.lookup(&a2, colex_val, side, s.ko_point, @intCast(s.passes));
        if (row) |r| {
            std.debug.print("node ply {d} ({s} to move): bracket [{d},{d}]{s} | committed move: {s}\n", .{
                ply, if (side > 0) "B" else "W", r.L, r.H,
                if (r.L != r.H) " (L<H)" else "", mv,
            });
        } else {
            std.debug.print("node ply {d}: NOT IN TABLE | committed: {s}\n", .{ ply, mv });
        }
        s.applyMove(side, if (std.mem.eql(u8, mv, "pass")) null else cellFromVertex(mv).?) catch unreachable;
        side = -side;
    }
    std.debug.print("final: {d}\n", .{final});
}
pub fn main(init: std.process.Init) !void {
    const gpa = std.heap.page_allocator;
    const io = init.io;
    var a2 = artifact2.load(io, std.Io.Dir.cwd(), "data/oracle-4x4-v2.wzo2", gpa) catch |err| {
        std.debug.print("cannot load artifact: {t}\n", .{err});
        return;
    };
    defer a2.deinit();

    const moves = [_][]const u8{ "ca", "bc", "cc", "bb", "cb", "cd", "ba", "ab", "ac", "ad", "dc", "da", "aa", "pass", "db", "dd", "bd", "pass", "ac", "pass", "pass" };

    var s = S{ .d = null, .a2 = &a2, .enforcement = .basic_ko };
    s.reset();

    var side: i8 = 1;
    var ply: usize = 0;
    // play to the violated node (ply 3 = moves-index 3: after ca,bc,cc Black to move)
    const node_ply: usize = 3;
    while (ply < node_ply) : (ply += 1) {
        const mv = moves[ply];
        const cell: ?usize = if (std.mem.eql(u8, mv, "pass")) null else cellFromVertex(mv).?;
        s.applyMove(side, cell) catch unreachable;
        side = -side;
    }
    // now at node ply 3, Black to move
    const colex_val: u32 = @intCast(X.colex_from_pos(&s.pos));
    const row = artifact2.lookup(&a2, colex_val, side, s.ko_point, @intCast(s.passes)) orelse {
        std.debug.print("node ply {d} NOT in table (colex {d}, side {d}, ko {d}, passes {d})\n", .{ node_ply, colex_val, side, s.ko_point, s.passes });
        return;
    };
    std.debug.print("node ply {d}: {s} to move, bracket [{d},{d}], ko={d} passes={d}\n", .{ node_ply, if (side > 0) "B" else "W", row.L, row.H, s.ko_point, s.passes });
    std.debug.print("committed final score of the whole game: B+16\n", .{});

    // basic-ko enforcement: the new engine's own choice
    var s_bk = s;
    const c_bk = s_bk.choose(side);
    std.debug.print("basic-ko choose: cell={?d} value={d}\n", .{ c_bk.cell, c_bk.value });

    // is the basic-ko optimal move PSK-legal at this node? (frame A restriction)
    if (c_bk.cell) |cell| {
        var scratch = s;
        scratch.applyMove(side, cell) catch unreachable;
        const child_pos = scratch.hist[scratch.hist_len - 1];
        var repeats = false;
        for (scratch.hist[0 .. scratch.hist_len - 1]) |*p| {
            if (std.mem.eql(i8, p, &child_pos)) {
                repeats = true;
                break;
            }
        }
        std.debug.print("basic-ko optimal move {s}: PSK-legal? {s}\n", .{
            blk: {
                var vb: [4]u8 = undefined;
                const col: u8 = @intCast('a' + cell % W);
                const rw: u8 = @intCast('a' + cell / W);
                vb[0] = col;
                vb[1] = rw;
                break :blk vb[0..2];
            },
            if (repeats) "NO (would repeat a position — forbidden in frame A)" else "yes",
        });
    }

    // PSK enforcement: the choice the frame-A game actually made
    var s_psk = s;
    s_psk.enforcement = .psk;
    const c_psk = s_psk.choose(side);
    std.debug.print("psk choose: cell={?d} value={d}\n", .{ c_psk.cell, c_psk.value });

    // the committed move at ply 3 (moves[3] = 'bb'? no — moves[3]='bb' is the move AT ply 3)
    std.debug.print("committed move at ply {d}: {s}\n", .{ node_ply, moves[node_ply] });
    try main2(init);
}
