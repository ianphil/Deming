$ErrorActionPreference = "Stop"
$source = Split-Path $PSScriptRoot -Parent
$script:checks = 0

function Assert($condition, $message) {
    if (-not $condition) { throw $message }
    $script:checks++
}
$utf8 = New-Object System.Text.UTF8Encoding($false)
function Read-Utf8($path) {
    [IO.File]::ReadAllText((Join-Path $source $path), $utf8)
}
function Assert-Contains($text, $needle, $message) {
    Assert ($text.Contains($needle)) $message
}
function Assert-NotContains($text, $needle, $message) {
    Assert (-not $text.Contains($needle)) $message
}

$skillPath = Join-Path $source 'skills\spec\SKILL.md'
$templatePath = Join-Path $source 'templates\spec.md'
Assert (Test-Path $skillPath -PathType Leaf) 'Spec skill is missing'
Assert (Test-Path $templatePath -PathType Leaf) 'Spec template is missing'

$skill = Read-Utf8 'skills\spec\SKILL.md'
$template = Read-Utf8 'templates\spec.md'
$system = Read-Utf8 'deming.system.md'
$readme = Read-Utf8 'README.md'
$plan = Read-Utf8 'skills\plan\SKILL.md'

$frontmatter = ($skill -split "`r?`n", 8)[0..4] -join "`n"
Assert-Contains $frontmatter 'name: spec' 'Spec skill frontmatter has no name'
Assert-Contains $frontmatter 'description:' 'Spec skill frontmatter has no description'
Assert-NotContains $frontmatter 'disable-model-invocation: true' 'Spec skill must be model-reachable'
Assert-Contains $frontmatter 'spec session' 'Spec skill description lacks the explicit session trigger'
Assert-Contains $frontmatter 'implementation' 'Spec skill description lacks the implementation boundary'

$emDash = [char]0x2014
foreach ($term in @(
    'Entry and boundary',
    'Inspect context and separate facts from decisions',
    'Interview the decision tree in rounds',
    'frontier',
    'Draft early and hand off the file',
    'Revise from current disk state',
    'Confirm and stop',
    ('Draft ' + $emDash + ' collaboration in progress'),
    ('Agreed ' + $emDash + ' user confirmed'),
    'code',
    'specs/<name>.md'
)) {
    Assert-Contains $skill $term "Spec skill is missing required behavior: $term"
}

foreach ($heading in @(
    '# [Specification title]',
    '## Problem',
    '## Solution',
    '## Non-Goals / Constraints',
    '## Context / Inputs',
    '## Assumptions',
    '## Open Questions',
    '## Workflow',
    '## Deliverables',
    '## Acceptance and quality criteria',
    '## How You Are Graded',
    '## Definition of Done'
)) {
    Assert-Contains $template $heading "Spec template is missing required section: $heading"
}

foreach ($term in @(
    ('Draft ' + $emDash + ' collaboration in progress'),
    'Status:** Undecided',
    'Direct implementation:',
    'PDSA implementation:',
    'Weight:',
    'Full credit:',
    'Partial credit:',
    'Hard fail:',
    'user-provided weight, or Not weighted',
    'Do not invent weights',
    'Remove it when grading is not part of the work'
)) {
    Assert-Contains $template $term "Spec template is missing rubric/status guidance: $term"
}

foreach ($forbidden in @('{{', '}}', '/planf3', 'Skill tool', 'grill-me', 'grilling')) {
    Assert-NotContains $skill $forbidden "Spec skill contains forbidden dependency or unresolved token: $forbidden"
    Assert-NotContains $template $forbidden "Spec template contains forbidden dependency or unresolved token: $forbidden"
}

foreach ($emptyCategory in @('### Workflow', '### Tool', '### UI', '### Prompt Engineering', '### Command')) {
    Assert-NotContains $template $emptyCategory "Spec template retains an empty source deliverable category: $emptyCategory"
}

Assert-Contains $system '## Spec sessions' 'System contract does not route Spec sessions'
Assert-Contains $system 'does not authorize implementation' 'System contract omits the Spec authorization boundary'
Assert-Contains $readme '## Spec sessions' 'README does not document Spec sessions'
Assert-Contains $readme 'templates/spec.md' 'README does not name the local Spec template'
Assert-Contains $plan 'For an agreed Spec draft' 'Plan skill does not describe agreed Spec input'
Assert-Contains $plan 'A draft under discussion or a request to review a spec is not an implementation request' 'Plan skill blurs draft review and implementation'

# Resolve actual Markdown references from the skill, not the target project.
$links = [regex]::Matches($skill, '\]\(([^)]+)\)')
Assert ($links.Count -ge 2) 'Spec skill lacks local template/source links'
foreach ($match in $links) {
    $relative = $match.Groups[1].Value.Split('#')[0]
    Assert (-not ($relative -match '^(https?:|[A-Za-z]:)')) 'Runtime reference must be local and portable'
    $resolved = [IO.Path]::GetFullPath((Join-Path (Split-Path $skillPath -Parent) $relative))
    Assert (Test-Path -LiteralPath $resolved -PathType Leaf) "Missing skill-relative reference: $relative"
}
Assert-Contains $skill '../../templates/spec.md' 'Spec must resolve the template from its installation'
Assert-Contains $system 'read any supplied or named task spec before deciding' 'Workflow choice must inspect the spec first'
Assert-Contains $system 'Reuse a user-selected Direct or PDSA workflow' 'Workflow gate must reuse either selected workflow'
Assert-Contains $system 'review-only or discussion-only request stays read-only' 'Review-only must not authorize edits'
Assert-Contains $skill 'launch fails' 'Editor launch failure must have a fallback'
Assert-Contains $skill 'explicitly deferred by the user' 'The agent cannot self-defer material requirements'
Assert-Contains $template 'decision source' 'Workflow selection must retain provenance'
Assert-Contains $template "Deming's integrated Plan" 'PDSA must use the integrated Plan'
Assert-Contains $template 'Variables section only for genuine reusable variables' 'Reusable variables need conditional guidance'

# Directory discovery is intentionally path-based; the installer must not enumerate a fixed skill count.
$installer = Read-Utf8 'install.ps1'
Assert-Contains $installer '$skillsPath' 'Installer does not use the skills directory path'
Assert-NotContains $installer 'skills.Count' 'Installer hard-codes a skill count'
Assert-NotContains $installer 'skills.Length' 'Installer hard-codes a skill length'

Write-Host "PASS: $script:checks static document checks on PowerShell $($PSVersionTable.PSVersion). Live behavior is evaluated separately."
