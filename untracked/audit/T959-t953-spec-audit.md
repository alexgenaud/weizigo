VERDICT: BLOCKERS (3)

Auditor: deepseek-v4-pro/T959 · audit round 1 of the 7c.21 cap · date 2026-08-25.
I read `untracked/T953-three-red-gate-arms.md` and checked its evidence against the
repository (the three scripts it names were run live; the gate sources were read at HEAD).

---

## BLOCKER 1 — evidence-table row 1 (title gate) is false, and it poisons the central control

**Section:** "The problem, measured on 2026-08-25" table, row 1; also "Controls".

The title gate already names its subject. `bin/dispatch:390-395` prints, in one message:

```
dispatch: REFUSED — title `{title}` is {len(title)} chars, over the 40-char limit (DELEGATOR.md §Task titles).
  The title is a display surface, not a summary: a title that needs more than 40 chars is a sign the task is two tasks. Shorten it;
  the long form goes in the brief's body.
```

That is the subject (the title), the exact cause (the length), and a suggested action
("Shorten it"), and it has been that shape since `ec6fb20` (T505, 2026-08-20) — five days
before the incident the spec dates today. The table quotes only the last sentence as if that
were the whole refusal, and the "knew" column ("T798's title is 44 chars") is wrong on two
counts: the gate *prints* the length, and T798's title is not 44 chars — `# T798 — kills
visible in the kanban` parses to a 28-char title portion.

Consequence: acceptance #1 ("every arm shown red before its green") is unsatisfiable for the
title-gate arm. The gate already complies, so no seeded defect can turn it red without
reverting the fix. The row the spec calls "the sharpest case and the one that cost 22 minutes"
is a false positive. The arm cannot be built red-first as specified.

**What to change:** drop the title-gate arm from the table (or, if the author insists there was
a real incident, reproduce the exact output that was seen and cite the commit whose message it
was — at HEAD no such message exists).

---

## BLOCKER 2 — the `assign --exclude` arm is a decision change the spec forbids itself from making

**Section:** "Scope" item 2 vs "Out of scope".

`managent assign --exclude ollama` is not a refusal at all — it is a silent no-op.
`filterQualified` (src/managent/main.zig:760-770) matches an exclusion token only against an
exact family name or an exact canonical model; `ollama` is neither (families are
`ollama-cloud`, `claude`, `deepseek`, `local`, `oxalpha`, `google`), so the token is ignored
and the draw proceeds, assigning to an ollama model. To make this gate "name its subject", the
worker must **add** a refusal/warning on unknown exclusion tokens — a new decision, because
today the gate does not refuse and the work is assigned anyway.

"Out of scope" says: *"Changing any gate's decision — every refusal above was correct; only its
wording was not. Do not weaken a gate to make an arm pass."* That is in direct contradiction
with the arm: there is no wording to re-word here, only silence to fill. A worker cannot satisfy
both "fix it to name its subject" and "do not change any gate's decision" at once.

**What to change:** either (a) descope the `assign --exclude` arm from this row and give it its
own row with a recorded decision ("an exclusion token that names no family and no model is
refused, naming the token and the valid families"), or (b) relax the out-of-scope clause to say
explicitly that this one gate gains a new refusal and record that decision.

---

## BLOCKER 3 — the ollama-dispatcher triage is based on a false premise, and the arm is already green

**Section:** "Scope" item 3, second bullet.

I ran `sh tools/regression-ollama-dispatcher.sh` at HEAD: **all seven controls pass**, including
control 4 (`qwen3.8:27b-mlx`). The spec claims "controls 1–3 pass; only the local
qwen3.8:27b-mlx arm fails" and directs "establish whether the host serves that model; if not,
the arm must print `SKIP: host does not serve <tag>`". Control 4 is a `--dry-run` dispatch
(bin/subagent `--dry-run` builds the launch-command string and spawns nothing), so "does the
host serve the model" is the wrong question even if the arm had failed — a dry-run never serves
the model. The script has not changed since `99a919b` (2026-08-21), and the qwen mapping has
been stable since `d142a2a` (T463, 2026-08-19); the arm has been green the whole time.

The known-red entry `tools/regression-ollama-dispatcher.sh T953 repair` is stale and must be
**removed**, not repaired.

**What to change:** replace the qwen bullet with "remove the stale known-red entry; re-run to
confirm green"; delete the SKIP-on-absent-model instruction, which invents a failure mode the
dry-run cannot have.

---

## RED FLAG 4 — claimlint C2 row misidentifies the defect (the path IS named; the action is what's missing)

**Section:** evidence table row 2.

C2's detail section names the path. src/claimlint.zig:2048-2070 prints, per missing path,
`C2 <path>` plus `named in: …` and `reachable from N register row(s)`. The only way
`C2 dangling evidence paths 1` appears with the C2 detail reading `(none)` is when the "1" is a
C10-NEW volatile citation folded into the C2 summary count (src/claimlint.zig:3675 prints
`c2_total + c10_new`), whose path is listed under the C10-NEW section — a labelling subtlety the
spec does not mention, not "the detail section is empty".

The genuine remaining gap for C2 against the spec's own rule is the **"what to do" half**: the
detail names the subject and the cause but never suggests an action. The arm's seeded-defect and
null must therefore target the missing *action*, not a phantom missing *subject*.

**What to change:** correct the table's "printed / knew" cells, and specify the C2 arm as
red-first on the absence of a "what to do" line, not on the absence of the path.

---

## RED FLAG 5 — "three red gate arms" is one red arm plus two stale baselines

**Section:** title and "Scope" item 3.

Of the three known-red entries owned by T953, only one is red today. Live runs at HEAD:

| script | result | true disposition |
|---|---|---|
| `regression-store-census.sh` | all 4 arms PASS | remove stale known-red entry |
| `regression-ollama-dispatcher.sh` | all 7 controls PASS | remove stale known-red entry |
| `regression-managent-duty.sh` | FAIL, arm B | repoint fixture (one line) |

The managent-duty red is exactly the fixture drift the spec suspects: arm B greps `duties (1)`
but T894 (`b27c7f0`, "queue head orders by dispatch-readiness") renamed the section header to
`duties & standing triggers (1)`. The spec's "Suspect T894" is confirmed — `git log -S
"duties & standing triggers"` shows only `b27c7f0`, and `duties (` traces to T478 (`cd10b2f`).
Two of the three "red arms" are known-red-list **removals**, not repairs, so the triage is
mostly a deletion plus one grep re-point.

**What to change:** retitle to "known-red triage" and state upfront that two entries are already
green and are to be removed (with the re-run pasted), leaving one repair.

---

## NOTE 6 — the scope is three tasks wearing one ID

The rule "a refusal names its subject" applies cleanly to only two of the five rows: claimlint
C2 (missing action) and the fast-tier red report (missing per-script "why"). Row 1 (title gate)
is a false positive; row 3 (`assign --exclude`) is a silent-acceptance defect, a different rule;
row 4 (declared-and-absent) is a gate-robustness check, a third rule. The known-red triage
(scope item 3) is a third workstream attached to the wording rule only through row 5. As
written, one ID carries: a wording regression, a decision change, a hook robustness fix, and a
baseline cleanup.

---

## NOTE 7 — "suggested action" is asserted but never defined per gate

The regression must grep for a concrete action string per gate, but the spec leaves the wording
to the worker. The test's discrimination therefore depends on the worker's invention and can
drift from the fix. Each arm should name its asserted action string (e.g. "valid families are
…" for assign, "…" for C2) so the test cannot pass by accident.

## NOTE 8 — title-gate control says "task id" where the gate prints the title text

"Controls" says the title-gate arm "asserts the task id and the actual length appear", but the
gate prints the title text and the length, not the task id. (Moot under BLOCKER 1, which removes
the arm; if it survives, the assertion must be title-text + length.)

---

## The fourth option nobody considered (most valuable return)

The spec considered A (shared helper), B (one regression seeding a failure per gate), C (fix the
three red arms only) and chose B. A fourth option — **split by defect shape, drop the false
positive** — is better than B because B treats five different defects as one:

- **D1 — the wording rule, 2 arms not 5.** The regression seeds a failure only in the two sites
  that genuinely have the defect: claimlint C2 (red-first on the missing "what to do") and the
  pre-commit fast-tier red report (red-first on the missing per-script "why").
- **D2 — silent-acceptance, its own row.** `managent assign --exclude <unknown-token>` must
  refuse, naming the token and the valid families. This changes behavior, so it is its own row
  with a recorded decision, not a wording fix hidden inside a refusal-wording row.
- **D3 — gate robustness, its own row.** The pre-commit hook checks each selected script exists
  before running it, and fails at contract level: `declared and absent: <script> (declared in
  <contract>)`. This is the fix the store-census deletion actually motivates — commit `a2ffe87`
  says so in its own message ("T953 owes the loud contract-level failure that would have caught
  all three").
- **Drop** the title-gate arm (already compliant) and remove the two stale known-red entries
  (store-census, ollama-dispatcher) rather than "repairing" them.

D1 is B's worth without B's false premises; D2 and D3 stop the spec from smuggling a decision
change and a robustness fix into a wording row.
