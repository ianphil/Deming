# Opt-in live evaluation: uses provider credentials and consumes model tokens.
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Repo,
    [Parameter(Mandatory = $true)][string]$EvidenceDir,
    [string]$Provider = 'github-copilot',
    [string]$Model = 'gpt-5.6-luna'
)
$ErrorActionPreference = 'Stop'
$source = Split-Path $PSScriptRoot -Parent
$Repo = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Repo)
$EvidenceDir = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($EvidenceDir)
if (-not (Test-Path $Repo -PathType Container) -or @(Get-ChildItem $Repo -Force).Count) {
    throw 'Provide an existing empty target directory. This test never deletes a project.'
}
if (Test-Path $EvidenceDir) { throw 'Choose a new evidence directory for each run.' }
if ($EvidenceDir.StartsWith($Repo.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Keep evidence outside the target project.'
}
$config = Join-Path ([IO.Path]::GetTempPath()) ('deming-pi-' + [guid]::NewGuid())
$agentDir = if ($env:PI_CODING_AGENT_DIR) { $env:PI_CODING_AGENT_DIR } else { Join-Path $HOME '.pi\agent' }
$oldConfig = $env:PI_CODING_AGENT_DIR
$utf8 = New-Object System.Text.UTF8Encoding($false)
New-Item -ItemType Directory -Path $config, $EvidenceDir | Out-Null
try {
    # Keep credentials out of evidence and remove this private temporary copy on exit.
    Copy-Item (Join-Path $agentDir 'auth.json') $config
    $catalog = Join-Path $agentDir 'models-store.json'
    if (Test-Path $catalog) { Copy-Item $catalog $config }
    $installer = Get-Content (Join-Path $source 'install.ps1') -Raw
    $block = [regex]::Match($installer, '(?s)\$demingBlock = @"\r?\n(.*?)\r?\n"@\.Trim\(\)').Groups[1].Value
    if (-not $block) { throw 'Could not recover the installer startup instructions.' }
    $paths = @{
        '$soulPath' = (Join-Path $source 'SOUL.md')
        '$systemPath' = (Join-Path $source 'deming.system.md')
        '$skillsPath' = (Join-Path $source 'skills')
        '$startMarker' = '<!-- deming:start -->'
        '$endMarker' = '<!-- deming:end -->'
    }
    foreach ($key in $paths.Keys) { $block = $block.Replace($key, $paths[$key]) }
    [IO.File]::WriteAllText((Join-Path $config 'APPEND_SYSTEM.md'), $block, $utf8)
    [IO.File]::WriteAllText((Join-Path $config 'settings.json'), '{"enableInstallTelemetry":false}', $utf8)
    $prompt = 'Hey Deming, I want to start a new project where we build an ADR management tool and UI. It should be a very simple CRUD app. A single-user browser-local prototype is the intended first slice. You may initialize local Git and make local commits. This is an unattended local trial: no remote fetch, push, PR, package installation, or global instruction changes. You may inspect installed tools and use isolated browser profiles for local testing. Follow your normal workflow; report blockers rather than inventing evidence.'
    [IO.File]::WriteAllText((Join-Path $EvidenceDir 'prompt.txt'), $prompt, $utf8)
    $files = @('SOUL.md', 'deming.system.md', 'install.ps1', 'scripts/check-update.ps1', 'scripts/start-cycle.ps1')
    $files += @(Get-ChildItem (Join-Path $source 'skills') -Recurse -Filter '*.md' | ForEach-Object FullName)
    $files += @(Get-ChildItem (Join-Path $source 'templates') -Filter '*.md' | ForEach-Object FullName)
    $files | ForEach-Object {
        $path = if ([IO.Path]::IsPathRooted($_)) { $_ } else { Join-Path $source $_ }
        Get-FileHash $path -Algorithm SHA256
    } | ConvertTo-Json | Set-Content (Join-Path $EvidenceDir 'candidate-hashes.json') -Encoding UTF8
    $env:PI_CODING_AGENT_DIR = $config
    $arguments = @('-p', '--mode', 'json', '--offline', '--provider', $Provider, '--model', $Model, '--thinking', 'xhigh',
        '--no-extensions', '--no-context-files', '--no-prompt-templates', '--no-themes', '--no-skills',
        '--skill', (Join-Path $source 'skills'), '--tools', 'read,bash,edit,write',
        '--session-dir', (Join-Path $EvidenceDir 'sessions'))
    $ponytail = Join-Path $HOME '.agents\skills\ponytail'
    if (Test-Path $ponytail) { $arguments += @('--skill', $ponytail) }
    $arguments += $prompt
    $arguments | ConvertTo-Json | Set-Content (Join-Path $EvidenceDir 'arguments.json') -Encoding UTF8
    Push-Location $Repo
    try {
        & pi @arguments 2> (Join-Path $EvidenceDir 'stderr.log') | Out-File (Join-Path $EvidenceDir 'events.jsonl') -Encoding utf8
        if ($LASTEXITCODE -ne 0) { throw "Pi exited with $LASTEXITCODE. Inspect $EvidenceDir." }
    } finally { Pop-Location }
    Write-Host "Pi run finished. Study the session and target artifacts before declaring acceptance: $EvidenceDir"
} finally {
    $env:PI_CODING_AGENT_DIR = $oldConfig
    Remove-Item $config -Recurse -Force
}
