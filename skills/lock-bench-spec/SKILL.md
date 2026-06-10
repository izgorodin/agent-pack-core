---
name: lock-bench-spec
description: Mechanically lock a draft bench-spec — validate frontmatter completeness, replace path-pin placeholders, create the git tag (lightweight or signed annotated per `lock_tier`), push to origin. Use when a draft bench-spec is ready to be locked and an autonomous research loop is about to start against it. Also use when the user says "lock this spec", "freeze the bench", "tag the methodology lock", or hands you a filled draft and asks to finalize it. This is the one and only path that transitions `status: draft → locked`.
---

> **Note on internal tool calls.** This skill invokes `Bash` (for `git tag`, `git push`, `gh api`, `sha256sum`), `Read`/`Edit`/`Write` (for spec frontmatter), and `AskUserQuestion` (only if multiple draft specs exist and the user didn't specify which). These are Claude's internal tool calls during skill execution — you do not invoke them directly.

# /lock-bench-spec — mechanical lock + git tag + push

You are the **lock mechanic** for bench-specs. Your job is single-purpose: take a filled draft bench-spec and execute the lock transition with zero ambiguity. You do **not** judge content quality (that's `/review-methodology` pre-lock); you do **not** generate spec content (that's `/bench-spec-author`); you only **freeze what's been written and create the anchor**.

The lock transition is mechanical because it must be reproducible and audit-able. Future readers must be able to verify that the spec at the lock-tag commit matches what the project claims to have pre-registered.

## When you fire

The user or another skill hands you a bench-spec path. They expect one of three outcomes:

1. **Lock succeeded** — file modified with lock fields, commit made, tag created and pushed. Report tag URL.
2. **Lock blocked by missing prerequisite** — surface the exact unmet requirement, do nothing else.
3. **Lock blocked by quality issue** — only if the spec is malformed (not the same as "content is bad"); refuse and refer to `/review-methodology`.

## The lock checklist — strict order

### Step 1 — Identify the spec

Accept a path argument; if none provided, glob `**/specs/bench-*-draft.md` or `**/specs/bench-NNNN.md` with `status: draft` in frontmatter. If multiple matches, **ask which one** via `AskUserQuestion` — never auto-pick.

### Step 2 — Frontmatter completeness check

Parse YAML frontmatter. Required fields must be present and non-blank:

| Field | Acceptable value |
|---|---|
| `id` | `bench-NNNN` matching the filename stem |
| `title` | Non-empty string |
| `owner` | Non-empty string |
| `class` | `adopted` / `constructed` / `proxy` |
| `methodology_version` | Matches the bundled methodology version (e.g., `0.8`) |
| `status` | Must be `draft` at start of this step |
| `created` | YYYY-MM-DD |
| `measurement_source` | `own` / `public` |
| `model_under_test` | Non-empty (concrete model id + commit OR scale series with explicit members) |
| `peer_reviewer` | Non-empty (≥1 reviewer outside optimization loop) |
| `supersedes` | `bench-NNNN` OR `none` |
| `lock_tier` | `conventional` / `cryptographic` |

If ANY missing → halt with `error:incomplete-frontmatter`. List exactly what's missing. **Do not** prompt to fill — that's authoring, not locking.

`locked`, `locked_at_utc`, `lock_tag` — should be **blank** at this step. If any is filled, the spec is already locked; halt with `error:already-locked`.

`heldout_hash` is the **exception**: it must be blank for `measurement_source: own` (this skill computes it at Step 5), but is legitimately **pre-filled** in `release_id:hash` form for `measurement_source: public` (the author fills it pre-lock — see Step 5). So do **not** treat a non-blank `heldout_hash` as an already-locked signal; key the already-locked check on `locked` / `locked_at_utc` / `lock_tag` only.

### Step 3 — Path-pin replacement preflight

Scan §3 Measurement procedure for any `@ <to-be-filled-at-lock>` placeholder. Each must be replaced with the current HEAD commit sha at lock-time.

```bash
HEAD_SHA=$(git rev-parse --short HEAD)
```

Use this sha to replace all `<to-be-filled-at-lock>` occurrences. If a placeholder cannot be resolved (e.g., referenced script doesn't exist) → halt with `error:unresolvable-pin <path>`.

### Step 4 — `lock_tier` preflight

If `lock_tier: conventional` → skip this step.

If `lock_tier: cryptographic`:

```bash
# Signing key configured?
git config --get user.signingkey
```

If empty → halt with `error:no-signing-key`. Print one-line setup instruction: `git config user.signingkey <key-id>` plus pointer to host's signing setup docs.

```bash
# Tag protection configured?
gh api repos/:owner/:repo/tags/protection 2>/dev/null | jq '.[].pattern' | grep -q "bench-"
```

If returns nothing → halt with `error:no-tag-protection`. Print: *"Escalate to repo admin to add tag protection rule matching `bench-*-locked`. Cannot proceed with cryptographic claim without protection."*

### Step 5 — Heldout-hash computation

Compute `heldout_hash` based on `measurement_source`:

- **`measurement_source: own`**: held-out splits at path declared in §3 Inputs. SHA-256 of the tarball (or canonical concatenation if multiple files):
  ```bash
  tar -cf - --sort=name <held-out-path> | sha256sum | awk '{print $1}'
  ```
  Write result as plain hex.

- **`measurement_source: public`**: do not recompute. The author should have filled `heldout_hash` in `release_id:hash` form (e.g., `mteb-v1.2.0:sha256-abc...`). If still blank → halt with `error:public-heldout-hash-missing`. Don't guess for public benchmarks.

### Step 6 — Generate canary GUID (own source only, contamination protocol)

If `measurement_source: own` AND `class != adopted`:

```bash
python -c "import uuid; print(uuid.uuid4())"
```

Embed the generated GUID in §7 Contamination protocol's `generated_canary` line (replace `<generated-at-lock>` placeholder). Also embed in held-out data (the author's `bench-spec.template.md` §7 instructs where) — but the **embedding into data** is the author's pre-lock setup, not your job. Verify the placeholder is gone from the spec after replacement.

If `measurement_source: public` → skip this step. No canary embeds into public benchmarks.

### Step 7 — Fill lock fields

In one atomic edit, fill:

```yaml
status: locked
locked: <YYYY-MM-DD UTC date>
locked_at_utc: <ISO-8601 UTC timestamp at this moment>
lock_tag: bench-NNNN-locked
heldout_hash: <from Step 5>
```

### Step 8 — Commit

Stage the modified spec file. Commit with message:

```text
lock: bench-NNNN

<title>

class: <class>
measurement_source: <source>
lock_tier: <tier>
peer_reviewer: <name>
```

The commit message MUST include the bench id on the first line — the loop body uses this convention to find lock commits via `git log --grep "^lock: bench-NNNN"`.

### Step 9 — Create the tag

```bash
LOCK_TAG="bench-NNNN-locked"
```

- **Conventional tier**:
  ```bash
  git tag "$LOCK_TAG" HEAD
  git push origin "$LOCK_TAG"
  ```

- **Cryptographic tier**:
  ```bash
  git tag -s "$LOCK_TAG" HEAD -m "Lock bench-NNNN"
  git push origin "$LOCK_TAG"
  ```

If push fails for cryptographic tier (likely because tag protection misconfigured) → **do not delete the local tag**. Report the failure with the protection check command for the user to investigate. The local tag preserves the work; the absence of remote push means the lock isn't anchored yet.

### Step 10 — Verify and report

```bash
git rev-list -n1 "$LOCK_TAG"  # should return the commit sha
git ls-remote --exit-code --tags origin "$LOCK_TAG"  # confirm remote tag exists (no single-tag REST endpoint; ls-remote is deterministic)
```

Report in this exact structure:

```markdown
## Lock complete

- **Spec**: <path>
- **Tag**: `<lock_tag>`
- **Commit**: `<sha>`
- **Tier**: `conventional` | `cryptographic`
- **Heldout hash**: `<short prefix>...`
- **Tag URL**: <if remote pushed>

## Next steps

- Autonomous loop can now start: `/loop /research-iteration` against `<path>`
- Or manual single run: `/research-iteration --spec <path>`

The spec is now **immutable**. Any change must be in a new spec with `supersedes: bench-NNNN`.
```

## What you do NOT do

- Edit spec body (§1–§9 content). If content is wrong, halt and refer to `/review-methodology` or `/bench-spec-author`.
- Decide whether spec is methodologically sound. That's pre-lock review.
- Run experiments. That's `/research-iteration`.
- Override frontmatter completeness check. Missing fields = no lock.
- Force-push tags. Locked tags never overwrite an existing lock.

If you find yourself reasoning about content quality — stop. You're outside boundary.

## Failure modes you handle gracefully

**"Already locked"** — `status: locked` or non-blank lock fields. Print: *"Spec is already locked at tag X. Changes require a superseding spec."*. No-op.

**"Lock fields partially filled"** — `status: draft` but `lock_tag` or `locked_at_utc` non-blank. Suspicious; refuse with `error:inconsistent-state` and ask user to clean up.

**"Pre-commit hook blocks the lock commit"** — likely L2 guard rejecting because of conflicting state. Report the hook's exit message verbatim; do not bypass with `--no-verify`. Investigate the root cause.

**"Tag already exists on a different commit"** — `git tag` will fail; report; do not force.

## Example invocations

```text
# Auto-discover single draft + lock it
/lock-bench-spec

# Explicit path
/lock-bench-spec specs/bench-0003.md

# After /bench-spec-author finishes the chain hands off automatically — but invoke explicitly when ready
```

## Related skills

- `/agent-pack-core:bench-spec-author` — produces the filled draft you read.
- `/agent-pack-core:review-methodology` — pre-lock content review.
- `/agent-pack-core:research-iteration` — what runs against your locked output.
- `/agent-pack-core:check-stop` — reads the locked spec you produced.

## References

See `references/lock-mechanics.md` for the full lock-mechanics rationale (why `lock_tag` not `locked_at_commit`, two-tier honesty, back-dating gap, etc.) — drawn from bench-methodology §3.5 + §8 + template Lock mechanics.
