# Pass 1 — SPEC: process ownership. Tournament brief (identical bytes to every lane)

You are writing a **spec** for pass 1 of the orchestration refactor. Seven models receive
this exact brief — same inputs, independent outputs. Write the best spec you can; do not
write code, and do not write the plan or the design.

**This is not winner-takes-all.** Your spec is anonymized and read by every other lane.
Consolidation then selects the best **aspects** across all seven documents — a section,
an argument, a test idea, a safety guard — and assembles them. So a spec that is weak
overall but contains one excellent section still contributes, and a polished spec with
nothing distinctive may contribute little. **Write to be quarried, not just to win:** make
each section strong and separable, and say plainly which part of your spec you think is
its best contribution.

All outputs then become inputs to a further independent round, so expect to see the other
six and be asked to revise. You are being evaluated to learn what models are good at,
not to crown a champion. No dimension schema is imposed: expect a coarse grade plus a
sentence of nuance. What is worth measuring will be discovered from the results, not
decided in advance.

## The problem, measured

The fleet dispatches AI workers. Each worker can run the project's test suite, which
compiles to a ~3 GB binary. On 2026-08-20 the host repeatedly ran out of memory, a guard
culled 12 workers, and those culls were recorded as *model failures* — corrupting the
model-performance ledger the project exists to build.

Root cause, measured, not assumed:

- `bin/dispatch:301` detaches every worker with `start_new_session=True` and returns
  immediately. Ownership of the worker is **severed at spawn by design**.
- `tools/runner:1161` does the right thing within its reach: `os.setsid()` on its
  child, then `os.killpg` — but only on its ceiling-kill path (`tools/runner:1505`).
  The host guard SIGKILLs one pid (`tools/runner:1432`), and the normal-exit path
  reaps nothing. So even a fully working group kill would leave the normal-exit and
  runner-death leaks untouched.
- It still leaks, and not because of zig. Zig 0.16's stdlib never creates a process
  group or session for build children (`std/process.zig:397` — `SpawnOptions.pgid`
  defaults null; no `setsid`/`setpgid` anywhere in the build path). Measured on the
  production chain 2026-08-20: the **console harness starts every tool command in a new
  session** (command shell pgid == sid == own pid, distinct from the console's session).
  `killpg` aimed at the console therefore misses every tool-command tree; the trees
  reparent to init holding gigabytes. Because the escapees are **session leaders**, no
  group- or session-level kill can reach them — only descendant enumeration can.
- Observed four times in one day: 6 orphans, then ~4.5 GB, then **9.1 GB** (free memory
  0.06 GB, swap 2.9/4 GB), then 2.8 GB recurring **while free memory was a healthy
  25–27 GB** — so the leak is continuous, not crisis-driven.
- macOS has no cgroups. There is no kernel-level "kill everything below this pid".

There is already a `tools/regression-orphan-reaper.sh` (from T364) with seven null and
seeded controls, and it passes. It tests **kanban** orphans — a task *row* whose worker
died. It has nothing to do with **process** orphans. One word, two meanings, and the
gap hid for months. Assume nothing from names.

## What you are specifying

A `managent` verb (or verbs) in **Zig**, inside the existing 8,780-line binary, that
**owns** a process tree rather than inferring it: given a spawned child, be able to
enumerate and reliably terminate every descendant, on every exit path.

`managent` is today a short-lived CLI. Pass 1 does **not** make it a daemon; it adds a
verb the existing Python `tools/runner` will call in place of its `killpg`.

## What your spec must contain

1. **What "owned" means, testably.** Not "robust" — a condition a control can assert.
2. **The verb's contract**: name, arguments, exit codes, output shape (data on stdout,
   diagnostics on stderr, per this project's convention), and behaviour when the target
   is already dead, is not ours, or is pid 1.
3. **The measured escape mechanism, and its residue.** The mechanism is measured
   (2026-08-20, this repo, production chain): the Claude console harness starts each
   tool command in a **new session**; zig creates none. Two consequences your spec must
   build on rather than re-derive: (i) escapees are session leaders, so group- and
   session-level kills are structurally insufficient — the verb must enumerate and
   signal the descendant tree, and must handle the race where a dying parent reparents
   children to init mid-walk; (ii) the mechanism is per-console-family — the
   measurement covers `claude -p`; specify the one-command check (`ps -o pid,ppid,pgid`
   plus `getsid`, macOS `ps -o sess` prints 0) that must be run once per other console
   family (DeepSeek CLI, ollama-subagent) before the seeded controls are finalized.
4. **Safety.** This verb kills processes on a live machine. Specify the guards that stop
   it killing live work, and say what must never be killable. The seat ran an *untested*
   reaper on 2026-08-20 with three hand-reasoned guards — do not repeat that; specify the
   guards and their controls.
5. **The controls, named but not written.** Which null and seeded arms prove it. At
   minimum: a deep tree that escapes by whichever mechanism the experiment finds, and a
   live tree that must survive untouched. Tests come before implementation here.
6. **The cannibalization step.** Which line of which file stops doing this work and
   starts calling the verb. A pass is not done when the verb exists — only when the old
   code path is deleted. Specifically: the verb replaces the `killpg` call site
   (`tools/runner:1505`) **and is also called on the normal-exit path**, which currently
   reaps nothing. The runner-death case (a SIGKILLed runner reaps nothing) is a stated
   **non-goal** for pass 1 — that is `T548`'s sweep, and later the supervisor's held
   handles.

7. **One dispatch interface for every harness** (operator requirement, 2026-08-20):
   *"Pi harness and Claude Code should both dispatch to model via the exact same
   script/command, and the command should work out the details, flags, model to harness
   pair, pid, child ps, tokens, etc. Shallow common interface hides deep functionality."*
   Today there are two dispatchers and per-family branching. Your spec need not build
   that interface — it is a later pass — but it must state how the ownership verb is
   shaped so it serves **all** console families behind one command rather than needing a
   variant per family. A design that only works for `claude -p` is a design that must be
   rewritten next pass.
8. **Explicit non-goals.** What pass 1 does not do. Note that the supervisor rewrite,
   the state consolidation and the dashboards are later passes; and that **no new
   supervisory process may be introduced** — the fix is that the mechanism works, not
   that something watches it fail.

## Constraints

- **Cite evidence by path and line.** Every factual claim must be checkable by the file
  or command you name. Unverifiable assertions are gradeable defects.
- **State your uncertainties.** An honest open question survives audit; a confident
  guess does not.
- Prefer *fewer moving parts*. The operator's standing constraint: "I do not want
  utility or tool proliferation. I want reuse, testability, predictability,
  transparency, stability, agility, performance, separation of concerns."
- If you conclude pass 1 is scoped wrongly — too big, too small, or the wrong first
  bite — say so and argue it. That is a finding, not a failure.
- Length is not a virtue. A shorter spec that is complete and checkable beats a long one.

## How you will be judged

Anonymized, then graded by the other lanes. Grading runs under
`docs/epics/E1-markovian/L1-dashboard/S02-model-delegation/grand-race.md` §5 and gates G3/G4 — that document governs the protocol,
including its grader null/seeded controls and its recorded consequence that on the
2026-08-20b roster a Claude-authored spec receives only three countable grades while the
qwen spec receives six, so panel-only Claude-vs-Claude orderings are low-confidence.

The criteria are: testability of its requirements; correctness and citation of its
evidence; quality of the safety specification; whether it builds correctly on the measured
escape mechanism and specifies the per-family residual check; and economy.

Do not name yourself.

Consolidation and the final ruling belong to `claude-fable-5` as the operator's designated
authority (`docs/infra/delegation/ROLES.md`, "Adjudication authority"), acting as a
**separate fresh instance** on anonymized inputs. Its job is to select aspects across the
seven and make the assembled result internally coherent; committee chooses the parts, one
hand makes them agree. That Fable both authors a lane and holds final authority is a
recorded footnote, not a blocker (operator ruling, 2026-08-20): Fable is being used as the
**benchmark** against which other models are compared, and it would be a welcome finding
if another lane surpassed it.

## Deliverable

One markdown document. Nothing else — no code, no tests, no tooling.
