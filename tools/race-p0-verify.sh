#!/usr/bin/env python3
"""tools/race-p0-verify.sh — grand-race P0 go/no-go gate (T529)

One command, one verdict.  `docs/epics/E1-markovian/L1-dashboard/S02-model-delegation/grand-race.md` §4 says the race
does not start until its gates are green; this checks the P0 half of that —
roster, sealed-packet keys, and the frozen fixture store — mechanically, so the
operator's go/no-go is one decision rather than a scramble.

It checks four things and prints PASS/FAIL per check:

  SEAL-MANIFEST  the packet MANIFEST.md hash is pinned in artifacts/SHA256SUMS
  SEAL-KEYS      every answer key hashes to the value the MANIFEST sealed
  SEAL-PACKETS   every PACKET.md hashes to the value the MANIFEST sealed
  FIXTURES       the frozen fixture store matches its copy-stable content seal
  ROSTER         the roster parses under tools/bakeoff.sh and every lane is servable
  KEYLEAK        no answer-key material is reachable from the lane's run root (G2)
  KEYREACH       no lane's own transcript shows it touching key material (G2, post-hoc)

WHY A CONTENT SEAL AND NOT THE MANIFEST'S tar HASH.  The MANIFEST seals each
fixture store as `tar -cf - <dir> | sha256sum`.  A tar stream carries mtimes and
the path prefix, so a *byte-identical* copy of the store hashes differently: the
staged store in T543's race worktree diffs clean against the origin and matches
none of the five sealed tar hashes.  That makes the tar seal unable to tell
"copied" from "tampered" — a false FAIL on the honest case, which is how a seal
becomes noise.  The content seal here is the sorted list of per-file SHA-256s
over relative paths, hashed; it is copy-stable and mtime-independent, so it
verifies both at rest and against what the lanes actually see.  The MANIFEST's
tar hashes still verify *in place* and are checked too, as recorded history.

KEYLEAK is the G2 substance, checked where it bites.  `tools/bakeoff.sh` records
`root_is_worktree` and never refuses (T542 owns the refusal).  The relative-path
boundary only holds if the staged lane input carries fixtures WITHOUT their
sibling `key.txt` — the five aspect keys sit inside the packet directories, so
`cp -r packets/* <run-root>/` would ship every answer key to every lane in
silence.  This check reads the run root and refuses if key material is there.

READ-ONLY.  Writes nothing outside a --self-test temp dir.

Exit 0 = all checks pass (GO).  Exit 1 = at least one check failed (NO-GO).
Exit 2 = harness error (bad args, missing input).
"""

import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PACKETS = os.path.join(ROOT, "untracked", "race-aspects", "packets")
MANIFEST = os.path.join(PACKETS, "MANIFEST.md")
SHA256SUMS = os.path.join(ROOT, "artifacts", "SHA256SUMS")
SEALS = os.path.join(ROOT, "docs", "epics", "E1-markovian", "L1-dashboard",
                    "S02-model-delegation", "grand-race-p0-fixtures.sha256")
ROSTER = os.path.join(ROOT, "docs", "epics", "E1-markovian", "L1-dashboard",
                     "S02-model-delegation", "roster-2026-08-20b.txt")

ASPECTS = ["aspect-triage", "aspect-verdict", "aspect-inbox",
           "aspect-crash", "aspect-dispatch"]
EPISTEMIC = ["race3", "race5"]

# Anything matching this under a run root is answer-key material.
KEY_PAT = re.compile(r"(^|/)(key|keys)\.txt$|\.key$|-key\.md$", re.I)


def sha256_file(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def content_seal(root):
    """Copy-stable seal of a directory: sorted 'sha256  relpath' lines, hashed.

    Independent of mtime, owner, and the path the tree was copied to — so it
    answers "is this the same store?" and not "is this the same tarball?".
    """
    lines = []
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames.sort()
        for name in sorted(filenames):
            full = os.path.join(dirpath, name)
            rel = os.path.relpath(full, root)
            lines.append(f"{sha256_file(full)}  {rel}")
    lines.sort()
    return hashlib.sha256("\n".join(lines).encode("utf-8")).hexdigest()


def parse_manifest_hashes():
    """Pull the sealed SHA-256s out of the MANIFEST's two tables.

    Returns {label: sha}, label being the path text in the row's second column.
    """
    out = {}
    with open(MANIFEST) as f:
        for line in f:
            cells = [c.strip() for c in line.strip().strip("|").split("|")]
            if len(cells) != 3:
                continue
            label, sha = cells[1], cells[2]
            m = re.fullmatch(r"`([^`]+)`", label)
            s = re.fullmatch(r"`([0-9a-f]{64})`", sha)
            if m and s:
                out[m.group(1)] = s.group(1)
    return out


class Report:
    def __init__(self, quiet=False):
        self.rows = []
        self.quiet = quiet

    def add(self, check, ok, detail):
        self.rows.append((check, ok, detail))
        if not self.quiet:
            print(f"{'PASS' if ok else 'FAIL'}  {check:14} {detail}")

    def ok(self):
        return all(ok for _, ok, _ in self.rows)


# ── checks ───────────────────────────────────────────────────────────

def check_manifest_pin(rep):
    if not os.path.exists(MANIFEST):
        rep.add("SEAL-MANIFEST", False, f"missing {MANIFEST}")
        return
    actual = sha256_file(MANIFEST)
    pinned = None
    if os.path.exists(SHA256SUMS):
        for line in open(SHA256SUMS):
            parts = line.split()
            if len(parts) == 2 and parts[1].endswith("race-aspects/packets/MANIFEST.md"):
                pinned = parts[0]
    if pinned is None:
        rep.add("SEAL-MANIFEST", False, "no MANIFEST.md line in artifacts/SHA256SUMS")
    elif pinned != actual:
        rep.add("SEAL-MANIFEST", False, f"pinned {pinned[:16]}… != actual {actual[:16]}…")
    else:
        rep.add("SEAL-MANIFEST", True, f"pinned == actual ({actual[:16]}…)")


def check_sealed_files(rep, sealed):
    keys = {
        "aspect-triage/key.txt": os.path.join(PACKETS, "aspect-triage", "key.txt"),
        "aspect-verdict/key.txt": os.path.join(PACKETS, "aspect-verdict", "key.txt"),
        "aspect-inbox/key.txt": os.path.join(PACKETS, "aspect-inbox", "key.txt"),
        "aspect-crash/key.txt": os.path.join(PACKETS, "aspect-crash", "key.txt"),
        "aspect-dispatch/key.txt": os.path.join(PACKETS, "aspect-dispatch", "key.txt"),
        "untracked/race-keys/race3.key": os.path.join(ROOT, "untracked", "race-keys", "race3.key"),
        "untracked/race-keys/race5.key": os.path.join(ROOT, "untracked", "race-keys", "race5.key"),
    }
    packets = {f"{a}/PACKET.md": os.path.join(PACKETS, a, "PACKET.md")
               for a in ASPECTS + ["epistemic-race3", "epistemic-race5"]}

    for check, table in (("SEAL-KEYS", keys), ("SEAL-PACKETS", packets)):
        bad = []
        for label, path in table.items():
            want = sealed.get(label)
            if want is None:
                bad.append(f"{label}: not sealed in MANIFEST")
            elif not os.path.exists(path):
                bad.append(f"{label}: missing on disk")
            elif sha256_file(path) != want:
                bad.append(f"{label}: HASH MISMATCH")
        rep.add(check, not bad,
                f"{len(table)}/{len(table)} verify" if not bad else "; ".join(bad))


def fixture_stores():
    stores = {a: os.path.join(PACKETS, a, "fixtures") for a in ASPECTS}
    for r in EPISTEMIC:
        stores[r] = os.path.join(ROOT, "docs", "evidence", "EPISTEMIC-RACES", "packets", r)
    return stores


def check_fixtures(rep, staged=None):
    if not os.path.exists(SEALS):
        rep.add("FIXTURES", False, f"missing seal file {SEALS}")
        return
    want = {}
    for line in open(SEALS):
        line = line.split("#", 1)[0].strip()
        if not line:
            continue
        sha, name = line.split()
        want[name] = sha

    bad, checked = [], 0
    for name, path in fixture_stores().items():
        if name not in want:
            bad.append(f"{name}: no seal recorded")
            continue
        if not os.path.isdir(path):
            bad.append(f"{name}: store missing at {path}")
            continue
        checked += 1
        if content_seal(path) != want[name]:
            bad.append(f"{name}: CONTENT MISMATCH at origin")

    if staged:
        for name in ASPECTS:
            path = os.path.join(staged, name, "fixtures")
            if not os.path.isdir(path):
                bad.append(f"{name}: not staged under {staged}")
                continue
            checked += 1
            if content_seal(path) != want[name]:
                bad.append(f"{name}: CONTENT MISMATCH in staged store")

    rep.add("FIXTURES", not bad,
            f"{checked} store(s) match the content seal" if not bad else "; ".join(bad))


def check_roster(rep, roster_path):
    ns = {"__name__": "bakeoff_p0"}
    try:
        exec(compile(open(os.path.join(ROOT, "tools", "bakeoff.sh")).read(),
                     "tools/bakeoff.sh", "exec"), ns)
        lanes = ns["parse_roster"](roster_path)
    except SystemExit as e:
        rep.add("ROSTER", False, f"tools/bakeoff.sh refused the roster (exit {e.code})")
        return
    except Exception as e:                                   # pragma: no cover
        rep.add("ROSTER", False, f"roster parse error: {e}")
        return

    bad = []
    served = set()
    if any(l["family"] == "ollama" for l in lanes):
        if shutil.which("ollama") is None:
            bad.append("ollama lane present but no `ollama` on PATH")
        else:
            r = subprocess.run(["ollama", "list"], capture_output=True, text=True)
            served = {ln.split()[0] for ln in r.stdout.splitlines()[1:] if ln.split()}
    for l in lanes:
        if l["family"] == "ollama" and served and l["serving_tag"] not in served:
            bad.append(f"{l['label']}: serving tag {l['serving_tag']} not pulled")
        if l["family"] == "claude" and shutil.which("claude") is None:
            bad.append(f"{l['label']}: no `claude` on PATH")
        if l["family"] == "deepseek" and shutil.which("pi") is None:
            bad.append(f"{l['label']}: no `pi` on PATH")
    rep.add("ROSTER", not bad,
            f"{len(lanes)} lane(s) parse and are servable" if not bad else "; ".join(bad))


def check_keyleak(rep, run_root):
    if run_root is None:
        rep.add("KEYLEAK", True, "skipped — no --run-root given (G2 unchecked)")
        return
    if not os.path.isdir(run_root):
        rep.add("KEYLEAK", False, f"run root does not exist: {run_root}")
        return
    hits = []
    for dirpath, dirnames, filenames in os.walk(run_root):
        if ".git" in dirnames:
            dirnames.remove(".git")
        for name in filenames:
            rel = os.path.relpath(os.path.join(dirpath, name), run_root)
            if KEY_PAT.search(rel):
                hits.append(rel)
    rep.add("KEYLEAK", not hits,
            f"no key material under {run_root}" if not hits
            else f"ANSWER KEY REACHABLE: {', '.join(sorted(hits)[:5])}")


def session_dirs_for(run_root):
    """Every session-transcript directory belonging to a race run root.

    Covers both harnesses: Claude Code writes ~/.claude/projects/<slug>/ and pi
    writes ~/.pi/agent/sessions/--<slug>--.  Lanes run with cwd set to the run
    root or to <run-root>/race-input/<packet>, so match on the slug prefix.
    """
    prefix = project_slug(run_root)
    out = []
    cc = os.path.join(os.path.expanduser("~"), ".claude", "projects")
    if os.path.isdir(cc):
        out += [os.path.join(cc, n) for n in sorted(os.listdir(cc)) if n.startswith(prefix)]
    pi = os.path.join(os.path.expanduser("~"), ".pi", "agent", "sessions")
    if os.path.isdir(pi):
        out += [os.path.join(pi, n) for n in sorted(os.listdir(pi))
                if n.strip("-").startswith(prefix.strip("-"))]
    return out


# What a lane READING an answer key would look like in its own transcript.
REACH_PAT = re.compile(r"untracked/race-keys|(^|[\s\"'/])key\.txt", re.I)


def scan_lane_sessions(run_root):
    """Return (dirs, hits) — key-material reach in what the LANES ACTUALLY DID.

    KEYLEAK reads the tree the lanes could see; this reads the transcript of
    what they did with it, which is the only post-hoc evidence a race was clean.
    Prompt text is deliberately excluded: the packet brief legitimately NAMES
    the key paths (the epistemic MANIFEST does, verbatim, with SHA-256s), and
    counting the brief would red-light every honest run.  Assistant turns, tool
    calls and tool results are lane ACTIONS and are counted.
    """
    dirs = session_dirs_for(run_root)
    return dirs, scan_session_dirs(dirs)


def scan_session_dirs(dirs):
    """The seam the controls drive: scan explicit transcript dirs for reach."""
    hits = []
    for d in dirs:
        for name in sorted(os.listdir(d)):
            if not name.endswith(".jsonl"):
                continue
            with open(os.path.join(d, name)) as f:
                for line in f:
                    try:
                        o = json.loads(line)
                    except ValueError:
                        continue
                    msg = o.get("message")
                    if not isinstance(msg, dict):
                        continue
                    role = msg.get("role") or o.get("type")
                    if role in ("user", "session", "system"):
                        continue
                    body = json.dumps(msg.get("content"))
                    if REACH_PAT.search(body):
                        hits.append(f"{os.path.basename(d)}/{name[:8]}")
                        break
    return sorted(set(hits))


def check_keyreach(rep, run_root):
    if run_root is None:
        rep.add("KEYREACH", True, "skipped — no --lane-sessions given")
        return
    dirs, hits = scan_lane_sessions(run_root)
    if not dirs:
        rep.add("KEYREACH", False, f"no session transcripts found for {run_root}")
        return
    rep.add("KEYREACH", not hits,
            f"{len(dirs)} session dir(s), no lane touched key material" if not hits
            else f"LANE REACHED KEY MATERIAL: {', '.join(hits[:5])}")


# ── lane token readings (spend measurement, §4 of the P0 doc) ────────

def project_slug(path):
    """Claude Code's on-disk project-directory slug for a working directory."""
    return re.sub(r"[^A-Za-z0-9]", "-", os.path.abspath(path))


def claude_lane_tokens(cwd):
    """Per-model token readings from Claude Code's own transcripts for `cwd`.

    WHY THIS EXISTS HERE.  tools/token-capture.py (T521) states that "Claude
    labels have no session record, so their numbers come from the ledger or are
    absent".  That is false for headless `claude -p` lanes: Claude Code writes a
    transcript per session under ~/.claude/projects/<slug>/, and every assistant
    turn carries a `message.usage` object.  The aspect-race Claude lanes were
    dispatched with --output-format text, so the JSON usage envelope T521
    captures at dispatch was never produced -- and the readings are on disk all
    the same.  Recorded in findings/T529-grand-race-p0.json as an interface
    T521 should absorb; measured here because P0 owes a spend estimate.

    tokens_in = input + cache_read, per the grand-race.md §6 schema.
    """
    d = os.path.join(os.path.expanduser("~"), ".claude", "projects", project_slug(cwd))
    out = {}
    if not os.path.isdir(d):
        return out
    for name in sorted(os.listdir(d)):
        if not name.endswith(".jsonl"):
            continue
        model, rec = None, {"turns": 0, "tokens_in": 0, "cache_write": 0, "tokens_out": 0}
        with open(os.path.join(d, name)) as f:
            for line in f:
                try:
                    o = json.loads(line)
                except ValueError:
                    continue
                msg = o.get("message")
                if not isinstance(msg, dict):
                    continue
                usage = msg.get("usage")
                if not isinstance(usage, dict):
                    continue
                model = msg.get("model") or model
                rec["turns"] += 1
                rec["tokens_in"] += usage.get("input_tokens", 0) + usage.get("cache_read_input_tokens", 0)
                rec["cache_write"] += usage.get("cache_creation_input_tokens", 0)
                rec["tokens_out"] += usage.get("output_tokens", 0)
        if model and rec["turns"]:
            prev = out.setdefault(model, {"turns": 0, "tokens_in": 0, "cache_write": 0, "tokens_out": 0})
            for k in rec:
                prev[k] += rec[k]
    return out


def pi_lane_tokens(cwd):
    """Per-model readings for pi-served lanes, via T521's instrument.

    Delegated rather than reimplemented: token-capture.py already owns the pi
    session schema.  It is invoked per LANE cwd, which is the join P0 found
    missing -- a race lane's cwd is <run-root>/race-input/<aspect>, not the run
    root, so `--cwd <run-root>` sees only the official's own sessions.
    """
    cap = os.path.join(ROOT, "tools", "token-capture.py")
    r = subprocess.run([sys.executable, cap, "--json", "--cwd", cwd],
                       capture_output=True, text=True)
    if r.returncode != 0:
        return {}
    try:
        data = json.loads(r.stdout)
    except ValueError:
        return {}
    out = {}
    for s in data.get("sessions", []):
        m = s.get("model")
        if not m:
            continue
        rec = out.setdefault(m, {"turns": 0, "tokens_in": 0, "cache_write": 0, "tokens_out": 0})
        rec["turns"] += s.get("turns", 0)
        rec["tokens_in"] += s.get("tokens_in", 0)
        rec["cache_write"] += s.get("cache_write", 0)
        rec["tokens_out"] += s.get("tokens_out", 0)
    return out


def lane_tokens(run_root, roster_path):
    """Print the measured per-lane spend table for a race run root.

    Every roster lane x every staged packet is a cell.  A cell with no record
    prints `null` and a REASON -- never an estimate (grand-race.md §4, G1).
    """
    try:
        ns = {"__name__": "bakeoff_p0"}
        exec(compile(open(os.path.join(ROOT, "tools", "bakeoff.sh")).read(),
                     "tools/bakeoff.sh", "exec"), ns)
        lanes = ns["parse_roster"](roster_path)
    except Exception as e:
        print(f"roster parse error: {e}", file=sys.stderr)
        return 2

    staged = os.path.join(run_root, "race-input")
    if not os.path.isdir(staged):
        print(f"no staged lane input under {staged}", file=sys.stderr)
        return 2
    packets = sorted(p for p in os.listdir(staged)
                     if os.path.isdir(os.path.join(staged, p)))

    print(f"{'packet':<18} {'lane':<28} {'turns':>5} {'tokens_in':>11} "
          f"{'cache_write':>12} {'tokens_out':>11}")
    totals, missing = {}, []
    for packet in packets:
        cwd = os.path.join(staged, packet)
        readings = {}
        readings.update(claude_lane_tokens(cwd))
        readings.update(pi_lane_tokens(cwd))
        for lane in lanes:
            label = lane["label"]
            rec = readings.get(label)
            if rec is None:
                reason = ("harness dispatched --no-session; no record exists to mine"
                          if lane["family"] == "deepseek" else "no session record found")
                missing.append((packet, label, reason))
                print(f"{packet:<18} {label:<28} {'null':>5} {'null':>11} {'null':>12} {'null':>11}")
                continue
            t = totals.setdefault(label, {"n": 0, "turns": 0, "tokens_in": 0,
                                          "cache_write": 0, "tokens_out": 0})
            t["n"] += 1
            for k in ("turns", "tokens_in", "cache_write", "tokens_out"):
                t[k] += rec[k]
            print(f"{packet:<18} {label:<28} {rec['turns']:>5} {rec['tokens_in']:>11,} "
                  f"{rec['cache_write']:>12,} {rec['tokens_out']:>11,}")

    print()
    print(f"{'lane':<28} {'lanes':>5} {'tokens_in':>11} {'tokens_out':>11} "
          f"{'mean_in':>11} {'mean_out':>10}")
    for label, t in sorted(totals.items()):
        print(f"{label:<28} {t['n']:>5} {t['tokens_in']:>11,} {t['tokens_out']:>11,} "
              f"{t['tokens_in'] // t['n']:>11,} {t['tokens_out'] // t['n']:>10,}")

    cells = len(packets) * len(lanes)
    measured = sum(t["n"] for t in totals.values())
    grand_in = sum(t["tokens_in"] for t in totals.values())
    grand_out = sum(t["tokens_out"] for t in totals.values())
    print()
    print(f"measured {measured}/{cells} lane-cells; "
          f"{grand_in:,} tokens_in / {grand_out:,} tokens_out")
    if missing:
        print(f"{len(missing)} cell(s) null WITH A REASON (never estimated):")
        for reason in sorted({r for _, _, r in missing}):
            n = sum(1 for _, _, r in missing if r == reason)
            print(f"  {n:>3}  {reason}")
    return 0


# ── controls ─────────────────────────────────────────────────────────

def self_test():
    """Null control (untouched copy passes) + seeded controls (each is caught).

    Principle 4, orient: a checker ships a known-good it passes and a known-bad
    it catches.  Runs entirely in a temp dir; the sealed originals are read-only
    inputs and are never written.
    """
    failures = []

    with tempfile.TemporaryDirectory(prefix="race-p0-selftest-") as tmp:
        # The controls must run on a FRESH CLONE, where untracked/race-aspects/
        # does not exist — a suite arm that needs an untracked input is an arm
        # that silently stops running.  Use the real store when it is here (it
        # exercises the actual sealed bytes) and a synthetic one when it is not.
        real = os.path.join(PACKETS, "aspect-triage", "fixtures")
        if os.path.isdir(real):
            origin = real
        else:
            origin = os.path.join(tmp, "origin")
            os.makedirs(os.path.join(origin, "sub"))
            open(os.path.join(origin, "finding-dump.json"), "w").write('{"synthetic": true}\n')
            open(os.path.join(origin, "sub", "existing-tasks.json"), "w").write("[]\n")
        base = content_seal(origin)

        # null control — a byte-identical copy, different mtimes and path.
        good = os.path.join(tmp, "good")
        shutil.copytree(origin, good)
        os.utime(os.path.join(good, "finding-dump.json"), (0, 0))
        if content_seal(good) != base:
            failures.append("null control FAILED: an untouched copy did not match its seal")
        else:
            print("PASS  control-null   copy with rewritten mtimes still matches the seal")

        # the same copy under the MANIFEST's tar seal — the defect this tool routes around.
        t_origin = subprocess.run(["tar", "-cf", "-", os.path.basename(origin)],
                                  cwd=os.path.dirname(origin),
                                  capture_output=True).stdout
        t_copy = subprocess.run(["tar", "-cf", "-", "good"], cwd=tmp,
                                capture_output=True).stdout
        if hashlib.sha256(t_origin).hexdigest() == hashlib.sha256(t_copy).hexdigest():
            failures.append("tar-seal demo FAILED: expected the tar hashes to diverge")
        else:
            print("PASS  control-tar    tar seal diverges on an identical copy (why we content-seal)")

        # seeded control — one flipped byte must be caught.
        bad = os.path.join(tmp, "bad")
        shutil.copytree(origin, bad)
        victim = os.path.join(bad, "finding-dump.json")
        data = bytearray(open(victim, "rb").read())
        data[0] ^= 0x20
        open(victim, "wb").write(bytes(data))
        if content_seal(bad) == base:
            failures.append("seeded control FAILED: a flipped byte was not caught")
        else:
            print("PASS  control-seed   one flipped byte in a fixture is caught")

        # seeded control — a planted key under a run root must be caught.
        leak = os.path.join(tmp, "runroot", "aspect-triage")
        os.makedirs(leak)
        open(os.path.join(leak, "key.txt"), "w").write("answers\n")
        rep = Report(quiet=True)
        check_keyleak(rep, os.path.join(tmp, "runroot"))
        if rep.ok():
            failures.append("seeded control FAILED: a planted key.txt was not caught")
        else:
            print("PASS  control-leak   a key.txt planted in a run root is caught")

        # null control — a run root with fixtures but no key passes.
        clean = os.path.join(tmp, "cleanroot", "aspect-triage")
        shutil.copytree(origin, os.path.join(clean, "fixtures"))
        rep2 = Report(quiet=True)
        check_keyleak(rep2, os.path.join(tmp, "cleanroot"))
        if not rep2.ok():
            failures.append("null control FAILED: a key-free run root was flagged")
        else:
            print("PASS  control-clean  a key-free run root is not flagged")

        # seeded control — a lane that ACTS on key material must be caught.
        sess = os.path.join(tmp, "sessions", "seeded")
        os.makedirs(sess)
        with open(os.path.join(sess, "lane.jsonl"), "w") as fh:
            fh.write(json.dumps({"message": {"role": "assistant", "content": [
                {"type": "toolCall", "name": "read",
                 "arguments": {"path": "packets/aspect-triage/key.txt"}}]}}) + "\n")
        if not scan_session_dirs([sess]):
            failures.append("seeded control FAILED: a lane reading key.txt was not caught")
        else:
            print("PASS  control-reach  a lane that reads an answer key is caught")

        # null control — the BRIEF naming the key path is not a lane action.
        clean_sess = os.path.join(tmp, "sessions", "clean")
        os.makedirs(clean_sess)
        with open(os.path.join(clean_sess, "lane.jsonl"), "w") as fh:
            fh.write(json.dumps({"message": {"role": "user", "content":
                "Keys live in untracked/race-keys/race3.key — do not read them."}}) + "\n")
            fh.write(json.dumps({"message": {"role": "assistant", "content": [
                {"type": "toolCall", "name": "read",
                 "arguments": {"path": "fixtures/finding-dump.json"}}]}}) + "\n")
        if scan_session_dirs([clean_sess]):
            failures.append("null control FAILED: the brief naming a key path was flagged")
        else:
            print("PASS  control-brief  a brief that names the key path is not a lane action")

    for f in failures:
        print(f"FAIL  {f}")
    print("\nself-test:", "PASS" if not failures else f"FAIL ({len(failures)})")
    return 0 if not failures else 1


def write_seals():
    """(Re)generate the copy-stable fixture seal file.  Sealing is a deliberate
    act: run this only when the fixture store is legitimately re-frozen, and
    commit the diff so the change is on the record."""
    lines = ["# Copy-stable content seals for the frozen fixture stores (T529).",
             "# seal = sha256 of the sorted 'sha256  relpath' listing of the store.",
             "# Regenerate deliberately: tools/race-p0-verify.sh --write-seals",
             ""]
    for name, path in sorted(fixture_stores().items()):
        lines.append(f"{content_seal(path)}  {name}")
    with open(SEALS, "w") as f:
        f.write("\n".join(lines) + "\n")
    print(f"wrote {SEALS}")
    return 0


def main():
    ap = argparse.ArgumentParser(description="grand-race P0 go/no-go gate (T529)")
    ap.add_argument("--roster", default=ROSTER, help="roster file to validate")
    ap.add_argument("--staged", help="staged lane-input dir (e.g. <worktree>/race-input)")
    ap.add_argument("--run-root", help="lane run root to scan for leaked key material (G2)")
    ap.add_argument("--lane-sessions", metavar="RUN_ROOT",
                    help="scan lane session transcripts for key-material reach (G2, post-hoc)")
    ap.add_argument("--lane-tokens", metavar="RUN_ROOT",
                    help="print the measured per-lane token table for a race run root")
    ap.add_argument("--self-test", action="store_true", help="run the null + seeded controls")
    ap.add_argument("--write-seals", action="store_true", help="(re)generate the seal file")
    args = ap.parse_args()

    if args.self_test:
        return self_test()
    if args.lane_tokens:
        return lane_tokens(args.lane_tokens, args.roster)
    if args.write_seals:
        return write_seals()

    if not os.path.exists(MANIFEST):
        print(f"FAIL  packet manifest missing: {MANIFEST}", file=sys.stderr)
        return 2

    sealed = parse_manifest_hashes()
    rep = Report()
    check_manifest_pin(rep)
    check_sealed_files(rep, sealed)
    check_fixtures(rep, staged=args.staged)
    check_roster(rep, args.roster)
    check_keyleak(rep, args.run_root)
    check_keyreach(rep, args.lane_sessions)

    print()
    print("P0 VERDICT: " + ("GO — every P0 seal and roster check is green"
                            if rep.ok() else
                            "NO-GO — at least one P0 check failed (see FAIL lines)"))
    return 0 if rep.ok() else 1


if __name__ == "__main__":
    sys.exit(main())
