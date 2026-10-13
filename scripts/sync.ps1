# Run Rojo and auto-pull new commits every few seconds (Windows).
# Usage: .\scripts\sync.ps1 [-Branch main]
param([string]$Branch = "main")
Set-Location (Join-Path $PSScriptRoot "..")

git fetch -q origin $Branch
git checkout -q $Branch
git pull -q --ff-only origin $Branch

$rojo = Start-Process rojo -ArgumentList "serve" -PassThru -NoNewWindow
Write-Host "Rojo running. Auto-pulling '$Branch' every 5s. Press Ctrl+C to stop."
try {
  while ($true) {
    Start-Sleep -Seconds 5
    git fetch -q origin $Branch 2>$null
    if ($LASTEXITCODE -ne 0) { continue }
    if ((git rev-parse HEAD) -ne (git rev-parse "origin/$Branch")) {
      git pull -q --ff-only origin $Branch
      Write-Host "Pulled new changes."
    }
  }
} finally {
  Stop-Process -Id $rojo.Id -ErrorAction SilentlyContinue
}
