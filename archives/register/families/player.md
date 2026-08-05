# Family: player — Player-side defects and play-time aids

The project diagnosed the GTP player's defects (undefined move rule in the unchainable region, greedy extremum bias, wrong-side bracket display, ko-key mismatches) and play-time aids (DTT, history-exact search feasibility, certification rates) — each cost real games and real debugging, and each corrected the player without changing the theorem — the player is a consumer of the table and Z asserts nothing about it; the fixes live in src/gtp.zig and the rulings are recorded here so a player change is never mistaken for a theorem change again.

**Members** (all moved to `rows/`):

- [`4x4.A-1`](../rows/4x4.A-1.md)
- [`4x4.A-3`](../rows/4x4.A-3.md)
- [`4x4.GREEDY-BIAS`](../rows/4x4.GREEDY-BIAS.md)
- [`4x4.GTP-DEFECT`](../rows/4x4.GTP-DEFECT.md)
- [`4x4.HISTPERF-CHEAP`](../rows/4x4.HISTPERF-CHEAP.md)
- [`4x4.REGR-CLIFF`](../rows/4x4.REGR-CLIFF.md)
- [`4x4.REGR-SYM`](../rows/4x4.REGR-SYM.md)
- [`CODE.GTP-LHSIDE`](../rows/CODE.GTP-LHSIDE.md)
- [`CODE.UNDEF`](../rows/CODE.UNDEF.md)
- [`GLOBAL.ADR0009-DTT`](../rows/GLOBAL.ADR0009-DTT.md)
- [`GLOBAL.ADR0014-DEAD`](../rows/GLOBAL.ADR0014-DEAD.md)
- [`GLOBAL.B-1`](../rows/GLOBAL.B-1.md)
- [`GLOBAL.H2`](../rows/GLOBAL.H2.md)
- [`GLOBAL.H3`](../rows/GLOBAL.H3.md)
- [`GLOBAL.H3-LOWERBOUND`](../rows/GLOBAL.H3-LOWERBOUND.md)
- [`GLOBAL.H5`](../rows/GLOBAL.H5.md)
- [`GLOBAL.H5a`](../rows/GLOBAL.H5a.md)
- [`GLOBAL.H5a-CHILD`](../rows/GLOBAL.H5a-CHILD.md)
- [`GLOBAL.H5a-FALLBACK`](../rows/GLOBAL.H5a-FALLBACK.md)
- [`GLOBAL.H5b`](../rows/GLOBAL.H5b.md)
- [`GLOBAL.H5d`](../rows/GLOBAL.H5d.md)
- [`QA-002`](../rows/QA-002.md)
- [`QA-014`](../rows/QA-014.md)
- [`QA-020`](../rows/QA-020.md)
