param([switch]$Editor)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
& (Join-Path $PSScriptRoot 'setup.ps1')
$version = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'godot-version.json') -Raw | ConvertFrom-Json
$godotPath = Join-Path $projectRoot ".tools/godot/Godot_v$($version.version)_win64.exe"
if (-not $Editor) {
    $consolePath = Join-Path $projectRoot ".tools/godot/Godot_v$($version.version)_win64_console.exe"
    $importOutput = & $consolePath --headless --path $projectRoot --editor --import 2>&1
    $importExit = $LASTEXITCODE
    $importOutput | Set-Content -LiteralPath (Join-Path $projectRoot '.tools/launch-import.log') -Encoding utf8
    if ($importExit -ne 0 -or ($importOutput -match 'SCRIPT ERROR:|ERROR:')) {
        throw 'Project import failed. See .tools/launch-import.log.'
    }
}
$launchArgs = @('--path', ('"' + $projectRoot + '"'))
if ($Editor) { $launchArgs += '--editor' }
# This launcher opens the interactive game/editor requested by the user.
Start-Process -FilePath $godotPath -ArgumentList $launchArgs -WorkingDirectory $projectRoot
