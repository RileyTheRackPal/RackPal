// rackpal_ui/src/draw/plan_image_cache.dart — the implementation
// `FlutterImageResolver` never had (PLAN-E/2, docs/12 §5.9.7.6).
//
// ═══════════════════════════════════════════════════════════════════════
// A TYPEDEF WITH NO IMPLEMENTATION IS A SEAM, NOT A FEATURE
// ═══════════════════════════════════════════════════════════════════════
// PLAN-A added `drawImage` to `DiagramCanvas`, both backends draw it, and
// `FlutterDiagramCanvas` takes an optional `FlutterImageResolver`.
// `PLAN-E/1`'s census found that **nothing in the tree supplied one**, and
// that the feasibility study's list of "machinery that already exists" had
// never mentioned it. A plan canvas that cannot draw the plan is not one,
// so this is that implementation.
//
// ═══════════════════════════════════════════════════════════════════════
// SYNCHRONOUS LOOKUP, ASYNCHRONOUS LOAD, AND THE SPLIT IS THE WHOLE POINT
// ═══════════════════════════════════════════════════════════════════════
// `flutter_canvas.dart` states the constraint in its own words: the
// resolver is synchronous "because painting is" — `ui.Canvas.drawImageRect`
// wants a decoded `ui.Image` and a paint callback cannot await — so
// "decoding is somebody else's job, done once when the underlay is
// imported or the document is opened". This class is that somebody.
//
// A resolver that decoded on demand would decode a floorplan on EVERY
// FRAME OF A PAN, which on the measured plan set (DR-137: 18 sheets, ARCH
// D) is tens of megabytes of work per frame. So [load] is a `Future` and
// [resolver] is not.
//
// ═══════════════════════════════════════════════════════════════════════
// IT OWNS `ui.Image` HANDLES, SO IT HAS A REAL `dispose`
// ═══════════════════════════════════════════════════════════════════════
// A `ui.Image` is a native handle and leaking one leaks GPU memory for the
// life of the process. The owner is whoever owns the document's lifetime,
// which is why this is an ordinary object with a `dispose` rather than a
// `static` cache: `flutter_canvas.dart`'s own `_dashCache` note records
// what a static gets you — it "would survive, and would also outlive every
// document, hold native handles for a project the user closed an hour ago,
// and leak between widget tests in a way no test could see".
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:rackpal_ui/src/draw/flutter_canvas.dart';

/// Decoded underlay rasters, keyed by their container member path.
///
/// The key is `ImageRef.member` and not a `Uuid` for the reason
/// `image_ref.dart` gives: DR-030's title-block logo is the second
/// consumer of this op and does not live under `underlays/`.
final class PlanImageCache {
  final Map<String, ui.Image> _images = <String, ui.Image>{};
  bool _disposed = false;

  /// How many rasters are held. For tests and for a memory report.
  int get length => _images.length;

  bool contains(String member) => _images.containsKey(member);

  /// The synchronous lookup handed to `FlutterDiagramCanvas`.
  ///
  /// RETURNS NULL RATHER THAN THROWING, and the distinction matters: null
  /// means "not loaded", and `FlutterDiagramCanvas.drawImage` turns that
  /// into a `MissingImageError`. Throwing here would rob it of the chance,
  /// and docs/15 §7 is explicit that a reference nothing resolves must
  /// THROW rather than draw nothing, "because a `T1.01` that is a title
  /// block over white paper is indistinguishable from a plan with no drops
  /// on it".
  FlutterImageResolver get resolver =>
      (ref) => _images[ref.member];

  /// Decodes [bytes] and holds the result under [member].
  ///
  /// IDEMPOTENT BY MEMBER, and that is not a convenience. A document can
  /// hold several underlays pointing at one member only by corruption, but
  /// a caller re-opening the same document, or a rebuild that re-runs a
  /// load, is ordinary. Decoding twice would leak the first handle,
  /// silently, so a repeat load returns the held image and decodes
  /// nothing.
  ///
  /// The bytes are the container member's, verbatim: PNG or JPEG
  /// (`PlanImageFormat` has two values on purpose), already through
  /// `PLAN-D/4`'s content sniff, size caps and alpha flatten by the time
  /// they are written. This does not re-run those checks and must not be
  /// handed bytes that have not.
  Future<ui.Image> load(String member, Uint8List bytes) async {
    if (_disposed) {
      throw StateError('PlanImageCache.load after dispose()');
    }
    final held = _images[member];
    if (held != null) return held;
    final codec = await ui.instantiateImageCodec(bytes);
    try {
      final frame = await codec.getNextFrame();
      // RE-CHECKED AFTER THE AWAIT. Two loads of the same member can
      // interleave across these awaits, and the loser must not overwrite
      // the winner's entry and leak its handle. `dispose()` can also have
      // run while this was decoding.
      final raced = _images[member];
      if (raced != null) {
        frame.image.dispose();
        return raced;
      }
      if (_disposed) {
        frame.image.dispose();
        throw StateError('PlanImageCache disposed while loading "$member"');
      }
      _images[member] = frame.image;
      return frame.image;
    } finally {
      codec.dispose();
    }
  }

  /// Drops one member, disposing its handle. For an underlay removed from
  /// the document while it is open.
  void evict(String member) => _images.remove(member)?.dispose();

  /// Disposes every held handle. Call when the document closes.
  @mustCallSuper
  void dispose() {
    _disposed = true;
    for (final image in _images.values) {
      image.dispose();
    }
    _images.clear();
  }
}
