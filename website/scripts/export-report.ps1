<#
export-report.ps1 - put a report folder's Markdown on the website's Comparison page, looking exactly like the styled preview.
  .\website\scripts\export-report.ps1                                   # reports\four-way-2026-11-23
  .\website\scripts\export-report.ps1 -Report reports\four-way-2027-01-10
What it does:
  1. renders REPORT.md and TEST-SUITES.md with GitHub's own Markdown renderer (gh api /markdown, mode gfm; needs gh logged in);
  2. makes relative links point at the files on GitHub (branch incremental-test) and heading ids plain (#1-summary);
  3. writes the HTML to website\frontend\src\data\reports\ (bundled at build time, so the site's CSP stays 'self' only);
  4. once: copies GitHub's Markdown stylesheet (github-markdown-css 5.5.1, MIT) into src\styles\, rewritten so it follows
     the site's light/dark toggle (data-theme) as well as the system setting.
Run it again after the report changes, then rebuild the site (scripts\publish.ps1 or scripts\test.ps1).
#>
param([string]$Report = 'reports\four-way-2026-11-23', [string]$Branch = 'incremental-test')
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$src = Join-Path $repo 'website\frontend\src'
$out = Join-Path $src 'data\reports'
New-Item -ItemType Directory -Force $out | Out-Null
$utf8 = [Text.UTF8Encoding]::new($false)
$base = [Uri]("https://github.com/andersoxie/xpact/blob/$Branch/" + (($Report -replace '\\', '/').Trim('/')) + '/')

foreach ($name in 'REPORT', 'TEST-SUITES') {
    $md = Join-Path $repo "$Report\$name.md"
    if (-not (Test-Path $md)) { Write-Warning "missing $md"; continue }
    $html = (& gh api -X POST /markdown -F "text=@$md" -f mode=gfm) -join "`n"
    if ($LASTEXITCODE -ne 0) { throw "gh api /markdown failed for $md (gh auth status?)" }
    # relative links -> the file on GitHub; in-page links keep working
    $html = [regex]::Replace($html, 'href="(?!https?:|#|mailto:)([^"]+)"', { param($m) 'href="' + [Uri]::new($base, $m.Groups[1].Value).AbsoluteUri + '"' })
    $html = $html -replace 'id="user-content-', 'id="'
    [IO.File]::WriteAllText((Join-Path $out "$name.html"), $html, $utf8)
    "wrote $out\$name.html ($($html.Length) chars)"
}

$css = Join-Path $src 'styles\github-markdown.css'
if (-not (Test-Path $css)) {
    $raw = (Invoke-WebRequest -UseBasicParsing 'https://cdnjs.cloudflare.com/ajax/libs/github-markdown-css/5.5.1/github-markdown.css').Content
    # the file starts with two @media blocks (dark, light) of colour variables; take their bodies
    $vars = [regex]::Matches($raw, '@media \(prefers-color-scheme: (dark|light)\) \{\s*\.markdown-body,\s*\[data-theme="\w+"\] \{(.*?)\n  \}\n\}', 'Singleline')
    if ($vars.Count -ne 2) { throw 'github-markdown.css layout changed: expected 2 theme blocks' }
    $dark = ($vars | Where-Object { $_.Groups[1].Value -eq 'dark' }).Groups[2].Value
    $light = ($vars | Where-Object { $_.Groups[1].Value -eq 'light' }).Groups[2].Value
    $rest = $raw.Substring($vars[1].Index + $vars[1].Length)
    $head = "/* github-markdown-css 5.5.1 (MIT, (c) Sindre Sorhus), copied by website/scripts/export-report.ps1.`n   Theme blocks rewritten to follow the site's data-theme toggle as well as the system setting. */`n"
    $themed = ".markdown-body {$light`n}`n@media (prefers-color-scheme: dark) {`n  :root:where(:not([data-theme=""light""])) .markdown-body {$dark`n  }`n}`n:root[data-theme=""dark""] .markdown-body {$dark`n}`n"
    [IO.File]::WriteAllText($css, $head + $themed + $rest, $utf8)
    "wrote $css"
}
