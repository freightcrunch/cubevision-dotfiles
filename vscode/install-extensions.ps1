# ╔══════════════════════════════════════════════════════════════════════╗
# ║  VS Code / Windsurf Extensions Installer                            ║
# ║  Reads extensions.json and installs all recommended extensions       ║
# ║                                                                      ║
# ║  Usage:  .\vscode\install-extensions.ps1                             ║
# ║          .\vscode\install-extensions.ps1 -Editor windsurf            ║
# ╚══════════════════════════════════════════════════════════════════════╝

param(
    [ValidateSet("code", "windsurf")]
    [string]$Editor = "code"
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$extensionsFile = Join-Path $scriptDir "extensions.json"

if (-not (Test-Path $extensionsFile)) {
    Write-Host "[!] extensions.json not found at $extensionsFile" -ForegroundColor Red
    exit 1
}

# parse JSON (strip comments)
$jsonContent = (Get-Content $extensionsFile -Raw) -replace '//.*$' -replace '/\*[\s\S]*?\*/'
$extensions = ($jsonContent | ConvertFrom-Json).recommendations

Write-Host "Installing $($extensions.Count) extensions for $Editor..." -ForegroundColor Cyan

foreach ($ext in $extensions) {
    Write-Host "  Installing: $ext" -ForegroundColor Gray
    & $Editor --install-extension $ext --force 2>$null
}

Write-Host "`n[+] All extensions installed for $Editor." -ForegroundColor Green
