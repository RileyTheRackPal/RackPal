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
# RE-MEASURED 2026-08-29 at `#234` (M4-M1): app 847 -> 848, one case in
# `test/session/file_dialog_flags_test.dart`. Two of that file's assertions
# were REPLACED rather than added: both pinned the exact source text of a
# ternary, which is a mechanism assertion the house style forbids and which
# the third file-dialog kind broke on contact.
# RE-MEASURED 2026-08-29 at `#235` (M4-M2, DR-100): core 3427 -> 3445, the
# eighteen of `test/library/rmdx_codec_test.dart`. Then 3445 -> 3455 at
# `#236` for the ten of `test/library/template_import_test.dart`. The
# codec's sweep is 48 templates wide inside ONE of those eighteen cases: it
# runs every seeded template through bytes and back, which is the only
# shape that could catch a key the file layout silently drops.
# RE-MEASURED 2026-08-29 at `#236` (M4-M3, DR-101): ui 1243 -> 1257 for the
# fourteen of `test/library/device_template_io_dialogs_test.dart`, and app
# 848 -> 859 for the eleven of `test/session/device_template_io_test.dart`.
# The split is `session_prompts.dart`'s: the BRANCHES are core's and were
# counted above, the dialogs' copy and buttons are ui's, and what is left
# for app is the sequence and the places it can end early.
# RE-MEASURED 2026-08-29 at `#795` (the real sha256): core 3455 -> 3469 for
# the fourteen of `test/library/template_hash_test.dart`, ui 1257 -> 1261 for
# the four AC-042 warning cases added to the dialogs file, and app 859 -> 860
# for the second case in `device_builder_actions_test.dart`. That file's
# `content hash` group USED TO PIN THE PLACEHOLDER and asserted
# `unhashed:tpl.hdmi_matrix_16x16@2`; it was honest when written, because
# that WAS the intended behaviour, and it had to move when the behaviour did.
# NOTHING WAS REMOVED. The ~150 test fixtures carrying `'h'` and
# `'sha256:test'` were left exactly as they are: `templateHashMatches`
# answers UNKNOWN for anything that is not 64 hex digits, so none of them
# reads as a mismatch, and rewriting them would have been the change that
# made this task expensive for no gain.
# RE-MEASURED 2026-08-29 at `#237` (M4-M4): app 860 -> 871, the eleven of
# `test/session/import_hardening_test.dart`. Core is unchanged:
# `checkImportSize` was EXTRACTED from `checkJsonLimits` rather than added
# beside it, so the size cap has one implementation and core gained no case.
#
# THAT FILE IS A CENSUS AS A TEST, and it earned its place on its first run
# by naming three byte-reading call sites the author had not listed. Two
# were real import paths that read before they measured, and one of those
# had shipped two hours earlier at `#236`.
# RE-MEASURED 2026-08-29 at `#238` (M4-N1): app 871 -> 881, the ten of
# `test/storage/library_directory_test.dart`. Every one of them is an
# ABSENCE case: the directory missing, unreadable, or a file vanishing
# between the listing and the stat. Listing files in a folder is not where
# this goes wrong, and in all three the required behaviour is the same, an
# empty shelf and a working palette.
# RE-MEASURED 2026-08-29 at `#239` (M4-N2): core 3469 -> 3483, the fourteen
# of `test/library/rmda_codec_test.dart`, and app 881 -> 882 for the .rmda
# row `#237`'s census gate DEMANDED. Its sweep is the `.rmdx` sweep's shape
# for a sharper reason: one `.rmdx` losing a key costs one template and one
# `.rmda` losing it costs every template in the pack, silently.
# RE-MEASURED 2026-08-29 at `#240` (M4-N3): core 3483 -> 3492 for the nine
# of `test/library/library_import_test.dart`, ui 1261 -> 1273 for the twelve
# of `test/library/library_io_dialogs_test.dart`, and app 882 -> 894 for the
# twelve of `test/session/library_io_test.dart` plus the row and assertion
# `#237`'s census gate demanded for the SECOND chapter running.
#
# TWO OF THE UI TWELVE FOUND REAL DEFECTS ON FIRST RUN, both invisible to
# anything but a pumped widget: the export dialog overflowed by 56 pixels
# the moment its picker opened, and its Export button read the name field
# without anything rebuilding when that field changed, so clearing the name
# left the button enabled.
# RE-MEASURED 2026-08-30 at `#241` (M4-N4): core 3492 -> 3508 for the sixteen
# merge and provenance cases in `test/derived/placeable_templates_test.dart`,
# and app 894 -> 908 for the fourteen of `test/storage/library_shelf_test.dart`.
# Nothing was removed. `PlaceableTemplate.key` was RENAMED to `documentKey` and
# typed nullable, which moved four assertions rather than deleting them.
# RE-MEASURED 2026-08-30 again at `#242` (M4-N5): core 3508 -> 3525, the
# seventeen of `test/library/library_placement_test.dart`, and ui 1273 -> 1289
# for the thirteen of `test/canvas/library_rows_place_test.dart` plus the three
# of `test/canvas/palette_click_is_not_a_drag_test.dart`. That last file is a
# DEFECT this chapter found rather than a feature it added: a plain click on a
# palette row announced "Released outside the rack ... was not placed" for a
# gesture nobody made, and a grep found no test asserting that message in
# either direction, which is how it survived a milestone.

# RE-MEASURED 2026-08-30 at `#244` (M4-O2): core 3525 -> 3546, the twenty-one
# of `test/derived/template_search_test.dart`, and ui 1289 -> 1292 for the three
# end-to-end cases added to `device_palette_panel_test.dart`. Nothing was
# removed: the palette's private `_matchesQuery` MOVED to core and grew, and its
# two existing callers moved with it.

# RE-MEASURED 2026-08-30 at `#243` (M4-O1, the facts layer): core 3546 -> 3562,
# the sixteen of `test/derived/template_facts_test.dart`. DR-104 §11.103.6 said
# each of `#243`'s eight filter chips "needs a producer this ruling does not
# grant it"; the census found all eight already in the model, so the file is a
# projection of existing answers and its test runs against the SEEDED catalog
# rather than against fixtures, because a chip is a promise about the 48.

# RE-MEASURED 2026-08-30 at `#243` (M4-O1, the browser): ui 1292 -> 1311, the
# nineteen of `test/browser/device_browser_screen_test.dart`, and app 908 -> 909
# for the case `door_two_test.dart` gained when the Device Manager tab stopped
# being the blank builder. NOTHING WAS REMOVED there: five of its cases moved
# from `openDeviceManager` to a new `openNewTemplate` helper, because the tab is
# the browser now and its first `TextField` is the SEARCH BOX. One of those five
# would otherwise have gone on passing while asserting a refusal that could no
# longer fire.

# RE-MEASURED 2026-08-30 at `#245` (M4-O3, favourites): ui 1311 -> 1324, the
# eight star and pinning cases in `device_browser_screen_test.dart` plus the
# five pinned-group cases in `device_palette_panel_test.dart`, and app 909 -> 916
# for the seven `AppPrefs` favourites cases in `prefs_store_test.dart`. Nothing
# was removed. The browser suite found a REAL DEFECT on its first run: the star's
# 28px tap target overflowed the card's fixed 132px extent by 2px, which is the
# second time this milestone a fixed extent has been the bug and the second time
# only a pumped widget could see it.

# RE-MEASURED 2026-08-30 at `#226` (M4-K1, schema 3): core 3562 -> 3570, the
# eight `v2 -> v3` cases in `migration_corpus_test.dart`. NOTHING WAS REMOVED.
# `PortDef.position` became nullable, so 27 files stopped passing
# `kUnplacedPanelPosition`; that is an argument going away, not a case. Two
# checked-in goldens were REGENERATED deliberately (`byte_roundtrip` and the
# schematic perf fixture) and a THIRD was captured first, at v2, because
# regenerating the only file that carried zero positions would have left the
# new migration with no real-file coverage at all.

# RE-MEASURED 2026-08-30 at `#226` (M4-K1, the algorithm): core 3570 -> 3590,
# the twenty of `test/scene/panel_layer_test.dart`. TWO of those cases started
# as assumptions and became measurements when they failed: 48 RJ45s do NOT
# overflow a 1U panel (an RJ45 cutout is 10mm, so 48 is two rows and 20mm), and
# TWO seeded archetypes DO overflow their own (A03 and N01, both dense 1U).
# Both are now pinned by name so the footprint table cannot move silently.
#
# RE-MEASURED 2026-08-30 at `#229` (M4-K4): core 3590 -> 3592, the two of
# `test/scene/symbol_sizing_seam_test.dart`. They guard a SEAM rather than a
# behaviour: `sizeSymbolForBody` was extracted from the schematic scene so the
# device builder's preview draws the sheet's symbol instead of a second one,
# and the test replays all 93 fixture devices through both paths.
#
# RE-MEASURED 2026-08-30 at `#229` again: core 3592 -> 3600, the eight of
# `test/scene/panel_draw_test.dart`. THREE of the eight started as assumptions
# and became measurements when they failed: an invented 40-port RJ45 body does
# NOT overflow a 1U panel (40 x 10mm is 400mm inside a 432mm chassis, so the
# seeded N01 is used instead), a zero-U body DOES still lay out and draw
# (`frontU` is rack occupancy, and a wall plate has holes without having any),
# and `PanelPalette` had to name both CR-082 stroke knobs because
# `draw_source_gate_test.dart` refuses a Stroke that decides only one.

# RE-MEASURED 2026-08-30 at `#229` a third time: core 3600 -> 3609, the nine
# of `test/scene/symbol_collapse_test.dart`. The first of them is the one that
# matters: a seeded 48-port switch STILL DRAWS 48 PINS by default, which is
# what says the schematic canvas did not move and `schematic_perf_test.dart`'s
# 4155-op M2-C baseline is still measuring the same drawing.

# RE-MEASURED 2026-08-30 at `#228` (the dock itself): ui 1324 -> 1333, the
# nine of `test/builder/preview_dock_test.dart`. They deliberately do NOT
# check that the previews look right -- every pixel comes from a core scene
# builder and the drawing is asserted beside it. They check that the dock asks
# the right builder, survives the bodies that break naive previews, collapses,
# and does not paint over the grid.

# RE-MEASURED 2026-08-30 at `#227` (the nudge canvas): core 3609 -> 3625 and
# ui 1333 -> 1351. The split is the point: 16 of the core cases are
# `panel_arrange_test.dart`, which asserts align/distribute/nudge/reset
# arithmetic WITHOUT pumping a widget, and the 18 ui cases assert only what a
# widget test can see and a core test cannot.

# RE-MEASURED 2026-08-31 at `#246` (the field-device path): ui 1351 -> 1361,
# the ten of `test/builder/field_device_form_test.dart`. Core, export and app
# are UNCHANGED, which is the measurement that made the model default safe to
# move: 92 files construct a bare `TemplateBody`, all five suites were run
# under the change before it was kept, and exactly one test moved -- one
# asserting the old default's LABEL, not its behaviour.

# RE-MEASURED 2026-08-31 at `#247` (the media-type editor): core 3625 -> 3634
# and ui 1361 -> 1373. The split is deliberate. The nine core cases assert the
# COMMANDS, including the one that matters: after a merge, the loser's id
# appears NOWHERE in the serialised document, so a sixth field naming a
# `MediaTypeId` fails that test rather than being silently orphaned. The twelve
# ui cases assert only what a widget test can see -- that a merge names how
# many references it will repoint before it does it.

# RE-MEASURED 2026-08-31 at `#248` (connector aliases and the two refusals):
# core 3634 -> 3651 and ui 1373 -> 1381. Seven of the core cases are
# `refused_surfaces_test.dart`, which asserts an ABSENCE -- no command that
# creates a signal family, a connector type, a colour scheme or a validation
# rule (RJ-012, AC-011). It carries its own vacuity guard, because a scan that
# walks zero files passes every such assertion while proving nothing.

# RE-MEASURED 2026-08-31 at `#805` (the settings surface): core 3651 -> 3662
# and ui 1381 -> 1389. `ProjectSettings` had 22 fields, had shipped since M0
# and NOTHING WROTE ANY OF THEM, which is what made RJ-012's third v1 surface
# unmeetable. The app floor does not move: its one new assertion is a CHANGED
# pin, RULE 14's File-menu census going 9 items to 10.

# RE-MEASURED 2026-08-31 again, at the `IdFormat` decode gate: core 3662 ->
# 3667 and ui 1389 -> 1390. `IdFormat`'s constructor validates NOTHING, so a
# hand-edited `.rmpj` carrying a pattern the renderer cannot read opened
# cleanly and threw at the first designator mint, a subsystem away from the
# field that caused it. Five wire tests cover the six settings patterns; the
# ui test is the unknown-token case, which is the one the settings dialog was
# letting escape unhandled. export, text and app do not move.

# RE-MEASURED 2026-09-01 at `#808`: ui 1403 -> 1406. `InspectorPanel` had no
# test at all, which is why a `Spacer` splitting the column's free space with
# the scroll view went unseen: the port section it pushed outside the viewport
# has its own test, and that one mounts the section directly and passes.
#
# RE-MEASURED 2026-09-02 at `#258` (M5-B1): core 3696 -> 3708. `Finding` and
# the fingerprint an acknowledgement joins on. The chapter called this "the
# part most likely to be got subtly wrong" and it is worse than it says: rule
# 42 GARBAGE-COLLECTS a stale acknowledgement on load, so a fingerprint that
# moved would delete the person's written reason and re-fire the finding bare.
# Most of the twelve assert what must NOT change the answer, and one pins the
# digest to a literal so a change of algorithm is a visible diff.
#
# RE-MEASURED 2026-09-02 at `#255` (M5-A3): core 3685 -> 3696. The connector
# compatibility matrix lands as `ConnectorTypeDef.matesWith`, seeded on 40 of
# the 49 shipped connectors. EMPTY IS UNKNOWN AND `CON-001` SKIPS IT (G4), so
# the nine unseeded ones are named with their reasons in the test rather than
# guessed at: a rule firing on an empty list is a false FAIL on a half-built
# table. The four starter goldens were regenerated, and the whole diff is
# `matesWith` arrays plus a trailing comma where it now follows what used to
# be the last key.
#
# RE-MEASURED 2026-09-02 at `#253`/`#254`/`#256` (M5-A): core 3672 -> 3685.
# The DRC rule catalogue lands as data, and the first test PARSES docs/02 §5
# and compares tier by tier: CR-021 says a rule not listed there does not
# exist, and a hand-kept Dart list beside a hand-kept markdown table is two
# copies of one fact. Thirteen cases, one of which is the 8/6/14 = 28 scope
# gate.
#
# RE-MEASURED 2026-09-01 at `#801`: core 3667 -> 3672 and ui 1399 -> 1403.
# CR-103's bank collapse now runs on first layout, AND the user can expand a
# bank again, which is the half the ruling always had and nothing had built.
# The core tests cover the exception set (per bank, per device, and a stale
# key changing nothing); the ui tests cover the click, the `B` key, and the
# defect that made the feature necessary: a collapsed bank leaves 47 of 48
# ports with no pin and no hit region.
#
# RE-MEASURED 2026-08-31 at `#802`: ui 1396 -> 1399. The narrow-window group
# in preview_dock_test.dart went from one test to four, because the dock
# stopped being a threshold and became a control: drawn at 1000, drawn at
# desktop width, hidden and restored by its own button, and leaving no
# dangling divider behind it.
#
# RE-MEASURED 2026-08-31 at `#803`: ui 1390 -> 1396, six widths in
# `builder_narrow_window_test.dart`. Each width needs its own tree because a
# `RenderFlex` reports its overflow ONCE per render object, so a single test
# re-pumped at six sizes measures one of them and reports clean for five.

$SuiteFloors = @{
    # 3963 at DR-126: +8 from ir_family_split_test.dart, which sweeps the
    # shipped catalogue rather than a fixture, plus one swapped near-miss
    # and one widened canary that net to zero.
    # 3978 at DR-128: +13 from declare_adapter_test.dart, the writer
    # InlineAdapter never had, and +2 for the census that found three
    # ghost ids in the AC-051 spring-back fixtures.
    # 3991 at DR-128 part two: +13 from insert_converter_test.dart.
    # 4010 at DR-128 part three: +16 from add_outlets_test.dart, PWR-003's
    # remedy, and +3 for the guard on Finding.withSeverity.
    # 4018 at DR-128 part four: +8 gating which rule offers which remedy,
    # after the ruling claimed two chip buttons that did not exist.
    # 4021 at #841: +3 for the producer census, which names the eleven
    # PortDef fields the seed builder cannot set rather than counting them.
    # 4035 at DR-130: +14 from mount_note_command_test.dart, the writer
    # OffRackPlacement.mountNote never had. Its canary earned its keep on
    # the first run: "no PLC finding from evaluateDocument" passed on a
    # rule that entry point never emits, for any document.
    # 4043 at DR-130 part two: +8 from mount_note_on_the_sheet_test.dart.
    # A producer that reaches no surface is DR-128 repeating one layer
    # out, and the ruling chose the smallest option ON THE GROUND that a
    # note reaches the schedule and the PDF.
    # 4049 at DR-131: +6 from speaker_bypass_test.dart. The bypass moves
    # the resolved FAMILY rather than one rule verdict, which is where
    # the fix belongs: ELE-006 was patched first and SIG-002 immediately
    # refused the same correct connection.
    # 4058 at DR-132: +9 from ele005_tap_budget_test.dart. The AC-051
    # pair proves ELE-005 fires; these prove it COUNTS honestly, which is
    # what a load rule gets wrong while passing its pair. One of them
    # caught the amplifier being reported as a speaker nobody measured.
    # 4109 at PLAN-A: +16 from draw/image_op_test.dart. Its translated
    # case earned the file on the first run: `BoundsCanvas.drawImage` was
    # written as `_ink(_toRoot(dst))` and `_ink` already maps through the
    # CTM, so every underlay landed at twice its own translation. No
    # sibling method makes that mistake, so no assertion about a rect
    # could have seen it.
    # 4144 at PLAN-B: +35 across three container files. +13 determinism,
    # one assertion per nondeterminism source rather than one round trip,
    # because a single `write(read(bytes)) == bytes` passes the moment the
    # writer is self-consistent and says nothing about WHICH knob is
    # fixed. +8 byte identity over the four checked-in starters, including
    # the negative that nothing writes a zip without a member. +14 error
    # cases, whose truncation group is the one that found `ZipDecoder`
    # returning an EMPTY archive rather than throwing, at six cut points
    # and on a four-byte file.
    # 4152 at PLAN-C part one: +8 from units/px_pt_separation_test.dart,
    # which is a SOURCE gate as well as a behavioural one. `PxPt` gaining
    # an `operator +`, a `toPt()` or a supertype is a one-line change that
    # looks like tidying and re-opens the collapse three documents rule
    # against; a running program cannot tell the two apart. Plus one byte
    # round-trip case for Location.riseAllowance, which
    # location_commands_test.dart demands per table row rather than per
    # command.
    # 4203 at PLAN-C part two: +20 from persistence/plan_serialization_
    # test.dart and +26 from commands/plan_commands_test.dart, plus five
    # in the migration corpus for the v4 -> v5 step. The serialization
    # file is where DR-136 came from: it set out to write the test `#621`
    # asked for, that a pin survives a codec which does not know the key,
    # and found that it cannot, because `Placement.unknown` is a reserved
    # container and not a harvester. It asserts the contract instead, so
    # nobody re-derives the false belief from an absence of tests.
    # The command file tests every epoch mask AGAINST A LISTENER rather
    # than against `touches`, including the negatives: pinning a rack
    # must NOT wake `EpochMask.rack`, and a mask that woke everything
    # would pass every positive assertion.
    # 4230 at PLAN-D part one: +27 from persistence/image_header_test.dart.
    # 4262 at DR-138: +31 from persistence/pdf_page_lift_test.dart, most of
    # them REFUSALS. A lifter that wrongly refuses costs one export; one
    # that wrongly accepts hands an installer a drawing with the stamp or
    # the redaction silently missing, so the case count is lopsided on
    # purpose. Re-measured: `dart test` reports 4262.
    # 4231 at DR-137: net +1 in container_determinism_test.dart. The STORE
    # assertion became a DEFLATE one and stayed a single test; the
    # verbatim-bytes search was REPLACED by a byte-for-byte round trip
    # (the obligation it was a proxy for), and a second case was added
    # asserting the ruling actually buys size on a line-art-shaped member.
    # Re-measured, not incremented: `dart test` reports 4231.
    # Two of those are SWEEPS rather than cases: every truncation of a good
    # PNG and JPEG, and every single-byte flip through a JPEG header, each
    # asserting only that the parser RETURNS rather than throws. That is
    # the property AC-058/D12 actually needs from a parser over hostile
    # input, and it is not expressible as a handful of hand-picked
    # malformed files.
    # 4266 at PLAN-E/2: +4 from the plan-drop group in
    # catalog_placement_test.dart, CR-104's third drop target. Two
    # mutations were run and both were killed: discarding the pin from the
    # placement fails three of the four, and removing the absent-underlay
    # refusal fails the one written for it. The group's real subject is
    # docs/15 §6's "in one command, so one undo restores both", which is
    # asserted as an artifact -- one command comes back, and reverting it
    # takes the pin with the device -- rather than by counting writes.
    # It was BRIEFLY +5. The fifth asserted a refusal for "called with
    # neither a rack nor a plan", which existed only because the first
    # draft relaxed `targetRack` to `Rack?`; a separate entry point makes
    # that state uncompilable, and a test for a state the types forbid is
    # worse than no test. The comment where it stood says so.
    # 4281 at PLAN-E/2 phase 2: +15 from scene/plan_scene_test.dart, the
    # third scene builder. Its subject is one coordinate rule -- one image
    # pixel is one scene unit -- and the cases assert it through `hitTest`
    # rather than by reading the mapping back, because being able to click
    # the pin is the artifact and the mapping is the mechanism.
    # Mutation-tested by transposing x and y in the marker centre: two
    # cases fail. Only two, and that is recorded rather than smoothed
    # over -- several fixtures use square coordinates like (10, 10) and
    # (500, 500), which cannot see a transposition at all. One case was
    # moved to (210, 45) once the mutation showed it.
    # 4284 at PLAN-E/4 phase 1: +3 for the room a plan drop writes
    # (DR-142 §11.141.5). A device has TWO location fields the model says
    # must agree, and `buildPlaceOnPlanCommand` set one, so every device
    # dropped on a plan since PLAN-E/2 printed no room on the Equipment
    # List. Mutation-tested by dropping the `locationId` argument back out
    # of `AddDeviceCommand.apply`, which is the state as shipped: two of
    # the three fail. The third asserts a RACKED device still names no
    # room and correctly survives, because it guards the derivation from
    # over-reaching rather than the fix from being absent.
    # The load-bearing case asserts the EQUIPMENT LIST CELL and not the
    # field: two fields disagreeing is invisible until something reads the
    # one that was not written, and that reader is the artifact.
    # 4296 at PLAN-E/4 phase 2: +12 from derived/unpinned_carriers_test.dart.
    # EVERY FIXTURE IS BUILT SO THE TWO PLAUSIBLE ANSWERS DIFFER, which is
    # the chapter's own brief: a count that counts the wrong thing passes on
    # a document where the wrong thing and the right thing are the same
    # number. Seven mutations run and all seven killed: a devices-only strip
    # fails 4, dropping outlets as well (the pre-DR-140 shape exactly) fails
    # 3, joining an unknown location to a named room fails 1, filtering
    # everything out of a site plan fails 1, dropping the total order fails
    # 2, reading "unpinned" as "no pin on THIS underlay" fails 1, and
    # reading a device's room from the INSTANCE field instead of the
    # placement's fails 1.
    # An eighth was written and is NOT counted: `for (final rack in
    # <Rack>[])` reported zero failures because `Rack` is not imported
    # there, so it was a compile error wearing a survivor's clothes. A
    # mutation that does not build measures nothing.
    # 4308 at PLAN-E/6 phase 1: +12 from draw/marquee_test.dart, CR-102's
    # band as geometry and the product's FIRST marquee (DR-139 §11.138).
    # EVERY FIXTURE IS BUILT SO WINDOW AND CROSS DISAGREE, which the
    # chapter's brief asks for in terms: two boxes and a band that
    # CONTAINS one and CLIPS the other, so window answers one and cross
    # answers two. A band swallowing both whole passes under either rule
    # and proves nothing about the convention.
    # Seven mutations, all killed: a zero-width drag becoming a cross
    # fails 1, reading Y instead of X fails 3, window behaving like cross
    # fails 2, cross behaving like window fails 1, dropping the partKey
    # filter fails 2, dropping the total order fails 1, and an off-by-one
    # containment edge fails 2.
    # THE partKey FILTER IS THE FINDING. A schematic symbol emits one
    # region per PORT carrying the symbol's entityId plus a body region
    # with none, so a band tested against every region would select a
    # whole device because it clipped ONE PIN, in the mode that means
    # "fully contained". Three cases pin it, including the one that proves
    # the filter is not a blanket refusal.
    # 4341 at PLAN-F/1: +26 from distance_entry_test.dart, whose
    # load-bearing case is a REFUSAL rather than an acceptance (a bare
    # `36` is 36 inches or 36 feet and the two differ by twelve), and +7
    # on plan_commands_test.dart for SetPlanScaleCommand, the writer
    # PlanScale did not have for two chapters.
    # 4343 at DR-145: +2 for the CAD-plot twin, a fixture built to the
    # SECOND real plan set's signature (classic xref, ANSI B pages, a
    # populated /Resources holding a font, and no /XObject) rather than
    # to the rule's boundary. One case is that every page is refused;
    # the other is that it is refused for the RIGHT reason, which is a
    # separate check and is the one docs/12 5.9.6.4 exists for.
    # 4354 at PLAN-F/2: +11 from plan_measurability_test.dart. Its
    # load-bearing case is a NEGATIVE: moving every pin changes
    # nothing, because the derivation asks whether a length is
    # DERIVABLE and never what it is. A Len per pin would be
    # planLowerBound early under another name and would pass every
    # counting case in the file. Five mutations killed.
    # 4360 at PLAN-F/3: +6 on plan_measurability_test.dart. Three on the
    # population DR-146 settled (39 unmeasurable become 39 measurable and
    # the subject count never moves; the two counts are complements in
    # every state; a rackless plan strands its pins too) and three on
    # PLN-001's sentence, whose VERB moves with its plural. Seven
    # mutations killed.
    # 4384 at PLAN-G/2 and PLAN-G/4: +18 from plan_length_test.dart and +6
    # in drc_rules_test.dart. Four of the eighteen are load-bearing and are
    # marked in the file, because every arithmetic case there passes
    # against a derivation that measures from the NEAREST pinned rack, from
    # the FIRST one, or that falls back to a device beyond an unpinned
    # outlet. The eighteenth was added BECAUSE A MUTATION SURVIVED: relaxing
    # "exactly one rack end" to "at least one" changes nothing for an
    # ordinary jumper or sub-feed, whose far end carries no pin either way,
    # so it took a run landing in two racks whose origin still names a
    # pinned outlet to tell the two rules apart. Seven mutations killed.
    # The six in drc_rules_test.dart are three pairs of controls: the same
    # unmeasured run on the same plan, over and under each limit, plus the
    # measured run that ignores the plan entirely.
    # 4392 at PLAN-G/3: +5 in schedule_test.dart and +3 in
    # cable_footage_test.dart. Two of the eight are load-bearing. The RANK
    # is one: a floor is more specific than a room estimate and still ranks
    # below it, so any derivation that put the plan above the room passes
    # every other case in that group. The SHEET FOOTER is the other, and it
    # is the rollup `_isQuantity`'s exhaustive switch does not guard:
    # `_footageOf` reads a `Len?` and never asks where it came from. Six
    # mutations killed.
    # 4411 at PLAN-H/1: +18 from plan_sheet_test.dart and +1 for the
    # perRack case in sheet_def_test.dart. Three of the eighteen are
    # load-bearing and assert an ABSENCE, because AUTO is what keeps M6's
    # four byte-verified starters from each growing a plan sheet: a
    # document with no underlay must resolve the identical set it resolved
    # before the role existed, and an imported underlay nobody pinned
    # anything to must print nothing. The fourth is the stray-pin case: a
    # drop dragged off the picture must not rescale the drawing, which is
    # why the fit reads `underlayBounds` and not the scene's ink.
    #
    # TWO EXISTING CANARIES MOVED AND NEITHER WAS WEAKENED.
    # sheet_def_test's `names the three sheets` and pull_sheet_clause_test's
    # ordered role list both pinned a three-value enum. The second now also
    # asserts the claim it was actually making, that no `pullSheet` role
    # exists, so the next legitimate addition does not have to re-read a
    # list to know what the case was for.
    # 4431 at PLAN-H/3: +14 from plan_callouts_test.dart and +6 in
    # plan_sheet_test.dart. Six are load-bearing and all six are about the
    # two ways a callout fails a stranger: it covers the thing it labels,
    # or it names the wrong wall.
    #
    # TWO OF THEM EXIST BECAUSE A MUTATION SURVIVED OR DID NOT BUILD.
    # Replacing the page mapping with raw image pixels left every
    # assertion green, because the cases pinned the pill's SIZE and never
    # its POSITION; two mapping cases were added and kill it. And the
    # ring's capacity was PROBED rather than guessed: a first draft
    # asserted crowding on twelve coincident pins and the ring solved all
    # twelve, since four radii by eight directions is thirty-two slots.
    # Twenty coincident drops all place clear and crowding starts at
    # twenty-four, which is the number the cases now use.
    # 4443 at PLAN-H/4: +12 from plan_scale_bar_test.dart. The
    # load-bearing one LAYS THE BAR AGAINST THE DRAWING: two pins exactly
    # one bar-length apart in the building must be exactly bar.lengthPt
    # apart on the page. Written that way rather than by recomputing the
    # implementation's multiplication, which agrees with it whichever
    # direction it is wrong in.
    #
    # AND ONE CASE EXISTS BECAUSE A MUTATION SURVIVED. Replacing
    # nanometresPerPixel with the literal value the first fixture happens
    # to produce passed everything, because every case was calibrated the
    # same way: a property proven by one fixture's number is not proven. A
    # second calibration at ten times the pixels per foot kills it.
    #
    # Two mutations DID NOT BUILD and both are facts rather than gaps: the
    # uncalibrated return and the bar's null check are enforced by the type
    # system, not by a case.
    # 4464 at PLAN-H/5: +21 from plan_schedule_test.dart, the Floor Plan
    # Device Schedule's rows and its band. Four of the cases exist because
    # a mutation survived: the id tiebreak needs FORTY rows sharing an
    # area and a reference, since Dart sorts a shorter list by insertion
    # and preserves order either way; the cap is pinned at eighty because
    # DR-152's draft said 180 and the layout held 60; and two count what
    # actually reached the ops, since `shown` is a claim about the sheet.
    # One mutation DID NOT BUILD and is a fact rather than a gap: the
    # entity lookups are non-null because the label resolved from the same
    # map one line earlier, so deleting the `!` is a compile error.
    # 4474 at PLAN-K/2: +10 from pdf_raster_plan_test.dart, the rule for
    # how many pixels a vector page renders at (DR-153 §11.152.5), which
    # discharges the question DR-145 §11.144.7 left owed. One case exists
    # because a mutation survived and it is a real hole: deleting the
    # non-positive guard looked harmless because every other case fell
    # through the one-pixel floor, but TWO negatives multiply to a positive
    # AREA, so a -1224 x -792 page took a negative dpi off the per-side cap
    # and came back as a plausible 30909 x 20000 raster, past the cap that
    # had just been consulted.
    # 4478 at PLAN-K/3: +4 from plan_serialization_test.dart, where a
    # rendered underlay keeps the PDF page it came from (DR-153 §11.152.6)
    # and a LIFTED one deliberately does not, since its stored bytes
    # already are the source. The load-bearing case is the absent key: the
    # asymmetry is the ruling, so "no source to keep" has to be visible in
    # the file rather than inferred.
    # 4480 at PLAN-K/4: +2 from pdf_page_lift_test.dart. A refusal that
    # happens after the /MediaBox is read now carries the page's size, so
    # something that draws vectors knows how big to draw it without
    # re-parsing the file; the second case is the other half, since the
    # three refusals ABOUT the box cannot report one.
    # 4507 at PLAN-I/1: +27. The plan advisories (DR-154), their AC-051
    # pairs, the hash comparator AC-042 had no verifying reader for, and
    # the two gates that had to widen to hold a second band: the
    # catalogue/predicate agreement and the fixture-pair coverage, each
    # now reporting PER BAND so a failure names the table it is about.
    #
    # ONE CASE IS ABOUT A DEFECT THE RULING FOUND IN A SHIPPED SURFACE.
    # `unpinnedCarriersFor` matched a location EXACTLY, so on a `Level 1`
    # plan an outlet filed in `Great Room` was neither a row nor an
    # unlocated count but dropped by a comparison; the strip and PLN-002
    # now share one subtree scope (§11.153.7a).
    # 4508 at PLAN-I/2 part one: +1 net. The locus census moved from a
    # sentence to a run of the rules (DR-154 §11.153.8a), which cost one
    # case for a net's designator fallback and widened three others.
    # THE ARITHMETIC IS SMALL AND WHAT IT FOUND IS NOT: `locusLabel` knew
    # four entity types and the rules point at six, so every `ELE-005`
    # finding since `#838` and every `PLN-*` since `PLAN-I/1` grouped
    # under "No single location" in the issues panel.
    # 4528 at PLAN-I/2 part two: +20 from plan_acknowledgement_test.dart.
    # CR-019's one mechanism, asserted END TO END over a document on which
    # all four PLN-* are open at once, rather than only through the gate
    # that admits a rule id. The load-bearing case is the fingerprint:
    # every PLN-* message embeds `underlay.name` and an underlay is
    # renamed by typing in a text field, so a name that reached the
    # fingerprint would have rule 42 collecting the acknowledgement on the
    # next load and reporting it as stale.
    # 4547 at LEN-A/1: +19 from persistence/room_outline_test.dart.
    # `RoomOutline` is the FIRST list-bearing value type in model/, and
    # seven of the nineteen are about that alone: Dart compares a List by
    # identity, and the last time a collection entered machinery built for
    # scalars it broke four sites at once and every one failed silently.
    # Equality, aliasing in both directions and the getter's object
    # identity are asserted before anything is built on them.
    # THE OTHER LOAD-BEARING ONE IS THE STAMP. A document carrying an
    # outline and no underlay is reachable only by hand-editing (CR-093),
    # and without its own check in `documentMinReaderVersion` an older
    # build would open that file read-write and delete the drawing on
    # save, which is DR-019 11.18.1's hazard exactly.
    # 4563 at LEN-A/2: +16 in commands/plan_commands_test.dart. Draw,
    # reshape and clear a room outline; three refusals; the underlay
    # removal that now takes outlines with it; DR-021's cascade asserted
    # rather than assumed; and the epoch masks against a listener.
    # ONE OF THE SIXTEEN ASSERTS A DEFECT RATHER THAN A CONTRACT (`#863`).
    # It set out to prove a refused command wakes nothing and found it
    # wakes everything AND lands on the undo stack, where the next undo
    # throws. Probed on the shipped SetPlanPinCommand, so it has been true
    # since PLAN-C and is command machinery rather than a plan bug. The
    # case records what happens and names the item that inverts it.
    # 4583 at LEN-A/3: +20 from derived/room_estimate_test.dart, and the
    # plan fixture builder moved to derived/fixtures/plan_doc.dart rather
    # than being copied (no net cases from the move).
    # FOUR OF THE TWENTY ARE ABOUT PICKING THE WRONG RACK, on
    # plan_length_test.dart's own rule: every arithmetic case passes
    # against a derivation measuring from the nearest pinned rack, or any
    # pinned rack, or the farthest, so the decoy sits on the OPPOSITE
    # side of correct in each and no single wrong rule survives both.
    # ONE ASSERTS AN ABSENCE AND NAMES `#861` AS WHAT RETIRES IT: the
    # derivation has no production caller yet, which is the state
    # PdfImageResolver sat in from PLAN-A to PLAN-H.
    # 4591 at LEN-A/5 part one: +8 from SetRoomEstimateCommand's cases.
    # `estimatedRunLengthFromRack` LEFT `LocationField`, the first field to
    # leave that table rather than never to have joined: a row writes ONE
    # field, so it could set the figure and leave a stale
    # `computedFromPlan` over a hand-typed number, which is the drift
    # DR-050 11.49.3 buys the marker to make impossible. The load-bearing
    # case is that UNDO restores both fields, since an undo that put the
    # figure back and left the marker would be that drift arriving through
    # the door marked undo.
    # 4596 at LEN-A/5 part two: +5 for `computedEstimateCount`, the count
    # that says how many of a takeoff's estimates the PLAN proposed rather
    # than a person entering them (DR-050 11.49.3). A SUBSET of
    # estimatedCount, unlike boundCount which is disjoint on purpose.
    # The load-bearing case is that a row which did not USE the room
    # estimate carries no marker even when the room has one: a run cut to
    # a measured length owes nothing to the room's figure.
    # 4599 at LEN-A/5 part three: +4 for `planEstimateMayFill`, less one
    # retired. THE RETIRED ONE IS THE INSTRUCTIVE HALF: `LEN-A/3` left a
    # case asserting `roomEstimateFor` had no production caller and naming
    # this chapter as what would fail it. This chapter wired it up and the
    # case DID NOT FAIL, because the scan walked rackpal_core/lib and the
    # caller landed in rackpal_ui. A gate whose scope was narrower than
    # its subject, written to guard against exactly that.
    'rackpal_core'   = 4599
    'rackpal_text'   = 1
    # 209 at PLAN-A: +9 from pdf_canvas_image_test.dart and +5 from the
    # harness self-test's new XObject group. Both are about ONE fact a
    # bounding box cannot carry: a PDF image occupies the unit square with
    # its top row at v = 1, so a vertically flipped placement produces an
    # IDENTICAL box and an upside-down floorplan. Mutation-tested by
    # deleting the counter-flip: three of the four orientation cases fail.
    # 220 at PLAN-H/1: +11 from plan_image_test.dart. PLAN-A/3 already
    # asserted no /SMask and no /ExtGState against a PdfImage the TEST
    # built with `alpha: false`; that proves the canvas, not the thing
    # which builds a PdfImage in production, and that function did not
    # exist until now. Two cases are load-bearing beyond the alpha pair: a
    # fully transparent pixel must become paper rather than black, since a
    # pass that discarded alpha would print a solid bar across the sheet,
    # and the deflate measurement, because "already-compressed rasters do
    # not deflate" is true of photographs and false of line art.
    # 222 at PLAN-H/5: +2 from plan_schedule_notice_test.dart. The band's
    # `omitted` count reaches the user through `ExportedDocument.notices`,
    # which is the channel scale_notice_test.dart exists because nothing
    # read. The control is the load-bearing half: it reads DEVICE SCHEDULE
    # and the sixtieth designator off the real PDF with the real font, so
    # an absent notice cannot be a sheet that was never drawn.
    # 227 at PLAN-I/2 part three: +5 in findings_never_block_export_test.
    # CR-022/G3 for the OTHER band. The three groups already there sweep
    # `kRuleCatalogue`, which has been one catalogue of two since DR-154,
    # so no PLN-* was inside any of them. "A complete sheet set" is read
    # OFF THE PAGE and not off `sheetCount`: four blank pages satisfy a
    # count, and `T1.01` is the sheet these four rules are about.
    'rackpal_export' = 227
    # 22 at PLAN-K/1: the whole package is new (DR-153 §11.152.4). Four of
    # them run with no binary present, because they are about FINDING it:
    # an override that points nowhere is an error rather than a fallback,
    # and the message a missing binary produces has to name the command
    # that fixes it. The rest need the vendored DLL, which a clean checkout
    # has, since CR-100 puts it in the repository rather than in a build
    # step.
    #
    # ONE OF THEM IS THE ONLY THING THAT CAN SEE A FLIPPED PAGE. A
    # vertically flipped render has the same size, the same ink and the
    # same bytes twice, so every other case passes against an upside-down
    # floorplan; deleting the counter-flip fails that case and nothing
    # else. PLAN-A/3 met the same defect one package over.
    'rackpal_pdfium' = 22
    # 1489 at DR-128: +6 from schematic_remedy_dr128_test.dart, which
    # presses the two new remedy buttons on chips raised by a real drag.
    # The core suites cannot see whether the SCREEN reaches the commands.
    # 1498 at DR-129: +9 from remedy_pairing_test.dart, which asserts in
    # both directions that a FindingRemedy reaches a pressable row, after
    # a ruling described a button the panel never drew.
    # 1506 at DR-130: +8 from mount_note_field_test.dart. One of the
    # eight mounts RackCanvasScreen rather than the panel, and asserts
    # the SCREEN hands over the callback: #847 is a panel that passes its
    # own tests because its own tests mount it.
    # 1513 at DR-132: +7 from port_tap_controls_test.dart. Its first
    # test is the DR-129 gate one layer along: SetPortFactCommand
    # switches exhaustively so the COMMAND had to handle both new fields,
    # and the widget lists its controls by hand, so both compiled green
    # with no way to set either.
    # 1523 at DR-133: +10 from validation_drawer_test.dart. Nine of
    # them mount the drawer, which is how DrcPanel passed its own suite
    # for two days while nothing in the product mounted it; the tenth
    # mounts RackCanvasScreen and is the assertion #847 IS.
    # 1539 at PLAN-A: +7 from draw/flutter_canvas_image_test.dart, which
    # RASTERISES rather than recording calls. It is the one place in this
    # repository where pixels are the right artifact: a recorder-based
    # test asserts that drawImageRect got two rects, which passes with the
    # source and destination swapped. Mutation-tested by flipping the
    # destination rect: five of five fail.
    # 1552 at DR-138: +13 from project/pdf_page_picker_dialog_test.dart.
    # EVERY CASE ANCHORS ON THE PAGE'S OWN LABEL, never on
    # `byType().first`: a grid is exactly where the first-of-many finder
    # locates the wrong cell and PASSES, since every tile is the same
    # widget. Two cases click page 2 and page 3 and assert the index that
    # comes back, so an off-by-one in the grid fails here.
    # 1558 at PLAN-E/1: +6 from canvas/plan_canvas_reuse_spike_test.dart,
    # the third canvas stood up out of the shipped parts to test a reuse
    # claim that had only ever been read. THE SPIKE IS THROWAWAY AND THE
    # FLOOR MOVES ANYWAY: E/2 replaces it with the real surface, and
    # lowering this back is then the visible line in a diff this file's
    # own header asks for. Two of the six were mutation-tested; a third
    # mutation deliberately SURVIVED, which is the finding (docs/12
    # §5.9.7): a widget test cannot see a dropped paint offset.
    # 1567 at PLAN-E/2 phase 3: +9 from canvas/plan/render_plan_canvas
    # _test.dart, the third render object and the image cache that finally
    # implements `FlutterImageResolver`.
    # THE PAINT-OFFSET CASE docs/12 §5.9.7.5 ASKED FOR IS NOT AMONG THEM,
    # and the section now says why: a repaint boundary is painted at
    # Offset.zero ALWAYS, so a canvas under a toolbar reads 0 rather than
    # 60 and the case cannot pass. The composition is protected by the
    # FREE FUNCTION case instead, which is what the schematic already did.
    # Four of the nine need `tester.runAsync`: Picture.toImage and
    # instantiateImageCodec are real engine work and never land inside
    # testWidgets' fake-async zone, which HANGS the file rather than
    # failing it.
    # 1578 at PLAN-E/2 phase 4: +11 from canvas/plan/plan_canvas_screen
    # _test.dart, the two gestures through the real widget tree. Every case
    # asserts the DOCUMENT rather than the controller's live drag state,
    # which is what makes "one command per gesture" checkable at all.
    # Mutation-tested twice, both killed: writing a SetPlanPinCommand per
    # pointer-move fails "ONE undo puts it back", and dropping the grab
    # offset fails the case written for it. An earlier draft of that
    # second case grabbed 12 units off centre, MISSED the marker's hit box
    # entirely (its radius is the underlay's long side over 110, about 5.5
    # here) and asserted that nothing moved, which it dutifully did not.
    # 1597 at PLAN-E/3: +13 from canvas/plan/plan_pin_arm_test.dart and +6
    # in plan_canvas_screen_test.dart, the drop-table-then-plan fast path.
    # The ruling they protect is DR-141's: THE MODE OUTLIVES THE PIN. A
    # one-shot arm (schematic_reveal.dart's `take()`) would pass any test
    # that only pinned once, so the cases pin and then look at what is
    # still on screen. Mutation-tested by ending the mode in `pinned()`:
    # five fail.
    # THE DROP TABLE'S OWN ARM ACTION IS NOT HERE, AND A GATE IS WHY.
    # `StructureEditorActions.onPinOnPlan` was written, wired to a row
    # menu and tested, and `actions_have_callers_test.dart` refused it:
    # nothing in lib/ supplies one, so the gesture is unreachable however
    # well the mode behind it is tested -- which is the M3-H/5 defect that
    # gate exists for, arriving again. It cannot become reachable until
    # PLAN-E/5 gives the Plan view a home to arm INTO (DR-091), so the
    # producer moved to that chapter rather than being reworded until the
    # regex stopped matching. See docs/12 §5.9.9.
    # 1611 at PLAN-E/4: +9 from canvas/plan/unpinned_strip_test.dart and +5
    # in plan_canvas_screen_test.dart for the drag OUT of the strip, which
    # is how a RACK gets its pin (DR-140 §11.139) and was the one gesture
    # docs/15's own table did not have.
    # Six mutations run and all six killed: ignoring the row's carrier and
    # pinning everything as a device fails 3, dropping the deleted-carrier
    # guard fails 1, committing a release made outside the canvas fails 2,
    # merging the unknown count into the total fails 1, dropping the
    # unknown line from the strip fails 1, and giving every row the SAME
    # key fails 4 -- that last one is the byType().first ambiguity this
    # repo has been bitten by, run as a mutation rather than trusted.
    # ONE OF THESE CASES EXISTS BECAUSE IT FIRED: the strip overflowed
    # vertically by 6px the first time a NAMED row rendered, and again by
    # 44px horizontally at 220 wide once that was fixed. It pumps five
    # widths, because a RenderFlex reports an overflow once per render
    # object and one pump measures one layout.
    # 1614 at PLAN-E/5 phase 2: +3 for `Esc` on the third canvas, its own
    # KeyScope.plan and the fourth row of an existing pattern (DR-143
    # §11.142.6). rackCancel, schematicCancel and dialogDismiss are three
    # ids, three scopes, one trigger and ONE LABEL, which
    # KeymapConflictKind.meaningDrift enforces; planCancel continues it.
    # THE LOAD-BEARING CASE IS THE FALL-THROUGH. Action.consumesKey
    # defaults to true and maps a run to `handled` whatever the body did,
    # so a screen declining INSIDE its callback still eats the key and a
    # dialog behind the canvas stops closing. Only isActionEnabled == false
    # yields `ignored`, and the case asserts it by putting a handler ABOVE
    # the screen and watching the key arrive.
    # Three mutations, all killed: an always-open gate fails 1, dismissing
    # AND clearing in one press fails 1, and dropping the autofocus fails
    # 3 -- that last is the app_shell post-mortem one level down, since a
    # Shortcuts below the root focus scope only sees keys pressed inside
    # its own subtree.
    # 1620 at PLAN-E/5 phase 3: +6 from canvas/plan/plan_editor_screen_test
    # .dart, the layout that finally puts four chapters on screen together.
    # THE LOAD-BEARING CASE DRAGS A RACK OUT OF THE STRIP AND ONTO THE
    # PLAN, through the real widget tree. Rack.planPin shipped at PLAN-C,
    # SetPlanPinCommand has accepted PinCarrier.rack just as long,
    # armCarrierDrag shipped at PLAN-E/4, and until this screen existed
    # nothing could hand the one to the other; without a rack pin PLN-003
    # fires and no length on the plan derives.
    # Three mutations, all killed: unwiring the strip's onArmDrag fails 2,
    # passing a ValueKey instead of the per-underlay GlobalKey fails 2 (the
    # first draft's real bug, which left currentState null and every strip
    # drag a silent no-op), and an empty state that stops naming the import
    # route fails 1.
    # A FOURTH IS RECORDED AS NOT COUNTED: `false ? null : X` compiles,
    # reported SURVIVED, and is semantically identical to X. That is the
    # same class as the PLAN-E/4 mutation that did not build -- a mutation
    # that changes nothing measures nothing -- arriving in a new costume.
    # 1622 at PLAN-E/5 phase 4: +2 for the drop table's `Pin on plan` row
    # menu, the producer a gate MOVED here from PLAN-E/3 (DR-141 §11.140.7,
    # DR-143 §11.142.4). It is reachable now: the shell owns the arm
    # controller above the tabs and the Plan view is in the strip.
    # AND THE GATE ITSELF WAS WIDENED, which is the finding worth the
    # line. actions_have_callers_test.dart matched only `.name(`, the one
    # shape a NON-nullable callback can take. `onPinOnPlan` is the FIRST
    # nullable Function field on any *Actions record in this package,
    # censused when it was added, and a nullable callback can only be
    # written `.name!(x)` or `.name?.call(x)`, so the gate reported a
    # fully wired gesture as uncalled. Three shapes now; a name never
    # invoked in any of them still fails, and a name merely PASSED still
    # does not count. Mutation-tested by unwiring the record call: it
    # fails, so the widening is not a rewording.
    # 1629 at PLAN-E/6 phase 2: +7 from canvas/marquee_adoption_test.dart,
    # CR-102's band on a real canvas and THE PRODUCT'S FIRST MULTI-
    # SELECTION. PLAN-E/1 censused the mechanism and found every SelectMode
    # call in lib/ passing exactly one id, so the case that matters is not
    # "a band appears" but "a band over two devices leaves TWO selected".
    # The window/cross pair uses ONE band dragged both ways, which is the
    # only arrangement that tests the convention rather than the geometry.
    # TWO DEFECTS WERE FOUND BY THESE CASES. `begin` set both corners, so
    # the band had a zero-size box from pointer-down and painted a
    # rectangle for every click on bare canvas; `_to` is now null until the
    # first update. And the rack numbers bottom-up, so a first draft's band
    # ran from ups.top down to amp.center and was INVERTED, catching
    # nothing and reading as a broken window rule.
    # A THIRD came from canvas_exclusivity_test.dart rather than from here:
    # its rule-1 case scrubbed empty canvas to hold the pointer claim, and
    # that scrub is now a marquee that catches nothing, which DESELECTS.
    # The premise was unstated; the sweep now selects what the next step
    # needs and asserts it.
    # 1632 at PLAN-E/6 phase 3: +3 from canvas/schematic/schematic_marquee
    # _test.dart, the THIRD adoption, which is what discharges DR-139: that
    # ruling's whole content is that the gesture is uniform across views.
    # WHAT THAT FILE ASSERTS IS THE BAND AND NOT THE SELECTION, and its
    # header says why rather than leaving it to be discovered.
    # SchematicCanvasScreen builds its own private SelectionController and
    # on this fixture selecting a device changes nothing a widget test can
    # read: the drawn-scope headline never renders in this harness and the
    # painted op count is IDENTICAL before and after a plain tap on a
    # symbol, 831 either way, measured. So a selection assertion here would
    # pass through a mechanism that does not report. The id count is
    # asserted where it CAN be read, on the rack elevation.
    # TWO MUTATIONS SURVIVED AND BOTH ARE RECORDED RATHER THAN PAPERED
    # OVER. Dropping `marquee.cancel()` from the click path survives, and
    # correctly: `begin` resets `_from` on every press, so nothing can
    # inherit a stale origin here, and that cancel is defensive rather than
    # load-bearing. The rack's version of this WAS load-bearing because it
    # consulted `isActive` across gestures. And feeding `update` the start
    # point instead of the pointer survives, because it still yields a band
    # widget and this file asserts the band's ARRIVAL rather than its
    # extent; the extent is core's, in marquee_test.dart.
    # The third mutation, never arming the band at all, is killed.
    # 1636 at PLAN-F/0: +4 from the band-and-click group in
    # plan_canvas_screen_test.dart. Only ONE of the four is load-bearing
    # against the defect, measured by restoring it: the other three stay
    # green with the condition mutated back, because a sweep clears the
    # selection too and `end` clears the band as surely as `cancel` does.
    # 1658 at PLAN-F/1: +22 from plan_calibrate_test.dart. Its end-to-end
    # cases assert the DOCUMENT, because a case asserting the pick
    # controller would survive SetPlanScaleCommand never running, which is
    # exactly how PlanScale sat reachable from nothing since PLAN-C.
    # 1665 at PLAN-F/2: +7 on plan_calibrate_test.dart, five on what
    # the report says and two on where the mask can be OBSERVED.
    # The recalibration case is the pair's reason: the row reads
    # identically before and after, so only the message can report
    # the most consequential edit the feature has.
    # 1672 at PLAN-F/3: +5 on plan_calibrate_test.dart and +2 on
    # plan_editor_screen_test.dart. The two on the editor are the ones
    # that could not be written anywhere else: a pin dragged out of the
    # strip onto an uncalibrated plan and onto a CALIBRATED one, which is
    # a state no fixture in this package had ever carried. A gate would
    # be added on a surface, so a case that ran the command would not see
    # it; two mutations on the drag confirm each case kills its own.
    # 1674 at PLAN-G/3: +2 in schedule_screen_test.dart, the two things
    # core cannot assert. The LEN cell renders `≥ 41` italic, and the
    # summary chip reads `1 bound` rather than folding into `N estimated`.
    # The fixture drops the home run's cut length, because `cut` outranks
    # every tier and a document keeping `78` would render `78` and pass an
    # assertion about a floor for a reason that has nothing to do with one.
    # 1677 at PLAN-K/4: +3 from pdf_page_picker_dialog_test.dart, where
    # the grid is handed a page that was RENDERED as well as one that was
    # lifted (DR-153). The load-bearing case is the caption: the tile
    # draws a 320 px thumbnail and must report the size the person would
    # GET, since "320 x 207, 19 dpi" is a fact about this dialog rather
    # than about anything on offer.
    # 1695 at LEN-A/4 part one: +18 from canvas/plan/plan_outline_test.dart.
    # The room-outline draw is the THIRD mode on this canvas and the third
    # LIFETIME: the arm outlives each pin, the calibration is consumed by
    # its own second click, and this accumulates until the shape closes.
    # The cases pin that difference, because the three look alike from
    # outside and ending differently is why they are three classes.
    # ONE IS A LAYOUT REGRESSION GUARD. The first draft of the chip's
    # close label overflowed its Row by 70 points at an 800-point canvas,
    # which a widget test reports as a failure and a shipped build reports
    # as a barber pole nobody files.
    # 1712 at LEN-A/4 part two: +17. The canvas wiring (10) and the room
    # list in the left rail (7). THE LOAD-BEARING ONE PRESSES THE REAL
    # BUTTON AND THEN CLICKS THE REAL CANVAS, because everything else in
    # this chapter passes against a mode nobody can start: PLAN-E/5 found
    # six functions and a dialog with no caller, and PLAN-E/6 shipped a
    # gesture that was dead until PLAN-F/0 because the canvas tests
    # predated the band and passed null.
    # 1723 at LEN-A/5: +11. The run-length editor AC-024 named and nobody
    # could type into (7), and the auto-fill on a closed outline (4). The
    # marker reads in all THREE directions, because an absent origin is
    # not "typed": every document written before LEN-A/1 carries a figure
    # with no recorded provenance.
    # 1753 at LEN-A/8: +30. The reshape mode (8), the chip (4), the drag
    # through the real canvas (16) and the reachability proof through the
    # real screen (6, one of which found a defect LEN-A/4 shipped: this
    # screen holds ONE outline controller for all plans and _openPlan
    # cancelled the calibration and not the draw, so two corners placed on
    # one plan survived a switch and closed a shape on another).
    # ELEVEN MUTATIONS, ELEVEN KILLS, including the two that matter most:
    # the canvas handed a null mode, and the button wired to nothing.
    'rackpal_ui'     = 1753
    # 930 at PLAN-B: +13 from storage/container_open_test.dart, the file
    # -layer states a container owes (AC-058/D3), through the real store
    # and the real presenter. Its copy assertions are the point: the
    # pre-existing `OpenZipContainer` sentence told users to "extract it
    # first", advice that DESTROYS a project once a project can be a zip,
    # and a test checking only the error TYPE would have left it standing.
    # +1 in document_store_test.dart, which gained the case proving a real
    # container opens beside the one proving six bytes of signature does
    # not.
    # 945 at PLAN-D: +15 from session/plan_import_test.dart. What is under
    # test is the ORDER, not just the outcome: every refusal here could
    # also be produced by a slower implementation that decoded first and
    # checked afterwards, so the cases use inputs a correct order survives
    # and an incorrect one does not. The 60000x60000 header in under a
    # hundred bytes is the one that separates them.
    # 954 at DR-138: +9 from session/pdf_page_import_test.dart. The point
    # of that file is that A LIFTED PAGE IS NOT PRIVILEGED: it re-enters
    # the ordinary import path, so PLAN-D/4's controls are asserted to
    # still fire on it. Exempting it because "we produced it" would be
    # exempting it because we trusted the stranger who sent the PDF.
    # 964 at PLAN-E/5 phase 1: +10 from session/floorplan_io_test.dart, the
    # CALLER that whole import path did not have. PLAN-D built every step,
    # tested each, and nothing in lib/ invoked any of it: censused at zero
    # call sites per symbol (DR-143 §11.142.1), so AddPlanUnderlayCommand
    # had no producer and no project could hold a floorplan.
    # The load-bearing case asserts BOTH writes, because an underlay whose
    # imageMember names bytes the container does not hold is a dangling
    # reference in a saved file and a test counting doc.underlays cannot
    # see it. Seven mutations run and all seven killed: never adding the
    # member fails 4, never running the command fails 2, routing by
    # extension instead of content fails 1, turning a cancelled page pick
    # into an Err fails 1, the wall clock instead of the injected one
    # fails 1, keeping the file extension in the name fails 2, and writing
    # the member on a REFUSED file fails 1.
    # TWO OF THESE CASES WERE VACUOUS IN THEIR FIRST DRAFT and are the
    # reason the fixture is borrowed: they used a stub beginning with
    # `%PDF-` that lifts no pages, so `anyOf(isNull, isA<Err>())` and
    # `pickerSawIt || underlays.isEmpty` both passed on a document nothing
    # was imported into. They now use pdf_page_import_test.dart's real
    # onePagePdf and assert what the picker actually received.
    # 965 at DR-145: +1 for the three-page CAD plot. Every other fixture
    # in pdf_page_import_test.dart is ONE page, so
    # PdfHasNoLiftablePageError.pageCount had only ever rendered as
    # `1 page` and the plural sentence a person actually sees was
    # untested.
    # 981 at PLAN-K/4: +16, the import flow rendering a page of vectors
    # instead of refusing it (DR-153). Three of them are
    # plan_import_pdfium_test.dart, which runs the REAL binding end to
    # end: the flow's own cases hand it a fake that returns a PNG of the
    # size asked for, which proves the sequence and nothing about pdfium.
    # The load-bearing case there counts DARK PIXELS in the stored
    # member, because every failure short of a crash produces a plausible
    # PNG of exactly the right size.
    # 985 at PLAN-K, after the merge: +4 from pdfium_install_test.dart.
    # The loader's third arm, the repository copy, HIDES THE ABSENCE OF
    # THE SECOND: a build run from inside the working tree walks up and
    # finds the committed DLL, so a missing install rule only fails on
    # somebody else's machine holding a packaged copy. A source gate, and
    # its limit is stated: it proves the rule is there and points at a
    # real file, and the build gate proves CMake obeyed it.
    'rackpal_app'    = 985
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
