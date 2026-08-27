// docs/04-rack-editor.md §4: "Presets are seed data in the same editable
// format as device templates, each carrying height, depth, capacity, rail
// type and RackFormFactor." Built in the idiom seed_catalog.dart already
// establishes — a `build*()` function returning a `Map` keyed by a stable
// string id — so the two catalogs read the same way and a future editable-
// presets UI has the same shape to hang off.
//
// NOT PERSISTED, and that is the important structural fact. A `Rack` has
// no `presetRef`: unlike a device, whose `TemplateSnapshot` really is
// embedded in the file, applying a preset is purely a fan-out of writes to
// `Rack` fields that `json_codec.dart` already round-trips. So there is no
// new entity, no new key, no new nullable, and CR-117's sorted-keys /
// absent-key-not-null / unit-suffixed-name invariants are untouched. It
// also means a preset the user has since diverged from is not something
// the document remembers — an inspector showing "Custom" after a manual
// edit is telling the truth, not losing state.
//
// PROVENANCE: every depth and capacity figure below is a GENERIC ARCHETYPE
// for that class of enclosure, never a real manufacturer SKU — the same
// rule the 48-template device catalog follows (AC-052 / DR-002). See
// `assets/catalog/sources.md` §5.
import 'package:rackpal_core/src/model/rack.dart';
import 'package:rackpal_core/src/units/len.dart';
import 'package:rackpal_core/src/units/mass.dart';

/// One rack preset: the values a user picking it from the Form factor
/// dropdown expects to land on the rack.
///
/// Deliberately NOT every `Rack` field. A preset states the facts that
/// define the archetype; it does not touch identity (name/designator/
/// location), display preferences (`ruNumbering`, `mirrorRearElevation`),
/// or anything derived. Applying one should never silently reset a
/// user's numbering choice.
final class RackPreset {
  const RackPreset({
    required this.id,
    required this.displayName,
    required this.heightU,
    required this.formFactor,
    required this.widthClass,
    required this.railType,
    this.usableDepth,
    this.weightCapacity,
    this.isSwingFrame = false,
    this.hingeSide,
  });

  /// Stable key, also this preset's key in [buildRackPresets].
  final String id;

  /// What the dropdown shows, e.g. "Wall box 6U / 12 in".
  final String displayName;

  /// Always within [1, 60] (CR-038) — asserted by the unit test.
  final int heightU;
  final RackFormFactor formFactor;
  final RackWidthClass widthClass;
  final RailType railType;

  /// Null ONLY where the archetype genuinely has no rail-to-rail usable
  /// depth (a 2-post frame). Null means unknown/not applicable, never
  /// zero (CR-114).
  final Len? usableDepth;

  /// Static load rating. Null would mean unknown; every archetype here
  /// has one.
  final Mass? weightCapacity;

  final bool isSwingFrame;

  /// Only meaningful when [isSwingFrame] is true; null otherwise, so the
  /// inspector's disabled-and-dashed hinge dropdown is a truthful render
  /// of the data rather than a UI-only convention.
  final HingeSide? hingeSide;

  @override
  String toString() => 'RackPreset($id, ${heightU}U)';
}

// Exact conversions — no floating point anywhere in a persisted length
// (CR-001). `Len.nmPerInch` is 25 400 000.
const Len _in12 = Len(12 * Len.nmPerInch);
const Len _in18 = Len(18 * Len.nmPerInch);
const Len _in20 = Len(20 * Len.nmPerInch);
const Len _in24 = Len(24 * Len.nmPerInch);
const Len _in30 = Len(30 * Len.nmPerInch);
const Len _in36 = Len(36 * Len.nmPerInch);

/// Kilograms as exact micrograms (CR-003): 1 kg = 1e9 µg. The factor now
/// lives on [Mass] itself — this file used to be the only one in the
/// catalog that had it right, which is precisely why nine local copies of
/// the arithmetic is not a pattern worth keeping.
Mass _kg(int kilograms) => Mass.fromKilograms(kilograms);

/// The ELEVEN presets docs/04 §4 names, in the order the dropdown shows
/// them: wall-mounted first, then floor, then the open frame, then the
/// furniture and data-room archetypes.
///
/// Eleven, counted from the spec's own list — "Wall box 6U/12in, Swing
/// gate 12U/18in, Pivot cabinet 10U, Floor enclosure 18/21/27/35/44U,
/// Open frame 4-post 44U, Credenza bay 8U, Data 42U/36in" is 1+1+1+5+1+
/// 1+1. Nothing is added beyond that list: notably there is NO
/// `openFrame2Post` preset, even though §4 cites a 2-post frame as the
/// reason `usableDepth` is nullable and `RackFormFactor` carries the
/// value. Inventing a preset the spec does not name, purely to make a
/// null-depth case reachable from seed data, would put an unreviewed
/// archetype's dimensions in front of users; the unset state is reached
/// by clearing the field instead, and is covered by unit test.
///
/// Built (not `const`) purely because [_kg] is a function; the values are
/// immutable regardless, and building a fresh map per call matches
/// `buildSeedCatalog()`'s own contract so a caller can never mutate a
/// shared singleton out from under another.
Map<String, RackPreset> buildRackPresets() {
  final presets = <RackPreset>[
    RackPreset(
      id: 'wallBox6U',
      displayName: 'Wall box 6U / 12 in',
      heightU: 6,
      formFactor: RackFormFactor.wallFixed,
      widthClass: RackWidthClass.eia19,
      railType: RailType.tapped10_32,
      usableDepth: _in12,
      weightCapacity: _kg(45),
    ),
    RackPreset(
      id: 'swingGate12U',
      displayName: 'Swing gate 12U / 18 in',
      heightU: 12,
      formFactor: RackFormFactor.wallSwingGate,
      widthClass: RackWidthClass.eia19,
      railType: RailType.tapped10_32,
      usableDepth: _in18,
      weightCapacity: _kg(90),
      isSwingFrame: true,
      hingeSide: HingeSide.left,
    ),
    RackPreset(
      id: 'pivotCabinet10U',
      displayName: 'Pivot cabinet 10U',
      heightU: 10,
      formFactor: RackFormFactor.wallPivotCabinet,
      widthClass: RackWidthClass.eia19,
      railType: RailType.tapped10_32,
      usableDepth: _in20,
      weightCapacity: _kg(68),
      isSwingFrame: true,
      hingeSide: HingeSide.left,
    ),
    RackPreset(
      id: 'floorEnclosure18U',
      displayName: 'Floor enclosure 18U',
      heightU: 18,
      formFactor: RackFormFactor.floorEnclosure,
      widthClass: RackWidthClass.eia19,
      railType: RailType.squareCageNut,
      usableDepth: _in24,
      weightCapacity: _kg(400),
    ),
    RackPreset(
      id: 'floorEnclosure21U',
      displayName: 'Floor enclosure 21U',
      heightU: 21,
      formFactor: RackFormFactor.floorEnclosure,
      widthClass: RackWidthClass.eia19,
      railType: RailType.squareCageNut,
      usableDepth: _in24,
      weightCapacity: _kg(450),
    ),
    RackPreset(
      id: 'floorEnclosure27U',
      displayName: 'Floor enclosure 27U',
      heightU: 27,
      formFactor: RackFormFactor.floorEnclosure,
      widthClass: RackWidthClass.eia19,
      railType: RailType.squareCageNut,
      usableDepth: _in24,
      weightCapacity: _kg(500),
    ),
    RackPreset(
      id: 'floorEnclosure35U',
      displayName: 'Floor enclosure 35U',
      heightU: 35,
      formFactor: RackFormFactor.floorEnclosure,
      widthClass: RackWidthClass.eia19,
      railType: RailType.squareCageNut,
      usableDepth: _in30,
      weightCapacity: _kg(600),
    ),
    RackPreset(
      id: 'floorEnclosure44U',
      displayName: 'Floor enclosure 44U',
      heightU: 44,
      formFactor: RackFormFactor.floorEnclosure,
      widthClass: RackWidthClass.eia19,
      railType: RailType.squareCageNut,
      usableDepth: _in30,
      weightCapacity: _kg(680),
    ),
    RackPreset(
      id: 'openFrame4Post44U',
      displayName: 'Open frame 4-post 44U',
      heightU: 44,
      formFactor: RackFormFactor.openFrame4Post,
      widthClass: RackWidthClass.eia19,
      railType: RailType.squareCageNut,
      usableDepth: _in30,
      weightCapacity: _kg(450),
    ),
    RackPreset(
      id: 'credenzaBay8U',
      displayName: 'Credenza bay 8U',
      heightU: 8,
      formFactor: RackFormFactor.credenzaFurniture,
      widthClass: RackWidthClass.eia19,
      railType: RailType.tapped10_32,
      usableDepth: _in20,
      weightCapacity: _kg(68),
    ),
    RackPreset(
      id: 'data42U36in',
      displayName: 'Data 42U / 36 in',
      heightU: 42,
      formFactor: RackFormFactor.floorEnclosure,
      widthClass: RackWidthClass.eia19,
      railType: RailType.squareCageNut,
      usableDepth: _in36,
      weightCapacity: _kg(900),
    ),
  ];
  return {for (final p in presets) p.id: p};
}

/// The dropdown's display order — the insertion order of
/// [buildRackPresets], named explicitly so a caller never has to rely on
/// `Map` iteration order being meaningful.
List<String> rackPresetOrder() => buildRackPresets().keys.toList();
