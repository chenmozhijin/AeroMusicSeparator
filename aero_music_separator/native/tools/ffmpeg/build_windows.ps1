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

$scriptRootWin = $PSScriptRoot
$scriptRootUnix = & $bashPath -lc "cygpath -u '$($scriptRootWin -replace '\\','/')'"
$scriptRootUnix = $scriptRootUnix.Trim()
if (-not $scriptRootUnix) {
  throw "Failed to convert script path to MSYS2 format."
}

$env:MSYSTEM = "MINGW64"
$env:CHERE_INVOKING = "1"

$innerScript = "$scriptRootUnix/build_windows_msys.sh"
& $bashPath -lc "set -euo pipefail; chmod +x '$innerScript'; '$innerScript' '$Arch'"
