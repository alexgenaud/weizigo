VERDICT: BLOCKERS (5)

Audit of `docs/epics/E1-markovian/L1-dashboard/T963/spec.md` by deepseek-v4-pro/T964,
2026-08-25, round 1 of the S10 §9 audit loop. I read the T963 bundle, S10 §1/§2.1/§2.2/§4,
and the three retired briefs (T816, T909, and S10's own), then checked the spec's facts
against the live store (`docs/infra/managent/tasks.json`, 587 rows) and the bundles. The
spec is substantively strong — all six decisions are addressed, no seventh verdict is
invented, `unverified` stays harness-emitted, and the close-stops-worker contract (option
3+4) is the right shape. But its own §0 "honest reading" contains three factual errors,
the missing-field refusal contradicts the bundle and S10, and the armed count is wrong
three different ways.

## BLOCKER 1 — §3.1 / §3.5 / §6.3: missing reporting field → "refused" contradicts the brief and S10

The T963 bundle's decision 4 is explicit: *"a refused close strands, so a missing field
cannot simply refuse."* S10 §1.2 measured refusal=stranding twice (T818 orphaned two
hours; sixteen tasks read in-flight while zero were alive). The spec nevertheless decides
that each missing field (`delivered`, `confidence`, `deferred`, `followups`,
`retrospective`) is **refused** (§3.1 table "what missing does", §6.3 "A missing required
field refuses the close").

§3.5's reconciliation — "refusal with an available path is not stranding … it is
`in_progress` with a clear instruction" — is the exact argument S10 §1.2 already falsified:
the available path (re-close) existed for T818 too, and it still stranded, because
`in_progress` is indistinguishable from a live worker regardless of how clear the
instruction is. The spec is relabelling refusal, not reconciling it.

Worse, the spec is internally inconsistent about the same fact: §6.4 gives the auto-close
door a *different* treatment — a missing field there is **not** refused, it is "record[ed]
… as not-provided" and the close lands with the computed verdict. So the worker door
refuses a missing `retrospective` while the auto-close door (the very door that produced
T943) closes with it marked absent. A worker whose `done` is refused will simply exit and
be auto-closed with the gap recorded — the refusal achieves one round-trip and nothing
else.

**Change:** decide a missing field's cost that is not a refusal (the obvious one is §6.4's
own "record not-provided, compute the verdict anyway, and mark the reporting gap on the
row"), and make §3.1/§6.3 say that. If the author genuinely wants refusal despite the
brief, that is a divergence from the ratified direction and must be named as such and
ratified — it cannot be smuggled in as "reconciliation."

## BLOCKER 2 — §0 / §5.2: the bundle's measured pass rate is misstated (92% vs 96%)

The T963 bundle's measured baseline is *"521 closes: 275 `pass`, 227 `pass-with-findings`,
12 `blocked`, 7 `abandoned`"* — i.e. **502 of 521 = 96%**, not 92%. The spec's §0 table
puts **"444 (92% of closes)"** in the "bundle/S10 number" column and §5.2 calls the Epoch 1
figure **"92% (bundle time)"**. 444/92% is S10's 2026-08-24 measurement, not the bundle's.
The bundle itself never says 444 or 92% (its only "92%" is a rhetorical *"if the honest
close rate turns out to be far below 92%"*).

This is load-bearing: §5.2 is defining the Epoch 1 boundary for S10-VERDICT-4, and it is
anchoring that boundary to a number the bundle did not measure. The whole row exists
because numbers were believed without checking; the spec is now mis-citing the bundle's
number in its own baseline table.

**Change:** §0's bundle column must read 502 of 521 (96%); §5.2's Epoch 1 figure must be
96% (bundle) / 96% (live), or the 92% must be explicitly attributed to "S10 era
(2026-08-24)" rather than "bundle time."

## BLOCKER 3 — §0: the fail-found exemplar is wrong (T948 is not fail-found)

The spec says `fail-found` all time is "1 (`T948`)". The single `fail-found` row in the
store is **T959** (the T953 spec audit, closed 2026-08-25T13:55:34Z, *before* this spec was
written). T948 is `pass-with-findings`. The count "1" happens to be right; the row cited
as the exemplar is wrong, and it is the second wrong fact in the section whose whole
premise is "numbers were believed without checking."

**Change:** cite T959 as the fail-found row (or drop the exemplar and keep the count).

## BLOCKER 4 — §0 / §6.4 / §7 / §10.6: T940 was not auto-closed

The spec states *"A second row, T940 … was auto-closed the same way — exit 0, deliverables
present, acceptance command never run."* That is false. T940's row has `note: null`, a
real worker `verdict_note` ("Removed DEEPSEEK_API_KEY env guard; keys resolve in pi") and a
real `impression` ("Clean removal of obsolete env guards; test-first red->green…") — it was
closed by its worker, not by `tools/runner`. The auto-close marker ("tools/runner
auto-close: worker exited 0 without closing…") appears on T943 and T786, not T940. The
claim is repeated as fact in §6.4, §7, §10.6, and SMOKE-T963-3/4.

T943 alone fully carries the auto-close-door argument, so nothing downstream changes — but
a spec whose §0 is titled "the honest reading" cannot assert a false second data point as
its evidence base.

**Change:** delete T940 from §0, §6.4, §7, §10.6, and SMOKE-T963-3/4, or re-verify it and
state what T940 actually demonstrates (a normal worker close whose acceptance was also
never run at close time — a property of the old contract, not of the auto-close door).

## BLOCKER 5 — §9.2 / §9.4 / §11: the armed count is wrong and internally inconsistent

The T963 bundle acceptance #2 requires "the armed count is stated and correct." It is not.
Counted from S10's own tables and this spec's tables:

- S10 cited: **21** unit arms (A1–A21) + **4** smoke (SMOKE-1..4) = **25**.
- This spec new: **8** (TC-1..TC-8) + **3** (TW-1..TW-3) + **5** (SMOKE-T963-1..5) = **16**.
- Correct total = **41**.

The spec states three mutually inconsistent numbers:
- §9.4: "S10's 21 + S10's 4 + 8 (TC) + 5 (SMOKE-T963) = **38 total, of which 13 are new**" — it silently **omits TW-1..TW-3** from both totals (38 should be 41; 13 new should be 16).
- §11 total row: "**32 cited + 16 new = 38**" — 32+16 is 48, not 38; "32 cited" is wrong (S10 has 25); and the ledger table itself lists only 16 cited rows (3 ACCEPT + 3 CLOSE + 4 VERDICT + 2 CONCERN + 4 SMOKE), **omitting S10-ATTEMPT (A11–A15) and S10-STORE (A16–A19)** entirely.
- §11 note: "S10's 32 + this spec's 16 … 38 of 38 normative ids."

The *coverage* claim is fine — I found no unarmed new normative id in §3–§6 (the five
fields are TC-1..5, grandfathering is TC-7, blocked-no-concern is TC-8, close-stops-worker
is TW-1..3, epochs are SMOKE-T963-5, auto-close is SMOKE-T963-3/4; §3.2–§3.4 ride the cited
S10 arms A1–A10). Only the count is broken.

**Change:** make one number — 25 cited + 16 new = 41 — and state it once, with the ledger
table listing all of S10's arms including S10-ATTEMPT and S10-STORE (or citing S10 §6's
ledger instead of re-deriving a partial one).

## RED FLAG — §4.5: decision 3's "how" is deferred without naming the ruling needed

The bundle's decision 3 is "whether the close stops the worker, **and how** — signal, wait,
escalate; and what happens when it cannot." §4.5 decides the contract (holds survive until
runner exit) but defers "the exact mechanism for detecting runner exit — reaper, liveness
poll, SIGCHLD handler, or the close path checking PID" to the implementation row, without
stating what ruling is needed and from whom. Bundle acceptance #3 says decisions are
decided, not deferred; where a decision is genuinely an implementation detail, say so
explicitly and say *why* the contract is sufficient. As written, an implementer has a
mandatory open question (which mechanism?) and the spec has not said whose call it is.

## RED FLAG — §7: the blocked/abandoned concern requirement has no available path today

§3.1/§6.1 and TC-8 require a concern record on `blocked`/`abandoned`, but §7 itself records
that the concern channel is unimplemented (`managent concern` absent, `concerns.jsonl`
absent). As written, every `blocked`/`abandoned` close is refused for a missing concern with
**no mechanism to satisfy it** — a stranding path, exactly the failure the direction exists
to avoid. §7 flags this but does not decide the interim mechanism ("either land T490's
channel … or specify an interim mechanism"), which is a deferral of a decision the spec is
on the hook for. Name the interim decision (or gate TC-8 behind the T490 landing).

## RED FLAG — §6.4 / §6.1: reporting-field encoding is never specified

The spec names five fields but never specifies their encoding — CLI flags, a JSON payload,
field names, or whether they are one `--report` blob. S10 §2.1 was careful to say "the
exact encoding is a design-phase decision" for acceptance; T963 makes no parallel statement
for the reporting fields, so an implementer must ask. §6.4's "prompt for them (if the
worker is still reachable)" is similarly unspecified (what mechanism prompts a dead
worker's runner?).

## NOTE — §9.1 reliance table is a subset and does not say so

§9.1 lists 11 of S10's 21 arms (A1–A10, A20). It is presented as "S10 id → this spec's
reliance," which is a legitimate subset, but it sits next to "S10 §4 specifies 21 arms"
and is easy to misread as the full set. One sentence — "the remaining S10 arms (A11–A19,
A21) are out of this spec's scope and still bind the implementation row" — removes the
ambiguity.

## NOTE — §0's "red on a clean host" slightly overstates the T943 amendment

T943's amendment says the gate is red because a Claude console's `caffeinate` is flagged
("a legitimate, unavoidable condition"), not that it is red on a pristine host. The
substantive point (T943 closed `pass` over a failing acceptance) stands; the "clean host"
phrasing is a minor overreach.

---

**What I checked that came out clean:** no seventh verdict value (§8 explicit, §2's
six-outcome table correct); `unverified` is harness-emitted and `--status unverified`
refused (§3.4, A7); acceptance comes from the bundle only and the 33/40 dispatchable rows
without acceptance are blocked not grandfathered (§3.2, consistent with the live store's 30
of 37 without acceptance at read time); the concern-channel claim (`managent concern` has
zero code occurrences — the only hit is a comment; `concerns.jsonl` absent) is accurate;
and the T786 timeline (done 2026-08-24T21:24:02Z, commit `75c307a` 8m48s later) checks out.
