// `BankDef` CRUD: rename, remove, and DR-085's mirror. Board `#181` /
// `#223` (M4-J1).
//
// ═════════════════════════════════════════════════════════════════════
// THIS FILE IS THE ONE `port_move_to_bank.dart` SAID IT WAS WAITING FOR
// ═════════════════════════════════════════════════════════════════════
// Its header: "Creating a bank is `BankDef` CRUD and belongs to M4-J1. A
// creation path here would have to agree with J1 about naming, ordering
// and collisions before J1 has decided any of them." Those three are
// decided here, and `Ctrl+M` keeps offering only the banks that exist.
//
// Naming and collisions REUSE `quick_add.dart`'s `uniqueBankKey` rather
// than growing a second generator, which is DR-085 §11.84.5's clause and
// the same argument `AddBankCommand`'s own `abbr` comment makes: a
// separate derivation would be "a third place for the same vocabulary to
// drift".
//
// ═════════════════════════════════════════════════════════════════════
// A BANK IS PRESENTATION, SO REMOVING ONE MUST NOT REMOVE ITS PORTS
// ═════════════════════════════════════════════════════════════════════
// CR-055 is explicit that a BANK groups for presentation while a
// `PortSetDef` groups electrically. Deleting a presentation grouping and
// taking real ports with it would destroy authored data on a cosmetic
// action, so [RemoveBankCommand] keeps every port and clears its
// `bankKey`.
//
// AND IT CLEARS THEM RATHER THAN LEAVING THEM DANGLING, which is the part
// worth arguing. `PortTableBand` deliberately draws a band whose `bankKey`
// names no `BankDef`, because "a bank key with no `BankDef` is what a
// hand-edited file or a half-finished paste leaves behind" — that is
// tolerance for a file somebody else broke, NOT a state this product
// should mint. `RemovePortCommand` settles the principle one type over: it
// takes the passthrough pairs with the port, because a dangling reference
// "reads as a pairing the user can no longer see". A dangling `bankKey`
// reads as a bank the user can no longer see.
//
// The ports land in `Not in a bank`, which `port_move_to_bank.dart` calls
// "a state the grid already draws and a person can already see".
import 'package:rackpal_core/src/builder/port_commands.dart'
    show AddBankCommand, AddPortCommand;
import 'package:rackpal_core/src/builder/port_impact.dart' show PortImpactRow;
import 'package:rackpal_core/src/builder/port_move_to_bank.dart'
    show movableBanks;
import 'package:rackpal_core/src/builder/port_table.dart'
    show portDirectionLabel;
import 'package:rackpal_core/src/builder/quick_add.dart' show uniqueBankKey;
import 'package:rackpal_core/src/commands/command.dart';
import 'package:rackpal_core/src/commands/label_key.dart';
import 'package:rackpal_core/src/commands/rack_commands.dart' show nextOrder;
import 'package:rackpal_core/src/model/template.dart';
import 'package:rackpal_core/src/units/ids.dart';

/// Renames a bank's [BankDef.label] and [BankDef.abbr].
///
/// **`key` IS NOT RENAMEABLE HERE, and that is deliberate.** A bank key is
/// what `PortDef.bankKey` points at, so changing one is the same class of
/// operation as `RenamePortKeyCommand` and would have to rewrite every
/// port naming it. docs/06 §4.6 does not ask for it; a bank's key is
/// internal and its LABEL is the thing a person reads and prints.
final class RenameBankCommand extends Command<TemplateBody> {
  RenameBankCommand(
    this.bankKey, {
    required this.toLabel,
    required this.toAbbr,
  });

  final String bankKey;
  final String toLabel;
  final String toAbbr;

  String? _wasLabel;
  String? _wasAbbr;

  @override
  LabelKey get label => LabelKey.renameBank;

  @override
  EpochMask? get touches => null;

  @override
  Iterable<Uuid> get affects => const <Uuid>[];

  @override
  bool apply(TemplateBody aggregate) {
    final at = aggregate.banks.indexWhere((b) => b.key == bankKey);
    if (at < 0) throw StateError('no bank $bankKey to rename');
    final bank = aggregate.banks[at];
    _wasLabel = bank.label;
    _wasAbbr = bank.abbr;
    bank
      ..label = toLabel
      ..abbr = toAbbr;
    return true;
  }

  @override
  void revert(TemplateBody aggregate) {
    final wasLabel = _wasLabel;
    final wasAbbr = _wasAbbr;
    if (wasLabel == null || wasAbbr == null) {
      throw StateError('revert before apply');
    }
    final at = aggregate.banks.indexWhere((b) => b.key == bankKey);
    if (at < 0) throw StateError('no bank $bankKey to restore');
    aggregate.banks[at]
      ..label = wasLabel
      ..abbr = wasAbbr;
  }
}

/// Removes a bank and un-bands every port that named it. **The ports
/// survive** (CR-055: a bank is presentation) and land in `Not in a bank`.
final class RemoveBankCommand extends Command<TemplateBody> {
  RemoveBankCommand(this.bankKey);

  final String bankKey;

  /// Captured so [revert] restores the bank at its own index rather than
  /// at the end: `banks` is read in list order by the codec, and a byte
  /// round trip that reorders it is a diff nobody asked for (CR-117).
  int? _at;
  BankDef? _removed;

  /// Exactly the ports THIS command un-banded, so a revert cannot re-band
  /// a port that was already loose before it ran.
  final Set<String> _unbanded = <String>{};

  @override
  LabelKey get label => LabelKey.removeBank;

  @override
  EpochMask? get touches => null;

  @override
  Iterable<Uuid> get affects => const <Uuid>[];

  @override
  bool apply(TemplateBody aggregate) {
    final at = aggregate.banks.indexWhere((b) => b.key == bankKey);
    if (at < 0) throw StateError('no bank $bankKey to remove');
    _at = at;
    _removed = aggregate.banks.removeAt(at);
    _unbanded.clear();
    for (final port in aggregate.ports) {
      if (port.bankKey == bankKey) {
        _unbanded.add(port.key.v);
        port.bankKey = null;
      }
    }
    return true;
  }

  @override
  void revert(TemplateBody aggregate) {
    final at = _at;
    final removed = _removed;
    if (at == null || removed == null) throw StateError('revert before apply');
    aggregate.banks.insert(at, removed);
    for (final port in aggregate.ports) {
      if (_unbanded.contains(port.key.v)) port.bankKey = bankKey;
    }
  }
}

/// What a mirror will do, computed before it does it.
///
/// `notFlipped` is DR-085 §11.84.3's clause made visible: the preview
/// NAMES every port whose direction it is leaving alone, because
/// `bidirectional`, `busNode` and `passive` have no opposite and a silent
/// copy would read as a flip that failed.
typedef MirrorBankPlan = ({
  BankDef bank,
  List<PortDef> ports,
  List<PortKey> notFlipped,
});

/// The opposite of [d], or [d] itself where it has none.
///
/// CR-060 gives five directions and only two are opposites. Inventing one
/// for the other three would be a guess made on a port somebody has to
/// wire (DR-085 §11.84.3).
PortDirection mirroredDirection(PortDirection d) => switch (d) {
  PortDirection.source => PortDirection.sink,
  PortDirection.sink => PortDirection.source,
  PortDirection.bidirectional ||
  PortDirection.busNode ||
  PortDirection.passive => d,
};

/// `IN`↔`OUT` swapped in [s], as whole words, or null when neither occurs.
///
/// **WHOLE WORDS, CASE-PRESERVING, AND NULL RATHER THAN A GUESS.** The
/// row's example is a matrix whose banks really are called `IN` and `OUT`;
/// `uniqueBankName` derives most labels from the signal family, so a real
/// bank is `HDMI` and has nothing to swap. Null is the signal that DR-085
/// §11.84.4's other half applies and a person names it.
///
/// Whole words because `LINE OUT` must swap and `ROUTING` must not.
String? swapInOut(String s) {
  final out = s.replaceAllMapped(
    RegExp(r'\b(in|out)\b', caseSensitive: false),
    (m) {
      final w = m[0]!;
      final flipped = w.toLowerCase() == 'in' ? 'out' : 'in';
      // Preserve the case the author typed: IN -> OUT, In -> Out.
      if (w == w.toUpperCase()) return flipped.toUpperCase();
      if (w[0] == w[0].toUpperCase()) {
        return flipped[0].toUpperCase() + flipped.substring(1);
      }
      return flipped;
    },
  );
  return out == s ? null : out;
}

/// Plans DR-085's mirror of [sourceBankKey].
///
/// [label] is what the new bank is called. A caller passes
/// `swapInOut(source.label)` when that is non-null and the name a person
/// typed otherwise; this function does not choose, because choosing is
/// exactly what §11.84.4 gives to the person.
MirrorBankPlan planMirrorBank(
  TemplateBody body, {
  required String sourceBankKey,
  required String label,
  required String abbr,
}) {
  final source = body.banks.firstWhere(
    (b) => b.key == sourceBankKey,
    orElse: () => throw StateError('no bank $sourceBankKey to mirror'),
  );
  final newKey = uniqueBankKey(body, label);
  final bank = BankDef(
    key: newKey,
    label: label,
    abbr: abbr,
    order: nextOrder(body.banks.map((b) => b.order)),
    symbolSide: source.symbolSide,
    collapseInSymbol: source.collapseInSymbol,
  );

  final notFlipped = <PortKey>[];
  final ports = <PortDef>[];
  final taken = {for (final p in body.ports) p.key.v};
  var order = nextOrder(body.ports.map((p) => p.order));

  for (final p in body.ports.where((p) => p.bankKey == sourceBankKey)) {
    final flipped = mirroredDirection(p.direction);
    if (flipped == p.direction) notFlipped.add(p.key);

    // DR-085 §11.84.5: NEW keys under the NEW bank key, through the same
    // generator Quick Add uses. These are new ports, not renamed ones, so
    // nothing writes a `renamedFrom` and CR-051's join is untouched.
    final tail = p.key.v.contains('.')
        ? p.key.v.substring(p.key.v.lastIndexOf('.') + 1)
        : p.key.v;
    var candidate = '$newKey.$tail';
    var n = 2;
    while (taken.contains(candidate)) {
      candidate = '$newKey.$tail.$n';
      n++;
    }
    taken.add(candidate);

    ports.add(
      PortDef(
        key: PortKey(candidate),
        label: swapInOut(p.label) ?? p.label,
        connector: p.connector,
        signalFamily: p.signalFamily,
        direction: flipped,
        bankKey: newKey,
        order: order,
        topology: p.topology,
        maxConnections: p.maxConnections,
        gender: p.gender,
        face: p.face,
        position: p.position,
      ),
    );
    order = nextOrder([order]);
  }

  return (bank: bank, ports: ports, notFlipped: notFlipped);
}

// ═════════════════════════════════════════════════════════════════════
// THE BANK TREE, docs/06 §2's LEFT-RAIL NAVIGATION
// ═════════════════════════════════════════════════════════════════════
// §2: *"The left rail carries the section list plus the bank tree, which
// becomes the primary navigation once you are in the Ports section."* So
// this is a list a person clicks to GET somewhere, and a navigation list
// whose order differs from the thing it navigates is a defect rather than
// a preference.
//
// **THAT IS WHY IT DELEGATES TO `movableBanks` AND DOES NOT SORT BY
// `BankDef.order`.** `buildPortTable` bands by FIRST APPEARANCE over the
// declared port order, so the grid's band order is a fact about the
// ports; `movableBanks` already reproduces it, already appends the
// declared banks that have no band because they have no ports, and
// already names the unbanded band the way the grid's own header does. A
// second list-builder here would be a second opinion about the order, and
// the two would part on the first template where they could.
//
// **`BankDef.order` HAS NO READER IN THE TREE, AND HAD NONE ANYWHERE.**
// Censused at M4-J1: it is allocated by `nextOrder`, encoded by the codec
// and read by nothing that orders anything. The symbol orders pins by
// `PortDef.order` (`symbol_layer.dart`), the grid bands by first
// appearance, and `movableBanks` follows the grid. Making the tree its
// first reader was the tempting move and is the wrong one: it would put
// the navigation out of step with the surface it navigates, in exchange
// for honouring a field no gesture in docs/06 §4.6 can even write.
// Reordering banks is not a §4.6 operation; if one is ever ruled, it gets
// this field and the grid gets a reader with it.

/// One row of docs/06 §2's bank tree.
///
/// `isDeclared` is what separates a bank from a band. Only a row with a
/// `BankDef` behind it can be renamed, removed or mirrored; `Not in a
/// bank` and a `bankKey` naming no definition are places the grid draws
/// and this tree navigates to, and neither is a thing to edit.
typedef BankTreeRow = ({
  String? key,
  String label,
  int portCount,
  bool isDeclared,
});

/// docs/06 §2's bank tree over [body], in the grid's own band order.
List<BankTreeRow> buildBankTree(TemplateBody body) {
  final declared = {for (final bank in body.banks) bank.key};
  return [
    for (final target in movableBanks(body))
      (
        key: target.key,
        label: target.label,
        portCount: target.portCount,
        isDeclared: target.key != null && declared.contains(target.key),
      ),
  ];
}

/// Whether [label] already names a bank of [body], ignoring [exceptKey].
///
/// **A DUPLICATE LABEL IS REFUSED RATHER THAN SUFFIXED, and the two
/// callers differ for a reason.** `uniqueBankName` suffixes because Quick
/// Add derives its label from the signal family and a person who types
/// `16 hdmi in` twice did not choose the name either time. A person typing
/// into the tree's own field DID choose it, and quietly handing back
/// `HDMI 2` would be the product renaming a bank behind them. Worse, the
/// label is what `buildQuickAdd` matches on to decide whether to reuse a
/// bank rather than mint one, so two banks sharing a label make that
/// lookup answer by list position.
///
/// [exceptKey] is the bank being renamed, which is allowed to keep its
/// own name: without it, opening Rename and pressing Enter is a refusal.
bool bankLabelIsTaken(
  TemplateBody body,
  String label, {
  String? exceptKey,
}) {
  final wanted = label.trim().toLowerCase();
  return body.banks.any(
    (bank) => bank.key != exceptKey && bank.label.toLowerCase() == wanted,
  );
}

/// The commands that carry out [plan], bank first.
///
/// **BANK FIRST, AND NO `MirrorBankCommand`.** `buildQuickAdd` settled
/// both halves: a `Transaction` is itself a `Command` holding children, so
/// a batch command would be a second mechanism for a solved problem, and
/// the bank leads because a port naming a bank that does not exist yet is
/// a dangling reference for however long the list takes to apply, while
/// `revert` runs the list backwards.
///
/// The caller runs these inside ONE `transact(LabelKey.mirrorBank, …)`, so
/// a mirrored 16-port bank is one `Ctrl+Z`.
List<Command<TemplateBody>> mirrorBankCommands(MirrorBankPlan plan) => [
  AddBankCommand(plan.bank),
  for (final port in plan.ports) AddPortCommand(port),
];

/// DR-085 §11.84.3's preview: what [plan] does to each port it copies.
///
/// **DERIVED FROM THE PLAN, NOT COMPUTED BESIDE IT.** `port_impact.dart`
/// states the rule this family runs on: *"a preview that is a second
/// implementation of the write is a preview that can lie, and a lying
/// preview is worse than none"*. So `after` is read off the port the
/// command will actually add, and the two cannot disagree.
///
/// The KEY column shows the SOURCE port, because the copies do not exist
/// yet and the key column's job is to be findable in the grid behind the
/// dialog. The note is carried only by the rows a direction is NOT flipped
/// on, which is what makes `portImpactSummary` say *"16 rows matched, 12
/// will change, 4 to check"*: DR-085's clause, in a sentence.
List<PortImpactRow> mirrorBankImpact(
  TemplateBody body,
  MirrorBankPlan plan, {
  required String sourceBankKey,
}) {
  // THE SAME WALK `planMirrorBank` MAKES, so row i describes port i. A
  // different iteration here (declared order, say) would pair a row with
  // a copy of some other port and the list would be confidently wrong.
  final source = [
    for (final port in body.ports)
      if (port.bankKey == sourceBankKey) port,
  ];
  return [
    for (var i = 0; i < source.length && i < plan.ports.length; i++)
      (
        key: source[i].key.v,
        before: portDirectionLabel(source[i].direction),
        after: portDirectionLabel(plan.ports[i].direction),
        note: plan.ports[i].direction == source[i].direction
            ? '${portDirectionLabel(source[i].direction)} has no opposite, '
                  'so the copy keeps it.'
            : null,
      ),
  ];
}
