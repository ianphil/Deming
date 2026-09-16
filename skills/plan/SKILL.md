---
name: plan
description: Plan a repository change or experiment and create its task branch and cycle records. Use before changing code or documentation, or when resuming planning.
---

# Plan

## Input

The request, target repository, constraints, and any prior cycle's `act.md`.

## Process

1. Read the request, relevant files, repository status, and existing behavior. Define the aim, non-goals, theory, and testable prediction.
2. For a new change cycle, choose an unused ID such as `001-adr-crud`. Confirm the current branch is the intended base, then run `../../scripts/start-cycle.ps1 -Cycle <id> -Repo <target-repository>` using PowerShell. Resolve the script relative to this skill directory, not the target repository. The script requires a clean, committed repository and creates `deming/<id>` plus `.deming/cycles/<id>/` from the bundled templates. On failure, inspect the cause; preserve existing work.
3. For a resumed cycle, read its existing records and verify the task branch instead of running setup again. If the cycle is ambiguous, ask which to resume.
4. Fill `plan.md`: scope, intervention, acceptance criteria, evidence, relevant run bounds, and stopping conditions. Acceptance criteria check behavior; measures test the theory. Clarify material uncertainty before handing off.

## Output

`.deming/cycles/<id>/plan.md`, with the base branch/commit and task branch recorded by setup. Mark it ready only when the plan can be executed without rediscovering scope or the study method; otherwise mark it blocked and explain why.

## Handoff

Give Do the cycle directory. Preserve the original theory and prediction once execution starts; record deviations in `do.md`.
