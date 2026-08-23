"""Unit tests for bin/subagent (T792).

============================================================================
HALF A — top down: what is `bin/subagent` for, is each function used, should
it be?  (819 lines, 11 functions at brief time; T792 adds one — see #12.)
`bin/subagent` is the real launch chokepoint (T677/D040): every lane, hand
or dispatched, runs through it.  It has no importers — nothing treats it as
a library — so "who calls it" below means "which other code path inside
THIS file reaches it", and "production caller" means the `__main__` block
via `main(argv)`.

 # function                    for                                            called by (production)      last touched     vanish unnoticed?
 -- --------------------------- ---------------------------------------------- ---------------------------- ---------------- -------------------------------------------
 1  _load_pinned_dispatch_verify bind `dispatch_verify` to the git-HEAD copy    module import (line ~145)    2026-08-22 T631  NO — every verify/heal call breaks; T631's
                                  so a concurrent in-flight edit on the module                                                own incident (T616) is the "unnoticed" case
                                  can't reach a running verifier
 2  _host_total_mb                total physical memory (MB), injectable       demoted `sample` diagnostic   2026-08-24 T821  NO but low-stakes — unused by any
                                                                                 only (T821); no decision caller                              decision (T821, ram-policy.md §6)
 3  _host_avail_mb                system-wide available memory (MB),           demoted `sample` diagnostic   2026-08-24 T821  NO — same as above; the arbiter
                                  injectable, None on failure (inert path)     only; no decision caller                      (tools/runner) reads its own copy
 4  _resident_tenant_mb           resident MLX/Ollama tenant RSS (MB),          demoted `sample` diagnostic   2026-08-24 T821  NO — the resident charge is now a
                                  declared or auto-detected                     only; no decision caller                      registry declaration (§2a), never this
 5  _declared_ram_mb (T821)       the declared peak RSS need for admission      main(), the --arbiter-preview 2026-08-24 T821  NO — every lane's --ram-mb goes
                                  (registry figure, per-provider default,       subprocess call and the                       missing/wrong, admission mis-sizes
                                  or an explicit --ram-mb override)            real launch's cmd
 7  _pi_session_path              unique per-attempt session-file path for      main() (deepseek/ollama)      2026-08-22 T662  NO — pi/ollama lanes lose --session, the
                                  the token meter                                                                              token meter goes UNKNOWN for those lanes
 8  run_worker                    spawn + stream the worker subprocess,         main()                        2026-08-07 T411  NO — no lane could ever run
                                  capturing stdout for verification
 9  parse_argv                    argv -> (positional args, flags dict)        main()                        2026-08-08 T437  NO — main() has no other way to read argv
 10 main                          the whole dispatch: parse, gate, resolve,     `if __name__ == "__main__"`   2026-08-23 T792  NO — it is the entire program
                                  build cmd, run, verify, heal                                                (cmd-building unchanged; model-resolution
                                                                                                               extracted to #12)
 11 _flag_manual_heal              record (not perform) a heal that crashed,    main()'s except around        2026-08-22 T631  NO — a crashed heal after a failed dispatch
                                  so a broken heal can't hide silently          heal_dispatch                                 would leave a row silently in_progress
 12 _resolve_model (NEW, T792)     provider + raw tag -> canonical model        main()                        2026-08-23 T792  n/a (extracted this row; see below)
                                  label, or a ready-to-print error

T821 ADDENDUM (2026-08-24): this table is otherwise as T792 left it.  The
T713 resident-aware memory gate (rows #5 `_lane_is_memory_heavy` and #6
`_memory_gate_verdict`) is DELETED, not repaired -- docs/infra/host/
ram-policy.md replaces it with declared-need admission for EVERY lane
(row #5 is now `_declared_ram_mb`), decided by tools/runner's one arbiter
via a subprocess call, never re-implemented here.  Rows #2-#4
(`_host_total_mb`/`_host_avail_mb`/`_resident_tenant_mb`) are RETAINED but
DEMOTED to labeled `sample` diagnostics with no decision caller (ram-
policy.md §6 item 6) -- kept because deleting them would also delete their
existing unit coverage for no gain (a stale sample is still a correct
sample); nothing in this file's main() path reads them.
tools/regression-subagent-resident-gate.sh, which tested the T713 gate
directly, is RETIRED by the same row (T821) -- it now exits 0 immediately
with a reason banner rather than being deleted (T821's findings file
records why).

DELETION CANDIDATES: none.  All remaining functions have a live, findable
production caller inside this file and touched activity in the last
24-72h (T821/T662/T631/T437/T792); none is dead weight.  #12 is new: the
provider-routing
decision (deepseek/claude/pi/ollama branches, previously inline in main(),
lines ~495-527 pre-T792) was extracted verbatim into `_resolve_model` so the
"table-driven arm over every registry tag" the brief asks for could run
without spawning a subprocess or a dry-run round-trip through main() for
every tag.  Behaviour is unchanged for every valid input; one bare-flag edge
case is FIXED (see TestResolveModel.test_bare_model_flag_no_crash below) --
extraction, not a module restructuring.

HALF-A SIDE FINDING (this harness itself): tests/unit/_load.py's `load()`
could not load `bin/subagent` (or `bin/dispatch`) at all before this row --
`importlib.util.spec_from_file_location(name, path)` with no explicit
loader returns None for an extensionless path (verified on 3.9.6 and
3.14.6), so `spec.loader` raised AttributeError before ever reaching this
module's code.  Fixed in _load.py by passing an explicit SourceFileLoader;
see that file's docstring.  Without the fix this test file could not exist.

============================================================================
HALF B — bottom up: what each surviving function SHOULD do, red or green,
then cleanup.  Two real defects were found and FIXED as part of "make the
function ... correct" (not a structural refactor):

  * _pi_session_path collided at whole-second granularity: two attempts of
    one task launched within the same wall-clock second produced the SAME
    session filename -- silently overwriting the earlier attempt's session,
    exactly the failure T650/T662 exist to prevent.  RED before the T792
    fix (nanosecond-resolution timestamp), GREEN after --
    test_uniqueness_two_attempts below demonstrates both by construction.
  * a bare `--model` flag (no value, e.g. `--model --dry-run` or `--model`
    at the end of argv) parsed as `flags['model'] is True` (parse_argv), and
    the ollama branch's `re.sub(r":cloud$", "", raw_model)` crashed with an
    uncaught TypeError on a bool instead of a clean "is required" message.
    RED before the T792 fix (raw_model is True now treated as missing),
    GREEN after -- test_bare_model_flag_no_crash below.

One CHARACTERIZATION is recorded, not fixed here (it is the ollama tag
table's documented behaviour, shared with src/managent/main.zig's
canonicalizeModelTag, so fixing it is a cross-language contract change
outside this row's scope): an ollama tag outside OLLAMA_TAG_TO_CANONICAL is
accepted by stripping a trailing `:cloud` rather than refused.  Two
concrete registry entries fall into this gap and are asserted explicitly
below (test_registry_table, cases 'kimi_broken_cloud_tag_accepted_anyway'
and 'unknown_tag_falls_through_unvalidated'):
  - `kimi-k2.7:cloud` is documented in docs/infra/model-registry.md as
    returning `Error: model 'kimi-k2.7' not found` -- "do NOT dispatch" --
    yet OLLAMA_TAG_TO_CANONICAL maps it to kimi-k2.7 exactly like its
    working sibling kimi-k2.7-code:cloud, so bin/subagent accepts a
    documented-broken tag as if it were fine.  This is plausibly the exact
    shape of "two lanes exiting 0 in 38 and 64 seconds without reading
    their bundles" the brief names as the motivating incident: a lane that
    dispatches and dies almost immediately because a broken tag routed
    clean through this table.
  - `kimi-k2-thinking:cloud` (retired per model-registry.md) is not in the
    table either, and the fallback strips `:cloud` and returns
    `kimi-k2-thinking` -- a label that is not in canonical_models at all --
    with no error.

T821 (2026-08-24) deletes the T713 gate this paragraph used to cross-check
against tools/regression-subagent-resident-gate.sh (now RETIRED); see the
T821 addendum above.
"""
import contextlib
import io
import os
import subprocess
import sys
import tempfile
import time
import unittest
from unittest import mock

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)
import _load  # noqa: E402

# T631: loading bin/subagent executes `dispatch_verify = _load_pinned_dispatch_verify()`
# at module import time, which by default shells out to `git show` (a real
# subprocess) -- exactly the import-time side effect _load.py's own
# docstring says to report rather than work around.  The escape hatch this
# module already ships (WEIZIGO_DISPATCH_VERIFY_UNPINNED=1) avoids the
# subprocess entirely, which is what makes an otherwise-stdlib-only,
# subprocess-free load of this module possible.  TestLoadPinnedDispatchVerify
# below exercises BOTH paths directly (mocking subprocess.run) rather than
# only ever relying on this escape hatch.
os.environ.setdefault("WEIZIGO_DISPATCH_VERIFY_UNPINNED", "1")
sa = _load.load("bin/subagent", name="t792_subagent")


def _fake_completed(stdout="", returncode=0):
    return subprocess.CompletedProcess(args=["x"], returncode=returncode, stdout=stdout)


class EnvIsolatedTestCase(unittest.TestCase):
    """Base: snapshot/restore os.environ so no test leaks a reading into another."""

    def setUp(self):
        self._environ_snapshot = dict(os.environ)

    def tearDown(self):
        os.environ.clear()
        os.environ.update(self._environ_snapshot)


# ---------------------------------------------------------------------------
# 12. _resolve_model -- provider routing, table-driven over the registry
# ---------------------------------------------------------------------------

# The canonical set (docs/infra/model-registry.md "Canonical labels", single
# source bin/managent models / src/managent/main.zig canonical_models[], as
# of 2026-08-23).  Used only to characterize the fallback gap below -- this
# test file does not call `managent` (that would be a subprocess).
CANONICAL_MODELS_PER_REGISTRY = {
    "claude-opus-5", "claude-sonnet-5", "claude-fable-5",
    "claude-haiku-4-5-20251001", "deepseek-v4-pro", "deepseek-v4-flash",
    "glm-5.2", "minimax-m3", "kimi-k2.7", "qwen3.8:27b-mlx", "ox-alpha",
}


class TestResolveModel(EnvIsolatedTestCase):
    """SHOULD: turn a provider + raw dispatch tag into the canonical model
    label, refusing (claude/pi) or falling back (ollama) per the registry."""

    def test_claude_every_canonical_label_accepted(self):
        for label in sorted(sa.CLAUDE_MODELS):
            with self.subTest(label=label):
                model, err = sa._resolve_model("claude", label, {})
                self.assertIsNone(err)
                self.assertEqual(model, label)

    def test_claude_unknown_label_refused(self):
        model, err = sa._resolve_model("claude", "claude-haiku-3", {})
        self.assertIsNone(model)
        self.assertIn("is not a canonical claude label", err)

    def test_claude_missing_model_refused(self):
        model, err = sa._resolve_model("claude", None, {})
        self.assertIsNone(model)
        self.assertIn("is required", err)

    def test_deepseek_dspro_and_dsflash(self):
        model, err = sa._resolve_model("deepseek", None, {"dspro": True})
        self.assertIsNone(err)
        self.assertEqual(model, "deepseek-v4-pro")
        model, err = sa._resolve_model("deepseek", None, {"dsflash": True})
        self.assertIsNone(err)
        self.assertEqual(model, "deepseek-v4-flash")

    def test_deepseek_neither_or_both_refused(self):
        model, err = sa._resolve_model("deepseek", None, {})
        self.assertIsNone(model)
        self.assertIn("name exactly one model", err)
        model, err = sa._resolve_model("deepseek", None, {"dspro": True, "dsflash": True})
        self.assertIsNone(model)
        self.assertIn("name exactly one model", err)

    def test_pi_stealth_ox_alpha(self):
        model, err = sa._resolve_model("pi", "stealth/ox-alpha", {})
        self.assertIsNone(err)
        self.assertEqual(model, "ox-alpha")

    def test_pi_unknown_serving_tag_refused(self):
        model, err = sa._resolve_model("pi", "stealth/made-up", {})
        self.assertIsNone(model)
        self.assertIn("is not a known pi serving tag", err)

    def test_bare_model_flag_no_crash(self):
        """T792 fix: `--model` with no value (parse_argv yields True, not a
        string) must refuse cleanly, not crash inside re.sub on a bool.
        RED before the fix (TypeError from the ollama branch); GREEN after."""
        for provider in ("claude", "pi", "ollama"):
            with self.subTest(provider=provider):
                model, err = sa._resolve_model(provider, True, {})
                self.assertIsNone(model)
                self.assertIn("is required", err)

    # -- the registry table itself ------------------------------------------
    # (provider, raw_model_or_None, flags, expected_model, expect_error, note)
    REGISTRY_TABLE = [
        ("ollama", "glm-5.2", {}, "glm-5.2", False, "canonical ollama tag"),
        ("ollama", "glm-5.2:cloud", {}, "glm-5.2", False, "cloud tag, table hit"),
        ("ollama", "minimax-m3", {}, "minimax-m3", False, "canonical ollama tag"),
        ("ollama", "minimax-m3:cloud", {}, "minimax-m3", False, "cloud tag, table hit"),
        ("ollama", "kimi-k2.7", {}, "kimi-k2.7", False, "canonical ollama tag"),
        ("ollama", "kimi-k2.7-code", {}, "kimi-k2.7", False, "-code variant, table hit"),
        ("ollama", "kimi-k2.7-code:cloud", {}, "kimi-k2.7", False,
         "the working kimi tag today (model-registry.md)"),
        ("ollama", "qwen3.8:27b-mlx", {}, "qwen3.8:27b-mlx", False, "local MLX tag"),
        ("ollama", "qwen3.8:27b-mlx:cloud", {}, "qwen3.8:27b-mlx", False, "cloud tag, table hit"),
        ("pi", "stealth/ox-alpha", {}, "ox-alpha", False, "T732 stealth serving tag"),
        ("deepseek", None, {"dspro": True}, "deepseek-v4-pro", False, "flag-selected"),
        ("deepseek", None, {"dsflash": True}, "deepseek-v4-flash", False, "flag-selected"),
        ("claude", "claude-opus-5", {}, "claude-opus-5", False, "canonical"),
        ("claude", "claude-sonnet-5", {}, "claude-sonnet-5", False, "canonical"),
        ("claude", "claude-fable-5", {}, "claude-fable-5", False, "canonical"),
        ("claude", "claude-haiku-4-5-20251001", {}, "claude-haiku-4-5-20251001", False, "canonical"),
        # -- CHARACTERIZATION: the ollama fallback gap (T792 finding) --
        ("ollama", "kimi-k2.7:cloud", {}, "kimi-k2.7", False,
         "CHARACTERIZATION: model-registry.md documents this exact tag as "
         "'Error: model not found — do NOT dispatch', yet the table routes "
         "it identically to its working sibling kimi-k2.7-code:cloud"),
        ("ollama", "kimi-k2-thinking:cloud", {}, "kimi-k2-thinking", False,
         "CHARACTERIZATION: retired tag (model-registry.md), not in "
         "OLLAMA_TAG_TO_CANONICAL; the :cloud-stripping fallback accepts it "
         "and returns a label that is NOT in canonical_models"),
    ]

    def test_registry_table(self):
        for provider, raw_model, flags, expected_model, expect_error, note in self.REGISTRY_TABLE:
            with self.subTest(provider=provider, raw_model=raw_model, note=note):
                model, err = sa._resolve_model(provider, raw_model, flags)
                if expect_error:
                    self.assertIsNone(model)
                    self.assertIsNotNone(err)
                else:
                    self.assertIsNone(err)
                    self.assertEqual(model, expected_model)

    def test_characterization_fallback_can_yield_noncanonical_label(self):
        """CHARACTERIZATION (not a defect fixed here): an ollama tag outside
        OLLAMA_TAG_TO_CANONICAL is never validated against the canonical
        set -- a retired/typo'd tag silently produces a label nothing else
        recognises, instead of an error a human would see immediately."""
        model, err = sa._resolve_model("ollama", "kimi-k2-thinking:cloud", {})
        self.assertIsNone(err)
        self.assertNotIn(model, CANONICAL_MODELS_PER_REGISTRY)

    def test_every_table_hit_is_canonical(self):
        """SHOULD: every tag bin/subagent's OWN tables claim to know about
        resolves to a label that is actually in the canonical set -- i.e.
        the table itself (as opposed to its fallback) is internally sound."""
        for tag, model in sa.OLLAMA_TAG_TO_CANONICAL.items():
            with self.subTest(tag=tag):
                self.assertIn(model, CANONICAL_MODELS_PER_REGISTRY)
        for tag, model in sa.PI_TAG_TO_CANONICAL.items():
            with self.subTest(tag=tag):
                self.assertIn(model, CANONICAL_MODELS_PER_REGISTRY)


# ---------------------------------------------------------------------------
# 2-6. resident-aware memory gate (T713)
# ---------------------------------------------------------------------------

class TestHostTotalMb(EnvIsolatedTestCase):
    """SHOULD: report total physical memory in MB; WEIZIGO_HOST_TOTAL_MB
    injects the reading so no unit test ever queries the real host."""

    def test_injected_value_wins(self):
        os.environ["WEIZIGO_HOST_TOTAL_MB"] = "49152"
        self.assertEqual(sa._host_total_mb(), 49152)

    def test_invalid_injected_value_falls_through_to_real_reading(self):
        os.environ["WEIZIGO_HOST_TOTAL_MB"] = "not-a-number"
        with mock.patch.object(sa.subprocess, "run",
                                return_value=_fake_completed("17179869184\n")):
            with mock.patch.object(sa.sys, "platform", "darwin"):
                self.assertEqual(sa._host_total_mb(), 17179869184 // (1024 * 1024))


class TestHostAvailMb(EnvIsolatedTestCase):
    """SHOULD: report system-wide available memory in MB, or None when the
    reading is unmeasurable (the gate's documented inert path)."""

    def test_unavail_flag_forces_none(self):
        os.environ["WEIZIGO_HOST_MEM_UNAVAIL"] = "1"
        os.environ["WEIZIGO_HOST_MEM_AVAIL_MB"] = "99999"  # must be ignored
        self.assertIsNone(sa._host_avail_mb())

    def test_injected_value_wins(self):
        os.environ["WEIZIGO_HOST_MEM_AVAIL_MB"] = "9000"
        self.assertEqual(sa._host_avail_mb(), 9000)

    def test_vm_stat_parsing_sums_reclaimable_classes(self):
        """SHOULD: on the vm_stat path, sum free+inactive+purgeable+
        speculative pages (NOT active/wired/throttled) and convert using
        the page size vm_stat itself reports -- host-independent, no real
        subprocess (T792: the arm the brief asks for)."""
        vm_stat_output = (
            "Mach Virtual Memory Statistics: (page size of 16384 bytes)\n"
            "Pages free:                             100000.\n"
            "Pages active:                           200000.\n"
            "Pages inactive:                          50000.\n"
            "Pages speculative:                        2000.\n"
            "Pages throttled:                             0.\n"
            "Pages wired down:                       300000.\n"
            "Pages purgeable:                          3000.\n"
        )
        page_size = 16384
        expected_mb = ((100000 + 50000 + 3000 + 2000) * page_size) // (1024 * 1024)
        with mock.patch.object(sa.sys, "platform", "darwin"), \
             mock.patch.object(sa.subprocess, "run", return_value=_fake_completed(vm_stat_output)):
            self.assertEqual(sa._host_avail_mb(), expected_mb)


class TestResidentTenantMb(EnvIsolatedTestCase):
    """SHOULD: the resident model-server tenant's RSS in MB (0 = none),
    declared verbatim or auto-detected from a real `ollama runner
    --mlx-engine` process; auto-detection is suppressed whenever the
    available-memory reading was itself injected (the test owns the whole
    scenario, per the module's own documented rule)."""

    def test_declared_reservation_wins_including_zero(self):
        os.environ["WEIZIGO_HOST_TENANT_RESERVATION_MB"] = "0"
        self.assertEqual(sa._resident_tenant_mb(), 0)
        os.environ["WEIZIGO_HOST_TENANT_RESERVATION_MB"] = "8000"
        self.assertEqual(sa._resident_tenant_mb(), 8000)

    def test_malformed_declared_reservation_falls_back_to_zero(self):
        os.environ["WEIZIGO_HOST_TENANT_RESERVATION_MB"] = "not-a-number"
        self.assertEqual(sa._resident_tenant_mb(), 0)

    def test_injected_avail_suppresses_autodetection(self):
        os.environ["WEIZIGO_HOST_MEM_AVAIL_MB"] = "9000"
        with mock.patch.object(sa.subprocess, "run") as run:
            self.assertEqual(sa._resident_tenant_mb(), 0)
            run.assert_not_called()

    def test_autodetects_resident_mlx_engine_rss(self):
        ps_output = (
            "  501 16000000 /usr/local/bin/ollama runner --mlx-engine --model qwen\n"
            "  502   500000 /usr/bin/python3 some-other-process\n"
        )
        with mock.patch.object(sa.subprocess, "run", return_value=_fake_completed(ps_output)):
            self.assertEqual(sa._resident_tenant_mb(), 16000000 // 1024)

    def test_no_matching_process_is_zero(self):
        ps_output = "  501   500000 /usr/bin/python3 some-other-process\n"
        with mock.patch.object(sa.subprocess, "run", return_value=_fake_completed(ps_output)):
            self.assertEqual(sa._resident_tenant_mb(), 0)


class TestLaneIsMemoryHeavyRemoved(unittest.TestCase):
    """SHOULD (T821, docs/infra/host/ram-policy.md §6 item 9): the T713
    heavy/not-heavy classification and its verdict function are GONE --
    every lane declares a need now, there is no separate heavy class.
    Deletion checks, not behaviour tests."""

    def test_lane_is_memory_heavy_removed(self):
        self.assertFalse(hasattr(sa, "_lane_is_memory_heavy"))

    def test_memory_gate_verdict_removed(self):
        self.assertFalse(hasattr(sa, "_memory_gate_verdict"))


class TestDeclaredRamMb(unittest.TestCase):
    """SHOULD (T821, ram-policy.md §2a/§3.3): a resident local model
    (provider ollama, no :cloud tag) declares the REGISTRY figure; every
    other lane declares its per-provider default; an explicit --ram-mb
    override always wins."""

    CASES = [
        ("ollama", "qwen3.8:27b-mlx", {}, sa.RESIDENT_MODEL_RAM_MB),
        ("ollama", "glm-5.2", {}, sa.RESIDENT_MODEL_RAM_MB),
        ("ollama", "glm-5.2:cloud", {}, sa.OLLAMA_CLOUD_RAM_MB_DEFAULT),
        ("ollama", "qwen3.8:27b-mlx:cloud", {}, sa.OLLAMA_CLOUD_RAM_MB_DEFAULT),
        ("deepseek", None, {}, sa.PROVIDER_RAM_MB_DEFAULT["deepseek"]),
        ("claude", "claude-opus-5", {}, sa.PROVIDER_RAM_MB_DEFAULT["claude"]),
        ("pi", "stealth/ox-alpha", {}, sa.PROVIDER_RAM_MB_DEFAULT["pi"]),
    ]

    def test_defaults_table(self):
        for provider, raw_model, flags, expected in self.CASES:
            with self.subTest(provider=provider, raw_model=raw_model):
                self.assertEqual(
                    sa._declared_ram_mb(provider, raw_model, flags), expected)

    def test_explicit_override_always_wins(self):
        self.assertEqual(
            sa._declared_ram_mb("ollama", "qwen3.8:27b-mlx", {"ram-mb": "500"}),
            500,
        )
        self.assertEqual(
            sa._declared_ram_mb("claude", "claude-opus-5", {"ram-mb": "9999"}),
            9999,
        )


# ---------------------------------------------------------------------------
# 7. _pi_session_path
# ---------------------------------------------------------------------------

class TestPiSessionPath(unittest.TestCase):
    """SHOULD: give every attempt of every task a distinct session file, so
    the token meter can attribute it and a re-dispatch never overwrites a
    previous attempt's session (T650 principle applied to the T662 meter)."""

    def test_uniqueness_two_attempts_same_task(self):
        p1 = sa._pi_session_path("T792")
        p2 = sa._pi_session_path("T792")
        self.assertNotEqual(p1, p2)

    def test_uniqueness_would_have_been_red_at_whole_second_granularity(self):
        """Demonstrates the pre-T792 defect by construction: freezing the
        clock to the SAME whole second is exactly what real-world back-to-
        back retries can do, and the old `int(time.time())` implementation
        collided under it.  RED against that implementation; GREEN now
        because the fix adds pid + a per-process counter (time_ns() ALONE
        still collided in practice on this host — see the module comment
        on _pi_session_path)."""
        frozen = 1787500000.999999
        with mock.patch.object(sa.time, "time", return_value=frozen):
            legacy_p1 = f"untracked/tokens/sessions/T792.{int(sa.time.time())}.jsonl"
            legacy_p2 = f"untracked/tokens/sessions/T792.{int(sa.time.time())}.jsonl"
        self.assertEqual(legacy_p1, legacy_p2, "the OLD formula collides -- this is the recorded defect")
        p1 = sa._pi_session_path("T792")
        p2 = sa._pi_session_path("T792")
        self.assertNotEqual(p1, p2, "the CURRENT (nanosecond) formula must not collide")

    def test_shape_and_default_ident(self):
        p = sa._pi_session_path("T792")
        self.assertTrue(p.startswith("untracked/tokens/sessions/T792."))
        self.assertTrue(p.endswith(".jsonl"))
        p_no_task = sa._pi_session_path(None)
        self.assertTrue(p_no_task.startswith("untracked/tokens/sessions/lane."))


# ---------------------------------------------------------------------------
# 8. run_worker
# ---------------------------------------------------------------------------

class _FakeProc:
    def __init__(self, lines, rc):
        self.stdout = iter(lines)
        self._rc = rc

    def wait(self):
        return self._rc


class TestRunWorker(unittest.TestCase):
    """SHOULD: stream every stdout line to the parent's stdout AS IT ARRIVES
    while also capturing the full text, and return (rc, captured_text) --
    the captured text is what T411's nonce/deliverable verification reads,
    so it must be the exact concatenation of every line the worker wrote."""

    def test_streams_and_captures(self):
        lines = ["hello\n", "VERIFY-NONCE: abc\n", "done\n"]
        fake = _FakeProc(lines, rc=0)
        with mock.patch.object(sa.subprocess, "Popen", return_value=fake):
            buf = io.StringIO()
            with contextlib.redirect_stdout(buf):
                rc, captured = sa.run_worker(["ignored"], cwd=".", env={})
        self.assertEqual(rc, 0)
        self.assertEqual(captured, "".join(lines))
        self.assertEqual(buf.getvalue(), "".join(lines))

    def test_nonzero_exit_code_propagates(self):
        fake = _FakeProc(["x\n"], rc=2)
        with mock.patch.object(sa.subprocess, "Popen", return_value=fake):
            with contextlib.redirect_stdout(io.StringIO()):
                rc, _ = sa.run_worker(["ignored"], cwd=".", env={})
        self.assertEqual(rc, 2)


# ---------------------------------------------------------------------------
# 9. parse_argv
# ---------------------------------------------------------------------------

class TestParseArgv(unittest.TestCase):
    """SHOULD: split argv into (positional args, flags dict); `--k v`,
    `--k=v` and bare `--k` are all accepted flag forms."""

    def test_positional_only(self):
        args, flags = sa.parse_argv(["T792"])
        self.assertEqual(args, ["T792"])
        self.assertEqual(flags, {})

    def test_space_separated_value_flags(self):
        args, flags = sa.parse_argv(["--provider", "ollama", "--model", "glm-5.2:cloud", "T1"])
        self.assertEqual(args, ["T1"])
        self.assertEqual(flags, {"provider": "ollama", "model": "glm-5.2:cloud"})

    def test_equals_form(self):
        args, flags = sa.parse_argv(["--wall=900", "--rss-cap-mb=4096"])
        self.assertEqual(flags, {"wall": "900", "rss-cap-mb": "4096"})
        self.assertEqual(args, [])

    def test_bare_flag(self):
        args, flags = sa.parse_argv(["--dry-run"])
        self.assertEqual(flags, {"dry-run": True})

    def test_value_flag_at_end_of_argv_is_bare(self):
        """CHARACTERIZATION: `--model` is a value-flag, but with nothing
        after it in argv there is no value to consume -- it degrades to a
        bare boolean flag (flags['model'] is True), not a parse error.
        This is exactly the input _resolve_model's T792 fix now handles
        instead of crashing on."""
        args, flags = sa.parse_argv(["--provider", "ollama", "--model"])
        self.assertEqual(flags, {"provider": "ollama", "model": True})

    def test_value_flag_immediately_before_another_flag_is_bare(self):
        """CHARACTERIZATION: the guard is `not argv[i+1].startswith('--')`,
        so `--model --dry-run` treats --model as bare (True) rather than
        swallowing --dry-run as its value -- the safer of the two readings,
        but still a silently-accepted malformed invocation."""
        args, flags = sa.parse_argv(["--model", "--dry-run"])
        self.assertEqual(flags, {"model": True, "dry-run": True})


# ---------------------------------------------------------------------------
# 11. _flag_manual_heal
# ---------------------------------------------------------------------------

class TestFlagManualHeal(unittest.TestCase):
    """SHOULD: when heal_dispatch itself crashes, append a `needs_manual_heal`
    record (healed=False) to the heals log and print a loud stderr line --
    the marker that lets a human find a row a crashed heal left stranded,
    self-contained so a broken dispatch_verify contract cannot also break
    this."""

    def test_appends_record_and_warns(self):
        with tempfile.TemporaryDirectory() as td:
            heals_path = os.path.join(td, "heals.jsonl")
            with mock.patch.dict(os.environ, {"WEIZIGO_DISPATCH_HEALS": heals_path}):
                buf = io.StringIO()
                with contextlib.redirect_stderr(buf):
                    sa._flag_manual_heal("T999", "deepseek-v4-flash", rc=1,
                                          wall_seconds=12.3, exc=ValueError("boom"))
            self.assertIn("HEAL CRASHED", buf.getvalue())
            with open(heals_path) as f:
                import json
                rec = json.loads(f.readline())
            self.assertEqual(rec["task_id"], "T999")
            self.assertEqual(rec["healed"], False)
            self.assertTrue(rec["needs_manual_heal"])
            self.assertIn("boom", rec["error"])

    def test_write_failure_is_reported_not_swallowed_silently(self):
        """SHOULD: if even the marker write fails, the printed line says so
        rather than pretending the marker was appended."""
        unwritable = "/nonexistent-dir-for-t792/heals.jsonl"
        with mock.patch.dict(os.environ, {"WEIZIGO_DISPATCH_HEALS": unwritable}):
            buf = io.StringIO()
            with contextlib.redirect_stderr(buf):
                sa._flag_manual_heal("T999", "deepseek-v4-flash", rc=1,
                                      wall_seconds=1.0, exc=RuntimeError("x"))
        self.assertIn("MARKER WRITE FAILED", buf.getvalue())


# ---------------------------------------------------------------------------
# 1. _load_pinned_dispatch_verify
# ---------------------------------------------------------------------------

class TestLoadPinnedDispatchVerify(EnvIsolatedTestCase):
    """SHOULD: import tools/dispatch_verify.py from git HEAD (never the
    working tree) so a concurrent in-flight edit cannot reach a running
    verifier (T631); WEIZIGO_DISPATCH_VERIFY_UNPINNED=1 is the documented
    developer escape hatch that skips git entirely; a git failure falls
    back to the working tree WITH a loud warning rather than crashing.

    Every arm here calls the real _load_pinned_dispatch_verify(), which
    writes `sys.modules["dispatch_verify"]` as a side effect (by design —
    T631 wants every later `import dispatch_verify` in-process to see the
    pinned copy).  That is exactly the kind of cross-test leak this file's
    tests must not cause each other, so each arm snapshots/restores that
    one cache slot in addition to os.environ."""

    def setUp(self):
        super().setUp()
        self._dv_snapshot = sys.modules.get("dispatch_verify")

    def tearDown(self):
        if self._dv_snapshot is not None:
            sys.modules["dispatch_verify"] = self._dv_snapshot
        else:
            sys.modules.pop("dispatch_verify", None)
        super().tearDown()

    def test_unpinned_escape_hatch_never_calls_subprocess(self):
        os.environ["WEIZIGO_DISPATCH_VERIFY_UNPINNED"] = "1"
        with mock.patch.object(sa.subprocess, "run",
                                side_effect=AssertionError("must not shell out")):
            buf = io.StringIO()
            with contextlib.redirect_stderr(buf):
                mod = sa._load_pinned_dispatch_verify()
        self.assertTrue(hasattr(mod, "generate_nonce"))
        self.assertIn("WEIZIGO_DISPATCH_VERIFY_UNPINNED=1", buf.getvalue())

    def test_pinned_path_reads_git_show_head_not_working_tree(self):
        os.environ.pop("WEIZIGO_DISPATCH_VERIFY_UNPINNED", None)
        sentinel_source = "SENTINEL_FROM_HEAD = 'T792-pinned-marker'\n"
        with mock.patch.object(sa.subprocess, "run",
                                return_value=_fake_completed(sentinel_source, returncode=0)):
            mod = sa._load_pinned_dispatch_verify()
        self.assertEqual(getattr(mod, "SENTINEL_FROM_HEAD", None), "T792-pinned-marker")

    def test_git_failure_falls_back_to_working_tree_with_warning(self):
        os.environ.pop("WEIZIGO_DISPATCH_VERIFY_UNPINNED", None)
        with mock.patch.object(sa.subprocess, "run",
                                side_effect=OSError("git not found")):
            buf = io.StringIO()
            with contextlib.redirect_stderr(buf):
                mod = sa._load_pinned_dispatch_verify()
        self.assertTrue(hasattr(mod, "generate_nonce"))
        self.assertIn("T631 WARNING", buf.getvalue())


# ---------------------------------------------------------------------------
# 10. main -- a few end-to-end smoke arms (the exhaustive routing sweep is
#     TestResolveModel above; this only guards the wiring around it).
# ---------------------------------------------------------------------------

def _run_main(argv, env):
    """Call sa.main(argv) with a fully-controlled environment; SystemExit's
    payload is returned as-is (usually a message string) so tests can
    assert on it directly, matching how sys.exit(str) is actually used
    throughout this module."""
    stdout, stderr = io.StringIO(), io.StringIO()
    with mock.patch.dict(os.environ, env, clear=True):
        try:
            with contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
                rc = sa.main(argv)
        except SystemExit as e:
            rc = e.code
    return rc, stdout.getvalue(), stderr.getvalue()


class TestMainRouting(unittest.TestCase):
    BASE_ENV = {
        "WEIZIGO_AGENT_DEPTH": "1",
        "WEIZIGO_HOST_MEM_AVAIL_MB": "25000",
        "WEIZIGO_HOST_TOTAL_MB": "49152",
        "WEIZIGO_DISPATCH_VERIFY_UNPINNED": "1",
        "DEEPSEEK_API_KEY": "unit-test-not-real",
        "PATH": os.environ.get("PATH", ""),
    }

    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.target = os.path.join(self._tmp.name, "target.md")
        with open(self.target, "w") as f:
            f.write("# scratch dispatch target\n")
        # T821: an instance attribute of the same name shadows the class
        # dict for every test in this class (no other call site needs to
        # change) — WEIZIGO_ARBITER_STATE_FILE isolates the admission
        # preview from the REAL untracked/arbiter-state.json, which the
        # live fleet is genuinely writing to on a shared host (a bare
        # WEIZIGO_HOST_MEM_AVAIL_MB injection is not enough: the arbiter
        # also reads committed_mb from the ledger file itself).
        self.BASE_ENV = dict(
            TestMainRouting.BASE_ENV,
            WEIZIGO_ARBITER_STATE_FILE=os.path.join(self._tmp.name, "arbiter-state.json"),
        )

    def tearDown(self):
        self._tmp.cleanup()

    def test_missing_provider_refused(self):
        rc, _, _ = _run_main([self.target], self.BASE_ENV)
        self.assertIn("missing --provider", rc)

    def test_unknown_provider_refused(self):
        rc, _, _ = _run_main(["--provider", "bogus", self.target], self.BASE_ENV)
        self.assertIn("unknown provider", rc)

    def test_depth_cap_refused(self):
        env = dict(self.BASE_ENV, WEIZIGO_AGENT_DEPTH="3")
        rc, _, _ = _run_main(["--provider", "claude", "--model", "claude-fable-5",
                               self.target, "--dry-run"], env)
        self.assertIn("delegation cap", rc)

    def test_claude_dry_run_success_names_canonical_model(self):
        rc, out, _ = _run_main(
            ["--provider", "claude", "--model", "claude-fable-5", self.target, "--dry-run"],
            self.BASE_ENV)
        self.assertEqual(rc, 0)
        self.assertIn("claude-fable-5", out)
        self.assertIn("tools/runner", out)

    def test_deepseek_dry_run_success(self):
        rc, out, _ = _run_main(
            ["--provider", "deepseek", "--dsflash", self.target, "--dry-run"],
            self.BASE_ENV)
        self.assertEqual(rc, 0)
        self.assertIn("deepseek-v4-flash", out)

    def test_pi_dry_run_success_uses_serving_tag_in_argv(self):
        rc, out, _ = _run_main(
            ["--provider", "pi", "--model", "stealth/ox-alpha", self.target, "--dry-run"],
            self.BASE_ENV)
        self.assertEqual(rc, 0)
        self.assertIn("stealth/ox-alpha", out)

    def test_ollama_cloud_tag_dry_run_declares_remote_default(self):
        # T821: a :cloud tag declares the small remote default, never the
        # 18 GB resident-model registry figure.
        rc, out, err = _run_main(
            ["--provider", "ollama", "--model", "glm-5.2:cloud", self.target, "--dry-run"],
            self.BASE_ENV)
        self.assertEqual(rc, 0)
        self.assertIn("glm-5.2:cloud", out)
        self.assertIn(f"ram_mb={sa.OLLAMA_CLOUD_RAM_MB_DEFAULT}", err)

    def test_ollama_local_tag_dry_run_declares_resident_registry_figure(self):
        # T821: a LOCAL ollama tag declares the registry figure (18432 MB)
        # at admission preview -- never a live ps sample.
        rc, out, err = _run_main(
            ["--provider", "ollama", "--model", "qwen3.8:27b-mlx", self.target, "--dry-run"],
            self.BASE_ENV)
        self.assertEqual(rc, 0, err)
        self.assertIn(f"ram_mb={sa.RESIDENT_MODEL_RAM_MB}", err)
        self.assertIn("qwen3.8:27b-mlx", out)

    def test_claude_invalid_label_refused(self):
        rc, _, _ = _run_main(
            ["--provider", "claude", "--model", "claude-haiku-3", self.target, "--dry-run"],
            self.BASE_ENV)
        self.assertIn("is not a canonical claude label", rc)


if __name__ == "__main__":
    unittest.main()
