# create_release.ps1
# Crea la cartella di release con i file di build e il Manuale Utente

$ErrorActionPreference = "Stop"

$scriptDir    = Split-Path -Parent $MyInvocation.MyCommand.Definition
$projectRoot  = Split-Path -Parent $scriptDir

# Percorsi
$versionFile  = Join-Path $projectRoot "assets\release\release_version.md"
$buildSource  = Join-Path $projectRoot "build\windows\x64\runner\Release"
$pdfSource    = Join-Path $projectRoot "assets\release\Manuale Utente GitSnap.pdf"
$outputBase   = Join-Path $projectRoot "assets\release\output"

# --- Legge e incrementa la versione ---
$content = Get-Content $versionFile -Raw
if ($content -notmatch 'version=(\d+\.\d+)') {
    Write-Error "Formato versione non trovato in release_version.md (atteso: version=X.XX)"
    exit 1
}
$currentVersion = $Matches[1]

# Incrementa la parte decimale
$parts = $currentVersion -split '\.'
$major = $parts[0]
$minor = [int]$parts[1] + 1
$newVersion = "$major.$minor"

Write-Host "Versione corrente : $currentVersion"
Write-Host "Nuova versione    : $newVersion"

# --- Controlla che la build esista ---
if (-not (Test-Path $buildSource)) {
    Write-Error "Cartella di build non trovata: $buildSource`nEsegui prima 'flutter build windows --release'."
    exit 1
}

# --- Crea la cartella di output ---
$releaseFolderName = "GitSnap_v${newVersion}_windows_x64"
$releaseDir = Join-Path $outputBase $releaseFolderName

if (Test-Path $releaseDir) {
    Write-Host "La cartella '$releaseFolderName' esiste gia'. Sovrascrittura in corso..."
    Remove-Item $releaseDir -Recurse -Force
}

New-Item -ItemType Directory -Path $releaseDir | Out-Null
Write-Host "Cartella creata: $releaseDir"

# --- Copia i file di build ---
Write-Host "Copia output build..."
Copy-Item -Path "$buildSource\*" -Destination $releaseDir -Recurse -Force

# --- Copia il Manuale Utente ---
if (-not (Test-Path $pdfSource)) {
    Write-Warning "Manuale Utente non trovato: $pdfSource"
} else {
    Copy-Item -Path $pdfSource -Destination $releaseDir -Force
    Write-Host "Manuale Utente copiato."
}

# --- Aggiorna release_version.md ---
$newContent = $content -replace "version=$currentVersion", "version=$newVersion"
Set-Content $versionFile $newContent -NoNewline
Write-Host "Versione aggiornata in release_version.md."

Write-Host ""
Write-Host "Release '$releaseFolderName' creata con successo!"
Write-Host "Percorso: $releaseDir"
