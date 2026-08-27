// rackpal_core/src/draw/scene/signal_style.dart — pure Dart.
//
// THE FOUR ENCODING CHANNELS, RESOLVED IN ONE PLACE (docs/05 §6.1,
// CR-078, AC-054). A signal family arrives; a hue, a dash, a weight and a
// glyph+tag token leave.
//
// ═════════════════════════════════════════════════════════════════════
// WHY FOUR CHANNELS AND NOT ONE, RESTATED SO IT CANNOT BE ERODED
// ═════════════════════════════════════════════════════════════════════
// There are ~50 signal families and NO CATEGORICAL PALETTE IS
// COLOUR-VISION-DEFICIENCY-SAFE PAST 8–9 CATEGORIES — the Okabe–Ito
// authors stopped at eight, having verified their set under protanopia,
// deuteranopia and tritanopia simulation. A hue per cable type "does not
// produce a colour-coded drawing; it produces an unreadable one, and it
// fails hardest for the ~8% of male installers with a CVD who are the
// exact audience" (docs/05 §6.1).
//
// So HUE IS NEVER USED ALONE:
//
//   hue         → domain (8, Okabe–Ito)   ✗ greyscale  ✗ photocopy
//   dash        → type-within-domain      ✓ greyscale  ✓ photocopy
//   weight      → domain tier, 0.75×–2×   ✓ greyscale  ✓ photocopy
//   glyph + tag → exact family            ✓ greyscale  ✓ photocopy
//
// The last row is ONE channel in §6.1's own table, not two, which is why
// [SignalStyle.familyToken] emits the glyph and the tag as a single run:
// they answer the same question ("which family, exactly") and splitting
// them would double the text runs on the commit path for no extra
// information. §6.1's rejected alternative — a `color` per family — is
// rejected here too; the one per-family hue escape that ships is
// `ProjectSettings.familyColorOverrides` (AC-054), applied below.
//
// ═════════════════════════════════════════════════════════════════════
// "EFFECTIVE" IS PAL-1'S OWN WORD, AND THIS FILE IS WHERE IT HAPPENS
// ═════════════════════════════════════════════════════════════════════
// PAL-1 is stated over the triple *(L, dashClass, weight)* where each
// term is the family's EFFECTIVE value — "after any per-family override
// (`colorOverride`, `dashOverride`, weight override), NOT the domain base
// value" (docs/05 §6.3). `tools/pal1_check.py` is the authority and it
// enumerates the 55 shipped families' rendered values pairwise. A
// renderer that read `SignalFamilyDef.dashOverride` directly would draw a
// whole domain's families alike, and the check would then be clearing a
// palette that nothing draws. So this file resolves through
// `SignalFamilyDef.effectiveDashPattern` / `.effectiveLineWeightPermille`
// (DR-010 §11.10.3) and nothing else in the drawing layer may resolve a
// channel.
//
// ═════════════════════════════════════════════════════════════════════
// JACKET COLOUR IS NOT A HUE CHANNEL
// ═════════════════════════════════════════════════════════════════════
// A cable's sheath colour never reaches this file or any other drawing
// source. It is a physical fact about the building and belongs on the
// schedule, the label and the keystone; the hue is the signal DOMAIN's.
// Coupling them "would be worse than useless — a blue control run and a
// blue A/V run would render identically, and a shop that repaints its
// convention would silently repaint its schematic" — and it would swap a
// CVD-verified palette for whatever was on the reel.
// `jacket_colour_is_not_hue_test.dart` scans this directory and fails the
// build on the names that would carry it here.
//
// ═════════════════════════════════════════════════════════════════════
// THE GLYPH CHANNEL IS DEGRADED, AND THE DEGRADATION IS COUNTED
// ═════════════════════════════════════════════════════════════════════
// `SignalDomainDef` carries `glyph`/`glyphAlt` — "native / transported",
// filled versus hollow (docs/05 §5: "fill encodes tier"). NOTHING IN THE
// MODEL SAYS WHICH TIER A FAMILY IS. There is no `tier` field, and all
// three candidate proxies fail against docs/05 §6.4's own table:
//
//   * "a family with a weight override is the transported one" makes
//     `video.hdmi.1_4` (750) hollow △, but §6.4 prints ▲ for all three
//     HDMI generations;
//   * "a family with a dash override" makes `audio.spdif_coax` hollow,
//     and §6.4 prints the FILLED ◆ for it;
//   * an id-namespace rule (`rf.` inside `video.analog` ⇒ ▽) is true of
//     that one domain and says nothing about the other seven.
//
// So this file draws `SignalDomainDef.glyph` — the native shape — for
// every family, and raises [SignalStyle.glyphIsUnderdetermined] on every
// family whose domain declares a DIFFERENT `glyphAlt`: every family whose
// shape this renderer cannot verify. `SchematicScene.underGlyphedFamilyIds`
// counts them, so the wrongness is REPORTED rather than silent (G4).
//
// THIS IS WIDER THAN THE DEFECT USUALLY NAMED. `audio.analog` and `pwr`
// each carry THREE shapes in docs/05 §6.2 (● / ◐ / ○ and ⬢ / ⬡ / ⏚)
// against two slots, so `audio.speaker_cv` and `power.bonding` have
// nowhere to put their third — but the missing SELECTOR above means the
// second slot is unreachable too, in all eight domains. Neither is fixed
// here: DR-010 §11.10.4 deliberately keeps a per-family glyph out of
// scope, and that is a ruling, not an implementation detail. Inventing a
// third slot, or a tier heuristic, would be fabricating a fact the model
// cannot express.

import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'package:rackpal_core/src/model/registries.dart';
import 'package:rackpal_core/src/units/ids.dart';
import 'package:rackpal_core/src/units/rgb.dart';

/// Which of the two stored hues a domain renders in.
///
/// Dash, weight, glyph and tag are IDENTICAL across themes; only hue moves
/// (docs/05 §6.2), and the theme is a UI preference never persisted in a
/// document. `pwr` inverts — `#000000` light, `#E8E8E8` dark — which is
/// why the pair is stored rather than derived from one value.
enum SignalTheme { light, dark }

/// The width, in points, that a `lineWeightPermille` of 1000 draws at.
///
/// docs/05 §5's weight table, print column: the `1.00× signal` row is
/// 0.7 pt. Its other rows are that figure times the multiplier, rounded to
/// one decimal FOR DISPLAY — 0.75× prints as `0.5`, 1.25× as `0.9`, 1.50×
/// as `1.0`, 2.00× as `1.4`.
///
/// THE ROUNDING IS DELIBERATELY NOT REPRODUCED. PAL-1's limb (b) rescues a
/// shared dash class only when two weights "differ by a factor ≥ 1.4", and
/// `tools/pal1_check.py` evaluates that ratio on the PERMILLE values.
/// Emitting the table's rounded figures would put different ratios on
/// paper than the authority cleared — 1.25× would arrive as 0.9/0.7 =
/// 1.286 and 0.75× as 0.5/0.7 = 1.4 — so the check would be clearing a
/// palette the sheet does not draw. Exact multiplication keeps the ratio
/// the authority checked.
const double kSignalBaseWeightPt = 0.7;

/// docs/05 §5: "Minimum print stroke is 0.5 pt and **no stroke is ever
/// emitted at 0**."
///
/// It does not fire on the shipped palette — the lightest family is 750
/// permille = 0.525 pt. It is here for the family authored lighter one
/// day, and that day has a consequence worth stating: once the floor
/// clamps, PAL-1's ratio limb is being evaluated on permille values the
/// sheet no longer reproduces, which `tools/pal1_check.py` cannot see.
/// `signal_style_test.dart` asserts the shipped seed stays clear of the
/// floor, so that day arrives as a red test rather than as a quiet loss.
const double kMinSignalStrokePt = 0.5;

/// The ink a signal whose registry entry does not resolve is drawn in.
///
/// A NEUTRAL SLATE, AND NOT ANY DOMAIN'S HUE — the whole point of the
/// value is that it reads as "this document does not know", so colliding
/// with `str`'s `#999999` or with any Okabe–Ito hue would make an
/// unresolved family look like a resolved one. It is also not PAL-2's
/// `#F0E442`, which "is reserved for selection and focus and is never a
/// cable". `signal_style_test.dart` pins both facts against the seeded
/// registries rather than against a transcribed copy of the palette.
const int kUnresolvedSignalArgb = 0xFF64748B;

/// The separator between a domain tag prefix and a family short tag —
/// `VID·HD20`. docs/08 §3.5's own form, and the one the schedule's `TYPE`
/// cell already prints (`derived/schedule.dart`'s `typeCell`).
const String kSignalTagSeparator = '·';

const _dashEquality = ListEquality<double>();

/// The four channels, resolved for one [SignalFamilyId].
///
/// Every field is a RENDERED value: apply it, never re-derive from it.
@immutable
final class SignalStyle {
  const SignalStyle({
    required this.familyId,
    required this.domainId,
    required this.argb,
    required this.dash,
    required this.widthPt,
    required this.glyph,
    required this.tag,
    required this.hueIsOverridden,
    required this.glyphIsUnderdetermined,
    required this.resolved,
  });

  final SignalFamilyId familyId;

  /// The resolved domain, or `null` when the family — or the domain its
  /// `domain` FK names — is absent from `doc.registries`.
  final SignalDomainId? domainId;

  /// CHANNEL 1, hue. Packed 0xAARRGGBB, opaque. The domain's themed hue,
  /// the caller's per-family override (AC-054), or
  /// [kUnresolvedSignalArgb].
  final int argb;

  /// CHANNEL 2, dash, in POINTS. `null` means SOLID.
  ///
  /// NULL AND EMPTY ARE DIFFERENT AND THE DIFFERENCE IS LOAD-BEARING.
  /// `SignalFamilyDef.effectiveDashPattern` returns the EMPTY LIST for a
  /// solid line — there, `null` means "inherit the domain's" — while
  /// `Stroke.dash` spells solid as `null` and would hand an empty pattern
  /// straight to `dashPath`/`PdfGraphics`. The conversion happens once,
  /// here, so no call site has to remember which convention it is holding.
  final List<double>? dash;

  /// CHANNEL 3, weight, in points, already floored at
  /// [kMinSignalStrokePt].
  final double widthPt;

  /// CHANNEL 4a, the domain glyph — always the NATIVE shape. Empty when
  /// the domain does not resolve. See the file header on why `glyphAlt`
  /// is never selected.
  final String glyph;

  /// CHANNEL 4b, the family tag token — `HD20`, `SPK`, `232`.
  ///
  /// Degrades the way `ScheduleEntry.typeCell` degrades, one step at a
  /// time and never into an abbreviation this code invented (G4):
  /// `VID·HD20` when both halves resolve, the bare domain prefix when only
  /// the domain does, the bare short tag when only the family does, and
  /// the raw `SignalFamilyId` when neither does.
  ///
  /// It prints `shortTag` where the schedule prints `displayName`, and the
  /// difference is deliberate: §4.4 calls this column the tag pill's
  /// token, `displayName` is `HDMI 2.0 (18 Gbps)` and does not fit a
  /// pennant, and `derived/schedule.dart`'s own header records that it
  /// kept `displayName` only to avoid churning the schedule's golden.
  final String tag;

  /// True when [argb] came from `ProjectSettings.familyColorOverrides`
  /// rather than from the domain. Exposed because an overridden hue sits
  /// OUTSIDE the Okabe–Ito set and therefore outside PAL-1's guarantee —
  /// a legend or an export check that wants to say so needs to know, and
  /// re-comparing the emitted colour against the palette to find out would
  /// be a second answer to a question resolved here.
  final bool hueIsOverridden;

  /// See the file header. True when the domain declares a `glyphAlt` that
  /// differs from `glyph`, i.e. when this family's shape cannot be
  /// verified because no model field selects a tier.
  final bool glyphIsUnderdetermined;

  /// True when the family AND its domain both resolved. False means this
  /// style is the honest degradation, not a drawing decision.
  final bool resolved;

  /// Channel 4 as one text run — `▲ HD20`. See the file header: §6.1's
  /// table makes glyph and tag ONE channel, so they are one run.
  ///
  /// Falls back to the tag alone when the domain (and therefore the glyph)
  /// did not resolve, which keeps the run non-empty for every family: a
  /// pennant with no family token would be hue-only, and hue alone is the
  /// one thing §6.1 forbids.
  String get familyToken => glyph.isEmpty ? tag : '$glyph $tag';

  @override
  bool operator ==(Object other) =>
      other is SignalStyle &&
      other.familyId == familyId &&
      other.domainId == domainId &&
      other.argb == argb &&
      _dashEquality.equals(other.dash, dash) &&
      other.widthPt == widthPt &&
      other.glyph == glyph &&
      other.tag == tag &&
      other.hueIsOverridden == hueIsOverridden &&
      other.glyphIsUnderdetermined == glyphIsUnderdetermined &&
      other.resolved == resolved;

  @override
  int get hashCode => Object.hash(
    familyId,
    domainId,
    argb,
    dash == null ? null : _dashEquality.hash(dash),
    widthPt,
    glyph,
    tag,
    hueIsOverridden,
    glyphIsUnderdetermined,
    resolved,
  );

  @override
  String toString() =>
      'SignalStyle(${familyId.v}, ${domainId?.v ?? '-'}, '
      '0x${argb.toRadixString(16)}, dash: $dash, ${widthPt}pt, '
      '$familyToken)';
}

/// Resolves [family] onto the four channels.
///
/// THE RESOLUTION CHAIN, and every link in it can fail:
/// `family` → `registries.signalFamilies[..]` → `.domain` →
/// `registries.signalDomains[..]`. Before DR-010 (`a984add`) the FIRST
/// step failed in every document ever written, because the registries
/// shipped empty — so the degraded path below is not hypothetical, it is
/// what every pre-DR-010 file still does.
///
/// [colorOverrides] is `ProjectSettings.familyColorOverrides` (AC-054).
/// It is passed in rather than read off a document because this function
/// has no document: the legend, the schedule's `TYPE` chip and the
/// exporter all resolve a family without one.
///
/// AN OVERRIDE IS THEME-INDEPENDENT. It is a colour a user chose, and
/// re-tinting it for dark mode would be second-guessing that choice; only
/// the two SEEDED hues form a light/dark pair, because only they were
/// authored as one.
SignalStyle resolveSignalStyle({
  required SignalFamilyId family,
  required Registries registries,
  Map<SignalFamilyId, Rgb> colorOverrides = const {},
  SignalTheme theme = SignalTheme.light,
}) {
  final def = registries.signalFamilies[family];
  final domain = def == null ? null : registries.signalDomains[def.domain];
  final override = colorOverrides[family];

  final argb = override != null
      ? _argbOf(override)
      : domain == null
      ? kUnresolvedSignalArgb
      : _argbOf(theme == SignalTheme.dark ? domain.colorDark : domain.color);

  // WITH NO DOMAIN THERE IS NOTHING TO INHERIT FROM, but the family's OWN
  // overrides are still its own declared facts and are still applied:
  // discarding them would draw two families alike for no reason. The
  // INHERITED half falls back to solid at 1000 permille — the identity,
  // not some domain's base value, which is the distinction that keeps this
  // from being an invented default.
  final permille = domain != null
      ? def!.effectiveLineWeightPermille(domain)
      : (def?.lineWeightPermilleOverride ?? 1000);
  final dashPermille = domain != null
      ? def!.effectiveDashPattern(domain)
      : (def?.dashOverride ?? const <int>[]);

  return SignalStyle(
    familyId: family,
    domainId: domain?.id,
    argb: argb,
    // Empty ⇒ solid ⇒ `null`. See [SignalStyle.dash].
    dash: dashPermille.isEmpty
        ? null
        : List<double>.unmodifiable(<double>[
            for (final p in dashPermille) p / 1000,
          ]),
    widthPt: math.max(
      kMinSignalStrokePt,
      kSignalBaseWeightPt * permille / 1000,
    ),
    glyph: domain?.glyph ?? '',
    tag: _tagFor(def, domain, family),
    hueIsOverridden: override != null,
    // See the file header: a domain that declares a second shape has a
    // tier this renderer cannot select, so every one of its families is
    // drawn with a glyph that may be the wrong one.
    glyphIsUnderdetermined: domain != null && domain.glyphAlt != domain.glyph,
    resolved: domain != null,
  );
}

/// [SignalStyle.tag]'s degradation ladder, in one place so the four steps
/// are read together rather than as nested conditionals at a call site.
String _tagFor(
  SignalFamilyDef? def,
  SignalDomainDef? domain,
  SignalFamilyId family,
) {
  final short = def?.shortTag;
  if (domain != null && short != null) {
    return '${domain.tagPrefix}$kSignalTagSeparator$short';
  }
  if (domain != null) return domain.tagPrefix;
  if (short != null) return short;
  return family.v;
}

/// [Rgb] → packed 0xAARRGGBB, the convention every `Fill`/`Stroke`/
/// `TextStyleSpec` in `draw/` uses. `Rgb` carries its own alpha and the
/// seeded hues are all opaque; a hue authored translucent would arrive
/// translucent rather than being silently forced opaque.
int _argbOf(Rgb c) => (c.a << 24) | (c.r << 16) | (c.g << 8) | c.b;
