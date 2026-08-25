# Model ladders — priors, not measurements

**Status: BELIEFS (Class C).** Best-effort guesses combining the few measured cells, one
session's impressions, and pretraining-era folklore. **Nothing here passes the emission gate**
(`measurement-methodology.md` §5: anchored, n ≥ 2, ≥ 2 qualified models at different cost) and
nothing here enters `model-task-metrics.jsonl` or the matrix. These ladders exist to be
**falsified by races** (the "race, don't decide" ruling); each one is a standing hypothesis for
the race queue, and a race result overwrites it without ceremony.

**Author:** `claude-fable-5`, 2026-08-22, at operator request. **Standing conflict:** the author
is a Claude model ranking Claude models. Per the review-independence rule
(`measurement-methodology.md` §5), treat every Claude placement below — and especially every
`fable` placement — as the *least* trustworthy lines in this file.

**Epoch:** current (post-2026-08-18 DeepSeek boundary). Roster and canonical labels per
`model-registry.md`; short names below are presentation only (canonical mapping as of
2026-08-22: opus=`claude-opus-5`, fable=`claude-fable-5`, sonnet=`claude-sonnet-5`,
haiku=`claude-haiku-4-5-20251001`, dspro=`deepseek-v4-pro`, flash=`deepseek-v4-flash`,
glm=`glm-5.2`, minimax=`minimax-m3`, kimi=`kimi-k2.7`, qwenlocal=`qwen3.8:27b-mlx`).

**Evidence tags** on every placement:
- **[M]** measured at least once (cite in place; almost always n = 1, grader caveats apply)
- **[I]** impression from observed-but-ungraded behaviour (dispatch-verify ledger, session work)
- **[F]** folklore — reputation, pretraining-era knowledge, family pricing intuition

---

## 1. Ladders by task type (D027 operator types, frequency order)

### audit / verification — 27 % of graded dispatch (matrix T-A)

Grader-mix caveat: the (T447) and (T447-rep) numbers were graded by different models and are
not directly comparable; the merged ordering below is therefore already a belief, not a reading.

1. opus [M — 46, T447-rep; also 11 findings incl. all four musts on the pass-2 spec audit]
2. fable [I — expect ≈ opus; **unmeasured in T-A**, matrix hole #5; RESERVED so may never fill]
3. flash [M — 38, T447]
4. dspro [M — 34, T447]
5. glm [M — 30, T447]
6. sonnet [M — 26, T447-rep; consistent style: few findings, each sharp — precision over recall]
7. minimax [M — 27, T447]
8. kimi [M — 25, T447]
9. haiku [M — 0, T447-rep, false-negative "no escape paths"; **never dispatch an audit to haiku
   without a second lane**]
10. qwenlocal [M — no completion in 2400 s on repo-wide input; but see §2 verification-depth — on a
    *bounded* verification target it is not last, it is mid]

### infra / tooling — 22 %

1. glm [M — scope_discipline 1.00, n = 37, the most confident single verdict in the profiles table]
2. flash [I — high-volume workhorse, closes rows]
3. dspro [I — capable but today's dispatch-verify ledger shows a fail=row incomplete habit:
   T544, T530, T599]
4. sonnet [F — clean bounded tool work, expensive for the tier]
5. kimi [F — the serving tag is literally `kimi-k2.7-code:cloud`; folklore says bounded code is
   its lane]
6. minimax [F — mid; one rc=124 cohort death on record, a fleet datum not a quality datum]
7. haiku [I — fine for small scripts with mechanical acceptance; passed T589/T598/T618 today]
8. opus [F — over-qualified; spends premium tokens on work flash closes]
9. qwenlocal [M-adjacent — only when input and output are both small]
10. fable [ruling — never; RESERVED types only]

### battery-heavy — 18 %

1. flash [M — correctness 1.62, n = 80, the largest sample anywhere in the ledger]
2. dspro [M — second by volume]
3. glm [I]
4. kimi [F]
5. sonnet [F]
6. minimax [F]
7. haiku [F — cheap enough to burn, but batteries reward thoroughness, its weak axis]
8. opus / fable [F/ruling — wrong cost tier]
9. qwenlocal [M — only overnight, never during a measured suite run]

### implementation-bounded — 11 % (matrix T-B; zero graded cells, this ladder is nearly all guess)

1. sonnet [F — the folklore "best value coder" in the Claude family; untested here]
2. flash [I — extrapolated from its battery correctness sample]
3. opus [F — likely strongest absolute, rarely worth the tokens for a bounded leaf]
4. glm [M — T451 and T452 crash repairs passed; "demonstrated competence", not "better than"]
5. kimi [M/F — T453 passed; plus the code serving tag]
6. dspro [I]
7. minimax [F]
8. haiku [F — only with a sealed mechanical acceptance gate (§6 of the methodology), never on
   panel trust]
9. qwenlocal [unknown in Zig — "untested", not "cannot code"]
10. fable [ruling — never]

Race #2 (mechanized-acceptance implement race) exists precisely to destroy this ladder.

### orchestration-seat — 8 % (matrix T-H)

1. dspro [operator hypothesis, untested this epoch — "may earn its premium here"]
2. opus [M in flight — current console work; strong plan-keeping impression]
3. sonnet [I — expect adequate at lower cost; untested]
4. flash [M prior epoch — T363 first sprint-manager trial, worked]
5. fable [M prior epoch — held the seat 2026-08-05; works, but context ceiling + RESERVED makes
   it the wrong resident; T612 merged-fresh-console pattern is the mitigation, not a reason to seat it]
6. glm [F]
7. kimi / minimax [F — no evidence either way]
8. haiku [I — plan-drift and premature-closure risk over hours]
9. qwenlocal [structural no — a console is all tool round-trips, each paying local latency]

### integration / reframe — 6 %

1. fable [I — this is what the RESERVED reservation is *for*: deep holistic review, holding the
   whole argument; the three-regime reframe and grand-audit direction docs are the house examples]
2. opus [M-adjacent — same tier in practice, cheaper, fewer reservation constraints]
3. dspro [I — good when the reframe decomposes into subdelegated parts]
4. sonnet [F]
5. flash [I — executes a given reframe well; less evidence it originates one]
6. glm / kimi / minimax [F — no data]
7. haiku [F — no]
8. qwenlocal [F — no]

### research / census — 4 % (almost no data anywhere; pure prior)

1. opus [F — breadth + citation honesty is the winning combination for census work]
2. flash [I — cheap breadth]
3. dspro [I]
4. sonnet [F]
5. qwenlocal [I — the one niche: overnight bounded re-runs and variance measurement, where slow is free]
6. glm / kimi / minimax [F]
7. haiku [F — census rewards not-missing-things]
8. fable [ruling — only if the census *is* the holistic review]

### spec / design — 3 %, but the operator's declared high-leverage cell (matrix T-E)

Measured base: T554 grading round — opus/sonnet/flash "great", fable/dspro "good", haiku "bad"
(mechanically confirmed fabricated citation, disqualified under the §5 gate regardless of panel score).

1. opus [M — great]
2. sonnet [M — great]
3. flash [M — great, 4.86/5; the ceiling caveat lives here: it saturates the verdict scale]
4. fable [M — "good", one topic, n = 1; my own suspicion is topic artifact, which is exactly what
   race #3 (T554 round 2, different topic) is designed to test — discount this line hardest, I am
   ranking myself]
5. dspro [M — good]
6. glm [F]
7. kimi / minimax [F]
8. qwenlocal [F — long-form coherence over small input is not implausible, untested]
9. haiku [M — disqualified: fabrication gate]

### adjudication / verdict-writing (matrix T-F; not a D027 type but a seat that recurs)

1. opus [M-adjacent — B-3 verification review: every claim proved true on disk, best in field on
   the evidence axis]
2. fable [I — independence and willingness-to-overturn are the reserved traits; T614 pass-with-findings
   audit of the S04 reconciler spec is the one recent datum]
3. qwenlocal [M — the `getsid` unique catch, every citation verified: verification *depth* is real]
4. sonnet [I — sharp, low false-alarm]
5. flash [M-adjacent — served as race grader repeatedly without incident]
6. glm [M-adjacent — wins the volume-graded independence metric in the profiles table]
7. dspro [I]
8. kimi / minimax [F]
9. haiku [M — fabrication + false-negative history; never an adjudicator]

G3 note: family independence binds harder than rank here — the best Claude adjudicator is still
ineligible to adjudicate a race that ranks Claude lanes.

---

## 2. Ladders by cross-cutting capability

### citation / verification honesty (the rank-1 discriminator per methodology §6)

opus [M] > qwenlocal [M] > sonnet ≈ glm [I] > flash ≈ dspro [I — no fabrication on record, no deep
probe either] > kimi ≈ minimax [F] > fable [unmeasured — expected high, but self-assessment is
worthless here] ≫ haiku [M — one confirmed fabricated citation].

### thoroughness (a D027 dimension with **zero recorded data for every model** — all guess)

opus > fable > flash > dspro > minimax ≈ glm > kimi > sonnet (deliberately trades recall for
precision) > qwenlocal (deep but narrow) > haiku.

### scope discipline (stay inside the brief)

glm [M — 1.00, n = 37] > sonnet [I] > qwenlocal [I — physically can't wander far] > flash [I] >
kimi [F] > haiku [I] > minimax [F] > dspro [I — today's fail=row incompletes are partly scope
drift] > opus ≈ fable [I — both tend to exceed the brief; sometimes that is the value, it is
still indiscipline].

### reliability-to-close (dispatch-verify ledger impression, 2026-08-22 sample)

**CORRECTED 2026-08-22 (post-outage):** the morning sample is contaminated. Five Claude
`fail=row` entries (fable, opus ×2, sonnet ×2) were the 12:47Z 5-hour-window provider outage
scored as model failures (classifier miss, folded into T625), and at least two of the rows the
classifier *did* excuse were misclassified the other way (T526 was our own watchdog kill; T601
actually succeeded). Until T625's fix lands and the rows are re-scored, this axis distinguishes
**provider availability and instrument error, not models** — treat model-the-weights and
model-the-service as separate things here. What survives: minimax's rc=124 history and qwenlocal's
wall-ceiling kill (both fleet data), haiku's speed-as-survival (its two lanes finished before
the wall came down). [I] throughout, now with known contamination.

### speed to done (wall clock, tool-heavy work)

haiku > flash > glm ≈ kimi ≈ minimax (cloud lanes) > sonnet > dspro > opus > fable ≫ qwenlocal
(structurally last on anything tool-heavy; competitive only when the task is one generation).

### cost per solved row (folklore only — **uncomputable across families** until the §6 token
split lands; fresh-vs-cache-read is unsplit)

qwenlocal (costs the machine, not money) ≤ glm ≈ minimax ≈ kimi (credits, currently OFF) <
flash < haiku < dspro < sonnet < opus < fable. The interesting inversions to test once
computable: haiku-vs-flash (haiku may lose on rework cost despite cheap tokens), and
sonnet-vs-dspro on bounded implementation.

### long-horizon context / plan-keeping

fable ≈ opus (200 k; fable hands over before 90 % by ruling) > sonnet > dspro > flash >
glm ≈ kimi ≈ minimax > haiku (drifts) > qwenlocal. [F/I — no controlled measurement exists.]

---

## 3. Ladder by task size/scope (which tier to reach for, before type is even considered)

| scope | first choice | backup | never |
|---|---|---|---|
| one-liner / config / rename | haiku, qwenlocal | glm | opus, fable |
| single file, sealed acceptance | flash | glm, kimi | fable |
| multi-file bounded feature | sonnet, flash | dspro | qwenlocal |
| repo-wide sweep / census | opus, flash | dspro | qwenlocal (measured DNF) |
| whole-sprint console | dspro (hypothesis), opus | sonnet, flash | qwenlocal, haiku |
| gate verification / holistic review / adjudication | fable, opus | sonnet | haiku (fabrication gate) |

---

## 4. How these ladders die

1. Every line above is a **prior for the race queue** (`measurement-methodology.md` §7): race #1
   already moved the T-A ladder; race #2 targets implementation-bounded; race #3 targets the
   fable/dspro spec gap; race #4 targets the console ladder. A race result replaces the line —
   append the correction here dated, don't argue with it.
2. The two all-guess dimensions (`thoroughness`, `citation_honesty` for most of the roster) are
   the cheapest place a race can embarrass this file. Good.
3. If a ladder here starts being *quoted as evidence*, that is a defect in the quoter: the stamp
   at the top is the whole point. Priors route exploration; measurements route dispatch.
