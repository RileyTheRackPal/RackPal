// rackpal_ui/src/canvas/marquee_controller.dart — CR-102's band, as a
// gesture and as chrome (DR-139 §11.138, PLAN-E/6).
//
// ═══════════════════════════════════════════════════════════════════════
// ONE OF THESE, ADOPTED THREE TIMES, WHICH IS THE RULING'S CONTENT
// ═══════════════════════════════════════════════════════════════════════
// CR-102's whole claim is that the gesture is UNIFORM across views, so
// three separate implementations would be the ruling honoured in letter
// and abolished in substance (DR-139). The geometry is
// `rackpal_core/draw/marquee.dart`; what is here is the pointer state and
// the band, and each canvas contributes four lines: begin, update, commit,
// cancel.
//
// ═══════════════════════════════════════════════════════════════════════
// SCENE POINTS, NOT SCREEN POINTS, AND THAT IS NOT A DETAIL
// ═══════════════════════════════════════════════════════════════════════
// The controller stores where the drag started and where it is now in
// SCENE space, because `CanvasIntentHandler` reports scene points and
// because the band must stay over the same devices when the viewport pans
// or zooms mid-drag. Storing screen points would make a two-finger pan
// during a marquee slide the band across the drawing.
//
// ═══════════════════════════════════════════════════════════════════════
// THE BAND IS SCREEN CHROME AND NEVER A SCENE OP (CR-086)
// ═══════════════════════════════════════════════════════════════════════
// `buildRackScene` feeds the PDF as well as the display, so a band added
// to the scene would PRINT. It is painted by [MarqueeBand], over the
// canvas, from the same viewport the canvas uses. Same rule, same reason,
// as `PlanPinArmChip`.
import 'package:flutter/widgets.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/src/canvas/viewport_controller.dart';

/// A marquee in progress: where it started, where the pointer is, and what
/// it would catch.
final class MarqueeController extends ChangeNotifier {
  DPt? _from;
  DPt? _to;

  /// True from the moment a canvas calls [begin] until [end] or [cancel].
  bool get isActive => _from != null;

  DPt? get from => _from;
  DPt? get to => _to;

  /// The convention this drag is running, or null when idle.
  MarqueeMode? get mode {
    final f = _from;
    final t = _to;
    return (f == null || t == null) ? null : marqueeModeFor(f, t);
  }

  /// The band in scene units, or null when idle.
  DBox? get band {
    final f = _from;
    final t = _to;
    return (f == null || t == null) ? null : marqueeBand(f, t);
  }

  /// Arms the band at [at]. It has NO EXTENT until the first [update].
  ///
  /// ═══════════════════════════════════════════════════════════════════
  /// `_to` STAYS NULL ON PURPOSE, AND A TEST IS WHY
  /// ═══════════════════════════════════════════════════════════════════
  /// The first draft set both corners here, so [band] was a zero-size box
  /// from the instant the pointer went down and `MarqueeBand` painted a
  /// rectangle for every click on bare canvas. The rack canvas arms this
  /// before its 4px slop check and cannot easily arm it after, so the
  /// "no band until it has a size" rule belongs here rather than in each
  /// canvas: [band] and [mode] are null until somebody drags.
  void begin(DPt at) {
    _from = at;
    _to = null;
    notifyListeners();
  }

  void update(DPt at) {
    if (_from == null) return;
    _to = at;
    notifyListeners();
  }

  /// Ends the band and returns every entity id it caught, in a total
  /// order. Empty when the marquee was not running.
  ///
  /// **IT CLEARS EVEN WHEN IT CAUGHT NOTHING**, which is what makes an
  /// empty sweep a deselect rather than a stuck band: the caller applies
  /// whatever comes back with `SelectMode.replace`, and an empty list
  /// replacing a selection is exactly what dragging across bare canvas
  /// means.
  List<String> end(DiagramScene scene) => endIn(scene.hits);

  /// The list-level form, on `marqueeSelectionIn`'s precedent: a canvas
  /// holding bare regions reuses the identical rule.
  ///
  /// The schematic is that canvas. It already caches the BODY regions of
  /// its symbols alone (`_bodyRegionsFor`), which is exactly the set the
  /// band wants, and handing it a whole `DiagramScene` would make it
  /// rebuild what it has.
  List<String> endIn(List<HitRegion> regions) {
    final f = _from;
    final t = _to;
    _from = null;
    _to = null;
    notifyListeners();
    if (f == null || t == null) return const [];
    return marqueeSelectionIn(regions, f, t);
  }

  void cancel() {
    if (_from == null) return;
    _from = null;
    _to = null;
    notifyListeners();
  }
}

/// The band, drawn over a canvas.
///
/// A `Positioned.fill` sibling of the canvas rather than something the
/// canvas paints, so the scene it sits over stays exactly what the PDF
/// backend would receive.
final class MarqueeBand extends StatelessWidget {
  const MarqueeBand({
    required this.marquee,
    required this.viewport,
    required this.color,
    super.key,
  });

  final MarqueeController marquee;
  final ViewportController viewport;

  /// The stroke and (at low alpha) the fill. Passed in because a canvas
  /// knows its own theme and this widget must not reach for one; PAL-1
  /// governs what the SCENE may use, and this is chrome.
  final Color color;

  /// A stable handle for tests, so a case can find the band rather than
  /// whichever `CustomPaint` the tree happens to hold first.
  static const Key bandKey = ValueKey('marquee-band');

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: AnimatedBuilder(
      animation: Listenable.merge([marquee, viewport]),
      builder: (context, _) {
        final box = marquee.band;
        final mode = marquee.mode;
        if (box == null || mode == null) return const SizedBox.shrink();
        return CustomPaint(
          key: bandKey,
          painter: _BandPainter(
            box: box,
            mode: mode,
            viewport: viewport,
            color: color,
          ),
          size: Size.infinite,
        );
      },
    ),
  );
}

class _BandPainter extends CustomPainter {
  const _BandPainter({
    required this.box,
    required this.mode,
    required this.viewport,
    required this.color,
  });

  final DBox box;
  final MarqueeMode mode;
  final ViewportController viewport;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // MAPPED AT PAINT TIME from the scene box, so a pan or zoom during the
    // drag moves the band with the drawing rather than with the pointer.
    final a = viewport.sceneToScreen(DPt(box.left, box.top));
    final b = viewport.sceneToScreen(DPt(box.right, box.bottom));
    final rect = Rect.fromLTRB(a.x, a.y, b.x, b.y);

    canvas.drawRect(
      rect,
      Paint()..color = color.withValues(alpha: 0.10),
    );
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    if (mode == MarqueeMode.window) {
      canvas.drawRect(rect, stroke);
      return;
    }
    // CROSS IS DASHED, which is CR-102's own convention and the only
    // thing on screen telling the user which rule is about to run. A
    // solid band for both would make the two modes indistinguishable
    // until the selection appeared.
    _dashedRect(canvas, rect, stroke);
  }

  static void _dashedRect(Canvas canvas, Rect r, Paint p) {
    const dash = 4.0;
    const gap = 3.0;
    void line(Offset from, Offset to) {
      final total = (to - from).distance;
      if (total <= 0) return;
      final step = (to - from) / total;
      var at = 0.0;
      while (at < total) {
        final end = (at + dash).clamp(0.0, total);
        canvas.drawLine(from + step * at, from + step * end, p);
        at = end + gap;
      }
    }

    line(r.topLeft, r.topRight);
    line(r.topRight, r.bottomRight);
    line(r.bottomRight, r.bottomLeft);
    line(r.bottomLeft, r.topLeft);
  }

  @override
  bool shouldRepaint(_BandPainter old) =>
      old.box != box || old.mode != mode || old.color != color;
}
