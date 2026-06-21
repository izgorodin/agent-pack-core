# Algorithmic fidelity protocol

When implementing a published algorithm — from a paper, a textbook, an existing library — match its exact mathematics and structure. Do not "improve" it during implementation, do not blend in heuristics from elsewhere, do not silently substitute a different algorithm with the same name.

## The rule

If the user (or an ADR, or a code comment) says "implement Levenshtein distance", "use BM25 for document ranking", "follow RFC-7519 JWT claim validation", or anything similar — the implementation must be the published algorithm verbatim. Nothing more, nothing less.

When you finish, the implementation must satisfy:

1. **The algorithm's published preconditions, invariants, and postconditions hold.** If you can't articulate them, you're not ready to implement.
2. **The implementation passes the source's reference tests** (if available).
3. **A reader who knows the published algorithm recognizes the code as that algorithm**, not "an algorithm".

## Why this matters

Numerical and research code relies on specific algorithmic guarantees. Levenshtein distance has a particular edit-cost model; a custom variant produces different rankings and breaks downstream comparisons. BM25 normalises term frequency in a particular way; a hand-rolled variant gives different scores. The RFC-7519 JWT claim set is a contract; dropping required fields makes tokens unverifiable by conforming libraries.

Subtle deviations are subtle to discover. A paper-faithful implementation is verifiable; a "lightly improved" one is not.

## What to do when the published algorithm is incomplete

Sometimes a paper specifies the core but leaves engineering choices open (data structure, tie-breaking rule, termination tolerance). In that case:

1. Make the choice explicitly, in code or comment.
2. Cite the paper section where it was left open.
3. Document the choice as an ADR if it has multiple defensible options.

Do **not**:
- Pick the choice silently.
- Pick a choice based on what's faster without confirming it preserves the algorithm's guarantees.
- Conflate engineering choices with the algorithm itself.

## What to do when you suspect the published algorithm is wrong

If during implementation you notice that the published algorithm seems to have a bug, or that a "better" variant from a different source seems to dominate:

1. **Don't quietly substitute.** Implement what was asked.
2. Flag the concern to the user with specific reasoning: "The published algorithm in section 3.2 appears to have an off-by-one error at step 4; the variant in [Smith 2023] handles this differently. Want me to implement Smith's variant instead?"
3. Wait for explicit decision before deviating.

## What to do when integrating with an existing implementation

If a library implements the algorithm (`scipy`, `sklearn`, `requests`, `httpx`, etc.):

1. Use the library. Don't reimplement.
2. Verify the library's algorithm matches the one you were asked to implement (sometimes similar-sounding algorithms get conflated in API names — e.g. cosine similarity vs dot-product similarity).
3. Stay within the library's guarantees — don't pre-process the input in a way that violates the algorithm's preconditions.

## Verification scripts as ground truth

When a repo bundles a `verify_*.py` script that re-implements the math from first principles, treat that script as authoritative. When such a script exists for an algorithm:

- The verification script is the ground truth.
- If the production code disagrees with the script, **the production code is wrong** until proven otherwise.
- Don't modify the script to match the production code without thinking very carefully about what that means.

This protocol applies to all numerical / algorithmic code — not just clustering or embeddings. Any time the deliverable is "implement algorithm X from source Y", fidelity is the bar.
