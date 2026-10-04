// THE `[ Devices ]` VIEW. NET-A/2a (`#988`), DR-048 §11.47.6, DR-226,
// DR-227.
//
// The fifth view in Structured Wiring, and the table DR-048 put network
// values in: one row per device, its management address in columns, typed
// down the way an installer closes out a job rather than one inspector
// visit per device.
//
// ═════════════════════════════════════════════════════════════════════
// IT RENDERS A DERIVATION. IT CONTAINS NONE.
// ═════════════════════════════════════════════════════════════════════
// Which devices, in what order, and every cell's text come from
// `rackpal_core`'s `derived/network_table.dart`, which `T6.50` prints from
// too, so the table and the schedule are the same strings (CR-107). This
// file owns no state at all: whether Show all is on and which columns show
// are the EDITOR'S, as the cable table's optional columns are, so both
// survive switching to another view and back.
//
// ═════════════════════════════════════════════════════════════════════
// UNVERIFIED IS SAID, NEVER LEFT BLANK
// ═════════════════════════════════════════════════════════════════════
// The `VERIFIED` cell reads `unverified` until somebody gives it a date
// (DR-048 §11.47.3), in the muted ink an unknown gets everywhere else, so
// an address nobody has checked never sits in the same typeface as one
// somebody has.
import 'package:flutter/material.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/src/theme/console_theme.dart';

/// What the app does when the Devices view asks for something.
@immutable
final class DevicesActions {
  const DevicesActions({required this.onEdit});

  /// Applies cell edits as ONE undo step, and returns a refusal sentence
  /// or null. A list, on `PathwaysActions.onEdit`'s reasoning: fill-down
  /// and the batch bar send several.
  final String? Function(List<NetworkCellEdit> edits) onEdit;
}

/// One cell, as an edit request: which device, which column, what was
/// typed. The value is TEXT, for `PathwayCellEdit`'s reason: parsing it is
/// the app's job, beside the command that refuses.
@immutable
final class NetworkCellEdit {
  const NetworkCellEdit({
    required this.deviceId,
    required this.column,
    required this.value,
  });

  final Uuid deviceId;
  final NetworkColumnId column;
  final String value;
}

/// The Show all toggle's words (DR-227 §11.226.2).
const String kShowAllDevicesLabel = 'Show all devices';

/// The Columns menu's button (NET-A/2b), the port grid's word for it.
const String kDeviceColumnsLabel = 'Columns';

/// The columns a person may turn on and off: every network value. The
/// three that say which device a row is are always shown.
List<NetworkColumnId> get toggleableNetworkColumns => [
  for (final c in NetworkColumnId.values)
    if (networkColumnIsEditable(c)) c,
];

/// The columns showing before anybody touches the menu (DR-226 §11.225.3).
Set<NetworkColumnId> get defaultNetworkColumns => {
  for (final c in toggleableNetworkColumns)
    if (networkColumnShownByDefault(c)) c,
};

/// What the view says when nothing is network-capable yet.
const String kNoNetworkDevicesYet =
    'No device here has a network jack, Wi-Fi or an address yet. Turn on '
    '$kShowAllDevicesLabel to give any device one.';

class DevicesView extends StatelessWidget {
  const DevicesView({
    required this.doc,
    required this.actions,
    required this.showAll,
    required this.onShowAll,
    required this.shown,
    required this.onColumn,
    this.order = NetworkOrder.designator,
    super.key,
  });

  final RackDocument doc;
  final DevicesActions actions;

  /// Whether every device is listed, not only the network-capable ones
  /// (DR-227 §11.226.2).
  final bool showAll;
  final ValueChanged<bool> onShowAll;

  /// The toggleable columns showing. The identity columns always are.
  final Set<NetworkColumnId> shown;

  /// Turns [NetworkColumnId] on when it is off, and off when it is on.
  final ValueChanged<NetworkColumnId> onColumn;

  /// The project's network order (DR-227 §11.226.4), which `T6.50` reads
  /// too.
  final NetworkOrder order;

  @override
  Widget build(BuildContext context) {
    final rows = buildNetworkTable(doc, showAll: showAll, order: order);
    final columns = [
      for (final c in NetworkColumnId.values)
        if (!networkColumnIsEditable(c) || shown.contains(c)) c,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Toolbar(
          rows: rows,
          showAll: showAll,
          onShowAll: onShowAll,
          shown: shown,
          onColumn: onColumn,
        ),
        const Divider(height: 1),
        Expanded(
          child: rows.isEmpty
              ? const _EmptyState()
              : _DeviceTable(rows: rows, columns: columns, actions: actions),
        ),
      ],
    );
  }
}

/// The counts, the Columns menu and the Show all toggle.
///
/// BOTH COUNTS SHOW, ZERO INCLUDED, for `PathwaysView`'s reason: "0
/// verified" is news, and a line that vanishes when the news is bad makes
/// its absence unreadable.
class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.rows,
    required this.showAll,
    required this.onShowAll,
    required this.shown,
    required this.onColumn,
  });

  final List<NetworkRow> rows;
  final bool showAll;
  final ValueChanged<bool> onShowAll;
  final Set<NetworkColumnId> shown;
  final ValueChanged<NetworkColumnId> onColumn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final verified = rows.where((r) => r.verifiedOn != null).length;
    final noun = rows.length == 1 ? 'device' : 'devices';
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Row(
        children: [
          Text(
            '${rows.length} $noun · $verified verified',
            style: theme.textTheme.bodySmall,
          ),
          const Spacer(),
          // THE PORT GRID'S CONTROL, word for word: a labelled button
          // opening a list of checkboxes, so a person who has used one
          // knows the other.
          MenuAnchor(
            menuChildren: [
              for (final c in toggleableNetworkColumns)
                MenuItemButton(
                  closeOnActivate: false,
                  leadingIcon: Icon(
                    shown.contains(c)
                        ? Icons.check_box
                        : Icons.check_box_outline_blank,
                    size: 18,
                  ),
                  onPressed: () => onColumn(c),
                  child: Text(networkColumnHeader(c)),
                ),
            ],
            builder: (context, controller, child) => TextButton.icon(
              onPressed: () =>
                  controller.isOpen ? controller.close() : controller.open(),
              icon: const Icon(Icons.settings_outlined, size: 18),
              label: const Text(kDeviceColumnsLabel),
            ),
          ),
          const SizedBox(width: 12),
          Text(kShowAllDevicesLabel, style: theme.textTheme.bodySmall),
          Switch(value: showAll, onChanged: onShowAll),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        kNoNetworkDevicesYet,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    ),
  );
}

class _DeviceTable extends StatelessWidget {
  const _DeviceTable({
    required this.rows,
    required this.columns,
    required this.actions,
  });

  final List<NetworkRow> rows;
  final List<NetworkColumnId> columns;
  final DevicesActions actions;

  @override
  Widget build(BuildContext context) {
    final totalPt = columns.fold<double>(
      0,
      (n, c) => n + networkColumnWidth(c),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        // NEVER SQUEEZED BELOW THE AUTHORED WIDTHS: a narrow window scrolls
        // sideways, the rule every table in this editor keeps, so a MAC
        // never renders as an ellipsis on the laptop a tech carries.
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
                  _HeaderRow(columns: columns, scale: effective),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.builder(
                      itemCount: rows.length,
                      itemBuilder: (context, index) => _DeviceRow(
                        key: ValueKey(rows[index].deviceId.v),
                        row: rows[index],
                        columns: columns,
                        scale: effective,
                        actions: actions,
                      ),
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

  final List<NetworkColumnId> columns;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          for (final id in columns)
            SizedBox(
              width: networkColumnWidth(id) * scale,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  networkColumnHeader(id),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: kConsoleEmphasis,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DeviceRow extends StatelessWidget {
  const _DeviceRow({
    required this.row,
    required this.columns,
    required this.scale,
    required this.actions,
    super.key,
  });

  final NetworkRow row;
  final List<NetworkColumnId> columns;
  final double scale;
  final DevicesActions actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        for (final id in columns)
          SizedBox(
            width: networkColumnWidth(id) * scale,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: networkColumnIsEditable(id)
                  ? _TextCell(
                      key: ValueKey('${row.deviceId.v}:${id.name}'),
                      deviceId: row.deviceId,
                      column: id,
                      value: _editValue(row, id),
                      onEdit: actions.onEdit,
                    )
                  : Text(
                      networkCellText(row, id),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: id == NetworkColumnId.device
                            ? kConsoleEmphasis
                            : FontWeight.w400,
                      ),
                    ),
            ),
          ),
      ],
    );
  }
}

/// What an EDITABLE cell holds: the cell's text, except that an undated
/// row's date box is empty with `unverified` as its hint, so a person types
/// a date into a blank box rather than over a word.
String _editValue(NetworkRow row, NetworkColumnId id) =>
    id == NetworkColumnId.verified && row.verifiedOn == null
    ? ''
    : networkCellText(row, id);

class _TextCell extends StatefulWidget {
  const _TextCell({
    required this.deviceId,
    required this.column,
    required this.value,
    required this.onEdit,
    super.key,
  });

  final Uuid deviceId;
  final NetworkColumnId column;
  final String value;
  final String? Function(List<NetworkCellEdit> edits) onEdit;

  @override
  State<_TextCell> createState() => _TextCellState();
}

class _TextCellState extends State<_TextCell> {
  late final TextEditingController _text = TextEditingController(
    text: widget.value,
  );
  final FocusNode _focus = FocusNode();

  /// The text last handed to `onEdit`, until the document answers.
  ///
  /// ENTER COMMITS AND THEN THE FIELD LOSES FOCUS, which commits again,
  /// and the second arrives before the document has rebuilt this cell
  /// with the new value. Without this the cell sends every edit twice;
  /// found by `devices_view_test.dart` against a harness that, like a slow
  /// frame, had not rebuilt yet.
  String? _sent;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(_TextCell old) {
    super.didUpdateWidget(old);
    // THE DOCUMENT WINS, EXCEPT WHILE SOMEBODY IS TYPING IN THIS BOX:
    // `PathwaysView`'s rule. An undo must reach an unfocused cell; it must
    // not delete what a person is halfway through typing.
    if (widget.value != old.value) _sent = null;
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
    if (_text.text == widget.value || _text.text == _sent) return;
    _sent = _text.text;
    final refusal = widget.onEdit([
      NetworkCellEdit(
        deviceId: widget.deviceId,
        column: widget.column,
        value: _text.text,
      ),
    ]);
    // THE SENTENCE GOES TO THE EDITOR'S STATUS BAR, through the callback,
    // as every other view's refusal does; the cell only puts back what the
    // document holds.
    if (refusal != null) {
      _sent = null;
      _text.text = widget.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final verified = widget.column == NetworkColumnId.verified;
    return TextField(
      controller: _text,
      focusNode: _focus,
      style: theme.textTheme.bodySmall,
      decoration: InputDecoration(
        isDense: true,
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(vertical: 4),
        // `unverified` IN MUTED INK on an undated row (DR-048 §11.47.3);
        // the unknown dash everywhere else, as every table here shows one.
        hintText: verified ? kUnverified : kUnknownCell,
        hintStyle: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      onSubmitted: (_) => _commit(),
    );
  }
}
