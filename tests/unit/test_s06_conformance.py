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

**Counts.** 63 arms: **35 GREEN** characterization + null/seeded controls, **28 RED**
spec-conformance covering **32 normative ids** (all of §1–§7 after T822's arm-or-delete:
ORC-GOAL-1..4 were deleted — goals are §10's acceptance bars, not ids — and ORC-GATE-2 was
deleted as a duplicate of ORC-POL-4; every remaining id carries at least one arm on disk. One
arm can assert more than one id, so arms and ids are not in bijection and are counted separately).
The 7 arms added by T813 (3 GREEN, 4 RED) cover POL-8…13; the arms added by T822 cover the 15
flips-column ids and the six remaining unarmed ids (POL-5, POL-6, POL-13, PAUSE-3, GATE-1,
ORIENT-1), and replaced the adjacent arms RACE-X flagged (POL-4's prose regex, DASH-1/DASH-4's
substring greps).

**Labels** (`tests/roundtrip/README.md`'s vocabulary, which this tier honours):
CHARACTERIZATION arms pin today and are expected GREEN; they are deleted or
rewritten by the migration step that intentionally changes the subject, named
per arm.  SPEC-CONFORMANCE arms are `@unittest.expectedFailure` with the row
that owes the mechanism.  An unlabelled arm is the defect the labels prevent.
"""
import glob
import json
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
POLICY_FILE = "docs/infra/orchestration-policy.json"


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
        """TODAY the two tables disagree on family NAMES (keeper: `ollama`;
        managent: `ollama-cloud`) — so the same model resolves to a different
        family name depending on which reader you ask.  The appetite for the
        ollama family now AGREE: T834 (operator ruling 2026-08-24) returned
        main.zig's ollama-cloud OFF → SPEND, a step-1 slice landed ahead of
        the sprint (the family-NAME multi-way job survives it).  Pinned as a
        fact, not a wish: the multi-way job is the name resolution, and this
        arm dies only when the tables share one namespace.
        """
        k, m = keeper_appetite(), managent_appetite()
        self.assertNotEqual(set(k), set(m),
                            "the two tables' family name sets now agree — "
                            "consolidation may have happened; re-read this arm")
        self.assertEqual("SPEND", k.get("ollama"))

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
# T813 — the dial + class semantics (ORC-POL-8/9/10)
# ---------------------------------------------------------------------------

class TestAppetiteDialAndClass(unittest.TestCase):
    """The operator's 2026-08-23 ruling: the 0-9 dial and the class are TWO
    first-class configurations.  Today the code has one — the class — and it
    collapses to a binary gate (off/reserved/probe exclude, spend/conserve
    pass); the dial exists in no tracked source file.
    """

    # CHARACTERIZATION — dies with ORC-PLAN-3 step 1 (policy reader).
    def test_conserve_has_no_branch_today(self):
        """TODAY (ORC-POL-8): `conserve` is dead code — `filterQualified`
        excludes `.off`/`.reserved`/`.probe` and has NO `.conserve` branch, so
        a CONSERVE family falls through to the candidate list exactly like
        SPEND.  Pinned so step 1 retires the level rather than silently
        keeping a five-level enum that behaves as two.
        """
        zig = src(MAIN_ZIG)
        self.assertIn("if (app == .off)", zig)
        self.assertIn("if (app == .reserved)", zig)
        self.assertIn("if (app == .probe)", zig)
        self.assertNotIn("if (app == .conserve)", zig,
                         "a .conserve branch now exists — the level is "
                         "implemented; re-read this arm and ORC-POL-8's "
                         "retire decision")

    # CHARACTERIZATION — dies with ORC-PLAN-3 step 1.
    def test_reserved_and_probe_name_conditions_that_do_not_exist_today(self):
        """TODAY (ORC-POL-9): the `.reserved`/`.probe` branches exclude with
        reason strings naming "reserved task types only" / "probe-flagged rows
        only", but no row carries either flag — the conditions they name do
        not exist.  Pinned so step 1 defines the row flags rather than
        deleting the levels the operator values ("1 is less informative than
        RESERVE and PROBE").
        """
        zig = src(MAIN_ZIG)
        self.assertIn("reserved task types only", zig)
        self.assertIn("probe-flagged rows only", zig)
        # the Row struct has a shape field but no reserved/probe flag
        self.assertNotRegex(zig, r"reserved\s*:\s*\?bool")
        self.assertNotRegex(zig, r"probe\s*:\s*\?bool")

    @unittest.expectedFailure  # RED — owner: ORC-PLAN-3 step 1 (policy reader)
    def test_dial_is_a_weight_and_zero_excludes(self):
        """SHOULD (ORC-POL-8/10): a per-model dial d in 0..9; d=0 excludes,
        d>=1 weights the draw.  RED: no dial mechanism at all — the word
        "dial" appears nowhere in main.zig, and the draw is uniform
        (`drawCandidate` = `rng.uintLessThan`).
        """
        zig = src(MAIN_ZIG)
        self.assertRegex(zig, r"dial", "no per-model dial mechanism at all")
        self.assertNotIn("rng.uintLessThan", zig,
                         "draw is still uniform — the dial-weighted draw has "
                         "not replaced it")

    @unittest.expectedFailure  # RED — owner: ORC-PLAN-3 step 1
    def test_selection_consults_class_then_qualification_then_dial(self):
        """SHOULD (ORC-POL-9): selection order class gate -> dial-0 forbid ->
        qualification -> dial-weighted draw -> cost reported.  RED: today the
        class is a binary gate and the draw is uniform — the word "dial"
        appears only in comments (T834's 2026-08-24 note); no dial-weighted
        draw mechanism exists in any tracked source.
        """
        zig = src(MAIN_ZIG)
        self.assertRegex(zig, r"\bdial\b[^\n]*\bweight\b|\bweight\b[^\n]*\bdial\b",
                         "no dial mechanism consulted in selection")
        self.assertNotRegex(zig, r"measured cost .* > .*\(cheapest\)",
                            "cost still decides a pick — it must be reporting "
                            "only (T772 ratified)")

    @unittest.expectedFailure  # RED — owner: ORC-PLAN-3 step 1
    def test_dial_inheritance_is_materialized_not_hidden(self):
        """SHOULD (ORC-POL-10): a model with no dial row inherits its family's
        default dial, materialized at parse time; a model whose family has no
        default is a parse error.  RED: no `default_dial` mechanism to inherit
        from.
        """
        zig = src(MAIN_ZIG)
        self.assertRegex(zig, r"default_dial",
                         "no materialized dial-inheritance mechanism")


# ---------------------------------------------------------------------------
# ORC-POL-4 / ORC-GATE-2 — the merged cooldown machine
# ---------------------------------------------------------------------------

class TestCooldownMachine(unittest.TestCase):
    """The spec merges THREE cooldowns.  There are FOUR mechanisms.

    ORC-POL-4 names heal (T504) + dispatch (T536) + window (T628/T677) — and
    ORC-GATE-2 was a duplicate of POL-4, folded into it by T822.  A fourth
    mechanism exists and is not in the merge list: the bare flag file
    `untracked/fleet-keeper.cooldown`, checked by `cooldown_set()`, global in
    scope, with no owner, no reason and no expiry.  It is the mechanism that
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

    @unittest.expectedFailure  # RED — owner: ORC-PLAN-3 step 1 (policy reader)
    def test_one_cooldown_machine_names_all_four_mechanisms(self):
        """SHOULD (ORC-POL-4): ONE visible cooldown machine in the policy
        reader names all four mechanisms — heal, dispatch, window, and the
        global flag file whose boolean becomes a scoped/owned/expiring state
        (the ORC-PAUSE-1 incident's mechanism).

        RED: main.zig has no cooldown machine at all.  (T822 replaced the
        rev-2 prose-regex arm here, whose green condition was a spec edit —
        the adjacent-arm class RACE-X flagged.  This arm's green condition is
        code in the reader, never prose in the spec.)
        """
        zig = src(MAIN_ZIG)
        self.assertIn("cooldown", zig,
                      "no cooldown machine in the policy reader")
        self.assertIn("fleet-keeper.cooldown", zig,
                      "the global flag file is not a named state of the machine")


# ---------------------------------------------------------------------------
# T813 — cooldown = prohibition with scope + reason + end (ORC-POL-11/12/13)
# ---------------------------------------------------------------------------

class TestCooldownSemantics(unittest.TestCase):
    """T813: cooldown is prohibition (do not draw until the end-condition),
    each carrying scope + reason + end; a rate reduction is the dial, never a
    cooldown.  Today the auto-cooldown is one narrow case — family-only,
    provider-limit-only, duration-only — wearing the general name.
    """

    # CHARACTERIZATION — dies with ORC-PLAN-3 step 1.
    def test_todays_auto_cooldown_is_one_narrow_case(self):
        """TODAY (ORC-POL-11/12): `window_policy.py`'s `family_cooldown` keys
        by family only (no model/fleet scope), arms only from a provider-limit
        death (no reason enumeration), and ends only on a duration (a reset
        epoch or `FALLBACK_COOLDOWN_SECONDS`) — no `until`-condition, no
        `indefinite`.  Pinned so step 1 widens the concept rather than keeping
        the narrow case's name.
        """
        wp = src(WINDOW_POLICY)
        body = re.search(r"def family_cooldown\(.*?\n\s*return by_family", wp, re.S)
        self.assertIsNotNone(body, "family_cooldown not found — parser break")
        b = body.group(0)
        self.assertIn("by_family[fam]", b)      # family scope only
        self.assertNotIn("scope", b)            # no scope axis
        self.assertNotIn("indefinite", b)       # no indefinite end-form
        self.assertNotIn("until-done", b)       # no until-condition
        self.assertIn('"provider-limit"', wp)   # the only reason
        self.assertNotIn("graceful-shutdown", wp)
        self.assertNotIn("reserve-queue-for-refactor", wp)

    @unittest.expectedFailure  # RED — owner: ORC-PLAN-3 step 1
    def test_cooldown_carries_reason_end_and_scope(self):
        """SHOULD (ORC-POL-11/12): every cooldown carries scope + reason + end,
        with the reason enumeration (provider-limit, graceful-shutdown,
        reserve-queue-for-refactor, preserve-tokens-before-reset,
        operator-manual) and the three end-forms (duration, until, indefinite).
        RED: today the cooldown is family-only, provider-limit-only,
        duration-only.
        """
        wp = src(WINDOW_POLICY)
        self.assertRegex(wp, r"scope", "no scope axis in the cooldown record")
        self.assertRegex(wp,
                         r"graceful-shutdown|reserve-queue-for-refactor|"
                         r"preserve-tokens-before-reset|operator-manual",
                         "no reason enumeration")
        self.assertRegex(wp, r"indefinite", "no indefinite end-form")


# ---------------------------------------------------------------------------
# ORC-DASH-4 — the one pane
# ---------------------------------------------------------------------------

class TestOnePane(unittest.TestCase):

    TODAY = ["PROGRESS", "CONCERNS", "RECENT", "DONE", "OPEN"]
    # T822: "window" corrected to "appetite" (T810 R6 — the retired meter's
    # name leaked into the normative section list; the pane's section is the
    # appetite + cap one the rendered example already shows).
    SPECIFIED = ["keeper", "pauses", "appetite", "benched", "queue"]

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
        """SHOULD (ORC-DASH-1/4): rendering is managent's, five named sections,
        and watch-fleet is a thin refresh wrapper holding no section printers.
        RED: main.zig renders none of them and watch-fleet still does.  (T822
        strengthened the rev-2 substring grep with the watch-fleet-thin half,
        so a comment containing the five words cannot turn it green.)
        """
        zig = src(MAIN_ZIG)
        missing = [s for s in self.SPECIFIED if s not in zig.lower()]
        self.assertEqual([], missing)
        watch = src(WATCH)
        self.assertNotRegex(
            watch,
            r"printf\s+'%b(PROGRESS|CONCERNS|RECENT|DONE|OPEN)",
            "watch-fleet still renders sections — step 3 must make it a thin "
            "wrapper before this arm can go green")


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


# ---------------------------------------------------------------------------
# T822 (arm-or-delete) — ORC-POL-2 / ORC-POL-5 — the policy file and its
# entry contract.  The file is the artifact step 1 builds; both arms are RED
# until it exists.
# ---------------------------------------------------------------------------

class TestPolicyFile(unittest.TestCase):
    """ORC-POL-5 (the schema's worked example) and ORC-POL-2 (every entry
    carries owner/reason/expiry) are the gate-as-data artifact — committed at
    `docs/infra/orchestration-policy.json`, never in untracked/.
    """

    @unittest.expectedFailure  # RED — owner: ORC-PLAN-3 step 1 (policy reader)
    def test_policy_file_exists_with_schema_version_two(self):
        """SHOULD (ORC-POL-5): the policy file is valid JSON, schema_version 2,
        with the worked example's top-level blocks.  RED: no such file.
        """
        path = os.path.join(REPO, POLICY_FILE)
        self.assertTrue(os.path.exists(path),
                        "%s does not exist — step 1 has not built the policy "
                        "file" % POLICY_FILE)
        data = json.load(open(path, encoding="utf-8"))
        self.assertEqual(2, data.get("schema_version"),
                         "schema_version is not 2 (T813)")
        for block in ("appetite", "caps", "allow_deny", "cooldowns",
                      "pause_default"):
            self.assertIn(block, data,
                          "policy file missing %s block" % block)

    @unittest.expectedFailure  # RED — owner: ORC-PLAN-3 step 1 (policy reader)
    def test_every_policy_entry_carries_owner_reason_and_expiry(self):
        """SHOULD (ORC-POL-2): every entry is a record {value, owner, reason,
        expiry}; an entry with no owner/reason is refused at parse time (an
        invisible default wearing a config costume), and the reader refuses
        rather than warns.  RED: no file, no reader refusal.
        """
        path = os.path.join(REPO, POLICY_FILE)
        self.assertTrue(os.path.exists(path),
                        "%s does not exist" % POLICY_FILE)
        data = json.load(open(path, encoding="utf-8"))
        entries = []
        entries.extend(data.get("appetite", []))
        entries.extend(data.get("caps", []))
        entries.extend(data.get("allow_deny", {}).get("deny", []))
        entries.extend(data.get("allow_deny", {}).get("allow", []))
        entries.extend(data.get("cooldowns", {}).values())
        if isinstance(data.get("pause_default"), dict):
            entries.append(data["pause_default"])
        self.assertTrue(entries, "policy file has no entries to check")
        for e in entries:
            self.assertIn("owner", e,
                          "entry %r has no owner (ORC-POL-2)" % (e,))
            self.assertIn("reason", e,
                          "entry %r has no reason (ORC-POL-2)" % (e,))
            self.assertIn("expiry", e,
                          "entry %r has no expiry key (ORC-POL-2)" % (e,))
        self.assertRegex(src(MAIN_ZIG), r"no owner.*(reason|refus)",
                         "the policy reader does not refuse an entry with no "
                         "owner/reason — it must refuse at parse, never warn")


# ---------------------------------------------------------------------------
# T822 — ORC-POL-7 — env vars are overrides, and overrides are recorded.
# ---------------------------------------------------------------------------

class TestEnvOverrides(unittest.TestCase):
    """POL-7 generalizes the T677 override-recording precedent: a knob with no
    policy-file entry is refused — the D036 silent-default class dies here.
    """

    # CHARACTERIZATION — the T677 precedent is live today.
    def test_override_recording_precedent_exists(self):
        """TODAY: `fleet-window-overrides.jsonl` is written by window_policy,
        dispatch and subagent (T677).  POL-7 generalizes this recording to
        every override; pinned so the generalization is measurable.
        """
        for target in (WINDOW_POLICY, "bin/dispatch", "bin/subagent"):
            self.assertIn("fleet-window-overrides.jsonl", src(target),
                          "%s no longer records overrides (T677 precedent)" % target)

    @unittest.expectedFailure  # RED — owner: ORC-PLAN-3 step 1 (policy reader)
    def test_knob_with_no_file_entry_is_refused(self):
        """SHOULD (ORC-POL-7): a knob with no corresponding policy-file entry
        is refused with the D036-killing line.  RED: the refusal string exists
        nowhere.
        """
        zig = src(MAIN_ZIG)
        self.assertIn("add it to the policy file or it is not a knob", zig,
                      "no unbacked-knob refusal in the policy reader")


# ---------------------------------------------------------------------------
# T822 — ORC-POL-6 — an unknown model resolves to a refusal, never a default.
# The GREEN arm (test_keeper_has_no_row_for_ox_alpha_...) pins today's
# fallthrough; this is the conformance half.
# ---------------------------------------------------------------------------

class TestUnknownModelRefusal(unittest.TestCase):
    """ORC-POL-6's live normative content (T813 moved RESERVED/PROBE off the
    dial axis into ORC-POL-9's class values): an unknown model resolves to a
    REFUSAL, never to a silently-permitting default appetite.
    """

    @unittest.expectedFailure  # RED — owner: ORC-PLAN-3 step 1 (policy reader)
    def test_unknown_model_resolves_to_a_refusal(self):
        """SHOULD (ORC-POL-6): an unknown model is refused, never silently
        drawn at a default appetite.  RED: the keeper's SPEND fallthrough
        still exists.
        """
        keeper = src(KEEPER)
        self.assertNotIn('APPETITE.get(fam, "SPEND")', keeper,
                         "the silent SPEND fallthrough for an unknown family "
                         "still exists — step 1 must replace it with a refusal")


# ---------------------------------------------------------------------------
# T822 — ORC-POL-13 / ORC-PAUSE-3 — legibility: cooldowns and pauses as rows.
# Both are the dashboard-row contracts that would have made the 2026-08-20→23
# silent cooldown visible.
# ---------------------------------------------------------------------------

class TestLegibilityRows(unittest.TestCase):
    """ORC-POL-13 (a cooldown is legible or it does not exist) and
    ORC-PAUSE-3 (each pause is one row with owner/reason/age/expiry, no second
    ledger) are step 3's pane contracts.  Both RED until the pane exists.
    """

    @unittest.expectedFailure  # RED — owner: ORC-PLAN-3 step 3 (dashboard)
    def test_each_cooldown_renders_as_one_row_with_scope_reason_end(self):
        """SHOULD (ORC-POL-13): every cooldown renders on the dashboard as one
        row — what is cooled (scope), why (reason), when/on-what it ends
        (end-condition) — beside the pauses section.  RED: main.zig has no
        cooldown rendering at all.
        """
        zig = src(MAIN_ZIG)
        self.assertRegex(zig, r"cooldown[^\n]*(scope|reason|end)",
                         "no dashboard cooldown row carrying scope/reason/end")

    @unittest.expectedFailure  # RED — owner: ORC-PLAN-3 step 3 (dashboard)
    def test_each_pause_renders_as_one_row_with_owner_reason_age_expiry(self):
        """SHOULD (ORC-PAUSE-3): each pause is one dashboard row with owner /
        reason / age / expiry, one state in the merged cooldown machine, and
        no second ledger the operator must consult.  RED: no pause-row
        rendering in main.zig.
        """
        zig = src(MAIN_ZIG)
        self.assertRegex(zig, r"pause[^\n]*(owner|reason|age|expiry)",
                         "no dashboard pause row carrying owner/reason/age/expiry")


# ---------------------------------------------------------------------------
# T822 — ORC-DASH-5 — the pane's data sources, wired; a dashboard invents
# nothing (the QA-023 class is C6's seeded control, P3).
# ---------------------------------------------------------------------------

class TestDashboardSources(unittest.TestCase):
    """ORC-DASH-5: the five sections render only store/policy-held numbers.
    The dashboard verb exists in no command table today.
    """

    @unittest.expectedFailure  # RED — owner: ORC-PLAN-3 step 3 (dashboard)
    def test_dashboard_reads_only_the_five_stated_sources(self):
        """SHOULD (ORC-DASH-5): keeper liveness ← heartbeat/lease, pauses ←
        directives.jsonl, appetite ← policy file, benched ← the arbiter's
        benched set, queue ← status --json.  RED: no dashboard verb, and
        nothing reads the policy file.
        """
        zig = src(MAIN_ZIG)
        self.assertRegex(zig, r'"(dashboard|fleet)"',
                         "no dashboard verb in managent's command table")
        self.assertRegex(zig, r"orchestration-policy\.json",
                         "nothing reads the policy file (the appetite source)")


# ---------------------------------------------------------------------------
# T822 — ORC-DASH-2 — short names only, one table (T738/T739 carried into Zig).
# ---------------------------------------------------------------------------

class TestShortNames(unittest.TestCase):
    """ORC-DASH-2: human surfaces show SHORT names resolved through the one
    short-name table; no second mapping.  The interim wrapper does this today;
    the managent pane must keep it.
    """

    # CHARACTERIZATION — dies with ORC-PLAN-3 step 3.
    def test_watch_fleet_resolves_short_names_through_the_one_table(self):
        """TODAY: watch-fleet's mdl() reads docs/infra/model-registry.md and
        holds no second mapping.  Pinned so step 3 carries the resolution into
        managent rather than re-inventing a second table.
        """
        watch = src(WATCH)
        self.assertIn("model-registry.md", watch)
        self.assertIn("mdl()", watch)
        self.assertIn("no second mapping", watch)

    @unittest.expectedFailure  # RED — owner: ORC-PLAN-3 step 3 (dashboard)
    def test_managent_pane_resolves_short_names_through_the_one_table(self):
        """SHOULD (ORC-DASH-2): the managent pane reads the one short-name
        table (model-registry.md); canonical labels never render on the human
        pane.  RED: no registry read in main.zig — the model tables are still
        hardcoded Zig declarations.
        """
        zig = src(MAIN_ZIG)
        self.assertRegex(zig, r'"(?:docs/infra/)?model-registry\.md"',
                         "managent does not read the one short-name table")


# ---------------------------------------------------------------------------
# T822 — ORC-DASH-3 — empty sections omitted; recovered height shows rows.
# ---------------------------------------------------------------------------

class TestEmptySections(unittest.TestCase):
    """ORC-DASH-3: T738's omission rule and T739's fill-the-screen rule.  The
    interim wrapper omits empty sections today; the managent pane must keep
    the rule — and the codebase convention is that a mechanism cites the
    ruling it implements (cf. the T353 cap in orient).
    """

    # CHARACTERIZATION — dies with ORC-PLAN-3 step 3.
    def test_watch_fleet_omits_empty_sections_today(self):
        """TODAY: watch-fleet prints a section heading only when its row file
        is non-empty (T738's rule, the `[ "$np" -gt 0 ]` guards).
        """
        watch = src(WATCH)
        self.assertRegex(watch, r'\[ "\$np" -gt 0 \]')
        self.assertRegex(watch, r'\[ "\$nc" -gt 0 \]')

    @unittest.expectedFailure  # RED — owner: ORC-PLAN-3 step 3 (dashboard)
    def test_managent_pane_omits_empty_sections(self):
        """SHOULD (ORC-DASH-3): a section with zero rows prints nothing in the
        managent pane; recovered vertical space becomes visible rows (T739).
        RED: the pane implements neither rule — no T738/T739 citation exists
        in main.zig's rendering.
        """
        zig = src(MAIN_ZIG)
        self.assertIn("T738", zig, "no T738 (omission rule) citation")
        self.assertIn("T739", zig, "no T739 (fill-the-screen rule) citation")


# ---------------------------------------------------------------------------
# T822 — ORC-PAUSE-1 / ORC-PAUSE-2 — expiring pauses: the T625 mechanism
# exists in Python today; the policy file is its new home.
# ---------------------------------------------------------------------------

class TestPauseSemantics(unittest.TestCase):
    """ORC-PAUSE-1 (scoped, expiring, 5h default, lapses loudly) and
    ORC-PAUSE-2 (the T625 discharge rules become policy-file semantics).
    """

    # CHARACTERIZATION — dies with ORC-PLAN-3 step 1.
    def test_directive_policy_has_discharge_and_staleness_today(self):
        """TODAY (ORC-PAUSE-2): directive_policy.py (T625) already evaluates
        discharge-by-condition (`until_done` re-checked at every apply) and
        the staleness horizon (STALE_HOURS_DEFAULT); `kill` is never stale.
        Pinned so step 1 carries the semantics, not re-implements them.
        """
        dp = src(DIRECTIVE_POLICY)
        self.assertIn("until_done", dp)
        self.assertIn("STALE_HOURS_DEFAULT", dp)
        self.assertIn("never stale", dp)

    @unittest.expectedFailure  # RED — owner: ORC-PLAN-3 step 1 (policy reader)
    def test_pause_default_max_and_loud_expiry_in_the_policy_file(self):
        """SHOULD (ORC-PAUSE-1): a pause has a 5-hour default maximum
        (`pause_default.max_seconds == 18000` in the policy file) and lapses
        loudly (the pane renders EXPIRED, never silently re-enforcing).  RED:
        no policy file, no EXPIRED pause rendering in main.zig.
        """
        path = os.path.join(REPO, POLICY_FILE)
        self.assertTrue(os.path.exists(path), "no policy file")
        data = json.load(open(path, encoding="utf-8"))
        self.assertEqual(18000, data.get("pause_default", {}).get("max_seconds"),
                         "pause_default.max_seconds is not the 5-hour default "
                         "maximum")
        self.assertRegex(src(MAIN_ZIG), r"EXPIRED[^\n]*pause|pause[^\n]*EXPIRED",
                         "no loud-EXPIRED pause rendering in the managent pane")

    @unittest.expectedFailure  # RED — owner: ORC-PLAN-3 step 1 (policy reader)
    def test_staleness_horizon_lives_in_the_policy_file(self):
        """SHOULD (ORC-PAUSE-2): `cooldowns.stale_directive_hours` is
        policy-file data, not Python; discharge-by-condition re-evaluates at
        every apply.  RED: the file does not exist.
        """
        path = os.path.join(REPO, POLICY_FILE)
        self.assertTrue(os.path.exists(path), "no policy file")
        data = json.load(open(path, encoding="utf-8"))
        cd = data.get("cooldowns", {})
        self.assertIn("stale_directive_hours", cd,
                      "stale_directive_hours not in the policy file's cooldowns")


# ---------------------------------------------------------------------------
# T822 — ORC-REG-1..4 — the file-first registration contract.
# ---------------------------------------------------------------------------

class TestRegistrationContract(unittest.TestCase):
    """ORC-REG-3's five required fields, refused at the `managent` call with
    the missing field named and a worked example.  The landmark field is
    enforced today (T682, regression-managent-landmark.sh); the title-length
    and gate-declaration fields are not — those are the RED half.
    """

    # CHARACTERIZATION — the landmark gate exists at add (T682).
    def test_landmark_gate_is_enforced_at_registration(self):
        """TODAY (ORC-REG-3 field 3): `add` refuses a bundle with no (or an
        unknown) **Landmark:** line via enforceBundleLandmark — the T592
        defect's mechanical fix, behaviorally held by
        regression-managent-landmark.sh.
        """
        zig = src(MAIN_ZIG)
        self.assertIn("checkBundleLandmark", zig)
        self.assertIn("valid_landmark_ids", zig)
        self.assertIn("enforceBundleLandmark", zig)

    @unittest.expectedFailure  # RED — owner: ORC-PLAN-3 step 4 (registration)
    def test_registration_refuses_title_and_gate_at_add(self):
        """SHOULD (ORC-REG-3): all five fields are refused AT the managent
        call — including title ≤40 and the gate declaration, which today are
        enforced only at dispatch (T505) or not at all.  RED: main.zig's add
        has neither refusal.
        """
        zig = src(MAIN_ZIG)
        self.assertRegex(zig, r"title[^\n]*(40|too long|under 40)",
                         "no title-length refusal at registration")
        self.assertRegex(zig, r"gate[^\n]*(declar|declared)",
                         "no gate-declaration refusal at registration")

    @unittest.expectedFailure  # RED — owner: ORC-PLAN-3 step 4 (registration)
    def test_one_parser_shared_by_add_suggest_and_dispatch(self):
        """SHOULD (ORC-REG-2): add, suggest and dispatch share ONE bundle-
        header parser, so an edge read by one surface can never be dropped by
        another (the T735 defect).  RED: bin/dispatch still parses the bundle
        header itself (the T505 title_re) — a second parser.
        """
        self.assertNotIn("title_re", src("bin/dispatch"),
                         "dispatch still parses the bundle header itself — "
                         "the one-parser contract is unmet")

    # CHARACTERIZATION — the T735/T539 repair is the parser, and it is held.
    def test_holds_edges_are_read_by_the_one_parser_at_add(self):
        """TODAY (ORC-REG-4): `add` reads holds= through parseBundleMeta and
        mergeHoldsFlag; regression-managent-holds.sh (T539) is the cross-tier
        control that a dropped holds edge makes the parser red.  The repair is
        the parser, not a one-off sweep — pinned.
        """
        zig = src(MAIN_ZIG)
        self.assertIn("parseBundleMeta", zig)
        self.assertIn("mergeHoldsFlag", zig)


class TestStoreWriteRefusal(unittest.TestCase):
    """ORC-REG-1: agents never write tasks.json; a direct edit fails
    mechanically (hook/permission), never by prose.  Today nothing refuses a
    direct tasks.json edit — the pre-commit hook guards held paths, not the
    store file.
    """

    @unittest.expectedFailure  # RED — owner: ORC-PLAN-3 step 4 (registration)
    def test_direct_tasks_json_edits_fail_mechanically(self):
        """SHOULD (ORC-REG-1): a direct edit of tasks.json fails mechanically
        (a hook check or a managent permission refusal) — the silent-write
        class dies here.  RED: the pre-commit hook guards held paths but has
        no store-file guard.
        """
        hook = src("tools/hooks/pre-commit")
        self.assertRegex(hook, r"tasks\.json[^\n]*(refus|guard|REJECT|reject)",
                         "no mechanical refusal of direct tasks.json edits")


# ---------------------------------------------------------------------------
# T822 — ORC-ARB-1/2/3 — the arbiter.  T821 (ram-policy.md) built it ahead of
# this sprint's P4.2; its own controls are tools/regression-arbiter.sh.
# ---------------------------------------------------------------------------

class TestArbiter(unittest.TestCase):
    """ORC-ARB-1/3.  One admission component in tools/runner decides before
    any child is spawned (refuse = nothing ever spawned, the row stays
    dispatchable); the futile largest-member kill is deleted; an alarm names
    the real host-wide consumer and never kills.  The policy-driven
    deterministic pre-pass in managent is the unbuilt half.
    """

    # CHARACTERIZATION — the T821 arbiter exists, with no victim selector.
    def test_arbiter_exists_as_one_admission_component(self):
        """TODAY (ORC-ARB-1, built ahead by T821): tools/runner decides
        admission (ARBITER_RESERVE_MB, --arbiter-admit) before any child is
        spawned, and the deleted victim selector stays deleted.  The control
        battery is tools/regression-arbiter.sh — the P4.2 bar itself.
        """
        runner = src("tools/runner")
        self.assertIn("ARBITER_RESERVE_MB", runner)
        self.assertIn("--arbiter-admit", runner)
        self.assertNotRegex(runner, r"def _select_host_guard_victim",
                             "the deleted victim selector has returned")
        # the name survives only in the deletion note (T821) — that is not a
        # return; the function definition is what the ban is about.
        self.assertIn("is DELETED", runner)

    # CHARACTERIZATION — the pre-launch preview exists (zero tokens on refusal).
    def test_arbiter_refusal_precedes_any_model_token(self):
        """TODAY (ORC-ARB-3, half): bin/subagent runs --arbiter-preview before
        building the launch command — a refused lane spends zero model tokens.
        The policy-driven pre-pass in managent is the unbuilt half.
        """
        self.assertIn("--arbiter-preview", src("bin/subagent"))

    @unittest.expectedFailure  # RED — owner: ORC-PLAN-3 step 1/2
    def test_policy_driven_prepass_exists_in_managent(self):
        """SHOULD (ORC-ARB-3): the arbiter's deterministic pre-pass applies
        every (a)/(b) mechanism from the policy file before any model token is
        spent; a quiet store is a zero-token wake.  RED: managent reads
        neither the policy file nor a pre-pass.
        """
        zig = src(MAIN_ZIG)
        self.assertRegex(zig, r"orchestration-policy\.json",
                         "managent does not read the policy file (the pre-pass "
                         "input)")


class TestAttribution(unittest.TestCase):
    """ORC-ARB-2: a guard stops a lane; attribution is a measurement decision
    that never shares a code path.  The killed_by enum is stamped by the
    runner's own terminal record (T629); the scorer-side refusal with a stated
    skip count is the unbuilt half.
    """

    # CHARACTERIZATION — the T629 killed_by vocabulary exists.
    def test_killed_by_is_an_enumerated_runner_stamped_value(self):
        """TODAY (ORC-ARB-2, half): tools/runner's `_killed_by` maps each guard
        reason to the T629 enum, stamped from the runner's own terminal record;
        dispatch_verify reads the KILLED_BY_VALUES vocabulary.
        """
        self.assertIn("def _killed_by", src("tools/runner"))
        self.assertIn("KILLED_BY_VALUES", src("tools/dispatch_verify.py"))

    @unittest.expectedFailure  # RED — owner: ORC-PLAN-3 step 2 (arbiter)
    def test_every_scorer_refuses_killed_rows_with_skip_count(self):
        """SHOULD (ORC-ARB-2): any row with killed_by != none is refused by
        every scorer, with the skip count stated — a stopped lane never enters
        a measurement.  RED: main.zig's §5 gate carries no killed_by handling.
        """
        zig = src(MAIN_ZIG)
        self.assertRegex(zig, r"killed_by[^\n]*(refus|skip|never scored)",
                         "no killed_by refusal in the §5 gate")


# ---------------------------------------------------------------------------
# T822 — ORC-PROV-1 — providers as data, one registry entry.
# ---------------------------------------------------------------------------

class TestProviderRegistry(unittest.TestCase):
    """ORC-PROV-1: onboarding a model costs ONE registry entry; the registry
    (policy appetite row + model-registry.md + the dispatch MODELS map) is
    unified and read by dispatch and subagent.  Today the tables are split
    across subagent's own maps and main.zig's Zig arrays.
    """

    # CHARACTERIZATION — the one registry table is already read somewhere.
    def test_model_registry_is_read_today(self):
        """TODAY: bin/subagent reads docs/infra/model-registry.md for the
        resident-model RAM figure; watch-fleet's mdl() reads the same table.
        The registry exists as data; the split maps are the refactor's target.
        """
        self.assertIn("model-registry.md", src("bin/subagent"))
        self.assertIn("model-registry.md", src(WATCH))

    @unittest.expectedFailure  # RED — owner: ORC-PLAN-3 step 6 (provider seam)
    def test_dispatch_reads_the_one_registry(self):
        """SHOULD (ORC-PROV-1): a provider change is a data edit in one file,
        never a code change in three scripts — dispatch and subagent read the
        unified registry.  RED: bin/dispatch carries no registry read.
        """
        self.assertIn("model-registry.md", src("bin/dispatch"),
                      "dispatch does not read the one registry")


# ---------------------------------------------------------------------------
# T822 — ORC-GATE-1 — the gate diet: a taste-gate is a warning, not a refusal.
# ---------------------------------------------------------------------------

class TestGateDiet(unittest.TestCase):
    """ORC-GATE-1: a gate that exists to enforce a taste is a warning.  The
    40-char title gate is the canonical taste-gate — a refusal at dispatch
    today (T505).
    """

    # CHARACTERIZATION — the taste-gate exists today as a refusal.
    def test_title_gate_is_a_refusal_at_dispatch_today(self):
        """TODAY (ORC-GATE-1): bin/dispatch's title-length gate (T505) refuses
        a brief whose title exceeds 40 chars.  Pinned so the demotion to a
        warning is a measurable change, not a silent deletion.
        """
        self.assertIn("title-length gate", src("bin/dispatch"))
        self.assertIn("under 40 chars", src("bin/dispatch"))

    @unittest.expectedFailure  # RED — owner: ORC-PLAN-3 step 5 (dispatch rewire)
    def test_taste_gates_are_warnings_not_refusals(self):
        """SHOULD (ORC-GATE-1): a display preference (the 40-char title) is a
        warning; it does not block a dispatch.  RED: the T505 refusal still
        blocks.
        """
        self.assertNotIn("refuses dispatch, naming", src("bin/dispatch"),
                         "the title-length gate still refuses — it must warn")


# ---------------------------------------------------------------------------
# T822 — ORC-ORIENT-1 — the startup-prose diet: the ≤150-line preamble is the
# only boilerplate, injected at dispatch.
# ---------------------------------------------------------------------------

class TestOrientDiet(unittest.TestCase):
    """ORC-ORIENT-1.  The cap is enforced and behaviorally controlled today
    (T353, regression-orient.sh); the injection at dispatch is the unbuilt
    half.
    """

    # CHARACTERIZATION — the ≤150-line cap is enforced (T353).
    def test_orient_preamble_cap_is_enforced(self):
        """TODAY (ORC-ORIENT-1, half): main.zig's orient composes the ≤150-line
        preamble and warns over the cap; regression-orient.sh (T353) is the
        cross-tier behavioral control (null + seeded + degradation).  The cap
        is credited here, not re-implemented.
        """
        zig = src(MAIN_ZIG)
        self.assertIn("150-line cap", zig)
        self.assertIn("=== managent orient — generated worker preamble", zig)

    @unittest.expectedFailure  # RED — owner: ORC-PLAN-3 step 5 (dispatch rewire)
    def test_orient_is_injected_at_dispatch(self):
        """SHOULD (ORC-ORIENT-1): the preamble is injected at dispatch; briefs
        carry task-specific content only.  RED: bin/dispatch invokes no orient
        composition.
        """
        self.assertIn("orient", src("bin/dispatch"),
                      "dispatch does not inject the orient preamble")


# ---------------------------------------------------------------------------
# T822 — rev 2 amendment row 3 (R11): the retired meter, mechanically held.
# ---------------------------------------------------------------------------

class TestRetiredMeter(unittest.TestCase):
    """Rev 2's amendment row 3 retired the window-budget meter (T766).  The
    row had no arm (R11) and the retirement was incompletely applied (R6 —
    the pane's section-name list kept 'window budget').  The meter's absence
    from the live code is the mechanical arm; regression-window-resilience.sh
    is the behavioral red-arm that the budget gate stays dead.
    """

    def test_window_budget_knobs_are_gone_from_the_code(self):
        """TODAY: no tracked source reads WEIZIGO_WINDOW_BUDGET_* — the
        meter's knobs exist only as a regression fixture proving a budget gate
        does not resurrect.  An arm row whose subject is a deletion is held by
        the deletion's absence.
        """
        for target in (WINDOW_POLICY, "bin/dispatch", "bin/subagent", KEEPER):
            self.assertNotIn("WEIZIGO_WINDOW_BUDGET", src(target),
                             "a window-budget knob has returned in %s" % target)


if __name__ == "__main__":
    unittest.main(verbosity=2)
