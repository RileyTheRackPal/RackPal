// THE `[ Pathways ]` TAB. Board M3-E/1 (#156), docs/07 §4, CR-016,
// DR-031, DR-032.
//
// ═════════════════════════════════════════════════════════════════════
// IT RENDERS A DERIVATION. IT DOES NOT CONTAIN ONE.
// ═════════════════════════════════════════════════════════════════════
// Every row, every cell string and both counts come from
// `rackpal_core`'s `derived/pathway_table.dart`. This file owns exactly
// one thing and it is VIEW state: which row the caret is in.
// `structure_editor_screen.dart` states the rule for the table tab and it
// is the same rule here.
//
// ═════════════════════════════════════════════════════════════════════
// THIS IS NOT WHERE A PATHWAY IS BORN, AND THAT IS THE WHOLE SHAPE OF IT
// ═════════════════════════════════════════════════════════════════════
// The user, on 2026-08-09: *"Pathway will likely be set in the plan view,
// once a pathway is actually determined and set on site."* That is DR-020
// §11.19.1 applied to the entity — the route is discovered, not designed
// — and it caps how far this tab should go. So it is a LIST AND AN EDITOR
// FOR WHAT EXISTS, not a routing surface: there is no map, no assignment
// of runs to a conduit, and no `[Group into pathway]`.
//
// `+ Add pathway` IS STILL HERE, and is not a contradiction of that. Two
// gestures already create pathways without it (DR-032's conduit drop
// line, and the same medium in the matrix), so the entity is not
// hypothetical; what this button covers is the trunk somebody walked and
// wants to record before any cable goes through it. It is the same
// affordance the Site tab gives a room the drop line would
// otherwise have to invent.
//
// ═════════════════════════════════════════════════════════════════════
// THE TWO COLUMNS M5 IS WAITING ON ARE THE REASON THIS TAB EXISTS
// ═════════════════════════════════════════════════════════════════════
// `KIND` and `LINE VOLTAGE` are read by `CODE-001` and `CODE-002`
// (NEC 800.154), and both sat at their constructor defaults on an entity
// no surface could reach. **No rule is implemented here**: canon §5 says
// a rule not listed does not exist, and a tier-2 rule built as a tier-1
// refusal would make the product unable to draw a mistake (G2, CR-017).
// A plenum pathway carrying line voltage with a CM jacket is a document
// this tab will render without a word, because M5 is where that fires and
// M3 is only where the fact is entered.
import 'package:flutter/material.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/src/theme/console_theme.dart';

/// What the tab can ask the application to do.
///
/// CALLBACKS AND NOT A CONTROLLER, the shape `LocationsPanel`,
/// `DropEntryPanel` and `StructureEditorActions` already use, so
/// `rackpal_ui` stays free of the session layer.
@immutable
final class PathwaysActions {
  const PathwaysActions({
    required this.onEdit,
    required this.onAdd,
    required this.onRemove,
  });

  /// Applies cell edits as ONE undo step, and returns a refusal sentence
  /// or null.
  ///
  /// A LIST, on `StructureEditorActions.onEdit`'s reasoning, even though
  /// nothing here sends more than one today: the signature is what a
  /// later fill-down would need, and a callback that took a single edit
  /// would have to change shape rather than gain a caller.
  final String? Function(List<PathwayCellEdit> edits) onEdit;

  /// Creates one pathway and returns a refusal sentence or null.
  final String? Function() onAdd;

  /// Deletes one pathway. NOT A CASCADE: nothing lives inside a pathway,
  /// so the runs through it survive having lost their recorded route and
  /// `RemovePathwayCommand` clears each `pathwayId` rather than leaving
  /// it dangling.
  final String? Function(Uuid id) onRemove;
}

/// One cell, as an edit request: which pathway, which column, what was
/// typed.
///
/// THE VALUE IS TEXT, always, even for `KIND` whose model type is an enum
/// and `LINE VOLTAGE` whose model type is a bool. `StructureCellEdit`
/// takes the same reading and for the same reason: the parsing belongs
/// beside the command that refuses, so this type stays what the surface
/// actually has, which is what a person put in a box.
@immutable
final class PathwayCellEdit {
  const PathwayCellEdit({
    required this.pathwayId,
    required this.column,
    required this.value,
  });

  final Uuid pathwayId;
  final PathwayColumnId column;
  final String value;
}

/// Which columns a person can type into.
///
/// `RUNS` IS THE ONLY ONE THAT IS NOT. It is derived from `doc.links` and
/// there is no field behind it; typing `6` into it would have to invent
/// six cables, each needing a room, a medium and a label nobody chose.
/// That is `_paste`'s rule on the drop table, applied where the column
/// itself is the impossible one.
bool pathwayColumnIsEditable(PathwayColumnId id) => id != PathwayColumnId.runs;

/// docs/07 §4's `[ Pathways ]` tab.
class PathwaysView extends StatelessWidget {
  const PathwaysView({
    required this.doc,
    required this.actions,
    super.key,
  });

  final RackDocument doc;
  final PathwaysActions actions;

  @override
  Widget build(BuildContext context) {
    final table = buildPathwayTable(doc);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Toolbar(table: table, onAdd: actions.onAdd),
        const Divider(height: 1),
        Expanded(
          child: table.isEmpty
              ? const _EmptyState()
              : _PathwayTable(doc: doc, table: table, actions: actions),
        ),
      ],
    );
  }
}

/// The counts, and the one button.
///
/// BOTH G4 COUNTS ARE SHOWN AND NEITHER IS HIDDEN WHEN IT IS ZERO for
/// [PathwayTable.unknownLengthCount]'s half: "0 lengths unknown" is a
/// statement that the takeoff is complete, and a line that disappears
/// when the news is good makes its absence unreadable. The unrouted count
/// is shown only when there ARE unrouted runs, because it is a note about
/// the rest of the document rather than about this list.
class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.table, required this.onAdd});

  final PathwayTable table;
  final String? Function() onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _summary(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall,
            ),
          ),
          // THE REFUSAL IS DROPPED HERE AND NOT SWALLOWED. `onAdd`
          // returns a sentence or null on the shape every other callback
          // in this file uses; the editor's own handler is what puts it
          // in the status bar, so this only has to hand the gesture over.
          TextButton(onPressed: onAdd, child: const Text(kAddPathwayLabel)),
        ],
      ),
    );
  }

  String _summary() => <String>[
    '${table.rows.length} pathways',
    '${table.unknownLengthCount} lengths unknown',
    if (table.unroutedRunCount > 0)
      '${table.unroutedRunCount} runs through no pathway',
  ].join(' · ');
}

/// What a document with no pathways says.
///
/// IT NAMES THE TWO GESTURES THAT MAKE ONE, which is
/// `unbuilt_copy_accuracy_test.dart`'s rule: copy on a surface must
/// describe what the product can actually do. Both named here are built —
/// DR-032's drop line at `b093062`, and this tab's own button — so
/// neither sentence is a promise about an unbuilt feature.
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          kNoPathwaysYet,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _PathwayTable extends StatelessWidget {
  const _PathwayTable({
    required this.doc,
    required this.table,
    required this.actions,
  });

  final RackDocument doc;
  final PathwayTable table;
  final PathwaysActions actions;

  @override
  Widget build(BuildContext context) {
    final totalPt =
        PathwayColumnId.values.fold<double>(
          0,
          (n, c) => n + pathwayColumnWidth(c),
        ) +
        _kRemoveColumnWidth;
    return LayoutBuilder(
      builder: (context, constraints) {
        // NEVER SQUEEZED BELOW THE AUTHORED WIDTHS — a narrow window
        // scrolls sideways instead, which is `_DropTable`'s rule and
        // `_ScheduleTable`'s. `KIND` is sized for `CRAWLSPACE` and a
        // column that shrank to fit would render DR-031's two new values
        // as ellipses on exactly the windows where somebody is working
        // in a crawlspace.
        final scale = constraints.maxWidth / totalPt;
        final width = scale > 1 ? constraints.maxWidth : totalPt;
        final effective = width / totalPt;
        return Scrollbar(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: width,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _HeaderRow(scale: effective),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.builder(
                      itemCount: table.rows.length,
                      itemBuilder: (context, index) {
                        final row = table.rows[index];
                        return _PathwayRow(
                          key: ValueKey(row.id.v),
                          doc: doc,
                          row: row,
                          scale: effective,
                          actions: actions,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          for (final id in PathwayColumnId.values)
            SizedBox(
              width: pathwayColumnWidth(id) * scale,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  pathwayColumnHeader(id),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: kConsoleEmphasis,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          // The delete column's header is blank rather than `DELETE`: the
          // affordance is one icon per row and a heading over it would be
          // a column name for something that is not a column.
          SizedBox(width: _kRemoveColumnWidth * scale),
        ],
      ),
    );
  }
}

const double _kRemoveColumnWidth = 40;

class _PathwayRow extends StatelessWidget {
  const _PathwayRow({
    required this.doc,
    required this.row,
    required this.scale,
    required this.actions,
    super.key,
  });

  final RackDocument doc;
  final PathwayTableRow row;
  final double scale;
  final PathwaysActions actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final units = doc.settings.displayUnits;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant,
            width: 0.5,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            for (final id in PathwayColumnId.values)
              SizedBox(
                width: pathwayColumnWidth(id) * scale,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: _cell(theme, id, units),
                ),
              ),
            SizedBox(
              width: _kRemoveColumnWidth * scale,
              child: IconButton(
                icon: const Icon(Icons.delete_outline, size: 18),
                tooltip: _removeTooltip(),
                onPressed: () => actions.onRemove(row.id),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// THE TOOLTIP STATES THE CONSEQUENCE AND THE COUNT, because the delete
  /// is not a cascade and the difference is invisible from the icon: the
  /// runs survive and lose their recorded route. A person deleting a
  /// conduit with six cables in it should read the six before clicking,
  /// not discover it in the undo label.
  String _removeTooltip() => row.runCount == 0
      ? kRemovePathwayTooltip
      : '$kRemovePathwayTooltip ${row.runCount} '
            '${row.runCount == 1 ? 'run' : 'runs'} through it will keep '
            'their cable and lose their recorded route.';

  Widget _cell(ThemeData theme, PathwayColumnId id, UnitSystem units) {
    final text = pathwayCell(row, id, units: units);
    if (!pathwayColumnIsEditable(id)) {
      return Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall,
      );
    }

    // THE CLOSED-SET COLUMNS GET A DROPDOWN AND THE REST GET A BOX, which
    // follows the MODEL TYPE rather than a preference — `_DataRow`'s rule
    // on the drop table. `KIND` is an enum, `LINE VOLTAGE` is a bool and
    // `MEDIA` is a registry lookup restricted to `isPathwayOnly` types,
    // so none of the three has anything to parse or to typo.
    final options = switch (id) {
      PathwayColumnId.kind => PathwayKind.values.map(pathwayKindLabel).toList(),
      PathwayColumnId.lineVoltage => const <String>[
        kLineVoltageNoCell,
        kLineVoltageYesCell,
      ],
      PathwayColumnId.media => _mediaOptions(),
      _ => null,
    };
    if (options != null) {
      return _ChoiceCell(
        pathwayId: row.id,
        column: id,
        value: text,
        // A DANGLING MEDIA ID IS ADDED TO ITS OWN OPTION LIST rather than
        // silently reset to unknown. `DropdownButton` throws when its
        // value is absent from its items, so the alternative is not
        // "show nothing", it is a crash on a document that lost a
        // registry entry. Showing what the document holds and letting a
        // person choose over it is `jacketColorCell`'s holding made
        // editable.
        options: options.contains(text) ? options : [...options, text],
        onEdit: actions.onEdit,
      );
    }
    return _TextCell(
      pathwayId: row.id,
      column: id,
      // THE DASH IS NOT PUT IN THE BOX, on `_DataRow`'s rule: `—` is what
      // an unknown PRINTS, and typing after it would save `—40`.
      value: text == kUnknownCell ? '' : text,
      // DESIGNATOR IS THE PRIMARY COLUMN, not the name (M3-E/2, #157).
      // It is what an installer matches against a label in a wall, and
      // it is where every other identifier column in this product sits.
      bold: id == PathwayColumnId.designator,
      onEdit: actions.onEdit,
    );
  }

  /// `MEDIA` offers the unknown dash and every `isPathwayOnly` type this
  /// document carries.
  ///
  /// FILTERED TO `isPathwayOnly` (CR-109), which is the point of the flag:
  /// offering `Cat6` here would let somebody record that a conduit is a
  /// cable. The list is the DOCUMENT'S registry rather than the seed
  /// catalog's, so a shop's own conduit type (RJ-009) appears.
  ///
  /// UNKNOWN IS AN OPTION and stays one: nobody has to say which conduit a
  /// pathway is, and a control that could not go back to unknown would
  /// make that state unreachable after the first guess (G4).
  List<String> _mediaOptions() => <String>[
    kUnknownCell,
    for (final def in doc.registries.mediaTypes.values)
      if (def.isPathwayOnly) def.displayName,
  ];
}

/// One typed cell.
///
/// IT COMMITS ON `Enter` AND ON LOSING FOCUS, and a refused edit puts the
/// stored value back. `_TextCell` on the drop table states the reasoning
/// for both; this is the same widget over a different edit type, and the
/// two are kept apart rather than made generic because the id they carry
/// is a different entity's.
class _TextCell extends StatefulWidget {
  const _TextCell({
    required this.pathwayId,
    required this.column,
    required this.value,
    required this.bold,
    required this.onEdit,
  });

  final Uuid pathwayId;
  final PathwayColumnId column;
  final String value;
  final bool bold;
  final String? Function(List<PathwayCellEdit> edits) onEdit;

  @override
  State<_TextCell> createState() => _TextCellState();
}

class _TextCellState extends State<_TextCell> {
  late final TextEditingController _text = TextEditingController(
    text: widget.value,
  );
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(_TextCell old) {
    super.didUpdateWidget(old);
    // THE DOCUMENT WINS, EXCEPT WHILE SOMEBODY IS TYPING IN THIS BOX. An
    // undo changes the stored value under an unfocused cell and it must
    // follow; overwriting a FOCUSED one would delete what the person is
    // halfway through typing.
    if (widget.value != old.value && !_focus.hasFocus) {
      _text.text = widget.value;
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
    if (_text.text == widget.value) return;
    final refusal = widget.onEdit([
      PathwayCellEdit(
        pathwayId: widget.pathwayId,
        column: widget.column,
        value: _text.text,
      ),
    ]);
    if (refusal != null) _text.text = widget.value;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextField(
      controller: _text,
      focusNode: _focus,
      style: theme.textTheme.bodySmall?.copyWith(
        fontWeight: widget.bold ? kConsoleEmphasis : FontWeight.w400,
      ),
      decoration: InputDecoration(
        isDense: true,
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(vertical: 4),
        hintText: kUnknownCell,
        hintStyle: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      onSubmitted: (_) => _commit(),
    );
  }
}

/// A cell whose column has a closed set of answers.
///
/// THE OPTIONS AND THE VALUE ARE BOTH LABELS, not enum values, for the
/// reason [PathwayCellEdit.value] is text: the label is what crosses the
/// boundary, so core's own speller (`pathwayKindLabel`) stays the only
/// one. `_ChoiceCell` on the drop table takes the same reading.
class _ChoiceCell extends StatelessWidget {
  const _ChoiceCell({
    required this.pathwayId,
    required this.column,
    required this.value,
    required this.options,
    required this.onEdit,
  });

  final Uuid pathwayId;
  final PathwayColumnId column;
  final String value;
  final List<String> options;
  final String? Function(List<PathwayCellEdit> edits) onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DropdownButton<String>(
      value: value,
      isDense: true,
      isExpanded: true,
      underline: const SizedBox.shrink(),
      style: theme.textTheme.bodySmall,
      items: [
        for (final label in options)
          DropdownMenuItem<String>(value: label, child: Text(label)),
      ],
      onChanged: (next) {
        if (next == null || next == value) return;
        onEdit([
          PathwayCellEdit(
            pathwayId: pathwayId,
            column: column,
            value: next,
          ),
        ]);
      },
    );
  }
}

/// What `+ Add pathway` is called.
const String kAddPathwayLabel = 'Add pathway';

/// What the delete affordance says before it says the consequence.
const String kRemovePathwayTooltip = 'Delete this pathway.';

/// The empty state, which names both gestures that make a pathway.
///
/// IT DOES NOT SAY "in the Plan view". That surface is DR-029's and is
/// not built, and copy naming an unbuilt screen is the defect
/// `unbuilt_copy_accuracy_test.dart` exists to catch.
const String kNoPathwaysYet =
    'No conduits, J-hooks or trays recorded yet.\n\n'
    'Type a conduit into the line above — "Living Room: 1x ENT" — and it '
    'becomes a pathway rather than a cable. Or add one here and name it '
    'yourself.';
