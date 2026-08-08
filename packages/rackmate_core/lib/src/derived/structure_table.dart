// THE STRUCTURE EDITOR'S TABLE, as a row model. Board M3-C/2 (#148),
// docs/07 §4 and §4.1, AC-048.
//
// ═════════════════════════════════════════════════════════════════════
// IT IS A PROJECTION OF `buildSchedule`, AND THAT IS THE WHOLE DESIGN
// ═════════════════════════════════════════════════════════════════════
// docs/07 §4.1's eight default columns are FIELD LABEL, RACK LBL, OUTLET,
// MEDIA, SERVICE, PATHWAY, RACK TERM and ROUGH-IN. Every one of them is
// already on `ScheduleEntry`, resolved, with its registry lookups done
// and its unknowns counted. So this file filters and regroups; it does
// not re-derive.
//
// A SECOND DERIVATION IS THE FAILURE CR-107 IS ABOUT. That ruling deleted
// `StructureDrop` because two entities carrying media, length, status and
// test result "is guaranteed [to diverge] within one week of real use:
// the drop schedule says 78 ft and the wiring schedule says 90 ft, and
// nobody knows which to bill against." A table that computed its own
// media name and its own termination would be the same divergence one
// layer up, and the editor is the surface people trust MOST because they
// are typing into it.
//
// ═════════════════════════════════════════════════════════════════════
// WHAT IT ADDS THAT THE SHEET DOES NOT HAVE
// ═════════════════════════════════════════════════════════════════════
//  * THE ROOM ORDER IS THE TREE'S, not the sheet's sort. docs/07 §4 draws
//    the table beside the location tree, and a room that sits third in
//    the tree must sit third here or the two panels disagree in front of
//    the person using them. `scheduleViewOf`'s grouping sorts bands by
//    footage or by name, which is right for a sheet nobody is editing.
//  * THE COUNTS THE STATUS BAR PRINTS: `52 drops · 41 connected · 11
//    spare · 9 outlets · 8 pathways`, and the same three per room.
//  * NO PRESET AND NO FILTER. `buildSchedule` is total, one row per
//    `Link`; this keeps every drop on the body, including the ones a
//    Pull Sheet preset would drop. An editor that hid rows would let a
//    person delete a room's last drop and see nothing change.
//
// ═════════════════════════════════════════════════════════════════════
// NO EDITING HERE
// ═════════════════════════════════════════════════════════════════════
// Which `EntityField` a cell writes through, and what a refusal reads
// like, belong with the surface. This answers "what does the table show",
// and it answers it against an unmutated document so a widget can rebuild
// it on every frame.
import 'package:meta/meta.dart';
import 'package:rackmate_core/src/derived/equipment_list.dart'
    show kUnknownCell;
import 'package:rackmate_core/src/derived/location_tree.dart';
import 'package:rackmate_core/src/derived/schedule.dart';
import 'package:rackmate_core/src/model/enums.dart' show UnitSystem;
import 'package:rackmate_core/src/model/link.dart' show RoughInStatus;
import 'package:rackmate_core/src/model/pathway.dart' show PathwayKind;
import 'package:rackmate_core/src/model/rack_document.dart';
import 'package:rackmate_core/src/units/ids.dart';
import 'package:rackmate_core/src/units/len.dart';

/// One room's worth of drops, in the location tree's own order.
@immutable
final class StructureTableGroup {
  const StructureTableGroup({
    required this.locationId,
    required this.title,
    required this.code,
    required this.rows,
    required this.connectedCount,
    required this.spareCount,
    required this.estimatedRunLength,
  });

  /// Null for the trailing band, which has no room.
  final Uuid? locationId;

  /// The room's name, or [kUngroupedTitle] for the trailing band.
  final String title;

  /// `LR`. Empty when the room has no code, which is a real state: a room
  /// created by hand is being named and not labelled (M3-B), and the drop
  /// line refuses to label its drops until somebody fills this in.
  final String code;

  final List<ScheduleEntry> rows;

  /// How many of [rows] land on a real port. See [StructureTable].
  final int connectedCount;

  /// How many are deliberately not landed. COUNTED, not subtracted, for
  /// the reason [StructureTable.hasUnresolvedEnds] gives.
  final int spareCount;

  /// `Location.estimatedRunLengthFromRack`. NULL IS UNKNOWN and prints as
  /// such (G4, CR-114); it is never a zero and never a sum of the drops.
  final Len? estimatedRunLength;

  int get dropCount => rows.length;
}

/// What the Structure editor's table tab shows.
@immutable
final class StructureTable {
  const StructureTable({
    required this.groups,
    required this.dropCount,
    required this.connectedCount,
    required this.spareCount,
    required this.outletCount,
    required this.pathwayCount,
  });

  /// Rooms in the location tree's order, then the trailing band for drops
  /// with no room. A room with no drops is NOT here: the tree beside the
  /// table is what lists every room, and an empty band per room would
  /// push the drops off the screen in a project with forty of them.
  final List<StructureTableGroup> groups;

  final int dropCount;

  /// A drop is CONNECTED when its rack end resolves to a real port on a
  /// device this document holds — `rackPort` or `unrackedPort`. It is
  /// SPARE otherwise, which covers the coil in a J-hook (`open`), the
  /// described place nobody has landed (`place`) and the drop with no
  /// second end at all (`none`).
  ///
  /// `unresolvedPort` COUNTS AS NEITHER, and that is deliberate: a
  /// `PortEndpoint` naming a port this document does not hold is a fault,
  /// not a state, and counting it as connected would report work that
  /// cannot be traced while counting it as spare would invite somebody to
  /// land a second cable on the same panel port. It is in [dropCount] and
  /// in neither of the other two, so the status bar's own arithmetic
  /// exposes it: `drops` stops equalling `connected + spare`.
  final int connectedCount;

  /// COUNTED FROM THE ENDS, NEVER `dropCount - connectedCount`. The
  /// subtraction is the bug this field exists to avoid: it makes
  /// [hasUnresolvedEnds] arithmetically impossible to trip, so a
  /// `PortEndpoint` naming a port nobody holds would be silently reported
  /// as a spare drop. The first version of this class did exactly that
  /// and its own test caught it.
  final int spareCount;

  /// Outlets with at least one drop on this body. NOT `doc.outlets.length`
  /// — an outlet the user created and has not pulled anything to yet is
  /// real, but it is not what "9 outlets" means beside "52 drops".
  final int outletCount;

  /// Distinct pathways named by these drops, on the same rule.
  final int pathwayCount;

  /// True when a `PortEndpoint` names something this document does not
  /// hold, so [connectedCount] and [spareCount] do not add up. The status
  /// bar says so rather than hiding it (G4: every rollup reports what it
  /// could not resolve).
  bool get hasUnresolvedEnds => connectedCount + spareCount != dropCount;
}

/// Builds the table for [structureBodyId], or for every Structure body
/// when it is null.
///
/// PURE, and cheap enough to call on every rebuild: it is one pass over
/// `buildSchedule`'s rows plus one tree walk.
StructureTable buildStructureTable(
  RackDocument doc, {
  Uuid? structureBodyId,
}) {
  final rows = <ScheduleEntry>[];
  for (final row in buildSchedule(doc).rows) {
    final origin = doc.links[row.linkId]?.structureOrigin;
    if (origin == null) continue;
    if (structureBodyId != null && origin.structureBodyId != structureBodyId) {
      continue;
    }
    rows.add(row);
  }

  // Grouped by the room the FIELD end names. `ScheduleEntry.roomId` is
  // already oriented (§3.2 reads a row `FROM — ROOM` then `TO — RACK`),
  // so this does not have to re-decide which end is the wall.
  final byRoom = <Uuid, List<ScheduleEntry>>{};
  final unplaced = <ScheduleEntry>[];
  for (final row in rows) {
    if (row.roomId case final id?) {
      (byRoom[id] ??= []).add(row);
    } else {
      unplaced.add(row);
    }
  }

  final groups = <StructureTableGroup>[];
  for (final id in _roomsInTreeOrder(doc)) {
    final inRoom = byRoom[id];
    if (inRoom == null) continue;
    final location = doc.locations[id];
    groups.add(
      StructureTableGroup(
        locationId: id,
        title: location?.name.trim().isNotEmpty ?? false
            ? location!.name.trim()
            : kUnnamedLocation,
        code: location?.code.trim() ?? '',
        rows: inRoom,
        connectedCount: inRoom.where(_isConnected).length,
        spareCount: inRoom.where(_isSpare).length,
        estimatedRunLength: location?.estimatedRunLengthFromRack,
      ),
    );
  }

  // A DROP WHOSE ROOM IS GONE STILL HAS A BAND. DR-021 clears a deleted
  // location's references to null rather than deleting the drops, and its
  // own §11.20 text names this band as where they land: "so a cleared
  // drop lands in the Pull Sheet's `NO ROOM RECORDED` band instead of
  // vanishing." The editor owes the same, more so, because this is the
  // surface somebody would use to put them back.
  if (unplaced.isNotEmpty) {
    groups.add(
      StructureTableGroup(
        locationId: null,
        title: kUngroupedTitle,
        code: '',
        rows: unplaced,
        connectedCount: unplaced.where(_isConnected).length,
        spareCount: unplaced.where(_isSpare).length,
        estimatedRunLength: null,
      ),
    );
  }

  return StructureTable(
    groups: groups,
    dropCount: rows.length,
    connectedCount: rows.where(_isConnected).length,
    spareCount: rows.where(_isSpare).length,
    outletCount: {
      for (final row in rows)
        if (doc.links[row.linkId]?.structureOrigin case final o?) o.outletId,
    }.length,
    pathwayCount: {
      for (final row in rows)
        if (row.pathwayId case final id?) id,
    }.length,
  );
}

bool _isConnected(ScheduleEntry row) => switch (row.to.kind) {
  ScheduleEndKind.rackPort || ScheduleEndKind.unrackedPort => true,
  _ => false,
};

/// Deliberately not landed: a coil in a J-hook, a described place, or no
/// second end at all. `unresolvedPort` is NEITHER this nor connected.
bool _isSpare(ScheduleEntry row) => switch (row.to.kind) {
  ScheduleEndKind.unresolvedPort => false,
  ScheduleEndKind.rackPort || ScheduleEndKind.unrackedPort => false,
  _ => true,
};

// ═════════════════════════════════════════════════════════════════════
// THE COLUMNS — docs/07 §4.1
// ═════════════════════════════════════════════════════════════════════
// EIGHT DEFAULT, THE REST BEHIND `⚙ Columns`. §4.1 states the split and
// its reason: the defaults are "the ones a person needs to answer 'what
// am I pulling and where does it land'", and RJ-004 demoted jacket colour
// and conduit out of that set and cut reel ID entirely.
//
// THE CELL TEXT IS THE SHEET'S. Six of the eight defaults are already
// `ScheduleColumnId`s, so [structureCell] delegates and the editor cannot
// print a media name the Pull Sheet spells differently. Where there is no
// sheet column — `OUTLET` and `ROUGH-IN` — the string is assembled here,
// once, and the widget takes it.
//
// WHY AN ENUM AND NOT A LIST OF WIDGETS. `⚙ Columns` is a set the user
// toggles and the app persists; a column has to be nameable, orderable
// and storable independently of anything Flutter. That, and the rest of
// this file's reason: none of it may be re-derived per frame.

/// Every column the Structure editor's table can carry.
///
/// ORDERED AS §4.1 LISTS THEM, defaults first, so a `⚙ Columns` menu
/// built by walking `values` reads in the corpus's own order.
enum StructureColumnId {
  // ── the eight defaults ─────────────────────────────────────────────
  fieldLabel,
  rackLabel,
  outlet,
  media,
  service,
  pathway,
  rackTerm,
  roughIn,

  // ── optional, off by default ───────────────────────────────────────
  jacketRating,
  jacketColor,
  jacketColorPulled,
  pathwayKind,
  routedLength,
  cutLength,
  terminatedLength,
  fieldTerm,
  testResult,
  certificateId,
  installedBy,
  notes,
}

/// §4.1's eight, in the wireframe's own left-to-right order.
const List<StructureColumnId> kStructureDefaultColumns = <StructureColumnId>[
  StructureColumnId.fieldLabel,
  StructureColumnId.rackLabel,
  StructureColumnId.outlet,
  StructureColumnId.media,
  StructureColumnId.service,
  StructureColumnId.pathway,
  StructureColumnId.rackTerm,
  StructureColumnId.roughIn,
];

/// Everything `⚙ Columns` offers.
///
/// TWO OF §4.1'S LIST ARE NOT HERE, and both absences are ruled rather
/// than forgotten:
///
///  * **`unknown`-map columns preserved from a CSV import.** There is no
///    CSV importer yet (docs/07 §5, still owed), so there is no unknown
///    map to preserve. A menu entry for a column that can never have a
///    value would be a promise about an unbuilt feature.
///  * **Reel ID**, cut entirely by RJ-004. It is named here so a later
///    reader does not add it back from §4.1's prose.
const List<StructureColumnId> kStructureOptionalColumns = <StructureColumnId>[
  StructureColumnId.jacketRating,
  StructureColumnId.jacketColor,
  StructureColumnId.jacketColorPulled,
  StructureColumnId.pathwayKind,
  StructureColumnId.routedLength,
  StructureColumnId.cutLength,
  StructureColumnId.terminatedLength,
  StructureColumnId.fieldTerm,
  StructureColumnId.testResult,
  StructureColumnId.certificateId,
  StructureColumnId.installedBy,
  StructureColumnId.notes,
];

/// The column header, as §4.1 and the §4 wireframe spell it.
String structureColumnHeader(StructureColumnId id) => switch (id) {
  StructureColumnId.fieldLabel => 'FIELD LABEL',
  StructureColumnId.rackLabel => 'RACK LBL',
  StructureColumnId.outlet => 'OUTLET',
  StructureColumnId.media => 'MEDIA',
  StructureColumnId.service => 'SERVICE',
  StructureColumnId.pathway => 'PATHWAY',
  StructureColumnId.rackTerm => 'RACK TERM',
  StructureColumnId.roughIn => 'ROUGH-IN',
  StructureColumnId.jacketRating => 'RATING',
  // TWO COLUMNS, NOT ONE, and §4.1 spends a paragraph on why: one says
  // what the run IS and drives the keystone, the other says what was
  // actually pulled and is null in the normal case.
  StructureColumnId.jacketColor => 'JACKET',
  StructureColumnId.jacketColorPulled => 'PULLED',
  StructureColumnId.pathwayKind => 'PATHWAY KIND',
  StructureColumnId.routedLength => 'ROUTED',
  StructureColumnId.cutLength => 'CUT',
  StructureColumnId.terminatedLength => 'TERM. LEN',
  StructureColumnId.fieldTerm => 'FIELD TERM',
  StructureColumnId.testResult => 'TEST',
  StructureColumnId.certificateId => 'CERT ID',
  StructureColumnId.installedBy => 'INSTALLED BY',
  StructureColumnId.notes => 'NOTES',
};

/// Points, at the same scale `kPullSheetColumns` uses, so the editor and
/// the printed sheet keep recognisably the same proportions.
double structureColumnWidth(StructureColumnId id) => switch (id) {
  StructureColumnId.fieldLabel => 84,
  StructureColumnId.rackLabel => 62,
  StructureColumnId.outlet => 52,
  StructureColumnId.media => 76,
  StructureColumnId.service => 76,
  StructureColumnId.pathway => 62,
  StructureColumnId.rackTerm => 78,
  StructureColumnId.roughIn => 62,
  StructureColumnId.jacketRating => 48,
  StructureColumnId.jacketColor => 48,
  StructureColumnId.jacketColorPulled => 48,
  StructureColumnId.pathwayKind => 72,
  StructureColumnId.routedLength ||
  StructureColumnId.cutLength ||
  StructureColumnId.terminatedLength => 46,
  StructureColumnId.fieldTerm => 78,
  StructureColumnId.testResult => 44,
  StructureColumnId.certificateId => 72,
  StructureColumnId.installedBy => 84,
  StructureColumnId.notes => 140,
};

/// Whether a person can type into this column.
///
/// FOUR OF TWENTY, AND THE OTHER SIXTEEN ARE NOT "NOT YET" IN THE SAME
/// WAY. docs/07 §4.1 wants inline editing to be the primary path, and
/// these four are the ones that have a `Command` to write through today:
/// `StructureOriginField.fieldLabel` and `.rackLabel`, which refuse a
/// CR-113 collision rather than writing it, plus `LinkField.roughInStatus`
/// and `.notes`.
///
/// The rest fall into three groups, and naming them is the point of this
/// function existing rather than a `switch` inside a widget:
///
///  * DERIVED, and editable only by editing what they derive from.
///    `MEDIA` and `SERVICE` name registry entries, `RACK TERM` is
///    assembled from a termination type and a port designator, `OUTLET`
///    belongs to the `Outlet`. Each needs a picker, not a text box.
///  * MEASUREMENTS in the project's display units. The three length
///    columns and `TEST` want a parser that can refuse `62 ft 3` and a
///    round trip that does not lose the nanometres (CR-001).
///  * JACKET and PULLED, which name convention entries and already have
///    their own two commands; a two-column colour picker is its own
///    gesture.
///
/// None of that is hard. All of it is a decision about a control, and a
/// text box that silently accepted `Cat6a` into a column that stores a
/// `MediaTypeId` would be worse than a cell that cannot be typed into.
bool structureColumnIsEditable(StructureColumnId id) => switch (id) {
  StructureColumnId.fieldLabel ||
  StructureColumnId.rackLabel ||
  StructureColumnId.roughIn ||
  StructureColumnId.notes => true,
  _ => false,
};

/// Right-aligned where the value is a number to compare down a column.
ScheduleAlign structureColumnAlign(StructureColumnId id) => switch (id) {
  StructureColumnId.routedLength ||
  StructureColumnId.cutLength ||
  StructureColumnId.terminatedLength => ScheduleAlign.right,
  _ => ScheduleAlign.left,
};

/// What one cell says.
///
/// [doc] IS REQUIRED AND IS NOT A SMELL. Five optional columns read a
/// field the wiring schedule has no column for (`cutLength`, the test
/// result and its certificate, `installedBy`, the field-end termination),
/// so they come off the `Link` and the `StructureOrigin` rather than off
/// the row. The DEFAULT eight never need it: they are the sheet's.
///
/// EVERY UNKNOWN PRINTS [kUnknownCell] AND NOTHING ELSE (G4, CR-114).
/// There is no empty-string branch below and there must not be one: a
/// blank cell reads as "nothing to say here", and the whole point of the
/// dash is that it reads as "nobody has said".
String structureCell(
  RackDocument doc,
  ScheduleEntry row,
  StructureColumnId id, {
  required UnitSystem units,
}) {
  final link = doc.links[row.linkId];
  final origin = link?.structureOrigin;
  return switch (id) {
    // The sheet's own six. `cell` is the one lookup both presets use;
    // this makes it the one lookup all three surfaces use.
    StructureColumnId.fieldLabel => row.cell(
      ScheduleColumnId.fieldLabel,
      units: units,
    ),
    StructureColumnId.rackLabel => row.cell(
      ScheduleColumnId.rackLabel,
      units: units,
    ),
    StructureColumnId.media => row.cell(ScheduleColumnId.media, units: units),
    StructureColumnId.service => row.cell(ScheduleColumnId.type, units: units),
    StructureColumnId.pathway => row.cell(
      ScheduleColumnId.pathway,
      units: units,
    ),
    StructureColumnId.rackTerm => row.cell(ScheduleColumnId.term, units: units),

    // The two the sheet has no column of its own for. `OUTLET` is half of
    // the Pull Sheet's `FROM (ROOM / OUTLET)`; splitting it is what makes
    // it an editable cell rather than a rendered sentence.
    StructureColumnId.outlet => row.outletDesignation ?? kUnknownCell,
    StructureColumnId.roughIn => roughInLabel(row.roughInStatus),

    StructureColumnId.jacketRating => switch (row.jacketRating) {
      final r? => jacketRatingLabel(r),
      null => kUnknownCell,
    },
    // SPLIT WHERE `jacketColorCell` JOINS. The sheet prints `BLU→YEL` in
    // one cell because a printed row has no room for two; the editor has
    // two columns because they are two facts a person edits separately,
    // and §4.1 says so in as many words.
    StructureColumnId.jacketColor => _jacketToken(
      row.jacketColor.conventionId,
      row.jacketColor.convention?.abbr,
    ),
    StructureColumnId.jacketColorPulled => _jacketToken(
      row.jacketColor.pulledId,
      row.jacketColor.pulled?.abbr,
    ),

    // §4.1's `conduit` COLUMN UNDER ITS CURRENT NAME. CR-016 made the
    // conduit a first-class `Pathway`, so "which conduit" is already the
    // default `PATHWAY` column and a second one naming the same thing
    // would be the RJ-004 demotion undone by accident. What that leaves
    // genuinely invisible is the KIND — whether `PW-LR-1` is conduit,
    // J-hook or tray, which is what `CODE-001` reads.
    StructureColumnId.pathwayKind => switch (row.pathwayId) {
      final pid? => switch (doc.pathways[pid]?.kind) {
        final k? => pathwayKindLabel(k),
        null => kUnknownCell,
      },
      null => kUnknownCell,
    },

    StructureColumnId.routedLength => scheduleLengthCell(
      row.routedLength,
      units,
    ),
    // OFF THE LINK, NOT OFF THE ROW. `ScheduleEntry.length` is the
    // RESOLVED length and may be an estimate from the room or the outlet
    // (`lengthSource`); `cutLength` is the measured one, and a column
    // headed `CUT` showing a room estimate is what AC-024 forbids.
    StructureColumnId.cutLength => scheduleLengthCell(link?.cutLength, units),
    StructureColumnId.terminatedLength => scheduleLengthCell(
      row.terminatedLength,
      units,
    ),

    StructureColumnId.fieldTerm => switch (origin?.terminationField) {
      final t? => terminationLabel(t),
      null => kUnknownCell,
    },
    // PASS/FAIL, and NULL IS "NOT TESTED" rather than a failure. The two
    // are a fortnight apart on a jobsite and only one of them is somebody
    // else's problem.
    StructureColumnId.testResult => switch (link?.test) {
      final t? => t.pass ? 'PASS' : 'FAIL',
      null => kUnknownCell,
    },
    StructureColumnId.certificateId => _text(link?.test?.certificateId),
    StructureColumnId.installedBy => _text(link?.installedBy),
    StructureColumnId.notes => _text(link?.notes),
  };
}

/// A stored string, or the unknown dash. AN EMPTY STRING IS UNKNOWN here
/// and not a value: nothing in the product writes `''` deliberately, and
/// a cell that rendered one would be indistinguishable from a cell nobody
/// has filled in.
String _text(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? kUnknownCell : trimmed;
}

/// One half of the jacket pair. A set id whose entry is missing prints
/// [kDanglingJacketColorCell], never nothing: the record of what was
/// pulled must survive the deletion of the convention entry naming it.
String _jacketToken(Object? id, String? abbr) {
  if (id == null) return kUnknownCell;
  return abbr ?? kDanglingJacketColorCell;
}

/// What a `RoughInStatus` prints. The enum's own names, uppercased, which
/// is what §4's wireframe shows (`pulled`, `tested`, `termin.`) once the
/// table's own casing is applied.
String roughInLabel(RoughInStatus status) => switch (status) {
  RoughInStatus.planned => 'PLANNED',
  RoughInStatus.pulled => 'PULLED',
  RoughInStatus.dressed => 'DRESSED',
  RoughInStatus.terminated => 'TERMINATED',
  RoughInStatus.tested => 'TESTED',
};

/// What a `PathwayKind` prints.
String pathwayKindLabel(PathwayKind kind) => switch (kind) {
  PathwayKind.conduit => 'CONDUIT',
  PathwayKind.jhook => 'J-HOOK',
  PathwayKind.tray => 'TRAY',
  PathwayKind.plenumSpace => 'PLENUM',
  PathwayKind.riser => 'RISER',
  PathwayKind.directBury => 'DIRECT BURY',
  PathwayKind.exterior => 'EXTERIOR',
};

/// Every location id, parents before children, siblings in `order`.
///
/// THE TREE'S ORDER AND NOT `doc.locations`'. A `Map`'s iteration order is
/// insertion order, which is the order rooms were CREATED; the panel next
/// to this table draws them sorted, and two panels disagreeing about
/// which room is third is the kind of defect nobody reports and everybody
/// distrusts.
List<Uuid> _roomsInTreeOrder(RackDocument doc) {
  final tree = LocationTree.of(doc);
  final out = <Uuid>[];
  void walk(Uuid id) {
    out.add(id);
    for (final child in tree.childrenOf(id)) {
      walk(child);
    }
  }

  for (final root in tree.roots) {
    walk(root);
  }
  return out;
}
