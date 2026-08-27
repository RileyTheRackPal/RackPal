// The change class a template edit falls into: safe, additive or
// breaking, computed from the diff and shown prominently before save
// (CR-050, docs/06 §7.2). Board #197, M4-C/2.
//
// IT IS NOT ENCODED IN THE VERSION INTEGER, and CR-050 is explicit about
// why: a semver whose components are computed adds a vocabulary without
// adding a capability, and `TemplateRef` cannot hold one. `version` stays
// a monotonic int. This is a LABEL on a save, not a number in a file, and
// nothing here writes anything.
//
// ─────────────────────────────────────────────────────────────────────
// WHAT THE THREE CLASSES MEAN, because docs/06 §7.2 gives EXAMPLES and
// not a specification, and the examples cover roughly a third of the
// fields a `TemplateBody` actually has.
// ─────────────────────────────────────────────────────────────────────
// The question every class answers is about a device somebody has ALREADY
// PLACED in a project that has ALREADY BEEN DRAWN:
//
//   safe      Nothing about that device's placement or its connections
//             changes meaning. Numbers on a schedule may move; a rollup
//             may print differently. Nothing has to be looked at.
//   additive  Something NEW appeared. Nothing that existed is invalidated,
//             and no migration can lose anything.
//   breaking  An existing connection may orphan, the device's occupancy
//             or tiling changes, OR installed work becomes WRONG.
//
// The third clause of `breaking` is not an invention: the doc's own list
// puts "connector or family retyped incompatibly" there, and a connector
// retype orphans nothing. It makes the cable already in the wall the wrong
// cable. That is the same failure `pinoutVariant` and `polarity` produce,
// so they are classed with it (AC-052 flags `pinoutVariant` as the IR
// emitter/receiver hazard by name, and AC-030 put `polarity` on the
// terminal precisely so a typo would be inexpressible).
//
// WHY `depth` AND `weight` ARE SAFE THOUGH `frontU` IS BREAKING, since it
// reads like an inconsistency in the doc and is not one. `frontU` changes
// how many U the device occupies, so every device below it in the rack is
// now in the wrong place. `depth` changes a number a DRC rule reads: the
// layout is untouched, and M5 raises a finding if the device no longer
// fits. A finding is not a migration. The same reading puts the clearance
// requirements and `chassisWidth` on the safe side and `widthClass` /
// `nominalSpanTwelfths` on the breaking side, because those two decide how
// the device TILES within a U.
//
// WHERE A CLASS IS GENUINELY ARGUABLE, the tiebreak is: take the class of
// the doc's nearest NAMED example. That is why `channelIndex` is safe (its
// neighbours are "port label changes" and "port reordering") and `setKey`
// is breaking (CR-055 makes port sets ELECTRICAL, and no safe example is
// near it).
//
// "RETYPED INCOMPATIBLY" IS COMPUTED AS "RETYPED", and that is a known
// over-warn. The compatibility matrix is M5's ("the compat matrix as a
// lookup table", roadmap §M5), so today there is nothing to ask whether
// `conn.hdmi_a` -> `conn.hdmi_a_locking` is compatible. Over-warning on an
// advisory label is recoverable; under-warning is what ships a breaking
// change labelled safe. When M5's matrix lands, `connector` and
// `signalFamily` consult it here and this paragraph goes away.
import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'package:rackpal_core/src/model/template.dart';
import 'package:rackpal_core/src/persistence/json_codec.dart'
    show templateBodyToJson;
import 'package:rackpal_core/src/persistence/json_util.dart' show JsonMap;

const _deepEquals = DeepCollectionEquality();

/// How consequential a template edit is (docs/06 §7.2). Declared in
/// increasing severity, which [TemplateChangeReport.changeClass] relies on
/// via `index`.
enum TemplateChangeClass { safe, additive, breaking }

/// What happened to a field or an element. Separate from the class so the
/// UI can say *"port `hdmi-in-01` was deleted"* rather than only *"this is
/// breaking"*: a verdict with no reasons under it is a verdict nobody can
/// act on.
enum TemplateChangeKind {
  /// A value became a different value.
  changed,

  /// A previously ABSENT optional fact was filled in. Always
  /// [TemplateChangeClass.additive] regardless of the field's declared
  /// class, per docs/06 §7.2's "new column data on existing ports".
  filledIn,

  /// A known fact became unknown. Classed as the field declares, because
  /// clearing a port's `connector` is exactly as wrong as retyping it.
  cleared,

  /// A port, bank, port set, passthrough pair or panel graphic appeared.
  elementAdded,

  /// One of the same disappeared.
  elementRemoved,
}

/// One reason inside a [TemplateChangeReport].
@immutable
final class TemplateChange {
  const TemplateChange({
    required this.changeClass,
    required this.kind,
    required this.path,
  });

  final TemplateChangeClass changeClass;
  final TemplateChangeKind kind;

  /// `frontU`, `power.typicalWatts`, `ports[hdmi-in-01].connector`. Unique
  /// within a report, which is what makes the report's order TOTAL when
  /// sorted by it (`List.sort` is not stable).
  final String path;

  @override
  bool operator ==(Object other) =>
      other is TemplateChange &&
      other.changeClass == changeClass &&
      other.kind == kind &&
      other.path == path;

  @override
  int get hashCode => Object.hash(changeClass, kind, path);

  @override
  String toString() => '${changeClass.name} ${kind.name} $path';
}

/// The verdict plus every reason behind it.
@immutable
final class TemplateChangeReport {
  const TemplateChangeReport(this.changes);

  /// Sorted by [TemplateChange.path], so the same pair of bodies always
  /// produces the same list.
  final List<TemplateChange> changes;

  /// True when the two bodies are identical. Kept OFF
  /// [TemplateChangeClass] deliberately: CR-050 names three classes and a
  /// fourth enum value would be a fourth word in the product's vocabulary
  /// for a state the user reaches by editing nothing.
  bool get isUnchanged => changes.isEmpty;

  /// The most severe class present; [TemplateChangeClass.safe] when there
  /// is nothing at all, which is the identity rather than a claim.
  TemplateChangeClass get changeClass => changes.fold(
    TemplateChangeClass.safe,
    (worst, c) => c.changeClass.index > worst.index ? c.changeClass : worst,
  );

  /// Every reason at the verdict's own class, for a UI that wants to lead
  /// with what made it breaking rather than with the first thing that
  /// happens to sort alphabetically.
  List<TemplateChange> get decidingChanges =>
      changes.where((c) => c.changeClass == changeClass).toList();
}

/// What a change to one wire key costs.
@immutable
final class _Rule {
  const _Rule(this.changeClass, {this.growsAdditively = false});

  final TemplateChangeClass changeClass;

  /// True when the value only ever gets MORE permissive by growing: a
  /// list that gained entries without losing any, or a count that went
  /// up. Such a change is [TemplateChangeClass.additive] even on a field
  /// declared breaking, because nothing that existed stopped existing.
  ///
  /// This is docs/06 §7.2's "new column data on existing ports" and its
  /// "new port" generalised one level: `acceptedFamilies` gaining an entry
  /// widens what may connect and cannot orphan anything, while losing one
  /// narrows it and can.
  final bool growsAdditively;
}

const _safe = _Rule(TemplateChangeClass.safe);
const _additive = _Rule(TemplateChangeClass.additive);
const _breaking = _Rule(TemplateChangeClass.breaking);
const _breakingUnlessGrown = _Rule(
  TemplateChangeClass.breaking,
  growsAdditively: true,
);

// ─── The tables ──────────────────────────────────────────────────────
// Keyed by WIRE name, not by Dart field name, and the two differ on the
// unit-suffixed fields (`bodyDepthNm`, `weightUg`). The wire name is the
// right key because the wire is what a downstream reader sees, and because
// `template_change_class_coverage_test.dart` gates these tables against
// the codec's own encoders: a field added to a file without a class here
// fails that test rather than silently classifying as safe.

const Map<String, _Rule> _bodyRules = {
  // Identity and presentation. docs/06 §7.2 names rename, description and
  // tags as safe outright.
  'manufacturer': _safe,
  'model': _safe,
  'displayName': _safe,
  'description': _safe,
  'category': _safe,
  'tags': _safe,
  // Seeds the designator FORMAT for newly placed instances. Designators
  // already assigned are stored on the `Port`, so nothing already drawn
  // is renamed by this.
  'typePrefix': _safe,

  // Occupancy: the struct that decides where the device sits and what
  // sits under it (CR-036). Every one of these moves other devices.
  'frontU': _breaking,
  'rearU': _breaking,
  'side': _breaking,
  'mountMethod': _breaking,
  // A LIST of alternatives: gaining one is additive, losing one can
  // invalidate a placement made on the strength of it.
  'alternateMountMethods': _breakingUnlessGrown,
  'widthClass': _breaking,
  'nominalSpanTwelfths': _breaking,
  'customPanelWidthNm': _breaking,

  // Dimensions and masses: DRC inputs, not layout. See the header.
  'chassisWidthNm': _safe,
  'bodyDepthNm': _safe,
  'connectorProjectionNm': _safe,
  'weightUg': _safe,
  'maxUnsupportedMassUg': _safe,
  'requiresClearanceAboveU': _safe,
  'requiresClearanceBelowU': _safe,
  'thermalClass': _safe,

  // A container holds other devices. Turning the flag off strands
  // whatever is inside it; the capacities are ratings a rule reads.
  'isContainer': _breaking,
  'containerWeightCapacityUg': _safe,
  'containerUsableDepthNm': _safe,
  'containerUsableWidthNm': _safe,
  'containerVented': _safe,

  // docs/06 §7.2, verbatim: "`isPassthrough` toggled" and "passthrough
  // pairing altered" are both breaking.
  'isPassthrough': _breaking,

  // Colour and faceplate art. docs/06 §7.2: colour and glyph are safe.
  // The device glyph (DR-059) joins them by the same reading: it changes
  // what a mark looks like on an elevation and touches no connection and
  // no occupancy.
  'accentColor': _safe,
  'glyph': _safe,

  // A credit the application never reads (DR-033), and a provenance join
  // that Duplicate writes once and nothing else should ever touch
  // (CR-062). Neither can invalidate anything downstream.
  'submittedBy': _safe,
  'derivedFrom': _safe,
};

// PowerProfile, reached as `power.<key>`. Every field here is a rating or
// a count that a rollup reads (CR-056, AC-039); none of them moves a
// device or touches a connection, which is docs/06 §7.2's "wattage".
const Map<String, _Rule> _powerRules = {
  'nameplateWatts': _safe,
  'typicalWatts': _safe,
  'standbyWatts': _safe,
  'nominalVolts': _safe,
  'apparentVA': _safe,
  'powerFactor': _safe,
  'isContinuousLoad': _safe,
  'outletsProvided': _safe,
  'outletsConsumed': _safe,
  'outputCapacityVA': _safe,
  'outputCapacityWatts': _safe,
  'inletPlug': _safe,
  'poeBudgetWatts': _safe,
  'btuPerHourOverride': _safe,
};

const Map<String, _Rule> _portRules = {
  // The migration join itself (CR-051). A changed key is a delete plus an
  // add and never reaches this table; the entry exists so the coverage
  // gate can see the field is accounted for.
  'key': _breaking,
  // The aliases that RESCUE a rename. Gaining one recovers connections;
  // losing one orphans them.
  'renamedFrom': _breakingUnlessGrown,

  'label': _safe,
  'designatorHint': _safe,

  // "connector or family retyped incompatibly" — computed as "retyped"
  // until M5's compat matrix exists. See the header.
  'connector': _breaking,
  'signalFamily': _breaking,
  'carriedProtocols': _breakingUnlessGrown,
  'acceptedFamilies': _breakingUnlessGrown,

  'direction': _breaking,
  'returnChannel': _safe,
  'topology': _breaking,
  // Raising the ceiling cannot orphan anything; lowering it can.
  'maxConnections': _breakingUnlessGrown,
  'gender': _breaking,
  // Front to rear moves where the cable physically lands.
  'face': _breaking,
  // docs/06 §7.2: "panel coordinates" are safe.
  'position': _safe,

  // The two fields whose change makes INSTALLED WORK wrong rather than
  // orphaning anything — the third clause of `breaking`. AC-052 names
  // `pinoutVariant` as the IR emitter/receiver hazard; AC-030 put
  // `polarity` on the terminal so a typo would be inexpressible.
  'pinoutVariant': _breaking,
  'polarity': _breaking,

  'conductorCount': _safe,
  'impedanceOhms': _safe,
  'level': _safe,
  'balanced': _safe,
  'phantomPowerCapable': _safe,
  'nominalVoltage': _safe,
  'maxCurrentMa': _safe,

  // PRESENTATION grouping (CR-055) — the same class as reordering.
  'bankKey': _safe,
  // ELECTRICAL grouping (CR-055). Which set a port belongs to, and its
  // role in it, is what the port IS electrically: an L that becomes an R
  // is a mis-wire, not a relabel.
  'setKey': _breaking,
  'setRole': _breaking,
  // An ordinal within a set. Its nearest named neighbours in §7.2 are
  // "port label changes" and "port reordering". Populated on NONE of the
  // 727 seed ports (DR-012's census), which is not why it is safe.
  'channelIndex': _safe,

  // Capability descriptions. Compared whole rather than field by field:
  // "this port's PoE spec changed" is the granularity a save-time label
  // needs, and none of them can orphan a link.
  'poe': _safe,
  'linkSpeedMbps': _safe,
  'sfp': _safe,
  'fiberMode': _safe,
  'wavelengthNm': _safe,
  'bus': _safe,
  'serial': _safe,
  'power': _safe,

  // docs/06 §7.2: "port reordering" is safe.
  'order': _safe,
  'notes': _safe,
};

// Banks are PRESENTATION (CR-055): they drive symbol edges, brackets and
// collapse. Nothing here reaches a conductor.
const Map<String, _Rule> _bankRules = {
  'key': _safe,
  'label': _safe,
  'abbr': _safe,
  'symbolSide': _safe,
  'collapseInSymbol': _safe,
  'order': _safe,
};

// Port sets are ELECTRICAL (CR-055), so the two structural fields are
// breaking and the two cosmetic ones are not.
const Map<String, _Rule> _portSetRules = {
  'key': _breaking,
  'label': _safe,
  'kind': _breaking,
  'atomicConnect': _safe,
};

// docs/06 §7.2, verbatim: "passthrough pairing altered" is breaking.
const Map<String, _Rule> _passthroughRules = {
  'frontKey': _breaking,
  'rearKey': _breaking,
  'sameNet': _breaking,
};

// Faceplate art. docs/06 §7.2 classes "glyph" as safe.
const Map<String, _Rule> _panelGraphicRules = {
  'id': _safe,
  'kind': _safe,
  'geometryRef': _safe,
};

/// The five keyed collections, their wire key and the identity each
/// element is joined on. Exposed for the coverage gate, which walks the
/// same list rather than repeating it.
@visibleForTesting
const Map<String, String> kTemplateCollectionIdentityKeys = {
  'ports': 'key',
  'banks': 'key',
  'portSets': 'key',
  // A front port passes through to ONE rear port, so the front key is the
  // pair's identity and a re-pointed `rearKey` reads as a change to that
  // pair rather than as a delete plus an add.
  'passthroughPairs': 'frontKey',
  'panelGraphics': 'id',
};

/// What appearing and disappearing costs, per collection. A new port and
/// a new bank are docs/06 §7.2's own "additive" examples; a deleted port
/// is its own "breaking" example. Removing a bank ungroups presentation
/// and removing a graphic erases art, neither of which touches a link.
const Map<String, ({_Rule added, _Rule removed})> _collectionRules = {
  'ports': (added: _additive, removed: _breaking),
  'banks': (added: _additive, removed: _safe),
  'portSets': (added: _additive, removed: _breaking),
  'passthroughPairs': (added: _breaking, removed: _breaking),
  'panelGraphics': (added: _safe, removed: _safe),
};

const Map<String, Map<String, _Rule>> _collectionFieldRules = {
  'ports': _portRules,
  'banks': _bankRules,
  'portSets': _portSetRules,
  'passthroughPairs': _passthroughRules,
  'panelGraphics': _panelGraphicRules,
};

/// Every wire key this file classifies, grouped by the `json_codec.dart`
/// encoder that emits it.
///
/// **The gate's other half.** `template_change_class_coverage_test.dart`
/// reads the codec's own encoder bodies and asserts the two sets match
/// exactly, in both directions: a field added to a template file without a
/// class here fails, and so does a class left behind for a field the codec
/// dropped. Without it the tables above are a list somebody maintains by
/// remembering to, and the failure that produces is a breaking change
/// labelled safe.
///
/// The nested spec encoders (`_encodePoeSpec`, `_encodeBusCapability`,
/// `_encodeSerialSpec`, `_encodePortPowerSpec`, `_encodePanelPosition`)
/// are deliberately absent: their parent key is classified whole, so their
/// interiors are opaque here by design rather than by omission.
@visibleForTesting
Map<String, Set<String>> get templateChangeClassifiedKeys => {
  '_encodeTemplateBody': {
    ..._bodyRules.keys,
    ...kTemplateCollectionIdentityKeys.keys,
    'power',
  },
  '_encodePowerProfile': _powerRules.keys.toSet(),
  '_encodePortDef': _portRules.keys.toSet(),
  '_encodeBankDef': _bankRules.keys.toSet(),
  '_encodePortSetDef': _portSetRules.keys.toSet(),
  '_encodePassthroughPairDef': _passthroughRules.keys.toSet(),
  '_encodePanelGraphic': _panelGraphicRules.keys.toSet(),
};

/// Classifies the edit that turns [before] into [after] (docs/06 §7.2,
/// CR-050).
///
/// **Diffed over the ENCODED bodies rather than the Dart objects, for
/// `copyTemplateBody`'s reason.** `TemplateBody` has ~50 fields and most
/// of its nested types define no `==` at all, so a hand-written
/// comparison drifts the first time somebody adds field 51 — and the
/// failure mode is a real change silently classified as no change, which
/// nothing would catch. The encoder is already under CR-117's
/// byte-exactness gate, so a field this diff cannot see is a field the
/// FILE cannot carry, and that gate fails first and louder.
///
/// A consequence worth stating: an edit the codec does not persist is not
/// a change here either. That is the correct answer, because the class
/// describes what a downstream reader will receive.
TemplateChangeReport classifyTemplateChange(
  TemplateBody before,
  TemplateBody after,
) {
  final changes = <TemplateChange>[];
  final a = templateBodyToJson(before);
  final b = templateBodyToJson(after);

  _diffMap(a, b, _bodyRules, '', changes);
  _diffMap(
    a['power']! as JsonMap,
    b['power']! as JsonMap,
    _powerRules,
    'power.',
    changes,
  );
  for (final collection in kTemplateCollectionIdentityKeys.keys) {
    _diffCollection(collection, a, b, changes);
  }

  changes.sort((x, y) => x.path.compareTo(y.path));
  return TemplateChangeReport(List.unmodifiable(changes));
}

/// Compares the SCALAR keys of two encoded maps. Keys named in
/// [kTemplateCollectionIdentityKeys], plus `power`, are skipped here and
/// walked by their own pass.
void _diffMap(
  JsonMap a,
  JsonMap b,
  Map<String, _Rule> rules,
  String prefix,
  List<TemplateChange> out,
) {
  for (final key in {...a.keys, ...b.keys}) {
    if (key == 'power' && prefix.isEmpty) continue;
    if (prefix.isEmpty && kTemplateCollectionIdentityKeys.containsKey(key)) {
      continue;
    }
    final rule = rules[key];
    if (rule == null) {
      // Unreachable while `template_change_class_coverage_test.dart`
      // passes. It is a throw rather than a default because the default
      // that would go here is `safe`, and a field silently classified
      // safe is the exact failure this whole file exists to prevent.
      throw StateError(
        'no change class for "$prefix$key" — add it to the table in '
        'builder/template_change_class.dart',
      );
    }
    final before = a[key];
    final after = b[key];
    if (_deepEquals.equals(before, after)) continue;

    final kind = !a.containsKey(key)
        ? TemplateChangeKind.filledIn
        : !b.containsKey(key)
        ? TemplateChangeKind.cleared
        : TemplateChangeKind.changed;

    out.add(
      TemplateChange(
        changeClass: _classOf(rule, kind, before, after),
        kind: kind,
        path: '$prefix$key',
      ),
    );
  }
}

/// Joins two encoded collections on their identity key and reports what
/// appeared, what disappeared and what changed inside a survivor.
void _diffCollection(
  String collection,
  JsonMap a,
  JsonMap b,
  List<TemplateChange> out,
) {
  final identity = kTemplateCollectionIdentityKeys[collection]!;
  final rules = _collectionRules[collection]!;
  final fieldRules = _collectionFieldRules[collection]!;
  final before = _byIdentity(a[collection], identity);
  final after = _byIdentity(b[collection], identity);

  for (final key in {...before.keys, ...after.keys}) {
    final wasThere = before.containsKey(key);
    final isThere = after.containsKey(key);
    if (wasThere && isThere) {
      _diffMap(
        before[key]!,
        after[key]!,
        fieldRules,
        '$collection[$key].',
        out,
      );
    } else {
      out.add(
        TemplateChange(
          changeClass: (isThere ? rules.added : rules.removed).changeClass,
          kind: isThere
              ? TemplateChangeKind.elementAdded
              : TemplateChangeKind.elementRemoved,
          path: '$collection[$key]',
        ),
      );
    }
  }
}

Map<String, JsonMap> _byIdentity(Object? list, String identity) => {
  for (final e in (list! as List<Object?>).cast<JsonMap>())
    e[identity]! as String: e,
};

/// Applies [_Rule.growsAdditively]: a list that only gained entries, or a
/// number that only went up, is additive whatever the field declares.
/// [TemplateChangeKind.filledIn] is additive unconditionally, which is
/// docs/06 §7.2's "new column data on existing ports".
TemplateChangeClass _classOf(
  _Rule rule,
  TemplateChangeKind kind,
  Object? before,
  Object? after,
) {
  if (kind == TemplateChangeKind.filledIn) return TemplateChangeClass.additive;
  if (rule.growsAdditively && _onlyGrew(before, after)) {
    return TemplateChangeClass.additive;
  }
  return rule.changeClass;
}

bool _onlyGrew(Object? before, Object? after) {
  if (before is List && after is List) {
    return after.length > before.length &&
        before.every((e) => after.any((f) => _deepEquals.equals(e, f)));
  }
  if (before is num && after is num) return after > before;
  return false;
}
