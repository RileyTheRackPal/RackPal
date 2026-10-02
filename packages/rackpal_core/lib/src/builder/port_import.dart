// IMPORT FROM SPREADSHEET (M4-I3 `#222`, docs/06 §4.3's `[Paste]`).
//
// **NAMED `PortImport` AND NOT `PortPaste`, because `port_tsv.dart` got
// there first and means something else.** That file's `PortPastePlan` is
// §4.6's `Ctrl+V` into the grid; this is the button that reads somebody
// else's sheet. Two features, two vocabularies, and the collision was a
// compiler error rather than a subtle one, which is the good kind.
//
// ═══════════════════════════════════════════════════════════════════════
// IT USES M3'S ENGINE AND DOES NOT FORK IT, WHICH IS THE TASK'S OWN WORDS
// ═══════════════════════════════════════════════════════════════════════
// `#222`: *"sharing the engine with the Structure CSV import, use it, do
// not fork it"*. So the quoting rules, the ragged-row handling, the
// limits, the refusals and the header normalisation all come from
// `structure/csv_reader.dart` and `structure/csv_header_map.dart`.
//
// **THE ONE CHANGE THAT ENGINE NEEDED WAS A DECLARED DELIMITER**, because
// a spreadsheet puts TABS on the clipboard and `readCsv` refuses a tab
// file by design rather than sniffing. Its own comment names the shape
// the fix had to take: *"a ruling and a user-visible choice, not a
// counter"*. [CsvDelimiter] is that choice and the dialog exposes it; M3
// keeps comma and is untouched.
//
// ═══════════════════════════════════════════════════════════════════════
// THIS IS NOT `port_tsv.dart`, AND THE TWO STAY APART
// ═══════════════════════════════════════════════════════════════════════
// That file is docs/06 §4.6's `Ctrl+C` / `Ctrl+V`: the grid's OWN shape
// out and back, with no mapping step because there is nothing to map, and
// it deliberately **refuses to create ports**. This is §4.3's `[Paste]`
// button, for somebody else's spreadsheet, whose columns nobody has
// agreed on yet, and **creating ports is the whole point of it**: a sheet
// of forty-eight rows is forty-eight ports that do not exist yet.
//
// What they share is `parsePortCell`, which is the one place a cell's
// text becomes a value, so `RJ45` and `Ethernet` mean the same thing on
// both paths.
//
// ═══════════════════════════════════════════════════════════════════════
// THE SYNONYM TABLE INHERITS M3-F's CAP RATHER THAN RE-OPENING IT
// ═══════════════════════════════════════════════════════════════════════
// `#222` says so in as many words, and `csv_header_map.dart`'s header
// says why: roadmap §4 names CSV synonym mapping as M3's scope hazard BY
// NAME, and the cap is the deliverable. So [kPortImportSynonyms] is a
// fixed table, [matchPortImportHeader] answers from it or answers null, and
// there is no fuzzy match, no edit distance, no stemming and no learning
// step. An unmatched column falls through to the manual assign step,
// which is exactly what the Structure sheet does.
//
// ═══════════════════════════════════════════════════════════════════════
// AN UNMAPPED COLUMN IS DROPPED HERE, WHERE M3 PRESERVES IT, AND THE
// DIFFERENCE IS A MODEL FACT RATHER THAN A DECISION
// ═══════════════════════════════════════════════════════════════════════
// `csv_mapping.dart` refuses a "discard" option outright, because §5.1 is
// unconditional that unmapped columns are "preserved into the row's
// `unknown` map". **`PortDef` HAS NO SUCH MAP.** The forward-compatibility
// passthrough the document format is built on lives on the document's own
// entities, and a port inside a template body is not one of them.
//
// So a column nobody maps cannot be kept, and the honest response is to
// SAY SO: [PortImportPlan.droppedColumns] counts them and the dialog
// prints the count beside the import. A visible discard is not the silent
// one canon §4.2 forbids. Giving `PortDef` an `unknown` map is a model
// change, a codec change and four regenerated starters, and it is a
// ruling somebody should raise the first time a shop actually needs it.
import 'package:meta/meta.dart';
import 'package:rackpal_core/src/builder/port_fill.dart';
import 'package:rackpal_core/src/builder/port_table.dart';
import 'package:rackpal_core/src/builder/port_tsv.dart' show parsePortCell;
import 'package:rackpal_core/src/builder/quick_add.dart';
import 'package:rackpal_core/src/commands/command.dart';
import 'package:rackpal_core/src/model/placement.dart';
import 'package:rackpal_core/src/model/registries.dart';
import 'package:rackpal_core/src/model/template.dart';
import 'package:rackpal_core/src/structure/csv_header_map.dart'
    show normaliseCsvHeader;
import 'package:rackpal_core/src/units/ids.dart';

/// Where one source column's cells go.
///
/// A sealed pair rather than a bare [PortColumnId], because **the bank is
/// not a column**. The grid bands by `PortDef.bankKey` and offers
/// `Move to bank…` as the editing path, so `PortColumnId` has no `bank`
/// member at all. A spreadsheet of ports very often has one, and a paste
/// that could not read it would land sixty-eight rows in `Not in a bank`.
@immutable
sealed class PortImportTarget {
  const PortImportTarget();

  /// The bank a row's ports land in, matched or created by LABEL.
  static const PortImportTarget bank = _PortImportBank();

  /// Every target a mapping sheet can offer, bank first.
  static List<PortImportTarget> get all => <PortImportTarget>[
    bank,
    for (final column in PortColumnId.values)
      if (portColumnFill(column) != null) PortImportColumn(column),
  ];

  /// What the mapping sheet calls this target.
  String get header;
}

/// The column feeds one of the grid's own columns.
@immutable
final class PortImportColumn extends PortImportTarget {
  const PortImportColumn(this.column);

  final PortColumnId column;

  @override
  String get header => portColumnHeader(column);

  @override
  bool operator ==(Object other) =>
      other is PortImportColumn && other.column == column;

  @override
  int get hashCode => column.hashCode;

  @override
  String toString() => 'PortImportColumn(${column.name})';
}

@immutable
final class _PortImportBank extends PortImportTarget {
  const _PortImportBank();

  @override
  String get header => 'BANK';

  @override
  bool operator ==(Object other) => other is _PortImportBank;

  @override
  int get hashCode => 0x8a4b;

  @override
  String toString() => 'PortImportTarget.bank';
}

/// The capped synonym table, on `csv_header_map.dart`'s pattern.
///
/// **NORMALISED KEYS.** [normaliseCsvHeader] is case-, space-,
/// underscore- and hyphen-insensitive, and it is M3's function rather
/// than a fourth copy of those four transforms.
///
/// The grid's own header for every target is matched WITHOUT being listed
/// here (see [matchPortImportHeader]), so this table holds only the spellings
/// somebody else's spreadsheet uses. That is what keeps it short: a
/// round trip through `Copy` needs no synonyms at all.
const Map<String, PortImportTarget> kPortImportSynonyms = {
  'port': PortImportColumn(PortColumnId.label),
  'name': PortImportColumn(PortColumnId.label),
  'portname': PortImportColumn(PortColumnId.label),
  'silkscreen': PortImportColumn(PortColumnId.label),
  'legend': PortImportColumn(PortColumnId.label),
  'ref': PortImportColumn(PortColumnId.designator),
  'refdes': PortImportColumn(PortColumnId.designator),
  'reference': PortImportColumn(PortColumnId.designator),
  'jack': PortImportColumn(PortColumnId.connector),
  'conn': PortImportColumn(PortColumnId.connector),
  'connectortype': PortImportColumn(PortColumnId.connector),
  'signal': PortImportColumn(PortColumnId.family),
  'signalfamily': PortImportColumn(PortColumnId.family),
  'type': PortImportColumn(PortColumnId.family),
  'dir': PortImportColumn(PortColumnId.direction),
  'io': PortImportColumn(PortColumnId.direction),
  'inout': PortImportColumn(PortColumnId.direction),
  'side': PortImportColumn(PortColumnId.face),
  'panel': PortImportColumn(PortColumnId.face),
  'frontrear': PortImportColumn(PortColumnId.face),
  'group': PortImportTarget.bank,
  'section': PortImportTarget.bank,
  'block': PortImportTarget.bank,
  'note': PortImportColumn(PortColumnId.notes),
  'comment': PortImportColumn(PortColumnId.notes),
  'comments': PortImportColumn(PortColumnId.notes),
  'remarks': PortImportColumn(PortColumnId.notes),
  'speed': PortImportColumn(PortColumnId.linkSpeedMbps),
  'linkspeed': PortImportColumn(PortColumnId.linkSpeedMbps),
  'impedance': PortImportColumn(PortColumnId.impedanceOhms),
  'ohms': PortImportColumn(PortColumnId.impedanceOhms),
  'pinout': PortImportColumn(PortColumnId.pinoutVariant),
  'terminals': PortImportColumn(PortColumnId.terminalRoles),
  'set': PortImportColumn(PortColumnId.portSet),
  'portset': PortImportColumn(PortColumnId.portSet),
  'role': PortImportColumn(PortColumnId.setRole),
};

/// [header]'s target, or null when nothing in the table answers.
///
/// **THE GRID'S OWN HEADERS MATCH FIRST AND ARE NOT IN THE TABLE.** A
/// sheet exported by `Copy` carries `LABEL`, `CONN`, `PoE STD` and the
/// rest, and listing forty-odd of those beside the synonyms would be two
/// tables saying the same thing, one of which goes stale when a column is
/// renamed. Derived from [PortImportTarget.all] instead, so a renamed
/// column keeps matching for free.
PortImportTarget? matchPortImportHeader(String header) {
  final want = normaliseCsvHeader(header);
  if (want.isEmpty) return null;
  for (final target in PortImportTarget.all) {
    if (normaliseCsvHeader(target.header) == want) return target;
  }
  return kPortImportSynonyms[want];
}

/// The mapping sheet's state: one assignment per source column.
///
/// Immutable, and [withAssignment] returns a new one, for the reason
/// `csv_mapping.dart` gives: the surface re-renders a preview against a
/// candidate mapping without committing to it, which is what makes a
/// one-dialog live preview possible.
@immutable
final class PortImportMapping {
  const PortImportMapping(this.headers, this.assignments);

  /// RackPal's guess for every header in [headers].
  factory PortImportMapping.guess(List<String> headers) => PortImportMapping(
    List<String>.unmodifiable(headers),
    List<PortImportTarget?>.unmodifiable(headers.map(matchPortImportHeader)),
  );

  /// As typed, so the sheet shows a person their own spelling.
  final List<String> headers;

  /// Null is `Not imported`, which is a real state here: `PortDef` has no
  /// `unknown` map to preserve a column into.
  final List<PortImportTarget?> assignments;

  PortImportMapping withAssignment(int column, PortImportTarget? target) {
    final next = [...assignments];
    next[column] = target;
    // A TARGET IS CLAIMED BY ONE COLUMN. Two columns both feeding LABEL
    // means the second silently wins, and a person looking at the sheet
    // cannot see which. The earlier one is released instead, and the
    // sheet shows it fall back to `Not imported`.
    if (target != null) {
      for (var i = 0; i < next.length; i++) {
        if (i != column && next[i] == target) next[i] = null;
      }
    }
    return PortImportMapping(
      headers,
      List<PortImportTarget?>.unmodifiable(next),
    );
  }

  /// The column feeding [target], or null.
  int? columnFor(PortImportTarget target) {
    final at = assignments.indexOf(target);
    return at < 0 ? null : at;
  }

  /// How many columns are going nowhere.
  int get unmappedColumns => assignments.where((a) => a == null).length;

  /// Nothing at all is mapped, so an import would create blank ports.
  bool get isEmpty => assignments.every((a) => a == null);
}

/// What an import would do, counted before any command exists.
@immutable
final class PortImportPlan {
  const PortImportPlan({
    required this.ports,
    required this.banks,
    required this.skippedRows,
    required this.droppedColumns,
    required this.unresolvedCells,
  });

  /// Ports the import creates. One per kept row.
  final int ports;

  /// Banks it creates. **NEW ONES ONLY**, as `previewArchetype` counts.
  final int banks;

  /// Rows whose every mapped cell was empty.
  ///
  /// SKIPPED AND COUNTED, never imported as a blank port. A trailing run
  /// of empty rows is what a spreadsheet always has, and forty phantom
  /// ports is a worse outcome than a number on screen.
  final int skippedRows;

  /// Columns nobody mapped. See this file's header: `PortDef` has no
  /// `unknown` map, so these are lost, and a lost column is announced.
  final int droppedColumns;

  /// Cells whose text named nothing the registry holds.
  ///
  /// **NOT AN ERROR AND NOT A GUESS.** `parsePortCell` writes nothing
  /// for a connector nobody can name, so the port arrives with that half
  /// unknown and the grid's validation dot marks it. The count is here
  /// so a sheet full of a competitor's spelling is visible as one number
  /// rather than as forty dots.
  final int unresolvedCells;
}

/// One row of the source, resolved against a mapping.
///
/// **IT CARRIES THE `QuickAddPlan`, AND THAT IS WHAT KEEPS THE COUNT
/// HONEST.** The first draft built a plan only on the build path and
/// counted banks on the plan path by looking for an explicit bank cell.
/// A row with no bank column derives one through `uniqueBankNameAmong`,
/// so the preview said "0 banks" and the import made one. The two
/// paths now read the same object.
@immutable
final class _Row {
  const _Row(this.label, this.plan, this.writes, this.unresolved);
  final String label;
  final QuickAddPlan plan;
  final List<(PortColumnId, Object?)> writes;
  final int unresolved;

  bool get isEmpty => label.isEmpty && plan.bankName == null && writes.isEmpty;
}

List<_Row> _resolve(
  Registries registries,
  PortImportMapping mapping,
  List<List<String>> rows,
) {
  final out = <_Row>[];
  for (final cells in rows) {
    var label = '';
    String? bank;
    var unresolved = 0;
    final writes = <(PortColumnId, Object?)>[];
    for (var i = 0; i < mapping.assignments.length && i < cells.length; i++) {
      final target = mapping.assignments[i];
      if (target == null) continue;
      final text = cells[i].trim();
      if (target == PortImportTarget.bank) {
        if (text.isNotEmpty) bank = text;
        continue;
      }
      final column = (target as PortImportColumn).column;
      if (column == PortColumnId.label) {
        label = text;
        continue;
      }
      if (text.isEmpty) continue;
      final parsed = parsePortCell(column, text, registries);
      if (!parsed.ok) {
        unresolved++;
        continue;
      }
      writes.add((column, parsed.value));
    }
    final byColumn = {for (final (column, value) in writes) column: value};
    out.add(
      _Row(
        label,
        QuickAddPlan(
          // NO SOURCE TEXT. A pasted row is not a command anybody typed,
          // and rendering one would claim a provenance it does not have.
          source: '',
          quantity: 1,
          connector: byColumn[PortColumnId.connector] as ConnectorTypeId?,
          family: byColumn[PortColumnId.family] as SignalFamilyId?,
          direction: byColumn[PortColumnId.direction] as PortDirection?,
          face: byColumn[PortColumnId.face] as Face?,
          bothFaces: false,
          passthrough: false,
          // NULL, AND THE LABEL TRAVELS SEPARATELY. See
          // [QuickAddBatch.add]'s `labels`: a pasted cell is DATA, and
          // running `HDMI {n}` through the pattern engine would expand it.
          labelPattern: null,
          bankName: bank,
        ),
        writes,
        unresolved,
      ),
    );
  }
  return out;
}

/// What importing [rows] under [mapping] would do to [body].
///
/// Mutates nothing and builds no `Command`, for `csv_import_plan.dart`'s
/// reason: a count derived from a command list is a count nobody can
/// check against the rows on screen.
PortImportPlan planPortImport({
  required Registries registries,
  required TemplateBody body,
  required PortImportMapping mapping,
  required List<List<String>> rows,
}) {
  final resolved = _resolve(registries, mapping, rows);
  final kept = resolved.where((r) => !r.isEmpty).toList();
  // THROUGH `uniqueBankNameAmong`, which is what the build will use.
  // Counting only the rows with an explicit bank cell under-reports every
  // sheet that has no bank column at all, and those rows still land in a
  // bank the derivation invents.
  final existing = {for (final b in body.banks) b.label};
  var newBanks = 0;
  for (final row in kept) {
    if (existing.add(uniqueBankNameAmong(registries, existing, row.plan))) {
      newBanks++;
    }
  }
  return PortImportPlan(
    ports: kept.length,
    banks: newBanks,
    skippedRows: resolved.length - kept.length,
    droppedColumns: mapping.unmappedColumns,
    unresolvedCells: kept.fold(0, (n, r) => n + r.unresolved),
  );
}

/// The commands that carry out an import, in one allocation.
///
/// **ONE PLAN PER ROW, THROUGH `QuickAddBatch`.** A pasted row differs
/// from its neighbour field by field, which a `QuickAddPlan` cannot say
/// on its own, so each row becomes a one-port plan carrying the four
/// things a plan does hold (connector, family, direction, face) and
/// `decorate` writes the rest. The allocator is still the one Quick Add
/// and the archetypes use, so forty-eight rows and a generated matrix in
/// the same template cannot mint one key twice (DR-092 §11.91.7).
List<Command<TemplateBody>> buildPortImport({
  required Registries registries,
  required TemplateBody body,
  required PortImportMapping mapping,
  required List<List<String>> rows,
}) {
  final batch = QuickAddBatch(registries, body);
  final commands = <Command<TemplateBody>>[];

  for (final row in _resolve(registries, mapping, rows)) {
    if (row.isEmpty) continue;
    commands.addAll(
      batch.add(
        row.plan,
        labels: [row.label],
        decorate: (port) {
          for (final (column, value) in row.writes) {
            // The four the plan already carried are skipped rather than
            // written twice: `buildQuickAdd` resolved a null direction
            // against the family's default, and re-writing a null here
            // would undo that.
            if (column == PortColumnId.connector ||
                column == PortColumnId.family ||
                column == PortColumnId.direction ||
                column == PortColumnId.face ||
                column == PortColumnId.label) {
              continue;
            }
            portColumnFill(column)?.set(port, value);
          }
        },
      ),
    );
  }
  return commands;
}
