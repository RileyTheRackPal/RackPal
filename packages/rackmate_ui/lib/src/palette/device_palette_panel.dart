// The device palette (docs/04-rack-editor.md §1's palette panel spec:
// "PALETTE 280px ... search ... categories"). Lists the seeded catalog
// (docs/09-roadmap.md M1 checklist #6) grouped by category with a search
// box that flattens to a filtered list across every category, matching
// §1's mockup ("⌕ /" search field over "▾ Recent / ▾ Amplif." category
// groups).
//
// PLACEMENT GESTURE, stated honestly (this stage's task brief): this is
// CLICK-TO-ADD, not docs/04 §3.1's full drag-from-palette-to-rails gesture
// (arm/lift/enter-canvas/snap/evaluate/commit with live blocked-drop
// feedback) — that gesture is a stretch goal explicitly deferred here.
// Double-click a row (or press Enter with a row focused) inserts it at the
// lowest fitting free U, which is docs/04 §3.2's "faster paths" behaviour
// ("Double-click a palette row — identical to Enter").
//
// The palette does not own placement geometry or the document — it only
// reports WHICH catalog id was activated via [onPlace]; the caller (the
// rack editor screen, which holds the `DocumentController`) decides where
// and how to place it (`rackmate_core`'s `buildPlaceFromCatalogCommand`).

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
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: searching
                ? _SearchResults(
                    catalog: widget.catalog,
                    query: _query,
                    onPlace: widget.onPlace,
                  )
                : _CategoryList(
                    catalog: widget.catalog,
                    categoryOrder: widget.categoryOrder,
                    onPlace: widget.onPlace,
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
  });

  final Map<String, TemplateBody> catalog;
  final List<String> categoryOrder;
  final void Function(String catalogId) onPlace;

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
  });

  final Map<String, TemplateBody> catalog;
  final String query;
  final void Function(String catalogId) onPlace;

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
          _PaletteRow(catalogId: entry.key, body: entry.value, onPlace: onPlace),
      ],
    );
  }
}

/// One palette row. `docs/04 §3.1` step 1 — "pointer down… nothing until
/// 4 px of movement, so a click still means 'show details'" — has no
/// details pane in this stage, so a single click is a no-op selection
/// affordance only; double-click (or `Enter` once focused) places.
class _PaletteRow extends StatelessWidget {
  const _PaletteRow({
    required this.catalogId,
    required this.body,
    required this.onPlace,
  });

  final String catalogId;
  final TemplateBody body;
  final void Function(String catalogId) onPlace;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Focus(
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
  }
}
