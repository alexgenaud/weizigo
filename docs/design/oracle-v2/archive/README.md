# oracle-v2 — archived ephemera

Historical records only. **Nothing in this directory is carried forward** —
the canonical phase documents are `docs/infra/oracle-v2/pass0/spec.md` and
`docs/infra/oracle-v2/pass0/strategy.md`; the M1 design under revision is
`docs/design/oracle-v2/design-M1.md`. Line references inside these audits
resolve against the snapshots at commit `56950a1`, not against the live docs.

| file | was | verdict |
|---|---|---|
| `spec.audit-1.md` | pass-0 spec audit (auditor unrecorded) | NEEDS-FIX — F1 blocker + F2–F6 must |
| `spec.audit-2.md` | pass-1 spec audit (DSPro/T135) | PASS → G1 ratified |
| `strategy.audit-1.md` | strategy audit (DSPro/T132) | NEEDS-FIX — F1/F2 must, resolved in strategy rev 1 |
| `design-M1.audit-1.md` | M1 design audit of rev 0 (Opus 5/O-4) | NEEDS-FIX — 2 blocker, 2 critical, 5 must |
| `design-M1.audit-2.md` | M1 design re-audit of rev 1 (Opus 5/T146) | NEEDS-FIX — NEW-1 critical, NEW-2..5 must |
| `design-M1.audit-3.md` | M1 design re-audit of rev 2 (DSPro/T150) | NEEDS-FIX — NEW-1/NEW-5 carried; RV2-1 was phantom |

Deleted rather than archived (byte-recoverable from git):

- original pass-0 spec text (pre-F1–F9): `git show 56950a1:docs/design/oracle-v2/pass0/spec.md`
- strategy rev 0: `git show 56950a1:docs/design/oracle-v2/pass0/strategy.md`
- pass-1 spec snapshot (= live spec minus the A6 amendment): `git show 56950a1:docs/design/oracle-v2/pass1/spec.md`
