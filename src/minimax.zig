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

const std = @import("std");
const print = std.debug.print;
const assert = std.debug.assert;
const expect = std.testing.expect;

const state = @import("state.zig");

const util = @import("util.zig");
const max2 = util.max2;
const min2 = util.min2;
const UNDEF = util.UNDEF;
const LOSS_FOR_BLACK = util.LOSS_FOR_BLACK;
const LOSS_FOR_WHITE = util.LOSS_FOR_WHITE;

const LAST_SAVE_DEPTH: u8 = 8;

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

pub fn seq_table_size(num_positions: u8, max_depth: u8) u32 {
    if (num_positions <= 6) {
        const ret: u32 = switch (max_depth) { // FIXME 2 * doubled for two 2^25 blind tables
            0 => 3,
            1 => 10, //
            2 => 117, //
            3 => 100, //
            4 => 100, //
            5 => 100, //
            6 => 100, //
            7 => 10000, //
            8 => 10000, //
            else => 100, //
        };
        return ret;
    }

    if (num_positions <= 9) {
        const ret: u32 = switch (max_depth) { // FIXME 2 * doubled for two 2^25 blind tables
            0 => 3,
            1 => 10, //
            2 => 117, //
            3 => 100, //
            4 => 100, //
            5 => 100, //
            6 => 100, //
            7 => 10000, //
            8 => 10000, //
            else => 10000, //
        };
        return ret;
    }

    if (num_positions <= 25) {
        const ret: u32 = switch (max_depth) { // FIXME 2 * doubled for two 2^25 blind tables
            0 => 3,
            1 => 3 * 10, //    original     10 ok
            2 => 3 * 117, //               117 ok
            3 => 3 * 1_176, //           1_176 ok
            4 => 3 * 12_139, //         12_139 ok
            5 => 3 * 105_583, //       105_583 ok
            6 => 9 * 733_447, //       733_447 ok
            7 => 4 * 3_446_846, //   3_446_846 ok
            8 => 3 * 15_627_565, // 15_627_560 too low, ...565 high
            else => 3 * 15_627_550, // seq is 8 bits max (lower req than 8?)
        };
        return ret;
    }
    unreachable;
}

pub fn variable_collision_size(num_stones: u8, max_depth: u8) u8 {
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

pub fn collision_size(num_stones: u8, max_depth: u8) u8 {
    if (num_stones <= 1) { // 1 bit max 0 (1)
        if (max_depth <= 10) return 1;
    }
    if (num_stones <= 2) { // 1 bit = 2 = 4/2 patterns 00 01 (10 11)
        if (max_depth <= 10) return 1;
    }
    if (num_stones <= 3) { // 2 bit = 4 = 8/2 patterns 000 001 010 011
        if (max_depth <= 10) return 4;
    }
    if (num_stones <= 4) { // 3 bit = 8 = 16/2 patterns 0xxx
        if (max_depth <= 5) return 6;
        if (max_depth <= 10) return 6;
    }
    if (num_stones <= 5) { // 4 bit = 16 = 32/2 patterns 0 xxxx
        if (max_depth <= 10) return 16;
    }
    if (num_stones <= 6) { // 5 bit = 32 = 64/2 patterns 0 xxxx x
        if (max_depth <= 10) return 32;
    }
    if (num_stones <= 7) { // 6 bit = 64 = 128/2 patterns 0 xxxx xx
        if (max_depth <= 10) return 64;
    }
    if (num_stones <= 8) { // 7 bit = 128 = 256/2 patterns 0 xxxx xxx
        if (max_depth <= 10) return 128;
    }
    print("\nFAIL: collision_size(num_stones={}, max_depth={})\n\n", .{
        num_stones,
        max_depth,
    });
    unreachable; // 9 bit stone seq not yet supported
}

test "new sizes" {
    const max_depth: u8 = 4;
    const global = struct {
        var black_table = [_]u32{0} ** (1 << 25);
        var white_table = [_]u32{0} ** (1 << 25);
        var seq_table = [_]seq_score{.{}} ** seq_table_size(25, max_depth);
    };
    init_tables(0);
    minimax5x5(&global.black_table, &global.white_table, &global.seq_table, max_depth);
    print("end with max_depth={} seq_table_size={} minimax/found={} %\n", .{
        max_depth,
        seq_table_size(25, max_depth),
        100 * total_minimax_child / (total_found_child + 1),
    });
}

test "capture 3x3" {
    const max_depth: u8 = 7;
    const global = struct {
        var black_table = [_]u32{0} ** (1 << 25);
        var white_table = [_]u32{0} ** (1 << 25);
        var seq_table = [_]seq_score{.{}} ** seq_table_size(9, max_depth);
    };
    init_tables(0);
    minimax3x3(&global.black_table, &global.white_table, &global.seq_table, max_depth);
    const W: i8 = -1;
    const B: i8 = 1;

    var score = get_game_score(&[_]i8{0} ** 25, B, // white to play on empty board
        &global.black_table, &global.white_table, &global.seq_table, max_depth);
    try expect(score == UNDEF);

    score = get_game_score(&[_]i8{0} ** 25, W, // black to play on empty board
        &global.black_table, &global.white_table, &global.seq_table, max_depth);
    try expect(score > -99 and score < 99);

    score = get_game_score(&[_]i8{
        0, B, 0, 0, 0, // single black stone top mid
        0, 0, 0, 0, 0,
        0, 0, 0, 0, 0,
        0, 0, 0, 0, 0,
        0, 0, 0, 0, 0,
    }, B, // white to play
        &global.black_table, &global.white_table, &global.seq_table, max_depth);
    try expect(score > -9 and score < 0);

    score = get_game_score(&[_]i8{
        0, 1, W, 0, 0, // black in the corner
        0, 1, 0, 0, 0,
        1, 0, 0, 0, 0,
        0, 0, 0, 0, 0,
        0, 0, 0, 0, 0,
    }, W, // white to play
        &global.black_table, &global.white_table, &global.seq_table, max_depth);
    try expect(score > 1 and score < 125);
}

pub fn main() !void {
    const max_depth: u8 = 4;
    const global = struct {
        var black_table = [_]u32{0} ** (1 << 25);
        var white_table = [_]u32{0} ** (1 << 25);
        var seq_table = [_]seq_score{.{}} ** seq_table_size(25, max_depth);
    };
    init_tables(0);

    minimax5x5(&global.black_table, &global.white_table, &global.seq_table, max_depth);
}

test "get undefined game score" {
    const global = struct {
        var black_table = [_]u32{0} ** (1 << 25);
        var white_table = [_]u32{0} ** (1 << 25);
        var seq_table = [_]seq_score{.{}} ** seq_table_size(3, 0);
    };
    init_tables(0);
    minimax2x2(&global.black_table, &global.white_table, &global.seq_table, 0);
    try expect(UNDEF == get_game_score(&[_]i8{
        1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    }, 1, &global.black_table, &global.white_table, &global.seq_table, 3));
}

test "set inverse ten score" {
    const max_depth: u8 = 3;
    const global = struct {
        var black_table = [_]u32{0} ** (1 << 25);
        var white_table = [_]u32{0} ** (1 << 25);
        var seq_table = [_]seq_score{.{}} ** seq_table_size(25, max_depth);
    };
    init_tables(0);
    const W: i8 = -1;
    minimax2x2(&global.black_table, &global.white_table, &global.seq_table, 1);
    var board_1w = [_]i8{
        1, W, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    };
    try expect(10 == set_game_score(
        &board_1w,
        W, // <---- white last move
        10, // <--- set 10 score
        &global.black_table,
        &global.white_table,
        &global.seq_table,
        max_depth,
    ));
    try expect(10 == get_game_score(
        &board_1w, // <-- same board
        W, // <---------- white last move
        &global.black_table,
        &global.white_table,
        &global.seq_table,
        max_depth,
    ));
    try expect(UNDEF == get_game_score(
        &board_1w, // <-- same board
        1, // <---------- black last move
        &global.black_table,
        &global.white_table,
        &global.seq_table,
        max_depth,
    ));

    // get the inverse
    var board_w1 = [_]i8{
        W, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    };
    try expect(-10 == get_game_score(
        &board_w1, // <-- inverted board
        W, // <---- black last move (invert player)
        &global.black_table,
        &global.white_table,
        &global.seq_table,
        max_depth,
    ));
    try expect(UNDEF == get_game_score(
        &board_w1, // <-- inverted board
        1, // <---- black last move (invert player)
        &global.black_table,
        &global.white_table,
        &global.seq_table,
        max_depth,
    ));
}

test "set inverse zero score" {
    const max_depth: u8 = 1;
    const global = struct {
        var black_table = [_]u32{0} ** (1 << 25);
        var white_table = [_]u32{0} ** (1 << 25);
        var seq_table = [_]seq_score{.{}} ** seq_table_size(25, max_depth);
    };
    init_tables(0);
    _ = minimax(&[_]i8{0} ** 25, -1, &global.black_table, &global.white_table, &global.seq_table, 0, 0, 5, 5);
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
        W, // <---- black last move
        &global.black_table,
        &global.white_table,
        &global.seq_table,
        max_depth,
    );
    try expect(0 == score_for_black);
}

test "set inverse mirror" {
    const max_depth = 3;
    const global = struct {
        var black_table = [_]u32{0} ** (1 << 25);
        var white_table = [_]u32{0} ** (1 << 25);
        var seq_table = [_]seq_score{.{}} ** seq_table_size(6, max_depth);
    };
    init_tables(0);
    minimax2x2(&global.black_table, &global.white_table, &global.seq_table, 0);
    var a = [_]i8{
        -1, 1, 0, 0, 0,
        0,  1, 0, 0, 0,
        0,  0, 0, 0, 0,
        0,  0, 0, 0, 0,
        0,  0, 0, 0, 0,
    };
    var b = [_]i8{
        1, -1, 0, 0, 0,
        0, -1, 0, 0, 0,
        0, 0,  0, 0, 0,
        0, 0,  0, 0, 0,
        0, 0,  0, 0, 0,
    };

    var lowa = state.lowest_blind_from_pos(&a);
    var lowb = state.lowest_blind_from_pos(&b);
    try expect(lowa.blind == lowb.blind);
    try expect(lowa.seq == lowb.seq);
    try expect(lowa.diff == lowb.diff);
    try expect(lowa.num_stones == lowb.num_stones);
    try expect(lowa.is_mirrored == lowb.is_mirrored);

    try expect(lowa.is_inverse != lowb.is_inverse);

    var g = get_game_score(&a, 1, &global.black_table, &global.white_table, &global.seq_table, max_depth);
    try expect(g == UNDEF);
    g = get_game_score(&a, -1, &global.black_table, &global.white_table, &global.seq_table, max_depth);
    try expect(g == UNDEF);
    g = get_game_score(&b, 1, &global.black_table, &global.white_table, &global.seq_table, max_depth);
    try expect(g == UNDEF);
    g = get_game_score(&b, -1, &global.black_table, &global.white_table, &global.seq_table, max_depth);
    try expect(g == UNDEF);

    // set white a 50
    var s = set_game_score(&a, 1, 50, // mostly black stones, black played
        &global.black_table, &global.white_table, &global.seq_table, max_depth);
    g = get_game_score(&a, 1, &global.black_table, &global.white_table, &global.seq_table, max_depth);
    try expect(s == 50 and g == 50 and s == g);

    g = get_game_score(&b, -1, // mostly white stones, white played
        &global.black_table, &global.white_table, &global.seq_table, max_depth);
    try expect(g == UNDEF);

    g = get_game_score(&a, -1, // mostly black stones, white played
        &global.black_table, &global.white_table, &global.seq_table, max_depth);
    try expect(g == UNDEF);

    g = get_game_score(&b, 1, // mostly white stones, black played
        &global.black_table, &global.white_table, &global.seq_table, max_depth);
    try expect(g == -50);
}

test "black traps white" {
    const max_depth: u8 = 8;
    const global = struct {
        var black_table = [_]u32{0} ** (1 << 25);
        var white_table = [_]u32{0} ** (1 << 25);
        var seq_table = [_]seq_score{.{}} ** seq_table_size(9, max_depth);
    };
    init_tables(0);
    const W: i8 = -1;
    minimax3x3(&global.black_table, &global.white_table, &global.seq_table, max_depth);

    var white_trapped = [_]i8{
        W, W, 1, 0, 0,
        0, 1, 0, 0, 0,
        0, 0, 0, 0, 0,
        0, 0, 0, 0, 0,
        0, 0, 0, 0, 0,
    };
    var white_trapped_score = get_game_score(&white_trapped, W, // black to play
        &global.black_table, &global.white_table, &global.seq_table, max_depth);

    try expect(white_trapped_score > 1);

    var black_triple_trapped = [_]i8{
        1, 1, W, 0, 0,
        1, W, 0, 0, 0,
        0, 0, 0, 0, 0,
        0, 0, 0, 0, 0,
        0, 0, 0, 0, 0,
    };
    var black_triple_score = get_game_score(&black_triple_trapped, 1, // white to play
        &global.black_table, &global.white_table, &global.seq_table, max_depth);

    try expect(black_triple_score > -120 and black_triple_score < -3);

    var black_trapped_score = get_game_score(
        &[_]i8{
            1, 0, 0, 0, 0,
            0, W, 0, 0, 0,
            0, 0, 0, 0, 0,
            0, 0, 0, 0, 0,
            0, 0, 0, 0, 0,
        },
        W, // black to play
        &global.black_table,
        &global.white_table,
        &global.seq_table,
        max_depth,
    );

    try expect(black_trapped_score > -120 and black_trapped_score < 0);
}

pub fn get_game_score(
    pos: *const [25]i8,
    color: i8,
    black_table: []u32,
    white_table: []u32,
    seq_table: []seq_score,
    max_depth: u8,
) i8 {
    //     if (color > 0) {
    //         return get_game_score_after_black_played(pos, 1, black_table, white_table, seq_table, max_depth);
    //     }
    //     var res = get_game_score_after_black_played(&state.armies_inverse(pos), 1, black_table, white_table, seq_table, max_depth);
    //     return if (res == UNDEF) UNDEF else -res;
    // }

    // fn get_game_score_after_black_played(
    //     pos: *const [25]i8,
    //     color: i8,
    //     black_table: []u32,
    //     white_table: []u32,
    //     seq_table: []seq_score,
    //     max_depth: u8,
    // ) i8 {
    var lowest = state.lowest_blind_from_pos(pos);
    var sequence = lowest.seq;
    if (sequence > 127) print("\n\nPANIC sequence={}\n\n", .{sequence});
    var seq_block_size = collision_size(lowest.num_stones, max_depth);
    //var seq_block_start = black_table[lowest.blind];
    var seq_block_start = if (color > 0) black_table[lowest.blind] else white_table[lowest.blind];

    if (seq_block_start == 0) return UNDEF;
    var i = seq_block_start;
    var seq_block_end = seq_block_start + seq_block_size;
    while (i < seq_block_end) : (i += 1) {
        var curr = &seq_table[i];
        if (curr.seq == sequence or curr.score == UNDEF) {
            if (curr.score == UNDEF) return UNDEF;

            return if (lowest.is_inverse)
                -curr.score * color
            else
                curr.score * color;
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
    //     if (color > 0) {
    //         return set_game_score_after_black_played(pos, 1, score, black_table, white_table, seq_table, max_depth);
    //     }
    //     var res = set_game_score_after_black_played(&state.armies_inverse(pos), 1, -score, black_table, white_table, seq_table, max_depth);
    //     return if (res == UNDEF) UNDEF else -res;
    // }

    // fn set_game_score_after_black_played(
    //     pos: *const [25]i8,
    //     color: i8,
    //     score: i8,
    //     black_table: []u32,
    //     white_table: []u32,
    //     seq_table: []seq_score,
    //     max_depth: u8,
    // ) i8 {
    if (score == UNDEF) {
        print("set_game_score UNDEF={}", .{score});
        unreachable;
    }
    var lowest = state.lowest_blind_from_pos(pos);
    var sequence = lowest.seq;
    if (sequence > 127) print("\n\nPANIC sequence={}\n\n", .{sequence});
    var score_to_set = score * color;
    if (lowest.is_inverse) score_to_set = -score * color;
    var seq_block_size = collision_size(lowest.num_stones, max_depth);
    //var seq_block_start = black_table[lowest.blind];
    var seq_block_start = if (color > 0) black_table[lowest.blind] else white_table[lowest.blind];

    if (seq_block_start == 0) {
        // create seq_block if does not yet exist
        if (seq_next_empty_index + seq_block_size > seq_table.len) {
            print("Uh oh! we have run out of total seq space " ++
                "while setting blind={}:seq={} (inv={}) " ++
                "to score={} num_stones={}", .{
                lowest.blind,
                lowest.seq,
                lowest.is_inverse,
                score_to_set,
                lowest.num_stones,
            });
            state.print_armies(pos);
            state.print_armies(&lowest.pos);
        }
        seq_block_start = seq_next_empty_index;

        // set seq index pointer in black_table
        if (color > 0) {
            black_table[lowest.blind] = seq_block_start;
        } else white_table[lowest.blind] = seq_block_start;

        // move the index forward for the next seq_block
        seq_next_empty_index += seq_block_size;
    }

    // search for seq (of black-white-black... patterns)
    // from seq_block_start to seq_block_end
    var i = seq_block_start;
    var seq_block_end = seq_block_start + seq_block_size;
    while (i < seq_block_end) : (i += 1) {
        var curr = &seq_table[i];
        if (curr.seq != sequence and curr.score != UNDEF) {
            continue; // around again
        }
        // if score not
        if (curr.seq == sequence and curr.score != UNDEF) {
            if (curr.score != score_to_set) {
                print("overwriting num_stones={} blind={} seq={} score old={} with new={}\n", .{
                    lowest.num_stones, lowest.blind, lowest.seq, curr.score, score_to_set,
                });
                unreachable;
            } else {
                print("Waste of resources: num_stones={} blind={} seq={} with same score {} == {}\n", .{
                    lowest.num_stones, lowest.blind, lowest.seq, curr.score, score_to_set,
                });
                // no logical problem, just annoying
            }
        }
        curr.seq = sequence;
        curr.score = score_to_set;
        return score; // original score
    }
    print(
        "Uh oh! found blind={}:seq={} (seq={}) (inv={}) of num_stones={} " ++
            "but no space in seq_block_size={}\n",
        .{
            lowest.blind,
            lowest.seq,
            sequence,
            lowest.is_inverse,
            lowest.num_stones,
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

pub fn wt_score(diff: i8, count: u8, color: i8) i8 {
    if (count < 1) return 0;
    if (diff * color == 1) return 0;
    var turn_diff = 2 * diff - color;

    var neg: i8 = if (turn_diff < 0) -1 else 1;
    var weight = 65 *
        @as(f64, @floatFromInt(neg * turn_diff)) /
        @as(f64, @floatFromInt(count + 1));
    var res: i8 = neg * @as(i8, @intFromFloat(weight));
    return res;
}

test "weighted score with komi" {
    try expect(wt_score(2, 2, 1) > 50);
    try expect(wt_score(0, 2, 1) < 0);
    try expect(wt_score(-2, 2, 1) < 50);

    try expect(wt_score(-2, 2, -1) < 50);
    try expect(wt_score(0, 2, -1) > 0);
    try expect(wt_score(2, 2, -1) > 50);

    try expect(wt_score(25, 25, -1) > 120);
    try expect(wt_score(25, 25, 1) > 120);
    try expect(wt_score(-25, 25, -1) < -120);
    try expect(wt_score(-25, 25, 1) < -120);
}

pub fn simple_score(diff: i8, count: u8, color: i8) i8 {
    _ = count;
    var komi: i8 = if (color > 0) 1 else -1;
    return diff * 2 - komi;
}

test "simple score" {
    try expect(-1 == simple_score(0, 2, 1));
}

// black must have two stones more than white to be ahead
// +/- 25 is a strong score, +/- 100 is total dominance
pub fn pos_score(pos: *const [25]i8, color: i8) i8 {
    var diff = state.stone_diff_from_pos(pos);
    var count = state.stone_count_from_pos(pos);
    var ret = simple_score(diff, count, color);
    return if (ret <= UNDEF) -127 else ret;
}

pub fn minimax2x2(black_table: []u32, white_table: []u32, seq_table: []seq_score, max_depth: u8) void {
    _ = minimax(&[_]i8{0} ** 25, -1, black_table, white_table, seq_table, 0, max_depth, 2, 2);
}
pub fn minimax3x2(black_table: []u32, white_table: []u32, seq_table: []seq_score, max_depth: u8) void {
    _ = minimax(&[_]i8{0} ** 25, -1, black_table, white_table, seq_table, 0, max_depth, 3, 2);
}
pub fn minimax3x3(black_table: []u32, white_table: []u32, seq_table: []seq_score, max_depth: u8) void {
    _ = minimax(&[_]i8{0} ** 25, -1, black_table, white_table, seq_table, 0, max_depth, 3, 3);
}
pub fn minimax5x5(black_table: []u32, white_table: []u32, seq_table: []seq_score, max_depth: u8) void {
    _ = minimax(&[_]i8{0} ** 25, -1, // color white "played empty" (black to play first stone)
        black_table, white_table, seq_table, 0, // start depth (start with zero stones)
        max_depth, 5, 5 // x_width, y_height
    );
}

pub fn minimax(
    pos: *const [25]i8,
    color: i8, // initial stones
    black_table: []u32,
    white_table: []u32,
    seq_table: []seq_score, // global tables
    depth: u8, // depth per recursive loop
    max_depth: u8,
    x_width: u8,
    y_height: u8,
    //ko_tree: *const [25][25]i8,
) i8 {
    assert(x_width > 1 and y_height > 1 and x_width < 6);
    assert(x_width * y_height <= 25);

    if (depth >= max_depth) { // game over
        if (depth > LAST_SAVE_DEPTH) {
            // FIXME cannot set seq more than 8 bits
            return pos_score(pos, color);
        }
        var score = pos_score(pos, color);
        return set_game_score(pos, color, score, black_table, white_table, seq_table, max_depth);
    }
    var val: i8 = if (color > 0) 99 else -99;
    var child_cnt: u8 = 0;
    for (0..(y_height * 5 - 5 + x_width)) |p| { // FIXME try ..8 for now, but should be 25
        if (pos[p] != 0) continue;
        if (p % 5 >= x_width) continue;

        var child: [25]i8 = state.armies_from_move(pos, -color, @intCast(p)) catch |err| switch (err) {
            error.Occupied => {
                print("{} Occupied\n", .{p});
                continue;
            },
            error.Suicide => continue,
            error.KoRepeat => {
                print("{} KoRepeat\n", .{p});
                continue;
            },
            error.Unexpected => {
                print("{} Unexpected\n", .{p});
                continue;
            },
        };

        var child_score = if (depth < LAST_SAVE_DEPTH)
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
            child_score = minimax(&child, -color, black_table, white_table, seq_table, depth + 1, max_depth, x_width, y_height);
        } else total_found_child += 1;

        val = if (color > 0)
            min2(val, child_score)
        else
            max2(val, child_score);

        child_cnt += 1; // only if success
    }

    if (child_cnt == 0) { // end game, no children
        val = pos_score(pos, color);
        //print("- minimax depth={}, no child score={}\n", .{ depth, val });
    } else if (depth == 1) {
        //print("- minimax depth={}, best child_score={}\n", .{ depth, val });
    }

    return if (depth <= LAST_SAVE_DEPTH) set_game_score(
        pos,
        color,
        val,
        black_table,
        white_table,
        seq_table,
        max_depth,
    ) else val;
}
