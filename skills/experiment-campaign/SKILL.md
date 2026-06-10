---
name: experiment-campaign
model: opus
description: Run a planned sequence of experiments hands-off — chain experiment-design → run-experiment → verdict → register for each run in a campaign, pacing long background jobs with /loop dynamic mode and stopping on regression or budget breach. Use this when you have a list of runs to execute unattended (a full benchmark sweep, a knob-decomposition campaign, a multi-benchmark regression pass), when the user says "run the whole benchmark campaign", "kick off all the benches and report back", "do the sweep overnight", or hands you a multi-run plan. For a single run, use run-experiment directly — this skill is the loop around it.
---

# Run an experiment campaign

A campaign is several runs executed in sequence with one verdict each. The point of this skill is to run them **unattended but safely** — long jobs (a full benchmark can be many hours) shouldn't block the session, and a campaign shouldn't keep spending after something has clearly broken.

## Before you start

- Read the domain profile and benchmark protocol your workspace declares for this kind of work — they name the paradigms, metrics, integrity checklist, and the registry location. (The profile is your source for the per-run pre-flight traps invoked below.)
- Have a **run list**: each entry is a run-spec from `experiment-design` (paradigm, invocation, baseline, thresholds). If you only have a fuzzy goal, run `experiment-design` for each run first to produce the list.
- Confirm the **global gates** below with the user, especially the budget cap — this skill spends money unattended.

## Global safety gates (confirm before the first run)

- **Budget cap.** A total $ ceiling for the campaign. Track cumulative spend; stop and report when the next run would exceed it.
- **Stop-on-regression.** If any run's verdict is REGRESSION, halt the campaign and surface it — don't keep burning budget on a broken state. (Exploration campaigns may opt out, since a worse number is expected; say so explicitly.)
- **Clean-tree precondition.** The code under test is pinned for the whole campaign; record the git hash once and don't let it drift mid-campaign.
- **Keys present** before the first run.
- **Serialize shared-store runs.** Benchmarks sharing a backing store (a shared database, a shared index, etc.) must run one at a time — never overlap, or they pollute each other's state.

## The loop (per run)

For each run-spec in the list:

1. **Pre-flight** (from `run-experiment` Phase 1): integrity checklist, dataset, budget headroom, and the **profile-specific pre-flight traps** the domain profile lists for this benchmark (e.g. resource-budget invariants and ingest/data-prep invariants the profile flags as must-check before launch).
2. **Kick the run in the background** with an unbuffered log (`python -u … > <log> 2>&1`).
3. **Pace with `/loop` dynamic mode.** Use `ScheduleWakeup` to sleep while the run proceeds. Pick the delay by what you're waiting on, not round numbers:
   - The harness re-invokes you when a tracked background job finishes — so the wake-up is a **fallback**, not the primary signal. Set it long (1200 s+) so you're not burning the prompt cache polling a multi-hour job.
   - If you're watching external state the harness can't notify you about (a remote queue), poll under the 5-min cache window (≤ 270 s).
4. **On completion**, validate (`run-experiment` Phase 3) and compute the **verdict** per the profile's thresholds + `experiment-paradigm-discipline` (the verdict + variance-band logic lives there).
5. **Register** the row, **append to the campaign report**, and check the gates (budget, stop-on-regression).
6. **Next run**, or stop if a gate fired or the list is empty.

## Reporting

Maintain a running campaign report: one section per run (paradigm, config, result, verdict, vs-baseline) plus a header with the cumulative spend and the pinned git hash. At the end (or on an early stop), present the table and the headline: what passed, what regressed, what improved, total spend, wall-time.

## Failure handling

- A run that **crashes** (traceback / OOM / dies) is not a verdict — surface it, don't mark it PASS or skip silently. Decide with the user whether to retry, fix, or abort the campaign.
- A **borderline hard-fail** gets the re-run-once variance check before it counts as REGRESSION (per profile).
- If the campaign is halted by a gate, leave the run list and cumulative state in the report so it can be resumed.
