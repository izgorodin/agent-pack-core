# Rule — model delegation: the expensive model thinks, cheap models execute

A session running on a top-tier model (Opus, Fable) that also *executes* every
mechanical step burns its token budget on work a cheaper model does just as well.
The fix is structural, not a per-session reminder: the top-tier model acts as the
**orchestrator** — it plans, decomposes, delegates, reviews, and decides — while
**pinned cheap subagents** (Sonnet-class) do the execution. Field reports put the
savings at 5–10× with no quality loss *when the orchestrator reviews the output*.

## The decision order

When work is about to happen in a session, route it by nature, taking the first
option that fits:

1. **Mechanical and well-scoped** (implement a specified change, run tests, apply
   a reviewed plan, mass edits, searches, inventories, summaries) → delegate to a
   **model-pinned worker agent** (this pack ships `worker` and `scout`, both
   pinned `model: sonnet` in their frontmatter). Never inline it in the
   orchestrator.
2. **Judgment-heavy but delegable** (independent review, adversarial
   verification, synthesis across many inputs) → delegate to the appropriate
   reviewer agent; pin the model in the agent definition, not in chat.
3. **Genuinely the orchestrator's** (decompose the goal, weigh trade-offs, ratify
   results, talk to the user) → stays in the main session. This list is short —
   if the orchestrator is editing files, something leaked past 1.

## Why pinning beats asking

A subagent definition whose frontmatter **omits `model:` silently inherits the
session's model** — on a top-tier session, your "cheap" workers quietly run on
the expensive model. That inherit-default is the single most common way the
savings evaporate. So:

- Every worker-class agent this pack ships carries an explicit `model:` pin.
- Skills that spawn subagents name a pinned agent type (or pass an explicit
  `model` parameter) — they never rely on the default.
- The user should never have to say "use Sonnet subagents" in a session: the
  routing lives in checked-in agent definitions that install with the pack.

For environments that must hard-lock cost, the `CLAUDE_CODE_SUBAGENT_MODEL`
environment variable forces **every** subagent onto one model — deterministic,
but blunt: it overrides per-agent pins, including agents deliberately pinned to
a stronger model for review quality. Prefer per-agent pinning; reach for the env
var only when a hard ceiling matters more than routing nuance.

## Known failure modes (from field practice — avoid all four)

- **The orchestrator "just does it itself."** The most common collapse: the
  expensive model implements directly instead of delegating. If a mechanical
  task is about to run inline, stop and dispatch a worker.
- **Over-context to cheap workers.** Dumping the whole codebase into a Sonnet
  worker cancels the savings. Brief workers with scoped context: the files, the
  diff, the exact task.
- **Skipping orchestrator review.** Cheaper models err more often; worker output
  is a proposal until the orchestrator (or an independent verifier) checks it.
- **Static routing.** Not everything mechanical is equal — genuinely hard
  execution can warrant a stronger worker for that one call (explicit per-call
  `model` override), and trivial scans can drop a tier.

## Worked example — this pack's own wiring

`agents/worker.md` and `agents/scout.md` ship pinned to `model: sonnet`; the
`spawn-worker-subagent` skill dispatches its workers to them — and its review
dispatch to the pack's pinned reviewers (`contradiction-hunter`,
`clarity-validator` on Sonnet; `ai-research-scientist` deliberately on Opus for
research-grade depth) — instead of an unpinned general-purpose agent. Result: any session with this pack installed
gets orchestrator-plans / Sonnet-executes routing with zero per-session setup —
the same "derive or gate, never a silent default" discipline as
`no-magic-numbers.md`, applied to model choice.
