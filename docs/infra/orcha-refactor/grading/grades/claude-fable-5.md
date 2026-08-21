All nine inputs read. Two things I verified before scoring: spec-A and spec-F are the same document up to formatting (bullet glyphs and separator style; every section, guard, arm, and citation is identical), so they receive identical scores; and I traced the load-bearing session logic myself — after a session leader dies, surviving members keep `sid == dead-leader-pid`, which is what separates the specs that actually close the normal-exit leak from those that only think they do.

Here is my grading deliverable:

---

## 1 Metrics

| metric (kebab-case) | definition (one line) | importance 0–10 |
|---|---|---|
| mechanism-fidelity | Builds correctly on the measured session-leader escape: reaches the dead-root/reparented case, treats the per-family check as owed, contradicts no measurement | 10 |
| testable-ownership | "Owned" reduces to predicates a control can assert against an oracle independent of the verb's self-report | 9 |
| safety-with-controls | Every guard is paired with a named control that can fire; a never-killable set is stated; no hand-reasoned-only guards | 9 |
| controls-rigor | Null and seeded arms named, red-first ordering, independent oracle, and ideally instrument-mutation checks (disable X ⇒ arm Y fails) | 9 |
| contract-completeness | Name (collision-aware), args, exit codes, stdout/stderr split per project convention, and defined behaviour for dead / not-ours / pid-1 targets | 8 |
| cannibalization-precision | Exact call sites by file:line, deletion (not wrapping) as the acceptance condition, all mandated exit paths covered | 8 |
| economy-honesty | Substance per byte; uncertainties stated as uncertainties; confident guesses and padding penalized | 7 |

## 2 Scores

| doc | metric | score 0–10 | justification (one line) |
|---|---|---|---|
| spec-A | mechanism-fidelity | 10 | §3's sid-catch-all (`sid == root-pid` survives reparenting) is the only design that reaps normal-exit escapees with no spawn change; nested-session residue (r3) and per-family gate stated |
| spec-A | testable-ownership | 9 | §1 OWN-1..4 each map to a named arm with an independent `ps` oracle and a self-report-disagreement-is-FAIL rule |
| spec-A | safety-with-controls | 9 | §4 G1–G8 each name their control; trust boundary of the dead-root case stated (G7), not hidden |
| spec-A | controls-rigor | 9 | §5 arms A–J include red-first integration arms I/J and a concurrency arm; lacks only C-style instrument mutations |
| spec-A | contract-completeness | 9 | §2 covers name collision with the live T364 `reap`, one-line parseable stdout, and all three edge targets with distinct exits |
| spec-A | cannibalization-precision | 9 | §6 deletes `:1505`, adds normal-exit and exception-path reaps, and argues (rather than forgets) keeping `:1432` |
| spec-A | economy-honesty | 9 | Dense throughout; §10 names pid-reuse and the unmeasured runner/console split as open rather than resolved |
| spec-B | mechanism-fidelity | 6 | §0's claim that no process-table walk can reach a dead-middle tree overlooks that sid survives reparenting, and the load-bearing `KERN_PROCARGS2`-readability claim is asserted, not measured |
| spec-B | testable-ownership | 8 | §1 O1–O5 are crisp assertable conditions with double-scan verification |
| spec-B | safety-with-controls | 8 | §5's leaked-token refusal (G2) is the sharpest single guard in the field; the uid-guard control gap is honestly declared unseedable |
| spec-B | controls-rigor | 7 | §8 names null/seeded arms and requires seeded-defect checks of the instruments, but arms are thinner and less parameterized than A/C |
| spec-B | contract-completeness | 8 | §2's `--plan` dry-run doubles as the controls' measurement instrument; exit codes cover foreign-uid anomaly loudly |
| spec-B | cannibalization-precision | 8 | §6 deletes `:1505`, routes the `:1432` cull line through the verb, and honestly substitutes a grep gate for the unverified normal-exit line number |
| spec-B | economy-honesty | 9 | Short, and §9 states the env-scrub residue, the argmax truncation, and a rejected lsof alternative as genuine unknowns |
| spec-C | mechanism-fidelity | 6 | Superb in-lane measurements (§3: env tokens dead on this host, `getsid` absent from Zig std) — but step 1 exits 3 on a dead anchor, so its normal-exit call (§6 C2) reaps nothing in exactly the recurring-leak shape, and this hole is never flagged |
| spec-C | testable-ownership | 9 | §1's O1/O2 pair (recompute closure over a fresh snapshot, sid keys included) is the strongest postcondition offered anywhere |
| spec-C | safety-with-controls | 10 | §4's G1–G10 including the mandatory SIGCONT rollback (G7) and the run-record protected set (G6) is the best safety section in the field, every guard armed |
| spec-C | controls-rigor | 10 | §5's instrument controls ("disable freeze ⇒ S2 must fail") plus the S8 differential oracle against the runner's existing walker make its arms evidence, not decoration |
| spec-C | contract-completeness | 9 | §2: read-only default, distinct refusal/non-convergence exits, fixture mode with a kill interlock (G9) |
| spec-C | cannibalization-precision | 10 | §6's C1–C6 table corrects the host-guard line to `:1435`, demotes the Python walker to a fixture, and mechanizes the deletion gate in the kanban acceptance |
| spec-C | economy-honesty | 8 | Long but nearly all substance; §9 names its own weakest parts (lstart parsing, G8 possibly invented scope) plainly |
| spec-D | mechanism-fidelity | 0 | §3 prescribes `killpg` and asserts "residue expected to be empty" and "no separate check required" — the exact claims the brief's measurement refutes |
| spec-D | testable-ownership | 1 | §1 is "robust guarantee… responsibility means cleanup" — no condition any control could assert |
| spec-D | safety-with-controls | 1 | §4: "protected by common sense" and "the verb will be careful" are the hand-reasoned guards the brief forbade |
| spec-D | controls-rigor | 1 | §5 is one happy-path test plus "edge cases added later in production" — no null, no seeded, no red-first |
| spec-D | contract-completeness | 2 | §2 has a name and two exit codes but "should probably refuse" and "no special handling needed" for pid 1 |
| spec-D | cannibalization-precision | 1 | §6's burn-in with both paths side by side and removal "in a follow-up pass" is precisely what requirement 6 disallows |
| spec-D | economy-honesty | 2 | Short but empty; zero citations, zero uncertainties, every guess delivered as fact |
| spec-E | mechanism-fidelity | 8 | §3 states the dead-root-at-call-time problem more sharply than anyone and solves it with `--from-snapshot`; deducted because children forked after the last poll-cadence snapshot escape and that window residue is never named |
| spec-E | testable-ownership | 9 | §1's closed predicate (absent-or-different-start-time) plus provable non-membership for the survivor control is judgment-free |
| spec-E | safety-with-controls | 8 | §4 pairs G1–G6 with arms, adds start-time provenance against pid reuse, and flags that `refuseLiveWrite` gives this verb zero protection — a real gap nobody else saw |
| spec-E | controls-rigor | 8 | §5's N1–S8 include the S3 dead-root arm and an end-to-end S8; no instrument-mutation checks |
| spec-E | contract-completeness | 9 | §2's two-verb contract is fully specified with skip reasons and a residue summary line, citing the binary's `processAlive` precedent |
| spec-E | cannibalization-precision | 8 | §6 covers both mandated sites with the poll-loop hook cited (`:1139`, `:1311`), grep acceptance; two verbs are one more moving part than the operator's constraint likes |
| spec-E | economy-honesty | 9 | §9 flags its own load-bearing reparenting-timing assumption as unmeasured and prescribes the two-line probe to verify it first |
| spec-F | mechanism-fidelity | 10 | Identical content to spec-A §3 (sid catch-all, nested-session residue, per-family gate); scored identically |
| spec-F | testable-ownership | 9 | Identical to spec-A §1 |
| spec-F | safety-with-controls | 9 | Identical to spec-A §4 |
| spec-F | controls-rigor | 9 | Identical to spec-A §5 |
| spec-F | contract-completeness | 9 | Identical to spec-A §2 |
| spec-F | cannibalization-precision | 9 | Identical to spec-A §6 |
| spec-F | economy-honesty | 9 | Identical to spec-A §9–10 |
| spec-G | mechanism-fidelity | 6 | §9 declares normal-exit reparented orphans structurally unreachable and re-scopes them to T548 — but sid-match enumeration (spec-A's shape) reaches them, so the impossibility claim is an analytical error, albeit an honestly argued one |
| spec-G | testable-ownership | 8 | §1's ownership-as-snapshot rule with an explicit reach limit is crisp and control-assertable |
| spec-G | safety-with-controls | 8 | §4's G1–G5 each carry a control, including the start-time pid-reuse re-verify (G4) with its flakiness honestly bounded in §10 |
| spec-G | controls-rigor | 8 | §5's C1–C8 are red-first with the C6 reach-limit arm consistent with its own claims |
| spec-G | contract-completeness | 8 | §2's table splits refusal (2) from partial (3) explicitly so a control can tell guard-fired from mechanism-broke, and names dead-target emptiness |
| spec-G | cannibalization-precision | 8 | §6 covers `:1505`/`:1538`, flags `:1432` as same-class, and makes deletion the acceptance — but its normal-exit call is knowingly hollow under its own design |
| spec-G | economy-honesty | 8 | Honest about its limits throughout; the opening line ("I have verified every citation") is grader-facing noise, not spec content |
| spec-H | mechanism-fidelity | 3 | §3 cites a nonexistent `tools/console.zig` and §4.4 refuses to signal reparented pids while "counting them owned" — declining to kill the exact measured leak shape |
| spec-H | testable-ownership | 3 | §1's "owned if enumerated before reparenting" makes the leak definitionally not-our-problem instead of testably dead |
| spec-H | safety-with-controls | 4 | §4's consent ledger and canary-mtime files are new gameable moving parts, though each guard does name a control arm |
| spec-H | controls-rigor | 4 | §5 names arms but inverts null/seeded semantics (its "null" canary arm expects a refusal), so pass criteria are muddled |
| spec-H | contract-completeness | 4 | §2 reuses the name `reap` — the live T364 verb — walking straight into the one-word-two-meanings trap the brief warned about |
| spec-H | cannibalization-precision | 4 | §6 gives approximate lines ("~1515") with code snippets the brief excluded, and its normal-exit fix finds nothing under its own ppid-only rule once children reparent |
| spec-H | economy-honesty | 4 | Compact and it does state open questions (§3, §7), but several confident claims are wrong on the page |

## 3 Verdicts

`spec-A: great — the sid-based dead-root catch-all is the one design that closes the normal-exit leak with no spawn change, and every guard, arm, and deletion is pinned to a checkable line; content-identical to spec-F.`
`spec-B: good — a genuinely novel token design with the field's best single guard, but its foundation (environment readability via sysctl) is asserted rather than measured and it wrongly dismisses the sid route it didn't need to.`
`spec-C: great — the richest measurements, safety section, and instrument-tested controls of the field, yet its verb exits 3 doing nothing on a dead anchor, silently no-op'ing on the recurring normal-exit leak it was asked to close.`
`spec-E: good — saw the dead-root-at-call-time problem more sharply than anyone and built the snapshot contract to fix it, but never names the fork window its poll cadence leaves open.`
`spec-F: great — byte-identical in substance to spec-A (formatting differs only); graded the same for the same reasons.`
`spec-G: good — precise, honest, and well-controlled, but it argued half of the normal-exit requirement out of scope on an impossibility claim the sid approach disproves.`
`spec-H: bad — has the right section skeleton and a real per-family check, but its ownership definition excuses the measured leak, it revives the reserved verb name, and its own rules make its normal-exit fix inert.`
`spec-D: terrible — prescribes the killpg the measurement already refuted, waves safety through on "common sense," and defers both testing and deletion to production, contradicting nearly every numbered requirement.`

## 4 Ranking

`A = F > C > E > B = G > H > D`

---

Two panel-relevant observations outside the per-document grades: spec-A and spec-F are the same document up to list-marker and separator formatting, which looks like a grader-consistency control — I scored them identically on content. And spec-D reads like a seeded-defect arm: it contradicts the brief's own measurements in nearly every section, so a grader ranking it anywhere but last should themselves be treated as suspect.
