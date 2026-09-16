// The first-launch start card (docs/04-rack-editor.md §9).
//
// §9 is explicit and this widget is a direct reading of it: *"First
// launch shows a start card, not an empty canvas: `Blank project` plus
// the four starter projects, which are authored as real `.rppj`
// files… A user who picks 'Home theater' is editing a populated,
// finding-clean 24U rack in two seconds, which is a far lower-effort mode
// than creating one."*
//
// THE ARGUMENT THE CARD IS MAKING is that opening something populated
// beats building something empty, so the starters are the prominent
// choice and `Blank project` sits with them rather than above them as
// the default. Each starter states its SIZE and its CONTENT, because a
// user choosing between four nouns is guessing.
//
// ==================================================================
// PURELY PRESENTATIONAL
// ==================================================================
// Like every other widget in `src/shell/`, this one knows nothing about
// assets, files or documents: it takes a list of value objects and hands
// back an id. `rackpal_ui` reaches for no file dialog, no path provider
// and no `dart:io`, and the start card is exactly the widget that would
// have quietly introduced the first of those.
//
// ==================================================================
// WHY THERE IS AN "OPEN A PROJECT…" BUTTON, WHICH §9 DOES NOT LIST
// ==================================================================
// The card REPLACES the canvas at launch — that is §9's own instruction.
// A user who already has a project would otherwise find that the primary
// surface offers five ways to start something new and none to open what
// they came for; the File menu has `Open…`, but a menu bar is
// discoverable, not primary. One secondary text button, routed to the
// SAME `Ctrl+O` action, is the smallest thing that keeps the card from
// being a dead end for the most common real session.
import 'package:flutter/material.dart';

/// One starter project, as the card renders it.
final class StarterEntry {
  const StarterEntry({
    required this.id,
    required this.title,
    required this.summary,
    required this.detail,
  });

  /// Handed back to [StartCard.onStarter] verbatim.
  final String id;

  /// The tile's headline.
  final String title;

  /// Size and shape: "24U rack · 15 rack devices · 14 in the field".
  final String summary;

  /// One sentence on what is in it.
  final String detail;
}

/// docs/04 §9's first-launch card.
final class StartCard extends StatelessWidget {
  const StartCard({
    required this.starters,
    required this.onBlank,
    required this.onStarter,
    required this.onOpen,
    super.key,
  });

  /// The four (docs/04 §9). The widget does not require exactly four —
  /// the app's own `starter_assets_test.dart` is what asserts the count,
  /// because "there are four" is a fact about the assets and not about
  /// this widget.
  final List<StarterEntry> starters;

  /// `Blank project`.
  final VoidCallback onBlank;

  /// A starter was chosen; the argument is [StarterEntry.id].
  final void Function(String id) onStarter;

  /// `Open a project…` — the same action `Ctrl+O` runs.
  final VoidCallback onOpen;

  /// The card's headline, exposed so a test can assert the copy without
  /// depending on layout.
  static const String headline = 'Start a project';

  /// The sentence under the headline.
  static const String subhead =
      'Open one of the four sample projects to start from something '
      'populated, or begin with an empty rack.';

  /// The `Blank project` tile's own copy.
  static const String blankTitle = 'Blank project';

  /// What `Blank project` actually produces in this build. Stated rather
  /// than implied: it is one empty 42U rack, not a document with no
  /// racks, and a user is entitled to know that before choosing.
  static const String blankDetail =
      'One empty 42U rack and the full device catalogue, ready to '
      'populate.';

  /// The secondary action's label. See the file header for why it is
  /// here at all.
  static const String openLabel = 'Open a project…';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(headline, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(subhead, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 24),
              for (final starter in starters) ...[
                _StartTile(
                  key: ValueKey<String>('starter-${starter.id}'),
                  title: starter.title,
                  summary: starter.summary,
                  detail: starter.detail,
                  icon: Icons.dashboard_outlined,
                  onPressed: () => onStarter(starter.id),
                ),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 8),
              _StartTile(
                key: const ValueKey<String>('starter-blank'),
                title: blankTitle,
                summary: '',
                detail: blankDetail,
                icon: Icons.add_box_outlined,
                onPressed: onBlank,
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: onOpen,
                  icon: const Icon(Icons.folder_open_outlined),
                  label: const Text(openLabel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One pressable row. A real `InkWell` inside a `Card` rather than a
/// `ListTile`, so the summary and the detail can be two separate lines
/// and the whole row is one focus stop and one 44 px-tall hit target.
final class _StartTile extends StatelessWidget {
  const _StartTile({
    required this.title,
    required this.summary,
    required this.detail,
    required this.icon,
    required this.onPressed,
    super.key,
  });

  final String title;
  final String summary;
  final String detail;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 22, color: theme.colorScheme.primary),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleMedium),
                    if (summary.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        summary,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(detail, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
