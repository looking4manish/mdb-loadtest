<#
  loadgen deploy script — Windows (PowerShell)

    .\deploy.ps1                 # create venv + install dependencies
    .\deploy.ps1 -Run            # ...then start the web app
    .\deploy.ps1 -Run -Port 9000

  Requires Python 3.10+ (the 'py' launcher or 'python' on PATH).
  Note: some Windows builds reserve port 8000 (winerror 10013). If the app
  fails to bind, pass another port, e.g. -Port 8077.
#>
[CmdletBinding()]
param(
  [int]$Port = 8000,
  [string]$BindHost = "127.0.0.1",
  [switch]$Run
)
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

# --- locate a Python interpreter -------------------------------------------
function Resolve-Python {
  foreach ($cand in @("py -3", "python", "python3")) {
    $parts = $cand.Split(" ")
    $exe = $parts[0]
    if (Get-Command $exe -ErrorAction SilentlyContinue) {
      try {
        $v = & $exe @($parts[1..($parts.Length-1)]) "-c" "import sys;print(sys.version_info[0],sys.version_info[1])" 2>$null
        if ($LASTEXITCODE -eq 0 -and $v) { return ,$cand }
      } catch {}
    }
  }
  return $null
}

$pyCmd = Resolve-Python
if (-not $pyCmd) {
  Write-Error "Python 3.10+ not found. Install from https://python.org (check 'Add to PATH'), or 'winget install Python.Python.3.13'."
  exit 1
}
Write-Host "==> Using Python launcher: $pyCmd"

# --- create venv + install --------------------------------------------------
$pyParts = $pyCmd.Split(" ")
Write-Host "==> Creating virtual environment at .\venv"
& $pyParts[0] @($pyParts[1..($pyParts.Length-1)]) -m venv venv

$venvPy = ".\venv\Scripts\python.exe"
Write-Host "==> Upgrading pip + installing requirements"
& $venvPy -m pip install --upgrade pip | Out-Null
& $venvPy -m pip install -r requirements.txt

Write-Host "==> Verifying dependencies"
& $venvPy -c "import pymongo, fastapi, uvicorn, apscheduler; print('   deps OK - pymongo', pymongo.version)"

# Find the first port uvicorn can actually bind, starting at $Port. This skips
# ports in use AND Windows excluded/reserved ranges (winerror 10013).
$freePort = (& $venvPy freeport.py $Port).Trim()
if (-not $freePort) {
  Write-Error "No bindable port found at/above $Port. Try a different -Port."
  exit 1
}
if ($freePort -ne "$Port") {
  Write-Host "==> Port $Port unavailable (in use or reserved); using $freePort instead."
}
$url = "http://${BindHost}:$freePort/"

Write-Host ""
Write-Host "Deploy complete. Start the app with:"
Write-Host "    .\venv\Scripts\python.exe -m uvicorn app:app --host $BindHost --port $freePort"
Write-Host "Then open: $url"

if ($Run) {
  Write-Host ""
  Write-Host "==> Starting loadgen - open $url   (Ctrl+C to stop)"
  & $venvPy -m uvicorn app:app --host $BindHost --port $freePort
}
