# The one command: regenerate everything that derives from a source file.
#   .\tools\build.ps1                 (set "origin" in tools/site.json once the site has a domain: og:image, canonical, sitemap.xml)
# Order matters: chrome + submenu first (the case-study template picks them
# up), then case studies, then the Gallery (reads work-src), then the sitemap.
param([string]$Origin = '')
$ErrorActionPreference = 'Stop'
$t = $PSScriptRoot
# The origin lives in tools/site.json (og:image, canonical, sitemap.xml all key off it); -Origin overrides for one run.
if (-not $Origin) { $Origin = ([string](Get-Content (Join-Path $t 'site.json') -Raw | ConvertFrom-Json).origin).TrimEnd('/') }
& (Join-Path $t 'sync-chrome.ps1')      # header/footer from tools/chrome, then sync-nav.ps1 for the Work submenu
& (Join-Path $t 'build-work.ps1')       # work/<slug>/index.html from tools/work-src
& (Join-Path $t 'build-writing.ps1')    # writing/<slug>/index.html + the list on writing.html, from tools/writing-src
& (Join-Path $t 'build-gallery.ps1')    # gallery.html bands from the case-study galleries
& (Join-Path $t 'build-sitemap.ps1') -Origin $Origin
& (Join-Path $t 'sync-chrome.ps1') -Check   # sanity: nothing left out of sync
