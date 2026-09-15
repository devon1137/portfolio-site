# Stamps the site header and footer into every page from one source each:
#   tools/chrome/header.html   tools/chrome/footer.html
# Placeholders: {{ROOT}} = path prefix to the site root ('' / '../../' / '/'),
# {{HOME}} = the home link. The header's Work item is a <!--worksub--> stub;
# sync-nav.ps1 (run at the end of this script) fills the case-study submenu.
# aria-current="page" is set on the nav link that matches the page.
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
$navPages = @('index.html', 'about.html', 'services.html', 'gallery.html', 'contact.html')

function Render([string]$src, [string]$pre, [string]$homeHref, [string]$page) {
  $out = $src
  if ($navPages -contains $page) {
    # Mark the matching top-level nav link current (before substitution so the match is exact).
    $target = if ($page -eq 'index.html') { 'href="{{HOME}}"' } else { "href=`"{{ROOT}}$page`"" }
    $out = $out.Replace("<a $target>", "<a $target aria-current=`"page`">")
  }
  $out.Replace('{{HOME}}', $homeHref).Replace('{{ROOT}}', $pre)
}
# The submenu is filled by sync-nav after stamping, so compare with it blanked.
function Norm([string]$s) { [regex]::Replace($s, '(?s)<!--worksub-->.*?<!--/worksub-->', '<!--worksub-->') }
function Stamp([string]$c, [string]$name, [string]$rendered) {
  # Prefer the marked region; otherwise migrate the bare element (first occurrence).
  $marked = [regex]"(?s)<!--$name-->.*?<!--/$name-->"
  $bare = [regex]"(?s)<$name class=`"site`">.*?</$name>"
  $rep = $rendered -replace '\$', '$$'
  if ($marked.IsMatch($c)) { return $marked.Replace($c, $rep, 1) }
  if ($bare.IsMatch($c)) { return $bare.Replace($c, $rep, 1) }
  throw "no <$name class=`"site`"> found"
}

$targets = @(Get-ChildItem (Join-Path $Root '*.html')) + @(Get-ChildItem (Join-Path $Root 'work\*\index.html') -ErrorAction SilentlyContinue)
$changed = 0; $drift = @()
foreach ($f in $targets) {
  $c = [IO.File]::ReadAllText($f.FullName)
  $isWork = $f.FullName -like '*\work\*'
  $pre = if ($f.Name -eq '404.html') { '/' } elseif ($isWork) { '../../' } else { '' }
  $homeHref = if ($f.Name -eq '404.html') { '/' } else { "${pre}index.html" }
  $page = if ($isWork) { 'work' } else { $f.Name }
  $new = Stamp $c 'header' (Render $hdrSrc $pre $homeHref $page)
  $new = Stamp $new 'footer' (Render $ftrSrc $pre $homeHref $page)
  if ((Norm $new) -ne (Norm $c)) {
    $drift += $f.FullName.Replace($Root + '\', '')
    if (-not $Check) { [IO.File]::WriteAllText($f.FullName, $new, $utf8); $changed++ }
  }
}

# The case-study template inside build-work.ps1 (keeps its BOM).
$tpl = Join-Path $PSScriptRoot 'build-work.ps1'
$t = [IO.File]::ReadAllText($tpl, [Text.Encoding]::UTF8)
$t2 = Stamp $t 'header' (Render $hdrSrc '../../' '../../index.html' 'work')
$t2 = Stamp $t2 'footer' (Render $ftrSrc '../../' '../../index.html' 'work')
if ((Norm $t2) -ne (Norm $t)) {
  $drift += 'tools/build-work.ps1'
  if (-not $Check) { [IO.File]::WriteAllText($tpl, $t2, (New-Object Text.UTF8Encoding $true)) }
}

if ($Check) {
  if ($drift) { "out of date (run sync-chrome.ps1): " + ($drift -join ', '); exit 1 } else { 'chrome in sync'; exit 0 }
}
"chrome stamped: $changed of $($targets.Count) pages changed" + $(if ($drift -contains 'tools/build-work.ps1') { ' + build-work template' } else { '' })
# The Work submenu lives inside the header; fill it now (pages + template).
& (Join-Path $PSScriptRoot 'sync-nav.ps1') -Root $Root
