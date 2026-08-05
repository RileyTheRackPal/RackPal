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

**Compiled 2026-07-28** against `0f83628`, by direct inspection. **Revised 2026-07-29** against
`b36c04c`: D7 cleared but its gate found incomplete (§3.1), D9 and the byte-exactness paragraph
**corrected** (both overstated the debt), D13 and D14 added, and §3.5 added to cost M3 against this
list. **Re-read 2026-08-01** against `91cd487`, after M2-F, see §2.1: every row still describes the
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
| **`Platform.isWindows` is used nowhere in Dart** | A repo-wide grep over `packages/*/lib` and `apps/*/lib` returns exactly one hit, and it is a comment explaining the deliberate avoidance (`apps/rackmate/lib/main.dart:132`). `storage_layering_test.dart` RULE 1 permits `dart:io` in exactly two files |
| **The platform split is an INJECTED FLAG, not a runtime check** | `isWindows` is threaded `main.dart:136` → `app_services.dart:198` → `atomic_writer.dart:213`. Its own comment already reasons about macOS: it *"decides which errno table classifies a failed save and whether MAX_PATH is enforced, so defaulting it made a disk-full save on macOS read 'something went wrong…' and refused any path over 259 characters on a filesystem whose limit is 4096 bytes"*. **Someone has already paid part of this debt and did not record it** |
| **The file picker is behind an interface** | `abstract interface class FilePicker` (`file_picker.dart:154`) with `Win32FilePicker` as one implementation (`:168`), injected as a default at `app_services.dart:199`. A macOS picker is a SECOND IMPLEMENTATION, not a refactor |
| **Fonts are bundled, not system** | `assets/fonts/Jost-Regular.ttf`, declared at `pubspec.yaml:134-139`. §10.10 lists *"font availability"* as a cost item; **it does not apply to this tree** |
| **Paths are never string-concatenated** | `path` used via an injected `p.Context`, so a `p.Style.windows` unit test runs green on a non-Windows runner (`pubspec.yaml:51`) |
| **`path_provider_windows` has exactly one call site** | `productionApplicationSupportDirectory` in `lib/src/storage/data_root.dart`, grep-enforced. The pubspec calls this *"the whole mechanism that keeps M2's portable build a one-function change rather than a five-store retrofit"*, the same property makes it a one-function macOS change |
| **No `dart:ffi` anywhere** | Grep over both `lib` trees returns nothing |
| **The gate scripts contain no Windows-only cmdlets** | A grep for `Get-CimInstance`, `New-SelfSignedCertificate`, `Set-AuthenticodeSignature`, `HKLM:` across `tools/ci/*.ps1` returns nothing. `pwsh` is cross-platform, so **the gate suite may already run on macOS**: see D5, which is a verification task rather than a rewrite |

---

## 2. Outstanding debt

Cost column is an **estimate**, not a measurement, unless marked otherwise.

| # | Item | Evidence | Est. |
|---|---|---|---|
| **D1** | **No `macos/` platform directory.** `apps/rackmate` has `windows/` only | `ls apps/rackmate/` | hours |
| **D2** | **Native file dialog.** RackMate drives `IFileDialog` itself from `windows/runner/file_dialog_channel.cpp` + `.h`, deliberately, `file_selector` was removed on purpose (`pubspec.yaml:8-20`). macOS needs an `NSOpenPanel`/`NSSavePanel` channel behind the existing `FilePicker` interface | `windows/runner/` | **largest item**: days |
| **D3** | **`path_provider_windows`** must gain a macOS answer at the one call site | `pubspec.yaml:70` | hours |
| **D4** | **CI has one job, pinned to Windows.** `azure-pipelines.yml:181` `job: windows_ci`, `:197` `vmImage: 'windows-2022'`. Needs a macOS job. Note the pipeline's own comment at `:106` already anticipates a matrix: *"that is a later question"*; **it is now this question** | `azure-pipelines.yml` | days |
| **D5** | **Gate scripts are PowerShell.** Six `.ps1` under `tools/ci/`. Likely runnable under `pwsh` on macOS unmodified, **verify before budgeting a rewrite** | `tools/ci/` | verify first |
| **D6** | **`verify_windows_build.ps1`** is Windows-specific by name and purpose; needs a macOS counterpart | `tools/ci/` | hours |
| **D7** | ~~KEYBOARD MODIFIERS~~: **CLEARED, GATE INCOMPLETE.** Was 43 hard-coded `SingleActivator` bindings assuming `Ctrl`, across six files. Now a 35-row `kKeymap` registry whose primary modifier resolves once, in `KeyBinding.activatorFor(TargetPlatform)`, through `defaultTargetPlatform`. **Zero `SingleActivator` instances remain outside the registry today**, but see §3.1 and §2.1: the ban is enforced in **one file**, and not in the package where M3 is built, and M2-F added **nine** more rows to that ungated package (35 → 44), **~~gate owed~~ PAID at #94, §2.2: `keymap_source_ban_test.dart` scans all of `rackmate_ui/lib`, comments stripped, three constructors banned, mutation-verified** | `packages/rackmate_ui/lib/src/keymap/keymap.dart` | **done** |
| **D8** | **Code signing.** DR-006 rules Windows self-signing; macOS needs **notarisation and stapling**, which D10 names and §12.9 explicitly leaves *"unaffected and still binding"* | canon `:2696`, `:5875` | days + Apple Developer enrolment lead time |
| **D9** | **pdfium is vendored per platform** (CR-100), **but not yet, and not by anything shipped.** `printing`/pdfium is in **no pubspec in this tree**; PDF comes from pure-Dart `pdf ^3.13.0`. docs/03 §10.1 *plans* `printing ^5.15.0` *"behind an explicit 'Verify output' button only"* and docs/11:432 schedules vendored pdfium at **M8**. So D9 is triggered by the preview button, not by adding sheets: **adding a sheet role costs zero here** | canon `:1517`; every `pubspec.yaml`; docs/11:432 | days, **at M8** |
| **D10** | **`window_manager` / `screen_retriever_windows`** for geometry restore. `window_manager` is cross-platform; the pinned `screen_retriever_windows` transitive is not | `pubspec.yaml:98`, `:106` | hours |
| **D11** | **A second print test matrix.** AC-054's greyscale laser check is a physical act on a physical printer, and no agent can perform it | §10.10 | manual |
| **D12** | **Path-length semantics.** `exceedsWindowsMaxPath` is already gated behind `isWindows` (`atomic_writer.dart:464`), so the mechanism exists; macOS needs its own answer (4096 bytes, not 259 chars) | `atomic_writer.dart` | hours |
| **D13** | **The file dialog takes no file-type filter.** `COMDLG_FILTERSPEC` is hard-coded to `.rackmate` and `SetDefaultExtension(L"rackmate")` fires on **both** dialogs, inside `ConfigureDialog`, which both branches call. The Dart interface passes only `confirmButtonText`, `suggestedName`, `initialDirectory`. **Add the filter argument BEFORE D2**, or D2 reimplements the narrow contract and then widens twice. **M3-F (CSV import) is what forces it**: see §5 | `file_dialog_channel.cpp:107-123, :216-218`; `file_picker.dart:156, :164` | hours, but **before D2** |
| **D14** | **Locale-dependent sheet size.** docs/08:509 requires *"Non-US platform locale substitutes A4/A3"*. Unimplemented, `SheetSize` has two values, neither A4. **Not macOS-specific**: a Windows machine in a metric locale hits it, which is why it went unnoticed. Recorded here because it is the one genuinely platform-dependent input to PDF geometry, and §2's closing paragraph was worrying about floats and fonts while this sat unlisted | docs/08:509; `sheet_def.dart:38-45` | hours |

### 2.1 Re-read against `91cd487` (2026-08-01, after M2-F)

**No row was found overstating the debt this time**, which is the outcome the 2026-07-29 revision
was checking for and did not get. What did move:

| Row | Finding |
|---|---|
| **D1** | Unchanged. `ls apps/rackmate/` still shows `windows/` and no `macos/` |
| **D3** | Unchanged, citation still exact: `path_provider_windows: ^2.3.0` at `pubspec.yaml:70` |
| **D4** | Unchanged, **citation drifted**: `job: windows_ci` is `azure-pipelines.yml:181` and `vmImage: 'windows-2022'` is `:197`, not `:180`/`:196` |
| **D5** | Unchanged: still exactly six `.ps1` under `tools/ci/`, still unverified under `pwsh` on macOS |
| **D7** | ~~Still `done — gate owed`~~: **GATE PAID at board #94, 2026-08-02. See §2.2.** The paragraph below is the state that made it owed, retained as the record |
| **D9** | Unchanged and still the corrected reading, `printing`/pdfium is in no pubspec in this tree |
| **D10** | Unchanged, **citation drifted**: `screen_retriever: ^0.2.0` is `pubspec.yaml:98` and `window_manager: ^0.5.2` is `:106`; `:87` is now a comment line |
| **D14** | Unchanged. `SheetSize` still has exactly two values, `ansiBPortrait` and `ansiALandscape`, neither A4 |

**§3.1's hole grew, and M2-F is what grew it.** The register's D7 row says the ban on
`SingleActivator` outside the registry *"is enforced in one file, and not in the package where M3 is
built"*. That is still literally true, `apps/rackmate/test/session/session_layering_test.dart`'s
RULE 14 asserts `isNot(contains('SingleActivator('))` against `app_shell.dart` alone, and
`packages/rackmate_ui/test/keymap/keymap_arbitration_test.dart` arbitrates the registry's CONTENT
without ever reading `rackmate_ui/lib` for literals. Meanwhile **M2-F added nine schematic rows**
(`kKeymap` is 44 rows now, was 35), every one of them in the ungated package.

So §3.5's warning, *"the largest remaining binding surface in v1, in the ungated package; if D7
regresses anywhere, here"*, has had one milestone slice's worth of practice run against it with
nothing watching. Nothing regressed; the register records that it was not being checked.

**The gate D7 owes is one source scan in `rackmate_ui`'s own suite**, the same shape RULE 14
already runs one package over.

### 2.2 The gate is PAID: `packages/rackmate_ui/test/keymap/keymap_source_ban_test.dart` (board #94, 2026-08-02)

**D7 moves from `done — gate owed` to `done`.** The scan walks every `.dart` under
`packages/rackmate_ui/lib`, strips comments, and fails on `SingleActivator(`, `CharacterActivator(`
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
platforms; and whether `pwsh` runs the gate suite unmodified (D5).

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
`apps/rackmate`, and asserts `isNot(contains('SingleActivator('))`. That is the entire ban.
`packages/rackmate_ui/test/` has **no layering test at all**, and `keymap_arbitration_test.dart` is
pure in-memory: it never reads a source file, so it cannot see a binding that never reached the
table.

**Every remaining M3 UI task writes into `packages/rackmate_ui/lib`**: M3-A, M3-C, M3-E and M3-H.
A `SingleActivator(LogicalKeyboardKey.keyT, control: true)` in the new Structure editor compiles,
ships, hard-codes `Ctrl` on macOS, and is invisible to `arbitrate()` and to M7's generated table.
**Nothing fails.**

That is the same shape as the defect D7 existed to remove, and §3's own thesis, that the count
grew ~95% in one day of work on other tasks, is the reason to expect it to recur. M3-C is the
largest binding surface left in v1.

**The gate is owed in `packages/rackmate_ui/test/`, and it must ban the CONSTRUCTION rather than
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
| **M3-C** Structure editor | **touches D7** | The **largest remaining binding surface in v1**, in the ungated package. If D7 regresses anywhere, here |
| **M3-D** dual labels, lengths, footage rollup | none | Grows neither D9 (see the D9 row) nor the cross-platform question (see §2's correction). It **does** straddle M6, the Pull Sheet role is assigned to M6 by `sheet_def.dart:15-20` while M3's exit criterion demands exporting it. Not macOS debt; recorded so M3-D is not scoped from its one-line description |
| **M3-E** Pathway, multiple Structure instances | none | |
| **M3-F** CSV import | **GROWS D2: the only growth in M3** | `pickOpen` already exists (`file_picker.dart:156`), so nothing is blocked. What is missing is a **file-type filter** anywhere in the stack, see **D13**. Hours on top of D2's days, once, and then it is done. **Not the D7 case**, which grew ~95% in a day because every commit added bindings |
| **M3-G** 60-drop drill (AC-018) | none | **Specifically NOT D11.** D11 is a physical greyscale laser print for AC-054, an **M6** clause. M3-G's artifact is an exported file; AC-018's *"prints"* means "appears on the sheet" (canon `:2161`). Treating them as one would wrongly hang a printer-procurement dependency on M3 |
| **M3-H** LV box / keystone plate (DR-007) | **touches D7** | Same ungated package |

**Nothing in M3 adds a new `dart:io`, `path`, or platform-channel dependency.** CSV bytes are
reachable through the existing `FileStore.readBytes` (`file_store.dart:164`), which satisfies
storage RULE 1/1b and session RULE 10 unchanged. **The only native-surface change M3 asks for is
D13's filter argument on the existing `rackmate/file_dialog` channel: no new channel.**

---

## 4. Honest summary

The debt is **smaller than §10.10 feared**, and the reason is recorded above: the seams macOS needs
were built for other purposes and are already in place. The two items with real lead time are
**D8** (Apple Developer enrolment, notarisation) and **D11** (a physical print test); neither is
code, and both should be started early precisely because they are not.

**What is genuinely unknown** is whether the PDF's **content streams** survive a platform change.
That is the one item that could turn a bounded port into a design question, but §2's correction
narrows it twice. It is **not** a CR-117 question (that gate is the `.rackmate` JSON), and it is
**not cheap to answer**: the existing determinism test compares two exports in one process, so
answering it means writing a golden-bytes comparison **and** having D4's macOS job to run it on.
The text pipeline is already platform-independent by construction; the concrete risk that remains
is **D14**, and that one is not even macOS-specific.

**Two ordering consequences worth acting on before the big items.** **D13 before D2**: widening
the dialog contract after the macOS implementation exists means writing it twice. And **the §3.1
gate before M3-C**, which is the largest remaining binding surface in v1 and lands in the package
the gate does not cover.
