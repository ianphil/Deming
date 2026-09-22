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
function Assert-Refusal($name, $message) {
    $beforeBranch = Run-Git rev-parse --abbrev-ref HEAD
    $beforeStatus = @(Run-Git status --porcelain) -join "`n"
    $beforeBranches = @(Run-Git for-each-ref --format='%(refname)' refs/heads/) -join "`n"
    Assert-Fails { & $setup -Name $name -Repo $repo } $message
    Assert ((Run-Git rev-parse --abbrev-ref HEAD) -eq $beforeBranch) 'Refusal switched branches'
    Assert ((@(Run-Git status --porcelain) -join "`n") -eq $beforeStatus) 'Refusal changed working tree status'
    Assert ((@(Run-Git for-each-ref --format='%(refname)' refs/heads/) -join "`n") -eq $beforeBranches) 'Refusal created a branch'
}

New-Item -ItemType Directory -Path $repo -Force | Out-Null
try {
    Run-Git init --quiet
    Run-Git symbolic-ref HEAD refs/heads/main
    Assert-Fails { & $setup -Name empty -Repo $repo } 'Unborn repository accepted'
    Assert (-not (Test-Path (Join-Path $repo '.deming'))) 'Unborn repository got cycle files'
    [IO.File]::WriteAllText((Join-Path $repo 'README.md'), '# Temporary project', $utf8)
    Run-Git add .
    Run-Git commit --quiet -m Initial
    $base = Run-Git rev-parse HEAD
    $subdir = Join-Path $repo 'subdir'
    New-Item -ItemType Directory -Path $subdir | Out-Null
    & $setup -Name crud -Repo $subdir
    Assert ((Run-Git branch --show-current) -eq 'deming/001-crud') 'Wrong first task branch'
    Assert ((Run-Git rev-parse HEAD) -eq $base) 'Setup created a commit or changed the base'
    $cycle = Join-Path $repo '.deming\cycles\001-crud'
    Assert (@(Get-ChildItem $cycle).Count -eq 4) 'Expected exactly four phase files'
    Assert (-not (Test-Path (Join-Path $cycle 'plan.md'))) 'New cycle created a Markdown plan'
    foreach ($file in @('plan.html', 'do.md', 'study.md', 'act.md')) {
        $text = [IO.File]::ReadAllText((Join-Path $cycle $file))
        $template = [IO.File]::ReadAllText((Join-Path $source "templates\$file"))
        $expected = $template.Replace('{{cycle}}', '001-crud').Replace('{{branch}}', 'deming/001-crud').Replace('{{base_branch}}', 'main').Replace('{{base_commit}}', $base)
        Assert ($text -ceq $expected) "Template not rendered correctly: $file"
        Assert ($text -match 'Status: pending') "Scaffold falsely marked complete: $file"
        & $gitExe -C $repo check-ignore --quiet -- ".deming/cycles/001-crud/$file"
        Assert ($LASTEXITCODE -eq 0) "Cycle record is not local-only: $file"
    }
    Assert-Refusal dirty 'Dirty working tree accepted'
    Run-Git add .
    Run-Git commit --quiet -m 'Cycle scaffolds'

    $existing = Join-Path $repo '.deming\cycles\003-existing'
    New-Item -ItemType Directory -Path $existing | Out-Null
    [IO.File]::WriteAllText((Join-Path $existing 'plan.md'), 'Existing work', $utf8)
    Run-Git branch deming/002-existing
    & $setup -Name next -Repo $repo
    Assert ((Run-Git branch --show-current) -eq 'deming/004-next') 'Did not choose the next cycle number'
    Assert ([IO.File]::ReadAllText((Join-Path $existing 'plan.md')) -ceq 'Existing work') 'Existing record overwritten'
    Assert (-not (Run-Git status --porcelain)) 'Local records dirtied the working tree'
    Assert (-not (Run-Git ls-files .deming)) 'Cycle records were tracked'

    Run-Git branch deming/005-existing
    & $setup -Name after-branch -Repo $repo
    Assert ((Run-Git branch --show-current) -eq 'deming/006-after-branch') 'Did not account for existing branch numbers'
    Assert (-not (Run-Git status --porcelain)) 'Second local cycle dirtied the working tree'

    Run-Git switch -c 'feature/a&b'
    & $setup -Name escaped -Repo $repo
    $html = [IO.File]::ReadAllText((Join-Path $repo '.deming\cycles\007-escaped\plan.html'))
    Assert ($html.Contains('feature/a&amp;b')) 'HTML provenance was not escaped'
    Assert (-not $html.Contains('feature/a&b')) 'Raw branch name leaked into HTML'
    & $gitExe -C $repo check-ignore --quiet -- '.deming/cycles/007-escaped/diagrams/overview.svg'
    Assert ($LASTEXITCODE -eq 0) 'Diagram assets are not ignored'

    Assert-Refusal '../escape' 'Unsafe name accepted'
    Assert-Refusal 'BadName' 'Uppercase name accepted'
    Assert-Refusal '004-explicit' 'Caller-supplied numeric prefix accepted'
    $ignoreBefore = [IO.File]::ReadAllText((Join-Path $repo '.gitignore'))
    Assert ([IO.File]::ReadAllText((Join-Path $repo '.gitignore')) -ceq $ignoreBefore) 'Ignore rules changed unexpectedly'

    $brokenInstall = Join-Path $root 'incomplete-deming'
    New-Item -ItemType Directory -Path (Join-Path $brokenInstall 'scripts') | Out-Null
    Copy-Item $setup (Join-Path $brokenInstall 'scripts\start-cycle.ps1')
    Copy-Item (Join-Path $source 'templates') $brokenInstall -Recurse
    Remove-Item (Join-Path $brokenInstall 'templates\act.md')
    $setup = Join-Path $brokenInstall 'scripts\start-cycle.ps1'
    Assert-Refusal missing-template 'Missing template accepted'
    $setup = Join-Path $source 'scripts\start-cycle.ps1'

    Run-Git checkout --quiet --detach
    Assert-Refusal detached 'Detached HEAD accepted'
    $notRepo = Join-Path $root 'not-a-repo'
    New-Item -ItemType Directory -Path $notRepo | Out-Null
    Assert-Fails { & $setup -Name outside -Repo $notRepo } 'Non-repository accepted'
    Assert (@(Get-ChildItem $notRepo -Force).Count -eq 0) 'Non-repository was changed'
    Write-Host "PASS: $script:checks checks on PowerShell $($PSVersionTable.PSVersion)."
} finally {
    Remove-Item $root -Recurse -Force
}
