// rackpal_ui/src/canvas/schematic/pin_badge_layer.dart — the 📌 on a pinned
// schematic symbol (DR-186 §11.185.3, `#913`).
//
// SCREEN CHROME AND NEVER A SCENE OP, on `MarqueeBand`'s precedent and for
// CR-086's reason: `buildSchematicScene` feeds the PDF as well as the
// display, so a badge in the scene would print on the client's interconnect
// sheets, where a pin is a fact about somebody's editing session and means
// nothing.
//
// A constant 12 logical pixels at every zoom, in the symbol's top-left
// corner, where docs/05 §3's header puts `📌 SheetItem.pinned` among its
// badges. Drawn as paths rather than as an emoji glyph, so it renders the
// same on a machine with no colour-emoji font and a test can find it.
import 'package:flutter/widgets.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/src/canvas/viewport_controller.dart';

/// Draws a pin on the top-left corner of every box in [symbols].
final class PinBadgeLayer extends StatelessWidget {
  const PinBadgeLayer({
    required this.symbols,
    required this.viewport,
    required this.color,
    super.key,
  });

  /// The body rects of the pinned symbols, in scene units.
  final List<DBox> symbols;

  final ViewportController viewport;

  /// The pin's ink. Passed in, because this layer is built by a screen
  /// that has a theme and this file has none.
  final Color color;

  /// A stable handle for tests.
  static const Key layerKey = ValueKey('schematic-pin-badges');

  @override
  Widget build(BuildContext context) {
    if (symbols.isEmpty) return const SizedBox.shrink();
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: viewport,
        builder: (context, _) => CustomPaint(
          key: layerKey,
          painter: _PinPainter(symbols, viewport, color),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _PinPainter extends CustomPainter {
  _PinPainter(this.symbols, this.viewport, this.color);

  final List<DBox> symbols;
  final ViewportController viewport;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    for (final box in symbols) {
      final at = viewport.sceneToScreen(DPt(box.left, box.top));
      paintPin(canvas, Offset(at.x, at.y), color);
    }
  }

  @override
  bool shouldRepaint(_PinPainter old) =>
      !identical(old.symbols, symbols) || old.color != color;
}

/// One pin with its plate's top-left at [topLeft], in screen pixels.
@visibleForTesting
void paintPin(Canvas canvas, Offset topLeft, Color ink) {
  final origin = topLeft + const Offset(3, 3);
  final plate = RRect.fromRectAndRadius(
    origin & const Size(12, 12),
    const Radius.circular(2),
  );
  final stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.2
    ..color = ink;
  canvas
    ..drawRRect(plate, Paint()..color = const Color(0xF2FFFFFF))
    ..drawRRect(
      plate,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = ink,
    )
    // The head, then the needle leaning down and left.
    ..drawCircle(origin + const Offset(7.5, 4.5), 2.5, Paint()..color = ink)
    ..drawLine(
      origin + const Offset(6.5, 6.5),
      origin + const Offset(4, 11),
      stroke,
    );
}
