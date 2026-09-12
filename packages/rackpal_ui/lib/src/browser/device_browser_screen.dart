// The device browser (`#243`, M4-O1, DR-104 §11.103.2, docs/06 §7.1).
//
// ═══════════════════════════════════════════════════════════════════════
// THIS IS WHAT THE `Device Manager` TAB WAS ALWAYS NAMED FOR
// ═══════════════════════════════════════════════════════════════════════
// That tab rendered `DeviceBuilderScreen` directly until `#243`: a
// *manager* that showed one editor and no list. Not a defect anybody
// introduced, just what the tab could be while no browser existed, and
// exactly the mismatch DR-104 §11.103.2 closes. The editor now opens FROM
// here, through [onEdit] and [onNew].
//
// **THE `New device template…` BUTTON IS NOT DECORATION, AND IT IS THE
// ONLY ROUTE.** This paragraph said the button was a rebuild of an entry
// point that also survived on a menu, *"and `Project ▸ New device
// template…` keeps working unchanged"*. **There is no `Project` menu.**
// The application has exactly one, `File`, with nine items, and no
// new-template item anywhere: `Ctrl+2` with nothing being edited was the
// whole of how a template got authored. DR-104 §11.103.2 carries the
// correction; the consequence here is that a browser whose button does
// nothing REMOVES the ability to author a device rather than failing to
// add a surface, which is why `device_browser_screen_test.dart` asserts
// the callback fires and not merely that the button renders.
//
// ═══════════════════════════════════════════════════════════════════════
// THE CARD DRAWS THE GLYPH MARK, NOT AN ELEVATION STRIP
// ═══════════════════════════════════════════════════════════════════════
// docs/06 §7.1 asks for *"the rack elevation strip as the card
// thumbnail"*. DR-104 §11.103.3 substitutes M4-R's glyph mark and records
// it as a substitution: the mark IS the device's identity on the real
// elevation since M4-R, so the card shows what the rack will show, and a
// strip would need a synthetic one-device rack and a full
// `buildRackScene` PER CARD on the one surface whose card count is
// unbounded. `DeviceGlyphMark` already existed for the builder's own
// picker, so this is a second caller rather than a painter.
//
// The RU badge carries the proportion a strip would have conveyed, as a
// number. `0U` is a real value and not a missing one (`TemplateFacts`).
//
// ═══════════════════════════════════════════════════════════════════════
// A GRID, AND THE DEFAULT IS NOT RULED
// ═══════════════════════════════════════════════════════════════════════
// docs/06 §7.1 says "grid or list" and DR-104 §11.103.6 explicitly
// declines to choose, calling it "a layout preference reversible in a
// click". Grid is the default here because the card carries a mark and a
// mark is the thing a grid is for; the toggle is one control and the
// state is this widget's.
//
// ═══════════════════════════════════════════════════════════════════════
// IT DOES NOT PLACE, AND THAT IS DELIBERATE
// ═══════════════════════════════════════════════════════════════════════
// `#186` says the browser's palette is the same widget used to insert
// devices everywhere (CR-104). That reads as a browser sitting BESIDE a
// canvas; DR-104 §11.103.2 made it a full tab instead, so placing from
// here would mean switching tabs mid-gesture and choosing a rack the user
// cannot see. No ruling grants that, so the browser finds and edits, and
// the palette places. If that turns out to be wrong, this paragraph is
// what is being overturned.
import 'package:flutter/material.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/src/draw/device_glyph_mark.dart';
import 'package:rackpal_ui/src/palette/device_palette_panel.dart'
    show
        PaletteSource,
        UnreadableLibrary,
        kAllSourceKey,
        kProjectRowTag,
        paletteSources;
import 'package:rackpal_ui/src/theme/console_theme.dart';

/// One filter the sidebar offers, and the question it asks of a row.
@immutable
final class BrowserFilter {
  const BrowserFilter({
    required this.key,
    required this.label,
    required this.test,
  });

  final String key;
  final String label;

  /// **A PREDICATE OVER FACTS, not over a body.** Every one of these was
  /// already computable (`template_facts.dart`); this list is which of
  /// them earn a chip, which DR-104 §11.103.6 left open.
  final bool Function(TemplateFacts facts) test;
}

/// docs/06 §7.1's sidebar chips, in its own order.
///
/// **RU HEIGHT AND MOUNT METHOD ARE ABSENT FROM THIS LIST**, and that is
/// the one departure from §7.1's sentence. Both are VALUE filters rather
/// than yes/no ones: a useful RU chip is `1U` / `2U` / `3U+`, and a
/// useful mount chip is one per `MountMethod`. Rendering either as a
/// single chip would ask a question with no answer ("has an RU height?"
/// is true of everything). They are worth building and they are a
/// different control, so they are named here as absent rather than
/// shipped as something that reads like a bug.
const List<BrowserFilter> kBrowserFilters = [
  BrowserFilter(key: 'hdmi', label: 'Has HDMI', test: _hasHdmi),
  BrowserFilter(key: 'poe', label: 'Has PoE', test: _hasPoe),
  BrowserFilter(
    key: 'passthrough',
    label: 'Passthrough',
    test: _isPassthrough,
  ),
  BrowserFilter(key: 'container', label: 'Container', test: _isContainer),
  BrowserFilter(key: 'used', label: 'Used here', test: _isUsed),
  BrowserFilter(key: 'draft', label: 'Drafts', test: _isDraft),
];

bool _hasHdmi(TemplateFacts f) => f.hasHdmi;
bool _hasPoe(TemplateFacts f) => f.hasPoe;
bool _isPassthrough(TemplateFacts f) => f.isPassthrough;
bool _isContainer(TemplateFacts f) => f.isContainer;
bool _isUsed(TemplateFacts f) => f.isUsedInProject;
bool _isDraft(TemplateFacts f) => f.isDraft;

/// Shown when every row has been filtered away.
const String kBrowserNoMatchesTitle = 'No devices match these filters';

/// The `New device template…` action's label, spelled once so the tab,
/// its tests and the File menu agree.
const String kBrowserNewTemplateLabel = 'New device template…';

/// docs/06 §7.1's browser: every template this project can place, with
/// the sidebar that narrows it.
class DeviceBrowserScreen extends StatefulWidget {
  const DeviceBrowserScreen({
    required this.templates,
    required this.onNew,
    this.favourites = const <String>{},
    this.onToggleFavourite,
    this.document,
    this.registries,
    this.unreadableLibraries = const [],
    this.onEdit,
    this.onRemove,
    super.key,
  });

  /// What the document AND the loaded libraries hold:
  /// `buildPlaceableTemplates(doc, libraries:)` (DR-102 §11.101.3).
  final List<PlaceableTemplate> templates;

  /// The document, for the one fact that needs it: how many devices use
  /// each template (`TemplateFacts.usedInProject`). Null is legal and
  /// makes that count zero, which is honest rather than a claim.
  final RackDocument? document;

  /// The template ids this USER has starred (DR-104 §11.103.4). Per
  /// user, never in the document, so a starred id this project does not
  /// hold is simply absent rather than a broken row.
  final Set<String> favourites;

  /// Flips a star. Null hides the control, which is what a render test
  /// that does not care about it wants.
  final void Function(String templateId)? onToggleFavourite;

  /// Widens the search only (`#244`, DR-104 §11.103.5).
  final Registries? registries;

  final List<UnreadableLibrary> unreadableLibraries;

  /// `New device template…`. **REQUIRED**, because this tab replaced the
  /// entry point that used to be here and a browser that cannot start one
  /// is a manager that can only look.
  final VoidCallback onNew;

  /// Opens the editor on an existing template (DR-099's door 2 routing,
  /// which the shell already does by template id). Null hides the action,
  /// which is what a render test that does not care about it wants.
  final void Function(TemplateId templateId)? onEdit;

  /// Removes a template from the PROJECT (`#871`, DR-158 §11.157), with
  /// the devices standing on it. Null hides the control, which is what a
  /// render test that does not care about it wants.
  ///
  /// **OFFERED ON `This project` ROWS ONLY** (§11.157.3), which is
  /// decided in `_Results` rather than here: a library row names somebody
  /// else's shelf, and a seeded row is what the build ships, so a
  /// per-project hole in it is a difference carried in the file forever
  /// and found later by somebody who did not make it.
  final void Function(TemplateId templateId)? onRemove;

  /// A stable handle for tests, per row. The card and the list row carry
  /// the SAME key, because they are one control in two layouts and a
  /// test should not have to know which is showing.
  static String removeKeyFor(String templateId) => 'browser-remove-$templateId';

  @override
  State<DeviceBrowserScreen> createState() => _DeviceBrowserScreenState();
}

class _DeviceBrowserScreenState extends State<DeviceBrowserScreen> {
  final TextEditingController _search = TextEditingController();
  String _query = '';
  String _source = kAllSourceKey;
  final Set<String> _filters = {};
  bool _asGrid = true;

  /// Facts and search keys, rebuilt only when the row list changes
  /// identity or the document moves.
  ///
  /// The same exact-staleness test the palette uses: the host hands back
  /// the same `List` instance while its memo holds, so identity beats a
  /// heuristic over lengths that would miss a rebuild producing the same
  /// number of rows.
  Map<String, TemplateFacts> _facts = const {};
  Map<String, TemplateSearchEntry> _index = const {};
  List<PlaceableTemplate>? _builtFrom;
  int? _builtAtStateId;

  void _rebuildIfStale() {
    final rows = widget.templates;
    final stateId = widget.document?.stateId;
    if (identical(_builtFrom, rows) && _builtAtStateId == stateId) return;
    _builtFrom = rows;
    _builtAtStateId = stateId;
    _facts = {
      for (final r in rows)
        r.rowKey: buildTemplateFacts(r, doc: widget.document),
    };
    _index = {
      for (final r in rows)
        r.rowKey: buildTemplateSearchEntry(r, registries: widget.registries),
    };
  }

  @override
  void initState() {
    super.initState();
    _search.addListener(() {
      if (_search.text == _query) return;
      setState(() => _query = _search.text);
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<PlaceableTemplate> get _visible {
    _rebuildIfStale();
    final kept = [
      for (final row in widget.templates)
        if (_admits(row)) row,
    ];
    // FAVOURITES PIN TO THE TOP (docs/06 §7.1). A STABLE PARTITION
    // rather than a sort: the incoming order is already total and
    // deterministic (`buildPlaceableTemplates`), and re-sorting on a
    // boolean would need a tiebreak to stay total. Two passes preserve
    // the order within each half for free.
    // **A PARTITION, NOT A LABELLED GROUP**, which is where the browser
    // and the palette differ on the same rule. docs/06 §7.1 says
    // favourites "pin to the top" of both; the palette is a list of
    // headed groups so it gets a `Favourites` heading, and this is a
    // grid of cards where a heading would mean a sectioned grid for one
    // section. The filled star is the cue, and it is on the card.
    if (widget.favourites.isEmpty) return kept;
    return [
      for (final r in kept)
        if (widget.favourites.contains(r.id)) r,
      for (final r in kept)
        if (!widget.favourites.contains(r.id)) r,
    ];
  }

  bool _admits(PlaceableTemplate row) {
    if (_source != kAllSourceKey && row.provenance.sourceKey != _source) {
      return false;
    }
    // FAILING OPEN on a missing entry, for the palette's reason: a frame
    // where the index and the rows disagree must not silently hide a
    // device. A stale match costs one frame; a lost row costs a device
    // with no way to tell.
    if (!(_index[row.rowKey]?.matches(_query) ?? true)) return false;
    final facts = _facts[row.rowKey];
    if (facts == null) return true;
    // EVERY LIT CHIP MUST HOLD, not any: chips narrow. "Has HDMI" plus
    // "Used here" means both, which is what a person ticking two boxes
    // is asking for.
    return _filters.every(
      (k) => kBrowserFilters.firstWhere((f) => f.key == k).test(facts),
    );
  }

  @override
  Widget build(BuildContext context) {
    _rebuildIfStale();
    final theme = Theme.of(context);
    final rows = _visible;
    final sources = paletteSources(
      widget.templates,
      unreadable: widget.unreadableLibraries,
    );
    return Material(
      color: theme.colorScheme.surface,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 240,
            child: _Sidebar(
              sources: sources,
              selectedSource: _source,
              onSource: (k) => setState(() => _source = k),
              filters: _filters,
              onToggleFilter: (k) => setState(() {
                if (!_filters.remove(k)) _filters.add(k);
              }),
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Toolbar(
                  controller: _search,
                  count: rows.length,
                  total: widget.templates.length,
                  asGrid: _asGrid,
                  onLayout: ({required asGrid}) =>
                      setState(() => _asGrid = asGrid),
                  onNew: widget.onNew,
                ),
                const Divider(height: 1),
                Expanded(
                  child: rows.isEmpty
                      ? _EmptyState(
                          onClear: _filters.isEmpty && _query.isEmpty
                              ? null
                              : () => setState(() {
                                  _filters.clear();
                                  _search.clear();
                                  _query = '';
                                  _source = kAllSourceKey;
                                }),
                        )
                      : _Results(
                          rows: rows,
                          facts: _facts,
                          asGrid: _asGrid,
                          favourites: widget.favourites,
                          onEdit: widget.onEdit,
                          onToggleFavourite: widget.onToggleFavourite,
                          onRemove: widget.onRemove,
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.controller,
    required this.count,
    required this.total,
    required this.asGrid,
    required this.onLayout,
    required this.onNew,
  });

  final TextEditingController controller;
  final int count;
  final int total;
  final bool asGrid;

  /// A NAMED parameter, because `avoid_positional_boolean_parameters`
  /// is right about a bare `bool` at a call site: `onLayout(true)` says
  /// nothing about what true means.
  final void Function({required bool asGrid}) onLayout;
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(8),
    child: Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            decoration: const InputDecoration(
              isDense: true,
              prefixIcon: Icon(Icons.search, size: 18),
              // THE HINT SAYS WHAT `#244` ADDED, because a search that
              // reads ports is not discoverable from a box that says
              // "Search devices".
              hintText: 'Search name, model or port type…',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // THE COUNT IS ALWAYS SHOWN, not only when filtered. "48 devices"
        // and "3 of 48" are the same control answering the same question,
        // and a count that appears only sometimes is one a person cannot
        // learn to look for.
        Text(
          count == total ? '$total devices' : '$count of $total',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(width: 12),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(
              value: true,
              icon: Icon(Icons.grid_view, size: 16),
              tooltip: 'Grid',
            ),
            ButtonSegment(
              value: false,
              icon: Icon(Icons.view_list, size: 16),
              tooltip: 'List',
            ),
          ],
          selected: {asGrid},
          showSelectedIcon: false,
          onSelectionChanged: (s) => onLayout(asGrid: s.first),
        ),
        const SizedBox(width: 12),
        FilledButton.icon(
          onPressed: onNew,
          icon: const Icon(Icons.add, size: 18),
          label: const Text(kBrowserNewTemplateLabel),
        ),
      ],
    ),
  );
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.sources,
    required this.selectedSource,
    required this.onSource,
    required this.filters,
    required this.onToggleFilter,
  });

  final List<PaletteSource> sources;
  final String selectedSource;
  final void Function(String key) onSource;
  final Set<String> filters;
  final void Function(String key) onToggleFilter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text('Source', style: theme.textTheme.labelLarge),
        const SizedBox(height: 6),
        // SINGLE-SELECT, the same rule and the same keys as the palette's
        // own chip row (DR-103 §11.102.6). Two surfaces disagreeing about
        // what `All` means would be the drift CR-104 is about.
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            for (final s in sources)
              ChoiceChip(
                label: Text(s.label, overflow: TextOverflow.ellipsis),
                selected: s.enabled && s.key == selectedSource,
                onSelected: s.enabled ? (_) => onSource(s.key) : null,
                avatar: s.enabled
                    ? null
                    : const Icon(Icons.error_outline, size: 14),
                visualDensity: VisualDensity.compact,
                labelStyle: theme.textTheme.labelSmall,
              ),
          ],
        ),
        const SizedBox(height: 20),
        Text('Filters', style: theme.textTheme.labelLarge),
        const SizedBox(height: 6),
        // MULTI-SELECT HERE, where the source row is single. They are
        // different questions: a row has exactly one source and any
        // number of properties, so "HDMI and used here" is a sentence and
        // "Catalog and Shop Kit" is not.
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            for (final f in kBrowserFilters)
              FilterChip(
                label: Text(f.label),
                selected: filters.contains(f.key),
                onSelected: (_) => onToggleFilter(f.key),
                visualDensity: VisualDensity.compact,
                labelStyle: theme.textTheme.labelSmall,
              ),
          ],
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({this.onClear});

  /// Null when nothing is narrowing, which can only happen in a project
  /// with no templates at all.
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          kBrowserNoMatchesTitle,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        if (onClear != null) ...[
          const SizedBox(height: 8),
          // A WAY OUT, not just a statement. The palette's own search
          // grew this for the same reason: a filter with no visible
          // reset is a surface a person can get stuck in.
          TextButton(onPressed: onClear, child: const Text('Clear filters')),
        ],
      ],
    ),
  );
}

class _Results extends StatelessWidget {
  const _Results({
    required this.rows,
    required this.facts,
    required this.asGrid,
    required this.favourites,
    this.onEdit,
    this.onToggleFavourite,
    this.onRemove,
  });

  final List<PlaceableTemplate> rows;
  final Map<String, TemplateFacts> facts;
  final bool asGrid;
  final Set<String> favourites;
  final void Function(TemplateId templateId)? onEdit;
  final void Function(String templateId)? onToggleFavourite;
  final void Function(TemplateId templateId)? onRemove;

  /// The remove callback for [row], or null when this row must not offer
  /// one: DR-158 §11.157.3 confines it to templates authored in THIS
  /// project. Decided once, here, so the card and the list row cannot
  /// disagree about which rows are removable.
  void Function(TemplateId)? _removeFor(PlaceableTemplate row) =>
      row.isProjectAuthored ? onRemove : null;

  @override
  Widget build(BuildContext context) {
    if (!asGrid) {
      return ListView.builder(
        itemCount: rows.length,
        itemBuilder: (context, i) => _Row(
          row: rows[i],
          facts: facts[rows[i].rowKey],
          starred: favourites.contains(rows[i].id),
          onEdit: onEdit,
          onToggleFavourite: onToggleFavourite,
          onRemove: _removeFor(rows[i]),
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        // 144 AND NOT 132, and a widget test is why. The star's
        // `IconButton` has a 28px minimum tap target, which is the
        // glyph's height plus its own padding, and the card's `Column`
        // overflowed by 2px the moment `#245` put one in the header row.
        // That renders as the yellow and black stripe and nothing but a
        // pumped test was going to catch it: the second time this
        // milestone a fixed extent has been the defect.
        mainAxisExtent: 144,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: rows.length,
      itemBuilder: (context, i) => _Card(
        row: rows[i],
        facts: facts[rows[i].rowKey],
        starred: favourites.contains(rows[i].id),
        onEdit: onEdit,
        onToggleFavourite: onToggleFavourite,
        onRemove: _removeFor(rows[i]),
      ),
    );
  }
}

/// The tag a card or row carries: which shelf it came from.
String? _tagOf(PlaceableTemplate row) => switch (row.provenance) {
  ProjectProvenance() => kProjectRowTag,
  LibraryProvenance(:final libraryName) => libraryName,
  SeededProvenance() => null,
};

/// What a card prints under the name: the RU badge, and the count when
/// this project actually uses it.
String _subtitleOf(PlaceableTemplate row, TemplateFacts? facts) {
  final ru = facts == null
      ? ''
      : (facts.ruHeight == 0 ? '0U' : '${facts.ruHeight}U');
  final used = facts == null || !facts.isUsedInProject
      ? ''
      : ' · used ${facts.usedInProject}×';
  return '$ru$used';
}

class _Card extends StatelessWidget {
  const _Card({
    required this.row,
    required this.starred,
    this.facts,
    this.onEdit,
    this.onToggleFavourite,
    this.onRemove,
  });

  final PlaceableTemplate row;
  final TemplateFacts? facts;
  final bool starred;
  final void Function(TemplateId templateId)? onEdit;
  final void Function(String templateId)? onToggleFavourite;
  final void Function(TemplateId templateId)? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tag = _tagOf(row);
    final edit = onEdit;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        // A DOUBLE-CLICK EDITS, matching the palette's double-click-to-
        // place: the primary verb of a surface is its double-click, and
        // the browser's primary verb is opening the thing.
        onDoubleTap: edit == null ? null : () => edit(row.templateId),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // DR-104 §11.103.3's substitution, drawn through the
                  // same widget the builder's glyph picker uses.
                  DeviceGlyphMark(
                    glyph: effectiveGlyph(row.body.glyph, row.body.category),
                    size: 28,
                  ),
                  const Spacer(),
                  if (tag != null) Flexible(child: _Tag(text: tag)),
                  if (onToggleFavourite != null)
                    _Star(
                      starred: starred,
                      onPressed: () => onToggleFavourite!(row.id),
                    ),
                  // REMOVE SITS BESIDE THE STAR, which is the other
                  // per-row verb, and only on a `This project` row
                  // (DR-158 §11.157.3). Drawn in the error colour: it is
                  // the one control on this surface that destroys
                  // anything.
                  if (onRemove != null)
                    _RemoveTemplateButton(
                      templateId: row.templateId,
                      onPressed: () => onRemove!(row.templateId),
                    ),
                ],
              ),
              const Spacer(),
              Text(
                row.body.displayName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 2),
              Text(
                _subtitleOf(row, facts),
                style: theme.textTheme.bodySmall,
              ),
              Text(
                row.id,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.row,
    required this.starred,
    this.facts,
    this.onEdit,
    this.onToggleFavourite,
    this.onRemove,
  });

  final PlaceableTemplate row;
  final TemplateFacts? facts;
  final bool starred;
  final void Function(TemplateId templateId)? onEdit;
  final void Function(String templateId)? onToggleFavourite;
  final void Function(TemplateId templateId)? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tag = _tagOf(row);
    final edit = onEdit;
    return ListTile(
      dense: true,
      leading: DeviceGlyphMark(
        glyph: effectiveGlyph(row.body.glyph, row.body.category),
        size: 22,
      ),
      title: Text(row.body.displayName, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${row.id} · ${_subtitleOf(row, facts)}',
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (tag != null) _Tag(text: tag),
          if (onToggleFavourite != null)
            _Star(
              starred: starred,
              onPressed: () => onToggleFavourite!(row.id),
            ),
          if (onRemove != null)
            _RemoveTemplateButton(
              templateId: row.templateId,
              onPressed: () => onRemove!(row.templateId),
            ),
        ],
      ),
      onTap: edit == null ? null : () => edit(row.templateId),
    );
  }
}

/// docs/06 §7.1's star toggle.
///
/// **THE ICON CHANGES SHAPE, NOT ONLY COLOUR** (filled versus outlined).
/// CR-078's "hue is never used alone" is PAL-1's rule for the canvas and
/// this repository's standing position everywhere else, and a star that
/// differed only in tint would fail it on a greyscale print and for a
/// person who cannot see the difference.
class _Star extends StatelessWidget {
  const _Star({required this.starred, required this.onPressed});

  final bool starred;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    icon: Icon(starred ? Icons.star : Icons.star_border, size: 16),
    // THE TOOLTIP SAYS WHAT PRESSING IT DOES, not what the state is. A
    // control labelled with its own state leaves the user to work out
    // which way the press goes.
    tooltip: starred ? 'Remove from favourites' : 'Add to favourites',
    visualDensity: VisualDensity.compact,
    padding: EdgeInsets.zero,
    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
    onPressed: onPressed,
  );
}

/// The one destructive control on this surface (`#871`, DR-158 §11.157).
///
/// **THE TOOLTIP ENDS IN AN ELLIPSIS BECAUSE IT ALWAYS ASKS.** §11.157.5
/// rules that authoring a template is work that exists nowhere else in
/// the project, so even a template nothing stands on gets a prompt. A
/// control that sometimes asks and sometimes does not is how people learn
/// to click through the prompt, including on the day it matters.
class _RemoveTemplateButton extends StatelessWidget {
  const _RemoveTemplateButton({
    required this.templateId,
    required this.onPressed,
  });

  final TemplateId templateId;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    key: ValueKey(DeviceBrowserScreen.removeKeyFor(templateId.v)),
    icon: const Icon(Icons.delete_outline, size: 16),
    // THE TOOLTIP SAYS WHICH SHELF, on `_Star`'s rule that a control says
    // what pressing it does. "Remove" alone would read as deleting the
    // template everywhere, and there is no everywhere yet: the shelf is
    // M4-N and this acts on the project's own embedded copy.
    tooltip: 'Remove from this project…',
    visualDensity: VisualDensity.compact,
    padding: EdgeInsets.zero,
    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
    color: Theme.of(context).colorScheme.error,
    onPressed: onPressed,
  );
}

/// The provenance tag, spelled the way the palette's subtitle spells it
/// so the two surfaces do not drift into two badge styles.
class _Tag extends StatelessWidget {
  const _Tag({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        text,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 9,
          height: 1.2,
          letterSpacing: 0.4,
          fontWeight: kConsoleEmphasis,
          color: theme.colorScheme.onTertiaryContainer,
        ),
      ),
    );
  }
}
