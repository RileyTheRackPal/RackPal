// rackmate_core/src/draw/scene/symbol_hit_test.dart — pure Dart.
//
// Point queries against schematic SYMBOLS: which pin, which body, and where
// the grid would snap. The geometric half only — pointer plumbing (one
// query per frame, hover throttle, cursor policy) stays in `rackmate_ui`,
// exactly as `draw/hit_test.dart` splits it for the rack elevation
// (docs/03-architecture.md §7.4, CR-084).
//
// It sits beside `symbol_layer.dart` and derives every pin position from
// that file's [symbolPortCentre] rather than re-deriving it. That is the
// point of the pairing: before relocation the painter and the hit-tester
// each computed port positions independently and DISAGREED by
// `(size/2, size/2)` on all four edges, so every pin's clickable zone was
// offset from the circle the user could see. One function, two callers, and
// one test that they agree — `symbol_hit_test_test.dart`'s "every pin the
// layer DRAWS is on its body edge, and is hittable exactly there", which
// probes this query at the circle centres replayed out of
// `buildSymbolLayer`'s own ops rather than at recomputed ones.
//
// WHY THE TYPES ARE NAMED `Symbol*`: the pre-relocation file called them
// `HitTestParams` / `HitTestResult` / `SchematicHitType`. `HitTestResult` is
// also a `package:flutter/rendering.dart` export, and this file's symbols
// are re-exported from the `rackmate_core` barrel — so the old name would
// have collided in every `rackmate_ui` file that imports both. Renamed on
// the way across. `draw/hit_test.dart` (the rack elevation's region query)
// keeps its own basename; this one is `symbol_hit_test.dart` so the two
// never clash either.
//
// ONE MECHANISM, NOT TWO. Everything here is expressed in the established
// `HitRegion` / `DiagramScene.hits` terms that CR-084 and docs/03 §7.4
// define, and the ranking is `hit_test.dart`'s own [hitTestRegions] — not a
// second implementation of it. [symbolHitRegions] is the bridge: it turns
// symbols into the regions a `DiagramScene` carries, so `hitTest(scene, p)`
// — "the exported, documented nearest-hit query the future read-only mobile
// shell reuses verbatim" — finds a symbol's body and its pins like it finds
// a device. A private parallel query would have meant no generic consumer of
// `hits` (the CR-084 selection path, a PDF clickable-annotation pass) could
// ever see a symbol, which would defeat the point of relocating this code.
// [SymbolHitTest] adds exactly two things on top: the pin-beats-body
// precedence, and grid snapping. It computes no distances of its own.
//
// TWO RULINGS INHERITED FROM `draw/hit_test.dart`, because a schematic
// query that behaves differently from a rack query is a bug in one of them:
//   * "Return the NEAREST hit, not the first." The pre-relocation code
//     returned the first symbol's port OR body before it had even looked at
//     the second symbol, so a body could beat a nearer pin.
//   * Brute force plus a cheap reject is the right algorithm at this scale.
//
// SCOPE: pins and bodies. Wire-segment hit-testing, port COMPATIBILITY
// matching (family + direction) and drag-to-connect target search are M2 —
// the pre-relocation file carried a `PortMatcher` and a `findBestTarget`
// that nothing called, the latter building a fabricated `PortDef` into an
// unused local under a `TODO: Implement PortMatcher integration`. Both were
// dropped here rather than relocated: M2 must build compatibility against
// docs/05 §4's rules, not against a stub.

import 'dart:math' as math;

import 'package:meta/meta.dart';
import 'package:rackmate_core/src/draw/geometry.dart';
import 'package:rackmate_core/src/draw/hit_test.dart';
import 'package:rackmate_core/src/draw/ops.dart';
import 'package:rackmate_core/src/draw/scene/symbol_layer.dart';
import 'package:rackmate_core/src/model/template.dart' show SymbolSide;

/// What a point query landed on.
enum SymbolHitKind {
  /// Nothing — not currently returned by [SymbolHitTest.testPoint], which
  /// always reports at least a snap position, but kept so a caller holding
  /// a default-constructed result can express "no hit".
  none,

  /// A symbol's body rectangle.
  node,

  /// A pin, within [SymbolHitTestParams.portHitTolerance] of its drawn
  /// circle.
  port,

  /// Empty sheet — [SymbolHitResult.snapPosition] is the grid point the
  /// cursor would land on.
  snap,
}

/// Tuning for a point query, in DIAGRAM UNITS (not screen pixels — the
/// query runs in sheet space, so a caller that has zoomed must convert its
/// pixel tolerance before constructing this).
@immutable
final class SymbolHitTestParams {
  const SymbolHitTestParams({
    this.portHitTolerance = 15,
    this.snapGridSize = 20,
  });

  /// Slop around a pin's DRAWN circle that still counts as hitting it —
  /// the `tolerance` handed to `hitTestRegions`, so it means exactly what it
  /// means for a rack device: a point qualifies when it lies inside the pin
  /// or within this distance of the pin's edge. Distance to a box, not to a
  /// box's corner-square, so the target is a rounded rect and a diagonal
  /// near-miss is a miss.
  ///
  /// Measured from the drawn circle rather than from a dimensionless centre
  /// because that is what the user is aiming at, and because a scene's
  /// `HitRegion` has to carry the pin's real ink for a generic consumer
  /// (`hitTest(scene, p)`, a PDF annotation pass) to be able to use it at
  /// all.
  final double portHitTolerance;

  /// Grid pitch for magnetic snapping. Non-positive disables snapping
  /// (the point is returned unchanged) rather than dividing by zero.
  final double snapGridSize;

  @override
  bool operator ==(Object other) =>
      other is SymbolHitTestParams &&
      other.portHitTolerance == portHitTolerance &&
      other.snapGridSize == snapGridSize;

  @override
  int get hashCode => Object.hash(portHitTolerance, snapGridSize);
}

/// The outcome of one point query.
@immutable
final class SymbolHitResult {
  const SymbolHitResult({
    this.kind = SymbolHitKind.none,
    this.position,
    this.snapPosition,
    this.nodeId,
    this.portKey,
    this.side,
  });

  final SymbolHitKind kind;

  /// For [SymbolHitKind.port], the pin's exact centre; otherwise the
  /// queried point.
  final DPt? position;

  /// The queried point snapped to the grid, always populated so a caller
  /// can render a cursor hint regardless of what was hit.
  final DPt? snapPosition;

  /// [RenderedSymbol.id] of the symbol hit, when one was.
  final String? nodeId;

  /// [SymbolPort.key] of the pin hit, when one was.
  final String? portKey;

  /// The edge the hit pin sits on.
  final SymbolSide? side;

  @override
  bool operator ==(Object other) =>
      other is SymbolHitResult &&
      other.kind == kind &&
      other.position == position &&
      other.snapPosition == snapPosition &&
      other.nodeId == nodeId &&
      other.portKey == portKey &&
      other.side == side;

  @override
  int get hashCode =>
      Object.hash(kind, position, snapPosition, nodeId, portKey, side);

  @override
  String toString() =>
      'SymbolHitResult(${kind.name}, node: $nodeId, port: $portKey)';
}

/// The [HitRegion]s [symbols] contribute to a `DiagramScene.hits`, in
/// ABSOLUTE sheet coordinates — the schematic's answer to what
/// `buildRackScene` does with `hits.add(HitRegion(device.id.v, rect))`.
///
/// Per symbol, in [RenderedSymbol.allPorts] order: one region per PIN
/// (`entityId` = the symbol's id, `partKey` = the pin's key, bounds = the
/// pin's DRAWN circle, `centre ± size / 2` — the same [symbolPortCentre]
/// the painter uses, never a second derivation), then one region for the
/// BODY (`partKey` null, bounds = [RenderedSymbol.bodyRect]).
///
/// The bounds are the symbol's real INK, with no hit slop baked in, because
/// slop is the querier's policy and belongs in `hitTest`'s `tolerance`
/// argument — a scene that stored inflated boxes would hand a PDF
/// annotation pass hit targets larger than the things they annotate.
List<HitRegion> symbolHitRegions(Iterable<RenderedSymbol> symbols) {
  final regions = <HitRegion>[];
  for (final symbol in symbols) {
    for (final port in symbol.allPorts) {
      final centre = symbolPortCentre(symbol, port);
      final r = port.size / 2;
      regions.add(
        HitRegion(
          symbol.id,
          DBox.fromLtwh(centre.x - r, centre.y - r, port.size, port.size),
          partKey: port.key,
        ),
      );
    }
    regions.add(HitRegion(symbol.id, symbol.bodyRect));
  }
  return regions;
}

/// Point queries over a fixed list of [RenderedSymbol]s.
///
/// Pure and synchronous: no Flutter, driven directly by `dart test`. The
/// regions are built ONCE, at construction, from [symbolHitRegions] — the
/// same function that populates a scene's `hits` — so a query allocates
/// nothing beyond locals and the result, and the interactive query and the
/// scene can never be looking at different geometry.
@immutable
final class SymbolHitTest {
  factory SymbolHitTest({
    required List<RenderedSymbol> symbols,
    SymbolHitTestParams params = const SymbolHitTestParams(),
  }) {
    final regions = symbolHitRegions(symbols);
    // [symbolHitRegions] emits pin regions in the flat (symbol, allPorts)
    // walk order, which is the same order this loop visits — so zipping the
    // two pairs each region with the pin it was built from.
    final pinRegions = regions.where((r) => r.partKey != null).toList();
    final pins = <_ResolvedPin>[];
    var i = 0;
    for (final symbol in symbols) {
      for (final port in symbol.allPorts) {
        pins.add(_ResolvedPin(pinRegions[i++], symbol, port));
      }
    }
    return SymbolHitTest._(
      symbols,
      params,
      regions,
      pins,
      pinRegions,
      regions.where((r) => r.partKey == null).toList(),
    );
  }

  const SymbolHitTest._(
    this.symbols,
    this.params,
    this._regions,
    this._pins,
    this._pinRegions,
    this._bodies,
  );

  final List<RenderedSymbol> symbols;
  final SymbolHitTestParams params;

  /// This query's view of [symbols], in the scene's own `HitRegion` terms.
  final List<HitRegion> _regions;

  /// The pin regions, each paired with the symbol and port it came from, so
  /// a hit resolves back to a [SymbolHitResult] without searching.
  final List<_ResolvedPin> _pins;

  /// [_pins]' regions alone, in the same order — what [hitTestRegions]
  /// ranks, held so a query allocates nothing.
  final List<HitRegion> _pinRegions;

  /// The body regions.
  final List<HitRegion> _bodies;

  /// The regions this query ranks — exactly what a schematic scene builder
  /// should put in `DiagramScene.hits`, exposed so a caller can assert the
  /// two are the same list rather than hope.
  List<HitRegion> get regions => List.unmodifiable(_regions);

  /// Resolves [point] (ABSOLUTE sheet coordinates) to a pin, a body, or the
  /// grid.
  ///
  /// PRECEDENCE, and it is deliberate: pins beat bodies GLOBALLY. A pin sits
  /// on its body's edge, so a click near one is inside the body too — if
  /// bodies could win, edge pins would be unclickable. That is the ONE thing
  /// this adds over the shared ranking, and it is why the pins and the
  /// bodies are ranked in two passes instead of one: a single
  /// [hitTestRegions] call over both would let a body that CONTAINS the
  /// point (edge distance 0) beat a pin a few units away, and edge pins
  /// would go back to being unclickable.
  ///
  /// Within each pass the ranking is [hitTestRegions] verbatim — nearest by
  /// edge distance, then by centre distance, then list order — so a
  /// schematic query and a rack query can never drift apart. Pin regions are
  /// the pin's drawn circle and are ranked with
  /// [SymbolHitTestParams.portHitTolerance] as slop; body regions are ranked
  /// with no slop, i.e. strict containment.
  SymbolHitResult testPoint(DPt point) {
    final snapped = snapToGrid(point);

    // ── pins: the drawn circle, plus the caller's slop ───────────────
    final hit = hitTestRegions(
      _pinRegions,
      point,
      tolerance: params.portHitTolerance,
    );
    if (hit != null) {
      final pin = _pins.firstWhere((p) => identical(p.region, hit));
      return SymbolHitResult(
        kind: SymbolHitKind.port,
        position: symbolPortCentre(pin.symbol, pin.port),
        snapPosition: snapped,
        nodeId: pin.symbol.id,
        portKey: pin.port.key,
        side: pin.port.side,
      );
    }

    // ── bodies: strict containment, nearest centre wins ──────────────
    final body = hitTestRegions(_bodies, point);
    if (body != null) {
      return SymbolHitResult(
        kind: SymbolHitKind.node,
        position: point,
        snapPosition: snapped,
        nodeId: body.entityId,
      );
    }

    return SymbolHitResult(
      kind: SymbolHitKind.snap,
      position: point,
      snapPosition: snapped,
    );
  }

  /// [point] snapped to the nearest [SymbolHitTestParams.snapGridSize]
  /// intersection. Exposed (not private) because the wire-draw state
  /// machine snaps the same way and must not re-derive it.
  ///
  /// Halfway values round AWAY FROM ZERO — `Dart`'s `num.round()`
  /// convention, stated here because it is the boundary a test pins.
  DPt snapToGrid(DPt point) {
    final g = params.snapGridSize;
    if (g <= 0) return point;
    return DPt((point.x / g).round() * g, (point.y / g).round() * g);
  }
}

/// One pin region paired with what it came from, so a ranked hit resolves
/// to a [SymbolHitResult] without a second search over [SymbolHitTest.symbols].
@immutable
final class _ResolvedPin {
  const _ResolvedPin(this.region, this.symbol, this.port);

  final HitRegion region;
  final RenderedSymbol symbol;
  final SymbolPort port;
}

double _distanceSq(DPt a, DPt b) {
  final dx = b.x - a.x;
  final dy = b.y - a.y;
  return dx * dx + dy * dy;
}

/// Euclidean distance between two diagram points.
///
/// Replaces the pre-relocation `DPointExt._sqrtNewton` — a hand-rolled
/// ten-iteration Newton square root written under the belief that
/// `dart:math` was unavailable in this package. It is not: `dart:math` is
/// pure Dart, imports no `dart:ui`, and passes `no_flutter_import_test`.
extension DPtDistance on DPt {
  double distanceTo(DPt other) => math.sqrt(_distanceSq(this, other));
}
