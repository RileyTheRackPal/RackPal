// The `[ Pathways ]` tab's derivation. Board M3-E/1 (#156), docs/07 §4,
// CR-016, DR-031.
//
// ═════════════════════════════════════════════════════════════════════
// WHY A DERIVATION AT ALL, FOR A FLAT MAP OF SIX-FIELD OBJECTS
// ═════════════════════════════════════════════════════════════════════
// `structure_editor_screen.dart` opens with the rule this file exists to
// keep: *"it renders a derivation, it does not contain one"*. A tab that
// walked `doc.pathways` itself would be the third surface deciding how a
// `PathwayKind` is spelled and the second deciding what an unknown length
// prints, and the Structure table already answers both.
//
// Two things here are genuinely derived and neither is available from a
// `Pathway`:
//
//   * **[PathwayTableRow.runCount]**, the number of `Link`s naming this
//     pathway, which needs a pass over `doc.links`. It is the answer to
//     "is this the conduit with six runs in it or the one I typed by
//     mistake", and it is what makes the delete honest: `RemovePathwayCommand`
//     clears that many `pathwayId`s.
//   * **the order**, which is `FracIndex` then id. Dart's `List.sort` is
//     not stable, so the chain ends in the id and the list is the same on
//     every machine (§8.4).
//
// ═════════════════════════════════════════════════════════════════════
// EVERY UNKNOWN IS COUNTED, AND ONE OF THEM IS NOT A PATHWAY'S
// ═════════════════════════════════════════════════════════════════════
// G4/CR-114: a rollup reports what it could not resolve rather than
// fabricating a total. [PathwayTable] carries two counts and they answer
// different questions. [PathwayTable.unknownLengthCount] is how many
// pathways nobody has measured. [PathwayTable.unroutedRunCount] is how
// many cables run through no pathway at all — which was EVERY cable in
// this product until `08ad5aa`, and is the number that says whether this
// tab is describing the job or a corner of it.
import 'package:meta/meta.dart';
import 'package:rackpal_core/src/derived/equipment_list.dart' show kUnknownCell;
import 'package:rackpal_core/src/derived/schedule.dart' show scheduleLengthCell;
import 'package:rackpal_core/src/derived/structure_table.dart'
    show pathwayKindLabel;
import 'package:rackpal_core/src/model/enums.dart' show UnitSystem;
import 'package:rackpal_core/src/model/pathway.dart';
import 'package:rackpal_core/src/model/rack_document.dart';
import 'package:rackpal_core/src/units/ids.dart';
import 'package:rackpal_core/src/units/len.dart';

/// Every column the Pathways tab carries.
///
/// SEVEN, AND ALL SEVEN ARE SHOWN. There is no `⚙ Columns` split here
/// and there should not be one: the Structure table has twenty-two
/// columns and needs a menu, this has the whole of `Pathway` minus the
/// two location references, and hiding one of seven would only hide the
/// two fields M5 is waiting on.
enum PathwayColumnId {
  /// `T1`, `PW-LR-1`: what is written on the trunk, where somebody has
  /// written one. Hand-entered, no allocator (DR-026 §11.25.1).
  ///
  /// FIRST, AND THE PRIMARY COLUMN. Identifiers lead everywhere else in
  /// this product: the drop table opens with `FIELD LABEL` and
  /// `RACK LABEL`, the equipment list with designators. This is the value
  /// an installer matches against a label in a wall; [name] is the
  /// context around it.
  designator,

  /// `Living Room ENT`, DR-032 §11.31.1's description.
  name,

  /// DR-031's nine values. The one M5's `CODE-001` reads.
  kind,

  /// M5's `CODE-002` (NEC 800.154). See [PathwayColumnId.kind].
  lineVoltage,

  /// Which `isPathwayOnly` medium this conduit is (CR-109).
  media,

  /// The pathway's own run, never a cable's.
  nominalLength,

  /// Derived: how many `Link`s name this pathway.
  runs,

  notes,
}

/// The header each column prints.
///
/// UPPERCASE, matching `structureColumnHeader`, because these two tables
/// sit one tab apart and a person reads them as one surface.
String pathwayColumnHeader(PathwayColumnId id) => switch (id) {
  PathwayColumnId.designator => 'DESIGNATOR',
  PathwayColumnId.name => 'PATHWAY',
  PathwayColumnId.kind => 'KIND',
  // NOT `LINE V` OR `120V`. The column decides whether a jacket rating is
  // a code violation, and an abbreviation a person has to decode is the
  // wrong economy on the one column that carries a citation.
  PathwayColumnId.lineVoltage => 'LINE VOLTAGE',
  PathwayColumnId.media => 'MEDIA',
  PathwayColumnId.nominalLength => 'LENGTH',
  PathwayColumnId.runs => 'RUNS',
  PathwayColumnId.notes => 'NOTES',
};

/// Layout width in points, on `structureColumnWidth`'s scale.
double pathwayColumnWidth(PathwayColumnId id) => switch (id) {
  // Narrow on purpose: a designator is `T1` or `PW-LR-1`, and a column
  // wide enough for a sentence invites somebody to type one into it.
  PathwayColumnId.designator => 96,
  PathwayColumnId.name => 190,
  // Wide enough for `CRAWLSPACE`, which DR-031 deliberately left
  // unabbreviated.
  PathwayColumnId.kind => 128,
  PathwayColumnId.lineVoltage => 104,
  PathwayColumnId.media => 116,
  PathwayColumnId.nominalLength => 76,
  PathwayColumnId.runs => 60,
  PathwayColumnId.notes => 220,
};

/// One pathway, with the two facts a `Pathway` cannot answer alone.
@immutable
final class PathwayTableRow {
  const PathwayTableRow({
    required this.id,
    required this.designator,
    required this.name,
    required this.kind,
    required this.containsLineVoltage,
    required this.mediaId,
    required this.mediaName,
    required this.nominalLength,
    required this.notes,
    required this.runCount,
  });

  final Uuid id;

  /// Null when nobody has labelled this trunk, which is the ordinary
  /// state before anybody has walked the building (G4, CR-114).
  final String? designator;

  final String name;
  final PathwayKind kind;
  final bool containsLineVoltage;

  /// Null when nobody said which conduit this is (G4).
  final MediaTypeId? mediaId;

  /// The registry's `displayName` for [mediaId], or null when the id
  /// names a type this document does not carry. The two are kept apart so
  /// [pathwayCell] can print the raw id for a dangling reference rather
  /// than the unknown dash: a document that lost a media type still knows
  /// what was written, and `mediaCell` on the schedule takes the same
  /// reading.
  final String? mediaName;

  final Len? nominalLength;
  final String? notes;

  /// How many `Link`s name this pathway. `0` is a real answer and prints
  /// as `0`, not as the unknown dash: nothing running through a conduit
  /// is a measured fact about the document, and it is the ordinary state
  /// of a pathway typed from a conduit-only drop line (DR-032).
  final int runCount;
}

/// Every pathway in the document, with the counts G4 owes.
@immutable
final class PathwayTable {
  const PathwayTable({
    required this.rows,
    required this.unknownLengthCount,
    required this.unroutedRunCount,
  });

  final List<PathwayTableRow> rows;

  /// Pathways whose [PathwayTableRow.nominalLength] nobody has measured.
  final int unknownLengthCount;

  /// `Link`s with no `pathwayId`. See this file's header: this is the
  /// count that says whether the tab describes the job.
  final int unroutedRunCount;

  bool get isEmpty => rows.isEmpty;
}

/// Builds the Pathways tab for [doc].
///
/// DOCUMENT-WIDE AND NOT PER STRUCTURE BODY, unlike `buildStructureTable`.
/// `doc.pathways` is a flat map with no `structureBodyId` on it, the same
/// shape `doc.locations` has, and for CR-112's reason: a conduit from the
/// garage to the attic belongs to the building rather than to whichever
/// Structure device happens to name drops through it.
///
/// PURE, and cheap enough to call on every rebuild: one pass over the
/// pathways and one over the links.
PathwayTable buildPathwayTable(RackDocument doc) {
  final runsPerPathway = <Uuid, int>{};
  var unrouted = 0;
  for (final link in doc.links.values) {
    final id = link.pathwayId;
    if (id == null) {
      unrouted++;
      continue;
    }
    runsPerPathway[id] = (runsPerPathway[id] ?? 0) + 1;
  }

  final pathways = doc.pathways.values.toList()
    // TOTAL, ENDING IN THE ID. Two pathways can share an `order` — the
    // drop-line planner allocated exactly that before `daf1f81` fixed it
    // — and a comparator returning 0 there would leave their positions to
    // map iteration order, which §8.4 forbids.
    ..sort((a, b) {
      final byOrder = a.order.v.compareTo(b.order.v);
      return byOrder != 0 ? byOrder : a.id.v.compareTo(b.id.v);
    });

  final rows = <PathwayTableRow>[];
  var unknownLengths = 0;
  for (final pathway in pathways) {
    if (pathway.nominalLength == null) unknownLengths++;
    final mediaId = pathway.pathwayMedia;
    rows.add(
      PathwayTableRow(
        id: pathway.id,
        designator: pathway.designator,
        name: pathway.name,
        kind: pathway.kind,
        containsLineVoltage: pathway.containsLineVoltage,
        mediaId: mediaId,
        mediaName: mediaId == null
            ? null
            : doc.registries.mediaTypes[mediaId]?.displayName,
        nominalLength: pathway.nominalLength,
        notes: pathway.notes,
        runCount: runsPerPathway[pathway.id] ?? 0,
      ),
    );
  }

  return PathwayTable(
    rows: rows,
    unknownLengthCount: unknownLengths,
    unroutedRunCount: unrouted,
  );
}

/// What one cell prints.
///
/// EVERY UNKNOWN PRINTS [kUnknownCell] AND NOTHING ELSE (G4, CR-114), on
/// `structureCell`'s rule and for its reason: a blank cell reads as
/// "nothing to say here" where the dash reads as "nobody has said".
///
/// [PathwayColumnId.kind] AND [PathwayColumnId.lineVoltage] NEVER PRINT
/// THE DASH, and that asymmetry is the model's. `kind` defaults to
/// `conduit` and `containsLineVoltage` to `false`; neither is nullable,
/// so neither has an unknown state to render. `Pathway.containsLineVoltage`
/// records what it would take to widen that.
String pathwayCell(
  PathwayTableRow row,
  PathwayColumnId id, {
  required UnitSystem units,
}) => switch (id) {
  PathwayColumnId.designator => _text(row.designator),
  PathwayColumnId.name => _text(row.name),
  PathwayColumnId.kind => pathwayKindLabel(row.kind),
  PathwayColumnId.lineVoltage =>
    row.containsLineVoltage ? kLineVoltageYesCell : kLineVoltageNoCell,
  // A DANGLING ID PRINTS ITSELF, never the dash. The record of which
  // conduit was written must survive the deletion of the registry entry
  // naming it, which is `jacketColorCell`'s holding and `mediaCell`'s.
  PathwayColumnId.media => switch (row.mediaId) {
    final mediaId? => row.mediaName ?? mediaId.v,
    null => kUnknownCell,
  },
  PathwayColumnId.nominalLength => scheduleLengthCell(row.nominalLength, units),
  PathwayColumnId.runs => '${row.runCount}',
  PathwayColumnId.notes => _text(row.notes),
};

/// What `LINE VOLTAGE` says when line voltage shares the pathway.
///
/// A WORD AND NOT A TICK GLYPH. This cell is read back by the app to
/// decide the value (`structure_edit_actions.dart`'s rule that the
/// surface sends what it displayed), and `✓` against blank makes "false"
/// and "nobody rendered it" the same string.
const String kLineVoltageYesCell = 'YES';

/// See [kLineVoltageYesCell]. `NO` is a stated answer, not an absence.
const String kLineVoltageNoCell = 'NO';

/// A stored string, or the unknown dash. AN EMPTY STRING IS UNKNOWN, on
/// `structure_table.dart`'s `_text` rule: nothing writes `''`
/// deliberately, so a cell rendering one is indistinguishable from a cell
/// nobody filled in.
String _text(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? kUnknownCell : trimmed;
}
