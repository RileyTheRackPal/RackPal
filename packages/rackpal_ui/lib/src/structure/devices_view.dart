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
import 'package:rackpal_ui/src/network/open_web_page.dart';
import 'package:rackpal_ui/src/structure/structure_editor_screen.dart'
    show kBatchSetLabel, kClearSelectionLabel;
import 'package:rackpal_ui/src/theme/console_theme.dart';

/// What the app does when the Devices view asks for something.
@immutable
final class DevicesActions {
  const DevicesActions({required this.onEdit, required this.onVerifiedToday});

  /// Applies cell edits as ONE undo step, and returns a refusal sentence
  /// or null. A list, on `PathwaysActions.onEdit`'s reasoning: fill-down
  /// and the batch bar send several.
  final String? Function(List<NetworkCellEdit> edits) onEdit;

  /// Stamps today's date on the given devices' rows, as ONE undo step (DR-226
  /// §11.225.5). "Today" is the person's calendar day, which only the app
  /// has a clock for, so the view asks rather than supplying a date.
  final String? Function(List<Uuid> ids) onVerifiedToday;
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

/// The batch bar's stamp (DR-226 §11.225.5).
const String kVerifiedTodayLabel = 'Verified today';

/// The tick gutter's width, the cable table's `kSelectGutterWidth`.
const double kDeviceSelectGutterWidth = 34;

/// The last column's width: one "Open web page" button per row (DR-229
/// §11.228.1). A column of the VIEW, not a `NetworkColumnId`: it is not
/// in the Columns menu and T6.50 does not print it.
const double kDeviceWebPageColumnWidth = 34;

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
    required this.selected,
    required this.onSelect,
    required this.onSelectAll,
    required this.onCaret,
    this.order = NetworkOrder.designator,
    super.key,
  });

  /// The ticked devices. Held by the editor, as the cable table's are.
  final Set<Uuid> selected;
  final void Function(Uuid id, {required bool ticked}) onSelect;

  /// Ticks or unticks every row ON SCREEN: what Show all lists.
  final void Function(List<Uuid> ids, {required bool ticked}) onSelectAll;

  /// The focused cell, for `Ctrl+D`.
  final ValueChanged<(Uuid, NetworkColumnId)?> onCaret;

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
        // ONLY WHEN SOMETHING ON SCREEN IS TICKED, the cable bar's rule: a
        // strip of controls that do nothing on an empty selection is the
        // defect `shell_tabs_test.dart` gates.
        if (rows.any((r) => selected.contains(r.deviceId)))
          _DeviceBatchBar(
            ticked: [
              for (final r in rows)
                if (selected.contains(r.deviceId)) r.deviceId,
            ],
            columns: [
              for (final c in columns)
                if (networkColumnIsEditable(c)) c,
            ],
            actions: actions,
            onClear: () => onSelectAll(
              [for (final r in rows) r.deviceId],
              ticked: false,
            ),
          ),
        Expanded(
          child: rows.isEmpty
              ? const _EmptyState()
              : _DeviceTable(
                  rows: rows,
                  columns: columns,
                  actions: actions,
                  selected: selected,
                  onSelect: onSelect,
                  onSelectAll: onSelectAll,
                  onCaret: onCaret,
                ),
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
    required this.selected,
    required this.onSelect,
    required this.onSelectAll,
    required this.onCaret,
  });

  final List<NetworkRow> rows;
  final List<NetworkColumnId> columns;
  final DevicesActions actions;
  final Set<Uuid> selected;
  final void Function(Uuid id, {required bool ticked}) onSelect;
  final void Function(List<Uuid> ids, {required bool ticked}) onSelectAll;
  final ValueChanged<(Uuid, NetworkColumnId)?> onCaret;

  @override
  Widget build(BuildContext context) {
    final totalPt =
        columns.fold<double>(0, (n, c) => n + networkColumnWidth(c)) +
        kDeviceSelectGutterWidth +
        kDeviceWebPageColumnWidth;
    final ids = [for (final r in rows) r.deviceId];
    final ticked = ids.where(selected.contains).length;
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
                  _HeaderRow(
                    columns: columns,
                    scale: effective,
                    // TRI-STATE, as the cable table's header is: some but
                    // not all ticked reads as a dash.
                    allTicked: ticked == ids.length
                        ? true
                        : ticked == 0
                        ? false
                        : null,
                    onSelectAll: (all) => onSelectAll(ids, ticked: all),
                  ),
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
                        ticked: selected.contains(rows[index].deviceId),
                        onTick: (v) =>
                            onSelect(rows[index].deviceId, ticked: v),
                        onCaret: onCaret,
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
  const _HeaderRow({
    required this.columns,
    required this.scale,
    required this.allTicked,
    required this.onSelectAll,
  });

  final List<NetworkColumnId> columns;
  final double scale;
  final bool? allTicked;

  /// True ticks every row on screen; false unticks them.
  final ValueChanged<bool> onSelectAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: kDeviceSelectGutterWidth * scale,
            child: Checkbox(
              key: const ValueKey('devices-tick-all'),
              tristate: true,
              value: allTicked,
              // A DASH TAPPED TICKS THE REST, the reading a spreadsheet
              // gives it; only a full tick taps to clear.
              onChanged: (_) => onSelectAll(allTicked != true),
            ),
          ),
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
          SizedBox(width: kDeviceWebPageColumnWidth * scale),
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
    required this.ticked,
    required this.onTick,
    required this.onCaret,
    super.key,
  });

  final NetworkRow row;
  final List<NetworkColumnId> columns;
  final double scale;
  final DevicesActions actions;
  final bool ticked;
  final ValueChanged<bool> onTick;
  final ValueChanged<(Uuid, NetworkColumnId)?> onCaret;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        SizedBox(
          width: kDeviceSelectGutterWidth * scale,
          child: Checkbox(
            key: ValueKey('devices-tick-${row.deviceId.v}'),
            value: ticked,
            onChanged: (v) => onTick(v ?? false),
          ),
        ),
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
                      onFocused: () => onCaret((row.deviceId, id)),
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
        // LAST, after the values it opens (DR-229 §11.228.1), and empty on
        // a row with no address rather than a button that cannot work.
        SizedBox(
          width: kDeviceWebPageColumnWidth * scale,
          child: OpenWebPageButton(row: row, compact: true),
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
    required this.onFocused,
    super.key,
  });

  final Uuid deviceId;
  final NetworkColumnId column;
  final String value;
  final String? Function(List<NetworkCellEdit> edits) onEdit;

  /// Tells the editor this is the cell `Ctrl+D` should fill.
  final VoidCallback onFocused;

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
    if (_focus.hasFocus) {
      widget.onFocused();
    } else {
      _commit();
    }
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

/// The Devices batch bar: a column and a value for every ticked row, and
/// the day they were checked.
///
/// THE CABLE BAR'S WORDS (`Set`, `value, then Enter`, `Clear selection`),
/// so a person who has used one has used the other. Holds only the column
/// it is about to set and the text in its box: what is ticked is the
/// editor's.
class _DeviceBatchBar extends StatefulWidget {
  const _DeviceBatchBar({
    required this.ticked,
    required this.columns,
    required this.actions,
    required this.onClear,
  });

  /// The ticked rows on screen, in screen order.
  final List<Uuid> ticked;

  /// The editable columns on screen.
  final List<NetworkColumnId> columns;
  final DevicesActions actions;
  final VoidCallback onClear;

  @override
  State<_DeviceBatchBar> createState() => _DeviceBatchBarState();
}

class _DeviceBatchBarState extends State<_DeviceBatchBar> {
  final TextEditingController _text = TextEditingController();
  NetworkColumnId? _column;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _set(String value) {
    final column = _column;
    if (column == null) return;
    final refusal = widget.actions.onEdit([
      for (final id in widget.ticked)
        NetworkCellEdit(deviceId: id, column: column, value: value),
    ]);
    if (refusal == null) _text.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final column = widget.columns.contains(_column) ? _column : null;
    return ColoredBox(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
        // A WRAP, for the cable bar's reason: a Row of these overflowed.
        child: Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              '${widget.ticked.length} selected',
              style: theme.textTheme.labelLarge,
            ),
            Text(kBatchSetLabel, style: theme.textTheme.labelMedium),
            DropdownButton<NetworkColumnId>(
              key: const ValueKey('devices-batch-column'),
              value: column,
              hint: const Text('column'),
              items: [
                for (final id in widget.columns)
                  DropdownMenuItem(
                    value: id,
                    child: Text(networkColumnHeader(id)),
                  ),
              ],
              onChanged: (id) => setState(() => _column = id),
            ),
            if (column != null)
              SizedBox(
                width: 180,
                child: TextField(
                  key: const ValueKey('devices-batch-value'),
                  controller: _text,
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: 'value, then Enter',
                  ),
                  onSubmitted: _set,
                ),
              ),
            // A GESTURE, NOT A DEFAULT (DR-226 §11.225.5): the date says a
            // person checked these rows, so only a person pressing this
            // writes it, and nothing else ever does.
            TextButton.icon(
              key: const ValueKey('devices-verified-today'),
              onPressed: () => widget.actions.onVerifiedToday(widget.ticked),
              icon: const Icon(Icons.event_available_outlined, size: 18),
              label: const Text(kVerifiedTodayLabel),
            ),
            TextButton(
              key: const ValueKey('devices-batch-clear'),
              onPressed: widget.onClear,
              child: const Text(kClearSelectionLabel),
            ),
          ],
        ),
      ),
    );
  }
}
