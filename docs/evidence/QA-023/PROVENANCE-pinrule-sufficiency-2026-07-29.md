Task: PINRULE-SUFFICIENCY · Role: worker · Model: Kimi-k3 (kimi-k3) · Date: 2026-07-29

# PROVENANCE — PINRULE-SUFFICIENCY

## Build

```sh
tools/runner -- zig build-exe src/qa023_pinrule.zig -femit-bin=/tmp/pinrule -Doptimize=ReleaseFast
```

Source: `src/qa023_pinrule.zig` (new file, this task's sole src write) at the
commit of this deliverable. Base HEAD at task start: 8b610ee. Zig 0.16.0.
All runs under `tools/runner` (4 GB RSS guard; peak observed 3 MB).

## Runs (in order)

1. Baseline fidelity: `tools/runner -- zig build-exe src/qa023_probe.zig -femit-bin=/tmp/probe-head -Doptimize=ReleaseFast && /tmp/probe-head fixpoint-3x2`
   → reproduced published pin census 948/1532/142/0 at HEAD.
2. `/tmp/pinrule pinrule-census` → V0..V3 + group distribution (§1/§2 of the
   deliverable). ~0.6 s.
3. `/tmp/pinrule pinrule-diag6` → seven controls, as-shipped vs corrected.
4. `/tmp/pinrule pinrule-battery --sample 64 --node-budget 200000` →
   controls 7/7 tier+value pass; 0 tier disagreements.
5. Dry run: `/tmp/pinrule pinrule-eval --max-states 120 --node-budget 5000000 --k-long 2 --cross-every 3`
   → first witness; triggered the T3/T2 adjudication.
6. T3/T2 adjudication: `/tmp/pinrule pinrule-state 178 0 6 0 --node-budget {5000000,500000000} --k-long {2,4}`
   → T1/T2 exhaust 5·10^8; T3 −3 (22n) / −6 (33n). Independent Python
   verifier `docs/evidence/QA-023/pinrule-sufficiency-verifier.py`
   (`python3 pinrule-sufficiency-verifier.py 3000000`) reproduced T3
   exactly; 22-node tree dumped from Python and hand-verified (§5).
7. Main run: `/tmp/pinrule pinrule-eval --node-budget 5000000 --k-long 2 --cross-every 5`
   → 10m16s wall, 13,168,635,521 nodes, 3,486 evaluations, 855 within
   budget, 470/1756 states valued, 10/24 groups testable, 7 C1 witnesses,
   3 witness groups, ARRIVAL-BAD=0, T3-vs-T2 cross-checks 79/0.
   Stdout: `pinrule-sufficiency-2026-07-29.stdout`.
8. Post-pass tallies (Python, over the committed stdout): BFS-shortest
   values 396/396 == median(L,TIE,H); per-group distinct-value tables
   (bfs-only vs any-arrival); 9 groups with ≥2 BFS values, all
   single-valued. Commands: inline `python3` over the .stdout file
   (regex tally; reproduced in the deliverable §4).
9. `/tmp/pinrule pinrule-state 511 1 6 1 --node-budget 5000000 --k-long 2`
   → secondary check (all −6 with fresh collector seeds; the eval-run
   witness value −3 came from the run's own DFS history — the log's EVAL
   lines are the record).

## Rules / semantics provenance

- `apply_place` includes the 2B-FIX-KO lone-stone conjunct (formalization
  (i)) — ported verbatim.
- `truncated_value` semantics: post-2B-PROBE-FIX (arrival exclusive of σ;
  TIE on arrival-or-path revisit; area_score at passes==2; separate
  budget/scratch exhaustion). T1 is the port; T2/T3 are cost-equivalent
  (bitset membership) and pruning (alpha-beta) variants, cross-validated.
- The corrected fixpoint kernel: monotone Gauss-Seidel, the pattern of
  `src/retro.zig` (EXP-11) and `smoke_fixpoint_2x2`; validated by V1
  (residual 0), V2 (inversion 0), V3 (7/7 controls).

## Wrong-answer controls

Seven hand-adjudicated states as positive control (a TIE-always evaluator
fails loudly); ARRIVAL-BAD self-check; T1/T2/T3 tier-agreement; independent
Python reimplementation of the flagship witness end-to-end.
