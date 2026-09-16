// packages/rackpal_core/lib/src/derived/jacket_color_resolution.dart
//
// THE THREE DERIVED QUESTIONS about one run's jacket colour, answered
// from the two facts `Link` stores plus the project's convention map.
// Nothing here is persisted; nothing here formats; nothing here draws.
//
// ═════════════════════════════════════════════════════════════════════
// THE TWO STORED FACTS, WHICH MUST NOT BE COLLAPSED
// ═════════════════════════════════════════════════════════════════════
//  1. `Link.jacketColorId` — WHAT THE RUN IS. A reference to a named
//     convention entry: "this is a control drop". Semantic.
//  2. `Link.jacketColorPulledId` — WHAT WAS ACTUALLY PULLED, set only
//     when the cable in the wall is not the convention colour. Physical,
//     nullable, and null in the normal case.
//
// The requesting integrator asked for exactly this separation, in these
// words: a way "to differentiate the control wire as being yellow
// instead of blue for that run only, WHILE KEEPING THE KEYSTONES
// FOLLOWING THE NORMAL CONVENTION". A single stored colour cannot
// express that sentence at all.
//
// ═════════════════════════════════════════════════════════════════════
// WHY THERE IS NO STATUS ENUM
// ═════════════════════════════════════════════════════════════════════
// The obvious shape is `enum JacketColorState { unrecorded, normal,
// exception, unknownEntry }`. It is wrong, because the states OVERLAP: a
// run whose override id names a convention entry that has since been
// deleted is an EXCEPTION *and* carries an UNKNOWN entry simultaneously,
// and any single-valued enum has to lie about one of them. Four nullable
// fields plus three getters is non-overlapping and honest, and every
// consumer asks the question it actually has.
//
// ═════════════════════════════════════════════════════════════════════
// WHY THIS IS DERIVED AND NOT STORED
// ═════════════════════════════════════════════════════════════════════
// CR-107 deleted `StructureDrop` because two stored copies of one
// physical fact diverge inside a week. "Which colour is the keystone"
// is computable from what is already stored, so storing it would create
// exactly that second copy. There is no keystone entity to store it on
// in any case: the wall-plate end is a `StructureOrigin.terminationField`
// whose `TerminationType` may be `keystone`, and `Outlet` carries no
// colour at all.
//
// The consequence worth naming: `isException` is a PURE FUNCTION of the
// `Link` plus the map. There is no flag anybody can forget to set, and
// no state in which the fact exists but is unreachable. That is what
// makes the exception surface rather than hide.
//
// ═════════════════════════════════════════════════════════════════════
// PALETTE SEPARATION — STATED PLAINLY (CR-078 / PAL-1)
// ═════════════════════════════════════════════════════════════════════
// A jacket colour NEVER reaches a drawn wire's hue. This file lives in
// `derived/`, never in `draw/`, and its entire output is schedule text,
// label text, a keystone answer and a print swatch. Hue remains the
// signal domain's, via PAL-1's effective hue — eight Okabe-Ito values,
// chosen because they survive a colour-vision deficiency, which a shop's
// reel colours carry no guarantee of. `jacket_colour_is_not_hue_test.dart`
// gates all four drawing roots against every COLOUR-CARRYING name defined
// here — the types, the resolver and the `…ColorId` accessors. The bare
// getters `keystone` and `asBuilt` are deliberately not banned by name
// (both words are ordinary drawing vocabulary), and are unreachable from
// a drawing source without naming something that is.
import 'package:rackpal_core/src/model/jacket_color.dart';
import 'package:rackpal_core/src/model/link.dart';
import 'package:rackpal_core/src/units/ids.dart';

/// One run's jacket colour, fully resolved against a convention map.
///
/// FOUR STATES, NONE COLLAPSED — see [isException], [asBuilt] and
/// [keystone] for how each reads:
///
///  * **neither id set** — nobody has said. Every `Link` in the corpus
///    today. A schedule prints `—`. Not an error, and not a default.
///  * **convention only** — the normal case. `BLU · CONTROL`.
///  * **both set and differing** — THE EXCEPTION.
///    `BLU · CONTROL — PULLED YEL`.
///  * **override only, no convention** — a tech observed a yellow jacket
///    at prewire but nobody recorded what the run is for. KEPT, not
///    refused: promoting it to the convention field would assert "this
///    is a general data drop", which is a guess (G4), and refusing it
///    would make a CSV importer discard an observed physical fact.
final class ResolvedJacketColor {
  const ResolvedJacketColor({
    required this.conventionId,
    required this.convention,
    required this.pulledId,
    required this.pulled,
  });

  /// `Link.jacketColorId` exactly as stored — never substituted.
  final JacketColorId? conventionId;

  /// The entry [conventionId] names, or null when [conventionId] is
  /// unset OR names no entry in the map (a DANGLING id). Those two
  /// causes are distinguished by [hasUnknownEntry], never by inventing
  /// an entry to fill the hole.
  final JacketColorDef? convention;

  /// `Link.jacketColorPulledId` exactly as stored. Null means no
  /// exception was recorded, which is the normal case.
  final JacketColorId? pulledId;

  /// The entry [pulledId] names, or null when there is no exception OR
  /// the override id dangles.
  final JacketColorDef? pulled;

  /// QUESTION 2: IS THIS RUN AN EXCEPTION — was a colour pulled that is
  /// not the one the convention calls for?
  ///
  /// BOTH LIMBS MATTER, and they fail independently. The null check is
  /// the ordinary case. The `!=` limb guards a file this program did not
  /// write: `SetLinkPulledJacketColorCommand` normalises an override
  /// equal to the convention away on the WRITE path, but a hand-edited
  /// `.rppj` or a CSV import can carry one, and reporting a
  /// non-exception as an exception would inflate an exceptions-sheet
  /// count with rows that say `BLU — PULLED BLU`.
  ///
  /// Note what this does NOT require: a resolvable entry. An exception
  /// whose override id dangles is still an exception — something wrong
  /// went in the wall regardless of whether the entry naming it survives.
  bool get isException => pulledId != null && pulledId != conventionId;

  /// QUESTION 1: WHAT COLOUR WAS ACTUALLY PULLED — the override if one
  /// was recorded, else the convention. This is what a takeoff, a reel
  /// count and a photo-vs-drawing comparison want.
  JacketColorId? get asBuiltColorId => pulledId ?? conventionId;

  /// [asBuiltColorId]'s entry, or null when unset or dangling.
  JacketColorDef? get asBuilt => pulled ?? convention;

  /// QUESTION 3: WHAT COLOUR IS THE KEYSTONE — the CONVENTION, always.
  ///
  /// THE EXPRESSION DOES NOT MENTION [pulledId] AT ALL, AND THAT
  /// SYNTACTIC INDEPENDENCE IS THE DESIGN. The keystone is chosen weeks
  /// after the pull, out of the same box as every other control drop's,
  /// so it is routinely correct while the cable is not. Rewriting this
  /// to `pulledId ?? conventionId` must turn
  /// `jacket_color_resolution_test.dart`'s `keystone_follows_convention`
  /// group RED; if it does not, that group has stopped testing anything.
  JacketColorId? get keystoneColorId => conventionId;

  /// [keystoneColorId]'s entry. Same independence, same reason.
  JacketColorDef? get keystone => convention;

  /// True when either stored id names no entry in the convention map.
  ///
  /// The consumer's job is to COUNT this and show it as unknown, never
  /// to substitute a default colour — the same discipline
  /// `Rollup.unknownCount` already carries in `derived/totals.dart`, and
  /// the reason the codec deliberately does not resolve ids at decode
  /// time. Deleting a convention entry must never destroy the record of
  /// what was pulled.
  bool get hasUnknownEntry =>
      (conventionId != null && convention == null) ||
      (pulledId != null && pulled == null);
}

/// Resolves [link]'s two stored jacket-colour ids against [convention].
///
/// Pure and total. Takes the map rather than a `RackDocument` for the
/// same reason `computeRackRollups` takes its inputs loose: a test can
/// state a scenario in three lines, and this survives the arrival of a
/// real `DocumentController` untouched.
///
/// Unknown ids are NOT dropped and NOT substituted — they arrive in
/// [ResolvedJacketColor.conventionId]/[ResolvedJacketColor.pulledId]
/// intact with a null def beside them, and [ResolvedJacketColor
/// .hasUnknownEntry] says so.
ResolvedJacketColor resolveJacketColor(
  Link link,
  Map<JacketColorId, JacketColorDef> convention,
) {
  final conventionId = link.jacketColorId;
  final pulledId = link.jacketColorPulledId;
  return ResolvedJacketColor(
    conventionId: conventionId,
    convention: conventionId == null ? null : convention[conventionId],
    pulledId: pulledId,
    pulled: pulledId == null ? null : convention[pulledId],
  );
}

// ═════════════════════════════════════════════════════════════════════
// WHAT IS DELIBERATELY NOT HERE: `JacketColorRollup`
// ═════════════════════════════════════════════════════════════════════
// A `jacketColorRollup(links, convention)` returning six counts
// (`perConventionCount`, `exceptionCount`, `pulledOnlyCount`,
// `unrecordedCount`, `unknownEntryCount`, `exceptionLinkIds`) shipped in
// this file and was DELETED, because nothing outside its own four tests
// ever called it. Its doc comment defended itself with the wrong
// criterion — "it is a pure function of its arguments, so it is not the
// 'production field whose only writer was test code' smell" — but that
// smell is about who READS a value, and purity is irrelevant to it.
// `resolveJacketColor` has the same purity AND a documented read path;
// the rollup had four tests written by its only consumer, which was
// itself.
//
// Its named landing site made it worse rather than better: `T0.02
// EXCEPTIONS` is defined in docs/08 §3 as a DRC FINDINGS sheet ("every
// open Finding with rule ID, severity and locus"), `SheetRole` has three
// values and none of them is it, and a colour rollup is not a Finding.
// That is a category mismatch, not deferred work.
//
// It comes back WITH ITS CONSUMER — the exceptions sheet, or the
// Schedule tab's colour column — and reconstructing it is a fifteen-line
// loop over [resolveJacketColor], which is the part that is actually
// load-bearing and is fully tested. See docs/m1-implementation-log.md.
