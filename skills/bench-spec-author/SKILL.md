---
name: bench-spec-author
description: Guide a researcher through authoring a bench-spec for a new research target — class selection, two-axis assembly (claim type × measurement source), §4 verdict logic with δ + baselines, §5 anti-Goodhart tripwires, §6 nomological predictions (proxy class), §7 contamination protocol, §10 overrides. Reads bundled bench-methodology + template, asks targeted questions only where the user's input is required, produces a draft spec ready for methodology review and then /lock-bench-spec. THIS IS THE ENTRY POINT — invoke this skill first on a fresh project with no prior spec. Also use when the user says "let's write a bench-spec for X", "spec out the E3 experiment", "draft a benchmark for our new research", "start a new research project", or hands you a research question and asks how to make it locked. The other loop-pipeline skills (`/check-stop`, `/lock-bench-spec`) all assume the output of this skill exists.
model: opus
---

# /bench-spec-author — interactive bench-spec authoring (entry point)

**This is the entry point of the loop-pipeline chain.** If you're on a fresh project with no `specs/bench-*-*.md` yet, this is where you start. The chain is:

```text
/bench-spec-author → draft → methodology review → revisions → /lock-bench-spec → /loop research-iteration ← → /check-stop
```

Subsequent skills assume a spec exists; this one creates it.

You are the **author's assistant** for producing a locked bench-spec. Your job is to convert a researcher's intent — a research goal, a fuzzy target, a paper outline — into a complete bench-spec draft that meets bench-methodology v0.8 requirements without imposing methodology choices you can derive from the methodology + the user's answers.

You don't run experiments. You don't lock anything (that's `/lock-bench-spec`). You don't judge the quality of the spec post-draft (that's the methodology-review pass). You produce a **filled draft** ready for review and lock.

> **Note on internal tool calls.** This skill orchestrates `Read`, `Write`, `Glob`, and `AskUserQuestion` (during the interview). These are tool calls Claude makes while executing the skill — you do not invoke them directly. The interview proceeds turn-by-turn; you answer at each prompt.
>
> **Note on filesystem layout.** This skill expects (and creates if missing) a `specs/` directory at the repo root. Downstream skills assume the layout:
>
> ```
> <repo>/
> ├── specs/
> │   └── bench-NNNN.md                   (draft; this skill writes here)
> │   └── bench-NNNN-locked.md            (after /lock-bench-spec; renamed)
> └── tasks/
>     └── <task-name>/
>         ├── iter-1/, iter-2/, ...       (the iteration loop writes here)
>         └── cumulative-log.md
> ```
>
> If `specs/` doesn't exist, this skill creates it. If `tasks/<name>/` doesn't exist, the iteration loop creates it on first run.

## When you fire

- New research target: user says "I want to measure X" / "let's spec the experiment for X" / "draft a bench-spec for X".
- Superseding spec: user says "spec the next round" / "we need to revise after iter-N retired the proxy" — read the prior spec + last `/check-stop` halt reason as context, draft superseder.
- Spec restart: user has a partial draft and is stuck on a section — pick up where they are.

Identify the mode in your first turn.

## Methodology assumed

You bundle `references/bench-methodology.md` and `references/bench-spec.template.md` — the v0.8 source-of-truth documents. Read them before asking the user anything. Most of what to write is already determined by methodology; your job is to surface only the **decisions that genuinely need the user**.

## The interview — what to actually ask

Don't ask 30 questions. Ask the **5 questions that determine everything else**:

### Q1: Target — what are you measuring?

"In one sentence, what is the research question this spec exists to answer?"

Listen for:
- The **target construct** (the thing you care about — concept hierarchy quality, model accuracy on X, embedding retrieval quality, etc.).
- Whether the construct is **observable** (e.g. ground-truth labels exist) or **latent** (no oracle).
- The **population / distribution** over which it's measured.

If the user is vague ("I want to understand if model X is good") — push back: "Good at what? On which inputs? Compared to what?" Don't proceed without precision.

### Q2: Class — adopted / constructed / proxy?

Walk the user through methodology §4's decision question: *"Are you measuring the benchmark's declared target, or using it as a stand-in for something unobservable you actually care about?"*

If the user picks **proxy** — confirm by asking: "Is there a third party who could look at your data and **directly** verify whether the construct is present? Yes → constructed. No → proxy."

This is the §4.4 boundary rule. Apply it strictly. Researchers default to "constructed" because it feels less risky, but constructed bench with a latent construct is **mis-classified** — they owe §6 nomological predictions and don't know it.

### Q3: Measurement source — own / public?

Independent of class (the two-axis assembly is the §4.3 fix to the prior "linear stack" misconception):

- **own**: your project authored the held-out splits. You can embed canary GUID. Provenance is yours.
- **public**: you pin a release of an external benchmark (MTEB v1.2.0, MMLU @ huggingface-revision-X, etc.). You can't embed canary; contamination detection falls back to canonical-completion / membership-probe / provenance.

Public + proxy is legitimate (MMLU as proxy for "model knowledge"). Don't let class choice railroad source choice or vice versa.

### Q4: Baseline — re-runnable or fixed-reference?

The decision rule in §4 forks on this. Ask:

- "Can you execute the baseline model on your exact eval items?"
  - **Yes** → re-runnable baseline. Paired-difference CI applies. Stronger.
  - **No** → fixed-reference (published number, no per-item outputs). One-sample CI on your model's own metric vs the reference. Weaker; declare baseline variance not captured.

If the user has a published number AND access to the model — push to re-runnable. The methodology prefers it.

### Q5: Stakes / lock_tier — conventional or cryptographic?

- "Will this spec be cited in a published artifact, peer-reviewed work, or external collaboration?"
  - **Yes** → `lock_tier: cryptographic`. Set up signed annotated tag + protected ref. `/lock-bench-spec` will preflight the requirements.
  - **No** (internal pilot, exploratory work) → `lock_tier: conventional`.

Template default is `conventional` (bench-methodology §3.5 + template frontmatter comment). Do **not** force `cryptographic` on uncertainty — that overrides template default for solo / internal use, increasing setup friction without payoff. **Recommend** `cryptographic` for any user who answers "maybe" to publication, but leave the choice to them.

### Q6: Budget envelope — what halts the loop on cost / time / iteration count?

Even for tightly-bounded internal pilots, autonomous loops without budget guardrails burn money. Ask the user to declare three caps (any can be left `null` / unset, but at least one should be present for `/check-stop` Tier 2 to function):

- `max_cost_usd`: cumulative cost across all iterations (API + compute).
- `max_wall_clock_hours`: from first iteration timestamp.
- `max_iterations`: hard cap on iteration count.

Defaults to suggest (the researcher should adjust):

- Internal pilot: `max_cost_usd: 50`, `max_wall_clock_hours: 24`, `max_iterations: 20`.
- High-stakes publication-bound: `max_cost_usd: 500`, `max_wall_clock_hours: 168` (1 week), `max_iterations: 100`.

Write to bench-spec frontmatter as a `budget:` block (or to a separate `budget.yaml` next to the spec — `/check-stop` reads either).

If the user explicitly declines a budget, document this with a `# budget: null — accepting unbounded autonomy on user authority` note. `/check-stop` will silently skip Tier 2 and emit a one-line warning.

### Q7: Peer-reviewer relationship to optimization loop

Frontmatter requires `peer_reviewer: <name>`. The methodology criterion (§3) is **"outside the optimization loop"** — has not contributed code/decisions to the model/script under measurement.

Ask explicitly: "Has the person you named in `peer_reviewer` contributed any code, hyperparameters, or design choices to the model/script that will be measured by this spec?"

- **No** → they qualify. Document their relationship in a one-line note next to `peer_reviewer` (e.g., `# methodology reviewer, did not touch model code`).
- **Yes** → they don't qualify per the methodology criterion. Two options:
  - Find a different reviewer who didn't contribute to the model.
  - If no qualified outside reviewer is available (solo project, no collaborators): explicitly declare this limitation in §1 Target — `Limitation: no peer reviewer outside the optimization loop was available; this spec is self-reviewed only`. The spec can still be locked, but downstream readers see the limitation as part of the audit trail. `/lock-bench-spec` will accept this self-declaration.

This is the only audit trail mechanism for the methodology's "outside the loop" criterion. Skipping the question relegates it to "anyone could be named", defeating the discipline.

## After the interview — fill the template

Based on Q1–Q5, you can fill **most** of the template without further user input:

### Frontmatter (mechanical)

- `id`: ask for the bench number (probably next available `bench-NNNN`).
- `title`: 1-line summary from Q1.
- `owner`: user's name / github handle.
- `class`, `measurement_source`, `lock_tier`: from Q2/Q3/Q5.
- `methodology_version`: 0.8 (bundled).
- `status`: draft.
- `created`: today.
- `locked` / `locked_at_utc` / `lock_tag` / `heldout_hash`: leave blank.
- `peer_reviewer`: ask for at least one name.
- `model_under_test`: ask for concrete model id + commit (or scale series with explicit members).
- `supersedes`: ask if this revises a prior spec.
- `related_tasks`: tasks that will produce results against this spec.

### §1 Target

One-paragraph expansion of Q1. Include:
- Construct name + brief definition.
- Population / distribution (which inputs, which model class, which context).
- Decision the measurement supports (why this matters).

Then **one paragraph "why this matters"** — what choice depends on the answer.

### §2 Class declaration

- Pick from Q2.
- Rationale paragraph: WHY this class fits the target. Reference §4.4 boundary rule explicitly if proxy was chosen for a latent construct.
- Include the proxy design-constraints forward-pointer block from the template (convergent ρ ≥ 0.50, ratio 2×, §10 defaults inheritance).

### §3 Measurement procedure

This is where the user must contribute concrete details:

- **Eval script path** — ask. Path-pin format: `scripts/eval/<name>.py @ <to-be-filled-at-lock>`. Don't invent a sha; placeholder until lock.
- **Inputs** — ask. Data paths, model checkpoint refs, config files. Pinned by hash or commit (or `<to-be-filled-at-lock>`).
- **Outputs** — what the script produces. The user should know.
- **Determinism**:
  - Seed list — propose using §10 default (≥10 constructed/adopted, **≥20 proxy**). Ask user to confirm or override; don't pre-fill seeds (just write `[seed_1, ..., seed_N]` placeholder with N specified).
  - Item count — ask.
  - Dependency pins — `hash of uv.lock` placeholder; user fills at lock.
  - Non-determinism sources — ask user to list (GPU model, CUDA version, known non-bitwise ops).
- **Runtime envelope** — ask user to estimate per-seed wall time, GPU-hours, dollar cost.

### §4 Acceptance criteria

- **Primary metric** — ask for name + precise definition.
- **Baseline** — from Q4. If re-runnable: `<model id + commit>`. If fixed-reference: `<published value> from <source>`.
- **Decision rule** — derive from baseline type:
  - Re-runnable: "two-level bootstrap 95% CI on paired difference (model − baseline) over the same seeds × items excludes 0 + δ".
  - Fixed-reference: "two-level bootstrap 95% CI on the model's own metric excludes (reference_value + δ)".
- **δ** — ask user. Suggest the user reference §10's δ-selection rule (one of: ≥ 1 SD of baseline variance OR downstream-meaningful threshold). Require rationale.
- **Power** — δ_min the design must detect + the seed/item budget that gives ≥ 0.8 power. Help user reason about this if they're new to it.
- **Guardrails** — ask for **≥2** (per §3.2). Suggest categories: quality metric that may not regress, runtime / cost guardrail, fairness / calibration guardrail. Each with direction + tolerance (absolute unless `rel:` prefix).
- **Stop rule** — propose: "halt if any guardrail violates while primary improves". Confirm with user.
- **Verdict categories** — copy the template's block verbatim. Include the verdict-time vs lock-time header.

### §5 Anti-Goodhart safeguards

For each of the 4 Manheim variants (Regressional / Extremal / Causal / Adversarial), help the user think through:

- **Risk** for this specific project.
- **Tripwire** — concrete runnable check.

If a variant truly doesn't apply: `N/A — <reason>`. But push back on `N/A` for Adversarial in any proxy spec — proxies are gameable by definition.

### §6 Proxy validity *(proxy class only)*

- **Convergent-Discriminant Matrix**: walk the user through identifying:
  - ≥2 independent operationalizations of the construct (rows).
  - ≥2 confound constructs (columns).
  - Pairwise convergent ρ ≥ 0.50 and ≥ 2× each discriminant |ρ|.
  - Optional criterion column (only if an independent observable criterion exists — most latent constructs have none, and that's fine).

- **Nomological predictions**: help user write **≥3** predictions. For each, pick a type (A/B/C) and specify type parameters (δ_min, δ_eq / δ_max, margin). This is the most technically demanding section — walk slowly. Confirm power for each.

- **Falsification rule**: copy the template's per-type block verbatim.

### §7 Contamination protocol

Pick detection methods per the model class under test (template's bulleted list). For `measurement_source: own`, include `generated_canary: <generated-at-lock>` placeholder (don't generate now; `/lock-bench-spec` does that). For public, walk user through canonical-completion or provenance audit.

### §8 Replacement protocol

- Retirement conditions: ask user to enumerate (canary leaked, deps deprecated, target shifted, replicated by community, provenance broken).
- Versioning: standard ("new spec supersedes; old stays locked").
- Frozen forever — three guarantee tiers: copy from template.
- Replay degradation policy: concrete rules per the bench-spec — ask user to specify δ for "drift acceptable", what counts as substitution acceptable, etc.

### §9 Confirmatory commitments

- Pre-registered analyses (each mapping to §4 or §6 element).
- Pre-registered prediction directions (sign + magnitude table).
- Multiple comparisons: Holm correction if ≥2 analyses jointly claim significance (confirmatory context only).
- Exploratory reservation: results in `exploratory.md`, never moved to confirmatory retroactively.

### §10 Overrides

Only fill if user explicitly overrides a default. Otherwise empty; defaults inherit silently.

## After draft is complete

Write the draft to `<repo>/specs/bench-NNNN.md` (status: draft). Then:

1. **Self-completeness check**: scan the spec — is every section filled? Any `<to-be-filled-at-lock>` placeholders left? List them; that's the lock checklist.

2. **Hand-off**: report to user:

```markdown
## Draft complete: bench-NNNN

- Path: specs/bench-NNNN.md
- Status: draft
- Class: <class>
- Measurement source: <source>
- Lock tier (declared): <tier>

## Open placeholders (to fill at lock)
- {list of `<to-be-filled-at-lock>` and blank fields with their template requirements}

## Recommended next steps
1. Run a methodology review against this draft to surface design issues before lock.
2. Have peer reviewer (<name>) review §1-§6 conceptually.
3. When ready, run `/lock-bench-spec` to freeze.

The spec is currently editable. Once locked, it becomes immutable; corrections require a superseding spec.
```

## Anti-patterns — what NOT to do

- **Don't pre-fill the user's content with plausible-sounding text.** Empty placeholders are honest; fabricated content is research fraud waiting to happen. If you don't know, ask. If user doesn't know, leave blank with a clear placeholder comment.
- **Don't skip §5 anti-Goodhart safeguards "because the user is in a hurry".** This is the section most likely to save the research from invalidity. Even one-line `N/A — reason` for each variant beats skipping.
- **Don't auto-decide proxy class to constructed because "constructed feels less risky".** Apply §4.4 boundary strictly. Misclassified constructed-with-latent-construct is the #1 methodology bug in proxy research.
- **Don't make up δ.** Force the user to derive it from baseline variance or downstream-meaningful threshold (§10). "Just pick 0.05" is not a design.
- **Don't reuse §6 Convergent-Discriminant matrix from a different bench-spec.** Each construct has its own confounds; copying matrices is how you mis-target.

## Example invocations

```text
# Brand-new project, research question stated
/bench-spec-author "linear decodability of NLP embedding hierarchy on ACM CCS labels — proxy class, own held-out"

# Vague target, skill leads the interview
/bench-spec-author

# Superseding spec after prior was retired (proxy falsified)
/bench-spec-author --supersedes specs/bench-0003-locked.md
```

## Related skills

- A methodology-review pass (if your workspace ships one) — runs after this skill, before lock. Three-subagent depth review for rigor / consistency / completeness / overclaiming / actionability / honesty.
- `/agent-pack-core:lock-bench-spec` — runs after review, transitions draft → locked.
- A research-iteration loop body (if your workspace ships one) — runs against the locked output.
- `/agent-pack-core:check-stop` — evaluates the locked output's verdict logic against iteration results.

## References

- `references/bench-methodology.md` — full methodology document (v0.8). Read this before any interview.
- `references/bench-spec.template.md` — fillable template. Your output structure follows this exactly.
- `references/authoring-pitfalls.md` — common mistakes in spec authoring (proxy misclassification, weak δ rationale, missing guardrails, etc.). Includes the §7.3 power-claim fix (≥47 scale points, not ≥8) — required reading for proxy-class authors.
