// The concrete DocumentCodec (docs/02-data-model.md §6, CR-091/092/117):
// RackDocument <-> the plain, pretty-printed, key-sorted UTF-8 JSON
// `.rackpal` container. Hand-written both directions, no code
// generation, no reflection.
//
// DRIFT / SCOPING NOTES (read once, applies throughout this file):
//  * Nullable fields omit their key when null, never write an explicit
//    `null` (CR-114, G4) — see `putIfNotNull` (json_util.dart). This
//    file's own §6.2 worked example shows a few explicit `null`s (e.g.
//    `"pairNumber": null`); that listing self-declares it is "not itself
//    byte-identical to" the real fixture it was derived from, so this
//    codec follows the binding §6.1 contract table (absent key) instead.
//  * `Rgb` serializes as an 8-hex-digit `#AARRGGBB` string (`toHexArgb`)
//    rather than the 6-digit opaque form the worked example shows —
//    lossless (captures alpha) where the shorter form would silently
//    drop it; every example value happens to be opaque, so both forms
//    are visually consistent with it, this one just doesn't lose data.
//  * `NetworkConfig`/`PoeAssignment` (port.dart), `SignalFamilyDef`/
//    `ConnectorTypeDef`/`MediaTypeDef` (registries.dart) and
//    `RevisionEntry` (rack_document.dart) each have their own model-level
//    "M0 MINIMAL SHAPE" doc comment; the §6.2 worked example shows a
//    DIFFERENT, richer field set for each of these than the Dart class
//    actually has. This codec always serializes the ACTUAL DART FIELDS
//    (the thing it can honestly round-trip), never the drifted example's
//    invented fields — noted again at each specific spot below.
//  * `Registries.connectorTypes`/`mediaTypes` serialize under the wire
//    keys `"connectors"`/`"media"` (matching the worked example), same
//    relationship as the Len/Mass "Nm"/"Ug" suffix convention: the wire
//    name and the Dart field name are allowed to differ for a documented
//    reason.
//  * Enum unknown(raw) fallback (§6.1) is implemented and unit-tested
//    end-to-end for `LifecycleStatus`/`Severity` (see enum_wire.dart's
//    header comment for the full scoping rationale); every other enum in
//    the model decodes via the strict, throwing `decodeEnumStrict`, which
//    surfaces as a whole-document `Err` at the `read()` boundary rather
//    than a silent guess.
import 'dart:convert';
import 'dart:typed_data';

import 'package:rackpal_core/src/idformat/collision_policy.dart';
import 'package:rackpal_core/src/idformat/id_format.dart';
import 'package:rackpal_core/src/model/acked_finding.dart';
import 'package:rackpal_core/src/model/circuit.dart';
import 'package:rackpal_core/src/model/conductor.dart';
import 'package:rackpal_core/src/model/device_glyph.dart';
import 'package:rackpal_core/src/model/device_instance.dart';
import 'package:rackpal_core/src/model/entity_meta.dart';
import 'package:rackpal_core/src/model/enums.dart';
import 'package:rackpal_core/src/model/gang.dart';
import 'package:rackpal_core/src/model/jacket_color.dart';
import 'package:rackpal_core/src/model/link.dart';
import 'package:rackpal_core/src/model/location.dart';
import 'package:rackpal_core/src/model/net.dart';
import 'package:rackpal_core/src/model/note.dart';
import 'package:rackpal_core/src/model/outlet.dart';
import 'package:rackpal_core/src/model/pathway.dart';
import 'package:rackpal_core/src/model/placement.dart';
import 'package:rackpal_core/src/model/plan.dart';
import 'package:rackpal_core/src/model/port.dart';
import 'package:rackpal_core/src/model/project_info.dart';
import 'package:rackpal_core/src/model/project_settings.dart';
import 'package:rackpal_core/src/model/rack.dart';
import 'package:rackpal_core/src/model/rack_document.dart';
import 'package:rackpal_core/src/model/registries.dart';
import 'package:rackpal_core/src/model/rule_override.dart';
import 'package:rackpal_core/src/model/service.dart';
import 'package:rackpal_core/src/model/sheet.dart';
import 'package:rackpal_core/src/model/sheet_item.dart';
import 'package:rackpal_core/src/model/structure_body.dart';
import 'package:rackpal_core/src/model/template.dart';
import 'package:rackpal_core/src/model/tombstone.dart';
import 'package:rackpal_core/src/model/zero_u_channel.dart';
import 'package:rackpal_core/src/persistence/codec.dart';
import 'package:rackpal_core/src/persistence/enum_wire.dart';
import 'package:rackpal_core/src/persistence/json_limits.dart';
import 'package:rackpal_core/src/persistence/json_util.dart';
import 'package:rackpal_core/src/persistence/migrations.dart';
import 'package:rackpal_core/src/persistence/schema.dart';
import 'package:rackpal_core/src/units/ids.dart';
import 'package:rackpal_core/src/units/len.dart';
import 'package:rackpal_core/src/units/mass.dart';
import 'package:rackpal_core/src/units/permille.dart';
import 'package:rackpal_core/src/units/pt.dart';
import 'package:rackpal_core/src/units/px_pt.dart';
import 'package:rackpal_core/src/units/rgb.dart';
import 'package:rackpal_core/src/util/outcome.dart';

/// The M0 `DocumentCodec` implementation — plain JSON, hand-written both
/// directions.
///
/// THE PIPELINE IS EXPOSED IN HALVES AS WELL AS WHOLE. [write] and [read]
/// are the compositions; [encodeToJsonTree]/[encodeJsonTreeBytes] and
/// [parseDocumentJsonTree]/[readFromJsonTree] are the same two pipelines
/// split at the plain-JSON-tree boundary. Byte-exactness (CR-117) is
/// preserved BY CONSTRUCTION — the composition is the old single-step
/// body verbatim — so the existing round-trip corpus still guards it.
///
/// WHY THE SPLIT EXISTS. A caller that wants to serialize off the UI
/// thread (AC-006, CR-099) needs to snapshot the document at a
/// well-defined instant and then do the expensive sort+encode+utf8
/// elsewhere. Handing a live `RackDocument` to `Isolate.run` does NOT do
/// that: Dart does not document *when* a captured mutable object graph is
/// copied, so an edit racing the spawn could be half-included. Splitting
/// at the tree makes the snapshot explicit and synchronous, and means the
/// only thing crossing the isolate boundary is plain
/// Map/List/String/int/bool/null — no property of the 30-class mutable
/// document graph has to be true for it to work.
///
/// Do not "simplify" this back into a single `Isolate.run(() =>
/// write(doc))`. That reintroduces a torn-snapshot race no test can see.
final class JsonDocumentCodec extends DocumentCodec {
  const JsonDocumentCodec();

  @override
  Uint8List write(RackDocument document) =>
      encodeJsonTreeBytes(encodeToJsonTree(document));

  @override
  Outcome<RackDocument> read(Uint8List bytes) {
    switch (parseDocumentJsonTree(bytes)) {
      case Err(:final error):
        return Err(error);
      case Ok(value: final root):
        return readFromJsonTree(root);
    }
  }

  /// Phase 1 of [write]: the live document to a plain JSON tree.
  /// Synchronous and cheap; run it on the main isolate so the snapshot is
  /// taken at a known instant.
  JsonMap encodeToJsonTree(RackDocument document) =>
      _encodeRackDocument(document);
}

/// The `minReaderVersion` [doc] must be stamped with.
///
/// [kMinReaderVersion] for an ordinary document, and
/// [kPlanMinReaderVersion] for one carrying PLAN DATA: any underlay, any
/// room outline, or any pin on a `Rack`, an `Outlet` or an
/// `OffRackPlacement` (DR-136 §11.135.2, DR-050).
///
/// ═══════════════════════════════════════════════════════════════════════
/// WHY THE STAMP AND NOT THE PASSTHROUGH
/// ═══════════════════════════════════════════════════════════════════════
/// DR-019 §11.18.1 named the hazard exactly: a build predating the Plan
/// view, opening a file that has pins, SILENTLY DROPS THEM ON SAVE.
/// §11.18.2(5) bought an `unknown` map on `Placement` and `Outlet` as the
/// remedy, and M3-I built a RESERVED CONTAINER rather than a harvester,
/// correctly and with the limitation stated in capitals in both
/// `placement.dart` and `_unknownBag` below. A sibling key like `planPin`
/// was never covered by it, so the remedy does not reach the hazard.
///
/// This closes it from the other end. An older build meeting
/// `minReaderVersion: 5` opens the document READ-ONLY and cannot
/// overwrite it, so the loss becomes a refusal somebody notices instead
/// of a deletion nobody does.
///
/// **`riseAllowance` DELIBERATELY DOES NOT COUNT.** It is an ordinary
/// additive optional field on `tia570Grade`'s precedent (DR-024): an
/// older build drops it exactly as it already drops those, and a number
/// somebody can retype is not a drawing somebody spent an afternoon
/// making. Widening this predicate to every new optional field would make
/// every document unopenable on every older build, which is the opposite
/// of what `kMinReaderVersion` exists for.
int documentMinReaderVersion(RackDocument doc) {
  if (doc.underlays.isNotEmpty) return kPlanMinReaderVersion;
  // A ROOM OUTLINE COUNTS, AND THE ARGUMENT IS THIS PREDICATE'S OWN
  // (DR-050, `LEN-A/1`). `riseAllowance` is excluded below because *"a
  // number somebody can retype is not a drawing somebody spent an
  // afternoon making"*. An outline is the drawing.
  //
  // **IT IS NOT COVERED BY THE UNDERLAY CHECK ABOVE, THOUGH IT VERY NEARLY
  // IS.** An outline names an underlay, so while one is present that line
  // already returns 5. `RemovePlanUnderlayCommand` clears the pins it
  // orphans and `LEN-A/2` gives outlines the same treatment, so through
  // the command path an outline cannot outlive its underlay. That is an
  // invariant of the COMMANDS, not of the format, and CR-093 lets a
  // hand-edited file carry an outline with no underlay beside it. Relying
  // on the line above would make this predicate correct by coincidence and
  // silently wrong the first time the coincidence broke, which is exactly
  // why the four checks below exist rather than one.
  for (final loc in doc.locations.values) {
    if (loc.planOutline != null) return kPlanMinReaderVersion;
  }
  for (final rack in doc.racks.values) {
    if (rack.planPin != null) return kPlanMinReaderVersion;
  }
  for (final outlet in doc.outlets.values) {
    if (outlet.planPin != null) return kPlanMinReaderVersion;
  }
  for (final device in doc.devices.values) {
    final placement = device.placement;
    if (placement is OffRackPlacement && placement.planPin != null) {
      return kPlanMinReaderVersion;
    }
  }
  return kMinReaderVersion;
}

/// Phase 2 of [JsonDocumentCodec.write]: a plain JSON tree to the
/// canonical sorted, pretty-printed UTF-8 bytes.
///
/// TOP-LEVEL AND ISOLATE-SAFE ON PURPOSE — this is the expensive half
/// (deep key sort, encode, UTF-8) and the half a caller runs in
/// `Isolate.run`. It closes over nothing and touches no instance state.
Uint8List encodeJsonTreeBytes(JsonMap tree) =>
    Uint8List.fromList(encodeCanonicalJsonBytes(tree));

/// Phase 1 of [JsonDocumentCodec.read]: bytes to a plain JSON tree, with
/// the zip sniff and both import-hardening limits (§9.5) run FIRST.
///
/// Top-level and isolate-safe for the same reason as
/// [encodeJsonTreeBytes]; both the `Ok` payload and every `Err` it can
/// produce are plain data. Never throws (CR-093).
///
/// The limits run before `jsonDecode` because doing it after would mean
/// allocating a tree that is already known to be refused. What they are
/// actually protecting is the WRITE side — `deepSortKeys` and
/// `JsonEncoder` are recursive and throw an uncatchable-by-`on Exception`
/// `StackOverflowError` past ~10 000 levels. See json_limits.dart, which
/// records the measurements.
Outcome<JsonMap> parseDocumentJsonTree(
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
  try {
    return Ok(asJsonMap(jsonDecode(utf8.decode(bytes)), 'root'));
    // `on Object`, NOT `on Exception`. CR-093 says never throws, and an
    // `on Exception` clause walks straight past every `Error` — which is
    // not a hypothetical here: json_limits.dart's own header records that
    // the recursive descent in `deepSortKeys`/`JsonEncoder` raises
    // `StackOverflowError`, and a file near the 64 MB cap can raise
    // `OutOfMemoryError` inside `jsonDecode`. Both are Errors. Escaping
    // here means an unhandled future in whichever caller forgot to await
    // it, which reaches the user as Ctrl+O doing NOTHING AT ALL — no
    // dialog, no log, no crash. A reported failure beats a silent one
    // even when the cause is our own bug.
  } on Object catch (e) {
    return Err(e);
  }
}

/// Phase 2 of [JsonDocumentCodec.read]: migrate the raw envelope, then
/// typed-decode it. Never throws (CR-093).
///
/// Separate from [parseDocumentJsonTree] so a caller that parsed in an
/// isolate can still run the migration chain and the typed decode on the
/// main isolate, where the resulting `RackDocument` is needed.
Outcome<RackDocument> readFromJsonTree(JsonMap raw) {
  try {
    switch (migrateToCurrent(raw)) {
      case Err(:final error):
        return Err(error);
      case Ok(value: final migratedDoc, :final openReadOnly):
        return Ok(
          _decodeRackDocument(migratedDoc.raw),
          openReadOnly: openReadOnly,
        );
    }
    // `on Object` for the same reason as [parseDocumentJsonTree]: a
    // `TypeError` from a decoder change, or a `StackOverflowError` from a
    // pathologically nested payload that slipped under the depth cap, is
    // an Error and would otherwise escape a function whose whole contract
    // is that it does not throw.
  } on Object catch (e) {
    return Err(e);
  }
}

// --- Small wrapper-type helpers (Uuid/Len/Mass/Rgb/IdFormat) --------------
//
// Thin, repeated everywhere below: unwrap the extension type to its plain
// wire value, or wrap a decoded plain value back into it.

Uuid _decodeUuid(Object? value, String context) => Uuid(asStr(value, context));

Uuid? _decodeUuidOrNull(Object? value, String context) =>
    value == null ? null : Uuid(asStr(value, context));

JacketColorId? _decodeJacketColorIdOrNull(Object? value, String context) =>
    value == null ? null : JacketColorId(asStr(value, context));

Len _decodeLen(Object? value, String context) => Len(asInt(value, context));

Len? _decodeLenOrNull(Object? value, String context) =>
    value == null ? null : Len(asInt(value, context));

Mass? _decodeMassOrNull(Object? value, String context) =>
    value == null ? null : Mass(asInt(value, context));

String _encodeRgb(Rgb value) => value.toHexArgb();

Rgb _decodeRgb(String raw) => Rgb.fromHex(raw);

Rgb? _decodeRgbOrNull(Object? value, String context) =>
    value == null ? null : Rgb.fromHex(asStr(value, context));

String _encodeIdFormat(IdFormat value) => value.pattern;

/// Decodes a designator pattern, REFUSING one the renderer cannot use.
///
/// ═══════════════════════════════════════════════════════════════════════
/// `IdFormat`'s CONSTRUCTOR VALIDATES NOTHING, AND THIS IS WHERE THAT BIT
/// ═══════════════════════════════════════════════════════════════════════
/// `const IdFormat(this.pattern)` stores the string and checks none of it;
/// `IdFormatSyntaxException` comes from `_parsePattern`, which only
/// `render()` calls. So this used to accept ANY string from a file, and a
/// hand-edited or corrupted `.rmpj` would open cleanly and then throw the
/// first time a designator was minted, a whole subsystem away from the
/// field that caused it.
///
/// **A FALLBACK TO THE DEFAULT WOULD BE THE SILENT GUESS THIS FILE'S OWN
/// HEADER REJECTS.** That header says every enum but two decodes through
/// the strict, throwing path "which surfaces as a whole-document `Err` at
/// the `read()` boundary rather than a silent guess". Substituting
/// `J{PORT_SEQ:2}` for a pattern its author did not write is exactly that
/// guess, and G4 forbids fabricating a value nobody supplied. So a bad
/// pattern refuses the document, and the message names the field.
///
/// TWO CHECKS, AND THE SAFE ONE GOES FIRST. `unrecognisedTokens()` is
/// regex-based and never throws, so it can report an unknown NAME as a
/// named list; `requiredTokens()` runs `_parsePattern`, which throws
/// `IdFormatSyntaxException` for a malformed pattern AND
/// `UnrecognisedTokenException` for an unknown name. The first draft
/// assumed the two checks were disjoint, ran the throwing one first, and
/// caught only the syntax type, so an unknown token escaped as an
/// unhandled exception and the message naming the field never fired.
///
/// Both types are caught anyway. If the regex and the parser ever
/// disagree about what a token is, the parser is authoritative and its
/// complaint should reach the reader rather than an unhandled throw.
IdFormat _decodeIdFormat(String raw, String context) {
  final format = IdFormat(raw);
  final unknown = format.unrecognisedTokens();
  if (unknown.isNotEmpty) {
    throw FormatException(
      'Unknown token${unknown.length == 1 ? '' : 's'} '
      '${unknown.join(', ')} in $context: '
      'a token the renderer does not know throws when a designator is '
      'minted, so it is refused here rather than at that point.',
    );
  }
  try {
    format.requiredTokens();
  } on IdFormatSyntaxException catch (e) {
    throw FormatException('Invalid pattern for $context: ${e.message}');
  } on UnrecognisedTokenException catch (e) {
    throw FormatException('Invalid pattern for $context: $e');
  }
  return format;
}

JsonMap _encodePt(Pt p) => {'gx': p.gx, 'gy': p.gy};

Pt _decodePt(JsonMap json) =>
    Pt(asInt(json['gx'], 'Pt.gx'), asInt(json['gy'], 'Pt.gy'));

// --- RackDocument: the envelope + the "document" wrapper ------------------

JsonMap _encodeRackDocument(RackDocument doc) {
  final document = <String, Object?>{
    'ackedFindings': {
      for (final e in doc.ackedFindings.entries)
        e.key.v: _encodeAckedFinding(e.value),
    },
    'circuits': {
      for (final e in doc.circuits.entries) e.key.v: _encodeCircuit(e.value),
    },
    'devices': {
      for (final e in doc.devices.entries)
        e.key.v: _encodeDeviceInstance(e.value),
    },
    'info': _encodeProjectInfo(doc.info),
    'links': {
      for (final e in doc.links.entries) e.key.v: _encodeLink(e.value),
    },
    'locations': {
      for (final e in doc.locations.entries) e.key.v: _encodeLocation(e.value),
    },
    'meta': _encodeEntityMeta(doc.meta),
    'nets': {
      for (final e in doc.nets.entries) e.key.v: _encodeNet(e.value),
    },
    'notes': {
      for (final e in doc.notes.entries) e.key.v: _encodeNote(e.value),
    },
    'outlets': {
      for (final e in doc.outlets.entries) e.key.v: _encodeOutlet(e.value),
    },
    'pathways': {
      for (final e in doc.pathways.entries) e.key.v: _encodePathway(e.value),
    },
    'ports': {
      for (final e in doc.ports.entries) e.key.v: _encodePort(e.value),
    },
    'racks': {
      for (final e in doc.racks.entries) e.key.v: _encodeRack(e.value),
    },
    // ═════════════════════════════════════════════════════════════════
    // OMITTED WHEN EMPTY, UNLIKE EVERY OTHER ENTITY MAP HERE
    // ═════════════════════════════════════════════════════════════════
    // The fourteen maps around this one write `{}` when they hold
    // nothing, which is what they have always done. This one does not,
    // and the difference is load-bearing rather than stylistic: writing
    // `"underlays": {}` would add a key to EVERY `.rmpj` in existence on
    // its next save, so no existing file would re-encode byte for byte,
    // and DR-136 §11.135.3's reasoning about why the schema advances
    // would become false in the same commit that stated it.
    //
    // It is also what CR-114 says and what this codec has twice recently
    // chosen: DR-105 §11.104.3 stopped writing 727 origin positions per
    // starter, and DR-134 §11.133 counted 737 empty arrays in
    // `apartment.rmpj` as a reason to delete a field. An absent map means
    // no underlays, which is exactly what an absent key has meant here
    // since M0.
    if (doc.underlays.isNotEmpty)
      'underlays': {
        for (final e in doc.underlays.entries)
          e.key.v: _encodePlanUnderlay(e.value),
      },
    'registries': _encodeRegistries(doc.registries),
    'revisionBlock': [
      for (final r in doc.revisionBlock) _encodeRevisionEntry(r),
    ],
    'settings': _encodeProjectSettings(doc.settings),
    'sheets': {
      for (final e in doc.sheets.entries) e.key.v: _encodeSheet(e.value),
    },
    'structures': {
      for (final e in doc.structures.entries)
        e.key.v: _encodeStructureBody(e.value),
    },
    'templates': {
      for (final e in doc.templates.entries)
        e.key: _encodeTemplateSnapshot(e.value),
    },
    'tombstones': {
      for (final e in doc.tombstones.entries)
        e.key.v: _encodeTombstone(e.value),
    },
  };

  return {
    kKeyAppVersion: doc.appVersion,
    kKeyCreatedAt: encodeDateTime(doc.createdAt),
    kKeyDocument: document,
    kKeyGenerator: kGeneratorName,
    kKeyId: doc.id.v,
    // THE VERSION STAMP DESCRIBES THESE BYTES, NOT THE FILE THEY CAME
    // FROM. `doc.schemaVersion` is the version the document was READ at;
    // re-emitting it is the single most dangerous thing this encoder
    // could do, because the value that a stamp is trusted for is exactly
    // "what shape is the payload below me".
    //
    // The case that makes it concrete. A future build (kSchemaVersion 3)
    // writes Smith.rackpal with new fields. THIS build opens it: the
    // minReaderVersion gate lets it through, `migrateToCurrent` returns
    // openReadOnly with the envelope untouched, and `_decodeRackDocument`
    // silently drops every v3 field it has no class member for. The user
    // then picks "Save a copy…". Re-emitting `doc.schemaVersion` would
    // write a file that ADVERTISES v3 while containing only v2 data — so
    // the next v3 reader sees its own version, runs no migration, applies
    // no read-only gate, and trusts a document whose v3 fields are gone.
    // That is the precise corruption the read-only gate exists to
    // prevent, arriving through the one door it left open.
    //
    // These bytes are produced by THIS encoder, so they are exactly a
    // `kSchemaVersion` document and they need exactly a
    // `kMinReaderVersion` reader. Both facts are properties of the code
    // below, not of the file the document was loaded from. `RackDocument`
    // keeps the fields it was read with (they are what the pre-update
    // snapshot and the migration bookkeeping reason about); the CONTAINER
    // is stamped from the constants.
    //
    // ═══════════════════════════════════════════════════════════════════
    // EXCEPT `minReaderVersion`, WHICH IS NOW A PROPERTY OF THE DOCUMENT
    // ═══════════════════════════════════════════════════════════════════
    // The one exception to the paragraph above, and it is deliberate
    // (DR-136 §11.135.2). A document carrying plan data needs a reader
    // that understands plans, and a document without it does not, so the
    // stamp is decided from the CONTENT rather than from the constants.
    // See [documentMinReaderVersion] for the hazard this closes and why
    // it is closed by refusing the write rather than preserving the field.
    kKeyMinReaderVersion: documentMinReaderVersion(doc),
    kKeyModifiedAt: encodeDateTime(doc.modifiedAt),
    kKeySchemaVersion: kSchemaVersion,
    kKeySequence: doc.sequence,
    kKeyUnknown: doc.unknown,
  };
}

RackDocument _decodeRackDocument(JsonMap root) {
  final document = asJsonMap(root[kKeyDocument], 'document');

  /// [optional] tolerates the KEY BEING ABSENT and is passed by exactly
  /// one caller.
  ///
  /// NOT THE DEFAULT, DELIBERATELY. A document missing `racks` is a
  /// damaged document, and decoding it as an empty map would open a
  /// project with the racks quietly gone rather than refusing it. Only
  /// `underlays` is optional, because the encoder OMITS it when empty so
  /// that existing files keep re-encoding byte for byte, and because a
  /// map that has never been written cannot be a map that went missing.
  Map<Uuid, T> decodeUuidKeyedMap<T>(
    String key,
    T Function(Uuid id, JsonMap json) decode, {
    bool optional = false,
  }) {
    if (optional && document[key] == null) return <Uuid, T>{};
    final json = asJsonMap(document[key], 'document.$key');
    return {
      for (final e in json.entries)
        Uuid(e.key): decode(
          Uuid(e.key),
          asJsonMap(e.value, 'document.$key[${e.key}]'),
        ),
    };
  }

  return RackDocument(
    id: Uuid(asStr(root[kKeyId], 'id')),
    appVersion: asStr(root[kKeyAppVersion], 'appVersion'),
    createdAt: decodeDateTime(asStr(root[kKeyCreatedAt], 'createdAt')),
    modifiedAt: decodeDateTime(asStr(root[kKeyModifiedAt], 'modifiedAt')),
    schemaVersion: asInt(root[kKeySchemaVersion], 'schemaVersion'),
    minReaderVersion: asInt(root[kKeyMinReaderVersion], 'minReaderVersion'),
    sequence: asInt(root[kKeySequence], 'sequence'),
    meta: _decodeEntityMeta(asJsonMap(document['meta'], 'document.meta')),
    info: _decodeProjectInfo(asJsonMap(document['info'], 'document.info')),
    settings: _decodeProjectSettings(
      asJsonMap(document['settings'], 'document.settings'),
    ),
    locations: decodeUuidKeyedMap('locations', _decodeLocation),
    racks: decodeUuidKeyedMap('racks', _decodeRack),
    devices: decodeUuidKeyedMap('devices', _decodeDeviceInstance),
    ports: decodeUuidKeyedMap('ports', _decodePort),
    nets: decodeUuidKeyedMap('nets', _decodeNet),
    links: decodeUuidKeyedMap('links', _decodeLink),
    pathways: decodeUuidKeyedMap('pathways', _decodePathway),
    outlets: decodeUuidKeyedMap('outlets', _decodeOutlet),
    structures: decodeUuidKeyedMap('structures', _decodeStructureBody),
    circuits: decodeUuidKeyedMap('circuits', _decodeCircuit),
    underlays: decodeUuidKeyedMap(
      'underlays',
      _decodePlanUnderlay,
      optional: true,
    ),
    sheets: decodeUuidKeyedMap('sheets', _decodeSheet),
    notes: decodeUuidKeyedMap('notes', _decodeNote),
    ackedFindings: decodeUuidKeyedMap('ackedFindings', _decodeAckedFinding),
    templates: {
      for (final e in asJsonMap(
        document['templates'],
        'document.templates',
      ).entries)
        e.key: _decodeTemplateSnapshot(
          asJsonMap(e.value, 'document.templates[${e.key}]'),
        ),
    },
    registries: _decodeRegistries(
      asJsonMap(document['registries'], 'document.registries'),
    ),
    revisionBlock: decodeObjectList(
      document['revisionBlock'],
      'document.revisionBlock',
      _decodeRevisionEntry,
    ),
    tombstones: decodeUuidKeyedMap('tombstones', _decodeTombstone),
    unknown: asJsonMap(
      root[kKeyUnknown] ?? const <String, Object?>{},
      'unknown',
    ),
  );
}

// --- EntityMeta ------------------------------------------------------------

JsonMap _encodeEntityMeta(EntityMeta meta) => {
  'createdAt': encodeDateTime(meta.createdAt),
  'updatedAt': encodeDateTime(meta.updatedAt),
  'updatedBy': meta.updatedBy,
  'localRevision': meta.localRevision,
  'unknown': meta.unknown,
};

EntityMeta _decodeEntityMeta(JsonMap json) => EntityMeta(
  createdAt: decodeDateTime(asStr(json['createdAt'], 'EntityMeta.createdAt')),
  updatedAt: decodeDateTime(asStr(json['updatedAt'], 'EntityMeta.updatedAt')),
  updatedBy: asStr(json['updatedBy'], 'EntityMeta.updatedBy'),
  localRevision: asInt(json['localRevision'], 'EntityMeta.localRevision'),
  unknown: asJsonMap(
    json['unknown'] ?? const <String, Object?>{},
    'EntityMeta.unknown',
  ),
);

// --- ProjectInfo / Address --------------------------------------------------

JsonMap _encodeAddress(Address a) {
  final json = <String, Object?>{};
  putIfNotNull(json, 'line1', a.line1);
  putIfNotNull(json, 'line2', a.line2);
  putIfNotNull(json, 'city', a.city);
  putIfNotNull(json, 'region', a.region);
  putIfNotNull(json, 'postalCode', a.postalCode);
  putIfNotNull(json, 'country', a.country);
  return json;
}

Address _decodeAddress(JsonMap json) => Address(
  line1: asStrOrNull(json['line1'], 'Address.line1'),
  line2: asStrOrNull(json['line2'], 'Address.line2'),
  city: asStrOrNull(json['city'], 'Address.city'),
  region: asStrOrNull(json['region'], 'Address.region'),
  postalCode: asStrOrNull(json['postalCode'], 'Address.postalCode'),
  country: asStrOrNull(json['country'], 'Address.country'),
);

JsonMap _encodeProjectInfo(ProjectInfo info) {
  final json = <String, Object?>{'projectName': info.projectName};
  putIfNotNull(json, 'projectNumber', info.projectNumber);
  putIfNotNull(json, 'drawingNumber', info.drawingNumber);
  putIfNotNull(json, 'clientName', info.clientName);
  if (info.siteAddress != null) {
    json['siteAddress'] = _encodeAddress(info.siteAddress!);
  }
  putIfNotNull(json, 'integratorName', info.integratorName);
  putIfNotNull(json, 'integratorContact', info.integratorContact);
  putIfNotNull(json, 'integratorLicense', info.integratorLicense);
  putIfNotNull(json, 'drawnBy', info.drawnBy);
  putIfNotNull(json, 'checkedBy', info.checkedBy);
  putIfNotNull(json, 'approvedBy', info.approvedBy);
  return json;
}

ProjectInfo _decodeProjectInfo(JsonMap json) => ProjectInfo(
  projectName: asStr(json['projectName'], 'ProjectInfo.projectName'),
  projectNumber: asStrOrNull(
    json['projectNumber'],
    'ProjectInfo.projectNumber',
  ),
  drawingNumber: asStrOrNull(
    json['drawingNumber'],
    'ProjectInfo.drawingNumber',
  ),
  clientName: asStrOrNull(json['clientName'], 'ProjectInfo.clientName'),
  siteAddress: decodeNullableObject(
    json,
    'siteAddress',
    'ProjectInfo.siteAddress',
    _decodeAddress,
  ),
  integratorName: asStrOrNull(
    json['integratorName'],
    'ProjectInfo.integratorName',
  ),
  integratorContact: asStrOrNull(
    json['integratorContact'],
    'ProjectInfo.integratorContact',
  ),
  integratorLicense: asStrOrNull(
    json['integratorLicense'],
    'ProjectInfo.integratorLicense',
  ),
  drawnBy: asStrOrNull(json['drawnBy'], 'ProjectInfo.drawnBy'),
  checkedBy: asStrOrNull(json['checkedBy'], 'ProjectInfo.checkedBy'),
  approvedBy: asStrOrNull(json['approvedBy'], 'ProjectInfo.approvedBy'),
);

// --- ProjectSettings / RuleOverride -----------------------------------------

JsonMap _encodeRuleOverride(RuleOverride r) => {
  'severity': encodeSeverity(r.severity),
  'reason': r.reason,
  'by': r.by,
  'at': encodeDateTime(r.at),
};

RuleOverride _decodeRuleOverride(JsonMap json) => RuleOverride(
  severity: decodeSeverity(asStr(json['severity'], 'RuleOverride.severity')),
  reason: asStr(json['reason'], 'RuleOverride.reason'),
  by: asStr(json['by'], 'RuleOverride.by'),
  at: decodeDateTime(asStr(json['at'], 'RuleOverride.at')),
);

/// All four keys, always. Every field is non-NULLABLE, and an empty
/// `meaning` is a VALUE — "the user has not said" — not an absence, so
/// `putIfNotNull` would be the wrong tool and would erase the
/// distinction on the way to disk.
JsonMap _encodeJacketColorDef(JacketColorDef d) => {
  'abbr': d.abbr,
  'color': _encodeRgb(d.color),
  'displayName': d.displayName,
  'meaning': d.meaning,
};

/// The three REQUIRED fields are strict; `meaning` is not.
///
/// `JacketColorDef.meaning` is the one field the model declares optional
/// (`this.meaning = ''`), and its default is a VALUE — "the user has not
/// said" (G4). `asStr(null, …)` THROWS, so requiring the key on disk made
/// a field the model says is optional mandatory in the file, and one
/// missing `"meaning"` — in a hand-edited `.rackpal`, or in the output
/// of an importer that only knows a name and a swatch — turned a whole
/// document into a "damaged file" dialog over a field whose absence and
/// whose empty value mean exactly the same thing.
///
/// Same reasoning, same shape, as `?? const <String, Object?>{}` on
/// `jacketColorConventions` below: absent and empty are indistinguishable
/// here, so the lenient read is the one that does not throw away a file.
/// The encoder still writes all four keys unconditionally, so nothing
/// this build writes ever exercises the fallback and no stored bytes move
/// (CR-117).
JacketColorDef _decodeJacketColorDef(JsonMap json, String context) =>
    JacketColorDef(
      displayName: asStr(json['displayName'], '$context.displayName'),
      abbr: asStr(json['abbr'], '$context.abbr'),
      color: _decodeRgb(asStr(json['color'], '$context.color')),
      meaning: asStrOrNull(json['meaning'], '$context.meaning') ?? '',
    );

JsonMap _encodeProjectSettings(ProjectSettings s) => {
  'displayUnits': encodeEnumName(s.displayUnits),
  'defaultRuNumbering': encodeEnumName(s.defaultRuNumbering),
  'defaultMirrorRearElevation': s.defaultMirrorRearElevation,
  'sheetNumbering': encodeEnumName(s.sheetNumbering),
  'deviceDesignatorFormat': _encodeIdFormat(s.deviceDesignatorFormat),
  'portDesignatorFormat': _encodeIdFormat(s.portDesignatorFormat),
  'linkDesignatorFormat': _encodeIdFormat(s.linkDesignatorFormat),
  'netNameFormat': _encodeIdFormat(s.netNameFormat),
  'outletFieldLabelFormat': _encodeIdFormat(s.outletFieldLabelFormat),
  'outletRackLabelFormat': _encodeIdFormat(s.outletRackLabelFormat),
  'designatorSeparator': s.designatorSeparator,
  'designatorPad': s.designatorPad,
  'collisionPolicy': encodeEnumName(s.collisionPolicy),
  'designatorBlockSize': s.designatorBlockSize,
  'ruleOverrides': {
    for (final e in s.ruleOverrides.entries)
      e.key: _encodeRuleOverride(e.value),
  },
  'familyColorOverrides': {
    for (final e in s.familyColorOverrides.entries)
      e.key.v: _encodeRgb(e.value),
  },
  // OMITTED WHEN EMPTY, and this is NOT the same call as the three maps
  // around it. `ruleOverrides`, `familyColorOverrides` and
  // `diversityFactorsByCategory` emit `{}` unconditionally because they
  // have done so since v1 — that empty object is already a byte of every
  // document ever written, so keeping it costs nothing. This key is NEW.
  // Emitting it unconditionally moves the bytes of every `.rackpal` file
  // that already exists on disk the moment it is loaded and saved, which
  // is exactly the CR-117 property (`write(read(bytes)) == bytes`) that
  // docs/03 §9.1 states and M0's exit criterion names. An empty map and an
  // absent key mean the identical thing to the decoder here
  // (`json['jacketColorConventions'] ?? {}`), so absent is the spelling
  // that is also backward-compatible.
  //
  // This shipped unconditional and was caught only after
  // `byte_roundtrip_test.dart` was repaired — until then that test
  // overwrote its own goldens before comparing, so it could not see a
  // format change to a stored document. See that file's history note.
  if (s.jacketColorConventions.isNotEmpty)
    'jacketColorConventions': {
      for (final e in s.jacketColorConventions.entries)
        e.key.v: _encodeJacketColorDef(e.value),
    },
  'diversityFactorsByCategory': {
    for (final e in s.diversityFactorsByCategory.entries) e.key: e.value.v,
  },
  'cableWasteFactor': s.cableWasteFactor.v,
  'defaultNetworkMedia': s.defaultNetworkMedia.v,
  'defaultRackHeightU': s.defaultRackHeightU,
  'defaultLineVolts': s.defaultLineVolts,
};

ProjectSettings _decodeProjectSettings(JsonMap json) => ProjectSettings(
  displayUnits: decodeEnumStrict(
    UnitSystem.values,
    asStr(json['displayUnits'], 'ProjectSettings.displayUnits'),
    'ProjectSettings.displayUnits',
  ),
  defaultRuNumbering: decodeEnumStrict(
    RuNumbering.values,
    asStr(json['defaultRuNumbering'], 'ProjectSettings.defaultRuNumbering'),
    'ProjectSettings.defaultRuNumbering',
  ),
  defaultMirrorRearElevation: asBool(
    json['defaultMirrorRearElevation'],
    'ProjectSettings.defaultMirrorRearElevation',
  ),
  sheetNumbering: decodeEnumStrict(
    SheetNumbering.values,
    asStr(json['sheetNumbering'], 'ProjectSettings.sheetNumbering'),
    'ProjectSettings.sheetNumbering',
  ),
  deviceDesignatorFormat: _decodeIdFormat(
    asStr(
      json['deviceDesignatorFormat'],
      'ProjectSettings.deviceDesignatorFormat',
    ),
    'ProjectSettings.deviceDesignatorFormat',
  ),
  portDesignatorFormat: _decodeIdFormat(
    asStr(json['portDesignatorFormat'], 'ProjectSettings.portDesignatorFormat'),
    'ProjectSettings.portDesignatorFormat',
  ),
  linkDesignatorFormat: _decodeIdFormat(
    asStr(json['linkDesignatorFormat'], 'ProjectSettings.linkDesignatorFormat'),
    'ProjectSettings.linkDesignatorFormat',
  ),
  netNameFormat: _decodeIdFormat(
    asStr(json['netNameFormat'], 'ProjectSettings.netNameFormat'),
    'ProjectSettings.netNameFormat',
  ),
  outletFieldLabelFormat: _decodeIdFormat(
    asStr(
      json['outletFieldLabelFormat'],
      'ProjectSettings.outletFieldLabelFormat',
    ),
    'ProjectSettings.outletFieldLabelFormat',
  ),
  outletRackLabelFormat: _decodeIdFormat(
    asStr(
      json['outletRackLabelFormat'],
      'ProjectSettings.outletRackLabelFormat',
    ),
    'ProjectSettings.outletRackLabelFormat',
  ),
  designatorSeparator: asStr(
    json['designatorSeparator'],
    'ProjectSettings.designatorSeparator',
  ),
  designatorPad: asInt(json['designatorPad'], 'ProjectSettings.designatorPad'),
  collisionPolicy: decodeEnumStrict(
    CollisionPolicy.values,
    asStr(json['collisionPolicy'], 'ProjectSettings.collisionPolicy'),
    'ProjectSettings.collisionPolicy',
  ),
  designatorBlockSize: asInt(
    json['designatorBlockSize'],
    'ProjectSettings.designatorBlockSize',
  ),
  ruleOverrides: {
    for (final e in asJsonMap(
      json['ruleOverrides'],
      'ProjectSettings.ruleOverrides',
    ).entries)
      e.key: _decodeRuleOverride(
        asJsonMap(e.value, 'ProjectSettings.ruleOverrides[${e.key}]'),
      ),
  },
  familyColorOverrides: {
    for (final e in asJsonMap(
      json['familyColorOverrides'],
      'ProjectSettings.familyColorOverrides',
    ).entries)
      SignalFamilyId(e.key): _decodeRgb(
        asStr(e.value, 'ProjectSettings.familyColorOverrides[${e.key}]'),
      ),
  },
  // THE `?? const {}` IS NOT DEFENSIVE PADDING. `asJsonMap(null, …)`
  // throws, and every file written before this field existed — including
  // the checked-in input golden `v1_templates_and_power.rackpal.json`,
  // which is never regenerated — has no such key. The strict form would
  // turn every already-shipped document into "damaged file". Same shape
  // as `MediaTypeDef.jacketOptions` below. Mutation: drop the `??` and
  // `migration_corpus_test.dart` goes red.
  jacketColorConventions: {
    for (final e in asJsonMap(
      json['jacketColorConventions'] ?? const <String, Object?>{},
      'ProjectSettings.jacketColorConventions',
    ).entries)
      JacketColorId(e.key): _decodeJacketColorDef(
        asJsonMap(e.value, 'ProjectSettings.jacketColorConventions[${e.key}]'),
        'ProjectSettings.jacketColorConventions[${e.key}]',
      ),
  },
  diversityFactorsByCategory: {
    for (final e in asJsonMap(
      json['diversityFactorsByCategory'],
      'ProjectSettings.diversityFactorsByCategory',
    ).entries)
      e.key: Permille(
        asInt(e.value, 'ProjectSettings.diversityFactorsByCategory[${e.key}]'),
      ),
  },
  cableWasteFactor: Permille(
    asInt(json['cableWasteFactor'], 'ProjectSettings.cableWasteFactor'),
  ),
  defaultNetworkMedia: MediaTypeId(
    asStr(json['defaultNetworkMedia'], 'ProjectSettings.defaultNetworkMedia'),
  ),
  defaultRackHeightU: asInt(
    json['defaultRackHeightU'],
    'ProjectSettings.defaultRackHeightU',
  ),
  defaultLineVolts: asInt(
    json['defaultLineVolts'],
    'ProjectSettings.defaultLineVolts',
  ),
);

// --- Location ---------------------------------------------------------------

JsonMap _encodeLocation(Location loc) {
  final json = <String, Object?>{
    'id': loc.id.v,
    'kind': encodeEnumName(loc.kind),
    'name': loc.name,
    'code': loc.code,
    'order': loc.order.v,
    'meta': _encodeEntityMeta(loc.meta),
  };
  putIfNotNull(json, 'parentId', loc.parentId?.v);
  putIfNotNull(json, 'floorNumber', loc.floorNumber);
  putIfNotNull(json, 'spaceCode', loc.spaceCode);
  putIfNotNull(
    json,
    'estimatedRunLengthFromRackNm',
    loc.estimatedRunLengthFromRack?.nm,
  );
  // The `Nm` suffix is the format's own convention for a `Len`, so the
  // wire name says its unit and a reader cannot mistake nanometres for
  // millimetres (docs/02 §6.1).
  putIfNotNull(json, 'riseAllowanceNm', loc.riseAllowance?.nm);
  putIfNotNull(
    json,
    'estimatedRunLengthOrigin',
    loc.estimatedRunLengthOrigin == null
        ? null
        : encodeEnumName(loc.estimatedRunLengthOrigin!),
  );
  putIfNotNull(
    json,
    'planOutline',
    loc.planOutline == null ? null : _encodeRoomOutline(loc.planOutline!),
  );
  return json;
}

Location _decodeLocation(Uuid id, JsonMap json) => Location(
  id: id,
  kind: decodeEnumStrict(
    LocationKind.values,
    asStr(json['kind'], 'Location.kind'),
    'Location.kind',
  ),
  name: asStr(json['name'], 'Location.name'),
  code: asStr(json['code'], 'Location.code'),
  order: FracIndex(asStr(json['order'], 'Location.order')),
  meta: _decodeEntityMeta(asJsonMap(json['meta'], 'Location.meta')),
  parentId: _decodeUuidOrNull(json['parentId'], 'Location.parentId'),
  floorNumber: asIntOrNull(json['floorNumber'], 'Location.floorNumber'),
  spaceCode: asStrOrNull(json['spaceCode'], 'Location.spaceCode'),
  estimatedRunLengthFromRack: _decodeLenOrNull(
    json['estimatedRunLengthFromRackNm'],
    'Location.estimatedRunLengthFromRackNm',
  ),
  riseAllowance: _decodeLenOrNull(
    json['riseAllowanceNm'],
    'Location.riseAllowanceNm',
  ),
  estimatedRunLengthOrigin: json['estimatedRunLengthOrigin'] == null
      ? null
      : decodeEnumStrict(
          RunLengthOrigin.values,
          asStr(
            json['estimatedRunLengthOrigin'],
            'Location.estimatedRunLengthOrigin',
          ),
          'Location.estimatedRunLengthOrigin',
        ),
  planOutline: _decodeRoomOutlineOrNull(
    json['planOutline'],
    'Location.planOutline',
  ),
);

// --- Plan (docs/15 §3, DR-037) -----------------------------------------------

/// A `PxPt` as a two-key object rather than a pair.
///
/// NAMED KEYS AND NOT A `[x, y]` ARRAY, on `_encodePt`'s precedent: an
/// array is one transposition away from silently swapping the axes, and
/// nothing in a diff of two numbers says which is which.
JsonMap _encodePxPt(PxPt p) => {'px': p.px, 'py': p.py};

PxPt _decodePxPt(Object? raw, String context) {
  final json = asJsonMap(raw, context);
  return PxPt(
    asInt(json['px'], '$context.px'),
    asInt(json['py'], '$context.py'),
  );
}

/// THE INPUTS, NEVER THE FACTOR (CR-001, docs/15 §3.2). Two integer pixel
/// points and one `Len`, which is exactly what the user supplied. A stored
/// factor would be a floating-point length in the file format, which
/// CR-001 forbids outright, and it would also be a second copy of a
/// derived number.
JsonMap _encodePlanScale(PlanScale scale) => {
  'a': _encodePxPt(scale.a),
  'b': _encodePxPt(scale.b),
  'distanceNm': scale.distance.nm,
};

PlanScale _decodePlanScale(Object? raw, String context) {
  final json = asJsonMap(raw, context);
  return PlanScale(
    a: _decodePxPt(json['a'], '$context.a'),
    b: _decodePxPt(json['b'], '$context.b'),
    distance: Len(asInt(json['distanceNm'], '$context.distanceNm')),
  );
}

JsonMap _encodePlanPin(PlanPin pin) => {
  'underlayId': pin.underlayId.v,
  'at': _encodePxPt(pin.at),
};

PlanPin _decodePlanPin(Object? raw, String context) {
  final json = asJsonMap(raw, context);
  return PlanPin(
    underlayId: _decodeUuid(json['underlayId'], '$context.underlayId'),
    at: _decodePxPt(json['at'], '$context.at'),
  );
}

PlanPin? _decodePlanPinOrNull(Object? raw, String context) =>
    raw == null ? null : _decodePlanPin(raw, context);

/// A room's shape (DR-050 §11.49, `LEN-A/1`).
///
/// AN ARRAY HERE, WHERE `_encodePxPt` REFUSED ONE, and the two are not in
/// tension. That function takes named keys because *"an array is one
/// transposition away from silently swapping the axes"*, which is about
/// the two numbers INSIDE a point. The vertices are an ordered sequence of
/// whole points, and a JSON array is what an ordered sequence is: the
/// order is the polygon's shape, so it is the one thing the format must
/// preserve exactly, and each element still carries its own named keys.
JsonMap _encodeRoomOutline(RoomOutline outline) => {
  'underlayId': outline.underlayId.v,
  'vertices': [for (final v in outline.vertices) _encodePxPt(v)],
};

/// **NOTHING IS REFUSED HERE, INCLUDING A TWO-POINT OUTLINE** (CR-093,
/// `read never throws`). `RoomOutline.isUsable` reports it and the
/// derivation declines to measure it, which is `PlanScale`'s answer to the
/// same question about a calibration whose two points coincide. Dropping
/// it on load would be a silent edit to somebody's file.
RoomOutline _decodeRoomOutline(Object? raw, String context) {
  final json = asJsonMap(raw, context);
  final vertices = asJsonList(json['vertices'], '$context.vertices');
  return RoomOutline(
    underlayId: _decodeUuid(json['underlayId'], '$context.underlayId'),
    vertices: [
      for (var i = 0; i < vertices.length; i++)
        _decodePxPt(vertices[i], '$context.vertices[$i]'),
    ],
  );
}

RoomOutline? _decodeRoomOutlineOrNull(Object? raw, String context) =>
    raw == null ? null : _decodeRoomOutline(raw, context);

JsonMap _encodePlanUnderlay(PlanUnderlay u) {
  final json = <String, Object?>{
    'id': u.id.v,
    'name': u.name,
    'imageMember': u.imageMember,
    'format': encodeEnumName(u.format),
    'pixelWidth': u.pixelWidth,
    'pixelHeight': u.pixelHeight,
    'contentHash': u.contentHash,
    'order': u.order.v,
    'meta': _encodeEntityMeta(u.meta),
  };
  putIfNotNull(json, 'locationId', u.locationId?.v);
  // ABSENT MEANS UNCALIBRATED, and that is a statement rather than a
  // default (G4, CR-114). It never becomes a 1:1 scale on the way back in.
  putIfNotNull(
    json,
    'scale',
    u.scale == null ? null : _encodePlanScale(u.scale!),
  );
  // ABSENT MEANS THERE IS NO SOURCE TO KEEP, which is a statement about
  // HOW the underlay arrived rather than an unknown: an image imported
  // directly, or a page lifted losslessly, whose stored bytes already are
  // the source (DR-153 §11.152.6).
  putIfNotNull(
    json,
    'sourcePage',
    u.sourcePage == null ? null : _encodePlanSourcePage(u.sourcePage!),
  );
  return json;
}

JsonMap _encodePlanSourcePage(PlanSourcePage p) => {
  'member': p.member,
  'pageIndex': p.pageIndex,
  'contentHash': p.contentHash,
};

PlanSourcePage _decodePlanSourcePage(Object? raw, String context) {
  final json = asJsonMap(raw, context);
  final pageIndex = asInt(json['pageIndex'], '$context.pageIndex');
  // A NEGATIVE PAGE IS REFUSED AT THE BOUNDARY. Nothing reads this field
  // yet, and that is exactly why: the day something does, the value it
  // meets was checked when it arrived rather than trusted because it had
  // been in a file for a year.
  if (pageIndex < 0) {
    throw FormatException(
      'Expected a page index >= 0 for $context, got: '
      '$pageIndex',
    );
  }
  return PlanSourcePage(
    member: asStr(json['member'], '$context.member'),
    pageIndex: pageIndex,
    contentHash: asStr(json['contentHash'], '$context.contentHash'),
  );
}

PlanUnderlay _decodePlanUnderlay(Uuid id, JsonMap json) => PlanUnderlay(
  id: id,
  name: asStr(json['name'], 'PlanUnderlay.name'),
  imageMember: asStr(json['imageMember'], 'PlanUnderlay.imageMember'),
  format: decodeEnumStrict(
    PlanImageFormat.values,
    asStr(json['format'], 'PlanUnderlay.format'),
    'PlanUnderlay.format',
  ),
  pixelWidth: asInt(json['pixelWidth'], 'PlanUnderlay.pixelWidth'),
  pixelHeight: asInt(json['pixelHeight'], 'PlanUnderlay.pixelHeight'),
  contentHash: asStr(json['contentHash'], 'PlanUnderlay.contentHash'),
  order: FracIndex(asStr(json['order'], 'PlanUnderlay.order')),
  meta: _decodeEntityMeta(asJsonMap(json['meta'], 'PlanUnderlay.meta')),
  locationId: _decodeUuidOrNull(json['locationId'], 'PlanUnderlay.locationId'),
  scale: json['scale'] == null
      ? null
      : _decodePlanScale(json['scale'], 'PlanUnderlay.scale'),
  sourcePage: json['sourcePage'] == null
      ? null
      : _decodePlanSourcePage(json['sourcePage'], 'PlanUnderlay.sourcePage'),
);

// --- Rack / ZeroUChannel -----------------------------------------------------

JsonMap _encodeZeroUChannel(ZeroUChannel c) => {
  'id': c.id,
  'name': c.name,
  'side': encodeEnumName(c.side),
  'startU': c.startU,
  'endU': c.endU,
};

ZeroUChannel _decodeZeroUChannel(JsonMap json) => ZeroUChannel(
  id: asStr(json['id'], 'ZeroUChannel.id'),
  side: decodeEnumStrict(
    ZeroUChannelSide.values,
    asStr(json['side'], 'ZeroUChannel.side'),
    'ZeroUChannel.side',
  ),
  startU: asInt(json['startU'], 'ZeroUChannel.startU'),
  endU: asInt(json['endU'], 'ZeroUChannel.endU'),
  name: asStr(json['name'] ?? '', 'ZeroUChannel.name'),
);

JsonMap _encodeRack(Rack r) {
  final json = <String, Object?>{
    'id': r.id.v,
    'name': r.name,
    'designator': r.designator,
    'heightU': r.heightU,
    'order': r.order.v,
    'meta': _encodeEntityMeta(r.meta),
    'ruNumbering': encodeEnumName(r.ruNumbering),
    'mirrorRearElevation': r.mirrorRearElevation,
    'widthClass': encodeEnumName(r.widthClass),
    'railType': encodeEnumName(r.railType),
    'fullHoleRail': r.fullHoleRail,
    'formFactor': encodeEnumName(r.formFactor),
    'isSwingFrame': r.isSwingFrame,
    'hasFrontDoor': r.hasFrontDoor,
    'hasRearDoor': r.hasRearDoor,
    'groundBarPresent': r.groundBarPresent,
    'zeroUChannels': [for (final c in r.zeroUChannels) _encodeZeroUChannel(c)],
  };
  putIfNotNull(json, 'locationId', r.locationId?.v);
  putIfNotNull(json, 'customPanelWidthNm', r.customPanelWidth?.nm);
  putIfNotNull(json, 'usableDepthNm', r.usableDepth?.nm);
  putIfNotNull(json, 'overallDepthNm', r.overallDepth?.nm);
  putIfNotNull(json, 'overallWidthNm', r.overallWidth?.nm);
  putIfNotNull(json, 'overallHeightNm', r.overallHeight?.nm);
  putIfNotNull(json, 'weightCapacityUg', r.weightCapacity?.ug);
  putIfNotNull(json, 'ownWeightUg', r.ownWeight?.ug);
  if (r.hingeSide != null) json['hingeSide'] = encodeEnumName(r.hingeSide!);
  putIfNotNull(json, 'frontDoorClearanceNm', r.frontDoorClearance?.nm);
  putIfNotNull(json, 'rearDoorClearanceNm', r.rearDoorClearance?.nm);
  putIfNotNull(
    json,
    'planPin',
    r.planPin == null ? null : _encodePlanPin(r.planPin!),
  );
  return json;
}

Rack _decodeRack(Uuid id, JsonMap json) => Rack(
  id: id,
  name: asStr(json['name'], 'Rack.name'),
  designator: asStr(json['designator'], 'Rack.designator'),
  heightU: asInt(json['heightU'], 'Rack.heightU'),
  order: FracIndex(asStr(json['order'], 'Rack.order')),
  meta: _decodeEntityMeta(asJsonMap(json['meta'], 'Rack.meta')),
  locationId: _decodeUuidOrNull(json['locationId'], 'Rack.locationId'),
  planPin: _decodePlanPinOrNull(json['planPin'], 'Rack.planPin'),
  ruNumbering: decodeEnumStrict(
    RuNumbering.values,
    asStr(json['ruNumbering'], 'Rack.ruNumbering'),
    'Rack.ruNumbering',
  ),
  mirrorRearElevation: asBool(
    json['mirrorRearElevation'],
    'Rack.mirrorRearElevation',
  ),
  widthClass: decodeEnumStrict(
    RackWidthClass.values,
    asStr(json['widthClass'], 'Rack.widthClass'),
    'Rack.widthClass',
  ),
  customPanelWidth: _decodeLenOrNull(
    json['customPanelWidthNm'],
    'Rack.customPanelWidthNm',
  ),
  railType: decodeEnumStrict(
    RailType.values,
    asStr(json['railType'], 'Rack.railType'),
    'Rack.railType',
  ),
  fullHoleRail: asBool(json['fullHoleRail'], 'Rack.fullHoleRail'),
  formFactor: decodeEnumStrict(
    RackFormFactor.values,
    asStr(json['formFactor'], 'Rack.formFactor'),
    'Rack.formFactor',
  ),
  usableDepth: _decodeLenOrNull(json['usableDepthNm'], 'Rack.usableDepthNm'),
  overallDepth: _decodeLenOrNull(json['overallDepthNm'], 'Rack.overallDepthNm'),
  overallWidth: _decodeLenOrNull(json['overallWidthNm'], 'Rack.overallWidthNm'),
  overallHeight: _decodeLenOrNull(
    json['overallHeightNm'],
    'Rack.overallHeightNm',
  ),
  weightCapacity: _decodeMassOrNull(
    json['weightCapacityUg'],
    'Rack.weightCapacityUg',
  ),
  ownWeight: _decodeMassOrNull(json['ownWeightUg'], 'Rack.ownWeightUg'),
  isSwingFrame: asBool(json['isSwingFrame'], 'Rack.isSwingFrame'),
  hingeSide: json['hingeSide'] == null
      ? null
      : decodeEnumStrict(
          HingeSide.values,
          asStr(json['hingeSide'], 'Rack.hingeSide'),
          'Rack.hingeSide',
        ),
  hasFrontDoor: asBool(json['hasFrontDoor'], 'Rack.hasFrontDoor'),
  hasRearDoor: asBool(json['hasRearDoor'], 'Rack.hasRearDoor'),
  frontDoorClearance: _decodeLenOrNull(
    json['frontDoorClearanceNm'],
    'Rack.frontDoorClearanceNm',
  ),
  rearDoorClearance: _decodeLenOrNull(
    json['rearDoorClearanceNm'],
    'Rack.rearDoorClearanceNm',
  ),
  groundBarPresent: asBool(json['groundBarPresent'], 'Rack.groundBarPresent'),
  zeroUChannels: decodeObjectList(
    json['zeroUChannels'] ?? const <Object?>[],
    'Rack.zeroUChannels',
    _decodeZeroUChannel,
  ),
);

// --- DeviceInstance / DeviceOverrides / Placement / TemplateRef -------------

/// DR-098 §11.97.3's third state on the wire.
///
/// UNKNOWN CANNOT BE AN EXPLICIT NULL HERE. CR-114 rules that an unknown
/// serializes as an ABSENT key, and on this type an absent key already
/// means "inherit the template's value" — so the two states would share a
/// spelling and the file could not tell them apart. The cleared set is
/// therefore a PRESENT key with a present value, and it is omitted
/// entirely when empty, which every override block in the shipped corpus
/// is. That makes this addition byte-invisible to existing files (CR-117)
/// and no `kSchemaVersion` advance is owed.
const Map<DeviceOverrideField, String> _kOverrideFieldNames = {
  DeviceOverrideField.typicalWatts: 'typicalWatts',
  DeviceOverrideField.weight: 'weight',
  DeviceOverrideField.bodyDepth: 'bodyDepth',
  DeviceOverrideField.accentColor: 'accentColor',
};

/// The wire names above, read the other way. A written-out inverse rather
/// than a search of the forward map, so that adding a field to the enum
/// and forgetting this pair is a compile-time hole in exactly one place.
const Map<String, DeviceOverrideField> _kOverrideFieldsByName = {
  'typicalWatts': DeviceOverrideField.typicalWatts,
  'weight': DeviceOverrideField.weight,
  'bodyDepth': DeviceOverrideField.bodyDepth,
  'accentColor': DeviceOverrideField.accentColor,
};

JsonMap _encodeDeviceOverrides(DeviceOverrides o) {
  final json = <String, Object?>{};
  putIfNotNull(json, 'typicalWatts', o.typicalWatts);
  putIfNotNull(json, 'weightUg', o.weight?.ug);
  putIfNotNull(json, 'bodyDepthNm', o.bodyDepth?.nm);
  if (o.accentColor != null) json['accentColor'] = _encodeRgb(o.accentColor!);
  if (o.cleared.isNotEmpty) {
    // SORTED BY THE ENUM'S OWN ORDER, not by the set's iteration order.
    // `Set` iteration is insertion-ordered in Dart, so two documents that
    // cleared the same two fields in a different sequence would write
    // different bytes and CR-117's round-trip would be the thing that
    // found out.
    json['cleared'] = [
      for (final f in DeviceOverrideField.values)
        if (o.cleared.contains(f)) _kOverrideFieldNames[f]!,
    ];
  }
  return json;
}

DeviceOverrides _decodeDeviceOverrides(JsonMap json) {
  final cleared = <DeviceOverrideField>{};
  final raw = json['cleared'];
  if (raw != null) {
    final names = asJsonList(raw, 'DeviceOverrides.cleared');
    for (var i = 0; i < names.length; i++) {
      final name = asStr(names[i], 'DeviceOverrides.cleared[$i]');
      final field = _kOverrideFieldsByName[name];
      if (field == null) {
        throw FormatException(
          'DeviceOverrides.cleared[$i]: unknown field "$name".',
        );
      }
      cleared.add(field);
    }
  }

  final decoded = DeviceOverrides(
    typicalWatts: asIntOrNull(
      json['typicalWatts'],
      'DeviceOverrides.typicalWatts',
    ),
    weight: _decodeMassOrNull(json['weightUg'], 'DeviceOverrides.weightUg'),
    bodyDepth: _decodeLenOrNull(
      json['bodyDepthNm'],
      'DeviceOverrides.bodyDepthNm',
    ),
    accentColor: _decodeRgbOrNull(
      json['accentColor'],
      'DeviceOverrides.accentColor',
    ),
    cleared: cleared,
  );

  // SET AND CLEARED AT ONCE IS REFUSED BY NAME, NOT NORMALISED.
  //
  // The file states two incompatible things about one field, and either
  // way of picking a winner silently discards one of them. G2 says the
  // model must be able to draw a mistake; it does not say the codec
  // should invent which half of a contradiction was meant. Nothing this
  // application writes can produce one, because `clear` and `inherit`
  // each undo the other.
  for (final f in cleared) {
    final value = switch (f) {
      DeviceOverrideField.typicalWatts => decoded.typicalWatts,
      DeviceOverrideField.weight => decoded.weight,
      DeviceOverrideField.bodyDepth => decoded.bodyDepth,
      DeviceOverrideField.accentColor => decoded.accentColor,
    };
    if (value != null) {
      throw FormatException(
        'DeviceOverrides."${_kOverrideFieldNames[f]}" is both set and '
        'listed in "cleared". A field is overridden to a value, or stated '
        'unknown, never both (DR-098 §11.97.3).',
      );
    }
  }
  return decoded;
}

JsonMap _encodeTemplateRef(TemplateRef ref) => {
  'templateId': ref.templateId.v,
  'version': ref.version,
  'contentHash': ref.contentHash,
};

TemplateRef _decodeTemplateRef(JsonMap json) => TemplateRef(
  templateId: TemplateId(asStr(json['templateId'], 'TemplateRef.templateId')),
  version: asInt(json['version'], 'TemplateRef.version'),
  contentHash: asStr(json['contentHash'], 'TemplateRef.contentHash'),
);

// Placement — sealed union, discriminator key "type". "rail" and
// "offRack" are directly evidenced by docs/02-data-model.md §6.2's worked
// example (`placement.type: "rail" | "offRack"`); "shelf"/"zeroU"/"staged"
// follow the identical naming pattern (strip "Placement", lowercase the
// first letter) but aren't themselves shown in the example — noted per
// this package's drift-handling policy rather than silently assumed.
/// The `unknown` passthrough entry for [placement], or nothing when the bag
/// is empty (DR-019 §11.18.2(5)).
///
/// OMITTED WHEN EMPTY, WHICH IS A DELIBERATE DEVIATION FROM `_encodePort`.
/// That one writes `'unknown': p.unknown` unconditionally, so every `Port`
/// in every shipped file already carries a `"unknown": {}`. Placements do
/// not, and adding the key unconditionally would change the bytes of all
/// four starters and every checked-in fixture, breaking CR-117 on files
/// this build did not write. Omission is also what the format already
/// means by "not present": canon §12.12 settles the neighbouring container
/// question on exactly that ground, that an absent key is how this format
/// expresses absence (G4, CR-114).
///
/// The rule is self-consistent because nothing ever WRITES an empty bag, so
/// no file this build produces can contain the `"unknown": {}` that would
/// fail to survive the trip back.
Map<String, Object?>? _placementUnknown(Placement placement) =>
    placement.unknown.isEmpty ? null : {'unknown': placement.unknown};

JsonMap _encodePlacement(Placement placement) => switch (placement) {
  RailPlacement(
    :final rackId,
    :final ruIndex,
    :final face,
    :final startTwelfth,
    :final spanTwelfths,
    :final depthOffsetFromFront,
    :final chassisRotation,
    :final locked,
  ) =>
    {
      'type': 'rail',
      'rackId': rackId.v,
      'ruIndex': ruIndex,
      'face': encodeEnumName(face),
      'startTwelfth': startTwelfth,
      'spanTwelfths': spanTwelfths,
      'chassisRotation': encodeEnumName(chassisRotation),
      'locked': locked,
      if (depthOffsetFromFront != null)
        'depthOffsetFromFrontNm': depthOffsetFromFront.nm,
      ...?_placementUnknown(placement),
    },
  ShelfPlacement(
    :final hostDeviceId,
    :final order,
    :final lateralOffset,
    :final locked,
  ) =>
    {
      'type': 'shelf',
      'hostDeviceId': hostDeviceId.v,
      'order': order.v,
      'locked': locked,
      if (lateralOffset != null) 'lateralOffsetNm': lateralOffset.nm,
      ...?_placementUnknown(placement),
    },
  ZeroUPlacement(
    :final rackId,
    :final channelId,
    :final offsetFromChannelStart,
    :final spanAlongChannel,
    :final orientation,
    :final locked,
  ) =>
    {
      'type': 'zeroU',
      'rackId': rackId.v,
      'channelId': channelId,
      'offsetFromChannelStartNm': offsetFromChannelStart.nm,
      // ABSENT WHEN UNKNOWN, never an explicit null (G4, CR-114, DR-166
      // §11.165.2). A reader that finds no key knows the file does not
      // say how long this occupant is; a reader that finds `null` cannot
      // tell that from a writer that meant zero.
      if (spanAlongChannel != null) 'spanAlongChannelNm': spanAlongChannel.nm,
      'orientation': encodeEnumName(orientation),
      'locked': locked,
      ...?_placementUnknown(placement),
    },
  OffRackPlacement(:final locationId, :final mountNote, :final planPin) => {
    'type': 'offRack',
    if (locationId != null) 'locationId': locationId.v,
    if (mountNote != null) 'mountNote': mountNote,
    if (planPin != null) 'planPin': _encodePlanPin(planPin),
    ...?_placementUnknown(placement),
  },
  StagedPlacement(
    :final lastRackId,
    :final lastRuIndex,
    :final lastFace,
    :final schematicHint,
  ) =>
    {
      'type': 'staged',
      if (lastRackId != null) 'lastRackId': lastRackId.v,
      if (lastRuIndex != null) 'lastRuIndex': lastRuIndex,
      if (lastFace != null) 'lastFace': encodeEnumName(lastFace),
      if (schematicHint != null) 'schematicHint': _encodePt(schematicHint),
      ...?_placementUnknown(placement),
    },
};

/// The reserved `unknown` bag on [json], empty when the key is absent.
///
/// RESERVED CONTAINER, NOT A HARVESTER: this reads the `unknown` key and
/// nothing collects unrecognised SIBLING keys, which is the contract
/// `codec_split_test.dart` already asserts for `Port`. See
/// `model/placement.dart`.
Map<String, Object?> _unknownBag(JsonMap json, String context) =>
    asJsonMap(json['unknown'] ?? const <String, Object?>{}, '$context.unknown');

Placement _decodePlacement(JsonMap json) {
  final type = asStr(json['type'], 'Placement.type');
  switch (type) {
    case 'rail':
      return RailPlacement(
        rackId: _decodeUuid(json['rackId'], 'RailPlacement.rackId'),
        ruIndex: asInt(json['ruIndex'], 'RailPlacement.ruIndex'),
        face: decodeEnumStrict(
          Face.values,
          asStr(json['face'], 'RailPlacement.face'),
          'RailPlacement.face',
        ),
        startTwelfth: asInt(
          json['startTwelfth'] ?? 0,
          'RailPlacement.startTwelfth',
        ),
        spanTwelfths: asInt(
          json['spanTwelfths'] ?? 12,
          'RailPlacement.spanTwelfths',
        ),
        depthOffsetFromFront: _decodeLenOrNull(
          json['depthOffsetFromFrontNm'],
          'RailPlacement.depthOffsetFromFrontNm',
        ),
        chassisRotation: decodeEnumStrict(
          ChassisRotation.values,
          asStr(json['chassisRotation'], 'RailPlacement.chassisRotation'),
          'RailPlacement.chassisRotation',
        ),
        locked: asBool(json['locked'], 'RailPlacement.locked'),
        unknown: _unknownBag(json, 'RailPlacement'),
      );
    case 'shelf':
      return ShelfPlacement(
        hostDeviceId: _decodeUuid(
          json['hostDeviceId'],
          'ShelfPlacement.hostDeviceId',
        ),
        order: FracIndex(asStr(json['order'], 'ShelfPlacement.order')),
        lateralOffset: _decodeLenOrNull(
          json['lateralOffsetNm'],
          'ShelfPlacement.lateralOffsetNm',
        ),
        locked: asBool(json['locked'], 'ShelfPlacement.locked'),
        unknown: _unknownBag(json, 'ShelfPlacement'),
      );
    case 'zeroU':
      return ZeroUPlacement(
        rackId: _decodeUuid(json['rackId'], 'ZeroUPlacement.rackId'),
        channelId: asStr(json['channelId'], 'ZeroUPlacement.channelId'),
        offsetFromChannelStart: _decodeLen(
          json['offsetFromChannelStartNm'],
          'ZeroUPlacement.offsetFromChannelStartNm',
        ),
        spanAlongChannel: _decodeLenOrNull(
          json['spanAlongChannelNm'],
          'ZeroUPlacement.spanAlongChannelNm',
        ),
        orientation: decodeEnumStrict(
          ZeroUOrientation.values,
          asStr(json['orientation'], 'ZeroUPlacement.orientation'),
          'ZeroUPlacement.orientation',
        ),
        locked: asBool(json['locked'], 'ZeroUPlacement.locked'),
        unknown: _unknownBag(json, 'ZeroUPlacement'),
      );
    case 'offRack':
      return OffRackPlacement(
        locationId: _decodeUuidOrNull(
          json['locationId'],
          'OffRackPlacement.locationId',
        ),
        mountNote: asStrOrNull(json['mountNote'], 'OffRackPlacement.mountNote'),
        planPin: _decodePlanPinOrNull(
          json['planPin'],
          'OffRackPlacement.planPin',
        ),
        unknown: _unknownBag(json, 'OffRackPlacement'),
      );
    case 'staged':
      return StagedPlacement(
        lastRackId: _decodeUuidOrNull(
          json['lastRackId'],
          'StagedPlacement.lastRackId',
        ),
        lastRuIndex: asIntOrNull(
          json['lastRuIndex'],
          'StagedPlacement.lastRuIndex',
        ),
        lastFace: json['lastFace'] == null
            ? null
            : decodeEnumStrict(
                Face.values,
                asStr(json['lastFace'], 'StagedPlacement.lastFace'),
                'StagedPlacement.lastFace',
              ),
        schematicHint: decodeNullableObject(
          json,
          'schematicHint',
          'StagedPlacement.schematicHint',
          _decodePt,
        ),
        unknown: _unknownBag(json, 'StagedPlacement'),
      );
    default:
      throw FormatException('Unrecognised Placement.type "$type".');
  }
}

JsonMap _encodeDeviceInstance(DeviceInstance d) {
  final json = <String, Object?>{
    'id': d.id.v,
    'kind': encodeEnumName(d.kind),
    'templateRef': _encodeTemplateRef(d.templateRef),
    'designator': d.designator,
    'name': d.name,
    'placement': _encodePlacement(d.placement),
    'meta': _encodeEntityMeta(d.meta),
    'designatorLocked': d.designatorLocked,
    'lifecycleStatus': encodeLifecycleStatus(d.lifecycleStatus),
    'overrides': _encodeDeviceOverrides(d.overrides),
    'designatorWatermark': d.designatorWatermark,
  };
  putIfNotNull(json, 'locationId', d.locationId?.v);
  putIfNotNull(json, 'serialNumber', d.serialNumber);
  putIfNotNull(json, 'assetTag', d.assetTag);
  putIfNotNull(json, 'macAddressPrimary', d.macAddressPrimary);
  putIfNotNull(json, 'firmwareVersion', d.firmwareVersion);
  if (d.installedAt != null) {
    json['installedAt'] = encodeDateTime(d.installedAt!);
  }
  putIfNotNull(json, 'structureBodyId', d.structureBodyId?.v);
  putIfNotNull(json, 'notes', d.notes);
  if (d.colorOverride != null) {
    json['colorOverride'] = _encodeRgb(d.colorOverride!);
  }
  return json;
}

DeviceInstance _decodeDeviceInstance(Uuid id, JsonMap json) => DeviceInstance(
  id: id,
  kind: decodeEnumStrict(
    DeviceKind.values,
    asStr(json['kind'], 'DeviceInstance.kind'),
    'DeviceInstance.kind',
  ),
  templateRef: _decodeTemplateRef(
    asJsonMap(json['templateRef'], 'DeviceInstance.templateRef'),
  ),
  designator: asStr(json['designator'], 'DeviceInstance.designator'),
  name: asStr(json['name'], 'DeviceInstance.name'),
  placement: _decodePlacement(
    asJsonMap(json['placement'], 'DeviceInstance.placement'),
  ),
  meta: _decodeEntityMeta(asJsonMap(json['meta'], 'DeviceInstance.meta')),
  designatorLocked: asBool(
    json['designatorLocked'],
    'DeviceInstance.designatorLocked',
  ),
  lifecycleStatus: decodeLifecycleStatus(
    asStr(json['lifecycleStatus'], 'DeviceInstance.lifecycleStatus'),
  ),
  locationId: _decodeUuidOrNull(
    json['locationId'],
    'DeviceInstance.locationId',
  ),
  serialNumber: asStrOrNull(
    json['serialNumber'],
    'DeviceInstance.serialNumber',
  ),
  assetTag: asStrOrNull(json['assetTag'], 'DeviceInstance.assetTag'),
  macAddressPrimary: asStrOrNull(
    json['macAddressPrimary'],
    'DeviceInstance.macAddressPrimary',
  ),
  firmwareVersion: asStrOrNull(
    json['firmwareVersion'],
    'DeviceInstance.firmwareVersion',
  ),
  installedAt: json['installedAt'] == null
      ? null
      : decodeDateTime(
          asStr(json['installedAt'], 'DeviceInstance.installedAt'),
        ),
  overrides: _decodeDeviceOverrides(
    asJsonMap(json['overrides'], 'DeviceInstance.overrides'),
  ),
  designatorWatermark: asInt(
    json['designatorWatermark'],
    'DeviceInstance.designatorWatermark',
  ),
  structureBodyId: _decodeUuidOrNull(
    json['structureBodyId'],
    'DeviceInstance.structureBodyId',
  ),
  notes: asStrOrNull(json['notes'], 'DeviceInstance.notes'),
  colorOverride: _decodeRgbOrNull(
    json['colorOverride'],
    'DeviceInstance.colorOverride',
  ),
);

// --- Port / PortOverrides / NetworkConfig / PoeAssignment -------------------

JsonMap _encodePortOverrides(PortOverrides o) {
  final json = <String, Object?>{};
  putIfNotNull(json, 'connector', o.connector?.v);
  putIfNotNull(json, 'signalFamily', o.signalFamily?.v);
  return json;
}

PortOverrides _decodePortOverrides(JsonMap json) => PortOverrides(
  connector: json['connector'] == null
      ? null
      : ConnectorTypeId(asStr(json['connector'], 'PortOverrides.connector')),
  signalFamily: json['signalFamily'] == null
      ? null
      : SignalFamilyId(
          asStr(json['signalFamily'], 'PortOverrides.signalFamily'),
        ),
);

JsonMap _encodeNetworkConfig(NetworkConfig n) {
  final json = <String, Object?>{'vlans': n.vlans};
  putIfNotNull(json, 'hostname', n.hostname);
  putIfNotNull(json, 'ip', n.ip);
  putIfNotNull(json, 'subnet', n.subnet);
  putIfNotNull(json, 'gw', n.gw);
  putIfNotNull(json, 'mac', n.mac);
  putIfNotNull(json, 'portRole', n.portRole);
  return json;
}

NetworkConfig _decodeNetworkConfig(JsonMap json) => NetworkConfig(
  hostname: asStrOrNull(json['hostname'], 'NetworkConfig.hostname'),
  ip: asStrOrNull(json['ip'], 'NetworkConfig.ip'),
  subnet: asStrOrNull(json['subnet'], 'NetworkConfig.subnet'),
  gw: asStrOrNull(json['gw'], 'NetworkConfig.gw'),
  mac: asStrOrNull(json['mac'], 'NetworkConfig.mac'),
  vlans: [
    for (final v in asJsonList(
      json['vlans'] ?? const <Object?>[],
      'NetworkConfig.vlans',
    ))
      asInt(v, 'NetworkConfig.vlans[]'),
  ],
  portRole: asStrOrNull(json['portRole'], 'NetworkConfig.portRole'),
);

JsonMap _encodePoeAssignment(PoeAssignment p) {
  final json = <String, Object?>{};
  putIfNotNull(json, 'poeClass', p.poeClass);
  putIfNotNull(json, 'negotiatedWatts', p.negotiatedWatts);
  return json;
}

PoeAssignment _decodePoeAssignment(JsonMap json) => PoeAssignment(
  poeClass: asIntOrNull(json['poeClass'], 'PoeAssignment.poeClass'),
  negotiatedWatts: asIntOrNull(
    json['negotiatedWatts'],
    'PoeAssignment.negotiatedWatts',
  ),
);

JsonMap _encodePort(Port p) {
  final json = <String, Object?>{
    'id': p.id.v,
    'deviceId': p.deviceId.v,
    'designator': p.designator,
    'overrides': _encodePortOverrides(p.overrides),
    'orphaned': p.orphaned,
    'reserved': p.reserved,
    'unknown': p.unknown,
  };
  putIfNotNull(json, 'templatePortKey', p.templatePortKey?.v);
  putIfNotNull(json, 'userLabel', p.userLabel);
  putIfNotNull(json, 'notes', p.notes);
  if (p.network != null) json['network'] = _encodeNetworkConfig(p.network!);
  putIfNotNull(json, 'busAddress', p.busAddress);
  putIfNotNull(json, 'busUniverse', p.busUniverse);
  putIfNotNull(json, 'isBusTerminator', p.isBusTerminator);
  putIfNotNull(json, 'tapWatts', p.tapWatts);
  // DR-131. Written only when TRUE, so a document full of ordinary ports
  // gains no bytes and CR-117's round-trip over every existing fixture is
  // byte-identical to before this field existed.
  if (p.lowZBypass) json['lowZBypass'] = true;
  putIfNotNull(json, 'circuitId', p.circuitId?.v);
  if (p.poeActual != null) {
    json['poeActual'] = _encodePoeAssignment(p.poeActual!);
  }
  return json;
}

Port _decodePort(Uuid id, JsonMap json) => Port(
  id: id,
  deviceId: _decodeUuid(json['deviceId'], 'Port.deviceId'),
  designator: asStr(json['designator'], 'Port.designator'),
  templatePortKey: json['templatePortKey'] == null
      ? null
      : PortKey(asStr(json['templatePortKey'], 'Port.templatePortKey')),
  overrides: _decodePortOverrides(
    asJsonMap(json['overrides'], 'Port.overrides'),
  ),
  userLabel: asStrOrNull(json['userLabel'], 'Port.userLabel'),
  orphaned: asBool(json['orphaned'], 'Port.orphaned'),
  reserved: asBool(json['reserved'], 'Port.reserved'),
  network: decodeNullableObject(
    json,
    'network',
    'Port.network',
    _decodeNetworkConfig,
  ),
  busAddress: asIntOrNull(json['busAddress'], 'Port.busAddress'),
  busUniverse: asIntOrNull(json['busUniverse'], 'Port.busUniverse'),
  isBusTerminator: asBoolOrNull(
    json['isBusTerminator'],
    'Port.isBusTerminator',
  ),
  tapWatts: asIntOrNull(json['tapWatts'], 'Port.tapWatts'),
  lowZBypass: asBoolOrNull(json['lowZBypass'], 'Port.lowZBypass') ?? false,
  circuitId: _decodeUuidOrNull(json['circuitId'], 'Port.circuitId'),
  poeActual: decodeNullableObject(
    json,
    'poeActual',
    'Port.poeActual',
    _decodePoeAssignment,
  ),
  notes: asStrOrNull(json['notes'], 'Port.notes'),
  unknown: asJsonMap(
    json['unknown'] ?? const <String, Object?>{},
    'Port.unknown',
  ),
);

// --- Net ---------------------------------------------------------------------

JsonMap _encodeNet(Net n) {
  final json = <String, Object?>{
    'id': n.id.v,
    'name': n.name,
    'signalFamily': n.signalFamily.v,
    'topology': encodeEnumName(n.topology),
    'isImplicit': n.isImplicit,
    'meta': _encodeEntityMeta(n.meta),
  };
  putIfNotNull(json, 'designator', n.designator);
  putIfNotNull(json, 'notes', n.notes);
  if (n.colorOverride != null) {
    json['colorOverride'] = _encodeRgb(n.colorOverride!);
  }
  putIfNotNull(json, 'busTerminatorPortIdA', n.busTerminatorPortIdA?.v);
  putIfNotNull(json, 'busTerminatorPortIdB', n.busTerminatorPortIdB?.v);
  putIfNotNull(json, 'busUniverse', n.busUniverse);
  putIfNotNull(json, 'nominalVoltage', n.nominalVoltage);
  return json;
}

Net _decodeNet(Uuid id, JsonMap json) => Net(
  id: id,
  name: asStr(json['name'], 'Net.name'),
  signalFamily: SignalFamilyId(asStr(json['signalFamily'], 'Net.signalFamily')),
  meta: _decodeEntityMeta(asJsonMap(json['meta'], 'Net.meta')),
  designator: asStrOrNull(json['designator'], 'Net.designator'),
  topology: decodeEnumStrict(
    NetTopologyKind.values,
    asStr(json['topology'], 'Net.topology'),
    'Net.topology',
  ),
  colorOverride: _decodeRgbOrNull(json['colorOverride'], 'Net.colorOverride'),
  isImplicit: asBool(json['isImplicit'], 'Net.isImplicit'),
  busTerminatorPortIdA: _decodeUuidOrNull(
    json['busTerminatorPortIdA'],
    'Net.busTerminatorPortIdA',
  ),
  busTerminatorPortIdB: _decodeUuidOrNull(
    json['busTerminatorPortIdB'],
    'Net.busTerminatorPortIdB',
  ),
  busUniverse: asIntOrNull(json['busUniverse'], 'Net.busUniverse'),
  nominalVoltage: asIntOrNull(json['nominalVoltage'], 'Net.nominalVoltage'),
  notes: asStrOrNull(json['notes'], 'Net.notes'),
);

// --- Link / Service / Conductor / Endpoint / Breakout / InlineAdapter /
//     TestResult / StructureOrigin --------------------------------------

JsonMap _encodeService(Service s) => {
  'id': s.id,
  'signalFamily': s.signalFamily.v,
  'netId': s.netId.v,
  'conductorRoles': s.conductorRoles,
  if (s.label != null) 'label': s.label,
};

Service _decodeService(JsonMap json) => Service(
  id: asStr(json['id'], 'Service.id'),
  signalFamily: SignalFamilyId(
    asStr(json['signalFamily'], 'Service.signalFamily'),
  ),
  netId: _decodeUuid(json['netId'], 'Service.netId'),
  conductorRoles: [
    for (final r in asJsonList(
      json['conductorRoles'],
      'Service.conductorRoles',
    ))
      asStr(r, 'Service.conductorRoles[]'),
  ],
  label: asStrOrNull(json['label'], 'Service.label'),
);

// Endpoint — sealed union, discriminator "type": "port" | "place" | "open",
// all three directly confirmed by docs/02-data-model.md §6.2's worked
// Conductor examples.
JsonMap _encodeEndpoint(Endpoint endpoint) => switch (endpoint) {
  PortEndpoint(:final portId) => {'type': 'port', 'portId': portId.v},
  PlaceEndpoint(
    :final description,
    :final locationId,
    :final intendedTermination,
    :final serviceLoop,
  ) =>
    {
      'type': 'place',
      'description': description,
      if (locationId != null) 'locationId': locationId.v,
      if (intendedTermination != null)
        'intendedTermination': encodeEnumName(intendedTermination),
      if (serviceLoop != null) 'serviceLoopNm': serviceLoop.nm,
    },
  OpenEndpoint(:final description) => {
    'type': 'open',
    'description': description,
  },
};

Endpoint _decodeEndpoint(JsonMap json) {
  final type = asStr(json['type'], 'Endpoint.type');
  switch (type) {
    case 'port':
      return PortEndpoint(_decodeUuid(json['portId'], 'PortEndpoint.portId'));
    case 'place':
      return PlaceEndpoint(
        description: asStr(json['description'], 'PlaceEndpoint.description'),
        locationId: _decodeUuidOrNull(
          json['locationId'],
          'PlaceEndpoint.locationId',
        ),
        intendedTermination: json['intendedTermination'] == null
            ? null
            : decodeEnumStrict(
                TerminationType.values,
                asStr(
                  json['intendedTermination'],
                  'PlaceEndpoint.intendedTermination',
                ),
                'PlaceEndpoint.intendedTermination',
              ),
        serviceLoop: _decodeLenOrNull(
          json['serviceLoopNm'],
          'PlaceEndpoint.serviceLoopNm',
        ),
      );
    case 'open':
      return OpenEndpoint(
        asStr(json['description'], 'OpenEndpoint.description'),
      );
    default:
      throw FormatException('Unrecognised Endpoint.type "$type".');
  }
}

JsonMap _encodeConductor(Conductor c) => {
  'role': c.role,
  'from': _encodeEndpoint(c.from),
  'to': _encodeEndpoint(c.to),
  if (c.pairNumber != null) 'pairNumber': c.pairNumber,
  if (c.colorCode != null) 'colorCode': c.colorCode,
};

Conductor _decodeConductor(JsonMap json) => Conductor(
  from: _decodeEndpoint(asJsonMap(json['from'], 'Conductor.from')),
  to: _decodeEndpoint(asJsonMap(json['to'], 'Conductor.to')),
  role: asStr(json['role'] ?? '', 'Conductor.role'),
  pairNumber: asIntOrNull(json['pairNumber'], 'Conductor.pairNumber'),
  colorCode: asStrOrNull(json['colorCode'], 'Conductor.colorCode'),
);

JsonMap _encodeBreakout(Breakout b) => {
  'label': b.label,
  'atLengthFraction': b.atLengthFraction.v,
};

Breakout _decodeBreakout(JsonMap json) => Breakout(
  label: asStr(json['label'], 'Breakout.label'),
  atLengthFraction: Permille(
    asInt(json['atLengthFraction'], 'Breakout.atLengthFraction'),
  ),
);

JsonMap _encodeInlineAdapter(InlineAdapter a) => {
  'fromConnector': a.fromConnector.v,
  'toConnector': a.toConnector.v,
  'satisfiesRuleIds': a.satisfiesRuleIds,
  if (a.model != null) 'model': a.model,
};

InlineAdapter _decodeInlineAdapter(JsonMap json) => InlineAdapter(
  fromConnector: ConnectorTypeId(
    asStr(json['fromConnector'], 'InlineAdapter.fromConnector'),
  ),
  toConnector: ConnectorTypeId(
    asStr(json['toConnector'], 'InlineAdapter.toConnector'),
  ),
  model: asStrOrNull(json['model'], 'InlineAdapter.model'),
  satisfiesRuleIds: [
    for (final r in asJsonList(
      json['satisfiesRuleIds'] ?? const <Object?>[],
      'InlineAdapter.satisfiesRuleIds',
    ))
      asStr(r, 'InlineAdapter.satisfiesRuleIds[]'),
  ],
);

JsonMap _encodeTestResult(TestResult t) {
  final json = <String, Object?>{'pass': t.pass};
  putIfNotNull(json, 'headroom', t.headroom);
  putIfNotNull(json, 'certificateId', t.certificateId);
  return json;
}

TestResult _decodeTestResult(JsonMap json) => TestResult(
  pass: asBool(json['pass'], 'TestResult.pass'),
  headroom: asIntOrNull(json['headroom'], 'TestResult.headroom'),
  certificateId: asStrOrNull(json['certificateId'], 'TestResult.certificateId'),
);

JsonMap _encodeStructureOrigin(StructureOrigin o) {
  final json = <String, Object?>{
    'structureBodyId': o.structureBodyId.v,
    'fieldLabel': o.fieldLabel,
  };
  // ═══════════════════════════════════════════════════════════════════
  // `outletId` STOPPED BEING UNCONDITIONAL AND CR-117 STILL HOLDS
  // ═══════════════════════════════════════════════════════════════════
  // The key was required until `#718`, so EVERY document ever written
  // carries one: reading yields that id and writing writes it back, and
  // no existing file moves a byte. Only a run somebody has said comes out
  // of no box omits it, and that run could not be authored before this
  // change. `kSchemaVersion` therefore does not move.
  //
  // Sorted-key order is unaffected: `putIfNotNull` writes into the same
  // map the literal above builds, and the encoder sorts on the way out.
  putIfNotNull(json, 'outletId', o.outletId?.v);
  // AND `boxless` IS WRITTEN ONLY WHEN TRUE, for the same reason and one
  // more: false is what every older document means, so emitting it would
  // rewrite every file in the corpus on first save.
  if (o.boxless) json['boxless'] = true;
  // ADDITIVE FROM M3-J, and CR-117 holds without a schema bump because
  // the key was UNCONDITIONAL before it: every document ever written
  // carries it, reading yields that value and writing writes it back, so
  // no existing file moves a byte. Only a run whose wall end nobody has
  // decided omits it, and that run did not exist before this change.
  if (o.terminationField case final t?) {
    json['terminationField'] = encodeEnumName(t);
  }
  // DR-046. OMITTED WHEN NULL, and null is the state of every home run
  // ever written: the field did not exist, and nothing infers it from
  // `terminationField`. So no existing file moves a byte and
  // `kSchemaVersion` does not move (CR-117).
  if (o.terminationRack case final t?) {
    json['terminationRack'] = encodeEnumName(t);
  }
  putIfNotNull(json, 'rackLabel', o.rackLabel);
  // DR-074 §11.73.2, AND WRITTEN ONLY WHEN TRUE for `linkClassLocked`'s
  // reason rather than `designatorLocked`'s: false is what every document
  // written before this key means, since nothing could hand-set a label
  // and say so, and emitting it would rewrite every file in the corpus on
  // first save. `kSchemaVersion` does not move (CR-117).
  if (o.rackLabelLocked) json['rackLabelLocked'] = true;
  if (o.wall != null) json['wall'] = encodeEnumName(o.wall!);
  if (o.mountSurface != null) {
    json['mountSurface'] = encodeEnumName(o.mountSurface!);
  }
  putIfNotNull(json, 'mountHeightAffNm', o.mountHeightAff?.nm);
  return json;
}

StructureOrigin _decodeStructureOrigin(JsonMap json) => StructureOrigin(
  structureBodyId: _decodeUuid(
    json['structureBodyId'],
    'StructureOrigin.structureBodyId',
  ),
  outletId: _decodeUuidOrNull(json['outletId'], 'StructureOrigin.outletId'),
  fieldLabel: asStr(json['fieldLabel'], 'StructureOrigin.fieldLabel'),
  // ABSENT MEANS FALSE, which is what every document written before
  // `#718` means: they all name a box.
  boxless:
      json['boxless'] != null &&
      asBool(json['boxless'], 'StructureOrigin.boxless'),
  terminationField: json['terminationField'] == null
      ? null
      : decodeEnumStrict(
          TerminationType.values,
          asStr(json['terminationField'], 'StructureOrigin.terminationField'),
          'StructureOrigin.terminationField',
        ),
  terminationRack: json['terminationRack'] == null
      ? null
      : decodeEnumStrict(
          TerminationType.values,
          asStr(json['terminationRack'], 'StructureOrigin.terminationRack'),
          'StructureOrigin.terminationRack',
        ),
  rackLabel: asStrOrNull(json['rackLabel'], 'StructureOrigin.rackLabel'),
  // ABSENT MEANS FALSE: every document written before DR-074 carries a
  // label the allocator produced, and none of them could say otherwise.
  rackLabelLocked:
      json['rackLabelLocked'] != null &&
      asBool(json['rackLabelLocked'], 'StructureOrigin.rackLabelLocked'),
  wall: json['wall'] == null
      ? null
      : decodeEnumStrict(
          Wall.values,
          asStr(json['wall'], 'StructureOrigin.wall'),
          'StructureOrigin.wall',
        ),
  mountSurface: json['mountSurface'] == null
      ? null
      : decodeEnumStrict(
          MountSurface.values,
          asStr(json['mountSurface'], 'StructureOrigin.mountSurface'),
          'StructureOrigin.mountSurface',
        ),
  mountHeightAff: _decodeLenOrNull(
    json['mountHeightAffNm'],
    'StructureOrigin.mountHeightAffNm',
  ),
);

JsonMap _encodeLink(Link l) {
  final json = <String, Object?>{
    'id': l.id.v,
    'designator': l.designator,
    'media': l.media.v,
    'order': l.order.v,
    'meta': _encodeEntityMeta(l.meta),
    'designatorLocked': l.designatorLocked,
    'linkClass': encodeEnumName(l.linkClass),
    'services': [for (final s in l.services) _encodeService(s)],
    'conductors': [for (final c in l.conductors) _encodeConductor(c)],
    'breakouts': [for (final b in l.breakouts) _encodeBreakout(b)],
    'inlineAdapters': [
      for (final a in l.inlineAdapters) _encodeInlineAdapter(a),
    ],
    'shielded': l.shielded,
    // `plenum` IS GONE (DR-079 §11.78.1). `Link` carried it beside
    // `jacket` with no doc comment and no stated relationship, so a link
    // could say `cmp` and `plenum: false` at once and nothing noticed.
    // The listing already answers the question; two fields for one fact
    // is one field too many. It was `false` on all 27 links that carried
    // it and `true` on none, so it never held information.
    if (l.lowSmokeZeroHalogen case final bool v) 'lowSmokeZeroHalogen': v,
    if (l.directBurialRated case final bool v) 'directBurialRated': v,
    'lifecycleStatus': encodeLifecycleStatus(l.lifecycleStatus),
    'roughInStatus': encodeEnumName(l.roughInStatus),
  };
  // TRUE-ONLY, ABSENT OTHERWISE — DR-008 §11.8.2 requires it and CR-117's
  // absent-key-is-not-null contract permits it. `false` is the normal case
  // (nobody has hand-set this link's class), so every document written
  // before this key existed still encodes BYTE-FOR-BYTE and
  // `kSchemaVersion` does not move.
  //
  // Deliberately NOT the shape of `designatorLocked` six lines above,
  // which is written unconditionally. Copying that here would add a key to
  // every Link in every existing document — a rewrite of every file on
  // disk to record something no one has said.
  if (l.linkClassLocked) json['linkClassLocked'] = true;
  putIfNotNull(json, 'notes', l.notes);
  putIfNotNull(json, 'cableSpecId', l.cableSpecId);
  putIfNotNull(json, 'gaugeAwg', l.gaugeAwg);
  if (l.jacket != null) json['jacket'] = encodeEnumName(l.jacket!);
  putIfNotNull(json, 'jacketColorId', l.jacketColorId?.v);
  // THE EXCEPTION, and it is ADDITIVE-OPTIONAL on purpose. `putIfNotNull`
  // writes nothing when the value is null, and null is the normal case
  // ("the cable matches the convention"), so every document that has
  // never recorded a wrong-colour pull encodes BYTE-FOR-BYTE as it did
  // before this key existed. That is why `kSchemaVersion` does not move:
  // an older reader never looks at this key, so it neither throws nor
  // degrades — the opposite of v2's breaking omission of previously
  // mandatory outlet keys. Sorted-key adjacency to `jacketColorId` is
  // deliberate: the pair reads as a pair when a human opens a
  // `.rackpal`.
  putIfNotNull(json, 'jacketColorPulledId', l.jacketColorPulledId?.v);
  putIfNotNull(json, 'routedLengthNm', l.routedLength?.nm);
  putIfNotNull(json, 'cutLengthNm', l.cutLength?.nm);
  putIfNotNull(json, 'terminatedLengthNm', l.terminatedLength?.nm);
  putIfNotNull(json, 'slack', l.slack?.v);
  putIfNotNull(json, 'pathwayId', l.pathwayId?.v);
  if (l.crossover != null) json['crossover'] = encodeEnumName(l.crossover!);
  if (l.test != null) json['test'] = _encodeTestResult(l.test!);
  putIfNotNull(json, 'installedBy', l.installedBy);
  // ADDITIVE, and `0` MUST STILL WRITE. `putIfNotNull` tests the value
  // against null rather than against falsiness, so a confirmed count of
  // none reaches disk as `"spliceCount": 0` and an unlooked-at run has
  // no key at all — which is the entire distinction DR-020 sect 11.19.2(3)
  // asked for. Absent means unknown; it never means zero.
  putIfNotNull(json, 'spliceCount', l.spliceCount);
  if (l.terminatedAt != null) {
    json['terminatedAt'] = encodeDateTime(l.terminatedAt!);
  }
  if (l.structureOrigin != null) {
    json['structureOrigin'] = _encodeStructureOrigin(l.structureOrigin!);
  }
  return json;
}

Link _decodeLink(Uuid id, JsonMap json) => Link(
  id: id,
  designator: asStr(json['designator'], 'Link.designator'),
  media: MediaTypeId(asStr(json['media'], 'Link.media')),
  order: FracIndex(asStr(json['order'], 'Link.order')),
  meta: _decodeEntityMeta(asJsonMap(json['meta'], 'Link.meta')),
  designatorLocked: asBool(json['designatorLocked'], 'Link.designatorLocked'),
  linkClass: decodeEnumStrict(
    LinkClass.values,
    asStr(json['linkClass'], 'Link.linkClass'),
    'Link.linkClass',
  ),
  // Absent means false — the key is written only when true. An older
  // document simply has no opinion here, which is exactly "no one
  // hand-set this class".
  linkClassLocked: asBool(
    json['linkClassLocked'] ?? false,
    'Link.linkClassLocked',
  ),
  services: decodeObjectList(json['services'], 'Link.services', _decodeService),
  conductors: decodeObjectList(
    json['conductors'],
    'Link.conductors',
    _decodeConductor,
  ),
  breakouts: decodeObjectList(
    json['breakouts'],
    'Link.breakouts',
    _decodeBreakout,
  ),
  inlineAdapters: decodeObjectList(
    json['inlineAdapters'],
    'Link.inlineAdapters',
    _decodeInlineAdapter,
  ),
  cableSpecId: asStrOrNull(json['cableSpecId'], 'Link.cableSpecId'),
  gaugeAwg: asIntOrNull(json['gaugeAwg'], 'Link.gaugeAwg'),
  jacket: json['jacket'] == null
      ? null
      : decodeEnumStrict(
          JacketListing.values,
          asStr(json['jacket'], 'Link.jacket'),
          'Link.jacket',
        ),
  // A DANGLING ID DECODES INTACT (G4). The codec does not resolve it
  // against `settings.jacketColorConventions` and must not: dropping an
  // id whose entry has been deleted would destroy the one record of what
  // was actually pulled. Consumers count it as unknown.
  jacketColorId: _decodeJacketColorIdOrNull(
    json['jacketColorId'],
    'Link.jacketColorId',
  ),
  // Same rule, and for a stronger reason: this id is the ONE record
  // that a wrong colour went in the wall. `json['jacketColorPulledId']`
  // is null in every file written before this key existed, so the field
  // is null and behaviour is identical. No `?? const {}` guard is
  // wanted here — that pattern exists only for MAPS, where
  // `asJsonMap(null, …)` throws.
  jacketColorPulledId: _decodeJacketColorIdOrNull(
    json['jacketColorPulledId'],
    'Link.jacketColorPulledId',
  ),
  shielded: asBool(json['shielded'], 'Link.shielded'),
  // ABSENT MEANS UNKNOWN (G4/CR-114), which is why these two are
  // written only when they hold a value and read back as null when they
  // are missing. A `false` here is a recorded no.
  lowSmokeZeroHalogen: asBoolOrNull(
    json['lowSmokeZeroHalogen'],
    'Link.lowSmokeZeroHalogen',
  ),
  directBurialRated: asBoolOrNull(
    json['directBurialRated'],
    'Link.directBurialRated',
  ),
  routedLength: _decodeLenOrNull(json['routedLengthNm'], 'Link.routedLengthNm'),
  cutLength: _decodeLenOrNull(json['cutLengthNm'], 'Link.cutLengthNm'),
  terminatedLength: _decodeLenOrNull(
    json['terminatedLengthNm'],
    'Link.terminatedLengthNm',
  ),
  slack: json['slack'] == null
      ? null
      : Permille(asInt(json['slack'], 'Link.slack')),
  pathwayId: _decodeUuidOrNull(json['pathwayId'], 'Link.pathwayId'),
  crossover: json['crossover'] == null
      ? null
      : decodeEnumStrict(
          CrossoverKind.values,
          asStr(json['crossover'], 'Link.crossover'),
          'Link.crossover',
        ),
  lifecycleStatus: decodeLifecycleStatus(
    asStr(json['lifecycleStatus'], 'Link.lifecycleStatus'),
  ),
  roughInStatus: decodeEnumStrict(
    RoughInStatus.values,
    asStr(json['roughInStatus'], 'Link.roughInStatus'),
    'Link.roughInStatus',
  ),
  test: decodeNullableObject(json, 'test', 'Link.test', _decodeTestResult),
  installedBy: asStrOrNull(json['installedBy'], 'Link.installedBy'),
  spliceCount: asIntOrNull(json['spliceCount'], 'Link.spliceCount'),
  terminatedAt: json['terminatedAt'] == null
      ? null
      : decodeDateTime(asStr(json['terminatedAt'], 'Link.terminatedAt')),
  structureOrigin: decodeNullableObject(
    json,
    'structureOrigin',
    'Link.structureOrigin',
    _decodeStructureOrigin,
  ),
  notes: asStrOrNull(json['notes'], 'Link.notes'),
);

// --- Pathway -------------------------------------------------------------

JsonMap _encodePathway(Pathway p) {
  final json = <String, Object?>{
    'id': p.id.v,
    'name': p.name,
    'order': p.order.v,
    'meta': _encodeEntityMeta(p.meta),
    'kind': encodeEnumName(p.kind),
    'containsLineVoltage': p.containsLineVoltage,
  };
  // WRITTEN ONLY WHEN PRESENT, which is what keeps this field free
  // (DR-026 §11.25.1). #157's own description priced it as changing
  // stored state and moving `kSchemaVersion`; a nullable key emitted only
  // when set does neither, and every file already on disk re-encodes byte
  // for byte. `tia570Grade`'s precedent (DR-024), and
  // `MediaTypeDef.aliases`'s before it.
  putIfNotNull(json, 'designator', p.designator);
  putIfNotNull(json, 'notes', p.notes);
  putIfNotNull(json, 'fromLocationId', p.fromLocationId?.v);
  putIfNotNull(json, 'toLocationId', p.toLocationId?.v);
  putIfNotNull(json, 'nominalLengthNm', p.nominalLength?.nm);
  putIfNotNull(json, 'pathwayMedia', p.pathwayMedia?.v);
  return json;
}

Pathway _decodePathway(Uuid id, JsonMap json) => Pathway(
  id: id,
  name: asStr(json['name'], 'Pathway.name'),
  order: FracIndex(asStr(json['order'], 'Pathway.order')),
  meta: _decodeEntityMeta(asJsonMap(json['meta'], 'Pathway.meta')),
  kind: decodeEnumStrict(
    PathwayKind.values,
    asStr(json['kind'], 'Pathway.kind'),
    'Pathway.kind',
  ),
  containsLineVoltage: asBool(
    json['containsLineVoltage'],
    'Pathway.containsLineVoltage',
  ),
  fromLocationId: _decodeUuidOrNull(
    json['fromLocationId'],
    'Pathway.fromLocationId',
  ),
  toLocationId: _decodeUuidOrNull(json['toLocationId'], 'Pathway.toLocationId'),
  nominalLength: _decodeLenOrNull(
    json['nominalLengthNm'],
    'Pathway.nominalLengthNm',
  ),
  pathwayMedia: json['pathwayMedia'] == null
      ? null
      : MediaTypeId(asStr(json['pathwayMedia'], 'Pathway.pathwayMedia')),
  designator: asStrOrNull(json['designator'], 'Pathway.designator'),
  notes: asStrOrNull(json['notes'], 'Pathway.notes'),
);

// --- Outlet ----------------------------------------------------------------

JsonMap _encodeOutlet(Outlet o) {
  final json = <String, Object?>{
    'id': o.id.v,
    'structureBodyId': o.structureBodyId.v,
    'designation': o.designation,
    'order': o.order.v,
    'meta': _encodeEntityMeta(o.meta),
  };
  putIfNotNull(json, 'notes', o.notes);
  putIfNotNull(
    json,
    'planPin',
    o.planPin == null ? null : _encodePlanPin(o.planPin!),
  );
  putIfNotNull(json, 'locationId', o.locationId?.v);
  if (o.wall != null) json['wall'] = encodeEnumName(o.wall!);
  if (o.mountSurface != null) {
    json['mountSurface'] = encodeEnumName(o.mountSurface!);
  }
  putIfNotNull(json, 'mountHeightAffNm', o.mountHeightAff?.nm);
  putIfNotNull(json, 'floorNumber', o.floorNumber);
  putIfNotNull(json, 'outletTemplateId', o.outletTemplateId);
  putIfNotNull(json, 'tia570Grade', o.tia570Grade);
  putIfNotNull(json, 'pathwayId', o.pathwayId?.v);
  putIfNotNull(json, 'nominalRunLengthNm', o.nominalRunLength?.nm);
  // Omitted when empty, for the reason given on `_placementUnknown`: every
  // shipped outlet predates this key.
  if (o.unknown.isNotEmpty) json['unknown'] = o.unknown;
  // DR-007's gang list. Omitted when empty, and it is empty on every
  // document ever written, which is why `kSchemaVersion` does not move: a
  // key an encoder never emits costs no existing file a byte (CR-117).
  if (o.gangs.isNotEmpty) {
    json['gangs'] = [for (final g in o.gangs) _encodeGang(g)];
  }
  return json;
}

// --- Gang / Strap / cell occupant (DR-007 §11.7) ------------------------------
//
// A GANG WITH NO STRAP ENCODES AS `{}`, and that is G4 rather than an
// oversight: null is UNKNOWN and unknown is an absent key, never an
// explicit null (CR-114/CR-117). A gang whose part nobody has picked is
// an ordinary rough-in state.
//
// CELLS ARE A LIST, NOT AN INT-KEYED OBJECT. Two reasons and the second
// is the load-bearing one. JSON object keys are strings, so an int-keyed
// map round-trips through a lexicographic sort that only coincides with
// numeric order while a strap has fewer than ten cells; six is the bound
// today and relying on it puts a silent trap under any future part. And
// an UNFILLED CELL IS SIMPLY NOT IN THE LIST, which is the absent-key
// discipline stated structurally rather than by convention: there is no
// shape a "cell 4 is null" entry could even take.
//
// Sorted by index on the way out, so the bytes are a function of the
// document and not of a map's iteration order.

// A PASS-THROUGH IS A SECOND KEY, NOT A TAGGED UNION (DR-047 §11.46.7).
// `strap` is written exactly as it was, byte for byte, so no document in
// existence changes and `kSchemaVersion` does not move; `passThrough` is
// a key nothing has ever written. Wrapping both in a `{"kind": ...}`
// envelope would have been tidier and would have rewritten every plate
// ever saved, which is CR-117's whole point.
//
// A gang carrying BOTH keys is malformed rather than forward-compatible:
// an opening holds one part. Refused at the door, like a 3-wide strap.

JsonMap _encodeGang(Gang g) {
  final json = <String, Object?>{};
  switch (g.fitting) {
    case null:
      break;
    case final Strap s:
      json['strap'] = _encodeStrap(s);
    case final PassThrough p:
      json['passThrough'] = <String, Object?>{'style': p.style.name};
  }
  return json;
}

Gang _decodeGang(JsonMap json) {
  final strap = decodeNullableObject(json, 'strap', 'Gang.strap', _decodeStrap);
  final passThrough = decodeNullableObject(
    json,
    'passThrough',
    'Gang.passThrough',
    _decodePassThrough,
  );
  if (strap != null && passThrough != null) {
    throw const FormatException(
      'Gang has both a strap and a passThrough, and one opening holds '
      'one part (DR-047 §11.46.2).',
    );
  }
  return Gang(fitting: strap ?? passThrough);
}

PassThrough _decodePassThrough(JsonMap json) => PassThrough(
  decodeEnumStrict(
    PassThroughStyle.values,
    asStr(json['style'], 'Gang.passThrough.style'),
    'Gang.passThrough.style',
  ),
);

JsonMap _encodeStrap(Strap s) {
  final indices = s.cells.keys.toList()..sort();
  return <String, Object?>{
    'width': s.width,
    'height': s.height,
    if (indices.isNotEmpty)
      'cells': [
        for (final i in indices)
          <String, Object?>{'cell': i, ..._encodeCellOccupant(s.cells[i]!)},
      ],
  };
}

Strap _decodeStrap(JsonMap json) {
  final width = asInt(json['width'], 'Strap.width');
  final height = asInt(json['height'], 'Strap.height');
  // THE DERIVED CONSTRAINT, ENFORCED AT THE DOOR (§11.7.1). A 3-wide
  // strap is not a part, so a file claiming one is malformed rather than
  // forward-compatible, and `Strap`'s own constructor would throw an
  // ArgumentError that reads as a bug in this build rather than as a bad
  // file. Reported here as the FormatException every other malformed
  // value in this codec reports.
  if (!isValidStrapSize(width, height)) {
    throw FormatException(
      'Strap.width x Strap.height is $width x $height, which is not a '
      'shipped part: DR-007 §11.7.1 bounds W to '
      '$kMinStrapWidth..$kMaxStrapWidth and H to '
      '$kMinStrapHeight..$kMaxStrapHeight.',
    );
  }
  final strap = Strap(width: width, height: height);
  for (final entry in asJsonList(json['cells'] ?? const [], 'Strap.cells')) {
    final cell = asJsonMap(entry, 'Strap.cells[]');
    final index = asInt(cell['cell'], 'Strap.cells[].cell');
    if (!strap.holdsIndex(index)) {
      throw FormatException(
        'Strap.cells[].cell is $index, outside a $width x $height strap.',
      );
    }
    strap.cells[index] = _decodeCellOccupant(cell);
  }
  return strap;
}

JsonMap _encodeCellOccupant(CellOccupant o) => switch (o) {
  LinkEndOccupant(:final linkId) => {'kind': 'linkEnd', 'linkId': linkId.v},
  ConductorOccupant(:final conductor) => {
    'kind': 'conductor',
    'linkId': conductor.linkId.v,
    'conductorIndex': conductor.index,
  },
  BlankInsert() => {'kind': 'blank'},
};

CellOccupant _decodeCellOccupant(JsonMap json) {
  final kind = asStr(json['kind'], 'Strap.cells[].kind');
  switch (kind) {
    case 'linkEnd':
      return LinkEndOccupant(
        _decodeUuid(json['linkId'], 'LinkEndOccupant.linkId'),
      );
    case 'conductor':
      return ConductorOccupant(
        ConductorRef(
          _decodeUuid(json['linkId'], 'ConductorOccupant.linkId'),
          asInt(json['conductorIndex'], 'ConductorOccupant.conductorIndex'),
        ),
      );
    case 'blank':
      return const BlankInsert();
    default:
      throw FormatException('Unrecognised Strap.cells[].kind "$kind".');
  }
}

Outlet _decodeOutlet(Uuid id, JsonMap json) => Outlet(
  id: id,
  structureBodyId: _decodeUuid(
    json['structureBodyId'],
    'Outlet.structureBodyId',
  ),
  designation: asStr(json['designation'], 'Outlet.designation'),
  order: FracIndex(asStr(json['order'], 'Outlet.order')),
  meta: _decodeEntityMeta(asJsonMap(json['meta'], 'Outlet.meta')),
  locationId: _decodeUuidOrNull(json['locationId'], 'Outlet.locationId'),
  wall: json['wall'] == null
      ? null
      : decodeEnumStrict(
          Wall.values,
          asStr(json['wall'], 'Outlet.wall'),
          'Outlet.wall',
        ),
  mountSurface: json['mountSurface'] == null
      ? null
      : decodeEnumStrict(
          MountSurface.values,
          asStr(json['mountSurface'], 'Outlet.mountSurface'),
          'Outlet.mountSurface',
        ),
  mountHeightAff: _decodeLenOrNull(
    json['mountHeightAffNm'],
    'Outlet.mountHeightAffNm',
  ),
  floorNumber: asIntOrNull(json['floorNumber'], 'Outlet.floorNumber'),
  outletTemplateId: asStrOrNull(
    json['outletTemplateId'],
    'Outlet.outletTemplateId',
  ),
  tia570Grade: asStrOrNull(json['tia570Grade'], 'Outlet.tia570Grade'),
  pathwayId: _decodeUuidOrNull(json['pathwayId'], 'Outlet.pathwayId'),
  nominalRunLength: _decodeLenOrNull(
    json['nominalRunLengthNm'],
    'Outlet.nominalRunLengthNm',
  ),
  notes: asStrOrNull(json['notes'], 'Outlet.notes'),
  planPin: _decodePlanPinOrNull(json['planPin'], 'Outlet.planPin'),
  // `?? const []` because the key is absent on every document written
  // before M3-H, which is all of them.
  gangs: decodeObjectList(
    json['gangs'] ?? const [],
    'Outlet.gangs',
    _decodeGang,
  ),
  unknown: _unknownBag(json, 'Outlet'),
);

// --- StructureBody -----------------------------------------------------------

JsonMap _encodeStructureBody(StructureBody s) {
  final json = <String, Object?>{
    'id': s.id.v,
    'deviceId': s.deviceId.v,
    'title': s.title,
    'meta': _encodeEntityMeta(s.meta),
    'role': encodeEnumName(s.role),
    'sheetEdge': encodeEnumName(s.sheetEdge),
  };
  putIfNotNull(
    json,
    'distributionDeviceLocationId',
    s.distributionDeviceLocationId?.v,
  );
  putIfNotNull(json, 'enclosureModel', s.enclosureModel);
  return json;
}

StructureBody _decodeStructureBody(Uuid id, JsonMap json) => StructureBody(
  id: id,
  deviceId: _decodeUuid(json['deviceId'], 'StructureBody.deviceId'),
  title: asStr(json['title'], 'StructureBody.title'),
  meta: _decodeEntityMeta(asJsonMap(json['meta'], 'StructureBody.meta')),
  role: decodeEnumStrict(
    StructureRole.values,
    asStr(json['role'], 'StructureBody.role'),
    'StructureBody.role',
  ),
  distributionDeviceLocationId: _decodeUuidOrNull(
    json['distributionDeviceLocationId'],
    'StructureBody.distributionDeviceLocationId',
  ),
  enclosureModel: asStrOrNull(
    json['enclosureModel'],
    'StructureBody.enclosureModel',
  ),
  sheetEdge: decodeEnumStrict(
    SheetEdge.values,
    asStr(json['sheetEdge'], 'StructureBody.sheetEdge'),
    'StructureBody.sheetEdge',
  ),
);

// --- Circuit -----------------------------------------------------------------

JsonMap _encodeCircuit(Circuit c) {
  final json = <String, Object?>{
    'id': c.id.v,
    'designator': c.designator,
    'breakerAmps': c.breakerAmps,
    'volts': c.volts,
    'dedicated': c.dedicated,
    'meta': _encodeEntityMeta(c.meta),
  };
  putIfNotNull(json, 'rackId', c.rackId?.v);
  putIfNotNull(json, 'phase', c.phase);
  putIfNotNull(json, 'locationId', c.locationId?.v);
  return json;
}

Circuit _decodeCircuit(Uuid id, JsonMap json) => Circuit(
  id: id,
  designator: asStr(json['designator'], 'Circuit.designator'),
  breakerAmps: asInt(json['breakerAmps'], 'Circuit.breakerAmps'),
  volts: asInt(json['volts'], 'Circuit.volts'),
  meta: _decodeEntityMeta(asJsonMap(json['meta'], 'Circuit.meta')),
  rackId: _decodeUuidOrNull(json['rackId'], 'Circuit.rackId'),
  phase: asIntOrNull(json['phase'], 'Circuit.phase'),
  dedicated: asBool(json['dedicated'], 'Circuit.dedicated'),
  locationId: _decodeUuidOrNull(json['locationId'], 'Circuit.locationId'),
);

// --- Sheet / SheetItem -------------------------------------------------------

JsonMap _encodeSheetItem(SheetItem item) => {
  'id': item.id.v,
  'targetId': item.targetId.v,
  'position': _encodePt(item.position),
  'zOrder': item.zOrder.v,
  'rotationQuarterTurns': item.rotationQuarterTurns,
  'collapsed': item.collapsed,
  'pinned': item.pinned,
  'unknown': item.unknown,
};

SheetItem _decodeSheetItem(Uuid id, JsonMap json) => SheetItem(
  id: id,
  targetId: _decodeUuid(json['targetId'], 'SheetItem.targetId'),
  position: _decodePt(asJsonMap(json['position'], 'SheetItem.position')),
  zOrder: FracIndex(asStr(json['zOrder'], 'SheetItem.zOrder')),
  rotationQuarterTurns: asInt(
    json['rotationQuarterTurns'] ?? 0,
    'SheetItem.rotationQuarterTurns',
  ),
  collapsed: asBool(json['collapsed'], 'SheetItem.collapsed'),
  pinned: asBool(json['pinned'], 'SheetItem.pinned'),
  unknown: asJsonMap(
    json['unknown'] ?? const <String, Object?>{},
    'SheetItem.unknown',
  ),
);

JsonMap _encodeSheet(Sheet s) => {
  'id': s.id.v,
  'number': s.number,
  'title': s.title,
  'order': s.order.v,
  'meta': _encodeEntityMeta(s.meta),
  'kind': encodeEnumName(s.kind),
  'paper': encodeEnumName(s.paper),
  'orientation': encodeEnumName(s.orientation),
  'scaleNumerator': s.scaleNumerator,
  'scaleDenominator': s.scaleDenominator,
  'carriesLegend': s.carriesLegend,
  'includedRackIds': [for (final rid in s.includedRackIds) rid.v],
  'includedDeviceIds': [for (final did in s.includedDeviceIds) did.v],
  'domainFilter': [for (final dom in s.domainFilter) dom.v],
  'lifecycleFilter': [
    for (final l in s.lifecycleFilter) encodeLifecycleStatus(l),
  ],
  'items': {
    for (final e in s.items.entries) e.key.v: _encodeSheetItem(e.value),
  },
};

Sheet _decodeSheet(Uuid id, JsonMap json) {
  final itemsJson = asJsonMap(json['items'], 'Sheet.items');
  return Sheet(
    id: id,
    number: asStr(json['number'], 'Sheet.number'),
    title: asStr(json['title'], 'Sheet.title'),
    order: FracIndex(asStr(json['order'], 'Sheet.order')),
    meta: _decodeEntityMeta(asJsonMap(json['meta'], 'Sheet.meta')),
    kind: decodeEnumStrict(
      SheetKind.values,
      asStr(json['kind'], 'Sheet.kind'),
      'Sheet.kind',
    ),
    paper: decodeEnumStrict(
      PaperSize.values,
      asStr(json['paper'], 'Sheet.paper'),
      'Sheet.paper',
    ),
    orientation: decodeEnumStrict(
      PageOrientation.values,
      asStr(json['orientation'], 'Sheet.orientation'),
      'Sheet.orientation',
    ),
    scaleNumerator: asInt(json['scaleNumerator'], 'Sheet.scaleNumerator'),
    scaleDenominator: asInt(json['scaleDenominator'], 'Sheet.scaleDenominator'),
    carriesLegend: asBool(json['carriesLegend'], 'Sheet.carriesLegend'),
    includedRackIds: [
      for (final v in asJsonList(
        json['includedRackIds'],
        'Sheet.includedRackIds',
      ))
        _decodeUuid(v, 'Sheet.includedRackIds[]'),
    ],
    includedDeviceIds: [
      for (final v in asJsonList(
        json['includedDeviceIds'],
        'Sheet.includedDeviceIds',
      ))
        _decodeUuid(v, 'Sheet.includedDeviceIds[]'),
    ],
    domainFilter: {
      for (final v in asJsonList(json['domainFilter'], 'Sheet.domainFilter'))
        SignalDomainId(asStr(v, 'Sheet.domainFilter[]')),
    },
    lifecycleFilter: {
      for (final v in asJsonList(
        json['lifecycleFilter'],
        'Sheet.lifecycleFilter',
      ))
        decodeLifecycleStatus(asStr(v, 'Sheet.lifecycleFilter[]')),
    },
    items: {
      for (final e in itemsJson.entries)
        Uuid(e.key): _decodeSheetItem(
          Uuid(e.key),
          asJsonMap(e.value, 'Sheet.items[${e.key}]'),
        ),
    },
  );
}

// --- Note --------------------------------------------------------------------

JsonMap _encodeNote(Note n) {
  final json = <String, Object?>{
    'id': n.id.v,
    'text': n.text,
    'meta': _encodeEntityMeta(n.meta),
  };
  putIfNotNull(json, 'targetId', n.targetId?.v);
  if (n.position != null) json['position'] = _encodePt(n.position!);
  return json;
}

Note _decodeNote(Uuid id, JsonMap json) => Note(
  id: id,
  text: asStr(json['text'], 'Note.text'),
  meta: _decodeEntityMeta(asJsonMap(json['meta'], 'Note.meta')),
  targetId: _decodeUuidOrNull(json['targetId'], 'Note.targetId'),
  position: decodeNullableObject(json, 'position', 'Note.position', _decodePt),
);

// --- AckedFinding --------------------------------------------------------

JsonMap _encodeAckedFinding(AckedFinding a) {
  final json = <String, Object?>{
    'id': a.id.v,
    'ruleId': a.ruleId,
    'targetFingerprint': a.targetFingerprint,
    'reason': a.reason,
    'by': a.by,
    'at': encodeDateTime(a.at),
    'demotedTo': encodeSeverity(a.demotedTo),
    'meta': _encodeEntityMeta(a.meta),
  };
  putIfNotNull(json, 'targetEntityId', a.targetEntityId?.v);
  return json;
}

AckedFinding _decodeAckedFinding(Uuid id, JsonMap json) => AckedFinding(
  id: id,
  ruleId: asStr(json['ruleId'], 'AckedFinding.ruleId'),
  targetFingerprint: asStr(
    json['targetFingerprint'],
    'AckedFinding.targetFingerprint',
  ),
  reason: asStr(json['reason'], 'AckedFinding.reason'),
  by: asStr(json['by'], 'AckedFinding.by'),
  at: decodeDateTime(asStr(json['at'], 'AckedFinding.at')),
  demotedTo: decodeSeverity(asStr(json['demotedTo'], 'AckedFinding.demotedTo')),
  meta: _decodeEntityMeta(asJsonMap(json['meta'], 'AckedFinding.meta')),
  targetEntityId: _decodeUuidOrNull(
    json['targetEntityId'],
    'AckedFinding.targetEntityId',
  ),
);

// --- RevisionEntry -------------------------------------------------------
//
// The Dart model (rack_document.dart) declares exactly {revision, date,
// description, by} — no `meta` (despite CR-095 listing RevisionEntry
// among the types that carry EntityMeta; the model doesn't implement
// that yet) and no `issued` flag. The doc's worked JSON example (§6.2
// revisionBlock) shows a DIFFERENT shape — key "rev" instead of
// "revision", a bare date instead of a full timestamp, and an extra
// "issued" boolean the Dart type has no field for. This codec serializes
// the Dart model's actual fields, per this package's drift-resolution
// instructions; noted rather than silently resolved.

JsonMap _encodeRevisionEntry(RevisionEntry r) => {
  'revision': r.revision,
  'date': encodeDateTime(r.date),
  'description': r.description,
  'by': r.by,
};

RevisionEntry _decodeRevisionEntry(JsonMap json) => RevisionEntry(
  revision: asStr(json['revision'], 'RevisionEntry.revision'),
  date: decodeDateTime(asStr(json['date'], 'RevisionEntry.date')),
  description: asStr(json['description'], 'RevisionEntry.description'),
  by: asStr(json['by'], 'RevisionEntry.by'),
);

// --- Tombstone -----------------------------------------------------------

JsonMap _encodeTombstone(Tombstone t) => {
  'deletedAt': encodeDateTime(t.deletedAt),
  'entityType': t.entityType,
  'by': t.by,
};

// Tombstone carries no `id` field of its own (its identity is the
// document map key only) — the unused `id` parameter below exists purely
// so this matches the `T Function(Uuid id, JsonMap json)` shape
// `decodeUuidKeyedMap` expects for every other entity.
Tombstone _decodeTombstone(Uuid id, JsonMap json) => Tombstone(
  deletedAt: decodeDateTime(asStr(json['deletedAt'], 'Tombstone.deletedAt')),
  entityType: asStr(json['entityType'], 'Tombstone.entityType'),
  by: asStr(json['by'], 'Tombstone.by'),
);

// --- Registries: SignalDomainDef / SignalFamilyDef / ConnectorTypeDef /
//     MediaTypeDef / CableSpecDef / OutletTemplate / OutletDrop ----------

JsonMap _encodeSignalDomainDef(SignalDomainDef d) => {
  'id': d.id.v,
  'displayName': d.displayName,
  'tagPrefix': d.tagPrefix,
  'color': _encodeRgb(d.color),
  'colorDark': _encodeRgb(d.colorDark),
  'dashPattern': d.dashPattern,
  'lineWeightPermille': d.lineWeightPermille,
  'glyph': d.glyph,
  'glyphAlt': d.glyphAlt,
};

SignalDomainDef _decodeSignalDomainDef(SignalDomainId id, JsonMap json) =>
    SignalDomainDef(
      id: id,
      displayName: asStr(json['displayName'], 'SignalDomainDef.displayName'),
      tagPrefix: asStr(json['tagPrefix'], 'SignalDomainDef.tagPrefix'),
      color: _decodeRgb(asStr(json['color'], 'SignalDomainDef.color')),
      colorDark: _decodeRgb(
        asStr(json['colorDark'], 'SignalDomainDef.colorDark'),
      ),
      dashPattern: [
        for (final v in asJsonList(
          json['dashPattern'],
          'SignalDomainDef.dashPattern',
        ))
          asInt(v, 'SignalDomainDef.dashPattern[]'),
      ],
      lineWeightPermille: asInt(
        json['lineWeightPermille'],
        'SignalDomainDef.lineWeightPermille',
      ),
      glyph: asStr(json['glyph'], 'SignalDomainDef.glyph'),
      glyphAlt: asStr(json['glyphAlt'], 'SignalDomainDef.glyphAlt'),
    );

// SignalFamilyDef/ConnectorTypeDef/MediaTypeDef: the doc's worked JSON
// example (§6.2 registries.signalFamilies/connectors/media) shows
// materially different field sets (topologyFree/maxChannelLengthNm,
// contacts/matesWith, conductorCount/pairCount) that do not correspond
// to any field these Dart classes actually declare.
//
// `genderApplies` LEFT THAT LIST AT M4-B (board #173), joining
// `ConnectorTypeDef` with `pitch` beside it, so both are now encoded
// under the corpus's own key names. `isPathwayOnly` also left it, at
// M3-E/1, when `MediaTypeDef` declared it; **the codec still does not
// carry that one**, so a pathway-only media type does not survive a
// save. Filed rather than fixed here, because it is CR-109's defect and
// not this registry's. This codec serializes the real Dart fields
// (id/displayName/domain/defaultConnector/defaultDirection/
// defaultTopology/aliases, etc.), per this package's drift-resolution
// instructions.
//
// `shortTag` LEFT THAT LIST AT DR-010 (§11.10.3): the example's key and
// a real Dart field now agree on both name and meaning, so it is written
// under the doc's own name rather than a new one.
JsonMap _encodeSignalFamilyDef(SignalFamilyDef d) {
  final json = <String, Object?>{
    'id': d.id.v,
    'displayName': d.displayName,
    'domain': d.domain.v,
    'defaultConnector': d.defaultConnector.v,
    'defaultDirection': encodeEnumName(d.defaultDirection),
    'defaultTopology': encodeEnumName(d.defaultTopology),
    'aliases': d.aliases,
  };
  // DR-010 §11.10.3's three fields, ADDITIVE AND OPTIONAL — written only
  // when present, which is the `linkClassLocked` contract of §11.8.2
  // applied again and NOT the shape of `designatorLocked`, whose
  // unconditional write would add three keys to every family in every
  // existing document. A family decoded from a document written before
  // these keys existed re-encodes BYTE-FOR-BYTE, which is why
  // `kSchemaVersion` does not move: the `registries` key itself already
  // exists and every reader already parses it.
  //
  // `dashOverride` GOES THROUGH `putIfNotNull`, NOT AN `isEmpty` TEST.
  // The empty list is a real, shipped value — `audio.line_bal` overrides
  // to *solid* inside the dashed `audio.analog` domain — so "absent" and
  // "[]" must stay distinguishable on the wire. Suppressing empties here
  // would silently redraw that family with the domain's `6,3` dash on
  // reopen, which is the collision §4.4 moved it off in the first place.
  putIfNotNull(json, 'shortTag', d.shortTag);
  putIfNotNull(json, 'dashOverride', d.dashOverride);
  putIfNotNull(
    json,
    'lineWeightPermilleOverride',
    d.lineWeightPermilleOverride,
  );
  return json;
}

SignalFamilyDef _decodeSignalFamilyDef(SignalFamilyId id, JsonMap json) =>
    SignalFamilyDef(
      id: id,
      displayName: asStr(json['displayName'], 'SignalFamilyDef.displayName'),
      domain: SignalDomainId(asStr(json['domain'], 'SignalFamilyDef.domain')),
      defaultConnector: ConnectorTypeId(
        asStr(json['defaultConnector'], 'SignalFamilyDef.defaultConnector'),
      ),
      defaultDirection: decodeEnumStrict(
        PortDirection.values,
        asStr(json['defaultDirection'], 'SignalFamilyDef.defaultDirection'),
        'SignalFamilyDef.defaultDirection',
      ),
      defaultTopology: decodeEnumStrict(
        PortTopology.values,
        asStr(json['defaultTopology'], 'SignalFamilyDef.defaultTopology'),
        'SignalFamilyDef.defaultTopology',
      ),
      aliases: [
        for (final v in asJsonList(
          json['aliases'] ?? const <Object?>[],
          'SignalFamilyDef.aliases',
        ))
          asStr(v, 'SignalFamilyDef.aliases[]'),
      ],
      // ABSENT MEANS NULL, and null means "inherit the domain" — never
      // an invented default. `?? const []` here would turn every family
      // in an older document into an explicit solid override.
      shortTag: asStrOrNull(json['shortTag'], 'SignalFamilyDef.shortTag'),
      dashOverride: json['dashOverride'] == null
          ? null
          : [
              for (final v in asJsonList(
                json['dashOverride'],
                'SignalFamilyDef.dashOverride',
              ))
                asInt(v, 'SignalFamilyDef.dashOverride[]'),
            ],
      lineWeightPermilleOverride: asIntOrNull(
        json['lineWeightPermilleOverride'],
        'SignalFamilyDef.lineWeightPermilleOverride',
      ),
    );

JsonMap _encodeConnectorTypeDef(ConnectorTypeDef d) {
  final json = <String, Object?>{
    'id': d.id.v,
    'displayName': d.displayName,
    'aliases': d.aliases,
  };
  putIfNotNull(json, 'footprintWidthNm', d.footprintWidth?.nm);
  putIfNotNull(json, 'footprintHeightNm', d.footprintHeight?.nm);
  // M4-B's two, ADDITIVE AND WRITTEN ONLY WHEN PRESENT, for the reason
  // `_encodeMediaTypeDef` sets out below at length: `registries` is
  // serialized into every document, so a key written unconditionally
  // would appear in every connector entry of every file already on disk
  // and break `write(read(bytes)) == bytes` (CR-117) for exactly the
  // files a user cannot regenerate. This is why `kSchemaVersion` does
  // not move.
  putIfNotNull(json, 'pitchNm', d.pitch?.nm);
  // Suppressing `false` is safe HERE and would not be on a tri-state:
  // nothing means anything by "gender deliberately does not apply" that
  // it does not also mean by saying nothing, because `genderApplies` is
  // a `bool` whose false branch IS the silent one (registries.dart).
  if (d.genderApplies) json['genderApplies'] = true;
  // `matesWith` (`#255`, `CON-001`), ADDITIVE AND ONLY WHEN NON-EMPTY,
  // for the same reason as the two above. Suppressing the empty list is
  // safe because empty and absent mean the SAME thing here: the mating
  // set is unknown and `CON-001` skips it (registries.dart). A connector
  // that deliberately mates nothing and one nobody has seeded yet are
  // indistinguishable by design, so there is no second state for the
  // silent branch to lose.
  if (d.matesWith.isNotEmpty) {
    json['matesWith'] = [for (final m in d.matesWith) m.v];
  }
  return json;
}

ConnectorTypeDef _decodeConnectorTypeDef(ConnectorTypeId id, JsonMap json) =>
    ConnectorTypeDef(
      id: id,
      displayName: asStr(json['displayName'], 'ConnectorTypeDef.displayName'),
      aliases: [
        for (final v in asJsonList(
          json['aliases'] ?? const <Object?>[],
          'ConnectorTypeDef.aliases',
        ))
          asStr(v, 'ConnectorTypeDef.aliases[]'),
      ],
      footprintWidth: _decodeLenOrNull(
        json['footprintWidthNm'],
        'ConnectorTypeDef.footprintWidthNm',
      ),
      footprintHeight: _decodeLenOrNull(
        json['footprintHeightNm'],
        'ConnectorTypeDef.footprintHeightNm',
      ),
      pitch: _decodeLenOrNull(json['pitchNm'], 'ConnectorTypeDef.pitchNm'),
      genderApplies: asBool(
        json['genderApplies'] ?? false,
        'ConnectorTypeDef.genderApplies',
      ),
      matesWith: [
        for (final v in asJsonList(
          json['matesWith'] ?? const <Object?>[],
          'ConnectorTypeDef.matesWith',
        ))
          ConnectorTypeId(asStr(v, 'ConnectorTypeDef.matesWith[]')),
      ],
    );

JsonMap _encodeMediaTypeDef(MediaTypeDef d) {
  final json = <String, Object?>{
    'id': d.id.v,
    'displayName': d.displayName,
    'jacketOptions': [for (final j in d.jacketOptions) encodeEnumName(j)],
  };
  // BOTH ADDITIVE, BOTH WRITTEN ONLY WHEN PRESENT, and `aliases` does NOT
  // copy the unconditional shape it has on `SignalFamilyDef` and
  // `ConnectorTypeDef`. Those two carried the key from M0, so emitting it
  // always costs nothing; `MediaTypeDef` did not, so an unconditional
  // write would add an `aliases` key to every media entry in every
  // document already on disk and break `write(read(bytes)) == bytes`
  // (CR-117) for exactly the files a user cannot regenerate. Suppressing
  // the empty list is safe HERE and would not be on `dashOverride`,
  // because no media type means anything by "an alias list that is
  // deliberately empty": absent and `[]` are the same fact, no synonyms.
  // This is why `kSchemaVersion` does not move.
  putIfNotNull(json, 'shortTag', d.shortTag);
  if (d.aliases.isNotEmpty) json['aliases'] = d.aliases;
  putIfNotNull(json, 'maxRunLengthPassiveNm', d.maxRunLengthPassive?.nm);
  putIfNotNull(json, 'maxRunLengthActiveNm', d.maxRunLengthActive?.nm);
  return json;
}

MediaTypeDef _decodeMediaTypeDef(MediaTypeId id, JsonMap json) => MediaTypeDef(
  id: id,
  displayName: asStr(json['displayName'], 'MediaTypeDef.displayName'),
  shortTag: asStrOrNull(json['shortTag'], 'MediaTypeDef.shortTag'),
  aliases: [
    for (final v in asJsonList(
      json['aliases'] ?? const <Object?>[],
      'MediaTypeDef.aliases',
    ))
      asStr(v, 'MediaTypeDef.aliases[]'),
  ],
  maxRunLengthPassive: _decodeLenOrNull(
    json['maxRunLengthPassiveNm'],
    'MediaTypeDef.maxRunLengthPassiveNm',
  ),
  maxRunLengthActive: _decodeLenOrNull(
    json['maxRunLengthActiveNm'],
    'MediaTypeDef.maxRunLengthActiveNm',
  ),
  jacketOptions: [
    for (final v in asJsonList(
      json['jacketOptions'] ?? const <Object?>[],
      'MediaTypeDef.jacketOptions',
    ))
      decodeEnumStrict(
        JacketListing.values,
        asStr(v, 'MediaTypeDef.jacketOptions[]'),
        'MediaTypeDef.jacketOptions',
      ),
  ],
);

JsonMap _encodeCableSpecDef(CableSpecDef d) => {
  'id': d.id,
  'manufacturer': d.manufacturer,
  'partNumber': d.partNumber,
  'mediaTypeId': d.mediaTypeId.v,
};

CableSpecDef _decodeCableSpecDef(String id, JsonMap json) => CableSpecDef(
  id: id,
  manufacturer: asStr(json['manufacturer'], 'CableSpecDef.manufacturer'),
  partNumber: asStr(json['partNumber'], 'CableSpecDef.partNumber'),
  mediaTypeId: MediaTypeId(
    asStr(json['mediaTypeId'], 'CableSpecDef.mediaTypeId'),
  ),
);

JsonMap _encodeOutletDrop(OutletDrop d) => {
  'media': d.media.v,
  'service': d.service,
  'count': d.count,
  // OMITTED WHEN NULL, never written as an explicit null: unspecified is
  // an absent key (G4/CR-114), and a template that makes no claim about
  // how its cable terminates says nothing rather than saying "unknown"
  // out loud (DR-043 §11.42.1).
  if (d.termination != null) 'termination': encodeEnumName(d.termination!),
};

OutletDrop _decodeOutletDrop(JsonMap json) => OutletDrop(
  media: MediaTypeId(asStr(json['media'], 'OutletDrop.media')),
  service: asStr(json['service'], 'OutletDrop.service'),
  count: asInt(json['count'] ?? 1, 'OutletDrop.count'),
  termination: json['termination'] == null
      ? null
      : decodeEnumStrict(
          TerminationType.values,
          asStr(json['termination'], 'OutletDrop.termination'),
          'OutletDrop.termination',
        ),
);

JsonMap _encodeOutletTemplate(OutletTemplate t) {
  final json = <String, Object?>{
    'id': t.id,
    'name': t.name,
    'drops': [for (final d in t.drops) _encodeOutletDrop(d)],
  };
  // ADDITIVE, written only when present — `MediaTypeDef.shortTag`'s
  // contract and DR-022 §11.21.4's "not a migration" claim, which holds
  // only if the key stays absent on a template that has no tag.
  putIfNotNull(json, 'tag', t.tag);
  // Same contract, DR-024 §11.23.2. It matters more here than for `tag`,
  // because nine templates have SHIPPED since M3-C/4: a document written
  // in that window carries the three grade entries with no
  // `tia570Grade`, and CR-117 holds only because reading yields null and
  // writing omits the key. The six named templates never write it.
  putIfNotNull(json, 'tia570Grade', t.tia570Grade);
  // The same contract a third time (`#900`, DR-169 §11.168.4). The three
  // TIA grades never write it, because a grade is a cabling standard
  // rather than a service and has no domain to author.
  putIfNotNull(json, 'primaryDomain', t.primaryDomain?.v);
  return json;
}

OutletTemplate _decodeOutletTemplate(String id, JsonMap json) => OutletTemplate(
  id: id,
  name: asStr(json['name'], 'OutletTemplate.name'),
  tag: asStrOrNull(json['tag'], 'OutletTemplate.tag'),
  tia570Grade: asStrOrNull(json['tia570Grade'], 'OutletTemplate.tia570Grade'),
  primaryDomain: switch (asStrOrNull(
    json['primaryDomain'],
    'OutletTemplate.primaryDomain',
  )) {
    final String v => SignalDomainId(v),
    null => null,
  },
  drops: decodeObjectList(
    json['drops'],
    'OutletTemplate.drops',
    _decodeOutletDrop,
  ),
);

// Registries: the doc's worked example (§6.2) uses the outer keys
// "connectors"/"media" where the Dart `Registries` class fields are
// named `connectorTypes`/`mediaTypes`. Same relationship as the Len/Mass
// "Nm"/"Ug" suffix convention elsewhere in this codec — wire name and
// Dart field name are allowed to differ for a documented reason — so
// this codec follows the doc's evidenced wire names for these two, per
// this package's drift-resolution instructions.
JsonMap _encodeRegistries(Registries r) => {
  'signalDomains': {
    for (final e in r.signalDomains.entries)
      e.key.v: _encodeSignalDomainDef(e.value),
  },
  'signalFamilies': {
    for (final e in r.signalFamilies.entries)
      e.key.v: _encodeSignalFamilyDef(e.value),
  },
  'connectors': {
    for (final e in r.connectorTypes.entries)
      e.key.v: _encodeConnectorTypeDef(e.value),
  },
  'media': {
    for (final e in r.mediaTypes.entries) e.key.v: _encodeMediaTypeDef(e.value),
  },
  'cableSpecs': {
    for (final e in r.cableSpecs.entries) e.key: _encodeCableSpecDef(e.value),
  },
  'outletTemplates': {
    for (final e in r.outletTemplates.entries)
      e.key: _encodeOutletTemplate(e.value),
  },
};

Registries _decodeRegistries(JsonMap json) => Registries(
  signalDomains: {
    for (final e in asJsonMap(
      json['signalDomains'],
      'Registries.signalDomains',
    ).entries)
      SignalDomainId(e.key): _decodeSignalDomainDef(
        SignalDomainId(e.key),
        asJsonMap(e.value, 'Registries.signalDomains[${e.key}]'),
      ),
  },
  signalFamilies: {
    for (final e in asJsonMap(
      json['signalFamilies'],
      'Registries.signalFamilies',
    ).entries)
      SignalFamilyId(e.key): _decodeSignalFamilyDef(
        SignalFamilyId(e.key),
        asJsonMap(e.value, 'Registries.signalFamilies[${e.key}]'),
      ),
  },
  connectorTypes: {
    for (final e in asJsonMap(
      json['connectors'],
      'Registries.connectors',
    ).entries)
      ConnectorTypeId(e.key): _decodeConnectorTypeDef(
        ConnectorTypeId(e.key),
        asJsonMap(e.value, 'Registries.connectors[${e.key}]'),
      ),
  },
  mediaTypes: {
    for (final e in asJsonMap(json['media'], 'Registries.media').entries)
      MediaTypeId(e.key): _decodeMediaTypeDef(
        MediaTypeId(e.key),
        asJsonMap(e.value, 'Registries.media[${e.key}]'),
      ),
  },
  cableSpecs: {
    for (final e in asJsonMap(
      json['cableSpecs'],
      'Registries.cableSpecs',
    ).entries)
      e.key: _decodeCableSpecDef(
        e.key,
        asJsonMap(e.value, 'Registries.cableSpecs[${e.key}]'),
      ),
  },
  outletTemplates: {
    for (final e in asJsonMap(
      json['outletTemplates'],
      'Registries.outletTemplates',
    ).entries)
      e.key: _decodeOutletTemplate(
        e.key,
        asJsonMap(e.value, 'Registries.outletTemplates[${e.key}]'),
      ),
  },
);

// --- Templates: TemplateSnapshot / TemplateBody / PowerProfile / PortDef /
//     BankDef / PortSetDef / PassthroughPairDef / PanelGraphic /
//     PanelPosition / PoeSpec / SerialSpec / BusCapability /
//     PortPowerSpec ---------------------------------------------------

JsonMap _encodePanelPosition(PanelPosition p) => {
  'ruOffset': p.ruOffset,
  'xTwelfth': p.xTwelfth,
  'xFineNm': p.xFineNm.nm,
  'yFineNm': p.yFineNm.nm,
};

PanelPosition _decodePanelPosition(JsonMap json) => PanelPosition(
  ruOffset: asInt(json['ruOffset'], 'PanelPosition.ruOffset'),
  xTwelfth: asInt(json['xTwelfth'], 'PanelPosition.xTwelfth'),
  xFineNm: Len(asInt(json['xFineNm'], 'PanelPosition.xFineNm')),
  yFineNm: Len(asInt(json['yFineNm'], 'PanelPosition.yFineNm')),
);

JsonMap _encodePoeSpec(PoeSpec p) {
  final json = <String, Object?>{};
  if (p.role != null) json['role'] = encodeEnumName(p.role!);
  if (p.standard != null) json['standard'] = encodeEnumName(p.standard!);
  putIfNotNull(json, 'type', p.type);
  // Wire key "class": `PoeSpec.poeClass` is only renamed in Dart because
  // `class` is a reserved word there; the doc's worked example (§6.2)
  // uses "class" on the wire, which this codec follows — same rationale
  // as the Len/Mass unit-suffix renames elsewhere (Dart field name and
  // wire key are allowed to differ for a documented reason).
  putIfNotNull(json, 'class', p.poeClass);
  putIfNotNull(json, 'watts', p.watts);
  return json;
}

PoeSpec _decodePoeSpec(JsonMap json) => PoeSpec(
  role: json['role'] == null
      ? null
      : decodeEnumStrict(
          PoeRole.values,
          asStr(json['role'], 'PoeSpec.role'),
          'PoeSpec.role',
        ),
  standard: json['standard'] == null
      ? null
      : decodeEnumStrict(
          PoeStandard.values,
          asStr(json['standard'], 'PoeSpec.standard'),
          'PoeSpec.standard',
        ),
  type: asIntOrNull(json['type'], 'PoeSpec.type'),
  poeClass: asIntOrNull(json['class'], 'PoeSpec.class'),
  watts: asIntOrNull(json['watts'], 'PoeSpec.watts'),
);

JsonMap _encodeSerialSpec(SerialSpec s) {
  final json = <String, Object?>{};
  putIfNotNull(json, 'baud', s.baud);
  putIfNotNull(json, 'dataBits', s.dataBits);
  putIfNotNull(json, 'stopBits', s.stopBits);
  putIfNotNull(json, 'parity', s.parity);
  putIfNotNull(json, 'flowControl', s.flowControl);
  if (s.role != null) json['role'] = encodeEnumName(s.role!);
  return json;
}

SerialSpec _decodeSerialSpec(JsonMap json) => SerialSpec(
  baud: asIntOrNull(json['baud'], 'SerialSpec.baud'),
  dataBits: asIntOrNull(json['dataBits'], 'SerialSpec.dataBits'),
  stopBits: asIntOrNull(json['stopBits'], 'SerialSpec.stopBits'),
  parity: asStrOrNull(json['parity'], 'SerialSpec.parity'),
  flowControl: asStrOrNull(json['flowControl'], 'SerialSpec.flowControl'),
  role: json['role'] == null
      ? null
      : decodeEnumStrict(
          SerialRole.values,
          asStr(json['role'], 'SerialSpec.role'),
          'SerialSpec.role',
        ),
);

JsonMap _encodeBusCapability(BusCapability b) {
  final json = <String, Object?>{};
  putIfNotNull(json, 'protocol', b.protocol);
  putIfNotNull(json, 'supportsTermination', b.supportsTermination);
  putIfNotNull(json, 'unitLoads', b.unitLoads);
  putIfNotNull(json, 'addressable', b.addressable);
  putIfNotNull(json, 'maxTapWatts', b.maxTapWatts);
  return json;
}

BusCapability _decodeBusCapability(JsonMap json) => BusCapability(
  protocol: asStrOrNull(json['protocol'], 'BusCapability.protocol'),
  supportsTermination: asBoolOrNull(
    json['supportsTermination'],
    'BusCapability.supportsTermination',
  ),
  unitLoads: asIntOrNull(json['unitLoads'], 'BusCapability.unitLoads'),
  addressable: asBoolOrNull(json['addressable'], 'BusCapability.addressable'),
  maxTapWatts: asIntOrNull(json['maxTapWatts'], 'BusCapability.maxTapWatts'),
);

JsonMap _encodePortPowerSpec(PortPowerSpec p) {
  final json = <String, Object?>{};
  if (p.role != null) json['role'] = encodeEnumName(p.role!);
  putIfNotNull(json, 'volts', p.volts);
  putIfNotNull(json, 'drawWatts', p.drawWatts);
  putIfNotNull(json, 'maxAmps', p.maxAmps);
  return json;
}

PortPowerSpec _decodePortPowerSpec(JsonMap json) => PortPowerSpec(
  role: json['role'] == null
      ? null
      : decodeEnumStrict(
          PortPowerRole.values,
          asStr(json['role'], 'PortPowerSpec.role'),
          'PortPowerSpec.role',
        ),
  volts: asIntOrNull(json['volts'], 'PortPowerSpec.volts'),
  drawWatts: asIntOrNull(json['drawWatts'], 'PortPowerSpec.drawWatts'),
  maxAmps: asIntOrNull(json['maxAmps'], 'PortPowerSpec.maxAmps'),
);

JsonMap _encodePowerProfile(PowerProfile p) {
  final json = <String, Object?>{'isContinuousLoad': p.isContinuousLoad};
  // NO OUTLET COUNTS. DR-171 retired both keys; `migrateV5ToV6` and the
  // device-file steps strip them from older files.
  // A CAPACITY, not a draw — see `PowerProfile`'s class doc. Omitted when
  // unauthored like every other optional figure, so a document written
  // before these two existed round-trips byte-for-byte (CR-117).
  putIfNotNull(json, 'outputCapacityVA', p.outputCapacityVA);
  putIfNotNull(json, 'outputCapacityWatts', p.outputCapacityWatts);
  putIfNotNull(json, 'nameplateWatts', p.nameplateWatts);
  putIfNotNull(json, 'typicalWatts', p.typicalWatts);
  putIfNotNull(json, 'standbyWatts', p.standbyWatts);
  putIfNotNull(json, 'nominalVolts', p.nominalVolts);
  putIfNotNull(json, 'apparentVA', p.apparentVA);
  putIfNotNull(json, 'powerFactor', p.powerFactor);
  if (p.inletPlug != null) json['inletPlug'] = encodeEnumName(p.inletPlug!);
  putIfNotNull(json, 'poeBudgetWatts', p.poeBudgetWatts);
  putIfNotNull(json, 'btuPerHourOverride', p.btuPerHourOverride);
  return json;
}

PowerProfile _decodePowerProfile(JsonMap json) => PowerProfile(
  nameplateWatts: asIntOrNull(
    json['nameplateWatts'],
    'PowerProfile.nameplateWatts',
  ),
  typicalWatts: asIntOrNull(json['typicalWatts'], 'PowerProfile.typicalWatts'),
  standbyWatts: asIntOrNull(json['standbyWatts'], 'PowerProfile.standbyWatts'),
  nominalVolts: asIntOrNull(json['nominalVolts'], 'PowerProfile.nominalVolts'),
  apparentVA: asIntOrNull(json['apparentVA'], 'PowerProfile.apparentVA'),
  powerFactor: asIntOrNull(json['powerFactor'], 'PowerProfile.powerFactor'),
  isContinuousLoad: asBool(
    json['isContinuousLoad'],
    'PowerProfile.isContinuousLoad',
  ),
  outputCapacityVA: asIntOrNull(
    json['outputCapacityVA'],
    'PowerProfile.outputCapacityVA',
  ),
  outputCapacityWatts: asIntOrNull(
    json['outputCapacityWatts'],
    'PowerProfile.outputCapacityWatts',
  ),
  inletPlug: json['inletPlug'] == null
      ? null
      : decodeEnumStrict(
          PlugType.values,
          asStr(json['inletPlug'], 'PowerProfile.inletPlug'),
          'PowerProfile.inletPlug',
        ),
  poeBudgetWatts: asIntOrNull(
    json['poeBudgetWatts'],
    'PowerProfile.poeBudgetWatts',
  ),
  btuPerHourOverride: asIntOrNull(
    json['btuPerHourOverride'],
    'PowerProfile.btuPerHourOverride',
  ),
);

JsonMap _encodePortDef(PortDef p) {
  final json = <String, Object?>{
    'key': p.key.v,
    'renamedFrom': [for (final k in p.renamedFrom) k.v],
    'label': p.label,
    'connector': p.connector.v,
    'signalFamily': p.signalFamily.v,
    // `carriedProtocols` sat here until DR-134 §11.133.5 and was written
    // UNCONDITIONALLY, so `apartment.rmpj` carried 737 copies of `[]` for
    // a field nothing set. `acceptedFamilies` keeps that spelling on
    // purpose: DR-081 §11.80.5 rules that an empty list is the statement
    // "this port constrains nothing" rather than an unknown, so it is not
    // a `putIfNotNull` candidate the way a nullable scalar is.
    'acceptedFamilies': [for (final f in p.acceptedFamilies) f.v],
    'direction': encodeEnumName(p.direction),
    'topology': encodeEnumName(p.topology),
    'maxConnections': p.maxConnections,
    'gender': encodeEnumName(p.gender),
    'face': encodeEnumName(p.face),
    'order': p.order.v,
  };
  // OMITTED WHEN THE LAYOUT IS AUTOMATIC (DR-105 §11.104.3), which the
  // doc's own worked example (§6.2) has always shown by leaving
  // `position` off every port. It was written unconditionally while the
  // field was non-nullable and every value was `kUnplacedPanelPosition`,
  // so the file carried 727 copies of the origin per starter and said
  // nothing by it. An absent key is G4's shape for unknown (CR-114) and
  // is what the schema-3 migration produces from those zeros.
  if (p.position case final position?) {
    json['position'] = _encodePanelPosition(position);
  }
  putIfNotNull(json, 'designatorHint', p.designatorHint);
  // `returnChannel` is a plain 2-value enum on the Dart model, NOT the
  // object shape docs/02-data-model.md §6.2 shows — see the naming-drift
  // note already recorded on `ReturnChannel` in template.dart; the enum
  // reading is used here, per that same note.
  if (p.returnChannel != null) {
    json['returnChannel'] = encodeEnumName(p.returnChannel!);
  }
  putIfNotNull(json, 'pinoutVariant', p.pinoutVariant);
  putIfNotNull(json, 'conductorCount', p.conductorCount);
  putIfNotNull(json, 'impedanceOhms', p.impedanceOhms);
  if (p.level != null) json['level'] = encodeEnumName(p.level!);
  putIfNotNull(json, 'balanced', p.balanced);
  putIfNotNull(json, 'phantomPowerCapable', p.phantomPowerCapable);
  if (p.polarity != null) json['polarity'] = encodeEnumName(p.polarity!);
  putIfNotNull(json, 'nominalVoltage', p.nominalVoltage);
  putIfNotNull(json, 'maxCurrentMa', p.maxCurrentMa);
  putIfNotNull(json, 'bankKey', p.bankKey);
  putIfNotNull(json, 'setKey', p.setKey);
  putIfNotNull(json, 'setRole', p.setRole);
  putIfNotNull(json, 'channelIndex', p.channelIndex);
  if (p.poe != null) json['poe'] = _encodePoeSpec(p.poe!);
  putIfNotNull(json, 'linkSpeedMbps', p.linkSpeedMbps);
  if (p.sfp != null) json['sfp'] = encodeEnumName(p.sfp!);
  if (p.fiberMode != null) json['fiberMode'] = encodeEnumName(p.fiberMode!);
  // `wavelengthNm` is already `int?` on the Dart model (the "Nm" is baked
  // into the field's own name, unlike Len-typed fields elsewhere) —
  // passthrough, no `.nm` unwrap.
  putIfNotNull(json, 'wavelengthNm', p.wavelengthNm);
  if (p.bus != null) json['bus'] = _encodeBusCapability(p.bus!);
  if (p.serial != null) json['serial'] = _encodeSerialSpec(p.serial!);
  if (p.power != null) json['power'] = _encodePortPowerSpec(p.power!);
  putIfNotNull(json, 'notes', p.notes);
  return json;
}

PortDef _decodePortDef(JsonMap json) => PortDef(
  key: PortKey(asStr(json['key'], 'PortDef.key')),
  label: asStr(json['label'], 'PortDef.label'),
  connector: ConnectorTypeId(asStr(json['connector'], 'PortDef.connector')),
  signalFamily: SignalFamilyId(
    asStr(json['signalFamily'], 'PortDef.signalFamily'),
  ),
  face: decodeEnumStrict(
    Face.values,
    asStr(json['face'], 'PortDef.face'),
    'PortDef.face',
  ),
  // ABSENT MEANS AUTOMATIC. `asJsonMap` on a missing key throws, which
  // is right for a required field and wrong for this one since DR-105.
  position: json['position'] == null
      ? null
      : _decodePanelPosition(asJsonMap(json['position'], 'PortDef.position')),
  order: FracIndex(asStr(json['order'], 'PortDef.order')),
  renamedFrom: [
    for (final v in asJsonList(
      json['renamedFrom'] ?? const <Object?>[],
      'PortDef.renamedFrom',
    ))
      PortKey(asStr(v, 'PortDef.renamedFrom[]')),
  ],
  designatorHint: asStrOrNull(json['designatorHint'], 'PortDef.designatorHint'),
  // NO `carriedProtocols` READ, AND A SCHEMA-3 FILE STILL OPENS (DR-134
  // §11.133.5). `migrateV3ToV4` strips the key before this function sees
  // it, so there is nothing here to ignore; a file that somehow reaches
  // this reader with the key still on it loses an empty list, which is
  // the only value it has ever held in any file.
  acceptedFamilies: [
    for (final v in asJsonList(
      json['acceptedFamilies'] ?? const <Object?>[],
      'PortDef.acceptedFamilies',
    ))
      SignalFamilyId(asStr(v, 'PortDef.acceptedFamilies[]')),
  ],
  direction: decodeEnumStrict(
    PortDirection.values,
    asStr(json['direction'] ?? 'bidirectional', 'PortDef.direction'),
    'PortDef.direction',
  ),
  returnChannel: json['returnChannel'] == null
      ? null
      : decodeEnumStrict(
          ReturnChannel.values,
          asStr(json['returnChannel'], 'PortDef.returnChannel'),
          'PortDef.returnChannel',
        ),
  topology: decodeEnumStrict(
    PortTopology.values,
    asStr(json['topology'] ?? 'p2p', 'PortDef.topology'),
    'PortDef.topology',
  ),
  maxConnections: asInt(json['maxConnections'] ?? 1, 'PortDef.maxConnections'),
  gender: decodeEnumStrict(
    Gender.values,
    asStr(json['gender'] ?? 'genderless', 'PortDef.gender'),
    'PortDef.gender',
  ),
  pinoutVariant: asStrOrNull(json['pinoutVariant'], 'PortDef.pinoutVariant'),
  conductorCount: asIntOrNull(json['conductorCount'], 'PortDef.conductorCount'),
  impedanceOhms: asIntOrNull(json['impedanceOhms'], 'PortDef.impedanceOhms'),
  level: json['level'] == null
      ? null
      : decodeEnumStrict(
          AudioLevel.values,
          asStr(json['level'], 'PortDef.level'),
          'PortDef.level',
        ),
  balanced: asBoolOrNull(json['balanced'], 'PortDef.balanced'),
  phantomPowerCapable: asBoolOrNull(
    json['phantomPowerCapable'],
    'PortDef.phantomPowerCapable',
  ),
  polarity: json['polarity'] == null
      ? null
      : decodeEnumStrict(
          Polarity.values,
          asStr(json['polarity'], 'PortDef.polarity'),
          'PortDef.polarity',
        ),
  nominalVoltage: asIntOrNull(json['nominalVoltage'], 'PortDef.nominalVoltage'),
  maxCurrentMa: asIntOrNull(json['maxCurrentMa'], 'PortDef.maxCurrentMa'),
  bankKey: asStrOrNull(json['bankKey'], 'PortDef.bankKey'),
  setKey: asStrOrNull(json['setKey'], 'PortDef.setKey'),
  setRole: asStrOrNull(json['setRole'], 'PortDef.setRole'),
  channelIndex: asIntOrNull(json['channelIndex'], 'PortDef.channelIndex'),
  poe: decodeNullableObject(json, 'poe', 'PortDef.poe', _decodePoeSpec),
  linkSpeedMbps: asIntOrNull(json['linkSpeedMbps'], 'PortDef.linkSpeedMbps'),
  sfp: json['sfp'] == null
      ? null
      : decodeEnumStrict(
          SfpFormFactor.values,
          asStr(json['sfp'], 'PortDef.sfp'),
          'PortDef.sfp',
        ),
  fiberMode: json['fiberMode'] == null
      ? null
      : decodeEnumStrict(
          FiberMode.values,
          asStr(json['fiberMode'], 'PortDef.fiberMode'),
          'PortDef.fiberMode',
        ),
  wavelengthNm: asIntOrNull(json['wavelengthNm'], 'PortDef.wavelengthNm'),
  bus: decodeNullableObject(json, 'bus', 'PortDef.bus', _decodeBusCapability),
  serial: decodeNullableObject(
    json,
    'serial',
    'PortDef.serial',
    _decodeSerialSpec,
  ),
  power: decodeNullableObject(
    json,
    'power',
    'PortDef.power',
    _decodePortPowerSpec,
  ),
  notes: asStrOrNull(json['notes'], 'PortDef.notes'),
);

JsonMap _encodeBankDef(BankDef b) => {
  'key': b.key,
  'label': b.label,
  'abbr': b.abbr,
  'order': b.order.v,
  'symbolSide': encodeEnumName(b.symbolSide),
  'collapseInSymbol': b.collapseInSymbol,
};

BankDef _decodeBankDef(JsonMap json) => BankDef(
  key: asStr(json['key'], 'BankDef.key'),
  label: asStr(json['label'], 'BankDef.label'),
  abbr: asStr(json['abbr'], 'BankDef.abbr'),
  order: FracIndex(asStr(json['order'], 'BankDef.order')),
  symbolSide: decodeEnumStrict(
    SymbolSide.values,
    asStr(json['symbolSide'] ?? 'left', 'BankDef.symbolSide'),
    'BankDef.symbolSide',
  ),
  // Absent-key default tracks `BankDef`'s own (`true`, board 96-L). The
  // encoder always writes the key, so this only governs a hand-edited or
  // forward-version file — and for those, the specification's default is
  // the honest reading.
  collapseInSymbol: asBool(
    json['collapseInSymbol'] ?? true,
    'BankDef.collapseInSymbol',
  ),
);

JsonMap _encodePortSetDef(PortSetDef p) => {
  'key': p.key,
  'label': p.label,
  'kind': encodeEnumName(p.kind),
  'atomicConnect': p.atomicConnect,
};

PortSetDef _decodePortSetDef(JsonMap json) => PortSetDef(
  key: asStr(json['key'], 'PortSetDef.key'),
  label: asStr(json['label'], 'PortSetDef.label'),
  kind: decodeEnumStrict(
    SetKind.values,
    asStr(json['kind'], 'PortSetDef.kind'),
    'PortSetDef.kind',
  ),
  atomicConnect: asBool(
    json['atomicConnect'] ?? true,
    'PortSetDef.atomicConnect',
  ),
);

JsonMap _encodeSubmissionCredit(SubmissionCredit c) => {
  'handle': c.handle,
  'userId': c.userId,
};

SubmissionCredit _decodeSubmissionCredit(JsonMap json) => SubmissionCredit(
  handle: asStr(json['handle'], 'SubmissionCredit.handle'),
  userId: asInt(json['userId'], 'SubmissionCredit.userId'),
);

// TWO keys and no `contentHash`, matching docs/06 §7.3's worked `.rmdx`
// example exactly. The absent third field is AC-042's cut apparatus, not
// an oversight — see `TemplateOrigin`'s doc comment.
JsonMap _encodeTemplateOrigin(TemplateOrigin o) => {
  'templateId': o.templateId.v,
  'version': o.version,
};

TemplateOrigin _decodeTemplateOrigin(JsonMap json) => TemplateOrigin(
  templateId: TemplateId(
    asStr(json['templateId'], 'TemplateOrigin.templateId'),
  ),
  version: asInt(json['version'], 'TemplateOrigin.version'),
);

JsonMap _encodePassthroughPairDef(PassthroughPairDef p) => {
  'frontKey': p.frontKey.v,
  'rearKey': p.rearKey.v,
  'sameNet': p.sameNet,
};

PassthroughPairDef _decodePassthroughPairDef(JsonMap json) =>
    PassthroughPairDef(
      frontKey: PortKey(asStr(json['frontKey'], 'PassthroughPairDef.frontKey')),
      rearKey: PortKey(asStr(json['rearKey'], 'PassthroughPairDef.rearKey')),
      sameNet: asBool(json['sameNet'], 'PassthroughPairDef.sameNet'),
    );

JsonMap _encodePanelGraphic(PanelGraphic p) {
  final json = <String, Object?>{'id': p.id, 'kind': p.kind};
  putIfNotNull(json, 'geometryRef', p.geometryRef);
  return json;
}

PanelGraphic _decodePanelGraphic(JsonMap json) => PanelGraphic(
  id: asStr(json['id'], 'PanelGraphic.id'),
  kind: asStr(json['kind'], 'PanelGraphic.kind'),
  geometryRef: asStrOrNull(json['geometryRef'], 'PanelGraphic.geometryRef'),
);

/// A deep copy of [b], sharing no mutable structure with it.
///
/// The Device Builder edits a COPY and its stack is discarded on close
/// without save (CR-106, M4-A/4), which is only true if the body the
/// session mutates is not the one the library holds.
///
/// **Implemented by the codec round trip rather than a hand-written
/// clone, and that is the point.** `TemplateBody` has ~50 fields, eight
/// of them growable lists; a `copyWith`-style clone drifts the first time
/// somebody adds one, and a field the clone forgets is a list SHARED
/// between the copy and the original, so cancelling out of the builder
/// silently keeps the edit. Nothing would catch that. This pair is
/// already under CR-117's byte-exactness gate, so a field it fails to
/// carry is a field the FILE fails to carry, and that gate fails first
/// and loudly. The copy is exactly as faithful as saving and reloading,
/// which is the strongest guarantee available here.
TemplateBody copyTemplateBody(TemplateBody b) =>
    _decodeTemplateBody(_encodeTemplateBody(b));

/// [b] in the exact shape it takes on disk.
///
/// **A read-only view for callers that need to compare two bodies rather
/// than store one**, which today is `builder/template_change_class.dart`.
/// It exists for the same reason [copyTemplateBody] does: the encoder is
/// the only description of a `TemplateBody` that is under CR-117's gate,
/// so a field it fails to carry is a field the FILE fails to carry, and
/// anything built on it inherits that guarantee instead of drifting from
/// it. Comparing the Dart objects instead would need `==` on eight nested
/// types that deliberately do not define one.
///
/// The returned map is freshly built and safe to keep; it is NOT a live
/// view of [b].
JsonMap templateBodyToJson(TemplateBody b) => _encodeTemplateBody(b);

/// The inverse of [templateBodyToJson].
///
/// **Made public for the `.rmdx` codec (DR-100 §11.99), and it is the
/// half that was missing rather than a new capability.** The encoder has
/// been public since M4-C for `template_change_class.dart`; the decoder
/// had no caller until a FILE carried a body, because `.rmpj` reaches
/// this function through `_decodeTemplateSnapshot` and never needed a
/// door of its own.
///
/// **The pairing is the point.** DR-100 rules that a `.rmdx` carries the
/// body flat, exactly as this pair writes and reads it, so the `.rmdx`
/// codec acquires **no second description of a `TemplateBody`** and
/// inherits CR-117's gate instead of drifting from it. A field this pair
/// fails to carry is a field `.rmpj` fails to carry, and that gate fails
/// first and loudly.
TemplateBody templateBodyFromJson(JsonMap json) => _decodeTemplateBody(json);

JsonMap _encodeTemplateBody(TemplateBody b) {
  final json = <String, Object?>{
    'manufacturer': b.manufacturer,
    'model': b.model,
    'displayName': b.displayName,
    'description': b.description,
    'category': b.category,
    'tags': b.tags,
    'frontU': b.frontU,
    'rearU': b.rearU,
    'side': encodeEnumName(b.side),
    'mountMethod': encodeEnumName(b.mountMethod),
    'alternateMountMethods': [
      for (final m in b.alternateMountMethods) encodeEnumName(m),
    ],
    'widthClass': encodeEnumName(b.widthClass),
    'nominalSpanTwelfths': b.nominalSpanTwelfths,
    'chassisWidthNm': b.chassisWidth.nm,
    'requiresClearanceAboveU': b.requiresClearanceAboveU,
    'requiresClearanceBelowU': b.requiresClearanceBelowU,
    'thermalClass': encodeEnumName(b.thermalClass),
    'isContainer': b.isContainer,
    'containerVented': b.containerVented,
    'isPassthrough': b.isPassthrough,
    'passthroughPairs': [
      for (final p in b.passthroughPairs) _encodePassthroughPairDef(p),
    ],
    'power': _encodePowerProfile(b.power),
    'ports': [for (final p in b.ports) _encodePortDef(p)],
    'banks': [for (final bank in b.banks) _encodeBankDef(bank)],
    'portSets': [for (final s in b.portSets) _encodePortSetDef(s)],
    'panelGraphics': [for (final g in b.panelGraphics) _encodePanelGraphic(g)],
  };
  // ABSENT WHEN UNKNOWN, which is G4's spelling and what keeps every
  // document written before `#899` byte-identical (CR-117).
  putIfNotNull(json, 'primaryDomain', b.primaryDomain?.v);
  putIfNotNull(json, 'typePrefix', b.typePrefix);
  putIfNotNull(json, 'customPanelWidthNm', b.customPanelWidth?.nm);
  putIfNotNull(json, 'bodyDepthNm', b.bodyDepth?.nm);
  putIfNotNull(json, 'connectorProjectionNm', b.connectorProjection?.nm);
  putIfNotNull(json, 'weightUg', b.weight?.ug);
  putIfNotNull(json, 'maxUnsupportedMassUg', b.maxUnsupportedMass?.ug);
  putIfNotNull(
    json,
    'containerWeightCapacityUg',
    b.containerWeightCapacity?.ug,
  );
  putIfNotNull(json, 'containerUsableDepthNm', b.containerUsableDepth?.nm);
  putIfNotNull(json, 'containerUsableWidthNm', b.containerUsableWidth?.nm);
  if (b.accentColor != null) json['accentColor'] = _encodeRgb(b.accentColor!);
  // Absent means INHERIT THE CATEGORY'S DEFAULT, not unknown (DR-059).
  // Writing the resolved value instead would put a key on all 48 seeded
  // templates and regenerate four starters for nothing, and would lose
  // the author's *choice* the moment the category changed.
  if (b.glyph != null) json['glyph'] = encodeEnumName(b.glyph!);
  // Absent when never submitted, never an explicit null (G4, CR-114, DR-033).
  if (b.submittedBy != null) {
    json['submittedBy'] = _encodeSubmissionCredit(b.submittedBy!);
  }
  // Absent when the template is ORIGINAL, by the same rule (CR-062,
  // CR-114). An explicit null here would be an assertion that somebody
  // measured the provenance and found none, which is a different claim.
  if (b.derivedFrom != null) {
    json['derivedFrom'] = _encodeTemplateOrigin(b.derivedFrom!);
  }
  return json;
}

TemplateBody _decodeTemplateBody(JsonMap json) => TemplateBody(
  manufacturer: asStr(json['manufacturer'], 'TemplateBody.manufacturer'),
  model: asStr(json['model'], 'TemplateBody.model'),
  displayName: asStr(json['displayName'], 'TemplateBody.displayName'),
  description: asStr(json['description'] ?? '', 'TemplateBody.description'),
  category: asStr(json['category'] ?? '', 'TemplateBody.category'),
  primaryDomain: switch (asStrOrNull(
    json['primaryDomain'],
    'TemplateBody.primaryDomain',
  )) {
    final String v => SignalDomainId(v),
    null => null,
  },
  typePrefix: asStrOrNull(json['typePrefix'], 'TemplateBody.typePrefix'),
  tags: [
    for (final v in asJsonList(
      json['tags'] ?? const <Object?>[],
      'TemplateBody.tags',
    ))
      asStr(v, 'TemplateBody.tags[]'),
  ],
  frontU: asInt(json['frontU'] ?? 0, 'TemplateBody.frontU'),
  rearU: asInt(json['rearU'] ?? 0, 'TemplateBody.rearU'),
  side: decodeEnumStrict(
    OccupancySide.values,
    asStr(json['side'] ?? 'none', 'TemplateBody.side'),
    'TemplateBody.side',
  ),
  mountMethod: decodeEnumStrict(
    MountMethod.values,
    asStr(json['mountMethod'] ?? 'notInRack', 'TemplateBody.mountMethod'),
    'TemplateBody.mountMethod',
  ),
  alternateMountMethods: [
    for (final v in asJsonList(
      json['alternateMountMethods'] ?? const <Object?>[],
      'TemplateBody.alternateMountMethods',
    ))
      decodeEnumStrict(
        MountMethod.values,
        asStr(v, 'TemplateBody.alternateMountMethods[]'),
        'TemplateBody.alternateMountMethods',
      ),
  ],
  widthClass: decodeEnumStrict(
    WidthClass.values,
    asStr(json['widthClass'] ?? 'full', 'TemplateBody.widthClass'),
    'TemplateBody.widthClass',
  ),
  nominalSpanTwelfths: asInt(
    json['nominalSpanTwelfths'] ?? 12,
    'TemplateBody.nominalSpanTwelfths',
  ),
  customPanelWidth: _decodeLenOrNull(
    json['customPanelWidthNm'],
    'TemplateBody.customPanelWidthNm',
  ),
  bodyDepth: _decodeLenOrNull(json['bodyDepthNm'], 'TemplateBody.bodyDepthNm'),
  connectorProjection: _decodeLenOrNull(
    json['connectorProjectionNm'],
    'TemplateBody.connectorProjectionNm',
  ),
  chassisWidth: json['chassisWidthNm'] == null
      ? const Len(432_000_000)
      : _decodeLen(json['chassisWidthNm'], 'TemplateBody.chassisWidthNm'),
  weight: _decodeMassOrNull(json['weightUg'], 'TemplateBody.weightUg'),
  maxUnsupportedMass: _decodeMassOrNull(
    json['maxUnsupportedMassUg'],
    'TemplateBody.maxUnsupportedMassUg',
  ),
  requiresClearanceAboveU: asInt(
    json['requiresClearanceAboveU'] ?? 0,
    'TemplateBody.requiresClearanceAboveU',
  ),
  requiresClearanceBelowU: asInt(
    json['requiresClearanceBelowU'] ?? 0,
    'TemplateBody.requiresClearanceBelowU',
  ),
  thermalClass: decodeEnumStrict(
    ThermalClass.values,
    asStr(json['thermalClass'] ?? 'passive', 'TemplateBody.thermalClass'),
    'TemplateBody.thermalClass',
  ),
  isContainer: asBool(json['isContainer'] ?? false, 'TemplateBody.isContainer'),
  containerWeightCapacity: _decodeMassOrNull(
    json['containerWeightCapacityUg'],
    'TemplateBody.containerWeightCapacityUg',
  ),
  containerUsableDepth: _decodeLenOrNull(
    json['containerUsableDepthNm'],
    'TemplateBody.containerUsableDepthNm',
  ),
  containerUsableWidth: _decodeLenOrNull(
    json['containerUsableWidthNm'],
    'TemplateBody.containerUsableWidthNm',
  ),
  containerVented: asBool(
    json['containerVented'] ?? false,
    'TemplateBody.containerVented',
  ),
  isPassthrough: asBool(
    json['isPassthrough'] ?? false,
    'TemplateBody.isPassthrough',
  ),
  passthroughPairs: decodeObjectList(
    json['passthroughPairs'] ?? const <Object?>[],
    'TemplateBody.passthroughPairs',
    _decodePassthroughPairDef,
  ),
  power: json['power'] == null
      ? PowerProfile()
      : _decodePowerProfile(asJsonMap(json['power'], 'TemplateBody.power')),
  ports: decodeObjectList(
    json['ports'] ?? const <Object?>[],
    'TemplateBody.ports',
    _decodePortDef,
  ),
  banks: decodeObjectList(
    json['banks'] ?? const <Object?>[],
    'TemplateBody.banks',
    _decodeBankDef,
  ),
  portSets: decodeObjectList(
    json['portSets'] ?? const <Object?>[],
    'TemplateBody.portSets',
    _decodePortSetDef,
  ),
  accentColor: _decodeRgbOrNull(
    json['accentColor'],
    'TemplateBody.accentColor',
  ),
  panelGraphics: decodeObjectList(
    json['panelGraphics'] ?? const <Object?>[],
    'TemplateBody.panelGraphics',
    _decodePanelGraphic,
  ),
  submittedBy: json['submittedBy'] == null
      ? null
      : _decodeSubmissionCredit(
          asJsonMap(json['submittedBy'], 'TemplateBody.submittedBy'),
        ),
  derivedFrom: json['derivedFrom'] == null
      ? null
      : _decodeTemplateOrigin(
          asJsonMap(json['derivedFrom'], 'TemplateBody.derivedFrom'),
        ),
  glyph: json['glyph'] == null
      ? null
      : decodeEnumStrict(
          DeviceGlyph.values,
          asStr(json['glyph'], 'TemplateBody.glyph'),
          'TemplateBody.glyph',
        ),
);

JsonMap _encodeTemplateSnapshot(TemplateSnapshot t) => {
  'templateId': t.templateId.v,
  'version': t.version,
  'contentHash': t.contentHash,
  'capturedAt': encodeDateTime(t.capturedAt),
  'body': _encodeTemplateBody(t.body),
};

TemplateSnapshot _decodeTemplateSnapshot(JsonMap json) => TemplateSnapshot(
  templateId: TemplateId(
    asStr(json['templateId'], 'TemplateSnapshot.templateId'),
  ),
  version: asInt(json['version'], 'TemplateSnapshot.version'),
  contentHash: asStr(json['contentHash'], 'TemplateSnapshot.contentHash'),
  body: _decodeTemplateBody(asJsonMap(json['body'], 'TemplateSnapshot.body')),
  capturedAt: decodeDateTime(
    asStr(json['capturedAt'], 'TemplateSnapshot.capturedAt'),
  ),
);
