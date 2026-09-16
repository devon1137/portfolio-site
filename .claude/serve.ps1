# Tiny static server for local preview (no Node/Python on this machine).
# Serves the site root on http://localhost:8765, index.html for folders,
# 404.html for misses, and answers POSTs with 200 so the agreement form's
# success state can be exercised locally (nothing is stored).
param([int]$Port = 8765)
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$mime = @{
  '.html'='text/html; charset=utf-8'; '.css'='text/css; charset=utf-8'; '.js'='text/javascript; charset=utf-8'
  '.json'='application/json'; '.xml'='application/xml'; '.txt'='text/plain; charset=utf-8'
  '.webp'='image/webp'; '.png'='image/png'; '.jpg'='image/jpeg'; '.jpeg'='image/jpeg'; '.gif'='image/gif'
  '.svg'='image/svg+xml'; '.ico'='image/x-icon'; '.pdf'='application/pdf'; '.woff2'='font/woff2'; '.woff'='font/woff'
}
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$Port/")
$listener.Start()
Write-Host "Serving $root on http://localhost:$Port/"
while ($listener.IsListening) {
  $ctx = $listener.GetContext()
  $req = $ctx.Request; $res = $ctx.Response
  try {
    if ($req.HttpMethod -eq 'POST') { $res.StatusCode = 200; $res.Close(); continue }
    $rel = [Uri]::UnescapeDataString($req.Url.AbsolutePath).TrimStart('/') -replace '/', '\'
    $path = Join-Path $root $rel
    if (Test-Path $path -PathType Container) { $path = Join-Path $path 'index.html' }
    elseif (-not (Test-Path $path) -and (Test-Path "$path.html")) { $path = "$path.html" }  # pretty URLs, like Netlify
    if (-not (Test-Path $path -PathType Leaf)) { $res.StatusCode = 404; $path = Join-Path $root '404.html' }
    $ext = [IO.Path]::GetExtension($path).ToLower()
    $res.ContentType = if ($mime.ContainsKey($ext)) { $mime[$ext] } else { 'application/octet-stream' }
    $bytes = [IO.File]::ReadAllBytes($path)
    $res.ContentLength64 = $bytes.Length
    if ($req.HttpMethod -ne 'HEAD') { $res.OutputStream.Write($bytes, 0, $bytes.Length) }
  } catch { $res.StatusCode = 500 }
  finally { $res.Close() }
}
