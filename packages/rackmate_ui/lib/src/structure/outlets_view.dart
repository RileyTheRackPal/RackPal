// THE `[ Outlets ]` TAB. Board M3-H/2 (#167) and M3-H/3 (#168), DR-007
// §11.7, DR-028, DR-038, DR-041, CR-121.
//
// The fourth tab docs/07 §4 has drawn since M3-C and which
// `structure_editor_screen.dart` has named as absent ever since. It
// opens something now.
//
// ═════════════════════════════════════════════════════════════════════
// IT RENDERS DERIVATIONS. IT CONTAINS NONE.
// ═════════════════════════════════════════════════════════════════════
// Every rectangle comes from `draw/scene/plate_geometry.dart`, every
// count from `derived/plate_fill.dart`, every proposal from
// `structure/plate_arrange.dart`, and every keystone colour from
// `derived/jacket_color_resolution.dart`. This file owns VIEW state:
// which outlet is selected and which cell the menu is open on. That is
// the rule `pathways_view.dart` and the table tab already state.
//
// ═════════════════════════════════════════════════════════════════════
// THE KEYSTONE FOLLOWS THE CONVENTION, AND THIS FILE DOES NOT DECIDE SO
// ═════════════════════════════════════════════════════════════════════
// M3-H/3 (#168) in one line: `ResolvedJacketColor.keystoneColorId`
// returns `conventionId` and mentions the override nowhere, and that
// syntactic independence is mutation-tested by
// `jacket_color_resolution_test.dart`'s `keystone_follows_convention`
// group. This file CONSUMES that resolver. It does not re-derive it, and
// it must never reach for `jacketColorPulledId` directly.
//
// The reason is a trim-out fact, not a modelling preference (§11.7.5,
// CR-121): a keystone is fitted weeks after the pull, out of the same box
// as every other drop of that service, so it is routinely the convention
// colour even when the cable in the wall is not. A run mis-pulled in
// yellow still gets the blue jack its service calls for.
//
// **AN EXCEPTION IS SHOWN AS TEXT AND NEVER AS A HUE.** When
// `isException` is true the cell keeps its convention colour and the drop
// list says `BLU · PULLED YEL`. Tinting the jack toward the pulled colour
// would be this file quietly overruling the resolver.
//
// ═════════════════════════════════════════════════════════════════════
// WHY A JACKET COLOUR REACHES A CANVAS HERE AND NOWHERE ELSE
// ═════════════════════════════════════════════════════════════════════
// `jacket_colour_is_not_hue_test.dart` bans `jacketColorId` and its
// relatives from four drawing roots: core's `draw/`, export's `draw/`,
// and `rackmate_ui`'s `draw/` and `canvas/`. This file is in
// `structure/` and is deliberately NOT in any of them.
//
// That is not a dodge, it is the distinction CR-078 draws. The gate
// protects WIRE HUE: the eight domain colours are Okabe-Ito because they
// survive a colour-vision deficiency, and a shop's reel colours carry no
// such guarantee, so feeding jacket colour into the schematic would
// substitute an unvalidated palette for a validated one. A keystone is
// not a wire. It is a physical part whose colour IS the fact being drawn,
// and `jacket_color_resolution.dart`'s own header lists "a keystone
// answer" among the four things the resolver exists to produce.
//
// A PLATE PAINTER MUST THEREFORE NEVER MOVE INTO `canvas/`. If one is
// ever needed on the schematic sheet, it takes the colour as a resolved
// argument rather than importing the resolver.
//
// ═════════════════════════════════════════════════════════════════════
// AN UNKNOWN COLOUR IS DRAWN AS UNKNOWN
// ═════════════════════════════════════════════════════════════════════
// A drop with no convention colour, or one naming an entry somebody has
// since deleted, gets a hatched outline and no fill. NOT a default grey:
// grey is a colour somebody could have chosen, and a plate showing six
// grey jacks would be indistinguishable from a plate showing six jacks
// nobody has specified. `ResolvedJacketColor.hasUnknownEntry` is what
// says which, and G4 is why the answer is a different treatment rather
// than a substituted value.
import 'package:flutter/material.dart';
import 'package:rackmate_core/rackmate_core.dart';

/// What the tab can ask the application to do.
///
/// CALLBACKS AND NOT A CONTROLLER, the shape `PathwaysActions` and
/// `StructureEditorActions` already use, so `rackmate_ui` stays free of
/// the session layer. Each returns a refusal sentence or null.
@immutable
final class OutletsActions {
  const OutletsActions({
    required this.onAddGang,
    required this.onRemoveGang,
    required this.onSetStrap,
    required this.onSetPassThrough,
    required this.onSetCell,
    required this.onArrange,
  });

  final String? Function(Uuid outletId) onAddGang;
  final String? Function(Uuid outletId, int gangIndex) onRemoveGang;

  /// Null width and height un-choose the fitting.
  final String? Function(Uuid outletId, int gangIndex, int? width, int? height)
  onSetStrap;

  /// Fits a pass-through: this opening is a hole and gets no strap
  /// (DR-047).
  ///
  /// **NOT `onSetStrap` WITH A SENTINEL.** Un-choosing a fitting and
  /// fitting a brush are opposite acts: one says nobody has decided, the
  /// other is a decision and a purchase. They also carry different undo
  /// labels, for the same reason.
  final String? Function(Uuid outletId, int gangIndex, PassThroughStyle style)
  onSetPassThrough;

  /// A null occupant clears the cell back to UNDECIDED, which is not the
  /// same as fitting a blank. See `gang_commands.dart`.
  final String? Function(
    Uuid outletId,
    int gangIndex,
    int cellIndex,
    CellOccupant? occupant,
  )
  onSetCell;

  /// Commits a whole [PlateArrangement] as ONE undo step.
  final String? Function(Uuid outletId, PlateArrangement plan) onArrange;
}

/// What a [PassThroughStyle] is called on screen (DR-047 §11.46.3).
///
/// **ONE FUNCTION, THREE CALL SITES**: the picker, the button under the
/// opening and the plate's own tooltip. Three literals would drift, and
/// this vocabulary is a ruling rather than copy.
String passThroughLabel(PassThroughStyle style) => switch (style) {
  PassThroughStyle.brush => 'Brush',
  PassThroughStyle.bullNose => 'Bull-nose',
};

/// docs/07 §4's fourth tab: one plate at a time, drawn to scale.
class OutletsView extends StatefulWidget {
  const OutletsView({
    required this.doc,
    required this.actions,
    this.structureBodyId,
    super.key,
  });

  final RackDocument doc;
  final OutletsActions actions;
  final Uuid? structureBodyId;

  @override
  State<OutletsView> createState() => _OutletsViewState();
}

class _OutletsViewState extends State<OutletsView> {
  Uuid? _selected;
  String? _refusal;

  List<Outlet> get _outlets {
    final body = widget.structureBodyId;
    // TOTAL comparator: `order` then the id, because `List.sort` is not
    // stable and a plate list that reshuffled between rebuilds would move
    // a target under the hand of whoever was clicking it.
    return widget.doc.outlets.values
        .where((o) => body == null || o.structureBodyId == body)
        .toList()
      ..sort((a, b) {
        final byOrder = a.order.v.compareTo(b.order.v);
        return byOrder != 0 ? byOrder : a.id.v.compareTo(b.id.v);
      });
  }

  Outlet? get _current {
    final all = _outlets;
    if (all.isEmpty) return null;
    for (final o in all) {
      if (o.id == _selected) return o;
    }
    return all.first;
  }

  void _run(String? Function() action) {
    final refusal = action();
    setState(() => _refusal = refusal);
  }

  @override
  Widget build(BuildContext context) {
    final outlets = _outlets;
    if (outlets.isEmpty) return const _NoOutlets();

    final outlet = _current!;
    final links = widget.doc.links.values.toList();
    final fill = computePlateFill(outlet, links);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 220,
          child: _OutletList(
            outlets: outlets,
            selected: outlet.id,
            links: links,
            onSelect: (id) => setState(() {
              _selected = id;
              _refusal = null;
            }),
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: _PlatePane(
            doc: widget.doc,
            outlet: outlet,
            links: links,
            fill: fill,
            refusal: _refusal,
            actions: widget.actions,
            run: _run,
          ),
        ),
      ],
    );
  }
}

/// The left rail: every plate in this body, with what each still owes.
class _OutletList extends StatelessWidget {
  const _OutletList({
    required this.outlets,
    required this.selected,
    required this.links,
    required this.onSelect,
  });

  final List<Outlet> outlets;
  final Uuid selected;
  final List<Link> links;
  final ValueChanged<Uuid> onSelect;

  @override
  Widget build(BuildContext context) => ListView.builder(
    itemCount: outlets.length,
    itemBuilder: (context, i) {
      final outlet = outlets[i];
      final fill = computePlateFill(outlet, links);
      return ListTile(
        dense: true,
        selected: outlet.id == selected,
        title: Text(outlet.designation),
        subtitle: Text(_subtitleFor(fill)),
        onTap: () => onSelect(outlet.id),
      );
    },
  );

  /// **THE UNKNOWN COUNT IS NEVER FOLDED INTO THE SHORTFALL.** A plate
  /// with room for everything known and three drops nobody has
  /// terminated is not a plate that fits; it is a plate nobody can say
  /// that about. `totals.dart`'s rule 2, on a smaller number.
  static String _subtitleFor(PlateFill fill) {
    final parts = <String>[
      '${fill.gangCount} gang',
      if (fill.fittingsUnchosen > 0) '${fill.fittingsUnchosen} no strap',
      // COUNTED SEPARATELY FROM "no strap", which is the whole of DR-047
      // at this scale: one is an opening nobody has decided and this is
      // one somebody decided gets a hole.
      if (fill.passThroughGangs > 0) '${fill.passThroughGangs} pass-through',
      if (fill.shortfall > 0) 'short ${fill.shortfall}',
      if (fill.unknownDrops > 0) '${fill.unknownDrops} unknown',
      if (fill.isSettled) 'fits',
    ];
    return parts.join(' · ');
  }
}

/// The plate itself, its controls, and the drops waiting for a cell.
class _PlatePane extends StatelessWidget {
  const _PlatePane({
    required this.doc,
    required this.outlet,
    required this.links,
    required this.fill,
    required this.refusal,
    required this.actions,
    required this.run,
  });

  final RackDocument doc;
  final Outlet outlet;
  final List<Link> links;
  final PlateFill fill;
  final String? refusal;
  final OutletsActions actions;
  final void Function(String? Function()) run;

  /// How many inserts of each style, IN ENUM ORDER so two runs of the
  /// same plate emit the same chips (§8.4). A `toSet()` over the list
  /// would order them by first appearance, which is a fact about which
  /// opening a person clicked first.
  static Map<PassThroughStyle, int> _insertCounts(PlateMaterials m) => {
    for (final style in PassThroughStyle.values)
      if (m.passThroughInserts.contains(style))
        style: m.passThroughInserts.where((s) => s == style).length,
  };

  /// What the one cover plate is, in the chip's words (DR-047 §11.46.4).
  ///
  /// **[CoverPlateKind.unknown] SAYS SO RATHER THAN GUESSING DECORA.**
  /// With one opening nobody has fitted and no strap to settle it, the
  /// plate could still turn out to be an integral brush plate, and naming
  /// a part on the strength of an absence of work is the exact defect G4
  /// exists to stop.
  static String _coverPlateLabel(PlateMaterials m) => switch (m.coverPlate) {
    CoverPlateKind.none => 'no plate needed',
    CoverPlateKind.decora => '${m.coverPlateGangs}-gang cover plate',
    CoverPlateKind.brush => '${m.coverPlateGangs}-gang brush plate',
    CoverPlateKind.bullNose => '${m.coverPlateGangs}-gang bull-nose plate',
    CoverPlateKind.unknown => '${m.coverPlateGangs}-gang plate, kind unknown',
  };

  @override
  Widget build(BuildContext context) {
    final unplaced = unplacedDropsOf(outlet, links);
    final materials = computePlateMaterials(outlet);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      outlet.designation,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    // §11.7.8 change 1: N straps plus exactly ONE N-gang
                    // cover plate, and the count is gangs.length, always.
                    // WHAT KIND of plate is DR-047's derivation, and the
                    // chip says it rather than assuming Decora: a plate
                    // whose every opening is brushed is one part, and a
                    // mixed plate is a Decora plus inserts.
                    Chip(
                      key: const ValueKey('plate-cover-chip'),
                      label: Text(_coverPlateLabel(materials)),
                      visualDensity: VisualDensity.compact,
                    ),
                    for (final entry in _insertCounts(materials).entries)
                      Chip(
                        label: Text(
                          '${entry.value} '
                          '${passThroughLabel(entry.key).toLowerCase()} '
                          'insert',
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                    if (fill.blanksFitted > 0)
                      Chip(
                        label: Text('${fill.blanksFitted} blank'),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ),
              OutlinedButton(
                onPressed: () => run(() => actions.onAddGang(outlet.id)),
                child: const Text('+ Add gang'),
              ),
              const SizedBox(width: 8),
              FilledButton.tonal(
                onPressed: () => _arrange(context),
                child: const Text('Arrange'),
              ),
            ],
          ),
        ),
        if (refusal != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              refusal!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                // SCROLLS BOTH WAYS, and the horizontal one is not
                // decoration. A plate is drawn to scale, so its width is
                // a fact about the part rather than about the pane: at
                // DR-042's outline a 3-gang plate is 647 units wide, and
                // a pane narrower than that must scroll rather than
                // clip. Clipping a dimensioned drawing is worse than
                // scrolling it, because a clipped plate still looks like
                // a plate and simply omits the last gang.
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: _PlateWidget(
                      doc: doc,
                      outlet: outlet,
                      links: links,
                      fill: fill,
                      onCell: (gang, cell) =>
                          _pickOccupant(context, gang, cell),
                      onStrap: (gang) => _pickFitting(context, gang),
                      onRemove: (gang) => _removeGang(context, gang),
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 260,
                child: _DropList(
                  doc: doc,
                  outlet: outlet,
                  links: links,
                  unplaced: unplaced,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// **ARRANGE IS DESTRUCTIVE AND ASKS FIRST when the plate holds
  /// anything.** `planPlateArrangement` does not consult the existing
  /// plate, so committing it replaces hand-placed work; a merge would
  /// have to guess which of two arrangements the person meant. The prompt
  /// counts what it will discard, which is DR-013's "a confirmation that
  /// counts the cables".
  Future<void> _arrange(BuildContext context) async {
    final plan = planPlateArrangement(outlet, links);
    if (plan.isEmpty) {
      run(
        () => plan.skippedUnknown > 0
            ? 'Nothing to arrange: ${plan.skippedUnknown} drop(s) have no '
                  'recorded field termination, so how many cells they need '
                  'is unknown.'
            : 'Nothing to arrange: no drop landing here needs a cell.',
      );
      return;
    }
    if (fill.cellsOccupied > 0 || fill.blanksFitted > 0) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Re-arrange this plate?'),
          content: Text(
            'This replaces the whole plate. '
            '${fill.cellsOccupied} keystone(s) and ${fill.blanksFitted} '
            'blank(s) already placed will be re-placed from scratch.'
            '${plan.skippedUnknown > 0 ? "\n\n${plan.skippedUnknown} drop(s) "
                      "have no recorded field termination and will be left "
                      "off." : ""}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Arrange'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    run(() => actions.onArrange(outlet.id, plan));
  }

  /// Removes one gang, asking first when it holds anything.
  ///
  /// **THE CALL SITE THAT DID NOT EXIST UNTIL M3-H/5.**
  /// `RemoveGangCommand` was built and tested, `OutletsActions.onRemoveGang`
  /// was declared, and `buildOutletsActions` implemented it. Nothing
  /// invoked it, so the only way to remove a gang was `Ctrl+Z` or a full
  /// destructive `Arrange`. `actions_have_callers_test.dart` is
  /// now the gate that fails if a callback loses its caller again.
  ///
  /// **THE CONFIRMATION COUNTS WHAT IT DISCARDS** and appears only when
  /// there is something to discard, which is DR-013's "a cascade with a
  /// confirmation that counts the cables" and `_pickFitting`'s own shape.
  /// An empty gang goes without a prompt: a dialog for a gesture that
  /// destroys nothing trains people to dismiss dialogs.
  Future<void> _removeGang(BuildContext context, int gangIndex) async {
    if (gangIndex < 0 || gangIndex >= outlet.gangs.length) return;
    // A pass-through holds no cells, so removing one destroys nothing to
    // count and goes without a prompt, exactly like an empty gang.
    final occupied = occupantsLostByPassThrough(outlet.gangs[gangIndex]);

    if (occupied > 0) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Remove gang ${gangIndex + 1}?'),
          content: Text(
            'It holds $occupied filled cell(s), and they go with it. '
            'Undo puts the gang back with everything in it.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Remove'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    run(() => actions.onRemoveGang(outlet.id, gangIndex));
  }

  /// One picker for the whole opening: a strap, a hole, or nothing
  /// decided (DR-047 §11.46.2).
  ///
  /// **THE THREE ANSWERS SIT IN ONE LIST BECAUSE THEY ARE ONE QUESTION**,
  /// *"what is in this opening"*. A separate `Fit pass-through` control
  /// beside the strap button would let a person hold both answers at
  /// once on screen and would have to explain which wins.
  ///
  /// The result is a RECORD around a nullable fitting, for the reason
  /// `_pickOccupant` gives at length: a bare `GangFitting?` makes
  /// *"nothing chosen"* and *"I dismissed the dialog"* the same value,
  /// and here that would silently un-choose a 6-port strap on Escape.
  Future<void> _pickFitting(BuildContext context, int gangIndex) async {
    final choice = await showDialog<({GangFitting? fitting})>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('Gang ${gangIndex + 1}'),
        children: [
          // DERIVED FROM THE BOUNDS, so five ports never appears as an
          // option and nothing here lists the port counts (§11.7.1).
          for (var w = kMinStrapWidth; w <= kMaxStrapWidth; w++)
            for (var h = kMinStrapHeight; h <= kMaxStrapHeight; h++)
              SimpleDialogOption(
                onPressed: () => Navigator.of(
                  context,
                ).pop((fitting: Strap(width: w, height: h))),
                child: Text('${w * h}-port  ($w x $h)'),
              ),
          const Divider(height: 1),
          // DERIVED FROM THE ENUM for the same reason the straps are
          // derived from the bounds: a hand-written list here is a fact
          // about this dialog, and the vocabulary is a fact about the
          // ruling (§11.46.3).
          for (final style in PassThroughStyle.values)
            SimpleDialogOption(
              onPressed: () =>
                  Navigator.of(context).pop((fitting: PassThrough(style))),
              child: Text(passThroughLabel(style)),
            ),
          const Divider(height: 1),
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop((fitting: null)),
            // NOT "no strap" and not "none". This is the UNDECIDED arm,
            // and the two arms above it are both decisions.
            child: const Text('Nothing chosen yet'),
          ),
        ],
      ),
    );
    if (choice == null) return;

    final gang = outlet.gangs[gangIndex];
    final lost = switch (choice.fitting) {
      final Strap s => occupantsLostByResize(gang, s.width, s.height),
      // A hole has no cells and neither has an undecided opening, so both
      // discard everything the strap was holding.
      null || PassThrough() => occupantsLostByPassThrough(gang),
    };
    if (lost > 0 && context.mounted) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(switch (choice.fitting) {
            Strap() => 'Smaller strap',
            PassThrough() => 'Fit a pass-through?',
            null => 'Un-choose this gang?',
          }),
          content: Text(
            '$lost keystone(s) sit in cells this gang will not have and '
            'will be taken off the plate. Undo puts them back.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Fit it'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    switch (choice.fitting) {
      case null:
        run(() => actions.onSetStrap(outlet.id, gangIndex, null, null));
      case final Strap s:
        run(() => actions.onSetStrap(outlet.id, gangIndex, s.width, s.height));
      case final PassThrough p:
        run(() => actions.onSetPassThrough(outlet.id, gangIndex, p.style));
    }
  }

  Future<void> _pickOccupant(
    BuildContext context,
    int gangIndex,
    int cellIndex,
  ) async {
    final unplaced = unplacedDropsOf(outlet, links);
    // WRAPPED IN A RECORD, and it is not decoration. `Clear it` and a
    // dismissed dialog are two different answers that both spell null:
    // one means "make this cell undecided" and the other means "I
    // changed my mind". Returning a bare `CellOccupant?` collapses them
    // and makes pressing Escape clear a cell, which is a destructive
    // cancel and the worst kind of bug to find by accident.
    final choice = await showDialog<({CellOccupant? occupant})>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('What goes in this cell?'),
        children: [
          for (final id in unplaced) ..._optionsForDrop(context, doc.links[id]),
          // TWO DIFFERENT ANSWERS, and the labels say which is which.
          // A blank insert is a decision and a purchase (§11.7.4);
          // clearing is the absence of one and orders nothing.
          SimpleDialogOption(
            onPressed: () =>
                Navigator.of(context).pop((occupant: const BlankInsert())),
            child: const Text('Blank insert (a part, on the materials list)'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop((occupant: null)),
            child: const Text('Clear it (nobody has decided)'),
          ),
        ],
      ),
    );
    if (choice == null) return;
    run(
      () => actions.onSetCell(
        outlet.id,
        gangIndex,
        cellIndex,
        choice.occupant,
      ),
    );
  }

  List<Widget> _optionsForDrop(BuildContext context, Link? link) {
    if (link == null) return const [];
    final label = link.structureOrigin?.fieldLabel ?? link.designator;
    final needed = cellsRequiredFor(
      link.structureOrigin?.terminationField,
      link.conductors.length,
    );
    // ONE OPTION PER POST for a binding-post drop, because a cell holds
    // one conductor and the person has to say which (§11.7.2.1).
    if (needed != null && needed > 1) {
      return [
        for (var i = 0; i < needed; i++)
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop((
              occupant: ConductorOccupant(ConductorRef(link.id, i)),
            )),
            child: Text('$label  ${_roleOf(link, i)}'),
          ),
      ];
    }
    if (needed == null) {
      // Offerable, but the label says why it is not arrangeable: the
      // termination is unrecorded and the cell count is a guess nobody
      // has made.
      return [
        SimpleDialogOption(
          onPressed: () =>
              Navigator.of(context).pop((occupant: LinkEndOccupant(link.id))),
          child: Text('$label  (no field termination recorded)'),
        ),
      ];
    }
    return [
      SimpleDialogOption(
        onPressed: () =>
            Navigator.of(context).pop((occupant: LinkEndOccupant(link.id))),
        child: Text(label),
      ),
    ];
  }

  static String _roleOf(Link link, int index) {
    if (index >= link.conductors.length) return 'post ${index + 1}';
    final role = link.conductors[index].role;
    return role.isEmpty ? 'post ${index + 1}' : role;
  }
}

/// The plate drawing: openings, cells, and a tap target on each.
class _PlateWidget extends StatelessWidget {
  const _PlateWidget({
    required this.doc,
    required this.outlet,
    required this.links,
    required this.fill,
    required this.onCell,
    required this.onStrap,
    required this.onRemove,
  });

  final RackDocument doc;
  final Outlet outlet;
  final List<Link> links;
  final PlateFill fill;
  final void Function(int gangIndex, int cellIndex) onCell;
  final ValueChanged<int> onStrap;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    if (outlet.gangs.isEmpty) return _NoGangs(fill: fill);

    // ONE PLATE, N OPENINGS IN IT. Until DR-042 the outline was an
    // unruled "about", so each gang was drawn as its own free-floating
    // box with an arbitrary gap between them: a picture of some holes
    // rather than of a part. The measurement is what lets this be a
    // cover plate at 1.8125 in pitch with real plastic around the edge,
    // which is the whole visible payoff of that caliper reading.
    final geometry = PlateGeometry(outlet.gangs.length);
    final plate = geometry.bounds;
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          key: const ValueKey('plate-outline'),
          width: plate.width,
          height: plate.height,
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: scheme.outline),
                    borderRadius: BorderRadius.circular(4),
                    color: scheme.surface,
                  ),
                ),
              ),
              for (var g = 0; g < outlet.gangs.length; g++)
                _positionedGang(context, geometry, g),
            ],
          ),
        ),
        const SizedBox(height: 6),
        // The strap pickers sit UNDER their own openings rather than in a
        // row of their own, so "which strap am I changing" is answered by
        // position on a 3-gang plate instead of by counting.
        SizedBox(
          width: plate.width,
          height: 32,
          child: Stack(
            children: [
              for (var g = 0; g < outlet.gangs.length; g++)
                Positioned(
                  left: geometry.openingAt(g).left,
                  width: geometry.openingAt(g).width,
                  top: 0,
                  child: _GangControls(
                    gangIndex: g,
                    fitting: outlet.gangs[g].fitting,
                    onStrap: () => onStrap(g),
                    onRemove: () => onRemove(g),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _positionedGang(
    BuildContext context,
    PlateGeometry geometry,
    int gangIndex,
  ) {
    final opening = geometry.openingAt(gangIndex);
    return Positioned(
      left: opening.left,
      top: opening.top,
      width: opening.width,
      height: opening.height,
      child: _GangWidget(
        key: ValueKey('plate-opening-$gangIndex'),
        doc: doc,
        gangIndex: gangIndex,
        gang: outlet.gangs[gangIndex],
        links: links,
        onCell: (cell) => onCell(gangIndex, cell),
      ),
    );
  }
}

/// The two controls under one opening: what is fitted, and remove the
/// gang.
///
/// **THE DELETE SITS BESIDE THE THING IT DELETES**, rather than in the
/// strap dialog or behind a right-click. A destructive action folded into
/// a menu labelled `6-port` is one nobody looks for, and this app has no
/// other context menu to teach the right-click with. Adjacency is what
/// buys discoverability here; the confirmation is what buys safety, and
/// the two are different problems.
class _GangControls extends StatelessWidget {
  const _GangControls({
    required this.gangIndex,
    required this.fitting,
    required this.onStrap,
    required this.onRemove,
  });

  final int gangIndex;
  final GangFitting? fitting;
  final VoidCallback onStrap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    mainAxisSize: MainAxisSize.min,
    children: [
      Flexible(
        child: TextButton(
          key: ValueKey('plate-strap-$gangIndex'),
          onPressed: onStrap,
          style: TextButton.styleFrom(padding: EdgeInsets.zero),
          child: Text(
            switch (fitting) {
              // NOT "0-port". A gang whose part nobody has chosen is
              // unknown, and saying zero would make it look decided.
              null => 'No strap',
              Strap(:final cellCount) => '$cellCount-port',
              // A DECISION, so it reads as a part rather than as an
              // absence. This button said "No strap" for a brushed
              // opening in every draft before DR-047, which is the M3-H
              // plateless-outlet defect one scale down.
              PassThrough(:final style) => passThroughLabel(style),
            },
            style: const TextStyle(fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
      IconButton(
        key: ValueKey('plate-remove-$gangIndex'),
        onPressed: onRemove,
        icon: const Icon(Icons.close, size: 14),
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
        tooltip: 'Remove gang ${gangIndex + 1}',
      ),
    ],
  );
}

/// One gang opening and its cells, sized and positioned by its parent.
///
/// FILLS ITS BOX rather than measuring itself, because since DR-042 the
/// opening's position is a fact about the PLATE and only the plate knows
/// the gang count. Cell rectangles still come from [PlateGeometry], via
/// a single-gang instance whose opening is at the same offset, so both
/// halves read the same figures.
class _GangWidget extends StatelessWidget {
  const _GangWidget({
    required this.doc,
    required this.gangIndex,
    required this.gang,
    required this.links,
    required this.onCell,
    super.key,
  });

  final RackDocument doc;
  final int gangIndex;
  final Gang gang;
  final List<Link> links;
  final ValueChanged<int> onCell;

  @override
  Widget build(BuildContext context) {
    // A ONE-GANG GEOMETRY, whose opening sits at the same inset this
    // widget's box already occupies, so cell offsets come out relative
    // to the opening exactly as they should. The parent has positioned
    // the box; this only fills it.
    const geometry = PlateGeometry(1);
    final opening = geometry.openingAt(0);
    final fitting = gang.fitting;
    final scheme = Theme.of(context).colorScheme;

    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: scheme.outline),
              borderRadius: BorderRadius.circular(3),
              color: scheme.surfaceContainerHighest,
            ),
          ),
        ),
        // A PASS-THROUGH FILLS THE WHOLE OPENING, because that is what
        // the part does: no cells, no grid, one hole (DR-047 §11.46.2).
        // Hatched rather than tinted, which is the treatment this file
        // already reserves for "not a jack" and needs no new colour, so
        // PAL-1 has nothing to say about it.
        if (fitting case PassThrough(:final style))
          Positioned.fill(
            key: ValueKey('plate-passthrough-$gangIndex'),
            child: Tooltip(
              message:
                  '${passThroughLabel(style)} pass-through: cables '
                  'pass and nothing is fitted here',
              child: CustomPaint(
                painter: _CellPainter(
                  fill: scheme.surfaceContainerHigh,
                  outline: scheme.outline,
                  hatched: true,
                ),
              ),
            ),
          ),
        if (fitting case final Strap strap)
          for (var i = 0; i < strap.cellCount; i++)
            _cellAt(context, geometry, opening, strap, i),
      ],
    );
  }

  Widget _cellAt(
    BuildContext context,
    PlateGeometry geometry,
    DBox opening,
    Strap strap,
    int index,
  ) {
    final box = geometry.cellAt(0, strap, index)!;
    final occupant = strap.cells[index];
    final paint = _cellPaint(context, occupant);
    // REBASED ONTO THE OPENING. `cellAt` returns plate coordinates and
    // this widget's box IS the opening, so the opening's own inset is
    // subtracted back off. Skipping this would push every cell down and
    // right by the plate's edge margin, which is 18 x 24 mm of visible
    // wrongness rather than a subtle one.
    return Positioned(
      left: box.left - opening.left,
      top: box.top - opening.top,
      width: box.width,
      height: box.height,
      child: Tooltip(
        message: paint.tooltip,
        child: InkWell(
          // KEYED BY POSITION, so a test names the cell it means. Every
          // other tappable thing on this tab is a `ListTile`, which is
          // an `InkWell` too, and a finder that picked one by type would
          // silently start hitting the outlet list the day a plate has
          // no cells.
          key: ValueKey('plate-cell-$gangIndex-$index'),
          onTap: () => onCell(index),
          child: CustomPaint(
            painter: _CellPainter(
              fill: paint.fill,
              outline: paint.outline,
              hatched: paint.hatched,
            ),
          ),
        ),
      ),
    );
  }

  /// How one cell reads. **The colour comes from the resolver's
  /// `keystone` and from nothing else** (§11.7.5, CR-121); see the file
  /// header.
  _CellPaint _cellPaint(BuildContext context, CellOccupant? occupant) {
    final scheme = Theme.of(context).colorScheme;
    switch (occupant) {
      case null:
        // UNDECIDED. Not a blank, and drawn as the absence it is.
        return _CellPaint(
          fill: null,
          outline: scheme.outlineVariant,
          hatched: false,
          tooltip: 'Nobody has decided what goes here',
        );
      case BlankInsert():
        return _CellPaint(
          fill: scheme.surfaceContainerHigh,
          outline: scheme.outline,
          hatched: false,
          tooltip: 'Blank insert (a part on the materials list)',
        );
      case LinkEndOccupant(:final linkId):
        return _paintForLink(scheme, linkId, null);
      case ConductorOccupant(:final conductor):
        return _paintForLink(scheme, conductor.linkId, conductor.index);
    }
  }

  _CellPaint _paintForLink(ColorScheme scheme, Uuid linkId, int? conductor) {
    final link = doc.links[linkId];
    if (link == null) {
      return _CellPaint(
        fill: null,
        outline: scheme.error,
        hatched: true,
        tooltip: 'This cell names a run that is no longer in the project',
      );
    }
    final resolved = resolveJacketColor(
      link,
      doc.settings.jacketColorConventions,
    );
    final entry = resolved.keystone;
    final label = link.structureOrigin?.fieldLabel ?? link.designator;
    final post = conductor == null
        ? ''
        : '  ${_PlatePane._roleOf(link, conductor)}';

    if (entry == null) {
      // UNKNOWN, drawn as unknown. A default grey would be
      // indistinguishable from a grey somebody chose (G4).
      return _CellPaint(
        fill: null,
        outline: scheme.outline,
        hatched: true,
        tooltip: resolved.hasUnknownEntry
            ? '$label$post  ·  jacket colour names an entry that is not in '
                  'this project'
            : '$label$post  ·  no jacket colour recorded',
      );
    }
    return _CellPaint(
      fill: Color.fromARGB(
        entry.color.a,
        entry.color.r,
        entry.color.g,
        entry.color.b,
      ),
      outline: scheme.outline,
      hatched: false,
      // THE EXCEPTION IS TEXT AND THE CELL KEEPS ITS CONVENTION COLOUR.
      // A keystone is chosen weeks after the pull out of the right box.
      tooltip: resolved.isException
          ? '$label$post  ·  ${entry.abbr}  ·  PULLED '
                '${resolved.pulled?.abbr ?? "?"}'
          : '$label$post  ·  ${entry.abbr}',
    );
  }
}

@immutable
class _CellPaint {
  const _CellPaint({
    required this.fill,
    required this.outline,
    required this.hatched,
    required this.tooltip,
  });

  final Color? fill;
  final Color outline;
  final bool hatched;
  final String tooltip;
}

class _CellPainter extends CustomPainter {
  const _CellPainter({
    required this.fill,
    required this.outline,
    required this.hatched,
  });

  final Color? fill;
  final Color outline;
  final bool hatched;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(2));
    final f = fill;
    if (f != null) {
      canvas.drawRRect(rrect, Paint()..color = f);
    }
    if (hatched) {
      final pen = Paint()
        ..color = outline
        ..strokeWidth = 1;
      canvas
        ..save()
        ..clipRRect(rrect);
      for (var x = -size.height; x < size.width; x += 4) {
        canvas.drawLine(
          Offset(x, size.height),
          Offset(x + size.height, 0),
          pen,
        );
      }
      canvas.restore();
    }
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_CellPainter old) =>
      old.fill != fill || old.outline != outline || old.hatched != hatched;
}

/// The drops landing on this plate, and which of them still need a cell.
class _DropList extends StatelessWidget {
  const _DropList({
    required this.doc,
    required this.outlet,
    required this.links,
    required this.unplaced,
  });

  final RackDocument doc;
  final Outlet outlet;
  final List<Link> links;
  final List<Uuid> unplaced;

  @override
  Widget build(BuildContext context) {
    final mine = links
        .where((l) => l.structureOrigin?.outletId == outlet.id)
        .toList();
    if (mine.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Text('No drop lands on this outlet yet.'),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        Text(
          '${unplaced.length} of ${mine.length} unplaced',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 4),
        for (final link in mine) _row(context, link),
      ],
    );
  }

  Widget _row(BuildContext context, Link link) {
    final resolved = resolveJacketColor(
      link,
      doc.settings.jacketColorConventions,
    );
    final termination = link.structureOrigin?.terminationField;
    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      leading: Icon(
        unplaced.contains(link.id)
            ? Icons.radio_button_unchecked
            : Icons.check_circle_outline,
        size: 16,
      ),
      title: Text(link.structureOrigin?.fieldLabel ?? link.designator),
      subtitle: Text(
        [
          // G4's marker, and the em dash here is a VALUE rather than
          // punctuation: it is what an unknown prints as.
          if (termination == null) '—' else terminationLabel(termination),
          if (resolved.keystone != null) resolved.keystone!.abbr,
          // The exception, as text. Never as the cell's colour.
          if (resolved.isException) 'PULLED ${resolved.pulled?.abbr ?? "?"}',
        ].join(' · '),
      ),
    );
  }
}

class _NoOutlets extends StatelessWidget {
  const _NoOutlets();

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(24),
      child: Text(
        'No outlets yet. Add drops on the Table tab and they will appear '
        'here as plates.',
        textAlign: TextAlign.center,
      ),
    ),
  );
}

/// An outlet with no gangs, which is THREE different facts (DR-045
/// §11.44.4).
///
/// **THIS WIDGET SAID ONE SENTENCE FOR ALL THREE UNTIL M3-M**, and the
/// sentence was the undecided one: *"This outlet has no gangs yet. Add
/// one, or press Arrange…"*. An access point that mounts straight to its
/// box is FINISHED, and it read as unfinished work from M3-H until now.
/// That is DR-007 §11.7.4's blank-insert-versus-empty-cell distinction
/// one level up, and got wrong the same way: *nobody has said* and
/// *somebody said no plate* are different facts.
///
/// The derivation was never wrong. `PlateFill.isSettled` has returned
/// true for a plateless outlet since M3-H; only this copy threw it away.
class _NoGangs extends StatelessWidget {
  const _NoGangs({required this.fill});

  final PlateFill fill;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (String headline, String detail) = switch (fill) {
      // SETTLED, and the one the product could not say. Every drop here
      // ends in a device, so there is correctly no strap and no cover
      // plate to buy.
      final f when f.needsNoPlate => (
        'This outlet needs no plate.',
        'All ${f.dropCount} drop(s) here terminate off-plate, straight into '
            'a device, so there is no strap and no cover plate to fit.',
      ),
      // Nothing lands here at all. Not plateless: empty.
      //
      // NOT "No drop lands on this outlet yet", WHICH THE DROP LIST TO
      // THE RIGHT ALREADY SAYS. Two panels on one screen repeating a
      // sentence is the same collision the batch bar hit with the status
      // bar: a reader checks whether the two are saying different things
      // and finds they are not.
      final f when f.dropCount == 0 => (
        'Nothing to fit yet.',
        'No drop lands on this outlet, so there is no plate to size.',
      ),
      // A plate is missing, or nobody can say whether one is needed.
      // The unknown case is deliberately in THIS arm and not the first:
      // "needs no plate" over an unrecorded termination is a guess (G4).
      _ => (
        'This outlet has no gangs yet.',
        'Add one, or press Arrange to size the plate from the drops that '
            'land here.',
      ),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(headline, style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(detail, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}
