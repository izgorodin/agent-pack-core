# Review-and-merge protocol

**Status:** Active (v1) — ratified 2026-06-19 after independent review.

How work produced by goal-agents / subagents gets from "done" to "merged" without the lead (or the human owner) drowning in manual QA, and without producer-rationalized errors slipping into `main`.

This protocol is the connective tissue between existing pack pieces:
`goal-launch` (start a run) → `check-stop` (in-loop halt for research loops) → **this protocol** (review-gate + merge decision) → `review-methodology` (external research depth review, if your workspace ships one) / `address-review` (PR-comment processing).

---

## The core distinction: complete vs correct

Two different things get proven by two different mechanisms. Conflating them is the trap.

- **Completeness** — "is the work whole?" Files exist, sections present, syntax/tests pass, the declared checks are green, CI + automated review clean. This is **objectively self-checkable** — a producer can mechanically verify it on its own output. No independence required.
- **Correctness** — "is the work *right*?" Does the migration actually do what it claims; does the test assert the real behaviour; is the contract honoured. This **requires independence** — the producer has already rationalized its own output, so it cannot see its own blind spot. Self-review catches execution errors, never errors of intent.

> Iron rule: **an in-loop completeness check never auto-merges.** It gates "done", not "right". Merge is a correctness decision, and correctness needs an independent eye.

---

## Three tiers, by stakes

| Tier | Proves | Where | When |
|------|--------|-------|------|
| **L1 — mechanical proof** | complete | in-loop | **always** — files/sections present, syntax, tests green, CI + automated review pass, scope = expected files |
| **L2 — grader wave** | output coheres | in-loop | for **non-trivial** output — one fresh-context grader reads the artifact cold |
| **L3 — external** | correct | out-of-loop, before merge | for **load-bearing** — independent adversarial wave (multi-dimension) + execution re-verify + human ratify |

**L3 in practice** = a Workflow adversarial wave (N independent verifiers, each a distinct lens, each blind to the producer's reasoning) **plus** an execution re-verify the lead runs themselves (trust-but-verify), **plus** a human ratify on the genuinely irreversible/contested calls.

For research artifacts the L3 wave is `review-methodology` (contradiction-hunter + clarity-validator + ai-research-scientist), if your workspace ships one. For code it's a per-dimension Workflow (domain-invariant / migration round-trip / contract-fidelity / regression-scope / domain-specific).

---

## The load-bearing boundary (when L3 external is required)

Not by artifact type — by **cost of error × irreversibility × downstream-consumer**. External required for:

- code in the core (`src/`)
- **DB migrations / schema** (irreversible in prod)
- **public numbers** (bench results, README claims, numbers cited in an ADR)
- **ADRs** (binding on the future, append-only)
- **anything other agents/humans read as fact**

In-loop (L1 + L2) + selective human glance is enough for: research dossiers, exploratory notes, reversible local artifacts.

---

## Why this isn't theatre — green CI is not correctness

The protocol earns its keep precisely when **integration is green and the producer self-reports success** — and the L3 wave still catches real defects. The recurring pattern:

- A producer reports a fix landed "at the image / config layer". The independent verifier finds the residual one layer down — e.g. the schema DDL is still fragile, safe only by build-time discipline, not by the schema itself. The producer had rationalized "fixed at the outer layer"; independence found the residual at the inner layer.
- A change ships with a full integration suite green and the producer reports done. The adversarial lens, asking "what input would this miss?", finds silent data loss — change-detection compares only a subset of fields, so an edit to an uncompared field is dropped on the floor — and an orphan-on-rename with no reconciliation pass. **Integration didn't catch them because the tests only exercised the compared fields.** Green ≠ correct.
- A producer silently resolves a question that actually needed a human decision (e.g. an irreversible schema/semantics call). L3 escalates it to the human owner per the critical-action contract instead of shipping a docstring-rationalized ADR amendment.

And the lead's **execution re-verify** routinely catches the lead's *own* setup errors — verifying on the wrong branch, the wrong DB DSN, a production-vs-test target — which a producer's self-report would never flag. Trust-but-verify cuts both ways.

The lesson the factory runs on: **green CI + producer "done" is L1, not L3.** For load-bearing work, the independent wave is what converts "looks done" into "is correct".

---

## Flow for a goal-agent / subagent PR

1. **Producer** (subagent / goal-run) implements, self-checks L1 (its own gate green), commits to a branch, pushes. **Does not open the PR** if the change is load-bearing — the lead opens it after L3.
2. **Lead** runs L3: a Workflow adversarial wave (dimensions chosen for the change) + an execution re-verify (re-run the real tests/migration on the real target — confirm the producer's numbers, don't trust them).
3. **Synthesize verdicts.** 0 blocker / 0 major → proceed. Any blocker/major → return findings to the producer (fix), re-verify the fix (focused wave). `needs-human-decision` → escalate to the human owner with the facts; do not self-resolve a committed-decision amendment (critical-action contract item 3).
4. **Open the PR** with the verdict summary in the body (which dimensions ran, what they found, how findings were addressed). CI + automated review = the external automated layer on top.
5. **Merge is the human's** for load-bearing changes (merge to `main` = visible, shared, often irreversible). The lead recommends go/no-go with proof; the human owner merges.

---

## What this protocol does NOT do

- It doesn't replace CI / automated review — those are part of L1/L3 automated coverage, not a substitute for the adversarial wave.
- It doesn't gate cosmetic/reversible local edits — those are L1 + glance.
- It doesn't let the lead self-ratify a committed-decision amendment, a default-flip, a bench verdict that drives a decision, or a destructive/cross-repo action — those are the critical-action contract's human-double-check list.

## References

- your repo's critical-action / verify-before-claiming rule, if present — the human-double-check list this protocol defers to, and the "name a coordinate before claiming a win" discipline; the execution re-verify is that coordinate.
- `protocols/anti-hallucination.md` (this pack) — adjacent integrity discipline.
- skills: `goal-launch`, `check-stop`, `review-methodology` (if your workspace ships one), `address-review` — the pieces this protocol connects.
