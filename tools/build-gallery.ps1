# Regenerates the Gallery page from the case-study sources (tools/work-src)
# and any entry galleries still inline on the Work page: one band per set of
# screenshots, same figures, captions, alt text and source links, plus a
# table of contents. Run after adding or reordering shots.
$root = Split-Path $PSScriptRoot -Parent
$utf8 = New-Object Text.UTF8Encoding $false
$gal = [IO.File]::ReadAllText((Join-Path $root 'gallery.html'))

$tileSizes = 'sizes="(max-width: 700px) calc(100vw - 3rem), (max-width: 1060px) calc(50vw - 3rem), 340px"'
$sets = New-Object System.Collections.Generic.List[object]

# ---- Case studies, in the same order as build-work.ps1 ----
$order = @(Get-Content (Join-Path $PSScriptRoot 'work-order.txt') | Where-Object { $_.Trim() } | ForEach-Object { $_.Trim() })   # one slug per line: the case-study order, used by every tool
foreach ($slug in $order) {
  $path = Join-Path $PSScriptRoot "work-src\$slug.html"
  if (-not (Test-Path $path)) { continue }
  $raw = [IO.File]::ReadAllText($path)
  $meta = [regex]::Match($raw, '(?s)<!--meta\s*(\{.*?\})\s*-->').Groups[1].Value | ConvertFrom-Json
  $secs = [regex]::Matches($raw, '(?s)<section\s+id="(?<id>[^"]+)"(?:\s+data-title="(?<t>[^"]*)")?\s*>(?<inner>.*?)</section>')
  $withGrid = @($secs | Where-Object { $_.Groups['inner'].Value -match '<div class="gallery-grid[ "]' })
  foreach ($s in $withGrid) {
    $figs = [regex]::Matches($s.Groups['inner'].Value, '(?s)<figure data-full=.*?</figure>') | ForEach-Object { $_.Value }
    if (-not $figs) { continue }
    $intro = [regex]::Match($s.Groups['inner'].Value, '<p class="category-intro gallery-intro">(.*?)</p>').Groups[1].Value
    $name = $meta.title
    if ($withGrid.Count -gt 1) { $name = "$($meta.title) &mdash; $($s.Groups['t'].Value)" }
    $sets.Add([pscustomobject]@{
      id = ($slug + $(if ($withGrid.Count -gt 1) { '-' + $s.Groups['id'].Value } else { '' }))
      name = $name; figs = $figs
      gridClass = $(if ($s.Groups['inner'].Value -match '<div class="gallery-grid creative"') { ' creative' } else { '' })
      intro = $intro
      link = "work/$slug/" + $(if ($withGrid.Count -gt 1) { '#' + $s.Groups['id'].Value } else { '' })
      linkLabel = 'Read the case study'
    })
  }
}

# ---- Work-page entries that still carry a gallery but have no case study ----
$proj = [IO.File]::ReadAllText((Join-Path $root 'projects.html'))
$entryRx = [regex]'(?s)<li class="ledger entry(?<hc> has-case)?" id="(?<id>[^"]+)">(?<body>.*?)(?=\r?\n\s*<li class="ledger entry|\r?\n\s*</ol>)'
foreach ($m in $entryRx.Matches($proj)) {
  if ($m.Groups['hc'].Value) { continue }
  $figs = [regex]::Matches($m.Groups['body'].Value, '(?s)<li>(<figure data-full=.*?</figure>)</li>') | ForEach-Object { $_.Groups[1].Value }
  if (-not $figs) { continue }
  $sets.Add([pscustomobject]@{ id = $m.Groups['id'].Value; name = [regex]::Match($m.Groups['body'].Value, '<h3>(.*?)</h3>').Groups[1].Value; figs = $figs; intro = ''; link = "projects.html#$($m.Groups['id'].Value)"; linkLabel = 'Read the Work entry' })
}

# ---- Render ----
$bands = New-Object System.Collections.Generic.List[string]
$i = 0
foreach ($set in $sets) {
  $items = ($set.figs | ForEach-Object { "        " + ($_ -replace 'sizes="4\.5rem"', $tileSizes) -replace 'sizes="\(max-width: 700px\)[^"]*"', $tileSizes }) -join "`n`n"
  $cls = if ($i % 2 -eq 1) { 'band gallery-band on-slate grid-bg' } else { 'band gallery-band' }
  $introHtml = if ($set.intro) { $set.intro + ' ' } else { '' }
  $bands.Add(@"
  <section class="$cls" id="g-$($set.id)">
    <div class="wrap">
      <h2>$($set.name)</h2>
      <p class="category-intro gallery-intro">$introHtml<a class="link-arrow" href="$($set.link)">$($set.linkLabel) <span class="arrow" aria-hidden="true">&rarr;</span></a></p>
      <div class="gallery-grid$($set.gridClass)">

$items

      </div>
    </div>
  </section>
"@)
  $i++
}

$tocItems = ($sets | ForEach-Object { "          <li><a href=`"#g-$($_.id)`">$($_.name) <span class=`"dim`">($($_.figs.Count))</span></a></li>" }) -join "`n"
$toc = @"
  <section class="band toc-band">
    <div class="wrap">
      <nav class="toc toc-flat" aria-label="Gallery index">
        <span class="toc-title eyebrow">On this page</span>
        <ol>
$tocItems
        </ol>
      </nav>
    </div>
  </section>

"@

$newBody = $toc + ($bands -join "`n`n")
# Everything from the first band after the page intro to the end of <main> is generated.
$rx = [regex]'(?s)(?<=</section>\r?\n\r?\n)  <section class="band.*?</section>\r?\n</main>'
if (-not $rx.IsMatch($gal)) { throw 'gallery body not found' }
$gal = $rx.Replace($gal, ($newBody -replace '\$', '$$') + "`n</main>", 1)
[IO.File]::WriteAllText((Join-Path $root 'gallery.html'), $gal, $utf8)
"bands: $($sets.Count); figures: $(($sets | ForEach-Object { $_.figs.Count } | Measure-Object -Sum).Sum)"
