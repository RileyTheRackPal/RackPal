// packages/rackpal_ui/lib/src/inspector/device_overrides_section.dart
//
// Door 1 of CR-054: "edit this device only" (DR-098 §11.97.5).
//
// ─────────────────────────────────────────────────────────────────────────
// WHY THIS IS IN THE COLUMN AND NOT IN A MODAL
// ─────────────────────────────────────────────────────────────────────────
// Two of the four fields change something the user is looking at: the
// accent IS the device body fill (DR-080 §11.79.4) and the mass moves the
// rack's load gutter. A modal over the elevation hides the thing the edit
// changes, and the amber badge's whole job is to say what this edit does
// NOT touch, which is a claim best read beside the devices it is about.
//
// It also retires `inspector_panel.dart`'s deferral in the file that wrote
// it. That header rules that "rendering a plausible-looking device form
// with no working fields would be worse than rendering the honest
// summary", and notes the lifecycle picker does not break the rule because
// it is the opposite case: a value the model held and nothing could edit.
// Every field here is that same opposite case, and DR-098's census is the
// evidence -- `typicalWatts` and `weight` reach `derived/device_loads.dart`
// and `accentColor` reaches `draw/scene/device_layer.dart` already.
//
// ─────────────────────────────────────────────────────────────────────────
// THREE SEGMENTS, NOT A TEXT BOX WITH TWO TRICKS
// ─────────────────────────────────────────────────────────────────────────
// The user chose the explicit control, and the reason is that UNKNOWN is
// novel: no tool in this trade has it, so nobody arrives looking for it. A
// third state reachable only by clearing a box or opening an overflow menu
// is a third state that ships unused, and an unused UNKNOWN puts us back
// where DR-098 started -- a rack subtotal built on a template figure the
// user knows is wrong and has no way to disown.
//
// The segments are labelled by what they MEAN rather than by their state
// names: "Template" not "Inherit", because the question a person is
// answering is "where does this number come from", and "the template" is
// an answer to that where "inherit" is a word about the software.
//
// ─────────────────────────────────────────────────────────────────────────
// ONE DEVICE ONLY
// ─────────────────────────────────────────────────────────────────────────
// `#183` describes right-clicking A device, and the amber badge counts the
// others on ITS template. A multi-selection may span several templates, at
// which point the badge's number has no single meaning and the control
// needs a "Mixed" rendering for three states across N devices. The
// lifecycle picker above acts on the whole selection and is right to; this
// says so and stops, which is the honest version of the same choice.

import 'package:flutter/material.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/src/theme/console_theme.dart';

/// Which of the three states a segmented control is showing.
enum _Segment { template, value, unknown }

/// Door 1's editor for one placed device.
class DeviceOverridesSection extends StatelessWidget {
  const DeviceOverridesSection({
    required this.doc,
    required this.device,
    required this.onSetOverride,
    super.key,
  });

  final RackDocument doc;
  final DeviceInstance device;

  /// Issues the `SetEntityPropertyCommand` for one override field. Typed
  /// per call so `Mass` stays `Mass` from the control to the command.
  final void Function<T>(
    EntityField<DeviceInstance, OverrideValue<T>> field,
    OverrideValue<T> value,
  )
  onSetOverride;

  /// The template body behind [device], or null when the snapshot does not
  /// resolve. A missing body is not an error here: the fields still edit,
  /// and "Template" simply has nothing to offer.
  TemplateBody? get _body {
    final key = templateSnapshotKey(
      device.templateRef.templateId,
      device.templateRef.version,
    );
    return doc.templates[key]?.body;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final body = _body;
    final others = countOtherDevicesOnTemplate(doc, device);
    final units = doc.settings.displayUnits;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text(
          'THIS DEVICE ONLY',
          style: theme.textTheme.labelSmall?.copyWith(
            color: scheme.primary,
            fontWeight: kConsoleEmphasis,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        _ScopeBadge(others: others),
        const SizedBox(height: 4),
        _OverrideField<Mass>(
          label: 'MASS',
          state: device.overrides.weightState,
          fromTemplate: body?.weight,
          // The SAME formatter the load gutter and T6.30 use, so the box
          // and the sheet cannot print one mass two ways.
          format: (m) => units == UnitSystem.metric
              ? m.toKilogramsValue(fractionDigits: 1)
              : m.toPoundsValue(fractionDigits: 1),
          suffix: units == UnitSystem.metric ? 'kg' : 'lb',
          parse: (s) {
            final n = double.tryParse(s.trim());
            if (n == null || n < 0) return null;
            return units == UnitSystem.metric
                ? Mass.fromKilograms(n)
                : Mass.fromPounds(n);
          },
          onChanged: (v) => onSetOverride<Mass>(DeviceField.overrideWeight, v),
        ),
        _OverrideField<int>(
          label: 'TYPICAL DRAW',
          state: device.overrides.typicalWattsState,
          // AC-039: the template's TYPICAL watts, never its nameplate.
          // Offering nameplate here as "the template value" would derive
          // one from the other through the user's fingers.
          fromTemplate: body?.power.typicalWatts,
          format: (w) => '$w',
          suffix: 'W',
          parse: (s) {
            final n = int.tryParse(s.trim());
            return (n == null || n < 0) ? null : n;
          },
          onChanged: (v) =>
              onSetOverride<int>(DeviceField.overrideTypicalWatts, v),
        ),
      ],
    );
  }
}

/// The amber badge. Names what this edit will NOT change.
class _ScopeBadge extends StatelessWidget {
  const _ScopeBadge({required this.others});

  final int others;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // ZERO IS A REAL ANSWER AND GETS ITS OWN SENTENCE. "0 other devices
    // are unaffected" invites the reader to wonder which ones were, and a
    // template placed once has no blast radius to reassure anybody about.
    final text = others == 0
        ? 'Only this device uses this template.'
        : others == 1
        ? 'Edits here change this device only. 1 other device on this '
              'template is unaffected.'
        : 'Edits here change this device only. $others other devices on '
              'this template are unaffected.';

    // AN INK AND A BORDER, NOT A FILL. `kConsoleScopeInstance` clears
    // 4.5:1 against the card it draws on and that is the only bar it has
    // to clear; a scope fill would need its own ink and its own pair of
    // assertions to earn. DR-090 §11.89.6 is satisfied by the SENTENCE:
    // delete the colour and the badge still says what it says.
    const amber = Color(kConsoleScopeInstance);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: amber),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(color: amber),
      ),
    );
  }
}

/// One field: three segments, a value box, and a line saying where the
/// number currently comes from.
class _OverrideField<T> extends StatefulWidget {
  const _OverrideField({
    required this.label,
    required this.state,
    required this.fromTemplate,
    required this.format,
    required this.suffix,
    required this.parse,
    required this.onChanged,
  });

  final String label;
  final OverrideValue<T> state;
  final T? fromTemplate;
  final String Function(T) format;
  final String suffix;
  final T? Function(String) parse;
  final ValueChanged<OverrideValue<T>> onChanged;

  @override
  State<_OverrideField<T>> createState() => _OverrideFieldState<T>();
}

class _OverrideFieldState<T> extends State<_OverrideField<T>> {
  late final TextEditingController _text = TextEditingController(
    text: switch (widget.state) {
      OverrideStated<T>(:final value) => widget.format(value),
      _ => '',
    },
  );
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(_commitOnBlur);
  }

  @override
  void didUpdateWidget(_OverrideField<T> old) {
    super.didUpdateWidget(old);
    // Only re-sync while UNFOCUSED, which is `_InspectorTextField`'s rule
    // and it is here for its reason: this panel rebuilds on every epoch
    // bump, and overwriting a buffer mid-keystroke eats what was typed.
    if (_focus.hasFocus) return;
    final next = switch (widget.state) {
      OverrideStated<T>(:final value) => widget.format(value),
      _ => '',
    };
    if (next != _text.text) _text.text = next;
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
    _commit();
  }

  void _commit() {
    final parsed = widget.parse(_text.text);
    if (parsed == null) {
      // A REFUSAL RESTORES, it does not silently keep nonsense in the
      // box. There is no override to write for "twelve-ish".
      // AN EMPTY BOX IS NOT NONSENSE, it is an edit not yet made. Only a
      // box with unparseable CONTENT gets reverted; an empty one is left
      // alone so the user can come back to it.
      if (_text.text.trim().isEmpty) return;
      setState(() {
        _text.text = switch (widget.state) {
          OverrideStated<T>(:final value) => widget.format(value),
          _ => '',
        };
      });
      return;
    }
    // Re-committing the same number is not an edit, and letting it through
    // would put an undo frame on the stack for a blur that changed nothing.
    final current = widget.state;
    if (current is OverrideStated<T> && current.value == parsed) return;
    widget.onChanged(OverrideStated<T>(parsed));
  }

  /// "The user has chosen Value but has not typed a usable number yet."
  ///
  /// THERE IS NO MODEL STATE FOR THIS, and there should not be: an
  /// override that states nothing IS an inherit, and inventing a fourth
  /// persisted state to hold a half-finished edit would put it in the
  /// file and in the undo stack. So the intent lives here, in the widget,
  /// for as long as the box is open.
  ///
  /// IT EXISTS BECAUSE THE FIRST DRAFT WITHOUT IT WAS BROKEN, and the
  /// widget test found it: `_select` seeded the box from the template and
  /// bailed out when there was nothing to seed from, so on a template that
  /// states no mass -- which is every template on the demo rack, and the
  /// commonest case there is -- tapping "Value" did nothing whatsoever.
  /// Stating a value for a fact the template omits is the whole point of
  /// door 1 and it was the one path that could not be reached.
  bool _valueIntent = false;

  _Segment get _segment => switch (widget.state) {
    OverrideInherited<T>() => _valueIntent ? _Segment.value : _Segment.template,
    OverrideStated<T>() => _Segment.value,
    OverrideUnknown<T>() => _Segment.unknown,
  };

  void _select(_Segment s) {
    switch (s) {
      case _Segment.template:
        setState(() => _valueIntent = false);
        widget.onChanged(OverrideInherited<T>());
      case _Segment.unknown:
        setState(() => _valueIntent = false);
        widget.onChanged(OverrideUnknown<T>());
      case _Segment.value:
        // Choosing "Value" SEEDS the box from the template when there is
        // one: the user is saying "this device differs", not "I have
        // forgotten what it was", and an empty box would make them retype
        // a number already on screen. When the template states nothing
        // the box opens empty and the model is not written until they
        // type something that parses.
        setState(() => _valueIntent = true);
        final seed = widget.parse(_text.text) ?? widget.fromTemplate;
        if (seed != null && widget.state is! OverrideStated<T>) {
          widget.onChanged(OverrideStated<T>(seed));
        }
        _focus.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final template = widget.fromTemplate;

    final provenance = switch (widget.state) {
      OverrideInherited<T>() when template != null =>
        'From the template: ${widget.format(template)} ${widget.suffix}',
      OverrideInherited<T>() =>
        'The template does not state one, so this is unknown',
      OverrideStated<T>() => 'Overridden on this device',
      OverrideUnknown<T>() =>
        'Unknown on this device. Counted, never totalled.',
    };

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: kConsoleEmphasis,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 6),
          // KEYED BY THE FIELD'S LABEL, because both fields carry the
          // identical three segment words and a bare `find.text('Unknown')`
          // matches two of them. A finder that cannot say which one it
          // found passes against the wrong control.
          SegmentedButton<_Segment>(
            key: ValueKey('override-segments-${widget.label}'),
            segments: const [
              ButtonSegment(value: _Segment.template, label: Text('Template')),
              ButtonSegment(value: _Segment.value, label: Text('Value')),
              ButtonSegment(value: _Segment.unknown, label: Text('Unknown')),
            ],
            selected: {_segment},
            showSelectedIcon: false,
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onSelectionChanged: (s) => _select(s.single),
          ),
          if (_segment == _Segment.value) ...[
            const SizedBox(height: 6),
            TextField(
              key: ValueKey('override-value-${widget.label}'),
              controller: _text,
              focusNode: _focus,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onSubmitted: (_) => _commit(),
              decoration: InputDecoration(
                isDense: true,
                border: const OutlineInputBorder(),
                suffixText: widget.suffix,
              ),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            provenance,
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
