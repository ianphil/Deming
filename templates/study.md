# Study: {{cycle}}

Status: pending
Inputs: [plan.md](plan.md), [do.md](do.md)

## Prediction versus results

Compare the original prediction with the recorded evidence. Reference evidence IDs from `do.md`; distinguish planned evidence from supplemental checks.

## Evidence classes

Use these labels consistently: `executed` (direct behavior), `inspected` (source or structure review), `simulated` (mock, stub, or override), `untested` (no evidence), and `blocked` (attempted but unavailable).

## Acceptance results

Split compound criteria into atomic behaviors and use one row per behavior and layer. A `passed` result requires direct executed evidence for every clause at the claimed layer; inspection or simulation alone cannot prove live behavior.

| Criterion | Atomic behavior and layer | Status | Evidence IDs | Evidence class | Limitation |
|---|---|---|---|---|---|
| 1a |  |  |  |  |  |

Use only `passed`, `failed`, `partial`, `untested`, or `blocked`. Do not collapse an untested clause into a passed compound criterion.

## Supplemental checks

List post hoc validation separately from the checks defined in Plan, with its evidence IDs and the question it addressed.

## Learning and limitations

Separate observations from inferences. State revised understanding and uncertainty.

## Recommendation to Act

Recommend adopt, revise, abandon, or defer for the supported scope. List every partial, failed, untested, or blocked required behavior and its concrete next check for Act; these remain required even if the cycle closes.
