# The 5×N frontier is a format decision

**Status:** MEASUREMENT / recommendation (not an operator ruling)
**Task / identifier:** T925 / gpt-5.6-luna-pro/T925
**Date:** 2026-08-25
**Landmark:** advances **L7 (the 5x5 decision, costed)** by replacing an open artifact-format variable with two measured alternatives and explicit RAM consequences.

## Executive answer

Use **WZO2** for a 5×4 oracle if the target remains the full Markov key. WZO1 is smaller to write, but it cannot represent a pending ko or a nonzero pass count; using it for a 5×4 result would knowingly project away required state. WZO2 is the only existing format that meets the semantic requirement, although the current WZO2 builder/loader is itself beyond the 48 GB host's comfortable RAM envelope at 5×4. No measurement makes WZO1 semantically adequate; changing that conclusion would require changing the target, not choosing a better compression setting.

The operator's format ruling is therefore still required: **WZO2 is the honest format choice, and 5×4 remains an implementation/RAM problem under the existing WZO2 implementation.** This document does not propose a third format.

## 1. Why the 4×4 path still writes WZO1

There are two paths, not one path that inexplicably selected the older format:

* `src/retro.zig:2378-2503` calls `artifact.save` with the six WZO1 columns. Its default 4×4 output is selected at `src/retro.zig:3213-3234`. This is the legacy dense artifact path and remains useful as a compatibility and regression input.
* `src/oracle_v2_build.zig:317-579` is a separate builder. It reads the exposed `exp6` full-key fixpoint, constructs WZO2 rows, and writes a versioned WZO2 artifact. The committed `data/oracle-4x4-v2.wzo2` is from this path.

The continued WZO1 writes have a sound **compatibility/golden-master** reason, not a sound 5×N-product reason. The battery intentionally keeps WZO1 artifacts as regression inputs (`build.zig:1939-1978`), and the 4×3 differential rung explicitly compares against a committed WZO1 golden (`src/differential.zig:1469-1475`). In contrast, the 4×4 key-agreement test reads WZO2 (`src/differential.zig:1364-1368`). WZO2 is not a drop-in replacement: WZO1 is keyed only by `(position, side)` and contains the `ko == NONE, passes == 0` slice; WZO2 stores `(position, side, ko, passes)` plus `L/H`.

Thus the answer to “why WZO1?” is “legacy compatibility and characterization remain live.” The answer is **not** “WZO1 is the preferred format for 4×4 or 5×4.”

## 2. Real 4×4 size measurement

The measurement below reads the headers and file lengths from the committed artifacts, and independently checks the WZO2 embedded counts. The WZO2 file is a real encoder output, not a formula-only estimate: it is the byte-reproducible T310 artifact (`CODE.WZO2-BUILD-REPRO`) at `data/oracle-4x4-v2.wzo2`, SHA-256 `0c3366f07fb33c6f2838ead48ad3080b64dbe55935b87af4f140d81a29e4e15a`.

Command used for the direct measurement:

```text
python3 - <<'PY'
import pathlib, struct
for p in sorted(pathlib.Path('data').glob('*.wzo*')):
    b = p.read_bytes()[:128]
    if b[:4] == b'WZO1':
        print(p, p.stat().st_size, struct.unpack_from('<Q', b, 12)[0],
              struct.unpack_from('<Q', b, 20)[0])
    elif b[:4] == b'WZO2':
        print(p, p.stat().st_size, struct.unpack_from('<Q', b, 16)[0],
              struct.unpack_from('<Q', b, 24)[0])
PY
```

| artifact | measured bytes | decimal MB | measured payload facts |
|---|---:|---:|---|
| WZO1 4×4 (`data/oracle-4x4-basicko-tie-area.wzo`) | 258,280,358 | 258.280 | `total=43,046,721`; `legal_count=24,318,165`; six raw columns |
| WZO2 4×4 (`data/oracle-4x4-v2.wzo2`) | **518,123,097** | **518.123** | `n_groups=24,318,165`; `n_entries=99,133,036`; 128-byte header, 5-byte groups, 4-byte entries |

The WZO2 decomposition is measured exactly:

```text
128 + (24,318,165 × 5) + (99,133,036 × 4)
= 128 + 121,590,825 + 396,532,144
= 518,123,097 bytes.
```

Relative to the measured WZO1 file, WZO2 is **2.006049× as large** (100.605% larger). This is expected: WZO2 carries roughly 4.075 full-key rows per legal goban and an explicit group index, while WZO1 carries six bytes per raw colex slot but no ko/pass key. The WZO2 size is not evidence of a value error; it is the cost of retaining the required state dimensions and `L/H` bracket.

## 3. Measured 4×4 density folds

The baseline for these byte comparisons is the WZO1 schema: six one-byte columns per raw colex slot plus the 32-byte header. The counts are measured structural counts, not occupancy-rate guesses.

### 3.1 Legal-only and canonical-only counts

The existing T359 census measured the full combined spatial-dihedral-plus-colour-inversion orbit set. Because this task asks specifically for the **dihedral group** (8 spatial symmetries on a square, 4 on a rectangle), I also ran a spatial-only derivative of the committed `src/symcensus.zig`: the same exhaustive odometer and legality predicate, with the colour-inversion half of the orbit elements replaced by duplicate non-inverted elements. The derivative is analysis-only and did not modify repository sources or artifacts. Its complete 4×4 readings were:

```text
raw positions                         43,046,721
legal positions                       24,318,165
spatial-D4 raw orbits                  5,398,083
spatial-D4 canonical-legal positions  3,047,783
raw / spatial-D4 orbits                       7.974
legal / spatial-D4 canonical-legal            7.979
raw / spatial-D4 canonical-legal              14.124
```

The derivative also passed its orbit partition check (`Σ orbit_size × orbit_count = raw`) and its independent colex-min versus lex-min orbit-count check at 4×4 (`5,398,083 = 5,398,083`). The seeded permutation check remains the T359 control; the 4×4 spatial-only result is a count measurement, not a new correctness claim about the solver.

For comparison, T359's already-committed **D4×colour-inversion** census gives 2,700,373 raw orbits and 1,524,805 canonical-legal orbits, with combined raw/canonical-legal fold 28.231×. That extra colour fold is mathematically available only with side/sign propagation; it is not included in the spatial-only row below.

| representation of position set | positions retained | WZO1-shaped bytes | saving vs raw WZO1 | fold |
|---|---:|---:|---:|---:|
| raw colex (current WZO1) | 43,046,721 | 258,280,358 | — | 1.000× |
| legal-only | 24,318,165 | 145,909,022 | 112,371,336 (**43.508%**) | 1.770× |
| spatial-D4 canonical-only, raw | 5,398,083 | 32,388,530 | 225,891,828 (**87.460%**) | 7.974× |
| legal + spatial-D4 canonical | 3,047,783 | **18,286,730** | 239,993,628 (**92.920%**) | **14.124×** |
| D4×colour-inversion canonical + legal (T359, comparison only) | 1,524,805 | 9,148,862 | 249,131,496 (**96.458%**) | 28.231× |

These are address-space changes. A legal-only index no longer means “raw colex offset,” and a canonical index requires mapping each transformed position to its representative (including the corresponding ko-point transform if the full key is retained). Per `docs/decisions/0011-oracle-artifact-format.md`, either requires a **colex layout-version bump**. The T359 truncation result remains important: canonical representatives are not a safe raw-colex prefix; at 4×4, truncating at 50% loses 1,055,164 combined canonical orbits (39.1%), including the high-stone endgame layers.

### 3.2 Dropping columns

No WZO1 column is semantically disposable in the complete product contract:

* `vb` and `vw` are the two side-to-move values.
* `fb` and `fw` carry the KO-sensitive / provenance flags used by existing checks and consumers.
* `db` and `dw` are DTT, required by the frozen schema and the finite-progress requirement even though the committed WZO1 4×4 artifact has the known empty-column characteristic: both DTT columns are uniformly `255` (`DTT_FAR`).

The last point is a measured defect signature, not permission to remove DTT from a correct artifact. At 4×4, the possible byte projections are:

| columns retained | bytes | saving | status |
|---|---:|---:|---|
| all six | 258,280,358 | — | current WZO1 contract |
| values only (`vb`,`vw`) | 86,093,474 | 172,186,884 (**66.667%**) | insufficient: loses flags and DTT |
| values + flags | 172,186,916 | 86,093,442 (**33.333%**) | insufficient: loses DTT |
| values + DTT | 172,186,916 | 86,093,442 (**33.333%**) | insufficient: loses KO-sensitive flags |

Removing a column preserves the logical colex address mapping, so it does **not** require a *colex* layout-version bump. It does require a WZO1 schema/format revision (`column_count` and reader contract), so it is not free. In particular, removing the uniformly-255 WZO1 DTT would make the current snapshot smaller but would preserve the DTT defect rather than fix it.

WZO2 has no separate flags columns: `ko_sensitive` is derived from `L != H`, and its key, `L`, `H`, and DTT fields are all used. There is no measured unused WZO2 column to delete.

### 3.3 Sub-byte packing

The current 4×4 WZO1 value bytes, scanned from `data/oracle-4x4-basicko-tie-area.wzo`, contain 24 distinct codes per side: `UNDEF=-128` plus 23 observed scores. A 5-bit empirical code would encode that exact snapshot. A schema-safe 4×4 code must allow `UNDEF` plus every score in `[-16,+16]`, i.e. 34 codes, so it needs 6 bits/value even if the current artifact does not exercise every value. The distinction matters: packing to the observed alphabet would be a snapshot optimization, not a safe artifact contract.

Using schema-safe widths on an interleaved WZO1 record gives:

* two values: 6 + 6 = 12 bits;
* two flags: 2 + 2 = 4 bits (bits 0–1 are the defined flag domain);
* two DTT fields: 8 + 8 = 16 bits;
* total: **32 bits = 4 bytes per raw position**, versus 48 bits = 6 bytes today.

At 4×4 this is **172,186,916 bytes**, saving **86,093,442 bytes (33.333%)**. It is a codec/schema change but not a colex-address change: it needs a format/encoding revision, not a colex layout-version bump.

For completeness, the real WZO2 rows also show the boundary: the measured 4×4 WZO2 `L` and `H` columns each exercise 29 codes, while the schema-safe score range still needs 6 bits each. Its 8-bit key byte is fully occupied at 4×4 (`terminal + side + 5 ko bits + passes`) and DTT is an 8-bit field. A hypothetical cross-row 26-bit WZO2 codec would reduce the measured 4×4 file from 518,123,097 to approximately **443,773,320 bytes**, a **14.350%** whole-file saving after retaining the 121,590,825-byte group index. This is not the frozen WZO2 codec and is not proposed as a third format; it demonstrates that bit packing is a codec revision, not a free optimization.

An external compressor is different: wrapping the unchanged WZO1/WZO2 file is format-free and does not change the colex version, but it also does not remove the uncompressed allocation or the working-set RAM wall. Compression after writing therefore does not solve 5×4's binding resource.

## 4. 5×4 choice and RAM consequences

The 5×4 raw colex count is `3^20 = 3,486,784,401`.

### Candidate A — WZO1

The current WZO1 layout would be:

```text
32 + 6 × 3,486,784,401 = 20,920,706,438 bytes
= 20.921 GB decimal = 19.484 GiB.
```

The source-level RAM consequences are different for writing and consuming:

* `artifact.encode` allocates the entire `HEADER_LEN + 6*t` output as one contiguous slice: **20.921 GB** before allocator/process overhead.
* `artifact.load` first reads the whole file and then `decode` allocates six more `t`-byte arrays. The minimum simultaneous file-plus-decoded-column storage is therefore **41.841 GB (38.968 GiB)**, before allocator/process overhead.

This is a tight but not intrinsically impossible file-buffer figure on a 48 GB host. It is nevertheless disqualified as the 5×4 oracle format by semantics: the WZO1 key has no ko-point or pass dimension, so a pending-ko state is aliased with the no-ko state. Compressing that file after writing cannot repair the alias.

### Candidate B — WZO2

The current scaling census gives a 5×4 projection of approximately `N=7.6–8.6 billion` stored entries and `G≈1.8 billion` legal groups. These are projections, not a 5×4 solve; the denominators and method are recorded in `docs/research/scaling-census-2026-08-20.md` and `GLOBAL.REACH-P4-CENSUS`.

Applying the **existing measured WZO2 layout** gives:

```text
N=7.6B: 128 + 1.8B×5 + 7.6B×4 = 39.400 GB
N=8.6B: 128 + 1.8B×5 + 8.6B×4 = 43.400 GB
```

So the candidate range is **39.4–43.4 GB decimal (36.694–40.419 GiB)** on disk. With the current `artifact2.load`, which uses `readFileAlloc` for the complete file, consumer RAM is approximately the same **39.4–43.4 GB**, plus a small checkpoint array (about 56 MB at 1.8B groups and stride 256), before process overhead.

The builder's current serialization phase is more demanding than a consumer load. `oracle_v2_build` simultaneously holds `entry_rows` (`4N` bytes), `group_headers` (`5G` bytes), and the `buildFile` result (the complete file). Thus serialization alone has a lower bound of approximately **78.8–86.8 GB** for the two copies, before `group_builders`, allocator overhead, or any solver/fixpoint working memory. The existing 4×4 builder explicitly frees large solve structures before allocating `file_bytes`; that optimization does not make a 5×4 WZO2 serialization phase fit a 48 GB host.

| candidate | artifact/file size at 5×4 | current writer minimum | current loader minimum | semantic result |
|---|---:|---:|---:|---|
| WZO1 raw | 20.921 GB | 20.921 GB contiguous output | 41.841 GB file + decoded columns | fails full-key requirement |
| WZO2 current | 39.4–43.4 GB projected | 78.8–86.8 GB serialization lower bound | 39.4–43.4 GB + checkpoints | meets full-key requirement; current implementation is RAM-bound |

## Recommendation and what would change it

I recommend **WZO2** for 5×4. It is the only one of the two existing formats that preserves the required `(position, side, ko, passes)` state and stores the bracket rather than silently collapsing it. The measured 4×4 WZO2 output confirms the format is real and reproducible, rather than a paper design.

The recommendation would change only if the project explicitly changed the deliverable from a full-key oracle to a legacy/history-free compatibility table. A 48 GB failure of the current WZO2 builder is **not** a reason to choose WZO1: it is evidence that the current WZO2 implementation needs a streaming/working-set decision before a 5×4 run. This task does not propose that implementation work or a third format, and it does not make the operator's ruling.

**Limitations:** 5×4 `N`, `G`, and WZO2 bytes are projections from the measured 2×2–4×4 scaling series, not a 5×4 solve. The 4×4 WZO2 size, counts, WZO1 size, WZO1 column contents, and spatial-D4 4×4 fold counts above are measured directly. Per-goban epistemic independence therefore applies: the 4×4 fold is not proof of the 5×4 projection.

## Evidence and reproducibility

* WZO1 contract and mandated colex-versioning for density folds: `src/artifact.zig:20-64`, `src/artifact.zig:153-224`, `docs/decisions/0011-oracle-artifact-format.md`.
* WZO2 frozen layout and current load/build behavior: `src/artifact2.zig:1-20`, `src/artifact2.zig:104-236`, `src/artifact2.zig:347-420`, `src/oracle_v2_build.zig:317-579`.
* Real WZO2 measurement and byte-for-byte rebuild provenance: `findings/T310-rebuild-reproducibility.json`, `docs/evidence/ORACLE-V2/rebuild-2026-08-03.md`, `docs/evidence/ORACLE-V2/rebuild-T310-2026-08-03.log`.
* Existing combined symmetry measurement and controls: `docs/research/symmetry-fold-census-2026-08-04.md`, `docs/evidence/T359-SYM-FOLD/run.txt`, `src/symcensus.zig`.
* Current scaling projections and their denominator caveats: `docs/research/scaling-census-2026-08-20.md`, `docs/evidence/GLOBAL.REACH-P4-CENSUS/PROVENANCE.md`.
* WZO1 DTT empty-column characteristic and battery distinction: `docs/epics/E1-markovian/sprints/verify-battery/pass1/baselines.md:217-219`, `docs/epics/E1-markovian/sprints/verify-battery/pass1/spec.md:29,86,158`.
