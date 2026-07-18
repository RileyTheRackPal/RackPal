// The concrete DocumentCodec (docs/02-data-model.md §6, CR-091/092/117):
// RackDocument <-> the plain, pretty-printed, key-sorted UTF-8 JSON
// `.rackmate` container. Hand-written both directions, no code
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

import 'package:rackmate_core/src/idformat/collision_policy.dart';
import 'package:rackmate_core/src/idformat/id_format.dart';
import 'package:rackmate_core/src/model/acked_finding.dart';
import 'package:rackmate_core/src/model/circuit.dart';
import 'package:rackmate_core/src/model/conductor.dart';
import 'package:rackmate_core/src/model/device_instance.dart';
import 'package:rackmate_core/src/model/entity_meta.dart';
import 'package:rackmate_core/src/model/enums.dart';
import 'package:rackmate_core/src/model/link.dart';
import 'package:rackmate_core/src/model/location.dart';
import 'package:rackmate_core/src/model/net.dart';
import 'package:rackmate_core/src/model/note.dart';
import 'package:rackmate_core/src/model/outlet.dart';
import 'package:rackmate_core/src/model/pathway.dart';
import 'package:rackmate_core/src/model/placement.dart';
import 'package:rackmate_core/src/model/port.dart';
import 'package:rackmate_core/src/model/project_info.dart';
import 'package:rackmate_core/src/model/project_settings.dart';
import 'package:rackmate_core/src/model/rack.dart';
import 'package:rackmate_core/src/model/rack_document.dart';
import 'package:rackmate_core/src/model/registries.dart';
import 'package:rackmate_core/src/model/rule_override.dart';
import 'package:rackmate_core/src/model/service.dart';
import 'package:rackmate_core/src/model/sheet.dart';
import 'package:rackmate_core/src/model/sheet_item.dart';
import 'package:rackmate_core/src/model/structure_body.dart';
import 'package:rackmate_core/src/model/template.dart';
import 'package:rackmate_core/src/model/tombstone.dart';
import 'package:rackmate_core/src/model/zero_u_channel.dart';
import 'package:rackmate_core/src/persistence/codec.dart';
import 'package:rackmate_core/src/persistence/enum_wire.dart';
import 'package:rackmate_core/src/persistence/json_util.dart';
import 'package:rackmate_core/src/persistence/migrations.dart';
import 'package:rackmate_core/src/persistence/schema.dart';
import 'package:rackmate_core/src/units/ids.dart';
import 'package:rackmate_core/src/units/len.dart';
import 'package:rackmate_core/src/units/mass.dart';
import 'package:rackmate_core/src/units/permille.dart';
import 'package:rackmate_core/src/units/pt.dart';
import 'package:rackmate_core/src/units/rgb.dart';
import 'package:rackmate_core/src/util/outcome.dart';

/// The M0 `DocumentCodec` implementation — plain JSON, hand-written both
/// directions.
final class JsonDocumentCodec extends DocumentCodec {
  const JsonDocumentCodec();

  @override
  Uint8List write(RackDocument document) => Uint8List.fromList(
    encodeCanonicalJsonBytes(_encodeRackDocument(document)),
  );

  @override
  Outcome<RackDocument> read(Uint8List bytes) {
    if (looksLikeZip(bytes)) {
      return const Err(UnsupportedZipContainerError());
    }
    try {
      final parsed = jsonDecode(utf8.decode(bytes));
      final root = asJsonMap(parsed, 'root');
      final migrated = migrateToCurrent(root);
      switch (migrated) {
        case Err(:final error):
          return Err(error);
        case Ok(value: final migratedDoc, :final openReadOnly):
          return Ok(
            _decodeRackDocument(migratedDoc.raw),
            openReadOnly: openReadOnly,
          );
      }
    } on Exception catch (e) {
      return Err(e);
    }
  }
}

// --- Small wrapper-type helpers (Uuid/Len/Mass/Rgb/IdFormat) --------------
//
// Thin, repeated everywhere below: unwrap the extension type to its plain
// wire value, or wrap a decoded plain value back into it.

Uuid _decodeUuid(Object? value, String context) => Uuid(asStr(value, context));

Uuid? _decodeUuidOrNull(Object? value, String context) =>
    value == null ? null : Uuid(asStr(value, context));

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

IdFormat _decodeIdFormat(String raw) => IdFormat(raw);

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
    kKeyMinReaderVersion: doc.minReaderVersion,
    kKeyModifiedAt: encodeDateTime(doc.modifiedAt),
    kKeySchemaVersion: doc.schemaVersion,
    kKeySequence: doc.sequence,
    kKeyUnknown: doc.unknown,
  };
}

RackDocument _decodeRackDocument(JsonMap root) {
  final document = asJsonMap(root[kKeyDocument], 'document');

  Map<Uuid, T> decodeUuidKeyedMap<T>(
    String key,
    T Function(Uuid id, JsonMap json) decode,
  ) {
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
  ),
  portDesignatorFormat: _decodeIdFormat(
    asStr(json['portDesignatorFormat'], 'ProjectSettings.portDesignatorFormat'),
  ),
  linkDesignatorFormat: _decodeIdFormat(
    asStr(json['linkDesignatorFormat'], 'ProjectSettings.linkDesignatorFormat'),
  ),
  netNameFormat: _decodeIdFormat(
    asStr(json['netNameFormat'], 'ProjectSettings.netNameFormat'),
  ),
  outletFieldLabelFormat: _decodeIdFormat(
    asStr(
      json['outletFieldLabelFormat'],
      'ProjectSettings.outletFieldLabelFormat',
    ),
  ),
  outletRackLabelFormat: _decodeIdFormat(
    asStr(
      json['outletRackLabelFormat'],
      'ProjectSettings.outletRackLabelFormat',
    ),
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

JsonMap _encodeDeviceOverrides(DeviceOverrides o) {
  final json = <String, Object?>{};
  putIfNotNull(json, 'displayName', o.displayName);
  putIfNotNull(json, 'typePrefix', o.typePrefix);
  putIfNotNull(json, 'typicalWatts', o.typicalWatts);
  putIfNotNull(json, 'weightUg', o.weight?.ug);
  putIfNotNull(json, 'bodyDepthNm', o.bodyDepth?.nm);
  if (o.accentColor != null) json['accentColor'] = _encodeRgb(o.accentColor!);
  return json;
}

DeviceOverrides _decodeDeviceOverrides(JsonMap json) => DeviceOverrides(
  displayName: asStrOrNull(json['displayName'], 'DeviceOverrides.displayName'),
  typePrefix: asStrOrNull(json['typePrefix'], 'DeviceOverrides.typePrefix'),
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
);

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
    },
  ZeroUPlacement(
    :final rackId,
    :final channelId,
    :final offsetFromChannelStart,
    :final orientation,
    :final locked,
  ) =>
    {
      'type': 'zeroU',
      'rackId': rackId.v,
      'channelId': channelId,
      'offsetFromChannelStartNm': offsetFromChannelStart.nm,
      'orientation': encodeEnumName(orientation),
      'locked': locked,
    },
  OffRackPlacement(:final locationId, :final mountNote) => {
    'type': 'offRack',
    if (locationId != null) 'locationId': locationId.v,
    if (mountNote != null) 'mountNote': mountNote,
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
    },
};

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
      );
    case 'zeroU':
      return ZeroUPlacement(
        rackId: _decodeUuid(json['rackId'], 'ZeroUPlacement.rackId'),
        channelId: asStr(json['channelId'], 'ZeroUPlacement.channelId'),
        offsetFromChannelStart: _decodeLen(
          json['offsetFromChannelStartNm'],
          'ZeroUPlacement.offsetFromChannelStartNm',
        ),
        orientation: decodeEnumStrict(
          ZeroUOrientation.values,
          asStr(json['orientation'], 'ZeroUPlacement.orientation'),
          'ZeroUPlacement.orientation',
        ),
        locked: asBool(json['locked'], 'ZeroUPlacement.locked'),
      );
    case 'offRack':
      return OffRackPlacement(
        locationId: _decodeUuidOrNull(
          json['locationId'],
          'OffRackPlacement.locationId',
        ),
        mountNote: asStrOrNull(json['mountNote'], 'OffRackPlacement.mountNote'),
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
  putIfNotNull(json, 'label', o.label);
  putIfNotNull(json, 'connector', o.connector?.v);
  putIfNotNull(json, 'signalFamily', o.signalFamily?.v);
  return json;
}

PortOverrides _decodePortOverrides(JsonMap json) => PortOverrides(
  label: asStrOrNull(json['label'], 'PortOverrides.label'),
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
    'outletId': o.outletId.v,
    'fieldLabel': o.fieldLabel,
    'terminationField': encodeEnumName(o.terminationField),
  };
  putIfNotNull(json, 'rackLabel', o.rackLabel);
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
  outletId: _decodeUuid(json['outletId'], 'StructureOrigin.outletId'),
  fieldLabel: asStr(json['fieldLabel'], 'StructureOrigin.fieldLabel'),
  terminationField: decodeEnumStrict(
    TerminationType.values,
    asStr(json['terminationField'], 'StructureOrigin.terminationField'),
    'StructureOrigin.terminationField',
  ),
  rackLabel: asStrOrNull(json['rackLabel'], 'StructureOrigin.rackLabel'),
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
    'plenum': l.plenum,
    'lifecycleStatus': encodeLifecycleStatus(l.lifecycleStatus),
    'roughInStatus': encodeEnumName(l.roughInStatus),
  };
  putIfNotNull(json, 'notes', l.notes);
  putIfNotNull(json, 'cableSpecId', l.cableSpecId);
  putIfNotNull(json, 'gaugeAwg', l.gaugeAwg);
  if (l.jacket != null) json['jacket'] = encodeEnumName(l.jacket!);
  putIfNotNull(json, 'routedLengthNm', l.routedLength?.nm);
  putIfNotNull(json, 'cutLengthNm', l.cutLength?.nm);
  putIfNotNull(json, 'terminatedLengthNm', l.terminatedLength?.nm);
  putIfNotNull(json, 'slack', l.slack?.v);
  putIfNotNull(json, 'pathwayId', l.pathwayId?.v);
  if (l.crossover != null) json['crossover'] = encodeEnumName(l.crossover!);
  if (l.test != null) json['test'] = _encodeTestResult(l.test!);
  putIfNotNull(json, 'installedBy', l.installedBy);
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
          JacketRating.values,
          asStr(json['jacket'], 'Link.jacket'),
          'Link.jacket',
        ),
  shielded: asBool(json['shielded'], 'Link.shielded'),
  plenum: asBool(json['plenum'], 'Link.plenum'),
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
  return json;
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
// materially different field sets (shortTag/topologyFree/
// maxChannelLengthNm, contacts/genderApplies/matesWith,
// conductorCount/isPathwayOnly/pairCount) that do not correspond to any
// field these Dart classes actually declare. This codec serializes the
// real Dart fields (id/displayName/domain/defaultConnector/
// defaultDirection/defaultTopology/aliases, etc.), per this package's
// drift-resolution instructions.
JsonMap _encodeSignalFamilyDef(SignalFamilyDef d) => {
  'id': d.id.v,
  'displayName': d.displayName,
  'domain': d.domain.v,
  'defaultConnector': d.defaultConnector.v,
  'defaultDirection': encodeEnumName(d.defaultDirection),
  'defaultTopology': encodeEnumName(d.defaultTopology),
  'aliases': d.aliases,
};

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
    );

JsonMap _encodeConnectorTypeDef(ConnectorTypeDef d) => {
  'id': d.id.v,
  'displayName': d.displayName,
  'aliases': d.aliases,
};

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
    );

JsonMap _encodeMediaTypeDef(MediaTypeDef d) {
  final json = <String, Object?>{
    'id': d.id.v,
    'displayName': d.displayName,
    'jacketOptions': [for (final j in d.jacketOptions) encodeEnumName(j)],
  };
  putIfNotNull(json, 'maxRunLengthPassiveNm', d.maxRunLengthPassive?.nm);
  putIfNotNull(json, 'maxRunLengthActiveNm', d.maxRunLengthActive?.nm);
  return json;
}

MediaTypeDef _decodeMediaTypeDef(MediaTypeId id, JsonMap json) => MediaTypeDef(
  id: id,
  displayName: asStr(json['displayName'], 'MediaTypeDef.displayName'),
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
        JacketRating.values,
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
};

OutletDrop _decodeOutletDrop(JsonMap json) => OutletDrop(
  media: MediaTypeId(asStr(json['media'], 'OutletDrop.media')),
  service: asStr(json['service'], 'OutletDrop.service'),
  count: asInt(json['count'] ?? 1, 'OutletDrop.count'),
);

JsonMap _encodeOutletTemplate(OutletTemplate t) => {
  'id': t.id,
  'name': t.name,
  'drops': [for (final d in t.drops) _encodeOutletDrop(d)],
};

OutletTemplate _decodeOutletTemplate(String id, JsonMap json) => OutletTemplate(
  id: id,
  name: asStr(json['name'], 'OutletTemplate.name'),
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
  final json = <String, Object?>{
    'isContinuousLoad': p.isContinuousLoad,
    'outletsProvided': p.outletsProvided,
    'outletsConsumed': p.outletsConsumed,
  };
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
  outletsProvided: asInt(
    json['outletsProvided'],
    'PowerProfile.outletsProvided',
  ),
  outletsConsumed: asInt(
    json['outletsConsumed'],
    'PowerProfile.outletsConsumed',
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
    'carriedProtocols': [for (final f in p.carriedProtocols) f.v],
    'acceptedFamilies': [for (final f in p.acceptedFamilies) f.v],
    'direction': encodeEnumName(p.direction),
    'topology': encodeEnumName(p.topology),
    'maxConnections': p.maxConnections,
    'gender': encodeEnumName(p.gender),
    'face': encodeEnumName(p.face),
    // Required per the Dart model even though the doc's worked example
    // (§6.2) omits "position" from every port shown — see the
    // PanelPosition doc comment in template.dart for why this type is a
    // judgement call to begin with. Always emitted, never omittable.
    'position': _encodePanelPosition(p.position),
    'order': p.order.v,
  };
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
  position: _decodePanelPosition(
    asJsonMap(json['position'], 'PortDef.position'),
  ),
  order: FracIndex(asStr(json['order'], 'PortDef.order')),
  renamedFrom: [
    for (final v in asJsonList(
      json['renamedFrom'] ?? const <Object?>[],
      'PortDef.renamedFrom',
    ))
      PortKey(asStr(v, 'PortDef.renamedFrom[]')),
  ],
  designatorHint: asStrOrNull(json['designatorHint'], 'PortDef.designatorHint'),
  carriedProtocols: [
    for (final v in asJsonList(
      json['carriedProtocols'] ?? const <Object?>[],
      'PortDef.carriedProtocols',
    ))
      SignalFamilyId(asStr(v, 'PortDef.carriedProtocols[]')),
  ],
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
  collapseInSymbol: asBool(
    json['collapseInSymbol'] ?? false,
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
  return json;
}

TemplateBody _decodeTemplateBody(JsonMap json) => TemplateBody(
  manufacturer: asStr(json['manufacturer'], 'TemplateBody.manufacturer'),
  model: asStr(json['model'], 'TemplateBody.model'),
  displayName: asStr(json['displayName'], 'TemplateBody.displayName'),
  description: asStr(json['description'] ?? '', 'TemplateBody.description'),
  category: asStr(json['category'] ?? '', 'TemplateBody.category'),
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
