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
import 'package:rackmate_core/src/builder/quick_add.dart' show uniqueBankKey;
import 'package:rackmate_core/src/commands/command.dart';
import 'package:rackmate_core/src/commands/label_key.dart';
import 'package:rackmate_core/src/commands/rack_commands.dart' show nextOrder;
import 'package:rackmate_core/src/model/template.dart';
import 'package:rackmate_core/src/units/ids.dart';

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
  void apply(TemplateBody aggregate) {
    final at = aggregate.banks.indexWhere((b) => b.key == bankKey);
    if (at < 0) throw StateError('no bank $bankKey to rename');
    final bank = aggregate.banks[at];
    _wasLabel = bank.label;
    _wasAbbr = bank.abbr;
    bank
      ..label = toLabel
      ..abbr = toAbbr;
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
  void apply(TemplateBody aggregate) {
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
