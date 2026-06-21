---
name: session-reflect
description: Look back at the just-completed BDD cycle (or any sustained work session) and turn observations into concrete updates to skills, rules, memory, hooks, CI, ADRs, or PR comments — actively improving the agent's own infrastructure. Use after a PR merges, at the end of a long session, or whenever the user says "let's reflect", "what did we learn today", "any takeaways", "post-mortem this". The point isn't journaling — it's self-improvement of the system.
---

# Session reflection — step 9 of the BDD workflow (the self-improvement step)

The work for this session is done — code shipped, PR merged or near-merge, tests passing. The cycle is ending. Your job: look back honestly, find what was non-obvious, and **fix it forward** by updating the system itself, so the next session is better.

This is the step most reflection processes get wrong: they journal observations into a file no one reads. The point of doing reflection at the system level — where skills, rules, memory, hooks, and CI all live as configurable artifacts — is that you can route each observation to the artifact that prevents the issue from recurring or amplifies the success.

## Step 1 — Ask the right questions

Walk through the cycle, ideally with the user but in any case in writing:

- **Where did the system slow you down?** A skill that gave bad guidance, a rule that was overly strict, a hook that blocked something legitimate, a missing tool you had to invent ad-hoc.
- **Where did it save you?** A rule that caught something, a skill that ran exactly right, a hook that prevented a real bug — these need to be **noted**, otherwise they're invisible and might get removed in a "cleanup" later.
- **What was unexpected?** Something the code did that didn't match your model, a constraint you didn't know existed, a tool that worked differently than docs said.
- **What stayed implicit?** A decision the user and you made verbally that lives only in the chat history. If it's load-bearing, it has to land somewhere durable.
- **What kept needing the same fix?** Repeated workarounds, repeated reminders, repeated corrections — those should be skills or rules, not running gags.
- **What in CLAUDE.md / rules / skills now feels wrong** in light of what you just learned? Even small mismatches compound.

Be specific. "Things were slow" is not a finding. "The lint skill misclassified a generated file as a violation because it doesn't whitelist `build/generated/`" is.

## Step 2 — Route each finding to the right artifact

| Type of finding | Artifact | How to update |
|---|---|---|
| Tied to a specific PR (context for reviewer, follow-up note) | Comment in that PR | `gh pr comment <N> --body "..."` |
| Architectural decision, supersedes or refines an existing one | `DECISIONS.md` | invoke `/add-adr` (if your workspace provides an ADR skill), or append to `DECISIONS.md` directly |
| Personal preference / shortcut / habit, useful in future sessions | Auto-memory | save to `~/.claude/projects/<project>/memory/<topic>.md` (and update `MEMORY.md` index) |
| Project-wide rule that should always hold | `CLAUDE.md` or `.claude/rules/<topic>.md` | edit; use `paths:` frontmatter if scoped to a subtree |
| **Existing skill misfired or had a gap** | `<...>/skills/<name>/SKILL.md` | edit description / body; add a "common mistakes" section if you saw one |
| **Recurring workflow that has no skill** | New skill | write a new `<name>/SKILL.md` |
| **Class of error that should be caught by automation** | Pre-push hook (`templates/hooks/pre-push-*.sh`) | add a check; user reinstalls hook |
| **Class of error that should be caught in CI (visible to team)** | `.github/workflows/*.yml` | add a job or step |
| **Genuinely don't know where it belongs** | Ask the user | "I see this finding: <X>. Should it land in skills / memory / rules / hook / CI / drop?" — explicit question, explicit answer |

The decision tree is genuinely useful, not a formality. Half of the value of reflection is the discrimination between "this is a personal preference" (memory) and "this is a project-wide rule" (CLAUDE.md / rules) — getting that wrong leads to either rules that don't actually hold or memories that should be team knowledge.

## Step 3 — Show the user the proposed updates as a batch

Before any edits, summarize what you intend to change:

```
Reflection batch:

1. Update <repo>/skills/lint-changed/SKILL.md
   → Add explicit whitelist for build/generated/ paths
   Reason: misfired on a legit generated file this session

2. Add new skill <repo>/.claude/skills/inspect-event-log/SKILL.md
   → For ad-hoc reading of recent events during debugging
   Reason: ran the same 4-command snippet 5 times today

3. Edit <repo>/CLAUDE.md
   → Note that asyncpg row-factory shape differs from psycopg2; pre-warn future sessions
   Reason: spent 20 minutes on this surprise today

4. Save to auto-memory: "the maintainer prefers `just` recipes over raw uv commands when both exist"
   Reason: reminded me twice; should remember

5. Add gate to pre-push hook: block on uncommitted DECISIONS.md when the schema migration dir changed
   Reason: nearly merged a schema-migration PR without the supporting ADR

Apply these? (y / edit / drop specific items / abort)
```

**Wait for explicit approval.** Self-modification of the agent's own infrastructure is exactly the kind of action that should require user confirmation — these changes affect every future session.

## Step 4 — Apply the approved updates

Walk through each approved item and apply it. For skill / rule / hook edits, run the repo's gate command after, to verify nothing regressed at the meta level.

For new skills or rules: ideally invoke `/agent-pack-core:skill-creator` to draft the new artifact properly. (If the user is in a hurry, write a draft and flag it for proper iteration in a future session.)

For DECISIONS.md updates: invoke `/add-adr` with the decision title (if your workspace provides an ADR skill), or append to `DECISIONS.md` directly.

For auto-memory: append a topic file in `~/.claude/projects/<project>/memory/`, update `MEMORY.md` index entry. Both per Claude Code memory spec.

For PR comments: use `gh pr comment` directly.

## Step 5 — If there are no findings, say so

A session with no honest findings is a normal occurrence. Reporting "no actionable findings this session" is more useful than a manufactured insight. The point of reflection is real signal, not process theater.

## Output

```
Session reflection complete.

Findings: <N>
Routed to:
  - Skills updated: <count> (paths)
  - New skills created: <count> (names)
  - Rules / CLAUDE.md updated: <count>
  - Memory entries: <count>
  - Pre-push hooks updated: <count>
  - PR comments posted: <count>
  - ADRs added: <count>
  - Asked user (unrouted): <count>

Diff summary: <one-line per artifact changed>
```

If asking the user about unrouted items, do that as a follow-up turn rather than blocking the rest of the report.

## Why self-improvement is structured this way

Three principles:

1. **The artifact is the destination.** "Note to self" reflections that don't land in a real file are lost. Routing forces the discipline of "if this matters, where does it actually live?".
2. **User approval before infrastructure changes.** Skills, rules, hooks, and CI shape every future session. Modifying them without explicit confirmation is a category-violation of agent autonomy.
3. **Reflection is a system, not a feeling.** The goal isn't to feel processed, it's to make the next cycle measurably better. Measurable here means: a recurring problem stops recurring, a recurring success becomes load-bearing.

## What this skill does not do

- Does not write findings into ephemeral places (chat, scratch files no one will revisit).
- Does not silently modify infrastructure. The batch-and-approve flow is non-negotiable.
- Does not invent findings to fill out a report.
- Does not duplicate the same finding into 4 places "in case". Each finding goes to exactly one place; if it spans, that's a hint to route it to the more durable one.
- Does not auto-merge changes to skills / rules / hooks into main. Self-improvement updates go through the same review process as feature work.
- Does not run on every session by default. Run after meaningful cycles; a 10-minute typo fix doesn't earn reflection.
