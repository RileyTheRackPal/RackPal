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
// **THE `New device template…` BUTTON IS NOT DECORATION.** The tab WAS
// the new-template entry point, so making it the browser means that entry
// point has to exist here or it is gone. DR-104 named that cost rather
// than leaving it to be found, and `Project ▸ New device template…` keeps
// working unchanged because `#251`'s stopwatch drill uses it.
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
    this.document,
    this.registries,
    this.unreadableLibraries = const [],
    this.onEdit,
    super.key,
  });

  /// What the document AND the loaded libraries hold:
  /// `buildPlaceableTemplates(doc, libraries:)` (DR-102 §11.101.3).
  final List<PlaceableTemplate> templates;

  /// The document, for the one fact that needs it: how many devices use
  /// each template (`TemplateFacts.usedInProject`). Null is legal and
  /// makes that count zero, which is honest rather than a claim.
  final RackDocument? document;

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
    return [
      for (final row in widget.templates)
        if (_admits(row)) row,
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
                          onEdit: widget.onEdit,
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
    this.onEdit,
  });

  final List<PlaceableTemplate> rows;
  final Map<String, TemplateFacts> facts;
  final bool asGrid;
  final void Function(TemplateId templateId)? onEdit;

  @override
  Widget build(BuildContext context) {
    if (!asGrid) {
      return ListView.builder(
        itemCount: rows.length,
        itemBuilder: (context, i) => _Row(
          row: rows[i],
          facts: facts[rows[i].rowKey],
          onEdit: onEdit,
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        mainAxisExtent: 132,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: rows.length,
      itemBuilder: (context, i) => _Card(
        row: rows[i],
        facts: facts[rows[i].rowKey],
        onEdit: onEdit,
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
  const _Card({required this.row, this.facts, this.onEdit});

  final PlaceableTemplate row;
  final TemplateFacts? facts;
  final void Function(TemplateId templateId)? onEdit;

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
  const _Row({required this.row, this.facts, this.onEdit});

  final PlaceableTemplate row;
  final TemplateFacts? facts;
  final void Function(TemplateId templateId)? onEdit;

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
      trailing: tag == null ? null : _Tag(text: tag),
      onTap: edit == null ? null : () => edit(row.templateId),
    );
  }
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
