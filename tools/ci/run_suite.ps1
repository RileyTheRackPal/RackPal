<#
.SYNOPSIS
    Run one package's test suite, capture the JSON event stream, and convert
    it to JUnit XML that the Azure DevOps Tests tab can render.

.DESCRIPTION
    THE RUNNER'S EXIT CODE IS THE VERDICT, always. The XML is a report; it
    never decides pass or fail. This script exits with whatever `dart test` or
    `flutter test` exited with, and only overrides that upward -- never
    downward -- if the conversion itself could not produce a report.

    WHY A SCRIPT RATHER THAN FIVE INLINE YAML STEPS. Three reasons, all of
    which have teeth:

      * ONE COMMAND TO REPRODUCE LOCALLY. `pwsh -File tools/ci/run_suite.ps1
        -Package packages/rackpal_core -Runner dart -Name rackpal_core`
        does on this machine exactly what the agent does. A gate you cannot
        run by hand is a gate you debug by pushing commits.
      * REDIRECTION IS NOT AS SIMPLE AS `>`. `Out-File` and `>` apply a width
        to their output; a JSON event line carrying a long failure message
        can be wrapped, and a wrapped line is not JSON any more, so the
        failure quietly vanishes from the report. This writes through a
        StreamWriter, which does not wrap, in UTF-8 without a BOM (test names
        in this repository contain em dashes; a mis-decoded stream produces
        mojibake test names in the Tests tab).
      * EXIT CODES SURVIVE THE PIPELINE. `$LASTEXITCODE` is captured
        immediately after the native command and returned unaltered.

    NO TAG FILTERING. docs/11 section 7 sketches `--exclude-tags golden` for
    the main job. This runs every test in every suite instead, deliberately:
    there are zero tagged tests in this repository today, so an exclusion
    would exclude nothing now and would silently drop the first golden
    somebody writes -- the precise failure the pipeline header warns about.

.PARAMETER Package
    Repo-relative directory of the package, e.g. packages/rackpal_core.

.PARAMETER Runner
    'dart' for pure-Dart packages, 'flutter' for the Flutter ones.

.PARAMETER Name
    Short suite name; used for the artifact file names and as the JUnit
    classname prefix.

.PARAMETER OutDir
    Where the .jsonl stream and .junit.xml land. Default build/ci at the repo
    root -- gitignored, and skipped by the tree sweep in
    apps/rackpal/test/gitattributes_byte_exactness_test.dart.

.PARAMETER ExtraArgs
    Passed through to the runner. FOR LOCAL USE ONLY -- the pipeline passes
    none, because a suite the pipeline narrows is a suite the pipeline is not
    running. Handy for `-ExtraArgs test/byte_roundtrip_test.dart` while
    debugging one file.

.PARAMETER MinTests
    THE SUITE IS NOT VACUOUS. Fail if fewer than this many cases ran AND
    WERE NOT SKIPPED, even when every one of them passed. Defaults to the
    floor recorded for `-Name` in `$SuiteFloors` below -- ONE place, so
    azure-pipelines.yml and run_local.ps1 cannot disagree about it.

    A test runner that finds nothing exits 0 and prints a cheerful summary.
    So does a suite whose files stopped being discovered because a directory
    moved, or whose `main()` came back empty after a bad merge. Green over
    nothing is the failure this repository keeps meeting in other forms --
    the "rule is not vacuous" test in
    apps/rackpal/test/gitattributes_byte_exactness_test.dart exists for
    exactly this reason -- and it is the one failure a passing test run
    cannot report on its own.

    A FLOOR, NOT A RATCHET, and the asymmetry is deliberate. Growing past it
    is logged and nothing more: tests going UP is the point, and a gate that
    nags on every good day gets ignored on the bad one. Dropping below it
    fails, and lowering the floor is then a visible line in a diff somebody
    has to justify.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Package,
    [Parameter(Mandatory = $true)][ValidateSet('dart', 'flutter')][string]$Runner,
    [Parameter(Mandatory = $true)][string]$Name,
    [string]$RepoRoot = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)),
    [string]$OutDir,
    [string[]]$ExtraArgs = @(),
    [int]$MinTests = 0
)

$ErrorActionPreference = 'Stop'

# ======================================================================
# THE NON-VACUITY FLOORS. See the -MinTests help above for the argument.
# ======================================================================
# MEASURED on Flutter 3.44.4 by running each suite through THIS script and
# counting the non-skipped cases in the JUnit document it produces.
#
# THEY ARE THE COUNTS OF THE TREE THEY SHIP WITH, and that is the whole
# point of the gate. The first version of this table was measured at commit
# 0fa532d and left there while four more commits landed, which put 131 tests
# of slack under the floors -- up to 90 core, 28 ui and 13 app tests could
# have been deleted or stopped being discovered while this script logged a
# cheerful "+N" and exited 0. A floor three commits behind is a loosened
# floor with no diff to review, which is exactly what the "lowering one is a
# reviewed act" rule below exists to prevent. RE-MEASURE THEM IN ANY COMMIT
# THAT ADDS OR REMOVES TESTS; going up is free, and the diff is one line.
#
# LOWERING ONE IS A REVIEWED ACT and belongs in the same commit as the test
# removal that made it necessary.
# RE-MEASURED 2026-08-25 (#764). The instruction above had not been followed
# for a long time and the slack it warns about had grown from 131 to 3,247:
# core 976 against 3263 actual, ui 382 against 1162, app 664 against 838.
# Two thousand two hundred and eighty-seven core tests could have stopped
# being discovered while this script printed "+2287" and exited 0. Measured
# by `run_local.ps1 -SkipBuild` on that date, all five suites green.
# RE-MEASURED 2026-08-25 again, at #770/#772/#776: core 3263 -> 3279, the seven
# `brand_test.dart` cases and the nine `console_palette_test.dart` ones, less
# nothing, and ui 1162 -> 1170 for console_theme_test. Raised in the same
# commit that added them, core 3279 -> 3281 at #779, and app 838 -> 839 at
# DR-091 for the landing-view case, then 839 -> 841 at #775 for the font
# weight gate, and ui 1170 -> 1176 at #774. RE-MEASURED 2026-08-26 at #220
# (M4-I1): core 3281 -> 3311, the 30 cases of `archetypes_test.dart`, and
# ui 1176 -> 1190 for the 14 of `archetype_dialogs_test.dart`. RE-MEASURED
# again at #221 (M4-I2): core 3311 -> 3331 for the 20 Switch cases, ui
# 1190 -> 1201 for its 11. And again at #222 (M4-I3): core 3331 -> 3358 for
# `port_import_test.dart`'s 27, ui 1201 -> 1213 for its 12. Which is the
# whole instruction above and is cheap only while it stays a habit.
# RE-MEASURED 2026-08-28 at #785 (M4-L0, DR-098): core 3365 -> 3379, the 14
# cases of `test/model/device_overrides_test.dart`. NOTHING WAS REMOVED, and
# the way that was checked is worth the line: deleting
# `DeviceOverrides.displayName` and `.typePrefix` broke no test, because no
# test had ever named either. That is the same absence the ruling's census
# found in the shipped corpus, arriving from the other direction.
# RE-MEASURED 2026-08-28 again at #230 (M4-L1): core 3379 -> 3389, the 10 cases
# of `test/commands/device_override_edit_test.dart`. And once more when the same
# task shipped its UI half: core 3389 -> 3391 for the two scope-cue cases in
# `console_palette_test.dart`, and ui 1213 -> 1220 for the seven of
# `test/inspector/device_overrides_section_test.dart`.
# RE-MEASURED 2026-08-29 when #230 finished its last two fields: core
# 3391 -> 3394 for the three cases of `test/draw/device_accent_test.dart`, and
# ui 1220 -> 1224 for the four accent and body-depth cases in the same
# inspector file.
# RE-MEASURED 2026-08-29 at #232 (M4-L3, door 3): core 3394 -> 3408, the 14
# cases of `test/commands/template_fork_commands_test.dart`. And at `#251`:
# core 3408 -> 3415, the seven of
# `test/sheet/clause2_drill_expectations_test.dart`, which pins docs/17's
# drill script against the product after two of its steps were found rotted.
# RE-MEASURED 2026-08-29 at `#231`/`#232` (the three doors): ui 1224 -> 1237,
# the nine of `test/canvas/device_doors_menu_test.dart` and the four
# secondary-button cases added to `canvas_intent_detector_test.dart`. Core is
# unchanged: `templateIdFor` MOVED from the app into core and its one caller
# moved with it, so no core case was added or removed. Door 2's shell half
# then took app 841 -> 847, the six of `test/session/door_two_test.dart`:
# the routing and DR-099's dirty-draft refusal are both the shell's, so
# `rackpal_ui` can only see a template id handed to a callback.
# RE-MEASURED 2026-08-29 at `#233` (M4-L4): core 3415 -> 3427, the twelve of
# `test/commands/port_override_commands_test.dart`. `PortOverrides.label` was
# DELETED as an unread duplicate of `Port.userLabel` and NO TEST NAMED IT,
# which is the same absence DR-098's census found on the device side. Its
# form then took ui 1237 -> 1243, the six of
# `test/inspector/device_ports_section_test.dart`. Those mount the section
# DIRECTLY rather than through `RackCanvasScreen`, because every template on
# the demo document has ZERO ports and a screen-level test would have been
# asserting an empty list.
$SuiteFloors = @{
    'rackpal_core'   = 3445
    'rackpal_text'   = 1
    'rackpal_export' = 189
    'rackpal_ui'     = 1243
    'rackpal_app'    = 848
}

# Test names in this repository contain em dashes. Without this the stream is
# decoded with the console code page and the Tests tab shows mojibake.
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

if (-not $PSBoundParameters.ContainsKey('MinTests')) {
    if ($SuiteFloors.ContainsKey($Name)) {
        $MinTests = $SuiteFloors[$Name]
    } else {
        # NEVER SILENTLY DO NOTHING. A name with no floor is a legitimate
        # thing (ad-hoc local runs use one), but the run must not read as
        # though non-vacuity was checked when it was not.
        Write-Host "  NOTE: no floor recorded for suite name '$Name', so this run proves nothing about whether the suite is vacuous. Pass -MinTests, or add it to `$SuiteFloors in tools/ci/run_suite.ps1 if it is one of the project's suites."
    }
}

if (-not $OutDir) { $OutDir = Join-Path $RepoRoot 'build/ci' }
$null = New-Item -ItemType Directory -Path $OutDir -Force

$packageDir = Join-Path $RepoRoot $Package
if (-not (Test-Path $packageDir)) {
    Write-Host "##vso[task.logissue type=error]run_suite: no such package directory: $packageDir"
    exit 1
}

$jsonPath  = Join-Path $OutDir "$Name.jsonl"
$junitPath = Join-Path $OutDir "$Name.junit.xml"

# `dart test --reporter=json` and `flutter test --machine` emit the SAME
# event protocol; only the flag differs.
$testArgs = if ($Runner -eq 'flutter') {
    @('test', '--machine') + $ExtraArgs
} else {
    @('test', '--reporter=json') + $ExtraArgs
}

Write-Host "== $Name =="
Write-Host "  package : $Package"
Write-Host "  command : $Runner $($testArgs -join ' ')"
Write-Host "  stream  : $jsonPath"

$writer = [System.IO.StreamWriter]::new(
    $jsonPath, $false, [System.Text.UTF8Encoding]::new($false))
Push-Location $packageDir
try {
    & $Runner @testArgs | ForEach-Object { $writer.WriteLine($_) }
    $runnerExit = $LASTEXITCODE
} finally {
    Pop-Location
    $writer.Dispose()
}

Write-Host "  runner exit : $runnerExit"

$converter = Join-Path $PSScriptRoot 'junit_from_dart_test.py'
& python $converter --input $jsonPath --output $junitPath --suite $Name
$convertExit = $LASTEXITCODE

if ($convertExit -ne 0) {
    # A missing report over a passing run is still a failure of this step:
    # the pipeline promises a rendered result and did not deliver one, and
    # the next person would read the silence as "no tests in that package".
    Write-Host "##vso[task.logissue type=error]run_suite: JUnit conversion for $Name failed (exit $convertExit). Raw stream kept at $jsonPath."
    exit 1
}

if ($runnerExit -ne 0) {
    Write-Host "##vso[task.logissue type=error]run_suite: $Name FAILED (exit $runnerExit)."
    exit $runnerExit
}

# THE NON-VACUITY FLOOR. Counted from the JUnit document rather than from
# the runner's own summary, so it also proves the report the Tests tab will
# show is the report of a real run. See the -MinTests help above.
if ($MinTests -gt 0) {
    if (-not (Test-Path $junitPath)) {
        Write-Host "##vso[task.logissue type=error]run_suite: $Name produced no JUnit document to count."
        exit 1
    }
    [xml]$document = Get-Content -Path $junitPath -Raw
    # SKIPPED CASES DO NOT COUNT. The JUnit `tests` attribute includes them
    # (junit_from_dart_test.py increments totals['tests'] for every visible
    # case BEFORE the skip branch), so a floor read straight off it is
    # satisfied by a suite in which nothing actually ran. Measured: a
    # 3-test package with `skip:` on all three reported tests="3"
    # skipped="3", met a floor of 3, and exited 0 -- "green over nothing",
    # which is the exact failure this floor exists to catch. A whole-file
    # `@Skip` was already caught (dart test collapses it to one `(suite)`
    # case); per-test `skip:` was the hole.
    $declared = [int]$document.testsuites.testsuite.tests
    $skipped = [int]$document.testsuites.testsuite.skipped
    $count = $declared - $skipped
    if ($skipped -gt 0) {
        Write-Host "  NOTE: $skipped of $declared case(s) were SKIPPED and do not count toward the floor."
    }
    if ($count -lt $MinTests) {
        Write-Host "##vso[task.logissue type=error]run_suite: $Name reported only $count non-skipped test(s) (of $declared declared, $skipped skipped), below the floor of $MinTests -- and every one of them passed, which is exactly how a suite that stopped being discovered, or was silenced with `skip:`, reads as green. Either tests were removed (lower the floor in `$SuiteFloors in tools/ci/run_suite.ps1 in the same change, and say why) or the runner found fewer files than it should have."
        exit 1
    }
    if ($count -gt $MinTests) {
        # Logged, not warned. Tests going up is the point.
        Write-Host "  $count tests (floor $MinTests, +$($count - $MinTests))"
    } else {
        Write-Host "  $count tests (floor $MinTests, exactly at it)"
    }
}

exit 0
