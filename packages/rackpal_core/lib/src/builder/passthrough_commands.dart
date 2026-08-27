// `Pair front↔rear by order` and the `PAIRED WITH` cell, docs/06 §4.6 and
// §4.7. Board `#181` / `#225` (M4-J3), DR-087 §11.86, CR-057.
//
// ═══════════════════════════════════════════════════════════════════════
// THE ACTION IS ADDITIVE AND IDEMPOTENT
// ═══════════════════════════════════════════════════════════════════════
// It pairs every UNPAIRED front port to every UNPAIRED rear port and
// leaves existing pairs alone, which is DR-087 §11.86.2. Replacing every
// pair is the simpler rule and was declined: one press over a panel where
// somebody corrected a crossed pair by hand puts the crossing back, and
// the undo entry is twenty-four pairs deep. Pairing only the unpaired also
// means the action can be pressed again after eight more ports are added
// and touches only the eight.
//
// ═══════════════════════════════════════════════════════════════════════
// THE OPTIONS DO THE VALIDATING, WHICH IS WHY THERE IS NONE
// ═══════════════════════════════════════════════════════════════════════
// [passthroughPartners] offers only ports on the OTHER face that are not
// already paired. A front-to-front pair and a double-booked port are
// therefore states this product cannot mint rather than states it flags
// afterwards, which is AC-030's temperament (a polarity inversion is
// INEXPRESSIBLE) applied one type over.
//
// ═══════════════════════════════════════════════════════════════════════
// `sameNet` IS ALWAYS `true` AND HAS NO READER (DR-087 §11.86.5)
// ═══════════════════════════════════════════════════════════════════════
// A front jack and the punchdown behind it are one electrical path; that
// is what passthrough means and what all 24 seeded pairs say. Nothing in
// the product reads the field: not a trace, not a schedule, not a rule,
// and `wire_trace.dart` does not mention passthrough at all. So no control
// is built for it, because a switch whose only observable effect is a byte
// in a file is the `UnbuiltView` defect wearing a different hat. It is
// kept rather than removed because deleting it moves N03's bytes and
// breaks CR-117's round trip.
import 'package:rackpal_core/src/commands/command.dart';
import 'package:rackpal_core/src/commands/label_key.dart';
import 'package:rackpal_core/src/model/placement.dart' show Face;
import 'package:rackpal_core/src/model/template.dart';
import 'package:rackpal_core/src/units/ids.dart';

/// What [PassthroughPairDef.sameNet] is written as, always (§11.86.5).
const bool kPassthroughSameNet = true;

/// Appends one passthrough pair.
final class AddPassthroughPairCommand extends Command<TemplateBody> {
  const AddPassthroughPairCommand(this.pair);

  final PassthroughPairDef pair;

  @override
  LabelKey get label => LabelKey.pairPassthrough;

  @override
  EpochMask? get touches => null;

  @override
  Iterable<Uuid> get affects => const <Uuid>[];

  @override
  void apply(TemplateBody aggregate) => aggregate.passthroughPairs.add(pair);

  @override
  void revert(TemplateBody aggregate) {
    final at = aggregate.passthroughPairs.indexWhere(
      (p) => p.frontKey.v == pair.frontKey.v && p.rearKey.v == pair.rearKey.v,
    );
    if (at < 0) throw StateError('no pair ${pair.frontKey.v} to remove');
    aggregate.passthroughPairs.removeAt(at);
  }
}

/// Removes the pair naming [portKey], on either end.
///
/// TAKES EITHER END, because the cell a person clears is one row and the
/// pair does not say which of its two keys that row is. `RemovePortCommand`
/// removes pairs the same way, one type over.
final class RemovePassthroughPairCommand extends Command<TemplateBody> {
  RemovePassthroughPairCommand(this.portKey);

  final PortKey portKey;

  /// Captured so [revert] restores it at its own index: `passthroughPairs`
  /// is read in list order by the codec, and a byte round trip that
  /// reorders it is a diff nobody asked for (CR-117).
  int? _at;
  PassthroughPairDef? _removed;

  @override
  LabelKey get label => LabelKey.unpairPassthrough;

  @override
  EpochMask? get touches => null;

  @override
  Iterable<Uuid> get affects => const <Uuid>[];

  @override
  void apply(TemplateBody aggregate) {
    final at = aggregate.passthroughPairs.indexWhere(
      (p) => p.frontKey.v == portKey.v || p.rearKey.v == portKey.v,
    );
    if (at < 0) throw StateError('no pair naming ${portKey.v}');
    _at = at;
    _removed = aggregate.passthroughPairs.removeAt(at);
  }

  @override
  void revert(TemplateBody aggregate) {
    final at = _at;
    final removed = _removed;
    if (at == null || removed == null) throw StateError('revert before apply');
    aggregate.passthroughPairs.insert(at, removed);
  }
}

/// The port [portKey] is paired with, or null.
PortKey? passthroughPartnerOf(TemplateBody body, PortKey portKey) {
  for (final pair in body.passthroughPairs) {
    if (pair.frontKey.v == portKey.v) return pair.rearKey;
    if (pair.rearKey.v == portKey.v) return pair.frontKey;
  }
  return null;
}

/// Every port [portKey] may be paired with, in declared order.
///
/// **THE OTHER FACE, AND UNPAIRED.** See the file header: this list is the
/// validation. [portKey]'s own current partner is included, so opening the
/// picker on a paired row shows what it is paired with rather than an
/// empty box.
List<PortDef> passthroughPartners(TemplateBody body, PortKey portKey) {
  final port = body.ports.where((p) => p.key.v == portKey.v).firstOrNull;
  if (port == null) return const [];
  final partner = passthroughPartnerOf(body, portKey);
  final paired = <String>{
    for (final pair in body.passthroughPairs) ...{
      pair.frontKey.v,
      pair.rearKey.v,
    },
  };
  return [
    for (final other in portsInDeclaredOrder(body.ports))
      if (other.face != port.face &&
          (!paired.contains(other.key.v) || other.key.v == partner?.v))
        other,
  ];
}

/// The commands that pair [portKey] with [partnerKey], or unpair it when
/// [partnerKey] is null.
///
/// **THE OLD PAIR GOES FIRST.** A port may hold one pair at most, so
/// re-pairing is a remove and an add, and running the add first would put
/// two pairs on one port for however long the list takes to apply.
List<Command<TemplateBody>> buildSetPassthroughPartner({
  required TemplateBody body,
  required PortKey portKey,
  required PortKey? partnerKey,
}) {
  final existing = passthroughPartnerOf(body, portKey);
  if (existing?.v == partnerKey?.v) return const [];

  final commands = <Command<TemplateBody>>[
    if (existing != null) RemovePassthroughPairCommand(portKey),
  ];
  if (partnerKey == null) return commands;

  final port = body.ports.where((p) => p.key.v == portKey.v).firstOrNull;
  if (port == null) return const [];
  // THE FACE DECIDES WHICH KEY IS WHICH, not the order of the arguments.
  // `PassthroughPairDef` names its ends `frontKey` and `rearKey`, and a
  // pair written the wrong way round reads as a rear jack on the front of
  // the panel everywhere it is printed.
  final isFront = port.face == Face.front;
  commands.add(
    AddPassthroughPairCommand(
      PassthroughPairDef(
        frontKey: isFront ? portKey : partnerKey,
        rearKey: isFront ? partnerKey : portKey,
        sameNet: kPassthroughSameNet,
      ),
    ),
  );
  return commands;
}

/// Why `Pair front↔rear by order` produced nothing.
enum PairByOrderRefusal {
  /// The template is not a passthrough. The action's button is hidden
  /// there, so this is the belt to that surface's braces.
  notAPassthrough,

  /// A sort badge is showing. The action writes no `order` and READS one:
  /// pairs go on in DECLARED order, so under a badge the person is looking
  /// at a different order from the one the pairs will follow.
  theViewIsSorted,

  /// One of the two faces has no unpaired port left, so there is nothing
  /// to pair. Not an error: on a fully paired panel it is what the person
  /// asked for, already true.
  nothingToPair,
}

/// One line of prose per refusal.
String pairByOrderRefusalMessage(PairByOrderRefusal refusal) =>
    switch (refusal) {
      PairByOrderRefusal.notAPassthrough =>
        'This template is not a passthrough. Turn on Passthrough on the '
            'Physical section first.',
      PairByOrderRefusal.theViewIsSorted =>
        'The grid is sorted. Ports pair in the declared order, not the '
            'order on screen, so clear the sort or commit it first.',
      PairByOrderRefusal.nothingToPair =>
        'Nothing left to pair: one of the two faces has no unpaired port.',
    };

/// What a pair-by-order produced.
final class PairByOrderResult {
  const PairByOrderResult.planned({
    required this.commands,
    required this.leftOverFront,
    required this.leftOverRear,
  }) : refusal = null;

  const PairByOrderResult.refused(PairByOrderRefusal this.refusal)
    : commands = const [],
      leftOverFront = 0,
      leftOverRear = 0;

  final List<Command<TemplateBody>> commands;

  /// Ports on each face this run could not pair, because the other face
  /// ran out first.
  ///
  /// **REPORTED RATHER THAN HIDDEN, and this is the LIU's case.** N04 has
  /// twelve duplex LC adapters over twenty-four splices, so a run over it
  /// pairs twelve and leaves twelve rear ports over. DR-087 §11.86.4 rules
  /// that the twelve pairs it WOULD write are half-true and the panel
  /// stays unpaired instead; a person who runs this anyway is told what it
  /// did rather than left counting rows.
  final int leftOverFront;
  final int leftOverRear;

  final PairByOrderRefusal? refusal;

  bool get isRefused => refusal != null;

  int get pairsAdded => commands.length;
}

/// What a completed run has to say for itself.
String pairByOrderOutcome(PairByOrderResult result) {
  final pairs = result.pairsAdded;
  final head = pairs == 1 ? 'Paired 1 port.' : 'Paired $pairs ports.';
  final over = result.leftOverFront + result.leftOverRear;
  if (over == 0) return head;
  final face = result.leftOverFront > 0 ? 'front' : 'rear';
  return over == 1
      ? '$head One $face port had no partner left.'
      : '$head $over $face ports had no partner left.';
}

/// `Pair front↔rear by order` (DR-087 §11.86.2).
PairByOrderResult buildPairFrontToRearByOrder({
  required TemplateBody body,
  bool viewIsSorted = false,
}) {
  if (!body.isPassthrough) {
    return const PairByOrderResult.refused(PairByOrderRefusal.notAPassthrough);
  }
  if (viewIsSorted) {
    return const PairByOrderResult.refused(PairByOrderRefusal.theViewIsSorted);
  }

  final paired = <String>{
    for (final pair in body.passthroughPairs) ...{
      pair.frontKey.v,
      pair.rearKey.v,
    },
  };
  final declared = portsInDeclaredOrder(body.ports);
  final fronts = [
    for (final port in declared)
      if (port.face == Face.front && !paired.contains(port.key.v)) port,
  ];
  final rears = [
    for (final port in declared)
      if (port.face == Face.rear && !paired.contains(port.key.v)) port,
  ];
  if (fronts.isEmpty || rears.isEmpty) {
    return const PairByOrderResult.refused(PairByOrderRefusal.nothingToPair);
  }

  final n = fronts.length < rears.length ? fronts.length : rears.length;
  return PairByOrderResult.planned(
    commands: [
      for (var i = 0; i < n; i++)
        AddPassthroughPairCommand(
          PassthroughPairDef(
            frontKey: fronts[i].key,
            rearKey: rears[i].key,
            sameNet: kPassthroughSameNet,
          ),
        ),
    ],
    leftOverFront: fronts.length - n,
    leftOverRear: rears.length - n,
  );
}
