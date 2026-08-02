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
// VERIFY-BATTERY — M1 harness (T168)
//
// CLI, artifact loading, result schema, exit-code discipline.
// Stub invariants. R8-compliant.
//
// Author: DSPro/T168-w2 · 2026-07-31

const std = @import("std");
const version = @import("version");
const vb = @import("vb_common.zig");
const vbt = @import("vb_table.zig");
const vbf = @import("vb_fixpoint.zig");
const vbg = @import("vb_graph.zig");

const SCHEMA_VERSION = "1.0.0";
const DEFAULT_SEED: u64 = 31337;

// ═══════════════════════════════════════════════════════════════════════════
// CLI config
// ═══════════════════════════════════════════════════════════════════════════

const CliConfig = struct {
    goban: ?vb.GobanSize = null,
    artifact_path: ?[]const u8 = null,
    arg_artifact_empty: bool = false,
    invariants: ?[]const u8 = null,
    i5_only: bool = false,
    i5_graph: []const u8 = "all-legal",
    output_path: ?[]const u8 = null,
    proposed_rows_path: ?[]const u8 = null,
    reference_path: ?[]const u8 = null,
    sha256: ?[]const u8 = null,
    seed: u64 = DEFAULT_SEED,
    seed_source: vb.SeedSource = .fixed,
    sample_size: ?u64 = null,
    allow_mode_deviation: bool = false,
    show_version: bool = false,
    show_help: bool = false,
};

// ═══════════════════════════════════════════════════════════════════════════
// Output handle
// ═══════════════════════════════════════════════════════════════════════════

const Output = struct {
    fd: std.c.fd_t,

    fn write(self: Output, bytes: []const u8) void {
        _ = std.c.write(self.fd, bytes.ptr, bytes.len);
    }

    fn writeFmt(self: Output, comptime fmt: []const u8, args: anytype) void {
        var buf: [4096]u8 = undefined;
        const s = std.fmt.bufPrint(&buf, fmt, args) catch return;
        self.write(s);
    }

    fn close(self: Output) void {
        if (self.fd != std.c.STDOUT_FILENO) {
            _ = std.c.close(self.fd);
        }
    }
};

fn openOutput(path: ?[]const u8) Output {
    if (path) |p| {
        const fd = std.c.open(@ptrCast(p), std.c.O{ .ACCMODE = .WRONLY, .CREAT = true, .TRUNC = true }, @as(c_int, 0o644));
        if (fd < 0) return Output{ .fd = std.c.STDOUT_FILENO };
        return Output{ .fd = fd };
    }
    return Output{ .fd = std.c.STDOUT_FILENO };
}

// ═══════════════════════════════════════════════════════════════════════════
// RSS High Water Mark
// ═══════════════════════════════════════════════════════════════════════════

/// Returns peak RSS in megabytes, or null if unavailable.
fn rssHwmMb() ?f64 {
    // Linux: parse VmHWM from /proc/self/status (kernel-maintained peak RSS).
    const status_fd = std.c.open("/proc/self/status", std.c.O{ .ACCMODE = .RDONLY });
    if (status_fd >= 0) {
        defer _ = std.c.close(status_fd);
        var buf: [4096]u8 = undefined;
        const n = std.c.read(status_fd, &buf, buf.len);
        if (n > 0) {
            const content = buf[0..@intCast(n)];
            var lines = std.mem.splitScalar(u8, content, '\n');
            while (lines.next()) |line| {
                if (std.mem.startsWith(u8, line, "VmHWM:")) {
                    // Format: "VmHWM:    12345 kB"
                    var parts = std.mem.tokenizeScalar(u8, line, ' ');
                    _ = parts.next(); // "VmHWM:"
                    if (parts.next()) |kb_str| {
                        if (std.fmt.parseUnsigned(u64, kb_str, 10)) |kb| {
                            return @as(f64, @floatFromInt(kb)) / 1024.0;
                        } else |_| {}
                    }
                }
            }
        }
    }

    // macOS/Linux fallback: getrusage(RUSAGE_SELF) — ru_maxrss in KB (Linux) or bytes (macOS).
    // RUSAGE_SELF is 0 on both platforms.
    var ru: std.c.rusage = undefined;
    if (std.c.getrusage(0, &ru) == 0) {
        if (ru.maxrss > 0) {
            // On macOS ru_maxrss is bytes; on Linux it's KB.
            // Detect: if value > 1_000_000, assume bytes (macOS).
            if (ru.maxrss > 1_000_000) {
                return @as(f64, @floatFromInt(ru.maxrss)) / (1024.0 * 1024.0);
            } else {
                return @as(f64, @floatFromInt(ru.maxrss)) / 1024.0;
            }
        }
    }
    return null;
}

// ═══════════════════════════════════════════════════════════════════════════
// Helpers
// ═══════════════════════════════════════════════════════════════════════════

fn note(comptime fmt: []const u8, args: anytype) void {
    std.debug.print(fmt, args);
}

fn readFilePath(allocator: std.mem.Allocator, path: []const u8, max_size: usize) ![]u8 {
    const fd = std.c.open(@ptrCast(path), std.c.O{ .ACCMODE = .RDONLY });
    if (fd < 0) return error.OpenFailed;
    defer _ = std.c.close(fd);
    var stat: std.c.Stat = undefined;
    if (std.c.fstat(fd, &stat) != 0) return error.StatFailed;
    if (stat.size > max_size) return error.FileTooBig;
    const buf = try allocator.alloc(u8, @intCast(stat.size));
    errdefer allocator.free(buf);
    const n = std.c.read(fd, buf.ptr, buf.len);
    if (n < 0) return error.ReadFailed;
    return buf;
}

fn nowMs() i64 {
    var tv: std.c.timeval = undefined;
    _ = std.c.gettimeofday(&tv, null);
    return @as(i64, tv.sec) * 1000 + @divTrunc(@as(i64, tv.usec), 1000);
}

fn sha256Hex(bytes: []const u8, out: []u8) void {
    var hasher = std.crypto.hash.sha2.Sha256.init(.{});
    hasher.update(bytes);
    var digest: [32]u8 = undefined;
    hasher.final(&digest);
    const hx = std.fmt.bytesToHex(&digest, .lower);
    @memcpy(out[0..hx.len], &hx);
}

fn formatTimestamp(now_ms: i64, buf: []u8) ![]const u8 {
    const secs: u64 = @intCast(@divTrunc(now_ms, 1000));
    const es = std.time.epoch.EpochSeconds{ .secs = secs };
    const ed = es.getEpochDay();
    const yd = ed.calculateYearDay();
    const md = yd.calculateMonthDay();
    const ds = es.getDaySeconds();
    return std.fmt.bufPrint(buf, "{d:0>4}-{d:0>2}-{d:0>2}T{d:0>2}:{d:0>2}:{d:0>2}Z", .{
        yd.year,
        md.month.numeric(),
        md.day_index + 1,
        ds.getHoursIntoDay(),
        ds.getMinutesIntoHour(),
        ds.getSecondsIntoMinute(),
    });
}

fn csLabel(s: vb.CheckStatus) []const u8 { return @tagName(s); }
fn ecLabel(ec: vb.ExitClass) []const u8 { return @tagName(ec); }
fn mdLabel(m: vb.ModeDeclared) []const u8 { return @tagName(m); }
fn akLabel(ak: vb.ArtifactKind) []const u8 { return @tagName(ak); }
fn afLabel(af: vb.ArtifactFormat) []const u8 { return @tagName(af); }
fn ssLabel(ss: vb.SeedSource) []const u8 { return @tagName(ss); }

fn escapeJsonToBuf(s: []const u8, buf: []u8) []const u8 {
    // Proper JSON string escaping per RFC 8259 §7.
    // Returns a slice of buf (stack-allocated; caller must use immediately).
    var wi: usize = 0;
    for (s) |c| {
        switch (c) {
            '"' => { if (wi + 2 > buf.len) break; buf[wi] = '\\'; buf[wi + 1] = '\"'; wi += 2; },
            '\\' => { if (wi + 2 > buf.len) break; buf[wi] = '\\'; buf[wi + 1] = '\\'; wi += 2; },
            0x08 => { if (wi + 2 > buf.len) break; buf[wi] = '\\'; buf[wi + 1] = 'b'; wi += 2; },
            0x0C => { if (wi + 2 > buf.len) break; buf[wi] = '\\'; buf[wi + 1] = 'f'; wi += 2; },
            '\n' => { if (wi + 2 > buf.len) break; buf[wi] = '\\'; buf[wi + 1] = 'n'; wi += 2; },
            '\r' => { if (wi + 2 > buf.len) break; buf[wi] = '\\'; buf[wi + 1] = 'r'; wi += 2; },
            '\t' => { if (wi + 2 > buf.len) break; buf[wi] = '\\'; buf[wi + 1] = 't'; wi += 2; },
            0x00...0x07, 0x0B, 0x0E...0x1F => {
                if (wi + 6 > buf.len) break;
                buf[wi] = '\\'; buf[wi + 1] = 'u'; buf[wi + 2] = '0'; buf[wi + 3] = '0';
                const hi = (c >> 4) & 0xF;
                const lo = c & 0xF;
                buf[wi + 4] = if (hi < 10) '0' + hi else 'a' + (hi - 10);
                buf[wi + 5] = if (lo < 10) '0' + lo else 'a' + (lo - 10);
                wi += 6;
            },
            else => { if (wi + 1 > buf.len) break; buf[wi] = c; wi += 1; },
        }
    }
    return buf[0..wi];
}

// ═══════════════════════════════════════════════════════════════════════════
// JSON output (manual, avoids Zig 0.16 json API churn)
// ═══════════════════════════════════════════════════════════════════════════

fn writeHeader(out: Output, _: *const CliConfig, gs: ?vb.GobanSize, art_path: ?[]const u8, art_sha: ?[]const u8, art_total: ?u64, art_legal: ?u64, art_rules_id: ?u8, art_rules_name: ?[]const u8, ref_path: ?[]const u8, ref_sha: ?[]const u8, ts: []const u8, args: []const []const u8, seed: u64, ss: []const u8, inv_labels: []const []const u8, i5g: ?[]const u8) void {

    var buf: [4096]u8 = undefined;
    out.write("{\"kind\":\"header\"");
    out.writeFmt(",\"battery_version\":\"{s}\"", .{version.banner("verify-battery")});
    out.writeFmt(",\"schema_version\":\"{s}\"", .{SCHEMA_VERSION});
    writeOptStr(out, "artifact_kind", if (art_path != null and art_sha != null) "pinned-v" else null);
    writeOptStr(out, "format", if (art_path != null and art_sha != null) "WZO1" else null);
    writeOptNum(out, "format_version", if (art_path != null and art_sha != null) @as(?u8, 1) else null);
    writeOptStr(out, "goban", if (gs) |g| std.fmt.bufPrint(&buf, "{d}x{d}", .{ g.w, g.h }) catch null else null);
    writeOptStr(out, "artifact", art_path);
    writeOptStr(out, "artifact_sha256", art_sha);
    writeOptNum(out, "artifact_total", art_total);
    writeOptNum(out, "artifact_legal_count", art_legal);
    writeOptNum(out, "artifact_rules_id", art_rules_id);
    writeOptStr(out, "artifact_rules_name", art_rules_name);
    writeOptStr(out, "reference_path", ref_path);
    writeOptStr(out, "reference_sha256", ref_sha);
    writeStr(out, "timestamp", ts);
    writeStrArray(out, "argv", args);
    writeNum(out, "seed", seed);
    writeStr(out, "seed_source", ss);
    writeStrArray(out, "invariants_requested", inv_labels);
    writeOptStr(out, "i5_graph", i5g);
    out.write("}\n");
}

fn writeResult(out: Output, inv: []const u8, gs: []const u8, ak: ?[]const u8, af: ?[]const u8, afv: ?u8, art: ?[]const u8, art_sha: ?[]const u8, md_decl: []const u8, md_act: []const u8, scope: bool, status: []const u8, ec: []const u8, dur: u64, _: ?f64, seed: ?u64, ss: ?u64, sden: ?u64, ek: ?[]const u8, em: ?[]const u8) void {
    const rss_mb = rssHwmMb();
    out.write("{\"kind\":\"result\"");
    writeStr(out, "invariant", inv);
    writeStr(out, "goban", gs);
    writeOptStr(out, "artifact_kind", ak);
    writeOptStr(out, "format", af);
    writeOptNum(out, "format_version", afv);
    writeOptStr(out, "artifact", art);
    writeOptStr(out, "artifact_sha256", art_sha);
    writeStr(out, "mode_declared", md_decl);
    writeStr(out, "mode_actual", md_act);
    writeBool(out, "scope_once_per_goban", scope);
    writeStr(out, "status", status);
    writeStr(out, "exit_class", ec);
    writeNum(out, "duration_ms", dur);
    writeOptFloat(out, "rss_hwm_after_mb", rss_mb);
    writeOptNum(out, "seed", seed);
    writeOptNum(out, "sample_size", ss);
    writeOptNum(out, "sample_denominator", sden);
    out.write(",\"value\":null");
    out.write(",\"deviation\":null");
    if (ek != null and em != null) {
        out.writeFmt(",\"error\":{{\"kind\":{s},\"message\":{s}}}", .{ ek.?, em.? });
    } else {
        out.write(",\"error\":null");
    }
    out.write("}\n");
}

fn writeTrailer(out: Output, exit_code: u8, dur: u64, _: ?f64, pass: u32, fail: u32, rd: u32, skip: u32, na: u32, err: u32, ec_pass: u32, ec_ab: u32, ec_rb: u32, ec_bb: u32) void {
    const rss_mb = rssHwmMb();
    out.writeFmt("{{\"kind\":\"trailer\",\"exit_code\":{d},\"total_duration_ms\":{d}", .{ exit_code, dur });
    writeOptFloat(out, "rss_hwm_after_mb", rss_mb);
    out.writeFmt(",\"result_counts\":{{\"pass\":{d},\"fail\":{d},\"reference_disagreement\":{d},\"skipped\":{d},\"not_applicable\":{d},\"error\":{d}}}", .{ pass, fail, rd, skip, na, err });
    out.writeFmt(",\"exit_class_counts\":{{\"pass\":{d},\"artifact_bad\":{d},\"reference_bad\":{d},\"battery_bad\":{d}}}", .{ ec_pass, ec_ab, ec_rb, ec_bb });
    out.write("}\n");
}

fn emitError(out: Output, cfg: *const CliConfig, gs: ?vb.GobanSize, art_path: ?[]const u8, art_sha: ?[]const u8, art_total: ?u64, art_legal: ?u64, ts: []const u8, start_ms: i64, ek: []const u8, em: []const u8) void {
    var empty: [0][]const u8 = undefined;
    writeHeader(out, cfg, gs, art_path, art_sha, art_total, art_legal, null, null, cfg.reference_path, null, ts, &empty, cfg.seed, ssLabel(cfg.seed_source), &empty, null);
    var buf: [8]u8 = undefined;
    const gs_str = if (gs) |g| std.fmt.bufPrint(&buf, "{d}x{d}", .{ g.w, g.h }) catch "??" else "unknown";
    writeResult(out, "ALL", gs_str, null, null, null, art_path, art_sha, "not-applicable", "not-applicable", false, "error", "battery-bad", @intCast(nowMs() - start_ms), null, null, null, null, ek, em);
    writeTrailer(out, 3, @intCast(nowMs() - start_ms), null, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1);
}

// ═══════════════════════════════════════════════════════════════════════════
// JSON field helpers
// ═══════════════════════════════════════════════════════════════════════════

fn writeStr(out: Output, key: []const u8, val: []const u8) void {
    var ebuf: [4096]u8 = undefined;
    const escaped = escapeJsonToBuf(val, &ebuf);
    out.writeFmt(",\"{s}\":\"{s}\"", .{ key, escaped });
}

fn writeOptStr(out: Output, key: []const u8, val: ?[]const u8) void {
    if (val) |v| {
        var ebuf: [4096]u8 = undefined;
        const escaped = escapeJsonToBuf(v, &ebuf);
        out.writeFmt(",\"{s}\":\"{s}\"", .{ key, escaped });
    } else {
        out.writeFmt(",\"{s}\":null", .{key});
    }
}

fn writeNum(out: Output, key: []const u8, val: anytype) void {
    out.writeFmt(",\"{s}\":{d}", .{ key, val });
}

fn writeOptNum(out: Output, key: []const u8, val: anytype) void {
    if (@TypeOf(val) == ?u64) {
        if (val) |v| {
            out.writeFmt(",\"{s}\":{d}", .{ key, v });
        } else {
            out.writeFmt(",\"{s}\":null", .{key});
        }
    } else if (@TypeOf(val) == ?u8) {
        if (val) |v| {
            out.writeFmt(",\"{s}\":{d}", .{ key, v });
        } else {
            out.writeFmt(",\"{s}\":null", .{key});
        }
    }
}

fn writeOptFloat(out: Output, key: []const u8, val: ?f64) void {
    if (val) |v| {
        out.writeFmt(",\"{s}\":{d}", .{ key, v });
    } else {
        out.writeFmt(",\"{s}\":null", .{key});
    }
}

fn writeBool(out: Output, key: []const u8, val: bool) void {
    out.writeFmt(",\"{s}\":{s}", .{ key, if (val) "true" else "false" });
}

fn writeStrArray(out: Output, key: []const u8, vals: []const []const u8) void {
    out.writeFmt(",\"{s}\":[", .{key});
    for (vals, 0..) |v, idx| {
        if (idx > 0) out.write(",");
        var ebuf: [4096]u8 = undefined;
        const escaped = escapeJsonToBuf(v, &ebuf);
        out.writeFmt("\"{s}\"", .{escaped});
    }
    out.write("]");
}

// ═══════════════════════════════════════════════════════════════════════════
// CLI parsing
// ═══════════════════════════════════════════════════════════════════════════

const HELP =
    \\usage: verify-battery <goban> <artifact> [flags]
    \\
    \\exit codes: 0=pass, 1=artifact-bad, 2=reference-bad, 3=battery-bad
    \\
;

fn parseCli(args: []const []const u8) !CliConfig {
    var cfg = CliConfig{};
    var pos: u8 = 0;
    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const a = args[i];
        if (std.mem.eql(u8, a, "--help")) { cfg.show_help = true; }
        else if (std.mem.eql(u8, a, "--version")) { cfg.show_version = true; }
        else if (std.mem.eql(u8, a, "--i5-only")) { cfg.i5_only = true; }
        else if (std.mem.eql(u8, a, "--allow-mode-deviation")) { cfg.allow_mode_deviation = true; }
        else if (std.mem.eql(u8, a, "--invariants")) { i += 1; cfg.invariants = args[i]; }
        else if (std.mem.eql(u8, a, "--i5-graph")) { i += 1; cfg.i5_graph = args[i]; }
        else if (std.mem.eql(u8, a, "--output")) { i += 1; cfg.output_path = args[i]; }
        else if (std.mem.eql(u8, a, "--proposed-rows")) { i += 1; cfg.proposed_rows_path = args[i]; }
        else if (std.mem.eql(u8, a, "--reference")) { i += 1; cfg.reference_path = args[i]; }
        else if (std.mem.eql(u8, a, "--sha256")) { i += 1; cfg.sha256 = args[i]; }
        else if (std.mem.eql(u8, a, "--seed")) {
            i += 1;
            if (std.mem.eql(u8, args[i], "auto")) {
                cfg.seed_source = .auto;
                cfg.seed = @as(u64, @intCast(std.c.getpid())) ^ @as(u64, @intCast(nowMs()));
            } else { cfg.seed = try std.fmt.parseUnsigned(u64, args[i], 10); }
        } else if (std.mem.eql(u8, a, "--sample-size")) { i += 1; cfg.sample_size = try std.fmt.parseUnsigned(u64, args[i], 10); }
        else if (!std.mem.startsWith(u8, a, "-")) {
            if (pos == 0) { cfg.goban = vb.GobanSize.parse(a) orelse { note("error: bad goban '{s}'\n", .{a}); return error.InvalidArgs; }; pos += 1; }
            else if (pos == 1) { cfg.artifact_path = if (a.len > 0) a else null; cfg.arg_artifact_empty = (a.len == 0); pos += 1; }
            else { note("error: unexpected arg '{s}'\n", .{a}); return error.InvalidArgs; }
        } else { note("error: unknown flag '{s}'\n", .{a}); return error.InvalidArgs; }
    }
    if (cfg.i5_only and cfg.invariants != null) { note("error: --i5-only and --invariants are mutually exclusive\n", .{}); return error.InvalidArgs; }
    return cfg;
}

// ═══════════════════════════════════════════════════════════════════════════
// Invariant resolution
// ═══════════════════════════════════════════════════════════════════════════

fn resolveInvariants(cfg: *const CliConfig, allocator: std.mem.Allocator) ![]const vb.Invariant {
    var list: std.ArrayList(vb.Invariant) = .empty;
    if (cfg.i5_only) {
        try list.append(allocator, .I5);
    } else if (cfg.invariants) |is| {
        var parts = std.mem.splitScalar(u8, is, ',');
        while (parts.next()) |p| {
            if (vb.Invariant.parse(std.mem.trim(u8, p, " \t"))) |inv| try list.append(allocator, inv);
        }
    } else {
        inline for (@typeInfo(vb.Invariant).@"enum".fields) |f| try list.append(allocator, @enumFromInt(f.value));
    }
    return list.toOwnedSlice(allocator);
}

// ═══════════════════════════════════════════════════════════════════════════
// Real invariant dispatch
// ═══════════════════════════════════════════════════════════════════════════

/// Holds all loaded representations of an artifact for dispatch.
const RunCtx = struct {
    gs: vb.GobanSize,
    ak: ?vb.ArtifactKind,
    art_hdr: ?[]const u8,
    art_sha256: ?[]const u8,
    /// vb_common decoder (used by harness + vb_fixpoint checks)
    dec: ?*const vb.WZO1Decoded = null,
    /// vb_table artifact (owns its own copies)
    vbt_art: ?*const vbt.VBArtifact = null,
    /// vb_graph artifact (owns its own copies, I5 only)
    vbg_art: ?*const vbg.VBArtifact = null,
    /// allocator (for I5 which needs heap)
    gpa: std.mem.Allocator,
    /// I5 graph mode
    i5_graph: []const u8 = "all-legal",
};

fn runCheck(ctx: *const RunCtx, inv: vb.Invariant) vb.CheckResult {
    const gs = ctx.gs;
    const ak = ctx.ak;
    const mode_declared = vb.modeForCell(inv, gs);
    const scope_once = inv == .I5;

    // Not-applicable on WZO1: I3, I10
    if (ak != null and ak.? == .@"pinned-v" and vb.notApplicableOnWZO1(inv)) {
        return vb.CheckResult{
            .invariant = inv, .goban = gs, .artifact_kind = ak,
            .format = .WZO1, .format_version = 1,
            .artifact = ctx.art_hdr, .artifact_sha256 = ctx.art_sha256,
            .mode_declared = mode_declared, .mode_actual = .@"not-applicable",
            .scope_once_per_goban = scope_once,
            .status = .@"not-applicable", .exit_class = .pass,
            .duration_ms = 0, .rss_hwm_after_mb = null,
            .seed = null, .sample_size = null, .sample_denominator = null,
            .value = null, .deviation = null, .@"error" = null,
        };
    }

    // I8 is 2×2 only
    if (inv == .I8 and !(gs.w == 2 and gs.h == 2)) {
        return vb.CheckResult{
            .invariant = inv, .goban = gs, .artifact_kind = ak,
            .format = .WZO1, .format_version = 1,
            .artifact = ctx.art_hdr, .artifact_sha256 = ctx.art_sha256,
            .mode_declared = mode_declared, .mode_actual = .@"not-applicable",
            .scope_once_per_goban = scope_once,
            .status = .@"not-applicable", .exit_class = .pass,
            .duration_ms = 0, .rss_hwm_after_mb = null,
            .seed = null, .sample_size = null, .sample_denominator = null,
            .value = null, .deviation = null, .@"error" = null,
        };
    }

    // I5: graph invariant (once per goban, uses vbg artifact)
    if (inv == .I5) return runI5(ctx);

    // I4, I7, I9, I11: fixpoint invariants — use vb_common decoder + vbf
    if (inv == .I4 or inv == .I7 or inv == .I9 or inv == .I11) return runFixpoint(ctx, inv);

    // I8 at 2×2: fixpoint
    if (inv == .I8) return runFixpoint(ctx, inv);

    // I1, I2, I3, I6, I10, I12: table invariants — use vb_table artifact
    return runTable(ctx, inv);
}

fn runTable(ctx: *const RunCtx, inv: vb.Invariant) vb.CheckResult {
    const art = ctx.vbt_art orelse return errResult(inv, ctx.gs, ctx.ak, ctx.art_hdr, ctx.art_sha256, "vbt_artifact_not_loaded");
    switch (inv) {
        .I1 => return mapI1(vbt.checkI1(art), ctx),
        .I2 => return mapI2(vbt.checkI2(art), ctx),
        .I3 => return mapI3(vbt.checkI3(), ctx),
        .I6 => return mapI6(vbt.checkI6(art), ctx),
        .I10 => return mapI10(vbt.checkI10(), ctx),
        .I12 => return mapI12(vbt.checkI12(art), ctx),
        else => unreachable,
    }
}

fn runFixpoint(ctx: *const RunCtx, inv: vb.Invariant) vb.CheckResult {
    const dec = ctx.dec orelse return errResult(inv, ctx.gs, ctx.ak, ctx.art_hdr, ctx.art_sha256, "dec_not_loaded");
    switch (inv) {
        .I4 => return mapI4(vbf.checkI4(dec, ctx.gs), ctx),
        .I7 => return mapI7(vbf.checkI7(dec, ctx.gs), ctx),
        .I8 => return mapI8(vbf.checkI8(), ctx),
        .I9 => return mapI9(vbf.checkI9(dec, ctx.gs), ctx),
        .I11 => return mapI11(vbf.checkI11(), ctx),
        else => unreachable,
    }
}

fn runI5(ctx: *const RunCtx) vb.CheckResult {
    const graph_kind: vbg.I5Graph = if (std.mem.eql(u8, ctx.i5_graph, "reachable")) .reachable else .all_legal;
    const vbg_gs = vbg.GobanSize{ .w = ctx.gs.w, .h = ctx.gs.h };
    const result = vbg.checkI5(ctx.gpa, vbg_gs, ctx.vbg_art, .{ .graph = graph_kind }) catch |e| {
        return vb.CheckResult{
            .invariant = .I5, .goban = ctx.gs, .artifact_kind = ctx.ak,
            .format = if (ctx.ak != null) .WZO1 else null, .format_version = if (ctx.ak != null) @as(u8, 1) else null,
            .artifact = ctx.art_hdr, .artifact_sha256 = ctx.art_sha256,
            .mode_declared = .exhaustive, .mode_actual = .exhaustive,
            .scope_once_per_goban = true,
            .status = .@"error", .exit_class = .@"battery-bad",
            .duration_ms = 0, .rss_hwm_after_mb = null,
            .seed = null, .sample_size = null, .sample_denominator = null,
            .value = null, .deviation = null,
            .@"error" = vb.ErrorInfo{ .kind = .internal, .message = @errorName(e) },
        };
    };
    return mapI5(result, ctx);
}

// ═══════════════════════════════════════════════════════════════════════════
// Result mappers: module-specific types → vb.CheckResult
// ═══════════════════════════════════════════════════════════════════════════

fn baseResult(inv: vb.Invariant, ctx: *const RunCtx) vb.CheckResult {
    return vb.CheckResult{
        .invariant = inv, .goban = ctx.gs, .artifact_kind = ctx.ak,
        .format = if (ctx.ak != null) .WZO1 else null,
        .format_version = if (ctx.ak != null) @as(u8, 1) else null,
        .artifact = ctx.art_hdr, .artifact_sha256 = ctx.art_sha256,
        .mode_declared = vb.modeForCell(inv, ctx.gs),
        .mode_actual = vb.modeForCell(inv, ctx.gs),
        .scope_once_per_goban = inv == .I5,
        .status = undefined, .exit_class = undefined,
        .duration_ms = 0, .rss_hwm_after_mb = null,
        .seed = null, .sample_size = null, .sample_denominator = null,
        .value = null, .deviation = null, .@"error" = null,
    };
}

fn toStatus(s: vbt.InvariantStatus) vb.CheckStatus {
    return switch (s) { .pass => .pass, .fail => .fail, .not_applicable => .@"not-applicable", .err => .@"error" };
}
fn toExit(s: vb.CheckStatus) vb.ExitClass {
    return switch (s) { .pass, .@"not-applicable", .skipped => .pass, .fail => .@"artifact-bad", .@"reference-disagreement" => .@"reference-bad", .@"error" => .@"battery-bad" };
}
fn toFixStatus(s: vbf.FixpointStatus) vb.CheckStatus {
    return switch (s) { .pass => .pass, .fail => .fail, .not_applicable => .@"not-applicable", .err => .@"error" };
}
fn toI5Status(s: vbg.I5Status) vb.CheckStatus {
    return switch (s) { .pass => .pass, .fail => .fail, .err => .@"error" };
}

fn errResult(inv: vb.Invariant, gs: vb.GobanSize, ak: ?vb.ArtifactKind, art: ?[]const u8, art_sha: ?[]const u8, msg: []const u8) vb.CheckResult {
    return vb.CheckResult{
        .invariant = inv, .goban = gs, .artifact_kind = ak,
        .format = if (ak != null) .WZO1 else null, .format_version = if (ak != null) @as(u8, 1) else null,
        .artifact = art, .artifact_sha256 = art_sha,
        .mode_declared = vb.modeForCell(inv, gs),
        .mode_actual = .exhaustive, .scope_once_per_goban = inv == .I5,
        .status = .@"error", .exit_class = .@"battery-bad",
        .duration_ms = 0, .rss_hwm_after_mb = null,
        .seed = null, .sample_size = null, .sample_denominator = null,
        .value = null, .deviation = null,
        .@"error" = vb.ErrorInfo{ .kind = .internal, .message = msg },
    };
}

fn mapI1(r: vbt.I1Result, ctx: *const RunCtx) vb.CheckResult {
    var b = baseResult(.I1, ctx); b.status = toStatus(r.status); b.exit_class = toExit(b.status);
    b.value = .{ .numerator = r.L_eq_H, .denominator = r.denominator };
    return b;
}
fn mapI2(r: vbt.I2Result, ctx: *const RunCtx) vb.CheckResult {
    var b = baseResult(.I2, ctx); b.status = toStatus(r.status); b.exit_class = toExit(b.status);
    b.value = .{ .numerator = r.violations, .denominator = r.denominator };
    return b;
}
fn mapI3(r: vbt.I3Result, ctx: *const RunCtx) vb.CheckResult {
    var b = baseResult(.I3, ctx); b.status = toStatus(r.status); b.exit_class = toExit(b.status);
    return b;
}
fn mapI6(r: vbt.I6Result, ctx: *const RunCtx) vb.CheckResult {
    var b = baseResult(.I6, ctx); b.status = toStatus(r.status); b.exit_class = toExit(b.status);
    b.value = .{ .numerator = r.legal_positions_total, .denominator = r.denominator };
    return b;
}
fn mapI10(r: vbt.I10Result, ctx: *const RunCtx) vb.CheckResult {
    var b = baseResult(.I10, ctx); b.status = toStatus(r.status); b.exit_class = toExit(b.status);
    return b;
}
fn mapI12(r: vbt.I12Result, ctx: *const RunCtx) vb.CheckResult {
    var b = baseResult(.I12, ctx); b.status = toStatus(r.status); b.exit_class = toExit(b.status);
    b.value = .{ .numerator = r.violations, .denominator = r.denominator };
    return b;
}
fn mapI4(r: vbf.I4Result, ctx: *const RunCtx) vb.CheckResult {
    var b = baseResult(.I4, ctx); b.status = toFixStatus(r.status); b.exit_class = toExit(b.status);
    b.value = .{ .numerator = r.numerator, .denominator = r.denominator };
    return b;
}
fn mapI7(r: vbf.I7Result, ctx: *const RunCtx) vb.CheckResult {
    var b = baseResult(.I7, ctx); b.status = toFixStatus(r.status); b.exit_class = toExit(b.status);
    b.value = .{ .numerator = r.terminals_with_dtt_neq_0, .denominator = r.denominator };
    return b;
}
fn mapI8(r: vbf.I8Result, ctx: *const RunCtx) vb.CheckResult {
    var b = baseResult(.I8, ctx); b.status = toFixStatus(r.status); b.exit_class = toExit(b.status);
    return b;
}
fn mapI9(r: vbf.I9Result, ctx: *const RunCtx) vb.CheckResult {
    var b = baseResult(.I9, ctx); b.status = toFixStatus(r.status); b.exit_class = toExit(b.status);
    b.value = .{ .numerator = r.numerator, .denominator = r.denominator };
    if (r.note) |n| b.deviation = n;
    return b;
}
fn mapI11(r: vbf.I11Result, ctx: *const RunCtx) vb.CheckResult {
    var b = baseResult(.I11, ctx); b.status = toFixStatus(r.status); b.exit_class = toExit(b.status);
    return b;
}
fn mapI5(r: vbg.I5Result, ctx: *const RunCtx) vb.CheckResult {
    var b = baseResult(.I5, ctx); b.status = toI5Status(r.status); b.exit_class = toExit(b.status);
    b.value = .{ .numerator = r.ko_sensitive_not_cycle_reachable, .denominator = r.ko_sensitive_flags };
    return b;
}

// ═══════════════════════════════════════════════════════════════════════════
// Exit code
// ═══════════════════════════════════════════════════════════════════════════

fn computeExitCode(results: []const vb.CheckResult) u8 {
    var hb = false; var ha = false; var hr = false;
    for (results) |r| {
        switch (r.exit_class) {
            .@"battery-bad" => hb = true,
            .@"artifact-bad" => ha = true,
            .@"reference-bad" => hr = true,
            .pass => {},
        }
    }
    if (hb) return 3;
    if (ha) return 1;
    if (hr) return 2;
    return 0;
}

// ═══════════════════════════════════════════════════════════════════════════
// MAIN
// ═══════════════════════════════════════════════════════════════════════════

pub fn main(init: std.process.Init) u8 {
    const start_ms = nowMs();
    const allocator = init.gpa;

    // Collect args
    var args_list: std.ArrayList([]const u8) = .empty;
    for (init.minimal.args.vector) |arg_ptr| {
        args_list.append(allocator, std.mem.span(arg_ptr)) catch return 3;
    }
    const args = args_list.items;

    const cfg = parseCli(args) catch { note("Try 'verify-battery --help'.\n", .{}); return 3; };
    if (cfg.show_help) { note("{s}", .{HELP}); return 0; }
    if (cfg.show_version) { note("{s}\n", .{version.banner("verify-battery")}); return 0; }
    if (cfg.goban == null) { note("error: <goban> required\n", .{}); return 3; }
    const gs = cfg.goban.?;
    const need_artifact = !(cfg.i5_only and std.mem.eql(u8, cfg.i5_graph, "all-legal"));
    if (need_artifact and cfg.artifact_path == null and !cfg.arg_artifact_empty) {
        note("error: <artifact> required\n", .{}); return 3;
    }

    var ts_buf: [32]u8 = undefined;
    const timestamp = formatTimestamp(start_ms, &ts_buf) catch "unknown";

    // Artifact
    var artifact_kind: ?vb.ArtifactKind = null;
    var artifact_format: ?vb.ArtifactFormat = null;
    var art_sha_hex: ?[]const u8 = null;
    var art_sha_buf: [64]u8 = undefined;
    var art_total: ?u64 = null;
    var art_legal: ?u64 = null;
    var art_rules_id: ?u8 = null;
    var art_rules_name: ?[]const u8 = null;

    // Output
    const out = openOutput(cfg.output_path);
    defer out.close();

    // Reference
    var ref_sha_hex: ?[]const u8 = null;
    var ref_sha_buf: [64]u8 = undefined;
    if (cfg.reference_path) |rp| {
        const bytes = readFilePath(allocator, rp, 10 * 1024 * 1024) catch |e| {
            note("error: ref file '{s}': {}\n", .{ rp, e });
            emitError(out, &cfg, gs, cfg.artifact_path, null, null, null, timestamp, start_ms, "artifact_load", "Cannot read reference file");
            return 3;
        };
        defer allocator.free(bytes);
        sha256Hex(bytes, &ref_sha_buf);
        ref_sha_hex = &ref_sha_buf;
    }

    // ── Artifact loading ─────────────────────────────────────────
    var art_bytes: ?[]u8 = null;
    var dec_opt: ?vb.WZO1Decoded = null;
    var vbt_art_opt: ?vbt.VBArtifact = null;
    var vbg_art_opt: ?vbg.VBArtifact = null;
    defer {
        if (vbg_art_opt) |*a| a.deinit(allocator);
        if (vbt_art_opt) |*a| a.deinit(allocator);
        if (dec_opt) |*d| d.deinit();
        if (art_bytes) |b| allocator.free(b);
    }

    const art_hdr: ?[]const u8 = cfg.artifact_path;
    if (need_artifact and cfg.artifact_path != null) {
        const ap = cfg.artifact_path.?;
        art_bytes = readFilePath(allocator, ap, 512 * 1024 * 1024) catch |e| {
            note("error: artifact '{s}': {}\n", .{ ap, e });
            emitError(out, &cfg, gs, art_hdr, null, null, null, timestamp, start_ms, "artifact_load", "Cannot read artifact");
            return 3;
        };
        const bytes = art_bytes.?;

        sha256Hex(bytes, &art_sha_buf);
        art_sha_hex = &art_sha_buf;

        if (cfg.sha256) |eh| {
            if (!std.ascii.eqlIgnoreCase(art_sha_hex.?, eh)) {
                note("error: SHA-256 mismatch\n", .{});
                emitError(out, &cfg, gs, art_hdr, art_sha_hex, null, null, timestamp, start_ms, "artifact_load", "SHA-256 mismatch");
                return 3;
            }
        }

        dec_opt = vb.decodeWZO1(allocator, bytes) catch |e| {
            note("error: artifact decode: {}\n", .{e});
            emitError(out, &cfg, gs, art_hdr, art_sha_hex, null, null, timestamp, start_ms, "artifact_load", @errorName(e));
            return 3;
        };
        const dec = &dec_opt.?;

        // Load vb_table artifact from shared bytes
        vbt_art_opt = vbt.loadArtifact(allocator, bytes) catch |e| {
            note("error: vbt artifact load: {}\n", .{e});
            emitError(out, &cfg, gs, art_hdr, art_sha_hex, null, null, timestamp, start_ms, "artifact_load", @errorName(e));
            return 3;
        };

        // Load vb_graph artifact from shared bytes (I5 uses fb/fw only)
        vbg_art_opt = vbg.loadArtifact(allocator, bytes) catch |e| {
            note("error: vbg artifact load: {}\n", .{e});
            emitError(out, &cfg, gs, art_hdr, art_sha_hex, null, null, timestamp, start_ms, "artifact_load", @errorName(e));
            return 3;
        };

        artifact_kind = .@"pinned-v";
        artifact_format = .WZO1;
        art_total = dec.header.total;
        art_legal = dec.header.legal_count;
        art_rules_id = dec.header.rules_id;
        art_rules_name = vb.rulesName(dec.header.rules_id);

        if (dec.header.board_w != gs.w or dec.header.board_h != gs.h) {
            note("warning: goban {d}x{d} vs artifact {d}x{d}\n", .{ gs.w, gs.h, dec.header.board_w, dec.header.board_h });
        }
        note("artifact: {s}  {d}x{d}  total={d}  legal={d}  rules={s}  sha256={s}\n", .{ ap, dec.header.board_w, dec.header.board_h, dec.header.total, dec.header.legal_count, art_rules_name.?, art_sha_hex.? });
    }

    // Invariants
    const invariants = resolveInvariants(&cfg, allocator) catch { note("error: can't resolve invariants\n", .{}); return 3; };
    var inv_labels = std.ArrayList([]const u8).initCapacity(allocator, invariants.len) catch { note("error: oom\n", .{}); return 3; };
    for (invariants) |inv| inv_labels.appendAssumeCapacity(inv.label());

    var i5g: ?[]const u8 = null;
    for (invariants) |inv| { if (inv == .I5) { i5g = cfg.i5_graph; break; } }

    // Header
    writeHeader(out, &cfg, gs, art_hdr, art_sha_hex, art_total, art_legal, art_rules_id, art_rules_name, cfg.reference_path, ref_sha_hex, timestamp, args, cfg.seed, ssLabel(cfg.seed_source), inv_labels.items, i5g);

    // ── Build dispatch context ───────────────────────────────────
    const dec_ptr: ?*const vb.WZO1Decoded = if (dec_opt) |*d| d else null;
    const vbt_ptr: ?*const vbt.VBArtifact = if (vbt_art_opt) |*a| a else null;
    const vbg_ptr: ?*const vbg.VBArtifact = if (vbg_art_opt) |*a| a else null;
    var run_ctx = RunCtx{
        .gs = gs, .ak = artifact_kind,
        .art_hdr = art_hdr, .art_sha256 = art_sha_hex,
        .dec = dec_ptr, .vbt_art = vbt_ptr, .vbg_art = vbg_ptr,
        .gpa = allocator, .i5_graph = i5g orelse "all-legal",
    };

    // Run invariants
    var results = std.ArrayList(vb.CheckResult).initCapacity(allocator, invariants.len) catch { note("error: oom\n", .{}); return 3; };
    var n_pass: u32 = 0; var n_fail: u32 = 0; var n_rd: u32 = 0;
    var n_skip: u32 = 0; var n_na: u32 = 0; var n_err: u32 = 0;
    var ec_p: u32 = 0; var ec_ab: u32 = 0; var ec_rb: u32 = 0; var ec_bb: u32 = 0;

    var gbuf: [8]u8 = undefined;
    const gs_str = std.fmt.bufPrint(&gbuf, "{d}x{d}", .{ gs.w, gs.h }) catch "??";
    const ak_str: ?[]const u8 = if (artifact_kind) |ak| akLabel(ak) else null;
    const af_str: ?[]const u8 = if (artifact_format) |af| afLabel(af) else null;
    const afv: ?u8 = if (artifact_format != null) @as(u8, 1) else null;

    for (invariants) |inv| {
        const inv_start = nowMs();
        var result = runCheck(&run_ctx, inv);
        result.duration_ms = @intCast(nowMs() - inv_start);

        switch (result.status) {
            .pass => n_pass += 1,
            .fail => n_fail += 1,
            .@"reference-disagreement" => n_rd += 1,
            .skipped => n_skip += 1,
            .@"not-applicable" => n_na += 1,
            .@"error" => n_err += 1,
        }
        switch (result.exit_class) {
            .pass => ec_p += 1,
            .@"artifact-bad" => ec_ab += 1,
            .@"reference-bad" => ec_rb += 1,
            .@"battery-bad" => ec_bb += 1,
        }

        writeResult(out, inv.label(), gs_str, ak_str, af_str, afv, result.artifact, result.artifact_sha256, mdLabel(result.mode_declared), mdLabel(result.mode_actual), result.scope_once_per_goban, csLabel(result.status), ecLabel(result.exit_class), result.duration_ms, result.rss_hwm_after_mb, result.seed, result.sample_size, result.sample_denominator, null, null);
        results.appendAssumeCapacity(result);
    }

    const ec = computeExitCode(results.items);
    const dur: u64 = @intCast(nowMs() - start_ms);
    const rss_end = rssHwmMb();
    // Note: rssHwmMb called once here; writeTrailer calls again — duplicate but harmless.
    _ = rss_end;
    writeTrailer(out, ec, dur, null, n_pass, n_fail, n_rd, n_skip, n_na, n_err, ec_p, ec_ab, ec_rb, ec_bb);
    return ec;
}
