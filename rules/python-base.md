# Python base rules (workspace-shared)

These rules apply to **every Python repo** in this workspace.

Repo-specific Python rules go in that repo's own `.claude/rules/python.md`. This file is the lowest-common-denominator baseline.

## Tooling baseline

- **Python 3.12+**. New repos: 3.12 unless there's a hard reason. Don't add 3.11-compat polyfills.
- **`uv`** is the recommended package manager. New repos start with it; existing repos using pip / poetry are not forced to migrate, but `uv` is the default for green-fields work.
- **`pyproject.toml`** is the source of truth for project metadata. No `setup.py`-only repos in green-fields work.

## Type system baseline

- Type hints required on all public functions, methods, and module-level constants.
- `from __future__ import annotations` at top of every module.
- Cross-module imports of types-only go inside `if TYPE_CHECKING:` blocks.
- Runtime checks via `pydantic` for data crossing process boundaries (HTTP, queue, DB).
- `mypy` strict mode is the goal. Repos that haven't reached it yet aim for it. Repos that have reached it stay there.

## Linting / formatting baseline

- **`ruff`** is the canonical linter and formatter for new code. Existing `black` + `isort` setups are tolerated until next config refresh.
- One linter per repo. Don't stack ruff + flake8 + pylint.
- `# type: ignore` and `# noqa` require a `Why:` comment with a real reason (incident, library bug, transitional).

## Test baseline

- **`pytest`**. No `unittest.TestCase` classes in new code.
- Test files mirror module structure: `tests/<module>/test_<feature>.py` ↔ `src/<package>/<module>/`.
- Marker convention: `@pytest.mark.integration` for tests that touch external services. Default `pytest` invocation can `-m "not integration"` for fast loops.

## Async

- New async code uses `asyncio` (not `trio`, not `anyio` shims unless the lib forces).
- Don't mix sync and async in the same call path without a clear boundary (e.g., `asyncio.run` at the entry point).
- Don't use `asyncio.run` inside library code — let the caller drive the loop.

## Logging

- Use `logging` module, not `print`. Configure at the application entry point, not at import time.
- Structured logging (key=value, JSON) preferred over plain strings for any service that emits >100 lines/sec.
- **Never log secrets.** API keys, tokens, full URLs with embedded credentials, full request bodies that may contain user data — all forbidden in logs. If in doubt, redact.

## What this rule explicitly does NOT cover

- Domain rules (project-specific domain rules — math contracts, perf invariants, etc.). Those live per-repo.
- Performance-specific patterns (numpy vs pandas vs polars, GPU memory management). Per-repo.
- Web framework conventions (FastAPI vs LangGraph vs raw asyncio). Per-repo.
- Documentation conventions. Per-repo.

The bar this file sets is "Python that wouldn't surprise any contributor to any of our Python repos". Anything narrower lives in the repo that needs it.
