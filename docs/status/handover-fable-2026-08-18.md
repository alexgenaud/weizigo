# Handover — Fable console, 2026-08-18 evening (context ceiling reached)

Written by claude-fable-5 at ~94% of its 200k cheap-context window, per the standing rule
(hand over before 90% — already past it). Everything below checked, not recalled.

## State at handover

- **HEAD `afd9d8f`.** Closed today: T438 (suite /tmp reads gone), T444 (stale-row triage,
  deepseek-v4-pro), T443 (storage durability, deepseek-v4-flash), T445 (live-repo escape fix),
  T440 (ledger A0012; findings file still owed → T442). T351 reopened (A0013).
- **THE INCIDENT — read `findings/T445-scratch-dir-hard-fail.json` before running anything.**
  A missing /tmp/weizigo sent 16 regression scripts' arms into the live repo (kanban wiped,
  claimlint.zig/CLAIMS.md/.gitignore clobbered, 1659 files staged). Hooks refused the commits;
  all repaired; all 17 mktemp sites now hard-fail, seeded+null controls pass.
- **IN FLIGHT: T369 suite measurement, run 2** (claimed claude-fable-5), guarded scripts, clean
  tree, ReleaseSafe, low load, log `untracked/log/t369-suite-2026-08-18-run2.log`. When it ends:
  write findings/T369 with pass/fail/crash counts + wall time vs the 2026-08-08 badge
  (904/931, 19 failed, 7 crashed, 35–45 min), and rule on whether the 7 crashes were resource
  pressure. Row deliverables also want tools/suite-truth.sh + docs/infra/suite-truth.md.
- 1–2 shells the operator sees = this suite run (tools/runner + its zig child).

## Queue, in order

1. **T369 verdict** (above).
2. **T446** — ledger-board seam (board must render assertions.jsonl closes; brief written,
   test-first bars inside). Dispatch AFTER the suite ends (it rebuilds managent).
3. **T442 + T351 — refresh briefs first** per findings/T444-stale-row-triage.json (T442's C7
   premise: true C7=8; T444's "140" was measured against the wiped store). Then dispatch.
4. **T378** — inverted White-direction guards in qa023_probe.zig:965/:1024, verified still live.
   Highest-severity untouched row: C1 readings from the shipped probe are suspect White-side.
5. **T443 policy P1–P6 ratification** (operator) — see the branch idea below.

## Operator directives, 2026-08-18 evening (verbatim intent, register before acting)

1. **Model economics:** if forced to choose between the DeepSeek pair, choose **Flash** (much
   cheaper). Standing question: **where does Pro shine enough to earn its cost**, and how do both
   compare to Opus and Fable. Today's baseline (new epoch, both first rows verified): Pro's T444
   triage was deeper per-row than Flash's T443 breadth — but that's 1 vs 1 on different tasks,
   not evidence. Race them properly.
2. **Ollama credits are plentiful right now:** use/test/compare GLM, Minimax, Kimi K2.7 liberally
   (K3 excluded on cost). qwen3.8 local trial authorized for lightweight tasks — add it to the
   canonical label list first, and don't run local inference during measured suite runs.
3. **Run the same safe, conflict-free tasks across all five-to-eight models in parallel** (or
   sequentially but blindly comparable). Read-only audits are the ideal class: same brief, one
   findings file per model, blind-scored (T328 race protocol). Write-rows need worktree isolation
   or sequential runs. Good first race candidates: an independent audit of T445's incident
   findings; the T442 brief-refresh; a repo doc-hygiene audit.
4. **Branch idea for large artifacts:** commit epic/sprint binary data to a git branch, delete
   the binary when stable, before squash/merge into main. Evaluate under T443 P2/P3 ratification
   with this caution: any committed binary enters the object store, and branch deletion alone
   does not reclaim it (needs unreachable + gc; and it bloats clones meanwhile). An **orphan
   branch never merged**, or P3's manifest + off-disk archive, likely dominates. Decide with the
   operator, don't default into it.

## Standing cautions carried forward

- Absence of an assertion is UNKNOWN. Dispatch verification has still never lied.
- DS-Flash TEMP default lapsed 2026-08-12 — operator decision pending, on new-epoch evidence.
- model-perf.md has a 2026-08-18 epoch boundary for DeepSeek: don't aggregate across it.
- data/ (1.7 GB oracle tables) still has no off-disk archive until P3 runs once.
