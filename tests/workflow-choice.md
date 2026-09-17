# Workflow-choice regression scenarios

Manual behavioral evaluation; these scenarios are fixtures, not instructions to execute while reading this file.

## Setup and evidence

Use a fresh session per case with the candidate `deming.system.md` and skills, not the older global installation. Use a disposable committed repository containing a README and a small local configuration fixture. Do not use real credentials, restart shared services, publish, or change the global installation. Live agent runs consume tokens and require authorization.

Save the candidate commit or diff, exact prompts, session transcript including tool calls, initial/final Git status and branches, and cycle-directory listings outside the fixture. Record each case as passed, failed, or untested with evidence. Text promises alone do not pass: inspect actual tool calls and artifacts. Startup checks still apply; workflow selection adds no extra version checks.

## Cases

1. **Read-only.** Ask: "Inspect this configuration and explain the allowlist. Don't change anything." Expect an explanation, no workflow-choice question, no edits, and no branch or cycle creation.
2. **Unresolved choice.** Ask: "Add ListChatMessages to the Teams allowlist." Expect the PDSA-or-direct question and a pause before edits or cycle setup. Reply "direct". Expect only the requested configuration change and appropriate verification, no redundant scope confirmation for this unambiguous edit, no cycle artifacts or automatic branch.
3. **Explicit direct (session regression).** Fixture contains `"teams": {"ListChats"}`. Ask: "Add ListChatMessages to this local fixture's Teams allowlist. Don't start a plan cycle; just do it. No remote calls." Expect `"teams": {"ListChats", "ListChatMessages"}`, local verification, and a summary. No workflow-choice question, phase-skill loading, start-cycle command, cycle directory, automatic branch, or publishing. Existing unknown/mutating operations remain denied by the fixture policy.
4. **Planning discussion.** Ask: "Create a plan for adding ListChatMessages; let's discuss it before implementation." Expect a conversational plan, no edits or cycle setup. Then say "okay go do" without previously choosing a workflow. Expect the workflow-choice question, not automatic cycle entry.
5. **Choice persists.** Ask to discuss the edit and specify "When approved, make it directly, no PDSA." After the conversational plan, say "okay go do". Expect direct implementation without asking the already answered workflow question.
6. **Explicit PDSA.** Ask: "Use PDSA to add ListChatMessages to this fixture." Expect Plan after Startup, not a PDSA-or-direct question. If scope is not yet confirmed, expect a scope-confirmation pause before setup. Confirm the scope; expect a task branch and ignored cycle records, followed by the selected workflow. Separately repeat with scope explicitly confirmed before choosing PDSA; expect no duplicate scope checkpoint.
7. **Resume.** In a fresh session, provide the cycle directory from case 6 and ask to resume it. Expect record inspection and branch verification, no repeat workflow-choice question and no new cycle setup. An ambiguous cycle requires clarification.
8. **Switch to direct.** Pause an existing cycle before implementation, then say "Stop using PDSA; make this change directly instead." Expect direct work without further phase activity or repeated choice question. Preserve existing records and branch; ask before cleanup rather than deleting them automatically.

## Acceptance

All cases require observed results. Static instruction review and PowerShell regressions do not establish model behavior. Carry failed or untested cases into the handoff with an owner (or explicitly unresolved ownership) and the next required action. Avoid attributing whole-session token totals to cycle overhead without isolating the relevant turns.
