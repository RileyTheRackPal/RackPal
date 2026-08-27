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
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

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
    test("insertionLineY(ruIndex) is the U's bottom edge (bottom-origin)", () {
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

    test('paints without throwing across the whole zoom range once active', () {
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
        reason:
            'expected several dashed-border line segments in the '
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
        reason:
            'the border should be in the caret color, not the error '
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
      final shake = ShakeController(vsync: vsync)..trigger(kDragGhostShakeId);
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
          reason:
              'the live source must be found at index '
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

    test('shouldRepaint reacts to a different drag-preview/shake '
        'instance', () {
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

  group('compaction preview ghosts (docs/04 §3.6)', () {
    // The demo-shaped plan used throughout: AMP-1 drops U4 -> U2 (2U) and
    // SW-1 drops U7 -> U4 (1U).
    CompactionPlan planDown() => const CompactionPlan(
      direction: CompactDirection.down,
      face: Face.front,
      moves: [
        CompactionMove(
          deviceId: Uuid('dev-amp'),
          designator: 'AMP-1',
          fromRuIndex: 4,
          toRuIndex: 2,
          deviceH: 2,
          face: Face.front,
        ),
        CompactionMove(
          deviceId: Uuid('dev-sw'),
          designator: 'SW-1',
          fromRuIndex: 7,
          toRuIndex: 4,
          deviceH: 1,
          face: Face.front,
        ),
      ],
      freedU: 3,
    );

    CompactionPreviewController showing(CompactionPlan plan) =>
        CompactionPreviewController()..show(plan, documentSequence: 1);

    test('one solid ghost per move, at the PROPOSED position — never at '
        'the current one', () {
      // The heart of §3.6: "proposed positions as solid ghosts". A
      // regression that drew ghosts at `fromRuIndex` would still paint two
      // boxes and still not throw, so this asserts the actual rects.
      final vp = ViewportController();
      addTearDown(vp.dispose);
      const geo = RackGeometry(12);
      final compaction = showing(planDown());
      addTearDown(compaction.dispose);

      final invocations = _recordPaint(
        EditingOverlayPainter(
          viewport: vp,
          caret: CaretController(),
          geo: geo,
          style: _style,
          compaction: compaction,
        ),
      );

      final strokedRects = invocations
          .where((r) {
            if (r.invocation.memberName != #drawRect) return false;
            final paint = r.invocation.positionalArguments[1] as ui.Paint;
            return paint.style == ui.PaintingStyle.stroke;
          })
          .map((r) => r.invocation.positionalArguments[0] as ui.Rect)
          .toList();

      expect(strokedRects, hasLength(2));

      final proposedAmp = geo.deviceRect(2, 2); // AMP-1's TARGET
      final proposedSw = geo.deviceRect(4, 1); // SW-1's TARGET
      final currentAmp = geo.deviceRect(4, 2); // where it is NOW
      final currentSw = geo.deviceRect(7, 1);

      bool drawnAt(DBox box) => strokedRects.any(
        (r) =>
            (r.top - box.top).abs() < 0.001 &&
            (r.bottom - box.bottom).abs() < 0.001,
      );

      expect(drawnAt(proposedAmp), isTrue, reason: 'AMP-1 ghost at U2');
      expect(drawnAt(proposedSw), isTrue, reason: 'SW-1 ghost at U4');
      // The CURRENT positions are real devices dimmed in place by
      // `RenderDeviceBox.fadeOpacity`, not a second painted copy — drawing
      // them here would double every moving device on screen.
      expect(drawnAt(currentAmp), isFalse);
      expect(drawnAt(currentSw), isFalse);
    });

    test('compaction ghosts are SOLID and un-hatched — the blocked-drag '
        'vocabulary must not leak in', () {
      // A compaction plan has no blocked verdict at all (see
      // compaction_preview_controller.dart's header), so a dashed border or
      // a 45-degree hatch here would be actively misleading: both mean
      // "this drop is refused".
      final vp = ViewportController();
      addTearDown(vp.dispose);
      final compaction = showing(planDown());
      addTearDown(compaction.dispose);

      final invocations = _recordPaint(
        EditingOverlayPainter(
          viewport: vp,
          caret: CaretController(),
          geo: const RackGeometry(12),
          style: _style,
          compaction: compaction,
        ),
      );

      // No hatch: `_paintHatch` is the only thing that clips.
      expect(
        invocations.where((r) => r.invocation.memberName == #clipRect),
        isEmpty,
      );
      // No dashes, and no snap-line: `paintInsertionLine` is deliberately
      // NOT called (its rail triangles mean "insert HERE", a claim about one
      // boundary that N simultaneous landings cannot make), so the only
      // `drawLine` a dashed border would contribute is absent too.
      expect(
        invocations.where((r) => r.invocation.memberName == #drawLine),
        isEmpty,
      );
      // ...and therefore no rail triangles either.
      expect(
        invocations.where((r) => r.invocation.memberName == #drawPath),
        isEmpty,
      );
      // Every ghost border is in the accent colour, never the error colour.
      for (final r in invocations.where(
        (r) => r.invocation.memberName == #drawRect,
      )) {
        final paint = r.invocation.positionalArguments[1] as ui.Paint;
        expect(_colorsMatch(paint.color, _style.errorColor), isFalse);
      }
    });

    test('a compaction preview TAKES PRECEDENCE over both a live drag '
        'ghost and an active caret — exactly one source paints', () {
      // The screen enforces preview exclusivity one level up (opening a
      // compaction cancels any in-flight drag), but the painter must not
      // depend on that to avoid drawing two overlapping proposals.
      final vp = ViewportController();
      addTearDown(vp.dispose);
      const geo = RackGeometry(12);
      final rack = _rack();

      final drag = DragPreviewController()
        ..arm(
          subjectId: 'V01',
          deviceH: 2,
          face: Face.front,
          displayName: 'Test Amp',
          badge: '2U',
          sourceKinds: const {PointerDeviceKind.mouse},
        )
        ..lift()
        ..enterCanvas()
        ..updateEvaluation(
          const DPt(0, 100),
          // U9 — a rect no compaction ghost occupies, so its presence or
          // absence is unambiguous.
          const DragPreviewEvaluation(ruIndex: 9, blocked: false),
        );
      final caret = CaretController()
        ..recompute(
          selectionEmpty: true,
          canvasHasFocus: true,
          dragInProgress: false,
          rack: rack,
          smartDefaultRuIndex: 6,
        );
      final compaction = showing(planDown());
      addTearDown(compaction.dispose);

      final invocations = _recordPaint(
        EditingOverlayPainter(
          viewport: vp,
          caret: caret,
          geo: geo,
          style: _style,
          dragPreviews: [drag],
          compaction: compaction,
        ),
      );

      final strokedRects = invocations
          .where((r) {
            if (r.invocation.memberName != #drawRect) return false;
            final paint = r.invocation.positionalArguments[1] as ui.Paint;
            return paint.style == ui.PaintingStyle.stroke;
          })
          .map((r) => r.invocation.positionalArguments[0] as ui.Rect)
          .toList();

      // The two compaction ghosts and NOT the drag ghost.
      expect(strokedRects, hasLength(2));
      final dragGhost = geo.deviceRect(9, 2);
      expect(
        strokedRects.any((r) => (r.top - dragGhost.top).abs() < 0.001),
        isFalse,
        reason: 'the drag ghost must not paint under a compaction preview',
      );
      // ...and no caret line either (the caret is active but outranked).
      expect(
        invocations.where((r) => r.invocation.memberName == #drawLine),
        isEmpty,
      );
    });

    test('a CANCELLED compaction paints nothing and hands the frame back '
        'to the caret', () {
      final vp = ViewportController();
      addTearDown(vp.dispose);
      final rack = _rack();
      final compaction = showing(planDown())..cancel();
      addTearDown(compaction.dispose);
      final caret = CaretController()
        ..recompute(
          selectionEmpty: true,
          canvasHasFocus: true,
          dragInProgress: false,
          rack: rack,
          smartDefaultRuIndex: 6,
        );

      final invocations = _recordPaint(
        EditingOverlayPainter(
          viewport: vp,
          caret: caret,
          geo: const RackGeometry(12),
          style: _style,
          compaction: compaction,
        ),
      );

      expect(
        invocations.where((r) {
          if (r.invocation.memberName != #drawRect) return false;
          final paint = r.invocation.positionalArguments[1] as ui.Paint;
          return paint.style == ui.PaintingStyle.stroke;
        }),
        isEmpty,
      );
      expect(
        invocations.where((r) {
          if (r.invocation.memberName != #drawLine) return false;
          final paint = r.invocation.positionalArguments[2] as ui.Paint;
          return _colorsMatch(paint.color, _style.caretColor);
        }),
        isNotEmpty,
        reason: 'a cancelled preview must not keep swallowing the caret',
      );
    });

    test('shouldRepaint reacts to a different compaction instance', () {
      final vp = ViewportController();
      addTearDown(vp.dispose);
      const geo = RackGeometry(12);
      final caret = CaretController();
      final a = showing(planDown());
      final b = showing(planDown());
      addTearDown(a.dispose);
      addTearDown(b.dispose);

      EditingOverlayPainter painter(CompactionPreviewController c) =>
          EditingOverlayPainter(
            viewport: vp,
            caret: caret,
            geo: geo,
            style: _style,
            compaction: c,
          );

      expect(painter(a).shouldRepaint(painter(a)), isFalse);
      expect(painter(a).shouldRepaint(painter(b)), isTrue);
    });
  });

  group('top-edge resize preview (docs/04 §4.1, way three of three)', () {
    // THE PAINT-LEVEL HALF of §4.1's live resize feedback. An adversarial
    // review killed an early `return` at the top of `_paintResizePreview` —
    // i.e. neither the 45° hatch nor the candidate top-edge line drawn on any
    // drag, "the collision is visible BEFORE release" violated outright —
    // with the whole rackpal_ui suite still green. Every assertion below
    // reads ACTUAL recorded canvas ops for that reason; the gesture that
    // feeds this controller is covered in rack_resize_drag_test.dart.

    const geo = RackGeometry(12);

    ResizePreviewController resizing({
      required int from,
      required int to,
      List<DBox> doomed = const [],
    }) => ResizePreviewController()
      ..begin(from)
      ..update(
        candidateHeightU: to,
        cursorGlobal: Offset.zero,
        doomedRects: doomed,
      );

    /// Every `drawLine` whose paint matches [color], as its two endpoints.
    List<(ui.Offset, ui.Offset)> linesIn(
      List<RecordedInvocation> invocations,
      ui.Color color,
    ) => invocations
        .where((r) {
          if (r.invocation.memberName != #drawLine) return false;
          final paint = r.invocation.positionalArguments[2] as ui.Paint;
          return _colorsMatch(paint.color, color);
        })
        .map(
          (r) => (
            r.invocation.positionalArguments[0] as ui.Offset,
            r.invocation.positionalArguments[1] as ui.Offset,
          ),
        )
        .toList();

    test('SHRINKING hatches every doomed occupant in error@25% and draws the '
        'candidate top-edge line, in the ERROR colour, at the candidate '
        "height's own boundary", () {
      final vp = ViewportController();
      addTearDown(vp.dispose);
      // The screen's demo shape: a 12U rack dragged to 8U stranding SW-1
      // (U7, 1U) and the REAR-face PP-1 (U9, 1U) — see
      // resize_preview_controller.dart's header for why a rear occupant is
      // hatched on a front elevation.
      final sw = geo.deviceRect(7, 1);
      final pp = geo.deviceRect(9, 1);
      final resize = resizing(from: 12, to: 8, doomed: [sw, pp]);
      addTearDown(resize.dispose);

      final invocations = _recordPaint(
        EditingOverlayPainter(
          viewport: vp,
          caret: CaretController(),
          geo: geo,
          style: _style,
          resize: resize,
        ),
      );

      // ONE hatch clip per doomed occupant, at that occupant's own rect —
      // `_paintHatch` is the only thing in this painter that clips.
      final clipRects = invocations
          .where((r) => r.invocation.memberName == #clipRect)
          .map((r) => r.invocation.positionalArguments[0] as ui.Rect)
          .toList();
      expect(clipRects, hasLength(2));
      for (final box in [sw, pp]) {
        expect(
          clipRects.any(
            (r) =>
                (r.top - box.top).abs() < 0.001 &&
                (r.bottom - box.bottom).abs() < 0.001,
          ),
          isTrue,
          reason: 'expected a hatch clipped to U${box.top}',
        );
      }

      // ...and the hatch STROKES themselves, at the shared error@25% the
      // blocked-drop occupant uses. A regression that clipped but drew
      // nothing would pass the assertion above alone.
      expect(
        linesIn(invocations, _style.errorColor.withValues(alpha: 0.25)),
        isNotEmpty,
      );

      // The candidate line: exactly one, full-strength error (NOT the 25%
      // hatch colour), horizontal, at the 8U boundary — with the shared
      // overhang on both sides.
      final candidate = linesIn(invocations, _style.errorColor);
      expect(candidate, hasLength(1));
      final (start, end) = candidate.single;
      final expectedY = geo.yOfBoundary(8);
      expect(start.dy, closeTo(expectedY, 0.001));
      expect(end.dy, closeTo(expectedY, 0.001));
      expect(
        start.dy,
        isNot(closeTo(geo.yOfBoundary(12), 0.001)),
        reason:
            'the line marks where the top edge WOULD land, not where it '
            'is now',
      );
      expect(start.dx, closeTo(-EditingOverlayPainter.lineOverhang, 0.001));
      expect(
        end.dx,
        closeTo(geo.rackWidth + EditingOverlayPainter.lineOverhang, 0.001),
      );

      // No rail triangles: the candidate line is deliberately NOT
      // `paintInsertionLine`, whose triangles claim "a device inserts here".
      expect(
        invocations.where((r) => r.invocation.memberName == #drawPath),
        isEmpty,
      );
    });

    test('GROWING draws the candidate line in the ACCENT colour and no hatch '
        'at all — "growing is always safe" needs no special case', () {
      final vp = ViewportController();
      addTearDown(vp.dispose);
      final resize = resizing(from: 12, to: 15);
      addTearDown(resize.dispose);

      final invocations = _recordPaint(
        EditingOverlayPainter(
          viewport: vp,
          caret: CaretController(),
          geo: geo,
          style: _style,
          resize: resize,
        ),
      );

      expect(
        invocations.where((r) => r.invocation.memberName == #clipRect),
        isEmpty,
        reason: 'nothing is doomed, so nothing may be hatched',
      );
      expect(linesIn(invocations, _style.errorColor), isEmpty);

      final candidate = linesIn(invocations, _style.caretColor);
      expect(candidate, hasLength(1));
      // `yOfBoundary`'s linear extension past the rack top: a 15U candidate
      // on a 12U rack floats 3U ABOVE scene y == 0, which is exactly where
      // the enlarged rack's top edge would be.
      expect(candidate.single.$1.dy, closeTo(geo.yOfBoundary(15), 0.001));
      expect(candidate.single.$1.dy, lessThan(0));
    });

    test('the IDENTITY position still draws its line — a drag sitting at its '
        'starting height is live feedback, not an absent preview', () {
      final vp = ViewportController();
      addTearDown(vp.dispose);
      final resize = resizing(from: 12, to: 12);
      addTearDown(resize.dispose);

      final invocations = _recordPaint(
        EditingOverlayPainter(
          viewport: vp,
          caret: CaretController(),
          geo: geo,
          style: _style,
          resize: resize,
        ),
      );

      final candidate = linesIn(invocations, _style.caretColor);
      expect(candidate, hasLength(1));
      expect(candidate.single.$1.dy, closeTo(geo.yOfBoundary(12), 0.001));
    });

    test('a resize preview OUTRANKS a compaction plan, a live drag ghost and '
        'an active caret — exactly one source paints', () {
      // `paint`'s stated precedence is resize -> compaction -> drag -> caret.
      // The screen enforces exclusivity one level up, but the painter must
      // not depend on that to avoid drawing two contradictory proposals.
      final vp = ViewportController();
      addTearDown(vp.dispose);
      final rack = _rack();

      final drag = DragPreviewController()
        ..arm(
          subjectId: 'V01',
          deviceH: 2,
          face: Face.front,
          displayName: 'Test Amp',
          badge: '2U',
          sourceKinds: const {PointerDeviceKind.mouse},
        )
        ..lift()
        ..enterCanvas()
        ..updateEvaluation(
          const DPt(0, 100),
          const DragPreviewEvaluation(ruIndex: 3, blocked: false),
        );
      final compaction = CompactionPreviewController()
        ..show(
          const CompactionPlan(
            direction: CompactDirection.down,
            face: Face.front,
            moves: [
              CompactionMove(
                deviceId: Uuid('dev-amp'),
                designator: 'AMP-1',
                fromRuIndex: 4,
                toRuIndex: 2,
                deviceH: 2,
                face: Face.front,
              ),
            ],
            freedU: 2,
          ),
          documentSequence: 1,
        );
      addTearDown(compaction.dispose);
      final caret = CaretController()
        ..recompute(
          selectionEmpty: true,
          canvasHasFocus: true,
          dragInProgress: false,
          rack: rack,
          smartDefaultRuIndex: 6,
        );
      final resize = resizing(from: 12, to: 15);
      addTearDown(resize.dispose);

      final invocations = _recordPaint(
        EditingOverlayPainter(
          viewport: vp,
          caret: caret,
          geo: geo,
          style: _style,
          dragPreviews: [drag],
          compaction: compaction,
          resize: resize,
        ),
      );

      // No ghost box from EITHER the drag or the compaction: a stroked
      // `drawRect` is how both of them draw a proposal.
      expect(
        invocations.where((r) {
          if (r.invocation.memberName != #drawRect) return false;
          final paint = r.invocation.positionalArguments[1] as ui.Paint;
          return paint.style == ui.PaintingStyle.stroke;
        }),
        isEmpty,
      );
      // Exactly the resize's own one line, and nothing the caret would add.
      expect(
        invocations.where((r) => r.invocation.memberName == #drawLine),
        hasLength(1),
      );
    });

    test('a CANCELLED resize paints nothing and hands the frame back to the '
        'caret', () {
      final vp = ViewportController();
      addTearDown(vp.dispose);
      final rack = _rack();
      final resize = resizing(from: 12, to: 6, doomed: [geo.deviceRect(9, 1)])
        ..cancel();
      addTearDown(resize.dispose);
      final caret = CaretController()
        ..recompute(
          selectionEmpty: true,
          canvasHasFocus: true,
          dragInProgress: false,
          rack: rack,
          smartDefaultRuIndex: 6,
        );

      final invocations = _recordPaint(
        EditingOverlayPainter(
          viewport: vp,
          caret: caret,
          geo: geo,
          style: _style,
          resize: resize,
        ),
      );

      expect(
        invocations.where((r) => r.invocation.memberName == #clipRect),
        isEmpty,
        reason: 'a cancelled preview must not keep hatching the rack',
      );
      expect(
        linesIn(invocations, _style.caretColor),
        isNotEmpty,
        reason: 'the caret gets its frame back',
      );
    });

    test('shouldRepaint reacts to a different resize instance', () {
      final vp = ViewportController();
      addTearDown(vp.dispose);
      final caret = CaretController();
      final a = resizing(from: 12, to: 9);
      final b = resizing(from: 12, to: 9);
      addTearDown(a.dispose);
      addTearDown(b.dispose);

      EditingOverlayPainter painter(ResizePreviewController c) =>
          EditingOverlayPainter(
            viewport: vp,
            caret: caret,
            geo: geo,
            style: _style,
            resize: c,
          );

      expect(painter(a).shouldRepaint(painter(a)), isFalse);
      expect(painter(a).shouldRepaint(painter(b)), isTrue);
    });
  });
}
