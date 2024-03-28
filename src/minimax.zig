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
const std = @import("std");
const print = std.debug.print;
const expect = std.testing.expect;

const state = @import("state.zig");

const util = @import("util.zig");
const max2 = util.max2;
const min2 = util.min2;
const UNDEF = util.UNDEF;

// MAX_DEPTH = 1 COLLISION_SIZE =  1 TABLE_SIZE =      10
// MAX_DEPTH = 2 COLLISION_SIZE =  2 TABLE_SIZE =     140
// MAX_DEPTH = 3 COLLISION_SIZE =  3 TABLE_SIZE =    1281
// MAX_DEPTH = 4 COLLISION_SIZE =  6 TABLE_SIZE =   13140
// MAX_DEPTH = 5 COLLISION_SIZE = 12 TABLE_SIZE =  110604
// MAX_DEPTH = 6 COLLISION_SIZE = 24 TABLE_SIZE =  744321
// MAX_DEPTH = 7 COLLISION_SIZE = 47 TABLE_SIZE = 3786648 ?
const MAX_DEPTH = 7;
const COLLISION_SIZE = 24; // safe collision if too small
const TABLE_SIZE = 3744321; // 24 * 157777; // crash if too small
// 137777 too small

var blind_table = [_]u32{0} ** 33_554_432; // 2^25
var seq_next_empty_index: u32 = 0;
pub const seq_score = struct {
    seq: u8 = 0,
    score: i8 = UNDEF,
};

var seq_table = [_]seq_score{.{}} ** TABLE_SIZE;
//var zero_empty = &seq_table[0];

pub fn collision_size(num_stones: u8) u8 {
    if (num_stones <= 1) { // x 1 bit max
        if (MAX_DEPTH <= 8) return 1;
    }
    if (num_stones <= 2) { // xx 2 bit 4 patterns
        if (MAX_DEPTH <= 2) return 2;
        if (MAX_DEPTH <= 8) return 3;
    }
    if (num_stones <= 3) {
        if (MAX_DEPTH <= 3) return 3;
        if (MAX_DEPTH <= 6) return 5;
        if (MAX_DEPTH <= 8) return 5;
    }
    if (num_stones <= 4) {
        if (MAX_DEPTH <= 4) return 6;
        if (MAX_DEPTH <= 6) return 12;
        if (MAX_DEPTH <= 8) return 12;
    }
    if (num_stones <= 5) {
        if (MAX_DEPTH <= 5) return 12;
        if (MAX_DEPTH <= 6) return 24;
        if (MAX_DEPTH <= 7) return 27; // [27 - ?
        if (MAX_DEPTH <= 8) return 26;
    }
    if (num_stones <= 6) {
        if (MAX_DEPTH <= 6) return 24;
        if (MAX_DEPTH <= 7) return 47; // [47 - 48?
        if (MAX_DEPTH <= 8) return 24;
    }
    if (num_stones <= 7) {
        if (MAX_DEPTH <= 7) return 37; // [37 < 40?
        if (MAX_DEPTH <= 8) return 36;
    }
    if (num_stones <= 8) {
        if (MAX_DEPTH <= 8) return 24;
    }
    unreachable;
}

pub fn get_game_score(pos: *const [25]i8) i8 {
    var lowest = state.lowest_blind_from_pos(&pos);
    var seq_block_size = collision_size(lowest.num_stones);
    var seq_block_start = blind_table[lowest.blind];
    if (seq_block_start == 0) return UNDEF;
    var i = seq_block_start;
    var seq_block_end = i + seq_block_size;
    while (i < seq_block_end) : (i += 1) {
        var curr = &seq_table[i];
        if (curr.seq == lowest.seq or curr.score == UNDEF) {
            return curr.score;
        }
    }
    return UNDEF;
}

pub fn set_game_score(pos: *const [25]i8, score: i8) i8 {
    var lowest = state.lowest_blind_from_pos(pos);
    var seq_block_size = collision_size(lowest.num_stones);

    var seq_block_start = blind_table[lowest.blind];
    if (seq_block_start == 0) {
        // create seq_block if does not yet exist
        if (seq_next_empty_index + seq_block_size > seq_table.len) {
            print("Uh oh! we have run out of space " ++
                "while setting num={}\n", .{
                lowest.num_stones,
            });
            state.print_armies(&lowest.pos);
        }
        seq_block_start = seq_next_empty_index;
        blind_table[lowest.blind] = seq_next_empty_index;
        // move the index forward for the next seq_block
        seq_next_empty_index += seq_block_size;
    }

    // search for seq (of black-white-black... patterns)
    // from seq_block_start to seq_block_end
    var i = seq_block_start;
    var seq_block_end = i + seq_block_size;
    while (i < seq_block_end) : (i += 1) {
        var curr = &seq_table[i];
        if (curr.seq != lowest.seq and curr.score != UNDEF) {
            continue; // around again
        }
        if (curr.seq == lowest.seq and curr.score == score) {
            return curr.score; // happy case
        }
        if (curr.score == UNDEF) {
            curr.seq = lowest.seq; // new entry
            curr.score = score;
            return score;
        }
    }
    print(
        "Uh oh! found blind={} of num_stones={} and block seq={} " ++
            "but no space to put score={} in seq_block_size={}\n",
        .{
            lowest.blind,
            lowest.num_stones,
            lowest.seq,
            score,
            seq_block_size,
        },
    );
    state.print_armies(&lowest.pos);
    return UNDEF;
}

test "blind size" {
    var all_black = [_]i8{1} ** 25; // 2^25
    try expect(33_554_432 - 1 == state.blind_from_pos(&all_black));
}

// komi 0.5
// black is penalized a stone and
// must have two stones more than white to be ahead
// A score above 25 could be considered a a good lead
// scores roughly between -126 to +126 for total board captures.
// score is relative to number of stones on the board
// with a bias toward
// large late captures rather than small early captures.
// a very early capture is 64 points, then 48, 38
// and an early double capture is 80 points.
// earliest triple capture in the corner is 112 points
pub fn wt_score(diff: i8, count: u8) i8 {
    if (count <= 1) return 0;
    var neg: i8 = if (diff < 0) -1 else 1;
    var weight = 64 *
        @as(f64, @floatFromInt(neg * (2 * diff - 1))) /
        @as(f64, @floatFromInt(count + 1));
    var res: i8 = neg * @as(i8, @intFromFloat(weight));
    // if (res <= -81 or res >= 81) {
    //     print("\n{} / {} = {}\n", .{ diff, count, res });
    // }
    return res;
}

test "weighted score" {
    try expect(wt_score(0, 0) == 0);
    try expect(wt_score(1, 1) == 0);

    try expect(wt_score(0, 2) >= -21);
    try expect(wt_score(0, 3) >= -16);
    try expect(wt_score(0, 4) >= -12);
    try expect(wt_score(1, 2) >= 21);
    try expect(wt_score(1, 3) >= 16);
    try expect(wt_score(1, 4) >= 12);
    try expect(wt_score(2, 2) >= 48);
    try expect(wt_score(2, 3) >= 48);
    try expect(wt_score(2, 4) >= 38);
    try expect(wt_score(2, 5) >= 32);
    try expect(wt_score(25, 25) >= 0);
    try expect(wt_score(-25, 25) <= 0);

    for (0..25) |d| {
        var i: i8 = @intCast(d);
        var u: u8 = @intCast(d);
        try expect(wt_score(i, u) >= 0);
        try expect(wt_score(-i, u) <= 0);
        try expect(wt_score(i + 1, u) == -wt_score(-i, u));
        try expect(wt_score(i, u) == -wt_score(1 - i, u));
    }
}

// black must have two stones more than white to be ahead
// +/- 25 is a strong score, +/- 100 is total dominance
pub fn pos_score(pos: *const [25]i8) i8 {
    var diff = state.stone_diff_from_pos(pos);
    var count = state.stone_count_from_pos(pos);
    return wt_score(diff, count);
}

pub fn minimax(
    pos: *const [25]i8,
    color: i8,
    depth: u8,
) i8 {
    var score: i8 = pos_score(pos);
    if (score < -25 or score > 25 or depth >= MAX_DEPTH) { // game over
        //print("depth={} score={}\n", .{ depth, score });
        //state.print_armies(pos);
        return set_game_score(pos, score);
    }
    var val: i8 = if (color > 0) 99 else -99;
    var child_cnt: u8 = 0;
    for (0..25) |p| { // FIXME try ..8 for now, but should be 25
        if (pos[p] != 0) continue;
        //print("loop --- color={} depth={} check p={}\n", .{ color, depth, p });
        child_cnt += 1;

        var child: [25]i8 = state.armies_from_move(
            pos,
            -color,
            @intCast(p),
        ) catch continue;

        var child_score = minimax(&child, -color, depth + 1);
        val = if (color > 0)
            min2(val, child_score)
        else
            max2(val, child_score);
    }

    if (child_cnt == 0) val = pos_score(pos);
    if (depth == 6 and (val >= 65 or val <= -65)) {
        print("-- depth {} -- score: {}\n", .{ depth, val });
        state.print_armies(pos);
    }
    return set_game_score(pos, val);
}

pub fn main() !void {
    print("start with MAX_DEPTH={} COLLISION_SIZE={} TABLE_SIZE={}\n", .{
        MAX_DEPTH,
        COLLISION_SIZE,
        TABLE_SIZE,
    });
    const board = [_]i8{0} ** 25;
    var root_score = minimax(&board, -1, 0);
    print("completed with root score={}\n", .{root_score});
    print("end with MAX_DEPTH={} COLLISION_SIZE={} TABLE_SIZE={}\n", .{
        MAX_DEPTH,
        COLLISION_SIZE,
        TABLE_SIZE,
    });
}
