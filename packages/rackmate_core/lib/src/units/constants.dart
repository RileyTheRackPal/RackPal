import 'package:rackmate_core/src/units/len.dart';

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
const kSchemaVersion = 2;

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
const kMinReaderVersion = 2;
