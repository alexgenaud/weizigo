#!/usr/bin/env python3
"""tools/race-collect.py — mechanical collection + blinding for race-protocol-v2 (T779).

One command, one contract: gather the hermetic lane dirs of a race root, copy
each artifact to a CONTENT-HASH name in the judge's blind set, verify that no
attribution lives inside the artifacts (attribution belongs in the sidecar
manifest only), and refuse to emit a blind set that is not blind.

Rules 2-3 of docs/epics/E1-markovian/L1-dashboard/S02-model-delegation/race-protocol-v2.md:
  R2 hermetic lanes  each lane writes only its own `lane-<id>/` dir, never
                     commits, attribution never inside the artifact;
  R3 mechanical      a script, not a model, gathers outputs under
  blinding           content-hash names.

Usage:
  tools/race-collect.py <race-root> [--artifact <name>] [--blind-dir <dir>]

  <race-root>   directory containing lane-<id>/ subdirectories (hermetic lanes)
  --artifact    artifact filename inside each lane dir (default: out.md)
  --blind-dir   output dir for the judge's blind set (default: <race-root>/blind/)

Compliance checks (a breach = the blind set cannot be trusted):
  SELF-ATTRIBUTION  the artifact contains a model label, a family proper noun,
                    or a first-person family self-claim ("I am Claude",
                    "as a DeepSeek model").  Detection vocabulary is kept in
                    sync with the G4 sanitizer in tools/bakeoff.sh (itself
                    pinned to the canonical_models array in
                    src/managent/main.zig).  Case is deliberate: the
                    first-person pattern is case-insensitive; the bare
                    proper-noun pattern is case-SENSITIVE so lowercase
                    "minimax" (the Go search algorithm) and "glm" are NOT
                    treated as a model family.
  GIT-COMMIT        any lane file is tracked in the git repository that
                    contains the race root, or the lane dir carries a nested
                    .git (a lane that made its own repo).  "Lanes never
                    commit" is R2.
  MISSING-ARTIFACT  a lane dir with no artifact.  Not a blinding breach: the
                    lane produced nothing (a DNF is data), it is excluded from
                    the blind set and noted in the report.

Exit codes:
  0  clean (or only MISSING-ARTIFACT): blind set emitted, manifest sealed.
  1  blinding-relevant breach (SELF-ATTRIBUTION / GIT-COMMIT): compliance
     report written, blind set REFUSED.  A leaked set is worse than none.
  2  harness error (bad args, race root unusable, no lanes, blind dir already
     sealed).

stdout = data, and the data is judge-facing: one content-hash name per blinded
lane, nothing else.  The lane mapping lives ONLY in the sealed sidecar
manifest (<blind-dir>/manifest.json) and the compliance report
(<race-root>/collect-report.json).  The judge's set never carries lane ids.

The manifest is self-sealed (manifest_sha256 over the canonical manifest minus
that field) and a re-collection over an existing manifest refuses (exit 2):
the judge's set is pinned once sealed — re-collect into a fresh --blind-dir
after a lane fix.

Read-only on the live tree: every output lands under the race root (or the
--blind-dir).  No real model is ever invoked.
"""

import argparse
import hashlib
import json
import os
import re
import subprocess
import sys

# ── detection vocabulary (sync with tools/bakeoff.sh G4 / src/managent/main.zig) ──
FAMILY_WORDS = ("Claude", "DeepSeek", "GLM", "Qwen", "Kimi", "Minimax",
                "Ollama", "Anthropic", "OpenAI", "Gemini", "GPT")
CANONICAL = {
    "claude-opus-5", "claude-sonnet-5", "claude-fable-5",
    "claude-haiku-4-5-20251001",
    "deepseek-v4-pro", "deepseek-v4-flash",
    "glm-5.2", "minimax-m3", "kimi-k2.7",
    "qwen3.8:27b-mlx",
}

_SELF_ID_RES = [
    # first-person / attribution constructions: "I am Claude", "as a DeepSeek model", "I'm GLM"
    re.compile(
        r"\b(?:I\s+am|I'?m|as|like)\s+(?:an?\s+)?(?:a\s+)?"
        r"(?:" + "|".join(FAMILY_WORDS) + r")\b", re.I),
    # canonical model labels (unambiguous self-identification)
    re.compile(r"\b(?:" + "|".join(re.escape(l) for l in sorted(CANONICAL)) + r")\b",
               re.I),
    # bare capitalized proper nouns (NOT lowercase minimax/glm — algorithm terms)
    re.compile(r"\b(?:" + "|".join(FAMILY_WORDS) + r")\b"),
]


def die(msg, code=2):
    sys.stderr.write("race-collect: %s\n" % msg)
    sys.exit(code)


def diag(msg):
    sys.stderr.write("[race-collect] %s\n" % msg)


def sha256_file(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def find_self_attribution(text):
    """Return the list of matched snippets, or [] if the artifact is clean."""
    matches = []
    for rx in _SELF_ID_RES:
        for m in rx.finditer(text):
            matches.append(text[m.start():m.end()])
    return matches


def git_tracked(race_root, relpath):
    """Return a list of tracked paths under relpath, or None if race_root is
    not inside a git repository (nothing to detect there)."""
    try:
        out = subprocess.run(["git", "-C", race_root, "ls-files", "--", relpath],
                             capture_output=True, text=True, timeout=15)
    except (OSError, subprocess.TimeoutExpired):
        return None
    if out.returncode != 0:
        return None
    return [l for l in out.stdout.splitlines() if l.strip()]


def main():
    ap = argparse.ArgumentParser(description="race-protocol-v2 mechanical blinding")
    ap.add_argument("race_root", help="directory containing lane-<id>/ subdirs")
    ap.add_argument("--artifact", default="out.md", help="artifact filename per lane (default out.md)")
    ap.add_argument("--blind-dir", default=None, help="judge's blind set dir (default <race-root>/blind)")
    args = ap.parse_args()

    race_root = os.path.abspath(args.race_root)
    if not os.path.isdir(race_root):
        die("race root %s is not a directory" % race_root)
    blind_dir = os.path.abspath(args.blind_dir) if args.blind_dir else os.path.join(race_root, "blind")

    lanes = sorted(d for d in os.listdir(race_root)
                   if d.startswith("lane-") and os.path.isdir(os.path.join(race_root, d)))
    if not lanes:
        die("no lane-<id>/ dirs found under %s" % race_root)

    if os.path.exists(os.path.join(blind_dir, "manifest.json")):
        die("blind dir %s is already sealed (manifest.json exists); re-collect into a fresh --blind-dir" % blind_dir)

    # ── per-lane compliance scan ─────────────────────────────────────────
    entries = []
    breaches = []
    for lane in lanes:
        lane_dir = os.path.join(race_root, lane)
        art_path = os.path.join(lane_dir, args.artifact)
        entry = {"lane": lane, "artifact": args.artifact, "present": False,
                 "sha256": None, "breaches": [], "status": "missing"}
        if not os.path.isfile(art_path):
            entry["breaches"].append("MISSING-ARTIFACT")
            entry["status"] = "missing"
            entries.append(entry)
            diag("%s: no artifact %s (lane produced nothing; excluded from the blind set)" % (lane, args.artifact))
            continue
        entry["present"] = True
        entry["sha256"] = sha256_file(art_path)
        with open(art_path, "rb") as f:
            content = f.read()
        try:
            text = content.decode("utf-8", errors="replace")
        except Exception:
            text = content.decode("utf-8", errors="replace")

        hits = find_self_attribution(text)
        if hits:
            entry["breaches"].append("SELF-ATTRIBUTION")
            entry["self_attribution_matches"] = hits[:8]
            breaches.append((lane, "SELF-ATTRIBUTION", hits[:3]))

        tracked = git_tracked(race_root, lane)
        if tracked:
            entry["breaches"].append("GIT-COMMIT")
            entry["tracked_paths"] = tracked[:8]
            breaches.append((lane, "GIT-COMMIT", tracked[:3]))
        elif tracked is None:
            entry["git_repo"] = "none"
        if os.path.isdir(os.path.join(lane_dir, ".git")):
            entry["breaches"].append("GIT-COMMIT")
            entry["nested_git"] = True
            breaches.append((lane, "GIT-COMMIT", ["<lane>/.git (nested repository)"]))

        entry["status"] = "breach" if entry["breaches"] else "clean"
        entries.append(entry)

    blind_breach = any(b for b in breaches if b[1] in ("SELF-ATTRIBUTION", "GIT-COMMIT"))
    report = {
        "race_root": race_root,
        "blind_dir": blind_dir,
        "generated": "2026-08-23",
        "artifact": args.artifact,
        "lanes": entries,
        "breach_count": len(breaches),
        "blinded_count": 0,
        "blind_set_emitted": False,
        "instrument": "tools/race-collect.py (race-protocol-v2 rules 2-3, T779)",
    }

    if blind_breach:
        for lane, cls, detail in breaches:
            diag("COMPLIANCE BREACH %s — %s: %s" % (lane, cls, "; ".join(detail)))
        diag("blind set REFUSED: a leaked set is worse than none; fix the artifacts and re-collect")
        with open(os.path.join(race_root, "collect-report.json"), "w") as f:
            json.dump(report, f, indent=1, sort_keys=True)
        sys.exit(1)

    # ── emit the blind set under content-hash names ──────────────────────
    os.makedirs(blind_dir, exist_ok=True)
    blind_names = {}   # lane -> blind name
    name_taken = {}    # blind name -> lane
    for entry in entries:
        if not entry["present"]:
            continue
        lane_dir = os.path.join(race_root, entry["lane"])
        art_path = os.path.join(lane_dir, args.artifact)
        h = entry["sha256"]
        name = h[:16] + ".md"
        n = 2
        while name in name_taken:
            name = h[:16] + "-%d.md" % n
            n += 1
        name_taken[name] = entry["lane"]
        blind_names[entry["lane"]] = name
        with open(art_path, "rb") as src, open(os.path.join(blind_dir, name), "wb") as dst:
            dst.write(src.read())

    manifest = {
        "generated": "2026-08-23",
        "race_root": os.path.basename(race_root),
        "artifact": args.artifact,
        "lanes": {blind_names[l]: l for l in blind_names},   # blind name -> lane id
        "artifacts": {l: {"blind_name": blind_names[l], "sha256": e["sha256"]}
                      for l, e in ((x["lane"], x) for x in entries) if e["present"]},
    }
    canonical = json.dumps(manifest, sort_keys=True)
    manifest["manifest_sha256"] = hashlib.sha256(canonical.encode()).hexdigest()
    with open(os.path.join(blind_dir, "manifest.json"), "w") as f:
        json.dump(manifest, f, indent=1, sort_keys=True)

    report["blinded_count"] = len(blind_names)
    report["blind_set_emitted"] = True
    with open(os.path.join(race_root, "collect-report.json"), "w") as f:
        json.dump(report, f, indent=1, sort_keys=True)

    # stdout = data, judge-facing: hash names ONLY, one per line
    for lane in sorted(blind_names):
        print(blind_names[lane])
    diag("%d lane(s) blinded into %s; %d breach(es) recorded (missing-artifact only)" % (
        len(blind_names), blind_dir, len(breaches)))
    sys.exit(0)


if __name__ == "__main__":
    main()
