# Family: design — Engine design rationale and 5×N projections

The register recorded the retrograde engine's design rationale (fixpoint-iteration necessity, successor sweeps, full-goban-only search, RAM-lean V1) and the 5×5 feasibility arithmetic (layers exceed RAM, fingerprint-width tradeoffs, sweep growth) — the rationale justified the design that works, the projections feed a 5×5 decision that is not this Z's — the engine is built and verified on the solved gobans; the rationale is history and the projections are L7's input, neither is a live claim about any solved goban.

**Members** (all moved to `rows/`):

- [`4x4.DRIVER`](../rows/4x4.DRIVER.md)
- [`GLOBAL.ADR0002-SEQ`](../rows/GLOBAL.ADR0002-SEQ.md)
- [`GLOBAL.ADR0005-SUBBOARD`](../rows/GLOBAL.ADR0005-SUBBOARD.md)
- [`GLOBAL.ADR0007-AB`](../rows/GLOBAL.ADR0007-AB.md)
- [`GLOBAL.ADR0007-BACKEDGE`](../rows/GLOBAL.ADR0007-BACKEDGE.md)
- [`GLOBAL.ADR0009-SUCC`](../rows/GLOBAL.ADR0009-SUCC.md)
- [`GLOBAL.ADR0012-5X5`](../rows/GLOBAL.ADR0012-5X5.md)
- [`GLOBAL.ADR0012-LAYER`](../rows/GLOBAL.ADR0012-LAYER.md)
- [`GLOBAL.ADR0012-V1`](../rows/GLOBAL.ADR0012-V1.md)
- [`GLOBAL.F4-COST`](../rows/GLOBAL.F4-COST.md)
- [`GLOBAL.FIN-BRACKET`](../rows/GLOBAL.FIN-BRACKET.md)
- [`GLOBAL.FIN-NEARTERM`](../rows/GLOBAL.FIN-NEARTERM.md)
- [`GLOBAL.FWD-INTRACT`](../rows/GLOBAL.FWD-INTRACT.md)
- [`GLOBAL.SWEEPS`](../rows/GLOBAL.SWEEPS.md)
