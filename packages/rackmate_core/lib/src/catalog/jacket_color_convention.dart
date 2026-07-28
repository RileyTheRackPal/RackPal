// THE SEED CABLE-COLOUR CONVENTION — data, not behaviour.
//
// Same directory, same shape and same contract as `buildSeedCatalog()`:
// pure Dart, no Flutter, returning a map that a document CONSTRUCTOR
// copies in. After that copy every entry is an ordinary map entry in the
// document — renameable, re-colourable, deletable, extendable with an
// eighth. Nothing in `lib/src/draw/`, in `rackmate_export` or in any DRC
// rule imports this file; its only callers are the two document-creation
// sites (`buildBlankDocument` and `StarterAuthor.newDocument`). A user
// who deletes all seven and authors their own five gets a project in
// which this const has no effect whatsoever, which is the test of
// whether something is really data.
//
// ==================================================================
// PROVENANCE (AC-052 / DR-002)
// ==================================================================
// ONE SHOP'S convention, supplied by the requesting integrator, 2026-07.
// THERE IS NO INDUSTRY STANDARD for category-cable jacket colour and
// this file must never be presented as one — a different integrator's
// yellow means something else. TIA-606 does standardise ADMINISTRATION
// LABEL colours; that is a different fact and must not be cited as
// support for these. If the application ever ships a legend calling
// these "standard", that is a defect.
//
// ==================================================================
// WHY THE HEX VALUES ARE NOT THE DOMAIN PALETTE'S
// ==================================================================
// These are authored print-ink approximations of real cable jackets, and
// they are DELIBERATELY NOT Okabe-Ito values. Reusing the signal-domain
// palette's hexes here would visually assert a relationship between a
// jacket colour and a signal domain that does not exist and that this
// whole design denies. Black is `#1A1A1A` rather than `#000000` for the
// same reason: the `pwr` domain draws a `#000000` line, and a reader who
// can conflate the two on one sheet is a reader the sheet has misled.
//
// WHITE AND BLACK STILL NEED A RENDERING RULE NOBODY OWNS YET: a
// near-white swatch on white paper is invisible without an outline. That
// belongs to the sheet consumer (T6.10), which does not exist. It is
// written-down debt, not a solved problem.
import 'package:rackmate_core/src/model/jacket_color.dart';
import 'package:rackmate_core/src/units/ids.dart';
import 'package:rackmate_core/src/units/rgb.dart';

/// The seven colours a new document starts with.
///
/// Seeded into NEW documents as ordinary editable data. Nothing in the
/// renderer, the exporter or the DRC reads this function.
Map<JacketColorId, JacketColorDef> buildDefaultJacketColorConvention() => {
  const JacketColorId('jc.yellow'): const JacketColorDef(
    displayName: 'Yellow',
    abbr: 'YEL',
    color: Rgb(0xEF, 0xC8, 0x1E),
    meaning: 'General data drops',
  ),
  const JacketColorId('jc.blue'): const JacketColorDef(
    displayName: 'Blue',
    abbr: 'BLU',
    color: Rgb(0x1F, 0x5F, 0xA8),
    meaning: 'Control — touchscreen / IR balun / RS-232 balun',
  ),
  const JacketColorId('jc.green'): const JacketColorDef(
    displayName: 'Green',
    abbr: 'GRN',
    color: Rgb(0x1E, 0x84, 0x49),
    meaning: 'A/V distribution drops',
  ),
  const JacketColorId('jc.grey'): const JacketColorDef(
    displayName: 'Grey',
    abbr: 'GRY',
    color: Rgb(0x9A, 0xA0, 0xA6),
    meaning: 'Wireless access point drops',
  ),
  const JacketColorId('jc.white'): const JacketColorDef(
    displayName: 'White',
    abbr: 'WHT',
    color: Rgb(0xF2, 0xF2, 0xEF),
    meaning: 'Camera / building bridge / satellite internet',
  ),
  const JacketColorId('jc.red'): const JacketColorDef(
    displayName: 'Red',
    abbr: 'RED',
    color: Rgb(0xC0, 0x39, 0x2B),
    meaning: 'External feeds, security and fire',
  ),
  // Aligns with `JacketRating.directBurial`, but is NOT the same fact and
  // must not be derived from it: the rating is what the cable is
  // certified for, this is what colour was on the reel. A black patch
  // cable carries no direct-burial rating at all.
  const JacketColorId('jc.black'): const JacketColorDef(
    displayName: 'Black',
    abbr: 'BLK',
    color: Rgb(0x1A, 0x1A, 0x1A),
    meaning: 'Direct burial and patch cables',
  ),
};
