// The three dialogs the bank tree opens: New bank, Rename bank, and
// DR-085's Mirror bank. docs/06 §2 and §4.6, board `#181` / `#223`.
//
// ═══════════════════════════════════════════════════════════════════════
// NEW AND RENAME ARE ONE DIALOG, AND MIRROR IS NOT
// ═══════════════════════════════════════════════════════════════════════
// New and Rename ask a person for the same two strings, validate them
// against the same rule and differ only in what the fields start holding
// and what the button says. Two files would be two spellings of the
// duplicate-label refusal, on the one surface whose job is to be believed.
//
// Mirror is a different dialog because it is a different act: it asks for
// a name AND shows a per-row preview of what it is about to copy, which is
// DR-085 §11.84.3's clause. `port_impact_list.dart` already draws that
// preview for three other operations, so this is a fourth caller of one
// widget rather than a second impact list.
//
// ═══════════════════════════════════════════════════════════════════════
// THE ABBREVIATION IS A SECOND FIELD, NOT A DERIVATION
// ═══════════════════════════════════════════════════════════════════════
// `buildQuickAdd` derives `abbr` from the label's first word because it
// derived the LABEL too, from the signal family, and a person who typed
// `16 hdmi in` chose neither. A person opening this dialog is choosing
// both. The abbreviation is what the schematic symbol prints beside a
// collapsed bank (docs/06 §6), so it is silkscreen-adjacent text with a
// width budget the label does not have, and deriving it silently would be
// the product writing on the drawing.
//
// It PRE-FILLS from the label's first word and stops following the moment
// it is typed in, which is `port_grid.dart`'s key-follows-label rule
// reused rather than reinvented.
import 'package:flutter/material.dart';
import 'package:rackmate_core/rackmate_core.dart';
import 'package:rackmate_ui/src/builder/port_impact_list.dart';

/// What `[Create]` or `[Rename]` returns.
typedef BankNameChoice = ({String label, String abbr});

/// What `[Mirror]` returns: the name for the new bank.
typedef MirrorBankChoice = ({String label, String abbr});

/// `New bank…`, or `Rename bank…` when [bank] is given.
///
/// [bank] null is the create case: empty fields and a `[Create]` button.
Future<BankNameChoice?> showBankNameDialog({
  required BuildContext context,
  required TemplateBody body,
  BankDef? bank,
}) => showDialog<BankNameChoice>(
  context: context,
  builder: (context) => _BankNameDialog(body: body, bank: bank),
);

/// DR-085's `Mirror bank`, with the preview that names every row it
/// leaves alone.
Future<MirrorBankChoice?> showMirrorBankDialog({
  required BuildContext context,
  required TemplateBody body,
  required BankDef source,
}) => showDialog<MirrorBankChoice>(
  context: context,
  builder: (context) => _MirrorBankDialog(body: body, source: source),
);

/// The label and abbreviation fields, plus the one refusal both dialogs
/// enforce. Shared by all three so `A bank called HDMI already exists` is
/// spelled once.
class _NameFields extends StatelessWidget {
  const _NameFields({
    required this.labelController,
    required this.abbrController,
    required this.onLabelChanged,
    required this.onAbbrChanged,
    required this.refusal,
  });

  final TextEditingController labelController;
  final TextEditingController abbrController;

  /// Separate callbacks, because the abbreviation FOLLOWS the name until
  /// it is typed in, and a shared handler cannot tell which field moved.
  final ValueChanged<String> onLabelChanged;
  final ValueChanged<String> onAbbrChanged;
  final String? refusal;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: labelController,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Name',
            hintText: 'HDMI Outputs',
            errorText: refusal,
          ),
          onChanged: onLabelChanged,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: abbrController,
          decoration: const InputDecoration(
            labelText: 'Abbreviation',
            hintText: 'OUT',
            helperText: 'What the symbol prints when the bank collapses.',
          ),
          onChanged: onAbbrChanged,
        ),
      ],
    );
  }
}

/// The refusal, or null when [label] may be used.
String? _labelRefusal(TemplateBody body, String label, {String? exceptKey}) {
  if (label.trim().isEmpty) return null;
  if (!bankLabelIsTaken(body, label, exceptKey: exceptKey)) return null;
  return 'A bank called ${label.trim()} already exists.';
}

class _BankNameDialog extends StatefulWidget {
  const _BankNameDialog({required this.body, this.bank});

  final TemplateBody body;
  final BankDef? bank;

  @override
  State<_BankNameDialog> createState() => _BankNameDialogState();
}

class _BankNameDialogState extends State<_BankNameDialog> {
  late final _label = TextEditingController(text: widget.bank?.label ?? '');
  late final _abbr = TextEditingController(text: widget.bank?.abbr ?? '');

  /// Whether the abbreviation has stopped following the name.
  ///
  /// A RENAME STARTS DETACHED. Its abbreviation is a value the author
  /// already chose, and retyping the name must not silently overwrite it;
  /// a create starts attached because there is nothing to overwrite.
  late bool _abbrTouched = widget.bank != null;

  @override
  void dispose() {
    _label.dispose();
    _abbr.dispose();
    super.dispose();
  }

  /// The head of the name upper-cased, which is `buildQuickAdd`'s own
  /// derivation.
  String _derivedAbbr(String label) =>
      label.trim().split(RegExp(r'\s+')).first.toUpperCase();

  /// **THE FOLLOW HAPPENS HERE AND NOT IN `build`.** Assigning to a
  /// `TextEditingController` notifies its listeners, and the `TextField`
  /// listening is in the middle of being built: Flutter asserts on
  /// `markNeedsBuild` during build. Doing it in the change handler is also
  /// the only place that knows which field the person typed in.
  void _labelChanged(String value) => setState(() {
    if (!_abbrTouched) _abbr.text = _derivedAbbr(value);
  });

  @override
  Widget build(BuildContext context) {
    final isRename = widget.bank != null;
    final refusal = _labelRefusal(
      widget.body,
      _label.text,
      exceptKey: widget.bank?.key,
    );
    final ready = _label.text.trim().isNotEmpty && refusal == null;
    return AlertDialog(
      title: Text(isRename ? 'Rename ${widget.bank!.label}' : 'New bank'),
      content: SizedBox(
        width: 380,
        child: _NameFields(
          labelController: _label,
          abbrController: _abbr,
          refusal: refusal,
          onLabelChanged: _labelChanged,
          onAbbrChanged: (_) => setState(() => _abbrTouched = true),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: ready
              ? () => Navigator.of(context).pop((
                  label: _label.text.trim(),
                  abbr: _abbr.text.trim(),
                ))
              : null,
          child: Text(isRename ? 'Rename' : 'Create'),
        ),
      ],
    );
  }
}

class _MirrorBankDialog extends StatefulWidget {
  const _MirrorBankDialog({required this.body, required this.source});

  final TemplateBody body;
  final BankDef source;

  @override
  State<_MirrorBankDialog> createState() => _MirrorBankDialogState();
}

class _MirrorBankDialogState extends State<_MirrorBankDialog> {
  /// DR-085 §11.84.4: `IN`↔`OUT` where those words occur, and EMPTY
  /// otherwise, because *"otherwise the person names the bank"*. An
  /// invented default here is precisely what the ruling declines: these
  /// labels reach the panel drawing and the schedule, and no device has
  /// `(mirrored)` printed on its silkscreen.
  late final _label = TextEditingController(
    text: swapInOut(widget.source.label) ?? '',
  );
  late final _abbr = TextEditingController(
    text: swapInOut(widget.source.abbr) ?? '',
  );

  @override
  void dispose() {
    _label.dispose();
    _abbr.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final refusal = _labelRefusal(widget.body, _label.text);
    final ready = _label.text.trim().isNotEmpty && refusal == null;

    // PLANNED AGAINST THE NAME AS TYPED, because the new port keys derive
    // from the new bank key (DR-085 §11.84.5) and the person is entitled
    // to see the keys they are about to get. The direction column does not
    // depend on the name, so an empty field still previews correctly: it
    // is planned under the source's own label purely to have something to
    // derive keys from.
    final plan = planMirrorBank(
      widget.body,
      sourceBankKey: widget.source.key,
      label: _label.text.trim().isEmpty
          ? widget.source.label
          : _label.text.trim(),
      abbr: _abbr.text.trim(),
    );
    final rows = mirrorBankImpact(
      widget.body,
      plan,
      sourceBankKey: widget.source.key,
    );

    return AlertDialog(
      title: Text('Mirror ${widget.source.label}'),
      content: SizedBox(
        width: 480,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // THE SENTENCE THE RULING ASKED FOR, and it is only shown when
            // it is true. A bank called `HDMI` has nothing to swap, and
            // saying so is what turns an empty required field from a bug
            // into an instruction.
            if (swapInOut(widget.source.label) == null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  "There is no IN or OUT in this bank's name to swap, so "
                  'give the copy a name.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            _NameFields(
              labelController: _label,
              abbrController: _abbr,
              refusal: refusal,
              onLabelChanged: (_) => setState(() {}),
              onAbbrChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            Text(
              portImpactSummary(rows),
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(height: 4),
            PortImpactList(rows: rows, maxHeight: 200),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: ready
              ? () => Navigator.of(context).pop((
                  label: _label.text.trim(),
                  abbr: _abbr.text.trim(),
                ))
              : null,
          child: const Text('Mirror'),
        ),
      ],
    );
  }
}
