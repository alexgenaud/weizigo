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

pub fn seq_table_size(max_depth: u8) u32 {
    return switch (max_depth) {
        1 => 10, //    original     10 ok
        2 => 117, //               117 ok
        3 => 1_176, //           1_176 ok
        4 => 12_139, //         12_139 ok
        5 => 105_583, //       105_583 ok
        6 => 733_447, //       733_447 ok
        7 => 3_446_846, //   3_446_846 ok
        8 => 15_627_565, // 15_627_560 too low, ...565 high
        else => 15_627_550, // seq is 8 bits max (lower req than 8?)
    };
}

pub fn main() !void {
    const max_depth: u8 = 9;
    const global = struct {
        var blind_array = [_]u32{0} ** (1 << 25);
        var seq_table = [_]seq_score{.{}} ** seq_table_size(max_depth);
    };
    print("start with max_depth={} seq_table_size={}\n", .{
        max_depth,
        seq_table_size(max_depth),
    });
    const board = [_]i8{0} ** 25;
    var root_score = minimax(
        &board,
        -1,
        0,
        &global.blind_array,
        &global.seq_table,
        max_depth,
    );
    print("completed with root score={}\n", .{root_score});
    print("end with max_depth={} seq_table_size={} minimax/found={} %\n", .{
        max_depth,
        seq_table_size(max_depth),
        100 * total_minimax_child / (total_found_child + 1),
    });
}

test "black traps white" {
    const max_depth: u8 = 5;
    const global = struct {
        var blind_array = [_]u32{0} ** (1 << 25);
        var seq_table = [_]seq_score{.{}} ** seq_table_size(max_depth);
    };
    const W: i8 = -1;
    _ = minimax(&[_]i8{
        0, 0, 0, 0, 0,
        0, 0, 0, 0, 0,
        0, 0, 0, 0, 0,
        0, 0, 0, 0, 0,
        0, 0, 0, 0, 0,
    }, -1, 0, &global.blind_array, &global.seq_table, max_depth);

    var good_score_black = get_game_score(&[_]i8{
        0, 0, 0, 0, 0,
        0, 0, 0, 0, 0,
        0, 0, 0, 0, 0,
        0, 1, 0, 0, 0,
        W, 0, 0, 0, 0,
    }, &global.blind_array, &global.seq_table, max_depth);

    print("score after black trap white {}\n", .{good_score_black});
    try expect(good_score_black > 1);

    var bad_score_black = get_game_score(&[_]i8{
        0, 0, 0, 0, 0,
        0, 0, 0, 0, 0,
        0, 0, 0, 0, 0,
        0, W, 0, 0, 0,
        1, 0, 0, 0, 0,
    }, &global.blind_array, &global.seq_table, max_depth);

    print("score after white traps black {}\n", .{bad_score_black});
    try expect(bad_score_black < good_score_black);
}

var seq_next_empty_index: u32 = 0;
pub const seq_score = struct {
    seq: u8 = 0,
    score: i8 = UNDEF,
};

pub fn collision_size(num_stones: u8, max_depth: u8) u8 {
    if (num_stones <= 1) { // x 1 bit max
        if (max_depth <= 8) return 1;
        if (max_depth <= 9) return 1;
    }
    if (num_stones <= 2) { // xx 2 bit 4 patterns
        if (max_depth <= 2) return 2;
        if (max_depth <= 8) return 3;
        if (max_depth <= 9) return 3;
    }
    if (num_stones <= 3) {
        if (max_depth <= 3) return 3;
        if (max_depth <= 8) return 5;
        if (max_depth <= 9) return 5;
    }
    if (num_stones <= 4) {
        if (max_depth <= 4) return 6;
        if (max_depth <= 8) return 12;
        if (max_depth <= 9) return 12;
    }
    if (num_stones <= 5) {
        if (max_depth <= 5) return 12;
        if (max_depth <= 6) return 24;
        if (max_depth <= 8) return 24;
        if (max_depth <= 9) return 24;
    }
    if (num_stones <= 6) {
        if (max_depth <= 6) return 24;
        if (max_depth <= 8) return 44; // 45 ok
        if (max_depth <= 9) return 44; // 45 ok
    }
    if (num_stones <= 7) {
        if (max_depth <= 7) return 37;
        if (max_depth <= 8) return 64; // 64 required
        if (max_depth <= 9) return 64; // 64 required
    }
    if (num_stones <= 8) {
        if (max_depth <= 8) return 77; // 78 ok
        if (max_depth <= 9) return 77; // 78 ok
    }
    unreachable; // 9 bit stone seq not supported
}

pub fn get_game_score(
    pos: *const [25]i8,
    blind_table: []u32,
    seq_table: []seq_score,
    max_depth: u8,
) i8 {
    var lowest = state.lowest_blind_from_pos(pos);
    var seq_block_size = collision_size(lowest.num_stones, max_depth);
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

pub fn set_game_score(
    pos: *const [25]i8,
    score: i8,
    blind_table: []u32,
    seq_table: []seq_score,
    max_depth: u8,
) i8 {
    var lowest = state.lowest_blind_from_pos(pos);
    var seq_block_size = collision_size(lowest.num_stones, max_depth);
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

var total_minimax_child: u64 = 0;
var total_found_child: u64 = 0;
pub fn minimax(
    pos: *const [25]i8,
    color: i8,
    depth: u8,
    blind_table: []u32,
    seq_table: []seq_score,
    max_depth: u8,
) i8 {
    var score: i8 = pos_score(pos);
    if (depth > 8) { // FIXME cannot set seq more than 8 bits
        return score;
    }
    if (score < -25 or score > 25 or depth >= max_depth) { // game over
        //print("depth={} score={}\n", .{ depth, score });
        //state.print_armies(pos);
        return set_game_score(pos, score, blind_table, seq_table, max_depth);
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

        var child_score = if (depth < 8)
            get_game_score(&child, blind_table, seq_table, max_depth)
        else
            UNDEF;

        if (child_score == UNDEF) {
            total_minimax_child += 1;
            child_score = minimax(
                &child,
                -color,
                depth + 1,
                blind_table,
                seq_table,
                max_depth,
            );
        } else total_found_child += 1;

        val = if (color > 0)
            min2(val, child_score)
        else
            max2(val, child_score);
    }

    if (child_cnt == 0) val = -pos_score(pos);

    if ((depth == 3 and (val >= 90 or val <= -90))) {
        print("-- depth {} -- score: {} minimax/found={} %\n", .{
            depth,
            val,
            100 * total_minimax_child / (total_found_child + 1),
        });
        state.print_armies(pos);
    }
    return if (depth < 8) set_game_score(
        pos,
        val,
        blind_table,
        seq_table,
        max_depth,
    ) else val;
}
