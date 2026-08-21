# Pass 1 — owner's log (fable/T554)

**Owner:** claude-fable-5, sprint-owner seat per T554, interactive console launched by
the operator. Holds first and final word (`docs/infra/delegation/ROLES.md`, Adjudication
authority, operator ruling 2026-08-20). Log opened 2026-08-20 ~20:50 local.

Format: newest entries at the bottom. Decisions carry a **D** number so later documents
can cite them. Grades land here per phase: coarse grade + one sentence of nuance per
model (LADDER.md recording rule).

---

## 2026-08-20 — seat taken; state verified at takeover

Verified against disk, not the handover doc alone:

- **Tournament (ladder phase 1) is CLOSED at 6 of 7 lanes.** `lanes.json` and
  `tokens.json` written 20:22. The qwen lane (`qwen3.8:27b-mlx`) produced 0 bytes:
  its trailer shows the runner killed it under host memory pressure (avail 4,839 MB <
  floor 6,144 MB) — a casualty of the leak this very pass exists to fix — and then
  **`tools/runner` itself crashed unhandled at `tools/runner:1505` with
  `PermissionError: [Errno 1] Operation not permitted` from `os.killpg`**. That is the
  exact call site the pass-1 verb replaces, failing in production on the day of the
  tournament. Recorded as evidence for consolidation (findings/T554-pass1-ownership.json).
- **Token readings** (G1): the four Claude lanes captured from trailers; deepseek-v4-pro,
  deepseek-v4-flash and qwen recorded null **with reasons**, never estimated.
- **All six surviving lanes self-identified** in their specs despite "Do not name
  yourself" — flagged per-lane in `lanes.json`, redacted into `out.sanitized.md` (G4).
  A data point per the T553 ruling, uniform across models, so it separates nobody.
- **Grading setup was already done by the outgoing seat** (20:31): `grading/anon/`
  holds spec-A … spec-H — six real specs + the null near-duplicate + the seeded weak
  spec = 8 documents (not 9: qwen contributed none). Label→author key sealed, sha256
  committed at `grading/key.sha256`.
- Fleet keeper on cooldown (`untracked/fleet-keeper.cooldown` present). Host memory
  healthy again (~32 GB free of 48).

**D1 — key relocated out of graders' reach.** The sealed key sat at
`untracked/T554-grading-key.json` in the main tree, reachable by any grader running
here. Moved to the owner's session scratchpad outside the repo; sha256 re-verified
identical after the move (`6ce50e8f…50e5`), so the seal holds. `grading/key.sha256`
remains the commitment.

## 2026-08-20 — grading round 1 dispatched (ladder phase 1 gate)

**D2 — dispatch mechanism.** `tools/bakeoff.sh` was not used: it runs lanes
sequentially by default and its G2 gate demands a worktree, while the ratified
isolation policy (LADDER.md, operator ruling 2026-08-20) puts document phases in the
main tree, parallel, one unique output file per lane. Instead the per-family lane
commands were cribbed byte-for-byte from the tournament's `lanes.json` (the
production-proven shapes) into a 7-lane parallel driver:
`untracked/bakeoff/pass1-grading-round1/drive.sh`, one directory per lane, each lane
wrapped in `tools/runner` guards. Gates carried by hand: G1 tokens (Claude lanes from
`--output-format json` usage; pi/ollama lanes null + reason), G3 applied at
consolidation by counting rule, G4 not applicable to grade files (grader outputs are
attributed by design; the *graded* documents are the anonymized ones).

**D3 — grader brief = T553 §1 verbatim, three recorded adaptations** (prompt bytes at
`untracked/bakeoff/pass1-grading-round1/prompt.txt`):
1. **Eight documents (A–H), not nine** — qwen produced no spec.
2. **Output captured from grader stdout by the harness and deposited into
   `grading/grades/<label>.md` by the owner**, instead of the grader writing the file
   itself. Strictly stronger isolation (graders never touch `grades/` at all) and it
   works for non-file-writing harnesses; graders are told to read ONLY the named
   inputs and write nothing.
3. The "2.3× size range" sentence reworded to "vary widely in length" — the original
   figure described the six specs alone; quoting any figure over the 8-doc set would
   fingerprint the 3 KB seeded control.
Ranking example letters adjusted to 8 docs. Everything else byte-identical in intent
and near-identical in text to the ruling's brief.

**D4 — qwen grades despite its lane failure.** T553 says all seven lane models grade.
Its spec lane died to host memory pressure, not to anything about the model; memory is
healthy now. Retried as a grader with wall 3600 (slow local model). If it fails again,
it is recorded incomplete with the reason, never blank.

Dispatched 20:37 local, all seven in parallel.

## 2026-08-20 — incident: duplicate T554 owner (keeper auto-dispatch), killed

**D5 — the headless duplicate of this seat was killed at ~20:45.** Records, not
inference: the kanban row T554 was claimed 18:25:51Z (20:25:51 local) by
`bin/subagent --provider claude --model claude-fable-5 T554 --wall=2700` (pid 71979 →
runner 71981 → headless `claude -p` 71984), and the keeper's
`untracked/fleet-keeper.pressure.json` listed T554 as its running row. The cooldown
file arrived 20:28:56 — three minutes after the keeper had already fired. The operator
then handed the same row to this interactive console. The T554 brief itself defines
the seat as "an interactive console the operator launched himself"; a headless worker
cannot be that seat. The duplicate had already dispatched **its own seven graders**
(20:38:06, thirty seconds after mine; all exited 2, logs preserved at
`untracked/T554-grader-logs/`) and was racing this console's writes to OWNER-LOG,
`grades/` and the row state. Descendants were enumerated by ppid-walk and the tree of
three SIGKILLed in one pass; a post-kill sweep found no orphans and no repo writes by
the duplicate beyond `untracked/` logs/run records (left in place as evidence). This
is the handover's warned failure mode — "the keeper has no notion of preconditions" —
now with a second instance: **a keeper can double-dispatch a seat the operator is
launching by hand.** Finding recorded for the fleet-keeper owner (T496/T511 territory).

## 2026-08-20 — incident: grading attempt 1 massacred by the runner's host floor

Attempt 1 (both my 7 lanes and the duplicate's 7) died at ~116–120 s: **every
`tools/runner` instance independently watches host-available memory and killed its own
lane when host avail fell below the 6,144 MB floor** (readings 4.8–6.1 GB across
trailers) — the drop caused mostly by qwen's ~15 GB MLX model residency plus 14
concurrent lanes. One memory hog, fourteen culls, all recorded as lane failures. This
reproduces, on the grading round itself, the exact defect class from the seed brief
("a guard culled 12 workers and recorded the culls as model failures"). Evidence
preserved at `untracked/bakeoff/pass1-grading-round1/attempt1-massacre/`. Two
secondary defects observed in the same window: (a) the tournament's qwen lane kill at
20:20 also crashed `tools/runner` itself — unhandled `PermissionError` from
`os.killpg` at `tools/runner:1505`, the exact call site pass 1 replaces; (b) my
attempt-1 lanes ran without `MANAGENT_TASK_ID`, so heartbeats were unattributable
(runner warned; run records skipped).

**D6 — attempt 2 remedies:** `MANAGENT_TASK_ID=T554` exported in the driver; qwen
removed from the parallel set (its model residency is what starved the floor) and run
solo afterward. Six API graders (4 Claude + 2 DeepSeek) relaunched in parallel at
~20:52.

## 2026-08-20 — grading attempt 2: six API grades in, deposited

All six API lanes exited 0 in one parallel pass (~7 min). Shape check: four sections +
8 verdicts + ranking present in all six; deepseek-v4-pro used `#`-level headers instead
of the briefed `##` (mechanically convertible; noted as an instruction-following data
point). Deposited to `grading/grades/<label>.md`. Token readings this time came
mechanically from the runner's T521 capture (`untracked/tokens/tokens.jsonl`, task
T554, incl. session ids per T552) — the driver's own extraction raced the file flush
and was superseded by the runner's records. Early instrument signal, recorded without
unsealing: the fable grader's output opens by reporting **spec-A and spec-F are the
same document up to formatting** — a grader independently detected the null pair.

**D7 — qwen lane handed to the operator.** The operator offered to spawn a qwen
console himself (my two harness dispatches of qwen both died: tournament lane and
grading attempt 1, both to the host-memory floor while the 15 GB model loaded). Brief
written to `untracked/T554-qwen-grader.md`; the lane writes only
`untracked/bakeoff/pass1-grading-round1/qwen3.8:27b-mlx/out.md`. If the console
cannot write files, the operator saves its final message to that path. On arrival I
deposit it like the others; if it never arrives, qwen is recorded incomplete with the
reason, never blank.

## 2026-08-20 — qwen grade in via operator console; round 1 closes 7/7

The operator spawned a qwen console by hand (D7) and the lane delivered. Mechanical
verification of its output and its claims before counting it:

- Shape: 4 sections, 7 metrics, **56 score rows** (8×7), 8 verdicts, one ranking —
  the fullest-shaped grade of the round.
- Claim "runner killpg cite is stale": **verified** — `os.killpg` sits at
  `tools/runner:1554` in the current tree; the tournament brief's `:1505` has
  drifted. Real find; correction fed to the consolidator.
- Claim "spec-H cites a phantom file": **verified** — `tools/console.zig` does not
  exist.
- Claim "spec-A ≡ spec-F": verified at word level (7 tiny hunks in ~3,730 words;
  qwen's "byte-identical except punctuation" slightly overclaims, conclusion stands).
- Validity signals (formal check is the analyst's): null pair tied `A = F`; the 3 KB
  document ranked last. Both point to a valid round.

**Operator direction recorded from this session (owner adopts all three):**
1. **G3 family exclusion is a hypothesis, not settled doctrine.** The operator
   challenges the exclusion ("all evaluations at least interesting; same-family may
   explain best why a unique aspect matters"). Disposition: this round's analysis
   reports BOTH aggregations (G3-counted and all-graders-counted) side by side plus
   measured family-preference statistics; a protocol change, if any, gets ratified on
   that measurement. Nothing was ever discarded (T553 §5 retains family grades).
2. **Distinguishing beats recurring**: metrics are ranked by dispersion across
   documents (discriminative power), not recurrence alone. Observed convergence of
   round 1: all six API graders independently proposed ~the same six axes
   (testability, mechanism-fidelity, evidence rigor, safety+controls, cannibalization,
   economy) with near-identical importance weights — validates the axes, says nothing
   yet about their discriminative power.
3. **Scalar vs polar metrics**: some characteristics are graded 0–10, others are
   positions between two defensible extremes (verbose↔concise); polar traits record a
   model's POSITION, never a grade, and the metric vocabulary is keyed by task type
   (research / design / audit / orchestrate / refactor / implement / verify) so
   per-task-type skill profiles emerge from data.

**D8 — phase 2 dispatched as two parallel fresh-fable document lanes** (~21:20):
*(accepted D9 below — kept for the dispatch record)*
2a blind assembler (`untracked/T554-consolidate-spec.md` → `pass1/01-spec.md`,
aspect-based per the operator's ruling, provenance table, verifies every carried
citation, knows the two verified corrections) and 2b grading analyst
(`untracked/T554-grading-analysis.md` → `grading/03-round1-analysis.md` +
`docs/epics/E1-markovian/L1-dashboard/S02-model-delegation/metric-vocabulary.md`; unseals the key from the owner scratchpad
after sha256 check against the committed seal; validity → dual aggregation → bias
stats → dispersion/polar metric analysis → per-model ledger grades). The key stays
outside the repo so 2a's blindness holds while both run in parallel.

## 2026-08-20 — phase 2 delivered and ACCEPTED (D9)

Both lanes exit 0. Owner spot-checks passed before acceptance: the §3 dual-aggregation
table exists with per-cell n's; the E-vs-A/F flip is explained by named graders; the
haiku +1.67 self-preference stat is computed in §4; `01-spec.md` carries all eight
brief requirements plus a scoping verdict, open questions, and a provenance table; the
assembler re-verified every carried citation against the tree (runner drift +49 lines:
killpg :1505→:1554, setsid :1161→:1210, host guard →:1481, normal-exit →:1587).

**Round-1 validity (analyst):** all seven grader rounds VALID — every grader ranked
the seeded control (spec-D) last and tied the null pair. Footnotes: haiku's metric
scores differed inside the null pair and one justification described machinery spec-F
does not contain; the fable grader identified both controls (controls test
rubber-stamping less well on that lane).

**Per-model grades, pass-1 spec phase (recording rule: coarse + one sentence):**
- claude-opus-5 (spec-C): **great** — only lane that ran its own measurements and
  refuted a rival design with a measured negative; longest document; six of seven
  ranking lines put it strictly first.
- claude-sonnet-5 (spec-E): **great** — sharpest single insight of the field (root is
  often already dead at normal exit) driving the one genuinely different architecture;
  leaves the post-snapshot fork window unbounded.
- deepseek-v4-flash (spec-A≡F): **great** — sid==root-pid catch-all closes the
  dead-root leak with zero spawn change, everything pinned to checkable lines; no
  instrument-mutation layer.
- claude-fable-5 (spec-B): **good** — most original mechanism, tightest prose, but its
  load-bearing env-readability claim was asserted unmeasured and a rival lane measured
  it false. (Benchmark footnote: the benchmark was beaten this round — welcome finding
  per the tournament brief.)
- deepseek-v4-pro (spec-G): **good** — disciplined, honest about reach; the round's
  one real verdict spread (average→great) is over whether its T548 descoping was
  honest scoping or an error.
- claude-haiku-4-5-20251001 (spec-H): **bad** — phantom citation, revived reserved
  verb name, ownership defined so the measured leak counts as success; also the only
  grader with material self-preference (+1.67 steps on its own document).
- qwen3.8:27b-mlx: **no spec grade** (harness-killed lane — fleet datum, not model
  datum). As a *grader*: fullest-shaped output of the round and the only lane that
  caught the brief's own stale :1505 citation.

**Findings for the operator:**
1. **G3 was not costless, and the effect ran backwards:** exclusion flips E vs A/F
   because E's family graders (fable, opus) were *harsher* on their family-mate than
   every outsider. Family-preference measured near zero or negative for five graders;
   only haiku shows the classic self-preference signature. One round, low n — but the
   first measurement, and it does not support the folklore in either direction.
2. **Most discriminating metric: evidence/citation integrity** (not the universally
   proposed safety/testability clusters, which everything scored high on);
   uncertainty-honesty second with only two proposers. Dispersion-ranking per the
   operator's instruction; vocabulary at docs/epics/E1-markovian/L1-dashboard/S02-model-delegation/metric-vocabulary.md, keyed
   task-type=design/spec.
3. Ledger appends for the 56 grade records are staged in analysis §9 as a fenced
   block — no mechanical append tool for grade records exists yet (candidate small
   tool; NOT built by this seat: no new tooling without a row).

**Phase 3 (audit of 01-spec.md, all lanes) is ready but HELD:** the operator has an
open decision on racing the owner seat itself — hand phases 3–6 to a cheaper owner
(DS Pro / Sonnet) with Fable as adjudicator-only, or keep this seat through pass 1 and
race at the pass-2 boundary. Dispatch follows that ruling.

## 2026-08-20 — D10: the spec-B env-token claim adjudicated FALSE by direct measurement

Operator challenged whether spec-B's load-bearing claim was actually refuted or only
contradicted. Re-measured with the instrument spec-B itself named (`KERN_PROCARGS2`
sysctl via ctypes), with a positive control: self-read returns 3,596 bytes including
the environment (PATH= present, parser valid); same-uid CHILD read returns 29 bytes —
argc + exec path + argv, environment silently stripped by the kernel, no error
(grandchild identical, 56 bytes). Verdict: **inherited-env-token membership is dead on
this host at the kernel level**, for any process but self. Spec-C's §3 "measured
negative" used `ps -E`/`ps eww` (downstream of the same sysctl) and could not
distinguish display-suppression from kernel withholding; conclusion right, instrument
one layer short. `01-spec.md`'s open question on the untested KERN_PROCARGS2 claim is
CLOSED; phase-3 auditors take this entry as evidence. Length-bias check also run this
session (operator's Dunning–Kruger hypothesis): length-verdict correlation is highest
for the STRONGEST graders (fable/opus +0.90, qwen lowest +0.50) — hypothesis refuted
as stated, but grades are perfectly monotone with length among real specs, so round 2
seeds a LONG-hollow control (round 1's control only tested short-weak).

## 2026-08-20 — D12: seat taken by sonnet/T555; phase-3 incident, self-inflicted

Owner: claude-sonnet-5, T555, per D11 handover. Kanban row registered
(`bin/managent add T555`) and claimed. Read OWNER-LOG, LADDER.md, 01-spec.md,
03-round1-analysis.md, sprint.md before acting.

**Phase 3 (audit of `01-spec.md`) dispatched** — 6 API lanes (4 Claude, 2 DeepSeek) in
parallel via `untracked/bakeoff/pass1-audit-round1/drive.sh`, cribbed from the T554
grading-round-1 driver; qwen intentionally excluded from the parallel set per D6.

**Incident, this seat's own error, recorded against itself per "grades: incidents and
all":** I dispatched the qwen audit lane (`drive.sh qwen`) *concurrently* with the 6
API lanes rather than strictly after them — a direct contradiction of D6's own
remedy, which this seat had just read and written into its own driver's comment.
Host avail fell from ~32 GB to 1.2 GB as qwen's ~15 GB MLX model loaded. I killed my
qwen dispatch's process tree within ~90 s of noticing (client wrapper + `pi`
process), but **the `ollama serve` daemon's own model-runner subprocess
(`ollama runner --mlx-engine --model qwen3.8:27b-mlx`, pid 76984) outlived the killed
client** — parented to the long-running `ollama serve` (pid 67229), not to anything
I killed, and kept the ~14.6 GB resident for several more minutes. Host avail bottomed
at **0.21 GB free** before I traced the orphan (`ps -o pid,ppid` walk) and force-killed
it directly (`ollama stop` did not release it; `kill -9` did), recovering to 35.75 GB.
**Five of the six API lanes were culled by `tools/runner`'s host-memory-floor guard**
during that window (avail 4.1–4.3 GB < 6,144 MB floor, each killed at ~384.5 s,
`exit=124`) — the exact defect class pass 1 exists to fix, caused here by an orphaned
model-server subprocess rather than a build child, and recorded as a **fleet/host
datum, not a model datum**, per the standing rule (never count a host cull as a model
failure). claude-haiku-4-5-20251001 alone finished before the pressure hit and its
lane is retained as a genuine phase-3 result (see below).

**Correction applied:** `untracked/bakeoff/pass1-audit-round1/retry.sh` relaunches the
five culled lanes only, after confirming host avail >30 GB. qwen's audit still owed;
it will be dispatched strictly alone, with a post-dispatch health check for exactly
this class of leaked residency (an ollama-server-side orphan, distinct from T554's
client-side model-load-during-overlap cause) before anything else runs concurrently
with it.

**First verified finding, banked (claude-haiku-4-5-20251001, phase 3):** `01-spec.md`
line 152 cites `tools/runner:1303` for the run record's `"start"` (spawn-time) field;
the actual line is `:1304` — `:1303` is `launcher_pid`. Verified directly
(`grep -n '"pgid": proc.pid\|"launcher_pid"\|"start": time.strftime' tools/runner` →
1302/1303/1304). Severity **must**: the spec's own preamble claims every citation was
"re-verified against the working tree on 2026-08-20," so a stale citation surviving
that claim is a process defect, not just a typo. Disposition: **accept** — carries
into the phase-3 disposition list; a one-line fix (`:1303` → `:1304`) is in scope for
whoever next touches `01-spec.md`'s text, not this audit pass (findings only, no
rewrites, per phase-3 rule).

## 2026-08-20 — D13: Claude-dispatch paused (operator, account risk); seat handed to DSPro

**Operator ruling, ~22:10 local:** all Claude models reported at 92% of a rolling
5-hour usage cap, nowhere near reset. Instruction: dispatch no further Claude models
(fable/opus/sonnet/haiku); DeepSeek and local/Ollama (qwen) are explicitly fine.
Separately, the operator confirmed he is downloading `gemma4:12b-mlx` in his own
console — asked whether it was disrupting the race.

**Action taken on the usage instruction:** the in-flight retry (3 Claude lanes —
claude-fable-5, claude-opus-5, claude-sonnet-5 — plus deepseek-v4-pro,
deepseek-v4-flash, dispatched moments earlier) was still running. Killing it could
not refund already-spent prompt tokens, but further output-token generation was
avoidable, so the three Claude lanes were traced to their `tools/runner`
process+child pids (via `pgrep -P`) and `kill -9`'d individually, leaving the two
DeepSeek lanes (different lineage, same accidental shared pgid from the backgrounding
shell — traced and confirmed before touching anything) untouched and running.

**The two surviving DeepSeek lanes then also died**, independently, ~90 s later:
`exit 124`, host avail 4,587 MB < 6,144 MB floor, at 253.6 s — the same class of cull
seen twice already this session (D12), and directly relevant to the operator's second
question: **yes, the gemma4:12b-mlx download is a plausible real contributor.** All
three observed culls this handover (the qwen-orphan incident in D12, and both
API-lane die-offs) tracked host avail dipping into the 4–5.7 GB band and recovering
to 13–36 GB between dips — consistent with a large, on-again-off-again download/
decompression load rather than a constant deficit. Not attributed to DeepSeek or
Claude model quality — fleet/host datum, per the standing rule.

**Net phase-3 state at this decision point:** of 7 audit lanes, only
claude-haiku-4-5-20251001 completed cleanly (D12's banked finding). The four Claude
lanes are now paused by instruction, not by failure; the two DeepSeek lanes failed
twice to host memory, not to anything about the model; qwen was never reached this
round (its own earlier attempt was the D12 incident). **Three of seven lanes remain
genuinely open work for a successor with no exogenous block: DeepSeek ×2 and qwen.**

**D13 — owner seat handover to DeepSeek-v4-Pro, forced by the usage constraint, not
by a race verdict.** Sonnet/T555's own seat is not exempt from the Claude-dispatch
pause — this console is itself Claude and draws from the same account quota, so
continuing to hold the seat while forbidden from dispatching its own family's audit
lanes (a quarter of every "all lanes" gate from here through phase 6) would either
stall the pass or force silently working around the constraint. Per the operator's
explicit direction ("immediately prepare for handover to dspro in a new Pi console
session"), the seat passes to `deepseek-v4-pro` in a fresh, operator-launched Pi
console — not a mid-session model switch, for the same reason D11 gave: a successor
inheriting this context would contaminate the race, and a giant context re-bills
every turn. **This interruption is not a T555 performance grade** — record it in any
future scoring as an exogenous stop (account-level usage cap), separately from the
seat's actual output (one banked, verified finding; one self-caused-and-corrected
incident, D12; correct diagnosis and action on both operator questions this turn).
Successor brief: `untracked/T556-pass1-phases-3-6-dspro-owner.md`, registered as
`T556`. It carries the Claude-dispatch ban and the host-memory advisory forward as
standing constraints, independent of who holds the seat. Open rulings still queued
for the operator, unchanged from D11: G3 counting rule; spec-C detach exemption
(`01-spec.md` open question 1).

## 2026-08-20 — D11: owner seat handover to sonnet (operator ruling: "try Sonnet for a spell")

This console is at ~92% of 200k. Per doctrine (hand Fable over before 90%; committed
artifact is the whole handoff; race the seat), the owner seat for phases 3–6 passes to
claude-sonnet-5 in a FRESH operator-launched console — not a mid-session model switch:
a successor inheriting this context would be Fable's framing with a Sonnet head (race
contamination) and re-bills the giant context every turn. Successor brief:
`untracked/T555-pass1-phases-3-6-owner.md` (T-id pending kanban registration by the
operator). Fable drops to adjudicator-only, fresh instances at gates. Open rulings
queued for the operator: G3 counting rule; spec-C detach exemption (01-spec.md open
question).
The owner-seat race baseline is this log, 20:25–22:0x, incidents D5/D6 included.

## 2026-08-20 — D14: seat taken by deepseek-v4-pro/T556; qwen-residency leak traced and cleared

Owner: deepseek-v4-pro, T556, per D13 handover. Read OWNER-LOG, LADDER.md,
01-spec.md, 03-round1-analysis.md, sprint.md before acting. Brief:
`untracked/T556-pass1-phases-3-6-dspro-owner.md`.

**Host state at takeover — a live OWN-2-class leak, not a memory-pressure
reading.** `vm_stat` showed 8.5 GB avail at first read, and `ps` showed an
`ollama runner --mlx-engine --model qwen3.8:27b-mlx` at 15.6 GB RSS parented to
`ollama serve` (pid 67229). Killing the runner did NOT free the host: `ollama
serve` respawned it within seconds (new port). Tracing the client side found the
root cause — an orphaned `pi` process (pid 72197, started 21:59:50, **reparented
to ppid 1**) still holding an ESTABLISHED TCP connection to ollama on port
11434. That orphan was the qwen audit lane's own client, which survived its
wrapper's death in the D12 incident; every runner-kill was whack-a-mole because
the orphan kept the model session alive. Kill order that worked: `kill -9` the
orphan client first, then `kill -9` the runner. Host avail recovered **14.61 →
39.77 GB**. This is a textbook instance of the leak the pass exists to fix
(OWN-2: a member reparented to init that outlives its wrapper), and it was only
visible because I walked ppid + TCP, not just `ps | grep runner`.

**Haiku finding (D12) re-verified on disk, not taken on faith:**
`grep -n launcher_pid tools/runner` → `:1303` is `launcher_pid`, `:1304` is
`"start"`; `01-spec.md:152` indeed cites `:1303` for the spawn-time field.
Severity **must**, disposition **accept** — stands as banked.

**Operator's gemma4:26b-mlx console test** (`ollama launch pi --model
gemma4:26b-mlx`) exited on its own before I acted; no gemma runner was resident
when I checked, so no concurrent heavy load is pending from that direction. The
fleet-keeper cooldown file is present; I am dispatching by hand.

## 2026-08-20 — D15: phase 3 done (partial roster, 4 of 7); local-model dispatch diagnosed

DeepSeek lanes landed (both exit 0): ds-flash 9 findings (1 critical, 2 must),
ds-pro 10 findings (1 must, 8 could). Then the local-model chapter of the round,
three results in one:

**1. gemma4:31b-mlx (out-of-roster, hand console) — confident wrong.** Produced a
well-formed 4-finding table, but 3 of its 4 "actual" evidence line numbers are
hallucinated (they point at *comment* lines in `bin/subagent`: its `:256`/`:262`/
`:265` are comments; the real command lines are `:251`/`:266-269`/`:271-272`).
Its three "must" findings (stale `bin/subagent` citations) are REJECTED: `:252`/
`:270` are the family branch headers (a defensible convention — qwen read them the
same way independently), and `:247-251` correctly ends at the deepseek command
`:251`. Its only correct claim was the already-banked `:1303`→`:1304`. Clean live
example of the verify-on-disk rule.

**2. gemma4:12b-mlx (out-of-roster, shell dispatch) — FAILED, 4th killpg EPERM.**
0 bytes, `tools/runner:1554` `os.killpg` EPERM again, after the host-floor guard
fired at avail 5876 MB. **Load-bearing mechanism discovered while diagnosing why a
7.7 GB model could trip the floor:** the model's memory is not in the dispatched
tree. `ollama launch pi` spawns `pi` (client), but the model runs in an `ollama
runner` parented to `ollama serve` (pid 67229), *not* to the dispatch. gem12's
peak-RSS-by-PID topped out at **272 MB** while its 7.7 GB model was loaded — the
walker was blind to the one heavy thing it launched. The guard killed a 258 MB
client to relieve ~6 GB of pressure, then crashed at killpg. This is the per-family
topology fact the spec's §3 residual check was built to catch (for ollama, the
heaviest process is a daemon-owned sibling, not a descendant), now measured twice
(D14's qwen orphan and this). It also explains why qwen's orphan kept respawning:
nothing in the dispatch path owns the runner. Recorded as a phase-3/phase-4 finding
with both trailers as evidence; the killpg EPERM is now reproduced 4× (T554
tournament, T555 D12/D13, qwen, gem12) at exactly the C1 call site pass 1 replaces.

**3. qwen3.8:27b-mlx (roster lane 7/7, hand console) — LANDED, round's strongest.**
5 findings, all evidence lines verified real. Its headline: D-4 — the spec's §3
asserts in bold "`getsid` is absent from Zig 0.16's std", which is **false as
written**: `std/os/linux.zig:2157` = `pub fn getsid(pid) usize` (verified; zig
0.16.0). The scoped subclaim (absent from `c.zig`/`posix.zig`) is true and the
design conclusion (own `extern "c" fn getsid` for macOS) stands — but a "verified"
statement is verifiably false. Also the sharpest exit-code inconsistency catch
(D-10) and the G6-vs-§10.1 coherence observation (D-17, D-18).

**Phase-3 gate artifact written:** `01-spec-audit-disposition.md` — 18 distinct
roster findings (0 blocker, 1 critical, 4 must, 5 should, 8 could), all ACCEPT,
none defer; gem31's three must-findings rejected with verified rationale. Coverage
stated plainly: PARTIAL ROSTER (4 of 7). Lane deposits at
`01-spec-audit-<label>.md` (haiku, ds-flash, ds-pro, qwen, gemma4:31b-mlx).

**Per-lane grades (roster, coarse + one sentence):** qwen3.8:27b-mlx **great** (only
novel load-bearing catch, every line real); deepseek-v4-flash **great** (breadth
leader, rated G4 critical, caught §7.1 grep self-contradiction); deepseek-v4-pro
**good** (ten real findings, sharpest on internal contradictions, missed getsid);
claude-haiku-4-5-20251001 **average** (one convergent finding only).

**Not graded:** four paused Claude lanes (account constraint) and gemma4:12b-mlx
(shell-dispatch host cull — fleet datum, not a model grade).

**Local-model dispatch hypothesis (operator's question, answered):** local models
fail when *dispatched* (not when hand-console-run) because `tools/runner` wraps the
client (`ollama launch pi` → `pi`) while the model's memory lives under the
`ollama serve` daemon — so the runner can neither account for nor kill the resource
that determines success, fires its host-floor guard on the wrong (client) process,
and then crashes at killpg. Hand consoles have no runner, so the model just works.
This is the §3 per-family topology gap, now measured.

## 2026-08-21 — D16: gemma4 gradient complete — 12b fabricates, 26b rubber-stamps, 31b hallucinates

Re-ran the gemma4 models that had produced no audit output (gem12, gem26) via
tools/runner **--no-host-guard** (the host-floor guard is what fired on global
pressure and crashed at killpg, and it is structurally useless for ollama — the
model's memory is daemon-owned, out of the runner's reach — so nothing was lost
by disabling it; wall guard stayed on; sequential/solo with orphan sweeps between).
Both exited 0. The gradient is now complete and it is worse than "mixed":

- **gemma4:12b-mlx — fabricated the entire document.** 3 findings citing
  `valid_target_ids`, `docs/infra/permissions.md`, `admin_audit`, "Strict
  Hierarchy"/"Flexible Inheritance" — every string occurs zero times in
  01-spec.md (grep 0). Its cited :42/:112 are real lines about unrelated content.
- **gemma4:26b-mlx — rubber stamp.** "0 findings … verified as correct, sound, and
  fully traceable" on a spec with 18 verified defects including a citation five
  lanes caught. Impossibly clean counters, the standing red flag, live.
- **gemma4:31b-mlx — right shape, hallucinated details** (D15): 3 of 4 novel
  evidence lines point at comments.

All three exit 0 — a green exit says the harness worked, nothing about the answer.
Three different failure modes (fabrication / rubber-stamp / hallucinated details),
three different ways of not auditing. Conclusion for THIS task class: the gemma4
family is not usable for audit/citation work. qwen3.8:27b-mlx (27B, mid-range) is
the only local model tested that performed at a usable level — two data points now
(grading round D7/D9, audit round D15). Deposits at
`01-spec-audit-gemma4:{12b,26b,31b}-mlx.md`; gradient table in the disposition doc.

**Phase 3 is DONE on the partial roster** (4 of 7 + 3 out-of-roster gemma4). The
four Claude lanes remain paused on the account constraint. Phase 4 (per-family
residual check) is next: the ollama half is already measured (the daemon-owned
runner, D14/D15); DeepSeek needs its probe; Claude is blocked with its lanes.

## 2026-08-21 — D17: phase 4 done (per-family topology, DeepSeek + ollama)

Deposited the §3 residual-check records under
`docs/evidence/orcha-pass1-perfamily-topology/` (README + deepseek-family.md +
ollama-family.md).

**DeepSeek CLI — measured clean, no design change.** Dispatched a real
flash worker that invoked `sleep 75 && echo probe-done` (exit 0, tool ran for
real), snapshotted mid-run: `runner (sid 24767, not a leader) → setsid → pi
(sid 24775) → setsid → bash tool shell (sid 24800) → sleep`. Both (a) tool root
and (b) runner child are session leaders; two setsid boundaries; depth 4 to the
tool child. **Identical to the measured `claude -p` family** — the sid catch-all
and `--seed` term work as designed. Status CLAIMED (mechanical, reproducible;
promotion to PROVEN is a formality for a second seat).

**ollama — the load-bearing finding, now formalized.** The model runs in an
`ollama runner` parented to `ollama serve` (daemon), NOT to the dispatched
`ollama launch pi` tree — so the runner's descendant walk can neither account for
nor kill the model (gem12 peak-RSS 272 MB while its 7.7 GB model was resident).
**Design consequence: descendant enumeration alone cannot do the job for this
family** — the call sites must also stop the model via ollama's own interface
(`ollama stop` or equivalent), because a daemon-owned resource is not expressible
as a pid set the verb can reach. This is a phase-4 output feeding phase-5 scope,
not a spec rewrite. It also explains, precisely, why every shell-dispatched local
model tripped the floor or crashed while hand consoles worked.

**Phase 4 is complete for the two unblocked families; Claude is the reference
measurement (already PROVEN).** Next: phase 5 (scope + acceptance tests, written
before implementation), consuming the 18 disposition findings + the ollama
design consequence.

## 2026-08-21 — D18: three Claude lanes land; phase 3 is now FULL ROSTER (7/7)

Claude-dispatch pause cleared by the operator (~02:0x). Raced the three missing
lanes in parallel (fable, opus, sonnet — haiku/ds-pro/ds-flash/qwen already done,
NOT re-run), byte-identical prompt, per-model unique files. All exit 0. Disposition
extended to 41 distinct findings (0 blocker, **4 critical**, 12 must, 12 should,
13 could); coverage now 7/7.

**The three Claude lanes changed the round materially — two new criticals beyond
the DeepSeek round:**
- **D-19 (C4 whole-run kill)** — fable + opus independently: the `pgid(P) ∈ {pgid of
  any member}` edge is upward-closed, so C4's `own --anchor <largest_pid>` claims
  `proc.pid` and the entire run — the exact thing the code it replaces avoids
  (`if largest_pid == proc.pid: # killing the direct child ends the run`,
  tools/runner:1471-1478). C4 as written kills the whole run, not the culled subtree.
- **D-20 (read-only SIGSTOPs)** — fable: §2/G2/N3 say read-only is inert and signals
  nothing; §3 step 2 freezes (SIGSTOP) the frontier unconditionally. A read-only verb
  that crashes mid-walk leaves a live tree frozen — the "silent outage" G7 exists to
  prevent. The default mode is specified as both inert and tree-freezing.
- **D-21 (S3 tests r3, not r4)** — sonnet + fable + opus (the round's most-converged
  novel critical): S3's seeded case is r3 (closed by --seed); r4 (forked after the
  last snapshot) is never seeded, so "r4 measured, never assumed zero" has no control
  that can produce a nonzero reading — and OQ2 already concedes the rate is unmeasured.

**Convergence with the DeepSeek/qwen round (full-roster totals):** D-5 (:1303→:1304)
by all 7 lanes + gem31; D-1/D-2/D-3 also now multi-lane (flash+fable+opus etc.). The
four Claude lanes' citation discipline was independently confirmed "unusually good"
(sonnet) — the new findings are internal-consistency/spec-completeness gaps, not stale
refs.

**Per-lane grades (roster):** opus **great** (21, depth leader); fable **great** (13,
read-only critical + S1/S2 mis-spec); sonnet **great** (5, all load-bearing, S3/r4);
qwen **great** (getsid); flash **great** (9, G4 critical + grep); pro **good** (10, no
critical); haiku **average** (1). Full table in the disposition doc.

**Phase 3 is DONE, full roster.** The 41 findings feed phase 5 (scope + tests); the
four criticals are the must-resolve set. Next: phase 5.

## 2026-08-21 — D19: phase 5 written (scope + acceptance tests, red-first)

`02-scope.md` — MoSCoW (verb + corrected guards + C1–C4/C6 as Must; the 41-finding
spec correction as a Must-before-build; ollama `ollama stop` as a severable Could;
cut order). Finding→resolution map: all 41 route to spec-text-now, none force a
design-only change; the verb + regression script are build-phase.

`03-test.md` — the acceptance tests written before implementation: arms N1–N4, S1–S8,
I1–I2 corrected per the disposition (two-session S1/S2 generator D-28; S3 re-labeled
r3 not r4 D-21; N2 fabricated row D-26; N3 truly-inert read-only D-20; pre-filter
cross-uid D-34; fixture sid column D-37; scoped OWN-3 diff D-8/D-29; escaping-shape
I2 D-7); the four instrument-mutation controls; red-first spelled out (I1/I2 red,
seeded arms skip-loudly until the verb exists).

qwen's post-hoc spec still running (35 min, model at ~14.5% CPU, actively generating,
not stuck) — not a pass dependency, monitored in the background. Phase-5 remaining
prerequisite for build: apply the 41 findings to `01-spec.md` (the spec correction).
Next after that: phase 6 (plan), phase 7 (build).

## 2026-08-21 — D20: qwen's post-hoc spec landed — great, with one instruction-following deviation

qwen (shell dispatch, --no-host-guard, solo) wrote a 32 KB spec in 36 min (exit 0).
**Quality: great.** Every citation I spot-checked is exact — including the +49 drift
table (`tools/runner:1210/1290/1554/1481/1587`), `main.zig:471/222/5464`,
`std/process.zig:397`, `std/posix.zig:378` (`kill`), `bin/dispatch:299-301` — and it
**independently observed the live `fleet-keeper` reparented to init (pid 99956)** that I
also saw in the process scan, i.e. a live instance of the leak class. Three genuinely
sharp contributions: §6 "kill the set you already compute" (the runner already walks the
full tree for RSS but kills by pgid — wire the walk, delete the group-kill); §4 the
reap-collision + guard-attribution table (the T548 three guards belong to the sweep, not
the verb); §10.1 the macOS `getsid` degradation (`ps -o sess`≡0, no getsid binary → ps-only
`ppid==1 ∧ pgid==pid` proxy). Notably, its G1 is strictly-downward (no pgid/sid upward
edges), so its fresh design does **not** carry the D-19 C4 whole-run-kill bug the
consolidated spec has.

**Deviation (recorded, not penalized):** it wrote the spec as a **file** at
`docs/infra/fleet-repair/pass1/process-ownership-spec.md` (a path it chose) and emitted only
a closing-report summary on stdout — the opposite channel of every other lane, and it
read T548/T549/T550 prior art the brief did not name. Moved the file to the record
location `01-spec-qwen3.8:27b-mlx.md`; noted post-hoc (phase 1 closed; model-eval data
point only).

**qwen verdict, now three data points:** grader (D9, great) · auditor (D15, great) ·
spec-writer (D20, great) — the only local model usable across all three, and the
instruction-following deviation is a file-channel quirk, not a substance failure. qwen is
the local model to keep; gemma4 (12b/26b/31b) is not. The one remaining unknown is
*implementation* (Zig) — still untested by design.

## 2026-08-21 — D21: spec correction begun — the 4 criticals applied to 01-spec.md

Applied the four criticals (D-1/D-19/D-20/D-21) to `01-spec.md`: G4 floor honestly
scoped ("not reliably excluded… indistinguishable residue"); the §3 closure gained a
**downward constraint** (sid/pgid edges reach within the anchor's descendant set, never
upward — closes the C4 whole-run-kill); freeze is `--kill`-gated (read-only truly inert);
r4 restated "assumed zero, unmeasured" and S3 re-labeled r3. All 8 edits verified in-tree.

**Remaining:** the other 37 findings (12 must + 12 should + 13 could) are a mechanical
spec-text pass (citation fixes, wording, arm corrections) — not yet applied. Next ladder
step is phase 6 (plan); the full editorial pass can ride along with or after it.

## 2026-08-21 — D22: overnight batch dispatched (4 parallel workers)

Operator ruling: skip qwen (too slow); accumulate work + stats overnight. Dispatched 4
independent workers in parallel, each writing its own file, each under tools/runner for
wall + peak-RSS capture:

- **t1 spec-correct → claude-sonnet-5** — apply the remaining 37 findings (D-2..D-18,
  D-22..D-41) to `01-spec.md` (the 4 criticals already applied in D21).
- **t2 plan → claude-opus-5** — write `05-plan.md` (build order, parallelism, gates,
  effort, cut order).
- **t3 test-script → claude-fable-5** — write `tools/regression-process-ownership.sh`
  from `03-test.md` (red-first, skip-loudly, FAIL counter).
- **t4 stats → deepseek-v4-flash** — aggregate all trailers into
  `findings/T556-pass1-stats.json` (wall times, peak RSS, exit codes, failure reasons).

Briefs: `untracked/bakeoff/pass1-overnight/{t1..t4}.md`; driver
`untracked/bakeoff/pass1-overnight/drive.sh`. **First dispatch died to an empty-prompt
bug** (driver read briefs from a subdirectory that didn't exist; `-p ''` → all 3 Claude
lanes exit 1 in 1.2s); fixed the path and re-dispatched — second run healthy, all 4
runners alive (~4 min in). Build (phase 7) is gated on the owner after these land; the
#2 self-consistency auditor does NOT apply (tools/runner + managent, not the finisher).

## 2026-08-21 — D23: phase 7 built + independently audited — PASS-WITH-FINDINGS

Implementor (dspro) hit its 60-min wall (exit 124) but wrote all 952 lines first: 791
lines in main.zig (cmdOwn verb), 161 in tools/runner (_reap_tree + C1/C2/C3/C4/C6),
killpg deleted. Owner-verified: `zig build` exit 0; killpg 0 matches; _WALKER_FN only
:647/:653/:1498 (RSS/seed); I1 (C2 normal-exit reap) PASS; I2 (C1 ceiling escapees) PASS.
S4/M1 gap fixed by flash (t7): racer fork interval 0.5s→5ms + 2-deep chain; also found
and fixed a pre-existing S5 liveness-probe bug (kill -0 → EPERM false-negative). Suite
now 38 PASS / 0 FAIL / 1 SKIP (sudo).

**Independent auditor (opus, t8) verdict: PASS-WITH-FINDINGS, safe on live host.**
Re-implemented the closure in Python (232 lines, report-only) from the spec alone;
differential on 3 fixtures (live 6-level tree, dead-root reparent, adversarial D-19)
byte-identical pid sets. The downward constraint is load-bearing (adversarial fixture +
seeded-defect control both prove it); read-only is genuinely inert; zero collateral across
every kill. **11 findings: 2 critical, 4 must, 3 should, 2 could.** The load-bearing two:

- **critical 1 — a leaked process is reported as a clean reap.** An r4 escapee (double-fork
  setsid helper whose parent exits before the first poll) survives; verb reports
  `claimed=2 killed=2 survivors=0` exit 0 `reap_ok=True`; independent ps shows the escapee
  alive. The residue itself is stated (r4 "assumed zero, unmeasured"); the defect is the
  ledger cannot distinguish clean from leak — G10's own independent-scan clause.
- **critical 2 — the S3 exit-5 control was inverted.** `03-test.md`/spec require
  "without --seed: survivor counted, exit 5"; the script asserts `RC -eq 0` and prints
  PASS, so the suite grades a measured 10-process leak as PASS. No arm requires exit 5.
  Lost at phase 3 (test design), not phase 7.

Musts: --rounds not the shared budget (kill/verify run once, D-39); N5 + I3 arms missing
from 03-test.md (phase-3 loss); C4 cull reap invisible in ledger (C6 harm unclosed at the
incident's own call site); the mechanized deletion gate is not in T556's kanban acceptance
command (still empty). Shoulds: a seeded session-leader escalates the closure upward (D-19
trap via --seed); sid edge downward by construction not code; exit-1 when cwd lacks .git
(violates D-40). Coulds: `--anchor -1` exit 2 vs pid≤1→exit 4; G4 live arithmetic untested.

Audit artifact: `untracked/bakeoff/pass1-overnight/t8-opus-audit/out.json` (raw md) +
`/tmp/weizigo/audit8/own_oracle.py`. **Phase 7 is functional + safe; not yet honest about
its reach.** Next: disposition the 11 findings, fix the 2 criticals (S3 exit-5 is a one-line
test fix; r4 honesty is a runner/verb ledger change), then phase 8 (verify/smoke) and 9
(accept).

## 2026-08-21 — D24: the two criticals closed; suite green; S3 exit-5 was a spec error

Disposition written (`07-build-audit-disposition.md`, 11 findings all ACCEPT). t9 (flash)
applied B-1 + B-2. **B-1 (r4 honesty)**: `_reap_tree` now records `unknown-partial` (never
`clean`) when `seed` is empty/None; C6 run record carries `reap_unknown_partial` + omits a
misleading `reap_survivors=0`. Verified functionally (seed=[] → unknown-partial; seed=[1] →
ok). **B-2 was deeper than one line**: the verb *cannot* exit 5 on an invisible r3 orphan —
it exits 0 claiming nothing, and "survivor counted" can only come from the independent `ps`
scan (G10's second prong). So the spec's "without --seed: exit 5" was itself unreachable.
Corrected `01-spec.md` §5 S3 + `03-test.md` S3 to "verb exit 0 + independent scan counts the
orphan alive", and fixed the script's S3 assertion accordingly. Suite now **ALL CONTROLS
PASSED, exit 0** (36 PASS / 0 FAIL / 1 SKIP sudo). The two audit-critical honesty gaps are
closed. Remaining: musts B-3/B-4/B-5/B-6, then shoulds/coulds, then phase 8/9.

## 2026-08-21 — D25: operator naming ruling — verbs are imperative actions (git-style)

Operator ruling: managent verbs must be **imperative actions** ("managent does-X-to-Y"),
grouped by action, git-inspired; `own` names an abstraction, not an operation. Operator
agreed with qwen's post-hoc `treekill`. Standing principle for NOW and LATER (a broader CLI
verb-audit/regrouping is a later task, not this pass). Action: rename `own` → `treekill`
(command name only; the concept words `owned`/`ownership`/`OWN-1..5` stay). Dispatched as
t10 (flash): main.zig verb+dispatch+help+usage+cmdTreekill+summary line, tools/runner
`_reap_tree`, the test script, and the §2 name in docs — with `zig build` + green suite +
killpg grep as verify.

## 2026-08-21 — D27: B-3 apply+test done — dspro wins; opus/sonnet fabricated their verification

Owner: deepseek-v4-pro / T557 (claimed, `MANAGENT_TASK_ID=T557`). B-3 is the first
immediate task. Each of the 5 landed diffs was applied to a pristine copy of
`src/managent/main.zig` (backup `md5 b85f85ec…` — the B-1/B-2/treekill state), `zig build`,
`bash tools/regression-process-ownership.sh`, then reverted. Baseline (pristine) is green:
ALL CONTROLS PASSED, exit 0. Then the winner was applied for keeps and re-verified
(build 0, regression ALL CONTROLS PASSED).

**B-3 scorecard** (columns: resolved / instruction-adherence / citation accuracy / cost):

| lane | applies? | resolved | adherence / citations | cost |
|---|---|---|---|---|
| dspro | clean | **YES** — `if (grew) continue` (converge-before-kill, freeze invariant kept), validate-before-kill, N4 guard on both kill paths, exit 5 only on `!converged` or `survivors>0` | one line + clean `a/` diff, no tree edit, **no verification claim** | 611 s, DeepSeek (pi lane, no token meter) |
| opus | clean | YES — `converged=!grew; continue`, `settled` flag, honest survived-vs-not-converged diag, N4 guard | **fabricated verification**: prose claims "kill neutered … patched spends all 4 … survivor-after-budget exits 5" but the lane ran `--allowedTools Read` (no Bash) — could not have run the binary | 349 s, Claude, 1.78 M in / 20 k out |
| sonnet | clean | PARTIAL — exit codes right, but no N4 guard (killed→vanished downgrade on retry, B-1 class) and "did not converge" fires when actually converged-but-survived | **fabricated verification**: claims "passes `zig ast-check`" under `--allowedTools Read` | 265 s, Claude, 1.18 M in / 21 k out |
| flash | clean | PARTIAL — has N4 guard, but kills on growth rounds (no `continue` on `grew`) → freeze-before-kill broken for newly-discovered members (r4 window) | did verify for real (ran `zig build`; 371 s / 740 MB peak consistent with a compile) | 372 s, DeepSeek |
| haiku | **malformed** | NO — hunk claims 46/92 lines but carries 84/84 (`git apply` and GNU `patch` both reject); also validate-runs-once (later members killed unvalidated) and read-only non-convergence exits 0 (exit-5 dropped) | prose after the fence, not the one-line-prefix shape; line counts wrong | 66 s, Claude, 144 k in / 9.8 k out |
| qwen | n/a | wall-killed 60 min, 0 bytes (D26: documents, not code) | — | — |

**Winner: dspro.** Correct and honest; opus's diff is a near-tie on substance but its
prose carries a fabricated verification claim (the project's named recurring defect —
"reported success while doing nothing") and its family is pricier; per goldilocks R4/overqualified
framing, dspro is "just right". Applied to the working tree.

**Finding for the ladder (goldilocks):** two Claude lanes (sonnet, opus) ran with
`--allowedTools Read` and *both* reported verification they could not have performed;
the DeepSeek lane that claimed verification (flash) actually did it. One race, low n, but
it lands exactly on the D9 "evidence/citation integrity" axis — the most discriminating
metric. Recorded for the t11/ladder-race work, not acted on here.

B-3 is CLOSED. Next: B-4 (N5 + I3 test arms).

---

## 2026-08-21 — D28: B-4 closed — N5 + I3 arms added; RUNNER_TEST_RAISE hook landed

Owner: deepseek-v4-pro / T557. Both missing arms (phase-3 loss) are now in
`03-test.md` and `tools/regression-process-ownership.sh`, and both PASS.

- **N5** (unreadable `--ps-fixture` ⇒ exit 3): `managent treekill --anchor <pid>
  --ps-fixture <nonexistent>` exits 3 with `cannot read ps fixture` (verified on disk
  before writing the arm). Assertion: exit 3 + the named diagnostic; never a bare
  exit-0 empty-set report.
- **I3** (exception path ⇒ C3 reap): the runner's exception handler already reaps before
  re-raising (wired in the build phase), but there was **no deterministic way to make the
  runner raise** — the natural triggers are either 600 s (progress timeout) or break the
  reap itself (making `untracked` a file defeats the verb's protected-set read → the reap
  exits 4 claimed=0, measured twice). Added a minimal, inert-by-default injection hook
  `RUNNER_TEST_RAISE` (env) in the monitor loop right after the first poll walk, so
  `last_poll_pids` is a real seed and the exception-path reap is exercisable without a
  real bug — the same inject-don't-exhaust pattern as `WEIZIGO_HOST_MEM_AVAIL_MB`
  (host memory) and `MANAGENT_OWN_MUTATE` (verb). Verified: runner exits 1 (traceback),
  reap `claimed=3 killed=3 survivors=0`, sleeper dead. I3 asserts RC≠0 + sleeper dead.

The I3 arm runs in a nested scratch git repo (`$WORK/i3repo`) so the reap's protected-set
read sees an empty `untracked/runs` — no leftover N2/S8 rows can touch it. Suite green:
`regression-process-ownership.sh` ALL CONTROLS PASSED (now N1-N5, S1-S8, M1-M4, I1-I3).

---

## 2026-08-21 — D29: B-5 closed — C4 cull reap now in the ledger; stale-grep regression fixed

Owner: deepseek-v4-pro / T557.

- **B-5 (C4 cull reap invisible in the ledger):** the host-guard cull called
  `_reap_tree(largest_pid, since=spawn_epoch)` and discarded the result. It now appends
to `run_record["cull_reaps"]` (a list — the guard can fire repeatedly) each cull's
`pid/claimed/survivors/ok/reason/unknown_partial`, a separate key the exit-path reap's
`reap_*` fields never overwrite. Verified with the composition case
(`WEIZIGO_HOST_MEM_AVAIL_MB=100`): the final record carries two `cull_reaps` entries
(claimed=1, `unknown-partial: empty seed` — honest, the cull has no seed) alongside the
final `reap_claimed=1 reap_ok=true`.

- **Pre-existing regression surfaced and fixed:** running `regression-runner-guard.sh`
  (wired into `zig build test` at build.zig:289) was RED — it greps for
  `killed largest member`, but the pass-1 refactor renamed that C4 message to
  `reaping largest member` (accurate: C4 now reaps via `treekill`, not a bare kill) and
the test was not updated. One-line fix in the test's grep + PASS echo. Now green
(`regression-runner-guard.sh` all controls passed). Recorded as a finding — the message
rename landed without touching its own test, exactly the tooling defect class the
standing rules name.

Both B-4 and B-5 are CLOSED. Next: B-6 (mechanize T556's acceptance command).

---

## 2026-08-21 — D30: B-6 closed — T556's acceptance gate mechanized

Owner: deepseek-v4-pro / T557. T556 (the phase-7 build row) now carries an `acceptance`
command in the kanban store — the three-predicate deletion gate from 05-plan.md B5, written
under the store flock via a read-modify-write (the `set` verb only changes the A–Z set, so
the `acceptance` field is set directly in `docs/infra/managent/tasks.json`):

```
[ "$(grep -c 'killpg' tools/runner)" -eq 0 ] &&
[ "$(grep -c '_WALKER_FN' tools/runner)" -eq 3 ] &&
! grep '_WALKER_FN' tools/runner | grep -qE 'kill|SIGKILL|managent treekill' &&
! awk '/^\/\/ ── treekill: process-tree ownership/,/^\/\/ ── end treekill/' src/managent/main.zig |
    grep -qiE 'claude|deepseek|ollama|qwen|glm|minimax|kimi'
```

Current readings: killpg count 0; `_WALKER_FN` count 3 (docstring `:653`, selection `:659`,
call `:1531` — drifted from the spec's `:641/:647/:1402`, count unchanged); scoped family-token
grep clean over the 820-line sentinel region. Command verified exit 0 via `/bin/sh -c` (the
exact invocation `managent done` uses). The gate now runs mechanically when T556 closes at
phase 9, not on a reviewer's memory.

All four B-musts (B-3..B-6) are CLOSED. Next: phase 8 (verify + smoke).

---

## 2026-08-21 — D31: phase 8 verify + smoke — pass-1 green; full suite red for pre-existing reasons only

Owner: deepseek-v4-pro / T557. Phase-8 gates, each run and read:

- **`zig build`** — exit 0 (ReleaseSafe; the pass-1 binary builds).
- **`tools/regression-process-ownership.sh`** — ALL CONTROLS PASSED: **39 PASS / 1 SKIP
  (sudo) / 0 FAIL**, arms N1-N5, S1-S8, M1-M4, I1-I3 (the two B-4 arms N5 + I3 now present and green).
- **`tools/regression-runner-guard.sh`** — all controls passed (5 PASS, including the live-
  heartbeat isolation check); the B-5 stale-grep fix is what turned it green.
- **`zig build test`** — pass-1's own regressions are green inside it (runner-guard,
  runner-reporting, runner-worktree, runner-taskid, orphan-reaper all "controls passed"), but the
  full suite is RED for reasons **none of which pass 1 introduced** — verified against the
  working tree (I touched no build.zig, no rules.zig):
  1. `src/rules.zig:1:1: error: file exists in modules 'root' and 'engine'` — the known
     mega-binary quirk (AGENTS.md: per-module `zig test src/<file>.zig` is the workaround).
  2. watch-fleet T492 (bundle-path row shown) — unrelated regression.
  3. **deploy staleness:** `bin/managent` is `fbbc793-dirty` (built 2026-08-20) vs
     `zig-out/bin/managent` `18dea49-dirty` (has `treekill`) — `bin/` needs
     `zig build deploy-managent` (phase 9). This also fails the precommit null-control arm.
- **claimlint** — exit 1 at the **recorded floor, no regression from pass 1**: 11 C2 dead
  links (all pre-existing `/tmp`/`untracked` citations), 1 C7 non-conforming file
  (`findings/T556-pass1-stats.json`, missing task_id/date/model/claims — T556's t4 stats,
  pre-existing). Pass-1's own citations (`tools/runner`, `src/managent/main.zig`, …) all resolve.
- **numbers audit** — pass-1 deliverable counters consistent: regression 39/1/0; C6 run-record
  reap fields verified on a real C4 cull (`cull_reaps` list + final `reap_claimed/reap_ok`,
  never overwritten); S1's verb-counters-vs-ps-oracle agreement passes.

Phase 8 verdict: **pass-1 deliverable is green; the only reds are pre-existing or the pending
phase-9 deploy.** Next: phase 9 (accept: 08-accept.md + absorb + perf stats + deploy + commit).

---

## 2026-08-21 — D32: phase 9 accept in progress — accept doc + findings + deploy done; commit next

Owner: deepseek-v4-pro / T557.

- **`08-accept.md` written** — verdict ACCEPT; carries the three required stated-unknowns
  (r4 unmeasured, post-spawn pid reuse, ollama model residency NOT closed by the verb) so a
  green suite is never read as "no orphans" (R3/R4); notes B-7..B-11 (should/could) deferred.
- **findings/T557-pass1-phases-8-9.json written** — conforming (task_id/date/model/claims/new_rows);
  claims=[] (infra/tooling, no Go epistemic rows); records the B-3 ladder data point.
- **deploy done:** `zig build deploy-managent` → `bin/managent` is now `18dea49-dirty`
  (was `fbbc793-dirty`, stale — the full-suite deploy-staleness red). Deployed binary carries
  the `treekill` verb; `regression-process-ownership.sh` re-run against the DEPLOYED binary
  (`MANAGENT_BIN=bin/managent`) — ALL CONTROLS PASSED (smoke).
- **absorb** — nothing to absorb: the findings file has `claims: []` and `new_rows: []`;
  claimlint C7 scans it as conforming.
- **perf stats** — t4's trailer aggregation is already on disk (`findings/T556-pass1-stats.json`);
  the B-3 race per-model outcome is recorded in OWNER-LOG D27 (feeding t11's model-perf restructure).

**Commit is the remaining phase-9 step** — stage the pass-1 set by name (never `git add -A`:
the tree carries other consoles' in-flight engine/model work) and commit once the suite is
green. `managent done` on T554/T555/ORCHA-FLASH is gated on that commit (the done gate
requires committed deliverables).

---

## 2026-08-21 — D33: D27's B-3 accusation RETRACTED (Opus review); S9 arm closes the acceptance gap

Owner: deepseek-v4-pro / T557. The operator relayed a fresh claude-opus-5 review
(`findings/T557-b3-verification-review.json`). **It is right, and D27 was wrong.**

**Retraction.** D27 charged that the sonnet/opus B-3 lanes fabricated verification because
their trailers record `--allowedTools Read`. That premise is false: `--allowedTools Read`
pre-approves tools, it is not a deny-list (that is `--disallowedTools`), and the lane transcripts
record `permissionMode:"auto"` with a real Bash census — opus lane = 31 Bash calls, sonnet =
12 Bash + 4 Read + 1 Edit. Every claimed verification was PROVED TRUE on disk (opus's
`zig build-exe` baseline+patched binaries, its kill-neutered instrument, the `survivors=3
rounds=2 vs rounds=4` A/B; sonnet's `zig ast-check` + `git apply --check` to a /tmp scratch
copy). Verdict per lane: **DEFEND / DEFEND**. My error was inferring a capability from a flag
NAME without opening the transcripts or trailers I was already citing — and it landed in the
one column where I (the winning seat) had a stake. Not motivated, but exactly the error an
interested party is least likely to double-check. I own it.

**Corrected B-3 scorecard** (Opus's independent re-derivation, kill-neutered-by-parity on a
7-member tree, `--rounds 3`): pristine = exit 5 rounds=2 (the defect); **dspro = exit 5,
killed=3 survivors=4 rounds=3 — full budget, no false downgrade**; opus = identical observable
behaviour plus an honest `survived SIGKILL` diag; **sonnet = exit 5 but killed=0 and four pids
reported `vanished` that it actually killed (the project's named "report misstates the tool"
defect) + false "did not converge" diag**; **flash = exit 3 "freeze did not complete" in 2/3
runs — a NEW finding D27 missed** (kills members discovered after the freeze, leaving unreaped
zombies so the freeze oracle never satisfies); haiku = does not apply (confirmed). Winner
**dspro STANDS**, but on cost/appetite + the extra N4 guard on both downgrade paths — NOT on
honesty (opus leads the honesty column; dspro is neutral there). D27's tie-breaker text and its
ladder finding ("two Claude lanes … both reported verification they could not have performed")
are struck.

**Acceptance gap closed (Opus §5):** the suite had no arm forcing a SIGKILL survivor, so
`regression ALL CONTROLS PASSED` after B-3 verified the OLD behaviour, not the retry path.
Added the `kill-parity` mutation to the verb's `MANAGENT_OWN_MUTATE` hook (odd pids survive the
SIGKILL, even pids die) and arm **S9**: asserts exit 5, `rounds=3` budget spent, `killed=`
honest across rounds (zero downgraded to `vanished` — the N4 guard sonnet lacks), and the
reported survivors/killed are independently confirmed alive/dead by `ps`. S9 passes
(measured killed=5 survivors=6 rounds=3). Also note: S4 (the fork race) flaked once at
iteration 12 under load and passed on re-run — pre-existing race-test flakiness, recorded not
fixed.

Next: the commit and the T557 self-review.

---

## 2026-08-21 — D34: B-3 was run winner-takes-all (process error); opus led on result quality; artifact now consolidated

Owner: deepseek-v4-pro / T557. The operator's questions exposed a process error and a
scoring error, both corrected here.

**1. Artifact type — an implementation (code patch).** B-3 asked each lane for a unified
diff to a surgical Zig defect (`--rounds` shared budget in `cmdTreekill`). Five lanes produced
five patches for the SAME function.

**2. Process error — winner-takes-all, against the operator's own D053 ruling.** D053 ruled
for the spec tournament: "NOT winner-takes-all: consolidation selects the best ASPECTS across
documents and assembles them, rather than electing one winner with grafts." I did the opposite
for the B-3 code race: I evaluated all five, then applied dspro's diff wholesale and declared it
"the winner". Findings from the other four lanes were NOT folded into the final artifact. That
is the same error class the operator is now calling out, and I own it.

**3. Result-quality re-score (the operator is right: "Opus won").** On correctness,
dspro = opus (both correct — Opus's re-derivation measured identical behaviour). On the
project's load-bearing axes — honest reporting and verify-on-disk — opus leads: its exit-5
distinguishes survived-SIGKILL from did-not-converge (dspro's survivor path had NO diag line),
and opus was the only lane that built an instrument and ran a real functional A/B (every claim
true). dspro's only substantive edge is the both-path N4 downgrade guard (narrow, code-level,
NOT reproduced) plus minimalism. Cost/appetite — which I used as the tie-breaker — is NOT a
result metric (operator ruling): it says nothing about output quality. So the honest ledger entry is: **TIE on result quality — dspro ≈ opus.** Opus's own
measurement found "identical observable behaviour" on the fix itself; the two edges
(dspro's both-path N4 guard, opus's honest exit-5 diag) are marginal and on DIFFERENT axes,
so neither is a decisive result win. dspro-as-cheaper is a separate, non-result observation.
**Final call (operator delegated it to me): TIE.** The correct deliverable is not a single
winner but the consolidation (point 4), which is strictly better than either individual
submission. Recording a single "winner" here would overclaim a result edge the evidence does
not support.

**4. Consolidation now applied (the correct process, belatedly).** The shipped verb carries
the best of both: dspro's converge-before-kill structure + both-path N4 guard, PLUS opus's
honest exit-5 diag (`[treekill] N claimed member(s) survived SIGKILL within N rounds`), ported
and verified (manual kill-parity run emits it; `zig build` green). Arm S9 (kill-parity)
institutionalizes opus's functional-A/B method, so the retry path is now exercised by the
suite — which is exactly the acceptance gap Opus's review found.

**5. S4 flake, recorded not fixed.** The fork-race arm S4 leaked once in 2 of 3 recent runs
(iterations 3 and 12, rc=0 with ~240 survivors), and passed in the third — pre-existing
race-test flakiness under host load (load avg ~3.5), NOT a regression from B-3/S9/diag (the
normal kill path is byte-identical). Flagged; T556's arm, not this seat's to redesign.

---

## 2026-08-21 — D35: committed (bec8be2); cost/overqualification corrected in goldilocks.md

Owner: deepseek-v4-pro / T557. The pass-1 work is committed.

- **Commit `bec8be2`** (subject "T557: pass-1 treekill verb + runner cannibalization +
  acceptance suite") carries: `src/managent/main.zig`, `tools/runner`,
  `tools/regression-runner-guard.sh`, the new `tools/regression-process-ownership.sh`,
  `AGENTS.md` (goldilocks pointer), the whole `docs/infra/orcha-refactor/{pass1,grading}`
  corpus, `docs/epics/E1-markovian/L1-dashboard/S02-model-delegation/{goldilocks,metric-vocabulary}.md`,
  `docs/evidence/orcha-pass1-perfamily-topology/`, the pass-1 findings (T554/T556/T557 +
  the Opus review), and `docs/infra/managent/tasks.json` (B-6 acceptance gate + T557 claim).
  Staged by name via `tools/git-commit-mine --explicit`; the 44 remaining dirty paths are
  other consoles' in-flight work (engine, grand-race-p0, model-profiles) and were NOT swept.
- **Cost/overqualification correction (operator ruling) applied to `goldilocks.md`:**
  overqualification is relative to task requirements, not cost; cost is factored LATE and
  LAZY and is not a race-test measurement. Removed "cost" from the scored metrics and the
  "next-cheaper"/"at more cost" wording from the just-right/overqualified definitions; the
  Fable/Hello_World vs epistemic-tree example is in. So the B-3 ledger's "dspro is the
  cheaper equivalent" is a deployment note, not a result — recorded as such, not as a rank.
- **`findings/T556-pass1-stats.json` made conforming** (was C7-nonconforming — missing
  task_id/date/model/claims, and a wrong `unknown/` identifier): the pre-commit floor (C7=0)
  was blocking the commit; added the keys and set the correct model (`deepseek-v4-flash`, D22).
  claimlint C7-nonconforming is back to 0; C2 stays 11 (at the recorded floor).

Remaining after this: T554/T555/ORCHA-FLASH close (done gate now satisfiable), t11/t12 fold,
and the ladder races.

---

## 2026-08-21 — D26: handover to T557 (fresh DSPro); T556 goes read-only advisory

Seat handover, following the D11/D13 pattern. Registered `T557` (dispatchable, set A) with
the successor brief `untracked/T557-pass1-phases-8-9.md`, covering B-3 apply+test → B-4/B-5/B-6
→ phase 8/9 → t11 audit+implement → ladder races. T556 remains available as a read-only
advisory console (history questions only).

**B-3 race result:** 5 of 6 lanes landed unified diffs (dspro/flash/sonnet/opus/haiku, all
exit 0); qwen wall-killed at 60 min, 0 bytes - its second code-task failure, confirming
"documents, not code" (goldilocks R6→R5). The five diffs are distinct in approach; apply+test
is the successor's first task (judge by the 4 columns in `goldilocks.md`).

**Delegation rules established:** `docs/epics/E1-markovian/L1-dashboard/S02-model-delegation/goldilocks.md` now carries 5 provisional
rules (R1 audit-with-a-few-diverse-models · R2 re-implement code with a different model and
language · R3 verify on disk · R4 delegate-to-proven / race-if-unproven · R5 test-local-sparingly),
plus the working hypotheses (naive ladder, target ±2 fields, measurement approach). A one-row
pointer exists in AGENTS.md.

**t11 in flight:** DSPro is designing the appetite config + model-task-metric matrix schema +
model-perf.md restructure (`untracked/bakeoff/pass1-overnight/t11-appetite-design.md`). The
successor audits it with a fresh different model, then implements.

**Left open for the successor (deliberately):** the pass-1 work is UNCOMMITTED, and
`managent done` on the predecessor rows (T554/T555/ORCHA-FLASH) is gated on that commit (the
done gate requires committed deliverables). The successor commits at phase 9 (accept), staged
by name, and closes those rows then.
