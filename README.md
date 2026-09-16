# Deming

Deming is a set of skills for the Agent Development Lifecycle (ADLC), based on the PDSA framework.

## Install for Pi

Run this in PowerShell:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/ianphil/Deming/master/install.ps1 | iex"
```

The installer installs Pi if needed, clones Deming to `$HOME\.deming`, and configures Pi to use its `SOUL.md`, `deming.system.md`, and skills. This makes Deming the default for every Pi session on the machine.

To update an existing installation:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$HOME\.deming\install.ps1"
```

To inspect the script before running it:

```powershell
irm https://raw.githubusercontent.com/ianphil/Deming/master/install.ps1 -OutFile "$env:TEMP\deming-install.ps1"
Get-Content "$env:TEMP\deming-install.ps1"
powershell -NoProfile -ExecutionPolicy Bypass -File "$env:TEMP\deming-install.ps1"
```

## Uninstall Deming

This removes Deming's global Pi configuration and its `$HOME\.deming` clone. It leaves Pi, other settings, skills, credentials, and sessions installed.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/ianphil/Deming/master/uninstall.ps1 | iex"
```

Use `-KeepRepository` when running the script locally if you want to remove the configuration but keep the clone.

The skills cover four stages:

- `plan`: form a hypothesis and predict the result
- `do`: run the smallest useful implementation or experiment
- `study`: compare the result with the prediction and learn about the system
- `act`: update the system, the theory, or the next experiment

Use them in this order:

`plan` → `do` → `study` → `act`

| PDSA  | Modern Agent/Engineering Equivalent                           |
| ----- | ------------------------------------------------------------- |
| Plan  | Hypothesis, spec, design, PRD, architecture                   |
| Do    | Agent runs a small implementation or experiment               |
| Study | Tests, reviews, evals, observed results, and system learning  |
| Act   | Update code, process, standards, prompts, specs, or next experiment |
