---
name: address-review
description: Read all comments on a pull request, propose a per-comment plan (accept / push back / partial), apply changes, re-run the gate, and push updates — without auto-resolving threads (that's the reviewer's call). Use whenever the user says "process the review on PR #N", "respond to review comments", "address the feedback on this PR", or after the user receives a review notification and asks "what now?".
---

# Address review comments — steps 7-8 of the BDD workflow

A reviewer left comments on a PR. Your job: read them honestly, decide for each one whether to accept / push back / partially adapt, apply the agreed changes, run the gate, and push. Reviewer keeps the keys to "resolve" — you don't close threads on their behalf.

The asymmetry to respect: a reviewer who feels heard will keep reviewing your PRs in the future. A reviewer who feels steamrolled won't.

## Step 1 — Pull the PR state

```bash
gh pr view <N> --json state,title,headRefName,baseRefName,reviewDecision
gh pr view <N> --comments
gh api repos/<owner>/<repo>/pulls/<N>/comments
```

The first command gives you the metadata. The second shows top-level review comments. The third gives inline comments tied to specific file:line locations — those are the ones with the most context.

If the PR is already merged or closed, stop and tell the user.

## Step 2 — Group and triage

For each comment, classify into one of:

| Class | Meaning | Action |
|---|---|---|
| **Accept** | Reviewer is right; change agreed. | Apply the change. |
| **Push back** | Reviewer's concern doesn't apply, or the suggested change would harm something they didn't see. | Respond with reasoning, no code change. |
| **Partial** | Reviewer's concern is real but their suggested fix isn't quite right. | Address the underlying concern with a different change; explain why. |
| **Defer** | Real issue, but out of scope for this PR. | Open a follow-up issue, link it in the response, leave PR alone. |
| **Clarify** | You don't yet understand what the reviewer means. | Ask a question, no change yet. |

Show the user this grouping **before** applying changes:

```
PR #142 review by @reviewer (3 comments):

1. [src/auth/logout.ts:18] "Should we hash the session ID before storing?"
   → Accept. Will add bcrypt hash before storing.

2. [src/auth/logout.ts:32] "This loop could be replaced with .map()"
   → Push back. The for-loop has an early-exit case .map() can't express cleanly.

3. [tests/auth/logout.test.ts:5] "Missing test for concurrent logout from two devices"
   → Defer. Real concern but out of this PR's scope. Will open follow-up issue.

Apply this plan? (y / edit / abort)
```

**Wait for explicit user approval.** Don't apply changes from a review you read 30 seconds ago without giving the user a chance to say "actually, on #2 I agree with the reviewer".

## Step 3 — Apply accepted and partial changes

Make the agreed code changes. Keep the diff minimal and focused — review responses aren't the place to refactor neighboring code "while you're there".

Re-run the tests that touch the changed files — the focused subset of the repo's declared quality gate (e.g. `uv run pytest <relevant-tests> -v` for Python, `pnpm test <pattern>` for JS, `go test ./<pkg>` for Go).

## Step 4 — Re-run the full gate

The same gate as in `/commit-and-pr` — the repo's declared quality gate, run in full. Detect the stack and use its gate, for example:

```bash
# Python: pytest + ruff + mypy
uv run pytest -q && uv run ruff check src tests && uv run mypy src/<package>

# JS/TS: test + lint + typecheck
pnpm test && pnpm lint && pnpm typecheck

# Go:    go test ./... && go vet ./...
# Rust:  cargo test && cargo clippy
```

If anything regresses, stop and surface it. Don't push until green.

## Step 5 — Compose responses

For each comment, draft a response. Tone matters:

**Accept:**

> "Good catch — agreed. Updated in <commit-hash>: now hashes the session ID with bcrypt before storage."

**Push back:**

> "I considered this but kept the for-loop because the early-exit on the dispute case can't be expressed cleanly with .map() (it'd require throw-as-control-flow). Open to other suggestions if you see a cleaner way."

**Partial:**

> "Concern is real — the original code could leak session data on the error path. I addressed it differently: instead of <reviewer's suggestion>, I added a try/finally that always clears the cache. <commit-hash>. Does this satisfy the original concern?"

**Defer:**

> "Real issue but feels out of scope for this PR — opened #143 to track concurrent-logout-from-multiple-devices. Worth doing soon but not blocking this."

**Clarify:**

> "Want to make sure I understand — when you say 'race condition', do you mean (a) two simultaneous logout requests from one user, or (b) logout racing with a session-refresh? Solution differs."

Don't be defensive. Don't over-apologize. Don't write a paragraph when one sentence does.

## Step 6 — Commit and push the response changes

```bash
git add <changed-files>
git commit -m "address review: <one-line summary>"
git push
```

Then post the responses:

```bash
# For inline comments, reply to each one
gh api repos/<owner>/<repo>/pulls/<N>/comments/<comment-id>/replies \
  -f body="<response>"

# For top-level review comments
gh pr comment <N> --body "<response>"
```

If multiple comments share a single thread, reply once on the thread rather than once per comment.

## Step 7 — Don't resolve the threads

The reviewer marks threads as resolved when they're satisfied. Resolving threads on their behalf:

- Looks like you're rushing them
- Loses the reviewer's record of what they checked
- Is sometimes blocked by repo settings anyway

Just push the changes and post responses. The reviewer comes back, reads, resolves, and re-reviews.

## Output

```
✓ PR #142 review processed:
  - Accepted: 1 comment, applied in <hash>
  - Pushed back: 1 comment, response posted
  - Deferred: 1 comment, follow-up issue #143 opened
  - Clarification: 0
✓ Gate green after changes
✓ Pushed to origin/<branch>
✓ Responses posted, threads left unresolved (reviewer's call)

PR URL: <url>
```

## Why this skill exists separately from `/commit-and-pr`

The two skills handle different conversations:

- `/commit-and-pr` is a one-way push: developer → reviewer.
- `/address-review` is a back-and-forth: reviewer ↔ developer.

The shape of work is different (per-comment triage, draft-and-approve before applying), the failure modes are different (ignoring a comment vs. ignoring a CI signal), and merging them into one skill obscures both.

## What this skill does not do

- Does not auto-resolve review threads.
- Does not silently dismiss comments without responding.
- Does not apply changes without showing the user the triage plan first.
- Does not "fix neighboring issues while in there" — every change in a review response should trace to a specific comment.
- Does not push back on a comment because the reviewer is junior or you disagree with their style. Reasoning has to be technical.
- Does not auto-close the PR or auto-merge after a review approval. Those are separate decisions.
