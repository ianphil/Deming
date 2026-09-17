[CmdletBinding()]
param(
    [string]$InstallDir,
    [switch]$Fetch
)

$ErrorActionPreference = 'Stop'
$report = [pscustomobject]@{
    Path = $InstallDir
    Commit = $null
    Branch = $null
    Upstream = $null
    Dirty = $null
    Ahead = $null
    Behind = $null
    Freshness = 'cached'
    Status = 'unknown'
    Message = ''
}
function Invoke-DemingGit {
    $result = & git -C $InstallDir @args 2>$null
    if ($LASTEXITCODE -ne 0) { throw "Git check failed: $args" }
    $result
}

try {
    if (-not $InstallDir) { $InstallDir = Split-Path $PSScriptRoot -Parent }
    $InstallDir = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($InstallDir)
    $report.Path = $InstallDir
    $root = Invoke-DemingGit rev-parse --show-toplevel
    if ([IO.Path]::GetFullPath($root).TrimEnd('\', '/') -ine $InstallDir.TrimEnd('\', '/')) {
        throw 'Installation path must be the root of its Git repository.'
    }
    $report.Commit = Invoke-DemingGit rev-parse --verify HEAD
    $report.Dirty = [bool](Invoke-DemingGit status --porcelain)
    $report.Branch = Invoke-DemingGit symbolic-ref --quiet --short HEAD
    $report.Upstream = Invoke-DemingGit rev-parse --abbrev-ref '@{upstream}'
    if ($Fetch) {
        $report.Freshness = 'unavailable'
        $remote = Invoke-DemingGit config --get "branch.$($report.Branch).remote"
        if ($remote -eq '.') { throw 'Upstream is local; no remote update check is available.' }
        $oldPrompt = $env:GIT_TERMINAL_PROMPT
        try {
            $env:GIT_TERMINAL_PROMPT = '0'
            Invoke-DemingGit -c credential.interactive=false fetch --quiet --no-tags -- $remote | Out-Null
        } finally { $env:GIT_TERMINAL_PROMPT = $oldPrompt }
        $report.Freshness = 'fetched'
    }
    $counts = (Invoke-DemingGit rev-list --left-right --count 'HEAD...@{upstream}') -split '\s+'
    $report.Ahead = [int]$counts[0]
    $report.Behind = [int]$counts[1]
    $report.Status = if ($report.Dirty) { 'modified' }
        elseif ($report.Ahead -and $report.Behind) { 'diverged' }
        elseif ($report.Ahead) { 'ahead' }
        elseif ($report.Behind) { 'behind' }
        else { 'current' }
    $report.Message = if ($report.Freshness -eq 'cached') {
        'Comparison uses cached upstream information; remote freshness is not verified.'
    } else { 'Upstream fetched. No working files, branch, or HEAD were updated.' }
} catch {
    $report.Status = 'unknown'
    $report.Message = "Update check unavailable: $($_.Exception.Message) Continue with the reported version; do not assume it is current."
}
$report
