---
name: spec
description: Draft or refine a project specification when the user explicitly asks for a spec session or an editable spec before implementation, including reviewing a user-updated draft; route implementation requests to the existing direct or PDSA workflow instead.
---

# Spec

Run a collaborative specification session. The output is a focused, durable Markdown draft; it is not an implementation plan and it does not authorize implementation.

## Entry and boundary

Use this skill for an explicit request to begin a spec session, draft a spec, turn an idea into an editable spec, or review a user-updated spec. A request to discuss an idea without drafting stays conversational. A request to implement an agreed spec belongs to the existing workflow gate and Plan/Direct path; hand it off without starting implementation from this skill.

A review-only request authorizes reading and feedback, not edits. During an active drafting/refinement session, chat answers or a user-edited file may guide targeted revisions; respect any read-only restriction.

An explicit spec-session request authorizes scoped draft creation and editor handoff. It does not authorize a task branch, a PDSA cycle, implementation edits, commits, publication, or editor installation.

## 1. Inspect context and separate facts from decisions

Read the project's README, relevant files, constraints, existing specs, and supplied prior artifacts before asking about them. Research facts available from the repository and available tools yourself. Bring only genuine product or policy decisions to the user.

State the working aim, affected users or system, observable outcome, constraints, and current uncertainties. Keep four labels distinct throughout the session:

- **Agreed** — the user has confirmed it.
- **Proposed** — a recommendation or working design that still needs the user's decision.
- **Assumed** — a temporary interpretation grounded in context; surface it for confirmation.
- **Open** — a material decision or fact that still blocks agreement.

## 2. Interview the decision tree in rounds

Model the discussion as a dependency tree. Each node is a decision, not an implementation task. Record which decisions are prerequisites for others.

At each round:

1. Compute the **frontier**: every unanswered decision whose prerequisites are settled.
2. Ask the independent frontier questions together in one numbered round. Give each question a clear title, the relevant choices, and a recommended answer labelled as a proposal.
3. Wait for the user's answers. Do not fill them in from silence.
4. Record the answers and recompute the frontier before asking the next round. Questions depending on an unanswered decision wait for a later round. Use parallel research only when the available tools support it; pending research is an unsettled prerequisite, not an assumed answer.

Use this format:

```text
❓ **Q1** — **<decision title>**: <question and choices>

➡️ Proposed answer: <recommendation and reason>

---
```

Ask rigorously about material ambiguity, boundaries, failure behavior, affected users, constraints, and observable success. Do not exhaust the user on hypothetical features or implementation details outside the agreed scope. Discoverable facts are research work; product decisions are user decisions.

## 3. Draft early and hand off the file

Once enough substance exists to make the shape useful, create the first draft before every question is settled. Choose a descriptive lowercase kebab name and use `specs/<name>.md` in the target project.

Before writing:

1. Check whether the target file already exists.
2. If it exists, read it and preserve the user's work. Ask whether to revise that draft when intent is ambiguous; never replace it from stale memory.
3. Read [the Spec template](../../templates/spec.md), resolved from this skill directory in the Deming installation, not the target project. Replace authoring comments and bracketed scaffolding with current content or explicit open questions; choose one status rather than copying slash-separated alternatives. Remove unused deliverable categories. Include reusable variables only when genuinely needed and distinguish them from unfinished scaffolding. Preserve a meaningful user-provided `How You Are Graded` rubric, including weights, partial-credit rules, and hard failures; propose any additions explicitly rather than treating them as agreed scoring.
4. Mark the file visibly as `Draft — collaboration in progress` while material decisions remain open. Keep proposed recommendations, assumptions, open questions, and deliberate deferrals visibly distinct from agreed requirements.

Check the `code` CLI before launching VS Code. When it is available, pass the exact path as one safely quoted/argument-separated value, use a non-blocking launch, and report the actual handoff. If unavailable or the launch fails, report that result and give the exact file path. A successful CLI exit establishes an accepted handoff, not a visually verified editor window; report only what was observed. Do not install an editor or wait indefinitely for it.

## 4. Revise from current disk state

Start every refinement turn by reading the current draft from disk before feedback or edits, including chat answers, explicit confirmations, and “I've updated it—review.” A read in the previous turn is not current: the editor may have changed the file since then. If the read fails, pause rather than editing from memory. Preserve external edits and make targeted changes. Recompute the decision frontier from the current content. Surface contradictions between the file and earlier decisions; ask the user when the contradiction is material. Keep the document a collaboration surface: requirements and rationale belong in it, while implementation architecture and ordered tasks belong in the later HTML Plan.

## 5. Confirm and stop

An agreed spec has no material unanswered decision: each remaining item is resolved or explicitly deferred by the user as a non-goal or later decision with an owner or decision point. Recheck assumptions and acceptance criteria as well as the Open Questions section; moving an unresolved requirement to “implementation” is not an agreed deferral. Before changing the status to `Agreed — user confirmed`, summarize the resulting problem, behavior, constraints, non-goals, open/deferred items, and acceptance criteria and ask whether it reflects the user's intent. Reuse a clear confirmation already given; do not add a redundant checkpoint.

After confirmation, stop the Spec session and report the path. A confirmed spec may be used as input to a later implementation request. It does not itself start direct work or PDSA. If the confirmed spec records a selected workflow, preserve that fact for the later workflow gate; an illustrative or merely proposed PDSA section is not authorization.

## Quality bar

The final draft explains what problem matters, what behavior is expected, what is out of scope, what context informed it, what will be delivered, and how completion will be observed. It does not silently convert recommendations into requirements, hide uncertainty behind polished prose, or retain empty template categories. The draft and the interview are separate artifacts: keep the interview concise and let the Markdown file carry the durable agreement. Specs are shareable project files eligible for version control; committing them is a separate action.

Source attribution and license: [notice](NOTICE.md). No external skill is needed at runtime.
