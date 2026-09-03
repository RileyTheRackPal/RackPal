// `SIG-001`'s remedy: `[ Insert HDBaseT receiver ]` (CR-015, DR-115).
//
// ═════════════════════════════════════════════════════════════════════
// A REMEDY CHIP THAT ONLY EXPLAINS HAS NOT REMEDIED
// ═════════════════════════════════════════════════════════════════════
// `#278`'s own words, and `design-ux-schematic.md §2.1`'s: *"Offering the
// remedy is what separates a rule engine from a nag."* Six predicates and
// a chip tell somebody their cable is wrong; this is the file that fixes
// it for them.
//
// ═════════════════════════════════════════════════════════════════════
// ONE LINK, NOT TWO, AND THAT IS DR-115 RATHER THAN A SHORTCUT
// ═════════════════════════════════════════════════════════════════════
// docs/05 §5 used to say the remedy *"creates both links in one undo
// step"*. Measured while building it, the second link cannot exist:
// DR-113 makes `SIG-001` fire on an HDBaseT port meeting a `net.ethernet`
// port that TERMINATES, so the target is an Ethernet jack by
// construction, and the receiver's `HDMI OUT` into that jack fails
// `SIG-002` and `CON-001` together. **The remedy would refuse its own
// second cable**, on the only case the rule has.
//
// So the receiver's HDMI end is left OPEN, which is a state this product
// already has a vocabulary for: AC-018 leaves a home run's far end open
// on purpose, `unlandedHomeRunIds` counts them, the schematic status
// strip reports them, and `LNK-020` is *"a CHECKLIST, NOT A FAILURE"*
// over exactly that. Where the display is, is a fact about the job that
// the product does not have and must not invent.
//
// ═════════════════════════════════════════════════════════════════════
// IT TAKES A `TxnScope` BECAUSE STEP THREE DEPENDS ON STEP TWO
// ═════════════════════════════════════════════════════════════════════
// Three commands, one undo entry: write the receiver's snapshot into the
// document, mint the device, connect the run to it. The third cannot be
// BUILT until the second has applied, because `resolveConnectTarget`
// reads `doc.devices` and `doc.templates` and would return null for a
// device that does not exist yet.
//
// `TxnScope`'s own doc comment names this exact case: *"Commands apply()
// IMMEDIATELY inside add, not at commit, so a later command in the same
// transaction sees the results of an earlier one ('add device, then
// connect to it')."* This is that caller. It is core rather than UI
// because the whole remedy is one testable unit that way, and because
// `TxnScope` is core.

import 'package:rackpal_core/src/catalog/catalog_roles.dart';
import 'package:rackpal_core/src/catalog/seed_catalog.dart';
import 'package:rackpal_core/src/commands/connect_commands.dart';
import 'package:rackpal_core/src/commands/device_commands.dart';
import 'package:rackpal_core/src/commands/split_commands.dart';
import 'package:rackpal_core/src/commands/template_snapshot_commands.dart';
import 'package:rackpal_core/src/derived/connect_rules.dart';
import 'package:rackpal_core/src/derived/connect_target.dart';
import 'package:rackpal_core/src/document_controller.dart';
import 'package:rackpal_core/src/idformat/designator_allocator.dart';
import 'package:rackpal_core/src/model/device_instance.dart';
import 'package:rackpal_core/src/model/placement.dart';
import 'package:rackpal_core/src/model/rack_document.dart';
import 'package:rackpal_core/src/model/template.dart';
import 'package:rackpal_core/src/units/ids.dart';

/// The catalog half this remedy inserts.
///
/// NAMED ONCE, HERE, and reached through `catalog_roles.dart` rather than
/// spelled as a template id: `V06` is the kit and `receiver` is P4's role
/// parameter, so a rename of either is a compile error rather than a
/// silent lookup miss.
const String kHdbasetKitCatalogId = 'V06';

/// What [insertHdbasetReceiver] decided.
sealed class InsertReceiverResult {
  const InsertReceiverResult();
}

/// The remedy ran: a receiver is in the document and the run lands on it.
final class InsertReceiverDone extends InsertReceiverResult {
  const InsertReceiverDone({
    required this.receiverId,
    required this.receiverDesignator,
    required this.landedOn,
  });

  final Uuid receiverId;

  /// What the new device is called, so the caller can say so. `RX-1`.
  final String receiverDesignator;

  /// The receiver port the run now terminates on, for the same reason.
  final String landedOn;
}

/// The remedy could not run, with a sentence naming why.
///
/// EVERY REASON HERE IS A DOCUMENT OR CATALOG FACT rather than a rule
/// verdict, so none of them carries a rule id. Attaching one would claim
/// a catalogue entry that does not exist (CR-021), which is the same
/// distinction `CatalogPlacementFailed.ruleId` draws.
final class InsertReceiverRefused extends InsertReceiverResult {
  const InsertReceiverRefused(this.reason);
  final String reason;
}

/// The port on [body] an HDBaseT run terminates on, or null.
///
/// DERIVED, NOT SPELLED `'hdbt.in'`. The port key is catalog data and the
/// PROPERTY the remedy needs is "a sink on `video.hdbaset`" — which is
/// also exactly what makes the insert work. A hard-coded key would still
/// resolve after somebody renamed the port and would then land the run on
/// nothing.
PortDef? hdbasetInletOf(TemplateBody body) {
  for (final port in body.ports) {
    if (port.signalFamily.v == 'video.hdbaset' &&
        port.direction == PortDirection.sink) {
      return port;
    }
  }
  return null;
}

/// Runs `SIG-001`'s remedy inside [tx]: mints an HDBaseT receiver and
/// lands [from]'s run on it, as ONE undo entry (CR-015, DR-115).
///
/// [from] is the HDBaseT source the user was dragging. The caller is
/// responsible for having a chip on screen that says why, and for
/// wrapping this in a `transact` whose label the Edit menu shows.
///
/// NOTHING IS WRITTEN ON A REFUSAL, and that took two goes to make true.
/// The first draft claimed it in this comment and did not do it: the
/// tier-1 check on the cable ran AFTER the snapshot and the device had
/// already applied, so a full source pin left an orphan receiver wired to
/// nothing — which looks like the user's own mistake. Its own test caught
/// the overclaim.
///
/// Every check that can fail now runs before the first `tx.add`, and the
/// source-occupancy one below is what makes that possible: see its note
/// for why occupancy is the ONLY tier-1 rule reachable here.
InsertReceiverResult insertHdbasetReceiver(
  TxnScope<RackDocument> tx, {
  required RackDocument doc,
  required ConnectTarget from,
  required DateTime now,
  required String actor,
}) {
  final body = resolveTemplateRole(
    buildSeedCatalog(),
    kHdbasetKitCatalogId,
    TemplateRole.receiver,
  );
  if (body == null) {
    return const InsertReceiverRefused(
      'This build has no HDBaseT receiver to insert.',
    );
  }
  final inlet = hdbasetInletOf(body);
  if (inlet == null) {
    return const InsertReceiverRefused(
      'The HDBaseT receiver in this build has no HDBaseT input, so there '
      'is nothing to land the run on.',
    );
  }
  // THE SOURCE END IS CHECKED TOO, and not because the chip could be
  // wrong about it. A remedy is reachable from a chip that was computed
  // one frame earlier, and between those two frames the document can
  // move: `SIG-001` fired on a pin whose template has since been forked.
  // Landing an HDMI run on an HDBaseT inlet because nobody looked would
  // be the remedy creating the defect it exists to remove.
  if (from.def.signalFamily.v != 'video.hdbaset') {
    return const InsertReceiverRefused(
      'That port does not carry HDBaseT, so a receiver would not help it.',
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // TIER 1, ASKED BEFORE ANYTHING IS MINTED, AND OCCUPANCY IS ALL OF IT
  // ═══════════════════════════════════════════════════════════════════
  // The cable cannot be planned yet: `buildSplitConnectCommands` needs a
  // `ConnectTarget` for a device that does not exist until two commands
  // below have applied. So the tier-1 question has to be asked about the
  // half that DOES exist, and the argument that this is sufficient is
  // worth stating rather than assuming.
  //
  // `evaluateConnect` is TOP-001..005. Against a receiver one frame old:
  // self-connection cannot happen (the target is a different device),
  // a duplicate ordered pair cannot happen (it has no links), a container
  // cycle cannot happen (it contains nothing), and a dangling endpoint
  // cannot happen (both ends resolve by construction). `maxConnections`
  // on the TARGET cannot fire either, because every port on a device
  // minted this instant is empty.
  //
  // That leaves `maxConnections` on the SOURCE, which is `TOP-003` and is
  // exactly what `isPortFull` answers. It is reachable in ordinary use: a
  // chip is computed one frame before the button is pressed, and another
  // view can fill that jack in between.
  if (isPortFull(doc, from)) {
    return InsertReceiverRefused(
      'TOP-003 — ${from.citation} already carries a cable, so there is '
      'nothing to route into a receiver.',
    );
  }

  final templateId = TemplateId(
    roleVariantTemplateId(kHdbasetKitCatalogId, TemplateRole.receiver),
  );
  final version = nextTemplateVersion(doc, templateId);
  final snapshot = TemplateSnapshot(
    templateId: templateId,
    version: version,
    // The same shape `catalogTemplateKey`'s seeds use. A snapshot's hash
    // is a warning-level check and never a load failure (AC-042), so a
    // derived half naming its origin is more use to a person diffing two
    // files than an opaque digest would be.
    contentHash: 'sha256:seed-${templateId.v}',
    body: body,
    capturedAt: now,
  );

  final designator = allocateDeviceDesignator(
    settings: doc.settings,
    // `?? catalogId` IS THE PLACEMENT PATH'S OWN FALLBACK, kept so a
    // remedy-placed device and a palette-placed one allocate the same
    // way. This body states `RX`, so the fallback is unreachable today
    // and is here because a divergence between the two paths would show
    // up as two devices with different designator schemes in one project.
    typePrefix: body.typePrefix ?? kHdbasetKitCatalogId,
    usedDesignators: {for (final d in doc.devices.values) d.designator},
  );

  final add = AddDeviceCommand(
    // `offRackPassive` IS WRONG FOR THIS DEVICE and `rackDevice` is
    // wronger. A receiver is powered (over the link) and it is not in the
    // rack, which is the pair `notInRack` templates land on elsewhere in
    // this file's neighbours — see `_kindFor`, which reads the body
    // rather than the id for exactly this reason.
    kind: DeviceKind.offRackPassive,
    templateRef: TemplateRef(
      templateId: snapshot.templateId,
      version: snapshot.version,
      contentHash: snapshot.contentHash,
    ),
    designator: designator,
    name: body.displayName,
    // §540: the receiver lives at the display end of the run.
    placement: const OffRackPlacement(),
    now: now,
    actor: actor,
  );

  // ═══════════════════════════════════════════════════════════════════
  // FROM HERE THE DOCUMENT MOVES, AND THE ORDER IS THE DEPENDENCY
  // ═══════════════════════════════════════════════════════════════════
  // The snapshot first, because `AddDeviceCommand` never writes
  // `doc.templates` (its own revert comment says so) and a device whose
  // `TemplateRef` resolves to nothing draws as an unknown body. Then the
  // device, because the connect below resolves through `doc.devices`.
  tx
    ..add(
      SaveTemplateToProjectCommand(
        templateId: snapshot.templateId,
        version: snapshot.version,
        contentHash: snapshot.contentHash,
        body: snapshot.body,
        capturedAt: now,
      ),
    )
    ..add(add);

  final to = resolveConnectTarget(
    doc,
    deviceId: add.id,
    portKey: inlet.key.v,
  );
  if (to == null) {
    // UNREACHABLE BY CONSTRUCTION and reported rather than asserted: the
    // two commands above put both halves in place, so a null here means
    // one of them silently did not apply. A remedy that returned success
    // with no cable would be the worst of the three outcomes.
    return const InsertReceiverRefused(
      'The receiver was placed but its HDBaseT input did not resolve, so '
      'no cable was made.',
    );
  }

  // THE SAME BUILDER THE GESTURE USES, not a second way to make a cable.
  // `buildSplitConnectCommands` returns a plain connect when there are no
  // splits to plan, which is always true here: the receiver is one frame
  // old and nothing is wired to it.
  final built = buildSplitConnectCommands(
    doc: doc,
    from: from,
    to: to,
    media: kUnstatedMedia,
    now: now,
    actor: actor,
  );
  switch (built) {
    case SplitConnectRefused(:final ruleId, :final message):
      // UNREACHABLE GIVEN THE OCCUPANCY CHECK ABOVE, and reported rather
      // than asserted for the same reason the null target is: if a
      // tier-1 rule ever refuses here, a receiver has already been
      // minted and the sentence is the only thing that can say so. An
      // `assert` would be silent in release, which is where it matters.
      return InsertReceiverRefused('$ruleId — $message');
    case SplitConnectReady(:final connect):
      tx.add(connect);
      return InsertReceiverDone(
        receiverId: add.id,
        receiverDesignator: designator,
        landedOn: inlet.label,
      );
  }
}
