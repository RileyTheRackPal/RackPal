// The append-only migration chain (docs/03-architecture.md §9.2, CR-093).
// Operates on the RAW root envelope map, before any typed deserialization
// — "migrating typed objects requires keeping historical Dart class
// shapes alive forever" (§9.2). json_codec.dart's typed decode always
// runs on the OUTPUT of migrateToCurrent, never on a raw map directly.
import 'package:rackpal_core/src/persistence/json_util.dart';
import 'package:rackpal_core/src/persistence/outlet_key_retirement.dart';
import 'package:rackpal_core/src/persistence/schema.dart';
import 'package:rackpal_core/src/util/outcome.dart';

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
/// (CR-092) — this is foreign JSON, not a RackPal file.
final class NotARackPalFileError implements Exception {
  const NotARackPalFileError(this.generator);

  final Object? generator;

  @override
  String toString() =>
      'NotARackPalFileError: root "generator" key is $generator, '
      'expected "$kGeneratorName".';
}

/// The envelope is structurally malformed — a required root key is
/// missing or is not the type the format demands. Distinct from
/// [NotARackPalFileError]: the generator tag matched, so this really is
/// meant to be a RackPal file, just a broken one.
final class MalformedEnvelopeError implements Exception {
  const MalformedEnvelopeError(this.message);

  final String message;

  @override
  String toString() => 'MalformedEnvelopeError: $message';
}

/// The migration chain ran out of migrations before it reached
/// [kSchemaVersion], so the envelope handed on would NOT be this build's
/// shape.
///
/// WHY THIS IS AN ERROR AND NOT A SHRUG. [migrateToCurrent]'s entire
/// contract to the typed decoder downstream is "whatever you get back is
/// `kSchemaVersion`-shaped". A chain that stops early breaks exactly that
/// contract, and the typed decoder has no way to notice: it reads the
/// keys it knows and produces a `RackDocument` that LOOKS healthy.
///
/// Two ways to get here, one live and one waiting:
///
///  * A corrupt or hand-edited envelope — `"schemaVersion": -1` from a
///    mangled byte or a merge artefact. It clears the `minReaderVersion`
///    gate, finds no migration for -1, and would otherwise be adopted as
///    a healthy document.
///  * THE STANDING TRAP OF AN APPEND-ONLY CHAIN: a future
///    [kSchemaVersion] bump that forgets its `migrations` entry. Silently
///    returning `Ok` would hand every older file to the typed decoder
///    unmigrated, surfacing as a confusing "damaged file" or — worse, if
///    the shapes happen to overlap — as a partial load. Failing loudly
///    here is what turns that into a bug someone finds in five minutes.
final class UnmigratableSchemaError implements Exception {
  const UnmigratableSchemaError({
    required this.storedSchemaVersion,
    required this.stalledAtVersion,
    required this.targetSchemaVersion,
  });

  /// What the file's root `schemaVersion` actually said.
  final int storedSchemaVersion;

  /// The version the chain got to before it ran out — the key that has no
  /// [migrations] entry.
  final int stalledAtVersion;

  /// [kSchemaVersion], the version it needed to reach.
  final int targetSchemaVersion;

  @override
  String toString() =>
      'UnmigratableSchemaError: a document stored at schemaVersion '
      '$storedSchemaVersion could not be migrated to $targetSchemaVersion '
      '— no migration is registered for version $stalledAtVersion.';
}

/// APPEND-ONLY. A shipped migration is a historical record — editing one
/// corrupts users' already-saved files. Never delete, never modify; only
/// ever add a new entry for a new `schemaVersion` bump.
///
/// Keyed by the schemaVersion each migration upgrades AWAY FROM (e.g. key
/// `0` migrates a v0 document up to v1's shape).
///
/// There is no real v0 in production history — v1 was the first ship. The
/// `0` entry below is a SYNTHETIC fixture built for this milestone's own
/// exit criterion ("one v0->v1 migration fixture in the golden corpus"): it
/// reenacts CR-094's real, documented `revision` -> `sequence` rename as if
/// a v0 schema had shipped with the old name, to prove the chain machinery
/// actually works end to end.
///
/// The `1` entry is the first REAL one — see [migrateV1ToV2].
const Map<int, Migration> migrations = <int, Migration>{
  0: migrateV0ToV1,
  1: migrateV1ToV2,
  2: migrateV2ToV3,
  3: migrateV3ToV4,
  4: migrateV4ToV5,
  5: migrateV5ToV6,
};

/// v5 -> v6: `PowerProfile.outletsProvided` and `outletsConsumed` are
/// DELETED (DR-171 §11.170.3). Outlet counts are read off ports and the
/// cords drawn to them instead.
///
/// ═══════════════════════════════════════════════════════════════════════
/// THE STRIP IS v3 -> v4's; THE HASH IS WHAT v4 NEVER HAD TO CONSIDER
/// ═══════════════════════════════════════════════════════════════════════
/// Every template body loses the two keys, as every port lost
/// `carriedProtocols` at v4. What v4 did not face is a real
/// `contentHash`: those arrived at `#795`, and every shipped starter
/// carries them over bodies that state both keys. `retireOutletKeys`
/// re-takes a hash only where it attested the body as stored, and a
/// device's `TemplateRef.contentHash` that equalled its snapshot's old
/// hash moves with it, so a template nobody edited is never reported as
/// edited and a device never disagrees with the snapshot it names.
///
/// `minReaderVersion` DOES NOT MOVE. A v5 reader meets the absent keys as
/// unknown, which every reader since v2 has understood, so refusing it
/// would refuse a file it opens perfectly.
JsonMap migrateV5ToV6(JsonMap raw) {
  final migrated = JsonMap.of(raw);
  final document = migrated[kKeyDocument];
  if (document is Map) {
    // "templateId@version" to the hash before and the hash after.
    final moved = <String, (Object?, Object?)>{};
    final templates = document['templates'];
    if (templates is Map) {
      for (final snapshot in templates.values) {
        if (snapshot is! Map) continue;
        final body = snapshot['body'];
        if (body is! Map<Object?, Object?>) continue;
        final before = snapshot['contentHash'];
        final after = retireOutletKeys(body, before);
        if (after == before) continue;
        snapshot['contentHash'] = after;
        moved['${snapshot['templateId']}@${snapshot['version']}'] = (
          before,
          after,
        );
      }
    }
    final devices = document['devices'];
    if (moved.isNotEmpty && devices is Map) {
      for (final device in devices.values) {
        if (device is! Map) continue;
        final ref = device['templateRef'];
        if (ref is! Map) continue;
        final change = moved['${ref['templateId']}@${ref['version']}'];
        if (change != null && ref['contentHash'] == change.$1) {
          ref['contentHash'] = change.$2;
        }
      }
    }
  }
  migrated[kKeySchemaVersion] = 6;
  return migrated;
}

/// v4 -> v5: the Plan view's model arrives, and NOTHING IN A v4 FILE
/// CHANGES (DR-037, DR-136 §11.135.3).
///
/// ═══════════════════════════════════════════════════════════════════════
/// A RE-STAMP AND NOTHING ELSE, WHICH IS WORTH A COMMENT RATHER THAN A
/// SHRUG
/// ═══════════════════════════════════════════════════════════════════════
/// Every v5 addition is an optional key or an empty entity map: no v4
/// document has an underlay, a pin or a `riseAllowance`, so there is no
/// value to convert and no key to strip. This step exists because the
/// SCHEMA moved, and the schema moved for a reason the format's usual
/// trigger does not cover: `minReaderVersion` became conditional and the
/// stamp it writes needs a number this build declares as current.
///
/// It deliberately does NOT stamp `minReaderVersion`. A migrated v4 file
/// has no plan data by construction, so it keeps `kMinReaderVersion` and
/// keeps opening on older builds; the conditional stamp is the ENCODER's
/// job, decided from the document's content at write time.
JsonMap migrateV4ToV5(JsonMap raw) {
  final migrated = JsonMap.of(raw);
  migrated[kKeySchemaVersion] = 5;
  return migrated;
}

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

/// v1 -> v2: the outlet-count keys became OMISSIBLE, so v2 files need a
/// reader that tolerates their absence — and a v1 file needs re-stamping
/// before this build can honestly write it back out.
///
/// WHAT CHANGED IN v2. `PowerProfile.outletsProvided`/`outletsConsumed`
/// were non-nullable `int`s defaulting to `0`, and the encoder wrote both
/// keys unconditionally. They are nullable now (CR-114, G4: an unauthored
/// count is UNKNOWN, not a measured zero), and the encoder omits the key
/// when there is no value — the format's absent-key-not-null rule. A v1
/// READER meeting one of those documents calls
/// `asInt(json['outletsProvided'], ...)` and throws
/// `FormatException: Expected an int ... got: null`. That is the whole
/// reason `kSchemaVersion` moved: a build that changed what it emits while
/// leaving the version at 1 gives a version-gated migration nothing to gate
/// on, and hands the user a corrupt-file error instead of a version error.
///
/// WHAT THIS FUNCTION THEREFORE DOES: it re-stamps the envelope, and it
/// does not touch the payload.
///
///  * `schemaVersion` -> 2, as every migration must.
///  * `minReaderVersion` -> at least [kMinReaderVersion]. NOT bookkeeping.
///    A v1 file opened here will be written back out by THIS build, in v2
///    form, with omitted outlet keys; leaving the stamp at 1 would ship
///    those bytes under a promise that any v1 reader can open them, and
///    that reader would throw rather than refuse. Raising it converts a
///    crash into `NewerSchemaError`. Never lowered — `max`, not assignment
///    — so a file that already demands more keeps demanding it.
///
/// WHAT IT DELIBERATELY DOES NOT DO, because the obvious rewrite is wrong.
/// It is tempting to translate v1's explicit `"outletsProvided": 0` into
/// v2's absent key, on the grounds that the old non-nullable default was
/// `0` and every unauthored template wrote one. But v1's catalogs also
/// authored `outletsProvided: 0` DELIBERATELY, on most of their entries
/// (`catalog_audio.dart`, `catalog_control.dart`, `catalog_field.dart`,
/// `catalog_rf.dart`, `catalog_sources.dart`), and that zero is a real
/// measurement: an amplifier genuinely provides no outlets. A v1 file
/// records no way to tell the two apart, so rewriting every `0` to
/// "unknown" would destroy far more true measurements than it would
/// recover fabricated ones — and inventing "this was never authored" is
/// exactly as much a guess as inventing "this was measured" (G4 cuts both
/// ways). Every key a v1 file contains is a valid v2 key with unchanged
/// meaning; v2's difference is only in what it may LEAVE OUT. So the
/// payload passes through untouched, and a v1 zero stays the measured zero
/// the file actually says it is.
JsonMap migrateV1ToV2(JsonMap raw) {
  final migrated = JsonMap.of(raw);
  migrated[kKeySchemaVersion] = 2;
  final declared = migrated[kKeyMinReaderVersion];
  if (declared is! int || declared < kMinReaderVersion) {
    migrated[kKeyMinReaderVersion] = kMinReaderVersion;
  }
  return migrated;
}

/// v2 -> v3: **drops a `PortDef.position` whose four components are all
/// zero** (`#226`, DR-105 §11.104.4).
///
/// ══════════════════════════════════════════════════════════════════════
/// WITHOUT THIS, EVERY FILE EVER SAVED READS AS HAND-PLACED
/// ══════════════════════════════════════════════════════════════════════
/// DR-105 §11.104.3 makes `position` nullable, with null meaning "the
/// layout is automatic". Every v2 file writes the key on every port,
/// **727 of them in each of the four checked-in starters**, all zero,
/// because `kUnplacedPanelPosition` was the only value any producer had.
/// Read at v3 untouched, all of them would mean *"manually placed at the
/// origin"* and the auto-layout would never run for anything anybody had
/// saved.
///
/// ══════════════════════════════════════════════════════════════════════
/// IT IS EXACT, NOT A HEURISTIC, AND THE DIFFERENCE MATTERS
/// ══════════════════════════════════════════════════════════════════════
/// A "drop it if it looks like a default" rule is usually a guess about
/// intent. This one is not: **no producer of a non-zero position has ever
/// existed**, so in every file that can exist at v2 a zero position IS an
/// unplaced port, with no exceptions to reason about. A genuine
/// nudge-to-origin authored after DR-105 is written into a v3 file and is
/// never seen by this step.
///
/// **A PORT IT CANNOT PARSE IS LEFT EXACTLY AS IT WAS.** A migration that
/// threw on a malformed port would turn a recoverable file into an
/// unopenable one; the decoder downstream reports the real problem with
/// the real key path.
JsonMap migrateV2ToV3(JsonMap raw) {
  final migrated = JsonMap.of(raw);
  final document = migrated[kKeyDocument];
  if (document is Map) {
    final templates = document['templates'];
    if (templates is Map) {
      for (final snapshot in templates.values) {
        if (snapshot is! Map) continue;
        final body = snapshot['body'];
        if (body is! Map) continue;
        final ports = body['ports'];
        if (ports is! List) continue;
        for (final port in ports) {
          if (port is! Map) continue;
          if (_isZeroPanelPosition(port['position'])) port.remove('position');
        }
      }
    }
  }
  migrated[kKeySchemaVersion] = 3;
  final declared = migrated[kKeyMinReaderVersion];
  if (declared is! int || declared < kMinReaderVersion) {
    migrated[kKeyMinReaderVersion] = kMinReaderVersion;
  }
  return migrated;
}

/// Whether [raw] is a panel position with all four components zero.
///
/// **ALL FOUR, AND A MISSING ONE IS NOT A ZERO.** A map that omits
/// `yFineNm` is not a zero position, it is a malformed one, and dropping
/// it would silently discard whatever the other three said.
bool _isZeroPanelPosition(Object? raw) {
  if (raw is! Map) return false;
  const keys = ['ruOffset', 'xTwelfth', 'xFineNm', 'yFineNm'];
  for (final key in keys) {
    if (raw[key] != 0) return false;
  }
  return raw.length == keys.length;
}

/// v3 -> v4: `PortDef.carriedProtocols` is deleted (DR-134 §11.133).
///
/// WHY THE VERSION MOVES AT ALL, since the reader could simply ignore the
/// key. `json_codec.dart` states the trigger twice in the same words: a
/// change is free when *"every file already on disk re-encodes byte for
/// byte"*. This one is not. `_encodePortDef` wrote `carriedProtocols`
/// unconditionally, so every `.rmpj` ever saved carries one empty array
/// per port and loses it here. `apartment.rmpj` alone carries 737.
/// Leaving the version at 3 while changing what the build emits gives a
/// version-gated migration nothing to gate on, which is [migrateV1ToV2]'s
/// stated reason and applies unchanged.
///
/// WHY [kMinReaderVersion] DOES NOT MOVE WITH IT, which is the first time
/// the two have diverged. That stamp rises when this build emits bytes an
/// older reader THROWS on. A v3 reader meets the absent key with
/// `?? const <Object?>[]` and gets `[]`, and **`[]` is the only value this
/// field has ever held in any file**, because nothing in the product could
/// write another. So a v3 reader loses nothing, and raising the stamp
/// would refuse a file that opens perfectly.
///
/// UNCONDITIONAL, UNLIKE [migrateV2ToV3]'s REMOVAL. That one had to test
/// `_isZeroPanelPosition` first, because a non-zero position was authored
/// data and dropping it would have destroyed a fact. There is no such
/// case here: no gesture ever set this field, so there is no value to
/// preserve and no discrimination to get wrong.
JsonMap migrateV3ToV4(JsonMap raw) {
  final migrated = JsonMap.of(raw);
  final document = migrated[kKeyDocument];
  if (document is Map) {
    final templates = document['templates'];
    if (templates is Map) {
      for (final snapshot in templates.values) {
        if (snapshot is! Map) continue;
        final body = snapshot['body'];
        if (body is! Map) continue;
        final ports = body['ports'];
        if (ports is! List) continue;
        for (final port in ports) {
          if (port is! Map) continue;
          port.remove('carriedProtocols');
        }
      }
    }
  }
  migrated[kKeySchemaVersion] = 4;
  final declared = migrated[kKeyMinReaderVersion];
  if (declared is! int || declared < kMinReaderVersion) {
    migrated[kKeyMinReaderVersion] = kMinReaderVersion;
  }
  return migrated;
}

/// Runs [raw] (a freshly `jsonDecode`d root envelope map) through the
/// generator check, the version-compatibility check, and the migration
/// chain up to [kSchemaVersion]. Never throws (CR-093) — every failure
/// mode, expected or malformed, comes back as an [Err].
Outcome<MigratedDoc> migrateToCurrent(JsonMap raw) {
  final generator = raw[kKeyGenerator];
  if (generator != kGeneratorName) {
    return Err(NotARackPalFileError(generator));
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
      // more this build knows how to do — stop rather than loop forever.
      // The post-loop check below turns this into the Err it is.
      break;
    }
    current = migration(current);
    version++;
  }

  // THE CHAIN EITHER ARRIVED OR IT FAILED. There is no third answer, and
  // the version this loop stopped at is the only evidence of which
  // happened — `current` looks identical either way, which is exactly why
  // this check cannot be left to the caller. See [UnmigratableSchemaError].
  if (version < kSchemaVersion) {
    return Err(
      UnmigratableSchemaError(
        storedSchemaVersion: schemaVersion,
        stalledAtVersion: version,
        targetSchemaVersion: kSchemaVersion,
      ),
    );
  }

  // schemaVersion > kSchemaVersion: a newer-than-us file this build's
  // minReaderVersion check above already agreed to open. No migration
  // runs (the loop condition is false from the start) — the raw map
  // passes through untouched, unknown fields and all.
  final openReadOnly = schemaVersion > kSchemaVersion;
  return Ok(MigratedDoc(current), openReadOnly: openReadOnly);
}
