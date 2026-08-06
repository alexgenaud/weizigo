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
// T394 — canForceLife: a Boolean retrograde pass over the move graph,
// certified as a pruning classifier.
//
// Task: T394 · Set: B · Role: worker · Model: deepseek-v4-flash · 2026-08-06
// Landmark: advances L2 (proven 4×4 values) — if T2 holds exactly, "neither
// player can force Benson life" is a sound "stop valuing, it's a draw" oracle.
//
// For every state (position, side, ko, passes) in the game graph and each
// player P ∈ {Black, White}, compute
//
//     canForceLife(P, s)  —  playing from s, can P force the game into a
//     position containing a Benson-alive P chain, against any opposition?
//
// This is a Boolean reachability game. The target set is the states whose
// position already contains a Benson-alive P chain (Benson chains are
// immortal, so the target is successor-closed). The winning region is the
// LEAST attractor of the target in the game graph where P-side states are
// existential and opponent-side states are universal:
//
//     attr_0 = T
//     attr_{k+1} = attr_k ∪ { s : side(s)=P  and ∃ child(s) ∈ attr_k }
//                          ∪ { s : side(s)≠P, passes(s)=0,
//                               children(s)≠∅, all children(s) ∈ attr_k }
//
// Terminal caveat: a passes=1 state's pass move ends the game (two passes).
// Its terminal successor is a losing sink for the mover's life goal and is
// NOT in the vertex space (WZO2 omits passes=2 states). Hence an opponent-
// side passes=1 state is in the attractor iff it is itself in the target
// (a non-target one can never satisfy "all successors in attr"): implemented
// as remaining = outdeg + 1 for universal passes=1 states (the implicit
// sink never joins attr). The complement of the least attractor is exactly
// the set of states from which the opponent can keep the position
// P-chain-free forever (possibly by infinite play) — the "mutual
// territory-denial" region the operator's hypothesis is about.
//
// Boolean reachability games on finite graphs have a UNIQUE attractor (no
// scores, no TIE, no fixpoint ambiguity) — the least fixpoint of the
// monotone operator above, computed by the classical counting worklist
// (in-degree counters for universal states, first-successor rule for
// existential states).
//
// Vertex space, per size:
//   3×3, 4×4  — the WZO2 table entries (reachable-from-empty closure under
//               basic ko, passes ∈ {0,1}; passes=2 terminal states omitted).
//   2×2, 3×2, 4×3 — the reachable-from-empty closure built by BFS under the
//               same basic-ko move relation (no WZO2 table exists).
// Move semantics: the T273 kernel (rules.zig Rules(w,h): applyMove/applyPass/
// benson_alive), already verified against the tables' successor sets by T345
// (0/99,133,036 key agreement). Child positions must be legal; in closure
// mode legality is checked explicitly, in table mode a missing group IS the
// miss (legal positions are exactly the WZO2 groups).
//
// L/H brackets (for the T2/T3 joins): 3×3/4×4 from the WZO2 entries
// (verified oracle-v2 loopy fixpoint, rules_id 3); 2×2/3×2/4×3 from the
// generic loopy fixpoint implemented here (exp6_solve.zig semantics,
// ADR-0020), calibrated against the WZO2 3×3 table per-entry (0 mismatch
// required) and the committed roots (2×2 [−4,+4], 3×2 [−6,+6]).
//
// Controls (mandatory before any reading counts):
//   N1 null — target set empty → attractor empty everywhere.
//   S1 seeded — 2×2 diagonal position (B at both diagonal cells): every
//      entry canForceLife(B)=true, canForceLife(W)=false.
//   S2 seeded — one forced move away: 2×2, B at (0,0), Black to move,
//      ko=NONE, passes=0: canForceLife(B)=true, s ∉ T_B, ∃ child ∈ T_B.
//   S3 seeded — refuting reply: 2×2 empty, Black to move: canForceLife(B)
//      = false (White's reply to any B stone blocks/kills the diagonal).
//   S4 colour inversion spot check — canForceLife(W, rootW) ==
//      canForceLife(B, rootB) at every size (empty board is its own
//      colour inverse).
//   V1 attractor fixpoint verification — every sampled state satisfies the
//      defining equation (full at sizes with V ≤ 20M, sampled at 4×4 with
//      the denominator stated).
//
// Calibrations (must reproduce, else the reading does not count):
//   C1 4×4 E (stored pred edges) == 565,402,416 (vb_scc_4x4 register).
//   C2 pin_0 (L≤0≤H entries) == 1,248 (3×3) and 895,216 (4×4) (A4 census).
//   C3 3×3: the BFS closure == the WZO2 entry set, and the generic fixpoint
//      reproduces every entry's L/H (0 mismatches).
//
// Build (small sizes fast, 4×4 ~15 min at ~3.3 GB peak):
//   tools/runner --max-wall 3600 -- zig run -O ReleaseFast src/t394_force_life.zig \
//     -- --out findings/T394-force-life.json --sizes 2x2,3x2,3x3,4x3,4x4
//
// stdout = data (one JSON object per size), stderr = diagnostics, JSON file
// written at the end.

const std = @import("std");
const vb_movegen = @import("vb_movegen.zig");
const rules_mod = @import("rules.zig");
const enumerate = @import("enumerate.zig");
const util = @import("util.zig");

const gpa = std.heap.page_allocator;

fn nowMs() u64 {
    var ts: std.c.timespec = undefined;
    _ = std.c.clock_gettime(.MONOTONIC, &ts);
    return @as(u64, @intCast(ts.sec)) * 1000 + @as(u64, @intCast(ts.nsec)) / 1_000_000;
}

fn pow3(n: u64) u64 {
    var r: u64 = 1;
    var e: u64 = n;
    while (e > 0) : (e -= 1) r *= 3;
    return r;
}

// ────────────────────────────────────────────────────────────────────────────
// WZO2 minimal loader (independent re-implementation of the format contract:
// 128-byte header + n_groups×5 group index + n_entries×4 key_byte|L|H|DTT).
// ────────────────────────────────────────────────────────────────────────────

const Wzo2 = struct {
    w: u8,
    h: u8,
    ko_bits: u8,
    n_groups: u64,
    n_entries: u64,
    /// The readFileAlloc buffer (the caller's ownership — freed via Graph).
    owned: []u8,
    groups: []const u8, // n_groups × 5 (colex u32 LE + entry_count u8)
    entries: []const u8, // n_entries × 4

    fn load(io: std.Io, allocator: std.mem.Allocator, path: []const u8) !Wzo2 {
        const bytes = try std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .unlimited);
        if (bytes.len < 128) return error.Truncated;
        if (!std.mem.eql(u8, bytes[0..4], "WZO2")) return error.BadMagic;
        const version = std.mem.readInt(u16, bytes[4..6], .little);
        if (version != 1) return error.BadVersion;
        const w = bytes[6];
        const h = bytes[7];
        if (w == 0 or h == 0 or w > 4 or h > 4) return error.BadSize;
        const entry_size = std.mem.readInt(u16, bytes[10..12], .little);
        if (entry_size != 4) return error.BadEntrySize;
        const group_header_size = bytes[12];
        if (group_header_size != 5) return error.BadGroupHeaderSize;
        const ko_bits = bytes[13];
        const n_groups = std.mem.readInt(u64, bytes[16..24], .little);
        const n_entries = std.mem.readInt(u64, bytes[24..32], .little);
        const data_offset = std.mem.readInt(u64, bytes[32..40], .little);
        if (data_offset != 128) return error.BadDataOffset;
        const groups_off: usize = 128;
        const entries_off: usize = 128 + @as(usize, @intCast(n_groups)) * 5;
        const expected_len = entries_off + @as(usize, @intCast(n_entries)) * 4;
        if (bytes.len != expected_len) return error.Truncated;
        return Wzo2{
            .w = w,
            .h = h,
            .ko_bits = ko_bits,
            .n_groups = n_groups,
            .n_entries = n_entries,
            .owned = bytes,
            .groups = bytes[groups_off..entries_off],
            .entries = bytes[entries_off..],
        };
    }
};

// ────────────────────────────────────────────────────────────────────────────
// Per-size solver
// ────────────────────────────────────────────────────────────────────────────

pub fn Solver(comptime w: usize, comptime h: usize) type {
    return struct {
        const n = w * h;
        const R = rules_mod.Rules(w, h);
        const E = enumerate.Enumerator(w, h);
        const Pos = R.Pos;
        const NONE: u8 = @intCast(n);
        const total_positions: u64 = pow3(n);
        const sub_stride: u64 = (@as(u64, n) + 1) * 3;
        const stride: u64 = 2 * sub_stride;
        const linear_total: u64 = total_positions * stride;
        const table_mode = (w == 3 and h == 3) or (w == 4 and h == 4);

        pub const State = struct {
            colex: u32,
            side: u8, // 0 = Black to move, 1 = White to move
            ko: u8, // >= n means NONE
            passes: u8, // 0 or 1 (2 is the omitted terminal)

            pub fn key(self: State) u64 {
                const ko_enc: u64 = if (self.ko >= NONE) 0 else @as(u64, self.ko) + 1;
                return @as(u64, self.colex) * stride + @as(u64, self.side) * sub_stride + ko_enc * 3 + @as(u64, self.passes);
            }
        };

        fn keyByte(s: State, ko_bits: u8) u8 {
            // The table stores the raw ko value (n for NONE) in the ko field.
            var kb: u8 = @as(u8, s.side) << 1;
            kb |= s.ko << 2;
            kb |= @as(u8, s.passes) << @intCast(2 + ko_bits);
            return kb;
        }
        pub fn sideOfKb(kb: u8) u8 {
            return (kb >> 1) & 1;
        }
        pub fn koOfKb(kb: u8, ko_bits: u8) u8 {
            const mask: u8 = (@as(u8, 1) << @intCast(ko_bits)) - 1;
            return (kb >> 2) & mask;
        }
        pub fn passesOfKb(kb: u8, ko_bits: u8) u8 {
            return (kb >> @intCast(2 + ko_bits)) & 1;
        }

        const Graph = struct {
            V: u64 = 0,
            E_edges: u64 = 0,
            sink_edges: u64 = 0,
            child_misses: u64 = 0,
            pass_misses: u64 = 0,
            // closure mode:
            states: []State = &.{},
            lookup: []u32 = &.{},
            // table mode:
            wzo: ?Wzo2 = null,
            wzo_owned: []const u8 = &.{}, // the readFileAlloc buffer (freed with deinit)
            colex_to_group: []u32 = &.{},
            entry_start: []u32 = &.{},
            // CSR preds (reverse adjacency: preds[offset[c]..offset[c+1]] = parents of c)
            offsets: []u32 = &.{},
            preds: []u32 = &.{},
            // per-vertex out-degree (number of stored children; u8 suffices
            // since outdeg <= n+1 <= 17) — needed by the attractor's
            // universal-state counters.
            outdeg: []u8 = &.{},
            // targets
            target_b: []u64 = &.{},
            target_w: []u64 = &.{},
            target_words: usize = 0,
            legal_positions: u64 = 0,

            fn freeDerived(self: *Graph) void {
                // free table-mode lookup structures (keep preds/offsets/targets)
                if (self.colex_to_group.len > 0) {
                    gpa.free(self.colex_to_group);
                    self.colex_to_group = &.{};
                }
                if (self.entry_start.len > 0) {
                    gpa.free(self.entry_start);
                    self.entry_start = &.{};
                }
                if (self.wzo_owned.len > 0) {
                    gpa.free(@constCast(self.wzo_owned));
                    self.wzo_owned = &.{};
                    self.wzo = null;
                }
            }

            /// Table mode: re-read the artifact and rebuild the derived
            /// lookup structures after freeDerived() (keeps the CSR preds,
            /// offsets and target bitsets, which survive).
            fn reloadDerived(self: *Graph, io: std.Io, path: []const u8) !void {
                const wzo = try Wzo2.load(io, gpa, path);
                self.wzo = wzo;
                self.wzo_owned = wzo.owned;
                self.colex_to_group = try gpa.alloc(u32, @intCast(total_positions));
                @memset(self.colex_to_group, 0xFFFFFFFF);
                for (0..@as(usize, @intCast(wzo.n_groups))) |gi| {
                    const colex = std.mem.readInt(u32, wzo.groups[gi * 5 ..][0..4], .little);
                    self.colex_to_group[colex] = @intCast(gi);
                }
                self.entry_start = try gpa.alloc(u32, @intCast(wzo.n_groups + 1));
                var acc: u32 = 0;
                for (0..@as(usize, @intCast(wzo.n_groups))) |gi| {
                    self.entry_start[gi] = acc;
                    acc += wzo.groups[gi * 5 + 4];
                }
                self.entry_start[@intCast(wzo.n_groups)] = acc;
            }

            pub fn deinit(self: *Graph) void {
                self.freeDerived();
                if (self.states.len > 0) gpa.free(self.states);
                if (self.lookup.len > 0) gpa.free(self.lookup);
                if (self.offsets.len > 0) gpa.free(self.offsets);
                if (self.preds.len > 0) gpa.free(self.preds);
                if (self.outdeg.len > 0) gpa.free(self.outdeg);
                if (self.target_b.len > 0) gpa.free(self.target_b);
                if (self.target_w.len > 0) gpa.free(self.target_w);
            }
        };

        // ── state accessors ──────────────────────────────────────────────

        fn stateAt(g: *const Graph, v: u64) State {
            if (g.wzo != null) {
                const gi = groupOfEntry(g, v);
                const colex = std.mem.readInt(u32, g.wzo.?.groups[@as(usize, @intCast(gi * 5))..][0..4], .little);
                const kb = g.wzo.?.entries[@as(usize, @intCast(v * 4))];
                return State{
                    .colex = colex,
                    .side = sideOfKb(kb),
                    .ko = koOfKb(kb, g.wzo.?.ko_bits),
                    .passes = passesOfKb(kb, g.wzo.?.ko_bits),
                };
            }
            return g.states[@intCast(v)];
        }

        fn sidePassesAt(g: *const Graph, v: u64) struct { side: u8, passes: u8 } {
            if (g.wzo != null) {
                const kb = g.wzo.?.entries[@as(usize, @intCast(v * 4))];
                return .{ .side = sideOfKb(kb), .passes = passesOfKb(kb, g.wzo.?.ko_bits) };
            }
            return .{ .side = g.states[@intCast(v)].side, .passes = g.states[@intCast(v)].passes };
        }

        fn groupOfEntry(g: *const Graph, v: u64) u64 {
            var lo: u64 = 0;
            var hi: u64 = g.wzo.?.n_groups - 1;
            while (lo < hi) {
                const mid = (lo + hi + 1) / 2;
                if (g.entry_start[@intCast(mid)] <= v) lo = mid else hi = mid - 1;
            }
            return lo;
        }

        pub fn lhAt(g: *const Graph, v: u64, L: []const i8, H: []const i8) struct { l: i8, h: i8 } {
            if (g.wzo != null) {
                const off: usize = @intCast(v * 4);
                return .{ .l = @bitCast(g.wzo.?.entries[off + 1]), .h = @bitCast(g.wzo.?.entries[off + 2]) };
            }
            return .{ .l = L[@intCast(v)], .h = H[@intCast(v)] };
        }

        // ── children ─────────────────────────────────────────────────────

        /// Enumerate table-present children of a state into `ids`; returns
        /// the count. A passes=1 state's pass edge is the omitted terminal
        /// (losing sink) — never generated.
        fn childrenOf(g: *const Graph, s: State, ids: *[n + 1]u32) usize {
            var count: usize = 0;
            if (s.passes == 0) {
                const pass_child = State{ .colex = s.colex, .side = 1 - s.side, .ko = NONE, .passes = 1 };
                if (childId(g, pass_child)) |cid| {
                    ids[count] = cid;
                    count += 1;
                }
            }
            var pos: Pos = undefined;
            posFromColexLocal(s.colex, &pos);
            const colour: i8 = if (s.side == 0) 1 else -1;
            for (0..n) |cell| {
                if (pos[cell] != 0) continue;
                if (s.ko < NONE and cell == @as(usize, s.ko)) continue;
                const child = R.applyMove(&pos, colour, s.ko, @intCast(s.passes), cell) orelse continue;
                if (!E.is_legal(&child.pos)) continue;
                const child_colex = vb_movegen.colexFromPos(w, h, &child.pos);
                const child_state = State{ .colex = @intCast(child_colex), .side = if (colour > 0) 1 else 0, .ko = child.ko, .passes = 0 };
                if (childId(g, child_state)) |cid| {
                    ids[count] = cid;
                    count += 1;
                }
            }
            return count;
        }

        pub fn childId(g: *const Graph, s: State) ?u32 {
            if (g.wzo != null) {
                const gi = g.colex_to_group[s.colex];
                if (gi == 0xFFFFFFFF) return null;
                const ec: u8 = g.wzo.?.groups[@as(usize, @intCast(gi * 5 + 4))];
                const start: usize = @intCast(g.entry_start[@intCast(gi)]);
                // Match on (side, ko, passes) fields only: the key byte's
                // terminal bit (bit 0) is a state property ("the side has no
                // legal placements"), not part of the state tuple — two
                // states with the same (side, ko, passes) always share it.
                const ko_bits = g.wzo.?.ko_bits;
                for (0..ec) |i| {
                    const kb = g.wzo.?.entries[(start + i) * 4];
                    if (sideOfKb(kb) == s.side and koOfKb(kb, ko_bits) == s.ko and passesOfKb(kb, ko_bits) == s.passes)
                        return @intCast(start + i);
                }
                return null;
            }
            const id = g.lookup[@intCast(s.key())];
            if (id == 0xFFFFFFFF) return null;
            return id;
        }

        fn posFromColexLocal(idx: u32, pos: *Pos) void {
            pos.* = vb_movegen.posFromColex(w, h, idx);
        }

        // ── closure construction (2×2, 3×2, 4×3) ────────────────────────

        pub fn buildClosure() !Graph {
            var g = Graph{};
            g.lookup = try gpa.alloc(u32, @intCast(linear_total));
            @memset(g.lookup, 0xFFFFFFFF);
            var states = std.ArrayListUnmanaged(State).empty;
            defer states.deinit(gpa);
            var queue = std.ArrayListUnmanaged(State).empty;
            defer queue.deinit(gpa);
            const seed_b = State{ .colex = 0, .side = 0, .ko = NONE, .passes = 0 };
            const seed_w = State{ .colex = 0, .side = 1, .ko = NONE, .passes = 0 };
            for ([_]State{ seed_b, seed_w }) |s| {
                try states.append(gpa, s);
                g.lookup[@intCast(s.key())] = @intCast(states.items.len - 1);
                try queue.append(gpa, s);
            }
            var qhead: usize = 0;
            while (qhead < queue.items.len) : (qhead += 1) {
                const s = queue.items[qhead];
                // Placements are legal from passes=0 AND passes=1 states (the
                // game ends only after TWO passes). Only the pass move from a
                // passes=1 state is the omitted terminal sink — never added.
                var pos: Pos = undefined;
                posFromColexLocal(s.colex, &pos);
                const colour: i8 = if (s.side == 0) 1 else -1;
                for (0..n) |cell| {
                    if (pos[cell] != 0) continue;
                    if (s.ko < NONE and cell == @as(usize, s.ko)) continue;
                    const child = R.applyMove(&pos, colour, s.ko, @intCast(s.passes), cell) orelse continue;
                    if (!E.is_legal(&child.pos)) continue;
                    const child_colex = vb_movegen.colexFromPos(w, h, &child.pos);
                    const cs = State{ .colex = @intCast(child_colex), .side = if (colour > 0) 1 else 0, .ko = child.ko, .passes = 0 };
                    const ck = cs.key();
                    if (g.lookup[@intCast(ck)] == 0xFFFFFFFF) {
                        g.lookup[@intCast(ck)] = @intCast(states.items.len);
                        try states.append(gpa, cs);
                        try queue.append(gpa, cs);
                    }
                }
                if (s.passes == 0) {
                    const ps = State{ .colex = s.colex, .side = 1 - s.side, .ko = NONE, .passes = 1 };
                    const pk = ps.key();
                    if (g.lookup[@intCast(pk)] == 0xFFFFFFFF) {
                        g.lookup[@intCast(pk)] = @intCast(states.items.len);
                        try states.append(gpa, ps);
                        try queue.append(gpa, ps);
                    }
                }
            }
            g.states = try states.toOwnedSlice(gpa);
            g.V = g.states.len;
            var seen = try gpa.alloc(u8, @intCast((total_positions + 7) / 8));
            defer gpa.free(seen);
            @memset(seen, 0);
            for (g.states) |s| {
                const wd: usize = @intCast(s.colex / 8);
                seen[wd] |= @as(u8, 1) << @intCast(s.colex % 8);
            }
            for (seen) |byte| {
                g.legal_positions += @popCount(byte);
            }
            return g;
        }

        // ── table construction (3×3, 4×4) ───────────────────────────────

        pub fn buildTable(io: std.Io, path: []const u8) !Graph {
            var g = Graph{};
            const wzo = try Wzo2.load(io, gpa, path);
            g.wzo = wzo;
            g.wzo_owned = wzo.owned;
            g.V = wzo.n_entries;
            g.legal_positions = wzo.n_groups;
            g.colex_to_group = try gpa.alloc(u32, @intCast(total_positions));
            @memset(g.colex_to_group, 0xFFFFFFFF);
            for (0..@as(usize, @intCast(wzo.n_groups))) |gi| {
                const colex = std.mem.readInt(u32, wzo.groups[gi * 5 ..][0..4], .little);
                g.colex_to_group[colex] = @intCast(gi);
            }
            g.entry_start = try gpa.alloc(u32, @intCast(wzo.n_groups + 1));
            var acc: u32 = 0;
            for (0..@as(usize, @intCast(wzo.n_groups))) |gi| {
                g.entry_start[gi] = acc;
                acc += wzo.groups[gi * 5 + 4];
            }
            g.entry_start[@intCast(wzo.n_groups)] = acc;
            if (@as(u64, acc) != wzo.n_entries) return error.BadEntrySum;
            return g;
        }

        // ── preds CSR build (two passes) ────────────────────────────────

        const PChild = struct { cell: usize, colex: u32, ko: u8 };
        const PChildren = struct { items: [n]PChild, len: usize = 0 };

        /// Placement children of (pos, side) as if ko=NONE, passes=0 — the
        /// same for every entry of that (group, side); the entry's ko then
        /// forbids one cell.
        fn placementChildren(pos: *const Pos, side: u8, pc: *PChildren) void {
            pc.len = 0;
            const colour: i8 = if (side == 0) 1 else -1;
            for (0..n) |cell| {
                if (pos[cell] != 0) continue;
                const child = R.applyMove(pos, colour, NONE, 0, cell) orelse continue;
                pc.items[pc.len] = .{ .cell = cell, .colex = @intCast(vb_movegen.colexFromPos(w, h, &child.pos)), .ko = child.ko };
                pc.len += 1;
            }
        }

        pub fn buildPreds(g: *Graph) !void {
            g.outdeg = try gpa.alloc(u8, @intCast(g.V));
            @memset(g.outdeg, 0);
            var indeg = try gpa.alloc(u32, @intCast(g.V));
            defer gpa.free(indeg);
            @memset(indeg, 0);
            var sink_edges: u64 = 0;
            var misses: u64 = 0;
            var pass_misses: u64 = 0;
            if (table_mode) {
                const wzo = g.wzo.?;
                for (0..@as(usize, @intCast(wzo.n_groups))) |gi| {
                    const colex = std.mem.readInt(u32, wzo.groups[gi * 5 ..][0..4], .little);
                    const ec: u8 = wzo.groups[gi * 5 + 4];
                    var pos: Pos = undefined;
                    posFromColexLocal(colex, &pos);
                    var pcs: [2]PChildren = undefined;
                    placementChildren(&pos, 0, &pcs[0]);
                    placementChildren(&pos, 1, &pcs[1]);
                    const start: usize = @intCast(g.entry_start[@intCast(gi)]);
                    for (0..ec) |i| {
                        const v: usize = start + i;
                        const kb = wzo.entries[v * 4];
                        const side = sideOfKb(kb);
                        const ko = koOfKb(kb, wzo.ko_bits);
                        const passes = passesOfKb(kb, wzo.ko_bits);
                        const pcv = &pcs[side];
                        var deg: u32 = 0;
                        for (0..pcv.len) |k| {
                            const p = pcv.items[k];
                            if (p.cell == @as(usize, ko)) continue;
                            const child_state = State{ .colex = p.colex, .side = 1 - side, .ko = p.ko, .passes = 0 };
                            if (childId(g, child_state)) |cid| {
                                deg += 1;
                                indeg[cid] += 1;
                            } else misses += 1;
                        }
                        if (passes == 0) {
                            const pc_state = State{ .colex = colex, .side = 1 - side, .ko = NONE, .passes = 1 };
                            if (childId(g, pc_state)) |cid| {
                                deg += 1;
                                indeg[cid] += 1;
                            } else pass_misses += 1;
                        } else sink_edges += 1;
                        g.outdeg[v] = @intCast(deg);
                    }
                }
            } else {
                for (g.states, 0..) |s, vi| {
                    var ids: [n + 1]u32 = undefined;
                    const cnt = childrenOf(g, s, &ids);
                    g.outdeg[vi] = @intCast(cnt);
                    for (0..cnt) |k| indeg[ids[k]] += 1;
                    if (s.passes == 1) sink_edges += 1;
                }
            }
            g.sink_edges = sink_edges;
            g.child_misses = misses;
            g.pass_misses = pass_misses;
            // prefix sum of IN-degrees → CSR offsets over children
            g.offsets = try gpa.alloc(u32, @intCast(g.V + 1));
            var acc: u32 = 0;
            g.offsets[0] = 0;
            for (0..@as(usize, @intCast(g.V))) |c| {
                acc += indeg[c];
                g.offsets[c + 1] = acc;
            }
            g.E_edges = acc;
            gpa.free(indeg); // no longer needed — trim peak RSS before preds
            indeg = &.{};
            g.preds = try gpa.alloc(u32, @intCast(acc));
            var cursor = try gpa.alloc(u32, @intCast(g.V));
            defer gpa.free(cursor);
            @memcpy(cursor, g.offsets[0..@intCast(g.V)]);
            if (table_mode) {
                const wzo = g.wzo.?;
                for (0..@as(usize, @intCast(wzo.n_groups))) |gi| {
                    const colex = std.mem.readInt(u32, wzo.groups[gi * 5 ..][0..4], .little);
                    const ec: u8 = wzo.groups[gi * 5 + 4];
                    var pos: Pos = undefined;
                    posFromColexLocal(colex, &pos);
                    var pcs: [2]PChildren = undefined;
                    placementChildren(&pos, 0, &pcs[0]);
                    placementChildren(&pos, 1, &pcs[1]);
                    const start: usize = @intCast(g.entry_start[@intCast(gi)]);
                    for (0..ec) |i| {
                        const v: usize = start + i;
                        const kb = wzo.entries[v * 4];
                        const side = sideOfKb(kb);
                        const ko = koOfKb(kb, wzo.ko_bits);
                        const passes = passesOfKb(kb, wzo.ko_bits);
                        const pcv = &pcs[side];
                        for (0..pcv.len) |k| {
                            const p = pcv.items[k];
                            if (p.cell == @as(usize, ko)) continue;
                            const child_state = State{ .colex = p.colex, .side = 1 - side, .ko = p.ko, .passes = 0 };
                            if (childId(g, child_state)) |cid| {
                                g.preds[cursor[cid]] = @intCast(v);
                                cursor[cid] += 1;
                            }
                        }
                        if (passes == 0) {
                            const pc_state = State{ .colex = colex, .side = 1 - side, .ko = NONE, .passes = 1 };
                            if (childId(g, pc_state)) |cid| {
                                g.preds[cursor[cid]] = @intCast(v);
                                cursor[cid] += 1;
                            }
                        }
                    }
                }
            } else {
                for (g.states, 0..) |s, vi| {
                    var ids: [n + 1]u32 = undefined;
                    const cnt = childrenOf(g, s, &ids);
                    for (0..cnt) |k| {
                        const cid = ids[k];
                        g.preds[cursor[cid]] = @intCast(vi);
                        cursor[cid] += 1;
                    }
                }
            }
        }

        // ── targets (Benson per position) ───────────────────────────────

        pub fn computeTargets(g: *Graph) !void {
            g.target_words = @intCast((g.V + 63) / 64);
            g.target_b = try gpa.alloc(u64, g.target_words);
            g.target_w = try gpa.alloc(u64, g.target_words);
            @memset(g.target_b, 0);
            @memset(g.target_w, 0);
            if (table_mode) {
                const wzo = g.wzo.?;
                for (0..@as(usize, @intCast(wzo.n_groups))) |gi| {
                    const colex = std.mem.readInt(u32, wzo.groups[gi * 5 ..][0..4], .little);
                    const ec: u8 = wzo.groups[gi * 5 + 4];
                    var pos: Pos = undefined;
                    posFromColexLocal(colex, &pos);
                    const alive_b = hasAliveChain(&pos, 1);
                    const alive_w = hasAliveChain(&pos, -1);
                    const start: usize = @intCast(g.entry_start[@intCast(gi)]);
                    for (0..ec) |i| {
                        const v: usize = start + i;
                        if (alive_b) setBit(g.target_b, v);
                        if (alive_w) setBit(g.target_w, v);
                    }
                }
            } else {
                var cache = try gpa.alloc(u8, @intCast(total_positions));
                defer gpa.free(cache);
                @memset(cache, 0);
                for (g.states, 0..) |s, v| {
                    var m = cache[s.colex];
                    if (m == 0) {
                        var pos: Pos = undefined;
                        posFromColexLocal(s.colex, &pos);
                        if (hasAliveChain(&pos, 1)) m |= 1;
                        if (hasAliveChain(&pos, -1)) m |= 2;
                        cache[s.colex] = m;
                    }
                    if (m & 1 != 0) setBit(g.target_b, v);
                    if (m & 2 != 0) setBit(g.target_w, v);
                }
            }
        }

        fn hasAliveChain(pos: *const Pos, colour: i8) bool {
            var any = false;
            for (pos) |c| {
                if (c * colour > 0) {
                    any = true;
                    break;
                }
            }
            if (!any) return false;
            const alive = R.benson_alive(pos, colour);
            for (alive) |a| {
                if (a) return true;
            }
            return false;
        }

        fn aliveArea(pos: *const Pos, colour: i8) u16 {
            if (!hasAliveChain(pos, colour)) return 0;
            const alive = R.benson_alive(pos, colour);
            var cnt: u16 = 0;
            for (alive) |a| {
                if (a) cnt += 1;
            }
            return cnt;
        }

        pub fn setBit(words: []u64, v: usize) void {
            words[v / 64] |= @as(u64, 1) << @intCast(v % 64);
        }
        pub fn getBit(words: []const u64, v: usize) bool {
            return (words[v / 64] & (@as(u64, 1) << @intCast(v % 64))) != 0;
        }

        // ── attractor (counting worklist) ───────────────────────────────

        const AttrResult = struct {
            size: u64,
            pops: u64,
            max_level: u32,
            target_size: u64,
        };

        /// P: 0 = Black (Black-side states existential), 1 = White.
        /// If out_attr is non-null it must hold target_words u64 words; the
        /// final attr bitset is copied into it (otherwise allocated and
        /// freed internally). target_override replaces the built-in target.
        pub fn attractor(g: *const Graph, P: u8, with_levels: bool, target_override: ?[]const u64, out_attr: ?[]u64) !AttrResult {
            const V: usize = @intCast(g.V);
            const words: usize = @intCast(g.target_words);
            const tgt: []const u64 = target_override orelse if (P == 0) g.target_b else g.target_w;
            var attr_owned: ?[]u64 = null;
            var attr: []u64 = undefined;
            if (out_attr) |oa| {
                attr = oa;
            } else {
                attr_owned = try gpa.alloc(u64, words);
                attr = attr_owned.?;
            }
            defer if (attr_owned) |a| gpa.free(a);
            @memcpy(attr, tgt);

            var remaining = try gpa.alloc(u8, V);
            defer gpa.free(remaining);
            var levels: ?[]u8 = null;
            if (with_levels) {
                levels = try gpa.alloc(u8, V);
                @memset(levels.?, 0);
            }
            defer if (levels) |lv| gpa.free(lv);

            var target_size: u64 = 0;
            for (tgt) |word| target_size += @popCount(word);

            for (0..V) |v| {
                var deg: u32 = g.outdeg[v];
                const sp = sidePassesAt(g, v);
                if (sp.side != P and sp.passes == 1) deg += 1; // implicit losing sink
                remaining[v] = @intCast(deg);
            }

            var queue = std.ArrayListUnmanaged(u32).empty;
            defer queue.deinit(gpa);
            for (0..V) |v| {
                if (getBit(attr, v)) try queue.append(gpa, @intCast(v));
            }

            var pops: u64 = 0;
            var max_level: u32 = 0;
            var qhead: usize = 0;
            while (qhead < queue.items.len) : (qhead += 1) {
                const v = queue.items[qhead];
                pops += 1;
                const lvl: u32 = if (levels) |lv| @as(u32, lv[v]) else 0;
                const start: usize = g.offsets[v];
                const end: usize = g.offsets[v + 1];
                for (g.preds[start..end]) |p_raw| {
                    const p: usize = p_raw;
                    if (getBit(attr, p)) continue;
                    const sp = sidePassesAt(g, p);
                    if (sp.side == P) {
                        setBit(attr, p);
                        if (levels) |lv| lv[p] = @intCast(@min(@as(u32, lvl) + 1, 255));
                        try queue.append(gpa, @intCast(p));
                        if (with_levels) max_level = @max(max_level, lvl + 1);
                    } else {
                        const r = &remaining[p];
                        r.* -= 1;
                        if (r.* == 0) {
                            setBit(attr, p);
                            if (levels) |lv| lv[p] = @intCast(@min(@as(u32, lvl) + 1, 255));
                            try queue.append(gpa, @intCast(p));
                            if (with_levels) max_level = @max(max_level, lvl + 1);
                        }
                    }
                }
            }

            var size: u64 = 0;
            for (attr) |word| size += @popCount(word);
            return AttrResult{ .size = size, .pops = pops, .max_level = if (with_levels) max_level else 0, .target_size = target_size };
        }

        // ── generic loopy fixpoint (closure mode only) ──────────────────

        /// exp6_solve.zig semantics (ADR-0020): decoupled least/greatest
        /// fixpoints of L/H from −n/+n over the closure; a passes=1 state's
        /// pass move ends the game, so its value includes the position's
        /// area score (the omitted passes=2 leaf). Returns L, H (i8/vertex).
        fn fixpointLh(g: *const Graph) !struct { L: []i8, H: []i8 } {
            const V: usize = @intCast(g.V);
            const L = try gpa.alloc(i8, V);
            const H = try gpa.alloc(i8, V);
            errdefer gpa.free(L);
            errdefer gpa.free(H);
            const lo: i8 = -@as(i8, @intCast(n));
            const hi: i8 = @as(i8, @intCast(n));
            @memset(L, lo);
            @memset(H, hi);
            var sweeps: u32 = 0;
            const MAX_SWEEPS: u32 = 512;
            while (true) {
                sweeps += 1;
                var changes: u64 = 0;
                for (g.states, 0..) |s, v| {
                    var pos: Pos = undefined;
                    posFromColexLocal(s.colex, &pos);
                    const colour: i8 = if (s.side == 0) 1 else -1;
                    const maximizing = s.side == 0;
                    var best_l: i8 = if (maximizing) @as(i8, -127) else @as(i8, 127);
                    var best_h: i8 = if (maximizing) @as(i8, -127) else @as(i8, 127);
                    var have: bool = false;
                    for (0..n) |cell| {
                        if (pos[cell] != 0) continue;
                        if (s.ko < NONE and cell == @as(usize, s.ko)) continue;
                        const child = R.applyMove(&pos, colour, s.ko, @intCast(s.passes), cell) orelse continue;
                        if (!E.is_legal(&child.pos)) continue;
                        const child_colex = vb_movegen.colexFromPos(w, h, &child.pos);
                        const cs = State{ .colex = @intCast(child_colex), .side = 1 - s.side, .ko = child.ko, .passes = 0 };
                        const cid = g.lookup[@intCast(cs.key())];
                        if (cid == 0xFFFFFFFF) continue;
                        const cL = L[cid];
                        const cH = H[cid];
                        if (!have) {
                            best_l = cL;
                            best_h = cH;
                            have = true;
                        } else {
                            if (maximizing) {
                                best_l = @max(best_l, cL);
                                best_h = @max(best_h, cH);
                            } else {
                                best_l = @min(best_l, cL);
                                best_h = @min(best_h, cH);
                            }
                        }
                    }
                    if (s.passes == 1) {
                        const score = R.area_score(&pos);
                        if (!have) {
                            best_l = score;
                            best_h = score;
                            have = true;
                        } else {
                            if (maximizing) {
                                best_l = @max(best_l, score);
                                best_h = @max(best_h, score);
                            } else {
                                best_l = @min(best_l, score);
                                best_h = @min(best_h, score);
                            }
                        }
                    } else {
                        const ps = State{ .colex = s.colex, .side = 1 - s.side, .ko = NONE, .passes = 1 };
                        const pid = g.lookup[@intCast(ps.key())];
                        if (pid != 0xFFFFFFFF) {
                            const pL = L[pid];
                            const pH = H[pid];
                            if (!have) {
                                best_l = pL;
                                best_h = pH;
                                have = true;
                            } else {
                                if (maximizing) {
                                    best_l = @max(best_l, pL);
                                    best_h = @max(best_h, pH);
                                } else {
                                    best_l = @min(best_l, pL);
                                    best_h = @min(best_h, pH);
                                }
                            }
                        }
                    }
                    if (have) {
                        if (best_l != L[v]) {
                            L[v] = best_l;
                            changes += 1;
                        }
                        if (best_h != H[v]) {
                            H[v] = best_h;
                            changes += 1;
                        }
                    }
                }
                if (changes == 0 or sweeps >= MAX_SWEEPS) break;
            }
            util.note("[T394] {d}x{d} fixpoint: {d} sweeps\n", .{ w, h, sweeps });
            return .{ .L = L, .H = H };
        }

        // ── attractor fixpoint verification ─────────────────────────────

        const VerifyResult = struct {
            checked: u64,
            violations: u64,
            sampled: bool,
        };

        /// Check the defining equation on a stride-sampled subset of
        /// vertices (stride 0 or 1 = full): v ∈ attr iff (v ∈ T) or
        /// (P-side and some child ∈ attr) or (opponent-side, passes=0,
        /// all children ∈ attr).
        pub fn verifyAttractor(g: *const Graph, P: u8, attr: []const u64, target: []const u64, stride_in: usize) VerifyResult {
            const V: usize = @intCast(g.V);
            var checked: u64 = 0;
            var violations: u64 = 0;
            var vi: usize = 0;
            while (vi < V) : (vi += 1) {
                if (stride_in > 1 and vi % stride_in != 0) continue;
                checked += 1;
                const s = stateAt(g, vi);
                const in_attr = getBit(attr, vi);
                const in_t = getBit(target, vi);
                var ids: [n + 1]u32 = undefined;
                const cnt = childrenOf(g, s, &ids);
                var expect = in_t;
                if (!expect) {
                    if (s.side == P) {
                        for (0..cnt) |k| {
                            if (getBit(attr, ids[k])) {
                                expect = true;
                                break;
                            }
                        }
                    } else if (s.passes == 0) {
                        var all = cnt > 0;
                        for (0..cnt) |k| {
                            if (!getBit(attr, ids[k])) {
                                all = false;
                                break;
                            }
                        }
                        expect = all;
                    }
                }
                if (expect != in_attr) violations += 1;
            }
            return .{ .checked = checked, .violations = violations, .sampled = stride_in > 1 };
        }

        // ── stats / hypothesis joins ────────────────────────────────────

        const Buckets = struct {
            total: u64 = 0,
            pin0: u64 = 0, // L<=0<=H (draw-by-loop class)
            pin0_both_false: u64 = 0, // ...and canForceLife false for both (T2 target)
            pin0_violations: u64 = 0, // ...with canForceLife true for someone (T2 exceptions)
            lh: u64 = 0, // L==H (single-valued)
            lh_pos: u64 = 0,
            lh_neg: u64 = 0,
            lh_zero: u64 = 0,
            br_black: u64 = 0, // L<H, L>0
            br_white: u64 = 0, // L<H, H<0
            neither: u64 = 0, // canForceLife false for both
            some: u64 = 0, // at least one can
            neither_pin0: u64 = 0,
            neither_decisive: u64 = 0,
            neither_br: u64 = 0,
            some_pin0: u64 = 0,
            some_decisive: u64 = 0,
            some_br: u64 = 0,
        };

        /// A4 pin-census classes (oracle_v2_accept.checkA4 ordering):
        /// 0 = L==H (pin_T); 1 = L>0 (pin_L, implies L<H); 2 = H<0 (pin_H);
        /// 3 = pin_0 (L<H and L<=0<=H — the draw-by-loop class).
        fn classOf(l: i8, hh: i8) u8 {
            if (l == hh) return 0;
            if (l > 0) return 1;
            if (hh < 0) return 2;
            return 3;
        }

        fn tally(g: *const Graph, L: []const i8, H: []const i8, attr_b: []const u64, attr_w: []const u64, b: *Buckets) void {
            const V: usize = @intCast(g.V);
            for (0..V) |v| {
                const lh = lhAt(g, v, L, H);
                b.total += 1;
                const cls = classOf(lh.l, lh.h);
                const cf_b = getBit(attr_b, v);
                const cf_w = getBit(attr_w, v);
                const neither = !cf_b and !cf_w;
                const some = cf_b or cf_w;
                switch (cls) {
                    0 => {
                        // L == H — single-valued (pin_T)
                        b.lh += 1;
                        if (lh.l > 0) b.lh_pos += 1 else if (lh.l < 0) b.lh_neg += 1 else b.lh_zero += 1;
                        if (neither) b.neither_decisive += 1;
                        if (some) b.some_decisive += 1;
                    },
                    1 => {
                        // L < H and L > 0 — Black-favoured bracket (pin_L)
                        b.br_black += 1;
                        if (neither) b.neither_br += 1;
                        if (some) b.some_br += 1;
                    },
                    2 => {
                        // L < H and H < 0 — White-favoured bracket (pin_H)
                        b.br_white += 1;
                        if (neither) b.neither_br += 1;
                        if (some) b.some_br += 1;
                    },
                    3 => {
                        // L < H and L <= 0 <= H — draw-by-loop (pin_0)
                        b.pin0 += 1;
                        if (neither) {
                            b.neither_pin0 += 1;
                            b.pin0_both_false += 1;
                        } else {
                            b.pin0_violations += 1;
                        }
                        if (some) b.some_pin0 += 1;
                    },
                    else => unreachable,
                }
                if (neither) b.neither += 1;
                if (some) b.some += 1;
            }
        }

        const Witness = struct {
            colex: u32,
            side: u8,
            ko: u8,
            passes: u8,
            l: i8,
            h: i8,
            cf_b: bool,
            cf_w: bool,
            area_b: u16,
            area_w: u16,
            /// Max Benson-alive area of the player's chains reachable within
            /// a bounded forward search (depth <= 6, nodes <= 4096) — a lower
            /// bound on the area of the forcible life (T2-exception reports).
            forcible_area_b: u16,
            forcible_area_w: u16,
        };

        /// Bounded forward search from a state; returns the max Benson-alive
        /// area of `colour` over all positions visited (incl. the start).
        fn maxReachableAliveArea(g: *const Graph, s0: State, colour: i8) u16 {
            _ = g;
            const MAX_DEPTH: usize = 26;
            const MAX_NODES: usize = 250000;
            var best: u16 = 0;
            var visited = std.AutoHashMap(u64, void).init(gpa);
            defer visited.deinit();
            const QueueItem = struct { s: State, depth: usize };
            var queue = std.ArrayListUnmanaged(QueueItem).empty;
            defer queue.deinit(gpa);
            queue.append(gpa, .{ .s = s0, .depth = 0 }) catch return best;
            var head: usize = 0;
            while (head < queue.items.len) : (head += 1) {
                const item = queue.items[head];
                if (visited.count() > MAX_NODES) break;
                var pos: Pos = undefined;
                posFromColexLocal(item.s.colex, &pos);
                const a = aliveArea(&pos, colour);
                if (a > best) best = a;
                if (item.depth >= MAX_DEPTH) continue;
                const colour_here: i8 = if (item.s.side == 0) 1 else -1;
                for (0..n) |cell| {
                    if (pos[cell] != 0) continue;
                    if (item.s.ko < NONE and cell == @as(usize, item.s.ko)) continue;
                    const child = R.applyMove(&pos, colour_here, item.s.ko, @intCast(item.s.passes), cell) orelse continue;
                    if (!E.is_legal(&child.pos)) continue;
                    const child_colex = vb_movegen.colexFromPos(w, h, &child.pos);
                    const cs = State{ .colex = @intCast(child_colex), .side = 1 - item.s.side, .ko = child.ko, .passes = 0 };
                    const ck = cs.key();
                    if (visited.contains(ck)) continue;
                    visited.put(ck, {}) catch return best;
                    queue.append(gpa, .{ .s = cs, .depth = item.depth + 1 }) catch return best;
                }
            }
            return best;
        }

        /// Collect up to `max` witnesses (ascending vertex id).
        /// kind 0 = T2 exceptions (pin0 ∧ some canForceLife);
        /// kind 1 = neither-can-force-life ∧ single-valued (T3's decisive mass);
        /// kind 2 = some-can-force-life ∧ single-valued (T3's decisive mass, other side).
        fn collectWitnesses(g: *const Graph, L: []const i8, H: []const i8, attr_b: []const u64, attr_w: []const u64, kind: u8, max: usize, out: []Witness) usize {
            const V: usize = @intCast(g.V);
            var got: usize = 0;
            for (0..V) |v| {
                if (got >= max) break;
                const lh = lhAt(g, v, L, H);
                const cf_b = getBit(attr_b, v);
                const cf_w = getBit(attr_w, v);
                const matches = switch (kind) {
                    0 => lh.l <= 0 and lh.h >= 0 and lh.l < lh.h and (cf_b or cf_w),
                    1 => !cf_b and !cf_w and lh.l == lh.h,
                    2 => (cf_b or cf_w) and lh.l == lh.h,
                    else => false,
                };
                if (!matches) continue;
                const s = stateAt(g, v);
                var pos: Pos = undefined;
                posFromColexLocal(s.colex, &pos);
                out[got] = .{
                    .colex = s.colex,
                    .side = s.side,
                    .ko = s.ko,
                    .passes = s.passes,
                    .l = lh.l,
                    .h = lh.h,
                    .cf_b = cf_b,
                    .cf_w = cf_w,
                    .area_b = aliveArea(&pos, 1),
                    .area_w = aliveArea(&pos, -1),
                    .forcible_area_b = maxReachableAliveArea(g, s, 1),
                    .forcible_area_w = maxReachableAliveArea(g, s, -1),
                };
                got += 1;
            }
            return got;
        }

        const RootInfo = struct {
            l_b: i8 = 0,
            h_b: i8 = 0,
            cf_b: bool = false, // canForceLife(B) at the Black-to-move root
            cf_w: bool = false, // canForceLife(W) at the Black-to-move root
            w_cf_w: bool = false, // canForceLife(W) at the White-to-move root (S4)
        };

        fn rootInfo(g: *const Graph, L: []const i8, H: []const i8, attr_b: []const u64, attr_w: []const u64) RootInfo {
            const sb = State{ .colex = 0, .side = 0, .ko = NONE, .passes = 0 };
            const sw = State{ .colex = 0, .side = 1, .ko = NONE, .passes = 0 };
            const id_b = childId(g, sb) orelse 0;
            const id_w = childId(g, sw) orelse 0;
            const lh_b = lhAt(g, id_b, L, H);
            return .{
                .l_b = lh_b.l,
                .h_b = lh_b.h,
                .cf_b = getBit(attr_b, id_b),
                .cf_w = getBit(attr_w, id_b),
                .w_cf_w = getBit(attr_w, id_w),
            };
        }

        // ── controls on the 2×2 closure ─────────────────────────────────

        const ControlResults = struct {
            null_ok: bool = false,
            s1_ok: bool = false,
            s2_ok: bool = false,
            s3_ok: bool = false,
            planted_ok: bool = false, // directive 3: planted state fires in the tally
        };

        fn runControls2x2(g: *Graph, L: []const i8, H: []const i8) !ControlResults {
            var res = ControlResults{};
            if (w != 2 or h != 2) return res;
            // N1 null control: empty target → empty attractor
            {
                const words: usize = @intCast(g.target_words);
                const zeros = try gpa.alloc(u64, words);
                defer gpa.free(zeros);
                @memset(zeros, 0);
                const r = try attractor(g, 0, false, zeros, null);
                res.null_ok = r.size == 0;
            }
            var diag_pos = [_]i8{ 1, 0, 0, 1 };
            const diag_colex = vb_movegen.colexFromPos(2, 2, &diag_pos);
            // S2: B at (0,0), W at (0,1), Black to move, ko=NONE, passes=0 —
            // Black plays (1,1) and the 2×2 diagonal (Benson-alive) appears.
            var s2_pos = [_]i8{ 1, -1, 0, 0 };
            const s2_colex = vb_movegen.colexFromPos(2, 2, &s2_pos);

            const attr_b = try gpa.alloc(u64, g.target_words);
            defer gpa.free(attr_b);
            const attr_w = try gpa.alloc(u64, g.target_words);
            defer gpa.free(attr_w);
            _ = try attractor(g, 0, true, null, attr_b);
            _ = try attractor(g, 1, false, null, attr_w);

            res.s1_ok = true;
            var s1_checked: u64 = 0;
            for (g.states, 0..) |s, v| {
                if (s.colex != diag_colex) continue;
                s1_checked += 1;
                if (!getBit(g.target_b, v) or getBit(attr_w, v)) res.s1_ok = false;
            }
            if (s1_checked == 0) res.s1_ok = false;

            if (childId(g, State{ .colex = @intCast(s2_colex), .side = 0, .ko = NONE, .passes = 0 })) |v| {
                res.s2_ok = getBit(attr_b, v) and !getBit(g.target_b, v);
                var ids: [n + 1]u32 = undefined;
                const cnt = childrenOf(g, State{ .colex = @intCast(s2_colex), .side = 0, .ko = NONE, .passes = 0 }, &ids);
                var has_target_child = false;
                for (0..cnt) |k| {
                    if (getBit(g.target_b, ids[k])) has_target_child = true;
                }
                res.s2_ok = res.s2_ok and has_target_child;
            }

            if (childId(g, State{ .colex = 0, .side = 0, .ko = NONE, .passes = 0 })) |v| {
                res.s3_ok = !getBit(attr_b, v);
            }

            // Planted control (directive 3): the seeded diagonal states must
            // fire in the TALLY's per-bracket counters, not just the
            // attractor. Run the real tally (same code as the report) and
            // check: the diagonal position's entries are L==H==+4 (decisive
            // for Black), canForceLife(B)=true, canForceLife(W)=false — so
            // they must land in the some_decisive cell, which must be > 0.
            var b = Buckets{};
            tally(g, L, H, attr_b, attr_w, &b);
            if (b.some_decisive == 0) return res;
            // find the planted diagonal entries and verify the tally counted them
            var planted_checked: u64 = 0;
            for (g.states, 0..) |st, v| {
                if (st.colex != diag_colex) continue;
                const lh = lhAt(g, v, L, H);
                if (!(lh.l == 4 and lh.h == 4)) return res;
                if (!getBit(attr_b, v) or getBit(attr_w, v)) return res;
                planted_checked += 1;
            }
            res.planted_ok = planted_checked > 0 and b.some_decisive >= planted_checked;
            util.note("[T394] 2×2 controls: null={} s1={} s2={} s3={} planted={} (some_decisive={d})\n", .{ res.null_ok, res.s1_ok, res.s2_ok, res.s3_ok, res.planted_ok, b.some_decisive });
            return res;
        }

        // ── 3×3 closure-vs-table calibration (C3) ───────────────────────

        const Calib3x3 = struct {
            v_match: bool,
            v_closure: u64,
            v_table: u64,
            lh_mismatches: u64,
            checked: u64,
        };

        fn calibrate3x3(g_closure: *const Graph, L: []const i8, H: []const i8, g_table: *const Graph) Calib3x3 {
            // Every closure state must be a table entry with the same L/H.
            var res = Calib3x3{ .v_match = false, .v_closure = g_closure.V, .v_table = g_table.V, .lh_mismatches = 0, .checked = 0 };
            if (g_closure.V != g_table.V) return res;
            res.v_match = true;
            // every closure state must be a table entry with matching L/H
            for (g_closure.states, 0..) |s, v| {
                const tid = childId(g_table, s) orelse {
                    res.lh_mismatches += 1;
                    res.checked += 1;
                    continue;
                };
                const lh_t = lhAt(g_table, tid, &.{}, &.{});
                const lh_c = lhAt(g_closure, v, L, H);
                res.checked += 1;
                if (lh_t.l != lh_c.l or lh_t.h != lh_c.h) res.lh_mismatches += 1;
            }
            // every table entry must be a closure state (no table-only states)
            for (0..@as(usize, @intCast(g_table.V))) |ti| {
                const ts = stateAt(g_table, ti);
                if (childId(g_closure, ts) == null) res.lh_mismatches += 1;
            }
            return res;
        }
    };
}

// ────────────────────────────────────────────────────────────────────────────
// JSON output (hand-rolled; std.json is churn-prone in 0.16)
// ────────────────────────────────────────────────────────────────────────────

const Json = struct {
    buf: std.ArrayListUnmanaged(u8) = .empty,

    fn deinit(self: *Json) void {
        self.buf.deinit(gpa);
    }
    /// Append literal JSON text (numbers, punctuation) — no quotes, no
    /// format-string interpretation.
    fn lit(self: *Json, s: []const u8) !void {
        try self.buf.appendSlice(gpa, s);
    }
    /// Append a quoted, escaped JSON string.
    fn str(self: *Json, s: []const u8) !void {
        try self.buf.append(gpa, '"');
        for (s) |c| {
            switch (c) {
                '"' => try self.lit("\\\""),
                '\\' => try self.lit("\\\\"),
                '\n' => try self.lit("\\n"),
                '\r' => try self.lit("\\r"),
                '\t' => try self.lit("\\t"),
                0...8, 11...12, 14...31 => {
                    var tmp: [8]u8 = undefined;
                    const t = try std.fmt.bufPrint(&tmp, "\\u{x:0>4}", .{c});
                    try self.lit(t);
                },
                else => try self.buf.append(gpa, c),
            }
        }
        try self.buf.append(gpa, '"');
    }
    /// `"name":` prefix.
    fn key(self: *Json, name: []const u8) !void {
        try self.str(name);
        try self.buf.append(gpa, ':');
    }
    fn int(self: *Json, v: anytype) !void {
        try self.buf.print(gpa, "{d}", .{v});
    }
    fn bool_(self: *Json, v: bool) !void {
        try self.lit(if (v) "true" else "false");
    }
    fn comma(self: *Json) !void {
        try self.buf.append(gpa, ',');
    }
    fn open(self: *Json) !void {
        try self.buf.append(gpa, '{');
    }
    fn close(self: *Json) !void {
        try self.buf.append(gpa, '}');
    }
};

// ────────────────────────────────────────────────────────────────────────────
// run driver
// ────────────────────────────────────────────────────────────────────────────

const SizeResult = struct {
    size: []const u8, // points into a static buffer
    json: []u8, // owned
    ok: bool,
};

pub fn main(init: std.process.Init) !void {
    var args = std.process.Args.Iterator.init(init.minimal.args);
    _ = args.next();
    var out_path: []const u8 = "findings/T394-force-life.json";
    var sizes_arg: []const u8 = "2x2,3x2,3x3,4x3,4x4";
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--out")) {
            out_path = args.next() orelse out_path;
        } else if (std.mem.eql(u8, arg, "--sizes")) {
            sizes_arg = args.next() orelse sizes_arg;
        } else if (std.mem.eql(u8, arg, "--help")) {
            util.out("usage: t394_force_life [--out PATH] [--sizes 2x2,3x2,3x3,4x3,4x4]\n", .{});
            return;
        }
    }
    var io_state = std.Io.Threaded.init(gpa, .{});
    const io = io_state.io();

    util.out("T394 canForceLife instrument — deepseek-v4-flash/T394 — 2026-08-06\n", .{});
    var results = std.ArrayListUnmanaged(SizeResult).empty;
    defer {
        for (results.items) |r| gpa.free(r.json);
        results.deinit(gpa);
    }
    var all_ok = true;
    var parts = std.mem.splitScalar(u8, sizes_arg, ',');
    while (parts.next()) |tok| {
        if (tok.len == 0) continue;
        const j = runSize(io, tok) catch |err| {
            util.warn("[T394] {s}: error {s}\n", .{ tok, @errorName(err) });
            all_ok = false;
            continue;
        };
        util.out("{s}", .{j});
        try results.append(gpa, .{ .size = tok, .json = j, .ok = true });
    }
    if (!all_ok) {
        util.warn("[T394] at least one size failed — no findings file written\n", .{});
        std.process.exit(1);
    }

    // write the findings file
    var j = Json{};
    defer j.deinit();
    try j.open();
    try j.key("instrument");
    try j.str("T394-force-life");
    try j.comma();
    try j.key("task");
    try j.str("T394");
    try j.comma();
    try j.key("agent");
    try j.str("deepseek-v4-flash/T394");
    try j.comma();
    try j.key("date");
    try j.str("2026-08-06");
    try j.comma();
    try j.key("artifact");
    try j.str("data/oracle-3x3-v2.wzo2 + data/oracle-4x4-v2.wzo2 (rules_id 3)");
    try j.comma();
    try j.key("sizes");
    try j.lit("[");
    for (results.items, 0..) |r, i| {
        if (i > 0) try j.comma();
        try j.lit(r.json);
    }
    try j.lit("]");
    try j.close();
    try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = out_path, .data = j.buf.items });
    util.note("[T394] wrote {s} ({d} bytes)\n", .{ out_path, j.buf.items.len });
}

fn runSize(io: std.Io, size: []const u8) ![]u8 {
    if (std.mem.eql(u8, size, "2x2")) return runOne(io, 2, 2);
    if (std.mem.eql(u8, size, "3x2")) return runOne(io, 3, 2);
    if (std.mem.eql(u8, size, "3x3")) return runOne(io, 3, 3);
    if (std.mem.eql(u8, size, "4x3")) return runOne(io, 4, 3);
    if (std.mem.eql(u8, size, "4x4")) return runOne(io, 4, 4);
    return error.UnknownSize;
}

fn runOne(io: std.Io, comptime w: usize, comptime h: usize) ![]u8 {
    const S = Solver(w, h);
    var g = S.Graph{};
    const t0 = nowMs();
    if (S.table_mode) {
        g = try S.buildTable(io, if (w == 4) "data/oracle-4x4-v2.wzo2" else "data/oracle-3x3-v2.wzo2");
    } else {
        g = try S.buildClosure();
    }
    const t1 = nowMs();
    try S.buildPreds(&g);
    const t2 = nowMs();
    try S.computeTargets(&g);
    const t3 = nowMs();

    var L: []i8 = &.{};
    var H: []i8 = &.{};
    if (!S.table_mode) {
        const fp = try S.fixpointLh(&g);
        L = fp.L;
        H = fp.H;
    }
    const t4 = nowMs();

    var controls = S.ControlResults{};
    if (w == 2 and h == 2) {
        controls = try S.runControls2x2(&g, L, H);
    }

    const with_levels = g.V <= 20_000_000;
    const attr_b = try gpa.alloc(u64, g.target_words);
    const attr_w = try gpa.alloc(u64, g.target_words);
    const ab = try S.attractor(&g, 0, with_levels, null, attr_b);
    const t5 = nowMs();
    const aw = try S.attractor(&g, 1, false, null, attr_w);
    const t6 = nowMs();

    // 3×3 C3: closure-vs-table calibration — the closure (complete reachable
    // graph) must equal the table entry set, and the generic fixpoint's L/H
    // must reproduce every table entry's L/H.
    var calib3x3: ?S.Calib3x3 = null;
    if (w == 3 and h == 3) {
        var g_c = try S.buildClosure();
        defer g_c.deinit();
        const fp_c = try S.fixpointLh(&g_c);
        defer gpa.free(fp_c.L);
        defer gpa.free(fp_c.H);
        var g_t = try S.buildTable(io, "data/oracle-3x3-v2.wzo2");
        defer g_t.deinit();
        calib3x3 = S.calibrate3x3(&g_c, fp_c.L, fp_c.H, &g_t);
        util.note("[T394] 3x3 C3 done: closure_V={d} table_V={d} mismatches={d} checked={d}\n", .{ calib3x3.?.v_closure, calib3x3.?.v_table, calib3x3.?.lh_mismatches, calib3x3.?.checked });
    }

    // free table-mode derived structures (keep preds/offsets/targets) —
    // needed to fit the 4×4 attractor under the RSS ceiling
    if (S.table_mode) g.freeDerived();

    const stride: usize = if (g.V > 20_000_000) @intCast(g.V / 200_000) else 0;
    var vb_b: S.VerifyResult = .{ .checked = 0, .violations = 0, .sampled = false };
    var vb_w: S.VerifyResult = .{ .checked = 0, .violations = 0, .sampled = false };
    if (S.table_mode) {
        // reload the derived structures for verification/stats
        try g.reloadDerived(io, if (w == 4) "data/oracle-4x4-v2.wzo2" else "data/oracle-3x3-v2.wzo2");
    }

    vb_b = S.verifyAttractor(&g, 0, attr_b, g.target_b, stride);
    vb_w = S.verifyAttractor(&g, 1, attr_w, g.target_w, stride);
    const t7 = nowMs();

    var buckets = S.Buckets{};
    var root = S.RootInfo{};
    S.tally(&g, L, H, attr_b, attr_w, &buckets);
    root = S.rootInfo(&g, L, H, attr_b, attr_w);
    var w_t2: [8]S.Witness = undefined;
    const n_t2 = S.collectWitnesses(&g, L, H, attr_b, attr_w, 0, 8, &w_t2);
    const t8 = nowMs();

    const s4_ok = root.w_cf_w == root.cf_b;
    if (!s4_ok) util.warn("[T394] {d}x{d}: S4 colour inversion FAILED\n", .{ w, h });

    // local aliases for the JSON builder
    const GV = g.V;
    const GE = g.E_edges;
    const GS = g.sink_edges;
    const GM = g.child_misses;
    const GPM = g.pass_misses;
    const GLP = g.legal_positions;
    const PE = g.E_edges - (g.V - g.sink_edges);
    const TB = ab.target_size;
    const TW = aw.target_size;
    const AB = ab.size;
    const ABP = ab.pops;
    const ABL = ab.max_level;
    const AW = aw.size;
    const AWP = aw.pops;
    const RL = root.l_b;
    const RH = root.h_b;
    const RCFB = root.cf_b;
    const RCFW = root.cf_w;
    const RWRW = root.w_cf_w;
    const P0 = buckets.pin0;
    const P0BF = buckets.pin0_both_false;
    const P0V = buckets.pin0_violations;
    const WIT = &w_t2;
    const NW = n_t2;
    const NE = buckets.neither;
    const NEP0 = buckets.neither_pin0;
    const NED = buckets.neither_decisive;
    const NEBR = buckets.neither_br;
    const SO = buckets.some;
    const SOP0 = buckets.some_pin0;
    const SOD = buckets.some_decisive;
    const SOBR = buckets.some_br;
    const BKLH = buckets.lh;
    const BKLP = buckets.lh_pos;
    const BKLN = buckets.lh_neg;
    const BKLZ = buckets.lh_zero;
    const BKBB = buckets.br_black;
    const BKBW = buckets.br_white;
    const CN = controls.null_ok;
    const CS1 = controls.s1_ok;
    const CS2 = controls.s2_ok;
    const CS3 = controls.s3_ok;
    const CS4 = s4_ok;
    const CP = controls.planted_ok;
    const VBB = vb_b.checked;
    const VBV = vb_b.violations;
    const VBS = vb_b.sampled;
    const VWB = vb_w.checked;
    const VWV = vb_w.violations;
    const VWS = vb_w.sampled;
    const CT0 = t1 - t0;
    const CT1 = t2 - t1;
    const CT2 = t3 - t2;
    const CT3 = t4 - t3;
    const CT4 = t5 - t4;
    const CT5 = t6 - t5;
    const CT6 = t7 - t6;
    const CT7 = t8 - t7;

    // calibrations: the I5 register's 4×4 E = 565,402,416 counts PLACEMENT
    // edges only; my E_total also counts passes=0 pass edges (one per
    // passes=0 entry = V - sink_edges). Recover the placement count:
    const placement_edges = g.E_edges - (g.V - g.sink_edges);
    const e4_match = if (w == 4 and h == 4) placement_edges == 565_402_416 else false;
    const pin0_3x3_match = if (w == 3 and h == 3) buckets.pin0 == 1248 else false;
    const pin0_4x4_match = if (w == 4 and h == 4) buckets.pin0 == 895_216 else false;
    const CAL_KIND: []const u8 = if (calib3x3 != null) "C3" else "C1C2";
    const C3V = if (calib3x3) |c3| c3.v_match else false;
    const C3CV = if (calib3x3) |c3| c3.v_closure else 0;
    const C3TV = if (calib3x3) |c3| c3.v_table else 0;
    const C3M = if (calib3x3) |c3| c3.lh_mismatches else 0;
    const C3C = if (calib3x3) |c3| c3.checked else 0;
    const C1 = e4_match;
    const C2A = pin0_3x3_match;
    const C2B = pin0_4x4_match;

    // JSON object
    var j = Json{};
    defer j.deinit();
    var size_buf: [8]u8 = undefined;
    const size_str = try std.fmt.bufPrint(&size_buf, "{d}x{d}", .{ w, h });
    try j.open();
    try j.key("size");
    try j.str(size_str);
    try j.comma();
    try j.key("mode");
    try j.str(if (S.table_mode) "wzo2" else "closure");
    try j.comma();
    try j.key("graph");
    try j.open();
    try j.key("V");
    try j.int(GV);
    try j.comma();
    try j.key("E_edges");
    try j.int(GE);
    try j.comma();
    try j.key("sink_edges");
    try j.int(GS);
    try j.comma();
    try j.key("child_misses");
    try j.int(GM);
    try j.comma();
    try j.key("pass_misses");
    try j.int(GPM);
    try j.comma();
    try j.key("placement_edges");
    try j.int(PE);
    try j.comma();
    try j.key("legal_positions");
    try j.int(GLP);
    try j.close();
    try j.comma();
    try j.key("targets");
    try j.open();
    try j.key("T_B");
    try j.int(TB);
    try j.comma();
    try j.key("T_W");
    try j.int(TW);
    try j.close();
    try j.comma();
    try j.key("attractors");
    try j.open();
    try j.key("B");
    try j.open();
    try j.key("size");
    try j.int(AB);
    try j.comma();
    try j.key("pops");
    try j.int(ABP);
    try j.comma();
    try j.key("max_level");
    try j.int(ABL);
    try j.close();
    try j.comma();
    try j.key("W");
    try j.open();
    try j.key("size");
    try j.int(AW);
    try j.comma();
    try j.key("pops");
    try j.int(AWP);
    try j.close();
    try j.close();
    try j.comma();
    try j.key("root");
    try j.open();
    try j.key("L");
    try j.int(RL);
    try j.comma();
    try j.key("H");
    try j.int(RH);
    try j.comma();
    try j.key("cfB");
    try j.bool_(RCFB);
    try j.comma();
    try j.key("cfW");
    try j.bool_(RCFW);
    try j.comma();
    try j.key("w_root_cfW");
    try j.bool_(RWRW);
    try j.close();
    try j.comma();
    try j.key("T2");
    try j.open();
    try j.key("pin0");
    try j.int(P0);
    try j.comma();
    try j.key("pin0_both_false");
    try j.int(P0BF);
    try j.comma();
    try j.key("violations");
    try j.int(P0V);
    try j.comma();
    try j.key("witnesses");
    try j.lit("[");
    for (0..NW) |i| {
        const ww = WIT[i];
        if (i > 0) try j.comma();
        try j.open();
        try j.key("colex");
        try j.int(ww.colex);
        try j.comma();
        try j.key("side");
        try j.int(ww.side);
        try j.comma();
        try j.key("ko");
        try j.int(ww.ko);
        try j.comma();
        try j.key("passes");
        try j.int(ww.passes);
        try j.comma();
        try j.key("L");
        try j.int(ww.l);
        try j.comma();
        try j.key("H");
        try j.int(ww.h);
        try j.comma();
        try j.key("cfB");
        try j.bool_(ww.cf_b);
        try j.comma();
        try j.key("cfW");
        try j.bool_(ww.cf_w);
        try j.comma();
        try j.key("areaB");
        try j.int(ww.area_b);
        try j.comma();
        try j.key("areaW");
        try j.int(ww.area_w);
        try j.comma();
        try j.key("forcibleB");
        try j.int(ww.forcible_area_b);
        try j.comma();
        try j.key("forcibleW");
        try j.int(ww.forcible_area_w);
        try j.close();
    }
    try j.lit("]");
    try j.close();
    try j.comma();
    try j.key("T3");
    try j.open();
    try j.key("neither");
    try j.int(NE);
    try j.comma();
    try j.key("neither_pin0");
    try j.int(NEP0);
    try j.comma();
    try j.key("neither_decisive");
    try j.int(NED);
    try j.comma();
    try j.key("neither_br");
    try j.int(NEBR);
    try j.comma();
    try j.key("some");
    try j.int(SO);
    try j.comma();
    try j.key("some_pin0");
    try j.int(SOP0);
    try j.comma();
    try j.key("some_decisive");
    try j.int(SOD);
    try j.comma();
    try j.key("some_br");
    try j.int(SOBR);
    try j.close();
    try j.comma();
    try j.key("buckets");
    try j.open();
    try j.key("lh");
    try j.int(BKLH);
    try j.comma();
    try j.key("lh_pos");
    try j.int(BKLP);
    try j.comma();
    try j.key("lh_neg");
    try j.int(BKLN);
    try j.comma();
    try j.key("lh_zero");
    try j.int(BKLZ);
    try j.comma();
    try j.key("br_black");
    try j.int(BKBB);
    try j.comma();
    try j.key("br_white");
    try j.int(BKBW);
    try j.close();
    try j.comma();
    try j.key("controls");
    try j.open();
    try j.key("null");
    try j.bool_(CN);
    try j.comma();
    try j.key("s1");
    try j.bool_(CS1);
    try j.comma();
    try j.key("s2");
    try j.bool_(CS2);
    try j.comma();
    try j.key("s3");
    try j.bool_(CS3);
    try j.comma();
    try j.key("s4");
    try j.bool_(CS4);
    try j.comma();
    try j.key("planted");
    try j.bool_(CP);
    try j.close();
    try j.comma();
    try j.key("verify");
    try j.open();
    try j.key("B");
    try j.open();
    try j.key("checked");
    try j.int(VBB);
    try j.comma();
    try j.key("violations");
    try j.int(VBV);
    try j.comma();
    try j.key("sampled");
    try j.bool_(VBS);
    try j.close();
    try j.comma();
    try j.key("W");
    try j.open();
    try j.key("checked");
    try j.int(VWB);
    try j.comma();
    try j.key("violations");
    try j.int(VWV);
    try j.comma();
    try j.key("sampled");
    try j.bool_(VWS);
    try j.close();
    try j.close();
    try j.comma();
    try j.key("cost_ms");
    try j.open();
    try j.key("graph");
    try j.int(CT0);
    try j.comma();
    try j.key("preds");
    try j.int(CT1);
    try j.comma();
    try j.key("targets");
    try j.int(CT2);
    try j.comma();
    try j.key("fixpoint");
    try j.int(CT3);
    try j.comma();
    try j.key("attrB");
    try j.int(CT4);
    try j.comma();
    try j.key("attrW");
    try j.int(CT5);
    try j.comma();
    try j.key("verify");
    try j.int(CT6);
    try j.comma();
    try j.key("stats");
    try j.int(CT7);
    try j.close();
    try j.comma();
    try j.key("calibration");
    try j.open();
    try j.key("kind");
    try j.str(CAL_KIND);
    if (CAL_KIND.len == 2) {
        // C3 (3x3 closure-vs-table)
        try j.comma();
        try j.key("C3_closure_eq_table");
        try j.bool_(C3V);
        try j.comma();
        try j.key("closure_V");
        try j.int(C3CV);
        try j.comma();
        try j.key("table_V");
        try j.int(C3TV);
        try j.comma();
        try j.key("C3_lh_mismatches");
        try j.int(C3M);
        try j.comma();
        try j.key("checked");
        try j.int(C3C);
    } else {
        try j.comma();
        try j.key("C1_E4x4_match");
        try j.bool_(C1);
        try j.comma();
        try j.key("C2_pin0_3x3");
        try j.bool_(C2A);
        try j.comma();
        try j.key("C2_pin0_4x4");
        try j.bool_(C2B);
    }
    try j.close();
    try j.close();

    gpa.free(attr_b);
    gpa.free(attr_w);
    if (L.len > 0) gpa.free(L);
    if (H.len > 0) gpa.free(H);
    g.deinit();
    return j.buf.toOwnedSlice(gpa);
}

// ────────────────────────────────────────────────────────────────────────────
// tests
// ────────────────────────────────────────────────────────────────────────────

test "T394: colex round-trip 2x2" {
    const pos = [_]i8{ 1, 0, -1, 0 };
    const c = vb_movegen.colexFromPos(2, 2, &pos);
    const back = vb_movegen.posFromColex(2, 2, c);
    try std.testing.expectEqualSlices(i8, &pos, &back);
}

test "T394: state key distinguishes states" {
    const S = Solver(3, 2);
    const s1 = S.State{ .colex = 5, .side = 0, .ko = S.NONE, .passes = 1 };
    const s2 = S.State{ .colex = 5, .side = 0, .ko = S.NONE, .passes = 1 };
    const s3 = S.State{ .colex = 5, .side = 1, .ko = S.NONE, .passes = 1 };
    const s4 = S.State{ .colex = 5, .side = 0, .ko = 2, .passes = 0 };
    try std.testing.expectEqual(s1.key(), s2.key());
    try std.testing.expect(s1.key() != s3.key());
    try std.testing.expect(s1.key() != s4.key());
}

test "T394: key byte round-trip" {
    const S = Solver(4, 4);
    const s = S.State{ .colex = 123, .side = 1, .ko = 7, .passes = 0 };
    const kb = S.keyByte(s, 5);
    try std.testing.expectEqual(@as(u8, 1), S.sideOfKb(kb));
    try std.testing.expectEqual(@as(u8, 7), S.koOfKb(kb, 5));
    try std.testing.expectEqual(@as(u8, 0), S.passesOfKb(kb, 5));
}
