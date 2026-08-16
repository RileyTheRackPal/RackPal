// TSV COPY AND PASTE FOR THE PORT GRID (M4-F3 `#210`, docs/06 §4.6).
//
// ═══════════════════════════════════════════════════════════════════════
// THIS IS NOT M4-I3, AND THE CORPUS KEEPS THEM APART ON PURPOSE
// ═══════════════════════════════════════════════════════════════════════
// `#222` is *"paste from spreadsheet: TSV/CSV with a column-mapping
// sheet, sharing the engine with the Structure CSV import, use it, do not
// fork it"*. That is docs/06 §4.4's `[Paste]` BUTTON, for somebody else's
// spreadsheet, whose columns nobody has agreed on yet.
//
// This is §4.6's `Ctrl+C` / `Ctrl+V` row: the grid's OWN shape, out and
// back, with no mapping step because there is nothing to map. Two
// features, two entry points, and neither forks the other: what M3's
// engine solves is *which column is this*, and here the answer is on the
// clipboard's first line.
//
// ═══════════════════════════════════════════════════════════════════════
// READABLE IN EXCEL **AND** LOSSLESS, BY REUSING THE RESOLVERS
// ═══════════════════════════════════════════════════════════════════════
// The round trip is `#210`'s own test, so every value written here has to
// parse back to the value it came from. That normally argues for raw ids
// and against readability. It does not have to, because the resolvers
// this project already ships accept the readable spelling:
//
//   connector  `portConnectorShortLabel` -> `RJ45`, and
//              `resolveConnectorToken` takes an alias (DR-060)
//   family     `displayName` -> `Ethernet`, and
//              `resolveSignalFamilyToken` ends its chain on displayName
//              (DR-025 §11.24.3)
//   enums      the grid's own label functions, reversed over a closed set
//   the rest   text and numbers, which are their own spelling
//
// So an integrator sees `RJ45` and `Ethernet` in Excel, and the same
// cells come home. Nothing here re-implements a lookup that exists.
//
// ═══════════════════════════════════════════════════════════════════════
// A PASTE DOES NOT CREATE PORTS
// ═══════════════════════════════════════════════════════════════════════
// `structure_editor_screen.dart` already ruled this for the drop table
// and the reasoning transfers unchanged: ten values into the last three
// rows would invent seven ports, each needing a key nobody chose. It
// refuses and says by how much. `+ Add port` and Quick Add are how ports
// come into existence, and both are one gesture away.
import 'package:rackmate_core/src/builder/port_batch.dart';
import 'package:rackmate_core/src/builder/port_fill.dart';
import 'package:rackmate_core/src/builder/port_table.dart';
import 'package:rackmate_core/src/commands/command.dart';
import 'package:rackmate_core/src/model/registries.dart';
import 'package:rackmate_core/src/model/template.dart';
import 'package:rackmate_core/src/structure/drop_line_planner.dart'
    show resolveConnectorToken, resolveSignalFamilyToken;

/// The cell separator. TSV and not CSV, because that is what a spreadsheet
/// puts on the clipboard and what it expects to find there: a comma would
/// make every label containing one into two cells.
const String kTsvCell = '\t';

/// What one cell of [column] reads on the clipboard.
///
/// EMPTY FOR UNKNOWN, NOT `—`. The dash is a rendering for a person
/// looking at a grid; a spreadsheet cell that is unknown is EMPTY, and
/// pasting `—` back into Excel would leave a literal dash in a numeric
/// column. [parsePortCell] treats empty as unknown, which closes the trip.
String portCellToTsv(
  PortColumnId column,
  PortDef port,
  Registries registries,
) {
  final fill = portColumnFill(column);
  if (fill == null) return '';
  final value = fill.read(port);
  if (value == null) return '';
  return switch (column) {
    PortColumnId.connector => portConnectorShortLabelFor(registries, port),
    PortColumnId.family =>
      registries.signalFamilies[port.signalFamily]?.displayName ??
          port.signalFamily.v,
    _ => portValueLabel(column, value, registries),
  };
}

/// `portConnectorShortLabel` without importing the summary's whole file.
///
/// The alias upper-cased (`RJ45`), falling back to the display name and
/// then the raw id, which is exactly what the footer prints. An unknown
/// connector still writes something a person can search for.
String portConnectorShortLabelFor(Registries registries, PortDef port) {
  final def = registries.connectorTypes[port.connector];
  if (def == null) return port.connector.v;
  return def.aliases.isEmpty
      ? def.displayName
      : def.aliases.first.toUpperCase();
}

/// The clipboard text for [portKeys] over [columns].
///
/// A HEADER ROW LEADS IT, which is the difference between a usable sheet
/// and eight anonymous columns for somebody who lives in Excel. It comes
/// home too: `parsePortTsv` drops a first line whose every cell is a
/// column header, so a straight round trip works and so does a sheet
/// somebody labelled by hand.
String buildPortTsv({
  required TemplateBody body,
  required List<PortColumnId> columns,
  required List<String> portKeys,
  required Registries registries,
}) {
  final byKey = {for (final port in body.ports) port.key.v: port};
  final lines = <String>[
    [for (final c in columns) portColumnHeader(c)].join(kTsvCell),
    for (final key in portKeys)
      if (byKey[key] case final PortDef port)
        [
          for (final c in columns) portCellToTsv(c, port, registries),
        ].join(kTsvCell),
  ];
  // `\n` AND NOT `\r\n`. Excel accepts either on paste, and every reader
  // in this file normalises anyway; emitting one line ending means the
  // round-trip test compares one thing.
  return lines.join('\n');
}

/// Why a paste did nothing, or did less than all of it.
enum PortPasteRefusal {
  /// Focus is not in a cell, so there is no corner to paste from.
  needsACell,

  /// The clipboard holds nothing, or nothing but whitespace.
  nothingToPaste,

  /// More rows on the clipboard than there are below the caret. A paste
  /// does not create ports.
  tooManyRows,

  /// More columns on the clipboard than there are to the right.
  tooManyColumns,
}

/// A parsed paste: the writes it implies, or why there are none.
final class PortPastePlan {
  const PortPastePlan.commands(this.commands, {this.skippedHeader = false})
    : refusal = null,
      overrun = 0;
  const PortPastePlan.refused(
    PortPasteRefusal this.refusal, {
    this.overrun = 0,
  }) : commands = const [],
       skippedHeader = false;

  final List<Command<TemplateBody>> commands;
  final PortPasteRefusal? refusal;

  /// How many rows or columns too many, for a message that says the size
  /// rather than only the fact.
  final int overrun;

  /// True when the clipboard's first line was a header and was dropped.
  final bool skippedHeader;

  bool get isRefused => refusal != null;
}

/// Whether [cells] is a header row for [columns].
///
/// EVERY CELL MUST MATCH, and that is what makes the heuristic safe. A
/// port genuinely labelled `LABEL` sits in a row whose other cells are a
/// connector and a direction, so a one-row copy of it is not mistaken for
/// a header. Requiring all of them makes the false positive essentially
/// unreachable rather than merely unlikely.
bool looksLikePortTsvHeader(List<String> cells, List<PortColumnId> columns) {
  if (cells.isEmpty || cells.length > columns.length) return false;
  for (var i = 0; i < cells.length; i++) {
    if (cells[i].trim().toUpperCase() != portColumnHeader(columns[i])) {
      return false;
    }
  }
  return true;
}

/// Reads [text] as a paste into [visibleRowKeys], with the cell named by
/// [anchorKey] and [anchorColumn] as its top-left corner.
///
/// TOTAL AND NEVER THROWS: a cell that resolves to nothing is skipped and
/// the rest of the paste lands, because an integrator pasting forty rows
/// should not lose thirty-nine to one typo. What it will not do is guess:
/// an unresolvable connector writes nothing rather than an invented one.
PortPastePlan parsePortTsv({
  required TemplateBody body,
  required String text,
  required List<PortColumnId> columns,
  required List<String> visibleRowKeys,
  required String? anchorKey,
  required PortColumnId? anchorColumn,
  required Registries registries,
}) {
  if (anchorKey == null || anchorColumn == null) {
    return const PortPastePlan.refused(PortPasteRefusal.needsACell);
  }
  if (text.trim().isEmpty) {
    return const PortPastePlan.refused(PortPasteRefusal.nothingToPaste);
  }
  final firstRow = visibleRowKeys.indexOf(anchorKey);
  final firstColumn = columns.indexOf(anchorColumn);
  if (firstRow < 0 || firstColumn < 0) {
    return const PortPastePlan.refused(PortPasteRefusal.needsACell);
  }

  // `\r\n` AND `\n`, because the clipboard's line ending belongs to the
  // application that wrote it and not to this platform: Excel and a text
  // editor on one machine disagree, and a stray `\r` lands inside a
  // label. `structure_editor_screen.dart` learned this first.
  final lines = text.replaceAll('\r\n', '\n').split('\n')
    ..removeWhere((l) => l.isEmpty);
  if (lines.isEmpty) {
    return const PortPastePlan.refused(PortPasteRefusal.nothingToPaste);
  }

  var skippedHeader = false;
  if (looksLikePortTsvHeader(
    lines.first.split(kTsvCell),
    columns.sublist(firstColumn),
  )) {
    lines.removeAt(0);
    skippedHeader = true;
    if (lines.isEmpty) {
      return const PortPastePlan.refused(PortPasteRefusal.nothingToPaste);
    }
  }

  if (firstRow + lines.length > visibleRowKeys.length) {
    return PortPastePlan.refused(
      PortPasteRefusal.tooManyRows,
      overrun: firstRow + lines.length - visibleRowKeys.length,
    );
  }
  final widest = lines.fold<int>(
    0,
    (n, l) => l.split(kTsvCell).length > n ? l.split(kTsvCell).length : n,
  );
  if (firstColumn + widest > columns.length) {
    return PortPastePlan.refused(
      PortPasteRefusal.tooManyColumns,
      overrun: firstColumn + widest - columns.length,
    );
  }

  final byKey = {for (final port in body.ports) port.key.v: port};
  final commands = <Command<TemplateBody>>[];
  for (var r = 0; r < lines.length; r++) {
    final port = byKey[visibleRowKeys[firstRow + r]];
    if (port == null) continue;
    final cells = lines[r].split(kTsvCell);
    for (var c = 0; c < cells.length; c++) {
      final column = columns[firstColumn + c];
      final fill = portColumnFill(column);
      if (fill == null) continue;
      final parsed = parsePortCell(column, cells[c], registries);
      if (!parsed.ok) continue;
      final write = fill.write(port, parsed.value);
      if (write != null) commands.add(write);
    }
  }
  return PortPastePlan.commands(commands, skippedHeader: skippedHeader);
}

/// One cell, parsed for [column].
///
/// `ok` IS NOT `value != null`, and the distinction is G4's. An empty
/// cell parses to `(ok: true, value: null)`, which WRITES an unknown,
/// because clearing a column across a paste is a thing a person means.
/// An unresolvable one parses to `(ok: false, …)`, which writes nothing,
/// because a connector nobody can name is not a connector.
({bool ok, Object? value}) parsePortCell(
  PortColumnId column,
  String cell,
  Registries registries,
) {
  final text = cell.trim();
  if (text.isEmpty) return (ok: true, value: null);

  // THE TWO REGISTRY COLUMNS RESOLVE RATHER THAN MATCH, through the
  // chains DR-060 and DR-025 already built. An id nobody holds is not a
  // typo to correct here; it is a refusal.
  if (column == PortColumnId.connector) {
    final def = resolveConnectorToken(registries, text);
    return def == null ? (ok: false, value: null) : (ok: true, value: def.id);
  }
  if (column == PortColumnId.family) {
    final def = resolveSignalFamilyToken(registries, text);
    return def == null ? (ok: false, value: null) : (ok: true, value: def.id);
  }

  // ENUMS, REVERSED OVER THEIR OWN LABELS. The write side prints
  // `portValueLabel`, so the read side asks that same function which
  // member produced the text. One vocabulary, inverted, rather than a
  // second table that drifts from the first.
  final options = portColumnOptions(column);
  if (options != null) {
    for (final option in options) {
      if (portValueLabel(column, option, registries) == text) {
        return (ok: true, value: option);
      }
    }
    return (ok: false, value: null);
  }

  final fill = portColumnFill(column);
  if (fill?.text != null) return (ok: true, value: text);

  final asInt = int.tryParse(text);
  return asInt == null ? (ok: false, value: null) : (ok: true, value: asInt);
}

/// What the grid says when a copy has nothing to take.
const String kCopyNeedsRows =
    'Select one or more rows to copy them as a spreadsheet.';

/// What the grid says when a paste declines.
///
/// IN CORE, BESIDE THE REFUSAL, for `portFillRefusalMessage`'s reason: a
/// sentence built in the widget is a second vocabulary, and the first
/// time one of them changes they disagree.
String portPasteRefusalMessage(
  PortPasteRefusal refusal,
  PortPastePlan plan,
) => switch (refusal) {
  PortPasteRefusal.needsACell =>
    'Click a cell first, so the paste knows where to start.',
  PortPasteRefusal.nothingToPaste => 'There is nothing on the clipboard.',
  PortPasteRefusal.tooManyRows =>
    'That is ${plan.overrun} row${plan.overrun == 1 ? '' : 's'} more than '
        'there is room for. A paste does not create ports: add them first, '
        'or start higher up.',
  PortPasteRefusal.tooManyColumns =>
    'That is ${plan.overrun} column${plan.overrun == 1 ? '' : 's'} wider '
        'than the grid is showing from here.',
};
