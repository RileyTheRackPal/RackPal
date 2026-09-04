// Acknowledging from the issues list (`#295`, M5-F2, CR-019, RJ-006).
//
// ═══════════════════════════════════════════════════════════════════════
// THE RULES ARE NOT RESTATED HERE
// ═══════════════════════════════════════════════════════════════════════
// Whether an exception may stand is `evaluateAcknowledgement`, and this
// dialog asks it on every keystroke rather than implementing "a project
// mute needs a reason" a second time. `acknowledgement_commands.dart`
// already wrote the contract this half honours: the refusal message is
// *"shown beside a disabled button, so it has to be the whole
// explanation"*. So the message is rendered verbatim and never
// paraphrased, and `[ Acknowledge ]` is disabled exactly when the verdict
// is a refusal.
//
// ═══════════════════════════════════════════════════════════════════════
// THE DEFAULT KEEPS THE FINDING VISIBLE
// ═══════════════════════════════════════════════════════════════════════
// `demotedTo` defaults to the severity the finding already has, NOT to
// `off`. CR-019 makes acknowledgement a demotion rather than a deletion,
// and the case the model exists for is the inspector's *"noted,
// justified, and still an error"*. Defaulting to `off` would make the
// one-click path the one that hides evidence, and a person clicking
// through a list of twelve would silently empty it.
//
// Hiding is still offered, because a professional is allowed to say a
// rule does not apply to their job. It is just not the default.
//
// ═══════════════════════════════════════════════════════════════════════
// SCOPE IS A CHOICE, NOT TWO BUTTONS
// ═══════════════════════════════════════════════════════════════════════
// CR-019 is one mechanism at two scopes, so this is one dialog with a
// scope control. Two entry points would be two dialogs to keep in step,
// and the reason field's requirement changes with the scope rather than
// with which button was pressed.
import 'package:flutter/material.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/src/keymap/keymap.dart';
import 'package:rackpal_ui/src/theme/console_theme.dart';
import 'package:rackpal_ui/src/validation/drc_panel.dart';
import 'package:rackpal_ui/src/validation/why_rule_dialog.dart';

/// What `[ Acknowledge ]` returns, or null when the dialog was cancelled.
typedef AcknowledgeChoice = ({
  bool projectWide,
  String reason,
  Severity demotedTo,
});

/// The confirm button.
const String kAckConfirm = 'Acknowledge';

/// The scope control's two answers. The project-wide one names the rule,
/// because "every one of these" is not something to agree to vaguely.
const String kAckScopeThisOne = 'Just this one';
String ackScopeProjectWide(String ruleId) => 'Every $ruleId in this project';

/// The reason field's label at instance scope, where RJ-006 makes it
/// optional and the word "optional" is doing real work: a person who
/// believes it is required will invent something to type.
const String kAckReasonOptional = 'Reason (optional)';

/// And at project scope, where CR-019 requires it.
const String kAckReasonRequired = 'Reason (required)';

/// The severity control's label.
const String kAckThenTreatAs = 'Then treat it as';

/// What `Severity.off` is called in this control.
///
/// NOT "off", which reads as a switch rather than as a consequence. The
/// finding still exists and still prints on `T0.02` (CR-022); what
/// changes is that it stops appearing in the list.
const String kAckSeverityHidden = 'hidden from the list';

/// Shows the acknowledgement dialog for [finding].
Future<AcknowledgeChoice?> showAcknowledgeFindingDialog({
  required BuildContext context,
  required Finding finding,
}) => showDialog<AcknowledgeChoice>(
  context: context,
  builder: (context) => _AcknowledgeDialog(finding: finding),
);

class _AcknowledgeDialog extends StatefulWidget {
  const _AcknowledgeDialog({required this.finding});

  final Finding finding;

  @override
  State<_AcknowledgeDialog> createState() => _AcknowledgeDialogState();
}

class _AcknowledgeDialogState extends State<_AcknowledgeDialog> {
  late final TextEditingController _reason = TextEditingController();
  bool _projectWide = false;
  late Severity _demotedTo = widget.finding.severity;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  String get _fingerprint =>
      _projectWide ? kProjectWideFingerprint : widget.finding.targetFingerprint;

  RuleExceptionVerdict get _verdict => evaluateAcknowledgement(
    ruleId: widget.finding.ruleId,
    targetFingerprint: _fingerprint,
    reason: _reason.text,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final finding = widget.finding;
    final verdict = _verdict;
    final refusal = verdict is RuleExceptionRefused ? verdict.message : null;

    return CallbackShortcuts(
      // `Esc` is Cancel, from kKeymap rather than a literal, so the row is
      // in the generated table and arbitration can see it (CR-101).
      bindings: dialogDismissShortcut(() => Navigator.of(context).pop()),
      child: Focus(
        autofocus: true,
        child: AlertDialog(
          title: Text(
            'Acknowledge ${finding.ruleId}?',
            style: theme.textTheme.titleMedium,
          ),
          // SCROLLABLE, because this content is taller than a short
          // window: the first widget test of it failed on a RenderFlex
          // overflow at the default 800x600, which is a real screen size
          // and not a test artifact. `AlertDialog` does not scroll its
          // content for you.
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // THE FINDING'S OWN SENTENCE, unedited. It is a complete
                  // sentence about this document by construction, and a
                  // summary here would be a second, vaguer copy.
                  Text(finding.message),
                  const SizedBox(height: 16),
                  // `RadioGroup`, not the per-tile `groupValue`/`onChanged`
                  // pair: those are deprecated after Flutter 3.32, and the
                  // analyzer here is a ratchet that counts every info.
                  RadioGroup<bool>(
                    groupValue: _projectWide,
                    onChanged: (v) => setState(() => _projectWide = v!),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const RadioListTile<bool>(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          value: false,
                          title: Text(kAckScopeThisOne),
                        ),
                        RadioListTile<bool>(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          value: true,
                          title: Text(ackScopeProjectWide(finding.ruleId)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _reason,
                    autofocus: true,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: _projectWide
                          ? kAckReasonRequired
                          : kAckReasonOptional,
                      border: const OutlineInputBorder(),
                    ),
                    // REBUILDS ON EVERY KEYSTROKE, because the verdict
                    // changes with the text and a button that stays
                    // disabled after the reason is typed is a bug people
                    // work around by cancelling.
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text(kAckThenTreatAs),
                      const SizedBox(width: 12),
                      // EXPANDED, with `isExpanded` on the button itself.
                      // A `DropdownButton` sizes to its WIDEST item, and
                      // "hidden from the list" overflowed this row by 127
                      // px before a widget test caught it. Shortening the
                      // copy would have hidden the bug rather than fixed
                      // it: the next long label brings it straight back.
                      Expanded(
                        child: DropdownButton<Severity>(
                          isExpanded: true,
                          value: _demotedTo,
                          onChanged: (v) => setState(() => _demotedTo = v!),
                          items: [
                            for (final s in [
                              ...kDrcFilterableSeverities,
                              Severity.off,
                            ])
                              DropdownMenuItem(
                                value: s,
                                child: Text(
                                  s == Severity.off
                                      ? kAckSeverityHidden
                                      : s.name,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (refusal != null) ...[
                    const SizedBox(height: 12),
                    // THE THEME'S ERROR COLOUR, AND NOT A SEVERITY ONE.
                    // `status_marker_source_test.dart` caught the first
                    // draft taking a console severity's fill here, and
                    // it was right to: DR-090 §11.89.6 wants a second cue
                    // on any severity colour. But this is not a severity
                    // at all. It is a form refusal about what the person
                    // has typed, and dressing it in a finding's own
                    // vocabulary would say this sentence is one.
                    //
                    // That scan is textual and does not skip comments, so
                    // the offending spelling is deliberately not written
                    // out here either.
                    Text(
                      refusal,
                      style: TextStyle(
                        color: theme.colorScheme.error,
                        fontWeight: kConsoleEmphasis,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            // LEFTMOST AND PASSIVE. `#293`: the viewer *"is what makes an
            // override informed rather than a reflex"*, so it belongs on
            // the screen where the override is agreed to, next to the
            // decision rather than behind it. It opens a second dialog
            // and changes nothing here, so this one stays open behind it.
            TextButton(
              onPressed: () => showWhyRuleDialog(
                context: context,
                ruleId: finding.ruleId,
              ),
              child: const Text(kWhyLabel),
            ),
            // NO `Spacer` HERE. `AlertDialog.actions` is an `OverflowBar`
            // and not a `Row`, so an `Expanded` inside it throws on
            // parent data. The bar lays the actions out in order, which
            // is enough: `[ Why? ]` is simply first.
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: refusal != null
                  ? null
                  : () => Navigator.of(context).pop((
                      projectWide: _projectWide,
                      reason: _reason.text,
                      demotedTo: _demotedTo,
                    )),
              child: const Text(kAckConfirm),
            ),
          ],
        ),
      ),
    );
  }
}
