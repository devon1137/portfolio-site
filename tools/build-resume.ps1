# Prints resume.html to Devon-Kubacki-Resume.pdf with headless Edge, using the
# page's own print stylesheet (so the PDF and the page never disagree).
# Needs the local preview server (tools/../.claude/serve.ps1 on :8765) so the
# stylesheet resolves. Run after editing resume.html; not part of build.ps1
# because the PDF is a binary and only changes when the resume does.
param([string]$Root = (Split-Path $PSScriptRoot -Parent), [string]$Origin = 'http://localhost:8765')
$ErrorActionPreference = 'Stop'
# Edge reports "N bytes written" on stderr; don't let PS 5.1 turn that into an error.
$edge = 'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe'
$out = Join-Path $Root 'Devon-Kubacki-Resume.pdf'
try { $null = Invoke-WebRequest -Uri "$Origin/resume.html" -Method Head -UseBasicParsing -TimeoutSec 5 } catch { throw "preview server not answering at $Origin (start it with preview_start / .claude/serve.ps1)" }
$profile = Join-Path $env:TEMP 'edge-pdf-profile'
if (Test-Path $out) { [IO.File]::Delete($out) }
$eap = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
& $edge --headless=new --disable-gpu --no-first-run --no-default-browser-check "--user-data-dir=$profile" --no-pdf-header-footer "--print-to-pdf=$out" ("$Origin/resume.html?print=" + [DateTimeOffset]::UtcNow.ToUnixTimeSeconds())
$ErrorActionPreference = $eap
for ($i = 0; $i -lt 40 -and -not (Test-Path $out); $i++) { Start-Sleep -Milliseconds 250 }
if (-not (Test-Path $out)) { throw 'Edge did not write the PDF' }
"{0}  ({1:N0} KB)" -f (Split-Path $out -Leaf), ((Get-Item $out).Length / 1KB)
