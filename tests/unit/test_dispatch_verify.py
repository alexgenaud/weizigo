"""Unit tests for tools/dispatch_verify.py (T793).

What each function SHOULD do (intent, not current behaviour):

  generate_nonce          a fresh 128-bit echo token, format NONCE-<16 hex>.
  nonce_prompt_lines      the prompt fragment that makes the nonce unmissable.
  parse_deliverables      `deliverables=` from the bundle meta header; the
                          declared list, or [fallback] when the header declares
                          nothing, or [] when neither exists.
  is_findings_deliverable True only for repo-relative paths under findings/.
  verify_findings_file    [] for a schema-conform findings record; otherwise
                          error strings (invalid JSON / missing keys / claims
                          not an array / unreadable).
  store_path              MANAGENT_STORE override, else the default state path.
  read_store              the store dict, or None when unreadable/absent.
  task_state              (status, verdict) for a task, (None, None) when unknown.
  _glob_bundles           the bundle file(s) for a T-id, [] for non-T-id.
  classify_task_type      spec/infra/verification/battery by the ordered keyword
                          rule (battery > verification > spec > infra); infra is
                          the default for no match / non-T-id / ambiguous glob.
  recommended_wall        the class wall, escalating one DELEGATOR row when the
                          brief is large; battery caps at the top row.
  wall_advisory           (type, recommended, adequate, line): a wall below the
                          recommendation names a wall-low risk; an adequate or
                          unknown (None/<=0) budget is silent.
  _run_record_path        the runner's per-task record path; None for non-T-id.
  read_run_record         the record dict, or None when absent/unreadable.
  family_of_command       the harness family of a dispatch command, or None.
  _is_harness_line        [runner]/[verify] diagnostics only, never worker text.
  _substantive_lines      the lane's non-harness, non-blank lines.
  _strip_ansi             strip ANSI colour codes; tolerate bracket forms.
  _claude_refusal_reason  the runner's own envelope diagnostic, terminal-only
                          when require_terminal.
  _ollama_refusal_reason  the client's structured api_error block as the lane's
                          TERMINAL emission, empty of worker content by shape.
  _deepseek_refusal_reason always None — record-only classification (T630 brief
                          item 2); registered so every family has a detector.
  provider_refusal_reason 'provider-429'/'provider-auth'/'provider-connection'
                          from the HARNESS's own evidence, else None; never an
                          error when evidence is missing.
  directive_kill_reason   "D<id>/<type>" when the run record or the log's
                          [runner]-anchored signature names a directive kill,
                          else None.
  _classify_killed        runner `killed` string + kill_class -> killed_by enum;
                          unclassifiable -> harness-error (never scored).
  killed_by_reason        the enumerated killed_by from the RUNNER'S OWN record,
                          the refusal/directive classifications only where the
                          record cannot answer; None for non-T-id.
  _fail_perf              the perf tuple: directive-kill > unreached > fail.
  verify_dispatch         the post-dispatch gate: nonce echo, declared side
                          effects (exist + findings-parse), kanban row closed,
                          exit code; exit 0 only when side effects hold.
  heal_dispatch           reopen ONLY the row whose worker was just watched die
                          (rc!=0, row in_progress, not a directive-kill); write
                          the assertion record; never touch the tree.
  record_perf             one append-only ledger line per dispatch; a write
                          failure is a warning, never a failed dispatch.
  scan_findings           (relpath, errors) per findings/*.json, skipping
                          rejections.json; a missing directory yields nothing.
  _trailer_classify       the log's terminal [runner] exit/KILL line -> killed_by.
  census_classify         best-effort killed_by for a historical rc!=0 row, from
                          refusal / record / trailer evidence; UNKNOWN never blank.
  run_census              classify every rc!=0 ledger row and print the
                          direction-of-change table; missing ledger -> rc 2.
  main                    --dry-run over findings/ (rc 0/2) or --census <ledger>;
                          unknown flags ignored.

Half B discipline (T793 brief): each test names the SHOULD first; a test that
only restates current behaviour is marked `# CHARACTERIZATION`.  The one
SHOULD-vs-current disagreement found this pass — the empty-`deliverables=`
declaration returning PASS instead of UNVERIFIABLE — is recorded as an
expected failure owned by T793 (see TestVerifyDispatchEmptyDeliverables).

Stdlib only; tempfile for every file touch; no network; no subprocess (the one
subprocess user, heal_dispatch, is tested with a mocked subprocess.run).
"""
import json
import os
import sys
import tempfile
import unittest
from unittest import mock

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from _load import load  # noqa: E402

dv = load("tools/dispatch_verify.py")


# ── helpers ────────────────────────────────────────────────────────────────

def make_root():
    """A hermetic repo-shaped root: untracked/{log,runs} present, nothing else."""
    root = tempfile.mkdtemp(prefix="t793-")
    os.makedirs(os.path.join(root, "untracked", "log"), exist_ok=True)
    os.makedirs(os.path.join(root, "untracked", "runs"), exist_ok=True)
    return root


def write_store(root, rows, name="store.json"):
    path = os.path.join(root, name)
    with open(path, "w") as f:
        json.dump(rows, f)
    return path


def write_deliverable(root, rel="docs/out.txt", content="work product"):
    p = os.path.join(root, rel)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    with open(p, "w") as f:
        f.write(content)
    return rel


def write_run_record(root, task_id, data):
    p = os.path.join(root, "untracked", "runs", task_id + ".json")
    os.makedirs(os.path.dirname(p), exist_ok=True)
    with open(p, "w") as f:
        json.dump(data, f)
    return p


def write_log(root, task_id, text):
    p = os.path.join(root, "untracked", "log", task_id.lower() + ".log")
    os.makedirs(os.path.dirname(p), exist_ok=True)
    with open(p, "w") as f:
        f.write(text)
    return p


def verify(root, task_id, nonce="NONCE-abc", stdout="NONCE-abc done", rc=0,
           store_env=None, deliverables=None, model="glm-5.2"):
    """Call dv.verify_dispatch with a done+pass row unless store_env says else."""
    return dv.verify_dispatch(root=root, task_id=task_id, model=model,
                              nonce=nonce, stdout=stdout, rc=rc,
                              store_env=store_env, deliverables=deliverables)


def done_pass_store(root, task_id="T1"):
    return write_store(root, {task_id: {"status": "done", "verdict": "pass"}})


# ── nonce utilities ────────────────────────────────────────────────────────

class TestGenerateNonce(unittest.TestCase):
    """SHOULD: a fresh 128-bit echo token, format NONCE-<16 hex chars>."""

    def test_format(self):
        n = dv.generate_nonce()
        self.assertRegex(n, r"^NONCE-[0-9a-f]{16}$")

    def test_fresh_each_call(self):
        self.assertNotEqual(dv.generate_nonce(), dv.generate_nonce())


class TestNoncePromptLines(unittest.TestCase):
    """SHOULD: make the injected token unmissable — both lines carry it."""

    def test_contains_nonce_twice(self):
        n = dv.generate_nonce()
        text = dv.nonce_prompt_lines(n)
        self.assertIn("VERIFY-NONCE: %s" % n, text)
        self.assertIn("Begin your final reply with exactly the line: %s" % n, text)


# ── parse_deliverables ─────────────────────────────────────────────────────

class TestParseDeliverables(unittest.TestCase):
    """SHOULD: the declared list, or [fallback] when nothing declared, or []."""

    def _bundle(self, first_line):
        root = tempfile.mkdtemp(prefix="t793-dl-")
        p = os.path.join(root, "bundle.md")
        with open(p, "w") as f:
            f.write(first_line + "\n# title\n")
        return p

    def test_two_paths(self):
        p = self._bundle('<!--managent set=A deliverables=docs/a.md,findings/T1-x.json-->')
        self.assertEqual(dv.parse_deliverables(p),
                         ["docs/a.md", "findings/T1-x.json"])

    def test_no_space_before_close(self):
        # T411 latent bug: a greedy [^\s>]+ absorbed the '-->' when
        # deliverables= was the last key; the non-greedy form must not.
        p = self._bundle('<!--managent set=A deliverables=docs/a.md-->')
        self.assertEqual(dv.parse_deliverables(p), ["docs/a.md"])

    def test_trailing_comma(self):
        p = self._bundle('<!--managent set=A deliverables=docs/a.md,-->')
        self.assertEqual(dv.parse_deliverables(p), ["docs/a.md"])

    def test_stops_at_next_key(self):
        # the acceptance= key follows with a space; the value must stop there
        p = self._bundle('<!--managent set=A deliverables=docs/a.md acceptance=cmd-->')
        self.assertEqual(dv.parse_deliverables(p), ["docs/a.md"])

    def test_empty_declaration_returns_empty(self):
        # an EXPLICIT empty deliverables= is a declaration of nothing: neither
        # the paths nor the fallback may leak through
        p = self._bundle("<!--managent set=A deliverables=-->")
        self.assertEqual(dv.parse_deliverables(p, fallback="findings/T1-x.json"), [])

    def test_no_header_with_fallback(self):
        p = self._bundle("# no meta header at all")
        self.assertEqual(dv.parse_deliverables(p, fallback="findings/T1-x.json"),
                         ["findings/T1-x.json"])

    def test_no_header_no_fallback(self):
        p = self._bundle("# no meta header at all")
        self.assertEqual(dv.parse_deliverables(p), [])

    def test_missing_file_with_fallback(self):
        # characterization: a missing bundle degrades to the fallback (the
        # dispatcher only calls this after globbing a real bundle, so the
        # missing-file path is defensive)
        self.assertEqual(
            dv.parse_deliverables("/nonexistent/bundle.md", fallback="findings/T1-x.json"),
            ["findings/T1-x.json"])

    def test_header_without_deliverables_key(self):
        p = self._bundle("<!--managent set=A holds=src/foo.zig-->")
        self.assertEqual(dv.parse_deliverables(p, fallback="findings/T1-x.json"),
                         ["findings/T1-x.json"])


# ── findings helpers ───────────────────────────────────────────────────────

class TestIsFindingsDeliverable(unittest.TestCase):
    """SHOULD: True only for repo-relative paths under findings/."""

    def test_under_findings(self):
        self.assertTrue(dv.is_findings_deliverable("findings/T1-x.json"))
        self.assertTrue(dv.is_findings_deliverable("findings/"))
        self.assertTrue(dv.is_findings_deliverable("findings"))

    def test_outside_findings(self):
        self.assertFalse(dv.is_findings_deliverable("docs/a.md"))
        self.assertFalse(dv.is_findings_deliverable("findings2/x.json"))

    def test_absolute_path_is_not_repo_relative(self):
        self.assertFalse(dv.is_findings_deliverable("/abs/findings/T1-x.json"))


class TestVerifyFindingsFile(unittest.TestCase):
    """SHOULD: [] for a conform record; error strings otherwise."""

    def _write(self, root, content):
        p = os.path.join(root, "rec.json")
        with open(p, "w") as f:
            f.write(content)
        return p

    def test_valid_record(self):
        root = tempfile.mkdtemp(prefix="t793-vff-")
        p = self._write(root, json.dumps(
            {"task_id": "T1", "date": "2026-08-23", "model": "m", "claims": []}))
        self.assertEqual(dv.verify_findings_file(p), [])

    def test_invalid_json(self):
        root = tempfile.mkdtemp(prefix="t793-vff-")
        p = self._write(root, "{ nope")
        errs = dv.verify_findings_file(p)
        self.assertEqual(len(errs), 1)
        self.assertIn("invalid JSON", errs[0])

    def test_not_an_object(self):
        root = tempfile.mkdtemp(prefix="t793-vff-")
        p = self._write(root, "[1, 2]")
        self.assertEqual(dv.verify_findings_file(p), ["not a JSON object"])

    def test_missing_required_keys(self):
        root = tempfile.mkdtemp(prefix="t793-vff-")
        p = self._write(root, json.dumps({"task_id": "T1"}))
        errs = dv.verify_findings_file(p)
        self.assertEqual(len(errs), 1)
        for k in ("date", "model", "claims"):
            self.assertIn(k, errs[0])

    def test_claims_not_an_array(self):
        root = tempfile.mkdtemp(prefix="t793-vff-")
        p = self._write(root, json.dumps(
            {"task_id": "T1", "date": "2026-08-23", "model": "m", "claims": "no"}))
        self.assertIn("claims must be an array", dv.verify_findings_file(p))

    def test_unreadable(self):
        errs = dv.verify_findings_file("/nonexistent/rec.json")
        self.assertEqual(len(errs), 1)
        self.assertIn("unreadable", errs[0])


# ── store helpers ──────────────────────────────────────────────────────────

class TestStoreHelpers(unittest.TestCase):
    """store_path/read_store/task_state — the kanban ground truth accessors."""

    def test_store_path_default(self):
        self.assertEqual(
            dv.store_path("/r"),
            os.path.join("/r", "docs", "infra", "managent", "tasks.json"))

    def test_store_path_env_override(self):
        self.assertEqual(dv.store_path("/r", store_env="/e/t.json"), "/e/t.json")

    def test_read_store_valid(self):
        root = make_root()
        p = write_store(root, {"T1": {"status": "done", "verdict": "pass"}})
        self.assertEqual(dv.read_store(root, p)["T1"]["status"], "done")

    def test_read_store_missing_returns_none(self):
        self.assertIsNone(dv.read_store("/nonexistent"))
        self.assertIsNone(dv.read_store("/nonexistent", "/nonexistent/store.json"))

    def test_task_state_present(self):
        data = {"T1": {"status": "done", "verdict": "pass"}}
        self.assertEqual(dv.task_state(data, "T1"), ("done", "pass"))

    def test_task_state_absent(self):
        self.assertEqual(dv.task_state({"T1": {}}, "T2"), (None, None))
        self.assertEqual(dv.task_state(None, "T2"), (None, None))
        self.assertEqual(dv.task_state({}, "T2"), (None, None))


# ── task class / wall guidance ─────────────────────────────────────────────

class TestGlobBundles(unittest.TestCase):
    """SHOULD: the bundle file(s) for a T-id; [] for a non-T-id."""

    def test_tid_finds_bundle(self):
        root = make_root()
        os.makedirs(os.path.join(root, "untracked"), exist_ok=True)
        open(os.path.join(root, "untracked", "T5201-battery-sweep.md"), "w").close()
        hits = dv._glob_bundles(root, "T5201")
        self.assertEqual(len(hits), 1)
        self.assertTrue(hits[0].endswith("T5201-battery-sweep.md"))

    def test_no_bundle(self):
        root = make_root()
        self.assertEqual(dv._glob_bundles(root, "T9999"), [])

    def test_non_tid(self):
        root = make_root()
        self.assertEqual(dv._glob_bundles(root, "bundle.md"), [])
        self.assertEqual(dv._glob_bundles(root, None), [])


class TestClassifyTaskType(unittest.TestCase):
    """SHOULD: ordered keyword rule, infra as the default for ambiguity."""

    def _root_with(self, bundles):
        root = make_root()
        os.makedirs(os.path.join(root, "untracked"), exist_ok=True)
        for name in bundles:
            open(os.path.join(root, "untracked", name), "w").close()
        return root

    def test_keyword_classes(self):
        root = self._root_with([
            "T5201-battery-sweep.md", "T5202-spec-design.md",
            "T5203-audit-race.md", "T5204-infra-tooling.md"])
        self.assertEqual(dv.classify_task_type(root, "T5201"), "battery")
        self.assertEqual(dv.classify_task_type(root, "T5202"), "spec")
        self.assertEqual(dv.classify_task_type(root, "T5203"), "verification")
        # infra has no keywords; no match -> the infra default
        self.assertEqual(dv.classify_task_type(root, "T5204"), "infra")

    def test_non_tid_defaults_infra(self):
        root = make_root()
        self.assertEqual(dv.classify_task_type(root, "foo"), "infra")
        self.assertEqual(dv.classify_task_type(root, None), "infra")

    def test_ambiguous_glob_defaults_infra(self):
        root = self._root_with(["T5205-a.md", "T5205-b.md"])
        self.assertEqual(dv.classify_task_type(root, "T5205"), "infra")

    def test_store_note_can_reclassify(self):
        root = self._root_with(["T5206-foo.md"])
        store = write_store(root, {"T5206": {"note": "second-auditor rerun"}})
        self.assertEqual(dv.classify_task_type(root, "T5206", store_env=store),
                         "verification")


class TestRecommendedWall(unittest.TestCase):
    """SHOULD: class base, escalate on large brief, cap at the top row."""

    def test_bases_differ_and_order(self):
        g = dv.WALL_GUIDANCE
        self.assertLess(g["spec"], g["infra"])
        self.assertLess(g["infra"], g["verification"])
        self.assertLess(g["verification"], g["battery"])

    def test_small_brief_uses_base(self):
        self.assertEqual(dv.recommended_wall("spec", 100),
                         dv.WALL_GUIDANCE["spec"])

    def test_large_brief_escalates_one_row(self):
        self.assertEqual(dv.recommended_wall("spec", 20000),
                         dv.WALL_GUIDANCE["infra"])
        self.assertEqual(dv.recommended_wall("infra", 20000),
                         dv.WALL_GUIDANCE["verification"])

    def test_boundary_at_large_brief_bytes(self):
        b = dv.LARGE_BRIEF_BYTES
        self.assertEqual(dv.recommended_wall("spec", b - 1), dv.WALL_GUIDANCE["spec"])
        self.assertEqual(dv.recommended_wall("spec", b), dv.WALL_GUIDANCE["infra"])

    def test_battery_caps_at_top(self):
        self.assertEqual(dv.recommended_wall("battery", 100000),
                         dv.WALL_GUIDANCE["battery"])

    def test_unknown_class_defaults_infra(self):
        self.assertEqual(dv.recommended_wall("nonsense", None),
                         dv.WALL_GUIDANCE["infra"])

    def test_no_brief_no_escalation(self):
        self.assertEqual(dv.recommended_wall("spec", None),
                         dv.WALL_GUIDANCE["spec"])


class TestWallAdvisory(unittest.TestCase):
    """SHOULD: (type, recommended, adequate, line); adequate/unknown silent."""

    def test_inadequate_names_wall_low(self):
        root = make_root()
        os.makedirs(os.path.join(root, "untracked"), exist_ok=True)
        open(os.path.join(root, "untracked", "T5207-battery-sweep.md"),
             "wb").write(b"Z" * 20000)
        typ, rec, ok, line = dv.wall_advisory(root, "T5207", wall_budget=1800,
                                              brief_bytes=20000)
        self.assertEqual(typ, "battery")
        self.assertEqual(rec, dv.WALL_GUIDANCE["battery"])
        self.assertFalse(ok)
        self.assertIn("wall-low", line)
        self.assertIn("T5207", line)

    def test_adequate_is_silent(self):
        root = make_root()
        typ, rec, ok, line = dv.wall_advisory(root, "T5208", wall_budget=7200)
        self.assertTrue(ok)
        self.assertEqual(line, "")

    def test_unknown_budget_is_adequate(self):
        root = make_root()
        typ, rec, ok, line = dv.wall_advisory(root, "T5209", wall_budget=None)
        self.assertTrue(ok)
        self.assertEqual(line, "")
        typ, rec, ok, line = dv.wall_advisory(root, "T5209", wall_budget=0)
        self.assertTrue(ok)
        self.assertEqual(line, "")


# ── run record ─────────────────────────────────────────────────────────────

class TestRunRecord(unittest.TestCase):
    """_run_record_path / read_run_record — the runner's terminal evidence."""

    def test_run_record_path_tid(self):
        self.assertEqual(
            dv._run_record_path("/r", "T6503"),
            os.path.join("/r", "untracked", "runs", "T6503.json"))

    def test_run_record_path_non_tid(self):
        self.assertIsNone(dv._run_record_path("/r", "foo"))
        self.assertIsNone(dv._run_record_path("/r", None))
        self.assertIsNone(dv._run_record_path(None, "T6503"))

    def test_read_run_record_valid(self):
        root = make_root()
        write_run_record(root, "T6503", {"exit": 124, "killed": "wall ceiling"})
        self.assertEqual(dv.read_run_record(root, "T6503")["exit"], 124)

    def test_read_run_record_missing(self):
        root = make_root()
        self.assertIsNone(dv.read_run_record(root, "T9999"))
        self.assertIsNone(dv.read_run_record(root, "foo"))

    def test_read_run_record_invalid_json(self):
        root = make_root()
        p = write_run_record(root, "T6504", {"a": 1})
        with open(p, "w") as f:
            f.write("{ broken")
        self.assertIsNone(dv.read_run_record(root, "T6504"))


# ── harness family / refusal detectors (T630) ──────────────────────────────

class TestFamilyOfCommand(unittest.TestCase):
    """SHOULD: the harness family from the dispatch argv, or None."""

    def test_ollama(self):
        self.assertEqual(
            dv.family_of_command("tools/runner ollama launch pi --model x -y -- ..."),
            "ollama")

    def test_claude(self):
        self.assertEqual(
            dv.family_of_command("tools/runner claude -p '...'"),
            "claude")

    def test_deepseek(self):
        self.assertEqual(
            dv.family_of_command("tools/runner pi --provider deepseek --max-wall 300"),
            "deepseek")

    def test_unrecognized_and_empty(self):
        self.assertIsNone(dv.family_of_command("python3 worker.py"))
        self.assertIsNone(dv.family_of_command(""))
        self.assertIsNone(dv.family_of_command(None))


class TestHarnessLineHelpers(unittest.TestCase):
    """_is_harness_line / _substantive_lines / _strip_ansi."""

    def test_is_harness_line(self):
        self.assertTrue(dv._is_harness_line("[runner] guards: rss 4096"))
        self.assertTrue(dv._is_harness_line("[verify] summary"))
        self.assertFalse(dv._is_harness_line("worker content"))
        self.assertFalse(dv._is_harness_line(""))
        self.assertFalse(dv._is_harness_line("[worker] not a harness line"))

    def test_substantive_lines_filters_harness_and_blanks(self):
        lines = ["[runner] argv = ...", "", "  worker line  ", "[verify] note",
                 "more work"]
        self.assertEqual(dv._substantive_lines(lines), ["  worker line  ", "more work"])

    def test_strip_ansi_escapes(self):
        self.assertEqual(dv._strip_ansi("\x1b[37mPreparing Pi...\x1b[0m"),
                         "Preparing Pi...")

    def test_strip_ansi_tolerates_bracket_forms(self):
        # fixture heredocs render the ESC byte away; leading/trailing [NNNm
        # must still be tolerated
        self.assertEqual(dv._strip_ansi("[37mPreparing Pi...[0m"), "Preparing Pi...")
        self.assertEqual(dv._strip_ansi("plain"), "plain")


class TestClaudeRefusalReason(unittest.TestCase):
    """SHOULD: the runner's envelope diagnostic, terminal-only when required."""

    REFUSAL = "[runner] tokens: no reading — claude api error (is_error=true, zero usage)"

    def test_position_free_without_terminal_requirement(self):
        lines = ["[runner] argv = claude -p ...", "worker", self.REFUSAL, "more work"]
        self.assertEqual(dv._claude_refusal_reason(lines, "\n".join(lines), False),
                         "provider-429")

    def test_require_terminal_refusal_after_last_substantive(self):
        lines = ["[runner] argv = claude -p ...", "worker", self.REFUSAL]
        self.assertEqual(dv._claude_refusal_reason(lines, None, True), "provider-429")

    def test_require_terminal_mid_log_mention_is_not_terminal(self):
        # T616: a mid-log mention is not the run's terminal event
        lines = ["[runner] argv = claude -p ...", "worker", self.REFUSAL, "more work"]
        self.assertIsNone(dv._claude_refusal_reason(lines, None, True))

    def test_no_refusal(self):
        lines = ["[runner] argv = claude -p ...", "worker"]
        self.assertIsNone(dv._claude_refusal_reason(lines, None, False))


class TestOllamaRefusalReason(unittest.TestCase):
    """SHOULD: the structured api_error block, terminal and empty of worker
    content by shape; a quotation of the block is NOT a refusal (T526/T601)."""

    STARTUP = "Preparing Pi..."
    STATUS = '429: {"message":"limit","type":"api_error","param":null,"code":null}'
    EXIT = "Error: exit status 1"

    def _lines(self, *emissions):
        return ["[runner] argv = ollama launch pi ...", self.STARTUP,
                "Launching Pi..."] + list(emissions)

    def test_full_block_shape(self):
        lines = self._lines(self.STATUS, self.EXIT)
        self.assertEqual(dv._ollama_refusal_reason(lines, None, False), "provider-429")

    def test_requires_terminal_block(self):
        # worker content after the block rules it out
        lines = self._lines(self.STATUS, self.EXIT, "more worker content")
        self.assertIsNone(dv._ollama_refusal_reason(lines, None, False))

    def test_quotation_of_the_block_ruled_out(self):
        # the block quoted mid-log leaves worker content between the launch
        # phase and the quote -> fails the emptiness test by construction
        lines = self._lines("worker wrote: " + self.STATUS, self.EXIT)
        self.assertIsNone(dv._ollama_refusal_reason(lines, None, False))

    def test_worker_content_before_block_disqualifies(self):
        lines = ["[runner] argv = ollama launch pi ...", self.STARTUP,
                 "worker content", self.STATUS, self.EXIT]
        self.assertIsNone(dv._ollama_refusal_reason(lines, None, False))

    def test_wrong_shapes(self):
        self.assertIsNone(dv._ollama_refusal_reason(["a"], None, False))
        self.assertIsNone(dv._ollama_refusal_reason(
            self._lines("429: {not json}", self.EXIT), None, False))
        self.assertIsNone(dv._ollama_refusal_reason(
            self._lines(self.STATUS, "Error: something else"), None, False))

    def test_require_terminal_never_matches(self):
        # an ollama connect refusal can never CAUSE a harness kill
        lines = self._lines(self.STATUS, self.EXIT)
        self.assertIsNone(dv._ollama_refusal_reason(lines, None, True))


class TestDeepseekRefusalReason(unittest.TestCase):
    """SHOULD: never — deepseek classifies from the run record only (T630)."""

    def test_always_none(self):
        self.assertIsNone(dv._deepseek_refusal_reason([], None, False))
        self.assertIsNone(dv._deepseek_refusal_reason(["anything"], "text", True))
        self.assertIsNone(dv._deepseek_refusal_reason(None, None, False))


class TestProviderRefusalReason(unittest.TestCase):
    """SHOULD: the harness's own evidence only; absence is a non-match, never
    an error."""

    def test_claude_log(self):
        root = make_root()
        write_log(root, "T1020",
                  "[runner] argv = claude -p '...'\nworker\n"
                  "[runner] tokens: no reading — claude api error (is_error=true, zero usage)\n")
        self.assertEqual(dv.provider_refusal_reason(root, "T1020"), "provider-429")

    def test_ollama_log(self):
        root = make_root()
        write_log(root, "T1012",
                  "[runner] argv = ollama launch pi ...\n"
                  "Preparing Pi...\nLaunching Pi...\n"
                  '429: {"type":"api_error","message":"limit"}\n'
                  "Error: exit status 1\n")
        self.assertEqual(dv.provider_refusal_reason(root, "T1012"), "provider-429")

    def test_no_evidence_is_none(self):
        root = make_root()
        self.assertIsNone(dv.provider_refusal_reason(root, "T9999"))

    def test_non_tid_is_none(self):
        root = make_root()
        self.assertIsNone(dv.provider_refusal_reason(root, "bundle.md"))
        self.assertIsNone(dv.provider_refusal_reason(root, None))
        self.assertIsNone(dv.provider_refusal_reason(None, "T1"))

    def test_worker_quote_of_refusal_is_not_evidence(self):
        # a worker quoting an old 429 (T526) must not classify
        root = make_root()
        write_log(root, "T1021",
                  "[runner] argv = claude -p '...'\n"
                  "The document quotes: [runner] tokens: no reading — claude api error\n"
                  "done\n")
        self.assertIsNone(dv.provider_refusal_reason(root, "T1021"))

    def test_killed_record_requires_terminal_refusal(self):
        # T616: a harness kill + mid-log refusal -> the kill stands
        root = make_root()
        write_log(root, "T1022",
                  "[runner] argv = claude -p '...'\n"
                  "[runner] tokens: no reading — claude api error (is_error=true, zero usage)\n"
                  "worker content\n")
        write_run_record(root, "T1022", {"killed": "progress timeout 600s", "exit": None})
        self.assertIsNone(dv.provider_refusal_reason(root, "T1022"))


# ── directive kills (T625) ─────────────────────────────────────────────────

class TestDirectiveKillReason(unittest.TestCase):
    """SHOULD: D<id>/<type> from the record first, then the log's
    [runner]-anchored launch signature; None for a genuine wall/RSS kill."""

    def test_record_kill_class(self):
        root = make_root()
        write_run_record(root, "T6250",
                         {"killed": "directive D6257 PAUSE", "kill_class": "directive"})
        self.assertEqual(dv.directive_kill_reason(root, "T6250"), "D6257/pause")

    def test_record_kill_kill(self):
        root = make_root()
        write_run_record(root, "T6251", {"killed": "directive D6258 KILL"})
        self.assertEqual(dv.directive_kill_reason(root, "T6251"), "D6258/kill")

    def test_record_killed_just_directive(self):
        root = make_root()
        write_run_record(root, "T6252", {"killed": "directive"})
        self.assertEqual(dv.directive_kill_reason(root, "T6252"), "unknown/directive")

    def test_log_fallback_launch_signature(self):
        root = make_root()
        write_log(root, "T6253", "[runner] exit 124 (directive: pause)")
        self.assertEqual(dv.directive_kill_reason(root, "T6253"), "unknown/pause")

    def test_log_fallback_without_type(self):
        root = make_root()
        write_log(root, "T6254", "[runner] exit 124 (directive)")
        self.assertEqual(dv.directive_kill_reason(root, "T6254"), "unknown/pause/kill")

    def test_wall_kill_is_not_directive(self):
        root = make_root()
        write_run_record(root, "T6255", {"killed": "wall ceiling 1800s reached"})
        self.assertIsNone(dv.directive_kill_reason(root, "T6255"))

    def test_worker_quoted_signature_is_not_directive(self):
        # T630 anchor: only a [runner]-prefixed line may match the log fallback
        root = make_root()
        write_log(root, "T6256", "the module docstring says [runner] exit 124 (directive: pause)\n")
        self.assertIsNone(dv.directive_kill_reason(root, "T6256"))

    def test_no_evidence(self):
        root = make_root()
        self.assertIsNone(dv.directive_kill_reason(root, "T9999"))

    def test_non_tid(self):
        root = make_root()
        self.assertIsNone(dv.directive_kill_reason(root, "foo"))


# ── killed_by (T629) ───────────────────────────────────────────────────────

class TestClassifyKilled(unittest.TestCase):
    """SHOULD: map the runner's killed string + kill_class to the enum;
    unclassifiable -> harness-error (censored, never scored)."""

    def test_directive(self):
        self.assertEqual(dv._classify_killed("directive D1 PAUSE"), "directive")
        self.assertEqual(dv._classify_killed("x", kill_class="directive"), "directive")

    def test_liveness(self):
        self.assertEqual(dv._classify_killed("liveness 60s"), "liveness")
        self.assertEqual(dv._classify_killed("x", kill_class="liveness"), "liveness")

    def test_watchdog_wall_cpu_rss(self):
        self.assertEqual(dv._classify_killed("progress timeout 600s"), "watchdog")
        self.assertEqual(dv._classify_killed("wall ceiling 1800s reached"), "wall")
        self.assertEqual(dv._classify_killed("cpu ceiling 3600s reached"), "cpu")
        self.assertEqual(dv._classify_killed("rss cap 4096 MB"), "rss")
        self.assertEqual(dv._classify_killed("host memory pressure"), "rss")

    def test_unknown_is_harness_error(self):
        self.assertEqual(dv._classify_killed("something mysterious"), "harness-error")
        self.assertEqual(dv._classify_killed(""), "harness-error")


class TestKilledByReason(unittest.TestCase):
    """SHOULD: the runner's own record first; refusal/directive only where the
    record cannot answer; None for non-T-id."""

    def test_record_stamp_wins(self):
        root = make_root()
        write_run_record(root, "T6290", {"killed_by": "wall", "killed": "wall ceiling"})
        self.assertEqual(dv.killed_by_reason(root, "T6290"), "wall")

    def test_record_killed_classified(self):
        root = make_root()
        write_run_record(root, "T6291", {"killed": "progress timeout 600s"})
        self.assertEqual(dv.killed_by_reason(root, "T6291"), "watchdog")

    def test_killed_with_tail_refusal_is_provider_limit(self):
        # T616: a refusal in the tail that CAUSED the kill censors the row
        root = make_root()
        write_run_record(root, "T6292", {"killed": "progress timeout 600s"})
        write_log(root, "T6292",
                  "[runner] argv = claude -p '...'\n"
                  "[runner] tokens: no reading — claude api error (is_error=true, zero usage)\n")
        self.assertEqual(dv.killed_by_reason(root, "T6292"), "provider-limit")

    def test_clean_exit_is_none(self):
        root = make_root()
        write_run_record(root, "T6293", {"exit": 0})
        self.assertEqual(dv.killed_by_reason(root, "T6293"), "none")

    def test_plain_nonzero_exit_is_none(self):
        root = make_root()
        write_run_record(root, "T6294", {"exit": 5})
        self.assertEqual(dv.killed_by_reason(root, "T6294"), "none")

    def test_no_record_directive_param(self):
        root = make_root()
        self.assertEqual(dv.killed_by_reason(root, "T6295", directive_kill="D1/pause"),
                         "directive")

    def test_no_record_log_refusal(self):
        root = make_root()
        write_log(root, "T6296",
                  "[runner] argv = claude -p '...'\n"
                  "[runner] tokens: no reading — claude api error (is_error=true, zero usage)\n")
        self.assertEqual(dv.killed_by_reason(root, "T6296"), "provider-limit")

    def test_no_evidence_is_none(self):
        root = make_root()
        self.assertEqual(dv.killed_by_reason(root, "T6297"), "none")

    def test_non_tid(self):
        root = make_root()
        self.assertIsNone(dv.killed_by_reason(root, "foo"))
        self.assertIsNone(dv.killed_by_reason(root, None))


# ── _fail_perf ─────────────────────────────────────────────────────────────

class TestFailPerf(unittest.TestCase):
    """SHOULD: directive-kill > unreached > fail — a directive stop or an
    unreached provider must never record verified=fail."""

    def test_directive_kill_wins(self):
        perf = dv._fail_perf("T1", "m", "incomplete", "row",
                             "provider-429", directive_kill="D1/pause")
        self.assertEqual(perf, ("T1", "m", "incomplete", "directive-kill", "D1/pause"))

    def test_unreached_over_fail(self):
        perf = dv._fail_perf("T1", "m", "incomplete", "row", "provider-429")
        self.assertEqual(perf, ("T1", "m", "incomplete", "unreached", "provider-429"))

    def test_plain_fail(self):
        perf = dv._fail_perf("T1", "m", "incomplete", "row", None)
        self.assertEqual(perf, ("T1", "m", "incomplete", "fail", "row"))


# ── verify_dispatch — the gate ─────────────────────────────────────────────

class TestVerifyDispatchNonce(unittest.TestCase):
    """SHOULD: pass only when the worker's reply contains the injected token
    (T411) — a reply that never opened the prompt cannot contain it."""

    def _done_row(self, root):
        return done_pass_store(root, "T1"), write_deliverable(root)

    def test_nonce_present_passes(self):
        root = make_root()
        store, dl = self._done_row(root)
        rc, summ, details, perf = verify(root, "T1", store_env=store,
                                         deliverables=[dl])
        self.assertEqual(rc, 0)
        self.assertIn("PASSED", summ)
        self.assertEqual(perf, ("T1", "glm-5.2", "success", "pass", None))

    def test_nonce_absent_fails(self):
        root = make_root()
        store, dl = self._done_row(root)
        rc, summ, details, perf = verify(root, "T1", stdout="OK.",
                                         store_env=store, deliverables=[dl])
        self.assertEqual(rc, 2)
        self.assertIn("nonce", summ)
        self.assertEqual(perf[3], "fail")
        self.assertEqual(perf[4], "nonce")

    def test_mangled_nonce_fails(self):
        # one hex char mutated: the exact token is not in the reply
        root = make_root()
        store, dl = self._done_row(root)
        nonce = "NONCE-0123456789abcdef"
        rc, summ, details, perf = verify(root, "T1", nonce=nonce,
                                         stdout="NONCE-0123456789abcdeX",
                                         store_env=store, deliverables=[dl])
        self.assertEqual(rc, 2)
        self.assertEqual(perf[4], "nonce")

    def test_nonce_echoed_in_a_quoted_brief_passes(self):
        # the worker pasted the whole brief (VERIFY-NONCE line included) into
        # a fenced quote: it demonstrably READ the prompt, so the nonce arm
        # passes — the deliverables arm is what catches a read-but-did-nothing
        root = make_root()
        store, dl = self._done_row(root)
        nonce = "NONCE-quoted00000000"
        quoted = ("Follow untracked/T1.md\n\n"
                  "VERIFY-NONCE: %s\n"
                  "Begin your final reply with exactly the line: %s" % (nonce, nonce))
        stdout = ("Here is the brief I was given:\n---\n%s\n---\nwork complete" % quoted)
        rc, summ, details, perf = verify(root, "T1", nonce=nonce, stdout=stdout,
                                         store_env=store, deliverables=[dl])
        self.assertEqual(rc, 0)

    def test_truncated_nonce_fails(self):
        # `nonce in stdout` demands the FULL token: a truncated echo is not the
        # injected token and fails.  (A worker that only had part of the prompt
        # — or truncated a quote — cannot reproduce the full 128-bit token.)
        root = make_root()
        store, dl = self._done_row(root)
        nonce = "NONCE-abcdef0123456789"
        rc, summ, details, perf = verify(root, "T1", nonce=nonce,
                                         stdout="NONCE-abcdef0123",
                                         store_env=store, deliverables=[dl])
        self.assertEqual(rc, 2)
        self.assertEqual(perf[4], "nonce")


class TestVerifyDispatchDeliverables(unittest.TestCase):
    """SHOULD: require every declared deliverables= path to exist (and the
    done gate, T278, separately requires them committed); a malformed findings
    deliverable is broken work regardless of the verdict (T488)."""

    def test_missing_deliverable_fails(self):
        root = make_root()
        store = done_pass_store(root)
        rc, summ, details, perf = verify(root, "T1", store_env=store,
                                         deliverables=["docs/never-written.txt"])
        self.assertEqual(rc, 2)
        self.assertIn("docs/never-written.txt", summ)
        self.assertEqual(perf[4], "deliverables")

    def test_fail_found_requires_deliverables(self):
        # fail-found's definition: the work executed, the subject failed — so
        # the deliverables are hard for it too
        root = make_root()
        store = write_store(root, {"T1": {"status": "done", "verdict": "fail-found"}})
        rc, summ, details, perf = verify(root, "T1", store_env=store,
                                         deliverables=["docs/never-written.txt"])
        self.assertEqual(rc, 2)
        self.assertEqual(perf[4], "deliverables")

    def test_fail_found_with_deliverables_passes(self):
        root = make_root()
        store = write_store(root, {"T1": {"status": "done", "verdict": "fail-found"}})
        dl = write_deliverable(root)
        rc, summ, details, perf = verify(root, "T1", store_env=store,
                                         deliverables=[dl])
        self.assertEqual(rc, 0)
        self.assertIn("believing the work, not the text", summ)

    def test_blocked_and_abandoned_need_no_deliverables(self):
        for verdict in ("blocked", "abandoned"):
            root = make_root()
            store = write_store(root, {"T1": {"status": "done", "verdict": verdict}})
            rc, summ, details, perf = verify(root, "T1", store_env=store,
                                             deliverables=["docs/never-written.txt"])
            self.assertEqual(rc, 0, "verdict %s must pass without deliverables" % verdict)
            self.assertTrue(any("deliverables absent" in d for d in details))

    def test_findings_deliverable_malformed_fails(self):
        # T488: exists but does not parse is broken work — report it, not pass
        root = make_root()
        store = done_pass_store(root)
        os.makedirs(os.path.join(root, "findings"), exist_ok=True)
        with open(os.path.join(root, "findings", "T1-bad.json"), "w") as f:
            f.write("{ nope")
        rc, summ, details, perf = verify(root, "T1", store_env=store,
                                         deliverables=["findings/T1-bad.json"])
        self.assertEqual(rc, 2)
        self.assertEqual(perf[4], "findings")

    def test_findings_deliverable_valid_passes(self):
        root = make_root()
        store = done_pass_store(root)
        os.makedirs(os.path.join(root, "findings"), exist_ok=True)
        with open(os.path.join(root, "findings", "T1-good.json"), "w") as f:
            json.dump({"task_id": "T1", "date": "2026-08-23",
                       "model": "m", "claims": []}, f)
        rc, summ, details, perf = verify(root, "T1", store_env=store,
                                         deliverables=["findings/T1-good.json"])
        self.assertEqual(rc, 0)

    def test_non_findings_deliverable_is_not_parsed(self):
        # the findings parse applies only under findings/ — a docs/ file with
        # garbage content is not a findings record and must not fail
        root = make_root()
        store = done_pass_store(root)
        dl = write_deliverable(root, "docs/not-a-findings.json", "{ nope")
        rc, summ, details, perf = verify(root, "T1", store_env=store,
                                         deliverables=[dl])
        self.assertEqual(rc, 0)

    def test_findings_deliverable_missing_is_deliverables_not_findings(self):
        # missing beats malformed: the file does not exist, so the parse cannot
        # even run; the fail reason is the graded 'deliverables', not 'findings'
        root = make_root()
        store = done_pass_store(root)
        rc, summ, details, perf = verify(root, "T1", store_env=store,
                                         deliverables=["findings/T1-never.json"])
        self.assertEqual(rc, 2)
        self.assertEqual(perf[4], "deliverables")

    def test_absolute_deliverable_path(self):
        root = make_root()
        store = done_pass_store(root)
        abs_dl = os.path.join(root, "docs", "abs.txt")
        os.makedirs(os.path.dirname(abs_dl), exist_ok=True)
        with open(abs_dl, "w") as f:
            f.write("x")
        rc, summ, details, perf = verify(root, "T1", store_env=store,
                                         deliverables=[abs_dl])
        self.assertEqual(rc, 0)


class TestVerifyDispatchEmptyDeliverables(unittest.TestCase):
    """SHOULD (T793 brief): a T-id row closed as success with NO deliverables
    declared is UNVERIFIABLE, never PASS — the deliverables arm silently
    disables itself when the declaration is empty, and a PASS resting on the
    nonce alone is exactly the self-report the module refuses to trust.

    Recorded defect, RED as written.  The fix changes the pinned verifier's
    pass/fail contract and collides with tools/regression-runner-brief-
    telemetry.sh arm E (which passes deliverables=[] and asserts the wall-low
    detail on the PASS path); it needs its own row with a regression arm, and
    a decision on the bare-file path (whose documented contract is 'the nonce
    is the whole guard').  The test pins the SHOULD so that row has a red
    test to make green.
    """

    @unittest.expectedFailure
    def test_empty_declaration_reports_unverifiable_never_pass(self):
        root = make_root()
        store = done_pass_store(root)
        rc, summ, details, perf = verify(root, "T1", store_env=store,
                                         deliverables=[])
        self.assertNotEqual(rc, 0)
        self.assertIn("unverifiable", summ.lower())
        # the ledger must not record verified=pass either
        self.assertNotEqual(perf[3], "pass")

    @unittest.expectedFailure
    def test_none_deliverables_same_as_empty(self):
        # None (the signature default) behaves like [] — same silent disable
        root = make_root()
        store = done_pass_store(root)
        rc, summ, details, perf = verify(root, "T1", store_env=store,
                                         deliverables=None)
        self.assertNotEqual(rc, 0)
        self.assertIn("unverifiable", summ.lower())


class TestVerifyDispatchKanban(unittest.TestCase):
    """SHOULD: fail when a row is still in_progress (or dispatchable) after
    the worker exits, whatever the exit code — the kimi incident (rc=0 + 'OK.'
    + row open) is exactly the state the kanban arm exists to catch."""

    def test_open_row_rc0_fails(self):
        root = make_root()
        store = write_store(root, {"T1": {"status": "in_progress"}})
        rc, summ, details, perf = verify(root, "T1", store_env=store,
                                         deliverables=["docs/out.txt"])
        self.assertEqual(rc, 2)
        self.assertIn("never left", summ)
        self.assertEqual(perf, ("T1", "glm-5.2", "incomplete", "fail", "row"))

    def test_dispatchable_row_rc0_fails(self):
        root = make_root()
        store = write_store(root, {"T1": {"status": "dispatchable"}})
        rc, summ, details, perf = verify(root, "T1", store_env=store,
                                         deliverables=["docs/out.txt"])
        self.assertEqual(rc, 2)
        self.assertIn("never left", summ)
        self.assertEqual(perf[4], "row")

    def test_open_row_rc_nonzero_fails(self):
        root = make_root()
        store = write_store(root, {"T1": {"status": "in_progress"}})
        rc, summ, details, perf = verify(root, "T1", rc=1, store_env=store,
                                         deliverables=["docs/out.txt"])
        self.assertEqual(rc, 2)
        self.assertIn("rc=1", summ)
        self.assertEqual(perf[4], "row")

    def test_row_not_found_fails(self):
        root = make_root()
        store = write_store(root, {})
        rc, summ, details, perf = verify(root, "T1", store_env=store,
                                         deliverables=["docs/out.txt"])
        self.assertEqual(rc, 2)
        self.assertIn("not found in store", summ)
        self.assertEqual(perf[4], "row")

    def test_done_row_rc_nonzero_fails_exit(self):
        root = make_root()
        store = done_pass_store(root)
        rc, summ, details, perf = verify(root, "T1", rc=1, store_env=store,
                                         deliverables=["docs/out.txt"])
        self.assertEqual(rc, 2)
        self.assertIn("rc=1", summ)
        self.assertEqual(perf[4], "exit")


class TestVerifyDispatchVerdicts(unittest.TestCase):
    """SHOULD: map verdict -> worker_report; success/fail-found require
    deliverables; blocked/abandoned may produce nothing; an unknown verdict is
    reported, never silently treated as success."""

    def test_pass_with_findings_is_success(self):
        root = make_root()
        store = write_store(root, {"T1": {"status": "done", "verdict": "pass-with-findings"}})
        dl = write_deliverable(root)
        rc, summ, details, perf = verify(root, "T1", store_env=store,
                                         deliverables=[dl])
        self.assertEqual(rc, 0)
        self.assertEqual(perf, ("T1", "glm-5.2", "success", "pass", None))

    def test_abandoned_report_word(self):
        root = make_root()
        store = write_store(root, {"T1": {"status": "done", "verdict": "abandoned"}})
        rc, summ, details, perf = verify(root, "T1", store_env=store,
                                         deliverables=[])
        self.assertEqual(rc, 0)
        self.assertIn("failure-abandoned", perf[2])

    def test_unknown_verdict_reported_not_silent(self):
        # the perf records 'unknown-bogus' and the summary names the verdict —
        # never silently treated as success.  (Cosmetic note, not a defect: the
        # summary says "failure (verdict bogus)" while the perf says
        # "unknown-bogus"; the graded datum is the perf.)
        root = make_root()
        store = write_store(root, {"T1": {"status": "done", "verdict": "bogus"}})
        rc, summ, details, perf = verify(root, "T1", store_env=store,
                                         deliverables=[])
        self.assertEqual(rc, 0)
        self.assertEqual(perf[2], "unknown-bogus")
        self.assertIn("bogus", summ)


class TestVerifyDispatchExitOrdering(unittest.TestCase):
    """SHOULD: for a closed row, exit failures are reported before nonce —
    a worker that closed the row but crashed is a harder failure than one
    that merely failed to echo."""

    def test_exit_reported_before_nonce(self):
        root = make_root()
        store = done_pass_store(root)
        rc, summ, details, perf = verify(root, "T1", rc=1, stdout="no nonce",
                                         store_env=store, deliverables=[])
        self.assertEqual(rc, 2)
        self.assertEqual(perf[4], "exit")


class TestVerifyDispatchRefusalAndDirective(unittest.TestCase):
    """SHOULD: an unreached provider or a directive kill is recorded as such,
    never as a model failure — and the fail perf still names the graded
    row check."""

    def test_unreached_note_and_perf(self):
        root = make_root()
        write_log(root, "T1",
                  "[runner] argv = claude -p '...'\n"
                  "[runner] tokens: no reading — claude api error (is_error=true, zero usage)\n")
        store = write_store(root, {"T1": {"status": "in_progress"}})
        rc, summ, details, perf = verify(root, "T1", rc=1, store_env=store,
                                         deliverables=["docs/out.txt"])
        self.assertEqual(rc, 2)
        self.assertTrue(any("provider refusal" in d for d in details))
        self.assertEqual(perf, ("T1", "glm-5.2", "incomplete", "unreached",
                                "provider-429"))

    def test_directive_kill_note_and_perf(self):
        root = make_root()
        write_run_record(root, "T1", {"killed": "directive D6257 PAUSE",
                                      "kill_class": "directive"})
        store = write_store(root, {"T1": {"status": "in_progress"}})
        rc, summ, details, perf = verify(root, "T1", rc=124, store_env=store,
                                         deliverables=["docs/out.txt"])
        self.assertEqual(rc, 2)
        self.assertTrue(any("directive kill" in d for d in details))
        self.assertEqual(perf, ("T1", "glm-5.2", "incomplete", "directive-kill",
                                "D6257/pause"))


class TestVerifyDispatchWallAdvisory(unittest.TestCase):
    """SHOULD: surface a wall too low for the brief's class as a detail — a
    risk, never a hard fail (T520)."""

    def test_wall_low_detail_surfaced(self):
        root = make_root()
        os.makedirs(os.path.join(root, "untracked"), exist_ok=True)
        open(os.path.join(root, "untracked", "T1-battery-sweep.md"),
             "wb").write(b"Z" * 20000)
        write_run_record(root, "T1", {"brief_bytes": 20000, "prompt_bytes": 21000,
                                      "wall_budget": 1800})
        store = done_pass_store(root)
        dl = write_deliverable(root)
        rc, summ, details, perf = verify(root, "T1", store_env=store,
                                         deliverables=[dl])
        self.assertEqual(rc, 0)
        self.assertTrue(any("wall-low" in d for d in details))

    def test_adequate_wall_silent(self):
        root = make_root()
        write_run_record(root, "T1", {"brief_bytes": 100, "wall_budget": 7200})
        store = done_pass_store(root)
        dl = write_deliverable(root)
        rc, summ, details, perf = verify(root, "T1", store_env=store,
                                         deliverables=[dl])
        self.assertEqual(rc, 0)
        self.assertFalse(any("wall-low" in d for d in details))


class TestVerifyDispatchBareFile(unittest.TestCase):
    """SHOULD: for a bare-file dispatch (no kanban row) the nonce is the whole
    guard; rc!=0, missing nonce, missing deliverables and malformed findings
    each fail loudly."""

    def test_bare_success(self):
        root = make_root()
        rc, summ, details, perf = dv.verify_dispatch(
            root=root, task_id=None, model="m", nonce="NONCE-x",
            stdout="NONCE-x done", rc=0, deliverables=[])
        self.assertEqual(rc, 0)
        self.assertIn("bare-file", summ)
        self.assertEqual(perf, (None, "m", "bare", "pass", None))

    def test_bare_rc_nonzero(self):
        root = make_root()
        rc, summ, details, perf = dv.verify_dispatch(
            root=root, task_id=None, model="m", nonce="NONCE-x",
            stdout="", rc=1, deliverables=[])
        self.assertEqual(rc, 2)
        self.assertEqual(perf[4], "exit")

    def test_bare_nonce_missing(self):
        root = make_root()
        rc, summ, details, perf = dv.verify_dispatch(
            root=root, task_id=None, model="m", nonce="NONCE-x",
            stdout="OK.", rc=0, deliverables=[])
        self.assertEqual(rc, 2)
        self.assertEqual(perf[4], "nonce")

    def test_bare_deliverable_missing(self):
        root = make_root()
        rc, summ, details, perf = dv.verify_dispatch(
            root=root, task_id=None, model="m", nonce="NONCE-x",
            stdout="NONCE-x done", rc=0, deliverables=["docs/never.txt"])
        self.assertEqual(rc, 2)
        self.assertEqual(perf[4], "deliverables")

    def test_bare_findings_malformed(self):
        root = make_root()
        os.makedirs(os.path.join(root, "findings"), exist_ok=True)
        with open(os.path.join(root, "findings", "bare.json"), "w") as f:
            f.write("{ nope")
        rc, summ, details, perf = dv.verify_dispatch(
            root=root, task_id=None, model="m", nonce="NONCE-x",
            stdout="NONCE-x done", rc=0, deliverables=["findings/bare.json"])
        self.assertEqual(rc, 2)
        self.assertEqual(perf[4], "findings")


class TestVerifyDispatchGradedVocabulary(unittest.TestCase):
    """SHOULD: every fail perf's fail_check is in the graded vocabulary
    {nonce, deliverables, findings} ∪ {row, exit} — the exact set
    tools/model-profiles.py grades as recoverable (1) vs unrecoverable (0).
    A novel value would silently grade as unrecoverable and corrupt the
    close-discipline dimension."""

    GRADED = {"nonce", "deliverables", "findings", "row", "exit"}

    def test_every_fail_arm_uses_graded_vocabulary(self):
        root = make_root()
        store_done = done_pass_store(root)
        store_open = write_store(root, {"T1": {"status": "in_progress"}})
        os.makedirs(os.path.join(root, "findings"), exist_ok=True)
        with open(os.path.join(root, "findings", "bad.json"), "w") as f:
            f.write("{ nope")
        scenarios = [
            dict(task_id="T1", store_env=store_open, rc=0, deliverables=["docs/x"]),
            dict(task_id="T1", store_env=store_open, rc=1, deliverables=["docs/x"]),
            dict(task_id="T1", store_env=store_done, rc=1, deliverables=["docs/x"]),
            dict(task_id="T1", store_env=store_done, rc=0, deliverables=["docs/missing.txt"]),
            dict(task_id="T1", store_env=store_done, rc=0, deliverables=["findings/bad.json"]),
            dict(task_id="T1", store_env=store_done, rc=0, stdout="no nonce",
                 deliverables=["docs/out.txt"]),
        ]
        for kw in scenarios:
            rc, summ, details, perf = verify(root, **kw)
            self.assertEqual(rc, 2, summ)
            self.assertIn(perf[4], self.GRADED,
                          "novel fail_check %r would corrupt the graded "
                          "dimension (model-profiles RECOVERABLE_FAIL)" % (perf[4],))


# ── heal_dispatch ──────────────────────────────────────────────────────────

class TestHealDispatch(unittest.TestCase):
    """SHOULD: reopen ONLY the row whose worker was just watched die (rc!=0,
    row in_progress, not a kill-directive); write the assertion record; never
    touch the tree.  F4/T513: the heals log is the census of reopeners."""

    def _heals_path(self, root):
        return os.path.join(root, "heals.jsonl")

    HEALS_ENV = "WEIZIGO_DISPATCH_HEALS"

    def _run(self, root, task_id="T1", rc=1, status="in_progress",
             mg_rc=0, directive_kill=None, real_root=None):
        store = write_store(root, {task_id: {"status": status}})
        # subprocess.run(...) RETURNS the mock's return_value — configuring the
        # mock's own attributes would leave the caller holding an auto-Mock.
        fake = mock.Mock()
        fake.return_value.returncode = mg_rc
        fake.return_value.stdout = ""
        fake.return_value.stderr = ""
        # assert_path_env is the NAME of the env var (production default
        # WEIZIGO_DISPATCH_HEALS), so the test sets the var to a temp path.
        env = {self.HEALS_ENV: self._heals_path(root)}
        with mock.patch.object(dv.subprocess, "run", fake), \
                mock.patch.dict(os.environ, env):
            return dv.heal_dispatch(
                root=root, real_root=real_root or root, task_id=task_id,
                model="glm-5.2", rc=rc, wall_seconds=12.34,
                store_env=store, assert_path_env=self.HEALS_ENV,
                directive_kill=directive_kill)

    def test_task_id_none_noop(self):
        root = make_root()
        healed, line = self._run(root, task_id=None)
        self.assertFalse(healed)
        self.assertEqual(line, "")

    def test_row_done_noop(self):
        root = make_root()
        healed, line = self._run(root, status="done")
        self.assertFalse(healed)
        self.assertEqual(line, "")

    def test_rc_zero_noop(self):
        # the kimi incident (rc=0, did nothing) is investigated, not auto-healed
        root = make_root()
        healed, line = self._run(root, rc=0)
        self.assertFalse(healed)
        self.assertEqual(line, "")

    def test_kill_directive_noop(self):
        # a `kill` directive is a STAND DOWN — reopening would re-launch it
        root = make_root()
        healed, line = self._run(root, directive_kill="D6257/kill")
        self.assertFalse(healed)
        self.assertIn("not healed", line)

    def test_watched_die_heals_and_records(self):
        root = make_root()
        healed, line = self._run(root)
        self.assertTrue(healed)
        self.assertIn("reopened T1", line)
        recs = [json.loads(l) for l in
                open(self._heals_path(root)).read().splitlines()]
        self.assertEqual(len(recs), 1)
        self.assertEqual(recs[0]["task_id"], "T1")
        self.assertEqual(recs[0]["healed_by"], dv.HEAL_OWNER)
        self.assertEqual(recs[0]["exit_code"], 1)
        self.assertEqual(recs[0]["wall_seconds"], 12.3)

    def test_reopen_failure_reported_not_healed(self):
        root = make_root()
        healed, line = self._run(root, mg_rc=1)
        self.assertFalse(healed)
        self.assertIn("heal FAILED", line)

    def test_pause_directive_heals_normally(self):
        # a pause heals — the next dispatch re-runs the directive gate
        root = make_root()
        healed, line = self._run(root, directive_kill="D6257/pause")
        self.assertTrue(healed)

    def test_assertion_write_failure_still_reports_heal(self):
        root = make_root()
        store = write_store(root, {"T1": {"status": "in_progress"}})
        # point the heals log at a path whose parent is a FILE -> OSError
        blocker = os.path.join(root, "blocker")
        with open(blocker, "w") as f:
            f.write("x")
        fake = mock.Mock()
        fake.return_value.returncode = 0
        fake.return_value.stdout = ""
        fake.return_value.stderr = ""
        env = {self.HEALS_ENV: os.path.join(blocker, "heals.jsonl")}
        with mock.patch.object(dv.subprocess, "run", fake), \
                mock.patch.dict(os.environ, env):
            healed, line = dv.heal_dispatch(
                root=root, real_root=root, task_id="T1", model="m", rc=1,
                wall_seconds=1.0, store_env=store,
                assert_path_env=self.HEALS_ENV)
        self.assertTrue(healed)
        self.assertIn("ASSERTION WRITE FAILED", line)


# ── record_perf ────────────────────────────────────────────────────────────

class TestRecordPerf(unittest.TestCase):
    """SHOULD: one append-only line per dispatch with killed_by=<enum> at the
    end; a write failure is a loud warning and False, never a crash."""

    def _perf_path(self, root):
        return os.path.join(root, "perf.md")

    def test_line_format_pass(self):
        root = make_root()
        p = self._perf_path(root)
        with mock.patch.dict(os.environ, {"WEIZIGO_MODEL_PERF": p}):
            ok = dv.record_perf(root, ("T1", "glm-5.2", "success", "pass", None))
        self.assertTrue(ok)
        line = open(p).read().strip()
        self.assertRegex(
            line,
            r"^dispatch-verify \d{4}-\d{2}-\d{2} T1 glm-5\.2 report=success "
            r"verified=pass killed_by=none$")

    def test_fail_line_carries_fail_check(self):
        root = make_root()
        p = self._perf_path(root)
        with mock.patch.dict(os.environ, {"WEIZIGO_MODEL_PERF": p}):
            dv.record_perf(root, ("T1", "glm-5.2", "success", "fail", "nonce"))
        line = open(p).read().strip()
        self.assertIn("verified=fail fail=nonce killed_by=none", line)

    def test_unreached_line_carries_reason(self):
        root = make_root()
        p = self._perf_path(root)
        with mock.patch.dict(os.environ, {"WEIZIGO_MODEL_PERF": p}):
            dv.record_perf(root, ("T1", "glm-5.2", "incomplete", "unreached",
                                  "provider-429"))
        line = open(p).read().strip()
        self.assertIn("verified=unreached reason=provider-429 killed_by=none", line)

    def test_directive_kill_line_carries_reason(self):
        root = make_root()
        p = self._perf_path(root)
        with mock.patch.dict(os.environ, {"WEIZIGO_MODEL_PERF": p}):
            dv.record_perf(root, ("T1", "glm-5.2", "incomplete", "directive-kill",
                                  "D6257/pause"))
        line = open(p).read().strip()
        self.assertIn("verified=directive-kill reason=D6257/pause killed_by=none", line)

    def test_append_only(self):
        root = make_root()
        p = self._perf_path(root)
        with mock.patch.dict(os.environ, {"WEIZIGO_MODEL_PERF": p}):
            dv.record_perf(root, ("T1", "glm-5.2", "success", "pass", None))
            dv.record_perf(root, ("T2", "glm-5.2", "success", "pass", None))
        self.assertEqual(len(open(p).read().splitlines()), 2)

    def test_write_failure_is_false_not_crash(self):
        root = make_root()
        blocker = os.path.join(root, "blocker")
        with open(blocker, "w") as f:
            f.write("x")
        with mock.patch.dict(os.environ,
                             {"WEIZIGO_MODEL_PERF": os.path.join(blocker, "perf.md")}):
            ok = dv.record_perf(root, ("T1", "glm-5.2", "success", "pass", None))
        self.assertFalse(ok)


# ── scan_findings / main ───────────────────────────────────────────────────

class TestScanFindings(unittest.TestCase):
    """SHOULD: yield (relpath, errors) per findings/*.json, skipping
    rejections.json; a missing findings/ yields nothing."""

    def test_valid_and_invalid(self):
        root = make_root()
        os.makedirs(os.path.join(root, "findings"), exist_ok=True)
        with open(os.path.join(root, "findings", "a.json"), "w") as f:
            json.dump({"task_id": "T1", "date": "2026-08-23", "model": "m",
                       "claims": []}, f)
        with open(os.path.join(root, "findings", "b.json"), "w") as f:
            f.write("{ nope")
        got = dict(dv.scan_findings(root))
        self.assertEqual(got[os.path.join("findings", "a.json")], [])
        self.assertEqual(len(got[os.path.join("findings", "b.json")]), 1)

    def test_skips_rejections_and_non_json(self):
        root = make_root()
        os.makedirs(os.path.join(root, "findings"), exist_ok=True)
        with open(os.path.join(root, "findings", "rejections.json"), "w") as f:
            f.write("{ nope")  # would be malformed if scanned — must be skipped
        with open(os.path.join(root, "findings", "notes.txt"), "w") as f:
            f.write("x")
        self.assertEqual(list(dv.scan_findings(root)), [])

    def test_missing_directory_yields_nothing(self):
        root = make_root()
        self.assertEqual(list(dv.scan_findings(root)), [])


class TestMain(unittest.TestCase):
    """SHOULD: --dry-run over findings/ (0 clean, 2 naming each malformed
    file); --census <ledger> runs the historical census; unknown flags are
    ignored so the acceptance line can evolve."""

    # argv[0] is the program name (production: sys.argv); main parses argv[1:].
    PROG = "dispatch_verify.py"

    def _quiet_main(self, argv):
        """Run main with stdout captured (it prints its verdict line)."""
        import io
        buf = io.StringIO()
        with mock.patch.object(sys, "stdout", buf):
            return dv.main(argv), buf.getvalue()

    def test_dry_run_clean(self):
        root = make_root()
        os.makedirs(os.path.join(root, "findings"), exist_ok=True)
        with open(os.path.join(root, "findings", "a.json"), "w") as f:
            json.dump({"task_id": "T1", "date": "2026-08-23", "model": "m",
                       "claims": []}, f)
        rc, out = self._quiet_main([self.PROG, "--root", root])
        self.assertEqual(rc, 0)
        self.assertIn("findings parse clean", out)

    def test_dry_run_malformed_names_files(self):
        root = make_root()
        os.makedirs(os.path.join(root, "findings"), exist_ok=True)
        with open(os.path.join(root, "findings", "bad.json"), "w") as f:
            f.write("{ nope")
        rc, out = self._quiet_main([self.PROG, "--root", root])
        self.assertEqual(rc, 2)
        self.assertIn("bad.json", out)

    def test_unknown_flag_ignored(self):
        root = make_root()
        rc, _out = self._quiet_main([self.PROG, "--root", root, "--future-flag"])
        self.assertEqual(rc, 0)

    def test_root_equals_form(self):
        root = make_root()
        os.makedirs(os.path.join(root, "findings"), exist_ok=True)
        with open(os.path.join(root, "findings", "bad.json"), "w") as f:
            f.write("{ nope")
        rc, out = self._quiet_main([self.PROG, "--root=%s" % root])
        self.assertEqual(rc, 2)
        self.assertIn("bad.json", out)

    def test_census_missing_ledger_returns_2(self):
        root = make_root()
        rc, _out = self._quiet_main([self.PROG, "--root", root, "--census",
                                     os.path.join(root, "no-ledger.md")])
        self.assertEqual(rc, 2)

    def test_census_runs_and_prints_unknown(self):
        root = make_root()
        ledger = os.path.join(root, "perf.md")
        with open(ledger, "w") as f:
            f.write("dispatch-verify 2026-08-23 T9999 glm-5.2 report=fail "
                    "verified=fail fail=row killed_by=none\n")
        rc, out = self._quiet_main([self.PROG, "--root", root, "--census", ledger])
        self.assertEqual(rc, 0)
        self.assertIn("T9999", out)


# ── census chain (T630 historical ledger) ──────────────────────────────────

class TestTrailerClassify(unittest.TestCase):
    """SHOULD: classify the log's own terminal [runner] exit/KILL line;
    (None, None) when the log has no runner trailer."""

    def test_wall_trailer(self):
        lines = ["worker noise", "[runner] exit 124 (wall ceiling 1800s reached)"]
        self.assertEqual(dv._trailer_classify(lines), ("wall", "trailer"))

    def test_rss_kill_trailer(self):
        lines = ["[runner] KILL: rss cap 4096 MB exceeded"]
        self.assertEqual(dv._trailer_classify(lines), ("rss", "trailer"))

    def test_clean_exit_trailer(self):
        lines = ["[runner] exit 0"]
        self.assertEqual(dv._trailer_classify(lines), ("none", "trailer"))

    def test_directive_trailer(self):
        lines = ["[runner] exit 124 (directive: pause)"]
        self.assertEqual(dv._trailer_classify(lines), ("directive", "trailer"))

    def test_no_runner_trailer(self):
        self.assertEqual(dv._trailer_classify(["worker", "[runner] argv = ..."]),
                         (None, None))

    def test_last_trailer_wins(self):
        lines = ["[runner] exit 124 (wall ceiling 1800s reached)",
                 "[runner] exit 1"]
        self.assertEqual(dv._trailer_classify(lines), ("none", "trailer"))


class TestCensusClassify(unittest.TestCase):
    """SHOULD: best-effort killed_by from refusal / record / trailer evidence;
    UNKNOWN when no evidence is kept — never a blank."""

    def test_refusal_evidence(self):
        root = make_root()
        write_run_record(root, "T901", {"killed": "progress timeout"})
        write_log(root, "T901",
                  "[runner] argv = claude -p '...'\n"
                  "[runner] tokens: no reading — claude api error (is_error=true, zero usage)\n")
        self.assertEqual(dv.census_classify(root, "T901", "fail"),
                         ("provider-limit", "refusal"))

    def test_record_stamp(self):
        root = make_root()
        write_run_record(root, "T902", {"killed_by": "wall"})
        self.assertEqual(dv.census_classify(root, "T902", "fail"),
                         ("wall", "record-stamp"))

    def test_record_killed(self):
        root = make_root()
        write_run_record(root, "T903", {"killed": "progress timeout 600s"})
        self.assertEqual(dv.census_classify(root, "T903", "fail"),
                         ("watchdog", "record"))

    def test_trailer_evidence(self):
        root = make_root()
        write_log(root, "T904", "[runner] exit 124 (wall ceiling 1800s reached)")
        self.assertEqual(dv.census_classify(root, "T904", "fail"),
                         ("wall", "trailer"))

    def test_no_evidence_is_unknown(self):
        root = make_root()
        self.assertEqual(dv.census_classify(root, "T905", "fail"),
                         ("UNKNOWN", "no-evidence"))

    def test_stale_clean_record_ignored(self):
        # a later run's exit-0 record is not the failed row's own evidence
        root = make_root()
        write_run_record(root, "T906", {"exit": 0})
        write_log(root, "T906", "[runner] exit 0")
        self.assertEqual(dv.census_classify(root, "T906", "fail"),
                         ("UNKNOWN", "no-evidence"))


class TestRunCensus(unittest.TestCase):
    """SHOULD: classify every rc!=0 ledger row and print the direction table;
    a missing ledger exits 2."""

    def test_missing_ledger(self):
        root = make_root()
        self.assertEqual(dv.run_census(root, os.path.join(root, "none.md")), 2)

    def test_classifies_rows_and_counts_directions(self):
        root = make_root()
        ledger = os.path.join(root, "perf.md")
        with open(ledger, "w") as f:
            f.write("dispatch-verify 2026-08-23 T910 glm-5.2 report=fail "
                    "verified=fail fail=row killed_by=none\n")
            f.write("dispatch-verify 2026-08-23 T911 glm-5.2 report=fail "
                    "verified=fail fail=row killed_by=wall\n")
        import io
        buf = io.StringIO()
        with mock.patch.object(sys, "stdout", buf):
            rc = dv.run_census(root, ledger)
        self.assertEqual(rc, 0)
        out = buf.getvalue()
        self.assertIn("T910", out)
        self.assertIn("T911", out)
        self.assertIn("unknown=2", out)  # no evidence kept for either

    def test_pass_rows_are_skipped(self):
        root = make_root()
        ledger = os.path.join(root, "perf.md")
        with open(ledger, "w") as f:
            f.write("dispatch-verify 2026-08-23 T912 glm-5.2 report=success "
                    "verified=pass killed_by=none\n")
        import io
        buf = io.StringIO()
        with mock.patch.object(sys, "stdout", buf):
            rc = dv.run_census(root, ledger)
        self.assertEqual(rc, 0)
        self.assertIn("0 rc!=0 rows", buf.getvalue())


if __name__ == "__main__":
    unittest.main()
