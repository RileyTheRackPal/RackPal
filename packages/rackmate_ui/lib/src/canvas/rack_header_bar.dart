// packages/rackmate_ui/lib/src/canvas/rack_header_bar.dart
//
// The rack's own header chrome (docs/04-rack-editor.md §4): the designator
// and name, and an overflow menu. Clicking the header is ONE of the three
// entry points §4 names for the `RackInspector` ("click the rack header or
// its empty background, Ctrl+Alt+U, or the overflow menu -> Rack settings");
// the menu itself is where §3.6's Compact Up / Compact Down live.
//
// SCREEN-SPACE, NOT SCENE-SPACE, and the distinction is load-bearing. This
// is a `Positioned` in the canvas `Stack`, a sibling of the zoom HUD and the
// face toggle — not part of the `DiagramScene` and not painted by a
// `CustomPainter`. Two reasons: (1) it hosts REAL Flutter controls (a
// `PopupMenuButton`, and pass 3's stepper buttons), which a scene fragment
// replayed through `FlutterDiagramCanvas` structurally cannot be; (2) a
// header that scaled with zoom would be unreadable at 0.05x and enormous at
// 8x, whereas every other piece of chrome on this canvas is deliberately
// zoom-invariant.
//
// WHY THE COMPACTION AFFORDANCE IS HERE. docs/04 §3.6 requires Compact
// Up/Down to ship but leaves `Ctrl+B` RESERVED AND UNBOUND (AC-045), so the
// commands need a non-keyboard home. The overflow menu on the rack's own
// header is that home: compaction is a per-rack operation, so hanging it off
// the rack's own chrome puts it where its subject is, and costs no new
// screen furniture. The alternative — a global toolbar — does not exist in
// this app yet and would have to invent a target-rack concept the moment a
// second rack lands.
//
// THE HEIGHT STEPPER (docs/04 §4.1's FIRST of three ways to change height:
// "the header stepper (hold to repeat at 8/s after 400 ms)") now lives here,
// replacing the read-only badge that stood in for it. Its hold-repeat is
// [_HoldRepeatButton] below; the timing constants are public statics so
// test/canvas/rack_header_bar_test.dart can assert against the same numbers
// the widget uses rather than a second copy that could drift.
//
// THE STEPPER DOES NOT DECIDE ANYTHING. It emits `+1`/`-1` through [onStep]
// and is told, by that callback's return value, whether it may keep
// repeating. Every question worth asking about a height change — is it in
// CR-038's [1,60], does it strand an occupant, does §4.1's modal need to open
// — belongs to the screen's ONE height funnel, and a control that answered
// any of them locally would be a second opinion that could disagree with it.
//
// WHAT IS STILL NOT HERE: the `⚠n` findings rollup §5 puts on this header,
// because no validation engine exists in any package.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show SchedulerBinding;

/// The actions the rack header's overflow menu offers.
enum RackHeaderAction {
  /// docs/04 §3.6 — opens the compaction preview, packing toward U1.
  compactDown,

  /// docs/04 §3.6 — opens the compaction preview, packing toward the top.
  compactUp,

  /// docs/04 §4's third inspector entry point: "the overflow menu -> Rack
  /// settings".
  rackSettings,
}

/// One step of the height stepper: [delta] is `+1` or `-1`.
///
/// RETURNS WHETHER THE HOLD-REPEAT MAY CONTINUE. The screen answers false
/// when the step it just handled opened §4.1's shrink modal, or when the
/// height did not actually change — see `RackCanvasScreen._requestHeight`.
/// This is how §4.1's unaddressed MODAL-STORM problem is solved: a held
/// stepper ratcheting down through occupied territory must not open one
/// modal per tick, and the repeat stopping dead at the first tick that
/// cannot proceed IS the feedback (the modal opens in the same instant, so
/// nothing about it is silent).
typedef RackHeightStep = bool Function(int delta);

/// The floating rack header (see the file header for why it is screen-space).
///
/// Stateless and fully driven by its arguments: the screen owns the rack and
/// every action, so this widget can be pumped standalone in a test with
/// plain strings and callbacks.
class RackHeaderBar extends StatelessWidget {
  const RackHeaderBar({
    required this.designator,
    required this.name,
    required this.heightU,
    required this.onHeaderTap,
    required this.onAction,
    required this.onStep,
    this.compactionEnabled = true,
    super.key,
  });

  /// docs/04 §4.1's hold-repeat delay: "hold to repeat at 8/s after 400 ms".
  static const Duration holdRepeatDelay = Duration(milliseconds: 400);

  /// The 8/s repeat period the same sentence specifies. Stated as the period
  /// rather than the rate because that is what a `Timer.periodic` takes; the
  /// rate is recovered as `1s / 125ms == 8`, which
  /// test/canvas/rack_header_bar_test.dart asserts against the spec's own
  /// two literals so the two spellings cannot drift.
  static const Duration holdRepeatPeriod = Duration(milliseconds: 125);

  /// "RK-1" — the ONLY rack identifier (CR-040), so it leads.
  final String designator;

  /// "Media Closet".
  final String name;

  /// The rack's current height, shown between the stepper's two buttons and
  /// used to disable each of them at CR-038's `[1, 60]` bounds.
  final int heightU;

  /// docs/04 §4's first inspector entry point: "click the rack header".
  final VoidCallback onHeaderTap;

  final ValueChanged<RackHeaderAction> onAction;

  /// docs/04 §4.1's first way to change height. See [RackHeightStep].
  final RackHeightStep onStep;

  /// False while a compaction preview is already open — one preview at a
  /// time is the screen's invariant, and re-entering the menu to start a
  /// second one mid-preview would silently discard the first. Disabled
  /// rather than hidden, so the menu does not change shape under the user.
  final bool compactionEnabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      elevation: 2,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // The tappable identity block — the whole designator/name/badge
          // run, not just the text, so the click target matches what a user
          // would read as "the header".
          //
          // FLEXIBLE, with the NAME as the thing that gives. The canvas
          // column is whatever is left after the 280px palette and the 320px
          // inspector, which on a small window is not much; the designator
          // (CR-040's only rack identifier) and the height badge must stay
          // legible, so the descriptive name is what ellipsises.
          Flexible(
            child: InkWell(
              onTap: onHeaderTap,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      designator,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        name,
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // OUTSIDE the header's `InkWell`, deliberately: the stepper's
          // buttons are their own targets, and nesting them inside the
          // open-the-inspector tap region would make every height step also
          // open the inspector.
          const SizedBox(width: 4),
          _HeightStepper(heightU: heightU, onStep: onStep),
          const SizedBox(width: 4),
          PopupMenuButton<RackHeaderAction>(
            tooltip: 'Rack actions',
            icon: const Icon(Icons.more_vert, size: 18),
            onSelected: onAction,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: RackHeaderAction.compactDown,
                enabled: compactionEnabled,
                child: const Text('Compact Down'),
              ),
              PopupMenuItem(
                value: RackHeaderAction.compactUp,
                enabled: compactionEnabled,
                child: const Text('Compact Up'),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: RackHeaderAction.rackSettings,
                child: Text('Rack settings…'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// docs/04 §4.1's header stepper: `[-] 12U [+]`.
///
/// The two buttons are DISABLED at CR-038's bounds rather than pressable-
/// and-refused. A refused action must "shake and report" (§3.4), but a rack
/// that is already at 60U being unable to grow is not a refusal — it is the
/// control correctly describing the range it operates over, and shaking at a
/// wall the user can see is noise. Every OTHER way a step can fail (an
/// occupant in the way) is a real refusal and does reach the funnel.
class _HeightStepper extends StatelessWidget {
  const _HeightStepper({required this.heightU, required this.onStep});

  final int heightU;
  final RackHeightStep onStep;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _HoldRepeatButton(
            icon: Icons.remove,
            tooltip: 'Shrink the rack by 1U (hold to repeat)',
            enabled: heightU > 1,
            onStep: () => onStep(-1),
          ),
          // Fixed-width so the two buttons do not shuffle sideways as the
          // number goes 9U -> 10U mid-hold, which would move the very
          // button the user is holding out from under their pointer.
          SizedBox(
            width: 34,
            child: Text(
              '${heightU}U',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          _HoldRepeatButton(
            icon: Icons.add,
            tooltip: 'Grow the rack by 1U (hold to repeat)',
            enabled: heightU < 60,
            onStep: () => onStep(1),
          ),
        ],
      ),
    );
  }
}

/// A button that fires once on press and then, after
/// [RackHeaderBar.holdRepeatDelay], keeps firing at
/// [RackHeaderBar.holdRepeatPeriod] until the pointer lifts — docs/04 §4.1's
/// "hold to repeat at 8/s after 400 ms".
///
/// [onStep] returns whether the repeat may continue; false stops both timers
/// immediately (see [RackHeightStep]).
///
/// WHY A `Listener` AROUND AN `IconButton`, rather than either alone. The
/// repeat needs raw pointer-down/up, which `IconButton` does not expose (its
/// `onPressed` fires on pointer-UP, so a hold would not begin repeating
/// until it was already over). But `IconButton.onPressed` is also what
/// carries KEYBOARD activation — a focused button responding to Space/Enter
/// through Flutter's `ActivateIntent` — which a bare `Listener` would throw
/// away. So both are wired, and the state's `_pointerActivated` latch stops
/// a single physical tap from firing twice (once from this `Listener`'s
/// pointer-down, once from the tap recogniser's eventual `onPressed`).
///
/// That latch is cleared in a POST-FRAME callback rather than in
/// `onPointerUp`, because the tap recogniser's `onPressed` and this
/// `Listener`'s `onPointerUp` are both dispatched from the same pointer-up
/// event and their relative order is not a documented guarantee. Clearing it
/// after the frame is unambiguously after both. Doing it unconditionally
/// also self-heals the press-then-drag-off case, where `onPressed` never
/// fires at all and a latch left set would swallow the next keypress.
class _HoldRepeatButton extends StatefulWidget {
  const _HoldRepeatButton({
    required this.icon,
    required this.tooltip,
    required this.enabled,
    required this.onStep,
  });

  final IconData icon;
  final String tooltip;
  final bool enabled;

  /// Returns false to stop an in-flight hold-repeat.
  final bool Function() onStep;

  @override
  State<_HoldRepeatButton> createState() => _HoldRepeatButtonState();
}

class _HoldRepeatButtonState extends State<_HoldRepeatButton> {
  Timer? _delay;
  Timer? _repeat;
  bool _pointerActivated = false;

  /// THE POINTER THAT OWNS THE IN-FLIGHT HOLD — a single slot, the same
  /// shape `CanvasIntentDetector` uses for its `_dragPointer`, and for the
  /// same reason: two fingers are physically possible on this app's touch
  /// and stylus targets, so "a pointer went up" is not the same question as
  /// "THE pointer went up".
  ///
  /// FIRST PRESS WINS, and a second concurrent press is ignored outright
  /// rather than taking the hold over. Without this slot, `onPointerUp` from
  /// EITHER finger cancelled the timers, so lifting one finger killed a
  /// repeat the other was still physically holding and the stepper went dead
  /// under a pointer the user had not moved. Taking over on the second press
  /// would fix that half and keep the other: the second press would fire an
  /// unrequested extra step and restart the first press's 400ms countdown
  /// from zero, so a held stepper would stutter every time another finger
  /// touched it. A hold belongs to the pointer that began it, until that
  /// pointer lifts.
  int? _holdPointer;

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  /// Cancels the timers ONLY. Releasing [_holdPointer] is deliberately not
  /// part of this: the repeat also stops when a step refuses (§4.1's
  /// modal-storm guard), and the owning finger is still down at that moment
  /// — leaving the slot claimed is what stops a second finger from
  /// re-triggering the refused step, and therefore the modal, while the
  /// first is still held.
  void _stop() {
    _delay?.cancel();
    _delay = null;
    _repeat?.cancel();
    _repeat = null;
  }

  void _onPointerDown(int pointer) {
    if (!widget.enabled) return;
    if (_holdPointer != null) return; // a hold is already in flight
    _holdPointer = pointer;
    _pointerActivated = true;
    _stop();
    // The FIRST step is immediate. §4.1's "after 400 ms" governs when the
    // REPEAT starts, not when the control responds — a stepper that waited
    // 400ms to move at all would feel broken.
    if (!widget.onStep()) return;
    _delay = Timer(RackHeaderBar.holdRepeatDelay, () {
      _repeat = Timer.periodic(RackHeaderBar.holdRepeatPeriod, (_) {
        if (!mounted || !widget.enabled || !widget.onStep()) _stop();
      });
    });
  }

  void _onPointerEnd(int pointer) {
    if (pointer != _holdPointer) return;
    _holdPointer = null;
    _stop();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) _pointerActivated = false;
    });
  }

  /// `IconButton.onPressed` — the KEYBOARD path (and the tail of a pointer
  /// tap, which [_pointerActivated] absorbs). See the class doc.
  void _onActivate() {
    if (_pointerActivated) return;
    widget.onStep();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (e) => _onPointerDown(e.pointer),
      onPointerUp: (e) => _onPointerEnd(e.pointer),
      onPointerCancel: (e) => _onPointerEnd(e.pointer),
      child: IconButton(
        tooltip: widget.tooltip,
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        iconSize: 16,
        onPressed: widget.enabled ? _onActivate : null,
        icon: Icon(widget.icon),
      ),
    );
  }
}
