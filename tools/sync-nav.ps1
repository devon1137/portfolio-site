# Rewrites the two header submenus in every page and in the page templates:
#   Work    -> case studies from tools/work-src, grouped by "group", ordered by work-order.txt
#   Writing -> samples from tools/writing-src, grouped by "kind" (Articles / Fiction), ordered by writing-order.txt
# Each block sits between markers (<!--worksub-->…<!--/worksub-->, <!--writingsub-->…<!--/writingsub-->);
# a bare <a href="…">Work</a> / <a href="…">Writing</a> link is migrated on first run.
# Run after adding, renaming, or reordering a case study or sample; then run the builders
# (tools/build.ps1 does all of it in order).
param([string]$Root = (Split-Path $PSScriptRoot -Parent))
$ErrorActionPreference = 'Stop'
$utf8 = New-Object Text.UTF8Encoding $false
function Enc([string]$s) { [Net.WebUtility]::HtmlEncode($s) }
function ReadMeta([string]$dir, [string]$orderFile) {
  $order = @(Get-Content (Join-Path $PSScriptRoot $orderFile) | Where-Object { $_.Trim() } | ForEach-Object { $_.Trim() })
  $metas = @{}
  foreach ($slug in $order) {
    $raw = [IO.File]::ReadAllText((Join-Path $PSScriptRoot "$dir\$slug.html"), [Text.Encoding]::UTF8)
    $metas[$slug] = [regex]::Match($raw, '(?s)<!--meta\s*(\{.*?\})\s*-->').Groups[1].Value | ConvertFrom-Json
  }
  [pscustomobject]@{ order = $order; metas = $metas }
}

# ---- Work ----
$work = ReadMeta 'work-src' 'work-order.txt'
$groupOf = @{}; foreach ($slug in $work.order) { $groupOf[$slug] = if ($work.metas[$slug].group) { [string]$work.metas[$slug].group } else { 'Case studies' } }
$groupNames = @(); foreach ($slug in $work.order) { if ($groupNames -notcontains $groupOf[$slug]) { $groupNames += $groupOf[$slug] } }

function WorkBlock([string]$pre, [bool]$current) {
  $cur = if ($current) { ' aria-current="page"' } else { '' }
  $cols = foreach ($g in $groupNames) {
    $items = ($work.order | Where-Object { $groupOf[$_] -eq $g } | ForEach-Object { "            <li><a href=`"${pre}work/$_/`">$(Enc $work.metas[$_].title)</a></li>" }) -join "`n"
    "          <li class=`"sub-group`"><span class=`"sub-label eyebrow`">$(Enc $g)</span>`n            <ul>`n$items`n            </ul>`n          </li>"
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

# ---- Writing ----
$writing = ReadMeta 'writing-src' 'writing-order.txt'
$kindLabel = @{ Article = 'Articles'; Fiction = 'Fiction'; Excerpt = 'Excerpts' }
$kindOf = @{}; foreach ($slug in $writing.order) { $k = [string]$writing.metas[$slug].kind; $kindOf[$slug] = if ($kindLabel[$k]) { $kindLabel[$k] } else { $k } }
$kindNames = @(); foreach ($slug in $writing.order) { if ($kindNames -notcontains $kindOf[$slug]) { $kindNames += $kindOf[$slug] } }

function WritingBlock([string]$pre, [bool]$current) {
  $cur = if ($current) { ' aria-current="page"' } else { '' }
  $cols = foreach ($g in $kindNames) {
    $items = ($writing.order | Where-Object { $kindOf[$_] -eq $g } | ForEach-Object { $tag = if ($writing.metas[$_].tag) { " <span class=`"sub-tag`">$(Enc $writing.metas[$_].tag)</span>" } else { '' }; "            <li><a href=`"${pre}writing/$_/`">$(Enc $writing.metas[$_].title)$tag</a></li>" }) -join "`n"
    "          <li class=`"sub-group`"><span class=`"sub-label eyebrow`">$(Enc $g)</span>`n            <ul>`n$items`n            </ul>`n          </li>"
  }
  @"
<!--writingsub--><div class="has-sub">
        <a href="${pre}writing.html"$cur>Writing</a>
        <button class="sub-toggle" type="button" aria-expanded="false" aria-controls="writing-sub" aria-label="Show writing samples"></button>
        <ul class="submenu" id="writing-sub" aria-label="Writing samples">
$($cols -join "`n")
          <li class="all"><a href="${pre}writing.html">All writing &rarr;</a></li>
        </ul>
      </div><!--/writingsub-->
"@.TrimEnd()
}

$menus = @(
  @{ name = 'Work';    blockRx = [regex]'(?s)<!--worksub-->.*?<!--/worksub-->';       linkRx = [regex]'<a href="(?<pre>(?:\.\./\.\./|/)?)projects\.html"(?<cur> aria-current="page")?>Work</a>';    fn = ${function:WorkBlock};    dir = 'work';    page = 'projects.html' }
  @{ name = 'Writing'; blockRx = [regex]'(?s)<!--writingsub-->.*?<!--/writingsub-->'; linkRx = [regex]'<a href="(?<pre>(?:\.\./\.\./|/)?)writing\.html"(?<cur> aria-current="page")?>Writing</a>'; fn = ${function:WritingBlock}; dir = 'writing'; page = 'writing.html' }
)

$n = 0
$targets = @(Get-ChildItem (Join-Path $Root '*.html')) + @(Get-ChildItem (Join-Path $Root 'work\*\index.html') -ErrorAction SilentlyContinue) + @(Get-ChildItem (Join-Path $Root 'writing\*\index.html') -ErrorAction SilentlyContinue)
foreach ($f in $targets) {
  $c = [IO.File]::ReadAllText($f.FullName)
  $deep = ($f.FullName -like '*\work\*') -or ($f.FullName -like '*\writing\*')
  $pre = if ($f.Name -eq '404.html') { '/' } elseif ($deep) { '../../' } else { '' }
  foreach ($m in $menus) {
    $isSection = ($f.Name -eq $m.page) -or ($f.FullName -like "*\$($m.dir)\*")
    $block = (& $m.fn $pre $isSection) -replace '\$', '$$'
    if ($m.blockRx.IsMatch($c)) { $c = $m.blockRx.Replace($c, $block, 1) }
    elseif ($m.linkRx.IsMatch($c)) { $c = $m.linkRx.Replace($c, $block, 1) }
    else { "  no $($m.name) link: $($f.FullName)"; continue }
    # On a section page, mark its own submenu entry current.
    if ($f.FullName -like "*\$($m.dir)\*") {
      $slug = Split-Path (Split-Path $f.FullName -Parent) -Leaf
      $c = $c.Replace("<a href=`"../../$($m.dir)/$slug/`">", "<a href=`"../../$($m.dir)/$slug/`" aria-current=`"page`">")
    }
  }
  [IO.File]::WriteAllText($f.FullName, $c, $utf8); $n++
}
# The page templates in the generators (keep their BOM); each one's own section is "current".
foreach ($tp in @(@{ file = 'build-work.ps1'; section = 'Work' }, @{ file = 'build-writing.ps1'; section = 'Writing' })) {
  $tpl = Join-Path $PSScriptRoot $tp.file
  if (-not (Test-Path $tpl)) { continue }
  $t = [IO.File]::ReadAllText($tpl, [Text.Encoding]::UTF8)
  foreach ($m in $menus) {
    $block = (& $m.fn '../../' ($m.name -eq $tp.section)) -replace '\$', '$$'
    if ($m.blockRx.IsMatch($t)) { $t = $m.blockRx.Replace($t, $block, 1) } elseif ($m.linkRx.IsMatch($t)) { $t = $m.linkRx.Replace($t, $block, 1) }
  }
  [IO.File]::WriteAllText($tpl, $t, (New-Object Text.UTF8Encoding $true))
}
# The builders mark the current case study / sample themselves ({{SLUG}} handling).
"submenus written to $n pages + templates ($($work.order.Count) case studies, $($writing.order.Count) writing samples)"
