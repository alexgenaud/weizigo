# Harness divergence audit — family-conditional branches in the dispatch pipeline

**Task:** T652 (harness symmetry audit) · **Date:** 2026-08-22 · **Author:** deepseek-v4-flash/T652
**Read-only enumeration.** No code was modified. Deliverables: this table + `findings/T652-harness-symmetry.json`.

## Pinned read state (T643/T650 are live on `tools/runner`)

| artifact | state read |
|---|---|
| `tools/runner` | **working tree** = HEAD `5220234` (last runner commit `2e36495` T629) **+ T643's uncommitted diff** (127 insertions / 14 deletions: the per-harness pi/ollama progress watchdog, `--agent-progress-timeout`). T643's regression (`tools/regression-runner-agent-progress.sh`) and its `build.zig` wiring are **also uncommitted** (untracked / modified). |
| `bin/dispatch`, `bin/subagent`, `tools/dispatch_verify.py` | HEAD `5220234`, clean (no working-tree edits). |

T650 (run-record-never-overwrite) has **landed no edit** on `tools/runner` — its bundle is still dispatchable and its deliverables are not in the tree. Nothing in this table is smeared across a T650 edit. Where a row exists only in the T643 working-tree diff, the table says so.

## Family model used

The fleet dispatches three launcher shapes, detected by **child-binary basename** (`tools/runner:1432`):

| runner basename | dispatch provider | models | also covers |
|---|---|---|---|
| `pi` | deepseek | deepseek-v4-pro/flash | any pi-run model |
| `ollama` | ollama | glm-5.2, minimax-m3, kimi-k2.7 (cloud) | **local** (qwen3.8:27b-mlx, MLX) |
| `claude` | claude | claude-opus/sonnet/fable-5, haiku-4-5 | — |

So the brief's five names collapse to three basename shapes: "pi" and "deepseek" are one shape; "local" rides the ollama shape. **Any fourth harness binary is not a shape at all** — it falls to the non-agent default (rows 7/10/11).

## Divergence table — 15 family-conditional branch sites

| # | where | branch | what differs | sensing or judgement | families covered | families NOT covered | known incident |
|---|---|---|---|---|---|---|---|
| 1 | `bin/dispatch:310` | `if provider == "claude":` in `--dry-run` | claude dry-run additionally delegates to `bin/subagent --dry-run` to print the resolved `claude -p` line ("resolved:" block); deepseek/ollama print only the subagent command | sensing (display surface; the claude command is built in subagent) | claude | deepseek, ollama (no "resolved:" block — cosmetic only) | none (T481/t490 precedent shape) |
| 2 | `bin/subagent:228-246` | 3-way model resolution: `if provider == "deepseek" / elif claude / else ollama` | deepseek: exactly one of `--dspro`/`--dsflash`; claude: `--model` must be in the `CLAUDE_MODELS` whitelist (refuses non-canonical); ollama: `--model` required, tag canonicalized with a `:cloud`-strip **fallback that accepts any tag** | sensing (input contract differs per provider) | deepseek, claude, ollama | none (canonicality is enforced upstream in `bin/dispatch`; local rides ollama tags) | none |
| 3 | `bin/subagent:311` | `if provider == "deepseek" and not test_worker:` — `DEEPSEEK_API_KEY` pre-flight gate | deepseek fails **early** at dispatch without its key; claude (CLI-held session) and ollama (local server) have **no pre-flight gate** — auth failure surfaces late, inside the harness, via the refusal classifier | sensing (credential location) with a judgement consequence: same failure, different discovery latency | deepseek | claude, ollama | 2026-08-20 Ollama session-limit fleet: ~80 keeper dispatches died in ~22 s each and were misattributed as glm-5.2 failures before T538 |
| 4 | `bin/subagent:321-358` | 3-way command builder | deepseek: `pi --provider deepseek --model <m> --mode json -p` (T586: **streams**); claude: `claude -p … --output-format json` (buffered envelope); ollama: `ollama launch pi --model <tag> -y -- -p` — pi **without `--mode json`**, i.e. the buffering shape T586 was written to eliminate | sensing (invocation shape) — but the ollama arm feeds a possibly-buffering pi into a streaming-judged fuse (row 11): the sensing branch silently decides the judgement branch's outcome | deepseek, claude, ollama | — | T586 (deepseek nonce-stall: pi buffered, killed mid-work). The fix went to deepseek only; the ollama arm predates it (`92c5b46`) and was never upgraded |
| 5 | `bin/subagent:322-323` | `--rss-cap-mb` wired **only** in the deepseek branch (docstring: "deepseek only") | deepseek lanes can override the runner RSS cap; claude/ollama lanes run the runner default (12288 MB) | sensing (flag wiring) | deepseek | claude, ollama | none (minor) |
| 6 | `tools/dispatch_verify.py:166,214` | `RUNNER_CLAUDE_API_REFUSAL_RX` — the runner's own "tokens: no reading … claude api error" line | the claude-envelope `is_error` signal is a **first-class, raw-text (window-exempt)** "model never reached" censor; pi/ollama have **no analogous first-class signal** — their refusals are caught only by the head+tail 8 KiB window scan (row 14) | judgement-shaped: the same mid-log provider limit censors for claude (anywhere in the log) but for pi/ollama only inside the 8 KiB tail | claude | deepseek, ollama (mid-log refusals outside the window score as model failures) | T615/T616/T617/T621/T622 (claude 5-hour session limit) — the signal exists because of the claude family; pi/ollama never got the equivalent |
| 7 | `tools/runner:1432-1443` | `AGENT_LANE_BINARIES = ("pi", "claude", "ollama")` + `_is_agent_lane` (basename match) | gates the startup-liveness fuse scope, stdout-as-progress, and the T643 progress watchdog | judgement (what is an "agent lane", i.e. which fuses apply) — via **inferred proxy: basename** | pi (deepseek), claude, ollama | **any other binary** → silently non-agent: flat-600 s T214 `[progress]` watchdog or wall/CPU fallback | T586 (created the scope); T643 (the scope's incomplete application) |
| 8 | `tools/runner:1445-1456` | `_is_claude_lane` (basename == "claude") | claude gets the mtime fuse (deliverables + `~/.claude` transcript, 4631 s) and is **exempt** from the startup fuse and the T643 progress watchdog; every other agent lane gets stdout-based sensing | judgement (what counts as "alive" for a lane) — via **inferred proxy: basename**. The carve-out is the *correct* T634 pattern, but it is hard-coded to the name, not to buffering behaviour | claude | ollama — which runs the **same buffering pi binary** (row 4) and is judged by the streaming sensor | T616 (claude killed at 600 s, 2 s from a pass) — fixed for claude; the shape remains for ollama |
| 9 | `tools/runner:1379-1386` | `_json_output_lane` — flag pair `--output-format json` | gates envelope parse, buffered stdout, text unwrap, session-handle capture | sensing (what the harness emits) — detection **by flag, not name** (the good pattern) | claude (only family that sets the flag) | deepseek, ollama (get "no structured usage" nulls with reasons — honest nulls, row 12) | none |
| 10 | `tools/runner:1589-1608` | `_AGENT_PROGRESS_TIMEOUT_DEFAULT` + `_agent_progress_timeout` — basename → {pi: 7336, ollama: 6766, **else 0**} | per-family derived progress-watchdog threshold; an unknown basename returns **0 = watchdog silently disabled** | judgement (threshold per family) — via **inferred proxy: basename**; **T643-only (uncommitted)** | pi (deepseek), ollama | unknown basename → no progress watchdog, no deliverable-mtime sensor (startup fuse + wall/CPU only) | T643 (flat 600 s killed T526/T635/T638 — all below family p95) |
| 11 | `tools/runner:2414-2530` | 5-way kill cascade: host-guard / directive / RSS / `claude_lane` mtime fuse / `agent_lane and progress_seen` (T643) / `agent_lane` silent (startup fuse 600 s, then wall/CPU) / non-agent progress (flat 600 s) / non-agent silent (wall/CPU) | the liveness **sensors and thresholds differ per family**: claude = mtime (4631 s); pi/ollama = stdout/stderr/`[progress]`/deliverable-mtime (7336/6766 s); unknown = flat 600 s / wall+CPU. **The silent branch has no deliverable-mtime sensor** — a silent lane that writes deliverables is killed at 600 s regardless | judgement (what counts as alive, what kills) | claude (mtime), pi/ollama (stdout+mtime), non-agent (T214) | (a) silent pi/ollama lanes that write deliverables but emit nothing — killed at 600 s despite progress; (b) unknown families | T634, T643 — and the residual shape for ollama (rows 4+8) and for the silent branch |
| 12 | `tools/runner:1655-1710` | `_capture_tokens` `claude_json_lane` split | claude envelope → tokens/session/is_error; pi/ollama → explicit `missing_reason` ("no structured usage in process output (pi/ollama lane)") | sensing (structured vs unstructured emission) | claude | deepseek, ollama (nulls with reasons — the honest-null rule, never a blank) | none |
| 13 | `tools/runner:1400-1407` | `_argv_provider` — `--provider` flag, else basename | provider label for tees/ledger | sensing (labeling) | all | — | none |
| 14 | `tools/runner:680` | `ORPHAN_GUARD_PATTERNS = ("subagent", "claude -p", "runner", "fleet-keeper")` | the orphan reaper protects live suite binaries whose ancestry carries a worker marker; `claude -p` named explicitly, pi/ollama covered via `subagent` ancestry | sensing (identify live lanes to protect) | claude (by name), pi/ollama (via subagent) | a live lane whose ancestry re-parents past both markers | 2026-08-22: three live suite binaries had **no** worker marker (nohup `zig build test` under ppid 1, a pi console chain) — fixed by the live-session half of the guard, not by the family list |
| 15 | `tools/runner:2076` | `PI_MODEL` env var for the auto-claim label (direct `--task-id` invocations only) | a pi-named env var supplies the claim `--agent` label; a non-pi lane invoked directly would claim `--agent unknown` | sensing (env var is pi-specific) | pi | claude, ollama (not in the `bin/subagent` dispatch path — workers self-claim there) | none (minor) |

## Analysis

### 1. Judgement wearing sensing's clothes — the predictions (T634/T643 shape)

Three sites are the next-incident class, in the sense the brief names (a sensor correct for one family applied to another, deciding what *counts as alive / what gets scored*):

- **P1 — the ollama buffering arm (rows 4+8+11). The strongest prediction.** The ollama lane runs the same pi binary **without** `--mode json` — the exact flag T586 added to make pi stream, on the deepseek branch only. If `ollama launch pi -p` buffers until the final reply (T586's own documented premise), `progress_seen` stays `False` and the **silent branch kills at 600 s** (`--startup-timeout` default), *regardless of deliverable writes* (the T643 mtime sensor does not run in the silent branch). This is the T616/T643 defect, family not yet hit. **Predicted failure:** the first ollama lane whose run exceeds 600 s with a quiet launch stream dies `startup liveness timeout` → censored `killed_by=liveness` (T629 refuses to score it, so it is a wasted wall + tokens, not a false ledger row — the censoring machinery now catches the *consequence*). If `ollama launch` prints a launch banner, `progress_seen` flips True and the derived 6766 s threshold + deliverable mtime protect the lane; I could not run an ollama lane in this read-only audit (no credentials, no writes) — but the code path for a fully silent lane is unambiguous.
- **P2 — the unknown-family silent default (rows 7+10+11).** The entire per-harness machinery keys off one hard-coded basename tuple in three places (`AGENT_LANE_BINARIES`, `_is_claude_lane`, `_AGENT_PROGRESS_TIMEOUT_DEFAULT`). A fourth family — or a renamed binary (an updated claude CLI named e.g. `claude-code`) — silently gets: non-agent semantics, the flat-600 s T214 watchdog if it streams, **no** progress watchdog (0) and **no** mtime sensor if it does not. The T643 defect reappears wholesale for that family.
- **P3 — the silent-branch mtime gap (row 11).** T643's deliverable-mtime sensor lives only in the `progress_seen` branch. A lane that is silent *from launch* (never-started detection) but steadily writes its deliverable — the T638 shape from t=0 — is killed at 600 s despite visible progress. Same bug T643 fixed, one branch over.

A fourth, refusal-classifier-shaped divergence (not a kill fuse but a *scoring* decision):

- **P4 — claude-only raw-text censoring (row 6).** The identical mid-log provider limit censors for claude (the envelope `is_error` is searched on raw text, window-exempt) but for pi/ollama only inside the head+tail 8 KiB. A deepseek/ollama mid-turn limit that lands outside the tail scores as a model failure while the claude event is censored. The sensing difference (structured envelope vs not) is real; the *decision* asymmetry is not forced by it — the runner knows when a pi/ollama lane produced zero usage and could stamp a first-class signal of its own.

### 2. Families unhandled per branch

- **A fourth family / any non-{pi,claude,ollama} basename:** rows 7, 8, 10, 11 — the silent default is the **pre-T634/T643 behaviour**: flat-600 s `[progress]` watchdog (T214) if any `[progress]` line appears, else wall/CPU ceilings; no per-family threshold, no deliverable-mtime sensor, no mtime fuse. That default is where an unlisted family *lives*, and it is exactly the configuration that produced T526/T635/T638/T616.
- **"local" (qwen3.8:27b-mlx):** rides the ollama shape end-to-end (rows 2, 4, 7, 10, 11) — covered, but with ollama's threshold (6766 s) and, per P1, the buffering exposure.
- **ollama mid-log refusals (row 6):** only the head/tail 8 KiB windows are scanned; a mid-log deepseek/ollama refusal outside them is not censored.
- **claude/ollama auth (row 3):** no pre-flight gate; failures surface late through the classifier (row 6/14 machinery), costing a full wall per miss.

### 3. Control fixtures against the bar ("no guard ships without a null control and a seeded-defect fixture")

Guard surfaces (the kill/refusal/capture decisions), each scored null-control + seeded-defect:

| guard | regression | null control | seeded defect | committed? |
|---|---|---|---|---|
| startup-liveness fuse (rows 7+11) | `regression-runner-startup-liveness.sh` | ✓ green null, scoping null | ✓ red (never-reads-bundle stub) | ✓ HEAD |
| claude mtime fuse (rows 8+11) | `regression-runner-claude-liveness.sh` | ✓ fast null, pi null | ✓ survives (T616 shape), hung | ✓ HEAD |
| pi/ollama progress watchdog + derived thresholds (rows 10+11) | `regression-runner-agent-progress.sh` | ✓ silent null, non-agent null, derived null | ✓ survives (T638 shape), stalled | ✗ **untracked** (T643 worktree only; `build.zig` wiring uncommitted) — **at HEAD this guard has zero fixture** |
| non-agent T214 watchdog + wall/CPU (row 11) | `regression-runner-guard.sh` | ✓ null | ✓ seeded ×2, guard-bite | ✓ HEAD |
| token/session capture explicit-missing (rows 9+12) | `regression-token-capture.sh` A/B/C, `regression-session-capture.sh` A/B/C | ✓ pi-lane null (C), envelope-without-session (C) | ✓ envelope parse (A), e2e (B) | ✓ HEAD |
| claude-envelope refusal signal (row 6) | — | ✗ **none** | ✗ **none** | ✗ |
| refusal window scan (row 6/14) | `regression-dispatch-verification.sh` arms 11/12/13/17 | partial (arm 12: clean log still fail) | ✓ 429-in-head → unreached, heal-with-marker, no-record | ✓ HEAD |
| **window exclusion** — a mid-log quoted refusal must NOT censor (the T526/T601 shape) | — | ✗ **none** | ✗ **none** | ✗ |

Count: **8 guard surfaces; 5 fully covered and committed; 1 (T643 progress) fixture exists but is uncommitted; 2 (claude-envelope signal, window-exclusion) have no fixture in any state.** Against the bar, the current committed state covers 5/8; the working tree covers 6/8; 2/8 are unpinned in either state. Additionally, the P3 silent-branch gap has no fixture (no arm runs a silent lane that writes deliverables and asserts survival), and no arm pins the deepseek `--mode json` presence (a regression removing it would pass today).

### 4. Ranked fix list for the follow-on sprint (false-failure generation, most likely first)

1. **Stream the ollama arm** (`bin/subagent` row 4): add `--mode json` to the `ollama launch pi` command (mirroring T586), or, if `ollama launch` cannot stream, give the ollama lane the mtime fuse the way T634 gave claude. Kills P1. *Most likely to produce the next false failure: a silent ollama lane over 600 s.*
2. **Make the family table data, with a loud unknown default** (`tools/runner` rows 7/8/10): one `FAMILIES` dict keyed by basename → {sensor, threshold, transcript-dir, envelope-flag}, and an unknown basename → warn loudly + the most conservative fuse (T643 progress watchdog with a large default + deliverable mtime), never silent-0. Kills P2.
3. **Move the deliverable-mtime sensor into the silent branch too** (`tools/runner` row 11): a lane writing its declared deliverable is alive whatever its stream says — the never-started case emits nothing *and* writes nothing, which is what the startup fuse should detect. Kills P3.
4. **Give pi/ollama a first-class unreached signal** (`tools/dispatch_verify.py` row 6): the runner already knows a lane produced zero usage; stamp a per-family "no tokens + error" note the classifier treats like the claude envelope line, closing the P4 censoring asymmetry.
5. **Add the missing fixtures** (bar compliance, §3): commit the T643 agent-progress script + `build.zig` wiring; a V1 fixture (fake-claude `is_error` envelope through the full dispatch path → unreached); a V2-exclusion fixture (mid-log quoted 429 in a wall-killed run → **not** unreached — the exact false positive the window exists to prevent, currently unpinned); a silent-writing-lane fixture (red against today's code — proves P3); an unknown-basename fixture pinning the loud default; a deepseek `--mode json` presence arm.
6. **Pre-flight auth gate for claude/ollama** (`bin/subagent` row 3): cheapest is reachability (`ollama ps` / `claude --version`) at dispatch; at minimum record the decision that late failure is intended.
7. **Document or unify the minors** (rows 1, 5, 15): `--rss-cap-mb` deepseek-only, `PI_MODEL` claim label, the claude-only "resolved:" dry-run block. No false-failure generation; plumbing.

## Verdict

The codebase is **not symmetric where it matters**, and the enumeration supports it: **15 family-conditional branch sites, 5 judgement-shaped (rows 6, 7, 8, 10, 11), 3 hard-coded basename tables that a fourth family silently bypasses, and 2 guard surfaces plus the T643 fixtures with no committed coverage.** The direction of travel is correct — T634 and T643 are the right *per-harness-sensing* pattern, and every kill is now censored via `killed_by` so a wrong fuse costs a wall, not a false ledger row — but the pattern is applied **incompletely**: ollama never got the streaming flag, the silent branch never got the mtime sensor, and the unknown-family default is the exact pre-fix configuration that produced the incidents this audit exists to predict. P1 is the one to watch: it is the T634/T643 shape with a family name nobody has hit yet.
