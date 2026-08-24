#!/usr/bin/env bash
# scratch-repo.sh — the ONE place a scratch git repository is created.
#
# Why this exists (T849, 2026-08-24): on 2026-08-24 the repository was
# silently repointed at a scratch directory twice. git sets GIT_DIR (and
# friends) for hook children; a regression script then ran `git init` in a
# `mktemp` scratch dir with GIT_DIR still pointing at the REAL repository —
# which reinitialised the real repo and left core.worktree aimed at /tmp.
# Commits truncated 2,556 files to 4 and the task store was overwritten,
# losing 59 tasks. tools/hooks/pre-commit now unsets the git env, but that
# guard covers only the pre-commit path; the 58 regression scripts that
# `git init` a scratch repo are unguarded every other way they are run
# (directly, by the suite, by `zig build test`). Every one of them is meant
# to source THIS file instead, so the isolation lives in one place.
#
# Contract (T849):
#   - unsets GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY
#     GIT_NAMESPACE before any git command, so a child can never reach back
#     into the real repository;
#   - creates the scratch dir under ONE normalised root, resolving the
#     /tmp vs /private/tmp symlink split (on this host /tmp → /private/tmp)
#     so git never traverses the symlink;
#   - refuses to continue if scratch creation fails (T445 — an empty WORK
#     once sent a suite's arms into the LIVE repo);
#   - `git init -q` and leaves the caller a variable pointing at it;
#   - safe to call more than once in one script (two scripts call it seven
#     times): each call yields a distinct repo.
#
# Usage:
#   source tools/lib/scratch-repo.sh
#   weizigo_scratch_repo <slug> [outvar]
#       <slug>   — short label for the mktemp template (e.g. t515-taskid)
#       <outvar> — name of the variable to receive the repo path; defaults
#                  to WEIZIGO_SCRATCH_DIR. Use a per-call name when a script
#                  needs several scratch repos at once.
#   On failure (mktemp or git init) the function prints a FATAL line to
#   stderr and returns 2; under `set -e` that aborts the script, preserving
#   the T445 refuse-on-failure contract.
#
# Normalised root: WEIZIGO_SCRATCH_ROOT (env override; default /tmp/weizigo),
# resolved to its real path once at source time so the /tmp symlink is never
# traversed by a child git.
#
# Task: T849 · Role: worker · Model: glm-5.2 · Date: 2026-08-24

# ── isolation: unset inherited git env before anything git can see ───────
# Done at source time so the whole script is clean, and again inside the
# function so a re-set env between calls cannot sneak through.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_NAMESPACE

# ── normalised scratch root ─────────────────────────────────────────────
# Resolve the /tmp → /private/tmp symlink once. Callers that used either
# spelling now get the same real path, and child gits never traverse the
# symlink (the "beyond a symbolic link" refusal).
: "${WEIZIGO_SCRATCH_ROOT:=/tmp/weizigo}"
if ! WEIZIGO_SCRATCH_ROOT="$(cd "$WEIZIGO_SCRATCH_ROOT" 2>/dev/null && pwd -P)"; then
    # root does not exist yet — resolve its parent and append the leaf
    WEIZIGO_SCRATCH_ROOT="$(cd "$(dirname "$WEIZIGO_SCRATCH_ROOT")" 2>/dev/null && pwd -P)/$(basename "${WEIZIGO_SCRATCH_ROOT:-/tmp/weizigo}")"
fi
export WEIZIGO_SCRATCH_ROOT

weizigo_scratch_repo() {
    # re-assert isolation in case the caller (or a tool it ran) re-set it
    unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_NAMESPACE
    local slug outvar d
    slug="${1:-}"
    outvar="${2:-WEIZIGO_SCRATCH_DIR}"
    if [ -z "$slug" ]; then
        echo "scratch-repo: FATAL — slug required (usage: weizigo_scratch_repo <slug> [outvar])" >&2
        return 2
    fi
    mkdir -p "$WEIZIGO_SCRATCH_ROOT" || { echo "scratch-repo: FATAL — cannot create scratch root $WEIZIGO_SCRATCH_ROOT" >&2; return 2; }
    d="$(mktemp -d "$WEIZIGO_SCRATCH_ROOT/${slug}-XXXXXX")" || { echo "scratch-repo: FATAL — mktemp failed under $WEIZIGO_SCRATCH_ROOT; refusing to continue (T445)" >&2; return 2; }
    # resolve any remaining symlink in the temp path itself
    d="$(cd "$d" && pwd -P)"
    git init -q "$d" || { echo "scratch-repo: FATAL — git init failed in $d" >&2; return 2; }
    printf -v "$outvar" '%s' "$d"
}