---
name: bdd-workflow
description: End-to-end guide through the 9-step BDD/TDD cycle — describe → red tests → green code → commit → PR → push → review → address review → reflect. Use this when the user wants to take a feature from idea to merged with discipline, says things like "let's BDD this", "full cycle for X", "do it properly with tests", "TDD this from scratch", or hands you something substantive enough to deserve real process.
---

# BDD/TDD workflow — the umbrella

You're the conductor for a 9-step cycle. Each step has its own atomic skill that does the actual work; your job is to invoke them in order, hand off context between them, and check in with the user at each transition. You don't bulldoze through all 9 — each transition is a checkpoint.

The cycle exists because shortcuts at any step compound: skip the spec, write tests for the wrong thing; skip the gate, push something broken; skip reflection, repeat the same mistake next week.

## The 9 steps

| # | Step | Atomic skill | What you check before moving on |
|---|---|---|---|
| 1-2 | Translate fuzzy request → behavior + deliverables (and user stories / tasks if warranted) | `/agent-pack-core:describe-task` | The user agrees the spec captures what they actually want |
| 3 | Write failing tests | `/agent-pack-core:write-failing-tests` | Tests fail with meaningful errors (not just `ImportError`) |
| 4 | Minimum code → green | `/agent-pack-core:make-green` | All targeted tests green; full suite green; no regressions |
| 5 | Commit + PR | `/agent-pack-core:commit-and-pr` | Local gate green; commit message reflects diff; PR opened |
| 6 | Pre-push hook gate | (handled by the hook itself, separate infrastructure) | Hook ran on push; no override |
| 7-8 | Address review | `/agent-pack-core:address-review` | Each comment triaged; gate still green; responses posted |
| 9 | Reflect → improve the system | `/agent-pack-core:session-reflect` | Findings routed to skills / rules / memory / hooks / CI / dropped |

## How to run the umbrella

### Mode 1: Full pass, supervised

The user wants the whole cycle, with a chance to redirect at each step:

1. Run `/agent-pack-core:describe-task`. When it finishes, summarize the spec back to the user in 2-3 lines and ask: "Spec looks right? (y / refine / abort)". Don't proceed without approval.

2. On approval, run `/agent-pack-core:write-failing-tests`. When it finishes: "Tests are red, <N> failures. Move to make-green?".

3. On approval, run `/agent-pack-core:make-green`. When it finishes: "Tests green, full suite green. Move to commit?".

4. On approval, run `/agent-pack-core:commit-and-pr`. That skill itself asks for explicit push approval — don't pre-empt that.

5. PR is open. Stop. The cycle pauses here naturally — the reviewer needs time, you need other work. **Don't wait** in the same session for a review unless the user explicitly wants to.

6. When the user comes back with a review (potentially in a future session), run `/agent-pack-core:address-review` for each round.

7. After merge — or after the user signals "this one's done" — run `/agent-pack-core:session-reflect`.

### Mode 2: Resume mid-cycle

The user wants only certain steps, or has done some manually:

> "I already have the spec, just write the tests and make them pass."

Skip the steps already done. Run only `/write-failing-tests` → check → `/make-green` → check → ask if `/commit-and-pr` should run.

Don't insist on running steps the user already covered — they have context you don't.

### Mode 3: Dry-run / explanation

The user wants to understand the cycle without doing it:

Walk them through the table above with one sentence each on what each step produces. Then ask: "Want to start with step 1, or you have a specific step in mind?"

## When the cycle is overkill

For 10-minute fixes (typo, dependency bump, comment correction), the umbrella is wasted ceremony. Tell the user that and offer a lighter path:

- Just fix → run gate locally → commit → push → small PR.

If the user wants the full cycle anyway (say, they're learning the rhythm), do it. Their call.

## When something fails mid-cycle

Each atomic skill reports failure honestly. Your job at the umbrella level:

- **Spec failure** (user keeps refining and it never lands) — pause and ask if the request itself is too broad; suggest splitting.
- **Tests don't fail meaningfully** — back to spec; the behavior wasn't precise enough.
- **Make-green stuck** — back to tests; one of them may be wrong, or the behavior is harder than the spec implied.
- **Gate fails** — fix in place, not in a new commit; or back to make-green.
- **Reviewer wants major changes** — that's a normal pre-merge cycle, not a failure; loop back to make-green for the deltas.
- **Reflection finds the spec was wrong all along** — that's expensive, but real. The artifact updates from reflection are the only way the next cycle avoids the same trap.

## Checkpoints between steps — what to actually say

Be terse. Each checkpoint is one or two sentences:

> "Spec for the logout flow staged in `.task-staging/user-logout/spec.md`. 4 deliverables, 1 user story (revoked-token case). Move to tests?"

Not:

> "I have completed the task description phase and produced a comprehensive specification document with full deliverable enumeration..."

The user is going to skim. Earn their attention by being short.

## Output (when the cycle completes or pauses)

```
BDD cycle for <slug>:
  ✓ Step 1-2: spec at .task-staging/<slug>/spec.md
  ✓ Step 3: <N> failing tests in <files>
  ✓ Step 4: green (full suite passes)
  ✓ Step 5: commit <hash>, PR <url>
  ⏸ Step 6: pushed, awaiting hook + CI
  ⏸ Step 7-8: awaiting reviewer
  ⏸ Step 9: reflection pending until merge / "done" signal
```

Or, when the user finishes the cycle:

```
BDD cycle for <slug>: complete.
  ✓ Merged: <PR url>
  ✓ Reflection batch applied: <N> system updates (see /session-reflect output)
```

## Why this umbrella exists alongside the atomic skills

You could argue the atomic skills are enough on their own — the user just calls them in order. But:

- The atomic skills don't know what comes next, so they can't tell the user "step 4 done, ready for step 5?". The umbrella does that.
- Humans (especially mid-task) skip steps. The umbrella resists by making each transition deliberate.
- The umbrella encodes the *order* of the cycle as a first-class artifact — readable, modifiable, testable. The atomics encode each *step*. Both are needed.

## What this skill does not do

- Does not run all 9 steps without checkpoints. Each transition is a stop.
- Does not auto-skip steps the user might want done — it asks.
- Does not duplicate the work of the atomic skills. The umbrella delegates; it doesn't reimplement.
- Does not require all 9 steps for trivial tasks. Mode 1 is the default; lighter modes are first-class.
- Does not block on review when the cycle naturally pauses — the user's other work matters.
