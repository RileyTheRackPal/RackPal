// The `[ Why? ]` rationale viewer (`#296`, M5-F3, AC-058/D1, DR-114).
//
// ═══════════════════════════════════════════════════════════════════════
// THE BUTTON THAT LED NOWHERE
// ═══════════════════════════════════════════════════════════════════════
// docs/research/critique-completeness.md §434 named this exactly: *"a
// `[ Why? ]` button that leads nowhere. Rule rationale exists in the
// model with no viewer."* Half of that was wrong. The rationale did NOT
// exist: the type the critique cites, `CompatibilityRuleDef`, is from a
// priority-3 research document and was never built. `RuleMeta` carried a
// summary and a list of ruling ids and nothing a person could read as an
// answer. M5-F3 added `RuleMeta.rationale`; this is the viewer.
//
// ═══════════════════════════════════════════════════════════════════════
// IT READS THE CATALOGUE AND HOLDS NO COPY
// ═══════════════════════════════════════════════════════════════════════
// `#296`: *"sourced from the catalogue metadata so it cannot drift from
// the predicate"*. So there is no map of explanations in this file. A
// rule whose predicate changes and whose rationale does not is a problem
// this cannot fix, but a rule whose EXPLANATION lives somewhere the rule
// does not is one it refuses to create.
//
// ═══════════════════════════════════════════════════════════════════════
// AN UNKNOWN RULE IS AN ANSWER, NOT AN ERROR
// ═══════════════════════════════════════════════════════════════════════
// CR-021: a rule not in the catalogue does not exist. So a `ruleId` that
// misses says that, in the same sentence `ruleAcceptsAnException` uses,
// rather than throwing or drawing an empty sheet. A file written by a
// later version is the case that reaches it.
import 'package:flutter/material.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/src/keymap/keymap.dart';
import 'package:rackpal_ui/src/theme/console_theme.dart';

/// The label every entry point uses, so the button reads the same on the
/// spring-back chip and in the acknowledgement dialog.
const String kWhyLabel = 'Why?';

/// The heading over `RuleMeta.summary`: what the product checks.
const String kWhyChecks = 'What this checks';

/// The heading over `RuleMeta.rationale`: why it is worth checking.
const String kWhyMatters = 'Why it matters';

/// The heading over `RuleMeta.governing`: the decisions behind it.
///
/// Named for what they ARE rather than "governing rulings", which is
/// this project's own word for them and means nothing to a reader.
const String kWhyDecisions = 'Recorded decisions';

/// What the viewer says about a rule this version does not have.
String whyUnknownRule(String ruleId) =>
    '$ruleId is not a rule this version of RackPal knows, so there is '
    'nothing to explain. A file written by a later version can carry one.';

/// Shows the rationale for [ruleId].
Future<void> showWhyRuleDialog({
  required BuildContext context,
  required String ruleId,
}) => showDialog<void>(
  context: context,
  builder: (context) => WhyRuleDialog(ruleId: ruleId),
);

/// The viewer, public so a test can pump it without a route.
class WhyRuleDialog extends StatelessWidget {
  const WhyRuleDialog({required this.ruleId, super.key});

  final String ruleId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final meta = kRulesById[ruleId];

    return CallbackShortcuts(
      bindings: dialogDismissShortcut(() => Navigator.of(context).pop()),
      child: Focus(
        autofocus: true,
        child: AlertDialog(
          title: Text(ruleId, style: theme.textTheme.titleMedium),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: meta == null
                  ? Text(whyUnknownRule(ruleId))
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // WHY FIRST. The person clicked a button that
                        // asks why, and leading with what the predicate
                        // tests would answer a question they did not ask.
                        _Section(
                          heading: kWhyMatters,
                          body: meta.rationale,
                        ),
                        const SizedBox(height: 16),
                        _Section(heading: kWhyChecks, body: meta.summary),
                        const SizedBox(height: 16),
                        _Section(
                          heading: kWhyDecisions,
                          body: meta.governing.join(', '),
                        ),
                      ],
                    ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.heading, required this.body});

  final String heading;
  final String body;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        heading,
        style: const TextStyle(fontWeight: kConsoleEmphasis),
      ),
      const SizedBox(height: 4),
      Text(body),
    ],
  );
}
