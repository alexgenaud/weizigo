#!/usr/bin/env bash
# git-commit-mine-lib.sh — scope resolution shared by tools/git-commit-mine
# (the wrapper, T278) and tools/hooks/pre-commit (the staged-path backstop,
# T282). ONE implementation, two callers: a second copy of the parsing is how
# the two would drift apart and the hook would start refusing the wrapper's
# own commits — which is the exact class of "sound by construction" rot this
# repo keeps getting bitten by.
#
# Used two ways:
#   source <this-file>          — defines the gcm_* functions (the wrapper)
#   bash <this-file> <cmd> …    — runs one command (the hook):
#       task-bundle <repo> <task-id> [tasks-json]
#           prints the task's bundle path (repo-relative); exit 2 if the
#           kanban is unreadable, 3 if the task id is absent.
#       bundle-deliverables <bundle-path>
#           prints the deliverables= paths parsed from the bundle's first-line
#           meta header (mirrors managent's parser, including the defect-2
#           truncation: the value stops at the next " key=value" token).
#       scope <repo> <task-id> [tasks-json]
#           prints the full scope, one path per line: the bundle's
#           deliverables ∪ findings/<id>-*.json ∪ the two fleet-coordination
#           surfaces (docs/status/CURRENT.md, docs/status/HANDOVER.md — any
#           worker may legitimately touch these).
#
# tasks-json defaults to <repo>/docs/infra/managent/tasks.json. The caller
# passes MANAGENT_STORE (the managent binary's substrate-isolation override,
# src/managent/main.zig:150) through as the third argument when set; an empty
# third argument falls back to the default.
#
# Task: T282 · Role: worker · Model: deepseek-v4-flash · Date: 2026-08-03

set -u

gcm_task_bundle() {
    # <repo> <task-id> [tasks-json] → prints bundle relpath; 2 = kanban unreadable, 3 = task absent
    [ "$#" -ge 2 ] || { echo "git-commit-mine-lib: task-bundle needs <repo> <task-id>" >&2; return 2; }
    local repo="$1" tid="$2"
    local store="${3:-$1/docs/infra/managent/tasks.json}"
    python3 - "$repo" "$tid" "$store" <<'PYEOF'
import json, sys
repo, tid, store = sys.argv[1], sys.argv[2], sys.argv[3]
try:
    d = json.load(open(store))
except Exception:
    sys.exit(2)
t = d.get(tid)
if not t:
    sys.exit(3)
print(t.get("bundle") or "")
PYEOF
}

gcm_task_status() {
    # <repo> <task-id> [tasks-json] → prints the task's stored status, lowercased
    # (dispatchable / in_progress / done / failed / blocked); empty when the
    # entry carries no status key (synthetic fixtures); 2 = kanban unreadable,
    # 3 = task absent.  T424: the claim-lifecycle guard reads this — a commit
    # under a task that is not in_progress is refused (worked-without-claiming
    # was invisible to holdsConflict all week of 2026-08-08).
    [ "$#" -ge 2 ] || { echo "git-commit-mine-lib: task-status needs <repo> <task-id>" >&2; return 2; }
    local repo="$1" tid="$2"
    local store="${3:-$1/docs/infra/managent/tasks.json}"
    python3 - "$repo" "$tid" "$store" <<'PYEOF'
import json, sys
repo, tid, store = sys.argv[1], sys.argv[2], sys.argv[3]
try:
    d = json.load(open(store))
except Exception:
    sys.exit(2)
t = d.get(tid)
if not t:
    sys.exit(3)
print((t.get("status") or "").lower())
PYEOF
}

gcm_bundle_deliverables() {
    # <bundle-path> → prints deliverables= paths parsed from the meta header
    [ "$#" -ge 1 ] || { echo "git-commit-mine-lib: bundle-deliverables needs <bundle-path>" >&2; return 2; }
    local bundle="$1"
    [ -f "$bundle" ] || return 0
    local meta val
    meta=$(head -1 "$bundle")
    case "$meta" in
        *"deliverables="*)
            val=${meta#*deliverables=}
            val=${val%%-->*}
            # defect-2 truncation: the value stops at the next " key=value" token
            # (e.g. " acceptance=cmd") — mirrors managent's parser
            val=$(printf '%s' "$val" | sed -E 's/[[:space:]][^= ]*=.*$//')
            while IFS= read -r p; do
                p=$(printf '%s' "$p" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
                [ -n "$p" ] && printf '%s\n' "$p"
            done <<< "$(printf '%s' "$val" | tr ',' '\n')"
            ;;
    esac
    return 0
}

gcm_scope_for_task() {
    # <repo> <task-id> [tasks-json] → prints the full scope, one path per line
    [ "$#" -ge 2 ] || { echo "git-commit-mine-lib: scope needs <repo> <task-id>" >&2; return 2; }
    local repo="$1" tid="$2"
    local store="${3:-$1/docs/infra/managent/tasks.json}"
    local bundle_path bundle f
    bundle_path=$(gcm_task_bundle "$repo" "$tid" "$store") || return $?
    if [ -n "$bundle_path" ]; then
        bundle="$repo/$bundle_path"
        gcm_bundle_deliverables "$bundle"
    fi
    for f in "$repo"/findings/"$tid"-*.json; do
        [ -e "$f" ] && printf '%s\n' "${f#$repo/}"
    done
    printf '%s\n' "docs/status/CURRENT.md" "docs/status/HANDOVER.md"
    return 0
}

if [ "${BASH_SOURCE[0]}" != "$0" ]; then
    : # sourced as a library — functions only
else
    cmd="${1:-}"
    shift 2>/dev/null || true
    case "$cmd" in
        task-bundle) gcm_task_bundle "$@" ;;
        task-status) gcm_task_status "$@" ;;
        bundle-deliverables) gcm_bundle_deliverables "$@" ;;
        scope) gcm_scope_for_task "$@" ;;
        *) echo "git-commit-mine-lib: unknown command '$cmd'" >&2; exit 2 ;;
    esac
fi
