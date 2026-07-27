# Subagent — single-task dispatch protocol

**For agents receiving a one-line prompt.** Read this, then read your
bundle file. Do not read PROGRESS.md, HANDOVER.md, or any other project
file unless your bundle explicitly tells you to.

## Bundle file format

A bundle file lives in `untracked/`. The first instruction is always
the same:

```markdown
<!--managent set=A context=500k-->
# Short task title

**Status:** open

Before starting, read `docs/infra/subagent.md`.

What to do. Clear instructions. Specific commands to run.
Expected outputs. Where to write results.

When done, update **Status:** to `done` (or `failed`) and write a
summary of what happened here.
```

The HTML comment at the top is metadata for the `managent` tool. Ignore it.

## Protocol

### 1. Read the bundle file

The prompt tells you which file to follow. Read it completely before
doing anything.

### 2. Check status

If `**Status:**` is already `done` or `failed`, the task already ran.
Read the results, then decide:
- Results look complete → report "already done" and stop.
- Results are partial or wrong → note what's missing, update status to
  `open`, and continue.
- Task is designed to be re-run (e.g. verification) → continue.

### 3. Do the work

Follow the instructions. Write findings, commands, and results into the
bundle file. Keep the file self-contained — a fresh reader should
understand what happened without reading anything else.

### 4. Report completion

Update `**Status:**` to `done` or `failed`. Write a summary at the top
of the file. Stop.

Do NOT call `managent`. Do NOT close or update any other file. The Boss
will verify your results and close the task.

## Rules

- **The bundle file is the complete specification.** Do not read
  PROGRESS.md, HANDOVER.md, or CURRENT.md unless your bundle
  explicitly tells you to.
- **Write results to the bundle file.** Do not create new files unless
  instructed. Do not write to `docs/`, `data/`, or `artifacts/`.
- **No engine edits unless the bundle says `holds=src/...`.** If the
  metadata comment lists `holds=`, you have exclusive write access to
  those files. Otherwise, read-only.
- **Report honestly.** If you can't complete the task, say why. Update
  status to `failed` with an explanation.
