$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'release_helpers.ps1')
$projectRoot = Split-Path -Parent $PSScriptRoot
$release = Get-GitSnapRelease -PubspecPath (Join-Path $projectRoot 'pubspec.yaml')
$buildSource = Join-Path $projectRoot 'build\windows\x64\runner\Release'
$executable = Join-Path $buildSource 'gitsnap_flutter.exe'
if (-not (Test-Path -LiteralPath $executable -PathType Leaf)) {
    throw "Build non trovata. Esegui prima 'flutter build windows --release'."
}
$expectedVersion = "$($release.Version)+$($release.BuildNumber)"
if ((Get-Item -LiteralPath $executable).VersionInfo.FileVersion -ne $expectedVersion) {
    throw "La build non corrisponde a pubspec.yaml ($expectedVersion). Ricompila prima di distribuire."
}
$releaseDir = Join-Path $projectRoot "assets\release\output\GitSnap_v$($release.Version)_windows_x64"
if (Test-Path -LiteralPath $releaseDir) {
    throw "Release gia' esistente: $releaseDir. Non viene sovrascritta."
}
New-Item -ItemType Directory -Path $releaseDir | Out-Null
Copy-Item -Path "$buildSource\*" -Destination $releaseDir -Recurse -Force
$manual = Join-Path $projectRoot 'assets\release\Manuale Utente GitSnap.pdf'
if (Test-Path -LiteralPath $manual) {
    Copy-Item -LiteralPath $manual -Destination $releaseDir
} else {
    Write-Warning 'Manuale Utente non trovato.'
}
Write-Output "Release portabile creata: $releaseDir"
