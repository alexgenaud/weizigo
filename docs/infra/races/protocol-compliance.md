# Protocol-compliance race — Step 0 result and an explicit non-run (T863)

**Task:** T863 (claude-sonnet-5), 2026-08-24/25. **Conflict disclosure (race protocol v2.1 rule
11):** this row's author has no lane in the eight-model comparison the brief designs (claude-opus-5
and claude-sonnet-5 are entrants; this task is graded by the same family it partly ranks — noted,
not resolved, by whoever grades this row next).

## What this row is, and is not

The row's brief (T863, in the untracked working tree) designs an eight-model race and asks for
four things in order: verify equal treatment, run the race, run a control arm, write ledger cells.
**This row completes Step 0 only, on measured evidence, and stops there.** It does not dispatch any
of the eight entrants. Two reasons, stated instead of worked around:

1. This task was claimed by a leaf worker with no dispatch authority for this brief.
2. `oxalpha` carries `appetite: spend` in the family-appetite table
   (`src/managent/main.zig:537`) — a deliberate real-cost designation. Spending against it on a
   comparison whose own precondition (Step 0) turns out not to hold would be spending to produce a
   number the brief itself says not to trust.

The brief's own acceptance criterion allows this: *"Equal treatment verified byte-for-byte before
any entrant runs, **or an explicit refusal to run**."* This is the second branch.

## Step 0 — equal treatment, measured 2026-08-24/25

`T862` (glm-5.2, done, `pass-with-findings`) and `T891` (glm-5.2, done, `pass-with-findings`) have
both landed. Per the brief's instruction, the four lanes' argv were re-measured fresh rather than
trusted from either task's findings file. Method: `bin/subagent --override-admission=<reason>
--dry-run --provider <p> --model <m> <same target file>` for all eight canonical model names, which
prints the exact child command and a `TELEMETRY:` line without spawning a worker, touching the
kanban, or incurring cost (the same mechanism `tools/regression-lane-telemetry-parity.sh` uses).

### The injected prompt: byte-identical

Every one of the eight constructed prompts has the identical shape:

```
Follow <target>\n\nVERIFY-NONCE: NONCE-<hex>\nBegin your final reply with exactly the line: NONCE-<hex>\n
```

The only per-entrant variation is the nonce value itself and the target path — both of which the
brief already requires to differ (the nonce must be unique to detect echo-vs-genuine-reply; the
target would be the one shared brief file in a real run). **Byte-identical brief for all eight,
confirmed.**

### The argv: not identical beyond provider and model name

|                    | deepseek (pro/flash) | ollama (glm-5.2 / minimax-m3 / kimi-k2.7) | pi (oxalpha) | claude (opus/sonnet) |
|---|---|---|---|---|
| binary shape | `pi --provider deepseek --model <m>` | `ollama launch pi --model <m>:cloud -y --` | `pi --provider openrouter --model stealth/ox-alpha` | `claude -p '<prompt>' --model <m>` |
| `--mode json` | **yes** | no | **yes** (added by T891) | n/a — carries `--output-format json` instead |
| `--session <path>` | yes | yes | **yes** (added by T891) | **no** — carries a named `meter_reason` instead |
| `--thinking <level>` | threads if requested | threads if requested | threads if requested | never (claude uses `--effort`) |
| `--allowedTools ...` | absent | absent | absent | **present** (claude-only) |

This fails the brief's literal Step 0 test — *"assert the invocation differs only in provider and
model name"* — on four independent axes, not one. None of the four is a leftover bug: T891's own
verdict_note and `tools/regression-lane-telemetry-parity.sh` (arms A–F, re-run here, all still
PASS) document each difference as a deliberate response to a real capability gap (claude has no
`--session` flag; ollama's liveness comes from ollama itself, not JSON mode; claude's tool
allowlist has no analogue in the other three). **Equal treatment, in the strict byte-for-byte sense
the brief asks Step 0 to certify, does not hold, and cannot hold without misrepresenting what each
provider actually supports.** Per the brief's own instruction, that is reported as the result rather
than argued past.

### The part of the argv difference that actually matters for this race

The brief's real concern is narrower than "are the argvs identical" — it is "does the harness read
compliance through a channel that behaves differently per lane." That channel is `--mode json`:
JSON mode echoes the structured message list (including the injected prompt, and therefore the
nonce) back into the child's stdout; `tools/dispatch_verify.py:959` reads compliance as
`nonce in stdout` — a raw substring test with no idea whether the nonce arrived by echo or by the
model actually writing it. This is `D085` (confirmed on the real `verify_dispatch` code path by
`T862`'s regression arm H, not merely argued).

Splitting the eight entrants by whether their lane, **as measured today**, carries `--mode json`:

- **Echo-confounded (3 of 8):** `deepseek-v4-pro`, `deepseek-v4-flash`, `oxalpha`. A nonce
  reading here is biased toward a false PASS — the D085 test showed identical (non-complying)
  model behaviour scored PASS under `--mode json` and FAIL without it.
- **Not echo-confounded (5 of 8), for two different reasons:** `glm-5.2`, `minimax-m3`,
  `kimi-k2.7` (ollama; no JSON mode exists on this lane at all) and `claude-opus-5`,
  `claude-sonnet-5` (claude's `--output-format json` wraps only the final result envelope; it does
  not echo the conversation, so the injected prompt never re-enters stdout).

A ranking that pools all eight entrants' nonce columns without naming this split would not be
comparing eight models on equal footing — three of them are being graded on a channel proven to
inflate toward compliance, five are not. **This is the concrete form of "the race is not runnable
as designed" for this specific metric**, independent of the four-flag argv table above.

### A new risk this measurement surfaces, not present in T862 or T891's findings

`T891` fixed `oxalpha`'s observability by adding `--mode json` + `--session` to the pi/openrouter
lane (it previously had neither and ran with, per T891, "no stdout liveness stream at all"). That
fix is correct on its own terms — it gives `oxalpha` a token-rate meter it never had. But it also
moves `oxalpha` from the "not echo-confounded" group into the "echo-confounded" group for the
*nonce* channel specifically, because `--mode json` is the same flag that causes the D085 echo. The
observability fix and the compliance-measurement confound are opposite pulls on the same flag, and
T891 (scoped to telemetry, not to `dispatch_verify.py`) did not have to reconcile them. Before any
future race scores `oxalpha`'s nonce column, this needs a decision: either accept its nonce reads
are now confounded like deepseek's, or change `nonce_ok` to check a location JSON mode does not echo
into (e.g. a designated field in the parsed reply object, not raw stdout).

## Step 1 / Step 2 — not run

Following from Step 0: the eight-entrant task and the seven-column matrix are not run. Running them
now would produce numbers whose nonce column is known in advance to be unequally reliable across
entrants, which is exactly the outcome Step 0 exists to prevent shipping.

## Step 3 — control arm: cited, not re-run live

The brief asks for one model run twice, once unified and once pre-fix, to show whether compliance
tracks the invocation. `T862`'s regression arm H already ran the equivalent controlled comparison
on the real `verify_dispatch` code path (not a live model — a synthetic stdout fixture standing in
for one), and the result is the D085 finding cited above: **identical model behaviour, verdict
changes with the invocation.** This row did not additionally spend a live model call to repeat that
demonstration, for the same reasons Steps 1–2 were not run. The result stands on T862's evidence,
not on a fresh run by this task, and that provenance distinction is recorded here rather than
presented as new confirmation.

**Direction of the confound, stated precisely, because it matters for what follows:** JSON-mode
echo can only inflate stdout with text that was never the model's own output — it can produce a
false PASS, never a false FAIL. A lane with no `--mode json` has no mechanism by which the harness
manufactures a nonce that was not genuinely written by the model. This asymmetry is the key to the
next section.

## The four recorded instances — which model, and do they stand

The brief refers to "one model has four recorded instances of 'skipped the nonce and the close.'"
Counting `verified=fail` lines in `docs/infra/model-perf.md` per model (re-measured 2026-08-25,
stable across a concurrent edit to that file during this task): `oxalpha` has exactly **four** —
`T848` (logged twice), `T849`, `T860` — the only model at that count. This matches.

Disposition of each, using the harness facts established above (not re-litigated, cited):

- **`T848`, `T849` — `fail=row` ("skipped the close").** Both are dated 2026-08-24, before `T862`
  landed (14:35:18Z). `T862`'s findings establish that the runner's auto-close net was gated on
  `args.task_id`, which is `None` for every lane dispatched via `bin/subagent` (identity travels on
  `MANAGENT_TASK_ID` + `--arbiter-id` instead) — so **the net never fired for any lane**, not just
  `oxalpha`'s, until the fix. Both tasks were later completed and closed successfully under other
  models (`T848` by `deepseek-v4-pro`, `T849` by `glm-5.2`), consistent with a row that stayed open
  through a harness gap rather than through `oxalpha` producing no work. **These two instances are
  a false attribution and should be retracted from `oxalpha`'s protocol-compliance record** — the
  defect was universal and is now fixed, confirmed by this task re-running
  `tools/regression-lane-telemetry-parity.sh` (all arms PASS).
- **`T860` — `fail=nonce` ("skipped the nonce").** `bin/managent show T860` carries the seat's own
  contemporaneous note: exit 0 after 1325.4s, a 27,743-byte deliverable committed, nonce absent from
  stdout, row closed on evidence by the seat rather than by the worker. At the time `T860` ran
  (done 14:08:45Z), the pi/openrouter lane had **neither** `--mode json` nor `--session` — so the
  D085 echo mechanism, which requires `--mode json` to manufacture a false nonce, **cannot explain
  this one**: there was no echo channel to inflate a false PASS, and the echo confound has no
  mechanism for producing a false FAIL. A different, not-yet-tested gap remains open, though: T891
  separately found this same lane ran with "no stdout liveness stream at all," which is a
  capture-completeness question distinct from JSON echo, and this task did not test whether
  incomplete capture (rather than genuine absence) explains a missing nonce. **This instance is
  UNSETTLED — neither confirmed as a genuine model failure nor retracted as a harness artifact** —
  and the seat's original framing ("recorded as a protocol-observability failure, not a model
  failure," `T860` verdict_note) is the more honest of the two available postures pending that test.

**Plain statement, as the acceptance criterion requires:** three-quarters of the four recorded
instances (the close-skips) are retracted as a confirmed, now-fixed harness defect; the remaining
quarter (the nonce-skip) stands unresolved, not exonerated and not confirmed, pending a test this
task did not run.

## Ledger cells (Step 4)

No entrant ran, so no new `model-task-cells.md` / `model-perf.md` row is written for any of the
eight under task type `protocol`. The existing four `oxalpha` cells above keep their prior
`verified=fail` values in the log (append-only; not edited by this row) with the disposition above
recorded here as the current reading of them — three **untrusted-as-attributed** (harness bug,
fixed), one **open**.

## What has to be true before Steps 1–2 can run for real

1. A dispatcher with authority to spend against `oxalpha`'s `appetite: spend` budget, and standing
   authorization to run 16 live entrant calls (two rows × eight models) — outside this leaf task's
   scope.
2. A nonce-verification channel that does not degrade when `--mode json` is present — either accept
   and name the asymmetry per entrant (as this row does) rather than pooling it into one column, or
   change `dispatch_verify.py`'s `nonce_ok` check to read a location JSON mode does not echo into.
3. A decision on `oxalpha`'s newly-introduced echo exposure (above) before its nonce column is
   compared to `ollama`'s or `claude`'s on the same axis.

Until then, this document is the result: not a ranking, a statement that the race's own
precondition does not hold, plus the one finding (the retraction of three of `oxalpha`'s four
recorded failures) that survives independent of whether the race ever runs.
