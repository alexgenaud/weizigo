# T168 findings capture — DSPro/T173 · 2026-07-31

## What was produced
- `src/vb_common.zig` (677 lines) — shared types: GobanSize, Invariant, CheckStatus,
  ExitClass, ArtifactKind/Format, WZO1 decoding, JSON record writer, goban-size
  parameterisation, mode matrix.
- `src/verify_battery.zig` (663 lines) — CLI parsing, artifact loader, result schema,
  header/trailer emission, invariant orchestration, exit-code discipline.

## What works (in vb_common.zig)
- Type definitions look correct against design-M1.
- WZO1 header parsing and column extraction.
- Mode matrix matches §6a.
- JSON writer (with Zig 0.16 fix).

## What fails (compilation against Zig 0.16)

### Resolved by DSPro/T173
- `std.time.milliTimestamp()` → nowMs() using `std.c.clock_gettime`
- `std.fs.cwd()` → `std.Io.Dir.cwd()` (some instances)
- RSS HWM function stubbed (platform-specific io required)

### Still broken
1. `std.fmt.fmtSliceHexLower` → need `std.fmt.bytesToHex` (for comptime-known data only;
   runtime data needs different approach)
2. `std.json.stringify` → need `std.json.fmt(value, .{})` with `{f}` format
3. `std.io.getStdOut()` → need `io.stdout.writer()` (io from init parameter)
4. `std.Io.Dir.cwd().readFileAlloc(io, ...)` — correct API but `io` not always in scope

## Root cause
The DeepSeek subagent (v4-pro) produced code targeting an older Zig API (~0.13-0.14).
Zig 0.16 made breaking changes to: time, fs, json, process, ArrayList, and Io.

## Assessment
vb_common.zig is close to correct (needs only json fix). verify_battery.zig needs
a systematic port: threading `io` through call chains, replacing all removed APIs,
and handling runtime hex formatting differently.

## Next step
Fix the remaining 4 errors and get the binary building. ~30 min of mechanical porting.
