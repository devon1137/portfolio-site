# Renders tools/og-card.html to images/og-card.jpg (1200x630) with headless
# Edge, via the preview server so the site stylesheet's tokens resolve. Run
# after a palette change; not part of build.ps1 because the JPG is a binary
# that only changes when the card does.
param([string]$Root = (Split-Path $PSScriptRoot -Parent), [string]$Origin = 'http://localhost:8765')
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$edge = 'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe'
$png = Join-Path $env:TEMP 'og-card.png'
$out = Join-Path $Root 'images\og-card.jpg'
try { $null = Invoke-WebRequest -Uri "$Origin/tools/og-card.html" -Method Head -UseBasicParsing -TimeoutSec 5 } catch { throw "preview server not answering at $Origin (start it with preview_start / .claude/serve.ps1)" }
$profile = Join-Path $env:TEMP 'edge-og-profile'
if (Test-Path $png) { [IO.File]::Delete($png) }
$eap = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
& $edge --headless=new --disable-gpu --no-first-run --no-default-browser-check "--user-data-dir=$profile" --hide-scrollbars --window-size=1200,630 "--screenshot=$png" ("$Origin/tools/og-card.html?v=" + [DateTimeOffset]::UtcNow.ToUnixTimeSeconds())
$ErrorActionPreference = $eap
for ($i = 0; $i -lt 40 -and -not (Test-Path $png); $i++) { Start-Sleep -Milliseconds 250 }
if (-not (Test-Path $png)) { throw 'Edge did not write the screenshot' }
# PNG -> JPEG at quality 88 (the card is a photo plus flat colour; ~100 KB)
$img = [System.Drawing.Image]::FromFile($png)
$codec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
$params = New-Object System.Drawing.Imaging.EncoderParameters 1
$params.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter ([System.Drawing.Imaging.Encoder]::Quality, [long]88)
if (Test-Path $out) { [IO.File]::Delete($out) }
$img.Save($out, $codec, $params)
$img.Dispose()
"{0}  {1}x{2}  ({3:N0} KB)" -f (Split-Path $out -Leaf), 1200, 630, ((Get-Item $out).Length / 1KB)
