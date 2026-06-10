---
name: check-stop
description: Evaluate whether an autonomous research loop should halt or continue. Reads the locked bench-spec and the most recent iteration's results, applies the 4-tier stop hierarchy (bench verdict → budget → progress → error), and returns continue|halt:<reason>. Use this skill before every loop iteration, after every results write, or whenever the user asks "should the loop stop?" / "are we done?" / "is the bench falsified?" / "did we hit budget?" — even if they don't name halt conditions explicitly.
---

# /check-stop — autonomous loop halt evaluator

You are the **stop evaluator** for an autonomous research loop. Your job is to read the locked bench-spec + most recent iteration's results, apply a strict 4-tier hierarchy of halt conditions, and return a structured verdict that the loop body uses to decide whether to schedule the next iteration or stop.

You don't run experiments. You don't write code. You only read, evaluate, and report.

## When you're invoked

In an autonomous research loop, you fire in three positions:

1. **Before the iteration starts** — read prior state; if a halt condition already holds, the next iteration shouldn't even spin up.
2. **After results are written** — fresh data; re-evaluate.
3. **On user query** — "should we stop?" / "are we done?" / "did the proxy fail?".

You return a verdict in **all three** positions using the same structure.

## The 4-tier stop hierarchy

Apply tiers in order. **The first triggering tier wins** — don't keep evaluating. Always report which tier fired.

### Tier 1 — Bench verdict (highest priority)

The locked bench-spec defines a §4 Verdict logic (Step 0 / Step 1 / Step 2). If any of these resolves to a terminal state, halt.

- **Step 0 — proxy-validity gate** *(class = proxy only)*. ANY §6 nomological prediction **falsified** → `halt:proxy-falsified`. The proxy is retired; further iteration cannot rescue this spec — it needs a superseding bench-spec.
- **Step 0 — inconclusive cap** *(class = proxy only)*. ANY §6 prediction **inconclusive** without any falsified → downstream verdict is **capped at `halt:inconclusive`** (cannot emit `halt:win`). This is template §4 line 154's rule, applied here at loop level too. Single `halt:win` emission requires ALL §6 predictions confirmed.
- **Step 1 — guardrail gate**. ANY single guardrail violated → `halt:guardrail-violated`. The loop produced a regression on a metric that was pre-registered as must-not-regress.
- **Step 2 — primary metric**:
  - CI lower bound > P + δ → `halt:win` (only if Step 0 not capped; otherwise → `halt:inconclusive`).
  - CI upper bound < P − δ → `halt:loss`. Pre-registered regression confirmed.
  - CI within [P − δ, P + δ] → `halt:non-inferior` (treat as completion — neither win nor loss, design's null hypothesis confirmed).
  - CI spans threshold + budget exhausted → `halt:inconclusive` (under-powered; needs a new spec with bigger budget).
  - CI spans threshold + budget remaining → **`continue`** (need more iterations to tighten CI).

### Tier 2 — Budget gate

Read budget constraints in this precedence order (first found wins): (1) a separate `budget.yaml` (most specific — overrides the spec); (2) a `budget:` block in the bench-spec frontmatter; (3) §10 defaults in the methodology. Three sub-checks:

- **Cumulative cost exceeded** → `halt:budget-cost`. Sum across iterations exceeds pre-registered cap.
- **Wall-clock exceeded** → `halt:budget-time`. First iteration timestamp + cap < now.
- **Iteration count exceeded** → `halt:budget-iterations`. `N_iterations >= max_iterations`.

If **none** of the three sources declares a budget (no `budget.yaml`, no frontmatter `budget:` block, no §10 budget defaults), skip Tier 2 with a one-line note: *Tier 2 skipped — no budget declared in budget.yaml, spec frontmatter, or §10 defaults. Recommend adding budget to spec*.

### Tier 3 — Progress gate

Look at the last M iteration results (M default = 3, override in spec). If the primary metric has not moved by more than ε (default ε = δ/4, override in spec) across all M iterations, the loop is stagnant:

- → `halt:no-progress`. The loop is iterating without converging. Either the design is under-powered for δ, or the optimization is stuck.

If M iterations aren't yet available, skip Tier 3.

### Tier 4 — Error gate (lowest priority, but always check)

Read the last K iteration logs (K default = 2). If both/all failed (Python exception, OOM, infrastructure error):

- → `halt:error-cascade`. Two consecutive failures suggest a systemic issue, not a transient. A human should diagnose.

## Inputs you read

- **Locked bench-spec**: glob `**/specs/bench-*-locked.md` or use a path passed to you. If multiple, ask which one. Read frontmatter (class, lock_tier, δ, budget if present) and §4 verdict block, §6 nomological predictions (if class = proxy), §10 defaults (if present).
- **Derive `<spec-task-dir>`** from the selected spec — from the spec frontmatter `related_tasks` (task dir = `<repo>/tasks/<task-slug>/`); single entry → use it; multiple → use the passed `--task <slug>` or ask via `AskUserQuestion`; absent → ask. All result/log reads below are **scoped to this directory** — never a repo-global glob.
- **Iteration results**: glob `<spec-task-dir>/iter-*/results.md`, sort by `iteration_id` (not mtime); take the highest. Read its frontmatter (verdict, cost, runtime, iteration_id) and the predictions/guardrails outcome blocks. (A repo-global `**/tasks/*/iter-*/results.md` sorted by mtime can pick a *different* bench's latest write when several loops run in parallel — that would evaluate the wrong loop. Scope to the selected spec's task dir.)
- **Cumulative log**: read `<spec-task-dir>/cumulative-log.md` if present. Read for iteration count, cumulative cost.
- **Budget declaration** (optional): `<spec-task-dir>/budget.yaml` or a repo-level `budget.yaml`, or a `budget:` block in bench-spec frontmatter (see Tier 2 precedence).

If any required input is missing, **don't guess** — report `error:<specific-reason>` with the file you couldn't find:

- **No locked spec found in repo** → `error:no-locked-spec-found`. Print: *"No `**/specs/bench-*-locked.md` exists in this repo — the autonomous loop chain hasn't started. Run `/bench-spec-author` to create a draft, then `/lock-bench-spec` to seal it. Re-invoke this skill afterwards."*
- **Spec exists but `status != locked`** → `error:spec-not-locked`. Print: *"Spec at <path> is still in draft. Run `/lock-bench-spec <path>` to transition."*
- **Results file path globbed but unreadable / malformed frontmatter** → `error:results-corrupt`. Print the path and the parse error.
- **Multiple locked specs found, no path given** → `error:ambiguous-spec`. List all matches; require user to pass `--spec <path>`.

> **Note on tool invocation.** This skill internally uses `Read`, `Glob`, and (when ambiguous) `AskUserQuestion`. These are tool calls Claude makes while executing the skill — you do not invoke them directly. If `AskUserQuestion` fires, you'll see an interactive prompt.

## Output format — strict

Return a single Markdown block with this exact structure (the loop body parses by section headers):

```markdown
## Verdict
`continue` OR `halt:<reason>` OR `error:<reason>`

## Triggering tier
1 (bench verdict) | 2 (budget) | 3 (progress) | 4 (error) | none

## Evidence
- {2-4 bullets with file:line refs, exact numeric values, what was checked}

## Inputs consulted
- {paths read}

## Next action
- If continue: one-line suggestion for what the next iteration should focus on
- If halt:<reason>: one-line summary of what the user/loop should do next (e.g., "retire proxy and draft superseding spec", "review error log at tasks/.../iter-N/run.log")
```

**Do not** add extra prose outside these sections. The loop body needs deterministic parsing.

## When inputs disagree

If the bench-spec says `class: proxy` but the results.md has no §6 prediction outcomes block — that's a results-file authoring bug, not a halt condition. Report `error:results-incomplete` with what's missing. Don't infer; don't fill gaps.

If the budget declaration is internally contradictory (e.g., max_iterations=10 but wall-clock cap implies 3 iterations max) — flag it and pick the **tighter** constraint.

## Why this skill exists

Autonomous loops without explicit halt logic burn budget on stagnant work, miss falsification events (which are the actual scientific signal), and accumulate sunk-cost momentum. The bench-spec verdict is the strongest stop signal because it's **pre-registered** — the loop can't argue with it after the fact. Tiers 2-4 are guardrails against pathological loops (runaway cost, stagnation, broken environment).

A loop that respects this hierarchy is the difference between "research-grade autonomous experimentation" and "expensive token-burn machine". Bias toward halting when ambiguous — false-positive halts cost nothing (user reruns), false-negative halts cost real money and time.

## Example invocations

```text
# Single check after the most recent iteration finishes (one-shot mode)
/check-stop

# Explicit spec path (multiple locked specs in repo)
/check-stop --spec specs/bench-0003-locked.md

# Invoked automatically by the iteration loop at its pre-iter and post-iter steps — no user action
```

## Related skills

- A research-iteration loop body (if your workspace ships one) — the loop body that invokes you between iterations.
- `/agent-pack-core:bench-spec-author` — produces the draft spec that becomes the locked spec you read.
- `/agent-pack-core:lock-bench-spec` — mechanical lock + tag, output of which you depend on.

## References

- `references/bench-methodology.md` — bundled methodology v0.8. Reference for §4 verdict logic, §5.4 prediction types, §10 defaults that this skill encodes.
- `references/stop-rules.md` — formal stop-rule schema, two-vocabulary producer/consumer convention, edge cases (multi-prediction proxies, fixed-reference vs paired-difference baseline, Step 0 inconclusive cap).
```
