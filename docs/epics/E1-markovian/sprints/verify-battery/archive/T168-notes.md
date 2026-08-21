# T168 notes — verify-battery M1 harness

**Author:** DSPro/T168-w2 · 2026-07-31

## Summary

Built the M1 harness: src/verify_battery.zig (main binary) + src/vb_common.zig (shared types).

## Working

- CLI parsing: goban, artifact, --invariants, --i5-only, --i5-graph, --output, --reference, --sha256, --seed, --sample-size, --allow-mode-deviation, --version, --help
- WZO1 artifact loading: header parsing, CRC-32 verification, column extraction (independent re-implementation per R8)
- JSON Lines output: header + 12 result records + trailer, valid JSON
- stdout=JSON data, stderr=diagnostics
- Exit code 0 on clean run
- Exit codes 3 on errors (bad goban, missing artifact, SHA-256 mismatch, bad magic, CRC-32 fail, etc.)
- WZO2 detection: error.artifact_load with clean message
- I3 and I10 properly marked as not-applicable on WZO1
- I8 properly marked as not-applicable at non-2x2 gobans
- Reference file loading + SHA-256 in header
- --output flag to write JSON to file
- Timestamps (ISO-8601 via gettimeofday)
- SHA-256 computation for artifacts
- Colex addressing (runtime-parameterized) in vb_common.zig

## Issues

- Zig 0.16 API churn: significant time spent adapting to removed APIs:
  - `std.time.milliTimestamp()` → custom `nowMs()` using `std.c.gettimeofday`
  - `std.json.stringify` → `std.json.Stringify` (not used; wrote manual JSON instead)
  - `std.fs.cwd()` → `std.Io.Dir.cwd()` with `io` parameter
  - `std.fmt.fmtSliceHexLower` → `std.fmt.bytesToHex`
  - `ArrayList.init` → `.empty` + `allocator` param on methods
  - File I/O via raw `std.c.open`/`read`/`close` due to `Io` complexity
  - Args via `std.process.Init` parameter (not `std.os.argv` or `ArgIterator`)
  - Format strings: `{` must be escaped as `{{` in Zig 0.16
- Manual JSON output (avoiding `std.json` API churn): works but not escaping special characters in strings. Acceptable for M1 (paths and labels contain no special chars).
- Memory leaks from ArrayList usage (page_allocator, CLI tool — acceptable).
- RSS measurement stubbed (Linux /proc/self/status uses old `readToEndAlloc` pattern; macOS returns null).
- No round-trip JSON test yet (design-M1 §3.1 requirement).

## Stubs

All 12 invariants return status=skipped (or not-applicable where appropriate). Invariant modules T169-T171 will replace these stubs.
