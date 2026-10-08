// The `.rpdx` codec: one device template, as a file (DR-100 §11.99,
// CR-063, AC-050/A8.2). docs/03-architecture.md §7 gives `library/` this
// job, and this is its first occupant.
//
// ==================================================================
// WHAT THIS FILE DELIBERATELY DOES NOT CONTAIN
// ==================================================================
// A DESCRIPTION OF A `TemplateBody`. Not one field name, not one key.
// The body is written by `templateBodyToJson` and read by
// `templateBodyFromJson`, the same pair `.rppj` goes through, so a field
// this format fails to carry is a field `.rppj` fails to carry and
// CR-117's byte gate fails first and loudly.
//
// That is DR-100's whole content. The alternative on the table was
// docs/06 §7.3's `identity.` / `physical.` / `power.` sections, and the
// census that killed it is in canon §11.99.1: the encoder emits **39**
// keys, the worked example places **18**, **21** had no home anywhere in
// the corpus, and `model` was one of the 21. `model` is required, always
// encoded, and DR-056 keeps it undefaulted SPECIFICALLY so it prints an
// unknown. A codec built from that example drops the one field the
// clause-2 drill is sent to look for.
//
// A partition table would also have to stay TOTAL as `TemplateBody`
// grows, because a key no section claims silently vanishes from the
// file, and only a gate written for that purpose would ever say so.
// `copyTemplateBody`'s header records the same failure one level down:
// "a clone drifts the first time somebody adds field 51".
//
// ==================================================================
// THE FORMAT WAS RECOGNISED, NOT DESIGNED
// ==================================================================
// A `TemplateSnapshot` already on disk in all four starters is
//
//     {templateId, version, contentHash, capturedAt, body: {...}}
//
// and a `.rpdx` is that shape with `capturedAt` dropped (a file has no
// capture time; the moment it was exported is not a fact about the
// template) plus `schemaVersion` and `kind`. `.rpda` is an array of
// these plus a manifest (DR-015 §11.15.3) and invents no third shape.
import 'dart:convert';
import 'dart:typed_data';

import 'package:rackpal_core/src/model/registries.dart';
import 'package:rackpal_core/src/model/template.dart';
import 'package:rackpal_core/src/persistence/codec.dart';
import 'package:rackpal_core/src/persistence/json_codec.dart';
import 'package:rackpal_core/src/persistence/json_limits.dart';
import 'package:rackpal_core/src/persistence/json_util.dart';
import 'package:rackpal_core/src/persistence/outlet_key_retirement.dart';
import 'package:rackpal_core/src/units/ids.dart';
import 'package:rackpal_core/src/util/outcome.dart';

/// The `.rpdx` schema version this build writes and understands.
///
/// **ITS OWN CHAIN, INDEPENDENT OF `.rppj`'s `kSchemaVersion`**
/// (AC-050/A8.2, docs/11 §5: *"`.rpdx` has its own parallel chain and its
/// own corpus"*). `.rppj` is at 2 and this is at 1, and the two numbers
/// never have to move together: a device template's shape is not a
/// project's shape and coupling them would make every project migration
/// a template migration for no reason.
/// **2 SINCE DR-134 §11.133**, which deleted `PortDef.carriedProtocols`.
/// The body of a `.rpdx` is written by `templateBodyToJson`, so a file
/// exported before that change carries the key on every port AND a
/// `contentHash` taken over bytes that include it. Left alone, every such
/// file would import reporting a content mismatch, which is a false alarm
/// that trains a person to ignore a real one.
///
/// **3 SINCE DR-171 §11.170.3**, which deleted `PowerProfile`'s two outlet
/// counts. The step is the one `.rppj` and `.rpda` share: strip both keys,
/// and re-take the hash only where it attested the body as stored.
///
/// **4 SINCE DR-245 §11.244.1**, which lets a file carry the signal
/// families its device uses. The step from 3 changes nothing, since a v3
/// file carries none. **A file is WRITTEN at 4 only when it carries a
/// family** ([kRmdxFamilyFreeSchemaVersion] otherwise): the reader ignores
/// unknown keys, so a v3-labelled file with families would lose them in
/// silence on an older build, and at 4 that build refuses it instead.
const int kRmdxSchemaVersion = 4;

/// The version a file that carries NO signal family is written at, so a
/// family-free export stays byte-identical and opens on every build that
/// opened it before DR-245.
const int kRmdxFamilyFreeSchemaVersion = 3;

/// The root `kind` tag every `.rpdx` carries (docs/06 §7.3).
///
/// **THIS IS `.rpdx`'s GENERATOR TAG**, doing the job `kGeneratorName`
/// does for `.rppj`: it is what makes "you picked a project file" a
/// typed refusal rather than a `FormatException` from a decoder that was
/// never going to succeed. It is the second half of M4-M1's file
/// dialog. The filter stops most wrong picks; this stops the rest.
const String kRmdxKind = 'device-template';

/// The root key names, declared once so the writer and the reader cannot
/// disagree about a spelling.
const String _kSchemaVersion = 'schemaVersion';
const String _kKind = 'kind';
const String _kTemplateId = 'templateId';
const String _kVersion = 'version';
const String _kContentHash = 'contentHash';
const String _kBody = 'body';
const String _kSignalFamilies = 'signalFamilies';

/// One device template as it sits in a `.rpdx`.
///
/// The four facts beside the body are `TemplateSnapshot`'s, minus
/// `capturedAt`. They are carried rather than derived because every one
/// of them is a fact about the template and not about this file.
final class DeviceTemplateFile {
  const DeviceTemplateFile({
    required this.templateId,
    required this.version,
    required this.contentHash,
    required this.body,
    this.signalFamilies = const [],
  });

  /// Built from an in-project snapshot, which is where every export
  /// starts (`#236`).
  factory DeviceTemplateFile.fromSnapshot(
    TemplateSnapshot snapshot, {
    List<SignalFamilyDef> signalFamilies = const [],
  }) => DeviceTemplateFile(
    templateId: snapshot.templateId,
    version: snapshot.version,
    contentHash: snapshot.contentHash,
    body: snapshot.body,
    signalFamilies: signalFamilies,
  );

  final TemplateId templateId;

  /// Monotonic int, NOT semver (CR-050).
  final int version;

  /// **CARRIED VERBATIM AND NOT VERIFIED HERE, and the reason is that
  /// nothing in this repository computes one yet.**
  ///
  /// Every `contentHash` in the tree today is a labelled placeholder:
  /// `template_fork_commands.dart` writes `unhashed:<id>@1` and
  /// `structure_commands.dart` writes `sha256:structure-no-template`.
  /// There is no sha256 anywhere in `lib/`, and `crypto` is a
  /// **transitive** dependency with no row in docs/03 §10.1.
  ///
  /// So this codec does what an honest carrier does: it round-trips the
  /// value it was given and asserts nothing about it. **AC-042's rule
  /// that a mismatch is a warning and a badge and never a load failure
  /// is `#236`'s to implement**, and `#236` cannot be exercised until
  /// somebody makes the hash real, because a placeholder never
  /// mismatches.
  ///
  /// **Filed as `#795`, not folded in here.** The hasher is shared with
  /// every `.rppj` `TemplateSnapshot`, so making it real inside the
  /// `.rpdx` codec would fix one file format and leave the other with
  /// the placeholder, which is two spellings of one fact (DR-098
  /// §11.97.4). It also needs `crypto` promoted from transitive to a
  /// declared dependency with a docs/03 §10.1 row, which the
  /// dependency-table-parity gate will insist on.
  final String contentHash;

  final TemplateBody body;

  /// The families [body]'s ports name that the shipped catalogue does not
  /// hold (DR-245 §11.244.1), so the device places with its ports resolved
  /// on a machine that never saw them. Empty for a device that uses only
  /// shipped families, which is every device before DR-122.
  final List<SignalFamilyDef> signalFamilies;
}

/// Refused: the root `kind` is missing or is not [kRmdxKind].
///
/// A project file, a library archive, or foreign JSON. Typed so the
/// import surface can say WHICH, rather than reporting a corrupt device
/// template for a file that is a perfectly good project.
final class NotADeviceTemplateError implements Exception {
  const NotADeviceTemplateError(this.kind);

  final Object? kind;

  @override
  String toString() =>
      'NotADeviceTemplateError: root "kind" key is $kind, '
      'expected "$kRmdxKind".';
}

/// Refused: the file's `schemaVersion` is newer than [kRmdxSchemaVersion].
///
/// **REFUSED RATHER THAN OPENED READ-ONLY, which is the opposite of what
/// `.rppj` does, and the asymmetry is deliberate.** A project carries
/// `minReaderVersion` and an `unknown` passthrough on every persisted
/// object, so a newer project can be opened without understanding all of
/// it and re-saved losslessly (CR-093). **`TemplateBody` has neither.**
/// AC-012 rules it *"app-defined and closed; there is no forward-compat
/// argument"*, so a newer template read by this build would silently drop
/// whatever it did not model, and then place a device from it. There is
/// no read-only middle ground to offer, so there is no `minReaderVersion`
/// key in the format either: it would be a field with nothing to decide.
final class NewerRmdxSchemaError implements Exception {
  const NewerRmdxSchemaError({
    required this.storedSchemaVersion,
    required this.supportedSchemaVersion,
  });

  final int storedSchemaVersion;
  final int supportedSchemaVersion;

  @override
  String toString() =>
      'NewerRmdxSchemaError: file is schemaVersion $storedSchemaVersion '
      'but this build only understands $supportedSchemaVersion.';
}

/// Refused: the envelope is structurally malformed.
///
/// Distinct from [NotADeviceTemplateError] the way `.rppj`'s
/// `MalformedEnvelopeError` is distinct from `NotARackPalFileError`: the
/// `kind` tag matched, so this really is meant to be a device template,
/// just a broken one.
final class MalformedRmdxError implements Exception {
  const MalformedRmdxError(this.message);

  final String message;

  @override
  String toString() => 'MalformedRmdxError: $message';
}

/// [file] as the plain JSON tree a `.rpdx` holds.
JsonMap rmdxToJsonTree(DeviceTemplateFile file) => <String, Object?>{
  _kSchemaVersion: file.signalFamilies.isEmpty
      ? kRmdxFamilyFreeSchemaVersion
      : kRmdxSchemaVersion,
  _kKind: kRmdxKind,
  _kTemplateId: file.templateId.v,
  _kVersion: file.version,
  _kContentHash: file.contentHash,
  _kBody: templateBodyToJson(file.body),
  if (file.signalFamilies.isNotEmpty)
    _kSignalFamilies: signalFamiliesToJson(file.signalFamilies),
};

/// [families] as the list a device file carries, sorted by id so the
/// bytes do not depend on the order a caller gathered them in.
List<JsonMap> signalFamiliesToJson(Iterable<SignalFamilyDef> families) => [
  for (final f in families.toList()..sort((a, b) => a.id.v.compareTo(b.id.v)))
    signalFamilyDefToJson(f),
];

/// The `signalFamilies` list of a device file's root, or empty when the
/// key is absent, which is every file written before DR-245.
List<SignalFamilyDef> signalFamiliesFromJson(Object? raw, String context) => [
  for (final (i, e) in asJsonList(raw ?? const <Object?>[], context).indexed)
    signalFamilyDefFromJson(asJsonMap(e, '$context[$i]')),
];

/// [file] as the canonical bytes that go on disk: plain UTF-8 JSON, LF,
/// two-space indent, keys sorted at every level (docs/06 §7.3).
///
/// **The same `encodeCanonicalJsonBytes` `.rppj` uses**, so "sorted how?"
/// has one answer in this product rather than two. `JsonEncoder` emits
/// `\n` and never `\r\n`, which is where the LF requirement is actually
/// satisfied; `.gitattributes` keeps it that way for the fixtures.
Uint8List encodeRmdxBytes(DeviceTemplateFile file) =>
    Uint8List.fromList(encodeCanonicalJsonBytes(rmdxToJsonTree(file)));

/// Bytes to a [DeviceTemplateFile]. Never throws (CR-093).
///
/// **THE LIMITS RUN FIRST, and this path has them from the day it lands
/// rather than waiting for `#237`.** AC-058/D8 says *every* import path,
/// and a read path shipped without them is a defect on arrival, not a
/// retrofit somebody schedules. `#237`'s job is the CENSUS across every
/// path once `#236` and M4-N have added theirs; this is one of the paths
/// it will count, already paid.
///
/// The zip sniff is here for `.rppj`'s reason and one more of its own: a
/// `.rmda` is deliberately NOT a zip (DR-015 §11.15.4), so anything that
/// sniffs as one reached this function by accident.
Outcome<DeviceTemplateFile> readRmdxBytes(
  Uint8List bytes, {
  JsonLimits limits = const JsonLimits(),
}) {
  if (looksLikeZip(bytes)) {
    return const Err(UnsupportedZipContainerError());
  }
  switch (checkJsonLimits(bytes, limits: limits)) {
    case Err(:final error):
      return Err(error);
    case Ok<void>():
      break;
  }
  final JsonMap tree;
  try {
    tree = asJsonMap(jsonDecode(utf8.decode(bytes)), 'rmdx root');
    // `on Object`, NOT `on Exception`, for `parseDocumentJsonTree`'s
    // reason: `StackOverflowError` and `OutOfMemoryError` are Errors and
    // an `on Exception` clause walks straight past both.
  } on Object catch (e) {
    return Err(e);
  }
  return readRmdxJsonTree(tree);
}

/// A parsed JSON tree to a [DeviceTemplateFile]. Never throws (CR-093).
///
/// Separate from [readRmdxBytes] so a caller that parsed in an isolate
/// can still decode on the main isolate, and so a test can hand in a
/// tree without building bytes for it.
Outcome<DeviceTemplateFile> readRmdxJsonTree(JsonMap raw) {
  // KIND BEFORE VERSION, deliberately. A `.rppj` has a `schemaVersion`
  // too, and checking the version first would report a project file as a
  // device template from the wrong era rather than as a project file.
  final kind = raw[_kKind];
  if (kind != kRmdxKind) {
    return Err(NotADeviceTemplateError(kind));
  }
  final stored = raw[_kSchemaVersion];
  if (stored is! int) {
    return Err(
      MalformedRmdxError('root "$_kSchemaVersion" is $stored, expected an int'),
    );
  }
  if (stored > kRmdxSchemaVersion) {
    return Err(
      NewerRmdxSchemaError(
        storedSchemaVersion: stored,
        supportedSchemaVersion: kRmdxSchemaVersion,
      ),
    );
  }
  switch (migrateRmdxToCurrent(raw, storedSchemaVersion: stored)) {
    case Err(:final error):
      return Err(error);
    case Ok(value: final migrated):
      try {
        return Ok(
          DeviceTemplateFile(
            templateId: TemplateId(
              asStr(migrated[_kTemplateId], 'rmdx.$_kTemplateId'),
            ),
            version: asInt(migrated[_kVersion], 'rmdx.$_kVersion'),
            contentHash: asStr(
              migrated[_kContentHash],
              'rmdx.$_kContentHash',
            ),
            body: templateBodyFromJson(
              asJsonMap(migrated[_kBody], 'rmdx.$_kBody'),
            ),
            signalFamilies: signalFamiliesFromJson(
              migrated[_kSignalFamilies],
              'rmdx.$_kSignalFamilies',
            ),
          ),
        );
      } on Object catch (e) {
        return Err(e);
      }
  }
}

/// The `.rpdx` migration chain: `storedSchemaVersion` to
/// [kRmdxSchemaVersion]. Never throws (CR-093).
///
/// **IT WAS EMPTY UNTIL DR-134 AND THE SEAM PAID FOR ITSELF.** This
/// function's own words were that it buys "the SEAM plus the refusal
/// below, so that the first person to bump [kRmdxSchemaVersion] adds a
/// row to a table that already exists instead of discovering that `.rpdx`
/// never had a chain and inventing one under deadline". That person
/// arrived, and adding v1 to v2 was a row. AC-050/A8.2 requires the
/// chain; nothing said it had to have steps in it, and now it has one.
///
/// **A version this build cannot reach is an ERROR, not a shrug**, which
/// is `UnmigratableSchemaError`'s argument transplanted: the contract to
/// the decoder downstream is "whatever you get back is
/// [kRmdxSchemaVersion]-shaped", and a chain that stops early breaks
/// exactly that while the decoder produces a `TemplateBody` that looks
/// healthy. The live way to get here is a hand-edited or mangled
/// `"schemaVersion": 0`, which clears the newer-than check above and
/// would otherwise be adopted.
Outcome<JsonMap> migrateRmdxToCurrent(
  JsonMap raw, {
  required int storedSchemaVersion,
}) {
  if (storedSchemaVersion == kRmdxSchemaVersion) return Ok(raw);
  if (storedSchemaVersion == 3) return Ok(_migrateRmdxV3ToV4(raw));
  if (storedSchemaVersion == 2) {
    return Ok(_migrateRmdxV3ToV4(_migrateRmdxV2ToV3(raw)));
  }
  if (storedSchemaVersion == 1) {
    return switch (_migrateRmdxV1ToV2(raw)) {
      Ok(value: final v2) => Ok(_migrateRmdxV3ToV4(_migrateRmdxV2ToV3(v2))),
      Err(:final error) => Err(error),
    };
  }
  return Err(
    MalformedRmdxError(
      'no migration from $_kSchemaVersion $storedSchemaVersion to '
      '$kRmdxSchemaVersion',
    ),
  );
}

/// v1 to v2: `PortDef.carriedProtocols` is gone (DR-134 §11.133).
///
/// **AND THE `contentHash` IS RECOMPUTED, WHICH IS THE HALF THAT NEEDED A
/// DECISION.** That value is tamper evidence: it is taken over
/// `templateBodyToJson`'s canonical bytes, and this migration changes
/// those bytes, so every v1 file would otherwise import reporting
/// `mismatched` for a reason that has nothing to do with its content.
///
/// A recomputed hash cannot attest to what the exporter wrote, and that
/// is the cost, taken deliberately. The alternative is worse: a warning
/// that fires on every older file is one a person learns to click past,
/// and then the check is gone for the files it was built for. Verification
/// still means what it says for anything written at v2, which is every
/// file from here on.
///
/// **IT HASHES ITS OWN RAW OUTPUT, AND IT USED TO DECODE INSTEAD.** Until
/// DR-171 this step decoded the body with this build's decoder and hashed
/// that, which is right only while it is the chain's last step. With
/// v2 to v3 behind it, a decoded v1 body is a v3 reading of a v2 map,
/// the hazard docs/03 §9.2 keeps migration on raw maps to avoid. Each
/// step now hashes the canonical bytes of what it hands on.
Outcome<JsonMap> _migrateRmdxV1ToV2(JsonMap raw) {
  try {
    final migrated = JsonMap.of(raw);
    final body = migrated[_kBody];
    if (body is Map) {
      final ports = body['ports'];
      if (ports is List) {
        for (final port in ports) {
          if (port is! Map) continue;
          port.remove('carriedProtocols');
        }
      }
      migrated[_kContentHash] = canonicalBodyHash(body);
    }
    migrated[_kSchemaVersion] = 2;
    return Ok(migrated);
  } on Object catch (e) {
    // A MALFORMED BODY IS THE DECODER'S ERROR TO REPORT, not this
    // function's to swallow: `readRmdxJsonTree` decodes next and names
    // the real key path.
    return Err(e);
  }
}

/// v2 to v3: `PowerProfile`'s two outlet counts are gone (DR-171
/// §11.170.3), through the step `.rppj` and `.rpda` share.
JsonMap _migrateRmdxV2ToV3(JsonMap raw) {
  final migrated = JsonMap.of(raw);
  final body = migrated[_kBody];
  if (body is Map) {
    migrated[_kContentHash] = retireOutletKeys(body, migrated[_kContentHash]);
  }
  migrated[_kSchemaVersion] = 3;
  return migrated;
}

/// v3 to v4: nothing moves (DR-245 §11.244.1). A v3 file carries no
/// signal families, and an absent `signalFamilies` already reads as none,
/// so the step only restamps the version the decoder is promised.
JsonMap _migrateRmdxV3ToV4(JsonMap raw) =>
    JsonMap.of(raw)..[_kSchemaVersion] = 4;
