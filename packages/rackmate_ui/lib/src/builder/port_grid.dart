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
import 'package:flutter/material.dart';
import 'package:rackmate_core/rackmate_core.dart';
import 'package:rackmate_ui/src/widgets/family_picker.dart';

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
    this.portDesignatorFormat = const IdFormat('J{PORT_SEQ:2}'),
    super.key,
  });

  /// The session's LIVE body. Read only through [buildPortTable]; every
  /// write goes through [actions].
  final TemplateBody body;

  /// For the connector and signal-family display names. A port naming
  /// something this does not hold still draws, showing the raw id.
  final Registries registries;

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

  /// Ticked rows, by port key. Held as strings rather than `PortKey`
  /// because a rename replaces the key, and a stale selection that still
  /// matched by identity would tick a row that no longer exists.
  final _ticked = <String>{};

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

  void _deleteTicked() {
    final doomed = [
      for (final port in widget.body.ports)
        if (_ticked.contains(port.key.v)) port.key,
    ];
    if (doomed.isEmpty) return;
    widget.actions.transact(LabelKey.removePort, (tx) {
      for (final key in doomed) {
        tx.add(RemovePortCommand(key));
      }
    });
    setState(_ticked.clear);
  }

  @override
  Widget build(BuildContext context) {
    final table = buildPortTable(
      widget.body,
      portDesignatorFormat: widget.portDesignatorFormat,
    );
    // Ports the user ticked and then deleted, or that a rename moved:
    // dropped here rather than in the writer, so the count under the
    // buttons is never a count of rows that are not there.
    _ticked.removeWhere(
      (key) => !widget.body.ports.any((p) => p.key.v == key),
    );

    final issues = validatePorts(widget.body);
    final columns = portVisibleColumns(_openPacks());
    final total =
        kPortSelectGutter +
        columns.fold<double>(0, (n, c) => n + portColumnWidth(c));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Toolbar(
          portCount: table.portCount,
          tickedCount: _ticked.length,
          onAdd: _addPort,
          onDelete: _ticked.isEmpty ? null : _deleteTicked,
          openPacks: _openPacks(),
          onTogglePack: _togglePack,
        ),
        const Divider(height: 1),
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
                        _HeaderRow(scale: scale, columns: columns),
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
                                  ticked: _ticked,
                                  onToggleBand: (key) => setState(() {
                                    if (!_collapsed.remove(key)) {
                                      _collapsed.add(key);
                                    }
                                  }),
                                  onTick: (key, {required bool on}) =>
                                      setState(() {
                                        on
                                            ? _ticked.add(key)
                                            : _ticked.remove(key);
                                      }),
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
      ],
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
const double kPortSelectGutter = 56;

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.portCount,
    required this.tickedCount,
    required this.onAdd,
    required this.onDelete,
    required this.openPacks,
    required this.onTogglePack,
  });

  final int portCount;
  final int tickedCount;
  final VoidCallback onAdd;
  final VoidCallback? onDelete;
  final Set<PortColumnPack> openPacks;
  final void Function(PortColumnPack pack, {required bool on}) onTogglePack;

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
          // 68 rows does not say whether it means the ticked rows or all
          // of them, and the answer matters most to the person who is
          // about to find out.
          label: Text(
            tickedCount == 0 ? 'Delete' : 'Delete $tickedCount selected',
          ),
        ),
        const Spacer(),
        Text(
          portCount == 1 ? '1 port' : '$portCount ports',
          style: Theme.of(context).textTheme.labelMedium,
        ),
        const SizedBox(width: 12),
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
  const _HeaderRow({required this.scale, required this.columns});

  final double scale;
  final List<PortColumnId> columns;

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
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  portColumnHeader(id),
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
    required this.ticked,
    required this.onToggleBand,
    required this.onTick,
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
  final Set<String> ticked;
  final ValueChanged<String?> onToggleBand;
  final void Function(String portKey, {required bool on}) onTick;

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
          SliverList.builder(
            itemCount: band.rows.length,
            itemBuilder: (context, index) => _PortRow(
              // KEYED ON THE PORT, so that when M4-E2 puts a
              // `TextField` in a cell its controller follows the PORT
              // rather than the row position. Adding, deleting or
              // collapsing reshuffles the list, and an unkeyed row
              // would hand row 3's controller to whatever port is
              // third afterwards.
              key: ValueKey(band.rows[index].port.key.v),
              row: band.rows[index],
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
              ticked: ticked.contains(band.rows[index].port.key.v),
              onTick: onTick,
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
    required this.ticked,
    required this.onTick,
    super.key,
  });

  final PortTableRow row;
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

  final bool ticked;
  final void Function(String portKey, {required bool on}) onTick;

  PortDef get _port => row.port;

  void _set<T>(PortField<T> field, T value) {
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
      _set(PortDefField.label, label);
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
                // SHRUNK, because a `Checkbox` reserves Material's 48-point
                // TAP TARGET by default and the gutter now has to hold a
                // dot beside it. Measured: the default overflowed this row
                // by 2.2 points.
                Checkbox(
                  value: ticked,
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onChanged: (v) => onTick(_port.key.v, on: v ?? false),
                ),
                _IssueDot(issues: issues),
              ],
            ),
          ),
          for (final id in columns)
            SizedBox(
              width: portColumnWidth(id) * scale,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: _cell(context, id),
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
    PortColumnId.portKey => _TextCell(
      value: _port.key.v,
      automatic: keyFollowsLabel,
      onCommit: _renameKey,
    ),
    PortColumnId.label => _TextCell(
      value: _port.label,
      hint: 'HDMI IN 1',
      onCommit: _setLabel,
    ),
    PortColumnId.designator => _TextCell(
      value: row.isDesignatorPinned ? _port.designatorHint : row.autoDesignator,
      // AUTOMATIC VALUES ARE ITALIC AND PINNED ONES ARE NOT (docs/06
      // §4.5). One glance says which designators a renumber would move
      // and which the author fixed.
      automatic: !row.isDesignatorPinned,
      // EMPTY MEANS BACK TO AUTOMATIC, not "deliberately unnumbered".
      onCommit: (v) => _set(
        PortDefField.designatorHint,
        v.trim().isEmpty ? null : v.trim(),
      ),
    ),
    PortColumnId.connector => _ConnectorCell(
      registries: registries,
      value: _port.connector,
      onPick: (v) => _set(PortDefField.connector, v),
    ),
    PortColumnId.family => _FamilyCell(
      registries: registries,
      value: _port.signalFamily,
      onPick: (v) => _set(PortDefField.signalFamily, v),
    ),
    PortColumnId.direction => _ChoiceCell<PortDirection>(
      value: _port.direction,
      options: PortDirection.values,
      label: portDirectionLabel,
      onPick: (v) => _set(PortDefField.direction, v),
    ),
    PortColumnId.face => _ChoiceCell<Face>(
      value: _port.face,
      options: Face.values,
      label: portFaceLabel,
      onPick: (v) => _set(PortDefField.face, v),
    ),
    PortColumnId.portSet => _ChoiceCell<String?>(
      value: _port.setKey,
      // NULL IS AN OPTION AND IS LISTED FIRST. Most ports belong to no
      // set, and a dropdown a person cannot get back out of is worse
      // than one they never opened.
      options: [null, for (final set in portSets) set.key],
      label: (v) => v == null
          ? kUnknownCell
          : portSets.firstWhere((s) => s.key == v).label,
      onPick: (v) => _set(PortDefField.setKey, v),
    ),
    PortColumnId.setRole => _TextCell(
      value: _port.setRole,
      hint: 'L',
      onCommit: (v) =>
          _set(PortDefField.setRole, v.trim().isEmpty ? null : v.trim()),
    ),
    PortColumnId.notes => _TextCell(
      value: _port.notes,
      onCommit: (v) => _set(PortDefField.notes, _orNull(v)),
    ),
    PortColumnId.impedanceOhms => _NumberCell(
      value: _port.impedanceOhms,
      hint: '75',
      onCommit: (v) => _set(PortDefField.impedanceOhms, v),
    ),
    PortColumnId.audioLevel => _NullableChoiceCell<AudioLevel>(
      value: _port.level,
      options: AudioLevel.values,
      label: portAudioLevelLabel,
      onPick: (v) => _set(PortDefField.audioLevel, v),
    ),
    PortColumnId.balanced => _TriStateCell(
      value: _port.balanced,
      onPick: (v) => _set(PortDefField.balanced, v),
    ),
    PortColumnId.phantomPower => _TriStateCell(
      value: _port.phantomPowerCapable,
      onPick: (v) => _set(PortDefField.phantomPower, v),
    ),
    PortColumnId.polarity => _NullableChoiceCell<Polarity>(
      value: _port.polarity,
      options: Polarity.values,
      label: portPolarityLabel,
      onPick: (v) => _set(PortDefField.polarity, v),
    ),
    PortColumnId.nominalVoltage => _NumberCell(
      value: _port.nominalVoltage,
      onCommit: (v) => _set(PortDefField.nominalVoltage, v),
    ),
    PortColumnId.maxCurrentMa => _NumberCell(
      value: _port.maxCurrentMa,
      onCommit: (v) => _set(PortDefField.maxCurrentMa, v),
    ),
    PortColumnId.poeRole => _NullableChoiceCell<PoeRole>(
      value: _port.poe?.role,
      options: PoeRole.values,
      label: portPoeRoleLabel,
      onPick: (v) => _set(PortDefField.poeRole, v),
    ),
    PortColumnId.poeStandard => _NullableChoiceCell<PoeStandard>(
      value: _port.poe?.standard,
      options: PoeStandard.values,
      label: portPoeStandardLabel,
      onPick: (v) => _set(PortDefField.poeStandard, v),
    ),
    PortColumnId.poeType => _NumberCell(
      value: _port.poe?.type,
      onCommit: (v) => _set(PortDefField.poeType, v),
    ),
    PortColumnId.poeClass => _NumberCell(
      value: _port.poe?.poeClass,
      onCommit: (v) => _set(PortDefField.poeClass, v),
    ),
    PortColumnId.poeWatts => _NumberCell(
      value: _port.poe?.watts,
      onCommit: (v) => _set(PortDefField.poeWatts, v),
    ),
    PortColumnId.linkSpeedMbps => _NumberCell(
      value: _port.linkSpeedMbps,
      hint: '1000',
      onCommit: (v) => _set(PortDefField.linkSpeedMbps, v),
    ),
    PortColumnId.sfpFormFactor => _NullableChoiceCell<SfpFormFactor>(
      value: _port.sfp,
      options: SfpFormFactor.values,
      label: portSfpLabel,
      onPick: (v) => _set(PortDefField.sfpFormFactor, v),
    ),
    PortColumnId.fiberMode => _NullableChoiceCell<FiberMode>(
      value: _port.fiberMode,
      options: FiberMode.values,
      label: portFiberModeLabel,
      onPick: (v) => _set(PortDefField.fiberMode, v),
    ),
    PortColumnId.wavelengthNm => _NumberCell(
      value: _port.wavelengthNm,
      hint: '1310',
      onCommit: (v) => _set(PortDefField.wavelengthNm, v),
    ),
    PortColumnId.serialRole => _NullableChoiceCell<SerialRole>(
      value: _port.serial?.role,
      options: SerialRole.values,
      label: portSerialRoleLabel,
      onPick: (v) => _set(PortDefField.serialRole, v),
    ),
    PortColumnId.baud => _NumberCell(
      value: _port.serial?.baud,
      hint: '9600',
      onCommit: (v) => _set(PortDefField.baud, v),
    ),
    PortColumnId.dataBits => _NumberCell(
      value: _port.serial?.dataBits,
      hint: '8',
      onCommit: (v) => _set(PortDefField.dataBits, v),
    ),
    PortColumnId.stopBits => _NumberCell(
      value: _port.serial?.stopBits,
      hint: '1',
      onCommit: (v) => _set(PortDefField.stopBits, v),
    ),
    PortColumnId.parity => _TextCell(
      value: _port.serial?.parity,
      hint: 'none',
      onCommit: (v) => _set(PortDefField.parity, _orNull(v)),
    ),
    PortColumnId.flowControl => _TextCell(
      value: _port.serial?.flowControl,
      hint: 'none',
      onCommit: (v) => _set(PortDefField.flowControl, _orNull(v)),
    ),
    PortColumnId.busProtocol => _TextCell(
      value: _port.bus?.protocol,
      hint: 'rs485',
      onCommit: (v) => _set(PortDefField.busProtocol, _orNull(v)),
    ),
    PortColumnId.busTermination => _TriStateCell(
      value: _port.bus?.supportsTermination,
      onPick: (v) => _set(PortDefField.busTermination, v),
    ),
    PortColumnId.busUnitLoads => _NumberCell(
      value: _port.bus?.unitLoads,
      onCommit: (v) => _set(PortDefField.busUnitLoads, v),
    ),
    PortColumnId.busAddressable => _TriStateCell(
      value: _port.bus?.addressable,
      onPick: (v) => _set(PortDefField.busAddressable, v),
    ),
    PortColumnId.busMaxTapWatts => _NumberCell(
      value: _port.bus?.maxTapWatts,
      onCommit: (v) => _set(PortDefField.busMaxTapWatts, v),
    ),
    PortColumnId.powerRole => _NullableChoiceCell<PortPowerRole>(
      value: _port.power?.role,
      options: PortPowerRole.values,
      label: portPowerRoleLabel,
      onPick: (v) => _set(PortDefField.powerRole, v),
    ),
    PortColumnId.powerVolts => _NumberCell(
      value: _port.power?.volts,
      hint: '120',
      onCommit: (v) => _set(PortDefField.powerVolts, v),
    ),
    PortColumnId.powerDrawWatts => _NumberCell(
      value: _port.power?.drawWatts,
      onCommit: (v) => _set(PortDefField.powerDrawWatts, v),
    ),
    PortColumnId.powerMaxAmps => _NumberCell(
      value: _port.power?.maxAmps,
      onCommit: (v) => _set(PortDefField.powerMaxAmps, v),
    ),
    // READ-ONLY, AND SAYS SO BY BEING TEXT. Pairing is M4-J3 (`#225`),
    // which owns the bank-level `Pair front to rear by order` action;
    // typing a key into a cell here would write half a pair.
    PortColumnId.pairedPort => _ReadOnlyCell(value: pairedWith),
    PortColumnId.maxConnections => _NumberCell(
      value: _port.maxConnections,
      onCommit: (v) => _set(PortDefField.maxConnections, v ?? 1),
    ),
    PortColumnId.topology => _ChoiceCell<PortTopology>(
      value: _port.topology,
      options: PortTopology.values,
      label: portTopologyLabel,
      onPick: (v) => _set(PortDefField.topology, v),
    ),
    // GATED ON THE CONNECTOR (CR-059, M4-B). Gender is meaningless on an
    // RJ45 and load-bearing on an XLR, and `genderApplies` is the field
    // M4-B authored to say which. A disabled cell rather than a hidden
    // one: the column is open because the person opened the pack, and a
    // gap where a control should be reads as a rendering fault.
    PortColumnId.gender =>
      genderApplies
          ? _ChoiceCell<Gender>(
              value: _port.gender,
              options: Gender.values,
              label: portGenderLabel,
              onPick: (v) => _set(PortDefField.gender, v),
            )
          : const _ReadOnlyCell(
              value: null,
              tooltip: 'This connector has no gender.',
            ),
    PortColumnId.pinoutVariant => _TextCell(
      value: _port.pinoutVariant,
      hint: 'emitter',
      onCommit: (v) => _set(PortDefField.pinoutVariant, _orNull(v)),
    ),
    PortColumnId.conductorCount => _NumberCell(
      value: _port.conductorCount,
      onCommit: (v) => _set(PortDefField.conductorCount, v),
    ),
    PortColumnId.returnChannel => _NullableChoiceCell<ReturnChannel>(
      value: _port.returnChannel,
      options: ReturnChannel.values,
      label: portReturnChannelLabel,
      onPick: (v) => _set(PortDefField.returnChannel, v),
    ),
    // READ-ONLY: `renamedFrom` is written by a rename, never typed.
    PortColumnId.renamedFrom => _ReadOnlyCell(
      value: _port.renamedFrom.isEmpty
          ? null
          : _port.renamedFrom.map((k) => k.v).join(', '),
    ),
  };

  static String? _orNull(String v) => v.trim().isEmpty ? null : v.trim();
}

/// A cell holding a whole number.
///
/// KEEPS WHAT WAS TYPED WHEN IT DOES NOT PARSE, rather than silently
/// reverting. `9,600` and `9600 baud` are things a person types, and a box
/// that empties itself when they tab away tells them nothing about which
/// of the two the app disliked. Nothing is written until it parses; an
/// empty box writes UNKNOWN.
class _NumberCell extends StatelessWidget {
  const _NumberCell({required this.value, required this.onCommit, this.hint});

  final int? value;
  final ValueChanged<int?> onCommit;
  final String? hint;

  @override
  Widget build(BuildContext context) => _TextCell(
    value: value?.toString(),
    hint: hint,
    onCommit: (typed) {
      final text = typed.trim();
      if (text.isEmpty) {
        onCommit(null);
        return;
      }
      final parsed = int.tryParse(text);
      if (parsed != null) onCommit(parsed);
    },
  );
}

/// A closed set that also accepts "nobody has said" (G4).
///
/// THE UNKNOWN ROW IS FIRST AND IS ALWAYS OFFERED. Every one of these
/// fields is nullable in the model because absent means unknown, so a menu
/// a person cannot get back out of would make the first pick permanent.
class _NullableChoiceCell<T extends Enum> extends StatelessWidget {
  const _NullableChoiceCell({
    required this.value,
    required this.options,
    required this.label,
    required this.onPick,
  });

  final T? value;
  final List<T> options;
  final String Function(T value) label;
  final ValueChanged<T?> onPick;

  @override
  Widget build(BuildContext context) => _ChoiceCell<T?>(
    value: value,
    options: [null, ...options],
    label: (v) => v == null ? kUnknownCell : label(v),
    onPick: onPick,
  );
}

/// A `bool?` cell: yes, no, or nobody has said.
///
/// A DROPDOWN AND NOT A CHECKBOX, and that is G4 rather than taste. A
/// checkbox has two states, so an unmeasured port would have to render as
/// a no, which is a measurement nobody took.
class _TriStateCell extends StatelessWidget {
  const _TriStateCell({required this.value, required this.onPick});

  final bool? value;
  final ValueChanged<bool?> onPick;

  @override
  Widget build(BuildContext context) => _ChoiceCell<bool?>(
    value: value,
    options: const [null, true, false],
    label: (v) => portTriStateLabel(value: v),
    onPick: onPick,
  );
}

/// A cell nothing writes through: derived, or not applicable here.
class _ReadOnlyCell extends StatelessWidget {
  const _ReadOnlyCell({required this.value, this.tooltip});

  final String? value;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(
        value ?? kUnknownCell,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
    final message = tooltip;
    return message == null ? text : Tooltip(message: message, child: text);
  }
}

/// A cell a person types into.
///
/// COMMITS ON BLUR AND ON ENTER, never per keystroke. That is docs/06
/// §4.6's rule and it is also why the port commands do not coalesce: one
/// committed value is one edit. Moving DOWN on Enter is spreadsheet
/// ergonomics and belongs with M4-F (`#177`), which owns fill-down,
/// multi-row edit and the rest of the Excel muscle memory; Tab already
/// moves right through the row because the cells are in reading order.
class _TextCell extends StatefulWidget {
  const _TextCell({
    required this.value,
    required this.onCommit,
    this.hint,
    this.automatic = false,
  });

  final String? value;
  final ValueChanged<String> onCommit;

  /// Shown greyed inside an EMPTY box only, which is the distinction M4-D
  /// had to be told twice: an example that stays under a filled field
  /// reads as a second value.
  final String? hint;

  /// Drawn italic and dimmed: a value this editor derived rather than one
  /// the author chose.
  final bool automatic;

  @override
  State<_TextCell> createState() => _TextCellState();
}

class _TextCellState extends State<_TextCell> {
  late final TextEditingController _text = TextEditingController(
    text: widget.value ?? '',
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
    // THE MODEL WINS, EXCEPT WHILE SOMEBODY IS TYPING IN THIS BOX. An
    // undo, or a key following a label typed one cell to the right,
    // changes the stored value under a cell that is not focused, and the
    // cell must follow. Overwriting a FOCUSED cell would delete what the
    // person is halfway through typing. M4-D shipped without this and
    // undo looked like a button that did nothing.
    if (widget.value != old.value && !_focus.hasFocus) {
      _text.text = widget.value ?? '';
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
    if (_text.text == (widget.value ?? '')) return;
    widget.onCommit(_text.text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextField(
      controller: _text,
      focusNode: _focus,
      style: theme.textTheme.bodySmall?.copyWith(
        fontStyle: widget.automatic ? FontStyle.italic : null,
        color: widget.automatic
            ? theme.colorScheme.onSurfaceVariant
            : theme.colorScheme.onSurface,
      ),
      decoration: InputDecoration(
        isDense: true,
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
        // THE DASH, and not an empty box. An empty cell says nothing
        // about whether anybody has looked at this field; the dash is
        // what the equipment list and every schedule print for a fact
        // nobody has supplied.
        hintText: widget.hint ?? kUnknownCell,
        hintStyle: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      onSubmitted: (_) => _commit(),
    );
  }
}

/// A cell whose column has a short closed set of answers.
///
/// A `DropdownButton` HERE AND A MENU FOR CONNECTOR AND SIGNAL, and the
/// difference is measured rather than stylistic: this widget's menu
/// inherits its BUTTON's width, which is fine for `Bidirectional` in a
/// 116-point column and is not fine for `AUD·Speaker, constant-voltage 70
/// / 100 / 25 V`. See `family_picker.dart`.
class _ChoiceCell<T> extends StatelessWidget {
  const _ChoiceCell({
    required this.value,
    required this.options,
    required this.label,
    required this.onPick,
  });

  final T value;
  final List<T> options;
  final String Function(T value) label;
  final ValueChanged<T> onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DropdownButtonHideUnderline(
      child: DropdownButton<T>(
        value: value,
        isDense: true,
        isExpanded: true,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurface,
        ),
        items: [
          for (final option in options)
            DropdownMenuItem<T>(
              value: option,
              child: Text(
                label(option),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: (v) {
          if (v is T) onPick(v);
        },
      ),
    );
  }
}

/// The CONNECTOR cell: a menu sized to its content, for the SIGNAL
/// column's measured reason.
///
/// THE CURRENT VALUE IS ALWAYS IN THE MENU, even when the registry does
/// not hold it. A `DropdownButton` asserts that exactly one item matches
/// its value, and M3-L found what that costs: a document naming something
/// no menu offers takes the WHOLE table down rather than misbehaving in
/// one cell. A `MenuAnchor` has no such assertion, and an unset port (a
/// brand-new row names no connector at all) still has a menu to pick from,
/// which read-only degradation would deny it.
class _ConnectorCell extends StatelessWidget {
  const _ConnectorCell({
    required this.registries,
    required this.value,
    required this.onPick,
  });

  final Registries registries;
  final ConnectorTypeId value;
  final ValueChanged<ConnectorTypeId> onPick;

  @override
  Widget build(BuildContext context) {
    final options = [...registries.connectorTypes.values]
      ..sort((a, b) => a.displayName.compareTo(b.displayName));
    return _MenuCell(
      text: portConnectorText(registries, value),
      hint: 'Connector',
      entries: [
        for (final def in options) (def.id.v, def.displayName),
      ],
      selected: value.v,
      onPick: (id) => onPick(ConnectorTypeId(id)),
    );
  }
}

/// The SIGNAL cell, on the Structure editor's own picker.
///
/// THE SAME WIDGET, NOT A SECOND ONE. `family_picker.dart` carries the
/// measurement that rejected a `DropdownButton` and the ruling that its
/// filter narrows without ever committing (DR-025 §11.24.3: an
/// unresolved value never invents a family). A copy here would be a
/// second place for one of those to be forgotten.
class _FamilyCell extends StatelessWidget {
  const _FamilyCell({
    required this.registries,
    required this.value,
    required this.onPick,
  });

  final Registries registries;
  final SignalFamilyId value;
  final ValueChanged<SignalFamilyId> onPick;

  @override
  Widget build(BuildContext context) => FamilyPicker(
    groups: signalFamilyCellGroups(registries),
    value: portFamilyText(registries, value),
    hint: 'Signal',
    onPick: (label) {
      final picked = resolveSignalFamilyCell(registries, label);
      if (picked != null) onPick(picked);
    },
  );
}

/// A menu of `(value, label)` pairs, wider than the cell that opened it.
class _MenuCell extends StatefulWidget {
  const _MenuCell({
    required this.text,
    required this.hint,
    required this.entries,
    required this.selected,
    required this.onPick,
  });

  final String? text;
  final String hint;
  final List<(String, String)> entries;
  final String selected;
  final ValueChanged<String> onPick;

  @override
  State<_MenuCell> createState() => _MenuCellState();
}

class _MenuCellState extends State<_MenuCell> {
  final MenuController _menu = MenuController();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MenuAnchor(
      controller: _menu,
      menuChildren: [
        SizedBox(
          width: kFamilyPickerWidth,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: kFamilyPickerMaxHeight,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final (id, label) in widget.entries)
                    MenuItemButton(
                      onPressed: () {
                        _menu.close();
                        widget.onPick(id);
                      },
                      leadingIcon: Icon(
                        Icons.check,
                        size: 16,
                        color: id == widget.selected
                            ? theme.colorScheme.primary
                            : Colors.transparent,
                      ),
                      child: Text(label),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
      builder: (context, controller, child) => InkWell(
        onTap: () => controller.isOpen ? controller.close() : controller.open(),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.text ?? kUnknownCell,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: widget.text == null
                        ? theme.colorScheme.onSurfaceVariant
                        : theme.colorScheme.onSurface,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_drop_down,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
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
