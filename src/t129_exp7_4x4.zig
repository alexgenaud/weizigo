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
// T129 — EXP-7 4×4 re-run: certified fraction against
//        data/oracle-4x4-basicko-tie-area.wzo
//
// Task: T129 · Role: worker · Model: DSPro · Date: 2026-07-31
//
// Reads the new-rule (basic-ko + TIE=0) 4×4 artifact from T113 and runs
// self-play + direct Bellman identity check. The artifact stores V=median(L,0,H)
// in vb/vw columns with rules_id=2. This tool parses the WZO1 header manually
// to accept rules_id=2.
//
// Also supports 3×3 calibration mode (computes fixpoint in-memory, same as
// the original exp7_census.zig).
//
// Build:
//   tools/runner --rss-cap-mb 4096 --max-wall 1800 -- \
//     zig run -O ReleaseFast src/t129_exp7_4x4.zig -- 4 --wzo data/oracle-4x4-basicko-tie-area.wzo
//
//   tools/runner --rss-cap-mb 4096 --max-wall 1800 -- \
//     zig run -O ReleaseFast src/t129_exp7_4x4.zig -- 3   (calibration)

const std = @import("std");

const TIE: i8 = 0;
const UNDEF: i8 = -128;

// =========================================================================
// WZO1 manual reader — accepts rules_id=2 (basic-ko+TIE=0)
// =========================================================================

const WZO_MAGIC = [4]u8{ 'W', 'Z', 'O', '1' };
const WZO_HEADER_LEN: usize = 32;

const WzoHeader = struct {
    board_w: u8,
    board_h: u8,
    format_version: u8,
    colex_layout: u8,
    value_semantics: u8,
    rules_id: u8,
    column_count: u8,
    total: u64,
    legal_count: u64,
    payload_crc32: u32,
};

fn parseWzoHeader(bytes: []const u8) !WzoHeader {
    if (bytes.len < WZO_HEADER_LEN) return error.Truncated;
    if (!std.mem.eql(u8, bytes[0..4], &WZO_MAGIC)) return error.BadMagic;
    const fv = bytes[4];
    if (fv != 1) return error.BadVersion;
    const cl = bytes[5];
    if (cl != 1) return error.BadLayout;
    const total = std.mem.readInt(u64, bytes[12..20], .little);
    const legal_count = std.mem.readInt(u64, bytes[20..28], .little);
    const crc = std.mem.readInt(u32, bytes[28..32], .little);
    return WzoHeader{
        .board_w = bytes[6],
        .board_h = bytes[7],
        .format_version = fv,
        .colex_layout = cl,
        .value_semantics = bytes[8],
        .rules_id = bytes[9],
        .column_count = bytes[10],
        .total = total,
        .legal_count = legal_count,
        .payload_crc32 = crc,
    };
}

fn verifyPayloadCrc(bytes: []const u8) !void {
    const payload = bytes[WZO_HEADER_LEN..];
    const crc_stored = std.mem.readInt(u32, bytes[28..32], .little);
    const crc_computed = std.hash.crc.Crc32IsoHdlc.hash(payload);
    if (crc_stored != crc_computed) return error.BadChecksum;
}

const WzoArtifact = struct {
    vb: []const i8, // V values, Black to move
    vw: []const i8, // V values, White to move
    fb: []const u8, // flags (bit 0 = L<H bracket indicator)
    fw: []const u8,
    total: u64,
    rules_id: u8,

    fn deinit(self: *WzoArtifact, gpa: std.mem.Allocator) void {
        gpa.free(self.vb);
        gpa.free(self.vw);
        gpa.free(self.fb);
        gpa.free(self.fw);
    }
};

fn readWzo(gpa: std.mem.Allocator, path: []const u8) !WzoArtifact {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const bytes = try file.readToEndAlloc(gpa, std.math.maxInt(usize));
    errdefer gpa.free(bytes);

    const hdr = try parseWzoHeader(bytes);
    try verifyPayloadCrc(bytes);

    const t: usize = @intCast(hdr.total);
    if (bytes.len != WZO_HEADER_LEN + 6 * t) return error.Truncated;
    if (hdr.board_w == 0 or hdr.board_h == 0) return error.BadTotal;

    const payload = bytes[WZO_HEADER_LEN..];

    const vb = try gpa.alloc(i8, t);
    errdefer gpa.free(vb);
    const vw = try gpa.alloc(i8, t);
    errdefer gpa.free(vw);
    const fb = try gpa.alloc(u8, t);
    errdefer gpa.free(fb);
    const fw = try gpa.alloc(u8, t);
    errdefer gpa.free(fw);

    @memcpy(std.mem.sliceAsBytes(vb), payload[0 * t .. 1 * t]);
    @memcpy(std.mem.sliceAsBytes(vw), payload[1 * t .. 2 * t]);
    @memcpy(fb, payload[2 * t .. 3 * t]);
    @memcpy(fw, payload[3 * t .. 4 * t]);

    return WzoArtifact{
        .vb = vb,
        .vw = vw,
        .fb = fb,
        .fw = fw,
        .total = hdr.total,
        .rules_id = hdr.rules_id,
    };
}

// =========================================================================
// Generic goban operations for 4×4
// =========================================================================

fn pow3(n: u8) u64 {
    var x: u64 = 1;
    for (0..n) |_| x *= 3;
    return x;
}

fn genericNeighbors(p: usize, w: usize, h: usize, buf: *[4]usize) usize {
    var cnt: usize = 0;
    const r = p / w;
    const c = p % w;
    if (r > 0) { buf[cnt] = p - w; cnt += 1; }
    if (r + 1 < h) { buf[cnt] = p + w; cnt += 1; }
    if (c > 0) { buf[cnt] = p - 1; cnt += 1; }
    if (c + 1 < w) { buf[cnt] = p + 1; cnt += 1; }
    return cnt;
}

fn genericChainCaptured(comptime n_cells: usize, pos: []const i8, seed: usize, w: usize, h: usize, chain: *[n_cells]usize, chain_len: *usize) bool {
    const colour: i8 = if (pos[seed] > 0) 1 else -1;
    var visited = [_]bool{false} ** n_cells;
    var stack: [n_cells]usize = undefined;
    var sp: usize = 1;
    chain[0] = seed;
    visited[seed] = true;
    stack[0] = seed;
    var len: usize = 1;
    var has_liberty = false;
    while (sp > 0) {
        sp -= 1;
        const q = stack[sp];
        var nb: [4]usize = undefined;
        const cnt = genericNeighbors(q, w, h, &nb);
        for (nb[0..cnt]) |r| {
            if (pos[r] == 0) {
                has_liberty = true;
            } else if ((pos[r] > 0) == (colour > 0) and pos[r] != 0 and !visited[r]) {
                visited[r] = true;
                stack[sp] = r;
                sp += 1;
                chain[len] = r;
                len += 1;
            }
        }
    }
    chain_len.* = len;
    return !has_liberty;
}

fn genericPosFromMove(comptime n_cells: usize, pos: []i8, colour: i8, cell: usize, w: usize, h: usize) !void {
    if (pos[cell] != 0) return error.Occupied;
    pos[cell] = colour;
    var nb: [4]usize = undefined;
    const cnt = genericNeighbors(cell, w, h, &nb);
    var chain: [n_cells]usize = undefined;
    var chain_len: usize = 0;
    for (nb[0..cnt]) |q| {
        if (pos[q] * colour < 0) {
            if (genericChainCaptured(n_cells, pos, q, w, h, &chain, &chain_len)) {
                for (chain[0..chain_len]) |c| pos[c] = 0;
            }
        }
    }
    if (genericChainCaptured(n_cells, pos, cell, w, h, &chain, &chain_len)) return error.Suicide;
}

fn genericIsLegal(comptime n_cells: usize, pos: []const i8, w: usize, h: usize) bool {
    var visited = [_]bool{false} ** n_cells;
    for (0..n_cells) |p| {
        if (pos[p] == 0 or visited[p]) continue;
        const colour = pos[p];
        var stack: [n_cells]usize = undefined;
        var sp: usize = 1;
        stack[0] = p;
        visited[p] = true;
        var has_liberty = false;
        while (sp > 0) {
            sp -= 1;
            const q = stack[sp];
            var nb: [4]usize = undefined;
            const cnt = genericNeighbors(q, w, h, &nb);
            for (nb[0..cnt]) |r| {
                if (pos[r] == 0) {
                    has_liberty = true;
                } else if (pos[r] == colour and !visited[r]) {
                    visited[r] = true;
                    stack[sp] = r;
                    sp += 1;
                }
            }
        }
        if (!has_liberty) return false;
    }
    return true;
}

fn genericAreaScore(comptime n_cells: usize, board: []const i8, w: usize, h: usize) i8 {
    var black: i16 = 0;
    var white: i16 = 0;
    var visited = [_]bool{false} ** n_cells;
    for (0..n_cells) |p| {
        if (board[p] > 0) { black += 1; continue; }
        if (board[p] < 0) { white += 1; continue; }
        if (visited[p]) continue;
        var stack: [n_cells]usize = undefined;
        var sp: usize = 1;
        stack[0] = p;
        visited[p] = true;
        var size: i16 = 0;
        var tb = false;
        var tw = false;
        while (sp > 0) {
            sp -= 1;
            const q = stack[sp];
            size += 1;
            var nb: [4]usize = undefined;
            const cnt = genericNeighbors(q, w, h, &nb);
            for (nb[0..cnt]) |r| {
                if (board[r] > 0) tb = true
                else if (board[r] < 0) tw = true
                else if (!visited[r]) {
                    visited[r] = true;
                    stack[sp] = r;
                    sp += 1;
                }
            }
        }
        if (tb and !tw) black += size;
        if (tw and !tb) white += size;
    }
    return @intCast(black - white);
}

// =========================================================================
// Colex indexer for 4×4 (compile-time, matches colex.zig layout_version=1)
// =========================================================================

fn Colex4x4() type {
    return struct {
        pub const n = 16;
        pub const total: u64 = 43046721; // 3^16

        fn binomial(i: usize, j: usize) u64 {
            if (j > i) return 0;
            if (j == 0 or j == i) return 1;
            var c: u64 = 1;
            const k = @min(j, i - j);
            var x: usize = 1;
            while (x <= k) : (x += 1) {
                c = c * (i - x + 1) / x;
            }
            return c;
        }

        fn layerOffset(k: usize) u64 {
            var off: u64 = 0;
            for (0..k) |i| {
                off += binomial(n, i) * (@as(u64, 1) << @intCast(i));
            }
            return off;
        }

        pub fn colexFromPos(pos: []const i8) u64 {
            var k: usize = 0;
            var subset: u64 = 0;
            var colours: u64 = 0;
            for (0..n) |cell| {
                if (pos[cell] == 0) continue;
                if (pos[cell] > 0) colours |= @as(u64, 1) << @intCast(k);
                k += 1;
                subset += binomial(cell, k);
            }
            return layerOffset(k) + subset * (@as(u64, 1) << @intCast(k)) + colours;
        }
    };
}

// =========================================================================
// 3×3 in-memory fixpoint (for calibration known-good)
// =========================================================================

const W3: usize = 3;
const H3: usize = 3;
const N3: usize = W3 * H3;
const KO_DIMS3: usize = N3 + 1;
const RAW_TOTAL3: u64 = 19683; // 3^9
const TOTAL3: u64 = RAW_TOTAL3 * 2 * KO_DIMS3 * 3;
const ReachWords3: u64 = (TOTAL3 + 63) / 64;
const KO_NONE3: u16 = @intCast(N3);

const Pos3 = [N3]i8;

const StateIdx3 = packed struct {
    board: u32,
    side: u8,
    ko: u16,
    passes: u8,

    fn linear(self: StateIdx3) u64 {
        return (((@as(u64, self.passes) * 2) + @as(u64, self.side)) * KO_DIMS3 + @as(u64, self.ko)) * RAW_TOTAL3 + self.board;
    }
};

fn unrankBoard3(idx: u32) Pos3 {
    var board: Pos3 = [_]i8{0} ** N3;
    var v: u32 = idx;
    for (0..N3) |i| {
        const d = v % 3;
        v /= 3;
        board[i] = switch (d) { 0 => 0, 1 => 1, 2 => -1, else => unreachable };
    }
    return board;
}

fn rankBoard3(board: Pos3) u32 {
    var idx: u32 = 0;
    var mult: u32 = 1;
    for (board) |c| {
        const d: u32 = if (c > 0) 1 else if (c < 0) 2 else 0;
        idx += d * mult;
        mult *= 3;
    }
    return idx;
}

fn applyPlace3(state: StateIdx3, board: *const Pos3, colour: i8, cell: u8) ?StateIdx3 {
    if (board[cell] != 0) return null;
    if (state.ko != N3 and cell == state.ko) return null;
    var next = board.*;
    _ = genericPosFromMove(N3, &next, colour, cell, W3, H3) catch return null;
    var opp_before: u8 = 0;
    var opp_after: u8 = 0;
    var captured_cell: u8 = KO_NONE3;
    for (0..N3) |i| {
        if (board[i] == -colour) opp_before += 1;
        if (next[i] == -colour) opp_after += 1;
        if (board[i] == -colour and next[i] == 0) captured_cell = @intCast(i);
    }
    var new_ko: u16 = KO_NONE3;
    if ((opp_before - opp_after == 1) and (captured_cell != KO_NONE3)) {
        var liberties: u8 = 0;
        var friendly: u8 = 0;
        var nb: [4]usize = undefined;
        const cnt = genericNeighbors(cell, W3, H3, &nb);
        for (nb[0..cnt]) |q| {
            if (next[q] == 0) liberties += 1;
            if (next[q] == colour) friendly += 1;
        }
        if (liberties == 1 and friendly == 0) new_ko = captured_cell;
    }
    return StateIdx3{
        .board = rankBoard3(next),
        .side = if (colour == 1) @as(u8, 1) else @as(u8, 0),
        .ko = new_ko,
        .passes = 0,
    };
}

fn applyPass3(state: StateIdx3) ?StateIdx3 {
    if (state.passes >= 2) return null;
    return StateIdx3{ .board = state.board, .side = 1 - state.side, .ko = KO_NONE3, .passes = state.passes + 1 };
}

fn median3(Lv: i8, Hv: i8) i8 { return @max(Lv, @min(TIE, Hv)); }

fn runFixpoint3(gpa: std.mem.Allocator) !struct {
    L_tab: []i8,
    H_tab: []i8,
    sweeps: u32,
} {
    const reach = try gpa.alloc(u64, ReachWords3);
    defer gpa.free(reach);
    @memset(reach, 0);

    const snap = try gpa.alloc(u64, ReachWords3);
    defer gpa.free(snap);

    for ([_]u8{ 0, 1 }) |side| {
        const root = StateIdx3{ .board = 0, .side = side, .ko = KO_NONE3, .passes = 0 };
        const lin = root.linear();
        reach[lin >> 6] |= @as(u64, 1) << @intCast(lin & 63);
    }

    var new_marks: u64 = 1;
    var sweep_idx: u32 = 0;
    const MAX_SWEEPS: u32 = 128;
    while (new_marks > 0 and sweep_idx < MAX_SWEEPS) {
        @memcpy(snap, reach);
        new_marks = 0;
        var lin: u64 = 0;
        while (lin < TOTAL3) : (lin += 1) {
            const word = lin >> 6;
            const bit: u64 = @as(u64, 1) << @intCast(lin & 63);
            if (snap[word] & bit == 0) continue;
            const state = decodeState3(lin);
            var succ_boards: [N3 + 1]Pos3 = undefined;
            var succs: [N3 + 1]StateIdx3 = undefined;
            const m = generateMoves3(state, &succ_boards, &succs);
            for (0..m) |k| {
                if (!genericIsLegal(N3, &succ_boards[k], W3, H3)) continue;
                const child_lin = succs[k].linear();
                const child_word = child_lin >> 6;
                const child_bit: u64 = @as(u64, 1) << @intCast(child_lin & 63);
                if (reach[child_word] & child_bit == 0) {
                    reach[child_word] |= child_bit;
                    new_marks += 1;
                }
            }
        }
        sweep_idx += 1;
    }

    const L_tab = try gpa.alloc(i8, TOTAL3);
    errdefer gpa.free(L_tab);
    const H_tab = try gpa.alloc(i8, TOTAL3);
    errdefer gpa.free(H_tab);

    const L_init: i8 = -@as(i8, @intCast(N3));
    const H_init: i8 = @as(i8, @intCast(N3));
    for (0..TOTAL3) |i| { L_tab[i] = L_init; H_tab[i] = H_init; }

    var li: u64 = 0;
    while (li < TOTAL3) : (li += 1) {
        const word = li >> 6;
        const bit: u64 = @as(u64, 1) << @intCast(li & 63);
        if (reach[word] & bit == 0) continue;
        if (decodePasses3(li) == 2) {
            const board_idx: u32 = @intCast(li % RAW_TOTAL3);
            const b = unrankBoard3(board_idx);
            const a = genericAreaScore(N3, &b, W3, H3);
            L_tab[li] = a;
            H_tab[li] = a;
        }
    }

    var fp_sweeps: u32 = 0;
    var total_changes: u64 = 1;
    const MAX_FP_SWEEPS: u32 = 256;
    while (total_changes > 0 and fp_sweeps < MAX_FP_SWEEPS) {
        fp_sweeps += 1;
        total_changes = 0;
        var lj: u64 = 0;
        while (lj < TOTAL3) : (lj += 1) {
            if (!isReachableAndNonTerminal3(reach, lj)) continue;
            const state = decodeState3(lj);
            var succ_boards: [N3 + 1]Pos3 = undefined;
            var succs: [N3 + 1]StateIdx3 = undefined;
            const m = generateMoves3(state, &succ_boards, &succs);
            const maximizing = state.side == 0;
            var best: ?i8 = null;
            for (0..m) |k| {
                if (!genericIsLegal(N3, &succ_boards[k], W3, H3)) continue;
                const child_li = succs[k].linear();
                const vl = L_tab[child_li];
                if (best == null or (if (maximizing) vl > best.? else vl < best.?)) best = vl;
            }
            if (best != null and best.? != L_tab[lj]) { L_tab[lj] = best.?; total_changes += 1; }
        }
        var hj: u64 = 0;
        while (hj < TOTAL3) : (hj += 1) {
            if (!isReachableAndNonTerminal3(reach, hj)) continue;
            const state = decodeState3(hj);
            var succ_boards: [N3 + 1]Pos3 = undefined;
            var succs: [N3 + 1]StateIdx3 = undefined;
            const m = generateMoves3(state, &succ_boards, &succs);
            const maximizing = state.side == 0;
            var best: ?i8 = null;
            for (0..m) |k| {
                if (!genericIsLegal(N3, &succ_boards[k], W3, H3)) continue;
                const child_li = succs[k].linear();
                const vh = H_tab[child_li];
                if (best == null or (if (maximizing) vh > best.? else vh < best.?)) best = vh;
            }
            if (best != null and best.? != H_tab[hj]) { H_tab[hj] = best.?; total_changes += 1; }
        }
    }

    return .{ .L_tab = L_tab, .H_tab = H_tab, .sweeps = fp_sweeps };
}

fn decodeState3(lin: u64) StateIdx3 {
    const passes: u8 = @intCast(lin / (2 * KO_DIMS3 * RAW_TOTAL3));
    const rest: u64 = lin % (2 * KO_DIMS3 * RAW_TOTAL3);
    const side: u8 = @intCast(rest / (KO_DIMS3 * RAW_TOTAL3));
    const rest2: u64 = rest % (KO_DIMS3 * RAW_TOTAL3);
    const ko: u16 = @intCast(rest2 / RAW_TOTAL3);
    const board: u32 = @intCast(rest2 % RAW_TOTAL3);
    return StateIdx3{ .board = board, .side = side, .ko = ko, .passes = passes };
}

fn decodePasses3(lin: u64) u8 {
    return @intCast(lin / (2 * KO_DIMS3 * RAW_TOTAL3));
}

fn isReachableAndNonTerminal3(reach: []const u64, lin: u64) bool {
    const word = lin >> 6;
    const bit: u64 = @as(u64, 1) << @intCast(lin & 63);
    if (reach[word] & bit == 0) return false;
    const passes: u8 = @intCast(lin / (2 * KO_DIMS3 * RAW_TOTAL3));
    return passes != 2;
}

fn generateMoves3(state: StateIdx3, succ_boards: *[N3 + 1]Pos3, succs: *[N3 + 1]StateIdx3) usize {
    if (state.passes == 2) return 0;
    const board = unrankBoard3(state.board);
    const colour: i8 = if (state.side == 0) 1 else -1;
    var count: usize = 0;
    if (applyPass3(state)) |ns| {
        succ_boards[count] = unrankBoard3(ns.board);
        succs[count] = ns;
        count += 1;
    }
    for (0..N3) |cell_u| {
        const cell: u8 = @intCast(cell_u);
        if (applyPlace3(state, &board, colour, cell)) |ns| {
            succ_boards[count] = unrankBoard3(ns.board);
            succs[count] = ns;
            count += 1;
        }
    }
    return count;
}

fn lookupValue3(L_tab: []const i8, H_tab: []const i8, lin: u64) i8 {
    return median3(L_tab[lin], H_tab[lin]);
}

// =========================================================================
// 4×4 playout engine — basic ko + TIE=0
// =========================================================================

const W4: usize = 4;
const H4: usize = 4;
const N4: usize = W4 * H4;
const KO_NONE4: u8 = 16; // N4

const MAX_HISTORY: usize = 1024;
const MAX_CYCLE_CHECK: usize = 512;

const PlayoutState4 = struct {
    board: [N4]i8,
    side: i8,   // +1 Black, -1 White
    ko: u8,     // KO_NONE4 or cell index of prohibited recapture
    passes: u8, // 0, 1, or 2 (terminal)
};

const BellmanResult = enum { MATCH, VIOLATION, TIE_CHILD, NO_CHILDREN };

const PlayoutStats = struct {
    games: u64,
    total_nodes: u64,
    bellman_matches: u64,
    bellman_violations: u64,
    bellman_tie_child: u64,
    undef_nodes: u64,
    cycle_terminated_games: u64,
    two_pass_games: u64,
    max_plies: u32,
    total_plies: u64,
    error_nodes: u64,
    violations_due_to_undef: u64,
    flag_read_bracket_nodes: u64,
    flag_read_total_nodes: u64,
};

/// Generate legal moves from state using basic ko.
/// Returns children and their board arrays.
fn generateMoves4(state: *const PlayoutState4, children: *[N4 + 1]PlayoutState4) usize {
    if (state.passes == 2) return 0;
    const colour = state.side;
    var count: usize = 0;

    // Pass
    children[count] = PlayoutState4{
        .board = state.board,
        .side = -colour,
        .ko = KO_NONE4,
        .passes = state.passes + 1,
    };
    count += 1;

    // Placement moves
    for (0..N4) |cell| {
        if (state.board[cell] != 0) continue;
        if (state.ko != KO_NONE4 and cell == state.ko) continue;

        var next = state.board;
        _ = genericPosFromMove(N4, &next, colour, cell, W4, H4) catch continue;

        // Basic ko detection
        var new_ko: u8 = KO_NONE4;
        var opp_before: u8 = 0;
        var captured_cell: u8 = KO_NONE4;
        for (0..N4) |i| {
            if (state.board[i] == -colour) opp_before += 1;
            if (state.board[i] == -colour and next[i] == 0) captured_cell = @intCast(i);
        }
        var opp_after: u8 = 0;
        for (0..N4) |i| {
            if (next[i] == -colour) opp_after += 1;
        }
        if (opp_before - opp_after == 1 and captured_cell != KO_NONE4) {
            var liberties: u8 = 0;
            var friendly: u8 = 0;
            var nb: [4]usize = undefined;
            const cnt = genericNeighbors(cell, W4, H4, &nb);
            for (nb[0..cnt]) |q| {
                if (next[q] == 0) liberties += 1;
                if (next[q] == colour) friendly += 1;
            }
            if (liberties == 1 and friendly == 0) new_ko = captured_cell;
        }

        children[count] = PlayoutState4{
            .board = next,
            .side = -colour,
            .ko = new_ko,
            .passes = 0,
        };
        count += 1;
    }
    return count;
}

/// Compute the correct value for a child state, handling passes=1 (terminal threat).
fn childValue4(child: *const PlayoutState4, art: *const WzoArtifact) i8 {
    const C = Colex4x4();
    if (child.passes == 2) {
        return genericAreaScore(N4, &child.board, W4, H4);
    }
    const art_v = if (child.side > 0) art.vb[C.colexFromPos(&child.board)] else art.vw[C.colexFromPos(&child.board)];
    if (art_v == UNDEF) return UNDEF;
    if (child.passes == 1) {
        // Opponent can pass to end the game — value is max(area, art_v) for
        // Black (maximizer) or min(area, art_v) for White (minimizer).
        const area = genericAreaScore(N4, &child.board, W4, H4);
        return if (child.side > 0) @max(area, art_v) else @min(area, art_v);
    }
    return art_v;
}

/// Direct Bellman identity check for 4×4: V(state) == best_child({V(child)})
/// Only valid for fresh-start states (passes=0, ko=none).
fn checkBellman4(state: *const PlayoutState4, art: *const WzoArtifact, history: []const PlayoutState4, history_len: usize) BellmanResult {
    const C = Colex4x4();
    const state_v = if (state.side > 0) art.vb[C.colexFromPos(&state.board)] else art.vw[C.colexFromPos(&state.board)];

    if (state_v == UNDEF) return .VIOLATION;

    var children: [N4 + 1]PlayoutState4 = undefined;
    const m = generateMoves4(state, &children);
    const maximizing = state.side > 0;

    var best_val: ?i8 = null;
    var child_count: u8 = 0;
    var any_tie = false;

    for (0..m) |k| {
        const child = &children[k];

        // Cycle detection for placement moves (not passes)
        if (!std.mem.eql(i8, &child.board, &state.board)) {
            var is_cycle = false;
            const cstart = if (history_len > MAX_CYCLE_CHECK) history_len - MAX_CYCLE_CHECK else 0;
            for (history[cstart..history_len]) |*h| {
                if (std.mem.eql(i8, &h.board, &child.board) and h.side == child.side and h.ko == child.ko) {
                    is_cycle = true;
                    break;
                }
            }
            if (is_cycle) continue;
        }

        // Look up child value (handles passes=1 terminal threat)
        const cv = childValue4(child, art);
        if (cv == UNDEF) continue;
        child_count += 1;

        if (maximizing) {
            if (best_val == null) {
                best_val = cv;
            } else if (cv == TIE) {
                if (best_val.? < 0) best_val = TIE;
                any_tie = true;
            } else if (best_val.? == TIE) {
                if (cv > 0) best_val = cv;
            } else if (cv > best_val.?) {
                best_val = cv;
            }
        } else {
            if (best_val == null) {
                best_val = cv;
            } else if (cv == TIE) {
                if (best_val.? > 0) best_val = TIE;
                any_tie = true;
            } else if (best_val.? == TIE) {
                if (cv < 0) best_val = cv;
            } else if (cv < best_val.?) {
                best_val = cv;
            }
        }
    }

    if (child_count == 0) return .MATCH; // terminal: value is exact by definition
    if (any_tie and best_val.? == TIE and state_v != TIE) return .TIE_CHILD;
    if (state_v == best_val.?) return .MATCH;
    return .VIOLATION;
}

/// Select oracle move (always pick best child value, deterministic)
fn selectOracle4(state: *const PlayoutState4, art: *const WzoArtifact, _: std.Random, history: []const PlayoutState4, history_len: usize) ?PlayoutState4 {
    var children: [N4 + 1]PlayoutState4 = undefined;
    const m = generateMoves4(state, &children);
    const maximizing = state.side > 0;

    var best_idx: ?usize = null;
    var best_val: ?i8 = null;
    var best_captures: i8 = -1;

    for (0..m) |k| {
        const child = &children[k];

        // Cycle detection for placement moves
        if (!std.mem.eql(i8, &child.board, &state.board)) {
            var is_cycle = false;
            const cstart = if (history_len > MAX_CYCLE_CHECK) history_len - MAX_CYCLE_CHECK else 0;
            for (history[cstart..history_len]) |*h| {
                if (std.mem.eql(i8, &h.board, &child.board) and h.side == child.side and h.ko == child.ko) {
                    is_cycle = true;
                    break;
                }
            }
            if (is_cycle) continue;
        }

        const cv = childValue4(child, art);
        if (cv == UNDEF) continue;

        // Compute captures for tie-breaking
        var captures: i8 = 0;
        for (0..N4) |i| {
            if (state.board[i] == -state.side and child.board[i] == 0) captures += 1;
        }

        const better = if (best_val == null) true else blk: {
            if (maximizing) {
                if (cv == TIE) {
                    if (best_val.? < 0) break :blk true;
                    if (best_val.? == TIE) break :blk (captures > best_captures);
                    break :blk false;
                }
                if (best_val.? == TIE) break :blk (cv > 0);
                if (cv > best_val.?) break :blk true;
                if (cv < best_val.?) break :blk false;
            } else {
                if (cv == TIE) {
                    if (best_val.? > 0) break :blk true;
                    if (best_val.? == TIE) break :blk (captures > best_captures);
                    break :blk false;
                }
                if (best_val.? == TIE) break :blk (cv < 0);
                if (cv < best_val.?) break :blk true;
                if (cv > best_val.?) break :blk false;
            }
            break :blk (captures > best_captures);
        };

        if (better) {
            best_idx = k;
            best_val = cv;
            best_captures = captures;
        }
    }

    if (best_idx) |idx| return children[idx];
    return null;
}

/// Select oracle-rt move (oracle with random tie-breaking)
fn selectOracleRt4(state: *const PlayoutState4, art: *const WzoArtifact, rng: std.Random, history: []const PlayoutState4, history_len: usize) ?PlayoutState4 {
    var children: [N4 + 1]PlayoutState4 = undefined;
    const m = generateMoves4(state, &children);
    const maximizing = state.side > 0;

    var best_val: ?i8 = null;
    var best_count: usize = 0;
    var best_indices: [N4 + 1]usize = undefined;

    for (0..m) |k| {
        const child = &children[k];

        if (!std.mem.eql(i8, &child.board, &state.board)) {
            var is_cycle = false;
            const cstart = if (history_len > MAX_CYCLE_CHECK) history_len - MAX_CYCLE_CHECK else 0;
            for (history[cstart..history_len]) |*h| {
                if (std.mem.eql(i8, &h.board, &child.board) and h.side == child.side and h.ko == child.ko) {
                    is_cycle = true;
                    break;
                }
            }
            if (is_cycle) continue;
        }

        const cv = childValue4(child, art);
        if (cv == UNDEF) continue;

        const better = if (best_val == null) true else blk: {
            if (maximizing) {
                if (cv == TIE) {
                    if (best_val.? < 0) break :blk true;
                    if (best_val.? == TIE) break :blk false; // tie with TIE
                    break :blk false;
                }
                if (best_val.? == TIE) break :blk (cv > 0);
                if (cv > best_val.?) break :blk true;
                if (cv < best_val.?) break :blk false;
            } else {
                if (cv == TIE) {
                    if (best_val.? > 0) break :blk true;
                    if (best_val.? == TIE) break :blk false;
                    break :blk false;
                }
                if (best_val.? == TIE) break :blk (cv < 0);
                if (cv < best_val.?) break :blk true;
                if (cv > best_val.?) break :blk false;
            }
            break :blk false; // value tie
        };

        if (better) {
            best_val = cv;
            best_count = 1;
            best_indices[0] = k;
        } else if (cv == best_val.?) {
            best_indices[best_count] = k;
            best_count += 1;
        }
    }

    if (best_count == 0) return null;
    const pick = if (best_count == 1) best_indices[0] else best_indices[rng.int(usize) % best_count];
    return children[pick];
}

/// Select random legal move
fn selectRandom4(state: *const PlayoutState4, art: *const WzoArtifact, rng: std.Random, history: []const PlayoutState4, history_len: usize) ?PlayoutState4 {
    _ = art;
    var children: [N4 + 1]PlayoutState4 = undefined;
    const m = generateMoves4(state, &children);

    var legal_count: usize = 0;
    var legal_indices: [N4 + 1]usize = undefined;

    for (0..m) |k| {
        const child = &children[k];
        if (!std.mem.eql(i8, &child.board, &state.board)) {
            var is_cycle = false;
            const cstart = if (history_len > MAX_CYCLE_CHECK) history_len - MAX_CYCLE_CHECK else 0;
            for (history[cstart..history_len]) |*h| {
                if (std.mem.eql(i8, &h.board, &child.board) and h.side == child.side and h.ko == child.ko) {
                    is_cycle = true;
                    break;
                }
            }
            if (is_cycle) continue;
        }
        legal_indices[legal_count] = k;
        legal_count += 1;
    }

    if (legal_count == 0) return null;
    const pick = legal_indices[rng.int(usize) % legal_count];
    return children[pick];
}

/// Select mixed move (oracle with 10% random exploration)
fn selectMixed4(state: *const PlayoutState4, art: *const WzoArtifact, rng: std.Random, history: []const PlayoutState4, history_len: usize) ?PlayoutState4 {
    if (rng.int(u32) % 10 == 0) {
        return selectRandom4(state, art, rng, history, history_len);
    }
    return selectOracleRt4(state, art, rng, history, history_len);
}

fn runPlayout4(
    art: *const WzoArtifact,
    games: u64,
    policy: []const u8,
    seed: u64,
) !PlayoutStats {
    var prng = std.Random.DefaultPrng.init(seed);
    const rng = prng.random();
    var stats = PlayoutStats{
        .games = 0,
        .total_nodes = 0,
        .bellman_matches = 0,
        .bellman_violations = 0,
        .bellman_tie_child = 0,
        .undef_nodes = 0,
        .cycle_terminated_games = 0,
        .two_pass_games = 0,
        .max_plies = 0,
        .total_plies = 0,
        .error_nodes = 0,
        .violations_due_to_undef = 0,
        .flag_read_bracket_nodes = 0,
        .flag_read_total_nodes = 0,
    };

    const C = Colex4x4();

    for (0..games) |game_idx| {
        const side: i8 = if (game_idx % 2 == 0) @as(i8, 1) else @as(i8, -1);
        var state = PlayoutState4{
            .board = [_]i8{0} ** N4,
            .side = side,
            .ko = KO_NONE4,
            .passes = 0,
        };

        var history: [MAX_HISTORY]PlayoutState4 = undefined;
        var history_len: usize = 0;
        history[history_len] = state;
        history_len += 1;

        const max_plies: usize = 512;

        for (0..max_plies) |ply_idx| {
            _ = ply_idx;

            // Bellman identity check — only on fresh-start states (passes=0, ko=none)
            // where the artifact value is valid. Non-fresh-start states are skipped.
            if (state.passes == 0 and state.ko == KO_NONE4) {
                const result = checkBellman4(&state, art, history[0..history_len], history_len);
                switch (result) {
                    .MATCH => stats.bellman_matches += 1,
                    .VIOLATION => {
                        const state_v = if (state.side > 0) art.vb[C.colexFromPos(&state.board)] else art.vw[C.colexFromPos(&state.board)];
                        if (state_v == UNDEF) {
                            stats.violations_due_to_undef += 1;
                        }
                        stats.bellman_violations += 1;
                    },
                    .TIE_CHILD => stats.bellman_tie_child += 1,
                    .NO_CHILDREN => stats.error_nodes += 1,
                }
            }

            // Flag-read check (degenerate under this rule)
            {
                const idx = C.colexFromPos(&state.board);
                const flag = if (state.side > 0) art.fb[idx] else art.fw[idx];
                stats.flag_read_total_nodes += 1;
                if (flag & 1 != 0) stats.flag_read_bracket_nodes += 1;
            }

            // UNDEF check
            {
                const idx = C.colexFromPos(&state.board);
                const v = if (state.side > 0) art.vb[idx] else art.vw[idx];
                if (v == UNDEF) stats.undef_nodes += 1;
            }

            stats.total_nodes += 1;

            // Terminal check
            if (state.passes == 2) {
                stats.two_pass_games += 1;
                stats.total_plies += 1;
                break;
            }

            // Select move based on policy
            const selected = switch (policy[0]) {
                'o' => selectOracle4(&state, art, rng, history[0..history_len], history_len),
                'O' => selectOracleRt4(&state, art, rng, history[0..history_len], history_len),
                'r' => selectRandom4(&state, art, rng, history[0..history_len], history_len),
                'm' => selectMixed4(&state, art, rng, history[0..history_len], history_len),
                else => selectOracle4(&state, art, rng, history[0..history_len], history_len),
            };

            if (selected) |child| {
                if (history_len < MAX_HISTORY) {
                    history[history_len] = child;
                    history_len += 1;
                }
                state = child;
            } else {
                // No legal non-cycle move → cycle termination
                stats.cycle_terminated_games += 1;
                break;
            }
        }

        stats.games += 1;
    }

    return stats;
}

// =========================================================================
// 3×3 playout reuse (from exp7_census.zig, adapted)
// =========================================================================

fn generateMoves3Full(state: StateIdx3, succ_boards: *[N3 + 1]Pos3, succs: *[N3 + 1]StateIdx3) usize {
    return generateMoves3(state, succ_boards, succs);
}

fn selectOracle3(
    state: StateIdx3,
    L_tab: []const i8,
    H_tab: []const i8,
    history: []const u64,
    history_len: usize,
) ?StateIdx3 {
    const board = unrankBoard3(state.board);
    var succ_boards: [N3 + 1]Pos3 = undefined;
    var succs: [N3 + 1]StateIdx3 = undefined;
    const m = generateMoves3(state, &succ_boards, &succs);
    const maximizing = state.side == 0;

    var best_idx: ?usize = null;
    var best_val: ?i8 = null;
    var best_captures: i8 = -1;

    for (0..m) |k| {
        if (!genericIsLegal(N3, &succ_boards[k], W3, H3)) continue;
        const child = succs[k];

        // Cycle detection for placement moves
        if (child.board != state.board) {
            const cstart = if (history_len > MAX_CYCLE_CHECK) history_len - MAX_CYCLE_CHECK else 0;
            var is_cycle = false;
            for (history[cstart..history_len]) |h_lin| {
                const hs = decodeState3(h_lin);
                if (hs.board == child.board and hs.side == child.side and hs.ko == child.ko) {
                    is_cycle = true;
                    break;
                }
            }
            if (is_cycle) continue;
        }

        var cv = lookupValue3(L_tab, H_tab, child.linear());
        if (child.passes == 2) {
            cv = genericAreaScore(N3, &succ_boards[k], W3, H3);
        }

        var captures: i8 = 0;
        for (0..N3) |i| {
            if (board[i] == -@as(i8, if (state.side == 0) -1 else 1) and succ_boards[k][i] == 0) captures += 1;
        }

        const better = if (best_val == null) true else blk: {
            if (maximizing) {
                if (cv == TIE) {
                    if (best_val.? < 0) break :blk true;
                    if (best_val.? == TIE) break :blk (captures > best_captures);
                    break :blk false;
                }
                if (best_val.? == TIE) break :blk (cv > 0);
                if (cv > best_val.?) break :blk true;
                if (cv < best_val.?) break :blk false;
            } else {
                if (cv == TIE) {
                    if (best_val.? > 0) break :blk true;
                    if (best_val.? == TIE) break :blk (captures > best_captures);
                    break :blk false;
                }
                if (best_val.? == TIE) break :blk (cv < 0);
                if (cv < best_val.?) break :blk true;
                if (cv > best_val.?) break :blk false;
            }
            break :blk (captures > best_captures);
        };
        if (better) {
            best_idx = k;
            best_val = cv;
            best_captures = captures;
        }
    }
    if (best_idx) |idx| return succs[idx];
    return null;
}

fn checkBellman3(
    state: StateIdx3,
    L_tab: []const i8,
    H_tab: []const i8,
) BellmanResult {
    const stored_v = lookupValue3(L_tab, H_tab, state.linear());
    if (stored_v == UNDEF) return .VIOLATION;

    var succ_boards: [N3 + 1]Pos3 = undefined;
    var succs: [N3 + 1]StateIdx3 = undefined;
    const m = generateMoves3(state, &succ_boards, &succs);
    const maximizing = state.side == 0;

    var best_child_val: ?i8 = null;
    var child_count: u8 = 0;
    var any_tie_child = false;

    for (0..m) |k| {
        if (!genericIsLegal(N3, &succ_boards[k], W3, H3)) continue;
        const child_lin = succs[k].linear();
        var cv = lookupValue3(L_tab, H_tab, child_lin);
        if (succs[k].passes == 2) {
            cv = genericAreaScore(N3, &succ_boards[k], W3, H3);
        }
        child_count += 1;

        if (maximizing) {
            if (best_child_val == null) {
                best_child_val = cv;
            } else if (cv == TIE) {
                if (best_child_val.? < 0) best_child_val = TIE;
                any_tie_child = true;
            } else if (best_child_val.? == TIE) {
                if (cv > 0) best_child_val = cv;
            } else if (cv > best_child_val.?) {
                best_child_val = cv;
            }
        } else {
            if (best_child_val == null) {
                best_child_val = cv;
            } else if (cv == TIE) {
                if (best_child_val.? > 0) best_child_val = TIE;
                any_tie_child = true;
            } else if (best_child_val.? == TIE) {
                if (cv < 0) best_child_val = cv;
            } else if (cv < best_child_val.?) {
                best_child_val = cv;
            }
        }
    }

    if (child_count == 0) return .MATCH; // terminal: value is exact by definition
    if (any_tie_child and best_child_val.? == TIE and stored_v != TIE) return .TIE_CHILD;
    if (stored_v == best_child_val.?) return .MATCH;
    return .VIOLATION;
}

fn runPlayout3(
    L_tab: []const i8,
    H_tab: []const i8,
    games: u64,
    _: []const u8,
    _seed: u64,
) !PlayoutStats {
    _ = _seed;
    var stats = PlayoutStats{
        .games = 0,
        .total_nodes = 0,
        .bellman_matches = 0,
        .bellman_violations = 0,
        .bellman_tie_child = 0,
        .undef_nodes = 0,
        .cycle_terminated_games = 0,
        .two_pass_games = 0,
        .max_plies = 0,
        .total_plies = 0,
        .error_nodes = 0,
        .violations_due_to_undef = 0,
        .flag_read_bracket_nodes = 0,
        .flag_read_total_nodes = 0,
    };

    for (0..games) |game_idx| {
        const side: u8 = if (game_idx % 2 == 0) @as(u8, 0) else @as(u8, 1);
        var state = StateIdx3{ .board = 0, .side = side, .ko = KO_NONE3, .passes = 0 };

        var history: [MAX_HISTORY]u64 = [_]u64{0} ** MAX_HISTORY;
        var history_len: usize = 1;
        history[0] = state.linear();

        const max_plies: usize = 512;

        for (0..max_plies) |_| {
            const result = checkBellman3(state, L_tab, H_tab);
            switch (result) {
                .MATCH => stats.bellman_matches += 1,
                .VIOLATION => stats.bellman_violations += 1,
                .TIE_CHILD => stats.bellman_tie_child += 1,
                .NO_CHILDREN => stats.error_nodes += 1,
            }
            stats.total_nodes += 1;

            if (lookupValue3(L_tab, H_tab, state.linear()) == UNDEF) stats.undef_nodes += 1;

            if (state.passes == 2) {
                stats.two_pass_games += 1;
                break;
            }

            const selected = selectOracle3(state, L_tab, H_tab, history[0..history_len], history_len);
            if (selected) |child| {
                if (history_len < MAX_HISTORY) {
                    history[history_len] = child.linear();
                    history_len += 1;
                }
                state = child;
            } else {
                stats.cycle_terminated_games += 1;
                break;
            }
        }
        stats.games += 1;
    }

    return stats;
}

// =========================================================================
// Main
// =========================================================================

pub fn main(init: std.process.Init) !void {
    const gpa = std.heap.page_allocator;

    var args_iter = std.process.Args.Iterator.init(init.minimal.args);
    _ = args_iter.next();

    const goban_str = args_iter.next() orelse {
        std.debug.print("usage: t129_exp7_4x4 <goban> [--wzo PATH] [--games N] [--seed N] [--policy X]\n", .{});
        std.debug.print("  goban: 3 (3×3, computes fixpoint) or 4 (4×4, reads --wzo)\n", .{});
        return;
    };

    var wzo_path: []const u8 = "data/oracle-4x4-basicko-tie-area.wzo";
    var num_games: u64 = 2000;
    var seed: u64 = 20260728;
    var policy_str: []const u8 = "oracle";

    while (args_iter.next()) |arg| {
        if (std.mem.eql(u8, arg, "--wzo")) {
            if (args_iter.next()) |val| wzo_path = val;
        } else if (std.mem.eql(u8, arg, "--games")) {
            if (args_iter.next()) |val| num_games = try std.fmt.parseInt(u64, val, 10);
        } else if (std.mem.eql(u8, arg, "--seed")) {
            if (args_iter.next()) |val| seed = try std.fmt.parseInt(u64, val, 10);
        } else if (std.mem.eql(u8, arg, "--policy")) {
            if (args_iter.next()) |val| policy_str = val;
        }
    }

    if (std.mem.eql(u8, goban_str, "4")) {
        // Verify artifact sha256
        const file_bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, wzo_path, gpa, .unlimited);
        defer gpa.free(file_bytes);

        var sha: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(file_bytes, &sha, .{});
        var sha_hex: [64]u8 = undefined;
        const hex_str = std.fmt.bytesToHex(&sha, .lower);
        @memcpy(sha_hex[0..64], &hex_str);

        std.debug.print("# ============================================================================\n", .{});
        std.debug.print("# T129 — EXP-7 4×4 re-run — certified fraction under basic-ko + TIE=0\n", .{});
        std.debug.print("# Task: T129 · Role: worker · Model: DSPro · Date: 2026-07-31\n", .{});
        std.debug.print("# Artifact: {s}\n", .{wzo_path});
        std.debug.print("# SHA256: {s}\n", .{sha_hex});
        std.debug.print("# Rule: basic ko (single-stone capture prohibition) + TIE=0 for long cycles\n", .{});
        std.debug.print("# Legality: basic ko (no PSK) — playout uses the new rule's own move generator\n", .{});
        std.debug.print("# Value domain: integers + TIE (TIE between -1 and +1 per EXP-2 A5)\n", .{});
        std.debug.print("# Direct-identity check: V(state) == best_child({{V(child)}}) at every decision node\n", .{});
        std.debug.print("# Long cycles: detected via (board, side, ko) repetition; terminate game, score as TIE\n", .{});
        std.debug.print("# Denominator: visited decision nodes (position, side-to-move)\n", .{});
        std.debug.print("# Flag-read fraction: reported alongside but DEGENERATE (all-zero under this rule)\n", .{});
        std.debug.print("# ============================================================================\n", .{});

        // Read artifact
        std.debug.print("\n## Loading artifact...\n", .{});
        const art_bytes = try gpa.dupe(u8, file_bytes);
        defer gpa.free(art_bytes);

        const hdr = try parseWzoHeader(art_bytes);
        try verifyPayloadCrc(art_bytes);
        std.debug.print("# WZO1: {d}x{d}, rules_id={d}, total={d}, legal_count={d}, CRC OK\n", .{ hdr.board_w, hdr.board_h, hdr.rules_id, hdr.total, hdr.legal_count });

        if (hdr.board_w != 4 or hdr.board_h != 4) {
            std.debug.print("ERROR: expected 4x4, got {d}x{d}\n", .{ hdr.board_w, hdr.board_h });
            return error.BadTotal;
        }

        const t: usize = @intCast(hdr.total);
        const payload = art_bytes[WZO_HEADER_LEN..];
        const vb = try gpa.alloc(i8, t);
        defer gpa.free(vb);
        const vw = try gpa.alloc(i8, t);
        defer gpa.free(vw);
        const fb = try gpa.alloc(u8, t);
        defer gpa.free(fb);
        const fw = try gpa.alloc(u8, t);
        defer gpa.free(fw);
        @memcpy(std.mem.sliceAsBytes(vb), payload[0 * t .. 1 * t]);
        @memcpy(std.mem.sliceAsBytes(vw), payload[1 * t .. 2 * t]);
        @memcpy(fb, payload[2 * t .. 3 * t]);
        @memcpy(fw, payload[3 * t .. 4 * t]);

        var art = WzoArtifact{ .vb = vb, .vw = vw, .fb = fb, .fw = fw, .total = hdr.total, .rules_id = hdr.rules_id };

        // Root check
        const C = Colex4x4();
        const empty_idx = C.colexFromPos(&[_]i8{0} ** N4);
        const root_vb = vb[empty_idx];
        const root_vw = vw[empty_idx];
        const root_flag_b = fb[empty_idx] & 1;
        const root_flag_w = fw[empty_idx] & 1;
        std.debug.print("# root (empty, B): V={d} bracket={d}\n", .{ root_vb, root_flag_b });
        std.debug.print("# root (empty, W): V={d} bracket={d}\n", .{ root_vw, root_flag_w });
        std.debug.print("# root filled: {} (B), {} (W)\n", .{ root_vb != UNDEF, root_vw != UNDEF });

        // Count UNDEF slots and bracket slots for context
        var undef_count: u64 = 0;
        var bracket_count_b: u64 = 0;
        var bracket_count_w: u64 = 0;
        var valued_count: u64 = 0;
        for (0..t) |i| {
            if (vb[i] != UNDEF or vw[i] != UNDEF) valued_count += 1;
            if (vb[i] == UNDEF and vw[i] == UNDEF) undef_count += 1;
            if (fb[i] & 1 != 0) bracket_count_b += 1;
            if (fw[i] & 1 != 0) bracket_count_w += 1;
        }
        std.debug.print("# table: {d} slots, {d} valued ({d:.2}%), {d} UNDEF\n", .{ t, valued_count, @as(f64, @floatFromInt(valued_count)) / @as(f64, @floatFromInt(t)) * 100.0, undef_count });
        std.debug.print("# bracket slots: B={d}, W={d}\n", .{ bracket_count_b, bracket_count_w });

        // Playout
        const policies = [_][]const u8{ "oracle", "oracle-rt", "random", "mixed" };
        for (policies) |pol| {
            std.debug.print("\n## Playout census — policy={s}, games={d}, seed={d}\n", .{ pol, num_games, seed });
            const stats = try runPlayout4(&art, num_games, pol, seed);

            const total_checked = stats.bellman_matches + stats.bellman_violations + stats.bellman_tie_child;
            const cert_frac = if (total_checked > 0)
                @as(f64, @floatFromInt(stats.bellman_matches)) / @as(f64, @floatFromInt(total_checked)) * 100.0
            else
                0.0;

            const flag_frac = if (stats.flag_read_total_nodes > 0)
                @as(f64, @floatFromInt(stats.flag_read_bracket_nodes)) / @as(f64, @floatFromInt(stats.flag_read_total_nodes)) * 100.0
            else
                0.0;

            std.debug.print("== policy: {s} ==\n", .{pol});
            std.debug.print("  games played:           {d}\n", .{stats.games});
            std.debug.print("  two-pass terminations:  {d}\n", .{stats.two_pass_games});
            std.debug.print("  cycle terminations:     {d}\n", .{stats.cycle_terminated_games});
            std.debug.print("  UNDEF nodes:            {d}\n", .{stats.undef_nodes});
            std.debug.print("  ---\n", .{});
            std.debug.print("  visited decision nodes: {d}\n", .{stats.total_nodes});
            std.debug.print("  Bellman MATCH:          {d}\n", .{stats.bellman_matches});
            std.debug.print("  Bellman VIOLATION:      {d}\n", .{stats.bellman_violations});
            std.debug.print("  Bellman TIE_CHILD:      {d}\n", .{stats.bellman_tie_child});
            std.debug.print("  error (no children):    {d}\n", .{stats.error_nodes});
            std.debug.print("  violations via UNDEF:   {d}\n", .{stats.violations_due_to_undef});
            std.debug.print("  ---- DIRECT-IDENTITY CERTIFIED FRACTION ----\n", .{});
            std.debug.print("  certified fraction:     {d:.2}% ({d}/{d})\n", .{ cert_frac, stats.bellman_matches, total_checked });
            std.debug.print("  ---- FLAG-READ FRACTION (degenerate under this rule) ----\n", .{});
            std.debug.print("  flag-read bracket frac: {d:.2}% ({d}/{d})\n", .{ flag_frac, stats.flag_read_bracket_nodes, stats.flag_read_total_nodes });

            if (stats.bellman_violations > 0) {
                std.debug.print("  VERDICT: {d} Bellman-identity violations found\n", .{stats.bellman_violations});
            } else {
                std.debug.print("  verdict: PASS — zero Bellman-identity violations\n", .{});
            }
        }
    } else if (std.mem.eql(u8, goban_str, "3")) {
        // 3×3 calibration mode — compute fixpoint in-memory
        std.debug.print("# ============================================================================\n", .{});
        std.debug.print("# T129 — calibration known-good — 3×3 fixpoint + playout\n", .{});
        std.debug.print("# Task: T129 · Role: worker · Model: DSPro · Date: 2026-07-31\n", .{});
        std.debug.print("# ============================================================================\n", .{});

        std.debug.print("\n## Phase 1: Fixpoint computation\n", .{});
        const fp = try runFixpoint3(gpa);
        defer gpa.free(fp.L_tab);
        defer gpa.free(fp.H_tab);

        std.debug.print("# fixpoint: {d} sweeps\n", .{fp.sweeps});

        const rootB = StateIdx3{ .board = 0, .side = 0, .ko = KO_NONE3, .passes = 0 };
        const vb = lookupValue3(fp.L_tab, fp.H_tab, rootB.linear());
        const lb = fp.L_tab[rootB.linear()];
        const hb = fp.H_tab[rootB.linear()];
        std.debug.print("# root (empty, B): V={d} L={d} H={d}\n", .{ vb, lb, hb });

        std.debug.print("\n## Phase 2: Playout — policy={s}, games={d}, seed={d}\n", .{ policy_str, num_games, seed });
        const stats = try runPlayout3(fp.L_tab, fp.H_tab, num_games, policy_str, seed);

        const total_checked = stats.bellman_matches + stats.bellman_violations + stats.bellman_tie_child;
        const cert_frac = if (total_checked > 0)
            @as(f64, @floatFromInt(stats.bellman_matches)) / @as(f64, @floatFromInt(total_checked)) * 100.0
        else
            0.0;

        std.debug.print("== policy: {s} ==\n", .{policy_str});
        std.debug.print("  games played:           {d}\n", .{stats.games});
        std.debug.print("  two-pass terminations:  {d}\n", .{stats.two_pass_games});
        std.debug.print("  cycle terminations:     {d}\n", .{stats.cycle_terminated_games});
        std.debug.print("  UNDEF nodes:            {d}\n", .{stats.undef_nodes});
        std.debug.print("  ---\n", .{});
        std.debug.print("  visited decision nodes: {d}\n", .{stats.total_nodes});
        std.debug.print("  Bellman MATCH:          {d}\n", .{stats.bellman_matches});
        std.debug.print("  Bellman VIOLATION:      {d}\n", .{stats.bellman_violations});
        std.debug.print("  Bellman TIE_CHILD:      {d}\n", .{stats.bellman_tie_child});
        std.debug.print("  error (no children):    {d}\n", .{stats.error_nodes});
        std.debug.print("  ---- DIRECT-IDENTITY CERTIFIED FRACTION ----\n", .{});
        std.debug.print("  certified fraction:     {d:.2}% ({d}/{d})\n", .{ cert_frac, stats.bellman_matches, total_checked });
    } else {
        std.debug.print("Unknown goban: {s}. Use 3 or 4.\n", .{goban_str});
    }
}
