# Packages the addon into output\Ribbon-<version>.zip, with a top-level Ribbon folder ready to drop into
# Interface\AddOns. Only the files the TOC loads plus its textures ship; src\probe (a local dev tool) and
# anything else not listed in the TOC is left out.
$ErrorActionPreference = 'Stop'

$root = $PSScriptRoot
$src = Join-Path $root 'src'
$toc = Join-Path $src 'Ribbon.toc'
$outDir = Join-Path $root 'output'

$version = (Select-String -Path $toc -Pattern '^##\s*Version:\s*(\S+)').Matches[0].Groups[1].Value
$zip = Join-Path $outDir "Ribbon-$version.zip"

# Stage a clean copy named Ribbon so the archive's top-level folder is correct.
$stage = Join-Path $outDir 'stage'
$addon = Join-Path $stage 'Ribbon'
if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }
New-Item -ItemType Directory -Force $addon | Out-Null

Copy-Item $toc $addon
Copy-Item (Join-Path $src 'icon.tga') $addon
Copy-Item (Join-Path $src 'textures') $addon -Recurse

# Every Lua file the TOC lists (lines that are not comments or directives), keeping its folder.
Get-Content $toc | Where-Object { $_ -match '\.lua\s*$' -and $_ -notmatch '^\s*#' } | ForEach-Object {
    $rel = $_.Trim()
    $from = Join-Path $src $rel
    if (-not (Test-Path $from)) { throw "TOC lists $rel but $from does not exist" }
    $to = Join-Path $addon $rel
    New-Item -ItemType Directory -Force (Split-Path $to) | Out-Null
    Copy-Item $from $to
}

if (Test-Path $zip) { Remove-Item $zip -Force }

# Entries are written with forward slashes (Windows PowerShell 5.1's Compress-Archive uses backslashes).
Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
$archive = [System.IO.Compression.ZipFile]::Open($zip, 'Create')
try {
    Get-ChildItem $addon -Recurse -File | ForEach-Object {
        $name = $_.FullName.Substring($stage.Length + 1).Replace('\', '/')
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, $_.FullName, $name, 'Optimal') | Out-Null
    }
} finally {
    $archive.Dispose()
}
Remove-Item $stage -Recurse -Force

Write-Host "Wrote $zip ($([math]::Round((Get-Item $zip).Length / 1KB, 1)) KB)"
