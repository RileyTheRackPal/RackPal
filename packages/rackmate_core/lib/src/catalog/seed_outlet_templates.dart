// THE SHIPPED OUTLET TEMPLATES — CR-108's six, plus TIA-570-D Grade
// 1/2/3, seeded the way DR-010 §11.10.1 settled for the signal
// registries: a Dart master, not a JSON asset, because `rackmate_core`
// imports no Flutter and so cannot load an asset at all.
//
// ═════════════════════════════════════════════════════════════════════
// SEVENTEEN OUTLETS ALREADY POINT AT THESE IDS
// ═════════════════════════════════════════════════════════════════════
// `apps/rackmate/assets/starters/whole_house.rmpj` carries seventeen
// outlets whose `outletTemplateId` reads `outlet.tv_location`,
// `outlet.ap`, `outlet.camera`, `outlet.data_only` or
// `outlet.ceiling_speaker_pair`, and the same file's
// `registries.outletTemplates` is `{}`. Every one of those references
// has dangled since the fixture was authored. The ids below are
// therefore TRANSCRIBED FROM THE FIXTURE, not chosen: `outlet.keypad` is
// the only one this file names first, and it follows the pattern the
// other five already set.
//
// ═════════════════════════════════════════════════════════════════════
// WHERE EACH RECIPE COMES FROM
// ═════════════════════════════════════════════════════════════════════
// Canon §1673 names the six and stops. The contents were censused rather
// than invented, from the fixture's own drops (`whole_house.rmpj`, the
// only executable statement of what these templates produce), docs/07
// §4.3 and docs/01 §519/§521:
//
//   TV location            2 × Cat6 + 2 × RG6 quad   fixture ×2; docs/07
//                                                    §4.3 "four `Link`s"
//   AP                     1 × Cat6                  fixture ×2; docs/01
//                                                    §521 "one Cat6 per AP"
//   Keypad                 1 × 22/4                  docs/07 §4's table,
//                                                    §5.1's "keypad → 22_4"
//   Ceiling speaker pair   1 × 16/4                  fixture ×5; docs/01
//                                                    §521 "16/4 to every
//                                                    speaker pair"
//   Camera                 1 × Cat6                  fixture ×2; docs/07
//                                                    §4.3 "6x Cat6"
//   Data only              1 × Cat6                  fixture ×4
//
// ONE SOURCE DISAGREES AND IS NAMED RATHER THAN QUIETLY DROPPED.
// docs/02 §6.2's worked JSON is the only other place a template's
// contents are written out, and its `outlet.tv_location` differs in
// three ways: `media.cat6a_futp` for the twisted pair, and a FIFTH drop,
// `1 × media.cat5e` for `ctl.ir_emitter`. The coax agrees
// (`media.rg6_quad`). It is outvoted three to two — the fixture, docs/07
// §4.3's explicit "four `Link`s" and docs/01 §519 all say four drops on
// plain Cat6 — and taking Cat6A would put the seeded TV location at odds
// with `Living Room: 4x Cat6`, the first drop line the corpus prints.
// The IR run is not wrong (canon §2202 accepts exactly that Cat5e at a
// TV location); it is one integrator's habit, and a seeded template is
// the wrong place to make it everyone's.
//
// ═════════════════════════════════════════════════════════════════════
// THE TAGS ARE THE CORPUS'S OWN LABELS, AND THE CENSUS SETTLED TWO
// ═════════════════════════════════════════════════════════════════════
// DR-022 §11.21.4: a tag is authored beside the name, NEVER derived from
// it, because a tag truncated out of *"TV location"* is a guess printed
// on physical cable. So all six are taken from field labels the corpus
// actually prints. `TV`, `KEY` and `CAM` are DR-023's three worked
// examples (`LR-TV-1`, `MBR-KEY-2`, `EXT-CAM-4`); `AP` is docs/08's
// `KIT-AP-1`; `SPK` and `DATA` are docs/07 §4's own table (`LR-SPK-1`,
// `LR-DATA-1`).
//
// TWO SPELLINGS HAD TO BE ADJUDICATED, and both went to the more
// normative source:
//  * KEYPAD is `KEY`, not docs/08's `KIT-KP-1`/`GR-KP-4` and not
//    design-ux-schematic's `MBR-KY-2`. `MBR-KEY-2` is the form canon
//    §11.21 and docs/07 §8's label table both print, and canon wins over
//    a derived sheet. docs/08 is owed the edit.
//  * CEILING SPEAKER PAIR is `SPK`, and this one was a three-way split.
//    docs/07 §4's labelled table and design-ux-device-builder's both
//    print `LR-SPK-1` in the FIELD LABEL column, with `CLG` sitting in
//    the OUTLET column beside it — so docs/08's `GR-CLG-1` put an outlet
//    designation in the service segment. The whole-house fixture is the
//    third reading, `GR-AUD-1`, and it is the one this seed can rule out
//    on principle rather than on count: `AUD` is `audio.analog`'s DOMAIN
//    tag prefix, which makes it exactly the family-shaped answer DR-022
//    §11.21.5 rejected — a word that never varies and never becomes
//    anything else, stored forever by CR-048. docs/08 is owed its edit;
//    the fixture's labels are hand-authored rather than generated, so
//    they are a separate question from this one.
//
// THE THREE GRADES CARRY NO TAG, and that is G4 rather than an
// oversight. No `{ROOM_ABBR}-{SERVICE}-{SEQ}` label anywhere in the
// corpus renders a grade, so there is no attested word and inventing
// `G2` would print a guess on cable. `tag` is nullable and null is
// unknown (CR-114), so DR-023's chain falls through to step 3 and a
// Grade 2 outlet's drops label `LR-C6A-1` / `LR-RG6Q-1`: what they are,
// which is true, rather than a word nobody uses.
//
// ═════════════════════════════════════════════════════════════════════
// WHAT `service` MEANS HERE, WHICH IS NOT WHAT IT MEANS ON A LINK
// ═════════════════════════════════════════════════════════════════════
// The template's `service` is INTENT — what this drop is for. The Link
// created from it starts at `structure.undetermined` regardless, because
// `AddHomeRunCommand` writes that unconditionally and docs/07 §4.1 says
// why: at rough-in a Cat6 is just a Cat6. docs/02 §6.2 prints both facts
// in one file — `outlet.tv_location`'s drops say `net.ethernet` and
// `rf.catv`, and `W001.services[0].signalFamily` says
// `structure.undetermined`. Nothing consumes this field yet; the
// instantiating gesture (`+ Add outlet ▾`, docs/07 §4.3) is a later
// task, and when it lands it must NOT copy `service` onto the Link.
//
// KEYPAD'S SERVICE IS `structure.undetermined`, AND IT IS THE FINDING.
// docs/07 §4's table prints `Keypad` in its SERVICE column, and there is
// no keypad family among the 55: a keypad speaks Cresnet, Lutron QS,
// DALI, KNX, RS-485 or a contact closure depending on a control system
// chosen months after the 22/4 is pulled. Naming one here would assert
// the job's control platform from a rough-in preset.
//
// AP, CAMERA AND DATA ONLY ARE THE SAME RECIPE, and that is the fact
// rather than a copy-paste. One Cat6 to a switch is one Cat6 to a
// switch; what differs is the name, the tag, and which location fields
// the inspector demands (AC-034/m24 — a ceiling AP is never asked for a
// compass direction). The last of those has nowhere to live on this
// class yet and is named in the gaps below.
//
// `net.poe` IS THE ARGUABLY TRUER INTENT FOR AP AND CAMERA, AND IS NOT
// USED. The family exists ("PoE / PoE+ / PoE++") and both devices are
// powered over the run in practically every job. But no source in the
// corpus states it for a TEMPLATE: the fixture writes `net.ethernet` on
// all five of its AP and camera drops, and docs/08's "PoE Class 4" is an
// auto-note on one Pull Sheet row whose TYPE chip prints the DOMAIN
// (`▬ NET`) and so cannot discriminate the two families. Transcription
// beats inference here for the same reason it does on Keypad above, and
// picking `net.poe` on domain knowledge alone would be the one habit
// this file's whole header argues against.
//
// ═════════════════════════════════════════════════════════════════════
// WHAT IS DELIBERATELY ABSENT, SO IT READS AS A GAP AND NOT AN OVERSIGHT
// ═════════════════════════════════════════════════════════════════════
//  * NO LOCATION-FIELD REQUIREMENTS. AC-034/m24 makes the template drive
//    which fields the inspector demands — `mountSurface: ceiling` for a
//    speaker pair, never a wall compass direction. That is a UI contract
//    with no model field today.
//  * NO LIBRARY FLOW. CR-108 makes user-defined templates first-class and
//    the registries are ordinary editable stored data after the seed copy
//    (docs/03 §5.6), but which surface edits them is unsettled (DR-024
//    §11.23.4). This ships the master, not an editor for it.
//  * `Registries.cableSpecs` STAYS EMPTY. Still out of DR-010's scope,
//    and still nothing to transcribe.
//
// `tia570Grade` WAS ON THIS LIST AND IS NOT ANY MORE. M3-C/4 shipped the
// three grade presets with no way to stamp the very tag they exist to
// carry, because `OutletTemplate` had no field for it; DR-024 §11.23.2
// added one, and the three below now carry the same string the
// whole-house fixture sets by hand, `'TIA-570-D Grade 2'`. The six named
// templates leave it null, because *TV location* cites no standard and
// writing one would put a citation in a document nobody made.

import 'package:rackmate_core/src/model/enums.dart' show TerminationType;
import 'package:rackmate_core/src/model/outlet.dart';
import 'package:rackmate_core/src/units/ids.dart';

/// One drop within a recipe, positional in the corpus's own column order
/// — media, service, count — so a reader can diff this file against
/// docs/02 §6.2's worked JSON without reordering anything.
OutletDrop _drop(
  String media,
  String service, [
  int count = 1,
  TerminationType? termination,
]) => OutletDrop(
  media: MediaTypeId(media),
  service: service,
  count: count,
  termination: termination,
);

/// How each seeded medium's FIELD end is finished (DR-044 §11.43.3).
///
/// ═════════════════════════════════════════════════════════════════════
/// EVERY ONE OF THESE FIVE WAS STATED BY THE USER, NOT INFERRED
/// ═════════════════════════════════════════════════════════════════════
/// The file's own header argues that transcription beats inference, and
/// this table is that argument applied to a fact the corpus did not
/// contain: the user was asked per medium rather than offered a set.
///
/// `punchdown` FOR TWISTED PAIR IS THE ROW THAT PROVES IT WAS WORTH
/// ASKING. `keystone` was the recommended answer and the shop's answer
/// was `punchdown`. Face-on the two are the same object (DR-007
/// §11.7.9 B) so no drawing changes, and the TERMINATION SCHEDULE does:
/// had the recommendation been taken, nothing would have looked wrong
/// and one printed column would have been quietly false on every data
/// drop in every job.
///
/// `media.16_4` WAS NOT ASKED AGAIN. §11.7.2's supersession already
/// rests on the user's *"We use single post keystones, one per
/// conductor"*, so a 16/4 ceiling pair is four binding posts and the
/// answer was on the record before the question came up.
///
/// `media.22_4` IS A EUROBLOCK AND THEREFORE ZERO CELLS (§11.43.4). The
/// keypad fills the gang itself; a plate sized to give it a keystone as
/// well would be one cell too big on every keypad drop in a house.
const TerminationType _punchdown = TerminationType.punchdown;
const TerminationType _fBarrel = TerminationType.fBarrel;
const TerminationType _euroblock = TerminationType.euroblock;
const TerminationType _bindingPost = TerminationType.bindingPost;
const TerminationType _keystone = TerminationType.keystone;

/// One shipped template. [tag] is the `{SERVICE}` segment DR-022 ruled
/// on; null means UNKNOWN and falls through to DR-023's step 3.
/// [grade] is the standards citation stamped on every outlet the
/// template creates (DR-024), null on the six that make no such claim.
OutletTemplate _template(
  String id,
  String name,
  String? tag,
  List<OutletDrop> drops, {
  String? grade,
}) => OutletTemplate(
  id: id,
  name: name,
  tag: tag,
  tia570Grade: grade,
  drops: drops,
);

const String _cat6 = 'media.cat6';
const String _cat6a = 'media.cat6a_futp';
const String _rg6q = 'media.rg6_quad';
const String _ethernet = 'net.ethernet';
const String _catv = 'rf.catv';
const String _undetermined = 'structure.undetermined';

/// The nine shipped outlet templates (CR-108): six named recipes, then
/// the three TIA-570-D grades.
Map<String, OutletTemplate> buildSeedOutletTemplates() {
  final all = <OutletTemplate>[
    // --- the six CR-108 names, in canon §1673's own order -------------
    _template('outlet.tv_location', 'TV location', 'TV', [
      _drop(_cat6, _ethernet, 2, _punchdown),
      _drop(_rg6q, _catv, 2, _fBarrel),
    ]),
    _template('outlet.ap', 'AP', 'AP', [
      _drop(_cat6, _ethernet, 1, _punchdown),
    ]),
    _template('outlet.keypad', 'Keypad', 'KEY', [
      _drop('media.22_4', _undetermined, 1, _euroblock),
    ]),
    _template('outlet.ceiling_speaker_pair', 'Ceiling speaker pair', 'SPK', [
      // ONE cable, not two. A 16/4 carries both channels of the pair on
      // four conductors; docs/08's `GR-CLG-1` row says so in its own
      // note, "1 `Link`, 2 `Conductor`s".
      _drop('media.16_4', 'audio.speaker_lowz', 1, _bindingPost),
    ]),
    _template('outlet.camera', 'Camera', 'CAM', [
      _drop(_cat6, _ethernet, 1, _punchdown),
    ]),
    _template('outlet.data_only', 'Data only', 'DATA', [
      _drop(_cat6, _ethernet, 1, _punchdown),
    ]),

    // --- the three TIA-570-D grades (docs/07 §1's table) --------------
    //
    // TRANSCRIBED, INCLUDING THE PART THAT READS ODDLY. docs/07 §1 gives
    // Grade 3 a LOWER twisted-pair grade and FEWER coax than Grade 2
    // (2 × Cat6 and 1, against 2 × Cat6A and 2), which is not how the
    // published standard stacks them. The corpus is the source here and
    // a silent "correction" would make this file disagree with the
    // document it claims to transcribe. Flagged for docs/07 rather than
    // fixed in code.
    //
    // OPTIONAL FIBRE IS OMITTED, REQUIRED FIBRE IS PRESENT. Grade 1 and
    // Grade 2 mark fibre "optional", and a preset that ships an optional
    // item asserts it on every outlet created from it. Grade 3 marks it
    // **required**, so it is there.
    _template(
      'outlet.tia570d_grade1',
      'TIA-570-D Grade 1',
      null,
      [
        _drop(_cat6a, _ethernet, 1, _punchdown),
        _drop(_rg6q, _catv, 1, _fBarrel),
      ],
      grade: 'TIA-570-D Grade 1',
    ),
    _template(
      'outlet.tia570d_grade2',
      'TIA-570-D Grade 2',
      null,
      [
        _drop(_cat6a, _ethernet, 2, _punchdown),
        _drop(_rg6q, _catv, 2, _fBarrel),
      ],
      grade: 'TIA-570-D Grade 2',
    ),
    _template(
      'outlet.tia570d_grade3',
      'TIA-570-D Grade 3',
      null,
      [
        _drop(_cat6, _ethernet, 2, _punchdown),
        _drop(_rg6q, _catv, 1, _fBarrel),
        // "2-fibre" is two strands in ONE jacket, pulled once, so it is
        // one drop and not two: `Link` is the cable (CR-107, "one cable,
        // one row, one length, one certificate"), and strand count lives
        // on `Conductor` the way the speaker pair's does.
        _drop('media.os2', 'net.fiber_sm', 1, _keystone),
      ],
      grade: 'TIA-570-D Grade 3',
    ),
  ];
  return {for (final t in all) t.id: t};
}
