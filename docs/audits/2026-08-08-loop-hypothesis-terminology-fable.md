# The operator's loop hypothesis, the "force life" terminology problem, and how the engine should handle optimal-loopy positions

**Author:** claude-fable-5, 2026-08-08, from the closing discussion with the operator before the
holiday. **Status: PROPOSALS + ASSESSMENT** — nothing here changes a claim status, a glossary
entry, or engine behaviour; every actionable item is listed in §4 for registration/ratification
on return. Companion files from the same day:
`docs/audits/2026-08-08-week-close-audit.md` (state of the project) and
`docs/audits/2026-08-08-epistemic-solution-tree-review-fable.md` (gaps and the path to
provably-perfect).

---

## 1. The operator's hypothesis, assessed against the ledger

**The hypothesis (operator's mental picture):** a sufficiently motivated player can guarantee
Benson-alive territory on larger gobans, and thus always has a path to a terminal position. If
every terminal is a loss for one player, looping is that player's best option — but all-loss
for one side means all-win for the other, so the opponent should drive to a winning terminal.
Hence loops shouldn't decide values on larger gobans, and the bracket-resolution machinery may
be unnecessary there.

**What the record says — the picture is more right than the operator fears:**

- **"Life ⟹ clean termination" is measured-true state-wise, categorically.** Any state
  containing a Benson-alive chain is L==H — 99,133,036 entries at 4×4, zero exceptions,
  unexplained (the project's best theorem candidate). Once life exists, loop-ambiguity
  vanishes. This part of the picture is the best-confirmed regularity we have.
- **"The opponent drives to a winning terminal" holds at every root where a winning terminal
  is forcible at all.** At 4×3 (L=+4) and 4×4 (L=+1), under the least-fixpoint reading
  (`GLOBAL.AXIOM-LH`, CLAIMED), Black forces a *terminal* ≥ L no matter what White does — the
  losing side would prefer the loop and **cannot get it**. (Caveats: AXIOM-LH is claimed, not
  proven, and the 4×4 root bracket sits in the Track-A-distrusted column.)
- **Where the logic actually breaks:** "all-loss means all-win for the opponent" is true of
  *payoffs* but smuggles in a claim about *control*. Avoiding my losing terminals does not
  grant you the ability to reach your winning ones — both players can simultaneously veto
  termination. That is what a draw-by-loop root *is*, and it is measured at 2×2 and 3×2 only:
  the sizes too small for anyone to have a forcible terminal win at all.
- **Which claim was actually falsified:** not "life ⟹ termination" but **"the win goes
  through guaranteed life"** — at 4×3/4×4 *nobody* can guarantee Benson life from the empty
  root, yet Black wins decisively on area anyway (the middle regime; the operator's recorded
  loss). Separately, loops *can* be sustained under optimal play (T416: 12 forced cycles / 80
  states at 3×3) — but T419 quantified how marginal that is: where a loopy option exists,
  optimal play declines it 63% of the time at a median margin of 9 points.

**The larger-goban question — the doubt is legitimate and cheap to test.** The forcible-life
sequence across sizes is yes (3×3) → no (4×3) → no (4×4): **not monotone** evidence against
larger gobans — 4×3/4×4 may be the squeeze zone (too big to annihilate from the centre, too
small to build an uninvadable group against a dedicated denier). Two measured fractions fall
with size: L<H states 10.94% → 7.20% → 3.49%, and straddle states (true draw-by-loop
candidates) 2.52% → 2.05% → 0.90%. External prior art: van der Werf solved 5×5 at **B+25 —
the whole goban** (`docs/evidence/van-der-werf-sources/ssgo.pdf`), which at least suggests
Black secures life at 5×5, putting the root back in regime 1 (single value, rule-independent,
nothing to resolve). Per-goban independence forbids concluding it; the correct move is to
**register the prediction before measuring** (T394 discipline): *at 4×2 / 5×2 / 5×3 / 5×4 /
5×5, some player can secure Benson life from the empty root, hence root L==H.* The 4×2/5×2
rungs are already roadmapped for the T394 closure instrument and are cheap.

**On "many bracket resolvers, simply unnecessary":** right in three senses, wrong in one.
(1) Root headlines at larger sizes — if the prediction holds, there is nothing to resolve.
(2) The 4×4 *win* needs no resolver today: L=+1 > 0 means Black wins under any loop
adjudication; only the exact margin (∈ [1,16]) needs resolution. (3) In-game weight — the
shrinking L<H fraction plus T419's decline-by-9-points says loop machinery matters less than
the resolver graveyard suggests. (4) Where resolution stays necessary: a full-table perfect
player (even 3×3 is 10.94% loopy off the main line), and *proving* any of this. Every falsified
resolver failed by quietly changing the game (ADR-0022); the operator's hypothesis, if it
holds, is cleaner — it makes brackets not arise where it matters, rather than resolving them.

---

## 2. Terminology: "force life" trips the reader — proposal

**The problem (operator, 2026-08-08):** "force life" reads as one player forcing something on
the *other* player. The intended meaning is reflexive: *a player can guarantee Benson-alive
stones for themself against any opposition*.

**Proposed phrase: "secure life" / "can secure life" / "securable life."**
"Black can secure life" is unambiguous about who lives, reads naturally in every sentence
position the corpus uses ("neither player can secure life", "life is securable at 3×3"), and
stays two words. Runner-up considered and rejected: "guarantee life" (fine but longer in
inflected forms); "unconditional life" is **not** available — it is Benson's own term for the
*static* property (alive as the position stands) and the corpus already uses it that way; the
dynamic property here is "player to move can *reach* unconditional life against best
resistance."

**Draft glossary entry** (for `docs/epistemic/GLOSSARY.md`, pending ratification):

> **secure life (v.), securable life (adj.)** — player P *can secure life* in state s if P has
> a strategy from s reaching a state containing a Benson-alive (unconditionally alive) chain of
> P's colour, against any play by the opponent. Reflexive: P secures life *for P*. Formerly
> written "force life"/`canForceLife`, which misread as forcing the *opponent*; the code
> identifier `canForceLife` is retained until the rename sweep. Distinct from **unconditional
> life** (Benson's static property of a position as it stands). Law (measured, 5/5 sizes):
> root L==H ⟺ some player can secure life. Securable life buys *rule-independence*, not
> victory (4×3/4×4: nobody can secure life, Black wins anyway).

**Scope of the change:** prose and docs only, file-by-file as touched (same policy as the
approved-but-unscheduled BRACKETED/SINGLE-SCORE sweep — never a global `sed`). The code
identifier `canForceLife` and register row IDs stay until a dedicated rename row; the glossary
entry carries the bridge so no reader is stranded either way.

---

## 3. Optimal-loopy positions: how the engine should label, play, and report them

**The operator's ask:** if the loopy region cannot be resolved to exact values, stop
pretending it is on the win/loss/tie axis — label it as its own thing ("optimal loopy path"),
and decide how the engine handles and reports it in real games (ko-threat reservoir,
hail-mary, seeking seki, draw-seeking).

**Proposed label taxonomy** — the measurement already exists (T416/T419); this only names the
classes for play and reporting:

| label | definition (from T416/T419) | game meaning | count at 3×3 (denominator 47,456 parents / 54 cycles) |
|---|---|---|---|
| `LOOP-FORCED` | on a cycle where every node's mover strictly prefers to stay | **dynamic seki** — neither side can leave without losing; the honest verdict is "repetition", not a score | 12 cycles / 80 states |
| `LOOP-ONLY` | every optimal child is loopy (incl. one-of-one) | the table's best play *enters* the loopy region; value guarantee is the bracket bound, not a score | 5,080 (4,420 one-of-one) |
| `LOOP-TIED` | loopy and non-loopy children tie at optimal | repetition is *available* at no cost — the hail-mary / draw-seeking / ko-threat-reservoir case, playable by choice | 448 (+ 42 indifferent cycles / 4,470 states) |
| `LOOP-DECLINED` | loopy children exist, all strictly worse | loops are a trap here; median losing margin 9 points | 9,480 |

**Engine policy proposal (play):**

1. **Never enter a loop when a strictly better decisive move exists** (the table already
   implies this — T419: optimal play declines 63% of available loops decisively).
2. **`LOOP-TIED` becomes a style knob**, not a fixed choice: when winning, prefer the decisive
   tie-mate (terminate the game — the operator's own "the opponent should seek a winning
   terminal"); when losing under the venue's rules, the loopy tie-mate *is* the hail-mary —
   repetition forces the venue's ko/repetition adjudication (draw, no-result, or superko ban)
   instead of a certain loss. Default: decisive-when-winning, loopy-when-losing.
3. **`LOOP-ONLY`/`LOOP-FORCED`: play the loop and say so.** Under the table's own rules
   (ADR-0020, TIE=0) the loop is optimal. Under *real* venue rules a superko/no-result rule
   will eventually forbid the repetition move; when that happens the engine is **off-table**
   — the fresh-start values do not cover history-constrained deviation (C2/C3 falsifications)
   — so the deviation move must be chosen by table value among legal moves *and flagged as an
   off-table guarantee* (the existing H5a-style mitigation, now labelled honestly instead of
   silently).

**Engine reporting proposal (real games, GTP/Sabaki):**

- Report bracketed positions as **`[L,H] + label`**, never as a bare score. "B+1 guaranteed,
  margin open to +16, LOOP-ONLY" is honest; "+1" alone is not, and "tie" is wrong.
- Emit the label per move via the analyze/comment channel (kifu comments in Sabaki; a
  `weizigo-loopstate` GTP extension for programmatic callers), so a game record shows *where*
  the game entered/left the loopy region and which policy branch (§3.2/3.3) fired.
- On a superko-forced deviation, the comment must say **"off-table: venue rule forbade the
  optimal repetition; playing best legal alternative, guarantee void"** — this is the exact
  seam where the engine's claims end, and it should be visible in every kifu that crosses it.

**Why labels rather than resolution is the right default:** every resolver tried so far was
falsified by changing the game (ADR-0022). The labels change nothing — they surface what the
table already knows. If the threshold-decomposition candidate (epistemic review §4) survives
its pilot, `LOOP-ONLY` brackets collapse to exact values and the labels simply get sharper;
nothing proposed here is thrown away.

---

## 4. Actionable items for return (none executed — all pending registration/ratification)

1. **Register the securable-life prediction before any new-rung measurement** (§1): at
   4×2/5×2/5×3/5×4/5×5, some player can secure Benson life from the empty root, hence root
   L==H. Falsifiable per rung by the T394 closure instrument + a life-security probe.
2. **Ratify the glossary entry** (§2 draft) and adopt "secure life" in prose file-by-file;
   `canForceLife` rename joins the existing BRACKETED/SINGLE-SCORE sweep backlog.
3. **Register the loop-label taxonomy** (§3) as an engine/reporting row: labels computed from
   the existing T416/T419 instruments, GTP/kifu annotation, the LOOP-TIED style knob, and the
   off-table deviation flag. No engine value changes — labelling and honesty only.
4. These fold into the standing long-term items: the "weakest forcible predicate" search is
   the formal version of §1's "sufficiently motivated player" (can-force-settled-and-ahead),
   and the threshold-decomposition pilot is the one resolver kept because it is a proof
   obligation, not a plugin.

*claude-fable-5, 2026-08-08 — written as the closing artifact of the pre-holiday session.*
