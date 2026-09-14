# Make responsive variants of every screenshot in /images using headless
# Edge (canvas -> WebP over the DevTools protocol; no ImageMagick needed).
#   name.webp (1440w, the true-size original, used by the lightbox)
#   name-960.webp   main image slot / large tiles
#   name-480.webp   thumbnails / small tiles / phones
# Re-runnable: skips variants that are newer than their source.
param(
  [string]$ImagesDir = (Join-Path (Split-Path $PSScriptRoot -Parent) 'images'),
  [int[]]$Widths = @(960, 480),
  [int]$Port = 9334,
  [string]$Origin = 'http://localhost:8765',   # local preview server (serves /images)
  [switch]$Force
)
$ErrorActionPreference = 'Stop'
$edge = 'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe'
$profile = Join-Path $env:TEMP 'edge-resize-profile'

$sources = Get-ChildItem $ImagesDir -Filter *.webp | Where-Object { $_.BaseName -notmatch '-(480|960)$' }
$todo = foreach ($s in $sources) {
  foreach ($w in $Widths) {
    $out = Join-Path $ImagesDir ("{0}-{1}.webp" -f $s.BaseName, $w)
    if ($Force -or -not (Test-Path $out) -or (Get-Item $out).LastWriteTime -lt $s.LastWriteTime) {
      [pscustomobject]@{ src = $s; width = $w; out = $out }
    }
  }
}
if (-not $todo) { 'nothing to do'; return }

$proc = Start-Process $edge -PassThru -ArgumentList @(
  '--headless=new', '--disable-gpu', '--no-first-run', '--no-default-browser-check',
  "--remote-debugging-port=$Port", "--user-data-dir=`"$profile`"", 'about:blank'
)
try {
  $target = $null
  for ($i = 0; $i -lt 30 -and -not $target; $i++) {
    Start-Sleep -Milliseconds 500
    try { $target = (Invoke-RestMethod "http://localhost:$Port/json") | Where-Object { $_.type -eq 'page' } | Select-Object -First 1 } catch {}
  }
  if (-not $target) { throw 'Edge did not expose a page target.' }
  $ws = New-Object System.Net.WebSockets.ClientWebSocket
  $ws.ConnectAsync([Uri]$target.webSocketDebuggerUrl, [Threading.CancellationToken]::None).Wait()
  $script:cid = 0
  function Invoke-Cdp([string]$method, [hashtable]$params = @{}) {
    $script:cid++; $id = $script:cid
    $json = (@{ id = $id; method = $method; params = $params } | ConvertTo-Json -Depth 6 -Compress)
    $bytes = [Text.Encoding]::UTF8.GetBytes($json)
    $ws.SendAsync([ArraySegment[byte]]::new($bytes), [Net.WebSockets.WebSocketMessageType]::Text, $true, [Threading.CancellationToken]::None).Wait()
    $buf = New-Object byte[] 1048576
    while ($true) {
      $ms = New-Object IO.MemoryStream
      do {
        $res = $ws.ReceiveAsync([ArraySegment[byte]]::new($buf), [Threading.CancellationToken]::None).Result
        $ms.Write($buf, 0, $res.Count)
      } while (-not $res.EndOfMessage)
      $text = [Text.Encoding]::UTF8.GetString($ms.ToArray())
      if ($text -match "^\{`"id`":$id,") { return $text }
    }
  }

  # Same-origin page so canvas isn't tainted by the image.
  $null = Invoke-Cdp 'Page.navigate' @{ url = "$Origin/404.html" }
  Start-Sleep -Seconds 2

  foreach ($t in $todo) {
    $q = if ($t.width -le 480) { 0.78 } else { 0.74 }
    $js = @"
(async () => {
  const img = new Image();
  img.src = '$Origin/images/$($t.src.Name)?v=' + Date.now();
  await img.decode();
  const w = $($t.width), h = Math.round(img.naturalHeight * w / img.naturalWidth);
  const c = document.createElement('canvas'); c.width = w; c.height = h;
  const ctx = c.getContext('2d'); ctx.imageSmoothingQuality = 'high';
  ctx.drawImage(img, 0, 0, w, h);
  return c.toDataURL('image/webp', $q).split(',')[1];
})()
"@
    $r = Invoke-Cdp 'Runtime.evaluate' @{ expression = $js; awaitPromise = $true; returnByValue = $true }
    if ($r -match '"value":"([A-Za-z0-9+/=]+)"') {
      $bytes = [Convert]::FromBase64String($Matches[1])
      [IO.File]::WriteAllBytes($t.out, $bytes)
      "{0,-34} {1,4}w  {2,4:N0} KB" -f (Split-Path $t.out -Leaf), $t.width, ($bytes.Length / 1KB)
    } else {
      "!! $($t.src.Name) @$($t.width): $($r.Substring(0, [Math]::Min(200, $r.Length)))"
    }
  }
  $ws.CloseAsync([Net.WebSockets.WebSocketCloseStatus]::NormalClosure, 'done', [Threading.CancellationToken]::None).Wait()
} finally {
  if ($proc -and -not $proc.HasExited) { Stop-Process -Id $proc.Id -Force }
}
