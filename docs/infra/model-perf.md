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
dispatch-verify 2026-08-22 T544 deepseek-v4-pro report=incomplete verified=fail fail=row killed_by=directive
dispatch-verify 2026-08-22 T524 deepseek-v4-flash report=success verified=pass
dispatch-verify 2026-08-22 T579 claude-opus-5 report=success verified=pass
dispatch-verify 2026-08-22 T548 deepseek-v4-flash report=success verified=pass
dispatch-verify 2026-08-22 T530 deepseek-v4-pro report=incomplete verified=fail fail=row
dispatch-verify 2026-08-22 T582 deepseek-v4-pro report=success verified=pass
dispatch-verify 2026-08-22 T581 deepseek-v4-pro report=success verified=pass
dispatch-verify 2026-08-22 T580 claude-sonnet-5 report=success verified=pass
dispatch-verify 2026-08-22 T544 deepseek-v4-flash report=incomplete verified=fail fail=row killed_by=directive
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
dispatch-verify 2026-08-22 T601 deepseek-v4-flash report=success verified=pass killed_by=none
dispatch-verify 2026-08-22 T599 deepseek-v4-pro report=incomplete verified=fail fail=row
dispatch-verify 2026-08-22 T587 deepseek-v4-pro report=success verified=pass
dispatch-verify 2026-08-22 T614 claude-fable-5 report=success verified=pass
dispatch-verify 2026-08-22 T618 claude-haiku-4-5-20251001 report=success verified=pass
dispatch-verify 2026-08-22 T599 deepseek-v4-pro report=success verified=pass
dispatch-verify 2026-08-22 T620 claude-haiku-4-5-20251001 report=success verified=pass
dispatch-verify 2026-08-22 T615 claude-fable-5 report=incomplete verified=fail fail=row killed_by=provider-limit
dispatch-verify 2026-08-22 T617 claude-sonnet-5 report=incomplete verified=fail fail=row killed_by=provider-limit
dispatch-verify 2026-08-22 T616 claude-opus-5 report=incomplete verified=fail fail=row killed_by=provider-limit
dispatch-verify 2026-08-22 T624 deepseek-v4-flash report=success verified=pass
dispatch-verify 2026-08-22 T622 claude-opus-5 report=incomplete verified=fail fail=row killed_by=provider-limit
dispatch-verify 2026-08-22 T621 claude-sonnet-5 report=incomplete verified=fail fail=row killed_by=provider-limit
dispatch-verify 2026-08-22 T619 deepseek-v4-flash report=success verified=pass
dispatch-verify 2026-08-22 T623 deepseek-v4-pro report=success verified=pass
dispatch-verify 2026-08-22 T526 deepseek-v4-flash report=incomplete verified=fail fail=row killed_by=watchdog
dispatch-verify 2026-08-22 T615 claude-fable-5 report=success verified=pass
dispatch-verify 2026-08-22 T616 claude-opus-5 report=incomplete verified=fail fail=row killed_by=provider-limit
dispatch-verify 2026-08-22 T544 deepseek-v4-pro report=success verified=pass
dispatch-verify 2026-08-22 T625 deepseek-v4-flash report=success verified=pass
dispatch-verify 2026-08-22 T526 deepseek-v4-pro report=success verified=pass
dispatch-verify 2026-08-22 T632 deepseek-v4-flash report=success verified=pass
dispatch-verify 2026-08-22 T634 deepseek-v4-pro report=success verified=pass
dispatch-verify 2026-08-22 T631 deepseek-v4-flash report=success verified=pass
dispatch-verify 2026-08-22 T621 claude-sonnet-5 report=success verified=pass
dispatch-verify 2026-08-22 T622 claude-opus-5 report=success verified=pass
dispatch-verify 2026-08-22 T642 claude-haiku-4-5-20251001 report=success verified=pass
