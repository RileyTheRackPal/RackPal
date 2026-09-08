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
import 'package:flutter/material.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/src/canvas/plan/plan_canvas_screen.dart';
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

  DocumentController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _controller.changes.addListener(_onDocumentChanged);
  }

  @override
  void dispose() {
    _controller.changes.removeListener(_onDocumentChanged);
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

  @override
  Widget build(BuildContext context) {
    final open = _open;
    if (open == null) return const _EmptyPlan();

    final strip = unpinnedCarriersFor(_controller.doc, open);
    return Row(
      children: [
        SizedBox(
          width: 240,
          child: _UnderlayList(
            underlays: _underlays,
            openId: open.id,
            locations: _controller.doc.locations,
            onOpen: (id) => setState(() => _openId = id),
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: Column(
            children: [
              Expanded(
                child: PlanCanvasScreen(
                  key: _canvasKeyFor(open.id),
                  controller: _controller,
                  underlay: open,
                  images: widget.images,
                  measurer: widget.measurer,
                  selection: widget.selection,
                  viewport: _viewportFor(open.id),
                  arm: widget.arm,
                  onRefuse: widget.onRefuse,
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

/// The left rail: which plans this project holds, and which is open.
class _UnderlayList extends StatelessWidget {
  const _UnderlayList({
    required this.underlays,
    required this.openId,
    required this.locations,
    required this.onOpen,
  });

  final List<PlanUnderlay> underlays;
  final Uuid openId;
  final Map<Uuid, Location> locations;
  final void Function(Uuid id) onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView.builder(
      itemCount: underlays.length,
      itemBuilder: (context, i) {
        final u = underlays[i];
        final room = u.locationId == null
            ? null
            : locations[u.locationId]?.name;
        return ListTile(
          key: ValueKey('underlay-row-${u.id.v}'),
          dense: true,
          selected: u.id == openId,
          title: Text(u.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          // THE ROOM, WHEN THERE IS ONE. A plan with no location is
          // perfectly ordinary and is not an error to report: the model
          // says a site plan depicts no room, so the line is simply
          // absent rather than reading "no location".
          subtitle: room == null
              ? null
              : Text(room, style: theme.textTheme.labelSmall),
          onTap: () => onOpen(u.id),
        );
      },
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
