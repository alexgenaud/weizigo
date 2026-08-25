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
dispatch-verify 2026-08-22 T641 claude-sonnet-5 report=incomplete verified=fail fail=row
dispatch-verify 2026-08-22 T639 deepseek-v4-pro report=success verified=pass
dispatch-verify 2026-08-22 T629 deepseek-v4-flash report=success verified=pass
dispatch-verify 2026-08-22 T637 deepseek-v4-flash report=success verified=pass
dispatch-verify 2026-08-22 T635 deepseek-v4-pro report=incomplete verified=fail fail=row killed_by=watchdog
dispatch-verify 2026-08-22 T638 deepseek-v4-flash report=incomplete verified=fail fail=row killed_by=watchdog
dispatch-verify 2026-08-22 T640 claude-opus-5 report=success verified=pass
dispatch-verify 2026-08-22 T646 claude-haiku-4-5-20251001 report=success verified=fail fail=nonce killed_by=none
dispatch-verify 2026-08-22 T635 deepseek-v4-pro report=success verified=pass killed_by=none
dispatch-verify 2026-08-22 T647 deepseek-v4-pro report=success verified=pass killed_by=none
dispatch-verify 2026-08-22 T648 deepseek-v4-flash report=success verified=pass killed_by=none
dispatch-verify 2026-08-22 T645 claude-sonnet-5 report=success verified=pass killed_by=none
dispatch-verify 2026-08-22 T644 claude-opus-5 report=success verified=pass killed_by=none
dispatch-verify 2026-08-22 T643 deepseek-v4-pro report=incomplete verified=directive-kill reason=unknown/pause/kill killed_by=watchdog
dispatch-verify 2026-08-22 T656 claude-haiku-4-5-20251001 report=success verified=pass killed_by=none
dispatch-verify 2026-08-22 T652 deepseek-v4-flash report=success verified=pass killed_by=none
dispatch-verify 2026-08-22 T658 deepseek-v4-flash report=success verified=pass killed_by=none
dispatch-verify 2026-08-22 T655 claude-sonnet-5 report=success verified=pass killed_by=none
dispatch-verify 2026-08-22 T649 claude-fable-5 report=success verified=pass killed_by=none
dispatch-verify 2026-08-22 T657 deepseek-v4-pro report=success verified=pass killed_by=none
dispatch-verify 2026-08-22 T654 claude-opus-5 report=incomplete verified=unreached reason=provider-429 killed_by=provider-limit
dispatch-verify 2026-08-22 T651 deepseek-v4-pro report=success verified=pass killed_by=none
dispatch-verify 2026-08-22 T650 deepseek-v4-flash report=success verified=pass killed_by=none
dispatch-verify 2026-08-24 T836 claude-opus-5 report=unknown verified=unreached reason=provider-429 killed_by=provider-limit
dispatch-verify 2026-08-24 T822 deepseek-v4-flash report=success verified=pass killed_by=none
dispatch-verify 2026-08-24 T834 deepseek-v4-pro report=success verified=pass killed_by=none
dispatch-verify 2026-08-24 T839 deepseek-v4-flash report=success verified=pass killed_by=none
dispatch-verify 2026-08-24 T842 minimax-m3 report=incomplete verified=unreached reason=provider-429 killed_by=provider-limit
dispatch-verify 2026-08-24 T841 kimi-k2.7 report=incomplete verified=unreached reason=provider-429 killed_by=provider-limit
dispatch-verify 2026-08-24 T840 glm-5.2 report=incomplete verified=unreached reason=provider-429 killed_by=provider-limit
dispatch-verify 2026-08-24 T838 deepseek-v4-pro report=success verified=pass killed_by=none
dispatch-verify 2026-08-24 T846 deepseek-v4-pro report=success verified=pass killed_by=none
dispatch-verify 2026-08-24 T845 deepseek-v4-flash report=success verified=pass killed_by=none
dispatch-verify 2026-08-24 T847 deepseek-v4-pro report=success verified=pass killed_by=none
dispatch-verify 2026-08-24 T848 oxalpha report=incomplete verified=fail fail=row killed_by=none
dispatch-verify 2026-08-24 T848 oxalpha report=incomplete verified=fail fail=row killed_by=none
dispatch-verify 2026-08-24 T849 oxalpha report=incomplete verified=fail fail=row killed_by=none
dispatch-verify 2026-08-24 T850 claude-sonnet-5 report=success verified=pass killed_by=none
dispatch-verify 2026-08-24 T848 deepseek-v4-pro report=success verified=pass killed_by=none
dispatch-verify 2026-08-24 T836 deepseek-v4-pro report=success verified=pass killed_by=none
dispatch-verify 2026-08-24 T849 glm-5.2 report=success verified=pass killed_by=none
dispatch-verify 2026-08-24 T832 glm-5.2 report=success verified=pass killed_by=none
dispatch-verify 2026-08-24 T819 kimi-k2.7 report=success verified=pass killed_by=none
dispatch-verify 2026-08-24 T843 claude-sonnet-5 report=success verified=pass killed_by=none
dispatch-verify 2026-08-24 T852 glm-5.2 report=success verified=pass killed_by=none
dispatch-verify 2026-08-24 T844 claude-haiku-4-5-20251001 report=success verified=pass killed_by=none
dispatch-verify 2026-08-24 T851 deepseek-v4-pro report=success verified=pass killed_by=none
dispatch-verify 2026-08-24 T853 claude-sonnet-5 report=success verified=pass killed_by=none
dispatch-verify 2026-08-24 T854 deepseek-v4-pro report=success verified=pass killed_by=none
dispatch-verify 2026-08-24 T855 claude-sonnet-5 report=success verified=pass killed_by=none
dispatch-verify 2026-08-24 T856 deepseek-v4-flash report=success verified=pass killed_by=none
dispatch-verify 2026-08-24 T857 oxalpha report=success verified=pass killed_by=none
dispatch-verify 2026-08-24 T858 deepseek-v4-pro report=success verified=pass killed_by=none
dispatch-verify 2026-08-24 T859 deepseek-v4-pro report=success verified=pass killed_by=none
dispatch-verify 2026-08-24 T860 oxalpha report=incomplete verified=fail fail=nonce killed_by=none
dispatch-verify 2026-08-24 T861 claude-sonnet-5 report=incomplete verified=fail fail=row killed_by=none
dispatch-verify 2026-08-24 T862 glm-5.2 report=success verified=pass killed_by=none
dispatch-verify 2026-08-24 T864 deepseek-v4-flash report=success verified=pass killed_by=none
dispatch-verify 2026-08-24 T865 deepseek-v4-flash report=success verified=pass killed_by=none
dispatch-verify 2026-08-24 T866 glm-5.2 report=success verified=pass killed_by=none
dispatch-verify 2026-08-24 T868 kimi-k2.7 report=success verified=pass killed_by=none
dispatch-verify 2026-08-24 T869 claude-sonnet-5 report=incomplete verified=fail fail=row killed_by=none
dispatch-verify 2026-08-24 T867 deepseek-v4-flash report=success verified=pass killed_by=none
dispatch-verify 2026-08-24 T861 deepseek-v4-pro report=success verified=pass killed_by=none
dispatch-verify 2026-08-24 T870 claude-opus-5 report=success verified=pass killed_by=none
dispatch-verify 2026-08-24 T884 kimi-k2.7 report=incomplete verified=fail fail=row killed_by=none
dispatch-verify 2026-08-24 T884 kimi-k2.7 report=incomplete verified=fail fail=row killed_by=none
dispatch-verify 2026-08-24 T883 glm-5.2 report=success verified=pass killed_by=none
dispatch-verify 2026-08-24 T884 kimi-k2.7 report=success verified=pass killed_by=none
dispatch-verify 2026-08-24 T885 minimax-m3 report=success verified=fail fail=nonce killed_by=none
dispatch-verify 2026-08-24 T882 deepseek-v4-pro report=success verified=pass killed_by=none
dispatch-verify 2026-08-24 T881 claude-opus-5 report=success verified=pass killed_by=none
dispatch-verify 2026-08-24 T886 oxalpha report=success verified=pass killed_by=none
dispatch-verify 2026-08-24 T872 deepseek-v4-pro report=incomplete verified=fail fail=row killed_by=none
dispatch-verify 2026-08-24 T888 claude-haiku-4-5-20251001 report=success verified=fail fail=nonce killed_by=none
dispatch-verify 2026-08-24 T889 deepseek-v4-flash report=success verified=pass killed_by=none
dispatch-verify 2026-08-24 - kimi-k2.7 report=bare verified=pass killed_by=none
dispatch-verify 2026-08-24 T887 claude-sonnet-5 report=incomplete verified=fail fail=row killed_by=rss
dispatch-verify 2026-08-24 T880 deepseek-v4-flash report=success verified=pass killed_by=none
dispatch-verify 2026-08-24 T897 claude-sonnet-5 report=success verified=pass killed_by=none
dispatch-verify 2026-08-24 T893 claude-fable-5 report=success verified=pass killed_by=none
dispatch-verify 2026-08-24 T896 deepseek-v4-flash report=success verified=pass killed_by=none
dispatch-verify 2026-08-24 T872 deepseek-v4-pro report=success verified=pass killed_by=none
dispatch-verify 2026-08-24 T890 glm-5.2 report=success verified=pass killed_by=none
dispatch-verify 2026-08-24 T750 minimax-m3 report=success verified=fail fail=nonce killed_by=none
dispatch-verify 2026-08-24 T899 deepseek-v4-pro report=success verified=pass killed_by=none
dispatch-verify 2026-08-24 T900 claude-fable-5 report=success verified=pass killed_by=none
dispatch-verify 2026-08-24 T898 claude-sonnet-5 report=success verified=pass killed_by=none
dispatch-verify 2026-08-24 T895 claude-opus-5 report=success verified=pass killed_by=none
dispatch-verify 2026-08-24 T891 glm-5.2 report=success verified=pass killed_by=none
dispatch-verify 2026-08-24 T901 deepseek-v4-pro report=success verified=pass killed_by=none
dispatch-verify 2026-08-24 T902 claude-opus-5 report=incomplete verified=unreached reason=provider-429 killed_by=provider-limit
dispatch-verify 2026-08-24 T863 claude-sonnet-5 report=incomplete verified=unreached reason=provider-429 killed_by=provider-limit
dispatch-verify 2026-08-24 T903 deepseek-v4-pro report=success verified=pass killed_by=none
dispatch-verify 2026-08-24 T905 glm-5.2 report=success verified=pass killed_by=none
dispatch-verify 2026-08-24 T904 oxalpha report=success verified=pass killed_by=none
dispatch-verify 2026-08-24 T786 deepseek-v4-flash report=success verified=fail fail=exit killed_by=none
dispatch-verify 2026-08-25 T908 minimax-m3 report=incomplete verified=unreached reason=provider-429 killed_by=provider-limit
dispatch-verify 2026-08-25 T751 glm-5.2 report=incomplete verified=unreached reason=provider-429 killed_by=provider-limit
dispatch-verify 2026-08-25 T863 claude-sonnet-5 report=failure-blocked verified=pass killed_by=none
dispatch-verify 2026-08-25 T907 claude-fable-5 report=failure-blocked verified=pass killed_by=none
dispatch-verify 2026-08-25 T764 minimax-m3 report=incomplete verified=unreached reason=provider-429 killed_by=provider-limit
dispatch-verify 2026-08-25 T902 claude-opus-5 report=incomplete verified=fail fail=row killed_by=rss
dispatch-verify 2026-08-25 T764 minimax-m3 report=incomplete verified=unreached reason=provider-429 killed_by=provider-limit
dispatch-verify 2026-08-25 T912 claude-opus-5 report=incomplete verified=fail fail=row killed_by=rss
dispatch-verify 2026-08-25 T912 claude-opus-5 report=incomplete verified=fail fail=row killed_by=rss
dispatch-verify 2026-08-25 T764 deepseek-v4-pro report=success verified=pass killed_by=none
dispatch-verify 2026-08-25 T906 deepseek-v4-flash report=success verified=pass killed_by=none
dispatch-verify 2026-08-25 T912 claude-opus-5 report=incomplete verified=fail fail=row killed_by=rss
dispatch-verify 2026-08-25 T796 kimi-k2.7 report=success verified=pass killed_by=none
dispatch-verify 2026-08-25 T751 minimax-m3 report=success verified=pass killed_by=none
dispatch-verify 2026-08-25 T912 claude-opus-5 report=success verified=pass killed_by=none
dispatch-verify 2026-08-25 T910 deepseek-v4-pro report=success verified=pass killed_by=none
dispatch-verify 2026-08-25 T825 minimax-m3 report=success verified=pass killed_by=none
dispatch-verify 2026-08-25 T913 deepseek-v4-flash report=success verified=pass killed_by=none
dispatch-verify 2026-08-25 T908 glm-5.2 report=success verified=pass killed_by=none
dispatch-verify 2026-08-25 T924 oxalpha report=incomplete verified=fail fail=row killed_by=none
dispatch-verify 2026-08-25 T929 deepseek-v4-flash report=success verified=pass killed_by=none
dispatch-verify 2026-08-25 T930 deepseek-v4-pro report=success verified=pass killed_by=none
dispatch-verify 2026-08-25 T926 oxalpha report=incomplete verified=fail fail=row killed_by=none
dispatch-verify 2026-08-25 T927 glm-5.2 report=success verified=pass killed_by=none
dispatch-verify 2026-08-25 T894 claude-sonnet-5 report=incomplete verified=fail fail=row killed_by=none
dispatch-verify 2026-08-25 T932 deepseek-v4-pro report=success verified=pass killed_by=none
dispatch-verify 2026-08-25 T926 minimax-m3 report=success verified=fail fail=nonce killed_by=none
dispatch-verify 2026-08-25 T938 claude-haiku-4-5-20251001 report=success verified=pass killed_by=none
dispatch-verify 2026-08-25 T940 gemini-3.7-flash report=success verified=pass killed_by=none
dispatch-verify 2026-08-25 T916 oxalpha report=success verified=pass killed_by=none
dispatch-verify 2026-08-25 T917 deepseek-v4-flash report=success verified=pass killed_by=none
dispatch-verify 2026-08-25 T918 deepseek-v4-pro report=success verified=pass killed_by=none
dispatch-verify 2026-08-25 T919 kimi-k2.7 report=success verified=pass killed_by=none
dispatch-verify 2026-08-25 T943 gemini-3.7-flash report=success verified=pass killed_by=none
dispatch-verify 2026-08-25 T920 claude-sonnet-5 report=success verified=pass killed_by=none
