# Writes sitemap.xml for the site: every top-level page (except 404 and the
# noindex agreement page) plus the case studies under /work/<slug>/.
# lastmod comes from each file's modified time. Also makes sure robots.txt
# advertises the sitemap.
#   .\tools\build-sitemap.ps1 -Origin https://example.com
param(
  [Parameter(Mandatory = $true)][string]$Origin,   # e.g. https://devonkubacki.com (no trailing slash)
  [string]$Root = (Split-Path $PSScriptRoot -Parent)
)
$ErrorActionPreference = 'Stop'
$Origin = $Origin.TrimEnd('/')
$utf8 = New-Object Text.UTF8Encoding $false
$skip = @('404.html', 'agreement.html')

$entries = New-Object System.Collections.Generic.List[object]
foreach ($f in Get-ChildItem (Join-Path $Root '*.html') | Where-Object { $_.Name -notin $skip } | Sort-Object Name) {
  $loc = if ($f.Name -eq 'index.html') { "$Origin/" } else { "$Origin/$($f.Name)" }
  $pri = switch ($f.Name) { 'index.html' { '1.0' } 'projects.html' { '0.9' } 'services.html' { '0.8' } default { '0.6' } }
  $entries.Add([pscustomobject]@{ loc = $loc; lastmod = $f.LastWriteTimeUtc.ToString('yyyy-MM-dd'); priority = $pri })
}
foreach ($d in Get-ChildItem (Join-Path $Root 'work') -Directory | Sort-Object Name) {
  $idx = Join-Path $d.FullName 'index.html'
  if (Test-Path $idx) {
    $entries.Add([pscustomobject]@{ loc = "$Origin/work/$($d.Name)/"; lastmod = (Get-Item $idx).LastWriteTimeUtc.ToString('yyyy-MM-dd'); priority = '0.8' })
  }
}

$xml = New-Object System.Text.StringBuilder
[void]$xml.AppendLine('<?xml version="1.0" encoding="UTF-8"?>')
[void]$xml.AppendLine('<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">')
foreach ($e in $entries) {
  [void]$xml.AppendLine("  <url><loc>$([Security.SecurityElement]::Escape($e.loc))</loc><lastmod>$($e.lastmod)</lastmod><priority>$($e.priority)</priority></url>")
}
[void]$xml.AppendLine('</urlset>')
[IO.File]::WriteAllText((Join-Path $Root 'sitemap.xml'), $xml.ToString(), $utf8)

$robots = Join-Path $Root 'robots.txt'
$r = [IO.File]::ReadAllText($robots)
$line = "Sitemap: $Origin/sitemap.xml"
if ($r -match '(?m)^Sitemap:.*$') { $r = [regex]::Replace($r, '(?m)^Sitemap:.*$', $line) } else { $r = $r.TrimEnd() + "`n`n$line`n" }
[IO.File]::WriteAllText($robots, $r, $utf8)
"sitemap.xml: $($entries.Count) URLs; robots.txt updated"
