#!/usr/bin/env python3
"""The single Python reader of managent's model canonicalizer (T801).

Before T801 the serving-tag -> canonical-label transform
(strip `:cloud`, `kimi-k2.7-code` -> `kimi-k2.7`,
`stealth/ox-alpha` -> `ox-alpha`) was reimplemented in three Python tools and
drifted (token-capture lacked the stealth mapping; the runner did not
canonicalize at all — three ledger rows and every run record carried the
`stealth/ox-alpha` serving tag).  The transform now lives in ONE place —
`src/managent/main.zig` `canonicalizeModelTag` — and this module RESOLVES it
via `managent models --tags --json`, cached in-process so a hot loop does not
fork per call.

The boundary is STRICT: `canon_tag` rejects an unrecognized non-empty tag
(raises `UnknownModelTag`) instead of returning it unchanged — pass-through
is exactly how a serving tag reached the ledger (T801 acceptance item 4).
None / '' / whitespace resolve to '' (no model), which is a different thing
from an unknown label.

The three readers all call this module:
    tools/token-capture.py   (ledger + session-scan attribution)
    tools/model-profiles.py  (wall-kill log census attribution)
    tools/runner             (_model_from_argv -> run record `model`)

Stdlib only.  Task: T801 · Role: worker · Model: deepseek-v4-pro ·
Date: 2026-08-23.
"""
import json
import os
import subprocess


class UnknownModelTag(ValueError):
    """An unrecognized non-empty model tag reached the canonicalizer boundary."""


# The repo that CONTAINS this module (tools/..).  This is the authoritative
# source tree for the canonicalizer — `src/managent/main.zig` lives here — so
# `bin/managent`/`zig-out/bin/managent` is resolved from HERE, never from a
# git rev-parse of the CWD (a scratch fixture repo has its own .git but no
# managent binary; resolving from the module root is what keeps the readers
# correct from any directory).
_MODULE_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# T801 test seam: WEIZIGO_CANONICALIZER_JSON points at a fixture file with
# {canonical_models, strip_suffix, serving_tags}.  When set, every reader
# resolves the canonicalizer from that file instead of forking managent — the
# regression fixtures stay hermetic (no managent build, no fork).  The runner
# has no CLI flag for this, so the env var is the uniform seam; the two CLI
# tools additionally expose --canonicalizer-json.
_CANON_ENV = "WEIZIGO_CANONICALIZER_JSON"


def _managent_bin(root):
    for base in (root, _MODULE_ROOT):
        if base:
            for cand in (os.path.join(base, "bin", "managent"),
                         os.path.join(base, "zig-out", "bin", "managent")):
                if os.path.isfile(cand) and os.access(cand, os.X_OK):
                    return cand
    for cand in ("bin/managent", "zig-out/bin/managent"):
        if os.path.isfile(cand) and os.access(cand, os.X_OK):
            return cand
    return None


_CACHE = {}


def normalize_rules(data):
    """Normalize a canonicalizer JSON dict (from `models --tags --json` or a
    fixture file injected via --canonicalizer-json) into the internal rules
    shape.  Raises UnknownModelTag on a bad shape."""
    if not isinstance(data, dict):
        raise UnknownModelTag("canonicalizer must be a JSON object")
    models = data.get("canonical_models")
    serving = data.get("serving_tags") or {}
    if not isinstance(models, list) or not isinstance(serving, dict):
        raise UnknownModelTag(
            "canonicalizer: canonical_models must be a list and serving_tags a dict")
    return {
        "canonical_models": frozenset(models),
        "canonical_list": list(models),
        "strip_suffix": data.get("strip_suffix") or "",
        "serving_tags": dict(serving),
    }


def load_canonicalizer(root=None):
    """Fetch the canonicalizer rules from the single source.

    Resolution order:
      1. WEIZIGO_CANONICALIZER_JSON env var (fixture seam — a file with
         {canonical_models, strip_suffix, serving_tags});
      2. `managent models --tags --json`, resolved from the module's own repo
         root (the authoritative source tree) or the caller's `root`.

    Returns a rules dict:
        {"canonical_models": frozenset, "canonical_list": list,
         "strip_suffix": str, "serving_tags": {serving: canonical}}
    Cached.  Raises UnknownModelTag when the source is missing or its output
    does not parse — a reader must fail loudly, never guess.
    """
    env = os.environ.get(_CANON_ENV)
    if env:
        key = "env:" + env
        if key in _CACHE:
            return _CACHE[key]
        try:
            with open(env) as f:
                data = json.load(f)
        except (OSError, ValueError) as exc:
            raise UnknownModelTag(
                "%s=%r unreadable: %s" % (_CANON_ENV, env, exc))
        rules = normalize_rules(data)
        _CACHE[key] = rules
        return rules

    root = root or _MODULE_ROOT
    key = root or "<none>"
    if key in _CACHE:
        return _CACHE[key]
    binpath = _managent_bin(root)
    if binpath is None:
        raise UnknownModelTag(
            "no managent binary found (root=%r, module_root=%r) — cannot "
            "resolve the canonicalizer; build with `zig build` then "
            "`tools/deploy.sh`" % (root, _MODULE_ROOT))
    try:
        out = subprocess.run(
            [binpath, "models", "--tags", "--json"],
            capture_output=True, text=True, timeout=10.0,
        )
    except (FileNotFoundError, subprocess.TimeoutExpired, OSError) as exc:
        raise UnknownModelTag("managent models --tags failed: %s" % (exc,))
    if out.returncode != 0:
        raise UnknownModelTag(
            "managent models --tags exit %d: %s"
            % (out.returncode, (out.stderr or out.stdout or "").strip()))
    try:
        data = json.loads(out.stdout)
    except ValueError as exc:
        raise UnknownModelTag(
            "managent models --tags emitted invalid JSON: %s" % (exc,))
    rules = normalize_rules(data)
    _CACHE[key] = rules
    return rules


def canonical_models(root=None):
    """The canonical label list, from the single source (a copy)."""
    return list(load_canonicalizer(root)["canonical_list"])


def serving_tag_map(root=None):
    """The serving-tag -> canonical map, from the single source (a copy)."""
    return dict(load_canonicalizer(root)["serving_tags"])


def apply_rules(tag, rules):
    """The pure transform + strict boundary, given already-loaded rules.

    None/''/whitespace -> '' (no model).  A non-empty tag that is not a
    canonical label after the strip + serving-tag map raises UnknownModelTag
    — never passed through unchanged (T801).  This is the seam the reader
    unit tests inject a fixture through, so they stay hermetic (no fork).
    """
    t = (tag or "").strip()
    if not t:
        return ""
    s = t
    sfx = rules.get("strip_suffix") or ""
    if sfx and s.endswith(sfx):
        s = s[:len(s) - len(sfx)]
    s = (rules.get("serving_tags") or {}).get(s, s)
    if s not in (rules.get("canonical_models") or ()):
        raise UnknownModelTag(
            "unrecognized model tag %r (after strip/map: %r); canonical labels: %s"
            % (tag, s, ", ".join(sorted(rules.get("canonical_list") or []))))
    return s


def canon_tag(tag, root=None):
    """Canonicalize a model tag at the boundary (STRICT).

    Resolves the rules from the single source (managent) and applies them;
    rejects an unrecognized non-empty tag with UnknownModelTag."""
    return apply_rules(tag, load_canonicalizer(root))
