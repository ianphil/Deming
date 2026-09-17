---
name: plan
description: Plan an explicitly selected PDSA cycle and create its task branch and cycle records. Use after Startup when the user chooses PDSA, or when resuming that cycle's planning.
---

# Plan

## Input

The request, target repository, constraints, and any prior cycle's `act.md`.

## Process

### Entry gate

Apply `../../deming.system.md`'s Workflow choice gate first. Enter this procedure only for user-selected PDSA work after Startup. If reached for direct work or conversational planning, return to that path without cycle setup.

### Confirmation checkpoint

Before planning, research relevant facts read-only, then restate the user's request in your own words in the conversation: the problem, desired outcome, scope, and material assumptions. Ask only clarifying questions whose answers could change the aim, scope, constraints, or non-goals; if there are none, say so. Research facts yourself rather than asking the user to look them up.

Reuse explicit confirmation of unchanged scope already present in the conversation or cycle record, including when entering a new cycle; do not request it again. Selecting PDSA alone confirms the workflow, not an unstated scope. If scope confirmation is missing, ask the user to confirm your understanding, end the turn, and wait. Without confirmation, remain paused: Git initialization, branch creation, cycle records, and implementation come afterward, including in unattended requests. A written `plan.md` or the agent's own readiness statement is not confirmation.

If answers or corrections change the scope, restate it and obtain confirmation before proceeding.

### After confirmation

1. Read the request, relevant files, repository status, and existing behavior. Define the aim, non-goals, theory, and testable prediction. Choose the smallest useful intervention that can satisfy the aim; record adjacent improvements as out of scope unless they are required.
2. For an explicitly requested new project in an empty non-Git directory, initialize Git with `git init -b main` and an empty baseline commit before cycle setup. This is local bootstrap, not publication. Verify the directory is empty and is not inside another repository first. For an existing unborn repository or pre-existing files, ask before creating a baseline commit; preserve user work. Record bootstrap commands in the plan.
3. For a new change cycle, choose a lowercase name such as `adr-crud`, confirm the current branch is the intended base, then run `../../scripts/start-cycle.ps1 -Name <name> -Repo <target-repository>` using PowerShell. Resolve the script relative to this skill directory, not the target repository. The script assigns the next three-digit number from existing local cycle records and `deming/*` refs, then creates `deming/<number>-<name>` plus local-only `.deming/cycles/<number>-<name>/` records from the bundled templates. Do not supply or invent the numeric prefix. It adds `/.deming/` to `.gitignore` when needed; keep that ignore change with the implementation. On failure, inspect the cause; preserve existing work.
4. For a resumed cycle, read its existing records and verify the task branch instead of running setup again. If the cycle is ambiguous, ask which to resume.
5. Fill `plan.md`: confirmed problem understanding, clarification answers, agreed assumptions, the user's confirmation, scope, smallest useful intervention, acceptance criteria, evidence, relevant run bounds, non-goals, and stopping conditions. Acceptance criteria check behavior; measures test the theory. Clarify material uncertainty before handing off, especially personal/local versus shared/team data. State a bounded prototype assumption only when compatible with the request. Required acceptance checks remain required throughout the cycle; an unavailable test is a handoff obligation, not an optional enhancement.

## Output

`.deming/cycles/<id>/plan.md`, with the base branch/commit and task branch recorded by setup. Mark it ready only when explicit user confirmation is recorded and the plan can be executed without rediscovering scope or the study method; otherwise mark it blocked and explain why.

## Handoff

Give Do the cycle directory. Preserve the original theory and prediction once execution starts; record deviations in `do.md`.
