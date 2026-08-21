# Pass 2 — spec audit disposition (4 lanes)

**Verdict: PASS-WITH-FINDINGS.** Core is sound — HOLD-1..5 are each testable and jointly close the
"inferred, not held" root cause; the data-not-code direction is right; all citations resolve on disk.
Four musts + convergent shoulds to fix in the spec, then re-audit. Lanes: Opus (11 findings), Flash (6),
Sonnet (2), Haiku (3) — heavily convergent.

| # | finding (sev) | lanes | disposition |
|---|---|---|---|
| F1 | HOLD-6 is false: the kept `tools/runner` still writes run records/heartbeats (`task_identity` from `MANAGENT_TASK_ID`); single-writer is a *path* property, not a parenthood property (must) | Opus, Flash | **ACCEPT.** Scope HOLD-6/C7 to the dispatch path and name `tools/runner` a permitted residual writer, OR migrate run-record/heartbeat writes under the store lock (the seed's Pass 5, currently deferred). |
| F2 | The seed's Pass-5 run-record migration is deferred; §7 substitutes an assertion for it (must) | Opus | **ACCEPT.** Pull Pass 5 into scope, or state the deferral honestly — do not let HOLD-6 claim what the deferred pass holds. |
| F3 | DP-4 forbids the one family branch the tree needs — the claude JSON-envelope unwrap; the flag-keyed seam (`tools/runner:1044`, "by the flag pair, not the binary name") must be adopted by name (must) | Opus | **ACCEPT.** Name the flag-keyed design explicitly; a `--output-format json` seam is family-independent. |
| F4 | Fifth model list — `fleet-keeper.sh:286-287` holds 5 of 10 canonical labels (the F7/T503 defect); "behaviour-preserving" copies it and no gate catches it (must) | Opus, Sonnet | **ACCEPT.** DP-2 must pin the single canonical list; a gate must fail on a second list. |
| F5 | DP-3 gate under-specified: no sentinels on `canonical_models[]`, `\bpi\b` trips prose, and it inverts pass-1's *inclusive* sentinel sweep (should) | Opus, Flash, Sonnet, Haiku | **ACCEPT.** Adopt pass-1's inclusive-sentinel form (the one that shipped and works). |
| F6 | The launch-template table does not exist — data-not-code cannot hold until it does (should) | Haiku, Flash, Sonnet | **ACCEPT.** Build the table in pass 2; it *is* the data-not-code deliverable, not a later add-on. |
| F7 | Arm B-7 passes via a pass-1 G3 refusal, not the downward rule; refuse-vs-exclude unpinned (should) | Opus, Flash | **ACCEPT.** Pin the semantic and the seeded construction (downward-test seed outside the verb's ancestry). |
| F8 | Behaviour-preserving fleet-fill: six state files, §2.4 migrates one; no golden-master characterize arm; `regression-fleet-keeper.sh` never cited (should) | Opus, Flash | **ACCEPT.** Migrate all six state files; cite the existing suite as the characterize/golden-master arm. |
| F9 | S9 doesn't pin the release tag/path (launch uses raw `glm-5.2:cloud`, §4 releases canonical `glm-5.2`) (should/could) | Opus, Flash | **ACCEPT.** Assert the *launched* tag and pin which release route the stub records. |
| F10 | HOLD-1 "no detach anywhere" can't hold for ollama (daemon-owned model) (could) | Flash | **ACCEPT.** Scope the wording to the supervisor's spawn mechanics, or name the ollama daemonization as the stated exception. |
| F11 | C1–C6 ID collision (pass-1 runner kill sites vs pass-2); no commit-pinning of citations (could) | Opus, Sonnet | **ACCEPT.** Rename the pass-2 set; pin citations to commits. |

**Fix routing:** Opus revises `pass2/spec.md` to close F1–F11 and fold two operator refinements — (a)
**appetite as a 0–99 dial per family** (turn Claude down / Ollama up as credit windows approach and
reset), replacing static levels with a continuous dial whose extremes are hard-forbid and back-pressure;
(b) **runaway/recursion safety as a first-class Must** (no runaway agents, no infinite recursion — the
mint-delta check + one-author-per-mint from the queue sketch). Then re-audit.
