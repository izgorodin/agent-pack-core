---
name: self-improve
description: Drive the pack's own improvement loop — capture learnings from a session or PR into a backlog, then (deliberately, not automatically) batch-generate and gate proposed skill/rule changes. Use when the user says "let's improve the pack", "process the backlog", "generate improvements from the backlog", or "add this to the improvement backlog". Also use when a session ends and there are learnings worth capturing — even if generation is not happening yet. Composes session-reflect (capture), skill-creator (generate/iterate/eval), and merge-readiness (gate). Never self-merges into the pack.
---

# self-improve — the pack's own improvement loop

This skill drives a two-phase loop: **cheap capture on every session** and **deliberate batched generation** when the backlog warrants it. The two phases are intentionally decoupled — capture is always-on and fast; generation is expensive and gated.

---

## Phase 1 — Capture (cheap, per-session)

**When to run:** at the end of any session that produced a learning worth keeping. Costs < 2 minutes.

**What this phase does:**

Run `/session-reflect` in its normal mode. When it surfaces a finding that belongs in the pack itself — a gap in a skill, a recurring pattern with no skill, a rule that should exist — **route it to the evolution backlog rather than fixing it inline**. (session-reflect's default for skill gaps is to edit the SKILL.md directly; this skill overrides that routing for pack-level improvements, sending them to the backlog instead so they go through the full generate+gate cycle.)

Append to `evolution/backlog.md` in the pack root (create the file if it doesn't exist yet). One entry per finding:

```markdown
## <YYYY-MM-DD> — <one-line summary>

**Source:** PR #N / session <description>
**Type:** skill-gap | new-skill | rule | hook | other
**Skill affected (if any):** <skill-name> or "none"
**Finding:** <what was missing or wrong, specific — "session-reflect step 4 sends users to skill-creator but doesn't say what eval threshold to aim for">
**Evidence:** <file:line or command-output that proves it>
**Proposed direction:** <a sentence, not a solution — the solution comes in Phase 2>
**Status:** backlog
```

Do NOT design the fix here. That is Phase 2's job. Capture the finding accurately and stop.

**Trigger for Phase 2:** When the backlog crosses roughly 5 actionable entries, or on a deliberate "let's process the backlog" request from the user. Never automatically.

---

## Phase 2 — Generate + Gate (deliberate, batched)

**When to run:** user initiates — never triggered automatically. Expect this to take significant time.

### 2a — Triage the backlog

Read `evolution/backlog.md`. Group entries by type. Identify which are:
- Actionable now (finding is specific, proposed direction is clear)
- Blocked (needs more evidence — move back to backlog with a note)
- Duplicate or superseded — merge or drop

Present the triage to the user. Proceed only with their approval on which entries to process.

### 2b — Draft each improvement via skill-creator

For each approved entry, invoke `/skill-creator` to draft the proposed change:
- Existing skill edit: snapshot the current skill, iterate the edit, run evals (with-skill vs snapshot baseline)
- New skill: full skill-creator cycle — intent capture, SKILL.md draft, test cases, eval runs, grading, analyst pass
- Rule or hook: draft the artifact, write a falsification test (what does it catch; does a contrived violation actually trip it?)

**Eval bar:** a proposed improvement earns a before/after score from skill-creator's benchmark. Always include the benchmark result in the candidate. If evals show improvement, state the delta. If evals are inconclusive or the change fixes a correctness gap that the evals don't cover, say so explicitly — don't assert improvement you didn't measure, but also don't silently drop a valid correctness fix just because it didn't show in the benchmark. Present the evidence and let the human decide.

Run candidates in parallel where independent. Save all candidates to `evolution/candidates/YYYY-MM-DD-<slug>/` within the pack.

### 2c — Gate every candidate via merge-readiness

Before running `/merge-readiness`, stage each candidate on a feature branch and push it (so CI can run). merge-readiness checks CI on the actual head (criterion A1) — a candidate that exists only locally cannot pass the full gate.

Run `/merge-readiness` against the staged diff. Key criteria for skill candidates:
- **B1:** the proposed change is non-vacuous (the skill/rule fires when it should, doesn't fire when it shouldn't)
- **D1/D2:** claims in the skill body match what the skill actually does
- **F1:** an independent adversarial wave reviewed the candidate (a separate subagent blind to the author's reasoning)

**Non-negotiables from merge-readiness:**
- Gate never auto-merges. The verdict is GO/NO-GO for proposing to a human approver — not permission to install.
- Any CRITICAL fail → NO-GO. Fix and re-gate, or drop the candidate.

Note: for A1 (CI green on actual head), the pack's CI must exist and be wired. If CI is not yet configured, state this explicitly in the audit — do not wave A1 as N-A without documenting why.

### 2d — Present and await ratification

Collect all GO candidates. Produce a batch proposal:

```
Pack improvement batch — <date>

Candidates:
1. [GO] <skill-name>: <one-line change> — eval delta: +X pp pass-rate
2. [GO] new skill <name>: <one-line description> — eval vs no-skill: X% pass
3. [NO-GO] <skill-name>: <reason> — deferred back to backlog

Merge-readiness audits: evolution/candidates/YYYY-MM-DD-*/audit.md
Eval benchmarks: evolution/candidates/YYYY-MM-DD-*/benchmark.json

Ready to install: items 1, 2 above. Awaiting approval from the designated approver(s) before any file moves into the pack.
```

**No self-install.** Nothing moves from `evolution/candidates/` into the pack until the human approver(s) explicitly approve. Once approved, each accepted candidate is copied into the pack, the backlog entry updated to `status: shipped`, and a PR opened via `/commit-and-pr`.

---

## Clone divergence — keep the base in sync

If this pack has downstream clones (or if you are working inside a clone), run
`/backport-review` periodically and **always before tagging a clone release**. Universal
improvements — generic fixes, clearer wording, new domain-agnostic skills — tend to
accumulate in clones and never find their way back to the base, causing silent divergence
that compounds with every release. `backport-review` makes that debt visible and
actionable before it becomes painful.

---

## What this skill does NOT do

- Does not auto-generate improvements on a schedule or silently on every PR.
- Does not self-install any change into the pack — ever.
- Does not claim a change is better without a measured eval delta.
- Does not skip the merge-readiness gate for "obvious" improvements.
- Does not invent findings. If the session had no learnings worth capturing, Phase 1 produces nothing.
- Does not design solutions in Phase 1 — capture only.

---

## Skill composition (what each composed skill contributes)

| Composed skill | Role in this loop | Key constraint to honor |
|---|---|---|
| `session-reflect` | Phase 1: surfaces findings, routes to backlog | User approval required before any infrastructure change |
| `skill-creator` | Phase 2b: drafts + iterates candidates with measured evals | Eval bar must be met; no assertion without benchmark |
| `merge-readiness` | Phase 2c: gates every candidate | Never auto-merges; CRITICAL fails block; load-bearing changes require F1 adversarial wave |

---

## Proportionality

Cheap always-on (Phase 1) is non-negotiable — learnings lost at session end are lost forever. Expensive deliberate (Phase 2) is batched — the overhead of skill-creator + merge-readiness per candidate is high; don't trigger it for a single marginal entry.

Five backlog entries is a reasonable threshold, not a hard rule. Use judgment: three high-signal entries beat seven low-confidence ones.
