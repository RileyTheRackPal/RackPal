// Your own rack presets, and the seeded ones you have hidden (#561, DR-016,
// DR-176 §11.175).
//
// ═════════════════════════════════════════════════════════════════════
// SEEDED PRESETS ARE NEVER EDITED, ONLY HIDDEN
// ═════════════════════════════════════════════════════════════════════
// `buildRackPresets()` ships the eleven archetypes docs/04 §4 names, and
// `rack_presets_test.dart` pins them. §11.175.4 keeps them as shipped: a
// user may hide the ones they never stock, and that is a set of ids, not an
// override of any value. So this file adds presets and removes ids from a
// merged view; it never writes a seeded preset's height, depth or capacity.
//
// ═════════════════════════════════════════════════════════════════════
// THE FILE IS A CONVENIENCE, SO READING IT NEVER THROWS
// ═════════════════════════════════════════════════════════════════════
// `rack_presets.json` sits beside `prefs.json` under the data root
// (§11.175.3), and it follows `prefs.json`'s rule: a file that cannot be
// read must never stop the app starting. A root that is not a map reads as
// empty. One preset that cannot be read is SKIPPED, not fatal to the rest:
// a user with twenty presets should not lose nineteen because one was
// hand-edited. A height outside CR-038's 1..60 is not a rack anybody saved,
// so that preset is skipped rather than clamped, the same call
// `prefs.json` makes for an undo depth out of range.
//
// ═════════════════════════════════════════════════════════════════════
// THE SAME FIELD NAMES AND UNITS AS A RACK IN A PROJECT FILE
// ═════════════════════════════════════════════════════════════════════
// `heightU`, `formFactor`, `widthClass`, `railType`, `isSwingFrame` and
// `hingeSide` are spelled as `json_codec.dart` spells them on a `Rack`, and
// lengths and masses are whole nanometres and micrograms under the
// `usableDepthNm` / `weightCapacityUg` names (CR-001, CR-003). An unknown
// is an ABSENT key, never an explicit null (G4).
import 'package:rackpal_core/src/catalog/rack_presets.dart';
import 'package:rackpal_core/src/model/rack.dart';
import 'package:rackpal_core/src/persistence/enum_wire.dart';
import 'package:rackpal_core/src/persistence/json_util.dart';
import 'package:rackpal_core/src/units/len.dart';
import 'package:rackpal_core/src/units/mass.dart';

/// The on-disk schema version for `rack_presets.json`.
const int kUserRackPresetsFormatVersion = 1;

/// The tallest rack a preset may describe (CR-038).
const int kMaxPresetHeightU = 60;

/// What `rack_presets.json` holds: your presets, in the order you saved
/// them, and the seeded preset ids you have hidden.
final class UserRackPresets {
  const UserRackPresets({
    this.presets = const <RackPreset>[],
    this.hiddenSeedIds = const <String>{},
  });

  /// Yours, in saved order. Their ids never collide with a seeded id; see
  /// [kUserPresetIdPrefix].
  final List<RackPreset> presets;

  /// Seeded preset ids removed from every dropdown. An id no seeded preset
  /// carries is KEPT, not dropped: it belongs to a build with a different
  /// seed list, and a user who runs both should not have the older one
  /// forget the choice.
  final Set<String> hiddenSeedIds;
}

/// Every id of yours starts with this, so it can never equal a seeded id
/// and a merged map never loses one to the other.
const String kUserPresetIdPrefix = 'user:';

/// `rack_presets.json`'s root for [value].
///
/// `version`, spelled as `prefs.json` spells it, since the two files sit side
/// by side under the data root.
JsonMap userRackPresetsToJson(UserRackPresets value) => <String, Object?>{
  'version': kUserRackPresetsFormatVersion,
  'hiddenSeedIds': value.hiddenSeedIds.toList()..sort(),
  'presets': [for (final p in value.presets) _presetToJson(p)],
};

JsonMap _presetToJson(RackPreset p) {
  final json = <String, Object?>{
    'id': p.id,
    'displayName': p.displayName,
    'heightU': p.heightU,
    'formFactor': encodeEnumName(p.formFactor),
    'widthClass': encodeEnumName(p.widthClass),
    'railType': encodeEnumName(p.railType),
    'isSwingFrame': p.isSwingFrame,
  };
  putIfNotNull(json, 'usableDepthNm', p.usableDepth?.nm);
  putIfNotNull(json, 'weightCapacityUg', p.weightCapacity?.ug);
  if (p.hingeSide != null) json['hingeSide'] = encodeEnumName(p.hingeSide!);
  return json;
}

/// Reads `rack_presets.json`'s decoded root. Never throws; see the file
/// header for what is skipped and why.
UserRackPresets userRackPresetsFromJson(Object? raw) {
  if (raw is! Map) return const UserRackPresets();
  final hidden = <String>{
    if (raw['hiddenSeedIds'] case final List<Object?> ids)
      for (final id in ids)
        if (id is String && id.isNotEmpty) id,
  };
  final presets = <RackPreset>[];
  final seen = <String>{};
  if (raw['presets'] case final List<Object?> entries) {
    for (final entry in entries) {
      final preset = _presetFromJson(entry);
      if (preset == null || !seen.add(preset.id)) continue;
      presets.add(preset);
    }
  }
  return UserRackPresets(presets: presets, hiddenSeedIds: hidden);
}

RackPreset? _presetFromJson(Object? raw) {
  if (raw is! Map<String, Object?>) return null;
  try {
    final id = asStr(raw['id'], 'RackPreset.id');
    final name = asStr(raw['displayName'], 'RackPreset.displayName').trim();
    final height = asInt(raw['heightU'], 'RackPreset.heightU');
    if (!id.startsWith(kUserPresetIdPrefix) || name.isEmpty) return null;
    if (height < 1 || height > kMaxPresetHeightU) return null;
    final swing = raw['isSwingFrame'] == true;
    return RackPreset(
      id: id,
      displayName: name,
      heightU: height,
      formFactor: decodeEnumStrict(
        RackFormFactor.values,
        asStr(raw['formFactor'], 'RackPreset.formFactor'),
        'RackPreset.formFactor',
      ),
      widthClass: decodeEnumStrict(
        RackWidthClass.values,
        asStr(raw['widthClass'], 'RackPreset.widthClass'),
        'RackPreset.widthClass',
      ),
      railType: decodeEnumStrict(
        RailType.values,
        asStr(raw['railType'], 'RackPreset.railType'),
        'RackPreset.railType',
      ),
      usableDepth: switch (raw['usableDepthNm']) {
        final int nm when nm > 0 => Len(nm),
        _ => null,
      },
      weightCapacity: switch (raw['weightCapacityUg']) {
        final int ug when ug > 0 => Mass(ug),
        _ => null,
      },
      isSwingFrame: swing,
      hingeSide: swing && raw['hingeSide'] is String
          ? decodeEnumStrict(
              HingeSide.values,
              raw['hingeSide']! as String,
              'RackPreset.hingeSide',
            )
          : null,
    );
    // One unreadable preset is skipped, not fatal to the file.
  } on FormatException {
    return null;
  }
}

/// The presets every dropdown lists: seeded ones not hidden, in seed order,
/// then yours, in saved order.
///
/// SEEDED FIRST, and that is also the tie-break `matchingPresetId` inherits:
/// a rack whose values equal both a seeded preset and one of yours still
/// reads as its archetype.
Map<String, RackPreset> mergeRackPresets(
  Map<String, RackPreset> seed,
  UserRackPresets user,
) => <String, RackPreset>{
  for (final entry in seed.entries)
    if (!user.hiddenSeedIds.contains(entry.key)) entry.key: entry.value,
  for (final p in user.presets) p.id: p,
};
