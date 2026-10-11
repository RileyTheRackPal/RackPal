// rackpal_core/src/structure/csv_row_resolve.dart — pure Dart.
//
// CELLS INTO VALUES. Board M3-F/6 (#652), docs/07 §5.1, §5.2.
//
// ═════════════════════════════════════════════════════════════════════
// THIS LAYER READS CELLS. IT MATCHES NOTHING AGAINST THE DOCUMENT
// ═════════════════════════════════════════════════════════════════════
// It reads the registries (which cable is `Cat6`) and the settings
// (which convention `BLU` names), because those are what a CELL means.
// It does NOT look up a `Location`, an `Outlet` or a `Pathway`, does not
// dedup, and produces no `Command`; §5.3's matching is the next stage
// and it needs every row resolved before it can count anything.
//
// ═════════════════════════════════════════════════════════════════════
// A CELL THAT CANNOT BE READ MAKES ONE FIELD UNKNOWN, NOT ONE LESS ROW
// ═════════════════════════════════════════════════════════════════════
// docs/07 §5.3: "Import is never fail-fast." So an unreadable length is
// a WARNING and the length is absent (G4: null is unknown, never
// estimated, and never `0` — `0` would mean somebody measured zero
// feet). The row still imports, the preview grid still shows the cell,
// and every issue carries the column it came from so the grid can point
// at it.
//
// Exactly one thing is an ERROR, and it is an error because there is no
// honest partial answer: a row with no room does not say where it goes,
// and inventing one would put a drop in a house at random.
//
// ═════════════════════════════════════════════════════════════════════
// THE TWO JACKET COLUMNS AND THE ONE THAT LOOKS LIKE THEM
// ═════════════════════════════════════════════════════════════════════
// §5.1's blockquote is unusually specific and each clause is built:
// they import INDEPENDENTLY; a value naming no convention entry is kept
// as a DANGLING ID rather than dropped or snapped to the nearest entry,
// because the id is the record that a particular colour went in a
// particular wall and must outlive the entry naming it; a row carrying
// only an as-pulled colour is imported as-is rather than promoted, since
// promoting it would assert a purpose nobody stated; and an as-pulled
// value EQUAL to the convention normalises to absent, so an exceptions
// count can never be inflated by a no-op import.
import 'package:meta/meta.dart';
import 'package:rackpal_core/src/derived/structure_table.dart'
    show CellParsed, CellRefused, parseLengthCell;
import 'package:rackpal_core/src/model/enums.dart';
import 'package:rackpal_core/src/model/link.dart' show RoughInStatus;
import 'package:rackpal_core/src/model/project_settings.dart';
import 'package:rackpal_core/src/model/registries.dart';
import 'package:rackpal_core/src/structure/csv_header_map.dart';
import 'package:rackpal_core/src/structure/csv_mapping.dart';
import 'package:rackpal_core/src/structure/csv_reader.dart';
import 'package:rackpal_core/src/structure/drop_line_planner.dart'
    show normaliseMediaToken, resolveMediaToken, resolveSignalFamilyToken;
import 'package:rackpal_core/src/units/ids.dart';
import 'package:rackpal_core/src/units/len.dart';

/// How much an issue costs the row.
enum CsvIssueSeverity {
  /// One field is unknown; the row still imports. The overwhelming
  /// majority.
  warning,

  /// The row cannot become anything and is shown struck through in the
  /// preview grid. Reserved for a row with no room.
  error,
}

/// Something the preview grid has to say about one cell.
@immutable
final class CsvCellIssue {
  const CsvCellIssue({
    required this.severity,
    required this.message,
    this.column,
  });

  final CsvIssueSeverity severity;

  /// One sentence, already written for a human.
  final String message;

  /// The source column, so the grid can point at the cell. Null when the
  /// issue is about the row as a whole.
  final int? column;
}

/// Which cable, once RJ-012 has had its say.
sealed class ResolvedMedia {
  const ResolvedMedia();
}

/// The document's registry already carries it.
@immutable
final class ResolvedMediaKnown extends ResolvedMedia {
  const ResolvedMediaKnown(this.id);
  final MediaTypeId id;
}

/// **RJ-012: an unmatched value CREATES a new media type rather than
/// rejecting the row.** docs/07 §5.1 states it outright: "An unmatched
/// value creates a new media type with a confirmation chip; it is never
/// a rejected row." The token is carried through as typed so the chip
/// can quote it and the planner can mint the type once per distinct
/// spelling rather than once per row.
@immutable
final class ResolvedMediaNew extends ResolvedMedia {
  const ResolvedMediaNew(this.token);
  final String token;
}

/// One cable and how many of it, from one row.
@immutable
final class ResolvedCsvItem {
  const ResolvedCsvItem({required this.media, required this.count});
  final ResolvedMedia media;
  final int count;
}

/// One source row, read through a [CsvMapping].
///
/// Every field is what the CELLS said. Nothing here has been matched
/// against the document, so `locationName` is a string and not a
/// `Location`.
@immutable
final class ResolvedCsvRow {
  const ResolvedCsvRow({
    required this.source,
    required this.locationName,
    required this.items,
    required this.unknown,
    required this.issues,
    this.floor,
    this.building,
    this.outletDesignation,
    this.fieldLabel,
    this.rackLabel,
    this.serviceToken,
    this.signalFamily,
    this.pathwayName,
    this.routedLength,
    this.rackTermination,
    this.terminationField,
    this.roughInStatus,
    this.jacketColor,
    this.jacketColorPulled,
    this.notes,
  });

  final CsvRow source;

  /// AS TYPED. §5.3's location match is case- and whitespace-insensitive
  /// and it happens in the next stage; keeping the spelling is what lets
  /// a "create room" offer pre-fill with what the operator wrote.
  final String locationName;

  /// What this row becomes. One entry in the long shape, one per
  /// non-zero cable column in the wide shape, and EMPTY is possible: a
  /// wide row for a room getting nothing is a real row.
  final List<ResolvedCsvItem> items;

  /// Preserved columns, keyed by [CsvMapping.unknownKeyFor].
  ///
  /// An EMPTY CELL WRITES NO KEY. G4 and CR-117 agree here: an absent
  /// key is unknown, and writing `''` would make a blank cell a stated
  /// fact and change the bytes of every re-import.
  final Map<String, Object?> unknown;

  final List<CsvCellIssue> issues;

  final String? floor;
  final String? building;
  final String? outletDesignation;
  final String? fieldLabel;
  final String? rackLabel;

  /// The `Use` column, which feeds the LABEL CHAIN and never the family
  /// (DR-025 §11.24.4). Real pull lists put `TV`, `Data`, `Camera` here
  /// and those name templates, which DR-023's chain already resolves.
  final String? serviceToken;

  /// From a column mapped to `signal`, and only from there. DR-025
  /// §11.24.4: "The family is stated deliberately or not at all."
  final SignalFamilyId? signalFamily;

  final String? pathwayName;
  final Len? routedLength;
  final TerminationType? rackTermination;
  final TerminationType? terminationField;
  final RoughInStatus? roughInStatus;
  final JacketColorId? jacketColor;
  final JacketColorId? jacketColorPulled;
  final String? notes;

  bool get hasError => issues.any((i) => i.severity == CsvIssueSeverity.error);

  int get warningCount =>
      issues.where((i) => i.severity == CsvIssueSeverity.warning).length;
}

/// Reads every row of [table] through [mapping].
///
/// Total: never throws, and every row comes back, including the ones
/// that cannot import.
List<ResolvedCsvRow> resolveCsvRows({
  required CsvTable table,
  required CsvMapping mapping,
  required Registries registries,
  required ProjectSettings settings,
}) => [
  for (final row in table.rows)
    _resolveRow(
      row: row,
      mapping: mapping,
      registries: registries,
      settings: settings,
    ),
];

ResolvedCsvRow _resolveRow({
  required CsvRow row,
  required CsvMapping mapping,
  required Registries registries,
  required ProjectSettings settings,
}) {
  final issues = <CsvCellIssue>[];

  String? cell(CsvColumnTarget target) {
    final column = mapping.columnFor(target);
    if (column == null) return null;
    final raw = row.cells[column].trim();
    return raw.isEmpty ? null : raw;
  }

  int? columnOf(CsvColumnTarget target) => mapping.columnFor(target);

  // --- the room, the one field with no honest partial answer ---------
  final locationName = cell(CsvColumnTarget.location) ?? '';
  if (locationName.isEmpty) {
    issues.add(
      CsvCellIssue(
        severity: CsvIssueSeverity.error,
        message: 'This row names no room, so there is nowhere to put it.',
        column: columnOf(CsvColumnTarget.location),
      ),
    );
  }

  // --- what this row is made of --------------------------------------
  final items = mapping.shape == CsvShape.wide
      ? _wideItems(row, mapping, issues)
      : _longItems(row, mapping, registries, issues);

  // --- lengths, statuses, terminations -------------------------------
  Len? routedLength;
  if (cell(CsvColumnTarget.routedLength) case final text?) {
    final parsed = parseLengthCell(text, settings.displayUnits);
    switch (parsed) {
      case CellParsed<Len>(:final value):
        routedLength = value;
      case CellRefused<Len>(:final reason):
        // G4: the length is UNKNOWN, not zero and not a guess at what
        // `62'6"` meant. The row still imports.
        issues.add(
          CsvCellIssue(
            severity: CsvIssueSeverity.warning,
            message: '$reason The length is left unknown.',
            column: columnOf(CsvColumnTarget.routedLength),
          ),
        );
    }
  }

  final roughInStatus = _resolveEnum<RoughInStatus>(
    cell(CsvColumnTarget.roughInStatus),
    RoughInStatus.values,
    (v) => v.name,
    column: columnOf(CsvColumnTarget.roughInStatus),
    what: 'a rough-in status',
    issues: issues,
  );

  final rackTermination = _resolveEnum<TerminationType>(
    cell(CsvColumnTarget.rackTermination),
    TerminationType.values,
    (v) => v.name,
    column: columnOf(CsvColumnTarget.rackTermination),
    what: 'a termination type',
    issues: issues,
  );

  final terminationField = _resolveEnum<TerminationType>(
    cell(CsvColumnTarget.terminationField),
    TerminationType.values,
    (v) => v.name,
    column: columnOf(CsvColumnTarget.terminationField),
    what: 'a termination type',
    issues: issues,
  );

  // --- the signal family, which REFUSES rather than inventing --------
  SignalFamilyId? signalFamily;
  if (cell(CsvColumnTarget.signal) case final text?) {
    final def = resolveSignalFamilyToken(registries, text);
    if (def == null) {
      issues.add(
        CsvCellIssue(
          severity: CsvIssueSeverity.warning,
          message:
              '"$text" is not a signal family this catalog carries, so '
              'the run is left undetermined. Families are catalog-updated '
              'and an import never invents one (DR-025).',
          column: columnOf(CsvColumnTarget.signal),
        ),
      );
    } else {
      signalFamily = def.id;
    }
  }

  // --- the two jacket columns, independently -------------------------
  final jacketColor = _resolveJacket(
    cell(CsvColumnTarget.jacketColor),
    settings,
  );
  var jacketColorPulled = _resolveJacket(
    cell(CsvColumnTarget.jacketColorPulled),
    settings,
  );
  // "An as-pulled value EQUAL to the convention value is not an
  // exception and normalises to absent" (§5.1), so an exceptions count
  // cannot be inflated by a no-op import.
  if (jacketColorPulled != null && jacketColorPulled == jacketColor) {
    jacketColorPulled = null;
  }
  for (final (column, id) in [
    (columnOf(CsvColumnTarget.jacketColor), jacketColor),
    (columnOf(CsvColumnTarget.jacketColorPulled), jacketColorPulled),
  ]) {
    if (id == null) continue;
    if (settings.jacketColorConventions.containsKey(id)) continue;
    issues.add(
      CsvCellIssue(
        severity: CsvIssueSeverity.warning,
        message:
            '"${id.v}" is not in this project\'s colour conventions. '
            'It is kept exactly as written and counted as unknown, never '
            'snapped to the nearest entry.',
        column: column,
      ),
    );
  }

  // --- everything a column preserves ---------------------------------
  final unknown = <String, Object?>{};
  for (final column in mapping.keptColumns) {
    final raw = row.cells[column].trim();
    if (raw.isEmpty) continue;
    unknown[mapping.unknownKeyFor(column)] = raw;
  }
  // A row longer than its header still has data on it, and the reader
  // kept it precisely so this layer would not have to drop it.
  for (var n = 0; n < row.overflow.length; n++) {
    final raw = row.overflow[n].trim();
    if (raw.isEmpty) continue;
    unknown['overflow ${mapping.headers.length + n + 1}'] = raw;
  }
  if (row.isRagged) {
    issues.add(
      CsvCellIssue(
        severity: CsvIssueSeverity.warning,
        message:
            'This row has ${row.overflow.length} more values than there '
            'are columns, usually an unescaped comma. They are kept as extra '
            'data rather than dropped.',
      ),
    );
  }

  return ResolvedCsvRow(
    source: row,
    locationName: locationName,
    items: items,
    unknown: Map.unmodifiable(unknown),
    issues: List.unmodifiable(issues),
    floor: cell(CsvColumnTarget.floor),
    building: cell(CsvColumnTarget.building),
    outletDesignation: cell(CsvColumnTarget.outlet),
    fieldLabel: cell(CsvColumnTarget.fieldLabel),
    rackLabel: cell(CsvColumnTarget.rackLabel),
    serviceToken: cell(CsvColumnTarget.service),
    signalFamily: signalFamily,
    pathwayName: cell(CsvColumnTarget.pathway),
    routedLength: routedLength,
    rackTermination: rackTermination,
    terminationField: terminationField,
    roughInStatus: roughInStatus,
    jacketColor: jacketColor,
    jacketColorPulled: jacketColorPulled,
    notes: cell(CsvColumnTarget.notes),
  );
}

/// The long shape: one cable column, one quantity column, one item.
List<ResolvedCsvItem> _longItems(
  CsvRow row,
  CsvMapping mapping,
  Registries registries,
  List<CsvCellIssue> issues,
) {
  final mediaColumn = mapping.columnFor(CsvColumnTarget.media);
  final token = mediaColumn == null ? '' : row.cells[mediaColumn].trim();
  if (token.isEmpty) {
    issues.add(
      CsvCellIssue(
        severity: CsvIssueSeverity.warning,
        message: 'This row names no cable, so it creates no drop.',
        column: mediaColumn,
      ),
    );
    return const [];
  }

  final qtyColumn = mapping.columnFor(CsvColumnTarget.qty);
  var count = 1;
  if (qtyColumn != null) {
    final raw = row.cells[qtyColumn].trim();
    if (raw.isNotEmpty) {
      final n = int.tryParse(raw);
      // ABSENT MEANS ONE (§5.1) and so does unreadable, because a row
      // that named a cable is a drop; treating a bad quantity as zero
      // would delete a run the sheet says exists.
      if (n == null || n < 0) {
        issues.add(
          CsvCellIssue(
            severity: CsvIssueSeverity.warning,
            message:
                '"$raw" is not a quantity, so this row is read as one '
                'drop.',
            column: qtyColumn,
          ),
        );
      } else {
        count = n;
      }
    }
  }
  if (count == 0) return const [];

  final def = resolveMediaToken(registries, token);
  return [
    ResolvedCsvItem(
      media: def == null ? ResolvedMediaNew(token) : ResolvedMediaKnown(def.id),
      count: count,
    ),
  ];
}

/// The wide shape: one item per cable column holding a positive count.
///
/// A BLANK OR ZERO CELL IS NOT AN ITEM, and that is what a wide sheet
/// means by leaving the speaker column empty for a room with no
/// speakers. `csv_reader.dart` deliberately did not answer this: it only
/// said the column holds counts rather than words.
List<ResolvedCsvItem> _wideItems(
  CsvRow row,
  CsvMapping mapping,
  List<CsvCellIssue> issues,
) {
  final out = <ResolvedCsvItem>[];
  for (final (:column, :media) in mapping.mediaCountColumns) {
    final raw = row.cells[column].trim();
    if (raw.isEmpty) continue;
    final n = int.tryParse(raw);
    if (n == null || n < 0) {
      issues.add(
        CsvCellIssue(
          severity: CsvIssueSeverity.warning,
          message:
              '"$raw" is not a count, so this cable is skipped for this '
              'room.',
          column: column,
        ),
      );
      continue;
    }
    if (n == 0) continue;
    out.add(
      ResolvedCsvItem(media: ResolvedMediaKnown(media), count: n),
    );
  }
  return out;
}

/// A word → an enum value, by §5.1's four transforms.
///
/// The same normalisation the header table uses, so §5.2's `F barrel`
/// reaches `fBarrel` without a second spelling table. An unreadable
/// value leaves the field UNKNOWN and says so.
T? _resolveEnum<T>(
  String? text,
  List<T> values,
  String Function(T) nameOf, {
  required int? column,
  required String what,
  required List<CsvCellIssue> issues,
}) {
  if (text == null) return null;
  final want = normaliseMediaToken(text);
  for (final v in values) {
    if (normaliseMediaToken(nameOf(v)) == want) return v;
  }
  issues.add(
    CsvCellIssue(
      severity: CsvIssueSeverity.warning,
      message:
          '"$text" is not $what. Use one of: '
          '${values.map(nameOf).join(', ')}. The field is left unknown.',
      column: column,
    ),
  );
  return null;
}

/// A colour word → a [JacketColorId].
///
/// **AN UNMATCHED VALUE BECOMES A DANGLING ID, NOT NULL** (§5.1's
/// blockquote). Matching is by `abbr` then `displayName`, both under the
/// four transforms, so `BLU`, `blu` and `Blue` all reach the same entry.
/// A word matching neither is kept verbatim as the id, because it is the
/// one record that a particular colour went in a particular wall and it
/// must outlive the entry naming it.
JacketColorId? _resolveJacket(String? text, ProjectSettings settings) {
  if (text == null) return null;
  final want = normaliseMediaToken(text);
  for (final e in settings.jacketColorConventions.entries) {
    if (normaliseMediaToken(e.value.abbr) == want) return e.key;
  }
  for (final e in settings.jacketColorConventions.entries) {
    if (normaliseMediaToken(e.value.displayName) == want) return e.key;
  }
  return JacketColorId(text);
}
