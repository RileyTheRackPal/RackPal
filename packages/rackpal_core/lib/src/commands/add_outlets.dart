// `PWR-003`'s remedy: the issues panel's `[ Add a rack PDU ]` button
// (DR-128 §11.127.5, §11.127.8, §11.127.9).
//
// ═════════════════════════════════════════════════════════════════════
// THE FIRST TIER-3 REMEDY, AND THE FIRST THAT IS NOT A CHIP
// ═════════════════════════════════════════════════════════════════════
// `SpringBackRemedy` lives on a spring-back chip and answers a GESTURE
// that has not happened yet. `PWR-003` is a row in the issues panel about
// a rack that already exists, so `Finding` carries the remedy and this
// file carries out what the button says.
//
// ═════════════════════════════════════════════════════════════════════
// IT ASKS RATHER THAN GUESSING WHEN THE RACK HAS NO POWER AT ALL
// ═════════════════════════════════════════════════════════════════════
// DR-128 §11.127.9. The first answer to this question was "insert the 0U
// PDU", chosen by an agent listing what the catalogue happened to hold.
// The user returned the trade fact it was missing: the ordinary fix is a
// small passive strip on a shelf, fed from a PDU or sequencer outlet so
// the gear on it can be power-cycled remotely.
//
// So the rule is:
//
//   * The rack already provides outlets  ->  add the strip (`P04`). It
//     needs no 0U channel and it is what somebody would actually do.
//   * The rack provides none             ->  ASK. Returns
//     `AddOutletsChoice`, and the panel puts the question.
//
// The second case is not indecision. A strip in a rack with no
// distribution reaches a wall outlet and is a perfectly legal drawing; a
// PDU is the beginning of a power plan. **A remedy that silently picked
// the second would have made a design decision on somebody's behalf**,
// and `PWR-003` is an error-severity finding, so that decision would look
// like the product's opinion rather than a choice.
//
// The rule already knows which case it is: `rulePwr003` summed
// `outletsProvided` to decide the rack was short, so the branch below
// re-reads a number the finding was computed from.
import 'package:rackpal_core/src/catalog/seed_catalog.dart';
import 'package:rackpal_core/src/commands/catalog_placement.dart';
import 'package:rackpal_core/src/commands/device_commands.dart';
import 'package:rackpal_core/src/commands/shelf_placement.dart';
import 'package:rackpal_core/src/commands/template_snapshot_commands.dart';
import 'package:rackpal_core/src/commands/zero_u_commands.dart';
import 'package:rackpal_core/src/derived/device_loads.dart';
import 'package:rackpal_core/src/derived/placeable_templates.dart';
import 'package:rackpal_core/src/document_controller.dart';
import 'package:rackpal_core/src/model/placement.dart';
import 'package:rackpal_core/src/model/rack.dart';
import 'package:rackpal_core/src/model/rack_document.dart';
import 'package:rackpal_core/src/model/template.dart';
import 'package:rackpal_core/src/model/zero_u_channel.dart';
import 'package:rackpal_core/src/units/ids.dart';
import 'package:rackpal_core/src/units/len.dart';

/// The 6-outlet shelf strip, and the 0U PDU it is usually plugged into.
const String kPowerStripCatalogId = 'P04';
const String kRackPduCatalogId = 'P01';

/// The 2U vented shelf the strip is set on when the rack has none.
const String kRackShelfCatalogId = 'X03';

/// The channel a minted 0U PDU lands in when the rack has none.
const String kRemedyChannelId = 'remedy-left';

/// Which of the two the caller wants, when the panel has asked.
enum OutletSource {
  /// `P04`, a passive strip on a shelf. The everyday fix.
  powerStrip(kPowerStripCatalogId),

  /// `P01`, the 24-outlet 0U vertical PDU. The start of a power plan.
  rackPdu(kRackPduCatalogId);

  const OutletSource(this.catalogId);

  final String catalogId;
}

/// What [addOutletsToRack] decided.
sealed class AddOutletsResult {
  const AddOutletsResult();
}

/// Something was placed.
final class AddOutletsDone extends AddOutletsResult {
  const AddOutletsDone({
    required this.deviceId,
    required this.designator,
    required this.source,
    required this.outletsGained,
  });

  final Uuid deviceId;
  final String designator;
  final OutletSource source;

  /// The NET gain, which is not the same as the outlets the device has:
  /// it consumes one to provide its own. A strip of six gains five.
  final int outletsGained;
}

/// The rack provides no outlets at all, so the caller has to ask which.
///
/// NOT A REFUSAL. Nothing is wrong with the document and nothing failed;
/// the remedy simply will not choose between two different jobs on
/// somebody's behalf.
final class AddOutletsChoice extends AddOutletsResult {
  const AddOutletsChoice(this.question);

  /// What the panel should ask, in words.
  final String question;
}

/// Why nothing was placed.
final class AddOutletsRefused extends AddOutletsResult {
  const AddOutletsRefused(this.message);

  final String message;
}

/// True when anything in [rackId] declares outlets it provides.
///
/// WALKS THE RACK THE SAME WAY `rulePwr003` DOES, through
/// `belongsToRack` and `resolveDeviceLoads`, because this answer decides
/// which remedy that rule's finding offers. Two different traversals
/// would eventually disagree about which devices are in a rack, and the
/// disagreement would show up as a button that fixes the wrong thing.
bool rackProvidesOutlets(RackDocument doc, Uuid rackId) {
  for (final device in doc.devices.values) {
    if (!belongsToRack(device, rackId, doc.devices)) continue;
    final loads = resolveDeviceLoads(device, bodyFor(device, doc.templates));
    if ((loads.outletsProvided ?? 0) > 0) return true;
  }
  return false;
}

/// Writes [body] into the project at version 1 if it is not there already.
///
/// `AddDeviceCommand` never writes `doc.templates`, so a device whose
/// `TemplateRef` resolves to nothing draws as an unknown body. Every
/// placement path below therefore seeds first.
void _seedTemplate(
  TxnScope<RackDocument> tx,
  RackDocument doc,
  String catalogId,
  TemplateBody body,
  DateTime now,
) {
  final templateId = TemplateId(catalogId);
  if (resolveLatestTemplate(doc, catalogId) != null) return;
  tx.add(
    SaveTemplateToProjectCommand(
      templateId: templateId,
      version: nextTemplateVersion(doc, templateId),
      contentHash: 'sha256:seed-$catalogId',
      body: body,
      capturedAt: now,
    ),
  );
}

/// A 0U channel on [rack] to put a PDU in, adding one if there is none.
///
/// AC-044 makes the inspector the only way a person creates a 0U
/// occupant, and this is not a person: it is a remedy the person asked
/// for by name. The channel it adds is an ordinary one they can remove
/// afterwards, from the rack inspector (`#876`).
///
/// **"OR EDIT" USED TO BE IN THAT SENTENCE AND WAS NEVER TRUE.** There is
/// no command that changes a channel's bounds, only add and remove, so a
/// channel whose extent is wrong is replaced rather than corrected.
String _channelFor(
  TxnScope<RackDocument> tx,
  RackDocument doc,
  Rack rack,
  DateTime now,
) {
  if (rack.zeroUChannels.isNotEmpty) return rack.zeroUChannels.first.id;
  tx.add(
    AddZeroUChannelCommand(
      rackId: rack.id,
      channel: ZeroUChannel(
        id: kRemedyChannelId,
        // REAR LEFT, and the choice is the trade's rather than the
        // model's default. A 0U PDU goes down the back of the rack where
        // the cords are, not down the front where the gear is read.
        side: ZeroUChannelSide.rearLeft,
        // THE WHOLE RACK, which is what a vertical channel is: a rail
        // down its full height.
        //
        // ═══════════════════════════════════════════════════════════
        // 1-BASED, AND THIS READ `startU: 0` CITING CR-025 FOR IT
        // ═══════════════════════════════════════════════════════════
        // CR-025 rules the opposite in as many words: "1-based, bottom
        // origin. `ruIndex` in [1, heightU]", and calls itself the
        // contradiction that "will actually hurt". So the comment named
        // the ruling that forbids the line it was defending.
        //
        // NOTHING ELSE IN THE TREE AGREED WITH IT. Every shipped starter
        // writes `startU: 1`, every test in `zero_u_commands_test.dart`
        // does, `placement_rules.dart` derives a channel's length as
        // `endU - startU + 1` "from U 1 to U 42 is 42 U of rail", and
        // `rack_shrink.dart` normalises "an inverted or SUB-1 channel"
        // on read, which is this defect described by a file that had
        // never seen it.
        //
        // AND `planAddZeroUChannel` WOULD HAVE REFUSED IT. It rejects
        // `startU < 1`. This is the only producer in the product and it
        // builds the command directly, so the guard never ran on the one
        // path that ships (`#876`, DR-163).
        startU: 1,
        endU: rack.heightU,
        name: 'Rear left',
      ),
    ),
  );
  return kRemedyChannelId;
}

/// Adds outlets to [rackId], choosing the strip when the rack already has
/// distribution and asking when it has none.
///
/// Pass [source] to answer an [AddOutletsChoice] this returned earlier.
AddOutletsResult addOutletsToRack(
  TxnScope<RackDocument> tx, {
  required RackDocument doc,
  required Uuid rackId,
  required DateTime now,
  required String actor,
  OutletSource? source,
}) {
  final rack = doc.racks[rackId];
  if (rack == null) {
    return const AddOutletsRefused(
      'That rack is no longer in the drawing.',
    );
  }

  final chosen =
      source ??
      (rackProvidesOutlets(doc, rackId)
          ? OutletSource.powerStrip
          // ASKED, NOT ASSUMED. See the header.
          : null);
  if (chosen == null) {
    return AddOutletsChoice(
      'Nothing in ${rack.designator} provides an outlet yet. Add a power '
      'strip, or a rack PDU?',
    );
  }

  final body = buildSeedCatalog()[chosen.catalogId];
  if (body == null) {
    return AddOutletsRefused(
      'This build has no ${chosen.catalogId} to place.',
    );
  }
  final provided = body.power.outletsProvided;
  final consumed = body.power.outletsConsumed ?? 0;
  if (provided == null) {
    // G4 ON A PRECONDITION. A template that does not say how many outlets
    // it provides cannot be offered as the fix for not having enough, and
    // guessing a number here would be the fabrication the invariant
    // forbids.
    return AddOutletsRefused(
      '${body.displayName} does not state how many outlets it provides, '
      'so it cannot be offered as the answer to a shortfall.',
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // THE DEVICE HAS TO END UP IN THE RACK, OR THE REMEDY IS A LIE
  // ═══════════════════════════════════════════════════════════════════
  // `rulePwr003` counts through `belongsToRack`, which walks
  // `hostRackOf`. A `StagedPlacement` or an `OffRackPlacement` answers
  // null there, so a remedy that added the device and left it unplaced
  // would report success against a finding that had not moved. "A remedy
  // chip that only explains has not remedied" (`#278`), one tier down.
  //
  // Neither candidate goes in rail holes, so each needs its own seat:
  //   * `P04` is `mountMethod: shelf`  -> a shelf, added first if the
  //     rack has none. `hostRackOf` walks shelf to host to rail, so a
  //     strip on a shelf in the rack DOES belong to the rack.
  //   * `P01` is `mountMethod: zeroU`  -> a `ZeroUChannel`, added first
  //     if the rack has none, then a `ZeroUTarget`. That branch of
  //     `buildPlaceFromCatalogCommand` has existed since M4 and has
  //     never had a production caller; this is the first.
  _seedTemplate(tx, doc, chosen.catalogId, body, now);

  final AddDeviceCommand add;
  switch (chosen) {
    case OutletSource.powerStrip:
      var shelf = findShelfInRack(doc, rackId);
      if (shelf == null) {
        // NO SHELF, SO ONE IS ADDED, and it is part of the same undo
        // entry. An installer who needs a strip on a shelf and has no
        // shelf buys a shelf; the drawing should say so rather than
        // leaving the strip nowhere.
        _seedTemplate(
          tx,
          doc,
          kRackShelfCatalogId,
          buildSeedCatalog()[kRackShelfCatalogId]!,
          now,
        );
        final placed = buildPlaceFromCatalogCommand(
          doc: doc,
          catalogId: kRackShelfCatalogId,
          targetRack: rack,
          now: now,
          actor: actor,
        );
        if (placed is CatalogPlacementFailed) {
          return AddOutletsRefused(
            'A shelf is needed to set the strip on, and it could not be '
            'placed: ${placed.reason}',
          );
        }
        final shelfCmd = (placed as CatalogPlacementReady).command;
        tx.add(shelfCmd);
        shelf = doc.devices[shelfCmd.id];
        if (shelf == null) {
          return const AddOutletsRefused(
            'The shelf was placed but did not resolve, so no strip was '
            'added.',
          );
        }
      }
      final onShelf = buildPlaceOnShelfCommand(
        doc: doc,
        catalogId: chosen.catalogId,
        hostId: shelf.id,
        now: now,
        actor: actor,
      );
      if (onShelf is ShelfPlacementFailed) {
        return AddOutletsRefused(onShelf.reason);
      }
      add = (onShelf as ShelfPlacementReady).command;

    case OutletSource.rackPdu:
      final channelId = _channelFor(tx, doc, rack, now);
      final placed = buildPlaceFromCatalogCommand(
        doc: doc,
        catalogId: chosen.catalogId,
        targetRack: rack,
        now: now,
        actor: actor,
        zeroU: (
          channelId: channelId,
          offsetFromChannelStart: Len.zero,
          orientation: ZeroUOrientation.vertical,
        ),
      );
      if (placed is CatalogPlacementFailed) {
        return AddOutletsRefused(placed.reason);
      }
      add = (placed as CatalogPlacementReady).command;
  }
  tx.add(add);
  final designator = add.designator;

  return AddOutletsDone(
    deviceId: add.id,
    designator: designator,
    source: chosen,
    outletsGained: provided - consumed,
  );
}
