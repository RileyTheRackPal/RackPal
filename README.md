# RackPal

> **This is an alpha.** Version 0.6.x, pre-1.0, Windows only, and published to collect feedback from
> people who design, build and document A/V racks. Expect gaps (the [user guide's §21.8](docs/21-user-guide.md)
> lists the ones we know) and expect file formats to keep migrating forward.
>
> - **Try it:** download the Windows preview from [Releases](https://github.com/RileyTheRackPal/RackPal/releases),
>   unzip it anywhere and run `rackpal.exe`, or [build it from source](#building-from-source).
> - **Tell us:** [open an issue](https://github.com/RileyTheRackPal/RackPal/issues/new/choose). Workflow
>   feedback ("this is not how I do it") is as welcome as bug reports. Pull requests are not accepted
>   during the alpha; [CONTRIBUTING](CONTRIBUTING.md) says why.

RackPal is a desktop application for designing A/V equipment racks for custom-integration work, **residential-CI-first, commercial-capable** (DR-002): you enter a rack height in rack units, populate the rack from a seeded catalog of generic archetypes, wire the gear together on a schematic canvas, and export a PDF sheet set containing both the drawing and the cable schedule. The repository holds the specification (the canonical decision record, the documents derived from it, and the working papers they were adjudicated from) **and a Flutter application that builds and runs on Windows**.

## Status: IN BUILD

| | |
|---|---|
| Phase | [docs/12 §1](docs/12-milestone-board.md#1-the-board-at-a-glance) is the one place that says which milestones have met their exit criteria, which is open now, and what is not started. This page does not restate it, because a status written here went stale at M3 |
| Platform | Windows. macOS ships in v1 (DR-009): it builds on CI but cannot yet open or save a file, so it is not usable; the remaining debt is enumerated in [docs/13](docs/13-macos-debt-register.md) |
| Tests and gates | Counted by the code, not by this page. The gates are the `Invoke-Gate` calls in `tools/ci/run_local.ps1`, the suite floors are in `tools/ci/run_suite.ps1`, and the analyzer ratchet is pinned in `tools/ci/analyze_info_baseline.txt` |
| Next step | The open milestone on the board above; the plan it belongs to is the [Roadmap](docs/09-roadmap.md) |
| Cost to v1 | Stated as relative sizes, not weeks (DR-182 §11.181.2): [docs/09 §6](docs/09-roadmap.md#6-what-this-costs-in-sizes) carries the sizes and what the closed milestones actually took |

**The status above is a pointer, not the evidence.** [docs/12, the milestone board](docs/12-milestone-board.md) is the audit: it marks every exit clause of every milestone with what was *run* rather than what is believed, cites the file or test that would have to be wrong for the mark to be wrong, and records where those citations have gone stale. Read it before trusting any claim on this page.

No week total is given here on purpose. A detailed design with no cost attached stalls, and one with a *wrong* cost attached stalls while also destroying trust in the plan (AC-017); the week total this page used to carry was written before any of it was built, and the milestones that have closed came in several times under it.

## Features

The seven core requirements of the brief, and what v1 does about each. All seven ship in v1, the scope ruling's first filter is "does one of the seven requirements fail without it?", and anything that fails it is in regardless of cost (per §7.0).

| # | Requirement | v1 |
|---|---|---|
| 1 | Rack height in RU | Racks of 1–60 RU, 1-based bottom-origin `ruIndex`, per-rack numbering direction and rear-elevation mirroring (CR-038, CR-025, CR-026) |
| 2 | GUI device builder with I/O | Three required fields (name, RU height, designator prefix) then the port grid, with fill-down, TSV paste, archetype generators and a pattern DSL (AC-049) |
| 3 | Physical connections | Drag-to-connect on the Schematic with magnetic type-weighted snap, chain-draw and multi-draw; a `Link` is one physical cable carrying a list of `Service`s over `Conductor`s (CR-008, CR-010) |
| 4 | Colour-coding by cable type | Hue = signal domain, dash + weight + tag = type; eight domains, per-family colour override, legend printed in colour and greyscale side by side (CR-078, AC-054) |
| 5 | Schematic idiom | Net labels by default, drawn wires on domain filter, hover or focus (DR-001); Sugiyama phases 0–3 place the symbols and a deterministic layer-ordered orthogonal trace draws the wires; no route geometry is persisted, only symbol placement (DR-001, CR-013, CR-012) |
| 6 | Structure device | A `DeviceInstance` with `kind == structure` rendering as an edge bank of off-page flags; `Outlet` is the creation atom, a home run is a `Link` carrying a `StructureOrigin` (CR-016, AC-019) |
| 7 | PDF with diagram **and** schedule | Cover and drawing index, legend, exceptions page, front and rear elevations, **N interconnect sheets: one per domain partition of the single schematic `Sheet`**, Pull Sheet, Termination Schedule, Unused Home Runs, Equipment List and Materials, and plate/panel/pinout details where a non-standard pinout exists (AC-025, AC-055, CR-073, DR-005) |

Beyond the seven: a live [Schedule](docs/05-schematic-editor.md) tab that fills in as you wire rather than appearing at export time (AC-035), validation rules that never block an export (CR-022; the catalogue and its count are [docs/02 §5](docs/02-data-model.md#5-the-v1-validation-rule-catalogue-three-tiers)), a Staging Bin, a project-level location tree, pathways, three separate cable-length fields, and CSV import for structured wiring.

## Documentation

Read [00-overview](docs/00-overview.md) first, then [canonical-decisions](docs/canonical-decisions.md), the second is the authority every other document defers to. [10-decisions](docs/10-decisions.md) is the short-form ADR summary of it.

| Document | What it covers |
|---|---|
| [docs/00-overview.md](docs/00-overview.md) | The product in one read: the core loop, the v1 line, who it is for |
| [docs/01-domain.md](docs/01-domain.md) | Rack and A/V trade concepts, the glossary, the signal and cable registry |
| [docs/02-data-model.md](docs/02-data-model.md) | Entities, primitives, units, the `.rppj` envelope and migration chain |
| [docs/03-architecture.md](docs/03-architecture.md) | Five packages, the command stack, the drawing IR, the derived pipeline |
| [docs/04-rack-editor.md](docs/04-rack-editor.md) | Elevation authoring: placement, quick-add, staging, compaction, locks |
| [docs/05-schematic-editor.md](docs/05-schematic-editor.md) | The wiring canvas, drag-to-connect, layout and routing, the live schedule |
| [docs/06-device-builder.md](docs/06-device-builder.md) | Template authoring, the port grid, the three doors, `.rpdx` templates and `.rpda` libraries |
| [docs/07-structure-device.md](docs/07-structure-device.md) | Structured wiring entering the rack: outlets, home runs, dual labels |
| [docs/08-pdf-export.md](docs/08-pdf-export.md) | The sheet set, schedule presets, the PDF backend, greyscale and print tests |
| [docs/09-roadmap.md](docs/09-roadmap.md) | M0–M9, exit criteria, relative sizes, and the release bands of §2 (read them there, they have grown more than once) |
| [docs/10-decisions.md](docs/10-decisions.md) | Short-form ADR log: a summary of the record for readers who want the shape without the adjudication, plus the open questions. A summary with a pointer, not a ruling; where it and a ruling differ, the ruling wins |
| [docs/11-testing-and-quality.md](docs/11-testing-and-quality.md) | Fixture corpora, golden files, parity tests, performance budgets, accessibility |
| [docs/12-milestone-board.md](docs/12-milestone-board.md) | **The evidence.** Every milestone's exit clauses, marked by what was run; §1 is the board at a glance and the one home of project status |
| [docs/13-macos-debt-register.md](docs/13-macos-debt-register.md) | The macOS work list that DR-009 (macOS ships in v1) makes owed |
| [docs/14-deployment.md](docs/14-deployment.md) | The portable build and how to hand it over, and the version scheme (§14.0) |
| [docs/15-plan-view.md](docs/15-plan-view.md) | Floorplan underlay, pins, two-point calibration, the four-tier length model, the `T1.01` plan sheet. Added to v1 by DR-029; its status is on the board |
| [docs/16-m3g-drill.md](docs/16-m3g-drill.md) | A drill record: the script, conditions form and verdict form for M3's timed 60-drop exit clause, a test only a person can perform |
| [docs/17-m4q2-drill.md](docs/17-m4q2-drill.md) | A drill record: M4's second exit clause, whether a template a person authored places into a rack and prints `—` for what it does not know |
| [docs/18-m4r-mark-legibility.md](docs/18-m4r-mark-legibility.md) | A paper check: whether a person can tell the device marks apart on a greyscale print |
| [docs/19-riley.md](docs/19-riley.md) | The character reference for Riley, the mascot, written to be handed to an artist: what is fixed and what is open |
| [docs/20-rule-review.md](docs/20-rule-review.md) | A review pack for a working integrator to mark up: every validation check in plain terms, and the signal families |
| [docs/21-user-guide.md](docs/21-user-guide.md) | The user guide. Unlike every other document here, it describes what the application does today, not what it should be |
| [docs/22-riley-plate-plan.md](docs/22-riley-plate-plan.md) | **Proposed, not ruled.** Where Riley's art goes in the user guide: scenes, slot sizes, a budget for the visor |
| [docs/canonical-decisions.md](docs/canonical-decisions.md) | **Normative.** The full decision record: the `CR`, `AC`, `RJ` and `DR` rulings, canonical naming, the data model, the registry, the scope ruling and the milestone plan. Every other document defers to this one |
| [docs/catalog/seed-devices.md](docs/catalog/seed-devices.md) | The seeded archetypes. **The only place a template count is stated** (CR-061) |
| [docs/m1-implementation-log.md](docs/m1-implementation-log.md) | A build record of M1's stages. History, not a spec |
| [docs/proposed-output-exception.md](docs/proposed-output-exception.md) | **Proposed, not in force.** The draft output exception, kept for review before v1.0 (DR-259) |
| [docs/reference/keymap-windows.md](docs/reference/keymap-windows.md) | Every keyboard shortcut, generated from the keymap the app runs on |
| [docs/reference/keystone/](docs/reference/keystone/README.md) | What the real keystone straps and plates measured, for DR-007 §11.7 |
| [docs/research/](docs/research/) | The raw working papers: research briefs, design documents, critiques and a feasibility study (listed in [its README](docs/research/README.md)). **Non-normative rationale.** They explain *why*, and they are wrong wherever [canonical-decisions](docs/canonical-decisions.md) contradicts them |

## Target platforms

| Platform | v1 | Notes |
|---|---|---|
| Windows 10/11 desktop | Full editor | The only usable target today, and the only preview build |
| macOS desktop | Full editor, in v1 (DR-009) | Builds on CI as `RackPal.app` (DR-255, DR-256) but has no native file dialog or data folder yet, so it cannot open or save. DR-009 overturned §10.10's recommendation of Windows only; the remaining work is the list in [docs/13](docs/13-macos-debt-register.md) |
| iOS / Android / tablet | Read-only, not built | Exactly three surfaces (rack elevation, schedule table, exported PDF) and the app says so rather than shipping a squeezed editor (AC-056) |
| Web | No | One `kIsWeb` guard exists in the export path; a read-only viewer is a v2 distribution question |

Mobile is read-only by confirmed product decision. The architecture must not preclude touch, which is why `CanvasIntent{beginDrag, updateDrag, commitDrag, cancel}` is built first and no editor logic branches on `PointerDeviceKind` (AC-016 #23).

## Intended tech stack

| Layer | Choice | Why |
|---|---|---|
| Language / SDK | Dart, with Flutter pinned in `azure-pipelines.yml` (DR-248) | The pin is the `flutterVersion` variable there and nowhere else; `package:pdf` ^3.13.0 requires Dart ≥ 3.12.0 |
| UI | Flutter desktop | Single codebase across the desktop target and the read-only mobile shell |
| State / DI | No package. Constructor injection plus hand-rolled `Listenable`s | One `AppServices` is built in `main` and passed down; the document lives in a plain-Dart `DocumentController`, and `DocEpochs` holds seven `SimpleNotifier<int>` counters that painters subscribe to directly. `flutter_riverpod` was accepted by ADR-011 and never built; **DR-088** ratifies what exists and rejects the dependency (docs/03 §4.1) |
| PDF | `pdf` ^3.13.0 | Pure Dart, therefore isolate-safe; Apache-2.0. `pw.Widget` for schedules, `PdfGraphics` for vector diagram output |
| PDF preview | vendored pdfium over `dart:ffi` (`rackpal_pdfium`, DR-153) | The preview renders the real exported PDF, so what you see is what prints. The binary is committed under `third_party/pdfium/` with its licences and never downloaded at build time (CR-100) |
| IDs | `uuid` ^4.6.0 | UUIDv7: time-ordered, so creation order needs no extra field |
| File dialogs | first-party `IFileDialog`, no package | `file_selector` was removed: it cannot set `FOS_DONTADDTORECENT`, without which every open and save writes the project file name into `HKCU\…\ComDlg32\OpenSavePidlMRU`. ~150 lines of COM in the Windows runner. Half a fix, and the other half is bounded rather than listed: RackPal's own code writes no registry key, but **the shell writes values under ComDlg32 that RackPal does not control**: at minimum `LastVisitedPidlMRU` (this executable plus the last folder browsed) and `CIDSizeMRU` (this executable, written even on a cancelled dialog), measured examples and not an inventory. So a portable build leaves shell-owned HKCU entries naming this executable and folders browsed, and no project file names (docs/03 §10.1) |
| Window | `window_manager` ^0.5.2 | `setPreventClose` for the save prompt is the load-bearing API |
| Persistence | Hand-written JSON codecs | Plain, pretty-printed, key-sorted UTF-8 JSON. No `freezed`, no `json_serializable`, the migration chain and byte-round-trip contract need explicit control (CR-091, CR-092) |
| Lints | `very_good_analysis` 11.0.0, exact (DR-248) | Strictest widely-used set; `flutter_lints` ^6.0.0 is the fallback if it proves noisy |

The versions above are indicative. The committed `pubspec.lock` is what builds, and where this table and the lock differ, the lock is right.

## Building from source

**Prerequisites, on Windows 10 or 11 (x64):**

- **Flutter at exactly the version pinned in [`azure-pipelines.yml`](azure-pipelines.yml)** (the `flutterVersion` variable; the pin lives there and nowhere else, DR-248). A different version may build, and its output is not what the tests hold.
- **Visual Studio 2022** with the **Desktop development with C++** workload (Flutter's Windows toolchain).
- Git. Nothing else: pdfium is already in `third_party/`, and no build step downloads a binary.

**Build and run:**

```text
git clone https://github.com/RileyTheRackPal/RackPal.git
cd RackPal
flutter pub get --enforce-lockfile   # at the repository root: it is a pub workspace
cd apps/rackpal
flutter run -d windows
```

**Run the tests from each package's own directory**, not the root: several read fixtures relative to the working directory. `dart test` in `packages/rackpal_core`, `rackpal_text`, `rackpal_export` and `rackpal_pdfium`; `flutter test` in `packages/rackpal_ui` and `apps/rackpal`. Or run every gate at once, as described below.

**A portable folder** like the preview release: `pwsh -File tools/release/make_portable.ps1` writes `dist/RackPal-portable/`, which runs from anywhere and installs nothing ([docs/14](docs/14-deployment.md)).

## Continuous integration

CI runs on a private Azure DevOps project; this GitHub repository carries the same history. So the pipeline and the board that the corpus cites (definition numbers, build numbers, `#nnn` items) are not visible from here, and every gate it runs can be run locally with the commands below.

**The pipeline runs.** It first executed on 2026-08-27 (build `20260827.1`, definition 1, `RackPal CI (Windows)`), and [docs/12 §4.1](docs/12-milestone-board.md#41-discharged-2026-08-27-the-pipeline-runs-and-it-has-been-red) records what that run proved, what it did not, and the runs since that have gone red. This page used to carry a box saying no run had ever happened; it was true when written and is not now. `main` is protected by a build-validation policy, so work lands by pull request. `azure-pipelines.yml`'s header says which of its claims are verified and which are not, and where the build agent runs.

What the file *defines*: a Windows agent, the Flutter version pinned in its `flutterVersion` variable and **verified after install** (DR-248, docs/03 §10.2), the analyzer gate, the two palette gates, the JUnit converter self-test, every suite with a non-vacuity floor, `flutter build windows --release`, and publication of the test results and the release ZIP.

Every gate script under `tools/ci/` also runs on a developer machine. Run them the way the pipeline does:

```text
pwsh -File tools/ci/run_local.ps1                 # everything
pwsh -File tools/ci/run_local.ps1 -SkipBuild      # skip the Windows build
pwsh -File tools/ci/run_local.ps1 -SkipTests -SkipBuild   # fast gates only
```

What a local run does **not** cover, stated so it is not mistaken for done:

- **A clean checkout.** `run_local.ps1` runs against your working tree; the pipeline runs against a fresh clone, which is itself a gate (a `.gitattributes` defect in the byte-exact starter assets is only visible there). The cheap half of that is mechanised: `tools/ci/verify_tracked_sources.ps1` fails if any `lib/` Dart source is untracked, which is how a barrel `export` of a file no clone would receive gets caught before it is committed.
- **A second machine.** The pipeline's agent is self-hosted (see the header of `azure-pipelines.yml`), so a green run does not show the tree builds on a machine that is not the author's.

The analyzer gate is **zero errors, zero warnings, and a ratcheted info count** pinned in `tools/ci/analyze_info_baseline.txt`, not `--fatal-infos`, which would make `main` permanently red at the pinned number of infos. Each suite also has a non-vacuity floor (in `tools/ci/run_suite.ps1`) counted over **non-skipped** cases, so neither a runner that discovers no tests nor a batch silenced with `skip:` can pass.

## Project layout

Six packages, not one tree: the five of the original split plus `rackpal_pdfium`, the vendored pdfium binding that joined at DR-153. The split is mechanically enforced by `no_flutter_import_test`, which bans `package:flutter/`, `dart:ui` **and** `package:pdf/` from `rackpal_core` (CR-083). Rejected alternative: a single `lib/` tree with the Flutter and PDF canvas backends in one directory; it puts a concrete font engine in the core package and breaks the isolate-safety guarantee within a month.

```text
RackPal/
├─ packages/
│  ├─ rackpal_core/      pure Dart. no flutter, no dart:ui, NO pdf.
│  │                      model/ commands/ derived/ routing/ persistence/
│  │                      units/ idformat/ library/
│  │                      draw/  scene builders, hit_test.dart, BoundsCanvas
│  │                      declares abstract TextMeasurer + TextMetrics
│  ├─ rackpal_text/      pure Dart. core + package:pdf for PdfTtfFont only.
│  │                      ~5 files. The single concrete TextMeasurer.
│  ├─ rackpal_pdfium/    the vendored pdfium binding (dart:ffi, DR-153).
│  │                      the binary is committed, not downloaded (CR-100).
│  ├─ rackpal_export/    pure Dart. core + text + pdf.
│  │                      PdfDiagramCanvas, sheets, furniture, tables,
│  │                      document assembly. The isolate entry point.
│  └─ rackpal_ui/        flutter. core + text.
│                         FlutterDiagramCanvas, render objects, widgets,
│                         canvas/input/ (pointer plumbing, spatial hash)
├─ apps/
│  └─ rackpal/           the app. everything + plugins.
├─ assets/
│  └─ catalog/            seeded templates + sources.md (a cited source for
│                         every numeric field in every shipped template)
├─ third_party/pdfium/    the vendored pdfium binaries and their licences
├─ tools/ci/              the gate scripts, runnable locally
├─ .okf/                  the knowledge bundle — rulings, invariants, gates
│                         and practices, maintained as changes land
└─ docs/                  the specification set + research/
```

`rackpal_export` and `rackpal_ui` are siblings that cannot see each other. That is what makes the PDF path isolate-safe, and it is a build-time invariant rather than a convention.

## Design principles

Five principles decide most of the close calls in the decision record. Where a ruling looks arbitrary, it is almost always one of these applied mechanically.

1. **The schedule is the deliverable; the drawing is the receipt** (G1). RackPal is a cable-schedule generator with a rack elevation and a schematic on the front of it. Effort and risk budget follow the schedule; anything that delays or degrades it loses. The drawing is not decoration either; it is what the integrator hands the client to prove the schedule describes a real system, and what the integrator reads to find their own mistake.
2. **The document must be able to represent a wrong, incomplete, or found-in-the-field world** (G2). A model that cannot draw a mistake cannot document reality. A cable can run to a location that has no device yet, or to nothing at all. Only model-incoherence is illegal.
3. **A heuristic may never hold a user's deliverable hostage** (G3). No computed number, trade opinion or drafting convention blocks an export. Errors gate one thing, the `ISSUED FOR CONSTRUCTION` stamp, and never gate bytes. `blockExportOnErrors` is deleted, not deferred (CR-022).
4. **Never fabricate data; show `unknown`** (G4). A missing weight contributes nothing to a rollup and the rollup reports its unknown count. `typicalWatts` never silently defaults to half of nameplate. `null` means unknown everywhere and renders `—`.
5. **Cut features, never foundations** (G5). Units, UUIDv7 identity, tombstones, per-entity metadata, fractional indices, the command stack and the drawing IR all ship in v1 even where their UI does not. Anything expensive to retrofit is done now; this produces the "model ships, gesture defers" pattern that appears eleven times in the scope ruling.

Alongside the five, one ruling acts as the binding validation frame: **the gesture may hesitate; the document may not lie** (CR-017). The user knows things the software does not, so a rule that merely disagrees with them springs the gesture back with a reason rather than refusing it, **but the five tier-1 topology rules refuse outright and offer nothing to escape to** (DR-011.5, superseding this page's earlier claim of a `[ Connect anyway ]` button on every refusal; docs/02 §5's own tier table gives T1's escape as *"None. There is nothing to escape to."*). Spring-back belongs to the tier-2 rules, which land with validation at M5.

One concept has one name everywhere, Dart identifier, JSON key, UI label, prose, commit message and PDF column header all derive from one glossary entry (N1). `Connection`, `CableType`, `PhysicalLink`, `bottomU`, `refDes` and the rest of [canon §4.7](docs/canonical-decisions.md#47-banned-names) are banned in code *and* in comments.

## Licence

**AGPLv3-or-later** for the application code, in [`LICENSE`](LICENSE) (DR-189 §11.188.1, which reverses DR-036's GPLv3); **CC0 1.0** for the community device catalog, which is deliberately not copyleft (DR-036 §11.35.3). **This line read "TBD … under consideration" until 2026-09-23, six weeks after DR-036 answered the question**, which is why it now names the ruling rather than the state of a deliberation.

**The output exception is proposed and NOT in force.** DR-036 §11.35.4 asks for an explicit statement that a document produced by RackPal is the user's own work and not a derivative of RackPal. A draft is at [docs/proposed-output-exception.md](docs/proposed-output-exception.md); it goes to a qualified reviewer before v1.0 (DR-259 §11.258.2.1, which moved that review from *"before any public push"*), and until then `LICENSE` alone is the licence. **This paragraph said there was no `LICENSE` file until 2026-11-03**, five weeks after one was committed. A dependency sweep on 2026-07-31 found the tree clean for it (81 packages, 58 BSD / 18 MIT / 5 Apache-2.0, zero copyleft) with the Apache-2.0 members closing GPLv2 but not GPLv3.

Third-party licences are surfaced through `Help ▸ About RackPal…`, which opens Flutter's `showLicensePage` over the whole `LicenseRegistry`, and RackPal's own `LICENSE` is registered into it from `main` so the page lists this application beside its dependencies. **THIS SENTENCE CLAIMED THAT WAS ALREADY TRUE AND IT WAS NOT**: until 2026-09-23 neither `LicenseRegistry` nor `showLicensePage` appeared anywhere in the tree, so the portable folder shipped MIT, BSD-3 and Apache-2.0 code without reproducing the notices all three require. The licence asset is a gated copy of the root `LICENSE` (`test/session/license_asset_parity_test.dart`), because Flutter asset paths cannot escape the package directory and the alternative is the application showing terms the repository does not grant. **The shipped font is Jost, SIL OFL 1.1**: it supersedes CR-080's IBM Plex, which the ruling has not yet been amended for (docs/12 §4.6).
