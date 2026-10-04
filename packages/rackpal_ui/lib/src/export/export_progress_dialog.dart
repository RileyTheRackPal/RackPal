// packages/rackpal_ui/lib/src/export/export_progress_dialog.dart
// M6-I2 (`#353`), docs/08 §8.2, CR-099: export progress, and a Cancel that
// stops the work.
//
// ═════════════════════════════════════════════════════════════════════
// SHOWN ONLY WHEN IT IS WORTH SHOWING
// ═════════════════════════════════════════════════════════════════════
// §8.2: under 400 ms no progress at all, since a bar flashed for a
// three-sheet export looks worse than a brief pause. The caller decides
// that and opens this only for a job still running at the threshold; at
// the measured rate (DR-230 §11.229.1) that is a set of about sixty-five
// sheets, so most people never see it.
//
// TWO PHASES, SAID AS TWO. The sheets are drawn one at a time and counted;
// then the PDF library paints and writes every page inside one call that
// reports nothing, and that is most of the time. A bar parked at full
// while four fifths of the work is still to come would be a lie, so the
// second phase is an indeterminate bar that says what is happening.
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

/// How far an export has got: sheets drawn of the set's total. Null
/// before the set has resolved.
typedef ExportProgress = ({int sheetsDone, int sheets});

/// The dialog's title.
const String kExportProgressTitle = 'Exporting PDF';

/// What the dialog says while the file is being written.
const String kExportWritingLabel = 'Writing the file…';

/// What it says before the set has resolved.
const String kExportPreparingLabel = 'Working out the sheet set…';

/// `Drawing sheet 12 of 31`.
String exportDrawingLabel(ExportProgress p) =>
    'Drawing sheet ${p.sheetsDone + 1} of ${p.sheets}';

/// Shows [progress] until [finished] completes, closing itself then.
/// Cancel calls [onCancel], which must stop the work and complete
/// [finished]; this dialog never decides that the export is over.
Future<void> showExportProgressDialog(
  BuildContext context, {
  required ValueListenable<ExportProgress?> progress,
  required Future<void> finished,
  required VoidCallback onCancel,
}) {
  var open = true;
  final navigator = Navigator.of(context);
  finished.whenComplete(() {
    if (open) navigator.pop();
  });
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _ExportProgressDialog(
      progress: progress,
      onCancel: onCancel,
    ),
  ).whenComplete(() => open = false);
}

class _ExportProgressDialog extends StatelessWidget {
  const _ExportProgressDialog({required this.progress, required this.onCancel});

  final ValueListenable<ExportProgress?> progress;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(kExportProgressTitle),
      content: SizedBox(
        width: 360,
        child: ValueListenableBuilder<ExportProgress?>(
          valueListenable: progress,
          builder: (context, p, _) {
            final drawing = p != null && p.sheetsDone < p.sheets;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p == null
                      ? kExportPreparingLabel
                      : drawing
                      ? exportDrawingLabel(p)
                      : kExportWritingLabel,
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  // DETERMINATE ONLY WHILE IT IS COUNTING SOMETHING.
                  value: drawing ? p.sheetsDone / p.sheets : null,
                ),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: onCancel,
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
      ],
    );
  }
}
