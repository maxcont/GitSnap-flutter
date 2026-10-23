function Get-GitSnapRelease {
    param(
        [Parameter(Mandatory)][string]$PubspecPath,
        [string]$Tag
    )
    $content = Get-Content -LiteralPath $PubspecPath -Raw
    if ($content -notmatch '(?m)^version:\s*((?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*))\+([1-9]\d*)\s*$') {
        throw 'pubspec.yaml must contain version: MAJOR.MINOR.PATCH+BUILD (stable versions only).'
    }
    $version = $Matches[1]
    $buildNumber = $Matches[2]
    foreach ($part in (($version -split '\.') + @($buildNumber))) {
        if ([long]$part -gt 65535) {
            throw 'Every Windows version component must be between 0 and 65535.'
        }
    }
    if ($Tag -and $Tag -cne "v$version") {
        throw "Tag '$Tag' does not match pubspec.yaml version 'v$version'."
    }
    [pscustomobject]@{
        Version = $version
        BuildNumber = [int]$buildNumber
        WindowsVersion = "$version.$buildNumber"
        Tag = "v$version"
        InstallerName = "GitSnap-$version-windows-x64-setup.exe"
    }
}

function Write-GitSnapAppcast {
    param(
        [Parameter(Mandatory)]$Release,
        [Parameter(Mandatory)][string]$Repository,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Signature,
        [Parameter(Mandatory)][long]$Length,
        [Parameter(Mandatory)][string]$Destination
    )
    if ($Repository -notmatch '^[A-Za-z0-9][A-Za-z0-9-]*/[A-Za-z0-9_.-]+$') {
        throw 'Repository must be a GitHub owner/repository slug.'
    }
    if ($Signature -notmatch '^[A-Za-z0-9+/]+={0,2}$' -or $Length -le 0) {
        throw 'A nonempty installer and a base64 update signature are required.'
    }
    $url = "https://github.com/$Repository/releases/download/$($Release.Tag)/$($Release.InstallerName)"
    @"
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>GitSnap updates</title>
    <link>https://github.com/$Repository/releases</link>
    <description>GitSnap stable Windows updates</description>
    <item>
      <title>GitSnap $($Release.Version)</title>
      <enclosure url="$url"
        sparkle:version="$($Release.WindowsVersion)"
        sparkle:shortVersionString="$($Release.Version)"
        sparkle:dsaSignature="$Signature"
        sparkle:installerArguments="/SP- /SILENT /SUPPRESSMSGBOXES /NORESTART"
        length="$Length" type="application/octet-stream" />
    </item>
  </channel>
</rss>
"@ | Set-Content -LiteralPath $Destination -Encoding utf8
}

function Invoke-ReleaseCommand {
    param(
        [Parameter(Mandatory)][string]$Executable,
        [string[]]$Arguments = @()
    )
    & $Executable @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Release command failed: $Executable (exit code $LASTEXITCODE)"
    }
}

function Get-GitSnapUpdateSignature {
    param(
        [Parameter(Mandatory)][string]$InstallerPath,
        [Parameter(Mandatory)][string]$PrivateKeyPath,
        [Parameter(Mandatory)][string]$PublicKeyPath,
        [Parameter(Mandatory)][string]$OpenSslPath,
        [Parameter(Mandatory)][string]$WorkingDirectory
    )
    $signaturePath = Join-Path $WorkingDirectory 'signature.bin'
    $digestPath = Join-Path $WorkingDirectory 'digest.bin'
    # WinSparkle 0.8.1 signs the SHA-1 digest, not the raw installer.
    Invoke-ReleaseCommand $OpenSslPath @('dgst', '-sha1', '-binary', '-out', $digestPath, $InstallerPath)
    Invoke-ReleaseCommand $OpenSslPath @('dgst', '-sha1', '-sign', $PrivateKeyPath, '-out', $signaturePath, $digestPath)
    Invoke-ReleaseCommand $OpenSslPath @('dgst', '-sha1', '-verify', $PublicKeyPath, '-signature', $signaturePath, $digestPath) | Out-Null
    $signature = & $OpenSslPath base64 -A -in $signaturePath
    if ($LASTEXITCODE -ne 0) { throw 'Failed to encode the update signature.' }
    $signature.Trim()
}

function Copy-GitSnapRuntime {
    param(
        [Parameter(Mandatory)][string]$RuntimeDirectory,
        [Parameter(Mandatory)][string]$BuildDirectory
    )
    foreach ($dll in @('msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll')) {
        if (-not (Test-Path -LiteralPath (Join-Path $RuntimeDirectory $dll) -PathType Leaf)) {
            throw "Missing redistributable runtime DLL: $dll in $RuntimeDirectory"
        }
    }
    if (-not (Test-Path -LiteralPath $BuildDirectory -PathType Container)) {
        throw "Build directory not found: $BuildDirectory"
    }
    # Copy the complete app-local CRT, including companion DLLs used by plugins.
    Copy-Item -Path (Join-Path $RuntimeDirectory '*.dll') -Destination $BuildDirectory -Force
}

function Get-GitSnapRuntimeDirectory {
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    if (-not (Test-Path -LiteralPath $vswhere -PathType Leaf)) {
        throw 'Visual Studio Installer vswhere.exe is required to locate redistributable runtime DLLs.'
    }
    $installation = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
    if ($LASTEXITCODE -ne 0 -or -not $installation) {
        throw 'Visual Studio C++ tools were not found.'
    }
    $redist = Join-Path $installation.Trim() 'VC\Redist\MSVC'
    if (Test-Path -LiteralPath $redist -PathType Container) {
        $versions = Get-ChildItem -LiteralPath $redist -Directory |
            Where-Object Name -Match '^\d+\.\d+\.\d+$' |
            Sort-Object { [version]$_.Name } -Descending
        foreach ($version in $versions) {
            $crt = Get-ChildItem -LiteralPath (Join-Path $version.FullName 'x64') -Directory -ErrorAction SilentlyContinue |
                Where-Object Name -Match '^Microsoft\.VC\d+\.CRT$' |
                Select-Object -First 1
            if ($crt) { return $crt.FullName }
        }
    }
    throw 'Visual Studio x64 redistributable CRT directory not found. Supply -RuntimeDirectory explicitly.'
}
