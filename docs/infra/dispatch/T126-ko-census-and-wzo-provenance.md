<!--managent set=A holds=docs/epistemic/CLAIMS.md-->
# T126 — ko-composition census row, and a PROVENANCE for the 4×4 artifact

**Type:** register edit + evidence hygiene · **Holds:** `docs/epistemic/CLAIMS.md`
· **Needs:** T125 (same file)

## Part 1 — T117's census has no row

`docs/research/ko-composition-census-2026-07-30.md`: the 4×4 ko-sensitive
region is **99.997% single-ko**; multi-ko is ~0.0024%, concentrated in a 3-ko
category of 256 side-positions (0.0025%) out of 10,367,922. Verified
byte-identical against the B23 static census, with a dynamic cycle classifier
(`src/ko_cycle_census.zig`, committed) sampling 1,500+ positions across every
category.

This is strategy-shifting, not decorative: it converts the open question from
"can we handle 10.4M ko-sensitive slots?" into "can we certify a single-ko
sub-solver?", which is the cheapest live path to the 4×4 deliverable. It lives
in one research file and nowhere else. Give it a row and wire its dependents.

## Part 2 — the artifact has no provenance of record

`data/oracle-4x4-basicko-tie-area.wzo` exists — 258,280,358 bytes, SHA-256:

```
edd9f68ef243f67de21152432f9e8f521536317527d425208e6901f90b11c0cc
```

`model-perf.md:2280` asserts "SHA-256 verified", but **no committed file records
the digest**, so the verification cannot be re-checked by anyone. The existing
`docs/evidence/QA-026/4x4/PROVENANCE.md` documents the *solve*, not the
*artifact*.

Write a PROVENANCE for the artifact: producing task (T113), rules ID (2 —
basic-ko + TIE), state counts (48.5M fresh-start from 99M compact fixpoint),
format reference (`docs/evidence/QA-026/4x4/wzo-format.md`), and a
`SHA256SUMS` entry. Re-verify the digest yourself before recording it —
transcribing the one above without checking defeats the point.

This artifact is the gate input to the EXP-7 4×4 re-run (T129); an unverifiable
gate input is how EXP-7 came to be marked done having tested only at 3×3.

## Deliverable

Census row in `CLAIMS.md`, artifact PROVENANCE + `SHA256SUMS` under
`docs/evidence/QA-026/4x4/`, claimlint output.
