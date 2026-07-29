# Muhtasib audit plan — 2026-07-28

**Auditor:** Kimi-k2.7 Auditor (Muhtasib role).
Mandate: hold the claim graph against the standard; name false measures before they are committed.

## What will not be done

- No edits to engine files (`src/retro.zig`, `oracle.zig`, `rules.zig`, `solve.zig`).
- No generation runs, no new artifacts, no simple-ko solver launches.
- No dispatching or TODO-writing for other agents.
- No status upgrades from CLAIMED to PROVEN.

## Chunks

### Chunk 1 — Reproduce `weizigo-chainability` (fastest, newest PROVEN claim)

Build `bin/weizigo-chainability`, run it on every committed artifact, and verify:

1. Zero Bellman-identity violations outside the `KO_SENSITIVE` flag.
2. Violations are exactly co-extensive with the flag.
3. The verdict line correctly ignores in-flag violations.
4. The 4×4 sample rate (`--sample 37`) and the reported ko-sensitive fraction match the published figures.

Evidence files to read first:
- `docs/research/ko-sensitive-chainability.md`
- `docs/epistemic/GLOSSARY.md` (term **chainable**)
- `docs/epistemic/boards/4x4/EPISTEMIC.md` (facts M4, M5)

Commands (build + run):
```bash
zig build -Doptimize=ReleaseFast
bin/weizigo-chainability artifacts/oracle-2x2.wzo
bin/weizigo-chainability artifacts/oracle-3x2.wzo
bin/weizigo-chainability artifacts/oracle-3x3.wzo
bin/weizigo-chainability artifacts/oracle-4x3.wzo
bin/weizigo-chainability data/oracle-4x4.checkpoint.wzo --sample 37
```

Output: `untracked/muhtasib-audit-chunk1-2026-07-28.md`.

### Chunk 2 — Audit the claim graph (PROGRESS / leak-crisis / QA-023)

Read and trace every claim in:

- `docs/epistemic/PROGRESS.md`
- `docs/status/leak-crisis.md`
- `docs/decisions/0013-sound-finisher-and-dependency-guarded-memo.md`
- `docs/evidence/QA-023/proof-v2-2026-07-28.md`
- `docs/evidence/QA-023/audit-opus-2026-07-28.md`
- `docs/research/qa023-basicko-markovian-2026-07-28.md`

Check for:
- Status stronger than evidence.
- Definitions that shifted mid-document.
- Places where “fresh-start correct” is read as “real-game correct.”
- Whether QA-023 Part A is still labeled REPAIRABLE-GAPS or has been silently promoted.

Output: `untracked/muhtasib-audit-chunk2-2026-07-28.md`.

### Chunk 3 — Reproduce EXP-3 basic-ko state-space census

Run `src/kostate_census.zig` and verify the headline numbers:

- 4×4: 51,419,046 reachable triples; 29,497,329 distinct addresses.
- 4×3 and 3×3 match the published figures.
- Legal-position counts still match OEIS A094777.
- The calibration-2 caveat (B-to-move reachable vs slot count) is stated honestly.

Evidence files:
- `src/kostate_census.zig`
- `docs/research/kostate-census-2026-07-28.md`
- `docs/evidence/GLOBAL.H1-CENSUS/PROVENANCE.md`

Output: `untracked/muhtasib-audit-chunk3-2026-07-28.md`.

### Chunk 4 — Inspect the dirty tree for commit hazards

Check `git status`, read diffs, and verify:

- `src/chainability.zig` + `build.zig` contain no unverified claims.
- `docs/research/corrections-2026-07-27.md` has been folded into docs that still contain the corrected errors.
- No artifact in `data/` or `artifacts/` is being silently overwritten.
- `docs/status/CURRENT.md` reflects EXP-2A/EXP-3 completions honestly.
- No two authors are claiming the same file.

Output: `untracked/muhtasib-audit-chunk4-2026-07-28.md`.

## Verdict categories

Each audited claim will be marked:

- **VERIFIED** — reproduced or proof holds as stated.
- **NEEDS REPAIR** — gap found; named with file and line.
- **BLOCKED** — depends on an unrun experiment or open gate.
- **FALSE-AS-STATED** — claim overreaches its evidence.

## Context-clearing schedule

After each chunk, the user may clear the agent context. The audit files in `untracked/` will carry state. Read `untracked/muhtasib-audit-plan-2026-07-28.md` first to resume.
