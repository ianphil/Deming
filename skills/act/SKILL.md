---
name: act
description: Apply or hand off a study finding and close the cycle record. Use after Study has produced a recommendation.
---

# Act

## Input

The cycle directory, `study.md`, supporting records, and applicable authorization.

## Process

1. Resolve the recommendation into adopt, revise, abandon, or defer, supported by the evidence and available authority. Reconcile every atomic behavior from Study against Plan before deciding: `partial`, `failed`, `untested`, or `blocked` required behavior remains unresolved. Separate cycle closure, retention of a prototype, and acceptance of its behavior. Carry each unresolved item into an explicit required handoff with the next check and owner (or state ownership unresolved). Check Study's evidence class and IDs against every clause of Plan's required criteria, including branches covered only by inspection, mocks, or simulation. Adopt only the scope supported by direct evidence; never relabel required verification as optional.
2. Apply the justified adoption or learning update, or explicitly hand it off. Material revisions to the intervention return to Plan/Do/Study before adoption. Verify any changes made here.
3. Fill `act.md` with the adopted scope, evidence-supported acceptance, actual actions, retained learning, and closure or next action. Distinguish completed delivery from proposed delivery. State that no required follow-up remains only when every required atomic behavior is directly supported at the claimed layer.
4. Follow the authorized repository workflow for application changes. Cycle records are local-only: keep them ignored and never force-add them. Put the necessary decision/evidence summary in an authorized PR or handoff rather than publishing the scratch records. Ask before pushing, opening a PR, merging, deploying, or taking destructive action; a completed cycle need not be merged.

## Output

`.deming/cycles/<id>/act.md`, marked completed when the disposition has been applied or explicitly handed off and the next action or closure is clear.

## Handoff

For another cycle, give Plan this `act.md` and relevant evidence. Otherwise close the cycle without manufacturing another task. Retain the records even when the intervention is not adopted.
