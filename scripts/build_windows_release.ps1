param(
    [Parameter(Mandatory)][string]$PrivateKeyPath,
    [string]$Repository = 'maxcont/GitSnap-flutter',
    [string]$Tag,
    [string]$IsccPath,
    [string]$OpenSslPath,
    [string]$RuntimeDirectory
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'release_helpers.ps1')
$projectRoot = Split-Path -Parent $PSScriptRoot
$release = Get-GitSnapRelease -PubspecPath (Join-Path $projectRoot 'pubspec.yaml') -Tag $Tag
$publicKeyPath = Join-Path $projectRoot 'windows\runner\resources\updater_public_key.pem'
if (-not (Test-Path -LiteralPath $PrivateKeyPath -PathType Leaf)) {
    throw 'Private signing key not found. Never commit the private key.'
}
$PrivateKeyPath = (Resolve-Path -LiteralPath $PrivateKeyPath).Path
if (-not (Test-Path -LiteralPath $publicKeyPath -PathType Leaf)) {
    throw 'Missing windows\runner\resources\updater_public_key.pem. Configure the public signing key first.'
}
if ($Repository -notmatch '^[A-Za-z0-9][A-Za-z0-9-]*/[A-Za-z0-9_.-]+$') {
    throw 'Repository must be a GitHub owner/repository slug.'
}
if (-not $OpenSslPath) {
    $tool = Get-Command openssl -ErrorAction SilentlyContinue
    if ($tool) { $OpenSslPath = $tool.Source }
    elseif (Test-Path 'C:\Program Files\Git\usr\bin\openssl.exe') {
        $OpenSslPath = 'C:\Program Files\Git\usr\bin\openssl.exe'
    } else { throw 'OpenSSL is required to sign and verify update packages.' }
}
if (-not $IsccPath) {
    $tool = Get-Command ISCC -ErrorAction SilentlyContinue
    if ($tool) { $IsccPath = $tool.Source }
    else {
        foreach ($candidate in @(
            "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
            "$env:ProgramFiles\Inno Setup 6\ISCC.exe",
            "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe"
        )) {
            if (Test-Path -LiteralPath $candidate) { $IsccPath = $candidate; break }
        }
        if (-not $RuntimeDirectory) {
            $RuntimeDirectory = Get-GitSnapRuntimeDirectory
        }
        $RuntimeDirectory = (Resolve-Path -LiteralPath $RuntimeDirectory).Path
    }
    if (-not $IsccPath) { throw 'Inno Setup 6.3 or newer is required (ISCC.exe).' }
}
$signingDir = Join-Path $env:TEMP "gitsnap-signing-$PID"
if (Test-Path -LiteralPath $signingDir) { throw "Signing directory already exists: $signingDir" }
New-Item -ItemType Directory -Path $signingDir | Out-Null
Push-Location $projectRoot
try {
    $derivedKey = Join-Path $signingDir 'public.pem'
    Invoke-ReleaseCommand $OpenSslPath @('dsa', '-pubin', '-in', $publicKeyPath, '-noout')
    Invoke-ReleaseCommand $OpenSslPath @('pkey', '-in', $PrivateKeyPath, '-pubout', '-out', $derivedKey)
    $expected = (Get-Content -LiteralPath $publicKeyPath -Raw) -replace '\s', ''
    $actual = (Get-Content -LiteralPath $derivedKey -Raw) -replace '\s', ''
    if ($actual -cne $expected) { throw 'Private signing key does not match the public key embedded in the app.' }

    $feedUrl = "https://github.com/$Repository/releases/latest/download/appcast.xml"
    Invoke-ReleaseCommand 'flutter' @(
        'build', 'windows', '--release',
        "--dart-define=GITSNAP_ENABLE_UPDATES=true",
        "--dart-define=GITSNAP_VERSION=$($release.Version)+$($release.BuildNumber)",
        "--dart-define=GITSNAP_UPDATE_FEED_URL=$feedUrl"
    )
    $buildSource = Join-Path $projectRoot 'build\windows\x64\runner\Release'
    Copy-GitSnapRuntime -RuntimeDirectory $RuntimeDirectory -BuildDirectory $buildSource
    $outputDir = Join-Path $projectRoot 'build\release'
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    Invoke-ReleaseCommand $IsccPath @(
        "/DAppVersion=$($release.Version)",
        "/DWindowsVersion=$($release.WindowsVersion)",
        "/DBuildSource=$buildSource",
        "/DOutputDirectory=$outputDir",
        (Join-Path $PSScriptRoot 'windows_installer.iss')
    )
    $installer = Join-Path $outputDir $release.InstallerName
    $signature = Get-GitSnapUpdateSignature -InstallerPath $installer `
        -PrivateKeyPath $PrivateKeyPath -PublicKeyPath $publicKeyPath `
        -OpenSslPath $OpenSslPath -WorkingDirectory $signingDir
    Write-GitSnapAppcast -Release $release -Repository $Repository -Signature $signature `
        -Length (Get-Item -LiteralPath $installer).Length `
        -Destination (Join-Path $outputDir 'appcast.xml')
    $hash = (Get-FileHash -LiteralPath $installer -Algorithm SHA256).Hash.ToLowerInvariant()
    "$hash  $($release.InstallerName)" |
        Set-Content -LiteralPath (Join-Path $outputDir 'SHA256SUMS.txt') -Encoding ascii
    Write-Output "Signed release ready: $installer"
} finally {
    Pop-Location
    Remove-Item -LiteralPath $signingDir -Recurse -Force
}
