# Lock mechanics — formal reference

Companion to `SKILL.md`. Captures the rationale behind why locking looks the way it does, drawn from bench-methodology §3.5 + §8 + template "Lock mechanics" section.

## Why `lock_tag`, not `locked_at_commit`

A file cannot contain the git sha of the commit that contains it — cryptographically impossible. Any field claiming to store "the sha of this file's commit" would have to be filled before the commit exists, breaking the chicken-and-egg problem only by lying (filling in a future sha).

The lock is therefore a **git tag** placed on the commit where `status` flips to `locked`. The commit sha is recovered via `git rev-list -n1 <lock_tag>` — never stored in the spec file.

This means the spec file is **complete and verifiable at commit time** — there's no field that needs to be filled "later". The tag is created in a separate command after the commit is made.

## Two-tier honesty

Calling something "immutable" should mean it cannot be modified retroactively. Plain git tags are **movable references** — they can be deleted or repointed via `git tag -f` and `git push --force`. Most teams don't do this, but "convention not to" is not "cryptographically prevented".

We expose two tiers, named honestly:

### Tier 1: Conventional immutability (default)

`git tag <lock_tag> <commit>` — a lightweight tag. Pros:
- Removes the self-reference problem.
- Standard git-native, no infrastructure dependencies.
- Sufficient for honest, internal research with discipline.

Cons:
- Movable. Defends against accident, not against intent.
- No cryptographic claim about who made the tag or when.

Use this tier for internal pilots, draft research, anything where the team is trusted and the spec won't be cited externally.

### Tier 2: Cryptographic immutability (opt-in)

`git tag -s <lock_tag> <commit>` on a protected ref. Pros:
- Signed: tampering with the tag changes the signature.
- Protected ref: hosting service (GitHub, etc.) refuses to delete or move the tag.
- Combined, this makes retroactive modification both **detectable** (signature mismatch) and **blocked** (protection rule).

Cons:
- Requires upfront setup: GPG/SSH signing key + repo admin configuring tag protection rules.
- Push to protected tag will fail if rules misconfigured — but that's a feature, not a bug.

Use this tier for any spec to be cited in a published artifact, peer-reviewed work, or external collaboration.

## What the tag does NOT do — back-dating

A signed annotated tag on a protected ref proves:
- The tagged commit existed at the moment the tag was pushed (server timestamp).
- The tag has not been moved since.

It does **not** prove the tagged commit existed before some other event (e.g., before the results were collected). A team could:
1. Run experiments first, observe results.
2. Write a spec post-hoc tuned to declare those results as wins.
3. Backdate the spec file's `locked_at_utc` field.
4. Commit and tag the spec, claiming it was pre-registered.

The tag's server timestamp would defeat this **only if** the server timestamp can be cross-referenced with the results' timestamps — which requires an out-of-band attestation (e.g., an L2-guard that registers the lock-tag with an external timestamping service at lock time, or peer-witness via a forum post / issue / Slack archive).

Bench-methodology Q-0003 is the open question on cryptographic freeze for agent timescales. Until that's closed, **back-dating is structurally undetectable** by tooling alone. The honest position: locks rest on **discipline + audit trail** (results citing locked spec, peer-reviewer name in frontmatter), not pure cryptography.

## Why path-pin replacement at lock-time

`§3 Measurement procedure` references eval scripts: `scripts/eval/X.py @ <commit>`. In draft state, these are written as `scripts/eval/X.py @ <to-be-filled-at-lock>` — explicit placeholders.

At lock time, replace with HEAD's commit sha. Reason: the spec must reference **the exact code version that was current at lock**. If you wrote `@ <to-be-filled-at-lock>` and then forgot to replace it before locking, the spec is malformed — no recoverable claim about what code ran.

Lock checklist Step 3 enforces this. Don't let it slip.

## Why canary GUID generated at lock (not earlier)

A draft spec lives in a PR — public, indexed, scrapable. A canary GUID committed in a draft is already **compromised before lock**: scraping the repo's history surfaces the canary, and any future training corpus that includes scraped GitHub content contaminates against your benchmark.

Therefore: in `status: draft`, write the literal placeholder `<generated-at-lock>` in §7's `generated_canary` line. Generate the real GUID **at the lock commit**, embed it in both the spec file AND the held-out data, and commit in one atomic action.

This skill (`/lock-bench-spec`) generates the GUID via `python -c "import uuid; print(uuid.uuid4())"` and embeds in the spec. The **embedding into the data** is the author's responsibility pre-lock (it's part of authoring the held-out set). This skill verifies the placeholder is gone from the spec after replacement, but cannot verify it was embedded in the data — that's an audit step.

## Why peer-reviewer required before lock

Peer review is the **only** non-author check we can enforce mechanically in solo / small-team setups. The frontmatter field `peer_reviewer` documents who looked at the draft before lock.

"Outside the optimization loop" means: has not contributed code/decisions to the model or script under measurement. For solo projects, any external collaborator who has reviewed methodology §3 qualifies.

This skill does **not** verify the named reviewer actually reviewed — it only checks the field is non-blank. The honest check is at audit time (e.g., a reader of the published spec can email the named reviewer).

## Why lock_tier is a frontmatter field

The lock tier (conventional vs cryptographic) is **declared in the spec**, not derived from git config. Reasons:

1. **Audit clarity**: future readers see immediately whether to trust the lock as cryptographic or conventional.
2. **Pre-commitment**: choosing a tier is itself an act of pre-registration ("I commit to higher rigor for this spec").
3. **Loop interoperability**: `/check-stop` and audit tools can read `lock_tier` from frontmatter without invoking git.

If the declared tier is `cryptographic` but the push to protected ref fails, the spec must NOT silently downgrade to conventional. Halt with `error:no-tag-protection` and let the user explicitly decide: fix protection rules, or rewrite as `lock_tier: conventional`.

## Edge: spec on a non-default branch

If lock happens on a feature branch (not `main`), the lock commit and tag exist on that branch. Practical guidance:

- Conventional tier: tag stays on the branch until merge; after merge to `main`, the tag still references the original commit (which is now ancestor of `main`).
- Cryptographic tier: the protected-ref rule should be configured to cover both branches or only `main`. If only `main`, the lock should happen post-merge.

In practice: prefer to lock on `main` after a clean merge of the draft PR. This keeps the lock commit on a permanent reference.

## Edge: overlay tasks (corrections to locked tasks)

Bench-methodology rule: completed tasks are immutable; corrections go to an overlay task with `Overlays: tNNNN` in frontmatter (per `tasks/README.md` convention).

A locked bench-spec follows the same rule. To "fix" a locked spec, create a new spec with:

```yaml
id: bench-MMMM
supersedes: bench-NNNN
```

The new spec follows the same lock procedure. The old spec's `lock_tag` is **never** modified.

This skill refuses to re-lock an already-locked spec (`error:already-locked`). It does not generate the superseder — that's `/bench-spec-author`'s job, with the prior spec as input.

## Failure modes summary

| Error | Cause | Recovery |
|---|---|---|
| `error:incomplete-frontmatter` | Required field blank | Author fills missing fields (not this skill's job) |
| `error:already-locked` | `status != draft` OR lock fields filled | Create superseding spec instead |
| `error:inconsistent-state` | Partial lock fields (lock_tag without status: locked, etc.) | Manual cleanup; don't auto-fix |
| `error:unresolvable-pin <path>` | Path-pin placeholder references missing file | Author fixes |
| `error:no-signing-key` | `lock_tier: cryptographic` but no signingkey configured | User sets up signing |
| `error:no-tag-protection` | `lock_tier: cryptographic` but no protection rule | Admin configures protection |
| `error:public-heldout-hash-missing` | `measurement_source: public` but `heldout_hash` blank | Author fills with `release_id:hash` |
| Push fails | Network OR protection rejection | Diagnose; do not force |

Across all failures: **never bypass with `--no-verify`, `--force`, `--no-gpg-sign`**. If something is blocking the lock, the lock is not happening; investigate the root cause.
