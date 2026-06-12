---
name: commit-and-pr
description: Run the full pre-push quality gate locally, run an adversarial self-review of the diff (a green gate is not correctness), fold any pre-commit auto-fixes (trailing-whitespace, EOL, format) into the staged set so the commit lands in one shot, generate a real commit message from the actual diff, commit, and open a pull request via gh CLI. Use this after `/make-green` produces green tests, or whenever the user says "commit and open a PR", "ship this", "let's PR", "wrap this up for review". Refuses to commit if the gate fails — that's the entire point.
---

# Commit and open a PR — step 5 of the BDD workflow

Tests are green, code is in, you're ready to package the work for review. Your job: prove locally that the same gate the pre-push hook will run still passes, run an adversarial self-review of the diff, fold any pre-commit auto-fixes (trailing whitespace, EOL, formatter) transparently into the staged set, generate a commit message from the diff (not from imagination), commit, then open a PR.

The asymmetry to honor: pushing broken work wastes a reviewer's time and your CI minutes. The 30 seconds you save by skipping the gate locally costs 30 minutes of "why did CI fail" investigation later.

## Step 1 — Verify branch state

```bash
git status
git branch --show-current
```

Required:
- Branch is **not** main / master / develop
- Working tree has staged changes (the green-phase work)
- At least one commit ahead of the base will exist after this skill runs

If you're on main, refuse to proceed and ask the user to create a feature branch first.

## Step 2 — Run the same gate the pre-push hook runs

Run the repo's declared quality gate — whatever the project's pre-push hook / CI runs. Detect the stack and use its gate, for example:

```bash
# Python (pyproject.toml): pytest + ruff + mypy
uv run pytest -q && uv run ruff check src tests && uv run mypy src/<package>

# JS/TS (package.json): test + lint + typecheck
pnpm test && pnpm lint && pnpm typecheck

# Go:     go test ./... && go vet ./...
# Rust:   cargo test && cargo clippy
```

If the repo declares its gate elsewhere (a `Makefile` target, a `just` recipe, a CI workflow), run that instead. The principle is identical regardless of stack: run the exact gate that gates the push.

If any check fails, **stop and report**. Don't commit, don't push, don't try to "fix it real quick" — surface the failure and the user decides whether to fix in this session or revert and rewrite.

If the repo has a `.git/hooks/pre-push` already installed (the repo's maintainer manages the pre-push hook separately), running the gate locally is still valuable: catching a failure pre-commit avoids the worse experience of pushing and getting blocked.

## Step 3 — Self-review the diff (adversarial pass)

A green gate proves the change passes its own tests — not that it's correct. Before packaging the work for a human reviewer, run an adversarial review of the staged diff: `/code-review` at high effort if available, otherwise independent reviewer subagents — several finder angles over the diff (line-by-line; what did deleted/replaced lines guarantee; who else calls the changed code) with a verifier pass over each candidate finding.

Why this step is non-negotiable: in one measured session, two PRs with green tests, green types and green lint carried **20 verified defects** between them — including a fix that didn't cover the primary code path it claimed to fix, and a widened shared constant that silently changed two sibling features' behavior. None of it was visible to the Step 2 gate.

Every CONFIRMED finding gets one of exactly two treatments:

- **Fix now** — fold the fix into this branch (back through `/make-green` if tests are affected), then re-run Step 2.
- **Accept consciously** — write the finding and the acceptance reason into the PR body, so the reviewer gets the context for free.

Silently dropping a finding is not an option.

## Step 4 — Fold pre-commit auto-fixes into the staged set

If the repo has `.pre-commit-config.yaml`, some hooks are *auto-fixers* (`trailing-whitespace`, `end-of-file-fixer`, `ruff format`, etc.). When `git commit` invokes them and they modify a file, pre-commit **aborts the commit** and asks you to `git add` and try again. That is correct framework behavior — pre-commit doesn't want to silently change what you're committing — but it produces a two-pass dance that costs every contributor ~30 seconds per occurrence (plus the cognitive cost of noticing the abort and re-pasting a long heredoc commit message).

This skill collapses that dance into a single transparent step. **Skip Step 4 entirely if the repo has no `.pre-commit-config.yaml`.**

Run the auto-fixers explicitly on the **staged set**, before the commit happens:

```bash
# capture the list of staged paths into a shell array
mapfile -t staged < <(git diff --staged --name-only)

# run pre-commit on exactly those paths (won't touch unrelated working-tree changes)
pre-commit run --files "${staged[@]}"
```

(Equivalent on platforms without `mapfile`: `staged=$(git diff --staged --name-only); pre-commit run --files $staged`.)

Three outcomes to handle:

| Outcome | What you see | What to do |
|---|---|---|
| All hooks `Passed` / `Skipped` | No `Fixing ...` lines | Continue to Step 5. |
| Some hooks emit `Fixing <path>` | The named files appear in `git status` as **both** staged (old version) AND unstaged-modified (the auto-fix). | Re-stage **only** those paths: `git add <those-paths>`. Tell the user explicitly: *"pre-commit auto-fixed: file1.md, file2.py — folding into commit"*. Continue. |
| A non-fix hook reports `Failed` (e.g. `mypy`, `ruff check`, `pytest`) | The Step 2 gate should have caught this; if it slips through here, surface the output verbatim and **stop**. | Do not commit. The user fixes manually and re-runs the skill. |

**Critical:** never `git add -u` or `git add .` to re-stage. Both pick up unrelated tracked-file changes the user did not intend to commit. Re-stage only the specific paths pre-commit reported as `Fixing`.

If an auto-fix introduces a new lint/type error (rare, possible with aggressive `ruff format`), Step 6's commit will fail when the same hooks run again. Handle that as a normal lint failure: surface and stop.

## Step 5 — Read the diff and write a real commit message

```bash
git diff --staged
git diff --staged --stat
```

Read it. Don't paraphrase from memory. The commit message comes from what actually changed. (After Step 4 the staged set may include trailing-whitespace fixes — that's expected and won't change the substance of the diff.)

**Subject line** (the first line):
- Imperative mood: "Add session invalidation on logout", not "Added" or "Adding"
- Under 70 characters
- No trailing period
- No emoji prefix unless the repo's CONTRIBUTING.md asks for them
- No `[WIP]` for a real PR (use `--draft` flag instead)

**Body** (after blank line):
- One paragraph explaining the **why**, not the what (the diff shows the what)
- Reference issue/ADR if relevant: `Closes #123` or `Implements ADR-008`
- If non-obvious tradeoffs were made, name them in one line each

Example:

```
Add session invalidation on logout

Previously the logout endpoint cleared client-side cookies but left the
server-side session record intact, leaving a window where a stolen cookie
could still authenticate. The new code revokes the session on the server
the moment logout is called.

Closes #142.
```

## Step 6 — Commit

```bash
git commit -m "<subject>" -m "<body>"
```

Because Step 4 already folded the auto-fixes, this commit should land in one shot — no `Fixing ...` abort. If it still aborts, the cause is a different hook (e.g. an auto-fixer not yet in the project's config that snuck in via a hook update); diagnose and either re-run from Step 4 or surface to the user.

Don't `--amend` an existing commit unless the user explicitly asked — amending rewrites history that may already be visible to others.

If the user has Co-Authored-By conventions, follow them. Otherwise don't add a "Generated with Claude" footer unless the user asked for it.

## Step 7 — Push (with explicit user approval)

Pushing is a side-effect visible to others. **Ask the user before pushing**, even if the gate passed:

> "Gate green, commit made on branch `feat/logout-flow`. Push and open PR? (y / hold)"

On approval:

```bash
git push -u origin <branch>
```

If the push fails because the upstream pre-push hook caught something the local gate missed, surface the hook's output verbatim. Don't try to bypass with `--no-verify`.

## Step 8 — Open the PR

```bash
gh pr create --title "<subject>" --body "$(cat <<'EOF'
## Summary
<2-4 bullets grounded in the actual diff>

## Why
<1-2 sentences from the commit body>

## Test plan
- [ ] <how to verify this works locally>
- [ ] <edge case the reviewer should sanity-check>
- [ ] <regression to watch for>
EOF
)" --base main
```

`--base` defaults to the repo's default branch; set it explicitly if your repo merges into something other than `main`. Add `--draft` if any check is amber-not-green and the user wants early feedback.

If the user doesn't want the PR opened automatically (some repos prefer the GitHub web UI for the final push of "Open"), stop after the push and tell them the URL where they can open it.

## Output

```
✓ Gate: pytest pass, ruff clean, mypy clean
✓ Self-review: 3 findings — 2 fixed, 1 accepted (noted in PR body)   ← omit line if 0
✓ Auto-fix: 2 files folded (foo.md, bar.py)        ← omit line if 0
✓ Commit: <hash> on branch <branch>
✓ Pushed to origin
✓ PR opened: <URL>
```

Or, if interrupted:

```
✗ Gate failed at: <which check> — <error message>
   No commit made. Fix and re-run /commit-and-pr, or revert and rethink.
```

## Why this skill insists on the local gate

The pre-push hook is a safety net, not a primary tool. The primary tool is the developer (or assistant) running the gate before pushing, because:

1. Local gate failures are recoverable in seconds; CI failures are recoverable in minutes plus context-switch.
2. Hooks can be bypassed with `--no-verify`. The discipline of running the gate without bypass keeps the gate trusted.
3. CI minutes have a real cost, and pushing known-broken code burns them gratuitously.

## Why Step 3 (auto-fix fold) exists

The same logic. The two-pass `Fixing ... → git add → git commit again` cycle costs ~30 seconds per occurrence and breaks the assistant flow when commit messages are long-form heredocs. Folding fixes ahead of the commit produces one clean commit, transparently, with no loss of safety: the user is still told which files were touched and why.

## What this skill does not do

- Does not push to main directly. PRs go through review.
- Does not use `git push --force` or `--force-with-lease` without an explicit user request and a clear reason.
- Does not skip the gate "to save time".
- Does not treat a green gate as proof of correctness — the self-review pass is part of the gate; CONFIRMED findings are fixed or explicitly accepted in the PR body, never silently dropped.
- Does not generate the commit body from imagination — it reads the diff first.
- Does not bypass `--no-verify` on a hook failure. A hook failure is a real signal.
- Does not auto-merge the PR — that's a separate decision after review.
- **Does not** `git add -u` or `git add .` during the auto-fix fold — only the specific paths pre-commit named, to avoid sweeping in unrelated working-tree changes.
