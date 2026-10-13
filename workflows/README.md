# Local PDSA workflow prototype

Prefect coordinates one PDSA cycle. A host-side Python process runs **headless Pi**, which uses **gpt-6.1-sol through your existing GitHub Copilot subscription**. No Copilot SDK, Copilot CLI, custom model gateway, or global Pi changes are needed.

This is a single-user experiment, not a production service or generic workflow builder. Windows, PowerShell, Git, Pi 1.0.4, Python 3.12 and Prefect 3.8.7 are the initial target. Linux process cleanup is implemented but not live-validated.

## Start the local services

From the Deming checkout, with `uv`, Docker Compose and Pi installed:

```powershell
uv sync --locked
docker compose up -d --wait
uv run --locked python -m workflows serve
```

Keep the serving terminal open. The [Prefect UI](http://127.0.0.1:4200) and API bind to loopback. The container stores its SQLite database in a named volume; it receives **no host repository or model credentials**. The Python serving process launches work on your host, one run at a time.

The lockfile was resolved through the author's configured Microsoft package feed. `uv` needs network access to the registries/artifact URLs recorded there. On a slow feed, use a process-local `UV_HTTP_TIMEOUT=120`; don't disable TLS checks or change global configuration. A different organization's feed may require an explicitly reviewed lock refresh.

The CLI sets Prefect state under this checkout's ignored `.deming/prefect-host/`, disables an implicit ephemeral server, and rejects non-loopback API URLs. It does not call `prefect config set`. `PREFECT_API_URL` can select another **local** port, but update the Compose port and UI API URL consistently too.

## Prepare and submit a cycle

1. Agree on a small task and its scope. Save its request in a UTF-8 file outside the target repository, or commit it as part of an agreed baseline. The request must contain no credentials.
2. Start on the intended base branch of a clean, committed target repository. Use Deming's normal setup script:

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File C:\src\Deming\scripts\start-cycle.ps1 -Name small-change -Repo C:\src\my-project
   ```

   Use your real Deming checkout path. Setup reports the assigned cycle ID and creates its branch/scaffolds. This prototype consumes that cycle; it does not initialize projects or replace cycle setup.
3. From the Deming checkout, in another terminal, submit the reported cycle:

   ```powershell
   uv run --locked python -m workflows submit `
     --cycle C:\src\my-project\.deming\cycles\001-small-change `
     --request-file C:\requests\small-change.md `
     --scope-confirmed
   ```

   `--scope-confirmed` is your confirmation of the supplied request, not permission for unrelated work. The default model is `gpt-6.1-sol`; `--model` and `--timeout-seconds` override the model and per-attempt limit. The target must remain on `deming/<cycle-id>` throughout execution.
4. Open the printed run URL. After Plan, the run becomes **Suspended** and the host flow process exits. Inspect the actual `plan.html` on the host, then use **Resume** in the UI and explicitly approve or deny continuation. The review form includes the plan's SHA-256.

   The equivalent CLI commands are:

   ```powershell
   uv run --locked python -m workflows status <run-id>
   uv run --locked python -m workflows resume <run-id> --approve --answer "Reviewed; continue the same local scope."
   # Or refuse continuation:
   uv run --locked python -m workflows resume <run-id> --deny
   ```

An approval permits only the already-confirmed local work. It does not authorize publishing, package installation, destructive cleanup, or global changes. A refusal fails the run before the next phase. A phase can ask one clarification question and receive one further attempt; another question or a `blocked` result stops dependent work for inspection.

## Pi profile and authentication

Each phase gets a temporary Pi configuration directory containing explicit settings and, when needed, **only the existing `github-copilot` credential**. Discovered extensions, skills, context files and project settings are disabled. The worker instructions explicitly load Deming's startup contract and the dispatched phase skill from `--deming-dir` (the checkout by default).

Authentication uses:

1. `COPILOT_GITHUB_TOKEN`, if already present in the serving process environment; otherwise
2. The `github-copilot` entry in your existing Pi `auth.json`, discovered through the original `PI_CODING_AGENT_DIR` or `~/.pi/agent`. `submit --auth-file <path>` selects a different existing Pi auth file.

Keep credentials out of request files, Prefect parameters, command-line token arguments, logs, and Git. Only a file **path**, never its contents, is passed as a flow parameter. No unrelated provider credential is staged. Login/renew authentication through your normal Pi session if needed; starting a headless worker does not perform an interactive login.

Temporary profiles are removed after successful and handled-error exits. An abrupt process/machine kill can leave `deming-pi-*` directories in the user's OS temporary directory: inspect and remove only abandoned directories after verifying their processes are stopped. Persistent sessions and transcripts may contain sensitive project content even when credentials were never deliberately logged.

## Results and recovery

The Python workflow is explicitly Plan → review → Do → Study → Act. Pi executes one phase and ends at its handoff. Its final JSON result is validated separately from the JSONL event stream and process exit code. A zero exit with an assistant error, malformed output, wrong model/phase, missing settlement, or missing/pending artifact is rejected. HTML plans also run through Deming's structural validator; this does not establish semantic correctness or browser behavior.

Evidence is local and ignored:

```text
<cycle>/
  plan.html / do.md / study.md / act.md   # existing PDSA records
  workflow/
    owner.json                          # immutable run/config/instruction binding
    plan-reviewed.html                  # exact plan presented for review, not a second plan
    approval.json
    prefect-results/                    # Prefect task cache; preserve across host restarts
    attempts/<phase>-<number>/
      prompt.txt
      events.jsonl / stderr.log
      sessions/
      process.json
      record-hashes.json / result.json  # accepted output, or failure.json
    outcome.json
```

`plan-reviewed.html` is an audit snapshot only; the live `plan.html` remains authoritative. Do may update its execution checklist, with accepted changes hashed for later replays.

- **Suspended at review:** you can stop/restart `serve`, then resume the **same run ID**. Prefect replays flow code but cached phase results prevent repeated Pi calls. File/branch/input checks still execute.
- **Failed, timed out or unexpectedly interrupted:** inspect Prefect, the attempt's evidence, live processes and repository diff first. There are no automatic retries. An exclusive attempt directory prevents another invocation if completion is uncertain, even if a cache is missing.
- **Changed request, instructions or task branch:** the run refuses to continue. Reconcile the work with Deming and agree on the next cycle/baseline. Do not delete `owner.json`, attempt directories, or caches to force a replay. This prototype deliberately has no automatic repair command.
- **Act recommends revision:** this run records the disposition and required handoff. It does not spawn another cycle or push/merge anything.

This protects against accidental replay; it is **not transactional filesystem rollback or exactly-once execution**. A Completed flow means phase execution finished, not that every acceptance criterion passed. Read Study and Act.

## Trust boundary

The unauthenticated loopback API and serving process are for a trusted local machine. Anyone able to submit local run parameters can influence host execution. A temporary Pi profile is **not a sandbox**: its shell tools have the host account's permissions. Prompt restrictions and approval forms do not enforce OS access controls. Use trusted repositories and a limited account/isolated machine for unattended work; multi-user service hardening is outside this prototype.

## Tests and opt-in trials

```powershell
uv run --locked pytest tests/workflows -q
docker compose config --quiet
```

Tests use fake Pi subprocesses, including timeout/child cleanup; they do not spend model allowance. The runtime helper requires the running local container and creates a fresh scratch Git repository outside the checkout, preserving it and all evidence:

```powershell
# Real Prefect, fake Pi. Choose a NEW evidence directory each time.
uv run --locked python tests/workflows/trial.py start --evidence .deming\trial-01
# Read the saved trial.json and generated plan; then:
uv run --locked python tests/workflows/trial.py finish --evidence .deming\trial-01 --approve-reviewed-plan
```

`start` stops the serving process while the run is suspended; `finish` starts a fresh one and resumes it. The fake plan is a structural fixture, not a meaningful implementation plan. After inspecting the generated plan, the explicit finish flag authorizes a test input to exercise the mechanism; it is not an independent human review claim.

Add `--live` to **start** only when you explicitly want a Copilot-backed trial that consumes model allowance and makes one tiny scratch README change. Inspect that real plan before finishing. The helper checks one attempt per phase and unchanged interactive Pi configuration; independently inspect the actual records and README as well. Never treat a successful process exit alone as acceptance.

## Current validation limits

The initial evaluation passed the adapter/flow regression suite and a real Prefect run with fake Pi, including a serving-process restart and a Cached Plan task. The Copilot-backed run reached Plan review, but browser inspection found narrow-viewport overflow in its generated HTML plan. It was left suspended, without approving or modifying its README. Real-agent Do/Study/Act and restart completion therefore remain **unverified**; the fake run is not a substitute. Correct and re-review the plan through an agreed recovery/cycle procedure before further live work. A subsequent subprocess-cleanup fix also changes the bound instruction hash; the original paused run is retained as evidence, not ready for blind resumption under the changed code.

## Stop

Stop the serving terminal with Ctrl+C, then:

```powershell
docker compose down
```

This preserves the database volume, local results and evidence. `docker compose down -v` would delete the server's run history; don't use it unless you intend that loss. Stopping only the serving process leaves the UI available.
