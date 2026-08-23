#!/usr/bin/env python3
"""tests/roundtrip/test_dispatch_lifecycle.py — T797 round-trip tier: the
dispatch → run → verify → close lifecycle, end to end, with no provider and
no cost.

This tier is the consolidation net for the operator's plan (2026-08-23):
"Does it make sense to write thorough tests for the six scripts and managent.
Test round trips, e2e, etc. Then use those same tests to consolidate the
scripts into managent, slowly replacing each script with managent
functionality."  The net is built BEFORE the consolidation so that every
absorption step (ORC-PLAN-3) has something to swing on.

NOT a unit tier.  Every arm spawns processes — bin/dispatch, bin/subagent,
bin/managent and the stub worker — against a scratch git repo and a scratch
kanban store under /tmp/weizigo.  Per T789 it is a pre-commit-adjacent /
pre-consolidation gate: run it before any commit that touches dispatch /
subagent / verification behaviour, and never mix it into tests/unit/ (which
is hermetic and function-level by contract — tests/unit/README.md).

The seam: bin/dispatch and bin/subagent accept --test-root=<dir> (resolve
the repo from a scratch tree) and --test-worker=<cmd> (run a stub instead of
a real model).  Only 3 of 75 tools/regression-*.sh arms use the seam; this
tier is the mechanism's main customer.

Labels (T797 rule — every arm is exactly one):
  OUTCOME        what the system must achieve, stated without naming which
                 script achieves it.  Survives both consolidation into
                 managent and interface simplification.  Write these
                 thoroughly — they are the net the consolidation swings on.
  SCAFFOLD       today's interface: this flag, this stdout line, this file
                 path.  Written to catch *accidental* change while
                 functionality moves, and deliberately deleted in the same
                 commit that intentionally changes that interface.  Each
                 SCAFFOLD arm names the ORC-PLAN-3 step it dies with.
  PINNED-DEFECT  behaviour already known wrong, pinned faithfully with the
                 owning row — consolidation carries the bug consciously
                 until the owning row fixes it.  Recorded via
                 @unittest.expectedFailure so the tier stays runnable while
                 the defect stays visible (the tests/unit convention).

Two arms are currently RED (recorded defects, expected-failure):
  test_empty_deliverables_reports_unverifiable_never_pass   PINNED-DEFECT,
      owner T793 (same SHOULD as tests/unit
      TestVerifyDispatchEmptyDeliverables — the two tiers agree).
  test_silent_but_working_lane_is_not_failed                OUTCOME,
      owners T785/T773 (the T735 class: a working lane scored dead for
      stdout silence).  At the round-trip seam the runner's liveness fuse
      is not present (--test-worker bypasses tools/runner), so the
      round-trip manifestation is the verification's nonce-echo check.

Run (the one documented command):
    python3 tests/roundtrip/test_dispatch_lifecycle.py
    (or: python3 -m unittest discover -s tests/roundtrip -p 'test_*.py')

The runner prints the tier's total wall and a per-arm breakdown; the
dominant cost is the T390 claim-to-done gate (a closing stub must sleep
>10 s between claim and done — the honest path the fleet actually runs).

Task: T797 · Role: worker · Model: deepseek-v4-flash · Date: 2026-08-23
"""
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MG = os.path.join(ROOT, "bin", "managent")
DISPATCH = os.path.join(ROOT, "bin", "dispatch")
SUBAGENT = os.path.join(ROOT, "bin", "subagent")
TMP = "/tmp/weizigo"          # disposable outputs only (AGENTS.md rule)
SCRATCH_PREFIX = "t797-rt-"   # one scratch repo per arm; cleaned up at tearDown

NONCE_RE = re.compile(r"NONCE-[0-9a-f]{16}")
DISPATCH_LINE_RE = re.compile(
    r"^dispatched T\d+ → deepseek-v4-flash \(deepseek\) · pid \d+ · "
    r"untracked/log/t\d+\.log$")


def resolve_claimlint():
    """The claimlint binary the done-gate runs (scratch symlink target)."""
    for p in (os.path.join(ROOT, "bin", "weizigo-claimlint"),
              os.path.join(ROOT, "zig-out", "bin", "weizigo-claimlint")):
        if os.path.isfile(p) and os.access(p, os.X_OK):
            return p
    return None


CLAIMLINT = resolve_claimlint()

# ── the shared stub worker ────────────────────────────────────────────────
# One script, parameterised entirely by environment.  It parses the task id,
# model, deliverables and nonce OUT OF THE PROMPT, exactly as a real agent
# must, then behaves per its STUB_* configuration.  Every failure mode the
# fleet has actually seen maps to one configuration (README table):
#   STUB_CLAIM        1 (default) run `managent claim <id> --agent <model>`
#   STUB_WRITE        1 (default) write + git-commit the declared deliverables
#   STUB_CLOSE        1 (default) sleep STUB_SLEEP then `managent done` with
#                     --status STUB_VERDICT (the T390 claim-to-done gap is
#                     the honest path; the fleet's own stubs sleep 11 s)
#   STUB_ECHO_NONCE   1 (default) print the nonce as the final stdout line
#   STUB_PROGRESS     1 print interim working lines before the nonce
#   STUB_SILENT       1 print NOTHING (no nonce, no progress)
#   STUB_VERDICT      pass (default) | fail-found | ... — the done --status
#   STUB_SABOTAGE     1 delete the declared deliverables AFTER done (the only
#                     honest way to close with a deliverable missing: the
#                     done gate itself refuses an uncommitted/missing
#                     deliverable, T278)
#   STUB_EXIT         exit code (default 0)
#   STUB_SLEEP        seconds between claim and done (default 11 — T390 gate)
#   STUB_PROMPT_FILE  if set, write the whole prompt there (prompt-contract
#                     arms — a diagnostic side effect, not stdout)
#   STUB_MARKER       if set, write the nonce there (seam-reached arms — a
#                     diagnostic side effect, not stdout)
STUB_SRC = r'''#!/usr/bin/env python3
"""T797 shared stub worker — a fake agent driven by STUB_* environment vars.

Run in place of a real model via bin/subagent --test-worker (or through
bin/dispatch's forwarding).  Parses the task id, model, deliverables and
nonce out of the prompt, exactly as a real agent would have to, then behaves
per its configuration.  See tests/roundtrip/README.md for the failure-mode
table.
"""
import os
import re
import subprocess
import sys
import time


def on(name, default):
    return os.environ.get(name, default) == "1"


prompt = sys.argv[-1]

nonce_m = re.search(r"NONCE-[0-9a-f]{16}", prompt)
nonce = nonce_m.group(0) if nonce_m else ""
task_m = re.search(r"managent (?:claim|done) (T\d+)", prompt)
task = task_m.group(1) if task_m else None
model_m = re.search(r"managent claim \S+ --agent (\S+)", prompt)
model = model_m.group(1) if model_m else None
dls = re.findall(r"^  - (\S+)$", prompt, re.M)

if os.environ.get("STUB_PROMPT_FILE"):
    with open(os.environ["STUB_PROMPT_FILE"], "w") as f:
        f.write(prompt)
if os.environ.get("STUB_MARKER"):
    with open(os.environ["STUB_MARKER"], "w") as f:
        f.write(nonce or "NO-NONCE")

mg = os.environ.get("REAL_MG", "managent")

if on("STUB_CLAIM", "1") and task and model:
    subprocess.run([mg, "claim", task, "--agent", model], check=True)

if on("STUB_WRITE", "1") and dls:
    for d in dls:
        os.makedirs(os.path.dirname(d) or ".", exist_ok=True)
        with open(d, "w") as f:
            f.write("T797 stub deliverable\n")
    subprocess.run(["git", "add", "--"] + dls, check=True)
    subprocess.run(["git", "commit", "-qm", "T797 stub deliverable"], check=True)

if on("STUB_CLOSE", "1") and task and model:
    time.sleep(int(os.environ.get("STUB_SLEEP", "11")))
    verdict = os.environ.get("STUB_VERDICT", "pass")
    subprocess.run([mg, "done", task, "--agent", model, "--status", verdict,
                    "--note", "T797 stub " + verdict,
                    "--impression-waiver",
                    "stub worker — no model ran (T797 roundtrip)"], check=True)
    if on("STUB_SABOTAGE", "0"):
        for d in dls:
            try:
                os.unlink(d)
            except OSError:
                pass

if not on("STUB_SILENT", "0"):
    if on("STUB_PROGRESS", "0"):
        print("stub: working...")
        print("stub: still working...")
    if on("STUB_ECHO_NONCE", "1") and nonce:
        print(nonce + " task complete")

sys.exit(int(os.environ.get("STUB_EXIT", "0")))
'''


class ScratchRepo:
    """One isolated scratch repo per arm: git, minimal claims register,
    claimlint symlink (the T485 done-gate substrate), the stub worker, a
    scratch kanban store and scratch telemetry.  Nothing here touches the
    live repo, the live kanban or the live ledger — MANAGENT_STORE /
    WEIZIGO_MODEL_PERF / WEIZIGO_DISPATCH_HEALS / REAL_MG point at scratch
    (the same isolation the tools/regression-dispatch*.sh suites use)."""

    def __init__(self, task_id=None, deliverables=None, header_extra=""):
        self.dir = tempfile.mkdtemp(prefix=SCRATCH_PREFIX, dir=TMP)
        self._cleanup_registered = False
        self.store = os.path.join(self.dir, "docs", "infra", "managent",
                                  "tasks.json")
        self.stub = os.path.join(self.dir, "stub.py")
        self.env = self._base_env()
        self._init_git()
        self._write_stub()
        if task_id is not None:
            self.seed_task(task_id, deliverables, header_extra)

    # -- construction ----------------------------------------------------
    def _init_git(self):
        for c in (["git", "init", "-q"],
                  ["git", "config", "user.email", "t797@test"],
                  ["git", "config", "user.name", "T797"]):
            subprocess.run(c, cwd=self.dir, check=True,
                           capture_output=True, text=True)
        for d in ("docs", "untracked", "findings", "docs/epistemic",
                  "docs/infra/managent", "bin"):
            os.makedirs(os.path.join(self.dir, d), exist_ok=True)
        with open(os.path.join(self.dir, "README.md"), "w") as f:
            f.write("base\n")
        with open(os.path.join(self.dir, ".gitignore"), "w") as f:
            f.write("untracked/\n")
        with open(os.path.join(self.dir, "docs", "epistemic", "CLAIMS.md"),
                  "w") as f:
            f.write("# minimal scratch claims register (T797 roundtrip)\n")
        subprocess.run(["git", "add", "README.md", ".gitignore",
                        "docs/epistemic/CLAIMS.md"],
                       cwd=self.dir, check=True, capture_output=True, text=True)
        subprocess.run(["git", "commit", "-qm", "base"],
                       cwd=self.dir, check=True, capture_output=True, text=True)
        if CLAIMLINT is None:
            raise RuntimeError(
                "weizigo-claimlint is not built (bin/ or zig-out/bin/); the "
                "T485 done-gate cannot run and the closing arms cannot close. "
                "Build it first: zig build")
        os.symlink(CLAIMLINT, os.path.join(self.dir, "bin", "weizigo-claimlint"))

    def _base_env(self):
        env = dict(os.environ)
        env.update({
            "MANAGENT_STORE": self.store,
            "WEIZIGO_MODEL_PERF": os.path.join(self.dir, "perf-ledger.txt"),
            "WEIZIGO_DISPATCH_HEALS": os.path.join(self.dir, "heals.jsonl"),
            "REAL_MG": MG,
            # T631's pin is deliberately bypassed: this tier tests the
            # WORKING TREE (the consolidation net must catch in-flight
            # edits, not the last commit).  The pin protects LIVE
            # dispatches from a mid-edit verifier; a test tier is not a
            # live dispatch.
            "WEIZIGO_DISPATCH_VERIFY_UNPINNED": "1",
        })
        # a stale depth stamp from a worker-run suite trips the cap control
        env.pop("WEIZIGO_AGENT_DEPTH", None)
        return env

    def _write_stub(self):
        with open(self.stub, "w") as f:
            f.write(STUB_SRC)
        os.chmod(self.stub, 0o755)

    def seed_task(self, task_id, deliverables=None, header_extra=""):
        """Write untracked/T<id>-bundle.md and register the row."""
        dl = deliverables or "docs/%s-result.txt" % task_id
        header = "<!--managent set=A deliverables=%s%s-->" % (dl, header_extra)
        bundle = ("%s\n# %s \u2014 roundtrip fixture\n"
                  "**Landmark:** none directly; unblocks roundtrip fixture\n"
                  % (header, task_id))
        with open(os.path.join(self.dir, "untracked",
                               "%s-bundle.md" % task_id), "w") as f:
            f.write(bundle)
        r = subprocess.run([MG, "add", task_id], cwd=self.dir, env=self.env,
                           capture_output=True, text=True)
        if r.returncode != 0:
            raise RuntimeError("managent add %s failed: %s" % (task_id, r.stderr))

    # -- queries ----------------------------------------------------------
    def row_status(self, task_id):
        try:
            with open(self.store) as f:
                data = json.load(f)
        except (OSError, ValueError):
            return None
        t = data.get(task_id)
        return t.get("status") if t else None

    def row_verdict(self, task_id):
        try:
            with open(self.store) as f:
                data = json.load(f)
        except (OSError, ValueError):
            return None
        t = data.get(task_id)
        return t.get("verdict") if t else None

    def env_with_stub(self, **overrides):
        env = dict(self.env)
        env.update({k: str(v) for k, v in overrides.items()})
        return env

    # -- runners ----------------------------------------------------------
    def run_dispatch(self, task_id, env=None, extra=()):
        """bin/dispatch — detaches the worker; returns when the data line is
        printed (the row lifecycle continues in the background)."""
        return subprocess.run(
            [sys.executable, DISPATCH, task_id, "deepseek-v4-flash",
             "--test-root=" + self.dir, "--test-worker=" + self.stub] + list(extra),
            capture_output=True, text=True, env=env or self.env, timeout=60)

    def run_subagent(self, task_id, env=None):
        """bin/subagent — synchronous: returns when the stub has exited AND
        verification has run (the exit code IS the verification verdict)."""
        return subprocess.run(
            [sys.executable, SUBAGENT, "--provider", "deepseek", task_id,
             "--dsflash", "--test-root=" + self.dir,
             "--test-worker=" + self.stub],
            capture_output=True, text=True, env=env or self.env, timeout=90)

    def wait_for(self, task_id, status, timeout_s=45):
        """Poll the store until the row reaches `status` (or timeout)."""
        deadline = time.monotonic() + timeout_s
        while time.monotonic() < deadline:
            s = self.row_status(task_id)
            if s == status:
                return True
            time.sleep(0.5)
        return False

    def wait_for_log_path(self, log_path, needle, timeout_s=45):
        deadline = time.monotonic() + timeout_s
        content = ""
        while time.monotonic() < deadline:
            if os.path.exists(log_path):
                try:
                    with open(log_path) as f:
                        content = f.read()
                except OSError:
                    content = ""
                if needle in content:
                    return True, content
            time.sleep(0.5)
        return False, content

    def cleanup(self):
        if not self._cleanup_registered:
            self._cleanup_registered = True
            shutil.rmtree(self.dir, ignore_errors=True)


class RoundtripLifecycle(unittest.TestCase):
    """The dispatch lifecycle, end to end, on the stub seam.

    Arm labels (T797): OUTCOME / SCAFFOLD / PINNED-DEFECT — see the module
    docstring and tests/roundtrip/README.md.  Every arm's label and its
    first-run colour are recorded in findings/T797-roundtrip-harness.json.
    """

    # label registry for the runner's count + the wall report
    ARMS = {}

    def setUp(self):
        self._scratch_repos = []

    def tearDown(self):
        for s in self._scratch_repos:
            s.cleanup()
        self._scratch_repos = []

    def make(self, *a, **k):
        s = ScratchRepo(*a, **k)
        self._scratch_repos.append(s)
        return s

    # ══ OUTCOME 1 — happy path ═══════════════════════════════════════════
    def test_happy_path_dispatch_roundtrip_closes_and_passes(self):
        """OUTCOME — a dispatched row reaches a verified close: dispatch →
        stub works → row closes pass → the declared deliverable exists.
        No flag, no log path, no summary text is asserted here (S1 pins the
        reporting interface); this is the lifecycle itself."""
        w = self.make("T8001")
        env = w.env_with_stub(STUB_PROGRESS="1")   # a lane that emits output
        r = w.run_dispatch("T8001", env=env)
        self.assertEqual(r.returncode, 0,
                         "dispatch refused: %s" % (r.stdout + r.stderr))
        self.assertIn("dispatched T8001", r.stdout,
                      "no data line: %s" % r.stdout)
        self.assertTrue(w.wait_for("T8001", "done"),
                        "row never reached done (status=%s)"
                        % w.row_status("T8001"))
        self.assertEqual(w.row_verdict("T8001"), "pass")
        self.assertTrue(
            os.path.exists(os.path.join(w.dir, "docs", "T8001-result.txt")),
            "the declared deliverable was not written by the worker")

    # ══ OUTCOME 2 — exit 0 without reading the bundle ═════════════════════
    def test_exit_zero_without_work_fails_nonce(self):
        """OUTCOME — a worker that exits 0 without reading the bundle (or
        doing any work) fails verification on the nonce.  The 2026-08-23
        ox-alpha double-catch (two lanes, exit 0 in 38 s and 64 s) — a
        standing arm."""
        w = self.make("T8002")
        env = w.env_with_stub(STUB_SILENT="1", STUB_CLAIM="0",
                              STUB_CLOSE="0", STUB_WRITE="0")
        r = w.run_subagent("T8002", env=env)
        out = r.stdout + r.stderr
        self.assertNotEqual(r.returncode, 0,
                            "verification passed a worker that did nothing")
        self.assertIn("verification FAILED", out)
        self.assertIn("FAIL nonce", out,
                      "the failure must name the nonce: %s" % out)
        self.assertEqual(w.row_status("T8002"), "dispatchable",
                         "the row must be untouched by a worker that did nothing")

    # ══ OUTCOME 3 — declared deliverables absent ═════════════════════════
    def test_declared_deliverable_absent_fails_verification(self):
        """OUTCOME — a close whose declared deliverable is not there at
        verification time fails on deliverables, whatever the worker's text
        said.  Model: write+commit+close, then delete — the only honest way
        to reach verification with a deliverable missing (the done gate
        itself refuses an uncommitted/missing deliverable, T278, so a close
        with the file never present cannot happen)."""
        w = self.make("T8003")
        env = w.env_with_stub(STUB_SABOTAGE="1")
        r = w.run_subagent("T8003", env=env)
        out = r.stdout + r.stderr
        self.assertNotEqual(r.returncode, 0,
                            "verification passed with the deliverable missing")
        self.assertIn("verification FAILED", out)
        self.assertIn("deliverable", out,
                      "the failure must name the deliverable: %s" % out)
        self.assertEqual(w.row_status("T8003"), "done",
                         "the sabotage model closes the row, then deletes")
        self.assertFalse(
            os.path.exists(os.path.join(w.dir, "docs", "T8003-result.txt")),
            "the sabotaged deliverable should be gone at verification time")

    # ══ OUTCOME 4 — row left in_progress after exit, either exit code ═════
    def test_open_row_after_worker_exit_fails_either_exit_code(self):
        """OUTCOME — a row left in_progress after the worker exits fails
        verification whatever the exit code.  rc=0 with an open row is the
        kimi incident (claimed then abandoned); rc!=0 is the died-worker
        case.  And a died worker leaves no zombie: the row returns to
        dispatchable (today via the dispatcher's heal, T477 — the
        mechanism, not the arm, may change under consolidation)."""
        # rc = 0: claimed then abandoned — fails, and is NOT auto-healed
        # (a clean exit that left the row open is investigated, not tidied)
        w1 = self.make("T8004")
        env1 = w1.env_with_stub(STUB_CLAIM="1", STUB_CLOSE="0", STUB_WRITE="0")
        r1 = w1.run_subagent("T8004", env=env1)
        out1 = r1.stdout + r1.stderr
        self.assertNotEqual(r1.returncode, 0,
                            "rc=0 with an open row passed verification")
        self.assertIn("verification FAILED", out1)
        self.assertIn("never left in_progress", out1)
        self.assertEqual(w1.row_status("T8004"), "in_progress",
                         "rc=0 is not healed (the kimi state is investigated)")

        # rc != 0: died after claiming — fails, AND the row comes back
        # (no zombie: a process that watched the worker die reopens it)
        w2 = self.make("T8005")
        env2 = w2.env_with_stub(STUB_CLAIM="1", STUB_CLOSE="0",
                                STUB_WRITE="0", STUB_EXIT="1")
        r2 = w2.run_subagent("T8005", env=env2)
        out2 = r2.stdout + r2.stderr
        self.assertNotEqual(r2.returncode, 0,
                            "rc=1 with an open row passed verification")
        self.assertIn("verification FAILED", out2)
        self.assertEqual(w2.row_status("T8005"), "dispatchable",
                         "a died worker must leave no zombie row (healed)")
        # the heal is the current mechanism; the no-zombie state is the
        # OUTCOME that survives whatever replaces it

    # ══ OUTCOME 5 — fail-found with the work done is believed ════════════
    def test_fail_found_with_work_done_passes(self):
        """OUTCOME — the worker's verdict text is never trusted in either
        direction: a row closed fail-found WITH its deliverables present and
        its nonce echoed verifies PASS — the side effects are the evidence,
        the text is a report about them (T411 'believe the work, not the
        text')."""
        w = self.make("T8006")
        env = w.env_with_stub(STUB_VERDICT="fail-found")
        r = w.run_subagent("T8006", env=env)
        out = r.stdout + r.stderr
        self.assertEqual(r.returncode, 0,
                         "fail-found with the work done failed verification: %s" % out)
        self.assertIn("verification PASSED", out)
        self.assertIn("fail-found", out)
        self.assertEqual(w.row_status("T8006"), "done")

    # ══ OUTCOME 6 — silent-but-working lane is not failed as dead ════════
    @unittest.expectedFailure
    def test_silent_but_working_lane_is_not_failed(self):
        """OUTCOME — RED today; owners T785/T773 (the T735 class).  A lane
        that completes every declared side effect but emits no stdout must
        not be recorded as failed-as-dead.  T735 attempt 2 ran 40 turns and
        19,060 output tokens across 600 s and was recorded 'produced no
        output since launch (bundle never read?)'.  At the round-trip seam
        the runner's liveness fuse is not present (--test-worker bypasses
        tools/runner), so the round-trip manifestation is the verifier's
        nonce-echo check: it demands the token in stdout and fails a
        fully-worked silent lane.  The SHOULD: work fully verified (row
        closed, deliverable committed) is evidence of a working lane;
        stdout silence alone must not fail it."""
        w = self.make("T8007")
        env = w.env_with_stub(STUB_SILENT="1")   # full work, zero stdout
        r = w.run_subagent("T8007", env=env)
        out = r.stdout + r.stderr
        self.assertEqual(r.returncode, 0,
                         "a fully-worked silent lane failed verification: %s" % out)
        self.assertEqual(w.row_status("T8007"), "done",
                         "the silent lane's work must have landed")
        self.assertTrue(
            os.path.exists(os.path.join(w.dir, "docs", "T8007-result.txt")),
            "the silent lane's deliverable must be present")

    # ══ PINNED-DEFECT — empty deliverables= ══════════════════════════════
    @unittest.expectedFailure
    def test_empty_deliverables_reports_unverifiable_never_pass(self):
        """PINNED-DEFECT (owner T793) — RED today.  A row closed success
        with an EMPTY deliverables= declaration is UNVERIFIABLE, never PASS:
        the deliverables arm silently disables itself when the declaration
        is empty, and a PASS resting on the nonce alone is exactly the
        self-report the verifier refuses to trust.  The unit tier pins the
        same SHOULD (tests/unit TestVerifyDispatchEmptyDeliverables,
        @unittest.expectedFailure); this is the round-trip twin so the two
        tiers agree.  When T793's fix lands, this arm goes green and the
        expectedFailure flags an unexpected success — update it then."""
        # no seeding: the bundle must declare deliverables= (empty), and
        # seed_task would build `deliverables=docs/T8008-result.txt`
        w = ScratchRepo()
        self._scratch_repos.append(w)
        bundle = ("<!--managent set=A deliverables=-->\n"
                  "# T8008 \u2014 roundtrip fixture\n"
                  "**Landmark:** none directly; unblocks roundtrip fixture\n")
        with open(os.path.join(w.dir, "untracked", "T8008-bundle.md"), "w") as f:
            f.write(bundle)
        r = subprocess.run([MG, "add", "T8008"], cwd=w.dir, env=w.env,
                           capture_output=True, text=True)
        self.assertEqual(r.returncode, 0, r.stderr)
        env = w.env_with_stub()                   # full honest close, no deliverables
        r = w.run_subagent("T8008", env=env)
        out = r.stdout + r.stderr
        self.assertNotEqual(r.returncode, 0,
                            "an unverifiable close must not pass: %s" % out)
        self.assertIn("unverifiable", out,
                      "the failure must say unverifiable: %s" % out)

    # ══ SCAFFOLD — the dispatch interface (dies with ORC-PLAN-3 step 5) ═══
    def test_dispatch_data_line_and_log_convention(self):
        """SCAFFOLD — dies with ORC-PLAN-3 step 5 (dispatch/subagent
        rewire).  Today's interface: bin/dispatch prints exactly one data
        line `dispatched T<id> → <canon> (<provider>) · pid <pid> ·
        untracked/log/t<id>.log`; the worker log lands at that path; and a
        verified close's log ends with the `[verify] verification PASSED`
        summary.  These are the surfaces the operator greps.  Deleted in
        the same commit that intentionally changes them."""
        w = self.make("T8009")
        env = w.env_with_stub()
        r = w.run_dispatch("T8009", env=env)
        self.assertEqual(r.returncode, 0,
                         "dispatch refused: %s" % (r.stdout + r.stderr))
        self.assertIsNotNone(
            DISPATCH_LINE_RE.match(r.stdout.strip()),
            "data line shape changed: %r" % r.stdout)
        log_path = os.path.join(w.dir, "untracked", "log", "t8009.log")
        self.assertTrue(os.path.exists(log_path),
                        "the dispatch log did not land at untracked/log/t8009.log")
        seen, content = w.wait_for_log_path(log_path, "verification PASSED")
        self.assertTrue(seen,
                        "the log never showed a verified close: %s" % content[-2000:])
        self.assertIn("[verify]", content,
                      "the verify summary is a [verify] line: %s" % content[-2000:])

    def test_test_seam_flags_accepted_by_both_front_doors(self):
        """SCAFFOLD — dies with ORC-PLAN-3 step 5.  The test seam spelling:
        --test-root=<dir> and --test-worker=<cmd> are accepted by
        bin/dispatch (a dry-run shows them forwarded into the subagent
        command) and by bin/subagent (a real call reaches the stub).  The
        whole tier is this seam; if the seam is re-spelled, every arm in
        this file breaks loudly — delete THIS arm in the same commit that
        re-spells it, and update the README's run instructions."""
        w = self.make("T8010")
        # bin/dispatch forwards them (dry-run — nothing spawned)
        r = subprocess.run(
            [sys.executable, DISPATCH, "T8010", "deepseek-v4-flash",
             "--test-root=" + w.dir, "--test-worker=" + w.stub, "--dry-run"],
            capture_output=True, text=True, env=w.env, timeout=30)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("--test-root=" + w.dir, r.stdout,
                      "dispatch did not forward --test-root: %s" % r.stdout)
        self.assertIn("--test-worker=" + w.stub, r.stdout,
                      "dispatch did not forward --test-worker: %s" % r.stdout)
        # bin/subagent accepts them: a silent stub still writes its marker
        # through the seam (the marker is a file side effect, not stdout)
        marker = os.path.join(w.dir, "marker.txt")
        env = w.env_with_stub(STUB_MARKER=marker, STUB_SILENT="1",
                              STUB_CLAIM="0", STUB_CLOSE="0", STUB_WRITE="0")
        r = subprocess.run(
            [sys.executable, SUBAGENT, "--provider", "deepseek", "T8010",
             "--dsflash", "--test-root=" + w.dir, "--test-worker=" + w.stub],
            capture_output=True, text=True, env=env, timeout=30)
        self.assertTrue(os.path.exists(marker),
                        "the seam never reached the stub worker")
        with open(marker) as f:
            self.assertTrue(NONCE_RE.search(f.read()),
                            "the stub received no prompt with a nonce")

    def test_nonce_prompt_contract_reaches_the_worker(self):
        """SCAFFOLD — dies with ORC-PLAN-3 step 5.  The worker-side
        instruction contract: the prompt handed to the worker carries the
        two verbatim nonce lines (VERIFY-NONCE: NONCE-… / Begin your final
        reply with exactly the line: NONCE-…).  Real agents parse these;
        the seam must deliver them unmodified, or the nonce arm of
        verification is checking a token the worker was never given."""
        w = self.make("T8011")
        prompt_file = os.path.join(w.dir, "prompt.txt")
        env = w.env_with_stub(STUB_PROMPT_FILE=prompt_file,
                              STUB_CLAIM="0", STUB_CLOSE="0", STUB_WRITE="0")
        r = w.run_subagent("T8011", env=env)
        self.assertTrue(os.path.exists(prompt_file),
                        "the seam never delivered a prompt to the worker")
        with open(prompt_file) as f:
            prompt = f.read()
        nonce_m = NONCE_RE.search(prompt)
        self.assertIsNotNone(nonce_m, "no NONCE token in the worker prompt")
        nonce = nonce_m.group(0)
        self.assertIn("VERIFY-NONCE: " + nonce, prompt,
                      "the VERIFY-NONCE line is missing or altered")
        self.assertIn("Begin your final reply with exactly the line: " + nonce,
                      prompt,
                      "the final-reply line is missing or altered")


# ── label registry (drives the runner's counts and the wall report) ──────
RoundtripLifecycle.ARMS = {
    "test_happy_path_dispatch_roundtrip_closes_and_passes": (
        "OUTCOME", "happy path: dispatch → stub works → row closes pass → work lands"),
    "test_exit_zero_without_work_fails_nonce": (
        "OUTCOME", "exit 0 without reading the bundle fails on the nonce (ox-alpha double-catch)"),
    "test_declared_deliverable_absent_fails_verification": (
        "OUTCOME", "declared deliverable absent at verification time fails on deliverables"),
    "test_open_row_after_worker_exit_fails_either_exit_code": (
        "OUTCOME", "row left in_progress fails for exit 0 and non-zero; died worker leaves no zombie"),
    "test_fail_found_with_work_done_passes": (
        "OUTCOME", "fail-found with the work done verifies PASS (believe the work, not the text)"),
    "test_silent_but_working_lane_is_not_failed": (
        "OUTCOME", "silent-but-working lane not failed as dead — RED, owners T785/T773"),
    "test_empty_deliverables_reports_unverifiable_never_pass": (
        "PINNED-DEFECT", "empty deliverables= reports unverifiable, never pass — RED, owner T793"),
    "test_dispatch_data_line_and_log_convention": (
        "SCAFFOLD", "dispatch one data line + untracked/log/t<id>.log + [verify] PASSED — dies with ORC-PLAN-3 step 5"),
    "test_test_seam_flags_accepted_by_both_front_doors": (
        "SCAFFOLD", "--test-root=/--test-worker= accepted by dispatch and subagent — dies with ORC-PLAN-3 step 5"),
    "test_nonce_prompt_contract_reaches_the_worker": (
        "SCAFFOLD", "the two verbatim nonce prompt lines reach the worker — dies with ORC-PLAN-3 step 5"),
}


class _TimingResult(unittest.TextTestResult):
    """TestResult that records per-arm wall time for the tier report."""

    def __init__(self, *a, **k):
        super().__init__(*a, **k)
        self.durations = {}
        self._start = {}

    def startTest(self, test):
        self._start[test.id()] = time.monotonic()
        super().startTest(test)

    def stopTest(self, test):
        self.durations[test.id()] = time.monotonic() - self._start.pop(test.id())
        super().stopTest(test)


def main():
    t0 = time.monotonic()
    suite = unittest.defaultTestLoader.loadTestsFromTestCase(RoundtripLifecycle)
    runner = unittest.TextTestRunner(resultclass=_TimingResult, verbosity=2)
    result = runner.run(suite)
    wall = time.monotonic() - t0

    labels = {}
    for name, (label, _note) in RoundtripLifecycle.ARMS.items():
        labels[label] = labels.get(label, 0) + 1

    print()
    print("=== tests/roundtrip summary ===")
    print("arms: %d   OUTCOME %d   SCAFFOLD %d   PINNED-DEFECT %d"
          % (len(RoundtripLifecycle.ARMS), labels.get("OUTCOME", 0),
             labels.get("SCAFFOLD", 0), labels.get("PINNED-DEFECT", 0)))
    print("tier wall: %.1f s" % wall)
    for name in sorted(RoundtripLifecycle.ARMS):
        label, note = RoundtripLifecycle.ARMS[name]
        dur = 0.0
        for tid, d in result.durations.items():
            if tid.endswith("." + name):
                dur = d
                break
        print("  %-58s %-13s %5.1fs   %s" % (name, label, dur, note))
    if result.expectedFailures:
        print("recorded defects (expected failures) still open:")
        for case, _ in result.expectedFailures:
            print("   ", case.id())
    if result.unexpectedSuccesses:
        print("!! recorded defects now PASS — update the tests (unexpected success):")
        for case in result.unexpectedSuccesses:
            print("   ", case.id())
    if result.failures or result.errors:
        print("!! %d failure(s), %d error(s) — see above"
              % (len(result.failures), len(result.errors)))
    return 0 if result.wasSuccessful() else 1


if __name__ == "__main__":
    if CLAIMLINT is None:
        sys.stderr.write(
            "tests/roundtrip: FATAL — weizigo-claimlint is not built "
            "(bin/ or zig-out/bin/); the T485 done-gate cannot run and the "
            "closing arms cannot close. Build it first: zig build\n")
        sys.exit(2)
    sys.exit(main())
