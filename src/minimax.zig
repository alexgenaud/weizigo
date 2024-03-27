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

// MAX_DEPTH = 1 COLLISION_SIZE =  1 TREE_SIZE =    10
// MAX_DEPTH = 2 COLLISION_SIZE =  2 TREE_SIZE =    70
// MAX_DEPTH = 3 COLLISION_SIZE =  3 TREE_SIZE =   427
// MAX_DEPTH = 4 COLLISION_SIZE =  6 TREE_SIZE =  2190
// MAX_DEPTH = 5 COLLISION_SIZE = 12 TREE_SIZE =  9217
//
// to reduce but the following work
// MAX_DEPTH = 6 COLLISION_SIZE = 24 TREE_SIZE = 32100 (crahes)
// MAX_DEPTH = 6 COLLISION_SIZE = 24 TREE_SIZE = 32105 (-- trial --)
// MAX_DEPTH = 6 COLLISION_SIZE = 24 TREE_SIZE = 32110 (no collisions)
const MAX_DEPTH = 6;
const COLLISION_SIZE = 24; // safe collision if too small
const TREE_SIZE = 32105; // crash if too small

const SEQ_TABLE_SIZE: u32 = COLLISION_SIZE * TREE_SIZE;
var blind_table = [_]u32{0} ** 33_554_432; // 2^25
var seq_index_empty: u32 = COLLISION_SIZE; // FIXME cannot set to zero
pub const seq_score = struct {
    seq: u8 = 0,
    score: i8 = UNDEF,
};

var seq_table = [_]seq_score{.{}} ** SEQ_TABLE_SIZE;
var zero_empty = &seq_table[0];

pub fn get_game_score(pos: *const [25]i8) i8 {
    var lowest = state.lowest_blind_from_pos(&pos);
    var seq_block_from_blind_table = blind_table[lowest.blind];
    if (seq_block_from_blind_table == 0) return UNDEF;
    var i = seq_block_from_blind_table;
    while (i < seq_block_from_blind_table + COLLISION_SIZE) : (i += 1) {
        var curr = &seq_table[i];
        if (curr.seq == lowest.seq or curr.score == UNDEF) {
            return curr.score;
        }
    }
    return UNDEF;
}

pub fn set_game_score(pos: *const [25]i8, score: i8) i8 {
    var lowest = state.lowest_blind_from_pos(pos);

    var seq_block_from_blind_table = blind_table[lowest.blind];
    if (seq_block_from_blind_table == 0) {
        if (seq_index_empty + COLLISION_SIZE > seq_table.len) {
            print("Uh oh! we have run out of space\n", .{});
        }
        seq_block_from_blind_table = seq_index_empty;
        blind_table[lowest.blind] = seq_index_empty;
        seq_index_empty += COLLISION_SIZE;
    }

    var i = seq_block_from_blind_table;
    while (i < seq_block_from_blind_table + COLLISION_SIZE) : (i += 1) {
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
        // if (curr.seq == lowest.seq and
        //     curr.score != UNDEF and
        //     curr.score != score)
        // {
        //     // found but occupied by different score
        //     print("Uh oh! found blind={} and block seq={} with score={} but failed to set seq={} with score={}\n", .{
        //         lowest.blind,
        //         curr.seq,
        //         curr.score,
        //         lowest.seq,
        //         score,
        //     });
        //     return curr.score;
        // }
    }
    print("Uh oh! found blind={} and block seq={} but no space to put score={}\n", .{ lowest.blind, lowest.seq, score });
    return UNDEF;
}

pub fn pos_score(pos: *const [25]i8, force_score: bool) i8 {
    var diff = state.stone_diff_from_pos(pos);
    if (diff > 3 or diff < -1 or force_score) {
        return diff;
    }
    return UNDEF;
}

pub fn minimax(
    pos: *const [25]i8,
    color: i8,
    depth: u8,
) i8 {
    var score: i8 = pos_score(pos, false);
    if (score != UNDEF) { // game over
        //print("depth={} score={} returned organically\n", .{ depth, score });
        //state.print_armies(pos);
        return set_game_score(pos, score);
    }
    if (depth >= MAX_DEPTH) {
        score = pos_score(pos, true);
        //print("depth={} score={} max depth reached\n", .{ depth, score });
        //state.print_armies(pos);
        return set_game_score(pos, score);
    }
    var val: i8 = if (color > 0) 99 else -99;
    var child_cnt: u8 = 0;
    for (0..25) |p| { // FIXME try ..8 for now, but should be 25
        if (pos[p] != 0) continue;
        //print("loop --- color={} depth={} check p={}\n", .{ color, depth, p });
        child_cnt += 1;

        // var legal: [25]i8 = undefined;
        // if (state.armies_from_move(pos, -color, @intCast(p))) |success| {
        //     legal = success;
        // } else |_| continue;

        var child: [25]i8 = state.armies_from_move(
            pos,
            -color,
            @intCast(p),
        ) catch continue;

        val = if (color > 0)
            min2(val, minimax(&child, -color, depth + 1))
        else
            max2(val, minimax(&child, -color, depth + 1));
    }
    if (child_cnt == 0) val = pos_score(pos, true);
    return set_game_score(pos, val);
}

pub fn main() !void {
    print("start with MAX_DEPTH={} COLLISION_SIZE={} TREE_SIZE={}\n", .{
        MAX_DEPTH,
        COLLISION_SIZE,
        TREE_SIZE,
    });
    const board = [_]i8{0} ** 25;
    var root_score = minimax(&board, -1, 0);
    print("completed with root score={}\n", .{root_score});
    print("end with MAX_DEPTH={} COLLISION_SIZE={} TREE_SIZE={}\n", .{
        MAX_DEPTH,
        COLLISION_SIZE,
        TREE_SIZE,
    });
}

// test "white always wins, terminal leaf souls, hopeless black parent" {
//     const W = -1;
//     const WHITE_TO_PLAY = false;
//     const BLACK_TO_PLAY = true;

//     const white_diagonal_win = [_]i8{
//         W, 1, 1,
//         1, W, 1,
//         0, W, W,
//     };
//     const white_diagonal_soul = soul_from_pos(&white_diagonal_win);
//     const white_diagonal_score = pos_score(&white_diagonal_win);

//     // test score
//     // negative for W win,
//     // with 0 + 1 remaining
//     try expect(white_diagonal_score == -2);

//     var souls: SoulTable = SoulTable{};

//     // minimax returns parent/root score,
//     // is that what we expect?
//     try expect(-2 == minimax(&white_diagonal_win, WHITE_TO_PLAY, &souls));
//     try expect(souls.get_count() == 1);

//     // sibling, another way for white to win
//     const white_bottom_row_win = [_]i8{
//         W, 1, 1,
//         1, 0, 1,
//         W, W, W,
//     };
//     const white_bottom_row_soul = soul_from_pos(&white_bottom_row_win);
//     const white_bottom_row_score = pos_score(&white_bottom_row_win);

//     try expect(white_bottom_row_score == -2);
//     try expect(-2 == minimax(&white_bottom_row_win, WHITE_TO_PLAY, &souls));
//     try expect(souls.get_count() == 2);

//     // let's test integrity of both previous states
//     try expect(white_diagonal_score == souls.get_score(white_diagonal_soul));
//     try expect(white_bottom_row_score == souls.get_score(white_bottom_row_soul));
//     try expect(UNDEF == souls.get_score(123));

//     // going up (backwards), let's consider parent
//     const black_parent = [_]i8{
//         W, 1, 1,
//         1, 0, 1,
//         0, W, W,
//     };
//     try expect(pos_score(&black_parent) == UNDEF);
//     try expect(-2 == minimax(&black_parent, BLACK_TO_PLAY, &souls));
//     try expect(souls.get_count() == 3);
// }

// test "white always wins, start from hopeless black parent" {
//     const W = -1;
//     const BLACK_TO_PLAY = true;
//     var souls: SoulTable = SoulTable{};
//     const white_diagonal_win = [_]i8{
//         W, 1, 1,
//         1, W, 1,
//         0, W, W,
//     };
//     const white_diagonal_soul = soul_from_pos(&white_diagonal_win);
//     const white_diagonal_score = pos_score(&white_diagonal_win);

//     // test score
//     // negative for W win,
//     // with 0 + 1 remaining
//     try expect(white_diagonal_score == -2);

//     // sibling, another way for white to win
//     const white_bottom_row_win = [_]i8{
//         W, 1, 1,
//         1, 0, 1,
//         W, W, W,
//     };
//     const white_bottom_row_soul = soul_from_pos(&white_bottom_row_win);
//     const white_bottom_row_score = pos_score(&white_bottom_row_win);

//     try expect(white_bottom_row_score == -2);

//     // prove that souls knows nothing
//     try expect(UNDEF == souls.get_score(white_diagonal_soul));
//     try expect(UNDEF == souls.get_score(white_bottom_row_soul));
//     try expect(UNDEF == souls.get_score(123));

//     // going up (backwards), let's consider parent
//     const black_parent = [_]i8{
//         W, 1, 1,
//         1, 0, 1,
//         0, W, W,
//     };
//     try expect(pos_score(&black_parent) == UNDEF);
//     try expect(-2 == minimax(&black_parent, BLACK_TO_PLAY, &souls));
//     try expect(souls.get_count() == 3);
// }

// test "unbalanced tree, two and three levels from white" {
//     const W = -1;
//     const WHITE_TO_PLAY = false;
//     const BLACK_TO_PLAY = true;
//     var souls: SoulTable = SoulTable{};
//     const white_diagonal_win = [_]i8{
//         W, 0, 1,
//         1, W, 1,
//         1, W, W,
//     };
//     const white_diagonal_score = pos_score(&white_diagonal_win);
//     try expect(white_diagonal_score == -2);
//     try expect(-2 == minimax(&white_diagonal_win, WHITE_TO_PLAY, &souls));

//     // black nephew wins by row and diagonal
//     const black_nephew_double_win = [_]i8{
//         W, W, 1,
//         1, 1, 1,
//         1, W, W,
//     };
//     const black_nephew_double_score = pos_score(&black_nephew_double_win);

//     // no empty space but still a positive win for black
//     try expect(black_nephew_double_score == 1);
//     try expect(1 == minimax(&black_nephew_double_win, BLACK_TO_PLAY, &souls));

//     // going up (backwards), let's consider parent
//     const black_parent = [_]i8{
//         W, 1, 1,
//         1, 0, 1,
//         0, W, W,
//     };
//     try expect(pos_score(&black_parent) == UNDEF);

//     try expect(-2 == minimax(&black_parent, BLACK_TO_PLAY, &souls));
//     try expect(souls.get_count() == 5);
// }

// test "full minimax from empty board" {
//     const W: i8 = -1;
//     var souls: SoulTable = SoulTable{};
//     var empty_board = pos_from_view(0);
//     var resMinimax = minimax(&empty_board, false, &souls);
//     try expect(resMinimax == 0);
//     try expect(souls.get_score(0) == souls.get_score(1)); // top left
//     try expect(souls.get_score(3) == souls.get_score(81)); // top == middle
//     try expect(souls.get_score_from_pos(&[9]i8{
//         W, 1, 0,
//         W, 1, 0,
//         0, 0, 0,
//     }) == 5);
//     try expect(souls.get_score_from_pos(&[9]i8{
//         W, 1, 0,
//         W, 1, 0,
//         0, 1, 0,
//     }) == 5);
//     try expect(souls.get_score_from_pos(&[9]i8{
//         W, 1, 0,
//         W, 1, 0,
//         1, 0, 0,
//     }) == 3);
//     try expect(souls.get_score_from_pos(&[9]i8{
//         W, 1, 0,
//         W, 1, 0,
//         1, W, 0,
//     }) == 3);
//     try expect(souls.get_score_from_pos(&[9]i8{
//         W, 1, 1,
//         W, 1, 0,
//         1, W, 0,
//     }) == 3);
//     try expect(souls.get_score_from_pos(&[9]i8{
//         W, 1, 1,
//         W, 1, 0,
//         1, W, 0,
//     }) == 3);
//     try expect(souls.get_score_from_pos(&[9]i8{
//         W, 1, 1,
//         W, 1, W,
//         1, W, 0,
//     }) == UNDEF);
//     try expect(souls.get_score_from_pos(&[9]i8{
//         W, 1, 0,
//         W, 1, 1,
//         1, W, 0,
//     }) == 0);
//     try expect(souls.get_count() >= 765);
// }

// test "four levels from the top, white to play" {
//     const W = -1;
//     const WHITE_TO_PLAY = false;
//     var souls: SoulTable = SoulTable{};
//     const white_to_play = [_]i8{
//         W, 0, 1,
//         1, 0, 1,
//         0, W, W,
//     };
//     try expect(pos_score(&white_to_play) == UNDEF);
//     try expect(minimax(&white_to_play, WHITE_TO_PLAY, &souls) == 3);
//     try expect(souls.get_score(4153) == 3);
//     try expect(souls.get_score(4180) == -2);
//     try expect(souls.get_score(4234) == 3);
//     try expect(souls.get_score(8314) == -2);
//     //
//     // WHITE                    (4153+3)
//     //                         /    |   \
//     //                        /     |    \
//     // BLACK          (4180-2)  (4234+3)  (8314-2)
//     //                /      \            /     \
//     //               /        \          /       \
//     // WHITE   (4342-2) (10502-2)   (10768+1)   (8476-2)
//     //                               /
//     //                              /
//     // BLACK                  (10849+1)
//     //
//     try expect(souls.get_score(4342) == -2);
//     try expect(souls.get_score(10502) == -2);
//     try expect(souls.get_score(10768) == 1);
//     try expect(souls.get_score(8476) == -2);
//     try expect(souls.get_score(10849) == 1);
//     try expect(souls.get_count() >= 9);
// }

// test "white lead to draw to win early" {
//     const W: i8 = -1;
//     var souls: SoulTable = SoulTable{};
//     var empty_board = pos_from_view(0);
//     try expect(0 == minimax(&empty_board, false, &souls));
//     try expect(souls.get_score_from_pos(&[9]i8{
//         1, 0, 0,
//         1, W, 0,
//         0, 0, 0,
//     }) == 0);
//     try expect(souls.get_score_from_pos(&[9]i8{
//         1, 0, 0,
//         1, W, 0,
//         W, 0, 0,
//     }) == 0);
//     try expect(souls.get_score_from_pos(&[9]i8{
//         1, 0, 1,
//         1, W, 0,
//         W, 0, 0,
//     }) == 0);
//     try expect(souls.get_score_from_pos(&[9]i8{
//         1, W, 1,
//         1, W, 0,
//         W, 0, 0,
//     }) == 0);
//     try expect(souls.get_score_from_pos(&[9]i8{
//         1, W, 1,
//         1, W, 0,
//         W, 1, 0,
//     }) == 0);
//     try expect(souls.get_count() >= 765);
// }
