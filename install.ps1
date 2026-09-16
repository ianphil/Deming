[CmdletBinding()]
param(
    [string]$InstallDir = (Join-Path $HOME ".deming")
)

$ErrorActionPreference = "Stop"
$repoUrl = "https://github.com/ianphil/Deming.git"
$piDir = Join-Path $HOME ".pi\agent"
$appendPath = Join-Path $piDir "APPEND_SYSTEM.md"
$settingsPath = Join-Path $piDir "settings.json"

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw "Git is required. Install Git, then run this script again."
}

if (-not (Get-Command pi -ErrorAction SilentlyContinue)) {
    Write-Host "Installing Pi..."
    Invoke-Expression (Invoke-RestMethod "https://pi.dev/install.ps1")
}

if (Test-Path (Join-Path $InstallDir ".git")) {
    Write-Host "Updating Deming in $InstallDir..."
    & git -C $InstallDir pull --ff-only
    if ($LASTEXITCODE -ne 0) { throw "Could not update $InstallDir." }
} elseif (Test-Path $InstallDir) {
    throw "$InstallDir already exists and is not a Git repository. Choose another -InstallDir."
} else {
    Write-Host "Installing Deming in $InstallDir..."
    & git clone --depth 1 $repoUrl $InstallDir
    if ($LASTEXITCODE -ne 0) { throw "Could not clone Deming." }
}

New-Item -ItemType Directory -Force -Path $piDir | Out-Null

$soulPath = Join-Path $InstallDir "SOUL.md"
$systemPath = Join-Path $InstallDir "deming.system.md"
$skillsPath = Join-Path $InstallDir "skills"
$startMarker = "<!-- deming:start -->"
$endMarker = "<!-- deming:end -->"
$demingBlock = @"
$startMarker
# Deming agent

Before acting, read $soulPath and $systemPath.

SOUL.md defines Deming's identity, voice, values, and boundaries.
deming.system.md defines Deming's operating contract and PDSA workflow.

Use the Deming skills from $skillsPath for Plan, Do, Study, and Act.
$endMarker
"@.Trim()

$append = if (Test-Path $appendPath) { Get-Content $appendPath -Raw } else { "" }
$append = [regex]::Replace($append, "(?ms)<!-- deming:start -->.*?<!-- deming:end -->\s*", "").Trim()
$append = if ($append) { "$append`r`n`r`n$demingBlock" } else { $demingBlock }
Set-Content -Path $appendPath -Value "$append`r`n" -Encoding UTF8

$settings = if (Test-Path $settingsPath) {
    Get-Content $settingsPath -Raw | ConvertFrom-Json
} else {
    [pscustomobject]@{}
}

$skills = @($settings.skills | Where-Object { $_ })
if ($skills -notcontains $skillsPath) { $skills += $skillsPath }
if ($settings.PSObject.Properties.Name -contains "skills") {
    $settings.skills = $skills
} else {
    $settings | Add-Member -NotePropertyName skills -NotePropertyValue $skills
}
$settings | ConvertTo-Json -Depth 10 | Set-Content -Path $settingsPath -Encoding UTF8

Write-Host "Deming is configured for Pi."
Write-Host "Repository: $InstallDir"
Write-Host "Restart Pi or run /reload."
