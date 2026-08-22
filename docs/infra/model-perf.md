# Model-performance — pointer (the full log is archived)

**Status: thin pointer.** On 2026-08-21 (T565) the ~4,150-line prose impression log that
lived here was restructured per `measurement-methodology.md` §8:

- **The full historical log** (belief-audit Class A/B/C, dated anecdotes, Boss-era notes,
  tenure scorecards, the 2026-08-21 impressions section) → **`docs/infra/archive/model-perf-2026-08-21.md`**,
  stamped *"impressions, not measurements; not evidence of ranking"*. Historical line-number
  citations into the old file resolve there with **+9 lines**.
- **Canonical facts** (context windows, label normalization, serving-tag/epoch rules, short-name
  table, model versions) → **`docs/infra/model-registry.md`**.
- **Structured measured cells** (T447 blind scores, T371, T451–T453, T369, T443, T444, re-keyed
  onto the 8 operator types) → **`docs/infra/model-task-metrics.jsonl`**.
- **Dispatch policy + task types** (the 8 operator types, measured-cells matrix, qwen scope,
  the local-model rule) → **`docs/infra/model-task-matrix.md`** (unchanged by this restructure
  except the retired 2026-08-18 cost stance).
- **Appetite / budget authority** → `measurement-methodology.md` §1 (the appetite table).

The old path is kept live so existing citations do not dangle (claimlint C2). New observations
go to the JSONL (measured) or the archive append (impressions), not here.

- **pass-2 spec audit (4 lanes, 2026-08-21):** opus **great** (11 findings incl. all four musts, every citation verified + live repro of B-9/B-10 reds); flash **good** (6 — HOLD-6/C7 scoping, the `\bpi\b` gate, the missing golden-master arm); sonnet **good** (2 sharp provenance findings — F7 misapplied, sentinel gap); haiku **average** (3 — the launch-template-table blocker). Strongly convergent; the audit process worked.
- **race1 (T447 read-only-audit replication, graded by flash, n=1 provisional):** opus 46 > sonnet 26 > haiku 0 (haiku false-negative "no escape paths"). No tier emitted (n=1, per methodology §5). Matrix-cell fold deferred to after T565.
dispatch-verify 2026-08-22 T574 deepseek-v4-flash report=success verified=pass
dispatch-verify 2026-08-22 T575 deepseek-v4-flash report=success verified=pass
dispatch-verify 2026-08-22 T572 deepseek-v4-flash report=success verified=pass
dispatch-verify 2026-08-22 T571 claude-opus-5 report=success verified=pass
dispatch-verify 2026-08-22 T577 deepseek-v4-pro report=success verified=pass
dispatch-verify 2026-08-22 T573 deepseek-v4-pro report=success verified=fail fail=exit
dispatch-verify 2026-08-22 T576 claude-opus-5 report=success verified=pass
dispatch-verify 2026-08-22 T544 deepseek-v4-pro report=incomplete verified=fail fail=row
dispatch-verify 2026-08-22 T524 deepseek-v4-flash report=success verified=pass
dispatch-verify 2026-08-22 T579 claude-opus-5 report=success verified=pass
dispatch-verify 2026-08-22 T548 deepseek-v4-flash report=success verified=pass
dispatch-verify 2026-08-22 T530 deepseek-v4-pro report=incomplete verified=fail fail=row
dispatch-verify 2026-08-22 T582 deepseek-v4-pro report=success verified=pass
dispatch-verify 2026-08-22 T581 deepseek-v4-pro report=success verified=pass
dispatch-verify 2026-08-22 T580 claude-sonnet-5 report=success verified=pass
dispatch-verify 2026-08-22 T544 deepseek-v4-flash report=incomplete verified=fail fail=row
dispatch-verify 2026-08-22 T585 claude-sonnet-5 report=success verified=pass
dispatch-verify 2026-08-22 T584 claude-opus-5 report=success verified=pass
dispatch-verify 2026-08-22 T522 deepseek-v4-pro report=success verified=pass
dispatch-verify 2026-08-22 T589 claude-haiku-4-5-20251001 report=success verified=pass
dispatch-verify 2026-08-22 T588 claude-sonnet-5 report=success verified=pass
dispatch-verify 2026-08-22 T530 deepseek-v4-flash report=incomplete verified=fail fail=row
dispatch-verify 2026-08-22 T586 deepseek-v4-pro report=success verified=pass
dispatch-verify 2026-08-22 T590 deepseek-v4-flash report=success verified=pass
dispatch-verify 2026-08-22 T598 claude-haiku-4-5-20251001 report=success verified=pass
dispatch-verify 2026-08-22 T605 claude-sonnet-5 report=success verified=pass
dispatch-verify 2026-08-22 T600 deepseek-v4-pro report=success verified=pass
dispatch-verify 2026-08-22 T602 deepseek-v4-flash report=success verified=pass
dispatch-verify 2026-08-22 T604 claude-opus-5 report=incomplete verified=fail fail=row
dispatch-verify 2026-08-22 T603 claude-opus-5 report=incomplete verified=fail fail=row
dispatch-verify 2026-08-22 T606 claude-sonnet-5 report=success verified=fail fail=exit
dispatch-verify 2026-08-22 T591 deepseek-v4-flash report=incomplete verified=fail fail=row
dispatch-verify 2026-08-22 T607 claude-haiku-4-5-20251001 report=incomplete verified=fail fail=row
dispatch-verify 2026-08-22 T601 deepseek-v4-flash report=incomplete verified=unreached reason=provider-429
dispatch-verify 2026-08-22 T599 deepseek-v4-pro report=incomplete verified=fail fail=row
dispatch-verify 2026-08-22 T587 deepseek-v4-pro report=success verified=pass
dispatch-verify 2026-08-22 T614 claude-fable-5 report=success verified=pass
dispatch-verify 2026-08-22 T618 claude-haiku-4-5-20251001 report=success verified=pass
dispatch-verify 2026-08-22 T599 deepseek-v4-pro report=success verified=pass
dispatch-verify 2026-08-22 T620 claude-haiku-4-5-20251001 report=success verified=pass
dispatch-verify 2026-08-22 T615 claude-fable-5 report=incomplete verified=fail fail=row
dispatch-verify 2026-08-22 T617 claude-sonnet-5 report=incomplete verified=fail fail=row
dispatch-verify 2026-08-22 T616 claude-opus-5 report=incomplete verified=fail fail=row
dispatch-verify 2026-08-22 T624 deepseek-v4-flash report=success verified=pass
dispatch-verify 2026-08-22 T622 claude-opus-5 report=incomplete verified=fail fail=row
dispatch-verify 2026-08-22 T621 claude-sonnet-5 report=incomplete verified=fail fail=row
dispatch-verify 2026-08-22 T619 deepseek-v4-flash report=success verified=pass
dispatch-verify 2026-08-22 T623 deepseek-v4-pro report=success verified=pass
dispatch-verify 2026-08-22 T526 deepseek-v4-flash report=incomplete verified=unreached reason=provider-429

### DO NOT SCORE — 2026-08-22 12:47Z, Claude session-limit outage (T612 seat annotation)

Seven Claude lanes were live when the account's five-hour session limit was reached. Five were
terminated mid-turn by the provider and are recorded above as **model failures. They are not.**
The models did nothing wrong and were given no chance to react; the record blames them for a
stop the provider chose.

| ledger line | model | wall at kill | what actually happened |
|---|---|---|---|
| `T615 … verified=fail fail=row` | `claude-fable-5` | 542.3 s | provider session limit |
| `T616 … verified=fail fail=row` | `claude-opus-5` | 549.9 s | provider session limit |
| `T617 … verified=fail fail=row` | `claude-sonnet-5` | 540.4 s | provider session limit |
| `T621 … verified=fail fail=row` | `claude-sonnet-5` | 360.1 s | provider session limit |
| `T622 … verified=fail fail=row` | `claude-opus-5` | 358.1 s | provider session limit |

Every one of the five logs ends with the same line, and it is unambiguous:

    You've hit your session limit · resets 3pm (Europe/Oslo)
    [runner] tokens: no reading — claude api error (is_error=true, zero usage)
    [runner] exit 1 in 542.3 s

`tools/dispatch_verify.py` has had a provider-refusal classifier since T538, and it did not fire
— its signature list carries `session usage limit` and `reached your (session )?usage limit`,
and the string Claude actually emits is `hit your session limit`. It misses by one word.

**Two lines above are wrong in the opposite direction** and are also DO NOT SCORE:

| ledger line | recorded | what actually happened |
|---|---|---|
| `T526 … verified=unreached reason=provider-429` | provider refusal | killed by the runner's own progress-timeout watchdog at 600 s (`untracked/runs/T526.json`: `killed: progress timeout 600s`, `signal 9`, cpu 1033 s). The classifier matched a **historical Ollama 429 the worker was quoting out of a document** — `Error: 429 Too Many Requests … reached your session usage limit`, dated 2026-08-20. |
| `T601 … verified=unreached reason=provider-429` | provider refusal | ran fine and delivered `findings/T601-race-b.json`. The classifier matched the word **`quota`** inside the prose "provider quota/appetite 7". |

So the instrument fails in both directions, and which direction it fails in is decided by
whether a worker happened to quote a limit message. A real outage scores against the model; a
real harness kill scores against the provider. Both corrupt the ladder, and the second one is
exactly the laundering D048 warned against on 2026-08-20.

Registered against **T625**, which already holds `tools/dispatch_verify.py`.
