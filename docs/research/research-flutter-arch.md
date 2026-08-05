I'll research this thoroughly. Let me load the web tools and start fanning out searches.# RackMate, Architecture Research Report
**Dart 3.12 / Flutter desktop-first document editor**
Research date: 2026-07-18. Versions verified against pub.dev on this date.

> **Sourcing note:** package versions, publishers and platform-support facts below are read directly from pub.dev / api.flutter.dev and are reliable. Claims about "2026 trends" from blog aggregators were largely AI-generated SEO content; I have discarded unverifiable ones (e.g. "freezed is 30% faster in 2026") and flagged the rest as `[weak]`.

---

## 1. State management for a document editor

### Findings

The critical realization: **a document editor is not a state-management problem, it is an ownership problem.** The document is one large, long-lived, mutable object graph. Almost every general-purpose Flutter state solution (Bloc, Riverpod's immutable `Notifier<T>`, signals) assumes state is small enough to replace wholesale on each change. At 40 devices × ~20 ports + several hundred connections, replacing the whole document on every mouse-move is wasteful and, worse, it makes fine-grained repaint impossible.

Current package status:

| Package | Version | Publisher | Notes |
|---|---|---|---|
| [`riverpod` / `flutter_riverpod`](https://pub.dev/packages/riverpod) | **3.3.2** (~Jun 2026) | rrousselGit, Flutter Favorite | 3.x is stable and mature |
| [`riverpod_generator`](https://pub.dev/packages/riverpod_generator) | 3.0.3 |: | codegen **optional** in 3.x |
| [`signals`](https://pub.dev/packages/signals) | **7.1.0** (~Jun 2026) | rodydavis.com | 684 likes, ~20k downloads: small ecosystem |
| [`bloc` / `flutter_bloc`](https://pub.dev/packages/bloc) | 9.x | felangel | event-sourced; good audit trail, heavy for canvas |

Riverpod 3.0 highlights ([riverpod.dev/docs/whats_new](https://riverpod.dev/docs/whats_new)): unified `Ref` (no more `AutoDisposeFamilyNotifier` combinatorics), `Ref.mounted`, automatic retry with backoff, experimental offline persistence, experimental mutations, listeners auto-pause when not visible (`TickerMode`), and `StateProvider`/`ChangeNotifierProvider` demoted to a `legacy.dart` import. Codegen is explicitly optional; there is an [open RFC (#4008)](https://github.com/rrousselGit/riverpod/issues/4008) for a unified codegen-free provider syntax.

The single most important Flutter mechanism for this app, from [`CustomPainter`](https://api.flutter.dev/flutter/rendering/CustomPainter-class.html): passing a `Listenable` to `CustomPainter(repaint: ...)` causes repaint **while skipping the build and layout phases entirely**. That is the escape hatch that makes a 60fps canvas possible regardless of which state library wraps it.

### Recommendation

**Riverpod 3.3.2, without codegen, used only as a DI/lifetime container: not as the document store.**

```
ProviderScope (one per open document → free multi-document + future multi-window)
 └── documentControllerProvider  → DocumentController  (plain Dart, owns RackDocument)
     ├── RackDocument            (mutable aggregate, mutated ONLY via commands)
     ├── UndoStack
     └── Listenables:  docRevision · selectionNotifier · hoverNotifier · viewportNotifier
```

- The document lives in a **plain-Dart `DocumentController`** in `rackmate_core`. Riverpod holds the controller, not the document.
- Riverpod handles: open-document lifetime, disposal, DI of file services, and derived read-models the *chrome* needs (window title, dirty flag, wiring-schedule table, validation errors). Use `ref.watch(p.select(...))` for those, they're cheap and rebuild rarely.
- The **canvas never watches a provider**. It reads the controller once and subscribes `CustomPainter(repaint: ...)` to narrow `Listenable`s.

**Layer the canvas into independent `RepaintBoundary` + `CustomPaint` stacks**, each with its own repaint `Listenable`. This is the thing that actually determines whether the app feels good:

| Layer | Repaints on | Cost |
|---|---|---|
| Rack chassis: rails, RU ruler, grid | RU count / theme change only | ~never |
| Devices (front & rear faces) | `docRevision` (structural) | rare |
| Wires / traces | `docRevision` **wire epoch** | rare; cache routed polylines |
| Overlay: selection, hover, rubber-band, in-flight wire, snap guides | `selectionNotifier` / `hoverNotifier` (every frame during drag) | cheap, thin |

Key discipline: **an in-progress drag must never touch the document.** Drag deltas go into the overlay's `ValueNotifier`; only `onPanEnd` produces a command. This single rule gives you (a) no device-layer repaints during drag, (b) one undo entry per drag for free, and (c) no garbage churn.

Also: set `isComplex: true, willChange: false` on the static layers so Skia rasters them into a cache; batch draws (build one `Path` per wire *colour class*, not per wire), per the [high-performance canvas write-up](https://plugfox.dev/high-performance-canvas-rendering/).

**Why not signals:** genuinely elegant fine-grained reactivity, and `signals` 7.1.0 is good work, but its advantage is automatic dependency tracking of *widget* rebuilds, and the hot path here bypasses widget rebuilds entirely via `repaint:`. You'd take ecosystem risk (~20k downloads vs Riverpod's Flutter-Favorite status) for a benefit you've already engineered around. **Why not Bloc:** event-sourcing a canvas means an event object per mouse-move; the ceremony/benefit ratio is poor, though its explicit event log is philosophically close to the command stack you're going to build by hand anyway.

---

## 2. Undo / redo

### Findings

Real editors converge on the **command pattern with transactions**, not snapshots. The most useful primary source in the Dart ecosystem is the [super_editor Undo/Redo design analysis](https://github.com/Flutter-Bounty-Hunters/super_editor/wiki/Design-Thoughts:-Undo-Redo), which evaluates all three approaches and lands on two conclusions worth stealing:

1. **"Partial snapshots" collapse into deltas.** Once you need to encode deletions and reordering, a partial snapshot needs explicit nulls and ordering info, at which point you have re-invented a delta, badly. So the real choice is *full snapshot* vs *command/delta*, with nothing coherent in between.
2. **Selection must be tracked by the undo system**, or undo leaves the caret pointing at a node that no longer exists.

super_editor's shipped architecture forces **all mutations through a single pipeline** (`Editor` executes `EditCommand`s in a transaction, emitting a change list that reactions observe). That pipeline-monopoly is the actual load-bearing idea; the storage format is secondary.

Dart packages: [`undo` 1.6.0](https://pub.dev/packages/undo) (rodydavis, `ChangeStack`/`Change`/`SimpleStack`, zero deps), but 86 likes and **~803 weekly downloads**, and it has no concept of transactions, coalescing, or selection capture. `replay_bloc` only replays whole-state snapshots.

### Recommendation

**Hand-roll it in `rackmate_core`. ~200 lines. Do not take a dependency.**

```dart
abstract class Command {
  void apply(RackDocument doc);
  void revert(RackDocument doc);
  String get label;              // "Move AVR to RU 12"  → Edit menu, history panel
  Object? get mergeKey => null;  // non-null ⇒ eligible to coalesce
}

class Transaction implements Command {   // composite; reverts children in reverse
  final List<Command> children;
  final Selection selectionBefore, selectionAfter;
  ...
}
```

- **`UndoStack` with an open-transaction cursor.** `controller.transact('Move device', (tx) { ... })`. Nested transactions flatten into the outermost. Redo stack cleared on new command (standard linear undo, do not build an undo *tree* for v1).
- **Coalescing:** merge the incoming command into the stack top iff `mergeKey` matches, same transaction is still open, **and** `now - top.timestamp < 400ms`. Use this for property-inspector typing (renaming a device = one entry) and nudge-by-arrow-key repeats. You do **not** need it for drags, the "gesture end commits" rule from §1 already collapses those.
- **Selection is not document state, but undo restores it.** Every `Transaction` captures `selectionBefore`/`selectionAfter`; undo applies `selectionBefore`, redo applies `selectionAfter`. Also: after undoing a device deletion, re-select the restored device, users expect it.
- **Memory:** a fully-loaded rack document is on the order of 100–500 KB of JSON. Commands storing before/after field values are *tiny* (tens of bytes). A 500-entry history costs single-digit MB. Cap at 200 entries or ~64 MB, whichever first; nobody will hit it.

**Pragmatic hybrid worth adopting:** for genuinely awkward-to-invert bulk operations (auto-arrange, import, "renumber all reference designators"), don't write a hand-inverted command, snapshot just the affected entities' JSON before and after and store that as a `SnapshotCommand`. You get correctness immediately and pay a few KB. Reserve precise commands for the high-frequency operations.

**Deliberately deferred:** don't reach for JSON Patch ([`json_patch`](https://pub.dev/packages/json_patch)). It sounds elegant, but computing a diff requires serializing the whole document on every edit, and patches are opaque, you lose the human-readable `label` that the Edit menu and history panel need.

---

## 3. Immutable modelling in Dart 3.12

### Findings

**Macros are dead.** The Dart team halted development in **January 2025** (after ~2 years and ~1,400 upvotes) because the deep semantic introspection macros required broke incremental compilation and hot reload. The experimental macros documentation page was removed. What survives is **augmentations**, shipping as a standalone language feature (splitting a class definition across files), plus a commitment to improve `build_runner` performance and an RFC for a new serialization protocol (codename **"codable"**). Sources: [Dominik Roszkowski's write-up](https://occasionalflutter.substack.com/p/dart-macros-are-not-coming), [HN discussion of the official post](https://news.ycombinator.com/item?id=42871867), [dart.dev/resources/whats-new](https://dart.dev/resources/whats-new).

**Consequence: there is no codegen-free path to generated `==`/`hashCode`/`copyWith`/`fromJson` in Dart 3.12, and there will not be one soon.** Anyone planning around macros must replan.

Package state:

| Package | Version | Notes |
|---|---|---|
| [`freezed`](https://pub.dev/packages/freezed) | **3.2.5** (Feb 2026); **4.0.0-dev.3** (~Jun 2026) | still the default |
| [`json_serializable`](https://pub.dev/packages/json_serializable) | **6.14.0** | Google, 3.9k likes, 3.14M downloads |
| [`dart_mappable`](https://pub.dev/packages/dart_mappable) | 4.x | best-in-class generics/polymorphism; [benchmarks show it ~2× slower](https://helight.medium.com/benchmarking-darts-json-serialization-and-dataclass-ecosystem-a49969861d08) on serialization and slowest on equality |
| `built_value` | maintained | legacy; don't start here in 2026 |

Freezed 3.x notably **removed `map`/`when`** in favour of native Dart 3 pattern matching, and added "mixed mode" (classic factory syntax *and* plain-class syntax), inheritance, and non-const defaults. Freezed 4.0 is in dev with no public changelog yet, **do not adopt 4.0.0-dev on a project you're starting now.**

### Recommendation

**Do not make the whole document immutable. Stratify it.**

```
Immutable value objects        → plain Dart / records / sealed classes, hand-written
  ConnectorType, RuPosition, PortRef, CableType, Rgb, Point
  → sealed class + pattern matching; records for tuples; const constructors

Mutable entities (identity)    → plain mutable classes with UUID identity
  RackDevice, Port, Connection, StructureEntry, Rack
  → mutated ONLY inside Command.apply/revert

Document root                  → mutable aggregate: flat Map<Uuid, Entity> (see §6)
```

Rationale: full immutability in Dart without optics means `doc.copyWith(devices: {...doc.devices, id: dev.copyWith(ports: [...])})` on every edit, deep `copyWith` chains are the single biggest source of tedium and bugs in Flutter document editors, and Dart has no lens library worth using. Meanwhile the *reason* people reach for immutability (safe undo) you are already getting from the command stack, and the *other* reason (change detection) you are getting from explicit revision counters. Mutable + monopolized mutation pipeline is strictly simpler here and is what super_editor, Figma, and every CAD tool actually do.

**Where to use freezed:** the small, genuinely-immutable leaf types where `==`/`hashCode` matter, and only if you want it. Honestly, for ~15 value types, `sealed class` + `const` constructors + a hand-written `==` (or a `records`-based `_key` getter) is competitive and costs you zero build time. Dart 3's sealed classes + exhaustive `switch` cover the union-type use case that was freezed's killer feature, natively.

**My opinionated call: start RackMate with zero `build_runner`.** Hand-write the ~15 value types and the JSON codecs (see §4 for why hand-written JSON is *actively better* here). If the model triples in size and the boilerplate hurts, add freezed then, retrofitting freezed onto a plain class is a mechanical change, whereas ripping codegen out later is not. This also keeps `rackmate_core` a dependency-light pure-Dart package with sub-second test cycles, which is worth a lot over a multi-year project.

---

## 4. JSON serialization + schema versioning

### Findings

The consensus migration architecture ([offlinetools](https://offlinetools.org/a/json-formatter/schema-versioning-for-json-configuration-files), [jsonic migration guide](https://jsonic.io/guides/json-migrations), [ELCA/MongoDB case study](https://medium.com/elca-it/schema-versioning-and-upgrade-in-document-store-implementation-with-java-mongodb-and-springdata-bbd4062c9819)):

- Root-level integer `schemaVersion` written into every document.
- Migrations are **pure functions on raw JSON maps**, `vN → vN+1`, held in a registry keyed by version, composed by an orchestrator to bridge arbitrary gaps.
- Migrate the raw map to the current shape **before** any typed deserialization happens. Never migrate typed objects.
- Additive-only changes for backward compat; deprecate rather than remove/rename.
- Keep app version and schema version strictly separate.

### Recommendation

**Hand-write `toJson`/`fromJson` for the persisted model. Do not use `json_serializable` or freezed's JSON for the file format.**

This is a contrarian call, so the reasoning: generated JSON *couples your on-disk format to your class shape*. Every refactor of a Dart class silently changes the file format. For a format that must be readable in 2031, that coupling is the bug. Hand-written codecs make the wire format an explicit, reviewable, diffable artifact, and the format is the product's most durable asset. Generated codecs are the right answer for ephemeral API DTOs; they are the wrong answer for a document format. Cost is roughly 300 lines you write once.

If you want codegen anyway, use **`json_serializable` 6.14.0** (Google-maintained, huge install base) over `dart_mappable`, but then introduce an explicit DTO layer so the generated classes are *format* classes, separate from domain classes. That's more code than just hand-writing it.

```dart
// rackmate_core/lib/src/persistence/
const kCurrentSchemaVersion = 1;

typedef JsonMap = Map<String, dynamic>;
typedef Migration = JsonMap Function(JsonMap);

const migrations = <int, Migration>{
  // 1: _v1ToV2,   // added when v2 ships; NEVER deleted, NEVER edited afterwards
};

JsonMap migrateToCurrent(JsonMap raw) {
  var v = raw['schemaVersion'] as int?
      ?? (throw FormatException('Not a RackMate document'));
  if (v > kCurrentSchemaVersion) throw NewerSchemaException(v);
  while (v < kCurrentSchemaVersion) {
    raw = migrations[v]!(raw);
    v = raw['schemaVersion'] as int;   // each migration bumps it itself
  }
  return raw;
}
```

Rules to commit to on day one:

1. **`schemaVersion` (int) + `appVersion` (string, diagnostics only) + `generator: "RackMate"` magic key** at the root. The magic key lets you reject foreign JSON with a good error instead of a null-cast crash.
2. **Migrations are append-only and frozen once released.** A migration function is a historical record; editing one corrupts users' files.
3. **Golden fixture corpus.** `test/fixtures/v1_sample.rackmate`, `v2_sample.rackmate`, … Every release, a test opens *every* historical fixture and asserts it migrates to a valid current document. This is the single highest-value test in the project. Add a fixture the day each schema version ships.
4. **Forward compatibility: preserve unknown fields.** Each entity keeps `Map<String, dynamic> _unknown` for keys it didn't recognize, and re-emits them on save. A v1.0 app opening a v1.4 file then round-trips without destroying the newer data. Combine with a **`minReaderVersion`** field: bump it only for genuinely breaking changes; if `minReaderVersion > kCurrentSchemaVersion`, refuse to open with "This file was made with a newer RackMate." Otherwise open read-only with a warning banner. This two-field scheme (`schemaVersion` + `minReaderVersion`) is how you get both "old app opens new file" and "old app can't silently corrupt new file."
5. **Enums are strings, never ordinals.** `"hdmi"`, not `3`. Unknown enum value → fall back to an `unknown(raw)` sealed variant that round-trips, don't throw. This matters enormously for `CableType`, which will grow.

---

## 5. File I/O for a desktop document app

### Findings

| Package | Version | Publisher | Verdict |
|---|---|---|---|
| [`file_selector`](https://pub.dev/packages/file_selector) | **1.1.0** | **flutter.dev (verified)** | official; calls native OS APIs |
| [`file_picker`](https://pub.dev/packages/file_picker) | 8.x | miguelpruivo (3rd party) | more popular; on macOS/Linux [historically shells out to spawn dialogs](https://github.com/miguelpruivo/flutter_file_picker/wiki/FAQ) |
| [`window_manager`](https://pub.dev/packages/window_manager) | **0.5.2** | 1.1k likes, 494k downloads | de-facto standard |
| [`archive`](https://pub.dev/packages/archive) | **4.0.9** | 900 likes, 10.7M downloads | pure Dart zip; 4.x renamed `decodeBuffer`→`decodeStream`, `InputStream`→`InputMemoryStream` |
| [`path_provider`](https://pub.dev/packages/path_provider) | 2.x | flutter.dev | `getApplicationSupportDirectory()` |
| [`desktop_drop`](https://pub.dev/packages/desktop_drop) | 0.6.x |: | drag-and-drop file onto window |
| [`pdf`](https://pub.dev/packages/pdf) | **3.13.0** | nfet.net, 3k likes | Flutter-like widget API, `MultiPage`, tables, vector/SVG, for requirement #7 |

`file_selector` supports `getSaveLocation()` on Windows/macOS/Linux and `getDirectoryPath()` on Windows/macOS/Linux/Android. `window_manager` covers size, position, appearance, close behaviour and event listening.

### Recommendation

**`file_selector` 1.1.0.** It's the flutter.dev package, it uses native OS APIs rather than shelling out, and desktop is exactly where that difference bites. `file_picker`'s popularity is driven by mobile.

**Container format:** ship v1 as **plain, pretty-printed, key-sorted JSON**: `.rackmate` is a text file. Benefits: users can diff it in git, you can eyeball bug reports, and support requests become readable. Pretty-print + deterministic key order makes the file diff-friendly, which matters more than the ~3× size.

But **hide it behind an interface from commit one**, because the moment someone embeds a device faceplate PNG you need a zip:

```dart
abstract class DocumentCodec {
  Future<RackDocument> read(Uint8List bytes);
  Future<Uint8List> write(RackDocument doc);
}
// v1: PlainJsonCodec.  v2: ZipCodec (archive 4.0.9) with document.json +
// assets/<uuid>.png + manifest.json. Sniff the PK\x03\x04 magic on read to
// dispatch — the extension never changes, old files keep opening forever.
```

**Atomic saves, always:** write to `foo.rackmate.tmp` in the same directory → `flush()` → `rename()` over the target. A crash mid-save must never destroy the previous good file. Optionally keep `foo.rackmate.bak` (previous version), cheap insurance, users love it.

**Dirty tracking via revision counters, not equality:**
```dart
int revision;              // monotonic, ++ on every committed command
int lastSavedRevision;
bool get isDirty => revision != lastSavedRevision;
```
Never compare documents for equality to detect dirtiness, it's O(document) on every keystroke and gets subtly wrong with floats. Note this gives correct behaviour for free when the user undoes back to the saved state… *if* you make undo restore the revision rather than increment it. Decide deliberately; I'd restore (undoing back to the save point marks the doc clean, matches user intuition).

**Autosave / crash recovery:** every 30s *and* on window blur, if dirty, write a recovery snapshot to `getApplicationSupportDirectory()/recovery/<docUuid>.rackmate` plus a small sidecar recording the real path and revision. Delete on clean save and on clean exit. On startup, any surviving recovery file ⇒ offer "RackMate closed unexpectedly. Recover *Smith Residence Rack 2*?" Do **not** autosave over the user's file, CAD users expect explicit saves.

**Close interception:**
```dart
await windowManager.setPreventClose(true);
// in WindowListener.onWindowClose: if (!isDirty) destroy();
//   else show Save / Don't Save / Cancel  → the three-button dialog, not two
```
Bind `Ctrl+S`, `Ctrl+Shift+S`, `Ctrl+O`, `Ctrl+N`, `Ctrl+Z`, `Ctrl+Y`/`Ctrl+Shift+Z` through Flutter's `Shortcuts`/`Actions` so they work identically from menu and keyboard, and so the menu can render the accelerator labels from one source.

**Recent files:** a JSON list in app-support dir (path, display name, last-opened, thumbnail path). Not `shared_preferences`, you'll want a thumbnail and metadata, and prefs is the wrong shape. Prune entries whose file no longer exists, but only lazily (network drives go away and come back).

---

## 6. Stable IDs and cloud-readiness

### Findings

[`uuid` 4.6.0](https://pub.dev/packages/uuid) (published ~2 days ago) supports **RFC 9562 v6, v7 and v8** in addition to RFC 4122 v1/v4/v5.

Dart CRDT options are thin: [`crdt`](https://pub.dev/packages/crdt) (native Dart, generic), [`sql_crdt`](https://pub.dev/packages/sql_crdt), and [`y_crdt`](https://pub.dev/packages/y_crdt), a Yjs port that runs the real implementation **via WASM (`wasm_run`)**, which is a heavy and fragile dependency for a desktop app. In the wider ecosystem [Yjs is the production default](https://www.pkgpulse.com/guides/yjs-vs-automerge-vs-loro-crdt-libraries-2026); nothing Dart-native is close to production-grade for rich document CRDTs.

### Recommendation

**UUID v7 for all entity IDs.** No downside vs v4 here and three real upsides: time-ordered so debugging/log-reading is sane, stable natural sort order for "creation order" without a separate field, and index locality if these ever land in a database. (v7 embeds a creation timestamp, irrelevant for rack diagrams.)

**Do not build CRDT now.** Rack design is overwhelmingly single-user-at-a-time; the complexity cost is enormous and no Dart library is ready. **But make five cheap decisions now** that keep both LWW *and* CRDT viable later:

1. **Flat entity maps, not a nested tree.**
   ```dart
   Map<Uuid, RackDevice> devices;
   Map<Uuid, Connection> connections;
   Map<Uuid, Port> ports;          // ports reference deviceId, not nested inside
   ```
   This is the highest-leverage decision in the whole document. It simultaneously enables: per-entity LWW sync, cheap command implementation (a command touches one map entry), fine-grained repaint invalidation, and O(1) lookup during wire routing. Nested trees make all four hard.

2. **Never use array index as identity.** Ordering (device stacking, port order, connection z-order) uses an explicit **fractional index string** (LexoRank / Figma-style `"a0"`, `"a0V"`, `"a1"`) so an insert between two items is a purely local edit that can't collide. Integer `sortOrder` requires renumbering neighbours, which is the classic thing that makes sync impossible to retrofit.

3. **Per-entity metadata on every entity:** `createdAt`, `updatedAt` (UTC, microsecond), `updatedBy` (device/user id, a local UUID for now). This is exactly the LWW tuple; adding it later means a schema migration that can't backfill honest values.

4. **Document-level monotonic `revision`** (already needed for dirty-tracking, §5) doubles as the sync cursor.

5. **Deletions are the one thing that genuinely breaks retrofits.** If you hard-delete, a later sync can't distinguish "peer deleted it" from "peer never had it." Cheapest hedge: keep a `Set<Uuid> tombstones` with `deletedAt` in the document. It's a few bytes per delete and it also makes your delete-commands trivially invertible for undo. Do this now.

With those five, adding last-write-wins-per-field sync later is a weekend; adding a real CRDT is a rewrite but a *possible* one. Without #1 and #2, both are rewrites.

---

## 7. Project structure & testing

### Findings

**Dart 3.6+/Flutter 3.27+ ship native [pub workspaces](https://dart.dev/tools/pub/workspaces)** (`resolution: workspace` in member pubspecs, shared lockfile, shared resolution). [`melos` 8.2.2](https://pub.dev/packages/melos) (Invertase, published ~4 days ago, actively maintained) has been rebuilt on top of pub workspaces rather than generating `pubspec_overrides.yaml`. The two are now complementary: **workspaces do dependency resolution; melos does workflow orchestration**: filtered scripts ("test only packages changed since last commit"), conventional-commit versioning, changelogs, publishing.

### Recommendation

**Use pub workspaces. Skip melos until it earns its place** (probably when you have >4 packages or start publishing them). For a 2–3 package repo, melos is orchestration you don't need yet, and it's easy to add later.

```
rackmate/
  pubspec.yaml                         # workspace root: workspace: [packages/*, apps/*]
  packages/
    rackmate_core/                     # PURE DART — no flutter dependency
      lib/src/model/                   #   entities, value objects, flat maps
      lib/src/commands/                #   Command, Transaction, UndoStack
      lib/src/persistence/             #   codec, schemaVersion, migration chain
      lib/src/geometry/                #   RU math, port coordinates, orthogonal routing
      lib/src/netlist/                 #   wiring schedule derivation, DRC/validation
      test/                            #   dart test — sub-second, no flutter
      test/fixtures/                   #   v1_sample.rackmate, v2_sample.rackmate, ...
    rackmate_ui/                       # Flutter: painters, widgets, theme, cable colours
      test/goldens/
  apps/
    rackmate_app/                      # Flutter desktop shell: menus, windows, file dialogs
      integration_test/
```

The hard rule that makes this pay off: **`rackmate_core` must not import `package:flutter`.** Not for `Offset`, not for `Color`, not for `Rect`. Define your own `Pt`, `Rgb`, `Box` (they're 10 lines each) with adapters in `rackmate_ui`. The payoff is that your entire model, undo stack, migration chain, orthogonal wire router and netlist derivation test in `dart test` in under a second with no widget tree; you will run those tests a thousand times.

Inside `rackmate_app`, **feature-first** (`features/rack_canvas/`, `features/device_builder/`, `features/wiring/`, `features/export_pdf/`, `features/library/`). Layer-first collapses at this size.

**Testing strategy, in priority order:**
1. **Migration golden corpus** (§4.3), highest value per line of test code in the project.
2. **Command round-trip property tests:** for a randomly generated document and a random command, `apply` then `revert` must produce a document byte-identical to the original when re-serialized. This one test catches nearly every undo bug you would otherwise ship. Trivially expressible because core is pure Dart.
3. **Serialization round-trip:** `doc → json → doc → json` is stable, plus unknown-field preservation.
4. **Geometry/routing unit tests**: orthogonal trace routing and port coordinate math are pure functions; test them exhaustively without a canvas.
5. **Golden tests** for the painters (`flutter_test` `matchesGoldenFile`). Caution: goldens are fragile across Flutter versions and platforms, pin the Flutter version in CI, keep golden scenes small and deterministic (fixed seed, fixed fonts, no animation), and don't golden the entire canvas. Golden the *device face renderer* and the *wire layer* separately.
6. **Integration tests** for the file lifecycle: new → edit → save → close → reopen → verify; and the unsaved-changes-on-close dialog.

---

## 8. Flutter desktop on Windows: specifics and rough edges

### Findings

- **[`PlatformMenuBar`](https://api.flutter.dev/flutter/widgets/PlatformMenuBar-class.html) is macOS-only out of the box.** Docs: *"Flutter only includes support for macOS out of the box, but support for other platforms may be provided via plugins that set `WidgetsBinding.platformMenuDelegate`."* The class example explicitly states it only works on macOS. **There is no native Win32 menu bar in Flutter.**
- **[`MenuBar`](https://api.flutter.dev/flutter/material/MenuBar-class.html) (Material) is the cross-platform answer**: Flutter-rendered cascading menus, works on Windows/Linux/macOS/web. `MenuAnchor` is the lower-level primitive for context menus. `MenuAcceleratorLabel` (Alt+F style accelerators) works on Windows/Linux, unsupported on macOS/iOS.
- **Multi-window: not ready.** Canonical's work is [still under engine/framework review](https://ubuntu.com/blog/multiple-window-flutter-desktop) as of this research; Windows lands first, Linux and macOS "soon." The [official 2026 roadmap](https://github.com/flutter/flutter/blob/main/docs/roadmap/Roadmap.md) says only *"our partners at Canonical continue to make progress on improving multi-window support"*, no commitment, no version. Third-party [`desktop_multi_window`](https://pub.dev/packages/desktop_multi_window) exists but each window is a separate isolate/engine with no shared memory, which is fatal for a shared document model.
- Impeller on desktop is not in the 2026 roadmap document; desktop remains Skia. `[weak]`, several blogs claim desktop Impeller in 2026, but the roadmap itself does not say so.

### Recommendation

**Menus:** use Material **`MenuBar`** for Windows. Do *not* try to get native Win32 menus, the plugin ecosystem there is unmaintained and the visual difference is negligible in a dark-themed pro tool. But **abstract the menu into a data model in your app layer**:

```dart
// One tree of AppMenuItem { label, shortcut, intent, enabled, checked }
//  → renders to MenuBar on Windows/Linux
//  → renders to PlatformMenuBar on macOS (native menu, required for App Store polish)
```
Every item dispatches an `Intent` through `Actions`, so the menu item, the keyboard shortcut, the toolbar button and the context menu all funnel to one `Action`, with one enablement rule. This also makes menu state (greyed-out Undo, checked "Show Rear View") derive automatically from the document, and it's the only structure that makes a later macOS port cheap.

**Windowing:** `window_manager` 0.5.2 for title (`Smith Residence — RackMate` with a `•` dirty marker), size/position restore across launches, minimum window size (set one, a rack editor below ~1000px is unusable), and `setPreventClose` for the save prompt.

**Multi-window:** design for it, don't build it. The one thing that matters is **no global singletons for document state**: one `ProviderScope` per document (§1) means "open a second document" is already correct in-process, and becomes multi-window mechanically when the API lands. Ship v1 as single-window, possibly with in-app document tabs.

**Rough edges to plan around on Windows:**
- No native menus (above); no native context-menu look, you're drawing Material menus.
- **Text input on a canvas** (inline device renaming, port labels) is the classic Flutter desktop pain point: IME positioning, right-click context menu, and text selection on a `CustomPaint` are all manual. Recommendation: **don't do inline canvas editing in v1.** Edit names in a properties inspector panel with a real `TextField`. This dodges an entire category of platform bugs and is also what CAD tools do.
- **DPI / display scaling:** Windows users run 125%/150% scaling and mixed-DPI multi-monitor setups. Do all canvas geometry in *document units* (1 RU = 44.45mm, and keep it metric internally) with an explicit zoom transform; never in logical pixels. Test dragging the window between a 4K and a 1080p monitor, that path breaks naive implementations.
- **File drag-and-drop onto the window** needs [`desktop_drop`](https://pub.dev/packages/desktop_drop); not built in.
- **Right-click** needs `Listener`/`GestureDetector` with `PointerDeviceKind` checks; `onSecondaryTap` exists but pair it with hover cursors (`MouseRegion` + `SystemMouseCursors.resizeUpDown` etc.), desktop users read the cursor to know what's draggable.
- **Trackpad/scroll semantics:** handle `PointerScrollEvent` for pan, `Ctrl+scroll` for zoom, and `PointerScaleEvent` for trackpad pinch. Getting zoom-to-cursor right (zoom anchored at the pointer, not the viewport centre) is table stakes and is easy to get subtly wrong.
- **PDF export** ([`pdf` 3.13.0](https://pub.dev/packages/pdf)): its `pw.Widget` layout system covers the wiring *schedule* table well (`MultiPage` auto-paginates with repeating headers). For the *diagram*, do **not** re-implement your painter in `pw` widgets, render your canvas geometry to vector via `pw.CustomPaint`/path primitives from the same `rackmate_core` geometry code, so the PDF and the screen can never diverge. Rasterizing the canvas to a PNG and embedding it is the tempting shortcut and it produces unprofessional output for a document an installer will print at A3 and mark up by hand.

---

## Summary of recommendations

| # | Topic | Recommendation |
|---|---|---|
| 1 | State mgmt | Riverpod **3.3.2** no-codegen as DI/lifetime only; document owned by plain-Dart `DocumentController`; canvas repaints via `CustomPainter(repaint: Listenable)`; 4 layered `RepaintBoundary`s; **drags never touch the document until `onPanEnd`** |
| 2 | Undo/redo | Hand-rolled Command + Transaction + `UndoStack` (~200 LOC) in core. No package. Coalesce by `mergeKey` + 400ms. Selection captured before/after per transaction. Snapshot-commands for bulk ops |
| 3 | Modelling | **Macros are cancelled (Jan 2025): plan without them.** Stratify: immutable value objects (plain Dart sealed classes/records), mutable identity entities, mutation monopolized by commands. Start with **zero build_runner**; add freezed 3.2.5 only if boilerplate hurts. Avoid freezed 4.0.0-dev |
| 4 | Serialization | **Hand-written** `toJson`/`fromJson`: the file format is the durable asset, don't couple it to class shape. `schemaVersion` + `minReaderVersion` + append-only pure-JSON migration chain + **golden fixture corpus per version** + unknown-field preservation + string enums |
| 5 | File I/O | `file_selector` **1.1.0** (flutter.dev). Plain JSON v1 behind a `DocumentCodec` interface (→ `archive` 4.0.9 zip later, sniffed by magic bytes). Atomic temp+rename. Revision-counter dirty tracking. `window_manager` 0.5.2 `setPreventClose`. Autosave to a separate recovery dir, never over the user's file |
| 6 | IDs / cloud | **UUID v7** (`uuid` 4.6.0). No CRDT now. But now: flat `Map<Uuid,Entity>` (not nested), fractional-index ordering strings, per-entity `updatedAt`/`updatedBy`, doc `revision`, and **tombstones for deletes** |
| 7 | Structure | Pub workspaces (skip melos for now). `rackmate_core` **must not import flutter**. Feature-first in the app. Test priority: migration goldens → command apply/revert round-trip property tests → serialization round-trip → geometry → painter goldens → integration |
| 8 | Windows | Material `MenuBar` (PlatformMenuBar is macOS-only); menu as a data model dispatching `Intent`s through `Actions`. Multi-window not ready, one `ProviderScope` per document keeps the door open. No inline canvas text editing in v1. Geometry in document units, not pixels. Vector PDF, not rasterized |

**Sources:**
[riverpod](https://pub.dev/packages/riverpod) · [Riverpod 3.0 what's new](https://riverpod.dev/docs/whats_new) · [riverpod_generator](https://pub.dev/packages/riverpod_generator) · [Riverpod RFC #4008](https://github.com/rrousselGit/riverpod/issues/4008) · [signals](https://pub.dev/packages/signals) · [CustomPainter](https://api.flutter.dev/flutter/rendering/CustomPainter-class.html) · [shouldRepaint](https://api.flutter.dev/flutter/rendering/CustomPainter/shouldRepaint.html) · [High-performance canvas rendering](https://plugfox.dev/high-performance-canvas-rendering/) · [super_editor Undo/Redo design](https://github.com/Flutter-Bounty-Hunters/super_editor/wiki/Design-Thoughts:-Undo-Redo) · [super_editor How it works: The Editor](https://github.com/Flutter-Bounty-Hunters/super_editor/wiki/How-it-works:-The-Editor) · [undo](https://pub.dev/packages/undo) · [freezed](https://pub.dev/packages/freezed) · [freezed versions](https://pub.dev/packages/freezed/versions) · [json_serializable](https://pub.dev/packages/json_serializable) · [Dart macros are not coming](https://occasionalflutter.substack.com/p/dart-macros-are-not-coming) · [HN: update on Dart macros](https://news.ycombinator.com/item?id=42871867) · [dart.dev what's new](https://dart.dev/resources/whats-new) · [Dart serialization benchmarks](https://helight.medium.com/benchmarking-darts-json-serialization-and-dataclass-ecosystem-a49969861d08) · [Schema versioning for JSON config](https://offlinetools.org/a/json-formatter/schema-versioning-for-json-configuration-files) · [JSON migration strategy](https://jsonic.io/guides/json-migrations) · [Schema versioning in document stores](https://medium.com/elca-it/schema-versioning-and-upgrade-in-document-store-implementation-with-java-mongodb-and-springdata-bbd4062c9819) · [file_selector](https://pub.dev/packages/file_selector) · [file_picker FAQ](https://github.com/miguelpruivo/flutter_file_picker/wiki/FAQ) · [window_manager](https://pub.dev/packages/window_manager) · [archive](https://pub.dev/packages/archive) · [pdf](https://pub.dev/packages/pdf) · [uuid](https://pub.dev/packages/uuid) · [crdt.tech implementations](https://crdt.tech/implementations) · [y_crdt](https://pub.dev/packages/y_crdt) · [Yjs vs Automerge vs Loro 2026](https://www.pkgpulse.com/guides/yjs-vs-automerge-vs-loro-crdt-libraries-2026) · [Dart pub workspaces](https://dart.dev/tools/pub/workspaces) · [melos](https://pub.dev/packages/melos) · [PlatformMenuBar](https://api.flutter.dev/flutter/widgets/PlatformMenuBar-class.html) · [MenuBar](https://api.flutter.dev/flutter/material/MenuBar-class.html) · [Flutter Roadmap](https://github.com/flutter/flutter/blob/main/docs/roadmap/Roadmap.md) · [Canonical multi-window](https://ubuntu.com/blog/multiple-window-flutter-desktop) · [Speeding up build_runner](https://codewithandrea.com/tips/speed-up-code-generation-build-runner-dart-flutter/)