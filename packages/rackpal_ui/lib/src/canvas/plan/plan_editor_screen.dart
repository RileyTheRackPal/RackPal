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

import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/src/canvas/marquee_controller.dart';
import 'package:rackpal_ui/src/canvas/plan/edit_plan_dialog.dart';
import 'package:rackpal_ui/src/canvas/plan/plan_calibrate.dart';
import 'package:rackpal_ui/src/canvas/plan/plan_canvas_screen.dart';
import 'package:rackpal_ui/src/canvas/plan/plan_outline.dart';
import 'package:rackpal_ui/src/canvas/plan/plan_pin_arm.dart';
import 'package:rackpal_ui/src/canvas/plan/unpinned_strip.dart';
import 'package:rackpal_ui/src/canvas/schematic/schematic_reveal.dart';
import 'package:rackpal_ui/src/canvas/selection_controller.dart';
import 'package:rackpal_ui/src/canvas/viewport_controller.dart';
import 'package:rackpal_ui/src/draw/flutter_canvas.dart';
import 'package:rackpal_ui/src/keymap/keymap.dart';
import 'package:rackpal_ui/src/project/locations_panel.dart';
import 'package:rackpal_ui/src/project/remove_underlay_dialog.dart';

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
/// What the rail's add button says with nothing selected, and with a room
/// selected (`#891`).
///
/// TWO STRINGS, because the button does two different things and a single
/// `Add room` would be a lie half the time: `LocationsPanelActions.onAdd`
/// puts the new room UNDER the selection, which is how CR-047's
/// arbitrary-depth tree gets its depth at all.
const String kAddRoom = 'Add room';
const String kAddRoomUnder = 'Add room under selection';

final class PlanEditorScreen extends StatefulWidget {
  const PlanEditorScreen({
    required this.controller,
    required this.images,
    required this.measurer,
    required this.selection,
    required this.locations,
    this.arm,
    this.onRefuse,
    this.onNotice,
    this.reveal,
    super.key,
  });

  /// A floorplan to open, parked by the shell's `F8` (DR-193 §11.192).
  /// See `RevealController` for why it is a pending request.
  final RevealController? reveal;

  final DocumentController controller;

  /// Resolves an underlay's raster. The host owns the cache because it
  /// owns the container the bytes came out of.
  final FlutterImageResolver images;

  final TextMeasurer measurer;
  final SelectionController selection;

  /// What editing a room MEANS, in commands (`#891`, DR-168 §11.167.4).
  ///
  /// The same record `LocationsPanel` takes, built by the app, because
  /// `rackpal_ui` holds no controller: this view edits the tree now, and
  /// the tree's edits were already expressed this way for the panel that
  /// is about to be deleted.
  final LocationsPanelActions locations;

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
  PlanEditorScreenState createState() => PlanEditorScreenState();
}

class PlanEditorScreenState extends State<PlanEditorScreen> {
  /// Which room the rail has selected, and therefore what the inspector
  /// shows (`#891`, DR-168 §11.167.4).
  ///
  /// **HELD HERE AND NOT IN THE TREE**, because the tree is in one region
  /// and what it selects is drawn in another. A selection private to the
  /// list could not reach across that gap and would have to be mirrored,
  /// which is two answers to one question.
  Uuid? _selectedLocation;

  /// The four editing wrappers `LocationsPanel` holds, which both hosts
  /// need for as long as both exist. `MERGE/4` deletes that panel and
  /// with it the second copy.
  void _addLocation() {
    final id = widget.locations.onAdd(_selectedLocation);
    setState(() => _selectedLocation = id);
  }

  void _editLocation(VoidCallback edit) {
    edit();
    setState(() {});
  }

  void _reparentLocation(Uuid id, Uuid? newParentId) {
    final refusal = widget.locations.onReparent(id, newParentId);
    if (refusal != null) {
      widget.onRefuse?.call(refusal);
      return;
    }
    setState(() {});
  }

  Future<void> _deleteLocation(Uuid id) async {
    final removed = await widget.locations.onDelete(id);
    if (!removed) return;
    // THE SELECTION GOES WITH THE ROOM. A rail pointing at a deleted id
    // would leave the inspector showing nothing with no way to say why.
    setState(() => _selectedLocation = null);
  }

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
  final PlanReshapeController _reshape = PlanReshapeController();

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
    widget.reveal?.addListener(_onRevealRequested);
    if (widget.reveal?.pending != null) _onRevealRequested();
  }

  /// Opens a parked floorplan, after the frame, on the Schematic's
  /// reasoning including its `ensureVisualUpdate`. An id that is not a
  /// floorplan in this document is dropped: nothing else on this view is
  /// what a finding points at.
  void _onRevealRequested() {
    final id = widget.reveal?.take();
    if (id == null) return;
    WidgetsBinding.instance
      ..addPostFrameCallback((_) {
        if (mounted && _controller.doc.underlays.containsKey(id)) {
          _openPlan(id);
        }
      })
      ..ensureVisualUpdate();
  }

  @override
  void dispose() {
    _controller.changes.removeListener(_onDocumentChanged);
    widget.reveal?.removeListener(_onRevealRequested);
    _calibrate.dispose();
    _outline.dispose();
    _reshape.dispose();
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

  /// Moves the page at [from] to [at] (`#878`, DR-162 §11.161.4).
  ///
  /// **THE NEIGHBOURS ARE READ FROM THE LIST AFTER THE MOVE**, which is
  /// what `onReorderItem` makes safe: it has already subtracted for the
  /// row leaving its old position, so `at` indexes the list as it will
  /// look. Computing against the pre-move list is the off-by-one Flutter
  /// deprecated `onReorder` over, and `port_grid.dart` carries the same
  /// note.
  ///
  /// **ONE FIELD WRITE, NEVER A RENUMBER** (§11.161.5).
  void _reorderPlan(int from, int at) {
    final all = _underlays;
    if (from < 0 || from >= all.length || at < 0 || at >= all.length) return;
    if (from == at) return;

    final moving = all[from];
    final without = [...all]..removeAt(from);
    final before = at == 0 ? null : without[at - 1].order;
    final after = at < without.length ? without[at].order : null;

    final order = orderBetween(before, after);
    if (order == null) {
      // NAMED RATHER THAN RENUMBERED. `orderBetween`'s own header says
      // the one pair it cannot answer is unreachable in a document this
      // program wrote, so a person meeting this is holding a file from
      // somewhere else and deserves to be told which.
      widget.onRefuse?.call(kReorderPagesRefused);
      return;
    }
    _controller.run(
      ReorderPlanUnderlayCommand(underlayId: moving.id, order: order),
    );
  }

  /// The location selected in the Site tree, or null (DR-185 §11.184.2).
  ///
  /// PUBLIC for the import: a floorplan imported while `Level 2` is
  /// selected proposes that it shows `Level 2`, and the shell that runs
  /// the import is not this widget's parent chain to shout down.
  Uuid? get selectedLocationId => _selectedLocation;

  /// Opens `Edit plan…` on the OPEN plan (`#912`, DR-185 §11.184.1).
  ///
  /// ONE COMMAND FOR BOTH FIELDS, so the dialog is one undo entry, and a
  /// dialog confirmed with nothing changed leaves none: the command
  /// refuses a no-op (DR-156).
  Future<void> _editOpenPlan() async {
    final open = _open;
    if (open == null) return;
    final details = await showEditPlanDialog(
      context,
      doc: _controller.doc,
      initial: PlanDetails(name: open.name, locationId: open.locationId),
    );
    if (details == null || !mounted) return;
    _controller.run(
      SetPlanUnderlayDetailsCommand(
        underlayId: open.id,
        name: details.name,
        locationId: details.locationId,
      ),
    );
  }

  /// Turns the OPEN plan a quarter (`#911`, DR-184 §11.183.4).
  ///
  /// **THROUGH THE CANVAS WHEN THERE IS ONE**, so the rail's buttons and
  /// the canvas's keys hold the view the same way (§11.183.5). With no
  /// canvas mounted the command still runs: the turn is the act, and there
  /// is no view to hold.
  void _rotateOpenPlan({required bool clockwise}) {
    final open = _open;
    if (open == null) return;
    final canvas = _canvasKeyFor(open.id).currentState;
    if (canvas != null) {
      canvas.rotate(clockwise: clockwise);
      return;
    }
    _controller.run(
      RotatePlanCommand(underlayId: open.id, clockwise: clockwise),
    );
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

  /// Hands the shell's palette down to the open canvas (`#885`, DR-165).
  ///
  /// **NULL WHEN NO PLAN IS OPEN**, which is a real state: the Plan tab
  /// shows `_EmptyPlan` in a project with no floorplan, and a drag armed
  /// against nothing must not arm anything.
  void armPaletteDrag(PlaceableTemplate row, PointerDownEvent event) {
    final open = _open;
    if (open == null) return;
    _canvasKeyFor(open.id).currentState?.armPaletteDrag(row, event);
  }

  /// A double-click or `Enter` in the palette, which this view REFUSES.
  ///
  /// docs/15 §6's gesture is a DRAG, and it is a drag because the act
  /// places the device AND sets its pin in one command: a floorplan has
  /// no caret and no default spot, so an activated row has nowhere to
  /// mean. Refusing by name beats both alternatives, which are doing
  /// nothing (docs/04 §3.4) and placing the device somewhere the person
  /// was not looking, the exact defect DR-157 §11.156 closed on the
  /// rails.
  void placeFromPalette(PlaceableTemplate row) => widget.onRefuse?.call(
    'Drag ${row.body.displayName} onto the plan to place it.',
  );

  /// Gives the keyboard back to the open canvas (`#885`).
  void focusCanvas() {
    final open = _open;
    if (open == null) return;
    _canvasKeyFor(open.id).currentState?.focusCanvas();
  }

  GlobalKey<PlanCanvasScreenState> _canvasKeyFor(Uuid id) =>
      _canvasKeys.putIfAbsent(id, GlobalKey<PlanCanvasScreenState>.new);

  /// The canvas region, split out only so the band can be stacked over it
  /// without the build method growing a second level of nesting.
  /// Opens another plan, and ENDS EVERY MODE IN PROGRESS.
  ///
  /// A pick is two points in ONE raster's pixel space, so carrying it
  /// across a switch would let the second click land on a different
  /// picture and calibrate a wall that is not there. The chip going away
  /// is what tells the user it stopped.
  ///
  /// **THE DRAW HAD THE SAME DEFECT AND THIS LINE IS ITS FIX** (found at
  /// `LEN-A/8`). `LEN-A/4` gave this screen one outline controller for all
  /// plans, on the calibration's own "cannot outlive the raster"
  /// reasoning, and then did not cancel it here: two corners placed on one
  /// plan, a switch, and a third click closed a shape whose first two
  /// vertices were measured on a different picture. Nothing refused it,
  /// because the vertices are integers and every raster has those.
  ///
  /// The reshape is cancelled for a softer reason. Its corners are read
  /// from the document and checked against the open underlay, so a mode
  /// carried across a switch is inert rather than wrong; what it would do
  /// is leave a chip up over a plan with no handles under it, which is the
  /// surface telling the user something untrue.
  void _openPlan(Uuid id) {
    _calibrate.cancel();
    _outline.cancel();
    _reshape.cancel();
    setState(() => _openId = id);
  }

  /// Starts a pick on the open plan.
  void _beginCalibrate() => _calibrate.begin();

  /// Removes the open plan, after saying what it costs (`#870`).
  ///
  /// **THE COUNTS AND THE REMOVAL READ ONE OBJECT.** `planUnderlayRemoval`
  /// is what the dialog counts and what `RemovePlanUnderlayCommand.apply`
  /// clears, which is `delete_location_dialog.dart`'s rule: a dialog that
  /// said "3 pins" and cleared four would be worse than no dialog.
  ///
  /// EVERY MODE ENDS FIRST, on `_openPlan`'s reasoning: a draw or a pick
  /// left running over a page that is about to stop existing is a mode
  /// pointing at nothing.
  Future<void> _removeOpenPlan() async {
    final open = _open;
    if (open == null) return;
    final plan = planUnderlayRemoval(_controller.doc, open.id);
    final confirmed = await confirmUnderlayRemoval(
      context,
      plan: plan,
      name: open.name,
    );
    if (!confirmed || !mounted) return;
    _calibrate.cancel();
    _outline.cancel();
    _reshape.cancel();
    _controller.run(RemovePlanUnderlayCommand(underlayId: open.id));
    // THE OPEN ID IS NOT CLEARED HERE. `_open` resolves against the
    // document every build and already falls back when the id is gone,
    // which is the same path a removal performed from anywhere else would
    // take; setting it would be a second rule that could disagree.
    setState(() {});
  }

  /// Starts a room draw, and STOPS WHATEVER ELSE WAS RUNNING first.
  ///
  /// The canvas ranks the draw above the pick and the arm, so without
  /// this a plan could hold a live calibration underneath a live draw and
  /// the older one would be unreachable until the newer ended: a mode
  /// nobody can get back to is the state `PLAN-E/3`'s chip exists to
  /// prevent.
  void _beginOutline(Uuid locationId) {
    _calibrate.cancel();
    _reshape.cancel();
    _outline.begin(locationId);
  }

  /// Starts a reshape, and stops whatever else was running first.
  ///
  /// [_beginOutline]'s rule applied to the fourth mode, and the canvas
  /// depends on it: a reshape SWALLOWS every press on the canvas, so a
  /// draw left running underneath one could not take a single corner until
  /// the reshape ended, which is a mode nobody can get back to.
  void _beginReshape(Uuid locationId) {
    _calibrate.cancel();
    _outline.cancel();
    _reshape.begin(locationId);
  }

  /// Takes a room's shape off. One command, its own Edit-menu label.
  ///
  /// **AND IT ENDS A RESHAPE OF THAT ROOM**, because there is nothing left
  /// to grab. The canvas would offer no handles either way, so this is
  /// about the chip: a mode that stays up saying to drag a corner, over a
  /// plan whose corners the same button press just deleted, is the surface
  /// contradicting itself.
  void _clearOutline(Uuid locationId) {
    if (_reshape.locationId == locationId) _reshape.cancel();
    _controller.run(ClearRoomOutlineCommand(locationId: locationId));
  }

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
    reshape: _reshape,
    onCalibrationPicked: (a, b) => unawaited(_askDistance(open, a, b)),
    marquee: _marquee,
    onRefuse: widget.onRefuse,
    // ONE LINE FOR BOTH. The host's status line is where a person reads
    // what a gesture did, refused or not; the canvas keeps the two
    // callbacks apart so a reader can tell which is which.
    onNotice: widget.onRefuse,
  );

  @override
  Widget build(BuildContext context) {
    final open = _open;
    // ═══════════════════════════════════════════════════════════════════
    // THE RAIL AND THE INSPECTOR ARE ALWAYS HERE (`#891`/`#892`, DR-168)
    // ═══════════════════════════════════════════════════════════════════
    // This method opened `if (open == null) return const _EmptyPlan();`,
    // which made a project with no floorplan a DEAD END: nothing on this
    // view could be done until somebody imported a PDF. CR-112 and
    // docs/04 §7.5 rule the opposite — *"a project with racks and no
    // Structure device must still be able to say which room a rack is
    // in"* — so only the CENTRE depends on there being an underlay.
    return Row(
      children: [
        SizedBox(width: 240, child: _rail(open)),
        const VerticalDivider(width: 1),
        Expanded(
          child: open == null ? const _EmptyPlan() : _planColumn(context, open),
        ),
        const VerticalDivider(width: 1),
        SizedBox(width: 320, child: _inspector(open)),
      ],
    );
  }

  /// The left rail: the floorplans of this project when it has any, and
  /// its rooms always (`#891`, DR-168 §11.167.4).
  ///
  /// **THE TREE IS THE PRIMARY LIST AND THE UNDERLAY LIST IS THE GUEST.**
  /// It was the other way round, with a read-only room list beneath, and
  /// the affordance for editing a room pointed at `Project ▸ Locations…`,
  /// a menu the application does not have. A project with no floorplan
  /// now shows its rooms at full rail height rather than an empty list of
  /// a thing most projects never have.
  Widget _rail(PlanUnderlay? open) {
    final underlays = _underlays;
    return Column(
      children: [
        if (underlays.isNotEmpty && open != null) ...[
          Expanded(
            child: _UnderlayList(
              underlays: underlays,
              openId: open.id,
              doc: _controller.doc,
              onOpen: _openPlan,
              onCalibrate: _beginCalibrate,
              onEdit: () => unawaited(_editOpenPlan()),
              onRotate: _rotateOpenPlan,
              onRemove: () => unawaited(_removeOpenPlan()),
              onReorder: _reorderPlan,
            ),
          ),
          const Divider(height: 1),
        ],
        Expanded(
          child: LocationTreeList(
            doc: _controller.doc,
            selectedId: _selectedLocation,
            onSelect: (id) => setState(() => _selectedLocation = id),
          ),
        ),
        const Divider(height: 1),
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: TextButton.icon(
              key: const ValueKey('site-add-room'),
              onPressed: _addLocation,
              icon: const Icon(Icons.add, size: 16),
              label: Text(
                _selectedLocation == null ? kAddRoom : kAddRoomUnder,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// The right region docs/15 §6 ruled and `PLAN-E/5` did not build
  /// (`#892`, DR-168).
  ///
  /// **ITS OWN HEADER NAMED THIS AS OWED**: *"there is no standard
  /// inspector to put there ... the column is absent rather than
  /// invented"*, because `InspectorPanel` takes a `required Rack` and a
  /// pin's carrier may be an outlet or an off-rack device. The merge is
  /// what finally gives the region something it can honestly show: the
  /// selected ROOM, which is a thing both halves of this view are about.
  Widget _inspector(PlanUnderlay? open) {
    final selected = _selectedLocation;
    final location = selected == null
        ? null
        : _controller.doc.locations[selected];
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // THE OUTLINE ACTIONS LIVE WITH THE ROOM THEY ACT ON. They were
          // three buttons on a read-only room list in the rail; a room's
          // shape on a plan is a property of that room, and this is where
          // its properties are.
          if (location != null && open != null)
            _OutlineActions(
              location: location,
              underlay: open,
              doc: _controller.doc,
              drawingId: _outline.isActive ? _outline.locationId : null,
              reshapingId: _reshape.isActive ? _reshape.locationId : null,
              onDraw: _beginOutline,
              onReshape: _beginReshape,
              onClear: _clearOutline,
            ),
          Expanded(
            child: LocationDetailPane(
              location: location,
              doc: _controller.doc,
              actions: widget.locations,
              onEdit: _editLocation,
              onReparent: _reparentLocation,
              onDelete: _deleteLocation,
            ),
          ),
        ],
      ),
    );
  }

  Widget _planColumn(BuildContext context, PlanUnderlay open) {
    final strip = unpinnedCarriersFor(_controller.doc, open);
    return Column(
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
    required this.onEdit,
    required this.onRotate,
    required this.onRemove,
    required this.onReorder,
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

  /// Opens `Edit plan…` on the OPEN plan (DR-185 §11.184.1), for
  /// [onCalibrate]'s reason.
  final VoidCallback onEdit;

  /// Turns the OPEN plan a quarter (DR-184 §11.183.4), for [onCalibrate]'s
  /// reason exactly: the canvas is showing one plan, and a button on a
  /// closed row that turned a picture nobody could see would be the bug
  /// this signature makes unspellable.
  final void Function({required bool clockwise}) onRotate;

  /// Removes the OPEN plan, for [onCalibrate]'s reason exactly: the
  /// confirmation counts what is on one page, and a button on a closed
  /// row that removed a different picture is the bug this signature makes
  /// unspellable.
  final VoidCallback onRemove;

  /// Moves the page at `from` to `at` (`#878`, DR-162 §11.161.4).
  ///
  /// TWO INDICES AND NOT AN ID, because that is what the reorderable list
  /// speaks and the caller has the ordered list in front of it. The order
  /// itself is minted by `orderBetween` against the two NEIGHBOURS, which
  /// is a single field write rather than a renumber of the rail
  /// (§11.161.5).
  final void Function(int from, int at) onReorder;

  /// A stable handle for tests, per row.
  static String calibrateKeyFor(Uuid id) => 'underlay-calibrate-${id.v}';

  /// Ditto for the removal.
  static String removeKeyFor(Uuid id) => 'underlay-remove-${id.v}';

  /// Ditto for `Edit plan…`.
  static String editKeyFor(Uuid id) => 'underlay-edit-${id.v}';

  /// Ditto for the two turns.
  static String rotateLeftKeyFor(Uuid id) => 'underlay-rotate-left-${id.v}';
  static String rotateRightKeyFor(Uuid id) => 'underlay-rotate-right-${id.v}';

  /// Ditto for the row itself.
  static String rowKeyFor(Uuid id) => 'underlay-row-${id.v}';

  /// Ditto for the grip a reorder starts from.
  static String dragKeyFor(Uuid id) => 'underlay-drag-${id.v}';

  @override
  Widget build(BuildContext context) => ReorderableListView.builder(
    itemCount: underlays.length,
    // ═════════════════════════════════════════════════════════════════
    // A HANDLE, NOT THE WHOLE ROW (`#878`, DR-162 §11.161.4)
    // ═════════════════════════════════════════════════════════════════
    // Settled by the user. These rows carry tap-to-open plus `Calibrate`
    // and `Remove`, and all three live INSIDE what a whole-row drag would
    // claim: a slow tap becomes a drag and a missed button press reorders
    // the set. `buildDefaultDragHandles: false` is what hands the gesture
    // to the grip instead.
    //
    // UP AND DOWN BUTTONS WERE THE OTHER OPTION AND WERE REFUSED ON A
    // MEASUREMENT. This row overflowed by 126 pixels at 240 wide holding
    // ONE button (see `_UnderlayRow`), and the `Wrap` that fixed it is
    // what two more would have had to negotiate with.
    buildDefaultDragHandles: false,
    // `onReorderItem` and not `onReorder`, which `port_grid.dart` already
    // records: the older callback reports a `to` measured against the
    // list BEFORE the dragged row leaves it, so dropping row 0 at the
    // foot answers `length` rather than `length - 1`.
    onReorderItem: onReorder,
    // THE DEFAULT PROXY IS RIGHT HERE, unlike the port grid's. A rail row
    // is a card-shaped thing already, so lifting and elevating it reads
    // as being carried rather than as coming apart.
    itemBuilder: (context, i) {
      final u = underlays[i];
      return _UnderlayRow(
        key: ValueKey(_UnderlayList.rowKeyFor(u.id)),
        underlay: u,
        open: u.id == openId,
        dragIndex: i,
        reorderable: underlays.length > 1,
        room: u.locationId == null ? null : doc.locations[u.locationId]?.name,
        // DERIVED PER ROW AND PER BUILD, so the line answers for the
        // document as it is now. It moves when the SCALE changes and
        // equally when a PIN does, which is the half a mask-shaped
        // reading of this feature misses: pinning the rack is what turns
        // `no rack pinned` into a count, and no calibration happened.
        measurability: planMeasurabilityOf(doc, u),
        onOpen: () => onOpen(u.id),
        onCalibrate: onCalibrate,
        onEdit: onEdit,
        onRotate: onRotate,
        onRemove: onRemove,
      );
    },
  );
}

/// What the rail's grip says it does.
const String kReorderPagesTooltip = 'Drag to reorder the pages';

/// What a reorder says when `orderBetween` cannot mint a value.
///
/// **REFUSED IN WORDS RATHER THAN RENUMBERING THE RAIL** (DR-162
/// §11.161.5). The one pair it cannot answer is reachable only from a
/// hand-edited file, and rewriting every page's order behind somebody's
/// back is a much larger edit than the gesture asked for.
const String kReorderPagesRefused =
    'These two pages are ordered too close together to fit another '
    'between them. This can only happen in a file another program wrote.';

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
    required this.onEdit,
    required this.onRotate,
    required this.onRemove,
    required this.dragIndex,
    required this.reorderable,
    super.key,
  });

  final PlanUnderlay underlay;
  final bool open;

  /// This row's position in the rail, which is what
  /// `ReorderableDragStartListener` speaks.
  final int dragIndex;

  /// **FALSE ON A ONE-PAGE SET**, where the grip would be a control that
  /// cannot do anything. A rail with a single row has no order to change,
  /// and `#872`'s whole family of findings is about surfaces that offer
  /// what they cannot perform.
  final bool reorderable;

  /// What this plan can measure, for the state line (`PLAN-F/2`).
  final PlanMeasurability measurability;

  /// The room this plan depicts, or null. A plan with no location is
  /// perfectly ordinary and is not an error to report: the model says a
  /// site plan depicts no room, so the line is absent rather than reading
  /// "no location".
  final String? room;

  final VoidCallback onOpen;
  final VoidCallback onCalibrate;
  final VoidCallback onEdit;
  final void Function({required bool clockwise}) onRotate;
  final VoidCallback onRemove;

  /// One of the two turn buttons (DR-184 §11.183.4).
  ///
  /// **ICONS AND NOT WORDS**, unlike the two text buttons beside them. This
  /// row overflowed by 126 pixels at 240 wide holding ONE text button,
  /// which is why it is a `Wrap`; two more words would push `Remove…` onto
  /// a third line in a narrow rail. The arrows are the convention every
  /// image and PDF tool uses for exactly this act, and the tooltip carries
  /// both the words and the chord, read off the keymap row so it cannot
  /// name a key nothing listens for.
  Widget _rotateButton(
    ThemeData theme, {
    required bool clockwise,
    required String key,
  }) {
    final binding = keyBindingFor(
      clockwise
          ? KeyBindingId.rotatePlanClockwise
          : KeyBindingId.rotatePlanAnticlockwise,
    );
    return IconButton(
      key: ValueKey(key),
      onPressed: () => onRotate(clockwise: clockwise),
      tooltip:
          '${clockwise ? 'Rotate right' : 'Rotate left'} '
          '(${binding.renderChord(defaultTargetPlatform)})',
      icon: Icon(clockwise ? Icons.rotate_right : Icons.rotate_left),
      iconSize: 16,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 28, height: 28),
      color: theme.colorScheme.onSurfaceVariant,
    );
  }

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
            Row(
              children: [
                Expanded(
                  child: Text(
                    underlay.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                // ON THE NAME LINE AND NOT IN THE `Wrap` BELOW, which is
                // where the two buttons live. That `Wrap` exists because
                // this row overflowed by 126 pixels at 240 wide, and it
                // works by DROPPING its children onto a second line: a
                // grip that moved under the state text when the rail
                // narrowed would be a drag target that changes place.
                if (reorderable)
                  ReorderableDragStartListener(
                    key: ValueKey(_UnderlayList.dragKeyFor(underlay.id)),
                    index: dragIndex,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.grab,
                      child: Tooltip(
                        message: kReorderPagesTooltip,
                        child: Icon(
                          Icons.drag_indicator,
                          size: 16,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
              ],
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
                // `Edit plan…` LEADS THE ACTIONS (DR-185 §11.184.1): the
                // name and the place are what a person reads this row for,
                // so the control that changes them sits nearest to them.
                // An icon for `#911`'s reason: this row overflowed at 240
                // wide holding one text button.
                if (open)
                  IconButton(
                    key: ValueKey(_UnderlayList.editKeyFor(underlay.id)),
                    onPressed: onEdit,
                    tooltip: 'Edit plan… (name, and the floor it shows)',
                    icon: const Icon(Icons.edit_outlined),
                    iconSize: 16,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 28,
                      height: 28,
                    ),
                    color: theme.colorScheme.onSurfaceVariant,
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
                // THE TURNS SIT BETWEEN CALIBRATE AND REMOVE, and only on
                // the open row (DR-184 §11.183.4). A turn is a property of
                // the plan and this is DR-144 §11.143.4's host for one;
                // `Remove…` stays last because it is the destructive act.
                if (open)
                  _rotateButton(
                    theme,
                    clockwise: false,
                    key: _UnderlayList.rotateLeftKeyFor(underlay.id),
                  ),
                if (open)
                  _rotateButton(
                    theme,
                    clockwise: true,
                    key: _UnderlayList.rotateRightKeyFor(underlay.id),
                  ),
                // REMOVE SITS BESIDE CALIBRATE, and only on the open row.
                // `RemovePlanUnderlayCommand` shipped at `PLAN-C/6` with a
                // real revert, a pin cascade and seven tests, and NOTHING
                // EVER BUILT ONE (`#870`): the only way to not have a page
                // was to never have imported it, which makes a wrong page
                // picked out of a multi-page PDF permanent.
                if (open)
                  TextButton(
                    key: ValueKey(_UnderlayList.removeKeyFor(underlay.id)),
                    onPressed: onRemove,
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      foregroundColor: theme.colorScheme.error,
                    ),
                    child: Text('Remove…', style: theme.textTheme.labelSmall),
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

/// The selected room's outline on the OPEN plan, and the three acts that
/// change it (`#892`, DR-168).
///
/// ═══════════════════════════════════════════════════════════════════════
/// THESE WERE THREE BUTTONS ON A ROW IN A LIST IN THE RAIL
/// ═══════════════════════════════════════════════════════════════════════
/// `_RoomList` showed every room of the open plan's location subtree, each
/// with Draw, Reshape and Clear. A room's shape on a plan is a property of
/// that room, and since `#891` its properties are in this column, so the
/// list stopped earning the rail height it took: the tree lists the rooms,
/// and the room that is selected is the one these act on.
///
/// **THE UNDERLAY IS PART OF THE QUESTION.** A room whose shape was drawn
/// on another plan has none HERE, and offering `Clear` for it would take
/// away something the person is not looking at.
class _OutlineActions extends StatelessWidget {
  const _OutlineActions({
    required this.location,
    required this.underlay,
    required this.doc,
    required this.drawingId,
    required this.reshapingId,
    required this.onDraw,
    required this.onReshape,
    required this.onClear,
  });

  final Location location;
  final PlanUnderlay underlay;
  final RackDocument doc;
  final Uuid? drawingId;
  final Uuid? reshapingId;
  final void Function(Uuid locationId) onDraw;
  final void Function(Uuid locationId) onReshape;
  final void Function(Uuid locationId) onClear;

  /// A stable handle per act, kept at the names `_RoomList` used so the
  /// cases that drive them did not have to be rewritten to follow the
  /// buttons across the view.
  static String drawKeyFor(Uuid id) => 'room-draw-${id.v}';
  static String reshapeKeyFor(Uuid id) => 'room-reshape-${id.v}';
  static String clearKeyFor(Uuid id) => 'room-clear-${id.v}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasOutline = location.planOutline?.underlayId == underlay.id;
    final busy = location.id == drawingId || location.id == reshapingId;
    return Container(
      width: double.infinity,
      color: busy ? theme.colorScheme.primaryContainer : null,
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('On ${underlay.name}', style: theme.textTheme.labelLarge),
          // PRINTED IN BOTH DIRECTIONS (G4), on the calibration row's own
          // rule: "no outline yet" is a fact worth stating, and saying
          // nothing would leave "not drawn" and "drawn and I have
          // forgotten" looking identical.
          Text(
            hasOutline ? 'Outline drawn' : 'No outline yet',
            style: theme.textTheme.labelSmall,
          ),
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                key: ValueKey(drawKeyFor(location.id)),
                onPressed: () => onDraw(location.id),
                child: Text(hasOutline ? 'Redraw…' : 'Draw…'),
              ),
              // RESHAPE ONLY WHERE THERE IS A SHAPE, which is `Clear`'s
              // own condition and reads the same way: a button offering
              // to correct a room that has no outline would be offering
              // an act with nothing to perform it on.
              if (hasOutline)
                TextButton(
                  key: ValueKey(reshapeKeyFor(location.id)),
                  onPressed: () => onReshape(location.id),
                  child: const Text('Reshape…'),
                ),
              if (hasOutline)
                TextButton(
                  key: ValueKey(clearKeyFor(location.id)),
                  onPressed: () => onClear(location.id),
                  child: const Text('Clear'),
                ),
            ],
          ),
          const Divider(height: 17),
        ],
      ),
    );
  }
}
