# Stop rules — formal reference

Companion to `SKILL.md`. Defines edge cases and the formal schema for halt-condition evaluation.

## Two vocabularies — strict producer/consumer convention

The system uses **two related but distinct verdict vocabularies**. Confusing them is a known foot-gun.

### Per-iteration `verdict` (bare tokens, written by `/research-iteration`)

Lives in `iter-N/results.md` frontmatter `verdict:` field. Describes **what this single iteration produced**:

| Token | Trigger |
|---|---|
| `win` | Step 2 — paired CI lower bound > P + δ. Primary metric improvement confirmed. |
| `loss` | Step 2 — paired CI upper bound < P − δ. Pre-registered regression on primary metric. |
| `non-inferior` | Step 2 — CI within ±δ band. Null hypothesis confirmed. |
| `inconclusive` | Step 2 — CI spans threshold. Under-powered for this iteration. |
| `proxy-falsified` | Step 0 — at least one §6 nomological prediction falsified. (Distinct from `loss` per template §4.) |
| `guardrail-violated` | Step 1 — at least one guardrail outside tolerance. (Distinct from `loss` per template §4.) |
| `error` | Run exited non-zero / metrics not computable / audit P0 blocked. |

Note: `continue` is **not** a per-iter verdict — every completed iteration produces one of the seven above. `continue` is loop-level state, see below.

### Loop-level decision (`/check-stop` output)

Emitted by `/check-stop` in its `## Verdict` block. Describes **what the loop should do next**:

| Token | Triggered by |
|---|---|
| `continue` | No halt condition. Loop schedules next iteration. |
| `halt:win` | Last iter `verdict: win` (Tier 1, Step 2). |
| `halt:loss` | Last iter `verdict: loss` (Tier 1, Step 2). |
| `halt:non-inferior` | Last iter `verdict: non-inferior` (Tier 1, Step 2). |
| `halt:inconclusive` | Last iter `verdict: inconclusive` AND budget exhausted (Tier 1+2). Or the **current** §6 evaluation has inconclusive predictions with no falsifications → cap (see "Step 0 inconclusive cap" below). |
| `halt:proxy-falsified` | Any iter `verdict: proxy-falsified` (Tier 1, Step 0). Proxy retired across whole loop. |
| `halt:guardrail-violated` | Any iter `verdict: guardrail-violated` (Tier 1, Step 1). |
| `halt:budget-cost` | Cumulative cost exceeded declared cap (Tier 2). |
| `halt:budget-time` | Wall-clock exceeded declared cap (Tier 2). |
| `halt:budget-iterations` | Iteration count reached declared maximum (Tier 2). |
| `halt:no-progress` | Primary metric stagnant across last M iterations (Tier 3). |
| `halt:error-cascade` | K consecutive iteration failures (Tier 4). |
| `error:<reason>` | Skill cannot evaluate due to missing or malformed input. Not a halt condition; a tooling problem (e.g., `error:missing-input`, `error:no-locked-spec-found`, `error:results-corrupt`). |

**Why two vocabularies.** A `verdict: win` in results.md is **iteration data** — what was found. `halt:win` is **loop control** — what to do given that finding. They share the suffix to make the lineage obvious, but the `halt:` prefix denotes loop-level decision. Consumers parsing iter frontmatter MUST use bare tokens; consumers reading `/check-stop` output MUST handle `halt:` prefix.

### Step 0 inconclusive cap (skill-layer addition, derived from template §4)

When `class: proxy` and §6 predictions return a mix of confirmed + inconclusive (no falsifications), Step 0 result is **mixed**. Template §4 caps downstream verdict at `inconclusive` (cannot be `win`). `/check-stop` enforces:

- Any iter with §6 inconclusive predictions but no §6 falsifications → that iter's `verdict:` field is capped at `inconclusive` even if Step 2 primary metric reads `win`. (Research-iteration applies this cap at iter-write time; check-stop verifies.)
- Loop-level: `halt:win` is not emitted while the **most recent (most-powered) iteration**'s §6 evaluation still has inconclusive predictions. The cap reflects the **current** evidence state, not loop history — an early under-powered iteration that was inconclusive does **not** permanently lock out `halt:win` once a later iteration confirms all §6 predictions at adequate power. (Contrast Step 0 *falsification*, which is monotonic: any falsified §6 prediction retires the proxy for good.)

## Per-prediction-type falsification rules (methodology §5.4)

The `halt:proxy-falsified` decision walks each §6 nomological prediction. Per its declared type (A/B/C), apply:

### Type (A) Directional

Pre-registered: sign + `δ_min` (minimum effect for "effect is real") + power ≥ 0.8.

- **Confirmed**: CI excludes 0 in predicted direction AND wholly ≥ `δ_min` (or wholly ≤ −`δ_min` for negative sign).
- **Falsified**: sign wrong OR CI wholly within ±`δ_min` at adequate power.
- **Inconclusive**: CI straddles `δ_min` boundary OR power inadequate.

### Type (B) Equivalence / invariance

Pre-registered: `δ_eq` (within = "practically zero") + `δ_max` (beyond = "real effect") + power detect `δ_max`. Required relation: `δ_eq < δ_max` (no zero-width gray zone — that would eliminate "inconclusive" verdict).

- **Confirmed**: |Δ| ≤ `δ_eq` (TOST or equivalent).
- **Falsified**: |Δ| > `δ_max`.
- **Inconclusive**: `δ_eq < |Δ| ≤ δ_max` (gray zone) OR power inadequate.

### Type (C) Non-inferiority

Pre-registered: margin `δ`.

- **Confirmed**: CI lower bound ≥ −`δ`.
- **Falsified**: CI lower bound < −`δ`.

### Aggregation across multiple predictions

Walk all §6 predictions. **ANY single falsified** → `halt:proxy-falsified`. ALL confirmed → Step 0 passes, proceed to Step 1. Any inconclusive without falsification → Step 0 result is "mixed"; downstream verdict is **capped at `halt:inconclusive`** (cannot be `halt:win`).

## Per-guardrail evaluation (methodology §3.2)

Each guardrail has: name, direction (`not below` / `not above` / `within`), tolerance.

- Tolerance is **absolute** unless prefixed `rel:`. Absolute `-5%` = 5 percentage-points; `rel:-5%` = 5% of baseline value.
- ANY single guardrail violated → `halt:guardrail-violated`. **Veto overrides Step 2** — guardrail can block a primary-metric win.

## Budget declaration schema (Tier 2)

Read from `budget:` block in bench-spec frontmatter, or from separate `budget.yaml` next to spec, or from §10-overrides in spec body.

```yaml
budget:
  max_cost_usd: 50.00          # cumulative cost cap across iterations
  max_wall_clock_hours: 24     # wall-clock from first iteration timestamp
  max_iterations: 20           # iteration count cap
```

Any subset of three may be declared. Undeclared keys → that sub-check is skipped with a one-line note.

## Progress detection (Tier 3)

Read last `M` iteration results. Default `M = 3`; override via `stop_rules.progress_window: <N>` in spec frontmatter.

For each of the last M iterations, extract `primary_metric.point_estimate` from `results.md` frontmatter. Compute pairwise differences:

```text
delta_i = abs(point_estimate[i] - point_estimate[i-1])
```

If `max(delta_i) ≤ ε` where `ε = δ / 4` by default (override via `stop_rules.progress_epsilon`), → `halt:no-progress`.

**Why δ/4**: the detection threshold should be tighter than the decision threshold, otherwise stagnation can hide a slow-but-real signal. δ/4 leaves 4 iterations of headroom before a real effect would clear δ.

If fewer than M iterations available → skip Tier 3 silently.

## Error cascade detection (Tier 4)

Read last K iteration directories. Default `K = 2`. An iteration "failed" if:

- `results.md` is missing AND `run.log` shows exception/error, OR
- `results.md` exists but has `verdict: error` in frontmatter.

If all K most recent failed → `halt:error-cascade`. A human should diagnose before next try.

## Multi-baseline cases

If the spec declares **paired-difference baseline** (re-runnable), Step 2 evaluates CI on `(model - baseline)` per item, decision point P = 0.

If the spec declares **fixed-reference scalar baseline** (published number, no per-item outputs), Step 2 evaluates one-sample CI on the model's own metric, decision point P = `reference_value`. Note that baseline variance is not captured — flag this in the evidence if it's the case.

**Disambiguation**: the spec MUST declare which type (in §4 Baseline). If ambiguous → `error:baseline-ambiguous`.

## What you do NOT decide

This skill does **not**:

- Decide whether the spec itself is well-designed. That's `/review-methodology`'s job, pre-lock.
- Suggest a new spec when proxy is falsified. That's `bench-spec-author`'s job.
- Run the next experiment. That's `research-iteration`'s job.
- Approve / reject iteration artifacts. That's audit subagents (`contradiction-hunter`, `clarity-validator`) called inside `research-iteration`.

Your boundary: read state, apply rules, emit verdict. Pure evaluation, no action.

## Edge cases that come up in practice

**Spec missing §10 budget block** — Tier 2 silently skipped. One-line note in evidence: *"No budget declared; recommend adding to spec for autonomous runs."*

**Iteration crashed mid-write (partial results.md)** — Frontmatter parsing fails → `error:results-corrupt`. Don't infer; human needs to inspect.

**Cumulative log out of sync with iter directories** — e.g., log says iteration 5 was last but `iter-5/` is absent. Trust the **filesystem**, not the log. Report mismatch as a side note.

**Multiple locked specs in repo** — Always require a path argument; do not auto-pick.

**Spec class = adopted or constructed (Step 0 N/A)** — Skip Tier 1 Step 0 entirely; go to Step 1 then Step 2.

**No prior iteration yet (loop just starting)** — Tier 1 N/A (no results to evaluate). Tier 2 budget cumulative = 0 (no halt). Tier 3 N/A. Tier 4 N/A. → `continue` with evidence note "first iteration".
