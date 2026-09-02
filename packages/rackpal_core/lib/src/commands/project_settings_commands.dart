// Writing a project setting (`#805`, RJ-012, AC-054, CR-097).
//
// ═══════════════════════════════════════════════════════════════════════
// TWENTY-TWO FIELDS AND, UNTIL NOW, NO WRITER AT ALL
// ═══════════════════════════════════════════════════════════════════════
// `ProjectSettings` has shipped since M0 and is read across the app:
// `displayUnits` is authoritative over any app-level preference (CR-097),
// `signal_style.dart` consumes `familyColorOverrides` (AC-054), the
// designator machinery reads five `IdFormat`s. **Nothing wrote any of
// them.** A census on 2026-08-31 found no command touching `doc.settings`
// anywhere, so every one of these values was whatever the constructor or
// the codec supplied, for the life of the project.
//
// That made RJ-012 unmeetable as written. It ships three v1 surfaces, and
// the third is *"a per-family colour override row in settings"*: there was
// no settings.
//
// ── ONE COMMAND, A TYPED FIELD TABLE ───────────────────────────────────
// The shape `port_commands.dart` established and argued for: a single
// typed write to a single field is what `SetPortFieldCommand` already is,
// and a bespoke command per setting would be twenty-two undo paths to one
// object. `ProjectSettingField<T>` carries the accessor pair; the command
// carries the before and after.
import 'package:rackpal_core/src/commands/command.dart';
import 'package:rackpal_core/src/commands/label_key.dart';
import 'package:rackpal_core/src/idformat/collision_policy.dart';
import 'package:rackpal_core/src/idformat/id_format.dart';
import 'package:rackpal_core/src/model/enums.dart';
import 'package:rackpal_core/src/model/project_settings.dart';
import 'package:rackpal_core/src/model/rack_document.dart';
import 'package:rackpal_core/src/model/rule_override.dart';
import 'package:rackpal_core/src/units/ids.dart';
import 'package:rackpal_core/src/units/permille.dart';
import 'package:rackpal_core/src/units/rgb.dart';
import 'package:rackpal_core/src/validation/rule_exception.dart';

/// One editable setting: how to read it, how to write it, what to call it.
final class ProjectSettingField<T> {
  const ProjectSettingField({
    required this.key,
    required this.label,
    required this.get,
    required this.set,
    this.help,
  });

  /// Stable and unique within [ProjectSettingFields.all] (asserted by a
  /// test). It is the field's identity in an undo entry.
  final String key;

  /// What the surface calls it. HERE rather than in the widget, so the
  /// undo entry and the row cannot disagree about which setting moved.
  final String label;

  /// One line of trade-facing explanation, or null when the label says
  /// everything. Null is UNKNOWN in the G4 sense only by accident here:
  /// a setting with no help genuinely needs none.
  final String? help;

  final T Function(ProjectSettings s) get;
  final void Function(ProjectSettings s, T value) set;

  @override
  String toString() => 'ProjectSettingField($key)';
}

/// The settings a person may edit (`#805`).
///
/// ═══════════════════════════════════════════════════════════════════════
/// EIGHTEEN OF TWENTY-TWO, AND THE FOUR ABSENCES ARE DELIBERATE
/// ═══════════════════════════════════════════════════════════════════════
/// The four MAPS are each an editor of their own shape and are not rows:
///
///   * `familyColorOverrides` is RJ-012's required surface and ships with
///     `#805`, edited by its own control rather than through this table,
///     because a colour per signal family is a list and not a field.
///   * `ruleOverrides` is AC-011's delicate one. An override carries a
///     severity, a REASON, an AUTHOR and a TIME: it is a signed exception
///     to a shipped rule, so its editor is a small form and never a
///     dropdown. Its WRITE PATH landed at M5-B3 as
///     [SetRuleOverrideCommand] below, on `familyColorOverrides`'
///     precedent; the form is still filed.
///   * `jacketColorConventions` expresses three distinct states (entries
///     present, zero entries, an entry nothing references) and its own
///     doc comment argues each. Filed.
///   * `diversityFactorsByCategory` is a `Permille` per category. Filed.
///
/// **NO ENTRY WITHOUT A SURFACE**, which is `PortDefField`'s rule read
/// across: a field in this table that no row draws is an accessor nobody
/// calls, and that is the state `NetworkConfig` was found in.
abstract final class ProjectSettingFields {
  static const displayUnits = ProjectSettingField<UnitSystem>(
    key: 'displayUnits',
    label: 'Display units',
    help: 'Authoritative over any app-level preference (CR-097).',
    get: _getDisplayUnits,
    set: _setDisplayUnits,
  );

  static const defaultRuNumbering = ProjectSettingField<RuNumbering>(
    key: 'defaultRuNumbering',
    label: 'Default RU numbering',
    help: 'Seeds new racks. Existing racks keep what they were made with.',
    get: _getRuNumbering,
    set: _setRuNumbering,
  );

  static const defaultMirrorRearElevation = ProjectSettingField<bool>(
    key: 'defaultMirrorRearElevation',
    label: 'Mirror rear elevations by default',
    help: 'Seeds new racks (CR-035).',
    get: _getMirror,
    set: _setMirror,
  );

  static const sheetNumbering = ProjectSettingField<SheetNumbering>(
    key: 'sheetNumbering',
    label: 'Sheet numbering',
    get: _getSheetNumbering,
    set: _setSheetNumbering,
  );

  static const deviceDesignatorFormat = ProjectSettingField<IdFormat>(
    key: 'deviceDesignatorFormat',
    label: 'Device designator',
    help: 'Pattern for a placed device, e.g. {TYPE_PREFIX}{SEP}{SEQ}.',
    get: _getDeviceFmt,
    set: _setDeviceFmt,
  );

  static const portDesignatorFormat = ProjectSettingField<IdFormat>(
    key: 'portDesignatorFormat',
    label: 'Port designator',
    help: 'Pattern for a port, e.g. J{PORT_SEQ:2}.',
    get: _getPortFmt,
    set: _setPortFmt,
  );

  static const linkDesignatorFormat = ProjectSettingField<IdFormat>(
    key: 'linkDesignatorFormat',
    label: 'Cable designator',
    help: 'Pattern for one cable, e.g. W{SEQ:3}.',
    get: _getLinkFmt,
    set: _setLinkFmt,
  );

  static const netNameFormat = ProjectSettingField<IdFormat>(
    key: 'netNameFormat',
    label: 'Net name',
    get: _getNetFmt,
    set: _setNetFmt,
  );

  static const outletFieldLabelFormat = ProjectSettingField<IdFormat>(
    key: 'outletFieldLabelFormat',
    label: 'Outlet label, field end',
    help: 'What gets printed on the wall plate.',
    get: _getOutletFieldFmt,
    set: _setOutletFieldFmt,
  );

  static const outletRackLabelFormat = ProjectSettingField<IdFormat>(
    key: 'outletRackLabelFormat',
    label: 'Outlet label, rack end',
    get: _getOutletRackFmt,
    set: _setOutletRackFmt,
  );

  static const designatorSeparator = ProjectSettingField<String>(
    key: 'designatorSeparator',
    label: 'Designator separator',
    help: 'May be empty, which gives MTX1 rather than MTX-1.',
    get: _getSep,
    set: _setSep,
  );

  static const designatorPad = ProjectSettingField<int>(
    key: 'designatorPad',
    label: 'Designator padding',
    help: '0 gives MTX-1; 2 gives MTX-01.',
    get: _getPad,
    set: _setPad,
  );

  static const collisionPolicy = ProjectSettingField<CollisionPolicy>(
    key: 'collisionPolicy',
    label: 'Designator collision policy',
    get: _getCollision,
    set: _setCollision,
  );

  static const designatorBlockSize = ProjectSettingField<int>(
    key: 'designatorBlockSize',
    label: 'Designator block size',
    help: 'Reserve blocks for commercial port numbering.',
    get: _getBlock,
    set: _setBlock,
  );

  static const cableWasteFactor = ProjectSettingField<Permille>(
    key: 'cableWasteFactor',
    label: 'Cable waste factor',
    help: 'Added to every measured run on the pull sheet.',
    get: _getWaste,
    set: _setWaste,
  );

  static const defaultNetworkMedia = ProjectSettingField<MediaTypeId>(
    key: 'defaultNetworkMedia',
    label: 'Default network media',
    get: _getNetMedia,
    set: _setNetMedia,
  );

  static const defaultRackHeightU = ProjectSettingField<int>(
    key: 'defaultRackHeightU',
    label: 'Default rack height (U)',
    get: _getRackU,
    set: _setRackU,
  );

  static const defaultLineVolts = ProjectSettingField<int>(
    key: 'defaultLineVolts',
    label: 'Default line voltage',
    get: _getVolts,
    set: _setVolts,
  );

  /// Every entry above. A test walks this to prove no two share a key
  /// and no accessor pair is aliased onto another field, which is the
  /// census the port field table needed three attempts to get right.
  static const all = <ProjectSettingField<Object?>>[
    displayUnits,
    defaultRuNumbering,
    defaultMirrorRearElevation,
    sheetNumbering,
    deviceDesignatorFormat,
    portDesignatorFormat,
    linkDesignatorFormat,
    netNameFormat,
    outletFieldLabelFormat,
    outletRackLabelFormat,
    designatorSeparator,
    designatorPad,
    collisionPolicy,
    designatorBlockSize,
    cableWasteFactor,
    defaultNetworkMedia,
    defaultRackHeightU,
    defaultLineVolts,
  ];
}

UnitSystem _getDisplayUnits(ProjectSettings s) => s.displayUnits;
void _setDisplayUnits(ProjectSettings s, UnitSystem v) => s.displayUnits = v;
RuNumbering _getRuNumbering(ProjectSettings s) => s.defaultRuNumbering;
void _setRuNumbering(ProjectSettings s, RuNumbering v) =>
    s.defaultRuNumbering = v;
bool _getMirror(ProjectSettings s) => s.defaultMirrorRearElevation;
void _setMirror(ProjectSettings s, bool v) => s.defaultMirrorRearElevation = v;
SheetNumbering _getSheetNumbering(ProjectSettings s) => s.sheetNumbering;
void _setSheetNumbering(ProjectSettings s, SheetNumbering v) =>
    s.sheetNumbering = v;
IdFormat _getDeviceFmt(ProjectSettings s) => s.deviceDesignatorFormat;
void _setDeviceFmt(ProjectSettings s, IdFormat v) =>
    s.deviceDesignatorFormat = v;
IdFormat _getPortFmt(ProjectSettings s) => s.portDesignatorFormat;
void _setPortFmt(ProjectSettings s, IdFormat v) => s.portDesignatorFormat = v;
IdFormat _getLinkFmt(ProjectSettings s) => s.linkDesignatorFormat;
void _setLinkFmt(ProjectSettings s, IdFormat v) => s.linkDesignatorFormat = v;
IdFormat _getNetFmt(ProjectSettings s) => s.netNameFormat;
void _setNetFmt(ProjectSettings s, IdFormat v) => s.netNameFormat = v;
IdFormat _getOutletFieldFmt(ProjectSettings s) => s.outletFieldLabelFormat;
void _setOutletFieldFmt(ProjectSettings s, IdFormat v) =>
    s.outletFieldLabelFormat = v;
IdFormat _getOutletRackFmt(ProjectSettings s) => s.outletRackLabelFormat;
void _setOutletRackFmt(ProjectSettings s, IdFormat v) =>
    s.outletRackLabelFormat = v;
String _getSep(ProjectSettings s) => s.designatorSeparator;
void _setSep(ProjectSettings s, String v) => s.designatorSeparator = v;
int _getPad(ProjectSettings s) => s.designatorPad;
void _setPad(ProjectSettings s, int v) => s.designatorPad = v;
CollisionPolicy _getCollision(ProjectSettings s) => s.collisionPolicy;
void _setCollision(ProjectSettings s, CollisionPolicy v) =>
    s.collisionPolicy = v;
int _getBlock(ProjectSettings s) => s.designatorBlockSize;
void _setBlock(ProjectSettings s, int v) => s.designatorBlockSize = v;
Permille _getWaste(ProjectSettings s) => s.cableWasteFactor;
void _setWaste(ProjectSettings s, Permille v) => s.cableWasteFactor = v;
MediaTypeId _getNetMedia(ProjectSettings s) => s.defaultNetworkMedia;
void _setNetMedia(ProjectSettings s, MediaTypeId v) =>
    s.defaultNetworkMedia = v;
int _getRackU(ProjectSettings s) => s.defaultRackHeightU;
void _setRackU(ProjectSettings s, int v) => s.defaultRackHeightU = v;
int _getVolts(ProjectSettings s) => s.defaultLineVolts;
void _setVolts(ProjectSettings s, int v) => s.defaultLineVolts = v;

/// Sets one project setting.
final class SetProjectSettingCommand<T> extends Command<RackDocument> {
  const SetProjectSettingCommand({
    required this.field,
    required this.from,
    required this.to,
  });

  final ProjectSettingField<T> field;
  final T from;
  final T to;

  @override
  LabelKey get label => LabelKey.setProjectSetting;

  /// `meta` alone, with one deliberate exception noted rather than
  /// modelled: `displayUnits` changes what every dimension on every sheet
  /// READS AS, and `cableWasteFactor` changes the pull sheet's numbers.
  /// Neither changes an entity, and `EpochMask` names entity epochs, so a
  /// broader mask would claim geometry moved when only its presentation
  /// did. The derived layer recomputes from the document either way.
  @override
  EpochMask get touches => EpochMask.meta;

  /// Empty: a setting is not an entity a selection can hold.
  @override
  Iterable<Uuid> get affects => const [];

  @override
  void apply(RackDocument doc) => field.set(doc.settings, to);

  @override
  void revert(RackDocument doc) => field.set(doc.settings, from);
}

/// Sets or clears one family's colour override (AC-054, RJ-012).
///
/// ═══════════════════════════════════════════════════════════════════════
/// ITS OWN COMMAND, BECAUSE A MAP ENTRY IS NOT A FIELD
/// ═══════════════════════════════════════════════════════════════════════
/// `SetProjectSettingCommand` writes a whole value; this writes one key of
/// a map and leaves the rest alone. Routing it through the field table
/// would mean a command carrying two copies of the entire map to move one
/// colour, and an undo that restored colours nobody touched.
///
/// **NULL CLEARS, and clearing is not the same as setting the base hue.**
/// CR-078 puts colour on the signal DOMAIN; an override is a per-family
/// exception to that. Removing the entry returns the family to its
/// domain's colour, which is a different state from an override that
/// happens to equal it: `signal_style.dart` reports whether a colour came
/// from an override, and a legend that said "overridden" about a
/// coincidence would be lying.
final class SetFamilyColorOverrideCommand extends Command<RackDocument> {
  const SetFamilyColorOverrideCommand({
    required this.family,
    required this.from,
    required this.to,
  });

  final SignalFamilyId family;
  final Rgb? from;
  final Rgb? to;

  @override
  LabelKey get label => LabelKey.setFamilyColorOverride;

  @override
  EpochMask get touches => EpochMask.meta;

  @override
  Iterable<Uuid> get affects => const [];

  @override
  void apply(RackDocument doc) => _write(doc, to);

  @override
  void revert(RackDocument doc) => _write(doc, from);

  void _write(RackDocument doc, Rgb? value) {
    if (value == null) {
      doc.settings.familyColorOverrides.remove(family);
    } else {
      doc.settings.familyColorOverrides[family] = value;
    }
  }
}

/// Sets or clears what one DRC rule counts as in this project (`#260`,
/// M5-B3, CR-019).
///
/// ═══════════════════════════════════════════════════════════════════════
/// THE SAME SHAPE AS THE COLOUR OVERRIDE, FOR THE SAME REASONS
/// ═══════════════════════════════════════════════════════════════════════
/// One key of a map, `from`/`to`, null clears. Routing it through the
/// field table would mean a command carrying two copies of the whole map
/// to move one rule, and an undo restoring severities nobody touched.
///
/// **NULL CLEARS, and clearing is not the same as setting the default.**
/// `projectSeverity` falls back to `RuleMeta.defaultSeverity` when there
/// is no entry, so removing the entry returns the rule to what the
/// catalogue says. An override that happens to equal the default is a
/// different state: it carries a reason, an author and a date, and it
/// prints on `T0.02` as a decision somebody made. A surface that treated
/// the two as one would silently delete the record of the decision.
///
/// The reason is REQUIRED, unlike a single-instance acknowledgement.
/// [evaluateRuleOverride] argues why and this constructor asserts it,
/// leaving the codec free to read whatever a file holds.
final class SetRuleOverrideCommand extends Command<RackDocument> {
  SetRuleOverrideCommand({
    required this.ruleId,
    required this.from,
    required this.to,
  }) : assert(
         to == null ||
             evaluateRuleOverride(ruleId: ruleId, reason: to.reason)
                 is RuleExceptionAllowed,
         'built from an override the rules refuse: call '
         'evaluateRuleOverride first and show its message',
       );

  /// `'PWR-001'`. Keyed exactly as `ProjectSettings.ruleOverrides` is.
  final String ruleId;

  final RuleOverride? from;
  final RuleOverride? to;

  @override
  LabelKey get label => LabelKey.setRuleOverride;

  @override
  EpochMask get touches => EpochMask.meta;

  @override
  Iterable<Uuid> get affects => const [];

  @override
  void apply(RackDocument doc) => _write(doc, to);

  @override
  void revert(RackDocument doc) => _write(doc, from);

  void _write(RackDocument doc, RuleOverride? value) {
    if (value == null) {
      doc.settings.ruleOverrides.remove(ruleId);
    } else {
      doc.settings.ruleOverrides[ruleId] = value;
    }
  }
}
