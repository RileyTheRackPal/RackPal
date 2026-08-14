// The device's appearance mark: CR-078's redundancy argument applied to
// the elevation. DR-059 (canon §11.58), board #201, M4-D/3.
//
// ═════════════════════════════════════════════════════════════════════
// WHY A SECOND CHANNEL EXISTS AT ALL
// ═════════════════════════════════════════════════════════════════════
// CR-078 rules that HUE IS NEVER USED ALONE, because no categorical
// palette is CVD-safe past 8 or 9 categories and because hue dies in
// greyscale and on a photocopy, which is how these drawings reach a job
// site. That ruling is written about the schematic and its argument is
// not: the ELEVATION is the sheet that gets taped inside the rack door,
// and `TemplateBody.accentColor` was going to be its only appearance
// channel.
//
// The census that found this is worth keeping, because it is stronger
// than the reasoning: `accentColor` is authored on **0 of the 48 seeded
// templates** and read by **no renderer at all** —
// `draw/scene/device_layer.dart` fills every device with
// `palette.deviceFill`, one uniform colour. So Appearance was about to
// ship two controls and no channel that reaches paper.
//
// ═════════════════════════════════════════════════════════════════════
// SEVENTEEN, AND THE NUMBER IS A MEASUREMENT
// ═════════════════════════════════════════════════════════════════════
// One mark per shipped archetype would be near 40: the catalog has 48
// templates across 9 categories. **The mark draws 1U tall on a greyscale
// photocopy**, and a 40-way silhouette distinction is not readable at
// that size, so the set groups by what a box IS rather than by what it
// is called. The three HDMI matrices are one [matrix]; F04 through F08
// are one [speaker]. Every one of the 48 resolves to a value, and
// `device_glyph_test.dart` asserts it.
//
// Each value below names the seeded catalog ids that motivated it. That
// is not documentation for its own sake: it is the evidence that the set
// was censused rather than invented, and it is what a later reader
// checks a proposed 18th value against.
//
// ═════════════════════════════════════════════════════════════════════
// IT WILL BE DRAWN AS GEOMETRY, NEVER AS A CODEPOINT
// ═════════════════════════════════════════════════════════════════════
// `draw/scene/family_glyph.dart` exists because the SIGNAL glyph once was
// a character. Jost carries none of those codepoints, so `PdfFontMeasurer`
// returned a near-zero advance while the screen's `TextPainter` fell back
// to a system font and drew it at full width. Measured short, drawn wide,
// and the field saw `NET-NEN006` printed over a net name. No gate caught
// it, because both backends emitted identical ops and only the font
// behind one of them differed.
//
// NOTHING DRAWS THESE YET. The 17 vector marks and their renderers are
// M4-K's, sequenced with the three live previews, which is the first
// surface a device glyph appears on at all (DR-059 §11.58.7). This file
// ships the vocabulary and the default; it deliberately ships no paths,
// and says so here rather than leaving it to be discovered.
import 'package:rackmate_core/src/catalog/catalog_audio.dart' show kCatAudio;
import 'package:rackmate_core/src/catalog/catalog_control.dart'
    show kCatControl;
import 'package:rackmate_core/src/catalog/catalog_field.dart' show kCatField;
import 'package:rackmate_core/src/catalog/catalog_network.dart'
    show kCatNetwork;
import 'package:rackmate_core/src/catalog/catalog_passive.dart'
    show kCatPassive;
import 'package:rackmate_core/src/catalog/catalog_power.dart' show kCatPower;
import 'package:rackmate_core/src/catalog/catalog_rf.dart' show kCatRf;
import 'package:rackmate_core/src/catalog/catalog_sources.dart'
    show kCatSources;
import 'package:rackmate_core/src/catalog/catalog_video.dart' show kCatVideo;

/// A device's appearance mark (DR-059). Seventeen silhouettes plus
/// [none], drawn beside `accentColor` so hue is never the only channel.
enum DeviceGlyph {
  /// No mark at all. **Chosen, and not the same as unchosen**: a template
  /// whose author cleared the glyph draws `accentColor` alone, which is
  /// their call. `TemplateBody.glyph` being *null* is the different
  /// thing, and means the category's default applies: see
  /// [effectiveGlyph].
  none,

  /// A crossbar. V01, V02, V03 (the three HDMI/HDBaseT matrices).
  matrix,

  /// One in, many out. V04 the distribution amplifier, R01 the RF
  /// splitter panel, C02 the IR distribution block: three categories,
  /// one silhouette, because at 1U they are the same picture.
  distribution,

  /// Many in, many out, switched. V05 the presentation switcher, N01 the
  /// PoE switch, N02 the router/firewall, R02 the satellite multiswitch.
  switcher,

  /// A link across a distance. V06 the HDBaseT transmitter, V07 the AVoIP
  /// encoder.
  extender,

  /// The triangle. A01, A04, A05 the amplifiers, A02 the AV receiver.
  amplifier,

  /// A processing block. A03 the DSP, C01 the control processor, C03 the
  /// RS-232/IP gateway.
  processor,

  /// A play mark. A06 the streamer, S01 the set-top box, S02 the
  /// media server/NAS, F10 the NVR.
  source,

  /// A row of jacks. N03 the 24-port patch panel, N04 the fibre
  /// enclosure.
  patchPanel,

  /// A plug. P01 the rack PDU, P02 the conditioner/sequencer.
  power,

  /// A cell. P03, the UPS. Its own mark rather than [power]'s, because
  /// "this box holds a battery" is the fact a person looks for on an
  /// elevation and the one that decides where it can sit.
  battery,

  /// A filled face. X01 the blank panel, X02 the vent panel.
  blank,

  /// A ledge. X03, the rack shelf.
  shelf,

  /// A rectangle on a stand. F01 the flat panel, F02 the projector, F03
  /// the motorised screen, F12 the touchpanel.
  display,

  /// A cone. F04 through F08: in-ceiling, in-wall, subwoofer, outdoor and
  /// 70V pendant. Five catalog ids, one picture, and that is the cap
  /// doing its job.
  speaker,

  /// A lens. F09, the IP camera.
  camera,

  /// Radiating arcs. F11 the wireless access point, F17 the OTA antenna.
  /// The two are unrelated in the trade and identical at 1U.
  antenna,

  /// A knob or button plate. F13 the keypad, F14 the volume control,
  /// F15 the IR receiver eye, F16 the ISP gateway/ONT, F18 the F-type
  /// ground block.
  control,
}

/// The glyph a template gets when its author has chosen none, keyed on
/// `TemplateBody.category`.
///
/// **Keyed on `kCatalogCategoryOrder`'s nine strings and NOT on a list of
/// its own** (DR-059 §11.58.6). docs/06 §3.1 used to spell eight
/// categories, abbreviating three and dropping `Field Devices`; a second
/// list is how the palette and the builder come to disagree about what a
/// device is. `device_glyph_test.dart` asserts this map covers the
/// constant exactly, in both directions.
///
/// An unrecognised category answers [DeviceGlyph.none] rather than
/// guessing. A user-authored category is an ordinary thing to have and a
/// wrong picture is worse than no picture.
const Map<String, DeviceGlyph> kCategoryDefaultGlyph = {
  kCatVideo: DeviceGlyph.matrix,
  kCatAudio: DeviceGlyph.amplifier,
  kCatNetwork: DeviceGlyph.switcher,
  kCatControl: DeviceGlyph.processor,
  kCatSources: DeviceGlyph.source,
  kCatRf: DeviceGlyph.distribution,
  kCatPower: DeviceGlyph.power,
  kCatPassive: DeviceGlyph.blank,
  // The 18 field devices are the widest category by a factor of four and
  // the only one whose members share no silhouette at all: a speaker, a
  // camera, a keypad and a projector. `display` is the modal answer
  // rather than the right one, which is why the form's picker matters
  // more here than anywhere else.
  kCatField: DeviceGlyph.display,
};

/// The default mark for [category], or [DeviceGlyph.none] when nothing
/// is known about it.
DeviceGlyph defaultGlyphForCategory(String category) =>
    kCategoryDefaultGlyph[category] ?? DeviceGlyph.none;

/// The mark a template actually draws: the author's choice when there is
/// one, and the category's default when there is not.
///
/// ─────────────────────────────────────────────────────────────────────
/// ALWAYS READ THE EFFECTIVE VALUE. A renderer that reads
/// `TemplateBody.glyph` directly draws NOTHING for every template whose
/// author never opened the Appearance section, which is all 48 seeded
/// ones. This is the same trap `four-encoding-channels` records for
/// `effectiveDashPattern`: *"a renderer that reads `dashOverride`
/// directly draws a domain's families all alike, and a gate that checks
/// the raw field passes it."*
/// ─────────────────────────────────────────────────────────────────────
///
/// **A null `TemplateBody.glyph` is NOT a G4 unknown**, and the
/// distinction matters because the nullable field looks like one.
/// G4 governs facts about the physical world: a weight nobody measured
/// stays null and every rollup counts it. This is an OVERRIDE SLOT, the
/// shape `SignalFamilyDef.dashOverride` already has, and its absence
/// means *"inherit"* rather than *"nobody knows"*. Nothing counts it and
/// nothing prints `—` for it, because there is always a mark: the
/// category supplies one.
///
/// It also keeps CR-117 cheap. Absent stays absent through a round trip,
/// so no document already on disk gains a key and the four checked-in
/// starters do not regenerate. Writing the resolved value instead would
/// mean a file whose author chose `amplifier` in the Audio category
/// silently loses the *choice* the moment the category changes, which is
/// the same class of bug as storing a derived number.
DeviceGlyph effectiveGlyph(DeviceGlyph? glyph, String category) =>
    glyph ?? defaultGlyphForCategory(category);
