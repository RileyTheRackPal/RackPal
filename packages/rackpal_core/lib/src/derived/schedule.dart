// packages/rackpal_core/lib/src/derived/schedule.dart — pure Dart.
//
// docs/08-pdf-export.md §3 — THE WIRING SCHEDULE. "The schedule is the
// deliverable; the drawing is the receipt" (G1), which is why this is the
// one derivation the Schedule tab AND the T6.10/T6.15 sheet builders both
// read. Computes; never draws.
//
// ═════════════════════════════════════════════════════════════════════
// ONE DERIVATION, TWO VIEWS — THE CONSTRAINT THAT SHAPES THIS FILE
// ═════════════════════════════════════════════════════════════════════
// §3.1: the Pull Sheet and the Termination Schedule are "two presets of
// one derivation — same query, same row model, different projection".
// So there is exactly ONE row builder ([buildSchedule]) and exactly ONE
// projector ([buildScheduleView]); a preset contributes DATA — a filter,
// a sort, a grouping and a column list — and no code of its own. The
// failure this shape exists to prevent is the obvious one: two table
// builders that agree on the day they are written, and disagree about
// what a rack label is by the end of the milestone. `T6.10` and `T6.15`
// describe the SAME cable to two different readers, and a discrepancy
// between them is a callback.
//
// The corollary is that a cell's text is computed ONCE, in
// [ScheduleEntry.cell], and both presets ask for it by [ScheduleColumnId].
// A column that appears on both sheets — `CABLE ID`, `TYPE`,
// `FIELD LABEL`, `RACK LABEL`, `MEDIA` — is therefore the same string on
// both by construction rather than by review.
//
// ═════════════════════════════════════════════════════════════════════
// READ THE CLASS THROUGH `effectiveLinkClassOf`, NEVER `Link.linkClass`
// ═════════════════════════════════════════════════════════════════════
// DR-008 §11.8.2. `Link.linkClass` is the STORED value and is inert
// unless `Link.linkClassLocked` — reading it directly shows a default
// nobody chose. `linkClassOf` is the classifier and ignores the user's
// override. [effectiveLinkClassOf] is the one a consumer asks, and this
// file is its first real consumer.
//
// It returns `null` for UNDETERMINED, and that is not a hole to be
// plugged. Jumpers are excluded from the Pull Sheet by default, so:
//
//   * defaulting an undetermined link to `fieldCable` puts it on a sheet
//     an installer works from, asserting a pull nobody established;
//   * defaulting it to `jumper` deletes a real pull from that sheet.
//
// Both are worse than saying so. Undetermined rows land in their own
// trailing [kUndeterminedClassGroupTitle] group on BOTH presets and are
// counted in [ScheduleView.undeterminedClassCount] — the same shape
// `equipment_list.dart` uses for its trailing `NOT IN A RACK` group, and
// the same discipline `Rollup.unknownCount` carries in `totals.dart`
// (G4).
//
// `linkClassDisagreementOf` is surfaced too, per row and as a count.
// §11.8.2 requires the disagreement to stay VISIBLE; a schedule is where
// it bites, because a link a person classed `jumper` before the document
// moved under them silently stays off the Pull Sheet forever.
//
// ═════════════════════════════════════════════════════════════════════
// NOTHING IS SILENTLY DROPPED
// ═════════════════════════════════════════════════════════════════════
// [buildSchedule] emits exactly one [ScheduleEntry] per `Link` in the
// document — including links with no conductors, links naming ports that
// do not exist, and links that no preset will show. A preset then
// EXCLUDES rows, and every exclusion is counted by reason on
// [ScheduleView] (see [ScheduleExclusions]). A schedule that quietly
// holds fewer cables than the document is the failure mode; a schedule
// that says "27 rows · 4 jumpers hidden" is not.
//
// ═════════════════════════════════════════════════════════════════════
// WHAT IS DELIBERATELY NOT DERIVED — AND WHY EACH IS A GAP, NOT A BUG
// ═════════════════════════════════════════════════════════════════════
//  * **T568A/B WAS HERE AND IS NOT ANY MORE** (DR-180 §11.179, `#80`).
//    This bullet read "§3.3's `TERM` column wants it and NOTHING IN THE
//    MODEL STATES IT", and it was right for four milestones. The model
//    states it now: a project-wide `ProjectSettings.wiringStandard` with
//    an optional `Link.wiringStandard` override, and
//    [ScheduleEntry.wiringStandard] carries what
//    `effectiveWiringStandard` resolved for this cable.
//    WHAT DID NOT CHANGE is the part that made the gap a gap: the
//    corpus's own worked example overloads a DIFFERENT field with it —
//    docs/02-data-model.md:1377 and `byte_roundtrip_test.dart` both store
//    `"colorCode": "T568B"` on a `Conductor`, whose doc comment says the
//    field is the pair colour inside the sheath, and whose §3.3 column is
//    `CONDUCTOR / NOTES`. This file still prints `Conductor.colorCode`
//    EXACTLY AS STORED in the conductor column and still never re-reads a
//    stored string to decide it means a wiring standard. The `TERM`
//    column now has a real field to print, so guessing from the shape of
//    a value is not merely forbidden (G4) but unnecessary.
//  * **`SignalFamilyDef.shortTag`.** §3.2's `TYPE` column asks for
//    "domain tag + family `shortTag`". THE FIELD NOW EXISTS — DR-010
//    §11.10.3 added it, and the seeded registry populates it on all 55
//    families — but [ScheduleEntry.typeCell] still prints the domain's
//    `tagPrefix` with the family's `displayName`, because switching it
//    is a change to what the schedule RENDERS and belongs with the rest
//    of the tag-pill work (AC-054, M2-D), not to the ruling that added
//    the field. It is nullable, so the switch also owes a fallback for
//    a family decoded from a document written before the key existed.
//    The fall back to the raw `SignalFamilyId` when the registry does
//    not resolve stays either way — never an abbreviation this file
//    invented.
//  * **§3.8's generated notes** — `NOT ETHERNET`, `VERIFY POLARITY`, the
//    null-modem pin map. Those come from a rules pass over the connector
//    and family model that does not exist. The notes the model DOES state
//    are derived ([ScheduleEntry.derivedNotes], not counted here because
//    this said "three" until it held six); the rest are absent rather
//    than approximated.
//  * **Pagination, page geometry, the chip's dash and hue.** §3.5/§3.7
//    are rendering. [ScheduleColumn.widthPt] carries §3.2/§3.3's exact
//    point widths because they are the shared column contract, but no
//    font is named here: the export embeds Jost Regular alone
//    (`kSheetFont` in `sheet_frame.dart`), `RackMono` is bundled for the
//    screen only, and `RackBody`/`RackCond` exist only as role names, so
//    naming a face the sheet cannot draw would be the same fabrication.

import 'package:meta/meta.dart';
import 'package:rackpal_core/src/commands/bind_endpoint_command.dart'
    show panelPositionToken;
import 'package:rackpal_core/src/derived/device_loads.dart'
    show bodyFor, hostRackOf;
import 'package:rackpal_core/src/derived/equipment_list.dart'
    show kUnknownCell, kUnplacedGroupTitle;
import 'package:rackpal_core/src/derived/inline_adapters.dart';
import 'package:rackpal_core/src/derived/jacket_color_resolution.dart';
import 'package:rackpal_core/src/derived/link_class.dart';
import 'package:rackpal_core/src/derived/plan_length.dart';
import 'package:rackpal_core/src/derived/totals.dart' show Rollup;
import 'package:rackpal_core/src/derived/wiring_standard.dart';
import 'package:rackpal_core/src/model/conductor.dart';
import 'package:rackpal_core/src/model/device_instance.dart';
import 'package:rackpal_core/src/model/enums.dart'
    show LifecycleStatus, TerminationType, UnitSystem, WiringStandard;
import 'package:rackpal_core/src/model/link.dart';
import 'package:rackpal_core/src/model/location.dart';
import 'package:rackpal_core/src/model/outlet.dart';
import 'package:rackpal_core/src/model/placement.dart';
import 'package:rackpal_core/src/model/port.dart';
import 'package:rackpal_core/src/model/rack_document.dart';
import 'package:rackpal_core/src/model/registries.dart';
import 'package:rackpal_core/src/units/ids.dart';
import 'package:rackpal_core/src/units/len.dart';

// ═════════════════════════════════════════════════════════════════════
// ENDS
// ═════════════════════════════════════════════════════════════════════

/// What one end of a cable turned out to be.
///
/// FIVE VALUES, NOT `Uuid?`. "Lands on a port in a rack", "lands on a
/// port that is not in a rack" and "names a port this document does not
/// contain" are three different facts, and only the third is a defect.
/// Collapsing them loses exactly the distinction `linkClassOf` was
/// written to preserve.
enum ScheduleEndKind {
  /// A `PortEndpoint` whose device's host chain reaches a `Rack`.
  rackPort,

  /// A `PortEndpoint` on a device that is off-rack, staged, or on a shelf
  /// chain that never lands. Resolved — and not in a rack.
  unrackedPort,

  /// A `PortEndpoint` naming a port (or a device) this document does not
  /// hold. Something is wrong; nothing here guesses what.
  unresolvedPort,

  /// A `PlaceEndpoint` — the field. A home run to "the projector shelf,
  /// beam 3" is this, and it is an answer rather than a failure.
  field,

  /// An `OpenEndpoint` — a coil terminated nowhere. It still schedules,
  /// prints and carries a `W` number (AC-018).
  open,

  /// The link has no `Conductor`s at all, so it has no ends. `CR-014`
  /// fixes a conductor at two ends; it does not oblige a link to have a
  /// conductor, and a hand-edited file can carry one that does not.
  none,
}

/// One end of one row, resolved against the document.
///
/// The SAME type for both ends and both presets. §3.1 requires the
/// location and both labels "on both ends"; a type that can only describe
/// a rack end forces the field end to be described by a second, quietly
/// different set of fields, which is how the two sheets stop agreeing.
@immutable
final class ScheduleEnd {
  const ScheduleEnd({
    required this.kind,
    this.rackId,
    this.rackDesignator,
    this.ruIndex,
    this.face,
    this.deviceId,
    this.deviceDesignator,
    this.portId,
    this.portDesignator,
    this.portPositionToken,
    this.portLabel,
    this.locationId,
    this.roomName,
    this.description = '',
  });

  /// The end with no conductor behind it. Shared rather than
  /// reconstructed so `identical` comparisons in a renderer are stable.
  static const ScheduleEnd none = ScheduleEnd(kind: ScheduleEndKind.none);

  final ScheduleEndKind kind;

  /// The rack this end lands in, via `hostRackOf` — so a component on a
  /// rack shelf resolves to the rack under the shelf, not to nothing.
  final Uuid? rackId;
  final String? rackDesignator;

  /// Lowest occupied U, 1-based bottom-origin (CR-025), or null when the
  /// device is not rail-mounted. NOT re-derived per face: this is the
  /// stored `RailPlacement.ruIndex`, which is what a tech reads off the
  /// rails.
  final int? ruIndex;

  /// The rails the device is bolted to. Null when it is not rail-placed.
  final Face? face;

  final Uuid? deviceId;

  /// `SW-1`, `PP-1` — and, for §3.6's `rack, panel, port` sort, THE
  /// PANEL. The model has no `Panel` entity: a patch panel is a
  /// `DeviceInstance` like any other, so "one panel at a time" is
  /// "one device at a time" and this is the key it sorts on.
  final String? deviceDesignator;

  final Uuid? portId;

  /// `J09`, `A03`. **What this product ALLOCATED, and identity rather
  /// than rendering**: it is what `PORT` sorts on and what a `Port`
  /// carries (CR-042), and since DR-054 it is no longer what the column
  /// prints. See [portCell] and [portPositionToken].
  ///
  /// THIS COMMENT USED TO SAY "on a punchdown this IS §3.3's punch
  /// position, the model carries no second field for it, and inventing
  /// one would give the sheet two answers for one physical hole." The
  /// sheet HAD two answers for one hole, and the second field was not
  /// invented, it was already there: `PortDef.label` is the number
  /// silkscreened on the part, and `RACK LBL` has rendered it since
  /// DR-040 §11.39.8 while this column rendered the allocated one.
  final String? portDesignator;

  /// The number printed ON THE PART, `01` on a patch panel (DR-054
  /// §11.53.3, via `panelPositionToken`).
  ///
  /// Null when the end is not a materialised port on a device whose
  /// template resolves; [portCell] falls back to [portDesignator], which
  /// is what `panelPositionToken` itself does for a template that
  /// silkscreens nothing.
  final String? portPositionToken;

  /// `Port.userLabel`, when the user has set one.
  final String? portLabel;

  /// The room this end is in: the `PlaceEndpoint`'s location, else the
  /// device's, else the rack's. Never guessed from a sibling end.
  final Uuid? locationId;
  final String? roomName;

  /// A `PlaceEndpoint`/`OpenEndpoint`'s own words — "LR TV wall plate,
  /// north wall, 60 in AFF". Empty for port ends.
  final String description;

  /// True when this end is somewhere in a rack.
  bool get isInRack => rackId != null;

  /// §3.2 column 6 / §3.3 column 5 — `RK-1 / U14 / rear`.
  ///
  /// Falls back through what is actually known rather than printing a
  /// half-empty template: an unracked port prints its device, a field end
  /// prints its description, and an unresolved port prints
  /// [kUnknownCell] because the honest answer is that this document
  /// cannot say where that end is.
  String get locationCell {
    final parts = <String>[
      if (rackDesignator != null) rackDesignator!,
      if (ruIndex != null) 'U$ruIndex',
      if (face != null) face == Face.front ? 'front' : 'rear',
    ];
    if (parts.isNotEmpty) return parts.join(' / ');
    return switch (kind) {
      ScheduleEndKind.unrackedPort => deviceDesignator ?? kNotInARackCell,
      ScheduleEndKind.field || ScheduleEndKind.open => _fieldCell,
      ScheduleEndKind.rackPort ||
      ScheduleEndKind.unresolvedPort ||
      ScheduleEndKind.none => kUnknownCell,
    };
  }

  /// `Great Room / TV wall WP-1` — §3.2 column 5's room-and-outlet cell,
  /// minus the outlet, which lives on the row (it comes from
  /// `Link.structureOrigin`, not from the endpoint).
  String get _fieldCell {
    final room = roomName;
    if (room == null) return description.isEmpty ? kUnknownCell : description;
    if (description.isEmpty) return room;
    return '$room / $description';
  }

  /// §3.3 column 8's far-end cell. An `OpenEndpoint` prints `— OPEN —`
  /// (§3.3, AC-018): a home run whose far end is not yet bound is the
  /// normal state of a rough-in, not an error, and it must not read as
  /// missing data.
  String get farEndCell => switch (kind) {
    ScheduleEndKind.open => kOpenEndCell,
    ScheduleEndKind.field => _fieldCell,
    ScheduleEndKind.rackPort ||
    ScheduleEndKind.unrackedPort => deviceDesignator ?? kUnknownCell,
    ScheduleEndKind.unresolvedPort || ScheduleEndKind.none => kUnknownCell,
  };

  /// THE NUMBER PRINTED ON THE PART, plus its user label when there is
  /// one. `01` on a patch panel, `J09` on a device that silkscreens
  /// nothing.
  ///
  /// DR-054 (canon §11.53) MOVED THIS OFF `portDesignator`, and the
  /// column and `RACK LBL` now describe one hole one way. `RACK LBL`
  /// has rendered `PortDef.label` since DR-040 §11.39.8, while this
  /// rendered `Port.designator`, and `portDesignatorFormat` is
  /// `J{PORT_SEQ:2}` where `PORT_SEQ` counts the FRONT jacks a drop never
  /// touches: on a three-up/three-down fixture the hole labelled `01`
  /// designates `J04`. One sheet, two numbers, one position.
  ///
  /// [portPositionToken] already falls back to the designator, so this
  /// is uniform rather than special-cased, and `farPort` gets it free
  /// because it renders through here too.
  ///
  /// **`portDesignator` IS UNCHANGED AND IS STILL WHAT SORTS.** DR-054
  /// deliberately did not touch designator ALLOCATION: `Port.designator`
  /// is stored project state (CR-042), so changing how it is allocated
  /// would leave one document holding `J04` on ports bound last week and
  /// `01` on ports bound today, with no migration able to reconcile them.
  /// A rendering rule has no such tail.
  String get portCell {
    final shown = portPositionToken ?? portDesignator;
    if (shown == null) return kUnknownCell;
    final label = portLabel;
    return label == null || label.isEmpty ? shown : '$shown $label';
  }
}

/// How a signal family is SPELLED in a cell: `V·HDBaseT 5Play`.
///
/// EXTRACTED FROM [ScheduleEntry.typeCell] SO THERE IS ONE SPELLER.
/// The SERVICE column is a picker (DR-025 §11.24.5), its options are
/// built from this, and `resolveSignalFamilyCell` reads it back. A
/// dropdown that offered one spelling while the cell printed another
/// would round-trip wrong on the first family whose display name is not
/// its tag, which is most of them.
String signalFamilyCellLabel(SignalDomainDef domain, SignalFamilyDef family) =>
    '${domain.tagPrefix}·${family.displayName}';

/// What a plan-derived floor carries in front of its number: `≥ 41`.
///
/// U+2265 AND NOT `>=`, and the choice is a gate rather than a taste.
/// `tools/glyph_coverage_check.py` checks every non-ASCII literal against
/// the intersection of both bundled Jost weights, and both carry U+2265;
/// its `REQUIRED` set names this one so the gate still fails if the
/// literal scan ever stops matching. The trailing space is the cell's,
/// not the glyph's: at §3.2's 28 pt column `≥41` sets the bar tight
/// against the digit.
const String kAtLeastPrefix = '≥ ';

/// What §3.3 prints for an `OpenEndpoint`. A distinct token from
/// [kUnknownCell]: "nothing is landed here yet" is a fact, and "we do not
/// know" is not.
const String kOpenEndCell = '— OPEN —';

/// What the `OUTLET` column prints for a run that comes out of no box
/// (DR-070 §11.69).
///
/// A DISTINCT TOKEN FROM [kUnknownCell], for exactly [kOpenEndCell]'s
/// reason and it is worth restating: the dash means "nobody has said
/// which box", and a ceiling speaker having no box is something a person
/// stated. Printing the dash for both would put the fusion this ruling
/// removed from the MODEL straight back onto the sheet, where an
/// estimator reading the column cannot tell an unassigned drop from one
/// that will never have a plate.
const String kNoBoxCell = '— NO BOX —';

/// What an end that resolved to a device outside every rack prints, and
/// the band title those rows group under. Again not [kUnknownCell] — the
/// document states where it is.
///
/// ALIASED FROM `equipment_list.dart` rather than respelled. A reader who
/// meets `NOT IN A RACK` on T6.30 and again on T6.15 is entitled to
/// assume it means one thing, and two independent string literals is how
/// that stops being true.
const String kNotInARackCell = kUnplacedGroupTitle;

// ═════════════════════════════════════════════════════════════════════
// CONDUCTORS
// ═════════════════════════════════════════════════════════════════════

/// One `Conductor` as §3.3 column 12 prints it: `L+ red`, `pr 3 blue/white`.
///
/// The exit criterion for M2 says "conductor colours WHERE THEY EXIST",
/// so a conductor with no `colorCode` is kept, counted, and printed
/// without one — never dropped, and never given a colour from its role.
@immutable
final class ScheduleConductor {
  const ScheduleConductor({
    required this.role,
    required this.pairNumber,
    required this.colorCode,
  });

  /// `""` | `"L+"` | `"Y"` | `"+"`. Empty is legal and means the cable
  /// has one electrical path whose role is the cable.
  final String role;

  final int? pairNumber;

  /// `"blue/white"`, EXACTLY AS STORED — see the file header on why a
  /// value that looks like `T568B` is still printed here rather than
  /// promoted into the `TERM` column.
  final String? colorCode;

  bool get hasColor => colorCode != null && colorCode!.trim().isNotEmpty;

  /// `L+ red`, `pr 3 blue/white`, or just the colour when the role is
  /// empty.
  String get label {
    final head = <String>[
      if (role.trim().isNotEmpty)
        role.trim()
      else if (pairNumber != null)
        'pr $pairNumber',
    ];
    if (hasColor) head.add(colorCode!.trim());
    return head.isEmpty ? kUnknownCell : head.join(' ');
  }
}

// ═════════════════════════════════════════════════════════════════════
// LENGTH
// ═════════════════════════════════════════════════════════════════════

/// Where a row's `LEN` figure came from — §3.2 column 8's italic rule,
/// made explicit rather than left to a bool.
///
/// AC-024 gives a `Link` THREE lengths for three columns (routed for
/// takeoff, cut for the pull sheet, terminated for as-built), and §3.2's
/// `LEN` is the CUT length. When there is none, the sheet may still show
/// an estimate — in italic, "so nobody bills off them".
enum ScheduleLengthSource {
  /// `Link.cutLength`. The measured figure; prints upright.
  cut,

  /// `Outlet.nominalRunLength` — the per-drop nominal the outlet carries.
  ///
  /// §3.2 names only the room estimate below, and this source is a
  /// DELIBERATE addition, stated here rather than buried: it is a stored
  /// fact about this exact drop, it is strictly more specific than the
  /// room figure, and it is what the corpus actually populates
  /// (`whole_house` sets `nominalRunLength` on all seventeen outlets and
  /// `cutLength` on none). It prints as an estimate, never as a cut
  /// length.
  ///
  /// RATIFIED, PROVISIONALLY, BY DR-026 §11.25.2 — and the citation is
  /// added here because this doc comment is the evidence that ruling
  /// reasoned from, which made it the one place a reader could not find
  /// the answer. Board #153 asked for the placement to be "ratified or
  /// overruled BEFORE ANYTHING READS IT"; the ruling's finding is that
  /// the deadline had already passed, since the tier shipped at M2-B and
  /// the corpus's own fixture depends on it, so the task must not be
  /// picked up and priced as preventive. The tier stands as written:
  /// more specific than the room estimate, less authoritative than a cut
  /// length, printed as an estimate and never as a measurement.
  ///
  /// THE PLAN VIEW WAS THE NAMED TRIGGER AND IT HAS LANDED, SO THIS
  /// COMMENT IS ANSWERED RATHER THAN LEFT OPEN. It read *"whether a
  /// floorplan supersedes any of these four tiers is open and is owed
  /// when it lands"* until `PLAN-G/1`. **It supersedes none of them**
  /// (DR-037 §11.36.4): [planLowerBound] ranks BELOW the room estimate
  /// and the three tiers above it are untouched. A comment that stays
  /// open after its question is answered is how the next reader
  /// re-litigates it.
  ///
  /// The advance note it carried was right and is now the tier's own:
  /// a plan yields a BOUND, a bound "never enters the footage rollup as
  /// a quantity" (DR-020 §11.19.2(2)), and [planLowerBound] therefore
  /// does not behave like the three here.
  outletNominal,

  /// `Location.estimatedRunLengthFromRack` — AC-024's "ONE number per
  /// room ... what makes 62 usable estimates possible". §3.2's named
  /// source for the italic figure.
  roomEstimate,

  /// A calibrated plan's straight line from the rack's pin to this run's
  /// subject pin, plus the subject's `Location.riseAllowance` where one
  /// is set (docs/15 §4.1, DR-020 §11.19.2, DR-147 §11.146.2).
  ///
  /// **NOT AN ESTIMATE, AND THE RANK IS NOT ABOUT THE COLUMN.** It is the
  /// one length statement a plan can make that survives whatever the
  /// framing turns out to be, because a straight line is `≤` any real
  /// route. It nonetheless ranks BELOW [roomEstimate], and DR-037
  /// §11.36.4 gives the reason as the ROLLUP: a bound is excluded from
  /// the footage total, so ranking it above the room estimate would move
  /// every drop on a calibrated plan out of the purchase quantity and
  /// into the unknown count. **The number an integrator orders cable from
  /// would get worse in proportion to how much of the job had been
  /// planned.**
  ///
  /// **THE RANK COSTS IT NOTHING, BECAUSE ITS VALUE WAS NEVER THE
  /// COLUMN.** `LEN-001` and `LEN-002` read the bound regardless of which
  /// tier printed, by calling `planLowerBoundOf` themselves rather than
  /// through a row: they take a `Link` and never build a schedule, so a
  /// second copy of the number on [ScheduleEntry] would have had no
  /// reader. A plan can prove a length violation and can never prove
  /// compliance.
  ///
  /// Prints ITALIC and prefixed `≥`. The flag is
  /// `ScheduleEntry.lengthIsBound` (`PLAN-G/3`) and is deliberately NOT
  /// [ScheduleEntry.lengthIsEstimated]: a floor and a guess are two
  /// claims, and one count cannot carry both (DR-147 §11.146.4).
  ///
  /// **THIS SAID "NOTHING PRODUCES THIS VALUE YET" UNTIL 2026-09-23**, and
  /// had been wrong since `PLAN-G/3` did exactly what the sentence said it
  /// would: `_lengthOf` returns this tier, below the room estimate, and
  /// `rules_cable.dart` reads the floor directly. The note described a
  /// plan rather than a state and nothing connected finishing the work to
  /// editing it. Found while writing docs/21, which had to state what the
  /// schedule can tell an integrator about cable footage.
  planLowerBound,

  /// No length is known. §3.2: prints `—`, and the `LEN-*` rules emit
  /// "length unknown, cannot verify" rather than silently passing (G4).
  none,
}

// ═════════════════════════════════════════════════════════════════════
// ROWS
// ═════════════════════════════════════════════════════════════════════

/// ONE PHYSICAL CABLE, ONE `W` NUMBER, ONE ROW (G1) — projected by both
/// presets.
///
/// NOT NAMED `ScheduleRow`, and the reason is worth stating rather than
/// leaving as a curiosity: `draw/sheet/equipment_sheet.dart` already owns
/// that name for §3.7's PAGINATION model — a laid-out line of measured
/// cells on a page, with a height. This is the other thing entirely: a
/// cable, before anyone has decided what page it lands on. Two types
/// called `ScheduleRow` in one barrel would have to be told apart by
/// import, which is exactly the confusion §3.1's "one derivation" is
/// meant to remove.
///
/// Holds resolved VALUES and the cell strings §3.2/§3.3 specify. It does
/// NOT hold pounds-vs-kilograms decisions, page geometry or any colour:
/// `ProjectSettings.displayUnits` (CR-097) is applied by the presentation
/// layer, and a jacket colour never reaches a drawn hue (CR-078/PAL-1).
@immutable
final class ScheduleEntry {
  const ScheduleEntry({
    required this.linkId,
    required this.designator,
    required this.order,
    required this.linkClass,
    required this.classDisagreement,
    required this.from,
    required this.to,
    required this.fieldLabel,
    required this.rackLabel,
    required this.outletDesignation,
    required this.roomId,
    required this.roomName,
    required this.pathwayId,
    required this.pathwayName,
    required this.pathwayDesignator,
    required this.mediaId,
    required this.media,
    required this.jacketRating,
    required this.jacketColor,
    required this.signalFamilyId,
    required this.signalFamily,
    required this.signalDomain,
    required this.length,
    required this.lengthSource,
    required this.routedLength,
    required this.terminatedLength,
    required this.conductors,
    required this.roughInStatus,
    required this.lifecycleStatus,
    required this.crossover,
    required this.terminationType,
    required this.notes,
    // OPTIONAL AND LAST, so the twenty-two required names above it
    // keep the lint's required-first order (DR-070 §11.69).
    this.boxless = false,
    this.estimateOrigin,
    this.wiringStandard,
    this.rackTerminationType,
    this.adapterNotes = const <String>[],
    this.furtherPairs = const <ScheduleEndPair>[],
    this.isCaptiveCord = false,
  });

  final Uuid linkId;

  /// `W042`.
  final String designator;

  /// `Link.order`. Carried so a caller can restore document order without
  /// a second lookup; never used as a sort key on its own, because §3.6's
  /// stable secondary sort is the DESIGNATOR.
  final FracIndex order;

  /// THE EFFECTIVE CLASS (`effectiveLinkClassOf`), and `null` means
  /// UNDETERMINED — see the file header. Never `Link.linkClass`.
  final LinkClass? linkClass;

  /// What the classifier would say when a person has said otherwise
  /// (`linkClassDisagreementOf`), else null. DR-008 §11.8.2's "and the
  /// disagreement stays visible" half.
  final LinkClass? classDisagreement;

  /// The two ends, ORIENTED: when exactly one end lands in a rack, that
  /// end is [to] and the other is [from], whatever order the conductor
  /// stored them in. §3.2 reads a row left-to-right as
  /// `FROM — ROOM / OUTLET` then `TO — RACK / RU / FACE`, and a document
  /// that happened to store the rack end first would otherwise print the
  /// rack under "FROM — ROOM" on half the sheet.
  final ScheduleEnd from;
  final ScheduleEnd to;

  /// `StructureOrigin.fieldLabel` — `LR-TV-1`, the label on the wall
  /// plate. Null when this link is not a home run.
  ///
  /// BOTH LABELS RIDE ON EVERY ROW OF BOTH PRESETS. CR-044/AC-047: "the
  /// dual-label insight was correctly identified for structured wiring
  /// and then not applied to every cable; it now applies to every cable".
  /// A tech at the plate and a tech at the panel are reading the same
  /// row and each needs the other's label to speak to the other.
  final String? fieldLabel;

  /// `StructureOrigin.rackLabel` — `1A-A12`, the label at the panel.
  final String? rackLabel;

  /// The `Outlet`'s own field designation, via
  /// `StructureOrigin.outletId`.
  final String? outletDesignation;

  /// This run comes out of NO BOX and never will (DR-070 §11.69). Not the
  /// same as [outletDesignation] being null, which is "nobody has said".
  final bool boxless;

  /// The room this run belongs to — the FROM end's, falling back to the
  /// outlet's and then the TO end's. The Pull Sheet's default grouping
  /// and primary sort (AC-025: "the order the tech walks the house").
  final Uuid? roomId;
  final String? roomName;

  final Uuid? pathwayId;

  /// `Pathway.name` — "attic run to the garage". The HUMAN NAME.
  ///
  /// This comment used to record that docs/08 §3.2 calls the column's
  /// content `Pathway.designator` while the entity had no such field, *"so
  /// this reads the field that exists"*. M3-E/2 (#157) built the field, and
  /// the honest workaround is retired: see [pathwayDesignator] and
  /// [pathwayLabel].
  final String? pathwayName;

  /// `Pathway.designator` — `T1`, `PW-LR-1`. What docs/08 §3.2 column 9
  /// always specified. Null is unknown (G4, CR-114); most pathways carry
  /// none until somebody has walked the building (DR-026 §11.25.1).
  final String? pathwayDesignator;

  final MediaTypeId mediaId;

  /// The registry entry for [mediaId], or null when the document's
  /// `Registries` does not carry one. Counted, never invented.
  final MediaTypeDef? media;

  /// The NEC/UL LISTING (`Link.jacket`) — `CMR`, `CMP`. One of the three
  /// colour-ish facts on a `Link` that must not be confused; see
  /// `link.dart`.
  final JacketListing? jacketRating;

  /// The run's jacket colour, resolved through the SHARED
  /// `resolveJacketColor` — never a second reading of the two stored ids.
  final ResolvedJacketColor jacketColor;

  /// From the link's FIRST `Service`. A link carrying three services
  /// (CR-010) has three families and one TYPE cell; §3.4's `SERVICE`
  /// column is the place that grows to hold the rest, and it is not
  /// built here.
  final SignalFamilyId? signalFamilyId;
  final SignalFamilyDef? signalFamily;
  final SignalDomainDef? signalDomain;

  /// The `LEN` figure, from [lengthSource]. Null when nothing is known.
  final Len? length;
  final ScheduleLengthSource lengthSource;

  /// AC-024's other two lengths, for §3.4's optional `ROUTED` /
  /// `TERMINATED` columns. Carried rather than re-fetched so a caller
  /// enabling them cannot accidentally read `cutLength` for both.
  final Len? routedLength;
  final Len? terminatedLength;

  final List<ScheduleConductor> conductors;

  final RoughInStatus roughInStatus;
  final LifecycleStatus lifecycleStatus;
  final CrossoverKind? crossover;

  /// One note per declared in-line adapter, in `Link.inlineAdapters`
  /// order: `ADAPTER XLR3 TO RCA (Hosa XLR3F-RCA)` (DR-235 §11.234.4).
  /// Composed at build from `adapterConnectorsLabel`, so the schedule names
  /// an adapter exactly as the cable bar and T6.30 do. The connectors are
  /// in the notes' capitals; the model is a person's words and keeps its
  /// own case.
  final List<String> adapterNotes;

  /// The cable's further ends (DR-236 §11.235.3, BRK-A/4): one pair per
  /// (device, device) its conductors join BEYOND the pair [from] and [to]
  /// already name, oriented as they are. Empty for every cable that joins
  /// one pair of devices, which is every cable drawn before DR-236.
  ///
  /// A PAIR, NOT AN END, because a tap-and-continue's second line is
  /// terminated at BOTH ends: the amplifier's zone 2 pins as well as SPK-2.
  /// ONE ROW STILL, so the view's footage and counts read the cable once,
  /// and the Termination Schedule prints a line per pair under it.
  final List<ScheduleEndPair> furtherPairs;

  /// Whether this cable is a device's own attached lead (DR-238): still a
  /// power cord everywhere, and left out of what T6.30 says is bought by
  /// the piece.
  final bool isCaptiveCord;

  /// " + SPK-2": each further pair's NEW end, on the side of the row the
  /// pair does NOT share (§11.235.3, one row naming every far end).
  ///
  /// THE SHARED SIDE DECIDES IT, NOT "THE FAR END". A 16/4 from a rack
  /// amplifier to two room speakers shares the amplifier, which is the
  /// row's TO, so SPK-2 joins SPK-1 in FROM. The same cable rack to rack
  /// shares the amplifier as the row's FROM, so the new end joins TO. A
  /// pair that shares neither adds each end to its own side.
  String _furtherOn({required bool fromSide}) {
    final out = StringBuffer();
    for (final p in furtherPairs) {
      final sharesFrom = _shares(p.from, from);
      final sharesTo = _shares(p.to, to);
      // Shares TO: the new end is its FROM. Shares FROM: its TO. Shares
      // neither: each end goes to its own side. (Sharing both cannot
      // happen: a pair is a distinct pair of devices.)
      final here = fromSide
          ? (sharesFrom ? null : p.from)
          : (sharesTo ? null : p.to);
      if (here != null) out.write(' + ${here.farEndCell}');
    }
    return out.toString();
  }

  static bool _shares(ScheduleEnd a, ScheduleEnd b) =>
      a.deviceId != null && a.deviceId == b.deviceId;

  /// [id]'s text on the Termination Schedule's line for [pair]: the cable
  /// number again, and the end columns for that pair. Everything else is
  /// blank, so a length or a type is never printed twice for one cable.
  String continuationCell(ScheduleColumnId id, ScheduleEndPair pair) {
    final near = _nearOf(pair);
    final far = _farOf(pair);
    return switch (id) {
      ScheduleColumnId.cableId ||
      ScheduleColumnId.cableIdWithLifecycle => designator,
      ScheduleColumnId.fromRoomOutlet => pair.from.locationCell,
      ScheduleColumnId.toRackRuFace => pair.to.locationCell,
      ScheduleColumnId.rackRuFace => near.locationCell,
      ScheduleColumnId.device => near.deviceDesignator ?? kUnknownCell,
      ScheduleColumnId.port => near.portCell,
      ScheduleColumnId.farEnd => far.farEndCell,
      ScheduleColumnId.farPort => far.portCell,
      _ => '',
    };
  }

  /// How this run's field end terminates —
  /// `StructureOrigin.terminationField` for a home run, else a
  /// `PlaceEndpoint`'s `intendedTermination`. Null when neither says, and
  /// never inferred from the connector: an F barrel and a keystone are
  /// both RG6 terminations and the model states which one this is or it
  /// does not.
  final TerminationType? terminationType;

  /// How this run's RACK end terminates: `StructureOrigin.terminationRack`
  /// and nothing else (DR-046, DR-055 §11.54). Null is undecided and prints
  /// as such; [terminationType]'s `PlaceEndpoint` chain belongs to the
  /// field end alone, and copying one end onto the other is the defect
  /// DR-046 removed from the model.
  final TerminationType? rackTerminationType;

  /// What this cable is wired to, ALREADY RESOLVED (DR-180 §11.179.2).
  ///
  /// `effectiveWiringStandard` answered this: the cable's own override,
  /// else the project's, else null. Null carries two distinct facts that
  /// no printed cell needs to tell apart, which is why one field holds
  /// both: nobody has stated a standard, or this is not a cable a
  /// standard is a fact about (a coax run, a speaker run). Either way
  /// nothing prints, which is G4's answer and the ruling's.
  ///
  /// RESOLVED HERE RATHER THAN AT THE CELL because §11.179.3's "only
  /// where it can be true" test reads the whole document (a port's
  /// connector is a template join), and a projection that re-derived it
  /// per cell would ask that question once per column per row.
  final WiringStandard? wiringStandard;

  /// `Link.notes` — the USER'S words, kept strictly apart from
  /// [derivedNotes] so a sheet can never present one as the other.
  final String? notes;

  /// True when no class could be determined — the state the Pull Sheet
  /// must count and show rather than default (G4).
  bool get isClassUndetermined => linkClass == null;

  /// True when a person's class and the classifier disagree.
  bool get hasClassDisagreement => classDisagreement != null;

  /// What §3.2 column 9 prints: the designator where one is written, the
  /// name otherwise.
  ///
  /// **THE FALLBACK IS NOT AN OVERLOAD**, and the distinction is the one
  /// DR-026 §11.25.1 drew. That ruling refused to *store* a designator in
  /// `name`, because two facts written into one field cannot be told apart
  /// afterwards by anybody. Both facts are stored here, separately, and the
  /// column resolves between them at the point of printing while
  /// [pathwayLabelIsDesignator] preserves which one it got. Nothing is
  /// lost and nothing is guessed.
  ///
  /// Without the fallback, every existing project's `PATHWAY` column would
  /// go to em rules the day the field shipped, since no pathway anywhere
  /// carries a designator yet.
  String? get pathwayLabel => pathwayDesignator ?? pathwayName;

  /// Whether [pathwayLabel] is a designator rather than a name.
  ///
  /// §3.2 column 9's font: `RackMono` for a designator, because it is an
  /// identifier somebody wrote on a trunk, and `RackBody` for a name,
  /// because it is prose. The sheet already assigns fonts by kind this way
  /// (`CABLE ID` and `RACK LABEL` are mono, `FROM — ROOM` is condensed),
  /// so a reader can tell a label in a wall from somebody's description
  /// without being told.
  ///
  /// A per-row flag the renderer consults, on [lengthIsEstimated]'s
  /// precedent. **The rendering itself is M6's** (DR-027 §11.26.2): M3
  /// owes the rows and the sort, M6 owns the sheet.
  bool get pathwayLabelIsDesignator => pathwayDesignator != null;

  /// Whether [length] is an estimate — §3.2 column 8's italic.
  ///
  /// **A PLAN FLOOR IS NOT AN ESTIMATE AND IS DELIBERATELY FALSE HERE**
  /// (DR-147 §11.146.4). Both print italic, so a renderer wants
  /// `lengthIsEstimated || lengthIsBound`; but this flag is also what
  /// `ScheduleView.estimatedCount` and §3.8's `3 estimated (italic)`
  /// footer count, and a footer reading `5 estimated` on a document
  /// holding three guesses and two measured floors is wrong about the one
  /// thing it exists to say. See [lengthIsBound].
  bool get lengthIsEstimated =>
      lengthSource == ScheduleLengthSource.outletNominal ||
      lengthSource == ScheduleLengthSource.roomEstimate;

  /// Where this row's ROOM ESTIMATE came from, or null when the length
  /// did not come from one (DR-050 §11.49.3, `LEN-A/5`).
  ///
  /// **SET ONLY WHEN `roomEstimate` PRINTED**, not merely when the room
  /// carries a marker. A run measured with a tape and cut to length has a
  /// row whose number owes nothing to the room's estimate, and carrying
  /// the marker onto it would report a provenance about a figure this row
  /// never used.
  final RunLengthOrigin? estimateOrigin;

  /// Whether this row's length is a figure the PLAN proposed rather than
  /// one a person entered.
  ///
  /// A STRICT SUBSET OF [lengthIsEstimated], unlike [lengthIsBound] which
  /// is deliberately disjoint from it. §11.49.3's question is *"did
  /// somebody measure this room or did the software guess it"*, and it is
  /// asked ABOUT an estimate rather than instead of one.
  bool get estimateIsComputed =>
      estimateOrigin == RunLengthOrigin.computedFromPlan;

  /// Whether [length] is a plan-derived floor rather than a length.
  ///
  /// Prints italic like an estimate and prefixed `≥`, which is the part
  /// that is not decoration: it is the difference between a number an
  /// installer cuts to and a number an installer knows is a floor
  /// (DR-020 §11.19.2(2)).
  ///
  /// **THE ROLLUPS READ THIS, NOT THE SOURCE**, so there is one predicate
  /// rather than four comparisons that can drift apart.
  bool get lengthIsBound => lengthSource == ScheduleLengthSource.planLowerBound;

  /// Conductors that state no colour. "Colours WHERE THEY EXIST" is the
  /// exit criterion's own hedge; this is the number that keeps it honest.
  int get conductorColorUnknownCount =>
      conductors.where((c) => !c.hasColor).length;

  /// The end that lands in a rack — §3.3's near end, the one whose rack,
  /// panel and port the Termination Schedule sorts on.
  ///
  /// Prefers [to], which orientation already put the rack end in. For a
  /// jumper BOTH ends are in one rack and either would do; taking [to]
  /// deterministically is what keeps the sort total (§8.4).
  ScheduleEnd get nearEnd => to.isInRack ? to : from;

  /// The other one.
  ScheduleEnd get farEnd => to.isInRack ? from : to;

  /// True when this cable lands in a rack at either end — §3.1's row rule
  /// for the Termination Schedule.
  bool get landsInRack => from.isInRack || to.isInRack;

  /// §3.2 column 2 / §3.3 column 2 — the tag beside the chip.
  ///
  /// `VID·HDMI` when the registry resolves both halves; the bare domain
  /// tag when only the domain does; the raw `SignalFamilyId` when neither
  /// does. That last case used to be the state of EVERY document, because
  /// the `registries.json` `registries.dart:12` cited never existed;
  /// DR-010 §11.10 seeds NEW documents from a Dart master instead, so it
  /// is now the honest degradation for a document saved before that
  /// (§6.2's `unknown(rawId)` rule), not the universal case. Never an
  /// abbreviation this file made up — see the file header.
  String get typeCell {
    final family = signalFamily;
    final domain = signalDomain;
    if (domain != null && family != null) {
      return signalFamilyCellLabel(domain, family);
    }
    if (domain != null) return domain.tagPrefix;
    return signalFamilyId?.v ?? kUnknownCell;
  }

  /// §3.2 column 7 — `Cat6A F/UTP CMR`, media plus fire rating.
  String get mediaCell {
    final name = media?.displayName ?? mediaId.v;
    final rating = jacketRating;
    return rating == null ? name : '$name ${jacketListingLabel(rating)}';
  }

  /// §3.1's jacket-colour cell. TWO TOKENS WHEN THE RUN IS AN EXCEPTION —
  /// `BLU→YEL`, never one: "a run pulled in the wrong colour prints both
  /// tokens".
  ///
  /// The ABBREVIATION is what prints, not the swatch. The Installer
  /// preset defaults to greyscale, where a swatch alone degrades to an
  /// indistinguishable grey — and was already indistinguishable for the
  /// ~8 % of installers with a colour-vision deficiency (docs/05 §6.1).
  /// A dangling id prints `?` rather than nothing: the record of what was
  /// pulled must survive the deletion of the convention entry naming it.
  String get jacketColorCell {
    final resolved = jacketColor;
    final conventionId = resolved.conventionId;
    final pulledId = resolved.pulledId;
    if (conventionId == null && pulledId == null) return kUnknownCell;
    final convention = conventionId == null
        ? null
        : resolved.convention?.abbr ?? kDanglingJacketColorCell;
    final pulled = resolved.pulled?.abbr ?? kDanglingJacketColorCell;
    if (!resolved.isException) return convention ?? pulled;
    return '${convention ?? kUnknownCell}→$pulled';
  }

  /// §3.3 column 11, FIELD TERM: `KEYSTONE T568A`, `F BARREL`. Its twin,
  /// [rackTermCell], is column 12: `PUNCHDOWN A03 T568B`.
  ///
  /// **ONE CELL CARRIED BOTH ENDS UNTIL M6-K (`#693`)**: the field end's
  /// termination type beside the RACK end's port designator, so a wall
  /// keystone landed on panel hole A03 printed `KEYSTONE A03`, a phrase
  /// true of no single piece of hardware. DR-055 split it. Each cell now
  /// reads one end: the field end's type (the home run's origin, or a
  /// `PlaceEndpoint`'s intent) here, and the rack end's own type, then its
  /// punch position (the near end's port designator), there. Both close
  /// with the wiring standard (DR-180 §11.179.4).
  ///
  /// THE STANDARD GOES LAST, BEHIND THE PUNCH POSITION, and that is a
  /// choice rather than an accident. `PUNCHDOWN A03` is one thing an
  /// installer reads at the panel: the type and the hole. Putting the
  /// standard between them splits a pair of words that belong together to
  /// satisfy a literal reading of "beside the termination type", which
  /// the ruling meant as "in this cell" rather than as an ordering.
  ///
  /// IT PRINTS ONLY BESIDE A TERMINATION THAT LANDS PAIRS ON PINS
  /// ([kPairOrderTerminations]). [wiringStandard] is already null for a
  /// cable that has no 8P8C end at all, so this second test catches the
  /// remaining case: a genuinely four-pair run whose recorded termination
  /// at THIS end is a euroblock or a binding post. `EUROBLOCK T568B` is a
  /// sentence about hardware that has no pins, which is the fabrication
  /// §11.179.3 exists to prevent, one end down.
  String get fieldTermCell => _termCell(terminationType, port: null);

  /// §3.3 column 12: the rack end's termination, then the punch position
  /// where there is one, then the standard. `—` when the rack end's
  /// termination is undecided, whatever the field end says (DR-046).
  String get rackTermCell {
    if (rackTerminationType == null) return kUnknownCell;
    return _termCell(rackTerminationType, port: nearEnd.portDesignator);
  }

  String _termCell(TerminationType? type, {required String? port}) {
    final parts = <String>[
      if (type != null) terminationLabel(type),
      if (port != null) port,
      if (wiringStandard != null &&
          type != null &&
          kPairOrderTerminations.contains(type))
        wiringStandardLabel(wiringStandard!),
    ];
    return parts.isEmpty ? kUnknownCell : parts.join(' ');
  }

  /// §3.2 column 8, in the project's display units — WHOLE FEET or whole
  /// metres, no unit suffix.
  ///
  /// [units] is REQUIRED and not defaulted. CR-097 makes
  /// `ProjectSettings.displayUnits` authoritative over every other
  /// preference, and a default here would be this file quietly overruling
  /// it for any caller that forgot.
  ///
  /// Whole units, not `78' 4-1/2"`: §3.2 gives this column 28 pt, §3.8
  /// prints `78`, and cable is ordered and cut in whole feet. The
  /// ESTIMATE flag is [lengthIsEstimated] and is not encoded in this
  /// string — italic is the renderer's job, and a caller that reads the
  /// number without the flag would bill off an estimate (AC-024).
  ///
  /// **THE `≥` IS THE ONE THING THAT IS IN THE STRING**, and the asymmetry
  /// with the italic is deliberate. Italic is a *style* a renderer applies
  /// and a plain-text export loses; `≥ 41` and `41` are different claims,
  /// and the second is a number an installer cuts to. A bound that lost
  /// its prefix on the way to a CSV would be indistinguishable from a
  /// measurement (DR-147 §11.146.4).
  ///
  /// **IT IS COMPOSED HERE AND NOT IN `scheduleLengthCell`**, which is
  /// shared with `pathway_table.dart`'s nominal length and three
  /// `structure_table.dart` columns. None of those can hold a bound, and
  /// one of them is parsed back by `parseLengthCell`: a prefix in the
  /// shared speller would put a character into cells that must round-trip
  /// and into cells that cannot mean it.
  String lengthCell(UnitSystem units) {
    final cell = scheduleLengthCell(length, units);
    return lengthIsBound ? '$kAtLeastPrefix$cell' : cell;
  }

  /// §3.3 column 12's conductor half — `L+ red · L- black`.
  String get conductorCell {
    if (conductors.isEmpty) return kUnknownCell;
    return conductors.map((c) => c.label).join(' · ');
  }

  /// The notes this file will stand behind, each read straight off a
  /// stored field. §3.8's richer set is not approximated — see the file
  /// header.
  List<String> get derivedNotes => <String>[
    if (crossover == CrossoverKind.nullModem) 'NULL-MODEM',
    if (crossover == CrossoverKind.fiberPolarityAB) 'POLARITY A→B',
    if (crossover == CrossoverKind.polarityReversed) 'POLARITY REVERSED',
    // DR-235 §11.234.4: whoever terminates the cable needs to know there is
    // a part in the middle of it.
    ...adapterNotes,
    if (jacketColor.isException) 'PULLED OFF-CONVENTION',
    if (isClassUndetermined) kUndeterminedClassGroupTitle,
    // DR-008 §11.8.2's disagreement, ON THE ROW rather than only in a
    // summary count: a reader working down the sheet must meet it at the
    // cable it is about.
    if (classDisagreement != null) _disagreementNote,
  ];

  String get _disagreementNote =>
      'CLASSED ${linkClassLabel(linkClass)} · LOOKS LIKE '
      '${linkClassLabel(classDisagreement)}';

  /// THE ONE CELL LOOKUP BOTH PRESETS USE. See the file header: a column
  /// that appears on both sheets is the same string on both because there
  /// is one function, not two.
  ///
  /// [ScheduleColumnId.number] and [ScheduleColumnId.signOff] return the
  /// empty string on purpose — a row ordinal belongs to the projection,
  /// not the row, and a sign-off box has no text at all.
  ///
  /// [units] reaches exactly one column ([ScheduleColumnId.length]) and is
  /// required for the reason [lengthCell] gives.
  String cell(ScheduleColumnId id, {required UnitSystem units}) => switch (id) {
    ScheduleColumnId.number || ScheduleColumnId.signOff => '',
    ScheduleColumnId.cableId => designator,
    ScheduleColumnId.cableIdWithLifecycle => switch (lifecycleSuffix(
      lifecycleStatus,
    )) {
      '' => designator,
      final suffix => '$designator $suffix',
    },
    ScheduleColumnId.type => typeCell,
    ScheduleColumnId.fieldLabel => fieldLabel ?? kUnknownCell,
    ScheduleColumnId.rackLabel => rackLabel ?? kUnknownCell,
    ScheduleColumnId.fromRoomOutlet => _fromRoomOutletCell,
    ScheduleColumnId.toRackRuFace =>
      '${to.locationCell}${_furtherOn(fromSide: false)}',
    ScheduleColumnId.rackRuFace => nearEnd.locationCell,
    ScheduleColumnId.device => nearEnd.deviceDesignator ?? kUnknownCell,
    ScheduleColumnId.port => nearEnd.portCell,
    ScheduleColumnId.farEnd => farEnd.farEndCell,
    ScheduleColumnId.farPort => farEnd.portCell,
    ScheduleColumnId.media => mediaCell,
    ScheduleColumnId.jacketColor => jacketColorCell,
    ScheduleColumnId.length => lengthCell(units),
    ScheduleColumnId.pathway => pathwayLabel ?? kUnknownCell,
    ScheduleColumnId.fieldTerm => fieldTermCell,
    ScheduleColumnId.rackTerm => rackTermCell,
    ScheduleColumnId.conductorNotes => _conductorNotesCell,
  };

  String get _fromRoomOutletCell {
    final outlet = outletDesignation;
    final base = from.locationCell;
    // NAMED, NOT LEFT BLANK (DR-070 §11.69). A boxless run has a room and
    // no plate, and a cell showing only the room reads as a drop whose
    // outlet nobody filled in. The estimator counting plates off this
    // column is the person the difference is for.
    if (boxless) {
      return base == kUnknownCell ? kNoBoxCell : '$base $kNoBoxCell';
    }
    // DR-236 §11.235.3: a cable that continues names its further far ends
    // here, on the one row.
    final more = _furtherOn(fromSide: true);
    if (outlet == null || outlet.isEmpty) return '$base$more';
    final at = base == kUnknownCell ? outlet : '$base $outlet';
    return '$at$more';
  }

  String get _conductorNotesCell {
    final parts = <String>[
      if (conductors.isNotEmpty) conductorCell,
      ...derivedNotes,
    ];
    return parts.isEmpty ? kUnknownCell : parts.join(' · ');
  }
}

/// What a jacket-colour token prints when its id names no convention
/// entry. NOT a substituted colour — `hasUnknownEntry` says so and the
/// view counts it.
const String kDanglingJacketColorCell = '?';

/// Exact nanometres per foot and per metre — the two divisors
/// [ScheduleEntry.lengthCell] rounds by. Named rather than spelled inline
/// because this project has already shipped a 1000x unit error that
/// survived nine copy-pasted conversions (`device_loads.dart`'s header).
const int _nmPerFoot = Len.nmPerInch * 12;
const int _nmPerMetre = Len.nmPerMillimetre * 1000;

/// WHOLE FEET OR WHOLE METRES, ONCE, FOR EVERY LENGTH ANY TABLE PRINTS.
///
/// [ScheduleEntry.lengthCell] is one caller; docs/07 §4.1's three optional
/// length columns (`routedLength` / `cutLength` / `terminatedLength`) are
/// the others. They go through here rather than each dividing by its own
/// constant for the reason named above [_nmPerFoot]: this project has
/// already shipped a 1000x unit error that survived nine copy-pasted
/// conversions.
///
/// NULL IS UNKNOWN and prints as such (G4, CR-114). Never `0`, which on a
/// length column means a measured zero.
String scheduleLengthCell(Len? value, UnitSystem units) {
  if (value == null) return kUnknownCell;
  final divisor = switch (units) {
    UnitSystem.imperial => _nmPerFoot,
    UnitSystem.metric => _nmPerMetre,
  };
  return '${(value.nm / divisor).round()}';
}

/// What a `JacketListing` prints. PUBLIC because the Structure editor
/// offers fire rating as its own optional column (docs/07 §4.1) and a
/// second spelling of `CMR` is a second vocabulary.
String jacketListingLabel(JacketListing listing) => switch (listing) {
  JacketListing.cm => 'CM',
  JacketListing.cmg => 'CMG',
  JacketListing.cmr => 'CMR',
  JacketListing.cmp => 'CMP',
  JacketListing.cmx => 'CMX',
  JacketListing.cl2 => 'CL2',
  JacketListing.cl2r => 'CL2R',
  JacketListing.cl2p => 'CL2P',
  JacketListing.cl2x => 'CL2X',
  JacketListing.cl3 => 'CL3',
  JacketListing.cl3r => 'CL3R',
  JacketListing.cl3p => 'CL3P',
  JacketListing.cl3x => 'CL3X',
  JacketListing.fpl => 'FPL',
  JacketListing.fplr => 'FPLR',
  JacketListing.fplp => 'FPLP',
  JacketListing.ofn => 'OFN',
  JacketListing.ofng => 'OFNG',
  JacketListing.ofnr => 'OFNR',
  JacketListing.ofnp => 'OFNP',
  JacketListing.ofc => 'OFC',
  JacketListing.ofcg => 'OFCG',
  JacketListing.ofcr => 'OFCR',
  JacketListing.ofcp => 'OFCP',
  JacketListing.catv => 'CATV',
  JacketListing.catvr => 'CATVR',
  JacketListing.catvp => 'CATVP',
  JacketListing.catvx => 'CATVX',
};

/// What a `TerminationType` prints. PUBLIC for the same reason
/// [jacketListingLabel] is: docs/07 §4.1 gives the FIELD termination its
/// own optional column, and the rack end already prints through here.
String terminationLabel(TerminationType type) => switch (type) {
  TerminationType.keystone => 'KEYSTONE',
  TerminationType.punchdown => 'PUNCHDOWN',
  TerminationType.fBarrel => 'F BARREL',
  TerminationType.euroblock => 'EUROBLOCK',
  TerminationType.unterminated => 'UNTERMINATED',
  TerminationType.fieldConnector => 'FIELD CONNECTOR',
  TerminationType.bindingPost => 'BINDING POST',
  TerminationType.rj45Plug => 'RJ45 PLUG',
};

/// What a `LinkClass` prints. `null` is UNDETERMINED and prints as such —
/// never as a class name, which is the whole point (G4).
String linkClassLabel(LinkClass? value) => switch (value) {
  LinkClass.fieldCable => 'FIELD CABLE',
  LinkClass.jumper => 'JUMPER',
  LinkClass.powerCord => 'POWER CORD',
  LinkClass.internal => 'INTERNAL',
  null => 'UNDETERMINED',
};

// ═════════════════════════════════════════════════════════════════════
// THE DERIVATION
// ═════════════════════════════════════════════════════════════════════

/// Every `Link` in the document as a row, in document order.
@immutable
final class Schedule {
  const Schedule({required this.rows});

  /// One row per `Link`, ordered by `Link.order` then id — a total order
  /// with no `Map` iteration in it (§8.4), so two builds of an unmodified
  /// document produce the identical list.
  final List<ScheduleEntry> rows;

  int get rowCount => rows.length;
}

/// Builds the row model for [doc]. PURE and TOTAL: `doc.links.length`
/// rows out, always.
Schedule buildSchedule(RackDocument doc) {
  final rows =
      <ScheduleEntry>[
        for (final link in doc.links.values) _row(doc, link),
      ]..sort((a, b) {
        final byOrder = a.order.v.compareTo(b.order.v);
        return byOrder != 0 ? byOrder : a.linkId.v.compareTo(b.linkId.v);
      });
  return Schedule(rows: List.unmodifiable(rows));
}

/// One further pair of a cable's ends (DR-236 §11.235.3).
typedef ScheduleEndPair = ({ScheduleEnd from, ScheduleEnd to});

ScheduleEnd _nearOf(ScheduleEndPair p) => p.to.isInRack ? p.to : p.from;
ScheduleEnd _farOf(ScheduleEndPair p) => p.to.isInRack ? p.from : p.to;

/// [link]'s pairs beyond its first conductor's (BRK-A/4): its conductors
/// grouped by the devices (or field places) their two ends land on, the
/// first conductor's group left out, each group oriented as `_row` orients
/// the row (exactly one end in a rack means that end is TO).
List<ScheduleEndPair> _furtherPairsOf(RackDocument doc, Link link) {
  // A STRING FOR EVERY KIND: a port by its device, a place by where and
  // what it says, every open end as one "nowhere". Neither `PlaceEndpoint`
  // nor `OpenEndpoint` has value equality, so keying on the object made
  // each conductor of a multi-pair cable to one place a pair of its own.
  // (`Uuid` is an extension type, not an `Object`, hence `.v`.)
  String keyOf(Endpoint e) => switch (e) {
    PortEndpoint(:final portId) =>
      'dev:${(doc.ports[portId]?.deviceId ?? portId).v}',
    PlaceEndpoint(:final locationId, :final description) =>
      'place:${locationId?.v}:$description',
    OpenEndpoint() => 'open',
  };

  final conductors = link.conductors;
  if (conductors.length < 2) return const <ScheduleEndPair>[];
  final first = conductors.first;
  final seen = <(String, String)>{(keyOf(first.from), keyOf(first.to))};
  final out = <ScheduleEndPair>[];
  for (final c in conductors.skip(1)) {
    if (!seen.add((keyOf(c.from), keyOf(c.to)))) continue;
    final a = _endOf(doc, c.from);
    final b = _endOf(doc, c.to);
    final flip = a.isInRack && !b.isInRack;
    out.add((from: flip ? b : a, to: flip ? a : b));
  }
  return List<ScheduleEndPair>.unmodifiable(out);
}

ScheduleEntry _row(RackDocument doc, Link link) {
  final conductors = link.conductors;
  // THE FIRST CONDUCTOR'S ENDS, AND THAT IS NOW KNOWN TO BE INCOMPLETE.
  // This said CR-014 gives every conductor of one cable the same pair; it
  // does not, and a cable may reach N devices (DR-236). For every cable
  // with one pair of devices this is the whole answer. A cable that
  // reaches further prints its far ends together on one row, which is
  // BRK-A/4's (`#1007`) and DR-236 §11.235.3's, not this reader's.
  final first = conductors.isEmpty ? null : conductors.first;
  final endA = first == null ? ScheduleEnd.none : _endOf(doc, first.from);
  final endB = first == null ? ScheduleEnd.none : _endOf(doc, first.to);

  // ORIENTATION. Exactly one end in a rack ⇒ that end is TO. See
  // `ScheduleEntry.from`.
  final flip = endA.isInRack && !endB.isInRack;
  final from = flip ? endB : endA;
  final to = flip ? endA : endB;

  final origin = link.structureOrigin;
  final outlet = origin == null ? null : doc.outlets[origin.outletId];

  // THE ROOM IS THE FROM END'S, and orientation has already put the FIELD
  // end there when there is one. A run's room is where its drop is, not
  // where its rack is — AC-025's "the order the tech walks the house"
  // means nothing if every row groups under the equipment room.
  //
  // THROUGH THE SHARED RULE, NOT INLINE (`LEN-A/3`). `roomEstimateFor`
  // has to find the runs belonging to a room, and the room whose estimate
  // applies to a run is BY DEFINITION the one this line picks: the
  // consumer is four lines below. A second spelling would let the two
  // disagree about the same run, which is the two-answers failure CR-107
  // keeps naming.
  final roomId = _roomIdOf(from, to, outlet);

  final room = doc.locations[roomId];
  final (Len? length, ScheduleLengthSource source) = _lengthOf(
    link,
    outletNominal: outlet?.nominalRunLength,
    roomEstimate: room?.estimatedRunLengthFromRack,
    // COMPUTED FOR EVERY ROW AND USED BY THE LAST TIER ONLY. It is not
    // carried on the entry: `LEN-001` and `LEN-002` read the floor
    // whichever tier printed, and they do it by calling
    // `planLowerBoundOf` themselves, since they take a `Link` and never
    // build a schedule.
    planLowerBound: planLowerBoundOf(doc, link),
  );

  final familyId = link.services.isEmpty
      ? null
      : link.services.first.signalFamily;
  final family = familyId == null
      ? null
      : doc.registries.signalFamilies[familyId];

  final pathwayId = link.pathwayId ?? outlet?.pathwayId;

  return ScheduleEntry(
    linkId: link.id,
    designator: link.designator,
    order: link.order,
    // THE ONLY READ OF A LINK'S CLASS IN THIS FILE, and it is not
    // `link.linkClass`. See the file header.
    linkClass: effectiveLinkClassOf(doc, link),
    classDisagreement: linkClassDisagreementOf(doc, link),
    from: from,
    to: to,
    fieldLabel: _trimToNull(origin?.fieldLabel),
    rackLabel: _trimToNull(origin?.rackLabel),
    outletDesignation: _trimToNull(outlet?.designation),
    boxless: origin?.boxless ?? false,
    roomId: roomId,
    roomName: _locationName(doc, roomId),
    pathwayId: pathwayId,
    pathwayName: _trimToNull(doc.pathways[pathwayId]?.name),
    pathwayDesignator: _trimToNull(doc.pathways[pathwayId]?.designator),
    mediaId: link.media,
    media: doc.registries.mediaTypes[link.media],
    jacketRating: link.jacket,
    // THE SHARED RESOLUTION, not a second reading of the two stored ids
    // (`jacket_color_resolution.dart`). CR-121 populates them; this is
    // the consumer docs/01:621 and docs/08:99 promised and never had.
    jacketColor: resolveJacketColor(link, doc.settings.jacketColorConventions),
    signalFamilyId: familyId,
    signalFamily: family,
    signalDomain: family == null
        ? null
        : doc.registries.signalDomains[family.domain],
    length: length,
    lengthSource: source,
    // ONLY WHEN THE ROOM ESTIMATE ACTUALLY PRINTED. See
    // `ScheduleEntry.estimateOrigin`: a run cut to a measured length owes
    // nothing to the room's figure, and carrying the marker onto it would
    // report a provenance about a number this row never used.
    estimateOrigin: source == ScheduleLengthSource.roomEstimate
        ? room?.estimatedRunLengthOrigin
        : null,
    routedLength: link.routedLength,
    terminatedLength: link.terminatedLength,
    conductors: List.unmodifiable(<ScheduleConductor>[
      for (final c in conductors)
        ScheduleConductor(
          role: c.role,
          pairNumber: c.pairNumber,
          colorCode: c.colorCode,
        ),
    ]),
    roughInStatus: link.roughInStatus,
    lifecycleStatus: link.lifecycleStatus,
    crossover: link.crossover,
    terminationType: _terminationOf(link, first),
    notes: _trimToNull(link.notes),
    wiringStandard: effectiveWiringStandard(doc, link),
    rackTerminationType: link.structureOrigin?.terminationRack,
    furtherPairs: _furtherPairsOf(doc, link),
    isCaptiveCord: linkIsCaptiveCord(doc, link),
    adapterNotes: List.unmodifiable(<String>[
      for (final a in link.inlineAdapters) _adapterNote(doc, a),
    ]),
  );
}

/// `ADAPTER XLR3 TO RCA`, and the model in brackets when one is stated.
String _adapterNote(RackDocument doc, InlineAdapter adapter) {
  final pair = adapterConnectorsLabel(doc.registries, adapter).toUpperCase();
  final model = adapter.model;
  return model == null ? 'ADAPTER $pair' : 'ADAPTER $pair ($model)';
}

/// The home run's own termination first, then a `PlaceEndpoint`'s stated
/// intent, then nothing.
///
/// `StructureOrigin.terminationField` outranks the endpoint's
/// `intendedTermination` because the origin is what the trim-out crew
/// actually installs; the endpoint's field is an INTENT recorded at
/// rough-in and may predate the decision.
///
/// A NULL ORIGIN FIELD OUTRANKS NOTHING, and that is what changed at
/// M3-J. The field was non-nullable, so a home run always answered and
/// this function returned on the first line for every one of them. Now
/// null means UNKNOWN (G4, CR-114), and unknown is not a value to prefer
/// over a stated intent: a drop whose wall end nobody has decided, on an
/// endpoint that says `fBarrel`, should print `fBarrel` rather than `—`.
/// The precedence is unchanged where both are present.
TerminationType? _terminationOf(Link link, Conductor? first) {
  final origin = link.structureOrigin;
  if (origin?.terminationField case final t?) return t;
  for (final end in <Endpoint?>[first?.from, first?.to]) {
    if (end is PlaceEndpoint && end.intendedTermination != null) {
      return end.intendedTermination;
    }
  }
  return null;
}

/// §3.2 column 8's fallback chain, most specific first. See
/// [ScheduleLengthSource] for why `Outlet.nominalRunLength` is in it and
/// why the plan's floor ranks below the room estimate rather than above
/// it.
(Len?, ScheduleLengthSource) _lengthOf(
  Link link, {
  required Len? outletNominal,
  required Len? roomEstimate,
  required Len? planLowerBound,
}) {
  final cut = link.cutLength;
  if (cut != null) return (cut, ScheduleLengthSource.cut);
  if (outletNominal != null) {
    return (outletNominal, ScheduleLengthSource.outletNominal);
  }
  if (roomEstimate != null) {
    return (roomEstimate, ScheduleLengthSource.roomEstimate);
  }
  if (planLowerBound != null) {
    return (planLowerBound, ScheduleLengthSource.planLowerBound);
  }
  return (null, ScheduleLengthSource.none);
}

/// The room a run belongs to, or null when nothing says.
///
/// ═══════════════════════════════════════════════════════════════════════
/// THE RULE ITSELF, SO THERE IS ONE OF IT
/// ═══════════════════════════════════════════════════════════════════════
/// Takes the ends ALREADY ORIENTED and the outlet already resolved,
/// because `_row` has both and re-deriving them would double `_endOf` on
/// a path that runs once per link. [roomOfLink] is the same rule for a
/// caller holding only a `Link`.
Uuid? _roomIdOf(ScheduleEnd from, ScheduleEnd to, Outlet? outlet) =>
    from.locationId ?? outlet?.locationId ?? to.locationId;

/// The room [link] belongs to, by the rule the schedule itself uses.
///
/// **THE SAME ANSWER `_row` COMPUTES**, which is the point: a run's
/// `roomEstimate` is read from `doc.locations[roomId]`, so a derivation
/// looking for "the runs of this room" has to agree with the line that
/// will consume its answer (`LEN-A/3`, DR-050).
///
/// Costs one `_endOf` pair, so it is for callers that have a `Link` and
/// no row. Building a whole schedule to ask this would be the expensive
/// way round.
Uuid? roomOfLink(RackDocument doc, Link link) {
  final conductors = link.conductors;
  if (conductors.isEmpty) return null;
  // THE FIRST CONDUCTOR IS THE CABLE'S FIRST FAR END. A cable may reach N
  // devices (CR-014, DR-236), and a set added to it appends after the
  // conductors already there, so a 16/4 tapped and continued is placed in
  // its first speaker's room. That is the row's room on DR-236 §11.235.3's
  // one Pull Sheet row; where the run continues is the row's far ends.
  final first = conductors.first;
  final endA = _endOf(doc, first.from);
  final endB = _endOf(doc, first.to);
  // ORIENTATION, spelled as `_row` spells it: exactly one end in a rack
  // means that end is TO.
  final flip = endA.isInRack && !endB.isInRack;
  final from = flip ? endB : endA;
  final to = flip ? endA : endB;
  final origin = link.structureOrigin;
  final outlet = origin == null ? null : doc.outlets[origin.outletId];
  return _roomIdOf(from, to, outlet);
}

ScheduleEnd _endOf(RackDocument doc, Endpoint endpoint) => switch (endpoint) {
  PortEndpoint(:final portId) => _portEnd(doc, portId),
  PlaceEndpoint(:final locationId, :final description) => ScheduleEnd(
    kind: ScheduleEndKind.field,
    locationId: locationId,
    roomName: _locationName(doc, locationId),
    description: description,
  ),
  OpenEndpoint(:final description) => ScheduleEnd(
    kind: ScheduleEndKind.open,
    description: description,
  ),
};

ScheduleEnd _portEnd(RackDocument doc, Uuid portId) {
  final port = doc.ports[portId];
  final device = port == null ? null : doc.devices[port.deviceId];
  if (port == null || device == null) {
    // UNRESOLVED, and deliberately not softened. A materialised port
    // always belongs to a device (`port.dart`), so a port endpoint that
    // reaches neither is a document this build cannot explain — the same
    // state `linkClassOf` refuses to classify.
    return const ScheduleEnd(kind: ScheduleEndKind.unresolvedPort);
  }

  // THE SHARED WALK. `hostRackOf` follows a shelf chain (and guards its
  // cycles); reading `placement.rackId` here would drop every
  // shelf-mounted device into "not in a rack" and take its whole row off
  // the Termination Schedule.
  final rackId = hostRackOf(device, doc.devices);
  final rack = rackId == null ? null : doc.racks[rackId];
  final placement = device.placement;
  final rail = placement is RailPlacement ? placement : null;

  final locationId = device.locationId ?? rack?.locationId;
  return ScheduleEnd(
    kind: rackId == null
        ? ScheduleEndKind.unrackedPort
        : ScheduleEndKind.rackPort,
    rackId: rackId,
    rackDesignator: rack?.designator,
    ruIndex: rail?.ruIndex,
    face: rail?.face,
    deviceId: device.id,
    deviceDesignator: device.designator,
    portId: portId,
    portDesignator: port.designator,
    portPositionToken: _positionTokenFor(doc, device, port),
    portLabel: _trimToNull(port.userLabel),
    locationId: locationId,
    roomName: _locationName(doc, locationId),
  );
}

/// The number silkscreened on [port]'s hole, via `panelPositionToken`
/// (DR-054 §11.53.3).
///
/// Null when the join cannot be made, and `null` is right rather than a
/// fallback here: [ScheduleEnd.portCell] falls back to the designator, so
/// a template that cannot be resolved renders exactly what it rendered
/// before this existed. **A default of `port.designator` HERE would be a
/// second fallback saying the same thing in a second place**, which is
/// how two of them come to disagree.
///
/// `bodyFor` returning null is a hand-edited file rather than an
/// impossibility, which is the reading `resolvePortSet` and
/// `connect_target.dart` already take of CR-054.
String? _positionTokenFor(RackDocument doc, DeviceInstance device, Port port) {
  final key = port.templatePortKey;
  if (key == null) return null;
  final body = bodyFor(device, doc.templates);
  if (body == null) return null;
  for (final def in body.ports) {
    if (def.key.v == key.v) return panelPositionToken(def, port.designator);
  }
  return null;
}

String? _locationName(RackDocument doc, Uuid? id) =>
    id == null ? null : _trimToNull(doc.locations[id]?.name);

/// `null` for both "absent" and "present but blank", so a cell renders
/// ONE unknown marker instead of an empty cell for one of them — the
/// identical helper `equipment_list.dart` carries, for the identical
/// reason.
String? _trimToNull(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

// ═════════════════════════════════════════════════════════════════════
// COLUMNS — §3.2 AND §3.3, AS DATA
// ═════════════════════════════════════════════════════════════════════

/// Every column either sheet can carry. One enum, because a column that
/// appears on both sheets must be ONE id — that is what makes
/// [ScheduleEntry.cell] able to guarantee the two sheets print the same
/// string.
enum ScheduleColumnId {
  number,
  cableId,
  type,
  fieldLabel,
  rackLabel,
  fromRoomOutlet,
  toRackRuFace,
  rackRuFace,
  device,
  port,
  farEnd,
  farPort,
  media,
  jacketColor,
  length,
  pathway,

  /// §3.3 column 11, the FIELD end's termination (DR-055 §11.54). Was one
  /// `term` column until DR-055's split was built at M6-K (`#693`).
  fieldTerm,

  /// §3.3 column 12, the RACK end's termination, its punch position and
  /// standard. No fallback to the field end (DR-046).
  rackTerm,
  conductorNotes,
  signOff,

  /// T6.15's `CABLE ID`: the designator and, unless the run is `new`, its
  /// lifecycle suffix (DR-206 §11.205.3). A column of its own rather than
  /// a preset flag on [cableId], so the one cell function answers both
  /// and a printed T6.15 cannot spell the suffix a second way.
  cableIdWithLifecycle,
}

/// T6.15's lifecycle suffix for [status] (DR-206 §11.205.3), or empty for
/// `new`, which is what the sheet is for.
String lifecycleSuffix(LifecycleStatus status) => switch (status) {
  LifecycleStatus.new_ => '',
  LifecycleStatus.existing => 'EX',
  LifecycleStatus.removed => 'RM',
  LifecycleStatus.future => 'FUT',
  LifecycleStatus.designIntent => 'DI',
};

/// The one-line key T6.15 prints whenever a suffix appears on it.
const String kLifecycleSuffixKey =
    'EX existing · RM to remove · FUT future · DI design intent';

/// The Pull Sheet's sections, in the order a crew works down the page
/// (DR-206 §11.205.2): everything it pulls before anything it must not.
enum LifecycleSection {
  toPull('TO PULL'),
  existing('EXISTING'),
  toRemove('TO REMOVE'),
  future('FUTURE');

  const LifecycleSection(this.title);

  /// The section header's words.
  final String title;
}

/// Which Pull Sheet section a run of [status] belongs in. `designIntent`
/// is pulled: its field end is known and only the device is undecided.
LifecycleSection lifecycleSectionOf(LifecycleStatus status) => switch (status) {
  LifecycleStatus.new_ ||
  LifecycleStatus.designIntent => LifecycleSection.toPull,
  LifecycleStatus.existing => LifecycleSection.existing,
  LifecycleStatus.removed => LifecycleSection.toRemove,
  LifecycleStatus.future => LifecycleSection.future,
};

/// One Pull Sheet section's header: how many runs, and their footage with
/// its unknowns counted (G4). Per section, because EXISTING runs are not
/// cable anybody orders, and a total over every section would say so.
typedef ScheduleSectionSummary = ({
  LifecycleSection section,
  int rowCount,
  Rollup<Len> footage,
});

/// Where a cell sits in its column (§3.2/§3.3's `Just.`).
enum ScheduleAlign { left, right, centre }

/// One column of one preset, at §3.2/§3.3's exact width.
@immutable
final class ScheduleColumn {
  const ScheduleColumn({
    required this.id,
    required this.header,
    required this.widthPt,
    this.align = ScheduleAlign.left,
  });

  final ScheduleColumnId id;

  /// EXACTLY as §3.2/§3.3 spell it. `STATUS` is never a header here
  /// (CR-065): three vocabularies were being flown under that one word.
  final String header;

  /// Points. §3.2's ten widths sum to 510 (ANSI A portrait usable);
  /// §3.3's twelve sum to 690 (landscape). `schedule_test.dart` asserts
  /// both sums, because a column table that no longer fits its page is a
  /// defect the eye does not catch.
  final double widthPt;

  final ScheduleAlign align;
}

/// §3.2 — the Pull Sheet's ten columns, portrait, Σ 510 pt.
///
/// Column 8 `LEN` is right-aligned; column 10 `SIGN-OFF` is centred.
/// Everything else is left.
const List<ScheduleColumn> kPullSheetColumns = <ScheduleColumn>[
  ScheduleColumn(id: ScheduleColumnId.cableId, header: 'CABLE ID', widthPt: 52),
  ScheduleColumn(id: ScheduleColumnId.type, header: 'TYPE', widthPt: 44),
  ScheduleColumn(
    id: ScheduleColumnId.fieldLabel,
    header: 'FIELD LABEL',
    widthPt: 54,
  ),
  ScheduleColumn(
    id: ScheduleColumnId.rackLabel,
    header: 'RACK LABEL',
    widthPt: 50,
  ),
  ScheduleColumn(
    id: ScheduleColumnId.fromRoomOutlet,
    header: 'FROM — ROOM / OUTLET',
    widthPt: 68,
  ),
  ScheduleColumn(
    id: ScheduleColumnId.toRackRuFace,
    header: 'TO — RACK / RU / FACE',
    widthPt: 64,
  ),
  ScheduleColumn(id: ScheduleColumnId.media, header: 'MEDIA', widthPt: 58),
  ScheduleColumn(
    id: ScheduleColumnId.length,
    header: 'LEN',
    widthPt: 28,
    align: ScheduleAlign.right,
  ),
  ScheduleColumn(id: ScheduleColumnId.pathway, header: 'PATHWAY', widthPt: 36),
  ScheduleColumn(
    id: ScheduleColumnId.signOff,
    header: 'SIGN-OFF',
    widthPt: 56,
    align: ScheduleAlign.centre,
  ),
];

/// §3.3 — the Termination Schedule's twelve columns, landscape, Σ 690 pt.
///
/// **THIRTEEN COLUMNS, DR-055's, BUILT AT M6-K (`#693`).** `TERM` is retired
/// for `FIELD TERM` 44 and `RACK TERM` 44, taking width from
/// `CONDUCTOR / NOTES` 66 to 44 and `MEDIA` 56 to 42, so Σ stays 690.
///
/// `RACK TERM` gets **no fallback**. `_terminationOf`'s `PlaceEndpoint`
/// chain belongs to the field end alone, and copying one end onto the
/// other is the defect DR-046 removed from the model.
///
/// **THIS COMMENT SAID "NOTHING RENDERS THIS CONSTANT TODAY" WHILE THE
/// SCHEDULE SCREEN DID**, through `ScheduleView.columns`. Both the screen
/// and the printed `T6.15` read it, which is the point: one column set,
/// so the page and the screen cannot disagree about a termination.
const List<ScheduleColumn> kTerminationScheduleColumns = <ScheduleColumn>[
  // DR-206 §11.205.3: the lifecycle rides here, at no width.
  ScheduleColumn(
    id: ScheduleColumnId.cableIdWithLifecycle,
    header: 'CABLE ID',
    widthPt: 56,
  ),
  ScheduleColumn(id: ScheduleColumnId.type, header: 'TYPE', widthPt: 44),
  ScheduleColumn(
    id: ScheduleColumnId.rackLabel,
    header: 'RACK LABEL',
    widthPt: 52,
  ),
  ScheduleColumn(
    id: ScheduleColumnId.fieldLabel,
    header: 'FIELD LABEL',
    widthPt: 52,
  ),
  ScheduleColumn(
    id: ScheduleColumnId.rackRuFace,
    header: 'RACK / RU / FACE',
    widthPt: 62,
  ),
  ScheduleColumn(id: ScheduleColumnId.device, header: 'DEVICE', widthPt: 74),
  ScheduleColumn(id: ScheduleColumnId.port, header: 'PORT', widthPt: 46),
  ScheduleColumn(id: ScheduleColumnId.farEnd, header: 'FAR END', widthPt: 84),
  ScheduleColumn(
    id: ScheduleColumnId.farPort,
    header: 'FAR PORT',
    widthPt: 46,
  ),
  ScheduleColumn(id: ScheduleColumnId.media, header: 'MEDIA', widthPt: 42),
  ScheduleColumn(
    id: ScheduleColumnId.fieldTerm,
    header: 'FIELD TERM',
    widthPt: 44,
  ),
  ScheduleColumn(
    id: ScheduleColumnId.rackTerm,
    header: 'RACK TERM',
    widthPt: 44,
  ),
  ScheduleColumn(
    id: ScheduleColumnId.conductorNotes,
    header: 'CONDUCTOR / NOTES',
    widthPt: 44,
  ),
];

/// §3.1's jacket-colour column, which is OPTIONAL and therefore not in
/// either fixed set: "jacket colour is an OPTIONAL column that has to
/// steal width from one of them" (`jacket_color.dart`). Declared here so
/// a caller enabling it uses one width rather than choosing its own, and
/// so `JacketColorDef.abbr` — three characters, chosen precisely because
/// the Pull Sheet's 510 pt is already spoken for — has somewhere to land.
const ScheduleColumn kJacketColorColumn = ScheduleColumn(
  id: ScheduleColumnId.jacketColor,
  header: 'JACKET',
  widthPt: 34,
);

// ═════════════════════════════════════════════════════════════════════
// PRESETS, SORT AND GROUPING
// ═════════════════════════════════════════════════════════════════════

/// §3.1's two presets.
enum SchedulePreset {
  /// `T6.10` — ANSI A portrait, room then pathway, field cables only,
  /// per-room footage subtotals and a sign-off block.
  pullSheet,

  /// `T6.15` — ANSI A landscape, rack then panel then port, every cable
  /// landing in a rack.
  terminationSchedule;

  /// The id of this preset's FIRST printed page: the Schedule screen's
  /// picker shows it, so it names the same sheet the paper does. `T6.15`
  /// since DR-222 §11.221.1 (it was `T6.15`, which left a second Pull
  /// Sheet page no id); `sheet_def.dart`'s block constants are the ones
  /// the set is numbered from, and a test holds the two equal.
  String get sheetId => switch (this) {
    SchedulePreset.pullSheet => 'T6.10',
    SchedulePreset.terminationSchedule => 'T6.15',
  };

  String get title => switch (this) {
    SchedulePreset.pullSheet => 'PULL SHEET',
    SchedulePreset.terminationSchedule => 'TERMINATION SCHEDULE',
  };

  List<ScheduleColumn> get columns => switch (this) {
    SchedulePreset.pullSheet => kPullSheetColumns,
    SchedulePreset.terminationSchedule => kTerminationScheduleColumns,
  };

  ScheduleSort get defaultSort => switch (this) {
    SchedulePreset.pullSheet => ScheduleSort.roomThenPathway,
    SchedulePreset.terminationSchedule => ScheduleSort.rackThenPanelThenPort,
  };

  ScheduleGrouping get defaultGrouping => switch (this) {
    SchedulePreset.pullSheet => ScheduleGrouping.room,
    SchedulePreset.terminationSchedule => ScheduleGrouping.rack,
  };
}

/// §3.6's sort keys. Single-select, each with a stable secondary sort on
/// `Link.designator` and a final tiebreak on the link id, so every one of
/// them is a TOTAL order (§8.4: two exports of an unmodified project
/// produce the identical table).
enum ScheduleSort {
  /// Reference lookup — someone reads a label in a rack and wants the row.
  designator,

  /// Pull Sheet default (AC-025) — the order the tech walks the house.
  roomThenPathway,

  /// Termination Schedule default — terminate one panel at a time.
  rackThenPanelThenPort,

  /// Pull by trade: all the Cat6, then all the speaker wire.
  domainThenFamily,

  /// Terminate one device at a time.
  fromDeviceThenPort,

  /// Reel planning and cut lists.
  cutLengthDescending,

  /// Punch list.
  roughInStatus,
}

/// §3.6's grouping, orthogonal to the sort.
enum ScheduleGrouping { none, room, rack, pathway, domain }

// ═════════════════════════════════════════════════════════════════════
// THE PROJECTION
// ═════════════════════════════════════════════════════════════════════

/// The band title for rows whose class could not be determined.
///
/// A SEPARATE GROUP, not a flag on a row inside a room. Its footage must
/// not join a room's subtotal: a subtotal that silently includes a run
/// nobody has established is a pull is the fabricated number G4 forbids,
/// and it is the number an installer orders cable against. Modelled on
/// `equipment_list.dart`'s trailing `NOT IN A RACK` group.
const String kUndeterminedClassGroupTitle = 'CLASS NOT DETERMINED';

/// The band title for rows the grouping key cannot place.
const String kUngroupedTitle = 'NO ROOM RECORDED';

/// One §3.6 group band: `▌ NETWORK — 24 runs ──── 1,860 ft total`.
@immutable
final class ScheduleGroup {
  const ScheduleGroup({
    required this.key,
    required this.title,
    required this.rows,
    required this.footage,
    required this.estimatedCount,
    required this.computedEstimateCount,
    required this.boundCount,
    required this.isUndeterminedClass,
    this.section,
  });

  /// The Pull Sheet section this band sits in (DR-206 §11.205.2), or null
  /// on a preset that is not sectioned.
  final LifecycleSection? section;

  /// The grouping value, or null for a catch-all band.
  final Uuid? key;

  final String title;
  final List<ScheduleEntry> rows;

  /// Σ of this band's known lengths, WITH the count of rows that could
  /// not supply one — built exactly as `totals.dart` builds its rollups,
  /// so a subtotal is never a number with unstated ignorance behind it.
  final Rollup<Len> footage;

  /// How many of [footage]'s contributors were ESTIMATES rather than cut
  /// lengths (§3.2's italic). A subtotal of estimates is not a subtotal
  /// of measurements, and §3.8's own footer says so out loud:
  /// `Σ 11 runs · 601 ft · 3 estimated (italic)`.
  final int estimatedCount;

  /// How many of [estimatedCount] the PLAN proposed rather than a person
  /// entering them (DR-050 §11.49.3, `LEN-A/5`).
  ///
  /// **A SUBSET OF [estimatedCount], AND THE ONLY ONE OF THESE COUNTS
  /// THAT IS.** `boundCount` is disjoint from it on purpose and says so;
  /// this one narrows the same population rather than naming a different
  /// one, because §11.49.3's question is asked ABOUT an estimate: *"did
  /// somebody measure this room or did the software guess it"*.
  ///
  /// It reaches a takeoff for the reason `estimatedCount` does. That
  /// figure exists so a reader knows how much of a total rests on
  /// estimates; this is the same question one turn finer, in the place
  /// somebody is about to spend money on the answer.
  final int computedEstimateCount;

  /// How many rows in this band print a plan-derived FLOOR rather than a
  /// length (DR-147 §11.146.3).
  ///
  /// **NOT A SUBSET OF [estimatedCount] AND NOT A CONTRIBUTOR TO
  /// [footage].** These rows are excluded from the `Σ` and counted here,
  /// which is `Rollup.unknownCount`'s own discipline applied to a
  /// narrower ignorance: the band does not know how much cable this is,
  /// and it does know it is at least something.
  final int boundCount;

  /// True for the [kUndeterminedClassGroupTitle] band.
  final bool isUndeterminedClass;

  int get rowCount => rows.length;
}

/// Why rows are not on this sheet, counted by reason.
///
/// EVERY EXCLUSION IS A NUMBER. §3.1 excludes jumpers and power cords "by
/// default, with a toggle" because "110 rows of factory patch cords in a
/// 180-row schedule make the 70 rows describing real pulls
/// indistinguishable from noise" — a good reason to hide them and no
/// reason at all to hide THAT they are hidden.
@immutable
final class ScheduleExclusions {
  const ScheduleExclusions({
    required this.jumpers,
    required this.powerCords,
    required this.internal,
    required this.notLandingInRack,
  });

  static const ScheduleExclusions none = ScheduleExclusions(
    jumpers: 0,
    powerCords: 0,
    internal: 0,
    notLandingInRack: 0,
  );

  final int jumpers;
  final int powerCords;

  /// `LinkClass.internal` — a link inside one device. Nobody pulls it and
  /// nobody terminates it in the field, so it is off the Pull Sheet
  /// unconditionally; §3.1's toggle is about jumpers and power cords.
  final int internal;

  /// Termination Schedule only: a cable that lands in no rack has no
  /// panel and no port to terminate.
  final int notLandingInRack;

  int get total => jumpers + powerCords + internal + notLandingInRack;
}

/// The jacket-colour rollup §3.1's cell needs, and the one
/// `jacket_color_resolution.dart`'s footer said would "come back WITH ITS
/// CONSUMER — the exceptions sheet, or the Schedule tab's colour column".
/// This is that consumer, and this is the fifteen-line loop it predicted.
@immutable
final class ScheduleJacketRollup {
  const ScheduleJacketRollup({
    required this.recorded,
    required this.unrecorded,
    required this.exceptions,
    required this.unknownEntries,
  });

  /// Rows whose run states a jacket colour of some kind.
  final int recorded;

  /// Rows where nobody has said. Not an error and not a default.
  final int unrecorded;

  /// Rows pulled in a colour the convention does not call for — the
  /// `BLU→YEL` rows. THE NUMBER THE FEATURE EXISTS FOR.
  final int exceptions;

  /// Rows carrying an id that names no convention entry. Counted and
  /// shown as unknown, never substituted (G4).
  final int unknownEntries;
}

/// One preset's projection of a [Schedule] — the filtered, sorted,
/// grouped rows plus every number a reader needs to trust them.
@immutable
final class ScheduleView {
  const ScheduleView({
    required this.preset,
    required this.sort,
    required this.grouping,
    required this.columns,
    required this.groups,
    required this.sourceRowCount,
    required this.exclusions,
    required this.footage,
    required this.estimatedCount,
    required this.computedEstimateCount,
    required this.boundCount,
    required this.undeterminedClassCount,
    required this.classDisagreementCount,
    required this.jacket,
    required this.conductorColorUnknownCount,
    required this.unresolvedMediaCount,
    required this.unresolvedSignalFamilyCount,
    required this.missingFieldLabelCount,
    required this.missingRackLabelCount,
    this.sections = const [],
    this.lifecycleKey,
  });

  final SchedulePreset preset;
  final ScheduleSort sort;
  final ScheduleGrouping grouping;

  /// The Pull Sheet's non-empty lifecycle sections, in order, each with
  /// its count and footage (DR-206 §11.205.2). Empty on other presets.
  final List<ScheduleSectionSummary> sections;

  /// [kLifecycleSuffixKey] when a `CABLE ID` on this view carries a
  /// lifecycle suffix (DR-206 §11.205.3), else null, so the key appears
  /// exactly when there is something for it to explain.
  final String? lifecycleKey;

  /// §3.2/§3.3's column table for this preset.
  final List<ScheduleColumn> columns;

  final List<ScheduleGroup> groups;

  /// How many rows the [Schedule] held before this preset filtered it.
  /// `sourceRowCount - rowCount == exclusions.total` is an invariant, and
  /// a test asserts it: the two numbers reconciling is what makes
  /// "nothing was silently dropped" checkable rather than claimed.
  final int sourceRowCount;

  final ScheduleExclusions exclusions;

  /// Σ of every shown row's length, unknowns COUNTED (G4).
  final Rollup<Len> footage;

  /// How many of those lengths are estimates (§3.8's
  /// `3 estimated (italic)`).
  final int estimatedCount;

  /// How many of [estimatedCount] the PLAN proposed (DR-050 §11.49.3).
  /// A SUBSET of it, unlike [boundCount], which is disjoint on purpose.
  final int computedEstimateCount;

  /// How many shown rows print a plan-derived FLOOR rather than a length
  /// (DR-147 §11.146.3). Excluded from [footage] and counted here.
  final int boundCount;

  /// Rows whose class `effectiveLinkClassOf` could not determine. Shown
  /// in their own band AND stated as a number — see the file header.
  final int undeterminedClassCount;

  /// Rows where a person's class and the classifier disagree (DR-008
  /// §11.8.2).
  final int classDisagreementCount;

  final ScheduleJacketRollup jacket;

  /// Conductors across all shown rows that state no colour — the exit
  /// criterion's "where they exist", quantified.
  final int conductorColorUnknownCount;

  /// Rows whose `MediaTypeId` names no registry entry.
  final int unresolvedMediaCount;

  /// Rows whose `SignalFamilyId` names no registry entry. This was every
  /// row in every document until DR-010 §11.10 seeded the registries;
  /// documents saved before it keep empty maps and are NOT migrated, so
  /// the count stays meaningful. Counted rather than papered over.
  final int unresolvedSignalFamilyCount;

  /// §3.1's "both labels, on both ends" made checkable. A row missing one
  /// is not an error — a jumper has no wall plate — but the count is what
  /// turns the M2 exit criterion into something a test can read.
  final int missingFieldLabelCount;
  final int missingRackLabelCount;

  /// Every shown row, in sheet order.
  Iterable<ScheduleEntry> get rows => groups.expand((g) => g.rows);

  int get rowCount => groups.fold(0, (n, g) => n + g.rows.length);

  /// True when this document has no cables at all — distinct from "every
  /// cable was filtered out", which [exclusions] describes. The Schedule
  /// tab must say something different in each case: an empty project has
  /// no schedule, and a schedule with everything hidden has a toggle.
  bool get isEmptyDocument => sourceRowCount == 0;
}

/// Projects [schedule] through [preset] — §3.1's "same query, same row
/// model, different projection", and the only place a preset differs from
/// another.
///
/// [includeJumpersAndPowerCords] is AC-026's toggle, defaulting to the
/// exclusion §3.1 specifies.
ScheduleView buildScheduleView(
  Schedule schedule, {
  required SchedulePreset preset,
  ScheduleSort? sort,
  ScheduleGrouping? grouping,
  bool includeJumpersAndPowerCords = false,
}) {
  final effectiveSort = sort ?? preset.defaultSort;
  final effectiveGrouping = grouping ?? preset.defaultGrouping;

  var jumpers = 0;
  var powerCords = 0;
  var internal = 0;
  var notLandingInRack = 0;

  final kept = <ScheduleEntry>[];
  for (final row in schedule.rows) {
    // UNDETERMINED IS NEVER EXCLUDED. It is not a class, so it cannot be
    // filtered by class; it is shown, in its own band, and counted.
    if (!row.isClassUndetermined) {
      final cls = row.linkClass!;
      if (!includeJumpersAndPowerCords && cls == LinkClass.jumper) {
        jumpers++;
        continue;
      }
      if (!includeJumpersAndPowerCords && cls == LinkClass.powerCord) {
        powerCords++;
        continue;
      }
      if (cls == LinkClass.internal && preset == SchedulePreset.pullSheet) {
        internal++;
        continue;
      }
    }
    if (preset == SchedulePreset.terminationSchedule && !row.landsInRack) {
      notLandingInRack++;
      continue;
    }
    kept.add(row);
  }

  kept.sort(_comparatorFor(effectiveSort));

  return ScheduleView(
    preset: preset,
    sort: effectiveSort,
    grouping: effectiveGrouping,
    columns: preset.columns,
    groups: _group(
      kept,
      effectiveGrouping,
      sectioned: preset == SchedulePreset.pullSheet,
    ),
    sections: preset == SchedulePreset.pullSheet
        ? [
            for (final section in LifecycleSection.values)
              if ([
                    for (final r in kept)
                      if (lifecycleSectionOf(r.lifecycleStatus) == section) r,
                  ]
                  case final rows when rows.isNotEmpty)
                (
                  section: section,
                  rowCount: rows.length,
                  footage: _footageOf(rows),
                ),
          ]
        : const [],
    lifecycleKey:
        preset.columns.any(
              (c) => c.id == ScheduleColumnId.cableIdWithLifecycle,
            ) &&
            kept.any((r) => lifecycleSuffix(r.lifecycleStatus).isNotEmpty)
        ? kLifecycleSuffixKey
        : null,
    sourceRowCount: schedule.rowCount,
    exclusions: ScheduleExclusions(
      jumpers: jumpers,
      powerCords: powerCords,
      internal: internal,
      notLandingInRack: notLandingInRack,
    ),
    footage: _footageOf(kept),
    estimatedCount: kept.where((r) => r.lengthIsEstimated).length,
    computedEstimateCount: kept.where((r) => r.estimateIsComputed).length,
    boundCount: kept.where((r) => r.lengthIsBound).length,
    undeterminedClassCount: kept.where((r) => r.isClassUndetermined).length,
    classDisagreementCount: kept.where((r) => r.hasClassDisagreement).length,
    jacket: _jacketRollup(kept),
    conductorColorUnknownCount: kept.fold(
      0,
      (n, r) => n + r.conductorColorUnknownCount,
    ),
    unresolvedMediaCount: kept.where((r) => r.media == null).length,
    unresolvedSignalFamilyCount: kept
        .where((r) => r.signalFamily == null)
        .length,
    missingFieldLabelCount: kept.where((r) => r.fieldLabel == null).length,
    missingRackLabelCount: kept.where((r) => r.rackLabel == null).length,
  );
}

/// Convenience: derive and project in one call, for a caller that wants
/// one sheet. Two sheets should [buildSchedule] ONCE and project twice —
/// that is the point of the split, and it is what makes the two agree.
///
/// Only tests call this (#945): it is a handle on live logic, not logic of its
/// own, so it stays and the analyzer keeps it out of lib/.
@visibleForTesting
ScheduleView scheduleViewOf(
  RackDocument doc, {
  required SchedulePreset preset,
  ScheduleSort? sort,
  ScheduleGrouping? grouping,
  bool includeJumpersAndPowerCords = false,
}) => buildScheduleView(
  buildSchedule(doc),
  preset: preset,
  sort: sort,
  grouping: grouping,
  includeJumpersAndPowerCords: includeJumpersAndPowerCords,
);

// ─── grouping ────────────────────────────────────────────────────────

/// [rows] banded by [grouping], and on a SECTIONED preset (the Pull
/// Sheet, DR-206 §11.205.2) banded once per lifecycle section, in
/// [LifecycleSection]'s order, so a room with pulls and existing runs
/// appears under TO PULL and again under EXISTING. An empty section has
/// no bands, so it is not drawn. [rows] is already sorted and a
/// partition keeps order, so each section's bands still follow the sort.
List<ScheduleGroup> _group(
  List<ScheduleEntry> rows,
  ScheduleGrouping grouping, {
  required bool sectioned,
}) {
  if (!sectioned) return _groupWithin(rows, grouping);
  return List.unmodifiable([
    for (final section in LifecycleSection.values)
      ..._groupWithin(
        [
          for (final r in rows)
            if (lifecycleSectionOf(r.lifecycleStatus) == section) r,
        ],
        grouping,
        section: section,
      ),
  ]);
}

List<ScheduleGroup> _groupWithin(
  List<ScheduleEntry> rows,
  ScheduleGrouping grouping, {
  LifecycleSection? section,
}) {
  // THE UNDETERMINED BAND IS PARTITIONED OFF FIRST, whatever the
  // grouping. See [kUndeterminedClassGroupTitle].
  final undetermined = <ScheduleEntry>[];
  final placed = <ScheduleEntry>[];
  for (final row in rows) {
    (row.isClassUndetermined ? undetermined : placed).add(row);
  }

  final bands = <ScheduleGroup>[];
  if (grouping == ScheduleGrouping.none) {
    if (placed.isNotEmpty) {
      bands.add(
        _band(
          null,
          kAllRunsTitle,
          placed,
          isUndetermined: false,
          section: section,
        ),
      );
    }
  } else {
    // Dart's default `Map` is INSERTION-ORDERED BY SPECIFICATION, and
    // `placed` is already sorted — so the bands come out in the sort's
    // own order without a second comparator that could disagree with it.
    // (This is not the "relying on Map iteration order" that
    // `equipment_list.dart` bans: that is about HASH order, which is
    // unspecified. Insertion order is a language guarantee.)
    final byKey = <String, List<ScheduleEntry>>{};
    final titles = <String, String>{};
    final keys = <String, Uuid?>{};
    for (final row in placed) {
      final (Uuid? key, String title) = _groupKeyOf(row, grouping);
      // Namespaced so a `Uuid` string can never collide with a title.
      final mapKey = key == null ? 'title:$title' : 'id:${key.v}';
      byKey.putIfAbsent(mapKey, () => <ScheduleEntry>[]).add(row);
      titles[mapKey] = title;
      keys[mapKey] = key;
    }
    for (final entry in byKey.entries) {
      bands.add(
        _band(
          keys[entry.key],
          titles[entry.key]!,
          entry.value,
          isUndetermined: false,
          section: section,
        ),
      );
    }
  }

  if (undetermined.isNotEmpty) {
    bands.add(
      _band(
        null,
        kUndeterminedClassGroupTitle,
        undetermined,
        isUndetermined: true,
        section: section,
      ),
    );
  }
  return List.unmodifiable(bands);
}

/// The band title when nothing is grouped — still a band, so a renderer
/// has one shape to draw rather than two.
const String kAllRunsTitle = 'ALL RUNS';

(Uuid?, String) _groupKeyOf(ScheduleEntry row, ScheduleGrouping grouping) =>
    switch (grouping) {
      ScheduleGrouping.none => (null, kAllRunsTitle),
      ScheduleGrouping.room => (
        row.roomId,
        row.roomName ?? kUngroupedTitle,
      ),
      ScheduleGrouping.rack => (
        row.nearEnd.rackId,
        row.nearEnd.rackDesignator ?? kNotInARackCell,
      ),
      // THE SAME VALUE THE CELL PRINTS, deliberately. A band headed `T1`
      // over rows whose own `PATHWAY` cells read "attic run to the garage"
      // is a sheet disagreeing with itself, and this corpus has shipped
      // that shape twice from one number computed two ways.
      ScheduleGrouping.pathway => (
        row.pathwayId,
        row.pathwayLabel ?? kNoPathwayGroupTitle,
      ),
      // The domain is a registry def, not an entity, so it has no `Uuid`
      // to key on — the title carries the identity and the null key says
      // "this band is not an entity".
      ScheduleGrouping.domain => (
        null,
        row.signalDomain?.displayName ??
            row.signalFamilyId?.v ??
            kNoDomainGroupTitle,
      ),
    };

/// The band title for rows with no pathway assigned.
const String kNoPathwayGroupTitle = 'NO PATHWAY RECORDED';

/// The band title for rows whose signal domain does not resolve.
const String kNoDomainGroupTitle = 'DOMAIN NOT RECORDED';

ScheduleGroup _band(
  Uuid? key,
  String title,
  List<ScheduleEntry> rows, {
  required bool isUndetermined,
  LifecycleSection? section,
}) => ScheduleGroup(
  key: key,
  title: title,
  section: section,
  rows: List.unmodifiable(rows),
  footage: _footageOf(rows),
  estimatedCount: rows.where((r) => r.lengthIsEstimated).length,
  computedEstimateCount: rows.where((r) => r.estimateIsComputed).length,
  boundCount: rows.where((r) => r.lengthIsBound).length,
  isUndeterminedClass: isUndetermined,
);

/// Rule 1 applied to footage, through `Rollup.fromScan` — where the rule
/// is spelled. This used to restate the ternary under a comment naming
/// `totals.dart`, which is the shape that lets a rule drift.
Rollup<Len> _footageOf(List<ScheduleEntry> rows) {
  var sum = Len.zero;
  var known = 0;
  var unknown = 0;
  for (final row in rows) {
    // A BOUND IS NOT A QUANTITY HERE EITHER, AND THIS IS THE ROLLUP THE
    // BOOBY TRAP DID NOT GUARD (DR-147 §11.146.1). `cable_footage.dart`'s
    // `_isQuantity` is an exhaustive switch that stops the build when a
    // source is added; this function reads a `Len?` and never asks where
    // it came from, so a floor would have walked into §3.8's
    // `Σ 11 runs · 601 ft` footer with nothing to stop it. A `Σ` holding
    // one floor and ten totals is neither a floor nor a total.
    //
    // COUNTED AS UNKNOWN, WHICH IS NOT A DEMOTION: the question this
    // rollup answers is how much cable this sheet is, and a floor answers
    // it not at all. `ScheduleView.boundCount` says how much of that
    // ignorance has a floor under it, which is strictly more than the
    // reader had before.
    final length = row.lengthIsBound ? null : row.length;
    if (length == null) {
      unknown++;
    } else {
      sum += length;
      known++;
    }
  }
  return Rollup<Len>.fromScan(
    sum: sum,
    knownCount: known,
    unknownCount: unknown,
  );
}

ScheduleJacketRollup _jacketRollup(List<ScheduleEntry> rows) {
  var recorded = 0;
  var unrecorded = 0;
  var exceptions = 0;
  var unknownEntries = 0;
  for (final row in rows) {
    final jacket = row.jacketColor;
    if (jacket.asBuiltColorId == null) {
      unrecorded++;
    } else {
      recorded++;
    }
    if (jacket.isException) exceptions++;
    if (jacket.hasUnknownEntry) unknownEntries++;
  }
  return ScheduleJacketRollup(
    recorded: recorded,
    unrecorded: unrecorded,
    exceptions: exceptions,
    unknownEntries: unknownEntries,
  );
}

// ─── sorting ─────────────────────────────────────────────────────────

Comparator<ScheduleEntry> _comparatorFor(ScheduleSort sort) => switch (sort) {
  ScheduleSort.designator => _byDesignator,
  ScheduleSort.roomThenPathway => (a, b) => _chain([
    () => _compareNullableText(a.roomName, b.roomName),
    // Sorts on what the column prints, so the order a reader sees matches
    // the values they are reading. Ends in `_byDesignator`, which is
    // unique, so the chain stays TOTAL (Dart's List.sort is not stable).
    () => _compareNullableText(a.pathwayLabel, b.pathwayLabel),
    () => _byDesignator(a, b),
  ]),
  ScheduleSort.rackThenPanelThenPort => (a, b) => _chain([
    () => _compareNullableText(
      a.nearEnd.rackDesignator,
      b.nearEnd.rackDesignator,
    ),
    () => _compareNullableText(
      a.nearEnd.deviceDesignator,
      b.nearEnd.deviceDesignator,
    ),
    () => _compareNullableText(
      a.nearEnd.portDesignator,
      b.nearEnd.portDesignator,
    ),
    () => _byDesignator(a, b),
  ]),
  ScheduleSort.domainThenFamily => (a, b) => _chain([
    () => _compareNullableText(
      a.signalDomain?.displayName,
      b.signalDomain?.displayName,
    ),
    () => _compareNullableText(
      a.signalFamilyId?.v,
      b.signalFamilyId?.v,
    ),
    () => _byDesignator(a, b),
  ]),
  ScheduleSort.fromDeviceThenPort => (a, b) => _chain([
    () => _compareNullableText(
      a.from.deviceDesignator,
      b.from.deviceDesignator,
    ),
    () => _compareNullableText(
      a.from.portDesignator,
      b.from.portDesignator,
    ),
    () => _byDesignator(a, b),
  ]),
  ScheduleSort.cutLengthDescending => (a, b) => _chain([
    // DESCENDING IS A FLAG, NOT SWAPPED ARGUMENTS, and that is the whole
    // point of the parameter. This shipped for one build as
    // `_compareNullableLength(b.length, a.length)` — which reverses the
    // NULL handling along with the values and put every unknown length
    // at the TOP of a reel-planning list, above the longest known run.
    // `cutLength descending still puts unknown lengths last` is the test
    // that caught it.
    () => _compareNullableLength(a.length, b.length, descending: true),
    () => _byDesignator(a, b),
  ]),
  ScheduleSort.roughInStatus => (a, b) => _chain([
    () => a.roughInStatus.index.compareTo(b.roughInStatus.index),
    () => _byDesignator(a, b),
  ]),
};

/// §3.6's stable secondary sort, plus the id tiebreak that makes every
/// order in this file TOTAL.
int _byDesignator(ScheduleEntry a, ScheduleEntry b) {
  final byDesignator = compareDesignators(a.designator, b.designator);
  return byDesignator != 0 ? byDesignator : a.linkId.v.compareTo(b.linkId.v);
}

/// Runs [steps] until one is decisive. A helper rather than nested
/// ternaries because a sort chain that is hard to read is a sort chain
/// whose second key silently stops being applied.
int _chain(List<int Function()> steps) {
  for (final step in steps) {
    final result = step();
    if (result != 0) return result;
  }
  return 0;
}

/// NULLS LAST, always and everywhere in this file.
///
/// A row with no room, no pathway or no rack sorts after every row that
/// has one. The alternative — nulls first — puts the rows nobody has
/// finished describing at the top of the sheet an installer works down,
/// which is precisely backwards.
int _compareNullableText(String? a, String? b) {
  if (a == null && b == null) return 0;
  if (a == null) return 1;
  if (b == null) return -1;
  return compareDesignators(a, b);
}

/// Same rule as [_compareNullableText]: NULLS LAST — in BOTH directions.
///
/// "We do not know how long this is" is not the longest run and it is not
/// the shortest one; it belongs at the end of the list either way. Only
/// the KNOWN values reverse when [descending] is set.
int _compareNullableLength(Len? a, Len? b, {required bool descending}) {
  if (a == null && b == null) return 0;
  if (a == null) return 1;
  if (b == null) return -1;
  return descending ? b.nm.compareTo(a.nm) : a.nm.compareTo(b.nm);
}

/// Compares two designators the way a human reads them: `W2` before
/// `W10`, `RK-2` before `RK-10`, `A2` before `A10`.
///
/// WHY NOT A PLAIN STRING COMPARE. The default formats
/// (`ProjectSettings.linkDesignatorFormat` is `W{SEQ:3}`,
/// `portDesignatorFormat` is `J{PORT_SEQ:2}`) zero-pad, and padded ids
/// sort correctly either way. Hand-set and imported ones do not: a
/// lexicographic sheet puts `A10` between `A1` and `A2`, and §3.3's whole
/// promise is that you terminate a panel top to bottom without hunting.
///
/// Deterministic and total: digit runs compare numerically, everything
/// else compares by code unit, and equal-under-those strings fall back to
/// the raw comparison so two different strings never compare equal.
int compareDesignators(String a, String b) {
  final natural = _compareNatural(a, b);
  return natural != 0 ? natural : a.compareTo(b);
}

int _compareNatural(String a, String b) {
  var i = 0;
  var j = 0;
  while (i < a.length && j < b.length) {
    final ca = a.codeUnitAt(i);
    final cb = b.codeUnitAt(j);
    final aDigit = _isDigit(ca);
    final bDigit = _isDigit(cb);
    if (aDigit && bDigit) {
      final startA = i;
      final startB = j;
      while (i < a.length && _isDigit(a.codeUnitAt(i))) {
        i++;
      }
      while (j < b.length && _isDigit(b.codeUnitAt(j))) {
        j++;
      }
      // Parsed rather than compared digit by digit so `007` and `7` land
      // on the same value; `int.parse` is safe here because the run is
      // digits by construction, but a pathological 30-digit run would
      // overflow, so the length guard falls back to a string compare.
      final runA = a.substring(startA, i);
      final runB = b.substring(startB, j);
      if (runA.length > 18 || runB.length > 18) {
        final byRun = runA.compareTo(runB);
        if (byRun != 0) return byRun;
      } else {
        final byValue = int.parse(runA).compareTo(int.parse(runB));
        if (byValue != 0) return byValue;
      }
      continue;
    }
    if (ca != cb) return ca.compareTo(cb);
    i++;
    j++;
  }
  return (a.length - i).compareTo(b.length - j);
}

bool _isDigit(int codeUnit) => codeUnit >= 0x30 && codeUnit <= 0x39;
