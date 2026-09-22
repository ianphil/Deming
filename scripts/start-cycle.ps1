[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('(?-i)^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$')]
    [string]$Name,
    [string]$Repo = '.'
)

$ErrorActionPreference = 'Stop'
function Invoke-Git {
    $result = & git -C $Repo @args
    if ($LASTEXITCODE -ne 0) { throw "Git failed: git -C $Repo $args" }
    $result
}

$Repo = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Repo)
$Repo = (Invoke-Git rev-parse --show-toplevel).Trim()
$baseBranch = (Invoke-Git symbolic-ref --quiet --short HEAD).Trim()
$baseCommit = (Invoke-Git rev-parse --verify HEAD).Trim()
if (Invoke-Git status --porcelain) { throw 'Working tree must be clean before starting a cycle.' }

$localBranches = @(Invoke-Git for-each-ref --format='%(refname:short)' refs/heads/)
$allRefs = @(Invoke-Git for-each-ref --format='%(refname:short)' refs/heads/ refs/remotes/)
$usedNumbers = @()
foreach ($ref in $allRefs) {
    if ($ref -match '(?:^|/)deming/([0-9]+)-') {
        $usedNumbers += [int]$Matches[1]
    }
}

$cycleRoot = Join-Path $Repo '.deming\cycles'
if (Test-Path $cycleRoot) {
    foreach ($directory in Get-ChildItem -LiteralPath $cycleRoot -Directory) {
        if ($directory.Name -match '^([0-9]+)-') {
            $usedNumbers += [int]$Matches[1]
        }
    }
}

$nextNumber = 1
if ($usedNumbers.Count -gt 0) {
    $nextNumber = [int](($usedNumbers | Measure-Object -Maximum).Maximum) + 1
}
do {
    $Cycle = '{0:D3}-{1}' -f $nextNumber, $Name
    $branch = "deming/$Cycle"
    $relativePath = ".deming/cycles/$Cycle"
    $cyclePath = Join-Path $Repo $relativePath
    if (($localBranches -contains $branch) -or (Test-Path $cyclePath)) {
        $nextNumber++
        continue
    }
    break
} while ($true)

# Cycle records are local-only. Respect existing ignore rules; add one if needed.
$needsIgnore = $false
$recordFiles = @('plan.html', 'do.md', 'study.md', 'act.md')
foreach ($file in ($recordFiles + @('diagrams/probe.html', 'diagrams/probe.svg'))) {
    & git -C $Repo check-ignore --quiet -- "$relativePath/$file"
    if ($LASTEXITCODE -eq 1) { $needsIgnore = $true }
    elseif ($LASTEXITCODE -ne 0) { throw 'Could not check Git ignore rules.' }
}

# Read every template before creating the branch or writing project files.
$templateDir = Join-Path (Split-Path $PSScriptRoot -Parent) 'templates'
$documents = @{}
foreach ($file in $recordFiles) {
    $text = Get-Content (Join-Path $templateDir $file) -Raw -Encoding UTF8
    $values = @{ cycle = $Cycle; branch = $branch; base_branch = $baseBranch; base_commit = $baseCommit }
    foreach ($key in $values.Keys) {
        $value = $values[$key]
        if ($file.EndsWith('.html')) { $value = [System.Net.WebUtility]::HtmlEncode($value) }
        $text = $text.Replace("{{$key}}", $value)
    }
    $documents[$file] = $text
}

Invoke-Git switch -c $branch
# On a write failure, leave the branch and partial records for inspection; never delete user work.
$utf8 = New-Object System.Text.UTF8Encoding($false)
if ($needsIgnore) {
    [IO.File]::AppendAllText((Join-Path $Repo '.gitignore'), "`n/.deming/`n", $utf8)
}
New-Item -ItemType Directory -Path $cyclePath | Out-Null
foreach ($file in $recordFiles) {
    [IO.File]::WriteAllText((Join-Path $cyclePath $file), $documents[$file], $utf8)
}
Write-Host "Created $branch from $baseBranch ($baseCommit)."
Write-Host "Cycle records: $cyclePath"
Write-Host 'Fill plan.html first; keep diagram sources and SVGs in diagrams/. No files were committed or pushed.'
