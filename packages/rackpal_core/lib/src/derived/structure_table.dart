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
import 'package:rackpal_core/src/commands/bind_endpoint_command.dart'
    show freePanelPositions;
import 'package:rackpal_core/src/derived/equipment_list.dart' show kUnknownCell;
import 'package:rackpal_core/src/derived/link_class.dart';
import 'package:rackpal_core/src/derived/location_tree.dart';
import 'package:rackpal_core/src/derived/schedule.dart';
import 'package:rackpal_core/src/model/conductor.dart' show PortEndpoint;
import 'package:rackpal_core/src/model/enums.dart'
    show TerminationType, UnitSystem;
import 'package:rackpal_core/src/model/link.dart' show LinkClass, RoughInStatus;
import 'package:rackpal_core/src/model/pathway.dart' show PathwayKind;
import 'package:rackpal_core/src/model/rack_document.dart';
import 'package:rackpal_core/src/model/registries.dart';
import 'package:rackpal_core/src/structure/drop_line_planner.dart'
    show normaliseMediaToken;
import 'package:rackpal_core/src/units/ids.dart';
import 'package:rackpal_core/src/units/len.dart';

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

  /// Every `Pathway` in the document.
  ///
  /// **NOT [outletCount]'S RULE, AND DR-032 IS WHY.** This used to be
  /// *"distinct pathways named by these drops"*, which was the outlet
  /// reading applied to the neighbouring field and was coherent while
  /// nothing in the product could create a `Pathway` at all. It stopped
  /// being coherent the moment a conduit-only drop line could:
  /// `Office: 1x ENT` builds a pathway **and no cable**, so a bar counting
  /// only pathways with drops through them reads `0 pathways` on the
  /// keystroke after somebody made one. A surface that contradicts the
  /// gesture that fed it is worse than a statistic with a slightly wider
  /// scope.
  ///
  /// **DOCUMENT-WIDE WHERE ITS FOUR NEIGHBOURS ARE PER BODY**, and that is
  /// stated rather than smoothed: `doc.pathways` carries no
  /// `structureBodyId`, for the reason `doc.locations` carries none
  /// (CR-112). A conduit from the garage to the attic belongs to the
  /// building. On every document this product can currently produce the
  /// two scopes coincide, because a second Structure body is #158's.
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
    // BOXLESS RUNS COUNT NO OUTLET (`#718`). The set used to collect
    // `o.outletId` unconditionally; once that field became nullable, a
    // body holding nothing but ceiling speakers reported ONE outlet,
    // because every one of them contributed the same null. The count is
    // "how many boxes are there", and the answer for a speaker is none.
    outletCount: {
      for (final row in rows)
        if (doc.links[row.linkId]?.structureOrigin?.outletId case final id?) id,
    }.length,
    // See [StructureTable.pathwayCount]: the document's, not this body's
    // drops', because DR-032 makes a pathway with nothing running through
    // it the ordinary product of a conduit-only line.
    pathwayCount: doc.pathways.length,
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
  spliceCount,
  fieldTerm,
  testResult,
  certificateId,
  installedBy,
  terminatedAt,
  notes,

  // DR-067, `#712`. LAST, rather than beside `MEDIA` where it would read
  // as a peer of the columns describing the cable: this is the only
  // column whose value is normally DERIVED, and `values` order is the
  // order `⚙ Columns` presents them in.
  linkClass,

  // DR-071, `#715`. Where the rack end LANDS, and the only column that
  // is a gesture rather than a value: picking a panel here punches the
  // drop down onto its next free position.
  landing,

  // `#779`. WHICH position, once [landing] has chosen the panel.
  //
  // ADDITIVE, AND THAT IS THE WHOLE DESIGN. `structureColumnIsEditable`
  // explains why [landing] allocates rather than asks: *"which hole a
  // drop goes in is the product's job and not something a person should
  // have to type sixty times"*. That reasoning is right for the batch it
  // was written for and leaves the single case unexpressible, which is
  // what a person hit. So [landing] still allocates and sixty drops stay
  // cheap; this column overrides ONE of them afterwards.
  landingPort,
}

/// §4.1's eight, in the wireframe's own left-to-right order.
const List<StructureColumnId> kStructureDefaultColumns = <StructureColumnId>[
  StructureColumnId.fieldLabel,
  StructureColumnId.rackLabel,
  StructureColumnId.outlet,
  StructureColumnId.media,
  StructureColumnId.service,
  StructureColumnId.pathway,
  // BOTH ENDS, SIDE BY SIDE (DR-046 §11.45.4). `fieldTerm` joined the
  // defaults here: until DR-046 the two columns read one field, so the
  // one a person saw without configuring anything was `RACK TERM`
  // showing the FIELD end's value. Drawing them together is what makes
  // the distinction teach itself, and the table already scrolls
  // horizontally rather than squeezing below authored widths.
  StructureColumnId.fieldTerm,
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
  StructureColumnId.spliceCount,
  // `fieldTerm` LEFT THIS LIST AT DR-046 and is a default now.
  StructureColumnId.testResult,
  StructureColumnId.certificateId,
  StructureColumnId.installedBy,
  StructureColumnId.terminatedAt,
  StructureColumnId.notes,
  // DR-071 §11.70. Optional for `RACK LBL`'s reason: the label is the
  // default column that says whether a drop is landed, and this one is
  // how it gets that way.
  StructureColumnId.landing,
  StructureColumnId.landingPort,
  // OPTIONAL, NOT A NINTH DEFAULT (DR-067 §11.66.2). §4.1's eight are a
  // ruled list answering "what am I pulling and where does it land", and
  // a class is not that question: it is normally derived and normally
  // right, so a column carrying it by default would spend width teaching
  // people a fact the classifier already knows.
  StructureColumnId.linkClass,
];

/// The as-built set, as one thing to switch on (DR-020 §11.19.2(5)).
///
/// A GROUP RATHER THAN SEVEN TICKS, because the ruling's own picture is a
/// person "closing out sixty runs" who "needs one table with a length
/// column they tab down, not sixty inspector visits". Making them reach
/// that table through seven separate menu entries would put the cost back
/// in a different place.
///
/// `ROUGH-IN` IS NOT IN IT, and that is the line between the two halves:
/// it is one of §4.1's eight DEFAULTS, because "how far along is this
/// run" is a question the rough-in table is already about. These seven
/// answer "what did we actually do", which is a second visit to the same
/// cable weeks later.
const List<StructureColumnId> kStructureAsBuiltColumns = <StructureColumnId>[
  StructureColumnId.terminatedLength,
  StructureColumnId.spliceCount,
  // `fieldTerm` IS A DEFAULT SINCE DR-046 and is no longer in this
  // group: a group that toggles a column already on screen would turn it
  // OFF, which is not what "show me the as-built set" means.
  StructureColumnId.testResult,
  StructureColumnId.certificateId,
  StructureColumnId.installedBy,
  StructureColumnId.terminatedAt,
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
  StructureColumnId.spliceCount => 'SPLICES',
  StructureColumnId.fieldTerm => 'FIELD TERM',
  StructureColumnId.testResult => 'TEST',
  StructureColumnId.certificateId => 'CERT ID',
  StructureColumnId.installedBy => 'INSTALLED BY',
  StructureColumnId.terminatedAt => 'TERMINATED',
  StructureColumnId.notes => 'NOTES',
  StructureColumnId.linkClass => 'CLASS',
  StructureColumnId.landing => 'LANDS ON',
  StructureColumnId.landingPort => 'PORT',
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
  StructureColumnId.spliceCount => 46,
  StructureColumnId.fieldTerm => 78,
  StructureColumnId.testResult => 44,
  StructureColumnId.certificateId => 72,
  StructureColumnId.installedBy => 84,
  StructureColumnId.terminatedAt => 78,
  StructureColumnId.notes => 140,
  // Wide enough for `FIELD CABLE` plus the override marker the cell puts
  // in front of it, since a badge that clips is a badge nobody sees.
  StructureColumnId.linkClass => 96,
  // `PP-1 · 01` plus room for a longer designator. Wider than `RACK LBL`
  // because it carries two identifiers rather than one.
  StructureColumnId.landing => 104,
  StructureColumnId.landingPort => 64,
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

  // M3-J/3's seven. DR-020 §11.19.2(5) asks for "one table with a length
  // column they tab down, not sixty inspector visits", so the whole
  // as-built set is enterable and not merely visible.
  StructureColumnId.terminatedLength ||
  StructureColumnId.spliceCount ||
  StructureColumnId.fieldTerm ||
  // DR-046: the rack end is its own field and its own editable cell.
  StructureColumnId.rackTerm ||
  StructureColumnId.testResult ||
  StructureColumnId.certificateId ||
  StructureColumnId.installedBy ||
  StructureColumnId.terminatedAt => true,

  // `ROUTED` AND `CUT` JOIN THEM (M3-D/2). They were read-only for one
  // milestone and the reason was a task boundary, not a control problem:
  // M3-J/3 owned the as-built length and #153 owned the other two. Both
  // now have a `LinkField`, and all three take `parseLengthCell` — the
  // same parser, so the three columns cannot disagree about what `62.5`
  // means or about which unit an unadorned number is in.
  StructureColumnId.routedLength || StructureColumnId.cutLength => true,

  // THE SIGNAL FAMILY (DR-025 §11.24.5, board #587). It was grouped with
  // MEDIA as "derived, needs a picker and not a text box", and a picker
  // was never the whole of what it lacked: there was no Command behind
  // it either, so a surface had nothing to call. `SetSignalFamilyCommand`
  // is that command and this makes the cell reachable.
  //
  // Batchable follows for free, because the rule below is
  // editable-minus-the-unique-ones and a family is not unique. MEDIA
  // does NOT follow: it still has no command, and RJ-012 makes it
  // user-extensible, which is a different question from this one.
  StructureColumnId.service => true,

  // THE LINK CLASS (DR-067 §11.66, board `#712`). `SetLinkClassCommand`
  // and `ClearLinkClassOverrideCommand` had been complete in core, with
  // undo, since DR-008, and no surface in the product called either: a
  // class could be classified and never asserted. This makes the cell
  // reachable.
  //
  // EDITABLE EVEN THOUGH THE VALUE IS NORMALLY DERIVED, which is the
  // whole of DR-008 §11.8.2: the classifier is advisory, and a person
  // must be able to overrule it and to hand it back. `MEDIA` is not the
  // precedent to read this against — that column is derived AND has no
  // command; this one is derived and has two.
  StructureColumnId.linkClass => true,

  // WHERE THE RACK END LANDS (DR-071 §11.70, board `#715`).
  //
  // `BindEndpointCommand` has been complete since M3-K/2 and reachable
  // only by typing `@panel=` on the line that CREATES the drops.
  // `label_key.dart` anticipated the missing gesture in prose: "the
  // single bind a person makes when they punch one stray drop down". It
  // was never built, so a run typed without `@panel=` could never be
  // landed at all.
  //
  // THE CELL IS A GESTURE, NOT A VALUE, which is what makes it the odd
  // one out here. Every other editable column writes what it is given;
  // this one is given a PANEL and allocates a position, exactly as
  // `@panel=` does, because which hole a drop goes in is the product's
  // job and not something a person should have to type sixty times.
  StructureColumnId.landing => true,
  StructureColumnId.landingPort => true,

  _ => false,
};

/// Resolves a typed termination token to its `TerminationType`, or null
/// when nothing matches (DR-043 §11.42.4).
///
/// **MATCHES [terminationLabel]'S SPELLING AND THE ENUM NAME, BOTH
/// NORMALISED** for case and non-alphanumerics, so `f barrel`,
/// `fbarrel`, `F BARREL` and `fBarrel` all reach
/// `TerminationType.fBarrel`. The label half is the load-bearing one:
/// the surface sends what it DISPLAYED, so core stays the only speller,
/// which is `pathway_actions.dart`'s rule for `PathwayKind` applied to a
/// second enum.
///
/// **NO ALIAS IS INVENTED, AND `post` DOES NOT RESOLVE TO
/// `bindingPost`.** Trade shorthand in a parser is how a product ends up
/// with two vocabularies, one of them undocumented, and a refusal that
/// lists the accepted set teaches it once. [terminationTokens] is that
/// list, so a refusal and this function cannot disagree about what is
/// accepted.
TerminationType? resolveTerminationToken(String token) {
  String norm(String s) => s.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');
  final wanted = norm(token);
  if (wanted.isEmpty) return null;
  for (final t in TerminationType.values) {
    if (norm(t.name) == wanted || norm(terminationLabel(t)) == wanted) {
      return t;
    }
  }
  return null;
}

/// Every spelling [resolveTerminationToken] accepts, for a refusal
/// sentence. One per value, in enum order, in the label's own casing.
List<String> terminationTokens() => [
  for (final t in TerminationType.values) terminationLabel(t),
];

// ─────────────────────────────────────────────────────────────────────
// THE SERVICE COLUMN'S MENU (DR-025 §11.24.5, board #587)
// ─────────────────────────────────────────────────────────────────────

/// One family, as the SERVICE picker needs it: what to print, what to
/// write, and what a filter box matches against.
@immutable
final class SignalFamilyCellOption {
  const SignalFamilyCellOption({
    required this.id,
    required this.label,
    required this.searchKey,
  });

  final SignalFamilyId id;

  /// [signalFamilyCellLabel]'s spelling, which is also what the cell
  /// PRINTS. The menu and the cell must agree, or the first family whose
  /// display name is not its tag round-trips wrong, which is most of
  /// them.
  final String label;

  /// Everything [matches] compares against, normalised and joined once.
  ///
  /// PRE-COMPUTED because a filter box runs this on every keystroke
  /// against every family, and because building it in one place is the
  /// only way to be sure the printed label and the DSL's own tokens are
  /// searched by the same rule.
  final String searchKey;

  /// Whether this row survives a filter box containing [query].
  ///
  /// SUBSTRING, WHERE `resolveSignalFamilyToken` IS EXACT, and the two
  /// answer different questions rather than disagreeing. `@signal=hdb`
  /// must REFUSE, because DR-025 §11.24.3 says an unresolved value never
  /// invents a family; typing `hdb` into a filter must SHOW HDBaseT,
  /// because a box that only matched what was already spelled correctly
  /// is a search for people who do not need one.
  bool matches(String query) {
    final want = normaliseMediaToken(query);
    return want.isEmpty || searchKey.contains(want);
  }
}

/// One domain's block in the SERVICE picker.
@immutable
final class SignalFamilyCellGroup {
  const SignalFamilyCellGroup({
    required this.domainId,
    required this.tagPrefix,
    required this.domainName,
    required this.options,
  });

  final SignalDomainId domainId;

  /// `VID`, `AUD`, `NET`. Every label in [options] starts with it, so a
  /// header repeating it is a heading rather than new information, which
  /// is why the surface pairs it with [domainName].
  final String tagPrefix;
  final String domainName;
  final List<SignalFamilyCellOption> options;
}

/// The SERVICE picker's rows, grouped by domain.
///
/// **A FLAT MENU DOES NOT FIT, AND THE NUMBER THAT SETTLES IT IS THE
/// COLUMN WIDTH RATHER THAN THE FAMILY COUNT.** SERVICE is 76 points, a
/// `DropdownButton`'s menu inherits its button's width, and the seeded
/// labels average 22 characters and reach 45. Measured, every row
/// renders clamped to 84 points, so `AUD·Speaker level, low-Z` and
/// `AUD·Speaker, constant-voltage 70 / 100 / 25 V` both arrive as
/// `AUD·Speaker…`. The three enum-backed choice columns never hit this
/// because `PULLED` and `RJ45` fit in 84 points.
///
/// **ORDERED BY DOMAIN ID, WHICH IS `schematic_filter.dart`'S ORDER.**
/// That file already sorts these same eight domains for the schematic's
/// filter bar, and the same eight things in two different orders in one
/// product reads as assembled from parts. Sorting by id also keeps
/// `audio.analog` next to `audio.digital` and `video.analog` next to
/// `video.digital`, which sorting by [SignalFamilyCellGroup.tagPrefix]
/// would split apart.
///
/// **TOTAL AT BOTH LEVELS**, domains by id and families by label, so the
/// menu never depends on map order.
///
/// A family whose domain is missing is DROPPED rather than listed
/// domainless: it has no tag to file it under and no colour to draw in.
/// `seed_catalog_test.dart` gates the shipped catalog against exactly
/// that, so this arm is a guard on a document rather than on the seed.
List<SignalFamilyCellGroup> signalFamilyCellGroups(Registries registries) {
  final byDomain = <SignalDomainId, List<SignalFamilyCellOption>>{};
  for (final family in registries.signalFamilies.values) {
    final domain = registries.signalDomains[family.domain];
    if (domain == null) continue;
    final label = signalFamilyCellLabel(domain, family);
    byDomain
        .putIfAbsent(family.domain, () => [])
        .add(
          SignalFamilyCellOption(
            id: family.id,
            label: label,
            searchKey: normaliseMediaToken(
              [
                label,
                family.shortTag ?? '',
                family.id.v,
                family.displayName,
                ...family.aliases,
              ].join(' '),
            ),
          ),
        );
  }
  final ids = byDomain.keys.toList()..sort((a, b) => a.v.compareTo(b.v));
  return [
    for (final id in ids)
      SignalFamilyCellGroup(
        domainId: id,
        tagPrefix: registries.signalDomains[id]!.tagPrefix,
        domainName: registries.signalDomains[id]!.displayName,
        options: byDomain[id]!..sort((a, b) => a.label.compareTo(b.label)),
      ),
  ];
}

/// Every spelling the SERVICE picker offers, flat and sorted.
///
/// **ITS INVERSE IS [resolveSignalFamilyCell] AND THE TWO ARE ONE PAIR**,
/// the `terminationLabel` / [resolveTerminationToken] shape applied to a
/// family: the surface offers what core spells and hands back what it
/// displayed, so core stays the only speller and a refusal cannot
/// disagree with the menu that produced it.
///
/// **THERE IS NO `unknown` ENTRY, UNLIKE THE TERMINATION COLUMNS**, and
/// that is G4 drawing a real distinction rather than an inconsistency.
/// `TerminationType?` is nullable because "nobody has decided how this
/// end is finished" is a genuine absence. A `Service` always HAS a
/// family, and `structure.undetermined` is the encouraged first-class
/// value (docs/07 §4.1: at rough-in a Cat6 is just a Cat6), so it is an
/// ordinary row in this list and choosing it is a statement rather than
/// a clearing.
///
/// Derived from [signalFamilyCellGroups] rather than rebuilt, so the
/// validator and the menu cannot come to hold different sets.
List<String> signalFamilyCellOptions(Registries registries) => [
  for (final group in signalFamilyCellGroups(registries))
    for (final option in group.options) option.label,
]..sort();

/// The family a SERVICE cell's text names, or null when nothing matches.
///
/// Compares against [signalFamilyCellLabel]'s own spelling, so this and
/// the menu cannot drift. A batch fill or a pasted column can produce a
/// string that matches nothing, and that REFUSES rather than inventing a
/// family (DR-025 §11.24.3): families are catalog-updated where media
/// types are user-extensible.
///
/// **EXACT ON THE LABEL, NOT [SignalFamilyCellOption.matches].** A cell
/// COMMITS a value where a filter only narrows a list, so accepting a
/// substring here would let `hdmi` commit whichever of the three HDMI
/// generations happened to sort first.
SignalFamilyId? resolveSignalFamilyCell(Registries registries, String cell) {
  final want = cell.trim().toLowerCase();
  if (want.isEmpty) return null;
  for (final group in signalFamilyCellGroups(registries)) {
    for (final option in group.options) {
      if (option.label.toLowerCase() == want) return option.id;
    }
  }
  return null;
}

/// Whether a column's choices come from the DOCUMENT'S REGISTRIES rather
/// than from a Dart enum.
///
/// **THE SURFACE NEEDS THIS TO CHOOSE A CONTROL, and the distinction is
/// where the options come from rather than how many there are today.**
/// An enum-backed column has a handful of short fixed labels and a plain
/// dropdown fits it. A registry-backed one has as many rows as the
/// catalog ships, spelled as long as the catalog spells them, and needs
/// a menu sized to its content plus a way to find a row without reading
/// all of them.
///
/// LIVES HERE FOR [structureColumnIsBatchable]'S REASON: the cell and
/// the batch bar have to reach the same answer, and a list hardcoded in
/// `rackpal_ui` would drift the first time a second column becomes
/// registry-backed. MEDIA is the one waiting to do that, since RJ-012
/// ships a media-type editor and makes media user-extensible, which is
/// what makes this a predicate rather than an `id == service` test at
/// the call site.
bool structureColumnChoicesAreRegistryBacked(StructureColumnId id) =>
    id == StructureColumnId.service;

/// Whether a column can be set to ONE value across MANY selected rows
/// (DR-043 §11.42.6, M3-L/3).
///
/// **EDITABLE MINUS THE UNIQUE ONES, and the rule is uniqueness rather
/// than a taste about which facts feel bulk-shaped.** CR-113 makes
/// `fieldLabel` unique project-wide and `rackLabel` unique when set, so
/// one value across N rows is refused by
/// `buildSetStructureOriginProperty` on every row after the first. A
/// batch menu offering them would be a control whose only outcome on a
/// real selection is a refusal sentence, which is
/// `shell_tabs_test.dart`'s "no control that does nothing" wearing a
/// different hat.
///
/// **NOTHING ELSE IS EXCLUDED, INCLUDING THE ODD-LOOKING ONES.** A bulk
/// `CUT` length reads strange until it is forty identical patch runs, and
/// `CERT ID` is not declared unique anywhere, so neither is this
/// function's business. The refusing builder is still in the path and
/// still decides; this only declines to draw a control that cannot ever
/// succeed.
///
/// LIVES HERE AND NOT IN THE TABLE WIDGET, so the batch bar and any later
/// consumer read one answer. A list hardcoded in `rackpal_ui` would
/// drift the first time a column becomes editable.
bool structureColumnIsBatchable(StructureColumnId id) =>
    structureColumnIsEditable(id) &&
    id != StructureColumnId.fieldLabel &&
    id != StructureColumnId.rackLabel;

/// Right-aligned where the value is a number to compare down a column.
ScheduleAlign structureColumnAlign(StructureColumnId id) => switch (id) {
  StructureColumnId.routedLength ||
  StructureColumnId.cutLength ||
  StructureColumnId.terminatedLength ||
  StructureColumnId.spliceCount => ScheduleAlign.right,
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
    // READS THE RACK END, AND UNTIL DR-046 READ THE FIELD END. This
    // column and `fieldTerm` below both resolved to
    // `StructureOrigin.terminationField`: two columns, one value, so a
    // speaker run with a phoenix at the panel and binding posts in the
    // room was inexpressible. NOTHING IS INFERRED from the other end;
    // an unrecorded rack termination prints the unknown marker (G4).
    StructureColumnId.rackTerm => switch (origin?.terminationRack) {
      final t? => terminationLabel(t),
      null => kUnknownCell,
    },

    // The two the sheet has no column of its own for. `OUTLET` is half of
    // the Pull Sheet's `FROM (ROOM / OUTLET)`; splitting it is what makes
    // it an editable cell rather than a rendered sentence.
    // THREE STATES, NOT TWO (DR-070 §11.69). A designation when there is
    // a box, `— NO BOX —` when somebody has said there is none, and the
    // dash when nobody has said. Collapsing the last two is the fusion
    // this ruling removed from the model, and the editor is the surface
    // people trust most because they are typing into it.
    StructureColumnId.outlet =>
      row.boxless ? kNoBoxCell : row.outletDesignation ?? kUnknownCell,
    StructureColumnId.roughIn => roughInLabel(row.roughInStatus),

    StructureColumnId.jacketRating => switch (row.jacketRating) {
      final r? => jacketListingLabel(r),
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
      final t? => t.pass ? kTestPassCell : kTestFailCell,
      null => kUnknownCell,
    },
    StructureColumnId.certificateId => _text(link?.test?.certificateId),
    StructureColumnId.installedBy => _text(link?.installedBy),

    // A COUNT, WHERE `0` IS A VALUE AND BLANK IS NOT. `spliceCount` is
    // the field DR-020 §11.19.2(3) added precisely so "nobody has looked"
    // and "somebody looked and there are none" stop being the same
    // answer, so this must not fall through `_text`'s empty-is-unknown
    // rule and must not print `0` for null.
    StructureColumnId.spliceCount => switch (link?.spliceCount) {
      final n? => '$n',
      null => kUnknownCell,
    },

    // A DATE, NOT A TIMESTAMP. `terminatedAt` is a `DateTime` and the
    // codec stores the instant, but nothing in the product records an
    // hour; printing one would invent a precision the document does not
    // have. See [parseDateCell] for the other half of the round trip.
    StructureColumnId.terminatedAt => switch (link?.terminatedAt) {
      final t? => formatDateCell(t),
      null => kUnknownCell,
    },

    StructureColumnId.notes => _text(link?.notes),

    // THE EFFECTIVE CLASS, WHICH IS THE ONLY ONE ANY SURFACE MAY ASK FOR
    // (DR-008 §11.8.2, DR-067 §11.66.1). `effectiveLinkClassOf` returns
    // the person's assertion when they have made one and the classifier's
    // answer otherwise; reading `Link.linkClass` here would print a
    // stored default nobody chose, on every link nobody has classified.
    //
    // AND `null` IS THE DASH, not `FIELD CABLE`. The classifier returns
    // null when an end will not resolve, and `link_class.dart`'s header
    // spends a paragraph on why guessing there is worse than counting:
    // defaulting to a field cable asserts a pull nobody established, and
    // defaulting to a jumper hides the run from the sheet an installer
    // works from. G4 applies to a classifier exactly as it does to a
    // measurement.
    // WHERE THE RACK END IS PUNCHED DOWN (DR-071 §11.70). Two
    // identifiers, because a position without its panel names nothing on
    // a job with four of them.
    //
    // READ OFF THE RESOLVED END, not off `rackLabel`. The label is what
    // the CABLE is called and is allocated separately; a drop can carry
    // one and be unlanded, and DR-040 §11.39.5 rules that a bind whose
    // label cannot render still binds. A column that showed the label
    // would report the naming and not the punchdown.
    StructureColumnId.landing => switch (row.to.kind) {
      ScheduleEndKind.rackPort || ScheduleEndKind.unrackedPort =>
        '${row.to.deviceDesignator ?? kUnknownCell} · '
            '${row.to.portDesignator ?? kUnknownCell}',
      _ => kUnknownCell,
    },

    // THE NUMBER PRINTED ON THE PART, which is `positionToken` and not
    // the `portDesignator` the LANDS ON cell shows beside the panel.
    // DR-040 §11.39.8 is explicit that `J04` "appears nowhere on the
    // physical part", so a column a person uses to CHOOSE a hole must
    // offer what is written on it. The two columns therefore disagree on
    // purpose, and each is right for its own question.
    StructureColumnId.landingPort => landingPortToken(row) ?? kUnknownCell,

    StructureColumnId.linkClass => switch (link) {
      final l? => switch (effectiveLinkClassOf(doc, l)) {
        final c? => linkClassLabel(c),
        null => kUnknownCell,
      },
      null => kUnknownCell,
    },
  };
}

/// The `CLASS` option meaning "hand this back to the classifier".
///
/// NOT [kUnknownCell], and the difference is the whole point of the
/// column. The dash means "nobody knows what this is", which is what an
/// unresolvable end produces; this means "let the classifier decide",
/// which is a decision and the DEFAULT state of every link. Spelling them
/// the same would make handing a link back indistinguishable from
/// declaring it a mystery.
const String kLinkClassAutoCell = 'AUTO';

/// The label a chosen `CLASS` cell maps back to, or null if it is not one
/// this column offers.
///
/// THE INVERSE OF `linkClassLabel`, WHICH IS THE SCHEDULE'S SPELLER AND
/// NOT A SECOND ONE. The sheet has printed these four words since DR-008;
/// a column that offered its own spelling would round-trip wrong the
/// first time either changed, which is the rule `resolveSignalFamilyCell`
/// and `terminationLabel` already work under.
///
/// `UNDETERMINED` DOES NOT RESOLVE, though `linkClassLabel(null)` prints
/// it: that word is the sheet's rendering of "the classifier could not
/// tell", which is a fact about a document rather than a choice a person
/// can make. [kLinkClassAutoCell] is not a class either and returns null
/// too; a caller must check for it before calling this.
LinkClass? resolveLinkClassCell(String label) {
  final wanted = label.trim().toUpperCase();
  return LinkClass.values.where((c) => linkClassLabel(c) == wanted).firstOrNull;
}

/// Whether this row's rack end is already punched down (DR-071 §11.70).
///
/// WHICH MENU THE ROW GETS, and it is the model's answer rather than a UI
/// preference. It used to mean something stronger: until DR-074 a landed
/// row was not editable at all, because `buildBindEndpointCommand` refuses
/// a drop that is already landed and a dropdown whose every use is refused
/// is `#711`'s defect drawn on purpose.
///
/// DR-074 §11.73.1 spends that reasoning. A landed row now offers the same
/// panels an unlanded one does, meaning MOVE rather than land, plus
/// [kUnlandCell]. The distinction survives because the two rows run
/// different commands, and because [kUnlandCell] must not appear on a row
/// with nothing to take off.
bool structureRowIsLanded(ScheduleEntry row) => switch (row.to.kind) {
  ScheduleEndKind.rackPort || ScheduleEndKind.unrackedPort => true,
  _ => false,
};

/// The `LANDS ON` option meaning "take this end back off its jack"
/// (DR-074 §11.73.1).
///
/// NAMES THE RESULTING STATE, not the act, which is what every other
/// closed-set cell in this table does: `FIELD CABLE`, `PLANNED`,
/// `KEYSTONE`. Settled by the user on 2026-08-19 against `UNLAND`, which
/// is this project's word rather than a word anybody says holding a punch
/// tool, and against `TAKE OFF PANEL`, which does not fit the column.
///
/// It reads correctly beside the dash an unlanded row already shows: after
/// picking it, the cell says `—` and the row is not landed.
const String kUnlandCell = 'NOT LANDED';

/// Whether this row's rack label is A PERSON'S rather than the
/// allocator's (DR-074 §11.73.2).
///
/// `structureLinkClassIsUserSet`'s shape one column over, and for
/// DR-067 §11.66.3's reason: the mark is what makes an override
/// auditable. Here it also answers a question the person asks at a
/// specific moment — they moved a drop, the position changed, the label
/// did not, and the cell has to be able to say why.
bool structureRackLabelIsUserSet(RackDocument doc, ScheduleEntry row) =>
    doc.links[row.linkId]?.structureOrigin?.rackLabelLocked ?? false;

/// Every home run whose RACK end is not punched down, in document order
/// (DR-072 §11.71).
///
/// ═══════════════════════════════════════════════════════════════════
/// THE ONE UNLANDED END THAT IS A JOB AND NOT A STATE
/// ═══════════════════════════════════════════════════════════════════
/// An unlanded FIELD end is ordinary and often permanent: DR-068 §11.67.1
/// lets a speaker run land on its driver, and a Cat6 drop that ends at a
/// wall plate ends there for good. Counting those would put a number on
/// the sheet that never goes to zero, which is how a person learns to
/// stop reading it.
///
/// An unlanded RACK end is different. AC-018 makes it a legitimate state
/// at rough-in — fourteen of sixty, by that criterion's own arithmetic —
/// and a job somebody is printing a schematic for is past rough-in. This
/// is the count that answers "did I forget one", which is the question
/// the schematic could not answer at all before `#716`.
///
/// NOT THE SAME AS `unlabelledLinkIds`, which the sheet already reports.
/// That one is "this cable has no drawn end at all" and folds together a
/// run nobody landed with a link whose device carries no symbol: two
/// different problems with two different fixes. This one names only the
/// first, so the sentence a person reads is one they can act on.
List<Uuid> unlandedHomeRunIds(RackDocument doc) {
  final out = <Uuid>[];
  for (final link in doc.links.values) {
    if (link.structureOrigin == null) continue;
    if (link.conductors.isEmpty) continue;
    if (link.conductors.first.to is PortEndpoint) continue;
    out.add(link.id);
  }
  return out;
}

/// The devices a drop may be landed on, by designator, in document
/// order.
///
/// EVERY DEVICE WITH A FREE REAR POSITION, and not "every patch panel".
/// `_resolvePanel` in the drop-line planner matches `@panel=` on
/// designator against any device for the same reason: DR-068 §11.67.1's
/// speaker run lands on an amplifier, and a filter that knew what a
/// patch panel was would refuse the case the ruling exists for. What
/// makes a device offerable is that it HAS somewhere for a pulled cable
/// to go, which `freePanelPositions` already answers.
///
/// [landed] adds [kUnlandCell], because taking an end off its jack is only
/// offered where there is something to take off. It is a parameter rather
/// than a second function so that both callers — the cell and the batch
/// bar — reach one list and cannot disagree about what the column offers.
List<String> landingCellOptions(RackDocument doc, {bool landed = false}) {
  final out = <String>[];
  for (final device in doc.devices.values) {
    if (freePanelPositions(doc, panelDeviceId: device.id).isEmpty) continue;
    final designator = device.designator.trim();
    if (designator.isEmpty || out.contains(designator)) continue;
    out.add(designator);
  }
  out.sort();
  // AFTER THE SORT, so it sits at the end rather than wherever `N` falls
  // among the panel designators. A destructive option hiding between
  // `MDF-1` and `PP-1` is one a person picks by aiming badly.
  if (landed) out.add(kUnlandCell);
  return out;
}

/// What `PORT` shows for [row]: the token printed on the panel, or null
/// when the drop is not landed on one.
///
/// READ OFF THE RESOLVED END rather than walked back through the link.
/// `ScheduleEnd` already carries `portPositionToken` and did the template
/// resolution once; a second walk here would be a second answer to a
/// question already answered, and the two could drift.
String? landingPortToken(ScheduleEntry row) => switch (row.to.kind) {
  ScheduleEndKind.rackPort || ScheduleEndKind.unrackedPort =>
    row.to.portPositionToken ?? row.to.portDesignator,
  _ => null,
};

/// The positions this row could land on, by printed token, INCLUDING the
/// one it currently occupies.
///
/// The current position is in the list because a dropdown whose value is
/// absent from its own options is `#711`'s defect again: it renders blank,
/// or the framework asserts, and either way the person cannot see where
/// the drop actually is.
///
/// Empty when the row is not landed, which the surface reads as "pick a
/// panel first". Offering ports for a drop with no panel would be asking a
/// question with no subject.
List<String> landingPortCellOptions(RackDocument doc, ScheduleEntry row) {
  final deviceId = row.to.deviceId;
  if (deviceId == null || landingPortToken(row) == null) return const [];
  final out = <String>[
    for (final f in freePanelPositions(doc, panelDeviceId: deviceId))
      f.positionToken,
  ];
  final current = landingPortToken(row);
  if (current != null && !out.contains(current)) out.add(current);
  out.sort();
  return out;
}

/// Whether this row's `CLASS` is a PERSON'S assertion rather than the
/// classifier's answer, so a surface can mark it (DR-067 §11.66.3).
///
/// The mark is what makes an override auditable: `effectiveLinkClassOf`
/// returns the same kind of value either way, and a cell that showed no
/// difference would let a pin set months ago go on quietly outranking a
/// document that has moved underneath it.
bool structureLinkClassIsUserSet(RackDocument doc, ScheduleEntry row) =>
    doc.links[row.linkId]?.linkClassLocked ?? false;

/// What the classifier would say instead, spelled, or null when it does
/// not disagree.
///
/// Reads [linkClassDisagreementOf], which is careful about one case this
/// must not lose: an UNDETERMINED classifier is not a disagreement. It
/// has failed to resolve an end, not formed a competing opinion, and
/// reporting those as conflicts would mark every link touching a staged
/// device.
String? structureLinkClassDisagreement(RackDocument doc, ScheduleEntry row) {
  final link = doc.links[row.linkId];
  if (link == null) return null;
  final derived = linkClassDisagreementOf(doc, link);
  return derived == null ? null : linkClassLabel(derived);
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
  // DR-031 (canon §11.30). Unabbreviated: `PLENUM` is short for a term
  // of art nobody says in full, where these two are already the words an
  // installer uses, and the column has the room at 72 pt.
  PathwayKind.attic => 'ATTIC',
  PathwayKind.crawlspace => 'CRAWLSPACE',
};

// ═════════════════════════════════════════════════════════════════════
// READING A TYPED CELL BACK — M3-J/3
// ═════════════════════════════════════════════════════════════════════
// THE PARSERS ARE HERE AND NOT IN THE WIDGET, for the reason `structureCell`
// is: a surface holding a rule is a second copy of that rule. They are also
// here rather than in the app layer because what they enforce is CR-001 —
// integer nanometres, no floating-point millimetres anywhere — and that is
// this package's invariant to keep.
//
// EACH REFUSES WITH A SENTENCE RATHER THAN RETURNING NULL, because null is
// already taken: an empty box means UNKNOWN and is a legal edit (G4). A
// parser that answered null for both "cleared" and "nonsense" would make
// `62 ft 3` silently erase a measurement.

/// What reading a cell produced: a value, or why it was refused.
sealed class CellParse<T> {
  const CellParse();
}

/// The cell parsed. [value] may be null, which means the box was cleared
/// and the fact is now UNKNOWN (G4, CR-114).
final class CellParsed<T> extends CellParse<T> {
  const CellParsed(this.value);
  final T? value;
}

/// The cell held something this column cannot mean.
final class CellRefused<T> extends CellParse<T> {
  const CellRefused(this.reason);
  final String reason;
}

/// A length column, in the project's display units.
///
/// WHOLE UNITS ONLY, AND THAT IS THE HONEST RULE FOR THIS COLUMN.
/// `scheduleLengthCell` rounds to whole feet or whole metres, because
/// docs/08 §3.2 prints `78` and cable is ordered and cut in whole feet.
/// A cell that ACCEPTED `62.5` would store a value its own column then
/// displays as `63`, so the number on screen and the number in the file
/// would disagree the moment it was typed. Refusing is the only answer
/// that keeps them equal.
///
/// A STORED PRECISE VALUE IS NOT CLOBBERED BY THIS. The cell only commits
/// when its text CHANGES, so tabbing through a run measured at 62 ft 6 in
/// leaves it exactly where it is; only typing over it rounds it, which is
/// a person's decision rather than a side effect of navigation.
CellParse<Len> parseLengthCell(String text, UnitSystem units) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return const CellParsed<Len>(null);
  final n = int.tryParse(trimmed);
  final suffix = units == UnitSystem.imperial ? 'feet' : 'metres';
  if (n == null) {
    return CellRefused<Len>(
      '"$trimmed" is not a length. This column is whole $suffix, so type '
      'a number and nothing else.',
    );
  }
  if (n < 0) {
    return const CellRefused<Len>('A length cannot be negative.');
  }
  final divisor = units == UnitSystem.imperial
      ? Len.nmPerInch * 12
      : Len.nmPerMillimetre * 1000;
  return CellParsed<Len>(Len(n * divisor));
}

/// A count column: `spliceCount` today.
///
/// `0` IS A VALUE AND BLANK IS NOT THE SAME THING. That distinction is
/// the entire reason DR-020 §11.19.2(3) made the field nullable, so it
/// has to survive the round trip through a text box.
CellParse<int> parseCountCell(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return const CellParsed<int>(null);
  final n = int.tryParse(trimmed);
  if (n == null) {
    return CellRefused<int>('"$trimmed" is not a whole number.');
  }
  if (n < 0) {
    return const CellRefused<int>('A count cannot be negative.');
  }
  return CellParsed<int>(n);
}

/// A storey: `Location.floorNumber` today (DR-040 §11.39.4).
///
/// NEGATIVES ARE LEGAL, AND THAT IS THE WHOLE REASON THIS IS NOT
/// [parseCountCell]. A basement is floor `0` under one convention and `-1`
/// under another, and nothing in this product knows which building the
/// user is standing in. A count cannot be negative; a storey can. `B` is
/// unrepresentable because the field is `int?`, which is the model's
/// decision and not this parser's.
///
/// BLANK IS UNKNOWN, NEVER GROUND LEVEL (G4, CR-114). A blank that landed
/// as `0` would put a wrong `{FLOOR}` on every rack label in a room nobody
/// had got to yet, and `0` is a real storey somewhere.
CellParse<int> parseFloorCell(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return const CellParsed<int>(null);
  final n = int.tryParse(trimmed);
  if (n == null) {
    return CellRefused<int>(
      '"$trimmed" is not a floor. A storey is a whole number, and a '
      'basement is a negative one rather than "B".',
    );
  }
  return CellParsed<int>(n);
}

/// A date column: `terminatedAt` today.
///
/// `YYYY-MM-DD` AND NOTHING ELSE, which is the one spelling that is not
/// ambiguous between two readers on two continents: `03/04` is March and
/// April at the same time, and a jobsite date that is wrong by a month is
/// worse than a jobsite date that is missing.
///
/// STORED AT MIDNIGHT UTC. Nothing in the product records an hour, so
/// there is none to lose; [formatDateCell] prints the date back and the
/// round trip is exact.
CellParse<DateTime> parseDateCell(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return const CellParsed<DateTime>(null);
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(trimmed)) {
    return CellRefused<DateTime>(
      '"$trimmed" is not a date. Use YYYY-MM-DD, which reads the same '
      'everywhere.',
    );
  }
  final parts = trimmed.split('-').map(int.parse).toList();
  final value = DateTime.utc(parts[0], parts[1], parts[2]);
  // `DateTime.utc` ROLLS OVER rather than throwing: month 13 becomes
  // January of the next year and 31 February becomes early March, so a
  // typo would be stored as a real date nobody meant. Comparing the parts
  // back is what catches it.
  if (value.year != parts[0] ||
      value.month != parts[1] ||
      value.day != parts[2]) {
    return CellRefused<DateTime>('There is no such date as $trimmed.');
  }
  return CellParsed<DateTime>(value);
}

/// `2026-08-08`. The inverse of [parseDateCell].
String formatDateCell(DateTime value) {
  final utc = value.toUtc();
  final m = utc.month.toString().padLeft(2, '0');
  final d = utc.day.toString().padLeft(2, '0');
  return '${utc.year.toString().padLeft(4, '0')}-$m-$d';
}

/// What a `TEST` cell prints, and the three things it can say.
///
/// THREE STATES, NOT TWO. Null is NOT TESTED and is not a failure; the
/// two are a fortnight apart on a jobsite and only one of them is
/// somebody else's problem (G4).
const String kTestPassCell = 'PASS';

/// See [kTestPassCell].
const String kTestFailCell = 'FAIL';

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
