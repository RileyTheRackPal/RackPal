// `Ctrl+J`, docs/06 §4.6: *"Clones the selection below, labels
// auto-incremented past the highest existing index."* M4-F6, board `#696`.
//
// ═══════════════════════════════════════════════════════════════════════
// "PAST THE HIGHEST EXISTING INDEX" IS NOT "PLUS ONE"
// ═══════════════════════════════════════════════════════════════════════
// §4.6's phrase is about the TEMPLATE, not about the selection. Duplicating
// `HDMI IN 1`..`HDMI IN 4` inside a bank that already runs to `HDMI IN 12`
// produces 13, 14, 15, 16, not 5, 6, 7, 8. A rule counting from the
// selection would mint labels that already exist on rows the person can
// see, which is the one outcome this operation cannot be allowed to have.
//
// THE SCAN IS PER SERIES, NOT PER TEMPLATE. Labels are grouped by their
// (prefix, suffix) pair, which is what `inferLabelSeries` reads out of a
// cell, and each group counts on from its own highest index. A selection
// holding `HDMI IN 3` and `SPK A 1` is two series and gets two counters;
// one shared counter would jump one of them past a number nothing uses.
//
// A LABEL WITH NO DIGITS IS COPIED VERBATIM, and that is legal rather than
// a fallback (§4.6's multi-row row already permits a bank of identical
// labels). `inferLabelSeries` returns null and this file does not invent a
// series to have one; the keys still differ, because `autoPortKey`
// suffixes on collision.
//
// ═══════════════════════════════════════════════════════════════════════
// WHAT A CLONE DELIBERATELY DOES NOT CARRY
// ═══════════════════════════════════════════════════════════════════════
//  * `renamedFrom`. Those aliases are the SOURCE's history: they say what
//    that port used to be called in projects that already resolve it
//    (CR-051). A clone has never been in any project, so carrying them
//    would offer a migration join to a port that was never on the other
//    end of one.
//  * `designatorHint`. A pinned designator is a claim to one name, and two
//    ports holding it is precisely the "duplicate designator in-template"
//    that §4.6's live validation already flags. The clone drops the pin and
//    takes its designator from `PORT_SEQ` like any other new row.
//  * The panel position. Every port sits at `kUnplacedPanelPosition` today
//    because panel auto-layout is M4-K, so copying one is harmless right
//    now and would place two jacks in one hole the moment it is not.
//
// Everything else carries, through the same exhaustive field list a rename
// uses, because a clone that silently dropped `poe` or `serial` would be a
// data loss with no error and no visible symptom until an export.
import 'package:rackpal_core/src/builder/port_commands.dart';
import 'package:rackpal_core/src/builder/port_fill.dart'
    show LabelSeries, inferLabelSeries;
import 'package:rackpal_core/src/commands/command.dart';
import 'package:rackpal_core/src/commands/rack_commands.dart'
    show ordersBetween;
import 'package:rackpal_core/src/model/template.dart';

/// Why a duplicate produced nothing, so the surface can say which.
///
/// A REFUSAL IS ANNOUNCED, NEVER SWALLOWED: `PortFillRefusal`'s own doc
/// makes the argument, and it applies to all fourteen of §4.6's rows.
enum PortDuplicateRefusal {
  /// Nothing is selected, so there is nothing to clone.
  nothingSelected,

  /// A sort badge is showing. Duplicating mints `order` values, and §4.6
  /// disables reorder while a sort is showing for exactly that reason:
  /// "below itself" is a claim about the declared order, and the person
  /// is not looking at it.
  theViewIsSorted,

  /// `FracIndex` ran out of room between the block and the row below it.
  /// Shares `buildPortReorder`'s wording because it is the same wall.
  noRoomBetweenTheRows,
}

/// What a duplicate produced: commands to run, or the reason there are
/// none.
final class PortDuplicateResult {
  const PortDuplicateResult.commands(this.commands) : refusal = null;
  const PortDuplicateResult.refused(PortDuplicateRefusal this.refusal)
    : commands = const [];

  final List<Command<TemplateBody>> commands;
  final PortDuplicateRefusal? refusal;

  bool get isRefused => refusal != null;
}

/// One line of prose per refusal, in the user's vocabulary.
String portDuplicateRefusalMessage(PortDuplicateRefusal refusal) =>
    switch (refusal) {
      PortDuplicateRefusal.nothingSelected =>
        'Select the ports to duplicate first.',
      PortDuplicateRefusal.theViewIsSorted =>
        'The grid is sorted. Duplicate adds rows in the declared order, so '
            'clear the sort or commit it first.',
      PortDuplicateRefusal.noRoomBetweenTheRows =>
        'No room to insert below the selection. Commit a sort or move the '
            'rows apart first.',
    };

/// `Ctrl+J`: clone [selectedInOrder] immediately below the block.
///
/// [selectedInOrder] is the selected keys in DISPLAY order, the same input
/// `buildFillDown` and `buildPortReorder` take, so the clones land in the
/// order the person can see rather than in map order.
///
/// **THE CLONES LAND AFTER THE LAST SELECTED ROW**, contiguously, keeping
/// their own relative order. A non-contiguous selection therefore
/// CONSOLIDATES its copies rather than interleaving them next to each of
/// their sources: three rows picked out of a bank of twelve give three
/// copies together at the bottom of the block, which is what "below the
/// selection" says and is the only reading that gives one insertion point.
PortDuplicateResult buildPortDuplicate({
  required TemplateBody body,
  required List<String> selectedInOrder,
  bool viewIsSorted = false,
}) {
  if (viewIsSorted) {
    return const PortDuplicateResult.refused(
      PortDuplicateRefusal.theViewIsSorted,
    );
  }
  final declared = portsInDeclaredOrder(body.ports);
  final byKey = {for (final port in declared) port.key.v: port};
  final block = [
    for (final key in selectedInOrder)
      if (byKey[key] case final PortDef port) port,
  ];
  if (block.isEmpty) {
    return const PortDuplicateResult.refused(
      PortDuplicateRefusal.nothingSelected,
    );
  }

  // The insertion point is after the LAST member in declared order, which
  // is not necessarily the last member of `selectedInOrder`: a display
  // order under no sort equals the declared order, but this does not have
  // to assume that to be right.
  var lastAt = -1;
  final blockKeys = {for (final port in block) port.key.v};
  for (var i = 0; i < declared.length; i++) {
    if (blockKeys.contains(declared[i].key.v)) lastAt = i;
  }
  final minted = ordersBetween(
    declared[lastAt].order,
    lastAt + 1 < declared.length ? declared[lastAt + 1].order : null,
    block.length,
  );
  if (minted == null) {
    return const PortDuplicateResult.refused(
      PortDuplicateRefusal.noRoomBetweenTheRows,
    );
  }

  final labels = _nextLabels(body, block);
  // ACCUMULATED, so two clones of the same label do not collide with each
  // other: `autoPortKey` is only unique against what it is told is taken,
  // and the ports it is minting against do not exist in `body` yet.
  final taken = {for (final port in body.ports) port.key.v};

  final commands = <Command<TemplateBody>>[];
  for (var i = 0; i < block.length; i++) {
    final key = autoPortKey(
      labels[i],
      taken: taken,
      ordinal: body.ports.length + i + 1,
    );
    taken.add(key.v);
    commands.add(
      AddPortCommand(
        portWithIdentity(
          block[i],
          key: key,
          label: labels[i],
          order: minted[i],
          // A DUPLICATE IS AUTO-PLACED, not stacked on its source.
          // `portWithIdentity` keeps this REQUIRED on purpose (see its
          // own comment about not defaulting a pass-through), so the
          // answer is spelled rather than omitted. Copying the source's
          // nudge would put the new jack exactly on top of the old one,
          // which is the one place a person can never see it.
          position: null,
          renamedFrom: const [],
          designatorHint: null,
        ),
      ),
    );
  }
  return PortDuplicateResult.commands(commands);
}

/// One label per member of [block], counting each series on from the
/// highest index the WHOLE template already uses for it.
List<String> _nextLabels(TemplateBody body, List<PortDef> block) {
  // Highest index per (prefix, suffix) across every label in the template,
  // the source rows included: they are what "already exists" means.
  final highest = <String, int>{};
  for (final port in body.ports) {
    final series = inferLabelSeries(port.label);
    if (series == null) continue;
    final group = _groupOf(series);
    final seen = highest[group];
    if (seen == null || series.start > seen) highest[group] = series.start;
  }

  final cursor = <String, int>{};
  return [
    for (final port in block)
      if (inferLabelSeries(port.label) case final LabelSeries series)
        () {
          final group = _groupOf(series);
          // The group's own counter, seeded past the template's highest
          // and advanced once per clone so two clones of one series get
          // two consecutive numbers rather than the same one.
          final next = (cursor[group] ?? highest[group] ?? series.start) + 1;
          cursor[group] = next;
          return LabelSeries(
            prefix: series.prefix,
            start: next,
            width: series.width,
            suffix: series.suffix,
          ).at(0);
        }()
      else
        port.label,
  ];
}

/// A series' identity for counting purposes: everything but the number.
///
/// The width is deliberately NOT in the key. `IN 1` and `IN 01` are the
/// same series written two ways, and treating them as two would count one
/// of them straight over the other.
String _groupOf(LabelSeries series) => '${series.prefix} ${series.suffix}';
