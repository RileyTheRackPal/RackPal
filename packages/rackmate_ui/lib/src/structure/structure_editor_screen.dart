// THE STRUCTURE EDITOR. Board M3-C/2 (#148), docs/07 §4, AC-048.
//
// ═════════════════════════════════════════════════════════════════════
// IT RENDERS A DERIVATION. IT DOES NOT CONTAIN ONE.
// ═════════════════════════════════════════════════════════════════════
// Every row, every band, every count and every cell string comes from
// `rackmate_core`'s `derived/structure_table.dart`, which is itself a
// projection of `derived/schedule.dart` — so what the editor shows and
// what the Pull Sheet prints are the same strings from the same
// function. `schedule_screen.dart` states this rule for the Schedule tab
// and it is the same rule here, with more at stake: this is the surface
// people TYPE INTO, and a table that computed its own media name would
// be CR-107's "the drop schedule says 78 ft and the wiring schedule says
// 90 ft" one layer up.
//
// This file owns exactly three things, all of them VIEW state: which
// optional columns are showing, what the three filters are set to, and
// the "just added" tail of the quick-add loop.
//
// ═════════════════════════════════════════════════════════════════════
// WHAT THE §4 WIREFRAME DRAWS THAT IS NOT HERE, AND WHY NOT
// ═════════════════════════════════════════════════════════════════════
// `shell_tabs_test.dart` proves that no tab in this app "fabricates a
// device, a port label or a control that does nothing", and that rule
// binds a new surface hardest, because a new surface can meet it for
// free by simply not drawing the control.
//
//   * THE TAB STRIP IS THREE TABS AND §4 DRAWS FOUR. `[▶ Table]
//     [ Matrix ]` are M3-C/2 and M3-C/3, `[ Pathways ]` is M3-E/1, and
//     `[ Outlets ]` is later — a tab that opens nothing is the
//     `UnbuiltView` defect wearing a different hat. #148 shipped with no
//     strip at all for exactly this reason — AC-048 asks that the editor
//     OPEN IN TABLE MODE, which one surface satisfies outright — and
//     #149 adds it because there is now a second thing to switch to. The
//     strip keeps §4's order, so the absent tab holds its place rather
//     than letting the built ones shuffle left.
//   * NO `[Group into pathway]`, `[Renumber…]`, `[Import CSV…]` or
//     `[Export CSV]` in the button bar. Renumber is M3-F, CSV is docs/07
//     §5 and unbuilt. **Grouping into a pathway still has no command**,
//     and `[ Pathways ]` does not supply one: that tab lists and edits
//     the pathways that exist and does not assign runs to them, which is
//     the user's own scoping — a pathway is set in the Plan view, once
//     somebody has walked the run (DR-020 §11.19.1's reasoning applied to
//     the entity).
//   * NO `Labels: [Residential CI ▾] [TIA-606 Cl.2 ▾]` in the header.
//     Those pick an id-format profile, which is M3-H.
//
// The two controls that ARE drawn both do something: quick add is
// M3-C/1's loop, and `+ Add outlet ▾` is M3-C/5's picker.
//
// ═════════════════════════════════════════════════════════════════════
// THE TREE IS READ-ONLY HERE, AND THAT IS CR-112
// ═════════════════════════════════════════════════════════════════════
// docs/07 §4: the left pane is "a view of the project vocabulary, not an
// editor for it". Rooms are named once, in `Project ▸ Locations…`, and
// the affordance below the tree says so rather than the pane silently
// refusing a double-click.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard;
import 'package:rackmate_core/rackmate_core.dart';
import 'package:rackmate_ui/src/keymap/keymap.dart';
import 'package:rackmate_ui/src/structure/csv_import_dialog.dart';
import 'package:rackmate_ui/src/structure/drop_entry_panel.dart';
import 'package:rackmate_ui/src/structure/outlets_view.dart';
import 'package:rackmate_ui/src/structure/pathways_view.dart';
import 'package:rackmate_ui/src/structure/structure_matrix_view.dart';

/// What the app does when the editor asks for something.
///
/// CALLBACKS AND NOT A CONTROLLER, the shape `LocationsPanel` and
/// `DropEntryPanel` already use, so `rackmate_ui` stays free of the
/// session layer.
@immutable
final class StructureEditorActions {
  const StructureEditorActions({
    required this.dropEntry,
    required this.onAddOutlet,
    required this.onEdit,
    required this.onSetCount,
    required this.onEditPathways,
    required this.onAddPathway,
    required this.onRemovePathway,
    required this.onImportCsv,
    required this.outlets,
  });

  /// M3-C/1's loop, unchanged. See `DropEntryActions.onCommit` for why
  /// the parsed LINE crosses this boundary and never the preview's
  /// commands.
  final DropEntryActions dropEntry;

  /// Opens M3-C/5's outlet-template picker, on the Structure body the
  /// editor's picker is currently showing (M3-E/3, #158).
  final void Function(Uuid? structureBodyId) onAddOutlet;

  /// Applies cell edits as ONE undo step, and returns a refusal sentence
  /// or null.
  ///
  /// A LIST AND NOT ONE EDIT, because the interesting case is the bulk
  /// one. `buildSetStructureOriginProperty` takes `alsoUsedLabels`
  /// precisely so a batch cannot let two rows agree on a field label
  /// while each individually looks fine against the unmutated document;
  /// handing it one edit at a time would throw that away. A single typed
  /// cell is a list of one.
  ///
  /// ALL OR NOTHING. A batch with one bad label applies none of itself
  /// and says which one, because a fill-down that wrote nine of ten rows
  /// and reported an error leaves a person to work out which nine.
  final String? Function(List<StructureCellEdit> edits) onEdit;

  /// Applies one MATRIX cell as one undo step, and returns a refusal
  /// sentence or null (M3-C/3).
  ///
  /// A SECOND CALLBACK RATHER THAN A THIRD COLUMN ID, because the two
  /// tabs edit different things. A table cell is a FIELD on one drop; a
  /// matrix cell is a COUNT of drops, and typing `2` over `6` deletes
  /// four cables. Folding them together would put "does this write a
  /// value or delete a cable" behind one signature.
  final String? Function(StructureMatrixEdit edit) onSetCount;

  /// The Pathways tab's cells, as ONE undo step (M3-E/1, #156).
  ///
  /// A THIRD CALLBACK RATHER THAN A WIDER `onEdit`, on [onSetCount]'s
  /// reasoning: the id in a `PathwayCellEdit` is a `Pathway`'s and the id
  /// in a `StructureCellEdit` is a `Link`'s. Folding them together would
  /// put two entity types behind one `Uuid` and leave the app to work out
  /// which it was handed from the column.
  final String? Function(List<PathwayCellEdit> edits) onEditPathways;

  /// Creates one pathway (`AddPathwayCommand`).
  final String? Function() onAddPathway;

  /// Deletes one pathway and clears every `Link` that named it. NOT a
  /// cascade: see `RemovePathwayCommand`.
  final String? Function(Uuid id) onRemovePathway;

  /// docs/07 §5's import, on the body the editor is showing (M3-F/2,
  /// #160).
  ///
  /// THE WHOLE FLOW LIVES ON THE APP SIDE, because it opens a native
  /// file dialog and reads a file, and `rackmate_ui` has neither. What
  /// crosses this boundary is a request and nothing else: the dialog
  /// this opens is `showCsvImportDialog`, which is in this package and
  /// takes only a parsed table and the live document.
  ///
  /// ASYNC, unlike every other callback here, and that is the file
  /// dialog: the native picker blocks on the user and AC-058/D14 wants
  /// progress on anything over ~500 ms.
  final Future<void> Function(Uuid? structureBodyId) onImportCsv;

  /// The Outlets tab's five gestures (M3-H/2, #167, DR-007 §11.7).
  ///
  /// ITS OWN GROUP RATHER THAN FIVE MORE FIELDS HERE, which is the shape
  /// `dropEntry` already uses: they are one surface's vocabulary, they
  /// all carry an `outletId` a table edit never does, and a tab that had
  /// to reach past four unrelated pathway callbacks to find them would
  /// invite somebody to widen `onEdit` instead.
  final OutletsActions outlets;
}

/// Which of §4's tabs the editor is showing.
///
/// FOUR, AND §4 DRAWS FOUR. The strip was three from M3-C to M3-H and
/// this file named the missing one beside the list it was missing from;
/// `Outlets` arrived with M3-H (#167) and the count now matches the
/// wireframe. The order is still §4's, so nothing shuffled.
enum StructureEditorTab {
  /// AC-048's requirement, and the value this enum starts on.
  table,

  /// docs/07 §4.2.
  matrix,

  /// docs/07 §4, M3-H/2 (#167), DR-007 §11.7. One wall plate at a time,
  /// drawn to scale: gangs, straps, and which keystone is in which cell.
  outlets,

  /// docs/07 §4, M3-E/1 (#156). A list and an editor for the pathways
  /// that exist, deliberately not a routing surface: the user's stated
  /// expectation is that a pathway is SET in the Plan view, once somebody
  /// has walked the run.
  pathways,
}

/// What the tab strip calls each tab.
const String kTableTabLabel = 'Table';

/// See [kTableTabLabel].
const String kMatrixTabLabel = 'Matrix';

/// See [kTableTabLabel].
const String kOutletsTabLabel = 'Outlets';

/// See [kTableTabLabel].
const String kPathwaysTabLabel = 'Pathways';

/// One cell, as an edit request: which drop, which column, what was
/// typed.
///
/// THE VALUE IS TEXT, always, even for `ROUGH-IN` whose model type is an
/// enum. The parsing belongs on the app side beside the command that
/// refuses, so this type stays what the surface actually has: what a
/// person put in a box.
@immutable
final class StructureCellEdit {
  const StructureCellEdit({
    required this.linkId,
    required this.column,
    required this.value,
  });

  final Uuid linkId;
  final StructureColumnId column;
  final String value;
}

/// Opens the editor full-screen.
///
/// FULL-SCREEN AND NOT A TAB. The four top-level tabs are views of a
/// DOCUMENT (`Ctrl+1/2/4`, CR-071); this is an editor for one entity,
/// with a `Done`, in the same shape docs/06's device builder has. Its
/// header carries the body it is editing so two Structure bodies (§7)
/// can never be confused for one.
///
/// [currentDoc] is read on every build, for [DropEntryLoop]'s reason: a
/// surface holding one document reference plans the next line against
/// the state before the last one landed.
Future<void> showStructureEditor(
  BuildContext context, {
  required StructureEditorActions actions,
  required RackDocument Function() currentDoc,
  Uuid? structureBodyId,
}) => showDialog<void>(
  context: context,
  // The editor is a working surface, not a question: it fills the
  // window rather than floating a 640 px card over the rack.
  builder: (context) => Dialog.fullscreen(
    child: StructureEditorScreen(
      actions: actions,
      currentDoc: currentDoc,
      structureBodyId: structureBodyId,
      onDone: () => Navigator.of(context).pop(),
    ),
  ),
);

/// docs/07 §4's editor, in table mode.
class StructureEditorScreen extends StatefulWidget {
  const StructureEditorScreen({
    required this.actions,
    required this.currentDoc,
    this.structureBodyId,
    this.onDone,
    super.key,
  });

  final StructureEditorActions actions;
  final RackDocument Function() currentDoc;

  /// The body to OPEN on. Null means "decide from the document", which
  /// resolves to `defaultStructureBody` and never to "all of them"
  /// (M3-E/3, #158).
  ///
  /// IT USED TO MEAN "SHOW EVERY ONE OF THEM", and the app passed null
  /// forever, so a project with two panels rendered both sets of drops in
  /// one undifferentiated table while the header said *"2 Structure
  /// devices"*. CR-113 ships multiple instances; merging them is not what
  /// it ships.
  final Uuid? structureBodyId;

  /// Null when the editor is not in a route it can pop — the state a
  /// widget test drives it in.
  final VoidCallback? onDone;

  @override
  State<StructureEditorScreen> createState() => _StructureEditorScreenState();
}

class _StructureEditorScreenState extends State<StructureEditorScreen> {
  final Set<StructureColumnId> _optional = <StructureColumnId>{};

  /// AC-048: THE EDITOR OPENS IN TABLE MODE. The one requirement the
  /// ruling makes of this surface, and the one line that keeps it.
  StructureEditorTab _tab = StructureEditorTab.table;

  /// The matrix's media columns, seeded with §4.2's own eight so the
  /// grid is usable the moment it opens rather than after a person has
  /// configured it. Filtered against the document's registry inside
  /// `buildStructureMatrix`.
  final Set<MediaTypeId> _mediaColumns = {...kStructureMatrixSeedColumns};

  Uuid? _roomFilter;
  MediaTypeId? _mediaFilter;
  bool _unconnectedOnly = false;

  /// Ticked rows, by `Link` id (M3-L/3, DR-043 §11.42.6).
  ///
  /// **IDS AND NOT INDICES**, for the reason `_DataRow` is keyed on the
  /// link: a filter change or a deletion reshuffles the list, and a
  /// selection held as positions would silently come to mean different
  /// cables.
  ///
  /// **NOT PRUNED WHEN A FILTER HIDES A ROW.** The id stays selected and
  /// the bar counts it as hidden; see [_selectedVisible] for the half
  /// that matters, which is that a batch never writes to a row nobody can
  /// see. Pruning was the alternative and it throws away work: narrowing
  /// a filter to find the rest of your rows would drop the ones already
  /// ticked.
  final Set<Uuid> _selected = <Uuid>{};

  /// The batch bar's column, or null before anybody picked one.
  StructureColumnId? _batchColumn;

  /// The body the picker has chosen, or null before anybody has chosen.
  ///
  /// RESOLVED PER BUILD RATHER THAN LATCHED IN `initState`, by
  /// [_bodyIdFor]. A latched id goes stale the moment the chosen panel is
  /// deleted from another surface, and a table filtered to a body that no
  /// longer exists shows nothing at all, which reads exactly like a
  /// project with no drops.
  Uuid? _pickedBodyId;

  /// Which body this build shows: the picked one if it still exists, else
  /// the one the editor was opened on, else the document's default.
  ///
  /// NEVER NULL WHEN THE PROJECT HAS A BODY, which is the whole change.
  /// `buildStructureTable`'s null means "do not filter", and that is a
  /// fine contract for a caller that wants every row; it is the wrong
  /// thing for an editor, because two panels merged into one table is the
  /// failure CR-113's milestone exists to prevent.
  Uuid? _bodyIdFor(RackDocument doc) {
    final picked = _pickedBodyId;
    if (picked != null && doc.structures.containsKey(picked)) return picked;
    final opened = widget.structureBodyId;
    if (opened != null && doc.structures.containsKey(opened)) return opened;
    return defaultStructureBody(doc)?.id;
  }

  /// The last refusal, held until the next edit succeeds.
  ///
  /// IT DOES NOT FADE. A `SnackBar` would be the ordinary choice and it
  /// is the wrong one here: a refused label edit means the cell went back
  /// to what it was, and a person who looked away for three seconds sees
  /// only that their typing vanished. docs/04 §3.4's rule is that a
  /// refusal names itself; a rule that expires is a rule that sometimes
  /// does not.
  String? _refusal;

  List<StructureColumnId> get _columns => [
    ...kStructureDefaultColumns,
    // IN §4.1'S OWN ORDER rather than in the order they were ticked, so
    // the table does not rearrange itself under a person who turns two
    // columns on and off while reading a row.
    ...kStructureOptionalColumns.where(_optional.contains),
  ];

  bool _keeps(RackDocument doc, ScheduleEntry row) {
    if (_roomFilter != null && row.roomId != _roomFilter) return false;
    if (_mediaFilter != null && row.mediaId != _mediaFilter) return false;
    if (_unconnectedOnly && _isLanded(row)) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final doc = widget.currentDoc();
    final table = buildStructureTable(doc, structureBodyId: _bodyIdFor(doc));
    final visible = _filter(doc, table);

    // THE TWO GRID BINDINGS WRAP THE WHOLE EDITOR AND NOT THE TABLE TAB,
    // which looks like the looser choice and is the stricter one.
    // `Shortcuts` only sees a key when the FOCUSED widget is inside it,
    // so scoping this to the table body would make `Ctrl+D` silently do
    // nothing whenever focus sat in the quick-add bar — the exact thing
    // docs/04 §3.4 forbids, and the thing `kNoCaretForFill` exists to
    // prevent. Both handlers say what is true where they are pressed;
    // see [_fillDown].
    return Shortcuts(
      shortcuts: keymapShortcuts(KeyScope.structure),
      child: Actions(
        actions: <Type, Action<Intent>>{
          FillDownIntent: CallbackAction<FillDownIntent>(
            onInvoke: (_) {
              _fillDown();
              return null;
            },
          ),
          PasteCellsIntent: CallbackAction<PasteCellsIntent>(
            onInvoke: (_) {
              unawaited(_paste());
              return null;
            },
          ),
        },
        child: _body(context, doc, table, visible),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    RackDocument doc,
    StructureTable table,
    List<StructureTableGroup> visible,
  ) => ColoredBox(
    color: Theme.of(context).colorScheme.surface,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _EditorHeader(
          doc: doc,
          structureBodyId: _bodyIdFor(doc),
          table: table,
          onDone: widget.onDone,
          onBody: (id) => setState(() => _pickedBodyId = id),
          onImportCsv: () =>
              unawaited(widget.actions.onImportCsv(_bodyIdFor(doc))),
        ),
        _TabStrip(
          tab: _tab,
          onTab: (next) => setState(() => _tab = next),
        ),
        const Divider(height: 1),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 220,
                child: _LocationPane(doc: doc, table: table),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // THE LOOP IS ABOVE THE TABS AND NOT INSIDE ONE,
                    // which is the whole of #149's instruction: "a
                    // matrix that is its own screen is a second place
                    // the repeat loop has to be re-established". It is
                    // the same widget with the same state on both.
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                      child: DropEntryLoop(
                        actions: _loopActions(),
                        currentDoc: widget.currentDoc,
                        structureBodyId: _bodyIdFor(doc),
                      ),
                    ),
                    Expanded(
                      child: switch (_tab) {
                        StructureEditorTab.table => _tableBody(
                          doc,
                          table,
                          visible,
                        ),
                        StructureEditorTab.matrix => StructureMatrixView(
                          doc: doc,
                          structureBodyId: widget.structureBodyId,
                          columns: _mediaColumns,
                          onColumn: (id) => setState(() {
                            if (!_mediaColumns.remove(id)) {
                              _mediaColumns.add(id);
                            }
                          }),
                          onSetCount: _setCount,
                        ),
                        StructureEditorTab.outlets => OutletsView(
                          doc: doc,
                          structureBodyId: widget.structureBodyId,
                          actions: widget.actions.outlets,
                        ),
                        StructureEditorTab.pathways => PathwaysView(
                          doc: doc,
                          actions: PathwaysActions(
                            onEdit: _editPathways,
                            onAdd: _addPathway,
                            onRemove: _removePathway,
                          ),
                        ),
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        _StatusBar(
          table: table,
          refusal: _refusal,
          // THE FILTERS ARE THE TABLE'S, so on the matrix tab nothing
          // is hidden by them. Reporting "9 hidden by filter" beside a
          // grid that shows every room would be the status bar
          // describing a screen nobody is looking at.
          hidden: _tab == StructureEditorTab.table
              ? table.dropCount - _shownCount(visible)
              : 0,
          onAddDrop: null,
          onAddOutlet: () => widget.actions.onAddOutlet(_bodyIdFor(doc)),
        ),
      ],
    ),
  );

  /// The table tab: the filter bar, then the grid.
  Widget _tableBody(
    RackDocument doc,
    StructureTable table,
    List<StructureTableGroup> visible,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _FilterBar(
        doc: doc,
        table: table,
        roomFilter: _roomFilter,
        mediaFilter: _mediaFilter,
        unconnectedOnly: _unconnectedOnly,
        optional: _optional,
        onRoom: (v) => setState(() => _roomFilter = v),
        onMedia: (v) => setState(() => _mediaFilter = v),
        onUnconnected: (v) => setState(() => _unconnectedOnly = v),
        onToggleColumn: (id) => setState(() {
          if (!_optional.remove(id)) _optional.add(id);
        }),
        onToggleAsBuilt: () => setState(() {
          // ALL ON, OR ALL OFF. A half-on set toggles ON, because
          // somebody who ticked one of them by hand and then asked
          // for the group wants the group.
          if (_optional.containsAll(kStructureAsBuiltColumns)) {
            _optional.removeAll(kStructureAsBuiltColumns);
          } else {
            _optional.addAll(kStructureAsBuiltColumns);
          }
        }),
      ),
      const Divider(height: 1),
      // ONLY WHEN SOMETHING IS TICKED. A bar that was always there would
      // be a permanent strip of controls that do nothing on an empty
      // selection, which is the defect `shell_tabs_test.dart` gates.
      if (_selected.isNotEmpty)
        _BatchBar(
          selectedVisible: _selectedVisible(doc).length,
          selectedHidden: _selected.length - _selectedVisible(doc).length,
          column: _batchColumn,
          columns: _columns.where(structureColumnIsBatchable).toList(),
          onColumn: (id) => setState(() => _batchColumn = id),
          onSet: _batchSet,
          onClear: () => setState(() {
            _selected.clear();
            _batchColumn = null;
          }),
        ),
      Expanded(
        child: _DropTable(
          doc: doc,
          groups: visible,
          columns: _columns,
          onEdit: _edit,
          onCaret: (cell) => _caret = cell,
          isFiltered:
              _roomFilter != null || _mediaFilter != null || _unconnectedOnly,
          totalDrops: table.dropCount,
          selected: _selected,
          onSelect: (linkId, {required ticked}) => setState(() {
            if (ticked) {
              _selected.add(linkId);
            } else {
              _selected.remove(linkId);
            }
          }),
          onSelectAll: (ticked) => setState(() {
            // ALL VISIBLE, NOT ALL ROWS. The header tick means "these",
            // and "these" is what is on screen: a filter is the person
            // saying which rows they are working on.
            final ids = _visibleRows(doc).map((r) => r.linkId);
            if (ticked) {
              _selected.addAll(ids);
            } else {
              _selected.removeAll(ids);
            }
          }),
        ),
      ),
    ],
  );

  /// Hands one matrix cell to the app and rebuilds on whatever came
  /// back, which is [_edit]'s shape and for [_edit]'s reason: the rules
  /// have a document behind them and a surface holding a second copy of
  /// one is how two answers to a question start.
  String? _setCount(StructureMatrixEdit edit) {
    final refusal = widget.actions.onSetCount(edit);
    setState(() => _refusal = refusal);
    return refusal;
  }

  /// The Pathways tab's three gestures, each on [_setCount]'s shape.
  ///
  /// THEY GO THROUGH THE SAME `_refusal` AS THE OTHER TWO TABS, so a
  /// pathway edit that is refused says so in the one place this editor
  /// puts a refusal. A second banner would be a second thing to look at
  /// for the same class of news.
  String? _editPathways(List<PathwayCellEdit> edits) {
    final refusal = widget.actions.onEditPathways(edits);
    setState(() => _refusal = refusal);
    return refusal;
  }

  String? _addPathway() {
    final refusal = widget.actions.onAddPathway();
    setState(() => _refusal = refusal);
    return refusal;
  }

  String? _removePathway(Uuid id) {
    final refusal = widget.actions.onRemovePathway(id);
    setState(() => _refusal = refusal);
    return refusal;
  }

  /// Which cell the caret is in, or null when it is not in the table.
  ///
  /// SET BY THE CELLS THEMSELVES as they gain focus, rather than tracked
  /// by a selection model this screen would then have to keep in step
  /// with the focus tree. There is exactly one focused widget and Flutter
  /// already knows which; a second answer to that question is a second
  /// thing to be wrong.
  (Uuid, StructureColumnId)? _caret;

  /// The rows the table is showing, flattened across the bands.
  ///
  /// THE VISIBLE ORDER, and that is the honest one for a fill: `Ctrl+D`
  /// means "the cell above", and the cell above is the one a person can
  /// see above. Filling from a row hidden by a filter would copy a value
  /// off the screen.
  List<ScheduleEntry> _visibleRows(RackDocument doc) => [
    for (final group in _filter(
      doc,
      buildStructureTable(
        doc,
        structureBodyId: widget.structureBodyId,
      ),
    ))
      ...group.rows,
  ];

  /// Selected rows that are ALSO on screen, in visible order.
  ///
  /// **THE ONLY SET A BATCH EVER WRITES TO** (DR-043 §11.42.6, and the
  /// user's own call on 2026-08-11). Editing a row hidden behind a filter
  /// is the one genuinely dangerous outcome available here: the button
  /// would look safe, the undo entry would name a count matching nothing
  /// on screen, and the person would find out weeks later on a printed
  /// sheet. `_fillDown` already refuses to copy FROM a hidden row for the
  /// same reason.
  List<ScheduleEntry> _selectedVisible(RackDocument doc) => [
    for (final row in _visibleRows(doc))
      if (_selected.contains(row.linkId)) row,
  ];

  /// Sets one column to one value on every selected VISIBLE row.
  ///
  /// ONE BATCH, so it is one entry on the undo stack and it is all or
  /// nothing: `StructureEditorActions.onEdit` already contracts both, and
  /// `_paste` already relies on it. Nothing new was needed in the edit
  /// path for this task, only the selection in front of it.
  void _batchSet(String value) {
    final column = _batchColumn;
    if (column == null) return;
    final doc = widget.currentDoc();
    final rows = _selectedVisible(doc);
    if (rows.isEmpty) {
      setState(() => _refusal = kNothingSelectedToSet);
      return;
    }
    _edit([
      for (final row in rows)
        StructureCellEdit(linkId: row.linkId, column: column, value: value),
    ]);
  }

  /// `Ctrl+D` — copy the cell directly above into the focused one.
  ///
  /// IT ANSWERS FOR THE TAB IT IS PRESSED ON. Both bindings act on a
  /// TABLE cell, so on the matrix there is nothing for them to do — and
  /// saying that is the whole of docs/04 §3.4, where printing "put the
  /// caret in a cell first" at somebody whose caret IS in a cell would
  /// be worse than an unbound key.
  void _fillDown() {
    if (_tab != StructureEditorTab.table) {
      setState(() => _refusal = kGridKeysAreTableOnly);
      return;
    }
    final caret = _caret;
    if (caret == null) {
      setState(() => _refusal = kNoCaretForFill);
      return;
    }
    final doc = widget.currentDoc();
    final rows = _visibleRows(doc);
    final index = rows.indexWhere((r) => r.linkId == caret.$1);
    if (index <= 0) {
      // Row zero has nothing above it, and saying so beats a keypress
      // that appears to do nothing (docs/04 §3.4).
      setState(() => _refusal = kNothingAboveToFill);
      return;
    }
    _edit([
      StructureCellEdit(
        linkId: caret.$1,
        column: caret.$2,
        value: _valueFor(doc, rows[index - 1], caret.$2),
      ),
    ]);
  }

  /// `Ctrl+V` — tab-separated cells, from the caret rightwards and down.
  ///
  /// ONE BATCH FOR THE WHOLE PASTE, so a spreadsheet column that collides
  /// on its fourth row writes none of its rows rather than three. See
  /// `StructureEditorActions.onEdit`.
  Future<void> _paste() async {
    if (_tab != StructureEditorTab.table) {
      setState(() => _refusal = kGridKeysAreTableOnly);
      return;
    }
    final caret = _caret;
    if (caret == null) {
      setState(() => _refusal = kNoCaretForPaste);
      return;
    }
    final clip = await Clipboard.getData(Clipboard.kTextPlain);
    final text = clip?.text;
    if (text == null || text.trim().isEmpty) return;
    if (!mounted) return;

    final doc = widget.currentDoc();
    final rows = _visibleRows(doc);
    final columns = _columns;
    final firstRow = rows.indexWhere((r) => r.linkId == caret.$1);
    final firstColumn = columns.indexOf(caret.$2);
    if (firstRow < 0 || firstColumn < 0) return;

    final edits = <StructureCellEdit>[];
    // `\r\n` AND `\n`, because the clipboard's line ending is the source
    // application's, not this platform's: Excel on Windows and a text
    // editor on the same machine disagree, and a stray `\r` would land
    // inside a label.
    final lines = text.replaceAll('\r\n', '\n').split('\n');
    for (var r = 0; r < lines.length; r++) {
      if (lines[r].isEmpty && r == lines.length - 1) continue;
      final targetRow = firstRow + r;
      if (targetRow >= rows.length) {
        // A PASTE DOES NOT CREATE DROPS. Ten values into the last three
        // rows would otherwise invent seven cables from a spreadsheet,
        // each needing a room, a media type and a label nobody chose.
        setState(
          () => _refusal = kPasteOverruns(lines.length, rows.length - firstRow),
        );
        return;
      }
      final cells = lines[r].split('\t');
      for (var c = 0; c < cells.length; c++) {
        final targetColumn = firstColumn + c;
        if (targetColumn >= columns.length) {
          setState(() => _refusal = kPasteOverrunsColumns);
          return;
        }
        final column = columns[targetColumn];
        if (!structureColumnIsEditable(column)) {
          setState(
            () => _refusal =
                'Nothing can be pasted into ${structureColumnHeader(column)}.',
          );
          return;
        }
        edits.add(
          StructureCellEdit(
            linkId: rows[targetRow].linkId,
            column: column,
            value: cells[c],
          ),
        );
      }
    }
    if (edits.isNotEmpty) _edit(edits);
  }

  /// What a cell holds, as the edit path wants it: the displayed string,
  /// with the unknown dash flattened to empty.
  ///
  /// THE SAME TRANSLATION `_DataRow` MAKES when it fills a text box, and
  /// for the same reason: `—` is what an unknown prints, never a value to
  /// copy into another row.
  String _valueFor(RackDocument doc, ScheduleEntry row, StructureColumnId id) {
    final text = structureCell(
      doc,
      row,
      id,
      units: doc.settings.displayUnits,
    );
    return text == kUnknownCell ? '' : text;
  }

  /// Hands [edits] to the app and rebuilds on whatever came back.
  ///
  /// THE APP'S ANSWER IS THE ONLY ANSWER. This does not check a label for
  /// uniqueness, does not parse a `RoughInStatus` and does not decide
  /// that an empty box means null: every one of those is a rule with a
  /// document behind it, and a surface holding a second copy of a rule is
  /// how two answers to one question start.
  String? _edit(List<StructureCellEdit> edits) {
    final refusal = widget.actions.onEdit(edits);
    setState(() => _refusal = refusal);
    return refusal;
  }

  /// The loop's actions, wrapped so the TABLE rebuilds too.
  ///
  /// `DropEntryLoop` already rebuilds itself and owns its "just added"
  /// tail; what it cannot know is that a committed line changed the rows
  /// underneath it. Every arm calls `setState` for that reason and for no
  /// other, including the refusing one: a refusal can still have created
  /// a room or a Structure body on the way to refusing.
  DropEntryActions _loopActions() => DropEntryActions(
    onCommit: (line, {structureBodyId}) {
      final committed = widget.actions.dropEntry.onCommit(
        line,
        structureBodyId: structureBodyId,
      );
      setState(() {});
      return committed;
    },
    onCreateLocation: (name) {
      widget.actions.dropEntry.onCreateLocation(name);
      setState(() {});
    },
    onCreateStructure: () {
      widget.actions.dropEntry.onCreateStructure();
      setState(() {});
    },
  );

  /// The filters applied, band by band.
  ///
  /// A BAND WITH NO SURVIVING ROW DISAPPEARS, but the counts in its
  /// header and in the status bar are still the TABLE's — see
  /// [_StatusBar]. A filter that also changed the totals would let
  /// somebody read "6 drops" off a screen filtered to one media type and
  /// order cable for the house.
  List<StructureTableGroup> _filter(
    RackDocument doc,
    StructureTable table,
  ) {
    final out = <StructureTableGroup>[];
    for (final group in table.groups) {
      final rows = group.rows.where((r) => _keeps(doc, r)).toList();
      if (rows.isEmpty) continue;
      out.add(
        rows.length == group.rows.length
            ? group
            : StructureTableGroup(
                locationId: group.locationId,
                title: group.title,
                code: group.code,
                rows: rows,
                connectedCount: rows.where(_isLanded).length,
                spareCount: group.spareCount,
                estimatedRunLength: group.estimatedRunLength,
              ),
      );
    }
    return out;
  }

  int _shownCount(List<StructureTableGroup> groups) =>
      groups.fold<int>(0, (n, g) => n + g.rows.length);
}

/// True when the rack end is a real port. The same rule
/// `StructureTable.connectedCount` counts by, spelled once here so the
/// `☐ Unconnected only` filter and the count cannot disagree about what
/// "connected" means.
bool _isLanded(ScheduleEntry row) => switch (row.to.kind) {
  ScheduleEndKind.rackPort || ScheduleEndKind.unrackedPort => true,
  _ => false,
};

/// `Structure  STR-1 · "Media Panel — Garage"   52 drops · 41 connected`.
class _EditorHeader extends StatelessWidget {
  const _EditorHeader({
    required this.doc,
    required this.structureBodyId,
    required this.table,
    required this.onDone,
    required this.onBody,
    required this.onImportCsv,
  });

  final RackDocument doc;
  final Uuid? structureBodyId;
  final StructureTable table;
  final VoidCallback? onDone;

  /// M3-F/2 (#160). In the HEADER rather than beside `Add outlet`,
  /// because it acts on the whole body and not on the table's selection,
  /// and §4's wireframe draws it with the other body-level controls.
  final VoidCallback onImportCsv;

  /// Choose which body the editor is working on (M3-E/3, #158).
  final ValueChanged<Uuid> onBody;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final body = doc.structures[structureBodyId];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      child: Row(
        children: [
          Text('Structure', style: theme.textTheme.titleMedium),
          const SizedBox(width: 12),
          // THE PICKER APPEARS ONLY WHEN THERE IS SOMETHING TO PICK. A
          // one-panel project is the ordinary case and gains no chrome;
          // a dropdown with one entry is a control that cannot be used
          // and still has to be read past.
          if (doc.structures.length > 1) ...[
            // FLEXIBLE, because the picker's width is the LONGEST BODY
            // NAME a person typed and nothing bounds that. It was the
            // only unconstrained child in this row, so adding one more
            // button (M3-F/2's `Import CSV…`) overflowed the header on a
            // narrow window by four pixels. The subtitle beside it was
            // already free to collapse; this one was not.
            Flexible(
              child: _StructureBodyPicker(
                doc: doc,
                selectedId: structureBodyId,
                onBody: onBody,
              ),
            ),
          ],
          Expanded(
            child: Text(
              _subtitle(body, doc),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          TextButton(
            onPressed: onImportCsv,
            child: const Text(kImportCsvLabel),
          ),
          if (onDone != null)
            TextButton(onPressed: onDone, child: const Text('Done')),
        ],
      ),
    );
  }

  /// `STR-1 · "Media Panel"`, or what is true when there is no body.
  ///
  /// THE DESIGNATOR IS THE DEVICE'S, not the body's, and the body has
  /// none: a `StructureBody` is the payload on a `DeviceInstance`
  /// (docs/07 §2), so `STR-1` is `doc.devices[body.deviceId].designator`
  /// and there is no second copy of it to go stale.
  ///
  /// THE EMPTY CASE IS NAMED rather than blank: a project with no
  /// Structure device is the state every new project is in, and the
  /// quick-add loop offers to create one on `Enter`.
  static String _subtitle(StructureBody? body, RackDocument doc) {
    if (body != null) {
      final designator = doc.devices[body.deviceId]?.designator ?? kUnknownCell;
      final title = body.title.trim();
      return title.isEmpty ? designator : '$designator · $title';
    }
    if (doc.structures.isEmpty) return 'No Structure device yet';
    // UNREACHABLE FROM THE EDITOR AS OF #158, because `_bodyIdFor` always
    // resolves a body when the project holds one. Kept because this
    // widget is constructible with any id, including a stale one, and a
    // header that renders blank on a deleted panel is worse than one that
    // says how many exist.
    return '${doc.structures.length} Structure devices';
  }
}

/// The Structure-body picker, so a test can reach it without competing
/// with the drop table's own dropdowns.
///
/// EVERY EDITABLE CELL ON BOTH TABS IS A REAL CONTROL, which is what buys
/// the tab order, so `find.byType` stops naming one thing the moment the
/// table has a row in it. Same reason `_kindCell` in the Pathways tests
/// indexes rather than searches by text.
const Key kStructureBodyPickerKey = Key('structure-body-picker');

/// `[ STR-1 · Media Panel ▾ ]` — which Structure body the editor edits.
///
/// ONLY BUILT WHEN THE PROJECT HAS MORE THAN ONE (see [_EditorHeader]).
///
/// THE LIST IS `structureBodiesInOrder`, not `doc.structures.values`. A
/// map's iteration order is insertion order, so a picker built from it
/// would reshuffle when a document was reloaded from disk, and the entry
/// a person reached for by position would move under them.
class _StructureBodyPicker extends StatelessWidget {
  const _StructureBodyPicker({
    required this.doc,
    required this.selectedId,
    required this.onBody,
  });

  final RackDocument doc;
  final Uuid? selectedId;
  final ValueChanged<Uuid> onBody;

  @override
  Widget build(BuildContext context) {
    final bodies = structureBodiesInOrder(doc);
    return DropdownButton<Uuid>(
      key: kStructureBodyPickerKey,
      value: selectedId,
      focusColor: Colors.transparent,
      // FILLS ITS BOX AND ELLIPSISES, because the label is
      // `STR-1 · "Media Panel — Garage"` and the quoted half is whatever
      // a person typed. Unbounded, it pushed the header's own controls
      // off the right on a narrow window; bounded without this, the
      // button's internal row overflowed instead. The caller gives it a
      // `Flexible`; this is what lets it accept the offer.
      isExpanded: true,
      onChanged: (id) {
        if (id != null) onBody(id);
      },
      items: [
        for (final body in bodies)
          DropdownMenuItem<Uuid>(
            value: body.id,
            child: Text(
              _label(body),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }

  /// `STR-1 · Media Panel`, on `_EditorHeader._subtitle`'s rule: the
  /// designator belongs to the paired device and there is no second copy
  /// of it to go stale.
  String _label(StructureBody body) {
    final designator = doc.devices[body.deviceId]?.designator ?? kUnknownCell;
    final title = body.title.trim();
    return title.isEmpty ? designator : '$designator · $title';
  }
}

/// §4's `[▶ Table] [ Matrix ]`.
///
/// A `SegmentedButton` AND NOT TWO `TextButton`s, because a segmented
/// control states which one is showing rather than leaving a reader to
/// infer it from an underline, and it is one focus stop that the arrow
/// keys move within — which is what a two-item strip should cost a
/// keyboard.
class _TabStrip extends StatelessWidget {
  const _TabStrip({required this.tab, required this.onTab});

  final StructureEditorTab tab;
  final ValueChanged<StructureEditorTab> onTab;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: SegmentedButton<StructureEditorTab>(
        segments: const [
          ButtonSegment<StructureEditorTab>(
            value: StructureEditorTab.table,
            label: Text(kTableTabLabel),
          ),
          ButtonSegment<StructureEditorTab>(
            value: StructureEditorTab.matrix,
            label: Text(kMatrixTabLabel),
          ),
          // `Outlets` LANDED IN THE SLOT THAT WAS BEING HELD FOR IT
          // (M3-H/2, #167). §4's wireframe orders the strip
          // `[Table] [Matrix] [Outlets] [Pathways]`, and `Pathways`
          // shipped in third position holding fourth place rather than
          // shuffling left, precisely so this arrival moves nothing under
          // the hand of anybody who had learned where `Pathways` was.
          ButtonSegment<StructureEditorTab>(
            value: StructureEditorTab.outlets,
            label: Text(kOutletsTabLabel),
          ),
          ButtonSegment<StructureEditorTab>(
            value: StructureEditorTab.pathways,
            label: Text(kPathwaysTabLabel),
          ),
        ],
        selected: {tab},
        showSelectedIcon: false,
        onSelectionChanged: (next) => onTab(next.single),
      ),
    ),
  );
}

/// The read-only location tree (CR-112).
class _LocationPane extends StatelessWidget {
  const _LocationPane({required this.doc, required this.table});

  final RackDocument doc;
  final StructureTable table;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tree = LocationTree.of(doc);
    final counts = <Uuid, int>{
      for (final group in table.groups)
        if (group.locationId case final id?) id: group.dropCount,
    };
    final rows = <Widget>[];
    void walk(Uuid id, int depth) {
      final location = doc.locations[id];
      final name = location?.name.trim() ?? '';
      rows.add(
        _TreeRow(
          depth: depth,
          name: name.isEmpty ? kUnnamedLocation : name,
          code: location?.code.trim() ?? '',
          dropCount: counts[id] ?? 0,
        ),
      );
      for (final child in tree.childrenOf(id)) {
        walk(child, depth + 1);
      }
    }

    for (final root in tree.roots) {
      walk(root, 0);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
          child: Text(
            'LOCATIONS',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
        ),
        Expanded(
          child: rows.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'No rooms yet.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              : ListView(children: rows),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            // NAMES THE PLACE, and does not offer a button that would
            // open a second editor over this one. CR-112: the vocabulary
            // is the project's, not this body's.
            kLocationsAreReadOnlyHere,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

/// What the left pane says about why it cannot be typed into.
const String kLocationsAreReadOnlyHere =
    'Rooms are named in Project ▸ Locations…';

class _TreeRow extends StatelessWidget {
  const _TreeRow({
    required this.depth,
    required this.name,
    required this.code,
    required this.dropCount,
  });

  final int depth;
  final String name;
  final String code;
  final int dropCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(12.0 + depth * 14, 3, 12, 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ),
          if (code.isNotEmpty)
            Text(
              code,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          if (dropCount > 0) ...[
            Text(
              '$dropCount',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// `Filter: [All rooms ▾] [All media ▾] [☐ Unconnected only]  ⚙ Columns`.
class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.doc,
    required this.table,
    required this.roomFilter,
    required this.mediaFilter,
    required this.unconnectedOnly,
    required this.optional,
    required this.onRoom,
    required this.onMedia,
    required this.onUnconnected,
    required this.onToggleColumn,
    required this.onToggleAsBuilt,
  });

  final RackDocument doc;
  final StructureTable table;
  final Uuid? roomFilter;
  final MediaTypeId? mediaFilter;
  final bool unconnectedOnly;
  final Set<StructureColumnId> optional;
  final ValueChanged<Uuid?> onRoom;
  final ValueChanged<MediaTypeId?> onMedia;
  final ValueChanged<bool> onUnconnected;
  final ValueChanged<StructureColumnId> onToggleColumn;
  final VoidCallback onToggleAsBuilt;

  @override
  Widget build(BuildContext context) {
    // OFFERED FROM THE TABLE, NOT FROM THE REGISTRIES. A media dropdown
    // listing all 38 seeded types on a project that pulled Cat6 and RG6
    // is a menu somebody has to read; these are the values actually on
    // the body, which is the set a filter can usefully cut.
    final media = <MediaTypeId>{
      for (final group in table.groups)
        for (final row in group.rows) row.mediaId,
    }.toList()..sort((a, b) => a.v.compareTo(b.v));

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      // A `Wrap` AND NOT A `Row`, which is `_ScheduleToolbar`'s shape and
      // for the same reason: four controls at their natural widths
      // overflow a narrow window, and a filter bar that clips its own
      // last control is worse than one that takes two lines.
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          DropdownButton<Uuid?>(
            value: roomFilter,
            onChanged: onRoom,
            items: [
              const DropdownMenuItem<Uuid?>(child: Text('All rooms')),
              for (final group in table.groups)
                if (group.locationId case final id?)
                  DropdownMenuItem<Uuid?>(value: id, child: Text(group.title)),
            ],
          ),
          DropdownButton<MediaTypeId?>(
            value: mediaFilter,
            onChanged: onMedia,
            items: [
              const DropdownMenuItem<MediaTypeId?>(child: Text('All media')),
              for (final id in media)
                DropdownMenuItem<MediaTypeId?>(
                  value: id,
                  child: Text(
                    doc.registries.mediaTypes[id]?.displayName ?? id.v,
                  ),
                ),
            ],
          ),
          FilterChip(
            selected: unconnectedOnly,
            onSelected: onUnconnected,
            label: const Text('Unconnected only'),
          ),
          MenuAnchor(
            menuChildren: [
              // THE AS-BUILT SET AS ONE SWITCH, at the top rather than
              // buried among the seven ticks it replaces. DR-020
              // §11.19.2(5) pictures somebody "closing out sixty runs"
              // who "needs one table with a length column they tab down,
              // not sixty inspector visits"; making them reach that table
              // through seven menu entries would put the cost back in a
              // different place.
              MenuItemButton(
                closeOnActivate: false,
                leadingIcon: Icon(
                  optional.containsAll(kStructureAsBuiltColumns)
                      ? Icons.check_box_outlined
                      : Icons.check_box_outline_blank,
                  size: 18,
                ),
                onPressed: onToggleAsBuilt,
                child: const Text(kAsBuiltColumnsLabel),
              ),
              const Divider(height: 1),
              for (final id in kStructureOptionalColumns)
                MenuItemButton(
                  closeOnActivate: false,
                  leadingIcon: Icon(
                    optional.contains(id)
                        ? Icons.check_box_outlined
                        : Icons.check_box_outline_blank,
                    size: 18,
                  ),
                  onPressed: () => onToggleColumn(id),
                  child: Text(structureColumnHeader(id)),
                ),
            ],
            builder: (context, controller, child) => TextButton.icon(
              icon: const Icon(Icons.settings_outlined, size: 18),
              label: const Text('Columns'),
              onPressed: () =>
                  controller.isOpen ? controller.close() : controller.open(),
            ),
          ),
        ],
      ),
    );
  }
}

/// The grouped table: a pinned band per room, then that room's drops.
class _DropTable extends StatelessWidget {
  const _DropTable({
    required this.doc,
    required this.groups,
    required this.columns,
    required this.isFiltered,
    required this.totalDrops,
    required this.onEdit,
    required this.onCaret,
    required this.selected,
    required this.onSelect,
    required this.onSelectAll,
  });

  final RackDocument doc;
  final List<StructureTableGroup> groups;
  final List<StructureColumnId> columns;
  final bool isFiltered;
  final int totalDrops;
  final String? Function(List<StructureCellEdit> edits) onEdit;

  /// Reported as a cell gains focus, and nulled as it loses it. NOT
  /// `setState`: the caret changes on every `Tab` and nothing on screen
  /// draws differently for it, so rebuilding the whole table would be a
  /// rebuild per keystroke down a sixty-row column.
  final ValueChanged<(Uuid, StructureColumnId)?> onCaret;

  /// Ticked rows, by link id (M3-L/3).
  final Set<Uuid> selected;
  final void Function(Uuid linkId, {required bool ticked}) onSelect;
  final ValueChanged<bool> onSelectAll;

  @override
  Widget build(BuildContext context) {
    final units = doc.settings.displayUnits;
    final totalPt =
        kSelectGutterWidth +
        columns.fold<double>(0, (n, c) => n + structureColumnWidth(c));
    final visibleIds = <Uuid>{
      for (final g in groups)
        for (final r in g.rows) r.linkId,
    };
    return LayoutBuilder(
      builder: (context, constraints) {
        // Never squeezed below the authored widths — a narrow window
        // scrolls sideways instead, which is `_ScheduleTable`'s rule and
        // docs/08 §6.2's for the printed page.
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
                  // THE HEADERS RENDER BEFORE ANY DATA EXISTS, which is
                  // `schedule_screen.dart`'s rule for the empty case and
                  // is what makes an empty table READABLE rather than
                  // blank: a person can see what the columns will be
                  // before deciding what to type.
                  _HeaderRow(
                    columns: columns,
                    scale: effective,
                    // TRISTATE, and the middle state is the honest one:
                    // some of the visible rows are ticked, and neither
                    // "all" nor "none" says that.
                    allTicked:
                        visibleIds.isNotEmpty &&
                        visibleIds.every(selected.contains),
                    someTicked: visibleIds.any(selected.contains),
                    onSelectAll: onSelectAll,
                  ),
                  const Divider(height: 1, thickness: 1),
                  Expanded(
                    child: groups.isEmpty
                        ? _EmptyBody(
                            isFiltered: isFiltered,
                            totalDrops: totalDrops,
                          )
                        : CustomScrollView(
                            slivers: [
                              for (final group in groups) ...[
                                // PINNED, which is what "sticky group
                                // header" in §4 means: a person forty rows
                                // into the Exterior must still be able to
                                // see that these are the Exterior's.
                                SliverPersistentHeader(
                                  pinned: true,
                                  delegate: _BandDelegate(
                                    group: group,
                                    units: units,
                                    theme: Theme.of(context),
                                  ),
                                ),
                                SliverList.builder(
                                  itemCount: group.rows.length,
                                  itemBuilder: (context, index) => _DataRow(
                                    // KEYED ON THE LINK, so a `TextField`
                                    // and its controller follow the DROP
                                    // rather than the row position. A
                                    // filter change or a deletion
                                    // reshuffles the list, and an
                                    // unkeyed row would hand row 3's
                                    // controller to whatever cable is
                                    // third afterwards.
                                    key: ValueKey(group.rows[index].linkId),
                                    doc: doc,
                                    row: group.rows[index],
                                    columns: columns,
                                    scale: effective,
                                    onEdit: onEdit,
                                    onCaret: onCaret,
                                    ticked: selected.contains(
                                      group.rows[index].linkId,
                                    ),
                                    onSelect: onSelect,
                                  ),
                                ),
                              ],
                            ],
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

/// The strip that appears when rows are ticked (M3-L/3, DR-043 §11.42.6).
///
/// ═════════════════════════════════════════════════════════════════════
/// IT COUNTS WHAT IT WILL WRITE TO, AND SEPARATELY WHAT IT WILL NOT
/// ═════════════════════════════════════════════════════════════════════
/// "12 selected · 8 hidden by filter" rather than "20 selected". The
/// user settled this on 2026-08-11 and the reason is the one dangerous
/// outcome available on this surface: a batch that reached rows behind a
/// filter would look safe, would put a count on the undo stack matching
/// nothing on screen, and would surface weeks later on a printed sheet.
/// `_fillDown` already refuses to copy FROM a hidden row.
///
/// The hidden count is only drawn when it is non-zero, so the ordinary
/// case reads "12 selected" and carries no arithmetic nobody needs.
///
/// ═════════════════════════════════════════════════════════════════════
/// THE VALUE CONTROL FOLLOWS THE COLUMN'S MODEL TYPE
/// ═════════════════════════════════════════════════════════════════════
/// A dropdown where [structureCellChoices] gives a closed set, a text box
/// otherwise, which is exactly what the inline cell does and is the same
/// function answering. Two copies of that decision would disagree the
/// first time a column gained a value.
class _BatchBar extends StatefulWidget {
  const _BatchBar({
    required this.selectedVisible,
    required this.selectedHidden,
    required this.column,
    required this.columns,
    required this.onColumn,
    required this.onSet,
    required this.onClear,
  });

  final int selectedVisible;
  final int selectedHidden;
  final StructureColumnId? column;

  /// The batchable columns currently on screen. Filtered by
  /// `structureColumnIsBatchable`, so `FIELD LABEL` and `RACK LBL` are
  /// absent: CR-113 makes them unique, and a control whose only outcome
  /// on two or more rows is a refusal is a control that does nothing.
  final List<StructureColumnId> columns;
  final ValueChanged<StructureColumnId> onColumn;
  final ValueChanged<String> onSet;
  final VoidCallback onClear;

  @override
  State<_BatchBar> createState() => _BatchBarState();
}

class _BatchBarState extends State<_BatchBar> {
  final TextEditingController _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final column = widget.column;
    final choices = column == null ? null : structureCellChoices(column);
    return ColoredBox(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
        // A WRAP AND NOT A ROW. The bar carries two counts, a label, two
        // dropdowns and a button, and the second count only appears once
        // a filter hides part of the selection: a `Row` overflowed by
        // 154 px in exactly that state and would have shipped as a
        // yellow-and-black stripe on the one screen a person reaches
        // while doing something careful. A control strip has no reason to
        // insist on one line.
        child: Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              '${widget.selectedVisible} selected',
              style: theme.textTheme.labelLarge,
            ),
            if (widget.selectedHidden > 0)
              // NOT "N hidden by filter", WHICH IS ALREADY ON SCREEN.
              // The status bar carries that exact phrase for the table's
              // own hidden-row count, and two lines saying it with
              // different numbers is a person doing arithmetic to work
              // out which is which. Found by a test that matched the
              // wrong widget, which is the same collision a reader hits.
              Text(
                '${widget.selectedHidden} more ticked, off screen',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            Text(kBatchSetLabel, style: theme.textTheme.labelMedium),
            DropdownButton<StructureColumnId>(
              key: const ValueKey('batch-column'),
              value: column,
              hint: const Text('column'),
              items: [
                for (final id in widget.columns)
                  DropdownMenuItem(
                    value: id,
                    child: Text(structureColumnHeader(id)),
                  ),
              ],
              onChanged: (id) {
                if (id != null) widget.onColumn(id);
              },
            ),
            if (column != null)
              if (choices != null)
                // NO APPLY BUTTON ON A DROPDOWN. Picking the value IS the
                // gesture, the way an inline `_ChoiceCell` commits on
                // selection; a second click to confirm would make the
                // batch path slower per value than the cell it replaces.
                DropdownButton<String>(
                  key: const ValueKey('batch-value'),
                  hint: const Text('value'),
                  items: [
                    for (final label in choices)
                      DropdownMenuItem(value: label, child: Text(label)),
                  ],
                  onChanged: (v) {
                    if (v != null) widget.onSet(v);
                  },
                )
              else
                SizedBox(
                  width: 180,
                  child: TextField(
                    key: const ValueKey('batch-value-text'),
                    controller: _text,
                    decoration: const InputDecoration(
                      isDense: true,
                      hintText: 'value, then Enter',
                    ),
                    onSubmitted: widget.onSet,
                  ),
                ),
            // NO `Spacer`: `Wrap` has no free axis to expand into, and a
            // `Spacer` inside one throws at layout time rather than
            // being ignored.
            TextButton(
              key: const ValueKey('batch-clear'),
              onPressed: widget.onClear,
              child: const Text(kClearSelectionLabel),
            ),
          ],
        ),
      ),
    );
  }
}

/// The select gutter's width, in the same points the columns are authored
/// in (docs/07 §4 draws it as `⠿☐` before `FIELD LABEL`).
///
/// FIXED CHROME AND NOT A COLUMN. It carries no data, has no header text,
/// and is not in `StructureColumnId`, which is the same class of width as
/// `rack_geometry.dart`'s RU ruler: an annotation gutter outside the
/// thing being measured.
const double kSelectGutterWidth = 34;

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({
    required this.columns,
    required this.scale,
    required this.allTicked,
    required this.someTicked,
    required this.onSelectAll,
  });

  final List<StructureColumnId> columns;
  final double scale;
  final bool allTicked;
  final bool someTicked;
  final ValueChanged<bool> onSelectAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          SizedBox(
            width: kSelectGutterWidth * scale,
            child: Checkbox(
              key: const ValueKey('select-all'),
              value: allTicked ? true : (someTicked ? null : false),
              tristate: true,
              // TICKING FROM THE MIDDLE STATE SELECTS, it does not clear.
              // Somebody who has ticked four of forty and then reaches
              // for the header wants the other thirty-six, which is the
              // same reasoning `_FilterBar`'s as-built group already
              // uses for a half-on set.
              onChanged: (v) => onSelectAll(!allTicked),
            ),
          ),
          for (final id in columns)
            SizedBox(
              width: structureColumnWidth(id) * scale,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  structureColumnHeader(id),
                  textAlign: _align(structureColumnAlign(id)),
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

TextAlign _align(ScheduleAlign align) => switch (align) {
  ScheduleAlign.left => TextAlign.left,
  ScheduleAlign.right => TextAlign.right,
  ScheduleAlign.centre => TextAlign.center,
};

/// §4's `▾ LIVING ROOM (LR) · est. run 62 ft   9 drops · 6 connected`.
class _BandDelegate extends SliverPersistentHeaderDelegate {
  _BandDelegate({
    required this.group,
    required this.units,
    required this.theme,
  });

  final StructureTableGroup group;
  final UnitSystem units;
  final ThemeData theme;

  static const double _height = 28;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) {
    final scheme = theme.colorScheme;
    // The no-room band is toned apart from a room's, for
    // `_BandRow`'s reason on the Schedule: it is not a place, and a
    // reader skimming for rooms must not mistake it for one.
    final isUngrouped = group.locationId == null;
    final background = isUngrouped
        ? scheme.errorContainer
        : scheme.surfaceContainerHigh;
    final foreground = isUngrouped ? scheme.onErrorContainer : scheme.onSurface;
    return ColoredBox(
      color: background,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _title(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              '${group.dropCount} drops · ${group.connectedCount} connected',
              style: theme.textTheme.labelSmall?.copyWith(color: foreground),
            ),
          ],
        ),
      ),
    );
  }

  /// `LIVING ROOM (LR) · est. run 62 ft`.
  ///
  /// The estimate is OMITTED when unknown rather than printed as a dash
  /// with a unit, because `est. run — ft` in a band header reads as a
  /// broken template. The DASH still appears where it matters, in the
  /// length columns, where a reader is comparing a column of numbers.
  String _title() {
    final name = group.title.toUpperCase();
    final head = group.code.isEmpty ? name : '$name (${group.code})';
    final estimate = group.estimatedRunLength;
    if (estimate == null) return head;
    final suffix = units == UnitSystem.imperial ? 'ft' : 'm';
    return '$head · est. run ${scheduleLengthCell(estimate, units)} $suffix';
  }

  @override
  bool shouldRebuild(_BandDelegate old) =>
      old.group != group || old.units != units || old.theme != theme;
}

/// The closed set of labels a column accepts, or null when the column
/// takes free text.
///
/// ONE ANSWER FOR TWO CONSUMERS (M3-L/3). The inline cell and the batch
/// bar both need "what may this column be set to", and two copies of this
/// switch would disagree the first time a column gained a value. It was
/// inline in `_DataRow._cell` until the batch bar needed it.
///
/// WHICH COLUMNS ARE CLOSED FOLLOWS THE MODEL TYPE rather than a
/// preference: these three store an enum, so there is nothing to parse
/// and nothing to typo. The text columns beside them store strings and
/// numbers, and their parsing lives in core.
///
/// THE LABELS ARE CORE'S SPELLING, never `.name`. The surface sends what
/// it DISPLAYED, so core stays the only speller: `directBury` already
/// prints `DIRECT BURY`, so a `.name` match is a bug waiting for the
/// second time a label stops being the enum name uppercased.
List<String>? structureCellChoices(StructureColumnId id) => switch (id) {
  StructureColumnId.roughIn => RoughInStatus.values.map(roughInLabel).toList(),
  StructureColumnId.testResult => kTestCellOptions,
  // UNKNOWN IS AN OPTION HERE and is not on `ROUGH-IN`, which is the
  // difference G4 draws between them: `planned` is a real state of an
  // untouched drop, where "nobody has decided how this end is finished"
  // is genuinely an absence (M3-J/1 made the field nullable for exactly
  // that).
  StructureColumnId.fieldTerm => <String>[
    kUnknownCell,
    ...TerminationType.values.map(terminationLabel),
  ],
  _ => null,
};

class _DataRow extends StatelessWidget {
  const _DataRow({
    required this.doc,
    required this.row,
    required this.columns,
    required this.scale,
    required this.onEdit,
    required this.onCaret,
    required this.ticked,
    required this.onSelect,
    super.key,
  });

  final RackDocument doc;
  final ScheduleEntry row;
  final List<StructureColumnId> columns;
  final double scale;
  final String? Function(List<StructureCellEdit> edits) onEdit;
  final ValueChanged<(Uuid, StructureColumnId)?> onCaret;
  final bool ticked;
  final void Function(Uuid linkId, {required bool ticked}) onSelect;

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
            SizedBox(
              width: kSelectGutterWidth * scale,
              child: Checkbox(
                // KEYED ON THE LINK, like the row itself: a filter change
                // reshuffles the list and a positional key would hand
                // row 3's tick to whatever cable is third afterwards.
                key: ValueKey('select-${row.linkId.v}'),
                value: ticked,
                onChanged: (v) => onSelect(row.linkId, ticked: v ?? false),
              ),
            ),
            for (final id in columns)
              SizedBox(
                width: structureColumnWidth(id) * scale,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: _cell(theme, id, units),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _cell(ThemeData theme, StructureColumnId id, UnitSystem units) {
    final text = structureCell(doc, row, id, units: units);
    // ═══════════════════════════════════════════════════════════════════
    // AN EDITABLE CELL IS ALWAYS AN INPUT, NEVER A LABEL THAT BECOMES ONE
    // ═══════════════════════════════════════════════════════════════════
    // §4.1: "inline editing is the primary path, a cell is one click and
    // a keystroke". Click-to-edit costs a click before the keystroke and
    // it costs the TAB ORDER, which is the half #148's brief names: a
    // widget that only exists once clicked is not in the focus tree, so
    // `Tab` cannot reach it. Rendering the real control always makes tab
    // order the widget order, and that is why this file adds NO key
    // binding for it — Flutter's own traversal already does the work, and
    // an unnecessary `kKeymap` row would be a real cost (D7, M7's
    // generated table, `arbitrate()` on every platform).
    if (structureColumnIsEditable(id)) {
      // THE CLOSED-SET COLUMNS GET A DROPDOWN AND THE REST GET A BOX, and
      // which is which follows the MODEL TYPE rather than a preference:
      // three of these store an enum, so there is nothing to parse and
      // nothing to typo. The text columns beside them store strings and
      // numbers, and their parsing lives in core.
      final options = structureCellChoices(id);
      if (options != null) {
        return _ChoiceCell(
          linkId: row.linkId,
          column: id,
          value: text,
          options: options,
          onEdit: onEdit,
          onCaret: onCaret,
        );
      }
      return _TextCell(
        linkId: row.linkId,
        column: id,
        onCaret: onCaret,
        // THE DASH IS NOT PUT IN THE BOX. `—` is what an unknown PRINTS,
        // and a text field showing it would make a person delete a
        // character that was never theirs — worse, typing after it would
        // save `—PP1-01`. An empty box is what "nobody has said" looks
        // like when it is editable, and the hint says so.
        value: text == kUnknownCell ? '' : text,
        bold: id == StructureColumnId.fieldLabel,
        onEdit: onEdit,
      );
    }
    final isUnknown = text == kUnknownCell;
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: _align(structureColumnAlign(id)),
      style: theme.textTheme.bodySmall?.copyWith(
        color: isUnknown
            ? theme.colorScheme.onSurfaceVariant
            : theme.colorScheme.onSurface,
      ),
    );
  }
}

/// One typed cell.
///
/// IT COMMITS ON `Enter` AND ON LOSING FOCUS, and those are the same two
/// moments the device builder's inspector commits on. Losing focus is the
/// one that matters for `Tab`: a person filling a column types, tabs,
/// types, tabs, and never presses `Enter` at all.
///
/// A REFUSED EDIT PUTS THE STORED VALUE BACK. The batch was rejected
/// whole, so the cell showing the typed text would be showing something
/// no document holds. The sentence goes to the status bar, where it stays
/// until the next edit rather than fading.
class _TextCell extends StatefulWidget {
  const _TextCell({
    required this.linkId,
    required this.column,
    required this.value,
    required this.bold,
    required this.onEdit,
    required this.onCaret,
  });

  final Uuid linkId;
  final StructureColumnId column;
  final String value;
  final bool bold;
  final String? Function(List<StructureCellEdit> edits) onEdit;
  final ValueChanged<(Uuid, StructureColumnId)?> onCaret;

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
    // THE DOCUMENT WINS, EXCEPT WHILE SOMEBODY IS TYPING IN THIS BOX.
    // A fill-down, an undo or a paste changes the stored value under a
    // cell that is not focused, and the cell must follow. Overwriting a
    // FOCUSED cell would delete what the person is halfway through
    // typing, which is the classic controlled-input defect.
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
    if (_focus.hasFocus) {
      widget.onCaret((widget.linkId, widget.column));
      return;
    }
    // NOT NULLED ON BLUR. `Ctrl+D` and `Ctrl+V` are dispatched while this
    // field still has focus, so nulling here would be harmless; what it
    // would break is the moment focus moves to the SHORTCUT handler in
    // some future Flutter, leaving the grid with no idea where it was.
    // The caret is replaced by the next cell that takes focus.
    _commit();
  }

  void _commit() {
    if (_text.text == widget.value) return;
    final refusal = widget.onEdit([
      StructureCellEdit(
        linkId: widget.linkId,
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
        fontWeight: widget.bold ? FontWeight.w700 : FontWeight.w400,
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

/// `ROUGH-IN` as the five-value enum it is.
///
/// A DROPDOWN AND NOT A TEXT BOX, because the model type is an enum and
/// there is nothing to parse: five values, all of them legal, none of
/// them typo-able. The text columns beside it are text because their
/// model type is a string.
/// A cell whose column has a closed set of answers.
///
/// ONE WIDGET FOR FOUR COLUMNS. `ROUGH-IN` was the first; M3-J/3 adds
/// `FIELD TERM` and `TEST`, which differ only in their option list and in
/// whether "nobody has said" is one of the options. Writing a class per
/// enum would have put the caret reporting, the label vocabulary and the
/// `onEdit` shape in three places to keep in step.
///
/// THE OPTIONS AND THE VALUE ARE BOTH LABELS, not enum values, for the
/// reason `StructureCellEdit.value` is text: the label is what crosses
/// the boundary, so core's own speller stays the only one.
class _ChoiceCell extends StatelessWidget {
  const _ChoiceCell({
    required this.linkId,
    required this.column,
    required this.value,
    required this.options,
    required this.onEdit,
    required this.onCaret,
  });

  final Uuid linkId;
  final StructureColumnId column;

  /// The label showing now. [kUnknownCell] when nothing is recorded, and
  /// it must then also be in [options] or the dropdown has no value.
  final String value;

  /// Every label this column accepts, in the order a person reads them.
  final List<String> options;

  final String? Function(List<StructureCellEdit> edits) onEdit;
  final ValueChanged<(Uuid, StructureColumnId)?> onCaret;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // IT REPORTS THE CARET LIKE ANY OTHER CELL, through a `Focus` rather
    // than through `onTap`, so it is reported by TABBING to it as well as
    // by clicking. These are the columns where fill-down earns its
    // keystroke: "everything from here down is pulled" is the gesture a
    // person makes walking a job, and a status is legal to repeat where a
    // label is not.
    return Focus(
      onFocusChange: (has) {
        if (has) onCaret((linkId, column));
      },
      child: DropdownButton<String>(
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
            StructureCellEdit(linkId: linkId, column: column, value: next),
          ]);
        },
      ),
    );
  }
}

/// What the `⚙ Columns` menu calls the as-built group.
const String kAsBuiltColumnsLabel = 'As-built columns';

/// The labels a `TEST` cell offers, unknown first.
///
/// THREE, NOT TWO. Clearing it back to [kUnknownCell] is a legal edit and
/// means NOT TESTED, which is not a failure (G4). A two-option control
/// would make "we have not been back yet" unsayable once somebody had
/// answered once.
const List<String> kTestCellOptions = <String>[
  kUnknownCell,
  kTestPassCell,
  kTestFailCell,
];

/// Why `Set` on the batch bar did nothing (M3-L/3).
///
/// Reachable only when every ticked row is behind a filter, which is a
/// state a person can get into by ticking rows and then narrowing the
/// view. The bar already says "0 selected, 12 hidden by filter" in that
/// case, and this is the belt to that pair of braces: a button that
/// declined without saying why is indistinguishable from a broken one
/// (docs/04 §3.4).
const String kNothingSelectedToSet =
    'Every ticked row is hidden by the current filter, so there is nothing '
    'on screen to set. Clear the filter, or tick rows you can see.';

/// The batch bar's own label, so the test and the widget agree.
const String kBatchSetLabel = 'Set';

/// See [kBatchSetLabel].
const String kClearSelectionLabel = 'Clear selection';

/// Why `Ctrl+D` did nothing.
///
/// EVERY ONE OF THESE FOUR NAMES A CAUSE, because docs/04 §3.4's rule is
/// that a surface never silently does nothing, and a grid operation that
/// declined without saying why is indistinguishable from a key that is
/// not bound.
const String kNoCaretForFill =
    'Put the caret in a cell first: Ctrl+D fills it from the row above.';

/// The focused cell is the first row on screen.
const String kNothingAboveToFill =
    'This is the first row, so there is nothing above it to fill from.';

/// Why `Ctrl+V` did nothing.
const String kNoCaretForPaste =
    'Put the caret in a cell first: paste starts from there.';

/// The clipboard is taller than the table below the caret.
String kPasteOverruns(int lines, int available) =>
    'That is $lines rows and there are $available below the caret. Pasting '
    'does not create drops: add them first, then paste.';

/// The clipboard is wider than the columns to the right of the caret.
const String kPasteOverrunsColumns =
    'That is wider than the columns to the right of the caret.';

/// `Ctrl+D` or `Ctrl+V` on the matrix tab.
///
/// A SENTENCE RATHER THAN SILENCE, and rather than a matrix
/// implementation nobody asked for. Filling a COUNT down a room column
/// would be a legible gesture, but "eight rooms all get four Cat6" makes
/// 32 cables and an outlet each from one keystroke, and that is a ruling
/// rather than an afternoon.
const String kGridKeysAreTableOnly =
    'Ctrl+D and Ctrl+V work on the table, not the matrix.';

/// What the first line of the no-drops state says.
const String kNoDropsHeadline = 'This Structure body has no drops yet.';

/// And where they come from. NAMES THE SURFACE THAT IS ON SCREEN, which
/// is the lesson `unbuilt_copy_accuracy_test.dart` was written for: the
/// Schedule tab once told its reader to go and use a tab that could not
/// create a cable.
const String kNoDropsDetail =
    'Type a room and what it needs into the field above, then press Enter: '
    '"Living Room: 4x Cat6, 2x RG6". Each line becomes drops with their '
    'field and rack labels already allocated.';

/// What it says when the filters hid everything.
const String kAllDropsFilteredHeadline =
    'Every drop on this body is hidden by the current filter.';

class _EmptyBody extends StatelessWidget {
  const _EmptyBody({required this.isFiltered, required this.totalDrops});

  final bool isFiltered;
  final int totalDrops;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // TWO EMPTY STATES WITH DIFFERENT CAUSES AND DIFFERENT ANSWERS, the
    // distinction `_EmptyBody` on the Schedule already draws: "there are
    // none" is about the document, "they are all hidden" is about a
    // control the reader can reach.
    final filteredOut = isFiltered && totalDrops > 0;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                filteredOut ? kAllDropsFilteredHeadline : kNoDropsHeadline,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Text(
                filteredOut
                    ? 'All $totalDrops of them are excluded by the room, '
                          'media or connection filter above.'
                    : kNoDropsDetail,
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

/// §4's bottom strip: the counts, then the two buttons that do something.
class _StatusBar extends StatelessWidget {
  const _StatusBar({
    required this.table,
    required this.refusal,
    required this.hidden,
    required this.onAddDrop,
    required this.onAddOutlet,
  });

  final StructureTable table;
  final String? refusal;
  final int hidden;
  final VoidCallback? onAddDrop;
  final VoidCallback onAddOutlet;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // THE REFUSAL SITS ABOVE THE COUNTS AND STAYS THERE. A refused
        // edit has already put the old value back in the cell, so without
        // this line the only visible effect is that somebody's typing
        // disappeared.
        if (refusal case final sentence?)
          ColoredBox(
            color: scheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
              child: Text(
                sentence,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onErrorContainer,
                ),
              ),
            ),
          ),
        Padding(
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
              if (onAddDrop != null)
                TextButton(onPressed: onAddDrop, child: const Text('Add drop')),
              TextButton(
                onPressed: onAddOutlet,
                child: const Text('Add outlet'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// `52 drops · 41 connected · 11 spare · 9 outlets · 8 pathways`.
  ///
  /// THE COUNTS ARE THE TABLE'S AND NOT THE FILTERED VIEW'S, and what
  /// the filter hides is stated separately. A status bar that counted
  /// only what was on screen would let somebody read "6 drops" off a
  /// screen filtered to one media type and order cable for the house.
  ///
  /// `hasUnresolvedEnds` is REPORTED rather than smoothed over: it means
  /// a `PortEndpoint` names a port this document does not hold, so
  /// connected plus spare does not equal drops (G4 — every rollup
  /// reports what it could not resolve).
  String _summary() {
    final parts = <String>[
      '${table.dropCount} drops',
      '${table.connectedCount} connected',
      '${table.spareCount} spare',
      '${table.outletCount} outlets',
      '${table.pathwayCount} pathways',
      if (hidden > 0) '$hidden hidden by filter',
      if (table.hasUnresolvedEnds) _unresolvedNote(),
    ];
    return parts.join(' · ');
  }

  String _unresolvedNote() {
    final count = table.dropCount - table.connectedCount - table.spareCount;
    return '▲ $count land on a port this project does not hold';
  }
}
