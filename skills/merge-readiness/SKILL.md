---
name: merge-readiness
description: The final merge gate. Run the full acceptance-criteria checklist BEFORE proposing any merge to a human (or before self-merging, once delegated). Produces a per-criterion PASS/FAIL audit + a mechanical GO/NO-GO verdict. Use every time you are about to say "this is ready to merge" / "ready for merge" / "good to merge?" / before `gh pr merge`. Operationalizes the review-and-merge protocol (complete-vs-correct, L1/L3). Refuses GO if any CRITICAL fails — that is the point. Composes /review-methodology (or a Workflow adversarial wave) for the independent-correctness tier.
allowed-tools: Bash(git*), Bash(gh*), Bash(pnpm*), Bash(uv run*), Bash(npm*), Bash(just*), Grep, Read, Glob, Agent
model: opus
---

# /merge-readiness — the final acceptance gate before a merge proposal

You are the **merge gate**. Before any merge is *proposed to the human approver* (or self-merged, once they have delegated that), you run this checklist against the actual branch/PR and emit a per-criterion **PASS / FAIL / N-A** audit with **file:line / command-output evidence**, then a mechanical **GO / NO-GO** verdict.

Two non-negotiables:

1. **This gate never auto-merges.** It produces a recommendation. Merge stays the human approver's call until they explicitly delegate it. Even when delegated, you still run this gate first and attach the audit.
2. **Evidence, not assertion.** Every PASS is backed by a command you actually ran or a line you actually read — never "looks fine". A criterion you cannot evidence is a FAIL, not a pass-by-default.

The audit is also a **trust ledger**: a run of consistently-clean audits is what earns delegated merge authority. Sloppy or hand-waved audits poison that. Treat each run as if the human approver will diff your evidence against reality — because the point is that they eventually won't have to.

## The frame: complete ≠ correct

(From `protocols/review-and-merge.md`.) Two different things, two different mechanisms — conflating them is the trap:

- **Complete** — "is it whole?" Files present, typecheck/lint/tests green, CI + CodeRabbit clean, scope = expected files. **Self-checkable** by the producer. This is tiers **A–E** below.
- **Correct** — "is it *right*?" Does it do what it claims; do the tests assert real behaviour; are the numbers true. **Requires independence** — the producer already rationalized its own output. This is tier **F** (the adversarial wave + execution re-verify).

A green CI + a producer "done" is **complete, not correct.** For load-bearing changes, GO requires *both*.

## Load-bearing? (decides how heavy F must be)

Judge by **cost-of-error × irreversibility × who-reads-it-as-fact**, not by file type. **Load-bearing** (full tier F required): core `src/`, DB migrations/schema, public numbers (bench/README/ADR), ADRs, contracts other agents/humans consume, anything irreversible in prod. **Not load-bearing** (A–E + a glance): reversible local edits, exploratory notes, cosmetic docs. State which class you judged it, and why, in the audit header.

---

## The checklist

Run top to bottom. For each: do the CHECK, record PASS/FAIL/N-A + evidence. **CRITICAL** items gate GO. Mark N-A only with a one-line reason.

### A — Build & CI integrity *(complete)*

- **A1 [CRITICAL] CI green on the ACTUAL head.** `gh pr view <n> --json mergeable,mergeStateStatus,statusCheckRollup` → `mergeable:MERGEABLE` + `mergeStateStatus:CLEAN`. **Then prove the green run validated the *current* head**, not a superseded commit: `gh run list --branch <b> --json headSha,name,conclusion` and confirm the passing run's `headSha` == the PR head (`gh pr view <n> --json headRefOid`). *Guards: a bot/auto-commit (e.g. changeset) landing on top of the branch so required checks were never re-run on the real tip.*
- **A2 [CRITICAL] No red / no required check missing or "expected".** A check stuck `pending`/`expected` is a FAIL, not a pass. Skipped ≠ passed.
- **A3 Local gate matches CI** where the local env can run it: `pnpm typecheck && pnpm lint` (or repo equivalent). If a runner is broken locally (e.g. vitest on Node 25), say so and note that CI is the authority for that check — never claim a local green you didn't get.

### B — Tests are real, not vacuous *(correct — the anti-coincidence tier)*

- **B1 [CRITICAL] The gating test is coupled to the code.** Prove it FAILS when the behaviour breaks: revert the prod change **in the working tree (not a commit)** → run the test → confirm **RED** → restore. For a type-level lock, mutate the owner type → confirm `typecheck` fails at the lock → restore. A test that stays green when you break the code proves nothing. *Guards: TDD-veracity — coincidental green.*
- **B2 New lint/guard rules are non-vacuous AND precise.** Fire-test: introduce a real violation in a throwaway file → confirm it trips. Then run the rule repo-wide → confirm **zero false positives**. Delete the throwaway. *Guards: a `no-restricted-syntax` selector that matches nothing, or one that flags unrelated code.*

### C — Completeness of the change *(correct)*

- **C1 [CRITICAL] All affected sites enumerated, not just the named ones.** `grep`/`Grep` the whole repo for the pattern you changed (symbol, literal, shape) and confirm every site is handled. *Guards: the "fixed one half of a producer/consumer pair, missed the other" miss.*
- **C2 Coverage claims are reproducible.** Any "N→1", "6 copies", "all call-sites" claim in the PR/commit/ADR is backed by a grep you can paste. If you cannot reproduce the number, reword it — don't ship an unverifiable count.

### D — Honesty / no lying-doc *(correct)*

- **D1 [CRITICAL] Every doc/ADR/PR/commit claim matches the diff.** No present-tense prose describing code that does not exist yet (a guard/test "that exists" but doesn't). Read the diff; reconcile each claim. *Guards: the prototype-README that advertised an ESLint guard + drift test that weren't in the tree.*
- **D2 [CRITICAL] Every number is reproducible from a committed artifact.** Bench results, "N faster", counts in ADRs/READMEs/PR bodies — trace each to a committed file or a command. `/tmp` scripts and stdout printouts are NOT sources.
- **D3 No marketing tells in the prose.** grep the PR/commit/ADR for structural/breakthrough/"honest-answer-first"/DOMINANT/"new features" (when it's a refactor) and first-person overclaim. The first draft should already pass.

### E — Scope, safety & contracts *(complete)*

- **E1 [CRITICAL] Diff touches only what the change requires.** `git diff main...HEAD --stat`. No scope creep, no drive-by edits, and none of the forbidden zones (e.g. `<forbidden path>`, another person's open-PR branch) unless the task is explicitly that.
- **E2 [CRITICAL] Frozen/locked contracts untouched or extended additively only.** Confirm the locked wire DTO / public schema is byte-unchanged (`git diff main...HEAD -- <locked file>` empty) or only additively extended with its contract test still green.
- **E3 [CRITICAL] No secrets in the diff.** Scan for keys/tokens/credentials. A leaked secret is the owner's to rotate — never ship one.
- **E4 Lockfile / generated files delta is exactly expected.** `git diff main...HEAD -- pnpm-lock.yaml` (or equivalent) = only the edges you intended; no phantom entries.

### F — Independent correctness *(the load-bearing tier — required for load-bearing changes)*

- **F1 [CRITICAL for load-bearing] An independent adversarial wave ran AND its must-fix findings are fixed (not merely acknowledged).** Use `/review-methodology` for research/methodology, or a Workflow panel of N reviewers (distinct lenses: correctness / tests / completeness / contract-fidelity / honesty) for code. Each reviewer blind to the producer's reasoning. Re-verify each fix. List the findings + how each was resolved. *Guards: green-but-wrong; self-review never catches errors of intent.*
- **F2 Execution re-verify by you, not the producer's word.** Re-run the real tests/build/migration on the real target yourself; confirm the producer's claimed numbers. Trust-but-verify — this also catches *your own* setup errors (wrong branch, wrong DSN, prod-vs-test target).
- **F3 needs-human-decision escalated, not self-resolved.** Any committed-decision amendment, default-flip, bench verdict driving a decision, or destructive/cross-repo action goes to the human approver with the facts — never resolved by docstring rationalization.

### G — Process & authority

- **G1 [CRITICAL] No self-merge without explicit delegation.** Until the human approver has delegated merge for this class of change, the verdict is a *recommendation*; you do not run `gh pr merge`. Held PRs (e.g. a HOLD pending an upstream layer) are NO-GO to propose regardless of cleanliness.
- **G2 PR hygiene.** Base is correct; branch is not `main`; PR body has the reviewer-voice section (attack surfaces → targeted review asks) + the self-review checklist. Diff is reviewable (<~800 lines / <~15 files) or a split was flagged.
- **G3 Reversibility stated.** Forward-only/additive where possible; rollback path or irreversible steps explicitly flagged.

---

## Verdict (mechanical)

- **NO-GO** if **any CRITICAL fails**, or any non-N-A item is unevidenced, or (load-bearing) tier F did not run.
- **GO — propose to the human approver** if all CRITICALs PASS and remaining items are PASS or justified N-A. Attach the audit + the disclosed non-blocking limitations (the HIGH-but-disclosed items, follow-ups).
- Never "GO — merged": the merge action is the human approver's until delegated, and even then this audit is attached.

## Output format

```
MERGE-READINESS AUDIT — PR #<n> "<title>"  (<load-bearing | not-load-bearing>, because …)
A1 CI-on-actual-head     PASS  mergeable=CLEAN; green run headSha=c4539974 == PR head ✓
B1 test-coupling         PASS  reverted owner → slice.contract.test.ts:372 RED → restored
C1 site-enumeration      PASS  grep "<pat>" → 7 sites, all handled (list)
D2 numbers-reproducible  PASS  "6→1" = grep … (paste)
F1 adversarial-wave      PASS  5-reviewer panel (ids); 2 must-fix found → fixed (refs)
…
VERDICT: GO — propose to the human approver.  Disclosed non-blockers: <…>.
```

Keep evidence terse but real (a SHA, a line number, a one-line grep result). The audit is the artifact; bloat hides the signal.

## Toward delegated merge

The human approver's stated path: when these audits come out consistently clean and reproducible, they may delegate merge authority for some change-classes so iteration speeds up. That delegation is *earned by the ledger*, not assumed. When delegated: still run this gate, still attach the audit, still escalate F3 items — the only thing that changes is who clicks merge.

## What this skill does NOT do

- It does not author code/docs (that's the BDD/authoring skills) or fix findings (that's `/address-review`).
- It does not replace CI/CodeRabbit — those are part of tier A/F-automated, not a substitute for tier F's adversarial wave.
- It does not gate cosmetic/reversible local edits beyond A–E + a glance.

## References

- `protocols/review-and-merge.md` — the policy this operationalizes (complete-vs-correct, L1/L2/L3, the load-bearing boundary, live evidence). *(Companion draft; pending the maintainer's review.)*
- `protocols/anti-hallucination.md` — adjacent integrity discipline.
- skills: `review-methodology` (the F1 wave for research), `address-review` (process findings), `pr-preparation` / `commit-and-pr` (the pre-review packaging this gate sits after).
