// packages/rackmate_ui/lib/src/canvas/compaction_preview_bar.dart
//
// docs/04-rack-editor.md §3.6's floating bar, verbatim: "a floating bar
// 'Compact Up — 4 devices move — 3U freed [Apply] [Cancel]'. Enter applies
// as one undo entry, Esc cancels."
//
// A `Positioned` in the canvas `Stack` rather than an `Overlay`/`OverlayEntry`
// (the route the drag chips take), because — unlike a drag chip — this bar
// does not follow a pointer and is not transient chrome over an in-flight
// gesture. It sits at a fixed spot for as long as the user is deciding, and
// it must accept CLICKS on its two buttons, which the drag overlays'
// `IgnorePointer` wrapper explicitly forbids for themselves.
//
// The keyboard bindings are NOT here. `Enter`/`Esc` are wired in
// `RackCanvasScreen`'s existing `Shortcuts`/`Actions` map, so the same two
// keys keep their single registration point and the Apply action can declare
// itself disabled when no preview is open — see that file's
// `_ApplyCompactionAction` for why a real `Action` subclass is required
// rather than a `CallbackAction` (a `CallbackAction` returning null still
// marks the key HANDLED, which would silently swallow `Enter` from the
// palette search box).

import 'package:flutter/material.dart';
import 'package:rackmate_ui/src/canvas/compaction_preview_controller.dart';

/// §3.6's Apply/Cancel bar. Renders nothing at all when [controller] has no
/// plan, so the caller can leave it permanently in the `Stack` rather than
/// conditionally inserting it.
class CompactionPreviewBar extends StatelessWidget {
  const CompactionPreviewBar({
    required this.controller,
    required this.onApply,
    required this.onCancel,
    super.key,
  });

  final CompactionPreviewController controller;
  final VoidCallback onApply;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (!controller.isActive) return const SizedBox.shrink();
        final scheme = Theme.of(context).colorScheme;
        return Card(
          elevation: 6,
          color: scheme.surfaceContainerHigh,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  // Built by the controller, not spelled again here, so the
                  // label and the plan cannot drift (and so a unit test can
                  // pin the exact string without a widget tree).
                  controller.barLabel,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(width: 16),
                // Apply leads and is the filled button: §3.6 binds Enter to
                // it, and a preview the user opened deliberately is a
                // proposal they are expected to accept or reject, not a
                // warning they are expected to back out of.
                FilledButton(onPressed: onApply, child: const Text('Apply')),
                const SizedBox(width: 8),
                TextButton(onPressed: onCancel, child: const Text('Cancel')),
              ],
            ),
          ),
        );
      },
    );
  }
}
