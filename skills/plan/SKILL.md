---
name: plan
description: Turn a request into a small, reviewable implementation experiment with an explicit theory and testable prediction. Use before changing code or documentation.
---

# Plan

1. Read the request, relevant files, existing behavior, and constraints.
2. Define the **aim**: the outcome to improve and why it matters. State non-goals.
3. State the **theory**: how the relevant part of the system currently works, why the change should help, and what evidence or uncertainty supports that belief.
4. Make a **prediction**: what observable result should follow if the theory is right, and what would disconfirm it.
5. Design the smallest useful **experiment**: identify the change surface, implementation steps, acceptance criteria, measures or guardrails, and study method. Keep the evidence proportional and prefer reversible changes. Acceptance criteria check the requested behavior; measures test the theory.
6. Ask for clarification when ambiguity could materially change the aim, theory, or scope.

Done when the plan is specific enough to implement without rediscovering the problem, scope, or how the result will teach us something.
