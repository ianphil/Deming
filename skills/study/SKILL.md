---
name: study
description: Compare execution evidence with the plan and recommend a disposition. Use after Do or when reviewing an existing cycle.
---

# Study

## Input

The cycle directory, `plan.md`, `do.md`, and referenced evidence.

## Process

1. Recover the original theory, prediction, scope, and acceptance criteria. Record missing inputs as limitations rather than inventing them.
2. Inspect the changes against the recorded base commit, including uncommitted work, for correctness, scope, security, and contract issues. Run focused validation and record the commands and results in `study.md`.
3. Compare prediction with reality, give every acceptance criterion a result (including untested or blocked), and separate observations from inferences. State revised understanding, surprises, and limitations.
4. Recommend adoption, revision, abandonment, or deferral based on the evidence.

## Output

`.deming/cycles/<id>/study.md`, marked completed when the comparison, acceptance results, learning, and recommendation are explicit. If evidence is insufficient, state that and recommend the needed next action.

## Handoff

Give Act the cycle directory and recommendation. Study recommends; Act records and applies the authorized disposition.
