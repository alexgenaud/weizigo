# AGENTS.md — the router

**Only what EVERY agent needs** — read this, then the one file your role points you at, nothing else. Agents
read only what they need, when they need it. Harness prefers `CLAUDE.md`/`.cursorrules`? Redirect, don't copy.

## What this project is
`weizigo` — a provably-correct solver for small Go gobans (Weiqi/Baduk) in Zig 0.16. Goal: a compressed
fresh-start oracle: the exact game-theoretic fresh-start score of every legal (position, side), by
retrograde value iteration with two-sided (L/H) certification. Gobans done through 4x4; ruleset in reframe.

## Non-negotiable rules (foreclosures — do NOT relitigate)
Settled — reopening one wastes a session. To overturn one, write an ADR superseding it with evidence; never act against one silently.

- **Positional superko (PSK) is NOT the generation target.** PSK exact-solve is intractable even on the EMPTY
  2x2 (118M ban-set states). See ADR-0013, `docs/research/ruleset-options.md`. Play-time can still enforce PSK for legality.
- **kill-X% is dead as a ko-sensitive-region cure.** It makes the 4x4 ko-sensitive region WORSE (21.32%
  -> 25.01% as the threshold drops). Remains an optional play rule only.
- **score-on-cycle is provably as hard as PSK.** Byte-identical state counts (118,475,182 / 116,114,272).
  No free lunch. See `docs/research/ruleset-options.md`.
- **The committed ko-sensitive values are NOT trustworthy.** `data/oracle-4x4.checkpoint.wzo` (referent
  corrected 2026-07-28: `data/oracle-4x4.wzo` is named in older docs but **does not exist on disk** — two
  instruments confirm, `bin/weizigo-claimlint` and a direct `ls`. The checkpoint is the artifact this
  foreclosure is about: it is the writes-**ON** build, it is the only 4x4 artifact whose root is filled, and
  every headline 4x4 number to date came from it.) and the 2x2/3x2/3x3
  ko-sensitive columns are unverified until Track A regenerates them with `memo_writes=false` and passes
  the #2 auditor. The L==H core is **fresh-start correct (C1)**, NOT real-game correct. C2 (single-score
  history-independence) is **falsified at 3×2** (T13, 2026-07-26; 12 mismatches on 508 non-trivial PSK
  histories). Do NOT quote a ko-sensitive score as truth until then, and do not call the L==H region a
  "proven core" or "certified core" in any real-game sense; it is the *fresh-start single-score region*.
- **Never report any table value as *the* real-game value of the goban.** The table holds **fresh-start
  scores only** (C1); C2 (single-score history-independence) is falsified at 3×2 (T13); C3 (bracket bounds
  real-game score) is falsified at 3×3 (E2). The honest deliverable is the fresh-start score table + the
  CLAIMED [L,H] fresh-start bracket, with the explicit non-promise that neither equals nor bounds the
  real-game PSK score.
- **The #2 self-consistency auditor is a mandatory pre-commit gate** for any change to the finisher, memo
  logic, or ko/GHI handling. Zero minimax-identity violations on 3x2 exhaustive + the deepest-N 4x4
  sample. A "sound by construction" claim without an auditor run is INSUFFICIENT — the last bug
  (`ko_ref >= d`, ADR-0013) looked obviously correct and was wrong.
- **The single-score (L==H) region is NOT history-independent.** T13 falsified C2 at 3×2 (2026-07-26). The
  L==H values are fresh-start exact (C1), not real-game exact. Do not relitigate "is the L==H region
  history-independent?" — it is settled false at the smallest testable goban. A new ADR with a different
  representation (e.g. bounded-history state) is the route to a real-game claim, not a re-run of the
  C2-probe.
- **Scores are ALWAYS Black-positive.** Side-to-move picks the array (vb/vw), never the sign. Black
  maximizes, White minimizes. Colour inversion: value(-pos,-side) == -value(pos,side); for bound tables
  L(-pos,-side) == -H.
- **Never call the goban index a "rank."** In Go, rank = kyu/dan. Use "colex index" or just "index." (User
  decision; you will be corrected.)
- **No sub-goban solving.** Restricting moves to a region of the goban is unsound (edge stones keep
  phantom liberties). Search is full-goban only.
- **Do not remove the eye-prune from the forward search.** Self-eye-fill reopens the goban and explodes the
  DFS (ADR-0006). The retrograde engine uses the full move set by design; the forward cross-checks use eye-prune.

## Behaviour — every agent, every task
- **Decide now what can be decided now — never punt a decision (operator, 2026-08-23; sharpened
  2026-08-24).** Parking a decidable point in a "ratification round", an open-questions section, a
  rulings queue, or an escalation to the operator is ceremony. Weigh the evidence, consider the
  alternatives and their consequences, make a recommendation, and defend it — doubts stated, not
  hidden. Deferring a decision repeats a process already run once, and it is worst when the agent
  already held everything needed to decide. If a genuinely missing fact blocks the decision, go find
  it or ask for **the fact** — never hand back the decision itself. Escalate only what is genuinely
  the operator's — spend, scope, overturning a recorded ruling — and arrive even there with a
  defended recommendation, never a menu of abstractions. A draft presented for ratification must be
  finished — every question its author could answer, answered.
- **Per-goban epistemic independence.** Each goban size is its own epistemic universe: PROVEN / CLAIMED /
  FALSE-AS-SCOPED at one size is **not** evidence at any other size, absent a monotonicity theorem.
- **Evidence in git, or the claim is not proven** — under `docs/evidence/<claim-id>/`, never `untracked/`:
  that is how T13's probe source, the falsification the strategy rests on, was destroyed. **Every claim
  carries a status** — PROVEN / CLAIMED / FALSE-AS-SCOPED — and never assert "proven" or "sound" without
  the run that makes it so.
- **Scratch is for working files; a citation is a commitment (T421, 2026-08-08).** Anything a document
  cites must be committed under `docs/evidence/<claim-id>/` **before the task closes** — a `/tmp` citation
  whose file still exists passes claimlint C2 (which only sees *missing* paths) and becomes a dead link
  the moment the sweep destroys the file; 43 such citations had already crossed that line on 2026-08-08
  before the 278-file rescue. claimlint C10 VOLATILE reports every `/tmp`, `/private/tmp`,
  absolute-outside-tree and `untracked/` citation in committed docs, whether or not the file exists.
  C10 is report-only; its floor is proposed separately, so treat it as a standing debt census, not a gate.
- **No silent writes to `data/` or `artifacts/`.** New rule → new file, tagged `(size, ruleset)`; never
  overwrite a `.wzo` or `artifacts/SHA256SUMS`.
- **One writer per engine file** (`src/retro.zig`, `oracle.zig`, `rules.zig`, `solve.zig`). Declare
  ownership via the kanban `holds=` field (`managent show <id>` displays it), clear it when done;
  concurrent edits corrupt silently.
- **Dates are absolute** (2026-07-28), never "today." **Numbers cite their run** (command, flags, goban
  size) and state their **denominator**.
- **Know your identifier and write it into every file you produce.** Court seats use the role name
  (`Orchestrator`, `Dabir`); workers use their task ID (`2B-5`, `EXP-4`). A model name alone names a
  *kind* of worker, not a worker, and five instances of one model ran five tasks on 2026-07-29. In full
  at first use, abbreviated after. `unknown/<task-id>` if you were not told your model, **never a guess**;
  otherwise the model-performance ledger can attribute nothing. The model is recorded at dispatch time
  in `managent`'s `agent` field and in `model-perf.md`; it does not belong in the identifier. Scheme and
  edge cases: `docs/infra/agent-identity-and-worker-channel.md`.
- **Workers are identified by task ID** (`EXP-4`, `B99`), never by model name; thinking managers are
  addressed by ROLE — Orchestrator / Dabir / Auditor. Who is who, what may be specified in a brief, and how
  many agents may run at once: `docs/infra/delegation/ROLES.md`.

## Build / test / run
- Build `zig build` · suite `zig build test` · per-module `zig test src/<file>.zig` (avoids the dyld mega-
  binary quirk). Correctness runs use `-Doptimize=ReleaseSafe` — asserts are no-ops in ReleaseFast.
- **Ad-hoc builds run under `tools/runner`**, which auto-adds `-O ReleaseFast` (or
  `-Doptimize=ReleaseFast` for `zig build`) and SIGKILLs the process group on a
  4 GB RSS breach. The 2026-07-29 02:37 host kernel panic
  (`docs/infra/host/incident-2026-07-29.md`) is the precedent; the runner is
  `docs/infra/runner.md`; the source is `tools/runner` (Python, stdlib only).
  **Builds without the guard on a host with a recent compressor incident are
  the Orchestrator's responsibility to refuse, not the agent's to remember.**
- Retrograde build + battery: `RETRO_SAVE=1 zig run -O ReleaseFast src/retro.zig`. Long runs (258 MB, 19 sweeps)
  need a persistent session: start it, watch the heartbeat, never restart. Caches under `/tmp/weizigo-zigcache`.
- `weizigo-oracle <a.wzo>` (GTP; Sabaki-compatible) · `weizigo-arena <a.wzo> <seeds>` · `bin/weizigo-claimlint`.
- **Install the pre-commit gate once per clone: `git config core.hooksPath tools/hooks`.**
  It blocks claimlint *regressions* against the recorded floor in
  `tools/hooks/claimlint-floor.json` — not "must be green", which is unreachable today.
  Repo config is not tracked by git, so `tools/regression-precommit.sh` (wired into
  `zig build test`) **fails loudly while the gate is uninstalled**; a red suite on a
  fresh clone means run that command.
- **Staging procedure — every agent, every commit, no exceptions.** Keep your own list of the
  files you created or modified, and **stage them by name**: `tools/git-commit-mine <paths> -m
  <msg>`. **Never `git add -A`, `git add .`, or `git commit -a`.** You are never alone in this
  checkout: another console's half-finished edit sitting in the working tree is invisible to you
  and indistinguishable from your own, and a wildcard stage takes it. If you do not know which
  files are yours, you are not ready to commit — re-read your own brief's `deliverables=`, which
  is the authoritative list. Recorded failure, 2026-08-18: the **Orchestrator** ran `git add -A`
  while three consoles were mid-task and committed two of their source fixes under an unrelated
  message (`d7e4bdb`); the work survived, the authorship did not. The rule predated the failure,
  which is why the mechanism is being built too — `T455`, since a rule that only prose enforces
  is enforced only on whoever reads it. See `docs/infra/fleet-git-isolation.md`.
- **Titles are display surfaces: one line, under 40 chars for a task title, under 72 for a
  commit subject.** The full rules live in their single homes: task titles in
  `docs/infra/delegation/DELEGATOR.md` §Task titles; commit subjects in
  `docs/infra/fleet-git-isolation.md` §4.1a. A title that needs more than the limit is a sign
  the task (or commit) is two of whatever it is. The detail goes in the body / the findings
  file, never in the title.
- `bin/managent` is the queue: `add` / `dispatch` / `claim` / `done` / `reopen`
  / `purge` / `set` / `next` / `status` / `show`. Any seat may register and
  dispatch unless its brief says otherwise; a seat acting on a worker's behalf
  attributes with `--agent <worker>`. The permission ruling lives in ONE place:
  `docs/infra/delegation/ROLES.md` §"Dispatching, claiming, and the kanban".
  Schema in `docs/infra/managent/spec.md`.
- **stdout = data, stderr = diagnostics.** Use `util.out(...)` for parseable/filterable
  output and `util.note(...)` / `util.warn(...)` for diagnostics. Reference:
  `src/gtp.zig:691,1056`, helper in `src/util.zig`. Regression check:
  `<tool> 2>/dev/null` must emit data, `<tool> 1>/dev/null` must be silent.

## Where to go next — read ONE of these
| if you are… | read |
|---|---|
| dispatching, or unsure what you are | `docs/infra/delegation/ROLES.md` |
| writing a task for another agent | `docs/infra/delegation/DELEGATOR.md` |
| executing a task you were handed | `docs/infra/delegation/DELEGATEE.md`, then your brief |
| running an experiment from a console | `docs/infra/dispatch/README.md` + your experiment's brief there |
| auditing or setting claim status | `docs/epistemic/CLAIMS.md` (one owner — do not race it) |
| unsure of a term | `docs/epistemic/GLOSSARY.md` (coinages marked `[project term]`) |
| after the living overview | `docs/epistemic/PROGRESS.md` — the durable hub. The two dated docs below are depth it is meant to absorb; if they disagree with it, PROGRESS is stale and that is a bug to file |
| after which ruleset we solve, and how | `docs/epistemic/roadmap-2026-07-28.md` |
| after what is known-wrong | `docs/epistemic/critique-2026-07-28.md` (§4 especially) |
| resuming cold (durable in git) | `bin/managent resume` (composed surface), then `docs/epistemic/PROGRESS.md` |
| resuming from the channel (durable + untracked) | `untracked/msg/<epic>/STATE.md` (read first), then `bin/managent resume` |
| running an ad-hoc build | `docs/infra/runner.md`, then `tools/runner -- <command>` |
| delegating to a DeepSeek subagent | `docs/infra/agents/subdelegation.md` — `odeeppi` (Pro) and `oflashpi` (Flash) shell commands |
| editing engine code | `docs/engine/ARCHITECTURE.md` + the relevant `docs/decisions/000N-*.md` |
| choosing which model to delegate to (provisional tiers + rules) | `docs/epics/E1-markovian/L1-dashboard/S02-model-delegation/goldilocks.md` |
| measuring models (appetite, metric schema, how scores compare) | `docs/epics/E1-markovian/L1-dashboard/S02-model-delegation/measurement-methodology.md` — DESIGN, not built |

## The queue is a *kanban*; the playing surface is a *goban*

Two words, no overlap, and **neither of them is "board."**

- `bin/managent` is the **kanban** — tasks, sets, holds, needs, claims, columns.
- The Go playing surface is the **goban** (2×2, 3×2, 4×4) — goban size, goban state, per-goban independence.

"Board" served both and produced sentences that read two ways, so it is retired from prose in both senses.
Leave it untouched only where it is not prose: the GTP `boardsize` command, code identifiers, `boards/`
path segments, captured `.stdout` output, quoted third-party titles ("Solving Go for Rectangular Boards"),
and English idioms ("across the board"). (User's terminology ruling, 2026-07-29; extended to *goban*
2026-07-31, swept by T120.)

## Tooling gets the same pipeline as research code (user requirement, 2026-08-07) — standing

**Tests before implementation, for instruments and tooling, not only for the engine.** The delivery
pipeline — spec → design → tests → implement → independent audit → accept — has been applied to tasks
that produce numbers and skipped for the code that produces them. **Every defect of the week of
2026-08-03 was in tooling or an instrument; none was in the kernel.** That is not luck, it is where
the discipline was missing:

| defect | why no test caught it |
|---|---|
| `t387_budget.zig` — `bitpos: u6` vs `while (bitpos < 64)`, infinite loop | none; only manifests under `-O ReleaseFast`, which is what `tools/runner` forces |
| `gtp.zig` — `list_commands` reply 303 bytes into a `[256]u8` | none; crashed on a command every GUI sends at handshake |
| `managent` — free text written into JSON unescaped | none; corrupted the live kanban **twice**, fleet-wide outage |
| `absorb` — parser read a 221-line claim register as **empty** | none; reported "nothing to absorb" instead of failing |

The shared failure mode is worth naming, because it recurs: **the tool reported success while doing
nothing.** A silent wrong answer outranks a loud crash.

So, standing:

- **Write the failing test first and show it red**, then fix. A test written after the fix proves the
  fix compiles, not that the test works. If a defect has already been fixed and cannot be re-observed
  failing, **assert the invariant instead** — do not re-introduce a bug to watch it break.
- **A tooling task is not accepted until its test is wired into `zig build test`.**
- **Report which tasks were test-first and which were not.** Sprint consoles must say so per task.
- This binds the Orchestrator seat too. An Orchestrator production edit without a test is the same
  defect with a better excuse — 2026-08-07, `src/gtp.zig` was fixed from the Orchestrator seat and
  verified by hand, and its regression test had to be added afterwards by T403.

## Verification rules earned on 2026-07-29 (the QA-023 chain) — standing

The QA-023 probe returned `TIE` on its first node in **1,133 of 1,133** evaluations and produced two
published falsification numbers before an absorption check caught it. **Five audit links; four passed the
artefact through.** These are the rules that would have caught it, and they are now standing:

- **Verify-then-promote.** A load-bearing claim moves to FALSE (or PROVEN) **only after an independent
  seat agrees** — not on one model's report, however well argued. The Orchestrator is not exempt: the
  Orchestrator's own adjudication went to `2B-6` before promotion. State the gate in the commit.
- **An auditor must trace one complete evaluation end-to-end.** `2B-3-AUDIT` stopped one function call
  short of the defect and verified everything around it. Reviewing inputs, outputs and structure is not
  the same as following one datum from entry to verdict.
- **A positive control must exercise the instrument under test, not a parallel one.** `2B-5`'s POS arm ran
  PSK through a *separate* code path, passed, and gave **zero** coverage of the defective call site — while
  reading as proof the instrument was sensitive.
- **Impossibly clean counters are red flags.** `budget-exhausted: 0` on a harness whose honest cost is
  exponential, or `value-agreements: 0` in every run ever recorded, are symptoms. Both were reported as
  reassurance.
- **Independent re-implementation is what finds defects.** In this project it is the *only* thing that ever
  has: the audit that found the ko bug (F5) rewrote the algorithm in Python; document review found nothing.
- **State every denominator, including the within-budget one.** 93% of the corrected probe's sample is
  missing; a rate quoted without that is not a measurement.

## Closing report to the human — what your last console message must be (user requirement, 2026-08-07)

**Everything you produce goes to disk and is read from git by the Orchestrator.** Your final console
message is therefore *not* a handover — it is a short human-readable summary for the operator, who
should never have to read a transcript to know what happened.

End every task or sprint with a brief plain-text summary containing, in this order:

1. **The headline** — what the task was, in one sentence, in words a human reads once.
2. **Status** — `success`, `failure`, or `incomplete`. Say the word. "Pass with findings" is a
   verdict for the ledger; the operator wants the plain status.
3. **What he would want to know** — the load-bearing result, and anything surprising. A refuted
   hypothesis, a defect found in something you were not working on, a number that contradicts a
   published one.
4. **Possible follow-up**, if a surprise suggests one. A sentence, not a plan.

**No details.** No tables of denominators, no control readings, no file lists, no commit hashes. Those
belong in the committed doc and findings file, where the Orchestrator reads them. If the summary is
longer than a short paragraph or two, it is the wrong artifact.

**Never ask the human to relay a message to another agent.** He is not a message bus. Write it to
disk — a findings file, the task's doc, a `bin/managent tell` directive — and it will be read. Ask him
to relay something only when there is genuinely no on-disk route, and then say explicitly why not.

## Agent-to-human output — copy/paste boundaries (user requirement, 2026-07-29)

The human relays text between consoles by hand. **Anything he is meant to copy must be unambiguously
bounded, so he never has to guess which paragraphs are the payload.**

**Placement first (user requirement, 2026-08-08): if your message contains something he can dispatch
NOW, put it EARLY — not at the end.** He is a dispatcher first and a reader second, so a prompt
buried under analysis blocks him from starting the work while he reads about it. One line of context
at most, then the dispatch line, then the explanation. (With *several* payloads, the
consecutive-fences rule below still applies once past the opening.)

Two forms, and only two:

**1. A prompt one-liner is exactly one line.** No wrapping, no internal newlines, no leading bullet or
quote marker — it must survive a single select-and-paste. If it does not fit on one line, it is not a
one-liner; use form 2.

**2. Multi-line copy/paste text is fenced by a `---` above and below, each `---` ALONE on its
own line with a blank line on either side.** So: prose, blank line, `---`, blank line, **the payload**,
blank line, `---`, blank line, prose. Nothing but payload goes inside the boundaries — no commentary, no
"note that…", no explanation the receiving console should not read. Put that in the prose outside.

The blank lines are load-bearing, not style: markdown fuses a `---` with an adjacent text line into a
heading or an attached rule, which makes the fence invisible or swallows the payload's first line. A
fence that is not alone is not a fence. (Violation observed 2026-08-05: a payload written directly
against its opening `---` rendered as one merged block; the human could not see where narrative ended
and payload began.)

**The payload's first line is an address line:** `<sender>/<seat> to <target>/<seat>: …` — e.g.
`Fable/Auditor to Opus/Orcha: …` — so the human knows which console receives it without reading the
body, and the receiving console knows who is speaking. For task dispatches the target form is
`<model>/T<nnn>` (e.g. `to deepseek-v4-flash/T365:`); the address line replaces the older
same-line `--- <model>/T<nnn>` annotation, which put content on the fence line and broke the
fence-alone rule.

Canonical shape (ruled 2026-08-05):

```
…narrative to the human ends here.

---

Fable/Auditor to Opus/Orcha: <the payload, and nothing else>

---

…narrative to the human resumes here.
```

**Never two `---` in a row (operator directive 2026-08-05).** One rule is always enough: between
narrative and a payload, and *between consecutive payloads* — a single `---` closes one block and opens
the next. Stacking a closing rule against an opening rule is the violation that prompted this line. For
several dispatches, put all the prose first, then the payloads back to back separated by one rule each:

```
…narrative, including which model each dispatch is for, ends here.

---

flash/T372: Follow untracked/T372-zrtie-contrast-generator.md

---

flash/T368: Follow untracked/T368-standing-trigger-markers.md

---
```

(`flash/T<nnn>` shorthand is fine in a paste line; the kanban and ledger keep the canonical model label.)

Why: without the rule the human has to infer the subset, and inferring it wrongly means a console gets a
truncated or contaminated brief. This applies to relay messages, dispatch prompts, commit-message drafts,
and anything else handed over for pasting — every role, not just the Orchestrator.

## Landmarks — frame the work as a journey, not a task list

`docs/epics/E1-markovian/LANDMARKS.md` names the checkpoints a human can verify without
reading a task brief: **L0** the table and the instruments exist · **L1** the dashboard tells the
truth · **L2** proven 4×4 values · **L3** the new engine outplays the old one · **L4** the ledger is
clean · **L5** one rulebook · **L6** small Go solved, certifiably · **L7** the 5×5 decision, costed.

**Every ID is written with its short name** — `L2 (proven 4×4 values)`, never a bare `L2`. An ID
nobody can expand is not communication. (These were "milestones M<n>" before 2026-08-05; the IDs
moved to `L<n>` because `M1`–`M10` are already the mutant IDs.)

**Every task has a SHORT NAME, phrased as the question the task answers.** Not a slug — a question
a human can read: `T387 (does a capture cap make the game finite?)`, `T388 (do we run the same test
at every goban size?)`. It goes in the brief's title line and in the `managent` note, and it is what
appears in narrative to the operator. Report a task's outcome as a sentence that ties it to its
landmark:

> `T387 (does a capture cap make the game finite?)` — **answered yes, at 3×3.** One of the
> hypotheses supporting `L2 (proven 4×4 values)`; still open at 4×3 and 4×4.

An ID with no short name forces the reader to open the brief to learn what the work was about.

**Frame work as movement between landmarks.** A sprint is not "a list of tasks that closed" — it is a
step from one landmark toward the next. When you open a brief, say which landmark the work serves;
when you close a task, say what a human can now see that they could not before, and what still
stands in the way:

> **Landmark:** advances `L<n> (<short name>)` — <what is now visible> — <what remains>.

Three rules keep it honest rather than decorative:

1. **Always expand the ID.**
2. **State which direction a result cuts.** If something got worse, say *whose* and *which way*.
   "Every game diverged and there were 9 genuine losses" is uninterpretable until you say the losses
   were the *old* engine's and the new engine wins those games.
3. **A task that advances no landmark says so** — `Landmark: none directly; unblocks <task>`. Fleet
   plumbing is honest work; dressing it up as mission progress is what makes landmark talk worthless.

This is for the operator, who is the only reader who cannot query the repo — every other artifact
here is written for the next agent.

## Untracked directories — two types, never conflat

There are exactly two places for files that must not enter git, and their purposes are distinct:

| directory | purpose | lifetime | examples |
|---|---|---|---|
| `/tmp/weizigo/` | **disposable outputs** — build artifacts, test runs, zig caches, scratch files you would not mind losing on reboot | reboot = gone; fine | `/tmp/weizigo-zigcache`, compiled binaries, `heartbeat.jsonl` |
| `untracked/` (project-local, gitignored) | **important but untracked** — agent-to-agent comms, large `.wzo` artifacts too big for git, in-progress task bundles | must survive across sessions; survives clone only on the host that created it | `msg/`, `managent/` (tombstone), `*.wzo` |

**Rule: never put disposable scratch in `untracked/`.** The B44 cleanup swept evidence because `untracked/` held
both scratch and load-bearing files and the cleaner could not tell them apart. If it goes to `/tmp/weizigo/` it will
never be cited as evidence; if it is in `untracked/` someone may need it next month. Choose deliberately.

Ensure `/tmp/weizigo` exists (once per clone):
```sh
mkdir -p /tmp/weizigo
```
Disposable scratch goes straight to `/tmp/weizigo/` — the `ephemeral` symlink is retired
(human's ruling, 2026-08-03; see `docs/infra/resume-surface.md`).

Agent-to-agent comms and task state belong in `untracked/`, under documented subdirectories:
- `untracked/msg/<epic>/` — cross-agent messages (see below)
- `untracked/managent/` — tombstone only; the live kanban store is `docs/infra/managent/tasks.json` (`bin/managent` writes there)
- `untracked/*.wzo` — large oracle artifacts that are cited but not in git (hashes recorded in `docs/evidence/README.md`)

## Agent-to-agent communication
Cross-agent traffic lives in `untracked/msg/<epic>/` (max two live): `STATE.md` is the crash-recovery anchor
(read first; always current, overwritten in place), `NNN-<from>-to-<to>.md` are append-only numbered messages
(never edit an old one), `DECISIONS.md` records every ruling with its promotion target in `docs/`. **Delete the
directory only once every decision is promoted** — `untracked/` is git-ignored, so it dies on a fresh clone; that
is how T13's evidence was destroyed. Promotion is the gate, not tidiness.

The legacy directory `untracked/msg/milestone-01-ko-reframe/` persists as the channel name for epic-01-markovian:
"milestone" is retired for new documents, but the directory name stays to avoid breaking existing references
(see `docs/infra/channel.md`).
