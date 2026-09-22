[CmdletBinding()]
param(
    [string]$InstallDir = (Join-Path $HOME ".deming")
)

$ErrorActionPreference = "Stop"
$InstallDir = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($InstallDir)
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

$machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
$env:Path = "$machinePath;$userPath;$env:Path"
if (-not (Get-Command pi -ErrorAction SilentlyContinue)) {
    throw "Pi is not available after installation. Restart PowerShell and run this script again."
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

$soulPath = Join-Path $InstallDir "SOUL.md"
$systemPath = Join-Path $InstallDir "deming.system.md"
$skillsPath = Join-Path $InstallDir "skills"
foreach ($requiredPath in @($soulPath, $systemPath)) {
    if (-not (Test-Path $requiredPath -PathType Leaf)) { throw "Missing Deming file: $requiredPath" }
}
if (-not (Test-Path $skillsPath -PathType Container)) { throw "Missing Deming directory: $skillsPath" }
$startMarker = "<!-- deming:start -->"
$endMarker = "<!-- deming:end -->"
$demingBlock = @"
$startMarker
# Deming agent

Before acting, read $soulPath and $systemPath. Complete Startup and report the version check before loading any phase skill. Keep these steps sequential; do not batch phase-skill reads with startup.

SOUL.md defines Deming's identity, voice, values, and boundaries.
deming.system.md defines Deming's operating contract and PDSA workflow.

Use the Deming skills from $skillsPath for Spec sessions and Plan, Do, Study, and Act.
$endMarker
"@.Trim()

$append = if (Test-Path $appendPath) { Get-Content $appendPath -Raw -Encoding UTF8 } else { "" }
$append = [regex]::Replace($append, "(?ms)<!-- deming:start -->.*?<!-- deming:end -->\s*", "").Trim()
$append = if ($append) { "$append`r`n`r`n$demingBlock" } else { $demingBlock }

$settings = if (Test-Path $settingsPath) {
    Get-Content $settingsPath -Raw -Encoding UTF8 | ConvertFrom-Json
} else {
    [pscustomobject]@{}
}
if ($settings -isnot [System.Management.Automation.PSCustomObject]) { throw "Pi settings must be a JSON object: $settingsPath" }

$skills = @($settings.skills | Where-Object { $_ })
if ($skills -notcontains $skillsPath) { $skills += $skillsPath }
if ($settings.PSObject.Properties.Name -contains "skills") {
    $settings.skills = $skills
} else {
    $settings | Add-Member -NotePropertyName skills -NotePropertyValue $skills
}
$settingsJson = $settings | ConvertTo-Json -Depth 10

# Validate and prepare both files before changing global configuration.
New-Item -ItemType Directory -Force -Path $piDir | Out-Null
Set-Content -Path $appendPath -Value "$append`r`n" -Encoding UTF8
Set-Content -Path $settingsPath -Value $settingsJson -Encoding UTF8

$writtenSettings = Get-Content $settingsPath -Raw -Encoding UTF8 | ConvertFrom-Json
if (@($writtenSettings.skills) -notcontains $skillsPath) {
    throw "Pi settings do not contain the Deming skills path."
}
$writtenAppend = Get-Content $appendPath -Raw -Encoding UTF8
foreach ($requiredPath in @($soulPath, $systemPath, $skillsPath)) {
    if ($writtenAppend -notmatch [regex]::Escape($requiredPath)) {
        throw "Pi append prompt does not contain: $requiredPath"
    }
}

Write-Host "Deming is configured for Pi."
Write-Host "Repository: $InstallDir"
Write-Host "Restart Pi or run /reload."
