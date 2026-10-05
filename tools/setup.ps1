param([switch]$WithExportTemplates)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$version = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'godot-version.json') -Raw | ConvertFrom-Json
$localTools = Join-Path $projectRoot '.tools'
New-Item -ItemType Directory -Force -Path "$localTools/downloads", "$localTools/godot", "$localTools/templates" | Out-Null

function Get-VerifiedArchive($asset) {
    $archive = Join-Path "$localTools/downloads" $asset.file
    if (-not (Test-Path -LiteralPath $archive)) {
        $url = "https://github.com/godotengine/godot-builds/releases/download/$($version.version)/$($asset.file)"
        Write-Host "Downloading $($asset.file)..."
        Invoke-WebRequest -Uri $url -OutFile "$archive.tmp" -UseBasicParsing
        $hash = (Get-FileHash -LiteralPath "$archive.tmp" -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($hash -ne $asset.sha256) { throw "Checksum mismatch: $($asset.file)" }
        Move-Item -LiteralPath "$archive.tmp" -Destination $archive -Force
    }
    $hash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($hash -ne $asset.sha256) { throw "Checksum mismatch: $($asset.file)" }
    return $archive
}

$editorPath = Join-Path "$localTools/godot" "Godot_v$($version.version)_win64.exe"
if (-not (Test-Path -LiteralPath $editorPath)) {
    $archive = Get-VerifiedArchive $version.editor
    Expand-Archive -LiteralPath $archive -DestinationPath "$localTools/godot" -Force
}
if ($WithExportTemplates -and -not (Test-Path -LiteralPath "$localTools/templates/windows_release_x86_64.exe")) {
    $archive = Get-VerifiedArchive $version.templates
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [System.IO.Compression.ZipFile]::OpenRead($archive)
    try {
        foreach ($name in @('windows_debug_x86_64.exe', 'windows_release_x86_64.exe')) {
            $entry = $zip.Entries | Where-Object { $_.Name -eq $name } | Select-Object -First 1
            if (-not $entry) { throw "Missing template: $name" }
            [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, "$localTools/templates/$name", $true)
        }
    } finally { $zip.Dispose() }
}
Write-Host "Godot $($version.version) ready: $editorPath"
