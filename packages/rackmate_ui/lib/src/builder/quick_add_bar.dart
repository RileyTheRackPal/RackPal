// QUICK ADD'S DOCKED BAR (M4-G1, docs/06 §4.1).
//
// ═════════════════════════════════════════════════════════════════════
// DOCKED, NEVER MODAL, AND FOCUS RETURNS HERE AFTER EVERY ADD
// ═════════════════════════════════════════════════════════════════════
// That invariant IS the feature, not a nicety around it. docs/06 §9.3
// states it as one of the two things that make the thirteen-step count
// real rather than a demo: "focus never leaves Quick Add during steps
// 6 to 13, no reach for the mouse, no modal dismissal". A modal that
// dismissed after each add would turn eight commands into eight
// re-openings, and the exit criterion is a stopwatch.
//
// So: the field keeps focus across a commit, the text clears rather
// than the widget rebuilding, and NOTHING here returns a `Future` that
// a caller could await before restoring focus.
//
// ═════════════════════════════════════════════════════════════════════
// THE SPAN IS UNDERLINED IN THE INPUT ITSELF (AC-050 / A2.4)
// ═════════════════════════════════════════════════════════════════════
// `_SpanController` overrides `buildTextSpan` so the offending
// characters carry a wavy underline where the user typed them. A
// message under a box that highlights nothing is the failure mode
// board #218 calls a failed requirement, and putting the mark anywhere
// but on the text is how it happens.
//
// ═════════════════════════════════════════════════════════════════════
// THE SUMMARY LINE IS THE PREVIEW, AND IT STATES WHAT IS INFERRED
// ═════════════════════════════════════════════════════════════════════
// A typo costs sixteen ports and an undo, so the line under the bar
// says what Enter will do BEFORE it is pressed. It deliberately spells
// the two things the DSL infers silently and would therefore get wrong
// silently: the resolved FAMILY, and the bank name derived when no
// `@bank` was typed. A count alone would have said "16 ports" for a
// command about to put HDBaseT where Ethernet was meant.

import 'package:flutter/material.dart';
import 'package:rackmate_core/rackmate_core.dart';
import 'package:rackmate_ui/src/keymap/keymap.dart';

/// The docked Quick Add bar.
class QuickAddBar extends StatefulWidget {
  const QuickAddBar({
    required this.body,
    required this.registries,
    required this.onRun,
    this.autofocus = true,
    super.key,
  });

  final TemplateBody body;
  final Registries registries;

  /// Runs the built commands as ONE undo entry. The bar does not know
  /// about `TemplateEditSession`; it hands back a list and the grid's
  /// existing `transact` groups it, which is the same shape the delete
  /// path already uses.
  final void Function(List<Command<TemplateBody>> commands) onRun;

  /// FOCUS LANDS HERE ON ENTERING THE SECTION (docs/06 §4.1). Off only
  /// in tests that are checking something else and would otherwise
  /// steal focus from the control under examination.
  final bool autofocus;

  @override
  State<QuickAddBar> createState() => _QuickAddBarState();
}

class _QuickAddBarState extends State<QuickAddBar> {
  late final _SpanController _controller = _SpanController();
  final FocusNode _focus = FocusNode(debugLabel: 'QuickAdd');

  QuickAddResult? _result;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_reparse);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Parses on EVERY keystroke, which is why the parser treats an
  /// unterminated quote as a label rather than an error: refusing
  /// mid-word would paint red under the user's hands as they type
  /// `"HDMI IN`.
  void _reparse() {
    final text = _controller.text;
    final result = text.trim().isEmpty
        ? null
        : parseQuickAdd(widget.registries, text);
    setState(() {
      _result = result;
      _controller.errorSpan = switch (result) {
        final QuickAddFailure f => (f.start, f.end),
        _ => null,
      };
    });
  }

  void _commit() {
    if (_result case final QuickAddPlan plan) {
      widget.onRun(buildQuickAdd(widget.registries, widget.body, plan));
      // CLEAR THE TEXT, KEEP THE FOCUS. `clear()` fires the listener,
      // which resets the summary; requesting focus again is belt and
      // braces for the case where the commit rebuilt an ancestor.
      _controller.clear();
      _focus.requestFocus();
    }
  }

  /// Replaces the whole command with a repair chip's suggestion and puts
  /// the caret at the end, so the next keystroke continues rather than
  /// overwriting a selection.
  void _applyRepair(String repair) {
    _controller.value = TextEditingValue(
      text: repair,
      selection: TextSelection.collapsed(offset: repair.length),
    );
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Shortcuts(
                  // ENTER COMES FROM THE KEYMAP REGISTRY, NEVER FROM A
                  // `SingleActivator` HERE. D7 bans the constructor
                  // outside `src/keymap/` and a gate reads this package's
                  // source for it; the first draft of this bar built one
                  // inline and `keymap_source_ban_test.dart` caught it.
                  // The registry is also what makes the binding
                  // discoverable to a menu and arbitrated against every
                  // other Enter in the product.
                  shortcuts: keymapShortcuts(
                    KeyScope.builder,
                    platform: theme.platform,
                  ),
                  child: Actions(
                    actions: <Type, Action<Intent>>{
                      QuickAddCommitIntent:
                          CallbackAction<QuickAddCommitIntent>(
                            onInvoke: (_) {
                              _commit();
                              return null;
                            },
                          ),
                    },
                    child: TextField(
                      controller: _controller,
                      focusNode: _focus,
                      autofocus: widget.autofocus,
                      decoration: const InputDecoration(
                        isDense: true,
                        border: OutlineInputBorder(),
                        prefixText: '> ',
                        // A PLACEHOLDER, NEVER A HELPER LINE. M4-D found
                        // an example under a filled box reading as a
                        // second value; `hintText` shows only while the
                        // box is empty.
                        hintText: '16 hdmi in "HDMI IN {n:2}"',
                        labelText: 'Quick Add',
                      ),
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: FilledButton(
                  onPressed: _result is QuickAddPlan ? _commit : null,
                  child: const Text('Add'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _Summary(
            result: _result,
            registries: widget.registries,
            body: widget.body,
            onRepair: _applyRepair,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// The one line under the bar: what Enter will do, or what is wrong.
class _Summary extends StatelessWidget {
  const _Summary({
    required this.result,
    required this.registries,
    required this.body,
    required this.onRepair,
    required this.style,
  });

  final QuickAddResult? result;
  final Registries registries;
  final TemplateBody body;
  final ValueChanged<String> onRepair;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    switch (result) {
      case null:
        return Text(
          'Type a quantity and a port type. Enter adds; focus stays here.',
          style: style?.copyWith(color: theme.disabledColor),
        );
      case final QuickAddFailure f:
        return Row(
          children: [
            Icon(Icons.error_outline, size: 14, color: theme.colorScheme.error),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                f.message,
                style: style?.copyWith(color: theme.colorScheme.error),
              ),
            ),
            const SizedBox(width: 8),
            // THE CHIP IS THE WHOLE REPAIRED COMMAND, so accepting it is
            // one click and never a merge.
            ActionChip(
              label: Text(f.repair),
              visualDensity: VisualDensity.compact,
              onPressed: () => onRepair(f.repair),
            ),
          ],
        );
      case final QuickAddPlan plan:
        return Text(
          describeQuickAddPlan(registries, body, plan),
          style: style,
        );
    }
  }
}

/// The summary sentence, in core-free UI vocabulary.
///
/// PUBLIC AND PURE so a test can assert the STRING a user reads without
/// pumping a widget, which is the half of this feature a widget test is
/// worst at seeing.
///
/// It names the resolved family and the bank because those are the two
/// facts the DSL infers without being told, and therefore the two it
/// can get wrong without the user noticing until sixteen rows exist.
String describeQuickAddPlan(
  Registries registries,
  TemplateBody body,
  QuickAddPlan plan,
) {
  final parts = <String>['${plan.portCount} ports'];

  final family = plan.family == null
      ? null
      : registries.signalFamilies[plan.family];
  parts.add(family?.displayName ?? 'signal not set');

  final connector = plan.connector == null
      ? null
      : registries.connectorTypes[plan.connector];
  if (connector != null) parts.add(connector.displayName);

  final direction = plan.direction ?? family?.defaultDirection;
  if (direction != null) parts.add(_directionWord(direction));

  parts.add(plan.bothFaces ? 'front and rear' : (plan.face ?? Face.rear).name);

  // "(new)" IS THE POINT OF THIS CLAUSE. A user typing `@Contol` wants
  // to see that they are about to create a bank rather than add to one.
  final bank = uniqueBankName(registries, body, plan);
  final exists = body.banks.any((b) => b.label == bank);
  parts.add('bank "$bank"${exists ? '' : ' (new)'}');

  final labels = plan.labels;
  if (labels.isNotEmpty) {
    parts.add(
      labels.length == 1 || labels.first == labels.last
          ? 'labelled ${labels.first}'
          : '${labels.first} … ${labels.last}',
    );
  }

  return parts.join(' · ');
}

/// Trade words rather than enum names. M4-D found twenty-six strings
/// citing the corpus at the user and dropdowns showing raw Dart
/// identifiers; `sink` on a summary line would be the same defect.
String _directionWord(PortDirection d) => switch (d) {
  PortDirection.sink => 'input',
  PortDirection.source => 'output',
  PortDirection.bidirectional => 'bidirectional',
  PortDirection.busNode => 'bus',
  PortDirection.passive => 'passthrough',
};

/// A controller that draws a wavy underline under one character range.
///
/// The range is the parser's own span, so what is marked is exactly what
/// the message is about.
class _SpanController extends TextEditingController {
  (int, int)? errorSpan;

  @override
  set value(TextEditingValue newValue) {
    // The span is stale the instant the text changes; clearing it here
    // rather than in the listener avoids one frame drawn with the old
    // range against the new characters.
    if (newValue.text != text) errorSpan = null;
    super.value = newValue;
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    required bool withComposing,
    TextStyle? style,
  }) {
    final span = errorSpan;
    if (span == null || span.$1 >= span.$2 || span.$2 > text.length) {
      return TextSpan(text: text, style: style);
    }
    final error = Theme.of(context).colorScheme.error;
    return TextSpan(
      style: style,
      children: [
        TextSpan(text: text.substring(0, span.$1)),
        TextSpan(
          text: text.substring(span.$1, span.$2),
          style: TextStyle(
            decoration: TextDecoration.underline,
            decorationStyle: TextDecorationStyle.wavy,
            decorationColor: error,
          ),
        ),
        TextSpan(text: text.substring(span.$2)),
      ],
    );
  }
}
