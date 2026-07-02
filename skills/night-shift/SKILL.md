---
name: night-shift
description: Run a supervised autonomous work shift while the user is away (overnight, travel, a long meeting) — self-managed like a goal run, but inside a live session with the permission system intact. Use when the user grants a block of unattended time and a mission ("работай ночью", "work on this overnight", "продолжай до утра, я спать", "finish this while I'm out — full self-management"), or grants full self-management without a time anchor ("handle this yourself, full autonomy", "реши сам, не спрашивай меня"). Sets a self-pacing wake timer, and on every wake re-reads the mission, answers its own open questions via risk and pros/cons analysis, delegates execution to model-pinned workers, checkpoints verifiable state, and works until the mission is provably complete — then leaves a morning report. Not for headless/unattended CLI runs (that is goal-launch's job).
---

# night-shift — a supervised autonomous shift

The user is away and has granted full self-management for a mission. Your job:
keep working — correctly, safely, without waking them — until the mission is
**provably** done, and leave a report they can trust at a glance.

This is NOT goal-launch: no sandbox, no `--dangerously-skip-permissions`, no
headless run. You stay inside the live session with the permission system
intact. If a permission prompt blocks an action, treat it as a **parked
question** (see Step 3) — never try to bypass it.

## Step 0 — Take the shift (2 minutes, before the user leaves if possible)

Confirm, restating in one short message:

- **Mission** — what "fully done" means, as verifiable outcomes.
- **Perimeter** — which repos/dirs you may change; where you may push.
- **Budget** — rough time box ("до утра") and any turn/token ceiling.

If the user is already gone and something is missing, derive it from the
conversation, write your derivation into the shift state file (Step 4), and
proceed — that is what full self-management means.

## Step 1 — Set the wake timer

Use the harness's self-pacing loop if available (`/loop` with no interval, or a
schedule-wakeup facility): long intervals (20–30 min) as a fallback heartbeat —
background work that completes re-invokes you anyway. No timer facility at all?
Work continuously and checkpoint more often. Timers auto-expire (loops cap out
after days); design the shift as **bounded runs + a resumable state file**, not
one immortal process.

## Step 2 — The wake cycle (every wake, in order)

1. **Re-read reality, not memory:** the user's ORIGINAL mission message (not
   just its one-line summary in the state file — summaries compress intent
   lossily across cycles), their latest messages, the todo list, the shift
   state file, and any task notifications that arrived.
2. **List open questions.** For each: *can I answer this myself?*
3. **Decide or park** — the answer-yourself protocol below. In practice ~99% of
   questions resolve without the user.
4. **Dispatch work.** Delegate execution to the pack's model-pinned agents
   (`worker` for changes, `scout` for reconnaissance — see
   `rules/model-delegation.md`). The orchestrator plans, reviews, and decides;
   it does not grind.
5. **Verify what came back.** Worker output is a proposal: check the evidence,
   re-run the gate, diff the result. A green gate is consistency, not truth.
6. **Checkpoint** (Step 4), then either continue immediately (work remains and
   the path is clear) or schedule the next wake and yield.

## Step 3 — The answer-yourself protocol

For every open question, run three quick passes — in writing, in the state file:

- **Risk analysis** — what's the worst credible outcome of each option? Is it
  reversible? Does it cross the perimeter or an outward boundary?
- **Pros / cons** — two honest columns, three lines each. Which option best
  serves the mission as the user stated it?
- **Reversibility test** — a reversible in-perimeter step with a clear best
  option: **decide and go.** Irreversible, outward-facing, or a genuine fork in
  the user's intent: **park it** — write the question, your analysis, and your
  recommendation into the state file, and move to work that isn't blocked.

Hard rails — always parked, never decided at night: outward actions (messages
to people, PRs to other teams' repos, publishing, tags/releases), destructive
or hard-to-reverse operations, spending real money, anything the user said to
ask about first, and pushes outside the agreed perimeter.

## Step 4 — Checkpoint: the shift state file

Keep `NIGHT-SHIFT.md` (or the path the user names) as the single source of
truth — chat history compacts; files survive. Update it every cycle:

```
## Shift state — <timestamp>
Mission: <one line>   Budget: <spent/left, turns or time>
Done (verified): <item — HOW it was verified: command + result, commit sha, CI state>
In flight: <item — what's dispatched, to which agent>
Decisions taken: <question → decision, one-line risk/pros-cons summary>
Parked for the user: <question → recommendation>
Next: <the single next action>
```

**Verifiable facts only.** No "great progress", no self-praise — the next wake
reads this file and *believes* it; optimism written tonight becomes false
ground truth at 4 a.m. Every "done" carries its proof or goes to "in flight".

## Step 5 — Stop conditions (all three defined, first hit wins)

- **Success:** every mission outcome verified by an independent check (tests,
  gate, CI run, diff inspection) — not by your own assertion.
- **Failure:** the same step failed 3 times, or an unrecoverable blocker —
  checkpoint, write the morning report with the blocker analysis, stop cleanly.
- **Budget:** the time/turn ceiling from Step 0 is reached — stop even if not
  done; a clean handover beats a runaway loop. (A documented field incident
  burned 4M tokens in 5 minutes of unguarded looping — budgets are not
  optional.)

## Step 6 — The morning report

Before ending the shift, write the report (file the user will open first, plus
a short chat summary). Lead with the outcome:

```
# Morning report — <date>
**TL;DR:** <mission status in one sentence — done / done-except / blocked>

## Done (each with proof)
- <what> — verified by <command/CI/commit>

## Decisions I took for you (with the risk analysis)
- <question> → <decision> — <why, one line>

## Parked — needs you (with my recommendation)
- <question> → <recommendation>

## State of the perimeter
<branches, CI status, anything running>

## Next
<the obvious next step(s), so the morning starts moving>
```

## Constraints

- Permission system stays on; a blocking prompt = a parked item, never a bypass.
- Every long-running command gets a timeout; one hung call must not kill the
  shift.
- Delegate execution to pinned cheap workers; the orchestrator's tokens are for
  planning, review, and decisions (`rules/model-delegation.md`).
- The state file contains only verifiable facts; the morning report never
  claims what it cannot prove.
