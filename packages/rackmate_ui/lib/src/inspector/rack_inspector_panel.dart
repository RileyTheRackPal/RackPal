// packages/rackmate_ui/lib/src/inspector/rack_inspector_panel.dart
//
// docs/04-rack-editor.md §4's `RackInspector`, in the 320px fourth column
// §1 specifies. Four sections, in the spec's own order:
//
//   Identity     Name, Designator, Location
//   Form factor  Preset, Height, Width, Usable depth, Rail type,
//                Weight capacity (+ read-only Own weight), Mount,
//                Swing frame (+ Hinge side), Ground bar
//   Display      RU numbering, Mirror rear elevation
//   Circuits     the flat list filtered by rackId (CR-028)
//
// EVERY EDITABLE FIELD ROUTES THROUGH A COMMAND, and this widget cannot
// bypass that even by accident: `Rack`'s twelve editable properties carry
// `@internal` setters (AC-013), so assigning to one of them directly from
// here would not compile against the package boundary — and, belt to that
// brace, `internal_setter_grep_test.dart` now scans `rackmate_ui/lib` and
// fails on the textual pattern too. (Which is why this paragraph describes
// the forbidden assignment in words instead of spelling one out: that grep
// cannot tell prose from code, and it is right not to try.) The only writes
// this file performs are calls to
// [onSetProperty] (which builds a `SetEntityPropertyCommand`), [onRename]
// (`RenameEntityCommand`), [onRequestHeight] (`SetRackHeightCommand`,
// through the screen's one height funnel) and [onApplyPreset] (one
// `Transaction`).
//
// COMMIT DISCIPLINE, one rule for the whole panel. §4.1 states "commits on
// blur or Enter" for the height field specifically; applying it uniformly to
// every text and numeric field means a user never has to remember which box
// behaves which way. Dropdowns, radios and checkboxes commit on change (they
// have no intermediate state to protect). `Esc` in a focused text field
// reverts the buffer to the model value and runs NO command — a genuine
// cancel, not a write-back of the old value, which would otherwise push a
// pointless undo entry.
//
// REFUSAL IS NEVER SILENT (§3.4). An unparseable number does not quietly
// snap back: it reverts the buffer AND reports on the status line via
// [onRefuse]. An out-of-range height clamps to CR-038's [1, 60] and says so.
//
// THE PRESET DROPDOWN IS WRITE-ONLY, deliberately. A `Rack` has no
// `presetRef` — applying a preset is a fan-out of writes to ordinary fields
// (see rack_presets.dart) — so the dropdown displays whichever preset
// currently MATCHES the rack's values, and "Custom" once any of them has been
// edited away. That is the honest render of data the document actually
// holds; remembering "this is still a Wall box" after the user changed its
// height and depth would be the UI telling a story the file does not.
//
// WHAT THIS PANEL DELIBERATELY DOES NOT HAVE, so a reader does not read an
// omission as an oversight:
//   * The Location dropdown's "+ New…" item. The project Locations panel
//     (CR-112) is out of scope for this stage; a menu item opening nothing
//     is the dead affordance §3.4 forbids. The dropdown ITSELF is real,
//     enabled and command-backed over `doc.locations`.
//   * A [+ Add circuit] button, for the same reason — no circuit-creating
//     command exists in any package. One caption line says so instead.
//   * Rack Vitals, the chip strip and the findings rollup (§5): no
//     validation engine exists anywhere in this codebase.
//   * §4.2's finding filings. Usable depth, width class and weight capacity
//     are fully editable and undoable here; reducing them displaces nothing
//     and — until a validation engine exists — files nothing.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show FilteringTextInputFormatter, KeyDownEvent, LogicalKeyboardKey;
import 'package:rackmate_core/rackmate_core.dart';

/// §4's `RackInspector`. Stateless in its own right; the mutable buffers
/// live in the individual field widgets below, each of which re-syncs from
/// the model whenever it is not focused (so an undo repaints the panel).
class RackInspectorPanel extends StatelessWidget {
  const RackInspectorPanel({
    required this.rack,
    required this.doc,
    required this.presets,
    required this.onSetProperty,
    required this.onRename,
    required this.onRequestHeight,
    required this.onApplyPreset,
    required this.onRefuse,
    this.firstFieldFocus,
    super.key,
  });

  final Rack rack;

  /// Read for `doc.locations` (the Location dropdown) and `doc.circuits`
  /// (the Circuits list). Never mutated here — see the file header.
  final RackDocument doc;

  /// `buildRackPresets()`'s result, injected rather than built here so the
  /// panel has no hidden data source and a test can supply a small set.
  final Map<String, RackPreset> presets;

  /// Runs one `SetEntityPropertyCommand`. Generic so the twelve call sites
  /// below keep full static typing — the whole reason `RackField` is an
  /// accessor table rather than an `Object?` payload.
  final void Function<T>(EntityField<Rack, T> field, T value) onSetProperty;

  /// `RenameEntityCommand(targetKind: rack)` — `name` is the one identity
  /// field that already had a command before this stage.
  final ValueChanged<String> onRename;

  /// The screen's ONE height funnel (§4.1: "Three ways to set height, ALL
  /// producing one ResizeRackCommand"). The inspector field is way two; the
  /// header stepper and the drag-the-top-edge gesture (ways one and three)
  /// land in the next pass and call this same funnel.
  final ValueChanged<int> onRequestHeight;

  final ValueChanged<RackPreset> onApplyPreset;

  /// Reports a refused edit on the status line (§3.4's "never silently do
  /// nothing").
  final ValueChanged<String> onRefuse;

  /// Focused when the panel is opened via `Ctrl+Alt+U`, so the keyboard
  /// path lands somewhere useful rather than nowhere.
  final FocusNode? firstFieldFocus;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        const _SectionHeader('Identity'),
        _InspectorTextField(
          label: 'Name',
          value: rack.name,
          focusNode: firstFieldFocus,
          onCommit: onRename,
        ),
        _InspectorTextField(
          label: 'Designator',
          // CR-040: "the ONLY rack identifier".
          helper: 'The only rack identifier.',
          value: rack.designator,
          onCommit: (v) => onSetProperty(RackField.designator, v),
          // An empty designator would leave the rack unnameable on every
          // other surface (the header, the status line, a future PDF title
          // block), so it is refused rather than accepted.
          validate: (v) =>
              v.trim().isEmpty ? 'A rack needs a designator.' : null,
          onRefuse: onRefuse,
        ),
        _LocationField(
          rack: rack,
          doc: doc,
          onSetProperty: onSetProperty,
        ),

        const _SectionHeader('Form factor'),
        _PresetField(
          rack: rack,
          presets: presets,
          onApplyPreset: onApplyPreset,
        ),
        _InspectorTextField(
          label: 'Height (U)',
          helper: rack.heightU > 50
              // CR-038: "advisory above 50".
              ? 'Above 50U is unusual — check your enclosure.'
              : null,
          value: '${rack.heightU}',
          keyboardType: TextInputType.number,
          digitsOnly: true,
          onCommit: (v) {
            final parsed = int.tryParse(v.trim());
            if (parsed == null) return; // validate() already refused it.
            // CR-038's ceiling is read, not retyped: the guard, the clamp
            // and the sentence the user reads must all move together when
            // the constant does, or the refusal text starts naming a range
            // the app no longer enforces.
            if (parsed < 1 || parsed > kMaxRackHeightU) {
              onRefuse(
                'Height clamped to ${parsed.clamp(1, kMaxRackHeightU)}U '
                '(1–$kMaxRackHeightU).',
              );
            }
            onRequestHeight(parsed);
          },
          validate: (v) => int.tryParse(v.trim()) == null
              ? 'Height must be a whole number of U.'
              : null,
          onRefuse: onRefuse,
        ),
        InspectorDropdown<RackWidthClass>(
          label: 'Width',
          value: rack.widthClass,
          values: RackWidthClass.values,
          labelOf: widthClassLabel,
          onChanged: (v) => onSetProperty(RackField.widthClass, v),
        ),
        _NullableLengthField(
          label: 'Usable depth (mm)',
          value: rack.usableDepth,
          onCommit: (v) => onSetProperty(RackField.usableDepth, v),
          onRefuse: onRefuse,
        ),
        InspectorDropdown<RailType>(
          label: 'Rail type',
          value: rack.railType,
          values: RailType.values,
          labelOf: railTypeLabel,
          onChanged: (v) => onSetProperty(RackField.railType, v),
        ),
        _NullableMassField(
          label: 'Weight capacity (kg)',
          value: rack.weightCapacity,
          onCommit: (v) => onSetProperty(RackField.weightCapacity, v),
          onRefuse: onRefuse,
        ),
        _ReadOnlyRow(
          label: 'Own weight',
          // CR-114: null means UNKNOWN, and an unknown must LOOK unknown —
          // never 0 kg, which would silently enter a future weight rollup as
          // a real measurement.
          value: rack.ownWeight == null
              ? '—'
              : rack.ownWeight!.toKilograms(fractionDigits: 1),
        ),
        _MountField(rack: rack, onSetProperty: onSetProperty),
        _InspectorCheckbox(
          label: 'Swing frame',
          value: rack.isSwingFrame,
          onChanged: (v) => onSetProperty(RackField.isSwingFrame, v),
        ),
        InspectorDropdown<HingeSide?>(
          label: 'Hinge side',
          value: rack.hingeSide,
          values: const [null, HingeSide.left, HingeSide.right],
          labelOf: (v) => v == null ? '—' : hingeSideLabel(v),
          // Meaningless on a non-swinging frame, so disabled and dashed
          // rather than offering a value the model would carry but nothing
          // would honour.
          enabled: rack.isSwingFrame,
          onChanged: (v) => onSetProperty(RackField.hingeSide, v),
        ),
        _InspectorCheckbox(
          label: 'Ground bar present',
          value: rack.groundBarPresent,
          onChanged: (v) => onSetProperty(RackField.groundBarPresent, v),
        ),

        const _SectionHeader('Display'),
        _RuNumberingField(rack: rack, onSetProperty: onSetProperty),
        _InspectorCheckbox(
          label: 'Mirror rear elevation',
          value: rack.mirrorRearElevation,
          onChanged: (v) => onSetProperty(RackField.mirrorRearElevation, v),
        ),

        const _SectionHeader('Circuits'),
        _CircuitsSection(rack: rack, doc: doc),
      ],
    );
  }
}

// ── enum display names ──────────────────────────────────────────────────
//
// Public so a test can assert against the same strings the panel shows,
// rather than hardcoding a second copy that could drift.

/// e.g. `RackWidthClass.eia19` -> `'EIA 19"'`.
String widthClassLabel(RackWidthClass v) => switch (v) {
  RackWidthClass.eia19 => 'EIA 19"',
  RackWidthClass.eia23 => 'EIA 23"',
  RackWidthClass.tenInch => '10"',
  RackWidthClass.etsi => 'ETSI',
  RackWidthClass.customWidth => 'Custom',
};

String railTypeLabel(RailType v) => switch (v) {
  RailType.tapped10_32 => 'Tapped 10-32',
  RailType.tapped12_24 => 'Tapped 12-24',
  RailType.squareCageNut => 'Square (cage nut)',
  RailType.roundClearance => 'Round clearance',
  RailType.m6 => 'M6',
};

String hingeSideLabel(HingeSide v) => v == HingeSide.left ? 'Left' : 'Right';

/// docs/04 §4's Mount radio is a TWO-way control over an EIGHT-value
/// `RackFormFactor`. This is the mapping, stated explicitly because the
/// spec does not make it: three form factors are wall-mounted, five are
/// floor-standing.
bool isWallMounted(RackFormFactor v) =>
    v == RackFormFactor.wallFixed ||
    v == RackFormFactor.wallSwingGate ||
    v == RackFormFactor.wallPivotCabinet;

/// The `RackFormFactor` the Mount radio should write when the user picks
/// [wall], given the rack's [current] value.
///
/// PRESERVES THE EXISTING SUBTYPE. Toggling Wall -> Floor -> Wall on a
/// pivot cabinet lands back on a pivot cabinet, not on a generic
/// `wallFixed`, because a two-way radio must not be able to destroy the
/// more specific fact a preset put there. Only a cross-category move picks
/// the category's generic member.
RackFormFactor mountFormFactor(RackFormFactor current, {required bool wall}) {
  if (wall == isWallMounted(current)) return current;
  return wall ? RackFormFactor.wallFixed : RackFormFactor.floorEnclosure;
}

/// The id of the preset whose every value matches [rack], or null for
/// "Custom" — see the file header on why this is derived rather than stored.
String? matchingPresetId(Rack rack, Map<String, RackPreset> presets) {
  for (final entry in presets.entries) {
    final p = entry.value;
    if (p.heightU == rack.heightU &&
        p.formFactor == rack.formFactor &&
        p.widthClass == rack.widthClass &&
        p.railType == rack.railType &&
        p.usableDepth == rack.usableDepth &&
        p.weightCapacity == rack.weightCapacity &&
        p.isSwingFrame == rack.isSwingFrame &&
        p.hingeSide == rack.hingeSide) {
      return entry.key;
    }
  }
  return null;
}

// ── section chrome ──────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 6),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: scheme.primary,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _ReadOnlyRow extends StatelessWidget {
  const _ReadOnlyRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ── the field widgets ───────────────────────────────────────────────────

/// A labelled text field that commits on blur or Enter, reverts on `Esc`,
/// and re-syncs from the model whenever it is not focused.
///
/// The re-sync matters more than it looks: an `undo` changes the document
/// without touching this widget's buffer, so without it the panel would
/// keep displaying the value the user just undid.
class _InspectorTextField extends StatefulWidget {
  const _InspectorTextField({
    required this.label,
    required this.value,
    required this.onCommit,
    this.helper,
    this.focusNode,
    this.keyboardType,
    this.digitsOnly = false,
    this.validate,
    this.onRefuse,
  });

  final String label;
  final String? helper;
  final String value;
  final ValueChanged<String> onCommit;
  final FocusNode? focusNode;
  final TextInputType? keyboardType;
  final bool digitsOnly;

  /// Returns a refusal reason, or null when [String] is acceptable. A
  /// refused commit reverts the buffer and reports through [onRefuse]
  /// rather than silently swallowing the keystrokes (§3.4).
  final String? Function(String)? validate;
  final ValueChanged<String>? onRefuse;

  @override
  State<_InspectorTextField> createState() => _InspectorTextFieldState();
}

class _InspectorTextFieldState extends State<_InspectorTextField> {
  late final TextEditingController _text = TextEditingController(
    text: widget.value,
  );
  late final FocusNode _focus = widget.focusNode ?? FocusNode();
  bool _ownsFocusNode = false;

  @override
  void initState() {
    super.initState();
    _ownsFocusNode = widget.focusNode == null;
    _focus.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(_InspectorTextField old) {
    super.didUpdateWidget(old);
    // Only re-sync while UNFOCUSED: overwriting a buffer the user is
    // actively typing into would eat their keystrokes on every unrelated
    // rebuild (and this panel rebuilds on every epoch bump).
    //
    // THE FOCUS GATE IS NOT A HOLE, and it is worth saying why, because
    // docs/04 §4.1's shrink modal looks like one: the Height field opens
    // that modal, so "the field is still focused when the answer comes
    // back" would leave a buffer stating a height the rack does not have.
    // It cannot be. Both of this widget's commit paths are provably
    // unfocused by the time the screen resolves anything — `_onFocusChanged`
    // fires ON focus loss by definition, and `EditableText._finalizeEditing`
    // calls `focusNode.unfocus()` BEFORE `onSubmitted`, for every platform
    // and every unfocusing action. What the modal DID break is the other
    // half: Cancel runs no command, so nothing rebuilt and this method never
    // ran at all. That is fixed on the screen side, by
    // `_resyncInspectorHeight` forcing the rebuild — see there.
    //
    // (An override that re-synced regardless of focus was written for this
    // and then deleted: a mutation removing it could not be killed by any
    // reachable scenario, and an unfalsifiable branch is worse than the
    // paragraph above.)
    if (!_focus.hasFocus && widget.value != _text.text) {
      _text.text = widget.value;
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChanged);
    if (_ownsFocusNode) _focus.dispose();
    _text.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!_focus.hasFocus) _commit();
  }

  void _revert() {
    _text.text = widget.value;
  }

  void _commit() {
    final raw = _text.text;
    if (raw == widget.value) return; // genuine no-op — no command, no noise.
    final refusal = widget.validate?.call(raw);
    if (refusal != null) {
      widget.onRefuse?.call(refusal);
      _revert();
      return;
    }
    widget.onCommit(raw);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Focus(
        // `Esc` reverts the buffer WITHOUT running a command (see the file
        // header). Handled here rather than through the screen's
        // `Shortcuts` map so it never reaches the compaction-cancel
        // binding while a field is focused — an Esc aimed at a text box
        // should not also tear down an unrelated preview.
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.escape) {
            _revert();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: TextField(
          controller: _text,
          focusNode: _focus,
          keyboardType: widget.keyboardType,
          inputFormatters: widget.digitsOnly
              ? [FilteringTextInputFormatter.digitsOnly]
              : null,
          decoration: InputDecoration(
            labelText: widget.label,
            helperText: widget.helper,
            helperMaxLines: 2,
            isDense: true,
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (_) => _commit(),
        ),
      ),
    );
  }
}

/// The nullable usable-depth field (§4: "a nullable mm field with an
/// explicit unset/dash state — a 2-post frame leaves it unset").
///
/// EMPTY MEANS NULL, and null means UNKNOWN, never zero (CR-114) — hence
/// the `—` hint rather than a `0` placeholder, and the explicit clear
/// button, which is the only unambiguous way to say "I mean unset" as
/// opposed to "I have not typed yet".
class _NullableLengthField extends StatelessWidget {
  const _NullableLengthField({
    required this.label,
    required this.value,
    required this.onCommit,
    required this.onRefuse,
  });

  final String label;
  final Len? value;
  final ValueChanged<Len?> onCommit;
  final ValueChanged<String> onRefuse;

  @override
  Widget build(BuildContext context) {
    return _NullableNumberField(
      label: label,
      // Exact nanometres in, a plain millimetre number out. Trailing ".0"
      // trimmed so a 457.2 mm depth and a 300 mm depth read alike.
      //
      // The divisor is NAMED, not a bare `1e6`. This field converts in both
      // directions five lines apart, and the mass field below does the same
      // in a factor that differs by 1000; see `Mass.fromKilograms`, which
      // exists because those two literals were once confused for each other
      // and every seed template stored grams.
      text: value == null ? '' : _trim(value!.nm / Len.nmPerMillimetre),
      onCommit: (raw) {
        if (raw.trim().isEmpty) {
          onCommit(null);
          return;
        }
        final mm = double.tryParse(raw.trim());
        if (mm == null || mm < 0) {
          onRefuse('Usable depth must be a positive number of mm, or empty.');
          return;
        }
        onCommit(Len.fromMillimetres(mm));
      },
      onClear: () => onCommit(null),
      hasValue: value != null,
    );
  }
}

/// Weight capacity in kilograms, over the exact-microgram [Mass] type.
/// Nullable for the same CR-114 reason as usable depth: a rack whose
/// capacity nobody has looked up is UNKNOWN, not zero-rated.
class _NullableMassField extends StatelessWidget {
  const _NullableMassField({
    required this.label,
    required this.value,
    required this.onCommit,
    required this.onRefuse,
  });

  final String label;
  final Mass? value;
  final ValueChanged<Mass?> onCommit;
  final ValueChanged<String> onRefuse;

  @override
  Widget build(BuildContext context) {
    return _NullableNumberField(
      label: label,
      // Named divisor, for the reason given on the length field above.
      text: value == null ? '' : _trim(value!.ug / Mass.ugPerKilogram),
      onCommit: (raw) {
        if (raw.trim().isEmpty) {
          onCommit(null);
          return;
        }
        final kg = double.tryParse(raw.trim());
        if (kg == null || kg < 0) {
          onRefuse(
            'Weight capacity must be a positive number of kg, or '
            'empty.',
          );
          return;
        }
        onCommit(Mass.fromKilograms(kg));
      },
      onClear: () => onCommit(null),
      hasValue: value != null,
    );
  }
}

String _trim(double v) {
  final s = v.toStringAsFixed(2);
  if (!s.contains('.')) return s;
  return s.replaceFirst(RegExp(r'\.?0+$'), '');
}

/// The shared shell for the two nullable numeric fields above: a text field
/// whose empty string means null, hinted `—`, with a clear button that only
/// appears when there is something to clear.
class _NullableNumberField extends StatefulWidget {
  const _NullableNumberField({
    required this.label,
    required this.text,
    required this.onCommit,
    required this.onClear,
    required this.hasValue,
  });

  final String label;
  final String text;
  final ValueChanged<String> onCommit;
  final VoidCallback onClear;
  final bool hasValue;

  @override
  State<_NullableNumberField> createState() => _NullableNumberFieldState();
}

class _NullableNumberFieldState extends State<_NullableNumberField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.text,
  );
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _commit();
    });
  }

  @override
  void didUpdateWidget(_NullableNumberField old) {
    super.didUpdateWidget(old);
    if (!_focus.hasFocus && widget.text != _controller.text) {
      _controller.text = widget.text;
    }
  }

  @override
  void dispose() {
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _commit() {
    if (_controller.text == widget.text) return;
    widget.onCommit(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Focus(
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.escape) {
            _controller.text = widget.text;
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: TextField(
          controller: _controller,
          focusNode: _focus,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: widget.label,
            // NOT "0" — see the class doc and CR-114.
            hintText: '—',
            isDense: true,
            border: const OutlineInputBorder(),
            suffixIcon: widget.hasValue
                ? IconButton(
                    tooltip: 'Clear (unset)',
                    icon: const Icon(Icons.backspace_outlined, size: 16),
                    onPressed: () {
                      _controller.clear();
                      widget.onClear();
                    },
                  )
                : null,
          ),
          onSubmitted: (_) => _commit(),
        ),
      ),
    );
  }
}

/// One labelled dropdown in the 320px inspector column.
///
/// PUBLIC, unlike its siblings in this file, because the selection view in
/// `inspector_panel.dart` needs the same control for M3-A/7's lifecycle
/// picker and a second copy of it would be a second place for the column's
/// dropdown styling to drift.
class InspectorDropdown<T> extends StatelessWidget {
  const InspectorDropdown({
    required this.label,
    required this.value,
    required this.values,
    required this.labelOf,
    required this.onChanged,
    this.hintText,
    this.enabled = true,
    super.key,
  });

  final String label;

  /// NULLABLE, for the multi-select case: when the selected entities do
  /// not agree on a value there is no value to show, and [hintText] says
  /// so rather than the control naming one of them and inviting the user
  /// to believe the others match it.
  final T? value;

  final List<T> values;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;
  final String? hintText;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: DropdownButtonFormField<T>(
        initialValue: value,
        // The inspector column is 320px wide and several option labels
        // ("Floor enclosure 18U", "Square (cage nut)") are longer than the
        // control's intrinsic width allows. `isExpanded` + an ellipsis lets
        // the label truncate instead of overflowing the column.
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          hintText: hintText,
          isDense: true,
          border: const OutlineInputBorder(),
        ),
        items: [
          for (final v in values)
            DropdownMenuItem<T>(
              value: v,
              child: Text(labelOf(v), overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: enabled
            ? (v) {
                if (v != null && v != value) onChanged(v);
              }
            : null,
      ),
    );
  }
}

class _InspectorCheckbox extends StatelessWidget {
  const _InspectorCheckbox({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      value: value,
      title: Text(label, style: Theme.of(context).textTheme.bodySmall),
      onChanged: (v) {
        if (v != null && v != value) onChanged(v);
      },
    );
  }
}

/// §4's Location dropdown — real, enabled and command-backed over
/// `doc.locations`, with a leading "(none)" entry mapping to null.
///
/// The "+ New…" item §4 also names is deliberately absent: it would open the
/// project Locations panel (CR-112), which is out of scope for this stage.
class _LocationField extends StatelessWidget {
  const _LocationField({
    required this.rack,
    required this.doc,
    required this.onSetProperty,
  });

  final Rack rack;
  final RackDocument doc;
  final void Function<T>(EntityField<Rack, T> field, T value) onSetProperty;

  @override
  Widget build(BuildContext context) {
    // ORDER THEN ID, because `order` alone is not a total order.
    // `Location.order` is a plain mutable `FracIndex` that nothing
    // enforces the uniqueness of: racks and links get theirs from
    // `nextOrder`, locations are authored directly, so two can collide in
    // a decoded document. `List.sort` is not stable, so a bare `order`
    // comparison lets colliding entries swap places between rebuilds of an
    // unchanged document. Every other `order` sort in the tree ends in an
    // id or key; this one was the exception.
    final locations = doc.locations.values.toList()
      ..sort((a, b) {
        final byOrder = a.order.v.compareTo(b.order.v);
        return byOrder != 0 ? byOrder : a.id.v.compareTo(b.id.v);
      });
    return InspectorDropdown<Uuid?>(
      label: 'Location',
      // A locationId pointing at a location that no longer exists would
      // otherwise assert inside DropdownButton ("no item with that value").
      // Falling back to "(none)" shows the truth — the link is broken — and
      // lets the user repair it, which is strictly better than crashing.
      value: doc.locations.containsKey(rack.locationId)
          ? rack.locationId
          : null,
      values: [null, for (final l in locations) l.id],
      labelOf: (id) =>
          id == null ? '(none)' : doc.locations[id]?.name ?? '(missing)',
      onChanged: (v) => onSetProperty(RackField.locationId, v),
    );
  }
}

/// §4's "Mount (Floor/Wall radio)" over the eight-value `RackFormFactor`.
/// See [mountFormFactor] for the mapping and why it preserves the existing
/// subtype.
class _MountField extends StatelessWidget {
  const _MountField({required this.rack, required this.onSetProperty});

  final Rack rack;
  final void Function<T>(EntityField<Rack, T> field, T value) onSetProperty;

  @override
  Widget build(BuildContext context) {
    final wall = isWallMounted(rack.formFactor);
    return _RadioPair<bool>(
      label: 'Mount',
      value: wall,
      options: const [(false, 'Floor'), (true, 'Wall')],
      onChanged: (toWall) => onSetProperty(
        RackField.formFactor,
        mountFormFactor(rack.formFactor, wall: toWall),
      ),
    );
  }
}

/// §4's "RU numbering (Bottom-up / Top radio)". DISPLAY ONLY (CR-026) —
/// it never touches `RailPlacement.ruIndex`, which is bottom-origin
/// always (CR-025).
class _RuNumberingField extends StatelessWidget {
  const _RuNumberingField({required this.rack, required this.onSetProperty});

  final Rack rack;
  final void Function<T>(EntityField<Rack, T> field, T value) onSetProperty;

  @override
  Widget build(BuildContext context) {
    return _RadioPair<RuNumbering>(
      label: 'RU numbering',
      value: rack.ruNumbering,
      options: const [
        (RuNumbering.bottomUpFromOne, 'Bottom-up'),
        (RuNumbering.topDown, 'Top'),
      ],
      onChanged: (v) => onSetProperty(RackField.ruNumbering, v),
    );
  }
}

/// A two-option radio row — the shape §4 uses for both Mount and RU
/// numbering.
class _RadioPair<T> extends StatelessWidget {
  const _RadioPair({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<(T, String)> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          // `RadioGroup` rather than per-tile `groupValue`/`onChanged`,
          // which Flutter deprecated: the group owns the selection and the
          // callback, so each tile is a plain value.
          RadioGroup<T>(
            groupValue: value,
            onChanged: (v) {
              if (v != null && v != value) onChanged(v);
            },
            child: Row(
              children: [
                for (final (optionValue, optionLabel) in options)
                  Expanded(
                    child: RadioListTile<T>(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      value: optionValue,
                      title: Text(
                        optionLabel,
                        style: Theme.of(context).textTheme.bodySmall,
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
}

/// §4's Preset dropdown. Write-only in the honest sense — see the file
/// header on why "Custom" appears after any manual divergence.
class _PresetField extends StatelessWidget {
  const _PresetField({
    required this.rack,
    required this.presets,
    required this.onApplyPreset,
  });

  final Rack rack;
  final Map<String, RackPreset> presets;
  final ValueChanged<RackPreset> onApplyPreset;

  @override
  Widget build(BuildContext context) {
    final current = matchingPresetId(rack, presets);
    return InspectorDropdown<String?>(
      label: 'Preset',
      value: current,
      values: [null, ...presets.keys],
      labelOf: (id) => id == null ? 'Custom' : presets[id]?.displayName ?? id,
      onChanged: (id) {
        // Selecting "Custom" is not an edit — it is the display state that
        // means "this rack matches no preset". Applying it would have no
        // defined values to write.
        final preset = id == null ? null : presets[id];
        if (preset != null) onApplyPreset(preset);
      },
    );
  }
}

/// §4's Circuits section: a READ-ONLY list filtered by `rackId` (CR-028's
/// "Circuit is flat on the document with an optional rackId; the inspector
/// merely filters").
///
/// NO `[+ Add circuit]` BUTTON, and that is a decision rather than an
/// omission. No command anywhere in this codebase creates or edits a
/// `Circuit` — the model, the `doc.circuits` map and the codec all exist,
/// but nothing writes them. A rendered-but-inert button is exactly the
/// silently-does-nothing trap §3.4 forbids, so one caption line states the
/// situation instead.
///
/// Membership-by-walking-power-`Link`s (CR-028's other half) is untouched:
/// this filters, which is all CR-028 asks of an inspector.
class _CircuitsSection extends StatelessWidget {
  const _CircuitsSection({required this.rack, required this.doc});

  final Rack rack;
  final RackDocument doc;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final circuits =
        doc.circuits.values.where((c) => c.rackId == rack.id).toList()
          ..sort((a, b) => a.designator.compareTo(b.designator));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (circuits.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              'No circuits on ${rack.designator}.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          )
        else
          for (final c in circuits)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      c.designator,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  Text(
                    // CR-048: continuousLimitAmps is DERIVED, never stored.
                    '${c.breakerAmps} A  ·  cont. ${c.continuousLimitAmps} A',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            'Circuit creation arrives with the power stage.',
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }
}
