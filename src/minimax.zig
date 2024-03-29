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

var seq_next_empty_index: u32 = 0;
var total_minimax_child: u64 = 0;
var total_found_child: u64 = 0;

pub fn init_tables(empty_index: u8) void {
    seq_next_empty_index = empty_index; // TODO 0 means not found
    total_minimax_child = 0;
    total_found_child = 0;
}

pub const seq_score = struct {
    seq: u8 = 0,
    score: i8 = UNDEF,
};

pub fn seq_table_size(max_depth: u8) u32 {
    const ret: u32 = switch (max_depth) { // FIXME 2 * doubled for two 2^25 blind tables
        0 => 1,
        1 => 1 * 10, //    original     10 ok
        2 => 1 * 117, //               117 ok
        3 => 1 * 1_176, //           1_176 ok
        4 => 1 * 12_139, //         12_139 ok
        5 => 1 * 105_583, //       105_583 ok
        6 => 1 * 733_447, //       733_447 ok
        7 => 1 * 3_446_846, //   3_446_846 ok
        8 => 1 * 15_627_565, // 15_627_560 too low, ...565 high
        else => 2 * 15_627_550, // seq is 8 bits max (lower req than 8?)
    };
    return ret;
}

pub fn collision_size(num_stones: u8, max_depth: u8) u8 {
    if (num_stones <= 1) { // 1 bit max 0 (1)
        if (max_depth <= 8) return 1;
        if (max_depth <= 9) return 1;
        if (max_depth <= 10) return 1;
    }
    if (num_stones <= 2) { // 1 bit = 2 = 4/2 patterns 00 01 (10 11)
        if (max_depth <= 8) return 1; // was 3
        if (max_depth <= 9) return 1;
        if (max_depth <= 10) return 1;
    }
    if (num_stones <= 3) { // 2 bit = 4 = 8/2 patterns 000 001 010 011
        if (max_depth <= 4) return 3;
        if (max_depth <= 8) return 4; // was 5
        if (max_depth <= 9) return 4;
        if (max_depth <= 10) return 4;
    }
    if (num_stones <= 4) { // 3 bit = 8 = 16/2 patterns 0xxx
        if (max_depth <= 4) return 3; // was 6
        if (max_depth <= 8) return 6; // was 12
        if (max_depth <= 9) return 6;
        if (max_depth <= 10) return 6;
    }
    if (num_stones <= 5) { // 4 bit = 16 = 32/2 patterns 0 xxxx
        if (max_depth <= 6) return 10; // was 24
        if (max_depth <= 7) return 12; // was 24
        if (max_depth <= 8) return 14; // was 24
        if (max_depth <= 9) return 14;
        if (max_depth <= 10) return 14;
    }
    if (num_stones <= 6) { // 5 bit = 32 = 64/2 patterns 0 xxxx x
        if (max_depth <= 6) return 10; // was 24
        if (max_depth <= 8) return 23; // was 44
        if (max_depth <= 9) return 23;
        if (max_depth <= 10) return 23;
    }
    if (num_stones <= 7) { // 6 bit = 64 = 128/2 patterns 0 xxxx xx
        if (max_depth <= 8) return 35; // was 64
        if (max_depth <= 9) return 35;
        if (max_depth <= 10) return 35;
    }
    if (num_stones <= 8) { // 7 bit = 128 = 256/2 patterns 0 xxxx xxx
        if (max_depth <= 8) return 35; // was 77
        if (max_depth <= 9) return 35;
        if (max_depth <= 10) return 35;
    }
    print("\nFAIL: collision_size(num_stones={}, max_depth={})\n\n", .{
        num_stones,
        max_depth,
    });
    unreachable; // 9 bit stone seq not yet supported
}

test "new sizes" {
    const max_depth: u8 = 2;
    const global = struct {
        var black_table = [_]u32{0} ** (1 << 25);
        var white_table = [_]u32{0} ** (1 << 25);
        var seq_table = [_]seq_score{.{}} ** seq_table_size(max_depth);
    };
    init_tables(0);
    var root_score = minimax(
        &[_]i8{0} ** 25,
        -1,
        &global.black_table,
        &global.white_table,
        &global.seq_table,
        0,
        max_depth,
    );
    print("end with max_depth={} seq_table_size={} minimax/found={} % root_score={}\n", .{
        max_depth,                                           seq_table_size(max_depth),
        100 * total_minimax_child / (total_found_child + 1), root_score,
    });
}

pub fn main() !void {
    const max_depth: u8 = 6;
    const global = struct {
        var black_table = [_]u32{0} ** (1 << 25);
        var white_table = [_]u32{0} ** (1 << 25);
        var seq_table = [_]seq_score{.{}} ** seq_table_size(max_depth);
    };
    init_tables(0);
    print("start with max_depth={} seq_table_size={}\n", .{
        max_depth,
        seq_table_size(max_depth),
    });
    const board = [_]i8{0} ** 25;
    var root_score = minimax(
        &board,
        -1,
        &global.black_table,
        &global.white_table,
        &global.seq_table,
        0,
        max_depth,
    );
    print("completed with root score={}\n", .{root_score});
    print("end with max_depth={} seq_table_size={} minimax/found={} %\n", .{
        max_depth,
        seq_table_size(max_depth),
        100 * total_minimax_child / (total_found_child + 1),
    });
}

test "get undefined game score" {
    const global = struct {
        var black_table = [_]u32{0} ** (1 << 25);
        var white_table = [_]u32{0} ** (1 << 25);
        var seq_table = [_]seq_score{.{}} ** seq_table_size(3);
    };
    init_tables(0);
    _ = minimax(&[_]i8{0} ** 25, -1, &global.black_table, &global.white_table, &global.seq_table, 0, 0);
    try expect(UNDEF == get_game_score(&[_]i8{
        1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    }, 1, &global.black_table, &global.white_table, &global.seq_table, 3));
}

test "set inverse ten score" {
    const max_depth: u8 = 1;
    const global = struct {
        var black_table = [_]u32{0} ** (1 << 25);
        var white_table = [_]u32{0} ** (1 << 25);
        var seq_table = [_]seq_score{.{}} ** seq_table_size(max_depth);
    };
    init_tables(0);
    _ = minimax(&[_]i8{0} ** 25, -1, &global.black_table, &global.white_table, &global.seq_table, 0, 0);
    const W: i8 = -1;
    var board_1w = [_]i8{
        1, W, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    };
    var score_for_white = set_game_score(
        &board_1w,
        W, // <---- white last move
        10, // <--- set 10 score
        &global.black_table,
        &global.white_table,
        &global.seq_table,
        max_depth,
    );
    try expect(10 == score_for_white);
    score_for_white = get_game_score(
        &board_1w, // <-- same board
        W, // <---------- white last move
        &global.black_table,
        &global.white_table,
        &global.seq_table,
        max_depth,
    );
    try expect(10 == score_for_white);

    // get the inverse
    var board_w1 = [_]i8{
        W, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    };
    var score_for_black = get_game_score(
        &board_w1, // <-- inverted board
        1, // <---- black last move (invert player)
        &global.black_table,
        &global.white_table,
        &global.seq_table,
        max_depth,
    );
    try expect(-10 == score_for_black); // invert score
}

test "set inverse zero score" {
    const max_depth: u8 = 1;
    const global = struct {
        var black_table = [_]u32{0} ** (1 << 25);
        var white_table = [_]u32{0} ** (1 << 25);
        var seq_table = [_]seq_score{.{}} ** seq_table_size(max_depth);
    };
    init_tables(0);
    _ = minimax(&[_]i8{0} ** 25, -1, &global.black_table, &global.white_table, &global.seq_table, 0, 0);
    const W: i8 = -1;
    var board_1w = [_]i8{
        1, W, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    };
    var score_for_white = set_game_score(
        &board_1w,
        W, // <---- white last move
        0, // <--- set 0 score
        &global.black_table,
        &global.white_table,
        &global.seq_table,
        max_depth,
    );
    try expect(0 == score_for_white);
    score_for_white = get_game_score(
        &board_1w, // <-- same board
        W, // <---------- white last move
        &global.black_table,
        &global.white_table,
        &global.seq_table,
        max_depth,
    );
    try expect(0 == score_for_white);

    // get the inverse
    var board_w1 = [_]i8{
        W, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    };
    var score_for_black = get_game_score(
        &board_w1,
        1, // <---- black last move
        &global.black_table,
        &global.white_table,
        &global.seq_table,
        max_depth,
    );
    try expect(0 == score_for_black);
}

test "black traps white" {
    const max_depth: u8 = 5; // 6 to learn all captures
    const global = struct {
        var black_table = [_]u32{0} ** (1 << 25);
        var white_table = [_]u32{0} ** (1 << 25);
        var seq_table = [_]seq_score{.{}} ** seq_table_size(max_depth);
    };
    init_tables(0);
    const W: i8 = -1;
    _ = minimax(
        &[_]i8{0} ** 25,
        W, // black next to play
        &global.black_table,
        &global.white_table,
        &global.seq_table,
        0,
        max_depth,
    );

    var good_score_black = get_game_score(
        &[_]i8{
            0, 0, 0, 0, 0,
            0, 0, 0, 0, 0,
            0, 0, 0, 0, 0,
            0, 1, 0, 0, 0,
            W, 0, 0, 0, 0,
        },
        W, // white played last, black to play next
        &global.black_table,
        &global.white_table,
        &global.seq_table,
        max_depth,
    );

    //print("\nwhite is trapped and black to play: {}\n", .{good_score_black});
    try expect(good_score_black > 1);

    var bad_score_black = get_game_score(
        &[_]i8{
            0, 0, 0, 0, 0,
            0, 0, 0, 0, 0,
            0, 0, 0, 0, 0,
            0, W, 0, 0, 0,
            1, 0, 0, 0, 0,
        },
        1, // black played last, white to play next
        &global.black_table,
        &global.white_table,
        &global.seq_table,
        max_depth,
    );

    //print("black is trapped and white to play: {}\n", .{bad_score_black});
    try expect(bad_score_black <= good_score_black);
    try expect(bad_score_black == 0 - good_score_black);

    var little_white_hope = get_game_score(
        &[_]i8{
            0, 0, 0, 0, 0,
            0, 0, 0, 0, 0,
            0, 0, 0, 0, 0,
            0, W, 0, 0, 0,
            1, 0, 0, 0, 0,
        },
        W, // white played last, black to play next
        &global.black_table,
        &global.white_table,
        &global.seq_table,
        max_depth,
    );

    //print("black is trapped, black to play with little hope: {}\n", .{little_white_hope});
    try expect(little_white_hope <= good_score_black);
    try expect(little_white_hope > 0 - good_score_black);
}

pub fn get_game_score(
    pos: *const [25]i8,
    color: i8,
    black_table: []u32,
    white_table: []u32,
    seq_table: []seq_score,
    max_depth: u8,
) i8 {
    // start new lowest sequence
    var lowest = state.lowest_blind_from_pos(pos);
    var is_inverse: bool = false;
    var is_black = color;
    var sequence = lowest.seq;
    //if (lowest.diff < 0 or (lowest.diff == 0 and lowest.inverse_seq < lowest.seq)) {
    if (lowest.diff == 0 and lowest.inverse_seq < lowest.seq) {
        is_inverse = true;
        is_black = -color;
        sequence = lowest.inverse_seq;
    }
    // end new lowest sequence

    var seq_block_size = collision_size(lowest.num_stones, max_depth);
    var seq_block_start = if (is_black > 0)
        black_table[lowest.blind]
    else
        white_table[lowest.blind];
    if (seq_block_start == 0) return UNDEF;
    var i = seq_block_start;
    var seq_block_end = i + seq_block_size;
    while (i < seq_block_end) : (i += 1) {
        var curr = &seq_table[i];
        if (curr.seq == sequence or curr.score == UNDEF) {
            if (curr.score == UNDEF) return UNDEF;
            return if (is_inverse) -curr.score else curr.score;
        }
    }
    return UNDEF;
}

pub fn set_game_score(
    pos: *const [25]i8,
    color: i8,
    score: i8,
    black_table: []u32,
    white_table: []u32,
    seq_table: []seq_score,
    max_depth: u8,
) i8 {
    // start new lowest sequence
    var lowest = state.lowest_blind_from_pos(pos);
    var is_inverse: bool = false;
    var is_black = color;
    var sequence = lowest.seq;
    var score_to_set = score;
    //if (lowest.diff < 0 or (lowest.diff == 0 and lowest.inverse_seq < lowest.seq)) {
    if (lowest.diff == 0 and lowest.inverse_seq < lowest.seq) {
        is_inverse = true;
        is_black = -color;
        sequence = lowest.inverse_seq;
        score_to_set = if (score == UNDEF) UNDEF else -score;
    }
    // end new lowest sequence

    var seq_block_size = collision_size(lowest.num_stones, max_depth);
    var seq_block_start = if (is_black > 0)
        black_table[lowest.blind]
    else
        white_table[lowest.blind];

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

        if (is_black > 0) {
            black_table[lowest.blind] = seq_next_empty_index;
        } else {
            white_table[lowest.blind] = seq_next_empty_index;
        }

        // move the index forward for the next seq_block
        seq_next_empty_index += seq_block_size;
    }

    // search for seq (of black-white-black... patterns)
    // from seq_block_start to seq_block_end
    var i = seq_block_start;
    var seq_block_end = i + seq_block_size;
    while (i < seq_block_end) : (i += 1) {
        var curr = &seq_table[i];
        if (curr.seq != sequence and curr.score != UNDEF) {
            continue; // around again
        }
        if ((curr.seq == sequence and curr.score == score_to_set) or
            curr.score == UNDEF)
        {
            curr.seq = sequence;
            curr.score = score_to_set;
            return score; // original score
        }
    }
    print(
        "Uh oh! found blind={} of num_stones={} and block seq={} " ++
            "but no space in seq_block_size={}\n",
        .{
            lowest.blind,
            lowest.num_stones,
            sequence,
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

test "weighted score with komi" {
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

pub fn wt_score_no_komi(diff: i8, count: u8) i8 {
    if (count <= 1) return 0;
    var neg: i8 = if (diff < 0) -1 else 1;
    var weight = 66 *
        @as(f64, @floatFromInt(neg * (2 * diff))) /
        @as(f64, @floatFromInt(count + 1));
    return neg * @as(i8, @intFromFloat(weight));
}

test "weighted score no komi" {
    try expect(wt_score_no_komi(0, 0) == 0);
    try expect(wt_score_no_komi(1, 1) == 0);

    try expect(wt_score_no_komi(0, 2) >= -21);
    try expect(wt_score_no_komi(0, 3) >= -16);
    try expect(wt_score_no_komi(0, 4) >= -12);
    try expect(wt_score_no_komi(1, 2) >= 21);
    try expect(wt_score_no_komi(1, 3) >= 16);
    try expect(wt_score_no_komi(1, 4) >= 12);
    try expect(wt_score_no_komi(2, 2) >= 48);
    try expect(wt_score_no_komi(2, 3) >= 48);
    try expect(wt_score_no_komi(2, 4) >= 38);
    try expect(wt_score_no_komi(2, 5) >= 32);
    try expect(wt_score_no_komi(25, 25) >= 0);
    try expect(wt_score_no_komi(-25, 25) <= 0);
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
    black_table: []u32,
    white_table: []u32,
    seq_table: []seq_score,
    depth: u8,
    max_depth: u8,
) i8 {
    var score: i8 = pos_score(pos);
    if (depth > 8) { // FIXME cannot set seq more than 8 bits
        return score;
    }
    if (score < -25 or score > 25 or depth >= max_depth) { // game over
        //print("depth={} score={}\n", .{ depth, score });
        //state.print_armies(pos);
        return set_game_score(
            pos,
            color,
            score,
            black_table,
            white_table,
            seq_table,
            max_depth,
        );
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
            get_game_score(
                &child,
                -color,
                black_table,
                white_table,
                seq_table,
                max_depth,
            )
        else
            UNDEF;

        if (child_score == UNDEF) {
            total_minimax_child += 1;
            child_score = minimax(
                &child,
                -color,
                black_table,
                white_table,
                seq_table,
                depth + 1,
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
        color,
        val,
        black_table,
        white_table,
        seq_table,
        max_depth,
    ) else val;
}
