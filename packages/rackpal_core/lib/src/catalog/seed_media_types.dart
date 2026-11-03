// THE SHIPPED CABLE TYPES — canon §6.5's 34 rows, which are 38 media
// types, seeded the way DR-010 §11.10.1 settled for the signal
// registries: a Dart master, not a JSON asset, because `rackpal_core`
// imports no Flutter and so cannot load an asset at all.
//
// ═════════════════════════════════════════════════════════════════════
// 34 ROWS, 38 IDS, AND THE DIFFERENCE IS LOAD-BEARING
// ═════════════════════════════════════════════════════════════════════
// Four of canon's rows carry two ids in one line: `media.14_2 ·
// media.14_4`, `media.22_2 · media.22_4`, `media.om3 · media.om4`,
// `media.conduit_emt · media.conduit_ent`. They are split here rather
// than folded, and docs/07 §5.1 says why in its own words: "14 AWG gets
// its own targets rather than folding onto the 16 AWG ones: mapping
// `14/4` to a 16 AWG media type changes the gauge and the footage
// rollup, and `media.14_2` / `media.14_4` exist in the registry
// precisely so it does not have to."
//
// A PAIRED ROW'S DISPLAY NAME IS SPLIT ON THE SAME `·`, distributing the
// trailing noun: "14/2 · 14/4 speaker" becomes "14/2 speaker" and "14/4
// speaker", "Fibre OM3 · OM4 multimode" becomes "Fibre OM3 multimode"
// and "Fibre OM4 multimode". Stated as a rule rather than decided per
// row, the way `_family`'s Dir/Topo reading is.
//
// ═════════════════════════════════════════════════════════════════════
// WHAT `maxChannel` IS FILLED FROM, AND WHY IT IS MOSTLY ABSENT
// ═════════════════════════════════════════════════════════════════════
// Canon's `Max channel` column is prose, and most of it is hedged: `~150
// m`, `100 m+`, `gauge/length table`, `hundreds of feet`, `long`,
// `short`, `2.1: 3–4.5 m · 2.0: ~7.5 m`, `915 m data · 333 ft at 20 W`.
// The rule applied is the one `apps/rackpal/tool/starters/
// whole_house.dart` already states at its own registration: FILLED ONLY
// WHERE A STANDARD FIXES IT, left null everywhere else rather than
// estimated.
//
// So seven of the 38 carry a length and thirty-one do not, and those
// thirty-one absences are G4 working rather than thirty-one gaps: `~150
// m` rounded into `Len(150_000 * nmPerMillimetre)` would print an exact
// figure onto a termination schedule an installer buys cable from, and
// the tilde — the entire content of the hedge — would be gone. Null is
// unknown (CR-114); a rollup counts it and says so.
//
// The seven: TIA-568's 100 m balanced-twisted-pair channel (the four
// Cat grades), AES3's 100 m, ANSI E1.11's 1200 m for DMX512/RS-485, and
// KNX TP1's 1000 m. `media.os2` is the near miss — `10–40 km` is a range
// across singlemode optics, not a figure a standard fixes.
//
// ═════════════════════════════════════════════════════════════════════
// ALIASES ARE TRANSCRIBED FROM docs/07 §5.1, NOT INVENTED
// ═════════════════════════════════════════════════════════════════════
// 13 of the 38 carry synonyms and 25 carry none, because docs/07 §5.1's
// block lists exactly 13 targets. `media.cat6_futp` gets none even
// though `media.cat6a_futp` does, and `media.conduit_emt` gets none even
// though `media.conduit_ent` does: that is what the source says, and
// filling the gaps by symmetry would be invention wearing transcription
// as a costume. RJ-009 is the escape hatch the corpus already chose for
// a spelling nobody anticipated — an unmatched import value creates a
// new user media type with a confirmation chip, never a rejected row.
//
// ONE STALE SENTENCE IN THE SOURCE, DECLARED. docs/07 §5.1 closes with
// "Every target above resolves in `assets/catalog/registries.json`".
// THAT FILE HAS NEVER EXISTED — `seed_registries.dart`'s header
// establishes this at length — and DR-010 §11.10.1 settled the master as
// seeded Dart. This file is what makes that sentence true; the sentence
// itself is owed a correction.
//
// ═════════════════════════════════════════════════════════════════════
// WHAT IS DELIBERATELY ABSENT, SO IT READS AS A GAP AND NOT AN OVERSIGHT
// ═════════════════════════════════════════════════════════════════════
//  * `jacketOptions` IS EMPTY ON ALL 38. Canon §6.5 names
//    `availableJackets[]` in its field list and gives it NO COLUMN, so
//    there is nothing to transcribe. The four `JacketRating` sets the
//    whole-house starter used to carry were authored for that fixture,
//    not sourced, and nothing in the codebase reads the field.
//  * `isPathwayOnly` IS NOW SEEDED on `media.conduit_emt`,
//    `media.conduit_ent` and `media.pull_string` (M3-E/1). It was held
//    out through #149 for one reason, stated here at the time: the
//    flag's whole purpose is that such a media type creates a `Pathway`
//    instead of a `Link`, and NOTHING IN THIS PRODUCT COULD CREATE A
//    `Pathway` AT ALL, so seeding it alone would have marked three types
//    with a fact no code could act on. M3-E/4 (`08ad5aa`) built the
//    creation path and the reason lapsed. **Reading the flag is the
//    OTHER half and is not done here**: the drop line and the matrix
//    still make `Link`s out of conduit, which docs/07 §5.2 shows the
//    importer must not do. Seeding first is deliberate rather than
//    partial — the registry fact is what a planner will read, and a
//    planner branching on a flag no medium carries is untestable.
//  * NO `conductorCount`, `pairCount`, `gaugeAwg`, `impedanceOhms`,
//    `shielded`, `minBendRadius`, `outerDiameter` or `supports`. Canon
//    §6.5 has columns for the first five and nothing reads any of them;
//    DR-010 §11.10.4's rule is to add what something needs and keep the
//    rest out. `supports` is the interesting one — it would let a family
//    name its typical cable, which is the second half of what
//    `kUnstatedMedia` is waiting on.

import 'package:rackpal_core/src/model/registries.dart';
import 'package:rackpal_core/src/units/ids.dart';
import 'package:rackpal_core/src/units/len.dart';

/// One §6.5 row, positional and in the table's own column order — id,
/// display name, tag — so a reader can diff the two side by side.
MediaTypeDef _media(
  String id,
  String displayName,
  String shortTag, {
  List<String> aliases = const [],
  Len? maxChannel,
  bool isPathwayOnly = false,
}) => MediaTypeDef(
  id: MediaTypeId(id),
  displayName: displayName,
  shortTag: shortTag,
  aliases: aliases,
  maxRunLengthPassive: maxChannel,
  isPathwayOnly: isPathwayOnly,
);

const Len _m100 = Len(100 * 1000 * Len.nmPerMillimetre);
const Len _m1000 = Len(1000 * 1000 * Len.nmPerMillimetre);
const Len _m1200 = Len(1200 * 1000 * Len.nmPerMillimetre);

/// The 38 shipped media types (canon §6.5), in the table's row order.
Map<MediaTypeId, MediaTypeDef> buildSeedMediaTypes() {
  final defs = <MediaTypeDef>[
    // --- balanced twisted pair ---------------------------------------
    _media(
      'media.cat5e',
      'Cat5e UTP',
      'C5E',
      aliases: const ['cat5e', 'c5e', 'cat5'],
      maxChannel: _m100,
    ),
    _media(
      'media.cat6',
      'Cat6 UTP',
      'C6',
      aliases: const ['cat6', 'cat-6', 'c6', 'cat6 utp'],
      maxChannel: _m100,
    ),
    _media('media.cat6_futp', 'Cat6 F/UTP', 'C6S', maxChannel: _m100),
    _media(
      'media.cat6a_futp',
      'Cat6a F/UTP',
      'C6A',
      aliases: const ['cat6a', 'c6a', 'f/utp'],
      maxChannel: _m100,
    ),

    // --- coaxial ------------------------------------------------------
    _media('media.rg6', 'RG6', 'RG6', aliases: const ['rg6', 'rg-6', 'coax']),
    _media(
      'media.rg6_quad',
      'RG6 quad-shield',
      'RG6Q',
      aliases: const ['rg6q', 'quad shield'],
    ),
    _media('media.rg59', 'RG59', 'RG59'),
    _media('media.rg11', 'RG11', 'RG11'),
    _media(
      'media.coax_video_75',
      'Precision 75 Ω video coax (1694A class)',
      'V75',
    ),

    // --- shielded pair, audio and control ----------------------------
    _media('media.mic_stp', 'Mic / line shielded twisted pair', 'STP2'),
    _media('media.aes_110', '110 Ω AES/DMX cable', 'Z110', maxChannel: _m100),
    _media(
      'media.dmx_120',
      '120 Ω DMX / RS-485 cable',
      'Z120',
      maxChannel: _m1200,
    ),

    // --- speaker ------------------------------------------------------
    _media(
      'media.16_2',
      '16/2 speaker',
      '16/2',
      aliases: const ['16/2', '16-2', 'spkr 16/2'],
    ),
    _media(
      'media.16_4',
      '16/4 speaker',
      '16/4',
      aliases: const ['16/4', '16-4'],
    ),
    _media(
      'media.14_2',
      '14/2 speaker',
      '14/2',
      aliases: const ['14/2', '14-2'],
    ),
    _media(
      'media.14_4',
      '14/4 speaker',
      '14/4',
      aliases: const ['14/4', '14-4'],
    ),
    _media('media.12_2', '12/2 speaker', '12/2'),
    _media('media.18_2_cv', '18/2 constant-voltage', '18/2'),

    // --- low-voltage control -----------------------------------------
    _media('media.22_2', '22/2 control', '22/2', aliases: const ['22/2']),
    _media(
      'media.22_4',
      '22/4 control',
      '22/4',
      aliases: const ['22/4', 'control', 'keypad'],
    ),
    _media(
      'media.cresnet_18_22',
      'Cresnet (18 AWG power + 22 AWG data)',
      'CN',
    ),
    _media('media.knx_tp1', 'KNX TP1 bus cable', 'KNX', maxChannel: _m1000),
    _media('media.dali_2c', 'DALI 2-conductor (mains-rated)', 'DALI'),

    // --- video assemblies ---------------------------------------------
    _media('media.hdmi_passive', 'HDMI, passive', 'HDMI'),
    _media('media.hdmi_active', 'HDMI, active copper', 'HDMIA'),
    _media('media.hdmi_aoc', 'HDMI, active optical (AOC)', 'AOC'),
    _media('media.dp_cable', 'DisplayPort cable', 'DP'),
    _media('media.usbc_cable', 'USB-C cable', 'USBC'),

    // --- optical ------------------------------------------------------
    _media('media.om3', 'Fibre OM3 multimode', 'OM3'),
    _media('media.om4', 'Fibre OM4 multimode', 'OM4'),
    _media(
      'media.os2',
      'Fibre OS2 singlemode',
      'OS2',
      aliases: const ['os2', 'smf', 'single mode'],
    ),
    _media('media.pof_toslink', 'Plastic optical fibre (TOSLINK)', 'POF'),

    // --- power and bonding --------------------------------------------
    _media('media.so_cord', 'SO / SJ power cord', 'SO'),
    _media('media.iec_cordage', 'IEC rated cordage', 'IEC'),
    _media('media.bonding_6awg', 'Bonding conductor', 'GND'),

    // --- pathway only (CR-109) ----------------------------------------
    // THE THREE `isPathwayOnly` TYPES (CR-109), which canon §6.5 marks
    // and which nothing could act on until M3-E/4 gave the product a way
    // to create a `Pathway`. A medium with the flag creates one, never a
    // `Link` and never a `Port`.
    _media('media.conduit_emt', 'EMT conduit', 'EMT', isPathwayOnly: true),
    _media(
      'media.conduit_ent',
      'ENT (smurf tube)',
      'ENT',
      aliases: const ['conduit', 'smurf', 'ent'],
      isPathwayOnly: true,
    ),
    _media('media.pull_string', 'Pull string', 'PULL', isPathwayOnly: true),
  ];
  return {for (final d in defs) d.id: d};
}
