## 1 Metrics

| metric (kebab-case) | definition (one line) | importance 0–10 |
|---|---|---|
| testable-ownership-definition | does §1 define "owned" as a condition an independent oracle can assert, not a vibe like "robust" | 10 |
| evidence-citation-rigor | are mechanism/design claims backed by checkable path:line citations or explicit in-session measurement, vs. asserted | 10 |
| safety-guard-controls | is every guard named, enumerated, and paired with a control that can be shown to fail if the guard is removed | 9 |
| per-family-generality | is the per-family residual check specified as owed/unmeasured (not assumed universal), and is the verb's contract family-agnostic | 8 |
| cannibalization-completeness | are all real exit-path call sites (ceiling, normal-exit, exception, host-guard) named with lines, and is "old code deleted" the acceptance gate | 8 |
| economy-vs-padding | is length proportional to checkable content, or does it restate the brief/pad without adding assertions | 6 |
| scoping-honesty | does the spec engage candidly with pass-1's scope (including pushing back on the brief) and list real uncertainties instead of overclaiming | 6 |

## 2 Scores

| doc | metric | score 0–10 | justification (one line) |
|---|---|---|---|
| spec-A | testable-ownership-definition | 9 | OWN-1..4 each mapped to an independent `ps`-diff oracle and a named arm (§1) |
| spec-A | evidence-citation-rigor | 9 | dense, consistent citations (`tools/runner:1161/1241/1432/1505/1538-1597`, `std/process.zig:397`, `docs/infra/managent/spec.md:48-57`) |
| spec-A | safety-guard-controls | 9 | G1–G8 each with a named arm; "a guard without a control is not a guard" (§4) |
| spec-A | per-family-generality | 9 | per-family probe command given, arms gated "final only for claude -p" until recorded (§3) |
| spec-A | cannibalization-completeness | 9 | covers §1505, normal-exit, and adds the exception path beyond the brief's two mandated sites (§6) |
| spec-A | economy-vs-padding | 8 | long but almost every line is a citation or a new assertion, not restatement |
| spec-A | scoping-honesty | 9 | §9 argues the runner-side/console-side split is unmeasured and flags `reap_residual` as first thing to cut |
| spec-B | testable-ownership-definition | 7 | O1–O5 are clear, but the algorithm's soundness leans on an unverified environment-readability assumption (§0/§4) |
| spec-B | evidence-citation-rigor | 4 | core mechanism ("`KERN_PROCARGS2`... readable for same-uid processes on macOS") has no path:line or in-session test, and is contradicted by spec-C/E's own measured `ps eww`/`ps -E` result showing no environment printed |
| spec-B | safety-guard-controls | 7 | G1–G4 each with a control, but G4 admits "control gap, stated" rather than closing it (§5) |
| spec-B | per-family-generality | 8 | per-family check given and correctly argued to not change the verb's design (§3) |
| spec-B | cannibalization-completeness | 8 | covers spawn-site env addition, ceiling kill, normal-exit, and flags the leak-causing host-guard line for the same swap (§6) |
| spec-B | economy-vs-padding | 8 | tight, well-organized, no filler |
| spec-B | scoping-honesty | 5 | never states the token-readability risk as an uncertainty despite it being the design's foundation (§9 lists other risks but not this one) |
| spec-C | testable-ownership-definition | 9 | O1/O2 with fresh-snapshot recomputation, plus an RSS corollary tied to the actual 9.1 GB incident (§1) |
| spec-C | evidence-citation-rigor | 10 | includes its own live measurement this session (specific pids/sid/pgid values, §3) and a negative result that falsifies an env-token design |
| spec-C | safety-guard-controls | 10 | G1–G10 including a protected-set guard for other in-progress workers (G6) and a mandatory freeze-rollback (G7), each with a control (§5) |
| spec-C | per-family-generality | 9 | per-family command given, records what the sid-edge means if a family doesn't escape (§3) |
| spec-C | cannibalization-completeness | 10 | §0 catches that the brief's own cannibalization list omits the host-guard line (`tools/runner:1435`) that actually caused the incident |
| spec-C | economy-vs-padding | 7 | the longest document in the set, but each section adds new checkable content rather than restating |
| spec-C | scoping-honesty | 10 | §0 argues the brief itself is "one site short" and that "every exit path" needs enumerating rather than asserted |
| spec-D | testable-ownership-definition | 1 | defines ownership as "responsibility... this is a robust guarantee" — the exact vocabulary the brief says a control must replace (§1) |
| spec-D | evidence-citation-rigor | 1 | no path:line citations anywhere; claims are asserted ("residue is expected to be empty," §3) |
| spec-D | safety-guard-controls | 0 | "protected by common sense" (§4); no named guards, no controls |
| spec-D | per-family-generality | 0 | asserts "other console families behave the same way... no separate check is required" (§3), contradicting the brief's own stated need to verify per family |
| spec-D | cannibalization-completeness | 1 | proposes running old and new paths "side by side" for a "burn-in period" before deleting old code — the opposite of the brief's "not done until deleted" (§6) |
| spec-D | economy-vs-padding | 2 | short, but the brevity reflects missing required content, not efficient substance |
| spec-D | scoping-honesty | 1 | no uncertainties section, no scope pushback, confident claims with nothing behind them |
| spec-E | testable-ownership-definition | 9 | closed predicate over two `ps` snapshots plus start-time, with an explicit non-membership control requirement (§1) |
| spec-E | evidence-citation-rigor | 10 | cites `tools/runner:1311/1538/1139/1180`, quotes an in-repo code comment (`main.zig:6180-6189`), and explicitly flags what it did *not* verify (§3, §9) |
| spec-E | safety-guard-controls | 9 | G1–G6 with controls, and flags that the existing `refuseLiveWrite` guard does nothing for this verb (§4) |
| spec-E | per-family-generality | 9 | names the exact check and states plainly it was not run this session, rather than assuming a result (§3, §9) |
| spec-E | cannibalization-completeness | 9 | the two-verb (`snapshot-tree`/`kill-tree`) design is the only one that structurally solves the "root already dead when the call happens" case rather than assuming it away (§3, §6) |
| spec-E | economy-vs-padding | 8 | long, but dense with citations and repeated "I did not verify X" discipline, not restatement |
| spec-E | scoping-honesty | 9 | argues explicitly against shrinking the spec by dropping `snapshot-tree` (§9) |
| spec-F | testable-ownership-definition | 9 | identical content to spec-A (`diff` shows only bullet-style/heading-rule differences) |
| spec-F | evidence-citation-rigor | 9 | identical to spec-A |
| spec-F | safety-guard-controls | 9 | identical to spec-A |
| spec-F | per-family-generality | 9 | identical to spec-A |
| spec-F | cannibalization-completeness | 9 | identical to spec-A |
| spec-F | economy-vs-padding | 8 | identical to spec-A |
| spec-F | scoping-honesty | 9 | identical to spec-A |
| spec-G | testable-ownership-definition | 7 | snapshot-then-signal rule is clear, but §1 concedes it structurally cannot reach a descendant that reparented before invocation — exactly the incident's core case — rather than closing it |
| spec-G | evidence-citation-rigor | 8 | strong on code citations (`main.zig:362,33-51,471,489`, `tools/runner:1505/1432`), weaker on auxiliary-doc citations (`00-brief-review.md`, `tooling-defects-2026-08-20.md`) not corroborated elsewhere in the set |
| spec-G | safety-guard-controls | 8 | G1–G5 map explicitly onto the brief's "three hand-reasoned guards," each with a control (§4) |
| spec-G | per-family-generality | 8 | check specified with gating logic (§3.2) |
| spec-G | cannibalization-completeness | 7 | names the same reach-limit gap in §9 but, unlike A/C/E, doesn't adopt sid-matching or a pre-death snapshot to close it — the fix is deferred to `T548` rather than attempted |
| spec-G | economy-vs-padding | 8 | well organized, minimal filler beyond a closing "Status of this document" footer |
| spec-G | scoping-honesty | 9 | §9 directly corrects a misreading of the brief's requirement 6 rather than silently complying |
| spec-H | testable-ownership-definition | 5 | ppid=1-based rule is stated but lacks the independent-oracle framing and fixpoint/closure rigor of its peers (§1) |
| spec-H | evidence-citation-rigor | 3 | cites `tools/runner.py` (all seven other specs cite `tools/runner`, no `.py`) and uses a hedged tilde line number ("Line ~1515," §6) |
| spec-H | safety-guard-controls | 4 | invents an unrequested consent-ledger file and canary/mtime "work marker" mechanism, neither grounded in a repo citation (§4) |
| spec-H | per-family-generality | 5 | check is present but also proposes per-harness consent-file naming, adding family-specific plumbing (§7) |
| spec-H | cannibalization-completeness | 5 | covers only two call sites; never names the host-guard line (`:1432`/`:1435`) that other specs identify as the one that actually culled 12 workers |
| spec-H | economy-vs-padding | 4 | the consent-ledger/canary machinery is scope creep against the operator's "fewer moving parts" constraint, not efficient content |
| spec-H | scoping-honesty | 3 | names its verb `managent-reap`/`managent reap`, reusing the exact word the brief warns is already overloaded by the kanban reaper (§2) |

## 3 Verdicts

spec-A: great — rigorous, fully-cited, and complete on cannibalization, but doesn't add an insight beyond its peers' best ideas.
spec-B: good — a coherent token-based design whose foundation (reading a same-uid process's environment) is asserted rather than measured, and a sibling spec's own experiment suggests it may not hold on this host.
spec-C: great — the most exhaustively measured document in the set; it runs its own corroborating measurement, falsifies a rival design, and catches a real omission in the brief's own cannibalization list.
spec-D: terrible — uses the exact vague vocabulary ("robust," "common sense") the brief tells authors to avoid, cites nothing, and asserts universality across console families with zero verification.
spec-E: great — its sharpest and most original point is that the root pid is often already dead by the time the verb can be called, which drives a genuinely different two-verb architecture and is paired with disciplined "not verified this session" flags.
spec-F: great — byte-for-byte the same substance as spec-A (a `diff` shows only cosmetic bullet/rule differences), graded identically on content.
spec-G: good — turns the brief's three hand-reasoned guards into controlled assertions, but its ownership definition explicitly can't reach descendants that reparented before invocation, which is precisely the case the 2026-08-20 incident measured, and it settles for naming that gap rather than closing it like its stronger peers.
spec-H: bad — reuses the very word ("reap") the brief calls out as already dangerously overloaded, bolts on unrequested consent-ledger and canary machinery that adds moving parts, and its citations are noticeably looser (a guessed file extension, an approximate line number) than the rest of the field.

## 4 Ranking

C > E > A = F > G > B > H > D
