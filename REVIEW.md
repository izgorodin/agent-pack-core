# Self-review: the pack reviews the pack

`agent-pack-core` dogfoods its own discipline. The skills, agents, and protocols here exist
to make engineering and research verifiable — so the repo that ships them holds itself to
exactly that standard. This is not aspirational; it is the merge process.

## Every PR runs the loop

For every pull request to this repo, before merge:

1. **`/code-review`** — review the diff for correctness bugs and for reuse / simplification
   / efficiency cleanups. Findings are addressed or explicitly waived with a reason in the
   PR thread.
2. **`/security-review`** — review the diff for security issues. Because this pack carries a
   `secrets-hygiene` rule and a `docs-guard` coupling gate, a security finding on a secrets
   or coupling-marker regression is treated as blocking, not advisory.
3. **`/merge-readiness`** — the GO / NO-GO gate. It produces a trust ledger over the
   evidence: gate status, review outcomes, and any open findings. The verdict is binary.

A PR merges only on a **GO**. A **NO-GO** lists exactly what is missing; the author closes
those items and re-runs the gate. No silent merges, no "I'll fix it after."

## Why this is the charm in action

The point of an evidence-first toolkit is undermined the moment its own repo ships on vibes.
Running `/code-review` + `/security-review` + `/merge-readiness` on every change means each
release is itself a worked example of the methodology the pack teaches. The audit agents
(`contradiction-hunter`, `clarity-validator`, `ai-research-scientist`) are available to
dispatch on docs-heavy PRs to catch cross-document drift before it ships.

## After merge

Run `/session-reflect` on substantive sessions: turn what you learned into concrete updates
to the skills, rules, protocols, or CI in this repo. The pack improves the pack. That loop —
review in, reflection out — is the whole idea.
