# Deming

Deming is a set of agent instructions and skills for the Agent Development Lifecycle. It uses the Plan, Do, Study, Act cycle to guide work on code, documentation, tests, and development processes.

## How it works

The four skills ask the agent to predict what a change will do, make the change, and use the results to decide what to do next:

1. [Plan](skills/plan/SKILL.md). Define the goal, scope, and acceptance criteria. Predict the result and choose how to test it.
2. [Do](skills/do/SKILL.md). Run the planned experiment without contaminating the learning.
3. [Study](skills/study/SKILL.md). Review the change, run focused tests, and compare the evidence with the prediction. Record what the agent learned and what remains uncertain.
4. [Act](skills/act/SKILL.md). Adopt, revise, or abandon the change. Update the instructions or standards that need to change, or plan another experiment. Get authorization before pushing a branch or opening a pull request.

[SOUL.md](SOUL.md) defines Deming's voice, values, and boundaries. [deming.system.md](deming.system.md) sets the workflow and tells the agent when to use each skill.

## Cycle records

For a repository change, Plan starts a cycle in the target repository. For an explicitly requested new project in an empty directory outside another repository, Plan may initialize Git on `main` and make an empty baseline commit, recording that bootstrap in the plan. Pre-existing files or an existing unborn repository require an explicit baseline decision; the setup script never initializes or commits for you.

Choose an unused ID and start from the intended base branch with a clean working tree and at least one commit:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$HOME\.deming\scripts\start-cycle.ps1" -Cycle 001-adr-crud -Repo C:\src\adr-ui
```

Use your actual Deming installation path if different. The script creates and checks out `deming/001-adr-crud` from the current branch, then copies four templates:

```text
adr-ui/
└── .deming/cycles/001-adr-crud/
    ├── plan.md
    ├── do.md
    ├── study.md
    └── act.md
```

The files begin as pending scaffolds, not completed phase outputs. Plan fills `plan.md`; Do consumes it and fills `do.md`; Study consumes both and fills `study.md`; Act records the disposition in `act.md`. Resume by giving Deming the existing cycle directory, not by rerunning setup. Records are local-only and ignored: setup adds `/.deming/` to `.gitignore` when needed. Commit the ignore rule with the application changes, not the records. Existing tracked history is preserved. Ignored records support local session recovery but do not travel with a clone; summarize necessary evidence and decisions in the authorized PR or handoff.

Setup accepts ignored cycle paths and refuses dirty repositories, detached HEADs, and existing cycle directories or task branches. It does not commit, push, or merge. If writing fails after branch creation, inspect the retained branch and partial files before proceeding.

Cycle closure is separate from accepting behavior. Study records passed, failed, or untested criteria with their evidence; Act carries every unresolved required criterion into an explicit required handoff. An HTTP response or a mock-storage test is not proof that the browser UI works.

## Install for Pi

The PowerShell installer installs Pi if needed, clones Deming to `$HOME\.deming`, and adds its instructions and skills to your global Pi configuration. Deming then applies across projects for your user account.

Install Git first, then run this in PowerShell:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/ianphil/Deming/master/install.ps1 | iex"
```

Restart Pi or run `/reload` after installation.

### Inspect the installer

To read the script before running it:

```powershell
irm https://raw.githubusercontent.com/ianphil/Deming/master/install.ps1 -OutFile "$env:TEMP\deming-install.ps1"
Get-Content "$env:TEMP\deming-install.ps1"
powershell -NoProfile -ExecutionPolicy Bypass -File "$env:TEMP\deming-install.ps1"
```

### Update

To update an existing installation:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$HOME\.deming\install.ps1"
```

### Startup version check

Deming reports its installed path, commit, and update status once per session before project work. The check script never merges or updates working files:

```powershell
# Local-only: compare against cached upstream information.
powershell -NoProfile -ExecutionPolicy Bypass -File "$HOME\.deming\scripts\check-update.ps1"

# With network permission: fetch the configured upstream remote first.
powershell -NoProfile -ExecutionPolicy Bypass -File "$HOME\.deming\scripts\check-update.ps1" -Fetch
```

`Status` is `current`, `behind`, `ahead`, `diverged`, `modified`, or `unknown`. `Freshness` distinguishes a cached comparison from a successful fetch or an unavailable fetch. A failed check reports uncertainty rather than blocking project work. `-InstallDir` can select another installed clone; by default the script checks the clone containing itself, not the current project.

Deming asks before updating a behind installation and uses a fast-forward-only merge after a fresh, clean check. It preserves local changes and stops for a fresh session after updating. Restarting or `/reload` alone does not download new files. Older installations need the one-time update above before they can follow this startup rule.

### Custom location

Both `install.ps1` and `uninstall.ps1` accept `-InstallDir` when you run them locally. Relative paths resolve from the current PowerShell directory. Use the same location when updating or uninstalling.

## Uninstall

The uninstaller removes Deming's global Pi configuration. It keeps the clone, including local commits, stashes, and ignored files. It also leaves Pi, other settings, skills, credentials, and sessions intact.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/ianphil/Deming/master/uninstall.ps1 | iex"
```

`-KeepRepository` still works, but keeping the clone is now the default.

### Delete the clone too

`-RemoveRepository` deletes local commits, stashes, and ignored files too. Back them up first.

Download the uninstaller outside the clone, then pass `-RemoveRepository`:

```powershell
irm https://raw.githubusercontent.com/ianphil/Deming/master/uninstall.ps1 -OutFile "$env:TEMP\deming-uninstall.ps1"
powershell -NoProfile -ExecutionPolicy Bypass -File "$env:TEMP\deming-uninstall.ps1" -RemoveRepository
```

The script refuses to delete the clone if it cannot verify the origin, the working tree has uncommitted changes, or the script is running from the installation directory.

## Run the tests

Run the regression checks from the repository root with Windows PowerShell 5.1 and PowerShell 7:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tests\installer.tests.ps1
pwsh -NoProfile -File tests\installer.tests.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tests\cycle.tests.ps1
pwsh -NoProfile -File tests\cycle.tests.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tests\update.tests.ps1
pwsh -NoProfile -File tests\update.tests.ps1
```

### Live Pi evaluation (opt-in)

`tests/pi-e2e.ps1` runs a real `pi -p --mode json` session using your existing provider credentials. It consumes model tokens. Supply an **empty** target directory and a new evidence directory outside the target; the harness never deletes a project:

```powershell
pwsh -NoProfile -File tests\pi-e2e.ps1 -Repo C:\src\adr-ui -EvidenceDir C:\src\Deming\.deming\e2e-run-01
```

The harness uses the candidate checkout's installer instructions and skills in a temporary isolated Pi configuration, preserves sessions and candidate hashes, and removes its temporary credential copy afterward. It does not update the global installation. The trial permits local Git bootstrap/commits and browser testing, but not remote fetches, publishing, package installation, or global changes.

A successful Pi exit is **not** a passing evaluation. Inspect the saved session for startup ordering, bootstrap, phase handoffs, ignored records, real browser evidence, and required follow-up in Act. Independently rerun generated checks. Keep failed trials and interventions in the parent cycle's Study record.

The checks use temporary configuration and repositories. Installer checks replace Pi installation and network updates with test functions and leave your real Pi configuration untouched. Cycle checks exercise branch creation, template rendering, and refusal of unsafe or conflicting setup requests without network access. Update checks use local Git repositories to exercise version reporting and fetch failures; they do not contact GitHub or change the installed Deming.
