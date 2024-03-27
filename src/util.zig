const std = @import("std");
const expect = std.testing.expect;
const print = std.debug.print;

pub const UNDEF: i8 = -128;

pub fn max2(a: anytype, b: anytype) @TypeOf(a) {
    return if (a > b) a else b;
}

pub fn min2(a: anytype, b: anytype) @TypeOf(a) {
    return if (a < b) a else b;
}

pub fn min3(a: anytype, b: anytype, c: anytype) @TypeOf(a) {
    return min2(min2(a, b), c);
}

pub fn min4(a: anytype, b: anytype, c: anytype, d: anytype) @TypeOf(a) {
    return min2(min2(a, b), min2(c, d));
}

pub fn println() void {
    print("\n", .{});
}
