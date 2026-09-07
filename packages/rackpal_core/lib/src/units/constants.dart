import 'package:rackpal_core/src/units/len.dart';

const kRackUnit = Len(44_450_000); // 44.45 mm exactly
const kGridUnit = Len(2_500_000); // 2.5 mm schematic pitch
const kPinPitch = 2; // gu
const kBankCollapseThreshold = 8;
const kMaxRackHeightU = 60; // CR-038
/// The container format this build WRITES (docs/03-architecture.md §9.2).
///
/// HISTORY, because an append-only migration chain is only readable next to
/// one:
///
///  * **1** — the first ship.
///  * **2** — `PowerProfile.outletsProvided`/`outletsConsumed` became
///    nullable, and the encoder switched from writing an explicit `0` for
///    an unauthored count to OMITTING the key (CR-114/CR-117's
///    absent-key-not-null rule). That is a BREAKING WRITE: a v1 reader
///    calls `asInt` on those keys and throws `FormatException` on a
///    document this build produces. The version had to move so the change
///    is detectable rather than arriving as a corrupt-file error — see
///    [kMinReaderVersion] and `migrations.dart`'s `migrateV1ToV2`.
///
/// 2 -> 3 at DR-105 §11.104.3/.4: `PortDef.position` became NULLABLE with
/// null meaning "the layout is automatic", and the encoder switched from
/// writing the origin on every port to OMITTING the key. Another BREAKING
/// WRITE in `migrateV1ToV2`'s exact sense: a v2 reader calls `asJsonMap`
/// on `position` and throws on a file this build produces, so
/// [kMinReaderVersion] moves with it. `migrateV2ToV3` drops the 727
/// zero positions each existing file carries; without it every one of
/// them would read as a hand-placed port and the auto-layout would never
/// run.
/// v4 DELETES `PortDef.carriedProtocols` (DR-134 §11.133.5). The trigger
/// is the one this file's own history states twice: the advance is owed
/// because every file on disk stops re-encoding byte for byte, losing one
/// key per port. It is NOT a breaking write in `migrateV1ToV2`'s sense,
/// which is why [kMinReaderVersion] stays behind at 3 for the first time:
/// a v3 reader meets the absent key with `?? const <Object?>[]` and gets
/// `[]`, and `[]` is the only value the field has ever held in any file,
/// so there is nothing an older reader can lose by not finding it.
/// `migrateV3ToV4` strips the key and re-stamps.
///
/// v5 ADDS THE PLAN MODEL (DR-037), AND ADVANCES FOR A REASON THIS
/// FILE'S HISTORY DID NOT PREVIOUSLY HAVE (DR-136 §11.135.3). Every
/// addition is optional and absent from every file on disk, so every one
/// of them re-encodes BYTE FOR BYTE and the trigger stated twice above is
/// not met. **The advance is owed because the format gained a capability
/// [kPlanMinReaderVersion] must be able to name.** A document carrying a
/// pin stamps a conditional `minReaderVersion` of 5, and a build
/// declaring `kSchemaVersion` 4 while writing that stamp would refuse its
/// own file. `migrateV4ToV5` re-stamps and converts nothing, because
/// there is nothing in a v4 file to convert.
const kSchemaVersion = 5;

/// The `minReaderVersion` stamped into a document that carries PLAN DATA
/// (DR-136 §11.135.2).
///
/// ═══════════════════════════════════════════════════════════════════════
/// THE ONE PLACE `minReaderVersion` STOPS BEING A CONSTANT
/// ═══════════════════════════════════════════════════════════════════════
/// Every other document stamps [kMinReaderVersion]. A document holding an
/// underlay or a pin stamps this instead, so a build that does not
/// understand plans opens it READ-ONLY and cannot overwrite it.
///
/// **IT EXISTS BECAUSE THE PASSTHROUGH DR-019 BOUGHT DOES NOT CLOSE THE
/// HAZARD DR-019 NAMED.** §11.18.1 described it exactly: a build predating
/// the Plan view, opening a file with pins, silently drops them on save.
/// §11.18.2(5) bought an `unknown` map, and M3-I built a RESERVED
/// CONTAINER rather than a harvester, correctly and with the limitation
/// written in capitals in `placement.dart`. A sibling key like `planPin`
/// was never covered. Neither file is wrong; the remedy simply does not
/// reach the hazard, and nothing noticed until PLAN-C tried to write the
/// test proving it did.
///
/// So the loss is prevented by REFUSING THE WRITE rather than by
/// preserving the field. The narrower fix, and it leaves harvesting where
/// `placement.dart` left it: a different format, owing its own ruling.
const kPlanMinReaderVersion = 5;

/// The lowest [kSchemaVersion] that can safely READ a document this build
/// writes — stamped into every file as `minReaderVersion` and checked by
/// `migrateToCurrent` before anything else happens.
///
/// It moves ONLY when the format changes in a way an older reader cannot
/// survive, which is why it is its own constant rather than an alias for
/// [kSchemaVersion]: a purely additive schema bump leaves this alone, so
/// old builds keep opening new files. It moved to 2 with the omitted
/// outlet keys above, which are exactly such a change — an older reader
/// does not degrade on them, it throws. Refusing the file with
/// `NewerSchemaError` is the honest outcome and is what this constant buys.
///
/// **IT DID NOT MOVE TO 4, AND THAT IS THE FIRST TIME THE TWO HAVE
/// DIVERGED.** DR-134 §11.133.5: deleting `carriedProtocols` changes what
/// every file contains, so [kSchemaVersion] is owed an advance, but a v3
/// reader tolerates the absent key and reads `[]`, which is what the field
/// held in every file ever written. Raising this would refuse a file that
/// opens perfectly, which is the opposite of what the constant is for.
///
/// **IT DOES NOT MOVE AT v5 EITHER, AND FOR A DIFFERENT REASON.** The
/// plan additions are optional keys a v3 reader simply does not find, so
/// an ordinary document keeps this stamp and keeps opening everywhere. A
/// document that actually CARRIES plan data stamps
/// [kPlanMinReaderVersion] instead: the value is a property of the
/// document from v5 onwards rather than of the build, which is the first
/// time that has been true (DR-136 §11.135.2).
const kMinReaderVersion = 3;
