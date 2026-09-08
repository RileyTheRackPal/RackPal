// rackpal_ui/src/canvas/plan/plan_calibrate.dart — the two-point pick and
// the typed distance (docs/15 §5, DR-144 §11.143, PLAN-F/1).
//
// ═══════════════════════════════════════════════════════════════════════
// A MODE ON DR-141's SHAPE, CONSUMED BY ITS OWN SECOND CLICK
// ═══════════════════════════════════════════════════════════════════════
// `PlanPinArmController` is the other mode on this canvas and the two look
// alike from outside: a chip, a click on the plan, `Esc` to stop. They
// differ in the one place that matters. The arm mode OUTLIVES each pin by
// design (DR-141 §11.140.2), because sixty drops is sixty pins and the
// chip staying up is what tells the user where to go next. **A calibration
// describes exactly one distance**, so a mode that stayed armed afterwards
// would be offering to recalibrate the plan immediately, which is not a
// workflow anybody has.
//
// So this is not `PlanPinArmController` with a flag. It is the same shape
// with a different lifetime, and DR-144 §11.143.6 says so rather than
// leaving the resemblance to suggest a merge.
//
// ═══════════════════════════════════════════════════════════════════════
// THE POINTS ARE `PxPt` AND THE HOVER IS NOT HERE
// ═══════════════════════════════════════════════════════════════════════
// A pick is two positions in the underlay's own raster, which is what a
// `PlanScale` stores and what survives a pan or a zoom mid-pick. The
// POINTER position between the two clicks is a frame detail with no
// meaning once the gesture ends, so it lives in the canvas state and never
// in this controller: a mode that carried it would notify every listener
// on every mouse move.
//
// ═══════════════════════════════════════════════════════════════════════
// THE BAND, THE CHIP AND THE DIALOG ARE ALL SCREEN CHROME (CR-086)
// ═══════════════════════════════════════════════════════════════════════
// `buildPlanScene` feeds the PDF as well as the display, so a rubber line
// added as a scene op would print on `T1.01`. Same rule and same reason as
// `PlanPinArmChip` and `MarqueeBand`.
import 'package:flutter/material.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/src/canvas/viewport_controller.dart';

/// The calibration pick: on or off, and how much of it has been picked.
///
/// Three states, and the middle one is what the chip exists for:
///
/// | `isActive` | `first` | What the user sees |
/// |---|---|---|
/// | false | null | Nothing. The plan behaves normally |
/// | **true** | **null** | The chip, saying to click one end |
/// | true | a `PxPt` | The chip, and a line following the pointer |
final class PlanCalibrateController extends ChangeNotifier {
  bool _active = false;
  PxPt? _first;

  /// Whether a pick is running. True from [begin] until [cancel].
  bool get isActive => _active;

  /// The end already picked, or null while the mode waits for the first
  /// click.
  PxPt? get first => _first;

  /// Starts a pick. Idempotent by design: pressing `Calibrate…` twice
  /// restarts the pick rather than compounding it, which is what somebody
  /// who has clicked one end and changed their mind will do.
  void begin() {
    _active = true;
    _first = null;
    notifyListeners();
  }

  /// Records the first end.
  ///
  /// A NO-OP WHEN THE MODE IS OFF, so a stray canvas click cannot leave a
  /// half-picked state nothing can finish or see.
  void pickFirst(PxPt at) {
    if (!_active) return;
    _first = at;
    notifyListeners();
  }

  /// Ends the pick: `Esc`, a dialog dismissed, or a calibration committed.
  ///
  /// **THE SAME EXIT FOR ALL THREE**, unlike the arm mode's `dismiss` and
  /// `pinned` pair. There is nothing for this mode to do after a distance
  /// has been typed, so a second method would be a distinction with no
  /// behaviour behind it.
  void cancel() {
    if (!_active && _first == null) return;
    _active = false;
    _first = null;
    notifyListeners();
  }
}

/// What the chip says before either end is picked.
///
/// **THE AFFORDANCE IS DOMAIN KNOWLEDGE AND BELONGS IN THE COPY**
/// (`#633`). "Click two points a known distance apart" leaves the person
/// to think of one; naming the dimensioned wall and the door is the
/// difference between a feature somebody uses and one they close.
const String kCalibrateFirstLabel = 'Click one end of a distance you know';

/// What it says once one end is down.
const String kCalibrateSecondLabel = 'Click the other end';

/// The refusal when both clicks land on the same pixel.
///
/// **IT IS THE MODEL'S OWN CONDITION, NOT A SECOND RULE.**
/// `PlanScale.nanometresPerPixel` returns null when the two points
/// coincide, so a scale built from them would be stored, calibrated and
/// useless. Refusing here keeps the surface and the model agreeing about
/// what is unusable, and the pick stays live so the second end can be
/// moved rather than the whole mode restarted (DR-144 §11.143.6).
const String kCalibrateSamePointRefusal =
    'Those two clicks landed on the same spot. Click the other end '
    'somewhere else.';

/// `PLAN-F/1`'s signpost: what to do next, and how to stop.
final class PlanCalibrateChip extends StatelessWidget {
  const PlanCalibrateChip({
    required this.hasFirst,
    required this.onDismiss,
    super.key,
  });

  /// Whether one end is already down.
  final bool hasFirst;

  final VoidCallback onDismiss;

  /// A stable handle for tests, so a case can tell this chip from the arm
  /// chip: both are `Material` widgets in the same corner of the canvas.
  static const Key chipKey = ValueKey('plan-calibrate-chip');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      key: chipKey,
      elevation: 3,
      borderRadius: BorderRadius.circular(6),
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              hasFirst ? kCalibrateSecondLabel : kCalibrateFirstLabel,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
            const SizedBox(width: 8),
            // HOW TO STOP, BESIDE WHAT TO DO. A mode whose exit is a
            // keystroke nobody mentions is a mode people quit by closing
            // the project.
            IconButton(
              onPressed: onDismiss,
              icon: const Icon(Icons.close, size: 16),
              tooltip: 'Stop calibrating (Esc)',
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}

/// The rubber line between the picked end and the pointer.
///
/// A `Positioned.fill` sibling rather than something the canvas paints,
/// on `MarqueeBand`'s precedent and for CR-086's reason: the scene the
/// canvas builds is the one the PDF backend receives.
final class PlanCalibrateLine extends StatelessWidget {
  const PlanCalibrateLine({
    required this.from,
    required this.to,
    required this.viewport,
    super.key,
  });

  /// The end already picked, in the underlay's pixel space.
  final PxPt? from;

  /// Where the pointer is, in the same space, or null when it is not over
  /// the canvas.
  final PxPt? to;

  final ViewportController viewport;

  /// A stable handle for tests.
  static const Key lineKey = ValueKey('plan-calibrate-line');

  @override
  Widget build(BuildContext context) {
    final a = from;
    final b = to;
    if (a == null || b == null) return const SizedBox.shrink();
    // RESOLVED HERE AND NOT PASSED IN, unlike `MarqueeBand`'s colour, and
    // the difference is which widget lays this out. The band is a sibling
    // of the canvas and its host knows the theme; this line is built by
    // `plan_canvas_screen.dart`, which imports `widgets.dart` on purpose
    // and has no `Theme` to hand. PAL-1 is unaffected either way: it
    // governs what the SCENE may use, and this is chrome.
    final color = Theme.of(context).colorScheme.primary;
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: viewport,
        builder: (context, _) => CustomPaint(
          key: lineKey,
          painter: _LinePainter(a: a, b: b, viewport: viewport, color: color),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  const _LinePainter({
    required this.a,
    required this.b,
    required this.viewport,
    required this.color,
  });

  final PxPt a;
  final PxPt b;
  final ViewportController viewport;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // MAPPED AT PAINT TIME from pixel space, so a pan or a zoom between
    // the two clicks leaves the picked end on the same wall rather than
    // on the same part of the screen.
    final from = viewport.sceneToScreen(DPt(a.px.toDouble(), a.py.toDouble()));
    final to = viewport.sceneToScreen(DPt(b.px.toDouble(), b.py.toDouble()));
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas
      ..drawLine(Offset(from.x, from.y), Offset(to.x, to.y), p)
      // END TICKS, because a bare line does not say WHERE it ends when
      // it is nearly horizontal against the lines an architect already
      // drew.
      ..drawCircle(Offset(from.x, from.y), 4, p)
      ..drawCircle(Offset(to.x, to.y), 4, p);
  }

  @override
  bool shouldRepaint(_LinePainter old) =>
      old.a != a || old.b != b || old.color != color;
}

/// The title the dialog and the row action both use.
///
/// TWO WORDS, ONE RULE (DR-144 §11.143.4): `Calibrate` when there is no
/// scale and `Recalibrate` when there is, which is the same distinction
/// `SetPlanScaleCommand` makes for the Edit menu. Deriving both from one
/// function is what stops the button and the undo entry disagreeing about
/// what just happened.
String calibrateActionLabel({required bool alreadyCalibrated}) =>
    alreadyCalibrated ? 'Recalibrate…' : 'Calibrate…';

/// What the underlay row prints about its own calibration.
///
/// **PRESENT IN BOTH DIRECTIONS**, which is DR-144 §11.143.4 and G4: an
/// uncalibrated plan is a fact worth stating, not an absence worth
/// hiding, and a row that said nothing would leave "no scale yet" and "a
/// scale I have forgotten about" looking identical.
///
/// A SCALE THAT CANNOT YIELD A LENGTH READS AS UNCALIBRATED, because that
/// is what it is: `PlanScale.isUsable` is false when the two points
/// coincide or the distance is not positive, and a row calling that
/// "calibrated" would promise a length the model refuses to derive.
const String kCalibratedLabel = 'Calibrated';
const String kUncalibratedLabel = 'Not calibrated';

String calibrationStateLabel(PlanUnderlay underlay) =>
    underlay.isCalibrated ? kCalibratedLabel : kUncalibratedLabel;

/// The helper line under the field, and the reason this dialog exists
/// rather than an inline box on the canvas.
const String kCalibrateHelp =
    'A dimensioned wall is the best thing to measure. If there is none, a '
    'door is almost always 32 or 36 inches.';

/// Asks for the distance between the two picked points.
///
/// Returns the `Len` typed, or null when the person backed out. **The
/// parse lives in core** (`parseDistanceEntry`), because what it enforces
/// is CR-001 and G4 rather than anything about a text field, and a surface
/// holding that rule would be a second copy of it.
Future<Len?> showCalibrateDistanceDialog(
  BuildContext context, {
  required String planName,
  required UnitSystem units,
  required bool alreadyCalibrated,
}) => showDialog<Len>(
  context: context,
  builder: (context) => CalibrateDistanceDialog(
    planName: planName,
    units: units,
    alreadyCalibrated: alreadyCalibrated,
  ),
);

/// The dialog itself, public so a widget test can pump it without a route.
final class CalibrateDistanceDialog extends StatefulWidget {
  const CalibrateDistanceDialog({
    required this.planName,
    required this.units,
    required this.alreadyCalibrated,
    super.key,
  });

  final String planName;
  final UnitSystem units;
  final bool alreadyCalibrated;

  /// Stable handles for tests, so a case names the control rather than
  /// whichever `TextField` the tree happens to hold first.
  static const Key fieldKey = ValueKey('calibrate-distance-field');
  static const Key commitKey = ValueKey('calibrate-distance-commit');

  @override
  State<CalibrateDistanceDialog> createState() =>
      _CalibrateDistanceDialogState();
}

class _CalibrateDistanceDialogState extends State<CalibrateDistanceDialog> {
  final TextEditingController _text = TextEditingController();

  /// The refusal to show, or null when the field parses.
  ///
  /// **NOT SHOWN UNTIL SOMETHING IS TYPED.** An empty field on a dialog
  /// that has just opened is not a mistake anybody has made yet, and
  /// greeting somebody with an error is how a form teaches them to ignore
  /// its errors.
  String? _refusal;
  Len? _value;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _reread(String raw) {
    if (raw.trim().isEmpty) {
      setState(() {
        _refusal = null;
        _value = null;
      });
      return;
    }
    final result = parseDistanceEntry(raw, widget.units);
    setState(() {
      switch (result) {
        case DistanceRead(:final value):
          _value = value;
          _refusal = null;
        case DistanceRefused(:final reason):
          _value = null;
          _refusal = reason;
      }
    });
  }

  void _commit() {
    final value = _value;
    if (value == null) return;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final imperial = widget.units == UnitSystem.imperial;
    return AlertDialog(
      title: Text(
        widget.alreadyCalibrated
            ? 'Recalibrate ${widget.planName}'
            : 'Calibrate ${widget.planName}',
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Type the real distance between the two points you '
            'picked.',
          ),
          const SizedBox(height: 12),
          TextField(
            key: CalibrateDistanceDialog.fieldKey,
            controller: _text,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Distance',
              // THE HINT IS AN EXAMPLE WITH ITS UNIT IN IT, which is the
              // cheapest way to teach the one rule this field has: a bare
              // number is refused, because 36 is 36 inches or 36 feet and
              // the two differ by twelve (DR-144 §11.143.5).
              hintText: imperial ? '3\' 6"' : '2.4 m',
              errorText: _refusal,
            ),
            onChanged: _reread,
            onSubmitted: (_) => _commit(),
          ),
          const SizedBox(height: 12),
          Text(
            kCalibrateHelp,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        // DISABLED RATHER THAN REFUSING ON PRESS. The refusal is already
        // under the field in the person's own words, and a button that
        // accepted the press and then said no would make them read the
        // same sentence twice.
        FilledButton(
          key: CalibrateDistanceDialog.commitKey,
          onPressed: _value == null ? null : _commit,
          child: Text(widget.alreadyCalibrated ? 'Recalibrate' : 'Calibrate'),
        ),
      ],
    );
  }
}
