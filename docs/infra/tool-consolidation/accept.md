# T428 · Tool Consolidation — Acceptance ruling

**Ruling: SHIPPED.** The claimlint+absorb and subagent+ollama-subagent consolidations
designed by this sprint are implemented and accepted. This file is the sprint's acceptance
gate artifact (`acceptance=test -s docs/infra/tool-consolidation/accept.md` in the T428
bundle meta).

| | |
|---|---|
| Sprint | T428 (tool consolidation), set S |
| Executed by | T437 (build), T440 (hardening), T482 (c7 extension), T527 (acceptance execution, Phase B, final fixes) |
| Acceptance date | 2026-08-23 |
| Acceptance suite | `03-acceptance.md` — 22 tests; results in `07-test.md` |

## What is accepted

1. **`weizigo-claimlint` is one binary with verbs** — `verify` (default, backward
   compatible), `absorb <findings.json> [--dry-run]`, `c7 [--json]`. `weizigo-absorb` no
   longer exists as a binary or entry point; its function is the `absorb` verb.
2. **One register parser** — `claims_register.zig` is the single Zig parser; claimlint's
   inline copy is retired. Both verbs call `cr.parseRegister()`, making the T406
   two-verdicts-same-file shape structurally impossible.
3. **`bin/subagent` is one script with REQUIRED `--provider`** —
   `--provider deepseek|ollama|claude`; missing or unknown provider is a hard error.
   `bin/ollama-subagent` and `bin/subagent-ds` are removed.
4. **Cutover wrappers** (`bin/weizigo-absorb`, `bin/ollama-subagent`, `bin/subagent-ds`)
   were deployed, verified working (T440), then removed in Phase B — nothing replaced
   without the old entry point working first.

## Acceptance evidence (summary)

- **22/22 tests pass** after three HEAD-gap fixes by T527 (see below); every RED-first
  control was shown RED before its fix (`07-test.md` §3).
- **Byte-identity:** merged `verify` and `absorb` produce byte-identical output/side effects
  to the pre-merge tools after version normalization (C1.2, C1.3).
- **Union of suites:** 9 consolidated-tool regression scripts ≥ 8 pre-merge scripts (A0);
  all nine green at HEAD.
- **No silent success:** a 0-row register makes both verbs fail hard with a message naming
  the empty parse (C1.9).
- **Live-store safe:** the suite's internal live-store guards all passed (C3.3).

## Fixes T527 had to make before acceptance

These were acceptance failures found at HEAD during the Phase 7 run — all fixed test-first
(control RED first), then re-run GREEN:

| gap | test | fix |
|---|---|---|
| `verify --help` / `absorb --help` did not print usage | C1.1 acceptance half (NF4) | verb dispatch prints help + exit 0 when a help flag follows a known verb |
| `verify` on a 0-row register did not name the empty parse on stderr | C1.9 | runVerify fails hard (exit 3) mirroring absorb's T406 block |
| subagent file-branch prompt over-escaped to literal `\n` by the merge | C2.2/C2.3 | restored pre-merge real newlines + repr condition |
| claimlint-promotion regression pointed at pre-T557 kill-matrix path | C1.4 | path re-pointed to `docs/epics/E1-markovian/…` |

## Known non-blocking debt (separate repair rows)

Six pre-existing fleet-suite reds, verified at clean HEAD, none touching the consolidated
toolchain — see `07-test.md` §5 and `findings/T527-t428-console.json` (argus stale hardcoded
floor, deploy-staleness arms, managent `cmdAgent` segfault on model-less rows, store-pollution
clean-lane arm, directive-kill T616 misclassification, race-p0 path drift, runner-host-guard
expected-red until T711).

## Signature

Prepared by deepseek-v4-flash/T527 (acceptance execution) on 2026-08-23, on top of the
T428.2 phase documents and the T437/T440/T482 implementation. Findings:
`findings/T527-t428-console.json`; full test evidence: `docs/infra/tool-consolidation/07-test.md`.
