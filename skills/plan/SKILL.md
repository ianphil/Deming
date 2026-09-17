---
name: plan
description: Plan a repository change or experiment and create its task branch and cycle records. Use after the startup version report, before changing code or documentation, or when resuming planning.
---

# Plan

## Input

The request, target repository, constraints, and any prior cycle's `act.md`.

## Process

Before planning, establish shared understanding with the user: restate the problem and ask only the smallest set of questions that could change the aim, scope, constraints, or non-goals. Research facts yourself, distinguish them from user decisions, and wait for confirmation when material uncertainty remains.

1. Read the request, relevant files, repository status, and existing behavior. Define the aim, non-goals, theory, and testable prediction.
2. For an explicitly requested new project in an empty non-Git directory, initialize Git with `git init -b main` and an empty baseline commit before cycle setup. This is local bootstrap, not publication. Verify the directory is empty and is not inside another repository first. For an existing unborn repository or pre-existing files, ask before creating a baseline commit; preserve user work. Record bootstrap commands in the plan.
3. For a new change cycle, choose a lowercase name such as `adr-crud`, confirm the current branch is the intended base, then run `../../scripts/start-cycle.ps1 -Name <name> -Repo <target-repository>` using PowerShell. Resolve the script relative to this skill directory, not the target repository. The script assigns the next three-digit number from existing local cycle records and `deming/*` refs, then creates `deming/<number>-<name>` plus local-only `.deming/cycles/<number>-<name>/` records from the bundled templates. Do not supply or invent the numeric prefix. It adds `/.deming/` to `.gitignore` when needed; keep that ignore change with the implementation. On failure, inspect the cause; preserve existing work.
4. For a resumed cycle, read its existing records and verify the task branch instead of running setup again. If the cycle is ambiguous, ask which to resume.
5. Fill `plan.md`: scope, intervention, acceptance criteria, evidence, relevant run bounds, and stopping conditions. Acceptance criteria check behavior; measures test the theory. Clarify material uncertainty before handing off, especially personal/local versus shared/team data. State a bounded prototype assumption only when compatible with the request. Required acceptance checks remain required throughout the cycle; an unavailable test is a handoff obligation, not an optional enhancement.

## Output

`.deming/cycles/<id>/plan.md`, with the base branch/commit and task branch recorded by setup. Mark it ready only when the plan can be executed without rediscovering scope or the study method; otherwise mark it blocked and explain why.

## Handoff

Give Do the cycle directory. Preserve the original theory and prediction once execution starts; record deviations in `do.md`.
