$ErrorActionPreference = "Stop"
$source = Split-Path $PSScriptRoot -Parent
$gitExe = (Get-Command git -CommandType Application | Select-Object -First 1).Source
$root = Join-Path ([IO.Path]::GetTempPath()) ("deming-test-" + [guid]::NewGuid())
$oldPath = $env:Path
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
function Snapshot($path) {
    [Convert]::ToBase64String([IO.File]::ReadAllBytes($path))
}
function Run-Git {
    & $gitExe -c user.name=Test -c user.email=test@example.invalid -c commit.gpgsign=false -c core.hooksPath=NUL @args
    if ($LASTEXITCODE -ne 0) { throw "Test Git command failed: $args" }
}
# No network access or real Pi installation during the tests.
function pi { }
function git {
    if ($args.Count -ne 4 -or $args[2] -ne 'pull' -or $args[3] -ne '--ff-only') {
        throw "Unexpected Git operation: $args"
    }
    $global:LASTEXITCODE = 0
}

New-Item -ItemType Directory -Path $root | Out-Null
# Shadow HOME only in this script's scope, never the user's profile.
Set-Variable -Name HOME -Value $root -Force -Scope Script
Push-Location $root
try {
    foreach ($file in @('install.ps1', 'uninstall.ps1')) {
        $tokens = $null; $errors = $null
        [void][System.Management.Automation.Language.Parser]::ParseFile((Join-Path $source $file), [ref]$tokens, [ref]$errors)
        Assert ($errors.Count -eq 0) "Syntax errors in $file"
    }
    $install = Join-Path $root 'clone'
    $skills = Join-Path $install 'skills'
    $soul = Join-Path $install 'SOUL.md'
    $system = Join-Path $install 'deming.system.md'
    New-Item -ItemType Directory -Path $skills -Force | Out-Null
    [IO.File]::WriteAllText($soul, 'soul', $utf8)
    [IO.File]::WriteAllText($system, 'system', $utf8)
    Run-Git init --quiet $install
    Run-Git -C $install remote add origin https://github.com/ianphil/Deming.git
    Run-Git -C $install add .
    Run-Git -C $install commit --quiet -m 'Initial test commit'

    $piDir = Join-Path $HOME '.pi\agent'
    New-Item -ItemType Directory -Path $piDir -Force | Out-Null
    $settingsPath = Join-Path $piDir 'settings.json'
    $appendPath = Join-Path $piDir 'APPEND_SYSTEM.md'
    & "$source\install.ps1" -InstallDir $install
    $freshSettings = [IO.File]::ReadAllText($settingsPath) | ConvertFrom-Json
    Assert (@($freshSettings.skills).Count -eq 1 -and $freshSettings.skills[0] -eq $skills) 'Fresh configuration was not created'
    Assert (Test-Path $appendPath) 'Fresh prompt was not created'

    $unicode = 'caf' + [char]0x00e9 + [char]0x65e5
    $originalSettings = '{"theme":"' + $unicode + '","skills":["other"]}'
    [IO.File]::WriteAllText($settingsPath, $originalSettings, $utf8)
    [IO.File]::WriteAllText($appendPath, $unicode, $utf8)

    & "$source\install.ps1" -InstallDir '.\clone'
    & "$source\install.ps1" -InstallDir $install
    $settings = [IO.File]::ReadAllText($settingsPath) | ConvertFrom-Json
    $append = [IO.File]::ReadAllText($appendPath)
    Assert ($settings.theme -ceq $unicode) 'Install corrupted a UTF-8 setting'
    Assert ($append.Contains($unicode)) 'Install corrupted the UTF-8 prompt'
    Assert (@($settings.skills).Count -eq 2 -and $settings.skills -contains $skills) 'Relative/absolute installs must share one absolute skills entry'
    Assert ($append.Contains($soul) -and $append.Contains($system)) 'Prompt paths must be absolute'
    Assert ([regex]::Matches($append, '<!-- deming:start -->').Count -eq 1) 'Repeated install duplicated the prompt block'

    # Missing resources and malformed settings must not change either file.
    foreach ($missing in @($soul, $system, $skills)) {
        Move-Item $missing "$missing.saved"
        try {
            $beforeSettings = Snapshot $settingsPath
            $beforeAppend = Snapshot $appendPath
            Assert-Fails { & "$source\install.ps1" -InstallDir $install } 'Missing resource was accepted'
            Assert ((Snapshot $settingsPath) -eq $beforeSettings) 'Failed install changed settings'
            Assert ((Snapshot $appendPath) -eq $beforeAppend) 'Failed install changed prompt'
        } finally { Move-Item "$missing.saved" $missing }
    }
    foreach ($invalid in @('{broken', 'null', '[]', '')) {
        [IO.File]::WriteAllText($settingsPath, $invalid, $utf8)
        $beforeSettings = Snapshot $settingsPath
        $beforeAppend = Snapshot $appendPath
        Assert-Fails { & "$source\install.ps1" -InstallDir $install } 'Invalid settings were accepted'
        Assert ((Snapshot $settingsPath) -eq $beforeSettings) 'Invalid settings were overwritten'
        Assert ((Snapshot $appendPath) -eq $beforeAppend) 'Invalid settings caused a prompt write'
    }
    [IO.File]::WriteAllText($settingsPath, $originalSettings, $utf8)
    $beforeSettings = Snapshot $settingsPath
    $beforeAppend = Snapshot $appendPath
    $piState = @{ Checks = 0 }
    function Get-Command {
        param($Name, $ErrorAction)
        if ($Name -eq 'pi') {
            $piState.Checks++
            if ($piState.Checks -gt 1) { return }
        }
        Microsoft.PowerShell.Core\Get-Command @PSBoundParameters
    }
    try {
        Assert-Fails { & "$source\install.ps1" -InstallDir $install } 'Unavailable Pi was accepted'
        Assert ($piState.Checks -eq 2) 'Pi availability check was not reached'
        Assert ((Snapshot $settingsPath) -eq $beforeSettings) 'Unavailable Pi changed settings'
        Assert ((Snapshot $appendPath) -eq $beforeAppend) 'Unavailable Pi changed prompt'
    } finally { Remove-Item Function:\Get-Command }

    # BOM-less input must also survive uninstall independently of install.
    $settings = $originalSettings | ConvertFrom-Json
    $settings.skills += $skills
    [IO.File]::WriteAllText($settingsPath, ($settings | ConvertTo-Json), $utf8)
    [IO.File]::WriteAllText($appendPath, ($unicode + "`n<!-- deming:start -->`nDeming`n<!-- deming:end -->"), $utf8)
    [IO.File]::WriteAllText((Join-Path $install 'local-work.txt'), 'unpublished work', $utf8)
    Run-Git -C $install add local-work.txt
    Run-Git -C $install commit --quiet -m 'Unpublished test commit'
    [IO.File]::WriteAllText($soul, 'stashed work', $utf8)
    Run-Git -C $install stash push --quiet
    [IO.File]::WriteAllText((Join-Path $install '.git\info\exclude'), 'ignored.txt', $utf8)
    $ignored = Join-Path $install 'ignored.txt'
    [IO.File]::WriteAllText($ignored, 'ignored data', $utf8)
    $head = Run-Git -C $install rev-parse HEAD
    $stash = Run-Git -C $install rev-parse refs/stash

    & "$source\uninstall.ps1" -InstallDir '.\clone'
    Assert (Test-Path $install) 'Default uninstall deleted the repository'
    Assert ((Run-Git -C $install rev-parse HEAD) -eq $head) 'Default uninstall lost local commits'
    Assert ((Run-Git -C $install rev-parse refs/stash) -eq $stash) 'Default uninstall lost the stash'
    Assert (Test-Path $ignored) 'Default uninstall lost ignored data'
    $settings = [IO.File]::ReadAllText($settingsPath) | ConvertFrom-Json
    Assert ($settings.theme -ceq $unicode) 'Uninstall corrupted a UTF-8 setting'
    Assert (@($settings.skills).Count -eq 1 -and $settings.skills[0] -eq 'other') 'Relative uninstall did not remove only Deming skills'
    Assert ([IO.File]::ReadAllText($appendPath).Trim() -ceq $unicode) 'Uninstall corrupted the UTF-8 prompt'
    & "$source\uninstall.ps1" -InstallDir $install -KeepRepository
    Assert (Test-Path $install) 'Legacy KeepRepository stopped working'
    Assert-Fails { & "$source\uninstall.ps1" -InstallDir $install -KeepRepository -RemoveRepository } 'Conflicting deletion options were accepted'

    # Explicit deletion still refuses failed verification and dirty clones.
    function git {
        if ($args[2] -eq 'config') {
            $global:LASTEXITCODE = 0
            'https://github.com/ianphil/Deming.git'
        } else { $global:LASTEXITCODE = 1 }
    }
    & "$source\uninstall.ps1" -InstallDir $install -RemoveRepository
    Assert (Test-Path $install) 'Failed Git status allowed deletion'
    Remove-Item Function:\git
    [IO.File]::WriteAllText($soul, 'uncommitted work', $utf8)
    & "$source\uninstall.ps1" -InstallDir $install -RemoveRepository
    Assert (Test-Path $install) 'Explicit removal deleted a dirty clone'
    [IO.File]::WriteAllText($soul, 'soul', $utf8)
    Run-Git -C $install remote set-url origin https://notgithub.com/ianphil/Deming.git
    & "$source\uninstall.ps1" -InstallDir $install -RemoveRepository
    Assert (Test-Path $install) 'Explicit removal deleted an unverified clone'
    Run-Git -C $install remote set-url origin https://github.com/ianphil/Deming.git

    # Only the explicit destructive option may delete a verified clean clone.
    & "$source\uninstall.ps1" -InstallDir $install -RemoveRepository
    Assert (-not (Test-Path $install)) 'Explicit repository removal did not work'
    Write-Host "PASS: $script:checks checks on PowerShell $($PSVersionTable.PSVersion)."
} finally {
    Pop-Location
    $env:Path = $oldPath
    Remove-Item $root -Recurse -Force
}
