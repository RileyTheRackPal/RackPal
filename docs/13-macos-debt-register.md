# 13 · The macOS debt register

> **What this is.** The register **§10.10 asked for and nobody created.** Its recommendation
> carried a condition — *"nothing in M0–M6 may take a Windows-only dependency without it being
> written down as a macOS debt item"* — and that sentence was restated in three documents
> (`docs/10-decisions.md:72`, `:1036`, `docs/canonical-decisions.md:5424`) without a single item
> ever being recorded anywhere. The rule was declared and never given a home.
>
> **Status of the question it served.** §10.10 is closed by **DR-009**: macOS ships in v1. This
> register is therefore no longer a deferral ledger — it is the **work list**, and its items are
> to be cleared, not merely tracked.

**Compiled 2026-07-28** against `6965508`, by direct inspection. **Revised 2026-07-29** against
`906cc27`: D7 cleared but its gate found incomplete (§3.1), D9 and the byte-exactness paragraph
**corrected** (both overstated the debt), D13 and D14 added, and §3.5 added to cost M3 against this
list. **Re-read 2026-08-01** against `6c0eda3`, after M2-F, see §2.1: every row still describes the
tree, three citations have drifted by a line or two and are corrected in place, and **§3.1's hole
grew by nine bindings**. Every claim below cites what was read. Where a number is an estimate rather
than a measurement it says so, the distinction is the point, and §10.10's own 3–5 week figure is an
estimate that has never been checked against this tree.

> **This register is live, not a dated audit.** Two of its rows were wrong within a day of being
> written, in the direction of claiming more debt than exists. A row that has stopped describing
> the tree is worse than a missing row, because it is trusted.

---

## 1. What the discipline already bought, without being asked to

The register was never kept, and the debt is **still small**. That is not luck about macOS; it is
the same insulation discipline applied for other reasons (testability, the portable build, a
layering test) landing on portability as a side effect. Recording it matters, because these are
the items a naive port estimate would double-count.

| Already paid | Evidence |
|---|---|
| **`Platform.isWindows` is used nowhere in Dart** | A repo-wide grep over `packages/*/lib` and `apps/*/lib` returns exactly one hit, and it is a comment explaining the deliberate avoidance (`apps/rackpal/lib/main.dart:132`). `storage_layering_test.dart` RULE 1 permits `dart:io` in exactly two files |
| **The platform split is an INJECTED FLAG, not a runtime check** | `isWindows` is threaded `main.dart:136` → `app_services.dart:198` → `atomic_writer.dart:213`. Its own comment already reasons about macOS: it *"decides which errno table classifies a failed save and whether MAX_PATH is enforced, so defaulting it made a disk-full save on macOS read 'something went wrong…' and refused any path over 259 characters on a filesystem whose limit is 4096 bytes"*. **Someone has already paid part of this debt and did not record it** |
| **The file picker is behind an interface** | `abstract interface class FilePicker` (`file_picker.dart:154`) with `Win32FilePicker` as one implementation (`:168`), injected as a default at `app_services.dart:199`. A macOS picker is a SECOND IMPLEMENTATION, not a refactor |
| **Fonts are bundled, not system** | `assets/fonts/Jost-Regular.ttf`, declared at `pubspec.yaml:134-139`. §10.10 lists *"font availability"* as a cost item; **it does not apply to this tree** |
| **Paths are never string-concatenated** | `path` used via an injected `p.Context`, so a `p.Style.windows` unit test runs green on a non-Windows runner (`pubspec.yaml:51`) |
| **`path_provider_windows` has exactly one call site** | `productionApplicationSupportDirectory` in `lib/src/storage/data_root.dart`, grep-enforced. The pubspec calls this *"the whole mechanism that keeps M2's portable build a one-function change rather than a five-store retrofit"*, the same property makes it a one-function macOS change |
| **No `dart:ffi` anywhere** | Grep over both `lib` trees returned nothing on 2026-07-28. **Not true since DR-153 §11.152.4:** `packages/rackpal_pdfium` is a `dart:ffi` binding by design (D9). The debt it carries is the vendored binary, not the FFI, which is platform-neutral Dart |
| **The gate scripts contain no Windows-only cmdlets** | A grep for `Get-CimInstance`, `New-SelfSignedCertificate`, `Set-AuthenticodeSignature`, `HKLM:` across `tools/ci/*.ps1` returns nothing. `pwsh` is cross-platform, so **the gate suite may already run on macOS**: see D5, which is a verification task rather than a rewrite |

---

## 2. Outstanding debt

Cost column is an **estimate**, not a measurement, unless marked otherwise.

| # | Item | Evidence | Est. |
|---|---|---|---|
| **D1** | ~~**No `macos/` platform directory.** `apps/rackpal` has `windows/` only~~ **CLEARED 2026-10-19 (#453, #454, DR-256, section 2.8)**: `apps/rackpal/macos/` is Flutter 3.47.5's template as `com.rackpal.rackpal` / `RackPal.app`, unsandboxed with the hardened runtime, and definition 2 builds it universal in 2.6 minutes. The app it builds still lacks D2's dialog and D3's data folder | `apps/rackpal/macos/`; `azure-pipelines-macos.yml` | **done** |
| **D2** | **Native file dialog.** RackPal drives `IFileDialog` itself from `windows/runner/file_dialog_channel.cpp` + `.h`, deliberately, `file_selector` was removed on purpose (`pubspec.yaml:8-20`). macOS needs an `NSOpenPanel`/`NSSavePanel` channel behind the existing `FilePicker` interface | `windows/runner/` | **largest item**: days |
| **D3** | **`path_provider_windows`** must gain a macOS answer at the one call site | `path_provider_windows` in `apps/rackpal/pubspec.yaml` (cited by name, since the line drifted from `:70` to `:89` by 2026-10-17) | hours |
| **D4** | **CI has one job, pinned to Windows.** The `windows_ci` job in `azure-pipelines.yml`, which since 2026-08-30 runs on a self-hosted Windows agent in the `Default` pool where it once named `vmImage: 'windows-2022'`. Needs a macOS job, and that job cannot use the Windows agent. Note the pipeline's own header comment already anticipates a matrix: *"that is a later question"*; **it is now this question**. **A macOS JOB EXISTS SINCE 2026-10-17 (DR-255, §2.5)**: `azure-pipelines-macos.yml`, definition 2, a Microsoft-hosted `macOS-15` image run as an optional PR check, never blocking, at a measured 27.2 minutes. What it lacks is a build: D1 and D6. **AND IT IS AN INTEL MACHINE**: build 486's forensics step printed `15.7.9 x86_64`, so nothing it proves reaches Apple Silicon (§2.6) | `azure-pipelines.yml`; `azure-pipelines-macos.yml` | **job done**; build waits on D1, D6; arm64 unmeasured |
| **D5** | **Gate scripts are PowerShell.** Six `.ps1` under `tools/ci/`. Likely runnable under `pwsh` on macOS unmodified, **verify before budgeting a rewrite**. **VERIFIED ON BUILD 481 (§2.5)**: one of the six needed changing, `ensure_flutter.ps1`, which probed `flutter.bat` and fetched the Windows archive; it now chooses by OS (`0ce061dc`). The other five ran unmodified, and `python` is supplied by a pipeline step | `tools/ci/` | **done** |
| **D6** | ~~**`verify_windows_build.ps1`** is Windows-specific by name and purpose; needs a macOS counterpart~~ **CLEARED 2026-10-19 (#463, section 2.8)**: `tools/ci/verify_macos_build.ps1` gates the bundle definition 2 builds: the executable, the exact `Contents/Frameworks` set as measured, the executable and both frameworks universal, the dylib's two slices and its signature, no JNI library, the starters packaged | `tools/ci/verify_macos_build.ps1` | **done** |
| **D7** | ~~KEYBOARD MODIFIERS~~: **CLEARED, GATE INCOMPLETE.** Was 43 hard-coded `SingleActivator` bindings assuming `Ctrl`, across six files. Now a 35-row `kKeymap` registry whose primary modifier resolves once, in `KeyBinding.activatorFor(TargetPlatform)`, through `defaultTargetPlatform`. **Zero `SingleActivator` instances remain outside the registry today**, but see §3.1 and §2.1: the ban is enforced in **one file**, and not in the package where M3 is built, and M2-F added **nine** more rows to that ungated package (35 → 44), **~~gate owed~~ PAID at #94, §2.2: `keymap_source_ban_test.dart` scans all of `rackpal_ui/lib`, comments stripped, three constructors banned, mutation-verified** | `packages/rackpal_ui/lib/src/keymap/keymap.dart` | **done** |
| **D8** | **Code signing.** DR-006 rules Windows self-signing; macOS needs **notarisation and stapling**, which D10 names and §12.9 explicitly leaves *"unaffected and still binding"* | canon `:2696`, `:5875` | days + Apple Developer enrolment lead time |
| **D9** | **pdfium is vendored per platform** (CR-100), ~~**but not yet, and not by anything shipped.** `printing`/pdfium is in **no pubspec in this tree**; PDF comes from pure-Dart `pdf ^3.13.0`. docs/03 §10.1 *plans* `printing ^5.15.0` *"behind an explicit 'Verify output' button only"* and docs/11:432 schedules vendored pdfium at **M8**.~~ **THAT WAS TRUE UNTIL DR-153 (canon §11.152, 2026-09-09) AND IS NOT NOW.** The tree vendors pdfium as `packages/rackpal_pdfium`, a pure-Dart `dart:ffi` binding that only `apps/rackpal` depends on (§11.152.4), over `third_party/pdfium/`, which holds **`win-x64/pdfium.dll` and no other platform**: `pdfium.pin.json` records one release, one archive checksum and one DLL checksum, and `pwsh -File tools/vendor_pdfium.ps1 -Verify` says whether the file is in the tree. A person places it (CR-100, §11.152.3); nothing fetches it. `printing` is still in no pubspec, but it no longer stands between the tree and a pdfium: the export preview renders the real PDF through the vendored binary (DR-230 §11.229), so D9 is no longer triggered by a future button. PDF generation itself is still the pure-Dart `pdf`, and **adding a sheet role costs zero here**. **The debt is now concrete: a macOS binary and its loader.** That is a macOS pdfium under `third_party/pdfium/` with its pin and vendoring-script entries (both record `win-x64` alone); a loader that can find it (`pdfium_library.dart` hard-codes `third_party/pdfium/win-x64/pdfium.dll` and words its load failure for Windows); and an install step in a `macos/` runner that D1 has not created, as `apps/rackpal/windows/CMakeLists.txt` does for the DLL. DR-153 deferred it on purpose: *"macOS binaries when macOS work starts"*, because an unused binary is an unverified one. **The board item that carries it is Story #61**, retitled for D9 and D15 together by BOARD-1j (#1098). D15 is the same fact (see there). **VENDORED 2026-10-18 (#468, §2.7)**: `mac-univ/libpdfium.dylib`, universal (x86_64 and arm64), from the same `chromium/8044` as Windows; the pin holds an entry per platform and the loader picks the file by OS. What remains is the install into the app bundle, which needs D1 | `packages/rackpal_pdfium/`; `third_party/pdfium/` (`README.md`, `pdfium.pin.json`); canon §11.152.3, §11.229 | **binary and loader done** (#468); the bundle install waits on D1 |
| **D10** | **`window_manager` / `screen_retriever_windows`** for geometry restore. `window_manager` is cross-platform; the pinned `screen_retriever_windows` transitive is not | `screen_retriever` and `window_manager` in `apps/rackpal/pubspec.yaml` (by name: `:98` and `:106` on 2026-08-01, `:122` and `:130` on 2026-10-17) | hours |
| **D11** | **A second print test matrix.** AC-054's greyscale laser check is a physical act on a physical printer, and no agent can perform it | §10.10 | manual |
| **D12** | **Path-length semantics.** `exceedsWindowsMaxPath` is already gated behind `isWindows` (`atomic_writer.dart:464`), so the mechanism exists; macOS needs its own answer (4096 bytes, not 259 chars) | `atomic_writer.dart` | hours |
| **D13** | ~~**The file dialog takes no file-type filter.** `COMDLG_FILTERSPEC` is hard-coded to `.rackpal` and `SetDefaultExtension(L"rackpal")` fires on **both** dialogs, inside `ConfigureDialog`, which both branches call. The Dart interface passes only `confirmButtonText`, `suggestedName`, `initialDirectory`.~~ **CLEARED at `72190b7` (M3-F/4, `#162`), CONFIRMED and WIDENED at M4-M1 (`#234`). See §2.3.** Dart sends a KIND and the runner keeps a table of them. **This row was three separate false statements about the tree for the whole of M4**, which is the failure §2's own preamble names: a stale row is trusted. The instruction that survives is the one aimed at D2: **the macOS dialog must be born taking the kind**, which is `#457` | `file_dialog_channel.cpp` `kFileKinds`; `file_picker.dart` `enum FileDialogType` | **done**, `#457` outstanding |
| **D14** | **Locale-dependent sheet size.** docs/08:509 requires *"Non-US platform locale substitutes A4/A3"*. Unimplemented, `SheetSize` has two values, neither A4. **Not macOS-specific**: a Windows machine in a metric locale hits it, which is why it went unnoticed. Recorded here because it is the one genuinely platform-dependent input to PDF geometry, and §2's closing paragraph was worrying about floats and fonts while this sat unlisted | docs/08:509; `sheet_def.dart:38-45` | hours |
| **D15** | **The PDF rasteriser for the Plan view's underlay import**, and it is the entry **DR-018 §11.17.4 predicted verbatim** before there was a ruling to hang it on: *"`docs/13` gains an entry if the chosen import path is a Windows-only rasterizer, because DR-009 puts macOS in v1."* DR-029 buys PDF import, so it does. ~~**DECIDED AT PLAN-D/1, 2026-09-07: PDFium, through a Dart wrapper (`pdfrx`/`pdfx`), NOT `Windows.Data.Pdf`.**~~ **THE ENGINE STANDS AND THE WRAPPER DID NOT SURVIVE (re-read 2026-10-17).** DR-138 §11.137.1 verified what this row left open and refused `pdfrx` twice: every route downloads pdfium at build time, which CR-100 forbids in its own words, and 2.x needed a newer Flutter than the pin. DR-145 and DR-148 deferred the rasteriser, and **DR-153 §11.152 built it as a direct `dart:ffi` binding over a vendored binary** (`packages/rackpal_pdfium`). **D9 and D15 are now the same fact**: one vendored pdfium serves the underlay import (this row) and the export preview (D9), and the macOS debt for both is a single thing, a macOS binary and the loader that finds it, carried by Story #61. `Windows.Data.Pdf` is still rejected, for the reason below. DR-037 §11.36.8 ruled this a decision needing the tree read rather than a user, and the tree says two things. **The cost is already committed**: the D9 row (above this one) is the vendoring of pdfium per platform (CR-100), first scheduled for M8's print-preview button, so choosing it here made the two ONE vendoring problem paid once and moved D9's schedule earlier rather than adding a second debt. **And `Windows.Data.Pdf` has no macOS answer at all**, so under DR-009 it guarantees a second rasteriser has to be chosen before v1 ships, which is a per-platform cost where the other is shared. **THE GRAIN THIS RUNS AGAINST IS RECORDED RATHER THAN DISCOVERED AT M8**: this project removed `file_selector` and the `path_provider` umbrella partly because they dragged an Android JNI bridge and `dartjni.dll` into a Windows Release build, and `flutter_dependency_test.dart` fails the build if that DLL returns. A multi-megabyte unsigned native binary in a self-signed portable distribution (DR-006) is the same shape of problem, and CR-100's answer is the same: **vendor the binary, never fetch it at build time**, which is exactly what docs/03 §10.1 already says disqualifies `printing`'s own CMake. ~~**TWO THINGS ARE UNVERIFIED AND ARE `PLAN-D/3`'s TO ESTABLISH BEFORE THE DEPENDENCY GOES `in use`**: the WRAPPER's licence (PDFium itself is BSD-3-Clause and clean under DR-036; the Dart package around it is a separate question), and whether its build fetches pdfium or accepts a vendored one. Until then docs/03 §10.1 carries it as `planned`.~~ **BOTH WERE ESTABLISHED, AND THE SECOND ENDED THE WRAPPER** (DR-138 §11.137.1: it fetches at build time and cannot accept a vendored binary), so no wrapper is in any pubspec. **Note what changes and what does not**: a PDF is rasterised at **import** and the member written to the zip is still PNG or JPEG, so `PlanUnderlay.format` keeps two values and `rackpal_core` needs no decoder (DR-029 §11.28.12). The debt is an import path, not a model change | canon §11.28.5, §11.36.8, §11.137, §11.152; docs/15 §2; the D9 row above | **the same days as D9, not additional to them**: it pulled the binary forward from M8. **Paid with D9 at #468 (§2.7)**, the bundle install excepted |

### 2.1 Re-read against `6c0eda3` (2026-08-01, after M2-F)

**No row was found overstating the debt this time**, which is the outcome the 2026-07-29 revision
was checking for and did not get. What did move:

| Row | Finding |
|---|---|
| **D1** | Unchanged. `ls apps/rackpal/` still shows `windows/` and no `macos/` |
| **D3** | Unchanged, citation still exact: `path_provider_windows: ^2.3.0` at `pubspec.yaml:70` |
| **D4** | Unchanged, **citation drifted**: `job: windows_ci` is `azure-pipelines.yml:181` and `vmImage: 'windows-2022'` is `:197`, not `:180`/`:196` |
| **D5** | Unchanged: still exactly six `.ps1` under `tools/ci/`, still unverified under `pwsh` on macOS |
| **D7** | ~~Still `done — gate owed`~~: **GATE PAID at board #94, 2026-08-02. See §2.2.** The paragraph below is the state that made it owed, retained as the record |
| **D9** | Unchanged and still the corrected reading, `printing`/pdfium is in no pubspec in this tree. **True on 2026-08-01 and superseded by DR-153 (2026-09-09): see D9 and §2.4** |
| **D10** | Unchanged, **citation drifted**: `screen_retriever: ^0.2.0` is `pubspec.yaml:98` and `window_manager: ^0.5.2` is `:106`; `:87` is now a comment line |
| **D14** | Unchanged. `SheetSize` still has exactly two values, `ansiBPortrait` and `ansiALandscape`, neither A4 |

**§3.1's hole grew, and M2-F is what grew it.** The register's D7 row says the ban on
`SingleActivator` outside the registry *"is enforced in one file, and not in the package where M3 is
built"*. That is still literally true, `apps/rackpal/test/session/session_layering_test.dart`'s
RULE 14 asserts `isNot(contains('SingleActivator('))` against `app_shell.dart` alone, and
`packages/rackpal_ui/test/keymap/keymap_arbitration_test.dart` arbitrates the registry's CONTENT
without ever reading `rackpal_ui/lib` for literals. Meanwhile **M2-F added nine schematic rows**
(`kKeymap` stood at 44 rows then, up from 35), every one in the ungated package.

So §3.5's warning, *"the largest remaining binding surface in v1, in the ungated package; if D7
regresses anywhere, here"*, has had one milestone slice's worth of practice run against it with
nothing watching. Nothing regressed; the register records that it was not being checked.

**The gate D7 owes is one source scan in `rackpal_ui`'s own suite**, the same shape RULE 14
already runs one package over.

### 2.2 The gate is PAID: `packages/rackpal_ui/test/keymap/keymap_source_ban_test.dart` (board #94, 2026-08-02)

**D7 moves from `done — gate owed` to `done`.** The scan walks every `.dart` under
`packages/rackpal_ui/lib`, strips comments, and fails on `SingleActivator(`, `CharacterActivator(`
or `LogicalKeySet(` anywhere outside `lib/src/keymap/`. It landed **before M3-C**, which §3.5 names
as the largest remaining binding surface, a gate added after the bindings land tells you what you
already shipped.

**Comment stripping is load-bearing, and that is measured rather than precautionary.** A naive grep
over this package fails TODAY on correct code: there are **20 mentions of the type across `lib/`
and exactly ONE constructor call**, the legitimate one in `keymap.dart`, because
`rack_canvas_screen.dart` explains the framework's exact-modifier semantics in prose and writes
`SingleActivator(keyZ, control: true)` inside a comment to do it. A fourth test asserts that trap is
still present, so tidying the stripper away fails there rather than turning the canvas into a false
positive.

**Three constructors, not one.** The board item asked for `SingleActivator(`; the property being
defended is *no binding exists that the generated table and `arbitrate()` cannot see*, and
`CharacterActivator` and the older `LogicalKeySet` have it too. Neither is used in this package, 
measured, so naming them now is free.

**Two assertions guard the gate itself**, because a source scan that looks nowhere passes silently
forever: the corpus size is asserted before the ban is (`>30` sources, canvases present), and
`keymap.dart` must still CONTAIN a `SingleActivator(`, if `activatorFor` ever stops building one,
`primary` has stopped resolving per platform and D7 has regressed in the one place the ban does not
look. **Mutation-verified**: a constructor planted in `rack_canvas_screen.dart` fails the gate with
the file named.

---

**Not yet measured, and required before this register can be called complete:** whether the four
starter projects open on macOS; whether the PDF export's **content streams** are identical across
platforms; and whether `pwsh` runs the gate suite unmodified (D5). **Two of the three are answered
since 2026-10-18**: D5 on build 481 (§2.5), and the content streams on build 486, which found the
whole FILE identical on Intel macOS and left Apple Silicon unmeasured (§2.6). Whether the starters
open waits on a build (D1).

> **Correction, 2026-07-29.** This paragraph previously read *"whether the PDF export is
> byte-identical across platforms (CR-117 is a byte gate…)"*. **That cited the wrong gate, and the
> claim under it was already false on one platform.** CR-117 (canon `:1779-1782`) is
> `write(read(bytes)) == bytes` for the **`.rackmate` JSON** — it constrains key ordering,
> timestamp precision and integer formatting, and says nothing about PDFs. And PDF **file-level**
> byte equality is impossible on the pinned library today, on Windows alone:
> `export_determinism_test.dart:6-14` records that `PdfDocument.documentID` is
> `sha256(DateTime.now() + Random.secure())` and `PdfInfo` hardcodes `/CreationDate: DateTime.now()`,
> *"Neither is injectable."* The real gate is **content-stream** equality (`:147-159`) — and that
> test compares two exports **in the same process**, so it cannot answer the cross-platform
> question at all. Answering it means a new golden-bytes comparison **plus** D4. §4's "cheap to
> answer" is true only after D1 and D4 exist.
>
> Two things reduce the worry the original sentence was expressing. Text metrics are **already
> platform-independent**: `PdfFontMeasurer` is backed by `PdfFont.stringMetrics` over the bundled
> `Jost-Regular.ttf`, imports only `dart:math`, `dart:typed_data`, `package:pdf` and
> `rackmate_core`, and is injected into **every** `DiagramCanvas` backend including the Flutter one
> (`pdf_font_measurer.dart:28-39`). No system font and no platform shaper is consulted. But
> docs/08-pdf-export.md:509 — *"Non-US platform locale substitutes A4/A3"* — **is** a genuine
> platform-dependent input to PDF geometry, it is unimplemented (`SheetSize` has two values, neither
> A4), and it is **not macOS-specific**: a Windows machine in Germany hits it. It belongs on this
> list and was missing from it.

### 2.3 D13 is CLEARED, and it had been cleared for weeks (`72190b7`, `#162`; confirmed `#234`)

**THE ROW WAS WRONG IN EVERY CLAUSE IT MADE, AND THAT IS THE FINDING.** §2's preamble rules that
*"a row that has stopped describing the tree is worse than a missing row, because it is trusted"*.
D13 is the first row to actually do it, and it was trusted: `#234`'s board text is a transcription
of it, and `#475` and `#476` were opened against it.

Measured against `file_dialog_channel.cpp` on 2026-08-29, clause by clause:

| The row said | The tree says |
|---|---|
| *"takes no file-type filter"* | `StringArg(args, "fileType")` has been read since `72190b7` |
| *"hard-coded to `.rackpal`"* | `.rackpal` has not been the project extension since DR-015 (`ffb6e72`), and the entry reads `*.rmpj;*.rackpal` |
| *"`SetDefaultExtension(L"rackpal")` fires on both dialogs"* | it fires once, on the value the chosen kind carries |
| *"The Dart interface passes only `confirmButtonText`, `suggestedName`, `initialDirectory`"* | `FileDialogType` is a fourth argument and has been since `72190b7` |

**WHAT M4-M1 ACTUALLY ADDED, stated so this closure is not read as more than it is.** The
parameterisation was M3-F/4's. `#234` added the `device` kind that `.rmdx` needs, turned two
parallel ternaries into one table so the filter and the default extension are a single row, and
added the gate that had been missing: **every `FileDialogType` value must have a row in
`kFileKinds`**. That gate is the one worth having, because the failure it catches is silent. An
unrecognised kind does not throw and does not open an empty dialog; it falls back to the project
filter, so an `Export device template…` would offer `*.rmpj` and read as a mis-wired feature
rather than an un-taught runner.

**HOW A ROW STAYS WRONG FOR WEEKS.** `72190b7`'s message says *"closing D13 before D2"* in its
subject line, so the author knew which register row they were closing and did not edit the
register. The register is not under any gate: nothing compares a row against the tree, and
`re-read a task against canon` is aimed at rulings rather than at source. **The countermeasure is
not another document.** It is that a task written from an absence gets one grep for its own nouns
in the file it names, at pickup and not only at decomposition. One `grep -n fileType` on the file
`#234` names in its own text would have found this in a second.

**`#457` (D2/3) is untouched and stays open.** There is no macOS runner, so nothing has carried the
kind across. The instruction it inherits is now sharper than the one D13 wrote: macOS implements
the same **table**, not the same argument, and `NSOpenPanel` takes the row's extension directly.

### 2.4 Re-read against the tree on 2026-10-17: D9 and D15 are one fact, and three citations drifted

**D9 and D15 were the two rows that had stopped describing the tree**, and they were wrong in
opposite directions. D9 claimed pdfium was in no pubspec and would arrive at M8 for a preview button;
D15 recorded a wrapper choice (`pdfrx`/`pdfx`) that DR-138 had already refused and DR-153 replaced.
The tree vendors pdfium as `packages/rackpal_pdfium` over `third_party/pdfium/win-x64/pdfium.dll`,
used by the underlay import and by the export preview (DR-230), and holds **no other platform's
binary**. Both rows are rewritten above, struck-through where they were wrong rather than deleted,
so the history is still readable. The macOS debt they share is a binary and a loader, and it is
carried by Story #61 (extended to D15 by BOARD-1j, #1098).

| Row | Finding |
|---|---|
| **D3** | Citation drifted: `path_provider_windows` is no longer at `pubspec.yaml:70`. Now cited by name |
| **D4** | Citation drifted and the fact moved: `windows_ci` is no longer on a hosted `windows-2022` image, it runs on a self-hosted Windows agent. A macOS job needs its own agent. Now cited by name |
| **D10** | Citation drifted: `screen_retriever` and `window_manager` moved from `:98`/`:106` to `:122`/`:130`. Now cited by name |
| **§1, `dart:ffi`** | The "already paid" row claiming no `dart:ffi` anywhere stopped being true at DR-153; corrected in place |

The remedy is the one §2.3 already names: a row cited by line number goes stale by being right once.
Name the thing, and let the reader search for it.

### 2.5 The first macOS run (build 481, 2026-10-18): D5 verified, D4 has a job, and the census was right

**DR-255 (canon §11.254) gave D4 a job**: `azure-pipelines-macos.yml`, definition 2, on a
Microsoft-hosted `macOS-15` image, run as an optional PR check because the organisation's hosted
allowance is one job of 1,800 minutes a month and a blocking check would let that allowance decide what
merges. Build 481 was its first run, on `macos-ci-459` at `ab689d82`, and it ran **before** a single
test was changed, so it measured the tree rather than a tree adjusted to pass.

**D5 is answered, and the register's guess was nearly right.** Of the six `.ps1`, **one** could not run
on macOS, and reading said so before the run: `ensure_flutter.ps1` probed `flutter.bat`, fetched the
Windows archive and extracted with `System32\tar.exe`. It now chooses each by OS (`0ce061dc`), and on
its first macOS execution it installed the pin and verified the framework revision. The other five ran
unmodified. `verify_windows_build.ps1` is not run there, since there is nothing to build (D1, D6). The
interpreter name was the only other gap, `python` against an image that promises `python3`, and one
pipeline step closes it for every script rather than a branch in each.

**Every non-suite gate is green on macOS**, the analyzer at exactly the Windows pin, which is the one
the audit flagged as plausibly platform-dependent.

**A read-only census predicted the reds before the run, case for case.** Six sub-agents read the gate
scripts and the test trees; their prediction and build 481's result:

| Suite | Predicted | Measured |
|---|---|---|
| core, text, export, ui | green, at the Windows floor | green, at the Windows floor |
| `rackpal_pdfium` | 13 of 22 fail on the pdfium load | 13 of 22 failed, one message: *"found .../win-x64/pdfium.dll but could not load it"* |
| `apps/rackpal` | 9 fail on the pdfium load, 1 test defect, 4 not registered | exactly that: 1,201 registered against 1,205 |

The one defect was in a test, not the product. `file_store_contract_test.dart` asked
`Platform.isWindows` which errno to expect from `FakeFileStore`, which has Windows semantics
everywhere; the host and the fake had always agreed, so it passed for months. The harness now takes the
store's semantics as a parameter, and a mutation that lies about them fails on Windows with the message
macOS printed.

**The 22 pdfium cases skip on macOS**, the first `skip:` in this repository, because a check that is red
for a known reason cannot show a new one. Each cites Story #61 and Chapter #468, and the macOS floors in
`tools/ci/run_suite.ps1` are lower by exactly them; #468 deletes the skips and those floor rows
together. **Windows never skips.**

**It costs 27.2 minutes, not the 22 DR-255's question assumed.** The SDK install was 1.5 minutes on a
cold cache, so caching saves little; `rackpal_ui` is 11.4 of it. On last month's 22 PR builds that is
about 600 minutes, a third of the allowance.

**And it proved something the Windows pipeline never had.** CLAUDE.md recorded that no test had ever
failed on the service, so the JUnit reporter had only been seen in the green direction. Build 481's 23
failures reached the Tests tab with their messages, and `PublishTestResults` failed the step on them.

### 2.6 The PDF is the same file on macOS (build 486, 2026-10-18), on Intel, and arm64 is not measured

§4 called one item *"genuinely unknown"*: whether the export's content streams survive a platform
change. `export_determinism_test.dart` could not say, because it compares two exports made in one
process. **`packages/rackpal_export/test/starters_pdf_golden_test.dart` can** (Story #1106): it
exports the four starters at a fixed `issuedAt` and holds each against a PDF committed from Windows
under `test/fixtures/starters/`, which is a golden as DR-253 defines one, a committed fixture
compared exactly. It asserts two layers, because they fail for different reasons: **the content**
(every indirect object with its streams inflated and its compressed `/Length` blanked) and **the
file** (byte for byte). Every stream is deflated by `dart:io`'s zlib, so the file is a property of
the SDK's zlib build as well as of the drawing, and a failure says which layer moved.

**What could vary was censused before the test was written.** The issue date is injected, and
`/CreationDate` and `/ID` are rewritten from it and from the contents (M6-I5). The starters are
`eol=lf` and the font `binary`. Nothing in the lib trees of `rackpal_export`, `rackpal_text` or
`rackpal_core` reads `Platform`, a locale, a time zone, or a `HashMap` or `HashSet`. Two inputs were
left that the tree cannot pin: **the SDK's zlib**, and **the platform libm** behind `math.sin`,
`math.cos` and `math.pow`, which the scene and `pdf` itself call before `PdfNum` rounds to five
places.

**Build 486, on `7ad7ca90`: all ten cases passed, and so did every suite.** The four starters
came out of macOS as the same files Windows wrote, byte for byte, so the content streams are
identical too, and the zlib and libm differences that could have moved them did not. No D-row is
owed for it.

**THE MACHINE WAS INTEL.** The `macOS-15` hosted image ran `15.7.9 x86_64`, so this compared two
operating systems on one CPU architecture. That is a weaker result than the question deserves:
an Apple Silicon Mac runs an arm64 Dart VM, whose zlib and libm are different builds of exactly the
two inputs the census could not pin. Whether those builds produce different output is **not read
from their sources here**; that they could is the whole reason to measure. **Whether arm64
writes the same file is unmeasured**, and the golden is already the test for it: it needs an arm64
runner and nothing else. A failure there names the object and sheet that moved, and says whether
only the encoding did, which would be the cheaper finding: the drawing would be identical and the
deliverable would differ only in how it is compressed.

### 2.7 D9 and D15 are paid for the binary and the loader (#468, 2026-10-18), and the licences were never there

**The macOS pdfium is vendored**: `third_party/pdfium/mac-univ/libpdfium.dylib`, from the same
`chromium/8044` release as Windows, placed by the integrator with `tools/vendor_pdfium.ps1 -Bootstrap`
(CR-100's human act). It is **one universal file**, an x86_64 and an arm64 slice, because a Flutter macOS
release app is itself universal and a second pinned file would need `lipo` to make an unpinned third.
`pdfium.pin.json` now holds one release and an entry per platform; the loader picks the file by OS and, on
macOS, looks for the shipped copy in the bundle's `Contents/Frameworks`. The 22 macOS skips DR-255 added
are deleted, and every suite on macOS is held to its Windows floor but the app's, which stays lower by the
four `testOn: 'windows'` cases.

**What it does not pay.** The install step that copies the dylib into the bundle needs a `macos/` runner,
and that is **D1**. And the arm64 slice is **present but never executed** by any CI here: DR-255's hosted
image is Intel (`15.7.9 x86_64`), and Azure's Apple Silicon images are a paid preview in a separate pool,
on macOS 26 and Xcode 27 only (read from Microsoft's own announcement, 2026-08-18). A test reads the dylib's
Mach-O header on every OS to prove the slice is there; an Apple Silicon Mac is the only thing that runs it.

**Two placements were refused before one was committed**, and both are worth the record:

- **The first was `chromium/8100`**, the newest release, six days old. Its archive digest matched no asset
  of 8044, and a scan of the release history found it under 8100. One release for every platform, and
  DR-248's fourteen days, each refused it alone.
- **The second stopped at the licence check**, which exposed that the check was guarding the wrong file.
  `third_party/pdfium/LICENSE` was the **packager's** MIT licence, and its last line points at `licenses/`:
  pdfium's own BSD licence and the notices for every library compiled into it. **`licenses/` had never been
  vendored, for Windows either, since 2026-09-10**, so the README's *"the licence travels with the binary"*
  was half true for five weeks. Each platform now carries `LICENSE` and `licenses/` beside its binary; for
  8044 they are the same fourteen notices, and the two `LICENSE` files differ only in line endings, which
  is all the check had seen. The same stop showed the script copied the binary before the check could
  refuse it, leaving a dylib with no pin; it now copies nothing until every check passes.

**Still owed to D9's licence half, and not here**: a shipped app has to carry those notices too, which is
release packaging (M8-B, #407, for Windows; D1 and D6 for the macOS bundle).

### 2.8 D1 and D6 are cleared (2026-10-19): the bundle builds on CI, universal, and is gated

**DR-256 (canon section 11.255) ruled the bundle's identity first**, because Flutter's template supplies three
defaults a shipped app cannot keep: `com.example`, App Sandbox on, and a bundle that reads "Quit rackpal". The
user chose `com.rackpal.rackpal` (what Windows' `Runner.rc` already implies, naming no person), no sandbox with
the hardened runtime, and `RackPal.app`. A census of the lock found **no dependency change needed**:
`window_manager` and `screen_retriever_macos` were already locked, well past DR-248's fourteen days.

**Build 497, the first macOS build, passed first try** and measured what the gate had left open:

| Measured | Value |
|---|---|
| `flutter build macos --release` | 2.6 minutes on the hosted image |
| `Contents/MacOS/RackPal` | 499,232 bytes |
| `Contents/Frameworks` | exactly `App.framework`, `FlutterMacOS.framework`, `libpdfium.dylib`: the plugins link statically through Swift Package Manager |
| `libpdfium.dylib` | x86_64 and arm64, signed on copy, `codesign --verify --strict` exit 0 |
| starters | all four packaged, CR-free |

The Frameworks list is now exact in both directions, and the executable and both frameworks must carry both slices,
because an x86_64-only app would run under Rosetta on Apple Silicon and the dylib's arm64 slice would ship and
never load. The dylib in the bundle is **not** compared with the pin: signing on copy writes into it.

**Two things found on the way.** `flutter create` on Windows writes CRLF, so the generated tree was CRLF on the
machine that made it while `.gitattributes` (now `apps/rackpal/macos/** text eol=lf`) makes every checkout LF; a
new test anchored on `
` failed on the first and would have passed on the second. And two agents reported the
tree as LF because Git Bash's `grep` and `cat` hide carriage returns here; only a byte count saw them.

**What the built app does not do yet**: open or save a file (D2, the native dialog), keep recovery, recents or
preferences (D3: `path_provider_windows` throws on its first call, and the app starts with persistence off), or
run the arm64 half anywhere but an Apple Silicon Mac, which no CI here has.

---

## 3. Why D7 is scheduled into M2 and the rest is not

**M2-F adds the connection-creation keyboard path**, and its own brief calls the keyboard clause
*"the one to design first, not last"*, because M1's equivalent clause was **REFUTED by the user
on 2026-07-27** for exactly the reason a late keyboard pass produces.

The binding count was **22 when this register was compiled**, against §10.10's **~40** estimate.
Extracting the modifier then was roughly half the edit it becomes after M2-F, and it was
independently owed: M7's exit criterion requires *"no keybinding bound twice **in the generated
table**"*, and the milestone board recorded that **nothing generates a table**.

So D7 paid three debts at once (macOS modifiers, M7's generated table, CR-101's collisions) and
got more expensive with every binding added. **Nothing else in this register has that property**,
which is why nothing else was pulled into M2.

**THE ESTIMATE WAS BEATEN BY REALITY WHILE THE REGISTER WAS BEING WRITTEN.** By the time D7 was
built, the count was **43**, not 22, M2-D and M2-E added twenty-one bindings between the
compilation of this register and the extraction. §10.10's "~40" was already exceeded. Recorded
because it is the register's own thesis demonstrated: this was the one item whose cost grew with
every commit, and it grew by ~95% in a single day of work on other tasks.

**Cleared 2026-07-28.** 43 instances across six files became a 35-row registry: the File menu's
four accelerators were a *second copy* of four bindings and now read one row, three dialogs each
declaring "Esc is Cancel, everywhere, always" became one, and `Ctrl+Z`/`Cmd+Z` plus
`Ctrl+Shift+Z`/`Cmd+Shift+Z` turned out to be **four literals where someone had already hand-rolled
D7** for undo alone. `arbitrate()` checks four conflict kinds across **every** `TargetPlatform`,
which is the only way a Windows machine sees a macOS-only collision, verified by injecting a
duplicate and watching it fail with `duplicateInScope: Ctrl+S — openDocument vs saveDocument`.

### 3.1 The gate does not reach where the next bindings will be written

**Correction, 2026-07-29.** The D7 row above previously claimed *"`session_layering_test` RULE 14
asserts `app_shell.dart` contains none"* as though that settled the enforcement question. **It is
the whole enforcement, and it covers one file.**

`session_layering_test.dart:503` reads `File('lib/src/session/app_shell.dart')`, relative to
`apps/rackpal`, and asserts `isNot(contains('SingleActivator('))`. That is the entire ban.
`packages/rackpal_ui/test/` has **no layering test at all**, and `keymap_arbitration_test.dart` is
pure in-memory: it never reads a source file, so it cannot see a binding that never reached the
table.

**Every remaining M3 UI task writes into `packages/rackpal_ui/lib`**: M3-A, M3-C, M3-E and M3-H.
A `SingleActivator(LogicalKeyboardKey.keyT, control: true)` in the new Structure editor compiles,
ships, hard-codes `Ctrl` on macOS, and is invisible to `arbitrate()` and to M7's generated table.
**Nothing fails.**

That is the same shape as the defect D7 existed to remove, and §3's own thesis, that the count
grew ~95% in one day of work on other tasks, is the reason to expect it to recur. M3-C is the
largest binding surface left in v1.

**The gate is owed in `packages/rackpal_ui/test/`, and it must ban the CONSTRUCTION rather than
name a file**: a per-file ban is exactly what left this hole.

---

## 3.5 What M3 costs this register

Checked 2026-07-29, task by task, against the roadmap and the tree. **No M3 task is blocked by any
item here.** M3's only hard block is M2 (docs/12:697). Every debt item M3 comes near sits behind a
seam that already has a working Windows implementation M3 extends rather than waits on, which is
§1's thesis holding up a second time.

| M3 task | Effect | Detail |
|---|---|---|
| **M3-A** Outlet / structureOrigin / endpoint kinds in UI | **touches D7** | New bindings must be `kKeymap` rows; §3.1's hole is the exposure |
| **M3-B** Locations panel (CR-112) | none | Pure model + Flutter UI |
| **M3-C** Structure editor | **touches D7** | The **largest remaining binding surface in v1**, in the ungated package. If D7 regresses anywhere, here. **M3-C/2 landed 2026-08-08 and added two rows**, `Ctrl+D` and `Ctrl+V` in a new `KeyScope.structure`, both through `kKeymap` with the gate watching. The forecast said largest; the outcome was two, because every editable cell is a real focusable control and tab order is therefore the framework's, not a binding |
| **M3-D** dual labels, lengths, footage rollup | none | Grows neither D9 (see the D9 row) nor the cross-platform question (see §2's correction). It **did** straddle M6, the Pull Sheet role being assigned to M6 by `sheet_def.dart:15-20` while M3's exit criterion demanded exporting it. **DR-027 §11.26.2 settled that seam on 2026-08-09**: M3 owes the rows, the sort and the per-room subtotals as tested `rackpal_core` output, M6 owes the `SheetRole`, the layout, the initial boxes and the page. Demonstrated at M3-D/4 (`pull_sheet_clause_test.dart`), which asserts M3's half and asserts that no Pull Sheet role exists to claim M6's. Not macOS debt; recorded so M3-D is not scoped from its one-line description |
| **M3-E** Pathway, multiple Structure instances | none | |
| **M3-F** CSV import | **GROWS D2: the only growth in M3** | `pickOpen` already exists (`file_picker.dart:156`), so nothing is blocked. What is missing is a **file-type filter** anywhere in the stack, see **D13**. Hours on top of D2's days, once, and then it is done. **Not the D7 case**, which grew ~95% in a day because every commit added bindings |
| **M3-G** 60-drop drill (AC-018) | none | **Specifically NOT D11.** D11 is a physical greyscale laser print for AC-054, an **M6** clause. M3-G's artifact is an exported file; AC-018's *"prints"* means "appears on the sheet" (canon `:2161`). Treating them as one would wrongly hang a printer-procurement dependency on M3 |
| **M3-H** LV box / keystone plate (DR-007) | **touches D7** | Same ungated package |

**Nothing in M3 adds a new `dart:io`, `path`, or platform-channel dependency.** CSV bytes are
reachable through the existing `FileStore.readBytes` (`file_store.dart:164`), which satisfies
storage RULE 1/1b and session RULE 10 unchanged. **The only native-surface change M3 asks for is
D13's filter argument on the existing `rackpal/file_dialog` channel: no new channel.**

---

## 3.6 What M4 costs this register: one shadowed framework binding

Checked 2026-08-19 at M4-F's pick-up, over the five chords `docs/06` §4.6 binds for the grid
operations. **No M4 task is blocked by any item here**, and the register grows by exactly one row,
which is a behaviour v1 deliberately takes away from macOS rather than a port that is owed.

| M4 chord | macOS | Detail |
|---|---|---|
| `Ctrl+J` `Duplicate` | clean | In no platform map of `default_text_editing_shortcuts.dart` |
| `Ctrl+R` `Renumber…` | clean | As above |
| `Ctrl+H` `Find & replace` | clean | As above |
| **`Ctrl+T` `Change type…`** | **SHADOWS `TransposeCharactersIntent`** | See below |
| `Ctrl+M` `Move to bank…` | clean | As above |

**`Ctrl+T` is `TransposeCharactersIntent` in `_macShortcuts`**, one of the emacs-derived bindings
Flutter installs in every text field, and focus is almost always inside a cell `TextField` when a
grid chord is pressed. `docs/04` §8 records that Flutter dispatches key events **leaf to root**
while `DefaultTextEditingShortcuts` sits at the app root, so **the collision runs our way**: on
macOS, inside a builder cell, `Ctrl+T` opens `Change type…` and does not transpose two characters.

**Ruled deliberately as DR-078 §11.77.1** rather than absorbed: `docs/06` §4.6 specifies the chord,
and DR-011.6 requires one chord to wear one meaning across the product, which a per-platform split
would break on an axis a keyboard-only user can see even less than a scope boundary.

**WHAT IS OWED HERE IS AN OBSERVATION, NOT A PORT.** Nothing needs writing for macOS to work; what
is owed is that the first macOS user who reaches for transpose in a builder cell finds this row
instead of a mystery. If it turns out to matter to a real person, the fix is an amendment to §4.6's
table and not a platform branch.

**The check was run over the framework's own source, not recalled.** That is how the one collision
was found among five, and it is the method the next binding pass should copy: `Ctrl+D`'s keymap note
had already established the check, and this is the first time it came back positive.

---

## 4. Honest summary

The debt is **smaller than §10.10 feared**, and the reason is recorded above: the seams macOS needs
were built for other purposes and are already in place. The two items with real lead time are
**D8** (Apple Developer enrolment, notarisation) and **D11** (a physical print test); neither is
code, and both should be started early precisely because they are not.

**What was genuinely unknown** is whether the PDF's **content streams** survive a platform change,
the one item that could have turned a bounded port into a design question. ~~Answering it means
writing a golden-bytes comparison **and** having D4's macOS job to run it on.~~ **BOTH EXIST, AND
THE ANSWER IS YES ON INTEL (§2.6).** `starters_pdf_golden_test.dart` holds the four starters against
PDFs committed from Windows, and on build 486 macOS wrote the same four files byte for byte, so the
content streams are identical and so is everything around them. **What stays unknown is narrower:
Apple Silicon.** The hosted image is `x86_64`, and an arm64 Dart VM carries its own builds of zlib
and libm, the two inputs the tree cannot pin. The golden already answers it the day it runs on an arm64
machine. It is still **not** a CR-117 question (that gate is the `.rppj` JSON). The text pipeline is
platform-independent by construction; the concrete risk that remains is **D14**, and that one is
not even macOS-specific.

**Two ordering consequences worth acting on before the big items.** ~~**D13 before D2**: widening
the dialog contract after the macOS implementation exists means writing it twice.~~ **BOUGHT, and
earlier than this paragraph knew** (§2.3): `72190b7` made the filter a kind before any macOS runner
existed, and `#234` made the kinds a table. What D2 inherits is a shape rather than a warning, and
`#457` is where it gets carried across. And **the §3.1 gate before M3-C**, which is the largest
remaining binding surface in v1 and lands in the package the gate does not cover.
