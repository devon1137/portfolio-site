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
  # One band per case study: several galleries in a case study (e.g. build + writing) are merged.
  $figs = @(); $intros = @(); $creative = $false
  foreach ($s in $withGrid) {
    $f = [regex]::Matches($s.Groups['inner'].Value, '(?s)<figure data-full=.*?</figure>') | ForEach-Object { $_.Value }
    if (-not $f) { continue }
    $figs += $f
    $intro = [regex]::Match($s.Groups['inner'].Value, '<p class="category-intro gallery-intro">(.*?)</p>').Groups[1].Value
    if ($intro) { $intros += $intro }
    if ($s.Groups['inner'].Value -match '<div class="gallery-grid creative"') { $creative = $true }
  }
  if (-not $figs) { continue }
  $sets.Add([pscustomobject]@{
    id = $slug; name = $meta.title; figs = $figs
    gridClass = $(if ($creative) { ' creative' } else { '' })
    intro = ($intros | Select-Object -First 1)
    link = "work/$slug/"; linkLabel = 'Read the case study'
  })
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
# Same shape as a case study: a stone strip under the intro, then one
# honeycomb band holding every group, with the rail beside them.
$groups = New-Object System.Collections.Generic.List[string]
foreach ($set in $sets) {
  $items = ($set.figs | ForEach-Object { "        " + ($_ -replace 'sizes="4\.5rem"', $tileSizes) -replace 'sizes="\(max-width: 700px\)[^"]*"', $tileSizes }) -join "`n`n"
  $introHtml = if ($set.intro) { $set.intro + ' ' } else { '' }
  $groups.Add(@"
      <section class="gallery-group" id="g-$($set.id)">
        <h2>$($set.name)</h2>
        <p class="category-intro gallery-intro">$introHtml<a class="link-arrow" href="$($set.link)">$($set.linkLabel) <span class="arrow" aria-hidden="true">&rarr;</span></a></p>
        <div class="gallery-grid$($set.gridClass)">

$items

        </div>
      </section>
"@)
}

$figTotal = ($sets | ForEach-Object { $_.figs.Count } | Measure-Object -Sum).Sum
$tocItems = ($sets | ForEach-Object { "          <li><a href=`"#g-$($_.id)`">$($_.name) <span class=`"dim`">($($_.figs.Count))</span></a></li>" }) -join "`n"
$newBody = @"
  <section class="band" id="facts">
    <div class="wrap">
      <dl class="case-facts">
        <div><dt>Projects</dt><dd>$($sets.Count)</dd></div>
        <div><dt>Captures</dt><dd>$figTotal</dd></div>
      </dl>
    </div>
  </section>

  <section class="band on-slate grid-bg case-band gallery-band">
  <div class="case-body">
    <aside class="toc-rail">
      <nav class="toc toc-flat" aria-label="Gallery index">
        <span class="toc-title eyebrow">On this page</span>
        <ol>
$tocItems
        </ol>
      </nav>
    </aside>
    <div class="wrap">
      <div class="case-text gallery-text">
$($groups -join "`n`n")
      </div>
    </div>
  </div><!-- /.case-body -->
  </section>
"@
# Everything from the first band after the page intro to the end of <main> is generated.
$rx = [regex]'(?s)(?<=</section>\r?\n\r?\n)  (?:<div class="case-body">|<section class="band).*?\n</main>'
if (-not $rx.IsMatch($gal)) { throw 'gallery body not found' }
$gal = $rx.Replace($gal, ($newBody -replace '\$', '$$') + "`n</main>", 1)
[IO.File]::WriteAllText((Join-Path $root 'gallery.html'), $gal, $utf8)
"bands: $($sets.Count); figures: $(($sets | ForEach-Object { $_.figs.Count } | Measure-Object -Sum).Sum)"
