---
name: validate-plugin-marketplace
description: Lint a Claude Code marketplace.json (or plugin.json) for the common gotchas that produce confusing errors at install time — bare-string `source` values, missing required fields, wrong file location. Use when scaffolding a new pack or marketplace, before pushing the manifest, or whenever `claude plugin install` produces a "source type your version does not support" error and you don't yet know why. Read-only: emits warnings, never modifies the file.
argument-hint: [path/to/marketplace.json | path/to/plugin-dir]
---

# Validate a Claude Code marketplace / plugin manifest

Catch the manifest mistakes that cause the most confusing install-time errors. This skill is read-only — it reports, you fix.

## Step 1 — Locate the manifest

Argument `$1` may be:

- A path to a `marketplace.json` directly.
- A path to a directory — the skill looks for `<dir>/marketplace.json` and `<dir>/.claude-plugin/plugin.json`, lints whichever it finds.
- Empty — default to the current repo root, look for both files.

If neither file is found, stop and report the path you searched. Don't invent a manifest.

## Step 2 — Lint `marketplace.json`

A marketplace manifest looks like:

```json
{
  "name": "my-marketplace",
  "version": "1.0.0",
  "plugins": [
    {
      "name": "my-plugin",
      "source": { "source": "url", "url": "https://github.com/org/repo" }
    }
  ]
}
```

For each entry, check:

### A. `source` must be an object, OR the local `"./"` string

The most common gotcha. A bare string `"source": "."` (or any non-local string) is rejected at install time with:

> This plugin uses a source type your Claude Code version does not support.

The error blames the version; the real cause is the manifest.

**Allowed object forms:**

| Form | When to use | Example |
|---|---|---|
| `{"source": "url", "url": "..."}` | Plugin lives at the top of a public/private repo | `{"source": "url", "url": "https://github.com/org/repo"}` |
| `{"source": "git-subdir", "url": "...", "path": "..."}` | Plugin lives in a subdirectory of the marketplace repo | `{"source": "git-subdir", "url": "https://github.com/org/repo", "path": "plugins/my-plugin"}` |

**The local form** `"source": "./"` (a string, paired with `"strict": false`) is also valid — and is the right choice when the plugin lives in the marketplace repo itself (a single-repo marketplace, where one repo IS both the marketplace and the plugin). **Flag** any *other* bare-string source (e.g. `"."`, or a path without the companion `"strict": false`) and suggest the matching object form.

### B. Required fields per plugin entry

Every plugin entry needs `name` and `source`. Optionally `version`, `description`, `author`. Missing `name` or `source` is fatal — install fails with a less-confusing error than (A) but still costs minutes.

### C. Marketplace-level fields

The top level needs `name` and `plugins`. `version` is optional but recommended (so consumers can pin).

### D. File location

`marketplace.json` lives at `.claude-plugin/marketplace.json` at the marketplace repo root — the `.claude-plugin/` directory is its home (the same place the plugin manifest `plugin.json` lives, in a single-repo marketplace). Flag it only if it's loose at the bare repo root, or buried in an unrelated subdirectory like `meta/marketplace.json`. (The *plugin* manifest `plugin.json` sits alongside it at `<plugin-root>/.claude-plugin/plugin.json` — a different file with a different role.)

## Step 3 — Lint `plugin.json` (the plugin-level manifest)

If a `.claude-plugin/plugin.json` is present (the plugin's own manifest, distinct from the marketplace):

```json
{
  "name": "my-plugin",
  "version": "1.0.0",
  "description": "...",
  "author": { "name": "...", "email": "..." }
}
```

Check:

- `name` present and matches the directory name (Claude Code uses directory name as fallback if `name` is absent, but inconsistency confuses users).
- `version` present (required by the marketplace install path; without it, `plugin install` may pull but not pin).
- `description` present (otherwise the plugin shows up nameless in `/help`).

## Step 4 — Lint shape of `skills/` and `agents/` if present

Quick structural sanity checks (since you've already opened the directory):

- Each `skills/<name>/SKILL.md` exists (skill folders without SKILL.md are silently ignored at load).
- SKILL.md frontmatter has at least `description` (Claude won't auto-trigger without it).
- `agents/*.md` files don't use `hooks`, `mcpServers`, or `permissionMode` frontmatter — those fields are silently stripped on plugin agents per Claude Code spec, and the agent will load with unexpected behavior.

These checks are bonus; the marketplace lint (Step 2) is the main job.

## Step 5 — Report

```
🔎 Marketplace manifest validation

File: <path>
Issues found: N (blocking: a, warning: b)

## Blocking

### B1. <rule short name> — line <n>
<one-line description, with the exact snippet quoted>
**Fix:** <concrete replacement, often a JSON snippet>

---

## Warnings

<same shape, less severe>

## Clean
- <pass-message for each rule that passed, terse>

## Verdict: GREEN | RED
```

If GREEN, say so in two lines and stop.

## What this skill must NOT do

- Modify the manifest. Surface findings, the user fixes.
- Try to install or test the plugin. The lint runs offline, no network.
- Guess at fixes for things outside its rule set ("you should add X" — only suggest fixes that follow directly from a flagged rule).
- Walk into git history. The current file on disk is what matters.
