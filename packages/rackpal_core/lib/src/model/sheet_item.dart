import 'package:rackpal_core/src/units/ids.dart';
import 'package:rackpal_core/src/units/pt.dart';

/// One symbol's placement on the (single, permanent) schematic `Sheet`.
/// THE only symbol position and THE only stacking order (CR-069) — no
/// other type carries a schematic position. No `EntityMeta`: dead weight
/// on a conflict unit this fine-grained (§4.8).
final class SheetItem {
  SheetItem({
    required this.id,
    required this.targetId,
    required this.position,
    required this.zOrder,
    this.rotationQuarterTurns = 0,
    this.collapsed = false,
    this.pinned = false,
    Map<String, Object?>? unknown,
  }) : unknown = unknown ?? {};

  final Uuid id;
  final Uuid targetId;

  // ACCESS CONTROL: fields below are plain mutable pending @internal
  // retrofit (AC-013). Converted as each is wired to a Command. See
  // internal_setter_grep_test.dart.

  /// THE only symbol position (CR-069).
  Pt position;

  /// 0..3 — no float angles.
  int rotationQuarterTurns;
  bool collapsed;

  /// Any manual move sets it; auto-layout never moves a pinned symbol
  /// (CR-068).
  bool pinned;

  /// THE only stacking order.
  FracIndex zOrder;
  final Map<String, Object?> unknown;
}
