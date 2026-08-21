<!-- T554 · grader lane qwen3.8:27b-mlx · pass-1-grading-round-1. Judging the 8 anonymized specs against 00-spec-tournament-brief.md. Repo-citation checks done: std/process.zig:397 (pgid=null) and bin/dispatch:301 (start_new_session=True) confirmed; tools/killpg now at runner:1554 (brief's :1505 stale); tools/console.zig (cited by H) absent. A and F are byte-identical apart from --- / *** and - / * syntax. -->

## 1 Metrics

| metric (kebab-case) | definition (one line) | importance 0–10 |
|---|---|---|
| mechanism-correctness | Builds correctly on the *measured* session-leader escape: group/session kills are structurally insufficient, so the design enumerates-and-signals; a design whose core mechanism is the very bug scores badly. | 9 |
| testability | "Owned" and every control are oracle-assertable conditions (a `ps` diff, a seed that goes red) rather than "robust/reliable," with null **and** seeded arms, ideally seed-defect instrument arms. | 8 |
| evidence-and-citation | Factual claims cite path+line and are checkable; uncertainties are stated; no citation points at a file that is not in the repo. | 8 |
| safety-quality | Each guard has a named control; the never-killable set is explicit; there are no "common-sense"/hand-reasoned guards; idempotent and no silent partial success. | 8 |
| per-family-residual | States the one per-family residual check that gates the seeded arms, and confines family knowledge to that check/caller, not to the verb. | 6 |
| cannibalization | Names the exact old call site(s) to delete (`killpg` + the reaps-nothing normal-exit + the host-guard) and makes "old path gone," not "verb exists," the acceptance. | 7 |
| economy | Fewer moving parts; length is substance not padding; no unasked-for mechanisms/verbs/flags; no tool proliferation. | 7 |

## 2 Scores

| doc | metric | score 0–10 | justification (one line) |
|---|---|---|---|
| spec-A | mechanism-correctness | 8 | §3 `sid==root-pid` catch-all + §3 r1 ("sid survives reparenting") handles the escape; no freeze phase, so fork-during-walk rides bounded re-scans plus an honestly-flagged, not-closed r4 residue. |
| spec-A | testability | 7 | §5 arms A–J cross-check the verb's stdout against a `ps` oracle and add one hand-traced end-to-end audit; solid null+seeded, but no dedicated seed-defect/instrument arm. |
| spec-A | evidence-and-citation | 7 | §3 sharpenings (setsid at `:1161`→`:1241`, run-record `:1252`, T364 walker as oracle) are in-repo and checkable; §10 states pid-reuse and other-family uncertainties. |
| spec-A | safety-quality | 8 | §4 G1–G8 (no-broadcast, ancestry, session-confinement, idempotence, no-silent-partial, no-elevation/EPERM-refused) each names a control in §5. |
| spec-A | per-family-residual | 7 | §3 names the per-family `ps`+`getsid` check, records (a)–(d), and gates arms C/D/I/J until it is recorded. |
| spec-A | cannibalization | 7 | §6 deletes `:1505`, adds the normal-exit + exception reaps and a grep-ish gate, but keeps host-guard `:1432` — partial on the host-guard site. |
| spec-A | economy | 7 | One verb, minimal flags (`--kill/--grace/--owner`), zero spawn change; §9 flags `reap_residual` as the first thing to cut if slimmed — clean. |
| spec-B | mechanism-correctness | 7 | §4 `SIGSTOP`-freeze bounds the reparent race, but the inherited-token key (§0) sits beside C's measured env-unreadability and §9.1–2 concede truncation + env-scrubbing residue it can only bound. |
| spec-B | testability | 8 | §8 "each assert must be shown capable of failing (seeded-defect)" is an instrument layer matching the QA-023 doctrine; N/S arms plus S5 measuring the design's own residue. |
| spec-B | evidence-and-citation | 7 | Cites `std/process.zig:397`, `:1161`, `:1432`/`:1505` and `KERN_PROCARGS2` truncation honestly; the core token bet is the least-certain of the set. |
| spec-B | safety-quality | 7 | §5 G1–G4 incl. G2 leaked-token refusal (closes the token-escaping-into-a-profile catastrophe); uid guard (G4) openly flagged as an unseedable control gap. |
| spec-B | per-family-residual | 7 | §3 per-family check; the token is topology-blind, so the verb is unaffected per family and only the seed changes. |
| spec-B | cannibalization | 7 | §6 deletes `:1505`, routes the normal-exit and host-guard `:1432` through the verb, gated by `grep` — strong coverage, second only to C. |
| spec-B | economy | 5 | The token needs a spawn-site env change plus a `KERN_PROCARGS2` read plus residue handling: more machinery than the no-spawn-change `sid` design it competes with. |
| spec-C | mechanism-correctness | 9 | §3 `sid` catch-all + §4 `SIGSTOP`-freeze fixpoint + nested-session topology r3; the most complete build on the measured mechanism, with a measured corroboration of the session-leader chain. |
| spec-C | testability | 9 | §5 N/S arms plus §5 "freeze/start-time/protected-set/rollback disabled ⇒ arm must fail" instrument controls plus O2 (recompute closure over a *fresh* snapshot) that catches a post-snapshot child. |
| spec-C | evidence-and-citation | 9 | Real line cites incl. a verified `std/process.zig:397`, a measured corroboration **and** a measured *negative* (env token unreadable via `ps`, §3) that refutes B's bet; unrun per-family stated. |
| spec-C | safety-quality | 9 | §4 G1–G10 incl. rollback-on-refusal (G7, `SIGCONT`), protected-set (G6), delegated-ownership exempt (G8), each with a control; "a guard without a control is not a guard." |
| spec-C | per-family-residual | 8 | §3 per-family check gates arms C/D/I/J and degrades to ppid live-coverage if a family lacks the `setsid`, quantifying the loss rather than hiding it. |
| spec-C | cannibalization | 9 | §6 C1–C6 table: `:1505`, normal-exit before token parse, the exception path, host-guard `:1435`, plus a grep-based mechanized deletion gate — most complete of the set. |
| spec-C | economy | 6 | Substance-dense (245 lines) and largely non-redundant, but G6 protected-set + G8 exempt add machinery and §7/§8 restate shared ideas; modest penalty only under the brief's "shorter-beats-long" clause. |
| spec-D | mechanism-correctness | 1 | §2/§3 kill the tree with one `killpg` on the group leader — the exact bug the brief measures — and assert an "expected residue is empty" that is false by the measurement. |
| spec-D | testability | 1 | §5: "a test spawns a process, kills it with the verb, and asserts it is gone"; no deep-tree escape arm, no live-survivor arm, "additional edge cases added later." |
| spec-D | evidence-and-citation | 1 | No path/line citations anywhere; "other families behave the same … no separate check" and "residue … expected to be empty" are asserted, not derived. |
| spec-D | safety-quality | 1 | §4 "protected by common sense," "will be careful," and pid-1 "no special handling is needed" — the hand-reasoned-guard antipattern the brief explicitly names; pid 1 is left unguarded. |
| spec-D | per-family-residual | 1 | §3 explicitly skips the required per-family residual check: "no separate check is required … universal across harnesses." |
| spec-D | cannibalization | 1 | §6 defers old-path deletion to "a follow-up pass once confident" after a burn-in — the direct violation of "a pass is not done when the verb exists." |
| spec-D | economy | 3 | Shortest by far, but short from omitting required work, not from elegance; fewest moving parts because most are dropped. |
| spec-E | mechanism-correctness | 9 | §3 "the root pid is not always live when `kill-tree` is called" (normal-exit reaches the kill *after* reparent) answered by a snapshot-while-alive two-verb contract (§2) that reaps the orphan; handles reparent by snapshot-before-signal. |
| spec-E | testability | 8 | §5 N1–S8 incl. N2 live-survivor and S3 the normal-exit case on a tight §1 predicate; lacks the seed-defect instrument layer C and G add. |
| spec-E | evidence-and-citation | 8 | Very tight line cites (`:1311`, `:1538`, `:1139/1180` poll cadence) and §9 explicitly flags reparenting-timing as standard-OS (unmeasured this session) plus the unrun per-family check. |
| spec-E | safety-quality | 8 | §4 G1–G6 incl. the `refuseLiveWrite` gap (an existing guard that cannot protect a process-killer) + N2 + no-silent-partial (exit 4 reports residue). |
| spec-E | per-family-residual | 7 | §3 check distinguishes "matches the console's session (a `killpg` superset)" from "differs (needs the tree-walk)"; not run this session, stated. |
| spec-E | cannibalization | 8 | §6 two call sites + a grep acceptance + S8 integration oracle; notes `os.setsid` becomes non-load-bearing — strong, one step short of C's host-guard coverage. |
| spec-E | economy | 7 | Two verbs is one extra part, justified by §3's root-not-alive; otherwise tight, no proliferation. |
| spec-F | mechanism-correctness | 8 | Byte-identical to A apart from rule/list syntax (verified by diff): same `sid` catch-all, no freeze — scored on identical merits to A. |
| spec-F | testability | 7 | Identical content to A (diff: only `---`/`***` and `-`/`*` differ); same null/seeded suite, no seed-defect arm — same as A. |
| spec-F | evidence-and-citation | 7 | Identical content to A; same in-repo sharpenings and §10 uncertainties — same as A. |
| spec-F | safety-quality | 8 | Identical content to A; §4 G1–G8 each backed by a §5 control — same as A. |
| spec-F | per-family-residual | 7 | Identical content to A; §3 per-family `ps`+`getsid` check gating arms C/D/I/J — same as A. |
| spec-F | cannibalization | 7 | Identical content to A; §6 `:1505` + normal-exit + exception, grep-ish, host-guard `:1432` omitted — same as A. |
| spec-F | economy | 7 | Identical content to A; one verb, minimal flags, zero spawn change, `reap_residual` flagged first-cut — same as A. |
| spec-G | mechanism-correctness | 8 | §1 "owned = the set it captured, not the live tree" + §3.1 libproc enumeration + snapshot-before-signal handles reparent; it defers the un-reapable normal-exit orphan to T548 (reaps less there than E but names the boundary honestly). |
| spec-G | testability | 9 | §5 C1–C8 with "null must pass today / seeded must go RED first," C6 as the load-bearing reach-limit arm, and §10 honestly bounding the flaky C4/G4 as a stress control. |
| spec-G | evidence-and-citation | 8 | Real line cites (`:1161`, `:1505`, `:1538`, `:1432`, `:397`, `proc_listchildpids`/`proc_pidinfo`); unrun per-family and the flaky pid-reuse control flagged as spec-time open. |
| spec-G | safety-quality | 8 | §4 G1–G5 (pid 0/1, ours=ancestor-walk, snapshot-only signal, pid-reuse via `proc_pidinfo`, no-silent-success) each with a control; the never-killable set is enforced at the signal step, not the read step. |
| spec-G | per-family-residual | 8 | §3.2 check conditions control C2 and states "the verb is unaffected either way," confining family knowledge to the seed. |
| spec-G | cannibalization | 8 | §6 `:1505` + `:1538`, flags host-guard `:1432` as the same escape class (in-scope unless a Plan call descopes it), grep acceptance; reach-limits the normal-exit promise honestly rather than faking it. |
| spec-G | economy | 8 | Two verbs, minimal flags, no extra machinery; reach-limit honesty in lieu of more code — the tightest of the "great" tier. |
| spec-H | mechanism-correctness | 4 | Tries session-id matching + a per-family check (a good direction) but §4's consent-ledger + canary machinery clouds the build and §3 mis-cites the harness. |
| spec-H | testability | 5 | Has null/seeded arms (§5) but they are coupled to the canary/consent mechanisms and stated as phrasings ("must all pass / must fail") rather than as a `ps`-diff oracle. |
| spec-H | evidence-and-citation | 3 | §3 cites `tools/console.zig`, which is **absent from the repo**, and §6 cites `tools/runner.py` (the file is extensionless); only `std/process.zig:~397` is right; per-family is "assumed but untested." |
| spec-H | safety-quality | 3 | §4 guards 2–3 (a consent ledger and a canary `.alive` mtime check) are new hand-reasoned mechanisms — the exact "common-sense guard" failure mode the brief names — and are uncontrolled beyond their own arms. |
| spec-H | per-family-residual | 4 | §3 states the per-family `ps`/`getsid` check (good) but entangles it with per-harness consent files. |
| spec-H | cannibalization | 5 | §6 names `:1505` + the normal-exit and makes "old `killpg` deleted" the acceptance (the right direction) but adds an unasked-for two-call TERM+KILL on normal-exit and cites the wrong filename. |
| spec-H | economy | 3 | Adds a consent ledger + per-harness consent files + a canary circuit-breaker — two to three unasked-for mechanisms: the "tool proliferation" the brief warns against. |

## 3 Verdicts

spec-C: great — the most instrumented and audit-proof spec in the panel: a measured corroboration of the escape chain plus a measured *refutation* of the token design, four-exit-path enumeration, and disable-X⇒arm-Y-fail controls; its only cost is length, and most of that is substance.
spec-G: great — the most epistemically honest: ownership is the *captured* set, not the *claimed* tree, which turns the un-reapable normal-exit orphan into a named T548 boundary instead of a false "killed 0" success.
spec-E: great — states the crux most sharply (the root is already dead when the normal-exit kill fires) and answers it with a snapshot-while-alive two-verb contract that actually reaps the orphan; tightly cited, a half-step behind C/G only on the seed-defect instrument layer.
spec-A: good — the session-identity catch-all is elegant and needs no spawn change, with a clean `ps`-oracle null/seeded suite; it has no freeze phase, so the fork-during-rescan race rides bounded re-scans plus an honestly-flagged, not-closed residue.
spec-F: good — byte-identical to A apart from rule and list syntax (confirmed by diff); the same merits and the same small residue, no more.
spec-B: good — a genuine alternative (SIGSTOP-freeze plus an inherited token) with a seed-defect instrument layer, but its core bet — reading the token out of the environment — sits beside C's measured negative and carries residue it can only bound, which costs it on correctness and economy against the cleaner A/F design.
spec-H: average — reaches most required content (a per-family check, a deletion-acceptance, named arms) but wraps it in a consent ledger and a canary circuit-breaker — the "common-sense guard" antipattern — and cites a `tools/console.zig` that is not in the repo.
spec-D: terrible — the negative control: a `killpg` design that asserts "one kill takes the whole tree down" (the measured bug), skips the required per-family residual check, guards by "common sense," and defers old-path deletion to a later pass.

## 4 Ranking

`C > G > E > A = F > B > H > D`
