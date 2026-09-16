# Deming

Deming is a set of agent instructions and skills for the Agent Development Lifecycle. It uses the Plan, Do, Study, Act cycle to guide work on code, documentation, tests, and development processes.

## How it works

The four skills ask the agent to predict what a change will do, make the change, and use the results to decide what to do next:

1. [Plan](skills/plan/SKILL.md). Define the goal, scope, and acceptance criteria. Predict the result and choose how to test it.
2. [Do](skills/do/SKILL.md). Run the planned experiment without contaminating the learning.
3. [Study](skills/study/SKILL.md). Review the change, run focused tests, and compare the evidence with the prediction. Record what the agent learned and what remains uncertain.
4. [Act](skills/act/SKILL.md). Adopt, revise, or abandon the change. Update the instructions or standards that need to change, or plan another experiment. Get authorization before pushing a branch or opening a pull request.

[SOUL.md](SOUL.md) defines Deming's voice, values, and boundaries. [deming.system.md](deming.system.md) sets the workflow and tells the agent when to use each skill.

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
```

The checks use temporary configuration and repositories. They replace Pi installation and network updates with test functions and leave your real Pi configuration untouched.
