// The project's location tree, in two panes the `Site` view composes.
//
// It was `Project ▸ Locations…`, then a tab of its own, and since `#893`
// it is one region of the merged view (DR-168). The file keeps its name
// because the two panes and the actions record are what it always held.
// Board M3-B/2, CR-047, CR-112, DR-021.
//
// ═══════════════════════════════════════════════════════════════════════
// IN `src/project/`, NOT IN `src/inspector/`, AND THAT IS THE RULING
// ═══════════════════════════════════════════════════════════════════════
// CR-112 exists to say this tree is NOT owned by the Structure editor, and
// docs/04 §7.5 says it is not owned by the rack editor either: *"a project
// with racks and no Structure device must still be able to say which room
// a rack is in"*. Filing it beside the rack inspector's dialogs would put
// the ruling's own counterexample in the directory name. docs/07 §107 has
// the Structure editor showing this tree READ-ONLY with an "edit in
// Site tab" affordance, which only means anything if there
// is somewhere else for it to live.
//
// ═══════════════════════════════════════════════════════════════════════
// NEVER A FIXED FLOOR / ROOM / WALL HIERARCHY
// ═══════════════════════════════════════════════════════════════════════
// The board task's own words, and CR-047's: one arbitrary-depth tree, of
// which the device builder's four levels and the rack editor's flat
// combobox are VIEWS. So this panel:
//
//   * indents by [LocationTree.depthOf] and by nothing else. There is no
//     maximum depth, no per-level widget, and no level names;
//   * offers `kind` as a plain six-value dropdown on the selected node,
//     with no effect on where the node may sit. A `site` under a `zone` is
//     legal and the panel does not blink;
//   * puts a new node under whatever is selected, so depth is produced by
//     the user's gesture rather than by a rule this file knows.
//
// A UI that hard-codes depth is the ruling being overturned by a widget,
// which is why `locations_panel_test` asserts a five-deep chain renders and
// nests rather than asserting a shape.
//
// ═══════════════════════════════════════════════════════════════════════
// A DOCUMENT THAT IS NOT A TREE STILL RENDERS
// ═══════════════════════════════════════════════════════════════════════
// `LocationTree` reports `detached` (parent not in the document) and
// `cyclic` (parent chain loops) and makes both roots rather than dropping
// them. This panel SHOWS them, flagged. A `.rppj` is hand-editable text
// (DR-015) and the user cannot fix a room they cannot see; a panel that
// quietly listed four of five rooms would be the worst possible response
// to a file that needs repair.
//
// ═══════════════════════════════════════════════════════════════════════
// EVERY EDIT IS A COMMAND, AND THIS FILE RUNS NONE OF THEM
// ═══════════════════════════════════════════════════════════════════════
// The panel takes the document and callbacks, the shape
// `RackInspectorPanel` already uses, so `rackpal_ui` stays free of the
// controller and the app decides what an edit means. `onRefuse` is how
// DR-021 §11.20.5's cycle sentence reaches a user: the builder in core
// produces the sentence, the app surfaces it, and this file only has to
// not swallow it.
import 'package:flutter/material.dart';
import 'package:rackpal_core/rackpal_core.dart';

/// What the panel can ask the application to do.
///
/// One object rather than six loose callbacks, because every one of them
/// is "run a command against the live document" and a panel that took them
/// separately would let a caller wire five and forget the sixth.
@immutable
class LocationsPanelActions {
  const LocationsPanelActions({
    required this.onAdd,
    required this.onRename,
    required this.onSetCode,
    required this.onSetKind,
    required this.onSetFloorNumber,
    required this.onSetSpaceCode,
    required this.onSetEstimatedRunLength,
    required this.onReparent,
    required this.onDelete,
    required this.onRefuse,
  });

  /// Creates a location under `parentId`, or at the top level when null.
  /// Returns the new node's id so the panel can select it: a create that
  /// left the selection where it was would make the second of two new
  /// rooms land under the first one's parent by surprise.
  final Uuid Function(Uuid? parentId) onAdd;

  /// THREE TYPED CALLBACKS, NOT ONE GENERIC ONE, and the reason is a
  /// runtime failure rather than taste: `LocationField.all` is typed
  /// `EntityField<Location, Object?>`, and `set_entity_property_command`
  /// says out loud that the erased element type is READ-ONLY. A single
  /// `onEdit(field, value)` would compile and throw the first time it ran,
  /// because the closure really is `(Location, String) => void`.
  ///
  /// The first three fields are the three CR-047 and CR-046 are about.
  ///
  /// `floorNumber` AND `spaceCode` JOINED THEM AT DR-040 §11.39.4, and the
  /// reason they were absent had expired. They were left out beside
  /// `estimatedRunLengthFromRack` because that third field is AC-024's
  /// number and belonged with M3-D; the two identifiers were never M3-D's,
  /// and their absence made **three of the four tokens in the shipped rack
  /// label preset unreachable**, so `{FLOOR}{SPACE}-{PANEL}{PORT:2}` could
  /// not render on any document this product had ever written.
  ///
  /// **`estimatedRunLengthFromRack` GOT ITS EDITOR AT `LEN-A/5`**, and
  /// this paragraph said it had none since M3-D. It was the only one of
  /// AC-024's three numbers a person could not enter anywhere, which
  /// `LEN-A/3` ran into from the other side: a derivation proposing a
  /// figure had no surface to propose it into and no control to be
  /// compared against.
  final void Function(Uuid id, String name) onRename;
  final void Function(Uuid id, String code) onSetCode;
  final void Function(Uuid id, LocationKind kind) onSetKind;

  /// A storey, or null for unknown. The panel hands over an already-parsed
  /// value: `parseFloorCell` refuses in core, on `structure_edit_actions`'
  /// rule that EVERY parse is core's and a surface holding a second copy of
  /// one is how two answers to one question start.
  final void Function(Uuid id, int? floorNumber) onSetFloorNumber;

  /// A space code, or null for unknown. An empty box lands as null and
  /// never as `''`, which is `LinkField.notes`' stated rule: `''` is a
  /// third state every reader downstream would have to guess about.
  final void Function(Uuid id, String? spaceCode) onSetSpaceCode;

  /// AC-024's ONE number per room, and the third of the three CR-047 and
  /// CR-046 are about (DR-050, `LEN-A/5`).
  ///
  /// ALREADY PARSED, on `onSetFloorNumber`'s rule: the panel runs
  /// `parseLengthCell` and hands over a `Len?`, because a row cannot
  /// refuse and does not transform.
  ///
  /// **THE MARKER MOVES WITH IT AND IS NOT A SECOND PARAMETER.** A value
  /// arriving here was typed by a person, which is the only provenance
  /// this surface can report; `SetRoomEstimateCommand.typed` is what the
  /// host runs, and `LEN-A/6`'s auto-fill uses `computed` from somewhere
  /// else entirely (DR-050 §11.49.3).
  final void Function(Uuid id, Len? length) onSetEstimatedRunLength;

  /// Moves `id` under `newParentId`, or to the top level when null.
  /// Returns a refusal sentence, or null when it went through.
  final String? Function(Uuid id, Uuid? newParentId) onReparent;

  /// Deletes `id` and its subtree AFTER confirming. Returns whether it
  /// happened, so a cancelled confirmation does not clear the selection.
  final Future<bool> Function(Uuid id) onDelete;

  /// Surfaces a refusal sentence produced by core.
  final void Function(String reason) onRefuse;
}

// ═══════════════════════════════════════════════════════════════════════
// `LocationsPanel` AND `showLocationsPanel` ARE GONE (`#893`, DR-168)
// ═══════════════════════════════════════════════════════════════════════
// The composite panel was a whole view: a header, a 320px tree column, a
// detail pane and a footer. Its two panes are below, and the `Site` view
// composes them at its own proportions with the plan canvas between.
//
// **THE MODAL HAD NO CALLER AND HAD NOT FOR SOME TIME.**
// `showLocationsPanel` was the route CR-112's ellipsis promised, in
// `Project ▸ Locations…`; DR-091 §11.90 promoted Locations to a tab and
// deleted that menu, and the function stayed behind with no caller in
// `lib/` and none in any test. Three on-screen strings still name the
// menu (`#888`), which is the shape a dead route leaves when only the
// code is removed.

/// The location tree, as a list somebody can select a row of (`#891`,
/// DR-168 §11.167.4).
///
/// ═══════════════════════════════════════════════════════════════════════
/// EXTRACTED SO TWO HOSTS CAN SHOW IT, NOT SO IT COULD BE REUSED
/// ═══════════════════════════════════════════════════════════════════════
/// `LocationsPanel` put this in a 320px column beside a detail pane, which
/// is a whole view. The `Site` view needs the same list in a RAIL, with
/// the detail somewhere else entirely and the plan canvas between them, so
/// the tree and the detail had to stop being one widget's private layout.
///
/// **IT OWNS NO SELECTION.** Both hosts hold the selected id, because in
/// the `Site` view the tree is in one region and what it selects is drawn
/// in another; a selection private to this widget could not reach across
/// that gap and would have to be mirrored, which is two answers to one
/// question.
class LocationTreeList extends StatelessWidget {
  const LocationTreeList({
    required this.doc,
    required this.selectedId,
    required this.onSelect,
    super.key,
  });

  final RackDocument doc;
  final Uuid? selectedId;
  final ValueChanged<Uuid> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tree = LocationTree.of(doc);
    final nodes = tree.preOrder;
    if (nodes.isEmpty) return _EmptyTree(theme: theme);
    return ListView.builder(
      itemCount: nodes.length,
      itemBuilder: (context, i) => _TreeRow(
        key: ValueKey(nodes[i].v),
        location: doc.locations[nodes[i]]!,
        depth: tree.depthOf(nodes[i]),
        selected: nodes[i] == selectedId,
        fault: _faultOf(tree, nodes[i]),
        onTap: () => onSelect(nodes[i]),
      ),
    );
  }
}

/// The selected room's fields, or the sentence that says none is selected.
///
/// **THE NULL CASE IS INSIDE, not left to each host.** Two hosts now draw
/// this and both have to answer "nothing selected"; answering it here is
/// one sentence in one place rather than two that can come to differ about
/// what an empty selection looks like.
class LocationDetailPane extends StatelessWidget {
  const LocationDetailPane({
    required this.location,
    required this.doc,
    required this.actions,
    required this.onEdit,
    required this.onReparent,
    required this.onDelete,
    super.key,
  });

  final Location? location;
  final RackDocument doc;
  final LocationsPanelActions actions;
  final void Function(VoidCallback edit) onEdit;
  final void Function(Uuid id, Uuid? newParentId) onReparent;
  final Future<void> Function(Uuid id) onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final here = location;
    if (here == null) return _NoSelection(theme: theme);
    return _Detail(
      location: here,
      doc: doc,
      tree: LocationTree.of(doc),
      actions: actions,
      onEdit: onEdit,
      onReparent: onReparent,
      onDelete: onDelete,
    );
  }
}

/// The one-word marker a malformed node carries, or null when it is sound.
String? _faultOf(LocationTree tree, Uuid id) {
  if (tree.cyclic.contains(id)) return 'LOOPS';
  if (tree.detached.contains(id)) return 'ORPHANED';
  return null;
}

String _displayName(Location? location) {
  final name = location?.name.trim() ?? '';
  return name.isEmpty ? kUnnamedLocation : name;
}

/// The empty state. GUIDANCE ONLY, with no button of its own: the footer
/// already carries `New location`, and a second button reading the same
/// words is two things to aim at for one action. It also made the panel's
/// own test ambiguous, which is the cheap version of the same complaint.
class _EmptyTree extends StatelessWidget {
  const _EmptyTree({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'No locations yet.',
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            // Says what a location is FOR, not what the tree is. A user
            // who opened this panel already knows it is empty.
            'Rooms name where cable goes. The Pull Sheet sorts by them.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

class _NoSelection extends StatelessWidget {
  const _NoSelection({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) => Center(
    child: Text(
      'Select a location.',
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    ),
  );
}

/// One row of the tree.
///
/// INDENTED BY DEPTH AND BY NOTHING ELSE. There is no per-level widget and
/// no level name, because CR-047 rules a tree rather than four levels.
class _TreeRow extends StatelessWidget {
  const _TreeRow({
    required this.location,
    required this.depth,
    required this.selected,
    required this.fault,
    required this.onTap,
    super.key,
  });

  final Location location;
  final int depth;
  final bool selected;
  final String? fault;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        color: selected ? theme.colorScheme.primaryContainer : null,
        padding: EdgeInsets.only(
          left: 12 + depth * 16.0,
          right: 12,
          top: 8,
          bottom: 8,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _displayName(location),
                style: theme.textTheme.bodyMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (fault != null)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  fault!,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            if (location.code.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  location.code,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The selected node's fields, its parent, and its delete.
class _Detail extends StatelessWidget {
  const _Detail({
    required this.location,
    required this.doc,
    required this.tree,
    required this.actions,
    required this.onEdit,
    required this.onReparent,
    required this.onDelete,
  });

  final Location location;
  final RackDocument doc;
  final LocationTree tree;
  final LocationsPanelActions actions;
  final void Function(VoidCallback edit) onEdit;
  final void Function(Uuid id, Uuid? newParentId) onReparent;
  final Future<void> Function(Uuid id) onDelete;

  /// Every node this one may legally be moved under, plus the top level.
  ///
  /// Filtered by `wouldCycle` so the impossible move is not OFFERED, which
  /// is not the same as it not being refused: `buildReparentLocation` still
  /// refuses it, because the panel is not the only caller and a guard that
  /// lives only in a dropdown is a guard a second entry point walks past.
  List<Uuid> get _candidateParents => [
    for (final id in tree.preOrder)
      if (id != location.id && !tree.wouldCycle(location.id, id)) id,
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // THE FIELDS SCROLL; `Delete location` DOES NOT.
    //
    // The dialog is a fixed 720 × 520 (`showLocationsPanel`) and this pane
    // has grown twice: M3-B built it with three controls, DR-040 §11.39.4
    // added two more, and the second growth pushed the delete button out
    // of the pane's viewport. Three delete cases caught it, which is the
    // only reason it was not shipped.
    //
    // Making the dialog taller fixes today and nothing else, because the
    // next field puts it right back. A destructive action pinned outside
    // the scroll view has a fixed home no future field can take, and a
    // person looking for it never has to discover that this pane scrolls.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: _fields(theme)),
        const Divider(height: 1),
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: TextButton.icon(
              onPressed: () => onDelete(location.id),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete location'),
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _fields(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            // The breadcrumb CR-047 spells `Level 1 › Living Room`, which
            // is also what the rack editor's combobox shows, so the two
            // surfaces name a room the same way.
            breadcrumbOf(doc, tree, location.id) ?? _displayName(location),
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          _TextField(
            key: ValueKey('name-${location.id.v}'),
            label: 'Name',
            value: location.name,
            onChanged: (v) => onEdit(() => actions.onRename(location.id, v)),
          ),
          const SizedBox(height: 12),
          _TextField(
            key: ValueKey('code-${location.id.v}'),
            label: 'Code',
            helper: 'Feeds {ROOM_ABBR} on every label.',
            value: location.code,
            onChanged: (v) => onEdit(() => actions.onSetCode(location.id, v)),
          ),
          const SizedBox(height: 12),
          // FLOOR AND SPACE SIT BESIDE CODE because all three are
          // identifiers a label reads, and none of them is a name. DR-040
          // §11.39.4: these are the RACK's when a rack label renders, so
          // the room a drop starts in never contributes its own storey.
          //
          // ON ONE ROW, AND THE DIALOG IS WHY, not tidiness. It is a
          // FIXED 720 × 520 (`showLocationsPanel`), so two stacked rows
          // put `Delete location` below the fold of a pane a person cannot
          // resize. One row also reads the way the label does: `{FLOOR}`
          // and `{SPACE}` concatenate with nothing between them, and `1A`
          // is one identifier a building uses, not two.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _CommitField(
                  key: ValueKey('floor-${location.id.v}'),
                  label: 'Floor',
                  helper: 'Feeds {FLOOR}. Blank is unknown.',
                  value: location.floorNumber?.toString() ?? '',
                  onCommit: (text) {
                    switch (parseFloorCell(text)) {
                      case CellParsed<int>(:final value):
                        onEdit(
                          () => actions.onSetFloorNumber(location.id, value),
                        );
                        return true;
                      case CellRefused<int>(:final reason):
                        actions.onRefuse(reason);
                        return false;
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _TextField(
                  key: ValueKey('space-${location.id.v}'),
                  label: 'Space',
                  helper: 'Feeds {SPACE}. A telecom room is often "1A".',
                  value: location.spaceCode ?? '',
                  onChanged: (v) => onEdit(() {
                    final trimmed = v.trim();
                    actions.onSetSpaceCode(
                      location.id,
                      trimmed.isEmpty ? null : trimmed,
                    );
                  }),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _CommitField(
            key: ValueKey('estimate-${location.id.v}'),
            label: 'Run length from rack',
            // WHOLE FEET, WHICH IS `parseLengthCell`'s GRAMMAR AND NOT A
            // CHOICE MADE HERE. DR-144 §11.143.5 states the split between
            // this parser and the calibration's: that field is a distance
            // on somebody else's drawing whose magnitude is unknown, so it
            // refuses a bare number; THIS is cable, ordered and cut in
            // whole feet, so a bare number is what it reads.
            helper: estimateHelperFor(doc, location),
            value: location.estimatedRunLengthFromRack == null
                ? ''
                : lengthCellText(
                    location.estimatedRunLengthFromRack!,
                    doc.settings.displayUnits,
                  ),
            onCommit: (text) {
              switch (parseLengthCell(text, doc.settings.displayUnits)) {
                case CellParsed<Len>(:final value):
                  onEdit(
                    () => actions.onSetEstimatedRunLength(location.id, value),
                  );
                  return true;
                case CellRefused<Len>(:final reason):
                  actions.onRefuse(reason);
                  return false;
              }
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<LocationKind>(
            key: ValueKey('kind-${location.id.v}'),
            initialValue: location.kind,
            decoration: const InputDecoration(
              labelText: 'Kind',
              // CR-047 in a helper line: the word is a label, not a level.
              helperText: 'A label only. Any kind may sit under any other.',
            ),
            items: [
              for (final kind in LocationKind.values)
                DropdownMenuItem(value: kind, child: Text(kind.name)),
            ],
            onChanged: (v) {
              if (v == null) return;
              onEdit(() => actions.onSetKind(location.id, v));
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey('parent-${location.id.v}'),
            initialValue: location.parentId?.v ?? '',
            decoration: const InputDecoration(labelText: 'Inside'),
            // EXPANDED AND ELLIPSISED. Every item is a breadcrumb, so its
            // width grows with the depth of the tree AND with the length
            // of every name in it. Unconstrained, a three-deep room in a
            // 720px dialog overflows its own field.
            isExpanded: true,
            items: [
              const DropdownMenuItem(value: '', child: Text('(top level)')),
              for (final id in _candidateParents)
                DropdownMenuItem(
                  value: id.v,
                  child: Text(
                    breadcrumbOf(doc, tree, id) ?? id.v,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
            ],
            onChanged: (v) => onReparent(
              location.id,
              v == null || v.isEmpty ? null : Uuid(v),
            ),
          ),
        ],
      ),
    );
  }
}

/// A text field that reports every keystroke.
///
/// Per-keystroke rather than on-submit because `SetEntityPropertyCommand`
/// COALESCES per property per entity (its `mergeKey`), so typing a room
/// name is one undo entry either way, and the tree updates as the user
/// types.
class _TextField extends StatefulWidget {
  const _TextField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.helper,
    super.key,
  });

  final String label;
  final String? helper;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<_TextField> createState() => _TextFieldState();
}

class _TextFieldState extends State<_TextField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _controller,
    decoration: InputDecoration(
      labelText: widget.label,
      helperText: widget.helper,
    ),
    onChanged: widget.onChanged,
  );
}

/// A text field that commits when it LOSES FOCUS, not per keystroke.
///
/// THE SIBLING ABOVE IS PER-KEYSTROKE AND THAT IS RIGHT FOR A NAME.
/// It is wrong for a parsed field: `-` is the first keystroke of `-1` and
/// `parseFloorCell` would refuse it, so a person typing a basement would
/// be told they were wrong twice before they were right. Committing on
/// blur means the parse sees a finished value.
///
/// A REFUSED COMMIT PUTS THE OLD TEXT BACK. The alternative is a box
/// holding text the document does not have, which the next rebuild would
/// silently overwrite anyway; showing the stored value with the refusal
/// beside it is the only pair that stays true to each other.
class _CommitField extends StatefulWidget {
  const _CommitField({
    required this.label,
    required this.value,
    required this.onCommit,
    this.helper,
    super.key,
  });

  final String label;
  final String? helper;
  final String value;

  /// Returns whether the value was accepted.
  final bool Function(String text) onCommit;

  @override
  State<_CommitField> createState() => _CommitFieldState();
}

class _CommitFieldState extends State<_CommitField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value,
  );
  late final FocusNode _focus = FocusNode()..addListener(_onFocusChange);

  void _onFocusChange() {
    if (!_focus.hasFocus) _commit();
  }

  void _commit() {
    // NOTHING TYPED, NOTHING COMMITTED. Tabbing through a field must not
    // push an undo entry, and a text box that has not changed has no
    // opinion about the document.
    if (_controller.text == widget.value) return;
    if (!widget.onCommit(_controller.text)) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _focus
      ..removeListener(_onFocusChange)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _controller,
    focusNode: _focus,
    decoration: InputDecoration(
      labelText: widget.label,
      helperText: widget.helper,
    ),
    onSubmitted: (_) => _commit(),
  );
}

/// What the run-length field says under itself.
///
/// ═══════════════════════════════════════════════════════════════════════
/// THE MARKER'S READER, AND IT IS HERE BECAUSE §11.49.3 ASKED A QUESTION
/// ═══════════════════════════════════════════════════════════════════════
/// DR-050 buys `estimatedRunLengthOrigin` so that *"a later reader asking
/// 'did somebody measure this room or did the software guess it' has an
/// answer"*. A field with no reader is the failure this project keeps
/// meeting: `riseAllowance` was named by two rulings and a design document
/// and written by nothing until `PLAN-C`, and `PortDef.bus.maxTapWatts`
/// was declared on zero of 727 seeded ports. The marker ships with this.
///
/// **PRINTED IN ALL THREE DIRECTIONS** (G4). An absent marker is not
/// "typed": every document written before `LEN-A/1` carries a figure with
/// no recorded provenance, and saying a person entered it would be
/// inventing a fact about somebody else's project.
String estimateHelperFor(RackDocument doc, Location location) {
  if (location.estimatedRunLengthFromRack == null) {
    // BLANK SAYS WHY (DR-191 §11.190.4). This read *"AC-024's one number
    // per room. Blank is unknown."*, which showed a person a ruling ID and
    // told them nothing they could act on. The plan now fills the figure
    // on its own whenever it can, so a blank one is waiting for exactly
    // one input, and naming it is the useful sentence.
    return switch (planEstimateGapOf(doc, location)) {
      PlanEstimateGap.noOutline || null =>
        'Blank is unknown. Type it, or outline this room on a calibrated '
            'plan and it is worked out for you.',
      PlanEstimateGap.notCalibrated =>
        'Blank is unknown. Calibrate the plan this room is outlined on.',
      PlanEstimateGap.noLandedRun =>
        'Blank is unknown. No run to this room lands in a rack yet, so '
            'there is nothing to measure from.',
      PlanEstimateGap.rackNotPinned =>
        'Blank is unknown. Pin the rack this room’s runs land in on '
            'the plan it is outlined on.',
      // THE ONE THE NEXT EDIT CANNOT FIX, so it says to type the figure
      // rather than pointing at an act that would not help.
      PlanEstimateGap.rackOnAnotherPlan =>
        'Blank is unknown. The rack is pinned on a different plan from '
            'this room’s outline, and two plans cannot be measured '
            'across. Type the length.',
    };
  }
  return switch (location.estimatedRunLengthOrigin) {
    RunLengthOrigin.computedFromPlan =>
      'Worked out from this room’s outline on the plan.',
    RunLengthOrigin.typed => 'Entered by hand.',
    null => 'Where this figure came from was not recorded.',
  };
}

/// [length] as the whole-unit text `parseLengthCell` reads back.
///
/// ROUND-TRIPS WITH THE PARSER, which is the property that keeps the
/// stored value equal to the value its own field displays: that function
/// reads whole feet and this writes them.
String lengthCellText(Len length, UnitSystem units) {
  final divisor = units == UnitSystem.imperial
      ? Len.nmPerInch * 12
      : Len.nmPerMillimetre * 1000;
  return (length.nm / divisor).round().toString();
}
