// The append-only migration chain (docs/03-architecture.md §9.2, CR-093).
// Operates on the RAW root envelope map, before any typed deserialization
// — "migrating typed objects requires keeping historical Dart class
// shapes alive forever" (§9.2). json_codec.dart's typed decode always
// runs on the OUTPUT of migrateToCurrent, never on a raw map directly.
import 'package:rackmate_core/src/persistence/json_util.dart';
import 'package:rackmate_core/src/persistence/schema.dart';
import 'package:rackmate_core/src/util/outcome.dart';

typedef Migration = JsonMap Function(JsonMap);

/// The result of [migrateToCurrent]: the full root envelope map, migrated
/// (if necessary) up to [kSchemaVersion]'s shape. Still raw JSON —
/// json_codec.dart's typed deserialization runs on [raw] next.
final class MigratedDoc {
  const MigratedDoc(this.raw);

  final JsonMap raw;
}

/// Refused: the file's `minReaderVersion` is newer than this build's
/// [kSchemaVersion] understands (docs/03-architecture.md §9.2). Opening
/// it at all risks silently discarding data this build cannot model, so
/// this is the one case the migration chain refuses outright rather than
/// opening read-only.
final class NewerSchemaError implements Exception {
  const NewerSchemaError({
    required this.minReaderVersion,
    required this.supportedSchemaVersion,
  });

  final int minReaderVersion;
  final int supportedSchemaVersion;

  @override
  String toString() =>
      'NewerSchemaError: file requires minReaderVersion >= '
      '$minReaderVersion but this build only supports schemaVersion '
      '$supportedSchemaVersion.';
}

/// The root `"generator"` key is missing or is not [kGeneratorName]
/// (CR-092) — this is foreign JSON, not a RackMate file.
final class NotARackMateFileError implements Exception {
  const NotARackMateFileError(this.generator);

  final Object? generator;

  @override
  String toString() =>
      'NotARackMateFileError: root "generator" key is $generator, '
      'expected "$kGeneratorName".';
}

/// The envelope is structurally malformed — a required root key is
/// missing or is not the type the format demands. Distinct from
/// [NotARackMateFileError]: the generator tag matched, so this really is
/// meant to be a RackMate file, just a broken one.
final class MalformedEnvelopeError implements Exception {
  const MalformedEnvelopeError(this.message);

  final String message;

  @override
  String toString() => 'MalformedEnvelopeError: $message';
}

/// APPEND-ONLY. A shipped migration is a historical record — editing one
/// corrupts users' already-saved files. Never delete, never modify; only
/// ever add a new entry for a new `schemaVersion` bump.
///
/// Keyed by the schemaVersion each migration upgrades AWAY FROM (e.g. key
/// `0` migrates a v0 document up to v1's shape).
///
/// `kSchemaVersion` is `1` and there is no real v0 in production history
/// — v1 is the first ship. The single entry below is a SYNTHETIC fixture
/// built for this milestone's own exit criterion ("one v0->v1 migration
/// fixture in the golden corpus"): it reenacts CR-094's real, documented
/// `revision` -> `sequence` rename as if a v0 schema had shipped with the
/// old name, to prove the chain machinery actually works end to end. A
/// second, real migration lands here whenever `kSchemaVersion` actually
/// bumps in a future milestone.
const Map<int, Migration> migrations = <int, Migration>{
  0: migrateV0ToV1,
};

/// Synthetic v0 -> v1 migration (see [migrations]'s doc comment): v0
/// called the root envelope's `sequence` counter `revision` instead.
/// Renames the key in place and bumps `schemaVersion` to `1`; every other
/// key is passed through unchanged.
JsonMap migrateV0ToV1(JsonMap raw) {
  final migrated = JsonMap.of(raw);
  if (migrated.containsKey('revision')) {
    migrated[kKeySequence] = migrated.remove('revision');
  }
  migrated[kKeySchemaVersion] = 1;
  return migrated;
}

/// Runs [raw] (a freshly `jsonDecode`d root envelope map) through the
/// generator check, the version-compatibility check, and the migration
/// chain up to [kSchemaVersion]. Never throws (CR-093) — every failure
/// mode, expected or malformed, comes back as an [Err].
Outcome<MigratedDoc> migrateToCurrent(JsonMap raw) {
  final generator = raw[kKeyGenerator];
  if (generator != kGeneratorName) {
    return Err(NotARackMateFileError(generator));
  }

  final minReaderVersion = raw[kKeyMinReaderVersion];
  if (minReaderVersion is! int) {
    return const Err(
      MalformedEnvelopeError(
        'root "minReaderVersion" is missing or not an int.',
      ),
    );
  }
  if (minReaderVersion > kSchemaVersion) {
    return Err(
      NewerSchemaError(
        minReaderVersion: minReaderVersion,
        supportedSchemaVersion: kSchemaVersion,
      ),
    );
  }

  final schemaVersion = raw[kKeySchemaVersion];
  if (schemaVersion is! int) {
    return const Err(
      MalformedEnvelopeError(
        'root "schemaVersion" is missing or not an int.',
      ),
    );
  }

  var current = raw;
  var version = schemaVersion;
  while (version < kSchemaVersion) {
    final migration = migrations[version];
    if (migration == null) {
      // No migration registered to advance past this version. Nothing
      // more this build knows how to do — stop rather than loop forever;
      // the caller gets whatever shape the chain reached.
      break;
    }
    current = migration(current);
    version++;
  }

  // schemaVersion > kSchemaVersion: a newer-than-us file this build's
  // minReaderVersion check above already agreed to open. No migration
  // runs (the loop condition is false from the start) — the raw map
  // passes through untouched, unknown fields and all.
  final openReadOnly = schemaVersion > kSchemaVersion;
  return Ok(MigratedDoc(current), openReadOnly: openReadOnly);
}
