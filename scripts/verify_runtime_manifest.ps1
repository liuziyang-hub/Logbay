param(
  [string]$ToolsDirectory = "$(Split-Path -Parent $PSScriptRoot)\platform-tools\windows"
)

$ErrorActionPreference = 'Stop'
$required = @(
  (Join-Path $ToolsDirectory 'adb.exe'),
  (Join-Path $ToolsDirectory 'idevice_id.exe'),
  (Join-Path $ToolsDirectory 'ios-runtime\uv.exe')
)

foreach ($path in $required) {
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
    throw "Required bundled runtime is missing: $path"
  }
  if ((Get-Item -LiteralPath $path).Length -le 0) {
    throw "Bundled runtime is empty: $path"
  }
}

$iosManifestPath = Join-Path $ToolsDirectory 'ios-runtime\ios-runtime.json'
if (-not (Test-Path -LiteralPath $iosManifestPath -PathType Leaf)) {
  throw "iOS runtime manifest is missing: $iosManifestPath"
}
$iosManifest = Get-Content -Raw -LiteralPath $iosManifestPath | ConvertFrom-Json
$actualUv = (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $ToolsDirectory 'ios-runtime\uv.exe')).Hash.ToLowerInvariant()
if ($actualUv -ne $iosManifest.binarySha256) {
  throw "uv binary SHA-256 mismatch. Expected $($iosManifest.binarySha256), got $actualUv."
}

Write-Host 'Bundled runtime verification passed.'
