const std = @import("std");
const print = std.debug.print;

pub const UNDEF: i8 = -128;

pub fn println() void {
    print("\n", .{});
}
