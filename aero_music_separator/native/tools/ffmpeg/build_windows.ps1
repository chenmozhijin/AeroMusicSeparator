param(
  [ValidateSet("x64")]
  [string]$Arch = "x64",
  [string]$MsysRoot = ""
)

$ErrorActionPreference = "Stop"

$msysCandidates = @()
if (-not [string]::IsNullOrWhiteSpace($MsysRoot)) {
  $msysCandidates += $MsysRoot
}
if (-not [string]::IsNullOrWhiteSpace($env:MSYS2_LOCATION)) {
  $msysCandidates += $env:MSYS2_LOCATION
}
if (-not [string]::IsNullOrWhiteSpace($env:RUNNER_TEMP)) {
  $msysCandidates += (Join-Path $env:RUNNER_TEMP "msys64")
}
$msysCandidates += "C:\msys64"
$msysCandidates = $msysCandidates | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique

$resolvedMsysRoot = $null
foreach ($candidate in $msysCandidates) {
  $bashCandidate = Join-Path $candidate "usr\bin\bash.exe"
  $makeCandidate = Join-Path $candidate "usr\bin\make.exe"
  if ((Test-Path $bashCandidate) -and (Test-Path $makeCandidate)) {
    $resolvedMsysRoot = $candidate
    break
  }
}

if (-not $resolvedMsysRoot) {
  throw "MSYS2 with make.exe not found in candidates: $($msysCandidates -join ', '). Install MSYS2 packages or pass -MsysRoot."
}

$MsysRoot = $resolvedMsysRoot

$bashPath = Join-Path $MsysRoot "usr\bin\bash.exe"
if (-not (Test-Path $bashPath)) {
  throw "MSYS2 bash not found at $bashPath. Install MSYS2 or pass -MsysRoot."
}

$cygpathPath = Join-Path $MsysRoot "usr\bin\cygpath.exe"
if (-not (Test-Path $cygpathPath)) {
  throw "MSYS2 cygpath not found at $cygpathPath. Install MSYS2 or pass -MsysRoot."
}

$scriptRootWin = $PSScriptRoot
$scriptRootUnix = & $cygpathPath -u $scriptRootWin
$scriptRootUnix = $scriptRootUnix.Trim()
if (-not $scriptRootUnix -or -not $scriptRootUnix.StartsWith("/")) {
  throw "Failed to convert script path to MSYS2 format: '$scriptRootUnix'"
}

$env:MSYSTEM = "MINGW64"
$env:CHERE_INVOKING = "1"

$innerScript = "$scriptRootUnix/build_windows_msys.sh"
& $bashPath -lc "set -euo pipefail; chmod +x '$innerScript'; '$innerScript' '$Arch'"
