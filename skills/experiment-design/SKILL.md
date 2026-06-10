---
name: experiment-design
model: opus
description: Design a rigorous, reproducible experiment before running it — state the paradigm, hypothesis, baseline, method, metrics, and success criteria, and write a protocol + config the run can be reproduced from. Use this whenever you're about to run a benchmark, ablation, parameter sweep, or research experiment — especially before spending money or GPU hours, or when the user says "design an experiment", "plan a benchmark run", "set up an ablation", "what's the protocol for X". Run this BEFORE run-experiment so the run has a written spec to validate against. For locked bench-specs that drive autonomous research-iteration loops, use bench-spec-author instead — that produces a tagged, immutable spec; this produces a per-run protocol for operator-driven runs.
---

# Design an experiment

The job here is to make every load-bearing choice *before* the run, so the result is interpretable and reproducible — not "we ran something and got a number." A number with no pre-declared baseline, paradigm, and success criterion is uninterpretable, and worse, invites motivated reading after the fact.

## Pick a domain profile first

This skill is domain-agnostic; the concrete values (what counts as a replicate, which metrics, which integrity checks, where the registry lives) come from a profile. Read the domain profile your workspace declares (e.g. `profiles/<domain>.md`) — it names the paradigms, metrics, replicate rule, integrity checklist, and registry location for the kind of work you're doing.

If no profile fits, follow the phases below with the user filling in the domain specifics, and consider writing a new profile.

## Phase 0 — Paradigm (do this first; it constrains everything else)

Decide what the run is *for*. The profile enumerates the paradigms (for example: **regression** / **tuned-frontier** / **exploration**). Pick exactly one and write it down. The cardinal sin is comparing a number from one paradigm against a number from another — that kind of cross-paradigm comparison manufactures phantom "regressions" (see your project's paradigm ADR, if it has one). The paradigm decides whether the config is "production defaults, untouched" or "one knob changed" or "the known-good tuned config."

## Phase 1 — Hypothesis / intent

- **Regression run:** the intent is "confirm we haven't drifted." State the baseline you expect to hold and the thresholds.
- **Exploration / tuned run:** state the hypothesis in one sentence — "changing X will move metric Y by ≈ Z, because …". Make it falsifiable: what result would prove it *wrong*?
- Define success and failure with **specific numbers**, not "better."

## Phase 2 — Baseline

- Name the exact comparison point: a pinned `BASELINE.md` + git tag, or a numbered prior run from the registry. "Better than before" is meaningless without a reference.
- Confirm baseline and proposed run are measured the **same way** (same metric, same dataset slice, same paradigm). If they aren't, the comparison is invalid — fix that here, not after the run.

## Phase 3 — Method

- The exact invocation (CLI + every flag). For a regression run, **assert no tuning flags are present** (the profile lists which are forbidden). For an exploration run, change **exactly one** knob from the comparison point.
- Dataset and size; where it lives; confirm it's present.
- Replicates: per the profile (e.g. seeds for stochastic training; one canonical config + the re-run-once variance rule for deterministic-but-noisy benchmarks).
- Cost and wall-time estimate, so the spend is a conscious decision.

## Phase 4 — Metrics

- List every metric to record (the profile names them). Mark which one is the **apples-to-apples** comparison metric.
- Comparison method and threshold: hard-fail / soft-warn bands, or the statistical test the profile specifies.
- Note the variance band so a borderline result isn't over-read.

## Phase 5 — Write the protocol

- Append a planned-run row to the registry (profile says where) and write a short run-spec the `run-experiment` skill will consume: paradigm, invocation, baseline ref, metrics, thresholds, integrity checklist to verify at pre-flight.
- If the work is a multi-run campaign, hand the list to the `experiment-campaign` skill.

## Checklist

- [ ] Profile selected and read
- [ ] Paradigm chosen and written down (one, not mixed)
- [ ] Hypothesis falsifiable (or regression intent + thresholds stated)
- [ ] Baseline named (pinned doc/tag or registry ID), measured comparably
- [ ] Invocation exact; regression run has no tuning flags; exploration changes one knob
- [ ] Metrics listed, apples-to-apples metric identified, thresholds + variance band set
- [ ] Dataset present; cost/time estimated
- [ ] Run-spec written + registry row appended
</content>
