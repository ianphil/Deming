---
name: do
description: Execute a ready plan and record the evidence. Use after Plan has handed off a cycle directory.
---

# Do

## Input

The cycle directory and its ready `plan.md`.

## Process

1. Read the plan and verify the current branch matches its task branch. If the plan is missing, blocked, or ambiguous, return to Plan.
2. Execute the planned intervention within scope. Collect the specified evidence and observe unexpected effects and operational friction.
3. Fill `do.md` with actual changes, observations, validation commands and results, and deviations. Keep observations separate from interpretations. Record routine implementation fixes; material changes to the experiment require an explicit stop and handoff rather than silent redesign.

## Output

`.deming/cycles/<id>/do.md`, marked completed, stopped, or deviated, with evidence and reasons. Reference supporting artifacts when needed; the initial cycle needs no extra evidence folder.

## Handoff

Give Study the cycle directory containing both `plan.md` and `do.md`. Preserve the original prediction and reserve conclusions for Study.
