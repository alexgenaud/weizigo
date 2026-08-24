# PROVENANCE — `GLOBAL.ADR0014-PURE` · `score.zig` consults no oracle

**Author:** deepseek-v4-pro/T901 (repoint wave)
**Date:** 2026-08-24
**Claim closed:** `GLOBAL.ADR0014-PURE` — `score.zig` consults no oracle values; every public
function carries an epistemic tag; the report does not claim the fresh-start value and does not
bound the real-game PSK score.
**Status:** PROVEN — **unchanged by this repoint.**
**Acceptance criterion:** a committed note pinning the `score.zig` header + imports and the ADR
decision text, per `docs/epistemic/c3-evidence-triage.md` §3 row 43.

---

## 1. The committed source (header + imports)

`src/score.zig:19-36`:

```zig
// BOARD-SNAPSHOT SCORING — pure geometry, no oracle, no history.
// …
// Every public claim is tagged PROVEN, CLAIMED, or CLAIMED heuristic in its doc comment;
// this module does NOT consult the oracle/fresh-start table.

const std = @import("std");
const rules = @import("rules.zig");
```

The module's **only** imports are `std` and `rules` — a no-oracle-imports grep over
`src/score.zig` returns no `oracle` import. The header states both remaining clauses verbatim:
"Every public claim is tagged PROVEN/CLAIMED/…" and "does NOT consult the oracle/fresh-start
table".

## 2. The ADR decision text (report half)

`docs/decisions/0014-*.md:16-25` (Decision: "Pure: computed from the goban snapshot only … No
oracle values are consulted. Every public function carries an epistemic tag.") and
`0014:65-71` ("The score report is **goban-only**. It does not claim the fresh-start oracle
value and does not bound the real-game PSK score.").

## 3. Scope limits

This is an inspection claim about committed code, verified at HEAD (the no-oracle-imports grep
is seconds of compute). It says what `score.zig` *does not* do; it does not certify the
correctness of any score it does compute (that is `GLOBAL.S4` and its dependents).
