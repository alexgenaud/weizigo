# PROVENANCE — `GLOBAL.ADR0005-PASS` · pass exempt from superko, always available

**Author:** deepseek-v4-pro/T901 (repoint wave)
**Date:** 2026-08-24
**Claim closed:** `GLOBAL.ADR0005-PASS` — passes are exempt from superko; pass is always
available, so the "no children" case is subsumed.
**Status:** PROVEN — **unchanged by this repoint.**
**Acceptance criterion:** a committed note pinning the ruleset definition and the committed
unconditional `applyPass`, per `docs/epistemic/c3-evidence-triage.md` §3 row 38.

---

## 1. The ruleset definition

`docs/decisions/0005-*.md:47-50`:

> **Pass**: goban unchanged, do NOT push history, do NOT run `repeats` (passes are exempt from
> superko). Recurse with `to_move` negated and `passes + 1`. Pass is always available, so there
> is always ≥1 move — the old "no children" case is subsumed by passing.

The register claim is a direct restatement of these two sentences.

## 2. The committed code fact

`src/rules.zig:433-438`, `applyPass`:

```zig
pub fn applyPass(side: i8, passes: u2) ?PassChild {
    if (passes >= 2) return null; // C1
    return .{ .side = -side, .ko = @intCast(n), .passes = passes + 1 };
}
```

The only refusal is the double-pass terminal (`passes >= 2`); there is **no ko check and no
history check** — a pass is always legal otherwise, it clears the ko point (sentinel `n`), flips
side, and increments `passes`. The mechanized test `src/rules.zig:1895` ("kernel applyPass:
clears ko, flips side, increments passes") is wired into `zig build test`.

## 3. Scope limits

This is a definitional + code fact. It establishes the move-legality half (pass is always
available and superko-exempt); it does not by itself establish the `passes ≥ 1 ⇒ ko = none`
invariant's downstream uses (those are `GLOBAL.PASS-NOKO` and its dependents).
