$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\scripts\release_helpers.ps1')

function Assert-True($Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Assert-Throws([scriptblock]$Action, [string]$Message) {
    $threw = $false
    try { & $Action | Out-Null } catch { $threw = $true }
    Assert-True $threw $Message
}

$tempDir = Join-Path $env:TEMP "gitsnap-release-test-$PID"
if (Test-Path $tempDir) { throw "Test directory already exists: $tempDir" }
New-Item -ItemType Directory -Path $tempDir | Out-Null
try {
    $pubspec = Join-Path $tempDir 'pubspec.yaml'
    Set-Content $pubspec 'version: 1.2.3+4'
    $release = Get-GitSnapRelease -PubspecPath $pubspec -Tag 'v1.2.3'
    Assert-True ($release.Version -eq '1.2.3') 'Incorrect release version'
    Assert-True ($release.BuildNumber -eq 4) 'Incorrect build number'
    Assert-True ($release.WindowsVersion -eq '1.2.3.4') 'Incorrect Windows version'
    Assert-Throws { Get-GitSnapRelease $pubspec 'v1.2.4' } 'Mismatched tag accepted'
    foreach ($invalid in @('1.2+3', '1.2.3', '1.2.3-beta+1', '1.2.3+65536', '01.2.3+1')) {
        Set-Content $pubspec "version: $invalid"
        Assert-Throws { Get-GitSnapRelease $pubspec } "Invalid version accepted: $invalid"
    }
    $feed = Join-Path $tempDir 'appcast.xml'
    Write-GitSnapAppcast -Release $release -Repository 'maxcont/GitSnap-flutter' `
        -Signature 'YWJjZA==' -Length 12345 -Destination $feed
    $xml = Select-Xml -Path $feed -XPath '/rss/channel/item/enclosure'
    Assert-True ($xml.Node.url -eq 'https://github.com/maxcont/GitSnap-flutter/releases/download/v1.2.3/GitSnap-1.2.3-windows-x64-setup.exe') 'Incorrect download URL'
    Assert-True ($xml.Node.length -eq '12345') 'Feed must contain actual installer length'
    $ns = @{ sparkle = 'http://www.andymatuschak.org/xml-namespaces/sparkle' }
    $version = Select-Xml -Path $feed -XPath '/rss/channel/item/enclosure/@sparkle:version' -Namespace $ns
    Assert-True ($version.Node.Value -eq '1.2.3.4') 'Feed version differs from native version'
    $signature = Select-Xml -Path $feed -XPath '/rss/channel/item/enclosure/@sparkle:dsaSignature' -Namespace $ns
    Assert-True ($signature.Node.Value -eq 'YWJjZA==') 'Missing update signature'
    Assert-Throws {
        Write-GitSnapAppcast $release 'bad/repo?x=1&y=2' 'YWJjZA==' 123 $feed
    } 'Unsafe repository accepted'
    Assert-Throws {
        Write-GitSnapAppcast $release 'maxcont/GitSnap-flutter' '' 123 $feed
    } 'Unsigned update accepted'
    Assert-Throws {
        Write-GitSnapAppcast $release 'maxcont/GitSnap-flutter' 'YWJjZA==' 0 $feed
    } 'Empty installer accepted'
    $runtime = Join-Path $tempDir 'crt'
    $bundle = Join-Path $tempDir 'bundle'
    New-Item -ItemType Directory -Path $runtime, $bundle | Out-Null
    Assert-Throws {
        Copy-GitSnapRuntime -RuntimeDirectory $runtime -BuildDirectory $bundle
    } 'Missing runtime DLLs accepted'
    foreach ($dll in @('msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll', 'concrt140.dll')) {
        Set-Content -LiteralPath (Join-Path $runtime $dll) "Test fixture $dll"
    }
    Copy-GitSnapRuntime -RuntimeDirectory $runtime -BuildDirectory $bundle
    foreach ($dll in @('msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll', 'concrt140.dll')) {
        Assert-True (Test-Path -LiteralPath (Join-Path $bundle $dll)) "Missing packaged runtime: $dll"
    }
    Write-Output 'Release script tests passed.'
} finally {
    Remove-Item -LiteralPath $tempDir -Recurse -Force
}
