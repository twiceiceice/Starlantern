$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
& (Join-Path $PSScriptRoot 'setup.ps1')
$version = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'godot-version.json') -Raw | ConvertFrom-Json
$godotPath = Join-Path $projectRoot ".tools/godot/Godot_v$($version.version)_win64_console.exe"

function Invoke-CheckedGodot([string[]]$arguments, [string]$name) {
    $logPath = Join-Path $projectRoot ".tools/$name.log"
    # Godot sometimes exits with zero for script errors; also inspect its output.
    $output = & $godotPath @arguments 2>&1
    $result = $LASTEXITCODE
    $output | Set-Content -LiteralPath $logPath -Encoding utf8
    $output | ForEach-Object { Write-Host $_ }
    if ($result -ne 0 -or ($output -match 'SCRIPT ERROR:|ERROR:|FAIL:')) {
        throw "Godot check failed: $name (exit $result); see $logPath"
    }
}

Invoke-CheckedGodot @('--headless', '--path', $projectRoot, '--editor', '--import') 'import'
Invoke-CheckedGodot @('--headless', '--path', $projectRoot, '--fixed-fps', '60', '--script', 'res://tests/run_tests.gd') 'tests'
Invoke-CheckedGodot @('--headless', '--path', $projectRoot, '--fixed-fps', '60', '--', '--smoke') 'smoke'
Write-Host 'All Godot checks passed.'
