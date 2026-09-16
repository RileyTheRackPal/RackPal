// The `.rmda` codec: many device templates in one file (`#239`, DR-015
// §11.15.3–§11.15.4).
//
// ═══════════════════════════════════════════════════════════════════════
// IT IS THE `.rpdx` CODEC WITH A LIST IN IT, AND THAT IS THE RULING
// ═══════════════════════════════════════════════════════════════════════
// DR-015 §11.15.4: *"one JSON file holding a manifest and an array of
// `TemplateBody`, in the `.rpdx` regime, with the `.rpdx` migration chain
// reused rather than a second one invented."* `rmdx_codec.dart`'s own
// header states the same relationship from the other end, which is why
// this file is short: the body encoding, the canonical byte convention,
// the kind guard, the version refusal and the import limits all already
// exist and are called rather than restated.
//
// **NOT A ZIP, and the question is closed.** §11.15.4 makes that the
// ruling's one real content: the zip existed to carry per-face device
// images, images are cut (AC-057), and a zip of pure JSON would buy
// compression at the price of the zip-slip, entry-count and
// decompression-bomb surface D8 lists as needed-and-absent. The accepted
// cost is stated there plainly: no compression, a few MB where a zip
// would be a few hundred KB, in a file people email once.
//
// ═══════════════════════════════════════════════════════════════════════
// ONE READING OF THE RULING IS RECORDED HERE RATHER THAN MADE QUIETLY
// ═══════════════════════════════════════════════════════════════════════
// §11.15.4 says *"an array of `TemplateBody`"*. This writes an array of
// the same ENTRY a `.rpdx` carries: `{templateId, version, contentHash,
// body}`. The difference is identity, and three things already ruled need
// it:
//
//   * **CR-050's version chain.** A bare body has no `version`, so a
//     library could not hold two versions of one template and a re-export
//     would flatten the chain.
//   * **DR-101's collision handling.** It resolves on `templateId`; with
//     bare bodies every import would re-derive one from the display name
//     through `templateIdFor`, so a template's identity would change
//     merely by travelling.
//   * **`#241`'s provenance and AC-042's hash.** Neither has anything to
//     attach to on a body alone.
//
// The ruling's subject was the CONTAINER (not a zip, one file, one chain)
// and the entry shape was not what it was deciding. This is read as
// consistent with it rather than as a departure, and it is flagged so the
// next person can disagree with a sentence rather than reverse-engineer a
// choice.
import 'dart:convert';
import 'dart:typed_data';

import 'package:rackpal_core/src/library/rmdx_codec.dart';
import 'package:rackpal_core/src/persistence/codec.dart';
import 'package:rackpal_core/src/persistence/json_codec.dart';
import 'package:rackpal_core/src/persistence/json_limits.dart';
import 'package:rackpal_core/src/persistence/json_util.dart';
import 'package:rackpal_core/src/persistence/outlet_key_retirement.dart';
import 'package:rackpal_core/src/units/ids.dart';
import 'package:rackpal_core/src/util/outcome.dart';

/// The root `kind` tag every `.rpda` carries.
///
/// **DISTINCT FROM [kRmdxKind], and that is what makes "you picked the
/// wrong file" a typed refusal.** The two formats are structurally
/// similar enough that a `.rpdx` handed to this reader would otherwise
/// fail on a missing `templates` key, which reports a shape problem for
/// what is really a wrong-file problem.
const String kRmdaKind = 'device-library';

/// The `.rpda` schema version this build writes and understands.
///
/// **THE SAME CHAIN AS `.rmdx`, NOT A SECOND ONE** (DR-015 §11.15.4). The
/// two formats move together by construction: a `.rpda` is `.rpdx`
/// entries in a list, so a change to the entry shape is a change to both
/// and one number keeps them from disagreeing about which.
const int kRmdaSchemaVersion = kRmdxSchemaVersion;

const String _kSchemaVersion = 'schemaVersion';
const String _kKind = 'kind';
const String _kName = 'name';
const String _kTemplates = 'templates';

/// A device library: a name and the templates it holds.
final class DeviceLibraryFile {
  const DeviceLibraryFile({required this.name, required this.templates});

  /// What this library calls itself.
  ///
  /// **THE MANIFEST IS ONE FIELD, DELIBERATELY.** DR-015 does not
  /// enumerate the manifest, and every candidate beyond a name is either
  /// derivable or a liability: a template COUNT disagrees with the array
  /// the first time somebody hand-edits one (`docs/13` D13's shape, in a
  /// file), a created-at is a fact about an export rather than about the
  /// library, and an author is `submittedBy`'s job on the template
  /// (DR-033) and not the pack's. A field is added when something reads
  /// it.
  final String name;

  final List<DeviceTemplateFile> templates;

  @override
  String toString() =>
      'DeviceLibraryFile($name, ${templates.length} templates)';
}

/// Refused: the root `kind` is missing or is not [kRmdaKind].
final class NotADeviceLibraryError implements Exception {
  const NotADeviceLibraryError(this.kind);

  final Object? kind;

  @override
  String toString() =>
      'NotADeviceLibraryError: root "kind" key is $kind, '
      'expected "$kRmdaKind".';
}

/// Refused: the file's `schemaVersion` is newer than this build reads.
///
/// **REFUSED RATHER THAN PARTIALLY READ**, for `.rpdx`'s reason:
/// `TemplateBody` is app-defined and closed (AC-012) with no `unknown`
/// passthrough, so a newer library would silently drop what it did not
/// model on every template in it.
final class NewerRmdaSchemaError implements Exception {
  const NewerRmdaSchemaError({
    required this.storedSchemaVersion,
    required this.supportedSchemaVersion,
  });

  final int storedSchemaVersion;
  final int supportedSchemaVersion;

  @override
  String toString() =>
      'NewerRmdaSchemaError: file is schemaVersion $storedSchemaVersion '
      'but this build only understands $supportedSchemaVersion.';
}

/// Refused: the envelope is structurally malformed.
final class MalformedRmdaError implements Exception {
  const MalformedRmdaError(this.message);

  final String message;

  @override
  String toString() => 'MalformedRmdaError: $message';
}

/// [file] as the plain JSON tree a `.rpda` holds.
JsonMap rmdaToJsonTree(DeviceLibraryFile file) => <String, Object?>{
  _kSchemaVersion: kRmdaSchemaVersion,
  _kKind: kRmdaKind,
  _kName: file.name,
  _kTemplates: [
    for (final t in file.templates)
      <String, Object?>{
        'templateId': t.templateId.v,
        'version': t.version,
        'contentHash': t.contentHash,
        'body': templateBodyToJson(t.body),
      },
  ],
};

/// [file] as the canonical bytes that go on disk.
///
/// The same `encodeCanonicalJsonBytes` every other format uses, so
/// "sorted how?" has one answer in this product rather than three.
Uint8List encodeRmdaBytes(DeviceLibraryFile file) =>
    Uint8List.fromList(encodeCanonicalJsonBytes(rmdaToJsonTree(file)));

/// Bytes to a [DeviceLibraryFile]. Never throws (CR-093).
///
/// **THE IMPORT LIMITS RUN FIRST**, inherited rather than restated
/// (AC-058/D8): DR-015 §11.15.4's whole argument for one JSON file is
/// that it *"inherits AC-058/D8's existing JSON depth and size limits and
/// introduces no new attack surface at all"*. A library is the biggest
/// file this product reads, so it is the one where the cap matters most.
Outcome<DeviceLibraryFile> readRmdaBytes(
  Uint8List bytes, {
  JsonLimits limits = const JsonLimits(),
}) {
  if (looksLikeZip(bytes)) {
    // A ZIP HERE IS THE MOST LIKELY WRONG FILE OF ALL, because `.rmlib`
    // WAS specified as one and anybody carrying an old pack has one.
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
    tree = asJsonMap(jsonDecode(utf8.decode(bytes)), 'rmda root');
    // `on Object`, not `on Exception`: StackOverflowError and
    // OutOfMemoryError are Errors and an `on Exception` walks past both.
  } on Object catch (e) {
    return Err(e);
  }
  return readRmdaJsonTree(tree);
}

/// A parsed JSON tree to a [DeviceLibraryFile]. Never throws (CR-093).
Outcome<DeviceLibraryFile> readRmdaJsonTree(JsonMap raw) {
  // KIND BEFORE VERSION, for `.rpdx`'s reason: a `.rppj` and a `.rpdx`
  // both carry a schemaVersion, so checking it first would report the
  // wrong file as the right file from the wrong era.
  final kind = raw[_kKind];
  if (kind != kRmdaKind) return Err(NotADeviceLibraryError(kind));

  final stored = raw[_kSchemaVersion];
  if (stored is! int) {
    return Err(
      MalformedRmdaError('root "$_kSchemaVersion" is $stored, expected an int'),
    );
  }
  if (stored > kRmdaSchemaVersion) {
    return Err(
      NewerRmdaSchemaError(
        storedSchemaVersion: stored,
        supportedSchemaVersion: kRmdaSchemaVersion,
      ),
    );
  }
  // v2 TO v3 IS THE CHAIN'S FIRST STEP: `.rpdx`'s entry step, run over
  // every entry (DR-171 §11.170.3). Anything older is still refused,
  // because no `.rpda` was ever written below 2.
  var tree = raw;
  if (stored == 2) {
    tree = _migrateRmdaV2ToV3(raw);
  } else if (stored != kRmdaSchemaVersion) {
    return Err(
      MalformedRmdaError(
        'no migration from $_kSchemaVersion $stored to $kRmdaSchemaVersion',
      ),
    );
  }

  try {
    final name = asStr(tree[_kName], 'rmda.$_kName');
    final entries = asJsonList(tree[_kTemplates], 'rmda.$_kTemplates');
    final templates = <DeviceTemplateFile>[];
    for (var i = 0; i < entries.length; i++) {
      final e = asJsonMap(entries[i], 'rmda.$_kTemplates[$i]');
      templates.add(
        DeviceTemplateFile(
          templateId: TemplateId(
            asStr(e['templateId'], 'rmda.$_kTemplates[$i].templateId'),
          ),
          version: asInt(e['version'], 'rmda.$_kTemplates[$i].version'),
          contentHash: asStr(
            e['contentHash'],
            'rmda.$_kTemplates[$i].contentHash',
          ),
          body: templateBodyFromJson(
            asJsonMap(e['body'], 'rmda.$_kTemplates[$i].body'),
          ),
        ),
      );
    }
    return Ok(DeviceLibraryFile(name: name, templates: templates));
  } on Object catch (e) {
    return Err(e);
  }
}

/// v2 to v3 over every entry: `.rpdx`'s step, so the two formats cannot
/// disagree about which bodies were edited (DR-171 §11.170.3).
JsonMap _migrateRmdaV2ToV3(JsonMap raw) {
  final migrated = JsonMap.of(raw);
  final entries = migrated[_kTemplates];
  if (entries is List) {
    for (final entry in entries) {
      if (entry is! Map) continue;
      final body = entry['body'];
      if (body is! Map) continue;
      entry['contentHash'] = retireOutletKeys(body, entry['contentHash']);
    }
  }
  migrated[_kSchemaVersion] = 3;
  return migrated;
}
