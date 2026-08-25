# Architecture

This document specifies how RackMate is built: the five packages and the dependency rule that keeps them apart, where the document lives and how it is observed, the command and undo system that is the only way it changes, the derived-data pipeline, the single drawing IR that feeds both the screen and the PDF, persistence, and the platform surface. It is normative for structure and for names; where it states a decision, the governing ruling ID from the [decision record](10-decisions.md) is cited so any statement can be traced back to its adjudication. Anything not verified against a live API is marked `VERIFY:` rather than asserted, per [`critique-feasibility.md`](research/critique-feasibility.md), unverified API claims are the cheapest failure to prevent and the most expensive to discover late.

---

## 1. The five decisions everything follows from

Restated after adjudication. Three of the five survive intact; two were amended by rulings that matter more than the original statement.

| # | Decision | Status | Consequence |
|---|---|---|---|
| **D1** | **Monorepo, four pure-Dart packages + one Flutter app**, joined by pub workspaces. `rackmate_core` imports neither `package:flutter`, `dart:ui`, nor `package:pdf`. | **Amended by CR-083**: four packages became five. | Model, commands, routing, validation and the scene builder test in `dart test` in under a second, and run inside a background isolate for PDF export. |
| **D2** | **One mutable document aggregate, mutated only through `Command`s.** No immutable tree, no `copyWith`. Change detection by **epoch counters**, not equality. | Intact. | Undo is exact and free; repaint invalidation is exact; no deep-copy churn on drag. |
| **D3** | **Geometry stored as integers.** | **Superseded by CR-001**: the unit is `int64` **nanometres**, not hundredths-mm. | 1U = `Len(44_450_000)` exactly; 1/32 in = 793 750 nm exactly. The original hundredths-mm claim fails on the exact case it was written for. |
| **D4** | **A display list (`DiagramScene`) is the single drawing IR.** Screen and PDF are two interpreters of it. | **Strengthened by CR-086**: devices no longer escape it. | Screen and print cannot diverge, including on faceplates, which is where the divergence would have mattered most. |
| **D5** | **Pointer drags never touch the document.** Ephemeral drag state lives in an overlay-only `Listenable`; `onPointerUp` emits exactly one `Command`. | Intact. | 60 fps during drag with zero document-layer repaints, and one undo entry per gesture with no coalescing logic. |

Rejected alternative to D2: whole-document replacement (Bloc, `Notifier<T>`, signals). A 500 KB graph replaced per pointer-adjacent event is waste, and a replacement carries no information about *what* changed, which is precisely what the repaint system needs.

---

## 2. Packages and module structure

### 2.1 Five packages, not four and not one

Per **CR-083**. `design-architecture.md` argued four packages; `design-pdf-export.md` argued a single `lib/` tree with all four canvas backends in one directory. The single tree is rejected: it places `TextMeasurer` + `PdfFontMeasurer` in the core tree, which makes core depend on `package:pdf` and breaks core's own Flutter-free guard. The four-package split is rejected as insufficient: **CR-081** requires one concrete `TextMeasurer` backed by `PdfFont.stringMetrics` used by *every* backend including the Flutter one, and there is no legal home for it in four packages. The resolution is dependency **inversion**, not contamination, a fifth package.

| Package | Kind | Depends on | Owns |
|---|---|---|---|
| `rackmate_core` | pure Dart | `meta`, `collection`, `uuid` | model, commands, derived, routing, `draw/` (scene builders, `hit_test.dart`, `BoundsCanvas`), persistence, `units/`, `idformat/`, `library/`. Declares **abstract** `TextMeasurer` + `TextMetrics`. |
| `rackmate_text` | pure Dart | core + `pdf` (for `PdfTtfFont` only) | ~5 files. **The single concrete `TextMeasurer`.** |
| `rackmate_export` | pure Dart | core + `rackmate_text` + `pdf` | `PdfDiagramCanvas`, sheet furniture, tables, document assembly, the isolate entry point. |
| `rackmate_ui` | Flutter | core + `rackmate_text` | `FlutterDiagramCanvas`, render objects, widgets, `canvas/input/`. |
| `apps/rackmate` | Flutter app | everything + plugins | shell, providers, files, export service, diagnostics. |

`rackmate_ui` depending on `rackmate_text` is harmless: `package:pdf` is pure Dart and isolate-safe. The invariant that actually matters survives and is mechanically enforced, **`rackmate_core`, where the scene builder lives, has no concrete font engine and no `dart:ui`; it receives a `TextMeasurer` by injection.**

Rejected alternative: a folder convention inside one Flutter package. `design-architecture.md §1.1` predicts it "will be violated within a month by an `Offset` that 'was just easier'", and that prediction is the reason a package boundary, which the compiler enforces, is used instead of a lint.

Not using melos. Dart 3.6+ pub workspaces do the resolution; melos earns its place past ~6 packages or on first publish.

### 2.2 Annotated directory tree

```text
RackMate/
├─ pubspec.yaml                       workspace root: workspace: [packages/*, apps/*]
├─ analysis_options.yaml              shared lint baseline, inherited by all members
├─ dart_test.yaml                     tag definitions: golden, slow, perf
├─ docs/                              the fourteen planning documents plus the canonical
│                                     decision record. The six single-home documents the
│                                     corpus once referenced (rules.md, visual-language.md,
│                                     catalog.md, keymap.md, glossary.md, file-format.md)
│                                     were never authored; each has an existing home —
│                                     see the redirect table in canon §13.
│
├─ packages/
│  ├─ rackmate_core/                  ══ PURE DART. no flutter, no dart:ui, NO pdf ══
│  │  ├─ lib/rackmate_core.dart       the only public export barrel
│  │  └─ lib/src/
│  │     ├─ units/                    Len(nm), Mass(ug), Permille, Pt{gx,gy}, UnitFormatter,
│  │     │                            thermal.dart (kBtuPerWattHour). CR-001, CR-003, CR-005
│  │     ├─ idformat/                 ONE grammar, ONE registry, ONE parser. 5 call sites. CR-045
│  │     ├─ model/                    RackDocument + flat UUID-keyed entity maps. CR-090 names:
│  │     │                            rack.dart · device_instance.dart · port.dart · link.dart
│  │     │                            (NOT connection.dart — CR-008) · net.dart · service.dart
│  │     │                            · conductor.dart · placement.dart · structure_body.dart
│  │     │                            · outlet.dart · pathway.dart · sheet.dart · template.dart
│  │     │                            · entity_meta.dart · tombstone.dart          CR-095
│  │     ├─ builder/                  template_edit_session.dart (the second stack —
│  │     │                            CR-106) · template_commands.dart          M4-A
│  │     ├─ commands/                 command.dart (Command<A>, EpochMask, mergeKey) ·
│  │     │                            transaction.dart · undo_stack.dart (both generic
│  │     │                            over an aggregate — CR-106) · device_commands.dart ·
│  │     │                            link_commands.dart (Add/Remove/RetypeLink — CR-008) ·
│  │     │                            snapshot_command.dart
│  │     ├─ document_controller.dart   THE only mutation entry point; owns the UndoStack
│  │     ├─ derived/                  derivation.dart (Derived<T>) · occupancy.dart (depth
│  │     │                            intervals per (RU, face) — AC-022) · totals.dart ·
│  │     │                            schedule.dart (ONE function; UI table and PDF share it) ·
│  │     │                            validation.dart (Dart functions in a registry — CR-024)
│  │     ├─ routing/                  sugiyama.dart (phases 0–3, symbol placement) ·
│  │     │                            trace.dart (deterministic layer-ordered orthogonal
│  │     │                            trace, `drawn` mode only). Channel routing is v1.2 —
│  │     │                            DR-001. NO ObstacleField, NO RouteCache — CR-013
│  │     ├─ draw/                     ══ D4: the drawing IR ══
│  │     │  ├─ canvas.dart            abstract DiagramCanvas. No RendererCaps — CR-088
│  │     │  ├─ text.dart              abstract TextMeasurer + TextMetrics + TextStyleSpec +
│  │     │  │                         TextAnchor + anchorOffset(). One cluster. CR-081
│  │     │  ├─ ops.dart               sealed DiagramOp; DiagramScene {ops, bounds, hits}
│  │     │  ├─ spec.dart              Stroke{width, cap, join, miterLimit, dash, dashPhase,
│  │     │  │                         scaleWithGeometry, hairlineFloor} · Fill · Radii
│  │     │  │                         (TextStyleSpec lives in text.dart, not here)
│  │     │  ├─ bounds_canvas.dart     BoundsCanvas — v1. scale-to-fit, zoom-to-fit,
│  │     │  │                         elevation tile count. CR-089
│  │     │  ├─ hit_test.dart          GEOMETRIC hit test only. CR-084
│  │     │  └─ scene/                 scene_builder.dart · rack_layer.dart · device_layer.dart ·
│  │     │                            label_layer.dart (net-label stubs — the DEFAULT render,
│  │     │                            DR-001) · wire_layer.dart (`drawn` mode only).
│  │     │                            Every build*() takes lodLevel. AC-016/#13
│  │     ├─ persistence/              codec.dart (DocumentCodec, sniffs PK\x03\x04) ·
│  │     │                            json_codec.dart (hand-written) · schema.dart ·
│  │     │                            migrations.dart (append-only, Outcome<T>) — CR-091..093
│  │     ├─ library/                  catalog load + validate; .rmdx codec + its own chain
│  │     └─ util/outcome.dart         sealed Outcome<T> — expected outcomes are values
│  │  └─ test/                        migration_corpus_test · command_roundtrip_test ·
│  │                                  epoch_mask_test (AC-014) · byte_roundtrip_test (CR-117) ·
│  │                                  no_flutter_import_test · internal_setter_grep_test
│  │
│  ├─ rackmate_text/                  ══ PURE DART. core + pdf ══  ~5 files
│  │  └─ lib/src/pdf_font_measurer.dart  PdfFontMeasurer — the ONE concrete
│  │                                     TextMeasurer. CR-081, CR-083
│  │
│  ├─ rackmate_export/                ══ PURE DART. isolate entry point ══
│  │  └─ lib/src/                     pdf_diagram_canvas.dart (global Y-flip — CR-085) ·
│  │                                  sheets.dart · title_block.dart · schedule_table.dart ·
│  │                                  svg_canvas.dart (v1.1 — CR-089) · export_request.dart ·
│  │                                  build_document.dart (Isolate.spawn target — CR-099)
│  │
│  └─ rackmate_ui/                    ══ FLUTTER. no app shell ══
│     └─ lib/src/
│        ├─ theme/                    ThemeExtension<RackMateTheme>; SignalDomainDef → ui.Color
│        ├─ canvas/
│        │  ├─ flutter_diagram_canvas.dart   DiagramCanvas → ui.Canvas (dash synthesis)
│        │  ├─ render_rack_canvas.dart       MultiChildRenderObjectWidget + RenderBox
│        │  ├─ render_device.dart            RenderBox child; paint() REPLAYS its scene
│        │  │                                fragment. Draws nothing itself. CR-086
│        │  ├─ layer_cache.dart              ui.Picture memo keyed by (epochs, lodLevel)
│        │  ├─ label_cache.dart              LRU 12 000, key (text, styleId, quantisedScale)
│        │  ├─ viewport_controller.dart      Matrix4 + cached inverse, zoom-at-cursor
│        │  ├─ interaction_controller.dart   D5: ephemeral drag/marquee/live-wire state
│        │  └─ input/                        canvas_intent.dart (built FIRST — AC-016/#23) ·
│        │                                   pointer_router.dart · hit_tester.dart · snap.dart
│        ├─ inspector/ device_builder/ schedule/ structure/ outline/
│        └─ l10n/
│
└─ apps/rackmate/
   ├─ lib/main.dart                   runZonedGuarded, error hooks, window setup
   ├─ lib/providers/                  the ONLY place providers are declared
   ├─ lib/shell/                      app_menu.dart · intents.dart (the ONE Intent registry
   │                                  build/keymap.md is generated from at build time; the
   │                                  arbitrated bindings are ruled in canon §1.10 — CR-101)
   │                                  · actions.dart
   ├─ lib/files/                      document_file_service · autosave_service ·
   │                                  recovery_service · recent_files
   ├─ lib/export/export_service.dart  font preload on main isolate → Isolate.spawn
   ├─ lib/diagnostics/                log.dart · crash_reporter.dart
   ├─ assets/fonts/                   IBM Plex Sans / Sans Condensed / Mono + Noto Sans
   │                                  Symbols 2, declared TWICE in pubspec (fonts: and
   │                                  assets:). CR-080
   └─ windows/ macos/
```

---

## 3. Layering and the dependency rule

| Layer | Lives in | Contains |
|---|---|---|
| **Domain** | `rackmate_core/src/{units,idformat,model,routing,derived,draw}` | Entities, value objects, invariants, the router, the DRC rule functions, the scene builder. Knows nothing about files, PDFs, pixels or Flutter. |
| **Application** | `rackmate_core/src/{commands,document_controller.dart}` | `Command`, `Transaction`, `UndoStack`, `DocumentController`. Every state transition the product supports is a class here; this is the app's verb list. |
| **Infrastructure** | `rackmate_core/src/persistence`, all of `rackmate_text` and `rackmate_export`, `apps/rackmate/lib/src/storage`, and the file/export/dialog members of `apps/rackmate/lib/src/session` | Codecs, migrations, font metrics, PDF emission, disk I/O, isolates, logging, OS dialogs. |
| **Presentation** | all of `rackmate_ui`, and the shell members of `apps/rackmate/lib/src/session` (`app_shell.dart`, the `*_actions.dart` builders, `session_prompts.dart`) | Widgets, render objects, viewport, input, menus, and the composition root that injects `AppServices`. |

> **The dependency rule.** Dependencies point inward and downward only. Domain depends on nothing. Application depends only on Domain. Infrastructure depends on Domain and Application. Presentation depends on all three. No layer may name a type from a layer above it, and `rackmate_export` and `rackmate_ui` may not name each other.

Permitted import edges, exhaustively:

```text
rackmate_core    →  dart:core, dart:math, dart:convert, meta, collection, uuid
rackmate_text    →  rackmate_core, package:pdf
rackmate_export  →  rackmate_core, rackmate_text, package:pdf
rackmate_ui      →  rackmate_core, rackmate_text, flutter
apps/rackmate    →  all of the above, flutter, plugins
```

`rackmate_export` and `rackmate_ui` remain siblings that cannot see each other. That is what guarantees the PDF path is isolate-safe: there is no compile path from export code to `dart:ui`.

### 3.1 Three rules that carry the weight

1. **`rackmate_core` imports no `package:flutter`, no `dart:ui`, no `package:pdf`.** Not for `Offset`, not for `Color`, not for `Rect`. Core defines `Pt`, `Box`, and stores colour as `int` ARGB on `SignalDomainDef` (CR-078). Adapters live in `rackmate_ui`.
2. **The document is mutated only via `DocumentController.run(Command)`.** Enforced with `@internal` from `package:meta` on entity setters, an analyzer error for any consumer outside `rackmate_core`, which `rackmate_ui` and `apps/rackmate` are. Rejected alternative: `part of` the commands library (**AC-013**), `part` files cannot carry their own imports, so ~40 entity types plus ~30 command types collapse into one library file importing everything and 70 parts that cannot be reasoned about independently.
3. **Nothing in Domain or Application is `async`.** The document is a synchronous, single-threaded data structure. Every `Future` lives in Infrastructure or Presentation. This deletes an entire class of interleaved-mutation bug and makes every core test synchronous.

### 3.2 Mechanical enforcement

Two dependency-free guards, plus the pubspec:

```dart
// packages/rackmate_core/test/no_flutter_import_test.dart
test('rackmate_core has no UI, no Flutter, and no PDF engine', () {
  final banned = RegExp(r'''import\s+['"](package:flutter/|dart:ui|package:pdf/)''');
  for (final f in Directory('lib').listSync(recursive: true).whereType<File>()
                  .where((f) => f.path.endsWith('.dart'))) {
    final hit = banned.firstMatch(f.readAsStringSync());
    expect(hit, isNull, reason: '${f.path} imports ${hit?.group(1)}');
  }
});
```

```dart
// internal_setter_grep_test.dart — belt to @internal's braces (AC-013)
test('entity setters are called only from src/commands/', () { /* grep lib/ */ });
```

`rackmate_core`'s pubspec declares `environment: {sdk: ^3.12.0}` with **no `flutter:` key at all**, so a stray Flutter import is a hard compile error under `dart test` as well as a readable test failure in review.

---

## 4. State management

### 4.1 The choice

> **Constructor injection and hand-rolled `Listenable`s. There is no state-management package and no DI container.** The document lives in a plain-Dart `DocumentController`, and one `AppServices` is built in `main` and passed down.

**Ruled by DR-088** (canon §11.87, §12.27), which **supersedes ADR-011's Riverpod clause**. This section previously specified Riverpod 3.x as a DI and lifetime container. That layer was never written: at v0.4.63 the package appears in no `pubspec.yaml` and `ProviderScope` in no Dart file. What follows describes what is built, and DR-088 makes it the ruled answer rather than an accident anybody may quietly reverse.

A `RackDocument` at the scale targets is ~200 `DeviceInstance`s, ~1000 `Link`s, and ~600 KB of JSON (the corrected figure from **AC-006**, after lazy port materialisation). Riverpod had been kept for four things, none of which was holding the document, and **each is supplied by something already built**:

- **Scoped lifetime.** **CR-119** makes v1 single-document and single-window, so there is exactly one scope, and a scope of one is a variable. The lifetime problem that remained, the shell's `State` surviving rebuilds, is solved by the `GlobalKey<AppShellState>` minted in `main` and documented there as load-bearing.
- **DI without service locators.** `AppServices` is **one constructor parameter**. A test supplies a fake by constructing one, which needs no override mechanism.
- **Cheap chrome read-models.** Window title, dirty dot, Undo/Redo enablement, the totals chip strip, the open-findings count. The granularity `ref.watch(p.select(...))` would buy is bought instead by **`DocEpochs` holding seven counters rather than one revision number**: a consumer subscribing to `rack` is not woken by a `style` edit. That is the same optimisation performed in the model rather than in the view layer.
- **Ecosystem stability.** An argument about *which* dependency to take, never that one is needed.

**The built shape is also the reversible one**, which is why DR-088 ratifies rather than merely notes it: adding a container to a tree that passes one object down is mechanical; removing one that several hundred widgets read from is not.

Rejected alternatives, with the one-line reason each:

| Rejected | Reason |
|---|---|
| `flutter_riverpod` | **Rejected by DR-088**, having been accepted by ADR-011 and never built. Its four benefits are each answered above by something already in the tree; taking the dependency now would buy a container for a single scope and a `select()` the epoch counters already provide. Not forbidden forever: when tabs (v1.2) are designed, the question reopens on its own evidence. |
| `signals` | Its advantage is automatic fine-grained tracking of *widget* rebuilds; the canvas hot path bypasses widget rebuilds entirely via `CustomPainter(repaint:)`, so it is ecosystem risk for a benefit already engineered around. |
| Bloc | Event-sourcing a canvas means an event object per interaction tick; its good idea, an explicit replayable log, is the command stack, built by hand with better ergonomics (menu labels, inversion). |
| Immutable document + `copyWith` | Dart has no lens library worth using; deep `copyWith` chains are the largest source of tedium in Flutter document editors, and the two reasons to want immutability (safe undo, change detection) are already supplied by the command stack and the epoch counters. |
| `build_runner` / freezed / `json_serializable` | Macros were cancelled in January 2025, so codegen is a permanent commitment, not a bridge. Sealed classes plus exhaustive `switch` cover the union case natively, and **hand-written JSON is actively better for a document format** (§9.1). Zero `build_runner` keeps `dart test` sub-second for the life of the project. |

### 4.2 Ownership map

**Read as built at v0.4.63, not as planned.** Every name below resolves to a class in the repository.

```text
main()                                              ← the composition root
├── AppServices                                     built once, then passed by constructor
│   ├── DocumentSession          ChangeNotifier; owns the CURRENT controller
│   │   └── DocumentController                      [plain Dart, in core]
│   │       ├── RackDocument doc     flat UUID-keyed entity maps; @internal setters
│   │       ├── UndoStack<RackDocument>  document-scoped stack (one of three, CR-106)
│   │       ├── DocEpochs epochs     SimpleNotifier<int> × 7  ← repaint + invalidation
│   │       └── SimpleNotifier<int> changes   ← dirty state, title, undo enablement
│   ├── SessionController        new / open / save / close
│   ├── ExportController · AutosaveScheduler · WindowChrome · WindowTitleWriter
│   └── (stores: prefs, recents, recovery, snapshots, documents)
└── RackMateApp                  StatelessWidget; holds services, measurer, keys
    └── AppShell                 GlobalKey<AppShellState> minted in main, never in build
        └── canvas screens       each State owns its own ephemeral controllers:
            SelectionController · ViewportController · DragPreviewController
            ResizePreviewController · CompactionPreviewController
            StatusMessageController · CaretController · ShakeController
            SchematicRevealController        (nine at v0.4.63, an open count)
```

**Three things this map used to name and the repository does not contain**, all corrected here rather than pointered:

- **`ProviderScope` and the four `*Provider` declarations.** Never written (DR-088 §11.87.1).
- **`DerivedRegistry derived`.** Also never written, and **deliberately**: `document_controller.dart`'s own header records it as *"a later milestone's derived-data pipeline (§6) that does not exist yet, omitted rather than stubbed, since there is nothing yet for it to invalidate."* That is the right call and the honest record of it is in the source, not here.
- **`DocEpochs` as `ValueNotifier<int> × 6`.** It is `SimpleNotifier<int> × 7`. Pure Dart, because **D1 forbids Flutter imports in `rackmate_core`**, and seven because `sequence`, `structure`, `wires`, `rack`, `meta`, `style` and `sheet` are separate invalidation domains.

The ephemeral controllers are consumed by painters as plain `Listenable`s via `CustomPainter(repaint:)`, which is what keeps the canvas hot path off the widget rebuild path entirely.

### 4.3 The document: epochs, not equality

```dart
/// Bit flags a Command declares. The controller bumps matching epochs on commit.
extension type const EpochMask(int bits) {
  static const structure = EpochMask(1 << 0); // placement add/remove/move/rotate/face
  static const wires     = EpochMask(1 << 1); // Link/Service/Conductor/Net add/remove/retype
  static const rack      = EpochMask(1 << 2); // heightU, rack add/remove, rails, depth
  static const meta      = EpochMask(1 << 3); // designators, names, notes, ProjectInfo
  static const style     = EpochMask(1 << 4); // per-family colour overrides, ProjectSettings
  static const sheet     = EpochMask(1 << 5); // SheetItem positions, pinning, collapse
  EpochMask operator |(EpochMask o) => EpochMask(bits | o.bits);
  bool has(EpochMask o) => bits & o.bits != 0;
}

class DocEpochs {
  final sequence  = ValueNotifier<int>(0);   // strictly monotonic; the sync cursor. CR-094
  final structure = ValueNotifier<int>(0);
  final wires     = ValueNotifier<int>(0);
  final rack      = ValueNotifier<int>(0);
  final meta      = ValueNotifier<int>(0);
  final style     = ValueNotifier<int>(0);
  final sheet     = ValueNotifier<int>(0);

  void bump(EpochMask m) {
    sequence.value++;                        // every commit, AND every undo and redo
    if (m.has(EpochMask.structure)) structure.value++;
    // … one line per epoch
  }
}
```

Every `Command` declares `EpochMask get touches`. This one mechanism drives **three** systems: repaint invalidation (§7), derived-cache invalidation (§6), and dirty tracking (§9.4). A command cannot forget to invalidate something, because invalidation is a static property of the command type rather than an imperative call someone must remember to make.

`ValueNotifier<int>` is chosen over a bespoke `Listenable` because it composes with `Listenable.merge` and drops straight into `CustomPainter(repaint:)`.

**Two counters, not one (CR-094).** `RackDocument.sequence` is strictly monotonic, incremented on every committed transaction *and* on every undo and redo, an undo is a change, and is persisted; it is the sync cursor. `RackDocument.stateId` is in-memory only and non-monotonic: each undo entry records the `stateId` before and after, and `isDirty == stateId != savedStateId`, so undoing back to the save point marks the document clean. Overloading one counter for both breaks either the sync invariant or the dirty UX. `revision` as a field name is deleted.

### 4.4 Selection, viewport, tool mode, interaction

**Selection** is observed, not owned by the document. It is never persisted to `.rmpj` and never bumps `sequence`, selecting a device must not mark the file dirty. But every `Transaction` captures `selectionBefore` / `selectionAfter`, so undo restores it; without that, undoing a delete leaves the caret on an entity that no longer exists.

```dart
class SelectionController extends ChangeNotifier {
  Set<Uuid> _ids = const {};
  Uuid? _focus;                                  // last clicked — drives the inspector
  void apply(Iterable<Uuid> hits, SelectMode mode) { /* replace | add | subtract */ }
  Selection snapshot() => Selection(_ids, _focus);
  void restore(Selection s) { _ids = s.ids; _focus = s.focus; notifyListeners(); }
}
```

**Viewport** is a hand-rolled `ChangeNotifier` (~150 lines) owning a `Matrix4` and a cached inverse invalidated in every mutator. `InteractiveViewer` is rejected: it never receives `PointerScrollEvent`, so wheel-zoom-to-cursor is unimplementable inside it; it installs its own `ScaleGestureRecognizer` which fights marquee-select and drag-to-connect in the gesture arena; and `boundaryMargin` is the wrong model for a model-defined scene. Implementation detail that is easy to get backwards: pan deltas arrive in **screen** space and must be applied with `leftTranslate` (pre-multiply), while the zoom pivot uses right-multiplied `translate` in scene space, reversing them produces pan whose speed varies with zoom.

**No widget watches the viewport.** It is passed to painters as a repaint `Listenable`. The single exception is the status-bar zoom readout, which subscribes through a 10 Hz throttling adapter, otherwise a 1000 Hz mouse rebuilds a `Text` widget a thousand times a second.

**Tool mode** is a sealed class (`Select`, `PlaceDevice(templateRef)`, `DrawLink(signalFamily)`, `Pan`, `Measure`) in a small `NotifierProvider`. It changes at human speed, so ordinary widget rebuilds are correct and cheap. It parameterises the hit-test policy, the cursor, and which overlay affordances draw.

**Interaction** holds everything ephemeral (D5) and is listened to only by the overlay layer:

```dart
class InteractionController extends ChangeNotifier {
  DragSession? _drag;          // {ids, delta: Len, snapResult, ghostGeometry}
  Box? _marquee;
  PendingLink? _liveLink;
  List<SnapGuide> _guides = const [];
}
```

**The pointer-agnostic intent layer is built first, in M1 (AC-016/#23).** `CanvasIntent{beginDrag, updateDrag, commitDrag, cancel}` sits between raw input and every editor gesture, and **no editor logic branches on `PointerDeviceKind`**. "Architecture must not preclude touch" is a confirmed product decision, so this is not optional and it costs nothing when built first.

---

## 5. Commands and undo/redo

### 5.1 The `Command` interface

```dart
// packages/rackmate_core/lib/src/commands/command.dart
abstract base class Command<A> {                  // generic over the aggregate — CR-106
  const Command();

  /// Stable enum key + args, NOT a string — core cannot import Flutter, and the
  /// Edit menu must show a localized label while the log shows the enum name.
  LabelKey get label;

  /// Which epochs this command dirties. Static per command type; verified by test.
  /// NULL when `A` has no epoch model at all — not `EpochMask.none`, which asserts
  /// a command touched none of them. Every `Command<RackDocument>` returns non-null.
  EpochMask? get touches;

  /// The entities this command touched — hands the derived layer its invalidation set.
  Iterable<Uuid> get affects;

  /// Non-null makes this eligible to coalesce with an adjacent equal-mergeKey command.
  Object? get mergeKey => null;

  void apply(A aggregate);
  void revert(A aggregate);

  Command<A>? mergeWith(Command<A> next) => null;
}
```

**The type parameter arrived at M4-A, not at M0, and the gap was recorded rather than hidden.** M0 transcribed this interface literally and hard-typed `apply`/`revert` to `RackDocument`, while `UndoStack<A>` already carried its `<A>` for CR-106's documented intent; `undo_stack.dart`'s header named the mismatch as debt to close if the Device Builder's own stack was ever built. M4-A built it. The three pieces cannot land separately: an override's parameter type must be a supertype of the base's, so every subclass breaks the instant `Command` gains a parameter, and `strict-raw-types` closes the escape of leaving the stack holding a raw `Command`.

Three properties worth defending:

- **`apply`/`revert`, not `undo`/`redo`.** Redo is `apply` again. A command must be idempotent under alternation: `apply; revert; apply` lands in the identical state as a single `apply`. That is the invariant the property test asserts.
- **Commands store before-values, not whole entities.** `MoveDeviceCommand` holds `{id, fromRuIndex, toRuIndex, fromFace, toFace}`, tens of bytes. A 200-entry history is single-digit MB.
- **Commands never allocate IDs at `apply` time.** `AddDeviceCommand` generates its UUIDv7 in its *constructor*, so redo recreates the entity with the identical ID and commands stacked on top of it still resolve. This is the most common command-pattern bug and it is invisible until someone does add → connect → undo → undo → redo → redo.

### 5.2 A concrete command

```dart
final class MoveDeviceCommand extends Command {
  MoveDeviceCommand({
    required this.id,
    required this.fromRuIndex, required this.toRuIndex,   // 1-based, bottom origin. CR-025
    required this.fromFace,    required this.toFace,
  });

  final Uuid id;
  final int fromRuIndex, toRuIndex;
  final RackFace fromFace, toFace;

  @override LabelKey get label => LabelKey.moveDevice;
  @override EpochMask get touches => EpochMask.structure | EpochMask.wires;
  //                                 ^ wires too: endpoints moved, the layout is stale.
  @override Iterable<Uuid> get affects => [id];
  @override Object? get mergeKey => (MoveDeviceCommand, id);   // arrow-key nudge repeats

  @override void apply(RackDocument doc) {
    final d = doc.devices[id]!;
    d.placement = RailPlacement(ruIndex: toRuIndex, face: toFace);   // @internal setter
    d.meta.touch(doc.clock.nowUtc(), doc.actor);
  }

  @override void revert(RackDocument doc) {
    final d = doc.devices[id]!;
    d.placement = RailPlacement(ruIndex: fromRuIndex, face: fromFace);
    d.meta.touch(doc.clock.nowUtc(), doc.actor);
  }

  @override Command? mergeWith(Command next) => switch (next) {
    MoveDeviceCommand(id: final n, toRuIndex: final r, toFace: final f) when n == id =>
      MoveDeviceCommand(id: id, fromRuIndex: fromRuIndex, toRuIndex: r,
                        fromFace: fromFace, toFace: f),
    _ => null,
  };
}
```

`touches` includes `wires` even though no `Link` object changes: the *routed geometry* of every link touching this device is invalidated. When in doubt, over-declare, a spurious repaint is cheap, a stale wire is a bug report. **AC-014** removes the guesswork: one generic test snapshots every derived output for each command type, applies, snapshots again, diffs, and asserts the declared mask covers everything that changed. Forty lines, permanent, and the highest value-per-line test not already in the plan.

### 5.3 Transactions

```dart
final class Transaction<A> extends Command<A> {
  Transaction(this.label, this.children, this.selectionBefore, this.selectionAfter)
    : timestamp = DateTime.now();

  @override final LabelKey label;
  final List<Command<A>> children;
  final Selection? selectionBefore, selectionAfter;

  /// The union of the children that declare a mask; null when NONE does. A child
  /// declaring `EpochMask.none` still counts as declaring, so a document
  /// transaction folds to a real mask and never to null.
  @override EpochMask? get touches { … }
  @override Iterable<Uuid> get affects => children.expand((c) => c.affects);

  @override void apply(A aggregate) { for (final c in children) c.apply(aggregate); }

  @override void revert(A aggregate) {
    for (var i = children.length - 1; i >= 0; i--) children[i].revert(aggregate);
  }
}
```

Reverse-order revert is mandatory: deleting a device and its six links must restore the device *before* the links that reference it, or the link restore dereferences a missing device. Nested transactions **flatten into the outermost**: a device-builder "apply template changes" may open transactions internally, and the user must see one undo entry.

**Template-snapshot refcounting (AC-015).** Placing a device may insert a `TemplateSnapshot` into `RackDocument.templates`. Insertion and removal are **explicit child commands** in the transaction, with the refcount computed from `devices.values.where((d) => d.templateRef.key == k)`. Without this, `AddDeviceCommand.revert` either orphans a snapshot or removes one another device still uses. The byte-round-trip property test catches it for free once the generator emits add-device commands.

### 5.4 The undo stack and the controller

```dart
class UndoStack<A> {                       // generic over the aggregate — CR-106
  UndoStack({this.maxEntries = 200, this.mergeWindow = const Duration(milliseconds: 400)});

  bool get canUndo => _done.isNotEmpty;
  String? get undoLabelKey => _done.lastOrNull?.command.label.name;

  /// Coalesces into the stack top iff mergeKey matches AND the window has not elapsed.
  /// `before`/`after` are nullable since M4-A: a `Selection` is a set of `Uuid`s, and
  /// an aggregate whose parts are not `Uuid`-keyed records none.
  EpochMask? push(Command<A> c, Selection? before, Selection? after, DateTime now) {
    _undone.clear();                                  // linear undo; no undo tree in v1
    final top = _done.lastOrNull;
    if (top != null && c.mergeKey != null &&
        top.command.mergeKey == c.mergeKey &&
        now.difference(top.at) < mergeWindow) {
      final merged = top.command.mergeWith(c);
      if (merged != null) {
        _done[_done.length - 1] = _Entry(merged, top.selectionBefore, after, now);
        return c.touches;
      }
    }
    _done.add(_Entry(c, before, after, now));
    if (_done.length > maxEntries) _done.removeAt(0);
    return c.touches;
  }

  void poison() { /* canUndo/canRedo → false. See §12.3. */ }
}
```

```dart
class DocumentController {
  final RackDocument doc;
  final epochs = DocEpochs();
  final undo = UndoStack<RackDocument>();
  final derived = DerivedRegistry();

  bool get isDirty => doc.stateId != _savedStateId;

  void run(Command<RackDocument> c) => transact(c.label, (tx) => tx.add(c));

  T transact<T>(LabelKey label, T Function(TxnScope<RackDocument> tx) body) {
    if (_open != null) return body(_open!.scope);            // flatten
    final b = _TxnBuilder(label, selection.snapshot());
    _open = b;
    try {
      final result = body(b.scope);
      _commit(b);
      return result;
    } catch (e, st) {
      _rollback(b, e, st);                                   // §12.3
      rethrow;
    } finally {
      _open = null;
    }
  }

  void _commit(_TxnBuilder b) {
    if (b.children.isEmpty) return;                          // no-op edits add no history
    final txn = Transaction(b.label, b.children, b.selectionBefore, selection.snapshot());
    undo.push(txn, b.selectionBefore, selection.snapshot(), clock.nowUtc());
    derived.invalidateTouching(txn.affects);                 // §6
    epochs.bump(txn.touches);                                // invalidation happens ONCE
  }
}
```

Two subtleties. **Commands `apply` immediately inside `tx.add()`**, not at commit, so later commands in the same transaction read the results of earlier ones ("add device, then connect to it"). **Epochs bump once per transaction**, not per child, so a bulk operation touching 200 devices triggers exactly one repaint and one derived invalidation.

**Coalescing policy.** Merge iff `mergeKey` matches and the delta is under 400 ms, used for inspector typing (renaming is one undo entry), arrow-key nudges, and inspector sliders. Deliberately **not** used for canvas drags: D5's gesture-end-commits-once already collapses those, and doing both risks merging two genuinely distinct drags.

### 5.5 `SnapshotCommand`: the escape hatch

Auto-arrange, catalog import, "renumber all designators", "shrink rack and re-flow" are awkward to hand-invert. Do not write fragile inverse logic for them.

```dart
final class SnapshotCommand extends Command<RackDocument> {
  SnapshotCommand(this.label, this.touches, this.affects, this.before, this.after);
  final Map<Uuid, JsonMap?> before, after;         // null value == entity absent
  @override void apply(RackDocument doc) => doc.restoreEntities(after);
  @override void revert(RackDocument doc) => doc.restoreEntities(before);
}
```

It snapshots only the **affected entities'** JSON, ~60 KB for a 200-device re-flow. Pay it, get correctness immediately, and reserve precise commands for the high-frequency operations where memory and clarity actually matter.

### 5.6 Three stacks, one machinery (CR-106)

`UndoStack` is generic over an aggregate, and there are exactly three uses:

| Stack | Scope | Lifetime |
|---|---|---|
| Document | `RackDocument`, in `DocumentController` | The open project. |
| Device Builder | the `TemplateBody` being edited, in `TemplateEditSession` | Discarded on close without save. |
| — | Settings and library operations are **not undoable** | Therefore each must be individually confirmable or trivially reversible. |

The Structure editor's edits are ordinary document commands and use the document stack. Stated once so nobody builds a second mechanism.

**Built at M4-A.** `TemplateEditSession` (`packages/rackmate_core/lib/src/builder/`) is the second row, and it shares `Command<A>`, `Transaction<A>`, `TxnScope<A>` and `UndoStack<A>` with the first: everything the session adds is policy (a dirty save point, a close), and none of it is undo. **The session edits a deep COPY of the body**, made by `copyTemplateBody`, and that is what makes "discarded on close without save" a behaviour rather than a comment: a session mutating the library's own `TemplateBody` would leave every cancelled edit in memory for the next device placed from that template.

The third row is a rule with no code, and it stays that way. An undo scoped to one template cannot coherently undo an act on the shelf that template sits on.

---

## 6. The derived-data pipeline and invalidation

**Derived values are never serialized (CR-115).** `portIds`, `Outlet.roughInStatus`, `templateUpdateAvailable`, `Link.dominantSignalFamily`, elevation X/Y and circuit membership are in-memory only. A cache in the file bloats the git diff that plain JSON exists to keep readable and creates a second source of truth that will eventually disagree with the first.

Three tiers, assigned by cost and staleness tolerance.

### 6.1 Tier 1: synchronous epoch-keyed memo

Totals (RU used/free, weight, apparent VA, BTU/hr, outlet counts, port counts), the depth-occupancy map, and the **schedule rows**.

```dart
class Derived<T> {
  Derived(this._deps, this._compute);
  final EpochMask _deps;
  final T Function(RackDocument) _compute;
  T? _value;
  int _stamp = -1;

  T of(RackDocument doc, DocEpochs e) {
    final s = e.stampFor(_deps);          // packed hash of the epochs in _deps
    if (_stamp != s) { _value = _compute(doc); _stamp = s; }
    return _value as T;
  }
}
```

**Do not debounce these.** Debouncing exact, cheap data buys nothing and introduces visible lag in the chip strip. The schedule derivation is shared **verbatim** between the on-screen table and the PDF table; there is exactly one function that turns a `RackDocument` into schedule rows, or the printed schedule will eventually disagree with the screen (G1).

Rollups report their unknowns rather than fabricating (**CR-114**, G4): *"Total weight 148 lb · 3 devices have no weight."* `null` means unknown, everywhere; `typicalWatts` never defaults to half of nameplate.

### 6.2 Tier 2: per-domain scene sub-pictures

The original tier-2 slot held a `RouteCache` with an `ObstacleField` and per-link incremental invalidation. **CR-013 deletes all of it.** The router is **Sugiyama phases 0–3 (cycle-break, layer, barycentre, coordinate assign) for symbol placement, plus a deterministic layer-ordered orthogonal trace for `drawn` mode**, with a **full deterministic recompute**: full recompute is perfectly stable and the invalidation bookkeeping costs more than it saves. Interval-graph channel routing is **v1.2** (DR-001, canon §12.1): it exists to keep 150 simultaneous polylines legible, and under DR-001 the maximum simultaneous polyline count is one domain partition. `ObstacleField`, `RouteCache` and the phrase "obstacle-aware" do not appear in the repository, the v1 router is simpler still.

The slot is not left empty. Per **AC-003** and **AC-008** it is reassigned to **eight per-domain scene sub-pictures**.

**The commit-path arithmetic, restated under DR-001.** The original commit budget counted one stroked polyline per link. Under DR-001 the default render is **two net-label stubs per link (text, not geometry**) so the dominant commit-path term is the **label layer**, not the wire layer. Two labels per link on a 150-run project is ~300 text runs on top of the ~10 000 the label cache is sized for (AC-009). The eight per-domain sub-pictures are **kept**: they are precisely what lets a domain filter switch that domain to `drawn` mode without rebuilding the other seven. An edit to one HDMI run rebuilds ~1 200 ops while seven pictures replay untouched, and this is nearly free since paths are already batched by colour class.

### 6.3 Tier 3: incremental DRC, with a debounced isolate sweep

Rules are **Dart functions in a registry keyed by `ruleId`** (**CR-024**, **AC-011**). The rejected alternative, a JSON-serializable predicate AST, cannot express ~20 of the catalogue's rules (reachability, path enumeration with a per-hop predicate, parallel impedance, cascade budgets, two-limits-two-findings), so it buys a second rule system, a second debugger and a second test suite, for a user-authoring claim that has no UI. What stays data is substantial and correct: rule metadata, per-project `RuleOverride`s, `AckedFinding`s, forward-compat on unknown `ruleId`s, and the connector × signal-family compatibility matrix, which genuinely is a lookup table.

```dart
typedef Rule = Iterable<Finding> Function(RuleContext ctx);

class IncrementalValidator {
  /// Synchronous, called from _commit with the touched set. ~O(touched × rules).
  void revalidate(RackDocument doc, Set<Uuid> touched) { … }

  /// Full sweep: on load, before export, and on explicit "Re-check".
  static Future<ValidationReport> fullSweep(ValidationInput input) =>
      Isolate.run(() => runAllRules(input));
}
```

Incremental is the **primary** path, not the isolate. An isolate round-trip plus debounce makes issue badges lag the edit by 250–400 ms, which users read as "the app is slow"; synchronous incremental validation is imperceptible and always correct for local edits. The sweep is debounced at 500 ms with a generation token so a superseded result is discarded. **The isolate payload is a projection, not the document**: `ValidationInput` carries only the graph as flat typed lists (~30 KB), which is only possible because `rackmate_core` is Flutter-free.

Nothing here blocks anything. `Finding`s are computed and never stored; errors gate only `ExportSpec.issuedForConstruction` (**CR-022**, G3).

### 6.4 Invalidation summary

| Derived thing | Tier | Depends on | Recompute |
|---|---|---|---|
| Totals (weight / VA / BTU / RU / outlets) | 1 sync memo | `structure \| rack` | ~40 µs |
| Depth occupancy intervals per (RU, face) | 1 sync memo | `structure \| rack` | ~25 µs |
| Schedule rows (shared with PDF) | 1 sync memo | `wires \| structure \| meta` | ~900 µs |
| Layout (Sugiyama phases 0–3) + orthogonal trace | full recompute | `wires \| structure \| sheet` | ≤ 40 ms cold, 300 links |
| Scene sub-picture, per domain × LOD | 2 cache | matching epoch + `lodLevel` | ~1 200 ops |
| DRC findings (local) | 3a incremental sync | touched entities | ~200 µs |
| DRC findings (full) | 3b debounced isolate | whole document | ≤ 150 ms off-thread |

---

## 7. Rendering pipeline

### 7.1 One drawing path (CR-086)

The corpus contained a latent contradiction: D4 declares the display list the single drawing IR, and every UX document then specified device faceplates, ports and designators as "real widgets", so the **most information-dense content in the deliverable** would be drawn by a widget tree on screen and by a scene builder in print, with no parity mechanism. The parity test compared the two *canvas backends*, not the two *device renderers*.

> **Ruling: one rendering path; widgets remain as an interaction and semantics shell.** Each device is still a `RenderBox` child of `RenderRackCanvas` — it owns hit-testing, focus, hover, keyboard handling and `Semantics`, which is what makes the accessibility story true. But its `paint()` **replays that device's `DiagramScene` fragment through `FlutterDiagramCanvas`**; it draws nothing itself. Pixels come from the shared IR; behaviour comes from the widget.

This is the single most consequential architectural ruling in the record. Both positions get what they argued for, D4's guarantee holds where it matters, and the parity test covers faceplates by construction.

The reconciliation between "one display list" and "fine-grained incremental repaint" is that the scene is built **per layer and per LOD**, and each layer's `DiagramScene` is cached under its own key. The display list is the authoring format; a `ui.Picture` is the compiled artifact.

```text
RackDocument
   │ SceneBuilder.buildRackLayer(doc, lod)     → DiagramScene   [key: rack, lod]
   │ SceneBuilder.buildDeviceLayer(doc, lod)   → DiagramScene   [key: structure|style, lod]
   │ SceneBuilder.buildWireLayer(doc, lod)     → DiagramScene   [key: wires|structure, lod]
   ▼
   ├─ replay → FlutterDiagramCanvas(PictureRecorder) → ui.Picture → canvas.drawPicture()
   ├─ replay → PdfDiagramCanvas(PdfGraphics)         → vector PDF page content
   └─ replay → BoundsCanvas                          → true extent, for fit / elevation tiling
```

**`lodLevel` is an explicit parameter of every `build*` and part of every cache key (AC-016/#13).** Without it the cache silently returns the wrong LOD after a zoom change, and the claim that display-list goldens cover screen and PDF simultaneously is false, since PDF exports at print LOD and the screen is at current zoom. Goldens pin the LOD, with one golden specifically at print LOD.

### 7.2 Layer stack

Bottom to top, inside one `RenderRackCanvas` (a `MultiChildRenderObjectWidget`):

| # | Layer | Mechanism | Invalidated by |
|---|---|---|---|
| L0 | Background grid | `ui.Picture` re-baked per zoom decade; `Picture.toImageSync()` promotion is legitimate here because rasterisation dominates | zoom decade, theme |
| L1 | Rack chassis: rails, RU ruler, mounting holes, face divider | cached `ui.Picture` | `epochs.rack`, theme |
| L2 | Device bodies | `RenderBox` children that **replay their scene fragment** (CR-086) | `epochs.structure`/`style`, layout-isolated |
| L3a | Settled runs, **split into 8 per-domain sub-pictures** | cached `ui.Picture`, one `Path` per colour class | `epochs.wires`/`structure`, per domain |
| L3b | Tag pills | own LOD-gated picture, keyed `(wires, viewport decade)` | `epochs.wires`, LOD |
| L3c | Active runs (attached to the dragged device) | re-recorded each frame, ~8 of 1000 | `interaction` |
| L4 | Overlay: selection halo, marquee, snap guides, live link, hover | never cached, ~30 ops | `interaction`, `selection` |
| L5 | Screen-space HUD: RU numbers, zoom badge, off-screen indicators | painted **outside** the scene transform | throttled viewport |

The load-bearing detail in `performLayout` is that children get tight constraints derived from their **own** model size with `parentUsesSize: false`, so each child is a relayout boundary and moving device A cannot dirty device B's layout:

```dart
@override
void performLayout() {
  size = constraints.biggest;
  var child = firstChild;
  while (child != null) {
    final pd = child.parentData! as RackParentData;
    child.layout(BoxConstraints.tight(pd.sceneSize), parentUsesSize: false);
    child = pd.nextSibling;
  }
}
```

### 7.3 Caching, and the rules that keep the frame

```dart
class LayerCache {
  ui.Picture? _picture;
  Object? _key;                                    // (epochTuple, lodLevel)

  ui.Picture obtain(Object key, Rect cullRect, void Function(Canvas) draw) {
    if (_picture != null && _key == key) return _picture!;
    _picture?.dispose();                           // REQUIRED: native memory
    final rec = ui.PictureRecorder();
    draw(Canvas(rec, cullRect));
    _key = key;
    return _picture = rec.endRecording();
  }
}
```

`ui.Picture` caches **drawing instructions, not pixels**: replay still costs GPU time proportional to content, but it eliminates Dart-side command building and the scene walk. `RepaintBoundary` is complementary, not an alternative: wrap the canvas as a whole and the side panels, and do **not** wrap individual device widgets (200 compositing layers cost more than they save).

Hard rules:

- **No `setState` in the canvas path, ever.** Pan, zoom, drag, hover and marquee repaint via `repaint:` listenables or `markNeedsPaint()`. `CustomPainter(repaint:)` triggers a repaint while **skipping build and layout entirely**: that is what makes 60 fps achievable regardless of what wraps the canvas.
- **Zero `saveLayer`.** ~1 ms worst case; three of them eat a fifth of the frame. It is triggered implicitly by subtree opacity, blend modes, and antialiased `clipPath` + save. To dim filtered runs, **bake alpha into the colour**: never wrap in an opacity layer. `checkerboardOffscreenLayers` must read zero, and that is a manual pre-release check.
- **Batch by style.** One `Path` per colour class, so eight domains means ~8 `drawPath` calls for 1000 runs.
- **Line weights follow the stroke, not a global rule (CR-082).** `Stroke.scaleWithGeometry` decides: cable traces, symbol outlines and rack rails **scale**; UI chrome, selection halos and hit slop are **constant in screen pixels** (`width / viewport.scale`); sheet furniture uses `hairlineFloor` with a 0.25 pt print floor. No stroke width is ever emitted as 0.
- **The label cache is 12 000 entries (AC-009).** The original 2 000 was derived from "200 devices × 8 labels"; the real count is ~10 000 text runs, 200 devices × ~20 ports × two runs (designator *and* label), plus headers, plus two tag pills per run. A thrashing LRU is **worse than none**, because eviction disposes a native `ui.Paragraph` inside the paint path. Key on `(text, styleId, quantisedScale)`: port labels come from a small set of repeated strings, so *distinct* keys collapse to low thousands even at the hard cap. Quantise scale to a ladder (`0.5, 0.75, 1.0, 1.5, 2.0, 3.0, 4.0`) with the residual as a local canvas scale, or every zoom frame is a total cache miss *and* a glyph-atlas miss. **The LOD gate is a test, not an intention:** at fit-to-sheet zoom, assert zero text runs laid out.
- **`TextPainter` must be disposed on eviction**: it holds a native `ui.Paragraph` the Dart GC will not reclaim. `leak_tracker_flutter_testing` guards this in widget tests.

### 7.4 Hit-testing (CR-084)

Split by concern. The **geometric** test (`DiagramScene.hits`, point-to-segment distance, nearest-hit selection) lives in `rackmate_core/draw/hit_test.dart`: pure, synchronously testable, and reusable by the read-only mobile shell. The **pointer plumbing** (one query per frame, spatial hash, cursor policy, hover throttle) lives in `rackmate_ui/canvas/input/`.

Two facts that contradict plausible assumptions:

- **`Path.contains()` does not work on strokes.** It only works on closed paths, so a stroked polyline returns false everywhere. Flutter exposes no stroke-to-fill-path API, Skia's `getFillPath` is not in `dart:ui`, and Impeller strokes by iterating the curve rather than materialising an outline, so it is unlikely ever to be exposed. Link hit-testing is **closed-form point-to-segment distance**, trivial for orthogonal polylines and faster than every alternative anyway.
- **Return the *nearest* hit, not the first.** In a schematic, runs cross constantly; first-hit picks arbitrarily and feels broken.

Start with brute force plus an AABB reject (`if (!w.bounds.inflate(tol).contains(p)) continue;` kills ~95% of candidates, ~64 µs at 1000 runs × 4 segments). Add a uniform spatial hash (~120 lines, `Map<int, List<int>>` by grid cell) only if *hover* shows up in the timeline, and throttle hover to one hit-test per frame regardless. Do not import an R-tree; they earn their complexity at 10⁵ objects and there are 10³.

---

## 8. The shared drawing abstraction

### 8.1 The interface

The single declaration of `DiagramCanvas` is [PDF export §7.3](08-pdf-export.md), in `rackmate_core/draw/canvas.dart`. It is not restated here: CR-086 makes this the one drawing IR both backends replay, and two declarations of it are two chances to diverge.

There is **no `RendererCaps` (CR-088)**. The moment a scene builder branches on capabilities there are two code paths and the abstraction has already leaked. The interface is the common denominator, and the visual-language restriction, **flat fills, strokes, dashes and text only; no gradients, no shadows, no blurs, no blend modes, no shaders**: is promoted from prose to an invariant with a test. This is not a hardship; it *is* the schematic aesthetic, and it is what guarantees the backends agree.

**Units contract, stated once (CR-007).** Geometry at this boundary is in **diagram units: 1 diagram unit = 1 PDF point = 1/72 in, as `double`**. This is not a breach of "no doubles": the model stores `Len` in integer nanometres and `DiagramScene` is a transient rendering artifact that is never persisted. Conversion from `Len(nm)` to points happens in **exactly one function** in the scene builder. Stroke widths and font sizes are in typographic points, with `Stroke.scaleWithGeometry` making "hairlines must not shrink when scaled to fit" a first-class concept. `Stroke` carries explicit `cap`, `join` and `miterLimit` and both backends set them (**AC-016/#21**: PDF's default miter limit is 10, Flutter's is 4).

### 8.2 `TextMeasurer`: the load-bearing part

**CR-081** is what forces the five-package split, so it is worth stating exactly.

`TextMeasurer`, `TextMetrics`, `TextStyleSpec`, `TextAnchor` and the shared `anchorOffset` helper are declared once, in `rackmate_core/draw/text.dart`, see [PDF export §7.5](08-pdf-export.md). One file, one cluster; there is no `draw/text_measurer.dart`.

The rejected alternative was `Pt measureText(...)` with each backend answering independently. It fails at exactly one point, and the failure is invisible until it is printed: `PdfGraphics.drawString` positions at the **baseline**, while `TextPainter.paint` positions at the **top-left of the line box**. Converting between them needs `ascent`, which `Pt` cannot express, so each adapter derives a baseline independently, one from `PdfFontMetrics.ascent` and the other from a fudge of `height × 0.8`, and they do not agree. The result is text sitting a fraction of a line off between screen and print, uniformly, everywhere: invisible in code review, invisible in a display-list golden (which records the anchor, not the resolved baseline), and glaring on a printed drawing beside a leader line.

The binding rules:

1. **One injected `TextMeasurer`, backed by `PdfFont.stringMetrics`, used by the scene builder and by *every* backend including the Flutter one.** It lives in `rackmate_text`; core declares only the interface.
2. `measureText` returns `TextMetrics`, never `Pt` (**CR-087**, recorded separately because it is a signature that will otherwise be copied from the wrong document).
3. `TextStyleSpec` carries an explicit `TextAnchor`, resolved in **one shared pure-Dart helper**, so no adapter ever guesses a baseline.
4. The Flutter side sets `FontFeature.disable('kern')` **and** `FontFeature.disable('liga')`. `VERIFY:` there is no first-class API for "disable kerning"; these two feature flags are the only route, and standard ligatures are on by default and also affect advances. This is two flags plus a test, not a checkbox.
5. **The parity test asserts on baseline Y**, not just the bounding box, and a kerning-heavy fixture (`"AV Wa To Ty"`) must agree within 0.5%.

The residual error is understood and accepted: Skia *paints* a string a fraction of a percent wider than PDF metrics predict, so screen text can overflow a box that fits in the PDF. That is cosmetic, screen-only and bounded, and it is the correct trade, because layout parity (symbol widths, pill sizes, track counts, sheet fitting) is exact.

`VERIFY:` `PdfTtfFont` appears to require a `PdfDocument` to construct, which would mean building a throwaway document purely to parse three font families for metrics (**AC-016/#18**). The metrics font is therefore constructed **lazily on first paint**, not at bootstrap, and `stringMetrics` results are cached aggressively. Measure this against the 1.2 s cold-start budget as the sixth API spike in week one (**CR-120**).

### 8.3 The two backends

**`FlutterDiagramCanvas`** (`rackmate_ui`) replays a scene into a `ui.Canvas`. It absorbs one mismatch: **`dart:ui Canvas` has no dashing at all**, while `PdfGraphics.setLineDashPattern` is native. Without handling this, dashed domains render solid on screen and dashed in the PDF. It synthesizes via `path_drawing`'s `dashPath` and caches the dashed `ui.Path` per `(geometry, dash)` pair. One consequence is recorded rather than discovered later (**AC-016/#17**): `dashPath` resamples via `PathMetrics`, which is an approximation on curves, so dash phase can diverge between screen and print on corner fillets, documented in [the visual language](05-schematic-editor.md#66-rendering-constants-stated-once). There are no hop arcs in v1 (DR-001), so that half of the original concern is gone; straight dashed segments remain squarely on the hot path. `VERIFY:` profile `dashPath` explicitly in the perf harness rather than assuming the cache absorbs it.

**`PdfDiagramCanvas`** (`rackmate_export`) replays into `PdfGraphics`. It uses a **global Y-flip (CR-085)**, not per-coordinate negation. Per-coordinate flipping is valid only for an axis-aligned, rotation-free interface, and `DiagramCanvas` exposes `rotate()`; a rotation composed with per-coordinate negation is not a valid transform, and the failure is invisible until someone rotates a label 90° for a vertical rail, at which point it is diagnosed as "the PDF is wrong" months later. Text is counter-flipped in exactly one method. Recorded normatively because it will otherwise cost a day: **`pw.CustomPaint` pre-translates to the *widget box's* bottom-left, so the flip height is `size.y`, not the page height.**

**`BoundsCanvas`** (`rackmate_core`) ships in v1 (**CR-089**). Bounds are not optional, scale-to-fit, zoom-to-fit and the tile count for the one over-tall rack elevation all need the diagram's true extent and there is no other way to get it. Key plans are cut with the rest of the multi-sheet apparatus (CR-073, DR-004). `SvgDiagramCanvas` is v1.1: one file on top of an architecture that already exists.

Defining every connector symbol once as an SVG path `d` string eliminates the remaining duplication risk, but **the parse happens once, at catalog load**, via `DiagramPath.fromSvg(String d)`, and both backends then draw the resulting `DiagramPath` through `drawPath`. There is no `drawSvgPath` on the interface: a backend that parses strings is a backend that can disagree with the other one, which is exactly what CR-086 exists to prevent. `PdfGraphics.drawShape` and `parseSvgPathData` remain useful below that boundary, and both signatures were verified in the feasibility review.

---

## 9. Persistence

Full field-level detail is in [the file format](02-data-model.md#6-the-rackmate-file-format); this section covers the machinery.

### 9.1 Container and envelope

`.rmpj` is **plain, pretty-printed, key-sorted UTF-8 JSON** (**CR-091**). The zip alternative existed only to carry per-face device images, and images are cut from v1 (**AC-057**), so the container question resolves to what the confirmed product decisions already specified. `DocumentCodec` ships from commit one and **sniffs `PK\x03\x04` on read**, so a v2 zip container is a non-event and the extension never changes.

```dart
abstract class DocumentCodec {
  Outcome<RackDocument> read(Uint8List bytes);
  Uint8List write(RackDocument doc);
}
```

The envelope puts format metadata at the root and all entity maps under a `"document"` wrapper (**CR-092**). The rejected alternative, project fields at the root, conflates format with content; the wrapper makes the magic-key check a single top-level read before any parsing and gives migrations one obvious place to stand.

```json
{
  "generator": "RackMate",
  "schemaVersion": 2,
  "minReaderVersion": 2,
  "appVersion": "1.0.0",
  "document": { "racks": {}, "devices": {}, "links": {}, "nets": {} }
}
```

Two codec rules: **enums are strings, never ordinals** (`"hdmi"`, not `3`), with unknown values falling back to a round-tripping `unknown(raw)` variant; and **every persisted object preserves unknown fields** in a `Map<String, Object?> unknown` and re-emits them, so a v1.0 app opening a v1.4 file round-trips without destroying newer data.

**Codecs are hand-written.** Generated codecs couple the on-disk format to the Dart class shape, so every class refactor silently changes the file format, for a format that must open in 2033, that coupling *is* the bug. Cost is ~300 lines written once, and the format becomes an explicit, reviewable, diffable artifact.

**The round-trip test asserts the byte property, not the semantic one (CR-117):** `write(read(bytes)) == bytes`. The stated justification for plain JSON is git-diffability and honest dirty-tracking, and only the byte property constrains key ordering (including inside nested `unknown` maps), timestamp precision, and integer formatting, which are exactly the things that produce spurious diffs and a lying dirty flag.

### 9.2 Migration

```dart
const kSchemaVersion = 2;
typedef JsonMap = Map<String, Object?>;
typedef Migration = JsonMap Function(JsonMap);

/// APPEND-ONLY. A shipped migration is a historical record — editing one
/// corrupts users' files. Never delete, never modify.
const migrations = <int, Migration>{0: _v0ToV1, 1: _v1ToV2};

Outcome<MigratedDoc> migrateToCurrent(JsonMap raw) { … }
```

Migration returns `Outcome<T>` and never throws (**CR-093**), expected outcomes are values. The two cases, with the defect in the original snippet fixed:

| Condition | Result |
|---|---|
| `minReaderVersion > kSchemaVersion` | `Err(NewerSchema(refuse))`: the original returned `readOnly: false`, which is backwards |
| `schemaVersion > kSchemaVersion && minReaderVersion <= kSchemaVersion` | `Ok(doc, openReadOnly: true)`, unknown fields preserved for a subsequent Save As |
| `generator != "RackMate"` | `Err(NotARackMateFile())`: a good error, not a null-cast crash |

**Migrate the raw map before any typed deserialization.** Migrating typed objects requires keeping historical Dart class shapes alive forever.

### 9.3 Save path: atomic, always

```text
1. Serialize in Isolate.run (AC-006: at the corrected ~600 KB, keep the UI thread clean).
2. Write bytes to <target>.rmpj.tmp in the SAME directory (same volume ⇒ atomic rename).
3. flush() + close().
4. If <target> exists → rename it to <target>.bak (overwriting the previous .bak).
5. rename(<target>.rmpj.tmp → <target>.rmpj).
6. _savedStateId = doc.stateId;                        → isDirty goes false
7. Delete this document's recovery snapshot.
8. Push to recent files; update the window title.
```

A crash at any step leaves either the previous good file, or the previous good file plus a `.tmp`. There is **one** `.bak` sibling and **no `.history/` folder** (**CR-098**), the confirmed product decision is a local single-file project, so the user's folder gains nothing but the file they asked for and one backup. Pre-update snapshots go to `getApplicationSupportDirectory()/snapshots/<docUuid>/<sequence>.rmpj`, pruned to the last 10.

### 9.4 Dirty tracking, autosave, recovery

`isDirty == doc.stateId != savedStateId`, per **CR-094**. Never document equality; that is `O(document)` per keystroke and gets subtly wrong the moment a float survives into the model (which, per the persistence contract, it must not).

- Every **30 s** and on **window blur**, if dirty, write a recovery snapshot to `getApplicationSupportDirectory()/recovery/<docUuid>.rmpj` plus a sidecar `{realPath, sequence, savedAt, displayName}`.
- **Never autosave over the user's file.** CAD users expect explicit saves and will file a bug the first time an autosave clobbers something.
- Autosave serialization runs in `Isolate.run`; nobody is waiting, so the transfer cost is free and the UI must not hitch (**CR-099**: `Isolate.run` is correct precisely where neither progress nor cancellation is wanted).
- Delete the snapshot on clean save and on clean exit. On startup, scan the recovery directory; any survivor produces *"RackMate closed unexpectedly. Recover Smith Residence (12 unsaved changes)?"* with Recover / Discard / Keep for later.
- **Recovery files are never auto-attached to a crash report (CR-096).** A recovery file is a complete project containing the client's name and site address. The crash dialog offers an explicit, default-off checkbox labelled *"This includes your client's name and site address."*

### 9.5 Close interception, recents, window state

`windowManager.setPreventClose(true)`, then a **three-button** dialog on close-while-dirty: Save / Don't Save / Cancel. Never two buttons. `Ctrl+N` and `Ctrl+O` run the same prompt and then replace the document, v1 is single-document, single-window (**CR-119**); tabs without a design are not a feature.

Recent files are a JSON list in application support (`{path, displayName, lastOpened}`), not `shared_preferences`, structured metadata is the wrong shape for prefs. Prune missing files **lazily**: a temporarily unmounted network drive must not evict the entry. Window size, position, monitor and maximised state persist in the same prefs file, with a minimum window size set (a rack editor below ~1000 px wide is unusable).

**Import hardening** applies to every import path: JSON depth and size limits, and, for the day a container arrives, zip-slip protection with entry-count and uncompressed-size caps. No evaluated program arrives in any file, which is now structurally true because rules are Dart functions rather than a shipped AST (**AC-011**).

---

## 10. Dependencies

### 10.1 The full table

| Package | Status | Constraint | Package it lives in | Purpose | Risk | Fallback |
|---|---|---|---|---|---|---|
| `meta` | `in use` | `^1.16.0` | core | `@internal` (the setter gate: AC-013), `@immutable`, `@useResult`. Zero runtime cost. | none | — |
| `collection` | `in use` | `^1.19.0` | core | `UnmodifiableSetView`, `firstWhereOrNull`, deep-equality helpers. | none | trivial to inline |
| `uuid` | `in use` | `^4.6.0` | core | **UUIDv7** entity IDs (time-ordered, sortable, index-local) and **v5** for deterministic port IDs (AC-006). | low | ~80 lines |
| `pdf` | `in use` | `^3.13.0` | text, export | `PdfGraphics` vector output, `pw.Widget` layout for schedules, `PdfFont.stringMetrics` for the one `TextMeasurer`. Pure Dart ⇒ isolate-safe; Apache-2.0. | **Highest-consequence dependency in the project.** Single maintainer, headline feature. | `DiagramCanvas` **is** the hedge: swapping backends is one file. Failing that: emit PDF 1.7 content streams for pure vector plus Type0 embedding (~2 k lines of well-specified work), or route through `SvgDiagramCanvas` to an external converter. |
| `flutter` | `in use` | sdk | ui, app | — | — | — |
| `path_drawing` | `in use` | `^1.0.1` | ui | `dashPath()`: `dart:ui` has no native dashing (§8.3). | low activity, but tiny | ~60 lines over `PathMetrics` |
| `vector_math` | `in use` | `^2.2.0` | ui | `Matrix4` for the viewport. Transitively available; pin it explicitly. | none | — |
| *(no file-dialog package)* | n/a | — | app | **Native open/save dialogs are ours.** `windows/runner/file_dialog_channel.cpp` drives `IFileDialog` directly (~150 lines of COM) behind a two-method Dart seam, `lib/src/session/file_picker.dart`. `file_selector ^1.1.0` USED TO BE THIS ROW AND WAS DELIBERATELY REMOVED: its Windows plugin calls `AddOptions` only for `select_folders` and `allow_multiple` and its Pigeon `SelectionOptions` has no other field, so `FOS_DONTADDTORECENT` cannot be requested through it at any price, and without that flag every open and every save writes the project's file name and full path into `HKCU\…\Explorer\ComDlg32\OpenSavePidlMRU` and drops a shortcut in `%APPDATA%\Microsoft\Windows\Recent`. It also dragged in `file_selector_android`, which shipped `dartjni.dll` into a Windows-only Release build. | ~150 lines of COM we maintain, and the flag closes only **half** the leak. The other half is stated as a BOUND and not as a list, because naming the measured keys and closing the list has been wrong four times running. Ours and gated: RackMate's own code writes no registry key. Measured against the shipped binary: `OpenSavePidlMRU` and the Recent shortcut are suppressed, so no project file name reaches the host. Beyond that, **the shell writes values under ComDlg32 that RackMate does not control**, at minimum `LastVisitedPidlMRU` (this executable plus the last folder browsed) and `CIDSizeMRU` (this executable, written even when the user cancels the dialog), measured examples and not an inventory, and no supported option prevents them while the shell common dialog is the dialog. So a portable build leaves shell-owned HKCU entries on a client's machine naming this executable and the folders it browsed, and never a project file name. | None wanted. Re-adding `file_selector` fails `session_layering_test.dart` RULE 14d, and `registry_claim_test.dart` fails if this row stops stating the bound, or restates it as a closed list. Suppressing the shell's own records as well would mean a hand-built file browser instead of `IFileDialog`, weighed and declined: large scope, worse dialog, internal tool. |
| `window_manager` | `in use` | `^0.5.2` | app | Title with dirty marker, size/position restore, minimum size, and critically `setPreventClose`. | 0.x, single maintainer | the only load-bearing API is `setPreventClose` + the close event: ~80 lines of Win32 platform channel. Do **not** plan on `bitsdojo_window` |
| `screen_retriever` | `in use` | `^0.2.0` | app | The display work-area list, which is what lets `validateRestoredBounds` answer "is this saved rectangle still on a monitor that is plugged in?". Without it the honest answer is always "cannot tell", every launch centres, and position restore does not exist. **NOT A FIFTH CHOICE**: it is `window_manager`'s own transitive dependency, named here only because the analyzer requires a direct declaration for a direct import (`depend_on_referenced_packages`), and it is already compiled into the runner as `screen_retriever_windows`. | inherits `window_manager`'s | none needed; it adds no native plugin and no binary weight |
| `path_provider_windows` | `in use` | `^2.3.0` | app | `getApplicationSupportPath()` for recovery, snapshots, recents, logs, prefs. Called from **exactly one function** (`productionApplicationSupportDirectory` in `lib/src/storage/data_root.dart`) and a grep test asserts that single call site, which is what keeps M2's portable build a one-function change. **The platform package directly, NOT the `path_provider` umbrella:** on Windows the umbrella forwards to precisely this class, so the resolved path is identical, but it also drags `path_provider_android` in, and that package pulls the `jni` FFI plugin, which put `dartjni.dll` in the Release output beside `rackmate.exe`. Dart-only, no native plugin, no extra DLL. | none | the umbrella, if a second desktop platform ever needs one; then re-check the Release output for `dartjni.dll` (`flutter_dependency_test.dart` asserts it is absent) |
| `path` | `in use` | `^1.9.0` | app | Cross-platform joining. Never string-concatenate paths on Windows. | none | — |
| `printing` | `planned (M6)` | `^5.15.0` | app | **Behind an explicit "Verify output" button only.** `PdfPreview`; `layoutPdf` is v1.1. | `PdfPreview`/`raster` need **pdfium**, which the plugin's CMake downloads at build time, a fresh or network-restricted machine fails `flutter build windows` | **Binaries are vendored into the repo (CR-100)**; a network-fetched binary in a signed release is a supply-chain and reproducibility problem, not just a CI one. Degrade to export + "Open in system viewer", which needs no pdfium |
| `desktop_drop` | `planned (unscheduled)` | `^0.6.0` | app | Drag a `.rmpj` onto the window. | 0.x, low activity | a nicety: degrade to File ▸ Open. Alternative `super_drag_and_drop` |
| `logging` | `planned (unscheduled)` | `^1.3.0` | app | Structured, level-based, zero-dependency. Sinks are ours. | none | — |
| `intl` | `planned (M7)` | `^0.20.0` | app | Number/date/unit formatting; the runtime half of ARB localization. | none | — |
| `flutter_localizations` | `planned (M7)` | sdk | app | Locale resolution, `MaterialLocalizations`, `Directionality`. | — | — |
| `test` | `in use` | `^1.26.0` | dev | Pure-Dart tests in core/text/export. | — | — |
| `flutter_test` | `in use` | sdk | dev | Widget and golden tests. | — | — |
| `integration_test` | `planned (unscheduled)` | sdk | dev | Desktop end-to-end tests: the file lifecycle, crash recovery, and the two error-surface cases nothing else catches (docs/11 §5). **Planned and not installed**: no `integration_test/` directory exists in `apps/rackmate`, and no milestone in docs/09 names this work. | the plan it belongs to is unscheduled, which is the risk | — |
| `very_good_analysis` | `in use` | `9.0.0` **exact** | dev | Strictest widely-used lint set: catches the `prefer_final` / `avoid_dynamic_calls` / unawaited-future classes that matter in a document editor. | third-party; a major bump can fail CI on unchanged code | pinned exactly, bumped deliberately. Fallback `flutter_lints ^6.0.0` |
| `leak_tracker_flutter_testing` | `in use` | `^3.0.0` | dev | Catches undisposed `TextPainter` / `ui.Picture` / `ChangeNotifier`. Given §7.3's native-resource caching, **not optional**. | — | — |
| `fake_async` | `in use` | `^1.3.3` | dev | Deterministic `Timer` control in `status_message_controller_test.dart`, so the auto-clear is tested without a real sleep. Already resolved transitively through `flutter_test`; declared directly per pub's "declare what you import". | none | `Future.delayed` and a slower suite |
| `benchmark_harness` | `planned (unscheduled)` | `^2.3.0` | dev | The perf-budget harness (docs/11 §6's commit-time budget). **Planned and not installed**: the shipped perf tests are op-count baselines in `schematic_perf_test.dart`, which need no harness, and no milestone in docs/09 names this work. | the plan it belongs to is unscheduled | the op-count baselines, which is what is actually in use |

Explicitly **not** used: any node-editor package (`vyuh_node_flow`, `fl_nodes`, `flutter_flow_chart`, `diagram_editor`, `graphview`), any spatial-index package, `undo`, `freezed`, `json_serializable`, `build_runner`, `InteractiveViewer`, `golden_toolkit`, `desktop_multi_window`, and **`flutter_riverpod`** or any other state-management package (**DR-088**; state management is constructor injection plus hand-rolled `Listenable`s, §4.1).

The node-editor rejection deserves its reason, because the best of them is genuinely good work: **RackMate is not a node graph.** Node editors model free-floating nodes in unconstrained 2D. RackMate's devices are constrained to integer RU indices in a fixed-width column, with a front/rear dimension no node editor has any concept of, and its "nodes" do not move in x at all. Adopting one means fighting its core layout assumption on every feature, and the canvas *is* the product, not a feature of it. Read their source for port-validation models and LOD thresholds; take the dependency on none of them.

### 10.2 Two version facts: the Flutter pin (resolved), Impeller (open)

**RESOLVED: the Flutter pin is `3.44.4`, and it lives in `azure-pipelines.yml`.**

The original item read: *the corpus contains two different Flutter stable versions, `design-architecture.md` targets 3.44.4, while the canvas research reports 3.41 as current. The CI Flutter version is pinned and load-bearing, because a minor bump routinely shifts antialiasing by a pixel and golden regeneration must be a deliberate, reviewed step of every upgrade. Resolve to one number and pin it.*

It is resolved to **3.44.4 stable**: that is what `design-architecture.md` targets and what the local toolchain runs (Dart 3.12.2, framework revision `ad70ec4617166f1c38e5d2bfd388af71fda14f06`, engine `a10d8ac38de835021c8d2f920dbf50a920ccc030`). The 3.41 figure was a research-date observation, not a second decision.

**Where the pin lives, and what enforces it:**

| | |
|---|---|
| The number | `flutterVersion: '3.44.4'` in `azure-pipelines.yml`, referenced by every step that needs it. One place. |
| The install | `tools/ci/ensure_flutter.ps1` fetches that exact stable archive, no channel, no version range, no marketplace task resolving on its own. |
| **The enforcement** | The same script then reads `flutter --version --machine` and **fails the build** if `frameworkVersion` is not exactly the pinned number, or the channel is not `stable`. A pipeline that *requests* a version and never checks what it got looks identical to one that works, right up until goldens flap. |
| The revision | `frameworkRevision` is recorded in `azure-pipelines.yml` and **warned about, not enforced**: there are no goldens for it to protect yet (docs/12 §4.3). **Promote it to a hard failure on the day the first golden lands**; the script says so at its call site. |

Two things this pin does **not** yet cover, stated so neither is mistaken for done:

- **There are no goldens.** The whole antialiasing argument above is an argument about a corpus that does not exist. The pin is standing guard over the right door in advance; it is not evidence that pixel regressions are caught.
- **`pubspec.lock` is gitignored**, so CI resolves the dependency graph fresh on every run. The Flutter SDK is pinned exactly and the package graph is not. Committing the lockfile is the fix and it is a project decision, not a CI one.

`VERIFY:` Impeller is not the default on Windows as of the research date; desktop still renders through Skia. Budget frame costs against Skia and re-benchmark when Impeller lands, the `saveLayer` and path-stroking numbers will shift meaningfully.

---

## 11. Performance budget

### 11.1 Scale targets

| Quantity | Target | Hard cap (degrade gracefully past this) |
|---|---|---|
| Racks per project | 4 | 12 |
| RU per rack | 45 | 60 (CR-038) |
| `DeviceInstance` | 200 | 500 |
| Ports (mostly unmaterialised: AC-006) | 2 000 | 6 000 |
| `Link` | 1 000 | 3 000 |
| Undo history | 200 entries | — |
| `.rmpj` file size | ~600 KB | 3 MB |
| Distinct text runs | ~10 000 | ~30 000 |

The file-size figure is the **corrected** one. The original 500 KB budget was 3–6× optimistic because it materialised every port as a document entity with its own `EntityMeta` (~450–500 B each pretty-printed, so ~1 MB for ports alone at target). Lazy port materialisation plus `EntityMeta` off sub-objects (**AC-006**, **CR-095**) is what makes the plain-JSON decision survive its own arithmetic.

### 11.2 Time budgets

Targets are p95 at the scale targets on a mid-range 2022 laptop.

| Operation | Budget | Measured by |
|---|---|---|
| Idle frame | UI ≤ 2 ms, raster ≤ 4 ms | DevTools timeline, `--profile` |
| Pan / zoom frame | UI ≤ 3 ms, raster ≤ 8 ms | DevTools timeline |
| Device-drag frame | UI ≤ 4 ms, raster ≤ 8 ms; **zero** device/settled-run repaints | `debugRepaintRainbowEnabled` + timeline |
| **Commit a transaction** (mutate + invalidate + relayout + revalidate + repaint) | **≤ 16 ms**, with ≤ 8 ms for the non-paint terms | `benchmark_harness` + widget-test timing |
| Undo / redo step | ≤ 4 ms | core benchmark |
| Full layout, cold, 300 links | ≤ 40 ms | core benchmark |
| Label-layer build, 300 links in `netLabels` mode | ≤ 4 ms | core benchmark on a real 300-link fixture |
| Full DRC sweep (isolate) | ≤ 150 ms, UI never hitches | isolate timing + timeline |
| File load → first paint | ≤ 400 ms | integration test `Stopwatch` |
| Explicit save (atomic, in isolate) | ≤ 150 ms | integration test |
| Autosave | UI hitch ≤ 4 ms | timeline |
| PDF export, full sheet set | ≤ 2.5 s wall clock, UI never blocks > 16 ms | export benchmark |
| Cold start → empty document | ≤ 1.2 s | `--trace-startup` |
| Peak RSS | ≤ 350 MB | DevTools memory |

The commit budget is **16 ms, not 8** (**AC-008**). The original 8 ms counted one stroked polyline per run; the real wire layer is ~8–10 ops per run, so a naive rebuild is 10–25 ms of Dart-side command construction, not 4 ms. Per-domain sub-pictures plus a separate pill picture bring a typical edit back inside one frame. Nothing about the product requires sub-frame commits, and re-baselining honestly is better than a budget everyone quietly ignores.

### 11.3 How each is measured

1. **`benchmark_harness` over synthetic documents at 50 / 200 / 500 devices**, pure Dart, headless in CI under the `perf` tag. The CI signal is **op count per layer**, not wall time, op count is stable across runners and wall time is not. Thresholds are **warn-only for the first three months**: establish the baseline curve on CI hardware before it can fail a build, or that time goes to chasing runner variance instead of writing the app.
2. **DevTools timeline in `--profile`**, driven by a scripted 30-second pan/zoom/drag `integration_test`, asserting on `frame_build_times` and `frame_rasterizer_times` p95 from `TimelineSummary`. On demand, not per-PR, desktop CI runners have no GPU worth trusting.
3. **A three-item manual pre-release checklist**, each catching a class nothing automated will: `debugRepaintRainbowEnabled` (only the overlay may flicker during a drag), `checkerboardOffscreenLayers` (must be zero, any `saveLayer` is a bug), and dragging the window between a 4K and a 1080p monitor (mixed-DPI breaks naive viewports, and Windows users genuinely run this).

The arithmetic that justifies the architecture: 1000 runs × ~4 µs per stroked polyline ≈ 4 ms of raster, a quarter of the frame for runs *alone*, if drawn naively every frame. That is why L3a is cached and split by domain, and why the drag path re-records only the ~8 active runs. And `saveLayer` at ~1 ms means three of them cost more than the entire wire layer, which is where the zero-`saveLayer` rule comes from.

---

## 12. Error handling, logging, diagnostics

### 12.1 Two categories, two mechanisms

**Expected outcomes are values, not exceptions**: file not found, corrupt document, newer schema, permission denied, target PDF locked by another application:

```dart
sealed class Outcome<T> { const Outcome(); }
final class Ok<T>  extends Outcome<T> { final T value; final bool openReadOnly; }
final class Err<T> extends Outcome<T> { final AppError error; }

sealed class AppError {
  String get userMessageKey;    // localized, actionable, no jargon
  String get diagnosticDetail;  // for the log; may be technical
  bool   get isRecoverable;
}
```

Every `AppError` carries a message that says **what to do next**: *"This file was created by a newer version of RackMate. Update RackMate, or open it read-only."*, not a stack trace. There is one error-message catalogue with one voice (**AC-058/D1**).

**Programmer errors throw.** Broken invariants, unreachable switch arms and null entity lookups are bugs: loud in debug, captured in release.

### 12.2 Global capture

```dart
void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    FlutterError.onError = (d) {
      Log.root.severe('flutter', d.exception, d.stack);
      if (kDebugMode) FlutterError.presentError(d);
      CrashReporter.record(d.exception, d.stack);
    };
    PlatformDispatcher.instance.onError = (e, st) {
      Log.root.severe('platform', e, st);
      CrashReporter.record(e, st);
      return true;                                  // handled; do not kill the isolate
    };
    ErrorWidget.builder = (d) => RackMateErrorPane(d);   // never a red-and-yellow box

    final services = await bootstrap();          // the composition root (§4.2)
    runApp(RackMateApp(services: services, shellKey: GlobalKey<AppShellState>()));
  }, (e, st) { Log.root.shout('zone', e, st); CrashReporter.record(e, st); });
}
```

`ErrorWidget.builder` matters more on desktop than mobile: a red error box in a pane of a professional tool destroys credibility. Replace it with a neutral panel offering "Copy diagnostics" and "Save a recovery copy".

### 12.3 Transaction rollback and stack poisoning

The most dangerous failure mode is a command that throws *halfway through* `apply`, leaving the document in a state the undo stack cannot describe.

```dart
void _rollback(_TxnBuilder b, Object e, StackTrace st) {
  Log.root.severe('command failed mid-transaction: ${b.label.name}', e, st);
  try {
    for (var i = b.children.length - 1; i >= 0; i--) b.children[i].revert(doc);
    selection.restore(b.selectionBefore);
    epochs.bump(EpochMask.all);
  } catch (e2, st2) {
    Log.root.shout('ROLLBACK FAILED — poisoning undo stack', e2, st2);
    undo.poison();                    // canUndo/canRedo → false
    _forceRecoverySnapshot();         // write it out before anything else touches it
    _notifyUnrecoverable();           // "Save a copy and restart RackMate."
  }
}
```

Poisoning the stack rather than pretending is the honest behaviour: a user who keeps undoing through a corrupted history destroys their work silently.

### 12.4 Logging and redaction

`package:logging` with two sinks: a **rotating file** in `getApplicationSupportDirectory()/logs/` (5 × 2 MB, `INFO`+ in release, `FINE` in debug, rotation is ~40 lines of ours, not a framework), and an **in-memory ring buffer** of the last 2 000 records backing Help ▸ **Copy Diagnostics**.

**Redaction policy, enforced by convention and a lint-style test:** log entity **UUIDs**, never device names, client names, project addresses, or file paths above `FINE`. A rack drawing for a private residence contains the client's name and address, and those must not reach a log the user pastes into a public tracker. The diagnostics bundle carries app/Flutter/OS versions, document **statistics** (device count, link count, schema version), the last 200 records, and the current epoch/`sequence` values, **never document content** (**CR-096**).

### 12.5 Crash reporting: local-first, opt-in

**No telemetry by default.** This is a locally installed professional tool handling client project data; silent network egress is a trust violation and, for some commercial clients, a contractual one. On an uncaught error, write a redacted `crashes/<timestamp>.json` to application support. On next launch, if crash files exist, offer **View report** (the exact JSON, no hidden payload), **Send**, and **Never ask again**. Only on opt-in does anything leave the machine, and then to a self-hosted Sentry, deliberately **not a v1 dependency**, because until there is somewhere to send reports it is dead weight and an extra native surface per platform. Attaching the project file is a separate, default-off checkbox with an explicit label (**CR-096**).

---

## 13. Platform: Windows first, macOS ready

### 13.1 Windows

| Concern | Decision |
|---|---|
| **Menus** | Material **`MenuBar`**. `PlatformMenuBar` is macOS-only out of the box; there is no native Win32 menu bar in Flutter and that plugin ecosystem is unmaintained. The visual difference is negligible in a themed pro tool. |
| **Menu as data** | One tree of `AppMenuItem{labelKey, shortcut, intent, enabled, checked}`. Every item dispatches an `Intent` through `Actions`, so the menu item, the shortcut, the toolbar button and the context menu funnel to **one** `Action` with **one** enablement rule. This is also what makes the macOS port cheap. |
| **Keymap** | ~40 bindings generated from the single `Intent` registry into `build/keymap.md` at build time; the arbitrated bindings are ruled in [canon §1.10](canonical-decisions.md#110-interaction) (**CR-101**). The corpus had ~170 bindings with ~18 collisions and no arbitration; `Ctrl+P` is the export dialog everywhere. |
| **DPI** | Users run 125%/150% scaling and mixed-DPI multi-monitor. All canvas geometry is in document units with an explicit zoom transform, never in logical pixels. The 4K↔1080p window drag is a named pre-release check. |
| **Canvas text entry** | **No inline canvas editing in v1.** Names are edited in the inspector with a real `TextField`. IME positioning, context menus and selection over a `CustomPaint` are the classic Flutter desktop pain point, and CAD tools do it in a panel anyway. |
| **Input** | `Listener` for wheel and precision mouse work (the gesture arena adds disambiguation delay); recognizers for trackpad and touch. `PointerScrollEvent` pans, `Ctrl+scroll` zooms at the cursor, `PointerScaleEvent` handles trackpad pinch. All of it enters through `CanvasIntent`, and no editor logic branches on `PointerDeviceKind` (**AC-016/#23**). |
| **Multi-window** | Not shipping. Canonical's work has no committed version. The model is already correct in-process because **one `DocumentSession` owns one `DocumentController`** and nothing reaches a document except through it (DR-088 §11.87.4 supersedes the `ProviderScope` reason previously given here). Do **not** use `desktop_multi_window`, each window is a separate engine with no shared memory, which is fatal for a shared document. |
| **Code signing** | Certificate procurement starts **two milestones early** (**AC-058/D10**), with vendored pdfium and symbol archival in the release pipeline. |

### 13.2 macOS

macOS is a v1 target only if [§10.10 of the decision record](10-decisions.md) resolves that way; the architecture keeps it a port rather than a project. What that costs today: `PlatformMenuBar` behind the same menu-as-data tree; `SingleActivator` built through a platform meta/ctrl helper so `Cmd` is not hard-coded; and the knowledge that `MenuAcceleratorLabel` (Alt+F style) works on Windows and Linux and is unsupported on macOS. Goldens run on **Linux only** with a pinned Flutter version and bundled fonts registered in `flutter_test_config.dart`; per-platform golden sets collapse under maintenance cost within months.

### 13.3 Units, theme and i18n plumbing

**Storage is always integer nanometres and micrograms; display units are never stored.** `ProjectSettings.displayUnits` is authoritative when set, with the app preference supplying the value for *new* projects and a per-session toggle that does not modify the document or mark it dirty (**CR-097**). The deciding case is real: a US-spec commercial job opened on a German integrator's laptop must still read in inches.

Theme is a UI preference and is **never persisted in the document**. Light is the first-run default and dark is one click away (**CR-076**), the moment that decides whether a user trusts the tool is comparing the screen to the printed sheet, and that comparison must succeed on first run. **The screen theme never affects the export** (**CR-077**): export palette is an explicit `ExportSpec.palette: colour | greyscale | cmyk`, never inherited from the UI.

All user-facing strings go through `AppLocalizations` from the first commit with one locale, `l10n.yaml` in CI, and localisable registry display names. Command labels are the interesting case: they live in `rackmate_core`, which cannot import Flutter, so commands expose a **`LabelKey` enum plus arguments** and `rackmate_ui` maps key → localized string. The Edit menu shows a localized *"Undo Move device"*; the log shows the stable enum name. Retrofitting this across a mature app is a multi-week grind that never quite finishes; the incremental cost per string today is about fifteen seconds.

Explicit non-goal: **the canvas stays LTR under an RTL locale.** Electrical schematics are LTR by universal convention and mirroring a rack elevation would be actively wrong. Say so in the code so nobody "fixes" it.

---

## 14. Build order

Reconciled from the two conflicting orders in the corpus (**CR-120**). The five PDF API spikes plus the sixth for `PdfTtfFont` main-isolate metrics cost about a day and de-risk the largest single dependency in the project, so they run in **week one**; the export *feature* stays late.

1. **Reconciliation**: this document set. Not compressible into the first coding milestone: CR-001, CR-008, CR-017, CR-051, CR-081 and CR-083 each cost a rewrite of everything downstream if guessed wrong.
2. **The six API spikes**, including `PdfTtfFont` cold-start cost against the 1.2 s budget.
3. **`units/` + `Pt`/`Box`**, with the two discriminating tests written **before any other code**: exact 1/32-in clearance, and zero accumulated error across a 45U stack (**AC-001**).
4. **`.rmpj` envelope + hand-written codec + migration harness + the first golden fixture + the byte-round-trip test.** The format is the durable asset.
5. **`Command` / `Transaction` / `UndoStack` / `DocumentController`**, with `@internal` setters, the apply∘revert property test, and the epoch-mask coverage test. Retrofitting undo is the single most painful refactor available.
6. **`DiagramCanvas` + `TextMeasurer` + `DiagramScene` + both backends + the baseline-Y parity test, together and early.** If parity does not hold, stop, every hour spent on layout before parity is an hour that may need redoing.
7. **`CanvasIntent`, `ViewportController`, wheel/trackpad input, grid painter.** Pan and zoom must feel right before anything sits on them.
8. `RenderRackCanvas` + device `RenderBox` children replaying scene fragments + RU snapping.
9. Ports, links, the snap cascade, Sugiyama phases 0–3 plus the orthogonal trace.
10. Derived pipeline: totals, occupancy, incremental DRC, the shared schedule function.
11. Menus, shortcuts, marquee, context menus, the outline tree.
12. PDF export: sheets, furniture, title and revision blocks, pagination.
13. Autosave, recovery, recents, close interception.
14. Device Builder and the seeded catalog.

Steps 5 and 6 are the two "do it now or pay 10× later" items. Everything else can be reordered by product priority. Milestone sizing and exit criteria are in [Roadmap](09-roadmap.md); testing strategy in [Testing and quality](11-testing-and-quality.md).

---

## 15. Open `VERIFY:` items carried forward

Collected so none is lost in prose. Each is an API or environment claim the design leans on and that has not been executed against the live SDK.

| # | Claim to verify | Where it bites |
|---|---|---|
| 1 | `FontFeature.disable('kern')` **and** `disable('liga')` are the only route to matching PDF metrics; there is no first-class API | §8.2: screen/print text parity |
| 2 | `PdfTtfFont` requires a `PdfDocument` to construct, forcing a throwaway document for metrics; measure the parse cost of three families | §8.2, cold-start budget |
| 3 | `Printing.layoutPdf` on Windows does not itself require the fetched pdfium | CR-100: whether the OS print dialog can ship at all |
| 4 | `path_drawing.dashPath` cost under repeated re-synthesis; profile rather than assume the cache absorbs it | §8.3, frame budget |
| ~~5~~ | ~~Riverpod 3.3.2 `legacy` demotion of `ChangeNotifierProvider`~~, **MOOT: DR-088.** There is no Riverpod dependency and no adapter to write. **This row is the reason the `VERIFY:` mechanism is not a tripwire**: it was conditioned on "before the provider layer is written", the layer was never written, and the check therefore never fired while §4 went on describing it. The remedy is §10.1's status column and its gate, which assert a claim instead of scheduling a look | §4.2: superseded |
| ~~6~~ | ~~The pinned Flutter stable version (3.44.4 vs 3.41 in the corpus)~~, **RESOLVED: 3.44.4.** Pinned in `azure-pipelines.yml` and *enforced* by `tools/ci/ensure_flutter.ps1`, which measures `flutter --version --machine` and fails the build on any other version. See §10.2 | §10.2: goldens do not survive Flutter bumps |
| 7 | Impeller default status on Windows | §11: all raster budgets are Skia numbers |
| 8 | **Label-layer commit cost** on a real 300-link fixture (text-run count and commit time in `netLabels` mode, which is now the dominant term | §6.2) DR-001 makes labels, not wires, the commit-path budget |

See also: [Overview](00-overview.md) · [Domain](01-domain.md) · [Data model](02-data-model.md) · [Rack editor](04-rack-editor.md) · [Schematic editor](05-schematic-editor.md) · [Device builder](06-device-builder.md) · [Structure device](07-structure-device.md) · [PDF export](08-pdf-export.md) · [Decisions](10-decisions.md) · [Testing and quality](11-testing-and-quality.md)
