#!/usr/bin/env python3
"""Unit tests for tools/runner (T791 — deepseek-v4-pro/T791).

Half B of T791: bottom-up tests for the functions Half A kept.  Each test
names what the function SHOULD do — the intent, not the current behaviour.
Tests that only restate current behaviour are labelled CHARACTERIZATION;
tests that encode a SHOULD the code does not yet meet are marked
``@unittest.expectedFailure`` with the owning row id in the name/comment, so
the suite stays green while the defect stays visible.

Red arms (recorded defects, owned by other rows — not this row's failures):
  * test_select_host_guard_victim_kills_nothing_when_no_member_covers_shortfall  — owner T785 (S08)

T801 closed the former `test_model_from_argv_canonicalizes_serving_tag` red arm
(owner T751): _model_from_argv now canonicalizes a serving tag at write time.

Stdlib only: unittest, tempfile, no network, no subprocess, no writes outside
a tempfile directory.

Note on loading: tools/runner is extensionless, so the shared
tests/unit/_load.py (which calls importlib.util.spec_from_file_location)
returns None for it — the "loads extensionless modules" claim is a harness
gap, recorded in findings/T791-unit-tests.json, not papered over here.  This
file loads the module with an explicit SourceFileLoader and puts tools/ on
sys.path so the runner's own ``import directive_policy`` resolves.
"""
import importlib.util
import json
import os
import sys
import tempfile
import time
import unittest
from importlib.machinery import SourceFileLoader

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
TOOLS = os.path.join(REPO, "tools")

# tools/ is on sys.path[0] when the runner runs as a script; when loaded from
# a test it is not, and `import directive_policy` at the top of tools/runner
# needs it.
if TOOLS not in sys.path:
    sys.path.insert(0, TOOLS)


def _load_runner():
    path = os.path.join(TOOLS, "runner")
    loader = SourceFileLoader("runner", path)
    spec = importlib.util.spec_from_loader("runner", loader)
    mod = importlib.util.module_from_spec(spec)
    sys.modules["runner"] = mod
    loader.exec_module(mod)
    return mod


RUNNER = _load_runner()


class _env:
    """Context manager: set/remove exactly the given environment keys, then
    restore them on exit (a value of None removes the key)."""

    def __init__(self, **overrides):
        self.overrides = overrides
        self.saved = {}

    def __enter__(self):
        for k, v in self.overrides.items():
            self.saved[k] = os.environ.get(k)
            if v is None:
                os.environ.pop(k, None)
            else:
                os.environ[k] = v
        return self

    def __exit__(self, *exc):
        for k, v in self.saved.items():
            if v is None:
                os.environ.pop(k, None)
            else:
                os.environ[k] = v
        return False


# ── host-memory guard (priority 1) ────────────────────────────────────────

class TestHostMemoryGuard(unittest.TestCase):
    def test_sum_mlx_tenant_bytes_sums_matching_processes(self):
        # SHOULD: sum the RSS (kB -> bytes) of every `ollama runner
        # --mlx-engine` process in a ps listing — the resident tenant's true
        # footprint (T711).
        lines = [
            "  123  5242880 ollama runner --mlx-engine --model qwen",
            "  456  1048576 some-other-process",
            "  789  2097152 ollama runner --mlx-engine --model qwen2",
        ]
        self.assertEqual(
            RUNNER._sum_mlx_tenant_bytes(lines),
            (5242880 + 2097152) * 1024,
        )

    def test_sum_mlx_tenant_bytes_skips_nonmatching_and_malformed(self):
        # SHOULD: non-matching processes and malformed RSS columns are
        # skipped, never guessed.
        lines = [
            "1 nope ollama runner --mlx-engine",
            "2 1000 not-a-match",
        ]
        self.assertEqual(RUNNER._sum_mlx_tenant_bytes(lines), 0)

    def test_declared_tenant_reservation_env_override_mb_to_bytes(self):
        # SHOULD: an explicit WEIZIGO_HOST_TENANT_RESERVATION_MB is used
        # verbatim (MB -> bytes).
        with _env(WEIZIGO_HOST_TENANT_RESERVATION_MB="2000",
                  WEIZIGO_HOST_MEM_AVAIL_MB=None):
            self.assertEqual(
                RUNNER._declared_tenant_reservation_bytes(),
                2000 * 1024 * 1024,
            )

    def test_declared_tenant_reservation_invalid_env_is_zero(self):
        # SHOULD: an unparseable reservation is 0 (never a crash, never a
        # guessed number).
        with _env(WEIZIGO_HOST_TENANT_RESERVATION_MB="not-a-number",
                  WEIZIGO_HOST_MEM_AVAIL_MB=None):
            self.assertEqual(RUNNER._declared_tenant_reservation_bytes(), 0)

    def test_declared_tenant_reservation_no_autodetect_when_reading_injected(self):
        # SHOULD: when the available reading is injected
        # (WEIZIGO_HOST_MEM_AVAIL_MB), no auto-detection runs — the test
        # owns the whole scenario and a tenant must be declared explicitly.
        with _env(WEIZIGO_HOST_TENANT_RESERVATION_MB=None,
                  WEIZIGO_HOST_MEM_AVAIL_MB="8000"):
            self.assertEqual(RUNNER._declared_tenant_reservation_bytes(), 0)

    def test_select_host_guard_victim_empty_table_returns_none(self):
        # SHOULD: nothing to kill when the group is empty.
        self.assertIsNone(RUNNER._select_host_guard_victim({}, 100))

    def test_select_host_guard_victim_returns_largest_when_it_covers_shortfall(self):
        # SHOULD: the largest member is the victim when its RSS covers the
        # shortfall (killing it actually relieves the pressure).
        poll = {
            1: 500 * 1024 * 1024,
            2: 100 * 1024 * 1024,
        }
        self.assertEqual(
            RUNNER._select_host_guard_victim(poll, 300 * 1024 * 1024),
            1,
        )

    @unittest.expectedFailure
    def test_select_host_guard_victim_kills_nothing_when_no_member_covers_shortfall(self):
        # SHOULD (owner: T785, S08): kill NOTHING when no member's RSS >= the
        # shortfall.  2026-08-23 15:19:09 killed three lanes of 251/133/129 MB
        # to relieve a 383 MB shortfall — arithmetic that cannot work.
        # Current behaviour: returns the largest member unconditionally.
        poll = {
            11: 251 * 1024 * 1024,
            22: 133 * 1024 * 1024,
            33: 129 * 1024 * 1024,
        }
        self.assertIsNone(
            RUNNER._select_host_guard_victim(poll, 383 * 1024 * 1024),
        )


# ── token parsing (priority 2) — the _capture_tokens decision path ────────

class TestTokenCapture(unittest.TestCase):
    def _capture_claude(self, stdout_text):
        return RUNNER._capture_tokens(
            argv=["claude", "-p", "--output-format", "json"],
            claude_json_lane=True,
            stdout_text=stdout_text,
            stderr_text="",
            task_identity=None,
            repo_root=None,  # degraded: no tee/ledger writes, parse still runs
            start_ts="2026-08-23T00:00:00Z",
            rc=0,
        )

    def test_claude_envelope_tokens_in_is_input_plus_cache_read(self):
        # SHOULD: tokens_in = input + cache_read; the split is recorded
        # fresh (= input) vs cache_read; tokens_out = output.
        envelope = json.dumps({
            "type": "result",
            "subtype": "success",
            "result": "hello",
            "is_error": False,
            "session_id": "sess-1",
            "usage": {
                "input_tokens": 100,
                "output_tokens": 50,
                "cache_read_input_tokens": 30,
                "cache_creation_input_tokens": 5,
                "output_tokens_details": {"thinking_tokens": 10},
            },
        })
        tok = self._capture_claude(envelope)
        self.assertEqual(tok["tokens_in"], 130)
        self.assertEqual(tok["tokens_fresh"], 100)
        self.assertEqual(tok["tokens_cache_read"], 30)
        self.assertEqual(tok["tokens_out"], 50)
        self.assertEqual(tok["source"], "claude-json-envelope")
        self.assertEqual(tok["session_id"], "sess-1")

    def test_claude_api_error_is_missing_never_zero(self):
        # SHOULD: an api-error envelope with zero usage is MISSING, never a
        # 0/0 reading.
        envelope = json.dumps({
            "type": "result",
            "is_error": True,
            "result": "",
            "usage": {
                "input_tokens": 0,
                "output_tokens": 0,
                "cache_read_input_tokens": 0,
                "cache_creation_input_tokens": 0,
            },
        })
        tok = self._capture_claude(envelope)
        self.assertIsNone(tok["tokens_in"])
        self.assertEqual(
            tok["missing_reason"],
            "claude api error (is_error=true, zero usage)",
        )

    def test_pi_session_yields_real_split(self):
        # SHOULD: a pi/ollama lane with --session reads a REAL split from the
        # per-lane session JSONL (tokens_in = input + cacheRead).
        with tempfile.TemporaryDirectory() as d:
            path = os.path.join(d, "s.jsonl")
            with open(path, "w") as fh:
                fh.write(json.dumps({"type": "session", "id": "sess-abc"}) + "\n")
                fh.write(json.dumps({
                    "type": "message",
                    "message": {
                        "role": "assistant",
                        "usage": {"input": 40, "cacheRead": 10, "output": 20},
                    },
                }) + "\n")
            tok = RUNNER._capture_tokens(
                argv=["pi", "--session", path],
                claude_json_lane=False,
                stdout_text="",
                stderr_text="",
                task_identity=None,
                repo_root=None,
                start_ts="2026-08-23T00:00:00Z",
                rc=0,
            )
            self.assertEqual(tok["tokens_in"], 50)
            self.assertEqual(tok["tokens_fresh"], 40)
            self.assertEqual(tok["tokens_cache_read"], 10)
            self.assertEqual(tok["tokens_out"], 20)
            self.assertEqual(tok["source"], "pi-session-jsonl")
            self.assertEqual(tok["session_id"], "sess-abc")

    def test_pi_session_missing_is_missing_never_zero(self):
        # SHOULD: an unreadable/missing session file is UNKNOWN with a reason,
        # never 0 and never the total.
        with tempfile.TemporaryDirectory() as d:
            absent = os.path.join(d, "absent.jsonl")
            tok = RUNNER._capture_tokens(
                argv=["pi", "--session", absent],
                claude_json_lane=False,
                stdout_text="",
                stderr_text="",
                task_identity=None,
                repo_root=None,
                start_ts="2026-08-23T00:00:00Z",
                rc=0,
            )
            self.assertIsNone(tok["tokens_in"])
            self.assertIn("unreadable", tok["missing_reason"])


# ── model label (priority 3) ──────────────────────────────────────────────

class TestModelFromArgv(unittest.TestCase):
    # T801: _model_from_argv canonicalizes at write time by resolving the
    # single source (managent).  The unit test stays hermetic (no fork) by
    # injecting the canonicalizer rules; the parity control that exercises
    # the real managent verb is tools/regression-canonicalizer-parity.sh.
    def _canon(self):
        from model_tags import normalize_rules
        return normalize_rules({
            "canonical_models": [
                "claude-opus-5", "claude-sonnet-5", "claude-fable-5",
                "claude-haiku-4-5-20251001", "deepseek-v4-pro",
                "deepseek-v4-flash", "glm-5.2", "minimax-m3", "kimi-k2.7",
                "qwen3.8:27b-mlx", "ox-alpha",
            ],
            "strip_suffix": ":cloud",
            "serving_tags": {
                "kimi-k2.7-code": "kimi-k2.7",
                "stealth/ox-alpha": "ox-alpha",
            },
        })

    def test_model_from_argv_returns_flag_value(self):
        # SHOULD: an already-canonical label passes through unchanged.
        self.assertEqual(
            RUNNER._model_from_argv(["pi", "--model", "deepseek-v4-pro"],
                                    canonicalizer=self._canon()),
            "deepseek-v4-pro",
        )

    def test_model_from_argv_none_when_absent(self):
        # SHOULD: no --model flag -> None.
        self.assertIsNone(RUNNER._model_from_argv(["pi"], canonicalizer=self._canon()))

    def test_model_from_argv_canonicalizes_serving_tag(self):
        # SHOULD (T801, closes T751): a serving tag never reaches a record;
        # canonicalize stealth/ox-alpha -> ox-alpha and kimi-code -> kimi.
        self.assertEqual(
            RUNNER._model_from_argv(["pi", "--model", "stealth/ox-alpha"],
                                    canonicalizer=self._canon()),
            "ox-alpha",
        )
        self.assertEqual(
            RUNNER._model_from_argv(["ollama", "launch", "pi",
                                     "--model", "kimi-k2.7-code:cloud"],
                                    canonicalizer=self._canon()),
            "kimi-k2.7",
        )

    def test_model_from_argv_rejects_unknown_tag(self):
        # SHOULD (T801): an unrecognized tag is rejected (None), never passed
        # through as if it were a canonical label.
        self.assertIsNone(
            RUNNER._model_from_argv(["pi", "--model", "bogus-model"],
                                    canonicalizer=self._canon()))


# ── liveness fuse (priority 4) — states measurement, never a cause ────────

class TestLivenessFuse(unittest.TestCase):
    def test_pi_session_scan_target_file_from_session_flag(self):
        # SHOULD: `--session <abs>` resolves to the exact file pi writes.
        with _env(WEIZIGO_PI_SESSIONS_DIR=None):
            self.assertEqual(
                RUNNER._pi_session_scan_target(["pi", "--session", "/tmp/x/s.jsonl"]),
                ("file", "/tmp/x/s.jsonl"),
            )

    def test_pi_session_scan_target_dir_from_env(self):
        # SHOULD: WEIZIGO_PI_SESSIONS_DIR overrides the cwd-slug dir (test hook).
        with _env(WEIZIGO_PI_SESSIONS_DIR="/tmp/sessions"):
            self.assertEqual(
                RUNNER._pi_session_scan_target(["pi"]),
                ("dir", "/tmp/sessions"),
            )

    def test_pi_session_scan_target_default_slug_dir(self):
        # SHOULD: no --session and no override -> the cwd-slug session dir.
        with _env(WEIZIGO_PI_SESSIONS_DIR=None):
            kind, path = RUNNER._pi_session_scan_target(["pi"])
            self.assertEqual(kind, "dir")
            self.assertIn(".pi/agent/sessions/", path)
            self.assertTrue(path.endswith("--"))

    def test_pi_session_sensor_desc_names_what_is_measured(self):
        # SHOULD: the sensor description names the target, never a cause.
        self.assertEqual(
            RUNNER._pi_session_sensor_desc(("file", "/tmp/x")),
            "pi session file '/tmp/x'",
        )
        self.assertEqual(
            RUNNER._pi_session_sensor_desc(("dir", "/tmp/d")),
            "pi session dir '/tmp/d'",
        )
        self.assertEqual(
            RUNNER._pi_session_sensor_desc(None),
            "no pi session sensor",
        )

    def test_pi_session_max_mtime_file_respects_spawn_epoch(self):
        # SHOULD: a pre-launch session file must never mark a hung lane alive
        # (mtime < spawn_epoch -> 0.0); a post-launch mtime is the reading.
        with tempfile.TemporaryDirectory() as d:
            path = os.path.join(d, "s.jsonl")
            with open(path, "w") as fh:
                fh.write("{}\n")
            past = time.time() - 100
            os.utime(path, (past, past))
            self.assertEqual(
                RUNNER._pi_session_max_mtime(("file", path), time.time() + 1000),
                0.0,
            )
            self.assertGreater(
                RUNNER._pi_session_max_mtime(("file", path), time.time() - 1000),
                0.0,
            )

    def test_pi_session_max_mtime_dir_max_over_spawn_epoch(self):
        # SHOULD: for a dir, only entries with mtime >= spawn_epoch count.
        with tempfile.TemporaryDirectory() as d:
            old = os.path.join(d, "old.jsonl")
            new = os.path.join(d, "new.jsonl")
            open(old, "w").close()
            open(new, "w").close()
            t_old = time.time() - 100
            t_new = time.time() - 10
            os.utime(old, (t_old, t_old))
            os.utime(new, (t_new, t_new))
            m = RUNNER._pi_session_max_mtime(("dir", d), time.time() - 50)
            self.assertAlmostEqual(m, t_new, delta=5.0)
            self.assertEqual(
                RUNNER._pi_session_max_mtime(("dir", d), time.time() + 1000),
                0.0,
            )

    def test_startup_liveness_note_states_measurement_not_cause(self):
        # SHOULD: the kill note states what was measured (no stdout bytes, the
        # session sensor reading), never a cause it did not measure
        # ("bundle never read?" was the refuted causal claim, T773).
        note = RUNNER._startup_liveness_note(600, 600.0, False, ("dir", "/tmp/sessions"))
        self.assertIn("no stdout bytes since launch", note)
        self.assertIn("sensor:", note)
        self.assertNotIn("bundle never read", note)
        self.assertNotIn("bundle", note)


# ── pure decision helpers (not in the four priorities, but decisions) ─────

class TestPureHelpers(unittest.TestCase):
    def test_prepend_releasefast_zig_build(self):
        # SHOULD: a zig build with no optimize flag gets ReleaseFast (the
        # 2026-07-29 panic was a Debug LLVM build).
        self.assertEqual(
            RUNNER.prepend_releasefast(["zig", "build"]),
            ["zig", "build", "-Doptimize=ReleaseFast"],
        )

    def test_prepend_releasefast_zig_run(self):
        # SHOULD: zig run gets -O ReleaseFast; an explicit mode is respected.
        self.assertEqual(
            RUNNER.prepend_releasefast(["zig", "run", "x.zig"]),
            ["zig", "run", "-O", "ReleaseFast", "x.zig"],
        )
        self.assertEqual(
            RUNNER.prepend_releasefast(["zig", "run", "-Doptimize=ReleaseSafe", "x.zig"]),
            ["zig", "run", "-Doptimize=ReleaseSafe", "x.zig"],
        )

    def test_prepend_releasefast_non_zig_untouched(self):
        # SHOULD: non-zig commands are untouched.
        argv = ["make", "test"]
        self.assertEqual(RUNNER.prepend_releasefast(argv), argv)

    def test_parse_cputime_formats(self):
        # SHOULD: parse the three ps CPU-time shapes to seconds.
        self.assertEqual(RUNNER._parse_cputime("1:02:03"), 3723.0)
        self.assertEqual(RUNNER._parse_cputime("2-01:00:00"), 176400.0)
        self.assertAlmostEqual(RUNNER._parse_cputime("0:00:12.34"), 12.34)
        self.assertEqual(RUNNER._parse_cputime("0"), 0.0)

    def test_format_duration_never_uses_colons(self):
        # SHOULD (operator rule 2026-08-19): a duration never contains a colon.
        self.assertEqual(RUNNER._format_duration(48), "48s")
        self.assertEqual(RUNNER._format_duration(600), "10'00")
        self.assertEqual(RUNNER._format_duration(4 * 3600 + 28 * 60), "4h28")
        self.assertNotIn(":", RUNNER._format_duration(3723))


if __name__ == "__main__":
    unittest.main(verbosity=2)
