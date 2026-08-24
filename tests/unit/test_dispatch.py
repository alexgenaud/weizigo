"""Unit tests for bin/dispatch (T805).

============================================================================
HALF A — top down: what is `bin/dispatch` for, does each of its 7 functions
earn its place?  (546 lines, 7 functions.)
`bin/dispatch` is the ONE door a dispatch should go through: it canonicalizes
the model tag, re-checks every registration-time gate (row state, bundle
uniqueness, title, landmark, directives, provider window), then detaches
bin/subagent with the nonce/session layer that 159 of 364 measured provider
executions skipped by routing underneath it.  It has no importers — nothing
treats it as a library — so "who calls it" means "which code path inside THIS
file reaches it"; "production caller" of main() is the `__main__` block plus
tools/regression-dispatch.sh's controls (spawned as a process).

 # function                    for                                            called by (production)      last touched        vanish unnoticed?
 -- --------------------------- ---------------------------------------------- ---------------------------- ------------------- ------------------------------------------------------
 1  canonicalize_model         dispatch tag -> canonical label (aliases,      resolve_model                2026-08-23 T732     NO — every shorthand/cloud/stealth dispatch refuses;
                               :cloud, kimi -code, stealth/)                                                                   the ledger stops attributing (the serving-tag defect)
 2  resolve_model              raw tag -> (canonical, err, provider, flags)   main()                       2026-08-23 T732     NO — no dispatch can name a model; the whole door jams
 3  row_state*                kanban rows via bin/managent status --json   main() (as the shared   2026-08-24 T845     NO — the T350/T376/T389 duplicate-dispatch hazard
                             (subprocess) — *T845 moved the seam to the     snapshot; fleet_caps)                           returns: in_progress rows re-dispatch freely
                             SHARED helper tools/fleet_caps.read_rows, so
                             the row-state / probe / caps gates read the
                             SAME rows; row_state itself is gone from this
                             file
 4  _contains_valid_landmark_id text contains a valid L<id> token             _landmark_line_verdict       2026-08-23 T747     NO — every Landmark line reads "invalid", every brief
                                                                                                                                with a valid id refuses; dispatch grinds to a halt
 5  _landmark_line_verdict     one **Landmark:** line -> declared/invalid,    bundle_landmark_verdict      2026-08-23 T747     NO — same halt as #4, one level up
                               or None if the line is not one
 6  bundle_landmark_verdict    whole-bundle landmark scan (blockquote/bullet  main()                       2026-08-23 T747     NO — the T740–T744 no-landmark incident class returns
                               aware), mirroring managent's T682 gate
 7  main                       parse argv, run every gate IN ORDER, detach    __main__; tools/             2026-08-23 T766     NO — it is the entire program
                               bin/subagent or print the dry-run              regression-dispatch.sh

DELETION CANDIDATES: none.  All 7 functions have a live production caller
inside this file and were touched within the last week (T476/T494/T505 era
through T732/T747/T766, most recently yesterday); none is dead weight.  One
HALF-A SIDE FINDING, cleaned up in this row: the usage docstring still
advertised `[--override-window-budget=<reason>]` after T766 retired the
predictive window-budget gate (cf7fc68) — passing it fell through to the
generic unknown-flag refusal.  Docstring fixed here (usage surface only; no
behaviour change — an arm below pins the retirement).

============================================================================
HALF B — bottom up: what each survivor SHOULD do, red or green on first run.
All arms are stdlib-only, subprocess-free (bin/managent and window_policy are
mocked at the seam bin/dispatch itself defines: row_state / directive_policy /
window_policy / subprocess.run), host-insensitive, and write nothing outside
a tempfile directory.

First-run colours (2026-08-23, ox-alpha/T805):
  * RED (1): TestModelResolution.test_every_registry_short_name_accepted —
    docs/infra/model-registry.md §"Short names" is ruled THE one short-name
    mapping (T739), but bin/dispatch's ALIASES carries only dspro/dsflash,
    so opus/fable/sonnet/haiku/glm/minimax/kimi/qwen/oxalpha refuse at the
    dispatch door.  Owned by T801 (one-canonicalizer: four copies of this
    transform exist and T801 is collapsing them).  @unittest.expectedFailure.
  * GREEN: everything else, including the two CHARACTERIZATIONs below.
  * One docstring-only cleanup (no behaviour change): stale
    --override-window-budget usage removed (T766 retired that gate).

CHARACTERIZATION 1 (TestModelResolution.test_kimi_broken_cloud_tag_routes_clean):
docs/infra/model-registry.md documents `kimi-k2.7:cloud` as returning
`Error: model 'kimi-k2.7' not found` — "do NOT dispatch" — yet
canonicalize_model strips :cloud and routes it identically to its working
sibling kimi-k2.7-code:cloud.  T792 recorded the same gap in bin/subagent's
copy of the table; this is bin/dispatch's copy.  Left green+marked (shared
cross-language contract; T801 owns the collapse).

CHARACTERIZATION 2 (TestLandmark.test_none_prefix_wins_over_later_valid_id):
a Landmark line starting "none ..." declares none-directly even if a valid
L<id> appears later in the line — the none-form check runs before the id
scan.  Mirrors managent's checkBundleLandmark verdict order; pinned, not
changed.

The wall advisory the brief describes lives NOT in bin/dispatch but in
tools/dispatch_verify.py (`wall_advisory`, WALL_GUIDANCE), already unit-
tested in tests/unit/test_dispatch_verify.py — bin/dispatch only parses and
forwards --wall (default 2700).  No red arm here; the attribution is
recorded in findings/T805-unit-tests.json.

Veto-leaves-task-dispatchable rule (standing: idle is acceptable, killing a
running task is not): TestGateComposition asserts on every veto path that
nothing is spawned and nothing is written under the root — a refused
dispatch leaves the row exactly as dispatchable as before.
"""
import contextlib
import io
import json
import os
import re
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)
import _load  # noqa: E402

dp = _load.load("bin/dispatch", name="t805_dispatch")

REPO = _load.REPO


def _fake_completed(stdout="", returncode=0):
    return subprocess.CompletedProcess(args=["x"], returncode=returncode,
                                       stdout=stdout)


class EnvIsolatedTestCase(unittest.TestCase):
    """Base: snapshot/restore os.environ so no test leaks a reading into another."""

    def setUp(self):
        self._environ_snapshot = dict(os.environ)

    def tearDown(self):
        os.environ.clear()
        os.environ.update(self._environ_snapshot)

    def temp_root(self):
        tmp = tempfile.mkdtemp(prefix="t805-dispatch-")
        self.addCleanup(lambda: __import__("shutil").rmtree(tmp, True))
        os.makedirs(os.path.join(tmp, "untracked"), exist_ok=True)
        return tmp

    def write_bundle(self, root, task_id="T9999", title="unit fixture brief",
                     landmark="advances `L1 (dispatch tooling)` — fixture arm"):
        lines = ["# %s — %s" % (task_id, title), ""]
        if landmark is not None:
            lines.append("**Landmark:** %s" % landmark)
            lines.append("")
        lines.append("body")
        path = os.path.join(root, "untracked", "%s-fixture.md" % task_id)
        with open(path, "w", encoding="utf-8") as f:
            f.write("\n".join(lines) + "\n")
        return path

    def run_main(self, argv, root=None, status="dispatchable",
                 identifier="deepseek-v4-pro/T000", directives=((), ()),
                 cooldown=None, probe_active=False, inprog=0,
                 rows_json='[{"id": "T9999", "status": "dispatchable", '
                            '"identifier": "x"}]',
                 extra_patches=None, depth=1):
        """Run dp.main(argv) with every fleet touchpoint injected.

        depth injects WEIZIGO_AGENT_DEPTH (this console itself runs at the
        cap, so the default here must be an under-cap reading).  Returns
        (exit_or_0, stdout_text, stderr_text, spawned[bool]).
        """
        out, err = io.StringIO(), io.StringIO()
        spawned = []
        ctx = [mock.patch.dict(os.environ,
                               {"WEIZIGO_AGENT_DEPTH": str(depth)})]
        if root is not None:
            # main() resolves the repo root itself (ROOT vs --test-root),
            # so a fixture root reaches it ONLY through the documented seam.
            if not any(a.startswith("--test-root=") for a in argv):
                argv = [*argv, "--test-root=%s" % os.path.abspath(root)]
            # T845: the kanban snapshot comes from the SHARED helper
            # (tools/fleet_caps.py) — the row-state, probe and fleet-cap
            # gates all read the SAME rows; the seam moved there with it.
            rows = json.loads(rows_json)
            if status is None:
                rows = [r for r in rows if r.get("id") != "T9999"]
            else:
                rows = [dict(r) for r in rows]
                for r in rows:
                    if r.get("id") == "T9999":
                        r["status"] = status
                        r["identifier"] = identifier
            ctx.append(mock.patch.object(dp.fleet_caps, "read_rows",
                                         return_value=rows))
            ctx.append(mock.patch.object(dp.directive_policy,
                                         "evaluate_directives",
                                         return_value=(
                                             list(directives[0]),
                                             list(directives[1]))))
            cds = {} if cooldown is None else {"claude": cooldown}
            ctx.append(mock.patch.object(dp.window_policy, "family_cooldown",
                                         return_value=cds))
            ctx.append(mock.patch.object(dp.window_policy, "probe_active",
                                         return_value=probe_active))
            ctx.append(mock.patch.object(dp.window_policy,
                                         "family_inprog_count",
                                         return_value=inprog))

        def fake_run(*a, **k):
            return _fake_completed(stdout=rows_json)

        ctx.append(mock.patch.object(dp.subprocess, "run", fake_run))

        def no_spawn(*a, **k):
            spawned.append(a)
            raise AssertionError("bin/dispatch spawned a worker during a "
                                 "unit arm: %r" % (a,))
        ctx.append(mock.patch.object(dp.subprocess, "Popen", no_spawn))
        if extra_patches:
            ctx.extend(extra_patches)
        code = 0
        try:
            with contextlib.ExitStack() as stack:
                for c in ctx:
                    stack.enter_context(c)
                with contextlib.redirect_stdout(out), \
                        contextlib.redirect_stderr(err):
                    rc = dp.main(argv)
            code = rc if rc is not None else 0
        except SystemExit as e:
            code = e.code
        return code, out.getvalue(), err.getvalue(), spawned


# ---------------------------------------------------------------------------
# 1+2. canonicalize_model / resolve_model — the model-resolution decision
# ---------------------------------------------------------------------------

def _registry_canonical_labels():
    """Parse the canonical label block straight out of the registry doc —
    table-driven from the source of truth (bin/managent models mirror),
    not from a hand-copied list."""
    path = os.path.join(REPO, "docs", "infra", "model-registry.md")
    with open(path, encoding="utf-8") as f:
        text = f.read()
    start = text.index("## Canonical labels")
    fence = text.index("```", start)
    end = text.index("```", fence + 3)
    labels = []
    for ln in text[fence + 3:end].splitlines():
        for piece in ln.split("·"):
            piece = piece.strip()
            if piece:
                labels.append(piece)
    return labels


def _registry_short_names():
    """Parse §Short names → canonical: [(short, canonical), ...]."""
    path = os.path.join(REPO, "docs", "infra", "model-registry.md")
    with open(path, encoding="utf-8") as f:
        text = f.read()
    start = text.index("## Short names")
    end = text.index("## ", start + 10)
    pairs = []
    for m in re.finditer(r"^\| `([^`]+)` \| `([^`]+)` \|(?!$)",
                         text[start:end], re.M):
        pairs.append((m.group(1), m.group(2)))
    return pairs


class TestCanonicalizeModel(EnvIsolatedTestCase):
    """SHOULD: turn any accepted dispatch tag into the exact canonical label
    managent's canonicalizeModelTag produces (aliases, :cloud strip, kimi
    -code variant, stealth serving tag), and leave canonical labels alone."""

    def test_canonical_labels_pass_through(self):
        for label in _registry_canonical_labels():
            if label in ("kimi-k2.7-code",):  # not itself canonical
                continue
            with self.subTest(label=label):
                self.assertEqual(dp.canonicalize_model(label), label)

    def test_cloud_suffix_stripped(self):
        for tag, want in [("glm-5.2:cloud", "glm-5.2"),
                          ("minimax-m3:cloud", "minimax-m3"),
                          ("kimi-k2.7:cloud", "kimi-k2.7"),
                          ("qwen3.8:27b-mlx:cloud", "qwen3.8:27b-mlx")]:
            with self.subTest(tag=tag):
                self.assertEqual(dp.canonicalize_model(tag), want)

    def test_kimi_code_variant_and_combo(self):
        self.assertEqual(dp.canonicalize_model("kimi-k2.7-code"), "kimi-k2.7")
        self.assertEqual(dp.canonicalize_model("kimi-k2.7-code:cloud"),
                         "kimi-k2.7")

    def test_ds_aliases(self):
        self.assertEqual(dp.canonicalize_model("dspro"), "deepseek-v4-pro")
        self.assertEqual(dp.canonicalize_model("dsflash"), "deepseek-v4-flash")

    def test_stealth_serving_tag_maps_to_ledger_label(self):
        # The serving tag must never reach the ledger; the canonical label must.
        self.assertEqual(dp.canonicalize_model("stealth/ox-alpha"), "ox-alpha")


class TestModelResolution(EnvIsolatedTestCase):
    """SHOULD: accept every tag in docs/infra/model-registry.md, route it to
    the right provider with the right subagent flags, and refuse an unknown
    tag LOUDLY instead of passing it through."""

    PROVIDER_OF = {
        "claude-opus-5": "claude", "claude-sonnet-5": "claude",
        "claude-fable-5": "claude", "claude-haiku-4-5-20251001": "claude",
        "deepseek-v4-pro": "deepseek", "deepseek-v4-flash": "deepseek",
        "glm-5.2": "ollama", "minimax-m3": "ollama",
        "kimi-k2.7": "ollama", "qwen3.8:27b-mlx": "ollama",
        "ox-alpha": "pi",
    }

    def test_registry_sync_MODELS_covers_exactly_the_registry(self):
        # Table-driven: both directions, against the parsed registry doc.
        self.assertEqual(set(dp.MODELS), set(_registry_canonical_labels()))

    def test_every_canonical_label_resolves_with_provider(self):
        for label, provider in sorted(self.PROVIDER_OF.items()):
            with self.subTest(label=label):
                canon, err, prov, flags = dp.resolve_model(label)
                self.assertIsNone(err)
                self.assertEqual(canon, label)
                self.assertEqual(prov, provider)
                self.assertTrue(flags)

    def test_serving_tags_route_and_never_store_the_tag(self):
        table = [
            ("glm-5.2:cloud", "glm-5.2", "ollama"),
            ("kimi-k2.7-code", "kimi-k2.7", "ollama"),
            ("kimi-k2.7-code:cloud", "kimi-k2.7", "ollama"),
            ("minimax-m3:cloud", "minimax-m3", "ollama"),
            ("qwen3.8:27b-mlx:cloud", "qwen3.8:27b-mlx", "ollama"),
            ("dspro", "deepseek-v4-pro", "deepseek"),
            ("dsflash", "deepseek-v4-flash", "deepseek"),
            ("stealth/ox-alpha", "ox-alpha", "pi"),
        ]
        for raw, canon, provider in table:
            with self.subTest(raw=raw):
                got, err, prov, flags = dp.resolve_model(raw)
                self.assertIsNone(err)
                self.assertEqual(got, canon)
                self.assertEqual(prov, provider)
                # the serving tag itself must appear in FLAGS at most, and
                # ox-alpha's pi tag is exactly stealth/ox-alpha (T732).
                if raw == "stealth/ox-alpha":
                    self.assertIn("stealth/ox-alpha", flags)
                    self.assertNotIn("ox-alpha", flags)

    def test_unknown_tag_refused_loudly(self):
        canon, err, _, _ = dp.resolve_model("made-up-model-v9")
        self.assertIsNone(canon)
        self.assertIsNotNone(err)
        self.assertIn("refused", err)
        self.assertIn("made-up-model-v9", err)
        # loud = actionable: the error names what IS dispatchable
        self.assertIn("deepseek-v4-pro", err)

    # RED first run 2026-08-23: registry §Short names is THE one mapping
    # (T739) but bin/dispatch ALIASES carries only dspro/dsflash — owned by
    # T801 (one-canonicalizer).
    @unittest.expectedFailure
    def test_every_registry_short_name_accepted(self):
        """SHOULD: accept every short name in the registry's ONE short-name
        table (opus/fable/sonnet/haiku/glm/minimax/kimi/qwen/dspro/dsflash/
        oxalpha), exactly like the human surfaces do.  RED on first run
        2026-08-23; owning row T801 (one-canonicalizer)."""
        shorts = _registry_short_names()
        self.assertGreaterEqual(len(shorts), 11)
        for short, canonical in shorts:
            with self.subTest(short=short):
                canon, err, _, _ = dp.resolve_model(short)
                self.assertIsNone(err, "short name %r refused" % short)
                self.assertEqual(canon, canonical)

    def test_kimi_broken_cloud_tag_routes_clean(self):
        """CHARACTERIZATION: registry documents kimi-k2.7:cloud as
        'Error: model not found — do NOT dispatch', yet it routes clean,
        identical to its working sibling kimi-k2.7-code:cloud.  Same gap
        T792 recorded in bin/subagent's copy; T801 owns the collapse."""
        canon, err, _, _ = dp.resolve_model("kimi-k2.7:cloud")
        self.assertIsNone(err)
        self.assertEqual(canon, "kimi-k2.7")


# ---------------------------------------------------------------------------
# 3. kanban snapshot — read via the shared helper (T845)
# ---------------------------------------------------------------------------

class TestRowState(EnvIsolatedTestCase):
    """SHOULD: read bin/managent status --json and return the rows; None
    (not a crash) when the store cannot be read; resolve the store exactly
    like bin/dispatch's old row_state did (MANAGENT_STORE env, else the
    root default), forwarding it to the managent subprocess.  T845 moved
    the seam from bin/dispatch.row_state into the SHARED helper
    tools/fleet_caps.py — the keeper reads the same function's counters —
    so this class tests the helper's read path now."""

    def run_read_rows(self, stdout, store_env=None):
        captured = {}

        def fake_run(cmd, capture_output, text, env, timeout):
            captured["cmd"] = cmd
            captured["env"] = env
            return _fake_completed(stdout=stdout)

        env = {}
        if store_env:
            env["MANAGENT_STORE"] = store_env
        with mock.patch.dict(os.environ, env, clear=False):
            with mock.patch.object(dp.fleet_caps.subprocess, "run", fake_run):
                rows = dp.fleet_caps.read_rows("/tmp/some-root")
        return rows, captured

    def test_found_rows_returned_in_order(self):
        rows_json = json.dumps([
            {"id": "T1234", "status": "in_progress",
             "identifier": "deepseek-v4-flash/T350"},
            {"id": "T9999", "status": "dispatchable", "identifier": "x"}])
        rows, captured = self.run_read_rows(rows_json)
        self.assertEqual(len(rows), 2)
        self.assertEqual(rows[1]["status"], "dispatchable")
        self.assertEqual(rows[1]["id"], "T9999")
        self.assertTrue(captured["cmd"][0].endswith("bin/managent"))

    def test_absent_row_just_missing_from_rows(self):
        rows, _ = self.run_read_rows(json.dumps([]))
        self.assertEqual(rows, [])

    def test_non_json_store_returns_none_not_a_crash(self):
        rows, _ = self.run_read_rows("<html>not json</html>")
        self.assertIsNone(rows)

    def test_managent_store_env_is_honoured_and_forwarded(self):
        rows, captured = self.run_read_rows(
            json.dumps([{"id": "T9999", "status": "done"}]),
            store_env="/tmp/alt-store.json")
        self.assertEqual(rows[0]["status"], "done")
        self.assertEqual(captured["env"]["MANAGENT_STORE"], "/tmp/alt-store.json")

    def test_store_default_resolves_under_the_root(self):
        _, captured = self.run_read_rows("[]")
        self.assertEqual(
            captured["env"]["MANAGENT_STORE"],
            os.path.join("/tmp/some-root", "docs", "infra",
                         "managent", "tasks.json"))


# ---------------------------------------------------------------------------
# 4-6. landmark helpers — pure functions
# ---------------------------------------------------------------------------

class TestLandmark(EnvIsolatedTestCase):
    """SHOULD: mirror src/managent/main.zig checkBundleLandmark exactly —
    declared / absent / invalid, blockquote- and bullet-aware, one level deep."""

    def test_declared_advances_form(self):
        self.assertEqual(dp.bundle_landmark_verdict(
            "**Landmark:** advances `L2 (proven 4×4 values)` — x")[0],
            "declared")

    def test_declared_none_directly_form(self):
        v = dp.bundle_landmark_verdict(
            "**Landmark:** none directly; unblocks T400")
        self.assertEqual(v, ("declared", None))

    def test_absent_when_no_line(self):
        self.assertEqual(dp.bundle_landmark_verdict("no landmark here\nat all"),
                         ("absent", None))

    def test_invalid_when_garbage_after_marker(self):
        v = dp.bundle_landmark_verdict("**Landmark:** vibes")
        self.assertEqual(v[0], "invalid")
        self.assertEqual(v[1], "vibes")

    def test_invalid_empty_marker(self):
        self.assertEqual(dp.bundle_landmark_verdict("**Landmark:**")[0],
                         "invalid")

    def test_invalid_unknown_id(self):
        v = dp.bundle_landmark_verdict("**Landmark:** advances `L99 (nope)`")
        self.assertEqual(v[0], "invalid")
        self.assertIn("L99", v[1])

    def test_blockquote_one_level_deep(self):
        self.assertEqual(dp.bundle_landmark_verdict(
            "> **Landmark:** advances `L1 (dispatch tooling)`")[0], "declared")

    def test_bullet_one_level_deep(self):
        self.assertEqual(dp.bundle_landmark_verdict(
            "- **Landmark:** advances `L1`")[0], "declared")

    def test_first_line_wins(self):
        self.assertEqual(dp.bundle_landmark_verdict(
            "**Landmark:** vibes\n**Landmark:** advances `L1`")[0], "invalid")

    def test_none_prefix_wins_over_later_valid_id(self):
        """CHARACTERIZATION: 'none ...' form wins even with a valid id later
        in the line — mirrors managent's verdict order."""
        v = dp.bundle_landmark_verdict(
            "**Landmark:** none of the L2 ids apply")
        self.assertEqual(v, ("declared", None))

    def test_boundary_L9_valid_L10_not(self):
        self.assertEqual(dp.bundle_landmark_verdict(
            "**Landmark:** advances `L9`")[0], "declared")
        self.assertEqual(dp.bundle_landmark_verdict(
            "**Landmark:** advances `L10`")[0], "invalid")


# ---------------------------------------------------------------------------
# 7. main — refusal paths (nothing may be spawned on ANY refusal)
# ---------------------------------------------------------------------------

GOOD_TITLE = "unit fixture brief"


class TestMainRefusals(EnvIsolatedTestCase):
    """SHOULD: refuse, with non-zero exit and a reason naming the cause,
    every input class the docstring lists — and spawn NOTHING on refusal."""

    def assert_refused(self, res, *fragments):
        code, _, err, spawned = res
        self.assertNotEqual(code, 0)
        blob = code if isinstance(code, str) else (err or "")
        for frag in fragments:
            self.assertIn(frag, blob)
        self.assertEqual(spawned, [])

    def test_depth_cap_refuses(self):
        root = self.temp_root()
        self.write_bundle(root)
        self.assert_refused(self.run_main(
            ["T9999", "deepseek-v4-pro"], root=root, depth=3),
            "delegation cap", "depth 3")

    def test_depth_cap_counts_garbage_as_at_cap(self):
        root = self.temp_root()
        self.write_bundle(root)
        self.assert_refused(self.run_main(
            ["T9999", "deepseek-v4-pro"], root=root, depth="not-a-number"),
            "delegation cap")

    def test_bad_task_id_shape_refuses(self):
        self.assert_refused(self.run_main(["X99", "deepseek-v4-pro"]),
                            "not a T<id> task id")

    def test_missing_args_show_usage(self):
        self.assert_refused(self.run_main(["T9999"]), "Usage:")

    def test_absent_row_refuses_with_register_hint(self):
        self.assert_refused(self.run_main(
            ["T9999", "deepseek-v4-pro"],
            root=self.temp_root(), status=None, identifier=None),
            "not found in store", "register it first")

    def test_in_progress_row_refuses_naming_holder(self):
        # the T350/T376/T389 duplicate-dispatch hazard
        self.assert_refused(self.run_main(
            ["T9999", "deepseek-v4-pro"], root=self.temp_root(),
            status="in_progress", identifier="deepseek-v4-flash/T350"),
            "already in_progress", "deepseek-v4-flash/T350", "reopen")

    def test_done_row_refuses(self):
        self.assert_refused(self.run_main(
            ["T9999", "deepseek-v4-pro"], root=self.temp_root(),
            status="done", identifier=None),
            "done, not dispatchable")

    def test_blocked_row_refuses(self):
        self.assert_refused(self.run_main(
            ["T9999", "deepseek-v4-pro"], root=self.temp_root(),
            status="blocked", identifier=None),
            "blocked, not dispatchable")

    def test_two_bundles_refuse(self):
        root = self.temp_root()
        self.write_bundle(root)
        self.write_bundle(root, title="second collision")
        p = os.path.join(root, "untracked", "T9999-second.md")
        with open(p, "w", encoding="utf-8") as f:
            f.write("# T9999 — second\n")
        self.assert_refused(self.run_main(["T9999", "deepseek-v4-pro"],
                                          root=root),
                            "expected exactly one bundle", "found 2")

    def test_title_over_40_chars_refuses(self):
        root = self.temp_root()
        self.write_bundle(root, title="x" * 41)
        self.assert_refused(self.run_main(["T9999", "deepseek-v4-pro"],
                                          root=root),
                            "over the 40-char limit", "41 chars")

    def test_title_at_40_chars_passes_the_gate(self):
        root = self.temp_root()
        self.write_bundle(root, title="y" * 40)
        code, out, err, spawned = self.run_main(
            ["T9999", "deepseek-v4-pro", "--dry-run"], root=root)
        self.assertEqual(code, 0)
        self.assertIn("dry-run T9999", out)

    def test_bundle_without_title_line_refuses(self):
        root = self.temp_root()
        path = os.path.join(root, "untracked", "T9999-x.md")
        with open(path, "w", encoding="utf-8") as f:
            f.write("# no task header here\nbody\n")
        self.assert_refused(self.run_main(["T9999", "deepseek-v4-pro"],
                                          root=root),
                            "has no `# T9999")

    def test_bundle_without_landmark_line_refuses(self):
        root = self.temp_root()
        self.write_bundle(root, landmark=None)
        self.assert_refused(self.run_main(["T9999", "deepseek-v4-pro"],
                                          root=root),
                            "declares no **Landmark:** line")

    def test_bundle_with_invalid_landmark_id_refuses(self):
        root = self.temp_root()
        self.write_bundle(root, landmark="advances `L99 (made up)`")
        self.assert_refused(self.run_main(["T9999", "deepseek-v4-pro"],
                                          root=root),
                            "unknown landmark id", "L99")

    def test_enforced_pause_directive_refuses(self):
        root = self.temp_root()
        self.write_bundle(root)
        d = {"id": "D042", "directive": "pause", "from": "Opus/Orcha"}
        self.assert_refused(self.run_main(
            ["T9999", "deepseek-v4-pro"], root=root,
            directives=([(d, "enforced")], [])),
            "pending directive", "D042", "PAUSE")

    def test_override_window_cooldown_requires_a_reason(self):
        self.assert_refused(self.run_main(
            ["T9999", "claude-opus-5",
             "--override-window-cooldown"]),
            "requires a reason")

    def test_empty_override_reason_refuses(self):
        self.assert_refused(self.run_main(
            ["T9999", "claude-opus-5", "--override-window-cooldown="]),
            "requires a reason")

    def test_wall_must_be_positive_integer(self):
        root = self.temp_root()
        self.write_bundle(root)
        for bad in ("--wall=0", "--wall=-5", "--wall=abc"):
            with self.subTest(bad=bad):
                self.assert_refused(
                    self.run_main(["T9999", "deepseek-v4-pro", bad],
                                  root=root),
                    "--wall must be a positive integer")

    def test_retired_budget_override_flag_is_not_a_flag_any_more(self):
        # T766 retired the predictive window-budget gate; the flag must be
        # gone from the accepted surface (and now also from the usage text).
        self.assertNotIn("--override-window-budget", dp.__doc__)
        self.assert_refused(self.run_main(
            ["T9999", "claude-opus-5", "--override-window-budget=x"]),
            "Usage:")

    def test_unknown_flag_shows_usage(self):
        self.assert_refused(self.run_main(
            ["T9999", "deepseek-v4-pro", "--frobnicate"]), "Usage:")


# ---------------------------------------------------------------------------
# 7. main — gate composition: each gate vetoes independently, a veto spawns
#    nothing and WRITES NOTHING (idle is acceptable; killing a task is not)
# ---------------------------------------------------------------------------

class TestGateComposition(EnvIsolatedTestCase):
    """SHOULD: window cooldown, probe concurrency and the directive gate each
    veto independently off injected readings, without consulting the real
    host; a veto leaves the world untouched (row still dispatchable, no
    log written, no process started)."""

    def _root_for_claude(self):
        root = self.temp_root()
        self.write_bundle(root)
        return root

    def test_cooldown_veto_independently(self):
        root = self._root_for_claude()
        cd = {"until": 4102444800, "reset_text": "3pm (Europe/Oslo)",
              "source": "unit-injected"}
        code, out, err, spawned = self.run_main(
            ["T9999", "claude-opus-5"], root=root, cooldown=cd)
        self.assertNotEqual(code, 0)
        self.assertIn("window cooldown", str(code))
        self.assertIn("claude", str(code))
        self.assertEqual(spawned, [])
        # veto wrote nothing under the root
        self.assertEqual(os.listdir(os.path.join(root, "untracked")),
                         ["T9999-fixture.md"])

    def test_cooldown_override_with_reason_proceeds_dry_without_recording(self):
        root = self._root_for_claude()
        cd = {"until": 4102444800, "reset_text": "3pm (Europe/Oslo)",
              "source": "unit-injected"}
        code, out, err, spawned = self.run_main(
            ["T9999", "claude-opus-5", "--dry-run",
             "--override-window-cooldown=checked the provider myself"],
            root=root, cooldown=cd)
        self.assertEqual(code, 0)
        self.assertIn("OVERRIDDEN", err)
        self.assertIn("dry-run", err)  # not recorded on a dry-run
        self.assertFalse(os.path.exists(os.path.join(
            root, "untracked", "fleet-window-overrides.jsonl")))
        self.assertEqual(spawned, [])

    def test_probe_concurrency_veto_independently(self):
        root = self._root_for_claude()
        code, out, err, spawned = self.run_main(
            ["T9999", "claude-opus-5"], root=root,
            probe_active=True, inprog=1)
        self.assertNotEqual(code, 0)
        self.assertIn("probe window", str(code))
        self.assertEqual(spawned, [])

    def test_probe_active_but_zero_in_progress_allows_dispatch(self):
        root = self._root_for_claude()
        code, out, _, spawned = self.run_main(
            ["T9999", "claude-opus-5", "--dry-run"], root=root,
            probe_active=True, inprog=0)
        self.assertEqual(code, 0)
        self.assertIn("dry-run T9999", out)
        self.assertEqual(spawned, [])

    def test_cooldown_and_probe_do_not_fire_for_other_families(self):
        # family_of(deepseek-v4-pro) == "other": neither claude gate may
        # even be consulted for a deepseek dispatch.
        root = self._root_for_claude()
        boom = mock.patch.object(dp.window_policy, "family_cooldown",
                                 side_effect=AssertionError("consulted"))
        code, out, _, spawned = self.run_main(
            ["T9999", "deepseek-v4-pro", "--dry-run"], root=root,
            extra_patches=[boom])
        self.assertEqual(code, 0)
        self.assertIn("dry-run T9999", out)
        self.assertEqual(spawned, [])

    def test_directive_veto_independent_of_window_gates(self):
        root = self._root_for_claude()
        d = {"id": "D099", "directive": "kill", "from": "Fable/Auditor"}
        code, out, err, spawned = self.run_main(
            ["T9999", "deepseek-v4-pro"], root=root,
            directives=([(d, "enforced")], []))
        self.assertNotEqual(code, 0)
        self.assertIn("D099", str(code))
        self.assertIn("KILL", str(code))
        self.assertEqual(spawned, [])

    def test_discharged_directive_warns_but_does_not_block(self):
        root = self._root_for_claude()
        d = {"id": "D001", "directive": "pause", "from": "Opus/Orcha"}
        code, out, err, spawned = self.run_main(
            ["T9999", "deepseek-v4-pro", "--dry-run"], root=root,
            directives=((), [(d, "stale")]))
        self.assertEqual(code, 0)
        self.assertIn("NOT enforced", err)
        self.assertIn("dry-run T9999", out)
        self.assertEqual(spawned, [])


# ---------------------------------------------------------------------------
# 7. main — --wall handling (parse + forward; default 2700)
# ---------------------------------------------------------------------------

class TestWallHandling(EnvIsolatedTestCase):
    """SHOULD: default the wall to 2700 (mode of practice), forward any
    positive integer unchanged to bin/subagent, refuse anything else.
    (The wall-SIZE advisory lives in tools/dispatch_verify.wall_advisory,
    not here — see module docstring.)"""

    def _argv_out(self, root, extra):
        code, out, err, spawned = self.run_main(
            ["T9999", "deepseek-v4-pro", "--dry-run", *extra], root=root)
        return code, out

    def _subagent_line(self, out):
        for ln in out.splitlines():
            if ln.strip().startswith("subagent:"):
                return ln
        self.fail("no subagent line in dry-run output:\n" + out)

    def test_default_wall_2700(self):
        root = self.temp_root()
        self.write_bundle(root)
        code, out = self._argv_out(root, [])
        self.assertEqual(code, 0)
        self.assertIn("--wall=2700", self._subagent_line(out))

    def test_explicit_wall_forwarded_unchanged(self):
        root = self.temp_root()
        self.write_bundle(root)
        code, out = self._argv_out(root, ["--wall=1800"])
        self.assertEqual(code, 0)
        self.assertIn("--wall=1800", self._subagent_line(out))

    def test_wall_one_accepted_boundary(self):
        root = self.temp_root()
        self.write_bundle(root)
        code, out = self._argv_out(root, ["--wall=1"])
        self.assertEqual(code, 0)
        self.assertIn("--wall=1", self._subagent_line(out))


# ---------------------------------------------------------------------------
# 7. main — the test seam (--test-root / --test-worker)
# ---------------------------------------------------------------------------

class TestTestSeam(EnvIsolatedTestCase):
    """SHOULD: --test-root relocates bundle AND log resolution (everything
    in tests/roundtrip/ rests on this); --test-worker forwards verbatim to
    bin/subagent; production paths are untouched when the flags are absent."""

    def test_test_root_relocates_bundle_and_log(self):
        root = self.temp_root()
        scratch = self.temp_root()
        # bundle lives ONLY in the scratch repo
        self.write_bundle(scratch)
        code, out, err, spawned = self.run_main(
            ["T9999", "deepseek-v4-pro", "--dry-run",
             "--test-root=%s" % scratch], root=root)
        self.assertEqual(code, 0, out + err)
        self.assertIn("dry-run T9999", out)
        self.assertIn("untracked/log/t9999.log", out)
        self.assertEqual(spawned, [])

    def test_test_worker_forwarded_to_subagent(self):
        scratch = self.temp_root()
        self.write_bundle(scratch)
        code, out, err, spawned = self.run_main(
            ["T9999", "deepseek-v4-pro", "--dry-run",
             "--test-root=%s" % scratch,
             "--test-worker=/bin/echo stub-worker"], root=scratch)
        self.assertEqual(code, 0)
        self.assertIn("--test-root=%s" % scratch, self._extract_cmd(out))
        self.assertIn("--test-worker=/bin/echo stub-worker",
                      self._extract_cmd(out))

    def _extract_cmd(self, out):
        for ln in out.splitlines():
            if ln.strip().startswith("subagent:"):
                return ln
        self.fail("no subagent line:\n" + out)


# ---------------------------------------------------------------------------
# 7. main — the T845 fleet-cap gate (total cap, family cap, one-writer,
#    recorded override) — unit level; the E2E controls live in
#    tools/regression-dispatch-caps.sh
# ---------------------------------------------------------------------------

class TestFleetCapGate(EnvIsolatedTestCase):
    """SHOULD: refuse over FLEET_CAP and FLEET_FAMILY_CAP, naming the cap,
    the current count and the waiting tasks; refuse a holds clash with a
    running task (NOT overridable); let --override-cap=<reason> bypass the
    caps for THIS dispatch while recording the reason on a real dispatch.
    The counts come from the SHARED helper (tools/fleet_caps.py) — the
    same numbers the keeper sees (one counter, one definition)."""

    def _root(self):
        root = self.temp_root()
        self.write_bundle(root)
        return root

    def test_total_cap_refuses_naming_count_and_waiters(self):
        rows = json.dumps([
            {"id": "T100", "status": "in_progress",
             "identifier": "deepseek-v4-flash/T100"},
            {"id": "T101", "status": "in_progress",
             "identifier": "deepseek-v4-flash/T101"},
            {"id": "T9999", "status": "dispatchable", "identifier": "x"}])
        code, out, err, spawned = self.run_main(
            ["T9999", "deepseek-v4-pro", "--dry-run"], root=self._root(),
            rows_json=rows,
            extra_patches=[mock.patch.dict(os.environ, {"FLEET_CAP": "2"})])
        self.assertNotEqual(code, 0)
        self.assertIn("total cap: 2/2", str(code))
        self.assertIn("T100", str(code))
        self.assertIn("T101", str(code))
        self.assertEqual(spawned, [])

    def test_under_the_cap_dispatch_proceeds(self):
        rows = json.dumps([
            {"id": "T100", "status": "in_progress",
             "identifier": "deepseek-v4-flash/T100"},
            {"id": "T9999", "status": "dispatchable", "identifier": "x"}])
        code, out, err, spawned = self.run_main(
            ["T9999", "deepseek-v4-pro", "--dry-run"], root=self._root(),
            rows_json=rows,
            extra_patches=[mock.patch.dict(os.environ, {"FLEET_CAP": "2"})])
        self.assertEqual(code, 0)
        self.assertIn("dry-run T9999", out)
        self.assertEqual(spawned, [])

    def test_family_cap_refuses_naming_family_count_and_waiter(self):
        rows = json.dumps([
            {"id": "T102", "status": "in_progress",
             "identifier": "claude-opus-5/T102", "model": "claude-opus-5"},
            {"id": "T9999", "status": "dispatchable", "identifier": "x"}])
        code, out, err, spawned = self.run_main(
            ["T9999", "claude-sonnet-5", "--dry-run"], root=self._root(),
            rows_json=rows,
            extra_patches=[mock.patch.dict(
                os.environ, {"FLEET_FAMILY_CAP": "claude=1"})])
        self.assertNotEqual(code, 0)
        self.assertIn("family claude is at its cap: 1/1", str(code))
        self.assertIn("T102", str(code))
        self.assertEqual(spawned, [])

    def test_family_cap_other_family_allowed(self):
        rows = json.dumps([
            {"id": "T102", "status": "in_progress",
             "identifier": "claude-opus-5/T102", "model": "claude-opus-5"},
            {"id": "T9999", "status": "dispatchable", "identifier": "x"}])
        code, out, err, spawned = self.run_main(
            ["T9999", "deepseek-v4-pro", "--dry-run"], root=self._root(),
            rows_json=rows,
            extra_patches=[mock.patch.dict(
                os.environ, {"FLEET_FAMILY_CAP": "claude=1"})])
        self.assertEqual(code, 0)
        self.assertIn("dry-run T9999", out)
        self.assertEqual(spawned, [])

    def test_one_writer_holds_refused_naming_file_and_holder(self):
        rows = json.dumps([
            {"id": "T103", "status": "in_progress",
             "identifier": "deepseek-v4-flash/T103",
             "holds": ["src/retro.zig"]},
            {"id": "T9999", "status": "dispatchable", "identifier": "x",
             "holds": ["src/retro.zig"]}])
        code, out, err, spawned = self.run_main(
            ["T9999", "deepseek-v4-pro", "--dry-run"], root=self._root(),
            rows_json=rows)
        self.assertNotEqual(code, 0)
        self.assertIn("src/retro.zig", str(code))
        self.assertIn("T103", str(code))
        self.assertEqual(spawned, [])

    def test_one_writer_not_bypassed_by_cap_override(self):
        # D022's 'dispatch-anyway after a wait' escape was REJECTED on
        # 2026-08-20; the cap override must not resurrect it.
        rows = json.dumps([
            {"id": "T103", "status": "in_progress",
             "identifier": "deepseek-v4-flash/T103",
             "holds": ["src/retro.zig"]},
            {"id": "T9999", "status": "dispatchable", "identifier": "x",
             "holds": ["src/retro.zig"]}])
        code, out, err, spawned = self.run_main(
            ["T9999", "deepseek-v4-pro", "--dry-run",
             "--override-cap=operator checked"], root=self._root(),
            rows_json=rows)
        self.assertNotEqual(code, 0)
        self.assertIn("src/retro.zig", str(code))
        self.assertEqual(spawned, [])

    def test_cap_override_requires_a_reason(self):
        for bad in ("--override-cap", "--override-cap="):
            with self.subTest(bad=bad):
                self.assert_refused_quiet(bad)

    def assert_refused_quiet(self, bad_flag):
        code, out, err, spawned = self.run_main(
            ["T9999", "deepseek-v4-pro", "--dry-run", bad_flag],
            root=self._root())
        self.assertNotEqual(code, 0)
        self.assertIn("requires a reason", str(code))
        self.assertEqual(spawned, [])

    def test_cap_override_bypasses_in_dry_run_without_recording(self):
        # a DRY-RUN is not a decision (T677 precedent): the override
        # bypasses the cap and warns, but records nothing.
        rows = json.dumps([
            {"id": "T104", "status": "in_progress",
             "identifier": "deepseek-v4-flash/T104"},
            {"id": "T9999", "status": "dispatchable", "identifier": "x"}])
        root = self._root()
        code, out, err, spawned = self.run_main(
            ["T9999", "deepseek-v4-pro", "--dry-run",
             "--override-cap=operator checked the fleet"], root=root,
            rows_json=rows,
            extra_patches=[mock.patch.dict(os.environ, {"FLEET_CAP": "1"})])
        self.assertEqual(code, 0)
        self.assertIn("dry-run T9999", out)
        self.assertIn("OVERRIDDEN", err)
        self.assertIn("dry-run", err)  # would-be-recorded, not recorded
        self.assertFalse(os.path.exists(os.path.join(
            root, "untracked", "fleet-cap-overrides.jsonl")))
        self.assertEqual(spawned, [])

    def test_record_cap_override_writes_the_ledger(self):
        # helper-level: the ledger line carries the reason (integration
        # with the real dispatch path is regression-dispatch-caps.sh arm 3e).
        root = self.temp_root()
        p = dp.fleet_caps.record_cap_override(
            root, "T9999", "total", {"total": 2, "total_cap": 1},
            "operator checked the fleet")
        self.assertTrue(p.endswith("fleet-cap-overrides.jsonl"))
        with open(p, encoding="utf-8") as f:
            line = json.loads(f.read().strip())
        self.assertEqual(line["task"], "T9999")
        self.assertEqual(line["kind"], "total")
        self.assertEqual(line["reason"], "operator checked the fleet")

    def test_record_cap_override_refuses_without_reason(self):
        root = self.temp_root()
        self.assertIsNone(dp.fleet_caps.record_cap_override(
            root, "T9999", "total", {}, "   "))


if __name__ == "__main__":
    unittest.main()
