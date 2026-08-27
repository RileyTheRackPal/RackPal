// The only way to draw a severity. DR-090 §11.89.6, board #774.
//
// ═════════════════════════════════════════════════════════════════════
// A RULE THAT IS ENFORCED BY CONSTRUCTION, NOT BY REVIEW
// ═════════════════════════════════════════════════════════════════════
// §11.89.6: a status colour may appear anywhere, PROVIDED the marker
// carries a second cue that survives the colour being removed. A bare
// coloured dot is not a status marker.
//
// The obvious gate is a check over the display list, and `#774` was filed
// expecting one. It would be VACUOUS: nothing in this project draws a
// status marker yet, so a gate counting bad ones would count zero and
// pass forever. A gate whose subject does not exist is the shape this
// repository keeps finding in its own suite.
//
// So the rule is made structural instead. `ConsoleStatus` already refuses
// to hand out a fill without the ink that belongs on it; this refuses to
// hand out a fill without a SHAPE. There is no constructor here that
// takes a colour and draws a rectangle, and
// `status_marker_source_test.dart` checks that `ConsoleStatus.fill` is
// not reached anywhere else, so the bypass is gated even though the rule
// itself cannot be.
//
// ═════════════════════════════════════════════════════════════════════
// THE FIVE SHAPES, AND WHY CRITICAL IS NOT AN OCTAGON
// ═════════════════════════════════════════════════════════════════════
// The conventional severity octagon reads as a CIRCLE below about 24 px,
// and Notice is already a circle, so at the sizes this product uses the
// two most different severities would have been the two hardest to tell
// apart. Critical is an X: unmistakable at any size, and the one mark
// nobody reads as anything else.
//
// The set is checked pairwise at one colour by `status_marker_test.dart`,
// which is the rule stated as an assertion: delete the colour and the
// five must still differ.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:rackpal_ui/src/theme/console_theme.dart';

/// The shape a severity carries, which is its cue when the colour is gone.
enum StatusShape { cross, triangle, diamond, circle, check }

/// Which shape belongs to which severity.
///
/// A FUNCTION RATHER THAN A FIELD ON `ConsoleStatus`, because that enum
/// lives beside the palette and knows nothing about painting. The mapping
/// is total by the switch's own exhaustiveness: a sixth severity will not
/// compile until it has a shape.
StatusShape shapeFor(ConsoleStatus status) => switch (status) {
  ConsoleStatus.critical => StatusShape.cross,
  ConsoleStatus.warning => StatusShape.triangle,
  ConsoleStatus.caution => StatusShape.diamond,
  ConsoleStatus.notice => StatusShape.circle,
  ConsoleStatus.nominal => StatusShape.check,
};

/// Paints one [StatusShape] inside its box.
///
/// PUBLIC so the test can paint the five at one colour and compare them.
/// A private painter would have forced the test to go through a widget
/// and a `RenderObject` to ask a question about geometry.
@immutable
class StatusShapePainter extends CustomPainter {
  const StatusShapePainter({required this.shape, required this.color});

  final StatusShape shape;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    final fill = Paint()..color = color;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(2, s * 0.16)
      ..strokeCap = StrokeCap.square;

    switch (shape) {
      case StatusShape.cross:
        canvas
          ..drawLine(Offset(s * .14, s * .14), Offset(s * .86, s * .86), stroke)
          ..drawLine(
            Offset(s * .86, s * .14),
            Offset(s * .14, s * .86),
            stroke,
          );
      case StatusShape.triangle:
        canvas.drawPath(
          Path()
            ..moveTo(s / 2, 0)
            ..lineTo(s, s)
            ..lineTo(0, s)
            ..close(),
          fill,
        );
      case StatusShape.diamond:
        canvas.drawPath(
          Path()
            ..moveTo(s / 2, 0)
            ..lineTo(s, s / 2)
            ..lineTo(s / 2, s)
            ..lineTo(0, s / 2)
            ..close(),
          fill,
        );
      case StatusShape.circle:
        // OUTLINE, not filled: the filled round mark is what a "bare
        // coloured dot" is, and this set must not contain the thing the
        // ruling forbids.
        canvas.drawCircle(
          Offset(s / 2, s / 2),
          s / 2 - stroke.strokeWidth / 2,
          stroke,
        );
      case StatusShape.check:
        canvas.drawPath(
          Path()
            ..moveTo(s * .16, s * .50)
            ..lineTo(s * .42, s * .78)
            ..lineTo(s * .86, s * .18),
          stroke..strokeJoin = StrokeJoin.round,
        );
    }
  }

  @override
  bool shouldRepaint(StatusShapePainter old) =>
      old.shape != shape || old.color != color;
}

/// A severity, drawn so that deleting its colour leaves it readable.
///
/// [label] is a third cue and is optional; the shape alone satisfies
/// §11.89.6, which names "a shape, an icon, a border, or a word" as
/// alternatives rather than as a set to be collected.
class StatusMarker extends StatelessWidget {
  const StatusMarker(this.status, {this.label, this.size = 16, super.key});

  final ConsoleStatus status;
  final String? label;
  final double size;

  @override
  Widget build(BuildContext context) {
    final text = label;
    final mark = SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: StatusShapePainter(
          shape: shapeFor(status),
          color: status.fill,
        ),
      ),
    );
    if (text == null) return Semantics(label: status.name, child: mark);
    return Semantics(
      // THE SEVERITY IS IN THE SEMANTICS whatever the label says, because
      // a screen reader is the one consumer for which every visual cue,
      // shape included, is deleted.
      label: '${status.name}: $text',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          mark,
          const SizedBox(width: 6),
          Text(text, style: TextStyle(color: status.fill)),
        ],
      ),
    );
  }
}
