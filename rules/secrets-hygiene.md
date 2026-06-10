# Secrets hygiene (any stack)

These rules apply to every repo, in every language. Violating them is a security incident,
not a stylistic issue. They are provider-neutral and mechanism-neutral: whatever vault,
secret manager, or `.env` workflow your project uses, the hygiene below holds.

## What is NEVER allowed

1. **Committing secret-bearing files.** `.env` files and their kin hold real credentials;
   they belong in `.gitignore` and must never be staged. Verify the working tree before
   every commit.
2. **Committing real values in example files.** Anything tracked in git — `.env.example`,
   `.env.template`, config samples — must contain obvious placeholders (`your-key-here`,
   `xxx`), never a real value with one character changed.
3. **Hardcoding secrets in source**, even temporarily. "I'll remove it before pushing"
   fails — it gets pushed, and it lives in history forever.
4. **Logging secrets.** API keys, tokens, auth headers, and request/response bodies that may
   contain credentials. Redact before you log, not after.
5. **Pasting secrets in chat** with an assistant, in commit messages, in PR descriptions,
   in issue comments, in agent instruction files, in screen recordings or screenshots.
6. **Creating or modifying credentials from inside an assistant session.** Minting a new
   key or writing to the vault crosses a security boundary; the human owner does that
   explicitly, outside the session.

## What is allowed

- Reading an example/template file to learn which keys a project expects.
- Reading the names of required secrets (the keys, never the values) to document them.
- Asking the human owner to populate a missing secret when a code path needs one.
- Documenting that a key is required — in the README or an example file — with a
  placeholder, never the real value.

## When a secret might have leaked

If you suspect a secret was committed (current branch, history, or a file surfaced in a
session):

1. **Stop.** Do not push, do not open a PR, do not keep working on top of it.
2. **Report the location, specifically:** "Possible leak — `<key-name>` may be in
   `<file>:<line>` of commit `<sha>`." Name the key, the file, the line, the commit.
3. **Rotate, don't scrub.** Do not try to rewrite history yourself to "hide" the leak — a
   leaked secret must be assumed compromised the moment it touches a remote or a log.
   The fix is to **rotate the credential**. History scrubbing is the human owner's call and
   is secondary to rotation; a scrubbed-but-not-rotated secret is still compromised.

Rotation is always cheaper than recovery. When in doubt, ask the human owner to rotate.

## Common stumbling cases

- **Printing "config" from a script.** Don't dump the environment to confirm it loaded.
  Redact sensitive values at output time, or assert presence without printing the value.
- **Generating an example for a doc.** Use `xxx`, not the real value minus a character.
- **Pasting an error log** that includes a partial token — redact the token first.
- **Committing notebooks** with cell outputs that printed config — clear outputs first.

## Why this matters

Most projects integrate with paid, organization-scoped, or identity-bearing services. A
single leaked token can cost real money, expose organizational data, or grant an attacker a
foothold. The rules above are the cheap path; the alternative is rotating a pile of
credentials after a leak and explaining the incident. Treat every secret as if it is one
careless paste away from public.
