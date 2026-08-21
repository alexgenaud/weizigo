# T551 — Fable review of the pass-1 briefs. VERDICT: **SPEND-WITH-EDITS** — the tournament brief goes to seven lanes only after edits R1–R4 are applied; as written it is DO-NOT-SPEND, because its "measured" root-cause section contains one refuted mechanism claim and one false coverage claim, and its open question is no longer open.

**Reviewer:** claude-fable-5/T551, 2026-08-20, under the adjudication authority of
`docs/infra/delegation/ROLES.md` §Adjudication (operator ruling, 2026-08-20).
**Reviewed:** `docs/epics/E1-markovian/L1-dashboard/S01-process-ownership/pass1/00-spec-tournament-brief.md` (the tournament
brief) and `docs/status/refactor-roadmap-2026-08-20.md` (the SEED BRIEF), both authored by
the Orchestrator seat (`claude-opus-5`).

The edits below are required, not suggested. The seat applies them and may then dispatch
without a second review round — nothing in R1–R4 changes the tournament's structure, only
its facts.

---

## New measurements made during this review

The review did not stop at checking citations; it ran the experiment the brief wants seven
models to specify. Two observations, both reproducible today:

**M1 — zig creates no process groups and no sessions.** Sweep of the installed zig 0.16
stdlib (`/opt/homebrew/Cellar/zig/0.16.0_1/lib/zig`): `std.process.SpawnOptions.pgid`
defaults to `null` (`std/process.zig:397`) and nothing in `compiler/build_runner.zig`,
`std/Build/Step/Run.zig`, or anywhere else in the build path ever sets it or calls
`setsid`/`setpgid` when spawning. `zig build`'s descendants inherit their caller's group
and session. The brief's claim that "the build's descendants create their own groups" is
refuted at the zig layer.

**M2 — the console harness starts every tool command in a NEW SESSION.** Measured on this
review's own process chain, which is exactly the production topology (a detached
dispatcher at ppid 1 → `tools/runner --max-wall …` → `claude -p` console → tool command):

```
pid 55047  tools/runner            pgid 55046  sid 55046
pid 55050  claude -p …T551…        pgid 55050  sid 55050   (runner's setsid — as designed)
pid 72431  zsh (Bash-tool command) pgid 72431  sid 72431   (NEW SESSION per command)
```

(`ps -o pid,ppid,pgid` + `os.getsid()`, 2026-08-20; macOS `ps -o sess` prints 0 and is
useless — use `getsid`.) The Claude console harness `setsid`s each tool command. So when
`runner:1505` does `killpg` on the console's group, the console dies and every tool-command
tree — `zig build test` and its ~3 GB binaries — survives as its own **session leader**,
reparents to init, and holds its memory. No group-level *or session-level* kill aimed at
the console can ever reach it. Only descendant-tree enumeration can. This is the escape
mechanism, measured; zig is merely the heavy payload.

---

## Findings on the tournament brief (blockers first)

### R1 — BLOCKER: the escape mechanism is misattributed, as a "measured" fact
Brief §"The problem, measured", bullet 3: *"the build's descendants create their own
groups, so they survive the kill."* Refuted by M1; the group/session creation is the
console harness's, per M2. Seven specs built on the wrong layer would specify controls
that seed the wrong defect. **Required edit** — replace bullet 3 with:

> - It still leaks, and not because of zig. Zig 0.16's stdlib never creates a process
>   group or session for build children (`std/process.zig:397` — `SpawnOptions.pgid`
>   defaults null; no `setsid`/`setpgid` anywhere in the build path). Measured on the
>   production chain 2026-08-20: the **console harness starts every tool command in a new
>   session** (command shell pgid == sid == own pid, distinct from the console's session).
>   `killpg` aimed at the console therefore misses every tool-command tree; the trees
>   reparent to init holding gigabytes. Because the escapees are **session leaders**, no
>   group- or session-level kill can reach them — only descendant enumeration can.

### R2 — BLOCKER: "killpg at every exit path" is false
Brief §"The problem, measured", bullet 2. `tools/runner` has exactly one `killpg` call
site (`tools/runner:1505`) and it executes only on the ceiling-kill path (wall/CPU/RSS/
host-floor escalation). The host-pressure guard kills a single largest pid, not a group
(`tools/runner:1432`). The **normal-exit path — after `ret = proc.wait()` — reaps nothing
at all**, and a SIGKILLed runner reaps nothing. Two of three exit shapes never attempt any
kill. This matters because it alone explains the recorded healthy-memory orphan (2828 MB
at 27.1 GB free, no cull — `docs/status/tooling-defects-2026-08-20.md` item 16, 17:08
refinement): that orphan was not a killpg escapee; nothing was ever aimed at it.
**Required edits**: (a) replace bullet 2 with:

> - `tools/runner:1161` does the right thing within its reach: `os.setsid()` on its
>   child, then `os.killpg` — but only on its ceiling-kill path (`tools/runner:1505`).
>   The host guard SIGKILLs one pid (`tools/runner:1432`), and the normal-exit path
>   reaps nothing. So even a fully working group kill would leave the normal-exit and
>   runner-death leaks untouched.

(b) extend requirement 6 (the cannibalization step): the verb replaces the `killpg` call
site **and is also called on the normal-exit path**; the runner-death case is a stated
non-goal for pass 1 (it is T548's sweep, and later the supervisor's held handles).

### R3 — BLOCKER: the open question is closed; requirement 3 and the grading criterion must change
Ruling on the dispatching brief's question 3, which is mine to make: the
session-vs-process-group question **was honestly open when written** (no repo artifact
records pgid/sid of an escapee; the DARGUS doctor records ancestry only) — but it was
answerable in one command, and this review answered it (M2): **escape is via a new
session, created per tool command by the console harness, not by zig.** Dispatching seven
lanes to specify that experiment now would spend seven specs on a solved problem — and
worse, the brief's grading instruction ("a spec that asserts an answer without evidence is
guessing, and graders are told to mark that down") would have **punished the one spec that
investigated and got it right**. **Required edits**:
(a) Replace requirement 3 with:

> 3. **The measured escape mechanism, and its residue.** The mechanism is measured
>    (2026-08-20, this repo, production chain): the Claude console harness starts each
>    tool command in a **new session**; zig creates none. Two consequences your spec must
>    build on rather than re-derive: (i) escapees are session leaders, so group- and
>    session-level kills are structurally insufficient — the verb must enumerate and
>    signal the descendant tree, and must handle the race where a dying parent reparents
>    children to init mid-walk; (ii) the mechanism is per-console-family — the
>    measurement covers `claude -p`; specify the one-command check (`ps -o pid,ppid,pgid`
>    plus `getsid`, macOS `ps -o sess` prints 0) that must be run once per other console
>    family (DeepSeek CLI, ollama-subagent) before the seeded controls are finalized.

(b) In §"How you will be judged", replace *"whether it correctly treats the
session-vs-process-group question as open"* with *"whether it builds correctly on the
measured escape mechanism and specifies the per-family residual check"*.

### R4 — MAJOR: the grading paragraph paraphrases the harness, and drifts from it
The brief's G4 sentence ("Self-identifying text is flagged, not scrubbed") contradicts
`docs/epics/E1-markovian/L1-dashboard/S02-model-delegation/grand-race.md` G4 ("sanitizer pass **strips/flags** …"). The brief also
omits the machinery that makes seven grades aggregable: the null and seeded grader
controls (§5), and the recorded G3 consequence that with the 2026-08-20b roster (4 Claude,
2 DeepSeek, 1 qwen lane) a Claude-authored spec receives only **three** countable grades
while the qwen spec receives six — grand-race.md already rules that panel-only
Claude-vs-Claude orderings are low-confidence. **Required edit**: replace the brief's
grading paragraph's protocol sentences with a citation — "Grading runs under
`docs/epics/E1-markovian/L1-dashboard/S02-model-delegation/grand-race.md` §5 and gates G3/G4; the criteria are: …" — keeping the
criteria list. The final-selection sentence (Fable, fresh session, anonymized inputs)
stands; that authority supersedes panel skew, which bounds the comparability risk.

### R5 — MINOR: the reaper-regression description overstates
`tools/regression-orphan-reaper.sh` has **eight** arms (A–H), not seven; arms A–C are
runner-side, D–H require `managent reap` (which exists). "It passes" is T364's record —
this review read the arms but did not re-run them. Say "eight arms (A–H)" and cite the
file; the brief's substantive point (it tests kanban-row orphans, not process trees) is
verified correct and stays.

### R6 — MINOR: one observation overstated
"2.8 GB recurring while free memory was a healthy 25–27 GB" — the record is a **single**
2828 MB orphan at 27.1 GB free (`docs/status/tooling-defects-2026-08-20.md` item 16).
Write it as the single recorded event, with the citation. The conclusion drawn from it
(leak is continuous, not crisis-driven) is the doc's own and stands.

### R7 — MINOR: the memory observations carry no citations
The brief demands lane authors cite every claim by path and line, while its own §"The
problem, measured" cites only two code lines. Add
`docs/status/tooling-defects-2026-08-20.md` (items 2 and 16) to the observation bullets so
lanes can check what they are told. The 12-cull, ~3 GB-binary, 9.1 GB/0.06 GB/swap-2.9-of-4
figures all verified exact against that doc.

### R8 — EDIT: cap the deliverable
"Length is not a virtue" is not gradeable; a cap is. Append to §Deliverable: "Hard cap:
250 lines. Overrun is a gradeable defect against economy." Seven uncapped specs would
also blow the grading panel's attention budget.

Nothing else needs cutting — the brief is tight (95 lines); its problem was accuracy, not
length. Requirements 1, 2, 4, 5, 7 and the constraints section are good and are the reason
this is SPEND-WITH-EDITS rather than DO-NOT-SPEND: they make seven specs comparable
(question 1: yes, with the edits — the largest comparability threat was never vagueness,
it was seven specs comparably built on a wrong premise).

---

## Ruling on question 2 — pass order

**Pass 1 (process ownership) first: AFFIRMED.** The consolidation-first argument conflates
"before the supervisor" with "before everything". State consolidation must precede the
supervisor, and in the seed brief's ordering it does (passes 3–4 precede pass 5). Pass 1
itself touches no store — a proc-tree walker reads the process table — so scattered state
cannot malform it. Meanwhile the leak it fixes is the one **active** bleed: it corrupts
the model-perf ledger daily, and the ledger is the product. M2 strengthens this: since
escapees are session leaders, no incremental patch to the runner's killpg can ever work —
the verb is necessary, not merely tidy. Consolidation-first would defer the only fix that
stops the bleeding in order to protect a component (the supervisor) that is four passes
away and already protected by the ordering.

## Ruling on the seed brief (strategy, not prose)

- **Three programs** (managent as store / one holding supervisor / read-only views):
  **SOUND.** The rewrite-vs-improve split is argued from the measured design fault
  (inference vs held handles) and is correct.
- **Five-step pattern** (characterize → red → build → green → dogfood): **SOUND**; it is
  the repo's own doctrine (never trust a green test; duplication as oracle) applied to
  infra.
- **Both non-goals** (don't scrap the old fleet first; no new supervisory processes):
  **SOUND**, and the second is the operator's own ruling (commit `ec72cdb`).
- **T428-shape risk: PARTIALLY PRESENT, one condition imposed.** The dogfood-as-deliverable
  rule is necessary but not sufficient — T428's design did not die for lack of a dogfood
  step, it died **undispatched**. The mechanism that prevents recurrence is registration,
  not prose. **Condition of ratification: when the operator ratifies this seed brief, the
  full pass-1 ladder (spec tournament → grade → consolidate → plan → red → build → green →
  dogfood → audit) is registered as kanban rows in the same commit**, exactly as the
  fleet-repair sprint did (`81f23d8`). A plan that exists only as a document is the failure
  mode; a stalled row is at least visible.
- **Corrections it inherits from R1/R2/R3**: §"Why the supervisor is a rewrite" repeats
  "killpg() at every exit" (false, R2) and the zig-creates-groups mechanism (refuted, R1);
  pass 1's "open experiment" paragraph is now answered (R3). Apply the same corrections.
- **Minor factual drift**, note only: `model-perf.md` "316 KB" is 254 KB today and
  `heartbeat.jsonl` "2.5 MB" is 1.6 MB today (live files — date the figures); pass 2's red
  case "reported 3 watchdogs when 1 was running" has no independent record — the recorded
  instance of that defect class is `pgrep -f fleet-keeper` returning 2 with zero keepers
  running (`tooling-defects-2026-08-20.md` item 9); cite that one.

---

## Method and denominator

The tournament brief makes ~27 checkable factual claims. **26 of 27 checked** against the
live tree (the exception: re-running the T364 regression's green status — read, not
re-run). 21 verified exact — including both cited code lines (`bin/dispatch:301`,
`tools/runner:1161`), the 8,780-line count, the 12-cull/rc=124 record, and all four memory
observations' figures. 2 refuted (R1, R2), 2 overstated (R5, R6), 1 protocol drift (R4).
Two new measurements made (M1, M2). No live orphans existed at review time
(`ps -axo pid,ppid,pgid,rss,comm` — clean table), so M2 was obtained from the production
chain of this review's own dispatch rather than from a specimen.
