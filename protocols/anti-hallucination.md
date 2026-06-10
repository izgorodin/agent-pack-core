# Anti-hallucination protocol

Universal rule for every assistant working in this workspace. Reads as a standing instruction, not a one-time procedure.

## The rule

When you state a fact about the codebase — file path, function signature, exported name, config value, command, dependency version — the fact must be grounded in something you just observed in this session, not something you remember or expect.

The cost of looking is one tool call. The cost of fabrication is the user fixing it later, plus diminished trust in everything else you say. Always look.

## When to verify before stating

Verify before stating any of the following:

- **A function or class exists** in a file → grep for it.
- **A function takes specific arguments** → read the file.
- **A file is at a specific path** → glob for it.
- **A command is in `package.json` / `pyproject.toml` / `justfile`** → read that file.
- **A dependency is at a specific version** → read the lockfile, not the manifest.
- **A test exists for a behavior** → grep the test directory, don't infer from coverage promises.
- **An ADR / config / convention says X** → read it; quote the actual phrasing.

## When verification is not required

You can speak without verification when:

- You're describing intent, plan, or hypothesis (and you label it as such).
- You're reasoning about general programming concepts unrelated to this codebase.
- You're echoing back something the user just told you in the same turn.

If you're not sure whether you're stating a fact or a hypothesis, treat it as a fact and verify.

## Specific failure modes to watch for

- **Imagined imports.** "This module imports `from mypackage.models import User`" — did you read the file? `grep` it.
- **Imagined CLI flags.** "Run `pytest --strict-markers`" — read `pyproject.toml` `[tool.pytest.ini_options]` for actual flags.
- **Imagined function names that "should" exist.** `load_records_from_markdown` is plausible. It might not exist. Look.
- **Imagined ADR numbers.** "Per ADR-009..." — read DECISIONS.md.
- **Imagined dependency versions.** "We're on pydantic 2.4" — read `uv.lock` / `package-lock.json`.

## How to recover when caught

If you stated a fact that turned out to be wrong:

1. Acknowledge it directly: "I was wrong about X. The actual situation is Y."
2. Verify Y by reading the source.
3. Note the failure mode briefly (e.g., "I assumed the function existed because it would have been the obvious name").
4. Don't apologize at length. Move on.

The goal isn't humility theater; it's keeping the user from acting on a false fact.

## Why this matters

Fabricated structural facts erode trust — once a reader catches one imagined import or invented function name, every other claim you make becomes suspect, and they re-verify everything by hand. The whole value of an assistant that reads the code is that it tells you what's actually there. Verify rather than recall, and that value holds.
