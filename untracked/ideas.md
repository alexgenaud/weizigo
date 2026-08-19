# Ideas and goals — one line each; ideas are NOT tasks and must not be dispatchable

Created by T462 (backlog triage, 2026-08-19). Rows moved out of the kanban carry a one-line
epitaph (archive, never delete): what it was, why it left. Briefs remain on disk under
`untracked/T<nnn>-*.md` — a promoted idea is one dispatch away.

- T351 — suppress cosmetic `failed command:` noise from test stderr (green suite should read green) — left kanban: cosmetic, low severity; brief refreshed 2026-08-18 but line numbers must be re-derived at dispatch.
- T352 — fix the T227 regression timeout and wire it into `zig build test` — left kanban: defect persists (build.zig:299 still defers it, script `tools/regression-T227.sh` exists unwired) but below do-now; diagnosis needed.
- T353 — `managent orient`: cut the ~1,524-line dispatch preamble to one generated surface ≤150 lines — left kanban: feature, no defect; note its hold `src/managent/main.zig` collides with T446's file.
- T357 — measure the Ollama concurrency limit instead of guessing five — left kanban: measurement, quiet-fleet precondition not met, no urgency.
- T358 — scaling census: measured cost per board size (2×2…4×4), falsifiable 5×4/5×5 projection — left kanban: measurement feeding L7 (the 5×5 decision); artifacts still on disk.
- T362 — the memory guard must watch the host, not one process (per-process caps don't compose; 5×8 GB on 48 GB host → OOM-panic band) — left kanban: fleet-hot safety row, dispatch on fleet drain; holds `tools/runner`.
- T364 — a killed worker must leave a record and `managent reap` must exist — left kanban: fleet-hot, dispatch on fleet drain; holds `tools/runner`.
- T449 — `tools/runner` blind inside a git worktree (isdir('.git') misses the gitdir: file form) — left kanban: latent since the no-worktrees ruling (6f001ef); fix if worktrees return.
- T450 — `tools/pilot_gate.sh` writes live tracked artifacts before the gate that would catch a determinism break — left kanban: real but below do-now; the `--full` destructive branch waits on the storage ruling.
- T458 — disambiguate "row" → task / task row / claim / claim row in the startup-path docs (AGENTS.md first) — left kanban: operator ruling, cheap, one dispatch away; promote any time by dropping a do-now row.
- Background candidate — one random optimal-play simulation per pass from a random/suboptimal position, oracle prediction vs played result — not selected: the three-slot background cap is occupied by STANDING-CLEANUP + STANDING-ABSORB + STANDING-CLAIMVERIFY; promote by dropping one.
- Background candidate — one claim-register spot-audit per pass (register ↔ findings ↔ git consistency) — not selected: overlaps STANDING-CLAIMVERIFY and claimlint's automated checks; promote by dropping one.
- Mechanism idea — a `managent retire` verb to move a dispatchable row to archive/ideas with an epitaph — without it the queue can only physically shrink by Orchestrator-side store edits; the "short backlog" end state depends on it (see backlog-2026-08-19.md).
