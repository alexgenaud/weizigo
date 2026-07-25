# TODO

Status legend: [ ] todo · [~] in progress · [x] done · [-] dropped

## Improvement review (2026-07-16) — cleanup / simplification / optimization

Prioritized recommendations from a full read of the engine core. #1 is DONE
(this session); #2–#5 are queued in the recommended order.

- [x] **#1 — Safety hardening + depth instrumentation (DONE 2026-07-16).**
      Policy decided: run the one-time perfect computation in **ReleaseSafe**
      (correctness beats speed). Landed:
      - The two silent-corruption `assert`s are now **always-live `@panic`s**
        (no-op in ReleaseFast): `superko.push` MAX_LINE overflow, and
        `solve.Table.set` seq-table-full + value-inconsistency + block-overrun.
      - `superko.History.max_len` tracks the deepest game line per run.
      - `main.zig` is now a real solve driver: runs `solve_root` on a spawned
        thread with a 256 MB stack (recursion depth == ply count, not stone
        count) and reports value + measured max ply. Default = fast dead-stone
        demo (Black+25, max ply 2); flip `FULL` to attempt the empty board.
      - NOTE on the 4096 question: recursion depth == **game-line length in
        plies**, which is decoupled from the ~20-stone board ceiling because
        captures let a line keep changing without net stone growth. `MAX_LINE`
        is headroom, not a proof; the theoretical ceiling is the count of legal
        5x5 positions (~4.1e11). Realistic lines are almost certainly short
        (tens). The driver now MEASURES it — a real `FULL` run will report the
        true max (needs the TT wired+sized first; see #1-followup).
      - [x] #1-followup DONE 2026-07-16: wired + sized a TT into the `FULL` path
            (256 MB blind arrays + 2 GB seq) and measured. RESULT: the forward
            solve does NOT converge on the empty board — DFS descends 200+ plies
            while the TT caches nothing (GHI-tainted opening). Not a route to the
            oracle by itself; strong support for the retrograde/enumeration
            engine. Write-up: `docs/research/forward-solve-scaling.md`. `FULL`
            default reverted to `false` (quick demo).

- [x] **#2 — Retire the old path. DONE 2026-07-16.** Deleted `minimax.zig` +
      `measure.zig`; **ported `persist.zig`** off minimax onto `solve` (`seq_score`
      → `SeqScore`, `collision_size(n,depth)` → `block_size(n)`, dropped the
      vestigial `max_depth` from sizing — kept in `Header` for provenance);
      removed the now-dead `util.min2/max2/min3/min4` + `LOSS_FOR_*`; updated
      `main.zig`'s test aggregator. The "index-0 sentinel bug" is now moot (it
      lived in `minimax`; `solve.Table` reserves slot 0). Verified: baseline
      unchanged (solve 54 / superko 35 / terminal 9 / state 27), persist 58,
      driver = Black+25, and `zig build test` ran clean (no dyld abort this run).
      NOTE: `zobrist.zig` kept (standalone; future hashing / data-model use).
      FOLLOW-UP: a `persist` round-trip test that goes through a real
      `solve.Table` end-to-end (current tests use raw slices, which is
      equivalent but less explicit); and a Table-based save/load convenience
      wrapper.

- [ ] **#3 — Per-node redundant recompute (constant-factor win, ~1.3–1.8x,
      NOT 3x — profile first).** In the hot `solve` loop: `pass_alive` is
      computed up to 3x/node (`is_settled` does black+white, then `solve` does
      `to_move` again — `solve.zig:222`); `lowest_blind_from_pos` (16 dihedral
      x colour transforms) up to 3x/node (hashable check + `get` + `set`).
      Compute each once at node entry and thread it through. The real
      multiplicative win is algorithmic (see #6), not this.

- [ ] **#4 — Consolidate reusable geometry / flood; document state.zig.**
      New `board.zig`: `neighbors`, `same_position`, `stone_count`, and a
      `floodEmptyRegion` -> {size, touches_black, touches_white,
      all_bordered_by_stone}. Removes 3 neighbor reimplementations
      (`terminal.neighbors`, `solve.is_own_eye`, inline in `state.zig`) and 2
      flood copies (`area_score` vs `is_settled`). Add a header glossary to
      `state.zig`: blind = 25-bit occupancy; seq = colour bits of occupied cells
      (<=16); view = 40-bit packed; lowest = canonical rep over 8 dihedral x
      colour inversion.

- [ ] **#5 — Build structure (Zig 0.16 best practice).** Per-module `addTest`
      steps aggregated under `zig build test` (kills the dyld mega-binary
      abort); named steps for the tools (`zig build census|ko-probe|measure`);
      a first-class `-Dfull=true` build option to replace `main.FULL`; a shared
      module graph via `b.addModule` instead of ad-hoc `@import`.

- [-] **#6 — Alpha-beta + move ordering. SCRAPPED (ADR-0007, goal is (b)).**
      Alpha-beta returns bounds + prunes subtrees unvisited, so it proves the
      VALUE (goal a) but cannot populate an oracle (goal b). Kept only as a note:
      if the goal ever reverts to (a), this is the path.

- [~] **Position enumerator (oracle foundation) — STARTED 2026-07-16.**
      `src/enumerate.zig`: board-size-agnostic legal-position enumerator
      (structure only; standalone, no state/zobrist imports). VALIDATED against
      Tromp/OEIS A094777: 1x1=1, 2x2=57, 3x3=12,675, 4x4=24,318,165 all PASS
      (~6 s ReleaseFast). NEW data: canonical class counts (4x4: 1,524,805;
      ratio -> ~16) + per-stone-layer censuses => 5x5 oracle ~ 25.9e9 classes
      ~ 52 GB at 1 B/(class,side). See `research/enumeration-census.md`.
  - [x] Colex index DONE 2026-07-17: `src/colex.zig` — `colex_from_pos` /
        `pos_from_colex`, raw layered (offset + subset_idx*2^k + colour bits).
        Bijection exhaustively VERIFIED over all boards of 2x2/3x2/3x3/4x4
        (43M, zero collisions, ~5 s ReleaseFast); 5x5 addressing works
        arithmetically (3^25 total; tengen = idx 26). RENAMED from "rank"
        (user decision: in Go, rank = kyu/dan; avoid the term). See
        `research/enumeration-census.md`.
  - [x] Forward fresh-start filling MEASURED INTRACTABLE even at 3x3
        (2026-07-17): single 8-stone roots exceed 10M nodes with 2,100+-ply
        lines; warm bottom-up sweep stuck in layer 8 after 13 min. See
        `research/oracle-3x3.md` + ADR-0008. `rules.zig` (generic rules,
        cross-validated vs 5x5 stack) and `oracle.zig` (solver + full
        validation battery: anchors, exhaustive inversion/dihedral,
        order-independence, spot checks) are DONE and wait for a tractable
        engine.
  - [ ] ORACLE SCHEMA (decide in the #6' ADR, BEFORE format freeze): per
        (position, side) store value:i8 + DTT:u8 (depth-to-terminal — the
        retrograde engine computes it for free; unrecoverable later) + flags.
        Teaching metrics derive from these: see
        `research/teaching-oracle-metrics.md`.
  - [ ] QUERY ENGINE (design recorded, build after retrograde): goal-bounded
        forward solver (objective = capture(S)/save(S)/pass_alive(S), terminal
        = objective decided -- tsumego-style, tractable where full solves are
        not) + fact-diff WHY explanations + principle mining + GTP server.
        Store-vs-compute doctrine + query taxonomy:
        `research/query-engine-and-explanations.md`. Forward engine = live
        local queries; retrograde = global table; complementary as decided.
  - [x] CRITICAL PATH DONE 2026-07-19/20: the #6' retrograde design ADR
        (**ADR-0009**) + the 3x3 retrograde engine (`src/retro.zig`).
        Successor-sweep value iteration (NO un-capture code — forward move
        generator only), ko handled STRUCTURALLY by TWO-SIDED fixpoint
        certification (L seeded -n / H seeded +n; where L==H the value is
        history-free = the ADR-0008 fresh-start value; where L<H the node is
        KO_SENSITIVE and resolved by the certified-seeded forward FINISHER).
        NO eye-prune in the retrograde graph (resolves the ADR-0007
        coverage tension: coverage is TOTAL). DTT column computed. Full
        battery: exhaustive history-exact ground truth (`retro.Exact`,
        ban-set-keyed), L/H brackets, exhaustive symmetry (inversion +
        dihedral + L/H-swap + flags), 3x3 anchors, spot checks. Measured
        results: `research/retrograde-3x3.md`. Wired into `zig build test`
        (86 tests green). NEXT: see the retrograde follow-ups below.
  - [ ] Retrograde follow-ups (post-ADR-0009):
        - [x] full 3x3 finisher run to completion — DONE 2026-07-21 via
          ADR-0010 bracket-guided alpha-beta finishing: all 622 orbit reps in
          156,178 nodes (~20 ms); 3x3 oracle COMPLETE, anchors PIN
          (Findings 8–10 in `research/retrograde-3x3.md`).
        - [x] DTT-through-finisher — resolved as a side effect: with residue
          values filled, `dttPass` propagates through them (empty 3x3 = 3
          plies, max finite 16).
        - [x] persist the first real oracle artifact — DONE 2026-07-21
          (ADR-0011): `src/artifact.zig` (WZO1; header versions format +
          `colex.layout_version`; six schema columns; CRC; reader refuses any
          mismatch). `artifacts/oracle-{2x2,3x2,3x3}.wzo` written, reloaded,
          verified byte-identical (`RETRO_SAVE=1 zig run -O ReleaseFast
          src/retro.zig`). New data: empty(B) fresh-start = +1 at 2x2 AND 3x2.
        - [x] 4x4 scale run — DONE 2026-07-21, and it COMPLETED the oracle:
          all 649,517 residue orbit reps solved (0 skips), empty(B) = +2
          (published anchor MATCH), artifact persisted (data/, 258 MB).
          Sweeps 19, residue 21.3% — both trends favourable for 5x5. Took
          two finisher rebuilds: deepest-first + checkpoints/resume +
          heartbeat, then MTD null-window + per-root BOUNDS memo (bare MTD
          is WORSE than aspiration — measured). `research/retrograde-4x4.md`.
        - [ ] 5x5: density folds (legal ~2x, canonical ~8x -> bump
          colex.layout_version) + disk-streamed layer sweeps. Optional 4x5
          shakedown first (published anchor +20). Journal encoding needs
          idx < 2^30 — revisit with the folds.
  - [ ] Later: density folds behind the same interface — legal-only (~2x,
        counting rank) and canonical-only (~16x, fundamental domain / orbit
        rank) — required only for 5x5 (raw = 847 GB at 1 B/slot).

- [x] **#6' — Oracle engine (goal b, ADR-0007). DONE 2026-07-19/20 — ADR-0009
      + `src/retro.zig`.** Retrograde / layered fixpoint, exactly as scoped:
      captures = back-edges so it is a FIXPOINT (converges in 2/6/12 sweeps at
      2x2/3x2/3x3); superko/GHI handled structurally by two-sided (L/H)
      certification instead of history buckets; colex address space is the
      data model. The eye-prune-vs-coverage tension is RESOLVED — retrograde
      uses the full move set, coverage is total (ADR-0009 decision 3). The
      SIGN/INVERSION section is in ADR-0009 and the colour-symmetry checks are
      ported as EXHAUSTIVE whole-table checks (not hand-picked). `solve.zig`
      remains the slow forward reference (finisher + ground truth use it).

## Now — CORRECTNESS BUG found 2026-07-15 (fix before persisting any values)

- [x] **`is_settled` terminal-territory bug** — FIXED (commit b18e49d):
      `is_settled` now requires every empty point to have a stone neighbour
      (eye-space), so it certifies *decided* positions, not merely
      scoring-settled ones. Corrected census: minimal decided terminal = 10
      stones. See `research/terminal-territory-bug.md`.
- [x] **Strategy fork — DECIDED 2026-07-16: goal (b) compressed perfect oracle.**
      See ADR-0007. Engine = retrograde/layered fixpoint (alpha-beta scrapped);
      `persist` to be ported; eye-prune-vs-coverage tension open.

## Also — earlier correctness track

- [x] **Positional superko (PSK)** — `src/superko.zig` `History` (push/pop/
      repeats), colour-based position comparison, capture-armed fast path.
      8 tests incl. a real ko via `armies_from_move`. (Zobrist filter and
      irreversible-move pruning are deferred optimizations.)
- [x] **Benson unconditional-life terminal test** — `src/terminal.zig`
      `pass_alive` + `is_settled` (pure, 8 unit tests). Recognizes settled
      positions (all groups pass-alive, every empty region owned).
- [x] **Area / Chinese scoring** — `src/terminal.zig` `area_score`
      (Tromp-Taylor style, snapshot-computable, tested).
- [~] **Integrate into the search** — design in `decisions/0005` (proposed).
      New `src/solve.zig`, search-to-terminal + superko + Benson/double-pass +
      area scoring. Phased:
  - [x] Phase 1: `src/solve.zig` search-to-terminal + superko + pass +
        Benson/double-pass + area scoring (4 tests). FINDING: without a TT,
        any non-settled position can reopen the board via a capture and
        explode, so Phase 1 only validates the terminal / scoring / pass
        paths. Deep capture & superko *search* validation needs Phase 2.
  - [x] Phase 2: `(blind,seq)` TT with num_stones<=16 cutoff, passes==0-only
        caching, and the ko_ref GHI cacheability test. `src/solve.zig`
        `Table` + `solve` returning `{value, ko_ref}`; `superko.repeatsIndex`
        returns the matched ply. Validated: TT get/set round-trip + inverse +
        side (unit); integrated search on `dead_white` -> Black+25 both sides,
        colour symmetry, TT == no-TT.
  - [x] **Eye-fill pruning** (`solve.is_own_eye`, ADR-0006) — REQUIRED for
        tractability: the DFS was filling a live group's own eyes, letting the
        opponent capture it and reopen the board (stack overflow even on a
        3-empty endgame). Skipping self-eye-fills is sound under area scoring.
- [x] **Clean/tainted (GHI)** — done as the `ko_ref` dependency-ply in `solve`
      (a node caches iff every superko ban in its subtree referenced a ply
      within the subtree, i.e. `ko_ref >= d`). See `decisions/0005`,
      `research/ghi-and-superko.md`.

## Now — reach the full-board oracle (the remaining frontier)

The empty-board full solve (5x5 = Black+25) is NOT yet reached. Correctness is
in place; scale is the wall (see ADR-0006 "What this does NOT solve"):

- [ ] **Line length / recursion depth.** Positional-superko lines can be long;
      recursion depth == line length. `MAX_LINE` raised 2048->4096 as headroom,
      but confirm a real bound for 5x5 and make the depth stack-safe (larger
      stack, or restructure). A first empty-board run was launched and did not
      complete quickly (~min, ~320 MB RSS, growing) — instrument and bound it.
- [ ] Measured `collision_size` for 9–16 stones + matching `seq_table_size` for
      a full run (still the ADR-0005 open sizing question).
- [ ] Re-run `measure.zig` past depth 6 and confirm zero collisions (old path).

## Next

- [ ] **Captured-stone tracking** (side channel, not in the TT key) so real
      games with history can also be scored Japanese/territory.
- [ ] Measured `collision_size` for 9–16 stones (currently 2^(n-1) worst-case
      placeholders) and matching `seq_table_size` — needed before deep runs.
- [ ] Extend plan-A measurements to depth 8+ on the 48 GB machine; record
      time / nodes / redundancy per depth.

## Provable move-prunes (shrink the space; MUST be value-preserving)

- [ ] **Super-Benson & other PROVABLE dominance prunes.** Extend the eye-prune
      (ADR-0006) with more cheap, local, provably-sound certificates: super-Benson
      (provably-owned regions / borders with one gap) so neither side need play
      in settled territory. CAVEAT: only prune **provably (weakly) dominated**
      moves (like eye-fill, which passing always ties-or-beats). Do NOT add a
      heuristic "don't harm yourself" filter -- sacrifices/throw-ins are
      self-harming-looking but sometimes optimal; a heuristic prune would
      silently corrupt the oracle. Each prune also interacts with the
      complete-vs-scoped-oracle choice (ADR-0007): it shrinks the forward search
      always, but only a *scoped* oracle may drop the pruned positions entirely.

## Later — tighter data model (plan B / C)

- [ ] Evaluate combinatorial ranking / minimal perfect hash to replace the
      dense 2^25 blind array (see `research/data-model-and-measurements.md`).
- [ ] Endgame database of settled terminals (doubles as the ranked DB).
- [ ] Kishimoto–Müller dependency-set caching for ko-tainted nodes (only if
      the simple "don't cache tainted" version proves too slow).

## Housekeeping

- [ ] Fix the index-0 sentinel: `seq_next_empty_index` starts at 0, so the
      first-stored block lands at index 0 which also means "unset" → that
      block is orphaned/recomputed. Reserve index 0 (start at 1).
- [ ] Optional: gzip layer (std.compress.flate) over the disk codec; and/or
      score-frequency entropy coding of the value column.
- [ ] Push commits to origin when ready (nothing pushed since the port began).
