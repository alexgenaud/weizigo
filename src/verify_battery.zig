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
// Stub invariants. T169-T171 plug into the dispatch framework.
// R8-compliant: imports only std and vb_common.
//
// Author: DSPro/T168-w2 · 2026-07-31

const std = @import("std");
const vb = @import("vb_common.zig");

const VERSION = "1.0.0";
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
// JSON record types (for serialization)
// ═══════════════════════════════════════════════════════════════════════════

const HeaderRecord = struct {
    kind: []const u8 = "header",
    battery_version: []const u8,
    schema_version: []const u8,
    artifact_kind: ?[]const u8,
    format: ?[]const u8,
    format_version: ?u8,
    goban: ?[]const u8,
    artifact: ?[]const u8,
    artifact_sha256: ?[]const u8,
    artifact_total: ?u64,
    artifact_legal_count: ?u64,
    artifact_rules_id: ?u8,
    artifact_rules_name: ?[]const u8,
    reference_path: ?[]const u8,
    reference_sha256: ?[]const u8,
    timestamp: []const u8,
    argv: []const []const u8,
    seed: u64,
    seed_source: []const u8,
    invariants_requested: []const []const u8,
    i5_graph: ?[]const u8,
};

const ErrorRecord = struct {
    kind: []const u8,
    message: []const u8,
};

const ResultRecord = struct {
    kind: []const u8 = "result",
    invariant: []const u8,
    goban: []const u8,
    artifact_kind: ?[]const u8,
    format: ?[]const u8,
    format_version: ?u8,
    artifact: ?[]const u8,
    artifact_sha256: ?[]const u8,
    mode_declared: []const u8,
    mode_actual: []const u8,
    scope_once_per_goban: bool,
    status: []const u8,
    exit_class: []const u8,
    duration_ms: u64,
    rss_hwm_after_mb: ?f64,
    seed: ?u64,
    sample_size: ?u64,
    sample_denominator: ?u64,
    value: ?std.json.Value,
    deviation: ?[]const u8,
    @"error": ?ErrorRecord,
};

const TrailerCounts = struct {
    pass: u32 = 0,
    fail: u32 = 0,
    @"reference_disagreement": u32 = 0,
    skipped: u32 = 0,
    @"not_applicable": u32 = 0,
    @"error": u32 = 0,
};

const ExitClassCounts = struct {
    pass: u32 = 0,
    @"artifact_bad": u32 = 0,
    @"reference_bad": u32 = 0,
    @"battery_bad": u32 = 0,
};

const TrailerRecord = struct {
    kind: []const u8 = "trailer",
    exit_code: u8,
    total_duration_ms: u64,
    rss_hwm_after_mb: ?f64,
    result_counts: TrailerCounts,
    exit_class_counts: ExitClassCounts,
};

// ═══════════════════════════════════════════════════════════════════════════
// stdout / stderr discipline
// ═══════════════════════════════════════════════════════════════════════════

fn note(comptime fmt: []const u8, args: anytype) void {
    std.debug.print(fmt, args);
}

fn stderrWriter() std.fs.File.Writer {
    return std.io.getStdErr().writer();
}

// ═══════════════════════════════════════════════════════════════════════════
// Help text
// ═══════════════════════════════════════════════════════════════════════════

const HELP =
    \\usage: verify-battery <goban> <artifact> [flags]
    \\
    \\arguments:
    \\  <goban>       Goban size: 2x2, 3x2, 3x3, 4x3, 4x4
    \\  <artifact>    Path to .wzo artifact file (or "" for --i5-only all-legal)
    \\
    \\flags:
    \\  --invariants <ids>     Comma-separated invariant IDs
    \\  --i5-only              Run I5 alone
    \\  --i5-graph <kind>      all-legal (default) or reachable
    \\  --output <path>        Write JSON to file (default: stdout)
    \\  --proposed-rows <path> Emit proposed CLAIMS.md rows
    \\  --reference <path>     Load committed register figures
    \\  --sha256 <hash>        Verify artifact SHA-256
    \\  --seed <N|auto>        Seed (default: 31337)
    \\  --sample-size <N>      Override sample size
    \\  --allow-mode-deviation Permit mode downgrade
    \\  --version              Print version and exit
    \\  --help                 Print this help and exit
    \\
    \\exit codes: 0=pass, 1=artifact-bad, 2=reference-bad, 3=battery-bad
    \\
;

// ═══════════════════════════════════════════════════════════════════════════
// CLI parsing
// ═══════════════════════════════════════════════════════════════════════════

fn parseCli(args: []const []const u8) !CliConfig {
    var cfg = CliConfig{};
    var pos_args: u8 = 0;
    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "--help")) {
            cfg.show_help = true;
        } else if (std.mem.eql(u8, arg, "--version")) {
            cfg.show_version = true;
        } else if (std.mem.eql(u8, arg, "--i5-only")) {
            cfg.i5_only = true;
        } else if (std.mem.eql(u8, arg, "--allow-mode-deviation")) {
            cfg.allow_mode_deviation = true;
        } else if (std.mem.startsWith(u8, arg, "--")) {
            if (i + 1 >= args.len) {
                note("error: flag '{s}' requires a value\n", .{arg});
                return error.InvalidArgs;
            }
            if (std.mem.eql(u8, arg, "--invariants")) {
                i += 1; cfg.invariants = args[i];
            } else if (std.mem.eql(u8, arg, "--i5-graph")) {
                i += 1; cfg.i5_graph = args[i];
            } else if (std.mem.eql(u8, arg, "--output")) {
                i += 1; cfg.output_path = args[i];
            } else if (std.mem.eql(u8, arg, "--proposed-rows")) {
                i += 1; cfg.proposed_rows_path = args[i];
            } else if (std.mem.eql(u8, arg, "--reference")) {
                i += 1; cfg.reference_path = args[i];
            } else if (std.mem.eql(u8, arg, "--sha256")) {
                i += 1; cfg.sha256 = args[i];
            } else if (std.mem.eql(u8, arg, "--seed")) {
                i += 1;
                if (std.mem.eql(u8, args[i], "auto")) {
                    cfg.seed_source = .auto;
                    const pid: u64 = @intCast(std.os.linux.getpid());
                    const now_ms: u64 = @intCast(nowMs());
                    cfg.seed = pid ^ now_ms;
                } else {
                    cfg.seed = try std.fmt.parseUnsigned(u64, args[i], 10);
                }
            } else if (std.mem.eql(u8, arg, "--sample-size")) {
                i += 1;
                cfg.sample_size = try std.fmt.parseUnsigned(u64, args[i], 10);
            } else {
                note("error: unknown flag '{s}'\n", .{arg});
                return error.InvalidArgs;
            }
        } else {
            if (pos_args == 0) {
                cfg.goban = vb.GobanSize.parse(arg);
                if (cfg.goban == null) {
                    note("error: invalid goban size '{s}'\n", .{arg});
                    return error.InvalidArgs;
                }
                pos_args += 1;
            } else if (pos_args == 1) {
                if (arg.len == 0) {
                    cfg.arg_artifact_empty = true;
                } else {
                    cfg.artifact_path = arg;
                }
                pos_args += 1;
            } else {
                note("error: unexpected argument '{s}'\n", .{arg});
                return error.InvalidArgs;
            }
        }
    }
    if (cfg.i5_only and cfg.invariants != null) {
        note("error: --i5-only and --invariants are mutually exclusive\n", .{});
        return error.InvalidArgs;
    }
    return cfg;
}

// ═══════════════════════════════════════════════════════════════════════════
// Invariant resolution
// ═══════════════════════════════════════════════════════════════════════════

fn resolveInvariants(allocator: std.mem.Allocator, cfg: *const CliConfig) ![]const vb.Invariant {
    var list: std.ArrayList(vb.Invariant) = .empty;
    if (cfg.i5_only) {
        try list.append(allocator, .I5);
    } else if (cfg.invariants) |inv_str| {
        var parts = std.mem.splitScalar(u8, inv_str, ',');
        while (parts.next()) |part| {
            const trimmed = std.mem.trim(u8, part, " \t");
            if (vb.Invariant.parse(trimmed)) |inv| {
                try list.append(allocator, inv);
            } else {
                note("warning: unknown invariant '{s}', skipping\n", .{trimmed});
            }
        }
    } else {
        inline for (@typeInfo(vb.Invariant).@"enum".fields) |f| {
            try list.append(allocator, @enumFromInt(f.value));
        }
    }
    return list.toOwnedSlice(allocator);
}

// ═══════════════════════════════════════════════════════════════════════════
// SHA-256
// ═══════════════════════════════════════════════════════════════════════════

fn sha256Hex(bytes: []const u8, out: []u8) void {
    var hasher = std.crypto.hash.sha2.Sha256.init(.{});
    hasher.update(bytes);
    var digest: [32]u8 = undefined;
    hasher.final(&digest);
    _ = std.fmt.bufPrint(out, "{s}", .{std.fmt.fmtSliceHexLower(&digest)}) catch unreachable;
}

// ═══════════════════════════════════════════════════════════════════════════
// Timestamp
// ═══════════════════════════════════════════════════════════════════════════

fn nowMs() i64 {
    var tv: std.c.timeval = undefined;
    _ = std.c.gettimeofday(&tv, null);
    return @as(i64, tv.sec) * 1000 + @divTrunc(@as(i64, tv.usec), 1000);
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

// ═══════════════════════════════════════════════════════════════════════════
// Label helpers
// ═══════════════════════════════════════════════════════════════════════════

fn csLabel(s: vb.CheckStatus) []const u8 { return @tagName(s); }
fn ecLabel(ec: vb.ExitClass) []const u8 { return @tagName(ec); }
fn mdLabel(m: vb.ModeDeclared) []const u8 { return @tagName(m); }
fn akLabel(ak: vb.ArtifactKind) []const u8 { return @tagName(ak); }
fn afLabel(af: vb.ArtifactFormat) []const u8 { return @tagName(af); }
fn ssLabel(ss: vb.SeedSource) []const u8 { return @tagName(ss); }

// ═══════════════════════════════════════════════════════════════════════════
// Stub invariant check
// ═══════════════════════════════════════════════════════════════════════════

fn stubCheck(inv: vb.Invariant, gs: vb.GobanSize, artifact_kind: ?vb.ArtifactKind, artifact_fmt: ?vb.ArtifactFormat) vb.CheckResult {
    var mode = vb.modeForCell(inv, gs);
    if (artifact_kind != null and artifact_kind.? == .@"pinned-v" and vb.notApplicableOnWZO1(inv)) {
        mode = .@"not-applicable";
    }
    const status: vb.CheckStatus = if (mode == .@"not-applicable") .@"not-applicable" else .skipped;
    return vb.CheckResult{
        .invariant = inv,
        .goban = gs,
        .artifact_kind = artifact_kind,
        .format = artifact_fmt,
        .format_version = if (artifact_fmt != null) @as(u8, 1) else null,
        .artifact = null, .artifact_sha256 = null,
        .mode_declared = vb.modeForCell(inv, gs),
        .mode_actual = mode,
        .scope_once_per_goban = (inv == .I5),
        .status = status,
        .exit_class = if (status == .@"error") .@"battery-bad" else .pass,
        .duration_ms = 0,
        .rss_hwm_after_mb = null,
        .seed = null, .sample_size = null, .sample_denominator = null,
        .value = null, .deviation = null, .@"error" = null,
    };
}

// ═══════════════════════════════════════════════════════════════════════════
// Exit code computation (precedence: battery-bad > artifact-bad > ref-bad > pass)
// ═══════════════════════════════════════════════════════════════════════════

fn computeExitCode(results: []const vb.CheckResult) u8 {
    var hb: bool = false; var ha: bool = false; var hr: bool = false;
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
// emitJsonRecord — writes one JSON line to a writer
// ═══════════════════════════════════════════════════════════════════════════

fn emitJson(writer: anytype, value: anytype) void {
    std.json.stringify(value, .{}, writer) catch return;
    writer.writeByte('\n') catch return;
}

// ═══════════════════════════════════════════════════════════════════════════
// emitError — minimal header + error result + trailer, exit 3
// ═══════════════════════════════════════════════════════════════════════════

fn emitError(writer: anytype, cfg: *const CliConfig, gs: ?vb.GobanSize, art_path: ?[]const u8, art_sha: ?[]const u8, art_total: ?u64, art_legal: ?u64, ts: []const u8, start_ms: i64, ek: []const u8, em: []const u8) void {
    var gbuf: [8]u8 = undefined;
    const gstr: ?[]const u8 = if (gs) |g| std.fmt.bufPrint(&gbuf, "{d}x{d}", .{ g.w, g.h }) catch null else null;
    var iv: [0][]const u8 = undefined;
    emitJson(writer, HeaderRecord{
        .battery_version = VERSION,
        .schema_version = SCHEMA_VERSION,
        .artifact_kind = null, .format = null, .format_version = null,
        .goban = gstr, .artifact = art_path, .artifact_sha256 = art_sha,
        .artifact_total = art_total, .artifact_legal_count = art_legal,
        .artifact_rules_id = null, .artifact_rules_name = null,
        .reference_path = cfg.reference_path, .reference_sha256 = null,
        .timestamp = ts, .argv = &iv, .seed = cfg.seed,
        .seed_source = ssLabel(cfg.seed_source),
        .invariants_requested = &iv, .i5_graph = null,
    });
    emitJson(writer, ResultRecord{
        .invariant = "ALL", .goban = gstr orelse "unknown",
        .artifact_kind = null, .format = null, .format_version = null,
        .artifact = art_path, .artifact_sha256 = art_sha,
        .mode_declared = "not-applicable", .mode_actual = "not-applicable",
        .scope_once_per_goban = false,
        .status = "error", .exit_class = "battery-bad",
        .duration_ms = @intCast(nowMs() - start_ms),
        .rss_hwm_after_mb = null,
        .seed = null, .sample_size = null, .sample_denominator = null,
        .value = null, .deviation = null,
        .@"error" = ErrorRecord{ .kind = ek, .message = em },
    });
    const dur: u64 = @intCast(nowMs() - start_ms);
    emitJson(writer, TrailerRecord{
        .exit_code = 3, .total_duration_ms = dur, .rss_hwm_after_mb = null,
        .result_counts = .{ .@"error" = 1 },
        .exit_class_counts = .{ .@"battery_bad" = 1 },
    });
}

// ═══════════════════════════════════════════════════════════════════════════
// MAIN
// ═══════════════════════════════════════════════════════════════════════════

pub fn main(init: std.process.Init) u8 {
    const allocator = init.gpa;
    const io = init.io;
    var stdout_buf: [4096]u8 = undefined;
    const start_ms = nowMs();

    // Collect args from the Init
    const raw_args: []const [*:0]const u8 = init.minimal.args.vector;
    var args_list: std.ArrayList([]const u8) = .empty;
    for (raw_args) |arg_ptr| {
        args_list.append(allocator, std.mem.sliceTo(arg_ptr, 0)) catch {
            note("error: out of memory\n", .{});
            return 3;
        };
    }
    const args = args_list.items;

    const cfg = parseCli(args) catch {
        note("Try 'verify-battery --help' for usage.\n", .{});
        return 3;
    };
    if (cfg.show_help) { note("{s}", .{HELP}); return 0; }
    if (cfg.show_version) { note("verify-battery v{s}\n", .{VERSION}); return 0; }

    if (cfg.goban == null) {
        note("error: <goban> argument required\n", .{});
        return 3;
    }
    const gs = cfg.goban.?;
    const need_artifact = !(cfg.i5_only and std.mem.eql(u8, cfg.i5_graph, "all-legal"));
    if (need_artifact and cfg.artifact_path == null and !cfg.arg_artifact_empty) {
        note("error: <artifact> argument required\n", .{});
        return 3;
    }

    // Timestamp
    var ts_buf: [32]u8 = undefined;
    const timestamp = formatTimestamp(start_ms, &ts_buf) catch "unknown";

    // Artifact loading
    var artifact_kind: ?vb.ArtifactKind = null;
    var artifact_format: ?vb.ArtifactFormat = null;
    var artifact_fmt_ver: ?u8 = null;
    var art_sha_hex: ?[]const u8 = null;
    var art_sha_buf: [64]u8 = undefined;
    var art_total: ?u64 = null;
    var art_legal: ?u64 = null;
    var art_rules_id: ?u8 = null;
    var art_rules_name: ?[]const u8 = null;
    var decoded: ?vb.WZO1Decoded = null;

    // Reference file
    var ref_sha_hex: ?[]const u8 = null;
    var ref_sha_buf: [64]u8 = undefined;
    if (cfg.reference_path) |rp| {
        const ref_bytes = std.Io.Dir.cwd().readFileAlloc(io, rp, allocator, .unlimited) catch |err| {
            note("error: cannot read reference file '{s}': {}\n", .{ rp, err });
            const writer = std.Io.File.stdout().writer(io, &stdout_buf);
            emitError(writer, &cfg, gs, cfg.artifact_path, null, null, null, timestamp, start_ms, "artifact_load", "Cannot read reference file");
            return 3;
        };
        defer allocator.free(ref_bytes);
        sha256Hex(ref_bytes, &ref_sha_buf);
        ref_sha_hex = &ref_sha_buf;
    }

    // Open output file (or use stdout)
    var out_file: ?std.Io.File = null;
    var out_buf: [4096]u8 = undefined;
    if (cfg.output_path) |op| {
        out_file = std.Io.Dir.cwd().createFile(io, op, .{}) catch |err| {
            note("error: cannot create output file '{s}': {}\n", .{ op, err });
            return 3;
        };
    }

    const art_path_for_hdr: ?[]const u8 = cfg.artifact_path;

    if (need_artifact and cfg.artifact_path != null) {
        const art_path = cfg.artifact_path.?;
        const file_bytes = std.Io.Dir.cwd().readFileAlloc(io, art_path, allocator, .unlimited) catch |err| {
            note("error: cannot read artifact '{s}': {}\n", .{ art_path, err });
            const w = if (out_file) |*f| f.writer(io, &out_buf) else std.Io.File.stdout().writer(io, &stdout_buf);
            emitError(w, &cfg, gs, art_path_for_hdr, null, null, null, timestamp, start_ms, "artifact_load", "Cannot read artifact file");
            if (out_file) |*f| f.close(io);
            return 3;
        };
        defer allocator.free(file_bytes);

        sha256Hex(file_bytes, &art_sha_buf);
        art_sha_hex = &art_sha_buf;

        if (cfg.sha256) |eh| {
            if (!std.ascii.eqlIgnoreCase(art_sha_hex.?, eh)) {
                note("error: SHA-256 mismatch\nexpected: {s}\n     got: {s}\n", .{ eh, art_sha_hex.? });
                const w = if (out_file) |*f| f.writer(io, &out_buf) else std.Io.File.stdout().writer(io, &stdout_buf);
                emitError(w, &cfg, gs, art_path_for_hdr, art_sha_hex, null, null, timestamp, start_ms, "artifact_load", "SHA-256 mismatch");
                if (out_file) |*f| f.close(io);
                return 3;
            }
        }

        const dec = vb.decodeWZO1(allocator, file_bytes) catch |err| {
            note("error: artifact load failed: {}\n", .{err});
            const w = if (out_file) |*f| f.writer(io, &out_buf) else std.Io.File.stdout().writer(io, &stdout_buf);
            emitError(w, &cfg, gs, art_path_for_hdr, art_sha_hex, null, null, timestamp, start_ms, "artifact_load", @errorName(err));
            if (out_file) |*f| f.close(io);
            return 3;
        };
        decoded = dec;

        artifact_kind = .@"pinned-v";
        artifact_format = .WZO1;
        artifact_fmt_ver = 1;
        art_total = dec.header.total;
        art_legal = dec.header.legal_count;
        art_rules_id = dec.header.rules_id;
        art_rules_name = vb.rulesName(dec.header.rules_id);

        if (dec.header.board_w != gs.w or dec.header.board_h != gs.h) {
            note("warning: goban {d}x{d} != artifact {d}x{d}\n", .{ gs.w, gs.h, dec.header.board_w, dec.header.board_h });
        }
        note("artifact: {s}  {d}x{d}  total={d}  legal={d}  rules={s}  sha256={s}\n", .{
            art_path, dec.header.board_w, dec.header.board_h,
            dec.header.total, dec.header.legal_count,
            art_rules_name.?, art_sha_hex.?,
        });
    }

    // Resolve invariants
    const invariants = resolveInvariants(allocator, &cfg) catch {
        note("error: failed to resolve invariants\n", .{});
        return 3;
    };

    var inv_labels: std.ArrayList([]const u8) = .empty;
    for (invariants) |inv| { inv_labels.append(allocator, inv.label()) catch {}; }

    var i5g: ?[]const u8 = null;
    for (invariants) |inv| { if (inv == .I5) { i5g = cfg.i5_graph; break; } }

    // Select writer
    const writer = if (out_file) |*f| f.writer(io, &out_buf) else std.Io.File.stdout().writer(io, &stdout_buf);

    // Header
    emitJson(writer, HeaderRecord{
        .battery_version = VERSION, .schema_version = SCHEMA_VERSION,
        .artifact_kind = if (artifact_kind) |ak| akLabel(ak) else null,
        .format = if (artifact_format) |af| afLabel(af) else null,
        .format_version = artifact_fmt_ver,
        .goban = std.fmt.allocPrint(allocator, "{d}x{d}", .{ gs.w, gs.h }) catch null,
        .artifact = art_path_for_hdr, .artifact_sha256 = art_sha_hex,
        .artifact_total = art_total, .artifact_legal_count = art_legal,
        .artifact_rules_id = art_rules_id, .artifact_rules_name = art_rules_name,
        .reference_path = cfg.reference_path, .reference_sha256 = ref_sha_hex,
        .timestamp = timestamp, .argv = args,
        .seed = cfg.seed, .seed_source = ssLabel(cfg.seed_source),
        .invariants_requested = inv_labels.items, .i5_graph = i5g,
    });

    // Run invariants
    var results: std.ArrayList(vb.CheckResult) = .empty;
    var counts = TrailerCounts{};
    var ec_counts = ExitClassCounts{};
    var goban_str_buf: [8]u8 = undefined;
    const goban_str = std.fmt.bufPrint(&goban_str_buf, "{d}x{d}", .{ gs.w, gs.h }) catch "??";
    const ak_str: ?[]const u8 = if (artifact_kind) |ak| akLabel(ak) else null;
    const af_str: ?[]const u8 = if (artifact_format) |af| afLabel(af) else null;
    const afv: ?u8 = artifact_fmt_ver;

    for (invariants) |inv| {
        const inv_start = nowMs();
        var result = stubCheck(inv, gs, artifact_kind, artifact_format);
        result.artifact = art_path_for_hdr;
        result.artifact_sha256 = art_sha_hex;
        result.duration_ms = @intCast(nowMs() - inv_start);

        switch (result.status) {
            .pass => counts.pass += 1,
            .fail => counts.fail += 1,
            .@"reference-disagreement" => counts.@"reference_disagreement" += 1,
            .skipped => counts.skipped += 1,
            .@"not-applicable" => counts.@"not_applicable" += 1,
            .@"error" => counts.@"error" += 1,
        }
        switch (result.exit_class) {
            .pass => ec_counts.pass += 1,
            .@"artifact-bad" => ec_counts.@"artifact_bad" += 1,
            .@"reference-bad" => ec_counts.@"reference_bad" += 1,
            .@"battery-bad" => ec_counts.@"battery_bad" += 1,
        }

        emitJson(writer, ResultRecord{
            .invariant = inv.label(), .goban = goban_str,
            .artifact_kind = ak_str, .format = af_str, .format_version = afv,
            .artifact = result.artifact, .artifact_sha256 = result.artifact_sha256,
            .mode_declared = mdLabel(result.mode_declared),
            .mode_actual = mdLabel(result.mode_actual),
            .scope_once_per_goban = result.scope_once_per_goban,
            .status = csLabel(result.status), .exit_class = ecLabel(result.exit_class),
            .duration_ms = result.duration_ms,
            .rss_hwm_after_mb = result.rss_hwm_after_mb,
            .seed = result.seed, .sample_size = result.sample_size,
            .sample_denominator = result.sample_denominator,
            .value = null, .deviation = result.deviation,
            .@"error" = if (result.@"error") |e| ErrorRecord{
                .kind = @tagName(e.kind), .message = e.message,
            } else null,
        });
        results.append(allocator, result) catch {};
    }

    const exit_code = computeExitCode(results.items);
    const total_dur: u64 = @intCast(nowMs() - start_ms);

    emitJson(writer, TrailerRecord{
        .exit_code = exit_code, .total_duration_ms = total_dur,
        .rss_hwm_after_mb = null,
        .result_counts = counts, .exit_class_counts = ec_counts,
    });

    if (decoded) |*d| d.deinit();
    if (out_file) |*f| f.close(io);
    return exit_code;
}
