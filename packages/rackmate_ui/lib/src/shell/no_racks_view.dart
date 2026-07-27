// What the Rack tab shows for a document that contains no racks.
//
// WHY THIS EXISTS, AND WHY IT IS NOT COSMETIC. `RackCanvasScreen` reads
// `doc.racks.values.first` while building its state — a precondition that
// held for as long as the only document in the app was the demo seed.
// The moment the app can OPEN A FILE, a rack-less document is reachable
// in three ordinary ways: a project a user emptied, a `.rackmate`
// authored elsewhere, and (from the next stage) a Blank project. Without
// this the app would throw on the first frame after opening one, which is
// the worst possible response to a perfectly valid file.
//
// This is NOT the docs/04 §9 empty-state design. §9's eight empty states
// (AC-058/D4) are a later stage's work, and "New rack" is a three-field
// dialog that does not exist yet. So this panel says exactly what is true
// — the file opened, it holds no racks, and this build offers no way to
// add one — and offers nothing it cannot do. An empty rack canvas here
// would be the same lie the Schedule tab was rescued from: it would show
// rails and a ruler for a rack that is not in the document.
import 'package:flutter/material.dart';

/// The honest "this project has no racks" panel.
final class NoRacksView extends StatelessWidget {
  const NoRacksView({required this.documentName, super.key});

  /// What the document is called, so the panel is about THIS file rather
  /// than about a general condition.
  final String documentName;

  /// The first line, exposed for assertion without depending on layout.
  static String headline(String documentName) =>
      '$documentName contains no racks.';

  /// Why nothing is offered here. Named as a milestone, never dated.
  static const String detail =
      'The file opened correctly and everything in it is loaded — it '
      'simply has no rack to draw. This build has no "New rack" dialog '
      'yet (docs/04 §4 · M1), so there is nothing here to press. Open a '
      'project that contains a rack, or add one in a build that has the '
      'dialog.';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                headline(documentName),
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Text(detail, style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}
