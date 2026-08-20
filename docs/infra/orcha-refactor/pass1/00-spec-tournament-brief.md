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
- `tools/runner:1161` does the right thing within its reach: `os.setsid()` on its child,
  then `os.killpg(proc.pid, SIGKILL)` at every exit path.
- It still leaks. **`killpg` covers exactly one process group.** When the worker runs
  `zig build`, the build's descendants create their own groups, so they survive the kill
  and are reparented to init, holding gigabytes.
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
3. **The open technical question, and how to settle it.** Do `zig build`'s descendants
   escape via a new *session* or merely a new *process group*? **This is unknown.** A
   spec that specifies the experiment to answer it is doing the right thing; a spec that
   asserts an answer without evidence is guessing, and graders are told to mark that
   down. State what the experiment is and what each outcome would imply for the design.
4. **Safety.** This verb kills processes on a live machine. Specify the guards that stop
   it killing live work, and say what must never be killable. The seat ran an *untested*
   reaper on 2026-08-20 with three hand-reasoned guards — do not repeat that; specify the
   guards and their controls.
5. **The controls, named but not written.** Which null and seeded arms prove it. At
   minimum: a deep tree that escapes by whichever mechanism the experiment finds, and a
   live tree that must survive untouched. Tests come before implementation here.
6. **The cannibalization step.** Which line of which file stops doing this work and
   starts calling the verb. A pass is not done when the verb exists — only when the old
   code path is deleted.
7. **Explicit non-goals.** What pass 1 does not do. Note that the supervisor rewrite,
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

Anonymized, then graded by the other lanes on: testability of its requirements,
correctness and citation of its evidence, quality of the safety specification, whether
it correctly treats the session-vs-process-group question as open, and economy. Grades
where grader family equals author family are refused at counting (`G3`). Self-identifying
text is flagged, not scrubbed (`G4`) — do not name yourself.

Consolidation and the final ruling belong to `claude-fable-5` as the operator's
designated authority (`docs/infra/delegation/ROLES.md`, "Adjudication authority"), acting
as a **separate fresh instance** on anonymized inputs — so a Fable-authored spec in this
pool is judged by a Fable that has never seen it. Its job is to select aspects across the
seven and then make the assembled result internally coherent; committee chooses the
parts, one hand makes them agree.

## Deliverable

One markdown document. Nothing else — no code, no tests, no tooling.
