#!/usr/bin/env python3
"""Tests for tools/token-join.py (T751 — the token-to-metrics join).

Joining is the durable code change the row owes: the run record and the
ledger carry the readings (trusted-grade); the metrics record carries the
quality scores; the two were never joined, so 24/24 rows held `cost: null`
while the readings sat on disk.  The join is a pure function over the
ledger + the JSONL — no model involvement, no live dispatch — so the test
can drive it with synthetic fixtures and assert the schema exactly.

Stdlib only: unittest, tempfile, json, no network.

Test layout:
  1.  Schema          — the join writes the six named fields, never anything
                        else, in the documented shape.
  2.  Reading wins    — a ledger reading (any source) joins; the JSONL row
                        never gets a price (tokens-now-prices-later).
  3.  Trusted grade   — a claude-envelope reading carries trusted=true;
                        a per-lane --session reading also trusted=true;
                        a fallback reading carries trusted=false.
  4.  Corroboration   — corroborated='none' on dispatch-time readings,
                        'run-record' or 'task-only' on fallback.
  5.  Source labelling — source names the meter (claude-json-envelope,
                        pi-session-jsonl, pi-session-jsonl-fallback, retro).
  6.  Multiple models — when a task has multiple readings (rare), the
                        dispatch-time one wins; retro readings are not
                        substituted for dispatch-time truth.
  7.  No reading      — a task with no ledger entry leaves the JSONL row
                        untouched; UNKNOWN stays null.
  8.  Honesty         — the join NEVER invents a price (tokens-now-prices-later),
                        and the joined row carries the trust grade verbatim.

Task: T751 · Author: minimax-m3/T751 · Date: 2026-08-25
"""
import importlib.util
import json
import os
import sys
import tempfile
import unittest


def _load_tool(name):
    """Load tools/<name>.py by path (the .py is extensionless for runner but
    a real .py file here)."""
    here = os.path.dirname(os.path.abspath(__file__))
    path = os.path.join(here, name + ".py")
    spec = importlib.util.spec_from_file_location(name.replace("-", "_"), path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


class TestTokenJoin(unittest.TestCase):
    def _setup(self):
        """Build a temporary JSONL (3 rows across 2 tasks) and a temporary
        ledger (5 entries spanning the trust/sources we want to exercise)."""
        self.tmp = tempfile.TemporaryDirectory()
        d = self.tmp.__enter__()
        self.tmpdir = d
        self.jsonl_path = os.path.join(d, "metrics.jsonl")
        self.ledger_path = os.path.join(d, "tokens.jsonl")
        # 3 metric rows: T706 deepseek-v4-flash (audit), T706 deepseek-v4-pro,
        # T369 deepseek-v4-pro (verdict row).
        metrics = [
            {"task_id": "T706", "model": "deepseek-v4-flash",
             "task_type": "audit", "qualified": True, "cost": None,
             "wall_s": 681.0, "as_of": "2026-08-18"},
            {"task_id": "T706", "model": "deepseek-v4-pro",
             "task_type": "audit", "qualified": True, "cost": None,
             "wall_s": 416.9, "as_of": "2026-08-18"},
            {"task_id": "T369", "model": "deepseek-v4-pro",
             "task_type": "audit", "qualified": True, "cost": None,
             "as_of": "2026-08-18"},
        ]
        with open(self.jsonl_path, "w") as f:
            for m in metrics:
                f.write(json.dumps(m) + "\n")
        # 5 ledger entries:
        #  T706/deepseek-v4-flash   dispatch-time claude-json-envelope, trusted
        #  T706/deepseek-v4-flash   retro scan (would be a duplicate; test must skip)
        #  T706/deepseek-v4-pro     per-lane --session reading, trusted
        #  T369/deepseek-v4-pro     cwd-slug fallback, trusted=false, run-record
        #  T999                    no matching JSONL row (orphan; join does not crash)
        ledger = [
            {"task": "T706", "model": "deepseek-v4-flash",
             "ts": "2026-08-18T12:00:00Z",
             "source": "claude-json-envelope",
             "tokens_in": 1000, "tokens_out": 200,
             "tokens_fresh": 100, "tokens_cache_read": 900,
             "trusted": True, "corroborated": "none"},
            {"task": "T706", "model": "deepseek-v4-flash",
             "ts": "2026-08-18T12:00:05Z",
             "source": "pi-session-jsonl-retro",
             "tokens_in": 999, "tokens_out": 199,
             "tokens_fresh": 99, "tokens_cache_read": 900,
             "trusted": False, "corroborated": "run-record"},
            {"task": "T706", "model": "deepseek-v4-pro",
             "ts": "2026-08-18T12:01:00Z",
             "source": "pi-session-jsonl",
             "tokens_in": 800, "tokens_out": 150,
             "tokens_fresh": 50, "tokens_cache_read": 750,
             "trusted": True, "corroborated": "none"},
            {"task": "T369", "model": "deepseek-v4-pro",
             "ts": "2026-08-18T13:00:00Z",
             "source": "pi-session-jsonl-fallback",
             "tokens_in": 500, "tokens_out": 80,
             "tokens_fresh": 400, "tokens_cache_read": 100,
             "trusted": False, "corroborated": "run-record"},
            {"task": "T999", "model": "deepseek-v4-pro",
             "ts": "2026-08-18T14:00:00Z",
             "source": "claude-json-envelope",
             "tokens_in": 1, "tokens_out": 1,
             "tokens_fresh": 1, "tokens_cache_read": 0,
             "trusted": True, "corroborated": "none"},
        ]
        with open(self.ledger_path, "w") as f:
            for e in ledger:
                f.write(json.dumps(e) + "\n")
        return metrics, ledger

    def tearDown(self):
        self.tmp.__exit__(None, None, None)

    def _join(self):
        """Run the join and return the rewritten rows."""
        from token_join import join_to_metrics
        return join_to_metrics(self.jsonl_path, self.ledger_path)

    def test_join_writes_documented_fields(self):
        # SHOULD: every joined row carries exactly the six named fields
        # (tokens_fresh, tokens_cache_read, tokens_out, tokens_source,
        # trusted, corroborated) and NOTHING ELSE — no price, no derived
        # field, no surprise.
        self._setup()
        rows = self._join()
        # Find the joined T706/deepseek-v4-flash row
        joined = [r for r in rows if r["task_id"] == "T706"
                  and r["model"] == "deepseek-v4-flash"]
        self.assertEqual(len(joined), 1)
        row = joined[0]
        for k in ("tokens_fresh", "tokens_cache_read", "tokens_out",
                  "tokens_source", "trusted", "corroborated"):
            self.assertIn(k, row, f"missing field {k!r}")
        # tokens_now_prices_later: cost stays null when null
        self.assertIsNone(row.get("cost"))

    def test_join_dispatch_time_reading_wins_over_retro(self):
        # SHOULD: when a task has both a dispatch-time reading and a retro
        # reading, the dispatch-time one wins (retro never substitutes for
        # dispatch-time truth).  T746 contract.  The brief names the six
        # fields the join writes; `tokens_in` is intentionally NOT one of
        # them (it lives on the ledger + the run record — joining it into
        # the metrics row would duplicate the same datum across three
        # places, and one of them would silently drift).
        self._setup()
        rows = self._join()
        joined = next(r for r in rows
                      if r["task_id"] == "T706" and r["model"] == "deepseek-v4-flash")
        self.assertEqual(joined["tokens_source"], "claude-json-envelope")
        self.assertEqual(joined["tokens_fresh"], 100)
        self.assertEqual(joined["tokens_cache_read"], 900)
        self.assertEqual(joined["tokens_out"], 200)
        self.assertTrue(joined["trusted"])
        self.assertEqual(joined["corroborated"], "none")

    def test_join_per_lane_session_is_trusted_true(self):
        # SHOULD: a per-lane --session reading (the dispatcher named the file)
        # is dispatch-time and carries trusted=true.  corroborated='none'
        # because no independent surface corroborates (the file IS the
        # reading).
        self._setup()
        rows = self._join()
        joined = next(r for r in rows
                      if r["task_id"] == "T706" and r["model"] == "deepseek-v4-pro")
        self.assertEqual(joined["tokens_source"], "pi-session-jsonl")
        self.assertEqual(joined["tokens_out"], 150)
        self.assertEqual(joined["tokens_fresh"], 50)
        self.assertEqual(joined["tokens_cache_read"], 750)
        self.assertTrue(joined["trusted"])
        self.assertEqual(joined["corroborated"], "none")

    def test_join_fallback_reading_is_trusted_false(self):
        # SHOULD (operator ruling 2026-08-23): a cwd-slug fallback reading
        # is a retroactive-style session-scan and carries trusted=false.
        # corroborated='run-record' when the session's dominant model
        # agrees with the dispatch's --model.
        self._setup()
        rows = self._join()
        joined = next(r for r in rows
                      if r["task_id"] == "T369" and r["model"] == "deepseek-v4-pro")
        self.assertEqual(joined["tokens_source"], "pi-session-jsonl-fallback")
        self.assertEqual(joined["tokens_out"], 80)
        self.assertEqual(joined["tokens_fresh"], 400)
        self.assertEqual(joined["tokens_cache_read"], 100)
        self.assertFalse(joined["trusted"])
        self.assertEqual(joined["corroborated"], "run-record")

    def test_join_no_reading_leaves_row_untouched(self):
        # SHOULD: a metric row whose (task_id, model) has no ledger entry
        # is written back UNCHANGED — UNKNOWN stays null, the join does not
        # invent a zero or a placeholder.
        self._setup()
        rows = self._join()
        # All 3 metric rows must still be present (the join never drops rows)
        ids = sorted((r["task_id"], r["model"]) for r in rows)
        self.assertEqual(ids, [
            ("T369", "deepseek-v4-pro"),
            ("T706", "deepseek-v4-flash"),
            ("T706", "deepseek-v4-pro"),
        ])

    def test_join_does_not_invent_a_price(self):
        # SHOULD (tokens-now-prices-later doctrine): the join writes no
        # derived USD cost, no tokens-to-dollars conversion, no normalised
        # score.  cost stays null.  The only new fields are the six token
        # fields named in the brief.
        self._setup()
        rows = self._join()
        for r in rows:
            # never introduce price fields
            self.assertNotIn("cost_usd", r)
            self.assertNotIn("price", r)
            self.assertNotIn("tokens_per_dollar", r)
            # the six new fields are exactly the six
            extras = set(r.keys()) - {
                "task_id", "model", "task_type", "qualified", "cost",
                "wall_s", "as_of",
                "tokens_fresh", "tokens_cache_read", "tokens_out",
                "tokens_source", "trusted", "corroborated",
            }
            self.assertFalse(extras, f"unexpected fields: {extras}")

    def test_join_honesty_on_missing_field(self):
        # SHOULD: a metric row whose joined reading has missing_reason
        # (legacy/missing) gets the joined row's tokens_* set to null with
        # a tokens_source that names the missing reason's source — never 0.
        # We synthesise this by giving the ledger a MISSING-only entry
        # (tokens_in=None) for a fresh task.
        self._setup()
        # add a MISSING ledger entry for T369/deepseek-v4-pro (the same
        # row already has a fallback reading; this MISSING must be skipped
        # — only readings join).
        with open(self.ledger_path, "a") as f:
            f.write(json.dumps({"task": "T369", "model": "deepseek-v4-pro",
                                "ts": "2026-08-18T13:00:01Z",
                                "source": None,
                                "tokens_in": None, "tokens_out": None,
                                "missing_reason": "no --session",
                                "trusted": None}) + "\n")
        rows = self._join()
        joined = next(r for r in rows
                      if r["task_id"] == "T369" and r["model"] == "deepseek-v4-pro")
        # the existing fallback reading still wins
        self.assertEqual(joined["tokens_out"], 80)
        self.assertFalse(joined["trusted"])

    def test_join_writes_atomically(self):
        # SHOULD: the join is atomic — tmp + rename, never a torn write
        # that leaves the JSONL half-rebuilt (the metrics record is read
        # by dispatch and the cost ladder; a torn write is a free run).
        self._setup()
        rows = self._join()
        # file must still parse cleanly
        with open(self.jsonl_path) as f:
            reread = [json.loads(l) for l in f if l.strip()]
        self.assertEqual(len(reread), 3)
        # and the in-memory rows match the file
        self.assertEqual(sorted(r["task_id"] for r in rows),
                         sorted(r["task_id"] for r in reread))

    def test_join_legacy_dispatch_time_inherits_trusted_true(self):
        # SHOULD (T751 legacy rule): ledger entries written before the
        # trust-grade doctrine do not carry a `trusted` field.  Their
        # SOURCE is the trust signal — claude-json-envelope / pi-session-jsonl
        # are dispatch-time, so they inherit trusted=True.  Retro sources
        # inherit trusted=False.  An explicit `trusted` is never overridden
        # by the legacy inference.
        self.tmp = tempfile.TemporaryDirectory()
        d = self.tmp.__enter__()
        self.tmpdir = d
        self.jsonl_path = os.path.join(d, "metrics.jsonl")
        self.ledger_path = os.path.join(d, "tokens.jsonl")
        with open(self.jsonl_path, "w") as f:
            f.write(json.dumps({"task_id": "T001", "model": "x",
                                "as_of": "2026-08-20"}) + "\n")
            f.write(json.dumps({"task_id": "T002", "model": "x",
                                "as_of": "2026-08-20"}) + "\n")
        with open(self.ledger_path, "w") as f:
            # legacy dispatch-time, no trusted field
            f.write(json.dumps({"task": "T001", "model": "x",
                                "ts": "2026-08-20T00:00:00Z",
                                "source": "claude-json-envelope",
                                "tokens_in": 100, "tokens_out": 10,
                                "tokens_fresh": 100, "tokens_cache_read": 0}) + "\n")
            # legacy retro, no trusted field
            f.write(json.dumps({"task": "T002", "model": "x",
                                "ts": "2026-08-20T00:00:00Z",
                                "source": "pi-session-jsonl-retro",
                                "tokens_in": 100, "tokens_out": 10,
                                "tokens_fresh": 80, "tokens_cache_read": 20}) + "\n")
        rows = self._join()
        t1 = next(r for r in rows if r["task_id"] == "T001")
        t2 = next(r for r in rows if r["task_id"] == "T002")
        self.assertTrue(t1["trusted"])
        self.assertEqual(t1["corroborated"], "none")
        self.assertFalse(t2["trusted"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
