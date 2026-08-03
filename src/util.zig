// STREAM-DISCIPLINE (DSPro, 2026-07-30): stdout for data, stderr for diagnostics.
// out() → stdout (parseable/filterable/redirectable output).
// note()/warn() → stderr (diagnostics, progress, warnings, errors).
// gtp.zig:691,1056 is the reference pattern.

const std = @import("std");
const debug = std.debug;

pub const UNDEF: i8 = -128;

// ── stdout writer (persistent File.Writer, created once) ───
//
// T307: Each out() call was creating a new File.Writer with pos=0, causing
// positional pwritev writes to overwrite at offset 0 on regular files.
// Pipes survived because the first positional write fails with Unseekable,
// switching the (per-writer) mode to streaming for that call. Fix: create
// ONE writer and reuse it, so the position counter correctly accumulates
// across all calls. Uses global_single_threaded Io — no background thread.

var stdout_ready = false;
var stdout_buf: [4096]u8 = undefined;
var stdout_writer: std.Io.File.Writer = undefined;

fn stdoutWriter() *std.Io.File.Writer {
    if (!stdout_ready) {
        stdout_writer = std.Io.File.stdout().writer(
            std.Io.Threaded.global_single_threaded.io(),
            &stdout_buf,
        );
        stdout_ready = true;
    }
    return &stdout_writer;
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
