# 1 Metrics

| metric (kebab-case) | definition (one line) | importance 0–10 |
|---|---|---|
| testability | Every "must" is expressible as a runnable control with an independent oracle and a fail-first/fail-red discipline | 9 |
| citation-accuracy | Factual claims cite checkable path:line or command; no fabricated, vague, or misread evidence | 9 |
| builds-on-mechanism | Correctly builds on the measured session-leader/reparent-to-init mechanism (incl. the dead-root case) rather than re-deriving or contradicting it | 10 |
| per-family-check | Specifies the one-command residual check per other console family and gates seeded controls on it | 8 |
| safety | Guards are concrete, each with a named null+seeded control; the never-killable set is explicit; no hand-reasoned "common sense" | 9 |
| cannibalization | Names the exact deleted call site(s), includes the normal-exit call, states a deletion gate, and respects the runner-death non-goal | 9 |
| economy | Substance not padding; few moving parts; no scope creep presented as a requirement | 7 |

# 2 Scores

| doc | metric | score 0–10 | justification (one line) |
|---|---|---|---|
| A | testability | 9 | §1 OWN-1..4 + §5 arms A–J each cross-checked against an independent `ps` oracle, test-first |
| A | citation-accuracy | 9 | Dense path:line; §3's two "verified sharpenings" correctly fix the brief's setsid ambiguity; §10 flags open items |
| A | builds-on-mechanism | 9 | §3 `sid == root-pid` catch-all exploits "reparenting preserves session" + spawn-time setsid, reaching a dead root with no spawn change |
| A | per-family-check | 9 | §3 gives the exact `ps`+`getsid` command and gates arms C/D/I/J per family |
| A | safety | 9 | §4 G1–G8 each with a named control; explicit never-killable set; trust boundary stated at G7 |
| A | cannibalization | 8 | §6 deletes :1505 and adds normal-exit + exception reap; leaves :1432 with an unverified "always reaches the ceiling path" claim |
| A | economy | 7 | Dense but long; §9/§10 repeat; the extra exception-path site is beyond the brief's two |
| B | testability | 8 | §1 O1–O5 + §8 N1/N2, S1–S5 with seeded-defect arms; assertions concrete |
| B | citation-accuracy | 7 | §0's "the only marker that survives reparenting is the token" is false — sid survives too; rest is well-cited |
| B | builds-on-mechanism | 6 | Token is family-agnostic and catches daemonizers, but §0 misreads sid/pgid and adds a spawn change + `KERN_PROCARGS2` env read |
| B | per-family-check | 7 | §3 names the check and correctly says the verb is topology-blind; thinner than A/C |
| B | safety | 8 | §5 G2 leaked-token refusal is excellent; G1 hard exclusions good; G4 uid control gap honestly stated |
| B | cannibalization | 8 | §6 O4 grep gate; names :1161/:1505/:1432 and normal-exit |
| B | economy | 7 | Concise, but token minting is a new moving part with a stated env-scrubbing hole |
| C | testability | 10 | §5 S1–S8 + "disable X ⇒ arm must fail" instrument controls; §1 O1/O2; S8 differential oracle vs the runner walker |
| C | citation-accuracy | 9 | §3 measured session topology + start-time; but §9.1 overgeneralizes a `ps`-based env read to all token designs; §9.6 grading-meta is padding |
| C | builds-on-mechanism | 9 | §3 freeze→fixpoint→kill→verify with ppid+pgid+sid edges and start-time filter recovers reparented trees |
| C | per-family-check | 9 | §3 exact command, records a/b/c/d, gates controls |
| C | safety | 10 | §4 G7 SIGCONT rollback is unique and load-bearing; G5 atomic pre-flight; G6 protected set; every guard has a control |
| C | cannibalization | 9 | §6 C1–C6 + mechanized grep gate; §0 catches the :1435 host-guard cull line that A descopes |
| C | economy | 6 | Longest; §9.6 meta grading note and G8 (possibly invented nested-dispatch scope) are padding |
| D | testability | 1 | §5 "testing will confirm"; no named arms, no oracle |
| D | citation-accuracy | 1 | Zero path:line citations anywhere |
| D | builds-on-mechanism | 1 | §3 claims "one killpg … takes the entire tree down" — backwards vs the measured session-leader leak |
| D | per-family-check | 1 | §3 "no separate check is required — the mechanism is universal" |
| D | safety | 2 | §4 "common sense" and "the verb will be careful"; no named controls |
| D | cannibalization | 2 | §6 proposes side-by-side burn-in then deletion "in a follow-up pass" — contradicts delete-not-wrap |
| D | economy | 4 | Short, but vacuity is not economy; incomplete, not lean |
| E | testability | 9 | §5 N1/N2/S1–S8 with start-time diffing; §3 reparent-timing probe as a null control |
| E | citation-accuracy | 8 | Heavy path:line; §3 reparenting-timing claim honestly flagged unmeasured; §9.4 atomicity open |
| E | builds-on-mechanism | 8 | §3 sharpest insight (root is not always live at kill time); but rejects sid, so ppid-only needs poll-loop snapshot plumbing |
| E | per-family-check | 8 | §3 names the command + `getsid`; honest that it has not run |
| E | safety | 8 | §4 G1–G6 table; the `refuseLiveWrite` observation is a good extra; G3 uid only "implied" |
| E | cannibalization | 8 | §6 two sites + grep gate; the normal-exit snapshot plumbing is slightly hand-wavy |
| E | economy | 8 | Focused, minimal meta-noise |
| F | testability | 9 | Substantively identical to spec-A |
| F | citation-accuracy | 9 | Substantively identical to spec-A |
| F | builds-on-mechanism | 9 | Substantively identical to spec-A |
| F | per-family-check | 9 | Substantively identical to spec-A |
| F | safety | 9 | Substantively identical to spec-A |
| F | cannibalization | 8 | Substantively identical to spec-A |
| F | economy | 7 | Substantively identical to spec-A |
| G | testability | 8 | §5 C1–C8 each with an assert; §1 snapshot rule is crisp; G4 pid-reuse via `proc_pidinfo` |
| G | citation-accuracy | 6 | Cites `docs/status/*` and `00-brief-review.md` not corroborated by the brief (which points to `LADDER.md`); "2828 MB" embellishes "2.8 GB"; leftover "Writing the spec now" line |
| G | builds-on-mechanism | 7 | §1 snapshot rule good, but "reach limit" calls reparented descendants universally unreachable, ignoring that sid survives reparenting; routes the normal-exit orphan to T548 |
| G | per-family-check | 7 | §3 names the command + `getsid` and asserts per family; thinner than A/C |
| G | safety | 8 | §4 G1–G5 + never-killable set; start-time pid-reuse guard good; but defers the normal-exit orphan |
| G | cannibalization | 8 | §6 names :1505/:1538/:1432 with a grep acceptance gate |
| G | economy | 7 | Concise, but the meta line and long scope verdict cost it |
| H | testability | 3 | §5 controls named but null/seeded pairs muddled (both canary arms expect exit 3); no seeded-defect arms |
| H | citation-accuracy | 3 | §3 "tools/console.zig" is vague/uncorroborated; low path:line density |
| H | builds-on-mechanism | 2 | §2 not-ours check via `getsid==recorded_sid` is backwards for session leaders; dead-root enumeration by `ppid==root_pid` misses reparent-to-init |
| H | per-family-check | 4 | §3 names the check but uses `ps -o sess`, which the brief says prints 0 |
| H | safety | 2 | §4 canary + consent ledger are hand-reasoned proliferating guards; the consent is cleaned before the normal-exit call that needs it (contradiction) |
| H | cannibalization | 4 | §6 names :1505 and two-phase normal exit and deletes killpg, but the consent-ledger contradiction undercuts it |
| H | economy | 3 | Proliferation: per-family consent files, `MANAGENT_CONSENT_FILE` env var, canary files — against "fewer moving parts" |

spec-A and spec-F are substantively the same document (same mechanism, guards, arms, and citations; formatting only differs); scored identically.

# 3 Verdicts

spec-A: great — the session-identity catch-all closes the dead-root leak with zero spawn change by reusing the sid already recorded at spawn.
spec-B: good — token membership is a genuinely different idea that catches daemonizers, but its §0 "only marker" premise misreads sid.
spec-C: great — the freeze/rollback loop and instrument controls are the most quarriable pieces in the set, bought with length and one overbroad claim.
spec-D: terrible — re-asserts the exact mechanism the brief measured as false (killpg) and declines the per-family check.
spec-E: great — "the root is not always live" is the sharpest single insight; two verbs are heavier than A's zero-spawn answer to the same gap.
spec-F: great — substantively identical to spec-A; same strengths, same small gaps.
spec-G: good — the snapshot-ownership rule is clean and honest, but it over-defers the normal-exit orphan to T548 and its citations are the least corroborated.
spec-H: bad — reuses the reserved name `reap` (the T364 kanban verb) and bolts on a consent ledger + canary that are exactly the hand-reasoned guards the brief said not to repeat.

# 4 Ranking

C > A = F > E > G > B > H > D
