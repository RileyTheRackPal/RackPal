// rackpal_ui/src/canvas/plan/plan_outline.dart — drawing a room's shape
// on the plan (DR-050 §11.49, `LEN-A/4`).
//
// ═══════════════════════════════════════════════════════════════════════
// THE THIRD MODE ON THIS CANVAS, AND THE THIRD LIFETIME
// ═══════════════════════════════════════════════════════════════════════
// `PlanPinArmController` OUTLIVES each pin, because sixty drops is sixty
// pins and the chip staying up is what tells the user where to go next.
// `PlanCalibrateController` is consumed by its own second click, because
// a calibration describes exactly one distance.
//
// This one accumulates until the shape closes: a room has as many corners
// as it has, and nothing but the person drawing it knows how many. So the
// mode ends on an explicit act rather than on a count, and
// `plan_calibrate.dart`'s note applies here too — this is not that
// controller with a flag, it is the same shape with a different lifetime,
// and saying so is what stops somebody merging the three.
//
// `PlanReshapeController` is the FOURTH, added at `LEN-A/8`, and it is the
// emptiest of them: two fields and no geometry at all. It outlives each
// drag the way the arm mode outlives each pin, because a person correcting
// one corner of a room is usually correcting two.
//
// ═══════════════════════════════════════════════════════════════════════
// CLOSING IS A CLICK ON THE FIRST VERTEX (ruled by the user, 2026-09-11)
// ═══════════════════════════════════════════════════════════════════════
// The convention in every drawing tool, and it is its own affordance: the
// cursor arriving back at the corner you started from is the instruction.
// The hit radius is the canvas's, not this controller's — a radius is
// measured in screen pixels against a viewport, and a mode that carried
// one would be answering a question it cannot see the zoom for.
//
// ═══════════════════════════════════════════════════════════════════════
// `Esc` CANCELS THE WHOLE OUTLINE. RIGHT-CLICK TAKES BACK ONE VERTEX
// ═══════════════════════════════════════════════════════════════════════
// Also the user's call, and better than either option put to them. `Esc`
// already means *cancel the live mode* on this canvas for the arm and for
// the calibration, and there is ONE `planCancel` binding in the keymap
// registry carrying that meaning; a mode that made it mean *undo one step*
// would give one key two behaviours depending on which mode was live.
//
// Right-click is free here — `onSecondaryTap` is on `CanvasIntentDetector`
// and the plan canvas has never used it — and stepping back a vertex is
// what it does in the tools this is imitating.
import 'package:flutter/material.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/src/canvas/viewport_controller.dart';

/// The room-outline draw: which room, and the corners so far.
///
/// Three states, and the middle one is what the chip exists for:
///
/// | `isActive` | `vertices` | What the user sees |
/// |---|---|---|
/// | false | empty | Nothing. The plan behaves normally |
/// | **true** | **empty** | The chip, saying to click the first corner |
/// | true | some | The chip, the corners, and a line to the pointer |
final class PlanOutlineController extends ChangeNotifier {
  bool _active = false;
  Uuid? _locationId;
  final List<PxPt> _vertices = [];

  /// Whether a draw is running. True from [begin] until [cancel] or
  /// [takeClosed].
  bool get isActive => _active;

  /// The room being drawn, or null when the mode is off.
  Uuid? get locationId => _locationId;

  /// The corners picked so far, oldest first.
  ///
  /// UNMODIFIABLE, because `RoomOutline` copies its list and a caller
  /// handed the live one could edit the mode's state through a read. The
  /// same lesson `acceptedFamilies` taught, one layer up.
  List<PxPt> get vertices => List<PxPt>.unmodifiable(_vertices);

  /// Whether enough corners are down for [takeClosed] to yield a shape.
  ///
  /// **THE MODEL'S OWN CONDITION, NOT A SECOND RULE.**
  /// `RoomOutline.isUsable` is three vertices because a point has no
  /// extent and two points are a line, and `SetRoomOutlineCommand`
  /// refuses anything less. Asking the same question here is what stops
  /// the surface offering a close the command would decline.
  bool get canClose => _vertices.length >= 3;

  /// Starts a draw on [locationId].
  ///
  /// Idempotent on `PlanCalibrateController.begin`'s reasoning: pressing
  /// the affordance twice restarts rather than compounding, which is what
  /// somebody who has placed two corners and changed their mind will do.
  void begin(Uuid locationId) {
    _active = true;
    _locationId = locationId;
    _vertices.clear();
    notifyListeners();
  }

  /// Adds a corner.
  ///
  /// A NO-OP WHEN THE MODE IS OFF, so a stray canvas click cannot leave a
  /// half-drawn state nothing can finish or see.
  void addVertex(PxPt at) {
    if (!_active) return;
    _vertices.add(at);
    notifyListeners();
  }

  /// Takes back the most recent corner. Right-click.
  ///
  /// **THE MODE STAYS ON AT ZERO VERTICES**, which is the difference
  /// between this and `Esc`. Somebody who right-clicks four times has
  /// stepped back to the beginning of a draw they are still in; somebody
  /// who pressed `Esc` has left.
  void removeLastVertex() {
    if (!_active || _vertices.isEmpty) return;
    _vertices.removeLast();
    notifyListeners();
  }

  /// The finished shape, and the mode ends.
  ///
  /// Null when [canClose] is false, and the mode is LEFT RUNNING in that
  /// case: a person who clicked the first corner again with two down
  /// meant to close, and throwing their two corners away would be
  /// answering a mistake with a deletion.
  ({Uuid locationId, RoomOutline outline})? takeClosed(Uuid underlayId) {
    if (!_active || !canClose) return null;
    final out = (
      locationId: _locationId!,
      outline: RoomOutline(underlayId: underlayId, vertices: _vertices),
    );
    _active = false;
    _locationId = null;
    _vertices.clear();
    notifyListeners();
    return out;
  }

  /// Ends the draw with nothing written. `Esc`, or the affordance again.
  void cancel() {
    if (!_active && _vertices.isEmpty) return;
    _active = false;
    _locationId = null;
    _vertices.clear();
    notifyListeners();
  }
}

/// Which room's corners are grabbable right now (DR-050 §11.49,
/// `LEN-A/8`).
///
/// ═══════════════════════════════════════════════════════════════════════
/// TWO FIELDS AND NO GEOMETRY, WHICH IS THE POINT
/// ═══════════════════════════════════════════════════════════════════════
/// A drag's live corner moves at pointer rate and has no meaning once the
/// pointer comes up, so it lives on the canvas beside `_calibrateHover`
/// and `_outlineHover` for the reason those do: a mode carrying it would
/// notify every listener at pointer rate for a frame detail.
///
/// What is left is exactly what somebody other than the canvas needs: is
/// the mode on, so the chip shows and `Esc` has something to mean, and
/// which room is it on, so the canvas knows whose corners to offer.
///
/// ═══════════════════════════════════════════════════════════════════════
/// WHY THERE IS A MODE AT ALL, WHICH IS A RULING (the user, 2026-09-11)
/// ═══════════════════════════════════════════════════════════════════════
/// The cheap alternative was to make every finished corner draggable all
/// the time. It was put to the user with its costs and refused, on two
/// counts:
///
///   * **A pin and a corner are both points.** A plate pinned within the
///     grab radius of a corner makes one of the two unreachable, and
///     whichever way that tie is broken somebody loses a gesture they can
///     see sitting there.
///   * **A stray drag would reshape a room silently, and a room's shape is
///     a number on a quote.** `estimatedRunLengthFromRack` is re-derived
///     from the shape on release, so an accidental nudge moves a figure
///     somebody is about to spend money on. A mode cannot be entered by
///     accident, and that is the whole of what it buys.
final class PlanReshapeController extends ChangeNotifier {
  bool _active = false;
  Uuid? _locationId;

  /// Whether a reshape is running. True from [begin] until [cancel].
  bool get isActive => _active;

  /// The room whose corners are grabbable, or null when the mode is off.
  Uuid? get locationId => _locationId;

  /// Starts a reshape on [locationId].
  ///
  /// Idempotent on `PlanCalibrateController.begin`'s reasoning, and
  /// switching rooms mid-mode is the same call: the mode describes exactly
  /// one room and the most recent press names it.
  void begin(Uuid locationId) {
    _active = true;
    _locationId = locationId;
    notifyListeners();
  }

  /// Ends the reshape: `Esc`, the chip, or a mode the host opens instead.
  ///
  /// **A COMMITTED DRAG DOES NOT END IT**, unlike
  /// [PlanOutlineController.takeClosed].
  /// A room has as many corners as it has, and somebody who is correcting
  /// one is usually correcting the one beside it; ending on the first
  /// release would make the ordinary case a button press per corner.
  void cancel() {
    if (!_active && _locationId == null) return;
    _active = false;
    _locationId = null;
    notifyListeners();
  }
}

/// What the chip says before any corner is down.
///
/// **THE AFFORDANCE IS DOMAIN KNOWLEDGE AND BELONGS IN THE COPY**
/// (`#633`), which is `kCalibrateFirstLabel`'s rule. "Click the corners"
/// leaves a person to guess how the shape ends; naming the first corner
/// as the way to close it is the whole instruction.
const String kOutlineFirstLabel = 'Click each corner of the room';

/// What it says once corners are down but a close is not yet legal.
const String kOutlineMoreLabel = 'Keep clicking corners: a room needs three';

/// What it says once closing is possible.
///
/// **SHORTER THAN IT WANTS TO BE, AND A TEST IS WHY.** The first draft
/// read *"Click the first corner again to close. Right-click takes one
/// back"* and overflowed the chip's `Row` by 70 pixels at an 800-point
/// canvas. The `Flexible` below is the structural fix; this is the other
/// half, because a chip that ellipsises its own instruction has not given
/// it.
const String kOutlineCloseLabel =
    'Click the first corner to close · Right-click undoes one';

/// `LEN-A/4`'s signpost: what to do next, and how to stop.
final class PlanOutlineChip extends StatelessWidget {
  const PlanOutlineChip({
    required this.vertexCount,
    required this.canClose,
    required this.onDismiss,
    super.key,
  });

  /// How many corners are down.
  final int vertexCount;

  /// Whether [PlanOutlineController.takeClosed] would yield a shape.
  final bool canClose;

  final VoidCallback onDismiss;

  /// A stable handle for tests, so a case can tell this chip from the
  /// other two: all three are `Material` widgets in the same corner.
  static const Key chipKey = ValueKey('plan-outline-chip');

  /// The line a person reads, chosen from how far along they are.
  String get label {
    if (vertexCount == 0) return kOutlineFirstLabel;
    return canClose ? kOutlineCloseLabel : kOutlineMoreLabel;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      key: chipKey,
      color: theme.colorScheme.secondaryContainer,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // FLEXIBLE, BECAUSE THE LONGEST LABEL OVERFLOWED. A chip
            // sits on a canvas whose width is the window's, and this Row
            // is `MainAxisSize.min` with a fixed-width button beside it:
            // on a narrow canvas the text is the only thing that can
            // give.
            Flexible(
              child: Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.close, size: 16),
              tooltip: 'Stop drawing (Esc)',
              onPressed: onDismiss,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}

/// What the reshape chip says.
///
/// **THE AFFORDANCE IS DOMAIN KNOWLEDGE AND BELONGS IN THE COPY**
/// (`#633`), on [kOutlineFirstLabel]'s rule. "Reshaping" would name the
/// mode rather than the act; naming the corner as the thing to drag is the
/// whole instruction, and there is only one.
const String kReshapeLabel = 'Drag a corner to correct the room';

/// `LEN-A/8`'s signpost: what to do, and how to stop.
final class PlanReshapeChip extends StatelessWidget {
  const PlanReshapeChip({required this.onDismiss, super.key});

  final VoidCallback onDismiss;

  /// A stable handle for tests, so a case can tell this chip from the
  /// other three: all four are `Material` widgets in the same corner.
  static const Key chipKey = ValueKey('plan-reshape-chip');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      key: chipKey,
      color: theme.colorScheme.secondaryContainer,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // FLEXIBLE, for the reason `PlanOutlineChip` carries in full:
            // a chip sits on a canvas whose width is the window's, and on
            // a narrow one the text is the only thing that can give.
            Flexible(
              child: Text(
                kReshapeLabel,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.close, size: 16),
              tooltip: 'Stop reshaping (Esc)',
              onPressed: onDismiss,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}

/// How near the first corner a click has to land to CLOSE the shape.
///
/// ═══════════════════════════════════════════════════════════════════════
/// SCREEN POINTS, NOT PIXELS OF THE RASTER, AND THAT IS THE WHOLE POINT
/// ═══════════════════════════════════════════════════════════════════════
/// A person aims with a mouse at what they can see. Ten raster pixels is
/// an easy target on a plan zoomed to 400% and an impossible one on the
/// same plan fitted to the window, so a radius in the underlay's own
/// space would make closing a shape harder the further out you were
/// looking. Measured against the viewport, it is the same ten points of
/// travel at every zoom.
///
/// TEN, which is the ordinary desktop hit slop and is larger than the
/// four-point marker `plan_scene.dart` draws: the target a person aims at
/// is the corner, and the dot is only how it is advertised.
const double kOutlineCloseRadiusPt = 10;

/// How near a corner a PRESS has to land to GRAB it (`LEN-A/8`).
///
/// SCREEN POINTS, for [kOutlineCloseRadiusPt]'s reason exactly, and that
/// comment is the long version.
///
/// **ITS OWN CONSTANT THOUGH IT HOLDS THE SAME NUMBER**, deliberately.
/// *Is this click closing the shape* and *is this press grabbing a corner*
/// are two questions that happen to share an answer today. One constant
/// serving both would mean a change made for either silently moves the
/// other, and this file already carries a note about three modes that look
/// like one another and must not be merged.
const double kOutlineGrabRadiusPt = 10;

/// The room outlines on this plan, and the one being drawn.
///
/// ═══════════════════════════════════════════════════════════════════════
/// CHROME, NOT SCENE, AND FOR BOTH HALVES (CR-086)
/// ═══════════════════════════════════════════════════════════════════════
/// The in-progress shape is chrome for the reason every transient mode on
/// this canvas is: `buildPlanScene` feeds `T1.01` as well as the display,
/// so an op added for a live gesture would print on somebody's sheet.
///
/// **THE FINISHED OUTLINE IS CHROME TOO, AND THAT IS A RULING RATHER THAN
/// AN OVERSIGHT.** An outline is an estimating aid, and `T1.01`'s exit
/// criterion is that a stranger locates every drop from the printed
/// sheet; a room boundary does not serve that and a wrong-weight line
/// over a screened underlay works against AC-054's legibility standard.
///
/// **AND IT IS SETTLED RATHER THAN DEFERRED** (§11.49.9, `LEN-A/7`). The
/// chapter that was to decide it with a printed sheet in hand was
/// answered without one, on a fact about the drawings rather than about
/// our ink: **almost every floorplan already labels its rooms**, so the
/// architect's own titles say which space is which and a boundary of ours
/// would spend ink on what the sheet already carries. `buildPlanScene`
/// grows no parameter, every caller is unchanged, and the four
/// byte-verified starter goldens stay shut.
final class PlanOutlineLayer extends StatelessWidget {
  const PlanOutlineLayer({
    required this.finished,
    required this.drawing,
    required this.hover,
    required this.viewport,
    required this.canClose,
    this.handles = const <PxPt>[],
    super.key,
  });

  /// Every outline already stored on this underlay.
  ///
  /// **WITH THE RESHAPING ROOM'S SHAPE ALREADY SUBSTITUTED** for the live
  /// one, which is why this list arrives built rather than read here.
  final List<RoomOutline> finished;

  /// The corners to advertise as grabbable, empty when no reshape runs.
  ///
  /// PASSED IN RATHER THAN LOOKED UP FROM A ROOM ID, for the same reason
  /// [finished] is: a layer that read the document would draw the handles
  /// at the COMMITTED corners while the outline under them moved.
  final List<PxPt> handles;

  /// The corners of the draw in progress, oldest first. Empty when no
  /// draw is running.
  final List<PxPt> drawing;

  /// Where the pointer is, for the rubber segment from the last corner.
  final PxPt? hover;

  final ViewportController viewport;

  /// Whether a click on the first corner would close the shape, which is
  /// what the first corner's ring advertises.
  final bool canClose;

  /// A stable handle for tests.
  static const Key layerKey = ValueKey('plan-outline-layer');

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: viewport,
        builder: (context, _) => CustomPaint(
          key: layerKey,
          painter: _OutlinePainter(
            finished: finished,
            handles: handles,
            drawing: drawing,
            hover: hover,
            viewport: viewport,
            canClose: canClose,
            settled: scheme.tertiary,
            live: scheme.primary,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _OutlinePainter extends CustomPainter {
  const _OutlinePainter({
    required this.finished,
    required this.handles,
    required this.drawing,
    required this.hover,
    required this.viewport,
    required this.canClose,
    required this.settled,
    required this.live,
  });

  final List<RoomOutline> finished;
  final List<PxPt> handles;
  final List<PxPt> drawing;
  final PxPt? hover;
  final ViewportController viewport;
  final bool canClose;
  final Color settled;
  final Color live;

  Offset _at(PxPt p) {
    // MAPPED AT PAINT TIME from pixel space, so a pan or a zoom mid-draw
    // leaves each corner on the same wall rather than the same part of
    // the screen. `PlanCalibrateLine` does the same and for the same
    // reason.
    final s = viewport.sceneToScreen(DPt(p.px.toDouble(), p.py.toDouble()));
    return Offset(s.x, s.y);
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final outline in finished) {
      if (!outline.isUsable) continue;
      canvas.drawPath(
        _closedPath(outline.vertices),
        Paint()
          ..color = settled
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
    // THE GRAB HANDLES, drawn over the settled outlines and under the
    // live draw. Filled rather than stroked, which is how they read as
    // something to take hold of next to the draw mode's hollow corners.
    //
    // **A STARTING VALUE AND NOT A RULING**, on `kPlanMarkerRadiusFraction`'s
    // own note: the appearance of a mark is UI/UX and is the user's.
    for (final h in handles) {
      canvas.drawCircle(
        _at(h),
        4,
        Paint()
          ..color = live
          ..style = PaintingStyle.fill,
      );
    }
    if (drawing.isEmpty) return;

    final pen = Paint()
      ..color = live
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (var i = 1; i < drawing.length; i++) {
      canvas.drawLine(_at(drawing[i - 1]), _at(drawing[i]), pen);
    }
    // THE RUBBER SEGMENT, from the last corner to the pointer. Null when
    // the pointer is off the canvas, which is not a state worth drawing a
    // line into.
    final to = hover;
    if (to != null) canvas.drawLine(_at(drawing.last), _at(to), pen);

    for (final v in drawing) {
      canvas.drawCircle(_at(v), 3, pen);
    }
    // THE FIRST CORNER WEARS A RING ONCE CLOSING IS LEGAL, which is the
    // affordance the copy describes: the target is advertised where the
    // person is about to aim rather than only in the chip.
    if (canClose) {
      canvas.drawCircle(
        _at(drawing.first),
        kOutlineCloseRadiusPt,
        Paint()
          ..color = live
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  Path _closedPath(List<PxPt> vertices) {
    final path = Path()..moveTo(_at(vertices.first).dx, _at(vertices.first).dy);
    for (var i = 1; i < vertices.length; i++) {
      path.lineTo(_at(vertices[i]).dx, _at(vertices[i]).dy);
    }
    // `close()` IS THE MODEL'S IMPLICIT EDGE MADE VISIBLE. `RoomOutline`
    // stores no closing vertex, so the segment from the last corner back
    // to the first exists in exactly one place: here, and in whatever
    // else ever draws one.
    return path..close();
  }

  @override
  bool shouldRepaint(_OutlinePainter old) =>
      !identical(old.handles, handles) ||
      old.hover != hover ||
      old.canClose != canClose ||
      old.drawing.length != drawing.length ||
      !identical(old.finished, finished) ||
      old.settled != settled ||
      old.live != live;
}
