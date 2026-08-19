# Auditor independence — is it about the model, or about the context?

**Task:** T471 · **Role:** worker · **Model:** deepseek-v4-pro · **Date:** 2026-08-19
**Status:** research ruling recommendation (operator rules; this document does NOT change
`docs/infra/bakeoff.md`).

## TL;DR

The evidence settles the *structure* of the question and leaves only the *magnitude* open.

- **Independence is a property of the model (weights), not of the context (session).** The
  self-preference / family-preference literature measures bias that lives in the model's learned
  distribution — recognition of its own style, lower perplexity on its own style, correlated
  preferences shared within a family. None of these are context-window state. A "fresh instance" of
  the same model is byte-identical weights, so it carries the **same** bias.
- **"Fresh-instance independence" is a category error, not an open question.** In every paper that
  measures self-preference, "same model" already means "same model type / weights," not "same chat
  session." The papers compare model-to-model, never session-to-session. The operator's hypothesis
  ("a fresh instance shares no conversation, so it is independent") misidentifies what the
  literature's "same model" category is. The independence unit is the weights, and a fresh instance
  has the same weights.
- **The project is citing one claim while applying the other — exactly as the brief suspected.**
  `bakeoff.md` §3.6 cites Zheng et al. 2023 for *family* exclusion, but Zheng et al. 2023 measures
  *self*-preference (identity), and is itself **agnostic** about whether the effect exists ("our
  study cannot determine whether the models exhibit a self-enhancement bias"). The *family* effect
  is measured by different, later papers (Spiliopoulou et al. 2025; Li et al. 2025).
- **Recommended ruling: keep family exclusion for scored races; relax it for audits — but relax it
  to "different model within a family is acceptable," never to "same model, fresh instance."**
  Rationale in §6.

---

## 1. The question, restated

`docs/infra/bakeoff.md` §3.6 requires **family exclusion**: *"an LLM grader must not share a model
family with any lane it grades (self-preference bias — Zheng et al. 2023)."* The project applies
this to audits as well as to graded races.

The operator's challenge: **is the requirement about the model, or about the context?** A fresh
instance of the *same* model shares no conversation, no reasoning chain, and no memory. If
independence comes from absent shared context, then same-model-fresh-instance is a valid auditor and
the family rule costs capability for no gain. If independence requires a different model, the rule
is right.

Three sub-claims, which the literature actually distinguishes:

1. **Identity** — a model prefers outputs it generated (its own weights produced them).
2. **Family** — a model prefers outputs stylistically like its own / from its training lineage.
3. **Detectability** — a model prefers text it can *recognize* as its own.

These call for different rules, and the project has been citing one (identity, Zheng 2023) while
applying another (family exclusion).

---

## 2. What the cited source actually measures

**Zheng et al. 2023** (the §3.6 citation) measured **identity**, and found it **inconclusive**.

From §3.3 "Self-enhancement bias" (emphasis added):

> "Compared to humans, we do observe that some judges favor certain models. For example, GPT-4
> favors itself with a 10% higher win rate; Claude-v1 favors itself with a 25% higher win rate.
> However, they also favor other models and GPT-3.5 does not favor itself. **Due to limited data
> and small differences, our study cannot determine whether the models exhibit a self-enhancement
> bias.** Conducting a controlled study is challenging because we cannot easily rephrase a response
> to fit the style of another model without changing the quality."

So: the foundational citation (a) is about a model grading **its own outputs** (identity), not about
grading outputs from a *family member*, and (b) declines to conclude the effect is real. It is a
weak foundation for a hard family-exclusion rule. The rule is not *wrong* — the family effect is
real and measured elsewhere (§3, §5) — but the citation does not support what it is cited for.

---

## 3. What the follow-up literature measures

The follow-ups separate identity, family, and detectability, and converge on a mechanism.

### 3.1 Detectability — recognition correlates with preference

**Panickssery et al. 2024** ("LLM Evaluators Recognize and Favor Their Own Generations," NeurIPS
2024) is the key identity+detectability result. It found a **linear correlation between a model's
self-recognition ability and the strength of its self-preference**: models that are better at
recognizing their own outputs are more likely to favor them when grading. The bias operates through
*recognition of the self's own style*, not through any shared conversation or reasoning chain.

Note what this implies for the brief's question: recognition is a *weights* capability. A fresh
instance of the same model has identical recognition ability, because recognition of "my own style"
is a function of the learned distribution, not of anything the instance has seen in this session.

### 3.2 Familiarity — the bias is a perplexity / stylistic effect, not a context effect

**Wataoka et al. 2024** ("Self-Preference Bias in LLM-as-a-Judge") measured the effect on eight
models and found GPT-4 showed the strongest self-preference (Equal-Opportunity bias 0.52;
Demographic-Parity bias 0.749). The mechanism finding is the load-bearing one:

> "LLMs assign significantly higher evaluations to texts with lower perplexity than human
> evaluators, **regardless of whether the texts were self-generated**. This suggests that the
> essence of the bias lies in perplexity and that the self-preference bias exists because LLMs
> prefer texts more familiar to them."

Perplexity is computed from the model's weights against the text; it is identical across instances
of the same model. A fresh instance is no less "familiar with" the producer's style than the
producer itself is. This is direct evidence against the "fresh context removes the bias" hypothesis:
the bias is a *weights-level* preference for familiar style.

### 3.3 Family — real, but smaller than identity, and not universal

**Li et al. 2025** ("Preference Leakage: A Contamination Problem in LLM-as-a-judge") defined three
relatednesses between generator and judge — same model, inheritance, same family — and measured a
"preference leakage score" for each (average over Arena-Hard + AlpacaEval 2.0):

| relatedness | leakage |
|---|---|
| same model | 23.6% |
| inheritance (same ins. / diff ins.) | 19.3% / 22.3% |
| same family, same series | 8.9% |
| same family, different series | 2.8% |

Two things matter. (1) The family effect is **real** — a judge from the same family as the
generator inflates scores even when the generator is a *different model instance* (e.g. GPT-4o
generating, GPT-4-turbo judging). (2) It is **much smaller** than same-model, and it decays with
distance (same series 8.9% → different series 2.8%). Also: judges **cannot recognize** their
students' outputs (recognition accuracy ≈ random) yet still leak preference, so the bias flows
through "spurious features (style, format, wording)" rather than conscious detection — again a
weights-level property.

**Spiliopoulou et al. 2025** ("Play Favorites") is the most statistically careful measurement to
date (regression controlling for an independent human reference score). It found **both** self-bias
and family-bias, but **not universally**: "GPT-4o and Claude 3.5 Sonnet systematically assign higher
scores to their own outputs"; "Claude and GPT judges tend to give higher scores to completions of
other models within the same family"; "**Llama and Mistral models do not exhibit such bias.**" The
magnitudes are small in absolute score terms — "a score difference of just 0.02 is comparable to the
magnitude of the observed self-bias" — but they matter when all models cluster near the top of the
scale, which is exactly the scored-race setting.

### 3.4 Same-model self-review amplifies bias — the self-refinement evidence

The brief asked specifically about self-refine / self-critique as a proxy for "same-model
fresh-instance review." The relevant result is **Xu et al. 2024** ("Pride and Prejudice: LLM
Amplifies Self-bias in Self-refinement," ACL 2024): when a model uses its *own* feedback to refine
its *own* output, it **amplifies** its self-bias rather than correcting it. If a fresh instance of
the same model were a neutral reviewer, self-refinement would be a clean improvement loop; instead
the model's own evaluations are systematically biased in its own favour and the iteration compounds
it. This is the closest the literature comes to a direct test of "same model reviewing its own
work," and it comes out against independence.

---

## 4. The answer: independence is about the model, not the context

The mechanism across all of §3 is consistent and points one way: the bias lives in **weights**, not
in **context**.

- Recognition of "my style" (Panickssery) is a weights capability.
- Familiarity / low perplexity (Wataoka) is a weights function of the text.
- Same-family correlated preferences (Li, Spiliopoulou) come from shared architecture and training
  data — i.e. weights.

None of these are state that a "fresh instance" would lack. A fresh instance is the same weights,
the same recognition ability, the same perplexity landscape, the same stylistic priors. **A fresh
instance of the same model is the same evaluator.**

The operator's framing misidentifies the independence unit. "Same model" in the literature already
means "same model type / weights," because the papers compare model-to-model (does judge J favor
outputs of model J?) — they never distinguish session-to-session, because that distinction is
epistemically empty: sessions don't change the weights. So "same-model-fresh-instance" is **not a
new category**; it is the exact "same model" category the self-preference literature measures as the
strongest bias.

### The human code-review analogy, and where it breaks

The brief notes that human review requires a different *person*, not a different *person-type*. The
analogy actually **supports** model-level exclusion, once the units are mapped correctly:

- A human's "weights" (expertise, blind spots, priors) differ per person. A **different person** is
  a genuinely different evaluator. The LLM analogue of "a different person" is **a different model
  (different weights)** — not a fresh instance.
- A "fresh instance of the same model" has **no human analogue**, because a person cannot be a
  byte-identical fresh copy of themselves with unchanged priors and unchanged blind spots. The
  closest human analogue is *asking the same person to re-read their own work later* — which nobody
  treats as independent review, precisely because the blind spots are in the person, not in the
  reading session.

Where it breaks: humans genuinely change over time and forget; LLM weights do not change between
instances, so the LLM case is *more* rigid than the human case. The "different person" requirement
bites *harder*, not softer, for LLMs.

---

## 5. Effect sizes, and how solid they are

| effect | size | source | confidence |
|---|---|---|---|
| same-model (identity) | GPT-4 +10%, Claude-v1 +25% win rate; GPT-4 Equal-Opp 0.52; same-model leakage 23.6% | Zheng 2023; Wataoka 2024; Li 2025 | real, but Zheng itself flagged inconclusiveness |
| family, same series | 8.9% leakage | Li 2025 | real, moderate |
| family, different series | 2.8% leakage | Li 2025 | small |
| family (score regression) | ≈0.02 score units, GPT/Claude only | Spiliopoulou 2025 | small but ranking-relevant |
| whole effect | ~89.6% of *measured* self-preference is a measurement artifact | Roytburg et al. 2026 | the entire prior literature is being walked back |

Three caveats keep these from being "settled, large":

1. **Much of it is legitimate, not bias.** **Chen et al. 2025** ("Do LLM Evaluators Prefer
   Themselves for a Reason?") ran the cleanest design yet — verifiable tasks with objective
   ground truth — and found that strong models' self-preference is *mostly* the model correctly
   recognizing its own genuinely better output ("better generators are better judges"). The
   *harmful* part (favoring its own output when it is objectively wrong) is real and larger in
   stronger models, but much of what earlier papers called bias is just capability.
2. **A large fraction is measurement artifact.** **Roytburg et al. 2026** ("Are LLM Evaluators
   Really Narcissists?", preprint) reproduced four landmark self-preference pipelines with an
   added control group (judge evaluating a capability-matched *proxy* output instead of its own)
   and found that evaluator uncertainty on hard problems — not self-recognition — explains an
   average of **89.6%** of measured self-preference; only ~51% of original findings retain
   statistical significance, and only ~10.4% exceed the control baseline. The effect is real but
   far smaller and more task-dependent than the headline numbers suggest.
3. **Family bias is not universal.** Llama and Mistral families show no family bias (Spiliopoulou
   2025); different-series family leakage is ~2.8% (Li 2025).

**Net effect-size conclusion for this project:** the bias is real, is a *model/weights* property,
and is **largest for same-model (identity)**, **small-to-moderate for same-family**, and **smaller
than the early literature claimed**. For a *scored race* where lanes cluster within a few points,
even the small family bias can flip ranks. For an *audit* — where the question is "does this
specific claim's evidence check out / does this code path have a defect" — a small stylistic
preference is far less likely to flip a pass/fail verdict, and the project's audit standards are
already heavy (independent re-implementation, verify-then-promote, two seats).

---

## 6. Ruling recommendation

**Keep family exclusion for scored races; relax it for audits — but relax it to "different model,"
never to "same model, fresh instance."**

Concretely:

- **Scored races:** keep §3.6 as written (family exclusion). This is the setting where the evidence
  is strongest (Spiliopoulou 2025: family bias matters when scores cluster near the top) and where a
  few-point bias flips a ranking. The cited rationale should be *re-pointed* from Zheng et al. 2023
  (identity, inconclusive) to Spiliopoulou et al. 2025 and Li et al. 2025 (family, measured) — that
  is a citation fix the operator can make in `bakeoff.md` §3.6, not a rule change.
- **Audits:** relax family exclusion to **model exclusion**. An auditor may share a *family* with
  the producer (different model within the family) but must **not** be the *same model*, fresh
  instance or not. The family effect is small (2.8–8.9%) and partly legitimate/artifact; the
  same-model effect is the strongest and most robust (23.6%), and the "fresh instance is
  independent" intuition is directly contradicted by the mechanism evidence (§4) and by the
  self-refinement amplification result (§3.4).
- **Never treat "same model, fresh instance" as independence.** That is the one reading the
  literature rules out, not leaves open. A fresh instance is the same weights and therefore the
  same evaluator; the independence unit is the weights.

The asymmetry is defensible because the *mechanism* is the same in both settings but the *stakes*
differ: a small stylistic preference is a ranking error in a race and a near-nullity in a
pass/fail audit of a specific defect, especially under this project's already-mandatory second-seat
/ independent-re-implementation gates.

---

## 7. Where the literature is thin — mark these UNKNOWN

A recorded "the evidence does not settle this" is a successful outcome. Three such places:

1. **No paper directly tests "fresh context" as a variable.** §4's conclusion is an *inference from
   mechanism* (recognition, perplexity, weights-level features), not a direct experiment that held
   the model constant and varied only session state. The inference is strong — every mechanism
   identified is weights-level — but it is an inference. **UNKNOWN as a direct measurement; strong
   as an inference.** The project can close this cheaply (§8).
2. **The whole self-preference literature is currently being walked back.** Roytburg et al. 2026
   claims ~89.6% of measured self-preference is artifact; it is a fresh preprint, unreplicated.
   **The true magnitude is UNKNOWN and contested.** What survives every paper is the *direction*
   (same-model > family > unrelated) and the *locus* (weights, not context); magnitudes are
   uncertain.
3. **Audit-shaped tasks (defect-finding, evidence-checking) have no dedicated measurement.** Every
   paper above grades *quality/preference* (summaries, chat, math, code). Whether the self/family
   bias transfers to a *verification* task — "does this proof/claim check out" — is **UNKNOWN**.
   This is the gap most relevant to the audit half of the ruling, and it is the cheapest to test
   locally (§8).

---

## 8. What it would cost this project to test locally

The brief's bar: eight models and a sealed-key race harness, so a same-model-vs-different-model
grading comparison is "a run, not a theory." Concretely:

1. **The fresh-context question (settles §7.1).** Take N sealed-key task outputs. Grade each twice
   with the *same* model in two fresh sessions (the harness's `--no-session` / per-lane process
   isolation already gives fresh context), and once with a *different-family* model. Compare
   verdicts against the sealed key. If same-model-fresh-instance agreement with the key matches
   different-model agreement, the "fresh context" hypothesis gains support; if same-model inflates
   its own family's scores, it fails. Cost: a few dozen grade calls — one bakeoff run, minutes of
   wall time.
2. **The audit-shaped question (settles §7.3, the part the literature lacks).** Build a small
   seeded-defect audit set (the bakeoff harness's §3.6 grader-validity controls already do
   seeded-defect ranking). Have a same-model auditor and a different-family auditor hunt the
   seeded defect. Cost: one bakeoff run with a defect-seeded key — the machinery exists.
3. **The family-bias magnitude (settles the relax-for-audits step).** A three-grader comparison —
   same-model, same-family-different-model, different-family — over one sealed-key task set, using
   `tools/bakeoff.sh`. This is the single run that would empirically justify (or overturn) §6's
   "different model, not different family" threshold for audits. Cost: ~8 lanes × one task, a small
   wall-clock and token spend.

None of these requires new tooling; all three are bounded bakeoff runs. The recommendation in §6 is
the defensible prior; these runs are the cheap falsification.

---

## References

- **Zheng, Lianmin; Chiang, Wei-Lin; Sheng, Ying; Zhuang, Siyuan; Wu, Zhanghao; Zhuang, Yonghao;
  Lin, Zi; Li, Zhuohan; Li, Dacheng; Xing, Eric P.; Zhang, Hao; Gonzalez, Joseph E.; Stoica, Ion.**
  "Judging LLM-as-a-Judge with MT-Bench and Chatbot Arena." NeurIPS 2023 (Datasets and Benchmarks).
  arXiv:2306.05685. https://arxiv.org/abs/2306.05685 — *self-enhancement (identity); inconclusive.*
- **Panickssery, Arjun; Bowman, Samuel R.; Feng, Shi.** "LLM Evaluators Recognize and Favor Their
  Own Generations." NeurIPS 2024. arXiv:2404.13076. https://arxiv.org/abs/2404.13076 —
  *self-recognition ↔ self-preference correlation (detectability).*
- **Wataoka, Koki; Takahashi, Tsubasa; Ri, Ryokan.** "Self-Preference Bias in LLM-as-a-Judge."
  NeurIPS 2023 Safe Generative AI Workshop, 2024. arXiv:2410.21819. https://arxiv.org/abs/2410.21819
  — *bias tracks perplexity/familiarity; weights-level mechanism.*
- **Xu, Wenda; Zhu, Guanglei; Zhao, Xuandong; Pan, Liangming; Li, Lei; Wang, William Yang.**
  "Pride and Prejudice: LLM Amplifies Self-bias in Self-refinement." ACL 2024.
  arXiv:2402.11436. https://arxiv.org/abs/2402.11436 — *self-refinement amplifies self-bias.*
- **Li, Dawei; Sun, Renliang; Huang, Yue; Zhong, Ming; Jiang, Bohan; Han, Jiawei; Zhang,
  Xiangliang; Wang, Wei; Liu, Huan.** "Preference Leakage: A Contamination Problem in
  LLM-as-a-judge." arXiv:2502.01534. https://arxiv.org/abs/2502.01534 — *same-model / inheritance /
  family relatedness quantified.*
- **Spiliopoulou, Evangelia; Fogliato, Riccardo; Burnsky, Hanna; Soliman, Tamer; Ma, Jie;
  Horwood, Graham; Ballesteros, Miguel.** "Play Favorites: A Statistical Method to Measure
  Self-Bias in LLM-as-a-Judge." arXiv:2508.06709. https://arxiv.org/abs/2508.06709 — *self-bias AND
  family-bias via regression with human reference; GPT/Claude show family bias, Llama/Mistral do
  not.*
- **Chen, Wei-Lin; Wei, Zhepei; Zhu, Xinyu; Feng, Shi; Meng, Yu.** "Do LLM Evaluators Prefer
  Themselves for a Reason?" arXiv:2504.03846. https://arxiv.org/abs/2504.03846 — *much self-preference
  is legitimate; harmful part persists when the model errs; long CoT mitigates.*
- **Roytburg, Dani; Bozoukov, Matthew; Nguyen, Matthew; Barzdukas, Jou; Puig-Hall, Mackenzie;
  Oozeer, Narmeen.** "Are LLM Evaluators Really Narcissists? Sanity Checking Self-Preference
  Evaluations." arXiv:2601.22548 (preprint, under review). https://arxiv.org/abs/2601.22548 —
  *~89.6% of measured self-preference is an evaluator-uncertainty artifact; replication/walk-back.*
