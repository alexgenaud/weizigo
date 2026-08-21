# project-restructure pass1 — SPEC (stub)

```
Revision: 1
Status:   PROPOSED
Author:   DSPro/T200 (pass0 sprint manager) · 2026-08-01
Source:   pass0/design.md rev 1 §1.4 (target-state layout)
          pass0/accept.md rev 1 (open dependency D3)
          pass0/scope.md rev 2 §"Two-pass strategy"
```

**This is a seed, not a complete spec.** The Orchestrator or a designated
builder must write the full spec before pass1 begins. This stub exists so
an agent arriving cold knows pass1 is expected and what it entails.

---

## What pass1 does

Pass1 is the **dedicated relocation sprint under task freeze.** It executes
the target-state layout designed in pass0 (`design.md` §1.4). No concurrent
writers to `docs/`, `src/claimlint.zig`, or `.gitignore`.

### Must execute

1. **Relocate `docs/epistemic/`** into functional subdirectories per
   `pass0/design.md` §1.4 (register/, narrative/, glossary/, critiques/,
   concepts/, indices/). Move the indices from `docs/INDEX-claim-*.md`
   into `docs/epistemic/indices/`.

2. **Relocate `docs/evidence/`** to its target-state location (TBD in pass1
   design — pass0 explicitly deferred this decision).

3. **Update `src/claimlint.zig`** constants (DEFAULT_CLAIMS, NARRATIVE_FILE,
   LOSS_INVENTORY) and re-run calibration battery.

4. **Update `.gitignore`** evidence-store rules.

5. **Sweep all tracked references** — 593 `docs/evidence/`, 269
   `docs/epistemic/` (plus any new paths). Every reference resolved or
   flagged.

6. **The reference sweep is itself an audit** — broken links, stale paths,
   orphan citations surface during the sweep. Findings feed back into the
   backlog.

### Task freeze

Pass1 runs as the **only sprint executing.** No other agent writes to
`docs/`, `src/claimlint.zig`, or `.gitignore` while pass1 is in flight.
This is a hard requirement from pass0 scope.md.

---

## Source documents (read these first)

| document | what it provides |
|---|---|
| `pass0/scope.md` §"Two-pass strategy" | The pass1 scope definition |
| `pass0/design.md` §1.4 | The target-state layout (file moves, claimlint updates, slot reservations) |
| `pass0/design.md` §1.2 | Why pass0 deferred reorganization (frozen-file constraint) |
| `pass0/accept.md` §"Open dependencies" | D3 — pass1 relocation sprint |
| `pass0/test.md` §2 | Frozen-file list (10 files, 39 refs — these become unfrozen in pass1) |
| `pass0/backlog.md` | C4 dangling IDs/unreferenced — to be resolved during reference sweep |

---

## What is NOT in scope for pass1

Repeating pass0 scope.md:

- **No claim status changes** — adjudication, not restructuring
- **No substantive rewrites** of CLAIMS.md, PROGRESS.md, or any provenance
  document
- **No channel deletion or archival** — the pruning rule is written but
  not executed
- **No `src/`, `bin/`, `data/`, `artifacts/` reorganization**
- **No `docs/audits/`, `docs/research/`, `docs/status/` reorganization**
  unless the pass1 design finds they belong in the target-state layout

---

**Next:** Orchestrator ratifies this stub (or rewrites it), assigns a builder,
and dispatches pass1 under task freeze.
