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

pub fn main() !void {
    std.debug.print("weizigo: brute-force perfect 5x5 go\n", .{});
    std.debug.print("run the full test suite with `zig build test`\n", .{});
    std.debug.print("or a single module with e.g. `zig test src/minimax.zig`\n", .{});
}

// Pull every module's tests into `zig build test`.
test {
    _ = @import("util.zig");
    _ = @import("state.zig");
    _ = @import("zobrist.zig");
    _ = @import("minimax.zig");
}
