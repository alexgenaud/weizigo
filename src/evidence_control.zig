//! evidence_control.zig — the controls for the evidence artifact sink.
//!
//! Copyright (c) 2026 weizigo contributors.
//!
//! Task: T531 · Role: worker · Model: claude-opus-5 · Date: 2026-08-20
//!
//! These live in their own file, not inside `evidence.zig`, because a test in
//! `evidence.zig` would be compiled into *every* instrument binary that
//! imports it — six copies of the same assertion, six copies of the same
//! reading in the artifact, and six inflated test counts, for no extra
//! coverage.
//!
//! Two of the three controls this design needs are here.  The third — that a
//! passing test binary emits nothing on stderr, which is the *console* half of
//! the split — cannot be asserted from inside a test binary; it lives in
//! `tools/regression-suite-surfaces.sh`, together with its seeded-defect twin.

const std = @import("std");
const evidence = @import("evidence.zig");

// Null control, in-band: this line must reach the run's artifact, and
// `docs/infra/suite-truth-manifest.md` requires it.  A sink that silently
// stopped working therefore fails the gate on its own account, rather than as
// a silence spread across every instrument at once.
test "evidence: the sink is alive — print() reaches the artifact" {
    evidence.print("{s}\n", .{evidence.sink_control_line});

    // The artifact is append-only and shared with the rest of the suite, so
    // allow for a large tail rather than expecting a one-line file.
    const buf = try std.testing.allocator.alloc(u8, 1 << 20);
    defer std.testing.allocator.free(buf);
    const body = evidence.readArtifact(buf) orelse {
        // No stderr fallback on purpose (see evidence.zig's header): the test
        // result is itself the console's summary surface, which is where a
        // broken sink belongs.
        return error.EvidenceArtifactUnreadable;
    };
    try std.testing.expect(std.mem.indexOf(u8, body, evidence.sink_control_line) != null);
}

test "evidence: WEIZIGO_EVIDENCE overrides the default artifact path" {
    const p = std.mem.span(evidence.path());
    if (std.c.getenv("WEIZIGO_EVIDENCE")) |override| {
        try std.testing.expectEqualStrings(std.mem.span(override), p);
    } else {
        try std.testing.expectEqualStrings(evidence.default_path, p);
    }
}

test "evidence: a reading that fits is rendered byte-for-byte" {
    var buf: [64]u8 = undefined;
    try std.testing.expectEqualStrings(
        "I4 2x2: violations=0 examined=28\n",
        evidence.render(&buf, "I4 {s}: violations={d} examined={d}\n", .{ "2x2", 0, 28 }),
    );
}

test "evidence: an over-long reading truncates and still ends its line" {
    // Seeded defect for the renderer: a reading wider than the buffer.  It
    // must not panic, must not be dropped, and must not swallow its newline —
    // a reading that ate its own line ending would hide the *next* reading
    // from a gate that matches at line starts.
    var buf: [32]u8 = undefined;
    const out = evidence.render(&buf, "I4 {s}: violations={d}\n", .{ "x" ** 100, 0 });
    try std.testing.expectEqual(@as(usize, 32), out.len);
    try std.testing.expectEqual(@as(u8, '\n'), out[out.len - 1]);
    try std.testing.expect(std.mem.startsWith(u8, out, "I4 xxx"));
}
