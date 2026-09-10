<#
.SYNOPSIS
    Vendors pdfium into third_party/pdfium, pinned by version and SHA-256.

.DESCRIPTION
    CR-100 rules that the pdfium binaries are "vendored into the repo rather
    than downloaded at build time (a network-fetched binary in a signed
    release is a supply-chain and reproducibility problem, not just a CI
    problem)". DR-153 §11.152.3 makes that concrete: one Windows x64
    pdfium.dll, committed, pinned by release tag and checksum.

    THIS SCRIPT IS RUN ONCE BY A PERSON, NOT BY THE BUILD. That is the whole
    point. Nothing in CI or in a developer's ordinary loop invokes it: the
    binary is already in the tree, and `-Verify` is what checks that the one
    sitting there is the one that was pinned.

    THE TRUST DECISION IS THE HUMAN'S AND THE SCRIPT SAYS SO. On a first run
    there is no checksum to verify against, because a checksum invented by
    the thing doing the downloading proves nothing. So `-Bootstrap` prints
    what it got, writes the pin, and tells you to check it against the
    release page before committing. Every run after that verifies.

.PARAMETER Release
    The bblanchon/pdfium-binaries release tag, e.g. 'chromium/7047'.
    Required unless the pin file already names one.
    Releases: https://github.com/bblanchon/pdfium-binaries/releases

.PARAMETER Bootstrap
    Record the observed checksums into the pin file instead of verifying
    against them. Use once, then read the printed hashes against the
    release page.

.PARAMETER Verify
    Check the committed DLL against the pin and exit. Downloads nothing.

.EXAMPLE
    pwsh -File tools/vendor_pdfium.ps1 -Release chromium/7047 -Bootstrap

.EXAMPLE
    pwsh -File tools/vendor_pdfium.ps1 -Verify
#>
[CmdletBinding()]
param(
    [string] $Release,
    [switch] $Bootstrap,
    [switch] $Verify
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = Split-Path -Parent $PSScriptRoot
$vendorDir = Join-Path $repoRoot 'third_party/pdfium'
$dllPath = Join-Path $vendorDir 'win-x64/pdfium.dll'
$pinPath = Join-Path $vendorDir 'pdfium.pin.json'

function Read-Pin {
    if (-not (Test-Path $pinPath)) { return $null }
    return Get-Content $pinPath -Raw | ConvertFrom-Json
}

function Get-Sha256([string] $path) {
    return (Get-FileHash -Path $path -Algorithm SHA256).Hash.ToLowerInvariant()
}

# ======================================================================
# -Verify: the committed tree against the committed pin
# ======================================================================
# Runs with no network and is the only mode anything automated should use.
if ($Verify) {
    $pin = Read-Pin
    if ($null -eq $pin) { throw "no pin at $pinPath -- run with -Bootstrap first" }
    if (-not (Test-Path $dllPath)) {
        throw "pdfium is NOT VENDORED: $dllPath is missing. Run: pwsh -File tools/vendor_pdfium.ps1 -Release $($pin.release) (it will verify against the pin)"
    }
    $actual = Get-Sha256 $dllPath
    if ($actual -ne $pin.dllSha256) {
        throw "pdfium.dll does not match the pin.`n  expected $($pin.dllSha256)`n  actual   $actual`nThe binary in the tree is not the one that was reviewed."
    }
    Write-Host "pdfium.dll matches the pin ($($pin.release), sha256 $actual)" -ForegroundColor Green
    exit 0
}

$pin = Read-Pin
if (-not $Release) {
    if ($null -eq $pin) {
        throw "no pin yet, so -Release is required. Pick a tag from https://github.com/bblanchon/pdfium-binaries/releases (e.g. -Release chromium/7047) and pass -Bootstrap."
    }
    $Release = $pin.release
}

# The tag contains a slash, which has to survive the URL.
$tag = $Release -replace '/', '%2F'
$artifact = 'pdfium-win-x64.tgz'
$url = "https://github.com/bblanchon/pdfium-binaries/releases/download/$tag/$artifact"

$work = Join-Path ([System.IO.Path]::GetTempPath()) ("pdfium-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $work -Force | Out-Null

try {
    Write-Host "downloading $url"
    $archive = Join-Path $work $artifact
    Invoke-WebRequest -Uri $url -OutFile $archive -UseBasicParsing

    $archiveSha = Get-Sha256 $archive
    Write-Host "archive sha256: $archiveSha"

    if (-not $Bootstrap) {
        if ($null -eq $pin) { throw "no pin to verify against -- pass -Bootstrap" }
        if ($archiveSha -ne $pin.archiveSha256) {
            throw "the downloaded archive does not match the pin.`n  expected $($pin.archiveSha256)`n  actual   $archiveSha`nEither the release was re-cut or this is not the file that was reviewed. Do NOT commit it."
        }
    }

    # bsdtar ships with Windows 10 1803 and later, so no third-party
    # unpacker is needed to open a .tgz.
    & tar -xzf $archive -C $work
    if ($LASTEXITCODE -ne 0) { throw "tar failed to extract $archive" }

    $sourceDll = Join-Path $work 'bin/pdfium.dll'
    if (-not (Test-Path $sourceDll)) {
        throw "the archive has no bin/pdfium.dll -- has the release layout changed?"
    }
    $dllSha = Get-Sha256 $sourceDll
    Write-Host "pdfium.dll sha256: $dllSha"

    if (-not $Bootstrap -and $dllSha -ne $pin.dllSha256) {
        throw "pdfium.dll does not match the pin.`n  expected $($pin.dllSha256)`n  actual   $dllSha"
    }

    New-Item -ItemType Directory -Path (Split-Path -Parent $dllPath) -Force | Out-Null
    Copy-Item $sourceDll $dllPath -Force

    # THE LICENCE TRAVELS WITH THE BINARY. DR-036's census covers what is
    # in the tree, and CR-100 says a vendored pdfium reopens it: a binary
    # whose licence is a URL somebody has to go and find is a binary
    # nobody can audit from the repository.
    $sourceLicense = Join-Path $work 'LICENSE'
    if (Test-Path $sourceLicense) {
        Copy-Item $sourceLicense (Join-Path $vendorDir 'LICENSE') -Force
    } else {
        Write-Warning "the archive carries no LICENSE file -- fetch it from the pdfium source tree before committing"
    }

    if ($Bootstrap) {
        $pinObject = [ordered]@{
            release       = $Release
            artifact      = $artifact
            url           = $url
            archiveSha256 = $archiveSha
            dllSha256     = $dllSha
            recordedAt    = (Get-Date -Format 'yyyy-MM-dd')
        }
        $pinObject | ConvertTo-Json | Set-Content -Path $pinPath -Encoding utf8
        Write-Host ''
        Write-Host 'WROTE THE PIN. Before committing, check these against the release page:' -ForegroundColor Yellow
        Write-Host "  release       $Release"
        Write-Host "  archive       $archiveSha"
        Write-Host "  pdfium.dll    $dllSha"
        Write-Host 'A checksum computed by the downloader proves the file did not change in transit and nothing else.'
    }

    $size = [math]::Round((Get-Item $dllPath).Length / 1MB, 1)
    Write-Host ''
    Write-Host "vendored $dllPath ($size MB)" -ForegroundColor Green
    Write-Host 'Commit third_party/pdfium/ and it is done: nothing else ever downloads it.'
}
finally {
    Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
}
