---
name: onboarding
description: Orient a newcomer to agent-pack-core — what the pack is for, which skills exist and when to reach for each, how to use goal-launch safely, and the key conventions. Use when someone has just installed the pack, asks "what can this pack do?", "where do I start?", "what skills are here?", or needs a map before diving in. Also use when introducing a teammate to the pack or resuming after a long gap. Read-only; emits orientation text only.
---

# agent-pack-core — orientation

This pack is a portable, evidence-first toolkit for Claude Code. Not a catalog of "do task X" wrappers. The premise: reliable engineering and research work requires **proof, not recall** — every skill cites `file:line` or command output as evidence, gates are first-class citizens, and the pack improves itself via `session-reflect`.

Install once; all skills become available:

```bash
/plugin marketplace add izgorodin/agent-pack-core
/plugin install agent-pack-core@agent-pack-core
```

Or run from a local checkout without installing:

```bash
claude --plugin-dir ../agent-pack-core
```

---

## Skills — four groups

### 1. BDD / workflow cycle

Work a feature from fuzzy idea to reviewed and merged, with discipline at every step.

| Skill | When to reach for it |
|---|---|
| `describe-task` | Translate a fuzzy request into a precise behavior statement and deliverables list. Run this **before** writing any tests or code. |
| `write-failing-tests` | Write red tests from the spec. Each test must fail with a meaningful assertion error, not just an import error. |
| `make-green` | Implement the **minimum** code that turns red tests green. No gold-plating; no refactoring during green phase. |
| `commit-and-pr` | Run the local quality gate, generate a commit message from the diff (not memory), commit, and open a PR. Refuses to commit if the gate fails. |
| `address-review` | Read PR comments, classify each (accept / push back / partial / defer), apply changes, re-run the gate, push. Does **not** auto-resolve threads — that is the reviewer's call. |
| `pr-preparation` | Polish a multi-commit branch for review — squash/reword messy commits, generate the PR body from the actual diff. Use when wip/fmt commits accumulated over several sessions. Prefer `commit-and-pr` for a single clean session. |
| `session-reflect` | Turn session observations into concrete infrastructure updates — skills, rules, CI, memory, ADRs. Not a journal; each finding routes to a durable artifact or is dropped. |
| `merge-readiness` | Final GO / NO-GO gate before proposing any merge. Every criterion is backed by a command you ran or a line you read. Assertion without evidence is FAIL. Never auto-merges — that is always the human approver's call. |
| `bdd-workflow` | The 9-step conductor. Orchestrates `describe-task → write-failing-tests → make-green → commit-and-pr → push → review → address-review → reflect`. Use when you want the full cycle with checkpoints at each transition. |

### 2. Bench / experiment research pipeline

A disciplined pipeline for reproducible research and autonomous experimentation.

```
bench-spec-author → draft → review → lock-bench-spec → iteration loop ←→ check-stop
```

For operator-driven (non-autonomous) runs, use the experiment chain:

```
experiment-design → run-experiment   (or experiment-campaign for a sweep)
```

| Skill | When to reach for it |
|---|---|
| `bench-spec-author` | Interactive interview → filled draft bench-spec. Entry point for a fresh research project. |
| `lock-bench-spec` | Mechanical lock: validate frontmatter, commit, and create + push the git tag. The sole path from `status: draft` to `status: locked`. |
| `check-stop` | Four-tier autonomous-loop halt evaluator. Fires before and after each iteration; returns `continue` or `halt:<reason>`. |
| `experiment-design` | Design a single operator-driven run: paradigm, hypothesis, baseline, method, metrics, success criteria. Run before `run-experiment`. |
| `run-experiment` | Execute a designed experiment: pre-flight, background run, post-run validation, mandatory report, and registry entry. No unnamed runs. |
| `experiment-campaign` | Unattended loop over a run list: paces background jobs, stops on regression or budget breach, maintains a running campaign report. |

### 3. Orchestration / agentic

| Skill | When to reach for it |
|---|---|
| `goal-launch` | Compose and launch an unattended `/goal` run with a 6-element transcript-provable stop condition, sandboxed worktree, and a layered safety stack. Refuses to launch if any of 8 preconditions fail (see safety section below). |
| `spawn-worker-subagent` | Fan out 2–4 independent tasks to parallel worktree-isolated worker sub-agents, then aggregate PRs and DX findings. Trigger when you have 2–4 independent issues to close in parallel. |

### 4. Pack tooling

| Skill | When to reach for it |
|---|---|
| `validate-plugin-marketplace` | Lint a `marketplace.json` or `plugin.json` for the gotchas that produce confusing install-time errors. Read-only; never modifies the manifest. |
| `skill-creator` | Create, iterate, and eval new skills. Vendored from Anthropic (Apache-2.0, unmodified). |

---

## Using `goal-launch` safely

`goal-launch` composes a `/goal` run — it **does not run the goal itself**. It produces a paste-ready launch command after verifying 8 hard preconditions. Know these before you start.

### 8 hard gates (all must pass)

- **G1** — Main branch protected on GitHub. 403 on free private repos is treated as skip-with-warning, not hard fail (reading protection state is itself a GH Pro feature; defense falls back to L11 pre-push hook + condition negative-assertions).
- **G2** — Current branch must NOT be `main`, `master`, `develop`, or `production`.
- **G3** — Working tree must be clean (`git status --porcelain` empty).
- **G4** — On Windows: must be inside WSL2 or Docker microVM — native PowerShell is refused. On Linux/macOS: sandbox must be active.
- **G5** — The condition must contain all 6 elements (see below).
- **G6** — All three caps declared: `--max-turns`, in-condition turn-cap, and external wall-clock timeout.
- **G7** — For wave-disciplined runs (Pattern C only): a `rubric.md` must exist and be referenced in the condition.
- **G8** — Prod-class credentials (`*_PROD`, `STRIPE_SECRET_KEY`, `AWS_*`, etc.) must be unset before launch.

### The 6-element condition (every element required)

1. **End-state** — measurable, mechanical.
2. **Evidence clause** — "X was invoked via the Bash tool IN THE CURRENT TURN and the tool result is visible in the transcript."
3. **Positive check** — command + expected output.
4. **Negative assertion** — transcript MUST NOT contain [forbidden side-effect markers].
5. **Scope constraint** — declared files-in / files-out.
6. **Turn/time cap** — in-condition cap AND mechanical `--max-turns`.

### What ships vs what does NOT ship

`launch-windows.ps1` and `launch-posix.sh` ship: G1–G8 preconditions + L4 prod-cred scrub + L8 external watchdog + L11 pre-push hook.

They do **not** ship: the OS sandbox (operator setup), worktree creation (the script refuses on a protected branch and tells you the `git worktree add` command — you run it), or the L12 shell-wrapper denylist (operator step).

### When NOT to use `/goal`

- End-state is subjective ("looks good", "production-ready")
- Proof requires external state not visible in the transcript
- Run touches production credentials or signing keys
- Objective is safety-critical (SQL migrations against a live DB)

---

## Key conventions

**Evidence before assertion.** Every claim the pack's skills make is backed by `file:line` or actual command output. A claim with no evidence is a rumour, not a fact. If you cannot produce evidence, write "unverified" — never assert it.

**Green gate ≠ correctness.** A passing gate proves consistency with its own tests — not truth. The pack distinguishes: *ran-and-saw* vs *looks-consistent* vs *judgment*.

**User approves before infrastructure changes.** `session-reflect` always shows a proposed batch and waits for approval before applying any skill, rule, hook, or CI update. Self-modification requires explicit confirmation.

**No auto-merge.** `merge-readiness` produces a recommendation, not a merge action. The human approver holds that decision.

**Commit messages from the diff, not from memory.** `commit-and-pr` reads `git diff --staged` before writing the message.

**Profiles parameterize the experiment skills.** The bench/experiment skills are domain-agnostic; they read concrete values (metrics, replicate rule, registry path) from a profile you write. Copy `profiles/_example-profile.template.md` to start.

**No workspace paths baked in.** Skills detect your stack (pyproject.toml / package.json / go.mod / Cargo.toml) and read your project's conventions. Nothing assumes a specific directory layout, language, or credential location.

**`skill-creator` is vendored from Anthropic (Apache-2.0, unmodified).** All other skills are original to this pack. See `NOTICE` and `skills/skill-creator/LICENSE.txt`.

**Pin for reproducibility.** Skills can change between versions. Pin to a tag or commit when you add this pack; review the diff before bumping the pin.

---

## Quick reference

| I want to… | Skill |
|---|---|
| Start a feature from a fuzzy idea | `bdd-workflow` or `describe-task → write-failing-tests → make-green` |
| Commit and open a PR after tests are green | `commit-and-pr` |
| Clean up a messy multi-session branch before PR | `pr-preparation` |
| Address reviewer comments | `address-review` |
| Check if a PR is safe to merge | `merge-readiness` |
| Turn session learnings into system improvements | `session-reflect` |
| Fan out 2–4 tasks in parallel | `spawn-worker-subagent` |
| Launch an unattended `/goal` run | `goal-launch` |
| Design and run a benchmark | `experiment-design` + `run-experiment` |
| Run a full benchmark sweep unattended | `experiment-campaign` |
| Start a pre-registered research project | `bench-spec-author` → `lock-bench-spec` |
| Check if a research loop should halt | `check-stop` |
| Create or improve a skill | `skill-creator` |
| Lint a marketplace manifest | `validate-plugin-marketplace` |
