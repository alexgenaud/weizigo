////////////////////////////////////////////
//                                        //
//    (c) 2026 Alexander E Genaud         //
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
// T393 — two-life census instrument (deepseek-v4-flash/T393, 2026-08-06).
//
// Census only: reads committed artifacts, counts Benson-alive / bracket
// structure. No solving, no re-derivation, no fixes. Additive instrument
// (src/t393_census.zig); no engine / artifact / axiom edits.
//
// Measures (brief untracked/T393-two-life-census.md):
//
//   1. two-life frequency  — positions where BOTH colours have at least one
//      Benson-alive chain (benson_alive, rules.zig). WZO2 table walk for
//      3×3 / 4×4; WZO1 slot walk for 4×3 (no WZO2 artifact there). Completes
//      the T382 zero-alive series (its 4×4 figure was pending).
//   2. life-vs-bracket join — per WZO2 entry, the bracket class
//      (T: L==H; L: L<H & L>0; H: L<H & H<0; Z: L<H & L≤0≤H, the A4 pin
//      census names) crossed with the predicate "the side to move holds a
//      Benson-alive chain on the board NOW" (also opponent / either / both /
//      none). Hypothesis under test: NO entry containing an alive chain has
//      a bracket straddling zero (Z ∧ any-alive == 0). Witness boards are
//      captured for the first Z∧any-alive entries, if any.
//      Converse slice: of the 895,216 pin_0 (Z) entries at 4×4, how many
//      contain a Benson-alive chain for either colour — that is exactly the
//      Z∧either count.
//   3. winner's-structure check (3×3 only) — among positions where a colour
//      is Benson-alive, does unconditional life ever exist without a stone
//      of that colour at the centre point? Prediction: yes (the diamond
//      .x./x.x/.x. == the four edge-midpoints shape, cells 1,3,5,7). Count
//      the counterexample set raw, mod D4, and mod D4×colour-inversion.
//
// Controls (brief bars):
//   * null control — boards with no live chains report zero (empty goban,
//     lone corner stone; plus the committed 3×3 two-life == 0 cross-check);
//   * positive control — the brief's hand-verified 4×4 two-life board, the
//     3×3 diamond, and a 3×3 two-eye ring shape;
//   * seeded-defect control — three deliberately broken vitality predicates
//     must FAIL the canaries that the correct predicate passes;
//   * independent re-implementation — every 1024th group compares
//     rules.benson_alive against rules.naive_benson_alive (the QA-023 lesson:
//     re-implementation is the only defect-finder that has ever worked);
//   * committed cross-checks — 3×3 WZO2 groups/entries/L<H == 12,675 /
//     49,428 / 5,408; 4×4 pin_T/L/H/0 == 95,677,624 / 1,280,098 / 1,280,098 /
//     895,216 (A4 baseline); 4×3 WZO1 two-life == 2 (T382 series).
//
// Modes:
//   --selftest
//   --wzo2 <file.wzo2>    parts 1+2 (+3 when the file is 3×3)
//   --wzo1 <file.wzo>     part 1 (two-life frequency) over a WZO1 artifact (4×3)
//
// Build: tools/runner -- zig build-exe src/t393_census.zig \
//          --name weizigo-t393-census   (runner adds -O ReleaseFast)

const std = @import("std");
const util = @import("util.zig");
const artifact = @import("artifact.zig");
const artifact2 = @import("artifact2.zig");
const colex = @import("colex.zig");
const rules = @import("rules.zig");

const UNDEF: i8 = -128;

fn asPct(part: u64, total: u64) f64 {
    if (total == 0) return 0.0;
    return @as(f64, @floatFromInt(part)) * 100.0 / @as(f64, @floatFromInt(total));
}

// ═════════════════════════════════════════════════════════════════════════
//  Bracket classes (A4 pin-census names; TIE=0 pinned value = max(L,min(0,H)))
//    T — L == H            (certified / pin_T)
//    L — L < H, L > 0      (TIE=0 would select L / pin_L)
//    H — L < H, H < 0      (TIE=0 would select H / pin_H)
//    Z — L < H, L ≤ 0 ≤ H  (straddling zero / pin_0)
// ═════════════════════════════════════════════════════════════════════════

const Bracket = enum(u8) { T, L, H, Z };

fn bracketOf(L: i8, H: i8) Bracket {
    if (L == H) return .T;
    if (L > 0) return .L;
    if (H < 0) return .H;
    return .Z;
}

fn bracketName(b: Bracket) []const u8 {
    return switch (b) {
        .T => "T",
        .L => "L",
        .H => "H",
        .Z => "Z",
    };
}

// ═════════════════════════════════════════════════════════════════════════
//  Shared alive predicate
// ═════════════════════════════════════════════════════════════════════════

fn anyAlive(comptime R: type, pos: *const R.Pos, colour: i8) bool {
    const al = R.benson_alive(pos, colour);
    for (0..R.n) |q| {
        if (al[q] and pos[q] == colour) return true;
    }
    return false;
}

// ═════════════════════════════════════════════════════════════════════════
//  WZO2 sweep (parts 1 + 2, and part 3 for 3×3)
// ═════════════════════════════════════════════════════════════════════════

const AliveCounts = struct {
    side: u64 = 0,
    opp: u64 = 0,
    either: u64 = 0,
    both: u64 = 0,
    none: u64 = 0,
};

const Witness = struct {
    colex: u64,
    side: i8,
    ko: u8,
    passes: u1,
    L: i8,
    H: i8,
    dtt: u8,
    b_alive: bool,
    w_alive: bool,
};

const BracketCounts = struct {
    entries: u64 = 0,
    by_bracket: [4]u64 = [_]u64{0} ** 4,
    alive: [4]AliveCounts = [_]AliveCounts{.{}} ** 4,
    overall: AliveCounts = .{},
    z_either: u64 = 0,
    witnesses: [3]Witness = undefined,
    n_witnesses: u8 = 0,
};

const Wzo2Result = struct {
    groups: u64 = 0,
    entries: u64 = 0,
    all: BracketCounts = .{},
    fs: BracketCounts = .{},
    pos_legal: u64 = 0,
    pos_two_life: u64 = 0,
    pos_b_only: u64 = 0,
    pos_w_only: u64 = 0,
    pos_neither: u64 = 0,
    pos_has_z: u64 = 0,
    pos_has_z_and_alive: u64 = 0,
    spot_checked: u64 = 0,
    spot_mismatch: u64 = 0,
    // part 3 (3×3 only)
    pos_alive_any: u64 = 0,
    alive_any_no_centre: u64 = 0,
    alive_any_no_centre_strict: u64 = 0,
    orbits_d4: u64 = 0,
    orbits_d4c2: u64 = 0,
    n_orbit_reps: u8 = 0,
    orbit_reps: [12]u64 = undefined,
    diamond_orbit_present: bool = false,
};

fn addEntry(c: *BracketCounts, br: Bracket, side_alive: bool, opp_alive: bool) void {
    c.entries += 1;
    c.by_bracket[@intFromEnum(br)] += 1;
    const ac = &c.alive[@intFromEnum(br)];
    const either = side_alive or opp_alive;
    const both = side_alive and opp_alive;
    if (side_alive) ac.side += 1;
    if (opp_alive) ac.opp += 1;
    if (either) ac.either += 1;
    if (both) ac.both += 1;
    if (!either) ac.none += 1;
    const oc = &c.overall;
    if (side_alive) oc.side += 1;
    if (opp_alive) oc.opp += 1;
    if (either) oc.either += 1;
    if (both) oc.both += 1;
    if (!either) oc.none += 1;
}

fn Wzo2Sweep(comptime w: usize, comptime h: usize) type {
    return struct {
        const R = rules.Rules(w, h);
        const X = colex.Indexer(w, h);
        const n = R.n;
        const centre: usize = w * h / 2; // 9/2 = 4 for 3×3; 16/2 = 8 (unused) for 4×4

        pub fn run(io: std.Io, path: []const u8, gpa: std.mem.Allocator) !void {
            const bytes = try std.Io.Dir.cwd().readFileAlloc(io, path, gpa, .unlimited);
            defer gpa.free(bytes);
            const res = try sweepBytes(bytes, gpa);
            printResult(path, &res);
        }

        /// Walk the WZO2 artifact bytes. Shared by the CLI mode and selftest.
        pub fn sweepBytes(bytes: []const u8, gpa: std.mem.Allocator) !Wzo2Result {
            var res = Wzo2Result{};
            if (bytes.len < 128) return error.Truncated;
            if (!std.mem.eql(u8, bytes[0..4], "WZO2")) return error.BadMagic;
            const ko_bits: u8 = bytes[13];
            const n_groups = std.mem.readInt(u64, bytes[16..24], .little);
            const n_entries = std.mem.readInt(u64, bytes[24..32], .little);
            const ko_none_val: u8 = w * h;

            var off: usize = artifact2.HEADER_LEN;
            const entry_base: usize = artifact2.HEADER_LEN + @as(usize, @intCast(n_groups)) * artifact2.GROUP_HEADER_SIZE;
            var ec: usize = entry_base;
            var group_i: u64 = 0;

            // part-3 orbit tracking (3×3 only)
            var orbits = std.AutoHashMap(u64, void).init(gpa);
            defer orbits.deinit();
            var orbits_c2 = std.AutoHashMap(u64, void).init(gpa);
            defer orbits_c2.deinit();
            var orbit_reps = std.ArrayListUnmanaged(u64).empty;
            defer orbit_reps.deinit(gpa);

            while (off + artifact2.GROUP_HEADER_SIZE <= bytes.len and group_i < n_groups) : (group_i += 1) {
                const colex_val = std.mem.readInt(u32, bytes[off..][0..4], .little);
                const count = bytes[off + 4];
                off += artifact2.GROUP_HEADER_SIZE;

                const pos = X.pos_from_colex(colex_val);

                const balive = R.benson_alive(&pos, 1);
                const walive = R.benson_alive(&pos, -1);
                var anyB = false;
                var anyW = false;
                for (0..n) |q| {
                    if (balive[q] and pos[q] == 1) anyB = true;
                    if (walive[q] and pos[q] == -1) anyW = true;
                }

                // independent re-implementation control (every 1024th group)
                if (group_i % 1024 == 0) {
                    res.spot_checked += 1;
                    const nb = rules.naive_benson_alive(w, h, &pos, 1);
                    const nw = rules.naive_benson_alive(w, h, &pos, -1);
                    var mm = false;
                    for (0..n) |q| {
                        if (balive[q] != nb[q]) mm = true;
                        if (walive[q] != nw[q]) mm = true;
                    }
                    if (mm) res.spot_mismatch += 1;
                }

                // part 1 — position classes
                res.groups += 1;
                res.pos_legal += 1;
                if (anyB and anyW) {
                    res.pos_two_life += 1;
                } else if (anyB) {
                    res.pos_b_only += 1;
                } else if (anyW) {
                    res.pos_w_only += 1;
                } else {
                    res.pos_neither += 1;
                }

                // part 3 — winner's-structure check (3×3 only)
                if (w == 3 and h == 3) {
                    const alive_any = anyB or anyW;
                    if (alive_any) res.pos_alive_any += 1;
                    const b_no_centre = anyB and pos[centre] != 1;
                    const w_no_centre = anyW and pos[centre] != -1;
                    if (b_no_centre or w_no_centre) {
                        res.alive_any_no_centre += 1;
                        const can_d4 = canonicalD4(&pos);
                        const can_d4c2 = canonicalD4C2(&pos);
                        if (!orbits.contains(can_d4)) {
                            try orbits.put(can_d4, {});
                            if (orbit_reps.items.len < res.orbit_reps.len) try orbit_reps.append(gpa, can_d4);
                        }
                        if (!orbits_c2.contains(can_d4c2)) try orbits_c2.put(can_d4c2, {});
                    }
                    if (pos[centre] == 0 and alive_any) res.alive_any_no_centre_strict += 1;
                    // is the brief's diamond (cells 1,3,5,7) in this set?
                    if (isDiamond(&pos)) {
                        const can_d4 = canonicalD4(&pos);
                        if (orbits.contains(can_d4)) res.diamond_orbit_present = true;
                    }
                }

                // part 2 — entry-level life-vs-bracket join
                var has_z = false;
                for (0..count) |_| {
                    if (ec + 4 > bytes.len) return error.Truncated;
                    const kb = bytes[ec];
                    const L: i8 = @bitCast(bytes[ec + 1]);
                    const H: i8 = @bitCast(bytes[ec + 2]);
                    const dtt = bytes[ec + 3];
                    ec += artifact2.ENTRY_SIZE;
                    res.entries += 1;
                    const dec = artifact2.decodeKeyByte(kb, ko_bits);
                    const side: i8 = if (dec.side == 0) 1 else -1;
                    const br = bracketOf(L, H);
                    const side_alive = if (side > 0) anyB else anyW;
                    const opp_alive = if (side > 0) anyW else anyB;
                    const either = side_alive or opp_alive;

                    addEntry(&res.all, br, side_alive, opp_alive);
                    if (br == .Z and either) {
                        res.all.z_either += 1;
                        if (res.all.n_witnesses < 3) {
                            res.all.witnesses[res.all.n_witnesses] = .{
                                .colex = colex_val,
                                .side = side,
                                .ko = dec.ko,
                                .passes = dec.passes,
                                .L = L,
                                .H = H,
                                .dtt = dtt,
                                .b_alive = anyB,
                                .w_alive = anyW,
                            };
                            res.all.n_witnesses += 1;
                        }
                    }

                    const is_fs = (dec.passes == 0) and (dec.ko == ko_none_val);
                    if (is_fs) {
                        addEntry(&res.fs, br, side_alive, opp_alive);
                        if (br == .Z and either) res.fs.z_either += 1;
                    }

                    if (br == .Z) has_z = true;
                }
                if (has_z) {
                    res.pos_has_z += 1;
                    if (anyB or anyW) res.pos_has_z_and_alive += 1;
                }
            }

            if (res.groups != n_groups or res.entries != n_entries) {
                util.warn("T393 WZO2 walk MISMATCH: walked groups={d}/{d} entries={d}/{d}\n", .{ res.groups, n_groups, res.entries, n_entries });
                return error.WalkMismatch;
            }

            if (w == 3 and h == 3) {
                res.orbits_d4 = orbits.count();
                res.orbits_d4c2 = orbits_c2.count();
                res.n_orbit_reps = @intCast(@min(orbit_reps.items.len, res.orbit_reps.len));
                for (orbit_reps.items[0..res.n_orbit_reps], 0..) |can, ri| res.orbit_reps[ri] = can;
            }
            return res;
        }

        // ── D4 symmetry on the 3×3 grid (cells 0..8 row-major) ──
        fn isDiamond(pos: *const [9]i8) bool {
            // the brief's shape .x. / x.x / .x. — cells 1,3,5,7 all same colour
            const c = pos[1];
            if (c == 0) return false;
            if (pos[3] != c or pos[5] != c or pos[7] != c) return false;
            for (0..9) |p| {
                if (p == 1 or p == 3 or p == 5 or p == 7) continue;
                if (pos[p] != 0) return false;
            }
            return true;
        }
        fn d4Transform(t: u8, p: usize) usize {
            const r = p / 3;
            const c = p % 3;
            var nr: usize = 0;
            var nc: usize = 0;
            switch (t) {
                0 => { nr = r; nc = c; },
                1 => { nr = c; nc = 2 - r; }, // rot 90°
                2 => { nr = 2 - r; nc = 2 - c; }, // rot 180°
                3 => { nr = 2 - c; nc = r; }, // rot 270°
                4 => { nr = 2 - r; nc = c; }, // flip top↔bottom
                5 => { nr = r; nc = 2 - c; }, // flip left↔right
                6 => { nr = c; nc = r; }, // main diagonal
                7 => { nr = 2 - c; nc = 2 - r; }, // anti diagonal
                else => unreachable,
            }
            return nr * 3 + nc;
        }

        fn canonicalD4(pos: *const [9]i8) u64 {
            var best: u64 = std.math.maxInt(u64);
            var t: u8 = 0;
            while (t < 8) : (t += 1) {
                var q: [9]i8 = undefined;
                for (0..9) |p| q[d4Transform(t, p)] = pos[p];
                const idx = X.colex_from_pos(&q);
                if (idx < best) best = idx;
            }
            return best;
        }

        fn canonicalD4C2(pos: *const [9]i8) u64 {
            var best: u64 = std.math.maxInt(u64);
            var t: u8 = 0;
            while (t < 8) : (t += 1) {
                var flip: u8 = 0;
                while (flip < 2) : (flip += 1) {
                    var q: [9]i8 = undefined;
                    for (0..9) |p| {
                        const src = d4Transform(t, p);
                        q[p] = if (flip == 0) pos[src] else -pos[src];
                    }
                    const idx = X.colex_from_pos(&q);
                    if (idx < best) best = idx;
                }
            }
            return best;
        }

        fn printBoard(pos: *const [9]i8) void {
            var r: usize = 0;
            while (r < 3) : (r += 1) {
                var line: [3]u8 = undefined;
                for (0..3) |c| {
                    line[c] = switch (pos[r * 3 + c]) {
                        1 => 'x',
                        -1 => 'o',
                        else => '.',
                    };
                }
                util.out("    {s}\n", .{line});
            }
        }

        fn printResult(path: []const u8, res: *const Wzo2Result) void {
            util.out("== t393 wzo2 {d}x{d} {s}\n", .{ w, h, path });
            util.out("walked: groups={d} entries={d}  {s}\n", .{ res.groups, res.entries, if (res.groups == 0) "EMPTY" else "OK" });
            util.out("spotcheck (every 1024th group, rules.benson_alive vs naive): checked={d} mismatches={d}  {s}\n", .{ res.spot_checked, res.spot_mismatch, if (res.spot_mismatch == 0) "OK" else "MISMATCH" });
            util.out("part1 positions: legal={d} two_life={d} ({d:.4}%) b_only={d} w_only={d} neither={d} zero_alive_colour={d} ({d:.4}%)\n", .{
                res.pos_legal, res.pos_two_life, asPct(res.pos_two_life, res.pos_legal),
                res.pos_b_only, res.pos_w_only, res.pos_neither,
                res.pos_legal - res.pos_two_life, asPct(res.pos_legal - res.pos_two_life, res.pos_legal),
            });
            util.out("part1 positions: has_straddling(Z)_entry={d}  has_Z_and_alive={d}\n", .{ res.pos_has_z, res.pos_has_z_and_alive });
            if (w == 3 and h == 3) {
                util.out("part3 (3x3): alive_positions={d}  alive_without_centre={d}  alive_without_centre_strict(centre empty)={d}\n", .{ res.pos_alive_any, res.alive_any_no_centre, res.alive_any_no_centre_strict });
                util.out("part3 orbits of alive_without_centre: D4={d}  D4xcolour-inversion={d}  diamond_orbit_present={s}\n", .{ res.orbits_d4, res.orbits_d4c2, if (res.diamond_orbit_present) "yes" else "no" });
                var ri: usize = 0;
                while (ri < res.n_orbit_reps) : (ri += 1) {
                    const pos = X.pos_from_colex(res.orbit_reps[ri]);
                    util.out("  orbit rep {d} (colex {d}):\n", .{ ri, res.orbit_reps[ri] });
                    printBoard(&pos);
                }
            }
            if (w == 4 and h == 4) {
                // committed A4 pin census (docs/evidence/ORACLE-V2/rebuild-2026-08-03.md)
                const ok = res.all.by_bracket[@intFromEnum(Bracket.T)] == 95677624 and
                    res.all.by_bracket[@intFromEnum(Bracket.L)] == 1280098 and
                    res.all.by_bracket[@intFromEnum(Bracket.H)] == 1280098 and
                    res.all.by_bracket[@intFromEnum(Bracket.Z)] == 895216;
                util.out("pin census vs committed A4 baseline (T=95677624 L=1280098 H=1280098 Z=895216): {s}\n", .{if (ok) "MATCH" else "MISMATCH"});
            }
            printBracketCounts("all entries", &res.all);
            printBracketCounts("fresh-start slice (passes=0, ko=none)", &res.fs);
            const verdict = if (res.all.z_either == 0 and res.fs.z_either == 0) "STANDS" else "REFUTED";
            util.out("hypothesis (no state containing a Benson-alive chain has a bracket straddling zero): all_entries_z_either={d}  freshstart_z_either={d}  -> {s}\n", .{ res.all.z_either, res.fs.z_either, verdict });
            var wi: u8 = 0;
            while (wi < res.all.n_witnesses) : (wi += 1) {
                const wt = &res.all.witnesses[wi];
                util.out("  witness {d}: colex={d} side={s} ko={d} passes={d} L={d} H={d} dtt={d} b_alive={s} w_alive={s}\n", .{
                    wi, wt.colex, if (wt.side > 0) "B" else "W", wt.ko, wt.passes,
                    wt.L, wt.H, wt.dtt, if (wt.b_alive) "yes" else "no", if (wt.w_alive) "yes" else "no",
                });
            }
            util.out("== end {d}x{d}\n", .{ w, h });
        }

        fn printBracketCounts(label: []const u8, c: *const BracketCounts) void {
            util.out("part2 {s}: entries={d}\n", .{ label, c.entries });
            inline for ([_]Bracket{ .T, .L, .H, .Z }) |br| {
                const ac = &c.alive[@intFromEnum(br)];
                util.out("  bracket {s}: total={d}  side_alive={d} opp_alive={d} either_alive={d} both_alive={d} none_alive={d}\n", .{
                    bracketName(br), c.by_bracket[@intFromEnum(br)],
                    ac.side, ac.opp, ac.either, ac.both, ac.none,
                });
            }
            util.out("  overall: side_alive={d} opp_alive={d} either_alive={d} both_alive={d} none_alive={d}\n", .{
                c.overall.side, c.overall.opp, c.overall.either, c.overall.both, c.overall.none,
            });
            util.out("  Z(either_alive) = {d}\n", .{c.z_either});
        }
    };
}

// ═════════════════════════════════════════════════════════════════════════
//  WZO1 sweep (part 1 — two-life frequency, e.g. 4×3)
// ═════════════════════════════════════════════════════════════════════════

fn Wzo1Sweep(comptime w: usize, comptime h: usize) type {
    return struct {
        const R = rules.Rules(w, h);
        const X = colex.Indexer(w, h);

        pub fn run(io: std.Io, path: []const u8, gpa: std.mem.Allocator) !void {
            try runImpl(io, path, gpa, false);
        }

        pub fn runTwolife(io: std.Io, path: []const u8, gpa: std.mem.Allocator) !void {
            try runImpl(io, path, gpa, true);
        }

        fn runImpl(io: std.Io, path: []const u8, gpa: std.mem.Allocator, show_boards: bool) !void {
            const bytes = try std.Io.Dir.cwd().readFileAlloc(io, path, gpa, .unlimited);
            defer gpa.free(bytes);
            var dec = try artifact.decode(gpa, bytes);
            defer dec.deinit();
            var legal: u64 = 0;
            var two_life: u64 = 0;
            var b_only: u64 = 0;
            var w_only: u64 = 0;
            var neither: u64 = 0;
            var i: u64 = 0;
            while (i < X.total) : (i += 1) {
                const idx: usize = @intCast(i);
                if (dec.vb[idx] == UNDEF and dec.vw[idx] == UNDEF) continue;
                legal += 1;
                const pos = X.pos_from_colex(i);
                const anyB = anyAlive(R, &pos, 1);
                const anyW = anyAlive(R, &pos, -1);
                if (anyB and anyW) {
                    two_life += 1;
                    if (show_boards and two_life <= 8) printWzo1Board(&pos);
                } else if (anyB) {
                    b_only += 1;
                } else if (anyW) {
                    w_only += 1;
                } else {
                    neither += 1;
                }
            }
            util.out("== t393 wzo1 {d}x{d} {s}\n", .{ w, h, path });
            util.out("artifact legal_count (header): {d}\n", .{dec.header.legal_count});
            util.out("positions: legal={d} two_life={d} ({d:.4}%) b_only={d} w_only={d} neither={d} zero_alive_colour={d} ({d:.4}%)\n", .{
                legal, two_life, asPct(two_life, legal),
                b_only, w_only, neither,
                legal - two_life, asPct(legal - two_life, legal),
            });
            util.out("== end {d}x{d}\n", .{ w, h });
        }

        fn printWzo1Board(pos: *const R.Pos) void {
            var r: usize = 0;
            while (r < h) : (r += 1) {
                var line: [16]u8 = undefined;
                for (0..w) |c| {
                    line[c] = switch (pos[r * w + c]) {
                        1 => 'x',
                        -1 => 'o',
                        else => '.',
                    };
                }
                util.out("    {s}\n", .{line[0..w]});
            }
        }
    };
}

// ═════════════════════════════════════════════════════════════════════════
//  Seeded-defect mutants (used ONLY by the selftest controls)
// ═════════════════════════════════════════════════════════════════════════

fn mutantNeverAlive(comptime R: type, pos: *const R.Pos, colour: i8) bool {
    _ = pos;
    _ = colour;
    return false;
}

fn mutantAlwaysAlive(comptime R: type, pos: *const R.Pos, colour: i8) bool {
    _ = pos;
    _ = colour;
    return true;
}

fn mutantWhiteBlind(comptime R: type, pos: *const R.Pos, colour: i8) bool {
    if (colour < 0) return false;
    return anyAlive(R, pos, colour);
}

// ═════════════════════════════════════════════════════════════════════════
//  selftest
// ═════════════════════════════════════════════════════════════════════════

fn selftest(io: std.Io, gpa: std.mem.Allocator) !void {
    var passed: u32 = 0;
    var failed: u32 = 0;
    const check = struct {
        fn c(ok: bool, name: []const u8, p: *u32, f: *u32) void {
            if (ok) {
                p.* += 1;
                util.out("  [PASS] {s}\n", .{name});
            } else {
                f.* += 1;
                util.out("  [FAIL] {s}\n", .{name});
            }
        }
    }.c;

    util.out("== t393 selftest\n", .{});

    // ── 1. bracket classification on hand-built L/H pairs ──
    {
        check(bracketOf(0, 0) == .T, "bracket: (0,0) is T (L==H)", &passed, &failed);
        check(bracketOf(1, 1) == .T, "bracket: (1,1) is T", &passed, &failed);
        check(bracketOf(-4, -4) == .T, "bracket: (-4,-4) is T", &passed, &failed);
        check(bracketOf(2, 5) == .L, "bracket: (2,5) is L (L<H, L>0)", &passed, &failed);
        check(bracketOf(0, 5) == .Z, "bracket: (0,5) is Z (L==0)", &passed, &failed);
        check(bracketOf(-5, -2) == .H, "bracket: (-5,-2) is H (L<H, H<0)", &passed, &failed);
        check(bracketOf(-5, 0) == .Z, "bracket: (-5,0) is Z (H==0)", &passed, &failed);
        check(bracketOf(-1, 3) == .Z, "bracket: (-1,3) is Z (straddling)", &passed, &failed);
    }

    // ── 2. null controls: no live chains → zero ──
    {
        const R3 = rules.Rules(3, 3);
        var empty = [_]i8{0} ** 9;
        check(!anyAlive(R3, &empty, 1) and !anyAlive(R3, &empty, -1), "null: empty 3×3 has no Benson-alive chain (either colour)", &passed, &failed);
        var lone = [_]i8{0} ** 9;
        lone[0] = 1; // lone corner stone
        check(!anyAlive(R3, &lone, 1) and !anyAlive(R3, &lone, -1), "null: lone corner stone on 3×3 is NOT Benson-alive", &passed, &failed);
    }

    // ── 3. positive controls: known alive shapes ──
    {
        const R3 = rules.Rules(3, 3);
        // diamond == four edge midpoints, cells 1,3,5,7 (the brief's shape)
        var diamond = [_]i8{0} ** 9;
        diamond[1] = 1;
        diamond[3] = 1;
        diamond[5] = 1;
        diamond[7] = 1;
        check(anyAlive(R3, &diamond, 1), "positive: 3×3 diamond (cells 1,3,5,7) IS Benson-alive for Black", &passed, &failed);
        check(!anyAlive(R3, &diamond, -1), "positive: diamond White has no stones → not alive", &passed, &failed);
        check(diamond[4] == 0, "positive: diamond has NO stone at the centre point", &passed, &failed);
        // two-eye ring, cells 1,2,3,5,6,7
        var ring = [_]i8{0} ** 9;
        ring[1] = 1; ring[2] = 1; ring[3] = 1; ring[5] = 1; ring[6] = 1; ring[7] = 1;
        check(anyAlive(R3, &ring, 1), "positive: 3×3 two-eye ring (1,2,3,5,6,7) IS Benson-alive", &passed, &failed);
        check(ring[4] == 0, "positive: ring has no stone at the centre", &passed, &failed);

        // the brief's hand-verified 4×4 two-life board:
        //   .x..
        //   xxxx
        //   oooo
        //   .o..
        const R4 = rules.Rules(4, 4);
        var ex = [_]i8{0} ** 16;
        ex[1] = 1;
        ex[4] = 1; ex[5] = 1; ex[6] = 1; ex[7] = 1;
        ex[8] = -1; ex[9] = -1; ex[10] = -1; ex[11] = -1;
        ex[13] = -1;
        check(anyAlive(R4, &ex, 1) and anyAlive(R4, &ex, -1), "positive: brief's 4×4 example has BOTH colours Benson-alive", &passed, &failed);
    }

    // ── 4. seeded-defect control: broken vitality predicates must be caught ──
    {
        const R4 = rules.Rules(4, 4);
        const R3 = rules.Rules(3, 3);
        var ex = [_]i8{0} ** 16;
        ex[1] = 1;
        ex[4] = 1; ex[5] = 1; ex[6] = 1; ex[7] = 1;
        ex[8] = -1; ex[9] = -1; ex[10] = -1; ex[11] = -1;
        ex[13] = -1;
        var empty3 = [_]i8{0} ** 9;
        // Each mutant is substituted into the canary that guards the aspect it
        // breaks. The canary's verdict under the correct predicate must PASS
        // and its verdict under the mutant must FAIL — i.e. the canary
        // distinguishes the two.
        const pos_correct = anyAlive(R4, &ex, 1) and anyAlive(R4, &ex, -1); // positive canary
        const pos_mutant_a = mutantNeverAlive(R4, &ex, 1) and mutantNeverAlive(R4, &ex, -1);
        check(pos_correct and !pos_mutant_a, "seeded-defect: mutant A (never-alive) trips the positive canary the correct predicate passes", &passed, &failed);
        const null_correct = !anyAlive(R3, &empty3, 1); // null canary
        const null_mutant_b = !mutantAlwaysAlive(R3, &empty3, 1);
        check(null_correct and !null_mutant_b, "seeded-defect: mutant B (always-alive) trips the null canary the correct predicate passes", &passed, &failed);
        const both_correct = anyAlive(R4, &ex, 1) and anyAlive(R4, &ex, -1); // both-alive canary
        const both_mutant_c = anyAlive(R4, &ex, 1) and mutantWhiteBlind(R4, &ex, -1);
        check(both_correct and !both_mutant_c, "seeded-defect: mutant C (White-blind) trips the both-alive canary the correct predicate passes", &passed, &failed);
    }

    // ── 5. real-artifact cross-checks: 3×3 WZO2 walk ──
    {
        const path = "data/oracle-3x3-v2.wzo2";
        const bytes = try std.Io.Dir.cwd().readFileAlloc(io, path, gpa, .unlimited);
        defer gpa.free(bytes);
        const res = try Wzo2Sweep(3, 3).sweepBytes(bytes, gpa);
        check(res.groups == 12675 and res.entries == 49428, "cross-check: 3×3 WZO2 groups=12,675 entries=49,428 (committed)", &passed, &failed);
        check(res.all.by_bracket[@intFromEnum(Bracket.T)] + res.all.by_bracket[@intFromEnum(Bracket.L)] + res.all.by_bracket[@intFromEnum(Bracket.H)] + res.all.by_bracket[@intFromEnum(Bracket.Z)] == res.entries, "cross-check: bracket totals sum to entries", &passed, &failed);
        check(res.all.by_bracket[@intFromEnum(Bracket.L)] + res.all.by_bracket[@intFromEnum(Bracket.H)] + res.all.by_bracket[@intFromEnum(Bracket.Z)] == 5408, "cross-check: 3×3 WZO2 L<H = 5,408 (committed T382)", &passed, &failed);
        check(res.pos_two_life == 0, "cross-check: 3×3 two-life = 0 (T382 zero-alive series: 12,675/12,675)", &passed, &failed);
        // colour-inversion invariant: pin_L == pin_H at 3×3
        check(res.all.by_bracket[@intFromEnum(Bracket.L)] == res.all.by_bracket[@intFromEnum(Bracket.H)], "invariant: 3×3 pin_L == pin_H (colour-inversion symmetry)", &passed, &failed);
        check(res.spot_mismatch == 0, "cross-check: 3×3 spotcheck (benson_alive vs naive) has zero mismatches", &passed, &failed);
        check(res.all.z_either == 0, "cross-check: 3×3 Z ∧ any-alive = 0 (hypothesis holds at 3×3)", &passed, &failed);
    }

    // ── 6. synthetic WZO2 walker determinism (hand-built table) ──
    {
        const w: u8 = 2;
        const h: u8 = 2;
        const kb = artifact2.koBits(w * h);
        const none = artifact2.koNone(w, h); // 4
        const groups = [_]artifact2.GroupHeader{
            .{ .colex = 0, .entry_count = 2 },
            .{ .colex = 27, .entry_count = 2 },
        };
        const entries = [_]artifact2.EntryRow{
            .{ .key_byte = artifact2.encodeKeyByte(0, none, 0, 0, kb), .L = -1, .H = 3, .DTT = 10 }, // Z
            .{ .key_byte = artifact2.encodeKeyByte(1, none, 0, 0, kb), .L = 2, .H = 2, .DTT = 8 }, // T
            .{ .key_byte = artifact2.encodeKeyByte(0, none, 0, 0, kb), .L = 4, .H = 4, .DTT = 3 }, // T
            .{ .key_byte = artifact2.encodeKeyByte(1, none, 1, 0, kb), .L = 1, .H = 5, .DTT = 1 }, // L (passes=1, not fresh-start)
        };
        const art = artifact2.Artifact{
            .header = .{ .w = w, .h = h, .ko_bits = kb, .n_groups = groups.len, .n_entries = entries.len, .sha256 = [_]u8{0} ** 32 },
            .group_headers = &groups,
            .entry_rows = &entries,
        };
        const file_bytes = try artifact2.buildFile(gpa, &art);
        defer gpa.free(file_bytes);
        const res = try Wzo2Sweep(2, 2).sweepBytes(file_bytes, gpa);
        check(res.groups == 2 and res.entries == 4, "synthetic walker: groups=2 entries=4", &passed, &failed);
        check(res.all.by_bracket[@intFromEnum(Bracket.Z)] == 1 and res.all.by_bracket[@intFromEnum(Bracket.L)] == 1 and res.all.by_bracket[@intFromEnum(Bracket.T)] == 2, "synthetic walker: bracket counts T=2 L=1 Z=1", &passed, &failed);
        check(res.fs.entries == 3, "synthetic walker: fresh-start slice = 3 (passes=1 entry excluded)", &passed, &failed);
    }

    util.out("selftest: {d} passed, {d} failed\n", .{ passed, failed });
    if (failed > 0) std.process.exit(2);
}

// ═════════════════════════════════════════════════════════════════════════
//  main
// ═════════════════════════════════════════════════════════════════════════

pub fn main(init: std.process.Init) !void {
    const gpa = std.heap.page_allocator;
    var args = std.process.Args.Iterator.init(init.minimal.args);
    _ = args.next(); // program name
    const mode = args.next() orelse {
        util.out("usage: t393_census <mode> [args]\n", .{});
        util.out("  --selftest\n", .{});
        util.out("  --wzo2 <file.wzo2>\n", .{});
        util.out("  --wzo1 <file.wzo>\n", .{});
        return;
    };

    if (std.mem.eql(u8, mode, "--selftest")) {
        try selftest(init.io, gpa);
        return;
    }

    if (std.mem.eql(u8, mode, "--wzo2")) {
        const path = args.next() orelse return error.NoArtifact;
        const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, path, gpa, .unlimited);
        defer gpa.free(bytes);
        if (bytes.len < 128) return error.Truncated;
        if (!std.mem.eql(u8, bytes[0..4], "WZO2")) return error.BadMagic;
        const w = bytes[6];
        const h = bytes[7];
        switch (@as(usize, w) * 100 + h) {
            303 => try Wzo2Sweep(3, 3).run(init.io, path, gpa),
            404 => try Wzo2Sweep(4, 4).run(init.io, path, gpa),
            else => return error.Unsupported,
        }
        return;
    }

    if (std.mem.eql(u8, mode, "--wzo1")) {
        const path = args.next() orelse return error.NoArtifact;
        const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, path, gpa, .unlimited);
        defer gpa.free(bytes);
        if (bytes.len < 8) return error.Truncated;
        const w = bytes[6];
        const h = bytes[7];
        switch (@as(usize, w) * 100 + h) {
            303 => try Wzo1Sweep(3, 3).run(init.io, path, gpa),
            403 => try Wzo1Sweep(4, 3).run(init.io, path, gpa),
            404 => try Wzo1Sweep(4, 4).run(init.io, path, gpa),
            else => return error.Unsupported,
        }
        return;
    }

    if (std.mem.eql(u8, mode, "--twolife")) {
        const path = args.next() orelse return error.NoArtifact;
        const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, path, gpa, .unlimited);
        defer gpa.free(bytes);
        if (bytes.len < 8) return error.Truncated;
        const w = bytes[6];
        const h = bytes[7];
        switch (@as(usize, w) * 100 + h) {
            303 => try Wzo1Sweep(3, 3).runTwolife(init.io, path, gpa),
            403 => try Wzo1Sweep(4, 3).runTwolife(init.io, path, gpa),
            404 => try Wzo1Sweep(4, 4).runTwolife(init.io, path, gpa),
            else => return error.Unsupported,
        }
        return;
    }

    util.out("unknown mode: {s}\n", .{mode});
    return error.UnknownMode;
}
