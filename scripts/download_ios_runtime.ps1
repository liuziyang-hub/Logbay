param(
  [string]$TargetDirectory = "$(Split-Path -Parent $PSScriptRoot)\platform-tools\windows\ios-runtime"
)

$ErrorActionPreference = 'Stop'
$uvVersion = '0.11.28'
$assetName = 'uv-x86_64-pc-windows-msvc.zip'
$baseUrl = "https://github.com/astral-sh/uv/releases/download/$uvVersion"
$archiveUrl = "$baseUrl/$assetName"
$checksumUrl = "$archiveUrl.sha256"
$temporaryDirectory = Join-Path ([System.IO.Path]::GetTempPath()) "logbay-uv-$([guid]::NewGuid())"
$archive = "$temporaryDirectory.zip"
$checksumFile = "$archive.sha256"

New-Item -ItemType Directory -Force -Path $TargetDirectory | Out-Null
try {
  Invoke-WebRequest -Uri $archiveUrl -OutFile $archive -TimeoutSec 90
  Invoke-WebRequest -Uri $checksumUrl -OutFile $checksumFile -TimeoutSec 30
  $expected = ((Get-Content -Raw -LiteralPath $checksumFile).Trim() -split '\s+')[0].ToLowerInvariant()
  $actual = (Get-FileHash -Algorithm SHA256 -LiteralPath $archive).Hash.ToLowerInvariant()
  if ($actual -ne $expected) {
    throw "uv SHA-256 mismatch. Expected $expected, got $actual."
  }
  Expand-Archive -LiteralPath $archive -DestinationPath $temporaryDirectory -Force
  $uv = Get-ChildItem -LiteralPath $temporaryDirectory -Recurse -Filter 'uv.exe' | Select-Object -First 1
  if ($null -eq $uv) { throw 'uv.exe was not found in the official release archive.' }
  Copy-Item -LiteralPath $uv.FullName -Destination (Join-Path $TargetDirectory 'uv.exe') -Force
  $binaryHash = (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $TargetDirectory 'uv.exe')).Hash.ToLowerInvariant()
  [ordered]@{
    schemaVersion = 1
    runtime = 'uv'
    version = $uvVersion
    source = $archiveUrl
    archiveSha256 = $actual
    binarySha256 = $binaryHash
    managedPackage = 'pymobiledevice3==11.15.4'
  } | ConvertTo-Json | Set-Content -Encoding utf8 (Join-Path $TargetDirectory 'ios-runtime.json')
} finally {
  Remove-Item -LiteralPath $archive -Force -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath $checksumFile -Force -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath $temporaryDirectory -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host "Managed iOS runtime bootstrap staged at $TargetDirectory"
