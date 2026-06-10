---
name: describe-task
description: Translate a fuzzy user request into a precise behavior statement, deliverables list, and (when warranted) user stories or task list. Use this whenever the user describes work in natural language — "help me add X", "I want to do Y", "let's tackle Z", "figure out how to handle W", or hands you a problem without structure. Run this BEFORE writing any tests or code, even if the task seems simple, because most "simple" tasks have hidden behavior the user hasn't articulated.
---

# Describe a task — step 1-2 of the BDD workflow

The user has just said something like "help me add a logout flow" or "I want to wire up the event log to Postgres". Your job, before any code or tests, is to make the implicit explicit: name the behaviors that the deliverable must exhibit, list what concretely needs to appear, and flag if the work is large enough to deserve user stories or a task list.

A correctly-described task is one where, weeks later, anyone (including the user) can read your output and reproduce the same understanding of what was being asked.

## Step 1 — Read what the user said back to them

In your own words, restate:

- The **subject** of the work (what part of the system)
- The **change in behavior** they want (what's different after vs before)
- Any **constraints** they mentioned ("but don't break X", "must be reversible", "before Friday")

If the user's description is two sentences and you can't restate it precisely without filling gaps yourself, **stop and ask one or two clarifying questions**. Don't paper over ambiguity — it compounds.

## Step 2 — Write the behavior statement

One to three sentences, present-tense, observer's perspective.

Good:

> When a user clicks "Sign out", their session is invalidated server-side and the next request returns to the login page. Tokens issued before sign-out cannot be used afterward.

Bad:

> Add a logout function.

The good version names what's observable; the bad version names what's added. The first survives implementation choices; the second pre-commits to one.

## Step 3 — List deliverables

Concrete things that will appear by the time the work is done:

- New / changed files (files, not directories — name them where you can)
- New / changed tests (named, even just by intent)
- New configuration (env vars, schema entries)
- Documentation updates (CLAUDE.md, README, ADR if architectural)
- External-facing changes (API endpoints, UI surfaces, CLI flags)

Aim for 3-8 deliverables. Fewer than 3 means the task is suspiciously vague; more than 8 means it should probably be split.

## Step 4 — Decide if user stories help

User stories are warranted when:

- The user struggled to articulate the task (you had to ask multiple clarifying questions)
- Multiple actors are involved (logged-in user, admin, external system)
- The behavior has branches (happy path + at least two distinct error paths)
- Acceptance criteria aren't obvious from the behavior statement alone

User stories are unnecessary overhead when:

- The task is mechanical (rename a function, bump a dependency, add a missing import)
- The behavior is fully captured in one sentence
- There's exactly one actor and one outcome

When you write user stories, use Given/When/Then. Each story has 1 happy path + at least 1 error case:

```
Story: User can sign out of the web app

  Given I am signed in as a regular user
  When I click "Sign out" in the navbar
  Then my session is invalidated on the server
  And subsequent requests with the old session redirect me to /login

  Given I am signed in and my access token has been revoked by an admin
  When I attempt any authenticated request
  Then I receive a 401 and am redirected to /login
```

## Step 5 — Decide if a task list / GitHub project helps

Task list (markdown) is warranted when:

- 5+ distinct sub-tasks emerge from the deliverables
- Sub-tasks have ordering dependencies (B can only start after A)
- Multiple sessions of work will be needed (anything > 4 hours)

If yes, generate a markdown task list at the end of your output:

```markdown
## Tasks

- [ ] Add `POST /api/auth/logout` endpoint with session-invalidation logic
- [ ] Add `auth/logout` test suite covering happy path + revoked-token + expired-token
- [ ] Wire navbar "Sign out" button to the new endpoint
- [ ] Update CLAUDE.md with the auth-flow change
- [ ] Add ADR if the session storage strategy changed (probably not needed here)
```

The user can then run `gh project create` themselves, or invoke a separate `create-gh-project` skill (not part of this skill's job — `describe-task` does not call `gh` automatically).

## Step 6 — Save the spec

Write the full output to `<repo>/.task-staging/<slug>/spec.md` where `<slug>` is a short hyphenated name derived from the behavior statement (e.g., `user-logout-flow`).

`.task-staging/` is gitignored — this is a working draft, not a committed artifact. The next skill in the BDD pipeline (`/write-failing-tests`) reads from here.

If `.task-staging/` doesn't exist, create it. If it's not gitignored yet, add the entry to `.gitignore` and tell the user.

## Output shape

```markdown
# <Slug>

## Behavior
<1-3 sentences>

## Deliverables
1. <concrete item>
2. <concrete item>
...

## User stories (if warranted — otherwise omit)
<Given/When/Then blocks>

## Tasks (if 5+ sub-tasks — otherwise omit)
<markdown checklist>

## Open questions for the user
<anything you couldn't resolve and need answered before tests can be written>
```

## Why this skill exists, and why it runs before tests

Tests written from a fuzzy task description test the wrong thing — they encode the test author's guess at what the user wanted, not the actual behavior. Tests written from a precise behavior statement encode the contract the system has to satisfy regardless of implementation.

The cost of this skill is 5-10 minutes of structured thinking. The cost of skipping it is rewriting tests after implementation, plus a feature that diverges from intent. The math is favorable.

## What this skill does not do

- It does not write tests. That's `/write-failing-tests`.
- It does not write code. That's `/make-green`.
- It does not call `gh` or create GitHub projects. It only generates the markdown.
- It does not gate on user approval of every line — it produces a draft, the user iterates if needed.
- It does not invent constraints the user didn't mention. If something feels missing, it asks.
