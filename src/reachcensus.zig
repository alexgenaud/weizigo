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
// REACHABLE KO-SENSITIVITY CENSUS — how often does PLAY land in the region
// where the engine's move-selection rule is undefined?
//
// `src/chainability.zig` measures ko-sensitivity SLOT-UNIFORMLY: every legal
// (position, side) in the table counts once, at a colex stride. That is the
// right denominator for auditing the artifact and the WRONG denominator for a
// player, because a player never samples slots uniformly — it walks game lines
// from the empty board. Slot-uniform ko-sensitivity at 4x4 is 21.27%
// (bin/weizigo-chainability data/oracle-4x4.checkpoint.wzo --sample 37), yet
// 16 of 19 plies (84%) of both saved 4x4 regression games are KO_SENSITIVE.
// This tool measures the second quantity directly.
//
// WHAT IS MEASURED. A game is played out from the empty board under a policy.
// Every DECISION NODE — the (position, side-to-move) pair standing at each ply,
// before the move is made — is one observation. The reported fraction is the
// share of those nodes whose artifact slot carries the KO_SENSITIVE flag
// (bit 0 of fb/fw, i.e. L < H). On the KO_SENSITIVE region a one-ply extremum
// over stored child values is not an evaluation at all (measured 2026-07-27,
// docs/research/ko-sensitive-chainability.md), so this fraction is exactly the
// share of its own moves the engine CANNOT certify as fresh-start optimal.
//
// THE MEASURE DEPENDS ON WHO IS PLAYING, so three policies are reported:
//   oracle -- both sides use the engine's own rule (see `chooseOracle`).
//             DETERMINISTIC: N games are N copies of one line. The tool counts
//             distinct lines so this cannot be misread.
//   random -- both sides uniform over PSK-legal moves, plus pass with a small
//             fixed probability. The "what does the space look like from the
//             empty board" control.
//   mixed  -- one side oracle, one side random; the side assignment alternates
//             by game index. This is the realistic human-vs-engine case and is
//             what the saved regression games are.
//   oracle-rt -- oracle, but ties that survive the full (value, captures, DTT)
//             ordering are broken at random instead of by cell order. Exists
//             only because plain `oracle` is a single line; it shows whether
//             that one line is representative of the engine's own play.
// For `mixed` and `oracle-rt` the tool additionally reports the fraction over
// ENGINE-TO-MOVE nodes only, which is the quantity the user's headline metric
// ("what fraction of MY moves are certified") actually asks for.
//
// UNDEF HANDLING. Unfilled slots hold the sentinel -128 (see src/gtp.zig).
// A KO_SENSITIVE flag on an UNDEF slot means nothing, so any game that visits
// an UNDEF decision node is EXCLUDED WHOLESALE from the belief statistics and
// counted separately. The policies still play through such nodes (the oracle
// rule reads children, not the node itself), so exclusion loses games, never
// changes play.
//
// TERMINATION: two consecutive passes, or a settled position (R.is_settled),
// or a hard ply cap. Cap hits are reported loudly; a nonzero cap-hit count
// means the mean-plies and late-game bucket numbers are censored.
// The settled-stop is a TRUNCATION the real GTP player does not perform: it
// plays on in a settled position (capturing dead stones) until pass is optimal.
// Since late plies are the LEAST ko-sensitive, truncating there BIASES THE
// FRACTION UPWARD. `--no-settled-stop` disables it, for the sensitivity check.
//
// LEGALITY is the real thing: positional superko against the actual game
// history (every position that has occurred, empty board included), plus
// rules.Rules(w,h) suicide/occupancy. No eye-prune — the players do not use one.
//
// ---------------------------------------------------------------------------
// SECOND MEASURE (--psk-binding, added 2026-07-28 for EXP-1): how often does
// POSITIONAL SUPERKO forbid a move that BASIC KO would allow?
//
// Positional superko (PSK) is a computer convention. Japan and Korea play basic
// ko with no-result for long cycles; China adjudicates rather than mechanically
// enforcing (docs/research/ruleset-options.md). So the decision-relevant
// question is not "is PSK solvable" but "does PSK ever actually bind?"
//
// DEFINITIONS USED HERE (stated because they are choices, not facts):
//   * history is indexed by PLY. Ply 0 = the empty board. A pass re-records the
//     unchanged board at the next ply index, so `bply[k]` is always the board
//     after k plies.
//   * a candidate move made at a node where `k` plies have been played produces
//     a child board that would sit at ply index `k+1`.
//   * DISTANCE d = (k+1) - j, where j is the LARGEST (most recent) ply index
//     whose board equals the child. Most-recent is the conservative choice: it
//     minimises d, so it under-counts the "silent long-range" bucket.
//   * BASIC KO forbids only the recreation of the position one ply ago, i.e.
//     exactly d == 2. (d == 1 is impossible: a move always changes the board.)
//   * PSK forbids d >= 2 of any size.
//   * therefore PSK-BINDING = PSK-illegal AND d >= 3: legal under basic ko,
//     illegal under PSK. Three buckets:
//       d == 2      ko-cycle repeat   -- basic ko already forbids it; NOT binding
//       d in 3..6   short-cycle       -- double/triple ko territory, visible
//       d > 6       silent long-range -- what no human or judge would notice
//   * a d > 6 event is additionally flagged ISOLATED when no d <= 6 repeat
//     occurred at this node or at any node in the previous 6 plies of the same
//     game. That is this tool's operational proxy for "not part of a
//     recognisable cycle"; it is a heuristic, not a definition of cycle.
//
// TWO POPULATIONS, both reported, because they answer different questions:
//   (1) ALL CANDIDATES -- every rules-legal move at every decision node,
//       whether or not the policy would pick it. "How much of the move space
//       does PSK remove?"
//   (2) THE CHOSEN MOVE -- a one-ply counterfactual: re-run the SAME policy at
//       the SAME node with basic-ko legality instead of PSK, and ask whether
//       the move it then picks is PSK-illegal. "Does PSK actually change what
//       gets played?" The counterfactual draws from a SEPARATE random stream,
//       so enabling --psk-binding cannot perturb the played game; every
//       ko-sensitivity number is byte-identical with and without the flag.
//       The game itself always continues under real PSK.
//
// --replay <gtp-transcript> replays a fixed line instead of playing games and
// prints the per-ply PSK ban list with distances. Used to cross-check against
// docs/research/ko-sensitive-chainability.md Measurement 2, which reports
// exactly one PSK ban per saved regression game, at ply 14.
// ---------------------------------------------------------------------------
//
// usage: weizigo-reachcensus <artifact.wzo> [--games N] [--seed S]
//                            [--ply-cap C] [--pass-prob PERMILLE]
//                            [--policy oracle|random|mixed|oracle-rt|all]
//                            [--no-settled-stop] [--trace K]
//                            [--psk-binding] [--replay FILE.gtp]
// --trace K prints the move sequence and per-ply KO_SENSITIVE flag of the first
// K games of each policy. Used to check the `oracle` mirror against the real
// GTP player (`zig build-exe src/gtp.zig`, then `genmove b` / `genmove w`).
// With --psk-binding, --trace also annotates each ply with the PSK repeats
// available there, as `{d=5 d=12}`.
const std = @import("std");
const rules = @import("rules.zig");
const colexmod = @import("colex.zig");
const artifact = @import("artifact.zig");

/// Sentinel stored in unfilled artifact slots. Same value src/gtp.zig uses.
const UNDEF: i8 = -128;

const Policy = enum {
    oracle,
    random,
    mixed,
    oracle_rt,

    fn label(p: Policy) []const u8 {
        return switch (p) {
            .oracle => "oracle",
            .random => "random",
            .mixed => "mixed",
            .oracle_rt => "oracle-rt",
        };
    }
};

/// Who drives a given side in a given game.
const Driver = enum { engine, rand };

/// Which repetition rule a legality test enforces.
///   psk      -- positional superko: no board that has EVER occurred.
///   basic_ko -- only the board one ply ago is forbidden.
const Legality = enum { psk, basic_ko };

/// Distances are tallied into a histogram clamped at this index.
const MAXD = 41;

/// PSK-binding tallies. All counts are over ALL games (UNDEF exclusion is a
/// belief-statistics concern; legality does not read the artifact at all).
const PskStats = struct {
    nodes: u64 = 0, // decision nodes scanned
    cand: u64 = 0, // rules-legal candidate moves (pass excluded)
    cand_bk: u64 = 0, // ... of which legal under basic ko
    rep_ko: u64 = 0, // PSK repeats at d == 2 (basic ko forbids these too)
    rep_short: u64 = 0, // PSK repeats at 3 <= d <= 6
    rep_long: u64 = 0, // PSK repeats at d > 6
    rep_long_isolated: u64 = 0, // ... with no d <= 6 repeat within 6 plies
    nodes_bind: u64 = 0, // nodes offering >= 1 binding candidate
    nodes_long: u64 = 0, // nodes offering >= 1 d > 6 candidate
    games_bind: u64 = 0,
    games_long: u64 = 0,
    max_d: u64 = 0,
    dist: [MAXD]u64 = [_]u64{0} ** MAXD,

    // counterfactual: the policy re-run under basic-ko legality only
    cf_nodes: u64 = 0,
    cf_moves: u64 = 0, // counterfactual chose a move (not a pass)
    cf_short: u64 = 0,
    cf_long: u64 = 0,
    cf_games: u64 = 0,
};

const NBUCKET = 9; // ply/4 clamped, last bucket is "32+"
const COLS = "ABCDEFGHJKLMNOPQRSTUVWXYZ"; // GTP letters, no 'I'

const Stats = struct {
    games: u64 = 0,
    clean_games: u64 = 0, // games with no UNDEF decision node
    undef_games: u64 = 0,
    undef_nodes: u64 = 0, // over ALL games
    cap_hits: u64 = 0,
    end_double_pass: u64 = 0,
    end_settled: u64 = 0,
    plies_all: u64 = 0, // over ALL games (mean plies denominator = games)

    nodes: u64 = 0, // clean games only
    ko_nodes: u64 = 0,
    eng_nodes: u64 = 0, // clean games, engine-to-move only
    eng_ko: u64 = 0,
    pergame_sum: f64 = 0, // sum over clean games of ko/nodes
    pergame_n: u64 = 0,

    bucket_nodes: [NBUCKET]u64 = [_]u64{0} ** NBUCKET,
    bucket_ko: [NBUCKET]u64 = [_]u64{0} ** NBUCKET,

    max_plies: u64 = 0,
    ply1_ko: u64 = 0, // clean games whose ply-1 (empty board, Black) node is flagged

    psk: PskStats = .{},
};

fn pct(num: u64, den: u64) f64 {
    if (den == 0) return 0;
    return 100.0 * @as(f64, @floatFromInt(num)) / @as(f64, @floatFromInt(den));
}

fn Census(comptime w: usize, comptime h: usize) type {
    return struct {
        const Self = @This();
        const R = rules.Rules(w, h);
        const X = colexmod.Indexer(w, h);
        const n = R.n;
        const Pos = R.Pos;
        const MAXCAP = 1024;

        d: *const artifact.Decoded,
        pos: Pos = [_]i8{0} ** n,
        hist: [MAXCAP + 4]Pos = undefined,
        hist_len: usize = 0,
        passes: u8 = 0,
        /// Ply-indexed board record: `bply[k]` is the board after k plies.
        /// Passes re-record the unchanged board, so the index is a true ply
        /// index (unlike `hist`, which only grows on stone placements).
        /// Used only for PSK-binding distances; legality still goes via `hist`.
        bply: [MAXCAP + 4]Pos = undefined,
        ply: u64 = 0,

        fn v0(s: *const Self, p: *const Pos, side: i8) i8 {
            const i: usize = @intCast(X.colex_from_pos(p));
            return if (side > 0) s.d.vb[i] else s.d.vw[i];
        }
        fn dtt0(s: *const Self, p: *const Pos, side: i8) u8 {
            const i: usize = @intCast(X.colex_from_pos(p));
            return if (side > 0) s.d.db[i] else s.d.dw[i];
        }
        fn kosens(s: *const Self, p: *const Pos, side: i8) bool {
            const i: usize = @intCast(X.colex_from_pos(p));
            const f = if (side > 0) s.d.fb[i] else s.d.fw[i];
            return f & 1 != 0;
        }
        fn seen(s: *const Self, p: *const Pos) bool {
            for (s.hist[0..s.hist_len]) |*b| {
                if (std.mem.eql(i8, b, p)) return true;
            }
            return false;
        }
        fn push(s: *Self, p: *const Pos) void {
            if (s.hist_len >= s.hist.len) @panic("reachcensus: history overflow");
            s.hist[s.hist_len] = p.*;
            s.hist_len += 1;
        }
        fn reset(s: *Self) void {
            s.pos = [_]i8{0} ** n;
            s.hist_len = 0;
            s.passes = 0;
            s.ply = 0;
            s.push(&s.pos); // the empty board has occurred (mirrors gtp.Session.reset)
            s.bply[0] = s.pos;
        }

        /// Record the board reached after `s.ply` plies. Call after `s.ply` has
        /// been incremented, for moves AND passes.
        fn recordPly(s: *Self) void {
            if (s.ply >= s.bply.len) @panic("reachcensus: ply record overflow");
            s.bply[s.ply] = s.pos;
        }

        /// The MOST RECENT ply index whose board equals `p`, or null. Used for
        /// the PSK repeat distance; most-recent minimises the distance, which
        /// is the conservative choice for the "silent long-range" bucket.
        fn matchPly(s: *const Self, p: *const Pos) ?u64 {
            var j: usize = s.ply + 1;
            while (j > 0) {
                j -= 1;
                if (std.mem.eql(i8, &s.bply[j], p)) return @intCast(j);
            }
            return null;
        }

        /// Is `child` forbidden by the given repetition rule?
        fn repForbidden(s: *const Self, child: *const Pos, mode: Legality) bool {
            return switch (mode) {
                .psk => s.seen(child),
                .basic_ko => s.ply >= 1 and std.mem.eql(i8, &s.bply[s.ply - 1], child),
            };
        }

        /// One decision node's worth of PSK-repeat information.
        const NodeScan = struct {
            cand: u32 = 0, // rules-legal candidates (occupancy/suicide only)
            cand_bk: u32 = 0, // ... minus the one basic ko forbids
            ko: u32 = 0, // d == 2
            short: u32 = 0, // 3 <= d <= 6
            long: u32 = 0, // d > 6
            /// per-cell repeat distance; 0 = no repeat / not a candidate
            dist: [n]u32 = [_]u32{0} ** n,
        };

        /// Enumerate every rules-legal move at the current node and classify
        /// its whole-board repeat, if any. Reads no artifact slot.
        fn scanNode(s: *const Self, side: i8, st: *PskStats) NodeScan {
            var r = NodeScan{};
            for (0..n) |p| {
                if (s.pos[p] != 0) continue;
                const child = R.pos_from_move(&s.pos, side, p) catch continue;
                r.cand += 1;
                if (!s.repForbidden(&child, .basic_ko)) r.cand_bk += 1;
                const j = s.matchPly(&child) orelse continue;
                const d: u64 = (s.ply + 1) - j;
                r.dist[p] = @intCast(@min(d, std.math.maxInt(u32)));
                if (d > st.max_d) st.max_d = d;
                st.dist[@intCast(@min(d, MAXD - 1))] += 1;
                if (d <= 2) r.ko += 1 else if (d <= 6) r.short += 1 else r.long += 1;
            }
            return r;
        }
        fn countColor(p: *const Pos, colour: i8) u16 {
            var c: u16 = 0;
            for (p) |x| {
                if (x == colour) c += 1;
            }
            return c;
        }

        /// V1(pos, side): `side` to move facing one standing pass. One ply of
        /// stored V0 lookups plus the ending pass. Copied from
        /// gtp.Session.v1_from_table (no PSK filter there, none here).
        fn v1_from_table(s: *const Self, p: *const Pos, side: i8) i8 {
            const maxing = side > 0;
            var best: i8 = R.area_score(p);
            for (0..n) |c| {
                if (p[c] != 0) continue;
                const ch = R.pos_from_move(p, side, c) catch continue;
                const v = s.v0(&ch, -side);
                if (v == UNDEF) continue;
                if (if (maxing) v > best else v < best) best = v;
            }
            return best;
        }

        const Choice = struct { cell: ?usize, value: i8, dtt: u8, caps: u16 = 0 };

        /// gtp.Session.pick verbatim: value (max/min), then MORE captures,
        /// then SMALLER dtt; ties beyond that keep the incumbent (cell order).
        fn pick(cur: ?Choice, mv: Choice, maxing: bool) ?Choice {
            if (cur == null) return mv;
            const c = cur.?;
            const vbetter = if (maxing) mv.value > c.value else mv.value < c.value;
            if (vbetter) return mv;
            if (mv.value != c.value) return c;
            if (mv.caps != c.caps) return if (mv.caps > c.caps) mv else c;
            if (mv.dtt != c.dtt) return if (mv.dtt < c.dtt) mv else c;
            return c;
        }

        /// The engine's rule, mirroring gtp.Session.choose: the extremum over
        /// PSK-legal children's STORED values with the pass edge as a
        /// candidate, the (value, captures, DTT) ordering, UNDEF children
        /// dropped, and the early-game "always play the opening" override.
        /// NOT mirrored: resign (gtp handles it above `choose`) and the
        /// sustained-loss bookkeeping that feeds it.
        /// `rt` = break surviving ties uniformly at random instead of by cell
        /// order (reservoir sampling over the incumbent-equal set).
        /// `leg` selects the repetition rule the candidate filter enforces.
        /// `.psk` is the real game; `.basic_ko` is used only by the
        /// --psk-binding counterfactual and never advances the real game.
        fn chooseOracle(s: *const Self, side: i8, rt: bool, rnd: std.Random, leg: Legality) Choice {
            const maxing = side > 0;
            const opp: i8 = -side;
            const opp_before = countColor(&s.pos, opp);
            const pass = Choice{
                .cell = null,
                .value = if (s.passes >= 1) R.area_score(&s.pos) else s.v1_from_table(&s.pos, -side),
                .dtt = if (s.passes >= 1) 0 else 1,
                .caps = 0,
            };
            var best: ?Choice = pass;
            var best_move: ?Choice = null;
            var ties_best: u64 = 1; // how many candidates tie `best` exactly
            var ties_move: u64 = 0;
            for (0..n) |p| {
                if (s.pos[p] != 0) continue;
                const child = R.pos_from_move(&s.pos, side, p) catch continue;
                if (s.repForbidden(&child, leg)) continue; // repetition rule
                const v = s.v0(&child, -side);
                if (v == UNDEF) continue; // unfilled slot: not a candidate
                const dt = s.dtt0(&child, -side);
                const caps: u16 = opp_before - countColor(&child, opp);
                const mv = Choice{ .cell = p, .value = v, .dtt = dt, .caps = caps };

                const nb = pick(best_move, mv, maxing);
                if (best_move == null or !eqRank(nb.?, best_move.?)) {
                    // strictly better than the incumbent
                    best_move = nb;
                    ties_move = 1;
                } else if (eqRank(mv, best_move.?)) {
                    ties_move += 1;
                    if (rt and rnd.uintLessThan(u64, ties_move) == 0) best_move = mv;
                }

                const nba = pick(best, mv, maxing);
                if (!eqRank(nba.?, best.?)) {
                    best = nba;
                    ties_best = 1;
                } else if (eqRank(mv, best.?)) {
                    ties_best += 1;
                    if (rt and rnd.uintLessThan(u64, ties_best) == 0) best = mv;
                }
            }
            // early game (own < area/4 AND total < area/2): if pass would be
            // chosen, play the best move instead.
            if (best.?.cell == null) {
                const area: usize = w * h;
                var own: usize = 0;
                var tot: usize = 0;
                for (s.pos) |x| {
                    if (x == 0) continue;
                    tot += 1;
                    if ((x > 0) == (side > 0)) own += 1;
                }
                if (own < area / 4 and tot < area / 2) {
                    if (best_move) |bm| return bm;
                }
            }
            return best.?;
        }

        /// Rank-equality for the tie-break ordering (value, caps, dtt).
        fn eqRank(a: Choice, b: Choice) bool {
            return a.value == b.value and a.caps == b.caps and a.dtt == b.dtt;
        }

        /// Uniform over PSK-legal moves, with `pass_permille`/1000 chance of
        /// passing outright. Passes when no legal move exists.
        fn chooseRandom(s: *const Self, side: i8, rnd: std.Random, pass_permille: u32, leg: Legality) Choice {
            if (rnd.uintLessThan(u32, 1000) < pass_permille) {
                return .{ .cell = null, .value = 0, .dtt = 0 };
            }
            var pool: [n]usize = undefined;
            var k: usize = 0;
            for (0..n) |p| {
                if (s.pos[p] != 0) continue;
                const child = R.pos_from_move(&s.pos, side, p) catch continue;
                if (s.repForbidden(&child, leg)) continue;
                pool[k] = p;
                k += 1;
            }
            if (k == 0) return .{ .cell = null, .value = 0, .dtt = 0 };
            return .{ .cell = pool[rnd.uintLessThan(usize, k)], .value = 0, .dtt = 0 };
        }

        fn run(
            d: *const artifact.Decoded,
            policy: Policy,
            games: u64,
            seed: u64,
            ply_cap: u64,
            pass_permille: u32,
            settled_stop: bool,
            trace: usize,
            psk_binding: bool,
            gpa: std.mem.Allocator,
        ) !Stats {
            std.debug.print("\n== policy: {s} ==\n", .{policy.label()});
            var st = Stats{};
            var s = Self{ .d = d };
            var prng = std.Random.DefaultPrng.init(seed);
            const rnd = prng.random();
            // The counterfactual draws from its own stream so that enabling
            // --psk-binding cannot perturb a single played move.
            var prng_cf = std.Random.DefaultPrng.init(seed ^ 0x5c0ffee5c0ffee);
            const rnd_cf = prng_cf.random();

            var lines = std.AutoHashMap(u64, void).init(gpa);
            defer lines.deinit();

            var g: u64 = 0;
            while (g < games) : (g += 1) {
                s.reset();
                // driver assignment
                var drv: [2]Driver = undefined; // [0]=Black, [1]=White
                switch (policy) {
                    .oracle, .oracle_rt => drv = .{ .engine, .engine },
                    .random => drv = .{ .rand, .rand },
                    .mixed => drv = if (g % 2 == 0)
                        .{ .engine, .rand }
                    else
                        .{ .rand, .engine },
                }

                var side: i8 = 1; // Black moves first
                var ply: u64 = 0;
                var undef_hit = false;
                var g_nodes: u64 = 0;
                var g_ko: u64 = 0;
                var g_eng_nodes: u64 = 0;
                var g_eng_ko: u64 = 0;
                var g_bnodes: [NBUCKET]u64 = [_]u64{0} ** NBUCKET;
                var g_bko: [NBUCKET]u64 = [_]u64{0} ** NBUCKET;
                var g_ply1_ko = false;
                var g_bind = false;
                var g_long = false;
                var g_cf = false;
                var last_short_ply: ?u64 = null; // most recent ply with a d <= 6 repeat
                var linehash: u64 = 0xcbf29ce484222325;
                var capped = false;
                var settled_end = false;
                var dpass_end = false;
                const tracing = g < trace;
                if (tracing) std.debug.print("  trace game {d}:", .{g});

                while (true) {
                    if (ply >= ply_cap) {
                        capped = true;
                        break;
                    }
                    // ---- observe the decision node (pos, side to move) ----
                    const stored = s.v0(&s.pos, side);
                    const engine_turn = drv[if (side > 0) 0 else 1] == .engine;
                    if (stored == UNDEF) {
                        undef_hit = true;
                        st.undef_nodes += 1;
                    } else {
                        const ko = s.kosens(&s.pos, side);
                        g_nodes += 1;
                        if (ko) g_ko += 1;
                        if (engine_turn) {
                            g_eng_nodes += 1;
                            if (ko) g_eng_ko += 1;
                        }
                        const b = @min(ply / 4, NBUCKET - 1);
                        g_bnodes[b] += 1;
                        if (ko) g_bko[b] += 1;
                        if (ply == 0 and ko) g_ply1_ko = true;
                    }

                    // ---- PSK-binding scan (all rules-legal candidates) ----
                    var scan = NodeScan{};
                    if (psk_binding) {
                        scan = s.scanNode(side, &st.psk);
                        st.psk.nodes += 1;
                        st.psk.cand += scan.cand;
                        st.psk.cand_bk += scan.cand_bk;
                        st.psk.rep_ko += scan.ko;
                        st.psk.rep_short += scan.short;
                        st.psk.rep_long += scan.long;
                        const near_short = scan.short > 0 or
                            (last_short_ply != null and ply - last_short_ply.? <= 6);
                        if (scan.long > 0 and !near_short) st.psk.rep_long_isolated += scan.long;
                        if (scan.short > 0 or scan.long > 0) {
                            st.psk.nodes_bind += 1;
                            g_bind = true;
                        }
                        if (scan.long > 0) {
                            st.psk.nodes_long += 1;
                            g_long = true;
                        }
                        if (scan.ko > 0 or scan.short > 0) last_short_ply = ply;
                    }

                    // ---- choose ----
                    const ch = if (engine_turn)
                        s.chooseOracle(side, policy == .oracle_rt, rnd, .psk)
                    else
                        s.chooseRandom(side, rnd, pass_permille, .psk);

                    // ---- counterfactual: same policy, basic-ko legality only ----
                    if (psk_binding) {
                        const cf = if (engine_turn)
                            s.chooseOracle(side, policy == .oracle_rt, rnd_cf, .basic_ko)
                        else
                            s.chooseRandom(side, rnd_cf, pass_permille, .basic_ko);
                        st.psk.cf_nodes += 1;
                        if (cf.cell) |c| {
                            st.psk.cf_moves += 1;
                            const d2 = scan.dist[c];
                            if (d2 >= 3) {
                                if (d2 <= 6) st.psk.cf_short += 1 else st.psk.cf_long += 1;
                                g_cf = true;
                            }
                        }
                    }

                    if (tracing) {
                        // "*" = KO_SENSITIVE, "?" = UNDEF slot (belief-free)
                        const ko = stored != UNDEF and s.kosens(&s.pos, side);
                        if (ch.cell) |c| {
                            std.debug.print(" {c}{c}{d}{s}", .{
                                if (side > 0) @as(u8, 'B') else @as(u8, 'W'),
                                COLS[c % w],
                                h - c / w,
                                if (stored == UNDEF) "?" else if (ko) "*" else "",
                            });
                        } else {
                            std.debug.print(" {c}pass{s}", .{
                                if (side > 0) @as(u8, 'B') else @as(u8, 'W'),
                                if (stored == UNDEF) "?" else if (ko) "*" else "",
                            });
                        }
                        if (psk_binding and (scan.ko + scan.short + scan.long) > 0) {
                            std.debug.print("{{", .{});
                            for (0..n) |c| {
                                if (scan.dist[c] == 0) continue;
                                std.debug.print("{c}{d}:d={d} ", .{
                                    COLS[c % w], h - c / w, scan.dist[c],
                                });
                            }
                            std.debug.print("}}", .{});
                        }
                    }

                    // ---- apply ----
                    if (ch.cell) |c| {
                        const child = R.pos_from_move(&s.pos, side, c) catch unreachable;
                        s.pos = child;
                        s.push(&child);
                        s.passes = 0;
                        linehash = (linehash ^ (c + 1)) *% 0x100000001b3;
                    } else {
                        s.passes += 1;
                        linehash = (linehash ^ 0xff) *% 0x100000001b3;
                    }
                    ply += 1;
                    s.ply = ply;
                    s.recordPly();
                    if (s.passes >= 2) {
                        dpass_end = true;
                        break;
                    }
                    if (settled_stop and R.is_settled(&s.pos)) {
                        settled_end = true;
                        break;
                    }
                    side = -side;
                }

                if (tracing) std.debug.print("   [{s}]  (* = KO_SENSITIVE, ? = UNDEF slot)\n", .{
                    if (capped) "PLY CAP" else if (dpass_end) "two passes" else "settled",
                });

                st.games += 1;
                st.plies_all += ply;
                if (ply > st.max_plies) st.max_plies = ply;
                if (capped) st.cap_hits += 1;
                if (dpass_end) st.end_double_pass += 1;
                if (settled_end) st.end_settled += 1;
                if (g_bind) st.psk.games_bind += 1;
                if (g_long) st.psk.games_long += 1;
                if (g_cf) st.psk.cf_games += 1;
                try lines.put(linehash, {});

                if (undef_hit) {
                    st.undef_games += 1;
                } else {
                    st.clean_games += 1;
                    st.nodes += g_nodes;
                    st.ko_nodes += g_ko;
                    st.eng_nodes += g_eng_nodes;
                    st.eng_ko += g_eng_ko;
                    for (0..NBUCKET) |b| {
                        st.bucket_nodes[b] += g_bnodes[b];
                        st.bucket_ko[b] += g_bko[b];
                    }
                    if (g_nodes > 0) {
                        st.pergame_sum += @as(f64, @floatFromInt(g_ko)) / @as(f64, @floatFromInt(g_nodes));
                        st.pergame_n += 1;
                    }
                    if (g_ply1_ko) st.ply1_ko += 1;
                }
            }
            report(policy, &st, lines.count(), ply_cap);
            if (psk_binding) reportPsk(&st);
            return st;
        }

        /// Rate per 1,000 plies. `plies` is over ALL games (legality is
        /// artifact-independent, so no game is excluded here).
        fn per1k(num: u64, plies: u64) f64 {
            if (plies == 0) return 0;
            return 1000.0 * @as(f64, @floatFromInt(num)) / @as(f64, @floatFromInt(plies));
        }

        fn reportPsk(st: *const Stats) void {
            const p = std.debug.print;
            const q = &st.psk;
            const bind = q.rep_short + q.rep_long;
            p("  ---- PSK BINDING BEYOND BASIC KO (all games; legality reads no artifact slot) ----\n", .{});
            p("  plies played (all games): {d}\n", .{st.plies_all});
            p("  decision nodes scanned:   {d}\n", .{q.nodes});
            p("  rules-legal candidates:   {d}   (basic-ko-legal {d})\n", .{ q.cand, q.cand_bk });
            p("  PSK-repeat candidates:    {d}   = d==2 {d} | d 3-6 {d} | d>6 {d}   (max d = {d})\n", .{
                q.rep_ko + bind, q.rep_ko, q.rep_short, q.rep_long, q.max_d,
            });
            p("  (A) ALL CANDIDATES -- moves basic ko ALLOWS and PSK FORBIDS:\n", .{});
            p("      d==2 ko-cycle    : {d:<10} {d:9.4} /1k plies   (NOT binding: basic ko forbids it too)\n", .{
                q.rep_ko, per1k(q.rep_ko, st.plies_all),
            });
            p("      d 3-6 short-cycle: {d:<10} {d:9.4} /1k plies\n", .{
                q.rep_short, per1k(q.rep_short, st.plies_all),
            });
            p("      d>6   SILENT     : {d:<10} {d:9.4} /1k plies   (isolated {d}: no d<=6 repeat within 6 plies)\n", .{
                q.rep_long, per1k(q.rep_long, st.plies_all), q.rep_long_isolated,
            });
            p("      BINDING total    : {d:<10} {d:9.4} /1k plies   {d:9.4} /1k candidates\n", .{
                bind, per1k(bind, st.plies_all), per1k(bind, q.cand),
            });
            p("      nodes offering >=1 binding candidate: {d} ({d:.4}% of nodes)\n", .{
                q.nodes_bind, pct(q.nodes_bind, q.nodes),
            });
            p("      nodes offering >=1 d>6 candidate:     {d} ({d:.4}% of nodes)\n", .{
                q.nodes_long, pct(q.nodes_long, q.nodes),
            });
            p("      games with >=1 binding candidate:     {d}/{d} ({d:.3}%)\n", .{
                q.games_bind, st.games, pct(q.games_bind, st.games),
            });
            p("      games with >=1 SILENT (d>6) repeat:   {d}/{d} ({d:.3}%)\n", .{
                q.games_long, st.games, pct(q.games_long, st.games),
            });
            p("  (B) THE CHOSEN MOVE -- same policy re-run under basic-ko legality, separate RNG:\n", .{});
            p("      counterfactual nodes: {d}   chose a move (not pass): {d}\n", .{ q.cf_nodes, q.cf_moves });
            p("      chosen move PSK-illegal: {d} total = d 3-6 {d} | d>6 {d}   {d:9.4} /1k plies\n", .{
                q.cf_short + q.cf_long, q.cf_short, q.cf_long,
                per1k(q.cf_short + q.cf_long, st.plies_all),
            });
            p("      games where PSK changed >=1 played move: {d}/{d} ({d:.3}%)\n", .{
                q.cf_games, st.games, pct(q.cf_games, st.games),
            });
            p("  repeat-distance histogram (candidate-level):\n", .{});
            var any = false;
            for (0..MAXD) |i| {
                if (q.dist[i] == 0) continue;
                any = true;
                if (i == MAXD - 1) {
                    p("      d>={d:<4} {d}\n", .{ MAXD - 1, q.dist[i] });
                } else {
                    p("      d={d:<6} {d}\n", .{ i, q.dist[i] });
                }
            }
            if (!any) p("      (no whole-board repeat was ever available)\n", .{});
        }

        /// "C3" -> cell index, using the same convention as gtp.cell_from_vertex
        /// (row 1 at the bottom, cell 0 = top-left).
        fn cellFromVertex(tok: []const u8) ?usize {
            if (tok.len < 2) return null;
            const letter = std.ascii.toUpper(tok[0]);
            const col = std.mem.indexOfScalar(u8, COLS, letter) orelse return null;
            const row = std.fmt.parseInt(usize, tok[1..], 10) catch return null;
            if (col >= w or row < 1 or row > h) return null;
            return (h - row) * w + col;
        }

        /// Replay a FIXED line (a GTP transcript; only `play <colour> <vertex>`
        /// lines are read, everything else ignored) and print, ply by ply,
        /// every whole-board repeat that positional superko forbids, with its
        /// distance. No policy, no artifact slot read — pure rules.
        /// Cross-check instrument for ko-sensitive-chainability.md Measurement 2.
        fn replayTranscript(d: *const artifact.Decoded, name: []const u8, text: []const u8) void {
            const p = std.debug.print;
            var s = Self{ .d = d };
            s.reset();
            var ply: u64 = 0;
            var bans_ko: u64 = 0;
            var bans_short: u64 = 0;
            var bans_long: u64 = 0;
            var ban_plies: u64 = 0;
            p("\n== replay: {s} ({d}x{d}) ==\n", .{ name, w, h });
            var it = std.mem.tokenizeAny(u8, text, "\r\n");
            while (it.next()) |line| {
                var t = std.mem.tokenizeAny(u8, line, " \t");
                const cmd = t.next() orelse continue;
                if (!std.ascii.eqlIgnoreCase(cmd, "play")) continue;
                const colour = t.next() orelse continue;
                const vtx = t.next() orelse continue;
                const side: i8 = if (colour[0] == 'b' or colour[0] == 'B') 1 else -1;

                // --- observe the decision node before the move ---
                var dummy = PskStats{};
                const scan = s.scanNode(side, &dummy);
                const nrep = scan.ko + scan.short + scan.long;
                ply += 1; // this move is ply `ply` (1-based, matching Measurement 2)
                if (nrep > 0) {
                    ban_plies += 1;
                    bans_ko += scan.ko;
                    bans_short += scan.short;
                    bans_long += scan.long;
                    p("  ply {d:>2} ({c} to move): {d} PSK ban(s):", .{
                        ply, if (side > 0) @as(u8, 'B') else @as(u8, 'W'), nrep,
                    });
                    for (0..n) |c| {
                        if (scan.dist[c] == 0) continue;
                        const cat = if (scan.dist[c] <= 2)
                            "ko-cycle, basic ko forbids it too"
                        else if (scan.dist[c] <= 6) "short-cycle, BINDING" else "SILENT long-range, BINDING";
                        p(" {c}{d} d={d} [{s}]", .{ COLS[c % w], h - c / w, scan.dist[c], cat });
                    }
                    p("\n", .{});
                }

                // --- apply ---
                if (std.ascii.eqlIgnoreCase(vtx, "pass")) {
                    s.passes += 1;
                } else {
                    const cell = cellFromVertex(vtx) orelse {
                        p("  !! ply {d}: unparsable vertex '{s}'\n", .{ ply, vtx });
                        return;
                    };
                    const child = R.pos_from_move(&s.pos, side, cell) catch {
                        p("  !! ply {d}: transcript move {s} is rules-illegal\n", .{ ply, vtx });
                        return;
                    };
                    if (s.seen(&child)) p("  !! ply {d}: transcript move {s} is PSK-ILLEGAL\n", .{ ply, vtx });
                    s.pos = child;
                    s.push(&child);
                    s.passes = 0;
                }
                s.ply = ply;
                s.recordPly();
            }
            p("  TOTAL over {d} plies: {d} PSK ban(s) at {d} ply/plies -- d==2 {d} | d 3-6 {d} | d>6 {d}\n", .{
                ply, bans_ko + bans_short + bans_long, ban_plies, bans_ko, bans_short, bans_long,
            });
            p("  PSK-BINDING (basic-ko-legal but PSK-illegal): {d}\n", .{bans_short + bans_long});
        }

        fn report(policy: Policy, st: *const Stats, distinct: u32, ply_cap: u64) void {
            const p = std.debug.print;
            p("  games played:           {d}\n", .{st.games});
            p("  distinct game lines:    {d}\n", .{distinct});
            p("  mean plies/game:        {d:.2}  (max {d})\n", .{
                if (st.games == 0) 0.0 else @as(f64, @floatFromInt(st.plies_all)) / @as(f64, @floatFromInt(st.games)),
                st.max_plies,
            });
            p("  terminations:           two-pass {d} | settled {d} | PLY CAP {d} ({d:.2}%, cap={d})\n", .{
                st.end_double_pass, st.end_settled, st.cap_hits, pct(st.cap_hits, st.games), ply_cap,
            });
            p("  games touching UNDEF:   {d} ({d:.2}%) -- EXCLUDED from belief stats; {d} UNDEF nodes seen\n", .{
                st.undef_games, pct(st.undef_games, st.games), st.undef_nodes,
            });
            p("  clean games counted:    {d}\n", .{st.clean_games});
            p("  visited decision nodes: {d}\n", .{st.nodes});
            p("  KO_SENSITIVE nodes:     {d}\n", .{st.ko_nodes});
            p("  ---- KO-SENSITIVE FRACTION OVER REACHED PLAY ----\n", .{});
            p("  node-weighted:          {d:.2}%\n", .{pct(st.ko_nodes, st.nodes)});
            p("  game-weighted (mean of per-game fractions): {d:.2}%\n", .{
                if (st.pergame_n == 0) 0.0 else 100.0 * st.pergame_sum / @as(f64, @floatFromInt(st.pergame_n)),
            });
            if (policy == .mixed or policy == .oracle_rt or policy == .oracle) {
                p("  engine-to-move nodes:   {d}  ko={d}  ->  {d:.2}% KO_SENSITIVE\n", .{
                    st.eng_nodes, st.eng_ko, pct(st.eng_ko, st.eng_nodes),
                });
                // The complement: nodes the OPPONENT faces, i.e. the positions
                // the engine's own moves CREATE. A large gap between the two is
                // the greedy-optimism signature (M3, ko-sensitive-chainability).
                p("  opponent-to-move nodes: {d}  ko={d}  ->  {d:.2}% KO_SENSITIVE\n", .{
                    st.nodes - st.eng_nodes, st.ko_nodes - st.eng_ko,
                    pct(st.ko_nodes - st.eng_ko, st.nodes - st.eng_nodes),
                });
            }
            p("  clean games whose ply 1 (empty board) is KO_SENSITIVE: {d}/{d}\n", .{ st.ply1_ko, st.clean_games });
            p("  by ply index:\n", .{});
            for (0..NBUCKET) |b| {
                if (st.bucket_nodes[b] == 0) continue;
                var lbl: [16]u8 = undefined;
                const s2 = if (b == NBUCKET - 1)
                    std.fmt.bufPrint(&lbl, "{d}+", .{b * 4}) catch unreachable
                else
                    std.fmt.bufPrint(&lbl, "{d}-{d}", .{ b * 4, b * 4 + 3 }) catch unreachable;
                p("    ply {s:<7} n={d:<9} ko={d:<9} {d:6.2}%\n", .{
                    s2, st.bucket_nodes[b], st.bucket_ko[b], pct(st.bucket_ko[b], st.bucket_nodes[b]),
                });
            }
        }
    };
}

fn dispatch(
    dec: *const artifact.Decoded,
    policy: Policy,
    games: u64,
    seed: u64,
    ply_cap: u64,
    pass_permille: u32,
    settled_stop: bool,
    trace: usize,
    psk_binding: bool,
    gpa: std.mem.Allocator,
) !void {
    const key = @as(usize, dec.header.board_w) * 100 + dec.header.board_h;
    _ = switch (key) {
        202 => try Census(2, 2).run(dec, policy, games, seed, ply_cap, pass_permille, settled_stop, trace, psk_binding, gpa),
        302 => try Census(3, 2).run(dec, policy, games, seed, ply_cap, pass_permille, settled_stop, trace, psk_binding, gpa),
        303 => try Census(3, 3).run(dec, policy, games, seed, ply_cap, pass_permille, settled_stop, trace, psk_binding, gpa),
        403 => try Census(4, 3).run(dec, policy, games, seed, ply_cap, pass_permille, settled_stop, trace, psk_binding, gpa),
        404 => try Census(4, 4).run(dec, policy, games, seed, ply_cap, pass_permille, settled_stop, trace, psk_binding, gpa),
        else => return error.Unsupported,
    };
}

fn dispatchReplay(dec: *const artifact.Decoded, name: []const u8, text: []const u8) !void {
    const key = @as(usize, dec.header.board_w) * 100 + dec.header.board_h;
    switch (key) {
        202 => Census(2, 2).replayTranscript(dec, name, text),
        302 => Census(3, 2).replayTranscript(dec, name, text),
        303 => Census(3, 3).replayTranscript(dec, name, text),
        403 => Census(4, 3).replayTranscript(dec, name, text),
        404 => Census(4, 4).replayTranscript(dec, name, text),
        else => return error.Unsupported,
    }
}

pub fn main(init: std.process.Init) !void {
    const gpa = std.heap.page_allocator;
    const io = init.io;
    var args = std.process.Args.Iterator.init(init.minimal.args);
    _ = args.next();
    const path = args.next() orelse return error.NoArtifact;

    var games: u64 = 2000;
    var seed: u64 = 20260728;
    var ply_cap: u64 = 256;
    var pass_permille: u32 = 50; // 5% pass for the random policy
    var trace: usize = 0;
    var settled_stop: bool = true;
    var which: ?Policy = null; // null == all
    var psk_binding: bool = false;
    var replay_paths: [8][]const u8 = undefined;
    var replay_n: usize = 0;

    while (args.next()) |a| {
        if (std.mem.eql(u8, a, "--games")) {
            games = std.fmt.parseInt(u64, args.next() orelse "2000", 10) catch 2000;
        } else if (std.mem.eql(u8, a, "--seed")) {
            seed = std.fmt.parseInt(u64, args.next() orelse "20260728", 10) catch 20260728;
        } else if (std.mem.eql(u8, a, "--ply-cap")) {
            ply_cap = std.fmt.parseInt(u64, args.next() orelse "256", 10) catch 256;
        } else if (std.mem.eql(u8, a, "--pass-prob")) {
            pass_permille = std.fmt.parseInt(u32, args.next() orelse "50", 10) catch 50;
        } else if (std.mem.eql(u8, a, "--no-settled-stop")) {
            settled_stop = false;
        } else if (std.mem.eql(u8, a, "--psk-binding")) {
            psk_binding = true;
        } else if (std.mem.eql(u8, a, "--replay")) {
            const v = args.next() orelse continue;
            if (replay_n < replay_paths.len) {
                replay_paths[replay_n] = v;
                replay_n += 1;
            }
        } else if (std.mem.eql(u8, a, "--trace")) {
            trace = std.fmt.parseInt(usize, args.next() orelse "1", 10) catch 1;
        } else if (std.mem.eql(u8, a, "--policy")) {
            const v = args.next() orelse "all";
            if (std.mem.eql(u8, v, "oracle")) {
                which = .oracle;
            } else if (std.mem.eql(u8, v, "random")) {
                which = .random;
            } else if (std.mem.eql(u8, v, "mixed")) {
                which = .mixed;
            } else if (std.mem.eql(u8, v, "oracle-rt")) {
                which = .oracle_rt;
            } else which = null;
        }
    }
    if (ply_cap > 1024) ply_cap = 1024;

    var dec = try artifact.load(io, std.Io.Dir.cwd(), path, gpa);
    defer dec.deinit();

    std.debug.print(
        \\reachable ko-sensitivity census
        \\  artifact: {s} ({d}x{d}, {d} legal/side)
        \\  games/policy: {d}   seed: {d}   ply cap: {d}   random pass prob: {d}/1000
        \\  settled-stop: {s}
        \\  denominator: visited (position, side-to-move) decision nodes from the
        \\  empty board under real positional superko; NOT slot-uniform.
        \\
    , .{
        path,        dec.header.board_w, dec.header.board_h,
        dec.header.legal_count, games,  seed,
        ply_cap,     pass_permille,
        if (settled_stop) "on" else "OFF (play on until two passes)",
    });

    if (replay_n > 0) {
        // Fixed-line cross-check mode: no policies, no randomness.
        for (replay_paths[0..replay_n]) |rp| {
            const text = try std.Io.Dir.cwd().readFileAlloc(io, rp, gpa, .unlimited);
            defer gpa.free(text);
            try dispatchReplay(&dec, rp, text);
        }
        return;
    }

    if (which) |pol| {
        try dispatch(&dec, pol, games, seed, ply_cap, pass_permille, settled_stop, trace, psk_binding, gpa);
    } else {
        // Each policy gets its own seed stream derived from the master seed, so
        // adding/removing a policy cannot perturb another's numbers.
        try dispatch(&dec, .oracle, games, seed +% 0x1001, ply_cap, pass_permille, settled_stop, trace, psk_binding, gpa);
        try dispatch(&dec, .oracle_rt, games, seed +% 0x2002, ply_cap, pass_permille, settled_stop, trace, psk_binding, gpa);
        try dispatch(&dec, .random, games, seed +% 0x3003, ply_cap, pass_permille, settled_stop, trace, psk_binding, gpa);
        try dispatch(&dec, .mixed, games, seed +% 0x4004, ply_cap, pass_permille, settled_stop, trace, psk_binding, gpa);
    }
}
