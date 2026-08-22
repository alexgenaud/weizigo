# store-sharding design — per-row files + tasks.json as index

**Design deliverable of T671 (store-write contention).** Operator proposal,
2026-08-22: "write to a new unique file, then register that task and file with
managent, and managent would write to tasks.json pointing to your task-file …
catch the duplicated T-ID." This document answers the brief's five
design questions and states the recommendation. **The recommendation is to NOT
migrate now** — the gain is partial, the duplicate-ID loss is already closed,
and the one sharp edge worth fixing cheaply is something else (a silent
empty-store hazard). Written by `deepseek-v4-pro/T671`; immutable companion:
`findings/T671-store-contention.json`.

## 0. Verdict up front

Per-row files are the *right end state* but the *wrong next step*. The
operator's sharpest instinct — "the duplicate T-ID is catchable at
registration" — is already true under the current model: T545 wrapped every
store writer in a `lock → read → modify → write → unlock` flock, and `cmdAdd`
already refuses `task '<id>' already exists` when it re-reads under that lock.
The remaining contention is real but *shrinks, not vanishes*, under per-row
files (see §2), and the migration cost is large. The cheap, high-value fix is
the **silent empty-store hazard** (§5): today an existing store whose content
is empty, `{}`, or valid-but-non-object JSON is read as an *empty kanban* and
then overwritten with an `_sys`-only store by the startup migration — silently
destroying all 338 rows. That is the one thing worth a code change, and it is
small.

## 1. Inventory — what actually has to be atomic

The "store" is not one file. Shared mutable state, 2026-08-22:

| path | size | rows | write shape | writers |
|---|---|---|---|---|
| `docs/infra/managent/tasks.json` | 527 KB | 338 | whole-file RMW under flock | ~24 verbs (add/claim/done/set/needs/agent/verdict/amend/archive/reopen/purge/tell/assert/standing/sync/…) |
| `docs/infra/managent/archive.json` | 104 KB | 115 | whole-file RMW under flock | archive, retire |
| `docs/infra/managent/directives.jsonl` | 154 KB / 393 lines | — | append-only | tell |
| `docs/infra/assertion-ledger/assertions.jsonl` | 2.8 KB | — | append-only | assert |
| `_sys` (inside tasks.json) | — | 5 counters/flags | whole-file RMW (same as tasks.json) | add --auto, tell, assert, done |
| `_sync` / `_standing` (inside tasks.json) | — | — | **raw string surgery, not in StateMap** | sync, standing |

Two facts drive the whole design:

1. **Lost-update contention is already closed.** T545 (2026-08-20) moved all
   24 writers under one `flock` spanning read→write. The audit found five
   unlocked writers, not three; all five now lock. The remaining contention is
   *lock-wait*, not silent reversion. `tools/regression-managent-concurrency.sh`
   locks this invariant (5 arms).

2. **`_sync`/`_standing` are the fragile half of the store.** They are written
   by raw string surgery (`writeSyncData`, `persistStandingState`) and are
   **dropped by any later `writeStateLocked`** — the parser skips `_`-prefixed
   keys, the serializer never emits them. This was recorded as a sibling defect
   in T545's findings and is still unfixed. Any sharding design that does not
   first-class these two keys reproduces the same defect in more files.

## 2. What still has to be atomic — does the contention move or shrink?

**It shrinks in magnitude, does not vanish in count.** The partition:

- **Row writes** (claim, close, set, needs, agent, verdict, amend, archive) —
  under per-row files these touch only their own file. Two claims on different
  rows no longer contend at all. This is the real win.
- **Counter writes** (`_sys.directive_next` via tell, `_sys.assertion_next` via
  assert, `_sys.next_id` via add --auto, `_sys.closes` via done) — these are
  still a shared, monotonically-increasing counter that must be
  atomically bumped. They serialize on *some* shared file regardless of the
  row layout. Per-row files do not remove this serialization point; they shrink
  its payload from a 527 KB whole-store rewrite to a ~50-byte counter bump.
- **Derived-status reads** — `status`/`show`/`orient`/`next`/`claim`/`done` all
  need the full row set in memory (status is derived from the needs graph), so
  they read index + N row files. 338 opens of ~1–2 KB files is sub-millisecond;
  this is not a problem at any plausible row count.

**Quantification.** 35 commits touched tasks.json on 2026-08-22 alone (lower
bound on writes; every claim/close/tell/assert writes, only some get
committed). Each write is serialize(527 KB) + fsync + atomic rename under a
flock bounded at 3.2 s (`lockStore`). Under a dispatch wave (a dozen lanes
claiming/closing at once), the whole-file flock serializes them at a few ms
each — contention is measurable but not yet the bottleneck; the 3.2 s bound is
the failure mode if it ever becomes one.

**Conclusion:** the contention *moves* (rows → counters) and *shrinks*
(527 KB → bytes). Shrinking the payload is a genuine, if modest, improvement;
it is not enough on its own to justify the migration.

## 3. Where the row's state lives — the decision

Three options:

| option | claim/close write | `status` cost | crash-consistency surface |
|---|---|---|---|
| A. status stays in index (shallow rows) | shared file — **no gain, rejected** | index only | unchanged |
| B. status in per-row file; index = id→path + `_sys` only | own file | N+1 reads | new: index↔row |
| C. status in per-row file; index also carries a status cache | own file | 1 read (cache) + revalidation | new + cache drift |

**Choose B.** A leaves the problem in place. C reintroduces a derived-cache
consistency bug (the exact class that produced the "stored vs derived status"
migration in the first place) for a read cost that is already trivial. B is
the only option that achieves the operator's goal.

**What B costs:**

- **Every read verb becomes N+1 reads.** `status`/`show`/`orient`/`audit`/
  `why`/`next`/`claim`/`done` open the index and every row file, because
  derived status needs the whole needs graph. Fine at 338 rows; a future 5×5
  row explosion would need a batch-reader, not a redesign.
- **Crash consistency is *better*, not worse.** Order: write row file
  (fsync), then atomic-rename the index. A crash between the two leaves an
  orphan row file the index does not list — harmless, detectable,
  garbage-collectable. A crash mid-index-rename leaves either the old or the
  new index (rename is atomic). Today a single torn store is *total* loss;
  per-row files bound the blast radius to one row. This is the design's
  strongest argument — but it is a *robustness* argument, not a *contention*
  argument.
- **The `_sys` counters need their own home.** A small `_sys.json` (or a
  counter file with `flock` + O_APPEND) replaces the `_sys` block. This is the
  one remaining shared write. It is tiny.
- **`_sync`/`_standing` must be first-classed** (own keys in the index or own
  files) — today they are raw string surgery and already get dropped by
  unrelated writes. Sharding without this fix just moves the defect.

## 4. Migration

338 live rows + 115 archived rows, reversible, idempotent, lossless.

- **Split:** `tasks.json` → index `{"_sys": {...}, "rows": {"T601": "rows/T601.json", …}}`
  plus one `rows/<id>.json` per row carrying the row's full object (amendments,
  epitaph, scope fields, model/attribution fields move wholesale — they are
  per-row). `archive.json` shards the same way into `archive-rows/`.
- **Untouched by construction:** `killed_by` lives in `untracked/runs/*.json`
  and the directives ledger, *not* in tasks.json — the brief's §3 concern about
  "killed_by records ruling 32's census depends on" is about the run records,
  which are already outside the store and are not affected. Assertions and
  directives are already append-only files outside tasks.json.
- **Reversible:** a `merge` subcommand recomposes the original single-file
  store, rows ordered deterministically by id, so the reverse is
  byte-for-byte when no writes intervened (and a clean re-derivation
  otherwise). Rollback is `merge` then delete `rows/`.
- **Idempotent:** split refuses if `rows/` already exists with matching
  per-row hashes; merge refuses if the index is already single-file.
- **Gate:** run split, run merge, diff against the pre-split store; run split
  twice → second is a no-op. These are the brief's "migration run twice →
  idempotent; backwards → original restored" controls, spec'd here so the
  follow-up builds them test-first.

## 5. The ID-collision check — already closed, and the real sharp edge

**The duplicate-T-ID silent loss is already fixed.** `cmdAdd` (non-auto)
re-reads under the flock and refuses `error: task '<id>' already exists`
(`src/managent/main.zig:2962`). `add --auto` bumps `_sys.next_id` under the
same flock. The operator's scenario — "two writers each read a store lacking
T999, each write it, the loser's row disappears" — is the *pre-T545* shape;
T545 closed the window. Two concurrent registrations of the same id today
yield exactly one success and one loud refusal. This was a reason to migrate
*before* 2026-08-20; it is not one now.

**The real sharp edge is the silent empty store.** Trace
(`src/managent/main.zig`):

- `readState` returns an empty `StateMap` on `FileNotFound` (legitimate fresh
  clone) — and passes everything else to `parseStateJson`.
- `parseStateJson` returns an empty `StateMap` when the content trims to empty
  **or** is exactly `{}` (`:1944-1946`), and returns an empty `state` when the
  parsed value is valid JSON but not an object — `null`, `[]`, `42`, `"x"`
  (`:1959`).
- The startup migration block then sees `sys_duty_migrated == false` (a
  store with no `_sys`), so `duty_migrated_now` is true and it **writes the
  empty state back** as an `_sys`-only store — on *every* invocation, read-only
  verbs included.

Net: a store whose content is empty, `{}`, or any valid non-object JSON is
silently *replaced* by an empty `_sys`-only store. All 338 rows gone, no error,
and the next `status` prints an empty kanban. This is precisely the D046 shape
the brief names ("store corruption silently emptying every store-reading
verb"), and precisely the "never a silently empty store" control. Invalid JSON
does fail loudly (the parse errors out); the silent cases are the empty /
`{}` / non-object-but-valid ones.

**The fix (recommended follow-up, small):** `readState` distinguishes
file-absent (empty, legitimate) from file-present-but-content-is-not-a-valid
JSON object carrying `_sys` (corruption → loud refusal, exit non-zero, no
migration write). A store written by managent always contains `_sys`
(`serializeState` emits it even for zero rows), so "present but no `_sys`"
is unambiguously corruption, never a fresh store. This is ~15 lines in
`readState`/`parseStateJson`, plus a test-first regression (empty file, `{}`,
`[]`, `null`, truncated mid-token) wired into `zig build test`, asserting a
loud non-zero exit and *no* overwrite of the corrupt file.

## 6. Prior art (the brief's §5)

- **T545** — the lost-update class; already locked all 24 writers; recorded the
  `_sync`/`_standing` raw-surgery defect as a sibling finding. *This is why the
  duplicate-ID loss is already closed.*
- **T587** — the write path is byte-correct and already
  serialize → parse-back → atomic-rename; the suspected corruption was a stale
  fleet binary. *This is why the empty-store hazard is external (not a torn
  write), and why the guard is a read-side check, not a write-side one.*
- **T650** — the same "append/never-overwrite" instinct, already landed for
  run records. *This is the proof the operator's instinct is sound in the
  general case; the store is just the wrong next target.*

## 7. Recommendation

1. **Do not migrate to per-row files now.** The gain is partial (counters
   still serialize; duplicate-ID already loud; contention shrinks not
   vanishes) and the cost is large (every read path, crash-consistency,
   migration + reverse, first-classing `_sync`/`_standing`).
2. **Do implement the silent-empty-store guard** (§5) as the cheap, high-value
   fix — a small, test-first change to `readState`/`parseStateJson`. This is
   the one piece of this design that pays for itself immediately.
3. **If** a 5×5-era fleet makes contention the measured bottleneck, revisit
   per-row files then — option B (§3) is the design to follow, and this
   document is the spec to build against. Revisit, don't relitigate.

**Why this row produces no code:** `src/managent/main.zig` is live-held by
T636 (row-shape, in progress on the same file) — the one-writer invariant
forbids a concurrent edit — and the design's own verdict is that the
migration is not the right next step. The follow-up that implements §5 is a
separate mutation row, sequenced after T636 releases the file.
