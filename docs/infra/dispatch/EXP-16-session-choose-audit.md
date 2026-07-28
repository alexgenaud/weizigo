<!--managent set=A-->

# EXP-16 — `Session.choose` documentation check

**Closes:** a standing-tier audit of a single load-bearing claim in
AGENTS.md and the HANDOVER doc. The claim, verbatim from AGENTS.md
§"Gotchas — read before you run anything":

> `Session.choose` in `src/gtp.zig` does table lookups only and
> never searches.

The HANDOVER doc §"Critical state" repeats the same claim. The
audit-opus-2026-07-28.md audit verdict for QA-023 also relies on
this claim ("`Session.choose` in `src/gtp.zig` does table lookups
only — it is not a searcher"). **The claim is load-bearing** for
the EXP-9 (H5a) play-time mitigation, which adds a check at the
chosen-child node on the assumption that `Session.choose` is a
single one-ply table extremum. **This task verifies the claim at
the current `src/gtp.zig`.**

**Read first:** `AGENTS.md` §"Gotchas", `docs/status/HANDOVER.md`
§"Critical state", `docs/infra/dispatch/EXP-9.md` (the H5a brief
that depends on the claim), then `src/gtp.zig` — locate
`Session.choose` and read the function in full.

**KIND:** ANALYSIS, no `holds`. Reads `src/gtp.zig` only.

**The question, stated precisely.** Does `Session.choose` (or any
function it calls on the hot path of GTP move selection) perform
*any* operation that is not a single table lookup plus a one-ply
extremum over those lookups? Concretely: does it call `solve`,
`retro_solve`, `Exact`, the finisher, the arena evaluator, or any
function whose body is more than a colex-keyed read + a min/max
comparison?

**ACCEPTANCE:** one file
`docs/evidence/GLOBAL.SESSION-CHOOSE/audit-2026-07-28.md`
containing:

- The full body of `Session.choose` (copied verbatim from
  `src/gtp.zig`, with line numbers).
- For each function `Session.choose` calls on the hot path: the
  function's name, its location (file:line), and a one-sentence
  description of what it does.
- A **verdict**, one of:
  - **VERIFIED**: `Session.choose` is a one-ply table extremum
    only. Cite the function body's last line and the lack of any
    `solve` / `Exact` / `retro` / `finisher` / `arena` call in
    the call chain.
  - **PARTIAL**: the function *is* a one-ply table extremum in
    the common case, but calls a search function on a fall-back
    path (e.g. when all children are UNDEF, when the table is
    cold, when the position is KO_SENSITIVE). Cite the fall-back
    path and the call.
  - **WRONG**: the function does search by default. Cite the
    call and the conditions under which it is invoked.
- A "what depends on this verdict" paragraph: which docs /
  briefs / decisions are safe to keep if the verdict is
  VERIFIED, which need a wording fix if PARTIAL, which collapse
  if WRONG.

**Calibration (mandatory).** The H5a brief (EXP-9.md) is the
load-bearing consumer of the claim. The worker must read EXP-9.md
§"The mitigation (with both D-3 corrections)" and check: does
the H5a design's correctness depend on `Session.choose` being a
strict one-ply extremum? Cite the H5a design's specific
assumptions. A worker who reports VERIFIED but does not check
H5a has not done the calibration.

**EVIDENCE:** the verbatim function body + the call-chain
analysis. A `PROVENANCE.md` (per `docs/evidence/README.md`) with
the commit hash (`eebe3c2`), the date, the file:line of the
function.

**Do NOT** edit `src/gtp.zig` or any other engine file. This is
a documentation audit, not a code review. If the verdict is
WRONG or PARTIAL, the fix is the user's call (and a separate
brief), not the worker's.

**Report shape:** the verdict + the function body + the
call-chain + the H5a-dependency check. Concise; this is a
single-function audit, not a sweep.
