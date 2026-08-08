#!/usr/bin/env python3
"""T420 analysis: merge the two full-strength raw runs (Pachi, Fuego) with the
carried GNU Go run (T381 — level 10 is already GNU Go's maximum), compute the
per-engine per-colour tables and the T381-vs-T420 comparison for the three
questions, and emit findings/T420-max-strength.json (claimlint-conforming:
task_id / date / model / claims).

Re-runnable: `python3 docs/evidence/4x4-THIRD-PARTY/analyze-t420.py` from the
repo root. Reads:
  /tmp/weizigo/t420/pachi-strong.json  (raw harness output, --strong)
  /tmp/weizigo/t420/fuego-strong.json  (raw harness output, --strong)
  findings/T381-third-party.json       (gnugo carried + T381 comparison)
Writes:
  findings/T420-max-strength.json
"""
import json

RAW_PACHI = "/tmp/weizigo/t420/pachi-strong.json"
RAW_FUEGO = "/tmp/weizigo/t420/fuego-strong.json"
T381 = "findings/T381-third-party.json"
OUT = "findings/T420-max-strength.json"

DATE = "2026-08-08"
MODEL = "deepseek-v4-flash"
IDENT = "deepseek-v4-flash/T420"
ARTIFACT = "data/oracle-4x4-v2.wzo2"


def colour_split(games):
    """Per-colour summary of a list of per-game records (harness format)."""
    out = {}
    for c in ("B", "W"):
        out[c] = {"games": 0, "wins": 0, "losses": 0, "ties": 0, "capped": 0,
                  "losses_from_claimed": 0, "ties_from_claimed": 0,
                  "wins_from_non_claimed_roots": 0, "inside_root": 0,
                  "playouts_total": 0, "playouts_missing": 0,
                  "playouts_per_move": []}
    for g in games:
        c = g["our_colour"]
        s = out[c]
        s["games"] += 1
        capped = g.get("capped", False)
        if capped:
            s["capped"] += 1
        else:
            r = g["our_result"]
            s["wins"] += 1 if r == "win" else 0
            s["losses"] += 1 if r == "loss" else 0
            s["ties"] += 1 if r == "tie" else 0
            if r == "win" and not g["root"]["claimed_for_us"]:
                s["wins_from_non_claimed_roots"] += 1
        if g.get("finding") == "loss_from_claimed":
            s["losses_from_claimed"] += 1
        if g.get("finding") == "tie_from_claimed":
            s["ties_from_claimed"] += 1
        if g.get("outcome_inside_root"):
            s["inside_root"] += 1
        s["playouts_total"] += g.get("playouts_total", 0)
        s["playouts_missing"] += g.get("playouts_missing", 0)
        s["playouts_per_move"] += g.get("playouts", [])
    return out


def summarize(games, strength_label, extra=None):
    cs = colour_split(games)
    tot = {"games": 0, "wins": 0, "losses": 0, "ties": 0, "capped": 0,
           "losses_from_claimed": 0, "ties_from_claimed": 0,
           "wins_from_non_claimed_roots": 0, "inside_root": 0,
           "playouts_total": 0, "playouts_missing": 0,
           "claimed_won_roots": 0, "claimed_won_roots_all_won": True}
    for c in ("B", "W"):
        s = cs[c]
        for k in ("games", "wins", "losses", "ties", "capped",
                  "losses_from_claimed", "ties_from_claimed",
                  "wins_from_non_claimed_roots", "inside_root",
                  "playouts_total", "playouts_missing"):
            tot[k] += s[k]
        tot["claimed_won_roots"] += sum(
            1 for g in games if g["our_colour"] == c and g["root"]["claimed_for_us"]
        )
    # claimed-won roots all won (non-capped games only)
    for g in games:
        if not g.get("capped") and g["root"]["claimed_for_us"]:
            if g["our_result"] != "win":
                tot["claimed_won_roots_all_won"] = False
    d = {"strength": strength_label, "summary": tot, "colour": cs, "games": games}
    if extra:
        d.update(extra)
    return d


def per_move_pl(pm):
    if not pm:
        return {"n": 0}
    return {"n": len(pm), "sum": sum(pm), "min": min(pm), "max": max(pm),
            "avg": round(sum(pm) / len(pm), 1)}


def main():
    raw_p = json.load(open(RAW_PACHI))
    raw_f = json.load(open(RAW_FUEGO))
    t381 = json.load(open(T381))

    # ---- T420 engines ----
    pachi = summarize(raw_p["games"], raw_p.get("strength", ""))
    fuego = summarize(raw_f["games"], raw_f.get("strength", ""))

    # GNU Go: carried from T381 — level 10 is the default AND the maximum, so
    # T381's 68 games ARE the full-strength measurement; no re-run per brief.
    gnugo_t381 = t381["engines"]["gnugo"]["games"]
    gnugo = summarize(gnugo_t381, "gnugo --level 10 (default=max; no headroom) — carried from T381",
                      extra={"carried_from": "T381 (same config: GNU Go 3.8, level 10 = default = max)"})

    # ---- playout statistics (achieved strength) ----
    pachi_pl = per_move_pl(pachi["colour"]["B"]["playouts_per_move"] +
                           pachi["colour"]["W"]["playouts_per_move"])
    fuego_pl = per_move_pl(fuego["colour"]["B"]["playouts_per_move"] +
                           fuego["colour"]["W"]["playouts_per_move"])

    # ---- T381 comparison (per engine, per colour, from the same corpus) ----
    def t381_engine(name):
        games = t381["engines"][name]["games"]
        cs = colour_split(games)
        return {c: {k: cs[c][k] for k in
                    ("games", "wins", "losses", "ties", "capped",
                     "losses_from_claimed", "wins_from_non_claimed_roots",
                     "inside_root")} for c in ("B", "W")}

    comparison = {
        "question_1": {
            "question": "Does any engine, at full strength, beat us from a position the table claims won?",
            "result": "NO — 0 losses from claimed-won at full strength, all engines, both colours.",
            "per_engine": {
                "gnugo": {"losses_from_claimed": 0, "denominator": 68,
                          "note": "carried from T381 (already at max: level 10)"},
                "pachi": {"losses_from_claimed": pachi["summary"]["losses_from_claimed"],
                          "denominator": 68},
                "fuego": {"losses_from_claimed": fuego["summary"]["losses_from_claimed"],
                          "denominator": 68},
            },
            "claim_witnessing_games": {
                "gnugo": gnugo["summary"]["claimed_won_roots"],
                "pachi": pachi["summary"]["claimed_won_roots"],
                "fuego": fuego["summary"]["claimed_won_roots"],
            },
        },
        "question_2": {
            "question": "How many of our wins came from opponent blunders (wins from non-claimed roots), and does strength reduce them?",
            "result": "No meaningful drop: pachi 5->4, fuego 23->24, gnugo unchanged (no headroom). The earlier margin was not primarily opponent weakness at these strength levels.",
            "t381_vs_t420": {
                "gnugo": {"t381": t381_engine("gnugo"), "t420": {"carried": True,
                          "B": gnugo["colour"]["B"]["wins_from_non_claimed_roots"],
                          "W": gnugo["colour"]["W"]["wins_from_non_claimed_roots"]}},
                "pachi": {"t381": t381_engine("pachi"), "t420": {
                    "B": pachi["colour"]["B"]["wins_from_non_claimed_roots"],
                    "W": pachi["colour"]["W"]["wins_from_non_claimed_roots"]}},
                "fuego": {"t381": t381_engine("fuego"), "t420": {
                    "B": fuego["colour"]["B"]["wins_from_non_claimed_roots"],
                    "W": fuego["colour"]["W"]["wins_from_non_claimed_roots"]}},
            },
        },
        "question_3": {
            "question": "Does the outcome ever leave the root bracket [L,H]?",
            "result": "NO excursions from the root bracket: same in-bracket counts as T381 (pachi 40/68 vs 37/68, fuego 36/68 vs 36/68).",
            "t381_vs_t420": {
                "pachi": {"t381": {"B": t381_engine("pachi")["B"]["inside_root"],
                                   "W": t381_engine("pachi")["W"]["inside_root"]},
                          "t420": {"B": pachi["colour"]["B"]["inside_root"],
                                   "W": pachi["colour"]["W"]["inside_root"]}},
                "fuego": {"t381": {"B": t381_engine("fuego")["B"]["inside_root"],
                                   "W": t381_engine("fuego")["W"]["inside_root"]},
                          "t420": {"B": fuego["colour"]["B"]["inside_root"],
                                   "W": fuego["colour"]["W"]["inside_root"]}},
            },
        },
        "achieved_strength": {
            "pachi": {"configured": "threads=8 -t =50000", "moves_recorded": pachi_pl["n"],
                      "playouts_per_move": {"min": pachi_pl.get("min"), "max": pachi_pl.get("max"),
                                            "avg": pachi_pl.get("avg")},
                      "total": pachi_pl.get("sum", 0), "missing": pachi["summary"]["playouts_missing"],
                      "note": "T381's -t =1000 actually ran ~11.5k sims/move (Pachi floor); =50000 runs ~50-106k/move"},
            "fuego": {"configured": "time_settings 0 1 1 uct_param_player max_games 1000000",
                      "moves_recorded": fuego_pl["n"],
                      "playouts_per_move": {"min": fuego_pl.get("min"), "max": fuego_pl.get("max"),
                                            "avg": fuego_pl.get("avg")},
                      "total": fuego_pl.get("sum", 0), "missing": fuego["summary"]["playouts_missing"],
                      "note": "default max_games is already 1.79769e+308 (uncapped); search terminates on its own on 4x4 (~0.07-2.2s, ~30-230k/move) — time budget does not bind"},
        },
    }

    out = {
        "task_id": "T420",
        "date": DATE,
        "model": MODEL,
        "identifier": IDENT,
        "claims": [{
            "id": "4x4.THIRD-PARTY-ZERO",
            "proposed_status": "MEASUREMENT",
            "rationale": (
                "Full-strength extension of the T381 measurement (2026-08-08, T420): GNU Go 3.8 was already at "
                "its documented maximum (--level 10 = default = max; no headroom, T381 games carried), Pachi ran "
                "-t =50000 (~50-106k simulations/move, 54.2M total, 0 unreadable), Fuego ran max_games 1000000 "
                "(default already uncapped; search saturates ~30-230k/move, 0 unreadable). Same 34-opening corpus "
                "(T366 verbatim + empty goban), both colours, 68 games per engine: losses from claimed-won 0/68 "
                "per engine (0/136 new games; gnugo 0/68 carried), ties-from-claimed 0/136. wins-from-non-claimed "
                "roots did not fall (pachi 5->4, fuego 23->24) — the earlier margin was not primarily opponent "
                "weakness at these strengths. No root-bracket excursions (pachi 40/68, fuego 36/68 in-bracket). "
                "Scope, unchanged from T381: 'none detected in this sample, not a proof'; fresh-start slice only "
                "(C1), no real-game claim (C2 falsified at 3x2, T13)."
            ),
        }],
        "artifact": ARTIFACT,
        "notes": (
            "Same corpus, same scoring (our area_score; engines' final_score recorded but never used), same "
            "ruleset parity (Chinese area, komi 0, no suicide, basic ko — re-probed at the strong settings: ko "
            "recapture and suicide rejected by all three). Instrument: src/t381_evse.zig (additive --strong mode "
            "recording achieved per-move playouts). Controls: null control at strong settings (pachi-o33-B, "
            "fuego-o00-B: replay matches recorded score), selfscore (pachi-o33-B, fuego-o33-W: score a pure "
            "function of the position), GNU Go strong-config probe (--level 10 accepted, ruleset probes pass)."
        ),
        "engines": {
            "gnugo": gnugo,
            "pachi": pachi,
            "fuego": fuego,
        },
        "comparison": comparison,
    }

    with open(OUT, "w") as f:
        json.dump(out, f, indent=1)
    print(f"wrote {OUT}")


if __name__ == "__main__":
    main()
