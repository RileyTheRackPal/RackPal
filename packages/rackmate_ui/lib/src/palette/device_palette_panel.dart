// The device palette (docs/04-rack-editor.md §1's palette panel spec:
// "PALETTE 280px ... search ... categories"). Lists the seeded catalog
// (docs/09-roadmap.md M1 checklist #6) grouped by category with a search
// box that flattens to a filtered list across every category, matching
// §1's mockup ("⌕ /" search field over "▾ Recent / ▾ Amplif." category
// groups).
//
// TWO PLACEMENT GESTURES now originate here:
//  * CLICK-TO-ADD (double-click a row, or press Enter with a row
//    focused) — inserts at the insertion caret when one exists, else the
//    lowest fitting free U (docs/04 §3.2's "faster paths").
//  * DRAG-TO-RAILS (docs/04 §3.1, added this stage) — [onArmDrag] fires on
//    a plain pointer-down (any button/touch/stylus, no `PointerDeviceKind`
//    branch, AC-016 #23) from an ADDITIONAL `Listener` wrapped AROUND each
//    row's existing double-tap/Enter subtree. `Listener` never enters the
//    gesture arena, so it cannot interfere with double-tap detection —
//    both see the same raw down event independently, exactly like
//    `CanvasIntentDetector`'s own `Listener` already coexists with its
//    children (canvas_intent.dart). `RackCanvasScreen` owns everything
//    past this pointer-down: it tracks the rest of the gesture via a
//    GLOBAL `GestureBinding.instance.pointerRouter` route, not through
//    this widget's own tree — see that file's header for the full
//    mechanism (Draggable/DragTarget are off-limits, docs/04 §3's hard
//    constraint).
//
// The palette does not own placement geometry or the document — it only
// reports WHICH template id was activated (via [onPlace]) or armed for a
// drag (via [onArmDrag]); the caller (the rack editor screen, which holds
// the `DocumentController`) decides where and how to place it
// (`rackmate_core`'s `buildPlaceFromCatalogCommand`).
//
// ═════════════════════════════════════════════════════════════════════
// IT LISTS WHAT THE DOCUMENT CAN PLACE, NOT WHAT THE BUILD SHIPS
// ═════════════════════════════════════════════════════════════════════
// This took `Map<String, TemplateBody>` from `buildSeedCatalog()` until
// M4-S, and the consequence was that a template authored in the Device
// Builder saved into the project and appeared nowhere: M4's exit criterion
// clause 2 could not be performed at all (docs/12 §5.3.8). It now takes
// `buildPlaceableTemplates(doc)`, which is the document's own shelf with
// the newest version of each id and where each came from (DR-077
// §11.76.1).
//
// THREE GROUPING RULES, and the third is the one that was a silent hole:
//
//  * an authored template is filed into its own CATEGORY beside the
//    seeded ones, carrying a badge;
//  * it is ALSO repeated in a `This project` group pinned above the nine
//    categories, because the category is where a person looks for a
//    network switch and the pinned group is where a person looks for the
//    thing they saved thirty seconds ago (DR-077 §11.76.2);
//  * a template whose category is not one of the nine — INCLUDING the
//    empty string, which `_canSave` permits — lands in a trailing
//    `Uncategorised` group. Iterating `categoryOrder` alone made such a
//    template invisible: not refused, not badged, simply absent.
//
// THE PINNED GROUP IS BROWSE-STATE ONLY. A non-empty query flattens this
// panel to one filtered list across every category, and a row appearing
// twice there makes the match count wrong and `Enter`-on-the-top-match
// ambiguous. Searching shows each template once, badged.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show KeyDownEvent, LogicalKeyboardKey;
import 'package:rackmate_core/rackmate_core.dart';
import 'package:rackmate_ui/src/theme/console_theme.dart';

/// The pinned group's heading. A constant so the panel, its tests and
/// DR-077 §11.76.2 spell it once.
const String kProjectGroupTitle = 'This project';

/// What an authored row's badge reads. Deliberately the same word as
/// [kProjectGroupTitle]'s first, so a reader who sees the tag and then
/// looks for the group finds the group.
const String kProjectRowTag = 'PROJECT';

/// The trailing group's heading, for a template whose category is not one
/// of [kCatalogCategoryOrder]'s nine — the empty string included.
const String kUncategorisedGroupTitle = 'Uncategorised';

/// One category's rows, in the order they arrived.
///
/// **The caller's order is preserved rather than re-sorted here.**
/// `buildPlaceableTemplates` returns a total order by template id, which
/// is already the display order the palette wants (`V01`, `V02`, … then
/// `F01`, `F02`, …), and a second sort in the widget would be a second
/// place the row order is decided.
List<PlaceableTemplate> _inCategory(
  List<PlaceableTemplate> templates,
  String category,
) => [
  for (final t in templates)
    if (t.body.category == category) t,
];

/// Every template whose category is none of [categoryOrder]'s.
List<PlaceableTemplate> _uncategorised(
  List<PlaceableTemplate> templates,
  List<String> categoryOrder,
) => [
  for (final t in templates)
    if (!categoryOrder.contains(t.body.category)) t,
];

/// Every template authored in this project rather than shipped.
List<PlaceableTemplate> _projectAuthored(List<PlaceableTemplate> templates) => [
  for (final t in templates)
    if (t.isProjectAuthored) t,
];

bool _matchesQuery(String query, PlaceableTemplate template) {
  if (query.isEmpty) return true;
  final q = query.toLowerCase();
  final body = template.body;
  return template.id.toLowerCase().contains(q) ||
      body.displayName.toLowerCase().contains(q) ||
      (body.typePrefix ?? '').toLowerCase().contains(q) ||
      body.category.toLowerCase().contains(q) ||
      body.tags.any((t) => t.toLowerCase().contains(q));
}

/// The first two characters of a type prefix, for the leading avatar.
String _initials(String prefix) =>
    prefix.length <= 2 ? prefix : prefix.substring(0, 2);

/// A short occupancy badge for the trailing chip — "3U", "0U" (0U-vertical
/// PDU), or "Field" for a `notInRack` device, which has no RU badge at all.
String _occupancyBadge(TemplateBody body) {
  if (body.mountMethod == MountMethod.notInRack) return 'Field';
  if (body.side == OccupancySide.zeroUVertical) return '0U';
  final h = body.frontU > 0 ? body.frontU : body.rearU;
  return '${h}U';
}

/// The rack/schematic palette (docs/04 §1: "one palette widget, shared
/// with the Schematic's library panel", CR-104 — this stage builds the
/// rack half only; the schematic library panel is M2's job).
class DevicePalettePanel extends StatefulWidget {
  const DevicePalettePanel({
    required this.templates,
    required this.categoryOrder,
    required this.onPlace,
    this.searchFocusNode,
    this.searchController,
    this.onDismissSearch,
    this.onRefuse,
    this.onArmDrag,
    this.draggingCatalogId,
    super.key,
  });

  /// What the DOCUMENT can place: `buildPlaceableTemplates(doc)`, newest
  /// version of each id, each carrying where it came from.
  ///
  /// Was the seeded catalog until M4-S. See this file's header for why
  /// that made a milestone's exit criterion unperformable.
  final List<PlaceableTemplate> templates;

  /// Category display order (`kCatalogCategoryOrder`).
  final List<String> categoryOrder;

  /// Fired when a row is activated (double-click or Enter) with its
  /// template id — the caller places it into the running rack.
  final void Function(String templateId) onPlace;

  /// Optional externally-owned focus node so the screen can bind `/` to
  /// focus the search field (docs/04 §3.2, §8 keymap).
  final FocusNode? searchFocusNode;

  /// Optional externally-owned text controller, for the same reason as
  /// [searchFocusNode]: the screen has keyboard obligations toward this
  /// field — `/` selects the existing query so the next keystroke replaces
  /// it — that cannot be met without reaching its contents.
  final TextEditingController? searchController;

  /// `Esc` in the search field. Null disables the binding, which is what a
  /// standalone render test wants; `RackCanvasScreen` wires it to "clear the
  /// query and give the keyboard back to the canvas".
  final VoidCallback? onDismissSearch;

  /// Announces a refusal on the host's status line. Used when `Enter` in the
  /// search box matches nothing.
  final void Function(String message)? onRefuse;

  /// Fired on a plain pointer-down anywhere on a row (docs/04 §3.1 step 1:
  /// "Arm — pointer down on a palette row"). Null (the default) means
  /// drag-from-palette is disabled for this host — every render test that
  /// doesn't care about it need not supply one.
  final void Function(String templateId, PointerDownEvent event)? onArmDrag;

  /// The template id currently LIFTED (docs/04 §3.1 step 2 — past the 4px
  /// slop, not merely armed) by an in-flight palette drag, or null. That
  /// one row dims to 40% opacity and gets a 1px accent inset outline; the
  /// caller (`RackCanvasScreen`) is the sole owner of this value, pushed
  /// down the same way `RackCanvasScreen` pushes `selected` into
  /// `DeviceBox` — this widget never tracks its own drag state.
  final String? draggingCatalogId;

  @override
  State<DevicePalettePanel> createState() => _DevicePalettePanelState();
}

class _DevicePalettePanelState extends State<DevicePalettePanel> {
  late final TextEditingController _searchController =
      widget.searchController ?? TextEditingController();
  late final FocusNode _searchFocusNode =
      widget.searchFocusNode ?? FocusNode(debugLabel: 'paletteSearch');
  String _query = '';

  @override
  void initState() {
    super.initState();
    // The controller may be the SCREEN'S, and the screen writes to it —
    // `/` select-all, `Esc` clear. `onChanged` only fires for edits made
    // through the field itself, so without this listener an external clear
    // would empty the box while the list below kept showing the old
    // filtered results.
    _searchController.addListener(_onControllerChanged);
    _query = _searchController.text;
  }

  void _onControllerChanged() {
    if (_searchController.text == _query) return;
    setState(() => _query = _searchController.text);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onControllerChanged);
    if (widget.searchController == null) _searchController.dispose();
    if (widget.searchFocusNode == null) _searchFocusNode.dispose();
    super.dispose();
  }

  /// `Enter` in the search box (docs/04 §3.2's "type, press Enter -> the top
  /// match places").
  ///
  /// A ZERO-MATCH SUBMIT IS ANNOUNCED, NOT SWALLOWED. This used to
  /// `return` silently, so typing a template that does not exist and
  /// pressing Enter was indistinguishable from the app being frozen — and
  /// during the window where the filter could not be corrected, that was
  /// the user's last signal before the palette became unusable. The rest of
  /// this file family treats "a refused action always says why" as a
  /// standing rule; this was the one path that did not.
  void _submitQuery(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return; // "type, THEN Enter" — nothing typed yet.
    final matches = [
      for (final t in widget.templates)
        if (_matchesQuery(query, t)) t,
    ];
    if (matches.isEmpty) {
      widget.onRefuse?.call('No device matches "$trimmed".');
      return;
    }
    widget.onPlace(matches.first.id);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final searching = _query.trim().isNotEmpty;

    // `Material`, not a bare `ColoredBox`: `ListTile`'s ink/background paint
    // on the nearest `Material` ancestor, and an opaque `ColoredBox` sitting
    // between it and that ancestor would silently hide both.
    return Material(
      color: scheme.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            // ESCAPE IS HANDLED HERE, AT THE FIELD, on purpose. The screen's
            // `Esc` binding is deliberately gated OFF while a text field has
            // focus, so that pressing it mid-word cannot clear the canvas
            // selection out from under someone who is typing. Having taken
            // the key away from the canvas in this context, the field owes
            // the user something for it — and "empty the filter, hand the
            // keyboard back" is the keyboard-only way out of a bad query.
            //
            // This is field-LOCAL behaviour, not a swallower: it claims
            // exactly one key and returns `ignored` for everything else, so
            // it cannot become the next thing that eats `Backspace`.
            child: Focus(
              onKeyEvent: (node, event) {
                if (event is! KeyDownEvent) return KeyEventResult.ignored;
                if (event.logicalKey != LogicalKeyboardKey.escape) {
                  return KeyEventResult.ignored;
                }
                final dismiss = widget.onDismissSearch;
                if (dismiss == null) return KeyEventResult.ignored;
                dismiss();
                return KeyEventResult.handled;
              },
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                decoration: InputDecoration(
                  isDense: true,
                  prefixIcon: const Icon(Icons.search, size: 18),
                  hintText: 'Search devices…',
                  border: const OutlineInputBorder(),
                  // THE MOUSE ESCAPE HATCH. Without it, a mistyped filter
                  // was recoverable only from the keyboard — which is
                  // precisely what was broken. Two independent ways out of
                  // the same hole, so a regression in one does not strand
                  // the palette again.
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          tooltip: 'Clear search',
                          onPressed:
                              widget.onDismissSearch ?? _searchController.clear,
                        ),
                ),
                onChanged: (v) => setState(() => _query = v),
                // docs/04 §3.2: "Type, press Enter -> the top match ...
                // places". "Top match" reads as "the first row in the
                // current filtered list" (no fuzzy-match ranking is in
                // scope) — the SAME filter+sort `_SearchResults` below
                // already uses, so the row that's on screen when Enter is
                // pressed is exactly the row this places.
                onSubmitted: _submitQuery,
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: searching
                ? _SearchResults(
                    templates: widget.templates,
                    query: _query,
                    onPlace: widget.onPlace,
                    onArmDrag: widget.onArmDrag,
                    draggingCatalogId: widget.draggingCatalogId,
                  )
                : _CategoryList(
                    templates: widget.templates,
                    categoryOrder: widget.categoryOrder,
                    onPlace: widget.onPlace,
                    onArmDrag: widget.onArmDrag,
                    draggingCatalogId: widget.draggingCatalogId,
                  ),
          ),
        ],
      ),
    );
  }
}

class _CategoryList extends StatelessWidget {
  const _CategoryList({
    required this.templates,
    required this.categoryOrder,
    required this.onPlace,
    this.onArmDrag,
    this.draggingCatalogId,
  });

  final List<PlaceableTemplate> templates;
  final List<String> categoryOrder;
  final void Function(String templateId) onPlace;
  final void Function(String templateId, PointerDownEvent event)? onArmDrag;
  final String? draggingCatalogId;

  @override
  Widget build(BuildContext context) {
    final authored = _projectAuthored(templates);
    final homeless = _uncategorised(templates, categoryOrder);
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // PINNED FIRST, and only when it would hold something: an empty
        // `This project` group on a fresh file would be a heading that
        // teaches the reader the feature is broken (DR-077 §11.76.2).
        if (authored.isNotEmpty)
          _PaletteGroup(
            title: kProjectGroupTitle,
            rows: authored,
            onPlace: onPlace,
            onArmDrag: onArmDrag,
            draggingCatalogId: draggingCatalogId,
          ),
        for (final category in categoryOrder)
          if (_inCategory(templates, category).isNotEmpty)
            _PaletteGroup(
              title: category,
              rows: _inCategory(templates, category),
              onPlace: onPlace,
              onArmDrag: onArmDrag,
              draggingCatalogId: draggingCatalogId,
            ),
        // LAST, because it is the group nobody filed into deliberately.
        if (homeless.isNotEmpty)
          _PaletteGroup(
            title: kUncategorisedGroupTitle,
            rows: homeless,
            onPlace: onPlace,
            onArmDrag: onArmDrag,
            draggingCatalogId: draggingCatalogId,
          ),
      ],
    );
  }
}

/// One collapsible band of rows. Extracted when the browse state grew
/// from one kind of group to three: three copies of an `ExpansionTile`
/// argument list is three places a padding or a key convention drifts.
class _PaletteGroup extends StatelessWidget {
  const _PaletteGroup({
    required this.title,
    required this.rows,
    required this.onPlace,
    this.onArmDrag,
    this.draggingCatalogId,
  });

  final String title;
  final List<PlaceableTemplate> rows;
  final void Function(String templateId) onPlace;
  final void Function(String templateId, PointerDownEvent event)? onArmDrag;
  final String? draggingCatalogId;

  @override
  Widget build(BuildContext context) => ExpansionTile(
    key: PageStorageKey<String>(title),
    title: Text(title, style: Theme.of(context).textTheme.labelLarge),
    initiallyExpanded: true,
    maintainState: true,
    children: [
      for (final template in rows)
        _PaletteRow(
          template: template,
          onPlace: onPlace,
          onArmDrag: onArmDrag,
          dragging: template.id == draggingCatalogId,
        ),
    ],
  );
}

/// ONE ROW PER TEMPLATE, badged. The browse state repeats an authored
/// template in its pinned group; a search must not, because the match
/// count and `Enter`-on-the-top-match are both statements about a list
/// with no duplicates in it (DR-077 §11.76.2).
class _SearchResults extends StatelessWidget {
  const _SearchResults({
    required this.templates,
    required this.query,
    required this.onPlace,
    this.onArmDrag,
    this.draggingCatalogId,
  });

  final List<PlaceableTemplate> templates;
  final String query;
  final void Function(String templateId) onPlace;
  final void Function(String templateId, PointerDownEvent event)? onArmDrag;
  final String? draggingCatalogId;

  @override
  Widget build(BuildContext context) {
    final matches = [
      for (final t in templates)
        if (_matchesQuery(query, t)) t,
    ];

    if (matches.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'No devices match "$query"',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        for (final template in matches)
          _PaletteRow(
            template: template,
            onPlace: onPlace,
            onArmDrag: onArmDrag,
            dragging: template.id == draggingCatalogId,
          ),
      ],
    );
  }
}

/// One palette row. `docs/04 §3.1` step 1 — "pointer down… nothing until
/// 4 px of movement, so a click still means 'show details'" — has no
/// details pane in this stage, so a single click is a no-op selection
/// affordance only; double-click (or `Enter` once focused) places, and a
/// pointer-down that crosses 4px of movement arms/lifts a drag-to-rails
/// gesture instead (docs/04 §3.1, [onArmDrag]).
class _PaletteRow extends StatelessWidget {
  const _PaletteRow({
    required this.template,
    required this.onPlace,
    this.onArmDrag,
    this.dragging = false,
  });

  final PlaceableTemplate template;
  final void Function(String templateId) onPlace;
  final void Function(String templateId, PointerDownEvent event)? onArmDrag;

  /// Whether THIS row is the one currently lifted by an in-flight palette
  /// drag (docs/04 §3.1 step 2) — dims to 40% opacity with a 1px accent
  /// inset outline.
  final bool dragging;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final body = template.body;
    final id = template.id;
    final authored = template.isProjectAuthored;
    final row = Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.numpadEnter)) {
          onPlace(id);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onDoubleTap: () => onPlace(id),
        child: Semantics(
          // THE BADGE IS IN THE LABEL AND NOT ONLY IN THE PIXELS. A
          // provenance marker a screen reader cannot reach is a marker
          // for some readers, and docs/05 §12.1's argument for a real
          // widget table applies to every affordance this package draws.
          label: authored
              ? '${body.displayName}, $id, authored in this project, '
                    'double-tap to place in the rack'
              : '${body.displayName}, $id, double-tap to place in '
                    'the rack',
          child: ListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            leading: CircleAvatar(
              radius: 14,
              // A DIFFERENT CONTAINER ROLE, not a different hue picked by
              // hand: PAL-1 (canon §14) owns colour meaning on the canvas
              // and the theme owns it here, so an authored row reads as
              // "another kind of thing" in both light and dark without
              // this file naming a colour.
              backgroundColor: authored
                  ? scheme.tertiaryContainer
                  : scheme.secondaryContainer,
              child: Text(
                _initials(body.typePrefix ?? id),
                style: TextStyle(
                  fontSize: 10,
                  color: authored
                      ? scheme.onTertiaryContainer
                      : scheme.onSecondaryContainer,
                  fontWeight: kConsoleEmphasis,
                ),
              ),
            ),
            title: Text(body.displayName, overflow: TextOverflow.ellipsis),
            subtitle: authored
                ? _ProvenanceSubtitle(id: id)
                : Text(id, style: Theme.of(context).textTheme.bodySmall),
            trailing: Chip(
              label: Text(_occupancyBadge(body)),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ),
      ),
    );

    // docs/04 §3.1 step 2: the source row "drops to 40% opacity in place"
    // with "a 1px accent inset outline" once LIFTED (not merely armed).
    final decorated = dragging
        ? Opacity(
            opacity: 0.40,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: scheme.tertiary),
              ),
              child: row,
            ),
          )
        : row;

    final armDrag = onArmDrag;
    if (armDrag == null) return decorated;

    // The ADDITIONAL outer `Listener` (docs/04 §3.1's arm mechanism — see
    // this file's header). `Listener` never enters the gesture arena, so
    // it cannot interfere with `GestureDetector.onDoubleTap`/`Focus`'s own
    // Enter handling above — both see the same raw pointer-down
    // independently. Any primary button/touch/stylus contact arms a
    // POTENTIAL drag (no `PointerDeviceKind` branch, AC-016 #23); whether
    // it ever crosses the 4px lift threshold is `RackCanvasScreen`'s call,
    // not this widget's.
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (event) => armDrag(id, event),
      child: decorated,
    );
  }
}

/// The subtitle of an authored row: the template id, and a tag saying
/// where it came from.
///
/// A TAG RATHER THAN A SECOND `Chip`. The trailing chip is the occupancy
/// badge and the panel is 280 px (docs/04 §1), so a second chip on the
/// same line costs the display name its width on exactly the rows whose
/// names are longest, because a user types a longer name than `24p sw`.
class _ProvenanceSubtitle extends StatelessWidget {
  const _ProvenanceSubtitle({required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Flexible(
          child: Text(
            id,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            color: theme.colorScheme.tertiaryContainer,
            borderRadius: BorderRadius.circular(3),
          ),
          child: Text(
            kProjectRowTag,
            style: TextStyle(
              fontSize: 9,
              height: 1.2,
              letterSpacing: 0.4,
              fontWeight: kConsoleEmphasis,
              color: theme.colorScheme.onTertiaryContainer,
            ),
          ),
        ),
      ],
    );
  }
}
