<!--managent set=R-->
# REFERENCES — build the bibliography the project has never had, and fix three citation defects

**Opened by:** `docs/audits/AUDIT-REF-DSPro-2026-07-29.md`, assessed by the Orchestrator. ANALYSIS + new file; no engine file, no `CLAIMS.md`.

## Why

253+ claims, 34 source files and ~60 documents cite external work, and **no single file collects any of it**. The nearest thing is five incomplete entries in `GLOSSARY.md`. For a project whose output is meant to be defensible — and which the reference audit judges close to publishable — that is the cheapest structural gap on the board.

## The task

**1. Create `docs/references.md`** — one entry per external source, with complete bibliographic data (authors, title, venue, year, volume/pages, DOI or URL). The audit found these families, with these gaps:

| source | gap to close |
|---|---|
| van der Werf & Winands (ICGA 2009); van der Werf (2005 PhD thesis) | the **2005 thesis is the canonical MIGOS source and is cited nowhere**; add it as primary |
| Benson (1976), unconditional life | missing journal, volume, pages, DOI |
| Kishimoto & Müller (2004) GHI | missing venue (AAAI 2004), pages (644–649), DOI; the **2005 follow-up is missing entirely** |
| Tromp / OEIS A094777 | missing URL |
| Müller (1997) territory safety; Niu & Müller (2004) | a single informal citation; deserves a formal entry |
| Conway (1976); Berlekamp & Wolfe (1994) | adequate for recognition, complete the data |
| Knaster–Tarski, Bellman, Zobrist, Bloom | **no formal citation for any**; Knuth & Moore (1975) for alpha-beta is absent |

For each, mark **independently reproduced** / **implemented without external cross-validation** / **cited without reproduction**. The audit's finding here is worth preserving: the *only* externally-validated anchor the project has independently reproduced is **OEIS A094777**. Benson, GHI and Zobrist are implemented but never cross-validated against an external source; the 5×5 = +25 result and the CGT theorems are cited without reproduction. That distinction belongs in the file, per column.

**2. Add the six missing prior-art entries** (none affects correctness; all establish position in the literature): Schaeffer et al. checkers (2007), van den Herik et al. solved games (2002), Silver et al. AlphaGo (2016), Spight ko thermography (1999), Campbell GHI origin (1985), Knuth & Moore alpha-beta (1975). One line each on *why it is relevant to this project* — a bibliography of unread papers is worse than none.

**3. Fix three citation defects.** Verify each yourself before editing; the Orchestrator has already checked them and **two are narrower than the audit states**:

- **`docs/research/retrograde-4x4.md:74`** — the heading "published 4x4 score MATCHES under positional superko" is loose. **The body at :76-80 already states the ruleset difference correctly** ("MIGOS II plays basic-ko + long-cycle-ties, weizigo plays PSK — evidently cycle-rule-insensitive"). Fix the heading; the body needs no correction. The audit overstated this one.
- **`docs/epistemic/CLAIMS.md:401`** (`4x4.ANCHOR`) — "matches van der Werf & Winands **under PSK**" is genuinely wrong as written; MIGOS II is not PSK, and `QA-025` (PROVEN) says so. The true statement is narrower: weizigo computed +2 under PSK, MIGOS II published +2 under basic-ko + ties, and the two coincide — which is a *cross-ruleset* agreement and evidence of cycle-rule insensitivity at that position, not PSK validation. **This edit belongs to `EVIDENCE-INTEGRITY`** (it holds `CLAIMS.md`); coordinate, do not both edit it.
- **`docs/research/ruleset-options.md:215`** — "Soundness confirmed: every known anchor score falls inside its bracket". A wrong answer passes that test ~42–70% of the time. **Already known and recorded** at `critique-2026-07-28.md:107` and `CLAIMS.md:1005`, with `4x4.BRACKET` carrying a ~70% wrong-answer-pass-rate — so this is a stale source doc, not a new finding. Annotate the caption to match what the register already says.
- **`docs/research/retrograde-4x4.md:150`** — "trivially affordable at 4x4". The cheap number was bought with bracket-cut search, i.e. claim C3, falsified at 3×3. Note it. For the record, the audit's "neither document notes this" is **wrong about the register**: `CLAIMS.md:349` already carries the `e:GLOBAL.ADR0010-CUT` edge, which is precisely that note. The research doc is the one that needs it.

**4. Archive against URL rot:** the Hayward and van der Werf tengen.nl sources, under `docs/evidence/`.

## Acceptance

- `docs/references.md` exists, every family present, each entry complete or explicitly marked incomplete-and-why.
- The reproduced / implemented-not-validated / cited-not-reproduced column filled for every entry.
- The four source-doc corrections made (or, for the `CLAIMS.md` one, handed to `EVIDENCE-INTEGRITY` with the exact wording proposed).
- No claim status changed in this task.

## Deliverable

`docs/references.md` + the source-doc edits + archived sources. **Read first:** `docs/audits/AUDIT-REF-DSPro-2026-07-29.md` (the full audit — the summary above is compressed), `GLOSSARY.md`'s entry block.
