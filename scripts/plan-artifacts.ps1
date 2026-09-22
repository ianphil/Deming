[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Plan', 'Diagram', 'Export')]
    [string]$Mode,
    [Parameter(Mandatory = $true)]
    [string]$Path,
    [string]$OutputPath,
    [switch]$Completed
)

# Structural checks for authored, XML-compatible HTML; not a browser layout test
# or a sanitizer for untrusted documents. No network or third-party dependencies.
$ErrorActionPreference = 'Stop'
$utf8 = New-Object System.Text.UTF8Encoding($false)
function Require($condition, [string]$message) {
    if (-not $condition) { throw $message }
}
function Read-Document([string]$file) {
    $text = [IO.File]::ReadAllText($file)
    Require ($text -notmatch '(?s)\{\{.*?\}\}|<!--\s*repeat\b') "Unfilled scaffold: $file"
    $settings = New-Object System.Xml.XmlReaderSettings
    $settings.DtdProcessing = [System.Xml.DtdProcessing]::Ignore
    $settings.XmlResolver = $null
    $reader = [System.Xml.XmlReader]::Create((New-Object IO.StringReader($text)), $settings)
    $doc = New-Object System.Xml.XmlDocument
    $doc.XmlResolver = $null
    try { $doc.Load($reader) } finally { $reader.Dispose() }
    $ids = @{}
    foreach ($element in $doc.SelectNodes('//*')) {
        $id = $element.GetAttribute('id')
        if ($id) {
            Require (-not $ids.ContainsKey($id)) "Duplicate ID '$id' in $file"
            $ids[$id] = $true
        }
        Require ($element.LocalName -notin @('script', 'iframe', 'object', 'embed', 'foreignObject', 'base', 'animate', 'animateMotion', 'animateTransform', 'set')) "Non-static element in $file"
        foreach ($attribute in $element.Attributes) {
            Require ($attribute.Name -notmatch '^on') "Executable attribute in $file"
            if ($attribute.LocalName -in @('href', 'src')) {
                Require ($attribute.Value -notmatch '^\s*(javascript|data|vbscript):') "Executable URL in $file"
            }
        }
    }
    return ,$doc
}
function Check-Html([System.Xml.XmlDocument]$doc) {
    Require ($doc.DocumentElement.LocalName -eq 'html') 'Expected an HTML source document'
    Require ($doc.DocumentElement.GetAttribute('lang')) 'HTML needs a language'
    Require ($null -ne $doc.SelectSingleNode('/html/head/meta[@charset="UTF-8"]')) 'HTML needs UTF-8 metadata'
    Require ($doc.SelectNodes('/html/head/style').Count -eq 1) 'Keep HTML CSS in one head style block'
    Require ($doc.SelectNodes('//style').Count -eq 1) 'Unexpected additional style block'
    Require ($doc.SelectNodes('//*[@style]').Count -eq 0) 'Keep HTML styling in the head style block; use SVG presentation attributes'
    Require ($doc.SelectNodes('//link').Count -eq 0) 'Use local font fallbacks; external stylesheets are not self-contained'
}
function Check-Svg([System.Xml.XmlDocument]$doc) {
    $svgs = $doc.SelectNodes('//*[local-name()="svg"]')
    Require ($svgs.Count -eq 1) 'A diagram source/asset must contain exactly one SVG'
    $svg = $svgs[0]
    Require ($svg.NamespaceURI -eq 'http://www.w3.org/2000/svg') 'Declare the SVG namespace explicitly'
    $box = $svg.GetAttribute('viewBox') -split '[\s,]+'
    Require ($box.Count -eq 4) 'SVG needs a four-number viewBox'
    $numbers = @()
    foreach ($value in $box) {
        $number = 0.0
        Require ([double]::TryParse($value, [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$number)) 'Invalid viewBox number'
        Require (-not [double]::IsNaN($number) -and -not [double]::IsInfinity($number)) 'Non-finite viewBox number'
        $numbers += $number
    }
    Require ($numbers[2] -gt 0 -and $numbers[3] -gt 0) 'SVG dimensions must be positive'
    Require ($svg.GetAttribute('role') -eq 'img') 'SVG needs role="img"'
    $children = @($svg.ChildNodes | Where-Object { $_ -is [System.Xml.XmlElement] })
    Require ($children.Count -ge 2 -and $children[0].LocalName -eq 'title') 'SVG title must be its first element'
    $title = $svg.SelectSingleNode('./*[local-name()="title"]')
    $desc = $svg.SelectSingleNode('./*[local-name()="desc"]')
    Require ($null -ne $desc) 'SVG needs a description'
    Require ($title.InnerText.Trim() -and $desc.InnerText.Trim()) 'SVG title/description must be meaningful text'
    $titleId = $title.GetAttribute('id'); $descId = $desc.GetAttribute('id')
    Require ($titleId -match '^.+-title$' -and $descId -match '^.+-desc$') 'Prefix accessible IDs with the diagram slug'
    Require ($titleId.Substring(0, $titleId.Length - 6) -eq $descId.Substring(0, $descId.Length - 5)) 'Accessible ID prefixes must match'
    $labels = $svg.GetAttribute('aria-labelledby') -split '\s+'
    Require ($labels.Count -eq 2 -and $labels -contains $titleId -and $labels -contains $descId) 'aria-labelledby must resolve to title and description'
    foreach ($node in $svg.SelectNodes('.//*')) {
        foreach ($attr in $node.Attributes) {
            if ($attr.LocalName -in @('href', 'src')) { Require ($attr.Value.StartsWith('#')) 'SVG assets must be self-contained' }
            if ($attr.LocalName -in @('fill', 'stroke')) {
                Require ($attr.Value -notmatch 'rgba\(|transparent|var\(') 'Use explicit SVG colors and separate opacity attributes'
            }
            foreach ($match in [regex]::Matches($attr.Value, 'url\(#([^)]+)\)')) {
                $target = $match.Groups[1].Value
                Require (@($svg.SelectNodes('.//*[@id]') | Where-Object { $_.GetAttribute('id') -ceq $target }).Count -eq 1) "Unresolved SVG reference: $target"
            }
        }
    }
    return ,$svg
}

$Path = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
$document = Read-Document $Path
if ($Mode -in @('Diagram', 'Export')) {
    Check-Html $document
    $svg = Check-Svg $document
    if ($Mode -eq 'Export') {
        Require (-not [string]::IsNullOrWhiteSpace($OutputPath)) 'Export needs -OutputPath'
        $destination = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputPath)
        Require ([IO.Path]::GetExtension($destination) -eq '.svg') 'Export destination must be .svg'
        Require ($destination -ne $Path) 'Keep the HTML source'
        $temp = "$destination.$([guid]::NewGuid()).tmp"
        try {
            [IO.File]::WriteAllText($temp, ('<?xml version="1.0" encoding="UTF-8"?>' + "`n" + $svg.OuterXml), $utf8)
            if (Test-Path -LiteralPath $destination) { [IO.File]::Replace($temp, $destination, [System.Management.Automation.Language.NullString]::Value) }
            else { [IO.File]::Move($temp, $destination) }
        } finally { if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp } }
    }
} else {
    Check-Html $document
    foreach ($id in @('plan-status', 'created', 'modified', 'commits', 'agent', 'session', 'back-refs', 'forward-refs', 'purpose', 'problem', 'solution', 'prediction', 'scope', 'provenance', 'files', 'acceptance', 'phases', 'validation', 'notes', 'amendments', 'handoff')) {
        $node = $document.SelectSingleNode("//*[@id='$id']")
        Require ($null -ne $node) "Plan missing #$id"
        if ($id -ne 'amendments') { Require ($node.InnerText.Trim()) "Plan has empty #$id" }
    }
    $status = $document.SelectSingleNode('//*[@id="plan-status"]').InnerText.Trim()
    Require ($status -in @('Status: ready', 'Status: executed')) 'Plan must explicitly be ready or executed'
    $phases = $document.SelectNodes('//*[@id="phases"]//*[@class="phase"]')
    Require ($phases.Count -gt 0) 'Plan needs implementation phases'
    foreach ($phase in $phases) {
        Require ($phase.GetAttribute('id')) 'Each phase needs a stable ID'
        Require ($phase.SelectNodes('.//code[@class="status"]').Count -ge 3) 'Phase needs phase, task, and test status markers'
    }
    Require ($document.SelectNodes('//*[@id="validation"]//code[@class="status"]').Count -gt 0) 'Global validation needs status markers'
    foreach ($marker in $document.SelectNodes('//code[@class="status"]')) {
        Require ($marker.InnerText -in @('[]', '[wip]', '[x]', '[f]')) 'Unknown task status marker'
        if ($Completed) { Require ($marker.InnerText -eq '[x]') 'Required checklist is not complete' }
    }
    $root = Split-Path $Path -Parent
    foreach ($image in $document.SelectNodes('//img')) {
        Require ($image.GetAttribute('alt').Trim()) 'Plan images need descriptive alt text'
        $src = $image.GetAttribute('src')
        Require ($src -match '^diagrams/[a-z0-9]+(?:-[a-z0-9]+)*\.svg$') 'Plan images must be local diagrams/slug.svg assets'
        $assetPath = Join-Path $root $src
        $sourcePath = [IO.Path]::ChangeExtension($assetPath, '.html')
        $source = Read-Document $sourcePath
        Check-Html $source
        $sourceSvg = Check-Svg $source
        $asset = Read-Document $assetPath
        Require ($asset.DocumentElement.LocalName -eq 'svg') 'Expected a standalone SVG asset'
        $assetSvg = Check-Svg $asset
        Require ($sourceSvg.OuterXml -ceq $assetSvg.OuterXml) "Stale SVG; re-export $sourcePath"
    }
}
Write-Host "PASS: $Mode structural checks for $Path. Browser geometry and semantic review remain separate."
