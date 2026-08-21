# Grading Report: Pass 1 Specs

## 1 Metrics

| metric (kebab-case) | definition (one line) | importance 0–10 |
|---|---|---|
| mechanism-correctness | Does the spec correctly understand and build on the measured escape (session-leader escapees, reparenting race, enumeration requirement)? | 10 |
| owned-definition | Is "owned" defined in a testable, unambiguous way with concrete assertions? | 9 |
| safety-completeness | Are safety guards specified with named, seeded controls — not hand-reasoned? | 9 |
| contract-precision | Verb name, arguments, exit codes, and output shape fully specified? | 8 |
| per-family-rigor | Is the per-family residual check specified clearly with exact commands? | 8 |
| controls-substantiveness | Are controls sufficient (null + seeded arms, both designed and justified)? | 7 |
| economy | Is the spec appropriately sized — complete without padding? | 5 |

## 2 Scores

| doc | metric | score 0–10 | justification (one line) |
|---|---|---|---|
| A | mechanism-correctness | 9 | Session-identity catch-all (sid==root-pid) is sound; notes setsid already at spawn, no change needed. |
| A | owned-definition | 10 | Four assertions (OWN-1 through OWN-4) each independently testable by oracle. |
| A | safety-completeness | 9 | 8 guards (G1–G8) each tied to named controls; all guards grounded in testability. |
| A | contract-precision | 10 | Name, args (--kill, --grace, --owner), exit codes (0/1/2/3/4), output line specified exactly. |
| A | per-family-rigor | 9 | Per-family check specified with exact commands (ps, getsid), deposit location in `docs/evidence/`. |
| A | controls-substantiveness | 9 | 10 arms (A–J), null + seeded, hand-traced audit required; seeded arms assert against ps oracle. |
| A | economy | 7 | 160 lines; dense and substantive, no padding visible but length is minimal for content. |
| B | mechanism-correctness | 6 | Token design via KERN_PROCARGS2 is clever but contradicts Spec D's measurement that ps/env not readable on macOS; design may not work. |
| B | owned-definition | 7 | O1–O5 testable but dependent on token inheritance, which is the load-bearing (and uncertain) design choice. |
| B | safety-completeness | 7 | 4 guards (G1–G4) plus leaked-token guard (G2); fewer guards than others, less comprehensive. |
| B | contract-precision | 8 | One verb, name, args (--token, --plan), exit codes, output shape all specified; semantics clear. |
| B | per-family-rigor | 7 | Per-family check mentioned but generic; does not specify exact commands as others do. |
| B | controls-substantiveness | 6 | S1–S5 named and seeded; fewer arms than others, and S1 depends on the token design being readable. |
| B | economy | 6 | ~250 lines; dense with token design but not obviously concise. |
| C | mechanism-correctness | 9 | Freeze-fixpoint approach with 3-round re-scan handles reparenting race correctly; builds on session-leader escapees. |
| C | owned-definition | 10 | O1–O5 all testable, explicit about reparenting and the snapshot rule; definitions are tight. |
| C | safety-completeness | 10 | 10 guards (G1–G10), each with named control; includes G7 rollback obligation (freeze then refuse must SIGCONT all). |
| C | contract-precision | 10 | Two verbs (snapshot-tree, kill-tree), all args, exit codes (0–4 with semantic distinctions), output shape precise. |
| C | per-family-rigor | 9 | Per-family check specified with exact probe commands; gates seeded arms; records PROVEN/CLAIMED status. |
| C | controls-substantiveness | 9 | N1–N2 null, S1–S8 seeded; includes instrument controls (disable X ⇒ arm Y must fail); comprehensive. |
| C | economy | 5 | 285 lines; very long but substantive (no padding); freeze-fixpoint and rollback require detailed explanation. |
| D | mechanism-correctness | 3 | Claims "one killpg on the session is sufficient," contradicting brief's own measurement that group/session kills are structurally insufficient for session-leader escapees. |
| D | owned-definition | 4 | "Owned" vaguely defined ("the system can always clean it up"); no testable assertions or controls. |
| D | safety-completeness | 3 | Proposes hand-reasoned guards (common sense, careful about operator's shell) without naming seeded controls; repeats 2026-08-20 failure mode. |
| D | contract-precision | 5 | Basic contract (name: proc-kill, args: pid + maybe refusal check) but incomplete; output "human-readable summary" is vague. |
| D | per-family-rigor | 1 | Does not address per-family check at all; assumes "POSIX process groups work the same everywhere." |
| D | controls-substantiveness | 2 | "Testing will confirm the verb works" — no controls named; no null or seeded arms; no audit plan. |
| D | economy | 9 | 65 lines; brief but dangerously so — omits required content to stay short. |
| E | mechanism-correctness | 10 | Two-verb design (snapshot-tree + kill-tree) explicitly recognizes root is not always live at call time; profound insight. |
| E | owned-definition | 10 | Precise: "every pid in snapshot, post-call either absent or reused (different start-time)"; one-pass capture, no re-targeting. |
| E | safety-completeness | 9 | 6 guards (G1–G6) including provenance, uid boundary, snapshot-only signalling, pid-reuse check, reach-limit honesty; all tied to controls. |
| E | contract-precision | 9 | Two verbs fully specified (arguments, modes, exit codes 0–4, output shape with JSON option); modes (live vs. snapshot) clear. |
| E | per-family-rigor | 9 | Per-family check specified, includes exact ps/getsid commands; notes which families are unmeasured and why seeded arms are gated. |
| E | controls-substantiveness | 9 | N1–N2 null, S1–S8 seeded; arms include the normal-exit orphan case (S3) and reach-limit proof (C6); comprehensive. |
| E | economy | 6 | 280 lines; long but the two-verb contract and root-timing complexity justify the length. |
| F | mechanism-correctness | 10 | Explicitly recognizes root-pid death-timing issue; frames normal-exit reach-limit as structural boundary, not verb defect. |
| F | owned-definition | 10 | Precise predicate: post-call snapshot diff with ppid/start-time verification; ownership captured then verified. |
| F | safety-completeness | 9 | 6 guards (G1–G6) including ownership provenance, uid boundary, downward-only walk, idempotence; all with controls. |
| F | contract-precision | 9 | Two verbs (snapshot-tree, kill-tree) fully specified; contracts clear; live vs. snapshot modes explicit. |
| F | per-family-rigor | 9 | Per-family check specified; notes which families are unmeasured; gates seeded controls appropriately. |
| F | controls-substantiveness | 9 | N1–N2 null, S1–S8 seeded; includes per-family residual check (§3), reach-limit proof, pid-reuse race. |
| F | economy | 5 | 285 lines; long but the scoping verdict (§9) — clarifying what pass 1 can and cannot do — justifies the length. |
| G | mechanism-correctness | 9 | SIGSTOP fixpoint prevents reparenting during walk; novel and clever, but adds complexity; builds on the measured mechanism. |
| G | owned-definition | 9 | Ownership-as-snapshot: enumeration is deterministic from one read; corollary reach-limit stated honestly ("unreachable" not "killed"). |
| G | safety-completeness | 8 | 5 guards (G1–G5) including snapshot-only signalling, pid-reuse check; one guard (G8, delegated-ownership exemption) may be scope creep. |
| G | contract-precision | 8 | Two verbs (proc tree, proc kill) specified; some output details vague (exact JSON schema, signal handling). |
| G | per-family-rigor | 8 | Per-family check specified; notes which families are unmeasured; controls gated until measurements run. |
| G | controls-substantiveness | 8 | C1–C8 named, null + seeded; comprehensive but one fewer than others; includes the reach-limit arm (C6). |
| G | economy | 7 | 280 lines; dense but not wasteful; SIGSTOP approach requires some explanation. |
| H | mechanism-correctness | 7 | Consent ledger + canary approach; mechanism understanding present but less detail; ledger design is novel and untested. |
| H | owned-definition | 7 | Operational definition given but less testable than others; does not formalize what "owned" means precisely. |
| H | safety-completeness | 7 | 4 guards (ledger consent, canary, no ppid=1 escalation, pid-1) with controls; novel guards but fewer than others. |
| H | contract-precision | 7 | Basic contract specified (name, args, exit codes); some details vague (JSON schema, per-pid error details). |
| H | per-family-rigor | 4 | Per-family check mentioned but not detailed; cites tools/runner.py (wrong language — runner is Zig); check command not given. |
| H | controls-substantiveness | 6 | Null and seeded controls named; fewer arms than others; ledger/canary controls are novel but unvalidated. |
| H | economy | 8 | 160 lines; moderate and clear, but lack of detail in per-family check suggests premature brevity. |

## 3 Verdicts

- **spec-A: great** — session-identity catch-all is elegant and economical; no spawn change needed; strong across all dimensions.
- **spec-B: good** — token design is novel but contradicted by Spec D's measurement that environment is not readable via ps on macOS.
- **spec-C: great** — freeze-fixpoint with mandatory SIGCONT rollback is the most rigorous; G7 captures a non-obvious obligation; instrument controls are exemplary.
- **spec-D: bad** — misunderstands the core problem; claims killpg suffices despite the brief's measurement that session-leader escapees are unreachable by group kills.
- **spec-E: great** — root-timing insight (root not always live on normal-exit path) is profound and changes the design; two-verb approach handles this correctly.
- **spec-F: great** — explicitly frames normal-exit reach-limit as a structural boundary; scoping verdict (§9) clarifies what pass 1 cannot promise.
- **spec-G: good** — SIGSTOP fixpoint prevents reparenting during walk; clever and sound, but adds complexity; owns-as-snapshot framing is precise.
- **spec-H: good** — consent ledger and canary guards are novel and grounded in controls, but per-family rigor is weak (cites wrong language, omits check details).

## 4 Ranking

C > E > F > A > G > B > H > D
