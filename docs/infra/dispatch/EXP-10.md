# EXP-10 — QA-018/019 ADR: do bracket cuts hold under search-path histories?

**Closes:** drafts the ADR for `QA-018`/`QA-019` (the most consequential open
decision in the project). **The ruling is the user's, not the agent's** — this
task produces the ADR *draft* that lays out both horns with evidence so the user
can decide. **Blocks:** EXP-6 (and any writes-off regen) — do not start those
until this resolves. **Blocked by:** nothing. **Holds:** `docs/decisions/0015-*.md`
(new) — a docs-only task; no engine file.

**Read first:** `docs/infra/dispatch/README.md`, then `AGENTS.md`, then
`msg_from_opus.md` §007 (O1) in full, then `docs/epistemic/CLAIMS.md` (F2, O1,
C3, ADR-0010 edges), then `docs/decisions/0010-bracket-guided-finishing.md` and
`0013-sound-finisher-and-dependency-guarded-memo.md`, then
`src/retro.zig:464` (`bracket cut: [lo,hi] holds under ANY arrival history ->
KO_CLEAN`) and `:2407` (`saveArtifact` hardcodes `bracketed = true`), then
`docs/research/c2-falsification-3x2.md` (E2 falsified C3 for *real-game*
histories) and `docs/epistemic/critique-2026-07-28.md` §2.

## The open question, exactly

`GLOBAL.F2` (bracket-guided finisher sound) is CLAIMED, deriving from ADR-0010's
"brackets hold under **ANY** arrival history". `GLOBAL.C3` (the bracket bounds
the real-game score) is **FALSE-AS-SCOPED at 3×3** (E2). Opus's O1 finding
(`msg_from_opus.md` §007): **every shipped ko-sensitive value was produced by
bracket cuts**, and `memo_writes=false` (Track A) leaves bracket cuts **on**
(`saveArtifact` hardcodes `bracketed=true`). So Track A does not escape the
bracket claim, and the regen that would settle F2/F3 may need to be
**brackets-off**.

The nuance is the whole question: E2 falsified C3 for *real-game* arrival
histories. The finisher's cuts fire under *search-path* histories descending
from a fresh-start root — a different family. **Are they the same claim?**
ADR-0010 says yes ("ANY arrival history"). So either:

- **Horn A — ADR-0010 is too strong.** "ANY" over-reached; search-path and
  real-game histories are not the same, F2 does not inherit C3's falsification,
  but ADR-0010's justification must be rewritten to scope it to search-path
  histories (and F2 stays CLAIMED, now on a sounder basis). *Or* "ANY" really
  does include real-game, C3's falsification applies, and **F2 is orphaned** —
  every shipped ko-sensitive value loses its soundness basis and the only sound
  4×4 build is brackets-off.
- **Horn B — the histories differ.** Search-path histories (a fresh-start
  root, a single self-imposed ban set) are a strict subset / a different
  family from real-game PSK histories (arbitrary opponent arrival), and C3's
  real-game falsification does not transfer. F2 is unaffected; ADR-0010 is
  reworded to say "search-path arrival histories" and the finisher stands.

The agent's job is to **adjudicate the evidence for each horn and write the ADR
draft**, *not* to rule. The user rules.

## Acceptance (for the draft)

1. `docs/decisions/0015-bracket-cut-soundness-search-vs-real-history.md` exists.
2. It states both horns, the evidence for/against each (citing E2, ADR-0010,
   `retro.zig:464`, `retro.zig:2407`, the O1 finding), and the *consequence* of
   each ruling (Horn A → F2 orphaned / brackets-off regen needed; Horn B → F2
   stands, ADR-0010 reworded).
3. It does **not** assert a ruling. It ends with a crisp "Decision needed from
   the user: Horn A or Horn B?" and the recommended default (Advisor will
   recommend; the agent may state its lean as CLAIMED, not PROVEN).
4. It is auditable by a fresh agent reading only the ADR + the cited sources.

## Deliverables

- `docs/decisions/0015-*.md` (the ADR draft).
- `docs/evidence/QA-018/` (the source citations: `retro.zig:464`, `:2407`,
  ADR-0010:16-18, E2's falsification scope, the O1 chain in CLAIMS).

## Do NOT

- Do not edit the engine, do not edit ADR-0010 (supersede, don't rewrite —
  append a new ADR that may supersede it once the user rules).
- Do not mark F2 PROVEN or FALSE in the ADR — that is the user's ruling. Tag the
  analysis CLAIMED.
- Do not start a brackets-off regen; this ADR's ruling decides whether one is
  needed.