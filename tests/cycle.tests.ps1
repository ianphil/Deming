$ErrorActionPreference = 'Stop'
$source = Split-Path $PSScriptRoot -Parent
$setup = Join-Path $source 'scripts\start-cycle.ps1'
$gitExe = (Get-Command git -CommandType Application | Select-Object -First 1).Source
$root = Join-Path ([IO.Path]::GetTempPath()) ('deming-cycle-test-' + [guid]::NewGuid())
$repo = Join-Path $root 'target repo'
$utf8 = New-Object System.Text.UTF8Encoding($false)
$script:checks = 0

function Assert($condition, $message) {
    if (-not $condition) { throw $message }
    $script:checks++
}
function Assert-Fails($action, $message) {
    $failed = $false
    try { & $action } catch { $failed = $true }
    Assert $failed $message
}
function Run-Git {
    $result = & $gitExe -C $repo -c user.name=Test -c user.email=test@example.invalid -c commit.gpgsign=false -c core.hooksPath=NUL @args
    if ($LASTEXITCODE -ne 0) { throw "Test Git command failed: $args" }
    $result
}
function Assert-Refusal($id, $message) {
    $beforeBranch = Run-Git rev-parse --abbrev-ref HEAD
    $beforeStatus = @(Run-Git status --porcelain) -join "`n"
    $beforeBranches = @(Run-Git for-each-ref --format='%(refname)' refs/heads/) -join "`n"
    Assert-Fails { & $setup -Cycle $id -Repo $repo } $message
    Assert ((Run-Git rev-parse --abbrev-ref HEAD) -eq $beforeBranch) 'Refusal switched branches'
    Assert ((@(Run-Git status --porcelain) -join "`n") -eq $beforeStatus) 'Refusal changed working tree status'
    Assert ((@(Run-Git for-each-ref --format='%(refname)' refs/heads/) -join "`n") -eq $beforeBranches) 'Refusal created a branch'
}

New-Item -ItemType Directory -Path $repo -Force | Out-Null
try {
    Run-Git init --quiet
    Run-Git symbolic-ref HEAD refs/heads/main
    Assert-Fails { & $setup -Cycle 001-empty -Repo $repo } 'Unborn repository accepted'
    Assert (-not (Test-Path (Join-Path $repo '.deming'))) 'Unborn repository got cycle files'
    [IO.File]::WriteAllText((Join-Path $repo 'README.md'), '# Temporary project', $utf8)
    Run-Git add .
    Run-Git commit --quiet -m Initial
    $base = Run-Git rev-parse HEAD
    $subdir = Join-Path $repo 'subdir'
    New-Item -ItemType Directory -Path $subdir | Out-Null
    & $setup -Cycle 001-crud -Repo $subdir
    Assert ((Run-Git branch --show-current) -eq 'deming/001-crud') 'Wrong task branch'
    Assert ((Run-Git rev-parse HEAD) -eq $base) 'Setup created a commit or changed the base'
    $cycle = Join-Path $repo '.deming\cycles\001-crud'
    Assert (@(Get-ChildItem $cycle).Count -eq 4) 'Expected exactly four phase files'
    foreach ($phase in @('plan', 'do', 'study', 'act')) {
        $text = [IO.File]::ReadAllText((Join-Path $cycle "$phase.md"))
        $template = [IO.File]::ReadAllText((Join-Path $source "templates\$phase.md"))
        $expected = $template.Replace('{{cycle}}', '001-crud').Replace('{{branch}}', 'deming/001-crud').Replace('{{base_branch}}', 'main').Replace('{{base_commit}}', $base)
        Assert ($text -ceq $expected) "Template not rendered correctly: $phase"
        Assert ($text -match 'Status: pending') "Scaffold falsely marked complete: $phase"
    }
    Assert-Refusal 002-dirty 'Dirty working tree accepted'
    Run-Git add .
    Run-Git commit --quiet -m 'Cycle scaffolds'
    Assert-Refusal 001-crud 'Existing cycle accepted'
    Assert-Refusal '../escape' 'Unsafe cycle ID accepted'
    Run-Git branch deming/003-existing
    Assert-Refusal 003-existing 'Existing branch accepted'
    $existing = Join-Path $repo '.deming\cycles\004-existing'
    New-Item -ItemType Directory -Path $existing | Out-Null
    [IO.File]::WriteAllText((Join-Path $existing 'plan.md'), 'Existing work', $utf8)
    Run-Git add .
    Run-Git commit --quiet -m 'Existing cycle record'
    Assert-Refusal 004-existing 'Existing directory accepted'
    Assert ([IO.File]::ReadAllText((Join-Path $existing 'plan.md')) -ceq 'Existing work') 'Existing record overwritten'
    [IO.File]::WriteAllText((Join-Path $repo '.gitignore'), ".deming/cycles/005-ignored/`n.deming/cycles/008-ignored-file/study.md`n", $utf8)
    Run-Git add .
    Run-Git commit --quiet -m 'Ignore a cycle path'
    Assert-Refusal 005-ignored 'Ignored cycle path accepted'
    Assert-Refusal 008-ignored-file 'Ignored phase file accepted'
    $brokenInstall = Join-Path $root 'incomplete-deming'
    New-Item -ItemType Directory -Path (Join-Path $brokenInstall 'scripts') | Out-Null
    Copy-Item $setup (Join-Path $brokenInstall 'scripts\start-cycle.ps1')
    Copy-Item (Join-Path $source 'templates') $brokenInstall -Recurse
    Remove-Item (Join-Path $brokenInstall 'templates\act.md')
    $setup = Join-Path $brokenInstall 'scripts\start-cycle.ps1'
    Assert-Refusal 009-missing-template 'Missing template accepted'
    $setup = Join-Path $source 'scripts\start-cycle.ps1'
    Run-Git checkout --quiet --detach
    Assert-Refusal 006-detached 'Detached HEAD accepted'
    $notRepo = Join-Path $root 'not-a-repo'
    New-Item -ItemType Directory -Path $notRepo | Out-Null
    Assert-Fails { & $setup -Cycle 007-outside -Repo $notRepo } 'Non-repository accepted'
    Assert (@(Get-ChildItem $notRepo -Force).Count -eq 0) 'Non-repository was changed'
    Write-Host "PASS: $script:checks checks on PowerShell $($PSVersionTable.PSVersion)."
} finally {
    Remove-Item $root -Recurse -Force
}
