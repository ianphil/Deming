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
3. Run the validation defined in Plan. Report exactly what each check establishes; evidence from a substitute or narrower layer does not establish the full required behavior. Record unavailable checks and their observed blockers. Ask before installing missing tooling. Label any post hoc validation as supplemental rather than silently expanding the planned evidence.
4. Compare prediction with reality. Split every compound acceptance criterion into atomic behaviors and give each a `passed`, `failed`, `partial`, `untested`, or `blocked` result with one or more evidence IDs and a limitation where applicable. Use these evidence classes: `executed` for direct behavior, `inspected` for source or structure review, `simulated` for mocks/stubs/overrides, `untested` when no evidence exists, and `blocked` when an attempted check was unavailable. A `passed` result requires direct executed evidence for every clause at the claimed layer; inspection or simulation alone cannot prove live behavior. Link reproducible checks and results, not just a PASS label. Keep observations separate from inferences, state the revised understanding of the theory and its limitations, and stage intended files or read untracked files explicitly before diff review; an empty diff does not review new files.
5. Recommend a bounded disposition. List every `partial`, `failed`, `untested`, or `blocked` required behavior and its concrete next check. A cycle may close with a handoff, but required checks cannot become optional merely because the environment made them inconvenient.

## Output

`.deming/cycles/<id>/study.md`, marked completed when the comparison, acceptance results, learning, and recommendation are explicit. If evidence is insufficient, state that and recommend the needed next action.

## Handoff

Give Act the cycle directory and recommendation. Study recommends; Act records and applies the authorized disposition.
