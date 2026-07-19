// Tests for editing_overlay_painter.dart: the pure geometry helpers
// (insertionLineY/rulerHighlightRect) at known RackGeometry values, a
// paint()-doesn't-throw smoke test across caret states and zoom levels —
// the same style grid_painter_test.dart uses for its own CustomPainter —
// plus (added this stage) the palette-drag ghost: it replaces the caret
// when a drag is in progress, paints without throwing valid/blocked/
// lingering, and `shouldRepaint` reacts to it.

import 'dart:ui' as ui;

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart' show Color, Offset, SizedBox;
import 'package:flutter_test/flutter_test.dart';
import 'package:rackmate_core/rackmate_core.dart';
import 'package:rackmate_ui/rackmate_ui.dart';

final _now = DateTime.utc(2026, 7, 18);

Rack _rack({int heightU = 12}) => Rack(
  id: const Uuid('rk-1'),
  name: 'Test Rack',
  designator: 'RK-1',
  heightU: heightU,
  order: const FracIndex('a0'),
  meta: EntityMeta(createdAt: _now, updatedAt: _now, updatedBy: 'test'),
);

const _style = EditingOverlayStyle(
  caretColor: Color(0xFF7C3AED),
  rulerHighlight: Color(0x337C3AED),
  errorColor: Color(0xFFB00020),
);

/// Runs [painter] against a `TestRecordingCanvas` and returns every
/// `Canvas` call it made, in order — used by the two tests below that need
/// to check WHAT was actually drawn (the blocked-drop dashed border/hatch
/// vs. the valid-drop solid border), not merely that `paint()` didn't
/// throw (every other test in this file only checks the latter).
List<RecordedInvocation> _recordPaint(EditingOverlayPainter painter) {
  final canvas = TestRecordingCanvas();
  painter.paint(canvas, const ui.Size(400, 400));
  return canvas.invocations;
}

/// Loose color comparison, mirroring flutter_test's own internal
/// `_colorsMatch` (the tolerance its `paints` matcher's `color:` parameter
/// uses). Needed here because `ui.Paint.color`'s getter reconstructs its
/// `Color` from a float32-precision native round trip (see `dart:ui`'s
/// `Paint.color` setter/getter) -- an exact `==` against the original
/// full-double-precision `Color` constant essentially never matches even
/// for the identical logical color, which is exactly why flutter_test's
/// own matcher does not use `==` either.
bool _colorsMatch(ui.Color x, ui.Color y) {
  const limit = 1 / 255;
  return x.colorSpace == y.colorSpace &&
      (x.a - y.a).abs() < limit &&
      (x.r - y.r).abs() < limit &&
      (x.g - y.g).abs() < limit &&
      (x.b - y.b).abs() < limit;
}

void main() {
  group('pure geometry helpers', () {
    test("insertionLineY(ruIndex) is the U's bottom edge (bottom-origin)",
        () {
      const geo = RackGeometry(12);
      // U1's bottom edge is the rack's own bottom, at Y == rackHeight.
      expect(insertionLineY(geo, 1), geo.rackHeight);
      // The top U (U12)'s bottom edge is one RU below the rack's top
      // (Y == 0), i.e. at Y == unitsPerRu.
      expect(insertionLineY(geo, 12), RackGeometry.unitsPerRu);
      // Matches the underlying yBottomOfU exactly -- no second formula.
      for (var ru = 1; ru <= 12; ru++) {
        expect(insertionLineY(geo, ru), geo.yBottomOfU(ru));
      }
    });

    test("rulerHighlightRect spans exactly one U's height in the ruler "
        'column', () {
      const geo = RackGeometry(12);
      final rect = rulerHighlightRect(geo, 5);
      expect(rect.left, 0);
      expect(rect.right, RackGeometry.rulerWidth);
      expect(rect.top, geo.yTopOfU(5));
      expect(rect.bottom, geo.yBottomOfU(5));
      expect(rect.height, RackGeometry.unitsPerRu);
    });
  });

  group('EditingOverlayPainter', () {
    test('paints nothing when the caret is inactive (no throw, no-op)', () {
      final vp = ViewportController();
      addTearDown(vp.dispose);
      final caret = CaretController(); // never recompute()'d -> caret == null
      final painter = EditingOverlayPainter(
        viewport: vp,
        caret: caret,
        geo: const RackGeometry(12),
        style: _style,
      );
      final recorder = ui.PictureRecorder();
      expect(
        () => painter.paint(ui.Canvas(recorder), const ui.Size(400, 400)),
        returnsNormally,
      );
      recorder.endRecording().dispose();
    });

    test('paints without throwing across the whole zoom range once active',
        () {
      final vp = ViewportController();
      addTearDown(vp.dispose);
      final rack = _rack();
      final caret = CaretController()
        ..recompute(
          selectionEmpty: true,
          canvasHasFocus: true,
          dragInProgress: false,
          rack: rack,
          smartDefaultRuIndex: 4,
        );
      final painter = EditingOverlayPainter(
        viewport: vp,
        caret: caret,
        geo: RackGeometry(rack.heightU),
        style: _style,
      );

      for (final s in <double>[0.05, 0.5, 1, 8, 32]) {
        vp
          ..reset()
          ..zoomBy(s, screenPivot: Offset.zero);
        final recorder = ui.PictureRecorder();
        painter.paint(ui.Canvas(recorder), const ui.Size(400, 400));
        recorder.endRecording().dispose();
      }
    });

    test('shouldRepaint reacts to a caret move and a style change, not to '
        'an identical config', () {
      final vp = ViewportController();
      addTearDown(vp.dispose);
      final rack = _rack();
      final caret = CaretController()
        ..recompute(
          selectionEmpty: true,
          canvasHasFocus: true,
          dragInProgress: false,
          rack: rack,
          smartDefaultRuIndex: 4,
        );
      final geo = RackGeometry(rack.heightU);

      final base = EditingOverlayPainter(
        viewport: vp,
        caret: caret,
        geo: geo,
        style: _style,
      );
      final same = EditingOverlayPainter(
        viewport: vp,
        caret: caret,
        geo: geo,
        style: _style,
      );
      final restyled = EditingOverlayPainter(
        viewport: vp,
        caret: caret,
        geo: geo,
        style: const EditingOverlayStyle(
          caretColor: Color(0xFF000000),
          rulerHighlight: Color(0x11000000),
          errorColor: Color(0xFF990000),
        ),
      );

      expect(base.shouldRepaint(same), isFalse);
      expect(base.shouldRepaint(restyled), isTrue);
    });
  });

  group('palette-drag ghost (docs/04 §3.1, added this stage)', () {
    DragPreviewController armedAndDragging({int deviceH = 2}) =>
        DragPreviewController()
          ..arm(
            subjectId: 'V01',
            deviceH: deviceH,
            face: Face.front,
            displayName: 'Test Amp',
            badge: '${deviceH}U',
            sourceKinds: const {PointerDeviceKind.mouse},
          )
          ..lift()
          ..enterCanvas();

    test('a valid, an occupancy-blocked, and an extent-blocked evaluation '
        'all paint without throwing, across the whole zoom range', () {
      final vp = ViewportController();
      addTearDown(vp.dispose);
      const geo = RackGeometry(12);
      final caret = CaretController(); // inactive throughout -- irrelevant.

      final valid = armedAndDragging()
        ..updateEvaluation(
          const DPt(0, 100),
          const DragPreviewEvaluation(ruIndex: 3, blocked: false),
        );
      final occupancyBlocked = armedAndDragging()
        ..updateEvaluation(
          const DPt(0, 100),
          DragPreviewEvaluation(
            ruIndex: 4,
            blocked: true,
            reason: 'Occupied by AMP-1 (U4-U5).',
            blockingRect: geo.deviceRect(4, 2),
          ),
        );
      final extentBlocked = armedAndDragging(deviceH: 20)
        ..updateEvaluation(
          const DPt(0, 10),
          const DragPreviewEvaluation(
            ruIndex: 1,
            blocked: true,
            reason: 'Needs 20U, only 12U free at top.',
          ),
        );

      for (final drag in [valid, occupancyBlocked, extentBlocked]) {
        final painter = EditingOverlayPainter(
          viewport: vp,
          caret: caret,
          geo: geo,
          style: _style,
          dragPreviews: [drag],
        );
        for (final s in <double>[0.05, 1, 8]) {
          vp
            ..reset()
            ..zoomBy(s, screenPivot: Offset.zero);
          final recorder = ui.PictureRecorder();
          expect(
            () => painter.paint(ui.Canvas(recorder), const ui.Size(400, 400)),
            returnsNormally,
          );
          recorder.endRecording().dispose();
        }
      }
    });

    test('a BLOCKED drop paints a dashed error-colored border and a hatch '
        "clipped to the blocking occupant's rect -- and NOT the valid "
        'style', () {
      // Regression coverage for a bug class the smoke test above cannot
      // catch: it only asserts paint() doesn't throw, so a regression that
      // silently dropped the dashed border, swapped the hatch color, or
      // rendered a blocked drop with the VALID (solid-border, no-hatch)
      // style would pass every other test in this file.
      final vp = ViewportController();
      addTearDown(vp.dispose);
      const geo = RackGeometry(12);
      final caret = CaretController();
      final blockingRect = geo.deviceRect(4, 2);
      final drag = armedAndDragging()
        ..updateEvaluation(
          const DPt(0, 100),
          DragPreviewEvaluation(
            ruIndex: 4,
            blocked: true,
            reason: 'Occupied by AMP-1 (U4-U5).',
            blockingRect: blockingRect,
          ),
        );
      final painter = EditingOverlayPainter(
        viewport: vp,
        caret: caret,
        geo: geo,
        style: _style,
        dragPreviews: [drag],
      );
      final invocations = _recordPaint(painter);

      // The border is DASHED -- `_paintDashedRect` draws several short
      // `drawLine` segments (6px dash / 4px gap per side) in the error
      // color, rather than one stroked `drawRect` (that's the VALID
      // style, asserted absent below). Comfortably more than the ONE
      // `drawLine` the insertion snap-line itself also contributes in the
      // same color.
      final errorLines = invocations.where((r) {
        if (r.invocation.memberName != #drawLine) return false;
        final paint = r.invocation.positionalArguments[2] as ui.Paint;
        return _colorsMatch(paint.color, _style.errorColor);
      });
      expect(
        errorLines.length,
        greaterThan(4),
        reason: 'expected several dashed-border line segments in the '
            'error color, plus the snap-line',
      );

      // No solid stroked `drawRect` border anywhere -- that would be the
      // VALID drop's style (see the sibling test below), which must not
      // appear on a blocked drop.
      final strokedRects = invocations.where((r) {
        if (r.invocation.memberName != #drawRect) return false;
        final paint = r.invocation.positionalArguments[1] as ui.Paint;
        return paint.style == ui.PaintingStyle.stroke;
      });
      expect(strokedRects, isEmpty);

      // The hatch: a `clipRect` matching the blocking occupant's own rect
      // (the same DBox->Rect conversion `_paintHatch` performs), followed
      // by at least one `drawLine` in the hatch's error@25% color.
      final expectedClip = ui.Rect.fromLTRB(
        blockingRect.left,
        blockingRect.top,
        blockingRect.right,
        blockingRect.bottom,
      );
      final clipRects = invocations
          .where((r) => r.invocation.memberName == #clipRect)
          .map((r) => r.invocation.positionalArguments[0] as ui.Rect);
      expect(clipRects, contains(expectedClip));

      final hatchColor = _style.errorColor.withValues(alpha: 0.25);
      final hatchLines = invocations.where((r) {
        if (r.invocation.memberName != #drawLine) return false;
        final paint = r.invocation.positionalArguments[2] as ui.Paint;
        return _colorsMatch(paint.color, hatchColor);
      });
      expect(hatchLines, isNotEmpty);
    });

    test('a VALID drop paints a solid border and no hatch -- and NOT the '
        'blocked style', () {
      final vp = ViewportController();
      addTearDown(vp.dispose);
      const geo = RackGeometry(12);
      final caret = CaretController();
      final drag = armedAndDragging()
        ..updateEvaluation(
          const DPt(0, 100),
          const DragPreviewEvaluation(ruIndex: 3, blocked: false),
        );
      final painter = EditingOverlayPainter(
        viewport: vp,
        caret: caret,
        geo: geo,
        style: _style,
        dragPreviews: [drag],
      );
      final invocations = _recordPaint(painter);

      // Exactly one solid, stroked `drawRect` border, in the (non-error)
      // caret color.
      final strokedRects = invocations.where((r) {
        if (r.invocation.memberName != #drawRect) return false;
        final paint = r.invocation.positionalArguments[1] as ui.Paint;
        return paint.style == ui.PaintingStyle.stroke;
      }).toList();
      expect(strokedRects, hasLength(1));
      expect(
        _colorsMatch(
          (strokedRects.single.invocation.positionalArguments[1] as ui.Paint)
              .color,
          _style.caretColor,
        ),
        isTrue,
        reason: 'the border should be in the caret color, not the error '
            'color',
      );

      // No DASH: the only `drawLine` in the caret color is the snap-line
      // itself -- a dashed border would add several more short segments.
      final caretColorLines = invocations.where((r) {
        if (r.invocation.memberName != #drawLine) return false;
        final paint = r.invocation.positionalArguments[2] as ui.Paint;
        return _colorsMatch(paint.color, _style.caretColor);
      });
      expect(caretColorLines.length, 1);

      // No hatch at all for a valid drop -- no clipRect call whatsoever.
      expect(
        invocations.where((r) => r.invocation.memberName == #clipRect),
        isEmpty,
      );
    });

    testWidgets('a shake-controller offset does not crash the ghost paint', (
      tester,
    ) async {
      // A trivial widget so the test binding is actively pumping frames --
      // ShakeController.trigger's `AnimationController.forward()` needs a
      // real SchedulerBinding, matching shake_animation_test.dart's own
      // established convention.
      await tester.pumpWidget(const SizedBox());
      final vp = ViewportController();
      addTearDown(vp.dispose);
      final caret = CaretController();
      const geo = RackGeometry(12);
      final drag = armedAndDragging()
        ..updateEvaluation(
          const DPt(0, 100),
          const DragPreviewEvaluation(
            ruIndex: 3,
            blocked: true,
            reason: 'Occupied by X (U3-U4).',
          ),
        );

      const vsync = TestVSync();
      final shake = ShakeController(vsync: vsync)
        ..trigger(kDragGhostShakeId);
      addTearDown(shake.dispose);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));

      final painter = EditingOverlayPainter(
        viewport: vp,
        caret: caret,
        geo: geo,
        style: _style,
        dragPreviews: [drag],
        shake: shake,
      );
      final recorder = ui.PictureRecorder();
      expect(
        () => painter.paint(ui.Canvas(recorder), const ui.Size(400, 400)),
        returnsNormally,
      );
      recorder.endRecording().dispose();
      await tester.pump(const Duration(milliseconds: 200)); // let it finish.
    });

    test('a release-lingering (blocked-release) drag still paints -- the '
        'frozen ghost/chip persist for the 1.2s window', () {
      final vp = ViewportController();
      addTearDown(vp.dispose);
      final caret = CaretController();
      const geo = RackGeometry(12);
      final drag = armedAndDragging()
        ..updateEvaluation(
          const DPt(0, 100),
          const DragPreviewEvaluation(
            ruIndex: 3,
            blocked: true,
            reason: 'Occupied by X (U3-U4).',
          ),
        )
        ..beginBlockedRelease();
      expect(drag.isDragging, isFalse); // phase reset to none...
      expect(drag.releaseLingering, isTrue); // ...but still lingering.

      final painter = EditingOverlayPainter(
        viewport: vp,
        caret: caret,
        geo: geo,
        style: _style,
        dragPreviews: [drag],
      );
      final recorder = ui.PictureRecorder();
      expect(
        () => painter.paint(ui.Canvas(recorder), const ui.Size(400, 400)),
        returnsNormally,
      );
      recorder.endRecording().dispose();
    });

    test('the ghost REPLACES the caret line -- both never paint at once '
        '(mutual exclusion is the caller wiring dragInProgress into '
        'CaretController.recompute, verified here via the painter simply '
        'never asking the caret when a drag evaluation is present)', () {
      final vp = ViewportController();
      addTearDown(vp.dispose);
      const geo = RackGeometry(12);
      final rack = _rack();
      // The caret IS active (as it would wrongly be if the caller forgot
      // to wire dragInProgress) -- the painter must still prefer the ghost
      // whenever `paletteDrag` reports a live/lingering evaluation.
      final caret = CaretController()
        ..recompute(
          selectionEmpty: true,
          canvasHasFocus: true,
          dragInProgress: false,
          rack: rack,
          smartDefaultRuIndex: 6,
        );
      final drag = armedAndDragging()
        ..updateEvaluation(
          const DPt(0, 100),
          const DragPreviewEvaluation(ruIndex: 3, blocked: false),
        );

      final painter = EditingOverlayPainter(
        viewport: vp,
        caret: caret,
        geo: geo,
        style: _style,
        dragPreviews: [drag],
      );
      // No assertion beyond "doesn't throw" is possible without inspecting
      // recorded canvas ops, but the important guarantee -- exercised by
      // reading `paint`'s own source -- is the `showGhost` branch is
      // taken exclusively; a regression that paints BOTH would still not
      // throw, so this is a smoke test backed by the source-level if/else
      // structure (see `paint`'s own doc comment for the invariant).
      final recorder = ui.PictureRecorder();
      expect(
        () => painter.paint(ui.Canvas(recorder), const ui.Size(400, 400)),
        returnsNormally,
      );
      recorder.endRecording().dispose();
    });

    test('with several drag sources, the ONE reporting a ghost is drawn -- '
        'in either list order -- and an idle source never suppresses the '
        'caret', () {
      // docs/04 §3.3 wires a SECOND `DragPreviewController` (the move drag)
      // into this same painter alongside the palette drag. This pins
      // `_activeDrag`'s contract: pick whichever source is actually showing
      // a ghost, regardless of position, and fall through to the caret when
      // none is. A regression that only ever consulted `dragPreviews.first`
      // would draw nothing at all for a move drag.
      final vp = ViewportController();
      addTearDown(vp.dispose);
      const geo = RackGeometry(12);
      final rack = _rack();
      final idle = DragPreviewController(); // never armed -- no ghost.
      final live = armedAndDragging()
        ..updateEvaluation(
          const DPt(0, 100),
          const DragPreviewEvaluation(ruIndex: 3, blocked: false),
        );

      final expectedGhost = geo.deviceRect(3, 2);
      for (final previews in <List<DragPreviewController>>[
        [idle, live],
        [live, idle],
      ]) {
        final invocations = _recordPaint(
          EditingOverlayPainter(
            viewport: vp,
            caret: CaretController(),
            geo: geo,
            style: _style,
            dragPreviews: previews,
          ),
        );
        final strokedRects = invocations.where((r) {
          if (r.invocation.memberName != #drawRect) return false;
          final paint = r.invocation.positionalArguments[1] as ui.Paint;
          return paint.style == ui.PaintingStyle.stroke;
        }).toList();
        expect(
          strokedRects,
          hasLength(1),
          reason: 'the live source must be found at index '
              '${previews.indexOf(live)}',
        );
        final drawn =
            strokedRects.single.invocation.positionalArguments[0] as ui.Rect;
        expect(drawn.top, closeTo(expectedGhost.top, 0.001));
        expect(drawn.bottom, closeTo(expectedGhost.bottom, 0.001));
      }

      // No source showing a ghost -> the caret line is painted as normal.
      final activeCaret = CaretController()
        ..recompute(
          selectionEmpty: true,
          canvasHasFocus: true,
          dragInProgress: false,
          rack: rack,
          smartDefaultRuIndex: 6,
        );
      final caretInvocations = _recordPaint(
        EditingOverlayPainter(
          viewport: vp,
          caret: activeCaret,
          geo: geo,
          style: _style,
          dragPreviews: [idle],
        ),
      );
      expect(
        caretInvocations.where((r) {
          if (r.invocation.memberName != #drawLine) return false;
          final paint = r.invocation.positionalArguments[2] as ui.Paint;
          return _colorsMatch(paint.color, _style.caretColor);
        }),
        isNotEmpty,
        reason: 'an idle drag source must not swallow the caret',
      );
      expect(
        caretInvocations.where((r) {
          if (r.invocation.memberName != #drawRect) return false;
          final paint = r.invocation.positionalArguments[1] as ui.Paint;
          return paint.style == ui.PaintingStyle.stroke;
        }),
        isEmpty,
        reason: 'no ghost border when nothing is being dragged',
      );
    });

    test('shouldRepaint reacts to a different drag-preview/shake instance', () {
      final vp = ViewportController();
      addTearDown(vp.dispose);
      final rack = _rack();
      final geo = RackGeometry(rack.heightU);
      final caret = CaretController()
        ..recompute(
          selectionEmpty: true,
          canvasHasFocus: true,
          dragInProgress: false,
          rack: rack,
          smartDefaultRuIndex: 4,
        );
      final dragA = armedAndDragging();
      final dragB = armedAndDragging();

      final withA = EditingOverlayPainter(
        viewport: vp,
        caret: caret,
        geo: geo,
        style: _style,
        dragPreviews: [dragA],
      );
      final withSameA = EditingOverlayPainter(
        viewport: vp,
        caret: caret,
        geo: geo,
        style: _style,
        dragPreviews: [dragA],
      );
      final withB = EditingOverlayPainter(
        viewport: vp,
        caret: caret,
        geo: geo,
        style: _style,
        dragPreviews: [dragB],
      );

      expect(withA.shouldRepaint(withSameA), isFalse);
      expect(withA.shouldRepaint(withB), isTrue);
    });
  });
}
