import 'package:meta/meta.dart';

/// Schematic canvas coordinate. INTEGER grid units, `1 gu = Len(2_500_000)`
/// (CR-004). No sub-grid, no sx/sy, no free positioning.
@immutable
final class Pt {
  const Pt(this.gx, this.gy);

  final int gx;
  final int gy;

  Pt operator +(Pt other) => Pt(gx + other.gx, gy + other.gy);
  Pt operator -(Pt other) => Pt(gx - other.gx, gy - other.gy);

  @override
  bool operator ==(Object other) =>
      other is Pt && other.gx == gx && other.gy == gy;

  @override
  int get hashCode => Object.hash(gx, gy);

  @override
  String toString() => 'Pt($gx, $gy)';
}
