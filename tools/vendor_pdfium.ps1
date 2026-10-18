<#
.SYNOPSIS
    Vendors pdfium into third_party/pdfium, pinned by version and SHA-256,
    one artifact per platform.

.DESCRIPTION
    CR-100 rules that the pdfium binaries are "vendored into the repo rather
    than downloaded at build time (a network-fetched binary in a signed
    release is a supply-chain and reproducibility problem, not just a CI
    problem)". DR-153 §11.152.3 makes that concrete: committed, pinned by
    release tag and checksum.

    THIS SCRIPT IS RUN ONCE PER PLATFORM BY A PERSON, NOT BY THE BUILD. That
    is the whole point. Nothing in CI or in a developer's ordinary loop
    invokes it: the binaries are already in the tree, and `-Verify` is what
    checks that the ones sitting there are the ones that were pinned.

    THE TRUST DECISION IS THE HUMAN'S AND THE SCRIPT SAYS SO. On a first run
    for a platform there is no checksum to verify against, because a
    checksum invented by the thing doing the downloading proves nothing. So
    `-Bootstrap` compares the archive against the digest GitHub publishes for
    the release asset, refuses a mismatch, prints what it got, writes that
    platform's pin entry, and tells you to check it against the release page
    before committing. Every run after that verifies.

    ONE RELEASE FOR EVERY PLATFORM. The Windows DLL and the macOS dylib come
    from the same bblanchon/pdfium-binaries tag, so a document renders
    through the same pdfium wherever it is opened. A second tag is refused
    rather than quietly mixed in; moving the release re-pins every platform.

.PARAMETER Platform
    Which artifact: 'win-x64' (the default, pdfium.dll) or 'mac-univ' (one
    universal libpdfium.dylib holding both the x86_64 and arm64 slices,
    DR-255's macOS job loading the first and an Apple Silicon Mac the
    second).

.PARAMETER Release
    The bblanchon/pdfium-binaries release tag, e.g. 'chromium/8044'.
    Required unless the pin file already names one.
    Releases: https://github.com/bblanchon/pdfium-binaries/releases

.PARAMETER Bootstrap
    Record the observed checksums into the pin entry for -Platform instead
    of verifying against them. Use once per platform, then read the printed
    hashes against the release page.

.PARAMETER Verify
    Check EVERY pinned binary against the pin and exit. Downloads nothing.

.EXAMPLE
    pwsh -File tools/vendor_pdfium.ps1 -Platform mac-univ -Bootstrap

.EXAMPLE
    pwsh -File tools/vendor_pdfium.ps1 -Verify
#>
[CmdletBinding()]
param(
    [ValidateSet('win-x64', 'mac-univ')]
    [string] $Platform = 'win-x64',
    [string] $Release,
    [switch] $Bootstrap,
    [switch] $Verify
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = Split-Path -Parent $PSScriptRoot
$vendorDir = Join-Path $repoRoot 'third_party/pdfium'
$pinPath = Join-Path $vendorDir 'pdfium.pin.json'

# Per platform: the release artifact, the file inside it, and where that
# file is committed. The committed path is what pdfium_library.dart looks
# for, and pdfium_vendoring_test.dart holds the two to each other.
$layouts = @{
    'win-x64'  = @{ artifact = 'pdfium-win-x64.tgz';  inner = 'bin/pdfium.dll';      binary = 'win-x64/pdfium.dll' }
    'mac-univ' = @{ artifact = 'pdfium-mac-univ.tgz'; inner = 'lib/libpdfium.dylib'; binary = 'mac-univ/libpdfium.dylib' }
}

function Read-Pin {
    if (-not (Test-Path $pinPath)) { return $null }
    return Get-Content $pinPath -Raw | ConvertFrom-Json
}

function Get-Sha256([string] $path) {
    return (Get-FileHash -Path $path -Algorithm SHA256).Hash.ToLowerInvariant()
}

# ======================================================================
# -Verify: the committed tree against the committed pin, every platform
# ======================================================================
# Runs with no network and is the only mode anything automated should use.
if ($Verify) {
    $pin = Read-Pin
    if ($null -eq $pin) { throw "no pin at $pinPath -- run with -Bootstrap first" }
    $failed = $false
    foreach ($name in ($pin.platforms.PSObject.Properties.Name | Sort-Object)) {
        $entry = $pin.platforms.$name
        $path = Join-Path $vendorDir $entry.binary
        if (-not (Test-Path $path)) {
            Write-Host "$name : NOT VENDORED, $path is missing. Run: pwsh -File tools/vendor_pdfium.ps1 -Platform $name (it will verify against the pin)" -ForegroundColor Red
            $failed = $true
            continue
        }
        $actual = Get-Sha256 $path
        if ($actual -ne $entry.binarySha256) {
            Write-Host "$name : $($entry.binary) does not match the pin.`n  expected $($entry.binarySha256)`n  actual   $actual`nThe binary in the tree is not the one that was reviewed." -ForegroundColor Red
            $failed = $true
            continue
        }
        Write-Host "$name : $($entry.binary) matches the pin ($($pin.release), sha256 $actual)" -ForegroundColor Green
    }
    if ($failed) { exit 1 }
    exit 0
}

$pin = Read-Pin
if (-not $Release) {
    if ($null -eq $pin) {
        throw "no pin yet, so -Release is required. Pick a tag from https://github.com/bblanchon/pdfium-binaries/releases (e.g. -Release chromium/8044) and pass -Bootstrap."
    }
    $Release = $pin.release
}
if ($null -ne $pin -and $Release -ne $pin.release) {
    throw "the pin is at $($pin.release) and this run asks for $Release. Every platform comes from one release, so moving it means re-pinning all of them, deliberately; this script will not mix two."
}

$layout = $layouts[$Platform]
$entry = $null
if ($null -ne $pin -and $pin.platforms.PSObject.Properties.Name -contains $Platform) {
    $entry = $pin.platforms.$Platform
}
if (-not $Bootstrap -and $null -eq $entry) {
    throw "there is no pin entry for $Platform yet -- pass -Bootstrap to record one"
}

# The tag contains a slash, which has to survive the URL.
$tag = $Release -replace '/', '%2F'
$artifact = $layout.artifact
$url = "https://github.com/bblanchon/pdfium-binaries/releases/download/$tag/$artifact"
$binaryPath = Join-Path $vendorDir $layout.binary

$work = Join-Path ([System.IO.Path]::GetTempPath()) ("pdfium-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $work -Force | Out-Null

try {
    Write-Host "downloading $url"
    $archive = Join-Path $work $artifact
    Invoke-WebRequest -Uri $url -OutFile $archive -UseBasicParsing

    $archiveSha = Get-Sha256 $archive
    Write-Host "archive sha256: $archiveSha"

    if ($Bootstrap) {
        # A SECOND WITNESS FOR THE FIRST RUN. GitHub publishes a digest for
        # every release asset, computed by GitHub rather than by this
        # download, so a file altered in transit or on a mirror disagrees
        # with it. It does not make the release trustworthy; it makes this
        # copy the release's copy. For win-x64 it matched the pin that was
        # recorded by hand on 2026-09-10.
        $api = "https://api.github.com/repos/bblanchon/pdfium-binaries/releases/tags/$tag"
        $published = (Invoke-RestMethod -Uri $api -UseBasicParsing).assets |
            Where-Object { $_.name -eq $artifact } | Select-Object -First 1
        if ($null -eq $published -or -not $published.PSObject.Properties['digest'] -or -not $published.digest) {
            throw "GitHub publishes no digest for $artifact in $Release, so there is nothing independent to check this download against. Do not bootstrap from it."
        }
        $publishedSha = ($published.digest -replace '^sha256:', '').ToLowerInvariant()
        if ($publishedSha -ne $archiveSha) {
            throw "the downloaded archive does not match the digest GitHub publishes for it.`n  published $publishedSha`n  actual    $archiveSha`nDo NOT commit it."
        }
        Write-Host "archive matches the digest GitHub publishes for $artifact" -ForegroundColor Green
    } elseif ($archiveSha -ne $entry.archiveSha256) {
        throw "the downloaded archive does not match the pin.`n  expected $($entry.archiveSha256)`n  actual   $archiveSha`nEither the release was re-cut or this is not the file that was reviewed. Do NOT commit it."
    }

    # bsdtar ships with Windows 10 1803 and later, and with macOS, so no
    # third-party unpacker is needed to open a .tgz.
    & tar -xzf $archive -C $work
    if ($LASTEXITCODE -ne 0) { throw "tar failed to extract $archive" }

    $sourceBinary = Join-Path $work $layout.inner
    if (-not (Test-Path $sourceBinary)) {
        throw "the archive has no $($layout.inner) -- has the release layout changed?"
    }
    $binarySha = Get-Sha256 $sourceBinary
    Write-Host "$($layout.inner) sha256: $binarySha"

    if (-not $Bootstrap -and $binarySha -ne $entry.binarySha256) {
        throw "$($layout.inner) does not match the pin.`n  expected $($entry.binarySha256)`n  actual   $binarySha"
    }

    New-Item -ItemType Directory -Path (Split-Path -Parent $binaryPath) -Force | Out-Null
    Copy-Item $sourceBinary $binaryPath -Force

    # THE LICENCE TRAVELS WITH THE BINARY. DR-036's census covers what is
    # in the tree, and CR-100 says a vendored pdfium reopens it: a binary
    # whose licence is a URL somebody has to go and find is a binary
    # nobody can audit from the repository.
    # ONE LICENCE FILE FOR EVERY PLATFORM, so a second artifact whose
    # licence text differs is stopped rather than allowed to overwrite the
    # first: two artifacts of one release should carry one licence, and if
    # they do not, a person reads both.
    $sourceLicense = Join-Path $work 'LICENSE'
    $treeLicense = Join-Path $vendorDir 'LICENSE'
    if (Test-Path $sourceLicense) {
        if ((Test-Path $treeLicense) -and ((Get-Sha256 $sourceLicense) -ne (Get-Sha256 $treeLicense))) {
            throw "the LICENSE in $artifact differs from the one already in $vendorDir. Read both before choosing; this script will not overwrite one licence with another."
        }
        Copy-Item $sourceLicense $treeLicense -Force
    } else {
        Write-Warning "the archive carries no LICENSE file -- fetch it from the pdfium source tree before committing"
    }

    if ($Bootstrap) {
        $platforms = [ordered]@{}
        if ($null -ne $pin) {
            foreach ($name in $pin.platforms.PSObject.Properties.Name) { $platforms[$name] = $pin.platforms.$name }
        }
        $platforms[$Platform] = [ordered]@{
            artifact      = $artifact
            url           = $url
            archiveSha256 = $archiveSha
            binary        = $layout.binary
            binarySha256  = $binarySha
            recordedAt    = (Get-Date -Format 'yyyy-MM-dd')
        }
        $sorted = [ordered]@{}
        foreach ($name in ($platforms.Keys | Sort-Object)) { $sorted[$name] = $platforms[$name] }
        $pinObject = [ordered]@{ release = $Release; platforms = $sorted }
        $pinObject | ConvertTo-Json -Depth 4 | Set-Content -Path $pinPath -Encoding utf8NoBOM
        Write-Host ''
        Write-Host 'WROTE THE PIN. Before committing, check these against the release page:' -ForegroundColor Yellow
        Write-Host "  release       $Release"
        Write-Host "  archive       $archiveSha"
        Write-Host "  $($layout.inner)  $binarySha"
        Write-Host 'A checksum computed by the downloader proves the file did not change in transit and nothing else.'
    }

    $size = [math]::Round((Get-Item $binaryPath).Length / 1MB, 1)
    Write-Host ''
    Write-Host "vendored $binaryPath ($size MB)" -ForegroundColor Green
    Write-Host 'Commit third_party/pdfium/ and it is done: nothing else ever downloads it.'
}
finally {
    Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
}
