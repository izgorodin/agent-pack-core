---
name: backport-review
description: Compare a downstream clone of this pack against the base and surface universal improvements that live only in the clone and should be ported back. Use periodically during active development and always before tagging a clone release, to stop the base pack and its downstream clones from silently diverging. Read-only — proposes; a human ports and commits.
---

# backport-review — surface universal improvements for porting back to the base

When a clone diverges from the base over time, two classes of change accumulate: things that
belong in the base (generic improvements any adopter wants) and things that are legitimately
clone-specific (brand names, domain skills, org-specific rules). This skill makes that
distinction explicit and actionable, before the gap grows wide enough to be painful.

**This skill is read-only.** It proposes; a human reviews, ports, and commits.

---

## Inputs

You need two paths:

- **Base path** — the root of `agent-pack-core` (or whatever public base pack is being
  maintained).
- **Clone path** — the root of the downstream clone.

If you are running inside one of them (i.e., the skill was invoked from a Claude Code session
whose working directory is under one of the paths), infer that path and ask only for the other.
If neither is clear from context, ask for both before proceeding.

---

## Step 1 — Diff the shared surface

Recursively diff the directories that should remain in sync between clone and base. The
**shared surface** is:

- `skills/` — but **exclude**:
  - Any skill directory that exists only in the clone and is clearly domain-specific (no
    counterpart in the base; name contains the clone's org/domain identifier). List these
    as candidates for CLONE-SPECIFIC classification; do not silently skip them.
  - `skills/skill-creator/` — vendored from Anthropic; never touch it.
- `protocols/` (if present in both)
- `rules/` (if present in both)
- `agents/` (if present in both)
- Root protocol documents: `REVIEW.md`, `CLAUDE.md`, `DECISIONS.md`, and any file whose name
  suggests a universal convention (not a brand/manifest file).

Run the diff with either of these commands (choose whichever works in the shell):

```bash
diff -rq --exclude="*.pyc" --exclude=".DS_Store" <base-path> <clone-path>
```

or

```bash
git diff --no-index --stat <base-path> <clone-path>
```

For each file flagged as differing, or present in only one side, collect:

- The file path (relative to the pack root)
- Which side has it (base-only / clone-only / both-differ)
- A one-line summary of what differs (read the file if the diff is short; otherwise note
  "content differs, see diff")

Do not classify yet. Step 1 is enumeration only.

---

## Step 2 — Classify each divergence

For every file collected in Step 1, assign exactly one class:

### UNIVERSAL → backport

The change is a generic improvement that any adopter of the base pack would benefit from:

- Bug fix or correction in skill logic, step ordering, or constraints
- Clearer wording, better examples, removed ambiguity
- New step or guard that is domain-agnostic
- New skill that names no org/domain and would be useful to any team
- Neutralized example (clone-specific org name removed; now generic)

These belong in the base. List the exact change to port (not "clone is different" — "step 3
added a guard for empty diff output; port that guard").

### CLONE-SPECIFIC → leave

The change is legitimately tied to this clone:

- Namespace or brand prefix in frontmatter, file names, or manifest fields
- The `NOTICE` file, `LICENSE` attribution, or any file naming the clone's org/owner
- Skills whose name, description, or body references the clone's domain, product, or team
- Rules or protocols whose scope is the clone's specific stack or workflow

Do not port these. They are what makes the clone a clone.

### BASE-AHEAD

The base has content not present in the clone — the clone is missing something from the base.
These are not backport candidates; they are forward-port candidates (clone should pull from
base). List them so the human can decide whether to sync.

### REVIEW

Assign REVIEW when the classification is genuinely ambiguous — for example, a skill that
names no org but whose logic is so specific it may only apply to the clone's domain, or a
rule change that could be universal but you cannot confirm without knowing the clone's
intent.

**When in doubt, flag REVIEW.** A false REVIEW flag costs one human decision. A missed
universal change is exactly the failure this skill exists to prevent. Never silently guess.

---

## Step 3 — Output

### Classification table

One row per differing file:

| File | Class | What and why |
| --- | --- | --- |
| `skills/foo/SKILL.md` | UNIVERSAL | Step 2 added a null-diff guard; generic, no org refs |
| `skills/bar/SKILL.md` | CLONE-SPECIFIC | Description names clone's product; leave |
| `skills/baz/SKILL.md` | BASE-AHEAD | Base has this skill; clone is missing it |
| `NOTICE` | CLONE-SPECIFIC | Clone's copyright; never port |
| `protocols/review.md` | REVIEW | Change looks generic but references a workflow pattern unique to clone — unclear |

### Backport checklist

For every UNIVERSAL item, one checklist entry:

```
[ ] skills/foo/SKILL.md
    Port: step 2 null-diff guard (lines 34-38 in clone).
    Clone path: <clone-path>/skills/foo/SKILL.md
    Base path:  <base-path>/skills/foo/SKILL.md
```

### BASE-AHEAD checklist

For every BASE-AHEAD item, one checklist entry:

```
[ ] skills/qux/SKILL.md
    Base has this; clone is missing it.
    Consider: pull from base or deliberately exclude?
```

### REVIEW items

List each with the specific ambiguity that needs a human call:

```
REVIEW: protocols/review.md
  Ambiguity: change looks domain-agnostic but references a three-wave review
  pattern that may be specific to the clone's research workflow. Confirm with
  clone maintainer before porting.
```

---

## Constraints

- **Read-only.** This skill never edits, copies, or commits any file. It surfaces findings
  for a human to act on.
- **Never port CLONE-SPECIFIC content into the base.** That content is what keeps the clone
  distinct. Porting it would corrupt the base's reusability for other adopters.
- **`skills/skill-creator/` is always ignored.** It is vendored from Anthropic and must
  remain unmodified in both base and clone. Any divergence there is a separate concern.
- **Prefer a false REVIEW flag over a silent misclassification.** The cost of a wrong
  UNIVERSAL call — accidentally porting clone-specific content into the base — is higher
  than the cost of flagging an item for human review.
- **State which commands you ran.** List the actual diff command and its output as evidence.
  A claim with no command output is unverified.
