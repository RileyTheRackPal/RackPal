// The device mark, drawn on screen THROUGH THE SHARED IR. DR-059's
// artwork (#752), shown in the builder by #756.
//
// ═════════════════════════════════════════════════════════════════════
// THIS WIDGET OWNS NO GEOMETRY, AND THAT IS THE ENTIRE REQUIREMENT
// ═════════════════════════════════════════════════════════════════════
// CR-086: "pixels come from the shared IR; behaviour comes from the
// widget", and its sharper form, a symbol that cannot print is not a
// symbol. So this asks `deviceGlyphOp` for the same `DiagramOp` the
// elevation emits and replays it through `FlutterDiagramCanvas`, the same
// backend `RenderDeviceBox` uses.
//
// A hand-drawn Flutter `Path` that merely LOOKED like the mark would be a
// second drawing of one thing, and two drawings of one thing is how they
// come to disagree — silently, and only on paper, which is the half
// nobody looks at until a job site does.
import 'package:flutter/material.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/src/draw/flutter_canvas.dart';

/// One [DeviceGlyph] drawn at [size] in [color].
///
/// [glyph] is the RESOLVED mark: callers pass `effectiveGlyph(...)`, not
/// `TemplateBody.glyph`, because 22 of the 48 seeded templates still
/// inherit theirs from their category (DR-084).
class DeviceGlyphMark extends StatelessWidget {
  const DeviceGlyphMark({
    required this.glyph,
    this.size = 16,
    this.color,
    super.key,
  });

  final DeviceGlyph glyph;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.onSurface;
    return SizedBox.square(
      dimension: size,
      // `DeviceGlyph.none` draws nothing on purpose, and the box is still
      // laid out at `size` so a list of marks does not jump where one is
      // absent.
      child: glyph == DeviceGlyph.none
          ? const SizedBox.shrink()
          : CustomPaint(
              painter: _MarkPainter(glyph: glyph, argb: _argb(c)),
            ),
    );
  }

  static int _argb(Color c) =>
      ((c.a * 255).round() << 24) |
      ((c.r * 255).round() << 16) |
      ((c.g * 255).round() << 8) |
      (c.b * 255).round();
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter({required this.glyph, required this.argb});

  final DeviceGlyph glyph;
  final int argb;

  @override
  void paint(Canvas canvas, Size size) {
    // `deviceGlyphOp` measures its box as a CAP HEIGHT of the type size,
    // so the type size that fills this box is the inverse of that factor.
    final sizePt = size.shortestSide / kDeviceGlyphCapFactor;
    final op = deviceGlyphOp(
      glyph,
      DPt(0, size.height / 2),
      sizePt,
      argb,
      strokeWidthPt: deviceGlyphStrokeWidth(sizePt),
    );
    if (op == null) return;
    op.replay(FlutterDiagramCanvas(canvas, measurer: const _NeverMeasures()));
  }

  @override
  bool shouldRepaint(_MarkPainter old) =>
      old.glyph != glyph || old.argb != argb;
}

/// A measurer that THROWS rather than one that returns zeroes.
///
/// A device mark is a path and nothing else, so the replay never asks for
/// text metrics. If that ever stops being true, a measurer answering
/// zeroes would lay the text out at the origin and draw something plausibly
/// wrong; this one fails on the frame the assumption breaks. It is the same
/// reasoning that put geometry here instead of a codepoint: the failure
/// that hurts is the one that still renders.
final class _NeverMeasures implements TextMeasurer {
  const _NeverMeasures();

  @override
  TextMetrics measureText(String text, TextStyleSpec style) => throw StateError(
    'DeviceGlyphMark replayed a TEXT op. The mark is geometry only '
    '(DR-059 §11.58.4); if it has gained a label, this widget needs a '
    'real measurer injected rather than this guard removed.',
  );
}
