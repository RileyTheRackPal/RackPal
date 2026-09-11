// rackpal_ui/src/canvas/plan/plan_editor_screen.dart — the Plan view's
// layout, and the chapter that makes four other chapters reachable
// (docs/15 §6, DR-143 §11.142, PLAN-E/5).
//
// ═══════════════════════════════════════════════════════════════════════
// WHAT THIS ASSEMBLES, AND WHY IT IS ITS OWN FILE
// ═══════════════════════════════════════════════════════════════════════
// `PlanCanvasScreen` is the canvas region and says in its own header that
// the layout is this chapter's. Everything here was built and unreachable:
// the canvas and its two gestures (`PLAN-E/2`), the arm mode and its chip
// (`PLAN-E/3`), the unpinned strip and `armCarrierDrag` (`PLAN-E/4`). This
// file is the one that puts them on screen together.
//
// ═══════════════════════════════════════════════════════════════════════
// THREE REGIONS, NOT FOUR, AND THE MISSING ONE IS NAMED RATHER THAN FAKED
// ═══════════════════════════════════════════════════════════════════════
// docs/15 §6 gives the layout as: left the underlay list and the location
// tree, centre the plan, right **the standard inspector**, with "no fourth
// region and no plan-specific palette".
//
// **THERE IS NO STANDARD INSPECTOR TO PUT THERE.** `InspectorPanel` takes
// a `required Rack` and is the rack editor's: its targets are a rack, a
// rack device and a selection inside one. A pin's carrier is a rack, an
// **outlet** or an **off-rack device**, and two of those three have no
// rack to hand it.
//
// So the column is absent rather than invented. Building a plan-specific
// inspector here would be a surface nobody ruled, on a view whose whole
// arrival is DR-091's rule that a tab must open onto something built; the
// honest version of that rule pointed at ourselves is to ship the regions
// that exist and say which one is owed. docs/12 records it.
//
// ═══════════════════════════════════════════════════════════════════════
// THE LEFT RAIL IS THE UNDERLAY LIST, AND THE LOCATION TREE IS NOT HERE
// ═══════════════════════════════════════════════════════════════════════
// §6 pairs them, and `LocationsPanel` is a whole editing surface with its
// own tab in the strip since DR-091 §11.90. Embedding a second copy of it
// here would be the "two routes to one surface" that ruling deleted the
// `Project` menu to avoid. What the plan needs from locations is which
// room this underlay depicts, and that is one line of text on the row.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/src/canvas/marquee_controller.dart';
import 'package:rackpal_ui/src/canvas/plan/plan_calibrate.dart';
import 'package:rackpal_ui/src/canvas/plan/plan_canvas_screen.dart';
import 'package:rackpal_ui/src/canvas/plan/plan_outline.dart';
import 'package:rackpal_ui/src/canvas/plan/plan_pin_arm.dart';
import 'package:rackpal_ui/src/canvas/plan/unpinned_strip.dart';
import 'package:rackpal_ui/src/canvas/selection_controller.dart';
import 'package:rackpal_ui/src/canvas/viewport_controller.dart';
import 'package:rackpal_ui/src/draw/flutter_canvas.dart';

/// What the view says when the project has no floorplan in it.
///
/// **IT NAMES THE ROUTE**, because until `PLAN-E/5` there was none: the
/// importer existed and nothing called it (DR-143 §11.142.1). A tab that
/// said only "no plans" would be the honest-absence panel this repo
/// already ships, one degree less useful than it could be.
const String kPlanEmptyHeadline = 'No floorplan in this project yet';
const String kPlanEmptyDetail =
    'File ▸ Import floorplan… takes a PNG, a JPEG, or one page '
    'of a PDF.';

/// The Plan editor: one underlay, its pins, and everything that has been
/// waiting for a home.
final class PlanEditorScreen extends StatefulWidget {
  const PlanEditorScreen({
    required this.controller,
    required this.images,
    required this.measurer,
    required this.selection,
    this.arm,
    this.onRefuse,
    this.onNotice,
    super.key,
  });

  final DocumentController controller;

  /// Resolves an underlay's raster. The host owns the cache because it
  /// owns the container the bytes came out of.
  final FlutterImageResolver images;

  final TextMeasurer measurer;
  final SelectionController selection;

  /// docs/15 §6's fast path, or null. Null is supported and every render
  /// test uses it (DR-141 §11.140.4).
  final PlanPinArmController? arm;

  final void Function(String reason)? onRefuse;

  /// Told when something WORKED and the person should know what it did
  /// (`PLAN-F/2`, DR-144 §11.143.3).
  ///
  /// **A SECOND CALLBACK AND NOT A FLAG ON [onRefuse].** The two carry
  /// opposite news and a host may well want to render them differently;
  /// folding them together would make every caller ask which kind it had,
  /// from a string. The shell happens to put both in a snack bar today,
  /// and that is the shell's decision rather than this widget's.
  ///
  /// Null means the host says nothing, which is legal and is what every
  /// render test uses.
  final void Function(String message)? onNotice;

  @override
  State<PlanEditorScreen> createState() => _PlanEditorScreenState();
}

class _PlanEditorScreenState extends State<PlanEditorScreen> {
  /// Which plan is open. **Held here and not in the document**, because it
  /// is a view state and not a fact about the project: two windows on one
  /// file would disagree about it, and a saved file recording which tab
  /// somebody last looked at is the kind of thing that makes two saves of
  /// an unedited document differ.
  Uuid? _openId;

  /// One viewport PER UNDERLAY, so switching plans and switching back does
  /// not throw away the pan and zoom. A single shared controller would
  /// show `Level 2` at `Level 1`'s scroll offset, which on a differently
  /// sized raster is somewhere else entirely.
  final Map<Uuid, ViewportController> _viewports = {};

  /// One canvas key PER UNDERLAY, and it does two jobs at once.
  ///
  /// A `GlobalKey` is how the strip reaches the canvas at all: the two are
  /// siblings, not ancestor and descendant, so an armed pointer has to be
  /// handed ACROSS. Keying it on the underlay also makes switching plans
  /// build a NEW canvas state rather than carrying the previous one's live
  /// drag and grab offset onto a different raster.
  ///
  /// The first draft used a single `GlobalKey` here and passed a
  /// `ValueKey(open.id)` to the canvas, which is both of those jobs given
  /// to the wrong object: the global key was never attached, so
  /// `currentState` was always null and every strip drag was a silent
  /// no-op.
  final Map<Uuid, GlobalKey<PlanCanvasScreenState>> _canvasKeys = {};

  /// docs/15 §5's two-point pick (DR-144 §11.143, `PLAN-F/1`).
  ///
  /// OWNED HERE for the reason the band is: the affordance that starts it
  /// is on the underlay row in the left rail, and the dialog that ends it
  /// is a route this widget pushes. The canvas takes the clicks and
  /// reports the pair back; it does not decide what a pick means.
  ///
  /// ONE FOR ALL PLANS, like the band and unlike the viewports. A pick
  /// describes a distance on one raster and cannot outlive a switch to
  /// another; [_openPlan] cancels it for exactly that reason.
  final PlanCalibrateController _calibrate = PlanCalibrateController();
  final PlanOutlineController _outline = PlanOutlineController();

  /// CR-102's band (DR-139 §11.138).
  ///
  /// OWNED HERE because the band is drawn OVER the canvas by a sibling,
  /// and the widget that stacks the two is the one that must hold the
  /// controller. The rack canvas owns its own for the mirror-image reason:
  /// it lays out its own canvas, so nothing above it needs a handle.
  ///
  /// ONE FOR ALL PLANS, unlike the viewports. A viewport is a place on a
  /// particular raster and must survive a switch; a band lives for the
  /// length of one drag and cannot outlive the plan it was drawn on.
  final MarqueeController _marquee = MarqueeController();

  DocumentController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _controller.changes.addListener(_onDocumentChanged);
  }

  @override
  void dispose() {
    _controller.changes.removeListener(_onDocumentChanged);
    _calibrate.dispose();
    _outline.dispose();
    _marquee.dispose();
    for (final v in _viewports.values) {
      v.dispose();
    }
    super.dispose();
  }

  void _onDocumentChanged() => setState(() {});

  /// The underlays, in `order` then id: the same total order every other
  /// list in this product uses, because `Map` iteration is insertion order
  /// and a reopened file enumerates differently.
  List<PlanUnderlay> get _underlays {
    final out = _controller.doc.underlays.values.toList()
      ..sort((a, b) {
        final byOrder = a.order.v.compareTo(b.order.v);
        return byOrder != 0 ? byOrder : a.id.v.compareTo(b.id.v);
      });
    return out;
  }

  /// The plan on screen, or null when the project has none.
  ///
  /// FALLS BACK TO THE FIRST rather than holding a dangling id: an
  /// underlay can be removed in another tab while this one is open, and
  /// `RemovePlanUnderlayCommand` cascades its pins away, so an id that no
  /// longer resolves must not blank the view.
  PlanUnderlay? get _open {
    final all = _underlays;
    if (all.isEmpty) return null;
    final id = _openId;
    if (id == null) return all.first;
    return all.where((u) => u.id == id).firstOrNull ?? all.first;
  }

  ViewportController _viewportFor(Uuid id) =>
      _viewports.putIfAbsent(id, ViewportController.new);

  GlobalKey<PlanCanvasScreenState> _canvasKeyFor(Uuid id) =>
      _canvasKeys.putIfAbsent(id, GlobalKey<PlanCanvasScreenState>.new);

  /// The canvas region, split out only so the band can be stacked over it
  /// without the build method growing a second level of nesting.
  /// Opens another plan, and ENDS ANY PICK IN PROGRESS.
  ///
  /// A pick is two points in ONE raster's pixel space, so carrying it
  /// across a switch would let the second click land on a different
  /// picture and calibrate a wall that is not there. The chip going away
  /// is what tells the user it stopped.
  void _openPlan(Uuid id) {
    _calibrate.cancel();
    setState(() => _openId = id);
  }

  /// Starts a pick on the open plan.
  void _beginCalibrate() => _calibrate.begin();

  /// Starts a room draw, and STOPS WHATEVER ELSE WAS RUNNING first.
  ///
  /// The canvas ranks the draw above the pick and the arm, so without
  /// this a plan could hold a live calibration underneath a live draw and
  /// the older one would be unreachable until the newer ended: a mode
  /// nobody can get back to is the state `PLAN-E/3`'s chip exists to
  /// prevent.
  void _beginOutline(Uuid locationId) {
    _calibrate.cancel();
    _outline.begin(locationId);
  }

  /// Takes a room's shape off. One command, its own Edit-menu label.
  void _clearOutline(Uuid locationId) =>
      _controller.run(ClearRoomOutlineCommand(locationId: locationId));

  /// Both points are down: ask for the distance, then write it.
  ///
  /// **THE COMMAND IS RUN HERE AND NOT IN THE CANVAS**, which is the
  /// division `onRefuse` already draws: this widget owns the document and
  /// the routes, and a canvas that pushed a dialog would be a second
  /// surface deciding what a gesture means.
  Future<void> _askDistance(PlanUnderlay open, PxPt a, PxPt b) async {
    final alreadyCalibrated = open.scale != null;
    final distance = await showCalibrateDistanceDialog(
      context,
      planName: open.name,
      units: _controller.doc.settings.displayUnits,
      alreadyCalibrated: alreadyCalibrated,
    );
    // ALWAYS ENDS THE PICK, whichever way the dialog closed. Cancelling
    // means "not doing this", and committing has nothing left to pick;
    // DR-144 §11.143.6 gives the mode one exit for both.
    _calibrate.cancel();
    if (distance == null || !mounted) return;
    // RE-READ RATHER THAN CLOSE OVER `open`. The dialog is asynchronous
    // and another tab can remove the underlay while it is up, which is
    // the same hazard `_pinExisting` guards one file over.
    if (!_controller.doc.underlays.containsKey(open.id)) {
      widget.onRefuse?.call('That plan is not in the project any more.');
      return;
    }
    _controller.run(
      SetPlanScaleCommand(
        underlayId: open.id,
        scale: PlanScale(a: a, b: b, distance: distance),
      ),
    );
    // ═══════════════════════════════════════════════════════════════════
    // TELL THE USER WHAT MOVED, WHICH IS `PLAN-F/2`'s THIRD CLAUSE
    // ═══════════════════════════════════════════════════════════════════
    // MEASURED AFTER THE COMMAND, NOT BEFORE. The count is a fact about
    // the document the command has just produced, and taking it from the
    // pre-command document would report the state the calibration
    // replaced: on a FIRST calibration that is always "uncalibrated", so
    // every message would name the blocker the user had just cleared.
    //
    // AND RE-READ OUT OF THE DOCUMENT rather than off `open`, which is the
    // instance captured before the dialog. `SetPlanScaleCommand` mutates
    // the underlay in place today and a copy-on-write model later would
    // leave `open.scale` null here, which is the quiet kind of wrong.
    final after = _controller.doc.underlays[open.id];
    if (after == null) return;
    widget.onNotice?.call(
      calibrationCommitMessage(
        planName: after.name,
        wasRecalibration: alreadyCalibrated,
        measurability: planMeasurabilityOf(_controller.doc, after),
      ),
    );
  }

  Widget _canvas(PlanUnderlay open) => PlanCanvasScreen(
    key: _canvasKeyFor(open.id),
    controller: _controller,
    underlay: open,
    images: widget.images,
    measurer: widget.measurer,
    selection: widget.selection,
    viewport: _viewportFor(open.id),
    arm: widget.arm,
    calibrate: _calibrate,
    outline: _outline,
    onCalibrationPicked: (a, b) => unawaited(_askDistance(open, a, b)),
    marquee: _marquee,
    onRefuse: widget.onRefuse,
  );

  @override
  Widget build(BuildContext context) {
    final open = _open;
    if (open == null) return const _EmptyPlan();

    final strip = unpinnedCarriersFor(_controller.doc, open);
    return Row(
      children: [
        SizedBox(
          width: 240,
          // THE ROOM LIST SITS UNDER THE UNDERLAY LIST, which is the
          // user's call (2026-09-11) against a button on the underlay row
          // and an action over on the Locations tab. It mirrors the
          // unpinned strip's logic: the thing you are working through is
          // listed where you work, and "which rooms still need an
          // outline" becomes answerable at a glance rather than by
          // opening each one.
          //
          // **A FUTURE MERGE OF THE LOCATION AND PLAN VIEWS IS POSSIBLE
          // BEFORE v1** and is deliberately NOT designed for here: the
          // user ruled it out of this epic while naming it as something
          // that may happen. Nothing below assumes this rail is the only
          // place rooms are listed, which is the most that note is worth
          // acting on today.
          child: Column(
            children: [
              Expanded(
                child: _UnderlayList(
                  underlays: _underlays,
                  openId: open.id,
                  doc: _controller.doc,
                  onOpen: _openPlan,
                  onCalibrate: _beginCalibrate,
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: _RoomList(
                  doc: _controller.doc,
                  underlay: open,
                  drawingId: _outline.isActive ? _outline.locationId : null,
                  onDraw: _beginOutline,
                  onClear: _clearOutline,
                ),
              ),
            ],
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(child: _canvas(open)),
                    // SCREEN CHROME, NEVER A SCENE OP (CR-086):
                    // `buildPlanScene` feeds the PDF as well as this
                    // display, so a band in the scene would print.
                    Positioned.fill(
                      child: MarqueeBand(
                        marquee: _marquee,
                        viewport: _viewportFor(open.id),
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              UnpinnedStrip(
                carriers: strip,
                // THE WIRING DR-140 EXISTS FOR. A row dragged out of here
                // lands on the canvas above and pins that carrier, which
                // is how a RACK gets a pin at all; without one `PLN-003`
                // fires and no length on the plan derives.
                onArmDrag: (row, event) =>
                    _canvasKeyFor(
                      open.id,
                    ).currentState?.armCarrierDrag(
                      row.carrier,
                      row.entityId,
                      event,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The left rail: which plans this project holds, which is open, and
/// whether each one is calibrated.
///
/// ═══════════════════════════════════════════════════════════════════════
/// THE CALIBRATION LIVES ON THE ROW, WHICH IS DR-144 §11.143.4
/// ═══════════════════════════════════════════════════════════════════════
/// A calibration is a property OF an underlay and this is the list of
/// underlays. The alternatives were a toolbar over the canvas, which would
/// be new chrome on a layout docs/15 §6 rules as three regions with "no
/// fourth region", and a canvas context menu, which nothing in this
/// product has and nobody would find.
///
/// THE STATE LINE IS ON EVERY ROW AND THE ACTION ONLY ON THE OPEN ONE. A
/// list of buttons is not scannable, and the pick they start happens on
/// the canvas, which is showing the open plan and nothing else.
class _UnderlayList extends StatelessWidget {
  const _UnderlayList({
    required this.underlays,
    required this.openId,
    required this.doc,
    required this.onOpen,
    required this.onCalibrate,
  });

  final List<PlanUnderlay> underlays;
  final Uuid openId;

  /// THE DOCUMENT AND NOT A PRE-DERIVED LIST, because each row needs two
  /// different answers out of it (the room, and what this plan can
  /// measure) and a caller assembling both would be a third place that
  /// has to be kept in step with the two derivations.
  final RackDocument doc;
  final void Function(Uuid id) onOpen;

  /// Starts a pick on the OPEN plan. It takes no id, because the pick
  /// happens on the canvas and the canvas is showing one underlay: a
  /// button on a closed row that armed a pick over a different picture is
  /// the bug this signature makes unspellable.
  final VoidCallback onCalibrate;

  /// A stable handle for tests, per row.
  static String calibrateKeyFor(Uuid id) => 'underlay-calibrate-${id.v}';

  /// Ditto for the row itself.
  static String rowKeyFor(Uuid id) => 'underlay-row-${id.v}';

  @override
  Widget build(BuildContext context) => ListView.builder(
    itemCount: underlays.length,
    itemBuilder: (context, i) {
      final u = underlays[i];
      return _UnderlayRow(
        key: ValueKey(_UnderlayList.rowKeyFor(u.id)),
        underlay: u,
        open: u.id == openId,
        room: u.locationId == null ? null : doc.locations[u.locationId]?.name,
        // DERIVED PER ROW AND PER BUILD, so the line answers for the
        // document as it is now. It moves when the SCALE changes and
        // equally when a PIN does, which is the half a mask-shaped
        // reading of this feature misses: pinning the rack is what turns
        // `no rack pinned` into a count, and no calibration happened.
        measurability: planMeasurabilityOf(doc, u),
        onOpen: () => onOpen(u.id),
        onCalibrate: onCalibrate,
      );
    },
  );
}

/// One plan in the rail.
///
/// ═══════════════════════════════════════════════════════════════════════
/// NOT A `ListTile`, AND THE REASON IS A MEASUREMENT
/// ═══════════════════════════════════════════════════════════════════════
/// The first draft was one, with the state line and the action in a `Row`
/// inside its `subtitle`. **It overflowed by 126 pixels** in a 240 wide
/// rail: a `ListTile` hands its subtitle a fixed width and a `TextButton`
/// carries a 64 pixel minimum and a padded tap target, and the two do not
/// negotiate. A `Wrap` inside a `ListTile` would have fixed the horizontal
/// half and left the vertical one, because a three-line subtitle is more
/// than `isThreeLine` allots.
///
/// So the row is laid out here, where the widths are visible. The `Wrap`
/// is what keeps DR-144's one-line reading when the rail is wide enough
/// and drops the action below the state when it is not, rather than
/// clipping either.
class _UnderlayRow extends StatelessWidget {
  const _UnderlayRow({
    required this.underlay,
    required this.open,
    required this.room,
    required this.measurability,
    required this.onOpen,
    required this.onCalibrate,
    super.key,
  });

  final PlanUnderlay underlay;
  final bool open;

  /// What this plan can measure, for the state line (`PLAN-F/2`).
  final PlanMeasurability measurability;

  /// The room this plan depicts, or null. A plan with no location is
  /// perfectly ordinary and is not an error to report: the model says a
  /// site plan depicts no room, so the line is absent rather than reading
  /// "no location".
  final String? room;

  final VoidCallback onOpen;
  final VoidCallback onCalibrate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = room;
    return InkWell(
      onTap: onOpen,
      child: Container(
        width: double.infinity,
        color: open ? theme.colorScheme.primaryContainer : null,
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              underlay.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
            if (label != null) Text(label, style: theme.textTheme.labelSmall),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                // PRINTED IN BOTH DIRECTIONS (G4, DR-144 §11.143.4).
                // "Not calibrated" is a fact worth stating, and a row
                // that said nothing would leave "no scale yet" and "a
                // scale I have forgotten about" looking identical.
                //
                // AND IT CARRIES WHAT THE CALIBRATION BOUGHT, or the one
                // act still blocking it (`PLAN-F/2`). This is the half
                // that still says it tomorrow; the snack bar on commit is
                // the half that can report a RECALIBRATION, which leaves
                // this line reading exactly the same.
                Text(
                  calibrationStateLabel(underlay, measurability),
                  style: theme.textTheme.labelSmall,
                ),
                if (open)
                  TextButton(
                    key: ValueKey(
                      _UnderlayList.calibrateKeyFor(underlay.id),
                    ),
                    onPressed: onCalibrate,
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                    ),
                    child: Text(
                      // THE SAME TWO WORDS THE UNDO ENTRY USES, from one
                      // function, so the button and the Edit menu cannot
                      // disagree about which act just happened.
                      calibrateActionLabel(
                        alreadyCalibrated: underlay.scale != null,
                      ),
                      style: theme.textTheme.labelSmall,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The honest-absence panel, naming the route that now exists.
class _EmptyPlan extends StatelessWidget {
  const _EmptyPlan();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(kPlanEmptyHeadline, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              kPlanEmptyDetail,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// What the rail says when this plan depicts no location.
///
/// A PLAN WITH NO LOCATION IS ORDINARY, not an error to report: a site
/// plan depicts no room, which is why `_UnderlayRow` already prints its
/// room line only when there is one. The rooms an outline could hang on
/// are the ones UNDER the plan's own location, so with no location there
/// is nothing to list and the honest thing is to say which fact is
/// missing.
const String kPlanNoRoomsDetail =
    'Give this plan a location to draw rooms on it.';

/// Every room this plan could carry an outline for (`LEN-A/4`, DR-050).
///
/// ═══════════════════════════════════════════════════════════════════════
/// THE SUBTREE, WHICH IS `PLN-002`'s SCOPE AND NOT A SECOND ONE
/// ═══════════════════════════════════════════════════════════════════════
/// DR-154 §11.153.7a ruled that an underlay depicts a floor and the drops
/// are filed in its rooms, so the population a plan is about is its
/// location's SUBTREE. `unpinnedCarriersFor` was widened onto exactly
/// that scope, and this list asks the same question about the same tree.
/// Listing only the exact location would offer an outline on the floor
/// and on none of the rooms in it, which is the shape that ruling deleted.
class _RoomList extends StatelessWidget {
  const _RoomList({
    required this.doc,
    required this.underlay,
    required this.drawingId,
    required this.onDraw,
    required this.onClear,
  });

  final RackDocument doc;
  final PlanUnderlay underlay;

  /// The room currently being drawn, or null when no draw is running.
  final Uuid? drawingId;

  final void Function(Uuid locationId) onDraw;
  final void Function(Uuid locationId) onClear;

  static String drawKeyFor(Uuid id) => 'room-draw-${id.v}';
  static String clearKeyFor(Uuid id) => 'room-clear-${id.v}';
  static const Key emptyKey = ValueKey('plan-no-rooms');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scope = underlay.locationId;
    final rooms = <Location>[
      if (scope != null)
        for (final id in LocationTree.of(doc).subtreeOf(scope))
          if (doc.locations[id] case final Location l) l,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text('Rooms', style: theme.textTheme.labelLarge),
        ),
        if (rooms.isEmpty)
          Padding(
            key: emptyKey,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Text(
              kPlanNoRoomsDetail,
              style: theme.textTheme.labelSmall,
            ),
          )
        else
          Expanded(
            child: ListView(
              primary: false,
              children: [
                for (final room in rooms)
                  _RoomRow(
                    room: room,
                    // THE OUTLINE ON *THIS* PLAN. A room whose shape was
                    // drawn on another underlay has none here, and
                    // offering `Clear` for it would take away something
                    // the person is not looking at.
                    hasOutline: room.planOutline?.underlayId == underlay.id,
                    drawing: room.id == drawingId,
                    onDraw: () => onDraw(room.id),
                    onClear: () => onClear(room.id),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _RoomRow extends StatelessWidget {
  const _RoomRow({
    required this.room,
    required this.hasOutline,
    required this.drawing,
    required this.onDraw,
    required this.onClear,
  });

  final Location room;
  final bool hasOutline;
  final bool drawing;
  final VoidCallback onDraw;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      color: drawing ? theme.colorScheme.primaryContainer : null,
      padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            room.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium,
          ),
          // PRINTED IN BOTH DIRECTIONS (G4), on the calibration row's own
          // rule: "no outline yet" is a fact worth stating, and a row that
          // said nothing would leave "not drawn" and "drawn and I have
          // forgotten" looking identical.
          Text(
            hasOutline ? 'Outline drawn' : 'No outline yet',
            style: theme.textTheme.labelSmall,
          ),
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                key: ValueKey(_RoomList.drawKeyFor(room.id)),
                onPressed: onDraw,
                child: Text(hasOutline ? 'Redraw…' : 'Draw…'),
              ),
              if (hasOutline)
                TextButton(
                  key: ValueKey(_RoomList.clearKeyFor(room.id)),
                  onPressed: onClear,
                  child: const Text('Clear'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
