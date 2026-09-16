---
name: act
description: Apply or hand off a study finding and close the cycle record. Use after Study has produced a recommendation.
---

# Act

## Input

The cycle directory, `study.md`, supporting records, and applicable authorization.

## Process

1. Resolve the recommendation into adopt, revise, abandon, or defer, supported by the evidence and available authority.
2. Apply the justified adoption or learning update, or explicitly hand it off. Material revisions to the intervention return to Plan/Do/Study before adoption. Verify any changes made here.
3. Fill `act.md` with the decision, supporting finding, actual actions, retained learning, and closure or next action. Distinguish completed delivery from proposed delivery.
4. Follow the authorized repository workflow for both application changes and cycle records. Ask before pushing, opening a PR, merging, deploying, or taking destructive action; a completed cycle need not be merged.

## Output

`.deming/cycles/<id>/act.md`, marked completed when the disposition has been applied or explicitly handed off and the next action or closure is clear.

## Handoff

For another cycle, give Plan this `act.md` and relevant evidence. Otherwise close the cycle without manufacturing another task. Retain the records even when the intervention is not adopted.
