<#
.SYNOPSIS
  Launch an autonomous Claude Code /goal run on Windows with G1-G8 preconditions
  + L8 external watchdog (foreground Start-Process + live-tail) + L11 worktree
  pre-push hook. L4 env-scrub via CLAUDE_CODE_SUBPROCESS_ENV_SCRUB is intentionally
  NOT applied — it conflicts with --dangerously-skip-permissions; defense relies
  on G8 prod-cred scrub + L11 + condition negative-assertions.

.DESCRIPTION
  Companion to skills/goal-launch/SKILL.md. Refuses to
  launch if:
    G1  main branch not protected with "Do not allow bypassing"
    G2  current branch is main/master/develop/production
    G3  working tree dirty
    G4  not inside WSL2 or Docker (--dangerously-skip-permissions on native PS is rejected)
    G5  condition lacks "in the current turn" anchor OR negative assertion
    G6  one of (max_turns | wallclock_minutes | in-condition cap) missing
    G8  prod-class env vars present in scope

  On pass: scrubs prod creds, installs pre-push hook in the current worktree,
  spawns `claude` as a foreground child via Start-Process -PassThru with
  stdout/stderr redirected to temp files, and polls a read-tail loop every
  ~400 ms so the operator sees live output. On wall-clock timeout, kills the
  tracked PID + descendants (Stop-Job doesn't cascade TerminateProcess).

.PARAMETER Condition
  The full /goal directive (single-quoted recommended). MUST contain the
  6-element shape (see the six-element template in SKILL.md).

.PARAMETER MaxTurns
  Mechanical turn cap passed to `claude --max-turns`. Default 50.

.PARAMETER WallClockMinutes
  External Wait-Job timeout in minutes. Default 60. Recommended ≤ 90 (Haiku
  evaluator 200k context limit per #61759).

.PARAMETER Slug
  Short identifier for the worktree + branch name. e.g. "epic-964-runbook".
  Branch will be `goal/<slug>`; worktree at `C:\tmp\worktrees\goal-<slug>`.

.PARAMETER RubricPath
  Path to rubric.md (Pattern C only). Skill refuses Pattern C without it.

.PARAMETER SkipBranchProtection
  Bypass G1. ONLY use on personal repos with no shared collaborators.
  Logged loudly.

.EXAMPLE
  .\launch-windows.ps1 `
    -Slug "epic-964-runbook" `
    -MaxTurns 50 `
    -WallClockMinutes 60 `
    -Condition '/goal Initialize .loop-state.json (OVERWRITE) with poolFile=docs/specs/epic-964-triage-pool.md, status=uninitialized. Then run /loop-task-runner repeatedly until completion. Completion in this turn: (a) cat .loop-state.json shows status review-pending or done; (b) gh pr list --head chore/epic-964/issue-961-stage5-docs-runbook --json state shows OPEN; (c) grep -E "^## (Rollout|Rollback)" docs/epics/library-content/LIB-001-STAGE-5-RUNBOOK.md returns matches. NEGATIVE: NEVER gh pr merge. Final post-mortem: cat .loop-state.json. Stop after 50 turns.'
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Condition,
    [Parameter(Mandatory)][string]$Slug,
    [int]$MaxTurns = 50,
    [int]$WallClockMinutes = 60,
    [string]$RubricPath = $null,
    [switch]$SkipBranchProtection
)

$ErrorActionPreference = 'Stop'
$ProgressPreference   = 'SilentlyContinue'

function Fail($msg) {
    Write-Host "REFUSED: $msg" -ForegroundColor Red
    exit 1
}
function Pass($msg) {
    Write-Host "  PASS: $msg" -ForegroundColor Green
}
function Warn($msg) {
    Write-Host "  WARN: $msg" -ForegroundColor Yellow
}

# Resolve claude.cmd explicitly — npm CLI on Windows ships .cmd / .ps1, NOT .exe.
# Without this, `Start-Process -FilePath 'claude'` does not auto-resolve via
# $env:PATHEXT and silently fails to start the process.
try {
    $claudeCmd = (Get-Command claude.cmd -ErrorAction Stop).Source
} catch {
    Fail "claude.cmd not found in PATH. Install via 'npm i -g @anthropic-ai/claude-code'."
}

Write-Host "goal-launch precondition gates" -ForegroundColor Cyan

# G4 — sandbox precondition (run FIRST; everything else is moot if not sandboxed)
# Use IsNullOrEmpty (not -ne $null) — empty-string env vars exist but aren't a sandbox.
$inWsl    = -not [string]::IsNullOrEmpty($env:WSL_DISTRO_NAME) -or -not [string]::IsNullOrEmpty($env:WSL_INTEROP)
$inDocker = (Test-Path '/.dockerenv') -or -not [string]::IsNullOrEmpty($env:DOCKER_CONTAINER_ID)
if (-not ($inWsl -or $inDocker)) {
    Fail @"
G4: Native Windows shell detected — no OS-level sandbox available.
    --dangerously-skip-permissions is a known supply-chain target (s1ngularity).
    Re-launch from WSL2:    wsl --cd $PWD
    OR from Docker microVM: see Docker Sandboxes docs.
    Override is intentionally not provided — this is non-negotiable.
"@
}
Pass "G4 sandbox: running in $(if($inWsl){'WSL2'}else{'Docker'})"

# G2 — current branch not protected
$currentBranch = (git branch --show-current 2>$null).Trim()
if (-not $currentBranch) { Fail "G2: detached HEAD or not in a git repo" }
$protected = @('main','master','develop','production')
if ($currentBranch -in $protected) {
    Fail @"
G2: Current branch is `$currentBranch` (protected).
    Create a worktree from main first:
      git worktree add C:/tmp/worktrees/goal-$Slug -b goal/$Slug main
      cd C:/tmp/worktrees/goal-$Slug
"@
}
Pass "G2 branch: $currentBranch (not protected)"

# G1 — main branch protection
# 403 from the API is NOT the same as "branch unprotected": private repos on
# the free plan can't even READ protection state. Treat 403 as skip-with-warn,
# rely on L11 + condition negative-assertions for defense in that case.
if (-not $SkipBranchProtection) {
    $remote = (gh repo view --json nameWithOwner --jq '.nameWithOwner').Trim()
    $protRaw = gh api "repos/$remote/branches/main/protection" 2>&1
    if ($LASTEXITCODE -ne 0) {
        if ($protRaw -match 'Upgrade to GitHub Pro|HTTP 403|403 Forbidden') {
            Warn "G1 SKIPPED — branch protection API returned 403 (private free-plan limit on $remote)."
            Warn "    Defense falls back to L11 pre-push hook + condition negative-assertions."
            Warn "    If the repo upgrades to GH Pro/Team, G1 will start working again with no script changes."
        } else {
            Fail "G1: cannot read branch protection on main (gh not authed? repo not found?): $protRaw"
        }
    } else {
        try {
            $protJson = $protRaw | ConvertFrom-Json
            $hasRequiredReviews = $null -ne $protJson.required_pull_request_reviews
            $hasAdminEnforce    = $protJson.enforce_admins.enabled
            $forcePushAllowed   = $protJson.allow_force_pushes.enabled
            if (-not ($hasRequiredReviews -and $hasAdminEnforce -and -not $forcePushAllowed)) {
                Fail @"
G1: main branch on $remote not fully protected.
    Required: required_pull_request_reviews + enforce_admins + NO allow_force_pushes
    Fix: GitHub repo Settings > Branches > Protect main:
      - Require a pull request before merging
      - Do not allow bypassing the above settings
      - Block force pushes
    Override (personal repo): -SkipBranchProtection
"@
            }
            Pass "G1 protection: main is protected on $remote"
        } catch {
            Fail "G1: could not parse protection response: $($_.Exception.Message)"
        }
    }
} else {
    Warn "G1 branch-protection check SKIPPED (-SkipBranchProtection). Personal-repo override only."
}

# G3 — working tree clean
# Filter husky's lazy runtime cache (.husky/_/) — it's auto-generated on the
# first hook fire and would false-positive this gate on a fresh worktree.
$dirty = git status --porcelain 2>$null | Where-Object { $_ -notmatch '^\?\? \.husky/_/' }
if ($dirty) {
    Fail @"
G3: Working tree dirty:
$dirty
    Commit or stash before launching — agent diffs must not co-mingle with yours.
"@
}
Pass "G3 tree: clean"

# G5 — condition shape: must include "in the current turn" + a negative assertion
if ($Condition -notmatch '(in\s+the\s+current\s+turn|in\s+the\s+most\s+recent\s+(assistant\s+)?turn|in\s+this\s+turn)') {
    Fail @"
G5: condition lacks an EVIDENCE CLAUSE anchoring proof to the current turn.
    Add a phrase like: "X was invoked via the Bash tool in the current turn"
    so the Haiku evaluator sees a fresh tool call, not a stale assertion.
    See the six-element template in SKILL.md.
"@
}
if ($Condition -notmatch '(does\s+NOT\s+contain|zero\s+matches|empty\s+output|NEGATIVE\s*:|NEVER\s+(call\s+)?gh\s+pr\s+merge)') {
    Fail @"
G5: condition lacks a NEGATIVE ASSERTION (transcript-must-not-contain).
    Add a phrase like: "transcript does NOT contain `gh pr merge`, `git push origin main`, `terraform destroy`, `rm -rf`"
    This is defense-in-depth — pair with L11 (pre-push hook) and L12 (shell denylist).
    See the six-element template in SKILL.md (Element 4).
"@
}
Pass "G5 condition shape: evidence-anchor + negative-assertion present"

# G6 — in-condition cap
if ($Condition -notmatch '(stop\s+after\s+\d+\s+(turns?|minutes?))') {
    Fail "G6: condition lacks 'stop after N turns/minutes'. Soft cap is required alongside mechanical --max-turns."
}
Pass "G6 caps: --max-turns $MaxTurns + in-condition cap + external $WallClockMinutes-min timeout"

# G7 — rubric (Pattern C only)
if ($RubricPath) {
    if (-not (Test-Path $RubricPath)) {
        Fail "G7: -RubricPath '$RubricPath' does not exist (required for Pattern C wave-disciplined runs)."
    }
    Pass "G7 rubric: $RubricPath ($(Get-Item $RubricPath | Select-Object -ExpandProperty Length) bytes)"
}

# G8 — credential scrubbing
$prodCredVars = @(
    'AWS_ACCESS_KEY_ID', 'AWS_SECRET_ACCESS_KEY', 'AWS_SESSION_TOKEN',
    'DATABASE_URL_PROD', 'NEON_DATABASE_URL_PROD',
    'STRIPE_SECRET_KEY', 'STRIPE_LIVE_SECRET_KEY',
    'OPENAI_API_KEY_PROD', 'ANTHROPIC_API_KEY_PROD',
    'GITHUB_TOKEN_PROD', 'CLOUDFLARE_API_TOKEN_PROD'
)
$present = $prodCredVars | Where-Object { Test-Path "env:$_" }
if ($present) {
    foreach ($v in $present) { Remove-Item "env:$v" -ErrorAction SilentlyContinue }
    Warn "G8 scrub: removed $($present.Count) prod-class env vars from scope: $($present -join ', ')"
} else {
    Pass "G8 scrub: no prod-class env vars in scope"
}
# NOTE: CLAUDE_CODE_SUBPROCESS_ENV_SCRUB=1 is intentionally NOT set here.
# It triggers `allowed_non_write_users` hardening that SILENTLY overrides
# `--dangerously-skip-permissions` (which we DO pass below for the autonomous
# run). Setting both forces the subprocess back to per-tool permission
# prompts, which then hang on no human watcher and the run hits wall-clock
# timeout with zero progress. We rely on layered defense L1-L12 (G8 scrub of
# prod creds above + L11 pre-push hook + condition negative-assertions)
# instead. If you need the env-scrub hardening, also pass `--allowedTools <set>`
# to claude below — the two together avoid the conflict.

# L11 — install pre-push hook in the worktree blocking pushes to protected branches
$hookPath = '.git/hooks/pre-push'
if (Test-Path '.git') {
    @'
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
'@ | Set-Content -Path $hookPath -Encoding UTF8
    # Make executable (no-op on NTFS but required when worktree mounted from Linux container)
    try { & chmod +x $hookPath 2>$null } catch { }
    Pass "L11 pre-push hook installed at $hookPath"
} else {
    Warn "L11 SKIPPED: not in a git repo root (no .git/ dir)"
}

# All gates passed — assemble launch
$launchSha = (git rev-parse HEAD).Trim()
$startedAt = Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ'

Write-Host "`nLaunching /goal" -ForegroundColor Cyan
Write-Host "  branch:        $currentBranch"
Write-Host "  launch SHA:    $launchSha"
Write-Host "  started at:    $startedAt"
Write-Host "  max-turns:     $MaxTurns"
Write-Host "  wall-clock:    $WallClockMinutes min"
Write-Host "  watchdog:      foreground Start-Process + live-tail loop (PID-tracked kill on timeout)"
Write-Host ""

# L8 — external watchdog with foreground Start-Process + live-tail loop.
# Earlier this section used Start-Job + Wait-Job, but Start-Job buffers ALL
# stdout/stderr until the job completes — for 30-60-min autonomous runs the
# operator sees a black hole and can't tell if claude is making progress,
# stuck, or already failed. We now launch claude foreground via
# `Start-Process -PassThru` with stdout/stderr redirected to temp files, and
# read new bytes from those files every 400ms so the operator sees live
# output. PID tracking + child-tree kill on timeout preserved from prior
# implementation (Stop-Job alone doesn't cascade TerminateProcess to the
# runspace's spawned processes, so we kill by tracked PID).
$pidFile = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "goal-launch-pid-$([guid]::NewGuid().ToString('N')).txt")
$outFile = "$pidFile.out"
$errFile = "$pidFile.err"

function Read-NewBytes($path, [ref]$lastPos) {
    if (-not (Test-Path $path)) { return $null }
    $info = Get-Item $path
    if ($info.Length -le $lastPos.Value) { return $null }
    try {
        # Open with 'ReadWrite' share so the running child process can keep
        # writing to the file while we read from it.
        $fs = [System.IO.File]::Open($path, 'Open', 'Read', 'ReadWrite')
        $fs.Seek($lastPos.Value, 'Begin') | Out-Null
        $reader = New-Object System.IO.StreamReader($fs, [System.Text.Encoding]::UTF8)
        $chunk = $reader.ReadToEnd()
        $reader.Close(); $fs.Close()
        $lastPos.Value = $info.Length
        return $chunk
    } catch { return $null }
}

# Spawn claude via the resolved $claudeCmd (.cmd wrapper — see top of script).
# --dangerously-skip-permissions is intentional here because G4 enforced
# sandbox above.
$proc = Start-Process -FilePath $claudeCmd -ArgumentList @(
    '--dangerously-skip-permissions',
    '--max-turns', $MaxTurns,
    '-p', $Condition
) -PassThru -NoNewWindow -RedirectStandardOutput $outFile -RedirectStandardError $errFile

$proc.Id | Set-Content -Path $pidFile -Encoding ASCII

$lastOut = 0
$lastErr = 0
$deadline = (Get-Date).AddMinutes($WallClockMinutes)
$timedOut = $false

while (-not $proc.HasExited) {
    if ((Get-Date) -gt $deadline) {
        $timedOut = $true
        Write-Host "`nHARD TIMEOUT after $WallClockMinutes min — killing claude PID + descendants" -ForegroundColor Red
        try {
            # Kill descendants first so they can't outlive the parent kill.
            Get-CimInstance Win32_Process -Filter "ParentProcessId=$($proc.Id)" -ErrorAction SilentlyContinue |
                ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
            Stop-Process -Id $proc.Id -Force -ErrorAction Stop
            Write-Host "  killed claude PID $($proc.Id)" -ForegroundColor Yellow
        } catch {
            Write-Host "  could not Stop-Process PID $($proc.Id) (already exited or no permission): $_" -ForegroundColor Yellow
        }
        break
    }
    $chunk = Read-NewBytes $outFile ([ref]$lastOut)
    if ($chunk) { Write-Host $chunk -NoNewline }
    $chunkErr = Read-NewBytes $errFile ([ref]$lastErr)
    if ($chunkErr) { Write-Host $chunkErr -NoNewline -ForegroundColor Yellow }
    Start-Sleep -Milliseconds 400
}

# Drain any final output written between the last poll and process exit.
$chunk = Read-NewBytes $outFile ([ref]$lastOut)
if ($chunk) { Write-Host $chunk -NoNewline }
$chunkErr = Read-NewBytes $errFile ([ref]$lastErr)
if ($chunkErr) { Write-Host $chunkErr -NoNewline -ForegroundColor Yellow }

if ($timedOut) {
    $exitClass = 'TIMEOUT'
} else {
    $exitClass = "COMPLETED (exit=$($proc.ExitCode))"
}

Remove-Item $pidFile, $outFile, $errFile -ErrorAction SilentlyContinue

# Post-run audit (see the Post-run audit section in SKILL.md)
Write-Host "`nPost-run audit" -ForegroundColor Cyan
Write-Host "  exit class:    $exitClass"
Write-Host "  diff vs launch SHA:"
git diff --stat $launchSha 2>&1 | ForEach-Object { "    $_" }
Write-Host "  commits since launch:"
git log --oneline "$launchSha..HEAD" 2>&1 | ForEach-Object { "    $_" }
Write-Host "  branch state:"
"    $(git branch --show-current)  ($(git status --porcelain | Measure-Object).Count uncommitted)"

Write-Host "`nNext step: audit-the-achieved. Re-run the condition's verification commands outside this session. If they disagree with the goal's 'achieved' claim — the achievement was false." -ForegroundColor Yellow
