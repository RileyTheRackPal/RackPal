# RackMate: Software Architecture

**Target:** Dart 3.12.2 / Flutter 3.44.4 stable, Windows-first desktop.
**Repo:** `C:\Users\riley\Documents\Projects\Vibecoding\RackMate` (currently empty except `.editorconfig`, `.gitattributes`, `.gitignore`, `docs/`).

---

## 0. The five decisions everything else follows from

Stated up front so the rest of the document can reference them.

| # | Decision | Consequence |
|---|---|---|
| **D1** | **Monorepo, 3 pure-Dart packages + 1 Flutter app**, joined by pub workspaces. `rackmate_core` must not import `dart:ui` or `package:flutter`. | Model, undo, routing, validation, and the scene builder all test in `dart test` in <1s, and run inside a background isolate for PDF export. |
| **D2** | **One mutable document aggregate, mutated only through `Command`s.** No immutable-tree + `copyWith`. Change detection by **epoch counters**, not equality. | Undo is free and exact; repaint invalidation is exact; no deep-copy churn on drag. |
| **D3** | **Geometry stored as `int` in hundredths of a millimetre (10 µm).** Never `double`, never device pixels. | 1U = **4445** exactly, 19″ rail = **48260** exactly. No float drift in the file format, clean diffs, sync-safe. *(Note: tenths-of-mm, a plausible first choice, is **not** exact: 44.45 mm = 444.5 tenths. Use hundredths.)* |
| **D4** | **A display list (`DiagramScene`) is the single drawing IR.** Screen and PDF are two interpreters of it. | Screen and print cannot diverge. Also gives hit-test regions, bounds for scale-to-fit, and a deterministic golden-test artifact for free. |
| **D5** | **Pointer drags never touch the document.** Ephemeral drag state lives in an overlay-only `Listenable`; `onPointerUp` emits exactly one `Command`. | 60 fps during drag with zero document-layer repaints, and one undo entry per gesture without any coalescing logic. |

---

## 1. Package / module structure

### 1.1 The choice: monorepo, four packages

**Not a single Flutter app.** Three concrete forcing functions make the split pay for itself immediately, not speculatively:

1. **PDF export must run in a background isolate.** A background isolate has no `rootBundle`, no plugins, no `BuildContext`, and critically, code that touches `dart:ui` types drags in Flutter binding assumptions. The scene builder therefore *must* be free of `dart:ui`. A package boundary is the only way to enforce that mechanically; a folder convention will be violated within a month by an `Offset` that "was just easier."
2. **Test-loop economics.** The wire router, the DRC, the migration chain, and the command apply/revert property tests are where the bugs live and where you will iterate hundreds of times. `dart test` on a pure package is ~600 ms cold. `flutter test` on an app is 8–20 s. Over a multi-year project this difference is measured in days.
3. **The `pdf` package is a single-maintainer dependency on a headline feature.** Isolating it behind `rackmate_export` + the `DiagramCanvas` interface means replacing it is one package, not a rewrite.

**Not two packages either** (core + app). Putting `package:pdf` into `rackmate_core` re-pollutes the dependency-light core and makes `dart pub get` on the fast test package pull the PDF toolchain. And putting Flutter painters in the app blocks reuse by the future read-only mobile shell.

**Not melos.** Dart 3.6+ pub workspaces do the resolution; melos adds orchestration you don't need at four packages. Add it when you exceed ~6 packages or start publishing.

### 1.2 Directory tree

```
RackMate/
├─ pubspec.yaml                          # workspace root: `workspace: [packages/*, apps/*]`
├─ analysis_options.yaml                 # shared lint baseline, inherited by all members
├─ dart_test.yaml                        # test tag definitions (golden, slow, perf)
├─ .github/workflows/ci.yaml             # analyze+test matrix; goldens Linux-only
├─ docs/
│  ├─ architecture.md                    # this document
│  ├─ file-format.md                     # THE durable spec: .rackmate v1 wire format
│  └─ adr/0001-mutable-doc-command-stack.md   # one ADR per D1..D5 decision
│
├─ packages/
│  ├─ rackmate_core/                     # ══ PURE DART. no flutter, no dart:ui, no pdf ══
│  │  ├─ lib/rackmate_core.dart          #   the only public export barrel
│  │  ├─ lib/src/
│  │  │  ├─ units/
│  │  │  │  ├─ length.dart               #   Cmm (int extension type), Ru, unit conversions
│  │  │  │  └─ geom.dart                 #   Pt, Box, Ln — 10-line value types, no dart:ui
│  │  │  ├─ model/
│  │  │  │  ├─ ids.dart                  #   EntityId (extension type over String), UUIDv7 gen
│  │  │  │  ├─ document.dart             #   RackDocument: the mutable aggregate + epochs
│  │  │  │  ├─ rack.dart                 #   Rack: ruCount, name, depth, front/rear faces
│  │  │  │  ├─ device.dart               #   RackDevice: placement, heightU, template ref
│  │  │  │  ├─ port.dart                 #   Port: connector, direction, face, label, index
│  │  │  │  ├─ connection.dart           #   Connection: fromPort, toPort, cableType, length
│  │  │  │  ├─ structure.dart            #   StructureDevice: building home-runs (req #6)
│  │  │  │  ├─ connector_type.dart       #   sealed: RCA, HDMI, RJ45, XLR, IEC, F, TOSLINK…
│  │  │  │  ├─ cable_type.dart           #   sealed + unknown(raw) escape variant
│  │  │  │  └─ template.dart             #   DeviceTemplate: the device-builder output
│  │  │  ├─ commands/
│  │  │  │  ├─ command.dart              #   Command, EpochMask, mergeKey contract
│  │  │  │  ├─ transaction.dart          #   composite + selection capture
│  │  │  │  ├─ undo_stack.dart           #   linear undo, coalescing, cap
│  │  │  │  ├─ device_commands.dart      #   Add/Remove/Move/Resize/Retemplate
│  │  │  │  ├─ wire_commands.dart        #   Connect/Disconnect/ChangeCableType/SetWaypoints
│  │  │  │  └─ snapshot_command.dart     #   escape hatch for bulk ops (§4.6)
│  │  │  ├─ document_controller.dart     #   the ONLY mutation entry point; owns UndoStack
│  │  │  ├─ derived/
│  │  │  │  ├─ derivation.dart           #   Derived<T>: epoch-keyed memo cell
│  │  │  │  ├─ occupancy.dart            #   RU occupancy map, collision detection
│  │  │  │  ├─ validation.dart           #   DRC rules + IncrementalValidator
│  │  │  │  ├─ totals.dart               #   power draw, heat, weight, RU free, port counts
│  │  │  │  └─ schedule.dart             #   wiring schedule rows (shared: UI table + PDF)
│  │  │  ├─ routing/
│  │  │  │  ├─ router.dart               #   orthogonal trace router, obstacle-aware
│  │  │  │  ├─ route_cache.dart          #   per-connection incremental reroute
│  │  │  │  └─ bus.dart                  #   bundling parallel same-type runs into a bus
│  │  │  ├─ draw/                        #   ══ D4: the drawing IR ══
│  │  │  │  ├─ diagram_canvas.dart       #   abstract interface DiagramCanvas
│  │  │  │  ├─ ops.dart                  #   sealed DiagramOp; DiagramScene {ops,bounds,hits}
│  │  │  │  ├─ spec.dart                 #   StrokeSpec, FillSpec, TextSpec, FontRef
│  │  │  │  ├─ symbols.dart              #   connector glyphs as SVG 'd' path strings
│  │  │  │  ├─ palette.dart              #   CablePalette: screen + print variants
│  │  │  │  └─ scene/
│  │  │  │     ├─ scene_builder.dart     #   RackDocument -> DiagramScene, per layer
│  │  │  │     ├─ rack_layer.dart        #   rails, RU ruler, chassis
│  │  │  │     ├─ device_layer.dart      #   faceplates, ports, ref-designators
│  │  │  │     └─ wire_layer.dart        #   routed traces, junction dots, net labels
│  │  │  ├─ persistence/
│  │  │  │  ├─ codec.dart                #   abstract DocumentCodec (json now, zip later)
│  │  │  │  ├─ json_codec.dart           #   hand-written to/fromJson (§7)
│  │  │  │  ├─ schema.dart               #   kSchemaVersion, kMinReaderVersion, magic key
│  │  │  │  └─ migrations.dart           #   append-only Map<int, Migration>, frozen once shipped
│  │  │  ├─ catalog/
│  │  │  │  └─ starter_catalog.dart      #   loads/validates the seeded ~40 templates
│  │  │  └─ util/result.dart             #   sealed Outcome<T> — no exceptions for user errors
│  │  ├─ assets/catalog/starter_v1.json  #   the seeded generic device catalog
│  │  └─ test/
│  │     ├─ fixtures/v1_minimal.rackmate #   golden corpus, one per shipped schema version
│  │     ├─ migration_corpus_test.dart   #   HIGHEST-VALUE TEST IN THE REPO (§9.1)
│  │     ├─ command_roundtrip_test.dart  #   property: apply∘revert == identity
│  │     ├─ router_test.dart
│  │     ├─ scene_golden_test.dart       #   display-list text dumps (§9.3)
│  │     └─ no_flutter_import_test.dart  #   enforces D1 mechanically (§2.4)
│  │
│  ├─ rackmate_export/                   # ══ PURE DART. core + package:pdf. isolate-safe ══
│  │  ├─ lib/src/
│  │  │  ├─ pdf_diagram_canvas.dart      #   DiagramCanvas -> PdfGraphics (Y-flip, state cache)
│  │  │  ├─ sheets.dart                  #   ANSI A/B/C/D, ARCH B/C/D, ISO A3/A2 formats
│  │  │  ├─ title_block.dart             #   border, zone grid, title + revision blocks
│  │  │  ├─ schedule_table.dart          #   pw.TableHelper wiring, explicit columnWidths
│  │  │  ├─ sheet_plan.dart              #   net-partitioning + geometric tiling + match lines
│  │  │  ├─ export_request.dart          #   sendable payload: doc JSON + font bytes + options
│  │  │  └─ build_document.dart          #   top-level fn; the Isolate.run entry point
│  │  └─ test/pdf_structure_test.dart
│  │
│  └─ rackmate_ui/                       # ══ FLUTTER. widgets, painters, theme. NO app shell ══
│     ├─ lib/src/
│     │  ├─ theme/
│     │  │  ├─ rackmate_theme.dart       #   ThemeExtension<RackMateTheme>
│     │  │  └─ palette_adapter.dart      #   core Palette -> ui.Color
│     │  ├─ canvas/
│     │  │  ├─ flutter_diagram_canvas.dart   # DiagramCanvas -> ui.Canvas (dash synthesis)
│     │  │  ├─ render_rack_canvas.dart   #   MultiChildRenderObjectWidget + RenderBox (§6.2)
│     │  │  ├─ layer_cache.dart          #   ui.Picture memo keyed by epoch tuple
│     │  │  ├─ label_cache.dart          #   LRU TextPainter cache, quantised scale ladder
│     │  │  ├─ viewport_controller.dart  #   Matrix4 + cached inverse, zoom-at-cursor
│     │  │  ├─ interaction_controller.dart  # D5: ephemeral drag/marquee/live-wire state
│     │  │  ├─ input/
│     │  │  │  ├─ pointer_router.dart    #   Listener: wheel/trackpad/buttons
│     │  │  │  ├─ hit_tester.dart        #   scene-space nearest-hit, spatial hash
│     │  │  │  └─ snap.dart              #   the snap priority cascade
│     │  │  └─ overlay_painter.dart      #   selection, marquee, guides, in-flight wire
│     │  ├─ inspector/                   #   property panel widgets (real TextFields)
│     │  ├─ device_builder/              #   the GUI template editor
│     │  ├─ schedule/                    #   the accessible DataTable view of the netlist
│     │  └─ l10n/                        #   app_en.arb + generated AppLocalizations
│     └─ test/goldens/
│
└─ apps/
   └─ rackmate/                          # ══ FLUTTER DESKTOP SHELL ══
      ├─ lib/
      │  ├─ main.dart                    #   runZonedGuarded, error hooks, window setup
      │  ├─ providers/                   #   Riverpod: the ONLY place providers are declared
      │  │  ├─ document_scope.dart       #   documentControllerProvider (per ProviderScope)
      │  │  ├─ derived_providers.dart    #   chrome-facing read models (title, dirty, totals)
      │  │  └─ services.dart             #   file service, recents, prefs, logger DI
      │  ├─ shell/
      │  │  ├─ app_menu.dart             #   menu-as-data -> MenuBar (Win) / PlatformMenuBar (mac)
      │  │  ├─ intents.dart              #   every Intent type in one file
      │  │  ├─ actions.dart              #   Intent -> Action bindings; enablement rules
      │  │  └─ shortcuts.dart            #   SingleActivator map, platform meta/ctrl helper
      │  ├─ files/
      │  │  ├─ document_file_service.dart   # open/save/save-as, atomic temp+rename
      │  │  ├─ autosave_service.dart     #   30 s + on-blur recovery snapshots
      │  │  ├─ recovery_service.dart     #   startup scan + "recover?" prompt
      │  │  └─ recent_files.dart         #   JSON list in app-support, lazy pruning
      │  ├─ export/export_service.dart   #   font preload on main isolate -> Isolate.run
      │  └─ diagnostics/
      │     ├─ log.dart                  #   `logging` -> rotating file + in-memory ring
      │     └─ crash_reporter.dart       #   local crash file + "copy diagnostics" bundle
      ├─ assets/fonts/                   #   Inter-Regular/SemiBold, JetBrainsMono (§12.3)
      ├─ integration_test/
      └─ windows/ macos/ linux/
```

---

## 2. Layering and the dependency rule

### 2.1 The four layers

| Layer | Lives in | Contains |
|---|---|---|
| **Domain** | `rackmate_core/src/{units,model,routing,derived,draw}` | Entities, value objects, invariants, the wire router, DRC rules, the scene builder. Knows nothing about files, PDFs, pixels, or Flutter. |
| **Application** | `rackmate_core/src/{commands,document_controller}` | `Command`, `Transaction`, `UndoStack`, `DocumentController`. Every state transition the product supports is a class here. This is the app's *verb list*. |
| **Infrastructure** | `rackmate_core/src/persistence`, all of `rackmate_export`, `apps/rackmate/lib/{files,export,diagnostics}` | Codecs, migrations, PDF emission, disk I/O, isolates, logging, OS dialogs. |
| **Presentation** | all of `rackmate_ui`, `apps/rackmate/lib/{providers,shell}` | Widgets, painters, render objects, viewport, input, Riverpod wiring, menus. |

### 2.2 The dependency rule, stated explicitly

> **Dependencies point inward and downward only. Domain depends on nothing. Application depends only on Domain. Infrastructure depends on Domain and Application. Presentation depends on all three. No layer may name a type from a layer above it, and no layer may name a type from a sibling infrastructure module.**

Concretely, the permitted import edges:

```
rackmate_core        →  (dart:core, dart:math, dart:convert, meta, collection, uuid)
rackmate_export      →  rackmate_core, package:pdf
rackmate_ui          →  rackmate_core, flutter
apps/rackmate        →  rackmate_core, rackmate_export, rackmate_ui, flutter, plugins
```

Note `rackmate_export` and `rackmate_ui` are **siblings that cannot see each other**. That is deliberate: it is what guarantees the PDF path is isolate-safe, because there is no compile path from the export code to `dart:ui`.

### 2.3 Three rules that carry most of the weight

1. **`rackmate_core` must not import `package:flutter` or `dart:ui`**: not for `Offset`, not for `Color`, not for `Rect`. Define `Pt`, `Box`, and store colours as `int` ARGB. Adapters live in `rackmate_ui`.
2. **The document is mutated only via `DocumentController.run(Command)`.** No widget, service, or painter ever calls a setter on a `RackDevice`. Enforced by making entity fields private with library-private setters (`part of` the commands library), Dart's library privacy is the right tool here.
3. **Nothing in Domain or Application may be `async`.** The document is a synchronous, single-threaded data structure. All `Future`s live in Infrastructure and Presentation. This eliminates an entire class of interleaved-mutation bugs and makes every core test synchronous.

### 2.4 Mechanical enforcement

Two cheap guards, both dependency-free:

```dart
// packages/rackmate_core/test/no_flutter_import_test.dart
void main() {
  test('rackmate_core is Flutter-free', () {
    final banned = RegExp(r'''import\s+['"](package:flutter/|dart:ui|package:pdf/)''');
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()
                    .where((f) => f.path.endsWith('.dart'))) {
      final hit = banned.firstMatch(f.readAsStringSync());
      expect(hit, isNull, reason: '${f.path} imports ${hit?.group(1)}');
    }
  });
}
```

Plus: `rackmate_core`'s pubspec declares `environment: {sdk: ^3.12.0}` with **no `flutter:` key at all**, so a stray Flutter import is also a hard compile error under `dart test`. Belt and braces, the pubspec catches it at build, the test catches it in review with a readable message.

---

## 3. State management

### 3.1 The firm choice

> **Riverpod 3.x, codegen-free, used strictly as a DI and lifetime container. The document is *not* in Riverpod. It lives in a plain-Dart `DocumentController` owned by a provider.**

**Reasoning.** A rack document is one large, long-lived, mutable object graph, ~200 devices, ~2000 ports, ~1000 connections, ~500 KB of JSON. Every general-purpose Flutter state solution (Bloc, `Notifier<T>`, signals) is built on *replace the state object to signal change*. That premise is wrong here twice over: replacing a 500 KB graph on every pointer-adjacent event is pure waste, and more importantly a whole-object replacement carries no information about *what* changed, which is exactly the information the repaint system needs.

Riverpod still earns its place for four things it is genuinely best-in-class at, none of which is holding the document:

- **Scoped lifetime.** One `ProviderScope` per open document gives multi-document (and later multi-window) correctness for free, with automatic disposal.
- **DI without service locators.** `FileService`, `Logger`, `RecentFiles`, clock, and UUID generator are all overridable in tests via `ProviderScope(overrides:)`.
- **Cheap chrome read-models.** Window title, dirty dot, `Undo`/`Redo` menu enablement, totals panel, validation-issue count. These rebuild rarely and `ref.watch(p.select(...))` is exactly right.
- **Ecosystem stability.** Flutter Favorite, one maintainer with a decade of track record, huge install base.

**Why not `signals`.** Its selling point is automatic fine-grained tracking of *widget* rebuilds. The canvas hot path deliberately bypasses widget rebuilds entirely (§3.6), so you'd take real ecosystem risk for a benefit already engineered around.

**Why not Bloc.** Event-sourcing a canvas means an event object per interaction tick. Its genuinely good idea (an explicit, replayable event log), you are building by hand as the command stack, with better ergonomics (labels for the Edit menu, inversion for undo).

**Codegen-free**, per D-consistency with §8: the project ships **zero `build_runner`**. Riverpod 3 makes codegen optional; use plain `NotifierProvider` / `Provider`.

### 3.2 Ownership map

```
ProviderScope                                    ← one per open document
└── documentControllerProvider : DocumentController          [plain Dart, in core]
    ├── RackDocument doc                         mutable aggregate; flat Map<EntityId,…>
    ├── UndoStack undo
    ├── DocEpochs epochs                         ValueNotifier<int> × 5   ← repaint triggers
    └── DerivedRegistry derived                  epoch-keyed memo cells

└── selectionControllerProvider  : SelectionController   ChangeNotifier, NOT document state
└── viewportControllerProvider   : ViewportController    ChangeNotifier, Matrix4 + inv cache
└── toolModeProvider             : NotifierProvider<ToolMode>   small, rebuilds are fine
└── interactionControllerProvider: InteractionController  ephemeral drag state (D5)
```

### 3.3 The document: epochs, not equality

```dart
/// Bit flags a Command declares; the controller bumps matching epochs on commit.
extension type const EpochMask(int bits) {
  static const structure = EpochMask(1 << 0); // device add/remove/move/resize/face
  static const wires     = EpochMask(1 << 1); // connection add/remove/retype/waypoints
  static const rack      = EpochMask(1 << 2); // RU count, rack add/remove, depth
  static const meta      = EpochMask(1 << 3); // names, notes, project metadata
  static const style     = EpochMask(1 << 4); // per-entity colour overrides
  EpochMask operator |(EpochMask o) => EpochMask(bits | o.bits);
  bool has(EpochMask o) => bits & o.bits != 0;
}

class DocEpochs {
  final revision  = ValueNotifier<int>(0);   // monotonic, bumps on EVERY commit
  final structure = ValueNotifier<int>(0);
  final wires     = ValueNotifier<int>(0);
  final rack      = ValueNotifier<int>(0);
  final meta      = ValueNotifier<int>(0);
  final style     = ValueNotifier<int>(0);

  void bump(EpochMask m) {
    revision.value++;
    if (m.has(EpochMask.structure)) structure.value++;
    if (m.has(EpochMask.wires))     wires.value++;
    if (m.has(EpochMask.rack))      rack.value++;
    if (m.has(EpochMask.meta))      meta.value++;
    if (m.has(EpochMask.style))     style.value++;
  }
}
```

Every `Command` declares `EpochMask get touches`. This single mechanism drives **three** systems at once: repaint invalidation (§6), derived-cache invalidation (§5), and dirty tracking (§7). Commands cannot forget to invalidate something, because invalidation is a static property of the command type rather than an imperative call someone must remember.

`ValueNotifier<int>` is chosen over a bespoke `Listenable` because it composes directly with `Listenable.merge` and drops straight into `CustomPainter(repaint:)`.

### 3.4 Selection: observed, not owned by the document

```dart
class SelectionController extends ChangeNotifier {
  Set<EntityId> _ids = const {};
  EntityId? _focus;                 // the "last clicked" — drives the inspector

  Set<EntityId> get ids => _ids;
  EntityId? get focus => _focus;

  void apply(Iterable<EntityId> hits, SelectMode mode) { /* replace/add/subtract */ }
  Selection snapshot() => Selection(_ids, _focus);      // captured by transactions
  void restore(Selection s) { _ids = s.ids; _focus = s.focus; notifyListeners(); }
}
```

Selection is **not persisted** to `.rackmate` and does not bump `revision` (selecting a device must not mark the file dirty). But every `Transaction` captures `selectionBefore`/`selectionAfter`, so undo restores it, without which undoing a delete leaves the caret pointing at a device that no longer exists, and undoing a move leaves nothing highlighted. That is the single most-noticed undo polish detail.

### 3.5 Viewport, tool mode

`ViewportController extends ChangeNotifier` owns a `Matrix4`, a **cached inverse** invalidated in every mutator, and zoom-at-cursor / fit-to-content. It is hand-rolled (~150 lines); `InteractiveViewer` is rejected because it never receives `PointerScrollEvent` (so wheel-zoom-to-cursor is unimplementable inside it), it installs its own `ScaleGestureRecognizer` that fights marquee-select and wire-drawing in the gesture arena, and its `boundaryMargin` model doesn't match an infinite canvas.

Critical detail in the implementation: pan deltas arrive in **screen** space and must be applied with `leftTranslate` (pre-multiply); the zoom pivot uses right-multiplied `translate` in scene space. Reversing these produces pan whose speed varies with zoom, the classic hand-rolled-viewport bug.

**The viewport must not be `watch`ed by any widget.** It is passed to painters as a repaint `Listenable`. The one exception is the status-bar zoom readout, which subscribes through a **10 Hz throttling adapter**: otherwise a 1000 Hz mouse rebuilds a `Text` widget 1000 times a second to change "150%" to "151%".

`ToolMode` is a sealed class (`Select`, `PlaceDevice(template)`, `DrawWire(cableType)`, `Pan`, `Measure`) in a small `NotifierProvider`. It changes at human speed, so ordinary widget rebuilds are correct and cheap. It parameterises the hit-test policy, the cursor, and which overlay affordances draw.

### 3.6 Derived data: three tiers

Covered fully in §5. In brief: totals and occupancy are **synchronous epoch-keyed memos**; routed wire geometry is a **synchronous incremental cache** keyed per-connection; full-document validation is **incremental synchronously**, with a **debounced isolate full-sweep** reserved for load, pre-export, and explicit re-check.

### 3.7 The performance requirement: no world rebuild on pointer move

Three rules, applied together, are the entire answer.

**Rule 1: the canvas never watches a provider.** It reads controllers once at construction and subscribes painters to narrow `Listenable`s:

```dart
CustomPaint(
  painter: WirePainter(
    doc: controller.doc,
    routes: controller.derived.routes,
    repaint: Listenable.merge([epochs.wires, epochs.structure, viewport]),
  ),
)
```

`CustomPainter(repaint:)` triggers a repaint **while skipping build and layout entirely**. That is the escape hatch that makes 60 fps achievable irrespective of what wraps the canvas.

**Rule 2: D5: drags never touch the document.** During a device drag or a wire pull, deltas go into `InteractionController`, which only the overlay layer listens to:

```dart
class InteractionController extends ChangeNotifier {
  DragSession? _drag;               // {ids, deltaCmm, snapResult, ghostGeometry}
  Box? _marquee;
  PendingWire? _liveWire;
  List<SnapGuide> _guides = const [];
  // setters notifyListeners(); nothing here is document state.
}
```

Three things fall out for free: the device and wire layers do not repaint during the drag, the gesture produces exactly one undo entry with no coalescing logic, and there is zero allocation churn in the document graph per frame.

**Rule 3: layer the canvas, each with its own repaint source.**

| Layer | Repaints on | Typical frequency |
|---|---|---|
| Grid | zoom decade change | ~never |
| Rack chassis / RU ruler | `epochs.rack`, theme | ~never |
| Device faceplates | `epochs.structure`, `epochs.style` | rare |
| Wires (settled) | `epochs.wires`, `epochs.structure` | rare |
| Wires (active: the ≤8 attached to the dragged device) | every frame during drag | 60–144 Hz, tiny |
| Overlay (selection, marquee, guides, live wire) | `interaction`, `selection` | 60–144 Hz, tiny |
| Screen-space HUD (ruler labels, minimap) | throttled viewport | 10 Hz |

The split of wires into *settled* (replay a cached `ui.Picture`) and *active* (re-record ~8 of 1000) is the single optimisation that determines whether dragging feels good.

---

## 4. The edit/command system and undo/redo

### 4.1 The `Command` interface

```dart
// packages/rackmate_core/lib/src/commands/command.dart
abstract base class Command {
  const Command();

  /// Human-readable, shown in Edit ▸ Undo "<label>" and the history panel.
  String get label;

  /// Which epochs this command dirties. Static per command type.
  EpochMask get touches;

  /// Non-null makes this command eligible to coalesce with an adjacent
  /// command carrying an equal mergeKey. Typically (runtimeType, entityId, field).
  Object? get mergeKey => null;

  void apply(RackDocument doc);
  void revert(RackDocument doc);

  /// Fold [next] into a new command representing both. Called only when
  /// mergeKeys are equal AND the time window has not elapsed.
  Command? mergeWith(Command next) => null;
}
```

Design notes worth defending:

- **`apply`/`revert`, not `undo`/`redo`.** Redo is just `apply` again. A command must be *idempotent under alternation*: `apply; revert; apply` must land in the identical state as a single `apply`. This is the invariant the property test in §9.2 checks.
- **Commands store before-values, not the whole entity.** `MoveDeviceCommand` holds `{id, fromRu, toRu, fromFace, toFace}`, ~40 bytes. A 500-entry history is single-digit MB.
- **Commands never allocate IDs at `apply` time.** `AddDeviceCommand` generates its UUID in its *constructor*, so redo re-creates the entity with the identical ID and any commands stacked on top of it still resolve. This is the most common command-pattern bug and it is invisible until someone does add → connect → undo → undo → redo → redo.

### 4.2 A concrete command

```dart
final class MoveDeviceCommand extends Command {
  MoveDeviceCommand({
    required this.id, required this.fromRu, required this.toRu,
    required this.fromFace, required this.toFace,
  });

  final EntityId id;
  final int fromRu, toRu;
  final RackFace fromFace, toFace;

  @override String get label => 'Move device';
  @override EpochMask get touches => EpochMask.structure | EpochMask.wires;
  //                                 ^ wires too: endpoints moved, routes are stale.

  @override Object? get mergeKey => (MoveDeviceCommand, id);   // arrow-key nudge repeats

  @override void apply(RackDocument doc) {
    final d = doc.devices[id]!;
    d.setPlacement(toRu, toFace);        // library-private setter
    d.touch(doc.clock.nowUtc(), doc.actor);
  }

  @override void revert(RackDocument doc) {
    final d = doc.devices[id]!;
    d.setPlacement(fromRu, fromFace);
    d.touch(doc.clock.nowUtc(), doc.actor);
  }

  @override Command? mergeWith(Command next) => switch (next) {
    MoveDeviceCommand(id: final n, toRu: final r, toFace: final f) when n == id =>
      MoveDeviceCommand(id: id, fromRu: fromRu, toRu: r, fromFace: fromFace, toFace: f),
    _ => null,
  };
}
```

Note `touches` includes `wires` even though no `Connection` object changes, the *routed geometry* of every wire touching this device is invalidated. Getting these masks right is the discipline that makes the whole invalidation system honest; when in doubt, over-declare (a spurious repaint is cheap, a stale wire is a bug report).

### 4.3 Transactions

```dart
final class Transaction extends Command {
  Transaction(this.label, this.children, this.selectionBefore, this.selectionAfter)
    : timestamp = DateTime.now();

  @override final String label;
  final List<Command> children;
  final Selection selectionBefore, selectionAfter;
  final DateTime timestamp;

  @override EpochMask get touches =>
      children.fold(const EpochMask(0), (m, c) => m | c.touches);

  @override void apply(RackDocument doc) {
    for (final c in children) c.apply(doc);
  }

  @override void revert(RackDocument doc) {
    for (var i = children.length - 1; i >= 0; i--) children[i].revert(doc);
  }
}
```

Reverse-order revert is mandatory and easy to get wrong: deleting a device and its 6 connections must restore the device *before* the connections that reference it, or the connection restore dereferences a missing device.

Nested transactions **flatten into the outermost**. A device-builder "apply template changes" operation may internally open transactions; the user should see one undo entry.

### 4.4 The undo stack

```dart
class UndoStack {
  UndoStack({this.maxEntries = 200, this.mergeWindow = const Duration(milliseconds: 400)});

  final int maxEntries;
  final Duration mergeWindow;
  final List<_Entry> _done = [];
  final List<_Entry> _undone = [];

  bool get canUndo => _done.isNotEmpty;
  bool get canRedo => _undone.isNotEmpty;
  String? get undoLabel => _done.lastOrNull?.command.label;
  String? get redoLabel => _undone.lastOrNull?.command.label;

  /// Returns the epochs that must be bumped, or null if the command coalesced
  /// into the stack top (caller still bumps, but adds no history entry).
  EpochMask push(Command c, Selection before, Selection after, DateTime now) {
    _undone.clear();                                  // linear undo; no undo tree in v1
    final top = _done.lastOrNull;
    if (top != null &&
        c.mergeKey != null &&
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
}
```

**Coalescing policy.** Merge iff `mergeKey` matches **and** the delta is under 400 ms. Used for: property-inspector typing (renaming a device is one undo entry), arrow-key nudge repeats, and slider drags in the inspector. It is deliberately **not** used for canvas drags, D5's "gesture-end commits once" already collapses those, and doing both would risk merging two genuinely distinct drags a user performed quickly.

**Cap.** 200 entries. At ~100 bytes/command this is trivial memory; the cap exists to bound the pathological case (a script-driven bulk import), not to save RAM.

### 4.5 `DocumentController`: the single mutation gate

```dart
class DocumentController {
  DocumentController(this.doc, {required this.selection, required this.clock});

  final RackDocument doc;
  final SelectionController selection;
  final Clock clock;
  final epochs = DocEpochs();
  final undo = UndoStack();
  final derived = DerivedRegistry();

  _TxnBuilder? _open;
  int _lastSavedRevision = 0;
  bool get isDirty => epochs.revision.value != _lastSavedRevision;

  /// Single command, auto-wrapped in a transaction.
  void run(Command c) => transact(c.label, (tx) => tx.add(c));

  /// Grouped edits. Nested calls flatten into the outermost transaction.
  T transact<T>(String label, T Function(TxnScope tx) body) {
    if (_open != null) return body(_open!.scope);      // flatten
    final b = _TxnBuilder(label, selection.snapshot());
    _open = b;
    try {
      final result = body(b.scope);
      _commit(b);
      return result;
    } catch (e, st) {
      _rollback(b, e, st);                             // §11.3
      rethrow;
    } finally {
      _open = null;
    }
  }

  void _commit(_TxnBuilder b) {
    if (b.children.isEmpty) return;                    // no-op edits add no history
    final txn = Transaction(b.label, b.children, b.selectionBefore, selection.snapshot());
    undo.push(txn, b.selectionBefore, selection.snapshot(), clock.nowUtc());
    epochs.bump(txn.touches);                          // ← invalidation happens here, once
  }

  void undoOne() {
    final e = undo.popUndo();
    if (e == null) return;
    e.command.revert(doc);
    selection.restore(e.selectionBefore);
    epochs.bump(e.command.touches);
  }

  void redoOne() { /* symmetric, restores selectionAfter */ }
}
```

Two subtleties:

- **Commands `apply` immediately inside `tx.add()`**, not at commit. The document is always in a consistent state as the transaction builds, so later commands in the same transaction can read the results of earlier ones (e.g. "add device, then connect to it").
- **Epochs bump once per transaction**, not per child command. A bulk operation touching 200 devices triggers exactly one repaint and one derived-cache invalidation.

### 4.6 Escape hatch: `SnapshotCommand`

Some operations are genuinely awkward to hand-invert: auto-arrange, catalog import, "renumber all reference designators", "convert rack to 45U and re-flow". Do not write fragile hand-inverted commands for these.

```dart
final class SnapshotCommand extends Command {
  SnapshotCommand(this.label, this.touches, this.entityIds, this.before, this.after);
  @override final String label;
  @override final EpochMask touches;
  final List<EntityId> entityIds;
  final Map<EntityId, JsonMap?> before, after;   // null value == entity absent
  @override void apply(RackDocument doc) => doc.restoreEntities(after);
  @override void revert(RackDocument doc) => doc.restoreEntities(before);
}
```

It snapshots **only the affected entities'** JSON, not the document. For a 200-device auto-arrange that's ~60 KB, pay it, get correctness immediately. Reserve precise commands for the high-frequency operations where the memory and clarity actually matter.

### 4.7 Integration with the state solution

`DocumentController` extends nothing Riverpod-specific. The provider is:

```dart
final documentControllerProvider = Provider<DocumentController>((ref) {
  throw StateError('overridden per-document in ProviderScope');
});
```

…overridden in the per-document `ProviderScope`. Chrome-facing derived providers listen to the *epoch notifiers*, not the document:

```dart
final canUndoProvider = Provider<({bool can, String? label})>((ref) {
  final c = ref.watch(documentControllerProvider);
  ref.watch(_revisionProvider);              // ChangeNotifier→Provider adapter on epochs.revision
  return (can: c.undo.canUndo, label: c.undo.undoLabel);
});
```

Menu items, toolbar buttons, and keyboard shortcuts all dispatch the *same* `Intent` through `Actions`, so there is exactly one enablement rule per operation and the menu can render accelerator labels from the same source.

---

## 5. Derived-data pipeline

Three tiers, assigned by cost and staleness tolerance.

### 5.1 Tier 1: synchronous epoch-keyed memo (cheap, must be exact)

Totals (RU used/free, power draw in W, heat in BTU/hr, weight, port counts by connector), RU occupancy map, and the wiring schedule rows.

```dart
class Derived<T> {
  Derived(this._deps, this._compute);
  final EpochMask _deps;
  final T Function(RackDocument) _compute;
  T? _value;
  int _stamp = -1;

  T of(RackDocument doc, DocEpochs e) {
    final s = e.stampFor(_deps);      // packed hash of the epochs in _deps
    if (_stamp != s) { _value = _compute(doc); _stamp = s; }
    return _value as T;
  }
  void invalidate() => _stamp = -1;
}
```

Cost at 200 devices / 1000 connections: totals ≈ 40 µs, occupancy ≈ 25 µs, schedule ≈ 900 µs (it sorts and formats). All comfortably under one frame, all recomputed at most once per commit because commits happen at human speed. **Do not debounce these**: debouncing exact, cheap data buys nothing and introduces visible lag in the totals panel.

The schedule derivation is shared verbatim between the on-screen `DataTable` and the PDF table. There must be exactly one function that turns a document into schedule rows, or the printed schedule will eventually disagree with the screen.

### 5.2 Tier 2: incremental per-entity cache (expensive, must be exact)

Routed wire geometry. Full re-route of 1000 orthogonal traces with obstacle avoidance is ~15–40 ms, too slow to do per commit, and catastrophic if it ever landed in a drag frame.

```dart
class RouteCache {
  final _routes = <EntityId, RoutedWire>{};
  int _obstacleStamp = -1;

  RoutedWire routeOf(RackDocument doc, EntityId conn, DocEpochs e) {
    // Obstacle field (device bodies) changes far less often than wires do.
    if (_obstacleStamp != e.structure.value) {
      _field = ObstacleField.build(doc);      // ~1 ms at 200 devices
      _obstacleStamp = e.structure.value;
      _routes.clear();                        // conservative: geometry moved
    }
    return _routes.putIfAbsent(conn, () => router.route(doc, conn, _field));
  }

  /// Called by the controller with the entity set a transaction touched.
  void invalidateTouching(Set<EntityId> devices, Set<EntityId> conns) { … }
}
```

The refinement that matters: `_commit` hands the cache the *set of entity IDs the transaction touched* (each command exposes `Iterable<EntityId> get affects`), so moving one device evicts only the ~8 wires attached to it. Steady-state per-commit routing cost drops to ~0.4 ms.

**Lazy, not eager.** Routes are computed on first paint request, and only for connections whose bounds intersect the viewport plus a margin. A 1000-wire document where the user is zoomed into one rack routes ~150 wires, not 1000.

**Never in an isolate.** Routing is on the paint path; a round-trip through an isolate would introduce a frame of visible lag on every edit, which is far worse than 0.4 ms of synchronous work.

### 5.3 Tier 3: debounced background sweep (expensive, staleness tolerable)

Full-document validation / DRC: connector compatibility, direction sanity (out→in), duplicate port use, orphaned connections, RU collisions, power budget overrun, unresolved Structure home-runs, cable-length warnings, unlabelled ports.

The design is **incremental-first**:

```dart
class IncrementalValidator {
  final _issues = <EntityId, List<Issue>>{};     // keyed by the entity the issue attaches to

  /// Synchronous, called from _commit with the touched set. ~O(touched × rules).
  void revalidate(RackDocument doc, Set<EntityId> touched) { … }   // ~200 µs typical

  /// Full sweep. Runs on load, before export, and on explicit "Re-check".
  static Future<ValidationReport> fullSweep(ValidationInput input) =>
      Isolate.run(() => runAllRules(input));     // ~120 ms at 200 devices
}
```

Rationale for making incremental the primary path rather than reaching straight for the isolate: an isolate round-trip requires serializing an input payload, and the debounce plus transfer means issue badges lag the edit by 250–400 ms. Users read that as "the app is slow." Incremental synchronous validation at ~200 µs is imperceptible and always correct for local edits.

The isolate full sweep exists for the three cases where incrementality can't be trusted or latency doesn't matter: **document load** (nothing is cached), **pre-export** (must be authoritative, and blocking the UI for 120 ms during a 2 s export is fine but avoidable), and **explicit re-check** (the "something looks wrong" button). It is debounced at 500 ms with a generation token so a superseded sweep's result is discarded:

```dart
int _gen = 0;
void scheduleSweep() {
  final g = ++_gen;
  _debounce.run(() async {
    final report = await IncrementalValidator.fullSweep(_projectInput(doc));
    if (g == _gen) _applyReport(report);       // stale results dropped
  });
}
```

**The isolate payload is a projection, not the document.** `ValidationInput` carries only the graph (IDs, connector types, directions, RU spans, power ratings) as flat typed lists. ~30 KB at 200 devices versus ~500 KB for full JSON, and it's cheaply sendable. This is only possible because `rackmate_core` is Flutter-free (§2.2).

### 5.4 Invalidation summary

| Derived thing | Tier | Depends on | Recompute cost @200 dev |
|---|---|---|---|
| Totals (power/heat/weight/RU) | 1 sync memo | `structure \| rack` | ~40 µs |
| RU occupancy + collisions | 1 sync memo | `structure \| rack` | ~25 µs |
| Wiring schedule rows | 1 sync memo | `wires \| structure \| meta` | ~900 µs |
| Routed wire geometry | 2 incremental cache | `wires \| structure \| rack` | ~0.4 ms/commit |
| Scene display list (per layer) | 2 incremental cache | matching epoch | 1–6 ms/layer |
| DRC issues (local) | 3a incremental sync | touched entities | ~200 µs |
| DRC issues (full) | 3b debounced isolate | whole doc | ~120 ms off-thread |

---

## 6. Rendering pipeline

### 6.1 The reconciliation between "display list" and "incremental repaint"

There is an apparent tension: D4 wants one immutable display list so screen and PDF agree; §3.7 wants fine-grained incremental repaint. The resolution:

> **The scene is built per layer, and each layer's `DiagramScene` is cached under its own epoch stamp. The display list is the authoring format; a `ui.Picture` is the compiled artifact.**

```
RackDocument
   │ SceneBuilder.buildRackLayer(doc)     → DiagramScene   [cache key: epochs.rack]
   │ SceneBuilder.buildDeviceLayer(doc)   → DiagramScene   [cache key: structure|style]
   │ SceneBuilder.buildWireLayer(doc,rts) → DiagramScene   [cache key: wires|structure]
   ▼
   ├─ replay → FlutterDiagramCanvas(PictureRecorder) → ui.Picture → canvas.drawPicture()
   └─ replay → PdfDiagramCanvas(PdfGraphics)         → vector PDF page content
```

The overlay layer is rebuilt fresh every frame, but it's ~30 ops (a selection halo, a marquee rect, three snap guides, one live wire), so building and replaying it costs single-digit microseconds. It is never cached and never goes to PDF.

### 6.2 Layer stack

Bottom to top, inside one `RenderRackCanvas` (a `MultiChildRenderObjectWidget`):

| # | Layer | Mechanism | Invalidated by |
|---|---|---|---|
| L0 | Background grid | `ui.Picture` re-baked per zoom decade; optionally a fragment shader for a true infinite grid in one draw call | zoom decade, theme |
| L1 | Rack chassis: rails, RU ruler, mounting holes, front/rear divider | cached `ui.Picture` | `epochs.rack`, theme |
| L2 | Device faceplates + ports + ref-designators | **real widgets** as `RenderBox` children | `epochs.structure/style` (layout-isolated) |
| L3a | Settled wires | cached `ui.Picture`, one `Path` per cable-type colour class | `epochs.wires/structure` |
| L3b | Active wires (attached to the dragged device) | re-recorded each frame, ~8 of 1000 | `interaction` |
| L4 | Overlay: selection halo, marquee, snap guides, live wire, hover highlight | never cached, ~30 ops | `interaction`, `selection` |
| L5 | Screen-space HUD: RU ruler numbers, zoom badge, minimap, off-screen indicators | painted **outside** the scene transform | throttled viewport |

**Why hybrid rather than pure-canvas.** Devices are real widgets, so text layout, hover states, focus, right-click targets, and, importantly, **accessibility semantics** all come for free. A pure `CustomPainter` for a device *builder* means hand-rolling text layout and hit-testing for every port label on every device. Meanwhile wires must not be widgets: 1000 wire widgets means 1000 × (build + layout + paint) per frame, and since each wire's position depends on two devices, any drag dirties layout across the whole tree.

The load-bearing detail in `performLayout`:

```dart
@override
void performLayout() {
  size = constraints.biggest;
  var child = firstChild;
  while (child != null) {
    final pd = child.parentData! as RackParentData;
    // Tight constraints derived from the child's OWN model size.
    // No sibling dependency ⇒ moving device A cannot dirty device B's layout.
    child.layout(BoxConstraints.tight(pd.sceneSize), parentUsesSize: false);
    child = pd.nextSibling;
  }
}
```

`parentUsesSize: false` plus tight constraints makes each child a relayout boundary, so structural edits stay paint-only for their neighbours.

### 6.3 `LayerCache`

```dart
class LayerCache {
  ui.Picture? _picture;
  Object? _key;

  ui.Picture obtain(Object key, Rect cullRect, void Function(Canvas) draw) {
    if (_picture != null && _key == key) return _picture!;
    _picture?.dispose();                       // REQUIRED: native memory
    final rec = ui.PictureRecorder();
    draw(Canvas(rec, cullRect));
    _key = key;
    return _picture = rec.endRecording();
  }
  void dispose() { _picture?.dispose(); _picture = null; }
}
```

`ui.Picture` caches **drawing instructions, not pixels**: replaying still costs GPU time proportional to content, but it eliminates the Dart-side command building and the scene walk. For the grid specifically, where rasterisation rather than command-building dominates, promote to a texture with `Picture.toImageSync()` and re-bake per zoom decade. Do **not** do that for wires: they must stay crisp at any zoom.

`RepaintBoundary` and `Picture` are complementary, not alternatives. Wrap the canvas widget as a whole and the side panels in `RepaintBoundary` so canvas repaints never touch the inspector. Do **not** wrap individual device widgets, 200 compositing layers costs more than it saves.

### 6.4 Repaint strategy and hard rules

- **No `setState` in the canvas path, ever.** Pan, zoom, drag, hover, and marquee all repaint via `repaint:` listenables or `markNeedsPaint()`.
- **Zero `saveLayer`.** It costs ~1 ms worst case; three of them eats a fifth of the frame budget. It is triggered implicitly by opacity on a subtree, by blend modes, and by antialiased `clipPath` + save. To dim unselected wires, **bake alpha into `Paint.color`**: never wrap in an opacity layer. Run `checkerboardOffscreenLayers` in DevTools and drive it to zero, and keep that as a manual pre-release check.
- **Batch by style.** Build one `Path` per cable-type colour class, not per wire. 11 cable types means ~11 `drawPath` calls for 1000 wires instead of 1000.
- **Zoom-invariant chrome.** Anything the user *touches or reads* is constant in screen pixels; anything representing *physical reality* scales. Inside a transformed canvas that means `strokeWidth = 2.0 / viewport.scale` for UI strokes, and unmodified widths for physical features. Hit slop follows the same rule.
- **Level of detail.** Below ~0.4× scale, drop port labels and draw ports as coloured ticks. Below ~0.2×, draw devices as filled RU blocks with no internal detail. This is both a legibility and a large performance win.
- **Text.** `TextPainter.layout` is ~100× the cost of `TextPainter.paint`. At 200 devices × 8 port labels = 1600 labels, cold layout is 0.5–1.6 **seconds**. An LRU `LabelCache` (≈2000 entries, keyed on text + style + maxWidth) is non-negotiable, and `TextPainter` instances **must be disposed** on eviction, they hold a native `ui.Paragraph` the Dart GC will not reclaim. Quantise the text scale to a ladder (`0.5, 0.75, 1.0, 1.5, 2.0, 3.0, 4.0`) with the residual applied as a local canvas scale; otherwise every zoom frame is a total cache miss *and* a glyph-atlas miss.

### 6.5 Hit-testing

Two things worth stating because they contradict plausible assumptions:

- **`Path.contains()` does not work on strokes.** It only works on closed paths, so a stroked polyline returns false everywhere. Flutter exposes no stroke-to-fill-path API (Skia's `getFillPath` is not in `dart:ui`, and Impeller now strokes by iterating the curve rather than materialising an outline, so it is unlikely ever to be exposed). Wire hit-testing is **closed-form point-to-segment distance**, which is trivial for orthogonal polylines and far faster than the alternatives anyway.
- **Return the *nearest* hit, not the first.** In a schematic-styled diagram wires cross constantly; first-hit picks arbitrarily and feels broken.

Start with brute force plus an AABB reject (`if (!w.bounds.inflate(tol).contains(p)) continue;` kills ~95% of candidates). At 1000 wires × 4 segments that's ~64 µs, fine for click. Add a **uniform spatial hash** (~120 lines, `Map<int, List<int>>` keyed by grid cell) only if *hover* shows up in the DevTools timeline, since hover fires at up to 1000 Hz on gaming mice. Throttle hover hit-tests to one per frame regardless. Do not import an R-tree; they earn their complexity at 10⁵ objects, and you have 10³.

### 6.6 How the shared drawing abstraction plugs in

```dart
// rackmate_core — pure Dart, no dart:ui
abstract interface class DiagramCanvas {
  void save(); void restore();
  void translate(double dx, double dy);
  void scale(double sx, double sy);
  void rotate(double radians);
  void clipRect(Box r);

  void drawLine(Pt a, Pt b, StrokeSpec s);
  void drawPolyline(List<Pt> pts, StrokeSpec s);
  void drawRect(Box r, {FillSpec? fill, StrokeSpec? stroke});
  void drawRRect(Box r, double radius, {FillSpec? fill, StrokeSpec? stroke});
  void drawCircle(Pt c, double r, {FillSpec? fill, StrokeSpec? stroke});
  void drawSvgPath(String d, {FillSpec? fill, StrokeSpec? stroke});  // connector symbols
  void drawText(String s, Pt at, TextSpec spec);
  Pt   measureText(String s, TextSpec spec);
}
```

**Units contract, stated once and enforced everywhere:** geometry coordinates are **document units (hundredths-mm, as doubles at this boundary)**; stroke widths and font sizes are in **typographic points**, with an explicit `scaleWithGeometry` flag on `StrokeSpec`. Each backend applies its own unit transform, screen uses px/mm × zoom, PDF uses 72/25.4 pt per mm. This keeps the IR exact and backend-neutral, and makes "hairlines must not shrink when scaled to fit" a first-class concept rather than an afterthought.

Two mismatches the adapter must absorb, both of which will otherwise produce screen/print divergence bugs:

1. **Dashes.** `PdfGraphics.setLineDashPattern` is native; **`dart:ui Canvas` has no dashing at all.** Without handling this, dashed cable types render solid on screen and dashed in the PDF. The Flutter backend synthesizes via `path_drawing`'s `dashPath`, and caches the dashed `ui.Path` per (geometry, dash) pair since it re-synthesizes on every paint.
2. **Y-axis and rect anchor.** PDF is Y-up with `drawRect` anchored at the *bottom* edge. Use per-coordinate flipping (`double _y(double y) => _h - y;`) rather than a global `scale(1,-1)` transform, the global flip renders every `drawString` mirrored and requires a counter-flip around each text run, which in a label-dense schematic is a great many chances to get it wrong.

One more constraint that follows: **restrict the diagram visual language to flat fills, strokes, dashes, and text.** No gradients, no shadows, no blurs, PDF's graphics model can't express them (only `PdfGraphicState(opacity:)`). This is not a hardship; it *is* the schematic aesthetic, and it guarantees the two backends agree pixel-for-vector.

Defining every connector symbol once as an SVG path `d` string is what eliminates most remaining duplication risk: `PdfGraphics.drawShape(d)` consumes it natively, and `parseSvgPathData(d)` gives a `ui.Path` on the Flutter side.

---

## 7. Persistence

### 7.1 File format

`.rackmate` v1 is **plain, pretty-printed, key-sorted JSON**. Not zipped, not binary. Users can diff it in git, you can read bug reports, and support becomes tractable. The ~3× size penalty is irrelevant at 500 KB.

But hide it behind an interface from commit one, because the day someone embeds a faceplate PNG you need a container:

```dart
abstract class DocumentCodec {
  Future<Outcome<RackDocument>> read(Uint8List bytes);
  Future<Uint8List> write(RackDocument doc);
}
// v1: PlainJsonCodec.
// v2: ZipCodec (archive) with document.json + assets/<uuid>.png + manifest.json.
// Sniff PK\x03\x04 on read to dispatch. The extension NEVER changes; old files open forever.
```

Root keys, all four mandatory:

```json
{
  "generator": "RackMate",     // magic: reject foreign JSON with a good error, not a null cast
  "schemaVersion": 1,          // bumped by every format change
  "minReaderVersion": 1,       // bumped ONLY for genuinely breaking changes
  "appVersion": "1.0.0",       // diagnostics only, never branched on
  ...
}
```

The `schemaVersion` + `minReaderVersion` pair is what gets you both directions of compatibility: an old app can open a newer file read-only-with-warning unless the newer file declares a breaking change.

**Hand-written `toJson`/`fromJson`. No `json_serializable`, no freezed JSON, no `build_runner`.** Generated codecs couple the on-disk format to the Dart class shape, so every class refactor silently changes the file format. For a format that must open in 2033, that coupling *is* the bug. Hand-written codecs make the wire format an explicit, reviewable, diffable artifact, and the format is this product's most durable asset. Cost is ~300 lines written once. (Generated codecs are the right answer for ephemeral API DTOs; a document format is the opposite case.)

Two rules inside the codec:

- **Enums are strings, never ordinals.** `"hdmi"`, not `3`. Unknown values fall back to an `unknown(raw)` sealed variant that round-trips rather than throwing. `CableType` and `ConnectorType` will grow for the life of the product.
- **Preserve unknown fields.** Every entity keeps a `Map<String, dynamic> _unknown` for keys it didn't recognise and re-emits them on save. A v1.0 app opening a v1.4 file round-trips without destroying newer data.

### 7.2 Migration execution

```dart
const kSchemaVersion = 1;
typedef JsonMap = Map<String, dynamic>;
typedef Migration = JsonMap Function(JsonMap);

/// APPEND-ONLY. A shipped migration is a historical record — editing one
/// corrupts users' files. Never delete, never modify.
const migrations = <int, Migration>{
  // 1: _v1ToV2,   // added the day v2 ships
};

Outcome<JsonMap> migrateToCurrent(JsonMap raw) {
  if (raw['generator'] != 'RackMate') return Outcome.err(NotARackMateFile());
  var v = raw['schemaVersion'] as int?;
  if (v == null) return Outcome.err(MalformedDocument('missing schemaVersion'));
  final minReader = raw['minReaderVersion'] as int? ?? v;
  if (minReader > kSchemaVersion) return Outcome.err(NewerSchema(v, readOnly: false));
  while (v! < kSchemaVersion) {
    raw = migrations[v]!(raw);
    v = raw['schemaVersion'] as int;      // each migration bumps it itself
  }
  if (v > kSchemaVersion) return Outcome.err(NewerSchema(v, readOnly: true));
  return Outcome.ok(raw);
}
```

**Migrate the raw map before any typed deserialization.** Never migrate typed objects; that requires keeping historical Dart class shapes alive forever.

### 7.3 Save path: atomic, always

```
1. Serialize on the main isolate (~15 ms at 500 KB — acceptable, and avoids
   the payload transfer cost that would dominate for a doc this size).
2. Write bytes to  <target>.rackmate.tmp   in the SAME directory (same volume ⇒ atomic rename).
3. flush() + close().
4. If <target> exists → rename to <target>.rackmate.bak (overwrite previous .bak).
5. rename(<target>.rackmate.tmp → <target>.rackmate).
6. _lastSavedRevision = epochs.revision.value;   → isDirty goes false
7. Delete this document's recovery snapshot.
8. Push to recent files; update window title.
```

A crash at any step leaves either the previous good file or the previous good file plus a `.tmp`. The `.bak` is cheap insurance users appreciate disproportionately.

### 7.4 Dirty tracking

```dart
bool get isDirty => epochs.revision.value != _lastSavedRevision;
```

Revision counters, never document equality, equality is O(document) on every keystroke and gets subtly wrong with any float that survives into the model.

**Deliberate decision on undo-to-saved-state:** `undoOne()` and `redoOne()` **restore** the revision they were recorded at rather than incrementing it, so undoing back to the save point marks the document clean again. This matches user intuition ("I undid my changes, there's nothing to save"). Implementation: each `_Entry` records `revisionAfter`, and undo sets `epochs.revision.value = entry.revisionBefore`. This means `revision` is not strictly monotonic, which is fine for dirty tracking, so a **separate strictly-monotonic `sequence` counter** is kept for the future sync cursor.

### 7.5 Autosave and crash recovery

- Every **30 s** and on **window blur**, if dirty, write a recovery snapshot to `getApplicationSupportDirectory()/recovery/<docUuid>.rackmate`, plus a sidecar JSON `{realPath, revision, savedAt, displayName}`.
- **Never autosave over the user's file.** CAD users expect explicit saves and will file a bug the first time an autosave clobbers something.
- Autosave serialization runs in `Isolate.run`, unlike explicit save, nobody is waiting, so the transfer cost is free and the UI must not hitch.
- Delete the snapshot on clean save and clean exit.
- On startup, scan the recovery dir. Any survivor ⇒ `"RackMate closed unexpectedly. Recover Smith Residence Rack 2 (12 unsaved changes)?"` with Recover / Discard / Keep for later.
- Recovery files are also the crash-report attachment (§11).

### 7.6 Close interception, recents, window state

```dart
await windowManager.setPreventClose(true);
// WindowListener.onWindowClose:
//   if (!isDirty) → destroy()
//   else → three-button dialog: Save / Don't Save / Cancel.  Never two buttons.
```

**Recent files** = a JSON list in app-support (`{path, displayName, lastOpened, thumbnailPath}`), not `shared_preferences`, you want a thumbnail and structured metadata, and prefs is the wrong shape. Prune missing files **lazily** (a network drive that's temporarily unmounted must not evict the entry).

**Window state** (size, position, monitor, maximized) persists in the same app-support prefs file. Set a minimum window size, a rack editor below ~1000 px wide is unusable.

---

## 8. Dependency list

### 8.1 `rackmate_core`: pure Dart, deliberately tiny

| Package | Constraint | Why |
|---|---|---|
| `meta` | `^1.16.0` | `@immutable`, `@internal`, `@useResult` annotations. Zero runtime cost. |
| `collection` | `^1.19.0` | `UnmodifiableSetView`, `IterableExtension.firstWhereOrNull`, deep equality helpers. |
| `uuid` | `^4.6.0` | **UUID v7** for all entity IDs: time-ordered (readable logs, natural creation-order sort with no extra field, index locality if these ever hit a DB). No downside vs v4. |

That is the entire production dependency set for the layer where 80% of the logic lives. No `build_runner`, no `freezed`, no `json_serializable`.

**On skipping codegen entirely:** Dart macros were cancelled in January 2025, so there is no codegen-free path to generated `==`/`copyWith`/`fromJson` and there will not be one soon. That means the choice is "hand-write ~15 value types" versus "adopt `build_runner` forever." Dart 3 sealed classes with exhaustive `switch` already cover the union-type case that was freezed's killer feature, and §7.1 argues hand-written JSON is *actively better* for a document format. Retrofitting freezed onto a plain class later is mechanical; ripping codegen out is not. Start without it. The payoff is sub-second `dart test` cycles for the life of the project.

### 8.2 `rackmate_export`

| Package | Constraint | Why |
|---|---|---|
| `pdf` | `^3.13.0` | The only real option. Pure Dart (no Flutter dep ⇒ isolate-safe), Apache-2.0, `pw.Widget` layout for the schedule, `PdfGraphics` for vector diagram output. Requires Dart ≥3.12.0, matches this SDK exactly. |

### 8.3 `rackmate_ui`

| Package | Constraint | Why |
|---|---|---|
| `flutter` | sdk |: |
| `path_drawing` | `^1.0.1` | `dashPath()`: synthesizes dashes that `dart:ui` cannot do natively (§6.6). Small, stable, single-purpose. |
| `vector_math` | `^2.2.0` | `Matrix4` for the viewport. Transitively available via Flutter; pin it explicitly since core geometry code touches it. |

### 8.4 `apps/rackmate`

| Package | Constraint | Why |
|---|---|---|
| `flutter_riverpod` | `^3.3.2` | DI + per-document lifetime scoping + chrome read-models (§3). Codegen-free usage. |
| `file_selector` | `^1.1.0` | **flutter.dev verified**, federated, calls native OS dialogs. Chosen over `file_picker` (3rd-party, shells out on macOS/Linux, has had desktop `saveFile` regressions), desktop is exactly where that difference bites. |
| `window_manager` | `^0.5.2` | Title with dirty marker, size/position restore, minimum size, and critically `setPreventClose` for the save prompt. De-facto standard, ~500 k downloads. |
| `path_provider` | `^2.1.5` | `getApplicationSupportDirectory()` for recovery, recents, logs, prefs. flutter.dev. |
| `path` | `^1.9.0` | Cross-platform path joining. Never string-concatenate paths on Windows. |
| `printing` | `^5.15.0` | `layoutPdf` for the print dialog, `PdfPreview` for in-app preview. See risk note. |
| `desktop_drop` | `^0.6.0` | Drag a `.rackmate` onto the window to open it. Not built in to Flutter. |
| `logging` | `^1.3.0` | Structured, level-based, zero-dependency. Sinks are ours (§11). |
| `intl` | `^0.20.0` | Number/date/unit formatting; the runtime half of ARB localization. |
| `flutter_localizations` | sdk | `MaterialLocalizations`, `Directionality`, locale resolution. |

### 8.5 Dev dependencies

| Package | Constraint | Why |
|---|---|---|
| `test` | `^1.26.0` | Pure-Dart tests in core/export. |
| `flutter_test` | sdk | Widget + golden tests. |
| `integration_test` | sdk | Desktop end-to-end file-lifecycle tests. |
| `very_good_analysis` | `^9.0.0` | Strictest widely-used lint set. Stricter than `flutter_lints`; catches the `prefer_final`, `avoid_dynamic_calls`, and unawaited-future classes of bug that matter in a document editor. Fallback: `flutter_lints ^6.0.0` if the strictness proves noisy. |
| `leak_tracker_flutter_testing` | `^3.0.0` | Catches undisposed `TextPainter`/`ui.Picture`/`ChangeNotifier` in widget tests. Given §6.4's native-resource caching, this is not optional. |
| `benchmark_harness` | `^2.3.0` | The perf-budget harness (§10). |

Explicitly **not** used: any node-editor package (`vyuh_node_flow`, `fl_nodes`, `flutter_flow_chart`, `diagram_editor`, `graphview`), any spatial-index package, `undo`, `freezed`, `json_serializable`, `build_runner`, `InteractiveViewer`, `golden_toolkit`.

### 8.6 Risk register

| Package | Risk | Fallback |
|---|---|---|
| **`pdf` / `printing`** | Single maintainer (DavBfr) on a headline feature. Highest-consequence dependency in the project. | The `DiagramCanvas` abstraction (§6.6) *is* the hedge: swapping backends is one file. Failing that, emitting PDF 1.7 content streams for pure vector + Type0 font embedding is ~2 k lines of well-specified work, or route through SVG (`SvgDiagramCanvas` → external converter). |
| **`printing`** (specifically) | `Printing.raster` / `PdfPreview` need **pdfium**; the plugin's CMake downloads binaries at build time. A fresh machine or a network-restricted CI runner fails `flutter build windows`. Also affected by Android 16 KB page sizes for the mobile review mode. | Vendor the pdfium binaries into the repo and point CMake at them. Or drop in-app preview entirely and rely on `file_selector` save + the OS PDF viewer, `layoutPdf` and file saving do not need pdfium. |
| **`window_manager`** | 0.x, single maintainer. | The only truly load-bearing API is `setPreventClose` + the close event. That's ~80 lines of Win32 platform channel if it ever breaks. `bitsdojo_window` is a worse-maintained alternative; don't plan on it. |
| **`desktop_drop`** | 0.x, low activity. | Drag-drop-to-open is a nicety, not a requirement. Degrade to File ▸ Open. Alternative: `super_drag_and_drop`. |
| **`very_good_analysis`** | Third-party lint set; a major bump can suddenly fail CI on existing code. | Pin exactly (`9.0.0`, not `^9.0.0`) and bump deliberately. Fallback `flutter_lints`. |
| **`path_drawing`** | Low activity, but tiny and stable. | ~60 lines to implement dash synthesis over `PathMetrics` directly. |
| **Flutter desktop multi-window** | Not shipping; Canonical's work is still under engine review with no committed version. | Ship single-window with in-app document tabs. One `ProviderScope` per document means the model is already correct in-process; multi-window becomes mechanical when the API lands. Do **not** use `desktop_multi_window`, each window is a separate engine with no shared memory, which is fatal for a shared document. |

---

## 9. Testing strategy

Ordered by value per line of test code.

### 9.1 The migration golden corpus: highest value in the repo

```
packages/rackmate_core/test/fixtures/
  v1_minimal.rackmate        # empty 42U rack
  v1_full.rackmate           # every entity type, every connector, every cable type
  v1_unicode.rackmate        # Ω ° ± µ → × ≈ — " " and an accented client name
  v1_unknown_fields.rackmate # hand-edited to include future keys
  v2_*.rackmate              # added the day v2 ships. NEVER edited afterwards.
```

The test opens **every historical fixture**, migrates it, asserts it produces a valid current document, and asserts unknown fields survive a round-trip. Add a fixture on the day each schema version ships. This test is what lets you refactor the model confidently for years.

### 9.2 Command round-trip property test

```dart
test('apply ∘ revert == identity, over 2000 random (doc, command) pairs', () {
  for (var seed = 0; seed < 2000; seed++) {
    final rng = Random(seed);
    final doc = randomDocument(rng);          // hand-rolled generator, no glados
    final before = JsonEncoder.withIndent(' ').convert(doc.toJson());
    final cmd = randomCommandFor(doc, rng);
    cmd..apply(doc)..revert(doc);
    expect(JsonEncoder.withIndent(' ').convert(doc.toJson()), before, reason: 'seed=$seed');
  }
});
```

Plus the alternation invariant: `apply; revert; apply` must equal a single `apply`. This one pair of tests catches nearly every undo bug you would otherwise ship, and it is only expressible this cheaply because core is pure Dart and synchronous.

Hand-roll the generator with a seeded `math.Random` rather than importing a property-testing package, you need domain-aware generation (valid RU spans, compatible connectors) that a generic shrinker can't produce, and a failing seed number is a perfectly good repro.

### 9.3 Display-list goldens: the primary painter regression net

**Do not pixel-diff the canvas as the first line of defence, and do not byte-diff the PDF.**

Instead, golden the `DiagramScene` as a canonical, deterministic text dump:

```
RECT      l=0 t=0 w=48260 h=186690  fill=#1A1D21 stroke=#3A4048/0.75pt
TEXT      "U42" @(-2400,900) font=mono size=6.0pt anchor=centerRight
POLYLINE  [(12000,4445),(20000,4445),(20000,17780)] stroke=#E8A33D/1.5pt dash=none
SVGPATH   "M0 0h8v6h-8z" @(31000,8890) fill=#2AB3A6
```

Why this is better than pixels for the primary net: it is reviewable in a pull request (a reviewer sees *"the wire moved 2 mm and changed colour"*, not *"47 pixels differ"*), it is fully deterministic across platforms and Flutter versions, it runs in `dart test` with no Flutter binding, and it covers screen and PDF simultaneously because both consume the same list.

Pixel goldens then serve a narrower purpose: verifying the two *backends* are faithful interpreters. Keep them small and few.

### 9.4 Widget and pixel goldens

- `matchesGoldenFile` via plain `flutter_test`. **No `golden_toolkit`** (effectively unmaintained since Very Good Ventures stepped back); no `alchemist` either, the value-add over a good `flutter_test_config.dart` is small and the maintenance risk is real.
- **Font determinism** (the thing that breaks goldens across platforms): register the bundled TTFs in `flutter_test_config.dart` via `FontLoader`, and assert that no golden scene uses a family other than `RackBody`/`RackMono`. This removes the system-font variable entirely.
- `debugDisableShadows = true`, fixed `Random` seeds, no animations, fixed `Size`.
- Golden the *device faceplate renderer* and the *wire layer* **separately**. Never golden the whole canvas, one pixel of change anywhere fails everything and reviewers start rubber-stamping.
- Tag them: `@Tags(['golden'])`, declared in `dart_test.yaml`, so non-Linux CI jobs skip them.

### 9.5 PDF verification

Three levels:

1. **Structural assertions** (every PR): generate a document, assert page count, page sizes, that fonts are embedded and subset, that no page is empty, that the schedule row count equals the connection count, that `maxPages` was not hit.
2. **Display-list goldens** (every PR, §9.3), covers the diagram content.
3. **Pixel diff** (nightly only): render pages via poppler's `pdftoppm` (installed in the Linux CI job) and image-diff against references. Nightly rather than per-PR because it's slow and mildly flaky. Note that PDF **bytes** are not deterministic (creation timestamps, object ordering), so never hash the file.

### 9.6 Widget, integration, and leak tests

- **Widget tests**: inspector panels, device-builder forms, menu enablement (assert Undo is disabled at revision 0 and enabled after a command, with the right label).
- **Integration tests** (`integration_test`, desktop): new → place devices → connect → save → close → reopen → assert identical document. Plus the unsaved-changes-on-close dialog, and the crash-recovery path (kill mid-edit, relaunch, assert recovery prompt).
- **Leak tests**: `leak_tracker_flutter_testing` on the canvas widget tests, specifically catching undisposed `TextPainter` and `ui.Picture`.

### 9.7 CI

```yaml
# .github/workflows/ci.yaml  (shape, not full listing)
jobs:
  analyze-and-test:
    strategy:
      fail-fast: false
      matrix:
        os: [ubuntu-latest, windows-latest, macos-latest]
    steps:
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.44.4'      # PINNED. Goldens do not survive Flutter bumps.
          channel: stable
      - run: dart pub get                  # workspace root resolves all members
      - run: dart analyze --fatal-infos --fatal-warnings
      - run: dart format --output=none --set-exit-if-changed .
      - run: dart test                     # core + export: fast, all 3 OSes
        working-directory: packages/rackmate_core
      - run: flutter test --exclude-tags golden
      - run: flutter build windows --release      # if: windows
      - run: flutter build macos --release        # if: macos
      - run: flutter build linux --release        # if: ubuntu

  goldens:
    runs-on: ubuntu-latest               # ONE platform only
    steps: [ ..., run: flutter test --tags golden ]

  perf-budget:
    runs-on: ubuntu-latest
    steps: [ ..., run: dart test --tags perf ]   # warn-only for the first 3 months
```

**Golden strategy that survives platform font differences:** goldens run on **Linux only**, with a pinned Flutter version and bundled fonts registered in `flutter_test_config.dart`. Windows and macOS jobs run `--exclude-tags golden`. This is the only approach that actually holds, attempts to maintain per-platform golden sets collapse under maintenance cost within a few months. The pinned Flutter version is load-bearing: a Flutter minor bump routinely shifts antialiasing by a pixel, so treat golden regeneration as a deliberate, reviewed step of every Flutter upgrade.

---

## 10. Performance budget

### 10.1 Scale targets (the "large but supported" document)

| Quantity | Target | Hard cap (degrade gracefully past this) |
|---|---|---|
| Racks per project | 4 | 12 |
| RU per rack | 45 | 60 |
| Devices | 200 | 500 |
| Ports | 2 000 | 6 000 |
| Connections | 1 000 | 3 000 |
| Undo history | 200 entries |: |
| `.rackmate` file size | 500 KB | 3 MB |

### 10.2 Time budgets

| Operation | Target (p95, at scale targets, on a mid-range 2022 laptop) | Measured by |
|---|---|---|
| **Idle frame** | UI thread ≤ 2 ms, raster ≤ 4 ms | DevTools timeline, `--profile` |
| **Pan / zoom frame** | UI ≤ 3 ms, raster ≤ 8 ms (60 fps with headroom) | DevTools timeline |
| **Device-drag frame** | UI ≤ 4 ms, raster ≤ 8 ms; **zero** device/wire-layer repaints | `debugRepaintRainbowEnabled` + timeline |
| **Commit a command** (mutate + invalidate + reroute + revalidate + repaint) | ≤ 8 ms | `benchmark_harness` in core + widget test timing |
| **Undo / redo step** | ≤ 4 ms | core benchmark |
| **Full wire re-route** (cold, 1000 wires) | ≤ 40 ms | core benchmark |
| **Incremental re-route** (one device moved) | ≤ 1 ms | core benchmark |
| **Full DRC sweep** (isolate) | ≤ 150 ms, UI never hitches | isolate timing + timeline |
| **File load → first paint** (500 KB) | ≤ 400 ms | integration test `Stopwatch` |
| **Explicit save** (500 KB, atomic) | ≤ 150 ms | integration test |
| **Autosave** | UI hitch ≤ 4 ms (work is in isolate) | timeline |
| **PDF export, 7-sheet set** | ≤ 2.5 s wall clock, UI never blocks > 16 ms | export benchmark + timeline |
| **App cold start → empty document** | ≤ 1.2 s | `flutter run --trace-startup` |
| **Peak RSS** (500 KB doc, 200 devices) | ≤ 350 MB | DevTools memory |

### 10.3 How each is measured

Three mechanisms, all in CI or one command away:

1. **`packages/rackmate_core/test/perf/`: `benchmark_harness` benchmarks over synthetic documents at 50 / 200 / 500 devices.** Pure Dart, deterministic, runs headless in CI under the `perf` tag. Thresholds are asserted, but the job is **warn-only for the first three months**: establish the baseline curve on CI hardware before it can fail a build, or you will spend that time chasing runner variance instead of writing the app.
2. **DevTools timeline in `--profile` mode**, driven by a scripted interaction (`integration_test` performing a fixed 30-second pan/zoom/drag script), with `flutter drive --profile --trace-startup` producing a timeline JSON. Assert on `frame_build_times` p95 and `frame_rasterizer_times` p95 from `TimelineSummary`. This runs on demand, not per-PR (desktop CI runners have no GPU worth trusting).
3. **Manual pre-release checklist**, three items, each of which catches a class of regression nothing automated will: `debugRepaintRainbowEnabled` (assert only the overlay flickers during a drag), `checkerboardOffscreenLayers` (must be **zero**: any `saveLayer` is a bug per §6.4), and dragging the window between a 4K and a 1080p monitor (mixed-DPI breaks naive viewport implementations, and Windows users genuinely run this configuration).

**A note on the arithmetic that justifies the architecture:** 1000 wires × ~4 µs per stroked polyline ≈ 4 ms of raster time, about a quarter of the 16.6 ms budget for wires *alone*, if drawn naively every frame. That number is why L3a is a cached `ui.Picture` and why the drag path re-records only the ~8 active wires. And `saveLayer` at ~1 ms means three of them costs more than the entire wire layer; hence the zero-`saveLayer` rule.

---

## 11. Error handling, logging, crash reporting

### 11.1 Two error categories, two mechanisms

- **Expected outcomes** (file not found, corrupt document, newer schema, permission denied, invalid connection) are **values**, not exceptions:

```dart
sealed class Outcome<T> {
  const Outcome();
  R when<R>({required R Function(T) ok, required R Function(AppError) err});
}
final class Ok<T> extends Outcome<T> { final T value; }
final class Err<T> extends Outcome<T> { final AppError error; }

sealed class AppError {
  String get userMessage;       // localized, actionable, no jargon
  String get diagnosticDetail;  // for the log, may be technical
  bool get isRecoverable;
}
```

Every `AppError` carries a **user-facing message that says what to do next** ("This file was created by a newer version of RackMate. Update RackMate, or open it read-only."), not a stack trace.

- **Programmer errors** (broken invariants, unreachable switch arms, null entity lookups) throw. They are bugs, and they should be loud in debug and captured in release.

### 11.2 Global capture

```dart
void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    FlutterError.onError = (details) {
      Log.root.severe('flutter', details.exception, details.stack);
      if (kDebugMode) FlutterError.presentError(details);
      CrashReporter.record(details.exception, details.stack);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      Log.root.severe('platform', error, stack);
      CrashReporter.record(error, stack);
      return true;                      // handled; do not kill the isolate
    };

    ErrorWidget.builder = (details) => RackMateErrorPane(details);   // never a red screen

    await bootstrap();
    runApp(const ProviderScope(child: RackMateApp()));
  }, (error, stack) {
    Log.root.shout('zone', error, stack);
    CrashReporter.record(error, stack);
  });
}
```

`ErrorWidget.builder` matters more on desktop than mobile: a red-and-yellow error box in a pane of a professional tool destroys credibility. Replace it with a neutral panel offering "Copy diagnostics" and "Save a recovery copy."

### 11.3 Transaction rollback and stack poisoning

The most dangerous failure mode is a command that throws *halfway through* `apply`, leaving the document in a state the undo stack cannot describe.

```dart
void _rollback(_TxnBuilder b, Object e, StackTrace st) {
  Log.root.severe('command failed mid-transaction: ${b.label}', e, st);
  try {
    for (var i = b.children.length - 1; i >= 0; i--) b.children[i].revert(doc);
    selection.restore(b.selectionBefore);
    epochs.bump(EpochMask.all);
  } catch (e2, st2) {
    // Rollback itself failed. The document is now untrustworthy.
    Log.root.shout('ROLLBACK FAILED — poisoning undo stack', e2, st2);
    undo.poison();                         // canUndo/canRedo → false
    _forceRecoverySnapshot();              // write it out before anything else touches it
    _notifyUnrecoverable();                // "Save a copy and restart RackMate."
  }
}
```

Poisoning the stack rather than pretending is the honest behaviour: a user who keeps undoing through a corrupted history destroys their work silently.

### 11.4 Logging

`package:logging` with two sinks:

- **Rotating file** in `getApplicationSupportDirectory()/logs/`, 5 files × 2 MB, `INFO` and above in release, `FINE` in debug. Rotation is ours (~40 lines); don't add a logging framework for it.
- **In-memory ring buffer** (last 2000 records) backing the Help ▸ **Copy Diagnostics** command, which puts a redacted bundle on the clipboard.

**Redaction policy, enforced by convention and a lint-style test:** log entity **UUIDs**, never device names, client names, project addresses, or file paths above `FINE`. A rack drawing for a private residence contains the client's name and address; those must not end up in a log the user pastes into a public issue tracker. The diagnostics bundle includes: app/Flutter/OS versions, document *statistics* (device count, connection count, schema version), the last 200 log records, and the current epoch/revision values, never document content.

### 11.5 Crash reporting: local-first, opt-in remote

**No telemetry by default.** This is a locally-installed professional tool handling client project data; silent network egress is a trust violation and, for some commercial CI clients, a contractual one.

- On an uncaught error, write `crashes/<timestamp>.json` (redacted bundle + stack) to app-support.
- On next launch, if crash files exist: *"RackMate encountered a problem last session. Send a report?"* with **View report** (shows the exact JSON, no hidden payload), **Send**, and **Never ask again**.
- Only if the user opts in does anything leave the machine, and then to a self-hosted Sentry (`sentry_flutter`), deliberately **not added as a dependency in v1**, because until there's a place to send reports, it's dead weight and an extra native surface on every platform.

---

## 12. Internationalisation and theming readiness

### 12.1 i18n: do the plumbing now, one locale

**Now (non-negotiable, cheap):**
- `flutter_localizations` + `intl` + `gen-l10n` with `app_en.arb`. All user-facing strings go through `AppLocalizations` from the first commit. Retrofitting this across a mature app is a multi-week grind that never quite finishes, and the incremental cost per string today is ~15 seconds.
- Command `label`s are the interesting case: they live in `rackmate_core`, which cannot import Flutter. Resolve by having commands expose a **`LabelKey` enum + arguments**, with `rackmate_ui` mapping key → localized string. The Edit menu shows *"Undo Move device"* localized; the log shows the stable enum name.
- `intl` `NumberFormat`/`DateFormat` for every number and date shown. Never `toString()` a double into the UI.
- `Directionality` respected throughout the chrome.

**Later (v1.2+):**
- Additional locale ARBs. German and Spanish are the likely first asks in CI; German is also the best stress test, its compound nouns will break every fixed-width label you have, which is itself a useful forcing function to design flexible layouts now.
- Localized PDF output (the schedule headers and title block), which needs a locale parameter threaded into the export request, design the signature for it now, pass `Locale('en')` for a year.

**Explicit non-goals:** the **canvas stays LTR** even under an RTL locale. Electrical schematics are LTR by universal convention, and mirroring a rack elevation would be actively wrong. Say so in the code so nobody "fixes" it. Complex-script shaping in PDF is also known-imperfect in `dart_pdf` (no HarfBuzz-class shaper); if Arabic or Devanagari localization is ever requested, that needs its own investigation.

### 12.2 Units: a separate axis from locale

Rack dimensions are a mess of mixed units and this trips people up: racks are 19″ and measured in **U**, but depths and cable lengths are quoted in **mm** in most of the world and **inches/feet** in the US, and US integrators routinely use both in the same drawing.

- **Storage is always metric integer** (hundredths-mm, D3). Never store display units.
- **Display units are a user preference independent of locale**, with three settings: RU (always, vertical), and metric/imperial for depths, cable lengths, and weights. A German integrator working a US-spec commercial job needs imperial output regardless of their system locale.
- Formatting lives in one place: `UnitFormatter` in `rackmate_ui`, taking `(Cmm value, UnitPreference pref, Locale locale)`.

### 12.3 Theming

**Now:**
- **`ThemeExtension<RackMateTheme>`** carrying every canvas colour, stroke width, corner radius, and font size. The painters read from the theme extension; **no hard-coded colours anywhere below the widget layer.** In `rackmate_core` colours are `int` ARGB in a `CablePalette` value object; `rackmate_ui` adapts to `ui.Color`.
- **Three palettes from day one**, all derived from one `CablePalette` abstraction: `screenDark` (the default; this is a pro tool used in equipment rooms and dark UIs are the genre convention), `screenLight`, and **`print`**. The print palette is genuinely different, not a tint: dark-theme wire colours print as muddy pastels on white, so print gets darker, more saturated values and a white background. Shipping the print palette in v1 costs almost nothing and prevents the "why does my PDF look wrong" bug class entirely.
- **Cable type is never encoded by colour alone.** Every cable type carries `(colour, dashPattern, abbreviation)`, and the diagram renders all three. This is required for: the ~8% of male users with colour-vision deficiency, black-and-white laser printing (extremely common for job-site copies), and photocopied/faxed drawings (still real in construction). Validate the palette against deuteranopia/protanopia simulation before locking it, and note that the dash pattern requirement is what makes §6.6's dash-parity gotcha load-bearing rather than cosmetic.
- **Fonts bundled, not system.** `Inter-Regular`, `Inter-SemiBold`, `JetBrainsMono-Regular` in `apps/rackmate/assets/fonts/`, declared **twice** in `pubspec.yaml`, under `fonts:` (for Flutter's text engine) *and* under `assets:` (so `rootBundle.load()` works for `pw.Font.ttf`). Missing the second entry is an easy and confusing bug. Bundling the *same TTF file* for screen and PDF is what makes text metrics agree between the two, without which every label's measured width differs and leader lines / callout boxes / collision avoidance diverge between screen and print. A monospace face for reference designators, port numbers, and cable IDs is worth it, column alignment reads far better and it matches the schematic aesthetic.
- Bundling also means **never ship default Helvetica in the PDF**: the standard-14 Type1 fonts are WinAnsi single-byte and throw on any non-Latin-1 codepoint. A/V documentation routinely contains `Ω`, `°`, `±`, `µ`, `→`, `×`, `—`, and smart quotes pasted from a proposal. Set `fontFallback` on the PDF theme as a safety net even when you think you don't need it.

**Later:**
- User-customisable cable colours (the data model already supports it, `style` epoch and per-entity overrides exist from day one; only the settings UI is missing).
- High-contrast theme.
- Company branding in the PDF title block (logo asset + colour), which is a straightforward extension once `.rackmate` moves to the zip container.

---

## 13. Build order

The sequencing matters, because two of these are painful to retrofit and cheap to do early.

1. **`ViewportController` + wheel/trackpad input + grid painter.** Get pan/zoom feeling *right* first; everything sits on it and it's cheapest to iterate on when nothing else exists.
2. **Integer unit model + `.rackmate` schema + codec + migration harness + the first golden fixture.** The format is the durable asset; establish it before anything depends on its shape.
3. **`Command` / `Transaction` / `UndoStack` / `DocumentController`.** ← **Do this before the feature surface grows.** Retrofitting undo is one of the genuinely painful refactors, and every feature built without it will need rewriting.
4. **`RenderRackCanvas` hybrid + device widgets + RU snapping.**
5. **Ports, typed connections, the snap cascade.**
6. **`DiagramCanvas` + display list + `SceneBuilder`,** retrofitting the screen painter onto it. ← Also do this early; it's the second painful retrofit, and doing it before the PDF work means the PDF backend is nearly free.
7. **Orthogonal router + `LayerCache` tiers + `RouteCache`.**
8. **Derived pipeline: totals, occupancy, incremental DRC, schedule.**
9. **Marquee, shortcuts, context menus, menu-as-data.**
10. **PDF export** (vector diagram + schedule table + title blocks).
11. **Autosave, recovery, recents, close interception.**
12. **Device builder UI + starter catalog.**

Steps 3 and 6 are the two "do it now or pay 10× later" items. Everything else can be reordered by product priority.