// rackpal_ui/src/canvas/plan/plan_pin_arm.dart — the drop-table-then-plan
// fast path's mode (docs/15 §6, DR-141 §11.140, PLAN-E/3).
//
// ═══════════════════════════════════════════════════════════════════════
// A MODE, NOT A REQUEST, AND THAT IS A DIFFERENT TYPE FROM THE PRECEDENT
// ═══════════════════════════════════════════════════════════════════════
// `schematic_reveal.dart` is the existing cross-tab mechanism (CR-105's
// "clicking it switches to the schematic WITH THAT DEVICE SELECTED") and
// it is deliberately ONE-SHOT: `take()` empties the request, so one click
// reveals once. Reusing it here was considered and is wrong.
//
// This outlives the pin. DR-141 rules that pinning the armed drop leaves
// the mode ON WITH NOTHING ARMED, because that is what keeps the chip up
// telling the user where to go next; a mode that ended silently after each
// pin would be indistinguishable from one that had failed. `Esc` is the
// only thing that ends it.
//
// ═══════════════════════════════════════════════════════════════════════
// WHY IT IS NOT AN AUTO-ADVANCING QUEUE, WHICH IS THE OBVIOUS DESIGN
// ═══════════════════════════════════════════════════════════════════════
// Pin, advance to the next unpinned outlet, chip reads "Next: D-014",
// sixty drops in sixty clicks. It was offered and declined by the user
// (DR-141 §11.140.2) on the failure mode rather than the ergonomics: a
// mis-click pins the wrong drop AND advances the queue, so the recovery is
// an undo plus a re-arm, and the person going fast is exactly the person
// who will not notice which subject the chip had moved to. **An
// auto-advancing queue is a machine for producing confidently wrong pins
// on a drawing an installer will trust.**
//
// The ergonomic cost that buys is real and is paid elsewhere: DR-140's
// unpinned strip is in the plan view, so the ordinary loop is pick from
// the strip and click the plan, with no view change at all. That strip is
// THE pinning workflow and this is the secondary entry point, for somebody
// already in the Structure editor (§11.140.4).
import 'package:flutter/material.dart';
import 'package:rackpal_core/rackpal_core.dart';

/// What the chip has to be able to say: which drop is armed, named the way
/// the user just saw it in the table.
///
/// THE LABEL IS CARRIED, NOT DERIVED. Resolving a designator needs the
/// document, and the chip is screen chrome rendered on a different tab
/// from the table that armed it; passing the string the user actually read
/// is what stops the two disagreeing. It is also what makes the chip
/// testable without a document.
@immutable
final class ArmedPin {
  const ArmedPin({required this.outletId, required this.label});

  /// The `Outlet` a plan click will pin. **Not the table row's `linkId`**:
  /// rows are keyed by link and a pin hangs on an outlet, and a four-gang
  /// plate is four rows and one outlet (DR-141 §11.140.6).
  final Uuid outletId;

  /// What to call it on the chip, e.g. `"D-014"`.
  final String label;

  @override
  bool operator ==(Object other) =>
      other is ArmedPin && other.outletId == outletId && other.label == label;

  @override
  int get hashCode => Object.hash(outletId, label);

  @override
  String toString() => 'ArmedPin($label)';
}

/// The fast path's mode: on or off, and what is armed within it.
///
/// Three states, and the middle one is the whole ruling:
///
/// | `isActive` | `armed` | What the user sees |
/// |---|---|---|
/// | false | null | Nothing. The plan behaves normally |
/// | **true** | **null** | The chip, saying to pick a drop in the table |
/// | true | an `ArmedPin` | The chip, naming the drop the next click pins |
final class PlanPinArmController extends ChangeNotifier {
  bool _active = false;
  ArmedPin? _armed;

  /// Whether the fast path is running. True from the first [arm] until
  /// [dismiss].
  bool get isActive => _active;

  /// The drop a click on the plan would pin, or null when the mode is
  /// running but waiting for the user to choose one.
  ArmedPin? get armed => _armed;

  /// Arms [pin] and turns the mode on if it was not already.
  ///
  /// Replacing an armed subject is deliberate and needs no confirmation:
  /// arming a second drop before pinning the first means the user changed
  /// their mind, which is exactly what `schematic_reveal.dart` concluded
  /// about two clicks before its sheet built.
  void arm(ArmedPin pin) {
    _active = true;
    _armed = pin;
    notifyListeners();
  }

  /// The armed drop was pinned. **The mode stays on** (DR-141): only the
  /// subject clears, so the chip stays up and says to pick another.
  ///
  /// A no-op when nothing is armed, so a stray plan click cannot notify
  /// listeners into a rebuild that changes nothing.
  void pinned() {
    if (_armed == null) return;
    _armed = null;
    notifyListeners();
  }

  /// Ends the mode. `Esc`, and the only thing that does.
  void dismiss() {
    if (!_active && _armed == null) return;
    _active = false;
    _armed = null;
    notifyListeners();
  }
}

/// Why a drop row could not be armed. Null means it can.
///
/// A `String?` RATHER THAN A THROW OR A BOOL, on the `CatalogPlacement`
/// result's own shape: the caller has to put a sentence in front of a
/// person, and a bool would make it invent one.
String? armRefusalFor(RackDocument doc, Uuid linkId) {
  final link = doc.links[linkId];
  if (link == null) return 'That drop is not in the project any more.';
  final origin = link.structureOrigin;
  if (origin == null) {
    // NOT EVERY ROW IS A DROP. The table lists links, and a link with no
    // `StructureOrigin` is a cable that does not come off a wall plate, so
    // there is no outlet to carry a pin. Refused by name rather than
    // silently ignored: a row that does nothing when clicked, with no
    // sentence, is the silent no-op docs/04 §3.4 forbids.
    return 'This cable does not run to an outlet, so there is nothing to '
        'pin on the plan.';
  }
  if (!doc.outlets.containsKey(origin.outletId)) {
    return 'That outlet is not in the project any more.';
  }
  return null;
}

/// The outlet a drop-table row arms, or null when [armRefusalFor] refuses.
///
/// THE JOIN ALREADY EXISTED and this does not invent it:
/// `derived/structure_matrix.dart` walks `Link.structureOrigin.outletId`
/// for the same reason. What is new is only that a refusal has words.
Uuid? armSubjectFor(RackDocument doc, Uuid linkId) =>
    armRefusalFor(doc, linkId) == null
    ? doc.links[linkId]!.structureOrigin!.outletId
    : null;

/// The copy the chip shows while the mode is on and nothing is armed.
///
/// **THE SENTENCE IS THE FEATURE HERE.** DR-141 leaves the mode running
/// after a pin precisely so this stays on screen; a mode that ended
/// silently would be indistinguishable from one that had failed. So it
/// says what to do next rather than merely that it is on.
/// The drop table's row menu, docs/15 §6's secondary entry point.
///
/// A CONSTANT so the menu and the test name the same string, and so the
/// wording is one edit. DR-141 §11.140.4 demotes this to the secondary way
/// in: the primary loop is the unpinned strip, in the plan view, with no
/// tab change at all.
const String kPinOnPlanMenuLabel = 'Pin on plan';

const String kPinArmIdleLabel = 'Pick a drop in the Structure table';

/// What the chip says before the word: the act, not the state.
const String kPinArmActionLabel = 'Click the plan to pin';

/// `PLAN-E/3`'s signpost: what is armed, what happens next, and how to
/// stop, which are the three things that chapter's brief requires be
/// visible.
///
/// SCREEN CHROME AND NEVER SCENE (CR-086). `buildPlanScene` feeds the PDF
/// as well as the screen, so a mode indicator added as an op would print
/// on `T1.01`. This is an ordinary widget over the canvas.
final class PlanPinArmChip extends StatelessWidget {
  const PlanPinArmChip({
    required this.armed,
    required this.onDismiss,
    super.key,
  });

  /// The drop the next plan click pins, or null while the mode waits for
  /// the user to choose one.
  final ArmedPin? armed;

  final VoidCallback onDismiss;

  /// A stable handle for tests, so a case can tell this chip's copy from
  /// the table row that armed it: both legitimately render the same
  /// designator at the same moment.
  static const Key chipKey = ValueKey('plan-pin-arm-chip');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pin = armed;
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
              pin == null
                  ? kPinArmIdleLabel
                  : '$kPinArmActionLabel: ${pin.label}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
            const SizedBox(width: 8),
            // HOW TO STOP, IN THE SAME PLACE AS WHAT IS ARMED. A mode
            // whose exit is a keystroke nobody mentions is a mode people
            // quit by closing the project.
            IconButton(
              onPressed: onDismiss,
              icon: const Icon(Icons.close, size: 16),
              tooltip: 'Stop pinning (Esc)',
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}
