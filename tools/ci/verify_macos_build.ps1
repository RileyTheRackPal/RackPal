<#
.SYNOPSIS
    Assert things about what `flutter build macos --release` ACTUALLY
    PRODUCED, as opposed to what the dependency graph said it would. This is
    D6 of the macOS debt register (docs/13, board #463) and the sibling of
    verify_windows_build.ps1, whose header explains the gap both close.

.DESCRIPTION
    Read verify_windows_build.ps1's header for why the OUTPUT needs a gate of
    its own (dartjni.dll shipped in a Windows build while every test that read
    the inputs stayed green). Everything it says holds here. What differs is
    the shape of the thing being inspected: a macOS build is a BUNDLE, a
    directory tree that Finder shows as one file, with the native set under
    Contents/Frameworks rather than beside the executable.

      * RackPal.app is a directory and Contents/MacOS/RackPal is a real,
        executable program and not a stub;
      * Contents/Frameworks holds the Flutter engine, the compiled app and the
        vendored pdfium, and THE WHOLE LISTING IS PRINTED ON EVERY RUN;
      * libpdfium.dylib carries BOTH architecture slices (DR-255);
      * the bundle and the dylib both pass `codesign --verify --strict`;
      * NO Android/JNI native library is anywhere in the bundle;
      * the four starter projects reached flutter_assets, byte-intact.

    ON THE STARTERS, PRECISELY. As in the Windows script: this checks that
    the four files were PACKAGED, not that the app OPENS them. That needs an
    `integration_test` target this repository does not have.

    ON THE TWO PDFIUM CHECKS, WHICH ARE NOT A BYTE COMPARISON. The Windows
    build copies pdfium.dll untouched, so a hash against
    third_party/pdfium/pdfium.pin.json would be possible there. Here it is
    not: the copy phase signs the dylib (CodeSignOnCopy), and signing WRITES
    A SIGNATURE INTO THE FILE, so the shipped bytes differ from the vendored
    bytes by construction and a hash comparison would fail on every healthy
    build. The pin is checked at the source side by `tools/vendor_pdfium.ps1
    -Verify`. What a built bundle can still say is that the dylib is the
    two-slice file that was vendored (lipo) and that it carries a signature
    that verifies (codesign).

    ON THE ARM64 SLICE. The hosted macOS image is Intel (DR-255), so CI loads
    only the x86_64 slice and never executes the arm64 one. Its PRESENCE in
    the shipped dylib is therefore the only arm64 check a build can make, and
    it is made here.

    THIS SCRIPT RUNS UNDER pwsh 7 ON macOS AND NOWHERE ELSE. It shells out to
    lipo and codesign, which exist only there, and it reads Unix permission
    bits. It refuses on any other platform by name, rather than reporting
    five spurious failures.

.PARAMETER AppPath
    The built bundle. Defaults to where `flutter build macos --release` puts
    it.
#>
[CmdletBinding()]
param(
    [string]$RepoRoot = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)),
    [string]$AppPath
)

$ErrorActionPreference = 'Stop'

# `$IsMacOS` is undefined in Windows PowerShell 5.1 and reads as $null there,
# which is false: 5.1 is refused here along with Windows and Linux, which is
# the intent.
if (-not $IsMacOS) {
    Write-Host "##vso[task.logissue type=error]verify_macos_build.ps1 runs under pwsh 7 on macOS only (it needs lipo and codesign and reads Unix permission bits). On Windows use verify_windows_build.ps1."
    exit 1
}

if (-not $AppPath) {
    $AppPath = Join-Path $RepoRoot 'apps/rackpal/build/macos/Build/Products/Release/RackPal.app'
}

Write-Host "== macos release output =="
Write-Host "  app : $AppPath"

$problems = @()

if (-not (Test-Path -LiteralPath $AppPath -PathType Container)) {
    Write-Host "##vso[task.logissue type=error]no RackPal.app bundle at $AppPath -- the build did not produce output where this script looks for it."
    exit 1
}

# --- the executable -------------------------------------------------------
# DR-256: the bundle and the executable inside it are both named RackPal.
$exe = Join-Path $AppPath 'Contents/MacOS/RackPal'
if (-not (Test-Path -LiteralPath $exe -PathType Leaf)) {
    $problems += "Contents/MacOS/RackPal is missing from $AppPath"
} else {
    $size = (Get-Item -LiteralPath $exe).Length
    Write-Host ("  RackPal : {0:N0} bytes" -f $size)
    # The same bound as the Windows script and for the same reason: far below
    # the real size so it never becomes a chore, far above zero so it cannot
    # pass on an empty file.
    if ($size -lt 100KB) {
        $problems += "Contents/MacOS/RackPal is only $size bytes -- that is not a built application"
    }
    # `test -x` and not UnixFileMode: it asks the OS the question Finder and
    # launchd ask, and it works on every pwsh 7 rather than only the ones
    # that surface the mode bits. A file that is present, large and not
    # executable is what a zip round trip that drops permissions produces.
    & /bin/test -x $exe
    if ($LASTEXITCODE -ne 0) {
        $problems += "Contents/MacOS/RackPal is not executable"
    }
}

# --- the native set -------------------------------------------------------
$frameworksDir = Join-Path $AppPath 'Contents/Frameworks'
# THE EXACT SET IS NOT KNOWN YET. These three are the ones that must be there
# for any runnable build with pdfium: the engine, the compiled app, and the
# vendored dylib (DR-153, CR-100). The plugin frameworks (window_manager,
# screen_retriever and whatever else the lock graph pulls in) are not listed
# because no build had been measured when this was written. The listing below
# is printed on every run so the first CI run records the real set, and THIS
# LIST IS TO BE TIGHTENED TO AN EXACT, WITH-REASONS LIST once measured, as
# verify_windows_build.ps1's DLL list is. Until then an extra entry is
# printed and does not fail, because a list that fails on the unmeasured is a
# list that gets deleted.
$expectedNative = [ordered]@{
    'FlutterMacOS.framework' =
        'the Flutter engine itself. Its absence means the build produced no runnable application.'
    'App.framework' =
        'the compiled Dart program and flutter_assets. Without it the engine has nothing to run.'
    'libpdfium.dylib' =
        'renders a vector PDF page at import (DR-153). Without it a floorplan that is a CAD plot is refused with "draws no image", on a packaged copy only, while every developer build keeps working.'
}
if (-not (Test-Path -LiteralPath $frameworksDir -PathType Container)) {
    $problems += "no Contents/Frameworks in $AppPath"
    $actualNative = @()
} else {
    $actualNative = @(Get-ChildItem -LiteralPath $frameworksDir -Force |
        Select-Object -ExpandProperty Name | Sort-Object)
}

Write-Host "  Contents/Frameworks:"
foreach ($entry in $actualNative) {
    $item = Get-Item -LiteralPath (Join-Path $frameworksDir $entry) -Force
    $kind = if ($item.PSIsContainer) { 'dir ' } else { 'file' }
    Write-Host "    $kind $entry"
}
foreach ($name in $expectedNative.Keys) {
    if ($name -notin $actualNative) {
        $problems += "expected native library NOT shipped: $name -- $($expectedNative[$name])"
    }
}

# --- libpdfium.dylib: both slices, and a signature that verifies -----------
$dylib = Join-Path $frameworksDir 'libpdfium.dylib'
if (Test-Path -LiteralPath $dylib) {
    # DR-255: CI runs only the x86_64 slice, so the arm64 slice is never
    # executed by any build. That it is PRESENT is the only check available.
    $archOut = & /usr/bin/lipo -archs $dylib 2>&1
    $archCode = $LASTEXITCODE
    $archs = @(("$archOut" -split '\s+') | Where-Object { $_ })
    Write-Host "  libpdfium.dylib slices : $($archs -join ' ')"
    if ($archCode -ne 0) {
        $problems += "lipo could not read libpdfium.dylib: $archOut"
    } else {
        foreach ($want in 'x86_64', 'arm64') {
            if ($want -notin $archs) {
                $problems += ("libpdfium.dylib has no $want slice (found: " +
                    "$($archs -join ' ')). The vendored file is universal " +
                    "(third_party/pdfium/mac-univ, #468); a single-slice " +
                    "dylib here means the wrong file was copied.")
            }
        }
    }

    # `--deep` is deprecated, so the bundle and the dylib are verified as two
    # separate calls and BOTH results are reported: a bundle that verifies
    # while its dylib does not (or the reverse) points at a different step.
    # `--strict` makes the extra checks Apple's own tooling makes, which an
    # ad-hoc CI signature must still pass.
    $bundleOut = & /usr/bin/codesign --verify --strict $AppPath 2>&1
    $bundleCode = $LASTEXITCODE
    Write-Host "  codesign bundle : exit $bundleCode $bundleOut"
    if ($bundleCode -ne 0) {
        $problems += "codesign --verify --strict failed on RackPal.app: $bundleOut"
    }
    $dylibOut = & /usr/bin/codesign --verify --strict $dylib 2>&1
    $dylibCode = $LASTEXITCODE
    Write-Host "  codesign dylib  : exit $dylibCode $dylibOut"
    if ($dylibCode -ne 0) {
        $problems += "codesign --verify --strict failed on libpdfium.dylib: $dylibOut"
    }
}

# --- no JNI library anywhere in the bundle ---------------------------------
# The macOS twin of the Windows dartjni.dll check, and for the same reason:
# an Android JNI bridge arrives transitively through an Android
# implementation package (path_provider_android / file_selector_android)
# and is invisible to every test that reads the dependency graph. It has
# shipped once, on Windows. Searched across the WHOLE bundle and not only
# Frameworks, because a plugin can place a dylib anywhere under Contents.
$jni = @(Get-ChildItem -LiteralPath $AppPath -Recurse -Force -File -Filter '*jni*.dylib' -ErrorAction SilentlyContinue |
    ForEach-Object { $_.FullName.Substring($AppPath.Length).TrimStart('/') })
if ($jni.Count -gt 0) {
    $problems += ("a JNI native library is in the macOS bundle: " +
        "$($jni -join ', '). It arrives transitively through an Android " +
        "implementation package (path_provider_android / " +
        "file_selector_android). Depend on the platform package directly.")
}

# --- the starters ---------------------------------------------------------
# PACKAGED, not OPENED. See the header.
#
# App.framework is a versioned framework, so flutter_assets is reachable as
# Resources/ (a symlink) and as Versions/A/Resources/ (the real directory).
# Which one a given Flutter release lays down is not something this file
# should guess at, so both are tried and the first that exists is used.
$assetRoots = @(
    'Contents/Frameworks/App.framework/Resources/flutter_assets/assets/starters',
    'Contents/Frameworks/App.framework/Versions/A/Resources/flutter_assets/assets/starters'
)
$starterDir = $assetRoots |
    ForEach-Object { Join-Path $AppPath $_ } |
    Where-Object { Test-Path -LiteralPath $_ -PathType Container } |
    Select-Object -First 1
# `.rppj` SINCE DR-179 (`#782`). Kept as one constant for the reason the
# Windows script gives at length: this list went stale at two renames, and the
# extension is the part that moves.
$starterExtension = '.rppj'
$expectedStarters = @(
    "apartment$starterExtension", "home_theatre$starterExtension",
    "small_office$starterExtension", "whole_house$starterExtension"
)
if (-not $starterDir) {
    $problems += ("the starter projects were not packaged: no starters " +
        "directory under any of: $($assetRoots -join ' | ')")
} else {
    $shipped = @(Get-ChildItem -LiteralPath $starterDir -File |
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
        # The CR check from the Windows script, on the shipped copy: a CRLF
        # checkout would leave the corrupted file in the artifact, and a
        # clean clone on macOS is exactly where that is least expected.
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
    Write-Host "macos release output check FAILED ($($problems.Count) problem(s))"
    exit 1
}
Write-Host "macos release output check passed"
exit 0
