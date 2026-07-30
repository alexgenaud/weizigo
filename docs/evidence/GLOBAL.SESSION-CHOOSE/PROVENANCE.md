# PROVENANCE — GLOBAL.SESSION-CHOOSE

**Claim ID(s):** no standing row exists in `docs/epistemic/CLAIMS.md` under this
ID; the directory is named by the EXP-16 brief, and the audited claim is the
`docs/status/HANDOVER.md:61–63` assertion that `Session.choose` does table
lookups only and never searches. Bears on: `4x4.GTP-DEFECT`, `GLOBAL.H5a`
(`GLOBAL.H5a-CHILD`, `GLOBAL.H5a-FALLBACK`), `GLOBAL.CHAIN-LH` (as consumer).

**Task / worker / model:** EXP-16, executed by a console session.
**Model: Kimi-k3** (stated at dispatch).

**Date:** 2026-07-28.

**Commit:** `eebe3c2` (named by the brief) — verified: `git diff eebe3c2..HEAD
-- src/gtp.zig` is **empty**, so the audit holds identically at HEAD
`db689d06d2d61a5438ef00edb1cebac09f7735ee` (2026-07-28), where it was
performed. `src/gtp.zig`'s last change is commit `7a0946a` (2026-07-28
11:49:30 +0200); working tree clean for that path.

**Subject:** `Session.choose` at **src/gtp.zig:184–226** (doc comment
:152–183); the genmove call site at **src/gtp.zig:611**.

**Method (ANALYSIS — no probe binary; the artefact is the source itself):**

- `read src/gtp.zig` (full, 965 lines) — located and read `choose`,
  `v1_from_table`, `v0`/`dtt0`/`flags0`, `seen`, `pick`, `countColor`,
  `applyMove`, and the `genmove` handler.
- `grep -n -i "solve\|Exact\|retro\|finisher\|arena" src/gtp.zig` — comment
  hits only; **imports at src/gtp.zig:54–58 are `std`, `rules.zig`,
  `colex.zig`, `artifact.zig`, `score.zig`** — no solver module is imported,
  so no search function is reachable.
- Characterized callees by reading `src/rules.zig:101 pos_from_move`,
  `:125 area_score`, `:171 benson_alive`, `:304 is_settled`, and
  `src/score.zig:88 is_definitive`, `src/colex.zig:113 colex_from_pos` — all
  fixed-work single-goban functions; none walks the game tree or opens the
  artifact.
- Dependents swept with `grep -rn "Session.choose\|choose" docs/ AGENTS.md`.

**Acceptance criterion (from the brief):** one file
`docs/evidence/GLOBAL.SESSION-CHOOSE/audit-2026-07-28.md` containing the
verbatim function body with line numbers, the call-chain table, a verdict of
VERIFIED / PARTIAL / WRONG, a "what depends on this verdict" paragraph, and the
mandatory H5a calibration check against EXP-9 §"The mitigation (with both D-3
corrections)". All present in the sibling file. **Verdict delivered:
VERIFIED.**

**Calibration case (per P3):** the audit's sensitivity was demonstrated by the
two brief-accuracy findings it caught (the claim is in HANDOVER.md §"Gotchas",
not AGENTS.md §"Gotchas"; the relying opus verdict is
`docs/audits/muhtasib-audit-chunk2-2026-07-28.md:48`, not
`docs/evidence/QA-023/audit-opus-2026-07-28.md`) and by the H5a check, which
located the two concrete wrinkles a searcher-hypothesis would have broken
(early-game override at src/gtp.zig:208–224; the `v1_from_table` pass pricing
at :190) — i.e. it distinguished "reads the code" from "believes the docs" on
both a known-good input (the code itself) and a known-bad input (the brief's
misattributions).

**No engine file was modified**; this task held no file ownership.
