// What the window shows when RackPal cannot start (DR-194, board `#940`).
//
// ═════════════════════════════════════════════════════════════════════
// THE CASE `main.dart`'s HEADER CALLED A BLACK WINDOW
// ═════════════════════════════════════════════════════════════════════
// Anything thrown by the awaits before `runApp` reached the zone's handler
// and nothing else: no frame had been drawn, so the process sat behind a
// hidden or black window and the person saw nothing at all. It was caught
// and shown to nobody.
//
// This is the smallest window that says three true things: the app did not
// start, where its log is (or that there is none), and how to close it.
// It does not say the person's files are safe, because it cannot know that:
// a failure inside `buildAppServices` may be halfway through reading the
// recovery folder. A reassurance the code cannot check is the kind of copy
// that is true until the day it is quoted back.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

/// Runs [start], and hands anything it throws to [onFailure] instead of
/// letting it escape into a window nobody can see.
///
/// A function rather than a `try` written inline in `main.dart`, so the
/// shape "a startup that throws reaches the failure path" is testable
/// without a platform window.
Future<void> guardStartup(
  Future<void> Function() start,
  Future<void> Function(Object error, StackTrace stack) onFailure,
) async {
  try {
    await start();
  } on Object catch (error, stack) {
    await onFailure(error, stack);
  }
}

/// The window's title line.
const String kStartupFailedTitle = 'RackPal could not start';

/// The line when there is a log to point at.
const String kStartupFailedWithLog =
    'What went wrong was written to a log in this folder. If you send the '
    'log to whoever gave you this build, they can see what happened. It '
    'holds no project names or file paths.';

/// The line when the data folder itself was the problem.
const String kStartupFailedNoLog =
    'No log could be written, because RackPal could not use its data '
    'folder. That folder is usually the problem when this happens.';

/// The button that copies the folder path.
const String kCopyLogFolderLabel = 'Copy folder path';

/// The minimal app shown instead of RackPal when startup throws.
///
/// [logFolder] is the diagnostics folder, or null when no log could be
/// written. [onClose] ends the process; injected so a test can see it.
final class StartupFailureApp extends StatelessWidget {
  const StartupFailureApp({
    required this.logFolder,
    required this.onClose,
    super.key,
  });

  final String? logFolder;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: buildConsoleTheme(),
    home: Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: _Body(logFolder: logFolder, onClose: onClose),
          ),
        ),
      ),
    ),
  );
}

final class _Body extends StatelessWidget {
  const _Body({required this.logFolder, required this.onClose});

  final String? logFolder;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final folder = logFolder;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(kStartupFailedTitle, style: theme.textTheme.titleLarge),
        const SizedBox(height: 12),
        Text(folder == null ? kStartupFailedNoLog : kStartupFailedWithLog),
        if (folder != null) ...[
          const SizedBox(height: 12),
          SelectableText(folder, style: theme.textTheme.bodySmall),
        ],
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (folder != null)
              TextButton(
                onPressed: () => Clipboard.setData(ClipboardData(text: folder)),
                child: const Text(kCopyLogFolderLabel),
              ),
            const SizedBox(width: 8),
            FilledButton(
              autofocus: true,
              onPressed: onClose,
              child: const Text('Close'),
            ),
          ],
        ),
      ],
    );
  }
}
