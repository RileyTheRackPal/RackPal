<#
.SYNOPSIS
    Run the CI gates on this machine, in the pipeline's order.

.DESCRIPTION
    A GATE YOU CANNOT RUN BY HAND IS A GATE YOU DEBUG BY PUSHING COMMITS.
    This runs the same commands azure-pipelines.yml runs, in the same order,
    so "green locally" and "green on the agent" mean the same thing and a
    failure can be reproduced without a build queue.

    IT IS NOT THE PIPELINE and does not pretend to be. What it deliberately
    does NOT do:

      * install the pinned Flutter SDK -- it runs
        `ensure_flutter.ps1 -VerifyOnly` against whatever is on PATH, so a
        developer on the wrong SDK is told so, loudly, before anything else;
      * clean the working tree. The pipeline's clean clone is itself a gate
        (see the header of azure-pipelines.yml) and this cannot reproduce it.
        A `.gitattributes` defect that only shows on a fresh checkout will
        pass here and fail there. That is the one class this script cannot
        speak about -- except for the ONE PART OF IT THAT IS CHEAP: the
        `tracked sources` gate below asks git whether a clone would even
        RECEIVE every lib/ source, which is how a barrel export of an
        untracked file went unnoticed until it was already committed. That
        gate speaks about the COMMIT, not about the code, and it is the one
        thing here that will read red on an ordinary work-in-progress tree
        with a new file in it. That is deliberate: the answer it gives is
        "this changeset is not complete yet";
      * publish anything.

    THIS FILE AND azure-pipelines.yml CAN DRIFT APART. They are two lists of
    the same commands and nothing enforces that they stay equal. If you add a
    gate, add it in both.

.PARAMETER SkipBuild
    Skip `flutter build windows --release` and the release-output gate. The
    build dominates the wall clock; skipping it is for iterating on tests.

.PARAMETER SkipTests
    Run only the fast gates (pin, analyzer, palette, converter self-test).
#>
[CmdletBinding()]
param(
    [string]$RepoRoot = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)),
    [switch]$SkipBuild,
    [switch]$SkipTests
)

$ErrorActionPreference = 'Stop'
$ci = Join-Path $RepoRoot 'tools/ci'
$outDir = Join-Path $RepoRoot 'build/ci'

# Kept in step order to mirror the YAML. Each entry: label, scriptblock.
$results = [System.Collections.Generic.List[object]]::new()

function Invoke-Gate {
    param([string]$Label, [scriptblock]$Action)
    Write-Host ''
    Write-Host ('=' * 70)
    Write-Host "  $Label"
    Write-Host ('=' * 70)
    & $Action
    $code = $LASTEXITCODE
    if ($null -eq $code) { $code = 0 }
    $results.Add([pscustomobject]@{ Gate = $Label; Exit = $code })
    if ($code -ne 0) { Write-Host "  -> FAILED (exit $code)" }
}

Push-Location $RepoRoot
try {
    # The pin first: every number below is only meaningful on the pinned SDK.
    $pinVersion = '3.44.4'
    $pinRevision = 'ad70ec4617166f1c38e5d2bfd388af71fda14f06'
    Invoke-Gate 'flutter pin' {
        pwsh -NoProfile -File (Join-Path $ci 'ensure_flutter.ps1') `
            -Version $pinVersion -ExpectedFrameworkRevision $pinRevision -VerifyOnly
    }
    Invoke-Gate 'tracked sources (would a clone compile?)' {
        pwsh -NoProfile -File (Join-Path $ci 'verify_tracked_sources.ps1')
    }
    Invoke-Gate 'flutter pub get (workspace root)' { flutter pub get }
    Invoke-Gate 'analyzer gate'       { pwsh -NoProfile -File (Join-Path $ci 'analyze_gate.ps1') }
    # Added 2026-08-03 by DR-017 (canon section 11.16), answering docs/12
    # section 4.1: adopt the formatter, keep the info ratchet. It was absent for
    # months because turning it on before the tree was formatted would have
    # made main permanently red, which is the same argument the ratchet rests
    # on. The tree was formatted in b6ff394; this is what stops it drifting
    # back. Unlike every other gate here it needs no argument about what it
    # measures -- `dart format` is the definition of the answer.
    Invoke-Gate 'formatter' {
        dart format --output=none --set-exit-if-changed .
    }
    Invoke-Gate 'PAL-1 conformance'   { python tools/pal1_check.py }
    Invoke-Gate 'palette parity'      { python tools/palette_parity.py }
    # The third of the family: pal1_check says the palette is legible,
    # palette_parity says the DOCS agree with it, and this says the DART
    # SEED does (DR-010 section 11.10.1). Added when the seeded registries
    # made packages/rackpal_core/.../seed_registries.dart a fourth copy of
    # the same 8 hues and 55 dash/weight pairs.
    Invoke-Gate 'registry parity'     { python tools/registry_parity.py }
    # The fourth gate that reads the corpus (#780, DR-095 section 11.94.9):
    # no milestone before the current one may hold an exit clause that is
    # neither discharged nor parked on a named later milestone by a ruling.
    # It runs its own planted cases first, so a green run means it can fail.
    Invoke-Gate 'milestone completeness' { python tools/milestone_gate.py }
    # DR-090 section 11.89.8. The only gate here that reads a font BINARY,
    # because it is the only one that can: the two backends emit IDENTICAL
    # ops for a missing glyph and differ solely in what a rasteriser does
    # with one of them, which is how `NET-NEN006` printed over a net name
    # with every op-level gate green. Its blind spots are in its header.
    Invoke-Gate 'glyph coverage'      { python tools/glyph_coverage_check.py }
    Invoke-Gate 'JUnit converter self-test' {
        python (Join-Path $ci 'junit_converter_selftest.py')
    }
    # AC-051, #302. A NAMED STEP even though the core suite runs this file
    # anyway, because the thing it protects is a SCHEDULE control: roadmap
    # M5's risk list names the pressure to add "just one more obvious
    # rule" without its pair as how this milestone overruns. Buried among
    # 3,900 passing tests that failure reads as one red line; here it
    # reads as "AC-051 pair coverage FAILED" in the summary, which is
    # where somebody adding a rule will see it.
    Invoke-Gate 'AC-051 pair coverage' {
        Push-Location (Join-Path $RepoRoot 'packages/rackpal_core')
        try { dart test test/validation/drc_corpus_test.dart }
        finally { Pop-Location }
    }

    if (-not $SkipTests) {
        # DR-178 (#843). The core suite runs UNTIMED and its stopwatch
        # assertions run LAST, alone, one test at a time, so a one-frame
        # budget does not share the machine with its own suite. The last
        # entry is that step; drop it and the budgets run nowhere.
        $suites = @(
            @{ Package = 'packages/rackpal_core';   Runner = 'dart';    Name = 'rackpal_core';       Tests = 'untimed' },
            @{ Package = 'packages/rackpal_text';   Runner = 'dart';    Name = 'rackpal_text';       Tests = 'all' },
            @{ Package = 'packages/rackpal_export'; Runner = 'dart';    Name = 'rackpal_export';     Tests = 'all' },
            @{ Package = 'packages/rackpal_pdfium'; Runner = 'dart';    Name = 'rackpal_pdfium';     Tests = 'all' },
            @{ Package = 'packages/rackpal_ui';     Runner = 'flutter'; Name = 'rackpal_ui';         Tests = 'all' },
            @{ Package = 'apps/rackpal';            Runner = 'flutter'; Name = 'rackpal_app';        Tests = 'all' },
            @{ Package = 'packages/rackpal_core';   Runner = 'dart';    Name = 'rackpal_core_timed'; Tests = 'timed' }
        )
        foreach ($suite in $suites) {
            Invoke-Gate "suite: $($suite.Name)" {
                pwsh -NoProfile -File (Join-Path $ci 'run_suite.ps1') `
                    -Package $suite.Package -Runner $suite.Runner `
                    -Name $suite.Name -Tests $suite.Tests -OutDir $outDir
            }
        }
    }

    if (-not $SkipBuild) {
        Invoke-Gate 'flutter build windows --release' {
            Push-Location (Join-Path $RepoRoot 'apps/rackpal')
            try { flutter build windows --release } finally { Pop-Location }
        }
        Invoke-Gate 'windows release output' {
            pwsh -NoProfile -File (Join-Path $ci 'verify_windows_build.ps1')
        }
    }
} finally {
    Pop-Location
}

Write-Host ''
Write-Host ('=' * 70)
Write-Host '  SUMMARY'
Write-Host ('=' * 70)
foreach ($result in $results) {
    $mark = if ($result.Exit -eq 0) { 'pass' } else { "FAIL ($($result.Exit))" }
    Write-Host ('  {0,-8} {1}' -f $mark, $result.Gate)
}

$failed = @($results | Where-Object { $_.Exit -ne 0 })
Write-Host ''
if ($failed.Count -gt 0) {
    Write-Host "$($failed.Count) of $($results.Count) gates FAILED"
    exit 1
}
Write-Host "all $($results.Count) gates passed"
Write-Host 'NOTE: this did not test a clean checkout. Only the pipeline does.'
exit 0
