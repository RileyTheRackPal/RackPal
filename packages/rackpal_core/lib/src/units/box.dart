import 'package:meta/meta.dart';
import 'package:rackpal_core/src/units/pt.dart';

// M0 minimal shape: the data model doc does not specify Box's fields or
// API beyond "used later by BoundsCanvas" (docs/03-architecture.md line
// 179). This is a deliberately small, obviously-correct axis-aligned
// bounding box: two corners, normalised so gx0 <= gx1 and gy0 <= gy1.
// Extend only when a real consumer (BoundsCanvas, hit-testing) needs more.

/// An axis-aligned bounding box in schematic grid units.
@immutable
final class Box {
  const Box._(this.gx0, this.gy0, this.gx1, this.gy1);

  /// Builds the normalised box spanning two arbitrary corners.
  factory Box.fromCorners(Pt a, Pt b) => Box._(
    a.gx < b.gx ? a.gx : b.gx,
    a.gy < b.gy ? a.gy : b.gy,
    a.gx > b.gx ? a.gx : b.gx,
    a.gy > b.gy ? a.gy : b.gy,
  );

  /// Builds a box from a top-left corner plus width/height.
  const Box.fromLtwh(int gx, int gy, int width, int height)
    : this._(gx, gy, gx + width, gy + height);

  final int gx0;
  final int gy0;
  final int gx1;
  final int gy1;

  int get width => gx1 - gx0;
  int get height => gy1 - gy0;

  Pt get topLeft => Pt(gx0, gy0);
  Pt get bottomRight => Pt(gx1, gy1);

  bool contains(Pt p) =>
      p.gx >= gx0 && p.gx <= gx1 && p.gy >= gy0 && p.gy <= gy1;

  bool intersects(Box other) =>
      gx0 <= other.gx1 &&
      gx1 >= other.gx0 &&
      gy0 <= other.gy1 &&
      gy1 >= other.gy0;

  /// The smallest box containing both this box and [other].
  Box union(Box other) => Box._(
    gx0 < other.gx0 ? gx0 : other.gx0,
    gy0 < other.gy0 ? gy0 : other.gy0,
    gx1 > other.gx1 ? gx1 : other.gx1,
    gy1 > other.gy1 ? gy1 : other.gy1,
  );

  /// Grows (or, with a negative amount, shrinks) every edge by [amount].
  Box inflate(int amount) =>
      Box._(gx0 - amount, gy0 - amount, gx1 + amount, gy1 + amount);

  @override
  bool operator ==(Object other) =>
      other is Box &&
      other.gx0 == gx0 &&
      other.gy0 == gy0 &&
      other.gx1 == gx1 &&
      other.gy1 == gy1;

  @override
  int get hashCode => Object.hash(gx0, gy0, gx1, gy1);

  @override
  String toString() => 'Box($gx0, $gy0, $gx1, $gy1)';
}
