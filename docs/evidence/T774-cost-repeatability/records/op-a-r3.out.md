# Read-only audit — silent-wrong-answer hazards in the cost-measurement surface

**Task:** T774 · read-only · no file written, no test script run, no mutation. All inspection was `cat`/`sed`/`grep`/`python3 -c` reads of session and record JSON.

---

## 1. Denominator

| file | lines | functions (top-level + nested) | functions examined | lines read |
|---|---|---|---|---|
| `tools/token-capture.py` | 829 | 30 + 1 (`_num`) = **31** | **31 / 31** (whole file) | 829 / 829 |
| `tools/token-backfill.py` | 398 | **10** | **10 / 10** (whole file) | 398 / 398 |
| `tools/runner` | 3336 | 63 + 1 (`sort_key`) = **64** | **46 / 64** | ~1470 / 3336 |
| **total** | **4563** | **105** | **87 / 105 = 83%** | ~2700 / 4563 = 59% |

**The 18 `tools/runner` functions I did NOT read**, and why they are out of scope: `_find_repo_root`, `_check_directives`, `prepend_releasefast`, `sweep`, `sort_key`, `_ps_proc_table`, `_is_zig_tree_cmd`, `_classify_suite_orphan`, `_load_orphan_state`, `_save_orphan_state`, `_append_orphan_log`, `reap_orphans`, `_reap_tree`, `_runner_print`, `_host_avail_bytes`, `_declared_tenant_reservation_bytes`, `_log_peaks`, `_harness_p95_markdown`. None of these writes a token/cpu/rss value into a run record, the ledger, or a heartbeat; the orphan-reaper and sweep clusters are a separate instrument sharing the file. Four more (`_host_mem_bytes`, `_claude_transcript_dir`, `_claude_sensor_max_mtime`, `main`) were read partially and are counted as examined only for the parts quoted below.

I also read live artefacts at HEAD to test reachability: `untracked/runs/*.json` (13 records), `untracked/tokens/tokens.jsonl`, and three real pi session files under `untracked/bakeoff/t774-cost-repeatability/`. Several rows below are **confirmed against that live data**, not merely inferred.

---

## 2. Sites

| # | file:line | code | mechanism → wrong / silently-empty reading | reachable at HEAD? | sev |
|---|---|---|---|---|---|
| S1 | `tools/token-capture.py:678-681` | `for k in TOKEN_KEYS:` / `    v = e.get(k)` / `    if isinstance(v, (int, float)):` / `        a["tokens"][k] += v` | `TOKEN_KEYS` includes `"total"`, but **no ledger writer ever emits a `total` key** (`tools/runner:2352-2357` writes only `input/output/cache_read/cache_write/reasoning`). So every ledger-backed model aggregates `tokens["total"] == 0`, and `tools/token-capture.py:706` prints it: `m, a["tokens_in"], a["tokens_out"], a["tokens"]["total"]))`. A model that burned 3 M tokens reports `total 0` next to a correct `tokens_in`. | **Reachable — confirmed.** Live ledger rows for `deepseek-v4-flash` carry *none* of the component keys (`{"missing_reason": null, "model": "deepseek-v4-flash", … "tokens_in": 2931079, "tokens_out": 48723}`), so for pi lanes `input/output/cache_read/cache_write/reasoning` **and** `total` all aggregate to 0 while `tokens_in/out` are real. | **high** |
| S2 | `tools/runner:2262-2268` | `out["tokens_in"] = (parsed["input"]` / `                     + parsed["cache_read"])` … `out["tokens_out"] = parsed["output"]` | `read_pi_session` returns `reasoning` (`tools/token-capture.py:394`: `"reasoning": acc["reasoning"], "turns": turns,`) and the runner **discards it**. Measured on `T774-ds-a-r3` at HEAD: `output 48723 reasoning 37220`; `totalTokens 2979802` equals `input+output+cacheRead+cacheWrite` exactly, i.e. pi's own total also excludes reasoning. The ledger row records `tokens_out: 48723` — 37,220 output-side tokens invisible, 43% of that lane's generation. The claude branch *does* keep it (`tools/runner:2357` `"reasoning": usage.get("reasoning")`), so the omission is asymmetric across families in a cross-family cost race. | **Reachable — confirmed** on the three live deepseek sessions (reasoning 33 228 / 37 220 / >0, none recorded). | **high** |
| S3 | `tools/token-capture.py:388-390` | `if turns == 0:` / `    return {"ok": False,` / `            "reason": "no usage-bearing turns in %s" % ...}` | The gate counts **assistant messages**, not usage. `turns += 1` at `:380` happens before `_add_usage(acc, m.get("usage"))` at `:381`, and `_add_usage` returns silently on a non-dict (`:303-304` `if not isinstance(usage, dict): return`). A session with assistant turns but no/renamed usage objects returns `ok=True` with every component 0 → `tools/runner:2261` `if parsed.get("ok"):` records `tokens_in=0, tokens_out=0, source="pi-session-jsonl"`. A **silent zero recorded as a real reading**, exactly the "free lane" the brief names. The reason string even claims the opposite of what happened. | **Reachable, conditionally.** The key map `_harness_key` (`:311-320`) is hard-coded camelCase (`"cache_read": "cacheRead"`); I verified it matches deepseek-via-pi at HEAD (`usage keys {'input','output','cacheRead','cacheWrite','reasoning','totalTokens','cost'}`). The docstring's claim at `:347-348` that "the same key set was observed for … local ollama" is an **unverified assertion** — no ollama session exists in this tree to check. Any key-set drift lands here silently. | **high** |
| S4 | `tools/token-capture.py:268-270` | `usage_obj = obj.get("usage")` / `if not isinstance(usage_obj, dict):` / `    return result, None, meta` | An **empty** `usage: {}` is a dict, so it passes the guard; `_num` (`:272-274`) then returns 0 for every key and `:286-291` builds a fully-zero usage dict. `tools/runner:2212` `if usage is not None and not meta.get("is_error"):` accepts it and stamps `tokens_in=0, tokens_out=0, source="claude-json-envelope"`. Silent zero, not UNKNOWN. The only shape that yields UNKNOWN is a *missing* `usage` key, not an empty one. | **Reachable** — nothing between the envelope and this branch rejects `{}`; the runner has no post-parse zero check (`:2217-2221`). | **high** |
| S5 | `tools/runner:3276-3277` | `peak_rss_mb = max(peak_rss.values()) // (1024 * 1024) if peak_rss else 0` / `total_cpu_sum = sum(peak_cpu.values()) if peak_cpu else 0.0` | "Never sampled" and "genuinely zero" collapse to the same recorded value. The monitor loop tests `ret = proc.poll()` at its top (`:2873-2874`) and breaks before any sampling, and the poll cadence is `poll_s = args.poll_ms / 1000.0` (`:2615`) with `default=250` (`:2472`). A child that exits inside the first quarter-second is finalized with `cpu 0.0, rss_mb 0` — a run that reads as measured and free. Identical construct on the kill path at `:3218-3219`. | **Reachable** — no guard distinguishes an empty sample dict from a real 0; contrast the token path, which is explicitly nulls-plus-reason. | **high** |
| S6 | `tools/runner:2959-2991` | `for pid in pids:` … `if rss is None:` / `    continue` … `                    break` … `cpu = _cpu_time_seconds(pid)` | CPU is sampled **only after** a successful RSS read for the same pid, and only for pids alive at a poll instant. Three losses: (a) any pid whose RSS read fails (`None` at `:2966`, ps failure at `:2976/2978`) never gets its CPU read at all; (b) the RSS-cap `break` at `:2985` abandons CPU for that pid and every later pid in the poll; (c) short-lived grandchildren born and dead between 250 ms polls are never seen — a lane that shells out constantly is measured as cheaper than one that doesn't. This makes cpu-seconds a **model-dependent** undercount, which is fatal for a cost comparison specifically. | **Reachable — corroborated.** Live records show `T774-op-a-r1: wall 622.1 cpu 2.7` and `T774-ds-a-r1: wall 388.5 cpu 5.1` — cpu is a small, poll-sampled residue of wall in every record in `untracked/runs/`. | **high** |
| S7 | `tools/runner:2942` + `:1055-1076` | `pids = _WALKER_FN(proc.pid)` ; walker builds `children.setdefault(ppid, []).append(pid)` then BFS from `root_pid` | The tree is walked by **PPID**, but the child is deliberately put in its own **session/process group** (`:2637` `preexec_fn = lambda: os.setsid() if hasattr(os, "setsid") else None`, comment at `:2634-2636`: "New process group so SIGKILL reaches the whole tree"). A grandchild whose intermediate parent exits is reparented (ppid → 1) and **leaves the walk** while still running in the same pgid — its RSS and CPU stop being counted from that moment, though the reaper would still kill it. Measurement scope ≠ kill scope. | **Reachable** — the two scopes are computed by different code with no reconciliation; `_reap_tree` takes `seed=last_poll_pids` (`:3273`), i.e. it too inherits the ppid-walk blind spot for anything the last poll missed. | **medium** |
| S8 | `tools/token-capture.py:355`, `:368`, `:371` | `bad = 0` … `except ValueError:` / `    bad += 1` / `    continue` … `bad += 1` | `bad` is incremented and then **never returned, logged, or thresholded** — `read_pi_session` returns at `:391-395` without it. A session file with a torn final line (the normal shape after a SIGKILL) or any unparseable line silently drops those turns' usage while still returning `ok=True`. The undercount is invisible in the run record, the ledger, and the trailer. Contrast `load_ledger` at `:650`, which *does* return its `bad` count, and `parse_session`, which keeps `rec["bad_lines"]` (`:503`) — so the omission is inconsistent within the same file. | **Reachable** — killed pi lanes are routine in this repo (`T774-op-a-r2` was killed at 12.3 s by the host guard). | **high** |
| S9 | `tools/runner:2222-2225` | `elif meta.get("is_error"):` / `    is_api_error = True` / `    out["missing_reason"] = (` / `        "claude api error (is_error=true, zero usage)")` | The reason **asserts** zero usage, but the branch is reached whenever `is_error` is true regardless of the parsed counts — `usage` may be fully populated (the `if` at `:2212` requires *both* conditions). Real consumed tokens are dropped to UNKNOWN under a reason that is false. This is precisely the "metrics ledger whose own reason for UNKNOWN readings was false" class. Compounding: `:2352-2357` `if usage is not None:` then writes `input/output/cache_read/cache_write/reasoning` into that same MISSING ledger row, so one record simultaneously says "no reading" (`tokens_in: null`) and carries component counts a different reader could sum. | **Reachable** — `parse_claude_envelope` sets `meta["is_error"]` (`:256`) independently of whether it parses a usage dict (`:268-291`); nothing forces them to agree. | **medium-high** |
| S10 | `tools/token-capture.py:544` | `if os.path.isdir(sessions_dir):` | No `else`. A wrong or absent slug directory yields zero sessions and **no error, no warning, no reason** — `scan_sessions` returns `scanned = len(sessions)` = 0 and the caller reports a clean result. `tools/token-backfill.py:370` then prints `"recoverable:  %d lane(s)" % len(appends)` → `0`, and `:379` `"sessions with no task attribution: %d"` → `0`. Reads as "nothing to recover"; means "I looked nowhere." Same shape as the 221-line register read as empty. | **Reachable now.** `tools/token-backfill.py:51-52` fixes `ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))` and `:352` `sessions_dir = args.sessions or tc.default_sessions_dir(ROOT)`, so the slug is derived from **the script's own checkout path**. Run from this worktree (`/private/tmp/weizigo/t774-frozen`) the slug is `--private-tmp-weizigo-t774-frozen--`, not the main checkout's — a directory that does not exist. | **high** |
| S11 | `tools/token-backfill.py:74` vs `tools/token-capture.py:655` | `return e.get("tokens_in") is not None and e.get("tokens_out") is not None` **vs** `return e.get("tokens_in") is not None or e.get("tokens_out") is not None` | Two definitions of "is this row a reading?" over the **same ledger file**, differing by `and`/`or`. A half-populated row (one side set, the other null) is a *reading* to the aggregator and a *MISSING* to the backfiller. Backfill's `have_reading` (`:151`) therefore does not protect it, `missing_by_task` (`:156-158`) claims it, and a retro row is appended for a lane the aggregator already counts → the model's total is **double-counted** across the two rows in `merge_models`. | **Reachable** — the predicates are independent code in two files with no shared constant; the runner can emit a one-sided row on any path where one of the two assignments is skipped. | **medium** |
| S12 | `tools/token-capture.py:690-695` | `for label, a in ledger_by_model.items():` … `    models[label] = a` | Replacement, not merge: if a label has **one** ledger reading and fifty scanned sessions, the whole session-scan aggregate for that label is discarded and the model reports the single ledger row. The docstring at `:659-661` states the intent ("the dispatch-time ledger wins for a label"), but the granularity is wrong — the ledger wins *per label*, not *per task*, so partial ledger coverage silently shrinks a model's measured cost. | **Reachable** — partial coverage is the normal state; `tools/token-backfill.py:10-11` records that the ledger misses 56 lanes and never mentions 334 tasks. | **medium** |
| S13 | `tools/token-capture.py:531-533` | `if rec["model_turns"]:` / `    rec["model"] = max(rec["model_turns"], key=lambda m: (rec["model_turns"][m], m))` | Dominant-model attribution: **all** tokens of a session are billed to the plurality model, ties broken lexicographically. A session that switched models bills the minority model's tokens to the majority model. `tools/token-backfill.py:187` `"model": tc.canon_tag(s.get("model") or "")` then writes that single label into the ledger, and `corroborate` (`:138-140`) only rejects it when a run record names a different model — `if rm and rm != entry["model"]`, so an empty `rm` grades as `"run-record"` corroborated with the model unchecked. | **Reachable** — pi session files at HEAD carry a `model_change` entry type (observed in all three sessions I read: `types {'session': 1, 'model_change': 1, …}`), so mid-session model change is a real shape of this format. | **medium** |
| S14 | `tools/runner:3251-3264` | `except Exception as exc:` … `_finalize_run_record(run_record, record_root, wall=elapsed, killed=f"runner exception: {exc}", …)` | The exception path finalizes with **no `tokens=` argument**, so `:586` `if tokens is not None:` is skipped and the record carries *no* `tokens_in`, no `tokens_missing_reason`, no `session_*` keys — and `_capture_tokens` is never called, so **no ledger line is appended at all**. The run happened, the streams were buffered, and the ledger's "never a blank cell" invariant (`tools/token-capture.py:194-197`) is broken by absence rather than by a null. Also no `cpu`/`rss_mb` are passed. One concrete trigger: `_descendant_pids_ps` (`:1057-1059`) runs `ps` with `timeout=2.0` and does **not** catch `TimeoutExpired`, so a momentarily loaded host aborts an otherwise healthy measured run. | **Reachable** — the walker is called every poll at `:2942` inside this `try`. | **medium** |
| S15 | `tools/runner:2183`, `:2347`, `:605` | `"session_path": None, "session_path_reason": None,` / `"session_path_reason": out["session_path_reason"],` / `run_record["session_path_reason"] = tokens.get("session_path_reason")` | Three occurrences, **no assignment anywhere** (verified: `grep -n 'session_path_reason' tools/runner tools/token-capture.py tools/token-backfill.py` returns exactly these three lines). The field is always `null`, yet `:600-605` documents it as "the path that was expected but missing … so a reader can … see that a path was named but the file never appeared." A reader checking that field for why a session path failed reads `null` and concludes nothing went wrong. | **Reachable — confirmed** in every live ledger row and run record: `"session_path_reason": null` appears even on `T774-op-a-r2`, whose capture failed. | **medium-low** |
| S16 | `tools/runner:511-523` | `max_num = max(numbered) if numbered else 0` … `archive = os.path.join(runs_dir, "%s.%d.json" % (ident, max_num + 1))` / `os.replace(bare, archive)` / `return max_num + 2` | Attempt numbering is inferred from **surviving filenames**, not from the record's own `attempt` field. Delete or archive-move one `<task>.<N>.json` and the next launch writes the bare record's contents into an already-used slot number: the file's name says attempt N while its `"attempt"` field says something else — an attempt mislabelled, and the earlier one overwritten. Independently: two runners launched with the same `--task-id` both compute the same `max_num`, both `os.replace` the bare path, and both then write `_run_record_path` (`:461`) — the second finalize silently overwrites the first run's wall/cpu/rss/tokens. | **Reachable** — no lock, no uniqueness check; the census at `:1950` iterates filenames, so a mislabelled slot is counted under the wrong attempt. | **medium** |
| S17 | `tools/runner:1752-1761` | `if transcript_dir and os.path.isdir(transcript_dir):` … `for name in names:` … `st = os.stat(p)` | The claude liveness sensor watches `~/.claude/projects/<cwd-slug>/`, which is **per-cwd, not per-lane**. Two concurrent claude lanes in the same checkout share it, so lane A's transcript writes reset lane B's fuse — a hung lane is held alive to its wall budget, inflating its measured wall (and its share of host pressure). The comment at `:1682-1684` explicitly rejects the shared repo tree as a sensor for exactly this reason ("other consoles write to the same checkout, so a neighbour's edit would mark a hung lane 'alive'") but does not apply the same reasoning to the shared transcript dir. This is the claude-side twin of the pi session-dir attribution problem the code guards against at `:2238-2242`. | **Reachable** — the race harness runs lanes concurrently from one checkout; `_claude_transcript_dir(os.getcwd())` at `:2844` takes no lane discriminator. | **medium** |
| S18 | `tools/token-backfill.py:314-315` | `d_out = (s.get("tokens_out") or 0) - (e.get("tokens_out") or 0)` / `d_in = (s.get("tokens_in") or 0) - (e.get("tokens_in") or 0)` | The tool's **own validation gate**. `or 0` coerces null to zero, so a pair of silent zeros (S3/S4) differences to 0 and is counted at `:316-319` as `exact_out += 1` — "reproduces exactly". `main` returns the gate's verdict directly (`:356` `return 0 if validate(...) else 1`). The control that is supposed to catch a zeroed reading scores zeros as perfect agreement. | **Reachable** — `_is_reading` (`:74`) admits `0` (it tests `is not None`), so zero-valued readings enter the comparison population. | **medium** |
| S19 | `tools/runner:1523` / `:1501` | `remaining = _drain_stream(proc.stdout, time.monotonic() + 2.0)` | A hard 2 s deadline (`_drain_stream:1474` `if time.monotonic() >= deadline: break`). A leaked pipe-holding grandchild — the documented T548 shape — truncates the buffered claude envelope. The token reading then fails **loudly** (`"no claude usage envelope in output"`), which is correct, but the truncated bytes are still forwarded verbatim as the lane's answer (`:3287-3291` → `_forward_claude_text`) and teed as the archival record. The captured deliverable is silently short while nothing in the record says so. | **Reachable** — `_drain_stdout` is on the normal-exit path at `:2881`. | **medium** |
| S20 | `tools/token-capture.py:645` | `if since and (e.get("ts") or "") < since:` | A ledger row with a missing or null `ts` becomes `""`, which sorts below any `since` value, so it is **silently dropped** from every date-filtered report. `append_ledger` does not require `ts`, and the retro path can write `"ts": s.get("start")` (`tools/token-backfill.py:205`) which is `None` when the session header lacked a timestamp (`parse_session:507` `rec["start"] = o.get("timestamp")`). Undated rows vanish rather than being reported as undated. | **Reachable** — only when `--since` is passed. | **low** |

---

## 3. Checked and found SAFE

Each of these looks dangerous on a skim; each is not, for the stated reason.

1. **`errors="replace"` on session files** — `tools/token-capture.py:357` `fh = open(path, errors="replace")` (and `:491`). Safe: U+FFFD substitution can only occur on invalid byte sequences, which live in *text* fields. All usage values are ASCII digits; a replacement character inside a JSON number would make the line fail `json.loads` and be counted as `bad`, not silently re-read as a different number. It cannot turn one valid count into another valid count.

2. **Summing per-turn `totalTokens` across turns** — `tools/token-capture.py:319` `"total": "totalTokens",`. The obvious fear is that `totalTokens` is a running context total, making the sum quadratic. **Verified false at HEAD**: on the 85-turn session `ds-a/r3`, `sum(totalTokens) = 2 979 802` and `sum(input)+sum(output)+sum(cacheRead)+sum(cacheWrite) = 2 979 802` — exact identity, so the field is per-turn. No double count. (Its *exclusion of `reasoning`* is a separate, real defect: S2.)

3. **summary/compaction usage double-counted with the assistant turn** — `tools/token-capture.py:379-384`. Safe: the two branches are `if t == "message" and … role == "assistant"` and `elif t in ("summary", "compaction")`, an `if/elif` on mutually exclusive values of the same `type` field. No entry can enter both. (I could not exercise the branch — no live session contained a `summary` or `compaction` entry; see residual Q3.)

4. **`_num` defaulting a missing claude key to 0** — `tools/token-capture.py:272-274` `v = usage_obj.get(k)` / `return v if isinstance(v, (int, float)) else 0`. Safe **as a per-key default**: the enclosing branch (`:269`) has already established that a `usage` object exists, so a single absent sub-key genuinely means that category was zero for the call. The dangerous case is the *whole object* being empty, which is S4 — a different site. Calling this line a defect would be the false positive.

5. **`_write_run_record` torn writes** — `tools/runner:540-543` `with open(tmp, "w") as f:` / `json.dump(...)` / `os.replace(tmp, path)`. Genuinely atomic on POSIX; a reader sees the complete old file or the complete new one. The `.tmp` scratch file also cannot pollute the census, because `recompute_harness_p95:1951` filters `if not fn.endswith(".json")` and the scratch name is `<task>.json.tmp`.

6. **A launch-only record read as a successful run** — `tools/runner:1970-1972` `if "exit" not in rec:` / `census["incomplete"].append(...)` / `continue`, plus the `wall is None` re-check at `:1976-1979`. Correctly refuses. **Confirmed against live data**: `untracked/runs/T774-op-a-r3.json` exists right now with `start`/`pid`/`command` and no `end`, `exit`, `wall`, `cpu`, `rss_mb`, or token keys — and it is excluded by both guards.

7. **A signal-killed record slipping through as completed** — `tools/runner:1851-1852` `return bool(rec.get("killed") or rec.get("signal") or (rec.get("killed_by") not in (None, "none", "")))`. Three independent markers, checked before the exit test. Confirmed on `T774-op-a-r2.json`, which carries `"killed_by": "rss"`, `"signal": 9`, and no `exit` — caught by all three.

8. **Attempt archiving losing an attempt** — `tools/runner:519` `os.replace(bare, archive)`. Safe as an operation: an atomic rename, never a copy, so the AC7 census cannot count one attempt twice or lose it to a partial copy. The *numbering* around it is S16; the rename itself is sound.

9. **Degraded (no-identity) mode as a source of zeros** — `tools/runner:2693` `record_root = repo_root if not identity_degraded else None`, with the loud stderr block at `:2672-2686`. Safe by the standing rule: a degraded run writes **no** run record and **no** ledger line (both `_write_run_record:534` and `append_ledger:198-199` early-return on a falsy root), and prints five explanatory lines including "no run record will be written". Absence, announced — not a zero. Heartbeats still land under `runner/<pid>`, which is the deliberate T370 visibility choice, not a leak.

10. **`--session=<path>` not matched by the flag-pair parser** — `tools/runner:1603-1605` `if a == "--session" and i + 1 < len(argv): return argv[i + 1]`. An `=`-joined form returns `None`, which routes to the explicit UNKNOWN block at `:2278-2291` with a five-line reason. Fails to UNKNOWN, never to 0. Correct by the standing rule.

11. **A pi lane dispatched without `--session`** — `tools/runner:2279-2284`, `out["missing_reason"] = ("no structured usage in process output (pi/ollama lane) … (UNKNOWN, never 0, never the total)")`. This is a correct explicit MISSING. Note only that `tools/token-backfill.py:6-7` already asserts this reason is factually false ("**That reason is false.**"); that is a known, dated, documented finding with a tool built for it, not a new one, so I am not re-charging it.

12. **Concurrent ledger appends interleaving** — `tools/token-capture.py:203-204` `with open(ledger_path(root), "a") as f:` / `f.write(json.dumps(entry, sort_keys=True) + "\n")`. Safe in practice: `"a"` is `O_APPEND`, and one buffered `write` of one complete line is flushed as a single syscall at close, so concurrent lanes interleave whole records, not fragments. Worth noting as a design property rather than a defect.

13. **Heartbeat sentinels becoming zeros** — `tools/runner:652-654` `"wall": round(wall, 1) if wall >= 0 else None,` followed by `:660` `record = {k: v for k, v in record.items() if v is not None}`. The `-1` sentinels passed at `:2936` and `:3254` become absent keys, not `0`. A reader sees "no cpu recorded", not "cpu was zero". Correct.

14. **`deepseek_rate_band` guessing a band** — `tools/token-capture.py:420-421` `except ValueError:` / `    return None`. Returns `None` on an unparseable timestamp, and the runner pairs it with `rate_band_reason` at `:2329-2330`. Never a guessed band. The Sunday-override arithmetic at `:426` also checks out against live data (`2026-08-23` is a Sunday, `wd == 6 and hour < 16` → `off-peak`, which is what the live rows say).

15. **`_load_token_capture` swallowing every import error** — `tools/runner:1548-1559`, `except Exception: return None`. Looks like a silent failure, but every downstream branch is explicitly gated on `tc is not None` and each writes a distinct reason (`:2294-2302` "tools/token-capture.py absent — no envelope parse, no ledger"). The half-updated-tree case even has its own reason at `:2255-2256`. Failing open here produces UNKNOWN-with-reason, not 0.

16. **`extract_task` mis-attributing a session from prose** — `tools/token-capture.py:461-466`. Safe by construction: only `untracked/T<id>` and `claim T<id>` match, and the docstring's rule ("A bare `T<id>` mention is NOT matched") is what the two regexes actually implement. A brief that merely *mentions* another task cannot steal its session.

---

## 4. Residual questions (each with the command that settles it)

**Q1 — Does pi's `output` already include `reasoning`, or are they disjoint?** This decides whether S2 is a 43% undercount of billed output or a correctly-excluded internal figure. Read-only inspection shows only that `totalTokens` excludes `reasoning`.
```
python3 - <<'EOF'
import json,glob
for p in glob.glob('/Users/alex/Project/Zig/weizigo/untracked/bakeoff/*/*/*/session.jsonl'):
    for line in open(p,errors='replace'):
        o=json.loads(line) if line.strip() else {}
        m=o.get('message') or {}
        u=m.get('usage')
        if u and u.get('reasoning'):
            print(p.split('/')[-3], {k:u[k] for k in ('output','reasoning','totalTokens','cost')}); break
EOF
```
Compare `cost` against `output` with and without `reasoning` at the published per-token rate; whichever reproduces `cost` is the answer.

**Q2 — Do ollama/qwen pi sessions use the same `cacheRead`/`cacheWrite`/`totalTokens` key names?** If not, S3 fires as a silent all-zero reading for the whole ollama family. `tools/token-capture.py:347-348` asserts they match but no ollama session exists in this tree.
```
ls ~/.pi/agent/sessions/*/ | head; python3 -c "
import json,glob,collections
k=collections.Counter()
for p in glob.glob('/Users/alex/.pi/agent/sessions/*/*.jsonl'):
    for line in open(p,errors='replace'):
        try: o=json.loads(line)
        except ValueError: continue
        m=o.get('message') or {}
        if m.get('role')=='assistant' and m.get('provider')=='ollama' and isinstance(m.get('usage'),dict):
            k.update(m['usage'].keys())
print(k)"
```

**Q3 — Do `summary` / `compaction` entries carry usage at the top level (where `tools/token-capture.py:382` reads it) or nested under `message`?** None of the three live sessions contained either type, so the branch is unexercised. If the usage is nested, every compacted long session silently loses its compaction tokens while still returning `ok=True`.
```
grep -h -o '"type":"[a-z_]*"' ~/.pi/agent/sessions/*/*.jsonl | sort | uniq -c | sort -rn
python3 -c "
import json,glob
for p in glob.glob('/Users/alex/.pi/agent/sessions/*/*.jsonl'):
    for line in open(p,errors='replace'):
        try: o=json.loads(line)
        except ValueError: continue
        if o.get('type') in ('summary','compaction'):
            print(p, o.get('type'), 'top-level usage:', isinstance(o.get('usage'),dict),
                  'nested usage:', isinstance((o.get('message') or {}).get('usage'),dict)); break"
```

**Q4 — Does `ps -o time=` on this host report the process's own CPU only, or does it include reaped children's (`cutime`)?** This decides whether S6's per-pid summation is merely incomplete (own-CPU only, short children lost) or also **double-counts** (a parent that already absorbed a reaped child's CPU, summed again with a still-live sibling's).
```
python3 -c "
import subprocess,os,time
p=subprocess.Popen(['sh','-c','python3 -c \"x=0\nfor i in range(40000000): x+=i\"; sleep 3'])
time.sleep(4)
print('parent sh TIME after child burned CPU and was reaped:',
      subprocess.run(['ps','-o','time=','-p',str(p.pid)],capture_output=True,text=True).stdout.strip())
p.wait()"
```
If the parent's TIME stays near zero, `ps` reports own-CPU only and S6 is an undercount with no double count.

**Q5 — Does a real `claude -p --output-format json` failure envelope carry `is_error: true` together with non-zero usage?** This decides whether S9's false reason is theoretical or routine. Requires one live capture (out of scope for a read-only row); the archived tees are the read-only proxy:
```
grep -l '"is_error":true' untracked/tokens/*.stdout.log 2>/dev/null | while read f; do
  python3 -c "import json,sys; o=json.loads(open('$f').read().strip().splitlines()[-1]); print('$f', o.get('is_error'), o.get('usage'))"; done
```

**Q6 — How many rows in the live ledger already exhibit S1 (a `total` that will aggregate to 0) and S11 (a one-sided reading)?** Settles the blast radius without running either instrument's write path:
```
python3 -c "
import json
n=t=one=0
for line in open('untracked/tokens/tokens.jsonl'):
    e=json.loads(line); n+=1
    if 'total' not in e: t+=1
    a,b=e.get('tokens_in'),e.get('tokens_out')
    if (a is None) != (b is None): one+=1
print('rows',n,'| no total key',t,'| one-sided readings',one)"
```

**Q7 — Would the current human report actually print `total 0`?** S1 is established by reading the aggregation code plus the live row shapes, but the rendered output would confirm it end-to-end. `--json` and the default renderer are read-only with respect to the ledger (`main` calls only `scan_sessions`/`load_ledger`), but running the instrument is outside this row's mandate:
```
tools/token-capture.py --model deepseek-v4-flash
```
