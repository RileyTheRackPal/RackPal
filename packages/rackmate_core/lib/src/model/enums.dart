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
/// APPENDED, NEVER REORDERED. `bindingPost` is last because these
/// serialize by NAME and a `values` reorder is still a diff nobody can
/// review; new cases go on the end so a reader can see the history.
enum TerminationType {
  keystone,
  punchdown,
  fBarrel,
  euroblock,
  unterminated,
  fieldConnector,

  /// A single-post speaker terminal, ONE PER CONDUCTOR.
  ///
  /// Added by M3-H (DR-007 §11.7.2.1), which says exactly why: the
  /// cells a field end needs is "a function of TERMINATION, not of the
  /// cable", `TerminationType` "already carries exactly this
  /// distinction and is the hook M3 should read", and "it does not yet
  /// name a binding-post case, and adding one is the smallest change
  /// that makes this table computable".
  ///
  /// THIS IS THE ONLY VALUE THAT COUNTS CONDUCTORS. Every other
  /// termination here occupies one cell per `Link` end however many
  /// conductors the cable has: a Cat6 run in one RJ45 is one cell, not
  /// eight. A 16/4 speaker run is four, which is §11.7.2.2's case that
  /// bites, because four cells do not fit on a 1-, 2- or 3-port strap
  /// at all. See `derived/plate_fill.dart`.
  ///
  /// NOT A MIGRATION. Adding a value to an enum that serializes by name
  /// leaves every written document byte-identical; no file in existence
  /// contains this name, so `kSchemaVersion` does not move (CR-117).
  bindingPost,
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
