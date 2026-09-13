// PWR-003's remedy, when the rack has no distribution to extend
// (`#875`, DR-128 §11.127.5, DR-129 §11.128.4).
//
// ═══════════════════════════════════════════════════════════════════════
// THE QUESTION IS CORE'S AND THE BUTTONS ARE THIS FILE'S
// ═══════════════════════════════════════════════════════════════════════
// `addOutletsToRack` returns an `AddOutletsChoice` carrying the sentence
// to ask, and its own comment says why it refuses to answer itself:
// *"NOT A REFUSAL. Nothing is wrong with the document and nothing failed;
// the remedy simply will not choose between two different jobs on
// somebody's behalf."*
//
// A power strip on a shelf is the everyday fix. A 0U vertical PDU is the
// start of a power plan. Those are different jobs and the difference is
// the installer's to make, so the dialog names both in the trade's own
// terms rather than offering a default with an `Advanced…` beside it.
//
// ═══════════════════════════════════════════════════════════════════════
// AND IT IS ONLY ASKED WHEN THE RACK HAS NOTHING
// ═══════════════════════════════════════════════════════════════════════
// A rack that already provides outlets gets a strip without being asked,
// because extending distribution that exists is one job with one answer.
// This dialog exists for the empty case alone, which is why it is a
// question and not a preference.
import 'package:flutter/material.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/src/keymap/keymap.dart' show dialogDismissShortcut;

/// The title, which names the act rather than the rule.
const String kAddOutletsTitle = 'Add outlets';

/// The two answers, in the trade's words.
const String kAddOutletsStrip = 'Power strip on a shelf';
const String kAddOutletsPdu = 'Rack PDU (0U, vertical)';

/// What each one is for, under its own button.
const String kAddOutletsStripWhy =
    'The everyday fix: a passive strip, '
    'one rack unit, plugged into what is already there.';
const String kAddOutletsPduWhy =
    'The start of a power plan: 24 outlets '
    'down the back of the rack, taking no rail space.';

/// Asks [question] and returns which source to place, or null on cancel.
Future<OutletSource?> showAddOutletsChoiceDialog({
  required BuildContext context,
  required String question,
}) => showDialog<OutletSource>(
  context: context,
  builder: (context) => _AddOutletsChoiceDialog(question: question),
);

class _AddOutletsChoiceDialog extends StatelessWidget {
  const _AddOutletsChoiceDialog({required this.question});

  /// Core's sentence, printed verbatim. It names the rack by designator,
  /// so rewording it here would lose the one fact that tells the reader
  /// which rack they are answering about.
  final String question;

  /// Stable handles for tests.
  static const Key stripKey = ValueKey('add-outlets-strip');
  static const Key pduKey = ValueKey('add-outlets-pdu');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CallbackShortcuts(
      bindings: dialogDismissShortcut(() => Navigator.of(context).pop()),
      child: Focus(
        autofocus: true,
        child: AlertDialog(
          title: Text(kAddOutletsTitle, style: theme.textTheme.titleMedium),
          content: SizedBox(
            width: 460,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(question, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 16),
                _Option(
                  buttonKey: stripKey,
                  label: kAddOutletsStrip,
                  why: kAddOutletsStripWhy,
                  onPressed: () =>
                      Navigator.of(context).pop(OutletSource.powerStrip),
                ),
                const SizedBox(height: 8),
                _Option(
                  buttonKey: pduKey,
                  label: kAddOutletsPdu,
                  why: kAddOutletsPduWhy,
                  onPressed: () =>
                      Navigator.of(context).pop(OutletSource.rackPdu),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}

/// One answer: the name, and one line saying what it is for.
///
/// THE EXPLANATION IS UNDER THE BUTTON, NOT IN A TOOLTIP. Somebody
/// meeting this dialog is being asked a question about their own job and
/// may not know which of the two they want; a hover-only explanation is
/// no explanation on the first read, which is the only read that matters
/// here.
class _Option extends StatelessWidget {
  const _Option({
    required this.buttonKey,
    required this.label,
    required this.why,
    required this.onPressed,
  });

  final Key buttonKey;
  final String label;
  final String why;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OutlinedButton(
          key: buttonKey,
          onPressed: onPressed,
          child: Align(alignment: Alignment.centerLeft, child: Text(label)),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 12, top: 2),
          child: Text(
            why,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
