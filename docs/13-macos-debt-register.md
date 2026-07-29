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

**Compiled 2026-07-28** against `0f83628`, by direct inspection. Every claim below cites what was
read. Where a number is an estimate rather than a measurement it says so — the distinction is the
point, and §10.10's own 3–5 week figure is an estimate that has never been checked against this
tree.

---

## 1. What the discipline already bought, without being asked to

The register was never kept, and the debt is **still small**. That is not luck about macOS; it is
the same insulation discipline applied for other reasons — testability, the portable build, a
layering test — landing on portability as a side effect. Recording it matters, because these are
the items a naive port estimate would double-count.

| Already paid | Evidence |
|---|---|
| **`Platform.isWindows` is used nowhere in Dart** | A repo-wide grep over `packages/*/lib` and `apps/*/lib` returns exactly one hit, and it is a comment explaining the deliberate avoidance (`apps/rackmate/lib/main.dart:132`). `storage_layering_test.dart` RULE 1 permits `dart:io` in exactly two files |
| **The platform split is an INJECTED FLAG, not a runtime check** | `isWindows` is threaded `main.dart:136` → `app_services.dart:198` → `atomic_writer.dart:213`. Its own comment already reasons about macOS: it *"decides which errno table classifies a failed save and whether MAX_PATH is enforced, so defaulting it made a disk-full save on macOS read 'something went wrong…' and refused any path over 259 characters on a filesystem whose limit is 4096 bytes"*. **Someone has already paid part of this debt and did not record it** |
| **The file picker is behind an interface** | `abstract interface class FilePicker` (`file_picker.dart:154`) with `Win32FilePicker` as one implementation (`:168`), injected as a default at `app_services.dart:199`. A macOS picker is a SECOND IMPLEMENTATION, not a refactor |
| **Fonts are bundled, not system** | `assets/fonts/Jost-Regular.ttf`, declared at `pubspec.yaml:134-139`. §10.10 lists *"font availability"* as a cost item; **it does not apply to this tree** |
| **Paths are never string-concatenated** | `path` used via an injected `p.Context`, so a `p.Style.windows` unit test runs green on a non-Windows runner (`pubspec.yaml:51`) |
| **`path_provider_windows` has exactly one call site** | `productionApplicationSupportDirectory` in `lib/src/storage/data_root.dart`, grep-enforced. The pubspec calls this *"the whole mechanism that keeps M2's portable build a one-function change rather than a five-store retrofit"* — the same property makes it a one-function macOS change |
| **No `dart:ffi` anywhere** | Grep over both `lib` trees returns nothing |
| **The gate scripts contain no Windows-only cmdlets** | A grep for `Get-CimInstance`, `New-SelfSignedCertificate`, `Set-AuthenticodeSignature`, `HKLM:` across `tools/ci/*.ps1` returns nothing. `pwsh` is cross-platform, so **the gate suite may already run on macOS** — see D5, which is a verification task rather than a rewrite |

---

## 2. Outstanding debt

Cost column is an **estimate**, not a measurement, unless marked otherwise.

| # | Item | Evidence | Est. |
|---|---|---|---|
| **D1** | **No `macos/` platform directory.** `apps/rackmate` has `windows/` only | `ls apps/rackmate/` | hours |
| **D2** | **Native file dialog.** RackMate drives `IFileDialog` itself from `windows/runner/file_dialog_channel.cpp` + `.h` — deliberately, `file_selector` was removed on purpose (`pubspec.yaml:8-20`). macOS needs an `NSOpenPanel`/`NSSavePanel` channel behind the existing `FilePicker` interface | `windows/runner/` | **largest item** — days |
| **D3** | **`path_provider_windows`** must gain a macOS answer at the one call site | `pubspec.yaml:70` | hours |
| **D4** | **CI has one job, pinned to Windows.** `azure-pipelines.yml:180` `job: windows_ci`, `:196` `vmImage: 'windows-2022'`. Needs a macOS job. Note the pipeline's own comment at `:106` already anticipates a matrix: *"that is a later question"* — **it is now this question** | `azure-pipelines.yml` | days |
| **D5** | **Gate scripts are PowerShell.** Six `.ps1` under `tools/ci/`. Likely runnable under `pwsh` on macOS unmodified — **verify before budgeting a rewrite** | `tools/ci/` | verify first |
| **D6** | **`verify_windows_build.ps1`** is Windows-specific by name and purpose; needs a macOS counterpart | `tools/ci/` | hours |
| **D7** | ~~KEYBOARD MODIFIERS~~ — **CLEARED.** Was 43 hard-coded `SingleActivator` bindings assuming `Ctrl`, across six files. Now a 35-row `kKeymap` registry whose primary modifier resolves once, in `KeyBinding.activatorFor(TargetPlatform)`, through `defaultTargetPlatform`. **Zero `SingleActivator` instances remain outside the registry**, and `session_layering_test` RULE 14 asserts `app_shell.dart` contains none — a hand-rolled binding would be invisible to the table and would re-hardcode `Ctrl`. See §3 | `packages/rackmate_ui/lib/src/keymap/keymap.dart` | **done** |
| **D8** | **Code signing.** DR-006 rules Windows self-signing; macOS needs **notarisation and stapling**, which D10 names and §12.9 explicitly leaves *"unaffected and still binding"* | canon `:2696`, `:5875` | days + Apple Developer enrolment lead time |
| **D9** | **pdfium is vendored per platform** (CR-100). A macOS binary must be vendored and verified | canon `:1517` | days |
| **D10** | **`window_manager` / `screen_retriever_windows`** for geometry restore. `window_manager` is cross-platform; the pinned `screen_retriever_windows` transitive is not | `pubspec.yaml:87` | hours |
| **D11** | **A second print test matrix.** AC-054's greyscale laser check is a physical act on a physical printer, and no agent can perform it | §10.10 | manual |
| **D12** | **Path-length semantics.** `exceedsWindowsMaxPath` is already gated behind `isWindows` (`atomic_writer.dart:464`), so the mechanism exists; macOS needs its own answer (4096 bytes, not 259 chars) | `atomic_writer.dart` | hours |

**Not yet measured, and required before this register can be called complete:** whether the four
starter projects open on macOS; whether the PDF export is byte-identical across platforms (CR-117
is a byte gate, and a platform-dependent float or font metric would surface here first); and
whether `pwsh` runs the gate suite unmodified (D5).

---

## 3. Why D7 is scheduled into M2 and the rest is not

**M2-F adds the connection-creation keyboard path**, and its own brief calls the keyboard clause
*"the one to design first, not last"* — because M1's equivalent clause was **REFUTED by the user
on 2026-07-27** for exactly the reason a late keyboard pass produces.

The binding count was **22 when this register was compiled**, against §10.10's **~40** estimate.
Extracting the modifier then was roughly half the edit it becomes after M2-F, and it was
independently owed: M7's exit criterion requires *"no keybinding bound twice **in the generated
table**"*, and the milestone board recorded that **nothing generates a table**.

So D7 paid three debts at once — macOS modifiers, M7's generated table, CR-101's collisions — and
got more expensive with every binding added. **Nothing else in this register has that property**,
which is why nothing else was pulled into M2.

**THE ESTIMATE WAS BEATEN BY REALITY WHILE THE REGISTER WAS BEING WRITTEN.** By the time D7 was
built, the count was **43**, not 22 — M2-D and M2-E added twenty-one bindings between the
compilation of this register and the extraction. §10.10's "~40" was already exceeded. Recorded
because it is the register's own thesis demonstrated: this was the one item whose cost grew with
every commit, and it grew by ~95% in a single day of work on other tasks.

**Cleared 2026-07-28.** 43 instances across six files became a 35-row registry: the File menu's
four accelerators were a *second copy* of four bindings and now read one row, three dialogs each
declaring "Esc is Cancel, everywhere, always" became one, and `Ctrl+Z`/`Cmd+Z` plus
`Ctrl+Shift+Z`/`Cmd+Shift+Z` turned out to be **four literals where someone had already hand-rolled
D7** for undo alone. `arbitrate()` checks four conflict kinds across **every** `TargetPlatform`,
which is the only way a Windows machine sees a macOS-only collision — verified by injecting a
duplicate and watching it fail with `duplicateInScope: Ctrl+S — openDocument vs saveDocument`.

---

## 4. Honest summary

The debt is **smaller than §10.10 feared**, and the reason is recorded above: the seams macOS needs
were built for other purposes and are already in place. The two items with real lead time are
**D8** (Apple Developer enrolment, notarisation) and **D11** (a physical print test) — neither is
code, and both should be started early precisely because they are not.

**What is genuinely unknown** is whether the byte-exactness gate survives a platform change. That
is the one item that could turn a bounded port into a design question, and it is cheap to answer:
run the export suite on a macOS agent once D1 and D4 exist.
