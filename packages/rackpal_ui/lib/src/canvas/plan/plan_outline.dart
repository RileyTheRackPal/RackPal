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
