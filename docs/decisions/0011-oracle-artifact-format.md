# 0011 — Oracle artifact format (WZO1): the persisted perfect oracle

Date: 2026-07-21 · Status: **accepted**; first artifacts written this session

ADR-0007 made the oracle the goal; ADR-0008/0009 froze its semantics and
schema and both warned: version the colex layout in the persist header BEFORE
writing real data (the layout defines where every value lives — changing it
silently re-addresses every file). With the 3x3 oracle complete (ADR-0010),
this ADR freezes the on-disk artifact and writes the first real ones.

## Decision 1: the artifact is its own format, not a persist.zig extension

`persist.zig` (WZG1) checkpoints the forward TT — sparse, delta+varint,
resumable search state. The artifact IS the product: a dense, colex-addressed
table meant for O(1) mmap-able lookup. Different lifecycle, different codec,
different module: `src/artifact.zig` (WZO1), standalone (std + colex only —
the dyld test discipline).

## Decision 2: header carries BOTH format and layout versions

Little-endian, 32 bytes: magic "WZO1", format_version, **colex_layout**
(= `colex.layout_version`, new constant owned by colex.zig — the module whose
ordering IS the contract), board w/h, value_semantics (1 = fresh-start,
ADR-0008), rules_id (1 = Chinese area, komi 0, positional superko,
Benson/double-pass terminal), column_count, total (u64, must equal 3^(w*h)),
legal_count (provenance/sanity), CRC-32 of the payload. A reader REFUSES a
mismatch on any of these — the density folds planned for 5x5 (legal-only,
canonical-only) are layout changes and will bump `colex.layout_version`.

## Decision 3: payload = the six frozen schema columns, dense over RAW colex

`vb | vw | fb | fw | db | dw`, each `total` bytes (ADR-0009 decision 4:
value i8 / flags u8 / dtt u8, per side; UNDEF −128 = illegal slot, DTT 255 =
FAR; side picks the COLUMN, never the sign). Dense-raw is deliberate
(colex.zig "RAW"): simple, byte-addressable, sufficient through 4x4 (3^16 x 6
= 258 MB). Compression is layered OUTSIDE the format if wanted (gzip the
file); the format itself stays seekable.

## Decision 4: only complete, validated oracles get persisted

`retro.saveArtifact` refuses to write unless the build passed its battery in
the same process: finisher completed every orbit (no budget-skips), zero
bracket-fails, zero orbit-clashes, exhaustive symmetry PASS, no UNDEF value
on any legal slot. After writing it RELOADS the file and verifies every
column byte-identical plus key facts re-read from the loaded data — future
sessions trust the FILE, not the RAM it came from.

## First artifacts (committed, reproduce with `RETRO_SAVE=1 zig run -O ReleaseFast src/retro.zig`)

    artifacts/oracle-2x2.wzo      518 B   empty(B) = +1
    artifacts/oracle-3x2.wzo    4,406 B   empty(B) = +1
    artifacts/oracle-3x3.wzo  118,130 B   empty(B) = +9, dtt 3 (published anchor)

All three: columns IDENTICAL on reload, headers verified. The 2x2/3x2
empty-board fresh-start values (+1 both) are engine-produced data validated
by the exhaustive 2x2/3x2 ground-truth batteries.

## Consequences

- 4x4 artifact = 258 MB raw when the scale run lands; same writer, no format
  change. 5x5 requires density folds -> colex_layout version 2, reader keeps
  refusing what it cannot address.
- DTT stays best-effort where optimal lines cross unfinished V1 slots
  (documented in ADR-0009); a later V1-finishing pass would only tighten a
  side-file column, never move addresses.
- Consumers (query engine, teaching layers) read artifacts through
  `artifact.load` and get the format contract checked for free.
