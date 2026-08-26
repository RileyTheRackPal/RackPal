// THE ARCHETYPE GENERATOR DIALOGS (M4-I, docs/06 §4.3, DR-092 §11.91).
//
// ═══════════════════════════════════════════════════════════════════════
// MODAL, WHERE QUICK ADD IS NOT, AND THE DIFFERENCE IS THE GESTURE
// ═══════════════════════════════════════════════════════════════════════
// `quick_add_bar.dart` is docked and never modal because §9.3 rests on it:
// focus never leaves the bar across eight consecutive commands, so a modal
// there would be eight dismissals. A generator is the opposite shape. It
// fires ONCE, docs/06 §9.2 step 2 calls it a dialog in its own step table,
// and the thing it has to show before committing is a form too wide for a
// docked strip.
//
// ═══════════════════════════════════════════════════════════════════════
// THE PREVIEW LINE IS THE SAME ARGUMENT THE QUICK ADD SUMMARY MAKES
// ═══════════════════════════════════════════════════════════════════════
// A typo in Quick Add costs sixteen ports and an undo. A mis-set quantity
// here costs sixty-eight. So the count is on screen BEFORE `[Generate]`,
// computed by `previewArchetype` from the same groups the build consumes
// rather than by a second sum this file keeps (M4-I1, `#220`).
//
// **AND THE CONTROL CHECKBOX SAYS WHAT IT WILL ACTUALLY EMIT.** Its label
// gains `+ IR IN` the moment per-output IR is ticked, because DR-092
// §11.91.2 makes that port conditional on a box somewhere else on the
// form. A label that stayed "LAN + RS-232" would be the product doing
// something correct and unannounced, which is how a person learns not to
// trust the form.
//
// ═══════════════════════════════════════════════════════════════════════
// `[Generate]` IS REFUSED WHILE A SIDE NAMES NO TYPE
// ═══════════════════════════════════════════════════════════════════════
// `parseQuickAdd`'s own rule, verbatim: "a command with neither a
// connector nor a family has not said what to add and is far more likely
// a typo than an intention". Everything else here may be unknown, because
// unknown is a state a port can hold and the grid marks it.
import 'package:flutter/material.dart';
import 'package:rackmate_core/rackmate_core.dart';
import 'package:rackmate_ui/src/builder/port_cells.dart';

/// The dialog's title, and what a test finds it by.
const String kMatrixDialogTitle = 'Matrix I/O';

/// The commit button. §9.2's step 6 is `[ Generate ]`.
const String kArchetypeGenerateLabel = 'Generate';

/// Names the two count fields, so a test finds the one it means rather
/// than `byType(TextField).first`.
const ValueKey<String> kMatrixInputsField = ValueKey<String>('matrix.inputs');
const ValueKey<String> kMatrixOutputsField = ValueKey<String>('matrix.outputs');

/// The signal picker of one row, by slot: `inputs`, `outputs`, `mirrored`,
/// `audio`.
///
/// **FOUR ROWS CARRY THE SAME TWO CONTROLS**, so `byType(FamilyPicker)`
/// answers with whichever laid out first and a test written against it
/// passes while driving the wrong side of the matrix.
ValueKey<String> matrixSignalKey(String slot) =>
    ValueKey<String>('$slot.signal');

/// The connector picker of one row. See [matrixSignalKey].
ValueKey<String> matrixConnectorKey(String slot) =>
    ValueKey<String>('$slot.connector');

/// Said under the form while a side still names no type.
const String kArchetypeNeedsATypeNote =
    'Name a signal for both sides. A side with neither a signal nor a '
    'connector has not said what to add.';

/// Shows `Matrix I/O…` and returns the groups to build, or null on cancel.
///
/// **GROUPS AND NOT A SPEC.** The caller runs `buildArchetype` and knows
/// nothing about matrices, which is what lets `Switch ports…` and any
/// later generator reuse the one call site in the port grid.
Future<List<ArchetypeGroup>?> showMatrixArchetypeDialog({
  required BuildContext context,
  required TemplateBody body,
  required Registries registries,
}) => showDialog<List<ArchetypeGroup>>(
  context: context,
  builder: (context) => _MatrixDialog(body: body, registries: registries),
);

class _MatrixDialog extends StatefulWidget {
  const _MatrixDialog({required this.body, required this.registries});

  final TemplateBody body;
  final Registries registries;

  @override
  State<_MatrixDialog> createState() => _MatrixDialogState();
}

class _MatrixDialogState extends State<_MatrixDialog> {
  /// SIXTEEN, because the exit criterion's device is a 16×16 and a matrix
  /// is the one device class whose commonest size is worth pre-filling.
  /// The field selects on focus, so replacing it is a type rather than a
  /// clear-then-type.
  int _inputs = 16;
  int _outputs = 16;

  PortType _inputType = const PortType();
  PortType _outputType = const PortType();

  bool _mirrored = false;
  PortType? _mirroredType;

  bool _audio = false;
  PortType _audioType = kMatrixDefaultAudioType;

  bool _perOutputIr = false;
  bool _control = false;
  bool _acInlet = false;

  MatrixArchetype get _spec => MatrixArchetype(
    inputs: _inputs,
    inputType: _inputType,
    outputs: _outputs,
    outputType: _outputType,
    mirroredOutputs: _mirrored,
    mirroredType: _mirroredType,
    audioDeEmbed: _audio,
    audioType: _audioType,
    perOutputIr: _perOutputIr,
    control: _control,
    acInlet: _acInlet,
  );

  /// Both sides named, and both counts at least one.
  bool get _canGenerate =>
      _inputs >= 1 &&
      _outputs >= 1 &&
      _named(_inputType) &&
      _named(_outputType);

  static bool _named(PortType t) => t.family != null || t.connector != null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final groups = planMatrixArchetype(widget.registries, _spec);
    final preview = previewArchetype(widget.registries, widget.body, groups);

    return AlertDialog(
      title: const Text(kMatrixDialogTitle),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _TypeRow(
                label: 'Inputs',
                slot: 'inputs',
                fieldKey: kMatrixInputsField,
                count: _inputs,
                onCount: (n) => setState(() => _inputs = n),
                type: _inputType,
                registries: widget.registries,
                onType: (t) => setState(() => _inputType = t),
              ),
              const SizedBox(height: 8),
              _TypeRow(
                label: 'Outputs',
                slot: 'outputs',
                fieldKey: kMatrixOutputsField,
                count: _outputs,
                onCount: (n) => setState(() => _outputs = n),
                type: _outputType,
                registries: widget.registries,
                onType: (t) => setState(() => _outputType = t),
              ),
              const Divider(height: 24),

              // THE COMPANIONS, ALL OFF (DR-092 §11.91.6). §9.2's step 5
              // ticks four of them, which is what says they start clear.
              _Companion(
                label: 'Mirrored outputs',
                value: _mirrored,
                onChanged: (on) => setState(() => _mirrored = on),
                // NULL MEANS "THE INPUT TYPE", which is what a mirrored
                // output is: the local copy of the signal that came in.
                trailing: _mirrored
                    ? _TypePickers(
                        slot: 'mirrored',
                        registries: widget.registries,
                        type: _mirroredType ?? _inputType,
                        onType: (t) => setState(() => _mirroredType = t),
                      )
                    : null,
              ),
              _Companion(
                label: 'Per-output audio de-embed',
                value: _audio,
                onChanged: (on) => setState(() => _audio = on),
                trailing: _audio
                    ? _TypePickers(
                        slot: 'audio',
                        registries: widget.registries,
                        type: _audioType,
                        onType: (t) => setState(() => _audioType = t),
                      )
                    : null,
              ),
              _Companion(
                label: 'Per-output IR',
                value: _perOutputIr,
                onChanged: (on) => setState(() => _perOutputIr = on),
              ),
              _Companion(
                label: _perOutputIr
                    ? 'Control (LAN + RS-232 + IR IN)'
                    : 'Control (LAN + RS-232)',
                value: _control,
                onChanged: (on) => setState(() => _control = on),
              ),
              _Companion(
                label: 'AC inlet (C14)',
                value: _acInlet,
                onChanged: (on) => setState(() => _acInlet = on),
              ),
              const SizedBox(height: 12),
              Text(
                _canGenerate
                    ? archetypePreviewLine(preview)
                    : kArchetypeNeedsATypeNote,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: _canGenerate
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _canGenerate
              ? () => Navigator.of(context).pop(groups)
              : null,
          child: const Text(kArchetypeGenerateLabel),
        ),
      ],
    );
  }
}

/// `68 ports across 6 banks`, singularised.
///
/// **WHOLE STRINGS, BECAUSE `1 ports` SHIPPED ONCE ALREADY.** M4-G's
/// summary line printed it on four of eight steps under a dozen green
/// `contains` assertions, which cannot see grammar. A generator with one
/// input and one output reaches every singular here.
String archetypePreviewLine(ArchetypePreview preview) {
  final ports = preview.ports == 1 ? '1 port' : '${preview.ports} ports';
  if (preview.banks == 0) return ports;
  final banks = preview.banks == 1 ? '1 bank' : '${preview.banks} banks';
  return '$ports across $banks';
}

/// One side of the matrix: a count and the two pickers that type it.
class _TypeRow extends StatelessWidget {
  const _TypeRow({
    required this.label,
    required this.slot,
    required this.fieldKey,
    required this.count,
    required this.onCount,
    required this.type,
    required this.registries,
    required this.onType,
  });

  final String label;
  final String slot;
  final Key fieldKey;
  final int count;
  final ValueChanged<int> onCount;
  final PortType type;
  final Registries registries;
  final ValueChanged<PortType> onType;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox(width: 84, child: Text(label)),
      SizedBox(
        width: 64,
        child: _Count(key: fieldKey, value: count, onChanged: onCount),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: _TypePickers(
          slot: slot,
          registries: registries,
          type: type,
          onType: onType,
        ),
      ),
    ],
  );
}

/// The signal picker and the connector picker, in that order.
///
/// **THE GRID'S OWN TWO CELLS, NOT A THIRD PAIR.** `PortFamilyCell` carries
/// `family_picker.dart`'s measurement and DR-025 §11.24.3's narrowing
/// filter; `PortConnectorCell` carries M3-L's finding that a
/// `DropdownButton` asserting on its value takes a whole table down when a
/// document names something no menu offers. Two copies of those would be
/// two places to lose one.
class _TypePickers extends StatelessWidget {
  const _TypePickers({
    required this.slot,
    required this.registries,
    required this.type,
    required this.onType,
  });

  final String slot;
  final Registries registries;
  final PortType type;
  final ValueChanged<PortType> onType;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: PortFamilyCell(
          key: matrixSignalKey(slot),
          registries: registries,
          value: type.family ?? const SignalFamilyId(''),
          // PICKING A FAMILY TAKES ITS DEFAULT CONNECTOR, which is
          // `quick_add_fields.dart`'s rule: the new family's own default
          // is almost certainly what is wanted, and keeping the old
          // connector is how `hdbt` ends up on an HDMI-A.
          onPick: (id) => onType(
            PortType(
              family: id.v.isEmpty ? null : id,
              connector: registries.signalFamilies[id]?.defaultConnector,
            ),
          ),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: PortConnectorCell(
          key: matrixConnectorKey(slot),
          registries: registries,
          value: type.connector ?? const ConnectorTypeId(''),
          onPick: (id) => onType(type.withConnector(id.v.isEmpty ? null : id)),
        ),
      ),
    ],
  );
}

/// A checkbox with an optional pair of pickers beside it.
class _Companion extends StatelessWidget {
  const _Companion({
    required this.label,
    required this.value,
    required this.onChanged,
    this.trailing,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox(
        width: 260,
        child: CheckboxListTile(
          value: value,
          onChanged: (on) => onChanged(on ?? false),
          title: Text(label),
          dense: true,
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
        ),
      ),
      if (trailing case final Widget t) Expanded(child: t),
    ],
  );
}

/// A whole-number field that will not answer with a negative.
class _Count extends StatefulWidget {
  const _Count({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final int value;
  final ValueChanged<int> onChanged;

  @override
  State<_Count> createState() => _CountState();
}

class _CountState extends State<_Count> {
  late final TextEditingController _controller = TextEditingController(
    text: '${widget.value}',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _controller,
    // SELECTS ON FOCUS so 16 is replaced by typing rather than by
    // clearing first. A pre-filled field a person has to empty is worse
    // than an empty one.
    onTap: () => _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _controller.text.length,
    ),
    keyboardType: TextInputType.number,
    // NO `labelText`: the row already carries the word, and a field that
    // repeats its own label inside itself costs the digits their room.
    decoration: const InputDecoration(
      isDense: true,
      border: OutlineInputBorder(),
    ),
    // ZERO AND EMPTY ARE THE SAME ANSWER HERE and both refuse the button
    // rather than generating nothing. `int.tryParse` returning null on a
    // half-typed value must not throw away the digit already typed.
    onChanged: (text) => widget.onChanged(int.tryParse(text.trim()) ?? 0),
  );
}
