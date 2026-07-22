# 0001 — Branch consolidation and Zig 0.16 port

Date: 2026-07-14 · Status: accepted

## Context

Work had sat ~2 years (last real commits March 2024). Four branches existed;
`zig` had moved to 0.16 and the code no longer built.

## Decision

- Develop on **`inverse-player`** (the tip; contains all real work).
- Prune `copy-to-move` (a pure ancestor of `inverse-player`, fully subsumed)
  and `notes-on-depth-6-24bits` (its one unique file,
  `src/notes_on_depth_6_24bitz`, was salvaged onto `inverse-player` first).
  Remaining remotes: `inverse-player` + `main`.
- **Port to Zig 0.16**: `build.zig` uses `b.addExecutable/addTest` with
  `.root_module = b.createModule(...)` and `b.path(...)`; never-mutated `var`
  → `const`; `main.zig` boilerplate replaced and wired to run every module's
  tests via `zig build test`.

## Why

`inverse-player` is strictly ahead; the other branches carried no unique code
(only the one notes file). A green build on the installed toolchain is a
prerequisite for everything else.

## Verification

`zig build` ok; `zig build test` 41/41; per-module `zig test` all pass
(state 27, minimax 37, zobrist 30).
