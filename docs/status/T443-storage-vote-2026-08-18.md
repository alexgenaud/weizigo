# T443 storage & durability — one-page vote sheet for the operator

The full proposal is `untracked/T443-policy-draft.md` (239 lines, deepseek-v4-flash, read-only,
every number from `ls`/`du`/`git grep` at HEAD or from committed evidence). This page is the
short form: six items, each a yes/no, with the Orchestrator's recommendation and what it costs
to say yes. Nothing in the draft is in force until you rule.

| # | proposal | recommend | what saying yes costs |
|---|---|---|---|
| P1 | `/tmp/weizigo` is scratch: write-only, `mkdir -p` + hard-fail in every script that uses it, never cited in a committed doc | **ratify** | nothing — it is the status quo plus T445's guard, written down |
| P2 | `data/` gets a tracked `data/MANIFEST.json` (path, bytes, sha256, builder commit, regen cost + denominator, archive status) covering **every** file incl. `reuse-baseline/`; no new `data/` file without a manifest row in the same commit | **ratify** | one row of work to write the manifest; a small tax on every future table |
| P3 | `tools/archive-oracle.sh` — one operator-run step that tars `data/` to an external volume and records the archive's sha256 in the manifest | **ratify, and run it once** | you have to name a destination volume and run it. Until then the exposure is real: 1.7 GB on one disk, ten same-disk copies of the 4×4 table, and same-disk copies protect against nothing but an accidental `rm` |
| P4 | `untracked/` is comms + large artifacts, never cited by a committed doc (820 such citations exist today — the `/tmp` disease one layer down) | **ratify as a direction, not a deadline** | registers a debt; the re-point is a later row |
| P5 | `docs/evidence/` + `findings/` unchanged | **ratify** | nothing |
| P6 | Dead defaults are bugs: `src/arena.zig:565` → `data/oracle-4x4.wzo` and `src/resolver_harness.zig:283` → `data/oracle-4x3-v2.wzo2` point at files that do not exist | **ratify** | the next row touching those files repoints them |

## RULED, 2026-08-18 (operator): no binaries in git, and no worktrees to design for

The operator's ruling, same evening this sheet was written: **large artifacts do not go into a
git branch**, even one later squashed or deleted. Diligent organization of `/tmp/weizigo`
(scratch) and `untracked/` (host-local artifacts) is the working answer. He further ruled that
**this project has no need for worktrees**, so cross-branch and cross-worktree binary sharing is
a problem we do not solve.

Two consequences to carry:

1. **The durability question is not settled by this ruling and must not be filed as if it were.**
   `/tmp` is precisely where the 9.4 GB `260707` archive was lost to tmp decay, and `untracked/`
   dies with the disk. Organization is the right answer for *scratch*; **one off-disk copy** (P3)
   is still the only thing that survives the disk failing. That remains open.
2. **T449 drops in priority.** `tools/runner` being blind inside a git worktree is a real defect,
   but if the project runs no worktrees it is **latent, not live**. The one place a worktree is
   used today is race-lane isolation (`tools/bakeoff.sh`, T376) — optional, and its own harness
   already resolves roots correctly. Keep the row; do not rank it above live work.

## Why the branch idea was the wrong shape anyway (kept as the reasoning behind the ruling)

The sketch: commit epic/sprint binary data to a git branch, delete the binary once stable, then
squash/merge into `main`. The mechanics work against it:

- A committed binary enters the object store permanently. Deleting the file in a later commit
  does not reclaim it; deleting the *branch* does not either. Reclamation needs the objects to
  be unreachable **and** a `gc` with the reflog expired — and until then every clone carries
  518 MB per table copy.
- The 4×4 table is 518 MB and there are effectively ten copies of it on this disk today. Any of
  that entering git is unrecoverable in practice.

The exception that does work: an **orphan branch that is never merged** (`git switch --orphan`),
used as a pure content store and pruned by deleting the branch and gc-ing before anything is
merged anywhere. It keeps the bytes out of `main`'s history entirely. Even so, P3's manifest +
off-disk archive dominates it on every axis: no clone bloat, no gc ritual, and it survives the
disk dying — which is the actual risk. **Recommendation: P3 first; revisit the orphan branch
only if you want a second copy that lives on a git host.**

## Two follow-ups the draft names and this sheet endorses

1. **3×3-v2 regeneration cost is unmeasured** — 4×4 is recorded (63–83 min, deterministic 8/8),
   3×3-v2 has no standalone record. One measured run closes it.
2. **Consolidate the nine same-disk duplicates** of `oracle-4x4-v2.wzo2` (≈4.6 GB) after P3 has
   run once, never before — the duplicates are the only redundancy that exists until then.
