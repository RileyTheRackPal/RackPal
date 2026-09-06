// `SIG-002`'s remedy: `[ Insert a converter ]` (CR-015, DR-128 §11.127.3).
//
// ═════════════════════════════════════════════════════════════════════
// A DEVICE, NOT A VALUE, AND CR-015 CHOSE THAT
// ═════════════════════════════════════════════════════════════════════
// CR-015's test is mechanical: *does an installer pull two separate
// cables to it?* `CON-001` is "the plug does not fit the jack", answered
// by a barrel, and that is an `InlineAdapter` value in
// `declare_adapter.dart`. `SIG-002` is "the sink does not accept this
// family", answered by ELECTRONICS: HDMI to composite, SDI to HDMI, a
// balun. Two cables, so a real `DeviceInstance` with
// `mountMethod: notInRack`, exactly as CR-015 says of the `SIG-001`
// remedy.
//
// ═════════════════════════════════════════════════════════════════════
// MINTED FROM THE TWO PINS, NOT SHIPPED, AND THE CATALOGUE DOES NOT GROW
// ═════════════════════════════════════════════════════════════════════
// DR-128 §11.127.4. Censused before the work: the catalogue holds no
// generic converter, only the HDBaseT extender pair and a presentation
// scaler.
//
// A seeded `Signal Converter` archetype was rejected because A
// CONVERTER'S PORTS CANNOT BE RIGHT IN GENERAL: the families it bridges
// vary per use, so it would ship with unknown-family ports or a P4
// variant axis, which is a great deal of machinery for a box whose entire
// purpose is to be specific. A palette filtered to devices bridging the
// two families was rejected on measurement: that filter returns almost
// nothing today, and an empty picker behind a remedy button is worse than
// no button.
//
// So the body is authored HERE from the pins the remedy was invoked on.
// CR-061's shipped-template count does not move, because this template is
// written into the PROJECT (DR-123's path) and was never in the
// catalogue. (The count itself moved to 50 in the same ruling, for
// `PWR-003`'s power strip, which IS a catalogue row. The two remedies
// went opposite ways on purpose: a converter is specific to its two pins
// and a power strip is the same object on every job.)
//
// ═════════════════════════════════════════════════════════════════════
// IT CLEARS BOTH RULES ON BOTH NEW CABLES BY CONSTRUCTION
// ═════════════════════════════════════════════════════════════════════
// The input port takes the SOURCE's family and connector; the output port
// takes the SINK's. So `from -> converter.in` agrees on family (so
// `SIG-002` is silent) and on connector (so `CON-001` is silent), and
// `converter.out -> to` does the same at the other end. That is a
// property of the construction rather than of a rule being suppressed,
// which is why the tests assert the rules going quiet rather than the
// ports existing.
//
// ═════════════════════════════════════════════════════════════════════
// IT STATES NO WATTAGE AND NO MODEL
// ═════════════════════════════════════════════════════════════════════
// G4, and DR-120's `F19` is the precedent: a row that cannot cite a
// source states nothing rather than guessing. The BOM line is uncosted
// and says so, which is a fact about the job the product does not have.
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

/// The designator prefix a minted converter allocates under.
const String kConverterTypePrefix = 'CONV';

/// The two port keys a minted converter carries.
const String kConverterInKey = 'in';
const String kConverterOutKey = 'out';

/// What [insertSignalConverter] decided.
sealed class InsertConverterResult {
  const InsertConverterResult();
}

/// The converter is in, with a cable on each side.
final class InsertConverterDone extends InsertConverterResult {
  const InsertConverterDone({
    required this.converterId,
    required this.designator,
    required this.displayName,
  });

  final Uuid converterId;
  final String designator;
  final String displayName;
}

/// Why nothing was minted, in words for a person.
final class InsertConverterRefused extends InsertConverterResult {
  const InsertConverterRefused(this.message);

  final String message;
}

/// A template id built from the two families, so the same conversion
/// asked for twice reuses one body rather than minting a second.
///
/// DETERMINISTIC ON PURPOSE. The repository's determinism invariant is
/// "same document, same display list, same exported bytes", and a
/// template id containing a UUID would make two documents that a person
/// built identically differ on disk. Sorting is not needed because
/// direction is part of the meaning: HDMI-to-composite and
/// composite-to-HDMI are different boxes.
String converterTemplateId(SignalFamilyId from, SignalFamilyId to) =>
    'conv.${_slug(from.v)}-to-${_slug(to.v)}';

String _slug(String familyId) => familyId.replaceAll('.', '_');

/// Mints a converter between [from] and [to], places it, and lands a
/// cable on each side, all in one undo entry.
///
/// Takes a [TxnScope] for `insert_receiver.dart`'s reason, stated in that
/// file: a later command in the same transaction has to see the results
/// of an earlier one, because `resolveConnectTarget` reads `doc.devices`
/// and would answer null for a device that does not exist yet.
InsertConverterResult insertSignalConverter(
  TxnScope<RackDocument> tx, {
  required RackDocument doc,
  required ConnectTarget from,
  required ConnectTarget to,
  required DateTime now,
  required String actor,
}) {
  // ═══════════════════════════════════════════════════════════════════
  // THE PINS ARE RE-READ, ON `insert_receiver.dart`'s ARGUMENT
  // ═══════════════════════════════════════════════════════════════════
  // "A remedy is reachable from a chip that was computed one frame
  // earlier, and between those two frames the document can move."
  if (from.def.direction != PortDirection.source ||
      to.def.direction != PortDirection.sink) {
    return const InsertConverterRefused(
      'A converter needs an output on one side and an input on the '
      'other, and these two are not that pair.',
    );
  }
  final fromFamily = from.def.signalFamily;
  final toFamily = to.def.signalFamily;
  if (fromFamily == toFamily) {
    return InsertConverterRefused(
      '${from.citation} and ${to.citation} both carry ${fromFamily.v}, so '
      'there is nothing to convert.',
    );
  }
  // THE SINK MAY HAVE LEARNED TO ACCEPT IT IN BETWEEN. `acceptsFamily`
  // is the same question `SIG-002` asks, and a port override or a
  // template fork can widen it after the chip was drawn. Minting a
  // converter for a cable that now plugs straight in would be the remedy
  // creating the defect it exists to remove.
  if (to.acceptsFamily(fromFamily)) {
    return InsertConverterRefused(
      '${to.citation} already accepts ${fromFamily.v}, so a converter '
      'would sit between two ends that already agree.',
    );
  }
  // TIER 1, ASKED BEFORE ANYTHING IS MINTED. `insert_receiver.dart`
  // reasons this out in full: against a device one frame old only
  // `TOP-003` on the EXISTING pins is reachable, and here both are
  // existing pins, so both are asked.
  if (isPortFull(doc, from)) {
    return InsertConverterRefused(
      'TOP-003 — ${from.citation} already carries a cable, so there is '
      'nothing to route into a converter.',
    );
  }
  if (isPortFull(doc, to)) {
    return InsertConverterRefused(
      'TOP-003 — ${to.citation} already carries a cable, so a converter '
      'would have nowhere to land.',
    );
  }

  final fromName = doc.registries.signalFamilies[fromFamily]?.displayName;
  final toName = doc.registries.signalFamilies[toFamily]?.displayName;
  // THE ID IS THE FALLBACK, NOT A PLACEHOLDER. An unresolved family is a
  // real state (G4), and `video.hdbaset to Composite Converter` names the
  // thing accurately while `Unknown to Composite Converter` does not.
  final displayName =
      '${fromName ?? fromFamily.v} to ${toName ?? toFamily.v} Converter';

  final body = TemplateBody(
    manufacturer: '',
    model: '',
    displayName: displayName,
    category: 'Converter',
    typePrefix: kConverterTypePrefix,
    // NOT IN THE RACK, WHICH IS CR-015's OTHER HALF: a converter that an
    // installer pulls two cables to sits behind a display or above a
    // ceiling tile, not on a rail.
    mountMethod: MountMethod.notInRack,
    description:
        'Minted by the SIG-002 remedy from the two ports it was asked '
        'about. Its wattage and model are unstated because nothing has '
        'said what they are.',
    ports: [
      PortDef(
        key: const PortKey(kConverterInKey),
        label: 'IN',
        connector: from.def.connector,
        signalFamily: fromFamily,
        face: Face.rear,
        order: const FracIndex('a0'),
        direction: PortDirection.sink,
      ),
      PortDef(
        key: const PortKey(kConverterOutKey),
        label: 'OUT',
        connector: to.def.connector,
        signalFamily: toFamily,
        face: Face.rear,
        order: const FracIndex('a1'),
        direction: PortDirection.source,
      ),
    ],
  );

  final templateId = TemplateId(converterTemplateId(fromFamily, toFamily));
  final version = nextTemplateVersion(doc, templateId);
  final contentHash = 'sha256:minted-${templateId.v}';
  final designator = allocateDeviceDesignator(
    settings: doc.settings,
    typePrefix: kConverterTypePrefix,
    usedDesignators: {for (final d in doc.devices.values) d.designator},
  );

  final add = AddDeviceCommand(
    kind: DeviceKind.offRackPassive,
    templateRef: TemplateRef(
      templateId: templateId,
      version: version,
      contentHash: contentHash,
    ),
    designator: designator,
    name: displayName,
    placement: const OffRackPlacement(),
    now: now,
    actor: actor,
  );

  // THE SNAPSHOT FIRST. `AddDeviceCommand` never writes `doc.templates`,
  // so a device whose `TemplateRef` resolves to nothing draws as an
  // unknown body. Then the device, because the two connects below
  // resolve through `doc.devices`.
  tx
    ..add(
      SaveTemplateToProjectCommand(
        templateId: templateId,
        version: version,
        contentHash: contentHash,
        body: body,
        capturedAt: now,
      ),
    )
    ..add(add);

  final inPin = resolveConnectTarget(
    doc,
    deviceId: add.id,
    portKey: kConverterInKey,
  );
  final outPin = resolveConnectTarget(
    doc,
    deviceId: add.id,
    portKey: kConverterOutKey,
  );
  if (inPin == null || outPin == null) {
    // UNREACHABLE BY CONSTRUCTION, reported rather than asserted, on
    // `insert_receiver.dart`'s reasoning: an assert is silent in release,
    // which is where a half-placed converter would matter most.
    return const InsertConverterRefused(
      'The converter was placed but its ports did not resolve, so no '
      'cables were made.',
    );
  }

  // TWO CABLES, UNLIKE THE `SIG-001` REMEDY, and the difference is the
  // rule rather than a choice. That one leaves its second link open
  // because DR-113 makes its far end an Ethernet jack by construction, so
  // the second cable would fail `SIG-002` and `CON-001` together. Here
  // BOTH ends were named by the gesture, and the converter's ports were
  // authored to agree with them, so both cables are legal by
  // construction.
  for (final (a, b, side) in [
    (from, inPin, 'input'),
    (outPin, to, 'output'),
  ]) {
    final built = buildSplitConnectCommands(
      doc: doc,
      from: a,
      to: b,
      media: kUnstatedMedia,
      now: now,
      actor: actor,
    );
    switch (built) {
      case SplitConnectRefused(:final ruleId, :final message):
        return InsertConverterRefused(
          'The converter was placed, then its $side cable was refused: '
          '$ruleId — $message',
        );
      case SplitConnectReady(:final commands):
        for (final c in commands) {
          tx.add(c);
        }
    }
  }

  return InsertConverterDone(
    converterId: add.id,
    designator: designator,
    displayName: displayName,
  );
}
