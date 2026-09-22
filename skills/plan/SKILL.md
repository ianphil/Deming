---
name: plan
description: Create, revise, or update references in an HTML implementation plan for a selected PDSA cycle. Use after Startup and workflow selection, including PDSA specified in the user's task spec, or when resuming planning.
---

# Plan

Create one browser-readable implementation plan for the engineer, team, and executing agent. This skill integrates Plan F3's HTML-first workflow and Diagram Design's visual discipline; neither source skill is a runtime dependency. The HTML plan replaces the Markdown plan for new cycles, rather than adding a second source of truth.

## Entry and confirmation

1. Apply [Workflow choice](../../deming.system.md#workflow-choice) after Startup. A user-supplied task spec explicitly selecting PDSA resolves the workflow question. Direct work and conversational planning stay on their paths without cycle setup.
2. Read the request/spec, README, relevant code/tests, repository status, project agent/application documentation (including `AI_DOCS/` and `APP_DOCS/` when present), and prior cycle's Act record if supplied. Research facts rather than asking the user to look them up. If no actionable request can be recovered, ask for it and pause.
   For an agreed Spec draft, treat the document as requirements input: preserve its confirmed scope, explicit non-goals, deferred decisions, and selected workflow while translating its definition of done into an implementation plan. A draft under discussion or a request to review a spec is not an implementation request and does not enter Plan.
3. Restate the problem, desired outcome, scope, non-goals, and material assumptions. Ask only questions that could change them; otherwise say none remain. Reuse explicit confirmation of unchanged scope already in the conversation or cycle. Workflow selection alone is not scope confirmation. If missing, ask for confirmation, end the turn, and wait before setup or implementation. An agent-authored plan is not confirmation.

## Choose the planning operation

| Input | Operation | Completion |
|---|---|---|
| Confirmed new PDSA work without a cycle plan | Create | A ready `plan.html` and validated local assets |
| Revision to an existing cycle's solution, phases, or scope | Update | Surgical changes, appended metadata/amendment, revalidated assets |
| Metadata or related-work links only | Update references | Append-only provenance and authorized reciprocal links |
| Execute an existing ready plan | Hand off to Do | Cycle directory and plan path; do not create a replacement cycle |

For a resumed cycle, read its records and verify its task branch instead of rerunning setup. Follow the system's legacy-plan rule: revise an existing Markdown plan in its recorded format unless conversion is explicitly authorized; HTML-specific checks do not force migration. Ask when the active cycle or authoritative plan is ambiguous.

## Create

### 1. Establish the cycle

After scope confirmation, verify the intended base branch and a clean committed working tree. Use `../../scripts/start-cycle.ps1 -Name <lowercase-name> -Repo <target>` with PowerShell, resolving the script from this skill directory. The script assigns the numeric prefix, task branch, and ignored cycle directory; use its reported paths. It creates pending scaffolds, not finished outputs. If setup refuses, preserve user work and resolve the cause with the user; do not silently stash, commit, or ignore unrelated files to bypass the gate.

For an explicitly requested new project in an empty directory outside any Git repository, local `git init -b main` and an empty baseline commit may precede setup. Verify those conditions first. Existing files or an unborn repository require an explicit baseline decision. Record bootstrap commands and authorization.

Artifacts:

```text
.deming/cycles/<id>/
  plan.html                 authoritative plan and execution checklist
  diagrams/                 create only for useful figures
    <subject>.html          canonical self-contained diagram source
    <subject>.svg           extracted asset embedded by plan.html
  do.md                     attempts, results, deviations
  study.md                  comparison and recommendation
  act.md                    disposition and required follow-up
```

Keep the plan and assets local-only with the other records. Do not create a duplicate plan under `specs/`; link the input spec as a back reference. Publication requires a separately authorized handoff.

### 2. Design the intervention

Analyze the request and existing architecture before choosing the solution. Define the aim, non-goals, original theory/prediction, disconfirming result, alternatives, and smallest useful change. Include edge cases, error handling, and scale constraints that affect the request; do not manufacture extra work to fill a template.

Translate the spec's definition of done into atomic acceptance criteria with stable IDs. For each, name the required behavior/layer, validation command or manual procedure, expected evidence, and limitation. Distinguish acceptance of behavior from measures testing the theory. Resolve material uncertainty (especially personal/local versus shared data) before handoff. Required checks stay required if tooling or access is unavailable.

### 3. Author the HTML plan

Fill [the plan template](../../templates/plan.html), retaining its section IDs and machine-readable status markers. Author one HTML document with one head `<style>` block, UTF-8 metadata, responsive layout, readable print styling, and local relative diagram links. Use XML-compatible HTML so the bundled structural checker can parse it without browser or Python dependencies: quoted attributes, balanced tags, `<meta />`/`<img />`, escaped ampersands and angle brackets, and numeric entities rather than HTML-only named entities. Use static content, native `<details>` for toggles, and no executable scripts or event attributes.

The plan must include:

- **Header and metadata:** title, cycle/task/base branch and base commit, readiness status, created/modified timestamps, commits, agent, session, and back/forward references. Record the startup Deming path/commit, local modifications, freshness, and any bootstrap in Provenance.
- **Purpose / Problem / Solution:** the engineering aim, confirmed understanding and user confirmation, affected system, proposed design, and alternatives considered. Use figures where they explain more than prose.
- **Theory and prediction / Scope:** original expected observable result, what would disconfirm it, non-goals, assumptions, constraints, run bounds, and stopping conditions.
- **Relevant files:** existing and new paths, each with its reason; explicitly say none where applicable.
- **Acceptance and study method:** atomic criteria and expected evidence, mapped to tasks and tests.
- **Ordered implementation phases:** goal/dependencies, concrete tasks, stable phase/task IDs, code or pseudocode when useful. Each phase ends in a Testing Strategy with exact commands/procedures, edge cases, expected results, and a validation loop.
- **Global validation:** the checks needed to establish the whole plan, not just the sum of unit tests. Include real UI/runtime checks where required.
- **Questionables:** toggleable questions, risks, assumptions, and answers when any remain or the user requests them; omit the section otherwise. Material unanswered questions block readiness.
- **Notes:** dependencies, tradeoffs, rejected approaches, run bounds, diagram validation evidence, and anything needed for another developer to implement without rediscovering scope.
- **Amendments:** initially empty; append dated changes after first execution, preserving the original prediction and prior executed history.
- **Handoff:** ready or blocked, with unresolved permissions or checks stated.

All phase, task, phase-test, and global-check markers start as `<code class="status">[]</code>`: `[]` idle, `[wip]` in progress, `[x]` complete, `[f]` failed or blocked with a reason/evidence link. Do owns their execution updates. Plan readiness is separate from implementation completion.

**Metadata discipline:** set `created` once. Initialize the other metadata fields, then append comma-separated entries only: modified timestamps, commits, agent/session identities, back/forward links. Use observed values; record unavailable values honestly. Use “None yet” for empty reference lists and preserve it when appending later. Deduplicate links and keep relative paths plus short labels. Preserve branch/base provenance. Do not overwrite history to make a plan appear current.

Replace every `{{...}}` token, duplicate repeatable blocks as needed, and remove repeat comments and unused figure slots. Never deliver unresolved placeholders. A hero, problem, solution, phase, questions, or notes figure is a candidate, not a quota: delete it when a table or paragraph does the job better.

### 4. Design and generate figures

Use the integrated guidance below. Author the HTML source first, validate it, extract its SVG, then embed it. Independent figure authoring may be parallelized; validation must precede embedding. No separate image-generation service or credentials are needed.

#### Meaning before layout

For each figure state its one or two primary ideas, semantic pattern (when behavior matters), visual type, engineer audience, canvas size, and any cuts forced by the complexity budget. Infer clear choices; ask only for material ambiguity. Preserve engineering vocabulary and actual system facts. Never invent components to fill space.

| Meaning | Pattern and required content | Layout |
|---|---|---|
| Components and integrations | Components, directed connections, named boundaries | Architecture: one left-right or top-down axis, at most 3 zones |
| Conditional behavior | Ordered rules; labeled outcomes, distinct decisions | Flowchart: top-down, oval start/end, rectangular actions, diamond decisions with at most 3 labeled exits |
| Why two policies differ | Paired traces: same ordered rules, explicit PASS/FAIL/SKIPPED/NOT REACHED and first divergence | Flowchart: exactly 2 traces, 3–6 rules, at most 12 status cells |
| Messages over time | Participants, ordered calls/returns, failure paths | Sequence: at most 5 lifelines, one combined fragment by default, at most 2 alternative regions |
| Subject lifecycle | Primary phases, separate wait/retry band and terminal outcomes, labeled transitions | State machine: 4–5 main phases, at most 2 recovery and 2 terminal states, 10 transitions |
| Intake contention | Sources, queue/count, capacity with units, service point, admitted/deferred outcomes | Data flow: at most 5 sources and 5 queue slots |
| Repeated stage questions | Consistent input/control/output slots, explicit empty cells, handoffs | Process: 3–6 stages, 3–4 slot kinds, at most 20 populated cells |
| Conversation becomes a record | Source excerpts, clarifications, field/value mappings, unknowns, durable artifact | Data flow: at most 4 exchanges, 6 fields, 3 provenance links |
| Supported route across trust boundaries | Identities, allowed ingress, forbidden paths stopping at boundaries, privileged gate, runtime, audit | Architecture: at most 8 components, 10 paths, 2 forbidden paths |
| Controls by enforcement surface | Named controls, enforcing actor, timing, bypass/exception and coverage gaps | Layer stack: 3–5 surfaces, at most 24 controls; split detail out of overview |
| Residual risk through defenses | Each mitigation, limitation/escape, and remaining risk; never imply zero risk | Layer stack: 3–5 layers, at most 2 mitigations each |
| Addressable decomposition | Stable dotted IDs, noun-phrase blocks, parentage, linked implementation; detail in notes | Tree: root plus 3 tiers, at most 5 children per parent |
| Ownership, data, dependency, or timing | Owners/handoffs, entity keys/cardinality, directed dependencies, or durations respectively | Swimlane (5 lanes), ER (8 entities), dependency graph (9 nodes), or timeline/Gantt (12 tasks) |

Choose one primary pattern. A second may add one supporting primitive, not another layout grammar; otherwise split overview/detail. Use other visual types only when they improve the explanation; define their encoding and bounds in Notes instead of depending on an external skill catalog.

**Remove test:** would removing a node/arrow/label lose meaning? Merge ideas that always travel together. Prefer a three-column table to a weak diagram. Aim for moderate density, at most 9 primary nodes and 12 connectors per schematic, 2 focal accents, 2 callouts. Apply tighter type/pattern limits when present; detailed matrices use their stated cell budget. Split rather than shrinking labels.

#### Shared visual identity

Use the template's editorial palette by default without an onboarding pause (Plan F3's default). If the project/plan provides explicit tokens, use them consistently across plan and figures. Record the choice; don't edit external skill files or silently substitute a brand.

- Paper `#f5f5f5`, secondary paper `#ececec`, ink `#2d3142`, muted `#4f5d75`, soft `#7a8399`, rule `#bfc0c0`, accent `#eb6c36`, accent-tint `#fce9df`, link `#2e5aa8`.
- Instrument Serif for titles (28px standard), Geist sans for human-readable node names (12px/600), Geist Mono only for technical labels (9px) and connector annotations (8px). Use installed fonts with explicit Georgia/Arial/Consolas fallbacks; disclose substitution. Do not rely on network fonts loading inside an SVG `<img>`.
- Clean paper, modest borders, 4–8px corner radii; no shadows, glow, rainbow palette, or generic equal-card grid. Accent only 1–2 focal elements. Use white backend nodes, muted stores, lightly tinted external/input nodes, and dashed optional/boundary outlines with text labels.
- Structural coordinates/dimensions/gaps follow a 4px grid. Start with `doc-inline` viewBox `0 0 960 600` or `doc-wide` `0 0 1280 720`; `fit` rounds content bounds up to 4px and adds 40px margins plus 60px for a bottom legend. Grow the canvas or split before shrinking text. For slides use 16px node labels and at least 40px gaps.
- Keep primary and secondary prose WCAG AA readable on paper; do not use soft color for essential text. For non-Latin labels use appropriate installed fallbacks and measure rendered width; wide/full-width characters need roughly 1em and a 12px floor. Preserve printed identifiers verbatim.

#### Geometry and accessibility

- Draw in order: background, zones, connectors, labels, nodes. Keep the legend in a separate bottom strip; include only encodings used.
- Use horizontal/vertical segments and rounded orthogonal elbows (radius 8px, minimum 6px); no diagonal inter-node slants. Enter top/bottom ports for vertical routes and left/right ports for horizontal routes.
- Connector labels need opaque paper masks with a visible 6–10px gap from their line, never covering a later node. Keep annotations short (about 14 characters); move explanation into the caption.
- No overlapping/shared connector strokes. Fan attachment points at least 12px apart (8px for tiny nodes); offset parallel routes at least 12px. At crossings, put a bridge/hop on the less important route.
- Route around non-endpoint nodes. Only for a geometrically unavoidable intervening layer may a dashed transit cross behind it, with the label at the visible end and arrowhead at the true destination.
- Each static SVG declares `xmlns="http://www.w3.org/2000/svg"`, a positive `viewBox`, `role="img"`, and `aria-labelledby="<slug>-title <slug>-desc"`. Its first element is a meaningful `<title id="<slug>-title">`; include a nonempty `<desc id="<slug>-desc">` explaining the subject, not the shapes. Prefix all IDs per figure, including markers.
- Status and boundaries use text/shape/line style, not color alone. Embed with descriptive `<img alt="..." />` and `<figcaption>`. Preserve readable label size on narrow screens using a horizontally scrollable figure and a full-size asset link, rather than shrinking the whole diagram. Adjust the template's 960px image width to the chosen canvas in the head stylesheet.
- Make the SVG self-contained: use SVG presentation attributes for colors and fonts, hex colors with separate opacity attributes, and internal marker references. Extraction cannot carry styling inherited from the HTML wrapper; avoid CSS variables, `rgba()` or `transparent` in SVG fill/stroke. No animation or executable content in cycle figures.

#### Validate, extract, embed

`../../scripts/plan-artifacts.ps1` is bundled with Deming; resolve it from this skill directory, not the target project. For each `diagrams/<subject>.html`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File <deming>/scripts/plan-artifacts.ps1 -Mode Diagram -Path <cycle>/diagrams/<subject>.html
powershell -NoProfile -ExecutionPolicy Bypass -File <deming>/scripts/plan-artifacts.ps1 -Mode Export -Path <cycle>/diagrams/<subject>.html -OutputPath <cycle>/diagrams/<subject>.svg
```

The checker tests structural accessibility/static-content conventions; Export writes the validated SVG atomically. It is not a security sanitizer or proof of visual geometry. Fix failed checks and rerun before embedding `<img src="diagrams/<subject>.svg" alt="..." />`. Keep both source and asset. Report each figure's type, paths, checks, and cuts/merges.

### 5. Validate and hand off

Run the bundled helper with `-Mode Plan -Path <cycle>/plan.html` after filling the plan and setting `Status: ready`. This catches unresolved scaffolding, missing sections, invalid markers, missing source/assets, and stale SVG exports. Review every requirement and link separately; structural success does not prove meaningful acceptance criteria.

Open the saved plan in the available browser (for example `Start-Process <cycle>/plan.html` on Windows). Inspect plan and extracted figures at their embedded size: clipping, labels, crossings, contrast, responsive/print layout, font substitutions, and link/image loading. Use available browser automation for geometry where possible; launching a browser is not itself verification. If unavailable, record the exact blocker and required visual review rather than claiming success. Ask before installing tools.

Mark ready only with confirmed scope, executable phases, mapped acceptance checks, and no material planning uncertainty. List any unavailable required validation as a handoff obligation. Give Do the cycle directory, `plan.html`, and a concise summary of phases, figures, validation, and remaining limitations.

## Update

Read the full plan, its images/sources, metadata, and depth-one back references. Confirm changed scope when material; reuse confirmation otherwise. Edit only affected sections and redraw only affected diagrams, preserving IDs/style and untouched assets. Append modified timestamp, agent/session and applicable commits; append a dated amendment explaining what changed and why. Before first execution, refine the draft; afterward preserve the original prediction, acceptance obligations, and executed task history. Put approved revisions in an amendment/new task or phase instead of rewriting past results. Material mid-experiment changes return through Plan before Do resumes. Revalidate sources, regenerate affected SVGs, and rerun plan checks; report the amendment.

## Update references

Determine link direction: back references are dependencies/prior work; forward references are derived/future work. Append relative links and short labels without duplicates. Update reciprocal links only in authorized related plans; otherwise report the needed counterpart as a handoff. Append modified/agent/session metadata and a dated amendment to every plan touched. Verify paths and report each link added.

## Sources

Adapted guidance: Plan F3 (`SKILL.md`, Create/Update/References/Build and Diagram Generation workflows) and Diagram Design v2.6 (selection, semantic patterns, style, geometry, accessibility, output sizing), supplied in `mcp-server` commit `e97ddacef5c1588f451812f451dec12d4da26600`. The supplied Diagram Design copy identifies upstream [cathrynlavery/diagram-design](https://github.com/cathrynlavery/diagram-design) at `dc1ace47b99a419e42d01a03cb6ace5346efa8ae` (MIT). This is integrated planning guidance, not a vendored skill tree. The plan workflow takes precedence over the former Markdown outline. General import, profile management, animation, and the external example library are outside this cycle-plan workflow.
