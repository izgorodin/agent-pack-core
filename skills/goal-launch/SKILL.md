---
name: goal-launch
description: Compose and launch a robust autonomous Claude Code /goal run with a 6-element transcript-provable condition, file-based verification contract, external hard timeout, sandboxed worktree, and layered-defense safety stack. Refuses to launch if any of: main branch unprotected, running on native Windows shell (not WSL2/Docker), condition lacks current-turn evidence anchor, condition lacks negative assertion, no rubric file referenced, or all three caps not declared. Use ONLY when intentionally launching an unattended /goal run — never in normal interactive work.
disable-model-invocation: true
allowed-tools: [Read, Glob, Grep, Bash(gh api *), Bash(gh repo view *), Bash(gh pr view *), Bash(git log *), Bash(git status *), Bash(git branch *), Bash(git rev-parse *), Bash(git diff *), Bash(git worktree *), Bash(cat *), Bash(ls *)]
---

# `goal-launch` — Launch a `/goal` Run That Will Not Burn Your House Down

You are preparing an autonomous Claude Code `/goal` invocation. The run will be
**unattended** with `--dangerously-skip-permissions`, meaning the agent has broad
shell + git + gh + write access for the duration. The launch pattern is the
ONLY defense the human is awake for; once it starts, only layered infrastructure
protects the system.

This skill **does not run the goal itself** — it composes the launch (condition,
caps, wrapper, sandbox, rubric file) and verifies preconditions, then hands the
paste-ready command to the operator.

**Background (read these first if you haven't):**

- Your project's `/goal` research notes on the command mechanics — how `/goal`
  drives an autonomous run and what the evaluator sees.
- Your project's `/goal` research notes on launch design — what the field
  learned about composing good launches (the six-element condition shape).
- Your project's `/goal` research notes on an autonomous-loop retrospective —
  the canonical worked example of a real run.

(If your team keeps these as cross-repo docs, prefer absolute URLs over relative
paths: relative paths only resolve when both repos are checked out as siblings
on a developer machine — not in the plugin cache.)

## When to use

- You want to run a skill (e.g. `experiment-campaign`, `spawn-worker-subagent`) unattended
  with a measurable end-state.
- The end-state can be PROVEN from the transcript via a tool call in the final
  turn (exit code, grep result, file existence, gh state).
- You can write a `rubric.md` that lists per-criterion gradeable items.
- You have a sandbox or worktree to run in. (Required on Windows.)

## When NOT to use

- The end-state is **subjective** ("looks good", "production-ready", "nicer").
  Route to `agent`-type Stop hook that can actually exercise the artifact, or
  do it manually.
- The end-state requires **external proof not visible in the transcript**
  ("staging deploy is green" without `gh run view` tool-output in the
  current turn). Add the tool-call, or don't use `/goal`.
- The run touches **production credentials, secrets, or signing keys**. No
  sandbox is strong enough to make this safe; do it interactively.
- The objective is **safety-critical** (e.g. authoring SQL migrations against a
  live DB). Sensitive-path gates exist; respect them. `/goal` is the wrong tool.

---

## The 6-element condition template (mandatory shape)

The classic 4-part shape (end-state + check + constraints + cap) is necessary-but-insufficient
based on field reports. Every condition this skill emits MUST contain all
SIX of these elements, or the skill refuses to launch:

```
1. END STATE          measurable, mechanical
2. EVIDENCE CLAUSE    "X was invoked via the Bash tool IN THE CURRENT TURN
                      and the tool result is visible in the transcript"
3. POSITIVE CHECK     command + expected output (`npm test exits 0`)
4. NEGATIVE ASSERTION transcript MUST NOT contain (forbidden side-effect markers)
5. SCOPE CONSTRAINT   declared files-in / files-out
6. TURN/TIME CAP      in-condition cap AND mechanical --max-turns
```

**Paste-ready canonical shape:**

```
/goal Every call site of `legacyAuth.verify` in src/ has been replaced with
`newAuth.verify`. PROOF: a `grep -rn 'legacyAuth.verify' src/` was invoked
via the Bash tool in the current turn and the tool result in the transcript
shows zero matches. PROOF: `npm test` was invoked via the Bash tool in the
current turn and the tool result shows exit code 0. CONSTRAINT: no file
outside src/ and tests/ has been modified per a `git status` run in the
current turn. NEGATIVE: the transcript does NOT contain `gh pr merge`,
`git push origin main`, `terraform destroy`, or `rm -rf`. Final post-mortem:
re-run `cat .loop-state.json` (if applicable) so final state remains in the
transcript. Stop after 30 turns.
```

---

## Pre-launch hard-gates (REFUSE to launch if any fail)

Run these checks in order. Surface every failure with a corrective hint; do NOT
emit the launch command unless ALL pass.

### G1. Branch protection (L6)

```sh
gh api repos/:owner/:repo/branches/main/protection \
  --jq '.required_pull_request_reviews and (.enforce_admins.enabled // false) and ((.allow_force_pushes.enabled // false) | not)'
```
Expected: `true`. If `false` / `404` → REFUSE. Fix: GitHub repo settings →
Branches → Protect `main` → "Require a pull request before merging" + "Do not
allow bypassing the above settings".

### G2. Current branch is NOT a protected long-lived branch

```sh
git branch --show-current
```
Must NOT be in `{main, master, develop, production}`. If user is on one, the
skill must propose `git worktree add C:/tmp/worktrees/goal-<slug> -b goal/<slug> main`
and refuse to launch on the protected branch.

### G3. Working tree is clean

```sh
git status --porcelain
```
Must be empty. Uncommitted work in the worktree means the agent's diffs will
co-mingle with the user's. Refuse + tell user to stash or commit.

### G4. Sandbox available (OS-specific)

- **Windows:** REFUSE if not inside WSL2 or Docker microVM. The skill checks
  `$env:WSL_DISTRO_NAME` (WSL) or `$env:DOCKER_CONTAINER_ID` (Docker). Native
  PowerShell is not sandboxable; per Anthropic's own posture, the agent should
  not have `--dangerously-skip-permissions` without OS-level sandboxing
  (post-s1ngularity supply-chain reality).
- **macOS/Linux:** Anthropic's sandboxing is available; verify
  `~/.claude/settings.json` has a sandbox stanza with `enabled: true`.

### G5. Condition shape (the 6 elements)

Parse the proposed condition. Refuse if any of:
- No `"in the current turn"` / `"in the most recent turn"` substring → missing evidence clause (Element 2)
- No `"does NOT contain"` / `"zero matches"` / `"empty output"` / `"NEGATIVE"` clause → missing negative assertion (Element 4)
- Compound objective: condition contains `\\band\\b` ≥ 3 times where each conjunct is a separate goal (split into sequential goals)
- Subjective adjectives without measurable target: `\\b(better|nicer|polish|cleanup|improve|refactor)\\b` not followed by a specific check
- No turn cap (`stop after N turns`) AND no time clause (`stop after N minutes`)

### G6. All three caps declared

The launch wrapper must specify ALL three:
- `--max-turns <N>` (mechanical, ungameable)
- In-condition turn-cap (`stop after N turns`)
- External wall-clock timeout (Windows: foreground `Start-Process` + deadline-polled read-tail loop with explicit child-PID kill on expiry; POSIX: `timeout 4h --kill-after=30s setsid`)

### G7. Rubric file referenced (Pattern C only — wave-disciplined runs)

For wave-disciplined runs (Pattern C below), a `rubric.md` file must exist and
be referenced from the condition. Refuse to launch wave-disciplined patterns
without one (else the grader is just the writer re-judging itself).

### G8. Credential scrubbing

Before launching, the wrapper MUST `unset` prod-class env vars (`*_PROD`, `STRIPE_SECRET_KEY`, `AWS_*`, etc.) so the autonomous run cannot see them.

**Note on `CLAUDE_CODE_SUBPROCESS_ENV_SCRUB`.** Setting this env var to `1` triggers the `allowed_non_write_users` hardening, which silently overrides `--dangerously-skip-permissions` — the autonomous run then hangs on per-tool approval prompts with no human watcher. `launch-windows.ps1` v0.2+ intentionally does NOT set this var; defense relies on layered L1-L12 (G8 prod-cred unset above + L11 pre-push hook + condition negative-assertions). If you need the env-scrub layer too, pass `--allowedTools <set>` to claude as well so both checks have what they need.

---

## The 5 patterns (paste-ready forms)

### Pattern A — One-pass skill (triage / discovery)

Single skill invocation; verifies artifacts exist. No looping.

```
/goal Run /<skill> <args>. Verify in the current turn: (a) `ls <artifact-paths>`
exits 0; (b) the stdout summary table contains <expected count fields>.
NEGATIVE: transcript does NOT contain `gh issue close`, `gh issue comment`,
`gh pr merge`, or `git push origin main`. Stop after 20 turns.
```

**Illustrative example (substitute your own triage skill + paths):**

```
/goal Run /<your-triage-skill> <args>. Verify in the current turn: `ls docs/specs/<your-epic>-triage-digest.md docs/specs/<your-epic>-triage-pool.md` exits 0 AND the stdout summary table shows bucket counts. NEGATIVE: transcript does NOT contain `gh issue close`, `gh issue comment`, `gh issue edit`, `gh pr merge`, or `git push origin main`. Stop after 20 turns.
```

### Pattern B — Looping worker (chained task chain)

`<your-pool-worker-skill>` against a pool. Worker opens PR; NEVER merges.
`<your-pool-worker-skill>` is your workspace's pool-worker skill — substitute its real name.

```
/goal Initialize .loop-state.json (OVERWRITE — switching pools) with poolFile=<path>, status=uninitialized. Then run /<your-pool-worker-skill> repeatedly until completion. Verification in the current turn requires ALL three: (a) `cat .loop-state.json` shows status "review-pending" or "done" AND poolFile is <path>; (b) `gh pr list --head <branch-prefix> --json state` shows OPEN; (c) <artifact verification command>. NEGATIVE: NEVER call `gh pr merge` (transcript must not contain it). Final post-mortem: re-run `cat .loop-state.json` so final state remains in the transcript. Stop after 50 turns.
```

### Pattern C — Wave-disciplined (Anthropic-Outcomes shape)

Adversarial review baked into the loop. Worker → fresh-context grader (reads
`rubric.md` + artifact) → if `needs_revision`, feedback to worker. Up to N waves.

```
/goal Run /<worker-skill> against <task>. After each wave, invoke a fresh Agent (subagent, NEW context) that reads ONLY `<rubric-path>` + the produced artifact and returns JSON `{result: "satisfied"|"needs_revision"|"failed", per_criterion: [{name, status, evidence, gap}], summary}`. If `needs_revision`, feed the structured feedback back to the worker and start the next wave. Verification in the current turn: the grader's last verdict JSON is visible in the transcript and shows `satisfied`. NEGATIVE: transcript does NOT contain `gh pr merge`, `git push origin main`, `terraform destroy`, or `rm -rf`. Final post-mortem: surface the grader's last verdict + per_criterion list. Stop after 40 turns.
```

### Pattern D — Multi-target sweep

Single goal directing the same skill across N targets. (The 12-epic triage
sweep was this shape.)

```
/goal Run /<skill> on each of [<target-1>, <target-2>, ...] sequentially. Verify in the current turn: `ls <each artifact-path>` exits 0 for ALL N targets. Surface a summary table aggregating bucket counts across targets. NEGATIVE: transcript does NOT contain any tracker-mutating gh command (`gh issue close|comment|edit|label`) or `git push origin main`. Stop after 80 turns.
```

### Pattern E — Cleanup-with-budget-contract (drift shape)

Per-task contract instead of "drift==0 at any cost" — prevents blind annotation
that masks real bugs.

```
/goal Run /<your-pool-worker-skill>. Per-task contract: (resolved + deferred-with-reason) / original_count >= 0.80; deferred entries logged to <REPORT.md> with concrete reasons. Verification in the current turn: ALL pool tasks reach status "review-pending" with their contract met (verify via `cat .loop-state.json` AND `grep "^##" <REPORT.md>` showing the expected deferred-sections). NEGATIVE: no blanket `@intentional-*` annotation without a colon-separated rationale (verified by `grep -rhE "@intentional-[a-z]+( |$)" src/ services/ packages/ | wc -l` returning 0 — lines where the annotation is followed by space-or-EOL instead of `: <reason>`). NEVER call gh pr merge. Stop after 60 turns.
```
`<your-pool-worker-skill>` is your workspace's pool-worker skill — substitute its real name.

---

## Layered defense — which mechanism catches which incident class

| Layer | Mechanism | Catches |
|---|---|---|
| L1 | OS sandbox (Anthropic native on Linux/macOS; WSL2 or Docker microVM on Windows) | `rm -rf ~/`, tilde-expansion, host-cred reads, terraform on host creds |
| L2 | Filesystem allowlist (workspace-scoped; `denyRead` on `~/.aws`, `~/.ssh`, `~/.gnupg`, `~/Pictures`) | photo wipes, cred reads, cross-project writes |
| L3 | Network egress allowlist (`api.anthropic.com`, `api.github.com`, `registry.npmjs.org` only) | data exfil, reverse SSH (ROME), supply-chain C2 |
| L4 | Unset prod creds before launch (`launch-windows.ps1` G8 block); env-scrub var intentionally OMITTED — see G8 note | token exfil, supply-chain replay |
| L5 | Git worktree per run (`C:/tmp/worktrees/goal-<slug>`) | cross-run contamination; clean `git worktree remove` |
| L6 | GitHub branch protection ("Do not allow bypassing") | agent push to main, force-push, admin-mode merge |
| L7 | `auto_merge: false` on every agent-opened PR | self-merge after self-review |
| L8 | External watchdog — POSIX `timeout 4h` + `setsid` (separate process group, kills the whole tree on timeout); Windows: foreground `Start-Process -PassThru` + deadline-polled read-tail loop, on timeout `Stop-Process` the tracked PID + descendants (Stop-Job was tried but buffered all output; the live-tail variant exposes the run progress + still PID-kills on expiry) | stuck SSE (#33949), runaway loops (#26171); the POSIX variant catches bash-tool-kills-parent (#45717), Windows variant catches it iff the explicit PID-kill fires |
| L9 | Anthropic workspace spend limit + cc-budget alerter | token burn, accidental Opus runs, infinite-loop spend |
| L10 | `/goal` condition with negative assertions (Element 4) | agent declaring done with forbidden side effects (last-defense, transcript-only) |
| L11 | Pre-push hook in worktree blocking `main\|master\|production` (**bypassable via `git push --no-verify`** — catches forgetful agents, not hostile or jailbroken ones; for hard enforcement, rely on L6 server-side branch protection) | agent pushes despite L6 being misconfigured, when not using `--no-verify` |
| L12 | Shell wrapper denylist on `gh pr merge`, `terraform destroy`, `wrangler deploy` — **operator-installed, NOT shipped** by `launch-windows.ps1`/`launch-posix.sh`. The launch scripts ship L4 + L8 + L11; L12 is a separate operator step (see "What this skill does NOT ship" below) | agent decides to execute merge/deploy class commands (when installed) |

**Critical insight from the incident catalog (the "layered defense" lesson):** every
documented incident (Replit DB-wipe, Claude `rm -rf ~/`, terraform destroy on
prod, s1ngularity, ROME crypto-mining, Cursor plan-mode-violation) had the
inner agent as the failure point. Only L1-L3 would have stopped them. **Do not
rely on L10-L12 alone.** They are last-line, not primary.

---

## Tier matrix — risk class → required defenses

| Run class | L1-L4 sandbox | L5 worktree | L6-L7 branch+PR | L8 timeout | L10 negative | L11-L12 wrappers | Extra |
|---|---|---|---|---|---|---|---|
| **Triage / read-only** (Pattern A) | optional | required | n/a | required | required | n/a | — |
| **Worker preparing PR** (Pattern B) | recommended | required | required | required | required | required | the canonical run shape |
| **Multi-target sweep** (Pattern D) | required | required | required | required | required | required | + cost ceiling + 30min cumulative-diff Slack ping |
| **Wave-disciplined** (Pattern C) | required | required | required | required | required | required | + grader-model pin |
| **Production-adjacent** (DB schema / infra / auth) | required | required | required | required | required | + extended denylist: `prisma migrate deploy`, `wrangler deploy`, `terraform apply` | two-machine pattern (disposable VM) |
| **Untrusted input in loop** (issues / PRs / web) | required | required | required | required | required | required | + `disallowedTools: [WebFetch, WebSearch]` |
| **Overnight / weekend** | required | required | required | hard 4–6h ceiling | required | required | + heartbeat to pingable channel; auto-PR only |

---

## Windows-specific operating notes (primary developer surface)

- **`--dangerously-skip-permissions` outside WSL2/Docker is REFUSED.** Native
  PowerShell has no sandbox; the Anthropic sandbox config is macOS/Linux only.
- **Use `launch-windows.ps1`** (shipped in this skill dir) — it bakes G1-G8
  preconditions + L4 prod-cred unset (env-scrub var omitted by design — see G8
  note) + L8 watchdog (foreground Start-Process + live-tail loop + explicit
  child-PID kill on timeout) + L11 pre-push hook. **NOT shipped by the launcher**
  (see "Does NOT ship" below): L1-L3 sandbox config, L5 worktree CREATION
  (script REFUSES on protected branch and tells you the `git worktree add`
  command, but does not run it for you), L12 shell-wrapper denylist.
- **Quoting:** single-quote the `-p` value (literal — backticks are literal in
  single-quoted PS strings; `#` inside single quotes is literal). Avoid double
  quotes to skip PS interpolation hell.
- **Path separators:** forward slashes work in Bash tool and in PowerShell;
  prefer forward slash in conditions for portability.
- **Condition utilities are restricted on native Windows.** When the launcher
  hands the condition to claude, claude's Bash tool ultimately invokes
  cmd.exe / PowerShell — neither has `grep`, `cat`, HEREDOC (`<<EOF ... EOF`),
  `awk`, `sed`, `find -exec`, or complex pipelines. **Safe utilities** for
  Windows-targeted conditions: `jq`, `gh`, `git` (plain commands, not
  format-string output), shell builtins (`echo`, `if`, `for`, `||`, `&&`),
  and claude's own `Read` / `Edit` / `Write` / `Bash` tools (one command per
  call, no POSIX-pipe chains). If POSIX text processing is essential, route
  through `bash -c '...'` explicitly (relying on git-bash availability) OR
  stage data via tmp files + claude file-tools. Do not assume the autonomous
  claude's environment looks like your interactive WSL shell — it does not.
- **`CLAUDE_CODE_SUBPROCESS_ENV_SCRUB=1` conflicts with
  `--dangerously-skip-permissions`.** Setting both triggers
  `allowed_non_write_users` hardening that silently forces permission mode
  back to default; the autonomous run then hangs on per-tool approval
  prompts with no human to click. `launch-windows.ps1` v0.2+ leaves the env
  var unset — defense relies on G8 scrub of prod creds + L11 + condition
  negative-assertions. If you need the env-scrub layer too, pass
  `--allowedTools <set>` to claude as well so both checks have what they
  need.
- **`.husky/_/` is a husky runtime cache, NOT user state.** Husky lazily
  generates `.husky/_/` on the first hook fire; it shows as untracked in
  `git status --porcelain`. The G3 dirty-tree gate filters it
  automatically — don't be alarmed if you see it appear during a launch.
- **GitHub branch-protection API returns 403 on free private repos.** The
  G1 gate treats 403 as skip-with-warning (NOT fail-stop), because reading
  protection state is itself a GH Pro feature. On free-plan repos, defense
  falls back to L11 pre-push hook + condition negative-assertions. If the
  repo upgrades to Pro/Team, G1 starts working again with no script changes.

## POSIX notes — **Linux primary; macOS needs extra setup**

- Anthropic's native sandbox is available on Linux; verify with
  `cat ~/.claude/settings.json | jq '.sandbox.enabled'`.
- `launch-posix.sh` uses GNU `timeout --kill-after=30s` + `setsid`. **These are
  Linux-only by default** — BSD `timeout` on macOS lacks `--kill-after`, and
  `setsid` is not in macOS at all. On macOS install GNU coreutils + util-linux
  from brew (`brew install coreutils util-linux`) and use `gtimeout` / `gsetsid`
  (or alias them). v0.2 will add auto-detection; v0.1 is Linux-tested only.

---

## Post-run audit (skill produces this report after every run)

After the `/goal` exits (achieved / max-turns / external timeout), the launcher
emits a structured audit:

1. **Diff stats since launch SHA:** `git diff --stat <launch-sha>`
2. **Commits since launch SHA:** `git log --oneline <launch-sha>..HEAD`
3. **Final evaluator reason** (parsed from transcript JSONL)
4. **Cost breakdown** by model (parse `total_cost_usd` from
   `--output-format json` payload)
5. **Re-run verification commands OUTSIDE the goal session** — the
   audit-the-achieved discipline. The launcher literally exec's the `grep` /
   `npm test` / `ls` from the condition and reports agreement/disagreement
   with the goal's `achieved` claim. **If disagreement: the goal was wrong,
   regardless of what the evaluator said.**

---

## Anti-patterns reference (refuse-to-launch list)

The skill refuses to launch any of these condition shapes. The full catalog of
anti-patterns has bad → fixed examples.

- **A1 Subjective:** "looks good" / "production-ready" / "well-designed"
- **A2 PRD-as-goal:** pasting the spec as the condition
- **A3 Compound:** "auth AND OAuth AND tests AND docs" (split sequentially)
- **A4 External-not-in-transcript:** "staging deploy is green" without `gh run view` tool-output in current turn
- **A5 Spec-gaming (Goodhart):** all measures pass + obviously-broken artifact
- **A6 Acknowledgement-loop:** vague enough that Claude plausibly progresses every turn without moving
- **A7 Stale-evidence:** `npm test exits 0` from turn 3 still counts at turn 27
- **A8 Long-context collapse:** overnight run > 200k → Haiku evaluator HTTP 400 (#61759, unfixed)
- **A9 Harness-directive misreading:** model treats "do not pause" as authorization for unrequested actions (#60705)
- **A10 Single-shot quality:** "tests for every function" → ONE assert per function
- **A11 Evaluator prompt-injection:** hostile text in WebFetch result

---

## Project-specific conventions (example)

These are illustrative conventions worth adopting; adapt them to your own
runner and tracker.

- **State init clause for pool switches** (Pattern B): if your runner halts on a
  stale `status: done`, every pool-switch goal must explicitly OVERWRITE state.
- **`cat .loop-state.json` tail trick:** end every condition with a clause
  ensuring final state is in transcript regardless of which check triggered
  `yes`. Invaluable for post-mortem.
- **Branch naming `<class>/<scope>/<slug>`:** e.g. `chore/<your-scope>/<your-task-slug>`,
  `goal/cleanup-week`. A consistent prefix lets L6 match by prefix.
- **PR template references source pool:** have every agent-opened PR's body link
  the spec/pool file it worked from so the reviewer sees the source.
- **Sensitive-path triage gate:** filter out sensitive items (schema, auth,
  migrations, CI) BEFORE the pool. Defense-in-depth — the runner has its own
  gate at SKILL §2, but triage-time filtering means the runner never even sees
  those items.

---

## What this skill does NOT do (explicit non-shipped list — read before trusting a layer)

- Does NOT run `/goal` itself — composes the launch command, refuses on
  precondition fail, hands paste-ready string to the operator.
- Does NOT auto-resume on `--max-turns` hit. Blind resume creates infinite
  loops because the cap resets. Surface failure, require human re-launch.
- Does NOT enable `--dangerously-skip-permissions` outside a sandbox boundary.
  Post-s1ngularity, this is the load-bearing safety invariant.
- Does NOT bake wave-discipline into per-skill conventions — wave-discipline
  belongs at the framework level (Anthropic-Outcomes shape). Skill authors
  write `rubric.md`; the framework runs the loop.
- Does NOT suggest `/goal` for safety-critical gates, subjective work, or
  external-proof-only conditions — routes to `agent`-type Stop hook,
  command hook, or `/loop`.
- **Does NOT create the worktree.** The script REFUSES on a protected branch
  and TELLS you the `git worktree add ...` command, but you run it (operator
  step). L5 in the layered-defense table is an operator action, not script-shipped.
- **Does NOT install L1-L3 (OS sandbox + filesystem + egress allowlist).**
  These are environment setup, configured once per dev box (Anthropic
  sandbox settings on Linux/macOS; WSL2 or Docker microVM provisioning on
  Windows). The script only VERIFIES that one of these environments is active
  (G4); it does not provision them.
- **Does NOT install L12 (shell-wrapper denylist on `gh pr merge` /
  `terraform destroy` / `wrangler deploy`).** Operator step. Add to your
  shell profile if you want belt+suspenders on top of L10's negative-assertion.
  v0.2 may ship a helper to install it.
- **Does NOT defend against `git push --no-verify`.** L11's pre-push hook is
  bypassable; only L6 (server-side branch protection) is hard enforcement.

---

## Reference: shipped templates

- [`launch-windows.ps1`](./launch-windows.ps1) — paste-ready PowerShell wrapper
  that SHIPS: G1-G8 preconditions + L4 prod-cred unset (env-scrub var
  intentionally omitted — see G8 note) + L8 watchdog (foreground Start-Process
  + live-tail loop + explicit child-PID kill on timeout) + L11 pre-push hook.
  Does NOT ship: L1-L3 sandbox (G4 only verifies it's active), L5 worktree
  creation (script tells you the command), L12 shell-wrapper denylist.
- [`launch-posix.sh`](./launch-posix.sh) — Linux-primary equivalent (GNU
  `timeout --kill-after` + `setsid`; macOS needs `brew install coreutils
  util-linux` and aliases gtimeout/gsetsid; v0.1 not macOS-auto-detected).
- Example `rubric.md` shape (Pattern C):
  ```markdown
  # <Task> Rubric

  ## Criterion 1: <name>
  - [ ] specific gradeable thing (e.g. "function `foo` is exported from `bar.ts`
        and has at least 3 callers via `grep`")

  ## Criterion 2: <name>
  - [ ] another specific gradeable thing

  ...
  ```

---

## TL;DR for the impatient operator

If you're tempted to skip the gates:

1. **Refuse on native Windows shell.** Always use WSL2 or Docker microVM.
2. **6 elements or no launch.** Bad goals end careers.
3. **Three caps.** `--max-turns` + in-condition cap + external `timeout`.
4. **`auto_merge: false` always.** You merge. Never the agent.
5. **Audit the achieved.** Re-run the verification command yourself. If the
   transcript says yes and your run says no, the transcript was wrong.
