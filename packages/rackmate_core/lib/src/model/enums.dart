// Shared, cross-file enums (docs/02-data-model.md §4). An enum lives here
// only when more than one model/ file needs it; an enum specific to a
// single entity lives beside that entity instead (e.g. `RackWidthClass` in
// rack.dart, `SheetKind` in sheet.dart).

/// Five values, shared identically by `DeviceInstance` and `Link` — never
/// split into two enums (CR-064, CR-065, AC-018, canon §4.2).
///
/// `new` is a reserved word in Dart, so the second value is spelled
/// `new_`; every other layer (JSON, UI label) still renders it as `new`.
enum LifecycleStatus { existing, new_, future, removed, designIntent }

/// Severity vocabulary for the DRC catalogue (§5.3). "info" is renamed
/// `advisory` everywhere (CR-018).
enum Severity { error, warning, advisory, off }

/// How a conductor endpoint that isn't a live port yet is meant to be
/// terminated — used by `PlaceEndpoint.intendedTermination` and by
/// `StructureOrigin.terminationField`.
enum TerminationType {
  keystone,
  punchdown,
  fBarrel,
  euroblock,
  unterminated,
  fieldConnector,
}

/// Which surface an `Outlet` or a `StructureOrigin` field end is mounted
/// on. §4.7, m24.
enum MountSurface { wall, ceiling, floor, soffit, exterior, inGround }

/// Which wall of a room an outlet/origin sits against. Shared by
/// `Outlet` and `StructureOrigin`.
///
/// M0 MINIMAL SHAPE: docs/02-data-model.md does not enumerate this type's
/// values (only `MountSurface`'s, in the comment beside both fields). The
/// value set below is transcribed from docs/research/design-data-model.md
/// line 645 (`n | s | e | w | c | ne | nw | se | sw | ceiling | floor`);
/// `ceiling`/`floor` overlap `MountSurface` there and are kept as cited
/// rather than silently trimmed.
enum Wall { n, s, e, w, c, ne, nw, se, sw, ceiling, floor }

/// Screen/print measurement system for `ProjectSettings.displayUnits` —
/// AUTHORITATIVE over any app-level preference (CR-097). Storage is
/// always exact regardless of this setting (CR-001).
enum UnitSystem { imperial, metric }

/// RU numbering direction. Per-rack, with `ProjectSettings.ruNumbering`
/// only seeding new racks (CR-026); display only, never affects the
/// stored `RailPlacement.ruIndex` (CR-025).
enum RuNumbering { bottomUpFromOne, topDown }

/// Sheet numbering convention (CR-066). `simple` is the default — a
/// residential four-sheet set should not have to satisfy a commercial
/// numbering grammar.
enum SheetNumbering { ncs, simple }
