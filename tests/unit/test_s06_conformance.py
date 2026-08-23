"""S06 conformance + characterization arms (T802, Pass 0).

**Two jobs, deliberately in one file.**

1. *Characterization* — pin what the six absorption targets do **today**,
   including behaviour we know is wrong, so ORC-PLAN-3's six migration steps
   cannot change it silently.  This is what T711 skipped: its control injected
   the tenant footprint, so nothing ever pinned what the detector actually
   returned, and three worker consoles died to it three days later.
2. *Spec conformance* — arm the four load-bearing normative ids that
   `findings/T778-s06-spec-audit.json` finding 1 names as having **no arm at
   all**: `ORC-POL-3` (the appetite dial), `ORC-POL-4`/`ORC-GATE-2` (the merged
   cooldown machine), `ORC-DASH-4` (the one pane), `ORC-ARB-4` (kernel-attested
   identity).  These are RED by construction — the mechanisms are unbuilt, and
   `ORC-CTRL-2` requires red first.  Each carries its owning row.

Every arm here is **text analysis of tracked source files**.  Nothing is
imported, nothing is spawned, nothing outside `tempfile` is written — the
`tests/unit/README.md` contract holds.  The targets are shell with embedded
Python (`tools/fleet-keeper.sh`), Zig (`src/managent/main.zig`) and POSIX sh
(`untracked/watch-fleet.sh`); none can be imported, and the facts under test
are *declarations*, which is precisely what source text carries.

**Counts.** 24 arms: **19 GREEN** characterization + null/seeded controls, **5 RED**
spec-conformance covering **7 normative ids** (POL-1, POL-3, POL-4, GATE-2, DASH-1, DASH-4,
ARB-4 — one arm can assert more than one id, so arms and ids are not in bijection and are counted
separately).

**Labels** (`tests/roundtrip/README.md`'s vocabulary, which this tier honours):
CHARACTERIZATION arms pin today and are expected GREEN; they are deleted or
rewritten by the migration step that intentionally changes the subject, named
per arm.  SPEC-CONFORMANCE arms are `@unittest.expectedFailure` with the row
that owes the mechanism.  An unlabelled arm is the defect the labels prevent.
"""
import glob
import os
import re
import unittest

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

SPEC = "docs/epics/E1-markovian/L1-dashboard/S06-orchestration-refactor/spec.md"
KEEPER = "tools/fleet-keeper.sh"
MAIN_ZIG = "src/managent/main.zig"
WATCH = "untracked/watch-fleet.sh"
WINDOW_POLICY = "tools/window_policy.py"
DIRECTIVE_POLICY = "tools/directive_policy.py"


def src(relpath):
    with open(os.path.join(REPO, relpath), encoding="utf-8") as f:
        return f.read()


# ---------------------------------------------------------------------------
# The two appetite tables.  Parsed out of source text, in one place, so every
# arm below reads the same extraction and a parser break is one failure.
# ---------------------------------------------------------------------------

def keeper_appetite():
    """`DEFAULT_APPETITE` from tools/fleet-keeper.sh's embedded Python."""
    m = re.search(r"DEFAULT_APPETITE\s*=\s*\{(.*?)\}", src(KEEPER), re.S)
    if not m:
        raise AssertionError("DEFAULT_APPETITE not found in %s — parser break, "
                             "not a pass" % KEEPER)
    return dict(re.findall(r'"([^"]+)"\s*:\s*"([^"]+)"', m.group(1)))


def keeper_family_map():
    """`FAMILY` (canonical model -> family) from the same embedded Python."""
    m = re.search(r"^FAMILY\s*=\s*\{(.*?)^\}", src(KEEPER), re.S | re.M)
    if not m:
        raise AssertionError("FAMILY not found in %s — parser break" % KEEPER)
    return dict(re.findall(r'"([^"]+)"\s*:\s*"([^"]+)"', m.group(1)))


def managent_appetite():
    """`family_appetite` from src/managent/main.zig."""
    m = re.search(r"const family_appetite\s*=\s*\[_\]FamilyAppetite\{(.*?)\n\};",
                  src(MAIN_ZIG), re.S)
    if not m:
        raise AssertionError("family_appetite not found in %s — parser break"
                             % MAIN_ZIG)
    pairs = re.findall(r'\.family\s*=\s*"([^"]+)"\s*,\s*\.appetite\s*=\s*\.(\w+)',
                       m.group(1))
    return {fam: word.upper() for fam, word in pairs}


def managent_model_families():
    m = re.search(r"const model_families\s*=\s*\[_\]ModelFamily\{(.*?)\n\};",
                  src(MAIN_ZIG), re.S)
    if not m:
        raise AssertionError("model_families not found in %s — parser break"
                             % MAIN_ZIG)
    return dict(re.findall(r'\.model\s*=\s*"([^"]+)"\s*,\s*\.family\s*=\s*"([^"]+)"',
                           m.group(1)))


class TestParsersHaveSubjects(unittest.TestCase):
    """Null control for this file's own instrument (never trust a green test).

    Every arm below rests on four regex extractions.  A regex that silently
    matches nothing would make half this file pass vacuously, which is the
    exact class of green nobody earned.  These four arms fail loudly instead.
    """

    def test_all_four_extractions_return_nonempty(self):
        self.assertTrue(keeper_appetite(), "keeper appetite table empty")
        self.assertTrue(keeper_family_map(), "keeper FAMILY map empty")
        self.assertTrue(managent_appetite(), "managent appetite table empty")
        self.assertTrue(managent_model_families(), "managent model_families empty")

    def test_seeded_parser_defect_is_caught(self):
        """Seeded control: a renamed table must raise, not return {}."""
        text = "DEFAULT_APPETITE_RENAMED = {'claude': 'SPEND'}"
        self.assertIsNone(re.search(r"DEFAULT_APPETITE\s*=\s*\{", text),
                          "the extraction regex matches a renamed table — it "
                          "would report an empty dict as a clean read")


# ---------------------------------------------------------------------------
# ORC-POL-3 — the appetite dial
# ---------------------------------------------------------------------------

class TestAppetiteDial(unittest.TestCase):

    # CHARACTERIZATION — dies with ORC-PLAN-3 step 1 (policy file + reader).
    def test_appetite_is_family_categorical_today_not_a_per_model_dial(self):
        """SHOULD (ORC-POL-3): appetite is a per-MODEL 0-9 dial.

        TODAY: both live tables are per-FAMILY categorical words.  Pinned so
        step 1 cannot quietly keep the categorical form and call it the dial.
        """
        for table, where in ((keeper_appetite(), KEEPER),
                             (managent_appetite(), MAIN_ZIG)):
            for family, word in table.items():
                self.assertRegex(word, r"^[A-Z-]+$",
                                 "%s: %s is not a categorical word" % (where, family))
                self.assertFalse(word.isdigit(),
                                 "%s: %s carries a numeric dial — the 0-9 "
                                 "mechanism has appeared; rewrite this arm"
                                 % (where, family))

    # CHARACTERIZATION — dies with ORC-PLAN-3 step 1.
    def test_there_are_exactly_two_appetite_tables(self):
        """TODAY: two independent declarations of family -> appetite.

        ORC-POL-1 says one file, all readers.  Pinned at two so step 1's
        collapse is measurable, and so a third copy is caught the day it lands.
        """
        self.assertEqual(2, len([t for t in (keeper_appetite(), managent_appetite()) if t]))

    # CHARACTERIZATION — the disagreement itself, pinned. Owner: T802 census.
    def test_the_two_appetite_tables_disagree_today(self):
        """TODAY the two tables disagree on family NAMES and on one appetite.

        keeper: ollama=SPEND, fable=RESERVED.  managent: ollama-cloud=off,
        claude-fable=RESERVED.  So the same model resolves to a different
        family name and (for the ollama models) a different appetite depending
        on which reader you ask.  Pinned as a fact, not a wish: this is the
        11th multi-way job, found by T802's census and absent from the
        roadmap's table of ten.
        """
        k, m = keeper_appetite(), managent_appetite()
        self.assertNotEqual(set(k), set(m),
                            "the two tables' family name sets now agree — "
                            "consolidation may have happened; re-read this arm")
        self.assertEqual("SPEND", k.get("ollama"))
        self.assertEqual("OFF", m.get("ollama-cloud"))

    # CHARACTERIZATION — the latent RESERVED hole. Owner: T802 census.
    def test_keeper_has_no_row_for_ox_alpha_so_it_falls_through_to_spend(self):
        """TODAY: `tools/fleet-keeper.sh` has no ox-alpha row at all.

        `family_of("ox-alpha")` -> "other" -> `APPETITE.get("other", "SPEND")`
        -> SPEND.  The 2026-08-23 operator ruling makes SPEND the *right*
        answer by luck; before it, the keeper would have auto-dispatched an
        identity-sealed RESERVED model.  The keeper never honoured RESERVED
        for ox-alpha; managent did.  Pinned so step 1 fixes the fallthrough
        rather than inheriting it.
        """
        self.assertNotIn("ox-alpha", keeper_family_map(),
                         "keeper now knows ox-alpha — re-read this arm")
        self.assertIn("ox-alpha", managent_model_families())

    @unittest.expectedFailure  # RED — owner: ORC-PLAN-3 step 1 (policy reader)
    def test_appetite_dial_accepts_zero_through_nine_per_model(self):
        """SHOULD (ORC-POL-3): the dial is per model short name, 0-9, with 0 an
        unliftable hard forbid.  No such mechanism exists in any tracked source
        file — the 0-9 semantics live only in orchestration-layer-spec §7c.11
        prose.  RED until step 1 builds the policy reader.
        """
        for text, where in ((src(KEEPER), KEEPER), (src(MAIN_ZIG), MAIN_ZIG)):
            self.assertRegex(text, r"appetite[^\n]*\b[0-9]\s*-\s*9\b",
                             "%s declares no 0-9 appetite dial" % where)

    @unittest.expectedFailure  # RED — owner: ORC-PLAN-3 step 1 (policy reader)
    def test_one_appetite_table_not_two(self):
        """SHOULD (ORC-POL-1): one policy file, all readers.  RED: two tables."""
        self.assertEqual(managent_appetite(), keeper_appetite())


# ---------------------------------------------------------------------------
# ORC-POL-4 / ORC-GATE-2 — the merged cooldown machine
# ---------------------------------------------------------------------------

class TestCooldownMachine(unittest.TestCase):
    """The spec merges THREE cooldowns.  There are FOUR mechanisms.

    ORC-POL-4 and ORC-GATE-2 both name heal (T504) + dispatch (T536) + window
    (T628/T677).  A fourth exists and is not in the merge list: the bare flag
    file `untracked/fleet-keeper.cooldown`, checked by `cooldown_set()`, global
    in scope, with no owner, no reason and no expiry.  It is the mechanism that
    produced the incident ORC-PAUSE-1 exists to end.
    """

    # CHARACTERIZATION — dies with ORC-PLAN-3 step 1/2.
    def test_three_named_cooldowns_are_three_separate_knobs_today(self):
        keeper = src(KEEPER)
        self.assertRegex(keeper, r'HEAL_COOLDOWN\s*=\s*int\(os\.environ\.get\('
                                 r'"FLEET_HEAL_COOLDOWN",\s*"600"\)\)')
        self.assertRegex(keeper, r'DISPATCH_COOLDOWN\s*=\s*int\(os\.environ\.get\('
                                 r'"FLEET_DISPATCH_COOLDOWN",\s*"300"\)\)')
        # the window cooldown lives in a third file with its own state store
        self.assertIn("fleet-window.json", src(WINDOW_POLICY))

    # CHARACTERIZATION — the fourth mechanism. Owner: T802 (finding: merge is 3/4).
    def test_a_fourth_global_cooldown_exists_as_a_bare_flag_file(self):
        """TODAY: `cooldown_set()` is `os.listdir` + basename membership.

        Consequences pinned here, each load-bearing: the flag is a *file's
        existence*, so it carries no owner, no reason and no expiry (ORC-POL-2
        requires all three of every policy entry); it is *global*, so it has no
        family scope (ORC-PAUSE-1 forbids a silent global); and the unreadable
        directory case returns True, so a permissions fault idles the whole
        fleet as a dead-man's switch.  Nothing expires it.
        """
        keeper = src(KEEPER)
        self.assertRegex(keeper, r'COOLDOWN\s*=\s*os\.path\.join\([^)]*'
                                 r'"untracked",\s*"fleet-keeper\.cooldown"\)')
        body = re.search(r"def cooldown_set\(\):(.*?)\ndef ", keeper, re.S)
        self.assertIsNotNone(body, "cooldown_set() not found — parser break")
        body = body.group(1)
        self.assertIn("os.listdir", body)
        self.assertIn("return True", body)          # the dead-man's switch
        self.assertNotIn("expiry", body)
        self.assertNotIn("owner", body)
        self.assertNotIn("family", body)            # global, unscoped

    @unittest.expectedFailure  # RED — owner: ORC-PLAN-3 step 1; spec amendment owed
    def test_merge_list_names_every_cooldown_mechanism_that_exists(self):
        """SHOULD (ORC-POL-4/ORC-GATE-2): the merged machine is ALL of them.

        RED: the spec's merge names three; the global flag file is a fourth and
        is named nowhere in ORC-POL-4 or ORC-GATE-2.  A merge that leaves out
        the mechanism with the incident is the third place to look, preserved.
        """
        spec = src(SPEC)
        merge = re.search(r"\*\*ORC-POL-4.*?\n\n", spec, re.S)
        self.assertIsNotNone(merge, "ORC-POL-4 not found — parser break")
        self.assertIn("fleet-keeper.cooldown", merge.group(0))


# ---------------------------------------------------------------------------
# ORC-DASH-4 — the one pane
# ---------------------------------------------------------------------------

class TestOnePane(unittest.TestCase):

    TODAY = ["PROGRESS", "CONCERNS", "RECENT", "DONE", "OPEN"]
    SPECIFIED = ["keeper", "pauses", "window", "benched", "queue"]

    # CHARACTERIZATION — dies with ORC-PLAN-3 step 3 (dashboard).
    def test_todays_pane_has_these_five_sections(self):
        """TODAY: five sections, printed only when non-empty (T738's rule)."""
        watch = src(WATCH)
        for name in self.TODAY:
            self.assertRegex(watch, r"printf\s+'%b" + name,
                             "watch-fleet no longer prints %s" % name)

    # CHARACTERIZATION — the overlap, measured. Owner: T802 (finding).
    def test_specified_sections_share_nothing_with_todays_sections(self):
        """ORC-PLAN-3 step 3 reads as a MOVE ("rendering moves to managent").

        Measured: the five section names ORC-DASH-4 specifies and the five
        `watch-fleet.sh` renders have an empty intersection.  Step 3 is
        therefore a new build plus a deletion, not a move — and the T738
        omission rule, T739 fill-the-screen rule and T799 footer work all
        attach to sections ORC-DASH-4 does not keep.  Pinned so the plan is
        amended rather than the work being discovered mid-step.
        """
        today = {s.lower() for s in self.TODAY}
        self.assertEqual(set(), today & set(self.SPECIFIED))

    @unittest.expectedFailure  # RED — owner: ORC-PLAN-3 step 3 (dashboard)
    def test_managent_renders_the_five_specified_sections(self):
        """SHOULD (ORC-DASH-1/4): rendering is managent's, five named sections.

        RED: `src/managent/main.zig` renders none of them; the pane is still
        `untracked/watch-fleet.sh`'s.
        """
        zig = src(MAIN_ZIG)
        missing = [s for s in self.SPECIFIED if s not in zig.lower()]
        self.assertEqual([], missing)


# ---------------------------------------------------------------------------
# ORC-ARB-4 — kernel-attested identity (a Security Must)
# ---------------------------------------------------------------------------

class TestAttestedIdentity(unittest.TestCase):

    # CHARACTERIZATION — dies with ORC-PLAN-3 step 2 (arbiter).
    def test_identity_is_read_from_the_environment_today(self):
        """TODAY: the store writer's actor comes from `MANAGENT_TASK_ID`.

        `std.c.getenv("MANAGENT_TASK_ID")` at both the claim/done attribution
        path and the assertion path.  ORC-ARB-4 names this spoofable-by-
        unsetting and forbids it; pinned so step 2 replaces the source rather
        than adding a second one beside it.
        """
        self.assertIn('std.c.getenv("MANAGENT_TASK_ID")', src(MAIN_ZIG))

    # CHARACTERIZATION — the ppid machinery exists but not for attestation.
    def test_ppid_machinery_exists_but_serves_the_host_guard_not_attestation(self):
        """TODAY: managent parses `ps -axo pid=,ppid=,...` for the guard/reap
        path.  So the parent-PID chain ORC-ARB-4 wants is already read — it is
        simply not consulted for store-write authority.  Pinned because step 2
        should extend this reader, not build a second process table.
        """
        zig = src(MAIN_ZIG)
        self.assertIn('"ps", "-axo", "pid=,ppid=,pgid=,uid=,etime=,rss=,state=,comm="', zig)

    @unittest.expectedFailure  # RED — owner: ORC-PLAN-3 step 2 (arbiter)
    def test_store_write_authority_is_not_env_derived(self):
        """SHOULD (ORC-ARB-4, §7c.18): store-write authority is attested from
        the supervisor's held-child table, never from the environment.  RED:
        env is the only source today.
        """
        zig = src(MAIN_ZIG)
        self.assertNotIn('std.c.getenv("MANAGENT_TASK_ID")', zig)


# ---------------------------------------------------------------------------
# ORC-PLAN-5 — the disposition table is counted, not asserted
# ---------------------------------------------------------------------------

class TestDispositionCount(unittest.TestCase):
    """ORC-PLAN-5 says a script left off the table is a spec defect.  It says
    it in prose, and prose does not count scripts: the spec was correct at its
    own pin (75 at a1415fe) and drifted to 80 in eight hours.  This arm is the
    mechanism that prose was standing in for.
    """

    @staticmethod
    def live_count():
        return len(glob.glob(os.path.join(REPO, "tools", "regression-*.sh")))

    @staticmethod
    def declared_count(spec_text):
        m = re.search(r"ORC-PLAN-4[^\n]*\*\*\)?\s*(\d+)\s*`tools/regression-\*\.sh`",
                      spec_text)
        if not m:
            m = re.search(r"(\d+)\s*`tools/regression-\*\.sh`\s*at\s*`HEAD`", spec_text)
        return int(m.group(1)) if m else None

    def test_null_control_a_correct_declaration_passes(self):
        n = self.live_count()
        fixture = "**ORC-PLAN-4 (x).** %d `tools/regression-*.sh` at `HEAD`." % n
        self.assertEqual(n, self.declared_count(fixture))

    def test_seeded_control_a_wrong_declaration_is_caught(self):
        n = self.live_count()
        fixture = "**ORC-PLAN-4 (x).** %d `tools/regression-*.sh` at `HEAD`." % (n - 5)
        self.assertNotEqual(n, self.declared_count(fixture))

    def test_the_spec_declares_the_live_count(self):
        declared = self.declared_count(src(SPEC))
        self.assertIsNotNone(declared, "no regression-script count found in the "
                                       "spec — ORC-PLAN-4 has been reworded")
        self.assertEqual(self.live_count(), declared,
                         "the spec's disposition count has drifted from "
                         "`ls tools/regression-*.sh`")


# ---------------------------------------------------------------------------
# Census: the six absorption targets are live or not, on evidence
# ---------------------------------------------------------------------------

class TestAbsorptionTargetsAreLive(unittest.TestCase):
    """The census question per target: should it exist at all?

    Answered on *import/exec evidence*, never on static reachability alone —
    T771's correction, where a basename grep called a live gate dead.  Two of
    the six were on a no-production-caller list and both gate every dispatch.
    """

    # CHARACTERIZATION — dies with ORC-PLAN-3 steps 1/5.
    def test_window_policy_is_imported_by_both_front_doors(self):
        for door in ("bin/dispatch", "bin/subagent"):
            self.assertRegex(src(door), r"(?m)^import window_policy")

    # CHARACTERIZATION — dies with ORC-PLAN-3 step 1.
    def test_directive_policy_is_imported_by_dispatch_and_the_runner(self):
        self.assertRegex(src("bin/dispatch"), r"(?m)^import directive_policy")
        self.assertRegex(src("tools/runner"), r"(?m)^import directive_policy")

    # CHARACTERIZATION — dies with ORC-PLAN-3 step 2 (arbiter absorbs the loop).
    def test_the_keeper_has_no_code_caller_only_a_launchd_plist(self):
        """TODAY: nothing in bin/ tools/ src/ execs the keeper; its production
        shape is `tools/weizigo.fleet-keeper.plist`.  So "is it live" cannot be
        answered from the tree at all — it is answered by the host.  Pinned
        because absorb-vs-delete for the keeper turns on exactly this.
        """
        self.assertIn("tools/fleet-keeper.sh", src("tools/weizigo.fleet-keeper.plist"))

    # CHARACTERIZATION — dies with ORC-PLAN-3 step 3.
    def test_watch_fleet_has_no_code_caller_it_is_human_invoked(self):
        """TODAY: `untracked/watch-fleet.sh` is referenced by its own regression
        arm and by commit tooling, and exec'd by nothing.  Its caller is the
        operator's terminal — a target whose only caller is a human still
        cannot be deleted, which is why static reachability is not the test.
        """
        for producer in ("bin/dispatch", "bin/subagent", "tools/runner"):
            self.assertNotRegex(src(producer), r"exec[^\n]*watch-fleet")


if __name__ == "__main__":
    unittest.main(verbosity=2)
