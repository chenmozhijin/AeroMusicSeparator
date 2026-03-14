[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ReleaseDir,
    [Parameter(Mandatory = $true)][string]$Version,
    [Parameter(Mandatory = $true)][string]$Variant,
    [Parameter(Mandatory = $true)][string]$OutputDir
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$releasePath = (Resolve-Path $ReleaseDir).Path
$outputRoot = (New-Item -ItemType Directory -Path $OutputDir -Force).FullName
$outputPath = Join-Path $outputRoot "AeroMusicSeparator-$Version-windows-$Variant.zip"

if (Test-Path $outputPath) {
    Remove-Item $outputPath -Force
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory(
    $releasePath,
    $outputPath,
    [System.IO.Compression.CompressionLevel]::Optimal,
    $false
)

if (-not (Test-Path $outputPath)) {
    throw "Expected ZIP output at $outputPath"
}

Write-Host "Created $outputPath"
