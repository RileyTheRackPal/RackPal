// packages/rackpal_core/lib/src/model/gang.dart
//
// THE INSIDE OF A LOW-VOLTAGE BOX (DR-007 §11.7). An `Outlet` is one wall
// plate; this is what is behind it.
//
//   Outlet            one wall plate / one ceiling location [CR-016]
//     └─ Gang × N     one gang opening, ORDERED             [DR-007 §11.7.3]
//          └─ fitting Strap, or a PassThrough               [DR-047 §11.46.2]
//               └─ cell  one occupant, or nothing at all
//
// ═════════════════════════════════════════════════════════════════════
// AN OPENING IS NOT ALWAYS A STRAP (DR-047 §11.46)
// ═════════════════════════════════════════════════════════════════════
// A brush or bull-nose plate is a plate with a hole in it and nothing
// behind the hole. Until DR-047 this file could not say that, because
// `Gang.strap` was `Strap?` and null already meant SOMETHING ELSE:
// nobody has picked a part yet.
//
// So [GangFitting] is sealed and [Strap] is one case of it. The rename
// from `strap` to `fitting` is deliberate and the sealed switch is the
// point: every reader now has to say which of the three states it means,
// and no getter hands back null for a pass-through, because that is
// exactly the collapse the ruling removes.
//
// ═════════════════════════════════════════════════════════════════════
// BUILT FROM THE RULING AS IT NOW STANDS, NOT FROM THE REQUEST
// ═════════════════════════════════════════════════════════════════════
// DR-007 was refined three times and §11.7.2 was SUPERSEDED on
// 2026-07-28: EVERY OCCUPANT IS 1 × 1, a speaker binding post included.
// The original request described a dual-post speaker module spanning two
// cells, and the ruling had already built the expensive branch from it:
// multi-cell occupants, an orientation axis, a "forced on 1-wide, free on
// 2-wide" constraint, a refusal message for the forced case, and a
// packing search. A photograph of the actual part deleted all five.
//
// So there is no `orientation` field here, no occupant span, and no
// placement search. A cell is free or it is taken. Anything in this file
// that looks suspiciously simple is simple because a physical part said
// so, and re-deriving it from the original request would rebuild a
// subsystem for a problem that does not exist.
//
// ═════════════════════════════════════════════════════════════════════
// A GANG HAS NO ID, AND THAT IS `ConductorRef`'S ARGUMENT
// ═════════════════════════════════════════════════════════════════════
// Gangs are addressed by `(outletId, gangIndex)` — POSITION, not a minted
// uuid — for the reason `conductor.dart` gives at length for its own
// child type: minting an id puts a field on the wire (CR-117's byte gate,
// `kSchemaVersion`) to serve gestures that resolve and consume it inside
// one unmutated document state.
//
// Position is also the PHYSICAL fact here in a way it is not for a
// conductor. Gang 0 is the leftmost opening in the plate. An installer
// counts from the left; so does this list. A uuid would have needed a
// separate order key to say the thing the index already says.
//
// The same contract applies as there: a `GangRef` describes the document
// it was resolved from and no other. Insert a gang and every reference
// past it is stale.
//
// ═════════════════════════════════════════════════════════════════════
// AN EMPTY CELL AND A BLANK INSERT ARE DIFFERENT FACTS (G4 / CR-114)
// ═════════════════════════════════════════════════════════════════════
// This is the one place in this file where getting the shape wrong would
// have been invisible and expensive.
//
//   * NO ENTRY for a cell — nobody has said what goes there. Unknown.
//     Serializes as an absent key, never as an explicit null, and every
//     rollup over a plate reports how many there are.
//   * `BlankInsert` — somebody decided nothing goes there. DECIDED, and
//     §11.7.4 makes it a purchasable line item: "a six-port strap with
//     four positions used needs TWO BLANKS, and those are purchasable
//     line items that belong on the materials sheet."
//
// Collapsing the two would put two blanks on a materials sheet for every
// plate a designer had not finished filling in, which is a parts order
// derived from an absence of work. The precedent one scale up is exact
// and §11.7.4 names it: `X01 Blank Panel` is a catalog template, not a
// gap in a rack.
//
// THAT DISTINCTION NOW EXISTS AT THREE SCALES and DR-047 §11.46.1 is
// where they are tabulated: a cell (no entry / `BlankInsert`), a gang
// (no fitting / a [PassThrough]) and an outlet (no drops / needs no
// plate, §11.44.4). Two of the three were got wrong once each and cost a
// correction a milestone later. The gang one was ruled first.
import 'package:meta/meta.dart';
import 'package:rackpal_core/src/model/conductor.dart' show ConductorRef;
import 'package:rackpal_core/src/model/enums.dart' show PassThroughStyle;
import 'package:rackpal_core/src/units/ids.dart';

/// The width bounds of a strap: `W ∈ {1, 2}` (DR-007 §11.7.1).
const int kMinStrapWidth = 1;

/// See [kMinStrapWidth].
const int kMaxStrapWidth = 2;

/// The height bounds of a strap: `H ∈ {1, 2, 3}` (DR-007 §11.7.1).
const int kMinStrapHeight = 1;

/// See [kMinStrapHeight].
const int kMaxStrapHeight = 3;

/// One occupant of one cell. Every occupant is exactly ONE cell
/// (DR-007 §11.7.2, revised): there is no span, no orientation, and
/// therefore no packing.
///
/// Three cases, and the split between the first two is about WHAT THE
/// CELL TERMINATES rather than how it draws. §11.7.9 B rules that face-on
/// "a punchdown jack and an inline coupler are the same object, a
/// coloured bezel with a connector opening", so the renderer never needs
/// this distinction. The CELL COUNT does: §11.7.2.1 gives one cell per
/// `Link` end for a modular jack and one per `Conductor` for a binding
/// post, which is why a 16/4 speaker drop needs four cells and a Cat6
/// drop needs one.
sealed class CellOccupant {
  const CellOccupant();
}

/// A modular jack, punchdown or barrel: the WHOLE field end of one
/// [linkId] lands in this one cell.
///
/// One cell per `Link` end, per §11.7.2.1's table. The tempting
/// generalisation from DR-007's "one per conductor" is that cells always
/// equal conductors, and that ruling says in as many words that it "is
/// false for the most common drop in the building": a Cat6 run
/// terminating in one RJ45 occupies one cell no matter how its
/// conductors are modelled.
@immutable
final class LinkEndOccupant extends CellOccupant {
  const LinkEndOccupant(this.linkId);

  final Uuid linkId;

  @override
  bool operator ==(Object other) =>
      other is LinkEndOccupant && other.linkId == linkId;

  @override
  int get hashCode => Object.hash('linkEnd', linkId);

  @override
  String toString() => 'LinkEndOccupant(${linkId.v})';
}

/// A single-post keystone: ONE conductor of a link lands in this cell.
///
/// The speaker case, and the reason DR-007 §11.7.2 was rewritten. The
/// user's statement is the whole of it: *"We use single post keystones,
/// one per conductor."* A stereo pair is two of these; a 16/4 run is
/// four, which is §11.7.2.2's case that bites, because four cells do not
/// fit on a 1-, 2- or 3-port strap at all.
///
/// The two posts of a pair NEED NOT BE ADJACENT, need not share a column
/// and need not sit in the same order on every plate. Nothing here
/// groups them, because §11.7.2 explicitly deleted the grouping
/// constraint along with the orientation it existed to serve.
@immutable
final class ConductorOccupant extends CellOccupant {
  const ConductorOccupant(this.conductor);

  /// `(linkId, index)` — a POSITION in the link's conductor list, with
  /// exactly the staleness contract `ConductorRef` documents.
  final ConductorRef conductor;

  @override
  bool operator ==(Object other) =>
      other is ConductorOccupant && other.conductor == conductor;

  @override
  int get hashCode => Object.hash('conductor', conductor);

  @override
  String toString() => 'ConductorOccupant($conductor)';
}

/// A blank insert: somebody decided nothing goes in this cell.
///
/// AN OCCUPANT, NOT AN ABSENCE (§11.7.4). A cell with no entry at all is
/// undecided; this is decided, and it is a part somebody buys. See this
/// file's header for why the two must not collapse.
@immutable
final class BlankInsert extends CellOccupant {
  const BlankInsert();

  @override
  bool operator ==(Object other) => other is BlankInsert;

  @override
  int get hashCode => 'blank'.hashCode;

  @override
  String toString() => 'BlankInsert()';
}

/// What is fitted in one gang opening (DR-047 §11.46.2).
///
/// Two cases, and the nullability of the field holding one is the third
/// state: **null is UNKNOWN**, a gang whose part nobody has picked. See
/// [Gang.fitting], and this file's header for why a `Strap?` could not
/// express the middle case at all.
sealed class GangFitting {
  const GangFitting();
}

/// A hole in the plate at this opening, with nothing behind it.
///
/// **A DECISION AND A PURCHASE**, which is what separates it from a gang
/// with no fitting chosen. §11.7.4's argument for `BlankInsert` one
/// scale up: *"somebody decided nothing goes there"* is a part on a
/// materials sheet, and *"nobody has said"* is not.
///
/// **IT RECORDS NO DROPS, AND THAT WAS ASKED** (§11.46, question 3). A
/// brush is one opening that any number of cables share, so per-opening
/// occupancy is a fiction there. Listing the drops through it would also
/// be a **second membership list** beside `Link.structureOrigin.outletId`,
/// which AC-019 and CR-016 shaped the whole model to avoid: it could
/// disagree with the first, and it would need its own cascade when a drop
/// is deleted.
///
/// **WHETHER THE PLATE ITSELF IS BRUSHED OR HOLDS AN INSERT IS DERIVED**,
/// never stored (§11.46.4). `derived/plate_fill.dart` decides, from
/// whether every opening on the plate is a pass-through of one style.
@immutable
final class PassThrough extends GangFitting {
  const PassThrough(this.style);

  final PassThroughStyle style;

  @override
  bool operator ==(Object other) =>
      other is PassThrough && other.style == style;

  @override
  int get hashCode => Object.hash('passThrough', style);

  @override
  String toString() => 'PassThrough(${style.name})';
}

/// One keystone strap: a `W × H` grid of equal cells.
///
/// **FIVE PORT COUNTS EXIST AND FIVE PORTS IS NOT ONE OF THEM.** With
/// `W ∈ {1,2}` and `H ∈ {1,2,3}` the products are 1, 2, 3, 4 and 6, and
/// DR-007 §11.7.1 requires that this be "a DERIVED CONSTRAINT falling out
/// of `W × H`, never a hardcoded exclusion list, a list would be a fact
/// about a catalog, and this is a fact about geometry". [isValidStrapSize]
/// is that constraint and there is no list of five anywhere in this
/// package.
///
/// **EVERY CELL IS THE SAME SIZE**, on a 1-wide strap and a 2-wide one
/// alike (DR-038, measured). That is not modelled here because it is not
/// a per-strap fact: the figures live once, in `draw/scene/`, and this
/// type carries only which cells exist and what is in them.
///
/// **ONE CASE OF [GangFitting] SINCE DR-047**, and nothing else about it
/// changed. A strap is what is behind a Decora opening; a [PassThrough]
/// is what is behind nothing.
final class Strap extends GangFitting {
  Strap({
    required this.width,
    required this.height,
    Map<int, CellOccupant>? cells,
  }) : cells = cells ?? {} {
    if (!isValidStrapSize(width, height)) {
      throw ArgumentError(
        'Strap $width x $height is not a shipped part: DR-007 §11.7.1 '
        'bounds W to $kMinStrapWidth..$kMaxStrapWidth and H to '
        '$kMinStrapHeight..$kMaxStrapHeight.',
      );
    }
  }

  /// Columns, `1..2`.
  final int width;

  /// Rows, `1..3`.
  final int height;

  /// How many cells this strap has. The port count on the box the part
  /// came in: 1, 2, 3, 4 or 6.
  int get cellCount => width * height;

  /// Cell index to what is in it, keyed by [cellIndex].
  ///
  /// **A MISSING KEY IS UNDECIDED, NOT EMPTY** (G4/CR-114). See the file
  /// header: an absent entry means nobody has said, and a [BlankInsert]
  /// means somebody said "nothing", which is a part on a materials
  /// sheet. `unfilledCount` counts the first and never the second.
  ///
  /// ACCESS CONTROL: plain mutable pending the AC-013 retrofit, like
  /// `Link.conductors` and every other child collection in this package.
  /// Callers outside `src/commands/` mutate it at their own peril and
  /// `internal_setter_grep_test.dart` is the standing check.
  Map<int, CellOccupant> cells;

  /// `(column, row)` to the key [cells] uses. Row-major, so cell 0 is
  /// top-left and the last cell is bottom-right.
  int cellIndex(int column, int row) => row * width + column;

  /// The column of [index].
  int columnOf(int index) => index % width;

  /// The row of [index].
  int rowOf(int index) => index ~/ width;

  /// True when [index] names a cell this strap actually has.
  bool holdsIndex(int index) => index >= 0 && index < cellCount;

  /// Cells nobody has decided about: not occupied and not blanked.
  ///
  /// **Reported, never filled in.** G4's rule for every rollup in this
  /// package: a plate half designed is half designed, and a renderer or
  /// a materials sheet says so rather than assuming the rest are blanks.
  int get undecidedCount {
    var n = 0;
    for (var i = 0; i < cellCount; i++) {
      if (!cells.containsKey(i)) n++;
    }
    return n;
  }
}

/// One gang opening in a plate, holding at most one [GangFitting].
///
/// **[fitting] IS NULLABLE AND NULL IS UNKNOWN** (G4/CR-114). A gang whose
/// part nobody has chosen is an ordinary state at rough-in: the box is
/// in the wall, the drops are pulled, and which part gets screwed to it
/// is a trim-out decision weeks later. Defaulting it to a 1-port strap
/// would put a purchase on a materials sheet that nobody made, which is
/// the same defect `Outlet.mountHeightAff` documents for a plate nobody
/// has measured.
///
/// **THREE STATES, AND THE FIELD WAS `Strap?` FOR TWO OF THEM** until
/// DR-047 §11.46.2. Null, a [Strap], or a [PassThrough]: an opening
/// somebody decided gets no strap is not an opening nobody has reached.
final class Gang {
  Gang({this.fitting});

  /// ACCESS CONTROL: plain mutable pending the AC-013 retrofit, converted
  /// as it is wired to a `Command`.
  GangFitting? fitting;
}

/// Whether `W × H` names a strap that exists (DR-007 §11.7.1).
///
/// Derived from the bounds, so five ports are impossible rather than
/// excluded. Do not replace this with a set literal of `{1,2,3,4,6}`:
/// the ruling is explicit that a list would be "a fact about a catalog,
/// and this is a fact about geometry", and a list also silently accepts
/// a 3 × 2 strap that no manufacturer makes.
bool isValidStrapSize(int width, int height) =>
    width >= kMinStrapWidth &&
    width <= kMaxStrapWidth &&
    height >= kMinStrapHeight &&
    height <= kMaxStrapHeight;

/// One gang, cited by the `Outlet` that holds it and its POSITION in that
/// outlet's gang list.
///
/// A REFERENCE, NOT A HANDLE, and a snapshot rather than a live view. See
/// this file's header and `ConductorRef`, whose contract this copies
/// deliberately rather than inventing a second one.
@immutable
final class GangRef {
  const GangRef(this.outletId, this.index);

  final Uuid outletId;

  /// 0-based position in the outlet's `gangs` list. Gang 0 is the
  /// LEFTMOST opening in the plate.
  final int index;

  @override
  bool operator ==(Object other) =>
      other is GangRef && other.outletId == outletId && other.index == index;

  @override
  int get hashCode => Object.hash(outletId, index);

  @override
  String toString() => 'GangRef(${outletId.v}, $index)';
}

/// One cell, cited by its gang and its index within that gang's strap.
@immutable
final class CellRef {
  const CellRef(this.gang, this.cellIndex);

  final GangRef gang;
  final int cellIndex;

  @override
  bool operator ==(Object other) =>
      other is CellRef && other.gang == gang && other.cellIndex == cellIndex;

  @override
  int get hashCode => Object.hash(gang, cellIndex);

  @override
  String toString() => 'CellRef($gang, $cellIndex)';
}
