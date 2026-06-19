# agent-pack-core

Evidence-first BDD and research-discipline skills, audit agents, protocols, and rules for
Claude Code. Portable, workspace-agnostic, Apache-2.0.

This is not another catalog of "do task X" skills. It is a small, opinionated toolkit for
working the way good engineering and good research actually demand: **prove it, don't
recall it.** Every skill cites `file:line` or command output as evidence; review and audit
are first-class, not an afterthought; and the pack improves itself.

## What it is

A Claude Code plugin you add to your marketplace and install as a single plugin (all skills
become available at once). Drop it into any repo, in any language — the skills detect your stack and read your project's conventions
rather than assuming them. There are no workspace paths, no vendored credentials, and no
domain assumptions baked in. The benchmark/experiment family reads its domain values from a
profile you write (see `profiles/_example-profile.template.md`); everything else is generic
out of the box.

## What makes it distinct

Most published skill packs are either Anthropic's reference skills (great building blocks,
authoring-focused) or research-content collections. This one is built around four things
they do not foreground:

1. **Evidence-first, anti-hallucination by default.** The `anti-hallucination` and
   `algorithmic-fidelity` protocols and the `merge-readiness` "trust ledger" make
   *verifiability the default*. Skills cite the file and line or the command output that
   proves a claim, rather than asserting from memory. A claim with no evidence is treated
   as a rumour, not a fact.

2. **Audit agents as first-class citizens.** `contradiction-hunter`, `clarity-validator`,
   and `ai-research-scientist` ship as parallel-dispatch reviewer subagents. Depth review
   and cross-document contradiction-hunting are part of the toolkit — not just authoring
   and shipping.

3. **Bench / experiment discipline as portable methodology.** Paradigm-before-run,
   never-compare-across-paradigms, pre-registered locked specs (`lock-bench-spec`), and a
   four-tier autonomous-loop halt evaluator (`check-stop`) — research rigor distilled into
   reusable skills, parameterized by a workspace profile. This is research *process*, not
   research *content*.

4. **A self-improvement loop.** `session-reflect` turns observations from a finished
   session into concrete updates to skills, rules, CI, and ADRs — and the whole pack
   dogfoods itself (see [REVIEW.md](./REVIEW.md)). The pack reviews the pack and improves
   the pack.

## Install

Add the marketplace, then install the plugin — all skills become available at once:

```bash
/plugin marketplace add izgorodin/agent-pack-core
/plugin install agent-pack-core@agent-pack-core
```

Or run a local checkout directly without installing:

```bash
claude --plugin-dir ../agent-pack-core
```

## Catalog

### Skills — BDD / workflow

- `describe-task` — turn a fuzzy request into a precise behavior statement + deliverables.
- `write-failing-tests` — write meaningful red tests before any production code.
- `make-green` — implement the minimum code that turns red tests green; no gold-plating.
- `commit-and-pr` — run the local quality gate, generate a real commit message from the
  diff, commit, and open a PR. Refuses to commit if the gate fails.
- `address-review` — read PR comments, plan per comment (accept / push back / partial),
  apply, re-run the gate, push — without auto-resolving threads.
- `pr-preparation` — polish a multi-commit branch for review (squash/reword, PR body from
  the diff).
- `session-reflect` — convert a finished session into concrete infrastructure improvements.
- `bdd-workflow` — the end-to-end 9-step cycle that orchestrates the skills above.
- `merge-readiness` — GO / NO-GO gate with a trust ledger over the evidence.
- `spawn-worker-subagent` — fan out work to a worktree-isolated worker subagent.
- `goal-launch` — launch a goal-directed run (ships `launch-windows.ps1` + `launch-posix.sh`).
- `validate-plugin-marketplace` — lint a marketplace + plugin manifest pair.
- `skill-creator` — create, improve, and eval skills (vendored from Anthropic, Apache-2.0).
- `onboarding` — first-run orientation: what the pack is, the skills, `goal-launch` safety, and the conventions.

### Skills — bench / experiment methodology

- `experiment-design` — paradigm-before-run discipline.
- `experiment-campaign` — unattended loop with a budget cap, stop-on-regression, and
  serialized shared store.
- `run-experiment` — the pre-flight → background-execute → validate → report → registry →
  commit spine.
- `bench-spec-author` — the benchmark-spec authoring interview (class taxonomy, two-axis
  assembly, verdict logic, anti-Goodhart).
- `check-stop` — the four-tier autonomous-loop halt evaluator.
- `lock-bench-spec` — mechanical pre-registration lock + tag.

### Agents

- `ai-research-scientist` — research-grade reviewer subagent.
- `clarity-validator` — flags ambiguity and underspecification.
- `contradiction-hunter` — hunts cross-document contradictions.

### Protocols

- `anti-hallucination` — cite evidence; never fabricate structural facts.
- `algorithmic-fidelity` — numerical/research code must honor its algorithmic guarantees.
- `review-and-merge` — the depth-review and merge-decision discipline.
- `experiment-paradigm-discipline` — the three-paradigm model, never-compare-across-
  paradigms, tier cadence, and registry-row provenance.

### Rules

- `python-base` — baseline Python conventions.
- `typescript-base` — baseline TypeScript conventions.
- `secrets-hygiene` — provider-neutral never-commit / never-log / never-paste + leak
  response.

### Profiles

- `_example-profile.template.md` — neutral stub the experiment skills point at; copy and
  fill it for your domain.

## Companion: Anthropic's reference skills

This pack does not vendor most of Anthropic's reference skills. If you want `claude-api`,
`mcp-builder`, or `pdf`, pull them from
[anthropics/skills](https://github.com/anthropics/skills) and run them alongside this pack —
composition, not vendoring. Keeping them upstream means they never rot against their source.

`skill-creator` is an exception: it is **included and vendored** in this pack under
`skills/skill-creator/`, attributed to Anthropic (Apache-2.0 — see `skills/skill-creator/LICENSE.txt`
and the `NOTICE` file at the pack root). The vendored copy is unmodified.

## Pinning for consumers

For reproducibility, pin to a tag or commit when you add this pack rather than tracking a
moving branch. A skill's behavior can change between versions; pin so your team gets the
same toolkit you reviewed. When you bump the pin, run your own review over the diff before
adopting it.

## License

Apache License 2.0. Copyright 2026 Eduard Izgorodin. See [LICENSE](./LICENSE).
