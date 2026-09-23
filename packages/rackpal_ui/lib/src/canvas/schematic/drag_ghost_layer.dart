// rackpal_ui/src/canvas/schematic/drag_ghost_layer.dart — the dashed
// rectangle a symbol drag follows the cursor with (DR-187 §11.186.8,
// `#918`).
//
// SCREEN CHROME AND NEVER A SCENE OP, on `MarqueeBand`'s precedent and for
// CR-086's reason: `buildSchematicScene` feeds the PDF as well as the
// display, so a ghost in the scene would print.
//
// ═══════════════════════════════════════════════════════════════════════
// A GHOST RATHER THAN THE SYMBOL ITSELF, AND THE PRICE IS WHY
// ═══════════════════════════════════════════════════════════════════════
// §11.186.8 settled this against a live preview, on measurements rather
// than taste. One frame is 16.7 ms, and `schematic_perf_test.dart` says a
// twelve-pod job (3,600 links, 1,320 devices) costs 8.8 ms to re-route
// with the symbol tier reused, 36.3 ms with the layout reused, and 76.9 ms
// cold. A 300-link house is 0.72 ms and would have been fine. **The
// expensive case is the one that decides**, because a campus sheet is
// exactly the sheet somebody needs to drag symbols around on.
//
// This costs one rectangle per frame at any size, which is the budget
// CR-102's marquee band already runs on.
//
// **WHAT IT COSTS IS THAT THE WIRES ARE NOT SEEN UNTIL THE DROP.** A
// symbol dropped into a tangle looks fine until it is released, and one
// `Ctrl+Z` is the way out. That is stated in the ruling too, rather than
// discovered here.
import 'package:flutter/widgets.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/src/canvas/viewport_controller.dart';

/// Draws [box] as a dashed outline, or nothing when it is null.
final class DragGhostLayer extends StatelessWidget {
  const DragGhostLayer({
    required this.box,
    required this.viewport,
    required this.color,
    super.key,
  });

  /// Where the symbol WOULD land, in scene units, or null when no drag is
  /// in flight.
  final DBox? box;

  final ViewportController viewport;

  /// The outline's ink. Passed in, because this layer is built by a screen
  /// that has a theme and this file has none.
  final Color color;

  /// A stable handle for tests.
  static const Key layerKey = ValueKey('schematic-drag-ghost');

  @override
  Widget build(BuildContext context) {
    final ghost = box;
    if (ghost == null) return const SizedBox.shrink();
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: viewport,
        builder: (context, _) => CustomPaint(
          key: layerKey,
          painter: _GhostPainter(ghost, viewport, color),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _GhostPainter extends CustomPainter {
  _GhostPainter(this.box, this.viewport, this.color);

  final DBox box;
  final ViewportController viewport;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final topLeft = viewport.sceneToScreen(DPt(box.left, box.top));
    final bottomRight = viewport.sceneToScreen(DPt(box.right, box.bottom));
    final rect = Rect.fromLTRB(
      topLeft.x,
      topLeft.y,
      bottomRight.x,
      bottomRight.y,
    );
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = color;
    // A WASH UNDER THE OUTLINE, so the ghost reads as a place rather than
    // as four lines. Faint enough that the drawing underneath is still
    // legible, which is the point of moving it there.
    canvas.drawRect(rect, Paint()..color = color.withValues(alpha: 0.08));
    for (final side in _dashes(rect)) {
      canvas.drawLine(side.$1, side.$2, stroke);
    }
  }

  /// The four sides as dash segments.
  ///
  /// DASHED AND NOT SOLID, because a solid rectangle at a symbol's exact
  /// size is indistinguishable from a symbol that has already moved. The
  /// gesture is a proposal until the pointer comes up, and the outline has
  /// to say so.
  Iterable<(Offset, Offset)> _dashes(Rect rect) sync* {
    const dash = 6.0;
    const gap = 4.0;
    final corners = [
      (rect.topLeft, rect.topRight),
      (rect.topRight, rect.bottomRight),
      (rect.bottomRight, rect.bottomLeft),
      (rect.bottomLeft, rect.topLeft),
    ];
    for (final (from, to) in corners) {
      final span = to - from;
      final length = span.distance;
      if (length <= 0) continue;
      final step = span / length;
      for (var at = 0.0; at < length; at += dash + gap) {
        final end = at + dash < length ? at + dash : length;
        yield (from + step * at, from + step * end);
      }
    }
  }

  @override
  bool shouldRepaint(_GhostPainter old) => old.box != box || old.color != color;
}
