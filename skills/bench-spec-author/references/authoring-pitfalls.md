# Bench-spec authoring — common pitfalls

Companion to `SKILL.md`. Catalogues the mistakes that show up most often in first-time spec authoring, with concrete patterns to recognize and the methodology section that addresses each.

## Pitfall 1: Proxy misclassified as constructed

**Pattern**: Author has own held-out data + has annotators rate items → assumes class = `constructed`. But the construct (e.g., "concept hierarchy quality", "semantic structure", "model knowledge") is **latent** — no oracle returns ground-truth values; annotators are themselves approximating.

**Why dangerous**: skipping §6 nomological predictions because "we have own held-out data" means proxy claims without validity scaffolding. Verdict can be a "win" on a metric that doesn't measure the construct.

**Rule**: §4.4 boundary — "Can third party look at your data and **directly** verify construct presence?" If no → proxy, even with own splits. Annotated ratings = constructed-**style** data, but the **claim** is still proxy.

**Recognition signal**: user says "the construct is X, and we have annotators rate items 1-5 / yes-no / on a 3-class scale". The annotators' scores are themselves the proxy — not the construct.

## Pitfall 2: Class chosen by data convenience, not by claim

**Pattern**: "We're using MMLU, so it's adopted" — even though the claim is "model's knowledge", which is unobservable.

**Rule**: §4 intro — class is about your **relationship to the measurement**, not the benchmark's nature. MMLU as your target → adopted; MMLU as stand-in for unobservable "knowledge" → proxy. Same benchmark, different claim.

**Recognition signal**: user reaches for a benchmark name to decide class. Force the question: "What is the actual claim — accuracy on this benchmark, or something you're using this benchmark to approximate?"

## Pitfall 3: Single guardrail (or zero)

**Pattern**: Only the primary metric named; guardrails empty or just one.

**Why dangerous**: §3.2 requires ≥2 guardrails for "irreducibility to a single number". Single-number leaderboard optimization hides trade-offs (accuracy up, toxicity up, runtime up, fairness down).

**Rule**: ≥2 guardrails. Each guardrail is an individual constraint — ANY violation blocks `win`.

**Recognition signal**: user proposes one guardrail and says "the rest will be fine". Push back: enumerate categories that could regress (quality, runtime, cost, fairness, calibration, robustness). Pick 2-3.

## Pitfall 4: δ made up

**Pattern**: User sets δ = 0.05 because "it's a small number". No connection to baseline variance or downstream meaningfulness.

**Why dangerous**: arbitrary δ either rejects too easily (false-positive win) or too hard (real effects discarded).

**Rule**: §10 δ-selection — one of (a) ≥ 1 SD of baseline seed-to-seed/item-to-item variation, OR (b) smallest change that actually affects the decision the bench supports. Rationale documented in §4.

**Recognition signal**: when user proposes δ, ask "Why this value?" If the answer is "feels right" / "common in the field" / "small enough to detect" — push to derive from variance or decision threshold.

## Pitfall 5: Convergent ρ floor ignored

**Pattern**: Proxy class user designs operationalizations without budgeting for ρ ≥ 0.50 convergent floor. Discovers at §6 that operationalizations correlate at ρ = 0.3 — fails the absolute floor.

**Why dangerous**: methodology §5.1 — ratio without floor is a math trap ("2 × 0.05 = 0.10 passes ratio but is statistically useless"). The bench fails before §6 even gets to discriminant checks.

**Rule**: forward-pointer block in §2 (template) shows the floor early. Design operationalizations to meet ρ ≥ 0.50 **before** locking. If pilot ρ < 0.50 — go back to operationalization design, don't lock.

**Recognition signal**: user picks operationalizations that "feel reasonable" without checking how they correlate in pilot data. Force a pilot with computed ρ before going to lock.

## Pitfall 6: Nomological predictions vague

**Pattern**: "Decodability should increase with model size" — no sign, no δ_min, no type label, no power statement.

**Why dangerous**: §5.4 falsification rule requires per-type parameters. Vague predictions either auto-confirm (any positive correlation = "increases") or auto-falsify (no exact threshold met = "didn't increase enough"). No middle ground for honest inconclusive.

**Rule**: every §6 prediction needs (a) type (A/B/C), (b) sign + δ_min for type A; δ_eq + δ_max for type B; margin for type C, (c) power ≥ 0.8 statement.

**Recognition signal**: prediction has the word "should" with no number. Drill down: "what magnitude makes this a real effect vs noise? what's the unit of statistical inference (item? seed? scale point?)?".

## Pitfall 7: Multi-scale prediction without enough scale points

**Pattern**: "Decodability rises with scale at ρ ≥ 0.4 across 4 scale points". 4 points gives ≈15% power for ρ=0.4 (far below 0.8). Result will be inconclusive regardless of truth.

**Why dangerous**: false economy. User saves on compute (fewer scale points) but loses the prediction's verdict-eligibility entirely. Worse, in practice model families rarely give >8 scale points, so the *nominal* ρ-across-scale-points form is **by-design weak-power** for any realistic series.

**The correct math (Fisher-z power for Pearson/Spearman correlation):**

```text
z_r  = arctanh(ρ)                              # Fisher transform
n    = ((z_{α/2} + z_β) / z_r)² + 3            # required sample size

For ρ=0.4, α=0.05 two-tailed, power 0.8:
  z_r ≈ 0.424
  n   ≈ ((1.96 + 0.842) / 0.424)² + 3 ≈ 47
```

**Rule**: ρ ≥ 0.4 with power ≥ 0.8 needs **≥ 47 scale points** — not 8. (A prior version of bench-methodology §7.3 stated ≥8; this was a 5× error corrected after subagent review.)

**Options when realistic N_scale_points is far below 47:**

- **(a) Reformulate as type (B) equivalence test on slope coefficient.** Fit `log(metric) ~ log(scale)` with item-level data. Units of inference = items (thousands), not scale points. Now powered.
- **(b) Reformulate as ordinal-regression coefficient** on item-level data. Same N=items advantage.
- **(c) Accept inconclusive verdict.** Pre-register that with the achievable N this prediction will return `inconclusive`, and rely on other §6 predictions as primary falsification arms. Honest, methodologically valid.

**Never use**: monotonicity-ordering surrogates ("all N points in predicted order → confirmed"). Not a verdict-eligible primitive in §5.4's A/B/C taxonomy. Methodology §5.4 enforces three prediction types; no fourth.

**Recognition signal**: user proposes ρ-across-scale-points prediction. **Show them the math first.** If N_scale_points < 47, they pick one of (a)/(b)/(c) — not "we'll just live with weak power".

## Pitfall 8: Baseline drifts between iterations

**Pattern**: Iteration 1 runs baseline. Iteration 2 "re-runs baseline because the config changed slightly". Now there are two baselines, conflated.

**Why dangerous**: the baseline is pre-registered, frozen. Re-running with different config silently changes the verdict's reference point.

**Rule**: cache baseline outputs at lock. Future iterations read from cache, don't re-run. If the baseline needs to change → new superseding spec.

**Recognition signal**: user discusses "we'll re-run baseline each iteration to be fair". Push back — the bench-spec freezes baseline once. Re-runs against same baseline; "fair" means same reference, not fresh re-execution.

## Pitfall 9: Step 0 / Step 1 / Step 2 verdict logic confused with pre-registration

**Pattern**: User reads §4 Verdict categories block and starts filling values into Step 0 / Step 1 / Step 2 as if they're fields.

**Why dangerous**: §4 verdict block is **verdict-time logic** applied AFTER results arrive — not fields to fill at lock. At lock, you only pre-register: primary metric definition, baseline, δ, guardrails + tolerances, decision rule. The mechanical computation of `win` / `loss` / etc. happens later, by `/check-stop` against results.

**Rule**: template now labels this explicitly. Re-explain if user is confused.

**Recognition signal**: user asks "what verdict do I write here?" pointing to Step 2 table. Answer: "Nothing now. This is the rule that's applied after each iteration's results to produce a verdict."

## Pitfall 10: §10 overrides without rationale

**Pattern**: User wants to drop to N=5 seeds because "20 is too expensive". Doesn't write override rationale.

**Why dangerous**: §10 defaults exist for a reason (CI width, power). Overriding without rationale is silently weakening the design.

**Rule**: override convention — `Override: [default] → [new]. Rationale: [paragraph]`. Required.

**Recognition signal**: user proposes a value that differs from §10. Ask "Why this deviation? What does the override buy you, and what's the cost?" Document in spec §10.

## Pitfall 11: §7 contamination skipped for "we'll handle it later"

**Pattern**: User defers §7 because "the model is new, can't be contaminated".

**Why dangerous**: "model has cutoff < held-out date" is a contamination claim that requires evidence (provenance). Also, downstream model releases can backfill — what's uncontaminated today might be contaminated when a benchmark gets used by other teams whose models train on your project's papers.

**Rule**: §7 is **required** for constructed and proxy; **recommended** for adopted. Even "exposure structurally impossible" needs documenting (provenance + cutoff).

**Recognition signal**: user says "skip §7, the model is recent". Walk through provenance argument; explicitly write "exposure structurally impossible because [evidence]" in §7. Don't leave blank.

## Pitfall 12: Generating canary GUID in draft

**Pattern**: User wants to pre-generate canary GUID and embed in draft.

**Why dangerous**: drafts live in PRs — public, indexed, scrapable. Canary embedded pre-lock is **already compromised**.

**Rule**: §7 explicit warning. Placeholder `<generated-at-lock>` until lock. Generation at lock commit, embedded in spec + data atomically.

**Recognition signal**: user asks "can I just pre-generate the GUID?" — explain why no. Reference template §7 warning.

## Pitfall 13: Confirmatory and exploratory blurred in §9

**Pattern**: User lists "potential analyses" in §9 confirmatory list, including ones that depend on what they see in results.

**Why dangerous**: §9 confirmatory = pre-registered. Anything that depends on observed results is exploratory by definition. Mixing them retroactively converts exploratory to confirmatory — HARKing.

**Rule**: §9 confirmatory list is a closed set. Maps to §4 / §6 elements. Exploratory section reservation in results/exploratory.md.

**Recognition signal**: user includes "if we see X, we'll also analyze Y" in confirmatory. That's exploratory. Move it explicitly.

## Pitfall 14: lock_tier defaults to conventional even for high-stakes

**Pattern**: User picks `conventional` because "we're a small team, no protected ref setup needed".

**Why dangerous**: spec will be cited in a technical report → external readers can't distinguish conventional from cryptographic — both look "locked". Conventional doesn't survive scrutiny.

**Rule**: Q5 of interview — if cited externally, `cryptographic`. Set up protected ref + signing key as one-time investment.

**Recognition signal**: spec is high-stakes (publication, peer review) but user picks conventional for convenience. Push back on cost-vs-rigor. Setup is one-time; the discipline of cryptographic locking pays back across all future specs.

---

If the user makes any of these mistakes during the interview, name the pitfall explicitly and reference the methodology section that addresses it. The goal isn't to gate-keep; it's to make the design rigorous before lock. Each pitfall caught now saves a superseder later.
