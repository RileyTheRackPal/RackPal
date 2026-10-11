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
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/src/builder/quick_add_fields.dart';
import 'package:rackpal_ui/src/keymap/keymap.dart';

/// Names the command line itself, as opposed to field mode's controls.
const kQuickAddCommandField = ValueKey<String>('quickAddCommand');

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
  QuickAddCompletion? _completion;

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
    final caret = _controller.selection.baseOffset;
    setState(() {
      _result = result;
      // ONLY AT THE END OF THE LINE, though `quickAddCompletion` will
      // happily offer at the end of any token. Right-arrow moves the
      // caret, so the offer and the key must agree: mid-command the
      // user is navigating and the ghost would be pointing at a place
      // the key will not take them.
      _completion = caret == text.length
          ? quickAddCompletion(widget.registries, text, caret)
          : null;
      _controller.ghost = _completion?.suffix;
      _controller.errorSpan = switch (result) {
        final QuickAddFailure f => (f.start, f.end),
        _ => null,
      };
    });
  }

  /// Accepts the ghost by appending it, which is safe because the offer
  /// only exists when the caret is at the end of the line.
  void _acceptCompletion() {
    final offer = _completion;
    if (offer == null) return;
    final text = _controller.text;
    _controller.value = TextEditingValue(
      text: '$text${offer.suffix}',
      selection: TextSelection.collapsed(
        offset: text.length + offer.suffix.length,
      ),
    );
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

  /// Writes a whole command line and returns focus to it.
  ///
  /// THE ONE PATH BY WHICH FIELD MODE CHANGES ANYTHING. The controls
  /// hold no state; they render an edited plan back to a command and
  /// hand it here, so the text field stays the single source of truth
  /// and the two modes have nothing to drift between.
  void _replaceCommand(String command) => _applyRepair(command);

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
                      // A REAL ACTION, NOT A CallbackAction, and the
                      // keymap row says why: a CallbackAction consumes
                      // the key regardless of what its body does, so an
                      // idle bar would stop a user walking the caret
                      // through their own command. `isActionEnabled`
                      // false hands right-arrow straight back.
                      QuickAddCompleteIntent: _AcceptCompletionAction(this),
                    },
                    child: TextField(
                      // KEYED so a test can name THE COMMAND LINE rather
                      // than "the first TextField". Field mode adds five
                      // more of them, and every test in this file broke
                      // at once the day it landed because a `byType`
                      // finder had been standing in for identity.
                      key: kQuickAddCommandField,
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
                      // RackMono, not the generic 'monospace' alias: the
                      // pattern's column positions are what the user is
                      // counting, so the face has to actually be fixed
                      // width rather than resolve to one by luck.
                      style: const TextStyle(fontFamily: 'RackMono'),
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
          // FIELD MODE, ALWAYS VISIBLE RATHER THAN BEHIND A TOGGLE. The
          // controls exist to TEACH the grammar (board #215), and a
          // discoverability mechanism nobody discovers is not one. They
          // grey rather than vanish when the command does not parse,
          // because a row that appears and disappears as you type is
          // harder to read than one that dims.
          QuickAddFields(
            plan: _result is QuickAddPlan ? _result! as QuickAddPlan : null,
            registries: widget.registries,
            onCommand: _replaceCommand,
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
  final parts = <String>[];

  // THE COUNT APPEARS ONLY WHEN IT IS NOT THE QUANTITY BESIDE IT. The
  // Qty control says 24; `both` creates 48, and that doubling is the one
  // arithmetic surprise in the grammar.
  if (plan.portCount != plan.quantity) {
    parts.add('${plan.portCount} ports');
  }

  final family = plan.family == null
      ? null
      : registries.signalFamilies[plan.family];
  // THE TRADE TOKEN, NOT `displayName`. The catalog name is authored for
  // a table cell: `IEC device power (C13/C14, C19/C20)` is accurate and
  // is not what anyone calls it. Same rule bank derivation uses.
  parts.add(family == null ? 'signal not set' : _familyWord(family));

  // The connector is the one type fact field mode does NOT show, so it
  // stays. Short label, which is what the port grid's CONN column
  // already prints.
  //
  // UNLESS IT IS THE SAME WORD. `16 hdmi in` printed `HDMI · HDMI`,
  // because the connector was named after the signal and both tables
  // hold `hdmi` as their first alias. Saying it twice tells nobody
  // anything and reads as a bug.
  if (plan.connector case final id?) {
    final short = portConnectorShortLabel(registries, id);
    if (parts.isEmpty || short.toUpperCase() != parts.last.toUpperCase()) {
      parts.add(short);
    }
  }

  // FACE ONLY WHEN `both`, because the Face control cannot show two.
  if (plan.bothFaces) parts.add('front and rear');

  // ONLY WHEN THE BANK IS NEW. The Bank control already prints the name;
  // what it cannot say is that nothing of that name exists yet, which is
  // how a typo'd `@Contol` quietly makes a second bank.
  final bank = uniqueBankName(registries, body, plan);
  if (!body.banks.any((b) => b.label == bank)) {
    parts.add('new bank "$bank"');
  }

  // The Label control shows the PATTERN; this shows what it expands to,
  // which is the only place a user sees `{n:2}` become `01`.
  final labels = plan.labels;
  if (labels.isNotEmpty && labels.first != labels.last) {
    parts.add('${labels.first} … ${labels.last}');
  }

  return parts.join(' · ');
}

/// The family's own trade token, upper-cased, falling back to
/// `shortTag` then `displayName`.
///
/// THE SAME CHAIN `deriveBankName` USES, and for the same reason. A
/// catalog `displayName` is authored for a table cell: `IEC device power
/// (C13/C14, C19/C20)` is correct, is what the grid's SIGNAL column
/// should print, and is not what anyone says. This line is read at a
/// glance before committing sixteen ports, so it gets the word an
/// installer would use.
String _familyWord(SignalFamilyDef family) {
  if (family.aliases.isNotEmpty) return family.aliases.first.toUpperCase();
  if (family.shortTag case final t? when t.isNotEmpty) return t;
  return family.displayName;
}

/// Accepts the inline completion, and DECLINES WHEN THERE IS NONE.
///
/// The declining is the whole reason this is a class. `Tab` is how a
/// keyboard-only user leaves a text field, and `Action.isActionEnabled`
/// returning false is what lets the key fall through to focus traversal
/// rather than being swallowed. `keymap_arbitration_test.dart` states the
/// requirement for every binding that shadows a framework default: "a
/// CallbackAction consumes the key regardless of what its body does".
class _AcceptCompletionAction extends Action<QuickAddCompleteIntent> {
  _AcceptCompletionAction(this._state);

  final _QuickAddBarState _state;

  @override
  bool get isActionEnabled => _state._completion != null;

  @override
  void invoke(QuickAddCompleteIntent intent) => _state._acceptCompletion();
}

/// A controller that draws a wavy underline under one character range.
///
/// The range is the parser's own span, so what is marked is exactly what
/// the message is about.
class _SpanController extends TextEditingController {
  (int, int)? errorSpan;

  /// The completion's remaining characters, painted after the caret in a
  /// muted colour and NOT part of [text].
  ///
  /// GHOST TEXT IS PAINTING, NEVER CONTENT. It is appended in
  /// [buildTextSpan] and never enters the value, so the parser, the
  /// summary line and Enter all see exactly what the user typed. A
  /// completion written into the field would be committed by an Enter
  /// pressed before it was accepted, which is a tool putting words in
  /// someone's mouth and then acting on them.
  String? ghost;

  @override
  set value(TextEditingValue newValue) {
    // Both are stale the instant the text changes; clearing here rather
    // than in the listener avoids one frame drawn with the old range,
    // or the old suggestion, against the new characters.
    if (newValue.text != text) {
      errorSpan = null;
      ghost = null;
    }
    super.value = newValue;
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    required bool withComposing,
    TextStyle? style,
  }) {
    final theme = Theme.of(context);
    final tail = ghost;
    // The ghost is only honest at the END of the line. Mid-command the
    // completion is inserted at the caret, and painting it after the
    // whole string would put the suggestion somewhere it will not go.
    final showGhost =
        tail != null && tail.isNotEmpty && selection.baseOffset == text.length;
    // The two conditions above are the SAME ones the accept action is
    // gated on, deliberately: a ghost the key would not take is a lie
    // drawn in grey.
    final ghostSpan = showGhost
        ? TextSpan(
            text: tail,
            style: TextStyle(color: theme.disabledColor),
          )
        : null;

    final span = errorSpan;
    if (span == null || span.$1 >= span.$2 || span.$2 > text.length) {
      return TextSpan(
        style: style,
        children: [
          TextSpan(text: text),
          ?ghostSpan,
        ],
      );
    }
    final error = theme.colorScheme.error;
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
        ?ghostSpan,
      ],
    );
  }
}
