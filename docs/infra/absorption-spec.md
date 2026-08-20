# Absorption — the mechanism that makes unabsorbed findings impossible

**Task:** T481 · **Author:** Fable seat (claude-fable-5) · **Date:** 2026-08-19
**Landmark:** `L4 (the ledger is clean)` · **Status:** SPECIFICATION — for operator review.
This document implements nothing. Its implementation tasks are listed in §13.

**Operator ruling, 2026-08-19:** *"Absorption failure should have no tolerance threshold.
This is a crisis that needs a solution. Models (or Opus specifically) are unable to handle
it. It requires tooling and blocking procedures."*

## 0. The answer in one paragraph

A task may not close successfully while its own findings are malformed or unabsorbed. The
block lives in `managent done` — the one choke-point every close already passes through —
and the party running the close does the absorbing, mechanically assisted, before the close
is accepted. Rejection with a reason counts as absorption, so the gate cannot teach workers
to propose nothing. The threshold of 5 is retired, replaced by a partition: findings of
**open** tasks are legitimately unabsorbed at any count (that is work in flight), findings
of **closed** tasks must number exactly **zero** — no tolerance, and any non-zero reading is
a crisis trigger, because with the close gate in place it can only mean someone went around
the mechanism.

## 1. Definitions

- **Finding** — one proposal inside a findings file: a `claims[]` status proposal or a
  `new_rows[]` register-row proposal (`findings/README.md:27-55`).
- **A task's findings files** — every `findings/<task-id>-*.json`, per the naming
  convention (`findings/README.md:17-23`), unioned with any path under `findings/`
  declared in the task bundle's `deliverables=` line. The filename assigns ownership;
  a file named `T481-*` belongs to T481 regardless of who wrote it.
- **Absorbed** — the proposal is *reflected*: the register row in
  `docs/epistemic/CLAIMS.md` carries the proposed status (or the proposed new row exists),
  **or** the proposal is *dispositioned*: an entry in `findings/rejections.json` names it
  with a reason. This is already claimlint's definition (`src/claimlint.zig:1424-1425`);
  the rejection registry carries three reason-bearing dispositions — `rejected-by-register`,
  `not-a-register-claim`, `absorbed-under-register-id` (`src/claimlint.zig:253-265`;
  56 entries today, every one with all eight fields including `rationale`).
- **Conforming** — the file parses as JSON and carries the required keys `task_id`,
  `date`, `model`, `claims` with `claims` an array (`src/claimlint.zig:2356-2394`).

**The relationship between findings files and register rows, stated for the first time.**
347 findings files exist; the register holds 228 rows (claimlint `rows parsed 228 / 0`;
§2 of CLAIMS.md spans `docs/epistemic/CLAIMS.md:214-592`). These are not, and must never
be, in bijection. A findings file is an **immutable per-task proposal-and-provenance
record** (`findings/README.md:12-14`); the register is the **current ratified belief**.
41 distinct findings files are cited as evidence inside CLAIMS.md; 25 are named in
`findings/rejections.json`; the remainder are matched-status records or presence-only
context dumps. Silence in the register about a findings **file** is normal. Silence about
a **proposal** is the defect, and C7 is exactly its census: every proposal is either
reflected, dispositioned, or owned by a still-open task — anything else is drift.
(The T481 brief's "344 files" was correct when written; three more landed the same day.
That the headline number moves within hours is itself the argument for a mechanism.)

## 2. The invariant

- **INV-1 (close coherence).** A task may not close with verdict `pass`,
  `pass-with-findings`, or `fail-found` while any of its findings files is non-conforming
  or carries an unabsorbed proposal. `blocked` and `abandoned` are exempt (§9).
- **INV-2 (no invisible proposals).** A findings file that cannot be parsed is treated
  *at least as severely* as an unabsorbed one at every gate. Malformed must never mean
  invisible.
- **INV-3 (closed-set zero).** The set {unabsorbed proposals belonging to closed or
  archived tasks} is empty at all times. No threshold, no noise band. With INV-1 enforced,
  a violation can only arise from a side door (hand-edited register, post-close edit of a
  findings file, deleted rejection entry) and is therefore a crisis finding, not a backlog.

INV-1 is the enforcement point; INV-3 is the standing alarm that proves INV-1 is not being
routed around. The global C7 gauge splits into two readings with different laws: the
**open partition** (informational, any value healthy) and the **closed partition** (zero,
fails loudly). The number 5 died because it conflated the two.

## 3. Why the current machinery cannot hold the invariant

Seven surfaces touch absorption today. None blocks at close, and malformed files are
invisible to all of them:

| surface | what it does | what it misses | where |
|---|---|---|---|
| claimlint C7 | counts unabsorbed; `exit 1` when > 0 | `nonconforming` is **absent from the exit condition** — reported, never failing | `src/claimlint.zig:1421-1486`, exit at `:2103-2106` |
| pre-commit hook | floors C1a/C1b/C2/C3/C6/C9; blocks regressions | **no C7 floor, no non-conforming floor** — a commit may raise both without limit | `tools/hooks/pre-commit:219-270` |
| `managent done` | deliverables committed in git; acceptance command | never runs claimlint; **content of a findings file is never examined** | `src/managent/main.zig:2478-2523` |
| `managent archive` | refuses archiving a task with UNABSORBED entries | runs rarely and late; its parser matches only ``"  C7 UNABSORBED  `"`` item lines (`main.zig:2990`) and **misses NON-CONFORMING lines** (`claimlint.zig:1434`) | `src/managent/main.zig:2968-3055` |
| `managent standing` | fires STANDING-ABSORB when C7 > 5 | the threshold tolerates drift by design; a done/failed standing row **cannot re-fire** (`docs/infra/orcha-doctor-2026-08-08.md:43`) | `src/managent/main.zig:6225-6243`, `docs/infra/managent/spec.md:627-631` |
| dispatch verification | nonce echo; deliverables **exist**; row left `dispatchable` | existence, not parse — a malformed findings file passes | `tools/dispatch_verify.py` (T411 header, mechanisms 1-3) |
| `weizigo-claimlint absorb` | emits mechanical edit directives from a findings file | "The Orchestrator reviews and ratifies — this tool never writes CLAIMS.md" — the manual half is the half that fails | `src/absorb.zig:19-30` |

**The T454 chain, gate by gate.** `findings/T454-suite-caller-dependence.json` was
committed invalid at `a4c36bc` (2026-08-19 18:12 +0200; `Expecting ',' delimiter: line 24
column 84`) and its task closed `pass`. Dispatch verification: file exists → pass.
Pre-commit: non-conforming not floored → pass. `managent done`: file committed in git →
pass. Claimlint: `nonconforming = 1`, **not in the exit condition** → no failure; worse,
a file that does not parse contributes **zero** unabsorbed entries
(`src/claimlint.zig:2356-2362` returns with `unabsorbed = 0`), so its proposals vanish
from the census. Even `managent archive` would have passed it (parser mismatch above).
Repaired 93 minutes later by T480 (`b00b9b2`) — because the operator escalated, not
because anything fired.

**The T440 inverse.** T440's code shipped 2026-08-08 (`3aaffb6`, `b2a8517`) but its
declared findings file was never written, so `managent done` refused the close for
**eleven days** (`docs/infra/managent/tasks.json:1520-1538`: claimed 2026-08-08T16:23:26Z,
done 2026-08-19T13:13:35Z; `untracked/T465-t440-findings-from-evidence.md:6-9`). The row
showed a live claim for a console that no longer existed; the operator worked around it in
the assertion ledger (`docs/infra/assertion-ledger/archive/assertions-2026-08-19.jsonl:9`,
A0012 — archived 2026-08-19, T495) and a later
task reconstructed the findings from commit archaeology (`16c4230`), with the worker's
actual reasoning permanently lost. Two lessons the mechanism must carry: **(a)** a block
at close *works* — the gate held for eleven days without being routed around; **(b)** a
block whose repair needs a dead console's context creates zombies — absorption material
must be extracted **while the accountable party is still alive**, which is precisely the
close moment and no later.

**The seat evidence.** `docs/infra/model-perf.md:2703-2725` ("The seat, not the models")
records the identical failure under three different Orchestrator models in three
consecutive sessions, and states the invariant this spec mechanizes: *"findings reach
`model-perf.md`, which is **about** the work, and not `CLAIMS.md`, which **is** the work…
The register is the hard half, and it is the half that gets skipped."* The operator is
right that no discipline fix is available: the same prose has been in force for weeks
while T454 happened yesterday. Corroborating small print: `docs/epistemic/CLAIMS.md:214`
still says "274 rows" over a 228-row table — even the register's own prose drifts when a
human sentence is the mechanism.

## 4. Where it blocks — ruling: `managent done`

The gate lands in `cmdDone`, ordered immediately after the deliverable-in-git check
(`src/managent/main.zig:2478-2523`) and before the phase-1 write. For `pass`,
`pass-with-findings`, and `fail-found`: run claimlint, take the C7 verdict **scoped to the
closing task's findings files**, and refuse the close while any of them is non-conforming
(named first, with the parse error) or carries an unabsorbed proposal (each named:
claim id, proposed, register-actual — the same lines claimlint already prints,
`src/claimlint.zig:1476-1484`). The refusal message prints the repair path verbatim:
run `bin/weizigo-claimlint absorb <file>`, apply or disposition, commit, `done` again.

Why here and not the other candidates:

- **Pre-commit** is the wrong granularity twice over. Mid-work commits *must* carry
  unabsorbed proposals (the file lands before the register edit; a global C7 floor would
  either block honest work or force findings+absorption into one commit for every worker,
  including ones whose scope excludes the register today). And the hook is skippable by
  design (`--no-verify`, documented in its own refusal text, `tools/hooks/pre-commit:109-110`).
  Pre-commit gets exactly one new floor — non-conforming = 0 (§6) — because *that* is
  per-commit by nature: there is no honest reason for invalid JSON to land, ever.
- **Dispatch verification** covers only dispatched workers. The Orchestrator's own rows,
  operator manual closes, and any console driven interactively bypass it. It gets the
  cheap layer (§6) but cannot be the invariant's home.
- **The duty/landmark gate** (`src/managent/main.zig:4722-4768`, T478 — built, not yet
  deployed; `docs/infra/duties.md:57-60` is already stale on this) fires only when a
  landmark is *declared*, which is rare and late. Duties verify **correctness** of claims
  one at a time (`DCLAIM`); this mechanism enforces **coherence** at every close. They
  compose; neither substitutes for the other.
- **`managent archive`** stays as the last backstop (and its parser gets the
  NON-CONFORMING fix), but archive-time is weeks after close-time and the accountable
  party is long gone — T440 measured exactly what that costs.

Every close goes through `managent done`; it is the single choke-point all paths share,
it already refuses on deliverables with no escape flag, and T440 proves such a refusal
holds in practice. **No `--skip-absorption` flag and no `--force` bypass**: an escape
valve here is the threshold reborn in another shape. If the register itself is unreadable
(claimlint exit 3), the close is refused as an infrastructure fault, same posture as the
pre-commit hook's hard requirement on a runnable claimlint (`tools/hooks/pre-commit:52-56`)
— a broken register blocks all closes, and that is the point.

## 5. Who absorbs — ruling: the closer

The party invoking `managent done` absorbs, at close time, before the close is accepted.
For a dispatched worker that is the worker; for an Orchestrator-run close it is the
Orchestrator — but per-task, at the moment of close, never as a batch.

The alternatives and what they cost:

- **The worker, at close** *(chosen)*. It has the context; the reasoning that produced the
  proposal is in-session, not reconstructed (T440's reconstruction lost it permanently).
  Cost 1: `docs/epistemic/CLAIMS.md` becomes multi-writer — this deliberately **overturns**
  the "the CLAIMS.md owner is the claims-register seat" scope rule
  (`docs/infra/dispatch/STANDING-ABSORB.md:29-30`), and the operator must ratify that.
  The guard moves from seat-ownership to lint: the same pre-commit run floors C1a/C6/C9
  and calibration on every register edit, which is a stronger guard than an owner who is
  not looking. Contention on one shared file is real but row-local edits merge; the
  T268-class hazard is already fenced by the path-limited wrapper. Cost 2:
  **self-ratification** — the worker who proposed a status absorbs it with no independent
  review. Named plainly: this mechanism enforces *coherence* (ledger agrees with findings),
  not *correctness* (findings are true). Correctness stays where it lives today — the
  `DCLAIM` duty re-verifying one claim per chunk (`docs/infra/duties.md:25`), C3's
  evidence floor, C8's mutation gate. Conflating the two would rebuild the Orchestrator
  bottleneck under a new name.
- **The Orchestrator, in batch.** This is the arrangement that has failed for months under
  three different models (§3). Ruled out by the evidence and by the operator's ruling.
- **A duty.** Late by construction — a duty becomes due after N closes
  (`docs/infra/duties.md:31`), so the gap between close and absorption is exactly the
  drift window the invariant forbids. Duties keep the *verification* role, not the
  absorption role.

Absorption is mechanically assisted: `weizigo-claimlint absorb` already emits the edit
directives (`src/absorb.zig:19-30`); the ratify step becomes "apply them or write a
rejection entry," both inside the closer's own commit. Scope machinery follows: the
task-scope resolution (`tools/git-commit-mine-lib.sh`, shared with
`tools/hooks/pre-commit:63-116`) admits `docs/epistemic/CLAIMS.md` and
`findings/rejections.json` into every task's scope, exactly as `docs/status/CURRENT.md`
and `HANDOVER.md` are admitted today (`tools/hooks/pre-commit:106-107`).

Marginal cost, measured rather than feared: T480 absorbed six entries *and* repaired a
malformed file in 3.5 minutes (added 2026-08-19T17:42:06Z, done 17:45:36Z). Amortized
per close — one or two proposals, in-context — the cost is a minute or two. The eleven
days of T440 and the months of seat-failure are the number to weigh it against.

## 6. Malformed findings fail first, everywhere

1. **Claimlint**: `nonconforming` joins the exit condition (`src/claimlint.zig:2105`),
   with the same rank as C7 itself. A file that cannot speak must fail louder than a file
   that says something wrong.
2. **Pre-commit**: new floor `C7-nonconforming = 0` in
   `tools/hooks/claimlint-floor.json`, compared like the six existing floors
   (`tools/hooks/pre-commit:265-270`). Invalid JSON never lands in a commit. (No floor on
   C7-unabsorbed itself — §4 explains why that would block honest mid-work commits.)
3. **`managent done`**: conformance is checked before absorption, so the refusal names
   the parse error, not a misleading "0 unabsorbed" (the T454 illusion).
4. **Dispatch verification**: `tools/dispatch_verify.py` parses any deliverable under
   `findings/` (JSON-load + required keys) alongside its existence check — a cheap
   worker-side early warning; the authoritative check remains at close.
5. **`managent archive`**: its C7 parser learns the NON-CONFORMING line format
   (`src/managent/main.zig:2990` vs `src/claimlint.zig:1434`) so the backstop backstops.

## 7. One count, machine-readable — kill the scraper class

Three independent scrapers of claimlint's human-readable output exist today: the
pre-commit awk (`tools/hooks/pre-commit:219-225`), the archive parser
(`src/managent/main.zig:2990-3016`), and the standing parser
(`src/managent/main.zig:6260-6278`). A cosmetic rename already killed one silently — T356
renamed a detail line and STANDING-ABSORB read 0 from 2026-08-05 on
(`src/managent/main.zig:6330-6336`). The done gate must not become scraper number four.

Claimlint therefore grows a machine-readable C7 report — `weizigo-claimlint c7 --json`,
emitting per file: path, owning task id, conforming (with reason when not), unabsorbed
proposals (id / proposed / actual), dispositioned proposals. `managent done` filters it by
task id; `archive` and `standing` re-point at it; the pre-commit awk may follow later.
One count, one implementation, consumed structurally — the T294 rule ("the count is
claimlint's own — do not reimplement it", `docs/infra/dispatch/STANDING-ABSORB.md:19-20`)
finally made mechanical.

## 8. The threshold dies

`ABSORB_C7_THRESHOLD = 5` (`src/managent/main.zig:6243`, documented at
`docs/infra/managent/spec.md:627-631`) is retired. Its own rationale
(`src/managent/main.zig:6225-6242`) was honest about the two classes — "1–4 is the
in-flight noise band" — and then set one number over both. The partition replaces it:

- **Open partition** — findings of open tasks. No gate, no alarm; surfaced as an
  informational count. With the close gate live, this is the *only* place unabsorbed
  proposals can exist, and each one is bounded by its task's lifetime.
- **Closed partition** — computed by `managent` (which knows row status; claimlint stays
  kanban-free) by joining the `c7 --json` per-task report against `tasks.json` +
  `archive.json`: any unabsorbed or non-conforming file whose task is done/failed/archived.
  Surfaced in `managent audit`; STANDING-ABSORB's trigger becomes **closed-partition > 0**
  — a crisis trigger for mechanism bypass, not a chore threshold. The
  cannot-re-fire defect (`docs/infra/orcha-doctor-2026-08-08.md:43`) is fixed in the same
  change: a triggered standing row that is done/failed re-registers.

Where this pushes back on the ruling: taken literally, "no tolerance threshold" over the
*whole* C7 gauge would demand C7 = 0 at every instant, which is the permanently-red gate
the codebase already learned to distrust (GRAND-AUDIT §1c, cited at
`src/managent/main.zig:6228-6230`): a finished-but-unclosed task legitimately carries
unabsorbed proposals for minutes-to-hours. The partition keeps the ruling's substance —
**zero tolerance on everything closed, forever** — without re-installing an alarm that
cries on healthy work and trains people to ignore it, which is how the last three
mechanisms in this area died (STANDING-C3-DEAD, T356/T294, the archive parser).

## 9. What must NOT be blocked

- **`blocked` and `abandoned` closes.** A worker reporting "I could not do this" must
  never be gated on paperwork about work that did not happen — same exemption the
  deliverable check makes (`src/managent/main.zig:2480`). `fail-found` is *not* exempt: a
  falsification is the most valuable finding there is, it already passes the deliverable
  gate today, and exempting it would price failure reports below success reports.
- **Mid-work commits carrying unabsorbed proposals.** No global C7 pre-commit floor (§4).
  Between findings-write and close, unabsorbed is the healthy state.
- **Proposing claims.** Rejection-with-reason is first-class absorption, symmetric with
  ratification, and claimlint already honours it while refusing reasonless entries
  (`src/claimlint.zig:1439-1442`). A worker must never learn that the cheap path is an
  empty `claims: []`.
- **Other tasks' closes.** The done gate is scoped to the closing task's own files. A
  global gate would let one console's drift wedge every other console — the exact
  pressure that gets a mechanism routed around.
- **The operator's unlabelled commits.** Untouched (`tools/hooks/pre-commit:174-176`);
  the only new commit-time refusal is invalid JSON under `findings/`.
- **Duty chunks.** `managent duty done` requires a findings path already
  (`src/managent/main.zig:4683-4686`); duty findings (`findings/<UID>-<date>.json`,
  `docs/infra/duties.md:51`) don't follow the `T<nnn>` convention and are out of this
  gate's scope until they have a schema of their own. Noted, not blocked.

## 10. Controls

Every arm runs on a scratch store (`MANAGENT_STORE`) + fixture register + `CLAIMS_PATH`,
per the T427 isolation rules. Home: extend `tools/regression-absorption-machinery.sh`;
the done-gate arms join the managent regression family.

| arm | setup | must |
|---|---|---|
| seeded 1 | findings file for closing task proposes a status the fixture register contradicts | `done` refuses, names claim id + both statuses |
| seeded 2 | findings file is invalid JSON | `done` refuses with the parse error; pre-commit refuses the commit (non-conforming floor) |
| seeded 3 | findings file missing `task_id` | same refusals, reason names the key |
| seeded 4 | absorbed close, then register row hand-edited away from it | closed partition reads 1; STANDING-ABSORB triggers; `managent audit` names the file |
| null 1 | proposal matches the register | close passes |
| null 2 | mismatched proposal + reason-carrying rejection entry | close passes (rejection is absorption) |
| null 3 | *another* task's unabsorbed finding present | this task's close passes (scope control) |
| null 4 | `blocked` close with a malformed findings file present | close passes (exemption holds) |

The proposal-vs-register comparison itself is not re-proven here: it is claimlint's, which
carries built-in synthetic calibration (known-bad 6 / known-good 7 / multi-row 8,
`src/claimlint.zig:1867-1951`) and runs that calibration on every invocation — the done
gate inherits it by consuming claimlint's verdict instead of reimplementing the count.
Per "never trust a green test": seeded arms land and are seen red before the gate's first
live refusal is believed.

## 11. Migration — the backlog, and the honest current state

The brief's numbers moved while it was in flight, and that must be recorded: C7 was 6 with
one non-conforming file when the operator ruled; **T480 drove both to 0 the same evening**
(claimlint today: `unabsorbed: 0`, `non-conforming: 0`, 346 files scanned). So there is no
absorption backlog to migrate through *today* — there is a clean state to freeze before it
drifts again, which it will within days without the gate (it was clean on 2026-08-06 too:
`tools/hooks/claimlint-floor.json` note, "C7 1 → 0").

Order of flips (each a registered task, §13):

1. **Claimlint first**: `c7 --json` + non-conforming joins the exit condition + calibration
   arms. No behaviour change for anything downstream yet.
2. **Pre-commit floor** `C7-nonconforming = 0` — safe immediately, the reading is 0.
3. **`managent done` gate** + repair-path refusal text. Deploys with the duty verbs
   (T478's binary is built but `bin/managent` predates it — one deployment, drained fleet).
4. **Partition + trigger**: `managent audit` closed-partition; STANDING-ABSORB re-pointed
   at closed-partition > 0; re-fire defect fixed; `ABSORB_C7_THRESHOLD` deleted.
5. **Prose the mechanism obsoletes, deleted in the same commits** (process doctrine:
   prose is not a remedy, and stale prose is anti-remedy): the threshold language and
   the CLAIMS.md-owner scope rule in `docs/infra/dispatch/STANDING-ABSORB.md:5-13,29-30`
   (the standing brief survives, re-scoped to the crisis trigger);
   `docs/infra/managent/spec.md:627-631` re-written to the partition; the
   "Not yet built" section at `docs/infra/duties.md:57-60` (already stale — T478 landed);
   the stale "274 rows" prose at `docs/epistemic/CLAIMS.md:214` re-pointed at the
   authoritative print it already defers to.

**History gets an epitaph, not an audit.** The 347-vs-228 relationship is stated in §1 and
becomes part of `findings/README.md`. Pre-gate findings files whose tasks closed under the
old regime are declared *absorbed-as-of-2026-08-19* by the C7=0 reading itself — that is
what the reading means — and are not re-adjudicated. Files needing pure syntax repair, if
any resurface, follow the T480 precedent (`b00b9b2`: in-place repair is not a verdict
change and does not violate the immutability rule; a changed *verdict* is a new task,
`findings/README.md:12-14`).

## 12. What this costs, stated for the record

- **A claimlint red wedges every close.** Deliberate; same posture as pre-commit. The
  register being unlintable is a stop-the-line event.
- **CLAIMS.md becomes multi-writer** (§5, cost 1). Requires the operator to ratify
  overturning the register-seat ownership rule. Guarded by lint, not by a seat.
- **Coherence, not correctness** (§5, cost 2). A wrong proposal, self-absorbed, enters the
  register as a wrong row — visible, cited, and subject to DCLAIM/C3/C8, but wrong. This
  spec does not claim otherwise.
- **Close gets slower by one claimlint run** (~seconds; it already runs per-commit) plus,
  when proposals are pending, the minutes the absorption takes (T480: 3.5 minutes for six).
  That cost lands on the party with the most context, at the moment they have it.
- **The gate depends on the naming convention.** A findings file that misnames its task id
  escapes the task-scoped check — but not the closed-partition alarm, whose join is by
  filename-derived id against *all* closed rows, so a misnamed orphan surfaces there.

## 13. Implementation tasks (to register; none executed under T481)

| # | work | surface |
|---|---|---|
| 1 | `c7 --json`; non-conforming → exit condition; calibration arms | `src/claimlint.zig` |
| 2 | non-conforming floor | `tools/hooks/pre-commit`, `tools/hooks/claimlint-floor.json` |
| 3 | done gate + refusal/repair text; controls | `src/managent/main.zig` (cmdDone), `tools/regression-absorption-machinery.sh` |
| 4 | scope: CLAIMS.md + rejections.json into task scope | `tools/git-commit-mine-lib.sh` |
| 5 | closed partition in audit; STANDING-ABSORB re-point; re-fire fix; delete threshold | `src/managent/main.zig` |
| 6 | archive parser NON-CONFORMING fix | `src/managent/main.zig:2990` |
| 7 | dispatch_verify parses findings deliverables | `tools/dispatch_verify.py` |
| 8 | prose deletions/rewrites of §11 step 5 | docs |
