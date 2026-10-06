// packages/rackpal_ui/lib/src/canvas/schematic/cable_bar.dart
// `#973`, DR-231 §11.230.1: the schematic's first per-cable control.
//
// ═════════════════════════════════════════════════════════════════════
// A BAR, BECAUSE THE SCHEMATIC HAD NOWHERE ELSE TO PUT ONE
// ═════════════════════════════════════════════════════════════════════
// Until this file a selected cable got one status sentence ("W003 (...)
// selected — Del removes it.") and no control at all: the schematic has
// no inspector and no right-click menu. `Link.crossover` is the first
// per-cable fact a person sets here, and a null-modem cable is usually a
// serial cable inside the rack, which the Structured Wiring table (the
// other host) does not list. So the bar names the selected cable and
// carries the one control, and it is the obvious place for the next.
//
// EVERY VALUE ON EVERY CABLE (§11.230.2), on the user's trade reason:
// cables are crossed on purpose on more families than serial and fibre.
// `Not set` is nobody having said (G4) and is offered first, so a value
// can be taken back without Ctrl+Z.
//
// ═════════════════════════════════════════════════════════════════════
// AND THE NEXT WAS THE ADAPTER (DR-235 §11.234.2, `#1001`)
// ═════════════════════════════════════════════════════════════════════
// A declared adapter had no host at all: the remedy that writes one told
// the person to "name the part in the inspector", and the schematic has
// no inspector. Each adapter on the cable gets a row of its own UNDER the
// bar's first row, not beside it, because a cable can carry several and
// one row of them would overflow at the widths the schematic runs at.
//
// THE MODEL COMMITS ON ENTER OR ON LEAVING THE FIELD, never per keystroke:
// one undo step per name typed, not one per letter. The screen's bare-key
// bindings already stand down while any `EditableText` holds focus
// (`_textFieldHasFocus`, written for a text field that did not exist yet),
// and the widget test types a `W` and a Backspace into this field to hold
// it to that.
import 'package:flutter/material.dart';
import 'package:rackpal_core/rackpal_core.dart';

/// The crossover control's label.
const String kCableBarCrossoverLabel = 'Crossover';

/// What the control shows for a cable nobody has marked.
const String kCrossoverNotSet = 'Not set';

/// The crossover dropdown, so a test can find it.
const Key kCableBarCrossoverKey = ValueKey('cable-bar-crossover');

/// The button that continues the cable to another device (DR-236
/// §11.235.2).
const String kCableBarAddSetLabel = 'Add a set to this cable';

/// That button, so a test can find it.
const Key kCableBarAddSetKey = ValueKey('cable-bar-add-set');

/// What an adapter row starts with, before its connectors.
const String kCableBarAdapterLabel = 'Adapter';

/// The model field's hint while nobody has named the part.
const String kCableBarAdapterModelHint = 'Model not stated';

/// The [index]th adapter's model field.
Key cableBarAdapterModelKey(int index) =>
    ValueKey('cable-bar-adapter-model-$index');

/// The [index]th adapter's remove button.
Key cableBarAdapterRemoveKey(int index) =>
    ValueKey('cable-bar-adapter-remove-$index');

/// One adapter as the bar shows it: its connectors, named, and its model.
typedef CableBarAdapter = ({String connectors, String? model});

/// The bar shown under the schematic while a cable is selected.
class SchematicCableBar extends StatelessWidget {
  const SchematicCableBar({
    required this.saying,
    required this.crossover,
    required this.onCrossover,
    this.adapters = const <CableBarAdapter>[],
    this.onAdapterModel,
    this.onRemoveAdapter,
    this.onAddSet,
    super.key,
  });

  /// The cable, as the status line names it: `W003 (CTL-1 COM1 to PROJ-1
  /// RS232)`.
  final String saying;

  final CrossoverKind? crossover;

  /// Called with the value picked, null for `Not set`.
  final ValueChanged<CrossoverKind?> onCrossover;

  /// The cable's adapters, in `Link.inlineAdapters` order.
  final List<CableBarAdapter> adapters;

  /// Called with an adapter's position and the model typed, null for
  /// blank.
  final void Function(int index, String? model)? onAdapterModel;

  /// Called with the position of the adapter to take off.
  final ValueChanged<int>? onRemoveAdapter;

  /// "Add a set to this cable" (DR-236 §11.235.2), or null for no button.
  final VoidCallback? onAddSet;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(
                  child: Text(
                    saying,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                const SizedBox(width: 24),
                Text(
                  kCableBarCrossoverLabel,
                  style: theme.textTheme.labelSmall,
                ),
                const SizedBox(width: 8),
                DropdownButton<CrossoverKind?>(
                  key: kCableBarCrossoverKey,
                  value: crossover,
                  isDense: true,
                  style: theme.textTheme.bodySmall,
                  items: [
                    const DropdownMenuItem<CrossoverKind?>(
                      child: Text(kCrossoverNotSet),
                    ),
                    for (final kind in CrossoverKind.values)
                      DropdownMenuItem<CrossoverKind?>(
                        value: kind,
                        child: Text(crossoverLabel(kind)),
                      ),
                  ],
                  onChanged: onCrossover,
                ),
                // DR-236: one cable may carry several sets to several
                // devices, and this is where a person says so.
                if (onAddSet != null) ...[
                  const SizedBox(width: 16),
                  TextButton(
                    key: kCableBarAddSetKey,
                    onPressed: onAddSet,
                    child: const Text(kCableBarAddSetLabel),
                  ),
                ],
              ],
            ),
            for (final (i, adapter) in adapters.indexed)
              Row(
                children: [
                  Text(
                    kCableBarAdapterLabel,
                    style: theme.textTheme.labelSmall,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      adapter.connectors,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 220,
                    child: _AdapterModelField(
                      key: cableBarAdapterModelKey(i),
                      model: adapter.model,
                      onCommit: (model) => onAdapterModel?.call(i, model),
                    ),
                  ),
                  IconButton(
                    key: cableBarAdapterRemoveKey(i),
                    tooltip: 'Remove adapter',
                    iconSize: 16,
                    visualDensity: VisualDensity.compact,
                    onPressed: onRemoveAdapter == null
                        ? null
                        : () => onRemoveAdapter!(i),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// A model field that commits once, on Enter or on losing focus.
class _AdapterModelField extends StatefulWidget {
  const _AdapterModelField({
    required this.model,
    required this.onCommit,
    super.key,
  });

  final String? model;
  final ValueChanged<String?> onCommit;

  @override
  State<_AdapterModelField> createState() => _AdapterModelFieldState();
}

class _AdapterModelFieldState extends State<_AdapterModelField> {
  late final TextEditingController _text = TextEditingController(
    text: widget.model ?? '',
  );
  final FocusNode _focus = FocusNode(debugLabel: 'adapterModel');

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
  }

  void _onFocus() {
    if (!_focus.hasFocus) _commit();
  }

  @override
  void didUpdateWidget(_AdapterModelField old) {
    super.didUpdateWidget(old);
    // AN UNDO MOVES THE MODEL UNDER THE FIELD, and the field must follow.
    // Not while somebody is typing in it, which would throw their text away.
    if (old.model != widget.model && !_focus.hasFocus) {
      _text.text = widget.model ?? '';
    }
  }

  void _commit() {
    final typed = _text.text.trim();
    final now = typed.isEmpty ? null : typed;
    if (now == widget.model) return;
    widget.onCommit(now);
  }

  @override
  void dispose() {
    // OFF BEFORE THE NODE GOES, or losing focus to its own disposal would
    // run a command while the tree is unmounting.
    _focus.removeListener(_onFocus);
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _text,
    focusNode: _focus,
    style: Theme.of(context).textTheme.bodySmall,
    decoration: const InputDecoration(
      isDense: true,
      hintText: kCableBarAdapterModelHint,
    ),
    onSubmitted: (_) => _commit(),
  );
}
