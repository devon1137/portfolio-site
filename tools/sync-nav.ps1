# Rewrites the Work submenu (the case-study list under "Work" in the header)
# in every page and in the case-study template, from tools/work-src metadata.
# The block sits between <!--worksub--> and <!--/worksub--> markers. Run this
# after adding, renaming, or reordering a case study; then run build-work.ps1.
param([string]$Root = (Split-Path $PSScriptRoot -Parent))
$ErrorActionPreference = 'Stop'
$order = @(Get-Content (Join-Path $PSScriptRoot 'work-order.txt') | Where-Object { $_.Trim() } | ForEach-Object { $_.Trim() })   # one slug per line: the case-study order, used by every tool
$titles = @{}; $groupOf = @{}
foreach ($slug in $order) {
  $raw = [IO.File]::ReadAllText((Join-Path $PSScriptRoot "work-src\$slug.html"))
  $meta = [regex]::Match($raw, '(?s)<!--meta\s*(\{.*?\})\s*-->').Groups[1].Value | ConvertFrom-Json
  $titles[$slug] = [Net.WebUtility]::HtmlEncode($meta.title)
  $groupOf[$slug] = if ($meta.group) { [string]$meta.group } else { 'Case studies' }
}
# Groups in first-seen order (per work-order.txt), each a column in the panel.
$groupNames = @(); foreach ($slug in $order) { if ($groupNames -notcontains $groupOf[$slug]) { $groupNames += $groupOf[$slug] } }

function Block([string]$pre, [bool]$workCurrent) {
  $cur = if ($workCurrent) { ' aria-current="page"' } else { '' }
  $cols = foreach ($g in $groupNames) {
    $items = ($order | Where-Object { $groupOf[$_] -eq $g } | ForEach-Object { "            <li><a href=`"${pre}work/$_/`">$($titles[$_])</a></li>" }) -join "`n"
    "          <li class=`"sub-group`"><span class=`"sub-label eyebrow`">$([Net.WebUtility]::HtmlEncode($g))</span>`n            <ul>`n$items`n            </ul>`n          </li>"
  }
  @"
<!--worksub--><div class="has-sub">
        <a href="${pre}projects.html"$cur>Work</a>
        <button class="sub-toggle" type="button" aria-expanded="false" aria-controls="work-sub" aria-label="Show case studies"></button>
        <ul class="submenu" id="work-sub" aria-label="Case studies">
$($cols -join "`n")
          <li class="all"><a href="${pre}projects.html">All work &rarr;</a></li>
        </ul>
      </div><!--/worksub-->
"@.TrimEnd()
}

$utf8 = New-Object Text.UTF8Encoding $false
$linkRx = [regex]'<a href="(?<pre>(?:\.\./\.\./|/)?)projects\.html"(?<cur> aria-current="page")?>Work</a>'
$blockRx = [regex]'(?s)<!--worksub-->.*?<!--/worksub-->'
$n = 0
$targets = @(Get-ChildItem (Join-Path $Root '*.html')) + @(Get-ChildItem (Join-Path $Root 'work\*\index.html') -ErrorAction SilentlyContinue)
foreach ($f in $targets) {
  $c = [IO.File]::ReadAllText($f.FullName)
  $pre = if ($f.Name -eq '404.html') { '/' } elseif ($f.FullName -like '*\work\*') { '../../' } else { '' }
  $isWork = ($f.Name -eq 'projects.html') -or ($f.FullName -like '*\work\*')
  $block = Block $pre $isWork
  if ($blockRx.IsMatch($c)) { $c = $blockRx.Replace($c, ($block -replace '\$', '$$'), 1) }
  elseif ($linkRx.IsMatch($c)) { $c = $linkRx.Replace($c, ($block -replace '\$', '$$'), 1) }
  else { "  no Work link: $($f.FullName)"; continue }
  # On a case-study page, mark its own submenu entry current.
  if ($f.FullName -like '*\work\*') {
    $slug = Split-Path (Split-Path $f.FullName -Parent) -Leaf
    $c = $c.Replace("<a href=`"../../work/$slug/`">", "<a href=`"../../work/$slug/`" aria-current=`"page`">")
  }
  [IO.File]::WriteAllText($f.FullName, $c, $utf8); $n++
}
# The case-study template in build-work.ps1 (keeps its BOM)
$tpl = Join-Path $PSScriptRoot 'build-work.ps1'
$t = [IO.File]::ReadAllText($tpl, [Text.Encoding]::UTF8)
$block = (Block '../../' $true) -replace '\$', '$$'
if ($blockRx.IsMatch($t)) { $t = $blockRx.Replace($t, $block, 1) } else { $t = $linkRx.Replace($t, $block, 1) }
# build-work marks the current case study itself (see its {{SLUG}} handling)
[IO.File]::WriteAllText($tpl, $t, (New-Object Text.UTF8Encoding $true))
"submenu written to $n pages + build-work template ($($order.Count) case studies)"
