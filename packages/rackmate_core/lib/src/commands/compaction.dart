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
// shrink planner (rack_shrink.dart) calls this once per face IN SEQUENCE,
// threading each call's targets into the next through [alreadyPlanned] —
// two calls planned against the same starting positions would both reach
// for U1 and compose into an overlap. Neither caller is "the" caller; the
// parameter is required so neither can drift into assuming the other's
// convention.
//
// WHAT MOVES IS THE BOLTED SET; WHAT IT MUST CLEAR IS THE RACK.
// `catalog_placement.dart` carries two scans on purpose:
// `elevationOccupantsOnFace` answers "what occupies this elevation" (what
// the canvas draws, what the chip strip counts, what `findBlockingOccupant`
// refuses to drop onto), and `boltedOccupantsOnFace` answers "what is
// bolted to these rails". This planner needs BOTH, for two different
// questions, and conflating them either way produces a wrong plan:
//
//  * MOVERS come from the bolted scan, because a mover's face is written
//    straight back into a placement — a `CompactionMove` becomes
//    `MoveDeviceCommand(fromFace:, toFace:)` (see [compactionCommands]).
//    Planning the rear elevation by elevation footprint would UNBOLT every
//    front-mounted `side: both` device and re-hang it on the rear rails —
//    a far larger edit than "close the gaps", out of a preview that showed
//    only vertical movement.
//
//  * OBSTACLES come from the elevation scan, on BOTH faces (see
//    [_anchors]). A `side: both` device bolted to the front is DRAWN on
//    the rear (CR-036), so a rear compaction that packed through it would
//    propose a target `findBlockingOccupant` refuses — a preview showing a
//    device sliding into space another device is visibly standing in. And
//    the same is true in reverse: moving a full-depth device down the
//    front elevation moves its REAR block too, so the target has to be
//    free on every face that draws it, not just the one being planned.
//
// A device is never an obstacle to ITSELF. Its front block and its rear
// block are one object at one U; anchoring the elevation set wholesale
// would pin every `side: both` device against its own reflection and make
// Compact Down a permanent no-op on the shipped starters, 19 of whose 27
// RK-1 devices are `side: both`. The obstacle set is therefore the
// elevation set MINUS the movers, per face.
import 'package:rackmate_core/src/commands/catalog_placement.dart';
import 'package:rackmate_core/src/commands/device_commands.dart';
import 'package:rackmate_core/src/derived/device_loads.dart';
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
  /// the top; closing a 1U gap that is entirely below a LOCKED anchor —
  /// or below a device the OTHER face bolted and this one merely draws —
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

/// One device's footprint across BOTH elevations — its height on each
/// face, `0` where that elevation does not draw it at all.
///
/// The planner reasons in footprints rather than in a single `deviceH`
/// because a move relocates the whole object: a `side: both` device packed
/// down the front elevation takes its rear block with it, and the rear
/// block has to land somewhere free too.
typedef _Foot = ({int front, int rear});

int _footOn(_Foot foot, Face face) =>
    face == Face.front ? foot.front : foot.rear;

/// The U a footprint spans IN THE STACK — the taller of its two faces.
/// A move must fit THIS inside the rack, even when the face being planned
/// is the shorter one, or a `frontU 1 / rearU 4` device compacted on the
/// front elevation lands with three U of itself above the rack top.
int _stackH(_Foot foot) => foot.front > foot.rear ? foot.front : foot.rear;

/// True when `[start, start + h - 1]` overlaps any range in [ranges].
bool _hits(int start, int h, List<(int, int)> ranges) {
  final end = start + h - 1;
  for (final (lo, hi) in ranges) {
    if (start <= hi && end >= lo) return true;
  }
  return false;
}

/// True when placing [foot] with its bottom U at [t] would straddle
/// occupied U on ANY elevation that draws it.
bool _straddles(int t, _Foot foot, Map<Face, List<(int, int)>> blockers) {
  for (final f in Face.values) {
    final h = _footOn(foot, f);
    if (h <= 0) continue; // that elevation does not draw it: nothing to clear
    if (_hits(t, h, blockers[f]!)) return true;
  }
  return false;
}

/// Records [foot] at [t] as occupied on every elevation that draws it, so
/// the rest of the pass packs around it.
void _occupy(Map<Face, List<(int, int)>> blockers, int t, _Foot foot) {
  for (final f in Face.values) {
    final h = _footOn(foot, f);
    if (h > 0) blockers[f]!.add((t, t + h - 1));
  }
}

/// The lowest target `>= from` at which [foot] fits below [heightU]
/// without straddling anything in [blockers] on any face, or null when
/// none does.
///
/// A linear scan rather than interval arithmetic: `heightU` is bounded at
/// 60 (CR-038) and the blocker list is short, so the scan is trivially
/// cheap and — more importantly — obviously correct to read, which matters
/// for code whose output the user is about to accept sight-unseen.
int? _lowestFit(
  int from,
  _Foot foot,
  int heightU,
  Map<Face, List<(int, int)>> blockers,
) {
  final stack = _stackH(foot);
  for (var t = from < 1 ? 1 : from; t + stack - 1 <= heightU; t++) {
    if (!_straddles(t, foot, blockers)) return t;
  }
  return null;
}

/// The mirror of [_lowestFit]: the highest target whose stack TOP is `<=
/// fromTop` and whose bottom is `>= 1`, or null when none fits.
int? _highestFit(
  int fromTop,
  _Foot foot,
  int heightU,
  Map<Face, List<(int, int)>> blockers,
) {
  final stack = _stackH(foot);
  var top = fromTop > heightU ? heightU : fromTop;
  for (; top - stack + 1 >= 1; top--) {
    final t = top - stack + 1;
    if (!_straddles(t, foot, blockers)) return t;
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
///
/// [alreadyPlanned] lets a caller that is composing BOTH faces into one
/// physical change — `rack_shrink.dart`, and nothing else — hand this call
/// the targets its companion call already assigned, keyed by device id.
/// Devices this call does not move are then anchored where the composed
/// layout will actually put them rather than where the document currently
/// has them, which is what keeps two independently-planned faces from
/// packing two full-depth devices into the same U. It never affects which
/// devices move; it only relocates obstacles. Leave it empty for the
/// toolbar's one-face-at-a-time Compact Up/Down, whose preview is the
/// whole change.
CompactionPlan planCompaction({
  required Rack rack,
  required Iterable<DeviceInstance> devices,
  required Face face,
  required Map<String, TemplateSnapshot> templates,
  required CompactDirection direction,
  Map<Uuid, int> alreadyPlanned = const {},
}) {
  final heightU = rack.heightU;
  // WHAT MOVES: only what is BOLTED to this face's rails. A move becomes a
  // `MoveDeviceCommand(fromFace:, toFace:)` (see [compactionCommands]), so
  // planning by elevation footprint instead would re-hang a front-bolted
  // device on the rear rails the moment you compacted the rear view —
  // a far larger edit than "close the gaps", and one the preview would
  // not show. See `catalog_placement.dart`'s two scans.
  final occupants = boltedOccupantsOnFace(
    rack: rack,
    devices: devices,
    face: face,
    templates: templates,
  );
  if (occupants.isEmpty) return CompactionPlan.nothing(direction, face);

  // WHAT IT MUST CLEAR: every elevation, because a move carries the whole
  // device and a `side: both` device is drawn on both (CR-036).
  final elevations = <Face, List<RailOccupant>>{
    for (final f in Face.values)
      f: elevationOccupantsOnFace(
        rack: rack,
        devices: devices,
        face: f,
        templates: templates,
      ),
  };
  final heightOn = <Face, Map<Uuid, int>>{
    for (final f in Face.values)
      f: {for (final o in elevations[f]!) o.device.id: o.deviceH},
  };
  _Foot footOf(Uuid id) => (
    front: heightOn[Face.front]![id] ?? 0,
    rear: heightOn[Face.rear]![id] ?? 0,
  );

  final movers = {for (final o in occupants) o.device.id};
  final anchors = _anchors(
    rack: rack,
    devices: devices,
    elevations: elevations,
    movers: movers,
    alreadyPlanned: alreadyPlanned,
  );

  // The obstacle map the pass packs around: the anchors, plus every LOCKED
  // occupant (CR-034 — immovable, and therefore an obstacle rather than a
  // mover), plus each mover as the pass commits it to a target.
  final blockers = <Face, List<(int, int)>>{
    for (final f in Face.values) f: [...anchors[f]!],
  };
  for (final o in occupants) {
    if (o.locked) _occupy(blockers, o.ruIndex, footOf(o.device.id));
  }

  final moves = <CompactionMove>[];
  final targets = <Uuid, int>{};

  // THE CURSOR STEPS BY THE PLANNED FACE'S HEIGHT, NOT THE STACK'S, and
  // the division of labour is the reason. The cursor's only job is order
  // preservation ON THE ELEVATION BEING COMPACTED (see the file header) —
  // it is not what keeps devices off each other. `blockers` is, on every
  // face at once. Stepping it by the taller face instead would refuse a
  // legal placement rather than an illegal one: a front-only 1U device
  // following a `frontU 1 / rearU 4` neighbour belongs at the next FRONT
  // U, and pushing it three U higher leaves a gap the user is looking
  // straight at with nothing in it.
  switch (direction) {
    case CompactDirection.down:
      var cursor = 1;
      for (final o in occupants) {
        final foot = footOf(o.device.id);
        if (o.locked) {
          final past = o.ruIndex + o.deviceH;
          if (past > cursor) cursor = past;
          targets[o.device.id] = o.ruIndex;
          continue;
        }
        final target = _lowestFit(cursor, foot, heightU, blockers);
        if (target == null) {
          // No legal home at or above the cursor: leave it exactly where
          // it is and step the cursor past it so nothing packs on top.
          final past = o.ruIndex + o.deviceH;
          if (past > cursor) cursor = past;
          targets[o.device.id] = o.ruIndex;
          _occupy(blockers, o.ruIndex, foot);
          continue;
        }
        targets[o.device.id] = target;
        cursor = target + o.deviceH;
        _occupy(blockers, target, foot);
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
        final foot = footOf(o.device.id);
        if (o.locked) {
          final below = o.ruIndex - 1;
          if (below < cursor) cursor = below;
          targets[o.device.id] = o.ruIndex;
          continue;
        }
        final target = _highestFit(cursor, foot, heightU, blockers);
        if (target == null) {
          final below = o.ruIndex - 1;
          if (below < cursor) cursor = below;
          targets[o.device.id] = o.ruIndex;
          _occupy(blockers, o.ruIndex, foot);
          continue;
        }
        targets[o.device.id] = target;
        cursor = target - 1;
        _occupy(blockers, target, foot);
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
    freedU: _freedU(direction, occupants, targets, anchors[face]!),
  );
}

/// Everything a mover must pack AROUND, per elevation — the U ranges this
/// planner may not put anything through, keyed by the face they are drawn
/// on.
///
/// TWO KINDS, and both are immovable for the same reason: this pass cannot
/// relocate them, so a target that straddles one is a target the drop
/// evaluator would refuse.
///
/// 1. WHAT THE OTHER FACE BOLTED AND THIS ONE DRAWS (CR-036). Every
///    occupant of every elevation that is not in [movers]. A `side: both`
///    device bolted to the front is drawn across the rear at the same U;
///    `findBlockingOccupant` refuses a drop onto it, and so must a
///    compaction preview. It is listed on each face that DRAWS it, at that
///    face's own height, so a `frontU 2 / rearU 0` occupant blocks two
///    front U and no rear U at all — exactly what the canvas shows.
///
/// 2. WHAT NO ELEVATION CAN MODEL. A rail-placed device in this rack whose
///    `templates['<id>@<version>']` snapshot is missing, or that resolves
///    to zero U on both faces. The scans skipping it is right for their
///    own callers and catastrophic here — without this, Compact Down
///    happily packs a device straight THROUGH the U range of a device it
///    simply could not see, producing an overlap the user never approved
///    out of a preview that showed no conflict. Its height is unknowable
///    without a template, so it claims the single U it is certainly
///    standing on: an under-claim that can still leave an overlap, but one
///    that strictly beats pretending the rails are empty. It claims that U
///    on the rails it is BOLTED to (`boltedRailFace`), the only thing
///    about it the document states.
///
/// [movers] IS SUBTRACTED, AND THAT IS THE WHOLE CARE OF IT. A device is
/// not an obstacle to itself: its front block and its rear block are one
/// object at one U, and a set that kept them would pin every `side: both`
/// device against its own reflection — Compact Down would propose nothing,
/// forever, on any rack whose devices are full depth.
Map<Face, List<(int, int)>> _anchors({
  required Rack rack,
  required Iterable<DeviceInstance> devices,
  required Map<Face, List<RailOccupant>> elevations,
  required Set<Uuid> movers,
  required Map<Uuid, int> alreadyPlanned,
}) {
  final out = {for (final f in Face.values) f: <(int, int)>[]};
  final modelled = <Uuid>{};
  for (final f in Face.values) {
    for (final o in elevations[f]!) {
      modelled.add(o.device.id);
      if (movers.contains(o.device.id)) continue;
      final ru = alreadyPlanned[o.device.id] ?? o.ruIndex;
      out[f]!.add((ru, ru + o.deviceH - 1));
    }
  }
  for (final d in devices) {
    if (modelled.contains(d.id)) continue;
    if (d.placement case RailPlacement(
      :final rackId,
      :final ruIndex,
    ) when rackId == rack.id) {
      final bolted = boltedRailFace(d);
      if (bolted == null) continue;
      final ru = alreadyPlanned[d.id] ?? ruIndex;
      out[bolted]!.add((ru, ru));
    }
  }
  return out;
}

/// [CompactionPlan.freedU]'s definition, kept beside the planner so the
/// two cannot drift.
///
/// [immovable] is [_anchors]' list FOR THE PLANNED FACE — what this
/// elevation draws and this pass may not move. Anchors never move, so they
/// cap the run in both directions: a rack whose highest thing is a device
/// this planner cannot see — or one it can see perfectly well and simply
/// may not move, because it is bolted to the other rails — has not gained
/// the U above it just because everything that DID move packed down below.
///
/// The other face's anchor list is deliberately NOT folded in. This number
/// is a run on ONE elevation and is spent on that elevation: a front-only
/// blank really does fit above a front stack whose rear neighbour still
/// reaches higher. A caller combining faces re-derives the rack's own
/// floor instead — see [CompactionPlan.freedU].
int _freedU(
  CompactDirection direction,
  List<RailOccupant> occupants,
  Map<Uuid, int> targets,
  List<(int, int)> immovable,
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
      for (final (_, hi) in immovable) {
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
      for (final (lo, _) in immovable) {
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
