#!/usr/bin/env bash
#
# launch-posix.sh — Linux-primary equivalent of launch-windows.ps1.
#
# Launch an autonomous Claude Code /goal run on POSIX with G1-G8 preconditions
# + L8 external watchdog (GNU `timeout --kill-after` + `setsid` process group)
# + L11 worktree pre-push hook. L4 env-scrub via CLAUDE_CODE_SUBPROCESS_ENV_SCRUB
# is intentionally NOT applied — it conflicts with --dangerously-skip-permissions;
# defense relies on G8 prod-cred scrub + L11 + condition negative-assertions.
#
# Companion to skills/goal-launch/SKILL.md. Refuses to launch if:
#   G1  main branch not protected with "Do not allow bypassing"
#   G2  current branch is main/master/develop/production
#   G3  working tree dirty
#   G4  Anthropic sandbox not enabled in ~/.claude/settings.json
#   G5  condition lacks "in the current turn" anchor OR negative assertion
#   G6  one of (max_turns | wallclock_minutes | in-condition cap) missing
#   G8  prod-class env vars present in scope
#
# On pass: scrubs prod creds, installs pre-push hook in the current worktree,
# then runs `claude` under `timeout --kill-after=30s setsid` so the whole
# process group is killed on wall-clock expiry. Output streams live to the
# terminal (and is tee'd to a temp file for the post-run audit).
#
# macOS: GNU `timeout`/`setsid` are NOT present by default — BSD `timeout`
# lacks --kill-after and `setsid` is absent. Install GNU coreutils + util-linux
# (`brew install coreutils util-linux`) and either alias gtimeout/gsetsid or set
# TIMEOUT_BIN / SETSID_BIN below. v0.1 is Linux-tested only.
#
# Usage:
#   ./launch-posix.sh \
#     --slug epic-964-runbook \
#     --max-turns 50 \
#     --wallclock-minutes 60 \
#     --condition '/goal Initialize .loop-state.json (OVERWRITE) with poolFile=... NEGATIVE: NEVER gh pr merge. Stop after 50 turns.'
#
# Options:
#   --condition <str>          (required) the full /goal directive
#   --slug <str>               (required) short id for worktree + branch name
#   --max-turns <N>            mechanical turn cap (default 50)
#   --wallclock-minutes <N>    external timeout in minutes (default 60; recommend <= 90)
#   --rubric-path <path>       rubric.md (Pattern C only; refused if missing)
#   --skip-branch-protection   bypass G1 (personal repos only; logged loudly)

set -euo pipefail

# ---- arg parsing -----------------------------------------------------------
CONDITION=""
SLUG=""
MAX_TURNS=50
WALLCLOCK_MINUTES=60
RUBRIC_PATH=""
SKIP_BRANCH_PROTECTION=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --condition)               CONDITION="$2"; shift 2 ;;
        --slug)                    SLUG="$2"; shift 2 ;;
        --max-turns)               MAX_TURNS="$2"; shift 2 ;;
        --wallclock-minutes)       WALLCLOCK_MINUTES="$2"; shift 2 ;;
        --rubric-path)             RUBRIC_PATH="$2"; shift 2 ;;
        --skip-branch-protection)  SKIP_BRANCH_PROTECTION=1; shift ;;
        *) echo "Unknown option: $1" >&2; exit 2 ;;
    esac
done

# ---- output helpers (ANSI colours, no-op if not a tty) ---------------------
if [[ -t 1 ]]; then
    C_RED=$'\033[31m'; C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'; C_CYAN=$'\033[36m'; C_RESET=$'\033[0m'
else
    C_RED=""; C_GREEN=""; C_YELLOW=""; C_CYAN=""; C_RESET=""
fi
fail() { echo "${C_RED}REFUSED: $*${C_RESET}" >&2; exit 1; }
pass() { echo "${C_GREEN}  PASS: $*${C_RESET}"; }
warn() { echo "${C_YELLOW}  WARN: $*${C_RESET}"; }

[[ -n "$CONDITION" ]] || fail "missing required --condition"
[[ -n "$SLUG" ]]      || fail "missing required --slug"

# Resolve claude binary explicitly.
CLAUDE_BIN="$(command -v claude || true)"
[[ -n "$CLAUDE_BIN" ]] || fail "claude not found in PATH. Install via 'npm i -g @anthropic-ai/claude-code'."

# Resolve GNU timeout / setsid (gtimeout/gsetsid on macOS+coreutils).
TIMEOUT_BIN="${TIMEOUT_BIN:-$(command -v timeout || command -v gtimeout || true)}"
SETSID_BIN="${SETSID_BIN:-$(command -v setsid || command -v gsetsid || true)}"

echo "${C_CYAN}goal-launch precondition gates${C_RESET}"

# G4 — sandbox precondition (run FIRST; everything else is moot if not sandboxed).
# On Linux/macOS the Anthropic native sandbox is the boundary; verify it's enabled
# in ~/.claude/settings.json. Falls back to a string grep if jq is unavailable.
SETTINGS="$HOME/.claude/settings.json"
sandbox_enabled=0
if [[ -f "$SETTINGS" ]]; then
    if command -v jq >/dev/null 2>&1; then
        [[ "$(jq -r '.sandbox.enabled // false' "$SETTINGS" 2>/dev/null)" == "true" ]] && sandbox_enabled=1
    else
        grep -Eq '"sandbox"[[:space:]]*:[[:space:]]*\{[^}]*"enabled"[[:space:]]*:[[:space:]]*true' "$SETTINGS" && sandbox_enabled=1
    fi
fi
if [[ "$sandbox_enabled" -ne 1 ]]; then
    fail "$(cat <<EOF
G4: Anthropic OS-level sandbox is not enabled.
    --dangerously-skip-permissions is a known supply-chain target (s1ngularity).
    Enable a sandbox stanza in ~/.claude/settings.json:  { "sandbox": { "enabled": true } }
    Override is intentionally not provided — this is non-negotiable.
EOF
)"
fi
pass "G4 sandbox: Anthropic sandbox enabled in $SETTINGS"

# G2 — current branch not protected
CURRENT_BRANCH="$(git branch --show-current 2>/dev/null || true)"
[[ -n "$CURRENT_BRANCH" ]] || fail "G2: detached HEAD or not in a git repo"
case "$CURRENT_BRANCH" in
    main|master|develop|production)
        fail "$(cat <<EOF
G2: Current branch is '$CURRENT_BRANCH' (protected).
    Create a worktree from main first:
      git worktree add /tmp/worktrees/goal-$SLUG -b goal/$SLUG main
      cd /tmp/worktrees/goal-$SLUG
EOF
)" ;;
esac
pass "G2 branch: $CURRENT_BRANCH (not protected)"

# G1 — main branch protection
# 403 from the API is NOT the same as "branch unprotected": private repos on
# the free plan can't even READ protection state. Treat 403 as skip-with-warn,
# rely on L11 + condition negative-assertions for defense in that case.
if [[ "$SKIP_BRANCH_PROTECTION" -ne 1 ]]; then
    REMOTE="$(gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>/dev/null | tr -d '[:space:]' || true)"
    if [[ -z "$REMOTE" ]]; then
        fail "G1: cannot resolve remote (gh not authed? not a GitHub repo?). Use --skip-branch-protection for a personal repo."
    fi
    PROT_RAW="$(gh api "repos/$REMOTE/branches/main/protection" 2>&1)"
    if [[ $? -ne 0 ]]; then
        if echo "$PROT_RAW" | grep -Eq 'Upgrade to GitHub Pro|HTTP 403|403 Forbidden'; then
            warn "G1 SKIPPED — branch protection API returned 403 (private free-plan limit on $REMOTE)."
            warn "    Defense falls back to L11 pre-push hook + condition negative-assertions."
            warn "    If the repo upgrades to GH Pro/Team, G1 will start working again with no script changes."
        else
            fail "G1: cannot read branch protection on main (gh not authed? repo not found?): $PROT_RAW"
        fi
    else
        # required_pull_request_reviews present AND enforce_admins.enabled AND NOT allow_force_pushes.enabled
        OK="$(echo "$PROT_RAW" | jq -r \
            '((.required_pull_request_reviews != null) and (.enforce_admins.enabled // false) and ((.allow_force_pushes.enabled // false) | not))' 2>/dev/null || echo "false")"
        if [[ "$OK" != "true" ]]; then
            fail "$(cat <<EOF
G1: main branch on $REMOTE not fully protected.
    Required: required_pull_request_reviews + enforce_admins + NO allow_force_pushes
    Fix: GitHub repo Settings > Branches > Protect main:
      - Require a pull request before merging
      - Do not allow bypassing the above settings
      - Block force pushes
    Override (personal repo): --skip-branch-protection
EOF
)"
        fi
        pass "G1 protection: main is protected on $REMOTE"
    fi
else
    warn "G1 branch-protection check SKIPPED (--skip-branch-protection). Personal-repo override only."
fi

# G3 — working tree clean
# Filter husky's lazy runtime cache (.husky/_/) — it's auto-generated on the
# first hook fire and would false-positive this gate on a fresh worktree.
DIRTY="$(git status --porcelain 2>/dev/null | grep -Ev '^\?\? \.husky/_/' || true)"
if [[ -n "$DIRTY" ]]; then
    fail "$(printf 'G3: Working tree dirty:\n%s\n    Commit or stash before launching — agent diffs must not co-mingle with yours.' "$DIRTY")"
fi
pass "G3 tree: clean"

# G5 — condition shape: must include "in the current turn" + a negative assertion
if ! echo "$CONDITION" | grep -Eiq '(in[[:space:]]+the[[:space:]]+current[[:space:]]+turn|in[[:space:]]+the[[:space:]]+most[[:space:]]+recent[[:space:]]+(assistant[[:space:]]+)?turn|in[[:space:]]+this[[:space:]]+turn)'; then
    fail "$(cat <<'EOF'
G5: condition lacks an EVIDENCE CLAUSE anchoring proof to the current turn.
    Add a phrase like: "X was invoked via the Bash tool in the current turn"
    so the Haiku evaluator sees a fresh tool call, not a stale assertion.
    See the six-element template in SKILL.md.
EOF
)"
fi
if ! echo "$CONDITION" | grep -Eq '(does[[:space:]]+NOT[[:space:]]+contain|zero[[:space:]]+matches|empty[[:space:]]+output|NEGATIVE[[:space:]]*:|NEVER[[:space:]]+(call[[:space:]]+)?gh[[:space:]]+pr[[:space:]]+merge)'; then
    fail "$(cat <<'EOF'
G5: condition lacks a NEGATIVE ASSERTION (transcript-must-not-contain).
    Add a phrase like: "transcript does NOT contain `gh pr merge`, `git push origin main`, `terraform destroy`, `rm -rf`"
    This is defense-in-depth — pair with L11 (pre-push hook) and L12 (shell denylist).
    See the six-element template in SKILL.md (Element 4).
EOF
)"
fi
pass "G5 condition shape: evidence-anchor + negative-assertion present"

# G6 — in-condition cap
if ! echo "$CONDITION" | grep -Eiq 'stop[[:space:]]+after[[:space:]]+[0-9]+[[:space:]]+(turns?|minutes?)'; then
    fail "G6: condition lacks 'stop after N turns/minutes'. Soft cap is required alongside mechanical --max-turns."
fi
pass "G6 caps: --max-turns $MAX_TURNS + in-condition cap + external $WALLCLOCK_MINUTES-min timeout"

# G7 — rubric (Pattern C only)
if [[ -n "$RUBRIC_PATH" ]]; then
    [[ -f "$RUBRIC_PATH" ]] || fail "G7: --rubric-path '$RUBRIC_PATH' does not exist (required for Pattern C wave-disciplined runs)."
    pass "G7 rubric: $RUBRIC_PATH ($(wc -c < "$RUBRIC_PATH" | tr -d ' ') bytes)"
fi

# G8 — credential scrubbing
PROD_CRED_VARS=(
    AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
    DATABASE_URL_PROD NEON_DATABASE_URL_PROD
    STRIPE_SECRET_KEY STRIPE_LIVE_SECRET_KEY
    OPENAI_API_KEY_PROD ANTHROPIC_API_KEY_PROD
    GITHUB_TOKEN_PROD CLOUDFLARE_API_TOKEN_PROD
)
SCRUBBED=()
for v in "${PROD_CRED_VARS[@]}"; do
    if [[ -n "${!v:-}" ]]; then
        unset "$v"
        SCRUBBED+=("$v")
    fi
done
if [[ "${#SCRUBBED[@]}" -gt 0 ]]; then
    warn "G8 scrub: removed ${#SCRUBBED[@]} prod-class env vars from scope: ${SCRUBBED[*]}"
else
    pass "G8 scrub: no prod-class env vars in scope"
fi
# NOTE: CLAUDE_CODE_SUBPROCESS_ENV_SCRUB=1 is intentionally NOT set here.
# It triggers `allowed_non_write_users` hardening that SILENTLY overrides
# `--dangerously-skip-permissions` (which we DO pass below for the autonomous
# run). Setting both forces the subprocess back to per-tool permission prompts,
# which then hang on no human watcher and the run hits wall-clock timeout with
# zero progress. We rely on layered defense L1-L12 (G8 scrub of prod creds above
# + L11 pre-push hook + condition negative-assertions) instead. If you need the
# env-scrub hardening, also pass `--allowedTools <set>` to claude below — the
# two together avoid the conflict.

# L11 — install pre-push hook in the worktree blocking pushes to protected branches
GIT_DIR="$(git rev-parse --git-dir 2>/dev/null || true)"
if [[ -n "$GIT_DIR" ]]; then
    HOOK_PATH="$GIT_DIR/hooks/pre-push"
    cat > "$HOOK_PATH" <<'EOF'
#!/usr/bin/env bash
# Installed by goal-launch L11 — refuses agent push to protected branches.
protected='^(refs/heads/)?(main|master|develop|production|release/.*)$'
while read -r local_ref local_sha remote_ref remote_sha; do
    if [[ "$remote_ref" =~ $protected ]]; then
        echo "BLOCKED by goal-launch L11: push to protected branch $remote_ref" >&2
        echo "If you are the human and this is intentional, push from your own shell, not the agent's." >&2
        exit 1
    fi
done
exit 0
EOF
    chmod +x "$HOOK_PATH"
    pass "L11 pre-push hook installed at $HOOK_PATH"
else
    warn "L11 SKIPPED: not in a git repo (no git dir)"
fi

# All gates passed — assemble launch
LAUNCH_SHA="$(git rev-parse HEAD | tr -d '[:space:]')"
STARTED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

echo ""
echo "${C_CYAN}Launching /goal${C_RESET}"
echo "  branch:        $CURRENT_BRANCH"
echo "  launch SHA:    $LAUNCH_SHA"
echo "  started at:    $STARTED_AT"
echo "  max-turns:     $MAX_TURNS"
echo "  wall-clock:    $WALLCLOCK_MINUTES min"
echo "  watchdog:      timeout --kill-after=30s + setsid (kills the whole process group on expiry)"
echo ""

# L8 — external watchdog. GNU `timeout` sends SIGTERM at the deadline and SIGKILL
# 30s later (--kill-after); `setsid` runs claude in its own session/process group
# so the kill cascades to every descendant (the POSIX analogue of the Windows
# PID-tracked child-tree kill). Output is tee'd to a temp file for the audit.
[[ -n "$TIMEOUT_BIN" ]] || fail "L8: GNU 'timeout' not found (install coreutils; on macOS use gtimeout)."
[[ -n "$SETSID_BIN" ]]  || fail "L8: 'setsid' not found (install util-linux; on macOS use gsetsid)."

OUT_FILE="$(mktemp -t goal-launch.XXXXXX)"
DEADLINE_SECS=$(( WALLCLOCK_MINUTES * 60 ))
TIMED_OUT=0

set +e
"$TIMEOUT_BIN" --kill-after=30s "${DEADLINE_SECS}s" \
    "$SETSID_BIN" "$CLAUDE_BIN" \
        --dangerously-skip-permissions \
        --max-turns "$MAX_TURNS" \
        -p "$CONDITION" 2>&1 | tee "$OUT_FILE"
RC="${PIPESTATUS[0]}"
set -e

# `timeout` exits 124 on SIGTERM-deadline, 137 on SIGKILL (--kill-after).
if [[ "$RC" -eq 124 || "$RC" -eq 137 ]]; then
    TIMED_OUT=1
    echo "${C_RED}\nHARD TIMEOUT after $WALLCLOCK_MINUTES min — process group killed by timeout/setsid${C_RESET}" >&2
fi

if [[ "$TIMED_OUT" -eq 1 ]]; then
    EXIT_CLASS="TIMEOUT"
else
    EXIT_CLASS="COMPLETED (exit=$RC)"
fi

rm -f "$OUT_FILE"

# Post-run audit (see the Post-run audit section in SKILL.md)
echo ""
echo "${C_CYAN}Post-run audit${C_RESET}"
echo "  exit class:    $EXIT_CLASS"
echo "  diff vs launch SHA:"
git diff --stat "$LAUNCH_SHA" 2>&1 | sed 's/^/    /'
echo "  commits since launch:"
git log --oneline "$LAUNCH_SHA..HEAD" 2>&1 | sed 's/^/    /'
echo "  branch state:"
echo "    $(git branch --show-current)  ($(git status --porcelain | wc -l | tr -d ' ') uncommitted)"

echo ""
echo "${C_YELLOW}Next step: audit-the-achieved. Re-run the condition's verification commands outside this session. If they disagree with the goal's 'achieved' claim — the achievement was false.${C_RESET}"
