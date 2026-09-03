// The three tier-1 placement rules, evaluated for ONE prospective
// placement (`#268`, `#269`, `#270`, M5-C, docs/02 §5.1 `PLC-001..003`).
//
// ═════════════════════════════════════════════════════════════════════
// THESE REFUSE, AND UNTIL NOW THEY DID NOT EXIST AT ALL
// ═════════════════════════════════════════════════════════════════════
// `PLC-001..003` were ratified as distinct tier-1 rules by canon §12.6(b),
// because CR-017 already rules their conditions model-illegal and *"an
// unnumbered blocking rule can carry neither a `Finding.ruleId` nor an
// AC-051 fixture pair"*. A census at the start of M5 then found the string
// `PLC-00` in no Dart file in this repository. This is the predicate half
// of that ratification; `rule_catalogue.dart` has carried the rows since
// M5-A2.
//
// `connect_rules.dart` IS THE SHAPE, deliberately. Same sealed verdict,
// same rule enum carrying the canonical id, same contract that every
// refusal is a complete sentence about THIS document rather than a code.
// Two files that refuse for the same reason at the same tier should not
// need two readings.
//
// ═════════════════════════════════════════════════════════════════════
// WHAT THIS FILE DOES NOT CHECK, AND DR-112 IS WHY
// ═════════════════════════════════════════════════════════════════════
// OCCUPANCY. Two devices in one U on one face is refused by
// `findBlockingOccupant` and reported by `RCK-001` at tier 3, and it is
// deliberately not a rule here. DR-112 §11.111.4: no `Command` refuses on
// it, so it is not tier 1 by canon's own definition of the tier, and an
// overlap does not make the document MEAN NOTHING the way a conductor
// from a port to itself does.
//
// The same ruling settles what looks like a duplication and is not:
// `PLC-001`'s extent half and `RCK-002` are the same condition at two
// different MOMENTS. Tier 1 stops a person creating the state by
// dragging; tier 3 reports it however it arrived, by import, by a
// hand-edited file, or by a rack shrunk under a device.
//
// A `RailPlacement` NAMING A RACK THAT IS NOT IN THE DOCUMENT is the
// third thing absent here, and its absence is CR-021 rather than an
// oversight. It is genuinely model-illegal, it is genuinely not in
// docs/02 §5's catalogue, and *"a rule not listed there does not exist"*.
// Inventing a refusal for it would be a twenty-ninth rule arriving
// through a code review instead of a ruling. So an unresolvable rack
// makes `PLC-001` and `PLC-003` UNEVALUATABLE and they are silent (G4),
// which is the same answer `CODE-002` gives to a jacket listing it cannot
// read.
import 'package:meta/meta.dart';
import 'package:rackpal_core/src/derived/device_loads.dart' show occupancyU;
import 'package:rackpal_core/src/model/placement.dart';
import 'package:rackpal_core/src/model/rack.dart';
import 'package:rackpal_core/src/model/rack_document.dart';
import 'package:rackpal_core/src/model/template.dart' show TemplateBody;
import 'package:rackpal_core/src/model/zero_u_channel.dart';
import 'package:rackpal_core/src/units/constants.dart';
import 'package:rackpal_core/src/units/len.dart';

/// The three model-level illegality rules a placement gesture can meet,
/// IN EVALUATION ORDER.
///
/// ═══════════════════════════════════════════════════════════════════════
/// THE ORDER'S RATIONALE IS NOT `connect_rules.dart`'s, AND SAYING SO IS
/// THE POINT
/// ═══════════════════════════════════════════════════════════════════════
/// There the order is outside-in by DEPENDENCY: `TOP-004` runs first
/// because every later rule reads a fact off a pin that has to exist. Here
/// there is no such dependency. [ruWithinRack] and [lateralWithinBounds]
/// are independent questions about different axes, and either can fail
/// while the other is fine.
///
/// So the order is by WHAT THE PERSON IS LIKELY TO HAVE DONE. A device at
/// U 99 of a 12U rack is something somebody just did with their hands. A
/// `spanTwelfths` of 13 is not: CR-030 gives the v1 editor three fixed
/// positions, `Full (0,12)`, `Left half (0,6)` and `Right half (6,6)`, so
/// a malformed lateral span arrives from an import, a hand-edited file or
/// a caller with a bug. Reporting the second when both are wrong would
/// name the thing the person did not do.
enum PlacementRule {
  /// `PLC-001` for a [RailPlacement]: the RU is inside the rack and the
  /// device fits the extent from there.
  ruWithinRack('PLC-001'),

  /// `PLC-002` for a [RailPlacement]: `startTwelfth` in `[0,11]`,
  /// `spanTwelfths` in `[1,12]`, and their sum at most 12 (CR-030).
  lateralWithinBounds('PLC-002'),

  /// `PLC-003` for a [ZeroUPlacement]: the channel resolves in the rack
  /// and the offset lands inside it (CR-031).
  zeroUChannelResolves('PLC-003');

  const PlacementRule(this.id);

  /// The canonical rule id, e.g. `"PLC-001"`. Joins to `RuleMeta` and is
  /// what `Finding.ruleId` would carry if this tier filed findings, which
  /// it does not.
  final String id;
}

/// What [evaluatePlacement] decided. Sealed on `ConnectVerdict`'s
/// precedent and for its stated reason: a caller must handle both arms,
/// so there is no `isAllowed` boolean to check and forget.
@immutable
sealed class PlacementVerdict {
  const PlacementVerdict();
}

/// No tier-1 placement rule objects. Says nothing about occupancy, which
/// is `findBlockingOccupant`'s question and `RCK-001`'s finding (DR-112),
/// and nothing about tiers 2 and 3.
@immutable
final class PlacementAllowed extends PlacementVerdict {
  const PlacementAllowed();
}

/// A tier-1 refusal: the rule that fired and a sentence naming the actual
/// rack and RU involved.
@immutable
final class PlacementRefused extends PlacementVerdict {
  const PlacementRefused(this.rule, this.message);

  final PlacementRule rule;

  /// A COMPLETE SENTENCE about THIS document, ending in a full stop, on
  /// `ConnectRefused`'s contract: *"AMP-1 cannot sit at U 40: RK-1 is 12
  /// U."* Never a generic string, because the next thing the person does
  /// depends on which bound they crossed.
  final String message;

  /// `"PLC-001"`.
  String get ruleId => rule.id;

  @override
  String toString() => '$ruleId: $message';
}

/// Whether [placement] is model-legal in [doc].
///
/// [body] is the template body of the device being placed, used only for
/// its height on the placed face. It is NULLABLE and null is UNKNOWN
/// rather than zero (G4): a device whose snapshot does not resolve has no
/// knowable height, so the extent half of `PLC-001` is skipped and the
/// bounds half still runs. Refusing on an unknown height would make a
/// placement illegal because of a missing template rather than because of
/// where it is.
///
/// [designator] is what the sentence calls the device. Empty is legal and
/// reads as "the device", because a catalog drop refuses BEFORE a
/// designator is allocated.
PlacementVerdict evaluatePlacement({
  required RackDocument doc,
  required Placement placement,
  TemplateBody? body,
  String designator = '',
}) {
  final what = designator.isEmpty ? 'The device' : designator;
  return switch (placement) {
    RailPlacement() => _evaluateRail(doc, placement, body, what),
    ZeroUPlacement() => _evaluateZeroU(doc, placement, what),
    // No `PLC` rule reaches these. A shelf placement's coherence is
    // `TOP-005`'s (`connect_rules.dart`), and an off-rack or staged
    // device is in no rack to be out of bounds of.
    ShelfPlacement() ||
    OffRackPlacement() ||
    StagedPlacement() => const PlacementAllowed(),
  };
}

PlacementVerdict _evaluateRail(
  RackDocument doc,
  RailPlacement placement,
  TemplateBody? body,
  String what,
) {
  final rack = doc.racks[placement.rackId];
  // PLC-001, and only when there is a rack to be inside of. See the file
  // header on why an unresolvable rack is silence and not a refusal.
  if (rack != null) {
    final refusal = _railWithinRack(rack, placement, body, what);
    if (refusal != null) return refusal;
  }
  // PLC-002 reads nothing but the placement, so it runs either way. A
  // lateral span that does not fit in a 1U opening is incoherent whether
  // or not the rack it names is in the document.
  final lateral = _lateralWithinBounds(placement, what);
  if (lateral != null) return lateral;
  return const PlacementAllowed();
}

PlacementRefused? _railWithinRack(
  Rack rack,
  RailPlacement placement,
  TemplateBody? body,
  String what,
) {
  final ru = placement.ruIndex;
  if (ru < 1 || ru > rack.heightU) {
    return PlacementRefused(
      PlacementRule.ruWithinRack,
      '$what cannot sit at U $ru: ${rack.designator} is '
      '${rack.heightU} U, numbered 1 to ${rack.heightU} from the bottom.',
    );
  }
  // THE EXTENT HALF, and it is skipped rather than failed when the height
  // is unknown (G4). `occupancyU` returns null for a body that does not
  // resolve and for one that occupies zero U on this face.
  final heightU = occupancyU(body, placement.face);
  if (heightU == null) return null;
  final topU = ru + heightU - 1;
  if (topU > rack.heightU) {
    return PlacementRefused(
      PlacementRule.ruWithinRack,
      '$what is $heightU U and would reach U $topU from U $ru, past the '
      'top of ${rack.designator} at U ${rack.heightU}.',
    );
  }
  return null;
}

PlacementRefused? _lateralWithinBounds(RailPlacement placement, String what) {
  final start = placement.startTwelfth;
  final span = placement.spanTwelfths;
  // ONE RULE, THREE BOUNDS, ONE SENTENCE EACH. CR-030 writes them as one
  // rule and `PLC-002` is one row in the catalogue, so they share a rule
  // id; they do not share a message, because "starts outside the opening"
  // and "is wider than the opening" send a reader to different fields.
  if (start < 0 || start > 11) {
    return PlacementRefused(
      PlacementRule.lateralWithinBounds,
      '$what starts at twelfth $start of the rack opening, which is '
      'divided into twelfths 0 to 11.',
    );
  }
  if (span < 1 || span > 12) {
    return PlacementRefused(
      PlacementRule.lateralWithinBounds,
      '$what is $span twelfths wide, and a device occupies between 1 and '
      '12 twelfths of the opening.',
    );
  }
  if (start + span > 12) {
    return PlacementRefused(
      PlacementRule.lateralWithinBounds,
      '$what is $span twelfths wide starting at twelfth $start, which '
      'runs ${start + span - 12} twelfths past the right-hand rail.',
    );
  }
  return null;
}

PlacementVerdict _evaluateZeroU(
  RackDocument doc,
  ZeroUPlacement placement,
  String what,
) {
  final rack = doc.racks[placement.rackId];
  if (rack == null) return const PlacementAllowed();

  ZeroUChannel? channel;
  for (final c in rack.zeroUChannels) {
    if (c.id == placement.channelId) {
      channel = c;
      break;
    }
  }
  if (channel == null) {
    return PlacementRefused(
      PlacementRule.zeroUChannelResolves,
      '$what names 0U channel "${placement.channelId}", which '
      '${rack.designator} does not have.',
    );
  }

  // THE CHANNEL'S LENGTH IS DERIVED FROM ITS U SPAN, INCLUSIVE. A channel
  // from U 1 to U 42 is 42 U of rail, not 41: `endU` is the last U the
  // channel covers, not the U after it.
  final channelLength = kRackUnit * (channel.endU - channel.startU + 1);
  final offset = placement.offsetFromChannelStart;
  if (offset.nm < 0 || offset.nm > channelLength.nm) {
    return PlacementRefused(
      PlacementRule.zeroUChannelResolves,
      '$what sits ${_mm(offset)} along 0U channel '
      '"${placement.channelId}", which is ${_mm(channelLength)} long.',
    );
  }
  return const PlacementAllowed();
}

/// Millimetres, for a sentence a person reads. INTEGER DIVISION, not a
/// double: CR-001 bans floating-point millimetres in the model and in
/// every file format, and a message is not either of those, but a
/// rounding rule invented here would still be the second one in the
/// codebase. `unit_formatter.dart` owns display formatting; this is a
/// refusal string, which is deliberately coarse.
String _mm(Len len) => '${len.nm ~/ Len.nmPerMillimetre} mm';
