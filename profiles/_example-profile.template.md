# Domain profile — <domain-name> (template)

> Copy this file to `profiles/<your-domain>.md`, fill every `<placeholder>`, and delete the
> guidance lines. The domain-agnostic experiment skills (`experiment-design`,
> `run-experiment`, looped by `experiment-campaign`) are deliberately empty of domain
> values — they read those values from a profile like this one. The profile holds the
> *what*; the skills and `protocols/experiment-paradigm-discipline.md` hold the *how*.

This profile fills in the values the experiment skills need when the experiment is a
**<domain-name>** experiment. Read it alongside the skill you are running, and alongside
the experiment-paradigm-discipline protocol.

## Paradigm — pick exactly one (this is the load-bearing choice)

This domain supports three incompatible run purposes (see the paradigm protocol). Mixing
them produces false alarms.

- **regression** — fixed protocol, **production defaults**, no tuning flags.
  `<what a default caller gets in this domain; the canonical baseline>`
- **tuned-frontier** — `<the known-good tuned config for this domain; a reference, never the regression target>`
- **exploration** — `<each run varies one knob to find a new frontier; never "the baseline">`

**Rule:** never compare a number from one paradigm against another. State the paradigm in
the design, the registry row, and the report.

## Benchmark class

- **What this domain measures:** `<the construct under test — what a "good" number means here>`
- **Benchmarks in this class:** `<list the benchmark names/datasets this profile covers>`
- **Unit of run:** `<the atomic unit — e.g. question / task / episode / trial — and roughly how many per full run>`
- **Proxy caveat (anti-Goodhart):** `<if a metric is a proxy for a latent construct, name the proxy and the construct, and note where the proxy stops tracking the construct>`

## Metrics (record all; lead with the cross-mode comparable one)

- **`<primary-metric>`** — `<the one metric computed identically across run modes; lead every comparison with it>`
- **`<secondary-metric>`** — `<record it, but note which comparisons it is NOT valid for (e.g. mode-dependent)>`
- **per-category breakdown** — `<the sub-categories to report so drift can be localized>`
- **failure distribution** — `<the failure buckets; a shift here localizes the cause>`

## Baseline

- **Source of truth:** `<path/artifact the canonical number is read from — never cite from memory>`
- **Recorded baseline + tag:** `<where the baseline value and its tag/version live>`
- **Variance:** `<seed-based spread, or the run-to-run variance band if there is no seed knob>`
- **Refresh rule:** `<what confirms an improvement before the baseline may move; never move it silently>`

## Lock-tier (which tier this run belongs to)

- **Tier 1 (smoke / per-PR):** `<smallest probe; the fixed tiny input set>`
- **Tier 2 (major-PR / weekly):** `<medium slice at defaults>`
- **Tier 3 (periodic / pre-release):** `<authoritative full run that may refresh the baseline>`

A green lower tier never substitutes for the next tier up before a release.

## Budget

- **Per-tier cost / wall-time:** `<rough spend and time per tier — plan the campaign budget against these>`
- **Hard cap:** `<the spend/time ceiling at which experiment-campaign must stop>`
- **Pre-flight integrity checks:** `<domain-specific traps to assert BEFORE launching — e.g. no ground-truth leaking into the input, resource budgets set high enough, isolation between units>`

## Registry

Append one row per run that produced numbers:

```
| ID | date | benchmark | paradigm | config | result | vs-baseline | verdict | commit-hash |
```

No unnamed runs. No untraceable numbers. `<point at where this domain's registry lives>`
