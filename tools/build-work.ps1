# Builds the case-study pages under /work/<slug>/index.html from the source
# fragments in tools/work-src/<slug>.html.
#
# A fragment is a JSON front-matter block followed by top-level <section>s:
#
#   <!--meta
#   { "slug": "...", "title": "...", "category": "Web development",
#     "dates": "2025–2026", "lede": "...", "description": "...",
#     "role": "...", "timeline": "...", "stack": ["WordPress", "..."],
#     "links": [{ "label": "thenortheastlandhotel.com", "url": "https://...", "archived": false }] }
#   link flags: "archived": true -> Wayback title; "affiliate": true -> rel="sponsored" + disclosure title (label should say "(affiliate link)")
#   -->
#   <section id="overview" data-title="Overview"> <h2>Overview</h2> ... </section>
#
# Write image paths site-relative (images/x.webp) like every other page; this
# script rewrites them for the /work/<slug>/ depth. Sections become alternating
# bands; the on-page TOC is built from data-title (or the h2). Page order (for
# prev/next) is the $order list below.
param([string]$Root = (Split-Path $PSScriptRoot -Parent))
$ErrorActionPreference = 'Stop'
$srcDir = Join-Path $PSScriptRoot 'work-src'
$order = @(Get-Content (Join-Path $PSScriptRoot 'work-order.txt') | Where-Object { $_.Trim() } | ForEach-Object { $_.Trim() })   # one slug per line: the case-study order, used by every tool
$utf8 = New-Object Text.UTF8Encoding $false

function Read-Fragment([string]$path) {
  $raw = [IO.File]::ReadAllText($path)
  $m = [regex]::Match($raw, '(?s)<!--meta\s*(\{.*?\})\s*-->')
  if (-not $m.Success) { throw "No meta block in $path" }
  $meta = $m.Groups[1].Value | ConvertFrom-Json
  $body = $raw.Substring($m.Index + $m.Length).Trim()
  [pscustomobject]@{ meta = $meta; body = $body; path = $path }
}

$frags = @{}
foreach ($f in Get-ChildItem $srcDir -Filter *.html) { $fr = Read-Fragment $f.FullName; $frags[$fr.meta.slug] = $fr }
foreach ($slug in $order) { if (-not $frags.ContainsKey($slug)) { throw "Missing fragment for $slug" } }

$head = @'
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>{{TITLE}} — Case Study — Devon Kubacki</title>
<meta name="description" content="{{DESC}}">
<meta name="theme-color" content="#1B1F1D">
<meta property="og:type" content="article">
<meta property="og:title" content="{{TITLE}} — Case Study — Devon Kubacki">
<meta property="og:description" content="{{DESC}}">
<!--og--><!-- canonical + og:image: set "origin" in tools/site.json --><!--/og-->
<link rel="icon" href="data:image/svg+xml,<svg xmlns=%22http://www.w3.org/2000/svg%22 viewBox=%220 0 100 100%22><rect width=%22100%22 height=%22100%22 fill=%22%231B1F1D%22/><text x=%2250%22 y=%2268%22 font-size=%2260%22 text-anchor=%22middle%22 fill=%22%23D9A63E%22 font-family=%22Georgia,serif%22>D</text></svg>">
<link rel="stylesheet" href="../../css/style.css">
</head>
<body id="top" class="case">

<a class="skip-link" href="#main">Skip to content</a>

<!--header-->
<header class="site">
  <div class="wrap">
    <a class="wordmark" href="../../index.html">Devon<span>.</span>Kubacki</a>
    <button class="nav-toggle" aria-expanded="false" aria-controls="primary-nav">
      <span class="bars" aria-hidden="true"></span>
      <span>Menu</span>
    </button>
    <nav class="primary" id="primary-nav" aria-label="Primary">
      <a href="../../index.html">Home</a>
      <a href="../../about.html">About</a>
      <!--worksub--><div class="has-sub">
        <a href="../../projects.html" aria-current="page">Work</a>
        <button class="sub-toggle" type="button" aria-expanded="false" aria-controls="work-sub" aria-label="Show case studies"></button>
        <ul class="submenu" id="work-sub" aria-label="Case studies">
          <li class="sub-group"><span class="sub-label eyebrow">Featured Client Work</span>
            <ul>
            <li><a href="../../work/the-northeastland-hotel/">The Northeastland Hotel</a></li>
            <li><a href="../../work/ignitepi/">IgnitePI</a></li>
            <li><a href="../../work/the-law-offices-of-michael-s-lamonsoff/">The Law Offices of Michael S. Lamonsoff</a></li>
            <li><a href="../../work/brainandspinalcord/">BrainandSpinalCord.org</a></li>
            <li><a href="../../work/alpha-pressure-washing/">Alpha Pressure Washing</a></li>
            </ul>
          </li>
          <li class="sub-group"><span class="sub-label eyebrow">My Own Projects</span>
            <ul>
            <li><a href="../../work/streamershaven/">Streamershaven</a></li>
            <li><a href="../../work/notes-of-yore/">Notes of Yore</a></li>
            <li><a href="../../work/the-trail-of-tales/">The Trail of Tales</a></li>
            <li><a href="../../work/a-moon-of-cheese/">A Moon of Cheese</a></li>
            </ul>
          </li>
          <li class="all"><a href="../../projects.html">All work &rarr;</a></li>
        </ul>
      </div><!--/worksub-->
      <a href="../../services.html">Services</a>
      <a href="../../gallery.html">Gallery</a>
      <a href="../../contact.html">Contact</a>
    </nav>
  </div>
</header>
<!--/header-->

<main id="main">
  <section class="page-intro grid-bg">
    <div class="hex-blinks" aria-hidden="true"></div>
    <div class="wrap">
      <p class="eyebrow">Case study &middot; {{CATEGORY}} &middot; {{DATES}}</p>
      <h1>{{TITLE}}</h1>
      <p>{{LEDE}}</p>
    </div>
  </section>

  <section class="band" id="facts">
    <div class="wrap">
      <dl class="case-facts">
        <div><dt>Role</dt><dd>{{ROLE}}</dd></div>
        <div><dt>Timeline</dt><dd>{{TIMELINE}}</dd></div>
        <div><dt>Stack</dt><dd><ul class="tags" aria-label="Stack">{{STACK}}</ul></dd></div>
{{LINKS_DIV}}
      </dl>
      <nav class="toc toc-flat" aria-label="On this page" style="margin-top: var(--space-xl)">
        <span class="toc-title eyebrow">On this page</span>
        <ol>
{{TOC}}
        </ol>
      </nav>
    </div>
  </section>

'@

$tail = @'
  <section class="band">
    <div class="wrap">
      <nav class="case-nav" aria-label="More case studies">
{{PREV}}
        <a class="link-arrow" href="../../projects.html" style="align-self:center">All work</a>
{{NEXT}}
      </nav>
    </div>
  </section>
</main>

<!--footer-->
<footer class="site">
  <div class="wrap footer-grid">
    <div>
      <a class="wordmark" href="../../index.html">Devon<span>.</span>Kubacki</a>
      <p>Web, content, and sales. Built by hand in Presque Isle, Maine.</p>
    </div>
    <nav aria-label="Site">
      <span class="footer-label">Site</span>
      <a href="../../privacy.html">Privacy Policy</a>
      <a href="../../terms.html">Terms of Service</a>
      <a href="../../sitemap.html">Sitemap</a>
    </nav>
    <div>
      <span class="footer-label">Reach out</span>
      <a href="mailto:devon.kubacki@gmail.com">devon.kubacki@gmail.com</a>
      <div class="social-links">
        <a href="https://github.com/devon1137" target="_blank" rel="noopener" title="GitHub: devon1137 (new tab)"><svg viewBox="0 0 16 16" aria-hidden="true" focusable="false"><path d="M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27.68 0 1.36.09 2 .27 1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.013 8.013 0 0 0 16 8c0-4.42-3.58-8-8-8z"/></svg><span class="visually-hidden">GitHub</span></a>
        <a href="https://www.linkedin.com/in/devon-kubacki" target="_blank" rel="noopener" title="LinkedIn: devon-kubacki (new tab)"><svg viewBox="0 0 24 24" aria-hidden="true" focusable="false"><path d="M20.447 20.452h-3.554v-5.569c0-1.328-.027-3.037-1.852-3.037-1.853 0-2.136 1.445-2.136 2.939v5.667H9.351V9h3.414v1.561h.046c.477-.9 1.637-1.85 3.37-1.85 3.601 0 4.267 2.37 4.267 5.455v6.286zM5.337 7.433c-1.144 0-2.063-.926-2.063-2.065 0-1.138.92-2.063 2.063-2.063 1.14 0 2.064.925 2.064 2.063 0 1.139-.925 2.065-2.064 2.065zm1.782 13.019H3.555V9h3.564v11.452zM22.225 0H1.771C.792 0 0 .774 0 1.729v20.542C0 23.227.792 24 1.771 24h20.451C23.2 24 24 23.227 24 22.271V1.729C24 .774 23.2 0 22.222 0h.003z"/></svg><span class="visually-hidden">LinkedIn</span></a>
      </div>
    </div>
  </div>
  <div class="wrap footer-bottom">
    <span>© 2026 Devon Kubacki</span>
    <a href="#top">Back to top ↑</a>
  </div>
</footer>
<!--/footer-->

<dialog class="lightbox" aria-label="Full-size screenshot">
  <div class="stage">
    <img alt="">
  </div>
  <button class="lb-nav lb-prev" type="button" aria-label="Previous image">&#8249;</button>
  <button class="lb-nav lb-next" type="button" aria-label="Next image">&#8250;</button>
  <p class="lb-caption" aria-live="polite"></p>
  <button class="close" type="button">Close &#10005;</button>
</dialog>
<script src="../../js/script.js"></script>
</body>
</html>
'@

function Html([string]$s) { [Net.WebUtility]::HtmlEncode($s) }

$built = 0
for ($i = 0; $i -lt $order.Count; $i++) {
  $fr = $frags[$order[$i]]; $m = $fr.meta
  $prev = if ($i -gt 0) { $frags[$order[$i - 1]].meta } else { $null }
  $next = if ($i -lt $order.Count - 1) { $frags[$order[$i + 1]].meta } else { $null }

  # Sections -> alternating bands (the facts band is ink, so start on slate).
  $secRx = [regex]'(?s)<section\s+id="(?<id>[^"]+)"(?:\s+data-title="(?<t>[^"]*)")?\s*>(?<inner>.*?)</section>'
  $sections = $secRx.Matches($fr.body)
  if ($sections.Count -eq 0) { throw "No sections in $($fr.path)" }
  $bands = New-Object System.Collections.Generic.List[string]
  $toc = New-Object System.Collections.Generic.List[string]
  $k = 0
  foreach ($s in $sections) {
    $id = $s.Groups['id'].Value
    $title = $s.Groups['t'].Value
    if (-not $title) { $title = [regex]::Match($s.Groups['inner'].Value, '<h2>(.*?)</h2>').Groups[1].Value -replace '<[^>]+>', '' }
    $cls = if ($k % 2 -eq 0) { 'band on-slate grid-bg' } else { 'band' }
    $inner = $s.Groups['inner'].Value.Trim()
    $bands.Add("  <section class=`"$cls`" id=`"$id`">`n    <div class=`"wrap`">`n$inner`n    </div>`n  </section>`n")
    $toc.Add("          <li><a href=`"#$id`">$title</a></li>")
    $k++
  }

  $stack = ($m.stack | ForEach-Object { "<li>$(Html $_)</li>" }) -join ''
  $links = ($m.links | ForEach-Object {
    $lbl = if ($_.archived) { 'Open the archived page on the Wayback Machine (new tab)' } elseif ($_.affiliate) { 'Affiliate link: as an Amazon Associate I earn from qualifying purchases (new tab)' } else { 'Open on the live site (new tab)' }
    $rel = if ($_.affiliate) { 'sponsored noopener' } else { 'noopener' }
    "<a class=`"link-arrow`" href=`"$($_.url)`" target=`"_blank`" rel=`"$rel`" title=`"$lbl`">$(Html $_.label) <span class=`"arrow`" aria-hidden=`"true`">&#8599;</span></a>"
  }) -join '<br>'
  $archivedN = @($m.links | Where-Object { $_.archived }).Count
  $linksLabel = if ($m.links.Count -gt 0 -and $archivedN -eq $m.links.Count) { 'Archived at' } elseif ($archivedN -gt 0 -or $m.links.Count -gt 1) { 'Links' } else { 'Live site' }

  $prevHtml = if ($prev) { "        <a class=`"prev`" href=`"../$($prev.slug)/`"><span class=`"eyebrow`">&larr; Previous</span><span class=`"case-nav-title`">$(Html $prev.title)</span></a>" } else { '        <span></span>' }
  $nextHtml = if ($next) { "        <a class=`"next`" href=`"../$($next.slug)/`"><span class=`"eyebrow`">Next &rarr;</span><span class=`"case-nav-title`">$(Html $next.title)</span></a>" } else { '        <span></span>' }

  $page = $head + ($bands -join "`n") + "`n" + $tail
  $map = @{
    '{{TITLE}}' = (Html $m.title); '{{DESC}}' = (Html $m.description); '{{SLUG}}' = $m.slug; '{{OG}}' = $m.og
    '{{CATEGORY}}' = (Html $m.category); '{{DATES}}' = (Html $m.dates); '{{LEDE}}' = $m.lede
    '{{ROLE}}' = $m.role; '{{TIMELINE}}' = (Html $m.timeline); '{{STACK}}' = $stack
    '{{LINKS_DIV}}' = $(if ($m.links.Count -gt 0) { "        <div><dt>$linksLabel</dt><dd>$links</dd></div>" } else { '' }); '{{TOC}}' = ($toc -join "`n")
    '{{PREV}}' = $prevHtml; '{{NEXT}}' = $nextHtml
  }
  foreach ($kv in $map.GetEnumerator()) { $page = $page.Replace($kv.Key, [string]$kv.Value) }
  # Site-relative asset paths -> two levels up.
  $page = [regex]::Replace($page, '(?<=["\s,])images/', '../../images/')
  # This page's own entry in the Work submenu.
  $page = $page.Replace("<a href=`"../../work/$($m.slug)/`">", "<a href=`"../../work/$($m.slug)/`" aria-current=`"page`">")

  $dir = Join-Path $Root ("work\" + $m.slug)
  New-Item -ItemType Directory -Force $dir | Out-Null
  [IO.File]::WriteAllText((Join-Path $dir 'index.html'), $page, $utf8)
  $built++
  "built work/$($m.slug)/index.html  ($($sections.Count) sections)"
}
"pages: $built"
