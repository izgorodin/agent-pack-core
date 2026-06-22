# Rule — no silent magic numbers

A value that is meant to track reality — a count, a total, a list length, a
version — must never be a **static literal that silently rots**. The instant
reality changes and the literal doesn't, the doc or badge lies, and nothing
catches it. "It's just a number" is exactly how wrong numbers ship.

## The decision order

When you need such a value, take the first option that is possible:

1. **Derive it.** Compute it from the source of truth at build / render / run time
   (count the files, read the package version, query the API). Nobody has to keep
   it in sync because nobody writes it down.
2. **Gate it.** If it cannot be derived where it is shown — a static badge on a
   private repo that no external service can read, a number baked into prose — keep
   the literal but add a CI check that recomputes the real value and **fails red
   when they disagree**. The number stays static; lying becomes impossible.
3. **Never** ship a bare hardcoded literal with no derivation and no gate. That is
   a number that will eventually be wrong while everyone assumes it is right.

A green gate does not, by itself, prove the number is correct — but a gate that
recomputes from the source and compares makes "correct" the only state that
passes. Same discipline as a good data gate: the check owns the truth; the literal
only mirrors it.

## Worked example — the skill-count badge

`etera-agent-pack` advertises a `skills-N` shields badge, an "N invokable skills"
line in prose, and a grouped breakdown like `(15) + (2) + (6)`. shields.io cannot
count files inside a **private** repo, so the badge cannot be derived where it
renders — option 1 is out. Option 2 applies: `docs-guard.yml` recomputes
`ls skills/*/SKILL.md`, asserts every count claim in the README equals it, and
asserts the grouped sub-counts sum to the total. Add a skill and forget to bump a
number → CI goes red. (See the "Scan for stale skill counts" step in
`.github/workflows/docs-guard.yml`.)

## How to apply

- Before hardcoding any count / total / length / version in docs or code, ask:
  can I derive it (option 1)? If not, can I gate it (option 2)?
- When you add a gate, **prove it bites** — confirm it goes red on a deliberate
  mismatch before you trust the green.
- Keep the gate cheap and self-contained (a few lines that recompute and compare)
  so it never becomes a bottleneck. A check nobody can afford to run gets removed.
