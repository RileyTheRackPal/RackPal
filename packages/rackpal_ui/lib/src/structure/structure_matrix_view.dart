// THE MATRIX TAB. Board M3-C/3 (#149), docs/07 §4.2, AC-048.
//
// ═════════════════════════════════════════════════════════════════════
// A TAB ON THE EDITOR, NOT A SECOND EDITOR
// ═════════════════════════════════════════════════════════════════════
// #149's instruction in full: "One editor, two views of the same rows. A
// matrix that is its own screen is a second place the repeat loop has to
// be re-established, and M3-C/1 exists because that loop is the whole
// exit criterion."
//
// So this widget is a BODY and not a screen. The header, the location
// tree, the quick-add bar and the status bar all belong to
// `StructureEditorScreen` and are the same objects on both tabs — which
// is why there is no `+ Room` button here even though §4.2's wireframe
// draws one. The loop directly above this grid already creates a room
// on `Enter` and then puts drops in it, and a third path to creating a
// room would be a third place that rule lives (CR-112 puts the second
// in `Project ▸ Locations…`).
//
// ═════════════════════════════════════════════════════════════════════
// THE SPINNER IS A NUMBER BOX, AND THAT IS #148'S ARGUMENT AGAIN
// ═════════════════════════════════════════════════════════════════════
// §4.2 draws "integer spinners at the intersections". Six rooms by nine
// media is 54 of them and 108 arrow buttons, each costing a click where
// a keystroke does — and a pair of arrows is not in the focus tree in a
// way `Tab` can walk across a row. The table's cells are always real
// inputs for exactly this reason, so tab order is the widget order and
// no key binding is needed for it; the same holds here, and the same
// consequence follows: THIS FILE ADDS NO `kKeymap` ROW.
//
// A cell is therefore a TARGET rather than a step. `planMatrixCell`'s
// header says why that matters: a `+1` computed from what the widget
// last drew is `+1` against a stale number.
import 'package:flutter/material.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/src/theme/console_theme.dart';

/// One cell, as an edit request: which room, which cable, how many.
@immutable
final class StructureMatrixEdit {
  const StructureMatrixEdit({
    required this.locationId,
    required this.media,
    required this.targetCount,
    this.structureBodyId,
  });

  final Uuid locationId;
  final MediaTypeId media;

  /// Which Structure body the drops belong to (M3-E/3, #158).
  ///
  /// ON THE EDIT AND NOT ON THE ACTION, because the app builds the action
  /// once when the editor opens and the picker changes afterwards. A body
  /// captured at construction is the selection that existed before
  /// anybody made one.
  final Uuid? structureBodyId;

  /// What the cell should say when this is done — NOT how much to add.
  /// See the file header.
  final int targetCount;
}

/// docs/07 §4.2's grid: rooms down, media across.
class StructureMatrixView extends StatelessWidget {
  const StructureMatrixView({
    required this.doc,
    required this.columns,
    required this.onColumn,
    required this.onSetCount,
    this.structureBodyId,
    super.key,
  });

  final RackDocument doc;

  /// The media columns the user has asked to see. Columns that already
  /// hold drops are drawn whether or not they are in here; see
  /// `structureMatrixColumns`.
  final Set<MediaTypeId> columns;

  /// Add or remove an asked-for column.
  final ValueChanged<MediaTypeId> onColumn;

  /// Applies one cell as ONE undo step, and returns a refusal sentence
  /// or null. The same shape `StructureEditorActions.onEdit` has, and
  /// for the same reason: the rules live behind it, not in here.
  final String? Function(StructureMatrixEdit edit) onSetCount;

  final Uuid? structureBodyId;

  @override
  Widget build(BuildContext context) {
    final matrix = buildStructureMatrix(
      doc,
      structureBodyId: structureBodyId,
      alsoColumns: columns,
    );

    // NO ROOMS IS THE ONLY EMPTY STATE. No COLUMNS is not one: the grid
    // opens on §4.2's own eight and a project that carries none of them
    // still has `+ Media column` under a room list a person can read.
    if (matrix.rows.isEmpty) return const _NoRooms();

    final width =
        _roomWidth +
        matrix.columns.length * _cellWidth +
        _sumWidth +
        _outletWidth;

    return Scrollbar(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _HeaderRow(doc: doc, matrix: matrix, onRemove: onColumn),
              const Divider(height: 1, thickness: 1),
              Expanded(
                child: ListView.builder(
                  itemCount: matrix.rows.length,
                  itemBuilder: (context, index) => _MatrixRow(
                    // KEYED ON THE ROOM, so a cell's controller follows
                    // the room rather than the row position: adding a
                    // room reshuffles the list and an unkeyed row would
                    // hand row 3's controller to whatever room is third
                    // afterwards.
                    key: ValueKey(
                      matrix.rows[index].locationId ?? const Uuid('no-room'),
                    ),
                    row: matrix.rows[index],
                    columns: matrix.columns,
                    onSetCount: onSetCount,
                    structureBodyId: structureBodyId,
                  ),
                ),
              ),
              const Divider(height: 1, thickness: 1),
              _TotalRow(matrix: matrix),
              _AddColumnBar(doc: doc, drawn: matrix.columns, onAdd: onColumn),
            ],
          ),
        ),
      ),
    );
  }
}

const double _roomWidth = 180;
const double _cellWidth = 56;
const double _sumWidth = 48;
const double _outletWidth = 62;

/// What the `+ Media column` button says.
const String kAddMediaColumnLabel = 'Media column';

/// §4.2's summation header.
///
/// ═════════════════════════════════════════════════════════════════════
/// U+2211, THE OPERATOR, NOT U+03A3, THE GREEK LETTER
/// ═════════════════════════════════════════════════════════════════════
/// This was `Σ` (U+03A3 GREEK CAPITAL SIGMA) and should never have been:
/// Unicode separates the letter from the N-ARY SUMMATION operator on
/// purpose, and a column that adds a row up wants the operator. The two
/// look alike in most faces, which is why the substitution survives.
///
/// It was FOUND by the glyph-coverage gate rather than by reading. Jost
/// carries U+2211 in both weights and does not carry U+03A3, so the
/// header was the one character in the product falling back to a system
/// font. The gate reported a missing glyph; the missing glyph turned out
/// to be the wrong character.
///
/// THE ALTERNATIVES ARE BOTH WORSE. Drawing a Greek capital into someone
/// else's face is the one addition this project could not check by
/// measurement, because a letterform has a design where a triangle has
/// only a construction. Changing the header to a Latin word would have
/// been on-screen copy, which is not a build step's call. Using the right
/// character is neither.
const String kMatrixSumHeader = '∑';

/// §4.2's `Outlets` header, in the table's own casing.
const String kMatrixOutletsHeader = 'OUTLETS';

/// §4.2's `TOTAL` row label.
const String kMatrixTotalLabel = 'TOTAL';

/// What the grid says when the project has no rooms.
const String kNoRoomsHeadline = 'This project has no rooms yet.';

/// And where they come from. NAMES THE TWO SURFACES THAT CAN MAKE ONE,
/// both of which are reachable from here — the field directly above,
/// and the panel CR-112 puts the vocabulary in.
const String kNoRoomsDetail =
    'Type a room and what it needs into the field above, then press Enter: '
    '"Living Room: 4x Cat6". The room is created with the drops. Rooms are '
    'also named on the Site tab';

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({
    required this.doc,
    required this.matrix,
    required this.onRemove,
  });

  final RackDocument doc;
  final StructureMatrix matrix;
  final ValueChanged<MediaTypeId> onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelSmall?.copyWith(
      fontWeight: kConsoleEmphasis,
      letterSpacing: 0.4,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          SizedBox(
            width: _roomWidth,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text('ROOM', style: style),
            ),
          ),
          for (var c = 0; c < matrix.columns.length; c++)
            SizedBox(
              width: _cellWidth,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Flexible(
                      child: Text(
                        structureMatrixColumnHeader(doc, matrix.columns[c]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: style,
                      ),
                    ),
                    // ONLY ON A COLUMN THAT HOLDS NOTHING. Taking away a
                    // column with drops in it would hide cable somebody
                    // paid for, so the affordance is absent there rather
                    // than present and refusing.
                    if (matrix.columnTotals[c] == 0)
                      InkWell(
                        onTap: () => onRemove(matrix.columns[c]),
                        child: Icon(
                          Icons.close,
                          size: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          SizedBox(
            width: _sumWidth,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                kMatrixSumHeader,
                textAlign: TextAlign.right,
                style: style,
              ),
            ),
          ),
          SizedBox(
            width: _outletWidth,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                kMatrixOutletsHeader,
                textAlign: TextAlign.right,
                style: style,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MatrixRow extends StatelessWidget {
  const _MatrixRow({
    required this.row,
    required this.columns,
    required this.onSetCount,
    super.key,
    this.structureBodyId,
  });

  final StructureMatrixRow row;
  final List<MediaTypeId> columns;
  final String? Function(StructureMatrixEdit edit) onSetCount;

  /// Passed down to each cell so its edits name a body (#158).
  final Uuid? structureBodyId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // The no-room row is toned apart from a real room's, the same
    // distinction the table's band draws: it is not a place, and a
    // reader skimming for rooms must not mistake it for one.
    final background = row.takesDrops ? null : scheme.errorContainer;
    final foreground = row.takesDrops
        ? scheme.onSurface
        : scheme.onErrorContainer;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        border: Border(
          bottom: BorderSide(color: scheme.outlineVariant, width: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            SizedBox(
              width: _roomWidth,
              child: Padding(
                padding: EdgeInsets.fromLTRB(8.0 + row.depth * 14, 0, 8, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        row.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: foreground,
                        ),
                      ),
                    ),
                    if (row.code.isNotEmpty)
                      Text(
                        row.code,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: row.takesDrops
                              ? scheme.onSurfaceVariant
                              : foreground,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            for (var c = 0; c < columns.length; c++)
              SizedBox(
                width: _cellWidth,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  // THE TRAILING ROW IS READ-ONLY, and that is not a
                  // missing feature: its drops name no room, so there is
                  // nowhere to put a new one and nothing for a target
                  // count to mean.
                  child: switch (row.locationId) {
                    final id? => _CountCell(
                      locationId: id,
                      media: columns[c],
                      count: row.counts[c],
                      onSetCount: onSetCount,
                      structureBodyId: structureBodyId,
                    ),
                    null => _Number(row.counts[c], color: foreground),
                  },
                ),
              ),
            SizedBox(
              width: _sumWidth,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: _Number(row.dropCount, color: foreground, bold: true),
              ),
            ),
            SizedBox(
              width: _outletWidth,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: _Number(row.outletCount, color: foreground),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({required this.matrix});

  final StructureMatrix matrix;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ColoredBox(
      color: theme.colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            SizedBox(
              width: _roomWidth,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  kMatrixTotalLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: kConsoleEmphasis,
                  ),
                ),
              ),
            ),
            for (final total in matrix.columnTotals)
              SizedBox(
                width: _cellWidth,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _Number(total, bold: true),
                ),
              ),
            SizedBox(
              width: _sumWidth,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                // THE MATRIX'S OWN Σ, which is `StructureTable.dropCount`
                // by construction. `buildStructureMatrix`'s header is the
                // argument and a core test is the gate.
                child: _Number(matrix.dropCount, bold: true),
              ),
            ),
            const SizedBox(width: _outletWidth),
          ],
        ),
      ),
    );
  }
}

/// A right-aligned integer with tabular figures, so a column of counts
/// lines up under its header.
class _Number extends StatelessWidget {
  const _Number(this.value, {this.color, this.bold = false});

  final int value;
  final Color? color;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      '$value',
      textAlign: TextAlign.right,
      style: theme.textTheme.bodySmall?.copyWith(
        color: color,
        fontWeight: bold ? kConsoleEmphasis : FontWeight.w400,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

/// One typed cell.
///
/// IT COMMITS ON `Enter` AND ON LOSING FOCUS, which are the two moments
/// the table's cells commit on. Losing focus is the one that matters:
/// a person filling a room's row types, tabs, types, tabs, and never
/// presses `Enter` at all.
///
/// A REFUSED EDIT PUTS THE STORED COUNT BACK, which is CR-017's
/// spring-back. The sentence goes to the status bar, where it stays
/// until the next edit rather than fading.
class _CountCell extends StatefulWidget {
  const _CountCell({
    required this.locationId,
    required this.media,
    required this.count,
    required this.onSetCount,
    this.structureBodyId,
  });

  final Uuid locationId;
  final MediaTypeId media;

  /// Rides onto every `StructureMatrixEdit` this cell emits (#158).
  final Uuid? structureBodyId;

  final int count;
  final String? Function(StructureMatrixEdit edit) onSetCount;

  @override
  State<_CountCell> createState() => _CountCellState();
}

class _CountCellState extends State<_CountCell> {
  late final TextEditingController _text = TextEditingController(
    text: '${widget.count}',
  );
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(_CountCell old) {
    super.didUpdateWidget(old);
    // THE DOCUMENT WINS, EXCEPT WHILE SOMEBODY IS TYPING IN THIS BOX.
    // An undo, a typed line or another cell's gesture changes the count
    // under a cell that is not focused and the cell must follow;
    // overwriting a FOCUSED one would delete what a person is halfway
    // through typing.
    if (widget.count != old.count && !_focus.hasFocus) {
      _text.text = '${widget.count}';
    }
  }

  @override
  void dispose() {
    _focus
      ..removeListener(_onFocusChange)
      ..dispose();
    _text.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focus.hasFocus) _commit();
  }

  void _commit() {
    final typed = _text.text.trim();
    if (typed == '${widget.count}') return;
    // PARSED HERE AND NOWHERE ELSE IN THIS FILE, because it is the one
    // question with no document behind it: a cell holds a whole number
    // of cables and `two` is not one. Everything the answer then MEANS
    // is `planMatrixCell`'s.
    final target = int.tryParse(typed);
    if (target == null || target < 0) {
      widget.onSetCount(
        StructureMatrixEdit(
          locationId: widget.locationId,
          media: widget.media,
          structureBodyId: widget.structureBodyId,
          // -1 CAN ONLY REFUSE, and the refusal it produces is the one
          // sentence a person needs. Refusing here instead would put a
          // second copy of that sentence in the widget layer.
          targetCount: -1,
        ),
      );
      _text.text = '${widget.count}';
      return;
    }
    final refusal = widget.onSetCount(
      StructureMatrixEdit(
        locationId: widget.locationId,
        media: widget.media,
        structureBodyId: widget.structureBodyId,
        targetCount: target,
      ),
    );
    if (refusal != null) _text.text = '${widget.count}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextField(
      controller: _text,
      focusNode: _focus,
      textAlign: TextAlign.right,
      style: theme.textTheme.bodySmall?.copyWith(
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      decoration: const InputDecoration(
        isDense: true,
        border: InputBorder.none,
        contentPadding: EdgeInsets.symmetric(vertical: 4),
      ),
      onSubmitted: (_) => _commit(),
    );
  }
}

/// §4.2's `[ + Media column ]`.
///
/// IT OFFERS ONLY WHAT IS NOT ALREADY DRAWN, so every entry does
/// something. §4.2 also draws "an inline create new type row"; creating
/// a media type is the media-type editor, board #247 (M4-P2), and a row
/// that opened nothing would be a promise about an unbuilt surface.
class _AddColumnBar extends StatelessWidget {
  const _AddColumnBar({
    required this.doc,
    required this.drawn,
    required this.onAdd,
  });

  final RackDocument doc;
  final List<MediaTypeId> drawn;
  final ValueChanged<MediaTypeId> onAdd;

  @override
  Widget build(BuildContext context) {
    final offered = [
      for (final entry in doc.registries.mediaTypes.entries)
        if (!drawn.contains(entry.key)) entry.value,
    ];
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
        child: MenuAnchor(
          menuChildren: [
            // THIRTY-EIGHT SEEDED TYPES DO NOT FIT ON A SCREEN, so the
            // menu scrolls inside a fixed box rather than running off
            // the bottom of the window.
            SizedBox(
              width: 260,
              height: 320,
              child: ListView.builder(
                itemCount: offered.length,
                itemBuilder: (context, index) => MenuItemButton(
                  onPressed: () => onAdd(offered[index].id),
                  child: Text(
                    '${offered[index].shortTag ?? offered[index].displayName}'
                    ' · ${offered[index].displayName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          ],
          builder: (context, controller, child) => TextButton.icon(
            icon: const Icon(Icons.add, size: 18),
            label: const Text(kAddMediaColumnLabel),
            onPressed: offered.isEmpty
                ? null
                : () => controller.isOpen
                      ? controller.close()
                      : controller.open(),
          ),
        ),
      ),
    );
  }
}

class _NoRooms extends StatelessWidget {
  const _NoRooms();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(kNoRoomsHeadline, style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              Text(
                kNoRoomsDetail,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
