//! evidence.zig — the artifact surface of the two-surfaces split.
//!
//! Copyright (c) 2026 weizigo contributors.
//!
//! Task: T531 · Role: worker · Model: claude-opus-5 · Date: 2026-08-20
//!
//! ## Why this file exists
//!
//! T351 stopped on a real conflict: `zig build test` prints a cosmetic
//! `failed command:` line for every test binary that writes to stderr, even
//! when every test in it passes and the step exits 0 (Zig 0.16
//! `Run.evalZigTest` sets `result_stderr` on the success path; `build_runner`
//! then renders any step with non-empty `result_stderr` through
//! `printStepFailure`).  A test binary has exactly two channels: stdout is the
//! test-runner IPC protocol (writing there hangs the runner) and stderr is the
//! one that reaches the run log.  So "zero failed-command noise" and "keep the
//! `[EXPECTED]`/I4–I9 readings in the suite's output" looked mutually
//! exclusive: the only fix was to delete the readings.
//!
//! Ruling 4 (`docs/status/ROADMAP-2026-08-20.md` rev 3, 2026-08-20) says there
//! is no conflict, because there are two surfaces and only one of them is the
//! console:
//!
//!   > The console summary owes zero failed-command noise; the
//!   > `[EXPECTED]`/I4–I9 evidence lines live in the suite-truth manifest
//!   > artifact, which T369's gate reads.  Summary = console, evidence =
//!   > artifact — the stdout/stderr contract generalized.
//!
//! This module is the third channel that ruling needs: a file.  It is not a
//! logger and it is not for diagnostics — it carries **instrument readings**,
//! the numbers an invariant check actually measured, which is what tells a
//! bounded red from a defect.
//!
//! ## Contract
//!
//! `print` is `std.debug.print` with a different sink, chosen at compile time:
//!
//!   - **outside a test binary** (`zig run`, a deployed tool) it *is*
//!     `std.debug.print` — unchanged behaviour, byte for byte;
//!   - **inside a test binary** (`builtin.is_test`) the same bytes are
//!     appended to the evidence artifact and nothing reaches stderr.
//!
//! The artifact therefore carries byte-identical text to what the console used
//! to show.  That is deliberate: the manifest's expected-evidence lines are
//! plain prefixes of the real readings, so nothing has to be kept in sync with
//! a second format.
//!
//! Artifact path: `$WEIZIGO_EVIDENCE`, else `untracked/log/suite-evidence.log`
//! relative to the process cwd.  `tools/suite-truth.sh` always exports an
//! absolute path (not every `addTest` step in `build.zig` sets `cwd`).
//!
//! Writes use `O_APPEND`, so the parallel test binaries of one `zig build test`
//! interleave by whole `write(2)` calls rather than corrupting each other.  A
//! reading emitted by several `print` calls without a newline between them (the
//! `benson_alive_regression_check` mismatch dumps in `rules.zig` do this) can
//! still be split by a concurrent writer — those are failure paths that emit
//! nothing on a green run, and the gate does not key on them.
//!
//! ## Failure is not silent
//!
//! If the artifact cannot be opened the reading is dropped, with no fallback to
//! stderr — a fallback would quietly resurrect the console noise this exists to
//! remove.  Dropping is safe *because the gate is the control*: an unopenable
//! artifact means missing `EVIDENCE` lines, and
//! `sh tools/suite-truth.sh` goes RED naming each one.  Never make this
//! function report its own failure to stderr.

const std = @import("std");
const builtin = @import("builtin");

/// Where the readings land when nothing else is said.  Relative — callers that
/// cannot guarantee a cwd must export `WEIZIGO_EVIDENCE`.
pub const default_path: [:0]const u8 = "untracked/log/suite-evidence.log";

/// The line every suite run must carry whatever else it measures: proof that
/// the sink itself is alive.  Emitted by this file's own control test and
/// required by `docs/infra/suite-truth-manifest.md`, so a broken artifact
/// fails the gate on its own account rather than as a silence spread across
/// every instrument.
pub const sink_control_line = "[EXPECTED] evidence-sink control: artifact write ok";

/// One reading.  Same signature and same bytes as `std.debug.print`; only the
/// sink differs, and only inside a test binary.
pub fn print(comptime fmt: []const u8, args: anytype) void {
    if (!builtin.is_test) {
        std.debug.print(fmt, args);
        return;
    }
    var buf: [4096]u8 = undefined;
    appendToArtifact(render(&buf, fmt, args));
}

/// Format one reading into `buf`.  Over-long readings are truncated rather
/// than dropped: a truncated number still fails the gate loudly if it is
/// wrong, while a dropped one fails it as "missing" and hides which instrument
/// spoke.  The truncation keeps the artifact line-structured — the gate
/// matches at line starts, so a reading that swallowed its own newline would
/// hide the *next* one too.
pub fn render(buf: []u8, comptime fmt: []const u8, args: anytype) []const u8 {
    return std.fmt.bufPrint(buf, fmt, args) catch blk: {
        buf[buf.len - 1] = '\n';
        break :blk buf;
    };
}

/// The artifact path in force for this process.
pub fn path() [*:0]const u8 {
    if (std.c.getenv("WEIZIGO_EVIDENCE")) |p| return p;
    return default_path.ptr;
}

fn appendToArtifact(text: []const u8) void {
    const fd = std.c.open(path(), std.c.O{ .ACCMODE = .WRONLY, .CREAT = true, .APPEND = true }, @as(c_int, 0o644));
    if (fd < 0) return;
    defer _ = std.c.close(fd);
    var written: usize = 0;
    while (written < text.len) {
        const n = std.c.write(fd, text.ptr + written, text.len - written);
        if (n <= 0) return;
        written += @intCast(n);
    }
}

/// Read the artifact back the same way the gate does — used by the controls in
/// `evidence_control.zig`, which is the only place they belong: a control that
/// ships inside this file would run again inside every instrument binary that
/// imports it, inflating the suite's test counts for no extra coverage.
pub fn readArtifact(buf: []u8) ?[]const u8 {
    const fd = std.c.open(path(), std.c.O{ .ACCMODE = .RDONLY }, @as(c_int, 0));
    if (fd < 0) return null;
    defer _ = std.c.close(fd);
    var filled: usize = 0;
    while (filled < buf.len) {
        const n = std.c.read(fd, buf.ptr + filled, buf.len - filled);
        if (n <= 0) break;
        filled += @intCast(n);
    }
    return buf[0..filled];
}
