# P1 design audit
Auditor: DSPro/T255 · Date: 2026-08-01
Verdict: PASS

## Scope
Adversary review of `src/differential.zig` (315 lines, T226 P1). Seven gates as specified
in the brief. Every line read; every branch traced manually; the three test cases executed
(zig test passes 3/3); the harness run against real implementations by T256 (81/81 @ 2×2,
729/729 @ 3×2, all agree).

## Findings

### F1 — Vacuous truth on empty impls (QA-023 class)
**File:line:** src/differential.zig:77-84
**Severity:** MEDIUM
**Gate:** #4 (known-bad can pass for wrong reason)

When `impls.len == 0`, the harness returns `agreements = boards.len` without calling any
function. The comment marks this "vacuously true" — which is logically correct (zero
implementations vacuously agree) but is a QA-023-class footgun: if a comptime configuration
error or a refactoring accident produces an empty impls slice, the harness silently reports
perfect agreement. The instrument reports success without testing anything.

The current test suite is NOT affected (the known-bad fixture uses 3 impls and checks exact
witness values), but there is no defense-in-depth against an empty-impls call in production
or in future tests.

**Fix:** assert `impls.len > 0` or return `error.EmptyImpls`.

### F2 — Memory leak on OOM error paths
**File:line:** src/differential.zig:90-104 (body of the `for (boards)` loop)
**Severity:** LOW
**Gate:** #7 (memory leak)

Two leak sites, both on OOM:
- **F2a (line 92):** If `alloc.alloc(T, impls.len)` fails on a non-first board iteration,
  the `values` arrays already stored in `disagreement_list` are leaked — `disagreement_list`
  goes out of scope without `deinit`.
- **F2b (line 104):** If `disagreement_list.append` fails, the `values` allocated at line 92
  for the current board is leaked.
- **F2c (line 108):** If `disagreement_list.toOwnedSlice` fails, the ArrayList's internal
  items are leaked.

All three are OOM-only paths. The success path is clean: agreement values are freed at line 105,
disagreement values are freed in `Comparison.deinit`. In Zig, OOM-path leaks are conventionally
tolerated, but for a harness whose primary value proposition is correctness the leak is worth
noting.

**Fix:** wrap the loop body in `errdefer` that frees `disagreement_list` items, or use an arena
allocator internally (the `main()` caller already uses an arena).

### F3 — `Impl.file` is dead data
**File:line:** src/differential.zig:31
**Severity:** LOW
**Gate:** #3 (one-line registration) — tangential

The `file` field is stored in every `Impl`, carried through `Comparison.impls`, and never read
by the comparison logic, the deinit, the test assertions, or the `main()` display loop. It is
dead weight. Either it was intended for future use (disagreement reporting should name source
files) and never wired up, or it should be removed. As-is it inflates the registration line
(now 3 fields instead of 2) without benefit.

**Fix:** either remove it, or print it alongside `name` in the disagreement display loop at
lines 287-305.

### F4 — Seeded-defect mutant lives in test file, unprotected from neutralization
**File:line:** src/differential.zig:148 (definition), src/differential.zig:157 (use)
**Severity:** LOW
**Gate:** #6 (seeded-defect can be bypassed)

The `alwaysOne` mutant is a regular `test`-scoped function in the same file as the test that
uses it. A developer who "cleans up" duplicate test functions could change `alwaysOne` to
return 0 — the tests would still pass (perfect agreement), but the mutant control would be
silently destroyed. The T256 build auditor confirmed this: the test fails correctly when
`alwaysOne` is mutilated, but nothing prevents someone from doing it unintentionally.

The mutant is only used in tests (not in `main()`), so this is a CI-level concern. In
production, the harness compares independently-authored implementations (exp6 vs Rules),
which is the real control.

**Fix:** add a comment at the `alwaysOne` definition: `// MUTANT — DO NOT MAKE RETURN 0`.
Minimal defense; the real protection is code review.

## Gates — disposition

| # | Gate | Verdict | Detail |
|---|---|---|---|
| 1 | False positive | PASS | `std.meta.eql` on `i8` is exact bitwise equality; no coercion path exists |
| 2 | False negative | PASS | Same — bitwise equality; two `i8` values with equal bits compare equal |
| 3 | One-line registration | PASS | One struct literal: `.{ .name = "x", .file = "f", .func = f }` (F3 notes file is dead, not that it costs more than one line) |
| 4 | Known-bad QA-023 | PASS* | The known-bad test checks exact witness values `[0,1,0]`, not just disagreement counts — it cannot pass vacuously. F1 is the latent empty-impls hazard; the fixture with 3 impls is immune |
| 5 | Null control | PASS | Same function ptr twice → same return value → `std.meta.eql` returns true → agreement. No failure mode |
| 6 | Seeded-defect bypass | PASS* | The harness correctly catches the 0-vs-1 mutant. F4 notes the mutant is unprotected from human editing |
| 7 | Memory leak | PASS* | Success path clean via `deinit`. F2 documents OOM-path leaks |

All gates pass. Asterisks mark findings with LOW or MEDIUM severity — none are blockers, none
are correctness bugs in the current usage, and none produce a false reading from the harness.

## Audit method
- Full manual trace of `compare`, `enumerateBoards`, `Comparison.deinit`, and all three tests.
- `zig test src/differential.zig` — 3/3 pass in 0.036 s (ReleaseSafe).
- Build audit (T256, independent) confirms `zig run` produces 81/81 and 729/729 ALL AGREE
  against real exp6-vs-Rules implementations.
- Adversarial search for integer coercion, type-erasure, vacuous-comparison, and
  short-circuit-evaluation paths — none found for the `i8` comparison metric.
