---
name: do
description: Execute a ready cycle's HTML plan phase by phase, update its checklist, and record evidence. Use after Plan hands off a cycle directory or when resuming execution.
---

# Do

## Input

The cycle directory and its ready `plan.html`. Use the [legacy-plan rule](../../deming.system.md#cycle-plan-format) for older Markdown cycles; do not silently convert or replace their predictions.

## Process

### 1. Locate and absorb the plan

Read the entire plan: purpose/problem/solution, original prediction, scope, acceptance criteria, ordered phases, testing strategies, global validation, metadata, amendments, and every back reference at depth one. Inspect embedded figures and their HTML sources, not just filenames or captions. Read any existing `do.md` on resume. Resolve relative paths from the document that contains them. If the cycle/plan is ambiguous, ask rather than guessing.

Verify the current branch matches the plan's task branch and that scope confirmation and readiness are recorded. A pending scaffold or materially blocked plan returns to Plan. Check required tools and authorizations before using them; ask before installing missing tooling. Readiness authorizes only the scoped intervention, not publishing or unrelated cleanup.

### 2. Execute phases in order

For legacy Markdown cycles, follow their recorded steps and validation, tracking progress/evidence in `do.md`; update existing Markdown checklists only when present. The HTML marker/metadata/asset requirements below apply to HTML cycles and do not authorize conversion.

For each implementation phase, top to bottom:

1. Announce the phase. Set its marker and the current task marker to `[wip]` in `plan.html` before starting work.
2. Implement the task's specified actions within scope. Map the work to its stable task and acceptance IDs. Newly discovered adjacent work belongs in a handoff unless Plan approves a revision.
3. Run that phase's Testing Strategy, including edge cases and expected outcomes. When TDD is specified, record the expected red result before implementation and the subsequent green result separately.
4. Correct routine implementation defects and rerun within the plan's run bounds. Preserve every meaningful failed attempt and remedy. A user/spec stopping condition overrides the normal retry loop. Stop on safety concerns or a material change to the experiment and return to Plan; do not silently redesign it.
5. Mark a task/test `[x]` only when its stated completion condition has evidence. Mark an unavailable or unresolved check `[f]` with a reason and evidence ID; it remains required, not waived. Leave unstarted dependent tasks `[]`. Continue only independent tasks when safe and explain why; never advance dependent work past a failed prerequisite.
6. Resolve the phase before the next phase: `[x]` only if all required tasks and tests pass; otherwise `[f]` with explicit blockers and next actions. Do not leave a phase `[wip]` when handing off.

Do updates execution markers and evidence links; the original theory, prediction, confirmed scope, and required acceptance checks remain intact. For a scoped revision use Plan's Update procedure and append an amendment. On resume, reconcile existing markers with evidence; do not reset all markers or trust `[x]` without its supporting result.

### 3. Record attempts as they happen

Keep `do.md` as the evidence record, not a second implementation plan. Give every meaningful planned or supplemental attempt a unique evidence ID with:

- Phase/task/acceptance IDs and purpose.
- Exact command or artifact and reproducible output/artifact location.
- Observed result and exit status, with the layer it establishes.
- Intervention, deviation, or limitation, including failed attempts before a later success.

Label supplemental checks explicitly. Separate observations from explanations; reserve conclusions for Study. Keep actual result detail here and link its ID from the HTML checklist to avoid divergent duplicate narratives.

### 4. Validate the whole plan

Run the plan's global Validation Commands and update each check marker with its evidence ID. Passing a phase test does not substitute for a required integration, browser, or runtime check. If a required check cannot run or pass, retain `[f]`, record why, and pass the obligation to Study.

Append the current ISO timestamp to `modified`, agent/session identity to their metadata lists, and actual relevant commits to `commits`; preserve created time and existing entries. Do not invent a commit or overwrite base provenance. Set `Status: executed` only when execution has been attempted through its allowed boundary; this status is not behavioral acceptance.

For HTML cycles, run the bundled `../../scripts/plan-artifacts.ps1 -Mode Plan -Path <cycle>/plan.html` using PowerShell, resolved from this skill directory. Use `-Completed` only when claiming all checklist items passed; it requires every marker to be `[x]`. If plan/diagram content changed, rerun the relevant source/export and browser checks from Plan. Legacy cycles use their recorded Markdown checks and evidence instead.

## Output and handoff

Give Study the cycle directory containing `plan.html` (or the explicitly retained legacy plan) and `do.md`. Mark Do completed, stopped, or deviated and explain why. Summarize work per phase, task/test status, evidence IDs, failed or untested requirements, and concrete next actions. Confirm the ledger covers every meaningful attempt, the checklist agrees with it, and no required failure was turned into an optional enhancement.
