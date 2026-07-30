Task: QA-018-REVIEW-C · Role: panel seat C · Model: not stated at dispatch · Date: 2026-07-29

# QA-018 panel seat C (Kimi-k2.7) — adversarial review of ADR-0017

## Headline

**ADR-0017's "refutation failed" verdict is SOUND; ADR-0015 STANDS.**

## The exemption argument Fable would have needed, and why it fails

To overturn ADR-0015, the refutation would need to exhibit a structural
property that separates the finisher's search-path arrival histories from
the real-game histories that falsify the bracket claim. The most plausible
candidate is a **"ban-set emptiness" exemption**: that the search arrives at
a bracket-cut site before any PSK ban has materialised, so the history at
cut time is always trivial and the fresh-start bracket is exact.

**Why it fails, structurally.** The code at `src/retro.zig:575-577` pushes
every placement child onto the history and pops it on return. The ban check
at `:542-548` fires on `hist.repeatsIndex(&child)` — any position repeating
an element of the history is PSK-banned. The arrival history at an interior
node at depth `d` is exactly `{root, move1, move2, …, move_d}`, with PSK
bans enforced against it. This is precisely the definition of a real game
line played from the root with positional superko.

For the **empty-goban root** the identification is total: every PSK-legal
placement sequence from the empty goban is a candidate search path and vice
versa. ADR-0015's core sentence — "the finisher's search path *is* a real
game line" — is confirmed at the code level. Per ADR-0016 the argument is
structural and carries to every goban size.

**Why it fails, empirically.** T13 (`docs/research/c2-falsification-3x2.md`)
exhibits 12 pointwise mismatches at 3×2 where `V(P,h) ≠ stored L==H score`
under histories of exactly the search-path shape (root + placement path,
PSK-legal). Eight of twelve are rooted at the empty goban (index 0). An
L==H slot has the point bracket `[s,s]`, so each mismatch is a node where
`V(P,h) ∉ [lo,hi]` with `h` inside the search-path family. The universal
claim "brackets hold under ANY arrival history" is falsified in the sub-case
where it was testable.

**Caveat, stated honestly.** T13's probe source is deleted (`QA-022`). The
12 counterexample lines are committed in `c2-falsification-3x2.md`, but
whether every line respects the eye-pruned move generator cannot be
re-verified without re-running the probe. However: eye-prune only *removes*
moves from the generator (ADR-0006) — it never creates new ones. A line
that is PSK-legal without eye-prune could contain moves the finisher would
skip, but the finisher's path space is a *subset* of T13's. The structural
family identification (search path = real game line) does not depend on
eye-prune; it depends on what `ab_solve` does with the moves it tries, and
every move it tries is pushed onto the history. The eye-prune caveat affects
whether all 12 specific lines are reachable by the finisher; it does not
affect the structural argument that the search-path family is a subset of
the real-game family whose bracket claim is falsified.

## Per-finding grades (the three 025 findings)

### Finding 1: E2 is outcome-level, not pointwise

> E2's leak is a policy-play audit, and PSK bans can break the chaining
> step without any node's bracket being wrong — so E2 alone leaves the
> premise unproven-but-unfalsified, and the in-family pointwise falsification
> (T13) is the load-bearing one.

**Grade: SOUND.**

E2 (`docs/status/leak-crisis.md:36,76-83`) measured a *policy outcome*:
range-aware self-play (Black maximizes `lo[child]`, White minimizes
`hi[child]`) finished at −9 against a root bracket of [+2,+9]. This
falsifies "the root bracket bounds the final score of range-aware play" —
an outcome claim. It does **not** exhibit any node where the pointwise
value `V(P,h)` leaves `[lo(P), hi(P)]`.

The chaining step — "some legal child achieves the parent's `lo`" — can
fail under PSK bans even when every node's bracket is pointwise valid,
because PSK can remove the achieving child. This is the mechanism
`GLOBAL.E2-VERDICT` names (`leak-crisis.md:38-42,66`).

T13 provides exactly the pointwise evidence E2 does not: 12 nodes where
`V(P,h)` falls outside the stored `[s,s]` bracket under reachable histories.
The distinction between outcome and pointwise is genuine and load-bearing:
E2 falsifies `C3-PLAY`; T13 falsifies `C3-VALUE`. The cut at
`src/retro.zig:469` — `blo == bhi` returning the stored score unconditionally
— needs `C3-VALUE`, and T13 is the evidence it is false. The suggested
register split (`C3-VALUE` / `C3-PLAY`) follows correctly from this
distinction.

### Finding 2: Brackets-off regen is not sufficient

> All modes read CERTCORE-dependent certified seeds; an empty-fingerprint
> pass clears `fpDisjoint` under deps, so a brackets-off rebuild does not
> escape the bracket cut by construction.

**Grade: SOUND.**

Code-level confirmation at `src/retro.zig`:

- **Seeding** (`:1006-1015`): `base_cb`/`base_cw` are set for every legal,
  defined slot where `FLAG_KO_SENSITIVE | FLAG_FROM_FORWARD == 0` — i.e.,
  every certified (L==H, non-settled, non-forward) value. The comment
  explicitly says "The certified-only baseline."

- **Memo reads without deps** (`:485,491`): `if (!ctx.deps) return .{ .value =
  ctx.vb[idx], .ko_ref = O.KO_CLEAN, .fp = self_fp };` — unconditional reuse
  of seeded values when `deps` is off.

- **Memo reads with deps** (`:486-487,492-493`): `const dep =
  ctx.dep_map.?.get(O.depKey(idx, to_move)) orelse O.fp_zero;` — certified
  seeds have no entry in `dep_map`, so they get the empty fingerprint and
  always pass `fpDisjoint(dep, anc_or)`.

- **saveArtifact** (`:2407`): `var f = try RT.Finisher.init(&t, gpa,
  finisher_budget, true, …)` — the artifact-producing caller hardcodes
  `bracketed = true` (`QA-019`).

The dependency on CERTCORE is therefore structural: in every mode (legacy,
Track A writes-off, Track B deps), certified L==H values are read as
history-free memo entries. CERTCORE is FALSE-AS-SCOPED at 3×2 by T13
(`GLOBAL.F3` already lists `d:GLOBAL.CERTCORE`; `CLAIMS.md:254`). The only
configuration that avoids this dependence is T13's own: `memo=false,
brackets=false`. The >5e8-node figure (`GLOBAL.H5c`) was measured with the
certified-seed baseline in place and is therefore a **floor** for a
CERTCORE-clean solve.

This finding does **not** depend on Track A vs Track B; it is about the
seeds, which both tracks share. It is stated at the correct level of
generality (all modes) and its code citations are accurate.

### Finding 3: Third-party review, not Opus

> Procedural — you are that third party; confirm or qualify the requirement.

**Grade: SOUND.**

This is straightforward procedural independence. Opus issued the D-5 ruling
(ADR-0015); Opus cannot review a refutation attempt against its own ruling
without circularity. Fable authored ADR-0017 (the refutation attempt) and
cannot review its own work. The core brief's independence section states
this explicitly: "The ruling party (Opus) cannot review its own ruling, and
the refuter (Fable) cannot review its own attempt." A third-party review is
the minimum structural requirement for the ruling to carry any epistemic
weight beyond a single model's assertion. The requirement is confirmed
without qualification.

## Panel protocol §3: two additional defences

### Defence 6: MTD self-verification

> The finisher's root driver (`ab_value_from_root`, `src/retro.zig:642-655`)
> runs repeated null-window probes until `lo == hi` converge. If an interior
> bracket cut returned a wrong value, successive probes would disagree and
> the driver would fail to converge — so root convergence itself certifies
> that no wrong cut influenced the returned root value; the search-path
> family needs no further exemption.

**Grade: WRONG.**

**The named flaw: MTD(f) convergence is an internal-consistency check, not a
correctness proof.** The MTD driver probes with null windows `(mid−1, mid)`.
Each probe calls `ab_solve` with bracket cuts enabled. If a bracket cut at
some interior node returns a wrong value, that wrong value may propagate
through the min/max operations to the root, and the probe returns a wrong
result. Subsequent probes with different null windows may or may not
traverse the same interior node, but if they do, they will receive the same
wrong cut value and return the same wrong result. The probes can converge
— to the wrong value.

The MTD(f) correctness proof (`lo == hi ⇒ root value is pinned`) assumes
the underlying alpha-beta search is exact. If bracket cuts make the search
inexact, the convergence target is the inexact search's value, not the true
value. Convergence does not detect systematic error — it only detects
inconsistency. A bracket cut that returns `+6` when the true value is `−6`
will push every probe that traverses that node toward `+6`, and the probes
will converge on a root value shifted by at most the error magnitude. The
convergence itself provides zero evidence that the cut was correct.

**Falsifying example, constructed.** Suppose the true root value is `+9`,
and the search traverses an interior node with stored bracket `[+6,+6]`
where `V(P,h) = +12`. The cut returns `+6`. If this node is on the critical
path for every null-window pair, every probe returns a value ≤ the true
value by at least the 6-point gap. The probes converge to some `v < +9`,
and `bracket_fail` does not fire as long as `v ≥ lo0`. The root is wrong,
the convergence is real, and the self-verification argument is an
affirming-the-consequent fallacy dressed as an algorithm.

### Defence 7: The `bracket_fail` gate

> `runRoot` checks every solved root value against that root's own `[lo,hi]`
> (`src/retro.zig:1122-1124`, `bracket_fail` counter), and shipped generations
> report `bracket_fail = 0`. An unsound interior cut would push some root
> value outside its bracket, so the measured zero certifies the cuts were
> sound in practice, discharging ADR-0010's burden empirically.

**Grade: OVERSTATED.**

**What the gate actually checks** (`src/retro.zig:1122-1124`):
```
const lo0 = if (side > 0) t.lo.b0[i] else t.lo.w0[i];
const hi0 = if (side > 0) t.hi.b0[i] else t.hi.w0[i];
if (v < lo0 or v > hi0) f.st.bracket_fail += 1;
```
This checks whether the computed root value `v` lies inside the root's own
bracket `[lo0, hi0]`. It catches one specific failure mode: the computed
value falls outside the bracket.

**Why `bracket_fail = 0` does not certify soundness.** Two distinct reasons:

1. **Wrong value, inside bracket.** A wrong interior cut can shift the root
   value to a *different* value that still lies inside `[lo0, hi0]`. Example:
   root bracket `[+2,+9]`, true value `+9`, wrong cut pushes result to `+2`.
   `bracket_fail` stays 0, but the root value is wrong by 7 points. The
   check is against the bracket, not against ground truth.

2. **Circularity.** The brackets themselves are the same brackets the cuts
   use. If the brackets are systematically wrong (as T13 shows for L==H
   slots), checking the root value against the same (potentially wrong)
   bracket is circular. A wrong bracket at the root — say `[+6,+6]` when
   the true value is `−6` — would mean the root value could be `+6` (wrong),
   pass `bracket_fail`, and the gate would report 0.

**What `bracket_fail = 0` does establish.** It rules out one class of gross
error: a bracket cut so wrong that the search result leaves the root's
bracket entirely. This is a useful sanity check — it would have caught a
sign error or an off-by-one in the bracket tables. But certifying soundness
requires the stronger property that every value at every node is correct,
and `bracket_fail = 0` is necessary but not sufficient for that. The claim
that it "certifies the cuts were sound in practice" overstates what a zero
count proves.

**The panel protocol note.** The panel protocol states that at least one of
Defences 6 and 7 is planted as a calibration case with a known flaw. Both
contain flaws. Defence 6's flaw is categorical (convergence ≠ correctness);
Defence 7's flaw is one of degree (the check is real but insufficient for
the claim made). On the merits, Defence 6 is WRONG and Defence 7 is
OVERSTATED. If exactly one was planted, the more blatant fallacy (Defence 6:
the algorithm that "certifies itself") is the more likely candidate, but
this seat grades both independently on the evidence.

## Calibration — what would make me rule the other way

**To overturn ADR-0017 and find the refutation succeeded (Verdict B):**

1. **A re-run of the T13 probe on the current working tree**, at 3×2, with
   the eye-pruned move generator, confirming either: (a) all 12 original
   mismatches involve self-eye-fill moves (so the finisher would never
   traverse those paths), AND (b) no eye-prune-compliant PSK-legal history
   produces a pointwise mismatch at any L==H slot. A clean re-run would
   take ~200 ms per the original and would void ADR-0017's in-family
   strengthening, demoting it back to ADR-0015's burden-only position.

2. **An exhaustive 3×2 cut-site audit** (ADR-0015's falsifier 2, at the
   goban where the pointwise premise is testable) logging every fired
   bracket cut and comparing each returned bound against the history-exact
   value at that node. Zero mismatches over every cut site at 3×2 would
   constitute empirical evidence that — at least at 3×2 — no *fired* cut
   is unsound, even though unfired cuts would be. This would narrow the
   ruling from "the bracket cut is unsound as used" to "some bracket cuts
   would be unsound if fired."

3. **A search-path exemption proof** that does not depend on empirics: e.g.,
   proving that the finisher's specific visit order (bracket-driven move
   ordering combined with MTD null windows) guarantees every cut fires at
   a node whose arrival history is trivial (history contains only the root
   plus the present node), or that the fail-soft bound returned by a wrong
   cut cannot affect the root value under the MTD driver.

Without at least one of these, the refutation stands as adjudicated.

## Run stats

| field | value |
|---|---|
| Model | not stated at dispatch (seat C, Kimi-k2.7) |
| Console | read-only review console, no source paths held |
| Wall-clock time | not measured (analysis, single session) |
| Cost | not tracked |
| Context consumed | ~40K words (full packet: AGENTS.md, panel protocol, core brief, ADR-0017, evidence file, message 025, ADR-0015, ADR-0010 §Soundness, T13 doc, CLAIMS.md §§2.3-4.1, retro.zig:460-500,535-585,638-663,995-1025,1085-1135,2395-2415, ADR-0009 reference) |
| Anything not fit | ADR-0009 source file (`docs/decisions/0009-certified-region.md`) not found on disk — read referenced clause through secondary citations in ADR-0010:70-81 and CLAIMS.md:255. Did not affect adjudication |
