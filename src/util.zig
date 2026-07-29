// STREAM-DISCIPLINE (DSPro, 2026-07-30): stdout for data, stderr for diagnostics.
// out() → stdout (parseable/filterable/redirectable output).
// note()/warn() → stderr (diagnostics, progress, warnings, errors).
// gtp.zig:691,1056 is the reference pattern.

const std = @import("std");
const debug = std.debug;

pub const UNDEF: i8 = -128;

// ── lazy stdout writer (one Threaded instance, shared by all out() calls) ───

var stdout_ready = false;
var stdout_threaded: std.Io.Threaded = undefined;
var stdout_buf: [4096]u8 = undefined;

fn stdoutWriter() std.Io.File.Writer {
    if (!stdout_ready) {
        stdout_threaded = std.Io.Threaded.init(std.heap.page_allocator, .{});
        stdout_ready = true;
    }
    const io = stdout_threaded.io();
    return std.Io.File.stdout().writer(io, &stdout_buf);
}

/// Write data to stdout — anything a caller might parse, filter, redirect,
/// or commit as evidence. Result, verdict, census, report.
pub fn out(comptime fmt: []const u8, args: anytype) void {
    var w = stdoutWriter();
    w.interface.print(fmt, args) catch {};
    w.flush() catch {};
}

/// Write diagnostics to stderr — progress, warnings, errors, heartbeats.
pub fn note(comptime fmt: []const u8, args: anytype) void {
    debug.print(fmt, args);
}

/// Write a warning to stderr. Same channel as note, explicit semantics.
pub fn warn(comptime fmt: []const u8, args: anytype) void {
    debug.print(fmt, args);
}

pub fn println() void {
    out("\n", .{});
}
