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
//   * NO TAB STRIP. §4 draws `[▶ Table] [ Matrix ] [ Outlets ]
//     [ Pathways ]`. The matrix is board #149 and the other two are
//     later still; a strip whose three other tabs open nothing is the
//     `UnbuiltView` defect wearing a different hat. AC-048's requirement
//     is that the editor OPENS IN TABLE MODE, which one surface satisfies
//     outright. #149 adds the strip when there is a second thing to
//     switch to.
//   * NO `[Group into pathway]`, `[Renumber…]`, `[Import CSV…]` or
//     `[Export CSV]` in the button bar. Renumber is M3-F, CSV is docs/07
//     §5 and unbuilt, and grouping into a pathway has no command yet.
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
import 'package:flutter/material.dart';
import 'package:rackmate_core/rackmate_core.dart';
import 'package:rackmate_ui/src/structure/drop_entry_panel.dart';

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
  });

  /// M3-C/1's loop, unchanged. See `DropEntryActions.onCommit` for why
  /// the parsed LINE crosses this boundary and never the preview's
  /// commands.
  final DropEntryActions dropEntry;

  /// Opens M3-C/5's outlet-template picker.
  final VoidCallback onAddOutlet;

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
}

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

  /// Which body to show, or every one of them when null (§7 allows more
  /// than one Structure device).
  final Uuid? structureBodyId;

  /// Null when the editor is not in a route it can pop — the state a
  /// widget test drives it in.
  final VoidCallback? onDone;

  @override
  State<StructureEditorScreen> createState() => _StructureEditorScreenState();
}

class _StructureEditorScreenState extends State<StructureEditorScreen> {
  final Set<StructureColumnId> _optional = <StructureColumnId>{};

  Uuid? _roomFilter;
  MediaTypeId? _mediaFilter;
  bool _unconnectedOnly = false;

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
    final table = buildStructureTable(
      doc,
      structureBodyId: widget.structureBodyId,
    );
    final visible = _filter(doc, table);

    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _EditorHeader(
            doc: doc,
            structureBodyId: widget.structureBodyId,
            table: table,
            onDone: widget.onDone,
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
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                        child: DropEntryLoop(
                          actions: _loopActions(),
                          currentDoc: widget.currentDoc,
                        ),
                      ),
                      _FilterBar(
                        doc: doc,
                        table: table,
                        roomFilter: _roomFilter,
                        mediaFilter: _mediaFilter,
                        unconnectedOnly: _unconnectedOnly,
                        optional: _optional,
                        onRoom: (v) => setState(() => _roomFilter = v),
                        onMedia: (v) => setState(() => _mediaFilter = v),
                        onUnconnected: (v) =>
                            setState(() => _unconnectedOnly = v),
                        onToggleColumn: (id) => setState(() {
                          if (!_optional.remove(id)) _optional.add(id);
                        }),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: _DropTable(
                          doc: doc,
                          groups: visible,
                          columns: _columns,
                          onEdit: _edit,
                          isFiltered:
                              _roomFilter != null ||
                              _mediaFilter != null ||
                              _unconnectedOnly,
                          totalDrops: table.dropCount,
                        ),
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
            hidden: table.dropCount - _shownCount(visible),
            onAddDrop: null,
            onAddOutlet: widget.actions.onAddOutlet,
          ),
        ],
      ),
    );
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
    onCommit: (line) {
      final committed = widget.actions.dropEntry.onCommit(line);
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
  });

  final RackDocument doc;
  final Uuid? structureBodyId;
  final StructureTable table;
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final body = structureBodyId == null
        ? (doc.structures.length == 1 ? doc.structures.values.first : null)
        : doc.structures[structureBodyId];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      child: Row(
        children: [
          Text('Structure', style: theme.textTheme.titleMedium),
          const SizedBox(width: 12),
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
    return '${doc.structures.length} Structure devices';
  }
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
            const SizedBox(width: 8),
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
  });

  final RackDocument doc;
  final List<StructureTableGroup> groups;
  final List<StructureColumnId> columns;
  final bool isFiltered;
  final int totalDrops;
  final String? Function(List<StructureCellEdit> edits) onEdit;

  @override
  Widget build(BuildContext context) {
    final units = doc.settings.displayUnits;
    final totalPt = columns.fold<double>(
      0,
      (n, c) => n + structureColumnWidth(c),
    );
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
                  _HeaderRow(columns: columns, scale: effective),
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

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.columns, required this.scale});

  final List<StructureColumnId> columns;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
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

class _DataRow extends StatelessWidget {
  const _DataRow({
    required this.doc,
    required this.row,
    required this.columns,
    required this.scale,
    required this.onEdit,
    super.key,
  });

  final RackDocument doc;
  final ScheduleEntry row;
  final List<StructureColumnId> columns;
  final double scale;
  final String? Function(List<StructureCellEdit> edits) onEdit;

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
      if (id == StructureColumnId.roughIn) {
        return _RoughInCell(
          linkId: row.linkId,
          value: row.roughInStatus,
          onEdit: onEdit,
        );
      }
      return _TextCell(
        linkId: row.linkId,
        column: id,
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
  });

  final Uuid linkId;
  final StructureColumnId column;
  final String value;
  final bool bold;
  final String? Function(List<StructureCellEdit> edits) onEdit;

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
    if (!_focus.hasFocus) _commit();
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
class _RoughInCell extends StatelessWidget {
  const _RoughInCell({
    required this.linkId,
    required this.value,
    required this.onEdit,
  });

  final Uuid linkId;
  final RoughInStatus value;
  final String? Function(List<StructureCellEdit> edits) onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DropdownButton<RoughInStatus>(
      value: value,
      isDense: true,
      isExpanded: true,
      underline: const SizedBox.shrink(),
      style: theme.textTheme.bodySmall,
      items: [
        for (final status in RoughInStatus.values)
          DropdownMenuItem<RoughInStatus>(
            value: status,
            child: Text(roughInLabel(status)),
          ),
      ],
      onChanged: (next) {
        if (next == null || next == value) return;
        onEdit([
          StructureCellEdit(
            linkId: linkId,
            column: StructureColumnId.roughIn,
            // The label, not `.name`, so one vocabulary crosses this
            // boundary and `roughInLabel` stays the only speller.
            value: roughInLabel(next),
          ),
        ]);
      },
    );
  }
}

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
