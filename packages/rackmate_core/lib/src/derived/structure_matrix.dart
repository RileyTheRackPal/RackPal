// THE STRUCTURE EDITOR'S MATRIX, as a grid model. Board M3-C/3 (#149),
// docs/07 §4.2, AC-048.
//
// ═════════════════════════════════════════════════════════════════════
// IT IS A PROJECTION OF `buildStructureTable`, WHICH IS ONE OF THE SHEET
// ═════════════════════════════════════════════════════════════════════
// #149's own instruction is "one editor, two views of the same rows",
// and this file is where "the same rows" stops being a claim about the
// widget tree and becomes arithmetic: every count below is a tally of
// the table's own rows, so the matrix's Σ IS the table's drop count and
// cannot drift from it. A grid that counted `doc.links` itself would be
// the third derivation of one fact, which is what CR-107 deleted
// `StructureDrop` for.
//
// ═════════════════════════════════════════════════════════════════════
// WHERE IT DELIBERATELY DIFFERS FROM THE TABLE, AND WHY
// ═════════════════════════════════════════════════════════════════════
//  * AN EMPTY ROOM STILL HAS A ROW. `buildStructureTable` omits a room
//    with no drops, because the tree beside it already lists every room
//    and an empty band per room would push the drops off the screen.
//    Here the opposite holds and for the same reason the surface exists:
//    a `0` cell is WHERE A PERSON TYPES `2`. A matrix that hid the empty
//    rooms would be a bulk-entry surface you cannot enter the first drop
//    on.
//  * ROWS ARE PLACES A DROP LANDS. `LocationKind` already answers this,
//    so nothing here invents a second notion of "room": `room`, `zone`
//    and `outdoor` take drops, and a `site`, `building` or `floor` gets
//    a row only when it ALREADY carries drops — which an import or a
//    reparent can produce, and hiding those would hide cable.
//
// ═════════════════════════════════════════════════════════════════════
// WHAT §4.2 DRAWS THAT IS NOT HERE
// ═════════════════════════════════════════════════════════════════════
// THE TINTED `EMT` COLUMN. §4.2: "The `EMT` column is `isPathwayOnly`
// and creates `Pathway`s, not drops, its cells are tinted and excluded
// from the Σ drop count (CR-109)." Two things it needs are absent from
// this build: `MediaTypeDef.isPathwayOnly` is not a field, and nothing
// in the product creates a `Pathway` at all — that is #156 (M3-E/1),
// which owns `Pathway.kind` and `containsLineVoltage` through to the UI.
// So a conduit media type here behaves like any other column and makes
// `Link`s, which is what the typed drop line has always done with
// `Office: 1x ENT`. Named rather than half-built: a tint with no
// `Pathway` behind it would say CR-109 holds when it does not.
import 'package:meta/meta.dart';
import 'package:rackmate_core/src/derived/location_tree.dart';
import 'package:rackmate_core/src/derived/schedule.dart' show kUngroupedTitle;
import 'package:rackmate_core/src/derived/structure_table.dart';
import 'package:rackmate_core/src/model/location.dart' show LocationKind;
import 'package:rackmate_core/src/model/rack_document.dart';
import 'package:rackmate_core/src/units/ids.dart';

/// One room's row: how many of each media column it holds.
@immutable
final class StructureMatrixRow {
  const StructureMatrixRow({
    required this.locationId,
    required this.title,
    required this.code,
    required this.depth,
    required this.counts,
    required this.outletCount,
  });

  /// Null for the trailing row, which is the drops whose room is gone.
  /// A null row CANNOT BE TYPED INTO: there is no room to put a new drop
  /// in, and inventing one would be the surface guessing.
  final Uuid? locationId;

  /// The room's name, or [kUngroupedTitle] for the trailing row.
  final String title;

  /// `LR`, or empty where the room has no code. A room with no code
  /// refuses its drops' labels (`{ROOM_ABBR}`), so this is worth showing
  /// beside the name rather than only in the refusal.
  final String code;

  /// How deep in the location tree, counting only rows that are DRAWN —
  /// so a room under a floor under a site indents once, not three times.
  final int depth;

  /// Parallel to [StructureMatrix.columns]. Always the same length, and
  /// `0` is a real answer: this project holds none of that cable in this
  /// room. It is never the unknown dash, because a count of rows in a
  /// table is a thing the document knows exactly (G4 draws the line at
  /// facts nobody recorded, and this is not one).
  final List<int> counts;

  /// Outlets with at least one drop in this room, on [StructureTable]'s
  /// own rule — not `doc.outlets`, which includes plates nobody has
  /// pulled to yet.
  final int outletCount;

  /// §4.2's `Σ` column.
  int get dropCount => counts.fold<int>(0, (n, c) => n + c);

  /// False for the trailing row. See [locationId].
  bool get takesDrops => locationId != null;
}

/// docs/07 §4.2's grid: rooms down, media across.
@immutable
final class StructureMatrix {
  const StructureMatrix({
    required this.columns,
    required this.rows,
    required this.columnTotals,
    required this.dropCount,
  });

  /// The media columns, left to right. See [structureMatrixColumns] for
  /// the order and for which ones get in.
  final List<MediaTypeId> columns;

  /// Rooms in the location tree's order, then the trailing no-room row.
  final List<StructureMatrixRow> rows;

  /// §4.2's `TOTAL` row, parallel to [columns].
  final List<int> columnTotals;

  /// Every drop on the body, and THE SAME NUMBER `StructureTable.dropCount`
  /// reports. The two views are one derivation; a test asserts it rather
  /// than trusting the comment.
  final int dropCount;
}

/// §4.2's grid for [structureBodyId], or for every Structure body when
/// it is null.
///
/// [alsoColumns] are the media types the user has asked to see with
/// `+ Media column`. A column with no drops in it is worth having — it
/// is the empty column somebody is about to fill — but only when the
/// document's registry actually carries the type, because a column whose
/// cells all refuse is a control that does nothing.
///
/// PURE, and cheap enough to call on every rebuild.
StructureMatrix buildStructureMatrix(
  RackDocument doc, {
  Uuid? structureBodyId,
  Set<MediaTypeId> alsoColumns = const {},
}) {
  final table = buildStructureTable(doc, structureBodyId: structureBodyId);

  final counts = <Uuid?, Map<MediaTypeId, int>>{};
  final plates = <Uuid?, Set<Uuid>>{};
  for (final group in table.groups) {
    final byMedia = counts[group.locationId] ??= <MediaTypeId, int>{};
    final outlets = plates[group.locationId] ??= <Uuid>{};
    for (final row in group.rows) {
      byMedia[row.mediaId] = (byMedia[row.mediaId] ?? 0) + 1;
      if (doc.links[row.linkId]?.structureOrigin case final origin?) {
        outlets.add(origin.outletId);
      }
    }
  }

  final columns = structureMatrixColumns(
    doc,
    present: {for (final byMedia in counts.values) ...byMedia.keys},
    alsoColumns: alsoColumns,
  );

  final rows = <StructureMatrixRow>[];
  final tree = LocationTree.of(doc);
  void walk(Uuid id, int depth) {
    final location = doc.locations[id];
    final byMedia = counts[id] ?? const <MediaTypeId, int>{};
    // A `site` or a `floor` is drawn ONLY when it already holds drops.
    // Drawing every node would offer a row for "123 Oak St", and four
    // Cat6 filed against the street address is not a mistake this
    // surface should make easy.
    final drawn =
        location != null && (_takesDrops(location.kind) || byMedia.isNotEmpty);
    if (drawn) {
      final name = location.name.trim();
      rows.add(
        StructureMatrixRow(
          locationId: id,
          title: name.isEmpty ? kUnnamedLocation : name,
          code: location.code.trim(),
          depth: depth,
          counts: [for (final column in columns) byMedia[column] ?? 0],
          outletCount: (plates[id] ?? const <Uuid>{}).length,
        ),
      );
    }
    for (final child in tree.childrenOf(id)) {
      // INDENTED PAST THE ROWS THAT ARE DRAWN, not past the tree's own
      // depth: a room whose site and floor are both skipped sits at the
      // left margin, where a reader expects the first row to be.
      walk(child, drawn ? depth + 1 : depth);
    }
  }

  for (final root in tree.roots) {
    walk(root, 0);
  }

  // DR-021 clears a deleted location's references rather than deleting
  // the drops, so they land here — the same trailing band the table and
  // the Pull Sheet give them, for the same reason: cable that vanished
  // from a screen is cable somebody stops accounting for.
  final unplaced = counts[null];
  if (unplaced != null && unplaced.isNotEmpty) {
    rows.add(
      StructureMatrixRow(
        locationId: null,
        title: kUngroupedTitle,
        code: '',
        depth: 0,
        counts: [for (final column in columns) unplaced[column] ?? 0],
        outletCount: (plates[null] ?? const <Uuid>{}).length,
      ),
    );
  }

  return StructureMatrix(
    columns: columns,
    rows: rows,
    columnTotals: [
      for (var c = 0; c < columns.length; c++)
        rows.fold<int>(0, (n, row) => n + row.counts[c]),
    ],
    dropCount: table.dropCount,
  );
}

/// The media columns, in the registry's own declaration order.
///
/// THE REGISTRY'S ORDER AND NOT ALPHABETICAL, which is the same call
/// `offerableOutletTemplates` makes: canon §6.5 declares the 38 types
/// grouped by what they are — twisted pair, then coax, then speaker,
/// then control — and §4.2's own grid is in that order. Sorting by name
/// would put `16/2` before `Cat6` and scatter the coax.
///
/// A type the registry does not carry keeps its column when drops
/// already name it, sorted last by id. That is the dangling case
/// `_jacketToken` handles for a colour: the record that a particular
/// cable went in a particular wall must outlive the entry naming it.
List<MediaTypeId> structureMatrixColumns(
  RackDocument doc, {
  required Set<MediaTypeId> present,
  Set<MediaTypeId> alsoColumns = const {},
}) {
  final want = <MediaTypeId>{
    ...present,
    // AN ASKED-FOR COLUMN THE REGISTRY CANNOT FILL IS NOT DRAWN. Every
    // cell in it would refuse, and docs/04 §3.4's rule cuts both ways:
    // a surface must not silently do nothing, and it must not offer a
    // control that can only ever say no.
    for (final id in alsoColumns)
      if (doc.registries.mediaTypes.containsKey(id)) id,
  };
  final out = <MediaTypeId>[];
  for (final id in doc.registries.mediaTypes.keys) {
    if (want.remove(id)) out.add(id);
  }
  final dangling = want.toList()..sort((a, b) => a.v.compareTo(b.v));
  return [...out, ...dangling];
}

/// What a column header says: the trade tag a pull list writes.
///
/// `shortTag` AND NOT `displayName`, which is the one place this file
/// does not simply take the schedule's string. `ScheduleEntry.mediaCell`
/// prints `Cat6A F/UTP CMR` because a printed row has the width for it;
/// a matrix column is a two-digit number wide, and canon §6.5's `Tag`
/// column exists precisely because an installer writes `C6` on a pull
/// list. A type with no tag falls back to its name rather than to
/// nothing, and a dangling id prints itself.
String structureMatrixColumnHeader(RackDocument doc, MediaTypeId id) {
  final def = doc.registries.mediaTypes[id];
  if (def == null) return id.v;
  return def.shortTag ?? def.displayName;
}

/// docs/07 §4.2's own eight columns, as the grid a blank project opens
/// on.
///
/// TRANSCRIBED FROM THE WIREFRAME, not chosen. §4.2 draws `Cat6 Cat6a
/// RG6 RG6q 16/2 16/4 22/4 OS2 EMT`, and a matrix with no columns at all
/// would make a person configure the surface before using it, which is
/// the opposite of what a bulk-entry grid is for.
///
/// `EMT` IS THE ONE THAT IS MISSING, and the file header says why: it is
/// the pathway column, and nothing in this build creates a `Pathway`
/// (#156). Offering it would make conduit into cable one click faster
/// than the typed line already does.
///
/// Filtered against the document's registry by [structureMatrixColumns],
/// so a document that carries none of these opens on the columns its own
/// drops name.
const List<MediaTypeId> kStructureMatrixSeedColumns = <MediaTypeId>[
  MediaTypeId('media.cat6'),
  MediaTypeId('media.cat6a_futp'),
  MediaTypeId('media.rg6'),
  MediaTypeId('media.rg6_quad'),
  MediaTypeId('media.16_2'),
  MediaTypeId('media.16_4'),
  MediaTypeId('media.22_4'),
  MediaTypeId('media.os2'),
];

/// Whether a drop can land on a location of this kind.
///
/// THE MODEL ALREADY ANSWERS THIS. `LocationKind` is CR-047's enum and
/// its six values divide exactly here: the three that name a place a
/// cable terminates, and the three that name a container for those
/// places. Writing the split as a `switch` rather than a set means a
/// seventh kind fails to compile rather than silently landing on one
/// side of it.
bool _takesDrops(LocationKind kind) => switch (kind) {
  LocationKind.room || LocationKind.zone || LocationKind.outdoor => true,
  LocationKind.site || LocationKind.building || LocationKind.floor => false,
};
