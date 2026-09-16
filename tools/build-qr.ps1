# Writes images/venmo-qr.svg: a QR for the Venmo profile named in
# tools/site.json ("venmo"). Renders tools/qr.html in headless Edge (needs
# the preview server, and internet for the QR library, like build-card),
# dumps the DOM and keeps the SVG. Run after changing the handle; not part
# of build.ps1 because the file only changes when the handle does.
param([string]$Root = (Split-Path $PSScriptRoot -Parent), [string]$Origin = 'http://localhost:8765')
$ErrorActionPreference = 'Stop'
$edge = 'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe'
$site = Get-Content (Join-Path $PSScriptRoot 'site.json') -Raw | ConvertFrom-Json
$v = [string]$site.venmo
if (-not $v) { throw 'set "venmo" in tools/site.json: the app''s QR URL, or the profile handle without the @' }
$url = if ($v -match '^https?://') { $v } else { "https://venmo.com/u/$v" }
try { $null = Invoke-WebRequest -Uri "$Origin/tools/qr.html" -Method Head -UseBasicParsing -TimeoutSec 5 } catch { throw "preview server not answering at $Origin (start it with preview_start / .claude/serve.ps1)" }
$profile = Join-Path $env:TEMP 'edge-qr-profile'
$page = "$Origin/tools/qr.html?text=" + [Uri]::EscapeDataString($url)
# Edge detaches from a PowerShell-captured stdout, so cmd redirects the dump to a file.
$dump = Join-Path $env:TEMP 'edge-qr-dom.html'
if (Test-Path $dump) { Remove-Item $dump -Force }
$eap = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
cmd /c "`"$edge`" --headless=new --disable-gpu --no-first-run --no-default-browser-check `"--user-data-dir=$profile`" --virtual-time-budget=4000 --dump-dom `"$page`" > `"$dump`" 2>nul"
$ErrorActionPreference = $eap
$dom = if (Test-Path $dump) { [IO.File]::ReadAllText($dump) } else { '' }
$m = [regex]::Match($dom, '<div id="out">(.*?)</div>', 'Singleline')
if (-not $m.Success -or $m.Groups[1].Value -notmatch '^&lt;svg') { throw 'no SVG in the dumped DOM (is the QR library reachable?)' }
$svg = [Net.WebUtility]::HtmlDecode($m.Groups[1].Value).Trim()
$out = Join-Path $Root 'images\venmo-qr.svg'
[IO.File]::WriteAllText($out, $svg + "`n", (New-Object Text.UTF8Encoding($false)))
"images/venmo-qr.svg  ($url)"
