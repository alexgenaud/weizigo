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

const UNDEF: i8 = -128;

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
pub fn armies_from_pos(pos: *const [25]i8) [25]i8 {
    var armies: [25]i8 = undefined;
    var flagb: i8 = 0;
    var flagw: i8 = 0;
    for (0..25) |p| {
        if (pos[p] == 0) {
            // if empty then continue
            armies[p] = 0;
            continue;
        }
        const color: i8 = if (pos[p] > 0) 1 else -1; // 1 == black or -1 == white
        if (p >= 5 and p % 5 > 0 and (pos[p - 5] * color > 0 and pos[p - 1] * color > 0)) {
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
        } else if (p >= 5 and pos[p - 5] * color > 0) {
            // if north exists and north is friend
            armies[p] = armies[p - 5]; // north
        } else if (p >= 1 and p % 5 > 0 and pos[p - 1] * color > 0) {
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
    return armies;
}

fn is_equal_25i8(a: *const [25]i8, b: *const [25]i8) bool {
    for (0..25) |p| {
        if (a[p] != b[p]) return false;
    }
    return true;
}

fn expect_pos_repeatable_army(a: *const [25]i8, b: *const [25]i8) !void {
    var c = armies_from_pos(b);
    try expect(is_equal_25i8(a, &c));
    try expect(is_equal_25i8(a, &armies_from_pos(&c)));
}

test "print full range" {
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
    const T: i8 = -124;
    const W: i8 = -127;

    try expect(is_equal_25i8(&[_]i8{
        A, 1, 1, 1, 1,
        2, B, 1, C, C,
        2, 0, 1, C, 3,
        2, 2, 0, 2, D,
        2, 2, 2, 2, 2,
    }, &armies_from_pos(&[_]i8{
        W, v, 2, v, v,
        v, T, 8, A, W,
        v, 0, 4, T, 9,
        5, v, 0, 6, -126,
        v, 7, v, v, 123,
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

    try expect_pos_repeatable_army(&[_]i8{ A, 1, B, 2, C, 3, D, 4, E, 5, F, 6, G, 7, H, 8, I, 9, J, j, K, k, L, l, M }, &[_]i8{ A, 4, A, 1, A, 5, A, 5, A, 2, A, 3, A, 1, A, 5, A, 2, A, 3, A, 4, A, 5, A });
    try expect_pos_repeatable_army(&[_]i8{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }, &[_]i8{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 });
    try expect_pos_repeatable_army(&[_]i8{ 0, 1, 0, 0, 2, 1, 1, 0, 2, 2, 0, 0, 2, 2, 0, 0, 2, 2, 0, 3, 2, 2, 0, 3, 3 }, &[_]i8{ 0, 1, 0, 0, 9, 3, 6, 0, 5, 4, 0, 0, 2, 9, 0, 0, 1, 9, 0, 3, 1, 1, 0, 9, 1 });
    try expect_pos_repeatable_army(&[_]i8{ 0, A, 0, 0, B, A, A, 1, 0, 2, 0, 3, 0, 2, 2, 4, 0, 5, 0, C, 0, 6, 0, 7, C }, &[_]i8{ 0, A, 0, 0, A, A, A, 2, 0, 7, 0, 3, 0, 1, 8, 2, 0, 3, 0, A, 0, 9, 0, 1, A });
    try expect_pos_repeatable_army(&[_]i8{ 1, 0, 1, 0, 3, 1, 1, 1, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }, &[_]i8{ 1, 0, 1, 0, 2, 7, 1, 6, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 });
    try expect_pos_repeatable_army(&[_]i8{ 1, 1, 1, 1, 1, 1, 0, 0, 0, 1, 1, 0, 1, 0, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 2 }, &[_]i8{ 7, 3, 5, 1, 6, 2, 0, 0, 0, 9, 1, 0, 1, 0, 7, 4, 2, 8, 0, 0, 0, 0, 0, 0, 1 });
    try expect_pos_repeatable_army(&[_]i8{ 1, 0, 1, 1, 1, 1, 0, 1, 0, 1, 1, 0, 1, 0, 1, 1, 0, 1, 0, 0, 1, 1, 1, 0, 2 }, &[_]i8{ 1, 0, 2, 6, 4, 3, 0, 5, 0, 1, 2, 0, 8, 0, 6, 7, 0, 6, 0, 0, 4, 2, 1, 0, 1 });
    try expect_pos_repeatable_army(&[_]i8{ 1, 1, 0, 2, 0, 1, 0, 0, 0, 1, 1, 0, 1, 0, 1, 1, 0, 1, 1, 1, 1, 1, 1, 0, 0 }, &[_]i8{ 1, 2, 0, 1, 0, 8, 0, 0, 0, 3, 7, 0, 2, 0, 3, 9, 0, 7, 5, 2, 1, 7, 1, 0, 0 });
    try expect_pos_repeatable_army(&[_]i8{ 1, 1, 0, 2, 0, 1, 0, 0, 0, 1, 1, 0, 1, 0, 1, 1, 0, 1, 1, 1, 1, 1, 1, 0, 0 }, &[_]i8{ 4, 2, 0, 3, 0, 1, 0, 0, 0, 9, 2, 0, 8, 0, 3, 1, 0, 2, 6, 4, 7, 8, 9, 0, 0 });
    try expect_pos_repeatable_army(&[_]i8{ 1, 0, 1, 0, 1, 1, 0, 1, 0, 1, 1, 1, 1, 0, 1, 0, 0, 1, 1, 1, 3, 0, 0, 0, 0 }, &[_]i8{ 2, 0, 1, 0, 2, 7, 0, 3, 0, 2, 5, 7, 8, 0, 5, 0, 0, 9, 4, 6, 2, 0, 0, 0, 0 });
    try expect_pos_repeatable_army(&[_]i8{ A, 0, A, 0, A, A, 0, A, 0, A, A, A, A, 0, A, 0, 0, A, A, A, C, 0, 0, 0, 0 }, &[_]i8{ A, 0, A, 0, A, A, 0, A, 0, A, A, A, A, 0, A, 0, 0, A, A, A, A, 0, 0, 0, 0 });
    try expect_pos_repeatable_army(&[_]i8{ A, 0, A, 0, A, A, A, A, A, A, 0, 0, 0, 0, 0, C, 0, C, 0, E, C, C, C, 0, 0 }, &[_]i8{ A, 0, A, 0, A, A, A, A, A, A, 0, 0, 0, 0, 0, A, 0, A, 0, A, A, A, A, 0, 0 });
    try expect_pos_repeatable_army(&[_]i8{ 0, 0, A, 0, B, C, 0, A, 0, 0, 0, 0, 0, 0, D, E, 0, F, 0, 0, 0, 0, F, 0, G }, &[_]i8{ 0, 0, A, 0, A, A, 0, A, 0, 0, 0, 0, 0, 0, A, A, 0, A, 0, 0, 0, 0, A, 0, A });
    try expect_pos_repeatable_army(&[_]i8{ 0, 0, A, 0, B, C, 0, A, 0, 0, C, 0, 0, 0, D, C, 0, E, 0, D, 0, 0, E, 0, D }, &[_]i8{ 0, 0, B, 0, A, C, 0, J, 0, 0, A, 0, 0, 0, G, D, 0, A, 0, F, 0, 0, A, 0, E });

    // all possible realistic but absurd input (-13..12)
    try expect(is_equal_25i8(&[_]i8{ A, 1, B, 2, C, 3, D, 4, E, 5, F, 6, G, 7, H, 8, I, 9, J, j, K, k, L, l, M }, &armies_from_pos(&[_]i8{ A, 1, B, 2, C, 3, D, 4, E, 5, F, 6, G, 7, H, 8, I, 9, J, j, K, k, L, l, M })));

    // repeat the realistic output back as input again
    try expect(is_equal_25i8(&[_]i8{ A, 1, B, 2, C, 3, D, 4, E, 5, F, 6, G, 7, H, 8, I, 9, J, j, K, k, L, l, M }, &armies_from_pos(&[_]i8{ A, 4, A, 1, A, 5, A, 5, A, 2, A, 3, A, 1, A, 5, A, 2, A, 3, A, 4, A, 5, A })));

    // most extreme -127 to -1 all white
    try expect(is_equal_25i8(&[_]i8{ A, A, A, A, A, A, A, A, A, A, A, A, A, A, A, A, A, A, A, A, A, A, A, A, A }, &armies_from_pos(&[_]i8{ Z, Z, Z, Z, Z, Z, Z, Z, Z, Z, Z, Z, Z, Z, Z, Z, Z, Z, Z, Z, Z, Z, Z, Z, Z })));

    // most extreme 127 to 1 all black
    try expect(is_equal_25i8(&[_]i8{ 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1 }, &armies_from_pos(&[_]i8{ z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z, z })));

    // a mix of extreme values
    try expect(is_equal_25i8(&[_]i8{ A, 1, 1, 1, 1, 2, B, 1, C, C, 2, 0, 1, C, 3, 2, 2, 0, 2, D, 2, 2, 2, 2, 2 }, &armies_from_pos(&[_]i8{ Z, z, j, z, z, z, M, 1, A, K, z, 0, j, J, k, l, z, 0, k, J, z, k, z, z, z })));
}
