// rackmate_core/src/draw/scene/rack_style.dart — pure Dart.
//
// The colours and text sizes the rack scene builders draw with. Kept as
// packed 0xAARRGGBB `int`s (never a Flutter `Color` — core is Flutter-free,
// D1/§3.1) so `rackmate_ui` can hand in a theme-derived palette while all
// geometry and structure stay here. Text sizes are in diagram units (= px
// at zoom 1.0, per rack_geometry.dart's scale note).

import 'package:meta/meta.dart';
import 'package:rackmate_core/src/draw/spec.dart';
import 'package:rackmate_core/src/draw/text.dart';
import 'package:rackmate_core/src/model/enums.dart' show LifecycleStatus;

/// The font family every rack label uses. Matches the one bundled TTF
/// (`apps/rackmate/assets/fonts/Jost-Regular.ttf`) and the family
/// string `FlutterDiagramCanvas._familyFor` resolves (CR-080). No bold cut
/// is bundled yet, so "bolder" labels are expressed through colour weight,
/// not a heavier face — see [RackPalette].
const FontRef kRackFont = FontRef('Jost');

/// Packed-ARGB colours for one rack rendering. Defaults are a neutral
/// light-theme greyscale; `rackmate_ui` overrides them from the active
/// `ColorScheme` so the rack tracks the app theme.
@immutable
final class RackPalette {
  const RackPalette({
    this.frame = 0xFF6B7280,
    this.rail = 0xFFD1D5DB,
    this.railStroke = 0xFF9CA3AF,
    this.divisionMinor = 0x4D6B7280,
    this.divisionMajor = 0x996B7280,
    this.rulerText = 0xB3374151,
    this.rulerTextMajor = 0xFF111827,
    this.deviceFill = 0xFFEFF3F8,
    this.deviceStroke = 0xFF334155,
    this.deviceDesignator = 0xFF0F172A,
    this.deviceName = 0xFF334155,
    this.deviceType = 0xFF64748B,
    this.deviceBadge = 0xFF475569,
    this.hover = 0xFF2563EB,
    this.focus = 0xFF1D4ED8,
    this.selection = 0xFF7C3AED,
  });

  /// Rack enclosure outline.
  final int frame;

  /// Rail fill.
  final int rail;

  /// Rail outline.
  final int railStroke;

  /// Minor U-boundary hairline (docs/04 §2.1: "30% opacity").
  final int divisionMinor;

  /// Every-5th U boundary (docs/04 §2.1: "60% opacity, bolder").
  final int divisionMajor;

  /// RU ruler number, ordinary U.
  final int rulerText;

  /// RU ruler number, every 5th U — heavier ink stands in for the "bolder
  /// label" the docs want, since no bold TTF is bundled yet.
  final int rulerTextMajor;

  /// Device body fill.
  final int deviceFill;

  /// Device body outline.
  final int deviceStroke;

  /// Device designator text (the primary label).
  final int deviceDesignator;

  /// Device name text (secondary).
  final int deviceName;

  /// Device type-name text (tertiary).
  final int deviceType;

  /// U-height badge text.
  final int deviceBadge;

  /// Hover outline (drawn by the device widget, not the scene).
  final int hover;

  /// Focus ring (drawn by the device widget, not the scene).
  final int focus;

  /// Selection outline — the THIRD device chrome state (docs/04 §3.5:
  /// "Multi-select draws a 2px outline per member"), distinct from [hover]
  /// and [focus] and, like them, drawn by the device widget rather than the
  /// scene. A default accent that differs from the hover/focus blues so the
  /// state reads as its own even before a theme remaps it.
  final int selection;

  @override
  bool operator ==(Object other) =>
      other is RackPalette &&
      other.frame == frame &&
      other.rail == rail &&
      other.railStroke == railStroke &&
      other.divisionMinor == divisionMinor &&
      other.divisionMajor == divisionMajor &&
      other.rulerText == rulerText &&
      other.rulerTextMajor == rulerTextMajor &&
      other.deviceFill == deviceFill &&
      other.deviceStroke == deviceStroke &&
      other.deviceDesignator == deviceDesignator &&
      other.deviceName == deviceName &&
      other.deviceType == deviceType &&
      other.deviceBadge == deviceBadge &&
      other.hover == hover &&
      other.focus == focus &&
      other.selection == selection;

  @override
  int get hashCode => Object.hashAll([
    frame,
    rail,
    railStroke,
    divisionMinor,
    divisionMajor,
    rulerText,
    rulerTextMajor,
    deviceFill,
    deviceStroke,
    deviceDesignator,
    deviceName,
    deviceType,
    deviceBadge,
    hover,
    focus,
    selection,
  ]);
}

/// Text sizes (diagram units) for the rack labels, per docs/04 §2.1
/// ("11 px tabular figures" for the ruler). Grouped so the scene builder
/// can report the smallest one it actually emitted as
/// `DiagramScene.minTextSizePt` (the legibility trigger).
abstract final class RackTextSizes {
  /// RU ruler figures.
  static const double ruler = 11;

  /// Device designator (the primary label).
  static const double designator = 11;

  /// Device name (secondary line).
  static const double name = 9;

  /// Device type name (tertiary line).
  static const double type = 8;

  /// U-height / other badges.
  static const double badge = 9;

  /// The load gutter's cumulative-mass readings and its summary block.
  static const double gutter = 8;

  /// The SMALLEST size any rack layer can emit — what [RackTypeScale]
  /// inflates against, and what makes the legibility check checkable.
  ///
  /// Derived from [all] rather than written as a literal, so adding a
  /// smaller size cannot silently escape the floor.
  static double get smallest => all.reduce((a, b) => a < b ? a : b);

  /// Every size declared above.
  static const List<double> all = <double>[
    ruler,
    designator,
    name,
    type,
    badge,
    gutter,
  ];
}

/// Builds a [TextStyleSpec] with [kRackFont] at [sizePt]/[argb]/[anchor].
/// One helper so every rack label anchors consistently and no caller
/// hand-rolls a spec.
/// [rotationRad] is `TextStyleSpec`'s own convention — POSITIVE IS
/// CLOCKWISE, matching `DiagramCanvas.rotate` — and rotation happens about
/// the ANCHOR POINT on every backend, which is what makes an anchor plus an
/// angle a complete description of where a run lands.
///
/// It defaulted to zero for the whole of M0–M2 because nothing drew rotated
/// text, and `design-pdf-export.md`'s open-questions list says exactly what
/// that cost: *"Sign errors here are invisible until someone rotates a
/// label."* `text_rotation_test.dart` is the gate that closes it.
TextStyleSpec rackText(
  double sizePt,
  int argb,
  TextAnchor anchor, {
  double rotationRad = 0,
}) => TextStyleSpec(
  font: kRackFont,
  sizePt: sizePt,
  argb: argb,
  anchor: anchor,
  rotationRad: rotationRad,
);

/// A multiplier applied to every [RackTextSizes] value before it is
/// emitted.
///
/// ─────────────────────────────────────────────────────────────────────
/// WHY ANNOTATION DOES NOT SHRINK WITH THE DRAWING
/// ─────────────────────────────────────────────────────────────────────
/// [RackTextSizes] are in DIAGRAM UNITS, and a rack elevation printed at
/// 1:8 is drawn through a scene factor of `126 / (22 × 8)` ≈ 0.716. At
/// that factor `RackTextSizes.type` (8 units) lands at **5.73 pt on
/// paper**, under docs/08 §6.2's 6.0 pt hard legibility floor. That is a
/// measured fact about the current scene, not a hypothesis — pass 1's
/// legibility check surfaced it.
///
/// Text on a scaled drawing is never at model scale: a drafter does not
/// shrink the lettering when they change the ratio. So the exporter hands
/// in a [RackTypeScale] chosen so that the SMALLEST text the scene emits
/// lands at a stated paper size, and `DiagramScene.minTextSizePt ×
/// sceneFactor` then equals that size exactly — which is what turns §6.2's
/// legibility check from decoration into a check.
///
/// The default is the identity, so screen behaviour is unchanged.
@immutable
extension type const RackTypeScale(double factor) {
  /// No inflation — what the screen uses.
  const RackTypeScale.identity() : this(1);

  /// The scale that puts the smallest emitted rack text at [paperPt] once
  /// [sceneFactor] has been applied.
  ///
  /// [sceneFactor] is diagram units → PDF points (`draw/sheet/
  /// drawing_scale.dart`'s `SceneFactor`, passed as a plain double so this
  /// file stays independent of the sheet layer). A non-positive factor —
  /// an empty scene, a degenerate fit — returns the identity rather than
  /// an infinity that would propagate into every text size.
  factory RackTypeScale.forPaper({
    required double sceneFactor,
    double paperPt = kMinRackPaperPt,
  }) {
    if (sceneFactor <= 0) return const RackTypeScale.identity();
    final natural = RackTextSizes.smallest * sceneFactor;
    // NEVER SHRINKS. A drawing large enough that its smallest text already
    // clears the floor keeps the sizes the screen uses, so a 1:1 detail
    // and the screen agree.
    return natural >= paperPt
        ? const RackTypeScale.identity()
        : RackTypeScale(paperPt / natural);
  }

  /// [base] scaled.
  double size(double base) => base * factor;
}

/// The paper size the smallest rack annotation is inflated to.
///
/// 6.5 pt sits between docs/08 §6.2's 6.0 pt hard floor and its 7.0 pt
/// preferred floor: comfortably legal, and low enough that a 1U device
/// block at 1:8 still has room for its designator. The soft floor is not
/// used because inflating to 7.0 pt costs the second line on a 2U block
/// for a difference nobody reads.
const double kMinRackPaperPt = 6.5;

/// How a device body's outline encodes `DeviceInstance.lifecycleStatus`.
///
/// ─────────────────────────────────────────────────────────────────────
/// DASH AND WEIGHT, NEVER HUE (P4)
/// ─────────────────────────────────────────────────────────────────────
/// docs/08 §2.2 puts a `lifecycleStatus` border on every device block on
/// the elevation sheets. Encoding it as colour alone fails twice over: the
/// sheet is routinely printed on a greyscale office laser and photocopied
/// (AC-054's own acceptance test), and colour-as-sole-channel is P4's
/// explicit prohibition. So the channel is the DASH PATTERN plus the
/// weight, both of which survive a photocopy.
///
/// `new_` — the default for every device the app creates — keeps the plain
/// solid 1.0 pt outline the screen already draws, so the common case is
/// unchanged and the four other states each read as their own thing.
Stroke lifecycleStroke(LifecycleStatus status, int argb) => switch (status) {
  // Already installed: present, but quieter than the work being done.
  LifecycleStatus.existing => Stroke(argb: argb, widthPt: 0.6),
  // The default. Unchanged from the plain device outline.
  LifecycleStatus.new_ => Stroke(argb: argb, widthPt: 1),
  // A later phase: long dash.
  LifecycleStatus.future => Stroke(
    argb: argb,
    widthPt: 1,
    dash: const <double>[4, 2],
  ),
  // Coming out: dotted.
  LifecycleStatus.removed => Stroke(
    argb: argb,
    widthPt: 1,
    dash: const <double>[1, 2],
  ),
  // Not yet a commitment: dash-dot, the drafting convention for intent.
  LifecycleStatus.designIntent => Stroke(
    argb: argb,
    widthPt: 1,
    dash: const <double>[5, 2, 1, 2],
  ),
};
