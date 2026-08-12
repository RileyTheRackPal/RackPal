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

  /// A field-crimped male RJ45, pushed straight into the device.
  ///
  /// Added by M3-M (DR-045 §11.44.1). **NOT [keystone] AND NOT
  /// [punchdown]**: both of those are a jack, and the entire point of
  /// this termination is that there is no jack. Nor is it
  /// [fieldConnector], which names no connector and would leave the
  /// Termination Schedule saying nothing to somebody deciding between a
  /// crimper and a punchdown tool.
  ///
  /// THE REASON IS RELIABILITY, NOT TIDINESS. A keystone plus a patch
  /// cable puts two extra mated connections on a link carrying
  /// uncompressed video, and AVoIP and HDBaseT vendors recommend a
  /// continuous run for exactly that. The other volume case is an access
  /// point that mounts directly to the low-voltage box: no plate, no
  /// strap, nothing for a jack to sit in.
  ///
  /// **ZERO CELLS** (§11.44.2), beside [euroblock], [unterminated] and
  /// [fieldConnector]. The plug goes into the device. This was ASKED
  /// rather than inferred, because inferring it for [euroblock] is a
  /// defect that shipped in M3-H and had to be corrected at DR-044.
  rj45Plug,
}

/// What kind of hole a gang opening is, when it is a hole rather than a
/// strap (DR-047 §11.46.3).
///
/// TWO VALUES BECAUSE THE USER NAMED TWO PARTS, and a third was offered
/// and declined. Asked which pass-throughs they buy, the answer was a
/// whole brush plate, a Decora-format brush insert and a bull-nose or
/// grommet plate. The first two are the same opening in two forms, and
/// `derived/plate_fill.dart` derives which; the third is a different
/// opening and is [bullNose].
///
/// **A KEYSTONE-FORMAT BRUSH INSERT WAS DECLINED**, so there is no
/// fourth `CellOccupant` and nothing about this enum touches a strap's
/// cells. §11.44.2 made "how many cells, and which parts" a question
/// this project asks out loud every time a vocabulary grows, after
/// inferring it for `euroblock` cost a correction a milestone later.
enum PassThroughStyle {
  /// Bristles across the opening: cables pass and the hole is hidden.
  brush,

  /// A hard opening or a rubber grommet rather than bristles.
  bullNose,
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
