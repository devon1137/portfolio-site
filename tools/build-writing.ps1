# Builds the writing samples under /writing/<slug>/index.html from
# tools/writing-src/<slug>.html, and the list on writing.html (between
# <!--writing-list--> markers). Order is tools/writing-order.txt.
#
# A fragment is a JSON front-matter block followed by the piece's HTML:
#   <!--meta
#   { "slug": "...", "title": "...", "kind": "Article" | "Fiction", "source": "Notes of Yore",
#     "published": "September 20, 2021", "datetime": "2021-09-20", "archived": "https://web.archive.org/...",
#     "case": "notes-of-yore" (optional: slug of the related case study), "lede": "...", "description": "...",
#     "og": "og-card.jpg", "note": "how it was reproduced", "content": "optional content note, e.g. profanity" }
#   -->
#   <p>…</p>
#
# The header/footer/og blocks in the template below are stamped by sync-chrome.ps1;
# don't edit them here. Word count is computed from the body.
param([string]$Root = (Split-Path $PSScriptRoot -Parent))
$ErrorActionPreference = 'Stop'
$srcDir = Join-Path $PSScriptRoot 'writing-src'
$order = @(Get-Content (Join-Path $PSScriptRoot 'writing-order.txt') | Where-Object { $_.Trim() } | ForEach-Object { $_.Trim() })
$utf8 = New-Object Text.UTF8Encoding $false
$origin = ([string](Get-Content (Join-Path $PSScriptRoot 'site.json') -Raw | ConvertFrom-Json).origin).TrimEnd('/')   # for JSON-LD URLs; no origin, no schema

function Read-Fragment([string]$path) {
  $raw = [IO.File]::ReadAllText($path, [Text.Encoding]::UTF8)
  $m = [regex]::Match($raw, '(?s)<!--meta\s*(\{.*?\})\s*-->')
  if (-not $m.Success) { throw "No meta block in $path" }
  [pscustomobject]@{ meta = ($m.Groups[1].Value | ConvertFrom-Json); body = $raw.Substring($m.Index + $m.Length).Trim(); path = $path }
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
<title>{{TITLE}} — Writing — Devon Kubacki</title>
<meta name="description" content="{{DESC}}">
<meta name="theme-color" content="#1A1A16">
<meta property="og:type" content="article">
<meta property="og:title" content="{{TITLE}} — Devon Kubacki">
<meta property="og:description" content="{{DESC}}">
<!--og-->
<link rel="canonical" href="https://devonkubacki.netlify.app/writing/{{SLUG}}/">
<meta property="og:url" content="https://devonkubacki.netlify.app/writing/{{SLUG}}/">
<meta property="og:image" content="https://devonkubacki.netlify.app/images/{{OG}}">
<meta name="twitter:card" content="summary_large_image">
<!--/og-->
<link rel="icon" href="data:image/svg+xml,<svg xmlns=%22http://www.w3.org/2000/svg%22 viewBox=%220 0 100 100%22><rect width=%22100%22 height=%22100%22 fill=%22%231A1A16%22/><text x=%2250%22 y=%2268%22 font-size=%2260%22 text-anchor=%22middle%22 fill=%22%23E0B23F%22 font-family=%22Georgia,serif%22>D</text></svg>">
<link rel="stylesheet" href="../../css/style.css">
{{SCHEMA}}
</head>
<body id="top" class="reading">

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
      <a href="../../index.html" data-t="Home">Home</a>
      <a href="../../about.html" data-t="About">About</a>
      <!--worksub--><div class="has-sub">
        <a href="../../projects.html" data-t="Work">Work</a>
        <button class="sub-toggle" type="button" aria-expanded="false" aria-controls="work-sub" aria-label="Show case studies"></button>
        <ul class="submenu" id="work-sub" aria-label="Case studies">
          <li class="sub-group"><span class="sub-label eyebrow">Featured Client Work</span>
            <ul>
            <li><a href="../../work/the-northeastland-hotel/">The Northeastland Hotel</a></li>
            <li><a href="../../work/ignitepi/">IgnitePI</a></li>
            <li><a href="../../work/the-law-offices-of-michael-s-lamonsoff/">The Law Offices of Michael S. Lamonsoff</a></li>
            <li><a href="../../work/brainandspinalcord/">BrainandSpinalCord.org</a></li>
            <li><a href="../../work/washville-car-wash/">Washville Car Wash</a></li>
            <li><a href="../../work/alpha-pressure-washing/">Alpha Pressure Washing</a></li>
            </ul>
          </li>
          <li class="sub-group"><span class="sub-label eyebrow">My Own Projects</span>
            <ul>
            <li><a href="../../work/streamershaven/">Streamer&#39;s Haven</a></li>
            <li><a href="../../work/notes-of-yore/">Notes of Yore</a></li>
            <li><a href="../../work/the-trail-of-tales/">The Trail of Tales</a></li>
            <li><a href="../../work/a-moon-of-cheese/">A Moon of Cheese</a></li>
            </ul>
          </li>
          <li class="all"><a href="../../projects.html">All work &rarr;</a></li>
        </ul>
      </div><!--/worksub-->
      <!--writingsub--><div class="has-sub">
        <a href="../../writing.html" aria-current="page" data-t="Writing">Writing</a>
        <button class="sub-toggle" type="button" aria-expanded="false" aria-controls="writing-sub" aria-label="Show writing samples"></button>
        <ul class="submenu" id="writing-sub" aria-label="Writing samples">
          <li class="sub-group"><span class="sub-label eyebrow">Articles</span>
            <ul>
            <li><a href="../../writing/5e-alternate-combat-rules/">5E Alternate Combat Rules to Speed up Combat</a></li>
            <li><a href="../../writing/streamershaven-internet-speed/">Do You Have the Minimum Internet Speed for Live Streaming? <span class="sub-tag">excerpt</span></a></li>
            </ul>
          </li>
          <li class="sub-group"><span class="sub-label eyebrow">Fiction</span>
            <ul>
            <li><a href="../../writing/powerless-captain-ion/">Captain Ion and the Flammanator <span class="sub-tag">unused scene</span></a></li>
            <li><a href="../../writing/powerless-ian-boraghast/">“My Name Is Ian Boraghast” <span class="sub-tag">unused scene</span></a></li>
            </ul>
          </li>
          <li class="all"><a href="../../writing.html">All writing &rarr;</a></li>
        </ul>
      </div><!--/writingsub-->
      <a href="../../services.html" data-t="Services">Services</a>
      <a href="../../gallery.html" data-t="Gallery">Gallery</a>
      <a href="../../contact.html" data-t="Contact">Contact</a>
    </nav>
  </div>
</header>
<!--/header-->

<main id="main">
  <section class="page-intro grid-bg">
    <div class="hex-blinks" aria-hidden="true"></div>
    <div class="wrap">
      <p class="eyebrow">Writing sample &middot; {{KIND}} &middot; {{SOURCE}} &middot; <time datetime="{{DATETIME}}">{{PUBLISHED}}</time></p>
      <h1>{{TITLE}}</h1>
      <p>{{LEDE}}</p>
    </div>
  </section>

  <section class="band" id="about-this">
    <div class="wrap">
      <dl class="case-facts">
        <div><dt>{{PUB_LABEL}}</dt><dd>{{SOURCE}}, {{PUBLISHED}}{{CASE_LINK}}</dd></div>
        <div><dt>Length</dt><dd>{{LENGTH}}</dd></div>
{{ARCHIVE_DIV}}
      </dl>
      <p class="sample-note">{{NOTE}}</p>{{CONTENT_NOTE}}
    </div>
  </section>

  <article class="band on-slate grid-bg case-band" id="text">
  <div class="case-body">
{{TOC}}
    <div class="wrap">
      <div class="prose reading-text{{FICTION}}">
{{BODY}}
      </div>
    </div>
  </div><!-- /.case-body -->
  </article>

'@

$tail = @'
  <section class="band">
    <div class="wrap">
      <nav class="case-nav" aria-label="More writing">
{{PREV}}
        <a class="link-arrow" href="../../writing.html" style="align-self:center">All writing</a>
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
      <a href="../../resume.html">Resume</a>
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
<script src="../../js/script.js"></script>
</body>
</html>
'@

function Html([string]$s) { [Net.WebUtility]::HtmlEncode($s) }
function Words([string]$html) { (($html -replace '<[^>]+>', ' ' -replace '\s+', ' ').Trim() -split ' ').Count }

$built = 0; $listItems = New-Object System.Collections.Generic.List[string]
for ($i = 0; $i -lt $order.Count; $i++) {
  $fr = $frags[$order[$i]]; $m = $fr.meta
  $prev = if ($i -gt 0) { $frags[$order[$i - 1]].meta } else { $null }
  $next = if ($i -lt $order.Count - 1) { $frags[$order[$i + 1]].meta } else { $null }
  # Articles and excerpts get ids on their h2/h3s and a centred TOC; fiction doesn't.
  $body = $fr.body; $tocHtml = ''
  if ($m.kind -ne 'Fiction') {
    $used = @{}; $items = New-Object System.Collections.Generic.List[string]; $script:openSub = $false
    $body = [regex]::Replace($body, '<(h2|h3)>(.*?)</\1>', {
      param($mm)
      $lvl = $mm.Groups[1].Value; $text = $mm.Groups[2].Value
      $plain = [Net.WebUtility]::HtmlDecode(($text -replace '<[^>]+>', '')).Trim()
      $id = (($plain.ToLower() -replace '[^a-z0-9]+', '-').Trim('-')); if (-not $id) { $id = 'section' }
      $base = $id; $n = 2; while ($used.ContainsKey($id)) { $id = "$base-$n"; $n++ }; $used[$id] = $true
      if ($lvl -eq 'h2') { if ($script:openSub) { $items.Add('            </ol></li>'); $script:openSub = $false } else { if ($items.Count -gt 0) { $items.Add('          </li>') } }; $items.Add("          <li><a href=`"#$id`">$(Html $plain)</a>") }
      else { if (-not $script:openSub) { $items.Add('            <ol>'); $script:openSub = $true }; $items.Add("              <li><a href=`"#$id`">$(Html $plain)</a></li>") }
      "<$lvl id=`"$id`">$text</$lvl>"
    })
    if ($script:openSub) { $items.Add('            </ol></li>') } elseif ($items.Count -gt 0) { $items.Add('          </li>') }
    if ($items.Count -gt 0) {
      $tocHtml = "    <aside class=`"toc-rail`">`n      <nav class=`"toc toc-flat`" aria-label=`"In this piece`">`n        <span class=`"toc-title eyebrow`">In this piece</span>`n        <ol>`n" + ($items -join "`n") + "`n        </ol>`n      </nav>`n    </aside>"
    }
  }
  $words = Words $body
  $wordsFmt = $words.ToString('N0')
  $lengthText = if ($m.kind -eq 'Excerpt') { "$wordsFmt-word excerpt" } else { "$wordsFmt words" }
  $contentNote = if ($m.content) { "`n      <p class=`"content-note`"><strong>Content note:</strong> $(Html $m.content)</p>" } else { '' }
  $contentListNote = if ($m.content) { " &middot; <span class=`"content-flag`">$(Html $m.content)</span>" } else { '' }
  $pubLabel = if ($m.archived) { 'Originally published' } else { 'From' }
  $fiction = if ($m.kind -eq 'Fiction') { ' fiction' } else { '' }
  $caseLink = if ($m.case) { " &middot; <a href=`"../../work/$($m.case)/`">the case study</a>" } else { '' }
  $archiveDiv = if ($m.archived) { "        <div><dt>The original</dt><dd><a class=`"link-arrow`" href=`"$($m.archived)`" target=`"_blank`" rel=`"noopener`" title=`"Open the archived page on the Wayback Machine (new tab)`">Archived copy <span class=`"arrow`" aria-hidden=`"true`">&#8599;</span></a></dd></div>" } else { '' }
  $prevHtml = if ($prev) { "        <a class=`"prev`" href=`"../$($prev.slug)/`"><span class=`"eyebrow`">&larr; Previous</span><span class=`"case-nav-title`">$(Html $prev.title)</span></a>" } else { '        <span></span>' }
  $nextHtml = if ($next) { "        <a class=`"next`" href=`"../$($next.slug)/`"><span class=`"eyebrow`">Next &rarr;</span><span class=`"case-nav-title`">$(Html $next.title)</span></a>" } else { '        <span></span>' }

  # JSON-LD: Article for published pieces, CreativeWork for unpublished fiction; author is the Person on the home page.
  $schemaType = if ($m.kind -eq 'Fiction') { 'CreativeWork' } else { 'Article' }
  $schema = @{ '@context' = 'https://schema.org'; '@type' = $schemaType; headline = [string]$m.title; description = [string]$m.description
    author = @{ '@type' = 'Person'; '@id' = "$origin/#devon"; name = 'Devon Kubacki' }; wordCount = $words; inLanguage = 'en'
    url = "$origin/writing/$($m.slug)/" }
  if ($m.datetime -match '^\d{4}(-\d{2}-\d{2})?$') { $schema.datePublished = [string]$m.datetime }
  if ($m.kind -eq 'Fiction') { $schema.genre = 'Fiction'; $schema.isPartOf = @{ '@type' = 'Book'; name = 'Powerless'; author = @{ '@id' = "$origin/#devon" } } }
  if ($m.archived) { $schema.sameAs = [string]$m.archived }
  $crumbs = [ordered]@{ '@context' = 'https://schema.org'; '@type' = 'BreadcrumbList'; itemListElement = @(
    @{ '@type' = 'ListItem'; position = 1; name = 'Home'; item = "$origin/" },
    @{ '@type' = 'ListItem'; position = 2; name = 'Writing'; item = "$origin/writing.html" },
    @{ '@type' = 'ListItem'; position = 3; name = [string]$m.title; item = "$origin/writing/$($m.slug)/" }) }
  $lf = [char]10
  $schemaJson = if ($origin) {
    '<script type="application/ld+json">' + $lf + (($schema | ConvertTo-Json -Depth 5).Replace("`r`n", "`n")) + $lf + '</script>' + $lf +
    '<script type="application/ld+json">' + $lf + (($crumbs | ConvertTo-Json -Depth 5).Replace("`r`n", "`n")) + $lf + '</script>'
  } else { '' }
  $page = $head + $tail
  $map = @{
    '{{TITLE}}' = (Html $m.title); '{{DESC}}' = (Html $m.description); '{{SLUG}}' = $m.slug; '{{OG}}' = $m.og
    '{{KIND}}' = (Html $m.kind); '{{SOURCE}}' = (Html $m.source); '{{PUBLISHED}}' = (Html $m.published); '{{DATETIME}}' = $m.datetime
    '{{LEDE}}' = $m.lede; '{{NOTE}}' = $m.note; '{{PUB_LABEL}}' = $pubLabel; '{{CONTENT_NOTE}}' = $contentNote; '{{FICTION}}' = $fiction; '{{WORDS}}' = $wordsFmt; '{{LENGTH}}' = $lengthText; '{{CASE_LINK}}' = $caseLink; '{{ARCHIVE_DIV}}' = $archiveDiv
    '{{BODY}}' = $body; '{{TOC}}' = $tocHtml; '{{SCHEMA}}' = $schemaJson; '{{PREV}}' = $prevHtml; '{{NEXT}}' = $nextHtml
  }
  foreach ($kv in $map.GetEnumerator()) { $page = $page.Replace($kv.Key, [string]$kv.Value) }
  $page = [regex]::Replace($page, '(?<=["\s,])images/', '../../images/')
  # This page's own entry in the Writing submenu.
  $page = $page.Replace("<a href=""../../writing/$($m.slug)/"">", "<a href=""../../writing/$($m.slug)/"" aria-current=""page"">")

  $dir = Join-Path $Root ("writing\" + $m.slug)
  New-Item -ItemType Directory -Force $dir | Out-Null
  [IO.File]::WriteAllText((Join-Path $dir 'index.html'), $page, $utf8)
  $built++
  "built writing/$($m.slug)/index.html  ($wordsFmt words)"

  $listItems.Add(@"
        <li class="ledger entry has-case" id="$($m.slug)">
          <div class="margin"><time datetime="$($m.datetime)">$(Html $m.published)</time></div>
          <div>
            <h3><a href="writing/$($m.slug)/">$(Html $m.title)</a></h3>
            <div class="role">$(Html $m.kind) &middot; $(Html $m.source) &middot; $lengthText$contentListNote</div>
            <p class="desc">$($m.lede)</p>
            <div class="links"><a class="link-arrow" href="writing/$($m.slug)/">Read it <span class="arrow" aria-hidden="true">&rarr;</span></a></div>
          </div>
        </li>
"@)
}

# The list on writing.html
$listPage = Join-Path $Root 'writing.html'
if (Test-Path $listPage) {
  $c = [IO.File]::ReadAllText($listPage, [Text.Encoding]::UTF8)
  $rx = [regex]'(?s)<!--writing-list-->.*?<!--/writing-list-->'
  if (-not $rx.IsMatch($c)) { throw 'writing.html has no <!--writing-list--> markers' }
  $block = "<!--writing-list-->`n" + ($listItems -join "`n") + "`n      <!--/writing-list-->"
  $c = $rx.Replace($c, ($block -replace '\$', '$$'), 1)
  [IO.File]::WriteAllText($listPage, $c, $utf8)
  "writing.html: $($listItems.Count) samples listed"
}
"pages: $built"
