---
name: pr-preparation
description: Polish an already-multi-commit feature branch before it goes to review — verify the quality gate, decide whether to squash/reword commits to tell a coherent story, generate PR title and body grounded in the actual diff. Use when a branch accumulated several "wip"/"fmt"/"fix typo" commits over multiple sessions and needs cleanup, or when the user says "clean up this branch for PR", "polish before review", "squash the wips". For a single-session BDD cycle that's already at PR-ready, prefer /commit-and-pr — that one combines gate + commit + PR in one step.
allowed-tools: Bash(git*) Bash(gh pr view*) Bash(gh pr diff*) Bash(uv run*) Bash(pnpm*) Bash(just*)
---

# Pull request preparation

Get a branch into the shape it needs to be in before a human reviewer sees it.

## Step 1 — Verify the branch makes sense

```bash
git status
git branch --show-current
git log --oneline main..HEAD
```

Confirm:
- Branch is not `main` or `master` (you don't open a PR from main).
- There's at least one commit beyond the base.
- The diff size is reviewable. If it's >800 lines or touches >15 files, **flag it** — split-PR conversation may be needed before continuing.

## Step 2 — Quality gate

Run whatever the repo's quality gate is:

| Stack | Command |
|---|---|
| Python (uv-based) | `just test && just lint && just typecheck` (or `uv run pytest && uv run ruff check && uv run mypy <pkg>`) |
| pnpm (Next.js, etc.) | `pnpm test && pnpm typecheck && pnpm lint` |
| npm | `npm test && npm run typecheck && npm run lint` |

All checks must pass. Don't open a PR with red checks unless explicitly drafting (and then label it `[WIP]`).

## Step 3 — Read the diff yourself

```bash
git diff main...HEAD
```

Don't skim. Read every changed file. Specifically:

- Are there any leftover `console.log`, `print(...)`, `debugger`, breakpoint hooks?
- Are there any commented-out blocks of old code?
- Are there any TODOs introduced this PR that should be either resolved or split out?
- Are there any deps added that aren't reflected in lockfiles?
- Are there any `.env.example` keys added without docs explaining what they do?

If anything looks off, fix it now.

## Step 4 — History scrub (only if appropriate)

A scrub is appropriate when:
- The branch has many small "wip" / "fix typo" / "fmt" commits that don't tell a story.
- The branch hasn't been pushed yet, OR has been pushed only as draft to your own fork.

A scrub is NOT appropriate when:
- The branch is shared with collaborators who have it checked out.
- The commits are individually meaningful and telegraph the design path.

If scrubbing, prefer `git rebase -i` interactively (NOT in a Claude session — this requires your editor). Squash, fix-up, reword as needed.

## Step 5 — Generate PR title and body

Title: under 70 chars. Imperative mood. No trailing period. Example:
- ✅ "Add idempotency key to the order-creation endpoint"
- ❌ "Adding some changes for the claims module."

Body template:

```markdown
## Summary
<2-4 bullets of what the change does, grounded in the actual diff>

## Why
<1-2 sentences of motivation. Reference an ADR or issue if applicable.>

## Test plan
- [ ] <how the user can verify this works>
- [ ] <edge case checked>
- [ ] <regression to watch for>
```

Don't pad. Don't generate sections you didn't actually do.

## Step 6 — Open the PR

```bash
gh pr create --title "<title>" --body "$(cat <<'EOF'
<body>
EOF
)" --base main
```

Add `--draft` if any check is still red and you want feedback first.

## What this skill must NOT do

- Push to main. Ever. PRs target main; pushes to main are not part of this workflow.
- Skip the quality gate "to save time".
- Generate a body from the commit messages alone — read the diff.
- Add `[Generated with Claude Code]` footers unless the user explicitly asks.
- Squash commits on a branch others are working on.
