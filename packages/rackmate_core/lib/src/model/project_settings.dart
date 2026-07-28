import 'package:rackmate_core/src/idformat/collision_policy.dart';
import 'package:rackmate_core/src/idformat/id_format.dart';
import 'package:rackmate_core/src/model/enums.dart'
    show RuNumbering, SheetNumbering, UnitSystem;
import 'package:rackmate_core/src/model/jacket_color.dart';
import 'package:rackmate_core/src/model/rule_override.dart';
import 'package:rackmate_core/src/units/ids.dart';
import 'package:rackmate_core/src/units/permille.dart';
import 'package:rackmate_core/src/units/rgb.dart';

/// Project-wide defaults and the designator/label format engine (CR-045,
/// CR-048): one grammar, one parser, shared by all five call sites that
/// mint a designator or a drop label.
///
/// `blockExportOnErrors` and `greyscaleSafeExport` do NOT exist here
/// (CR-022, CR-077) — export options live on a transient `ExportSpec`
/// instead, which is out of scope for this milestone.
final class ProjectSettings {
  ProjectSettings({
    this.displayUnits = UnitSystem.imperial,
    this.defaultRuNumbering = RuNumbering.bottomUpFromOne,
    this.defaultMirrorRearElevation = true,
    this.sheetNumbering = SheetNumbering.simple,
    this.deviceDesignatorFormat = const IdFormat('{TYPE_PREFIX}{SEP}{SEQ}'),
    this.portDesignatorFormat = const IdFormat('J{PORT_SEQ:2}'),
    this.linkDesignatorFormat = const IdFormat('W{SEQ:3}'),
    this.netNameFormat = const IdFormat('N{SEQ:3}'),
    this.outletFieldLabelFormat = const IdFormat(
      '{ROOM_ABBR}-{SERVICE}-{SEQ}',
    ),
    this.outletRackLabelFormat = const IdFormat(
      '{FLOOR}{SPACE}-{PANEL}{PORT:2}',
    ),
    this.designatorSeparator = '-',
    this.designatorPad = 0,
    this.collisionPolicy = CollisionPolicy.suffixLetter,
    this.designatorBlockSize = 100,
    Map<String, RuleOverride>? ruleOverrides,
    Map<SignalFamilyId, Rgb>? familyColorOverrides,
    Map<JacketColorId, JacketColorDef>? jacketColorConventions,
    Map<String, Permille>? diversityFactorsByCategory,
    this.cableWasteFactor = const Permille(100),
    this.defaultNetworkMedia = const MediaTypeId('media.cat6a_futp'),
    this.defaultRackHeightU = 12,
    this.defaultLineVolts = 120,
  }) : ruleOverrides = ruleOverrides ?? {},
       familyColorOverrides = familyColorOverrides ?? {},
       jacketColorConventions = jacketColorConventions ?? {},
       diversityFactorsByCategory = diversityFactorsByCategory ?? {};

  // ACCESS CONTROL: fields below are plain mutable pending @internal
  // retrofit (AC-013). Converted as each is wired to a Command. See
  // internal_setter_grep_test.dart.

  /// AUTHORITATIVE over any app-level preference (CR-097).
  UnitSystem displayUnits;

  /// Seeds `Rack.ruNumbering` on new racks (CR-026).
  RuNumbering defaultRuNumbering;

  /// Seeds `Rack.mirrorRearElevation` on new racks (CR-035).
  bool defaultMirrorRearElevation;
  SheetNumbering sheetNumbering;

  // Format engine. One grammar, one parser, five call sites (CR-045,
  // CR-048).
  IdFormat deviceDesignatorFormat;
  IdFormat portDesignatorFormat;
  IdFormat linkDesignatorFormat;
  IdFormat netNameFormat;
  IdFormat outletFieldLabelFormat;
  IdFormat outletRackLabelFormat;

  /// "-"; may be empty, giving e.g. "MTX1".
  String designatorSeparator;

  /// 0; 2 gives e.g. "MTX-01".
  int designatorPad;
  CollisionPolicy collisionPolicy;

  /// Reserve blocks for commercial port numbering.
  int designatorBlockSize;

  /// CR-019.
  Map<String, RuleOverride> ruleOverrides;

  /// Ships in v1 (AC-054).
  Map<SignalFamilyId, Rgb> familyColorOverrides;

  /// THE SHOP'S CABLE-COLOUR CONVENTION. Document data, seeded on NEW
  /// documents from `buildDefaultJacketColorConvention()` and fully
  /// editable thereafter. Keyed the way `ruleOverrides` is: the map key
  /// IS the id, so there is no id/key pair that can desynchronise.
  ///
  /// DEFAULTS TO EMPTY, DELIBERATELY, and this is the load-bearing part.
  /// `ProjectSettings()` is what `RackDocument` falls back to and what
  /// the codec builds from a file, so a constructor default of the seven
  /// entries would make an OLD file — written before this feature
  /// existed — decode carrying a convention its author never authored.
  /// That is the fabrication `migrateV1ToV2` refuses. An old file's
  /// convention is genuinely empty and must decode empty; a new document
  /// gets the seed because a new document has an author choosing it.
  ///
  /// The format therefore expresses three distinct states: entries
  /// present = a convention is in force; zero entries = this project has
  /// none; an entry no `Link` references = a colour the shop stocks but
  /// has not pulled.
  Map<JacketColorId, JacketColorDef> jacketColorConventions;

  /// Amplifiers default 350 permille (AC-020).
  Map<String, Permille> diversityFactorsByCategory;

  /// Default 100 permille, footage rollup (AC-024).
  Permille cableWasteFactor;

  MediaTypeId defaultNetworkMedia;
  int defaultRackHeightU;

  /// Seeds new `Circuit`s (CR-039).
  int defaultLineVolts;
}
