"""Unit tests for tools/token-capture.py (T794).

What each tested function SHOULD do (intent, not current behaviour):

  canon_tag             map EVERY serving tag to its canonical label, exactly
                        as src/managent/main.zig canonicalizeModelTag does;
                        the arm table is driven from docs/infra/model-registry.md
                        and the two copies are asserted to agree (parity).
  slug                  map a cwd to the pi harness session-directory slug
                        exactly (leading '/' stripped, '/' -> '-', wrapped '--').
  extract_task          attribute a session to its task from
                        `Follow untracked/T<id>` first, then `claim T<id>`;
                        a bare `T<id>` mention NEVER matches, and prose citing
                        ANOTHER row's bundle must not steal the session.
  parse_claude_envelope return (text, normalized usage, meta); an is_error
                        envelope with zero usage is MISSING (None), never a
                        0/0 reading; unparseable output degrades to
                        passthrough, never silence.
  deepseek_rate_band    'peak'/'off-peak' per the recorded UTC rule (D044);
                        None when the timestamp will not parse -- never a
                        guessed band.  NOTE (flagged, not decided): the band
                        may be retired under the 2026-08-23 budget-meter
                        ruling; these tests pin it AS IT STANDS.
  read_pi_session       sum one pi session JSONL as the lane meter; distinct
                        failure reasons; ok=False is UNKNOWN, never 0.
  merge_models/load_ledger  the dispatch-time ledger wins per label;
                        explicit MISSING records survive with their reason;
                        corrupt ledger lines are skipped AND counted.

Stdlib only; tempfile for any file touch.  Loaded through tests/unit/_load.py
because the module name is hyphenated.
"""
import json
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from _load import load, REPO  # noqa: E402

tc = load("tools/token-capture.py")

ZIG_SRC = os.path.join(REPO, "src", "managent", "main.zig")
REGISTRY = os.path.join(REPO, "docs", "infra", "model-registry.md")


# ── canon_tag ──────────────────────────────────────────────────────────────

class TestCanonTag(unittest.TestCase):
    """SHOULD: every serving tag -> canonical label, matching managent."""

    def test_strips_cloud_suffix(self):
        self.assertEqual(tc.canon_tag("glm-5.2:cloud"), "glm-5.2")
        self.assertEqual(tc.canon_tag("minimax-m3:cloud"), "minimax-m3")

    def test_kimi_code_variant(self):
        self.assertEqual(tc.canon_tag("kimi-k2.7-code"), "kimi-k2.7")
        # both transforms compose (the tag actually dispatched today)
        self.assertEqual(tc.canon_tag("kimi-k2.7-code:cloud"), "kimi-k2.7")

    def test_stealth_serving_tag_never_reaches_a_record(self):
        # the T276/T746 rule: the serving tag must not survive into a record
        self.assertEqual(tc.canon_tag("stealth/ox-alpha"), "ox-alpha")

    def test_canonical_passthrough(self):
        for m in tc.CANONICAL_MODELS:
            self.assertEqual(tc.canon_tag(m), m)

    def test_none_and_empty_and_whitespace(self):
        self.assertEqual(tc.canon_tag(None), "")
        self.assertEqual(tc.canon_tag(""), "")
        self.assertEqual(tc.canon_tag("  ox-alpha \n"), "ox-alpha")

    def test_arm_table_is_registry_driven(self):
        """Every serving-tag arm must be traceable to the registry doc."""
        with open(REGISTRY) as f:
            reg = f.read()
        for serving, canonical in tc.SERVING_TAG_MAP.items():
            self.assertIn(serving, reg,
                          "%s in SERVING_TAG_MAP is not in model-registry.md" % serving)
            self.assertIn(canonical, tc.CANONICAL_MODELS,
                          "arm %s -> %s lands off the canonical set" % (serving, canonical))

    def test_parity_with_zig_canonicalizer(self):
        """The Python copy and src/managent/main.zig MUST agree (T794).

        Four places canonicalize tags; only tools/model-profiles.py had a
        parity control.  This is token-capture's.
        """
        with open(ZIG_SRC) as f:
            zig = f.read()
        start = zig.index("const canonical_models = [_][]const u8{")
        end = zig.index("};", start)
        block = zig[start:end]
        zig_list = [ln.split('"')[1] for ln in block.splitlines() if '"' in ln]
        self.assertEqual(zig_list, list(tc.CANONICAL_MODELS),
                         "canonical label lists diverge between Python and Zig")


# ── slug ───────────────────────────────────────────────────────────────────

class TestSlug(unittest.TestCase):
    """SHOULD: cwd -> the pi harness session-directory name exactly."""

    def test_repo_root(self):
        self.assertEqual(
            tc.slug("/Users/alex/Project/Zig/weizigo"),
            "--Users-alex-Project-Zig-weizigo--")

    def test_relative_path_gets_the_same_wrap(self):
        self.assertEqual(tc.slug("foo/bar"), "--foo-bar--")

    def test_trailing_slash_follows_the_documented_transform(self):
        # '/' -> '-' with no special case for a trailing one — identical in
        # tools/runner._pi_session_scan_target's duplicate of this rule
        # (cwds never carry trailing slashes in practice; the two copies
        # must stay character-identical).
        self.assertEqual(tc.slug("/tmp/x/"), "--tmp-x---")


# ── extract_task ───────────────────────────────────────────────────────────

class TestExtractTask(unittest.TestCase):
    """SHOULD: attribute via `Follow untracked/T<id>`, fall back to
    `claim T<id>`; never match a bare T<id>; another row's bundle cited in
    prose must not steal the session."""

    def test_canonical_follow_line(self):
        self.assertEqual(tc.extract_task("Follow untracked/T521-tokens.md"),
                         "T521")

    def test_claim_fallback(self):
        self.assertEqual(tc.extract_task("FIRST: bin/managent claim T456 --agent x"),
                         "T456")

    def test_bare_mention_not_matched(self):
        self.assertIsNone(
            tc.extract_task("T789 wires this into the gate later, said the brief."))

    def test_empty_text(self):
        self.assertIsNone(tc.extract_task(""))

    def test_brief_citing_another_rows_bundle(self):
        """A brief that cites another row's bundle BEFORE its own Follow line
        must attribute to ITS OWN task, not the citation (red-first defect,
        fixed in T794)."""
        prompt = ("Context: untracked/T700-old-bundle.md has background.\n"
                  "Follow untracked/T794-token_capture.md\n"
                  "FIRST: bin/managent claim T794 --agent ox-alpha")
        self.assertEqual(tc.extract_task(prompt), "T794")


# ── parse_claude_envelope ──────────────────────────────────────────────────

GOOD_ENV = {
    "type": "result", "subtype": "success",
    "is_error": False,
    "result": "the answer",
    "session_id": "abc-123",
    "usage": {
        "input_tokens": 10, "output_tokens": 20,
        "cache_read_input_tokens": 30, "cache_creation_input_tokens": 40,
        "output_tokens_details": {"thinking_tokens": 5},
    },
}


class TestParseClaudeEnvelope(unittest.TestCase):
    """SHOULD: (text, normalized usage, meta); error+zero-usage is MISSING."""

    def test_good_envelope(self):
        text, usage, meta = tc.parse_claude_envelope(json.dumps(GOOD_ENV))
        self.assertEqual(text, "the answer")
        self.assertEqual(usage, {"input": 10, "output": 20, "cache_read": 30,
                                 "cache_write": 40, "reasoning": 5,
                                 "total": 100})
        self.assertFalse(meta["is_error"])
        self.assertTrue(meta["session_id_present"])
        self.assertEqual(meta["session_id"], "abc-123")

    def test_error_envelope_without_usage_is_missing_not_zero(self):
        env = {"type": "result", "subtype": "error_during_execution",
               "is_error": True, "result": ""}
        text, usage, meta = tc.parse_claude_envelope(json.dumps(env))
        self.assertTrue(meta["is_error"])
        self.assertIsNone(usage)

    def test_error_envelope_with_zero_usage_is_missing_not_0_over_0(self):
        """An is_error envelope whose usage dict is present but all-zero is a
        MISSING, never a legitimate-looking 0/0 reading (red-first defect,
        fixed in T794)."""
        env = dict(GOOD_ENV, is_error=True, result="",
                   usage={"input_tokens": 0, "output_tokens": 0,
                          "cache_read_input_tokens": 0,
                          "cache_creation_input_tokens": 0})
        _, usage, meta = tc.parse_claude_envelope(json.dumps(env))
        self.assertTrue(meta["is_error"])
        self.assertIsNone(usage)

    def test_truncated_json_degrades_to_passthrough(self):
        raw = '{"type": "result", "result": "he'
        text, usage, meta = tc.parse_claude_envelope(raw)
        self.assertEqual(text, raw)
        self.assertIsNone(usage)
        self.assertFalse(meta["session_id_present"])
        self.assertIsNone(meta["terminal_reason"])

    def test_non_json_passthrough(self):
        text, usage, meta = tc.parse_claude_envelope("hello world")
        self.assertEqual(text, "hello world")
        self.assertIsNone(usage)
        self.assertFalse(meta["is_error"])

    def test_jsonl_stream_last_object_wins(self):
        lines = [
            json.dumps({"type": "assistant", "result": "partial"}),
            json.dumps({"type": "system"}),
            json.dumps(GOOD_ENV),
        ]
        text, usage, meta = tc.parse_claude_envelope("\n".join(lines))
        self.assertEqual(text, "the answer")
        self.assertEqual(usage["total"], 100)
        self.assertEqual(meta["session_id"], "abc-123")

    def test_empty_input(self):
        self.assertEqual(tc.parse_claude_envelope(""), ("", None, tc._empty_meta()))

    def test_non_string_session_handle_degrades_to_null(self):
        env = dict(GOOD_ENV, session_id=42)
        _, _, meta = tc.parse_claude_envelope(json.dumps(env))
        self.assertIsNone(meta["session_id"])
        self.assertFalse(meta["session_id_present"])


# ── deepseek_rate_band (D044) ──────────────────────────────────────────────

class TestDeepseekRateBand(unittest.TestCase):
    """SHOULD (D044): peak 01:00-04:00 and 06:00-10:00 UTC; every other hour
    half; UTC Fri 16:00 -> Sun 16:00 half regardless of hour.  Unparseable
    timestamp -> None, never a guessed band.

    FLAGGED, NOT DECIDED: the 2026-08-23 budget-meter ruling may retire this
    band; these tests pin the behaviour AS IT STANDS.  Owner of that question:
    the Orchestrator (measurement-methodology.md §1b).
    """

    # Wednesdays so no weekend override interferes.
    def peak(self, hhmm="02:00"):
        return "2026-08-19T%s:00Z" % hhmm      # Wednesday

    def off(self, hhmm="05:00"):
        return "2026-08-19T%s:00Z" % hhmm      # Wednesday

    def test_peak_windows(self):
        for h in ("01", "02", "03", "06", "07", "08", "09"):
            self.assertEqual(tc.deepseek_rate_band(self.peak(h + ":30")), "peak", h)

    def test_offpeak_weekday_hours(self):
        for h in ("00", "04", "05", "10", "16", "23"):
            self.assertEqual(tc.deepseek_rate_band(self.off(h + ":30")),
                             "off-peak", h)

    def test_boundary_edges_are_exact(self):
        # 00:59 off-peak, 01:00 peak; 04:00 off-peak again; 10:00 off-peak
        self.assertEqual(tc.deepseek_rate_band("2026-08-19T00:59Z"), "off-peak")
        self.assertEqual(tc.deepseek_rate_band("2026-08-19T01:00Z"), "peak")
        self.assertEqual(tc.deepseek_rate_band("2026-08-19T04:00Z"), "off-peak")
        self.assertEqual(tc.deepseek_rate_band("2026-08-19T06:00Z"), "peak")
        self.assertEqual(tc.deepseek_rate_band("2026-08-19T10:00Z"), "off-peak")

    def test_weekend_override_start_fri_16_utc(self):
        fri = "2026-08-21T%s:00Z"
        # Fri 15:xx is still weekday-rule (off-peak at 15 anyway); the
        # discriminating case: Fri 07:00 would be PEAK on a weekday but the
        # override started at 16:00 the PREVIOUS... no — Friday 07:00 is
        # BEFORE Fri 16:00, so weekday rule applies and it is peak.
        self.assertEqual(tc.deepseek_rate_band(fri % "07"), "peak")
        # Fri 16:00 sharp starts the override.
        self.assertEqual(tc.deepseek_rate_band(fri % "16"), "off-peak")
        self.assertEqual(tc.deepseek_rate_band(fri % "17"), "off-peak")

    def test_weekend_all_hours_offpeak(self):
        sat = "2026-08-22T%s:00Z"
        sun = "2026-08-23T%s:00Z"
        self.assertEqual(tc.deepseek_rate_band(sat % "02"), "off-peak")  # would be peak on a weekday
        self.assertEqual(tc.deepseek_rate_band(sun % "07"), "off-peak")  # would be peak on a weekday
        self.assertEqual(tc.deepseek_rate_band(sun % "15"), "off-peak")

    def test_override_ends_sun_16_utc(self):
        # Sun 15:59 still override; Sun 16:00+ back to weekday rule.
        self.assertEqual(tc.deepseek_rate_band("2026-08-23T15:59Z"), "off-peak")
        self.assertEqual(tc.deepseek_rate_band("2026-08-24T01:00Z"), "peak")  # Mon

    def test_timezone_offset_normalized_to_utc(self):
        # 03:00 +09:00 == 18:00 UTC Friday -> override off-peak
        self.assertEqual(tc.deepseek_rate_band("2026-08-21T03:00:00+09:00"),
                         "off-peak")
        # 18:00 Fri +09:00 == 09:00 UTC Friday -> weekday peak
        self.assertEqual(tc.deepseek_rate_band("2026-08-21T18:00:00+09:00"),
                         "peak")

    def test_malformed_or_missing_stamp_is_none(self):
        self.assertIsNone(tc.deepseek_rate_band("not-a-stamp"))
        self.assertIsNone(tc.deepseek_rate_band(""))
        self.assertIsNone(tc.deepseek_rate_band(None))


# ── read_pi_session ────────────────────────────────────────────────────────

def _session_jsonl(header=True, turns=1, compaction=False):
    lines = []
    if header:
        lines.append(json.dumps({"type": "session", "id": "sess-1",
                                 "timestamp": "2026-08-20T10:00:00Z",
                                 "cwd": "/repo"}))
    for i in range(turns):
        lines.append(json.dumps({
            "type": "message",
            "message": {"role": "assistant", "model": "deepseek-v4-flash",
                        "provider": "deepseek",
                        "content": [{"type": "text", "text": "hi"}],
                        "usage": {"input": 10, "output": 2,
                                  "cacheRead": 5, "cacheWrite": 1,
                                  "reasoning": 0, "totalTokens": 18}}}))
    if compaction:
        lines.append(json.dumps({"type": "compaction",
                                 "usage": {"input": 7, "output": 3,
                                           "totalTokens": 10}}))
    return "\n".join(lines) + "\n"


class TestReadPiSession(unittest.TestCase):
    """SHOULD: one pi session JSONL = the lane meter; ok=False reasons are
    DISTINCT and mean UNKNOWN, never 0."""

    def setUp(self):
        self.dir = tempfile.mkdtemp(prefix="t794-pi-")

    def _path(self, content):
        p = os.path.join(self.dir, "s.jsonl")
        with open(p, "w") as f:
            f.write(content)
        return p

    def test_ok_path_sums_turns_and_compaction(self):
        r = tc.read_pi_session(self._path(_session_jsonl(turns=2, compaction=True)))
        self.assertTrue(r["ok"])
        self.assertEqual(r["turns"], 2)
        self.assertEqual(r["input"], 27)     # 10+10 turns + 7 compaction
        self.assertEqual(r["output"], 7)     # 2+2 + 3
        self.assertEqual(r["cache_read"], 10)
        self.assertEqual(r["session_id"], "sess-1")

    def test_missing_file_reason(self):
        r = tc.read_pi_session(os.path.join(self.dir, "absent.jsonl"))
        self.assertFalse(r["ok"])
        self.assertIn("missing", r["reason"])

    def test_no_header_reason(self):
        r = tc.read_pi_session(self._path(_session_jsonl(header=False)))
        self.assertFalse(r["ok"])
        self.assertIn("no session header", r["reason"])

    def test_no_usage_bearing_turns_reason(self):
        p = os.path.join(self.dir, "s.jsonl")
        with open(p, "w") as f:
            f.write(json.dumps({"type": "session", "id": "sess-1"}) + "\n")
        r = tc.read_pi_session(p)
        self.assertFalse(r["ok"])
        self.assertIn("no usage-bearing turns", r["reason"])


# ── merge_models / load_ledger / _ledger_reading ───────────────────────────

class TestLedgerJoin(unittest.TestCase):
    """SHOULD: capture-time ledger wins per label; explicit MISSING records
    survive with their reason; corrupt lines are skipped AND counted."""

    def test_ledger_reading_predicate(self):
        self.assertTrue(tc._ledger_reading({"tokens_in": 5}))
        self.assertTrue(tc._ledger_reading({"tokens_out": 0}))
        self.assertFalse(tc._ledger_reading({"tokens_in": None, "tokens_out": None}))

    def test_ledger_wins_and_fallback_fills(self):
        sessions = {"deepseek-v4-flash": {"sessions": 1, "turns": 4,
                                          "tokens": dict.fromkeys(tc.TOKEN_KEYS, 1),
                                          "tokens_in": 2, "tokens_out": 2}}
        entries = [
            {"model": "deepseek-v4-flash", "task": "T1", "ts": "2026-08-20",
             "tokens_in": 100, "tokens_out": 50},
            {"model": "kimi-k2.7-code:cloud", "task": "T2", "ts": "2026-08-20",
             "tokens_in": 7, "tokens_out": 3},
        ]
        models, missing = tc.merge_models(sessions, entries)
        self.assertEqual(models["deepseek-v4-flash"]["tokens_in"], 100)
        self.assertEqual(models["deepseek-v4-flash"]["tokens_out"], 50)
        # serving tag canonicalized on the way into the models map
        self.assertIn("kimi-k2.7", models)
        self.assertNotIn("kimi-k2.7-code:cloud", models)
        self.assertEqual(models["kimi-k2.7"]["tokens_in"], 7)

    def test_missing_records_survive_with_reason(self):
        entries = [{"model": "claude-opus-5", "task": "T9", "provider": "claude",
                    "ts": "2026-08-20", "tokens_in": None, "tokens_out": None,
                    "missing_reason": "lane died before envelope"}]
        models, missing = tc.merge_models({}, entries)
        self.assertEqual(missing["T9"]["missing_reason"],
                         "lane died before envelope")
        self.assertEqual(missing["T9"]["model"], "claude-opus-5")

    def _root(self, lines):
        d = tempfile.mkdtemp(prefix="t794-ledger-")
        tokdir = tc.tokens_dir(d)
        os.makedirs(tokdir)
        with open(tc.ledger_path(d), "w") as f:
            f.write("\n".join(lines) + "\n")
        return d

    def test_load_ledger_counts_bad_lines(self):
        good = json.dumps({"task": "T1", "tokens_in": 1, "tokens_out": 1})
        d = self._root([good, "{corrupt", "[]"])
        entries, bad = tc.load_ledger(d)
        self.assertEqual(bad, 2)
        self.assertEqual(len(entries), 1)

    def test_load_ledger_filters(self):
        e1 = json.dumps({"task": "T1", "ts": "2026-08-19", "tokens_in": 1})
        e2 = json.dumps({"task": "T2", "ts": "2026-08-21", "tokens_in": 2})
        d = self._root([e1, e2])
        self.assertEqual(len(tc.load_ledger(d, since="2026-08-21")[0]), 1)
        self.assertEqual(tc.load_ledger(d, task="T1")[0][0]["task"], "T1")

    def test_append_ledger_roundtrip(self):
        d = tempfile.mkdtemp(prefix="t794-append-")
        self.assertTrue(tc.append_ledger(d, {"b": 1, "a": 2}))
        self.assertTrue(tc.append_ledger(d, {"c": 3}))
        entries, bad = tc.load_ledger(d)
        self.assertEqual((len(entries), bad), (2, 0))
        self.assertEqual(entries[0], {"a": 2, "b": 1})   # sort_keys roundtrip
        self.assertFalse(tc.append_ledger("", {}))


# ── write_tees / _sanitize ────────────────────────────────────────────────

class TestWriteTees(unittest.TestCase):
    """SHOULD: the COMPLETE raw stdout/stderr survives verbatim per task run."""

    def setUp(self):
        self.dir = tempfile.mkdtemp(prefix="t794-tee-")

    def test_tee_writes_both_streams_verbatim(self):
        out_p, err_p = tc.write_tees(self.dir, "T1", "20260820T1000", "deepseek",
                                     "raw stdout \n line2", "raw stderr")
        with open(out_p) as f:
            self.assertEqual(f.read(), "raw stdout \n line2")
        with open(err_p) as f:
            self.assertEqual(f.read(), "raw stderr")
        self.assertTrue(out_p.endswith(".stdout.log"))
        self.assertTrue(err_p.endswith(".stderr.log"))

    def test_falsy_root_returns_none_pair(self):
        self.assertEqual(tc.write_tees("", "T1", "t", "p", "o", "e"), (None, None))

    def test_sanitize_defuses_separators(self):
        self.assertEqual(tc._sanitize("a/b:c d"), "a_b_c_d")
        self.assertEqual(tc._sanitize(""), "")


# ── parse_session (feeds scan_sessions -> bakeoff/backfill) ────────────────

class TestParseSession(unittest.TestCase):
    """SHOULD: one session file -> record with dominant canonical model and
    derived tokens_in/tokens_out; no assistant turns -> None."""

    def setUp(self):
        self.dir = tempfile.mkdtemp(prefix="t794-parse-")

    def test_full_record(self):
        body = "\n".join([
            json.dumps({"type": "session", "id": "sess-9",
                        "timestamp": "2026-08-21T08:00:00Z",
                        "cwd": "/Users/alex/Project/Zig/weizigo"}),
            json.dumps({"type": "message", "message": {
                "role": "user",
                "content": [{"type": "text",
                             "text": "Follow untracked/T77-token-x.md"}]}}),
            json.dumps({"type": "message", "message": {
                "role": "assistant", "model": "deepseek-v4-flash",
                "provider": "deepseek",
                "usage": {"input": 4, "output": 6, "totalTokens": 10}}}),
        ]) + "\n"
        p = os.path.join(self.dir, "s.jsonl")
        with open(p, "w") as f:
            f.write(body)
        rec = tc.parse_session(p)
        self.assertIsNotNone(rec)
        self.assertEqual(rec["task"], "T77")
        self.assertEqual(rec["model"], "deepseek-v4-flash")
        self.assertEqual(rec["turns"], 1)
        self.assertEqual(rec["tokens_in"], 4)
        self.assertEqual(rec["tokens_out"], 6)
        self.assertEqual(rec["session_id"], "sess-9")

    def test_no_assistant_turns_is_none(self):
        p = os.path.join(self.dir, "s.jsonl")
        with open(p, "w") as f:
            f.write(json.dumps({"type": "session", "id": "x"}) + "\n")
        self.assertIsNone(tc.parse_session(p))

    def test_dominant_model_tie_break_lexicographic(self):
        body = "\n".join([
            json.dumps({"type": "session", "id": "x"}),
            json.dumps({"type": "message", "message": {
                "role": "assistant", "model": "glm-5.2:cloud",
                "usage": {}}}),
            json.dumps({"type": "message", "message": {
                "role": "assistant", "model": "minimax-m3",
                "usage": {}}}),
        ]) + "\n"
        p = os.path.join(self.dir, "s.jsonl")
        with open(p, "w") as f:
            f.write(body)
        rec = tc.parse_session(p)
        # 1-1 tie: lexicographic max of the CANONICAL labels wins
        self.assertEqual(rec["model"], "minimax-m3")

if __name__ == "__main__":
    unittest.main()
