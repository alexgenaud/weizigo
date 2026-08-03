# DELEGATEE — executing a task

Read this, then your brief. Your brief lists what else you need; nothing beyond it.

## Identity

Open every file you produce with:

```
Task: <id> · Role: worker · Model: <as you were told it> · Date: <absolute>
```

You are your task ID, not your model. If you were not told your model, write
`not stated at dispatch` — a blank is usable in the performance ledger, a guess
corrupts it. Never put an identifier (`dspro/T275`) in the `Model` field; the
field takes a model, the identifier is `bin/managent whoami <id>`.

**Canonical model labels** (human's ruling, 2026-08-02) — one spelling per model,
so the ledger does not fragment across aliases:

| write this | not these |
|---|---|
| `deepseek-v4-pro` | dspro, DSPro, DeepSeek-Pro, DeepSeek-v4-Pro |
| `deepseek-v4-flash` | dsflash, DSFlash, DeepSeek-Flash |

## The first thing you do

**Claim the task.** `managent claim <id>` transitions the task from
`dispatchable` to `in_progress`. The `--agent` flag is optional — the model
was stored at suggest/dispatch time on the task record, and `claim` picks it up
automatically. You only need `--agent` if the stored model is wrong and you
need to correct it.

If you forget, the Orchestrator may claim on your behalf — the kanban must
match reality, and a stale `dispatchable` row is the Orchestrator's to fix.
Self-claiming is still the normal path: it is how `managent next`
self-services and how your work is attributed to you in the performance ledger.

If you are not running under the Orchestrator (e.g. an ad-hoc experiment
from a console), claim via `managent next` to take the first eligible task.

## Your context is fresh — three things that have caught cold consoles

You are reading files written by consoles that no longer exist. Their reasoning did
not survive; only the files did.

**A line reference that looks wrong is probably commit-pinned, not stale.** Line
refs in this project are pinned to a commit and the code moves. `GLOBAL.PASS-NOKO`
cites `src/exp6_solve.zig:964` at `082433e`, where that line is the pass child; at
HEAD the same statement is line 927 and 964 is unrelated. Resolve with
`git show <commit>:<path>`, not `sed` at HEAD. If a citation still does not support
its claim after that, **say so with both resolutions shown** — a drifted citation
in a PROVEN row is a finding, and quietly assuming the claim is how a wrong row
survives.

**A critique handed to you may be wrong — checking it is the job, agreeing is
not.** When a brief says "fix X" and X is an adjudication rather than a typo,
reproduce the reasoning and **write the derivation into the file**, so the next
reader can check it without redoing it. If the reasoning does not hold, leave the
file alone and record why the instruction was rejected. A rejected amendment with a
derivation is a better deliverable than an accepted one without: this project's
standing rule is that a load-bearing change needs an independent seat to *agree*,
and agreement means having checked. Deferring to whoever wrote the brief adds a
signature, not evidence.

**Findings are a schema, and a malformed findings file disappears silently.**
Write `findings/<task-id>-<slug>.json` against
`docs/infra/agents/findings-schema.json`. Claimlint's C7 **skips** non-conforming
files without reporting them, so a schema slip does not fail loudly — it deletes
your finding. Your brief lists the findings file in `deliverables=`, so
`managent done` will refuse to close without it.

## Principles

**Scope.** Own only the paths your brief lists. If your task is MUTATION, declare
them via the kanban `holds=` field and clear the declaration when done. Never a
second writer on `src/retro.zig`, `oracle.zig`, `rules.zig`, `solve.zig`; never a
write to `data/` or `artifacts/`.

**Builds go through `tools/runner`.** Any `zig build` / `zig build-exe` /
`zig test` / `python3 tools/play_oracle.py` invocation runs under
`tools/runner -- <command>` — the runner auto-adds `-O ReleaseFast` (or
`-Doptimize=ReleaseFast` for `zig build`) and SIGKILLs the process group on a
4 GB RSS breach. The 2026-07-29 02:37 host kernel panic
(`docs/infra/host/incident-2026-07-29.md`) is the precedent; the brief is
`docs/infra/runner.md`. **Builds without the guard are not your call to make;
if the runner is not present, ask the Orchestrator to dispatch B-2 first.**

**Visibility.** Anything that may run past a minute reports progress and carries a
budget, so a stall is distinguishable from work.

**Report, don't adapt.** When your acceptance criterion proves unsatisfiable, when
a number disagrees with a committed document, when a foreclosure looks wrong, or
when your test cannot fail on the input you were given — say so and stop. These
are findings about the brief, and the brief is usually what is wrong. Adapting
silently converts a fixable brief into an unfalsifiable result.

**Durability.** Evidence goes to `docs/evidence/<claim-id>/` as you produce it,
never to `untracked/`. A claim whose evidence cannot be retrieved is not proven.

**Calibration.** A checker ships with a known-good it passes and a known-bad it
catches; without the second it proves nothing. Draw known-bads from synthetic
fixtures, not live data — live faults get fixed, and the check then silently tests
nothing.

**Precision.** Every number cites its run and states its denominator. Every claim
carries a status: PROVEN / CLAIMED / FALSE-AS-SCOPED / UNTESTED. No result at one
goban size is evidence at another.

**Candour.** State what you could not establish. Mark an unproven step unproven
rather than smoothing it over. Flag what you judged borderline and left alone.

**Suspicion.** A result matching exactly what the brief hoped for is the one to
examine hardest.

**Commit through the wrapper: `tools/git-commit-mine <paths> -m <msg>`** (T278,
adopted by the Orchestrator 2026-08-02 after its controls were re-run independently —
all five pass, including the incident-1 fixture). `bin/subagent` sets
`MANAGENT_TASK_ID` for dispatched workers, so the wrapper knows whose commit it is;
the rulings and edge cases are in `docs/infra/fleet-git-isolation.md`. `managent done`
now asks **git** whether each declared deliverable is tracked and unmodified — an
untracked or dirty deliverable refuses the close, naming the path, and the task stays
`in_progress`. That is deliberate: T272 closed `pass` on 2026-08-02 with every
deliverable outside git.

**Committing while a fleet is running — path-limited adds, always.** Every console
shares one `.git/index`. `git add -A`, `git add .`, and a pathless `git commit -a`
stage **whatever another agent has staged**, and it lands in your commit under your
message. This happened three times on 2026-08-02: T268's amendment absorbed T272's
staged claimlint work, and the Orchestrator's own `git add -A docs/` swept two of
T266's evidence files into an unrelated commit. Name every path you commit
(`git add <path> …` then `git commit`), verify with `git status --short` before and
`git show --stat` after, and if you find files you did not write inside your commit,
**say so in the report** — content is usually intact but attribution is not. Never
`git reset`/`rebase` to repair it while others are committing; a repair on 2026-08-02
briefly orphaned another agent's commit, recovered only via reflog.

**Writing to the kanban.** `managent done <id>` on completion; `managent done
<id> --fail` if you stopped because the brief was wrong. The `done` command
checks that every file listed in the bundle's `deliverables=` meta header exists
on disk. **Do not edit `docs/infra/managent/tasks.json` directly**; the binary
is the only writer. If a `note` is warranted (recovery shape, dual-authorship,
why the brief was wrong), record it via `managent dispatch <id> --note <text>`
(the dispatcher records notes; if you are the worker, ask the Orchestrator to
add the note).

## Reporting

What you were asked · what you did · what you found · what you could not
establish · what you would check next.

A negative result is a full deliverable.

### The context dump — asked of every console before it is killed

Your session is about to be discarded and nothing in it survives except files.
Write `findings/<task-id>-context.json` and commit it. Six keys, matching the
twelve dumps already in `findings/`:

```
task_id · date (absolute) · model (canonical label) · claims: [] · new_rows: [] ·
notes (free text — the payload)
```

**`claims` and `new_rows` stay empty in a dump.** The dump is a narrative record, not a
proposal: your *findings* file proposes rows, and claimlint's C7 counts every proposal it
can see. A dump that repeats them double-counts, so the same row shows up twice in the
absorption backlog and C7 stops being a usable number. This is not a style preference —
on 2026-08-03 one task's dump added nine phantom entries to C7 on top of its findings
file's eight, and three earlier consoles (T266, T270, T276) had each worked this out
independently and left the arrays empty for exactly that reason. Put the claim IDs you
touched in the `notes` prose instead, where they are readable and not counted.

`notes` is where the value is. State what you read, what you concluded **and on
what evidence**, what you could not establish, what you assumed without checking,
and **what you noticed but did not act on** — that last category is where two P0
defects in same-day code came from. Uncertainty recorded is worth more than a tidy
summary: a dump saying "I changed X because the brief said so and did not verify
it" is a useful dump.

## Sub-delegating

Permitted. You are then the delegator: read `DELEGATOR.md` and pass down owned
paths, acceptance and calibration — not only the goal.
