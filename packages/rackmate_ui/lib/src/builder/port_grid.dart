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
// THE CELLS ARE READ-ONLY HERE, AND THAT IS THE TASK BOUNDARY
// ═══════════════════════════════════════════════════════════════════════
// M4-E1 is the grid, its bands and its virtualisation; M4-E2 (`#204`) is
// the columns' editors. Rows draw their values through core's own
// spelling functions so that when the editors arrive they replace a
// control rather than a vocabulary.
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

    final total =
        kPortSelectGutter +
        _kColumns.fold<double>(
          0,
          (n, c) => n + portColumnWidth(c),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Toolbar(
          portCount: table.portCount,
          tickedCount: _ticked.length,
          onAdd: _addPort,
          onDelete: _ticked.isEmpty ? null : _deleteTicked,
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
                        _HeaderRow(scale: scale),
                        const Divider(height: 1, thickness: 1),
                        Expanded(
                          child: table.bands.isEmpty
                              ? const _NoPorts()
                              : _Bands(
                                  table: table,
                                  scale: scale,
                                  registries: widget.registries,
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

/// The tick-box gutter, in the same points the columns are authored in.
const double kPortSelectGutter = 34;

/// The core columns, left to right (docs/06 §4.5). The seven packs join
/// this list in M4-E3, which is why it is a list and not the enum itself.
const List<PortColumnId> _kColumns = PortColumnId.values;

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.portCount,
    required this.tickedCount,
    required this.onAdd,
    required this.onDelete,
  });

  final int portCount;
  final int tickedCount;
  final VoidCallback onAdd;
  final VoidCallback? onDelete;

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
      ],
    ),
  );
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          SizedBox(width: kPortSelectGutter * scale),
          for (final id in _kColumns)
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
    required this.collapsed,
    required this.ticked,
    required this.onToggleBand,
    required this.onTick,
  });

  final PortTable table;
  final double scale;
  final Registries registries;
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
    required this.ticked,
    required this.onTick,
    super.key,
  });

  final PortTableRow row;
  final double scale;
  final Registries registries;
  final bool ticked;
  final void Function(String portKey, {required bool on}) onTick;

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
            child: Checkbox(
              value: ticked,
              onChanged: (v) => onTick(row.port.key.v, on: v ?? false),
            ),
          ),
          for (final id in _kColumns)
            SizedBox(
              width: portColumnWidth(id) * scale,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 10,
                ),
                child: _CellText(
                  value: _cell(id),
                  // AUTOMATIC VALUES ARE ITALIC AND PINNED ONES ARE NOT
                  // (docs/06 §4.5). One glance says which designators a
                  // renumber would move and which the author fixed.
                  automatic:
                      id == PortColumnId.designator && !row.isDesignatorPinned,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// What this column reads for this port, or null for UNKNOWN.
  ///
  /// EVERY SPELLING COMES FROM CORE. The moment this file starts writing
  /// `port.direction.name` it owns a second vocabulary, and the first
  /// time one of them changes they disagree on a printed schedule.
  String? _cell(PortColumnId id) => switch (id) {
    PortColumnId.portKey => row.port.key.v,
    PortColumnId.label => _orNull(row.port.label),
    PortColumnId.designator => row.designator,
    PortColumnId.connector => portConnectorText(
      registries,
      row.port.connector,
    ),
    PortColumnId.family => portFamilyText(registries, row.port.signalFamily),
    PortColumnId.direction => portDirectionLabel(row.port.direction),
    PortColumnId.face => portFaceLabel(row.port.face),
    PortColumnId.portSet => _orNull(row.port.setKey),
    PortColumnId.setRole => _orNull(row.port.setRole),
    PortColumnId.notes => _orNull(row.port.notes),
  };

  static String? _orNull(String? value) =>
      (value ?? '').trim().isEmpty ? null : value!.trim();
}

/// One cell's text, with the dash G4 prints for an unknown.
class _CellText extends StatelessWidget {
  const _CellText({required this.value, required this.automatic});

  final String? value;
  final bool automatic;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unknown = value == null;
    return Text(
      // THE DASH, and not an empty box. An empty cell says nothing about
      // whether anybody has looked at this field; the dash is the same
      // mark the equipment list and every schedule print for a fact
      // nobody has supplied.
      unknown ? '—' : value!,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodySmall?.copyWith(
        fontStyle: automatic ? FontStyle.italic : null,
        color: unknown || automatic
            ? theme.colorScheme.onSurfaceVariant
            : theme.colorScheme.onSurface,
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
