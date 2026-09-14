# Regenerates the Gallery page from the Work page's entry galleries:
# one band per Work entry that has screenshots, same figures, captions,
# alt text and source links. Run after adding or reordering shots on projects.html.
$root = Split-Path $PSScriptRoot -Parent
$proj = [IO.File]::ReadAllText((Join-Path $root 'projects.html'))
$gal  = [IO.File]::ReadAllText((Join-Path $root 'gallery.html'))

# One band per Work entry that has a gallery, in Work-page order.
$intros = @{
  'northeastland'       = 'Website redesign and copywriting for a historic boutique hotel in Presque Isle, Maine. Live site, captured 2026.'
  'ignitepi'            = 'Companion build for the nonprofit that owns the hotel. Live site, captured 2026.'
  'streamershaven-theme'= 'A custom WordPress theme, brand, and logo for the streaming tutorial site I ran from 2019 to 2021. Captured from the Wayback Machine, Dec 2020.'
  'msllegal'            = 'Site redesign for a Manhattan personal-injury firm, built at Ardea Studios. Captured from the Wayback Machine, Sep 2017.'
  'streamershaven'      = 'The writing side of Streamershaven: tutorials, gear guides, and public-service pieces from the 246-article run. Captured from the Wayback Machine, Oct–Dec 2020.'
  'migration'           = 'The 2,700-page Drupal-to-WordPress migration, rebuilt in Divi to match the original design one-for-one. Captured from the Wayback Machine, 2016.'
}

$entryRx = [regex]'(?s)<li class="ledger entry" id="(?<id>[^"]+)">(?<body>.*?)(?=\r?\n\s*<li class="ledger entry"|\r?\n\s*</ol>)'
$bands = New-Object System.Collections.Generic.List[string]
$i = 0
foreach ($m in $entryRx.Matches($proj)) {
  $id = $m.Groups['id'].Value; $body = $m.Groups['body'].Value
  if ($body -notmatch '<div class="entry-gallery"') { continue }
  $name = [regex]::Match($body, '<h3>(.*?)</h3>').Groups[1].Value; if ($id -eq 'streamershaven') { $name = 'Streamershaven &mdash; Articles' }
  $figs = [regex]::Matches($body, '(?s)<li>(<figure data-full=.*?</figure>)</li>') | ForEach-Object { $_.Groups[1].Value }
  # Work-page thumbs declare sizes="4.5rem"; gallery tiles are grid cells
  # (auto-fill, min 300px) so tell the browser their real rendered width.
  $tileSizes = 'sizes="(max-width: 700px) calc(100vw - 3rem), (max-width: 1060px) calc(50vw - 3rem), 340px"'
  $items = ($figs | ForEach-Object { "        " + ($_ -replace 'sizes="4\.5rem"', $tileSizes) }) -join "`n`n"
  $cls = if ($i % 2 -eq 1) { 'band gallery-band on-slate grid-bg' } else { 'band gallery-band' }
  $intro = $intros[$id]; if (-not $intro) { $intro = '' }
  $bands.Add(@"
  <section class="$cls" id="g-$id">
    <div class="wrap">
      <h2>$name</h2>
      <p class="category-intro gallery-intro">$intro <a class="link-arrow" href="projects.html#$id">Read the Work entry <span class="arrow" aria-hidden="true">&rarr;</span></a></p>
      <div class="gallery-grid">

$items

      </div>
    </div>
  </section>
"@)
  $i++
}

$newBody = ($bands -join "`n`n")
# Everything from the first band after the page intro to the end of <main> is generated.
$rx = [regex]'(?s)(?<=</section>\r?\n\r?\n)  <section class="band.*?</section>\r?\n</main>'
if (-not $rx.IsMatch($gal)) { throw 'gallery body not found' }
$gal = $rx.Replace($gal, ($newBody -replace '\$', '$$') + "`n</main>", 1)
[IO.File]::WriteAllText((Join-Path $root 'gallery.html'), $gal, (New-Object Text.UTF8Encoding $false))
"bands: $($bands.Count); figures: $(([regex]::Matches($newBody, '<figure ')).Count)"
