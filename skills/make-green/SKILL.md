---
name: make-green
description: Implement the minimum production code that turns red tests green, without refactoring, optimizing, or adding features beyond the failing tests. Use this right after `/write-failing-tests` produces red tests, or whenever the user says "make tests pass", "implement to spec", "BDD green phase", "satisfy the failing tests for X". The constraint is minimum-viable — fancier code comes later, after green.
---

# Make tests green — step 4 of the BDD workflow

Red tests exist. Your job: write the **smallest** code that turns them green. Not the cleanest, not the fastest, not the prettiest — the smallest that passes.

This skill resists the natural urge to "do it right the first time". You'll want to add an extra method that "we'll need anyway", a config option "for flexibility", a comment block "for future maintainers". Resist all of it. Green first; design later (and only when the next test forces you to).

## Step 1 — Run the red tests, see the failures

```bash
# Python
uv run pytest <path-to-tests> -v

# TypeScript
pnpm test -- <path-to-tests>
```

Read the failure messages. They tell you exactly what to build. If the failures are vague (`ImportError`, `NameError`), this skill is being run too early — go back to `/write-failing-tests` and tighten the failure quality first.

## Step 2 — Implement, narrowly

For each failing test:

- Implement the **minimum** that makes that one test pass
- If a test demands a function, write a function that returns the assertion's expected value — even hardcoded, in the absolute simplest case
- If a test demands a route, write a route that returns the expected status code
- Don't add neighbors ("while I'm here, let me also add..."). Add neighbors only when the next failing test demands them.

Example progression (Python):

```python
# Test demands: client.post("/api/auth/logout") returns 200
# Minimum:
@router.post("/api/auth/logout")
def logout():
    return {"ok": True}
```

That's all. Yes, you and I both know it doesn't actually invalidate the session. But the test that checks invalidation is a *separate* test, and you'll do that when *its* failure surfaces. You write code in tiny increments, each driven by one failing test, and you let the suite tell you when you're done.

## Step 3 — Run the tests after each small change

```bash
uv run pytest <path-to-tests> -v --tb=short
```

Watch the count drop: 5 failed → 4 failed → 3 failed → ... → 0 failed.

If your change accidentally breaks a test that was previously passing, **stop and revert**. Make-green is monotonic — green count only goes up. A regression means your change touched too much.

## Step 4 — When all targeted tests are green, run the full suite

```bash
uv run pytest -q
```

The full suite must still be green, not just the ones you targeted. If you broke something elsewhere, that's a real regression — fix it before declaring done.

## Step 5 — Quick lint/type sanity (no failures, but no fixes either)

```bash
uv run ruff check src tests
uv run mypy src/<package>
```

You want to see what's flagged but **don't fix anything yet** unless the next BDD step (`/commit-and-pr`'s pre-push gate) is going to block on it. The reason: refactor-during-green leads to regressions. Refactoring is its own phase, after green is locked in.

If ruff or mypy flag something that the green code itself caused (you wrote a clearly-broken type annotation), that's fixable now. If they flag pre-existing issues — leave them, that's a separate task.

## Step 6 — Stage, don't commit

`git add` the changes. **Don't commit yet** — `/commit-and-pr` is the next skill and it does the gate-and-commit dance properly.

## Output

```
✓ Started: <N> failed
✓ Now: 0 failed, <N> passed (full suite: 0 failed)
✓ Files changed: <list>
✓ Lines added: ~<N> production code (excluding tests, which were already written)

Ready for `/commit-and-pr`.
```

If you couldn't reach 0 failed:

```
⚠️  Stuck at <N> failed. Failing tests:
  - test_X: <one-line summary of why hard>
  - test_Y: <one-line summary>

Likely causes: <hypotheses>. Recommend: <revisit spec | ask user | accept partial green>.
```

Honest non-completion is better than fake green (commenting out an assertion to make it pass is a hostile move toward your future self).

## Why minimum-viable is the right constraint

The temptation to "design properly the first time" assumes you know in advance what the right design is. The honest answer is you usually don't — you find out as the tests reveal which constraints actually matter. Premature design adds shape that the tests haven't asked for, and that shape becomes load-bearing the moment you ship it.

Minimum-viable + iterative-add-when-forced is slower-feeling but faster overall, because you don't write code that gets thrown away or, worse, kept around as legacy that turned out unnecessary.

## What this skill does not do

- Does not refactor. Refactoring is a separate phase.
- Does not optimize. Optimization without measurement is folklore.
- Does not "improve" tests by relaxing assertions to make them pass. The tests are the spec; only the code moves.
- Does not commit or push. `/commit-and-pr` does that.
- Does not silently mark tests as `xfail` or `skip` to claim green. If a test is genuinely wrong, that's a conversation with the user, not a `@skip` decorator.
