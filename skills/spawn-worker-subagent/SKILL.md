---
name: spawn-worker-subagent
description: Spawn 2-4 worker sub-agents in parallel (one per independent task, typically GitHub issues) followed by per-PR review sub-agents, with built-in DX-watch so each run also triangulates infrastructure friction. Trigger phrases — "run these in parallel", "spawn agents on these issues", "fan out these tasks", or a user message containing 2-4 GitHub issue numbers separated by commas/and. Produces one top-level aggregation report with PRs + triangulated DX findings.
---

# Spawn worker sub-agents — orchestration pattern

You are the lead orchestrator. Your job: spawn N worker sub-agents in
parallel (one per issue), spawn review agents per resulting PR, then
aggregate everything into a single top-level report.

**Two equal-priority objectives** for every spawn:

1. **Task completion** — each worker closes their issue's acceptance
   criteria via a real PR.
2. **DX custodianship** — each worker flags friction (lying docs,
   missing fixtures, undocumented env vars, missing tools, rules that
   misfire). The lead aggregates findings, **proposes** routing, but
   does NOT auto-apply changes to shared infrastructure (skills,
   rules, hooks, CI, CLAUDE.md).

The dual objective matters because parallelism turns DX signal from
anecdote into **triangulation**: 3 independent workers hitting the
same friction is a real signal, not "one agent in a bad day."

## When to use

- 2-4 independent issues sharing a domain (so DX findings comparable)
  but not files (so workers don't collide).
- Reasonable size budget (each worker XS-M).
- Goal includes "find out what's broken in our setup," not just ship.

## When NOT to use

- Sequential tasks with hard ordering dependencies.
- Single large task → use a single worker.
- Tasks needing deep iteration with the user.
- High-coupling refactors where workers would collide.

## Architecture

```
LEAD orchestrator (you)
├── Worker A (issue #N1, worktree, parallel)
├── Worker B (issue #N2, worktree, parallel)
├── Worker C (issue #N3, worktree, parallel)
│   ↓ each worker opens PR + posts DX report
├── Review-A (audits PR #M1, NO worktree, parallel)
├── Review-B (audits PR #M2, NO worktree, parallel)
├── Review-C (audits PR #M3, NO worktree, parallel)
│   ↓ review agents catch regressions workers missed
└── LEAD merges (or hands off) + writes TOP-LEVEL REPORT
```

## Spawn mechanics

Spawn workers in ONE message — multiple parallel `Agent` calls. Same
for review agents. Sequential loses wall-clock AND triangulation.

```
Agent({
  description: "Worker A — issue #N1",
  subagent_type: "general-purpose",
  isolation: "worktree",    // workers get worktree
  run_in_background: true,
  prompt: <WORKER_BRIEF>,
})
Agent({ description: "Worker B — issue #N2", ... })
```

**Worktree constraints to bake into every worker brief:**

- Do NOT run the dependency-install command inside the worktree — the
  worktree shares the parent checkout's installed deps; reinstalling
  inside it corrupts the parent's state on some toolchains.
- Spawn workers in parallel, not serially — serial loses both
  wall-clock time and the triangulation that makes shared DX findings
  trustworthy.
- If your repo documents a worktree/hook-execution contract in
  CLAUDE.md (e.g. a junction-symlink step on Windows), apply it.

Review agents — **NO worktree** (read-only, work via `gh pr diff` +
`git show <ref>:<path>`). A review agent that runs
`git checkout origin/branch -- paths` pollutes the parent's working
tree — forbid it explicitly and have reviewers read via `git show`
instead.

```
Agent({
  description: "Review A — PR #M1",
  subagent_type: "general-purpose",
  // NO isolation — review is read-only
  run_in_background: true,
  prompt: <REVIEW_BRIEF>,
})
```

## Worker brief template

Copy verbatim, append per-issue specifics at the bottom:

```
You are a worker sub-agent in a parallel orchestration run. ONE issue,
TWO equal-priority objectives:

1. PRIMARY — deliver a PR that closes the issue's acceptance criteria.
2. DX CUSTODIAN — while working, notice friction. Examples:
   - Lying README / wrong code-path docs.
   - Missing test fixture you had to fabricate.
   - Undocumented env var (no doc said you'd need it).
   - Tool that should exist and doesn't.
   - Rule in .claude/rules/ that misfires.
   - Hook that blocked you despite legitimate work.
   - Confusing error message you had to decode.

Boundaries (firm):
- Do NOT refactor adjacent code beyond the issue scope.
- Do NOT add features not in the issue.
- Do NOT fix issues you spot outside this PR's scope — they go in
  the DX report, NOT in your commits.
- Do NOT amend / force-push without explicit instruction.
- Do NOT update CHANGELOG.md by hand if the repo uses changesets
  (creates orphan changesets that conflict with the bot).
- Do NOT auto-modify shared infrastructure (skills / rules / hooks /
  CI / CLAUDE.md). Findings → DX report.
- Do NOT run the repo's dependency-install command inside this
  worktree. See your repo's worktree/hook-execution contract in
  CLAUDE.md, if present.
- If the task is larger than it looked, STOP and document why.

Pre-flight:
1. `git log --oneline -5` to match the repo's commit message
   conventions (type(scope): subject, emoji prefixes, etc.).
2. Check for a worktree-execution contract in CLAUDE.md and apply its
   pre-flight (e.g. a junction-symlink script).

Workflow:
1. Create a branch in your worktree.
2. Apply minimum-diff fix.
3. Run the relevant tests (use the repo's test command, run against
   the affected package if the repo is a monorepo).
4. Commit. Push branch. Open PR via `gh pr create`.
5. Post DX report as a PR comment.

DX report format (exact section names):

## What changed
3-7 bullets with file:line refs.

## DX observations
For each piece of friction:
- One-line description.
- Where noticed (file / doc / command).
- Severity: 🔴 blocked work, 🟡 slowed me down, 🟢 noted for future.
- Suggested routing: skill / rule / CLAUDE.md / new tool / PR comment / drop.

If nothing — "No DX issues. Tooling+docs held up."

## What surprised
Anything where actual code disagreed with docs/rules.

## Limitations
Tests skipped, deps unresolvable, `--no-verify` used and why, etc.

---

ISSUE FOR THIS WORKER:

[issue body inline]
```

## Review-agent brief template

Spawn ONE review per worker PR, in parallel after workers finish.
**No worktree** — read-only via `gh` and `git show`.

```
You are a review sub-agent. ONE PR to audit, no merge authority.
You are READ-ONLY — work via `gh pr diff` and `git show <ref>:<path>`.
NEVER `git checkout origin/branch -- paths` — pollutes parent worktree.

Read:
- gh pr view <NNN> --json title,body
- gh pr diff <NNN>
- The issue body the PR claims to close.

Output is a PR comment with these sections IN THIS ORDER:

## Verification log
Concrete commands you ran to verify (`git show <sha>:<path>`,
`gh pr diff <N>`, etc.) and a one-line summary of what each
established. This is the anti-hallucination block — proves you
read what you claim to have read.

## Coverage of acceptance criteria
Did the PR actually close each acceptance bullet? Quote the criterion
+ code citation. If not satisfied, name the gap.

## Possible regressions
For each: file:line, what could break, who notices.
🔴 must-fix-before-merge, 🟡 follow-up, 🟢 noted.

Possible-regressions-that-turn-out-real are the highest-value output
of the review step.

## API misuse / hardening (REQUIRED when PR changes a shared interface)

A PR counts as «changes a shared interface» when ANY of these is true:

- exports a NEW type / function / class that other modules will import
- modifies an EXISTING exported type (rename, reshape, change required-ness)
- **adds a NEW OPTIONAL field to an existing exported type** — this is
  the «backward-compat trap» that often pattern-matches as «low-risk,
  skip hardening probe». In reality, the new field changes the type's
  shape AND its read/write semantics, which is exactly where the
  subtlest misuse bugs land. If the diff adds a field, the misuse lens
  applies.
- alters a provider contract / helper that other modules call

If NONE of the above — internal-only refactor, pure bug fix touching
no exported surface — the section may be omitted with a one-line note
saying so. For everything else, this section is non-optional.

Standard probes:

- **Unexpected-but-valid input** — can a caller pass a value that
  satisfies the static type but breaks invariants? (empty string, `null`,
  `undefined`, very large input, special chars, mixed-case keys, zero
  / negative numbers where positive expected)
- **Caller-side mutation after the call** — returned-by-reference
  objects or retained parameter refs that a defensive shallow-clone
  would prevent. (Example: provider stores caller's metadata bag, then
  caller mutates it for the next message → corrupted storage.)
- **System-field override via spread / merge order** — bookkeeping
  vs user-supplied payload. Does the provider's metadata win, or does
  caller's spread come last and silently take over identity keys?
  (`{...bookkeeping, ...userPayload}` vs the reverse — wildly different
  trust models.)
- **Asymmetric defense** — if the implementation clones / validates /
  sanitises on ONE side of a read/write pair but not the other,
  mutation poisoning is still possible end-to-end. Examples:
  clone-on-write but return-by-reference on read; validate-on-create
  but accept any shape on update; reject empty string in one helper
  but not in its sibling. Verify defense PARITY across the pair.
- **Concurrent reuse of input** — caller reuses the same metadata bag
  for the next message. Is each call isolated, or do mutations leak
  via shared object identity?
- **Type strictness** — is the new field `any` or `Record<string,
  unknown>`? `any` silently accepts typos at call sites; the latter
  forces explicit casts. Prefer the latter.

**For each probe with a hit, cite `file:line` and quote the problematic
code.** A bare «✅ checked, looks fine» without citation is checkbox
theatre — it doesn't earn the mandatory slot and it doesn't let the
lead distinguish «reviewer actually looked» from «reviewer copied the
bullets». Mirror the citation rigor of the `Possible regressions`
section above.

## Follow-up worth tracking
Code-quality findings that don't block merge. Suggested GH issue title.

## Verdict
LGTM / LGTM-with-followups / requested-changes.

DO NOT formally approve/reject the PR. The lead decides.
```

**Why the review pass exists — concrete example:**

On a real run, a per-PR review agent flagged under 🟡 follow-up that a
preflight-tools change made unrelated mock/non-tool providers start
returning 503 on a tools-service outage — those providers didn't use
tools but had silently inherited the new preflight gate. The lead
verified it as a real regression versus main behavior and fixed it
before merge. **One catch paid for the whole orchestration run.** Don't
skip the review pass on M-sized PRs.

**Why the misuse/hardening probe is REQUIRED — concrete example:**

On a real run, a metadata-propagation PR shipped past a large
spec-conformance review with every reviewer saying LGTM on «does
metadata propagate correctly?». A parallel review run with a hardening
framing caught two 🔴 issues the conformance pass had walked past:

1. An in-memory provider's `storeMemory` pushed the caller's metadata
   BY REFERENCE into internal storage. Mutation of the original object
   after the call would corrupt stored records. The query path mirrored
   the problem — returned stored objects by reference, so caller
   mutation of `result.metadata.field` would poison the next read.
2. A core provider's `storeMemory` spread `...memory.metadata` AFTER
   the provider's bookkeeping block. Caller-supplied metadata could
   silently override identity / scope / schema-version keys in stored
   records — an audit-trail integrity bug.

Both real. Both fixed (shallow-clone defenses + a reserved-keys strip).

The conformance pass missed them because the prompts asked «is this
correct?», not «can this be misused?». Different question, different
lens. For PRs touching shared interfaces, the misuse lens is
non-optional.

**Falsifiability check.** A mandatory probe earns its slot only by
paying for itself in caught regressions. If after roughly 3 review
cycles the misuse probe surfaces zero real findings, demote it to
optional and re-evaluate what's missing — maybe the trigger («shared
interface») is too narrow, maybe the probes themselves are wrong for
this codebase, maybe the reviewers are pattern-matching past it. Track
the catches as you go (PR labels, a short log, or even a `grep` for
«misuse probe» in PR comments) so the answer is data, not vibes.
Without this check, mandatory probes accrete forever — that's how
skills become bureaucracy.

## Lead aggregation (top-level report)

Once all reviews come in, write ONE report:

```
# Top-level orchestration report

## PRs opened / status
| PR | Issue | State | Sub-agent |

## Triangulated DX findings
Group findings ≥2 workers independently surfaced. Highest-value
signal — name prominently.

If NO findings repeat across workers, name that as the verdict
signal: either the friction wasn't shared (everyone hit unique
potholes — broader infrastructure issues, fewer concentrated ones)
OR workers didn't pay DX attention. Both outcomes are useful.

## Singular DX findings (per worker)
The ones only one worker hit. Routed proposals (rule / skill / hook /
drop) — propose, don't apply.

## Real regressions caught by review pass
What the review agents flagged that workers missed. With fix status
(fixed before merge / deferred to follow-up).

## Verdict on the experiment
2-3 sentences: did parallelism produce useful triangulation? What
would change for next run?
```

## Common mistakes

- Spawning workers serially → loses both wall-clock AND triangulation.
- Skipping the review pass on M-sized PRs → regressions slip through.
- Lead auto-applying DX findings → breaks the "propose, don't enact"
  custodian rule. Findings go in the report; the user routes them.
- Re-using the same worktree for multiple workers → file collisions.
- Forgetting `run_in_background: true` → blocks the lead's loop.
- Spawning review agents with worktree isolation → wasted infra,
  reviews are read-only.
- Spec-conformance lens ≠ misuse lens. Both required for
  shared-interface PRs. The first answers «does this match the spec?»;
  the second answers «can this be misused?». A clean spec pass with
  zero misuse probes still misses reference-mutation, spread-order,
  asymmetric-defense, and type-laxness bugs.

## Subagent dispatch guardrails — for orchestrators that need state preservation

When the orchestrator dispatches a subagent with hard constraints framed
as NEGATIVE assertions ("NEVER `git checkout`", "NEVER write outside X"),
the constraints hold ONLY on the happy path described in the prompt. The
moment the subagent hits an obstacle on that happy path (the recommended
tool fails, the recommended file doesn't exist, an edge case isn't
covered), it falls back to KNOWN HABITS from training data — and those
habits are precisely the forbidden patterns.

**Empirical.** On a real run, three subagents were dispatched to review
three PRs with the explicit instruction "NEVER `git checkout`, use
`git show origin/<head>:<path>` instead". All three self-reported "no
checkout was run". Yet the parent working tree's branch was silently
switched from the feature branch to `main`, and the feature local branch
was deleted (via `git switch main && git branch -D <branch>` — a sequence
NOT in the negative-assertion list). No commits were lost (local was
clean = remote), but the constraint spirit was violated and the recovery
cost a turn of the orchestrator's attention.

The pattern is general — it applies to ANY subagent dispatch, not just
review. Code-generation subagents fall back to "create at most natural
location" when requested location is rejected. Investigation subagents
fall back to "look at adjacent files" when the target doesn't exist.

### 5 design principles for state-preserving subagent dispatch

**1. For every NEVER, name the FALLBACK for the failure case.** Don't
just say "use git show"; say "if git show fails: A. try
`gh api .../contents/<path>?ref=<sha>`; B. fall back to `gh pr diff`
content only; C. if neither suffices, return partial findings with a
NOTE — DO NOT switch branches or modify the working tree to compensate".
Without an explicit alternative, the trained-habit fallback wins.

**2. Name the CLASS of forbidden operations, not one example.** If your
forbid-list is one item long, expect violations under stress. List
`checkout, switch, restore, reset, rebase, merge, worktree add, branch -D,
update-ref` — name the class, not a single member.

**3. Pre/post state verification in the orchestrator.** Snapshot before
dispatch, verify after — never trust the subagent's self-report alone.

```powershell
$preBranch = git branch --show-current
$preSha = git rev-parse HEAD
$preDirty = git status --porcelain

# ... dispatch subagent ...

$postBranch = git branch --show-current
$postSha = git rev-parse HEAD
$postDirty = git status --porcelain
if ($preBranch -ne $postBranch -or $preSha -ne $postSha) {
    Write-Warning "Subagent drift: branch $preBranch→$postBranch, SHA $preSha→$postSha"
    git switch $preBranch  # auto-recover
    # surface violation in human-visible log
}
```

**4. Consider `isolation: "worktree"` for read-only review subagents.**
The only PHYSICAL guard available. Subagent operates in a temp worktree
it cannot escape — parent's state is structurally unreachable. Caveat:
the worktree has no installed dependencies — fine for pure-read review,
problematic if the subagent needs to run tests (link the parent's
installed deps into the worktree in that case, per your repo's CLAUDE.md
worktree/hook contract).

**5. POSIX-style paths in subagent prompts on Windows.** Use
`/c/tmp/reviews/PR-N-review.md`, NOT `c:\tmp\reviews\PR-N-review.md`.
The subagent passes paths through bash; backslash escapes mangle them
silently. A real Windows run produced an orphan file literally named
`c:tmppr-1648-diff.txt` from a `c:\tmp\pr-1648-diff.txt` path through
`gh pr diff > $path` — backslashes were stripped before tool execution.

### Why these are stronger than just "list more NEVERs"

A growing forbid-list still describes only the happy path. The 5
principles above add structural protection orthogonal to the prompt
content: explicit alternatives close the happy-path-failure escape
hatch; class-naming generalizes one example to a category; pre/post
verification catches violations independently of self-reports;
worktree isolation removes the physical capability; POSIX paths close
the silent-mangling vector. Use all 5 together — none is sufficient
alone, and they cost almost nothing to apply.
