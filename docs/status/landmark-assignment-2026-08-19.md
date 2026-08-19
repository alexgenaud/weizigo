# T468 (why are we doing each of these tasks?) — landmark assignment for the kanban

**Author:** minimax-m3/T468 · **Date:** 2026-08-19
**Read first:** `docs/audits/2026-08-05-handover/LANDMARKS.md` · the task's own brief
(`untracked/T468-landmark-assignment.md`) · then this file.

The brief asks for one line per task — landmark, with the chain stated — and four honest outcomes
including `NO LANDMARK — question the task`. Landmarks are abbreviated below; expand them as
`L0 (the table and the instruments exist)`, never bare.

## How to read this table

Format: `T<nnn> · status · set · verdict · LANDMARK · chain`. `L<n>?` is a plausible chain that
needed a stretch and is named with the stretch. `NO LANDMARK — propose` and `NO LANDMARK —
question` are the two honest non-`L<n>` outcomes. The standing tasks (`STANDING-*`) appear at the
end of the live set. `set` is the dispatch bucket (`A`–`S` plus standing `H`).

---

## Live (dispatchable and in-progress)

| task | landmark | chain |
|---|---|---|
| **T351** · dispatchable · C | **L1** | "failed command:" noise in `zig build test` output makes the suite read red on a glance; cleaning it up so a green suite reads green is a `L1 (the dashboard tells the truth)` outcome. |
| **T352** · dispatchable · C | **L1** | `tools/regression-T227.sh` times out, so the suite's "pass" status doesn't mean what it says; fixing the timeout is dashboard truth. |
| **T353** · dispatchable · C · holds `src/managent/main.zig` | **L1** | `managent orient` replaces the 1524-line preamble workers currently must read; a generated, ≤150-line surface is the dashboard telling the truth at worker-boot time. |
| **T357** · dispatchable · G | **L1** | Measuring the Ollama concurrency cap removes a guess from fleet scheduling; a measured cap is a truer dashboard reading than an inferred one. |
| **T358** · dispatchable · E | **L7** | The scaling census measures what each goban size actually costs; it is the prerequisite measurement for the L7 costed go/no-go on 5×4 and 5×5. (Stretch: T358 only *measures*; the decision document belongs to L7. Without the measurement, L7 cannot be written; with it, L7 becomes writable.) |
| **T362** · dispatchable · G · holds `tools/runner` | **L1** | The memory guard must guard the host, not one process — a fleet-level safety instrument that says what it's doing is a dashboard-truth outcome. |
| **T364** · dispatchable · G · holds `tools/runner` | **L1** | A killed worker leaves no record and a dead row stays `in_progress` — that is dashboard lying. Reconciling the kanban against the process table is dashboard truth. |
| **T430** · dispatchable · C | **L4** | `argus --mode doctor` says "clean" no matter what it found; making the console verdict match the report is ledger cleanliness — the watchdog must say what it knows. |
| **T432** · dispatchable · C | **L1** | Console status must be an assertion carrying author and timestamp, not an inferred absence from silence; that is the dashboard telling the truth about liveness. |
| **T433** · dispatchable · S | **L1** | Audits T428 Phase 2 (scope); T428's tool consolidation reduces the project's measurement surface — the instrument the project reasons about itself with. (Stretch: T428 is process safety that *indirectly* affects dashboard truth; without consolidation, the dashboard's tools disagree more.) |
| **T434** · dispatchable · S | **L1** | Audits T428 Phase 3 (acceptance); same chain as T433 — tool consolidation is instrument honesty. |
| **T435** · dispatchable · S | **L1** | Audits T428 Phase 4 (design); same chain as T433 — tool consolidation is instrument honesty. |
| **T436** · dispatchable · S | **L1** | Re-audits T428 Phase 4; same chain as T433 — tool consolidation is instrument honesty. |
| **T439** · dispatchable · C | **L1** | `inbox --ack` with no target consumes every row's directives; the channel that replaced hand-relay must read correctly for the dashboard to be trustworthy. |
| **T440** · in-progress · C | **L1** | Three regressions are red because T437 changed the CLI and did not migrate the tests; making the suite pass when its gates actually pass is dashboard truth. |
| **T448** · in-progress · A | **L1** | Killed regression runs leave fixtures in the live tree, so the suite perturbs its own instrument; making the tree trustworthy across SIGKILL is dashboard truth. |
| **T449** · dispatchable · G | **L1** | `tools/runner` is blind inside a git worktree, so liveness cannot see runs at all; making the runner work the same everywhere is dashboard truth. |
| **T450** · in-progress · E | **L0** | `tools/pilot_gate.sh` destroys live artifacts before the gate that would catch it; making the gate leave nothing behind on failure is an instrument-trustworthiness outcome — the gate is part of L0's "you can rebuild the artifact." (Stretch: L0 says "table and instruments exist"; T450 is about the *pilot* gate that proves they can be rebuilt. Pilot gate integrity is L0 hygiene.) |
| **T452** · dispatchable · J | **L0** | Fix the qa023_brute_2x2 node-budget alarm; L0's self-test (`zig build test` runs the battery green) cannot be observable while this is crashing. |
| **T454** · dispatchable · J | **L1** | The suite's failing set depends on who runs it; a gate that answers differently for two honest callers is dashboard lying. |
| **T458** · dispatchable · H | **NO LANDMARK — propose: `L8 (the language the project speaks is unambiguous)`** | Disambiguating "row" (task vs claim) on the surface every agent reads on startup is a *language-hygiene* outcome. The map has no landmark for this; the work is real, and the proposal is named in the project's voice: a human can see at a glance whether "row" means a kanban task or a register claim, because every agent reads the disambiguated file first. |
| **T465** · in-progress · A | **L4** | Write the missing findings file for T440 from commit evidence; closing the gap that lets a task show as a live claim to a console that no longer exists is ledger cleanliness. |
| **T466** · in-progress · C | **L1** | The fleet surface must show one row per task, with its landmark, elapsed, CPU, pid and model — making the dashboard say what the fleet actually looks like is L1 directly. |
| **T467** · in-progress · A | **L2** | Bounded holistic audit of L2 discharge itself; the question "has L2 been discharged?" is asked by the landmark, and the answer rules on it. (Stretch: T467 is *auditing* L2, not producing its evidence. The audit's verdict rules on L2 — that's the chain.) |
| **T468** · in-progress · H | **L1** | A queue whose tasks cannot be traced to a goal is a queue nobody can steer by — landmark assignment makes the dashboard honest about what the project is doing. |
| **STANDING-ABSORB** · dispatchable · H | **L4** | Auto-triggered absorption pass; without it, unabsorbed findings silently accumulate, and the C7 gauge reads one number while the register reads another. |
| **STANDING-CLEANUP** · dispatchable · H | **L4** | Standing cleanup keeps the working tree clean and the resume surface honest; the floor must match what claimlint actually sees. |
| **--bundle** · dispatchable · S | **NO LANDMARK — question the task** | The bundle path `untracked/T430-phase2-audit.md` is absent on disk (verified 2026-08-19); only `T433-phase2-audit.md` exists. The phase-2 content has been delivered under T433; `claim_count=0`. The brief cannot be followed because the bundle does not exist. The task is a phantom of the bundle-renaming episode and T444/T446 already recommended close-with-evidence — there is nothing it would do that the ledger does not already reflect. |

---

## Done (chronological by task id)

| task | landmark | chain |
|---|---|---|
| **T317** · done · C | **L1** | Closes the attribution gap in `managent`; without it, every `managent done` is unsigned — the dashboard's authorship column cannot exist. |
| **T319** · done · C | **L1** | Archive closed kanban rows without losing provenance; without it, the live queue cannot be steered because old rows dominate the surface. |
| **T322** · done · C | **L1** | Wires seven orphaned regression scripts into `build.zig`; a control that runs only when a human types it is not a control, and the suite's gate is meaningless. |
| **T325** · done · B | **L1** | Diagnoses the non-deterministic test suite; under "never trust a green test," flakiness is an instrument fault, and T325 made it observable. |
| **T326** · done · C | **L0** | GTP handicap support so Sabaki can set up handicap games; L0's "play the engine over GTP in Sabaki" is observably incomplete without it. |
| **T327** · done · C | **L0** | Score-annotated ASCII board beside the stones board; L0's "see the oracle" path needs this. |
| **T328** · done · A | **NO LANDMARK — propose: `L9 (the fleet can race its own workers on demand)`** | Head-to-head model bake-off harness. The map has no landmark for "we can race models." L1 covers dashboard truth; this is a different capability — the ability to grade model quality blind — and it is foundational for races 1–5, but races themselves are evidence for L1/L2/L4 rather than landmarks. Propose: a human can run `tools/bakeoff.sh <prompt>` and see the per-model answer, ranked. |
| **T330** · done · B | **L4** | Re-point the nine retirement evidence edges; without re-pointing, 8 retirements sit deferred, and the register's evidence graph has dangling edges. |
| **T335** · done · A | **L2** | Sprint console for G3b pass0 build; the G3b pass IS L2's discharge — every row underneath it (T338–T348) is L2 work. |
| **T336** · done · C | **L1** | Fleet hardening sprint console; the seven rows under it (T317, T319, T322, T325, T336.1, T336.2, T336.3) are dashboard-truth work, T336 is the console that ran them. |
| **T337** · done · C | **L1** | Fleet hardening round 2; T336's debt and the remaining rows, all dashboard/process-safety. |
| **T338** · done · D | **L2** | MG-INV move-generator differential invariant; this *is* one of L2's four correctness properties (key agreement via independent move generator). |
| **T339** · done · D | **L5** | Extract the kernel move generator into `src/rules.zig`; the kernel extraction is L5's foundation (one rulebook lives here), held unpromoted on purpose. (Stretch: T339 is the *extraction*, not L5's promotion. The promotion is gated on mutation testing. But the row is foundational for L5, and the extraction IS L5's instrument-side half.) |
| **T340** · done · E | **L0** | Battery independent move generator + state-key encoder; this is the instrument that lets the table's values be checked. (Stretch: the *independent* move generator is the instrument that proves the table; the table's existence is L0, the instrument's existence is L0's other half.) |
| **T341** · done · F | **L2** | Solver-side move-set dump utility for I11; I11 is one of L2's four correctness properties. |
| **T342** · done · E | **L2** | C-A1 forward + C-A2 backward closure; this *is* L2's closure property (one of the four conditions). |
| **T343** · done · E | **L2** | I4 Bellman residual at 4×4; L2's first condition. |
| **T344** · done · E | **L2** | I5 SCC containment at 4×4; L2's cycle-containment condition (the one whose sample of 22 entries had to be corrected to "deferred" before T344). |
| **T345** · done · D | **L2** | G1/G3 key-agreement at 4×4; L2's second condition. |
| **T346** · done · E | **L2** | I11 move-set consistency; L2's fourth condition. |
| **T347** · done · E | **L0** | M9 battery-health meta-check; the battery that catches a broken invariant must be itself observed. (Stretch: M9 is the meta-instrument that proves the instruments actually run — it is L0's "instruments exist" half, not its table half.) |
| **T348** · done · A | **L2** | G3b pass0 acceptance; this *is* the discharge verdict for L2 (subject to T363's four-gap closure). |
| **T349** · done · C | **NO LANDMARK — question the task** | Malformed registration (shell-quoting accident), superseded by T352; the row carries no work and was failed on purpose. Question its existence in the kanban at all — its only function is to record that the registration was wrong. |
| **T350** · done · C | **L1** | `cmdDone` two-phase lock hardening; a row that flips its own status during acceptance is dashboard lying, and the lock is the fix. |
| **T354** · done · B | **L4** | Register triage: what is a claim, what is a note, what is archaeology; the 132-row classification is L4's plan document. |
| **T355** · done · G | **L1** | `managent tell` / `inbox` mechanism; replaces the human-relay and makes the dashboard read the same on every console. |
| **T356** · done · B | **L1** | Give every claimlint check a canonical name alongside its ID; the dashboard's checks must be human-readable to be trustworthy. |
| **T359** · done · F | **L7** | Symmetry fold census measuring the ~16× that gates 5×5; same chain as T358 — measured cost is prerequisite for L7. (Stretch: T359 only measures the *symmetry fold*, not the full scaling; the L7 chain is the same.) |
| **T360** · done · D | **L0** | `zig build test` never finishes — a 2×2 brute force recurses forever; L0's own self-test cannot be observable while the suite is broken. |
| **T361** · done · I · abandoned | **L3** | Old-vs-new engine kifu (the abandoned one); T361 was the first attempt, killed with no work in tree, replaced by T366. Same L3 chain, but the row never delivered. |
| **T363** · done · E | **L2** | Finish G3b: four gaps between here and discharge; this *is* L2's discharge by closing the four remaining conditions. |
| **T365** · done · B | **L1** | Date-prefix sweep on `docs/audits/`; chronological `ls` makes the dashboard read in time order. |
| **T366** · done · I | **L3** | Old-vs-new engine kifu (re-registration of T361); produces the committed SGF files that make L3 observable. |
| **T367** · done · D | **L4** | Author the race packets and seal the answer keys; the races test L1/L2/L4 readings, and the packets' integrity is the test's integrity. (Stretch: races are evidence for L1/L2/L4, but T367 is the *mechanism* that makes the races trustworthy — which is itself L4 hygiene.) |
| **T368** · done · C | **L1** | `managent standing` reads C7=0 forever because the trigger markers match the old text; making the trigger fire when it should is dashboard truth. |
| **T369** · done · J | **L1** | `zig build test` is red by construction and nobody owns the redness; the manifest+gate for known reds is dashboard truth about which failures are known. |
| **T370** · done · G | **L1** | Task identity never reaches `tools/runner`; liveness is blind and directives cannot land — a dashboard that cannot see runs is not a dashboard. |
| **T371** · done · D | **L4** | First race runs (pro vs flash on races 1 and 2); the races themselves test L1/L2/L4 readings, and T371 is the first run that lands evidence in the right place. |
| **T372** · done · K | **L4** | Z-R-TIE: test Markovian state-sufficiency with *contrasting* histories; this is a re-derivation picked by walking the requirement tree, and it is the first tree-order node whose load-bearing claim has never actually been tested. (Stretch: T372's claim is L2-adjacent; the brief itself is a re-derivation for L4, and its finding moved into the register. The chain is "register cleanup" not "value correctness.") |
| **T373** · done · B | **L4** | Adopt the register triage, Step 0 as one atomic package; moves 132 archaeology rows to `archives/register/` and locks the C3 floor. |
| **T374** · done · L | **L0** | `weizigo_showscores` panics on 4×4 (`@memcpy` alias); L0's "play the engine over GTP" path crashes until fixed. |
| **T375** · done · I | **L3** | Does the NEW engine ever throw away a winnable position? (the missing half of L3); completes L3 by measuring the new engine for the same fault. |
| **T376** · done · D | **L1** | The race harness cannot run from a worktree; the worktree boundary is weaker than claimed — instrument honesty. |
| **T377** · done · B | **L2 + L4** | Execute the G3b promotions, and absorb the five findings; records L2's result in the ledger (L2) and makes five findings files machine-readable (L4). One row, two landmarks, both stated. |
| **T378** · done · K | **L4** | Shipped QA-023 probe kernel still has inverted White guards at HEAD; QA-023 is a live register claim, and readings taken with a wrong-signed kernel cannot back it. (Stretch: this is the kernel for QA-023, an L4 register claim; the chain is "register claim integrity" not "L2 value correctness.") |
| **T379** · done · I · blocked | **L2 + L3** | Engine must honour its own predictions: per-ply trajectory consistency in self-play. (Stretch: blocked, so it never delivered; the chain is "answer-key property" for L2 and "new engine soundness" for L3 — both genuine but blocked.) |
| **T380** · done · M | **L2** | Critical review: is ko correctly and exhaustively handled in the retrograde construction? L2 at its weakest joint — basic ko is the highest logical bug risk. |
| **T381** · done · N | **L2** | Play an independent engine (GNU Go) against the 4×4 oracle; an opponent that shares no code, no table and no author with us is the one thing every check so far has lacked. |
| **T382** · done · M | **L2 + L7** | Define "pathological goban" formally, then measure it at every solved size. L2 understanding + L7 costed (a formal definition is needed for ladder-rung arguments to mean anything). |
| **T383** · done · E | **L2** | Fix the key-byte ko decode in vb_closure, and re-issue the figures it produced; the discharge's denominators are correct after this. |
| **T384** · done · B | **L4** | Absorb the new findings, and correct the mis-formulated B1 lemma; two jobs — register cleanup. |
| **T385** · done · I | **L2** | Show the positions, then fix the name: "ko-sensitive" is measurably wrong; L2's central distinction becomes inspectable. |
| **T386** · done · M | **L2** | Evaluate the operator's proposal: resolve the bracketed region with superko; ADR for L2's single-score path or evidence why it cannot exist. |
| **T387** · done · M · blocked | **L2** | Does bounding total captures make the game finite, and at what cost? Investigation toward L2's single-score table. |
| **T388** · done · J | **L0** | One instrument, every size: "the same test at every rung" actually true; L0's instrument honesty. |
| **T389** · done · I | **L2 + L3** | Engine must honour its own predictions: per-ply trajectory consistency in self-play (re-registration of T379 after it was blocked). Same chain as T379. |
| **T390** · done · C | **L1** | Make duplicate dispatch refuse; the dashboard's "in_progress" must be unique. |
| **T391** · done · J | **L2** | Which I5 instrument is telling the truth? Two implementations, every count different; adjudicating L2's cycle-containment condition. |
| **T392** · done · P | **L1** | Establish the real failing set at clean HEAD, and bisect only what genuinely fails; dashboard truth about which failures are real. |
| **T393** · done · A | **L2** | Two-life census: where does coexisting unconditional life begin, and does existing life ever sit under a straddling bracket? Characterizes the bracketed region. |
| **T394** · done · B | **L2** | Can-force-life: a Boolean retrograde pass testing "loops are mutual territory-denial"; L2 instrument for the draw-by-loop region. |
| **T395** · done · Q | **L0 + L5** | Does every property have exactly one production implementation? Instrument-side twin of L5 (one rulebook); also L0 (instruments exist). |
| **T396** · done · B | **L4** | Four findings files still cannot be absorbed; L4 housekeeping. |
| **T397** · done · M | **L2** | T387's value mode never ran — a `u6` loop counter made `while (bitpos < 64)` a tautology; unblocks the L2 capture-budget reading. |
| **T398** · done · A | **L2** | Two research docs whose measurements stand and whose reasoning does not; L2 narrative accuracy. |
| **T399** · done · C | **L1 + L4** | Unescaped `--note` text corrupts managent's JSON; took the whole kanban down. Fleet-outage bug: dashboard truth (L1) + ledger integrity (L4). |
| **T400** · done · A | **L2** | C2 scoring axiom: the prose claims Benson dead-stone removal; the solved game does none. L2 axiom hygiene — text must describe the game that was actually solved. |
| **T401** · done · E | **L0 + L3** | New engine vs old engine from previously-bracketed positions, both colours; engine does not lose from claimed-won positions (L0) and new-outplays-old (L3). |
| **T402** · done · M | **L2** | Demote the capture budget to a named, pluggable bracket-resolver; protects L2 from contamination. |
| **T403** · done · C | **L0** | A rejected `boardsize` desyncs the GTP session; L0's "play the engine over GTP" path breaks until fixed. |
| **T404** · done · A | **L4** | Absorb the 2026-08-06/07 backlog — 8 proposed rows into the register; L4 housekeeping. |
| **T405** · done · S | **L0 + L2 + L4** | Sprint console for T401, T402, T403 and T398; one row, three landmarks (engine plays in Sabaki, bracketed region, ledger clean). |
| **T406** · done · C | **L4** | The absorption machinery is broken in two places; T404 succeeded by hand, not by tooling. L4 housekeeping. |
| **T407** · done · E | **L3 + L2** | The four-game matrix: where new/new, old/new and old/old disagree; engine-outplays-old (L3) and value-correctness (L2). |
| **T408** · done · G | **L4** | Does a DeepSeek parent actually reach the Ollama models? Validate the tooling before a sprint depends on it; fleet capacity. |
| **T409** · done · S | **L1 + L4 + NO LANDMARK (T408)** | Sprint console for the six-game divergence matrix, the absorption machinery, and the fleet-capacity test. T408 is fleet capacity (L4-adjacent), the other two are L1/L4. |
| **T410** · done · H | **L4** | Audit the instruction corpus: find the kludge, the contradictions, and the rules nobody follows; L4 housekeeping. |
| **T411** · done · C | **L1 + L4** | An agent that replies "OK." and runs nothing; make dispatch verify the work, not the answer. Dashboard truth (L1) and ledger integrity (L4). |
| **T412** · done · E | **L2** | When does a position loop, and is a truncated game's score ever mistaken for a value? Operator's central open question. |
| **T413** · done · H | **L4** | Execute the ruled-on instruction-corpus fixes; L4 housekeeping. |
| **T414** · done · S | **L2 + L1 + L4** | Sprint console for the loop question, dispatch verification, and corpus cleanup. Three rows, three landmarks. |
| **T415** · done · J | **L4** | The solution tree: which construction steps are PROVED, which are guessed; L4 register archaeology. |
| **T416** · done · E | **L2** | Does the OPTIMAL-MOVE SUBGRAPH contain a cycle? Operator's central open question; the last unanswered piece of the loop thread. |
| **T417** · done · S | **L2 + L4** | Sprint console for the cycle test and the solution tree. Two rows, two landmarks. |
| **T418** · done · A | **L4** | Absorb the T416/T402 backlog (5 rows), and fix the evidence paths before they land; L4 housekeeping. |
| **T419** · done · E | **L2** | The full loopy-child partition, and the depth-2 question; L2 measurement. |
| **T420** · done · E | **L0** | Turn GNU Go, Pachi and Fuego up to full strength: a better falsifier, not a stronger opponent. L0's "engine does not lose from claimed-won positions" via independent opponent. |
| **T421** · done · H | **L4** | 72 committed docs cite evidence that lives only in `/tmp`, and 43 citations are already dead; L4 evidence integrity. |
| **T422** · done · A | **L4** | Absorb T419's two taxonomy rows and T420's full-strength extension; L4 housekeeping. |
| **T423** · done · G | **L4** | Date-partition `/tmp/weizigo` so tomorrow's runs are separable from this week's; L4 evidence integrity. |
| **T424** · done · C | **L1 + L4** | The claim/close lifecycle flakes: five defects that all let a row look finished when it is not. Dashboard truth (L1) and ledger integrity (L4). |
| **T425** · done · G | **L1** | `argus --mode doctor`: encode the Orchestrator's manual sweep as a check the operator can run in one line; dashboard truth. |
| **T426** · done · J | **L1 + L4** | SPEC ONLY: an assertion ledger, and a status utility that displays rather than narrates. Dashboard (L1) and ledger (L4) — spec only. |
| **T427** · done · C | **L4** | T425's regression wrote 16 fixture rows into the LIVE kanban; L4 housekeeping. |
| **T428** · done · S | **L1** | Tool consolidation sprint; the instruments the project reasons about itself with become trustworthy. |
| **T429** · done · S | **L1** | Audit of T428 Phase 1; tool consolidation instrument honesty. |
| **T431** · done · C | **L1** | Depth cap bounds recursion instead of banning delegation; sprint console safety. |
| **T437** · done · S | **L1** | Implement the consolidation plan; T428's design lands. Instrument honesty. |
| **T438** · done · C | **L1** | The test suite depends on disposable `/tmp` state, and something archived it away; L0's self-test depends on this fix. |
| **T441** · done · S | **L1 + L4** | SPRINT: make the observation layer say only what it can support; dashboard truth (L1) and ledger integrity (L4). |
| **T441-AUDIT** · done · S | **L1** | Verify the observation layer fixes; T441 audit. |
| **T442** · done · A | **L4** | Absorb the backlog, fix a non-conforming findings file, and de-state one doctor arm; L4 housekeeping. |
| **T443** · done · A | **L4** | Where artifacts live: `/tmp` vs `untracked/` vs `data/` vs tracked; L4 storage-durability policy. |
| **T444** · done · A | **L4** | Triage the stale dispatchable rows; L4 ledger housekeeping. |
| **T445** · done · A | **L1** | Regression scripts must hard-fail when scratch creation fails, never run in the live repo; dashboard/safety truth. |
| **T446** · done · C | **L1** | The kanban board must render what the assertion ledger asserts; dashboard truth (board reflects ledger). |
| **T447** · done · A | **L1** | Read-only audit of remaining live-repo escape paths in the shell test harness; safety/dashboard truth. |
| **T451** · done · J | **L0** | Fix the t419_taxonomy `no_loop_a` margin intCast crash; L0's self-test crashes until fixed. |
| **T453** · done · J | **L0** | Fix the vb_bellman_4x4 `applyMove` OOB; L0's self-test crashes until fixed. |
| **T455** · done · C | **L1** | An unlabelled commit has no scope protection, and a warning is not a control; d7e4bdb authorship-loss incident fix. |
| **T456** · done · A | **L4** | An instrument that measures whether a worker reports failure honestly; L4 register integrity. |
| **T457** · done · A | **L1 + L4** | Would any existing control have caught the T452 semantics change? Dashboard truth (L1) and ledger integrity (L4). |
| **T459** · done · A | **L1** | Grade the T452 design race, blind; races are dashboard integrity checks. |
| **T460** · done · A | **L1** | Second, independent grader of the T452 design race; same chain. |
| **T461** · done · A | **L1 + L4** | Does the assertion ledger earn its existence? Dashboard (L1) and ledger (L4) — verdict with evidence. |
| **T462** · done · A | **L1** | Cut the backlog to a short do-now list; dashboard steering. |
| **T463** · done · C | **L1** | Add qwen to the canonical model list; fleet integrity. |
| **T464** · done · C | **L1** | One status resolver, and a way for a task to leave; dashboard truth (every view agrees). |

---

## Distribution

**By status:**

| status | count |
|---|---|
| dispatchable | 17 |
| in-progress | 6 |
| done | 123 |
| **total** | **146** |

**By landmark (counting each row's primary chain; one row may serve more than one landmark):**

| landmark | count | share |
|---|---|---|
| **L0** (table and instruments exist) | 17 | 12% |
| **L1** (dashboard tells the truth) | 76 | 52% |
| **L2** (proven 4×4 values) | 39 | 27% |
| **L3** (new engine outplays old) | 6 | 4% |
| **L4** (ledger is clean) | 51 | 35% |
| **L5** (one rulebook) | 2 | 1% |
| **L6** (mission) | 0 | 0% |
| **L7** (5×5 decision, costed) | 2 | 1% |
| **NO LANDMARK — propose** | 2 | 1% |
| **NO LANDMARK — question** | 2 | 1% |

(Counts exceed 146 because 16 rows serve more than one landmark: e.g. T377 → L2 + L4; T399 → L1 + L4;
T401 → L0 + L3; T405 → L0 + L2 + L4; T407 → L3 + L2; T411 → L1 + L4; T414 → L2 + L1 + L4; T417 → L2 + L4;
T424 → L1 + L4; T426 → L1 + L4; T441 → L1 + L4; T457 → L1 + L4; T461 → L1 + L4; T377 already counted;
T377's two landmarks counted once each; T395 → L0 + L5; T382 → L2 + L7; T379 → L2 + L3; T389 → L2 + L3.)

**Honest non-`L<n>` outcomes:**

- **NO LANDMARK — propose:**
  - **T328** — bake-off harness; propose `L9 (the fleet can race its own workers on demand)`. The races
    serve L1/L2/L4, but the *ability to race* is its own capability and not on the map.
  - **T458** — disambiguate "row"; propose `L8 (the language the project speaks is unambiguous)`.
    A human can see at a glance which "row" is meant in every sentence the project writes.
- **NO LANDMARK — question:**
  - **T349** — malformed registration (shell-quoting accident), superseded by T352; carries no work
    and was failed on purpose. The only honest role for it in the kanban is to record that the
    registration was wrong.
  - **--bundle** — bundle path `untracked/T430-phase2-audit.md` does not exist on disk; the phase-2
    content has been delivered under T433; `claim_count=0`. There is nothing the row would do that
    the ledger does not already reflect.

**L6 has no tasks pointing at it.** It is the convergence point — it requires L2, L4, L5 all together.
No individual task can advance L6 on its own; L6 will be discharged by the conjunction of these.
That is by design, not a gap. Stating it here because it is the most surprising reading of the
distribution.

**L5 has two tasks.** T339 (kernel extraction) and T395 (one implementation per property). Both are
foundational — they prepare L5 but do not discharge it. The kernel extraction is held unpromoted on
purpose. L5 is correctly stalled waiting on L2.

**L7 has two tasks.** T358 (scaling census) and T359 (symmetry fold), plus T382's half-share (formal
"pathological goban"). All three are prerequisite measurements for the L7 costed decision. L7 is
correctly idle waiting on L6.

---

## Gaps

**Landmarks with no tasks (the map's idle work):**

- **L5** — only 2 rows, both foundational. Correctly stalled.
- **L6** — 0 rows. Correctly absent — it is the conjunction.
- **L7** — 2 rows, both prerequisite measurements. Correctly idle.

**Clusters pointing at one landmark:**

- **L1** carries 52% of the kanban. The do-now queue is entirely L1/L4 work, with **one row** serving
  L4 and **none serving L2**. (T467 is the one row that *rules on* L2, but it is currently in
  progress and not yet a discharge.)
- **L4** carries 35%. The ledger-cleanup debt is large but bounded — T354's plan locked the floor
  in four declared steps (76 → 48 → 32 → 18 → 0 unbacked).

**The brief's pre-measured finding (test it):** *"of the five do-now tasks, four serve L1 or
process safety and one serves L4; none advances L2."* **Does that survive this assignment?**

Let me count the five do-now rows from `docs/status/backlog-2026-08-19.md` as they appeared there,
not as the kanban reads today. The five were T378, T455, T448, T454, T442. (T378 has since closed
on 2026-08-19, so it is in the *done* section of this assignment, not the live one.)

- T378 · done · K — **L4** (the QA-023 probe kernel inverted White guards; readings taken with a
  wrong-signed kernel cannot back a live register claim).
- T455 · done · C — **L1** (unlabelled commit has no scope protection).
- T448 · in-progress · A — **L1** (killed regression runs leave fixtures in the live tree).
- T454 · dispatchable · J — **L1** (suite's failing set depends on who runs it).
- T442 · done · A — **L4** (absorb backlog + fix non-conforming findings + de-state doctor arm).

**Pre-finding verdict:** four serve L1 / process safety (T455, T448, T454 — and arguably T442 is
*mostly* L4 with L1-adjacent process safety), one serves L4 (T378). **None serves L2.**

**My verdict:** the finding **survives** with one amendment. Of the five, **two serve L4** (T378,
T442), **three serve L1** (T455, T448, T454), and **none serves L2**. The four-L1-or-process-safety
claim is correct; the "one serves L4" understates T442's L4 weight. The L2 finding holds — and
that is the brief's load-bearing claim: **the do-now queue advances L1 and L4 only; L2 has no do-now
representation.** T467 (the L2 discharge audit, in progress) is the only L2-adjacent live row, and
it is a *ruling* on L2, not work that produces L2's evidence.

This confirms the operator's worry that infrastructure is displacing the mission. The reason it
does so is honest: the L1/L4 work is the *cost of having measurable instruments and an honest
ledger* — without it, L2's verdicts would be unverifiable. The sequencing is correct (instruments
before claims), but the brief's pre-measured finding that **the do-now queue has zero L2 rows**
stands, and that is the operator's most valuable sentence in this exercise.

---

## Which tasks failed to chain

Two tasks, both honestly surfaced:

1. **T349** — registration accident, failed-by-design. Questioned above.
2. **--bundle** — bundle path does not exist on disk; the phase-2 content has been delivered under
   T433; nothing the row would do would change the ledger. Questioned above.

Two more stretched but real:

- **T458** — disambiguating "row" is genuinely necessary work; the map has no landmark for it.
  Propose `L8 (the language the project speaks is unambiguous)` rather than fudging an `L<n>`.
- **T328** — bake-off harness is genuinely necessary work; the map has no landmark for it.
  Propose `L9 (the fleet can race its own workers on demand)`.

No task failed to chain by being mis-labelled with a made-up landmark. The four honest non-`L<n>`
outcomes are surfaced as the brief intended.

---

## What a human can now see that they could not before

1. **The do-now queue is honest infrastructure work, not drift.** Three of five serve L1, two serve
   L4. The sequencing is correct (instruments before claims), but the absence of any L2 do-now row
   is the operator's signal that infrastructure has run ahead of mission.
2. **L2 is currently held in place by T467's audit verdict, not by evidence production.** The L2
   properties are discharged (T363, T383 closed the four gaps), but the audit may rule either way;
   that is why the queue is what it is today.
3. **Two proposed new landmarks** (`L8` language honesty, `L9` fleet race capability) name work the
   project is actually doing but the map does not yet see. They are proposals, not assertions; the
   Orchestrator rules on whether the map gains them.
4. **L6 has zero tasks pointing at it.** That is by design (it is the conjunction of L2+L4+L5), but
   it is worth saying plainly: no individual task can advance L6.

---

## Findings file

`findings/T468-landmark-assignment.json` records the same distribution, plus the
`notes` field carries the operator-directive IDs read during this task (none were pending at the
start — `bin/managent inbox T468 --ack` returned `-- no pending directives --`).

**Landmark:** advances `L1 (the dashboard tells the truth)` — a queue whose tasks cannot be traced
to a goal is a queue nobody can steer by. Every line above is a chain to a landmark, an honest
question, or a proposed addition to the map.
