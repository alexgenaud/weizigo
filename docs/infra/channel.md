# Channel — agent-to-agent communication infrastructure

```
Created:  2026-08-01 · Sprint: project-restructure pass0 (T200)
Source:   spec.md item 3 (channel organization and pruning)
Related:  docs/infra/sprint.md · docs/infra/delegation/ROLES.md
```

The **channel** is the agent-to-agent working-space directory under
`untracked/msg/`. It is NOT in git — it is a scratchpad for cross-agent
coordination during a sprint. The canonical record of every sprint is its
phase documents in git (`spec.md`, `design.md`, `plan.md`, `test.md`,
`build.md`, `accept.md`).

---

## 1. Layout

```
untracked/msg/
├── <epic>/                  ← one directory per epic
│   ├── <sprint>/            ← one directory per sprint within the epic
│   │   ├── STATE.md         ← crash-recovery anchor (read first)
│   │   ├── DECISIONS.md     ← rulings awaiting promotion to docs/
│   │   └── NNN-<from>-to-<to>.md  ← numbered messages (append-only)
│   ├── STATE.md             ← epic-level crash-recovery anchor
│   └── DECISIONS.md         ← epic-level rulings
```

**Current channel:** `untracked/msg/milestone-01-ko-reframe/` — the live epic channel for
`epic-01-markovian`. Its directory name (`milestone-01-ko-reframe`)
is a historical alias for `epic-01-markovian`. The term "milestone" is retired
in favor of "epic" for new documents; the directory name is preserved as-is
to avoid breaking existing references.

**New sprints** use `untracked/msg/epic-01-markovian/<sprint>/`.

### Template

To initialize a new sprint channel, copy from:

```
docs/infra/channel-template/
├── STATE.md
└── DECISIONS.md
```

These are placeholder files with `<EPIC>`, `<SPRINT>`, `<DATE>` markers.

---

## 2. The pruning rule

> When pass N of sprint S closes and its `accept.md` is ratified, the sprint's
> channel directory may be archived or deleted, because the canonical record is
> the phase documents in git. The channel is a working-space convenience, not a
> durable record. Pruning is opt-in per pass: the sprint's `accept.md` states
> whether the channel was archived or retained, and why. A retained channel
> carries a README stating its retention reason and the date its pass closed.
>
> The epic-level channel (`untracked/msg/<epic>/`) is pruned only when the epic
> closes, by human decision, because it holds cross-sprint `DECISIONS.md` and
> `STATE.md` that no single sprint owns.

### What this rule authorizes

- **After a sprint's pass closes and accept.md is ratified:** the sprint's
  channel directory (`untracked/msg/<epic>/<sprint>/`) may be deleted.
- **The decision is recorded in accept.md** — "channel retained" or
  "channel deleted" with a one-line reason.
- **A retained channel** gets a `README.md` stating the retention reason
  and the date the pass closed.

### What this rule does NOT authorize

- **Deletion of the live epic channel while the epic is open.**
  `untracked/msg/milestone-01-ko-reframe/` is the live epic channel for
  `epic-01-markovian`. It may NOT be deleted until the epic closes.
- **Deletion without accept.md ratification.** The pruning is opt-in and
  recorded, never silent.

---

## 3. Addressee convention

The filename convention encodes addressees:

```
NNN-<from>-to-<to>.md
```

Examples: `068-dabir-to-orchestrator.md`, `069-consul-to-all.md`.

Messages are numbered sequentially within the channel. A single numbered
sequence readable by every seat has proven value; per-addressee
subdirectories were considered and rejected (design.md §2.4). They would
fragment the chronological record.

---

## 4. The evidence-store invariant

The channel lives under `untracked/msg/`, NOT under `docs/`. The invariant
that saved the evidence store is:

> **If it is under `docs/`, it is in git and retrievable.**

`docs/evidence/README.md` exists because `untracked/` was cleaned and the
primary evidence for load-bearing claims was destroyed (T13). A git-ignored
directory inside `docs/` — e.g., `docs/epic-01-markovian/sprints/<sprint>/
channel/` — would invert this invariant: a path that reads canonical but is
not in git is the exact failure mode that destroyed T13's evidence.

The channel is explicitly NOT durable. Placing it under `docs/` even with
a `.gitignore` would communicate permanence it does not have.

---

## 5. Cross-references

- `docs/infra/sprint.md` — phase gates and sprint lifecycle. Points here for
  channel layout and pruning.
- `docs/INDEX.md` — the authoritative retrieval index. Routes
  crash-recovery to `untracked/msg/<epic>/<sprint>/STATE.md`.
- `docs/infra/agent-identity-and-worker-channel.md` — identity scheme and
  channel protocol for agents.
