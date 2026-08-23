# Resume surface — compose at read time, never store

```
Task: T286 · Role: worker · Model: deepseek-v4-flash · Date: 2026-08-03
Status: RATIFIED by the human's ruling of 2026-08-03 (choose the more robust pattern)
Implements: GRAND-AUDIT prescription 3 (the delete option), DIRECTION §4
Supersedes: docs/status/CURRENT.md (deleted 2026-08-03, commit <T286-commit>)
```

`docs/status/CURRENT.md` rotted faster than anyone maintained it: the Grand Audit
found it stale within 24 hours of the remediation aimed at it, and on
2026-08-02/03 the Orchestrator hand-refreshed it six times in one session — at one
point it contained a block saying the pre-commit gate was installed and a bullet
saying it was not, the same self-contradiction `GRAND-AUDIT.md` §1e found in
PROGRESS.md, in the file whose only job is to be read first.

The audit offered two options: *generate* CURRENT.md at shutdown, or *delete* it
and route cold-resume through the register. The human ruled 2026-08-03: **choose
the more robust pattern**. This document records that choice and its four design
decisions.

## The pattern

**A command that composes the resume surface on demand, from sources that cannot
be stale, and no stored copy at all.**

```
managent resume
```

The command reads, at invocation, from:

| source | what it contributes | can it be stale? |
|---|---|---|
| `docs/infra/managent/tasks.json` | the kanban — in_progress, dispatchable, blocked, held files | no — it *is* the kanban; the surface is a projection of it |
| `git log` | what landed (recent commits) | no — read at invocation from the repo |
| `bin/weizigo-claimlint` summary | gate counts (C1a/C1b/C2/C6) against the recorded floor (`tools/hooks/claimlint-floor.json`) | no — recomputed at invocation |
| `git config core.hooksPath` | is the pre-commit gate installed | no — read at invocation |
| `git status --porcelain` | is the tree clean | no — read at invocation |
| `untracked/msg/*/STATE.md` | the narrative headline, **by reference** | yes — it is prose (see §4) |

Nothing is cached, nothing is written. `managent resume` is a pure reader: it
never mutates `tasks.json`, never writes a file, never registers a task.

## 1. Where it lives — `managent resume`, argued

A `managent resume` subcommand is the obvious home, and the argument is short:

- **The kanban is already its primary source.** The binary that owns
  `tasks.json` is the natural reader of it; every console already invokes
  `bin/managent` at claim/done, so the surface costs zero new tooling to reach.
- **Deployed and stamped.** `managent` is built, deployed to `bin/` via the
  remove-copy-sign deploy (T268), and stamped with its build. A new shell script
  would be a second, unstamped surface with its own drift risk.
- **The pattern exists.** `managent standing` already shells out to claimlint and
  git from inside the binary (T227); `managent done` already asks git (T278).
  `resume` is the same shape: read sources, print.
- **One writer per surface.** The failure mode of CURRENT.md was that *many*
  seats hand-edited one file. A subcommand has exactly one writer: the binary.

Against: a POSIX shell script could compose the same sections with less compile
weight, and the Zig binary needs a rebuild for any change. But the project's own
evidence is decisive — GRAND-AUDIT §4: *"rules that stayed prose rotted; rules
that became code held."* The mechanized surface wins. Rebuild cost is
acceptable: `managent` is a single-file exe and `zig build` is the standing
entry point.

**Deployment note (T286):** while a fleet is live, the rebuilt binary is left in
`zig-out/bin/managent`; deploying to `bin/` is Orcha's call when the fleet drains
(D018). Until then, `managent resume` on a console that has not rebuilt will
report `unknown command` — the read-order table below says `bin/managent resume`,
and the deploy step is `zig build deploy-managent`.

## 2. What replaces CURRENT.md — one read-first chain

CURRENT.md is **deleted**. The audit counted three competing "read me first"
chains; there is now one:

```
managent resume          ← the composed surface: what is in flight, what landed,
                           gate status, where the narrative lives
docs/epistemic/PROGRESS.md  ← the durable hub (the living overview)
docs/epistemic/CLAIMS.md    ← the register (one owner — do not race it)
<role doc>                   ← who you are in this session
```

For a session resuming from the channel, the chain is:

```
untracked/msg/<epic>/STATE.md  ← crash-recovery anchor (read first)
managent resume                ← the composed surface
docs/epistemic/PROGRESS.md     ← the durable hub
```

Pointers fixed (T286, count reported in the findings file):

| path | what changed |
|---|---|
| `AGENTS.md:121-122` | both "resuming" rows now read `bin/managent resume` first |
| `AGENTS.md:64` | ownership declarations move to the kanban `holds=` field (the mechanical gate) |
| `docs/infra/roles/ORCHESTRATOR.md:49` | resume chain rewritten to `STATE.md` → `managent resume` → role docs |
| `docs/infra/roles/ORCHESTRATOR.md:21` | CURRENT.md dropped from the absorb list |
| `docs/infra/delegation/DELEGATEE.md` | MUTATION declarations now via `holds=` |
| `docs/infra/delegation/ROLES.md` | same |
| `docs/infra/roles/DABIR.md` | "current state" now `managent resume` |
| `docs/infra/agents/workflow.md` | in-flight state section rewritten |
| `docs/infra/dispatch/README.md` | ownership declarations now via the kanban |
| `docs/README.md`, `docs/INDEX.md`, `docs/about-this-document.md` | doc-tree descriptions |

Historical references (evidence docs, audit arm reports, dispatch briefs,
register rows) are **left intact** — they record what was true when written;
rewriting them would falsify the record. The sweep count (live vs historical) is
in `findings/T286-resume.json`.

`docs/status/HANDOVER.md` and the dated `handover-*.md` files are **kept**: they are
tactical session-continuity snapshots, distinct from the resume surface. The dated
ones record their sessions; the resume surface points at the durable hub
(`PROGRESS.md`) and the register (`CLAIMS.md`), not at a snapshot that can itself
go stale.

## 3. What genuinely cannot be derived — the narrative

Everything mechanical is derivable: the kanban, the commit list, the gate
counts, the hook install state, the tree dirt. **The narrative is not.** "Here is
what happened and why it matters" is human/agent prose, and the channel
`STATE.md` already holds it — that is its job ("Overwritten in place; always
current", channel.md).

So `managent resume` **includes the prose by reference, never by duplication**:
it prints the path of every `untracked/msg/*/STATE.md`, its last-updated line
and its first `## ` heading — enough to orient, and a hard pointer to the file
for the actual narrative. If the prose is stale, the stale line is printed *as
stale* (its own date), and the mechanical sections above it do not depend on it
at all.

## 4. A staleness impossibility argument — the honest residual

The surface is composed at invocation from sources that are the state itself:
`tasks.json` *is* the kanban, `git log`/`status`/`config` are the repo, claimlint
is the register's gate. There is no stored copy to drift, and no generation step
that can lag the state — composition and read are the same instant. The previous
failure mode (a file hand-refreshed at shutdown, stale by next morning) is
structurally gone: nothing is refreshed, because nothing is stored.

The residual, stated plainly:

- **STATE.md is prose and can be stale.** The command does not fix that; it
  prints the prose's own date so the reader can judge. An honest residual beats a
  claimed guarantee.
- **tasks.json can disagree with the real world** (a console alive but not
  claimed, or a claimed task whose console died). That is the kanban's known
  limit; `managent liveness` (heartbeats) and `managent audit` exist to
  cross-check it, and the resume surface does not pretend otherwise.
- **claimlint can be unbuilt** (fresh clone). The command says
  `claimlint: unavailable` — it does not invent counts.

A resume surface that lies is worse than one that is stale, because a cold agent
has no way to tell. The command therefore degrades loudly, and its regression
controls (`tools/regression-managent-resume.sh`, wired into `zig build test`)
assert the two load-bearing shapes: an empty kanban + clean tree **says**
NOTHING IN FLIGHT, and a task in progress with a held file shows **both** the
task and the file.

## 5. What the command deliberately does not do

- **Does not run `zig build test`.** The full suite is minutes of stratified
  sweeps; a resume surface that costs a suite-run to compose is not a resume
  surface. The gate section says "NOT RUN here — run `zig build test` yourself".
- **Does not write `_standing`-style metadata** (unlike `managent standing`,
  which persists trigger state). Resume is a pure reader by design.
- **Does not read or copy the body of STATE.md** beyond the headline.

## Retired in the same ruling — the `ephemeral/` indirection

The human's 2026-08-03 ruling also retired the `ephemeral` → `/tmp/weizigo`
symlink: `/tmp/weizigo` is the location for untracked temporary files and the
directory name is not critical. The indirection is removed:

- `AGENTS.md` two-directory table and setup snippet now name `/tmp/weizigo`
  directly; the doctrine is unchanged (disposable → `/tmp/weizigo`; important-
  but-untracked → `untracked/`; never scratch in `untracked/`).
- The stray `ephemeral/` directory (a plain directory containing only a symlink
  to `/tmp/weizigo`, nothing load-bearing) was removed. `.gitignore` keeps the
  `ephemeral/` line with a comment — it can reappear, and if it does it stays
  invisible.
- `docs/epics/E1-markovian/WAYPOINTS.md` no longer lists the symlink as missing
  infrastructure. Historical audit text describing the broken symlink
  (`GRAND-AUDIT.md` §3, `arm-infra-tooling.md` D1) is left as record.
