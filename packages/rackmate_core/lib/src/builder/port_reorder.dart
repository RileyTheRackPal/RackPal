// REORDERING PORTS (M4-F4 `#211`, CR-027, DR-064, docs/06 §4.6).
//
// ═══════════════════════════════════════════════════════════════════════
// ONE ROW MOVES AND ONE ROW IS WRITTEN
// ═══════════════════════════════════════════════════════════════════════
// docs/06 §4.6: "`PortDef.order` is a `FracIndex` (CR-027), a reorder is
// one field write on one row, not a renumber of the bank". CR-027 chose
// the type over an integer `sortOrder` precisely because renumbering
// neighbours is the operation that cannot be retrofitted onto a synced
// document, so an implementation here that renumbered would have thrown
// away the reason the field is a string. Nothing below touches a port
// that is not moving.
//
// ═══════════════════════════════════════════════════════════════════════
// THE PLAN IS DRAWN ON THE GLOBAL DECLARED ORDER, NOT ON THE BAND
// ═══════════════════════════════════════════════════════════════════════
// The grid's bands GROUP by bank (`port_table.dart`), they are not runs,
// so a row only ever appears inside another bank's band if its `bankKey`
// changes. That is why the destination is expressed against the band and
// the INDEX is minted against the whole declared order: dropping a row at
// the foot of its band must not leapfrog the ports of the bank below it,
// or the move would silently rewrite every `PORT_SEQ` under it.
//
// ═══════════════════════════════════════════════════════════════════════
// A REORDER RENUMBERS THE SILKSCREEN, AND THAT IS THE POINT
// ═══════════════════════════════════════════════════════════════════════
// `PortTableRow.portSeq` is the rank in the declared order and
// `J{PORT_SEQ:2}` renders from it, so moving a port changes the automatic
// designator of that port and of everything after it. This is not a side
// effect to be suppressed: a silkscreen follows the physical order of the
// jacks, and CR-042 leaves the project to allocate. A port whose
// designator the author PINNED (`designatorHint`) keeps it, because that
// is what pinning means.
import 'package:rackmate_core/src/builder/port_commands.dart';
import 'package:rackmate_core/src/commands/command.dart';
import 'package:rackmate_core/src/commands/rack_commands.dart'
    show ordersBetween;
import 'package:rackmate_core/src/model/template.dart';
import 'package:rackmate_core/src/units/ids.dart';

/// Why a reorder did nothing, so the grid can say which one it was.
///
/// The same rule `PortFillRefusal` states: fourteen keys in docs/06 §4.6
/// act on a selection, and one that quietly does nothing is
/// indistinguishable from one that is not bound.
enum PortReorderRefusal {
  /// No rows are selected, so there is nothing to move.
  nothingToMove,

  /// The selected rows are not all in one bank.
  ///
  /// A block that spans two banks has no single band to land in, and
  /// making the move change everyone's `bankKey` would be a structural
  /// edit delivered by a drag.
  crossesBanks,

  /// `Alt+Up` on the top row of a band, or `Alt+Down` on the bottom one.
  ///
  /// The band edge is a wall by ruling (DR-064): the Bank column is how a
  /// port changes bank, and an arrow key that silently retyped one would
  /// be a change to the template's structure delivered by a keystroke.
  atTheBandEdge,

  /// The destination is not a row this move may land after.
  destinationIsNotInTheBand,

  /// The two neighbours have no representable index between them.
  ///
  /// A hand-edited file only: `nextOrder` no longer mints the one pair
  /// that has no midpoint (DR-064). Named rather than swallowed, because
  /// the alternative is renumbering the bank, which is the thing CR-027
  /// exists to avoid.
  noRoomBetweenTheRows,
}

/// What a reorder produced: commands to run, or the reason there are none.
final class PortReorderPlan {
  const PortReorderPlan.commands(this.commands) : refusal = null;
  const PortReorderPlan.refused(PortReorderRefusal this.refusal)
    : commands = const [];

  final List<Command<TemplateBody>> commands;
  final PortReorderRefusal? refusal;

  bool get isRefused => refusal != null;
}

/// Moves [moving] so that it sits immediately after [afterKey], or at the
/// head of its band when [afterKey] is null.
///
/// [moving] is the selected keys in DISPLAY order, which is what makes the
/// block keep its internal order when it lands (DR-064, and the same rule
/// `buildFillDown` follows for its "top").
PortReorderPlan buildPortReorder({
  required TemplateBody body,
  required List<String> moving,
  required String? afterKey,
}) {
  if (moving.isEmpty) {
    return const PortReorderPlan.refused(PortReorderRefusal.nothingToMove);
  }

  final declared = portsInDeclaredOrder(body.ports);
  final byKey = {for (final port in declared) port.key.v: port};
  final block = [
    for (final key in moving)
      if (byKey[key] case final PortDef port) port,
  ];
  if (block.isEmpty) {
    return const PortReorderPlan.refused(PortReorderRefusal.nothingToMove);
  }

  final bank = block.first.bankKey;
  if (block.any((port) => port.bankKey != bank)) {
    return const PortReorderPlan.refused(PortReorderRefusal.crossesBanks);
  }

  final movingKeys = {for (final port in block) port.key.v};
  final rest = [
    for (final port in declared)
      if (!movingKeys.contains(port.key.v)) port,
  ];

  final int at;
  if (afterKey == null) {
    // The head of the band, which means "immediately before the first row
    // of this bank that is staying put".
    final first = rest.indexWhere((port) => port.bankKey == bank);
    // Every row of the band is moving, so there is nothing for the block
    // to be ordered against and nothing to write. Not a refusal: the rows
    // are already exactly where this asks them to be.
    if (first < 0) return const PortReorderPlan.commands([]);
    at = first;
  } else {
    final after = rest.indexWhere((port) => port.key.v == afterKey);
    if (after < 0 || rest[after].bankKey != bank) {
      return const PortReorderPlan.refused(
        PortReorderRefusal.destinationIsNotInTheBand,
      );
    }
    at = after + 1;
  }

  // THE NEIGHBOURS ARE GLOBAL AND THE DESTINATION IS BANDED. `at` was
  // found by looking at this bank's rows; the indices minted around it are
  // the ones on either side in the whole declared order, so the block
  // lands where the band says without stepping over the bank next door.
  final minted = ordersBetween(
    at == 0 ? null : rest[at - 1].order,
    at == rest.length ? null : rest[at].order,
    block.length,
  );
  if (minted == null) {
    return const PortReorderPlan.refused(
      PortReorderRefusal.noRoomBetweenTheRows,
    );
  }

  return PortReorderPlan.commands([
    for (var i = 0; i < block.length; i++)
      // A row already holding its new index is not written. Dragging a
      // selection one row down moves every member, so this is rarely
      // empty; dropping a block back where it came from produces nothing
      // at all, and an empty transaction is not an undo entry.
      if (block[i].order.v != minted[i].v)
        SetPortFieldCommand<FracIndex>(
          port: block[i].key,
          field: PortDefField.order,
          from: block[i].order,
          to: minted[i],
        ),
  ]);
}

/// `Alt+Up` and `Alt+Down`: [moving] slides one row through its band.
///
/// ═══════════════════════════════════════════════════════════════════════
/// THE ARITHMETIC IS HERE AND NOT IN THE WIDGET
/// ═══════════════════════════════════════════════════════════════════════
/// One slot up for a block that may be non-contiguous is a rule, not an
/// index: the block lands immediately above the nearest row above it that
/// is staying put, whether the selection was three rows or three rows with
/// a gap. Written in the widget it would be four off-by-one opportunities
/// no widget test could see the inside of; written here it is the same
/// destination [buildPortReorder] already takes, arrived at by counting.
PortReorderPlan buildPortNudge({
  required TemplateBody body,
  required List<String> moving,
  required bool up,
}) {
  if (moving.isEmpty) {
    return const PortReorderPlan.refused(PortReorderRefusal.nothingToMove);
  }

  final declared = portsInDeclaredOrder(body.ports);
  final byKey = {for (final port in declared) port.key.v: port};
  final block = [
    for (final key in moving)
      if (byKey[key] case final PortDef port) port,
  ];
  if (block.isEmpty) {
    return const PortReorderPlan.refused(PortReorderRefusal.nothingToMove);
  }

  final bank = block.first.bankKey;
  if (block.any((port) => port.bankKey != bank)) {
    return const PortReorderPlan.refused(PortReorderRefusal.crossesBanks);
  }

  final movingKeys = {for (final port in block) port.key.v};
  final band = [
    for (final port in declared)
      if (port.bankKey == bank) port,
  ];
  final stayed = [
    for (final port in band)
      if (!movingKeys.contains(port.key.v)) port,
  ];
  if (stayed.isEmpty) {
    return const PortReorderPlan.refused(PortReorderRefusal.atTheBandEdge);
  }

  if (up) {
    // How many rows that are staying put sit above the topmost mover. Zero
    // means the block is already at the top of its band.
    final firstMover = band.indexWhere((p) => movingKeys.contains(p.key.v));
    final above = band
        .take(firstMover)
        .where((p) => !movingKeys.contains(p.key.v))
        .length;
    if (above == 0) {
      return const PortReorderPlan.refused(PortReorderRefusal.atTheBandEdge);
    }
    return buildPortReorder(
      body: body,
      moving: [for (final port in block) port.key.v],
      // One slot up: land after the row two places above, which for the
      // topmost slot is the head of the band and no row at all.
      afterKey: above >= 2 ? stayed[above - 2].key.v : null,
    );
  }

  final lastMover = band.lastIndexWhere((p) => movingKeys.contains(p.key.v));
  final aboveAndAt = band
      .take(lastMover + 1)
      .where((p) => !movingKeys.contains(p.key.v))
      .length;
  if (aboveAndAt >= stayed.length) {
    return const PortReorderPlan.refused(PortReorderRefusal.atTheBandEdge);
  }
  return buildPortReorder(
    body: body,
    moving: [for (final port in block) port.key.v],
    // One slot down: land after the first row that is currently below the
    // block.
    afterKey: stayed[aboveAndAt].key.v,
  );
}

/// What the grid says when a reorder declines.
///
/// IN CORE, BESIDE THE REFUSAL, for `portFillRefusalMessage`'s reason: a
/// sentence built in the widget is a second vocabulary, and the first time
/// one of them changes they disagree.
String portReorderRefusalMessage(PortReorderRefusal refusal) =>
    switch (refusal) {
      PortReorderRefusal.nothingToMove =>
        'Select a row first, then Alt+Up or Alt+Down to move it.',
      PortReorderRefusal.crossesBanks =>
        'These rows are in different banks. A move works within one bank; '
            'use the Bank column to move a port to another one.',
      PortReorderRefusal.atTheBandEdge =>
        'That is as far as this bank goes. Use the Bank column to move a '
            'port to another bank.',
      PortReorderRefusal.destinationIsNotInTheBand =>
        'A row can only be dropped among the rows of its own bank.',
      PortReorderRefusal.noRoomBetweenTheRows =>
        'These two rows have no position left between them. Reordering '
            'never renumbers the bank, so there is nowhere to put this one.',
    };
