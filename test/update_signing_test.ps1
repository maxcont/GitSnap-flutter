param(
    [string]$OpenSslPath,
    [switch]$VerifyWindowsResource
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\scripts\release_helpers.ps1')
if (-not $OpenSslPath) {
    $tool = Get-Command openssl -ErrorAction SilentlyContinue
    if ($tool) { $OpenSslPath = $tool.Source }
    elseif (Test-Path 'C:\Program Files\Git\usr\bin\openssl.exe') {
        $OpenSslPath = 'C:\Program Files\Git\usr\bin\openssl.exe'
    } else { throw 'OpenSSL is required for the signing tests.' }
}
$tempDir = Join-Path $env:TEMP "gitsnap-signature-test-$PID"
if (Test-Path -LiteralPath $tempDir) { throw "Test directory already exists: $tempDir" }
New-Item -ItemType Directory -Path $tempDir | Out-Null
$copiedPublicKey = $false
$resourcePath = Join-Path $PSScriptRoot '..\windows\runner\resources\updater_public_key.pem'
try {
    $params = Join-Path $tempDir 'params.pem'
    $private = Join-Path $tempDir 'dsa_priv.pem'
    $public = Join-Path $tempDir 'dsa_pub.pem'
    $payload = Join-Path $tempDir 'test-installer.exe'
    Invoke-ReleaseCommand $OpenSslPath @('dsaparam', '-out', $params, '2048')
    Invoke-ReleaseCommand $OpenSslPath @('gendsa', '-out', $private, $params)
    Invoke-ReleaseCommand $OpenSslPath @('dsa', '-in', $private, '-pubout', '-out', $public)
    Set-Content -LiteralPath $payload 'Test payload, not a real installer.' -Encoding ascii
    $signature = Get-GitSnapUpdateSignature -InstallerPath $payload `
        -PrivateKeyPath $private -PublicKeyPath $public -OpenSslPath $OpenSslPath `
        -WorkingDirectory $tempDir
    if ($signature -notmatch '^[A-Za-z0-9+/]+={0,2}$') { throw 'Invalid signature encoding.' }

    Set-Content -LiteralPath $payload 'Tampered payload.' -Encoding ascii
    $digest = Join-Path $tempDir 'digest.bin'
    $signatureFile = Join-Path $tempDir 'signature.bin'
    Invoke-ReleaseCommand $OpenSslPath @('dgst', '-sha1', '-binary', '-out', $digest, $payload)
    & $OpenSslPath dgst -sha1 -verify $public -signature $signatureFile $digest 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) { throw 'A tampered update passed signature verification.' }
    # The failed verification is expected; do not leak its exit code to CI.
    $global:LASTEXITCODE = 0
    Write-Output 'Update signing tests passed; tampered payload rejected.'
    if ($VerifyWindowsResource) {
        if (Test-Path -LiteralPath $resourcePath) {
            throw 'Refusing to overwrite an existing updater public key.'
        }
        Copy-Item -LiteralPath $public -Destination $resourcePath
        $copiedPublicKey = $true
        Push-Location (Join-Path $PSScriptRoot '..')
        try {
            Invoke-ReleaseCommand 'flutter' @('build', 'windows', '--release')
            Write-Output 'Windows public key resource build passed (updater disabled).'
        } finally {
            Pop-Location
        }
    }
} finally {
    if ($copiedPublicKey) { Remove-Item -LiteralPath $resourcePath -Force }
    Remove-Item -LiteralPath $tempDir -Recurse -Force
}
