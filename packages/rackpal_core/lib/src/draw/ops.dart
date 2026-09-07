// rackpal_core/src/draw/ops.dart — pure Dart. The display list
// (docs/08-pdf-export.md §7.9): one `DiagramOp` subclass per
// `DiagramCanvas` primitive, each a `const`, hashable-by-construction
// value object that forwards its stored arguments to the matching canvas
// call in `replay()`. This is what lets golden tests assert on DATA
// (`scene.ops.whereType<OpText>()...`) rather than pixels or PDF bytes.

import 'package:meta/meta.dart';
import 'package:rackpal_core/src/draw/canvas.dart';
import 'package:rackpal_core/src/draw/geometry.dart';
import 'package:rackpal_core/src/draw/image_ref.dart';
import 'package:rackpal_core/src/draw/path.dart';
import 'package:rackpal_core/src/draw/spec.dart';
import 'package:rackpal_core/src/draw/text.dart';
import 'package:vector_math/vector_math_64.dart';

/// One recorded drawing instruction. `replay` is the only way a
/// `DiagramOp` does anything — it forwards to exactly one
/// `DiagramCanvas` method.
sealed class DiagramOp {
  const DiagramOp();

  void replay(DiagramCanvas c);
}

// ── state stack ────────────────────────────────────────────────────────

final class OpSave extends DiagramOp {
  const OpSave();

  @override
  void replay(DiagramCanvas c) => c.save();
}

final class OpRestore extends DiagramOp {
  const OpRestore();

  @override
  void replay(DiagramCanvas c) => c.restore();
}

// ── transform ─────────────────────────────────────────────────────────

final class OpTransform extends DiagramOp {
  const OpTransform(this.m);

  final Matrix4 m;

  @override
  void replay(DiagramCanvas c) => c.transform(m);
}

// ── clip ──────────────────────────────────────────────────────────────

final class OpClipRect extends DiagramOp {
  const OpClipRect(this.r);

  final DBox r;

  @override
  void replay(DiagramCanvas c) => c.clipRect(r);
}

final class OpClipPath extends DiagramOp {
  const OpClipPath(this.p, {this.rule = FillRule.nonZero});

  final DiagramPath p;
  final FillRule rule;

  @override
  void replay(DiagramCanvas c) => c.clipPath(p, rule: rule);
}

// ── primitives ────────────────────────────────────────────────────────

final class OpLine extends DiagramOp {
  const OpLine(this.a, this.b, this.s);

  final DPt a;
  final DPt b;
  final Stroke s;

  @override
  void replay(DiagramCanvas c) => c.drawLine(a, b, s);
}

final class OpPolyline extends DiagramOp {
  const OpPolyline(this.pts, this.s, {this.close = false});

  final List<DPt> pts;
  final Stroke s;
  final bool close;

  @override
  void replay(DiagramCanvas c) => c.drawPolyline(pts, s, close: close);
}

final class OpPath extends DiagramOp {
  const OpPath(this.p, {this.fill, this.stroke});

  final DiagramPath p;
  final Fill? fill;
  final Stroke? stroke;

  @override
  void replay(DiagramCanvas c) => c.drawPath(p, fill: fill, stroke: stroke);
}

final class OpRect extends DiagramOp {
  const OpRect(this.r, {this.fill, this.stroke});

  final DBox r;
  final Fill? fill;
  final Stroke? stroke;

  @override
  void replay(DiagramCanvas c) => c.drawRect(r, fill: fill, stroke: stroke);
}

final class OpRoundRect extends DiagramOp {
  const OpRoundRect(this.r, this.radii, {this.fill, this.stroke});

  final DBox r;
  final Radii radii;
  final Fill? fill;
  final Stroke? stroke;

  @override
  void replay(DiagramCanvas c) =>
      c.drawRoundRect(r, radii, fill: fill, stroke: stroke);
}

final class OpCircle extends DiagramOp {
  const OpCircle(this.center, this.radius, {this.fill, this.stroke});

  final DPt center;
  final double radius;
  final Fill? fill;
  final Stroke? stroke;

  @override
  void replay(DiagramCanvas c) =>
      c.drawCircle(center, radius, fill: fill, stroke: stroke);
}

final class OpEllipse extends DiagramOp {
  const OpEllipse(this.center, this.rx, this.ry, {this.fill, this.stroke});

  final DPt center;
  final double rx;
  final double ry;
  final Fill? fill;
  final Stroke? stroke;

  @override
  void replay(DiagramCanvas c) =>
      c.drawEllipse(center, rx, ry, fill: fill, stroke: stroke);
}

final class OpText extends DiagramOp {
  const OpText(this.text, this.at, this.style);

  final String text;
  final DPt at;
  final TextStyleSpec style;

  @override
  void replay(DiagramCanvas c) => c.drawText(text, at, style);
}

/// A raster placed to fill [dst], added with `drawImage` under
/// `canvas.dart`'s amendment clause (DR-029 §11.28.6).
///
/// ═══════════════════════════════════════════════════════════════════════
/// IT HOLDS AN `ImageRef`, WHICH IS A NAME. IT HOLDS NO PIXELS.
/// ═══════════════════════════════════════════════════════════════════════
/// This list is compared byte for byte (M2-C's determinism clause) and
/// held whole while a sheet set lays out. A `Uint8List` here would put
/// megabytes into the one structure whose entire purpose is to be cheap to
/// compare, and would drag a decoder into a package that is Flutter-free
/// by gate. See `image_ref.dart` for the resolution seam.
///
/// **This op is emitted by nothing today.** `PlanUnderlay` does not exist
/// until PLAN-C and the container that holds the member does not exist
/// until PLAN-B, so every scene this repository builds still contains
/// exactly zero of these. That is the intended state at PLAN-A and it is
/// what `schematic_perf_test.dart`'s untouched op-count baselines record.
final class OpImage extends DiagramOp {
  const OpImage(this.image, this.dst);

  final ImageRef image;
  final DBox dst;

  @override
  void replay(DiagramCanvas c) => c.drawImage(image, dst);
}

// ── scene ─────────────────────────────────────────────────────────────

/// A simple `[start, end)` op-index range — Dart has no built-in range
/// type. `end` is exclusive, matching `List.sublist(start, end)`.
@immutable
final class IntRange {
  const IntRange(this.start, this.end);

  final int start;
  final int end;

  @override
  bool operator ==(Object other) =>
      other is IntRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'IntRange($start, $end)';
}

/// A minimal geometric hit region: an entity id, a bounding box, and
/// optionally the sub-part of that entity the box belongs to.
///
/// M1 SCOPE NOTE: a `DBox` is enough for point-in-region testing against
/// device bodies and furniture. This will need to grow (segment lists for
/// wire runs, etc.) once the schematic canvas's link hit-testing lands in
/// M2 (docs/03-architecture.md §7.4, CR-084) — do not over-build it now.
/// [partKey] is the first instalment of that growth: a schematic symbol
/// needs its PINS in `DiagramScene.hits`, not only its body, and the
/// alternative — a parallel symbol-only query type that no generic consumer
/// of `hits` can see — is precisely what §7.4 rules out.
@immutable
final class HitRegion {
  const HitRegion(this.entityId, this.bounds, {this.partKey});

  /// The owning entity — a `DeviceInstance.id.v` in both the rack elevation
  /// and the schematic. Selection, PDF annotations and anything else that
  /// only cares "which device" can read this and ignore [partKey].
  final String entityId;

  final DBox bounds;

  /// The sub-part of [entityId] this box covers, or `null` when the box IS
  /// the entity (a device body). Currently only a schematic pin's
  /// `SymbolPort.key` (the stable author-assigned join, CR-051 — never a
  /// UUID), so a schematic-aware consumer can tell "the MTX-1" from "the
  /// MTX-1's J07" while a generic one still resolves both to the device.
  final String? partKey;

  bool contains(DPt p) => bounds.contains(p);

  @override
  bool operator ==(Object other) =>
      other is HitRegion &&
      other.entityId == entityId &&
      other.bounds == bounds &&
      other.partKey == partKey;

  @override
  int get hashCode => Object.hash(entityId, bounds, partKey);

  @override
  String toString() =>
      'HitRegion($entityId${partKey == null ? '' : '#$partKey'}, $bounds)';
}

/// The output of `buildScene` (docs/03-architecture.md §7.2): a flat,
/// replayable display list plus everything derived from it that a
/// backend or the editor needs without re-walking the model.
final class DiagramScene {
  const DiagramScene({
    required this.ops,
    required this.bounds,
    required this.hits,
    required this.minTextSizePt,
    required this.fragments,
  });

  final List<DiagramOp> ops;

  /// → scale-to-fit, tile counts.
  final DBox bounds;

  /// → editor selection (CR-084).
  final List<HitRegion> hits;

  /// → the legibility trigger (docs/08-pdf-export.md §6.2).
  final double minTextSizePt;

  /// → CR-086 per-entity replay.
  final Map<String, IntRange> fragments;

  void replay(DiagramCanvas c) {
    for (final op in ops) {
      op.replay(c);
    }
  }

  /// A sub-scene containing only [entityId]'s ops (docs/08-pdf-export.md
  /// §7.8, CR-086) — what `RenderDeviceBox.paint` replays through
  /// `FlutterDiagramCanvas` instead of drawing anything itself. `bounds`,
  /// `hits` and `minTextSizePt` are carried over unchanged; only `ops` is
  /// narrowed to the entity's own range.
  ///
  /// Nothing calls this yet in this stage — the widget-tree replay
  /// mechanism (§7.8) is a later stage's job — but the shape is settled
  /// now so that stage does not need to rework `DiagramScene`.
  DiagramScene fragmentFor(String entityId) {
    final range = fragments[entityId];
    if (range == null) {
      throw ArgumentError.value(
        entityId,
        'entityId',
        'DiagramScene.fragmentFor: no fragment registered for this entity '
            'id',
      );
    }
    return DiagramScene(
      ops: ops.sublist(range.start, range.end),
      bounds: bounds,
      hits: hits,
      minTextSizePt: minTextSizePt,
      fragments: fragments,
    );
  }
}
