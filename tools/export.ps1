$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
& (Join-Path $PSScriptRoot 'setup.ps1') -WithExportTemplates
$version = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'godot-version.json') -Raw | ConvertFrom-Json
$godotPath = Join-Path $projectRoot ".tools/godot/Godot_v$($version.version)_win64_console.exe"
$buildDirectory = Join-Path $projectRoot 'builds/windows'
New-Item -ItemType Directory -Force -Path $buildDirectory | Out-Null
Set-Content -LiteralPath (Join-Path (Split-Path -Parent $buildDirectory) '.gdignore') -Value '' -Encoding ascii
& $godotPath --headless --path $projectRoot --editor --import
if ($LASTEXITCODE -ne 0) { throw 'Godot import failed' }
& $godotPath --headless --path $projectRoot --export-release 'Windows Desktop' "$buildDirectory/Starlantern.exe"
if ($LASTEXITCODE -ne 0) { throw 'Godot export failed' }
Copy-Item -LiteralPath (Join-Path $projectRoot 'THIRD_PARTY_NOTICES.txt') -Destination $buildDirectory -Force
Copy-Item -LiteralPath (Join-Path $projectRoot 'assets/fonts/OFL.txt') -Destination "$buildDirectory/FONT_LICENSE.txt" -Force
Copy-Item -LiteralPath (Join-Path $projectRoot 'assets/licenses/GODOT_COPYRIGHT.txt') -Destination $buildDirectory -Force
Copy-Item -LiteralPath (Join-Path $projectRoot 'docs/PLAY.txt') -Destination "$buildDirectory/PLAY.txt" -Force
Write-Host "Windows build ready: $buildDirectory/Starlantern.exe"
