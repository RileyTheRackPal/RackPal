// packages/rackmate_ui/lib/src/canvas/editing_overlay_painter.dart
//
// Ephemeral editing chrome painted ON TOP of the rack scene:
//  * the keyboard insertion caret (docs/04-rack-editor.md §3.4): "a 2px
//    accent line at a U boundary with a 6px triangle at each rail and the
//    ruler label highlighted."
//  * the drag ghost/snap-line/blocked-occupant hatch (docs/04 §3.1 steps
//    3-5) — the caret and the drag's snap indicator share ONE routine,
//    [paintInsertionLine], so they read as the same visual language
//    (docs/04 §3.1 step 4's snap line uses an identical extent to the
//    caret's own line) and are mutually exclusive by construction:
//    `CaretController.active` already factors in `!drag.isInProgress` (see
//    insertion_caret.dart), so [paint] only ever draws ONE of the two per
//    frame — never both.
//
// The ghost is drawn from a `DragPreviewController`, which is deliberately
// NOT palette-specific: docs/04 §3.3 step 3 ("Moving a placed device")
// says the move gesture uses the "same blocked rendering as §3.1", so BOTH
// gestures feed this one painter through [dragPreviews]. At most one of
// them can be showing a ghost on any given frame (a pointer can only drive
// one drag at a time), which [_activeDrag] asserts by construction: it
// takes the first source reporting `isShowingGhost` and ignores the rest.
//
// Scene-space, mirroring GridPainter's viewport-transform replay pattern
// (grid_painter.dart): `canvas.transform(viewport.transform.storage)`,
// draw everything in scene units, then divide nominal "px" sizes by
// `viewport.scale` before stroking/measuring so "2px line" / "6px
// triangle" / "1.5px border" stay constant SCREEN pixels regardless of
// zoom — the same compensation GridPainter already applies to its
// hairlines (`strokeWidth = style.minorWidth / repScale`). The one
// exception, flagged rather than silently inconsistent: the blocked-
// occupant hatch's line spacing is a flat scene-unit constant, so it
// scales with zoom exactly like `RenderDeviceBox`'s existing hover/focus/
// selected rings do (a pre-existing inconsistency this file does not fix,
// per that design's own OPEN RISKS note).
//
// This chrome is never baked into the shared `DiagramScene` IR, per the
// established precedent that ephemeral UI chrome is UI-side paint
// (RenderDeviceBox's hover/focus/selection rings, painted the same way).
// `EditingOverlayPainter` takes plain `dart:ui` `Color`s rather than
// core's packed-ARGB `RackPalette`, since — unlike the scene builder —
// this file is UI-only and never runs on the Flutter-free core side.

import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart' show CustomPainter;
import 'package:rackmate_core/rackmate_core.dart';
import 'package:rackmate_ui/src/canvas/drag_preview_controller.dart';
import 'package:rackmate_ui/src/canvas/insertion_caret.dart';
import 'package:rackmate_ui/src/canvas/shake_animation.dart';
import 'package:rackmate_ui/src/canvas/viewport_controller.dart';

/// Colours [EditingOverlayPainter] draws with.
@immutable
class EditingOverlayStyle {
  const EditingOverlayStyle({
    required this.caretColor,
    required this.rulerHighlight,
    required this.errorColor,
  });

  /// The caret line + rail-triangle colour (an accent distinct from the
  /// device hover/focus/selection colours, since the caret only ever
  /// shows when nothing is selected — see `RackCanvasScreen._rackPalette`
  /// for the device-chrome equivalents). Also the VALID-drop palette-drag
  /// ghost's fill/border/snap-line colour (docs/04 §3.1 step 3: "fill
  /// accent@12%, 1.5px solid accent border").
  final ui.Color caretColor;

  /// Ruler-label highlight tint, painted OVER the ruler cell the chassis
  /// fragment already drew (accent@~20%, per docs/04 §3.4's rendering
  /// intent) — a translucent tint band rather than a bold/inverted redraw
  /// of the actual number, which would require re-implementing the
  /// chassis fragment's own ruler text layout a second time; deferred as
  /// a visual-polish nicety (see docs/m1-implementation-log.md).
  final ui.Color rulerHighlight;

  /// The BLOCKED-drop palette-drag ghost's fill/border/snap-line/hatch
  /// colour (docs/04 §3.1 step 5: "Ghost fill -> error@12%, border ->
  /// 1.5px dashed error, the conflicting occupant gets a 45-degree hatch
  /// at error@25%"), added this stage.
  final ui.Color errorColor;

  @override
  bool operator ==(Object other) =>
      other is EditingOverlayStyle &&
      other.caretColor == caretColor &&
      other.rulerHighlight == rulerHighlight &&
      other.errorColor == errorColor;

  @override
  int get hashCode => Object.hash(caretColor, rulerHighlight, errorColor);
}

/// The scene-space Y of the insertion line for [ruIndex] — exactly a
/// future device's bottom edge if placed at the caret (see
/// `InsertionCaret.ruIndex`'s doc comment). Factored out as a pure,
/// widget-free function so geometry tests don't need a `ui.Canvas`.
double insertionLineY(RackGeometry geo, int ruIndex) => geo.yBottomOfU(ruIndex);

/// The scene-space rect of the ruler-label cell for [ruIndex] — the
/// region [EditingOverlayPainter] tints to highlight the caret's row.
ui.Rect rulerHighlightRect(RackGeometry geo, int ruIndex) => ui.Rect.fromLTRB(
  0,
  geo.yTopOfU(ruIndex),
  RackGeometry.rulerWidth,
  geo.yBottomOfU(ruIndex),
);

/// Paints the insertion caret AND the drag ghost/snap-line/blocked-occupant
/// hatch (docs/04 §3.1 for the palette gesture, §3.3 step 3 for the
/// move-a-placed-device gesture — one implementation, both surfaces).
/// `IgnorePointer`-wrapped by the caller — purely visual, never a hit
/// target.
class EditingOverlayPainter extends CustomPainter {
  EditingOverlayPainter({
    required this.viewport,
    required this.caret,
    required this.geo,
    required this.style,
    this.dragPreviews = const [],
    this.shake,
  }) : super(
         repaint: Listenable.merge([
           viewport,
           caret,
           ...dragPreviews,
           if (shake != null) shake,
         ]),
       );

  final ViewportController viewport;
  final CaretController caret;
  final RackGeometry geo;
  final EditingOverlayStyle style;

  /// Every drag-preview source that may want a ghost drawn — the palette
  /// drag (docs/04 §3.1) and the move drag (§3.3) in `RackCanvasScreen`;
  /// empty for hosts that never drag at all (e.g. most of this file's own
  /// unit tests). At most one can report [DragPreviewController
  /// .isShowingGhost] on a given frame, and that one's ghost/snap-line/
  /// hatch REPLACE the caret line for that frame — never both (see the
  /// file header).
  ///
  /// A list rather than two named fields precisely because this painter
  /// has no business knowing WHICH gesture is driving it: it renders "a
  /// drag preview", which is the whole reason §3.3's blocked rendering is
  /// literally, not approximately, the same as §3.1's.
  final List<DragPreviewController> dragPreviews;

  /// The shared blocked-feedback shake (docs/04 §3.1 step 5/6: "Release
  /// while blocked is a no-op with a 120ms shake"), reused for the ghost
  /// exactly as `RenderDeviceBox` reuses it for a real device — see
  /// `drag_preview_controller.dart`'s `kDragGhostShakeId` doc comment.
  final ShakeController? shake;

  /// The one drag source (if any) whose ghost this frame belongs to.
  DragPreviewController? get _activeDrag {
    for (final drag in dragPreviews) {
      if (drag.isShowingGhost) return drag;
    }
    return null;
  }

  /// Nominal screen-constant sizes (docs/04 §3.4), divided by the viewport
  /// scale before stroking — see the file header.
  static const double lineWidthPx = 2;
  static const double triangleSizePx = 6;
  static const double ghostBorderWidthPx = 1.5;

  /// How far the caret line extends past the ruler / right rail, matching
  /// the drag snap-line's own stated extent (docs/04 §3.1 step 4: "12px
  /// into the ruler and 12px past the far rail") so the two read as one
  /// visual language.
  static const double lineOverhang = 12;

  /// Scene-unit spacing between the blocked-occupant hatch's 45-degree
  /// lines (docs/04 §3.1 step 5) — a flat scene constant, so (like
  /// `RenderDeviceBox`'s existing hover/focus/selected rings, not this
  /// painter's OTHER strokes) it scales with zoom; see the file header.
  static const double hatchSpacing = 10;

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    final scale = viewport.scale;
    if (scale <= 0) return;

    final drag = _activeDrag;
    // Non-null exactly when `drag != null` — `isShowingGhost` already
    // requires an evaluation, so this is a type narrowing, not a second
    // (drift-prone) condition.
    final evaluation = drag?.evaluation;

    canvas
      ..save()
      ..transform(viewport.transform.storage);
    if (drag != null && evaluation != null) {
      _paintGhost(canvas, drag, evaluation, scale);
    } else {
      final active = caret.caret;
      if (active != null) {
        _paintRulerHighlight(canvas, active.ruIndex);
        paintInsertionLine(
          canvas,
          geo,
          active.ruIndex,
          style.caretColor,
          scale,
        );
      }
    }
    canvas.restore();
  }

  void _paintRulerHighlight(ui.Canvas canvas, int ruIndex) {
    canvas.drawRect(
      rulerHighlightRect(geo, ruIndex),
      ui.Paint()..color = style.rulerHighlight,
    );
  }

  /// The drag ghost (docs/04 §3.1 steps 3-5, and §3.3 step 3's "same
  /// blocked rendering"): fill + border (solid accent when valid, dashed
  /// error when blocked) at the snapped RU, the shared snap-line, and —
  /// when blocked by an occupant (not an extent overflow) — a 45-degree
  /// hatch clipped to that occupant's own rect.
  void _paintGhost(
    ui.Canvas canvas,
    DragPreviewController drag,
    DragPreviewEvaluation evaluation,
    double scale,
  ) {
    final color = evaluation.blocked ? style.errorColor : style.caretColor;
    final rect = geo.deviceRect(evaluation.ruIndex, drag.deviceH);
    final shakeOffset = shake?.offsetFor(kDragGhostShakeId);
    final dx = shakeOffset?.dx ?? 0;
    final drawRect = ui.Rect.fromLTRB(
      rect.left + dx,
      rect.top,
      rect.right + dx,
      rect.bottom,
    );

    canvas.drawRect(
      drawRect,
      ui.Paint()..color = color.withValues(alpha: 0.12),
    );

    final borderPaint = ui.Paint()
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = ghostBorderWidthPx / scale
      ..color = color
      ..isAntiAlias = true;
    if (evaluation.blocked) {
      _paintDashedRect(canvas, drawRect, borderPaint);
    } else {
      canvas.drawRect(drawRect, borderPaint);
    }

    paintInsertionLine(canvas, geo, evaluation.ruIndex, color, scale);

    final blockingRect = evaluation.blockingRect;
    if (evaluation.blocked && blockingRect != null) {
      _paintHatch(
        canvas,
        blockingRect,
        style.errorColor.withValues(alpha: 0.25),
      );
    }
  }

  /// A simple dashed-rectangle stroke for the blocked ghost's border
  /// (docs/04 §3.1 step 5: "border -> 1.5px dashed error").
  static void _paintDashedRect(ui.Canvas canvas, ui.Rect rect, ui.Paint paint) {
    const dash = 6.0;
    const gap = 4.0;
    void dashedLine(ui.Offset a, ui.Offset b) {
      final total = (b - a).distance;
      if (total <= 0) return;
      final dir = (b - a) / total;
      var travelled = 0.0;
      while (travelled < total) {
        final rawEnd = travelled + dash;
        final segEnd = rawEnd > total ? total : rawEnd;
        canvas.drawLine(a + dir * travelled, a + dir * segEnd, paint);
        travelled += dash + gap;
      }
    }

    dashedLine(rect.topLeft, rect.topRight);
    dashedLine(rect.topRight, rect.bottomRight);
    dashedLine(rect.bottomRight, rect.bottomLeft);
    dashedLine(rect.bottomLeft, rect.topLeft);
  }

  /// 45-degree hatch lines clipped to [rect] (docs/04 §3.1 step 5: "the
  /// conflicting occupant gets a 45-degree hatch at error@25%").
  static void _paintHatch(ui.Canvas canvas, DBox rect, ui.Color color) {
    final r = ui.Rect.fromLTRB(rect.left, rect.top, rect.right, rect.bottom);
    canvas
      ..save()
      ..clipRect(r);
    final paint = ui.Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..isAntiAlias = true;
    final span = r.width + r.height;
    for (var o = -r.height; o < span; o += hatchSpacing) {
      final x0 = r.left + o;
      canvas.drawLine(
        ui.Offset(x0, r.top),
        ui.Offset(x0 + r.height, r.bottom),
        paint,
      );
    }
    canvas.restore();
  }

  /// The shared insertion-line routine — drawn for the keyboard caret AND
  /// the drag snap-line (accent while a valid drop target, error while
  /// blocked), so both read as the same visual language. A top-level
  /// function (not a painter method) so a caller can invoke it without
  /// depending on this painter's own `caret`/`viewport` fields.
  static void paintInsertionLine(
    ui.Canvas canvas,
    RackGeometry geo,
    int ruIndex,
    ui.Color color,
    double scale,
  ) {
    final y = insertionLineY(geo, ruIndex);
    final left = -lineOverhang;
    final right = geo.rackWidth + lineOverhang;
    final lineWidth = lineWidthPx / scale;

    canvas.drawLine(
      ui.Offset(left, y),
      ui.Offset(right, y),
      ui.Paint()
        ..color = color
        ..strokeWidth = lineWidth
        ..style = ui.PaintingStyle.stroke
        ..isAntiAlias = true,
    );

    final triSize = triangleSizePx / scale;
    final fillPaint = ui.Paint()
      ..color = color
      ..style = ui.PaintingStyle.fill
      ..isAntiAlias = true;
    _paintRailTriangle(
      canvas,
      centerX: geo.railLeft + RackGeometry.railWidth / 2,
      y: y,
      size: triSize,
      pointRight: true,
      paint: fillPaint,
    );
    _paintRailTriangle(
      canvas,
      centerX: geo.rightRailLeft + RackGeometry.railWidth / 2,
      y: y,
      size: triSize,
      pointRight: false,
      paint: fillPaint,
    );
  }

  /// One small triangle centred on a rail, tip pointing toward the rack's
  /// interior (`pointRight` for the left rail, `!pointRight` for the
  /// right) so the pair reads as "pointing at" the insertion line between
  /// them.
  static void _paintRailTriangle(
    ui.Canvas canvas, {
    required double centerX,
    required double y,
    required double size,
    required bool pointRight,
    required ui.Paint paint,
  }) {
    final tipX = pointRight ? centerX + size / 2 : centerX - size / 2;
    final baseX = pointRight ? centerX - size / 2 : centerX + size / 2;
    final path = ui.Path()
      ..moveTo(tipX, y)
      ..lineTo(baseX, y - size / 2)
      ..lineTo(baseX, y + size / 2)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant EditingOverlayPainter old) =>
      viewport != old.viewport ||
      caret != old.caret ||
      geo != old.geo ||
      style != old.style ||
      !listEquals(dragPreviews, old.dragPreviews) ||
      shake != old.shake;
}
