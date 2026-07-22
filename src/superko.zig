////////////////////////////////////////////
//                                        //
//    (c) 2024 Alexander E Genaud         //
//                                        //
//    Permission is granted hereby,       //
//    to copy, share, use, modify,        //
//        for purposes any,               //
//        for free or for money,          //
//    provided these notices multiply.    //
//                                        //
//    This work "as is" I provide,        //
//    no warranty express or implied,     //
//        for, no purpose fit,            //
//        'tis unmerchantable shit.       //
//    Liability for damages denied.       //
//                                        //
////////////////////////////////////////////
//
// Positional superko (see docs/research/ghi-and-superko.md).
//
// A `History` is the stack of whole-board positions along the current game
// line. During search: reset() once, then push() / pop() around each move, and
// reject any candidate for which repeats() is true.
//
//   "the exact board position may never repeat in the same game" (PSK)
//
// Positions are compared by COLOUR (sign), not army-flag magnitude, so the
// same configuration reached via different move orders compares equal. A
// separate Zobrist hash filter could be layered on for speed later; for 5x5
// the lines are short enough that exact comparison is fine.
//
// Optimisation: a whole-board position can only recur after a capture (in
// capture-free play the stone count strictly increases). So `armed` tracks
// whether any capture has occurred at/before each ply, and repeats() skips the
// scan entirely for a plain stone-adding move while the line is still growing.

const std = @import("std");
const assert = std.debug.assert;
const expect = std.testing.expect;
const state = @import("state.zig");

/// Generous upper bound on the length of one 5x5 game line. Overflow asserts
/// (fail loud) rather than silently corrupting superko detection.
pub const MAX_LINE = 4096;

fn stone_count(b: *const [25]i8) u16 {
    var c: u16 = 0;
    for (0..25) |p| {
        if (b[p] != 0) c += 1;
    }
    return c;
}

/// Equal as Go POSITIONS: same colour at every point (magnitudes ignored).
fn same_position(a: *const [25]i8, b: *const [25]i8) bool {
    for (0..25) |p| {
        const sa: i8 = if (a[p] > 0) 1 else if (a[p] < 0) -1 else 0;
        const sb: i8 = if (b[p] > 0) 1 else if (b[p] < 0) -1 else 0;
        if (sa != sb) return false;
    }
    return true;
}

pub const History = struct {
    board: [MAX_LINE][25]i8 = undefined,
    scount: [MAX_LINE]u16 = undefined,
    armed: [MAX_LINE]bool = undefined, // a capture occurred at or before this ply
    len: usize = 0,
    max_len: usize = 0, // deepest `len` ever reached since the last reset (diagnostic)

    pub fn reset(self: *History) void {
        self.len = 0;
        self.max_len = 0;
    }

    pub fn push(self: *History, b: *const [25]i8) void {
        // ALWAYS-LIVE bound (not `assert`): `assert` is a no-op in ReleaseFast,
        // where an overflow would silently corrupt superko detection and poison
        // the oracle. Fail loud in every build instead.
        if (self.len >= MAX_LINE) @panic("superko: game line exceeded MAX_LINE");
        const c = stone_count(b);
        const captured_here = self.len > 0 and c <= self.scount[self.len - 1];
        const armed_before = self.len > 0 and self.armed[self.len - 1];
        self.board[self.len] = b.*;
        self.scount[self.len] = c;
        self.armed[self.len] = captured_here or armed_before;
        self.len += 1;
        if (self.len > self.max_len) self.max_len = self.len;
    }

    pub fn pop(self: *History) void {
        assert(self.len > 0);
        self.len -= 1;
    }

    /// Has any capture happened on the line so far?
    pub fn isArmed(self: *const History) bool {
        return self.len > 0 and self.armed[self.len - 1];
    }

    /// Positional superko: would arriving at board `b` recreate a position
    /// already on this line? (`b` is a candidate not yet pushed.)
    pub fn repeats(self: *const History, b: *const [25]i8) bool {
        return self.repeatsIndex(b) != null;
    }

    /// Like `repeats`, but returns the 0-based history index of the matched
    /// earlier position (null if none). The index is what GHI needs: it tells
    /// the search which prior game-line ply a superko ban depended on, so a
    /// node can decide whether that ban was self-contained (index within its
    /// own subtree) or referenced an ancestor (uncacheable). See
    /// docs/decisions/0005 and docs/research/ghi-and-superko.md.
    pub fn repeatsIndex(self: *const History, b: *const [25]i8) ?usize {
        if (self.len == 0) return null;
        const c = stone_count(b);
        // capture-free growth can never repeat: a plain stone-adding move has
        // more stones than every prior position on an un-armed line.
        if (!self.isArmed() and c > self.scount[self.len - 1]) return null;
        var i: usize = 0;
        while (i < self.len) : (i += 1) {
            if (self.scount[i] == c and same_position(&self.board[i], b)) return i;
        }
        return null;
    }
};

// ---- tests ------------------------------------------------------------------

fn boardOf(occupied: []const struct { usize, i8 }) [25]i8 {
    var b = [_]i8{0} ** 25;
    for (occupied) |o| b[o[0]] = o[1];
    return b;
}

test "growth line never repeats; not armed" {
    var h: History = .{};
    h.reset();
    const b1 = boardOf(&.{.{ 0, 1 }});
    const b2 = boardOf(&.{ .{ 0, 1 }, .{ 1, 1 } });
    const b3 = boardOf(&.{ .{ 0, 1 }, .{ 1, 1 }, .{ 2, -1 } });
    h.push(&b1);
    h.push(&b2);
    h.push(&b3);
    try expect(!h.isArmed());
    const b4 = boardOf(&.{ .{ 0, 1 }, .{ 1, 1 }, .{ 2, -1 }, .{ 3, -1 } });
    try expect(!h.repeats(&b4)); // pure growth
}

test "repeat detected after a capture arms the line" {
    var h: History = .{};
    const b1 = boardOf(&.{.{ 0, 1 }});
    const b2 = boardOf(&.{ .{ 0, 1 }, .{ 1, 1 } });
    const bcap = boardOf(&.{ .{ 0, 1 }, .{ 2, 1 } }); // same count as b2, different -> a capture
    h.push(&b1);
    h.push(&b2);
    h.push(&bcap);
    try expect(h.isArmed());
    // arriving back at b2's position is a superko repeat
    try expect(h.repeats(&b2));
    // a genuinely new same-count position is not
    const other = boardOf(&.{ .{ 0, 1 }, .{ 3, 1 } });
    try expect(!h.repeats(&other));
}

test "comparison is by colour, not army-flag magnitude" {
    var h: History = .{};
    const stored = boardOf(&.{ .{ 0, 2 }, .{ 1, 3 } }); // black armies 2 and 3
    const capture = boardOf(&.{ .{ 5, 1 }, .{ 6, 1 } }); // arm the line
    h.push(&stored);
    h.push(&capture);
    try expect(h.isArmed());
    const same_colours = boardOf(&.{ .{ 0, 1 }, .{ 1, 1 } }); // same position, flags 1
    try expect(h.repeats(&same_colours));
}

test "pop reverts armed state and length" {
    var h: History = .{};
    const b1 = boardOf(&.{.{ 0, 1 }});
    const b2 = boardOf(&.{ .{ 0, 1 }, .{ 1, 1 } });
    const bcap = boardOf(&.{ .{ 0, 1 }, .{ 2, 1 } });
    h.push(&b1);
    h.push(&b2);
    h.push(&bcap);
    try expect(h.isArmed() and h.len == 3);
    h.pop(); // remove the capturing position
    try expect(!h.isArmed() and h.len == 2);
    const b3 = boardOf(&.{ .{ 0, 1 }, .{ 1, 1 }, .{ 4, -1 } });
    try expect(!h.repeats(&b3)); // back in growth regime
}

test "reset clears the line" {
    var h: History = .{};
    const b1 = boardOf(&.{.{ 0, 1 }});
    h.push(&b1);
    h.reset();
    try expect(h.len == 0);
    try expect(!h.repeats(&b1));
}

test "longer cycle (superko, not just simple ko) is caught" {
    var h: History = .{};
    const p0 = boardOf(&.{ .{ 0, 1 }, .{ 1, -1 } });
    const p1 = boardOf(&.{ .{ 0, 1 }, .{ 2, -1 } }); // capture -> arm
    const p2 = boardOf(&.{ .{ 0, 1 }, .{ 3, -1 } });
    h.push(&p0);
    h.push(&p1);
    h.push(&p2);
    try expect(h.isArmed());
    // a move recreating p0 (two plies back beyond the immediate previous) is
    // illegal under superko even though it is not the *immediate* predecessor
    try expect(h.repeats(&p0));
}

test "repeatsIndex reports which ply the ban referenced" {
    var h: History = .{};
    const p0 = boardOf(&.{ .{ 0, 1 }, .{ 1, -1 } });
    const p1 = boardOf(&.{ .{ 0, 1 }, .{ 2, -1 } }); // capture -> arm
    const p2 = boardOf(&.{ .{ 0, 1 }, .{ 3, -1 } });
    h.push(&p0); // index 0
    h.push(&p1); // index 1
    h.push(&p2); // index 2
    try expect(h.repeatsIndex(&p0).? == 0); // recreating p0 matches ply 0
    try expect(h.repeatsIndex(&p1).? == 1);
    const fresh = boardOf(&.{ .{ 0, 1 }, .{ 4, -1 } });
    try expect(h.repeatsIndex(&fresh) == null);
}

test "real ko via armies_from_move: superko rejects the recapture" {
    // ko: white 6 in atari (only liberty 11); black 11's other neighbours
    // (10,12,16) are white, so the capturing stone is itself in atari.
    const W: i8 = -1;
    const p_start = [_]i8{
        0, 1, 0, 0, 0,
        1, W, 1, 0, 0,
        W, 0, W, 0, 0,
        0, W, 0, 0, 0,
        0, 0, 0, 0, 0,
    };
    // black plays 11, capturing white 6
    const p_mid = try state.armies_from_move(&p_start, 1, 11);
    try expect(p_mid[6] == 0);

    var h: History = .{};
    h.push(&p_start);
    h.push(&p_mid);
    try expect(h.isArmed()); // the capture armed the line

    // the game itself allows the recapture (armies_from_move has no ko rule):
    // white plays 6, capturing black 11 -> recreates p_start
    const p_recap = try state.armies_from_move(&p_mid, W, 6);
    try expect(p_recap[11] == 0);
    try expect(same_position(&p_recap, &p_start));
    // positional superko forbids it
    try expect(h.repeats(&p_recap));
}
