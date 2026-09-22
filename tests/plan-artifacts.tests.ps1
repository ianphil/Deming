$ErrorActionPreference = 'Stop'
$source = Split-Path $PSScriptRoot -Parent
$checker = Join-Path $source 'scripts\plan-artifacts.ps1'
$root = Join-Path ([IO.Path]::GetTempPath()) ('deming-plan-test-' + [guid]::NewGuid())
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
function Save($file, $text) { [IO.File]::WriteAllText($file, $text, $utf8) }
New-Item -ItemType Directory -Path (Join-Path $root 'diagrams') -Force | Out-Null
try {
    $planPath = Join-Path $root 'plan.html'
    $diagramPath = Join-Path $root 'diagrams\flow.html'
    $svgPath = Join-Path $root 'diagrams\flow.svg'
    $template = [IO.File]::ReadAllText((Join-Path $source 'templates\plan.html'))
    Save $planPath $template
    Assert-Fails { & $checker -Mode Plan -Path $planPath } 'Pending template passed readiness'
    # This synthetic fixture proves structure, not the quality of a generated plan.
    $plan = [regex]::Replace($template, '\{\{.*?\}\}', 'Recorded fixture value')
    $plan = [regex]::Replace($plan, '<!-- repeat:.*?-->', '')
    $plan = $plan.Replace('Status: pending', 'Status: ready')
    Save $planPath $plan
    & $checker -Mode Plan -Path $planPath
    Assert-Fails { & $checker -Mode Plan -Path $planPath -Completed } 'Idle tasks accepted as complete'
    Save $planPath ($plan.Replace('class="status">[]', 'class="status">[x]'))
    & $checker -Mode Plan -Path $planPath -Completed
    $script:checks += 2
    foreach ($badPlan in @(
        $plan.Replace('Status: ready', 'Status: pending'),
        $plan.Replace('id="prediction"', 'id="missing"'),
        $plan.Replace('class="status">[]', 'class="status">[skip]'),
        $plan.Replace('id="solution"', 'id="problem"'),
        $plan.Replace('Recorded fixture value', "{{unfilled`nvalue}}")
    )) {
        Save $planPath $badPlan
        Assert-Fails { & $checker -Mode Plan -Path $planPath } 'Malformed plan accepted'
    }
    $diagram = @'
<!DOCTYPE html>
<html lang="en"><head><meta charset="UTF-8" /><title>Flow</title><style>body { background:#f5f5f5; }</style></head><body>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 960 600" role="img" aria-labelledby="flow-title flow-desc">
<title id="flow-title">Plan to execution</title><desc id="flow-desc">Do follows the plan checklist.</desc>
<defs><marker id="arrow" markerWidth="8" markerHeight="6" refX="7" refY="3" orient="auto"><path d="M0 0 L8 3 L0 6 Z" fill="#4f5d75" /></marker></defs>
<path d="M240 200 H320" stroke="#4f5d75" marker-end="url(#arrow)" />
<rect x="80" y="160" width="160" height="80" fill="#f5f5f5" stroke="#2d3142" />
<rect x="320" y="160" width="160" height="80" fill="#f5f5f5" stroke="#2d3142" />
<text x="100" y="200" font-family="Geist,Arial,sans-serif" fill="#2d3142">Plan</text><text x="340" y="200" font-family="Geist,Arial,sans-serif" fill="#2d3142">Do</text>
</svg></body></html>
'@
    Save $diagramPath $diagram
    & $checker -Mode Diagram -Path $diagramPath
    & $checker -Mode Export -Path $diagramPath -OutputPath $svgPath
    Assert (Test-Path $svgPath) 'SVG was not exported'
    $exported = [IO.File]::ReadAllText($svgPath)
    $withImage = $plan.Replace('</main>', '<figure><img src="diagrams/flow.svg" alt="Do follows the plan" /><figcaption>Execution contract</figcaption></figure></main>')
    Save $planPath $withImage
    & $checker -Mode Plan -Path $planPath
    $script:checks++
    foreach ($badDiagram in @(
        $diagram.Replace('role="img"', 'role="none"'),
        $diagram.Replace('flow-desc', 'desc'),
        $diagram.Replace('viewBox="0 0 960 600"', 'viewBox="0 0 0 600"'),
        $diagram.Replace('viewBox="0 0 960 600"', 'viewBox="0 0 NaN 600"'),
        $diagram.Replace('flow-title flow-desc', 'flow-title missing-desc'),
        $diagram.Replace('<defs>', '<script>alert(1)</script><defs>'),
        $diagram.Replace('<rect x="80"', '<rect onclick="alert(1)" x="80"'),
        $diagram.Replace('#f5f5f5', 'rgba(1,2,3,0.1)'),
        $diagram.Replace('url(#arrow)', 'url(#missing)'),
        $diagram.Replace('</svg>', '<image href="https://example.invalid/pixel" /></svg>'),
        $diagram.Replace('</svg>', '<animate attributeName="x" /></svg>'),
        $diagram.Replace('width="160"', 'width=160')
    )) {
        Save $diagramPath $badDiagram
        Assert-Fails { & $checker -Mode Export -Path $diagramPath -OutputPath $svgPath } 'Invalid diagram exported'
        Assert ([IO.File]::ReadAllText($svgPath) -ceq $exported) 'Failed export damaged existing asset'
    }
    Save $diagramPath ($diagram.Replace('Do follows', 'Do executes'))
    Assert-Fails { & $checker -Mode Plan -Path $planPath } 'Stale SVG accepted'
    & $checker -Mode Export -Path $diagramPath -OutputPath $svgPath
    & $checker -Mode Plan -Path $planPath
    $script:checks++
    Save $planPath ($withImage.Replace('diagrams/flow.svg', '../outside.svg'))
    Assert-Fails { & $checker -Mode Plan -Path $planPath } 'External asset accepted'
    Save $planPath ($withImage.Replace(' alt="Do follows the plan"', ''))
    Assert-Fails { & $checker -Mode Plan -Path $planPath } 'Missing alt accepted'
    Save $planPath $withImage
    Remove-Item $svgPath
    Assert-Fails { & $checker -Mode Plan -Path $planPath } 'Missing SVG accepted'
    & $checker -Mode Export -Path $diagramPath -OutputPath $svgPath
    Remove-Item $diagramPath
    Assert-Fails { & $checker -Mode Plan -Path $planPath } 'Missing diagram source accepted'
    Write-Host "PASS: $script:checks checks on PowerShell $($PSVersionTable.PSVersion)."
} finally { Remove-Item $root -Recurse -Force }
