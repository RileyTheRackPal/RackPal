// The per-rule, per-project severity control (`#297`, M5-F4, CR-019).
//
// ═══════════════════════════════════════════════════════════════════════
// `off` IS AN ANSWER, AND THE HARDEST PART OF THIS SCREEN
// ═══════════════════════════════════════════════════════════════════════
// `#297`: *"Includes `off`, which is a legitimate answer a professional
// is allowed to give."* A tool that will not let an integrator say "this
// rule does not apply to my jobs" is a tool they stop opening, and CR-019
// chose that position deliberately over a nag that cannot be silenced.
//
// So `off` is offered plainly, in the same list as the others, and not
// hidden behind a confirmation that implies the person is doing
// something wrong.
//
// ═══════════════════════════════════════════════════════════════════════
// A REASON IS ALWAYS REQUIRED TO CHANGE ONE, AND NEVER TO RESTORE ONE
// ═══════════════════════════════════════════════════════════════════════
// `evaluateRuleOverride` requires a written reason at every severity,
// with no scope to split on, and `rule_exception.dart` gives the argument:
// RJ-006 lets a SINGLE acknowledgement go unexplained because it is one
// click about one cable that can be taken back, while an override is a
// standing decision about a rule for the whole project. That is the side
// of RJ-006's line where *"the essay is only demanded where the
// consequence is permanent"* puts it.
//
// RESTORING THE CATALOGUE DEFAULT NEEDS NO REASON, and that asymmetry is
// deliberate rather than an oversight: removing an override is not a
// standing decision, it is the withdrawal of one. `SetRuleOverrideCommand`
// asserts the verdict only when `to` is non-null, so the model agrees.
import 'package:flutter/material.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/src/keymap/keymap.dart';
import 'package:rackpal_ui/src/theme/console_theme.dart';
import 'package:rackpal_ui/src/validation/drc_panel.dart';
import 'package:rackpal_ui/src/validation/why_rule_dialog.dart';

/// What the dialog returns.
///
/// A NULL `severity` MEANS "restore the catalogue default", which is a
/// different act from choosing a severity that happens to equal it: the
/// first removes the override, the second records a standing decision
/// that agrees with the default and prints its reason on `T0.02`.
typedef RuleSeverityChoice = ({Severity? severity, String reason});

/// The confirm button.
const String kSeverityApply = 'Apply';

/// The option that removes the override.
String severityUseDefault(Severity? d) =>
    d == null ? 'Use the default' : 'Use the default (${d.name})';

/// What `off` is called here.
///
/// PLAIN, because `#297` rules it a legitimate answer. Anything hedged
/// would editorialise about a choice the product has already agreed a
/// professional may make.
const String kSeverityOff = 'off (this rule does not run here)';

/// The reason field's label. Always required; see this file's header.
const String kSeverityReason = 'Reason (required)';

/// Shows the severity control for [ruleId].
Future<RuleSeverityChoice?> showRuleSeverityDialog({
  required BuildContext context,
  required String ruleId,
  RuleOverride? current,
}) => showDialog<RuleSeverityChoice>(
  context: context,
  builder: (context) => _RuleSeverityDialog(ruleId: ruleId, current: current),
);

class _RuleSeverityDialog extends StatefulWidget {
  const _RuleSeverityDialog({required this.ruleId, required this.current});

  final String ruleId;
  final RuleOverride? current;

  @override
  State<_RuleSeverityDialog> createState() => _RuleSeverityDialogState();
}

class _RuleSeverityDialogState extends State<_RuleSeverityDialog> {
  late final TextEditingController _reason = TextEditingController(
    text: widget.current?.reason ?? '',
  );

  /// Null is the "use the default" row.
  late Severity? _choice = widget.current?.severity;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  /// Restoring the default is always allowed; setting one is not.
  RuleExceptionVerdict get _verdict => _choice == null
      ? const RuleExceptionAllowed()
      : evaluateRuleOverride(
          ruleId: widget.ruleId,
          reason: _reason.text,
        );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final meta = kRulesById[widget.ruleId];
    final verdict = _verdict;
    final refusal = verdict is RuleExceptionRefused ? verdict.message : null;

    return CallbackShortcuts(
      bindings: dialogDismissShortcut(() => Navigator.of(context).pop()),
      child: Focus(
        autofocus: true,
        child: AlertDialog(
          title: Text(
            'Severity for ${widget.ruleId}',
            style: theme.textTheme.titleMedium,
          ),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (meta != null) Text(meta.summary),
                  const SizedBox(height: 16),
                  RadioGroup<Severity?>(
                    groupValue: _choice,
                    onChanged: (v) => setState(() => _choice = v),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        RadioListTile<Severity?>(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          value: null,
                          title: Text(
                            severityUseDefault(meta?.defaultSeverity),
                          ),
                        ),
                        for (final s in [
                          ...kDrcFilterableSeverities,
                          Severity.off,
                        ])
                          RadioListTile<Severity?>(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            value: s,
                            title: Text(
                              s == Severity.off ? kSeverityOff : s.name,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // DISABLED WHEN RESTORING THE DEFAULT, so the field
                  // does not sit there asking for a sentence nothing
                  // will read.
                  TextField(
                    controller: _reason,
                    enabled: _choice != null,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: kSeverityReason,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  if (refusal != null) ...[
                    const SizedBox(height: 12),
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
            TextButton(
              onPressed: () => showWhyRuleDialog(
                context: context,
                ruleId: widget.ruleId,
              ),
              child: const Text(kWhyLabel),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: refusal != null
                  ? null
                  : () => Navigator.of(context).pop((
                      severity: _choice,
                      reason: _choice == null ? '' : _reason.text,
                    )),
              child: const Text(kSeverityApply),
            ),
          ],
        ),
      ),
    );
  }
}
