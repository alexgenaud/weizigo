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
// 1 099511 627776 // 2^40 1 TB
//   847288 609443 // 3^25 (all possible positions)
//   549755 813888 // 2^39 550 GB
//     4294 967296 // 2^32 4 GB
//      134 217728 // 2^27 134 MB
//       33 554432 // 2^25 33 MB
//       16 777216 // 2^24 16 MB
//
const std = @import("std");
const print = std.debug.print;
const expect = std.testing.expect;
const state = @import("state.zig");
const is_equal_25i8 = state.is_equal_25i8;
const armies_from_move = state.armies_from_move;

const M27: u32 = 134217728; // 2^27 = 134 MB SIZE
const B27: u32 = 134217728 - 15; // random numbers would help

const zob_black: [25]u32 = [_]u32{
    3827615441 % B27, 3314172905 % B27, 3922154556 % B27,
    3545139714 % B27, 3587074312 % B27, 3509125373 % B27,
    3978476749 % B27, 3887227403 % B27, 3796769641 % B27,
    3949201942 % B27, 3961167732 % B27, 3977259949 % B27,
    3456398560 % B27, 3890313154 % B27, 3976898036 % B27,
    3945890456 % B27, 3404357968 % B27, 3967438463 % B27,
    3992740711 % B27, 3537330497 % B27, 3874110767 % B27,
    3533995331 % B27, 3930711256 % B27, 3912730475 % B27,
    3953630078 % B27,
};

const zob_white: [25]u32 = [_]u32{
    3896137914 % B27, 3593109227 % B27, 3951846072 % B27,
    3167054141 % B27, 3299025455 % B27, 3971147125 % B27,
    3969505456 % B27, 3979650384 % B27, 3944043658 % B27,
    3369704711 % B27, 3894411607 % B27, 3974570307 % B27,
    3849756429 % B27, 3790675596 % B27, 3947682203 % B27,
    3699449942 % B27, 3474742594 % B27, 3920196172 % B27,
    3769465660 % B27, 3956089803 % B27, 3963883144 % B27,
    3359573571 % B27, 3952703047 % B27, 3930923716 % B27,
    3639805307 % B27,
};

var table_z_hits = [_]u32{0} ** M27; // 17 MB
var table_z_views: [M27]u40 = [_]u40{0} ** M27; // 134 MB

pub fn zobrist_from_view(view: u40) u32 {
    var rem = view;
    var zob: u32 = 0; // empty
    var mod3: u40 = undefined;
    for (0..25) |p| {
        mod3 = rem % 3;
        if (mod3 == 1) {
            zob ^= zob_black[p];
        } else if (mod3 == 2) {
            zob ^= zob_white[p];
        }
        rem /= 3;
    }
    return zob;
}

pub fn zobrist_from_pos(pos: *const [25]i8) u32 {
    var zob: u32 = 0; // empty
    for (0..25) |p| {
        if (pos[p] > 0) zob ^= zob_black[p];
        if (pos[p] < 0) zob ^= zob_white[p];
    }
    return zob;
}

var zobrist_repeat: u32 = 0;
var zobrist_hits: u32 = 0;
var zobrist_collision: u32 = 0;

fn set_board_as_zobrist_view(board: *const [25]i8) u32 {
    var view: u40 = state.view_from_pos(board);
    var zob: u32 = zobrist_from_pos(board);
    var cnt = table_z_hits[zob];
    table_z_hits[zob] += 1;
    zobrist_hits += 1;
    if (cnt > 0) {
        var old_view = table_z_views[zob];
        if (view != old_view) zobrist_collision += 1;
        return cnt;
    }

    table_z_views[zob] = view;
    return cnt;
}

pub fn num_prev_requests(board: *const [25]i8) u32 {
    var cnt = set_board_as_zobrist_view(board);
    if (cnt > 0) {
        zobrist_repeat += 1;
        return cnt;
    }

    var og = board.*;
    var ro = state.armies_reflect(&og);
    _ = set_board_as_zobrist_view(&ro);
    for (0..3) |_| {
        state.update_rotate(&og);
        state.update_rotate(&ro);
        _ = set_board_as_zobrist_view(&og);
        _ = set_board_as_zobrist_view(&ro);
    }
    return cnt;
}

pub fn recurse(parent: *const [25]i8, color: i8, depth: u8) void {
    _ = num_prev_requests(parent);
    if (depth >= 6) return;

    for (0..25) |p| {
        if (parent[p] != 0) continue;

        var child = state.armies_from_move(
            parent,
            -color,
            @intCast(p),
        );
        if (child) |legal| {
            recurse(
                &legal,
                -color,
                depth + 1,
            );
        } else |_| continue; // ignore illegal
    }

    if (depth < 1) {
        print("zobrist view collision {}, repeat {}, hits {}\n", .{
            zobrist_collision,
            zobrist_repeat,
            zobrist_hits,
        });
    }
}

pub fn main() !void {
    const board = [_]i8{0} ** 25;
    recurse(&board, -1, 0);
}

test "zobrist from pos" {
    const W: i8 = -1;
    try expect(0 == zobrist_from_pos(&[_]i8{0} ** 25));
    try expect(zob_black[0] == zobrist_from_pos(&[25]i8{
        1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    }));
    try expect(zob_white[0] == zobrist_from_pos(&[25]i8{
        W, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    }));

    const b13 = [25]i8{
        0, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    };
    const b57 = [25]i8{
        0, 0, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    };
    var zob13: u32 = zob_black[1];
    zob13 ^= zob_black[3];
    var zob57: u32 = zob_black[5];
    zob57 ^= zob_black[7];

    try expect(zob13 == zobrist_from_pos(&b13));
    try expect(zob57 == zobrist_from_pos(&b57));

    try expect(zob13 ^ zob57 ==
        zobrist_from_view(state.view_from_pos(&b13) +
        state.view_from_pos(&b57)));
}

test "zobrist from positions" {
    var exp: u40 = 1;
    for (0..25) |p| {
        try expect(zob_black[p] ==
            zobrist_from_pos(&state.pos_from_view(exp)));
        try expect(zob_white[p] ==
            zobrist_from_pos(&state.pos_from_view(exp * 2)));
        exp *= 3;
    }
}

test "view collision" {
    const huge_test: usize = 999; // 9999999
    for (0..huge_test) |a| {
        for (0..huge_test) |b| {
            if (a == b) continue;
            try expect(zobrist_from_view(@intCast(a)) !=
                zobrist_from_view(@intCast(b)));
        }
    }
}
