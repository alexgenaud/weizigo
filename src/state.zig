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
const expect = std.testing.expect;
const expectError = std.testing.expectError;
const util = @import("util.zig");
const println = util.println;

pub const UNDEF: i8 = util.UNDEF; // -128;

const GameError = error{
    Occupied,
    Suicide,
    KoRepeat,
    Unexpected,
};

fn char_from_stone(stone: i8) u8 {
    if (stone == 0) return '.'; // empty
    if (stone == UNDEF) return '/'; // -128
    if (stone < 0) {
        var pebble: i8 = stone;
        while (pebble < -26) pebble += 26;
        return @intCast('@' - pebble); // A-Z
    }
    var pebble: u8 = @intCast(stone);
    while (pebble > 35) pebble -= 35;
    if (pebble < 27) return '`' + pebble; // a-z
    return '0' + pebble - 26; // 1-9 (not 0)
}

pub fn print_armies(armies: *const [25]i8) void {
    for (0..5) |x| {
        var i = x * 5;
        print("{c} {c} {c} {c} {c}\n", .{
            char_from_stone(armies[i]),
            char_from_stone(armies[i + 1]),
            char_from_stone(armies[i + 2]),
            char_from_stone(armies[i + 3]),
            char_from_stone(armies[i + 4]),
        });
    }
    print("\n", .{});
}

// A B C D E     U P K F A
// F G H I J     V Q L G B
// K L M N O --> W R M H C
// P Q R S T     X S N I D
// U V W X Y     Y T O J E
//
// 00 01 02 03 04     20 15 10 05 00
// 05 06 07 08 09     21 16 11 06 01
// 10 11 12 13 14 --> 22 17 12 07 02
// 15 16 17 18 19     23 18 13 08 03
// 20 21 22 23 24     24 19 14 09 04
pub fn update_rotate(armies: *[25]i8) void {
    var tmp = armies[0];
    armies[0] = armies[20];
    armies[20] = armies[24];
    armies[24] = armies[4];
    armies[4] = tmp;

    tmp = armies[1];
    armies[1] = armies[15];
    armies[15] = armies[23];
    armies[23] = armies[9];
    armies[9] = tmp;

    tmp = armies[2];
    armies[2] = armies[10];
    armies[10] = armies[22];
    armies[22] = armies[14];
    armies[14] = tmp;

    tmp = armies[3];
    armies[3] = armies[5];
    armies[5] = armies[21];
    armies[21] = armies[19];
    armies[19] = tmp;

    tmp = armies[6];
    armies[6] = armies[16];
    armies[16] = armies[18];
    armies[18] = armies[8];
    armies[8] = tmp;

    tmp = armies[7];
    armies[7] = armies[11];
    armies[11] = armies[17];
    armies[17] = armies[13];
    armies[13] = tmp;

    //armies[12] = armies[12];
}

// returns a unique board view
// 0 = empty to 3^25-1 = fully white
//  2^40 > 3^25 > 2^39
//  1 TB > 847 GB > 550 GB
// considers only negative, zero, positive array elements
pub fn view_from_pos(pos: *const [25]i8) u40 {
    var h: u40 = 0;
    var m: u40 = 1;
    for (0..25) |p| {
        if (pos[p] > 0) h += m;
        if (pos[p] < 0) h += m * 2;
        m *= 3;
    }
    return h;
}

pub fn seq_from_pos(pos: *const [25]i8) u8 {
    var cnt: u8 = 0;
    var h: u8 = 0;
    var m: u8 = 1;
    for (0..25) |p| {
        if (pos[p] == 0) continue;
        // black 1, white 0 bit
        if (pos[p] > 0) h += m;
        cnt += 1;
        if (cnt >= 8) break;
        m *= 2;
    }
    return h;
}

pub fn pos_from_blind(blind: u25) [25]i8 {
    var rem = blind;
    var pos: [25]i8 = undefined;
    for (0..25) |p| {
        pos[p] = switch (rem % 2) {
            0 => 0,
            1 => 1,
            else => unreachable,
        };
        rem /= 2;
    }
    return pos;
}

pub fn seq_from_view(view: u40) u8 {
    var cnt: u8 = 0;
    var h: u8 = 0;
    var m: u8 = 1;
    var rem = view;
    for (0..25) |_| {
        var val = rem % 3;
        rem /= 3;
        if (val == 0) continue;
        if (val == 1) h += m;
        cnt += 1;
        if (cnt >= 8) break;
        m *= 2;
    }
    return h;
}

pub fn pos_from_view(view: u40) [25]i8 {
    var rem = view;
    var pos: [25]i8 = undefined;
    for (0..25) |p| {
        pos[p] = switch (rem % 3) {
            0 => 0,
            1 => 1,
            2 => -1,
            else => unreachable,
        };
        rem /= 3;
    }
    return pos;
}

pub fn armies_rotate(parent: *const [25]i8) [25]i8 {
    var armies = parent.*;
    update_rotate(&armies);
    return armies;
}

pub fn update_reflect(armies: *[25]i8) void {
    for (0..5) |x| {
        var p = x * 5;
        var tmp = armies[p];
        armies[p] = armies[p + 4];
        armies[p + 4] = tmp;
        tmp = armies[p + 1];
        armies[p + 1] = armies[p + 3];
        armies[p + 3] = tmp;
    }
}

pub fn armies_reflect(parent: *const [25]i8) [25]i8 {
    var armies = parent.*;
    update_reflect(&armies);
    return armies;
}

pub fn update_inverse(armies: *[25]i8) void {
    for (0..25) |p| armies[p] *= -1;
}

pub fn armies_inverse(parent: *const [25]i8) [25]i8 {
    var armies = parent.*;
    update_inverse(&armies);
    return armies;
}

pub fn update_captures(armies: *[25]i8, color: i8) u8 {
    var liberty = [_]i8{UNDEF} ** 15;
    var key: usize = undefined;
    for (0..25) |p| {
        if (armies[p] * color <= 0) continue;
        key = if (color > 0) @intCast(armies[p] - 1) else @intCast(1 - armies[p]);
        if ((p >= 5 and armies[p - 5] == 0) // north
        or (p < 20 and armies[p + 5] == 0) // south
        or (p >= 1 and p % 5 > 0 and armies[p - 1] == 0) // west
        or (p < 24 and p % 5 < 4 and armies[p + 1] == 0)) { // east
            liberty[key] = 1;
        } else if (liberty[key] == UNDEF) {
            liberty[key] = 0; // no liberties
        }
    }
    var captures: u8 = 0;
    for (0..25) |p| {
        if (armies[p] * color <= 0) continue;
        key = if (color > 0) @intCast(armies[p] - 1) else @intCast(1 - armies[p]);
        if (liberty[key] == UNDEF or liberty[key] > 0) continue;
        captures += 1;
        armies[p] = 0;
    }
    return captures;
}

pub fn armies_from_move_xy(armies: *const [25]i8, color: i8, x: u8, y: u8) GameError![25]i8 {
    return armies_from_move(armies, color, y * 5 + x);
}

pub fn armies_from_move(parent: *const [25]i8, color: i8, index: u8) GameError![25]i8 {
    if (parent[index] != 0) return GameError.Occupied;
    var armies = parent.*;
    armies[index] = color;
    update_armies(&armies);
    var enemy_captures = update_captures(&armies, -color);
    var self_captures = update_captures(&armies, color);
    if (enemy_captures > 0 and self_captures > 0) {
        return GameError.Unexpected;
    } else if (self_captures > 0) {
        return GameError.Suicide;
    }
    return armies;
}

// Converts a grid of white, empty, black stones into armies of common flags.
// For example:
//      black empty white black black
//      may result in "a0Cbb" or
//      (1) (0) (-3) (2) (2)
// The value (flag) of output positions separate armies
//      Armies with positive values (flags) are black and negative are white.
// The amplitude of input positions are insignificant,
// example
// zero represents an empty position, any positive is black, and any negative is white.
//     1, 2, 3, 4, 5, .. 99 are all black
//     0 is empty
//     -1, -2, ... -99 are all white
pub fn update_armies(armies: *[25]i8) void {
    var flagb: i8 = 0;
    var flagw: i8 = 0;
    for (0..25) |p| {
        if (armies[p] == 0) {
            // if empty then continue
            continue;
        }
        const color: i8 = if (armies[p] > 0) 1 else -1; // 1 == black or -1 == white
        if (p >= 5 and p % 5 > 0 and (armies[p - 5] * color > 0 and armies[p - 1] * color > 0)) {
            // if north exists and not west wall and north is friend and west is friend

            if (armies[p - 5] == armies[p - 1]) {
                // accept flag of existing large army
                armies[p] = armies[p - 5]; // north (same as west)
            } else {
                // merge two or three armies under one flag
                var burn_flag: i8 = armies[p - 1];
                var keep_flag: i8 = armies[p - 5];

                // keep the oldest and burn the newest flag
                if ((keep_flag - burn_flag) * color > 0) {
                    burn_flag = armies[p - 5];
                    keep_flag = armies[p - 1];
                }

                // reset the latest flag if burned
                // NOTE: the burned flag is often
                // (but not always) the latest flag.
                // Thus skipped flag values are possible
                if (color > 0) { // black
                    if (burn_flag == flagb) flagb -= 1;
                } else { // white
                    if (burn_flag == flagw) flagw += 1;
                }

                // set all previous burned flags to the kept flag
                armies[p] = keep_flag;
                for (0..p) |i| {
                    if (armies[i] == burn_flag) {
                        armies[i] = keep_flag;
                    }
                }
            }
        } else if (p >= 5 and armies[p - 5] * color > 0) {
            // if north exists and north is friend
            armies[p] = armies[p - 5]; // north
        } else if (p >= 1 and p % 5 > 0 and armies[p - 1] * color > 0) {
            // if west exists and not west wall and and west is friend
            armies[p] = armies[p - 1]; // west
        } else if (color > 0) {
            // new black army, no friends north nor west
            flagb += 1;
            armies[p] = flagb;
        } else {
            // new white army, no friends north nor west
            flagw -= 1;
            armies[p] = flagw;
        }
    }
}

// negative are to white advantage,
// zero when black and white have equal stones on the board
// positive is to black advantage.
// If 10 black and 5 white, then return +5
pub fn stone_diff_from_pos(pos: *const [25]i8) i8 {
    var diff: i8 = 0;
    for (0..25) |p| {
        if (pos[p] > 0) {
            diff += 1;
        } else if (pos[p] < 0) {
            diff -= 1;
        }
    }
    return diff;
}

pub fn stone_diff_from_view(view: u40) i8 {
    var diff: i8 = 0;
    var rem = view;
    for (0..25) |_| {
        diff += switch (rem % 3) {
            0 => 0,
            1 => 1,
            2 => -1,
            else => unreachable,
        };
        rem /= 3;
    }
    return diff;
}

pub fn stone_count_from_pos(pos: *const [25]i8) u8 {
    var cnt: u8 = 0;
    for (0..25) |p| {
        if (pos[p] != 0) cnt += 1;
    }
    return cnt;
}

pub fn stone_count_from_view(view: u40) u8 {
    var cnt: i8 = 0;
    var rem = view;
    for (0..25) |_| {
        if (rem % 3 != 0) cnt += 1;
        rem /= 3;
    }
    return cnt;
}

pub fn armies_from_pos(pos: *const [25]i8) [25]i8 {
    var armies: [25]i8 = pos.*;
    update_armies(&armies);
    return armies;
}

pub fn is_equal_25i8(a: *const [25]i8, b: *const [25]i8) bool {
    for (0..25) |p| {
        if (a[p] != b[p]) return false;
    }
    return true;
}

fn expect_armies_from_input(expected: *const [25]i8, input: *const [25]i8) !void {
    var output = armies_from_pos(input);
    try expect(is_equal_25i8(expected, &output));
    try expect(is_equal_25i8(expected, &armies_from_pos(&output)));
    output = input.*;
    update_armies(&output);
    try expect(is_equal_25i8(expected, &output));
}

pub fn blind_from_view(view: u40) u25 {
    var blind: u32 = 0;
    var rem = view;
    var m: u32 = 1;
    for (0..25) |_| {
        if (rem % 3 != 0) blind += m;
        rem /= 3;
        m *= 2;
    }
    return @intCast(blind);
}

pub fn blind_from_pos(pos: *const [25]i8) u25 {
    var blind: u32 = 0;
    var m: u32 = 1;
    for (0..25) |p| {
        if (pos[p] != 0) blind += m;
        m *= 2;
    }
    return @intCast(blind);
}

pub const lowest = struct {
    pos: [25]i8 = undefined,
    blind: u25 = undefined,
    seq: u8 = undefined,
    inverse_seq: u8 = undefined,
    num_stones: u8 = undefined,
    diff: i8 = undefined,
};

pub fn lowest_blind_from_pos(pos: *const [25]i8) lowest {
    var orig = pos.*;
    var refl = armies_reflect(&orig);

    var orig_blind = blind_from_pos(&orig);
    var refl_blind = blind_from_pos(&refl);

    var lowest_pos: [25]i8 = undefined;
    var lowest_seq: u8 = undefined;
    var lowest_blind: u25 = orig_blind;

    if (refl_blind < lowest_blind) {
        lowest_blind = refl_blind;
        lowest_pos = refl; // copy
        lowest_seq = seq_from_pos(&refl);
    } else {
        lowest_pos = orig; // copy
        lowest_seq = seq_from_pos(&orig);
    }

    for (0..3) |_| {
        update_rotate(&orig);
        update_rotate(&refl);
        orig_blind = blind_from_pos(&orig);
        refl_blind = blind_from_pos(&refl);
        if (orig_blind < lowest_blind and orig_blind < refl_blind) {
            lowest_blind = orig_blind;
            lowest_pos = orig; // copy
            lowest_seq = seq_from_pos(&orig);
        } else if (refl_blind < lowest_blind and refl_blind < orig_blind) {
            lowest_blind = refl_blind;
            lowest_pos = refl; // copy
            lowest_seq = seq_from_pos(&refl);
        }
    }
    return lowest{
        .pos = lowest_pos,
        .blind = lowest_blind,
        .seq = lowest_seq,
        // TODO must be faster inverse_seq considering num_stones
        .inverse_seq = seq_from_pos(&armies_inverse(&lowest_pos)),
        .num_stones = stone_count_from_pos(&orig),
        .diff = stone_diff_from_pos(&orig),
    };
}

test "seq from view and pos" {
    const W: i8 = -1;
    try expect(seq_from_pos(&[25]i8{
        //1   2  4  8    16    32    64   128
        W, 0, W, W, 1, 0, 1, 0, 1, 0, W, 0, 1,
        1, 1, W, W, 1, 0, 1, 0, 0, 0, 0, 0,
    }) == 8 + 16 + 32 + 128);

    const view_black = view_from_pos(&armies_from_pos(&[25]i8{
        1, 0, 1, 1, 1, 1, 0, 1, 1, 1, 0, 1, W,
        1, W, W, W, 1, W, 1, W, W, 1, 1, 1,
    }));
    try expect(seq_from_view(view_black) == 255);
}

test "blind from view" {
    const W: i8 = -1;

    // a line of white and black becomes blind
    const viewW31: u40 = 2 + 6 + 18 + 27 + 81 + 243;
    try expect(is_equal_25i8(&[25]i8{
        W, W, W, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    }, &pos_from_view(viewW31)));
    const blindW31 = blind_from_view(viewW31);
    const posB31 = [25]i8{
        1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    };
    try expect(blindW31 == blind_from_pos(&posB31));

    var m2: u64 = 1;
    var m3: u64 = 1;
    for (0..25) |_| {
        var posBlack = pos_from_view(@intCast(m3));
        var posWhite = pos_from_view(@intCast(m3 * 2));
        var posBlind = pos_from_blind(@intCast(m2));

        try expect(view_from_pos(&posWhite) ==
            view_from_pos(&armies_inverse(&posBlack)));
        try expect(view_from_pos(&posBlind) ==
            view_from_pos(&armies_inverse(&posWhite)));
        try expect(blind_from_pos(&posBlack) ==
            blind_from_pos(&posWhite));

        m2 *= 2;
        m3 *= 3;
    }

    try expect(is_equal_25i8( // 3 ^ 25 - 1
        &armies_inverse(&pos_from_view(847288609442)),
        &pos_from_view(423644304721), // 3 ^ 25 / 2
    ));
    try expect(is_equal_25i8(
        &pos_from_view(423644304721), // 3 ^ 25 / 2
        &pos_from_blind(33554431), // 2 ^ 25 - 1
    ));

    try expect(is_equal_25i8(
        &[_]i8{W} ** 25, // all white
        &pos_from_view(847288609442), // 3 ^ 25 - 1
    ));
}

test "pos from view" {
    //       0 1  2  3   4   5    6    7     8     9
    // black 1 3  9 27  81 243  729 2187  6561 19683
    // white 2 6 18 54 162 486 1458 4375 13122

    const W: i8 = -1;
    try expect(is_equal_25i8(&[25]i8{
        W, 1, 0, 1, W, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    }, &pos_from_view(5 + 27 + 162)));
    try expect(is_equal_25i8(&[_]i8{
        0, 0, W, 0, 1, 0, 1, 0, W, 1, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    }, &pos_from_view(81 + 729 + 19683 + 18 + 13122)));
}
test "rotate" {
    const A: i8 = -1;
    const B: i8 = -2;
    const board = [_]i8{
        B, 1, 0, A, 0,
        1, A, 1, B, B,
        B, 2, A, 2, 0,
        A, B, 0, A, 2,
        0, 0, 1, 1, 0,
    };
    var rotate = armies_rotate(&board);
    const expect_first_rotation = [_]i8{
        0, A, B, 1, B,
        0, B, 2, A, 1,
        1, 0, A, 1, 0,
        1, A, 2, B, A,
        0, 2, 0, B, 0,
    };
    try expect(is_equal_25i8(&expect_first_rotation, &rotate));
    rotate = armies_rotate(&rotate);
    rotate = armies_rotate(&rotate);
    rotate = armies_rotate(&rotate);
    try expect(is_equal_25i8(&board, &rotate));

    update_rotate(&rotate);
    try expect(is_equal_25i8(&expect_first_rotation, &rotate));
    update_rotate(&rotate);
    update_rotate(&rotate);
    update_rotate(&rotate);
    try expect(is_equal_25i8(&board, &rotate));
}

test "reflect" {
    const A: i8 = -1;
    const B: i8 = -2;
    const board = [_]i8{
        B, 1, 0, A, 0, 1, A, 1, B, B, B, 2, A, 2, 0,
        A, B, 0, A, 2, 0, 0, 1, 1, 0,
    };
    var reflect = armies_reflect(&board);
    try expect(is_equal_25i8(&[_]i8{
        0, A, 0, 1, B, B, B, 1, A, 1, 0, 2, A, 2, B,
        2, A, 0, B, A, 0, 1, 1, 0, 0,
    }, &reflect));
    try expect(is_equal_25i8(&board, &armies_reflect(&reflect)));
    update_reflect(&reflect);
    try expect(is_equal_25i8(&board, &reflect));
}

test "inverse" {
    const A: i8 = -1;
    const B: i8 = -2;
    const board = [_]i8{
        0, 1, 0, 0, 0, 0, A, 1, 0, B, B, 2, A,
        2, 0, A, B, 0, A, 2, 0, 0, 1, 1, 0,
    };
    var inv = armies_inverse(&board);
    try expect(is_equal_25i8(&[_]i8{
        0, A, 0, 0, 0, 0, 1, A, 0, 2, 2, B, 1,
        B, 0, 1, 2, 0, 1, B, 0, 0, A, A, 0,
    }, &inv));
    try expect(is_equal_25i8(&board, &armies_inverse(&inv)));
    update_inverse(&inv);
    try expect(is_equal_25i8(&board, &inv));
}

test "white capture in the center" {
    const A: i8 = -1;
    const B: i8 = -2;
    const C: i8 = -3;
    var board = try armies_from_move_xy(&[_]i8{
        0, 0, 0, 0, 0, 0, A, 1, 0, 0, 0, 1, A,
        1, 0, 0, 0, 0, A, 0, 0, 0, 0, 0, 0,
    }, 1, 2, 3);
    try expect(is_equal_25i8(&[_]i8{
        0, 0, 0, 0, 0, 0, A, 1, 0, 0, 0, 2, 0,
        3, 0, 0, 0, 4, C, 0, 0, 0, 0, 0, 0,
    }, &board));
    board = try armies_from_move_xy(&board, A, 3, 1);
    try expect_armies_from_input(&[_]i8{
        0, 0, 0, 0, 0, 0, A, 1, B, 0, 0, 2, 0,
        3, 0, 0, 0, 4, C, 0, 0, 0, 0, 0, 0,
    }, &board);
    try expectError(
        GameError.Occupied,
        armies_from_move_xy(&board, 1, 1, 1),
    );
    try expectError(
        GameError.Suicide,
        armies_from_move_xy(&board, A, 2, 2),
    );
}

test "west captures" {
    const A: i8 = -1;
    const B: i8 = -2;
    const C: i8 = -3;
    var board = try armies_from_move_xy(&[_]i8{
        A, 0, 0, 0, 0, 1, A, 0, 0, 0, 0, 1, 0,
        0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    }, A, 0, 2);
    board = try armies_from_move_xy(&board, 1, 0, 4);
    try expect_armies_from_input(&[_]i8{
        A, 0, 0, 0, 0, 0, B, 0, 0, 0, C, 1, 0,
        0, 0, 2, 0, 0, 0, 0, 2, 0, 0, 0, 0,
    }, &board);
    board = try armies_from_move_xy(&board, A, 1, 3);
    board = try armies_from_move_xy(&board, 1, 1, 4);
    board = try armies_from_move_xy(&board, A, 2, 4);
    try expect_armies_from_input(&[_]i8{
        A, 0, 0, 0,  0, 0, B, 0, 0, 0,  C, 1, 0,
        0, 0, 0, -4, 0, 0, 0, 0, 0, -5, 0, 0,
    }, &board);
}

test "south captures" {
    const A: i8 = -1;
    var board = try armies_from_move_xy(&[_]i8{
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        1, 1, 1, 1, 0, A, A, A, A, A,
    }, 1, 4, 3);
    try expect_armies_from_input(&[_]i8{
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        1, 1, 1, 1, 1, 0, 0, 0, 0, 0,
    }, &board);
}
test "east captures" {
    const A: i8 = -1;
    const B: i8 = -2;
    const C: i8 = -3;
    const D: i8 = -4;
    var board = try armies_from_move_xy(&[_]i8{
        0, 0, 0, 0, 0, 0, 0, 0, A, A, 0, 0, A, 1, 1,
        0, 0, 1, A, 0, 0, 0, 0, 1, 1,
    }, A, 4, 3);
    board = try armies_from_move_xy(&board, 1, 2, 4);
    try expect_armies_from_input(&[_]i8{
        0, 0, 0, 0, 0, 0, 0, 0, A, A, 0, 0, B, 0, 0,
        0, 0, 1, C, C, 0, 0, 1, 1, 1,
    }, &board);
    board = try armies_from_move_xy(&board, A, 1, 3);
    board = try armies_from_move_xy(&board, 1, 3, 2);
    try expect_armies_from_input(&[_]i8{
        0, 0, 0, 0, 0, 0, 0, 0, A, A, 0, 0, B, 1, 0,
        0, C, 2, D, D, 0, 0, 2, 2, 2,
    }, &board);
    var alternate = board;
    board = try armies_from_move_xy(&board, A, 1, 4);
    try expect_armies_from_input(&[_]i8{
        0, 0, 0, 0, 0, 0, 0, 0, A, A, 0, 0, B, 1, 0,
        0, C, 0, D, D, 0, C, 0, 0, 0,
    }, &board);
    alternate = try armies_from_move_xy(&alternate, 1, 4, 2);
    try expect_armies_from_input(&[_]i8{
        0, 0, 0, 0, 0, 0, 0, 0, A, A, 0, 0, B, 1, 1,
        0, C, 2, 0, 0, 0, 0, 2, 2, 2,
    }, &alternate);
}

test "white captured in the north" {
    const A: i8 = -1;
    const B: i8 = -2;
    var board = try armies_from_move_xy(&[_]i8{
        1, 0, 1, A, 0, 0, 1, A, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    }, A, 1, 0);
    board = try armies_from_move_xy(&board, 1, 2, 2);
    board = try armies_from_move_xy(&board, A, 2, 0);
    board = try armies_from_move_xy(&board, 1, 3, 1);
    board = try armies_from_move_xy(&board, A, 4, 0);
    try expect_armies_from_input(&[_]i8{
        1, A, A, A, A, 0, 2, A, 3, 0, 0, 0, 4, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    }, &board);
    board = try armies_from_move_xy(&board, 1, 4, 1);
    try expect_armies_from_input(&[_]i8{
        1, 0, 0, 0, 0, 0, 2, 0, 3, 3, 0, 0, 4, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    }, &board);
    board = try armies_from_move_xy(&board, A, 0, 1);
    board = try armies_from_move_xy(&board, 1, 2, 1);
    board = try armies_from_move_xy(&board, A, 1, 0);
    board = try armies_from_move_xy(&board, 1, 2, 0);
    try expect_armies_from_input(&[_]i8{
        0, A, 1, 0, 0, B, 1, 1, 1, 1, 0, 0, 1, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    }, &board);
    board = try armies_from_move_xy(&board, A, 0, 0);
    board = try armies_from_move_xy(&board, 1, 0, 2);
    try expect_armies_from_input(&[_]i8{
        0, 0, 1, 0, 0, 0, 1, 1, 1, 1, 2, 0, 1, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    }, &board);
}

test "capture black in center" {
    const A: i8 = -1;
    const B: i8 = -2;
    const C: i8 = -3;
    const D: i8 = -4;
    var board = try armies_from_move_xy(&[_]i8{
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, A, 0, 0, 1, 0, 0, 0,
    }, 1, 2, 3);
    try expect_armies_from_input(&[_]i8{
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 1, A, 0, 0, 2, 0, 0, 0,
    }, &board);
    board = try armies_from_move_xy(&board, -1, 2, 2);
    try expect_armies_from_input(&[_]i8{
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, A, 0, 0,
        0, 0, 1, B, 0, 0, 2, 0, 0, 0,
    }, &board);
    board = try armies_from_move_xy(&board, 1, 3, 2);
    board = try armies_from_move_xy(&board, -1, 1, 3);
    try expect_armies_from_input(&[_]i8{
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, A, 1, 0,
        0, B, 2, C, 0, 0, 3, 0, 0, 0,
    }, &board);
    board = try armies_from_move_xy(&board, 1, 1, 2);
    board = try armies_from_move_xy(&board, -1, 2, 4);
    try expect_armies_from_input(&[_]i8{
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, A, 2, 0,
        0, B, 0, C, 0, 0, 3, D, 0, 0,
    }, &board);
}

test "white captured in the corner" {
    const A: i8 = -1;
    var board = [_]i8{0} ** 25;
    board = try armies_from_move_xy(&board, 1, 4, 3);
    board = try armies_from_move_xy(&board, A, 4, 4);
    try expect_armies_from_input(&[_]i8{
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 1, 0, 0, 0, 0, A,
    }, &board);
    board = try armies_from_move_xy(&board, 1, 3, 4);
    try expect_armies_from_input(&[_]i8{
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 1, 0, 0, 0, 2, 0,
    }, &board);
}

test "white suicide in the corner" {
    var board = [_]i8{0} ** 25;
    board = try armies_from_move_xy(&board, 1, 4, 3);
    board = try armies_from_move_xy(&board, 1, 3, 4);
    try expectError(GameError.Suicide, armies_from_move_xy(&board, -1, 4, 4));
}

test "merge armies in several moves" {
    var board = [_]i8{0} ** 25;
    board = try armies_from_move_xy(&board, 1, 2, 1);
    board = try armies_from_move_xy(&board, 1, 2, 3);
    board = try armies_from_move_xy(&board, 1, 1, 2);
    board = try armies_from_move_xy(&board, 1, 3, 2);
    try expect_armies_from_input(&[_]i8{
        0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 2, 0, 3, 0,
        0, 0, 4, 0, 0, 0, 0, 0, 0, 0,
    }, &board);
    board = try armies_from_move_xy(&board, 1, 2, 2);
    try expect_armies_from_input(&[_]i8{
        0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 1, 1, 0,
        0, 0, 1, 0, 0, 0, 0, 0, 0, 0,
    }, &board);
}

test "full char range" {
    try expect('.' == char_from_stone(0));
    try expect('a' == char_from_stone(1));
    try expect('b' == char_from_stone(2));
    try expect('y' == char_from_stone(25));
    try expect('z' == char_from_stone(26));
    try expect('1' == char_from_stone(27));
    try expect('9' == char_from_stone(35));
    try expect('a' == char_from_stone(36));
    try expect('z' == char_from_stone(61));
    try expect('1' == char_from_stone(62));
    try expect('9' == char_from_stone(70));
    try expect('a' == char_from_stone(71));
    try expect('a' == char_from_stone(106));
    try expect('k' == char_from_stone(116));
    try expect('u' == char_from_stone(126));
    try expect('v' == char_from_stone(127));
    // w == 128 is above i8 range
    try expect('A' == char_from_stone(-1));
    try expect('B' == char_from_stone(-2));
    try expect('Y' == char_from_stone(-25));
    try expect('Z' == char_from_stone(-26));
    try expect('A' == char_from_stone(-27));
    try expect('Z' == char_from_stone(-52));
    try expect('Z' == char_from_stone(-78));
    try expect('Z' == char_from_stone(-104));
    try expect('A' == char_from_stone(-105));
    try expect('U' == char_from_stone(-125));
    try expect('W' == char_from_stone(-127));
    try expect('/' == char_from_stone(-128)); // UNDEFINED, NULL, or ERROR
    // Y == -129 is below i8 range
    const v: i8 = 127;
    const A: i8 = -1;
    const B: i8 = -2;
    const C: i8 = -3;
    const D: i8 = -4;
    const W: i8 = -127;
    try expect(is_equal_25i8(&[_]i8{
        A, 1, 1, 1, 1, 2, B, 1, C, C, 2, 0, 1, C, 3,
        2, 2, 0, 2, D, 2, 2, 2, 2, 2,
    }, &armies_from_pos(&[_]i8{
        W, v, 2, v, 97,   v, W, 8, A, -125, v, 0, 4, W, 99,
        5, v, 0, 6, -126, v, 7, v, v, 98,
    })));
}

test "merge armies" {
    const j: i8 = 10;
    const k: i8 = 11;
    const l: i8 = 12;
    const A: i8 = -1;
    const B: i8 = -2;
    const C: i8 = -3;
    const D: i8 = -4;
    const E: i8 = -5;
    const F: i8 = -6;
    const G: i8 = -7;
    const H: i8 = -8;
    const I: i8 = -9;
    const J: i8 = -10;
    const K: i8 = -11;
    const L: i8 = -12;
    const M: i8 = -13;
    const Z: i8 = -127;
    const z: i8 = 127;

    try expect_armies_from_input(&[_]i8{0} ** 25, &[_]i8{0} ** 25);
    try expect_armies_from_input(
        &[_]i8{ A, 1, B, 2, C, 3, D, 4, E, 5, F, 6, G, 7, H, 8, I, 9, J, j, K, k, L, l, M },
        &[_]i8{ A, 4, A, 1, A, 5, A, 5, A, 2, A, 3, A, 1, A, 5, A, 2, A, 3, A, 4, A, 5, A },
    );
    try expect_armies_from_input(
        &[_]i8{ 0, 1, 0, 0, 2, 1, 1, 0, 2, 2, 0, 0, 2, 2, 0, 0, 2, 2, 0, 3, 2, 2, 0, 3, 3 },
        &[_]i8{ 0, 1, 0, 0, 9, 3, 6, 0, 5, 4, 0, 0, 2, 9, 0, 0, 1, 9, 0, 3, 1, 1, 0, 9, 1 },
    );
    try expect_armies_from_input(
        &[_]i8{ 0, A, 0, 0, B, A, A, 1, 0, 2, 0, 3, 0, 2, 2, 4, 0, 5, 0, C, 0, 6, 0, 7, C },
        &[_]i8{ 0, A, 0, 0, A, A, A, 2, 0, 7, 0, 3, 0, 1, 8, 2, 0, 3, 0, A, 0, 9, 0, 1, A },
    );
    try expect_armies_from_input(
        &[_]i8{ 1, 0, 1, 0, 3, 1, 1, 1, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
        &[_]i8{ 1, 0, 1, 0, 2, 7, 1, 6, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
    );
    try expect_armies_from_input(
        &[_]i8{ 1, 1, 1, 1, 1, 1, 0, 0, 0, 1, 1, 0, 1, 0, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 2 },
        &[_]i8{ 7, 3, 5, 1, 6, 2, 0, 0, 0, 9, 1, 0, 1, 0, 7, 4, 2, 8, 0, 0, 0, 0, 0, 0, 1 },
    );
    try expect_armies_from_input(
        &[_]i8{ 1, 0, 1, 1, 1, 1, 0, 1, 0, 1, 1, 0, 1, 0, 1, 1, 0, 1, 0, 0, 1, 1, 1, 0, 2 },
        &[_]i8{ 1, 0, 2, 6, 4, 3, 0, 5, 0, 1, 2, 0, 8, 0, 6, 7, 0, 6, 0, 0, 4, 2, 1, 0, 1 },
    );
    try expect_armies_from_input(
        &[_]i8{ 1, 1, 0, 2, 0, 1, 0, 0, 0, 1, 1, 0, 1, 0, 1, 1, 0, 1, 1, 1, 1, 1, 1, 0, 0 },
        &[_]i8{ 1, 2, 0, 1, 0, 8, 0, 0, 0, 3, 7, 0, 2, 0, 3, 9, 0, 7, 5, 2, 1, 7, 1, 0, 0 },
    );
    try expect_armies_from_input(
        &[_]i8{ 1, 1, 0, 2, 0, 1, 0, 0, 0, 1, 1, 0, 1, 0, 1, 1, 0, 1, 1, 1, 1, 1, 1, 0, 0 },
        &[_]i8{ 4, 2, 0, 3, 0, 1, 0, 0, 0, 9, 2, 0, 8, 0, 3, 1, 0, 2, 6, 4, 7, 8, 9, 0, 0 },
    );
    try expect_armies_from_input(
        &[_]i8{ 1, 0, 1, 0, 1, 1, 0, 1, 0, 1, 1, 1, 1, 0, 1, 0, 0, 1, 1, 1, 3, 0, 0, 0, 0 },
        &[_]i8{ 2, 0, 1, 0, 2, 7, 0, 3, 0, 2, 5, 7, 8, 0, 5, 0, 0, 9, 4, 6, 2, 0, 0, 0, 0 },
    );
    try expect_armies_from_input(
        &[_]i8{ A, 0, A, 0, A, A, 0, A, 0, A, A, A, A, 0, A, 0, 0, A, A, A, C, 0, 0, 0, 0 },
        &[_]i8{ A, 0, A, 0, A, A, 0, A, 0, A, A, A, A, 0, A, 0, 0, A, A, A, A, 0, 0, 0, 0 },
    );
    try expect_armies_from_input(
        &[_]i8{ A, 0, A, 0, A, A, A, A, A, A, 0, 0, 0, 0, 0, C, 0, C, 0, E, C, C, C, 0, 0 },
        &[_]i8{ A, 0, A, 0, A, A, A, A, A, A, 0, 0, 0, 0, 0, A, 0, A, 0, A, A, A, A, 0, 0 },
    );
    try expect_armies_from_input(
        &[_]i8{ 0, 0, A, 0, B, C, 0, A, 0, 0, 0, 0, 0, 0, D, E, 0, F, 0, 0, 0, 0, F, 0, G },
        &[_]i8{ 0, 0, A, 0, A, A, 0, A, 0, 0, 0, 0, 0, 0, A, A, 0, A, 0, 0, 0, 0, A, 0, A },
    );
    try expect_armies_from_input(
        &[_]i8{ 0, 0, A, 0, B, C, 0, A, 0, 0, C, 0, 0, 0, D, C, 0, E, 0, D, 0, 0, E, 0, D },
        &[_]i8{ 0, 0, B, 0, A, C, 0, J, 0, 0, A, 0, 0, 0, G, D, 0, A, 0, F, 0, 0, A, 0, E },
    );

    // all possible realistic but absurd input (-13..12)
    try expect_armies_from_input(
        &[_]i8{ A, 1, B, 2, C, 3, D, 4, E, 5, F, 6, G, 7, H, 8, I, 9, J, j, K, k, L, l, M },
        &armies_from_pos(&[_]i8{ A, 1, B, 2, C, 3, D, 4, E, 5, F, 6, G, 7, H, 8, I, 9, J, j, K, k, L, l, M }),
    );

    // repeat the realistic output back as input again
    try expect_armies_from_input(
        &[_]i8{ A, 1, B, 2, C, 3, D, 4, E, 5, F, 6, G, 7, H, 8, I, 9, J, j, K, k, L, l, M },
        &armies_from_pos(&[_]i8{ A, 4, A, 1, A, 5, A, 5, A, 2, A, 3, A, 1, A, 5, A, 2, A, 3, A, 4, A, 5, A }),
    );

    // most extreme -127 to -1 all white
    try expect_armies_from_input(
        &[_]i8{ A, A, A, A, A, A, A, A, A, A, A, A, A, A, A, A, A, A, A, A, A, A, A, A, A },
        &armies_from_pos(&[_]i8{ Z, Z, Z, Z, Z, Z, Z, Z, Z, Z, Z, Z, Z, Z, Z, Z, Z, Z, Z, Z, Z, Z, Z, Z, Z }),
    );

    // most extreme 127 to 1 all black
    try expect_armies_from_input(
        &[_]i8{ 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1 },
        &armies_from_pos(&[_]i8{ z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z }),
    );

    // a mix of extreme values
    try expect_armies_from_input(
        &[_]i8{ A, 1, 1, 1, 1, 2, B, 1, C, C, 2, 0, 1, C, 3, 2, 2, 0, 2, D, 2, 2, 2, 2, 2 },
        &armies_from_pos(&[_]i8{ Z, z, j, z, z, z, M, 1, A, K, z, 0, j, J, k, l, z, 0, k, J, z, k, z, z, z }),
    );
}

test "update armies" {
    const j: i8 = 10;
    const k: i8 = 11;
    const l: i8 = 12;
    const A: i8 = -1;
    const B: i8 = -2;
    const C: i8 = -3;
    const D: i8 = -4;
    const E: i8 = -5;
    const F: i8 = -6;
    const G: i8 = -7;
    const H: i8 = -8;
    const I: i8 = -9;
    const J: i8 = -10;
    const K: i8 = -11;
    const L: i8 = -12;
    const M: i8 = -13;

    const expected = [_]i8{ A, 1, B, 2, C, 3, D, 4, E, 5, F, 6, G, 7, H, 8, I, 9, J, j, K, k, L, l, M };
    var actual = [_]i8{ A, 4, A, 1, A, 5, A, 5, A, 2, A, 3, A, 1, A, 5, A, 2, A, 3, A, 4, A, 5, A };

    update_armies(&actual);
    try expect(is_equal_25i8(&expected, &actual));
}
