// T6.10 Pull Sheet and T6.15 Termination Schedule (docs/08 §3, M6-K
// `#978`, `#979`, DR-222).
//
// ═══════════════════════════════════════════════════════════════════════
// TWO PRESETS, ONE DERIVATION, ONE PAGE MODULE
// ═══════════════════════════════════════════════════════════════════════
// docs/08 §3.1: "same query, same row model, different projection". The
// projection is `buildScheduleView`, M3's, which the Schedule screen also
// renders; this file lays out a `ScheduleView` and decides nothing about
// which rows it holds, their order, their bands or their cells. Every cell
// is `ScheduleEntry.cell`, so the page and the screen cannot disagree.
//
// THE COLUMNS ARE THE VIEW'S, §3.2's ten and §3.3's thirteen (DR-222
// §11.221.2: fixed columns only). Their widths are scaled to the body, so
// the ruled proportions hold whatever inset the frame takes.
//
// PAGINATED BY HAND, as §3.7 says it must be: the column heads repeat on
// every page; a page that opens inside a lifecycle section or a group
// re-prints both bands `(cont.)`; a band keeps with its first row (#337's
// lesson, DR-219 §11.218.1). Both sheets are `ON`, so an empty view is a
// page saying so, never a missing sheet.
import 'package:meta/meta.dart';
import 'package:rackpal_core/src/derived/equipment_list.dart' show kUnknownCell;
import 'package:rackpal_core/src/derived/schedule.dart';
import 'package:rackpal_core/src/derived/totals.dart';
import 'package:rackpal_core/src/draw/geometry.dart';
import 'package:rackpal_core/src/draw/ops.dart';
import 'package:rackpal_core/src/draw/scene/signal_style.dart';
import 'package:rackpal_core/src/draw/sheet/drawing_scale.dart';
import 'package:rackpal_core/src/draw/sheet/equipment_sheet.dart'
    show wrapMeasured;
import 'package:rackpal_core/src/draw/sheet/materials_rollups.dart'
    show footageText;
import 'package:rackpal_core/src/draw/sheet/sheet_def.dart';
import 'package:rackpal_core/src/draw/sheet/sheet_frame.dart';
import 'package:rackpal_core/src/draw/sheet/sheet_furniture.dart';
import 'package:rackpal_core/src/draw/sheet/text_fit.dart';
import 'package:rackpal_core/src/draw/sheet/type_chip.dart';
import 'package:rackpal_core/src/draw/spec.dart';
import 'package:rackpal_core/src/draw/text.dart';
import 'package:rackpal_core/src/model/enums.dart' show UnitSystem;
import 'package:rackpal_core/src/model/project_info.dart';
import 'package:rackpal_core/src/model/project_settings.dart';
import 'package:rackpal_core/src/model/rack_document.dart' show RevisionEntry;
import 'package:rackpal_core/src/model/registries.dart';
import 'package:rackpal_core/src/units/ids.dart';
import 'package:rackpal_core/src/units/len.dart';

/// Text size and one wrapped line, in points. §3.2's body row is 15 pt
/// and its two-line row 24 pt; these give 13 and 22 plus the padding.
const double kScheduleSheetPt = 7;
const double kScheduleSheetLine = 9;
const int _kMaxLines = 2;

const double _kTitle = 20;
const double _kNote = 11;

/// Two lines of column heads: §3.2's `FROM — ROOM / OUTLET` does not fit
/// 68 pt on one, and a head cut to `FROM — ROOM …` loses the half that
/// says what the column holds.
const double _kHeads = 20;
const double _kHeadLine = 8;

/// The column heads' size. 6.5 pt, T6.30's floor, because `CONDUCTOR`
/// does not fit §3.3's 44 pt at 7.
const double kScheduleHeadPt = 6.5;
const double _kBand = 14;
const double _kSection = 16;
const double _kRowPad = 4;
const double _kInset = 8;
const double _kCellPad = 2.5;

/// What an empty schedule says: the project has no cables at all, or every
/// cable it has is excluded from this preset (the note above names how).
const String kNoCablesText = 'This project has no cables yet.';
const String kAllExcludedText =
    'No cable belongs on this sheet; the exclusions are named above.';

/// Where a pathway's designator is typed, as the notice names it: the
/// Structured Wiring tab's Pathways view, its DESIGNATOR column.
///
/// IN WORDS AND NOT WITH `▸`, which this corpus reserves for a MENU path:
/// `menu_route_copy_test.dart` reads the real menu bar and refuses a
/// route through a menu that does not exist, and Structured Wiring is a
/// tab. The first draft wrote it with the glyph and that test caught it.
const String kPathwayDesignatorRoute =
    "the DESIGNATOR column of the Structured Wiring tab's Pathways view";

/// The export notice for pathways a Pull Sheet prints without a designator
/// (DR-223 §11.222.2), or null when every one it prints has one.
///
/// PATHWAY is 36 pt for a designator and falls back to the name (DR-026
/// §11.25.1), which it is too narrow to hold. The designator is
/// hand-entered and nothing mints one, so the notice says where a person
/// types it rather than inventing a short form. Distinct pathways, in the
/// order the sheet first prints them, up to three named.
String? undesignatedPathwayNotice(ScheduleView view, String sheetId) {
  final names = <Uuid, String>{};
  for (final row in view.rows) {
    final id = row.pathwayId;
    if (id == null || row.pathwayDesignator != null) continue;
    names.putIfAbsent(id, () => row.pathwayName ?? id.v);
  }
  if (names.isEmpty) return null;
  final n = names.length;
  final shown = names.values.take(3).join(', ');
  final more = n > 3 ? ' and ${n - 3} more' : '';
  final them = n == 1 ? 'it' : 'each one';
  return '$sheetId: $n ${n == 1 ? 'pathway has' : 'pathways have'} no '
      'designator, so PATHWAY prints the name, cut to fit: $shown$more. '
      'Give $them a designator in $kPathwayDesignatorRoute.';
}

// ── the paginated model ──────────────────────────────────────────────────

/// One laid-out thing on a schedule page.
@immutable
sealed class ScheduleSheetItem {
  const ScheduleSheetItem();

  double get height;
}

/// The sheet's title, its notes and the column heads: the top of every
/// page, the notes on the first only.
@immutable
final class ScheduleSheetHeading extends ScheduleSheetItem {
  const ScheduleSheetHeading({
    required this.title,
    required this.notes,
    this.continued = false,
  });

  final String title;
  final List<String> notes;
  final bool continued;

  String get text => continued ? '$title (cont.)' : title;

  ScheduleSheetHeading get asContinued => ScheduleSheetHeading(
    title: title,
    notes: const <String>[],
    continued: true,
  );

  @override
  double get height => _kTitle + notes.length * _kNote + _kHeads;
}

/// A Pull Sheet lifecycle section's header (DR-206 §11.205.2).
@immutable
final class ScheduleSectionBand extends ScheduleSheetItem {
  const ScheduleSectionBand(this.title, this.right, {this.continued = false});

  final String title;
  final String right;
  final bool continued;

  String get text => continued ? '$title (cont.)' : title;

  ScheduleSectionBand get asContinued =>
      ScheduleSectionBand(title, right, continued: true);

  @override
  double get height => _kSection;
}

/// A group's band (§3.6): its title and count, its footage on the right.
@immutable
final class ScheduleGroupBand extends ScheduleSheetItem {
  const ScheduleGroupBand(this.title, this.right, {this.continued = false});

  final String title;
  final String right;
  final bool continued;

  String get text => continued ? '$title (cont.)' : title;

  ScheduleGroupBand get asContinued =>
      ScheduleGroupBand(title, right, continued: true);

  @override
  double get height => _kBand;
}

/// One run: each column's wrapped lines, and the entry for the chip.
@immutable
final class ScheduleSheetRow extends ScheduleSheetItem {
  const ScheduleSheetRow(this.entry, this.cells, {this.continuation = false});

  final ScheduleEntry entry;
  final List<List<String>> cells;

  /// A further line of [entry]'s cable on the Termination Schedule (DR-236
  /// §11.235.3): its cable number and one further pair of ends, and no type
  /// chip, which the cable's first line already carries.
  final bool continuation;

  String get designator => entry.designator;

  int get lineCount => cells.fold(1, (n, c) => c.length > n ? c.length : n);

  @override
  double get height => lineCount * kScheduleSheetLine + _kRowPad;
}

/// A sentence in place of an empty table.
@immutable
final class ScheduleSheetNote extends ScheduleSheetItem {
  const ScheduleSheetNote(this.text);

  final String text;

  @override
  double get height => _kNote + _kRowPad;
}

/// One page's worth of items.
@immutable
final class ScheduleSheetPage {
  const ScheduleSheetPage(this.items);

  final List<ScheduleSheetItem> items;

  List<String> get designators => [
    for (final item in items)
      if (item is ScheduleSheetRow) item.designator,
  ];
}

/// The body box of a schedule page.
DBox scheduleSheetBodyArea(DBox drawingArea) => DBox.fromLtwh(
  drawingArea.left + _kInset,
  drawingArea.top + _kInset,
  drawingArea.width - 2 * _kInset,
  drawingArea.height - 2 * _kInset,
);

TextStyleSpec _style(int argb, [TextAnchor anchor = TextAnchor.midLeft]) =>
    TextStyleSpec(
      font: kSheetFont,
      sizePt: kScheduleSheetPt,
      argb: argb,
      anchor: anchor,
    );

/// [columns]' ruled widths scaled to [width].
List<double> scheduleSheetColumnWidths(
  List<ScheduleColumn> columns,
  double width,
) {
  final total = columns.fold<double>(0, (s, c) => s + c.widthPt);
  return [for (final c in columns) c.widthPt * width / total];
}

/// A rollup's footage as a band prints it: G4's unknowns counted.
String footageRollupText(Rollup<Len> footage, UnitSystem units) {
  final unknown = footage.unknownCount;
  if (footage.value == null) {
    return unknown == 0 ? '' : '$kUnknownCell ($unknown unknown)';
  }
  final text = footageText(footage.value, units);
  return unknown == 0 ? text : '≥ $text ($unknown unknown)';
}

String _runs(int n) => '$n ${n == 1 ? 'run' : 'runs'}';

/// The heading's notes: the lifecycle key when a suffix prints, and every
/// exclusion named in words (AC-026: they are not lost, they roll up on
/// T6.30).
List<String> scheduleSheetNotes(ScheduleView view) {
  final x = view.exclusions;
  final parts = <String>[
    if (x.jumpers > 0) '${x.jumpers} ${x.jumpers == 1 ? 'jumper' : 'jumpers'}',
    if (x.powerCords > 0)
      '${x.powerCords} power ${x.powerCords == 1 ? 'cord' : 'cords'}',
    if (x.internal > 0) '${x.internal} internal',
    if (x.notLandingInRack > 0)
      '${_runs(x.notLandingInRack)} landing in no rack',
  ];
  // EACH REASON ONLY WITH ITS OWN EXCLUSION: the first render told a
  // Termination Schedule whose only exclusions were runs landing in no rack
  // that jumpers are bought by the piece.
  const piece =
      'Jumpers and power cords are bought by the piece and roll up on the '
      'equipment list.';
  const noRack = 'A run landing in no rack is on the Pull Sheet.';
  final why = <String>[
    if (x.jumpers > 0 || x.powerCords > 0) piece,
    if (x.notLandingInRack > 0) noRack,
  ];
  final notListed = parts.isEmpty
      ? null
      : 'Not listed: ${parts.join(', ')}. ${why.join(' ')}'.trim();
  return <String>[
    if (view.lifecycleKey case final key?) key,
    ?notListed,
  ];
}

/// The tag a TYPE cell prints after its chip: docs/08 §3.2's *"domain tag
/// + family shortTag"*, `VID·HDMI`, as the legend prints it. The Schedule
/// screen's long label (`typeCell`) is for a column a person can widen;
/// 44 pt is not.
///
/// THE FIRST RENDER PRINTED `typeCell` AND READ `NET… (co…`. Falls back
/// to it only for a family the registries do not hold, counted elsewhere.
String scheduleTypeTag(ScheduleEntry entry, Registries registries) {
  final family = entry.signalFamilyId;
  if (family == null || !registries.signalFamilies.containsKey(family)) {
    return entry.typeCell;
  }
  return resolveSignalStyle(family: family, registries: registries).tag;
}

/// The cell text for [column] of [entry]. TYPE prints its tag after the
/// chip, and SIGN-OFF prints nothing: its boxes are drawn.
String _cellText(
  ScheduleEntry entry,
  ScheduleColumn column,
  UnitSystem u,
  Registries registries,
) => switch (column.id) {
  ScheduleColumnId.type => scheduleTypeTag(entry, registries),
  _ => entry.cell(column.id, units: u),
};

/// [view]'s pages, laid out in [drawingArea].
///
/// ALWAYS AT LEAST ONE PAGE: both schedules are `ON` (docs/08 §2.2).
List<ScheduleSheetPage> paginateSchedule({
  required ScheduleView view,
  required String title,
  required Registries registries,
  required DBox drawingArea,
  required TextMeasurer measurer,
  required UnitSystem units,
}) {
  final body = scheduleSheetBodyArea(drawingArea);
  final widths = scheduleSheetColumnWidths(view.columns, body.width);
  final heading = ScheduleSheetHeading(
    title: '$title (${_runs(view.rowCount)})',
    notes: scheduleSheetNotes(view),
  );

  final flat = <ScheduleSheetItem>[heading];
  if (view.rowCount == 0) {
    flat.add(
      ScheduleSheetNote(
        view.isEmptyDocument ? kNoCablesText : kAllExcludedText,
      ),
    );
  }
  final sections = {for (final s in view.sections) s.section: s};
  LifecycleSection? openSection;
  for (final group in view.groups) {
    if (group.rows.isEmpty) continue;
    final section = group.section;
    if (section != null && section != openSection) {
      openSection = section;
      final summary = sections[section];
      flat.add(
        ScheduleSectionBand(
          '${section.title} · ${_runs(summary?.rowCount ?? 0)}',
          summary == null ? '' : footageRollupText(summary.footage, units),
        ),
      );
    }
    flat.add(
      ScheduleGroupBand(
        '${group.title.toUpperCase()} · ${_runs(group.rows.length)}',
        footageRollupText(group.footage, units),
      ),
    );
    for (final entry in group.rows) {
      flat.add(
        ScheduleSheetRow(entry, [
          for (final (i, column) in view.columns.indexed)
            if (column.id == ScheduleColumnId.signOff)
              const <String>['']
            else
              () {
                final value = _cellText(entry, column, units, registries);
                final full = widths[i] - 2 * _kCellPad;
                // THE TAG SITS BESIDE THE CHIP WHEN IT FITS THERE, and on
                // the line beneath it, at the cell's full width, when it
                // does not: a tag cut to `NET…` names no family at all.
                // A leading empty line is the "beneath" form; the drawing
                // skips it and puts the chip on line one either way.
                if (column.id == ScheduleColumnId.type) {
                  final beside = full - kTypeChipWidth - 2;
                  final w = measurer
                      .measureText(value, _style(0xFF000000))
                      .advanceWidth;
                  if (w <= beside) return <String>[value];
                  return <String>[
                    '',
                    fitTextToWidth(
                      value,
                      full,
                      style: _style(0xFF000000),
                      measurer: measurer,
                    ),
                  ];
                }
                final lines = wrapMeasured(
                  value,
                  full,
                  style: _style(0xFF000000),
                  measurer: measurer,
                  maxLines: _kMaxLines,
                );
                return lines.isEmpty ? <String>[''] : lines;
              }(),
        ]),
      );
      // DR-236 §11.235.3: A LINE PER FURTHER PAIR of a cable that reaches
      // more devices, under the same cable number, on the Termination
      // Schedule only. The Pull Sheet names them on its one row instead.
      if (view.preset == SchedulePreset.terminationSchedule) {
        for (final pair in entry.furtherPairs) {
          flat.add(
            ScheduleSheetRow(entry, [
              for (final (i, column) in view.columns.indexed)
                switch (wrapMeasured(
                  entry.continuationCell(column.id, pair),
                  widths[i] - 2 * _kCellPad,
                  style: _style(0xFF000000),
                  measurer: measurer,
                  maxLines: _kMaxLines,
                )) {
                  final lines when lines.isEmpty => const <String>[''],
                  final lines => lines,
                },
            ], continuation: true),
          );
        }
      }
    }
  }

  final pages = <ScheduleSheetPage>[];
  var page = <ScheduleSheetItem>[];
  var y = 0.0;
  ScheduleSectionBand? section;
  ScheduleGroupBand? group;
  for (final (i, item) in flat.indexed) {
    // A BAND KEEPS WITH WHAT FOLLOWS IT, down to the first row: a section
    // band with its group band and that group's first row, a group band
    // with its first row.
    var need = item.height;
    if (item is ScheduleSectionBand || item is ScheduleGroupBand) {
      for (var j = i + 1; j < flat.length; j++) {
        need += flat[j].height;
        if (flat[j] is ScheduleSheetRow) break;
      }
    }
    if (y + need > body.height && page.isNotEmpty) {
      pages.add(ScheduleSheetPage(List.unmodifiable(page)));
      page = <ScheduleSheetItem>[heading.asContinued];
      y = heading.asContinued.height;
      // RE-EMIT WHAT THE NEXT ROW BELONGS TO, unless the next item is a
      // band that replaces it.
      if (item is ScheduleSheetRow) {
        for (final band in <ScheduleSheetItem?>[
          section?.asContinued,
          group?.asContinued,
        ]) {
          if (band == null) continue;
          page.add(band);
          y += band.height;
        }
      } else if (item is ScheduleGroupBand && section != null) {
        final cont = section.asContinued;
        page.add(cont);
        y += cont.height;
      }
    }
    if (item is ScheduleSectionBand) {
      section = item;
      group = null;
    }
    if (item is ScheduleGroupBand) group = item;
    page.add(item);
    y += item.height;
  }
  if (page.isNotEmpty) pages.add(ScheduleSheetPage(List.unmodifiable(page)));
  return List.unmodifiable(pages);
}

// ── drawing ──────────────────────────────────────────────────────────────

/// One composed schedule page.
@immutable
final class ScheduleSheet {
  const ScheduleSheet({required this.scene, required this.legibility});

  final DiagramScene scene;
  final LegibilityReport legibility;
}

/// Builds one page of `T6.10` or `T6.15`.
ScheduleSheet buildScheduleSheet({
  required SheetDef sheet,
  required ScheduleSheetPage page,
  required List<ScheduleColumn> columns,
  required Registries registries,
  required ProjectInfo info,
  required ProjectSettings settings,
  required List<RevisionEntry> revisions,
  required String fileName,
  required DateTime issuedAt,
  required TextMeasurer measurer,
  SheetPalette palette = const SheetPalette(),
}) {
  assert(
    sheet.role == SheetRole.pullSheet ||
        sheet.role == SheetRole.terminationSchedule,
    'buildScheduleSheet: ${sheet.role} is not a schedule role',
  );
  final layout = sheetLayoutFor(sheet, revisions);
  final body = scheduleSheetBodyArea(layout.drawingArea);
  final furniture = buildSheetFurniture(
    sheet: sheet,
    info: info,
    settings: settings,
    rack: null,
    revisions: revisions,
    scale: DrawingScale.fitted(const SceneFactor(0)),
    fileName: fileName,
    issuedAt: issuedAt,
    measurer: measurer,
    palette: palette,
  );
  final widths = scheduleSheetColumnWidths(columns, body.width);
  final xs = <double>[];
  var x = body.left;
  for (final w in widths) {
    xs.add(x);
    x += w;
  }
  final text = _style(palette.text);
  final muted = _style(palette.mutedText);
  final mutedRight = _style(palette.mutedText, TextAnchor.midRight);
  final bold = TextStyleSpec(
    font: kSheetFont,
    sizePt: 8,
    argb: palette.text,
    anchor: TextAnchor.midLeft,
  );
  final titleStyle = TextStyleSpec(
    font: kSheetFont,
    sizePt: 10,
    argb: palette.text,
    anchor: TextAnchor.midLeft,
  );
  final ops = <DiagramOp>[...furniture.ops];
  var y = body.top;

  DPt cellAt(int i, double lineY) {
    final c = columns[i];
    return switch (c.align) {
      ScheduleAlign.right => DPt(xs[i] + widths[i] - _kCellPad, lineY),
      ScheduleAlign.centre => DPt(xs[i] + widths[i] / 2, lineY),
      ScheduleAlign.left => DPt(xs[i] + _kCellPad, lineY),
    };
  }

  TextStyleSpec styleFor(int i, TextStyleSpec base) =>
      switch (columns[i].align) {
        ScheduleAlign.right => TextStyleSpec(
          font: base.font,
          sizePt: base.sizePt,
          argb: base.argb,
          anchor: TextAnchor.midRight,
        ),
        ScheduleAlign.centre => TextStyleSpec(
          font: base.font,
          sizePt: base.sizePt,
          argb: base.argb,
          anchor: TextAnchor.midCenter,
        ),
        ScheduleAlign.left => base,
      };

  for (final item in page.items) {
    switch (item) {
      case ScheduleSheetHeading():
        ops.add(
          OpText(item.text, DPt(body.left, y + _kTitle * 0.55), titleStyle),
        );
        var noteY = y + _kTitle;
        for (final note in item.notes) {
          ops.add(
            OpText(
              fitTextToWidth(
                note,
                body.width,
                style: muted,
                measurer: measurer,
              ),
              DPt(body.left + _kCellPad, noteY + _kNote / 2),
              muted,
            ),
          );
          noteY += _kNote;
        }
        final heads = TextStyleSpec(
          font: kSheetFont,
          sizePt: kScheduleHeadPt,
          argb: palette.mutedText,
          anchor: TextAnchor.midLeft,
        );
        for (final (i, c) in columns.indexed) {
          final lines = wrapMeasured(
            c.header,
            widths[i] - 2 * _kCellPad,
            style: heads,
            measurer: measurer,
            maxLines: 2,
          );
          // A ONE-LINE HEAD SITS ON THE LOWER LINE, so every head's last
          // line is against the rule and the columns read as one row.
          final first = noteY + _kHeads - 4 - _kHeadLine * lines.length;
          for (final (j, line) in lines.indexed) {
            ops.add(
              OpText(
                line,
                cellAt(i, first + _kHeadLine * (j + 0.5)),
                styleFor(i, heads),
              ),
            );
          }
        }
        // §3.3's rule weights: 0.8 pt below the header.
        ops.add(
          OpLine(
            DPt(body.left, y + item.height),
            DPt(body.right, y + item.height),
            Stroke(argb: palette.text, widthPt: 0.8),
          ),
        );
      case ScheduleSectionBand():
        ops
          ..add(
            OpText(
              item.text,
              DPt(body.left + _kCellPad, y + _kSection / 2),
              bold,
            ),
          )
          ..add(
            OpText(
              item.right,
              DPt(body.right - _kCellPad, y + _kSection / 2),
              mutedRight,
            ),
          );
      case ScheduleGroupBand():
        ops
          ..add(
            OpRect(
              DBox.fromLtwh(body.left, y + 1, body.width, _kBand - 2),
              fill: const Fill(0xFFE0E0E0),
            ),
          )
          ..add(
            OpText(
              fitTextToWidth(
                item.text,
                body.width * 0.7,
                style: muted,
                measurer: measurer,
              ),
              DPt(body.left + _kCellPad, y + _kBand / 2),
              text,
            ),
          )
          ..add(
            OpText(
              item.right,
              DPt(body.right - _kCellPad, y + _kBand / 2),
              _style(palette.text, TextAnchor.midRight),
            ),
          );
      case ScheduleSheetRow():
        for (final (i, lines) in item.cells.indexed) {
          final id = columns[i].id;
          final firstY = y + _kRowPad / 2 + kScheduleSheetLine * 0.5;
          if (id == ScheduleColumnId.signOff) {
            ops.addAll(_signOffOps(xs[i], widths[i], firstY, palette, muted));
            continue;
          }
          var offset = 0.0;
          final isType = id == ScheduleColumnId.type && !item.continuation;
          if (isType) {
            final family = item.entry.signalFamilyId;
            if (family != null &&
                registries.signalFamilies.containsKey(family)) {
              ops.addAll(
                typeChipOps(
                  resolveSignalStyle(
                    family: family,
                    registries: registries,
                    colorOverrides: settings.familyColorOverrides,
                  ),
                  xs[i] + _kCellPad,
                  firstY,
                ),
              );
              offset = kTypeChipWidth + 2;
            }
          }
          for (final (j, line) in lines.indexed) {
            if (line.isEmpty) continue;
            final at = cellAt(i, firstY + kScheduleSheetLine * j);
            // Beside the chip on line one; beneath it, from the cell's
            // edge, on line two.
            final dx = isType && j > 0 ? 0.0 : offset;
            ops.add(OpText(line, DPt(at.x + dx, at.y), styleFor(i, text)));
          }
        }
        ops.add(
          OpLine(
            DPt(body.left, y + item.height),
            DPt(body.right, y + item.height),
            Stroke(argb: palette.rule, widthPt: 0.35),
          ),
        );
      case ScheduleSheetNote():
        ops.add(
          OpText(
            item.text,
            DPt(body.left + _kCellPad, y + item.height / 2),
            text,
          ),
        );
    }
    y += item.height;
  }

  final minText = furniture.minTextSizePt < kScheduleSheetPt
      ? furniture.minTextSizePt
      : kScheduleSheetPt;
  return ScheduleSheet(
    scene: DiagramScene(
      ops: ops,
      bounds: layout.geometry.pageBox,
      hits: const <HitRegion>[],
      minTextSizePt: minText,
      fragments: const <String, IntRange>{},
    ),
    legibility: checkLegibility(
      sceneMinTextSizePt: minText,
      scale: const SceneFactor(1),
    ),
  );
}

/// §3.2 column 10: `☐ P · ☐ T · ☐ T · INIT ___`, drawn, since a box glyph
/// is a codepoint the font may not have and a drawn box always prints.
List<DiagramOp> _signOffOps(
  double left,
  double width,
  double y,
  SheetPalette palette,
  TextStyleSpec muted,
) {
  const box = 5.0;
  final ops = <DiagramOp>[];
  final step = width / 4;
  for (final (i, letter) in const ['P', 'T', 'T'].indexed) {
    final x = left + step * i + 2;
    ops
      ..add(
        OpRect(
          DBox.fromLtwh(x, y - box / 2, box, box),
          stroke: Stroke(argb: palette.text, widthPt: 0.5),
        ),
      )
      ..add(OpText(letter, DPt(x + box + 1, y), muted));
  }
  final initX = left + step * 3 + 1;
  ops.add(
    OpLine(
      DPt(initX, y + box / 2),
      DPt(left + width - 2, y + box / 2),
      Stroke(argb: palette.text, widthPt: 0.5),
    ),
  );
  return ops;
}
