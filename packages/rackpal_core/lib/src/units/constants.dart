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
const kSchemaVersion = 4;

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
const kMinReaderVersion = 3;
