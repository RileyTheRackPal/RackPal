// `Ctrl+M` `Move to bank…`, docs/06 §4.6. M4-F10, board `#700`, DR-078.
//
// §4.6 gives this a binding and leaves its behaviour column EMPTY, so the
// behaviour is decided here rather than quoted, and DR-078 §11.77.2 rules
// the one question that was a product decision.
//
// ═══════════════════════════════════════════════════════════════════════
// A MOVE IS A `bankKey` WRITE **AND** AN `order` WRITE
// ═══════════════════════════════════════════════════════════════════════
// This is the trap the task named, and it is the grid's own banding rule
// biting. `port_table.dart` bands by `bankKey` in FIRST-APPEARANCE order
// over the declared order, so a band is a RUN of that order. Writing
// `bankKey` on a row in the middle of the template without touching
// `order` therefore splits the target bank into two bands with other rows
// between them: visible, honest, and not what anybody asked for.
//
// So the block lands at the END of the target band, contiguously, keeping
// its own relative order. The alternative (at the head) was rejected for
// the reason `nextOrder` exists: ports are authored by appending, a bank's
// first row is usually its `IN 1`, and a move that pushed six rows in
// front of it would renumber every automatic designator in the band
// (§4.6: `PORT_SEQ` is the rank in the declared order).
//
// ═══════════════════════════════════════════════════════════════════════
// IT OFFERS THE BANKS THAT EXIST AND MINTS NONE (DR-078 §11.77.2)
// ═══════════════════════════════════════════════════════════════════════
// Creating a bank is `BankDef` CRUD and belongs to M4-J1. A creation path
// here would have to agree with J1 about naming, ordering and collisions
// before J1 has decided any of them. [movableBanks] is therefore the whole
// of what a dialog may offer, and a template with nowhere to move to gets
// a refusal with a sentence rather than a text field.
//
// **`Not in a bank` IS A DESTINATION.** `bankKey` is nullable and
// `PortTableBand`'s own title says `Not in a bank`, so unbanding a row is
// a state the grid already draws and a person can already see. Offering it
// is not a new concept; refusing it would be one.
import 'package:rackmate_core/src/builder/port_commands.dart';
import 'package:rackmate_core/src/commands/command.dart';
import 'package:rackmate_core/src/commands/rack_commands.dart'
    show ordersBetween;
import 'package:rackmate_core/src/model/template.dart';
import 'package:rackmate_core/src/units/ids.dart' show FracIndex;

/// Why a move produced nothing.
enum PortMoveToBankRefusal {
  /// Nothing is selected, so there is nothing to move.
  nothingSelected,

  /// A sort badge is showing. A move writes `order`, and §4.6 disables
  /// reorder while a sort shows for exactly that reason.
  theViewIsSorted,

  /// Every row is already in the destination, so there is nothing to do.
  /// Not an error: it is what the person asked for, already true.
  alreadyThere,

  /// The template declares no bank other than the one the selection is
  /// already in, and this operation does not create one (DR-078
  /// §11.77.2).
  nowhereToMoveTo,

  /// `FracIndex` ran out of room after the destination band's last row.
  noRoomBetweenTheRows,
}

/// One line of prose per refusal.
String portMoveToBankRefusalMessage(
  PortMoveToBankRefusal refusal,
) => switch (refusal) {
  PortMoveToBankRefusal.nothingSelected => 'Select the ports to move first.',
  PortMoveToBankRefusal.theViewIsSorted =>
    'The grid is sorted. A move rewrites the declared order, so clear '
        'the sort or commit it first.',
  PortMoveToBankRefusal.alreadyThere => 'Those ports are already in that bank.',
  PortMoveToBankRefusal.nowhereToMoveTo =>
    'This template has no other bank to move to. Add one in the Banks '
        'section first.',
  PortMoveToBankRefusal.noRoomBetweenTheRows =>
    'No room to place the ports at the end of that bank. Commit a sort '
        'or move the rows apart first.',
};

/// What a move produced.
final class PortMoveToBankResult {
  const PortMoveToBankResult.commands(this.commands) : refusal = null;
  const PortMoveToBankResult.refused(PortMoveToBankRefusal this.refusal)
    : commands = const [];

  final List<Command<TemplateBody>> commands;
  final PortMoveToBankRefusal? refusal;

  bool get isRefused => refusal != null;
}

/// One destination a dialog may offer.
///
/// `key` null is `Not in a bank`. `label` is what the band header prints,
/// so the dialog and the grid name the same destination the same way; a
/// dialog spelling its own would be the second place a bank has a name.
typedef PortBankTarget = ({String? key, String label, int portCount});

/// Every bank [body] can move ports INTO, in declared band order.
///
/// **DECLARED BANKS PLUS THE UNBANDED BAND**, and nothing else: no
/// creation (DR-078 §11.77.2). A `bankKey` named by ports and defined by
/// no `BankDef` is included, because `PortTableBand.isUndeclaredBank` is a
/// state the grid already draws and moving a row into it is no stranger
/// than the rows already sitting there.
List<PortBankTarget> movableBanks(TemplateBody body) {
  final counts = <String?, int>{};
  // FIRST-APPEARANCE ORDER over the declared order, which is exactly how
  // `buildPortTable` bands, so this list is in the order the person sees.
  for (final port in portsInDeclaredOrder(body.ports)) {
    counts[port.bankKey] = (counts[port.bankKey] ?? 0) + 1;
  }
  final declared = {for (final bank in body.banks) bank.key: bank};
  final targets = <PortBankTarget>[
    for (final entry in counts.entries)
      (
        key: entry.key,
        label: switch (entry.key) {
          null => kUnbandedBankLabel,
          final String key => declared[key]?.label ?? key,
        },
        portCount: entry.value,
      ),
  ];
  // A DECLARED BANK WITH NO PORTS IS STILL A DESTINATION. It has no band
  // in the grid, so the loop above never saw it, and it is precisely the
  // bank somebody just created in order to move ports into.
  for (final bank in body.banks) {
    if (counts.containsKey(bank.key)) continue;
    targets.add((key: bank.key, label: bank.label, portCount: 0));
  }
  return targets;
}

/// What `PortTableBand` prints for the ports that belong to no bank, so
/// the dialog offers the destination by the name the grid gives it.
const String kUnbandedBankLabel = 'Not in a bank';

/// `Ctrl+M`: move [selectedInOrder] to the end of [targetBankKey]'s band.
///
/// [targetBankKey] null moves them out of any bank.
PortMoveToBankResult buildPortMoveToBank({
  required TemplateBody body,
  required List<String> selectedInOrder,
  required String? targetBankKey,
  bool viewIsSorted = false,
}) {
  if (viewIsSorted) {
    return const PortMoveToBankResult.refused(
      PortMoveToBankRefusal.theViewIsSorted,
    );
  }
  final declared = portsInDeclaredOrder(body.ports);
  final byKey = {for (final port in declared) port.key.v: port};
  final block = [
    for (final key in selectedInOrder)
      if (byKey[key] case final PortDef port) port,
  ];
  if (block.isEmpty) {
    return const PortMoveToBankResult.refused(
      PortMoveToBankRefusal.nothingSelected,
    );
  }
  if (block.every((port) => port.bankKey == targetBankKey)) {
    return const PortMoveToBankResult.refused(
      PortMoveToBankRefusal.alreadyThere,
    );
  }

  // The rows staying put, which is what the destination is measured
  // against: a band's "last row" must not be a row that is about to leave.
  final movingKeys = {for (final port in block) port.key.v};
  final rest = [
    for (final port in declared)
      if (!movingKeys.contains(port.key.v)) port,
  ];

  // THE END OF THE TARGET BAND, which is the last STAYING row carrying
  // that bank key. A band whose every row is moving out has no anchor, so
  // the block lands where the band was: after the row above it.
  var lastAt = -1;
  for (var i = 0; i < rest.length; i++) {
    if (rest[i].bankKey == targetBankKey) lastAt = i;
  }
  final FracIndex? before;
  final FracIndex? after;
  if (lastAt >= 0) {
    before = rest[lastAt].order;
    after = lastAt + 1 < rest.length ? rest[lastAt + 1].order : null;
  } else {
    // An empty destination: append past everything that stays. Appending
    // rather than prepending keeps a newly created bank's first ports in
    // the order they were moved, and never in front of bank 1's `IN 1`.
    before = rest.isEmpty ? null : rest.last.order;
    after = null;
  }

  final minted = ordersBetween(before, after, block.length);
  if (minted == null) {
    return const PortMoveToBankResult.refused(
      PortMoveToBankRefusal.noRoomBetweenTheRows,
    );
  }

  return PortMoveToBankResult.commands([
    for (var i = 0; i < block.length; i++) ...[
      // TWO WRITES PER ROW, and both are needed: see the file header.
      // Skipped individually, so a selection spanning two banks writes
      // `bankKey` only on the rows that are changing bank while every row
      // still takes its new position.
      if (block[i].bankKey != targetBankKey)
        SetPortFieldCommand<String?>(
          port: block[i].key,
          field: PortDefField.bankKey,
          from: block[i].bankKey,
          to: targetBankKey,
        ),
      if (block[i].order.v != minted[i].v)
        SetPortFieldCommand<FracIndex>(
          port: block[i].key,
          field: PortDefField.order,
          from: block[i].order,
          to: minted[i],
        ),
    ],
  ]);
}
