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
// Task: T114 · Role: auditor · Model: Opus 5 · Date: 2026-07-30
//
// ADR-0006 (eye-prune) CALIBRATION BATTERY.
//
// The 2026-07-29 falsification (docs/evidence/ADR-0006/) reported 0/1050
// disagreements at 3x3 with a single random-cell calibration. This battery
// adds what that run did not have:
//
//   A. Hand-labelled KNOWN-GOOD / KNOWN-BAD predicate fixtures (genuine eyes
//      vs false eyes, one-eye groups, big-eye space, opponent eyes).
//   B. A transcription cross-check of the SECOND implementation of the
//      predicate (solve.zig's private is_own_eye) against rules.zig's.
//   C. An exhaustive class scan: for every legal position and side, how many
//      legal goban moves the prune removes -- in particular the PRUNE-ALL
//      class (self-eye-fill is the ONLY legal goban move), and how many of
//      those are already is_settled terminals (where the comparison is
//      vacuous).
//   D. Score equivalence with vs without the prune, over an explicitly
//      NON-VACUOUS denominator, with a history-correct (ko_ref-tainted) memo.
//   E. Memo soundness: the 2026-07-29 harness memoised (pos, side, passes)
//      unconditionally under positional superko. solve.zig does not (it only
//      caches when ko_ref >= d). This section measures whether that
//      difference changes any answer.
//   F. Mutant calibration: four PLAUSIBLE wrong implementations of the
//      predicate (not random cells), each scored for detection rate.
//
// Build: zig build-exe -O ReleaseFast src/eyeprune_battery.zig
// Run:   tools/runner -- ./weizigo-eyeprune-battery [sections]
//
// No engine file is modified; rules.zig / terminal.zig / solve.zig are read.

const std = @import("std");
const print = std.debug.print;

// ---- prune variants ---------------------------------------------------------
//
// `adr0006` is the shipped predicate. Everything else is either the control
// (`none`) or a deliberate mutant used to measure the battery's discriminating
// power.

const Prune = enum {
    none, // control: no prune at all (the ground truth arm)
    adr0006, // shipped: all neighbours are own Benson-alive stones
    m1_naive, // MUTANT (over-prune): all neighbours own stones, Benson ignored
    m2_libs2, // MUTANT (over-prune): "alive" := chain has >= 2 liberties
    m3_any, // MUTANT (gross over-prune): >= 1 neighbour is an own alive stone
    m4_interior, // MUTANT (under-prune control): only points with 4 real neighbours

    fn name(self: Prune) []const u8 {
        return switch (self) {
            .none => "none (control)",
            .adr0006 => "ADR-0006 (shipped)",
            .m1_naive => "M1 naive-eye (no Benson)",
            .m2_libs2 => "M2 two-liberty 'alive'",
            .m3_any => "M3 any-alive-neighbour",
            .m4_interior => "M4 interior-only (under-prune)",
        };
    }
};

// ---- per-goban-size battery -------------------------------------------------

fn Battery(comptime w: usize, comptime h: usize) type {
    return struct {
        const R = @import("rules.zig").Rules(w, h);
        const X = @import("colex.zig").Indexer(w, h);
        const E = @import("enumerate.zig").Enumerator(w, h);

        const n = w * h;
        const Pos = R.Pos;
        const Self = @This();

        const UNDEF: i8 = -128;
        const KO_CLEAN: usize = std.math.maxInt(usize);
        const MAX_LINE: usize = 8192;

        // ---- prune masks ----------------------------------------------------

        /// Liberty count of the chain occupying `p` (0 if empty).
        fn chainLiberties(pos: *const Pos, p: usize) u32 {
            if (pos[p] == 0) return 0;
            const colour = pos[p];
            var seen = [_]bool{false} ** n;
            var lib = [_]bool{false} ** n;
            var stack: [n]usize = undefined;
            var sp: usize = 1;
            stack[0] = p;
            seen[p] = true;
            while (sp > 0) {
                sp -= 1;
                const q = stack[sp];
                var nb: [4]usize = undefined;
                const cnt = R.neighbors(q, &nb);
                for (nb[0..cnt]) |r| {
                    if (pos[r] == 0) {
                        lib[r] = true;
                    } else if (pos[r] == colour and !seen[r]) {
                        seen[r] = true;
                        stack[sp] = r;
                        sp += 1;
                    }
                }
            }
            var c: u32 = 0;
            for (lib) |b| {
                if (b) c += 1;
            }
            return c;
        }

        /// Per-cell "this empty point is skipped by move generation" mask for
        /// `colour` under prune variant `pr`.
        fn pruneMask(pos: *const Pos, colour: i8, pr: Prune) [n]bool {
            var mask = [_]bool{false} ** n;
            if (pr == .none) return mask;

            const alive = R.benson_alive(pos, colour);

            for (0..n) |p| {
                if (pos[p] != 0) continue;
                var nb: [4]usize = undefined;
                const cnt = R.neighbors(p, &nb);
                mask[p] = switch (pr) {
                    .none => false,
                    .adr0006 => R.is_own_eye(pos, p, colour, &alive),
                    .m1_naive => blk: {
                        for (nb[0..cnt]) |q| {
                            if (pos[q] * colour <= 0) break :blk false;
                        }
                        break :blk true;
                    },
                    .m2_libs2 => blk: {
                        for (nb[0..cnt]) |q| {
                            if (pos[q] * colour <= 0) break :blk false;
                            if (chainLiberties(pos, q) < 2) break :blk false;
                        }
                        break :blk true;
                    },
                    .m3_any => blk: {
                        for (nb[0..cnt]) |q| {
                            if (pos[q] * colour > 0 and alive[q]) break :blk true;
                        }
                        break :blk false;
                    },
                    .m4_interior => blk: {
                        if (cnt != 4) break :blk false;
                        break :blk R.is_own_eye(pos, p, colour, &alive);
                    },
                };
            }
            return mask;
        }

        // ---- history (positional superko) -----------------------------------

        const History = struct {
            boards: [MAX_LINE]Pos = undefined,
            len: usize = 0,

            fn push(self: *History, b: *const Pos) void {
                if (self.len >= MAX_LINE) @panic("eyeprune_battery: MAX_LINE exceeded");
                self.boards[self.len] = b.*;
                self.len += 1;
            }
            fn pop(self: *History) void {
                self.len -= 1;
            }
            /// Index of the earliest ply repeating `b`, or null.
            fn repeatsIndex(self: *const History, b: *const Pos) ?usize {
                var i: usize = 0;
                while (i < self.len) : (i += 1) {
                    if (std.mem.eql(i8, &self.boards[i], b)) return i;
                }
                return null;
            }
        };

        // ---- solver ----------------------------------------------------------
        //
        // Semantics match oracle.zig / solve.zig: area (Chinese) scoring,
        // Black-positive, positional superko (pass exempt), terminal on double
        // pass or is_settled.
        //
        // `memo` selects the caching rule -- the three rules in play in this
        // project, kept side by side so the difference is measured, not assumed:
        //
        //   .exact  -- key includes an order-independent hash of the FULL set of
        //              positions in the game line. Under positional superko the
        //              value of a node is a function of exactly (position, side,
        //              passes, set-of-seen-positions), so this memo is exact by
        //              construction. It is the ground truth arm here.
        //   .koref  -- solve.zig's production rule: cache a passes==0 node only
        //              when every superko ban in its subtree referenced a ply at
        //              or below the node itself (ko_ref >= d). Sound but weaker.
        //   .always -- the 2026-07-29 eyeprune_falsify.zig rule: cache every
        //              (pos, side, passes) node regardless of history. NOT sound
        //              under superko; retained to measure whether it mattered.

        const MemoRule = enum { exact, koref, always };

        const Res = struct { value: i8, ko_ref: usize };

        const ExactKey = struct { set: u64, idx: u32, side: u8, passes: u8 };

        /// Per-position random word for the order-independent (XOR) set hash.
        /// Computed (splitmix64) rather than tabulated: a table would be
        /// 3^16 u64 at 4x4 and blows up the compiler.
        fn zobOf(idx: u64) u64 {
            var z = idx +% 0x9E3779B97F4A7C15;
            z = (z ^ (z >> 30)) *% 0xBF58476D1CE4E5B9;
            z = (z ^ (z >> 27)) *% 0x94D049BB133111EB;
            return z ^ (z >> 31);
        }

        const Solver = struct {
            memo: []i8, // X.total * 2 entries, indexed (colex, side) -- flat rules
            exact: std.AutoHashMap(ExactKey, i8),
            rule: MemoRule,
            prune: Prune,
            share_memo: bool,
            nodes: u64 = 0,
            budget: u64 = std.math.maxInt(u64),
            aborted: bool = false,
            hist: History = .{},
            set_hash: u64 = 0,

            fn clear(self: *Solver) void {
                @memset(self.memo, UNDEF);
                self.exact.clearRetainingCapacity();
            }

            fn key(idx: u64, to_move: i8) usize {
                return @intCast((idx << 1) | @as(u64, @intFromBool(to_move <= 0)));
            }

            fn solve(self: *Solver, pos: *const Pos, to_move: i8, passes: u8) Res {
                self.nodes += 1;
                if (self.nodes > self.budget) {
                    self.aborted = true;
                    return .{ .value = 0, .ko_ref = 0 };
                }
                if (passes >= 2) return .{ .value = R.area_score(pos), .ko_ref = KO_CLEAN };
                if (R.is_settled(pos)) return .{ .value = R.area_score(pos), .ko_ref = KO_CLEAN };

                const d = self.hist.len - 1;
                const idx = X.colex_from_pos(pos);
                const hashable = (passes == 0) or (self.rule == .exact);
                const k = key(idx, to_move);
                const ek = ExactKey{
                    .set = self.set_hash,
                    .idx = @intCast(idx),
                    .side = @intFromBool(to_move <= 0),
                    .passes = passes,
                };
                if (hashable) {
                    if (self.rule == .exact) {
                        if (self.exact.get(ek)) |v| return .{ .value = v, .ko_ref = KO_CLEAN };
                    } else if (self.memo[k] != UNDEF) {
                        return .{ .value = self.memo[k], .ko_ref = KO_CLEAN };
                    }
                }

                const maximizing = to_move > 0;
                var best: i8 = if (maximizing) -127 else 127;
                var ko_ref: usize = KO_CLEAN;

                const mask = pruneMask(pos, to_move, self.prune);
                for (0..n) |p| {
                    if (pos[p] != 0) continue;
                    if (mask[p]) continue;
                    const child = R.pos_from_move(pos, to_move, p) catch continue;
                    if (self.hist.repeatsIndex(&child)) |j| {
                        if (j < ko_ref) ko_ref = j;
                        continue;
                    }
                    self.hist.push(&child);
                    const cz = zobOf(X.colex_from_pos(&child));
                    self.set_hash ^= cz;
                    const r = self.solve(&child, -to_move, 0);
                    self.set_hash ^= cz;
                    self.hist.pop();
                    if (self.aborted) return .{ .value = 0, .ko_ref = 0 };
                    if (r.ko_ref < ko_ref) ko_ref = r.ko_ref;
                    if (maximizing) {
                        if (r.value > best) best = r.value;
                    } else {
                        if (r.value < best) best = r.value;
                    }
                }

                // pass: goban unchanged, exempt from superko
                {
                    const rp = self.solve(pos, -to_move, passes + 1);
                    if (self.aborted) return .{ .value = 0, .ko_ref = 0 };
                    if (rp.ko_ref < ko_ref) ko_ref = rp.ko_ref;
                    if (maximizing) {
                        if (rp.value > best) best = rp.value;
                    } else {
                        if (rp.value < best) best = rp.value;
                    }
                }

                switch (self.rule) {
                    .exact => {
                        // A cache is never load-bearing: when it is full, drop it
                        // and carry on rather than answering from a stale key.
                        if (self.exact.count() >= MAX_EXACT_ENTRIES) self.exact.clearRetainingCapacity();
                        self.exact.put(ek, best) catch {
                            self.aborted = true;
                        };
                    },
                    .koref => if (passes == 0 and ko_ref >= d) {
                        self.memo[k] = best;
                    },
                    .always => if (passes == 0) {
                        self.memo[k] = best;
                    },
                }
                return .{ .value = best, .ko_ref = ko_ref };
            }

            /// Fresh-start value of `pos` with `to_move` to play.
            fn value(self: *Solver, pos: *const Pos, to_move: i8) ?i8 {
                if (!self.share_memo) self.clear();
                self.hist.len = 0;
                self.hist.push(pos);
                self.set_hash = zobOf(X.colex_from_pos(pos));
                self.aborted = false;
                const saved = self.nodes;
                self.budget = saved + PER_ROOT_BUDGET;
                const r = self.solve(pos, to_move, 0);
                if (self.aborted) return null;
                return r.value;
            }
        };

        const PER_ROOT_BUDGET: u64 = 2_000_000;
        /// ~24 B/entry: 6M entries is roughly 300 MB, well inside the runner's
        /// 4 GB RSS ceiling. A root that needs more is reported UNRESOLVED
        /// rather than silently answered from a memo that is not exact.
        const MAX_EXACT_ENTRIES: u32 = 2_000_000;

        fn makeSolver(alloc: std.mem.Allocator, pr: Prune, rule: MemoRule, share: bool) !*Solver {
            const s = try alloc.create(Solver);
            s.* = .{
                .memo = try alloc.alloc(i8, @intCast(X.total * 2)),
                .exact = std.AutoHashMap(ExactKey, i8).init(alloc),
                .rule = rule,
                .prune = pr,
                .share_memo = share,
            };
            s.clear();
            return s;
        }

        fn freeSolver(alloc: std.mem.Allocator, s: *Solver) void {
            s.exact.deinit();
            alloc.free(s.memo);
            alloc.destroy(s);
        }

        // ---- enumeration ------------------------------------------------------

        fn allLegal(alloc: std.mem.Allocator) !std.ArrayList(Pos) {
            var out: std.ArrayList(Pos) = .empty;
            var digits = [_]u8{0} ** n;
            var pos: Pos = [_]i8{0} ** n;
            while (true) {
                if (E.is_legal(&pos)) try out.append(alloc, pos);
                var i: usize = 0;
                while (i < n) : (i += 1) {
                    if (digits[i] == 2) {
                        digits[i] = 0;
                        pos[i] = 0;
                        continue;
                    }
                    digits[i] += 1;
                    pos[i] = if (digits[i] == 1) 1 else -1;
                    break;
                }
                if (i == n) break;
            }
            return out;
        }

        /// Legal goban moves for `colour`, and how many of them the shipped
        /// prune removes. Superko is not applied (fresh position, no history).
        fn moveCensus(pos: *const Pos, colour: i8) struct { legal: u32, pruned: u32 } {
            const mask = pruneMask(pos, colour, .adr0006);
            var legal: u32 = 0;
            var pruned: u32 = 0;
            for (0..n) |p| {
                if (pos[p] != 0) continue;
                _ = R.pos_from_move(pos, colour, p) catch continue;
                legal += 1;
                if (mask[p]) pruned += 1;
            }
            return .{ .legal = legal, .pruned = pruned };
        }

        // ---- reporting helpers -------------------------------------------------

        fn boardStr(pos: *const Pos, buf: []u8) []const u8 {
            var i: usize = 0;
            for (0..h) |r| {
                for (0..w) |c| {
                    const v = pos[r * w + c];
                    buf[i] = if (v > 0) 'X' else if (v < 0) 'O' else '.';
                    i += 1;
                }
                if (r + 1 < h) {
                    buf[i] = '/';
                    i += 1;
                }
            }
            return buf[0..i];
        }

        const label = std.fmt.comptimePrint("{d}x{d}", .{ w, h });

        // ---- SECTION C: class scan ---------------------------------------------

        const ClassScan = struct {
            positions: u64 = 0,
            pairs: u64 = 0,
            prune_none: u64 = 0, // prune removes nothing
            prune_some: u64 = 0, // prune removes some but not all legal moves
            prune_all: u64 = 0, // EVERY legal goban move is an own-eye fill
            prune_all_settled: u64 = 0, // ...and is_settled already fired
            prune_all_live: u64 = 0, // ...and it did NOT (the live known-bad class)
            nonvacuous: u64 = 0, // !settled and prune removes >= 1 move at root
            eyepos: u64 = 0, // positions with >= 1 Benson-alive true eye (2026-07-29 denominator)
            eyepos_settled: u64 = 0, // ...of which is_settled already fires
            settled: u64 = 0, // settled positions overall
        };

        /// Streaming (no storage) so it reaches 4x4. Positions with no
        /// candidate eye cannot have a pruned move, so Benson is skipped there.
        fn classScan(alloc: std.mem.Allocator) !ClassScan {
            _ = alloc;
            var s = ClassScan{};
            var shown: u32 = 0;
            var digits = [_]u8{0} ** n;
            var pos: Pos = [_]i8{0} ** n;
            while (true) {
                if (E.is_legal(&pos)) {
                    s.positions += 1;
                    s.pairs += 2;
                    if (!maybeHasEye(&pos)) {
                        s.prune_none += 2;
                    } else {
                        const settled = R.is_settled(&pos);
                        var has_eye = false;
                        inline for (.{ @as(i8, 1), @as(i8, -1) }) |colour| {
                            const mc = moveCensus(&pos, colour);
                            if (mc.pruned > 0) has_eye = true;
                            if (mc.pruned == 0) {
                                s.prune_none += 1;
                            } else if (mc.pruned < mc.legal) {
                                s.prune_some += 1;
                            } else {
                                s.prune_all += 1;
                                if (settled) s.prune_all_settled += 1 else {
                                    s.prune_all_live += 1;
                                    if (shown < 8) {
                                        var buf: [64]u8 = undefined;
                                        print("      PRUNE-ALL & NOT settled: {s}  {s} to move ({d} legal, all eyes)\n", .{ boardStr(&pos, &buf), if (colour > 0) "Black" else "White", mc.legal });
                                        shown += 1;
                                    }
                                }
                            }
                            if (!settled and mc.pruned > 0) s.nonvacuous += 1;
                        }
                        if (has_eye) {
                            s.eyepos += 1;
                            if (settled) s.eyepos_settled += 1;
                        }
                        if (settled) s.settled += 1;
                    }
                }
                var i: usize = 0;
                while (i < n) : (i += 1) {
                    if (digits[i] == 2) {
                        digits[i] = 0;
                        pos[i] = 0;
                        continue;
                    }
                    digits[i] += 1;
                    pos[i] = if (digits[i] == 1) 1 else -1;
                    break;
                }
                if (i == n) break;
            }
            return s;
        }

        // ---- SECTION D/F: score comparison --------------------------------------

        const CmpResult = struct {
            checked: u64 = 0,
            touched: u64 = 0,
            disagree: u64 = 0,
            unresolved: u64 = 0,
            nodes_a: u64 = 0,
            nodes_b: u64 = 0,
        };

        /// Compare prune variant `pr` against the no-prune control over every
        /// (legal position, side) pair that is non-vacuous for the SHIPPED
        /// prune (not settled, and the shipped prune removes >= 1 root move),
        /// plus -- for mutants -- every pair the mutant itself touches.
        fn compareAgainstControl(
            alloc: std.mem.Allocator,
            pr: Prune,
            baseline: Prune,
            verbose: bool,
            max_report: u32,
            all_pairs: bool,
        ) !CmpResult {
            var out = CmpResult{};
            var list = try allLegal(alloc);
            defer list.deinit(alloc);

            const ctrl = try makeSolver(alloc, baseline, .exact, false);
            const test_solver = try makeSolver(alloc, pr, .exact, false);
            defer freeSolver(alloc, ctrl);
            defer freeSolver(alloc, test_solver);

            var reported: u32 = 0;
            for (list.items) |pos| {
                if (R.is_settled(&pos)) continue; // both arms return before movegen
                inline for (.{ @as(i8, 1), @as(i8, -1) }) |colour| {
                    var touched = false;
                    {
                        const m_ship = pruneMask(&pos, colour, baseline);
                        const m_test = pruneMask(&pos, colour, pr);
                        for (0..n) |p| {
                            if (pos[p] != 0) continue;
                            _ = R.pos_from_move(&pos, colour, p) catch continue;
                            if (m_ship[p] or m_test[p]) touched = true;
                        }
                    }
                    if (touched or all_pairs) {
                        if (touched) out.touched += 1;
                        const va = ctrl.value(&pos, colour);
                        const vb = test_solver.value(&pos, colour);
                        out.checked += 1;
                        if (va == null or vb == null) {
                            out.unresolved += 1;
                        } else if (va.? != vb.?) {
                            out.disagree += 1;
                            if (verbose and reported < max_report) {
                                var buf: [64]u8 = undefined;
                                print("      DISAGREE {s}: {s}  {s} to move  control={d} {s}={d}\n", .{ label, boardStr(&pos, &buf), if (colour > 0) "Black" else "White", va.?, pr.name(), vb.? });
                                reported += 1;
                            }
                        }
                    }
                }
            }
            out.nodes_a = ctrl.nodes;
            out.nodes_b = test_solver.nodes;
            return out;
        }

        // ---- SECTION G: structural lemma battery ---------------------------------
        //
        // The game-value comparison (Section D) is the strongest test but its
        // sound control is intractable above a handful of stones. These lemmas
        // are the premises ADR-0006's soundness argument actually rests on, and
        // each is exactly checkable per position with NO search -- so they run
        // exhaustively on gobans where Section D cannot, including 4x4.
        //
        //   L1  the eye fill is a legal move for the mover
        //       (if it were not, the prune would be removing nothing)
        //   L2  area score is invariant under the fill
        //       ("does not gain a point ... it is yours either way")
        //   L3  the opponent cannot play the eye point: it is suicide
        //       ("the opponent already cannot play in those eyes")
        //   L4  the fill captures nothing (stone count rises by exactly one)
        //   L7  the fill never CREATES unconditional life for the mover:
        //       benson_alive(P_filled, c) \ {e} is a subset of benson_alive(P, c)
        //       ("only ever risking its life" -- the dominance premise)
        //   L8  the fill never creates unconditional life for the OPPONENT
        //       (not required by the ADR; measured because it would be a real
        //       way in which the move changes the game)

        const LemmaScan = struct {
            positions: u64 = 0,
            eye_positions: u64 = 0,
            eyes: u64 = 0,
            l1: u64 = 0,
            l2: u64 = 0,
            l3: u64 = 0,
            l4: u64 = 0,
            l7: u64 = 0,
            l8: u64 = 0,
        };

        fn stones(pos: *const Pos) u32 {
            var c: u32 = 0;
            for (pos) |v| {
                if (v != 0) c += 1;
            }
            return c;
        }

        /// Cheap pre-filter: does any empty point have all its present
        /// neighbours occupied by one and the same colour? (Necessary condition
        /// for is_own_eye; avoids running Benson on the vast majority.)
        fn maybeHasEye(pos: *const Pos) bool {
            for (0..n) |p| {
                if (pos[p] != 0) continue;
                var nb: [4]usize = undefined;
                const cnt = R.neighbors(p, &nb);
                var col: i8 = 0;
                var ok = true;
                for (nb[0..cnt]) |q| {
                    if (pos[q] == 0) {
                        ok = false;
                        break;
                    }
                    if (col == 0) col = pos[q] else if (col != pos[q]) {
                        ok = false;
                        break;
                    }
                }
                if (ok and col != 0) return true;
            }
            return false;
        }

        fn lemmaCheck(s: *LemmaScan, pos: *const Pos, pr: Prune) void {
            var counted = false;
            inline for (.{ @as(i8, 1), @as(i8, -1) }) |c| {
                const alive = R.benson_alive(pos, c);
                const mask = pruneMask(pos, c, pr);
                for (0..n) |e| {
                    if (pos[e] != 0) continue;
                    if (!mask[e]) continue;
                    s.eyes += 1;
                    if (!counted) {
                        s.eye_positions += 1;
                        counted = true;
                    }

                    // L1 -- the fill is legal for the mover
                    const filled = R.pos_from_move(pos, c, e) catch {
                        s.l1 += 1;
                        continue;
                    };

                    // L2 -- area score unchanged
                    if (R.area_score(&filled) != R.area_score(pos)) s.l2 += 1;

                    // L3 -- the opponent's play there is suicide
                    if (R.pos_from_move(pos, -c, e)) |_| {
                        s.l3 += 1;
                    } else |err| {
                        if (err != error.Suicide) s.l3 += 1;
                    }

                    // L4 -- nothing is captured by the fill
                    if (stones(&filled) != stones(pos) + 1) s.l4 += 1;

                    // L7 -- the fill creates no new unconditional life for the mover
                    const alive_after = R.benson_alive(&filled, c);
                    for (0..n) |q| {
                        if (q == e) continue;
                        if (alive_after[q] and !alive[q]) {
                            s.l7 += 1;
                            break;
                        }
                    }

                    // L8 -- ...nor for the opponent
                    const opp_before = R.benson_alive(pos, -c);
                    const opp_after = R.benson_alive(&filled, -c);
                    for (0..n) |q| {
                        if (opp_after[q] and !opp_before[q]) {
                            s.l8 += 1;
                            break;
                        }
                    }
                }
            }
        }

        /// Exhaustive streaming scan over every legal position (no storage).
        fn lemmaScanExhaustive(pr: Prune) LemmaScan {
            var s = LemmaScan{};
            var digits = [_]u8{0} ** n;
            var pos: Pos = [_]i8{0} ** n;
            while (true) {
                if (maybeHasEye(&pos) and E.is_legal(&pos)) {
                    s.positions += 1;
                    lemmaCheck(&s, &pos, pr);
                }
                var i: usize = 0;
                while (i < n) : (i += 1) {
                    if (digits[i] == 2) {
                        digits[i] = 0;
                        pos[i] = 0;
                        continue;
                    }
                    digits[i] += 1;
                    pos[i] = if (digits[i] == 1) 1 else -1;
                    break;
                }
                if (i == n) break;
            }
            return s;
        }

        /// Random-sample scan, for gobans too large to enumerate (5x5).
        fn lemmaScanSampled(pr: Prune, samples: u64, seed: u64) LemmaScan {
            var s = LemmaScan{};
            var prng = std.Random.DefaultPrng.init(seed);
            const rnd = prng.random();
            var pos: Pos = undefined;
            for (0..samples) |_| {
                for (0..n) |i| {
                    const r = rnd.intRangeAtMost(u8, 0, 4);
                    pos[i] = if (r == 1 or r == 3) 1 else if (r == 2) -1 else 0;
                }
                if (maybeHasEye(&pos) and E.is_legal(&pos)) {
                    s.positions += 1;
                    lemmaCheck(&s, &pos, pr);
                }
            }
            return s;
        }

        // ---- SECTION H: the retrograde table as a SOUND no-prune control -------
        //
        // Section D's control (a from-scratch unpruned forward search) is not
        // computable. But the project already owns an unpruned solver whose
        // cost does not blow up: the retrograde value iteration
        // (`retro.zig` `sweep`, `apply_eye_prune = false`, ADR-0009 Decision 3)
        // scores every slot over the FULL legal move set. On slots that are not
        // KO_SENSITIVE its stored value is a single exact fresh-start number
        // produced without the prune.
        //
        // Comparing the eye-pruned forward search against those slots is
        // therefore the sound version of the ADR-0006 test -- and it is exactly
        // the standing test ADR-0009:118-123 promised (`GLOBAL.ADR0006-TEST`),
        // executed here with an explicit denominator.

        const ArtScan = struct {
            slots: u64 = 0,
            undef: u64 = 0,
            ko_sensitive: u64 = 0,
            from_forward: u64 = 0,
            checked: u64 = 0,
            touched: u64 = 0, // ...of which the prune removes >= 1 root move
            disagree: u64 = 0,
            unresolved: u64 = 0,
            nodes: u64 = 0,
        };

        fn artifactControl(
            alloc: std.mem.Allocator,
            dec: *const @import("artifact.zig").Decoded,
            touched_only: bool,
            stride: u64,
        ) !ArtScan {
            var out = ArtScan{};
            const fwd = try makeSolver(alloc, .adr0006, .koref, true);
            defer freeSolver(alloc, fwd);

            var reported: u32 = 0;
            var idx: u64 = 0;
            while (idx < X.total) : (idx += 1) {
                if (stride > 1 and idx % stride != 0) continue;
                const pos = X.pos_from_colex(idx);
                if (!E.is_legal(&pos)) continue;
                inline for (.{ @as(i8, 1), @as(i8, -1) }) |colour| {
                    const stored = if (colour > 0) dec.vb[@intCast(idx)] else dec.vw[@intCast(idx)];
                    const flags = if (colour > 0) dec.fb[@intCast(idx)] else dec.fw[@intCast(idx)];
                    out.slots += 1;
                    if (stored == UNDEF) {
                        out.undef += 1;
                    } else if (flags & 1 != 0) {
                        out.ko_sensitive += 1; // bracket, not a single value: not a control
                    } else if (flags & 2 != 0) {
                        // FROM_FORWARD: written by the finisher, which applies the
                        // prune. Comparing against it would be circular.
                        out.from_forward += 1;
                    } else {
                        var touched = false;
                        const m = pruneMask(&pos, colour, .adr0006);
                        for (0..n) |q| {
                            if (pos[q] != 0) continue;
                            _ = R.pos_from_move(&pos, colour, q) catch continue;
                            if (m[q]) touched = true;
                        }
                        if (touched or !touched_only) {
                            if (touched) out.touched += 1;
                            const v = fwd.value(&pos, colour);
                            out.checked += 1;
                            if (v == null) {
                                out.unresolved += 1;
                            } else if (v.? != stored) {
                                out.disagree += 1;
                                if (reported < 12) {
                                    var buf: [64]u8 = undefined;
                                    print("      DISAGREE {s}: {s}  {s} to move  retrograde(full moves)={d}  forward(eye-pruned)={d}\n", .{ label, boardStr(&pos, &buf), if (colour > 0) "Black" else "White", stored, v.? });
                                    reported += 1;
                                }
                            }
                        }
                    }
                }
            }
            out.nodes = fwd.nodes;
            return out;
        }

        // ---- SECTION J: the live PRUNE-ALL class, valued ------------------------
        //
        // Section C finds (position, side) pairs where the prune removes EVERY
        // legal goban move at a node that is NOT an is_settled terminal. There
        // the pruned search has only the pass edge. This scan values each such
        // pair with the eye-pruned forward search and compares it against the
        // unpruned retrograde table -- the one class where "the prune removed
        // the only move" could actually change an answer.

        const LiveScan = struct {
            live_pairs: u64 = 0,
            comparable: u64 = 0, // non-KO_SENSITIVE, non-FROM_FORWARD, defined
            disagree: u64 = 0,
            unresolved: u64 = 0,
            skipped_ko: u64 = 0,
            skipped_undef: u64 = 0,
        };

        fn livePruneAllScan(
            alloc: std.mem.Allocator,
            dec: *const @import("artifact.zig").Decoded,
        ) !LiveScan {
            var out = LiveScan{};
            const fwd = try makeSolver(alloc, .adr0006, .koref, true);
            defer freeSolver(alloc, fwd);

            var reported: u32 = 0;
            var digits = [_]u8{0} ** n;
            var pos: Pos = [_]i8{0} ** n;
            while (true) {
                if (E.is_legal(&pos) and maybeHasEye(&pos) and !R.is_settled(&pos)) {
                    inline for (.{ @as(i8, 1), @as(i8, -1) }) |colour| {
                        const mc = moveCensus(&pos, colour);
                        if (mc.pruned > 0 and mc.pruned == mc.legal) {
                            out.live_pairs += 1;
                            const idx: usize = @intCast(X.colex_from_pos(&pos));
                            const stored = if (colour > 0) dec.vb[idx] else dec.vw[idx];
                            const flags = if (colour > 0) dec.fb[idx] else dec.fw[idx];
                            var buf: [64]u8 = undefined;
                            if (stored == UNDEF) {
                                out.skipped_undef += 1;
                            } else if (flags & 3 != 0) {
                                out.skipped_ko += 1;
                            } else {
                                const v = fwd.value(&pos, colour);
                                out.comparable += 1;
                                if (v == null) {
                                    out.unresolved += 1;
                                } else if (v.? != stored) {
                                    out.disagree += 1;
                                    print("      DISAGREE {s}  {s} to move  retrograde={d}  eye-pruned forward={d}\n", .{ boardStr(&pos, &buf), if (colour > 0) "Black" else "White", stored, v.? });
                                } else if (reported < 6) {
                                    print("      ok  {s}  {s} to move  {d} legal moves, all pruned -> pass only; both = {d}\n", .{ boardStr(&pos, &buf), if (colour > 0) "Black" else "White", mc.legal, stored });
                                    reported += 1;
                                }
                            }
                        }
                    }
                }
                var i: usize = 0;
                while (i < n) : (i += 1) {
                    if (digits[i] == 2) {
                        digits[i] = 0;
                        pos[i] = 0;
                        continue;
                    }
                    digits[i] += 1;
                    pos[i] = if (digits[i] == 1) 1 else -1;
                    break;
                }
                if (i == n) break;
            }
            return out;
        }

        // ---- SECTION E: memo soundness -------------------------------------------

        /// Does the 2026-07-29 harness's unconditional memo change any answer
        /// relative to solve.zig's ko_ref-tainted rule? Run per-root (no memo
        /// sharing) so this reproduces that harness's configuration exactly.
        fn memoSoundness(alloc: std.mem.Allocator, pr: Prune, rule_a: MemoRule, rule_b: MemoRule) !CmpResult {
            var out = CmpResult{};
            var list = try allLegal(alloc);
            defer list.deinit(alloc);

            const safe = try makeSolver(alloc, pr, rule_a, false);
            const unsafe = try makeSolver(alloc, pr, rule_b, false);
            defer freeSolver(alloc, safe);
            defer freeSolver(alloc, unsafe);

            var reported: u32 = 0;
            for (list.items) |pos| {
                if (R.is_settled(&pos)) continue;
                inline for (.{ @as(i8, 1), @as(i8, -1) }) |colour| {
                    var touched = false;
                    {
                        const m = pruneMask(&pos, colour, pr);
                        for (0..n) |p| {
                            if (pos[p] != 0) continue;
                            _ = R.pos_from_move(&pos, colour, p) catch continue;
                            if (m[p]) touched = true;
                        }
                    }
                    if (touched) {
                    const va = safe.value(&pos, colour);
                    const vb = unsafe.value(&pos, colour);
                    out.checked += 1;
                    if (va == null or vb == null) {
                        out.unresolved += 1;
                    } else if (va.? != vb.?) {
                        out.disagree += 1;
                        if (reported < 8) {
                            var buf: [64]u8 = undefined;
                            print("      MEMO DIFF {s}: {s}  {s} to move  A={d} B={d}\n", .{ label, boardStr(&pos, &buf), if (colour > 0) "Black" else "White", va.?, vb.? });
                            reported += 1;
                        }
                    }
                    }
                }
            }
            out.nodes_a = safe.nodes;
            out.nodes_b = unsafe.nodes;
            return out;
        }
    };
}

// ---- SECTION A: hand-labelled predicate fixtures ------------------------------

var fixtures_run: u32 = 0;
var fixtures_failed: u32 = 0;

fn checkEye(
    comptime w: usize,
    comptime h: usize,
    name: []const u8,
    kind: []const u8, // "KNOWN-GOOD" / "KNOWN-BAD"
    pos: *const [w * h]i8,
    cell: usize,
    colour: i8,
    expect_eye: bool,
) void {
    const R = @import("rules.zig").Rules(w, h);
    const E = @import("enumerate.zig").Enumerator(w, h);
    const alive = R.benson_alive(pos, colour);
    const got = R.is_own_eye(pos, cell, colour, &alive);
    fixtures_run += 1;
    const ok = (got == expect_eye);
    if (!ok) fixtures_failed += 1;
    const legal = E.is_legal(pos);
    print("  [{s}] {s:<44} cell {d:>2} {s}  expect prune={s:<5} got={s:<5} {s}{s}\n", .{
        kind,
        name,
        cell,
        if (colour > 0) "B" else "W",
        if (expect_eye) "true" else "false",
        if (got) "true" else "false",
        if (ok) "PASS" else "*** FAIL ***",
        if (legal) "" else "  (POSITION ILLEGAL!)",
    });
}

/// Naive predicate: all neighbours are own stones, Benson ignored. Reported
/// alongside known-bad fixtures to show what the plausible wrong implementation
/// would have done there.
fn naiveEye(comptime w: usize, comptime h: usize, pos: *const [w * h]i8, cell: usize, colour: i8) bool {
    const R = @import("rules.zig").Rules(w, h);
    if (pos[cell] != 0) return false;
    var nb: [4]usize = undefined;
    const cnt = R.neighbors(cell, &nb);
    for (nb[0..cnt]) |q| {
        if (pos[q] * colour <= 0) return false;
    }
    return true;
}

// The position ADR-0006 was validated on (verbatim from src/solve.zig:395).
const dead_white = [_]i8{
    1, 1, 1, 0,  1,
    1, 0, 1, -1, 1,
    1, 1, 1, 1,  1,
    1, 1, 1, 0,  1,
    1, 1, 1, 1,  1,
};

fn sectionA() void {
    print("\n=== SECTION A — hand-labelled predicate fixtures ===\n", .{});
    print("Each row asserts whether the shipped predicate MUST fire (KNOWN-GOOD:\n", .{});
    print("the eye is genuine and filling it is dominated) or MUST NOT fire\n", .{});
    print("(KNOWN-BAD: the point is not a genuine eye of an unconditionally\n", .{});
    print("alive group, so removing the move could remove a needed move).\n\n", .{});

    // --- 3x3 -----------------------------------------------------------------
    const f1 = [_]i8{ 1, 0, 1, 1, 1, 1, 0, 0, 0 }; // X.X / XXX / ...
    checkEye(3, 3, "3x3 alive group, single-point eye", "KNOWN-GOOD", &f1, 1, 1, true);
    checkEye(3, 3, "3x3 same group, open-territory point", "KNOWN-BAD ", &f1, 7, 1, false);
    checkEye(3, 3, "3x3 same board, opponent's view of the eye", "KNOWN-BAD ", &f1, 1, -1, false);

    const f2 = [_]i8{ 1, 0, 0, 1, 1, 1, 0, 0, 0 }; // X.. / XXX / ...
    checkEye(3, 3, "3x3 alive group, 2-point eye space (left)", "KNOWN-BAD ", &f2, 1, 1, false);
    checkEye(3, 3, "3x3 alive group, 2-point eye space (right)", "KNOWN-BAD ", &f2, 2, 1, false);

    const f3 = [_]i8{ 1, 0, 1, 0, 1, 0, 0, 0, 0 }; // X.X / .X. / ...
    checkEye(3, 3, "3x3 FALSE EYE (three unconnected stones)", "KNOWN-BAD ", &f3, 1, 1, false);
    print("        ^ naive all-neighbours-own-stones predicate would say: {s}\n", .{if (naiveEye(3, 3, &f3, 1, 1)) "PRUNE (wrong)" else "no prune"});

    const f5 = [_]i8{ 1, 0, 1, 1, 1, 1, 1, 0, 1 }; // X.X / XXX / X.X
    checkEye(3, 3, "3x3 PRUNE-ALL: both eyes of an alive group", "KNOWN-GOOD", &f5, 1, 1, true);
    checkEye(3, 3, "3x3 PRUNE-ALL: second eye", "KNOWN-GOOD", &f5, 7, 1, true);
    {
        const R3 = @import("rules.zig").Rules(3, 3);
        print("        ^ is_settled = {s}; Black legal board moves = 2, both pruned;\n", .{if (R3.is_settled(&f5)) "TRUE (search terminates before move generation)" else "false"});
        print("          White legal board moves = 0 (both points are suicide).\n", .{});
    }

    // --- 5x5 -----------------------------------------------------------------
    const g1 = [_]i8{
        1, 0, 1, 0, 1,
        1, 1, 1, 1, 1,
        0, 0, 0, 0, 0,
        0, 0, 0, 0, 0,
        0, 0, 0, 0, 0,
    };
    checkEye(5, 5, "5x5 two-eye alive group, eye A", "KNOWN-GOOD", &g1, 1, 1, true);
    checkEye(5, 5, "5x5 two-eye alive group, eye B", "KNOWN-GOOD", &g1, 3, 1, true);
    checkEye(5, 5, "5x5 same group, open point below", "KNOWN-BAD ", &g1, 10, 1, false);
    checkEye(5, 5, "5x5 same board, White's view of eye A", "KNOWN-BAD ", &g1, 1, -1, false);

    const g2 = [_]i8{
        0, 1, -1, 0, 0,
        1, 0, 1,  0, 0,
        0, 1, 0,  0, 0,
        0, 0, 0,  0, 0,
        0, 0, 0,  0, 0,
    };
    checkEye(5, 5, "5x5 FALSE EYE (cuttable, no Benson chain)", "KNOWN-BAD ", &g2, 6, 1, false);
    print("        ^ naive all-neighbours-own-stones predicate would say: {s}\n", .{if (naiveEye(5, 5, &g2, 6, 1)) "PRUNE (wrong)" else "no prune"});

    const g3 = [_]i8{
        1, 0, 1, 0, 0,
        1, 1, 1, 0, 0,
        0, 0, 0, 0, 0,
        0, 0, 0, 0, 0,
        0, 0, 0, 0, 0,
    };
    checkEye(5, 5, "5x5 ONE-EYE group (not Benson-alive)", "KNOWN-BAD ", &g3, 1, 1, false);
    print("        ^ naive all-neighbours-own-stones predicate would say: {s}\n", .{if (naiveEye(5, 5, &g3, 1, 1)) "PRUNE (wrong)" else "no prune"});

    // --- the ADR's own anchor -------------------------------------------------
    checkEye(5, 5, "5x5 dead_white (ADR-0006 anchor), eye at 6", "KNOWN-GOOD", &dead_white, 6, 1, true);
    checkEye(5, 5, "5x5 dead_white, eye at 18", "KNOWN-GOOD", &dead_white, 18, 1, true);
    checkEye(5, 5, "5x5 dead_white, capture point at 3", "KNOWN-BAD ", &dead_white, 3, 1, false);
    {
        const R5 = @import("rules.zig").Rules(5, 5);
        print("        ^ is_settled(dead_white) = {s} (the search must actually play)\n", .{if (R5.is_settled(&dead_white)) "true" else "false"});
    }

    print("\n  fixtures: {d} run, {d} failed\n", .{ fixtures_run, fixtures_failed });
}

// ---- SECTION B: cross-implementation check ------------------------------------
//
// solve.zig carries a SECOND, private copy of the predicate, hard-coded to a
// 5-wide grid. It cannot be imported (it is not pub), so it is transcribed here
// verbatim from src/solve.zig:168-188 and differentially tested against
// rules.zig's generic implementation. This detects transcription/indexing
// divergence between the two engines, not a defect shared by both.

fn solveZigIsOwnEye(pos: *const [25]i8, p: u8, to_move: i8, alive: *const [25]bool) bool {
    const row = p / 5;
    const col = p % 5;
    if (row > 0) {
        const q = p - 5;
        if (pos[q] * to_move <= 0 or !alive[q]) return false;
    }
    if (row < 4) {
        const q = p + 5;
        if (pos[q] * to_move <= 0 or !alive[q]) return false;
    }
    if (col > 0) {
        const q = p - 1;
        if (pos[q] * to_move <= 0 or !alive[q]) return false;
    }
    if (col < 4) {
        const q = p + 1;
        if (pos[q] * to_move <= 0 or !alive[q]) return false;
    }
    return true;
}

fn sectionB() void {
    print("\n=== SECTION B — solve.zig vs rules.zig predicate (5x5) ===\n", .{});
    const R5 = @import("rules.zig").Rules(5, 5);
    var prng = std.Random.DefaultPrng.init(0x0006_0730);
    const rnd = prng.random();
    var mismatches: u64 = 0;
    var cells_compared: u64 = 0;
    var eyes_seen: u64 = 0;
    const BOARDS: u32 = 200_000;
    for (0..BOARDS) |_| {
        var b: [25]i8 = undefined;
        for (0..25) |i| {
            const r = rnd.intRangeAtMost(u8, 0, 4);
            b[i] = if (r == 1 or r == 3) 1 else if (r == 2) -1 else 0; // stone-dense
        }
        inline for (.{ @as(i8, 1), @as(i8, -1) }) |colour| {
            const alive = R5.benson_alive(&b, colour);
            for (0..25) |p| {
                if (b[p] != 0) continue;
                const a = R5.is_own_eye(&b, p, colour, &alive);
                const c = solveZigIsOwnEye(&b, @intCast(p), colour, &alive);
                cells_compared += 1;
                if (a) eyes_seen += 1;
                if (a != c) mismatches += 1;
            }
        }
    }
    // and the fixtures, which are far more eye-dense than random gobans
    for ([_][25]i8{dead_white}) |b| {
        inline for (.{ @as(i8, 1), @as(i8, -1) }) |colour| {
            const alive = R5.benson_alive(&b, colour);
            for (0..25) |p| {
                if (b[p] != 0) continue;
                cells_compared += 1;
                if (R5.is_own_eye(&b, p, colour, &alive) != solveZigIsOwnEye(&b, @intCast(p), colour, &alive)) mismatches += 1;
            }
        }
    }
    print("  random 5x5 boards: {d}   empty cells compared: {d}   eyes found: {d}\n", .{ BOARDS, cells_compared, eyes_seen });
    print("  mismatches (rules.zig vs solve.zig transcript): {d}  -> {s}\n", .{ mismatches, if (mismatches == 0) "AGREE" else "*** DIVERGENT ***" });
    if (eyes_seen == 0) print("  WARNING: no eyes in the random sample -- this check is vacuous\n", .{});
}

/// Monotonic milliseconds (std.time.Timer is gone in Zig 0.16).
fn nowMs() u64 {
    var ts: std.c.timespec = undefined;
    _ = std.c.clock_gettime(.MONOTONIC, &ts);
    return @as(u64, @intCast(ts.sec)) * 1000 + @as(u64, @intCast(ts.nsec)) / 1_000_000;
}

// ---- main ----------------------------------------------------------------------

pub fn main(init: std.process.Init) !void {
    const alloc = std.heap.page_allocator;

    var want_c = true;
    var want_d = true;
    var want_e = true;
    var want_f = true;
    var want_g = true;
    var want_h = true;
    var want_i = true;
    var h_only_4x3 = false;
    var want_j = true;
    {
        var args = std.process.Args.Iterator.init(init.minimal.args);
        _ = args.next();
        var any = false;
        var c = false;
        var d = false;
        var e = false;
        var f = false;
        var g = false;
        var hh = false;
        var ii = false;
        var jj = false;
        while (args.next()) |a| {
            any = true;
            if (std.mem.indexOfScalar(u8, a, 'C') != null) c = true;
            if (std.mem.indexOfScalar(u8, a, 'D') != null) d = true;
            if (std.mem.indexOfScalar(u8, a, 'E') != null) e = true;
            if (std.mem.indexOfScalar(u8, a, 'F') != null) f = true;
            if (std.mem.indexOfScalar(u8, a, 'G') != null) g = true;
            if (std.mem.indexOfScalar(u8, a, 'H') != null) hh = true;
            if (std.mem.indexOfScalar(u8, a, 'I') != null) ii = true;
            if (std.mem.indexOfScalar(u8, a, 'J') != null) jj = true;
            if (std.mem.indexOfScalar(u8, a, '4') != null) h_only_4x3 = true;
        }
        if (any) {
            want_c = c;
            want_d = d;
            want_e = e;
            want_f = f;
            want_g = g;
            want_h = hh;
            want_i = ii;
            want_j = jj;
        }
    }

    print("=== T114 — ADR-0006 eye-prune calibration battery ===\n", .{});
    print("Model: Opus 5   Date: 2026-07-30   Source: src/eyeprune_battery.zig\n", .{});
    print("Rules: area (Chinese) scoring, Black-positive, positional superko\n", .{});
    print("       (pass exempt), terminal on double pass or is_settled.\n", .{});

    sectionA();
    sectionB();

    const B22 = Battery(2, 2);
    const B32 = Battery(3, 2);
    const B33 = Battery(3, 3);

    if (want_c) {
        print("\n=== SECTION C — prune class scan (exhaustive per board) ===\n", .{});
        print("  For every legal position x side: how many legal board moves the\n", .{});
        print("  shipped prune removes. PRUNE-ALL = self-eye-fill is the ONLY legal\n", .{});
        print("  board move -- the known-bad class T114 asks for.\n\n", .{});
        inline for (.{ B22, B32, B33, Battery(4, 3), Battery(4, 4) }) |B| {
            const s = try B.classScan(alloc);
            print("  [{s}] legal positions {d}, (position,side) pairs {d}\n", .{ B.label, s.positions, s.pairs });
            print("      prune removes nothing : {d}\n", .{s.prune_none});
            print("      prune removes some    : {d}\n", .{s.prune_some});
            print("      PRUNE-ALL             : {d}  (settled {d} / NOT settled {d})\n", .{ s.prune_all, s.prune_all_settled, s.prune_all_live });
            print("      non-vacuous pairs     : {d}  (not settled AND prune removes >=1 root move)\n", .{s.nonvacuous});
            print("      settled positions     : {d}  (among eye-candidate positions only)\n", .{s.settled});
            print("      positions with >=1 eye: {d}  (of which settled: {d} -> comparison vacuous there)\n\n", .{ s.eyepos, s.eyepos_settled });
        }
    }

    if (want_d) {
        print("\n=== SECTION D — score equivalence, prune vs no prune ===\n", .{});
        print("  Denominator: every non-settled (position, side) pair where the prune\n", .{});
        print("  removes at least one ROOT move. The control (no prune) is exact:\n", .{});
        print("  history-set-keyed memo, per-root, budget 2M nodes / 2M entries.\n\n", .{});
        inline for (.{ B22, B32, B33 }) |B| {
            const t0 = nowMs();
            const r = try B.compareAgainstControl(alloc, .adr0006, .none, true, 20, false);
            const secs = @as(f64, @floatFromInt(nowMs() - t0)) / 1000.0;
            print("  [{s}] checked {d} pairs (of which {d} root-touched)   DISAGREEMENTS {d}   unresolved {d}   nodes {d}/{d}   {d:.1}s\n", .{ B.label, r.checked, r.touched, r.disagree, r.unresolved, r.nodes_a, r.nodes_b, secs });
        }
    }

    if (want_e) {
        print("\n=== SECTION E — memo soundness of the 2026-07-29 harness ===\n", .{});
        print("  eyeprune_falsify.zig caches every (pos,side,passes) node under\n", .{});
        print("  positional superko; solve.zig caches only ko_ref-clean nodes.\n", .{});
        print("  Does the difference change an answer? (prune arm, per-root memo)\n\n", .{});
        inline for (.{ B22, B32, B33 }) |B| {
            inline for (.{
                .{ B.MemoRule.koref, B.MemoRule.always, "solve.zig ko_ref  vs  2026-07-29 always-cache" },
                .{ B.MemoRule.exact, B.MemoRule.koref, "exact history-set vs  solve.zig ko_ref        " },
                .{ B.MemoRule.exact, B.MemoRule.always, "exact history-set vs  2026-07-29 always-cache " },
            }) |cfg| {
                const t0 = nowMs();
                const r = try B.memoSoundness(alloc, .adr0006, cfg[0], cfg[1]);
                const secs = @as(f64, @floatFromInt(nowMs() - t0)) / 1000.0;
                print("  [{s}] {s}  checked {d:>5}  DIFFERENCES {d}  unresolved {d}  {d:.1}s\n", .{ B.label, cfg[2], r.checked, r.disagree, r.unresolved, secs });
            }
        }
    }

    if (want_f) {
        print("\n=== SECTION F — mutant calibration ===\n", .{});
        print("  Four PLAUSIBLE wrong predicates, scored against the SHIPPED arm\n", .{});
        print("  (the no-prune control is not computable -- see Section D).\n", .{});
        print("  M4 is the deliberate NULL control: it only ever prunes FEWER\n", .{});
        print("  moves than ADR-0006, so if ADR-0006 is sound M4 must be clean.\n\n", .{});
        // 2x2/3x2 only: at 3x3 each mutant arm costs ~10 min against the shipped
        // arm, and Section I calibrates the lemma battery there far more cheaply.
        inline for (.{ B22, B32 }) |B| {
            inline for (.{ Prune.m1_naive, Prune.m2_libs2, Prune.m3_any, Prune.m4_interior }) |pr| {
                const t0 = nowMs();
                const r = try B.compareAgainstControl(alloc, pr, .adr0006, false, 0, false);
                const secs = @as(f64, @floatFromInt(nowMs() - t0)) / 1000.0;
                const rate: f64 = if (r.checked > 0)
                    @as(f64, @floatFromInt(r.disagree)) / @as(f64, @floatFromInt(r.checked)) * 100.0
                else
                    0.0;
                print("  [{s}] {s:<32} checked {d:>6}  detected {d:>6} ({d:>5.1}%)  unresolved {d}  {d:.1}s\n", .{ B.label, pr.name(), r.checked, r.disagree, rate, r.unresolved, secs });
            }
            print("\n", .{});
        }
    }

    if (want_g) {
        const B43 = Battery(4, 3);
        const B44 = Battery(4, 4);
        const B55 = Battery(5, 5);
        print("\n=== SECTION G — structural lemma battery (exhaustive to 4x4) ===\n", .{});
        print("  The premises ADR-0006's soundness argument rests on, checked\n", .{});
        print("  exactly per position with no search. Columns are VIOLATIONS.\n", .{});
        print("  L1 fill legal for mover | L2 area score invariant | L3 opponent\n", .{});
        print("  play is suicide | L4 fill captures nothing | L7 fill creates no\n", .{});
        print("  new unconditional life for the mover | L8 ...nor the opponent.\n\n", .{});
        print("  {s:<10} {s:>12} {s:>12} {s:>10}   {s:>4} {s:>4} {s:>4} {s:>4} {s:>4} {s:>4}\n", .{ "board", "eye-positions", "eyes checked", "seconds", "L1", "L2", "L3", "L4", "L7", "L8" });
        inline for (.{ B22, B32, B33, B43, B44 }) |B| {
            const t0 = nowMs();
            const r = B.lemmaScanExhaustive(.adr0006);
            const secs = @as(f64, @floatFromInt(nowMs() - t0)) / 1000.0;
            print("  {s:<10} {d:>12} {d:>12} {d:>10.1}   {d:>4} {d:>4} {d:>4} {d:>4} {d:>4} {d:>4}\n", .{ B.label, r.eye_positions, r.eyes, secs, r.l1, r.l2, r.l3, r.l4, r.l7, r.l8 });
        }
        {
            const SAMPLES: u64 = 20_000_000;
            const t0 = nowMs();
            const r = B55.lemmaScanSampled(.adr0006, SAMPLES, 0x5555_0730);
            const secs = @as(f64, @floatFromInt(nowMs() - t0)) / 1000.0;
            print("  {s:<10} {d:>12} {d:>12} {d:>10.1}   {d:>4} {d:>4} {d:>4} {d:>4} {d:>4} {d:>4}  (SAMPLED, {d} draws)\n", .{ B55.label, r.eye_positions, r.eyes, secs, r.l1, r.l2, r.l3, r.l4, r.l7, r.l8, SAMPLES });
        }
    }

    if (want_i) {
        print("\n=== SECTION I — lemma-battery calibration (mutant predicates) ===\n", .{});
        print("  Section G reports zero violations for the shipped predicate. That\n", .{});
        print("  is only evidence if the same lemmas FIRE on a wrong predicate.\n", .{});
        print("  Each mutant is substituted for is_own_eye and rescanned.\n\n", .{});
        print("  {s:<10} {s:<32} {s:>10} {s:>10}   {s:>6} {s:>6} {s:>6} {s:>6} {s:>6} {s:>6}\n", .{ "board", "predicate", "eye-pos", "eyes", "L1", "L2", "L3", "L4", "L7", "L8" });
        inline for (.{ B33, Battery(4, 3) }) |B| {
            inline for (.{ Prune.adr0006, Prune.m1_naive, Prune.m2_libs2, Prune.m3_any, Prune.m4_interior }) |pr| {
                const r = B.lemmaScanExhaustive(pr);
                print("  {s:<10} {s:<32} {d:>10} {d:>10}   {d:>6} {d:>6} {d:>6} {d:>6} {d:>6} {d:>6}\n", .{ B.label, pr.name(), r.eye_positions, r.eyes, r.l1, r.l2, r.l3, r.l4, r.l7, r.l8 });
            }
            print("\n", .{});
        }
    }

    if (want_j) {
        const artifact = @import("artifact.zig");
        print("\n=== SECTION J — the live PRUNE-ALL class at 4x4, valued ===\n", .{});
        print("  Pairs where the prune removes EVERY legal board move at a node\n", .{});
        print("  that is NOT an is_settled terminal: the pruned search has only\n", .{});
        print("  the pass edge there. Valued and compared against the unpruned\n", .{});
        print("  retrograde table.\n\n", .{});
        const path = "data/oracle-4x4-parallel.checkpoint.wzo";
        if (artifact.load(init.io, std.Io.Dir.cwd(), path, alloc)) |loaded| {
            var dec = loaded;
            defer dec.deinit();
            const t0 = nowMs();
            const r = try Battery(4, 4).livePruneAllScan(alloc, &dec);
            const secs = @as(f64, @floatFromInt(nowMs() - t0)) / 1000.0;
            print("\n  {s}\n", .{path});
            print("    live PRUNE-ALL pairs {d}   comparable {d}   (UNDEF {d}, KO/FROM_FORWARD {d})\n", .{ r.live_pairs, r.comparable, r.skipped_undef, r.skipped_ko });
            print("    DISAGREEMENTS {d}   unresolved {d}   {d:.1}s\n", .{ r.disagree, r.unresolved, secs });
        } else |err| {
            print("  {s}: LOAD FAILED ({s}) -- skipped\n", .{ path, @errorName(err) });
        }
    }

    if (want_h) {
        const artifact = @import("artifact.zig");
        print("\n=== SECTION H — retrograde table as a SOUND no-prune control ===\n", .{});
        print("  The retrograde value iteration (ADR-0009 Decision 3) uses the FULL\n", .{});
        print("  legal move set. On slots that are not KO_SENSITIVE its stored value\n", .{});
        print("  is an exact unpruned fresh-start score. Comparing the eye-pruned\n", .{});
        print("  forward search against those slots is the sound ADR-0006 test --\n", .{});
        print("  the standing test of ADR-0009:118-123, actually executed.\n\n", .{});
        // arg "4" restricts Section H to the 4x3 artifact (the slowest goban).
        const all_paths = [_][]const u8{
            "artifacts/oracle-2x2.wzo",
            "artifacts/oracle-3x2.wzo",
            "artifacts/oracle-3x3.wzo",
            "artifacts/oracle-4x3.wzo",
        };
        const paths: []const []const u8 = if (h_only_4x3) all_paths[3..] else all_paths[0..];
        for (paths, 0..) |path, pi_rel| {
            const pi: usize = if (h_only_4x3) 3 else pi_rel;
            var dec = artifact.load(init.io, std.Io.Dir.cwd(), path, alloc) catch |err| {
                print("  {s}: LOAD FAILED ({s}) -- skipped\n", .{ path, @errorName(err) });
                continue;
            };
            defer dec.deinit();
            const t0 = nowMs();
            // 4x3 is restricted to slots the prune actually touches at the root;
            // the smaller gobans are exhaustive over every non-KO_SENSITIVE slot.
            // 2x2/3x2: every non-KO slot. 3x3/4x3: restricted to slots where the
            // prune removes a move at the root -- exhaustive coverage there costs
            // more than the forward search can pay.
            const touched_only = (pi >= 2);
            const r = switch (pi) {
                0 => try B22.artifactControl(alloc, &dec, touched_only, 1),
                1 => try B32.artifactControl(alloc, &dec, touched_only, 1),
                2 => try B33.artifactControl(alloc, &dec, touched_only, 1),
                else => try Battery(4, 3).artifactControl(alloc, &dec, touched_only, 8),
            };
            const secs = @as(f64, @floatFromInt(nowMs() - t0)) / 1000.0;
            print("  {s}\n", .{path});
            print("    slots {d}  (UNDEF {d}, KO_SENSITIVE {d}, FROM_FORWARD {d} -> excluded, not independent)\n", .{ r.slots, r.undef, r.ko_sensitive, r.from_forward });
            print("    CHECKED {d}{s}{s}  of which prune-touched at root {d}\n", .{ r.checked, if (touched_only) " (root-touched only)" else " (every non-KO slot)", if (pi == 3) ", 1-in-8 colex sample" else "", r.touched });
            print("    DISAGREEMENTS {d}   unresolved {d}   forward nodes {d}   {d:.1}s\n\n", .{ r.disagree, r.unresolved, r.nodes, secs });
        }
    }

    print("\n=== battery complete ===\n", .{});
    print("fixtures failed: {d}\n", .{fixtures_failed});
}
