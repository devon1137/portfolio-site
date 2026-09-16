# Writes sitemap.xml for the site: every top-level page (except 404 and the
# noindex agreement and questionnaire pages) plus the case studies under /work/<slug>/.
# lastmod comes from each file's modified time. Also makes sure robots.txt
# advertises the sitemap.
#   .\tools\build-sitemap.ps1 -Origin https://example.com
param(
  [string]$Origin = '',   # e.g. https://devonkubacki.com — needed for sitemap.xml; sitemap.html builds without it
  [string]$Root = (Split-Path $PSScriptRoot -Parent)
)
$ErrorActionPreference = 'Stop'
$Origin = $Origin.TrimEnd('/')
$utf8 = New-Object Text.UTF8Encoding $false
$skip = @('404.html', 'agreement.html', 'questionnaire.html', 'sitemap.html')

# Page list: relative path, title (from <title>, minus the site suffix), group.
$pages = New-Object System.Collections.Generic.List[object]
$topOrder = @('index.html', 'about.html', 'projects.html', 'writing.html', 'services.html', 'gallery.html', 'contact.html', 'privacy.html', 'terms.html')
$titleOf = { param($path) ([regex]::Match([IO.File]::ReadAllText($path), '<title>(.*?)</title>').Groups[1].Value -replace '\s*—\s*Devon Kubacki\s*$', '') }
foreach ($name in $topOrder) {
  $f = Join-Path $Root $name
  if (-not (Test-Path $f) -or $name -in $skip) { continue }
  $t = & $titleOf $f; if ($name -eq 'index.html') { $t = 'Home' }
  $pri = switch ($name) { 'index.html' { '1.0' } 'projects.html' { '0.9' } 'writing.html' { '0.8' } 'services.html' { '0.8' } 'privacy.html' { '0.3' } 'terms.html' { '0.3' } default { '0.6' } }
  $pages.Add([pscustomobject]@{ rel = $(if ($name -eq 'index.html') { '' } else { $name }); title = $t; group = 'Pages'; lastmod = (Get-Item $f).LastWriteTimeUtc.ToString('yyyy-MM-dd'); priority = $pri })
}
foreach ($f in Get-ChildItem (Join-Path $Root '*.html') | Where-Object { $_.Name -notin $skip -and $_.Name -notin $topOrder } | Sort-Object Name) {
  $pages.Add([pscustomobject]@{ rel = $f.Name; title = (& $titleOf $f.FullName); group = 'Pages'; lastmod = $f.LastWriteTimeUtc.ToString('yyyy-MM-dd'); priority = '0.5' })
}
# Case studies in build-work order
$order = @(Get-Content (Join-Path $PSScriptRoot 'work-order.txt') | Where-Object { $_.Trim() } | ForEach-Object { $_.Trim() })   # one slug per line: the case-study order, used by every tool
$dirs = @($order | Where-Object { Test-Path (Join-Path $Root "work\$_\index.html") }) + @(Get-ChildItem (Join-Path $Root 'work') -Directory | Where-Object { $_.Name -notin $order } | Select-Object -ExpandProperty Name)
foreach ($slug in $dirs) {
  $idx = Join-Path $Root "work\$slug\index.html"
  $t = (& $titleOf $idx) -replace '\s*—\s*Case Study\s*$', ''
  $pages.Add([pscustomobject]@{ rel = "work/$slug/"; title = $t; group = 'Case studies'; lastmod = (Get-Item $idx).LastWriteTimeUtc.ToString('yyyy-MM-dd'); priority = '0.8' })
}
# Writing samples in build-writing order
$wOrderFile = Join-Path $PSScriptRoot 'writing-order.txt'
$wOrder = if (Test-Path $wOrderFile) { @(Get-Content $wOrderFile | Where-Object { $_.Trim() } | ForEach-Object { $_.Trim() }) } else { @() }
foreach ($slug in $wOrder) {
  $idx = Join-Path $Root "writing\$slug\index.html"
  if (-not (Test-Path $idx)) { continue }
  $t = (& $titleOf $idx) -replace '\s*—\s*Writing\s*$', ''
  $pages.Add([pscustomobject]@{ rel = "writing/$slug/"; title = $t; group = 'Writing'; lastmod = (Get-Item $idx).LastWriteTimeUtc.ToString('yyyy-MM-dd'); priority = '0.7' })
}

# ---- sitemap.html (human-readable; relative links, so no origin needed) ----
$tpl = [IO.File]::ReadAllText((Join-Path $Root 'privacy.html'))   # borrow the chrome from a simple page
$groups = $pages | Group-Object group
$lists = foreach ($g in $groups) {
  $items = ($g.Group | ForEach-Object { "          <li><a href=`"$(if ($_.rel) { $_.rel } else { 'index.html' })`">$([Net.WebUtility]::HtmlEncode($_.title))</a></li>" }) -join "`n"
  "        <li><a href=`"#$($g.Name.ToLower() -replace '\s','-')`">$($g.Name)</a>`n          <ol>`n$items`n          </ol>`n        </li>"
}
$body = @"
  <section class="page-intro grid-bg">
    <div class="hex-blinks" aria-hidden="true"></div>
    <div class="wrap">
      <h1>Sitemap.</h1>
      <p>Every page on this site, in one list. The XML version for search engines is at <a href="sitemap.xml">sitemap.xml</a>.</p>
    </div>
  </section>

  <section class="band">
    <div class="wrap">
      <nav class="toc" aria-label="All pages">
        <span class="toc-title eyebrow">All pages</span>
        <ol>
$($lists -join "`n")
        </ol>
      </nav>
    </div>
  </section>
"@
$html = $tpl
$html = [regex]::Replace($html, '(?s)<title>.*?</title>', '<title>Sitemap — Devon Kubacki</title>', 1)
$html = [regex]::Replace($html, '<meta name="description" content="[^"]*">', '<meta name="description" content="Every page on Devon Kubacki&#39;s site, in one list.">', 1)
$html = [regex]::Replace($html, '<meta property="og:title" content="[^"]*">', '<meta property="og:title" content="Sitemap — Devon Kubacki">', 1)
$html = [regex]::Replace($html, '<meta property="og:description" content="[^"]*">', '<meta property="og:description" content="Every page on this site, in one list.">', 1)
$html = [regex]::Replace($html, '(?s)<main id="main">.*?</main>', ('<main id="main">' + "`n" + ($body -replace '\$', '$$') + '</main>'), 1)
$html = $html.Replace('<body id="top" class="legal">', '<body id="top">')
$html = $html.Replace('/privacy.html"', '/sitemap.html"')   # the borrowed canonical / og:url (only present once site.json has an origin)
[IO.File]::WriteAllText((Join-Path $Root 'sitemap.html'), $html, $utf8)
"sitemap.html: $($pages.Count) pages"

if (-not $Origin) { "sitemap.xml skipped: pass -Origin https://your-domain to write it (and the robots.txt Sitemap line)"; return }

$entries = $pages | ForEach-Object { [pscustomobject]@{ loc = "$Origin/$($_.rel)"; lastmod = $_.lastmod; priority = $_.priority } }
$xml = New-Object System.Text.StringBuilder
# LF line endings, not AppendLine (CRLF on Windows), so git and the repo stay consistent
[void]$xml.Append('<?xml version="1.0" encoding="UTF-8"?>').Append("`n")
[void]$xml.Append('<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">').Append("`n")
foreach ($e in $entries) {
  [void]$xml.Append("  <url><loc>$([Security.SecurityElement]::Escape($e.loc))</loc><lastmod>$($e.lastmod)</lastmod><priority>$($e.priority)</priority></url>").Append("`n")
}
[void]$xml.Append('</urlset>').Append("`n")
[IO.File]::WriteAllText((Join-Path $Root 'sitemap.xml'), $xml.ToString(), $utf8)

$robots = Join-Path $Root 'robots.txt'
$r = [IO.File]::ReadAllText($robots)
$line = "Sitemap: $Origin/sitemap.xml"
if ($r -match '(?m)^Sitemap:.*$') { $r = [regex]::Replace($r, '(?m)^Sitemap:.*$', $line) } else { $r = $r.TrimEnd() + "`n`n$line`n" }
[IO.File]::WriteAllText($robots, $r, $utf8)
"sitemap.xml: $($entries.Count) URLs; robots.txt updated"
