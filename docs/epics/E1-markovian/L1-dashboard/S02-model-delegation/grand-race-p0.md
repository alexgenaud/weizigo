# Grand race — P0 go/no-go

**Author:** claude-opus-5 / T529 · **Date:** 2026-08-20 · **Landmark:** L9 (the fleet can race
its own workers on demand)
**Spec:** `docs/epics/E1-markovian/L1-dashboard/S02-model-delegation/grand-race.md` (roster epoch `2026-08-20b`, gates G1–G6, §8 spend)
**Scope, as ruled at commit `45cfad0`:** this row is the go/no-go prep — **roster, spend
estimate, sealed-packet keys, fixture-store freeze**. It does *not* own gates G2/G3/G4 (that is
`T542`) or the G1 capture instrument (`T521`). Where P0 work touches those gates it reports and
recommends; it does not implement them.

**The one-command form of this document:**

```sh
tools/race-p0-verify.sh --staged <worktree>/race-input \
                        --run-root <worktree>/race-input \
                        --lane-sessions <worktree>
```

Exit 0 is GO, exit 1 is NO-GO, and every check prints its own PASS/FAIL line. Two reporting
modes sit beside the gate: `--lane-tokens <worktree>` prints the measured per-lane spend table
of §4, and `--write-seals` re-freezes the fixture store deliberately. Controls:
`tools/regression-race-p0.sh` (null + seeded, both directions), wired into `zig build test`.

---

## 1. Verdict

**GO for the aspect races. GO for grand-race P1. The P3→P5 half needs a spend decision the
operator has not yet been given the numbers for — §4 supplies them.**

| P0 row | state | basis |
|---|---|---|
| Roster resolved | **GREEN** | 7 lanes parse under `tools/bakeoff.sh`'s own `parse_roster`; every label is in the canonical LIST; every lane servable on this host |
| Sealed packet keys | **GREEN** | 7/7 keys and 7/7 `PACKET.md` re-hash to the sealed values; the manifest itself matches its pin in `artifacts/SHA256SUMS` at `b389b0f` |
| Fixture store frozen | **GREEN — after replacing the seal** | the manifest's `tar` seals verify in place but **false-FAIL on an untampered copy**; replaced with copy-stable content seals that verify at rest *and* in the staged store |
| Key isolation (G2 substance) | **GREEN as run, and now measured both ways** | no key material anywhere under the live race worktree (`KEYLEAK`), and **no lane's own transcript shows it acting on key material** (`KEYREACH`, 11 session dirs). The mechanism gap that made this luck is closed by a pre-dispatch check here and by `T542`'s refusal |
| Token capture (G1) | **AMBER — and much better than the round-1 record says** | 21 of 35 staged lane-cells have full readings *on disk right now* (§4), against a race record that says every cell is `null`. DeepSeek lanes remain **structurally unrecoverable** — §5 |
| Spend estimate | **GREEN** | §4, from measured per-lane records, not from §8's estimate |

Nothing found here justifies stopping the aspect races, which have already run round 1.

## 2. Roster — epoch `2026-08-20b`, resolved and validated

Committed as `docs/epics/E1-markovian/L1-dashboard/S02-model-delegation/roster-2026-08-20b.txt` in the exact format the harness parses,
so the roster is an input file rather than a paragraph someone retypes.

| lane | family | serving tag | servable here | how checked |
|---|---|---|---|---|
| `claude-fable-5` | claude | — | yes | `claude` on PATH; a lane already ran (§4) |
| `claude-opus-5` | claude | — | yes | same |
| `claude-sonnet-5` | claude | — | yes | same |
| `claude-haiku-4-5-20251001` | claude | — | yes | same |
| `deepseek-v4-pro` | deepseek | — | yes | `pi` on PATH; T536–T544 rows live on it today |
| `deepseek-v4-flash` | deepseek | — | yes | same |
| `qwen3.8:27b-mlx` | ollama | `qwen3.8:27b-mlx` | yes | pulled locally, 18 GB; a lane already ran (§4) |

`WEIZIGO_BAKEOFF_ALLOW_CLAUDE=1` is the gate the four Claude lanes need, and it is authorized
(`grand-race.md` §2).

**The Ollama trio deferral, re-measured rather than assumed.** `glm-5.2`, `minimax-m3` and
`kimi-k2.7` are out of this epoch because Ollama cloud credits are exhausted. That was recorded
this morning; P0 **re-probed it** rather than inheriting it:

```
$ ollama run glm-5.2:cloud "Reply with the single word: ok"
Error: 429 Too Many Requests: you (infallible_moser_218) have reached your
session usage limit, upgrade for higher limits …                 (2026-08-20 ~13:05Z)
```

Still 429. The deferral stands, the trio's delta round is **not** available now, and per the
T538 rule this is infrastructure — it is not a data point about those three models. The probe
is one command and belongs in the go/no-go, because "the trio is out" is a status assertion and
status carries a timestamp.

---

## 3. Seals — keys, packets, and the fixture-store freeze

### 3.1 What verifies

All 21 sealed artifacts re-hash to the values `kimi-k2.7/T528` recorded, and the manifest that
records them matches the SHA-256 pinned in `artifacts/SHA256SUMS` at commit `b389b0f`:

- **7/7 answer keys** — the five aspect `key.txt` files plus `race3.key` / `race5.key`.
- **7/7 `PACKET.md`** briefs.
- **7/7 fixture stores** under the manifest's own `tar` recipe, *run in place*.

Tamper evidence is intact. Nothing was edited between sealing and now.

### 3.2 The freeze instrument was broken, in the direction that matters

The manifest seals each fixture store as `tar -cf - <dir> | sha256sum`. A tar stream carries
mtimes and the path prefix, so **a byte-identical copy of a store hashes differently**. Measured
against the store the aspect-race lanes are actually reading, in `T543`'s worktree:

| store | `diff -r` vs origin | manifest tar seal |
|---|---|---|
| `aspect-triage` | identical | `e8a175b8…` ≠ sealed `4810d700…` |
| `aspect-verdict` | identical | `4d88d8be…` ≠ sealed `911681d5…` |
| `aspect-inbox` | identical | `d6f21687…` ≠ sealed `c24c980d…` |
| `aspect-crash` | identical | `141a568f…` ≠ sealed `8e52201d…` |
| `aspect-dispatch` | identical | `d91e7d44…` ≠ sealed `c73d755b…` |

Five for five: the store is untampered and the seal says otherwise. The cause is mtime
(`2026-08-20T11:23:29Z` at origin, `12:49:58Z` staged), not content. That is the worse failure
direction for a seal — an instrument that red-lights the honest case gets waived, and a seal
that is routinely waived is not a seal. It also means the manifest's recipe can only ever be run
against the originals, never against **what the lanes actually see**, which is the only place a
fixture swap would show up.

**Replaced, not patched over.** `docs/epics/E1-markovian/L1-dashboard/S02-model-delegation/grand-race-p0-fixtures.sha256` records a
copy-stable **content seal** per store: the sorted `sha256  relpath` listing of the store,
hashed. It is mtime-, owner- and path-independent, so it verifies both at rest and in the staged
copy. All 7 stores verify at origin and all 5 staged aspect stores verify in `T543`'s worktree.

The manifest's tar hashes are still checked in place and are still the historical seal — the
content seal is an addition, and the divergence above is kept as a control
(`control-tar` in `--self-test`) so a future edit back to tar hashing fails the regression.

### 3.3 The keys sit beside the fixtures they answer

Five of the seven answer keys live *inside* the packet directories, as siblings of the
`fixtures/` the lanes must read:

```
untracked/race-aspects/packets/aspect-triage/
  ├── PACKET.md      ← lane must read
  ├── fixtures/      ← lane must read
  └── key.txt        ← lane must NOT read
```

The manifest calls this path "lane-inaccessible" because it is gitignored. Gitignored is not
inaccessible: it means *absent from a worktree checkout*, and the fixtures are absent from that
checkout too — so the packet has to be staged into the run root for any lane to run at all. Once
you stage it, the boundary is whatever the staging command happened to copy.

**As actually run, this is clean.** `T543` staged `race-input/<packet>/{PACKET.md,fixtures/}`
and copied no key. Scanned the entire live race worktree: **no key material anywhere**, and the
staged fixtures are byte-identical to the sealed originals. The race official got this right.

**As a mechanism, it is one keystroke from the T452 breach** — `cp -r packets/* race-input/`
ships every answer key to every lane, silently, and the race still looks like it ran. Prose
telling the next official to be careful is not a remedy for a mechanism failure. So the P0 gate
now *checks it*: `--run-root <dir>` walks the tree the lanes see and refuses on any `key.txt`,
`keys.txt`, `*.key` or `*-key.md`. Seeded control: a planted `key.txt` is caught. Null control:
a key-free run root with fixtures is not flagged.

**Measured a second way, at the only place that settles it: what the lanes did.** A filesystem
scan shows what a lane *could* reach; it cannot show what it *did*. `--lane-sessions` reads the
lanes' own transcripts — Claude Code's under `~/.claude/projects/<slug>/` and pi's under
`~/.pi/agent/sessions/--<slug>--` — and flags any assistant turn, tool call or tool result
touching key material. Across all **11 session directories** of the `T543` run: **no hit**. The
race was clean in behaviour, not just in layout.

That check has to distinguish two things a naive grep cannot, and its controls pin both:

- **seeded** — a lane whose transcript shows `read packets/aspect-triage/key.txt` is caught.
- **null** — a *brief* that names the key path is **not** a lane action. This is not
  hypothetical: the epistemic packet brief hands the lane
  `untracked/race-keys/race{1,2,3,5}.key` verbatim, with each key's SHA-256 and the sentence
  "outside lane reach by directory boundary". Counting prompt text would red-light every honest
  run, and an instrument that red-lights the honest case gets waived.

**Two things that finding surfaces, for whoever owns the packets.** First, the epistemic brief
tells a lane exactly where the answers live — harmless while the boundary holds, and a
free head start the moment it does not; the brief does not need those paths. Second, the two
epistemic lanes ran with cwd set to the **worktree root**, not to an isolated
`race-input/<packet>` directory the way the five aspect lanes did — so for those lanes the only
boundary was the worktree itself. Neither is a breach as run; both are avoidable.

Recommendation for the operator, not executed here: **move the five aspect keys into
`untracked/race-keys/`**, where the two epistemic keys already live. File contents do not
change, so all five sealed SHA-256s continue to verify and the seal is not broken. It is
deliberately **not** done in this row — `T543` is mid-flight and re-hashes at the manifest's
paths in its Step 0; moving them under a running race would break the tamper check it is
relying on.

---

## 4. Spend — measured, not estimated

`grand-race.md` §8 estimates the race as "≈ 80 dispatches plus reruns, walls 1800–3600 s" and
the packet manifest bounds an aspect lane at "≈ 4.3 k tokens per lane" for all seven packets.
Both are dispatch counts and artifact sizes. Neither is a spend figure, and the project has
never had one: *"6/6 blank `tokens.template.md`; n=0 across all prior races."*

It has one now, and it did not require building anything: the records already existed.

### 4.1 Aspect race A1 (triage) — every lane, mechanically captured, today

Read out of the harness's own session records for the run `T543` is executing right now.
`tokens_in` / `tokens_out` follow the §6 schema (`tokens_in = input + cache_read`).

| lane | turns | tokens_in | cache_write | tokens_out | source |
|---|---:|---:|---:|---:|---|
| `claude-sonnet-5` | 9 | 328,689 | 61,974 | 56,198 | Claude Code transcript |
| `claude-haiku-4-5-20251001` | 6 | 132,856 | 46,382 | 13,858 | Claude Code transcript |
| `claude-fable-5` | 6 | 122,202 | 49,412 | 12,888 | Claude Code transcript |
| `claude-opus-5` | 5 | 117,273 | 26,492 | 22,644 | Claude Code transcript |
| `qwen3.8:27b-mlx` | 2 | 20,281 | 0 | 458 | pi session record |
| `deepseek-v4-pro` | — | **no record** | — | **no record** | §5 |
| `deepseek-v4-flash` | — | **no record** | — | **no record** | §5 |

Five of seven lanes measured; two structurally unmeasurable. **Recorded as missing with a
reason, never estimated** — that is the G1 rule, and this is what honouring it looks like.

First readings this produces, offered as observations and not as rankings (n=1 per cell):

- **The manifest's cost bound is 20–90× low.** It estimated ≈ 0.6 k output tokens for A1;
  measured output is 12.9 k–56.2 k. It counted the size of `out.md` and omitted the reasoning
  and tool-loop turns that produce it. Anyone budgeting from it would be an order of magnitude
  out. **Corrected, not deleted**: the artifact estimate was roughly right about the artifact.
- **Turn count spread 2–9 on a byte-identical brief**, which is a real difference in how much
  re-derivation each lane does — one of the eight profile dimensions §6 asks for, arriving free.
- Do **not** read a quality ordering into these numbers. Grading is a separate row and the
  outputs are not graded yet.

### 4.2 The aspect track, projected from measurement

Five measurable lanes on A1 cost **721 k tokens_in / 106 k tokens_out** between them. Across
7 packets × 7 lanes = 49 lane-runs, taking A1 as typical:

- measurable lanes, 7 packets: ≈ **5.0 M in / 0.74 M out**
- with the two DeepSeek lanes at the same shape: ≈ **7 M in / 1.0 M out**

Under one week of ordinary fleet traffic. **The aspect track is cheap and the spend question
does not arise for it.** Run it.

### 4.3 The grand race P1–P6, projected from full-row medians

An aspect packet is a bounded answer from a frozen fixture store. A grand-race phase is a *real
delivery-pipeline row* — a spec, an audit, an implementation — so the honest anchor is the
project's own measured cost per completed row, not A1. Medians per completed row, rows T440+,
from the same mechanical records:

| lane | n | median tokens_in | median tokens_out | source |
|---|---:|---:|---:|---|
| `claude-opus-5` | 34 | 24,338,113 | 197,089 | Claude Code sessions |
| `claude-haiku-4-5-20251001` | 2 | 9,947,811 | 30,991 | Claude Code sessions |
| `claude-fable-5` | 32 | 8,881,380 | 213,466 | Claude Code sessions |
| `deepseek-v4-pro` | 31 | 6,330,287 | 63,735 | pi session records |
| `claude-sonnet-5` | 2 | 5,754,016 | 36,909 | Claude Code sessions |
| `deepseek-v4-flash` | 13 | 4,947,996 | 60,971 | pi session records |
| `qwen3.8:27b-mlx` | 1 | 940,290 | 27,547 | pi session record |

At epoch `2026-08-20b` the §8 dispatch count recomputes from 80 to **70**: 7 lanes × (4
generation phases + 5 grading rounds + 1 audit) = 10 dispatches per lane.

> **Envelope: ≈ 0.6 billion input tokens and ≈ 6.3 million output tokens.**

**Read that with its caveats, both of which point the same way.** The Claude medians come from
*whole seats* — long orchestrator sessions whose cache_read accumulates over hours — not from
one-shot `claude -p` lanes, so they overstate a lane. Against that, A1 shows a lane's real cost
running 20–90× above the intuition anyone would form from §8. The honest statement is that the
grand race is a **10⁸–10⁹ input-token commitment**, and §8's "80 dispatches" does not convey
that. The go/no-go between phases is the containment; the number above is what makes it a real
decision instead of a formality.

**Recommendation:** the operator's go/no-go should be taken **twice**, not once — a cheap yes
for the aspect races and P1 (≈ 10 M in), and a separate, informed yes for P3→P5, re-anchored on
the *actual* P1 lane records rather than on these row medians. P1 pays for its own estimate.

---

## 5. The G1 finding P0 did not go looking for

`T543`'s brief says G1 is "recoverable retroactively" because `T521`'s instrument reads the
existing session records. **That is true for Claude and Ollama lanes and false for DeepSeek
lanes**, and the reason is in the harness:

```python
# tools/bakeoff.sh:520 (execute) and :538 (--emit)
return runner + ["pi", "--provider", "deepseek", "--model", lane["label"],
                 "--no-session", "-p", prompt]
```

`--no-session` means no session file is written, so there is nothing for any later pass to mine.
The `tools/runner` trailer that `T543` is preserving carries exit, wall, CPU and peak RSS — it
carries **no token counts**. So for DeepSeek lanes the gap is not a wiring gap that a later row
can close; it is destroyed at dispatch time.

Confirmed against the T447 race: its worktree session directory holds four records
(2026-08-18, 39,998,299 in / 104,863 out) attributed by the instrument to `minimax-m3` ×3 and
`qwen3.8:27b-mlx` ×1 — and **none** to either DeepSeek lane, which the race record lists as
having run and scored. That race's own note, *"no token readings — an agent cannot read its own
meter and the operator was not at the console"*, was two-thirds wrong: the Ollama and local
readings were on disk the whole time, in a session directory nobody looked in.

**For `T542` (G1 wiring), stated as a concrete requirement:** drop `--no-session` for DeepSeek
race lanes, or pass an explicit session path per lane and record it in `lanes.json`. Until that
lands, a DeepSeek lane's token cell is `null` **with the reason `harness dispatched
--no-session; no record exists to mine`** — which is a different and more honest cell than
"missing reading", because no later pass can fill it.

### 5.1 A second T447 correction, from the same records

The T447 race record scores `qwen3.8:27b-mlx` as wall-killed at 2400 s with **zero bytes
captured**, and carefully says that reads as "no completion inside 40 minutes", not as "produced
nothing". The session record settles it: that lane generated **47,472 output tokens across 28
turns** before the wall guard killed it. It was producing the entire time; `pi` buffers stdout
to completion, so the kill discarded work that had already been done and paid for.

That changes what the DNF means. It is a **capture and wall-guard finding, not a capability
finding**, and any profile card that reads qwen's T447 result as "produces nothing" would be
wrong. Offered here for absorption; this row does not edit the T447 record or `model-perf.md`,
both of which belong to other rows and one of which has uncommitted edits in flight.

---

## 6. What P0 leaves red, named

A gate believed green that is not is worse than a known-red one, so:

| gate | owner | state at this writing |
|---|---|---|
| G1 tokens | `T521` instrument, `T542` wiring | **RED as a harness gate.** Recoverable for Claude/Ollama (§4 proves it), destroyed at dispatch for DeepSeek (§5) |
| G2 isolation | `T542` | **RED as a refusal.** `bakeoff.sh` records `root_is_worktree` and never refuses. P0 supplies an *external* pre-dispatch check (`--run-root`); that is a gate you must remember to run, which is not the same thing |
| G3 family exclusion | `T542` | **RED.** Grading-time; no lane is grade-valid until it lands |
| G4 blinding | `T542` | **RED.** Grading-time; same |
| G5 record | harness | **GREEN.** `lanes.json` + sealed lane map under flock |
| G6 impressions | `T522` | **RED.** Dispatchable, unclaimed |

**The status of the running aspect race, in one sentence that must not be lost between rows:
dispatch-valid, not grade-valid.** Lanes may run now; nothing may be graded until G3 and G4 are
green.

---

## 7. Files this row leaves behind

| file | what it is |
|---|---|
| `docs/epics/E1-markovian/L1-dashboard/S02-model-delegation/grand-race-p0.md` | this document |
| `docs/epics/E1-markovian/L1-dashboard/S02-model-delegation/roster-2026-08-20b.txt` | the epoch roster, in the format `tools/bakeoff.sh` parses |
| `docs/epics/E1-markovian/L1-dashboard/S02-model-delegation/grand-race-p0-fixtures.sha256` | copy-stable content seals for the 7 frozen fixture stores |
| `tools/race-p0-verify.sh` | the P0 gate — one command, GO/NO-GO, `--self-test` carries its controls |
| `tools/regression-race-p0.sh` | null + seeded controls, including red-first (a wrong seal must NO-GO) |
| `findings/T529-grand-race-p0.json` | findings |

Re-sealing is deliberate and visible: `tools/race-p0-verify.sh --write-seals` rewrites the seal
file, and the diff has to be committed for anyone to accept it.
