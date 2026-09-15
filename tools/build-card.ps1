# Prints tools/business-card.html to Devon-Kubacki-Business-Card.pdf with
# headless Edge: page 1 is the front, page 2 the back, each 3.75 x 2.25 in
# (3.5 x 2 trim plus 0.125 in bleed on every side). Needs the preview server
# so the site stylesheet resolves, and internet for the QR library.
param([string]$Root = (Split-Path $PSScriptRoot -Parent), [string]$Origin = 'http://localhost:8765')
$ErrorActionPreference = 'Stop'
$edge = 'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe'
$out = Join-Path $Root 'Devon-Kubacki-Business-Card.pdf'
try { $null = Invoke-WebRequest -Uri "$Origin/tools/business-card.html" -Method Head -UseBasicParsing -TimeoutSec 5 } catch { throw "preview server not answering at $Origin (start it with preview_start / .claude/serve.ps1)" }
$profile = Join-Path $env:TEMP 'edge-card-profile'
if (Test-Path $out) { [IO.File]::Delete($out) }
$eap = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
& $edge --headless=new --disable-gpu --no-first-run --no-default-browser-check "--user-data-dir=$profile" --no-pdf-header-footer --virtual-time-budget=4000 "--print-to-pdf=$out" ("$Origin/tools/business-card.html?print=" + [DateTimeOffset]::UtcNow.ToUnixTimeSeconds())
$ErrorActionPreference = $eap
for ($i = 0; $i -lt 40 -and -not (Test-Path $out); $i++) { Start-Sleep -Milliseconds 250 }
if (-not (Test-Path $out)) { throw 'Edge did not write the PDF' }
"{0}  ({1:N0} KB)  3.75 x 2.25 in with bleed; trim 3.5 x 2" -f (Split-Path $out -Leaf), ((Get-Item $out).Length / 1KB)
