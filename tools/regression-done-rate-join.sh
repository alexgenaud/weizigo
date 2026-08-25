#!/usr/bin/env bash
# T942: DONE rates must join tokens_out and wall from one served dispatch run.
# The fixture is hermetic and deliberately includes a later model:null smoke
# record for T924; that record must never donate wall to the ox-alpha lane.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
MG="$ROOT/bin/managent"
# lsof reports physical paths on macOS; use /private/tmp so the script's
# resolved cwd check agrees with the dummy worker's cwd.
WORK="$(mktemp -d /private/tmp/weizigo/done-rate-join-XXXXXX)"
DUMMY=""
cleanup() { [ -n "$DUMMY" ] && kill "$DUMMY" 2>/dev/null; rm -rf "$WORK"; }
trap cleanup EXIT

mkdir -p "$WORK/bin" "$WORK/docs/infra/managent" "$WORK/untracked/runs" "$WORK/untracked/tokens" "$WORK/untracked/tokens/sessions"
ln -s "$MG" "$WORK/bin/managent"
cp "$ROOT/docs/infra/model-registry.md" "$WORK/docs/infra/model-registry.md"
git -C "$WORK" init -q
git -C "$WORK" config user.email t942@test
git -C "$WORK" config user.name T942
STORE="$WORK/docs/infra/managent/tasks.json"
# The dashboard changes directory to the parent of its own path, so exercise
# a scratch copy; invoking the repository copy would read live token files.
LIVE="$WORK/untracked/watch-fleet.sh"
cp "$ROOT/untracked/watch-fleet.sh" "$LIVE"

python3 - "$STORE" "$WORK" <<'PY'
import json, sys
store, work = sys.argv[1:]
models = {
    "T894": ("claude-sonnet-5", 70532, 991.1),
    "T916": ("oxalpha", 20329, 767.7),
    "T924": ("oxalpha", 44877, 4110.6),
    "T938": ("claude-haiku-4-5-20251001", 25580, 287.1),
}
d = {"_sys": {"next_id": 9900, "directive_next": 1, "assertion_next": 1}}
for task, (model, tokens, wall) in models.items():
    d[task] = {
        "status": "done", "agent": model, "model": model,
        "bundle": f"untracked/{task}-bundle.md", "set": "A", "holds": [],
        "needs": [], "caps": [], "added": "2026-08-20T00:00:00Z",
        "claimed": "2026-08-25T00:00:00Z", "done": "2026-08-25T02:00:00Z",
        "dispatched": None, "dispatched_to": None, "note": None,
        "verdict": "pass", "verdict_note": None, "acceptance": None,
        "skip_acceptance_reason": None, "claim_count": 1,
    }
    open(f"{work}/untracked/{task}-bundle.md", "w").write(
        f"<!--managent -->\n# {task} — rate fixture\n\nBody.\n")
    # The matching record is the served lane and is the only source allowed
    # to contribute both readings.
    rec = {"attempt": 1, "run_kind": "dispatch", "model": model,
           "tokens_out": tokens, "wall": wall,
           "start": "2026-08-25T00:00:01Z", "end": "2026-08-25T02:00:00Z",
           "exit": 0}
    # Keep the matching lane in the default record for the ordinary rows;
    # T924 additionally gets a later, null-model attempt below to seed the
    # cross-run defect.
    path = f"{work}/untracked/runs/{task}.json" if task != "T924" else f"{work}/untracked/runs/{task}.1.json"
    json.dump(rec, open(path, "w"))
# T924's later smoke test is intentionally the last/default record. It has no
# model and must not be joined to the ox-alpha token reading.
json.dump({"attempt": 2, "run_kind": "dispatch", "model": None,
           "tokens_out": None, "wall": 3.1, "start": "2026-08-25T03:00:00Z",
           "end": "2026-08-25T03:00:03Z", "exit": 0},
          open(f"{work}/untracked/runs/T924.json", "w"))
json.dump(d, open(store, "w"), indent=2)
PY
# A direct fixture write bypasses the live census; clear any scratch census
# so managent status can read this intentionally small store.
rm -f "$WORK/docs/infra/managent/store-census.json"

cat > "$WORK/untracked/tokens/tokens.jsonl" <<'JSONL'
{"task":"T894","tokens_out":70532,"ts":"2026-08-25T02:00:00Z"}
{"task":"T916","tokens_out":20329,"ts":"2026-08-25T02:00:00Z"}
{"task":"T924","tokens_out":44877,"ts":"2026-08-25T02:00:00Z"}
{"task":"T938","tokens_out":25580,"ts":"2026-08-25T02:00:00Z"}
JSONL

# DONE controls: all four rows must use the matching dispatch record's wall.
FRAME=$(cd "$WORK" && MANAGENT_STORE="$STORE" FLEET_COLS=200 sh "$LIVE" </dev/null 2>/dev/null)
fail=0
row() { printf '%s\n' "$FRAME" | grep "^  $1 " | head -1; }
check_rate() {
    task=$1 expected=$2
    got=$(row "$task" | awk '{print $6}')
    [ "$got" = "$expected" ] || { echo "FAIL $task: expected rate $expected, got '$got'"; fail=1; }
}
echo "=== T942 DONE rate join regression ==="
check_rate T894 71.2/s
check_rate T916 26.5/s
check_rate T924 10.9/s
check_rate T938 89.1/s
if printf '%s\n' "$FRAME" | grep -Eq '([0-9][0-9][0-9][0-9]+\.[0-9]+/s|[1-9][0-9]{3,}/s)'; then
    echo "FAIL: corpus contains an implausible rate above 1000/s"
    fail=1
fi

# In-flight claude has no readable transcript before finalization. It must
# remain unknown, but the reason must identify why rather than look like a
# broken meter. The same surface is exercised with a real process argv.
python3 - "$STORE" <<'PY'
import json, sys
a=json.load(open(sys.argv[1]))
a["T949"] = {"status":"in_progress", "agent":"claude-haiku-4-5-20251001",
             "model":"claude-haiku-4-5-20251001", "bundle":"untracked/T949-bundle.md",
             "set":"A", "holds":[], "needs":[], "caps":[], "added":"2026-08-20T00:00:00Z",
             "claimed":"2026-08-25T00:00:00Z", "done":None, "dispatched":None,
             "dispatched_to":None, "note":None, "verdict":None, "verdict_note":None,
             "acceptance":None, "skip_acceptance_reason":None, "claim_count":1}
json.dump(a, open(sys.argv[1], "w"))
PY
printf '<!--managent -->\n# T949 — claude in-flight fixture\n\nBody.\n' > "$WORK/untracked/T949-bundle.md"
rm -f "$WORK/docs/infra/managent/store-census.json"
bash -c "cd '$WORK' && exec -a 'claude --model claude-haiku-4-5-20251001 Follow untracked/T949-bundle.md' sleep 30" &
DUMMY=$!
sleep 1
FRAME_LIVE=$(cd "$WORK" && MANAGENT_STORE="$STORE" FLEET_COLS=200 sh "$LIVE" </dev/null 2>/dev/null)
kill "$DUMMY" 2>/dev/null; wait "$DUMMY" 2>/dev/null; DUMMY=""
if ! printf '%s\n' "$FRAME_LIVE" | grep -q 'UNKNOWN(claude, no in-flight transcript)'; then
    echo "FAIL T949: missing explicit claude no-transcript reason"
    printf '%s\n' "$FRAME_LIVE" | grep T949 || true
    fail=1
fi

if [ "$fail" = 1 ]; then
    echo "=== T942 regression: FAIL ==="
    exit 1
fi
echo "=== T942 regression: PASS ==="
