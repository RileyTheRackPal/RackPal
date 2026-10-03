// The Export notices dialog (M6-M `#983`, DR-224).
//
// Every notice the exporter writes is a sentence about one sheet, prefixed
// with that sheet's id (`T6.10: 4 pathways have no designator ...`), or a
// sentence about the set. Until DR-224 none was shown: the status line
// counted them and dropped the words. This lists them, grouped by the sheet
// they name in the order the export raised them, with Copy so a person can
// paste them into a message or a ticket.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rackpal_ui/src/theme/console_theme.dart';

/// The dialog's title.
const String kExportNoticesTitle = 'Export notices';

/// The heading for notices that name no sheet.
const String kSetWideNoticesHeading = 'The set';

final RegExp _sheetPrefix = RegExp(r'^(T\d\.\d+): (.*)$', dotAll: true);

/// [notices] grouped by the sheet id each begins with, groups in the order
/// their first notice was raised; a notice naming no sheet goes under
/// [kSetWideNoticesHeading]. Public so the grouping is tested without a
/// widget.
List<({String heading, List<String> notices})> groupExportNotices(
  List<String> notices,
) {
  final groups = <String, List<String>>{};
  for (final notice in notices) {
    final m = _sheetPrefix.firstMatch(notice);
    final heading = m?.group(1) ?? kSetWideNoticesHeading;
    groups.putIfAbsent(heading, () => <String>[]).add(m?.group(2) ?? notice);
  }
  return [
    for (final e in groups.entries) (heading: e.key, notices: e.value),
  ];
}

/// Shows [notices] (DR-224 §11.223.1).
Future<void> showExportNoticesDialog(
  BuildContext context,
  List<String> notices,
) => showDialog<void>(
  context: context,
  builder: (context) => ExportNoticesDialog(notices: notices),
);

/// The dialog itself.
class ExportNoticesDialog extends StatelessWidget {
  const ExportNoticesDialog({required this.notices, super.key});

  final List<String> notices;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final groups = groupExportNotices(notices);
    return AlertDialog(
      title: Text(kExportNoticesTitle, style: theme.textTheme.titleMedium),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final g in groups) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 2),
                  child: Text(
                    g.heading,
                    style: theme.textTheme.labelLarge?.copyWith(
                      // The bundle's one real weight above Regular; a w600
                      // would be synthesised (`font_weight_coverage_test`).
                      fontWeight: kConsoleEmphasis,
                    ),
                  ),
                ),
                for (final n in g.notices)
                  Padding(
                    padding: const EdgeInsets.only(left: 12, bottom: 4),
                    child: SelectableText(n, style: theme.textTheme.bodySmall),
                  ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Clipboard.setData(ClipboardData(text: notices.join('\n'))),
          child: const Text('Copy'),
        ),
        TextButton(
          autofocus: true,
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
