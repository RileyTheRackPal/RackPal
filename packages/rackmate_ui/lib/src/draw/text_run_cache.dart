// M2-G — the text-run cache, sized from a measurement rather than from an
// assumption.
//
// ═══════════════════════════════════════════════════════════════════════
// WHAT IT IS FOR
// ═══════════════════════════════════════════════════════════════════════
// `FlutterDiagramCanvas.drawText` built a fresh `TextPainter` — a
// `TextSpan`, a `TextStyle` and a native `ui.Paragraph` via `layout()` —
// on EVERY call. Under DR-001 net labels are the default render, so a
// schematic paints two labels per `Link` on top of every symbol's
// designator, name and type line, and a pan re-records the picture, so
// that cost is paid per frame rather than per edit.
//
// ═══════════════════════════════════════════════════════════════════════
// THE MEASUREMENT, AND WHAT IT REFUTES
// ═══════════════════════════════════════════════════════════════════════
// docs/09's M2 risk paragraph sizes this cache against an assumption:
// "~300 additional text runs on a 150-connection project on top of the
// ~10,000 the cache must be sized for", and warns that "a 2,000-entry LRU
// against ~10,000 runs thrashes, and a thrashing LRU is worse than none
// because eviction disposes a native `ui.Paragraph` in the paint path."
//
// `schematic_perf_test.dart`'s M2-G census counted it instead, on the
// committed 300-link fixture — which is v1's stated density ceiling, not a
// typical project:
//
//   schematic, augmented   2374 total runs, 703 distinct (text, style)
//   schematic, as committed 2374 total runs, 404 distinct
//   rack elevations x4      234 total runs,  71 distinct
//
// **The working set is 703, not ~10,000.** The roadmap overstates the
// figure this cache must hold by about fourteen times, and the thrashing
// hazard it warns about does not exist at v1 scale: [kTextRunCacheCapacity]
// is nearly three times the measured working set, so on the densest
// document v1 admits, NOTHING IS EVER EVICTED. The roadmap's prescribed
// 2,000 entries turns out to be a good number for the opposite reason to
// the one given.
//
// The reuse factor is 3.38x, so a perfect cache eliminates 1,671 of 2,374
// layouts per paint. That is what makes it worth having at all — a census
// showing 1.0x would have retired this task instead.
//
// ═══════════════════════════════════════════════════════════════════════
// THE KEY IS `(text, TextStyleSpec)` — AND `quantisedScale` IS NOT A TERM
// ═══════════════════════════════════════════════════════════════════════
// docs/09 prescribes `(text, styleId, quantisedScale)`. The third term is
// deliberately absent, and this is a deviation with a reason rather than an
// omission: `drawText` passes `s.sizePt` straight to `TextStyle.fontSize`,
// and `sizePt` is in DIAGRAM UNITS fixed at scene-build time. The viewport
// transform is applied to the CANVAS, not to the font, so the same run
// lays out to the identical paragraph at every zoom. Including scale in the
// key would multiply the working set by the number of zoom levels visited
// and buy nothing — the cache would thrash for the reason the roadmap
// feared, caused by the key the roadmap prescribed.
// `text_run_cache_test.dart` holds that: the same run under two different
// canvas transforms is one miss and one hit.
//
// `TextStyleSpec` carries `argb`, so a colour change cannot reuse another
// colour's paragraph — the key is the whole spec rather than a style id,
// because the spec already has value `==`/`hashCode` and an id would be a
// second identity to keep in step with it. That whole-spec key also puts
// `rotationRad` and `anchor` in, though neither changes a layout: rotation
// is applied to the canvas and the anchor only decides where the run is
// painted. The cost is one duplicate entry for a run appearing both
// rotated and upright — cheap, and cheaper than a hand-maintained key that
// could drift from `==` and paint a run in the wrong colour.
import 'package:flutter/painting.dart';
import 'package:rackmate_core/rackmate_core.dart';

/// Entries held before the least-recently-used one is evicted.
///
/// 2 048, against a MEASURED working set of 703 on the 300-link fixture —
/// see the file header. The headroom is the point: eviction disposes a
/// native `ui.Paragraph` inside the paint path, so a cache that runs at its
/// limit is worse than no cache, and the only defence is to be bigger than
/// the densest document v1 admits.
const int kTextRunCacheCapacity = 2048;

/// One laid-out run, plus the baseline offset that laying it out produced.
///
/// The baseline rides along because `computeDistanceToActualBaseline` is a
/// property of the layout, not of the draw: recomputing it per call would
/// leave a cache that saved the expensive half and repeated the cheap half
/// for no reason.
final class TextRun {
  const TextRun(this.painter, this.baselineOffset);

  final TextPainter painter;
  final double baselineOffset;
}

/// A least-recently-used cache of laid-out text runs.
///
/// LRU, and the recency is maintained by re-insertion: Dart's map preserves
/// INSERTION order, so removing and re-adding on a hit moves an entry to the
/// end and `keys.first` is always the coldest. A plain insertion-ordered map
/// without that step is FIFO, which evicts the run a paint is about to ask
/// for again.
final class TextRunCache {
  TextRunCache({this.capacity = kTextRunCacheCapacity})
    : assert(capacity > 0, 'a zero-capacity cache is a leak with extra steps');

  final int capacity;

  final Map<(String, TextStyleSpec), TextRun> _entries =
      <(String, TextStyleSpec), TextRun>{};

  /// Cumulative counters. Not diagnostics for their own sake — they are how
  /// `text_run_cache_test.dart` proves the key is the right key, which no
  /// pixel comparison can show.
  int get hits => _hits;
  int get misses => _misses;
  int get evictions => _evictions;
  int _hits = 0;
  int _misses = 0;
  int _evictions = 0;

  /// Entries currently held.
  int get length => _entries.length;

  /// The run for [text] under [style], laying it out through [layOut] on a
  /// miss.
  ///
  /// The caller supplies the layout function rather than this class building
  /// a `TextPainter` itself, so the font resolution, the feature flags and
  /// the leading distribution stay in ONE place —
  /// `FlutterDiagramCanvas.drawText`, which is where docs/08 §7.7's contract
  /// is transcribed and where any divergence from the PDF backend would be
  /// a real bug.
  TextRun runFor(
    String text,
    TextStyleSpec style,
    TextRun Function() layOut,
  ) {
    final key = (text, style);
    final hit = _entries.remove(key);
    if (hit != null) {
      _hits++;
      // Re-inserted at the end: this is the LRU half of the structure.
      _entries[key] = hit;
      return hit;
    }

    _misses++;
    final made = layOut();
    _entries[key] = made;
    if (_entries.length > capacity) _evictOldest();
    return made;
  }

  void _evictOldest() {
    final coldest = _entries.keys.first;
    final evicted = _entries.remove(coldest);
    _evictions++;
    // DISPOSED, not dropped. A `TextPainter` holds a native `ui.Paragraph`;
    // leaving it to the finalizer is what turns a full cache into memory
    // pressure at exactly the moment the paint path is busiest.
    evicted?.painter.dispose();
  }

  /// Drops and disposes everything. Called by the render object that owns
  /// this cache when it detaches — a cache outliving its painter is a
  /// native-memory leak with no reader.
  void clear() {
    for (final entry in _entries.values) {
      entry.painter.dispose();
    }
    _entries.clear();
  }
}
