param(
  [ValidateSet("x64")]
  [string]$Arch = "x64",
  [string]$MsysRoot = "C:\msys64"
)

$ErrorActionPreference = "Stop"

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
