[CmdletBinding()]
param(
    [string]$InstallDir = (Join-Path $HOME ".deming"),
    [switch]$KeepRepository,
    [switch]$RemoveRepository
)

$ErrorActionPreference = "Stop"
if ($KeepRepository -and $RemoveRepository) { throw "Choose either -KeepRepository or -RemoveRepository, not both." }
$InstallDir = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($InstallDir)
$piDir = Join-Path $HOME ".pi\agent"
$appendPath = Join-Path $piDir "APPEND_SYSTEM.md"
$settingsPath = Join-Path $piDir "settings.json"
$skillsPath = Join-Path $InstallDir "skills"
$scriptRoot = if ($PSScriptRoot) { [IO.Path]::GetFullPath($PSScriptRoot).TrimEnd('\', '/') } else { "" }
$installRoot = [IO.Path]::GetFullPath($InstallDir).TrimEnd('\', '/')
$runningFromInstall = $scriptRoot -and $scriptRoot -ieq $installRoot
$startMarker = "<!-- deming:start -->"

$settingsJson = $null
if (Test-Path $settingsPath) {
    $settings = Get-Content $settingsPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($settings -isnot [System.Management.Automation.PSCustomObject]) { throw "Pi settings must be a JSON object: $settingsPath" }
    if ($settings.PSObject.Properties.Name -contains "skills") {
        $settings.skills = @($settings.skills | Where-Object { $_ -and $_ -ne $skillsPath })
        $settingsJson = $settings | ConvertTo-Json -Depth 10
    }
}

if (Test-Path $appendPath) {
    $append = Get-Content $appendPath -Raw -Encoding UTF8
    $cleanAppend = [regex]::Replace($append, "(?ms)<!-- deming:start -->.*?<!-- deming:end -->\s*", "").Trim()
    if ($cleanAppend) {
        Set-Content -Path $appendPath -Value "$cleanAppend`r`n" -Encoding UTF8
    } elseif ($append -match [regex]::Escape($startMarker)) {
        Remove-Item $appendPath -Force
    }
}

if ($null -ne $settingsJson) {
    Set-Content -Path $settingsPath -Value $settingsJson -Encoding UTF8
}

if ($RemoveRepository -and -not $runningFromInstall -and (Test-Path (Join-Path $InstallDir ".git"))) {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Warning "Kept $InstallDir because Git is not available to verify it."
    } else {
        $origin = (& git -C $InstallDir config --get remote.origin.url 2>$null | Out-String).Trim()
        $originVerified = $LASTEXITCODE -eq 0 -and $origin -match "^(https://github\.com/|git@github\.com:)ianphil/Deming(\.git)?$"
        $status = (& git -C $InstallDir status --porcelain 2>$null)
        if ($originVerified -and $LASTEXITCODE -eq 0 -and -not $status) {
            Remove-Item $InstallDir -Recurse -Force
        } else {
            Write-Warning "Kept $InstallDir because it is not a clean Deming clone."
        }
    }
}

Write-Host "Deming configuration removed."
Write-Host "Pi, its other settings, skills, credentials, and sessions were left intact."
if ($KeepRepository -or $runningFromInstall -or (Test-Path $InstallDir)) {
    if ($runningFromInstall) {
        Write-Warning "Repository kept because the script is running from $InstallDir."
    } else {
        Write-Host "Repository kept at $InstallDir."
    }
}
