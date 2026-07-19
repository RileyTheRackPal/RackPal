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
// reports WHICH catalog id was activated (via [onPlace]) or armed for a
// drag (via [onArmDrag]); the caller (the rack editor screen, which holds
// the `DocumentController`) decides where and how to place it
// (`rackmate_core`'s `buildPlaceFromCatalogCommand`).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show KeyDownEvent, LogicalKeyboardKey;
import 'package:rackmate_core/rackmate_core.dart';

/// One category's rows are sorted by catalog id, which is already a
/// sensible display order (`V01`, `V02`, … then `F01`, `F02`, …).
List<MapEntry<String, TemplateBody>> _sortedEntries(
  Map<String, TemplateBody> catalog,
  String category,
) {
  final entries = catalog.entries
      .where((e) => e.value.category == category)
      .toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  return entries;
}

bool _matchesQuery(String query, String id, TemplateBody body) {
  if (query.isEmpty) return true;
  final q = query.toLowerCase();
  return id.toLowerCase().contains(q) ||
      body.displayName.toLowerCase().contains(q) ||
      (body.typePrefix ?? '').toLowerCase().contains(q) ||
      body.category.toLowerCase().contains(q) ||
      body.tags.any((t) => t.toLowerCase().contains(q));
}

/// The first two characters of a type prefix, for the leading avatar.
String _initials(String prefix) => prefix.length <= 2 ? prefix : prefix.substring(0, 2);

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
    required this.catalog,
    required this.categoryOrder,
    required this.onPlace,
    this.searchFocusNode,
    this.onArmDrag,
    this.draggingCatalogId,
    super.key,
  });

  /// The seeded catalog, keyed by catalog id (`buildSeedCatalog()`).
  final Map<String, TemplateBody> catalog;

  /// Category display order (`kCatalogCategoryOrder`).
  final List<String> categoryOrder;

  /// Fired when a row is activated (double-click or Enter) with its
  /// catalog id — the caller places it into the running rack.
  final void Function(String catalogId) onPlace;

  /// Optional externally-owned focus node so the screen can bind `/` to
  /// focus the search field (docs/04 §3.2, §8 keymap).
  final FocusNode? searchFocusNode;

  /// Fired on a plain pointer-down anywhere on a row (docs/04 §3.1 step 1:
  /// "Arm — pointer down on a palette row"). Null (the default) means
  /// drag-from-palette is disabled for this host — every render test that
  /// doesn't care about it need not supply one.
  final void Function(String catalogId, PointerDownEvent event)? onArmDrag;

  /// The catalog id currently LIFTED (docs/04 §3.1 step 2 — past the 4px
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
  final _searchController = TextEditingController();
  late final FocusNode _searchFocusNode =
      widget.searchFocusNode ?? FocusNode(debugLabel: 'paletteSearch');
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    if (widget.searchFocusNode == null) _searchFocusNode.dispose();
    super.dispose();
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
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              decoration: const InputDecoration(
                isDense: true,
                prefixIcon: Icon(Icons.search, size: 18),
                hintText: 'Search devices…',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _query = v),
              // docs/04 §3.2: "Type, press Enter -> the top match ...
              // places". "Top match" reads as "the first row in the
              // current filtered list" (no fuzzy-match ranking is in
              // scope) — the SAME filter+sort `_SearchResults` below
              // already uses, so the row that's on screen when Enter is
              // pressed is exactly the row this places.
              onSubmitted: (query) {
                if (query.trim().isEmpty) return; // "type, then Enter"
                final matches = widget.catalog.entries
                    .where((e) => _matchesQuery(query, e.key, e.value))
                    .toList()
                  ..sort((a, b) => a.key.compareTo(b.key));
                if (matches.isNotEmpty) widget.onPlace(matches.first.key);
              },
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: searching
                ? _SearchResults(
                    catalog: widget.catalog,
                    query: _query,
                    onPlace: widget.onPlace,
                    onArmDrag: widget.onArmDrag,
                    draggingCatalogId: widget.draggingCatalogId,
                  )
                : _CategoryList(
                    catalog: widget.catalog,
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
    required this.catalog,
    required this.categoryOrder,
    required this.onPlace,
    this.onArmDrag,
    this.draggingCatalogId,
  });

  final Map<String, TemplateBody> catalog;
  final List<String> categoryOrder;
  final void Function(String catalogId) onPlace;
  final void Function(String catalogId, PointerDownEvent event)? onArmDrag;
  final String? draggingCatalogId;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        for (final category in categoryOrder)
          if (_sortedEntries(catalog, category).isNotEmpty)
            ExpansionTile(
              key: PageStorageKey<String>(category),
              title: Text(
                category,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              initiallyExpanded: true,
              maintainState: true,
              children: [
                for (final entry in _sortedEntries(catalog, category))
                  _PaletteRow(
                    catalogId: entry.key,
                    body: entry.value,
                    onPlace: onPlace,
                    onArmDrag: onArmDrag,
                    dragging: entry.key == draggingCatalogId,
                  ),
              ],
            ),
      ],
    );
  }
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({
    required this.catalog,
    required this.query,
    required this.onPlace,
    this.onArmDrag,
    this.draggingCatalogId,
  });

  final Map<String, TemplateBody> catalog;
  final String query;
  final void Function(String catalogId) onPlace;
  final void Function(String catalogId, PointerDownEvent event)? onArmDrag;
  final String? draggingCatalogId;

  @override
  Widget build(BuildContext context) {
    final matches = catalog.entries
        .where((e) => _matchesQuery(query, e.key, e.value))
        .toList()
      ..sort((a, b) => a.key.compareTo(b.key));

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
        for (final entry in matches)
          _PaletteRow(
            catalogId: entry.key,
            body: entry.value,
            onPlace: onPlace,
            onArmDrag: onArmDrag,
            dragging: entry.key == draggingCatalogId,
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
    required this.catalogId,
    required this.body,
    required this.onPlace,
    this.onArmDrag,
    this.dragging = false,
  });

  final String catalogId;
  final TemplateBody body;
  final void Function(String catalogId) onPlace;
  final void Function(String catalogId, PointerDownEvent event)? onArmDrag;

  /// Whether THIS row is the one currently lifted by an in-flight palette
  /// drag (docs/04 §3.1 step 2) — dims to 40% opacity with a 1px accent
  /// inset outline.
  final bool dragging;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final row = Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.numpadEnter)) {
          onPlace(catalogId);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onDoubleTap: () => onPlace(catalogId),
        child: Semantics(
          label: '${body.displayName}, $catalogId, double-tap to place in '
              'the rack',
          child: ListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            leading: CircleAvatar(
              radius: 14,
              backgroundColor: scheme.secondaryContainer,
              child: Text(
                _initials(body.typePrefix ?? catalogId),
                style: TextStyle(
                  fontSize: 10,
                  color: scheme.onSecondaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            title: Text(body.displayName, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              catalogId,
              style: Theme.of(context).textTheme.bodySmall,
            ),
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
      onPointerDown: (event) => armDrag(catalogId, event),
      child: decorated,
    );
  }
}
