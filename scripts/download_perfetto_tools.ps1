param(
  [string]$TargetDirectory = "$(Split-Path -Parent $PSScriptRoot)\platform-tools\windows"
)

$ErrorActionPreference = 'Stop'
$version = 'v55.3'
$archiveSha256 = 'e14f9fad47020670642e543bc2e58d9aedad8592322dda94ed1cda52f5954ea9'
$url = "https://github.com/google/perfetto/releases/download/$version/windows-amd64.zip"
$destination = Join-Path $TargetDirectory 'trace_processor_shell.exe'
$temporaryDirectory = Join-Path ([System.IO.Path]::GetTempPath()) "logbay-perfetto-$([guid]::NewGuid())"
$archive = "$temporaryDirectory.zip"

New-Item -ItemType Directory -Force -Path $TargetDirectory | Out-Null
try {
  Invoke-WebRequest -Uri $url -OutFile $archive -TimeoutSec 60
  $actualArchive = (Get-FileHash -Algorithm SHA256 -LiteralPath $archive).Hash.ToLowerInvariant()
  if ($actualArchive -ne $archiveSha256) {
    throw "Perfetto SHA-256 mismatch. Expected $archiveSha256, got $actualArchive."
  }
  Expand-Archive -LiteralPath $archive -DestinationPath $temporaryDirectory -Force
  $binary = Get-ChildItem -LiteralPath $temporaryDirectory -Recurse -Filter 'trace_processor_shell.exe' | Select-Object -First 1
  if ($null -eq $binary) { throw 'trace_processor_shell.exe was not found in the release archive.' }
  Copy-Item -LiteralPath $binary.FullName -Destination $destination -Force
} finally {
  Remove-Item -LiteralPath $archive -Force -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath $temporaryDirectory -Recurse -Force -ErrorAction SilentlyContinue
}
$binarySha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $destination).Hash.ToLowerInvariant()

$manifest = [ordered]@{
  name = 'trace_processor_shell'
  version = $version
  platform = 'windows-amd64'
  file = 'trace_processor_shell.exe'
  archiveSha256 = $archiveSha256
  binarySha256 = $binarySha256
}
$manifest | ConvertTo-Json | Set-Content -Encoding utf8 (
  Join-Path $TargetDirectory 'perfetto-runtime.json'
)
Write-Host "Perfetto $version staged at $destination"
