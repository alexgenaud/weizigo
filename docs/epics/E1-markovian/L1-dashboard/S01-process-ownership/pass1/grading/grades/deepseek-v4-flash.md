All eight documents read, plus the tournament brief. I diffed spec-A against spec-F: they are substantively the same document (identical contract, guards, arms, findings; only cosmetic differences in title, list markers, and one scope sentence) — a fact that shapes two verdicts. My grading follows the brief's stated criteria (testability, evidence correctness/citation, safety quality, mechanism fit + per-family check, economy) plus the brief's numbered content requirements.

---

# Grading panel — pass 1 spec tournament

## 1 Metrics

| metric (kebab-case) | definition (one line) | importance 0–10 |
|---|---|---|
| testability | Requirements reduce to closed, checkable predicates; null/seeded arms named with independent oracles; tests red-first, before implementation | 10 |
| evidence-correctness | Factual claims cite path:line and match the measured mechanism; no load-bearing unverified assertion passed as fact | 10 |
| mechanism-fit | Builds on the measured session-leader escape (descendant enumeration, dead-root reach, per-family residual check) and stays family-independent for the one dispatch interface | 10 |
| safety-guards | Never-killable set defined; every guard paired with a control; no hand-reasoned "common sense" protections | 9 |
| cannibalization-completeness | Pass-done = old code deleted (killpg site, normal-exit gap, the incident's cull line); acceptance enforced by a grep gate, not prose | 8 |
| uncertainty-honesty | Open questions stated plainly; load-bearing assumptions flagged as such rather than asserted | 7 |
| economy | Length is substance, not padding; short where possible; every section earns its space | 7 |

## 2 Scores

| doc | metric | score 0–10 | justification (one line) |
|---|---|---|---|
| spec-A | testability | 9 | OWN-1..4 each mapped to an arm; verb counts cross-checked against an independent ps oracle, disagreement = FAIL (§1); arms D/I/J must fail red before the verb exists (§5). |
| spec-A | evidence-correctness | 9 | Restates the brief's measurements correctly and adds two checkable code readings — setsid at spawn for every run (`tools/runner:1161`→`:1241`) and the existing per-poll walker (`:1353`) (§3). |
| spec-A | mechanism-fit | 9 | sid==root-pid catch-all reaches dead-root session escapees with no spawn change; per-family check gated before seeded arms are final, nested-session residue analyzed (§3). |
| spec-A | safety-guards | 9 | G1–G8 each with a named control and a never-killable list; dead-root trust boundary stated rather than hidden (G7) (§4). |
| spec-A | cannibalization-completeness | 8 | Replaces `:1505` and fills the normal-exit reap-nothing gap, but deliberately keeps the host-guard single-pid kill that culled 12 workers (§6). |
| spec-A | uncertainty-honesty | 9 | Full section: pid-reuse, daemonized residue, pending family checks; names its own over-scope candidate (§9, §10). |
| spec-A | economy | 8 | ~23 KB, dense; every section load-bearing, restates the mechanism only to build on it (§3). |
| spec-B | testability | 8 | O1–O5 assertable with N/S arms and seeded-defect controls, but the S5 honest-evader arm weakens the completeness guarantee (§1, §8). |
| spec-B | evidence-correctness | 6 | Cites the measured lines correctly, but asserts KERN_PROCARGS2 env is "readable for same-uid processes on macOS" with no evidence — a capability spec-C measured absent on this host (§0 vs C §3). |
| spec-B | mechanism-fit | 7 | Token membership is topology-blind and family-agnostic, but needs spawn-time minting (more moving parts) and inherits the dead-root gap if env is unreadable (§0, §6). |
| spec-B | safety-guards | 8 | The leaked-token guard (G2) is novel and sharp; uid-guard control gap stated; fewer guards than the top tier (§5). |
| spec-B | cannibalization-completeness | 8 | Replaces `:1505`, fills normal exit, AND routes the host-guard `:1432` through the verb; acceptance grep covers killpg\|SIGKILL (§6). |
| spec-B | uncertainty-honesty | 6 | Lists uncertainties, but its biggest risk (env readability) is asserted as fact — the confident guess the brief warns against (§0 vs §9). |
| spec-B | economy | 7 | ~15 KB, dense, design-decision-first structure; no padding (§0). |
| spec-C | testability | 10 | O1/O2 closure-recompute postcondition, mutation controls ("disable X ⇒ arm Y must fail"), differential oracle vs the existing Python walker, repeat-count race arm (§1, §5). |
| spec-C | evidence-correctness | 10 | Independently measured the session topology, the ps -E/no-env negative, Zig's missing getsid/kinfo_proc; every claim path:line (§3, §9). |
| spec-C | mechanism-fit | 9 | Freeze→fixpoint over ppid/sid/pgid edges with start-time filtering; per-family check with recording duty; heavier ps+getsid enumeration, cost flagged (§3). |
| spec-C | safety-guards | 10 | G1–G10 each with a control, incl. mandatory SIGCONT rollback (G7) and the protected-set guard stopping one worker's cleanup killing another (G6) (§4). |
| spec-C | cannibalization-completeness | 10 | C1–C6 covers the guard cull line `:1435`, the exception path, and mechanized grep gates in the acceptance command (§6). |
| spec-C | uncertainty-honesty | 9 | Six open questions incl. lstart parsing and the G8 judgement call offered for deletion; flags its own scope risk (§9, §10). |
| spec-C | economy | 7 | Longest at ~27 KB; substance throughout, but the self-quarry section and verbose table cells could be trimmed (§10). |
| spec-D | testability | 1 | One happy-path arm; edge cases deferred to production discovery — the opposite of named controls, test-first (§5). |
| spec-D | evidence-correctness | 1 | Zero line citations; misstates the mechanism as a group kill no tree can escape (§2, §3). |
| spec-D | mechanism-fit | 0 | Proposes killpg on the group leader — exactly the structurally-insufficient primitive the brief measured — and declares the per-family check unnecessary (§3). |
| spec-D | safety-guards | 1 | "Protected by common sense" and "the verb will be careful" are the hand-reasoned guards the brief names as the failure mode (§4). |
| spec-D | cannibalization-completeness | 1 | Burn-in both paths side by side, delete old code "in a follow-up pass" — the brief makes deletion the pass's completion condition (§6). |
| spec-D | uncertainty-honesty | 0 | Asserts universality across harnesses; states no open questions (§3). |
| spec-D | economy | 4 | Short, but brevity here is absence of content, not economy of expression (§1–§8). |
| spec-E | testability | 9 | Closed snapshot predicate with start-time pid-reuse; S3 arm documents the dead-root gap then proves snapshot recovery; S8 is a real end-to-end arm (§1, §5). |
| spec-E | evidence-correctness | 9 | Verifies `std/process.zig:397` and zero setsid/setpgid matches; reads the `:1311`→`:1538` normal-exit flow; flags the reparenting-timing claim as unverified (§3, §9). |
| spec-E | mechanism-fit | 9 | The dead-root insight is the corpus's sharpest; the two-verb snapshot contract is sound, but the poll-cadence staleness window (children forked after the last snapshot) is left unnamed (§3). |
| spec-E | safety-guards | 9 | G1–G6 with controls; catches that refuseLiveWrite protects kanban state but not process kills; explicit deny-list belt-and-suspenders (§4). |
| spec-E | cannibalization-completeness | 8 | Replaces `:1505` and rebuilds normal exit around snapshots, but never touches the host-guard cull line at `:1432`/`:1435` (§6). |
| spec-E | uncertainty-honesty | 10 | Names its load-bearing reparenting claim unverified with a two-line probe to run first; admits the per-family check is unrun (§9). |
| spec-E | economy | 8 | ~20 KB, dense, argued not padded; the two-verb machinery is justified by the mechanism (§2, §3). |
| spec-F | testability | 9 | Same OWN-1..4 arms, oracle cross-checks, red-first D/I/J as spec-A (identical text) (§1, §5). |
| spec-F | evidence-correctness | 9 | Same verified code readings as spec-A; no independent additions (identical text) (§3). |
| spec-F | mechanism-fit | 9 | Same sid==root-pid design and per-family gate as spec-A (identical text) (§3). |
| spec-F | safety-guards | 9 | Same G1–G8 with controls as spec-A (identical text) (§4). |
| spec-F | cannibalization-completeness | 8 | Same killpg replacement, normal-exit reap, and kept host-guard line as spec-A (identical text) (§6). |
| spec-F | uncertainty-honesty | 9 | Same uncertainties section as spec-A (identical text) (§10). |
| spec-F | economy | 8 | Same content as spec-A; the corpus therefore carries this document twice (§0). |
| spec-G | testability | 9 | Snapshot-capture rule makes the reparent race a testable postcondition (C3); C6 pins the reach limit; red-first discipline (§1, §5). |
| spec-G | evidence-correctness | 9 | M1/M2 citations checkable; one overstatement — "no point-in-time enumeration" can reach normal-exit orphans — holds only for live-root walks, not E's pre-death snapshot (§9 vs E §3). |
| spec-G | mechanism-fit | 9 | Descendant enumeration as a superset of every group/session scheme; per-family check with getsid; reach-limit boundary with T548 honestly drawn (§1, §3). |
| spec-G | safety-guards | 9 | G1–G5 tight and controlled; never-killable set checked at the signal step, not the read step; pid-reuse via start time (§4). |
| spec-G | cannibalization-completeness | 9 | `:1505`, normal exit, and flags `:1432` in-scope with a recorded-decision requirement if descoped; acceptance is a grep gate (§6). |
| spec-G | uncertainty-honesty | 9 | Four stated uncertainties incl. the flaky pid-reuse seed (bounded interpretation + unit backup) and the unrun family check (§10). |
| spec-G | economy | 8 | ~17.7 KB, tight; table-form contract is compact (§2). |
| spec-H | testability | 4 | Arms are named, but null-reparent-race asserts the verb kills a reparented child its own §1 definition says is not ours — internally inconsistent (§1 vs §5). |
| spec-H | evidence-correctness | 4 | Hedges the mechanism's file ("tools/console.zig (or claude harness runtime)"), mischaracterizes the killpg target as the console's group, and asks if the verb may be standalone after the brief fixed it inside the binary (§2, §3, §7). |
| spec-H | mechanism-fit | 4 | Gets the session-leader shape, but the dead-root path ("enumerate ppid==root_pid children") cannot work after reparenting — the exact consequence (i) it must build on (§2). |
| spec-H | safety-guards | 4 | Consent ledger and canary are real guards with controls, but the ledger is a new per-harness moving part and the canary needs the work's cooperation; "no ppid=1 escalation" reclassifies a leak as success (§4). |
| spec-H | cannibalization-completeness | 5 | Converts both mandated sites and deletes killpg, but the normal-exit double-call drives the broken dead-root path and line numbers are hedged with "~" (§6). |
| spec-H | uncertainty-honesty | 3 | Its open questions are answered by the brief already (family sessions; integrated binary); the ledger's failure modes are not questioned (§3, §7). |
| spec-H | economy | 5 | 11.9 KB with real content but meta-noise ("This must be recorded in the spec...") and hedged references (§3). |

## 3 Verdicts

- `spec-A: great — the sid==root-pid catch-all is the cleanest build on the measured leak with zero spawn change, every guard and arm cross-referenced; shortfalls are the absent mutation-test discipline and the host-guard cull line left in place.`
- `spec-B: good — boldest design (inherited-token membership, SIGSTOP fixpoint, leaked-token guard) but its core rests on an env-readability capability another lane measured absent on this host, and spawn-time minting strains the fewest-moving-parts constraint.`
- `spec-C: great — deepest evidence discipline (own session measurements, the ps -E negative that kills the token design) and the only spec with mutation controls, mandatory SIGCONT rollback, and a protected-set guard; longest, and its lstart parsing question is left open.`
- `spec-D: terrible — proposes exactly the killpg group-kill the brief measured as structurally insufficient, declares the per-family check unnecessary, and defers edge cases to production; no citations, no guards, no uncertainties.`
- `spec-E: great — the dead-root insight (normal-exit cleanup runs only after reparenting has severed discovery) and the two-verb snapshot contract are the corpus's sharpest finding, with model uncertainty honesty; the poll-cadence staleness window is its unnamed residual.`
- `spec-F: great — substantively identical to spec-A (same contract, guards, arms, findings; only cosmetic differences); as a consolidation input it adds a copy, not a second opinion.`
- `spec-G: good — the cleanest scoping: ownership-as-snapshot plus an honest reach limit that routes normal-exit orphans to T548 rather than promising the impossible; slightly overstates that no enumeration can reach them, which E's pre-death snapshot actually can.`
- `spec-H: bad — proposes reap, the name four other lanes independently identified as taken by the kanban reaper, its dead-root mechanism (ppid==root) cannot work after reparenting, and the per-family consent ledger is the per-harness branching the one-interface requirement forbids.`

## 4 Ranking

`C > A = F > E > G > B > H > D`
