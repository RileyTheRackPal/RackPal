// The Device Builder's I/O editor (docs/06 §4.5, M4-E1 #203).
//
// ═══════════════════════════════════════════════════════════════════════
// THE FOURTH TABLE IN THIS APPLICATION, BUILT LIKE THE THIRD
// ═══════════════════════════════════════════════════════════════════════
// `structure_editor_screen.dart`'s `_DropTable` already solves every
// structural problem this one has: a horizontal scroll that carries the
// header with the rows, band headers that stay pinned while their rows
// scroll under them, and virtualised rows so a long table costs what a
// short one costs. It is copied here in shape rather than reinvented,
// down to the `LayoutBuilder` that refuses to squeeze a column below its
// authored width and scrolls sideways instead.
//
// Virtualisation is not an optimisation on this surface. docs/06 §2 says
// the builder is a full-window editor and not a modal *because* a modal
// cannot host a 68-row grid, and 68 is the worked example rather than the
// ceiling: a 48-port patch panel plus its banks is the ordinary case.
//
// ═══════════════════════════════════════════════════════════════════════
// THREE CONTROLS FOR TEN COLUMNS, AND THE SPLIT IS MEASURED
// ═══════════════════════════════════════════════════════════════════════
// M4-E2 (`#204`) makes the cells editable, and which control a column
// gets follows its answer set rather than a taste:
//
//   * TEXT for the five columns whose model type is a string.
//   * `DropdownButton` for DIRECTION, FACE and SET. A dropdown's menu
//     inherits its BUTTON's width; `Bidirectional` fits in 116 points and
//     these three have no problem a bigger control would solve.
//   * A `MenuAnchor` for CONNECTOR and SIGNAL, which do. Their labels
//     come from the registries and run to 45 characters, and #587
//     measured what a `DropdownButton` does to those: every row clamped
//     to 84 points, so two different speaker families both arrive as
//     `AUD·Speaker…`. SIGNAL uses the Structure editor's own picker,
//     extracted to `widgets/family_picker.dart` rather than copied.
//
// The vocabulary is core's in every one of them. The moment this file
// writes `port.direction.name` it owns a second speller, and the first
// time one changes they disagree on a printed schedule.
//
// ═══════════════════════════════════════════════════════════════════════
// [+ ADD PORT] IS HERE BECAUSE NOTHING IN M4-E CREATES A PORT
// ═══════════════════════════════════════════════════════════════════════
// Quick Add is M4-G (`#178`), the archetype generators are M4-I, paste is
// M4-I3. M4-E1 through E5 build a grid, its columns, its packs, its
// validation dots and its footer, and not one of them produces a row for
// any of that to act on; the application's only entry point opens a blank
// template. So the slow path lands with the grid: one button, one blank
// port, undoable. The fast path is still M4-G's, and this does not
// pretend otherwise.
//
// Delete is here for the same reason, and it is not in M4-E's five tasks
// either: a grid you can add to and not remove from is one nobody can
// correct a mis-click in.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rackmate_core/rackmate_core.dart';
import 'package:rackmate_ui/src/builder/batch_inspector.dart';
import 'package:rackmate_ui/src/builder/change_type_dialog.dart';
import 'package:rackmate_ui/src/builder/find_replace_dialog.dart';
import 'package:rackmate_ui/src/builder/move_to_bank_dialog.dart';
import 'package:rackmate_ui/src/builder/port_cells.dart';
import 'package:rackmate_ui/src/builder/quick_add_bar.dart';
import 'package:rackmate_ui/src/builder/renumber_dialog.dart';
import 'package:rackmate_ui/src/keymap/keymap.dart';

/// How the grid asks the builder to change the template.
///
/// CALLBACKS AND NOT THE SESSION, the shape every other view in this
/// package already uses. The screen owns `setState` and the session's
/// lifetime; handing the grid a `TemplateEditSession` would hand it
/// `close()` as well.
final class PortGridActions {
  const PortGridActions({required this.run, required this.transact});

  /// One command, one undo entry.
  final void Function(Command<TemplateBody> command) run;

  /// Several commands, still one undo entry: deleting four ticked rows is
  /// one gesture and must be one `Ctrl+Z`.
  final void Function(
    LabelKey label,
    void Function(TxnScope<TemplateBody> tx) body,
  )
  transact;
}

/// The PORTS section: a virtualised, banded grid over `body.ports`.
class PortGrid extends StatefulWidget {
  const PortGrid({
    required this.body,
    required this.registries,
    required this.openedPortKeys,
    required this.keyTouched,
    required this.onKeyTouched,
    required this.remembered,
    required this.onPacksRemembered,
    required this.actions,
    required this.onBatchContext,
    this.portDesignatorFormat = const IdFormat('J{PORT_SEQ:2}'),
    this.quickAddAutofocus = true,
    super.key,
  });

  /// The session's LIVE body. Read only through [buildPortTable]; every
  /// write goes through [actions].
  final TemplateBody body;

  /// For the connector and signal-family display names. A port naming
  /// something this does not hold still draws, showing the raw id.
  final Registries registries;

  /// Told the selection whenever it changes, so docs/06 §2's right dock
  /// can be the batch inspector (M4-F2). Null when fewer than two rows
  /// are selected, which is the dock's own "not in this state".
  final ValueChanged<PortBatchContext?> onBatchContext;

  /// Whether Quick Add takes focus on entering the section.
  ///
  /// TRUE IN THE PRODUCT, because docs/06 §4.1 says focus lands
  /// there. False only in the nineteen-odd widget tests that are
  /// examining a CELL: an autofocusing bar would take focus from the
  /// control under test and every one of them would fail for a
  /// reason unrelated to what it asserts.
  final bool quickAddAutofocus;

  /// The keys the template already had when the builder opened.
  ///
  /// PASSED IN RATHER THAN CAPTURED HERE, because this widget is built
  /// lazily when the rail first reaches the Ports section and again every
  /// time the user comes back to it. Capturing on the second visit would
  /// call the ports created on the first visit "published", and a rename
  /// would start writing `renamedFrom` entries for names nothing ever saw.
  final Set<String> openedPortKeys;

  /// Keys whose cell a person has typed into.
  ///
  /// ═══════════════════════════════════════════════════════════════════
  /// OWNED BY THE SCREEN, NOT BY THIS WIDGET, AND THAT IS A FIX
  /// ═══════════════════════════════════════════════════════════════════
  /// It lived in this `State` until a test walked out to the Physical
  /// section and back: the grid is rebuilt by a `switch` on the rail, so
  /// leaving the section DISPOSED the set, and a key the author had
  /// deliberately typed silently went back to following its label. That
  /// is a fact about the editing SESSION rather than about a widget, so
  /// it lives beside the session.
  ///
  /// MONOTONIC, AND THAT IS WHAT MAKES IT SURVIVE AN UNDO. A hand-typed
  /// rename records BOTH the old and the new key, so undoing the rename
  /// lands on a key that is still marked touched. A set tracking only the
  /// current key would forget, and the migration join would resume
  /// following a typo correction, which is the failure CR-051 exists to
  /// prevent.
  ///
  /// SESSION-ONLY, never stored. Reopen a saved template and every key is
  /// the author's, because it was saved.
  final Set<String> keyTouched;

  /// Records a hand-typed rename in [keyTouched]. Both sides; see there.
  final void Function(String was, String now) onKeyTouched;

  /// Packs this device's CATEGORY was last left showing (docs/06 §4.5).
  /// Empty when the app has nothing remembered, which is honest: the
  /// auto-reveal still runs.
  final Set<PortColumnPack> remembered;

  /// Hands the app the set to remember against this category.
  final ValueChanged<Set<PortColumnPack>> onPacksRemembered;

  final PortGridActions actions;

  /// The project's port designator format, so the DESIG column previews
  /// what this project would allocate rather than what a default one
  /// would (CR-042).
  final IdFormat portDesignatorFormat;

  @override
  State<PortGrid> createState() => _PortGridState();
}

class _PortGridState extends State<PortGrid> {
  /// Bands the user has folded shut, by bank key. `null` is a legitimate
  /// member: the no-bank band folds like any other.
  final _collapsed = <String?>{};

  /// The selection (DR-061): which rows, where a `Shift`+click extends
  /// from, and which column has focus.
  ///
  /// THIS IS M4-E's `_ticked` UNDER ITS REAL NAME. The tick box was
  /// already a set of port keys read by the delete button; DR-061 makes it
  /// the one selection the whole section acts on rather than a second
  /// thing beside a selection. The algebra is in core, so what remains
  /// here is the gestures and the paint.
  PortSelection _selection = PortSelection.empty;

  /// The view sort (M4-F5, DR-065), or null for the declared order.
  ///
  /// STATE ON THE WIDGET AND NOT ON THE TEMPLATE, which is the whole of
  /// this feature: a sort is a way of looking at the ports and never a
  /// fact about them, so it lives here, dies with the window, and is
  /// absent from every byte of the file.
  PortSort? _sort;

  /// Whether this port's key still follows its label.
  ///
  /// Two conditions, and both are about whether the key can still be
  /// nobody's decision: it must not have been typed, and the port must be
  /// new in this session. A port that was in the template when the window
  /// opened has a PUBLISHED key, and a project somewhere may already join
  /// its cables through it.
  bool _keyFollows(PortDef port) =>
      !widget.keyTouched.contains(port.key.v) &&
      !widget.openedPortKeys.contains(port.key.v);

  /// Packs the person has switched on or off by hand, which is what makes
  /// auto-reveal a SUGGESTION rather than a rule. A pack the user closed
  /// stays closed even when the bank's traffic would open it, and a pack
  /// they opened stays open when it would not.
  final _packOverrides = <PortColumnPack, bool>{};

  /// Which packs are showing: the auto-revealed set, then the overrides.
  Set<PortColumnPack> _openPacks() {
    final open = {
      ...autoRevealedPacks(
        widget.body.ports,
        widget.registries,
        isPassthrough: widget.body.isPassthrough,
      ),
      ...widget.remembered,
    };
    for (final entry in _packOverrides.entries) {
      entry.value ? open.add(entry.key) : open.remove(entry.key);
    }
    return open;
  }

  void _togglePack(PortColumnPack pack, {required bool on}) {
    setState(() => _packOverrides[pack] = on);
    // REMEMBERED PER CATEGORY (docs/06 §4.5). An installer who opens the
    // Network pack on one switch means it for the next switch too, and
    // not for the next amplifier.
    widget.onPacksRemembered(_openPacks());
  }

  /// Which port each passthrough pair puts on the other end.
  ///
  /// BOTH DIRECTIONS, because a pair names a front and a rear and either
  /// row may be the one a person is looking at.
  Map<String, String> _pairs() => {
    for (final pair in widget.body.passthroughPairs) ...{
      pair.frontKey.v: pair.rearKey.v,
      pair.rearKey.v: pair.frontKey.v,
    },
  };

  void _addPort() {
    final port = blankPort(widget.body);
    widget.actions.run(AddPortCommand(port));
  }

  /// SIXTEEN PORTS AND A BANK, ONE UNDO ENTRY. The same `transact` the
  /// delete path uses; Quick Add needed no batch command of its own,
  /// only its own `LabelKey` so the Edit menu can name the whole line
  /// rather than one of the rows it is about to remove.
  void _runQuickAdd(List<Command<TemplateBody>> commands) {
    if (commands.isEmpty) return;
    widget.actions.transact(LabelKey.quickAddPorts, (tx) {
      for (final command in commands) {
        tx.add(command);
      }
    });
  }

  void _deleteSelected() {
    final doomed = [
      for (final port in widget.body.ports)
        if (_selection.contains(port.key.v)) port.key,
    ];
    if (doomed.isEmpty) return;
    widget.actions.transact(LabelKey.removePort, (tx) {
      for (final key in doomed) {
        tx.add(RemovePortCommand(key));
      }
    });
    setState(() => _selection = PortSelection.empty);
  }

  /// What the last fill refused to do, or null.
  ///
  /// SHOWN UNTIL THE NEXT GESTURE, not on a timer. A message about a key
  /// that appeared to do nothing has to still be there when the person
  /// looks up from the grid to find out why.
  String? _fillRefusal;

  /// `Ctrl+D` and `Ctrl+Shift+D`, which differ only in what they build.
  ///
  /// ONE TRANSACTION, so sixteen rewritten cells are one `Ctrl+Z`. The
  /// same shape the delete path and Quick Add already use.
  void _fill(
    PortFillResult Function({
      required TemplateBody body,
      required PortColumnId? column,
      required List<String> selectedInOrder,
    })
    build,
    List<String> visible,
  ) {
    final result = build(
      body: widget.body,
      column: _selection.column,
      selectedInOrder: _selection.inOrder(visible),
    );
    if (result.refusal case final PortFillRefusal refusal) {
      setState(() => _fillRefusal = portFillRefusalMessage(refusal));
      return;
    }
    setState(() => _fillRefusal = null);
    if (result.commands.isEmpty) return;
    widget.actions.transact(LabelKey.fillPorts, (tx) {
      for (final command in result.commands) {
        tx.add(command);
      }
    });
  }

  /// `Ctrl+J`: clone the selection below itself (M4-F6, docs/06 §4.6).
  ///
  /// ONE TRANSACTION, so four clones are one `Ctrl+Z`, and its own
  /// `LabelKey` so the Edit menu names the act rather than the mechanism.
  ///
  /// THE SELECTION FOLLOWS THE CLONES. Duplicating and then typing is the
  /// gesture this exists for (clone a bank, retype its labels), and
  /// leaving the selection on the sources means the next keystroke edits
  /// the rows the person just copied FROM. The keys are known here
  /// because the plan built them.
  void _duplicate(List<String> visible) {
    final result = buildPortDuplicate(
      body: widget.body,
      selectedInOrder: _selection.inOrder(visible),
      viewIsSorted: _sort != null,
    );
    if (result.refusal case final PortDuplicateRefusal refusal) {
      setState(() => _fillRefusal = portDuplicateRefusalMessage(refusal));
      return;
    }
    if (result.commands.isEmpty) return;
    widget.actions.transact(LabelKey.duplicatePorts, (tx) {
      for (final command in result.commands) {
        tx.add(command);
      }
    });
    setState(() {
      _fillRefusal = null;
      _selection = _selection.replacedWith([
        for (final command in result.commands)
          if (command case final AddPortCommand add) add.port.key.v,
      ]);
    });
  }

  /// `Ctrl+R`: re-apply a label pattern to the selection (M4-F7).
  ///
  /// THE DIALOG PARSES AND THIS RUNS. `label_pattern.dart` is the one
  /// grammar, the dialog shows its designed failure where the person is
  /// typing, and nothing reaches here until there is a compiled pattern.
  ///
  /// IT DOES NOT REFUSE UNDER A SORT, unlike `Ctrl+J`: §4.6 says renumber
  /// works in CURRENT DISPLAY ORDER, so a sorted view is a legitimate
  /// thing to number, and the dialog says which order it is about rather
  /// than this method guessing that the person knew.
  Future<void> _renumber(List<String> visible) async {
    final selected = _selection.inOrder(visible);
    if (selected.isEmpty) {
      setState(
        () => _fillRefusal = portRenumberRefusalMessage(
          PortRenumberRefusal.nothingSelected,
        ),
      );
      return;
    }
    final choice = await showRenumberDialog(
      context: context,
      body: widget.body,
      selectedInOrder: selected,
      viewIsSorted: _sort != null,
    );
    if (choice == null || !mounted) return;

    final result = buildPortRenumber(
      body: widget.body,
      // RE-READ rather than the list captured before the dialog. Nothing
      // can edit the body under a modal today, and a selection read once
      // and used later is the kind of thing that stops being true without
      // anybody noticing.
      selectedInOrder: _selection.inOrder(visible),
      pattern: choice.pattern,
      start: choice.start,
      step: choice.step,
    );
    if (result.refusal case final PortRenumberRefusal refusal) {
      setState(() => _fillRefusal = portRenumberRefusalMessage(refusal));
      return;
    }
    setState(() => _fillRefusal = null);
    if (result.commands.isEmpty) return;
    widget.actions.transact(LabelKey.renumberPorts, (tx) {
      for (final command in result.commands) {
        tx.add(command);
      }
    });
  }

  /// `Ctrl+M`: move the selection into another bank (M4-F10).
  ///
  /// THE REFUSALS COME FIRST, BEFORE THE DIALOG, because two of them are
  /// about whether there is anything to show: a template with one bank has
  /// nowhere to move to, and DR-078 §11.77.2 forbids offering to create
  /// one. A dialog listing a single destination that is where the rows
  /// already are would be a screen with nothing on it.
  Future<void> _moveToBank(List<String> visible) async {
    final selected = _selection.inOrder(visible);
    void refuse(PortMoveToBankRefusal refusal) => setState(
      () => _fillRefusal = portMoveToBankRefusalMessage(refusal),
    );
    if (selected.isEmpty) {
      refuse(PortMoveToBankRefusal.nothingSelected);
      return;
    }
    if (_sort != null) {
      refuse(PortMoveToBankRefusal.theViewIsSorted);
      return;
    }
    // THE DESTINATIONS THE SELECTION IS NOT ALREADY WHOLLY IN. A row for
    // the bank every selected port already sits in would be the one
    // choice that cannot do anything, offered first.
    final banks = {
      for (final key in selected)
        widget.body.ports.firstWhere((p) => p.key.v == key).bankKey,
    };
    final targets = [
      for (final target in movableBanks(widget.body))
        if (!(banks.length == 1 && banks.single == target.key)) target,
    ];
    if (targets.isEmpty) {
      refuse(PortMoveToBankRefusal.nowhereToMoveTo);
      return;
    }

    final choice = await showMoveToBankDialog(
      context: context,
      targets: targets,
      portCount: selected.length,
    );
    if (choice == null || !mounted) return;

    final result = buildPortMoveToBank(
      body: widget.body,
      selectedInOrder: _selection.inOrder(visible),
      targetBankKey: choice.bankKey,
      viewIsSorted: _sort != null,
    );
    if (result.refusal case final PortMoveToBankRefusal refusal) {
      refuse(refusal);
      return;
    }
    setState(() => _fillRefusal = null);
    if (result.commands.isEmpty) return;
    widget.actions.transact(LabelKey.movePortsToBank, (tx) {
      for (final command in result.commands) {
        tx.add(command);
      }
    });
  }

  /// `Ctrl+T`: bulk connector and family change (M4-F9).
  ///
  /// THE DIALOG IS THE DELIVERABLE, so this method is a router: it refuses
  /// early where there is nothing to show, opens the preview, and runs
  /// what came back. Everything worth arguing about is in
  /// `port_type_change.dart` and `change_type_dialog.dart`.
  Future<void> _changeType(List<String> visible) async {
    final selected = _selection.inOrder(visible);
    if (selected.isEmpty) {
      setState(
        () => _fillRefusal = portTypeChangeRefusalMessage(
          PortTypeChangeRefusal.nothingSelected,
        ),
      );
      return;
    }
    final choice = await showChangeTypeDialog(
      context: context,
      body: widget.body,
      selectedInOrder: selected,
      registries: widget.registries,
    );
    if (choice == null || !mounted) return;

    final result = buildPortTypeChange(
      body: widget.body,
      selectedInOrder: _selection.inOrder(visible),
      registries: widget.registries,
      family: choice.family,
      connector: choice.connector,
    );
    if (result.refusal case final PortTypeChangeRefusal refusal) {
      setState(() => _fillRefusal = portTypeChangeRefusalMessage(refusal));
      return;
    }
    setState(() => _fillRefusal = null);
    if (result.commands.isEmpty) return;
    widget.actions.transact(LabelKey.changePortType, (tx) {
      for (final command in result.commands) {
        tx.add(command);
      }
    });
  }

  /// `Ctrl+H`: find and replace across the selection's text (M4-F8).
  ///
  /// `widget.openedPortKeys` IS THE LOAD-BEARING ARGUMENT. It is the set
  /// the template had when the builder opened, and it decides two things
  /// the person can see: which rows the preview marks as a published key,
  /// and which renames record a `renamedFrom` alias so another project's
  /// cables still join (CR-051). Passed rather than recomputed, because
  /// this widget is rebuilt every time the rail returns to the Ports
  /// section and capturing it here would call this session's own new
  /// ports published.
  Future<void> _findReplace(List<String> visible) async {
    final selected = _selection.inOrder(visible);
    if (selected.isEmpty) {
      setState(
        () => _fillRefusal = portFindReplaceRefusalMessage(
          PortFindReplaceRefusal.nothingSelected,
        ),
      );
      return;
    }
    final choice = await showFindReplaceDialog(
      context: context,
      body: widget.body,
      selectedInOrder: selected,
      openedPortKeys: widget.openedPortKeys,
    );
    if (choice == null || !mounted) return;

    final result = buildPortFindReplace(
      body: widget.body,
      selectedInOrder: _selection.inOrder(visible),
      scope: choice.scope,
      find: choice.find,
      replace: choice.replace,
      openedPortKeys: widget.openedPortKeys,
      useRegex: choice.useRegex,
    );
    if (result.refusal case final PortFindReplaceRefusal refusal) {
      setState(() => _fillRefusal = portFindReplaceRefusalMessage(refusal));
      return;
    }
    setState(() => _fillRefusal = null);
    if (result.commands.isEmpty) return;
    widget.actions.transact(LabelKey.findAndReplacePorts, (tx) {
      for (final command in result.commands) {
        tx.add(command);
      }
    });
  }

  /// `Ctrl+C`: the selected rows, as TSV, on the clipboard (M4-F3).
  ///
  /// THE VISIBLE COLUMNS, because what a person copied is what they can
  /// see. Opening a pack widens the copy, which is the same rule the
  /// batch inspector follows and needs no second explanation.
  void _copy(List<String> visible, List<PortColumnId> columns) {
    final keys = _selection.inOrder(visible);
    if (keys.isEmpty) {
      setState(() => _fillRefusal = kCopyNeedsRows);
      return;
    }
    unawaited(
      Clipboard.setData(
        ClipboardData(
          text: buildPortTsv(
            body: widget.body,
            columns: columns,
            portKeys: keys,
            registries: widget.registries,
          ),
        ),
      ),
    );
    setState(
      () => _fillRefusal = keys.length == 1
          ? '1 port copied.'
          : '${keys.length} ports copied.',
    );
  }

  /// `Ctrl+V`: tab-separated cells from the focused cell (M4-F3).
  Future<void> _paste(
    List<String> visible,
    List<PortColumnId> columns,
  ) async {
    final clip = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    final plan = parsePortTsv(
      body: widget.body,
      text: clip?.text ?? '',
      columns: columns,
      visibleRowKeys: visible,
      // THE CARET, WHICH IS ONE ROW AND ONE COLUMN. The selection may be
      // eight rows; a paste still lands from the cell the hand is in,
      // exactly as it does in a spreadsheet, and the rows it covers are
      // however many the clipboard holds.
      anchorKey: _selection.anchor,
      anchorColumn: _selection.column,
      registries: widget.registries,
    );
    if (plan.refusal case final PortPasteRefusal refusal) {
      setState(() => _fillRefusal = portPasteRefusalMessage(refusal, plan));
      return;
    }
    setState(() => _fillRefusal = null);
    if (plan.commands.isEmpty) return;
    widget.actions.transact(LabelKey.fillPorts, (tx) {
      for (final command in plan.commands) {
        tx.add(command);
      }
    });
  }

  /// A click on a column header cycles that column's sort (M4-F5).
  void _onSort(PortColumnId column) => setState(() {
    _sort = nextPortSort(_sort, column);
    // The message was about the gesture before this one, and clicking a
    // header is a gesture.
    _fillRefusal = null;
  });

  /// `Commit sort order`: writes the view into the declared order.
  ///
  /// THE CONFIRM IS AC-058/D5, which lists this beside `Ctrl+X` on a wired
  /// device as a data-loss edge. It is the only place in this grid where a
  /// single click rewrites a whole bank, and the three things that follow
  /// the order are none of them visible from here.
  Future<void> _commitSort() async {
    final commit = buildSortCommit(
      body: widget.body,
      sortedTable: sortPortTable(
        buildPortTable(
          widget.body,
          portDesignatorFormat: widget.portDesignatorFormat,
        ),
        _sort,
        widget.registries,
      ),
    );
    if (commit.refusal case final PortSortCommitRefusal refusal) {
      setState(() => _fillRefusal = portSortCommitRefusalMessage(refusal));
      return;
    }

    final go = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Commit sort order'),
        content: Text(portSortCommitPrompt(commit.movedPorts)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Commit'),
          ),
        ],
      ),
    );
    if (go != true || !mounted) return;

    widget.actions.transact(LabelKey.commitPortSort, (tx) {
      for (final command in commit.commands) {
        tx.add(command);
      }
    });
    // THE SORT CLEARS ITSELF. The view and the declared order are now the
    // same thing, so a badge still saying "this is only a view" would be
    // describing a state that ended one line ago.
    setState(() {
      _sort = null;
      _fillRefusal = null;
    });
  }

  /// `Alt+Up` and `Alt+Down`: the selection slides one row (M4-F4).
  void _nudge({required bool up}) => _reorderBy(
    buildPortNudge(
      body: widget.body,
      moving: _selection.inOrder(_visibleRowKeys()),
      up: up,
      viewIsSorted: _sort != null,
    ),
  );

  /// A row dropped inside its band.
  ///
  /// THE WHOLE SELECTION TRAVELS WHEN THE GRABBED ROW IS IN IT, and only
  /// the grabbed row otherwise: dragging a row that is not selected is the
  /// same act as clicking one that is not selected, and neither should
  /// drag eight rows nobody pointed at.
  void _reorder(PortTableBand band, int from, int at) {
    final dragged = band.rows[from].port.key.v;
    final takesTheSelection =
        _selection.length > 1 && _selection.contains(dragged);
    final moving = takesTheSelection
        ? [
            for (final row in band.rows)
              if (_selection.contains(row.port.key.v)) row.port.key.v,
          ]
        : [dragged];

    // `at` is measured against the band with the dragged row already out
    // of it, which is what `onReorderItem` guarantees and what the older
    // `onReorder` did not.
    final without = [
      for (final row in band.rows)
        if (row.port.key.v != dragged) row.port.key.v,
    ];

    // The nearest row above the drop that is NOT travelling. Walking
    // backwards is what makes a block drop land where the pointer is
    // rather than after one of its own members.
    String? afterKey;
    for (var i = at - 1; i >= 0; i--) {
      if (!moving.contains(without[i])) {
        afterKey = without[i];
        break;
      }
    }

    _reorderBy(
      buildPortReorder(
        body: widget.body,
        moving: moving,
        afterKey: afterKey,
        viewIsSorted: _sort != null,
      ),
    );
  }

  /// Runs a reorder plan, or shows why there is none.
  ///
  /// ONE TRANSACTION, so a block of eight rows is one `Ctrl+Z`, and its
  /// own `LabelKey` so the Edit menu says "Reorder" rather than describing
  /// the field write underneath.
  void _reorderBy(PortReorderPlan plan) {
    if (plan.refusal case final PortReorderRefusal refusal) {
      setState(() => _fillRefusal = portReorderRefusalMessage(refusal));
      return;
    }
    setState(() => _fillRefusal = null);
    if (plan.commands.isEmpty) return;
    widget.actions.transact(LabelKey.reorderPorts, (tx) {
      for (final command in plan.commands) {
        tx.add(command);
      }
    });
  }

  /// Offers one cell write to the whole selection (M4-F2, DR-063).
  ///
  /// Returns TRUE when it took the write, so the row does not also write
  /// itself. Three conditions, and all three are the ruling:
  ///
  ///   * the row being edited is IN the selection. Editing a row outside
  ///     it is an edit to that row, which is what a person means when
  ///     they click somewhere else;
  ///   * more than one row is selected, because a batch of one is a cell
  ///     edit and routing it through a transaction would relabel it in
  ///     the Edit menu for no reason;
  ///   * the column is batch-editable. `LABEL` and `DESIG` are not
  ///     (DR-063): one label across eight rows names eight ports the same
  ///     and mints eight colliding keys.
  bool _writeBatch(String portKey, PortColumnId column, Object? value) {
    if (_selection.length < 2) return false;
    if (!_selection.contains(portKey)) return false;
    if (!portColumnBatchEditable(column)) return false;

    final commands = buildBatchWrite(
      body: widget.body,
      column: column,
      portKeys: _selection.inOrder(_visibleRowKeys()),
      value: value,
    );
    // TAKEN EVEN WHEN EMPTY. Every selected row already holding the value
    // is a batch that changed nothing, not a batch that did not happen,
    // and returning false there would let the row write itself a second
    // time.
    if (commands.isNotEmpty) {
      widget.actions.transact(LabelKey.setPortProperty, (tx) {
        for (final command in commands) {
          tx.add(command);
        }
      });
    }
    return true;
  }

  /// The rows the grid is showing, which is what a batch acts on and what
  /// a `Shift` range walks (DR-061).
  List<String> _visibleRowKeys() {
    // SORTED, because "visible" means what is on screen. A `Shift` range,
    // a fill and a paste all walk this list, and under a sort the top of
    // the selection is the top of what the person can see (DR-061).
    final table = sortPortTable(
      buildPortTable(
        widget.body,
        portDesignatorFormat: widget.portDesignatorFormat,
      ),
      _sort,
      widget.registries,
    );
    return [
      for (final band in table.bands)
        if (!_collapsed.contains(band.bankKey))
          for (final row in band.rows) row.port.key.v,
    ];
  }

  /// The last thing handed to `onBatchContext`, so an unchanged selection
  /// does not call it every frame.
  ({int rows, int columns, String keys})? _reported;

  /// Tells the screen what the dock should show.
  ///
  /// POST-FRAME, AND THAT IS NOT A FLOURISH. This runs from `build`,
  /// because the selection is pruned there and the visible columns are
  /// computed there; calling the parent's `setState` from inside a build
  /// is the error Flutter names outright. The frame that reports is
  /// therefore one behind, which is invisible: the dock redraws on the
  /// next frame, and there is no next gesture inside one frame.
  void _reportBatchContext(
    List<String> visible,
    List<PortColumnId> columns,
  ) {
    final keys = _selection.inOrder(visible);
    final batch = [
      for (final id in columns)
        if (portColumnBatchEditable(id)) id,
    ];
    final stamp = (
      rows: keys.length,
      columns: batch.length,
      keys: keys.join(','),
    );
    if (_reported == stamp) return;
    _reported = stamp;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onBatchContext(
        keys.length < 2 ? null : (portKeys: keys, columns: batch),
      );
    });
  }

  /// A click in a row's body, with whatever modifiers were down.
  ///
  /// A PLAIN CLICK ON AN ALREADY-SELECTED ROW LEAVES THE SELECTION ALONE,
  /// which is not a nicety. F2 (`#209`) is "select N rows, edit any cell,
  /// it applies to every selected row": if clicking into a cell collapsed
  /// the selection to that row first, the feature could never fire, and it
  /// would fail silently by writing one row instead of N.
  void _onRowTap(String portKey, List<String> visible) {
    final keys = HardwareKeyboard.instance;
    setState(() {
      if (keys.isShiftPressed) {
        _selection = _selection.extendTo(portKey, visible);
      } else if (keys.isControlPressed || keys.isMetaPressed) {
        _selection = _selection.toggle(portKey);
      } else if (!_selection.contains(portKey)) {
        _selection = _selection.selectOnly(portKey);
      }
      // The complaint was about the selection that just changed, so it
      // stops being true the moment the person acts on it.
      _fillRefusal = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final table = sortPortTable(
      buildPortTable(
        widget.body,
        portDesignatorFormat: widget.portDesignatorFormat,
      ),
      _sort,
      widget.registries,
    );
    // Ports the user selected and then deleted, or that a rename moved:
    // dropped here rather than in the writer, so the count under the
    // buttons is never a count of rows that are not there. `prunedTo`
    // returns the same object when nothing changed, so this is not a new
    // selection on every frame.
    _selection = _selection.prunedTo({
      for (final port in widget.body.ports) port.key.v,
    });

    // The rows a person can actually see and therefore click, which is
    // what a `Shift`+click ranges over (DR-061): a collapsed band's rows
    // are absent, so a range drawn across a folded bank cannot sweep up
    // forty rows nobody can see.
    final visible = [
      for (final band in table.bands)
        if (!_collapsed.contains(band.bankKey))
          for (final row in band.rows) row.port.key.v,
    ];

    final issues = validatePorts(widget.body);
    final columns = portVisibleColumns(_openPacks());
    _reportBatchContext(visible, columns);

    // THE ACTIONS ARE HERE AND THE `Shortcuts` IS AT THE SCREEN.
    // `device_builder_screen.dart` already installs `KeyScope.builder`'s
    // map above everything, because `Ctrl+Enter` has to reach the rail
    // from the metadata form. A chord resolves to its intent up there and
    // then looks DOWN from the focused widget for an enabled handler, so
    // declaring these here is what keeps the fills acting on this grid's
    // own selection without the screen having to know it has one.
    return Actions(
      actions: <Type, Action<Intent>>{
        BuilderFillDownIntent: CallbackAction<BuilderFillDownIntent>(
          onInvoke: (_) {
            _fill(buildFillDown, visible);
            return null;
          },
        ),
        BuilderFillSeriesIntent: CallbackAction<BuilderFillSeriesIntent>(
          onInvoke: (_) {
            _fill(buildFillSeries, visible);
            return null;
          },
        ),
        BuilderCopyCellsIntent: CallbackAction<BuilderCopyCellsIntent>(
          onInvoke: (_) {
            _copy(visible, columns);
            return null;
          },
        ),
        BuilderPasteCellsIntent: CallbackAction<BuilderPasteCellsIntent>(
          onInvoke: (_) {
            unawaited(_paste(visible, columns));
            return null;
          },
        ),
        BuilderMoveRowIntent: CallbackAction<BuilderMoveRowIntent>(
          onInvoke: (intent) {
            _nudge(up: intent.up);
            return null;
          },
        ),
        BuilderDuplicateRowsIntent: CallbackAction<BuilderDuplicateRowsIntent>(
          onInvoke: (_) {
            _duplicate(visible);
            return null;
          },
        ),
        BuilderRenumberIntent: CallbackAction<BuilderRenumberIntent>(
          onInvoke: (_) {
            unawaited(_renumber(visible));
            return null;
          },
        ),
        BuilderMoveToBankIntent: CallbackAction<BuilderMoveToBankIntent>(
          onInvoke: (_) {
            unawaited(_moveToBank(visible));
            return null;
          },
        ),
        BuilderChangeTypeIntent: CallbackAction<BuilderChangeTypeIntent>(
          onInvoke: (_) {
            unawaited(_changeType(visible));
            return null;
          },
        ),
        BuilderFindReplaceIntent: CallbackAction<BuilderFindReplaceIntent>(
          onInvoke: (_) {
            unawaited(_findReplace(visible));
            return null;
          },
        ),
      },
      child: _grid(context, table, columns, visible, issues),
    );
  }

  Widget _grid(
    BuildContext context,
    PortTable table,
    List<PortColumnId> columns,
    List<String> visible,
    Map<String, List<PortIssue>> issues,
  ) {
    final total =
        kPortSelectGutter +
        columns.fold<double>(0, (n, c) => n + portColumnWidth(c));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // QUICK ADD SITS ABOVE THE TOOLBAR, which is docs/06 §2's own
        // layout and also the ordering the exit criterion needs: the
        // fast path is the first thing under the hand on entering the
        // section, and `+ Add port` stays as the slow path beneath it.
        QuickAddBar(
          body: widget.body,
          registries: widget.registries,
          onRun: _runQuickAdd,
          autofocus: widget.quickAddAutofocus,
        ),
        const Divider(height: 1),
        _Toolbar(
          selectedCount: _selection.length,
          onAdd: _addPort,
          onDelete: _selection.isEmpty ? null : _deleteSelected,
          openPacks: _openPacks(),
          onTogglePack: _togglePack,
          refusal: _fillRefusal,
        ),
        const Divider(height: 1),
        // ONLY WHEN THERE IS A SORT. A permanent bar reading "not sorted"
        // is a row of pixels spent saying nothing, and it would train a
        // person to stop reading the place the warning appears.
        if (_sort case final PortSort sort) ...[
          _SortBadge(
            sort: sort,
            onClear: () => setState(() => _sort = null),
            onCommit: () => unawaited(_commitSort()),
          ),
          const Divider(height: 1),
        ],
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Never squeezed below the authored widths: a narrow window
              // scrolls sideways, which is `_DropTable`'s rule and
              // docs/08 §6.2's for the printed page.
              final width = constraints.maxWidth > total
                  ? constraints.maxWidth
                  : total;
              final scale = width / total;
              return Scrollbar(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: width,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // THE HEADERS DRAW BEFORE ANY DATA EXISTS, which
                        // is what makes an empty grid readable rather
                        // than blank: a person can see what the columns
                        // will be before deciding what to type.
                        _HeaderRow(
                          scale: scale,
                          columns: columns,
                          sort: _sort,
                          onSort: _onSort,
                        ),
                        const Divider(height: 1, thickness: 1),
                        Expanded(
                          child: table.bands.isEmpty
                              ? const _NoPorts()
                              : _Bands(
                                  table: table,
                                  scale: scale,
                                  registries: widget.registries,
                                  portSets: widget.body.portSets,
                                  actions: widget.actions,
                                  keyFollows: _keyFollows,
                                  isPublished: widget.openedPortKeys.contains,
                                  takenKeys: {
                                    for (final p in widget.body.ports) p.key.v,
                                  },
                                  columns: columns,
                                  pairedWith: _pairs(),
                                  issues: issues,
                                  registriesForGender: widget.registries,
                                  onKeyTouched: widget.onKeyTouched,
                                  collapsed: _collapsed,
                                  selection: _selection,
                                  onToggleBand: (key) => setState(() {
                                    if (!_collapsed.remove(key)) {
                                      _collapsed.add(key);
                                    }
                                  }),
                                  // THE TICK BOX IS Ctrl+CLICK (DR-061),
                                  // which is why it takes no `on`: a
                                  // checkbox that reported its own new
                                  // value would be a second opinion about
                                  // what the selection holds.
                                  onToggleRow: (key) => setState(() {
                                    _selection = _selection.toggle(key);
                                  }),
                                  onTapRow: (key) => _onRowTap(key, visible),
                                  // NO `setState`. Nothing on screen is
                                  // drawn from the focused column, and a
                                  // rebuild of a 68-row grid on every
                                  // Tab would be a cost paid for no
                                  // pixel. F1 reads it at the moment
                                  // Ctrl+D is pressed.
                                  onColumnFocused: (id) =>
                                      _selection = _selection.withColumn(id),
                                  onBatchWrite: _writeBatch,
                                  onReorder: _reorder,
                                  dragDisabled: _sort != null,
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const Divider(height: 1),
        _Footer(summary: buildPortSummary(widget.body, widget.registries)),
      ],
    );
  }
}

/// docs/06 §4.5's one-line readout, always visible.
///
/// OUTSIDE THE HORIZONTAL SCROLL, so it stays put while the columns move
/// under it. A footer that scrolled sideways with the grid would be off
/// screen exactly when a wide template made it most useful.
///
/// THE SENTENCE IS BUILT IN CORE. This widget draws a string and knows
/// nothing about PoE, faces or connector names, which is what stops the
/// footer and the equipment list ever disagreeing about how many HDMI
/// ports a device has.
class _Footer extends StatelessWidget {
  const _Footer({required this.summary});

  final PortSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ColoredBox(
      color: theme.colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          portSummaryLine(summary),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelMedium,
        ),
      ),
    );
  }
}

/// The tick-box gutter plus the validation dot, in the same points the
/// columns are authored in.
///
/// THE DOT IS IN THE GUTTER AND NOT IN A COLUMN, which is docs/06 §4.5's
/// word ("a severity dot in the row gutter") and is also the only place
/// it can go: a finding is about the ROW, and half of them name a column
/// that may not be showing.
///
/// 56 UNTIL M4-F4 PUT A DRAG HANDLE IN FRONT OF THE TICK BOX. §4.5's
/// column table opens with `⠿` and the handle is 16 points plus the two
/// the row already had no slack for, which is where the 20 went.
const double kPortSelectGutter = 76;

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.selectedCount,
    required this.onAdd,
    required this.onDelete,
    required this.openPacks,
    required this.onTogglePack,
    required this.refusal,
  });

  final int selectedCount;
  final VoidCallback onAdd;
  final VoidCallback? onDelete;
  final Set<PortColumnPack> openPacks;
  final void Function(PortColumnPack pack, {required bool on}) onTogglePack;

  /// Why the last fill did nothing, or null.
  ///
  /// BESIDE THE SELECTION COUNT, which is the other thing on this row
  /// that is about what the keys will act on. It is not a `SnackBar`: a
  /// message that slides away on a timer is gone by the time somebody
  /// has finished wondering why `Ctrl+D` appeared to do nothing.
  final String? refusal;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    child: Row(
      children: [
        FilledButton.tonalIcon(
          onPressed: onAdd,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add port'),
        ),
        const SizedBox(width: 8),
        TextButton.icon(
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline, size: 18),
          // COUNTS WHAT IT WILL DELETE. A bare "Delete" beside a grid of
          // 68 rows does not say whether it means the selected rows or
          // all of them, and the answer matters most to the person who is
          // about to find out.
          label: Text(
            selectedCount == 0 ? 'Delete' : 'Delete $selectedCount selected',
          ),
        ),
        if (refusal case final String message) ...[
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
        const Spacer(),
        // ═══════════════════════════════════════════════════════════════
        // TICKS, NOT A LIST OF NAMES, AND THE STATE IS ALREADY DECIDED
        // ═══════════════════════════════════════════════════════════════
        // Every pack opens itself when the bank's own traffic calls for
        // it, so this menu opens showing what the grid decided, and a
        // tick a person changes OVERRIDES that for the rest of the
        // session. Without the override, closing a pack the auto-reveal
        // wants would last exactly one rebuild.
        MenuAnchor(
          menuChildren: [
            for (final pack in PortColumnPack.values)
              MenuItemButton(
                closeOnActivate: false,
                leadingIcon: Icon(
                  openPacks.contains(pack)
                      ? Icons.check_box
                      : Icons.check_box_outline_blank,
                  size: 18,
                ),
                onPressed: () =>
                    onTogglePack(pack, on: !openPacks.contains(pack)),
                child: Text(pack.label),
              ),
          ],
          builder: (context, controller, child) => TextButton.icon(
            onPressed: () =>
                controller.isOpen ? controller.close() : controller.open(),
            icon: const Icon(Icons.settings_outlined, size: 18),
            label: const Text('Columns'),
          ),
        ),
      ],
    ),
  );
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({
    required this.scale,
    required this.columns,
    required this.sort,
    required this.onSort,
  });

  final double scale;
  final List<PortColumnId> columns;

  /// The view sort, or null for the declared order (M4-F5).
  final PortSort? sort;

  final ValueChanged<PortColumnId> onSort;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          SizedBox(width: kPortSelectGutter * scale),
          for (final id in columns)
            SizedBox(
              width: portColumnWidth(id) * scale,
              child: InkWell(
                // THE WHOLE HEADER CELL, not the word. A four-character
                // header like `KEY` is a tap target the width of three
                // letters, and this is the only affordance a sort has.
                onTap: portColumnSortable(id) ? () => onSort(id) : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          portColumnHeader(id),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                            // THE SORTED COLUMN IS TONED AS WELL AS
                            // ARROWED, because at 11 points an arrow is
                            // four pixels and a person scanning 43 columns
                            // for which one is sorted needs the answer
                            // from the shape of the row.
                            color: sort?.column == id
                                ? theme.colorScheme.primary
                                : null,
                          ),
                        ),
                      ),
                      if (sort?.column == id)
                        Icon(
                          sort!.direction == PortSortDirection.ascending
                              ? Icons.arrow_upward
                              : Icons.arrow_downward,
                          size: 12,
                          color: theme.colorScheme.primary,
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// docs/06 §4.6's sort badge, which is the only thing telling a person the
/// rows in front of them are not the rows in the file.
///
/// ═══════════════════════════════════════════════════════════════════════
/// IT IS A BAR AND NOT A CHIP, AND IT CARRIES BOTH EXITS
/// ═══════════════════════════════════════════════════════════════════════
/// A sort is a state the grid can be left in, and every state a person can
/// be stuck in needs its way out on screen beside the thing that says they
/// are in it. `Clear` restores the declared order and costs nothing;
/// `Commit sort order` writes it and goes through the confirm AC-058/D5
/// requires. Putting the destructive one in a menu somewhere else would
/// leave the badge saying "this is only a view" with no answer to the
/// obvious next question.
class _SortBadge extends StatelessWidget {
  const _SortBadge({
    required this.sort,
    required this.onClear,
    required this.onCommit,
  });

  final PortSort sort;
  final VoidCallback onClear;
  final VoidCallback onCommit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ColoredBox(
      color: theme.colorScheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
        child: Row(
          children: [
            Icon(
              Icons.sort,
              size: 18,
              color: theme.colorScheme.onTertiaryContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                // THE SENTENCE IS BUILT IN CORE, for `portSummaryLine`'s
                // reason: a second speller here and the badge and the
                // confirm would disagree about what a sort is.
                portSortBadge(sort),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onTertiaryContainer,
                ),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(onPressed: onClear, child: const Text('Clear sort')),
            const SizedBox(width: 4),
            TextButton(
              onPressed: onCommit,
              child: const Text('Commit sort order'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bands extends StatelessWidget {
  const _Bands({
    required this.table,
    required this.scale,
    required this.registries,
    required this.portSets,
    required this.actions,
    required this.keyFollows,
    required this.isPublished,
    required this.takenKeys,
    required this.columns,
    required this.pairedWith,
    required this.issues,
    required this.registriesForGender,
    required this.onKeyTouched,
    required this.collapsed,
    required this.selection,
    required this.onToggleBand,
    required this.onToggleRow,
    required this.onTapRow,
    required this.onColumnFocused,
    required this.onBatchWrite,
    required this.onReorder,
    required this.dragDisabled,
  });

  final PortTable table;
  final double scale;
  final Registries registries;
  final List<PortSetDef> portSets;
  final PortGridActions actions;
  final bool Function(PortDef port) keyFollows;
  final bool Function(String portKey) isPublished;
  final Set<String> takenKeys;
  final List<PortColumnId> columns;
  final Map<String, String> pairedWith;
  final Map<String, List<PortIssue>> issues;
  final Registries registriesForGender;
  final void Function(String was, String now) onKeyTouched;
  final Set<String?> collapsed;
  final PortSelection selection;
  final ValueChanged<String?> onToggleBand;
  final ValueChanged<String> onToggleRow;
  final ValueChanged<String> onTapRow;
  final ValueChanged<PortColumnId> onColumnFocused;
  final bool Function(String portKey, PortColumnId column, Object? value)
  onBatchWrite;

  /// A row dropped: which band, where it came from, and where it landed
  /// in the band with itself already taken out.
  final void Function(PortTableBand band, int from, int at) onReorder;

  /// True while a view sort is showing (M4-F5, DR-065): the handle greys
  /// out, because dragging a row would land it where the person cannot
  /// see it. The keyboard's half of this refuses in words.
  final bool dragDisabled;

  @override
  Widget build(BuildContext context) => CustomScrollView(
    slivers: [
      for (final band in table.bands) ...[
        // PINNED, which is what a sticky band header means: a person
        // forty rows into the HDMI inputs must still be able to see that
        // these are the HDMI inputs.
        SliverPersistentHeader(
          pinned: true,
          delegate: _BandDelegate(
            band: band,
            collapsed: collapsed.contains(band.bankKey),
            onToggle: () => onToggleBand(band.bankKey),
            theme: Theme.of(context),
          ),
        ),
        if (!collapsed.contains(band.bankKey))
          // ONE REORDERABLE LIST PER BAND, WHICH IS WHY THE BAND EDGE IS
          // A WALL (DR-064). Flutter's reorderable lists do not hand an
          // item to a sibling list, and the alternative was one flat list
          // with the bank headers as ordinary items in it, which would
          // cost the pinned header a person forty rows into the HDMI
          // inputs is reading to know they are the HDMI inputs. The Bank
          // column is the way across, and the refusal names it.
          SliverReorderableList(
            itemCount: band.rows.length,
            // `onReorderItem` and not `onReorder`: the older callback
            // reports a `to` measured against the list BEFORE the dragged
            // row leaves it, so dropping row 0 at the foot answers
            // `length` rather than `length - 1`. Flutter deprecated it for
            // exactly that off-by-one, and the replacement has already
            // subtracted.
            onReorderItem: (from, to) => onReorder(band, from, to),
            // NO LIFT ANIMATION ON A GRID ROW. The default proxy scales
            // and elevates the dragged item, which on a row 1400 points
            // wide with cell borders reads as the row breaking apart
            // rather than being carried.
            proxyDecorator: (child, index, animation) => Material(
              elevation: 4,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: child,
            ),
            itemBuilder: (context, index) => _PortRow(
              // KEYED ON THE PORT, so that when M4-E2 puts a
              // `TextField` in a cell its controller follows the PORT
              // rather than the row position. Adding, deleting or
              // collapsing reshuffles the list, and an unkeyed row
              // would hand row 3's controller to whatever port is
              // third afterwards.
              key: ValueKey(band.rows[index].port.key.v),
              row: band.rows[index],
              dragIndex: index,
              scale: scale,
              registries: registries,
              portSets: portSets,
              actions: actions,
              keyFollowsLabel: keyFollows(band.rows[index].port),
              keyIsPublished: isPublished(band.rows[index].port.key.v),
              takenKeys: takenKeys,
              columns: columns,
              pairedWith: pairedWith[band.rows[index].port.key.v],
              issues:
                  issues[band.rows[index].port.key.v] ?? const <PortIssue>[],
              genderApplies: portGenderApplies(
                registriesForGender,
                band.rows[index].port.connector,
              ),
              onKeyTouched: onKeyTouched,
              selected: selection.contains(band.rows[index].port.key.v),
              onToggleRow: onToggleRow,
              onTapRow: onTapRow,
              onColumnFocused: onColumnFocused,
              onBatchWrite: onBatchWrite,
              dragDisabled: dragDisabled,
            ),
          ),
      ],
    ],
  );
}

class _BandDelegate extends SliverPersistentHeaderDelegate {
  _BandDelegate({
    required this.band,
    required this.collapsed,
    required this.onToggle,
    required this.theme,
  });

  final PortTableBand band;
  final bool collapsed;
  final VoidCallback onToggle;
  final ThemeData theme;

  static const double _height = 30;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) {
    final scheme = theme.colorScheme;
    // A bank key nothing declares is toned apart from a real bank, for
    // the Structure editor's reason on its no-room band: it is not a
    // grouping the author made, and a reader skimming for banks must not
    // mistake it for one.
    final background = band.isUndeclaredBank
        ? scheme.errorContainer
        : scheme.surfaceContainerHigh;
    final foreground = band.isUndeclaredBank
        ? scheme.onErrorContainer
        : scheme.onSurface;
    return Material(
      color: background,
      child: InkWell(
        onTap: onToggle,
        // FILLS THE EXTENT IT DECLARED. A sliver header whose child sizes
        // itself to its content paints 20 points where it said 30 and the
        // framework asserts, which is what a `Padding` around a `Row` of
        // 18-point icons does. Expanding is also what makes the whole
        // band a tap target rather than only the words in it.
        child: SizedBox.expand(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                Icon(
                  collapsed ? Icons.chevron_right : Icons.expand_more,
                  size: 18,
                  color: foreground,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    band.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (band.isUndeclaredBank)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      'No such bank',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: foreground,
                      ),
                    ),
                  ),
                Text(
                  band.portCount == 1 ? '1 port' : '${band.portCount} ports',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: foreground,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_BandDelegate old) =>
      old.band != band || old.collapsed != collapsed || old.theme != theme;
}

class _PortRow extends StatelessWidget {
  const _PortRow({
    required this.row,
    required this.dragIndex,
    required this.scale,
    required this.registries,
    required this.portSets,
    required this.actions,
    required this.keyFollowsLabel,
    required this.keyIsPublished,
    required this.takenKeys,
    required this.columns,
    required this.pairedWith,
    required this.genderApplies,
    required this.issues,
    required this.onKeyTouched,
    required this.selected,
    required this.onToggleRow,
    required this.onTapRow,
    required this.onColumnFocused,
    required this.onBatchWrite,
    required this.dragDisabled,
    super.key,
  });

  /// True while a view sort is showing: the handle is drawn dimmed and
  /// inert rather than removed, so the gutter does not reflow and the
  /// affordance is visibly unavailable rather than absent.
  final bool dragDisabled;

  final PortTableRow row;

  /// This row's position within its BAND, which is the index
  /// `SliverReorderableList` speaks in. Not `portSeq`: that one counts the
  /// whole template and the two part the moment a second bank exists.
  final int dragIndex;

  final double scale;
  final Registries registries;
  final List<PortSetDef> portSets;
  final PortGridActions actions;

  /// Every port key on this template, so an automatic key can be made
  /// unique without asking the body again.
  final Set<String> takenKeys;

  /// The columns to draw, core plus whichever packs are open.
  final List<PortColumnId> columns;

  /// The key this port is paired with, for the Passthrough pack. Read
  /// only: pairing is M4-J3 (`#225`).
  final String? pairedWith;

  /// Whether GENDER may be edited here (CR-059, gated on the registry's
  /// `genderApplies` for this port's connector).
  final bool genderApplies;

  /// What live validation has to say about this port (M4-E4). Empty is
  /// the ordinary case and draws nothing at all.
  final List<PortIssue> issues;

  /// Whether typing a LABEL should carry the key along with it.
  final bool keyFollowsLabel;

  /// Whether this port was in the template when the builder opened, which
  /// is what decides whether a rename records an alias (CR-051).
  final bool keyIsPublished;

  final void Function(String was, String now) onKeyTouched;

  final bool selected;

  /// `Ctrl`+click, and the tick box, which DR-061 makes one gesture.
  final ValueChanged<String> onToggleRow;

  /// A click in the row's BODY, which reads its own modifiers.
  final ValueChanged<String> onTapRow;

  /// Which column focus just landed in, which is the half of DR-061's
  /// selection that is not rows. `Fill down` (F1) is what reads it.
  final ValueChanged<PortColumnId> onColumnFocused;

  /// Offers a cell write to the selection first. True when the grid took
  /// it as a batch (M4-F2), false when this row should write alone.
  ///
  /// A PREDICATE RATHER THAN A FLAG PASSED DOWN, because whether a write
  /// is a batch depends on the SELECTION, which the row does not hold and
  /// should not: a row that knew the selection would rebuild whenever it
  /// changed.
  final bool Function(String portKey, PortColumnId column, Object? value)
  onBatchWrite;

  PortDef get _port => row.port;

  /// Writes one cell, or the whole selection when this row is part of one.
  ///
  /// THE COLUMN IS A PARAMETER BECAUSE THE BATCH RULE IS PER COLUMN.
  /// DR-063 keeps `LABEL` and `DESIG` single-row, so `_set` cannot decide
  /// from the `PortField` alone: the field knows what it writes and not
  /// which column drew the control. Every call below sits inside
  /// [_cell]'s switch, where `id` is already in hand.
  void _set<T>(PortColumnId id, PortField<T> field, T value) {
    if (onBatchWrite(_port.key.v, id, value)) return;
    if (field.get(_port) == value) return;
    actions.run(
      SetPortFieldCommand<T>(
        port: _port.key,
        field: field,
        from: field.get(_port),
        to: value,
      ),
    );
  }

  /// The Key cell, typed by hand. Records the rename and stops the
  /// automatic following for good.
  void _renameKey(String typed) {
    final now = typed.trim();
    if (now.isEmpty || now == _port.key.v) return;
    onKeyTouched(_port.key.v, now);
    actions.run(
      RenamePortKeyCommand(
        from: _port.key,
        to: PortKey(now),
        recordAlias: keyIsPublished,
      ),
    );
  }

  /// The Label cell, which may drag the key behind it.
  ///
  /// ONE TRANSACTION, so the pair is one `Ctrl+Z`. A user who types a
  /// label and undoes once expects the label back, not a key left holding
  /// a slug of a name that no longer exists.
  void _setLabel(String typed) {
    final label = typed.trim();
    if (label == _port.label) return;
    if (!keyFollowsLabel) {
      _set(PortColumnId.label, PortDefField.label, label);
      return;
    }
    final wanted = autoPortKey(
      label,
      // ITS OWN KEY IS NOT TAKEN, by itself. Leaving it in would suffix
      // every port that already matches its label to `.2` the moment the
      // label is corrected for a typo.
      taken: {...takenKeys}..remove(_port.key.v),
      ordinal: 1,
    );
    actions.transact(LabelKey.setPortProperty, (tx) {
      tx.add(
        SetPortFieldCommand<String>(
          port: _port.key,
          field: PortDefField.label,
          from: _port.label,
          to: label,
        ),
      );
      if (wanted.v != _port.key.v) {
        tx.add(
          RenamePortKeyCommand(
            from: _port.key,
            to: wanted,
            // NEVER, on this path. The key being replaced is one this
            // editor invented seconds ago and no project has ever seen,
            // so recording it as a former name would put a working title
            // in the file permanently (CR-051).
            recordAlias: false,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        // The tint `locations_panel.dart` already uses for a selected row,
        // so the two lists in this app agree on what selected looks like.
        // Behind the cells rather than over them: an overlay would tint
        // the text a person is editing.
        color: selected ? theme.colorScheme.primaryContainer : null,
        border: Border(
          bottom: BorderSide(color: theme.dividerColor.withValues(alpha: 0.4)),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: kPortSelectGutter * scale,
            child: Row(
              children: [
                // docs/06 §4.5's first column, and the reason it is a
                // HANDLE rather than the whole row being draggable: the
                // row body is already a click target that selects and
                // opens a cell for editing, and a press that might mean
                // either would have to guess from how far the pointer
                // travelled.
                if (dragDisabled)
                  Tooltip(
                    message: 'Clear the sort to reorder rows',
                    child: Icon(
                      Icons.drag_indicator,
                      size: 16,
                      color: theme.disabledColor,
                    ),
                  )
                else
                  ReorderableDragStartListener(
                    index: dragIndex,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.grab,
                      child: Tooltip(
                        message: 'Drag to reorder · Alt+Up, Alt+Down',
                        child: Icon(
                          Icons.drag_indicator,
                          size: 16,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                // SHRUNK, because a `Checkbox` reserves Material's 48-point
                // TAP TARGET by default and the gutter now has to hold a
                // dot beside it. Measured: the default overflowed this row
                // by 2.2 points.
                Checkbox(
                  value: selected,
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  // IGNORES THE VALUE IT IS HANDED. The selection is the
                  // authority on what is selected; a checkbox reporting
                  // its own new state would be a second opinion, and the
                  // two would part the first time a range replaced the set
                  // under it.
                  onChanged: (_) => onToggleRow(_port.key.v),
                ),
                _IssueDot(issues: issues),
              ],
            ),
          ),
          // THE CELLS ARE THE CLICK TARGET, AND THE GUTTER IS NOT.
          //
          // `Listener` on pointer-down rather than a `GestureDetector`, so
          // the cells underneath still take focus and still edit: the row
          // is selected AND the text field opens, which is what a person
          // clicking a cell in a spreadsheet gets. `translucent`, because
          // the padding between cells is part of the row.
          //
          // The gutter sits outside it on purpose. Inside, a tap on the
          // checkbox would run both handlers and toggle twice, ending on
          // the state it started in.
          Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (_) => onTapRow(_port.key.v),
            child: Row(
              children: [
                for (final id in columns)
                  SizedBox(
                    width: portColumnWidth(id) * scale,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      // A LISTENER, NOT A STOP. `canRequestFocus: false`
                      // and `skipTraversal: true` keep this node out of
                      // the tab order and out of the directional
                      // traversal Enter uses, so it reports which column
                      // has focus without becoming a place focus can
                      // land. Wrapping the cell rather than asking each
                      // control to report is what makes the dropdowns and
                      // the two menu cells answer as well as the text
                      // boxes.
                      child: Focus(
                        canRequestFocus: false,
                        skipTraversal: true,
                        onFocusChange: (has) {
                          if (has) onColumnFocused(id);
                        },
                        child: _cell(context, id),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// This column's editor for this port.
  ///
  /// EVERY SPELLING COMES FROM CORE. The moment this file writes
  /// `port.direction.name` it owns a second vocabulary, and the first
  /// time one of them changes they disagree on a printed schedule.
  Widget _cell(BuildContext context, PortColumnId id) => switch (id) {
    // THE KEY IS GREY UNTIL IT IS TOUCHED (docs/06 §4.5), because while
    // it follows the label it is not a value the author has chosen.
    PortColumnId.portKey => PortTextCell(
      value: _port.key.v,
      automatic: keyFollowsLabel,
      onCommit: _renameKey,
    ),
    PortColumnId.label => PortTextCell(
      value: _port.label,
      hint: 'HDMI IN 1',
      onCommit: _setLabel,
    ),
    PortColumnId.designator => PortTextCell(
      value: row.isDesignatorPinned ? _port.designatorHint : row.autoDesignator,
      // AUTOMATIC VALUES ARE ITALIC AND PINNED ONES ARE NOT (docs/06
      // §4.5). One glance says which designators a renumber would move
      // and which the author fixed.
      automatic: !row.isDesignatorPinned,
      // EMPTY MEANS BACK TO AUTOMATIC, not "deliberately unnumbered".
      onCommit: (v) => _set(
        id,
        PortDefField.designatorHint,
        v.trim().isEmpty ? null : v.trim(),
      ),
    ),
    PortColumnId.connector => PortConnectorCell(
      registries: registries,
      value: _port.connector,
      onPick: (v) => _set(id, PortDefField.connector, v),
    ),
    PortColumnId.family => PortFamilyCell(
      registries: registries,
      value: _port.signalFamily,
      onPick: (v) => _set(id, PortDefField.signalFamily, v),
    ),
    PortColumnId.direction => PortChoiceCell<PortDirection>(
      value: _port.direction,
      options: PortDirection.values,
      label: portDirectionLabel,
      onPick: (v) => _set(id, PortDefField.direction, v),
    ),
    PortColumnId.face => PortChoiceCell<Face>(
      value: _port.face,
      options: Face.values,
      label: portFaceLabel,
      onPick: (v) => _set(id, PortDefField.face, v),
    ),
    PortColumnId.portSet => PortChoiceCell<String?>(
      value: _port.setKey,
      // NULL IS AN OPTION AND IS LISTED FIRST. Most ports belong to no
      // set, and a dropdown a person cannot get back out of is worse
      // than one they never opened.
      options: [null, for (final set in portSets) set.key],
      label: (v) => v == null
          ? kUnknownCell
          : portSets.firstWhere((s) => s.key == v).label,
      onPick: (v) => _set(id, PortDefField.setKey, v),
    ),
    PortColumnId.setRole => PortTextCell(
      value: _port.setRole,
      hint: 'L',
      onCommit: (v) =>
          _set(id, PortDefField.setRole, v.trim().isEmpty ? null : v.trim()),
    ),
    PortColumnId.notes => PortTextCell(
      value: _port.notes,
      onCommit: (v) => _set(id, PortDefField.notes, _orNull(v)),
    ),
    PortColumnId.impedanceOhms => PortNumberCell(
      value: _port.impedanceOhms,
      hint: '75',
      onCommit: (v) => _set(id, PortDefField.impedanceOhms, v),
    ),
    PortColumnId.audioLevel => PortNullableChoiceCell<AudioLevel>(
      value: _port.level,
      options: AudioLevel.values,
      label: portAudioLevelLabel,
      onPick: (v) => _set(id, PortDefField.audioLevel, v),
    ),
    PortColumnId.balanced => PortTriStateCell(
      value: _port.balanced,
      onPick: (v) => _set(id, PortDefField.balanced, v),
    ),
    PortColumnId.phantomPower => PortTriStateCell(
      value: _port.phantomPowerCapable,
      onPick: (v) => _set(id, PortDefField.phantomPower, v),
    ),
    PortColumnId.polarity => PortNullableChoiceCell<Polarity>(
      value: _port.polarity,
      options: Polarity.values,
      label: portPolarityLabel,
      onPick: (v) => _set(id, PortDefField.polarity, v),
    ),
    PortColumnId.nominalVoltage => PortNumberCell(
      value: _port.nominalVoltage,
      onCommit: (v) => _set(id, PortDefField.nominalVoltage, v),
    ),
    PortColumnId.maxCurrentMa => PortNumberCell(
      value: _port.maxCurrentMa,
      onCommit: (v) => _set(id, PortDefField.maxCurrentMa, v),
    ),
    PortColumnId.poeRole => PortNullableChoiceCell<PoeRole>(
      value: _port.poe?.role,
      options: PoeRole.values,
      label: portPoeRoleLabel,
      onPick: (v) => _set(id, PortDefField.poeRole, v),
    ),
    PortColumnId.poeStandard => PortNullableChoiceCell<PoeStandard>(
      value: _port.poe?.standard,
      options: PoeStandard.values,
      label: portPoeStandardLabel,
      onPick: (v) => _set(id, PortDefField.poeStandard, v),
    ),
    PortColumnId.poeType => PortNumberCell(
      value: _port.poe?.type,
      onCommit: (v) => _set(id, PortDefField.poeType, v),
    ),
    PortColumnId.poeClass => PortNumberCell(
      value: _port.poe?.poeClass,
      onCommit: (v) => _set(id, PortDefField.poeClass, v),
    ),
    PortColumnId.poeWatts => PortNumberCell(
      value: _port.poe?.watts,
      onCommit: (v) => _set(id, PortDefField.poeWatts, v),
    ),
    PortColumnId.linkSpeedMbps => PortNumberCell(
      value: _port.linkSpeedMbps,
      hint: '1000',
      onCommit: (v) => _set(id, PortDefField.linkSpeedMbps, v),
    ),
    PortColumnId.sfpFormFactor => PortNullableChoiceCell<SfpFormFactor>(
      value: _port.sfp,
      options: SfpFormFactor.values,
      label: portSfpLabel,
      onPick: (v) => _set(id, PortDefField.sfpFormFactor, v),
    ),
    PortColumnId.fiberMode => PortNullableChoiceCell<FiberMode>(
      value: _port.fiberMode,
      options: FiberMode.values,
      label: portFiberModeLabel,
      onPick: (v) => _set(id, PortDefField.fiberMode, v),
    ),
    PortColumnId.wavelengthNm => PortNumberCell(
      value: _port.wavelengthNm,
      hint: '1310',
      onCommit: (v) => _set(id, PortDefField.wavelengthNm, v),
    ),
    PortColumnId.serialRole => PortNullableChoiceCell<SerialRole>(
      value: _port.serial?.role,
      options: SerialRole.values,
      label: portSerialRoleLabel,
      onPick: (v) => _set(id, PortDefField.serialRole, v),
    ),
    PortColumnId.baud => PortNumberCell(
      value: _port.serial?.baud,
      hint: '9600',
      onCommit: (v) => _set(id, PortDefField.baud, v),
    ),
    PortColumnId.dataBits => PortNumberCell(
      value: _port.serial?.dataBits,
      hint: '8',
      onCommit: (v) => _set(id, PortDefField.dataBits, v),
    ),
    PortColumnId.stopBits => PortNumberCell(
      value: _port.serial?.stopBits,
      hint: '1',
      onCommit: (v) => _set(id, PortDefField.stopBits, v),
    ),
    PortColumnId.parity => PortTextCell(
      value: _port.serial?.parity,
      hint: 'none',
      onCommit: (v) => _set(id, PortDefField.parity, _orNull(v)),
    ),
    PortColumnId.flowControl => PortTextCell(
      value: _port.serial?.flowControl,
      hint: 'none',
      onCommit: (v) => _set(id, PortDefField.flowControl, _orNull(v)),
    ),
    PortColumnId.busProtocol => PortTextCell(
      value: _port.bus?.protocol,
      hint: 'rs485',
      onCommit: (v) => _set(id, PortDefField.busProtocol, _orNull(v)),
    ),
    PortColumnId.busTermination => PortTriStateCell(
      value: _port.bus?.supportsTermination,
      onPick: (v) => _set(id, PortDefField.busTermination, v),
    ),
    PortColumnId.busUnitLoads => PortNumberCell(
      value: _port.bus?.unitLoads,
      onCommit: (v) => _set(id, PortDefField.busUnitLoads, v),
    ),
    PortColumnId.busAddressable => PortTriStateCell(
      value: _port.bus?.addressable,
      onPick: (v) => _set(id, PortDefField.busAddressable, v),
    ),
    PortColumnId.busMaxTapWatts => PortNumberCell(
      value: _port.bus?.maxTapWatts,
      onCommit: (v) => _set(id, PortDefField.busMaxTapWatts, v),
    ),
    PortColumnId.powerRole => PortNullableChoiceCell<PortPowerRole>(
      value: _port.power?.role,
      options: PortPowerRole.values,
      label: portPowerRoleLabel,
      onPick: (v) => _set(id, PortDefField.powerRole, v),
    ),
    PortColumnId.powerVolts => PortNumberCell(
      value: _port.power?.volts,
      hint: '120',
      onCommit: (v) => _set(id, PortDefField.powerVolts, v),
    ),
    PortColumnId.powerDrawWatts => PortNumberCell(
      value: _port.power?.drawWatts,
      onCommit: (v) => _set(id, PortDefField.powerDrawWatts, v),
    ),
    PortColumnId.powerMaxAmps => PortNumberCell(
      value: _port.power?.maxAmps,
      onCommit: (v) => _set(id, PortDefField.powerMaxAmps, v),
    ),
    // READ-ONLY, AND SAYS SO BY BEING TEXT. Pairing is M4-J3 (`#225`),
    // which owns the bank-level `Pair front to rear by order` action;
    // typing a key into a cell here would write half a pair.
    PortColumnId.pairedPort => PortReadOnlyCell(value: pairedWith),
    PortColumnId.maxConnections => PortNumberCell(
      value: _port.maxConnections,
      onCommit: (v) => _set(id, PortDefField.maxConnections, v ?? 1),
    ),
    PortColumnId.topology => PortChoiceCell<PortTopology>(
      value: _port.topology,
      options: PortTopology.values,
      label: portTopologyLabel,
      onPick: (v) => _set(id, PortDefField.topology, v),
    ),
    // GATED ON THE CONNECTOR (CR-059, M4-B). Gender is meaningless on an
    // RJ45 and load-bearing on an XLR, and `genderApplies` is the field
    // M4-B authored to say which. A disabled cell rather than a hidden
    // one: the column is open because the person opened the pack, and a
    // gap where a control should be reads as a rendering fault.
    PortColumnId.gender =>
      genderApplies
          ? PortChoiceCell<Gender>(
              value: _port.gender,
              options: Gender.values,
              label: portGenderLabel,
              onPick: (v) => _set(id, PortDefField.gender, v),
            )
          : const PortReadOnlyCell(
              value: null,
              tooltip: 'This connector has no gender.',
            ),
    PortColumnId.pinoutVariant => PortTextCell(
      value: _port.pinoutVariant,
      hint: 'emitter',
      onCommit: (v) => _set(id, PortDefField.pinoutVariant, _orNull(v)),
    ),
    PortColumnId.conductorCount => PortNumberCell(
      value: _port.conductorCount,
      onCommit: (v) => _set(id, PortDefField.conductorCount, v),
    ),
    PortColumnId.returnChannel => PortNullableChoiceCell<ReturnChannel>(
      value: _port.returnChannel,
      options: ReturnChannel.values,
      label: portReturnChannelLabel,
      onPick: (v) => _set(id, PortDefField.returnChannel, v),
    ),
    // READ-ONLY: `renamedFrom` is written by a rename, never typed.
    PortColumnId.renamedFrom => PortReadOnlyCell(
      value: _port.renamedFrom.isEmpty
          ? null
          : _port.renamedFrom.map((k) => k.v).join(', '),
    ),
  };

  static String? _orNull(String v) => v.trim().isEmpty ? null : v.trim();
}

/// The severity dot docs/06 §4.5 puts in the row gutter.
///
/// ═══════════════════════════════════════════════════════════════════════
/// IT NEVER BLOCKS ANYTHING, AND THE SHAPE SAYS SO
/// ═══════════════════════════════════════════════════════════════════════
/// A filled dot for a warning, a hollow one for a notice, and nothing at
/// all for a clean row. No red cross, no disabled Save, no banner: AC-049
/// rules that three fields make a template, and a checker that can stop a
/// save is a fourth required field wearing a warning triangle.
///
/// SHAPE AND NOT COLOUR ALONE, which is the same discipline CR-078 fixes
/// for the schematic: hue is never the only channel, because a reader who
/// cannot separate two hues has to be able to separate two marks.
class _IssueDot extends StatelessWidget {
  const _IssueDot({required this.issues});

  final List<PortIssue> issues;

  @override
  Widget build(BuildContext context) {
    final worst = worstIssue(issues);
    if (worst == null) return const SizedBox(width: 18);
    final scheme = Theme.of(context).colorScheme;
    final warning = worst == PortIssueSeverity.warning;
    return Tooltip(
      // EVERY finding, not just the loudest. A row can be an IR port with
      // no pinout AND share a designator, and fixing one would otherwise
      // leave a dot with a sentence the person has already read.
      message: [for (final issue in issues) issue.message].join('\n\n'),
      child: SizedBox(
        width: 18,
        child: Icon(
          warning ? Icons.circle : Icons.circle_outlined,
          size: 10,
          color: warning ? scheme.error : scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// A template with no ports, which is every template the moment it is
/// created.
class _NoPorts extends StatelessWidget {
  const _NoPorts();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        // SAYS WHAT TO DO NEXT, and does not call the state a problem. A
        // template with a name, a height and a prefix is finished
        // (AC-049); ports are what make it useful, not what make it
        // valid, and the empty grid is the first thing every new
        // template shows.
        'No ports yet. Add one to start listing what plugs into this '
        'device.',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    ),
  );
}
