// docs/04-rack-editor.md §3.6 — Compact Down / Compact Up, the PLANNING
// half. Pure Dart: this file computes what WOULD happen and returns it as
// an immutable value; it never mutates a document and never runs a
// command. That split is the whole point — §3.6 requires the operation to
// "never apply silently", opening a preview overlay first ("proposed
// positions as solid ghosts, current positions dimmed to 25%") with an
// Apply/Cancel bar. A planner that mutated as it went could not be
// previewed without a speculative apply-then-undo, which would pollute the
// undo stack with an entry the user never asked for.
//
// LOCKED PLACEMENTS ARE IMMOVABLE ANCHORS (§3.6, CR-034). They never
// appear in [CompactionPlan.moves]; they occupy their U range for the
// whole pass and everything else packs AROUND them, never through them.
//
// COMPACTION PRESERVES RELATIVE ORDER — a decision §3.6 does not make, so
// it is made here explicitly. The pass walks occupants in rack order
// behind a monotonic cursor, so a device can only ever close the gap below
// it (above it, for Compact Up); it can never leapfrog a neighbour to
// reach a lower free run that would "fit it better". Two consequences a
// reader should expect rather than file as bugs: a device stranded above a
// locked anchor stays above it even when the space below is empty, and a
// short device never drops past a tall one. The alternative — greedy
// best-fit — packs marginally tighter and silently REORDERS the user's
// rack, which is a much larger edit than "close the gaps" and is not what
// a button labelled Compact Down offers to do. §3.6 also parks the
// heuristic rearrangers ("Auto-arrange with trade heuristics", "Fill gaps
// with blanks") in v1.2 under AC-045, which is the same line being drawn.
//
// FACE SCOPE, stated once because the asymmetry is deliberate:
// [planCompaction] plans exactly ONE face. The toolbar's Compact Up/Down
// is a visible, previewed operation on the elevation you are actually
// looking at, so the UI passes the currently displayed face. A rack
// SHRINK, by contrast, is a physical change to the whole rack, so the
// shrink planner (rack_shrink.dart) calls this once per face and unions
// the results. Neither caller is "the" caller; the parameter is required
// so neither can drift into assuming the other's convention.
import 'package:rackmate_core/src/commands/catalog_placement.dart';
import 'package:rackmate_core/src/commands/device_commands.dart';
import 'package:rackmate_core/src/model/device_instance.dart';
import 'package:rackmate_core/src/model/placement.dart';
import 'package:rackmate_core/src/model/rack.dart';
import 'package:rackmate_core/src/model/template.dart';
import 'package:rackmate_core/src/units/ids.dart';

/// Which end of the rack occupants pack toward.
enum CompactDirection {
  /// Toward U1 — gaps close downward, free U accumulates at the top.
  down,

  /// Toward `heightU` — gaps close upward, free U accumulates at the
  /// bottom.
  up,
}

/// One proposed relocation. A move is only emitted when
/// [toRuIndex] != [fromRuIndex], so a plan's move list is never padded
/// with no-ops and `CompactionPlan.isEmpty` is a truthful "nothing to do".
final class CompactionMove {
  const CompactionMove({
    required this.deviceId,
    required this.designator,
    required this.fromRuIndex,
    required this.toRuIndex,
    required this.deviceH,
    required this.face,
  });

  final Uuid deviceId;

  /// Carried so the preview overlay and the shrink modal can label a move
  /// without a second document lookup.
  final String designator;
  final int fromRuIndex;
  final int toRuIndex;

  /// The device's height ON [face] — the rear height for a rear-face
  /// move, which is not necessarily the front height (CR-036).
  final int deviceH;
  final Face face;

  /// The highest U this device occupies once the move lands.
  int get toTopRu => toRuIndex + deviceH - 1;

  @override
  String toString() =>
      'CompactionMove($designator ${face.name} U$fromRuIndex->U$toRuIndex '
      '(${deviceH}U))';
}

/// The immutable result of [planCompaction]: what would move, and what the
/// user gains by letting it.
final class CompactionPlan {
  const CompactionPlan({
    required this.direction,
    required this.face,
    required this.moves,
    required this.freedU,
  });

  /// The empty plan for [face]/[direction] — nothing moves, nothing gained.
  const CompactionPlan.nothing(this.direction, this.face)
    : moves = const [],
      freedU = 0;

  final CompactDirection direction;
  final Face face;

  /// Emitted in the order the planner assigned targets (ascending U for
  /// [CompactDirection.down], descending for [CompactDirection.up]).
  final List<CompactionMove> moves;

  /// The CONTIGUOUS run of U gained at this direction's far end — for
  /// [CompactDirection.down], `highestOccupiedBefore -
  /// highestOccupiedAfter`; mirrored for [CompactDirection.up]. This is
  /// what "3U freed" means to a user reading §3.6's floating bar: three
  /// more U they can now actually put something in.
  ///
  /// DELIBERATELY NOT "the sum of gaps closed". Closing a 1U gap between
  /// two devices and a 1U gap above them frees 2U of contiguous space at
  /// the top; closing a 1U gap that is entirely below a LOCKED anchor
  /// frees nothing at the top at all, even though a gap did close. The
  /// number on the bar has to be the one the user can spend.
  ///
  /// AND THEREFORE NOT ADDITIVE ACROSS FACES either — a contiguous run at
  /// one end of one face is not a quantity that sums. Two plans that each
  /// free 3U have between them freed 3U of rack, not 6U, because the rack
  /// top can only come down as far as the taller face still reaches. A
  /// caller that plans both faces (rack_shrink.dart does) must combine
  /// them by re-deriving the rack's own floor from the post-compaction
  /// positions, never by folding these numbers together.
  final int freedU;

  bool get isEmpty => moves.isEmpty;

  /// How many devices move — §3.6's floating bar reads "Compact Up — 4
  /// devices move — 3U freed". Convenience only; the same number
  /// [moves] already carries.
  int get deviceCount => moves.length;
}

/// True when `[start, start + h - 1]` overlaps any range in [locked].
bool _hitsLocked(int start, int h, List<(int, int)> locked) {
  final end = start + h - 1;
  for (final (lo, hi) in locked) {
    if (start <= hi && end >= lo) return true;
  }
  return false;
}

/// The lowest target `>= from` at which a [h]-U device fits below
/// [heightU] without straddling a locked anchor, or null when none does.
///
/// A linear scan rather than interval arithmetic: `heightU` is bounded at
/// 60 (CR-038) and locked anchors are few, so the scan is trivially cheap
/// and — more importantly — obviously correct to read, which matters for
/// code whose output the user is about to accept sight-unseen.
int? _lowestFit(int from, int h, int heightU, List<(int, int)> locked) {
  for (var t = from < 1 ? 1 : from; t + h - 1 <= heightU; t++) {
    if (!_hitsLocked(t, h, locked)) return t;
  }
  return null;
}

/// The mirror of [_lowestFit]: the highest target whose TOP U is `<=
/// fromTop` and whose bottom is `>= 1`, or null when none fits.
int? _highestFit(int fromTop, int h, int heightU, List<(int, int)> locked) {
  var top = fromTop > heightU ? heightU : fromTop;
  for (; top - h + 1 >= 1; top--) {
    final t = top - h + 1;
    if (!_hitsLocked(t, h, locked)) return t;
  }
  return null;
}

/// Plans a compaction of [face] within [rack] in [direction], WITHOUT
/// mutating anything. Feed the result to [compactionCommands] once the
/// user accepts it.
///
/// ALWAYS PLANS AGAINST THE RACK'S REAL HEIGHT. There is deliberately no
/// "plan as if the rack were N U" parameter, though an earlier design
/// called for one so the shrink modal could ask "what would compaction
/// achieve IF the rack were N U?" (docs/04 §4.1 option 1). Such a
/// parameter is actively harmful to that caller: constraining the packer
/// to a smaller height makes it REFUSE to relocate a device that would not
/// fully fit, so an over-tall device stays stranded at the top instead of
/// packing as low as it can — and the shrink planner then reports the rack
/// can only reach U23 when the compacted layout plainly reaches U8. The
/// shrink planner therefore compacts against the real height (the tightest
/// packing available) and evaluates the RESULT against the target height,
/// which is both simpler and strictly more useful. See rack_shrink.dart.
///
/// A device that cannot fit anywhere at or beyond the packing cursor STAYS
/// PUT rather than being dropped, displaced past a locked anchor, or
/// silently pushed out of the rack — compaction never destroys and never
/// evicts (§4.1's "never destroy, never silently move").
CompactionPlan planCompaction({
  required Rack rack,
  required Iterable<DeviceInstance> devices,
  required Face face,
  required Map<String, TemplateSnapshot> templates,
  required CompactDirection direction,
}) {
  final heightU = rack.heightU;
  final occupants = railOccupantsOnFace(
    rack: rack,
    devices: devices,
    face: face,
    templates: templates,
  );
  final unmodelled = _unmodelledAnchors(
    rack: rack,
    devices: devices,
    face: face,
    templates: templates,
  );
  if (occupants.isEmpty) return CompactionPlan.nothing(direction, face);

  final locked = <(int, int)>[
    for (final o in occupants)
      if (o.locked) (o.ruIndex, o.ruIndex + o.deviceH - 1),
    ...unmodelled,
  ];

  final moves = <CompactionMove>[];
  final targets = <Uuid, int>{};

  switch (direction) {
    case CompactDirection.down:
      var cursor = 1;
      for (final o in occupants) {
        if (o.locked) {
          final past = o.ruIndex + o.deviceH;
          if (past > cursor) cursor = past;
          targets[o.device.id] = o.ruIndex;
          continue;
        }
        final target = _lowestFit(cursor, o.deviceH, heightU, locked);
        if (target == null) {
          // No legal home at or above the cursor: leave it exactly where
          // it is and step the cursor past it so nothing packs on top.
          final past = o.ruIndex + o.deviceH;
          if (past > cursor) cursor = past;
          targets[o.device.id] = o.ruIndex;
          continue;
        }
        targets[o.device.id] = target;
        cursor = target + o.deviceH;
        if (target != o.ruIndex) {
          moves.add(
            CompactionMove(
              deviceId: o.device.id,
              designator: o.device.designator,
              fromRuIndex: o.ruIndex,
              toRuIndex: target,
              deviceH: o.deviceH,
              face: face,
            ),
          );
        }
      }

    case CompactDirection.up:
      var cursor = heightU;
      for (final o in occupants.reversed) {
        if (o.locked) {
          final below = o.ruIndex - 1;
          if (below < cursor) cursor = below;
          targets[o.device.id] = o.ruIndex;
          continue;
        }
        final target = _highestFit(cursor, o.deviceH, heightU, locked);
        if (target == null) {
          final below = o.ruIndex - 1;
          if (below < cursor) cursor = below;
          targets[o.device.id] = o.ruIndex;
          continue;
        }
        targets[o.device.id] = target;
        cursor = target - 1;
        if (target != o.ruIndex) {
          moves.add(
            CompactionMove(
              deviceId: o.device.id,
              designator: o.device.designator,
              fromRuIndex: o.ruIndex,
              toRuIndex: target,
              deviceH: o.deviceH,
              face: face,
            ),
          );
        }
      }
  }

  return CompactionPlan(
    direction: direction,
    face: face,
    moves: List.unmodifiable(moves),
    freedU: _freedU(direction, occupants, targets, unmodelled),
  );
}

/// The U ranges of devices rail-placed on [face] of [rack] that
/// [railOccupantsOnFace] cannot model — its template snapshot is missing,
/// or it resolves to zero height on the face it claims to be mounted on.
///
/// TREATED EXACTLY LIKE A LOCKED ANCHOR, because that is what they are:
/// something is bolted to those rails and this planner cannot move it.
/// The scan skipping them is right for its own callers and catastrophic
/// here — without this, Compact Down happily packs a device straight
/// THROUGH the U range of a device it simply could not see, producing an
/// overlap the user never approved out of a preview that showed no
/// conflict. `deviceH` is unknowable without the template, so each anchor
/// claims the single U it is certainly standing on: an under-claim that
/// can still leave an overlap, but one that strictly beats pretending the
/// rails are empty. The complete repair belongs in the shared scan itself
/// (see `railOccupantsOnFace`), which would also close the same hole in
/// `findLowestFreeRu` and `findBlockingOccupant`.
List<(int, int)> _unmodelledAnchors({
  required Rack rack,
  required Iterable<DeviceInstance> devices,
  required Face face,
  required Map<String, TemplateSnapshot> templates,
}) {
  final modelled = <Uuid>{
    for (final f in Face.values)
      for (final o in railOccupantsOnFace(
        rack: rack,
        devices: devices,
        face: f,
        templates: templates,
      ))
        o.device.id,
  };
  return [
    for (final d in devices)
      if (!modelled.contains(d.id))
        if (d.placement case RailPlacement(
          :final rackId,
          :final ruIndex,
          face: final placedFace,
        ) when rackId == rack.id && placedFace == face)
          (ruIndex, ruIndex),
  ];
}

/// [CompactionPlan.freedU]'s definition, kept beside the planner so the
/// two cannot drift.
///
/// [unmodelled] anchors never move, so they cap the run in both
/// directions: a rack whose highest thing is a device this planner cannot
/// see has not gained the U above it just because everything it CAN see
/// packed down below.
int _freedU(
  CompactDirection direction,
  List<RailOccupant> occupants,
  Map<Uuid, int> targets,
  List<(int, int)> unmodelled,
) {
  switch (direction) {
    case CompactDirection.down:
      var topBefore = 0;
      var topAfter = 0;
      for (final o in occupants) {
        final before = o.ruIndex + o.deviceH - 1;
        final after = targets[o.device.id]! + o.deviceH - 1;
        if (before > topBefore) topBefore = before;
        if (after > topAfter) topAfter = after;
      }
      for (final (_, hi) in unmodelled) {
        if (hi > topBefore) topBefore = hi;
        if (hi > topAfter) topAfter = hi;
      }
      final freed = topBefore - topAfter;
      return freed < 0 ? 0 : freed;
    case CompactDirection.up:
      var bottomBefore = 1 << 30;
      var bottomAfter = 1 << 30;
      for (final o in occupants) {
        final before = o.ruIndex;
        final after = targets[o.device.id]!;
        if (before < bottomBefore) bottomBefore = before;
        if (after < bottomAfter) bottomAfter = after;
      }
      for (final (lo, _) in unmodelled) {
        if (lo < bottomBefore) bottomBefore = lo;
        if (lo < bottomAfter) bottomAfter = lo;
      }
      final freed = bottomAfter - bottomBefore;
      return freed < 0 ? 0 : freed;
  }
}

/// Turns an accepted [plan] into the EXISTING [MoveDeviceCommand]s that
/// realise it — no new command type. The caller wraps these in one
/// `Transaction` (docs/04 §3.6: "Enter applies as one undo entry").
///
/// Face never changes: compaction packs a face against itself. Ordering
/// within the list is the plan's own order; intermediate overlap during
/// apply is harmless because [MoveDeviceCommand] rewrites `ruIndex`
/// without re-checking occupancy, and `Transaction.revert` runs children
/// in reverse, so undo restores every original position.
List<MoveDeviceCommand> compactionCommands(
  CompactionPlan plan, {
  required DateTime now,
  required String actor,
}) => [
  for (final m in plan.moves)
    MoveDeviceCommand(
      id: m.deviceId,
      fromRuIndex: m.fromRuIndex,
      toRuIndex: m.toRuIndex,
      fromFace: m.face,
      toFace: m.face,
      now: now,
      actor: actor,
    ),
];
