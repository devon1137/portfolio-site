# Stamps the site header and footer into every page from one source each:
#   tools/chrome/header.html   tools/chrome/footer.html
# Placeholders: {{ROOT}} = path prefix to the site root ('' / '../../' / '/'),
# {{HOME}} = the home link. The header's Work item is a <!--worksub--> stub;
# sync-nav.ps1 (run at the end of this script) fills the case-study submenu.
# aria-current="page" is set on the nav link that matches the page.
#
# chrome/og.html is the <head> block (canonical, og:url, og:image, twitter:card),
# stamped between <!--og--> markers; it renders as a placeholder comment until
# tools/site.json has an "origin", because those tags need absolute URLs.
# Top-level pages use images/og-card.jpg; case studies get their own screenshot
# via the build-work template ({{OG}}); 404 gets none.
#
# Pages get <!--header-->…<!--/header--> and <!--footer-->…<!--/footer-->
# markers on first run (migrating a bare <header class="site">/<footer class="site">);
# after that only the marked region is replaced. The case-study template in
# build-work.ps1 is stamped the same way, so rebuilt case studies match.
#
# Edit the fragment, run this (or tools/build.ps1), commit. Never edit a
# page's header/footer by hand: the next run overwrites it.
param([string]$Root = (Split-Path $PSScriptRoot -Parent), [switch]$Check)
$ErrorActionPreference = 'Stop'
$utf8 = New-Object Text.UTF8Encoding $false
$hdrSrc = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'chrome\header.html')).Trim()
$ftrSrc = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'chrome\footer.html')).Trim()
foreach ($pair in @(@($hdrSrc, 'header'), @($ftrSrc, 'footer'))) {
  if ($pair[0] -notmatch "^<!--$($pair[1])-->" -or $pair[0] -notmatch "<!--/$($pair[1])-->$") { throw "chrome/$($pair[1]).html must start with <!--$($pair[1])--> and end with <!--/$($pair[1])-->" }
}
$navPages = @('index.html', 'about.html', 'writing.html', 'services.html', 'gallery.html', 'contact.html')

# <head> block (canonical + og:image) from chrome/og.html, only once tools/site.json has an origin.
$site = Get-Content (Join-Path $PSScriptRoot 'site.json') -Raw | ConvertFrom-Json
$origin = ([string]$site.origin).TrimEnd('/')
$ogSrc = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'chrome\og.html')).Trim()
function RenderOg([string]$path, [string]$image) {
  if (-not $origin) { return '<!--og--><!-- canonical + og:image: set "origin" in tools/site.json --><!--/og-->' }
  $ogSrc.Replace('{{ORIGIN}}', $origin).Replace('{{PATH}}', $path).Replace('{{IMAGE}}', $image)
}
function StampOg([string]$c, [string]$rendered) {
  $rep = $rendered -replace '\$', '$$'
  $marked = [regex]'(?s)<!--og-->.*?<!--/og-->'
  if ($marked.IsMatch($c)) { return $marked.Replace($c, $rep, 1) }
  # First run: insert above the icon link (every page has one).
  $anchor = '<link rel="icon"'
  $i = $c.IndexOf($anchor); if ($i -lt 0) { throw 'no <link rel="icon"> to anchor the og block' }
  $c.Substring(0, $i) + $rendered + "`n" + $c.Substring($i)
}

# Per-page JSON-LD from chrome/schema/<page>.json ({{ORIGIN}} substituted), stamped
# between <!--schema--> markers right after the og block. Skipped without an origin.
$schemaDir = Join-Path $PSScriptRoot 'chrome\schema'
function Untag([string]$s) { [Net.WebUtility]::HtmlDecode(($s -replace '<[^>]+>', '' -replace '\s+', ' ').Trim()) }
function RenderSchema([string]$page, [string]$html) {
  $f = Join-Path $schemaDir "$page.json"
  # A page with <div class="faq"> of <details><summary>Q</summary><p>A</p></details> also gets FAQPage, built from the markup.
  $faq = [regex]::Match($html, '(?s)<div class="faq">(.*?)</div>\s*</div>\s*</section>')
  if (-not (Test-Path $f) -and -not $faq.Success) { return $null }
  if (-not $origin) { return '<!--schema--><!-- JSON-LD: set "origin" in tools/site.json --><!--/schema-->' }
  $blocks = @()
  if (Test-Path $f) { $blocks += [IO.File]::ReadAllText($f, [Text.Encoding]::UTF8).Trim().Replace('{{ORIGIN}}', $origin) }
  if ($faq.Success) {
    $qs = [regex]::Matches($faq.Groups[1].Value, '(?s)<details>\s*<summary>(.*?)</summary>(.*?)</details>') | ForEach-Object {
      @{ '@type' = 'Question'; name = (Untag $_.Groups[1].Value); acceptedAnswer = @{ '@type' = 'Answer'; text = (Untag $_.Groups[2].Value) } } }
    $obj = [ordered]@{ '@context' = 'https://schema.org'; '@type' = 'FAQPage'; url = "$origin/$page#faq"; mainEntity = @($qs) }
    $blocks += ($obj | ConvertTo-Json -Depth 6 -Compress)
  }
  "<!--schema-->`n" + (($blocks | ForEach-Object { "<script type=`"application/ld+json`">`n$_`n</script>" }) -join "`n") + "`n<!--/schema-->"
}
function StampSchema([string]$c, [string]$rendered) {
  $rep = $rendered -replace '\$', '$$'
  $marked = [regex]'(?s)<!--schema-->.*?<!--/schema-->'
  if ($marked.IsMatch($c)) { return $marked.Replace($c, $rep, 1) }
  # First run: right after the og block (which every page has by now).
  $anchor = '<!--/og-->'
  $i = $c.IndexOf($anchor); if ($i -lt 0) { throw 'no og block to anchor the schema block' }
  $i += $anchor.Length
  $c.Substring(0, $i) + "`n" + $rendered + $c.Substring($i)
}

function Render([string]$src, [string]$pre, [string]$homeHref, [string]$page) {
  $out = $src
  if ($navPages -contains $page) {
    # Mark the matching top-level nav link current (before substitution so the match is exact).
    $target = if ($page -eq 'index.html') { 'href="{{HOME}}"' } else { "href=`"{{ROOT}}$page`"" }
    $out = [regex]::Replace($out, "<a $([regex]::Escape($target))( data-t=`"[^`"]*`")?>", { param($mm) "<a $target aria-current=`"page`"$($mm.Groups[1].Value)>" }, 1)
  }
  $out.Replace('{{HOME}}', $homeHref).Replace('{{ROOT}}', $pre)
}
# The submenu is filled by sync-nav after stamping, so compare with it blanked.
function Norm([string]$s) { [regex]::Replace([regex]::Replace($s, '(?s)<!--worksub-->.*?<!--/worksub-->', '<!--worksub-->'), '(?s)<!--writingsub-->.*?<!--/writingsub-->', '<!--writingsub-->') }
function Stamp([string]$c, [string]$name, [string]$rendered) {
  # Prefer the marked region; otherwise migrate the bare element (first occurrence).
  $marked = [regex]"(?s)<!--$name-->.*?<!--/$name-->"
  $bare = [regex]"(?s)<$name class=`"site`">.*?</$name>"
  $rep = $rendered -replace '\$', '$$'
  if ($marked.IsMatch($c)) { return $marked.Replace($c, $rep, 1) }
  if ($bare.IsMatch($c)) { return $bare.Replace($c, $rep, 1) }
  throw "no <$name class=`"site`"> found"
}

$targets = @(Get-ChildItem (Join-Path $Root '*.html')) + @(Get-ChildItem (Join-Path $Root 'work\*\index.html') -ErrorAction SilentlyContinue) + @(Get-ChildItem (Join-Path $Root 'writing\*\index.html') -ErrorAction SilentlyContinue)
$changed = 0; $drift = @()
foreach ($f in $targets) {
  $c = [IO.File]::ReadAllText($f.FullName)
  $isWork = ($f.FullName -like '*\work\*') -or ($f.FullName -like '*\writing\*')   # a two-levels-deep generated page
  $pre = if ($f.Name -eq '404.html') { '/' } elseif ($isWork) { '../../' } else { '' }
  $homeHref = if ($f.Name -eq '404.html') { '/' } else { "${pre}index.html" }
  $page = if ($f.FullName -like '*\work\*') { 'work' } elseif ($f.FullName -like '*\writing\*') { 'writing.html' } else { $f.Name }   # which nav item is current
  $new = Stamp $c 'header' (Render $hdrSrc $pre $homeHref $page)
  $new = Stamp $new 'footer' (Render $ftrSrc $pre $homeHref $page)
  # Top-level pages share the og card; case studies get theirs from the template (own screenshot), 404 gets none.
  if (-not $isWork -and $f.Name -ne '404.html') {
    $path = if ($f.Name -eq 'index.html') { '/' } else { '/' + $f.Name }
    $new = StampOg $new (RenderOg $path 'og-card.jpg')
    $sch = RenderSchema $f.Name $new
    if ($sch) { $new = StampSchema $new $sch }
  }
  if ((Norm $new) -ne (Norm $c)) {
    $drift += $f.FullName.Replace($Root + '\', '')
    if (-not $Check) { [IO.File]::WriteAllText($f.FullName, $new, $utf8); $changed++ }
  }
}

# The page templates inside the generators (kept with their BOM). Each builder
# fills {{SLUG}} and {{OG}} itself; the nav item marked current is the section's.
$templates = @(
  @{ file = 'build-work.ps1';    page = 'work';         path = '/work/{{SLUG}}/' }
  @{ file = 'build-writing.ps1'; page = 'writing.html'; path = '/writing/{{SLUG}}/' }
)
$tplChanged = @()
foreach ($tp in $templates) {
  $tpl = Join-Path $PSScriptRoot $tp.file
  if (-not (Test-Path $tpl)) { continue }
  $t = [IO.File]::ReadAllText($tpl, [Text.Encoding]::UTF8)
  $t2 = Stamp $t 'header' (Render $hdrSrc '../../' '../../index.html' $tp.page)
  $t2 = Stamp $t2 'footer' (Render $ftrSrc '../../' '../../index.html' $tp.page)
  $t2 = StampOg $t2 (RenderOg $tp.path '{{OG}}')
  if ((Norm $t2) -ne (Norm $t)) {
    $drift += "tools/$($tp.file)"; $tplChanged += $tp.file
    if (-not $Check) { [IO.File]::WriteAllText($tpl, $t2, (New-Object Text.UTF8Encoding $true)) }
  }
}

if ($Check) {
  if ($drift) { "out of date (run sync-chrome.ps1): " + ($drift -join ', '); exit 1 } else { 'chrome in sync'; exit 0 }
}
"chrome stamped: $changed of $($targets.Count) pages changed" + $(if ($tplChanged) { ' + templates: ' + ($tplChanged -join ', ') } else { '' })
# The Work submenu lives inside the header; fill it now (pages + template).
& (Join-Path $PSScriptRoot 'sync-nav.ps1') -Root $Root
