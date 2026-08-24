#!/usr/bin/env python3
"""tools/fleet_caps.py — the T845 fleet-cap policy: ONE counter, ONE
definition, shared by both doors.

Defect (2026-08-24): tools/fleet-keeper.sh read FLEET_CAP (default 5) and
FLEET_FAMILY_CAP ("family=N", default claude=3,fable=1 — T651 §7c.33) and
refused over them, but bin/dispatch — the door nearly all work actually
launches through — contained ZERO references to either variable.  While the
keeper sat refusing at 1, twelve workers ran (7 ollama + 5 deepseek), all
dispatched explicitly: the "two doors, one gated" defect in its fourth
instance (nonce+meter, close-path, appetite, now caps).

This module is the single home of the cap definition:

  * the family map (canonical model label → appetite/cap family) — fixing
    the keeper's qwen3.8:27b-mlx bug, where `family_of` split the label on
    ":" BEFORE the map lookup, so the map's own "qwen3.8:27b-mlx": "local"
    entry was unreachable and every local lane counted as "other" (uncapped
    AND appetite-SPEND, against the keeper's own local=PROBE intent);
  * the defaults — FLEET_CAP and FLEET_FAMILY_CAP with the per-number
    derivations below (T845 §4: defend each number with evidence, not
    taste; C5 — do not invent a constant);
  * the counters — in_progress total, per-family, and the held-file set —
    computed from a kanban snapshot the same way at both doors;
  * the --override-cap=<reason> ledger (untracked/fleet-cap-overrides.jsonl),
    the recorded escape hatch mirroring window_policy.record_override (T677).

Consumers:
  bin/dispatch          the explicit door (the T845 gate: refuse over the
                        caps, name the cap + count + waiting task; the
                        one-writer holds check; the recorded override);
  tools/fleet-keeper.sh the automated loop (replaces its inline FAMILY map,
                        defaults and counting with these — same numbers,
                        same log lines, one definition).

## The defaults, and why each number (T845 §4)

Operator ruling 2026-08-24: "Maybe limit the total number of agents running
at one time.  Maybe limit the total number of family members running at one
time.  Run more sequentially/serially even if tasks CAN run in parallel
conflict-free."

  FLEET_CAP = 4 (total).  The 2026-08-19 ruling committed 5 as the KEEPER's
  cap; the 2026-08-24 ruling asks for more serial execution, and the
  explicit door now enforces the same number, so the effective fleet is
  bounded by both doors, not the keeper alone.  Derivation: 4 = the claude
  family cap (3) + 1 — the only family with a provider ceiling below 5 is
  claude (provider-429 at only 4 runs in a 5-hour window, 2026-08-24; five
  claude lanes died of the 5-hour session limit on 2026-08-22), so a total
  of 4 means even a full claude race leaves exactly one lane for other
  families — the "more serial" posture — while 3 would starve non-claude
  work whenever a race is running.  Evidence anchors: the 12-worker
  incident (7 ollama + 5 deepseek, all over any cap); DeepSeek's
  uncapped 513 M input tokens in one day — the total is the ONLY bound on
  the uncapped families, and concurrency multiplies cost linearly; ollama's
  recorded five-worker ceiling becomes unreachable-by-accident (a fleet of
  4 can never stack 5 ollama lanes).

  FLEET_FAMILY_CAP = claude=3, fable=1, ollama=5.
    claude=3 — unchanged from T651 §7c.33 ("one race's worth"), REINFORCED
      by the evidence: the 2026-08-24 provider-429 came at only 4 runs in
      a 5-hour window, so 3 is the largest number that has not tripped the
      provider.  The 2026-08-22 five-lane window death would have been
      structurally impossible at 3.
    fable=1 — unchanged from T651 §7c.33 ("Fable alone"); Fable's appetite
      is RESERVED (one lane at a time) and fable lanes share the claude
      provider's session window.
    ollama=5 — NEW default: the provider's own recorded five-worker
      ceiling (the brief cites it).  The cap makes the ceiling explicit at
      both doors; the 2026-08-24 incident ran 7 ollama lanes only because
      the explicit door had no cap.  Capping AT the ceiling changes nothing
      for the keeper (the total already binds first) — the derivation is
      the provider's number, not ours.
    deepseek / local (qwen3.8:27b-mlx) — NO default cap: neither has a
      recorded provider ceiling ("DeepSeek has no recorded ceiling"),
      and inventing a number for them is exactly the C5 constant-invention
      sin this task names.  They are bounded by the total; if a ceiling is
      ever recorded, the env line appears here.

All defaults are env-overridable (FLEET_CAP, FLEET_FAMILY_CAP="family=N,...")
exactly as the keeper's were; a garbage value is a loud refusal at
bin/dispatch and an error per iteration at the keeper (the keeper's
pre-existing behavior for a garbage FLEET_CAP — ValueError — is unchanged).

## The one-writer invariant (T500)

The held-file set is computed here too (inprog_holds): the union of holds
of in_progress rows.  Both doors refuse a dispatch whose holds intersect it
— the keeper always has ("the operator's non-negotiable"); bin/dispatch
now does too (T845 §5: "make the door notice").  --override-cap bypasses
the CAPS only, never this (D022's 'dispatch-anyway after a wait' escape was
REJECTED by the operator on 2026-08-20 and is gone from the keeper; the
explicit door gets no softer doctrine).

Standard library only (Python 3.9+).
"""

import json
import os
import subprocess
import time

# ── family map: canonical model label → appetite/cap family ──────────────
# Mirrors the keeper's pre-T845 FAMILY (T651), with the qwen fix: the full
# label is tried BEFORE the ":"-split prefix, so the map's own
# "qwen3.8:27b-mlx" → "local" entry is reachable (the old keeper split
# first, made the entry unreachable, and counted every local lane as
# "other" — uncapped AND appetite-SPEND, against its own local=PROBE
# intent).  The prefix fallback still canonicalizes a ":cloud"-tagged or
# otherwise-suffixed label to its family.
FAMILY = {
    "claude-opus-5": "claude",
    "claude-sonnet-5": "claude",
    "claude-haiku-4-5-20251001": "claude",
    "claude-fable-5": "fable",
    "deepseek-v4-pro": "deepseek",
    "deepseek-v4-flash": "deepseek",
    "glm-5.2": "ollama",
    "minimax-m3": "ollama",
    "kimi-k2.7": "ollama",
    "qwen3.8:27b-mlx": "local",
}

# ── defaults (derivations in the module docstring — T845 §4) ─────────────
DEFAULT_TOTAL_CAP = 4
DEFAULT_FAMILY_CAP = {"claude": 3, "fable": 1, "ollama": 5}

# Append-only audit log for the bin/dispatch cap override (T845 §3), the
# fleet-window-overrides.jsonl precedent (T677): one JSON line per human
# dispatch past a cap, reason required.
CAP_OVERRIDES_FILE = "fleet-cap-overrides.jsonl"


def family_of(model):
    """→ the cap family of a model label, or 'other'.  Full label first
    (the qwen3.8:27b-mlx fix), then the ':'-split prefix (a ":cloud" or
    other-suffixed label still resolves), then 'other'."""
    m = model or ""
    if m in FAMILY:
        return FAMILY[m]
    return FAMILY.get(m.split(":")[0], "other")


def total_cap():
    """FLEET_CAP → int (default DEFAULT_TOTAL_CAP).  A garbage value raises
    ValueError — a silent fallback is the two-doors-disagree class; both
    doors surface it loudly (bin/dispatch refuses, the keeper logs the
    error each iteration exactly as its old int() did)."""
    v = os.environ.get("FLEET_CAP")
    if v is None or v == "":
        return DEFAULT_TOTAL_CAP
    try:
        n = int(v)
    except ValueError:
        raise ValueError(f"FLEET_CAP must be an integer, got {v!r}")
    if n < 0:
        raise ValueError(f"FLEET_CAP must be >= 0, got {n!r}")
    return n


def family_caps():
    """FLEET_FAMILY_CAP 'family=N,...' over the defaults → {family: str}.
    The env line ADDS/overrides entries; unlisted families keep their
    default or stay uncapped.  Values stay strings here (a family may be
    explicitly uncapped with 'family='); family_cap() ints them."""
    m = dict(DEFAULT_FAMILY_CAP)
    for kv in (os.environ.get("FLEET_FAMILY_CAP") or "").split(","):
        kv = kv.strip()
        if "=" in kv:
            k, v = kv.split("=", 1)
            m[k.strip()] = v.strip()
    return m


def family_cap(family, caps=None):
    """→ int cap for `family` (None = uncapped).  Pass the parsed map from
    family_caps() when both doors already hold it; a family explicitly
    cleared ('family=') or absent from the map is uncapped.  A garbage
    value degrades to uncapped (None) — the same behavior the keeper's
    old int() try/except had."""
    v = (caps if caps is not None else family_caps()).get(family)
    if v in (None, ""):
        return None
    try:
        return int(v)
    except ValueError:
        return None


# ── the counters (the shared definition — T845 §2) ───────────────────────
# Both doors count in_progress rows from `managent status --json`; a row's
# family is its stored model, else its identifier's model prefix, else "" —
# exactly the keeper's pre-T845 rule, now in one place.

def inprog_rows(rows):
    return [r for r in rows if r.get("status") == "in_progress"]


def total_inprog(rows):
    return len(inprog_rows(rows))


def family_inprog(rows):
    """{family: count} over in_progress rows — the per-family fan-out."""
    counts = {}
    for r in inprog_rows(rows):
        m = r.get("model") or (r.get("identifier") or "").split("/")[0] or ""
        fam = family_of(m)
        counts[fam] = counts.get(fam, 0) + 1
    return counts


def inprog_holds(rows):
    """The union of holds of in_progress rows — the one-writer set (T500)."""
    holds = set()
    for r in inprog_rows(rows):
        for h in (r.get("holds") or []):
            holds.add(h)
    return holds


# ── the kanban snapshot (same store resolution both doors use) ───────────
def store_path(root):
    return os.environ.get("MANAGENT_STORE") or os.path.join(
        root, "docs", "infra", "managent", "tasks.json")


def read_rows(root):
    """→ rows from `managent status --json` (the REAL managent binary, the
    store resolved exactly as bin/dispatch's row_state does: MANAGENT_STORE
    env, else <root>/docs/infra/managent/tasks.json), or None on failure.
    --test-root only relocates the store-default, never the tooling."""
    mg = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                      "bin", "managent")
    env = dict(os.environ)
    env["MANAGENT_STORE"] = store_path(root)
    try:
        out = subprocess.run([mg, "status", "--json"], capture_output=True,
                             text=True, env=env, timeout=20).stdout
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return None
    try:
        return json.loads(out)
    except json.JSONDecodeError:
        return None


# ── the override ledger (T845 §3) ────────────────────────────────────────
def record_cap_override(root, task_id, kinds, counts, reason, now=None):
    """Append one JSON line to <root>/untracked/fleet-cap-overrides.jsonl
    and return its path (None on OSError / missing reason).  Append-only,
    never overwritten — an override is an audit event, not state; the
    reason is the operator's assertion that they have checked the fleet
    themselves.  `kinds` is the comma list of exceeded caps ("total",
    "family", or "total,family"); `counts` carries the numbers."""
    if not reason or not reason.strip():
        return None
    now = int(now if now is not None else time.time())
    line = {
        "ts": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(now)),
        "task": task_id,
        "kind": kinds,
        "counts": counts,
        "reason": reason.strip(),
    }
    try:
        p = os.path.join(root, "untracked", CAP_OVERRIDES_FILE)
        os.makedirs(os.path.dirname(p), exist_ok=True)
        with open(p, "a") as f:
            f.write(json.dumps(line, sort_keys=True) + "\n")
        return p
    except OSError:
        return None


# ── CLI (diagnostics: print the caps as the two doors would read them) ───
def main(argv):
    rows = read_rows(os.getcwd())
    out = [
        f"FLEET_CAP={total_cap()} (default {DEFAULT_TOTAL_CAP})",
        "FLEET_FAMILY_CAP=" + ",".join(f"{k}={v}" for k, v in sorted(family_caps().items())),
    ]
    if rows is not None:
        out.append(f"in_progress total={total_inprog(rows)}")
        for fam, n in sorted(family_inprog(rows).items()):
            cap = family_cap(fam)
            out.append(f"in_progress family {fam}={n}"
                       + (f"/{cap}" if cap is not None else " (uncapped)"))
    print("\n".join(out))
    return 0


if __name__ == "__main__":
    import sys
    sys.exit(main(sys.argv[1:]))
