---
name: run-experiment
model: opus
description: Execute a designed experiment with proper pre-flight checks, logging, post-run validation, a mandatory written report, and a registry entry — so every number is reproducible and attributable. Use this whenever you actually run a benchmark, ablation, sweep, or research experiment, or when the user says "run the benchmark", "execute the experiment", "kick off the run". Run this AFTER experiment-design has produced a run-spec. Every run that produces numbers gets registered — no exceptions, no "quick tests."
---

# Run an experiment

The discipline here exists because un-pre-flighted runs waste money on broken configs, and un-registered runs produce orphan numbers nobody can reproduce or trust later. Every run that emits numbers goes in the registry — a "quick test" that you cite tomorrow is a real result today.

## Pick a domain profile first

The concrete values — replicates, integrity checklist, registry location, the apples-to-apples metric — come from a profile. Read the domain profile your workspace declares for this kind of work (e.g. `profiles/<domain>.md`) before you start.

## Phase 1 — Pre-flight (cheap to check, expensive to skip)

- [ ] **Run-spec exists** (from `experiment-design`): paradigm, invocation, baseline ref, metrics, thresholds.
- [ ] **Keys present.** Verify the `.env` (or equivalent secret source) the runner reads is populated. A run that dies 30 min in on a missing key is pure waste.
- [ ] **Dataset present and loadable.**
- [ ] **Clean git tree** — commit or stash first; **record the git hash** (it goes in the results and the registry). A result you can't tie to a commit isn't reproducible.
- [ ] **Profile integrity checklist** — run the anti-leak checks for this benchmark. The profile lists the domain-specific traps and invariants you must check before launch (e.g. a resource-budget trap, a data-ingest invariant, and the per-benchmark anti-leak checks — see the profile's "Source of truth & integrity" and resource-budget sections; for stochastic-training profiles, seed stability + variance band).
- [ ] **Run behavior — verify, don't assume (infra-green ≠ run-correct).** Keys-exist + dataset-present is the easy half; what the config actually *does* is the half that bites:
  - **Flags aren't orthogonal.** A provider/preset can silently flip other settings (e.g. picking one provider turned on an extra per-item LLM pass). Read the branch you hit — don't assume a flag does only what its name says.
  - **Name the model at EACH stage** — ingest/extraction, reader/answerer, judge. Confirm no stage calls an LLM you didn't intend, and any reasoning model has a real budget. The profile enumerates the per-stage gotchas for the domain you're running.
  - **Cost/time follows.** A reasoning model on a trivial per-item task, or an unintended ingest LLM, turns a 1-hour run into days — estimate before launch.
  - Run the repo's per-benchmark pre-flight doc, if it has one — it lists the harness-specific traps.
- [ ] **Paradigm sanity:** a regression run carries *no* tuning flags; an exploration run changes exactly one knob.

## Phase 2 — Execute

- Long jobs (full benchmark runs can be many hours) go in the **background with an unbuffered log**: `python -u -m … > experiments/results/<bench>_<date>.log 2>&1` via `run_in_background`. Don't hold the session hostage to a multi-hour run.
- **Monitor for failure, not just success.** Watch the log for `Traceback`, OOM/`Killed`, auth errors, and the silent ones — empty-LLM (`tokens=0`), zero retrieved items, a metric stuck at 0. Silence is not success; a crashloop and a healthy run look identical if you only grep for the final summary line.
- Track wall-clock time and spend.
- Replicates per the profile (seeds for stochastic training; one canonical config for deterministic-but-noisy benchmarks).
- **Launch sanity (first ~60 s).** Read the opening log lines and confirm the config the run *actually loaded* matches intent — the model(s) per stage, any auto-enabled passes, retrieval depth, and the profile's launch-behavior invariants. Only then walk away. The cheapest place to catch a misconfigured run is its first minute, not its sixth hour.

## Phase 3 — Post-run validation

- [ ] Results `.json`/`.md` exist and parse.
- [ ] All expected metrics present; no NaN/Inf.
- [ ] Integrity invariants held in the *output* too (per the profile's anti-leak invariants — e.g. the profile's "Source of truth & integrity" section).
- [ ] **Re-run-once rule** (applies when the profile has a stated variance band — e.g. a ±1–2 pp band from an LLM-judge): a borderline hard-fail within the variance band is likely noise — re-run once before calling it a regression.
- [ ] Compare against the baseline from the run-spec (hand off to `analyze` for the full verdict).

## Phase 4 — Report (mandatory)

Write a report with: paradigm, exact config + git hash, metrics table (per-category + failure distribution for classification/QA benchmarks; per-seed mean±std for stochastic training), the vs-baseline delta, a one-line verdict, and any side effects (timing, cost, anomalies). Read numbers from the results JSON — never from memory.

## Phase 5 — Registry entry (mandatory)

Append one row to the registry the profile points at (the profile defines the row id convention, e.g. `RUN-NNN`). No unnamed runs.

## Phase 6 — Commit

Stage results + report + registry update. Commit on a feature branch (standing rule: no direct pushes to `main`; open a PR). Commit message states the one-line result. Per the standing rule, **a progress report isn't real until it's backed by this commit** — don't claim "done" with an uncommitted working tree.

## Notes

- One benchmark at a time when runs share a backing store (a shared database, a shared index, etc.) — parallel runs pollute each other's state.
- For a multi-run sequence, let `experiment-campaign` drive the loop; this skill is the single-run unit it calls.
</content>
