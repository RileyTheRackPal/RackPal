// packages/rackmate_ui/lib/src/schedule/schedule_screen.dart
//
// docs/05-schematic-editor.md §12: "the Schedule is a top-level tab,
// present and populating live from an empty project (Ctrl+4, CR-105,
// AC-035)". This is that tab.
//
// ═════════════════════════════════════════════════════════════════════
// IT RENDERS A DERIVATION. IT DOES NOT CONTAIN ONE.
// ═════════════════════════════════════════════════════════════════════
// Every row, every band, every subtotal and every count comes from
// `rackmate_core`'s `derived/schedule.dart`, which is pure Dart so the
// PDF exporter drives the identical query (`rackmate_export` may never
// import `rackmate_ui`). Nothing in this file decides what a rack label
// is, which rows a preset shows or how a footage subtotal is computed —
// and that is the whole point of docs/08 §3.1's "two presets of one
// derivation". A screen that computed its own rows would be the second
// table builder that ruling exists to forbid.
//
// This file therefore owns exactly three things: which preset is showing,
// whether AC-026's jumper toggle is on, and which §3.6 sort is selected.
// All three are VIEW state — nothing here mutates the document.
//
// ═════════════════════════════════════════════════════════════════════
// WHY IT IS WIDGETS AND NOT A CANVAS
// ═════════════════════════════════════════════════════════════════════
// docs/05 §12.1: "a real Flutter data table, not canvas-painted — which
// makes it screen-reader navigable for free, and an accessible wiring
// schedule is better accessibility than any amount of heroic
// `CustomPainterSemantics` on the canvas". Every cell below is a `Text`,
// so it is selectable, findable and readable by a screen reader without
// a semantics layer written by hand.
//
// ═════════════════════════════════════════════════════════════════════
// ZERO ROWS IS A STATE THIS TAB IS CORRECT IN, NOT A STATE IT AVOIDS
// ═════════════════════════════════════════════════════════════════════
// CR-105 asks for a tab "populating live from an EMPTY project", which is
// a requirement on the empty case, not a promise about the full one. So
// the column headers render before any data exists — that is what makes
// an empty schedule readable rather than blank — and beneath them the
// panel states the two facts that are actually true of an empty document
// (see [kNoCablesHeadline] and [kNoCablesDetail]).
//
// WHAT IT MAY NOT SAY. The predecessor of this screen showed
// "No connections yet · Create links in the Schematic tab", which pointed
// the user at a tab that cannot create a link. docs/09 M1 calls an empty
// Schedule tab that explains it is coming "a lie". The copy below states
// an absence and names where the absence is, and
// `schedule_screen_test.dart` holds the line on both.

import 'package:flutter/material.dart';
import 'package:rackmate_core/rackmate_core.dart';

/// The first line of the no-cables state.
///
/// A statement about THIS DOCUMENT ("holds no cables"), never about the
/// user ("you have not wired anything") — the second is false whenever
/// the build offers no way to wire anything, which is the case docs/09 M1
/// singles out.
const String kNoCablesHeadline = 'This document holds no cables.';

/// The second line: why the table is empty and where the gap is.
///
/// It is checked against the code it describes —
/// `apps/rackmate/test/unbuilt_copy_accuracy_test.dart` scans both UI
/// packages and the app for a caller of `AddLinkCommand` and fails if one
/// appears, which is what lets this sentence be stated as fact rather
/// than as a guess.
const String kNoCablesDetail =
    'Every row of this schedule derives from a Link. The derivation is '
    'built and running — the columns above are live and this table fills '
    'the moment a Link exists — but no surface in this build creates one '
    'yet, so there is nothing to derive from. The gap is the drawing '
    'gesture, not the schedule.';

/// What the summary strip says when every cable was filtered out.
const String kAllRowsFilteredHeadline =
    'Every cable in this document is hidden by the current filter.';

/// docs/08 §3's wiring schedule, as a tab.
///
/// Takes the document by value and re-derives on every build. That is
/// deliberate and it is what "populating live" means here: the app shell
/// rebuilds this subtree on every `DocumentController` change
/// notification, and a cached derivation would be one edit behind. The
/// derivation is O(links) over a document whose link count is in the
/// hundreds.
final class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({
    required this.document,
    this.initialPreset = SchedulePreset.pullSheet,
    super.key,
  });

  /// The live document. Mutated in place by commands, so this widget must
  /// not cache anything derived from it across builds.
  final RackDocument document;

  /// Which of §3.1's two presets opens first. The Pull Sheet, because it
  /// is the sheet an installer works from and AC-025's whole argument is
  /// about that reader.
  final SchedulePreset initialPreset;

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  late SchedulePreset _preset = widget.initialPreset;
  ScheduleSort? _sort;
  bool _includeJumpers = false;

  @override
  Widget build(BuildContext context) {
    // ONE derivation. If this screen ever shows both presets side by side
    // it projects this same `Schedule` twice rather than building two —
    // see `derived/schedule.dart`'s header.
    final schedule = buildSchedule(widget.document);
    final view = buildScheduleView(
      schedule,
      preset: _preset,
      sort: _sort,
      includeJumpersAndPowerCords: _includeJumpers,
    );
    final units = widget.document.settings.displayUnits;

    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ScheduleToolbar(
            preset: _preset,
            sort: view.sort,
            includeJumpers: _includeJumpers,
            hiddenByToggle:
                view.exclusions.jumpers + view.exclusions.powerCords,
            onPreset: (value) => setState(() {
              _preset = value;
              // The sort follows the preset unless the user has pinned
              // one: §3.6 gives each preset its own default and switching
              // to the Termination Schedule while still sorted by room
              // would silently answer a different question.
              _sort = null;
            }),
            onSort: (value) => setState(() => _sort = value),
            onIncludeJumpers: (value) =>
                setState(() => _includeJumpers = value),
          ),
          _ScheduleSummary(view: view, units: units),
          const Divider(height: 1),
          Expanded(
            child: _ScheduleTable(view: view, units: units),
          ),
        ],
      ),
    );
  }
}

/// The preset switch, the §3.6 sort selector and AC-026's toggle.
class _ScheduleToolbar extends StatelessWidget {
  const _ScheduleToolbar({
    required this.preset,
    required this.sort,
    required this.includeJumpers,
    required this.hiddenByToggle,
    required this.onPreset,
    required this.onSort,
    required this.onIncludeJumpers,
  });

  final SchedulePreset preset;
  final ScheduleSort sort;
  final bool includeJumpers;
  final int hiddenByToggle;
  final ValueChanged<SchedulePreset> onPreset;
  final ValueChanged<ScheduleSort> onSort;
  final ValueChanged<bool> onIncludeJumpers;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Wrap(
        spacing: 16,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SegmentedButton<SchedulePreset>(
            segments: [
              for (final value in SchedulePreset.values)
                ButtonSegment<SchedulePreset>(
                  value: value,
                  // The sheet id rides with the name, because the sheet
                  // the user is looking at and the sheet that prints must
                  // be nameable as the same thing (docs/08 §2.1).
                  label: Text('${value.title} · ${value.sheetId}'),
                ),
            ],
            selected: {preset},
            showSelectedIcon: false,
            onSelectionChanged: (selection) => onPreset(selection.first),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Sort', style: theme.textTheme.labelMedium),
              const SizedBox(width: 8),
              DropdownButton<ScheduleSort>(
                value: sort,
                onChanged: (value) {
                  if (value != null) onSort(value);
                },
                items: [
                  for (final value in ScheduleSort.values)
                    DropdownMenuItem<ScheduleSort>(
                      value: value,
                      child: Text(scheduleSortLabel(value)),
                    ),
                ],
              ),
            ],
          ),
          // AC-026's toggle, labelled with the number it is hiding.
          // "Show jumpers" alone would leave the reader to wonder whether
          // there are any; the count is the thing that makes the default
          // exclusion safe.
          FilterChip(
            selected: includeJumpers,
            onSelected: onIncludeJumpers,
            label: Text(
              hiddenByToggle == 0 && !includeJumpers
                  ? 'Show jumpers and power cords'
                  : 'Show jumpers and power cords ($hiddenByToggle hidden)',
            ),
          ),
        ],
      ),
    );
  }
}

/// What §3.6's sort keys are called on screen.
String scheduleSortLabel(ScheduleSort sort) => switch (sort) {
  ScheduleSort.designator => 'Cable ID',
  ScheduleSort.roomThenPathway => 'Room, then pathway',
  ScheduleSort.rackThenPanelThenPort => 'Rack, panel, port',
  ScheduleSort.domainThenFamily => 'Domain, then family',
  ScheduleSort.fromDeviceThenPort => 'From device, then port',
  ScheduleSort.cutLengthDescending => 'Length, longest first',
  ScheduleSort.roughInStatus => 'Rough-in status',
};

/// The counts strip.
///
/// EVERY UNKNOWN AND EVERY EXCLUSION IS ON SCREEN. `derived/totals.dart`
/// rule 2 — "a caller that renders a total without also rendering this
/// number is showing a number that is quietly wrong by an unstated
/// amount" — is a rule about this widget as much as about the chip strip
/// over the rack canvas.
class _ScheduleSummary extends StatelessWidget {
  const _ScheduleSummary({required this.view, required this.units});

  final ScheduleView view;
  final UnitSystem units;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final exclusions = view.exclusions;
    const unknown = _ChipTone.unknown;
    const attention = _ChipTone.attention;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: DefaultTextStyle.merge(
        style: theme.textTheme.labelSmall ?? const TextStyle(),
        child: Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            _Chip(label: '${view.rowCount} rows'),
            _Chip(label: 'Total ${_footageLabel(view.footage, units)}'),
            if (view.estimatedCount > 0)
              _Chip(label: '${view.estimatedCount} estimated'),
            if (view.footage.unknownCount > 0)
              _Chip(
                label: '${view.footage.unknownCount} length unknown',
                tone: unknown,
              ),
            // THE THREE THAT MUST NEVER BE SILENT — see
            // `derived/schedule.dart`'s header. An undetermined class, a
            // classifier disagreement and an off-convention pull are each
            // a fact a reader would otherwise have to already suspect.
            if (view.undeterminedClassCount > 0)
              _Chip(
                label: '${view.undeterminedClassCount} class not determined',
                tone: unknown,
              ),
            if (view.classDisagreementCount > 0)
              _Chip(
                label: '${view.classDisagreementCount} class disputed',
                tone: attention,
              ),
            if (view.jacket.exceptions > 0)
              _Chip(
                label: '${view.jacket.exceptions} pulled off-convention',
                tone: attention,
              ),
            if (view.jacket.unknownEntries > 0)
              _Chip(
                label: '${view.jacket.unknownEntries} unknown jacket colour',
                tone: unknown,
              ),
            if (exclusions.jumpers > 0)
              _Chip(label: '${exclusions.jumpers} jumpers hidden'),
            if (exclusions.powerCords > 0)
              _Chip(label: '${exclusions.powerCords} power cords hidden'),
            if (exclusions.internal > 0)
              _Chip(label: '${exclusions.internal} internal hidden'),
            if (exclusions.notLandingInRack > 0)
              _Chip(label: '${exclusions.notLandingInRack} land in no rack'),
          ],
        ),
      ),
    );
  }
}

/// `1,860 ft`, `— ft` when nothing known contributed.
///
/// The em dash is `totals.dart` rule 1 on screen: a rollup with no known
/// contributor prints "we do not know", never `0 ft`.
String _footageLabel(Rollup<Len> footage, UnitSystem units) {
  final value = footage.value;
  final suffix = units == UnitSystem.imperial ? 'ft' : 'm';
  if (value == null) return '$kUnknownCell $suffix';
  final divisor = units == UnitSystem.imperial
      ? Len.nmPerInch * 12
      : Len.nmPerMillimetre * 1000;
  return '${(value.nm / divisor).round()} $suffix';
}

enum _ChipTone { neutral, unknown, attention }

class _Chip extends StatelessWidget {
  const _Chip({required this.label, this.tone = _ChipTone.neutral});

  final String label;
  final _ChipTone tone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (Color background, Color foreground) = switch (tone) {
      _ChipTone.neutral => (scheme.surfaceContainerHighest, scheme.onSurface),
      _ChipTone.unknown => (
        scheme.surfaceContainerHighest,
        scheme.onSurfaceVariant,
      ),
      _ChipTone.attention => (scheme.errorContainer, scheme.onErrorContainer),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(label, style: TextStyle(color: foreground)),
      ),
    );
  }
}

/// The header row, the group bands and the rows.
///
/// The columns are laid out at §3.2/§3.3's own point widths, scaled up to
/// fill the window. Keeping the RATIOS is what makes the screen and the
/// printed sheet recognisably the same table; keeping the absolute points
/// would waste two thirds of a 1600 px window.
class _ScheduleTable extends StatelessWidget {
  const _ScheduleTable({required this.view, required this.units});

  final ScheduleView view;
  final UnitSystem units;

  @override
  Widget build(BuildContext context) {
    final totalPt = view.columns.fold<double>(0, (n, c) => n + c.widthPt);
    return LayoutBuilder(
      builder: (context, constraints) {
        // Never below 1.0: a window narrower than the sheet scrolls
        // horizontally rather than squeezing text past legibility, which
        // is docs/08 §6.2's rule for the printed page applied here.
        final scale = constraints.maxWidth / totalPt;
        final width = scale > 1 ? constraints.maxWidth : totalPt;
        final effective = width / totalPt;
        return Scrollbar(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: width,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _HeaderRow(columns: view.columns, scale: effective),
                  const Divider(height: 1, thickness: 1),
                  Expanded(
                    child: view.rowCount == 0
                        ? _EmptyBody(view: view)
                        : _Body(view: view, units: units, scale: effective),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.columns, required this.scale});

  final List<ScheduleColumn> columns;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final column in columns)
            SizedBox(
              width: column.widthPt * scale,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  column.header,
                  textAlign: _align(column.align),
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

TextAlign _align(ScheduleAlign align) => switch (align) {
  ScheduleAlign.left => TextAlign.left,
  ScheduleAlign.right => TextAlign.right,
  ScheduleAlign.centre => TextAlign.center,
};

/// The zero-row body: the honest panel, under a live header row.
class _EmptyBody extends StatelessWidget {
  const _EmptyBody({required this.view});

  final ScheduleView view;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // TWO DIFFERENT EMPTY STATES, because they have different causes and
    // different answers. "There are no cables" is about the document;
    // "everything is hidden" is about a toggle the user can reach.
    final headline = view.isEmptyDocument
        ? kNoCablesHeadline
        : kAllRowsFilteredHeadline;
    final detail = view.isEmptyDocument
        ? kNoCablesDetail
        : 'The ${view.sourceRowCount} cables in this document are all '
              'excluded by this preset: '
              '${_exclusionSentence(view.exclusions)}.';
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(headline, style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              Text(
                detail,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _exclusionSentence(ScheduleExclusions exclusions) {
  final parts = <String>[
    if (exclusions.jumpers > 0) '${exclusions.jumpers} jumper',
    if (exclusions.powerCords > 0) '${exclusions.powerCords} power cord',
    if (exclusions.internal > 0) '${exclusions.internal} internal',
    if (exclusions.notLandingInRack > 0)
      '${exclusions.notLandingInRack} landing in no rack',
  ];
  return parts.isEmpty ? 'no reason recorded' : parts.join(', ');
}

class _Body extends StatelessWidget {
  const _Body({
    required this.view,
    required this.units,
    required this.scale,
  });

  final ScheduleView view;
  final UnitSystem units;
  final double scale;

  @override
  Widget build(BuildContext context) {
    // Bands and rows flattened into one list, which is §3.7's own
    // `m.flattened` shape — the paginator consumes exactly this sequence,
    // so the screen scrolls the same order the sheet paginates.
    final items = <Widget>[];
    for (final group in view.groups) {
      items.add(_BandRow(group: group, units: units));
      for (final row in group.rows) {
        items.add(
          _DataRow(
            entry: row,
            columns: view.columns,
            units: units,
            scale: scale,
          ),
        );
      }
    }
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) => items[index],
    );
  }
}

/// §3.6's group band: `▌ NETWORK — 24 runs ──── 1,860 ft total`.
class _BandRow extends StatelessWidget {
  const _BandRow({required this.group, required this.units});

  final ScheduleGroup group;
  final UnitSystem units;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // The undetermined band is toned apart from a room band because it is
    // not a place — it is the set of cables this document cannot classify,
    // and a reader skimming for rooms must not mistake it for one.
    final background = group.isUndeterminedClass
        ? scheme.errorContainer
        : scheme.surfaceContainerHigh;
    final foreground = group.isUndeterminedClass
        ? scheme.onErrorContainer
        : scheme.onSurface;
    return ColoredBox(
      color: background,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '${group.title} — ${group.rowCount} runs',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              _bandTrailing(group, units),
              style: theme.textTheme.labelSmall?.copyWith(color: foreground),
            ),
          ],
        ),
      ),
    );
  }
}

String _bandTrailing(ScheduleGroup group, UnitSystem units) {
  final footage = _footageLabel(group.footage, units);
  final unknown = group.footage.unknownCount;
  final estimated = group.estimatedCount;
  return <String>[
    footage,
    if (estimated > 0) '$estimated estimated',
    if (unknown > 0) '$unknown unknown',
  ].join(' · ');
}

class _DataRow extends StatelessWidget {
  const _DataRow({
    required this.entry,
    required this.columns,
    required this.units,
    required this.scale,
  });

  final ScheduleEntry entry;
  final List<ScheduleColumn> columns;
  final UnitSystem units;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant,
            width: 0.5,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final column in columns)
              SizedBox(
                width: column.widthPt * scale,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: _cell(context, column),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _cell(BuildContext context, ScheduleColumn column) {
    final theme = Theme.of(context);
    // §3.2 column 10 is four boxes and a rule to initial, not text. It is
    // drawn rather than written because there is nothing to write.
    if (column.id == ScheduleColumnId.signOff) {
      return const _SignOffCell();
    }
    final text = entry.cell(column.id, units: units);
    final isUnknown = text == kUnknownCell;
    // ITALIC MEANS ESTIMATED (§3.2 column 8), and it is the only thing
    // italic means on this table. AC-024: "tagged as such so nobody bills
    // off them".
    final estimated =
        column.id == ScheduleColumnId.length && entry.lengthIsEstimated;
    return Text(
      text,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      textAlign: _align(column.align),
      style: theme.textTheme.bodySmall?.copyWith(
        fontStyle: estimated ? FontStyle.italic : FontStyle.normal,
        color: isUnknown
            ? theme.colorScheme.onSurfaceVariant
            : theme.colorScheme.onSurface,
        fontWeight: column.id == ScheduleColumnId.cableId
            ? FontWeight.w700
            : FontWeight.w400,
      ),
    );
  }
}

/// §3.2's `☐ P · ☐ T · ☐ T · INIT ___`.
///
/// NOT CHECKBOXES. A `Checkbox` here would be tappable, and tapping it
/// would have to store something the model has no field for — the three
/// sign-off states live on paper in a jobsite pocket, not in the
/// document. `RoughInStatus` is the document's own answer to a
/// neighbouring question and is a different column (§3.4's `ROUGH-IN`).
class _SignOffCell extends StatelessWidget {
  const _SignOffCell();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      '☐ P  ☐ T  ☐ T  ____',
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}
