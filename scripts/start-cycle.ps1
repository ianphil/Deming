[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[0-9]+-[a-z0-9]+(-[a-z0-9]+)*$')]
    [string]$Cycle,
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

$branch = "deming/$Cycle"
$relativePath = ".deming/cycles/$Cycle"
$cyclePath = Join-Path $Repo $relativePath
if (Test-Path $cyclePath) { throw "Cycle already exists: $cyclePath" }
$branches = @(Invoke-Git for-each-ref --format='%(refname:short)' refs/heads/)
if ($branches -contains $branch) { throw "Branch already exists: $branch" }
# Cycle records are local-only. Respect existing ignore rules; add one if needed.
$needsIgnore = $false
foreach ($phase in @('plan', 'do', 'study', 'act')) {
    & git -C $Repo check-ignore --quiet -- "$relativePath/$phase.md"
    if ($LASTEXITCODE -eq 1) { $needsIgnore = $true }
    elseif ($LASTEXITCODE -ne 0) { throw 'Could not check Git ignore rules.' }
}

# Read every template before creating the branch or writing project files.
$templateDir = Join-Path (Split-Path $PSScriptRoot -Parent) 'templates'
$documents = @{}
foreach ($phase in @('plan', 'do', 'study', 'act')) {
    $text = Get-Content (Join-Path $templateDir "$phase.md") -Raw -Encoding UTF8
    $documents[$phase] = $text.Replace('{{cycle}}', $Cycle).Replace('{{branch}}', $branch).Replace('{{base_branch}}', $baseBranch).Replace('{{base_commit}}', $baseCommit)
}

Invoke-Git switch -c $branch
# On a write failure, leave the branch and partial records for inspection; never delete user work.
$utf8 = New-Object System.Text.UTF8Encoding($false)
if ($needsIgnore) {
    [IO.File]::AppendAllText((Join-Path $Repo '.gitignore'), "`n/.deming/`n", $utf8)
}
New-Item -ItemType Directory -Path $cyclePath | Out-Null
foreach ($phase in @('plan', 'do', 'study', 'act')) {
    [IO.File]::WriteAllText((Join-Path $cyclePath "$phase.md"), $documents[$phase], $utf8)
}
Write-Host "Created $branch from $baseBranch ($baseCommit)."
Write-Host "Cycle records: $cyclePath"
Write-Host 'Fill plan.md first. No files were committed or pushed.'
