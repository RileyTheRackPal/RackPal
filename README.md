# RackMate

RackMate is a desktop application for designing A/V equipment racks for custom-integration work — **residential-CI-first, commercial-capable** (DR-002): you enter a rack height in rack units, populate the rack from a seeded catalog of generic archetypes, wire the gear together on a schematic canvas, and export a PDF sheet set containing both the drawing and the cable schedule. The repository holds the specification — the canonical decision record, twelve documents derived from it, and the working papers they were adjudicated from — **and a Flutter application that builds and runs on Windows**.

## Status: IN BUILD — M0 and M1 shipped, M2 partial

| | |
|---|---|
| Phase | M0 (foundations) and M1 (the elevation release) shipped; M2 (wiring and the live schedule) is **PARTIAL** — four of five exit clauses discharged |
| Platform | Windows. macOS ships in v1 (DR-009) and is not built yet; the debt is enumerated in [docs/13](docs/13-macos-debt-register.md) |
| Tests | 2 832 passing, 0 failing across five packages, behind **thirteen local gates** (`tools/ci/run_local.ps1`) including a pinned analyzer ratchet |
| Next step | M3 — Structure and the field (see [Roadmap](docs/09-roadmap.md)) |
| Estimated effort to v1 | 42–65 weeks of implementation; 11–17 months to a shipped v1 with normal overhead |

**The status above is a summary, not the evidence.** [docs/12 — the milestone board](docs/12-milestone-board.md) is the audit: it marks every exit clause of every milestone with what was *run* rather than what is believed, cites the file or test that would have to be wrong for the mark to be wrong, and records where those citations have gone stale. Read it before trusting any claim on this page. In particular it records that **no CI service has ever executed the pipeline definition** — the gates are local, and "CI passes" is not yet a thing this project can say.

The estimate above is the record's own honest number, not a target. It is stated rather than softened because a detailed design with no cost attached stalls, and one with a *wrong* cost attached stalls while also destroying trust in the plan.

## Features

The seven core requirements of the brief, and what v1 does about each. All seven ship in v1 — the scope ruling's first filter is "does one of the seven requirements fail without it?", and anything that fails it is in regardless of cost (per §7.0).

| # | Requirement | v1 |
|---|---|---|
| 1 | Rack height in RU | Racks of 1–60 RU, 1-based bottom-origin `ruIndex`, per-rack numbering direction and rear-elevation mirroring (CR-038, CR-025, CR-026) |
| 2 | GUI device builder with I/O | Three required fields — name, RU height, designator prefix — then the port grid, with fill-down, TSV paste, archetype generators and a pattern DSL (AC-049) |
| 3 | Physical connections | Drag-to-connect on the Schematic with magnetic type-weighted snap, chain-draw and multi-draw; a `Link` is one physical cable carrying a list of `Service`s over `Conductor`s (CR-008, CR-010) |
| 4 | Colour-coding by cable type | Hue = signal domain, dash + weight + tag = type; eight domains, per-family colour override, legend printed in colour and greyscale side by side (CR-078, AC-054) |
| 5 | Schematic idiom | Net labels by default, drawn wires on domain filter, hover or focus (DR-001); Sugiyama phases 0–3 place the symbols and a deterministic layer-ordered orthogonal trace draws the wires; no route geometry is persisted, only symbol placement (DR-001, CR-013, CR-012) |
| 6 | Structure device | A `DeviceInstance` with `kind == structure` rendering as an edge bank of off-page flags; `Outlet` is the creation atom, a home run is a `Link` carrying a `StructureOrigin` (CR-016, AC-019) |
| 7 | PDF with diagram **and** schedule | Cover and drawing index, legend, exceptions page, front and rear elevations, **N interconnect sheets — one per domain partition of the single schematic `Sheet`**, Pull Sheet, Termination Schedule, Unused Home Runs, Equipment List and Materials, and plate/panel/pinout details where a non-standard pinout exists (AC-025, AC-055, CR-073, DR-005) |

Beyond the seven: a live [Schedule](docs/05-schematic-editor.md) tab that fills in as you wire rather than appearing at export time (AC-035), 27 validation rules that never block an export (CR-022), a Staging Bin, a project-level location tree, pathways, three separate cable-length fields, and CSV import for structured wiring.

## Documentation

Read [00-overview](docs/00-overview.md) first, then [canonical-decisions](docs/canonical-decisions.md) — the second is the authority every other document defers to. [10-decisions](docs/10-decisions.md) is the short-form ADR summary of it.

| Document | What it covers |
|---|---|
| [docs/00-overview.md](docs/00-overview.md) | The product in one read: the core loop, the v1 line, who it is for |
| [docs/01-domain.md](docs/01-domain.md) | Rack and A/V trade concepts, the glossary, the signal and cable registry |
| [docs/02-data-model.md](docs/02-data-model.md) | Entities, primitives, units, the `.rackmate` envelope and migration chain |
| [docs/03-architecture.md](docs/03-architecture.md) | Five packages, the command stack, the drawing IR, the derived pipeline |
| [docs/04-rack-editor.md](docs/04-rack-editor.md) | Elevation authoring: placement, quick-add, staging, compaction, locks |
| [docs/05-schematic-editor.md](docs/05-schematic-editor.md) | The wiring canvas, drag-to-connect, layout and routing, the live schedule |
| [docs/06-device-builder.md](docs/06-device-builder.md) | Template authoring, the port grid, the three doors, `.rmdev` |
| [docs/07-structure-device.md](docs/07-structure-device.md) | Structured wiring entering the rack: outlets, home runs, dual labels |
| [docs/08-pdf-export.md](docs/08-pdf-export.md) | The sheet set, schedule presets, the PDF backend, greyscale and print tests |
| [docs/09-roadmap.md](docs/09-roadmap.md) | M0–M9, exit criteria, the honest total, v1.1 / v1.2 / v2 buckets |
| [docs/canonical-decisions.md](docs/canonical-decisions.md) | **Normative.** The full decision record — 120 `CR-nnn`, 59 `AC-nnn`, 17 `RJ-nnn`, canonical naming, the data model, the registry, the scope ruling, the milestone plan, and Part 4's binding user decisions `DR-001`–`DR-005`. Every other document defers to this one |
| [docs/10-decisions.md](docs/10-decisions.md) | Short-form ADR log — sixteen ADRs summarising the record for readers who want the shape without the adjudication, plus the open questions. A summary with a pointer, not a ruling |
| [docs/11-testing-and-quality.md](docs/11-testing-and-quality.md) | Fixture corpora, golden files, parity tests, performance budgets, accessibility |
| [docs/catalog/seed-devices.md](docs/catalog/seed-devices.md) | The seeded archetypes. **The only place a template count is stated** (CR-061) |
| [docs/research/](docs/research/) | The raw working papers — four research briefs, six design documents, four critiques. **Non-normative rationale.** They explain *why*, and they are wrong wherever [canonical-decisions](docs/canonical-decisions.md) contradicts them |

## Target platforms

| Platform | v1 | Notes |
|---|---|---|
| Windows 11 desktop | Full editor | The primary and only shipping target for v1 |
| macOS desktop | Not in v1 | Recommended (not ruled) as the first post-v1 milestone; nothing in M0–M6 may take an unrecorded Windows-only dependency (§10.10) |
| iOS / Android / tablet | Read-only | Exactly three surfaces — rack elevation, schedule table, exported PDF — and the app says so rather than shipping a squeezed editor (AC-056) |
| Web | No | One `kIsWeb` guard exists in the export path; a read-only viewer is a v2 distribution question |

Mobile is read-only by confirmed product decision. The architecture must not preclude touch, which is why `CanvasIntent{beginDrag, updateDrag, commitDrag, cancel}` is built first and no editor logic branches on `PointerDeviceKind` (AC-016 #23).

## Intended tech stack

| Layer | Choice | Why |
|---|---|---|
| Language / SDK | Dart 3.12.2 stable | `package:pdf` ^3.13.0 requires Dart ≥ 3.12.0 — matches exactly |
| UI | Flutter desktop | Single codebase across the desktop target and the read-only mobile shell |
| State / DI | `flutter_riverpod` ^3.3.2 | Per-document lifetime scoping and chrome read-models, codegen-free. VERIFY: Riverpod 3 moved `ChangeNotifierProvider` to legacy — the `epochs.revision` adapter is hand-written (~15 lines) and the legacy library is not imported |
| PDF | `pdf` ^3.13.0 | Pure Dart, therefore isolate-safe; Apache-2.0. `pw.Widget` for schedules, `PdfGraphics` for vector diagram output |
| Print preview | `printing` ^5.15.0 | Behind an explicit "Verify output" button only; primary preview uses the screen renderer and has no native dependency. pdfium is vendored, never downloaded at build time (CR-100) |
| IDs | `uuid` ^4.6.0 | UUIDv7 — time-ordered, so creation order needs no extra field |
| File dialogs | first-party `IFileDialog`, no package | `file_selector` was removed: it cannot set `FOS_DONTADDTORECENT`, without which every open and save writes the project file name into `HKCU\…\ComDlg32\OpenSavePidlMRU`. ~150 lines of COM in the Windows runner. Half a fix, and the other half is bounded rather than listed: RackMate's own code writes no registry key, but **the shell writes values under ComDlg32 that RackMate does not control** — at minimum `LastVisitedPidlMRU` (this executable plus the last folder browsed) and `CIDSizeMRU` (this executable, written even on a cancelled dialog), measured examples and not an inventory. So a portable build leaves shell-owned HKCU entries naming this executable and folders browsed, and no project file names (docs/03 §10.1) |
| Window | `window_manager` ^0.5.2 | `setPreventClose` for the save prompt is the load-bearing API |
| Persistence | Hand-written JSON codecs | Plain, pretty-printed, key-sorted UTF-8 JSON. No `freezed`, no `json_serializable` — the migration chain and byte-round-trip contract need explicit control (CR-091, CR-092) |
| Lints | `very_good_analysis` ^9.0.0 | Strictest widely-used set; `flutter_lints` ^6.0.0 is the fallback if it proves noisy |

VERIFY: every version above is taken from the design corpus and has not been re-checked against pub.dev at the time of writing.

## Running it

There is nothing to run. Once M0 lands, the entry point will be:

```text
flutter pub get
flutter run -d windows          # from apps/rackmate
dart test                       # pure-Dart tests in core / text / export
flutter test                    # widget and golden tests in ui / app
```

## Continuous integration

> **NO AZURE DEVOPS RUN HAS EVER EXECUTED THIS PIPELINE.** `azure-pipelines.yml` was written and its gate scripts were mutation-tested on a developer machine; no CI service has parsed the YAML, resolved a task name, fetched the pinned SDK archive, or built on a hosted image. Until a run number can be cited, this section describes a **plan**, not a green build. The file's own header lists the four things only the first real run can prove — the YAML schema itself, the Flutter SDK download URL, whether the hosted image can build desktop Windows, and the wall-clock timeout — plus the fact that PR validation on Azure Repos comes from a branch policy and not from the `pr:` block. `docs/12-milestone-board.md` §4.1 carries the same caveat.

What the file *defines*: a Windows agent, the Flutter version **pinned to 3.44.4 and verified after install** (docs/03 §10.2), the analyzer gate, the two palette gates, the JUnit converter self-test, all five suites with non-vacuity floors, `flutter build windows --release`, and publication of the test results and the release ZIP.

What **is** verified, because it runs here: every gate script under `tools/ci/`. Run them the way the pipeline does:

```text
pwsh -File tools/ci/run_local.ps1                 # everything
pwsh -File tools/ci/run_local.ps1 -SkipBuild      # skip the Windows build
pwsh -File tools/ci/run_local.ps1 -SkipTests -SkipBuild   # fast gates only
```

Three things it does **not** cover, stated so none is mistaken for done:

- **No goldens.** There are none in this repository, so the roadmap's *"goldens pass"* limb is not satisfied by a green pipeline and the pipeline deliberately does not pretend to run them.
- **No clean checkout.** `run_local.ps1` runs against your working tree; the pipeline runs against a fresh clone, which is itself a gate (a `.gitattributes` defect in the byte-exact starter assets is only visible there). The cheap half of that is mechanised: `tools/ci/verify_tracked_sources.ps1` fails if any `lib/` Dart source is untracked, which is how a barrel `export` of a file no clone would receive gets caught before it is committed rather than on run 1.
- **No run.** See the box above.

The analyzer gate is **zero errors, zero warnings, and a ratcheted info count** pinned in `tools/ci/analyze_info_baseline.txt` — not `--fatal-infos`, which would make `main` permanently red at today's 195 infos. Each suite also has a non-vacuity floor counted over **non-skipped** cases, so neither a runner that discovers no tests nor a batch silenced with `skip:` can pass.

## Planned project layout

Five packages, not one tree. The split is mechanically enforced by `no_flutter_import_test`, which bans `package:flutter/`, `dart:ui` **and** `package:pdf/` from `rackmate_core` (CR-083). Rejected alternative: a single `lib/` tree with the Flutter and PDF canvas backends in one directory — it puts a concrete font engine in the core package and breaks the isolate-safety guarantee within a month.

```text
RackMate/
├─ packages/
│  ├─ rackmate_core/      pure Dart. no flutter, no dart:ui, NO pdf.
│  │                      model/ commands/ derived/ routing/ persistence/
│  │                      units/ idformat/ library/
│  │                      draw/  scene builders, hit_test.dart, BoundsCanvas
│  │                      declares abstract TextMeasurer + TextMetrics
│  ├─ rackmate_text/      pure Dart. core + package:pdf for PdfTtfFont only.
│  │                      ~5 files. The single concrete TextMeasurer.
│  ├─ rackmate_export/    pure Dart. core + text + pdf.
│  │                      PdfDiagramCanvas, sheets, furniture, tables,
│  │                      document assembly. The isolate entry point.
│  └─ rackmate_ui/        flutter. core + text.
│                         FlutterDiagramCanvas, render objects, widgets,
│                         canvas/input/ (pointer plumbing, spatial hash)
├─ apps/
│  └─ rackmate/           the app. everything + plugins.
├─ assets/
│  └─ catalog/            seeded templates + sources.md (a cited source for
│                         every numeric field in every shipped template)
├─ tools/ci/              the thirteen gates, runnable locally
├─ .okf/                  the knowledge bundle — rulings, invariants, gates
│                         and practices, maintained as changes land
└─ docs/                  the specification set + research/
```

`rackmate_export` and `rackmate_ui` are siblings that cannot see each other. That is what makes the PDF path isolate-safe, and it is a build-time invariant rather than a convention.

## Design principles

Five principles decide most of the close calls in the decision record. Where a ruling looks arbitrary, it is almost always one of these applied mechanically.

1. **The schedule is the deliverable; the drawing is the receipt** (G1). RackMate is a cable-schedule generator with a rack elevation and a schematic on the front of it. Effort and risk budget follow the schedule; anything that delays or degrades it loses. The drawing is not decoration either — it is what the integrator hands the client to prove the schedule describes a real system, and what the integrator reads to find their own mistake.
2. **The document must be able to represent a wrong, incomplete, or found-in-the-field world** (G2). A model that cannot draw a mistake cannot document reality. A cable can run to a location that has no device yet, or to nothing at all. Only model-incoherence is illegal.
3. **A heuristic may never hold a user's deliverable hostage** (G3). No computed number, trade opinion or drafting convention blocks an export. Errors gate one thing — the `ISSUED FOR CONSTRUCTION` stamp — and never gate bytes. `blockExportOnErrors` is deleted, not deferred (CR-022).
4. **Never fabricate data; show `unknown`** (G4). A missing weight contributes nothing to a rollup and the rollup reports its unknown count. `typicalWatts` never silently defaults to half of nameplate. `null` means unknown everywhere and renders `—`.
5. **Cut features, never foundations** (G5). Units, UUIDv7 identity, tombstones, per-entity metadata, fractional indices, the command stack and the drawing IR all ship in v1 even where their UI does not. Anything expensive to retrofit is done now; this produces the "model ships, gesture defers" pattern that appears eleven times in the scope ruling.

Alongside the five, one ruling acts as the binding validation frame: **the gesture may hesitate; the document may not lie** (CR-017). The user knows things the software does not, so a rule that merely disagrees with them springs the gesture back with a reason rather than refusing it — **but the five tier-1 topology rules refuse outright and offer nothing to escape to** (DR-011.5, superseding this page's earlier claim of a `[ Connect anyway ]` button on every refusal; docs/02 §5's own tier table gives T1's escape as *"None. There is nothing to escape to."*). Spring-back belongs to the tier-2 rules, which land with validation at M5.

One concept has one name everywhere — Dart identifier, JSON key, UI label, prose, commit message and PDF column header all derive from one glossary entry (N1). `Connection`, `CableType`, `PhysicalLink`, `bottomU`, `refDes` and the rest of [canon §4.7](docs/canonical-decisions.md#47-banned-names) are banned in code *and* in comments.

## Licence

TBD. A licence model and EULA are named deliverables of M8 (AC-058 D7); **a GPLv3 release is under consideration and this line is deliberately not rewritten until that question is ruled** (§10.3). A dependency sweep on 2026-07-31 found the tree clean for it — 81 packages, 58 BSD / 18 MIT / 5 Apache-2.0, zero copyleft — with the Apache-2.0 members closing GPLv2 but not GPLv3.

Third-party licences are registered via `LicenseRegistry` and surfaced through `showLicensePage`. **The shipped font is Jost, SIL OFL 1.1** — it supersedes CR-080's IBM Plex, which the ruling has not yet been amended for (docs/12 §4.6).
