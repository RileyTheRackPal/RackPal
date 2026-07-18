import 'package:flutter/material.dart';
import 'package:rackmate_core/rackmate_core.dart';
import 'package:rackmate_ui/src/canvas/canvas_intent.dart';
import 'package:rackmate_ui/src/canvas/grid_painter.dart';
import 'package:rackmate_ui/src/canvas/viewport_controller.dart';

/// The canvas surface: a pannable, zoomable background grid on top of a
/// [ViewportController].
///
/// This is the walking-skeleton viewport the roadmap builds first ("everything
/// sits on it and it is cheapest to iterate on when nothing else exists").
/// It is a real, extensible widget, not a throwaway: a later stage replaces the
/// single [GridPainter] child with the L0..L5 layer stack (docs/03 §7.2) — the
/// grid painter stays as L0, the rack chassis / device / wire / overlay layers
/// stack above it, all reading this same [ViewportController].
class RackCanvasScreen extends StatefulWidget {
  const RackCanvasScreen({super.key});

  @override
  State<RackCanvasScreen> createState() => _RackCanvasScreenState();
}

class _RackCanvasScreenState extends State<RackCanvasScreen> {
  final ViewportController _viewport = ViewportController();
  final GridCache _gridCache = GridCache();

  @override
  void dispose() {
    _viewport.dispose();
    _gridCache.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = GridStyle(
      minorColor: scheme.outlineVariant.withValues(alpha: 0.55),
      majorColor: scheme.outline.withValues(alpha: 0.85),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportSize = constraints.biggest;
        return ColoredBox(
          color: scheme.surface,
          child: Stack(
            children: [
              Positioned.fill(
                child: CanvasIntentDetector(
                  viewport: _viewport,
                  // No handler yet: primary drags pan. A later stage supplies a
                  // CanvasIntentHandler here to move/marquee/connect.
                  child: CustomPaint(
                    painter: GridPainter(
                      viewport: _viewport,
                      cache: _gridCache,
                      style: style,
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
              Positioned(
                left: 12,
                top: 12,
                child: _ViewportHud(
                  viewport: _viewport,
                  onReset: _viewport.reset,
                  // Fit a sample scene box so the fitToContent path is visibly
                  // exercised before real content exists.
                  onFit: () => _viewport.fitToContent(
                    const Box.fromLtwh(0, 0, 600, 400),
                    viewportSize,
                  ),
                ),
              ),
              Positioned(
                left: 12,
                bottom: 12,
                child: IgnorePointer(
                  child: Text(
                    'Scroll to pan  ·  Ctrl/Cmd+scroll or pinch to zoom  ·  '
                    'middle-drag to pan',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Small floating readout: live zoom percentage plus reset / fit controls.
class _ViewportHud extends StatelessWidget {
  const _ViewportHud({
    required this.viewport,
    required this.onReset,
    required this.onFit,
  });

  final ViewportController viewport;
  final VoidCallback onReset;
  final VoidCallback onFit;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Subscribes directly to the viewport Listenable. A production
            // status bar would throttle this to ~10 Hz (docs/03 §4.4); at demo
            // scope the raw rebuild of one Text is fine.
            AnimatedBuilder(
              animation: viewport,
              builder: (context, _) => Text(
                '${(viewport.scale * 100).round()}%',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Fit sample content',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.fit_screen_outlined),
              onPressed: onFit,
            ),
            IconButton(
              tooltip: 'Reset view (100%)',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.restart_alt),
              onPressed: onReset,
            ),
          ],
        ),
      ),
    );
  }
}
