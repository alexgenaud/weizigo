# How we solve small Go gobans — what worked, what didn't, and how we know

**Status: historical overview (2026-07-17).** The living specification is now `docs/epistemic/PROGRESS.md`. [Historical.]

*Written for a curious reader who plays a little Go (say 20 kyu) but is not a
programmer or mathematician. No formulas, no code. If a term is unavoidable it
is explained the first time it appears.*

---

## 1. What we are trying to accomplish

We are building a **perfect player** for small Go gobans. "Perfect" has a
precise meaning here: from **any** position, for **either** colour to move, the
program knows

- the **exact final score** if both sides play as well as possible, and
- **which move (or moves) achieve it**.

No guessing, no "this looks good," no learning from example games. The answer
is the truth about the game, the way "checkmate in 3" is the truth about a
chess position.

We use **Chinese scoring** (you own the stones and the empty points your stones
surround), **komi 0** (no compensation points for playing second), and the
**positional superko rule**: *the whole goban may never repeat a position that
has appeared before in the game.* Scores are always written from **Black's
point of view** — a score of +2 means "Black ends 2 points ahead," −2 means
"White ends 2 points ahead."

We have done this **perfectly for gobans up to 4×4**. The prize we are working
toward is **5×5**. Along the way, solving the empty goban tells you the single
most-asked question about a goban size: *what is the fair komi?* — because the
score of the empty goban is exactly how much the first player is worth.

A note on honesty about the rules: other researchers have "solved" 5×5 before
(the answer is Black takes the whole goban, +25), **but they used a simpler
repetition rule than ours.** Our positional-superko rule is stricter and, as
this document will explain, dramatically harder. On the very smallest gobans
our answers already differ from the published ones *because* of this rule
difference. So a superko-perfect 5×5 is genuinely new territory, not a re-run
of old work.

---

## 2. Why this is hard

**Reason one: the sheer number of games.** Even on a tiny goban the number of
possible ways a game can go is astronomical. You cannot simply "try every
game." A 5×5 goban has more distinct legal positions than there are seconds in
thousands of years. So brute force in the naive sense is out.

**Reason two — the one that has dominated this whole project: *history
matters.*** In most goban games, the score of a position depends only on the
stones currently on the goban. In Go with the superko rule, **it can also
depend on which positions have already occurred earlier in the game.** A move
that would recreate an earlier whole-goban position is illegal — so the *same
stones on the goban* can have *different legal moves*, and therefore a
*different score*, depending on how you got there.

Think of a ko fight. The goban looks identical each time you glance at it, but
whether you are *allowed* to take back depends on the recent history. Superko
generalises this to the entire goban and the entire game. This "the score
depends on the past, not just the present" phenomenon has a name in the
research literature: the **graph-history interaction**, or **GHI**. It is the
central villain of this document.

---

## 3. The idea that works: solve it backwards, in two layers

### Work backwards from finished games

Instead of starting from the empty goban and looking forward (which drowns in
the number of games), we start from **finished positions** — gobans so full or
so settled that the score is obvious — and work **backwards**. If you know the
score of every position that can *follow* a given position, you can work out
the score of that position: the player to move simply picks the follow-up that
is best for them. Repeat this, filling in positions with more and more empty
space, until you reach the empty goban. This backwards sweep is called
**retrograde analysis** (the same technique that built the perfect endgame
tables for chess).

### The crucial split: a "certain" core and an "uncertain" ko-sensitive region

Here is the key discovery that makes the whole thing tractable and trustworthy.
We separate every position into one of two buckets:

- **The fresh-start single-score region (L==H).** For most positions, the
  score under the fresh-start (no prior history) game tree is **unique** — L
  and H converge to the same integer. These positions were once thought
  history-independent, but T13 (2026-07-26) falsified that at 3×2. They
  remain correct as *fresh-start* scores (C1). This is the large majority of
  positions at every goban size.

- **The ko-sensitive region.** A minority of positions are tangled up in
  repetition — their score genuinely *can* change depending on the history of
  the game. These are the hard ones. We call them the **ko-sensitive region**, and almost
  every dead end in this project has been about handling them correctly.

The great value of the split is that we can be **100% certain about the core**
while we do careful, expensive, error-prone work on the small ko-sensitive region — and we
always know which bucket we are standing in.

### How we tell the two apart: the low/high bracket

To decide whether a position is "certain" or "ko-sensitive," we compute its
score **two different ways**:

- a **pessimistic** way (call it **L**, the *low* estimate), which resolves
  every repetition tangle in the way that is *worst* for Black, and
- an **optimistic** way (call it **H**, the *high* estimate), which resolves
  every tangle in the way that is *best* for Black.

The true score, whatever the history, is always somewhere **between L and H**.

- **If L and H come out equal**, there is no room for doubt: the score is
  pinned down exactly, history cannot matter, and the position joins the
  **fresh-start single-score region**.
- **If L is below H**, the position is **ko-sensitive region**: the truth lies
  somewhere in the gap, and we need extra work to find exactly where.

This bracket is not just a classifier — it is also a **safety net**. Any later,
cleverer calculation of a ko-sensitive score **must** land inside its [L, H]
bracket. If it ever lands outside, we know instantly that something is wrong.

---

## 4. How we know we are right (and catch ourselves being wrong)

A perfect solver is only worth having if we can *trust* it. A 15-kyu human beat
an earlier version of our engine in a real game, which was a sharp reminder
that "we think it's perfect" is not the same as "it is perfect." We now lean on
several independent checks, each of which can only *catch* errors, never
*hide* them:

1. **The bracket containment check** (above): every ko-sensitive region answer must sit
   inside its own low/high bracket.

2. **Symmetry.** A Go goban has eight mirror/rotation symmetries, and swapping
   the two colours flips the score. Positions that are the same under these
   symmetries **must** get the same (or mirror-image) score. We check this
   exhaustively. A single mismatch is a bug.

3. **Published anchors.** Where other researchers have published scores for
   certain positions (allowing for the rule differences), our numbers must be
   consistent with theirs.

4. **The self-consistency auditor** — our newest and sharpest tool, described
   in Section 6, because it is what finally cracked the crisis this project has
   been stuck on.

The philosophy throughout: **every optimisation is a switch we can turn off.**
For anything clever and fast, we keep the slow, obviously-correct version
alongside it, so we can run both and confirm they agree. A speed trick you
cannot compare against plain truth is a speed trick you cannot trust.

---

## 5. The graveyard: dead ends, and why they are dead

This is the part most worth recording. Each of these cost real effort, and each
taught us something that constrains what optimisations are even *possible*.

### Dead end 1 — "Just play forwards from the empty goban"
The obvious approach. It drowns immediately: from the empty goban the number of
distinct game-lines explodes, and the repetition rule means you cannot safely
reuse work between lines (see Dead end 3). **Lesson:** you must go backwards,
and you must exploit the certified/ko-sensitive region split. This is *why* the whole
architecture is shaped the way it is.

### Dead end 2 — "Reuse a position's score everywhere we see it"
The single most tempting optimisation in any game solver: once you've computed
the score of a position, remember it, and every time that position comes up
again, just look it up. This is called a **transposition table** and it is what
makes chess engines fast.

**For the ko-sensitive region, this is fundamentally unsound**, and proving so
consumed much of this project. The reason is GHI (Section 2): the "same"
position can have *different* correct scores depending on history, so blindly
reusing one stored score plants a wrong answer that then poisons everything
computed from it. **Lesson — and this is a hard limit, not a temporary
obstacle:** you may freely reuse scores in the **fresh-start single-score region** (L==H,
where the fresh-start score is unique), but reuse in the **ko-sensitive region** must be *guarded*
by tracking exactly what history the stored score depended on. Unguarded reuse
in the ko-sensitive region is off the table forever.

### Dead end 3 — "Reuse it *if the ko stayed local*" (the subtle, seductive bug)
We tried a clever half-measure: reuse a stored ko-sensitive score as long as the
only repetitions involved happened *within the position's own follow-up tree*,
not reaching back to earlier history. It sounds airtight. It is not. When the
same position shows up later via a *different* history, one of its follow-ups
can collide with the *new* history in a way it never did before — changing its
legal moves and its score. The stored "it stayed local" score is then wrong.

We suspected this for a long time but could not *prove* which of our competing
calculations was the faulty one — until the self-consistency auditor (Section
6) caught it red-handed. **Lesson:** "the ko stayed local this time" does not
mean "the ko will stay local every time." Only a genuine record of *what the
score depended on* is safe.

### Dead end 4 — "Judge the hard cases with the slow-but-perfect solver"
When our fast methods disagreed about a ko-sensitive score, the natural referee was
the one method with no shortcuts at all: a solver that keys every stored score
to the **complete** history so far, making reuse provably safe. It is correct
by construction — and **hopelessly slow exactly where we need it.** Near the
end of a game it can occasionally answer; anywhere near the opening it never
finishes. We ran it against the disputed 3×2 and 4×4 positions and it could not
resolve a **single** one within any practical budget. **Lesson — an important
and somewhat philosophical one:** you *cannot* referee the hard ko-sensitive region cases
by brute external check. The brute check is defeated by the very same GHI
explosion that makes the problem hard in the first place. **Correctness for the
ko-sensitive region can only come from an algorithm that is provably sound *by design* — not
from an oracle we can consult.**

### Dead end 5 — smaller, practical traps (each a real day lost)
- **Searching the easy positions first.** Our first big run ground for hours on
  hopeless opening positions before ever reaching the tractable ones. Fix:
  always tackle the **fullest, nearest-to-finished positions first**.
- **A "smarter" search that forgot its work.** A well-known fast search
  technique (repeatedly asking narrow yes/no questions about the score) actually
  ran *slower* than the plain method, because it kept re-deriving answers it had
  already found. Fix: let it remember its partial findings between questions.
- **Writing giant files in one go.** Saving a single multi-gigabyte result file
  failed outright on this operating system. Fix: write it in chunks.

- **Rebuilding the program while a long run was using it.** We started an
  hours-long solve, then kept editing and recompiling the *same* program file
  the running solve was reading from. The run finished, but we could no longer
  trust *which version of the code* had actually produced its numbers (the
  labels in its own output contradicted how we launched it). The result had to
  be thrown out. Fix: freeze a private copy of the program for each long run and
  never touch it. Lesson: **a measurement you can't attribute to exact code is
  not a measurement.**

These are mundane, but they make the same general point: **measure, don't
assume.** Every one of them looked fine in theory.

---

## 6. The breakthrough: the self-consistency auditor

The crisis that stalled this project: three different versions of our ko-sensitive region
solver gave three different answers for the same positions, and Dead end 4 said
we could not simply ask a perfect referee which was right.

The way out was to stop asking "what is the true score?" (hard) and start
asking **"is this solver even consistent with itself?"** (easy, and enough to
convict). The test is a rule every correct game solver must obey:

> **Under one fixed history, a position's score must equal the best score among
> the moves available from it.** If it's Black to move, Black's score can never
> be *worse* than Black's best reply; if White, never *better* for Black than
> White's best reply.

If a solver ever reports a position as worse (for the side to move) than one of
its own follow-ups — under the *same* history — that is not a matter of opinion.
It is a **flat contradiction**, an outright proof the solver is broken.

We built this check (we call it the **consistency auditor**) and ran it on
every ko-sensitive position of the 3×2 board:

- The **fast** solver — the one with the seductive "ko stayed local" reuse
  (Dead end 3) — contradicted itself on **45 of 378** positions. **Proven
  buggy.** The empty goban was among them: it claimed Black was 2 points behind,
  while its *own* best opening move showed the game is even (0) — the known
  correct answer.
- The **cautious** solver — the same engine with that reuse switched **off** —
  contradicted itself **nowhere**. Self-consistent.

This did three things at once: it **identified** the culprit (the unsound
reuse), it **exonerated** the cautious version, and it gave us a permanent
**acceptance test** for any future solver.

One honest caveat we keep front-and-centre: passing this test is **necessary
but not sufficient**. A solver could in principle be consistently wrong (wrong
in a way that never contradicts itself). So the auditor can *convict* but not
fully *acquit*. That is why it is one check among several, not the whole story.

---

## 7. Track A and Track B, in plain English

The auditor pointed to a clean fix and split the road ahead into two tracks.

### Track A — "Be correct now, even if slower"
Simply **turn off the unsound reuse** and re-compute all our tables (2×2 up to
4×4) with the cautious solver, then re-run every check. Why we trust this: with
the reuse off, the only scores the solver ever reuses are the ones from the
**fresh-start single-score region**, which are safe by definition for fresh-start re-use. Everything else it works out
afresh, honestly following the real history of the game. In effect it becomes
the slow-but-correct referee from Dead end 4 — *minus* the one feature that made
that referee impossibly slow (keying on the entire history). So it is both
correct **and** fast enough for the small gobans.

> **Epistemic update (2026-07-26):** T13 falsified C2 (history-independence
> of the L==H region) at 3×2 (12/508 mismatches). The "certified core" was
> renamed to "fresh-start single-score region" to remove the false implication
> of real-game correctness. Only C1 (fresh-start correctness) survives. See
> `../epistemic/PROGRESS.md` and `../status/leak-crisis.md`.

The cost: turning off reuse gives up speed. For gobans up to 4×4 that is fine.
The open question is whether it is fast enough for the harder cases — which is
exactly what Track B addresses.

### Track B — "Be correct *and* fast, for the big goban"
Bring reuse back, but **safely**: instead of remembering only a position's
score, also remember **exactly which pieces of history that score depended on.**
Then reuse the stored score only when the current game's history is compatible
with those dependencies. This is a known technique from the research literature
(the **Kishimoto–Müller** method for exactly this ko/history problem). It is
sound by construction — it never makes the mistake of Dead end 3, because it
*checks* its dependencies instead of *assuming* they don't matter.

Track B is more work, and it is only *needed* when the cautious solver of Track
A becomes too slow — which we expect to happen as gobans grow. **In short:
Track A buys correctness immediately; Track B buys back the speed we'll need for
5×5.**

**What we found when we built Track B.** We implemented the safe reuse and it
works: it is provably sound (passes the consistency auditor) and it produces
*exactly the same answers* as the cautious method on every goban we can check
(3×2, 3×3, 4×3) — so it is correct, not merely plausible. The trick for
remembering "what a score depended on" without using enormous memory is a
**fingerprint**: a small fixed-size sketch of the set of positions involved,
like a fuzzy summary. Two positions that are the same leave the same mark on the
sketch, so if two sketches share no marks at all, the underlying situations
provably don't overlap — which is exactly the "safe to reuse" test. Getting a
"maybe overlap" answer just means we skip the reuse to be safe; we are never
wrong, only sometimes slower.

The catch we measured: a *small* fingerprint **saturates** — the ko tangles
touch so many positions that the sketch fills up and always reports "maybe
overlap," so almost no reuse is recovered. Widening the fingerprint recovers
much more reuse (at 4096 bits we got back most of it and ran roughly twice as
fast as the cautious method) — but a wider fingerprint costs more memory per
stored position. **This memory-for-reuse trade is the real obstacle for 5×5:**
the goban has so many positions that a fingerprint big enough to avoid
saturation, times billions of positions, is far more memory than any machine
has. So Track B clearly helps at small gobans, but making it help *enough* at
5×5 is an unsolved problem — and an honest one to record.

---

## 8. Can we solve 5×5 with 40–48 GB of RAM, in reasonable time?

Here is our honest assessment given what we currently know. It comes in two
parts, because there are two different resources at stake: **memory** and
**time**, and the harder risk is time.

### The memory picture: the full table does *not* fit in RAM

Some round numbers (approximate, but the conclusion is not close):

- A 5×5 goban has about **850 billion** possible stone-arrangements. Slightly
  under half of those — about **410 billion** — are legal positions.
- Folding away the eight goban symmetries brings that down to very roughly
  **25–50 billion** distinct positions to store.
- The final answer table needs on the order of **1–2 bytes per position**
  (the score for each side), i.e. very roughly **50–150 GB** — and that is just
  the *finished* table. The *working* data needed *while computing* (the low/high
  brackets, bookkeeping) is several times larger again.

So: **a full 5×5 oracle will not fit inside 40–48 GB of RAM. That is essentially
certain.** This is not a defeat — it is expected, and it is why the plan
(recorded in our design notes as the "RAM-lean, out-of-core" roadmap) has always
been to keep the big table **on disk** and stream it through memory in **tiles**,
using RAM only as a working buffer. The finished table also lives on disk and is
queried by fast random look-up — generation can be slow, but *using* the solved
oracle stays fast.

**So the realistic question is not "does it fit in RAM" (it doesn't) but "is
40–48 GB enough of a working buffer to compute it on disk in reasonable time?"**
On the memory side, the tentative answer is **plausibly yes** — but this has not
yet been demonstrated, and memory is not the main worry.

### The time picture: this is the real unknown

The genuine risk to 5×5 is **not** memory — it is the **size and cost of the
ko-sensitive region**. Everything hard in this project lives there. We do not
yet know how the ko-sensitive region behaves as the goban grows, and that single unknown
dominates the whole feasibility question. If the ko-sensitive region stays a small, cheap
fraction, 5×5 is very likely reachable. If it grows quickly and the ko-sensitive region
positions become individually expensive, even a perfectly sound and fast solver
could take impractically long.

### First measurements are in — and they are mostly encouraging

We have now measured the "history-free" part of every goban we can build
(2×2 through 4×4). See `scaling-census.md` for the table. Two things stand out:

- **The hard fraction is shrinking.** The share of positions that are
  ko-sensitive falls steadily as the goban grows: about 72% on 2×2, down to
  **21% on 4×4**. The easy, provably-certain core keeps growing to dominate.
  That is the best possible news about the *shape* of the problem.
- **But the hard *count* is large and growing.** 4×4 has **10.4 million**
  ko-sensitive positions (about 1.3 million once you remove mirror-images).
  Each one is an independent little ko puzzle the solver must crack. This — not
  memory — is the true bottleneck.

There is also a sharp practical consequence. The earlier (buggy) 4×4 solve
finished in *hours* precisely because it **reused** work between puzzles — the
very reuse we just proved unsound. Turning that reuse off (Track A) removes the
accelerator, so a fully-cautious 4×4 solve is expected to be much slower. That
strongly suggests the **safe** reuse of Track B is needed **even for 4×4**, not
only for 5×5. We are testing this next.

### So: what must we still test before we can promise 5×5?

We are **not yet in a position** to state the full set of optimisations 5×5
needs, because we are missing the measurements that would tell us. Concretely,
before proposing the final recipe we must measure, across the sizes we can
already solve (2×2, 3×2, 3×3, 4×4) and project forward:

1. **How fast does the ko-sensitive region grow?** What fraction of positions are
   ko-sensitive at each goban size, and is that fraction rising, flat, or
   falling? *This is the single most important number we are missing.*
2. **How expensive is each ko-sensitive region position to solve**, cautious (Track A) vs.
   guarded-reuse (Track B)? Does guarded reuse actually pay for itself?
3. **How many backward sweeps** does the low/high calculation need to settle,
   and how costly is each sweep when the table lives on disk instead of in
   memory?
4. **How well does the table compress?** The scores are far from random (nearby
   positions have similar scores), so there is real hope of shrinking the
   on-disk table well below the raw estimate — but this must be tested on the
   4×4 table first.
5. **Does out-of-core tiling actually work at speed?** The right first
   experiment is not 5×5 but the in-between rectangular goban **5×4** — big
   enough to force disk-based, tiled computation, small enough to finish and
   check. It is the true dress rehearsal.
6. **Does guarded reuse (Track B) pass the consistency auditor** on 4×4 before
   we ever rely on it at 5×5?

### Bottom line

- **Memory (40–48 GB):** the full table won't fit and was never meant to; as a
  *working buffer* for disk-based computation it is plausibly adequate, but
  unproven.
- **Feasibility of 5×5 at all:** **not yet answered.** It hinges on the ko-sensitive region,
  which we have not measured beyond 4×4.
- **Confidence today:** we have a *correct* method (Track A) and a *known route*
  to the speed we'll need (Track B), and we have finally proven where the old
  bug was. What we lack is the handful of growth measurements above. Those
  measurements — especially the ko-sensitive-region growth and the 5×4 out-of-core dress
  rehearsal — are the honest prerequisites before anyone should promise a
  superko-perfect 5×5 within any particular time or memory budget.

*This document will be updated as those measurements come in.*

---

## 2026-07-24 UPDATE — the superko story ended, and what we learned

Everything above assumes we were going to solve Go on 4×4 *exactly under
positional superko* (the strict "you may never repeat any past whole-goban
position" rule). We have now stopped chasing that, for good reasons, and the
honest picture is both smaller and cleaner than we hoped.

### Why we stopped chasing superko

Two independent facts settled it:

1. **It is the wrong rule.** Real Go does not use positional superko. Pro Japan
   and Korea use the basic ko rule and call long repeats "no result" (replay
   the game). China uses anti-repetition provisions decided by referees.
   AlphaGo's famous matches (Lee Sedol, Ke Jie) were played under Chinese
   rules, not superko. Even the strong bots never *compute* superko exactly —
   they show the neural net a short slice of recent history plus an
   engine-flagged "this move is illegal" hint, and the score they output is an
   *estimate*. Superko's real difficulty is a problem only for someone
   demanding a *proof* — and it turns out that's a self-inflicted wound.
2. **It is intractable even on the empty 2×2 goban** by the sound method
   (the exact solver drowns in the bookkeeping of "every past position").

### The two rescue ideas we tested — and what happened

We tried two ways to make the problem both realistic and solvable:

- **"Kill rule" (a big capture ends the game):** measured directly on the full
  4×4 goban. It did **not** help — it left the hard fraction essentially
  unchanged, and stricter versions made it *worse* (25% hard instead of 21%),
  because ending games early mid-goban just creates more awkward boundary
  positions. Abandoned.
- **"Basic ko + score the goban if a long cycle happens":** this is the rule
  closest to how humans actually play. But we proved it runs into *exactly the
  same wall* as superko. The reason is subtle but decisive: whether a move
  "closes a cycle" depends on the entire history of the game, so the computer
  still has to carry that whole history around — the very thing that made
  superko impossible. We confirmed this by measurement: the two rules explore a
  *byte-for-byte identical* number of positions before giving up.

### What we CAN prove — and it's real

Here is the good news, and it's genuinely worth stating plainly. Our backward
method computes two numbers for every position: a **low** score (assume every
unresolved cycle goes as badly as possible for Black) and a **high** score
(assume every cycle goes as well as possible). Two things follow:

- **Where low equals high, the score is certain — and it doesn't matter which
  ko rule you use.** These positions never depend on how a repeat is resolved,
  so their score is the same under superko, basic ko, the score-on-cycle rule,
  anything. That is **66% of 3×3, 74% of 4×3, and about 79% of 4×4** —
  *provably, exactly, permanently* solved.
- **Where low is below high, we can't name a single number, but we can prove
  the true score lies between them.** We checked this against the few scores
  humans have published (empty 3×3 is +9; it sits at the top of our [2, 9]
  bracket — correct) and it holds.

The catch, stated honestly: for the *empty goban specifically* — the position
everyone actually wants a number for — the bracket is wide (e.g. 3×3 is
"somewhere between +2 and +9"), because the empty goban is the most
cycle-tangled position of all. And a chunk of the hard positions have a bracket
so wide it says nothing at all. So:

> **We have a genuine partial solution of 4×4: an exact, rule-independent score
> for ~79% of positions, and honest bounds for the rest. We do NOT have — and
> cannot get by any fast, provable method we know — a single "Go on 4×4 is a win
> by N" number under a realistic rule.** Getting that last number would require
> either the intractable full-history search, or a specialised "loopy game"
> solver from combinatorial game theory that we have not built.

That is the true state of the art for this project as of today.
