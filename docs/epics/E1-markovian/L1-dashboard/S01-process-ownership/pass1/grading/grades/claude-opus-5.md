# Grading — pass-1 spec tournament (blind panel)

## 1 Metrics

| metric (kebab-case) | definition (one line) | importance 0–10 |
|---|---|---|
| testable-ownership-predicate | Is "owned" stated as a postcondition a control can assert — including the dead-root and post-snapshot-fork cases — rather than an adjective? | 10 |
| mechanism-fidelity | Does it build on the measured escape (session-leader escapees, reparenting to init, no cgroups) without contradicting or re-deriving it, and does it specify the per-family residual check? | 10 |
| citation-integrity | Is every factual claim checkable by a named path/line/command, with non-verified claims labelled as such and no invented files or guessed lines? | 9 |
| safety-specification | Guards, the never-killable set, refusal semantics, rollback — each paired with a named control, no hand-reasoned guard left unproven. | 9 |
| control-design | Null/seeded arms that can actually go red, plus controls on the instruments themselves and at least one end-to-end arm; tests before code. | 9 |
| cannibalization-completeness | Names the exact lines that stop doing this work, covers the normal-exit path, and gives a mechanized gate proving the old path is gone. | 8 |
| economy-and-honesty | Substance per byte (padding counts against), fewest moving parts, and uncertainties stated rather than smoothed. | 7 |

## 2 Scores

| doc | metric | score 0–10 | justification (one line) |
|---|---|---|---|
| spec-A | testable-ownership-predicate | 9 | OWN-1..4 (§1) each name an arm and require the verb's counters to agree with an independent `ps` oracle, disagreement = FAIL. |
| spec-A | mechanism-fidelity | 9 | §3 adds the nested-session topology (r3) and treats daemonized-descendant residue as measured not zero (r4); the mechanism paragraph is restated before being built on. |
| spec-A | citation-integrity | 9 | Dense checkable cites (`tools/runner:1161`→`:1241`, `:1252`, `:1353`, `:1505`, `:1538-1597`; `docs/infra/managent/spec.md:48-57`) and it corrects the brief's own account of where `setsid` happens (header, §3.1). |
| spec-A | safety-specification | 9 | G1–G8 (§4) each carry a named control, include the cross-uid EPERM case, and state the caller trust boundary rather than hiding it (G7). |
| spec-A | control-design | 8 | Ten arms A–J (§5) with red-first on D/I/J and fixed denominators, but no "delete the guard and the arm must go red" layer on the instruments themselves. |
| spec-A | cannibalization-completeness | 8 | §6 covers `:1505`, normal exit and the exception path and argues explicitly why `:1432` stays; no grep gate to mechanize the deletion. |
| spec-A | economy-and-honesty | 8 | Six real uncertainties incl. pid reuse (§10); mild padding in §3's restatement of the brief and §9's overlap with §6. |
| spec-B | testable-ownership-predicate | 9 | O1–O5 (§1) are all `ps`-assertable and O5 pins convergence under a fork race, which most specs leave implicit. |
| spec-B | mechanism-fidelity | 7 | §3's per-family check is correct and the token design is genuinely topology-blind, but §0's "no walk of the process table can find a tree whose middle has died" ignores sid-matching, which the runner's spawn-time `setsid` makes available. |
| spec-B | citation-integrity | 6 | The load-bearing claim that `KERN_PROCARGS2` yields another process's environ for same-uid targets (§0, §3) is asserted with no command or evidence, and is not listed among §9's uncertainties. |
| spec-B | safety-specification | 9 | The leaked-token refusal and 16-hex minimum (§5 G2) close the one path where this design kills the machine, and G4's uncontrollable foreign-uid arm is admitted rather than faked. |
| spec-B | control-design | 8 | N1–N2/S1–S5 (§8) include a residue-*measuring* arm (S5) and require each assert be shown capable of failing first; fewer arms than A/C/F. |
| spec-B | cannibalization-completeness | 9 | §6 routes all four sites including `tools/runner:1432` — the line that culled the 12 workers — and gates acceptance on a grep, not a reviewer. |
| spec-B | economy-and-honesty | 9 | Highest substance-per-byte of the eight; §9 rejects the `lsof` alternative with a reason and names the truncation limit of its own primitive. |
| spec-C | testable-ownership-predicate | 10 | O1/O2 (§1) separate roll-call from a recomputed closure over a *fresh* snapshot, which is the only postcondition here that catches a child forked after the snapshot; the RSS corollary ties it to the 9.1 GB observation. |
| spec-C | mechanism-fidelity | 10 | §3 corroborates with its own pids (12988/12986/8068), confirms `ps -o sess` prints 0, and records a measured *negative* (`ps eww` shows no environ) that constrains other lanes' designs. |
| spec-C | citation-integrity | 10 | Most checkable of the eight (`src/managent/main.zig:471`, `:6045`, `:8731`; `tools/runner:603`, `:641`, `:1435`, `:1502–1512`; `AGENTS.md:128–131`) and it states what it did *not* verify (§9.2, §9.3). |
| spec-C | safety-specification | 10 | G1–G10 (§4) add read-only default, atomic pre-flight, a protected set drawn from other `in_progress` run records, and the mandatory `SIGCONT` rollback that a refusal-after-freeze creates — no `--force` exists. |
| spec-C | control-design | 10 | N1–N3/S1–S8 (§5) plus four instrument mutations ("disable the freeze ⇒ S2 must fail"), a repeat-count race arm, and a differential oracle against the runner's existing walker. |
| spec-C | cannibalization-completeness | 10 | §0 and §6 find the site the brief omitted (`tools/runner:1435`, the host guard that culled 12 workers), enumerate four exit paths and say "three of four", and put the grep gate in the kanban acceptance command. |
| spec-C | economy-and-honesty | 7 | The longest document; mostly load-bearing, but G8/N3's detach exemption is scope it admits it may have invented (§9.5), §8 runs to list bloat, and §9.6's grading-confidence note is meta rather than spec. |
| spec-D | testable-ownership-predicate | 1 | §1 defines owned as "a robust guarantee" and "responsibility means cleanup" — verbatim the non-condition the brief said would not count. |
| spec-D | mechanism-fidelity | 0 | §3 claims one `killpg` on the session leader takes the whole tree, residue "expected to be empty", and that other families need no check "because POSIX process groups work the same everywhere" — three direct contradictions of the measurement it was handed. |
| spec-D | citation-integrity | 0 | Not one path or line anywhere in the document. |
| spec-D | safety-specification | 0 | §4 rests on "live work is protected by common sense" and "the verb will be careful about this", and §2 says pid 1 needs no special handling. |
| spec-D | control-design | 1 | §5 is one happy-path test, with edge cases to be "discovered in production, which is the most efficient way to find them". |
| spec-D | cannibalization-completeness | 1 | §6 proposes a side-by-side burn-in and removal "in a follow-up pass", inverting the brief's stated completion criterion. |
| spec-D | economy-and-honesty | 2 | Short, but short-and-wrong is not economy; it states no uncertainty at all and nominates its most incorrect section (§3) as its best contribution. |
| spec-E | testable-ownership-predicate | 9 | §1's predicate is closed over pid+start-time, makes non-membership provable for the survivor arm, and frames ownership as a property of a call rather than a standing state. |
| spec-E | mechanism-fidelity | 8 | The "root is already dead when the kill is called" reading (§3) is real and is honestly flagged as OS behaviour it did not reproduce (§9); but the last-poll snapshot's staleness window — a child spawned after the final snapshot — is never bounded. |
| spec-E | citation-integrity | 9 | Good cites (`tools/runner:1298-1311`, `:1311`, `:1139`, `:1538`; `src/managent/main.zig:6180-6189`, `:218-230`) with unmeasured claims explicitly labelled in §3 and §9. |
| spec-E | safety-specification | 9 | G1–G6 (§4) include the uid boundary, downward-only walk as a structural invariant, and the observation that `refuseLiveWrite` protects kanban state but nothing against killing a real pid. |
| spec-E | control-design | 8 | N1/N2 and S1–S8 (§5) with an end-to-end runner arm asserting zero system-wide residue; G3 is only "implied by S5" and there is no instrument-mutation layer. |
| spec-E | cannibalization-completeness | 7 | §6 handles `:1505` and the normal-exit path with the snapshot plumbing and a grep gate, but never mentions the host-guard single-pid kill at `:1432`. |
| spec-E | economy-and-honesty | 6 | Two verbs plus poll-loop snapshot plumbing is the most moving parts here, and the second verb's necessity rests on the one claim §9 admits is unverified; §4's prose runs discursive. |
| spec-G | testable-ownership-predicate | 7 | §1's snapshot rule and its "never reports a pid it did not observe" corollary are crisp, but the reach limit lets the normal-exit case exit 0 with survivors named-but-alive. |
| spec-G | mechanism-fidelity | 6 | §3 handles mid-walk reparenting correctly, yet §9 declares pre-invocation reparenting structurally unreachable — a limit of its own live-closure primitive, which sid-matching and pre-exit snapshots both defeat. |
| spec-G | citation-integrity | 9 | Checkable and specific, down to `libproc.h:95` and `src/managent/main.zig:33–51`, `:362`, `:471`, `:489`, with repo docs cited for the roadmap claims. |
| spec-G | safety-specification | 7 | G1–G5 (§4) are each paired with an arm and G4's start-time re-verify is good, but the never-killable set (§4) omits cross-uid processes entirely. |
| spec-G | control-design | 8 | C1–C8 (§5) are red-first and C6 pins the reach limit rather than hiding it; C8 checks the stdout/stderr split, which several lanes skip. |
| spec-G | cannibalization-completeness | 8 | §6 deletes `:1505`, calls the verb at `:1538` with bounded reach, and forces `:1432` to be an explicitly recorded decision if descoped. |
| spec-G | economy-and-honesty | 7 | Tight and well-organized with four honest uncertainties, docked for the "Writing the spec now" preamble that is not part of the deliverable and for §11 plus the status trailer restating §1 and §9. |
| spec-H | testable-ownership-predicate | 2 | §1 counts a survivor with `ppid = 1` as success, and §4 guard 4 makes that explicit — a descendant that reparents mid-enumeration is "not signaled" and still "counted as owned (exit 0)", which is the leak written down as intended behaviour. |
| spec-H | mechanism-fidelity | 3 | §3 invents `tools/console.zig` ("or claude harness runtime") and misreads the kill target as "the console's group" rather than the runner's own setsid'd child; the per-family check block is the one part that lands. |
| spec-H | citation-integrity | 2 | §6 names `tools/runner.py` and "Line ~1515", neither of which is the file or a given line, and the zig reference is approximated as "line ~397". |
| spec-H | safety-specification | 3 | §4 adds a consent ledger and a `.alive` mtime canary — two new state mechanisms against the no-proliferation constraint — and the canary would refuse to kill exactly the live runaway suite the pass exists to kill. |
| spec-H | control-design | 3 | §5 confuses the arms: `null-live-canary` expects a refusal and `seed-live-canary` is described as the same arm with the same expectation, so neither kind is doing its job. |
| spec-H | cannibalization-completeness | 5 | §6 does name two call sites, delete the old lines and sequence TERM-then-KILL, but against a fabricated path and a guessed line. |
| spec-H | economy-and-honesty | 4 | §2 names the verb `managent reap`, walking straight into the collision the brief warned about, and §7's "trying all known consent files in order of likelihood" is guesswork inside a kill tool; §7's open question is already answered in the brief. |

## 3 Verdicts

`spec-C: great — it measures its own corroboration and its own negative results, finds the call site the brief forgot (§0, tools/runner:1435), and is the only lane to notice that a refusal after a freeze can leave the fleet suspended; the detach exemption (§4 G8) is the one piece of scope it admits it may have invented.`

`spec-A: great — the sid-match catch-all plus the ten-arm control table is the most directly implementable package here, and it corrects the brief's own description of where setsid happens; content is identical to spec-F, so this is one contribution counted twice.`

`spec-F: great — same document as spec-A modulo bullet glyphs and rule characters; graded identically, and the duplication should be resolved before consolidation rather than read as two independent agreements.`

`spec-B: good — the most original mechanism and the tightest prose of the eight, but the entire design rests on one uncited claim about reading another process's environment, which another lane measured going the other way.`

`spec-E: good — the "root is already dead by the time you call" reading is a real finding, honestly labelled as unverified, but it buys a second verb and a stale-snapshot window it never bounds.`

`spec-G: average — disciplined and well-cited, then argues a required call site is impossible on the strength of its own primitive's limit, and never once mentions cross-uid processes in a tool that kills.`

`spec-H: bad — a guard that declines to signal reparented descendants and still exits 0 specifies the bug as the fix, and the cannibalization section cites a file that does not exist.`

`spec-D: terrible — contradicts the measurement it was handed on every load-bearing point, offers no citations, and calls a side-by-side burn-in cannibalization.`

## 4 Ranking

`C > A = F > B > E > G > H > D`
