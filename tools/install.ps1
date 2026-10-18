# Mirrors src/ into the game's AddOns\Ribbon folder. Tests and tools never ship.
# Usage: powershell -File tools/install.ps1 [-AddOns "<path to Interface\AddOns>"]
param(
  [string]$AddOns = 'C:\Program Files (x86)\World of Warcraft\_classic_beta_\Interface\AddOns'
)
$src = Join-Path $PSScriptRoot '..\src'
$dst = Join-Path $AddOns 'Ribbon'
if (-not (Test-Path $AddOns)) { throw "AddOns folder not found: $AddOns" }
if (Test-Path $dst) { Remove-Item $dst -Recurse -Force }
Copy-Item $src $dst -Recurse
Get-ChildItem $dst -Recurse -File | ForEach-Object { $_.FullName.Substring($dst.Length + 1) }
