$ErrorActionPreference = 'Stop'
$source = Split-Path $PSScriptRoot -Parent
$check = Join-Path $source 'scripts\check-update.ps1'
$root = Join-Path ([IO.Path]::GetTempPath()) ('deming-update-test-' + [guid]::NewGuid())
$remote = Join-Path $root 'origin.git'
$seed = Join-Path $root 'seed'
$install = Join-Path $root 'installed deming'
$utf8 = New-Object System.Text.UTF8Encoding($false)
$script:checks = 0
function Assert($condition, $message) {
    if (-not $condition) { throw $message }
    $script:checks++
}
function Run-Git($repo) {
    $result = & git -C $repo -c user.name=Test -c user.email=test@example.invalid -c commit.gpgsign=false -c core.hooksPath=NUL @args
    if ($LASTEXITCODE -ne 0) { throw "Test Git command failed: $args" }
    $result
}
function Check-Installation([switch]$Fetch) {
    $head = Run-Git $install rev-parse HEAD
    $branch = Run-Git $install rev-parse --abbrev-ref HEAD
    $status = @(Run-Git $install status --porcelain) -join "`n"
    $prompt = $env:GIT_TERMINAL_PROMPT
    $report = & $check -InstallDir $install -Fetch:$Fetch
    Assert ((Run-Git $install rev-parse HEAD) -eq $head) 'Check changed HEAD'
    Assert ((Run-Git $install rev-parse --abbrev-ref HEAD) -eq $branch) 'Check switched branches'
    Assert ((@(Run-Git $install status --porcelain) -join "`n") -eq $status) 'Check changed working tree status'
    Assert ($env:GIT_TERMINAL_PROMPT -eq $prompt) 'Check changed prompt environment'
    Assert ($report.Commit -eq $head -and $report.Path -eq $install) 'Wrong installation identity'
    $report
}
function Publish-Change($text) {
    [IO.File]::WriteAllText((Join-Path $seed 'README.md'), $text, $utf8)
    Run-Git $seed add .
    Run-Git $seed commit --quiet -m $text
    Run-Git $seed push --quiet origin master
}

New-Item -ItemType Directory -Path $root, $seed | Out-Null
try {
    Run-Git $root init --quiet --bare $remote
    Run-Git $remote symbolic-ref HEAD refs/heads/master
    Run-Git $seed init --quiet
    Run-Git $seed symbolic-ref HEAD refs/heads/master
    Run-Git $seed remote add origin $remote
    Publish-Change Initial
    Run-Git $root clone --quiet --no-local --depth 1 $remote $install
    $report = Check-Installation -Fetch
    Assert ($report.Status -eq 'current' -and $report.Freshness -eq 'fetched') 'Fresh current state not reported'
    Assert ($report.Branch -eq 'master' -and $report.Upstream -eq 'origin/master') 'Wrong branch or upstream'

    Publish-Change Update
    $report = Check-Installation
    Assert ($report.Status -eq 'current' -and $report.Freshness -eq 'cached') 'Default check fetched or claimed fresh information'
    $report = Check-Installation -Fetch
    Assert ($report.Status -eq 'behind' -and $report.Behind -eq 1 -and $report.Ahead -eq 0) 'Behind state not reported'
    [IO.File]::WriteAllText((Join-Path $install 'local.txt'), 'User work', $utf8)
    $report = Check-Installation -Fetch
    Assert ($report.Status -eq 'modified' -and $report.Dirty) 'Local changes not reported'
    Assert ([IO.File]::ReadAllText((Join-Path $install 'local.txt')) -ceq 'User work') 'Local work overwritten'
    Remove-Item (Join-Path $install 'local.txt')

    Run-Git $install remote set-url origin (Join-Path $root 'unavailable.git')
    $report = Check-Installation
    Assert ($report.Status -eq 'behind' -and $report.Freshness -eq 'cached') 'Local-only check required remote access'
    $report = Check-Installation -Fetch
    Assert ($report.Status -eq 'unknown' -and $report.Freshness -eq 'unavailable') 'Failed fetch claimed a current installation'
    Run-Git $install remote set-url origin $remote

    # Simulate the separately authorized update documented in the startup rule.
    Run-Git $install merge --quiet --ff-only '@{upstream}'
    Assert ((Check-Installation -Fetch).Status -eq 'current') 'Fast-forward update did not reach current state'
    [IO.File]::WriteAllText((Join-Path $install 'local.txt'), 'Local commit', $utf8)
    Run-Git $install add .
    Run-Git $install commit --quiet -m 'Local change'
    Assert ((Check-Installation).Status -eq 'ahead') 'Ahead state not reported'
    Publish-Change Divergence
    $report = Check-Installation -Fetch
    Assert ($report.Status -eq 'diverged' -and $report.Ahead -eq 1 -and $report.Behind -eq 1) 'Divergence not reported'
    Run-Git $install checkout --quiet --detach
    Assert ((Check-Installation).Status -eq 'unknown') 'Detached HEAD accepted for updating'
    Run-Git $install checkout --quiet master
    Run-Git $install branch --unset-upstream
    Assert ((Check-Installation).Status -eq 'unknown') 'Missing upstream accepted for updating'
    $report = & $check -InstallDir $root
    Assert ($report.Status -eq 'unknown') 'Non-repository check did not report uncertainty'
    $report = & $check -InstallDir (Join-Path $root 'missing')
    Assert ($report.Status -eq 'unknown') 'Missing installation did not report uncertainty'

    # Default to the script's own installation, even when invoked from another project.
    $scripts = Join-Path $install 'scripts'
    New-Item -ItemType Directory -Path $scripts | Out-Null
    Copy-Item $check (Join-Path $scripts 'check-update.ps1')
    Push-Location $seed
    try {
        $scriptPath = Join-Path $scripts 'check-update.ps1'
        $report = & $scriptPath
        $shellName = if ($PSVersionTable.PSVersion.Major -eq 5) { 'powershell.exe' } else { 'pwsh.exe' }
        $shell = Join-Path $PSHOME $shellName
        $output = (& $shell -NoProfile -ExecutionPolicy Bypass -File $scriptPath | Out-String)
        Assert ($LASTEXITCODE -eq 0) 'Child -File invocation failed'
        Assert (($output -replace '\s', '').Contains(($install -replace '\s', '')) -and $output.Contains((Run-Git $install rev-parse HEAD))) 'Child -File default did not identify its installation'
        $output = (& $shell -NoProfile -ExecutionPolicy Bypass -File $scriptPath -InstallDir $seed | Out-String)
        Assert ($LASTEXITCODE -eq 0 -and ($output -replace '\s', '').Contains(($seed -replace '\s', '')) -and $output.Contains((Run-Git $seed rev-parse HEAD))) 'Child -File ignored explicit InstallDir'
    } finally { Pop-Location }
    Assert ($report.Path -eq $install -and $report.Commit -eq (Run-Git $install rev-parse HEAD)) 'Default check used the target project instead of its installation'
    Write-Host "PASS: $script:checks checks on PowerShell $($PSVersionTable.PSVersion)."
} finally {
    Remove-Item $root -Recurse -Force
}
