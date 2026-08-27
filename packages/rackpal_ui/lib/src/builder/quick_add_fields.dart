// QUICK ADD'S FIELD MODE (M4-G3, docs/06 §4.1).
//
// ═════════════════════════════════════════════════════════════════════
// TWO MODES ON ONE CONTROL, BOUND BIDIRECTIONALLY
// ═════════════════════════════════════════════════════════════════════
// docs/06 §4.1: "Typing in command mode updates the fields live, which
// is how the DSL teaches itself." Board #215 is blunter: it is "the
// discoverability mechanism, not a convenience".
//
// The teaching runs BOTH ways and the second direction is the one that
// costs work. Command to fields is `parseQuickAdd`. Fields to command is
// `renderQuickAdd`, and it is what a user who reached for the dropdowns
// because they did not know the grammar sees happen: the command line
// assembles itself out of their clicks, in the words they will type next
// time. A field mode that did not write back would be a second way to do
// the same job rather than a way to learn the first.
//
// ═════════════════════════════════════════════════════════════════════
// THERE IS ONE SOURCE OF TRUTH AND IT IS THE COMMAND STRING
// ═════════════════════════════════════════════════════════════════════
// These controls hold NO state. Each reads from the plan the bar already
// parsed and writes by handing back a whole new command line, which the
// bar puts in the text field and reparses. So the two modes cannot drift:
// there is nothing for them to drift between.
//
// The alternative, keeping a parallel record of the parameters and
// syncing it, is how a form and its text representation come to disagree
// about what will happen, which on this surface would be sixteen ports
// created from something nobody could see.
//
// ═════════════════════════════════════════════════════════════════════
// THE SIGNAL PICKER IS THE ONE M4-E EXTRACTED
// ═════════════════════════════════════════════════════════════════════
// `widgets/family_picker.dart`, not a copy. It carries a MEASURED
// finding (a `DropdownButton`'s menu inherits its button's width, so 45
// character family labels arrive clamped to 84 points) and a RULING
// (DR-025 §11.24.3, the filter narrows and never commits). Two copies of
// a control encoding two decisions is two places for one to be lost.

import 'package:flutter/material.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/src/widgets/family_picker.dart';

/// Names one field-mode control, so a test can address it without
/// walking the widget tree. Navigating by ancestor found the BAR'S OWN
/// command line the first time it was tried, because the outermost
/// `Column` matching an ancestor query is the whole bar.
ValueKey<String> quickAddFieldKey(String label) =>
    ValueKey<String>('quickAddField.$label');

/// The discrete controls under the command line.
class QuickAddFields extends StatelessWidget {
  const QuickAddFields({
    required this.plan,
    required this.registries,
    required this.onCommand,
    super.key,
  });

  /// Null when the command line does not currently parse. The controls
  /// are shown DISABLED rather than hidden, because a row that appears
  /// and vanishes as you type is harder to read than one that greys.
  final QuickAddPlan? plan;

  final Registries registries;

  /// Hands back a whole new command line. The bar owns the text.
  final ValueChanged<String> onCommand;

  /// Rewrites one parameter by rendering an edited plan.
  void _edit(QuickAddPlan Function(QuickAddPlan) change) {
    final current = plan;
    if (current == null) return;
    onCommand(renderQuickAdd(registries, change(current)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = plan;
    final enabled = p != null;

    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Wrap(
        spacing: 10,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Icon(Icons.swap_vert, size: 15, color: theme.disabledColor),
          _Qty(
            value: p?.quantity,
            onChanged: !enabled
                ? null
                : (n) => _edit((c) => _copy(c, quantity: n)),
          ),
          _Field(
            label: 'Signal',
            child: SizedBox(
              width: 210,
              child: FamilyPicker(
                groups: signalFamilyCellGroups(registries),
                value: p?.family == null
                    ? null
                    : portFamilyText(registries, p!.family!),
                hint: 'not set',
                onPick: (label) {
                  final picked = resolveSignalFamilyCell(registries, label);
                  if (picked != null) {
                    _edit(
                      (c) => _copy(c, family: picked, clearConnector: true),
                    );
                  }
                },
              ),
            ),
          ),
          _Enum<PortDirection>(
            label: 'Dir',
            value: p?.direction,
            values: PortDirection.values,
            name: _directionWord,
            onChanged: !enabled
                ? null
                : (d) => _edit((c) => _copy(c, direction: d)),
          ),
          _Enum<Face>(
            label: 'Face',
            value: p?.bothFaces ?? false ? null : (p?.face ?? Face.rear),
            values: Face.values,
            name: (f) => f.name,
            onChanged: !enabled
                ? null
                : (f) => _edit((c) => _copy(c, face: f, bothFaces: false)),
          ),
          _Text(
            label: 'Label',
            // THE PATTERN AS AUTHORED, not the expansion. Showing
            // `HDMI IN 01` here would invite editing it into something
            // that is not a pattern at all.
            value: p?.labelPattern?.source ?? '',
            width: 170,
            hint: '{n:2}',
            onSubmitted: !enabled
                ? null
                : (text) => _edit((c) => _copy(c, label: text)),
          ),
          _Text(
            label: 'Bank',
            // The DERIVED name when none was typed, so the control shows
            // where the ports will actually land rather than a blank.
            value: p == null
                ? ''
                : uniqueBankName(
                    registries,
                    TemplateBody(
                      manufacturer: '',
                      model: '',
                      displayName: '',
                    ),
                    p,
                  ),
            width: 160,
            hint: 'auto',
            onSubmitted: !enabled
                ? null
                : (text) => _edit((c) => _copy(c, bank: text)),
          ),
        ],
      ),
    );
  }
}

/// Rebuilds a plan with one parameter changed.
///
/// A PLAIN FUNCTION RATHER THAN A `copyWith`, and deliberately private
/// to this file: `QuickAddPlan` is a PARSE RESULT, and a public
/// `copyWith` on it would invite code that constructs plans nobody
/// typed. Everything here immediately renders back to a command string,
/// so the edited plan lives for one statement.
QuickAddPlan _copy(
  QuickAddPlan c, {
  int? quantity,
  SignalFamilyId? family,
  bool clearConnector = false,
  PortDirection? direction,
  Face? face,
  bool? bothFaces,
  String? label,
  String? bank,
}) {
  final pattern = label == null
      ? c.labelPattern
      : (label.isEmpty ? null : parseLabelPattern(label));
  return QuickAddPlan(
    source: c.source,
    quantity: quantity ?? c.quantity,
    // PICKING A FAMILY CLEARS THE NAMED CONNECTOR, because the new
    // family's own default is almost certainly what is wanted and a
    // stale override would silently keep the old shell: choosing
    // HDBaseT after typing `xlr` must not leave an XLR3.
    connector: clearConnector ? null : c.connector,
    family: family ?? c.family,
    direction: direction ?? c.direction,
    face: face ?? c.face,
    bothFaces: bothFaces ?? c.bothFaces,
    passthrough: c.passthrough,
    labelPattern: pattern is LabelPattern ? pattern : c.labelPattern,
    bankName: bank == null ? c.bankName : (bank.isEmpty ? null : bank),
  );
}

String _directionWord(PortDirection d) => switch (d) {
  PortDirection.sink => 'in',
  PortDirection.source => 'out',
  PortDirection.bidirectional => 'bi',
  PortDirection.busNode => 'bus',
  PortDirection.passive => 'pass',
};

/// A labelled control. The label is above rather than beside, so the row
/// wraps without the label and its control being separated.
class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(label, style: Theme.of(context).textTheme.labelSmall),
      child,
    ],
  );
}

class _Qty extends StatelessWidget {
  const _Qty({required this.value, required this.onChanged});
  final int? value;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) => _Text(
    label: 'Qty',
    value: value?.toString() ?? '',
    width: 56,
    hint: '16',
    onSubmitted: onChanged == null
        ? null
        : (text) {
            final n = int.tryParse(text);
            // A QUANTITY THAT IS NOT A NUMBER IS IGNORED, not zeroed.
            // The command line still holds the real one, so the control
            // simply snaps back on the next rebuild.
            if (n != null && n >= 1) onChanged!(n);
          },
  );
}

class _Text extends StatefulWidget {
  const _Text({
    required this.label,
    required this.value,
    required this.width,
    required this.hint,
    required this.onSubmitted,
  });

  final String label;
  final String value;
  final double width;
  final String hint;
  final ValueChanged<String>? onSubmitted;

  @override
  State<_Text> createState() => _TextState();
}

class _TextState extends State<_Text> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value,
  );

  @override
  void didUpdateWidget(_Text old) {
    super.didUpdateWidget(old);
    // FOLLOWS THE COMMAND LINE WHENEVER IT DISAGREES, which is the
    // binding's whole point: type in the box above and this updates.
    // Guarded on inequality so it does not fight a caret mid-word.
    if (widget.value != _controller.text) _controller.text = widget.value;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _Field(
    label: widget.label,
    child: SizedBox(
      width: widget.width,
      child: TextField(
        key: quickAddFieldKey(widget.label),
        controller: _controller,
        enabled: widget.onSubmitted != null,
        decoration: InputDecoration(
          isDense: true,
          border: const OutlineInputBorder(),
          hintText: widget.hint,
        ),
        style: Theme.of(context).textTheme.bodySmall,
        onSubmitted: widget.onSubmitted,
        onTapOutside: (_) {
          if (_controller.text != widget.value) {
            widget.onSubmitted?.call(_controller.text);
          }
        },
      ),
    ),
  );
}

class _Enum<T> extends StatelessWidget {
  const _Enum({
    required this.label,
    required this.value,
    required this.values,
    required this.name,
    required this.onChanged,
  });

  final String label;
  final T? value;
  final List<T> values;
  final String Function(T) name;
  final ValueChanged<T>? onChanged;

  @override
  Widget build(BuildContext context) => _Field(
    label: label,
    child: DropdownButton<T>(
      value: value,
      // The hint carries the null case rather than a fabricated entry:
      // an unstated direction inherits the family's, and offering
      // "unset" as a choice would imply it could be written.
      hint: const Text('auto'),
      isDense: true,
      underline: const SizedBox.shrink(),
      style: Theme.of(context).textTheme.bodySmall,
      onChanged: onChanged == null
          ? null
          : (v) => v == null ? null : onChanged!(v),
      items: [
        for (final v in values)
          DropdownMenuItem<T>(value: v, child: Text(name(v))),
      ],
    ),
  );
}
