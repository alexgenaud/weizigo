# Open hypotheses — the register coming out of the 2026-07-27 chainability finding

**Opened:** 2026-07-27. **Board:** 4×4 unless stated; per AGENTS.md nothing here
inherits to 5×5. **Scores are Black-positive throughout.**

On 2026-07-27 `bin/weizigo-chainability` measured that the committed tables are
*chainable* — the history-free Bellman identity `V0(P,s) == best_s({V0(child,-s)}
∪ {V1(P,-s)})` holds — with **zero** violations outside the KO_SENSITIVE flag at
2×2/3×2/3×3/4×3/4×4, and that every violation inside the flag is one of the
independent fresh-start solves that C2's falsification predicts (max gap = 2n =
the whole board swing). The same session found that on 4×4 the empty board is
*itself* KO_SENSITIVE and 16 of 19 plies of both saved regression games are
flagged, while positional-superko bans changed the best available value at 0 of
19 plies. Together those two facts move the diagnosis: the GTP player is not
mis-applying the ko rule and is not (necessarily) reading a wrong number — it is
chaining numbers that were never defined to chain, from move one. That turns the
work item from "fix the player" into "fix the state representation", because a
Markovian `(position, side)` table has nowhere to store what a non-Markovian rule
depends on. Source finding: `docs/research/ko-sensitive-chainability.md`.

This file is a **work queue**. Each entry is designed to be actionable by a fresh
agent who reads only this file plus the documents it cites.

Status markers (as in `docs/epistemic/boards/4x4/EPISTEMIC.md`):
✅ proven · ⬜ untested · 🟡 partial/in progress · ❌ falsified · ⛔ intractable.
Epistemic tags: **PROVEN** / **CLAIMED** / **FALSE-AS-SCOPED**.

---

## H1 ⬜ **CLAIMED** — the simple-ko pivot: one mismatch, not five problems

**Claim (an interpretation, not a theorem).** Every symptom the project is
fighting — C2 (single-score history-independence, falsified at 3×2, T13
2026-07-26), C3 (bracket bounds the real-game score, FALSE-AS-SCOPED at 3×3, E2),
C4 (fresh-start ≠ real-game on ko-sensitive slots), the leak crisis, and the
2026-07-27 chainability collapse of the GTP player — follows from **one**
mismatch: **positional superko is a non-Markovian rule** (legality depends on
unbounded history) while the project stores a **Markovian** table for it. Under
**simple ko + long-cycle ties**, the state `(position, side_to_move, ko_point)`
is Markovian, so a table over that state would be chainable **by construction**:
no graph-history interaction, no fresh-start/real-game gap, and the greedy child
comparison `Session.choose` (`src/gtp.zig:154`) already performs becomes a
correct one-ply minimax rather than an extremum over incomparable premises.

Two supporting points, both already in the repo:

1. **This is the published-anchor ruleset.** MIGOS II (van der Werf & Winands,
   ICGA Journal 2009) plays basic ko + long-cycle-ties, not superko — recorded at
   `docs/research/retrograde-3x3.md` ("Published anchors vs the PSK ruleset") and
   `docs/research/retrograde-4x4.md` (anchors section). So a simple-ko table
   would be **directly** comparable to the published 4×4 **+2**, instead of
   agreeing with it by luck. It also hands us a free falsification target: the
   two rulesets are *known to disagree* at 2×2 and 3×2 (published 0 / 0 vs
   weizigo's exhaustively ground-truthed PSK +1 / +1). A correct simple-ko build
   must reproduce **0** there, not +1.
2. **The decision is already recorded; only the execution is missing.**
   `docs/epistemic/PROGRESS.md` records (2026-07-24) that PSK is abandoned as the
   *generation* rule and basic/simple ko is the tractable candidate, and
   `docs/research/ruleset-options.md` §Plan item 1 names SIMPLE ko + area as the
   leading generation rule. **But the 4×4 artifact and the GTP player are both
   still PSK.** H1 is unexecuted work, not a new idea.

**Experiment (cheap, go/no-go — run this FIRST).** Census the **reachable**
`(position, ko_point, side)` triples at 4×4. A ko point exists only immediately
after a move that captures exactly one stone whose capturing stone then has
exactly one liberty (the vacated cell) — the basic-ko shape that
`src/ko_census.zig` already detects. So the reachable set is far smaller than the
naive product: enumerate legal positions with `src/enumerate.zig`, and for every
legal position `Q` and every legal move by `-side` from `Q` that lands in the
basic-ko shape, mark the resulting `(P, side, ko_point)` as reachable; mark
`(P, side, none)` for every position reachable by a non-ko move or as a root.
`src/settled_census.zig` is the model for a single-pass census harness.
Instrumentation only — no `src/retro.zig` edit, so this does not contend for the
one-writer-per-engine-file lock.

**Acceptance.** Report (a) the exact reachable-triple count; (b) the exact count
of distinct `(position, ko_point)` **addresses**, which is what a dense artifact
must index; (c) the implied artifact size at 6 columns of 1 byte. Reference
points for (c): the current PSK 4×4 artifact is `32 + 6 × 3^16 = 258,280,358`
bytes on disk (`data/oracle-4x4.checkpoint.wzo`, verified 2026-07-27), and the
naive dense bound is `3^16 × 17 = 731,794,257` addresses × 6 B = **4.39 GB**,
i.e. 17× the current artifact. The expected result is a *small* multiple of the
48,636,330 `(position, side)` slots. **GO** if the implied artifact fits the
machine's confirmed budget (the D3 placeholder in
`docs/epistemic/boards/4x4/EPISTEMIC.md` `[T07-9]` is ≤ 32 GB, still marked
"confirm with user"); **NO-GO** otherwise, and then say what the next
representation candidate is.

**Do NOT conclude** that simple ko "solves" anything until the census returns
**and** the long-cycle question below is settled.

> **UNSETTLED DESIGN QUESTION (flag it in any write-up).** Simple ko alone does
> **not** terminate long cycles — triple ko, eternal life. "Long cycle = tie" is
> *plausibly* a loopy-game fixpoint (L/H value iteration with loops pinned to the
> tie value rather than to ±N), which would make it computable by the existing
> converge machinery. **This is UNVERIFIED and must not be asserted.** It needs
> its own derivation and its own falsification test before it can be built.
> Constraint on any candidate resolution rule: `score-on-cycle` is **foreclosed**
> — `RETRO_CYCLE` measured byte-identical state counts to PSK (118,475,182 at
> 2×2; 116,114,272 at 3×2; `docs/research/ruleset-options.md`), so it is exactly
> as hard as PSK. A "long-cycle tie" rule must resolve the cycle **without
> needing to know which earlier boards were seen**, or it has smuggled
> score-on-cycle back in and is dead on arrival.

**Cost.** Census tool: ~200 lines on top of `src/ko_census.zig` /
`src/enumerate.zig`; estimate 2–4 h to write. Run: a single pass over the same
address space `bin/weizigo-chainability` sweeps in 0.84 s CPU at 4×3 (531,441
colex slots, measured 2026-07-27), so minutes to ~1 h at 4×4 under ReleaseFast.
Memory: a reachability bitset over `3^16 × 17 × 2` bits = **183 MB** — fits
trivially. This is the cheapest entry in the register by an order of magnitude.
(A full simple-ko retrograde build is *not* costed here; the census is the
go/no-go that decides whether costing it is worth anyone's time.)

**Depends on.** Nothing. Independent of every other entry.

**Also note.** A GO here requires a **new ADR** once the user scopes it — ADRs
are append-only, and this would supersede the PSK generation assumption of
ADR-0003 / ADR-0009. **Do not write that ADR.** The decision is the user's.

---

## H2 ⬜ **CLAIMED** — the greedy player's loss rate exceeds the arena's random-persona leak rate

**Claim.** The B43 clean arena leak rate — **3.4% / max 32 pts** over 3,600 games
(`docs/research/arena-4x4-undef.md`, `bin/weizigo-arena
data/oracle-4x4-parallel.checkpoint.wzo 100`) — is a **lower bound** on the
greedy GTP player's loss rate, not an estimate of it. Reason: a random selection
among believed-optimal children samples ko-sensitive mispricings roughly
uniformly, whereas the greedy extremum in `Session.choose` systematically selects
the child whose false fresh-start premise is most flattering.

**Experiment.** Run the arena twice on the same artifact and the same seed set,
varying only the audited side's policy. The lever already exists: `src/arena.zig`
audits with a **uniform random pick among value-tied best children** by default
(the "belief audit" branch, `src/arena.zig:220`), and with **exactly the GTP
player's policy** — `Session.choose`, min-DTT tie-break — under the `det` flag
(`src/arena.zig:210`). So:

```
bin/weizigo-arena data/oracle-4x4-parallel.checkpoint.wzo 100        # random tie-break
bin/weizigo-arena data/oracle-4x4-parallel.checkpoint.wzo 100 det    # greedy / Session.choose
```

Compare CLEAN-LEAK rate and max leak magnitude, per persona and in total.
**Caveat to check before trusting the comparison:** both branches maximise the
stored child value, differing only in *tie-break*. If that turns out to be too
weak a contrast to express the claim, the honest fix is a new audited policy that
maximises the child value with no UNDEF skip and no DTT damping — a small,
clearly-scoped `src/arena.zig` change — and the run must then be reported as
measuring *that* policy, not `det`.

**Acceptance.** Greedy CLEAN-LEAK rate **strictly exceeds** random on the same
artifact and seed set ⇒ claim supported, and the 3.4% figure must be relabelled
as a lower bound wherever it is quoted. Equal or lower ⇒ the selection-bias claim
is **falsified**, and 3.4% / max 32 pts may be quoted as-is for the greedy
player.

**Cost.** Very low. Zero code change if `det` suffices; ~1 h and one
`src/arena.zig` edit if a dedicated greedy policy is needed. Two arena runs of
3,600 games each.

**Depends on.** Nothing. Fully parallel with everything else.

**Do NOT conclude** anything about *why* the greedy player leaks from this run
alone — it measures a rate difference, not the mechanism. The mechanism claim
stays CLAIMED regardless of the outcome.

---

## H3 ⬜ **UNMEASURED** — a mid-game tractability crossover for history-exact search

**Context, so nobody re-quotes the wrong number.** The 2026-07-27 re-measurement
of memo-free history-exact search (empty 2×2 = 2.3M nodes / 132 ms; empty 3×2 did
not finish in 100 s) is a **lower bound on achievable performance**, not a
measurement of the method: that probe was a scratch instrument using a **linear
history scan** — O(depth) per node, quadratic on long lines — and it used neither
`src/zobrist.zig` nor the `scount`/`armed` pruning in `src/superko.zig:97-121`,
which can reject a repetition without any scan on an un-armed (capture-free)
line. The repo's own **>5×10⁸ nodes, abandoned (146 s)** figure for the **empty**
4×4 root stands (`docs/research/retrograde-4x4.md`, driver table) and is not in
question here; the open question is about mid-game roots.

**Claim.** There is an empty-point count below which memo-free, bracket-free,
history-exact 4×4 search under the game's **real** history is affordable at play
time.

**Experiment.** Implement the search properly: Zobrist-hashed superko detection
(`src/zobrist.zig`) plus the `scount`/`armed` prune (`src/superko.zig`), no
cross-branch memo (ADR-0013 proved the `ko_ref >= d` guard unsound) and no [L,H]
cuts (that is H5(c) / C3). Then measure nodes and wall time as a function of
empty-point count on **real** 4×4 mid-game positions: the two saved regression
games (`regressions/4x4-black-win-after-ko.txt`,
`regressions/4x4-history-blunder.gtp`) supply 38 real positions with their real
histories, 19 plies each.

**Acceptance.** Report the empty-point count at which **median wall time crosses
1 s** and at which it crosses **10 s**, with node counts alongside. If the 1 s
crossover sits at **≥ 8 empty points**, a hybrid player — table on the chainable
(L==H) region, exact search once the board is empty-poor — is buildable as a
stop-gap and **should be proposed** to the user as H5(b)'s concrete form. Below 8,
report the number and say so plainly; do not dress up a negative.

**Cost.** Medium: 1–2 days to build the instrumented search (new file; do **not**
edit `src/retro.zig`, `oracle.zig`, `rules.zig` or `solve.zig` for this — the
one-writer rule applies and this needs none of them). Measurement sweep: hours,
and it must be run with a per-position node/time budget so a single hard position
cannot turn the sweep into a black box.

**Depends on.** Nothing to start. **Gates H5(b).**

**Do NOT conclude** anything about 5×5 — per-board epistemic independence. Also
do not conclude that a favourable crossover makes the *table* sound; it makes a
*player* sound on the searched region only.

---

## H4 🟡 **PARTIAL** — FP1 acceptance check 3 has two residual gaps

**Claim.** FP1 acceptance check 3 (the V0/V1 Bellman identity) now **PASSES** for
the shipped `vb`/`vw` columns — zero identity violations outside the KO_SENSITIVE
flag at 2×2/3×2/3×3/4×3/4×4 (M4, 2026-07-27) — but two gaps remain before FP1's
check 3 can be marked ✅ without a caveat:

- **(a) Wrong table.** M4 validated the *shipped value columns*. The WZO1 format
  (ADR-0011) carries six columns — `vb`, `vw`, `fb`, `fw`, `db`, `dw`
  (`src/artifact.zig:27-33`) — and **no bracket columns**. The literal `lo`/`hi`
  form of the check therefore still needs the in-memory retrograde tables
  (`Retro(w,h).Tables.lo` / `.hi`, `src/retro.zig:107-113`) and remains ⬜.
- **(b) Sampled, not exhaustive.** 4×4 was a **1:37 colex stride** (657,566
  positions, 1,313,248 slots). 4×3 and below were exhaustive.

**Experiment.**
- **(a)** After a 4×4 build, run the same V0/V1 identity check directly against
  the in-memory `Retro(4,4).Tables` `lo` and `hi` quads, before they are projected
  into `vb`/`vw`.
- **(b)** `bin/weizigo-chainability data/oracle-4x4.checkpoint.wzo` with **no
  `--sample`** — the tool's default stride is 1, i.e. exhaustive over the ~43M
  colex address space (`src/chainability.zig:54-58`).

**Acceptance.** **Zero** violations outside the KO_SENSITIVE flag in both. Per the
existing FP1 rule in `docs/epistemic/boards/4x4/EPISTEMIC.md`: **any single
violation outside the flag falsifies FP1 ⇒ STOP.** Violations *inside* the flag
are expected and are not evidence of anything (each such slot is an independent
fresh-start solve; C2 restated per-slot). A clean (b) also removes the sampling
caveat from M4.

**Cost.** **(b) is one command and the cheapest experiment after H1's census** —
4×3 exhaustive is 0.84 s CPU for 531,441 colex slots (measured 2026-07-27), and
4×4 is 81× that address space at somewhat higher per-slot cost, so estimate a few
minutes; ~258 MB resident to hold the artifact. **(a) is expensive** because it
needs an in-memory 4×4 retrograde build (see D3 in the 4×4 epistemic tree:
placeholder budget 8 h / 32 GB, unconfirmed); the check itself is minutes once
the tables exist.

**Depends on.** (b): nothing. (a): a 4×4 build — fold it into whichever regen is
already scheduled (F2/F3 writes-off) rather than spending a build on it alone.

**Do NOT conclude** that a clean result promotes the L==H region to *real-game*
correctness. Chainability is a statement about the table's internal consistency
under a history-free identity; C2 is falsified at 3×2 and the L==H values remain
fresh-start correct (C1) only.

---

## H5 ⬜ — player hardening, requiring no new epistemics

**Claim.** The GTP player can be made to stop asserting mispriced numbers
**without resolving any open epistemic question**. Three options, presented
neutrally with their costs — **the choice is the user's**, and it is a
deliverable decision, not an engineering one.

**(a) Restrict table steering to the chainable L==H region.** Steer by stored
values only where the flag is clear; elsewhere use a history-free quantity
(settled area score, or Benson-alive territory via `src/rules.zig` /
`src/terminal.zig`). *Sound* — M4 measured zero identity violations outside the
flag. *Weak* — on 4×4 the empty board is itself KO_SENSITIVE (M5), so this player
has **no table guidance from move one**. That is the honest consequence of a
fresh-start-only deliverable, not a bug in the option.
*Cost:* low; a guard in `Session.choose` plus a fallback evaluator, ~1 day.

**(b) History-exact search to a Benson-settled horizon.** Once a position is
Benson-settled its area score is history-free **by theorem**, so terminating the
search there is sound. *Cost:* gated on H3's open measurement — unknown until
that number exists; the search itself is H3's deliverable plus a horizon test.

**(c) Bracket-cut search.** Tractable: ≤3.5×10⁵ nodes for the empty 4×4 root
versus >5×10⁸ without, whole ko-sensitive region finished in 6.1 min at ~1,663
nodes/rep (M3; `docs/research/retrograde-4x4.md`). **But cutting on [L,H] under a
real history *is* claim C3, and C3 is FALSE-AS-SCOPED at 3×3** (E2: 25/4000 games
leaked, promise +3 → final −9). **NOT shippable as sound.** It is listed only so
that its 1,400× speed advantage is not rediscovered and mistaken for a solution.

**Acceptance.** Whichever option is chosen: the player must never print or act on
a KO_SENSITIVE stored value as if it were an evaluation. A concrete regression:
replay `regressions/4x4-black-win-after-ko.txt` and
`regressions/4x4-history-blunder.gtp` and confirm the hardened player does not
reproduce the ply-16 −16 → +16 reversal.

**Cost.** (a) ~1 day. (b) H3 + ~1 day. (c) not to be built.

**Depends on.** (b) depends on **H3**. (a) and (c) depend on nothing. None of the
three depends on H1 — H5 is the stop-gap while H1 decides the long-term
representation.

**Gate (mandatory, per AGENTS.md).** Any change to the ko/finisher path requires
a **passing #2 self-consistency auditor run** — zero minimax-identity violations
on 3×2 exhaustive plus the deepest-N 4×4 sample — **before commit**. "Sound by
construction" without an auditor run is insufficient; the `ko_ref >= d` bug
(ADR-0013) looked obviously correct and was wrong.

**Do NOT conclude** that a hardened player validates the table. A player that
declines to quote a number is *silent*, not *right*.

---

## Dependency and ordering

```
H1 census ──(GO/NO-GO)──▶ [user scopes a new ADR; long-cycle rule still open]
H2 arena  ──────────────▶ relabel or retire the 3.4% figure
H4(b) exhaustive ───────▶ removes M4's sampling caveat
H4(a) ── needs a 4×4 build ──▶ fold into the F2/F3 writes-off regen
H3 crossover ───────────▶ gates H5(b)
H5(a), H5(c) ───────────▶ independent of everything above
```

- **Serial:** H3 → H5(b) (the crossover number decides whether the hybrid player
  is buildable). H4(a) → a 4×4 retrograde build → which is itself gated on D3
  feasibility, so H4(a) should ride along with the already-planned F2/F3 regen
  rather than claim a build of its own. H1's GO → a new ADR → any simple-ko
  generation work (and the long-cycle resolution rule must be settled *before*
  that build, not during it).
- **Parallel:** H1, H2, H4(b), H3, and H5(a) are mutually independent. None of
  them edits `src/retro.zig`, `oracle.zig`, `rules.zig` or `solve.zig`, so none
  contends for the one-writer-per-engine-file lock; H2's optional policy change
  and H5(a)'s guard touch `src/arena.zig` and `src/gtp.zig` respectively and
  should each declare an intent line in `docs/status/CURRENT.md` per the
  concurrency protocol.
- **Run first: H1's census.** It is the cheapest thing in the register (~183 MB,
  minutes of wall time, no build, no engine-file lock), it is the only entry that
  can change the project's *direction* rather than its *confidence*, and every
  other entry is work on a representation H1 may retire. A NO-GO is equally
  valuable: it closes the last named tractable-generation candidate and forces
  the representation question back to the user immediately, instead of after
  another build cycle.
- **Run second: H4(b).** One command, a few minutes, and it upgrades the
  headline 2026-07-27 result from "1:37 sample" to "exhaustive".

## Cross-references

- `docs/research/ko-sensitive-chainability.md` — the source finding (M4, M5).
- `docs/epistemic/boards/4x4/EPISTEMIC.md` — FP1, D3, F2/F3/F4, the wave plan.
- `docs/research/ruleset-options.md` — the ruleset pivot; kill-X% and
  score-on-cycle foreclosures.
- `docs/research/retrograde-3x3.md` / `retrograde-4x4.md` — the MIGOS II
  ruleset note and the published anchors.
- `docs/research/arena-4x4-undef.md` — the 3.4% clean leak rate (B43).
- `docs/status/leak-crisis.md` — C2/C3/C4.
- `AGENTS.md` — foreclosures and the #2 auditor gate.
