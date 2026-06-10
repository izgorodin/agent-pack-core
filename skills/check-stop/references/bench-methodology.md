# Bench methodology

> **⚠️ Synced copy — do not edit in place.** This file is bundled **verbatim** in more than one skill (`bench-spec-author`, `check-stop`) because Claude Code resolves bundled `references/` relative to each skill's own directory. The copies are kept **byte-identical** — their `md5sum` must match. Any change must land in **all** copies in the same commit, or none; a lone edit silently desynchronizes the methodology. The intentional duplication (functional resolution over DRY) is the supported mechanism; do not collapse it to a single path without confirming the harness resolves it from every consuming skill.

**Status: pilot v0.8.** Not "approved for production". 3 blocking operational issues, found in a council-review, were fixed in fix-pass-3 — but validation is still incomplete: §8.1/§8.2 not executed, §8.3 was non-blind. Ready for **first real application**, which is itself the real §8.3 test. Methodology version that bench-specs reference: `0.8`.

Methodology for forming and validating bench-specs for research projects under a three-layer agent architecture.

Bench-spec template — [`./bench-spec.template.md`](./bench-spec.template.md).

---

## 1. Purpose and context

A bench-spec is a locked specification of a measurement for a research project. It exists BEFORE the work starts. It protects against **goal drift** — the gradual sliding of the target function toward a convenient result.

The idea grows out of two traditions:

- **BDD/TDD** in software: the test specification exists before implementation, is an executable contract, protects against drift. ([Beck 2002](https://dl.acm.org/doi/10.5555/579193), [North 2006](https://dannorth.net/introducing-bdd/) `[uncertain — page bot-blocked, secondary-verified]`).
- **Pre-registration** in psychology/clinical: hypotheses and analysis plan are fixed before data collection. Protects against HARKing and selective reporting ([Chambers 2013](https://pubmed.ncbi.nlm.nih.gov/23347556/); [OSF Registrations](https://help.osf.io/article/330-welcome-to-registrations)).

For **research-with-agents** neither tradition works directly: software pass/fail is binary, but research outputs are distributions; pre-registration assumes a multi-week timeline, but agent runs are minute-scale. This methodology synthesizes what is portable and explicitly describes what has to be invented.

---

## 2. Where the bench layer sits in the three-layer construction

Bench (L1) is the external anchor. It does not explain how to do work (L3), nor enforce how work is stored (L2). Bench answers one question: **"what counts as success?"** — and fixes the answer before the answers can be tuned.

Without L1 the two remaining layers become theatre:

- L2 (guards) gives rigorous hygiene around a fundamentally undefined question.
- L3 (creative agents) gives tools to explore without a way to know whether anything was found.

Bench is not cheap. The cost is a fixed day-of-work on formulation before each project. It pays off because 200 hypotheses in a season become distinguishable from one another, and you can say which of them actually moved the target.

---

## 3. Five cross-cutting principles

**The triangulation standard is a goal, not yet achieved.** The ideal: each principle is grounded in **≥2 independent intellectual lineages**, at least one **outside ML benchmark engineering**. Citation-clustering (BIG-bench / HELM / MTEB / NeurIPS reproducibility share authors, institutions, and a common ML credibility-revolution framing) is not triangulation.

**The current reality, honestly:** not all five principles meet this standard. Some lean predominantly on the ML benchmark engineering lineage. This is not "already triangulated" — it is a **declared target** the methodology moves toward. A per-principle audit of "how many independent lineages really" is still open.

Lineages the methodology refers to:

- **Software engineering** (BDD/TDD: Beck 2002, North 2006, Gherkin)
- **Clinical/psychological pre-registration** (OSF, Registered Reports, Chambers 2013, Bem-Ritchie replication case)
- **ML benchmark engineering** (BIG-bench, HELM, MTEB, NeurIPS Checklist) — *single lineage despite multiple sources*
- **Psychometric construct validity** (Cronbach & Meehl 1955, Messick 1989/1995, Campbell & Fiske 1959)
- **Goodhart taxonomy / alignment theory** (Manheim & Garrabrant 2018, Gao et al. 2022, Pan et al. 2022)

### 3.1. Pre-commitment before work starts

**Principle.** What we will use to judge the result is fixed BEFORE the result is obtained. The frozen artifact is not a "hypothesis" but a **decision rule**: a rule mapping observed numbers to a conclusion.

**Sources.** BDD `Given/When/Then` ([Gherkin](https://cucumber.io/docs/gherkin/reference/)); OSF Registrations form immutability; HELM's pre-specified (scenario × metric) matrix ([arXiv:2211.09110](https://arxiv.org/abs/2211.09110)).

**In the template.** Lock mechanics (frontmatter `status`, `locked_at_utc`, `lock_tag` — a git tag, not a self-referential commit hash; see template "Lock mechanics"); section 4 "Acceptance criteria" with a pre-registered shape band; section 9 "Confirmatory commitments" with a pre-registered analysis list.

**Failure mode addressed.** Canonical case — Bem 2011 "Feeling the Future" ([DOI 10.1037/a0021524](https://doi.org/10.1037/a0021524)): **9 experiments on precognition, 8 of 9 showed a significant effect** (Experiment 7 — null). Three pre-registered replications ([Ritchie, Wiseman & French 2012 DOI 10.1371/journal.pone.0033423](https://doi.org/10.1371/journal.pone.0033423)) returned null. This is a motivating case for the credibility revolution. *(The citation went through three iterations: the original "9 of 10 experiments" is a common mis-paraphrase; the intermediate "9 of 10 tests" was also inexact; a council-review with models that know the paper converged on 8 of 9 experiments significant.)*

### 3.2. Irreducibility to a single number

**Principle.** Single-number leaderboards hide trade-offs. Acceptance is a primary metric + ≥2 guardrail metrics. Each guardrail is an **individual constraint**: **any** violation of even one guardrail blocks `win` (not "regressed simultaneously" — that was loose wording; aligned with template §4 verdict logic).

**Sources.** HELM (7 metrics × 16 scenarios, 87.5% coverage); MTEB (8 task families, not a count of datasets; [arXiv:2210.07316](https://arxiv.org/abs/2210.07316)); construct validity (convergent + discriminant + nomological — three dimensions, not one).

**In the template.** Section 4: "Primary metric" + "Guardrail metrics" table. Section 6: "Convergent-Discriminant Matrix" for proxy cases.

**Failure mode addressed.** Single-score optimization that improves accuracy 3% at the cost of regressing toxicity 8% — a "win" on the leaderboard, actually a failure.

### 3.3. Machine-checkable, not descriptive

**Principle.** Acceptance criteria and validation are executed by a script, not self-graded by the author. Artifacts are identified by hashes and commit IDs, not by prose description.

**Sources.** BDD `Then` clause as a machine-checkable assertion; NeurIPS Reproducibility Checklist + its documented gameability ([arXiv:2411.03417](https://arxiv.org/html/2411.03417v1) — an LLM attacker bypasses an LLM verifier by rewriting justifications without changing the paper); OSF Registrations immutability through a hash.

**In the template.** Section 3 "Measurement procedure": eval script + commit hash, not a description of the procedure. Section 9: results artifact must cite `id` + `lock_tag`. Lock mechanics: **git tag** as the primitive — not a self-referential commit hash. A file cannot contain the sha of the commit that contains it; the lock is a git tag `bench-NNNN-locked` placed on the commit where `status` became `locked`. The sha resolves via `git rev-list -n1 <lock_tag>`, it is not stored in the file.

**Failure mode addressed.** Justification-paragraph compliance: a rigorous sound, zero content. Documented on NeurIPS checklists.

### 3.4. Separation of confirmatory from exploratory

**Principle.** What was pre-registered is reported separately from what was found along the way. Exploratory results never count as a victory under any circumstances.

**Sources.** Registered Reports Stage 1/2 — confirmatory vs exploratory split forced typographically ([Chambers 2013](https://pubmed.ncbi.nlm.nih.gov/23347556/)); Gao et al. ([arXiv:2210.10760](https://arxiv.org/abs/2210.10760)) — proxy reward keeps rising while gold reward peaks then drops, without an external check only the proxy is visible.

**In the template.** Section 9: confirmatory analyses list + reserved exploratory section in results.

**Failure mode addressed.** HARKing (Hypothesizing After Results Known) and selective reporting. In ML form — "re-roll seeds and publish the best". Without separation these results are indistinguishable from confirmatory.

### 3.5. A replacement protocol is required

**Principle.** A bench eventually goes stale. Retirement conditions are defined before the moment you want to retire it.

**Sources.** Papers with Code shutdown by Meta 2025-07-24 — empirical proof that infrastructure dependencies disappear unexpectedly. NeurIPS Checklist Assistant — proof that metrics are gameable and over time require revision.

**In the template.** Section 8 "Replacement protocol": retirement conditions, versioning, what is frozen forever.

**Caveat about "frozen forever".** Git commit hashes freeze source code, not runtime behavior. A pinned `uv.lock` may stop resolving (yanked packages, deprecated CUDA, removed checkpoints). Bitwise reproducibility across years on a GPU is unrealistic. Bench-specs must distinguish **three tiers** (see template §8): (a) **conventional immutability** — a plain git tag + convention; a tag is a movable ref, held by discipline, not cryptographically prevented; (b) **cryptographic immutability** — opt-in: a signed tag (`git tag -s`) on a protected ref, only then is tampering detectable+blocked; (c) **executable replay** — depends on external infra, best-effort with a graceful-degradation policy. "Full guarantee" is only tier (b), and only if enabled.

**Failure mode addressed.** The implicit assumption that the current bench will be valid indefinitely. When it stops being valid — nothing is frozen, there is no migration contract.

---

## 4. Three classes of bench

The literature treats benchmarks homogeneously. Experience shows that three distinct classes require different safeguards.

**Class is about your relationship to the measurement, not about the nature of the benchmark.** The same public benchmark can be `adopted` or `proxy` — it depends on what you claim. You report "MMLU score" and the score itself IS your target → adopted. You use the MMLU score as a stand-in for an unobservable construct you actually care about ("the model's knowledge") → proxy, and you owe §6, even though the benchmark is public. Decision question: *"Am I measuring the benchmark's declared target, or using it as a stand-in for something unobservable?"* — first → adopted (or constructed if it's your own observable target); second → proxy. "Pick exactly one" is resolved by this question, not by the benchmark's nature.

### 4.1. Adopted

**What.** A public benchmark with a maintained test set and eval harness — GLUE, SuperGLUE, MTEB suite, HELM scenarios.

**When to choose.** When the project target overlaps with an already peer-validated target.

**Minimal requirements (template fields):**

- Section 1 Target: precise — which task we solve from the adopted benchmark.
- Section 3 Measurement: the exact benchmark version (commit/release), eval script pinned.
- Section 4 Acceptance criteria: a decision rule, not "above baseline".
- Section 5 Anti-Goodhart: explicitly — which Manheim variants apply.
- Section 7 Contamination: recommended. Public benchmarks are often contaminated (BIG-bench canary leaked into GPT-4, Claude 3.5, Gemini — [Alignment Forum analysis](https://www.alignmentforum.org/posts/kSmHMoaLKGcGgyWzs/big-bench-canary-contamination-in-gpt-4)).
- Section 8 Replacement: what we do if the benchmark host disappears (PwC scenario).

**What is NOT required for adopted.** Section 6 Proxy validity (N/A — target is measured directly).

**Failure mode characteristic of the class.** Contamination. Public bench → large models have seen it.

### 4.2. Constructed

**What.** Your own benchmark with your own splits. The test set is formed for the project's unique target.

**When to choose.** When there is no public benchmark for the target, but the target is still measured directly (not a proxy).

**Minimal requirements:**

- Everything for adopted.
- Section 7 Contamination: **mandatory**. Your own canary GUID, do not reuse a public one.
- Section 1 Target: additionally — the dataset provenance (where the data came from, who annotated, which edge cases).
- Section 3 Measurement: held-out seal mechanics — hash + timestamp + access control. Who had access before the lock.

**Failure mode characteristic of the class.** Construct underrepresentation — the splits don't cover what we say they cover. Mitigation — task-family diversity per MTEB (≥2 task families for the same construct).

### 4.3. Proxy

**What.** A measurable approximation for an open-ended construct. Linear decodability as a proxy for a latent semantic-structure construct, embedding clustering as a proxy for concept structure, multiple-choice accuracy as a proxy for understanding.

**When to choose.** When the target does not reduce to a direct measurement.

**Minimal requirements — two independent axes.** The prior formulation "everything for constructed" was wrong: a public benchmark used as a proxy physically cannot have its own held-out splits. Proxy-class requirements assemble from **two axes** — claim type and measurement source — independently:

- **Claim type = proxy** → **always**: section 6 Proxy validity (Convergent-Discriminant Matrix, nomological predictions, falsification rule) + section 5 Anti-Goodhart in detail (all 4 Manheim variants). This is a requirement of the claim, not of the data source.
- **Measurement source = own dataset** → plus constructed requirements: own held-out splits, own canary GUID, provenance, held-out seal mechanics.
- **Measurement source = public benchmark** → plus adopted requirements: the exact benchmark version, contamination protocol for the public bench, replacement protocol in case the host disappears. **Own held-out splits are not required** — by definition there are none.

Example: MMLU score as a proxy for "the model's knowledge" = proxy-claim requirements (§6 + §5) + adopted-source requirements (version, contamination). Not "own held-out splits".

**Failure mode characteristic of the class.** Construct-irrelevant variance ([Messick 1995, p. 742, DOI 10.1037/0003-066X.50.9.741](https://doi.org/10.1037/0003-066X.50.9.741) `[uncertain page — variance among sources between 13–103 and 13–104]`). The ML analog is well documented — the probing literature regularly finds probe accuracy driven by surface features ([Belinkov 2022 DOI 10.1162/coli_a_00422](https://aclanthology.org/2022.cl-1.7/)).

This is the riskiest class. Most latent-construct experiments are proxies. Most interpretability research is a proxy. It needs the strictest safeguards.

### 4.4. Boundary case — constructed vs proxy

The boundary between constructed and proxy is not sharp when a project has its own held-out data on an open-ended construct.

**Rule of thumb:** "Can a third party look at your data and **directly** verify construct presence?"

- **Yes** (e.g. "is this passage about cats?" — yes/no observable) → **constructed**, even if the splits are your own.
- **No** (e.g. "does this embedding encode a latent semantic-structure axis?" — there is no oracle that returns ground truth) → **proxy**, even if the held-out is entirely your own.

If the construct **cannot be observed directly**, any measurable approximation is a proxy. Own annotation + own splits do not turn a proxy into constructed; they just mean you have a custom proxy.

Concretely, for a latent semantic-structure target: held-out passages annotated by a round of 3 raters are constructed-style data. But the construct ("frozen embeddings encode a continuous latent semantic-structure axis") cannot be directly observed — annotators approximate it through rated levels. Therefore the class is **proxy**, with all of §6's requirements.

---

## 5. Proxy class — separate depth

### 5.1. Construct validity for ML proxies

Cronbach and Meehl ([Cronbach & Meehl 1955](https://meehl.umn.edu/sites/meehl.umn.edu/files/files/036constructvalidityidx.pdf), *Psychological Bulletin* 52(4): 281–302) formalized validity for psychological tests. Messick (1989, 1995) unified it into a single framework. Three mechanics transfer to ML.

**Critical correction (fix-pass-3): you cannot correlate the proxy with the construct itself.** If the construct is openly observable, no proxy is needed — measure it directly. If the construct is **not** observable (proxy class by definition §4.3), then there is no ground-truth column to compute ρ against. Campbell-Fiske MTMM solves exactly this: correlations are computed **between operationalizations**, never with the latent trait. The prior formulation "Cell (proxy, target) → ρ" was circular and is corrected here.

**Convergent validity.** ≥2 *independently constructed* operationalizations of one construct must correlate **with each other**. If they measure the same thing, they agree.

In the bench-spec: ≥2 row-operationalizations in the Convergent-Discriminant Matrix. Convergent cells are **pairwise** ρ between operationalizations (off-diagonal among operationalizations), a pre-registered minimum. There is no "target" column.

**Discriminant validity.** Each operationalization must NOT strongly correlate with confound constructs it should not be measuring.

In the bench-spec: columns "confound_1", "confound_2". Cells → maximum |ρ| pre-registered. Discriminant ρ must be materially lower than the convergent ρ between operationalizations.

**Optional — criterion column.** If an *independent observable* criterion variable exists (not the construct itself, but something observable that the construct should predict), it can be added as a column. This is criterion validity, not "correlation with the construct". For purely latent constructs the criterion column is often absent — and that is fine, convergent among operationalizations carries the main load.

**Nomological network.** The proxy obeys predicted directional relations to upstream/downstream variables.

In the bench-spec: ≥3 sign-and-direction predictions, each with a pre-registered minimum effect size + equivalence bound (see §5.4).

**Ratio guideline (project convention, not a Campbell-Fiske attribution).** Campbell & Fiske (1959) set only a *qualitative* criterion: convergent > discriminant, "significantly different from zero and sufficiently large". A numeric threshold (`2×`) is not theirs — it is later literature (Fornell-Larcker 1981 for SEM; HTMT cutoffs Henseler et al. 2015 ~0.85-0.90 for similarity, not a ratio).

In this methodology — **two conditions at once** (project convention, not a Campbell-Fiske rule):

1. **Absolute floor:** convergent ρ ≥ **0.50**. Without this the ratio is a math trap: 2 × 0.05 = 0.10 formally passes the ratio test but is statistically useless. A convergent correlation below 0.50 means the operationalizations fundamentally fail to agree — the proxy is not valid regardless of discriminant.
2. **Ratio:** convergent ρ ≥ 2× each discriminant |ρ|. If convergent = 0.55 and discriminant = 0.30 — ratio 1.83×, weak: pull convergent up or tighten discriminant to ≤0.25.

Both must hold. The author may override with explicit argumentation in §6 of the spec.

### 5.2. Goodhart taxonomy checklist

[Manheim & Garrabrant 2018](https://arxiv.org/abs/1803.04585) categorizes 4 variants. Bench-spec section 5 walks each.

- **Regressional.** Proxy = construct + noise; selection on the proxy partially selects on noise.
- **Extremal.** Proxy tracks construct in the typical range, diverges at the extremes where optimization moves.
- **Causal.** The proxy-construct correlation is not causal; intervention breaks it.
- **Adversarial.** The agent exploits the metric.

Empirical evidence that this is real:

- **Gao et al. 2022** ([arXiv:2210.10760](https://arxiv.org/abs/2210.10760)): functional scaling laws for the proxy-vs-gold reward gap. Proxy reward keeps rising, gold reward peaks then drops under deliberate optimization pressure. Most naturally interpreted as evidence for **Regressional Goodhart** (proxy = construct + estimation noise; optimization risks picking up noise). The authors do NOT test all 4 Manheim variants — it is an empirical case study of one divergence type, not confirmation of the whole taxonomy.
- **Pan, Bhatia & Steinhardt 2022** ([arXiv:2201.03544](https://arxiv.org/abs/2201.03544), ICLR 2022): phase transitions where agent behavior qualitatively shifts; catalog reward-hacking-style failures. Evidence for **Adversarial Goodhart** specifically.

**Important:** the Manheim-Garrabrant 4-variant taxonomy is a **categorical hygiene checklist**, not an empirically tested taxonomy. Causal and Regressional Goodhart as distinct empirical phenomena in the ML literature are weakly operationalized — we use all 4 as a checklist for completeness, not as a claim that each is independently observed.

### 5.3. Time-locked held-out set

A small-team analog of Gao et al.'s gold reward model: a sealed test set + tripwire. The bench-spec frontmatter contains `heldout_hash` (hash of the held-out splits) + `locked_at_utc`. Watch metrics in section 4 — guardrails that should not move in the wrong direction.

This is **necessary but not sufficient**. Pair it with adversarial test cases written by someone *outside* the optimization loop.

### 5.4. Falsification via effect sizes, not Holm-corrected p-values

**Problem with the prior formulation (fix-pass-3).** The prior rule — "failure of any single nomological prediction at p<0.05 retires the proxy" + Holm correction in §10 — is statistically inverted. Holm makes rejection *harder*; but here rejection (the prediction confirmed) is good, and non-rejection (the prediction failed) is what retires the proxy. Holm makes false retirement **easier**, not harder. The contradiction was known and left active — a blocking bug, fixed here.

**Correct construction — three prediction types.** Falsification is not NHST, and the rule **depends on what is predicted**. The prior formulation ("within equivalence bound = falsified") is correct only for directional predictions and contradicted invariance predictions. Three types:

**(A) Directional effect** — an effect of a definite sign is predicted.
Pre-register: expected sign, minimum effect size δ_min (the threshold "effect is real, not noise"), power ≥ 0.8 to detect δ_min.
*Confirmed:* effect CI excludes 0 in the predicted direction **and** the whole CI ≥ δ_min.
*Falsified:* sign wrong, OR effect CI wholly within ±δ_min at adequate power.
*Inconclusive:* CI straddles δ_min (lower bound < δ_min < upper bound) — the effect is not separated from the noise threshold. Neither confirmed nor falsified; needs a larger budget. Counts as neither a win nor a loss.

**(B) Equivalence / invariance** — the *absence* of an effect is predicted (the proxy should not react to X).
Pre-register: equivalence bound δ_eq (within = "practically zero"), falsification bound δ_max (beyond = "there is an effect"), power to detect δ_max.
*Confirmed:* |Δ| ≤ δ_eq (TOST or equivalent).
*Falsified:* |Δ| > δ_max (invariance was predicted — the proxy reacts).
*Inconclusive:* δ_eq < |Δ| ≤ δ_max — in the "gray zone" between "practically zero" and "clearly an effect". Neither confirmed nor falsified; needs either a larger budget or a revision of δ_eq/δ_max in a new spec.

**(C) Non-inferiority** — "not worse than X by margin δ" is predicted.
Pre-register: non-inferiority margin δ.
*Confirmed:* CI lower bound ≥ −δ.
*Falsified:* CI lower bound < −δ.

**General rule.** Any falsified prediction (of any type) retires the proxy. "Did not find the effect" under **inadequate power** is neither falsification nor confirmation — it is inconclusive (needs a larger budget). No raw p<0.05 on a point null.

**Holm correction** is appropriate **only** in the confirmatory context (§9) — controlling the family-wise error rate across multiple *significance claims*. In the falsification rule Holm is not used (it would invert the intent — see the start of the section).

---

## 6. What does NOT transfer from the source traditions

Honest limitations. Each is a place where this methodology has no analog in an existing solution.

**From BDD/TDD:**

- Binary pass/fail. Software acceptance is binary; research is distributional. Replacement — a pre-registered CI shape + seed budget.
- Cheap re-runs. TDD assumes a loop = seconds. Agent experiments — hours. Replace — fewer, higher-stakes checkpoints.
- HARKing analog. In software there is none — passing a test is passing. In research re-rolling seeds is possible, and BDD has no machinery against it.

**From pre-registration:**

- `p < 0.05` as a universal decision rule. ML rarely fits NHST. Replacement — a pre-declared decision rule on the primary metric: bootstrap CI excludes baseline by δ.
- The human-subjects timeline (weeks). Agent runs — minutes. Freeze mechanism — a git tag (by default conventional, i.e. honor-system + convention; cryptographic only with a signed tag on a protected ref — see template §8). A clean "not honor system" arrives only at the cryptographic tier, and self-policing/back-dating remains open (see the open question on cryptographic freeze).
- IRB enforcement. ML has no external enforcer. Enforcement is built into the methodology: the results artifact must cite the locked spec, otherwise it does not count.

**From benchmark engineering:**

- Large infrastructure (HELM's 16-scenarios × 7-metrics). A small team will not reproduce it. Replacement — 1 primary + 2-3 guardrails, not a 7×16 matrix.
- Canary prevention. BIG-bench canary is detection-only, and empirically leaked. Nothing to replace it with — you need a protocol "what to do on detected contamination".

---

## 7. Worked examples — sketch per class

Illustrative examples (not realizations), showing how the key fields are filled for each class.

### 7.1. Adopted — example sketch

A project adopts the MTEB retrieval suite for embedding evaluation.

```yaml
id: bench-0001
title: Embedding retrieval quality on MTEB v1.2.0 retrieval tasks
class: adopted
measurement_source: public
methodology_version: 0.8
status: locked
created: 2026-05-14
locked: 2026-05-15
locked_at_utc: 2026-05-15T09:00:00Z
lock_tag: bench-0001-locked
lock_tier: conventional
model_under_test: <pre-registered embedding model; e.g., "bge-large-en-v1.5 @ huggingface-revision-abc123">
heldout_hash: <release_id:hash, e.g., "mteb-v1.2.0:sha256-of-pinned-tarball">
peer_reviewer: <name — outside optimization loop>
supersedes: none
```

- **Target:** nDCG@10 averaged over MTEB v1.2.0 retrieval tasks (15 tasks). Construct: ability to rank semantically-related passages above unrelated ones. *(Construct here is directly measurable — relevance labels exist — so class=adopted, not proxy.)*
- **Measurement procedure:** `scripts/eval/mteb_retrieval.py @ a3f7c92`. MTEB pinned to v1.2.0. Seeds: [42, 137, 1729, 2718, 4096, 8191, 16384, 32768, 65537, 131071]. N=10 (per §10 default).
- **Acceptance criteria:** Primary = mean nDCG@10. Decision rule: two-level bootstrap 95% CI on **paired difference** (model − baseline) over N=10 seeds × eval items, excludes 0 + δ, δ=0.005. Baseline: pre-registered, locked reference embedding model (id + commit). Guardrails: per-task minimum (no task drops >5% rel), runtime per query (≤120% baseline).
- **Anti-Goodhart:** Regressional → two-level CI. Extremal → check on adversarial-distractor MS MARCO subset. Causal → N/A (no intervention). Adversarial → check on a novel out-of-MTEB retrieval task.
- **Proxy validity:** N/A (class=adopted).
- **Contamination:** MTEB v1.2.0 release date 2026-01-15. Detection: canonical-completion test on unique strings in MTEB tasks 4-6; embedding-only models — membership-style probe (perf on held-out vs matched novel). Action if detected: remove affected models from leaderboard, document.
- **Replacement:** retire when MTEB v2 released OR contamination detected OR target task family deprecated.

### 7.2. Constructed — example sketch

A project builds its own held-out for a task where the construct is **directly observable** — so class=constructed, not proxy (see §4.4 boundary rule). Example: identifying the programming language of a code snippet. Which language is directly verifiable ground truth (a `.py` file is Python), there is no latent construct.

```yaml
id: bench-0002
title: Programming-language identification — own held-out v1
class: constructed
measurement_source: own
methodology_version: 0.8
status: draft
created: 2026-05-14
model_under_test: <pre-registered model + commit; e.g., "code-llama-13b-instruct @ <hash>">
heldout_hash: <filled at lock>
peer_reviewer: <filled before lock>
supersedes: none
```

- **Target:** Accuracy of language identification (12 classes) on a 2000-snippet held-out collected from post-cutoff public repositories. Construct — "which language" — directly observable; ground truth = file extension + parser check.
- **Measurement procedure:** `scripts/eval/langid.py @ <hash>`. Held-out: `data/langid-v1/heldout.jsonl @ <hash>` (sealed, hash in frontmatter). Provenance: snippets from repositories created after the model cutoff; who collected, dedup procedure. Seeds: 10. N=10.
- **Acceptance criteria:** Primary = balanced 12-class accuracy. Decision: two-level bootstrap 95% CI on paired difference (model − pre-registered baseline classifier) excludes 0 + δ, δ=0.02. Guardrails (≥2 per §3.2): (1) per-class recall — no class drops more than 5% rel to baseline; (2) inference throughput — ≤120% baseline tokens/sec (deployable-cost guardrail).
- **Anti-Goodhart:** Regressional → two-level CI. Extremal → check on obfuscated/minified snippets. Causal → N/A (no intervention). Adversarial → red-team snippets with misleading comments/shebangs.
- **Proxy validity:** N/A — construct directly observable, not a proxy. This is what distinguishes constructed from the proxy class.
- **Contamination:** held-out from post-cutoff repos → exposure structurally impossible for models with an earlier cutoff (provenance audit, see §10). A project-specific canary GUID in the held-out as a backstop. For models with a late/unknown cutoff — canonical-completion test.
- **Replacement:** retire when the language set changes OR the provenance assumption is broken (a model with a cutoff later than the held-out date) OR the canary is detected.

### 7.3. Proxy — example sketch

A project uses linear decodability as a proxy for a latent semantic-structure construct in embeddings.

```yaml
id: bench-0003
title: Linear decodability as proxy for a latent semantic-structure construct
class: proxy
measurement_source: own
methodology_version: 0.8
status: draft
created: 2026-05-14
model_under_test: <pre-registered model family; e.g., "Llama-3.x 7B/13B/70B + Mistral-7B-v0.3 @ <commit>">
heldout_hash: <filled at lock>
peer_reviewer: <filled before lock>
supersedes: none
```

- **Target construct:** "Frozen embeddings encode a continuous latent semantic-structure axis" — *latent, not directly observable*.
- **Class rationale:** the construct is open — there is no oracle returning ground-truth values for it. Linear decodability is a measurable approximation. Class = proxy (§4.4).
- **Seeds:** 20 (per §10 default for proxy class). N=20.
- **Convergent-Discriminant Matrix.** Correlations **between operationalizations** (convergent — should agree) and of each operationalization **with confounds** (discriminant — should not). There is no "target construct" column — it is unobservable (see §5.1 fix).

| measure | linear_decodability | human_rated_detail | seq_length (confound) | token_freq (confound) |
|---|---|---|---|---|
| **linear_decodability** (this proxy) | — | ρ ≥ 0.55 *(convergent)* | \|ρ\| ≤ 0.20 | \|ρ\| ≤ 0.20 |
| **human_rated_detail** (alt operationalization) | ρ ≥ 0.55 *(convergent)* | — | \|ρ\| ≤ 0.25 | \|ρ\| ≤ 0.25 |

*Convergent: two independently constructed operationalizations of the latent construct must correlate with each other ≥0.55. Discriminant: each with confounds ≤0.20–0.25. Ratio ≥ 2.2× (project 2× convention §5.1). ρ estimates: on N=500 held-out items (CI width at N=500, ρ≈0.55 ≈ ±0.07). `human_rated_detail` collected from an independent 3-rater pool, inclusion at inter-rater Krippendorff α ≥ 0.7. If the two operationalizations disagree — the proxy is not valid, and that is visible without reference to the latent construct.*

- **Nomological predictions** (typed per §5.4):
  1. **(A) Directional.** Decodability rises with model scale at a fixed prompt. Sign +; δ_min: Spearman ρ ≥ 0.4 **across scale points**; power ≥ 0.8 to detect ρ ≥ 0.4. *Power note: the statistical unit is a scale point, not an item. 500 items per point give a precise ρ estimate per point, but do NOT add points. Power ≥ 0.8 at ρ = 0.4 requires **≥47 scale points** (Fisher-z power calc: z_r = arctanh(0.4) ≈ 0.424, n ≈ ((z_{α/2}+z_β)/z_r)² + 3 ≈ ((1.96+0.842)/0.424)² + 3 ≈ 47); pre-register N_scale_points in the spec. Since model families usually give **far fewer than 47 scale points** (typically 4-8), this particular prediction in its nominal form will yield an **inconclusive** verdict for any realistic scale series — it is by-design weak-power. If you want a verdict-eligible signal via scale, options: (a) reformulate as a type (B) equivalence test on the slope coefficient of a linear regression log(decodability) ~ log(scale) with item-level data (units = items, N in the thousands) — gives high power, (b) reformulate as an ordinal-regression coefficient sample with item-level data, (c) accept the inconclusive verdict and use predictions (2) and (3) as primary falsification arms. **Do not use** monotonicity-ordering surrogates ("all 4 in order = confirmed") — they are not verdict-eligible primitives in §5.4 (three types A/B/C, there is no fourth).*
  2. **(A) Directional.** Decodability decreases under controlled paraphrase noise σ. Sign −; δ_min: ≥15% relative drop at σ_max; power ≥ 0.8 on N=500 paired items (here the unit is an item, not a scale point — power is valid).
  3. **(B) Equivalence/invariance.** Decodability invariant under semantic-preserving translation. δ_eq = 0.05 (|Δ| ≤ 0.05 = confirmed); δ_max = 0.15 (|Δ| > 0.15 = falsified); power ≥ 0.8 to detect δ_max on N=500 translated pairs.
- **Falsification rule:** apply the per-type rule of §5.4 — type (A) falsified on wrong sign or effect within ±δ_min at adequate power; type (B) falsified on |Δ| > δ_max. Any falsified prediction retires the proxy for this construct. Inadequate power → inconclusive, not falsified. **Not** p<0.05.
- **Anti-Goodhart:**
  - Regressional → two-level bootstrap CI (seeds × items, §10).
  - Extremal → re-validate the Convergent-Discriminant Matrix on outputs from the optimized model, not the base model.
  - Causal → controlled ablation (zero out the top-k decodability dimensions, check whether downstream tasks degrade as predicted). **Caveat:** for a proxy class with an unobservable construct, the tripwire tests proxy→downstream-proxy, not proxy→construct — an attenuated check. Pair with controlled-input experiments (text at controlled construct levels). A clean proxy→construct interventional test is impossible by definition of the proxy class.
  - Adversarial → red-team passages designed to maximize decodability without matching the construct.

---

## 8. Internal consistency checks (not validation in the strict sense)

A recursive question: a bench for the bench methodology. The methodology has no L1 in the usual sense. §8.1–§8.3 below are **internal consistency checks**, not validation: they are **non-falsifying by construction** (see §8.4). True validation is only §8.4's fourth criterion (in-the-wild failure detection). The section is named honestly so that "passed §8.1–8.3" does not read as "the methodology is valid".

**Honest status (fix-pass-3): the methodology is NOT "approved for production".** It is **pilot v0.8**. Of the three consistency-checks, §8.1 and §8.2 are not executed at all, §8.3 was non-blind. The prior formulation "approved if all three pass" + §8.3 "PASS" is an overclaim. The correct status: pilot, ready for the first real application — which is itself the real §8.3. "Production-ready" arrives after passing all three checks + accumulating §8.4 in-the-wild evidence.

### 8.1. Retrospective fit

**Question.** Does the methodology describe how successful research projects actually built their benches?

**Application.** For each of 5 reference projects (BIG-bench, HELM, MTEB, NeurIPS reproducibility tracks, a representative Registered Report) check: can their bench-spec be reconstructed through our template without loss of information?

**Pass criterion.** ≥4 of 5 reference projects fit the template with all required fields filled. If ≥2 do not fit — methodology weakness.

**Status.** Not yet executed. A follow-up deliverable, not blocking application of the methodology to a first real task.

### 8.2. Failure mode coverage

**Question.** Does the methodology catch predictable failure modes?

**Application.** We construct "adversarial bench-specs" — deliberately broken versions demonstrating each known failure mode (HARKing, the 4 Goodhart variants, contamination, the single-number trap, justification theater). We check which of them our template + lock mechanics catch, which not.

**Pass criterion.** ≥8 of 10 adversarial bench-specs are either blocked by required fields, or flagged with `[uncertain]` markers in required fields.

**Status.** Not yet executed. Also a follow-up deliverable.

### 8.3. Prospective utility — usability test

**Question.** Can a researcher read the methodology and fill out a bench-spec for a new project without clarifying questions?

**Application.** The first real applied case is a natural usability test. If the author of the first bench-spec needs to ask ≥3 clarifying questions of the methodology — the methodology fails usability.

**Pass criterion (original wording).** A successful first real bench-spec with ≤2 clarifying questions.

**About the "revised pass criterion" — withdrawn.** There was an attempt to reformulate the criterion around internal usability runs. That revision is **withdrawn as self-serving**: the internal target coincided with worked example §7.3 (agents had scaffolding — non-blind), and substituting "real applied task" with "internal run" softens the bar to fit an existing result. **Only** the original criterion (a real applied task) is in force. Internal runs are an indicative signal, not a PASS.

**Status (fix-pass-3): NOT closed.** Internal usability runs gave an indicative signal — agents independently filled out a proxy bench-spec — but this is **not a PASS**: (a) the test was non-blind (the target coincides with worked example §7.3, agents had scaffolding); (b) the original pass criterion requires a **real applied task**, not an internal run. §8.3 closes **only** with a successful real applied task. Until then — open. The run scoring is kept as evidence.

### 8.4. Honest stance on validation recursion

The methodology cannot validate itself in the strict sense. These three criteria are surrogates, not proof. The alternative — having no criteria at all — is strictly worse. We accept the surrogates, explicitly noting their limitations.

**Additional honesty (after Run 2 review feedback).** All three criteria are biased in one direction — toward false-positive validation:

- **§8.1 Retrospective fit** — non-falsifying. The reference benchmarks (BIG-bench, HELM, MTEB, etc.) were sources of the methodology. Testing their fit back is a check of whether the training data is recovered from a fitted curve, not independent validation.
- **§8.2 Failure mode coverage** — non-falsifying. The adversarial bench-specs are written by the team that wrote the methodology, targeting failures the methodology was designed to catch. Detection by construction.
- **§8.3 Prospective utility** — **not closed** (fix-pass-3). Internal runs are non-blind (target = worked example §7.3, agents had scaffolding). Closes only with a successful real applied task.

**What is needed for real validation:** a fourth criterion — *in-the-wild failure detection*. Tracking, over 6-12 months of application, how many tasks find failures the methodology does NOT catch. This is the only criterion capable of materially refuting the construction. Not yet enabled.

---

## 9. Open questions

These gaps remain after research and the draft:

- **Cryptographic freeze for agent timescales.** Pre-registration assumes weeks; we need commit hashes for minute-scale cycles. This is an infrastructure piece that should be a requirement in L2-guards. Not closed.
- **Stop-rule under cheap re-runs.** A pre-committed seed list + stopping rule + verification that seeds are not re-rolled retroactively. The mechanism is not specified.
- **Self-policing problem.** Bench-spec adoption in a solo / small-team context depends on the author not back-dating: the prerequisite is that the spec was really written BEFORE, not reproduced AFTER to fit the result. The methodology does not close this hole unilaterally — it requires an L2-guard that locks the bench-spec hash on the first associated experimental run, or external attestation. Until such a guard, bench-spec compliance is honor-system at the project boundary.
- **Proxy validity for open-ended research where the construct itself is refined.** Construct validity literature assumes a stable construct. Latent-construct experiments — the construct itself evolves along the way. A recursive layer: validity of the proxy + validity of the construct delineation. The methodology has no answer.
- **Verification debt residual.** A few sources are marked ◐ (Messick 1989 pagination, AsPredicted verbatim, North 2006 page bot-blocked). Not blockers, but cited with `[uncertain]` markers above.

---

## 10. Defaults — overrideable knobs

A bench-spec author may override any default explicitly. If a field is not mentioned in the spec — the default applies. This reduces the chance that different authors invent different answers to the same operational questions.

### Statistical defaults

- **Confidence interval level:** 95%.
- **Bootstrap resample count:** B ≥ 10,000.
- **Seeds:** ≥10 for adopted- and constructed-class, ≥20 for proxy-class. (Proxy has a higher noise budget.)
- **δ (effect threshold) selection.** δ is not invented. Pre-register δ justified by one of: (a) **baseline variance** — δ ≥ 1 SD of the natural seed-to-seed/item-to-item variation of the baseline (the change must be larger than noise); (b) **downstream-meaningful effect** — the smallest change that actually affects the decision the bench exists for. The δ rationale is recorded in bench-spec §4.
- **Power.** The design must have power ≥ 0.8 at α = 0.05 to detect the registered δ_min. If there is no pilot data for a power calculation — run a **calibration pilot**, and its data **cannot** be reused for confirmatory claims (it is a separate prior run, not part of the locked measurement).
- **Nomological predictions:** falsification via the per-type rules (§5.4): directional / equivalence / non-inferiority. Not p<0.05 on a point null.
- **Multiple-comparison correction:** Holm correction — **only** in the confirmatory context (§9), when it is claimed that N predictions are confirmed. **Not** in the falsification rule (§5.4) — there Holm inverts the intent.
- **Bootstrap structure: cluster bootstrap (seeds + items) by default.** Single-level over seeds estimates only optimizer variance; single-level over items — only eval-set variance. For generalization claims both components are needed — the correct construction:
  - **B iterations.** In each: resample the seed-list with replacement **AND** resample the eval-set with replacement (both clusters at once), then compute **one** aggregate metric.
  - **Result — B aggregates** (not B_seeds × B_items — that was an error in the prior formulation: the nested product distorts the variance structure). The CI is taken on the distribution of these B aggregates.
  - **Paired differences.** If the decision rule compares to a baseline — on each bootstrap iteration a **paired difference** (proxy − baseline) is computed on the same resampled seeds×items; CI on the distribution of paired differences. Requires **per-item baseline outputs** — see below on baseline types.
  - **Cost-conscious fallback:** single-level seed bootstrap is acceptable if the eval-set is known to be fixed and representative for the target population AND explicitly declared: `Override: cluster bootstrap → single-level (seeds only). Rationale: eval-set is the population, not a sample.`
- **Baseline types and what you can do with them.**
  - **Re-runnable baseline** (model id + commit, executed on the same items) → paired-difference CI applies.
  - **Named prior result** (only a published number, no per-item outputs) → paired CI is **impossible**. Use a one-sample CI on the model's own metric against the fixed baseline value; explicitly declare that baseline variance is not captured. This is weaker — prefer a re-runnable baseline.

### Measurement defaults

- **Ordinal vs categorical for axis constructs:** prefer ordinal regression (ranking loss or ordinal probit); 3-class categorical is OK as secondary if the axis is naturally discrete (macro/meso/micro). If you choose categorical for an inherently ordinal construct — explicit rationale in §1 Target.
- **Default probe family for "linearly decodable" claims:** `sklearn.linear_model.LogisticRegression` multinomial L2, balanced class weight (Belinkov 2022 probing standard). Override if the construct requires another.
- **Pooling for embedding-based probes:** mean over content tokens (excluding BOS/EOS/pad). Override explicitly if another.

### Validation defaults

- **Convergent-discriminant — two conditions:** (1) absolute floor convergent ρ ≥ 0.50; (2) ratio convergent ρ ≥ 2× discriminant |ρ|. Both mandatory (**project convention**, not a Campbell-Fiske rule — see §5.1 Ratio guideline). The floor closes the math trap "2 × 0.05 = 0.10".
- **Minimum operationalizations in the CD matrix:** 1 alt + 1 proxy = 2 rows. ≥2 confounds = ≥3 columns. This is the absolute floor; more is better.
- **Minimum nomological predictions:** 3, each signed + ML-substantive.

### Guardrail defaults

- **Tolerance interpretation:** **absolute** unless prefixed `rel:` (e.g., `tolerance: -5%` = absolute 5 percentage points; `tolerance: rel:-5%` = relative 5% of baseline). Override the convention in the bench-spec itself.
- **Stop rule baseline:** halt + re-evaluate on the first guardrail violation, not "watch and continue".

### Contamination defaults

- **Canary detection threshold:** log-probability of exact GUID continuation ≥10 log-units above a random 36-char baseline → suspected leak. **Applicable only to models with access to token log-probs at generation.**
- **Non-generative / closed-API models.** The canary log-prob test does not work for embedding-only models, retrieval systems, and closed APIs without logprob access. Alternatives (the bench-spec picks what applies):
  - **Membership-style probe:** compare the model's behavior on held-out items vs matched novel items from the same distribution — anomalously high perf on held-out → suspected exposure.
  - **Canonical-completion test:** give the model a unique prefix string from the held-out and check whether it reproduces the continuation (works for any generative model even without logprob).
  - **Provenance audit:** if the held-out is built after the model's cutoff date and was never published — exposure is structurally impossible; documented as a defense.
  - If **none** apply (closed embedding API, unknown training data) — the contamination status is flagged `unverifiable`, and this is an explicitly declared limitation of the bench-spec, not a silent gap.
- **Canary regeneration:** a new GUID each time at lock; do not reuse public canaries.
- **Detection frequency:** at spec creation + before each confirmatory run + before adding a new model to the evaluation series.

### Override convention

If the author overrides a default — note it in the relevant section of the spec: `Override: [default] → [new value]. Rationale: [one paragraph]`. This creates an audit trail for review.

---

## 11. References

**Methodology traditions:**

- Beck, K. (2002). *Test-Driven Development: By Example*. Addison-Wesley. ISBN-13 9780321146533.
- North, D. (2006). "Introducing BDD". Better Software magazine. dannorth.net/introducing-bdd/ `[uncertain — page bot-blocked at fetch, URL secondary-verified]`.
- Chambers, C. (2013). "Registered Reports: A new publishing initiative at Cortex". *Cortex* 49, pp. 609–610. [DOI 10.1016/j.cortex.2012.12.016](https://doi.org/10.1016/j.cortex.2012.12.016), [PMID 23347556](https://pubmed.ncbi.nlm.nih.gov/23347556/).
- [OSF Registrations help](https://help.osf.io/article/330-welcome-to-registrations).
- [COS Registered Reports](https://www.cos.io/initiatives/registered-reports).
- [Data Colada #44 — AsPredicted: Pre-registration Made Easy](https://datacolada.org/44).
- Leveson, N., & Turner, C. S. (1993). "An Investigation of the Therac-25 Accidents". *IEEE Computer* 26(7), pp. 18–41. [DOI 10.1109/MC.1993.274940](https://ieeexplore.ieee.org/document/274940/).

**Benchmark engineering:**

- Srivastava, A. et al. (2022). "Beyond the Imitation Game: Quantifying and extrapolating the capabilities of language models". [arXiv:2206.04615](https://arxiv.org/abs/2206.04615).
- Liang, P. et al. (2022). "Holistic Evaluation of Language Models". [arXiv:2211.09110](https://arxiv.org/abs/2211.09110) (TMLR 08/2023).
- Muennighoff, N. et al. (2023). "MTEB: Massive Text Embedding Benchmark". [arXiv:2210.07316](https://arxiv.org/abs/2210.07316).
- [NeurIPS Paper Checklist](https://neurips.cc/public/guides/PaperChecklist).
- Goldfeld, A. et al. (2024). "The NeurIPS Checklist Assistant: Findings from a study". [arXiv:2411.03417](https://arxiv.org/html/2411.03417v1).

**Construct validity:**

- Cronbach, L. J., & Meehl, P. E. (1955). "Construct Validity in Psychological Tests". *Psychological Bulletin* 52(4), 281–302. [PDF mirror](https://meehl.umn.edu/sites/meehl.umn.edu/files/files/036constructvalidityidx.pdf).
- Messick, S. (1989). "Validity". In R. L. Linn (Ed.), *Educational Measurement* (3rd ed.), pp. 13–103 `[uncertain — some sources 13–104]`. Macmillan. ISBN-13 9780029224007.
- Messick, S. (1995). "Validity of psychological assessment". *American Psychologist* 50(9), 741–749. [DOI 10.1037/0003-066X.50.9.741](https://doi.org/10.1037/0003-066X.50.9.741).
- Belinkov, Y. (2022). "Probing Classifiers: Promises, Shortcomings, and Advances". *Computational Linguistics* 48(1), 207–219. [DOI 10.1162/coli_a_00422](https://aclanthology.org/2022.cl-1.7/).

**Anti-Goodhart:**

- Manheim, D., & Garrabrant, S. (2018). "Categorizing Variants of Goodhart's Law". [arXiv:1803.04585](https://arxiv.org/abs/1803.04585).
- Gao, L., Schulman, J., & Hilton, J. (2022). "Scaling Laws for Reward Model Overoptimization". [arXiv:2210.10760](https://arxiv.org/abs/2210.10760).
- Pan, A., Bhatia, K., & Steinhardt, J. (2022). "The Effects of Reward Misspecification: Mapping and Mitigating Misaligned Models". [arXiv:2201.03544](https://arxiv.org/abs/2201.03544).

**Contamination evidence:**

- ["BIG-bench canary contamination in GPT-4" — Alignment Forum analysis](https://www.alignmentforum.org/posts/kSmHMoaLKGcGgyWzs/big-bench-canary-contamination-in-gpt-4).
- [Alignment Research Center canary registry](https://www.alignment.org/canary/).

**Infrastructure failure case (replacement protocol):**

- [Papers with Code sunset announcement and analysis (CodeSOTA)](https://www.codesota.com/papers-with-code).
- [paperswithcode-data archive (GitHub)](https://github.com/paperswithcode).
