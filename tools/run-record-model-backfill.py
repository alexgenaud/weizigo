#!/usr/bin/env python3
"""T751 — backfill `model` on run records that predate the canonicalizer.

The runner's `_model_from_argv` did not always resolve the model: before
T801 (2026-08-23), the runner wrote `model: null` on dispatch rows whose
`--model` flag held a serving tag (stealth/ox-alpha, kimi-k2.7-code:cloud)
or whose `--model` value was non-canonical (the 2026-08-22 era).  T801
landed the canonicalizer and the runner now resolves the canonical label
at write time.

This script backfills the records left behind by the older runner, in
place, by re-extracting the model from each record's stored `command`
field via the same `_model_from_argv` the runner uses today.  Idempotent:
a record that already carries a non-null `model` is left alone.

DISCIPLINE.  The ledger is append-only; run records in untracked/runs are
rewriteable (run-kind: dispatch records).  The same atomic-write rule
applies (tmp + os.replace): a torn rewrite would leave the row-store
half-built and `managent reap` would misread its own data.  Skipped when
record is a nested run (the nested namespace is the runner's own
sub-runs; the command argv there is a `zig build`, not a dispatch).

DISPATCH-TIME TRUTH.  A record that already has a non-null model is
left alone — the canonicalizer may resolve differently today, but the
runner that wrote the record is the one that chose that label, and
overwriting is an attribution claim, not a fix.

Usage:
  tools/run-record-model-backfill.py           # dry-run
  tools/run-record-model-backfill.py --commit  # rewrite in place
  tools/run-record-model-backfill.py --json    # machine-readable summary

Task: T751 · Author: minimax-m3/T751 · Date: 2026-08-25
"""
import argparse
import json
import os
import sys
from collections import Counter

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def _load_runner():
    """Load tools/runner via SourceFileLoader — extensionless, so the
    spec_from_file_location helper returns None (test_runner.py notes the
    same harness gap; we use the same workaround)."""
    from importlib.machinery import SourceFileLoader
    loader = SourceFileLoader("runner", os.path.join(HERE, "tools", "runner"))
    spec = __import__("importlib.util").util.spec_from_loader("runner", loader)
    mod = __import__("importlib.util").util.module_from_spec(spec)
    sys.modules.setdefault("runner", mod)
    loader.exec_module(mod)
    return mod


def _load_canonicalizer():
    """The same rules dict tools/regression-token-capture.sh uses — mirrors
    src/managent/main.zig canonicalizeModelTag (the single source)."""
    sys.path.insert(0, os.path.join(HERE, "tools"))
    from model_tags import normalize_rules
    return normalize_rules({
        "canonical_models": [
            "claude-opus-5", "claude-sonnet-5", "claude-fable-5",
            "claude-haiku-4-5-20251001", "deepseek-v4-pro",
            "deepseek-v4-flash", "glm-5.2", "minimax-m3", "kimi-k2.7",
            "qwen3.8:27b-mlx", "oxalpha", "gemini-3.7-flash",
        ],
        "strip_suffix": ":cloud",
        "serving_tags": {
            "kimi-k2.7-code": "kimi-k2.7",
            "stealth/ox-alpha": "oxalpha",
            "google/gemini-3.7-flash": "gemini-3.7-flash",
        },
    })


def _is_dispatch(rec):
    """A dispatch record (run_kind=='dispatch' or absent — pre-T895 the
    field did not exist) is backfillable.  A nested run record keeps
    its own namespace and is never touched (the nested command is
    `zig build` etc., not a model dispatch)."""
    return rec.get("run_kind") != "nested"


def _is_agent_dispatch(rec):
    """A record describing a model dispatch (pi/claude/ollama argv).  The
    only records where `model: null` is a defect — non-agent commands
    correctly carry null (regression scripts, build commands, sleeps)."""
    cmd = rec.get("command") or ""
    argv0 = cmd.split()[0] if cmd.split() else ""
    return argv0 in ("pi", "claude", "ollama")


def plan(runner, runs_dir, canon):
    """Walk every record; return (writes, skipped, conflicts) where each
    is a list of (path, record, new_model_or_none)."""
    writes, skipped, conflicts = [], [], []
    if not os.path.isdir(runs_dir):
        return writes, skipped, conflicts
    for fn in sorted(os.listdir(runs_dir)):
        if not fn.endswith(".json"):
            continue
        path = os.path.join(runs_dir, fn)
        try:
            with open(path) as f:
                rec = json.load(f)
        except (OSError, ValueError):
            continue
        if not isinstance(rec, dict):
            continue
        if not _is_dispatch(rec):
            continue
        if not _is_agent_dispatch(rec):
            continue
        if rec.get("model") is not None:
            continue
        cmd = rec.get("command") or ""
        argv = cmd.split()
        try:
            new_model = runner._model_from_argv(argv, canonicalizer=canon)
        except Exception:
            new_model = None
        if new_model is None:
            skipped.append((path, rec, None))
            continue
        writes.append((path, rec, new_model))
    return writes, skipped, conflicts


def apply(writes):
    """Atomic per-file rewrite (each file is a record; rewriting one is
    safe even if a reaper is mid-read on another).  tmp + os.replace."""
    for path, _rec, new_model in writes:
        try:
            with open(path) as f:
                rec = json.load(f)
        except (OSError, ValueError):
            continue
        if rec.get("model") is not None:
            continue
        rec["model"] = new_model
        tmp = path + ".tmp"
        try:
            with open(tmp, "w") as f:
                json.dump(rec, f, sort_keys=True)
                f.write("\n")
            os.replace(tmp, path)
        except OSError:
            try:
                if os.path.exists(tmp):
                    os.unlink(tmp)
            except OSError:
                pass


def main(argv):
    ap = argparse.ArgumentParser(prog="run-record-model-backfill.py")
    ap.add_argument("--commit", action="store_true",
                    help="rewrite the records (default: dry run)")
    ap.add_argument("--runs-dir", default=os.path.join(HERE, "untracked", "runs"))
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args(argv)

    runner = _load_runner()
    canon = _load_canonicalizer()
    writes, skipped, _conflicts = plan(runner, args.runs_dir, canon)

    by_model = Counter(w[2] for w in writes)
    summary = {
        "would_write": len(writes),
        "skipped_no_canonical": len(skipped),
        "by_new_model": dict(by_model),
        "commit": args.commit,
    }
    if args.json:
        print(json.dumps(summary, sort_keys=True))

    if args.commit:
        apply(writes)
        print(f"rewrite: wrote {len(writes)} record(s), "
              f"skipped {len(skipped)} (no canonical match)")
    else:
        print(f"would write: {len(writes)} record(s)")
        for m, n in by_model.most_common():
            print(f"  {m}: {n}")
        print(f"skipped (no canonical match): {len(skipped)}")
        print("dry run — nothing written.  --commit to apply.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
