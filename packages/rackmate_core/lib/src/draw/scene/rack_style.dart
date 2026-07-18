// rackmate_core/src/draw/scene/rack_style.dart — pure Dart.
//
// The colours and text sizes the rack scene builders draw with. Kept as
// packed 0xAARRGGBB `int`s (never a Flutter `Color` — core is Flutter-free,
// D1/§3.1) so `rackmate_ui` can hand in a theme-derived palette while all
// geometry and structure stay here. Text sizes are in diagram units (= px
// at zoom 1.0, per rack_geometry.dart's scale note).

import 'package:meta/meta.dart';
import 'package:rackmate_core/src/draw/text.dart';

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
}

/// Builds a [TextStyleSpec] with [kRackFont] at [sizePt]/[argb]/[anchor].
/// One helper so every rack label anchors consistently and no caller
/// hand-rolls a spec.
TextStyleSpec rackText(double sizePt, int argb, TextAnchor anchor) =>
    TextStyleSpec(font: kRackFont, sizePt: sizePt, argb: argb, anchor: anchor);
