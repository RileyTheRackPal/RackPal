// Double-precision geometry for the drawing IR (draw/), kept in its own
// file so canvas.dart, path.dart, text.dart and ops.dart all import ONE
// definition (docs/08-pdf-export.md §7.3's canvas.dart header comment says
// it "imports only geometry/style/path" — this file is that "geometry").
//
// units/pt.dart's `Pt{gx, gy}` and units/box.dart's `Box` are the MODEL's
// coordinates: integer schematic grid units (CR-004). The `DiagramCanvas`
// boundary (docs/03-architecture.md §7.2, CR-007) is a completely
// different regime — DOUBLE diagram units, where 1 diagram unit = 1 PDF
// point = 1/72 in. Conflating the two would be exactly the unit-regime
// violation this project's units policy exists to prevent, so this file
// deliberately does NOT reuse the names `Pt`/`Box`: [DPt] is the
// double-precision diagram point, [DBox] is the double-precision
// axis-aligned diagram box. Nothing under draw/ should import
// units/pt.dart or units/box.dart for on-canvas geometry.

import 'package:meta/meta.dart';

/// A point in diagram space: double-precision, 1 unit = 1 PDF point.
///
/// This is the `Pt` referenced by docs/08-pdf-export.md §7.3/§7.5's quoted
/// signatures — renamed `DPt` here (see the file header) so it is never
/// confused with the model's integer grid `Pt` from `units/pt.dart`.
@immutable
final class DPt {
  const DPt(this.x, this.y);

  final double x;
  final double y;

  DPt operator +(DPt other) => DPt(x + other.x, y + other.y);
  DPt operator -(DPt other) => DPt(x - other.x, y - other.y);

  @override
  bool operator ==(Object other) =>
      other is DPt && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'DPt($x, $y)';
}

/// An axis-aligned bounding box in diagram space: double-precision, 1 unit
/// = 1 PDF point. The double-precision sibling of `units/box.dart`'s
/// integer-grid `Box` — see the file header for why the name differs.
@immutable
final class DBox {
  const DBox._(this.left, this.top, this.right, this.bottom);

  /// Builds the normalised box spanning two arbitrary corners.
  factory DBox.fromCorners(DPt a, DPt b) => DBox._(
    a.x < b.x ? a.x : b.x,
    a.y < b.y ? a.y : b.y,
    a.x > b.x ? a.x : b.x,
    a.y > b.y ? a.y : b.y,
  );

  /// Builds a box from a top-left corner plus width/height.
  const DBox.fromLtwh(double left, double top, double width, double height)
    : this._(left, top, left + width, top + height);

  final double left;
  final double top;
  final double right;
  final double bottom;

  double get width => right - left;
  double get height => bottom - top;

  DPt get topLeft => DPt(left, top);
  DPt get bottomRight => DPt(right, bottom);

  bool contains(DPt p) =>
      p.x >= left && p.x <= right && p.y >= top && p.y <= bottom;

  bool intersects(DBox other) =>
      left <= other.right &&
      right >= other.left &&
      top <= other.bottom &&
      bottom >= other.top;

  /// The smallest box containing both this box and [other].
  DBox union(DBox other) => DBox._(
    left < other.left ? left : other.left,
    top < other.top ? top : other.top,
    right > other.right ? right : other.right,
    bottom > other.bottom ? bottom : other.bottom,
  );

  /// Grows (or, with a negative amount, shrinks) every edge by [amount].
  DBox inflate(double amount) =>
      DBox._(left - amount, top - amount, right + amount, bottom + amount);

  @override
  bool operator ==(Object other) =>
      other is DBox &&
      other.left == left &&
      other.top == top &&
      other.right == right &&
      other.bottom == bottom;

  @override
  int get hashCode => Object.hash(left, top, right, bottom);

  @override
  String toString() => 'DBox($left, $top, $right, $bottom)';
}
