<#
.SYNOPSIS
    Assert things about what `flutter build windows --release` ACTUALLY
    PRODUCED, as opposed to what the dependency graph said it would.

.DESCRIPTION
    apps/rackpal/test/flutter_dependency_test.dart is the existing gate here
    and it is a good one, but it reads `pubspec.lock` and
    `windows/flutter/generated_plugins.cmake` -- the INPUTS. Nothing in this
    repository has ever looked at the directory that gets zipped and copied
    onto a client's USB stick. That is the gap `dartjni.dll` sat in: an
    Android JNI bridge shipped beside rackpal.exe in a Windows-only build,
    invisible to every test, found by somebody listing a folder.

    So this closes the loop at the other end, on the real output:

      * rackpal.exe exists and is not a stub;
      * NO Android/JNI native library is in the shipped set;
      * THE SHIPPED NATIVE SET IS PRINTED ON EVERY RUN, and compared to the
        expected list. A new DLL appearing is reported, because the interesting
        failure is the one nobody predicted;
      * the four starter projects reached `data/flutter_assets/`.

    ON THE STARTERS, PRECISELY. The roadmap's per-milestone rule is "the app
    opens the four starter projects". THIS DOES NOT CHECK THAT and must not be
    read as checking it: it checks that the four files were PACKAGED, which is
    the step no existing test covers (starter_assets_test.dart verifies them
    byte-for-byte in `assets/starters/`, on the source side of the bundler).
    Opening them needs the app driven end to end, which needs an
    `integration_test` target this repository does not have.

.PARAMETER ReleaseDir
    The Release output directory.
#>
[CmdletBinding()]
param(
    [string]$RepoRoot = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)),
    [string]$ReleaseDir
)

$ErrorActionPreference = 'Stop'

if (-not $ReleaseDir) {
    $ReleaseDir = Join-Path $RepoRoot 'apps/rackpal/build/windows/x64/runner/Release'
}

Write-Host "== windows release output =="
Write-Host "  dir : $ReleaseDir"

$problems = @()

if (-not (Test-Path $ReleaseDir)) {
    Write-Host "##vso[task.logissue type=error]no Release directory at $ReleaseDir -- the build did not produce output where this script looks for it."
    exit 1
}

# --- the executable -------------------------------------------------------
$exe = Join-Path $ReleaseDir 'rackpal.exe'
if (-not (Test-Path $exe)) {
    $problems += "rackpal.exe is missing from $ReleaseDir"
} else {
    $size = (Get-Item $exe).Length
    Write-Host ("  rackpal.exe : {0:N0} bytes" -f $size)
    # A linker that produced a few kilobytes produced something that is not
    # this application. The bound is deliberately far below the real size
    # (~1 MB) so it never becomes a maintenance chore, and far above zero so
    # it cannot pass on an empty file.
    if ($size -lt 100KB) {
        $problems += "rackpal.exe is only $size bytes -- that is not a built application"
    }
}

# --- the native set -------------------------------------------------------
# EXPECTED, not ALLOWED: an unexpected DLL is reported and fails, and a
# MISSING one fails too. A list that only forbids cannot notice the plugin
# that quietly stopped shipping.
$expectedNative = [ordered]@{
    'flutter_windows.dll' =
        'the Flutter engine itself. Its absence means the build produced no runnable application.'
    'screen_retriever_windows_plugin.dll' =
        'supplies the display work-area list validateRestoredBounds needs; without it window position restore cannot decide whether a saved rectangle is still on a connected monitor, and every launch must centre.'
    'window_manager_plugin.dll' =
        'carries setPreventClose, without which the three-button close prompt (docs/03 section 9.5) cannot exist at all, because the OS closes the window before the app is asked.'
    # THE ONE THAT IS NOT A PLUGIN, and the only one a person put here by
    # hand (DR-153 section 11.152.3). It is vendored rather than fetched
    # (CR-100), installed by a rule in windows/CMakeLists.txt that
    # apps/rackpal/test/pdfium_install_test.dart exists to keep, and it is
    # by far the heaviest thing in this list. Its absence does not break
    # the app: it makes a CAD plot unimportable on a packaged copy while
    # every developer build keeps working, which is the failure that only
    # ever appears where nobody is looking.
    'pdfium.dll' =
        'renders a vector PDF page at import (DR-153). Without it a floorplan that is a CAD plot is refused with "draws no image", which is the state DR-138, DR-145 and DR-148 each deferred and PLAN-K ended.'
}
$actualNative = @(Get-ChildItem -Path $ReleaseDir -Filter '*.dll' -File |
    Select-Object -ExpandProperty Name | Sort-Object)

Write-Host "  native libraries shipped:"
$actualNative | ForEach-Object { Write-Host "    $_" }

foreach ($dll in $actualNative) {
    if (-not $expectedNative.Contains($dll)) {
        $problems += ("unexpected native library in the shipped output: " +
            "$dll. Every DLL here is another unsigned binary for an " +
            "enterprise allowlist to refuse, and weight in a portable ZIP. " +
            "If it belongs, add it to `$expectedNative in " +
            "tools/ci/verify_windows_build.ps1 WITH ITS REASON, and say why " +
            "in docs/03-architecture.md section 10.1.")
    }
}
foreach ($dll in $expectedNative.Keys) {
    if ($dll -notin $actualNative) {
        $problems += ("expected native library NOT shipped: $dll -- " +
            $expectedNative[$dll])
    }
}

# The specific one that already shipped once, named so the failure message
# says what happened last time rather than just "unexpected file".
if ($actualNative -contains 'dartjni.dll') {
    $problems += ("dartjni.dll is back in the Windows Release output. It " +
        "arrives transitively through an Android implementation package " +
        "(path_provider_android / file_selector_android). Depend on the " +
        "platform package directly.")
}

# --- the starters ---------------------------------------------------------
# PACKAGED, not OPENED. See the header.
$starterDir = Join-Path $ReleaseDir 'data/flutter_assets/assets/starters'
# `.rppj` SINCE DR-179 (`#782`), and `.rmpj` since DR-015 (`dc22ddc`) before
# that. THIS LIST HAS NOW GONE STALE AT BOTH RENAMES, and the second time is
# the reason to say so twice: at DR-015 it reported four missing starters that
# no longer existed while the four that do exist shipped correctly (board
# `#739`), and at DR-179 it did the same on the PR build, which is the FIRST
# run that could see it. `run_local.ps1 -SkipBuild` is the documented
# iteration path and these two release gates only run when the build does, so
# a rename is gated green locally five times over and fails on the agent.
#
# A LIST OF FILE NAMES IS A SECOND COPY OF SOMETHING GIT ALREADY KNOWS.
# Deriving it from `apps/rackpal/assets/starters/` would end this, and is not
# done here only because this gate reads the BUNDLE and must not take the
# source tree's word for what shipped. The cheap half is done instead: the
# extension is one constant, so the next rename touches one line.
$starterExtension = '.rppj'
$expectedStarters = @(
    "apartment$starterExtension", "home_theatre$starterExtension",
    "small_office$starterExtension", "whole_house$starterExtension"
)
if (-not (Test-Path $starterDir)) {
    $problems += "the starter projects were not packaged: no $starterDir"
} else {
    $shipped = @(Get-ChildItem -Path $starterDir -File |
        Select-Object -ExpandProperty Name | Sort-Object)
    Write-Host "  starter projects packaged: $($shipped -join ', ')"
    foreach ($starter in $expectedStarters) {
        if ($starter -notin $shipped) {
            $problems += "starter project $starter did not reach the bundle"
        }
    }
    foreach ($starter in $shipped) {
        $bytes = [System.IO.File]::ReadAllBytes((Join-Path $starterDir $starter))
        if ($bytes.Length -eq 0) {
            $problems += "packaged starter $starter is empty"
        }
        # The same CR check apps/rackpal/test/gitattributes_byte_exactness_
        # _test.dart makes on the source side, repeated on the SHIPPED copy:
        # if a clean clone checked these out CRLF-normalised, this is where
        # the corrupted file would be sitting in the artifact.
        if ($bytes -contains 0x0D) {
            $problems += ("packaged starter $starter contains CR bytes -- it " +
                "was checked out CRLF-normalised. See the header of " +
                ".gitattributes; CR-117 is byte-exact and this file is not " +
                "the file that was committed.")
        }
    }
}

# --- verdict --------------------------------------------------------------
Write-Host ""
if ($problems.Count -gt 0) {
    foreach ($problem in $problems) {
        Write-Host "##vso[task.logissue type=error]RELEASE OUTPUT: $problem"
    }
    Write-Host "windows release output check FAILED ($($problems.Count) problem(s))"
    exit 1
}
Write-Host "windows release output check passed"
exit 0
