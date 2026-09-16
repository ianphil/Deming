[CmdletBinding()]
param(
    [string]$InstallDir = (Join-Path $HOME ".deming"),
    [switch]$KeepRepository
)

$ErrorActionPreference = "Stop"
$piDir = Join-Path $HOME ".pi\agent"
$appendPath = Join-Path $piDir "APPEND_SYSTEM.md"
$settingsPath = Join-Path $piDir "settings.json"
$skillsPath = Join-Path $InstallDir "skills"
$scriptRoot = if ($PSScriptRoot) { [IO.Path]::GetFullPath($PSScriptRoot).TrimEnd('\', '/') } else { "" }
$installRoot = [IO.Path]::GetFullPath($InstallDir).TrimEnd('\', '/')
$runningFromInstall = $scriptRoot -and $scriptRoot -ieq $installRoot
$startMarker = "<!-- deming:start -->"

if (Test-Path $appendPath) {
    $append = Get-Content $appendPath -Raw
    $cleanAppend = [regex]::Replace($append, "(?ms)<!-- deming:start -->.*?<!-- deming:end -->\s*", "").Trim()
    if ($cleanAppend) {
        Set-Content -Path $appendPath -Value "$cleanAppend`r`n" -Encoding UTF8
    } elseif ($append -match [regex]::Escape($startMarker)) {
        Remove-Item $appendPath -Force
    }
}

if (Test-Path $settingsPath) {
    $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json
    $skills = @($settings.skills | Where-Object { $_ -and $_ -ne $skillsPath })
    if ($settings.PSObject.Properties.Name -contains "skills") {
        $settings.skills = $skills
        $settings | ConvertTo-Json -Depth 10 | Set-Content -Path $settingsPath -Encoding UTF8
    }
}

if (-not $KeepRepository -and -not $runningFromInstall -and (Test-Path (Join-Path $InstallDir ".git"))) {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Warning "Kept $InstallDir because Git is not available to verify it."
    } else {
        $origin = (& git -C $InstallDir config --get remote.origin.url 2>$null | Out-String).Trim()
        $status = (& git -C $InstallDir status --porcelain 2>$null)
        if ($origin -match "github\.com[/:]ianphil/Deming(\.git)?$" -and -not $status) {
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
