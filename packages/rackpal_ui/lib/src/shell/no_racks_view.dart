// What the Rack tab shows for a document that contains no racks.
//
// WHY THIS EXISTS, AND WHY IT IS NOT COSMETIC. `RackCanvasScreen` reads
// `doc.racks.values.first` while building its state — a precondition that
// held for as long as the only document in the app was the demo seed. The
// moment the app can OPEN A FILE, a rack-less document is reachable in
// three ordinary ways: a project a user emptied, a `.rppj` authored
// elsewhere, and (from the next stage) a Blank project. Without this the
// app would throw on the first frame after opening one, which is the worst
// possible response to a perfectly valid file.
//
// IT NOW OFFERS THE ONE THING IT CAN DO. This panel used to say, truthfully
// at the time, that "this build has no 'New rack' dialog yet … so there is
// nothing here to press", and a test asserted it carried no buttons at all.
// docs/04 §9's dialog now exists (`inspector/new_rack_dialog.dart`), so
// that sentence would have become the thing this file was written to
// prevent: a panel describing a limitation the build no longer has. The
// button routes through `showNewRack` — the SAME function `Ctrl+Alt+N` on
// the rack canvas uses — so there is still exactly one rack-creation path
// in the app.
//
// [onNewRack] IS REQUIRED, and a first draft had it nullable with a
// button-less branch and a second block of copy for a host that "cannot
// create a rack". No such host exists: the two callers in the repository —
// `app_shell.dart`'s Rack tab and `rack_canvas_screen.dart`'s own rack-less
// build — both pass one, and both route it to the same `showNewRack`. The
// branch was therefore unreachable in the shipped app and its only reader
// was the test asserting it, which is this project's "production field whose
// only writer lived in test code" shape all over again. Deleted rather than
// kept for a host that might one day appear: an untested branch is not a
// safety net, it is a second empty state nobody has ever seen.
//
// This is still NOT docs/04 §9's full empty-state design. §9's eight empty
// states (AC-058/D4) remain a later stage's work; what is here is one
// truthful sentence and one working button.
import 'package:flutter/material.dart';

/// The honest "this project has no racks" panel.
final class NoRacksView extends StatelessWidget {
  const NoRacksView({
    required this.documentName,
    required this.onNewRack,
    super.key,
  });

  /// What the document is called, so the panel is about THIS file rather
  /// than about a general condition.
  final String documentName;

  /// Opens docs/04 §9's New-rack dialog — see the file header for why this
  /// is required rather than nullable.
  final VoidCallback onNewRack;

  /// The first line, exposed for assertion without depending on layout.
  static String headline(String documentName) =>
      '$documentName contains no racks.';

  /// Why the panel exists, and what the button will do. Named as a
  /// milestone, never dated.
  static const String detail =
      'The file opened correctly and everything in it is loaded — it '
      'simply has no rack to draw. Create one and the elevation opens on '
      'it; the three fields are Name, Preset and Height (docs/04 §9), and '
      'location, RU numbering and rear mirroring are set afterwards from '
      'the rack inspector.';

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
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onNewRack,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New rack…'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
