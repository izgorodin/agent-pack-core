---
name: write-failing-tests
description: Write tests that fail with meaningful assertion errors before any production code exists. Use this right after `/describe-task` produces a spec, or whenever the user says "write the tests first", "TDD this", "BDD red phase", "write failing tests for X", or hands you a behavior to test. Run BEFORE writing any production code — that's the whole point of test-first.
---

# Write failing tests — step 3 of the BDD workflow

You have a behavior statement (from `/describe-task` or directly from the user). Your job: write tests that encode that behavior and fail in a meaningful way. No production code yet.

A meaningful failure is one where reading the test output tells you exactly what's missing. Bad: `ImportError: cannot import name 'logout' from 'auth'`. Better: `AssertionError: expected POST /api/auth/logout to return 200, got 404`. The second tells the implementer what the system has to do; the first just says "you haven't started".

## Step 1 — Locate the spec

Read `<repo>/.task-staging/<slug>/spec.md` if it exists. If not, ask the user for the behavior statement directly. Don't proceed without one — tests written from "I think the user wants..." are the failure mode this whole skill exists to prevent.

## Step 2 — Detect the stack and framework

| Marker | Stack | Test framework |
|---|---|---|
| `pyproject.toml` with pytest in deps | Python | pytest |
| `package.json` with vitest in deps | TS/JS | vitest |
| `package.json` with jest in deps | TS/JS | jest |
| `package.json` with @playwright/test | TS/JS | Playwright (e2e) |
| Other | ask | ask |

Use what the repo already uses. Don't introduce a new framework just because you'd prefer it — that's a separate decision the user makes outside this skill.

## Step 3 — Write tests that match the spec, one per behavior

For each user story or behavior in the spec:

- Name the test after the behavior it checks (`test_signed_in_user_can_sign_out`, not `test_logout_1`)
- Set up the precondition explicitly in the test body (no shared state, no implicit fixtures unless they exist already and are obviously the right thing)
- Assert the observable outcome — status code, returned data, downstream effect — not the internal mechanism
- Write at least one negative test per happy path (revoked token, expired session, missing input)

Example shape (Python / pytest):

```python
def test_signed_in_user_can_sign_out(client, signed_in_session):
    response = client.post("/api/auth/logout", cookies=signed_in_session)
    assert response.status_code == 200
    # The session is now invalid
    follow_up = client.get("/api/me", cookies=signed_in_session)
    assert follow_up.status_code == 401


def test_revoked_token_returns_401(client, revoked_token):
    response = client.get("/api/me", headers={"Authorization": f"Bearer {revoked_token}"})
    assert response.status_code == 401
```

The reason these tests fail meaningfully is that they hit a real route, exercise a real cookie/header, and check a real status. They don't pass by being wired to nothing — they pass only when behavior actually works.

## Step 4 — Run the tests, confirm they fail correctly

```bash
# Python
uv run pytest <path-to-new-tests> -v

# TypeScript
pnpm test -- <path-to-new-tests>
```

You want to see them **red**. If they pass, something is wrong — either the test is asserting nothing, or the production code already exists. Either way, stop and figure out which before continuing.

If they fail with `ImportError` / `ModuleNotFoundError` / "Cannot find name", that's lower-quality red. The test passes the bar minimally, but iterate one round: stub out the import target as a file that exists with a `NotImplementedError`-raising function. Now the failure says "behavior not yet implemented" instead of "module missing", which is what the next skill (`/make-green`) wants to see.

## Step 5 — Stage but don't commit

Add the new test files to git index (`git add`) but **don't commit**. The whole point of TDD is the diff between the red and green commit telling a coherent story. The next skill commits both at once or sequentially; this skill leaves the work staged and visible.

## Output

A short summary back to the user:

```
✓ Tests written: <N> tests in <file paths>
✓ Run result: <N> failed, 0 passed (red as expected)
✓ Failures verified meaningful: each failure points to a specific behavior

Ready for `/make-green` to implement.
```

If any test passed instead of failing, do **not** report success. Report the surprise:

```
⚠️  Test <name> passed unexpectedly. Either:
  - The production code already exists (good — skip make-green for this case)
  - The assertion is too weak to fail (bad — strengthen it)
Investigate before continuing.
```

## Why this skill runs before code

Tests written after code tend to encode what was implemented, not what was wanted. Tests written before code force the spec to crystallize and act as a cheap, fast contract that the implementation either satisfies or doesn't. The compile-then-test loop is replaced by a write-test-then-make-it-pass loop, which is faster on average and produces fewer regressions.

If TDD feels slow on a particular task, that's a signal the spec wasn't precise enough — the right move is back to `/describe-task`, not to skip tests.

## What this skill does not do

- Does not write production code. That's `/make-green`.
- Does not commit. The next skill or the user does that.
- Does not skip negative tests "to keep things simple". A test suite without negatives doesn't constrain the system enough.
- Does not invent fixtures that don't exist. If the test needs a `signed_in_session` fixture and there isn't one, write a stub or ask the user where it should live.
- Does not pad with low-value assertions just to inflate test count. Each test earns its place by checking a distinct behavior.
