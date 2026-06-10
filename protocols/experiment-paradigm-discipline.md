# Experiment paradigm discipline

A portable methodology protocol for anyone running benchmarks or experiments whose
numbers will be compared, tracked, or cited later. It says nothing about *which*
benchmarks you run — that belongs in a domain profile and a per-benchmark protocol.
It says how to keep the numbers honest: what paradigm a run belongs to, why you must
never compare across paradigms, how often to run each tier, and how every number earns
a provenance row.

This protocol pairs with the experiment skills (`experiment-design` → `run-experiment`,
looped by `experiment-campaign`) and with whatever domain profile your workspace declares
(see `profiles/_example-profile.template.md` for the shape). The profile holds the
concrete values — datasets, thresholds, invocations; this protocol holds the discipline
that keeps those values comparable.

## The three paradigms (read this before any run)

A benchmark number is meaningless without its paradigm. There are three, and they are
**not comparable to each other**:

| Paradigm | Config | Purpose | Comparable over time? |
|---|---|---|---|
| **regression** | production defaults, no tuning flags | the number a default caller actually gets; catch drift | yes — this is the canonical baseline |
| **tuned-frontier** | a fixed, known-good tuned config | track the ceiling | only to itself; a *reference*, never the regression target |
| **exploration** | one knob varied per run | find a new frontier | no — each run differs by design |

- **regression** changes *nothing* from the production defaults. That is the point: it
  measures what a real caller gets, so its runs are comparable to each other over time
  and form the canonical baseline.
- **tuned-frontier** is a deliberately favourable, frozen config kept to show how high
  the system can reach. Record it as a reference. It is *never* the target a regression
  run is graded against.
- **exploration** flips exactly one knob to look for a new frontier. It is valuable but
  produces nothing comparable across runs. Label it explicitly; never call it "the
  baseline."

**Never compare across paradigms.** State the paradigm in three places: the experiment
design, the registry row, and the report. If a number's paradigm is unknown, the number
is unusable.

### The failure mode this prevents

The classic false alarm: a defaults run is read as a catastrophic regression against an
earlier *tuned* run. The code is clean — the gap is a *configuration* difference (defaults
vs tuned paths), and a tuned re-run on the current code reproduces the earlier number.
The cost is a wasted investigation and an eroded baseline. The fix is structural, not
heroic: declare the canonical baseline a **regression test against production defaults**,
and record any tuned config as a separate, non-canonical reference. Most "regressions"
that survive a paradigm check are config drift, not code drift.

### One variable per run

So a result is attributable: change exactly one config knob from the comparison point.
A *regression* run changes nothing (it IS the defaults). An *exploration* run flips one
knob alone, never several at once — otherwise you cannot tell which knob moved the number.

## Tier cadence

Not every run is the same size or runs on the same schedule. Define a small number of
tiers so cost matches purpose. A common three-tier shape (adapt the counts to your domain
profile — this protocol does not pin them):

- **Tier 1 — per-PR (smoke):** the smallest probe on a fixed tiny input set. Catches gross
  breakage. Cheap enough to run on every PR.
- **Tier 2 — major-PR / weekly:** a medium slice at defaults. Catches drift in the default
  path before it reaches a release.
- **Tier 3 — periodic / pre-release:** the authoritative full run that refreshes the
  baseline. The largest and most expensive tier.

**A green lower tier never substitutes for the next tier up before a release.** A Tier 2
pass is an early-warning probe, not a baseline refresh. Run Tier 3 before you tag.

The per-tier cost and wall-time numbers belong in your domain profile / per-benchmark
protocol, not here — duplicating them anywhere else guarantees they drift the next time a
baseline is revised.

## Replicates & variance

Where a benchmark has a seed knob, run N seeds and report the spread. Where it does not
(e.g. the variation comes from a non-deterministic judge or answerer), keep **one canonical
config per paradigm** and characterise the run-to-run variance band instead.

- Report the **variance band** next to every number. A bare point estimate read as exact
  is a misread waiting to happen.
- **Re-run-once rule:** if a run breaches a hard-fail threshold by *less than* the variance
  band, re-run it once before declaring a regression. Two breaches → investigate.

## Reporting standard

Every run that produces a number produces, at minimum:

- the runner's machine + human-readable results artifact (read the number from the artifact,
  never from memory),
- a **report** (from `run-experiment`): paradigm, exact config + commit hash, a metrics
  table with per-category breakdown and failure distribution, the vs-baseline delta, a
  one-line verdict, and any side effects,
- a **registry row** (below).

Lead every comparison with the **one metric computed identically across run modes** (in
many setups this is a recall-style metric). Never compare a mode-dependent metric across
different run modes — that comparison is meaningless even within a single paradigm.

## Registry-row provenance

Maintain one append-only registry, one row per run that produced numbers. A row carries
enough to reconstruct and trust the result:

```
| ID | date | benchmark | paradigm | config | result | vs-baseline | verdict | commit-hash |
```

- **No unnamed runs.** A "quick test" you cite tomorrow is a result today — give it a row.
- **No untraceable numbers.** Any number that appears in a report, a PR, or a decision must
  trace back to a registry row, and that row's `commit-hash` must trace to the code that
  produced it. A number with no row is not evidence; treat it as a rumour and re-run.
- **Pin provenance, reference values.** A protocol should *reference* the authoritative
  baseline (by path/tag), not restate its numbers — restated numbers drift silently the
  next time the baseline is refreshed. When you do pin a code reference (a commit/tag),
  update it in the same change that revises the baseline, so the drift surfaces in review
  instead of going stale.

## Baselines & refresh

Each benchmark gets a recorded baseline and a tag. Set hard-fail and soft-warn thresholds
relative to it (the absolute deltas are domain-profile values). On a *confirmed*
improvement — a deliberate default-path change that a full Tier-3 run confirms — update the
baseline, bump the tag, and note the prior baseline in its history. **Never silently move a
baseline.** A moved baseline with no recorded reason is indistinguishable from a covered-up
regression.

## Why this matters

Benchmark numbers drive real decisions: ship/no-ship, "did this change help," "are we at
the frontier." A number whose paradigm is ambiguous, whose provenance is missing, or whose
baseline moved silently is worse than no number — it carries false authority. This protocol
costs a few lines of discipline per run and buys you numbers you can actually stand behind.
