# T982 — Race B resolution (sonnet), arm `B-failtrans/sonnet`

Resolving the 5 blockers from `untracked/L1/T963/spec/audit-1.md` against
`docs/epics/E1-markovian/L1-dashboard/T963/spec.md`, checking every cited fact against the
repository myself before accepting the auditor's claim. All 5 blockers are addressed; all 3 red
flags are addressed. I did not re-check the two NOTE items (§9.1 subset framing, the "clean host"
overstatement) — they are minor and the auditor's own text is self-evidently correct on inspection;
my wall went to the 5 blockers and 3 red flags as instructed.

**Verdict on all 5 blockers: the auditor is right on every one.** I re-derived each from primary
sources (the T963 bundle text, `docs/infra/managent/archive.json`/`tasks.json`, and arithmetic on
the spec's own tables), not from trusting the audit. Evidence for each is below, before the fix.

---

## Blocker 1 — §3.1/§3.5/§6.3: missing reporting field → "refused" contradicts the brief and S10

**Checked myself:** `untracked/T963-close-contract-spec.md` (the actual bundle, not a paraphrase),
decision 4:

> "Decide which are required, which are optional, and what a missing one costs — **a refused close
> strands, so a missing field cannot simply refuse.**"

That is an explicit, unambiguous instruction, and the spec's §3.1 table ("what missing does" →
"refused" for all five fields) and §6.3 ("A missing required field **refuses** the close") do
exactly the forbidden thing. The auditor is right, and the internal-inconsistency point also
checks out: §6.4 already gives the auto-close door the non-refusing treatment ("record… as
not-provided," close lands, verdict computed) — the spec contradicts itself across two doors for
the same fact.

**Fix — extend §6.4's own treatment to both close doors.** A missing reporting field is not a gate
on whether the close lands; it is a quality signal recorded on the row. This preserves S10's
"always close, never strand" without inventing new machinery — it reuses the auto-close door's
already-decided shape.

### Replacement — §3.1 table, "what missing does" column

Replace every "refused" cell in the five-row table with:

> **recorded as `not-provided`; the close proceeds; the verdict is computed from acceptance as
> normal; the row carries a visible `reporting_gap` marker (which field, since when) rendered on
> `status`, `show`, `resume`, and `audit` — never silent, never blocking.**

### Replacement — §3.5, "The distinction, decided" table

Delete the row:

> "Reporting field missing (...) | this spec §3.1 | **refused** — names the missing field..."

Replace with:

> "Reporting field missing (`delivered`, `confidence`, `deferred`, `followups`, `retrospective`) |
> this spec §3.1 | **not refused** — recorded as `not-provided`, verdict computed and stands, the
> row carries a `reporting_gap` marker. This is the honest-but-incomplete close: the verdict is
> real, the reporting contract has a hole, and the hole is visible rather than silent."

And delete the "edge case" paragraph that depends on refusal-of-missing-fields (§3.5's last
paragraph) — with fields no longer a gate, there is no refusal→closed-`unverified` chain to
describe. Replace with one sentence:

> "A missing reporting field and an uncheckable acceptance condition are independent facts about
> the same close: the first is recorded as a gap, the second determines the verdict
> (`unverified`). Neither blocks the other from landing."

### Replacement — §6.3 heading and body

Retitle "What a missing field costs — decided" and replace the body with:

> "A missing required field does not refuse the close (the bundle's decision 4: refusal strands).
> It is recorded as `not-provided` and the row carries a visible `reporting_gap` marker — loud on
> every read surface, never a silent default to a clean close. The cost of a missing field is
> reputational and visible, not procedural: a row with open `reporting_gap`s is a legible debt, the
> same shape as T816's measured hole (21% no verdict note, 71% no impression) made a queryable
> count instead of an invisible one."

**Also update:** §6.1's five numbered items each end "**Missing → refused.**" — change all five to
"**Missing → recorded as `reporting_gap`, verdict unaffected.**" And TC-1..TC-5 in §9.2 must change
their "must (red-then-green)" column from "refused, names X as missing; store unmutated" to
"**close succeeds**, verdict computed normally, row carries `reporting_gap: [X]`; a positive control
(TC-6) still proves the fields are collectible when supplied." This is a real change to the arms,
not just prose — the auditor's fix, if adopted only in prose, would leave the arms testing the
wrong behavior.

---

## Blocker 2 — §0/§5.2: the measured pass rate is misstated (92% vs 96%)

**Checked myself.** The bundle (`untracked/T963-close-contract-spec.md:52-53`) states its own
measured baseline in its own words:

> "521 closes: **275 `pass`, 227 `pass-with-findings`, 12 `blocked`, 7 `abandoned`**. `fail-found`:
> zero."

275 + 227 = **502**. 502 / 521 = **96.35%**, not 92%. Separately, the S10 spec
(`docs/epics/E1-markovian/L1-dashboard/S10-failure-transparency/spec.md:24`) states its own,
different, earlier baseline: "444 (92% of all closes)". These are two different measurements at
two different times, and the T963 spec's §0 table puts "444 (92% of closes)" under a column header
that says "bundle/S10 number" — collapsing two distinct numbers into one mislabeled cell. The
auditor is right: the bundle never says 444 or 92% as a fact (its only "92%" is the rhetorical "if
the honest close rate turns out to be far below 92%" in the landmark line).

I also re-ran the live count myself rather than trusting either document's live-store column:

```
$ python3 -c "... count status==done, Counter(verdict) over archive.json + tasks.json ..."
total closed: 659
Counter({'pass': 363, 'pass-with-findings': 249, 'abandoned': 30, 'blocked': 13, 'fail-found': 4})
pass+pwf: 612  pct: 92.9
```

This is a **third** number (92.9%, 659 closes), later than both the bundle's 521-close snapshot
and the spec's own "live store (2026-08-25)" column (515/535 = 96%) — the store keeps growing
intraday, which is exactly why §5.2's epoch discipline matters: any live count is a snapshot, not a
constant, and must carry its own read timestamp.

### Replacement — §0 table

Replace the "bundle/S10 number" column header with two separate columns, and correct the numbers:

| fact | bundle number (521 closes, 2026-08-25 bundle time) | S10 number (2026-08-24 measurement) | live store (read now) |
|---|---|---|---|
| closed `pass` / `pass-with-findings` | 502 (96% of 521) | 444 (92% of all closes, an earlier and smaller store) | 612 of 659 closed (93%), read at close-resolution time — **this number moves; timestamp it on every citation** |
| `fail-found`, all time | 0 (521-close snapshot) | 4 in 573 tasks (S10's count, a different denominator) | 4 (T332, T959, T258, T259) |

### Replacement — §5.2, Epoch 1 bullet

Replace "**This is the 92% (bundle time) / 96% (live) figure.**" with:

> "**This is the 96% (bundle time, 502/521) figure.** The 92%/444 figure belongs to S10's earlier
> 2026-08-24 measurement, on a smaller store, and must not be relabeled as the bundle's own number.
> Both are Epoch 1 (pre-close-contract) measurements and neither is comparable to a live count read
> after this spec was written, since the store's total keeps growing intraday — every citation of a
> 'live' pass-rate must carry the read timestamp, not just the word 'live'."

---

## Blocker 3 — §0: the `fail-found` exemplar is wrong (T948 is not `fail-found`)

**Checked myself against the live store**, not the audit's assertion:

```
T948: verdict = 'pass-with-findings' (tasks.json; closed 2026-08-25T14:42:12Z)
T959: verdict = 'fail-found' (archive.json; closed 2026-08-25T13:55:34Z, bundle
      untracked/T959-audit-t953-spec.md, "audit the T953 spec")
```

The auditor's replacement fact is correct on both counts: T948 is `pass-with-findings`, and the
single most-recent `fail-found` row at spec-writing time is T959, not T948. (There are in fact 4
`fail-found` rows all-time in the combined archive+live store — T332, T959, T258, T259 — which is
consistent with S10's own "4 in 573 tasks" figure cited above and inconsistent with the bundle's
521-close snapshot claiming zero; that snapshot evidently excludes the three older ones outside its
521-window. This is a scope note, not a new blocker — the T963 spec only needs one correct
exemplar for its narrower "1 in the current store" framing.)

### Replacement — §0 body text

Replace:

> "`fail-found`, all time | 0 in the store at bundle time | 1 (`T948`)"

with:

> "`fail-found`, all time | 0 in the store at bundle time (521-close snapshot) | 1 within the
> bundle's snapshot window (**T959**, closed 2026-08-25T13:55:34Z, the T953-spec audit) — 4 total
> across the full archive+live store (T332, T258, T259, T959), consistent with S10's independently
> measured 4-in-573 figure"

---

## Blocker 4 — §0/§6.4/§7/§10.6: T940 was not auto-closed

**Checked myself against `docs/infra/managent/archive.json`** (not the spec's assertion, not the
audit's assertion — the raw row):

```
T940.verdict_note = "Removed DEEPSEEK_API_KEY env guard; keys resolve in pi"
T940.impression   = "Clean removal of obsolete env guards; test-first red->green on all
                      providers without env keys"

T943.verdict_note = "tools/runner auto-close: worker exited 0 without closing; all declared
                      deliverables present; the worker reported no status and no impression —
                      this close is automatic, on process evidence (exit 0 + deliverables
                      present), not a worker-reported verdict (T862 §4)."
T943.impression   = null
T943.impression_waiver = "tools/runner auto-close on exit 0 — no model ran to narrate an
                           impression; the worker reported nothing (T862 §4)."
```

The auto-close marker text is present verbatim on T943 and absent from T940. T940 has a real
worker-authored `verdict_note` and `impression`, which is the opposite of an auto-close signature.
The spec's claim that T940 "was auto-closed the same way" is false, exactly as the audit states.

### Replacement — §0 body text

Delete the T940 paragraph entirely:

> ~~"A second row, **T940** (closed 2026-08-25T10:20:04Z, `acceptance:
> sh tools/regression-no-key-env-guard.sh`, verdict `pass`), was auto-closed the same way — exit 0,
> deliverables present, acceptance command never run."~~

Replace with (stating what T940 actually demonstrates, since it is real evidence of a different,
narrower gap):

> "T940 (closed 2026-08-25T10:20:04Z, `acceptance: sh tools/regression-no-key-env-guard.sh`,
> verdict `pass`) was closed by its own worker, with a real `verdict_note` and `impression` — it is
> **not** an auto-close instance. It is nonetheless evidence of a real, narrower gap: its worker
> asserted `pass` and there is no record the acceptance command was actually run at close time, a
> property of the *old, worker-asserted contract* (any worker-closed row before this spec's
> computed-close lands), not of the auto-close door specifically. T943 alone carries the auto-close
> argument; T940 illustrates the separate, broader baseline problem (§0's 92%/96%/502-of-521 self-
> report figures) that this whole spec exists to end."

### Replacement — §6.4, §7, §10.6, SMOKE-T963-3/4

Everywhere these sections cite "T943 and T940" as the two auto-close incidents, change to "T943"
singular. Specifically:

- §6.4 opening sentence: "T943 and T940 were auto-closed by `tools/runner`…" → "**T943** was
  auto-closed by `tools/runner`…"
- §7's sequencing note ("T943 and T940 are live evidence that the auto-close door…") →
  "**T943** is live evidence that the auto-close door…"
- §10.6 opening: "T943 and T940 are the evidence that exemption fails." → "**T943** is the evidence
  that exemption fails; T940 is separate evidence of the broader worker-asserted-pass gap this spec
  addresses through the reporting contract and computed close generally."
- SMOKE-T963-3/4's "would have caught" column cites "T943/T940" — change to "T943" for SMOKE-T963-3
  (the auto-close-refuses-on-failing-acceptance scenario, which is specifically T943's shape) and
  leave SMOKE-T963-4 citing only the auto-close path generically (it does not need a second
  exemplar to be a valid smoke test).

---

## Blocker 5 — §9.2/§9.4/§11: the armed count is wrong and internally inconsistent

**Checked myself by recounting from the spec's own tables**, not by trusting either the spec's
number or the audit's number — both are independently checkable arithmetic:

- S10 §6's own arm ledger (`S10-failure-transparency/spec.md:369-380`, cited verbatim, not
  re-derived): S10-ACCEPT-(3) + S10-CLOSE-(3) + S10-VERDICT-(4) + S10-ATTEMPT-(5) + S10-STORE-(4) +
  S10-CONCERN-(2) = **21** unit arms, + S10-SMOKE-(4) = **25** total. S10's own bookend line
  confirms: "Armed count: 21 of 21 normative ids… (A1–A21)" plus 4 smoke = 25.
- T963's new arms, counted from its own §9.2/§9.3/§9.4 tables: TC-1..TC-8 = **8**, TW-1..TW-3 =
  **3**, SMOKE-T963-1..5 = **5**. New total = **16**.
- **Correct grand total: 25 + 16 = 41.**

The spec's own numbers are self-contradictory in two places, confirmed by direct arithmetic (not
opinion):

- §9.4: "38 total arms, of which 13 are new" — 25 + 13 = 38 only if TW-1..3 (3 arms) are dropped
  from both the cited-25 and the new-count; 13 + 3 = 16 matches my recount, so the omission is
  exactly TW-1..3, confirming the auditor's diagnosis.
- §11: "32 cited + 16 new = **38**" is not even correct addition (32 + 16 = 48, not 38), and "32
  cited" doesn't match S10's own 25, and the ledger table beneath it lists only 3+3+4+2+4 = 16 cited
  rows, omitting S10-ATTEMPT- (5) and S10-STORE- (4) — 16 + 9 = 25, again matching my recount.

The auditor's arithmetic is correct throughout. The *coverage* claim (every new normative id in
§3–§6 has ≥1 arm) is unaffected — I spot-checked it too: the five reporting fields → TC-1..5,
grandfathering → TC-7, blocked-no-concern → TC-8, close-stops-worker → TW-1..3, epoch labeling →
SMOKE-T963-5, auto-close → SMOKE-T963-3/4. Only the stated *count* is broken, not the coverage.

### Replacement — §9.4 closing line

Replace:

> "**Armed count:** S10's 21 arms (A1–A21, cited) + S10's 4 smoke tests (SMOKE-1..4, cited) + this
> spec's 8 new arms (TC-1..TC-8) + this spec's 5 new smoke tests (SMOKE-T963-1..5) = **38 total
> arms, of which 13 are new to this spec.**"

with:

> "**Armed count:** S10's 21 unit arms (A1–A21) + S10's 4 smoke tests (SMOKE-1..4) — 25 cited,
> unchanged — plus this spec's 8 new unit arms (TC-1..TC-8) + 3 new unit arms (TW-1..TW-3) + 5 new
> smoke tests (SMOKE-T963-1..5) — **16 new. Grand total: 41, of which 16 are new to this spec.**"

### Replacement — §11 arm ledger

Add the two missing cited rows and fix the total row:

| id prefix | what it covers | arms | source |
|---|---|---|---|
| `S10-ACCEPT-` | acceptance schema/gate/migration | 3 (A1–A3) | S10 §4 — cited |
| `S10-CLOSE-` | computed close — run/compute/one-door | 3 (A4–A6) | S10 §4 — cited |
| `S10-VERDICT-` | unverified class | 4 (A7–A10) | S10 §4 — cited |
| `S10-ATTEMPT-` | kill/attempt history | 5 (A11–A15) | S10 §4 — cited |
| `S10-STORE-` | store-loss detection | 4 (A16–A19) | S10 §4 — cited |
| `S10-CONCERN-` | concern channel (blocked/abandoned) | 2 (A20–A21) | S10 §4 — cited |
| `S10-SMOKE-` | end-to-end smoke | 4 (SMOKE-1..4) | S10 §5 — cited |
| `TC-` | T816 close-contract consolidation — reporting fields | 8 (TC-1..TC-8) | this spec §9.2 — new |
| `TW-` | T909 close-stops-worker | 3 (TW-1..TW-3) | this spec §9.3 — new |
| `SMOKE-T963-` | T963 consolidation smoke | 5 (SMOKE-T963-1..5) | this spec §9.4 — new |
| **total** | | **25 cited + 16 new = 41** | |

And the closing sentence: "**Armed count: 41 of 41 normative ids carry ≥1 arm** (S10's 25, cited
unchanged, plus this spec's 16 new). No id in §3, §4, §5, §6 is left as prose."

---

## Red flag 1 — §4.5: decision 3's "how" is deferred without naming the ruling needed

The bundle's acceptance #3 requires decisions, not deferrals, and where genuinely deferred, the
spec must say whose call it is. §4.5 currently just lists the candidate mechanisms (reaper,
liveness poll, SIGCHLD, PID check) with no owner named.

**Resolution:** this is legitimately an implementation-row decision, not an operator ruling — the
bundle's own §6/decision 6 says "the implementation row… decides the mechanism," and T909 (the
retired brief this carries) never asked the operator to pick a mechanism, only to decide the
*contract* (holds survive until exit). The fix is a one-line addition to §4.5, not escalation:

> "**Whose call:** the implementation row's author, not the operator — this is an engineering
> choice among four contract-preserving mechanisms, none of which changes the observable contract
> in §4.2–§4.3 (verdict lands immediately; holds survive until process exit; the state is visible).
> The operator's ruling was already given at the contract level (§4.2, option 3+4 adopted); no
> further ruling is needed unless an implementer finds none of the four mechanisms feasible, in
> which case that finding — not a preference — is what would escalate."

## Red flag 2 — §7: the blocked/abandoned concern requirement has no available path today

**Checked myself:** `grep -c "concern" src/managent/main.zig` → 1 hit (a comment, confirmed by
inspection, not a command), and `docs/infra/managent/concerns.jsonl` does not exist on disk. The
audit's factual claim is correct — TC-8 as written today would refuse every `blocked`/`abandoned`
close with no path to satisfy it, which is exactly the stranding failure mode the whole direction
exists to prevent.

**Resolution — name the interim decision, per the bundle's instruction to decide rather than
defer:** gate TC-8 (and the confidence-field concern requirement in §6.1 item 2, for
`blocked`/`abandoned` closes specifically) behind T490's channel landing. Concretely:

> "Until `managent concern` and `concerns.jsonl` exist (T490's channel), a `blocked`/`abandoned`
> close's `confidence` field is satisfied by a free-text concern statement inline in the close call
> (the same shape T490 will formalize) rather than a structured record — **recorded, not refused
> for lack of the not-yet-built channel.** TC-8 tests the free-text interim form until T490 lands,
> then is re-armed against the structured channel. This is an explicit, named interim — not a
> silent gap — and it is retired the moment T490's implementation row closes."

This keeps TC-8 satisfiable today (no stranding) while stating plainly that the mechanism is
provisional, which is what the bundle's acceptance #3 requires when a decision cannot be made in
full.

## Red flag 3 — §6.4/§6.1: reporting-field encoding is never specified

The audit is correct that S10 explicitly punts acceptance-condition encoding to "a design-phase
decision" (S10 §2.1) but T963 makes no parallel statement for the five reporting fields, leaving an
implementer to guess the wire shape.

**Resolution — add the parallel statement S10 already modeled:**

> "**Encoding — a design-phase decision, not specified here (parallel to S10-ACCEPT-1's treatment
> of acceptance conditions):** the five reporting fields are logically one record per close (five
> named slots, four requiring an explicit 'none'/'no concerns' escape when empty, `delivered`
> requiring real content). Whether this arrives as five CLI flags, one `--report` JSON blob, or a
> `managent done --report <path>` file reference is an implementation choice; the contract this
> spec specifies is the record's *shape and requiredness* (§6.1), not its transport. The
> implementation row states its transport choice explicitly in its own bundle, per T963's own rule
> that nothing is silently decided."

And for §6.4's "prompt for them (if the worker is still reachable)" — this is genuinely
underspecified in a way that matters for the auto-close path specifically (a worker whose process
already exited cannot be prompted). Tighten to:

> "'Reachable' means the runner process has not yet exited (§4's liveness signal, reused here,
> not a new detector). A worker whose runner has already exited cannot be prompted; the auto-close
> records what it can and marks the rest `not-provided` per §3.1's corrected treatment (Blocker 1)
> — it never blocks on a prompt that can't be answered."

---

## What I did not reach

All 5 blockers and all 3 red flags are resolved above within the wall. I did not produce full
replacement prose for the two NOTE items (§9.1's "subset, not full set" framing and §0's "clean
host" phrasing) — both are one-sentence fixes the auditor already wrote correctly in
`audit-1.md`, and re-deriving them would not have changed the text, so I left them as the auditor
stated them rather than spend wall time restating agreement. I did not re-verify the "what I
checked that came out clean" section of the audit (no seventh verdict, `unverified` harness-emitted
only, S10-ACCEPT-1..3 consistency, the T786 timeline) — those are outside the five blockers and
three red flags this brief scoped me to, and the audit's own checked-clean claims are lower-risk
(they report the *absence* of a problem, not a specific fact I was asked to verify).
