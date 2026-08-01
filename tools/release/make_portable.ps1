<#
.SYNOPSIS
    Stage the portable RackMate tree: Release build + app-local VC++ runtime
    + the `portable.txt` marker.

.DESCRIPTION
    Board #13. This produces the folder that gets handed to somebody, and
    nothing more -- signing is `sign_artifacts.ps1` and verification is
    `verify_signatures.ps1`, because DR-006 consequence 4 rules that
    "every artifact a release produces signs with the same certificate and
    the same script -- installer and unpacked/portable directory alike".
    Folding signing in here would make the portable path a second signing
    implementation, which is exactly what that consequence forbids.

    ================================================================
    THIS IS A SCOPE EDIT, AND IT SAYS SO
    ================================================================
    DR-006 consequence 4 is explicit that a portable output before M8 is
    NOT something the ruling grants: *"All release-engineering deliverables
    remain at M8. If a portable output is ever wanted earlier, that is a
    scope edit under roadmap section 8.3 and not something this consequence
    grants."* One was wanted earlier -- the team needs something to test
    with -- and the user made that edit. It is recorded in
    docs/12-milestone-board.md section 5.1 rather than smuggled in under a
    ruling that declines to authorise it.

    What this does NOT do, so that M8 still has its work: no installer, no
    MSIX, no crash reporter, no cold-start budget. Those are M8's exit
    criterion and are untouched.

    ================================================================
    THE APP SIDE WAS ALREADY BUILT
    ================================================================
    `lib/src/storage/data_root.dart` is the portable seam and has been
    since M0: presence of `portable.txt` beside the executable switches the
    data root to a `RackMateData` sibling, and a grep test keeps
    `getApplicationSupportDirectory` to that one call site. docs/03:847
    predicted this: pinning `path_provider_windows` to a single call site
    "keeps M2's portable build a one-function change". It did. This script
    writes the marker; the behaviour behind it needed nothing.

    ================================================================
    THE RUNTIME SET IS DERIVED, NEVER HARDCODED
    ================================================================
    `Get-VCRuntimeClosure` reads the shipped binaries' PE import tables and
    follows the runtime DLLs' own imports until the set closes. Measured on
    the M2 build it closes at three -- MSVCP140.dll, VCRUNTIME140.dll,
    VCRUNTIME140_1.dll -- across `rackmate.exe` and both plugin DLLs;
    `flutter_windows.dll` needs none. The set is PRINTED on every run and
    compared with [ExpectedRuntime], so a plugin added in a later milestone
    that drags in `msvcp140_2.dll` is reported rather than discovered on a
    colleague's machine by a missing-DLL dialog.

    THE UNIVERSAL CRT IS DELIBERATELY ABSENT. `api-ms-win-crt-*.dll` are
    in-box on Windows 10 and 11 and serviced by Windows Update. Carrying
    them app-local is for Windows 7/8 targets, which M8's criterion --
    "a clean Windows 11 machine" -- excludes.

.PARAMETER Configuration
    Release (default) or Debug. Debug is refused for staging: a Debug build
    links the DEBUG CRT, whose DLLs are not redistributable at all.

.PARAMETER SkipBuild
    Stage whatever `flutter build windows` last produced. For iterating on
    this script.

.PARAMETER OutDir
    Where the portable tree is written. Defaults to `dist/RackMate-portable`
    at the repo root, which `.gitignore` excludes.

.EXAMPLE
    pwsh -File tools/release/make_portable.ps1
    pwsh -File tools/release/make_portable.ps1 -SkipBuild
#>
[CmdletBinding()]
param(
    [ValidateSet('Release', 'Debug')]
    [string]$Configuration = 'Release',
    [switch]$SkipBuild,
    [string]$RepoRoot = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)),
    [string]$OutDir,
    [string]$RedistDir,
    [string[]]$ExpectedRuntime = @(
        'MSVCP140.dll',
        'VCRUNTIME140.dll',
        'VCRUNTIME140_1.dll'
    )
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'pe_imports.ps1')

if ($Configuration -eq 'Debug') {
    # Not a nicety. `msvcp140d.dll` and friends carry a licence that
    # forbids redistribution, and they are not in the Redist folder at all
    # -- a Debug "portable build" is undistributable by construction.
    throw 'Debug builds cannot be staged: the debug CRT is not redistributable.'
}

$appDir = Join-Path $RepoRoot 'apps/rackmate'
if (-not $OutDir) { $OutDir = Join-Path $RepoRoot 'dist/RackMate-portable' }

Write-Host '== stage the portable tree =='
Write-Host "  repo   : $RepoRoot"
Write-Host "  out    : $OutDir"

# --- 1. build ------------------------------------------------------------
if (-not $SkipBuild) {
    Write-Host "-- flutter build windows --$($Configuration.ToLowerInvariant())"
    Push-Location $appDir
    try {
        & flutter build windows "--$($Configuration.ToLowerInvariant())"
        if ($LASTEXITCODE -ne 0) { throw "flutter build windows failed ($LASTEXITCODE)" }
    } finally {
        Pop-Location
    }
}

$releaseDir = Join-Path $appDir "build/windows/x64/runner/$Configuration"
if (-not (Test-Path $releaseDir)) {
    throw "no build output at $releaseDir -- run without -SkipBuild"
}

# --- 2. copy the build output -------------------------------------------
if (Test-Path $OutDir) { Remove-Item $OutDir -Recurse -Force }
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
Copy-Item (Join-Path $releaseDir '*') $OutDir -Recurse -Force
Write-Host "-- copied build output"

# --- 3. the VC++ runtime, derived from the binaries ----------------------
if (-not $RedistDir) {
    $roots = @(
        "${env:ProgramFiles}\Microsoft Visual Studio",
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio"
    )
    $candidates = @()
    foreach ($r in $roots) {
        if (-not (Test-Path $r)) { continue }
        $candidates += Get-ChildItem $r -Recurse -Directory -Filter 'Microsoft.VC*.CRT' `
            -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -match '\\x64\\' -and $_.FullName -notmatch '\\onecore\\' }
    }
    # Highest toolset version wins -- the redist is backward compatible, so
    # the newest available is the right default rather than the first found.
    $RedistDir = ($candidates | Sort-Object FullName | Select-Object -Last 1).FullName
}
if (-not $RedistDir -or -not (Test-Path $RedistDir)) {
    throw @'
no Visual C++ redistributable directory found.

Looked for Microsoft.VC*.CRT under the Visual Studio install. Install the
"MSVC v143 - VS 2022 C++ x64/x86 build tools" component, or pass -RedistDir
pointing at e.g.
  ...\VC\Redist\MSVC\<version>\x64\Microsoft.VC143.CRT

DO NOT substitute C:\Windows\System32. Those files are the machine's
serviced copies; app-local deployment is defined over the redist folder,
and copying System32 ships whatever happens to be installed here.
'@
}
Write-Host "  redist : $RedistDir"

$shipped = Get-ChildItem $OutDir -File -Recurse -Include *.exe, *.dll |
    ForEach-Object { $_.FullName }
$runtime = @(Get-VCRuntimeClosure -Binaries $shipped -RedistDir $RedistDir)

Write-Host '-- VC++ runtime closure, read off the shipped binaries:'
if ($runtime.Count -eq 0) { Write-Host '     (none)' }
foreach ($dll in $runtime) { Write-Host "     $dll" }

$missing = @()
foreach ($dll in $runtime) {
    $src = Join-Path $RedistDir $dll
    if (-not (Test-Path $src)) { $missing += $dll; continue }
    Copy-Item $src $OutDir -Force
}
if ($missing.Count -gt 0) {
    throw "these runtime DLLs are imported but absent from the redist: $($missing -join ', ')"
}

# THE SURPRISE IS WHAT IS WORTH REPORTING -- `verify_windows_build.ps1`'s
# own rule, applied to the runtime. A set that shrank is as interesting as
# one that grew: it means a binary stopped needing something, which is
# usually a toolchain change nobody announced.
$expected = @($ExpectedRuntime | Sort-Object)
$actual = @($runtime | Sort-Object)
if (($expected -join '|') -ne ($actual -join '|')) {
    Write-Host "##vso[task.logissue type=warning]VC++ runtime set changed. expected [$($expected -join ', ')] got [$($actual -join ', ')]. If this is intended, update -ExpectedRuntime and say why in the commit message."
}

# --- 4. the marker -------------------------------------------------------
# CONTENT IS NEVER READ -- `data_root.dart`: "Presence is the entire
# signal, which is what stops this from quietly becoming a config file."
# So the text is for the human who opens it wondering what it is, and
# changing it changes nothing.
$marker = Join-Path $OutDir 'portable.txt'
@'
RackMate portable mode.

The PRESENCE of this file beside rackmate.exe is the entire signal; its
contents are never read. Delete it and RackMate stores its recovery
snapshots, recents, logs and window preferences under the user's
AppData instead.

With it, all of that lives in the RackMateData folder beside this file.
RackMateData is NOT part of the release -- updating by unzipping a newer
version over this folder replaces `data`, never RackMateData.
'@ | Set-Content -Path $marker -Encoding UTF8

# --- 5. what was produced ------------------------------------------------
Write-Host ''
Write-Host '== staged =='
Get-ChildItem $OutDir | Sort-Object PSIsContainer, Name | ForEach-Object {
    $size = if ($_.PSIsContainer) { '<dir>' } else { '{0,10:N0}' -f $_.Length }
    Write-Host ('  {0}  {1}' -f $size, $_.Name)
}
$total = (Get-ChildItem $OutDir -Recurse -File | Measure-Object -Property Length -Sum).Sum
Write-Host ('  total: {0:N1} MB' -f ($total / 1MB))
Write-Host ''
Write-Host 'NOT YET SIGNED. Next:'
Write-Host "  pwsh -File tools/release/sign_artifacts.ps1 -Path '$OutDir' -Thumbprint <...>"
Write-Host ''
Write-Host 'AND READ docs/14-deployment.md BEFORE HANDING THIS OVER -- a ZIP'
Write-Host 'fetched over HTTP re-arms SmartScreen on every binary inside it,'
Write-Host 'however well signed. Copy over a UNC share instead.'
