<#
.SYNOPSIS
    Install the PINNED Flutter SDK and then PROVE the pin held.

.DESCRIPTION
    docs/03-architecture.md section 10.2 carried a standing VERIFY item: the
    corpus named two different Flutter stable versions, and "the CI Flutter
    version is pinned and load-bearing, because a minor bump routinely shifts
    antialiasing by a pixel and golden regeneration must be a deliberate,
    reviewed step of every upgrade." That item is resolved to 3.44.4 -- the
    local toolchain and design-architecture.md agree on it -- and this script
    plus the `flutterVersion` variable in azure-pipelines.yml is where the
    resolution lives.

    INSTALLING A PINNED VERSION IS THE EASY HALF. The half that actually
    matters is that a wrong version must be LOUD. A pipeline that says
    "flutter-version: 3.44.4" and silently gets 3.45.0 -- because the tool
    installer resolved a range, because a cache restored an older SDK,
    because a self-hosted agent already had one on PATH -- looks exactly like
    a pipeline that worked, right up until goldens land and start flapping.
    So the version is not requested; it is REQUESTED AND THEN MEASURED, from
    'flutter --version --machine', and a mismatch fails the build with the
    two numbers printed side by side.

    NO MARKETPLACE EXTENSION. The obvious alternative is the FlutterInstall
    task from the Flutter Azure DevOps extension, which would have to be
    installed into the organisation before this pipeline could run at all,
    and which resolves a channel rather than an exact build. Downloading the
    official archive by exact version keeps the pin in this repository, where
    it can be reviewed, and keeps the pipeline runnable in an organisation
    that has installed nothing.

    THE REVISION IS RECORDED, NOT ENFORCED -- YET. `frameworkRevision` is a
    stronger pin than the version string, and it is what actually determines
    the rendering. It is asserted as a WARNING today and printed on every
    run, because there are no goldens for it to protect (docs/12 section 4.3)
    and failing a first build over a benign re-tag would teach people to
    ignore this gate. THE DAY THE FIRST GOLDEN LANDS, promote the revision
    check to a hard failure -- that is the whole reason the pin is called
    load-bearing.

.PARAMETER Version
    The exact Flutter stable version, e.g. 3.44.4.

.PARAMETER ExpectedFrameworkRevision
    Full 40-char framework revision expected for that version. Warned about,
    not enforced. See above.

.PARAMETER InstallRoot
    Directory to install into. `$InstallRoot\flutter\bin` goes on PATH.

.PARAMETER VerifyOnly
    Skip installation; measure whatever `flutter` is already on PATH. This is
    the half of the script that can be, and has been, run on a developer
    machine.

.EXAMPLE
    pwsh -File tools/ci/ensure_flutter.ps1 -Version 3.44.4 -VerifyOnly
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Version,
    [string]$ExpectedFrameworkRevision = '',
    [string]$InstallRoot = $env:AGENT_TOOLSDIRECTORY,
    [switch]$VerifyOnly
)

$ErrorActionPreference = 'Stop'

Write-Host "== flutter pin =="
Write-Host "  required version : $Version"

if (-not $VerifyOnly) {
    if (-not $InstallRoot) { $InstallRoot = Join-Path $env:USERPROFILE 'flutter-sdk' }
    $flutterHome = Join-Path $InstallRoot 'flutter'
    $flutterBin  = Join-Path $flutterHome 'bin'

    # AN EXISTING SDK IS TRUSTED ONLY AT THE PINNED VERSION. This branch
    # used to accept any `flutter.bat` it found, on the assumption that a
    # wrong one could only arrive through the cache, keyed on the version.
    # A SELF-HOSTED AGENT KEEPS ITS TOOL DIRECTORY BETWEEN BUILDS: when
    # DR-248 moved the pin, the cache missed, restored nothing, and left
    # 3.44.4 in place, which this branch then accepted and the measurement
    # below rejected (build 463). So read the version the SDK records about
    # itself, the marker the pipeline's probe step reads, and REPLACE the
    # SDK when it is not the pin or cannot say what it is.
    $existing = Join-Path $flutterBin 'flutter.bat'
    if (Test-Path $existing) {
        $marker = Join-Path $flutterHome 'bin/cache/flutter.version.json'
        $onDisk = $null
        try { $onDisk = (Get-Content $marker -Raw | ConvertFrom-Json).flutterVersion } catch { $onDisk = $null }
        if ($onDisk -eq $Version) {
            Write-Host "  found the pinned SDK at $flutterHome ($onDisk)"
        } else {
            Write-Host "  found an SDK at $flutterHome reporting '$onDisk', not ${Version}: replacing it"
            Remove-Item -LiteralPath $flutterHome -Recurse -Force -ErrorAction SilentlyContinue
            if (Test-Path $flutterHome) { & cmd.exe /c "rmdir /s /q `"$flutterHome`"" }
            if (Test-Path $flutterHome) {
                Write-Host "##vso[task.logissue type=error]could not remove the stale SDK at $flutterHome; delete it by hand and re-run."
                exit 1
            }
        }
    }

    if (-not (Test-Path $existing)) {
        # The official stable archive, addressed by EXACT version. This URL
        # shape has been stable for years, but it is an external dependency
        # and this script has never been run against it from a developer
        # machine -- see the header of azure-pipelines.yml for what is
        # verified and what is not. If it 404s, the fix is one line here.
        $archive = "flutter_windows_$Version-stable.zip"
        $url = "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/$archive"
        $zip = Join-Path $env:TEMP $archive

        Write-Host "  downloading $url"
        $null = New-Item -ItemType Directory -Path $InstallRoot -Force
        # curl.exe ships with Windows and streams to disk; Invoke-WebRequest
        # buffers a ~1 GB body in memory first.
        # One line: this is the branch that has never been executed, so it is
        # the last place to leave a backtick continuation that a stray
        # trailing space would turn into a syntax error.
        & curl.exe --location --fail --show-error --silent --retry 3 --retry-delay 5 --output $zip $url
        if ($LASTEXITCODE -ne 0) {
            Write-Host "##vso[task.logissue type=error]could not download the pinned Flutter SDK from $url (curl exit $LASTEXITCODE). If the archive name changed, fix it in tools/ci/ensure_flutter.ps1 -- do NOT switch to a channel, the exact version is the point."
            exit 1
        }

        Write-Host "  extracting to $InstallRoot"
        # bsdtar (Windows 10+) unpacks a zip far faster than Expand-Archive.
        # BY PATH: the bsdtar Windows ships. Run from Git Bash, a bare `tar.exe`
        # resolved to GNU tar, which read `C:` as a remote host and failed.
        & (Join-Path $env:SystemRoot 'System32\tar.exe') -xf $zip -C $InstallRoot
        if ($LASTEXITCODE -ne 0) {
            Write-Host "  tar failed; falling back to Expand-Archive"
            Expand-Archive -Path $zip -DestinationPath $InstallRoot -Force
        }
        Remove-Item $zip -Force -ErrorAction SilentlyContinue
    }

    $env:PATH = "$flutterBin;$env:PATH"
    # Azure DevOps only: make the PATH change outlive this step.
    Write-Host "##vso[task.prependpath]$flutterBin"
    # BEST EFFORT, DELIBERATELY. These are configuration niceties, not gates:
    # a fresh SDK on a build agent should not phone home and should not emit
    # ANSI spinners into a log file. Native commands do not throw on a
    # non-zero exit, so a flag that has been renamed in some future SDK
    # degrades to a no-op rather than failing the build over cosmetics. The
    # thing that must not degrade -- the version -- is measured below.
    & flutter --disable-analytics 2>&1 | Out-Null
    & flutter config --no-cli-animations 2>&1 | Out-Null
    # Desktop has been on by default since 2.10; asserted here so a config
    # left over in a restored SDK cache cannot turn `flutter build windows`
    # into "no devices".
    & flutter config --enable-windows-desktop 2>&1 | Out-Null
}

# ----------------------------------------------------------------------
# MEASURE. Everything above is a request; this is the answer.
# ----------------------------------------------------------------------
$raw = & flutter --version --machine 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "##vso[task.logissue type=error]'flutter --version --machine' failed (exit $LASTEXITCODE): $raw"
    exit 1
}

# 'flutter --version --machine' can prepend non-JSON chatter on a first run
# ("Downloading Dart SDK..."), so take the JSON object, not the whole stream.
$text = ($raw | Out-String)
$start = $text.IndexOf('{')
$end = $text.LastIndexOf('}')
if ($start -lt 0 -or $end -le $start) {
    Write-Host "##vso[task.logissue type=error]could not find a JSON object in 'flutter --version --machine' output:"
    Write-Host $text
    exit 1
}
try {
    $info = $text.Substring($start, $end - $start + 1) | ConvertFrom-Json
} catch {
    Write-Host "##vso[task.logissue type=error]could not parse 'flutter --version --machine' output: $_"
    Write-Host $text
    exit 1
}

Write-Host ""
Write-Host "  frameworkVersion  : $($info.frameworkVersion)"
Write-Host "  channel           : $($info.channel)"
Write-Host "  frameworkRevision : $($info.frameworkRevision)"
Write-Host "  engineRevision    : $($info.engineRevision)"
Write-Host "  dartSdkVersion    : $($info.dartSdkVersion)"
Write-Host "  flutterRoot       : $($info.flutterRoot)"
Write-Host ""

if ($info.frameworkVersion -ne $Version) {
    Write-Host "##vso[task.logissue type=error]FLUTTER PIN VIOLATED: this pipeline requires exactly $Version and the agent is running $($info.frameworkVersion). The pin is not a preference -- docs/03-architecture.md section 10.2 records that a minor bump shifts antialiasing by a pixel, so a Flutter upgrade must be a deliberate, reviewed change to the flutterVersion variable in azure-pipelines.yml with goldens regenerated in the same commit."
    exit 1
}
if ($info.channel -ne 'stable') {
    Write-Host "##vso[task.logissue type=error]FLUTTER PIN VIOLATED: channel is '$($info.channel)', expected 'stable'."
    exit 1
}

if ($ExpectedFrameworkRevision) {
    if ($info.frameworkRevision -ne $ExpectedFrameworkRevision) {
        Write-Host "##vso[task.logissue type=warning]Flutter $Version resolved to framework revision $($info.frameworkRevision), not the recorded $ExpectedFrameworkRevision. The version string matches, so this is not fatal TODAY -- there are no goldens for it to protect. Promote this to a hard failure in tools/ci/ensure_flutter.ps1 on the day the first golden lands, and update the recorded revision deliberately."
    } else {
        Write-Host "  framework revision matches the recorded pin"
    }
}

Write-Host "flutter pin verified: $Version ($($info.channel))"
exit 0
