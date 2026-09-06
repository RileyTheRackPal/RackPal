// packages/rackpal_ui/lib/src/inspector/device_ports_section.dart
//
// M4-L4's form: correcting a fact about one jack. `#233`, CR-053.
//
// ─────────────────────────────────────────────────────────────────────────
// THE RESOLVER CAME FIRST, WHICH IS WHY THIS IS ALLOWED TO EXIST
// ─────────────────────────────────────────────────────────────────────────
// DR-098 §11.97.6 ruled that M4-L4 "owes a resolver before it owes a form",
// because `PortOverrides` had no reader anywhere and a form written against
// it would have been a save that changed nothing a person could see.
// `derived/port_facts.dart` landed first and `connect_target.dart` reads it,
// so a correction made here reaches the pin the connect gesture acts on.
//
// ─────────────────────────────────────────────────────────────────────────
// ONE PORT OPEN AT A TIME, AND THE REASON IS 68
// ─────────────────────────────────────────────────────────────────────────
// The drill template carries 68 ports and a 16x16 matrix carries 34, in a
// 320px column that already holds the lifecycle picker and door 1's four
// fields. Three editors per port, all mounted, is a scroll nobody reaches
// the bottom of. So the list is compact rows and exactly one expands.
//
// NO NESTED SCROLL VIEW. The section is already inside the inspector's
// `SingleChildScrollView`; a second one here would trap the wheel over the
// list and scroll the wrong thing, which is the classic version of this
// mistake.
//
// ─────────────────────────────────────────────────────────────────────────
// EVERY ROW SHOWS THE RESOLVED VALUE, NOT THE TEMPLATE'S
// ─────────────────────────────────────────────────────────────────────────
// A row that printed `PortDef.connector` while the instance overrode it
// would be a list disagreeing with the document it is a view of. The rows
// and the editors both go through `port_facts.dart`.

import 'package:flutter/material.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/src/theme/console_theme.dart';

/// Door 1's port half: the jacks on one placed device, and the three facts
/// a person may correct about each.
class DevicePortsSection extends StatefulWidget {
  const DevicePortsSection({
    required this.doc,
    required this.device,
    required this.onSetPortFact,
    super.key,
  });

  final RackDocument doc;
  final DeviceInstance device;

  /// Issues `SetPortFactCommand`. The designator is resolved here and
  /// handed over, because the command must not allocate inside `apply`
  /// (DR-011.1) and this is the caller.
  final void Function(
    PortKey portKey,
    PortFactField field,
    Object? value,
    String designatorIfMaterialised,
  )
  onSetPortFact;

  @override
  State<DevicePortsSection> createState() => _DevicePortsSectionState();
}

class _DevicePortsSectionState extends State<DevicePortsSection> {
  /// The one open row, or null when the list is collapsed to rows only.
  PortKey? _open;

  /// Whether the list itself is showing. Collapsed by default: a device
  /// with 68 ports would otherwise push door 1's fields off the top of the
  /// column on selection, which is the opposite of what a person clicked
  /// the device for.
  bool _expanded = false;

  TemplateBody? get _body {
    final ref = widget.device.templateRef;
    return widget
        .doc
        .templates[templateSnapshotKey(ref.templateId, ref.version)]
        ?.body;
  }

  /// The ports in the template's own order, which is the order the panel
  /// drawing and the port grid both use.
  List<PortDef> get _ports {
    // TOTAL, because `List.sort` is not stable and two ports sharing an
    // order must not swap between two builds of the same list. `FracIndex`
    // is an extension type over `String`, so the comparison is the raw
    // string one every other ordered derivation in core uses, and the key
    // breaks the tie because it is unique within a template.
    return [...?_body?.ports]..sort((a, b) {
      final byOrder = a.order.v.compareTo(b.order.v);
      return byOrder != 0 ? byOrder : a.key.v.compareTo(b.key.v);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ports = _ports;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        InkWell(
          onTap: ports.isEmpty
              ? null
              : () => setState(() => _expanded = !_expanded),
          child: Row(
            children: [
              Text(
                // NO COUNT WHEN THERE IS NOTHING TO COUNT. "PORTS (0)"
                // reads as something having gone wrong, and a template with
                // no ports is a blank panel or a shelf, which is a normal
                // thing to place. The first draft printed the zero and the
                // comment below claimed it did not, which is how a comment
                // and its code come apart.
                ports.isEmpty ? 'PORTS' : 'PORTS (${ports.length})',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.primary,
                  fontWeight: kConsoleEmphasis,
                  letterSpacing: 0.8,
                ),
              ),
              const Spacer(),
              if (ports.isNotEmpty)
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
            ],
          ),
        ),
        if (ports.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'This template declares no ports.',
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        if (_expanded)
          for (final def in ports) _row(context, def),
      ],
    );
  }

  Widget _row(BuildContext context, PortDef def) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final target = resolveConnectTarget(
      widget.doc,
      deviceId: widget.device.id,
      portKey: def.key.v,
    );
    final port = target?.materialisedPort;
    final label = resolvePortLabel(port, def);
    final connector = resolvePortConnector(port, def);
    final family = resolvePortSignalFamily(port, def);
    final corrected =
        port != null &&
        (port.userLabel != null ||
            port.overrides.connector != null ||
            port.overrides.signalFamily != null);
    final isOpen = _open == def.key;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          key: ValueKey('port-row-${def.key.v}'),
          onTap: () => setState(() => _open = isOpen ? null : def.key),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                // A MARK, NOT A COLOUR ALONE (DR-090 §11.89.6): the dot is
                // accompanied by the word in its tooltip, and the row's
                // editors say the same thing in full when it is opened.
                if (corrected)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Tooltip(
                      message: 'Corrected on this device',
                      child: Text(
                        '*',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: kConsoleEmphasis,
                          color: scheme.primary,
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    _connectorName(connector),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (isOpen)
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 12),
            child: _editors(context, def, port, connector, family),
          ),
      ],
    );
  }

  Widget _editors(
    BuildContext context,
    PortDef def,
    Port? port,
    ConnectorTypeId connector,
    SignalFamilyId family,
  ) {
    final registries = widget.doc.registries;
    final planned =
        resolveConnectTarget(
          widget.doc,
          deviceId: widget.device.id,
          portKey: def.key.v,
        )?.plannedDesignator ??
        def.key.v;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PortLabelField(
          key: ValueKey('port-label-${def.key.v}'),
          value: port?.userLabel ?? '',
          hint: def.label.trim().isEmpty ? def.key.v : def.label,
          onCommit: (v) => widget.onSetPortFact(
            def.key,
            PortFactField.userLabel,
            v.trim().isEmpty ? null : v.trim(),
            planned,
          ),
        ),
        const SizedBox(height: 8),
        _PortPicker<ConnectorTypeId>(
          fieldKey: ValueKey('port-connector-${def.key.v}'),
          label: 'CONNECTOR',
          value: connector,
          values: registries.connectorTypes.keys.toList(),
          nameOf: _connectorName,
          fromTemplate: def.connector,
          overridden: port?.overrides.connector != null,
          onChanged: (v) => widget.onSetPortFact(
            def.key,
            PortFactField.connector,
            v,
            planned,
          ),
        ),
        const SizedBox(height: 8),
        _PortPicker<SignalFamilyId>(
          fieldKey: ValueKey('port-family-${def.key.v}'),
          label: 'SIGNAL FAMILY',
          value: family,
          values: registries.signalFamilies.keys.toList(),
          nameOf: _familyName,
          fromTemplate: def.signalFamily,
          overridden: port?.overrides.signalFamily != null,
          onChanged: (v) => widget.onSetPortFact(
            def.key,
            PortFactField.signalFamily,
            v,
            planned,
          ),
        ),
        // ═══════════════════════════════════════════════════════════════
        // THE TRANSFORMER, ONLY ON A CONSTANT-VOLTAGE PIN (DR-131/DR-132)
        // ═══════════════════════════════════════════════════════════════
        // Gated on the RESOLVED family rather than the template's, so a
        // pin the user corrected to `audio.speaker_cv` grows the controls
        // and one corrected away from it loses them. Every port getting a
        // tap box would be noise on 700-odd pins that have no
        // transformer.
        if (family == kSpeakerCv || (port?.lowZBypass ?? false)) ...[
          const SizedBox(height: 8),
          _PortTapField(
            key: ValueKey('port-tap-${def.key.v}'),
            value: port?.tapWatts,
            onCommit: (v) => widget.onSetPortFact(
              def.key,
              PortFactField.tapWatts,
              v,
              planned,
            ),
          ),
          _PortBypassToggle(
            fieldKey: ValueKey('port-bypass-${def.key.v}'),
            value: port?.lowZBypass ?? false,
            onChanged: (v) => widget.onSetPortFact(
              def.key,
              PortFactField.lowZBypass,
              v,
              planned,
            ),
          ),
        ],
      ],
    );
  }

  /// `HDMI Type A` where the model holds `conn.hdmi_a`, falling back to the
  /// raw id when the project's registries do not declare it: an id a person
  /// can look up beats a blank.
  String _connectorName(ConnectorTypeId id) =>
      widget.doc.registries.connectorTypes[id]?.displayName ?? id.v;

  String _familyName(SignalFamilyId id) =>
      widget.doc.registries.signalFamilies[id]?.displayName ?? id.v;
}

/// The user's own name for a jack. Not an override: `Port.userLabel` is a
/// first-class field, and `PortOverrides.label` was its unread duplicate
/// until `#233` deleted it.
class _PortLabelField extends StatefulWidget {
  const _PortLabelField({
    required this.value,
    required this.hint,
    required this.onCommit,
    super.key,
  });

  final String value;

  /// What the template says is printed on the jack, shown as placeholder so
  /// an empty box reads as "the silkscreen stands" rather than as blank.
  final String hint;
  final ValueChanged<String> onCommit;

  @override
  State<_PortLabelField> createState() => _PortLabelFieldState();
}

class _PortLabelFieldState extends State<_PortLabelField> {
  late final TextEditingController _text = TextEditingController(
    text: widget.value,
  );
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(_commitOnBlur);
  }

  @override
  void didUpdateWidget(_PortLabelField old) {
    super.didUpdateWidget(old);
    // Only while unfocused, which is `_InspectorTextField`'s rule and is
    // here for its reason: this panel rebuilds on every epoch bump and
    // overwriting a buffer mid-keystroke eats what was typed.
    if (_focus.hasFocus) return;
    if (widget.value != _text.text) _text.text = widget.value;
  }

  @override
  void dispose() {
    _focus
      ..removeListener(_commitOnBlur)
      ..dispose();
    _text.dispose();
    super.dispose();
  }

  void _commitOnBlur() {
    if (_focus.hasFocus) return;
    if (_text.text == widget.value) return;
    widget.onCommit(_text.text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'LABEL',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: kConsoleEmphasis,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: _text,
          focusNode: _focus,
          onSubmitted: widget.onCommit,
          decoration: InputDecoration(
            isDense: true,
            border: const OutlineInputBorder(),
            hintText: widget.hint,
          ),
        ),
      ],
    );
  }
}

/// The label above the transformer tap box, and the string a test looks
/// for.
const String kPortTapLabel = 'TAP (W)';

/// The label on the bypass toggle.
const String kPortBypassLabel = 'Transformer bypassed (low-Z)';

/// What the tap box shows when nothing is recorded.
///
/// NOT "0", AND NOT BLANK-MEANING-ZERO. `ELE-005` counts an unrecorded
/// tap as an UNKNOWN and names the speaker in its message, so an empty
/// box is a real state with a consequence, and the hint says which state
/// it is.
const String kPortTapHint = 'not recorded';

/// The transformer tap in watts, typed rather than picked.
///
/// DR-132 §11.130.8: there is no single tap ladder. Episode ships
/// 7.5/15/30/60, Beale Street ranges from 1/1.9/3.8/7.5/15 to that same
/// scheme, and `F08`'s own catalogue description hard-codes a third set.
/// A dropdown would be wrong on somebody's speaker.
class _PortTapField extends StatefulWidget {
  const _PortTapField({
    required this.value,
    required this.onCommit,
    super.key,
  });

  final int? value;
  final ValueChanged<int?> onCommit;

  @override
  State<_PortTapField> createState() => _PortTapFieldState();
}

class _PortTapFieldState extends State<_PortTapField> {
  late final TextEditingController _text = TextEditingController(
    text: widget.value?.toString() ?? '',
  );
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(_commitOnBlur);
  }

  @override
  void didUpdateWidget(_PortTapField old) {
    super.didUpdateWidget(old);
    // Only while unfocused, for `_PortLabelField`'s reason: this panel
    // rebuilds on every epoch bump and overwriting a buffer mid-keystroke
    // eats what was typed.
    if (_focus.hasFocus) return;
    final incoming = widget.value?.toString() ?? '';
    if (incoming != _text.text) _text.text = incoming;
  }

  @override
  void dispose() {
    _focus
      ..removeListener(_commitOnBlur)
      ..dispose();
    _text.dispose();
    super.dispose();
  }

  void _commitOnBlur() {
    if (_focus.hasFocus) return;
    _commit(_text.text);
  }

  /// AN UNPARSEABLE ENTRY IS LEFT ALONE RATHER THAN TREATED AS CLEARED.
  /// "1o" is a typo, and turning it into "no tap recorded" would silently
  /// change what `ELE-005` reports about this line.
  void _commit(String raw) {
    final t = raw.trim();
    if (t.isEmpty) {
      if (widget.value != null) widget.onCommit(null);
      return;
    }
    final parsed = int.tryParse(t);
    if (parsed == null || parsed < 0) return;
    if (parsed != widget.value) widget.onCommit(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          kPortTapLabel,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: kConsoleEmphasis,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: _text,
          focusNode: _focus,
          keyboardType: TextInputType.number,
          onSubmitted: _commit,
          decoration: const InputDecoration(
            isDense: true,
            border: OutlineInputBorder(),
            hintText: kPortTapHint,
          ),
        ),
      ],
    );
  }
}

/// Whether the transformer is switched out, making this pin low impedance.
class _PortBypassToggle extends StatelessWidget {
  const _PortBypassToggle({
    required this.fieldKey,
    required this.value,
    required this.onChanged,
  });

  final ValueKey<String> fieldKey;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => CheckboxListTile(
    key: fieldKey,
    value: value,
    onChanged: (v) => onChanged(v ?? false),
    dense: true,
    contentPadding: EdgeInsets.zero,
    controlAffinity: ListTileControlAffinity.leading,
    title: Text(
      kPortBypassLabel,
      style: Theme.of(context).textTheme.bodySmall,
    ),
  );
}

/// A registry-backed picker with a "back to the template" escape.
class _PortPicker<T> extends StatelessWidget {
  const _PortPicker({
    required this.fieldKey,
    required this.label,
    required this.value,
    required this.values,
    required this.nameOf,
    required this.fromTemplate,
    required this.overridden,
    required this.onChanged,
  });

  final Key fieldKey;
  final String label;
  final T value;
  final List<T> values;
  final String Function(T) nameOf;
  final T fromTemplate;
  final bool overridden;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // THE RESOLVED VALUE MUST BE IN THE LIST OR THE DROPDOWN ASSERTS. A
    // template may name a connector this project's registries do not
    // declare (an imported `.rmdx`, a hand-authored body), and dropping it
    // from the list would make the control unable to show what the port
    // actually is.
    final options = <T>[
      if (!values.contains(value)) value,
      ...values,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
            fontWeight: kConsoleEmphasis,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 4),
        DropdownButtonFormField<T>(
          key: fieldKey,
          initialValue: value,
          isExpanded: true,
          decoration: const InputDecoration(
            isDense: true,
            border: OutlineInputBorder(),
          ),
          items: [
            for (final v in options)
              DropdownMenuItem<T>(
                value: v,
                child: Text(nameOf(v), overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: onChanged,
        ),
        if (overridden)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => onChanged(null),
              child: Text('Use the template’s (${nameOf(fromTemplate)})'),
            ),
          ),
      ],
    );
  }
}
