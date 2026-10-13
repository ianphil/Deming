# Prefect-dispatched Deming phase

## Entry

1. Read the supplied Deming directory's `SOUL.md` and `deming.system.md`. Complete Startup before loading the named phase skill. This unattended worker permits only the local version check; report an unavailable or behind installation rather than updating it.
2. Read the supplied request, repository README and cycle records. The caller has selected PDSA and confirmed the request's scope. The cycle was already created by the normal setup script; use its existing task branch and scaffolds. If instructions or scope conflict, return `needs_approval` with one concrete question.
3. Load only the dispatched phase skill. Execute that phase within the confirmed scope, preserving its required evidence and validation. End at its handoff; Prefect owns the next phase.

## Authority

Work is local to this repository and its ignored cycle. Read Deming's reference files but leave its installation and the interactive Pi configuration unchanged. Publication, package installation, remote Git operations, global changes and destructive cleanup require a separate human handoff; return `blocked` rather than performing them. Prefect approval is limited to continuing this same local scope, not permission to cross those boundaries.

On Plan, fill the existing `plan.html` and stop when it is ready for review. A structurally valid plan is not proof of browser geometry. Use installed browser tooling if available; explicitly retain unavailable required visual checks as handoff obligations.

On Do, execute the approved plan and preserve the original prediction. On Study, distinguish observations, inferences and uncertainty. On Act, record adopt/revise/abandon/defer and required follow-up; publication and starting another cycle remain human handoffs.

## Result

Finish with exactly one JSON object matching the supplied schema, without Markdown fences or surrounding text. List artifact paths relative to the cycle directory. `completed` means this phase produced its required records, not that every behavior was accepted. Use `blocked` for a failure requiring investigation; use `needs_approval` only for a question that can be answered without changing scope or granting prohibited actions. Preserve partial work and explain it in the summary. Never report a pending scaffold as completed evidence.
