# Imports non-screenshot images (JPG/PNG creatives, photos) into /images as
# WebP, capped at -MaxWidth, via headless Edge canvas. Then run
# resize-images.ps1 to make the 960/480 variants.
#   .\tools\import-images.ps1 -Map @{ 'apw-cubs-wash' = 'S:\...\The Cub''s Washv3.jpg'; ... }
#   .\tools\import-images.ps1 -Map @{ 'devon' = @{ path = '...jpg'; crop = 'x,y,w,h' } } -MaxWidth 960   (crop first)
param(
  [Parameter(Mandatory = $true)][hashtable]$Map,   # name (no extension) -> source path
  [int]$MaxWidth = 1440,
  [double]$Quality = 0.8,
  [string]$ImagesDir = (Join-Path (Split-Path $PSScriptRoot -Parent) 'images'),
  [int]$Port = 9335
)
$ErrorActionPreference = 'Stop'
$edge = 'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe'
$profile = Join-Path $env:TEMP 'edge-import-profile'
$proc = Start-Process $edge -PassThru -ArgumentList @('--headless=new', '--disable-gpu', '--no-first-run', '--no-default-browser-check', '--allow-file-access-from-files', "--remote-debugging-port=$Port", "--user-data-dir=`"$profile`"", 'about:blank')
try {
  $target = $null
  for ($i = 0; $i -lt 30 -and -not $target; $i++) { Start-Sleep -Milliseconds 500; try { $target = (Invoke-RestMethod "http://localhost:$Port/json") | Where-Object { $_.type -eq 'page' } | Select-Object -First 1 } catch {} }
  if (-not $target) { throw 'Edge did not expose a page target.' }
  $ws = New-Object System.Net.WebSockets.ClientWebSocket
  $ws.ConnectAsync([Uri]$target.webSocketDebuggerUrl, [Threading.CancellationToken]::None).Wait()
  $script:cid = 0
  function Invoke-Cdp([string]$method, [hashtable]$params = @{}) {
    $script:cid++; $id = $script:cid
    $json = (@{ id = $id; method = $method; params = $params } | ConvertTo-Json -Depth 6 -Compress)
    $bytes = [Text.Encoding]::UTF8.GetBytes($json)
    $ws.SendAsync([ArraySegment[byte]]::new($bytes), [Net.WebSockets.WebSocketMessageType]::Text, $true, [Threading.CancellationToken]::None).Wait()
    $buf = New-Object byte[] 4194304
    while ($true) {
      $ms = New-Object IO.MemoryStream
      do { $res = $ws.ReceiveAsync([ArraySegment[byte]]::new($buf), [Threading.CancellationToken]::None).Result; $ms.Write($buf, 0, $res.Count) } while (-not $res.EndOfMessage)
      $text = [Text.Encoding]::UTF8.GetString($ms.ToArray())
      if ($text -match "^\{`"id`":$id,") { return $text }
    }
  }
  foreach ($name in $Map.Keys) {
    # A value is a path, or @{ path = '...'; crop = 'x,y,w,h' } (crop in source pixels, applied before scaling).
    $spec = $Map[$name]
    $srcPath = if ($spec -is [hashtable]) { $spec.path } else { $spec }
    $crop = if ($spec -is [hashtable] -and $spec.crop) { ($spec.crop -split ',') | ForEach-Object { [int]$_ } } else { $null }
    $rotate = if ($spec -is [hashtable] -and $spec.rotate) { [int]$spec.rotate } else { 0 }   # 90 / -90 / 180, applied before the crop (crop is in rotated pixels)
    $src = (Resolve-Path $srcPath).Path
    # Feed the image as a data: URL so no file:// or server access is needed.
    $ext = [IO.Path]::GetExtension($src).ToLower().TrimStart('.'); if ($ext -eq 'jpg') { $ext = 'jpeg' }
    $b64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($src))
    $cropJs = if ($crop) { "const sx = $($crop[0]), sy = $($crop[1]), sw = $($crop[2]), sh = $($crop[3]);" } else { 'const sx = 0, sy = 0, sw = img.naturalWidth, sh = img.naturalHeight;' }
    $js = @"
(async () => {
  const src = new Image(); src.src = 'data:image/$ext;base64,$b64'; await src.decode();
  // Optional rotation into an intermediate canvas; everything after works on the rotated pixels.
  const rot = $rotate; let img = src;
  if (rot) {
    const swap = Math.abs(rot) === 90;
    const rc = document.createElement('canvas'); rc.width = swap ? src.naturalHeight : src.naturalWidth; rc.height = swap ? src.naturalWidth : src.naturalHeight;
    const rctx = rc.getContext('2d'); rctx.translate(rc.width / 2, rc.height / 2); rctx.rotate(rot * Math.PI / 180); rctx.drawImage(src, -src.naturalWidth / 2, -src.naturalHeight / 2);
    img = rc; img.naturalWidth = rc.width; img.naturalHeight = rc.height;
  }
  $cropJs
  const s = Math.min(1, $MaxWidth / sw);
  const w = Math.round(sw * s), h = Math.round(sh * s);
  const c = document.createElement('canvas'); c.width = w; c.height = h;
  const ctx = c.getContext('2d'); ctx.imageSmoothingQuality = 'high'; ctx.drawImage(img, sx, sy, sw, sh, 0, 0, w, h);
  return w + 'x' + h + '|' + c.toDataURL('image/webp', $Quality).split(',')[1];
})()
"@
    $r = Invoke-Cdp 'Runtime.evaluate' @{ expression = $js; awaitPromise = $true; returnByValue = $true }
    if ($r -match '"value":"(\d+x\d+)\|([A-Za-z0-9+/=]+)"') {
      $bytes = [Convert]::FromBase64String($Matches[2]); $out = Join-Path $ImagesDir "$name.webp"
      [IO.File]::WriteAllBytes($out, $bytes); "{0,-30} {1,-10} {2,5:N0} KB  <- {3}" -f "$name.webp", $Matches[1], ($bytes.Length / 1KB), (Split-Path $src -Leaf)
    } else { "!! $name : $($r.Substring(0, [Math]::Min(200, $r.Length)))" }
  }
  $ws.CloseAsync([Net.WebSockets.WebSocketCloseStatus]::NormalClosure, 'done', [Threading.CancellationToken]::None).Wait()
} finally { if ($proc -and -not $proc.HasExited) { Stop-Process -Id $proc.Id -Force } }
