// rackmate_core/src/structure/csv_import_plan.dart — pure Dart.
//
// WHAT THIS FILE WOULD DO TO THIS DOCUMENT. Board M3-F/6 (#652),
// docs/07 §5.3.
//
// ═════════════════════════════════════════════════════════════════════
// THE PLAN IS THE COUNT, AND THE COUNT IS WHAT #161 CONFIRMS
// ═════════════════════════════════════════════════════════════════════
// §5.3.5 asks an import that would modify existing work to show "an
// explicit import-over-existing confirmation listing the counts (`create
// 14 · update 38 · unchanged 9`)". Those three numbers are this file's
// output, and they are computed BEFORE any command exists, because a
// count derived from a command list is a count nobody can check against
// the rows on screen.
//
// Mutates nothing and builds no `Command`. Applying the plan is the next
// commit; the preview grid and the confirm both render from here.
//
// ═════════════════════════════════════════════════════════════════════
// WHY RE-IMPORT HAS TO BE IDEMPOTENT, IN ONE SENTENCE
// ═════════════════════════════════════════════════════════════════════
// §5.3: "the pull list gets revised three times before drywall". An
// import that duplicated on the second pass would give a job sixty extra
// phantom drops, each with its own label, in the week the labels are
// being printed.
//
// ═════════════════════════════════════════════════════════════════════
// THE TWO MATCHING RULES NO LONGER DIFFER. DR-053 UNIFIED THEM
// ═════════════════════════════════════════════════════════════════════
// THIS BLOCK USED TO SAY THE DIFFERENCE WAS DELIBERATE AND THAT
// "UNIFYING THEM IS A RULING". The ruling is DR-053 (canon §11.52,
// board #654), and both differences are gone:
//
//   1. Location matching. Both paths now call `normaliseTypedName`, and
//      it COLLAPSES internal whitespace rather than stripping it, which
//      is a narrowing HERE and a widening in the planner. `Living  Room`
//      still finds `Living Room`; `LivingRoom` no longer does. The old
//      body was `s.toLowerCase().replaceAll(RegExp(r'\s+'), '')`.
//   2. Outlet matching. The typed-line planner now keys on
//      `(locationId, designation)` too, so this file's rule stopped
//      being the exception and became the rule.
//
// **THE OLD BLOCK WAS RIGHT ABOUT ITS OWN SCOPE AND IS KEPT IN OUTLINE
// FOR THAT REASON.** It declined to change a shipped gesture from inside
// a CSV task and said what it would take instead. That is what happened,
// three days later, and the finding it recorded is what got #654 filed
// rather than lost.
import 'package:meta/meta.dart';
import 'package:rackmate_core/src/model/link.dart';
import 'package:rackmate_core/src/model/location.dart';
import 'package:rackmate_core/src/model/outlet.dart';
import 'package:rackmate_core/src/model/pathway.dart';
import 'package:rackmate_core/src/model/rack_document.dart';
import 'package:rackmate_core/src/structure/csv_row_resolve.dart';
import 'package:rackmate_core/src/structure/drop_line_planner.dart'
    show normaliseTypedName;
import 'package:rackmate_core/src/units/ids.dart';

/// What a planned row does to the document.
enum CsvRowAction {
  /// Creates one or more `Link`s that are not there yet.
  create,

  /// Matches existing `Link`s and changes at least one field on them.
  update,

  /// Matches existing `Link`s and changes nothing.
  ///
  /// ITS OWN OUTCOME AND NOT A KIND OF UPDATE, because §5.3.5's confirm
  /// prints it separately: re-importing a sheet where nine rows were
  /// already right should say so, rather than claim to have touched
  /// them.
  unchanged,

  /// Does nothing, because the row could not be read (a row with no
  /// room) or names no cable.
  skipped,
}

/// One resolved row, placed against the document.
@immutable
final class CsvPlannedRow {
  const CsvPlannedRow({
    required this.row,
    required this.action,
    required this.drops,
    required this.issues,
    this.location,
    this.outlet,
    this.pathway,
    this.matchedLinkIds = const [],
  });

  final ResolvedCsvRow row;
  final CsvRowAction action;

  /// How many `Link`s this row accounts for: created, updated or found
  /// unchanged, according to [action].
  final int drops;

  /// Issues raised by PLACING the row, on top of the ones reading it
  /// raised. [row]'s own issues are not repeated here.
  final List<CsvCellIssue> issues;

  /// Null when the room does not exist yet and will be created.
  final Location? location;

  /// Null when the outlet does not exist yet, and also when the row
  /// named no plate.
  final Outlet? outlet;

  /// Null when the row named no pathway, or names one to be created.
  final Pathway? pathway;

  /// The `Link`s this row matched, in order, for [CsvRowAction.update]
  /// and [CsvRowAction.unchanged].
  final List<Uuid> matchedLinkIds;
}

/// Everything one import would do, counted.
@immutable
final class CsvImportPlan {
  const CsvImportPlan({
    required this.rows,
    required this.newLocationNames,
    required this.newMediaTokens,
    required this.newPathwayNames,
    required this.issues,
  });

  final List<CsvPlannedRow> rows;

  /// Rooms §5.3.1 found no match for, deduplicated, in first-seen order.
  ///
  /// §5.3.1: "No match offers 'create room' inline". Offering is the
  /// surface's job; naming them is this one's.
  final List<String> newLocationNames;

  /// RJ-012's new media types, deduplicated by the spelling the sheet
  /// used, in first-seen order.
  ///
  /// ONE TYPE PER DISTINCT SPELLING, NOT ONE PER ROW. A sheet with forty
  /// `Cat6e` rows creates one type and forty drops on it; minting per
  /// row would put forty identical types in the registry.
  final List<String> newMediaTokens;

  final List<String> newPathwayNames;

  /// Whole-import issues: duplicate labels, and anything that is about
  /// the file rather than one row.
  final List<CsvCellIssue> issues;

  int get createCount => _sum(CsvRowAction.create);
  int get updateCount => _sum(CsvRowAction.update);
  int get unchangedCount => _sum(CsvRowAction.unchanged);

  /// Rows that produce nothing. COUNTED RATHER THAN OMITTED (G4): an
  /// import that quietly did nothing with four of sixty rows is the
  /// failure §5.3's preview grid exists to prevent.
  int get skippedRowCount =>
      rows.where((r) => r.action == CsvRowAction.skipped).length;

  /// Whether anything already in the document would change.
  ///
  /// **THIS IS WHAT ARMS #161's CONFIRM.** An import that only creates
  /// is not the destructive case and does not need the dialog DR-013's
  /// delete needs.
  bool get touchesExistingWork => updateCount > 0;

  int _sum(CsvRowAction action) => rows
      .where((r) => r.action == action)
      .fold(0, (total, r) => total + r.drops);
}

/// §5.3's matching, dedup and counts, against [doc], mutating nothing.
///
/// [declinedLocations] and [declinedMediaTokens] are the boxes the
/// operator UNTICKED in the import dialog's "will create" list, matched
/// against [CsvImportPlan.newLocationNames] and
/// [CsvImportPlan.newMediaTokens] by exact spelling.
///
/// **DECLINING IS EXPRESSED AS A SUBTRACTION FROM ALL-ACCEPTED, so the
/// empty default is every box ticked.** The dialog opens with the whole
/// list checked because a pull list IS the room list on a February job
/// and unticking is the exception; an accept-list would make an empty
/// set mean "import nothing", which is the wrong thing for a caller to
/// get by omission.
///
/// A declined room skips its rows. A declined cable drops its items,
/// and a row left with no items skips. Both are counted in
/// [CsvImportPlan.skippedRowCount] rather than vanishing, because a
/// checkbox that silently removed four of sixty rows would be the
/// discard G4 forbids wearing a tick box.
CsvImportPlan planCsvImport({
  required RackDocument doc,
  required List<ResolvedCsvRow> rows,
  Set<String> declinedLocations = const {},
  Set<String> declinedMediaTokens = const {},
}) {
  final planned = <CsvPlannedRow>[];
  final issues = <CsvCellIssue>[];
  final newLocations = <String>[];
  final newMedia = <String>[];
  final newPathways = <String>[];

  // Links this import has already claimed, so two rows cannot both
  // update one drop. §5.3.4's ordinal-within-group is exactly this: the
  // second `Living Room · WP-1 · Cat6` row takes the second such drop.
  final claimed = <Uuid>{};

  // Field labels the file supplies, to find §5.3.6's duplicates. Counted
  // rather than blocked.
  final labelRows = <String, List<int>>{};

  for (final row in rows) {
    if (row.fieldLabel case final label?) {
      (labelRows[_squash(label)] ??= []).add(row.source.line);
    }
  }
  for (final entry in labelRows.entries) {
    if (entry.value.length < 2) continue;
    issues.add(
      CsvCellIssue(
        severity: CsvIssueSeverity.warning,
        // FLAGGED, NOT BLOCKED (§5.3.6, G3): a heuristic must not hold a
        // deliverable hostage, and the operator can renumber.
        message:
            'The label on lines ${entry.value.join(', ')} is the same. '
            'Field labels are unique project-wide (CR-113), so all but one '
            'will need renumbering.',
      ),
    );
  }

  for (final row in rows) {
    if (row.hasError) {
      planned.add(
        CsvPlannedRow(
          row: row,
          action: CsvRowAction.skipped,
          drops: 0,
          issues: const [],
        ),
      );
      continue;
    }

    // --- §5.3.1 the room ---------------------------------------------
    final location = _matchLocation(doc, row.locationName);
    if (location == null && !newLocations.contains(row.locationName)) {
      newLocations.add(row.locationName);
    }

    // --- §5.3.2 the plate --------------------------------------------
    final outlet = location == null
        ? null
        : _matchOutlet(doc, location.id, row.outletDesignation);

    // --- §5.3.3 the pathway ------------------------------------------
    Pathway? pathway;
    if (row.pathwayName case final name?) {
      pathway = _matchPathway(doc, name);
      if (pathway == null && !newPathways.contains(name)) {
        newPathways.add(name);
      }
    }

    // --- RJ-012's new types, once per spelling ------------------------
    // Every new token is LISTED even when it is declined, because the
    // list is what the dialog's tick boxes render; declining removes the
    // drops, not the row of the checklist.
    for (final item in row.items) {
      if (item.media case ResolvedMediaNew(:final token)) {
        if (!newMedia.contains(token)) newMedia.add(token);
      }
    }

    // --- what the operator unticked ------------------------------------
    if (location == null && declinedLocations.contains(row.locationName)) {
      planned.add(
        CsvPlannedRow(
          row: row,
          action: CsvRowAction.skipped,
          drops: 0,
          issues: [
            CsvCellIssue(
              severity: CsvIssueSeverity.warning,
              message:
                  '"${row.locationName}" is not being created, so this '
                  'row is skipped.',
            ),
          ],
        ),
      );
      continue;
    }

    final items = [
      for (final item in row.items)
        if (!(item.media is ResolvedMediaNew &&
            declinedMediaTokens.contains(
              (item.media as ResolvedMediaNew).token,
            )))
          item,
    ];
    final declinedItems = row.items.length - items.length;

    final totalDrops = items.fold(0, (t, i) => t + i.count);
    if (totalDrops == 0) {
      planned.add(
        CsvPlannedRow(
          row: row,
          action: CsvRowAction.skipped,
          drops: 0,
          issues: declinedItems == 0
              ? const []
              : [
                  const CsvCellIssue(
                    severity: CsvIssueSeverity.warning,
                    message:
                        'The cable this row names is not being created, '
                        'so the row is skipped.',
                  ),
                ],
          location: location,
          outlet: outlet,
          pathway: pathway,
        ),
      );
      continue;
    }

    // --- §5.3.4 dedup -------------------------------------------------
    // RUN EVEN WHEN THE ROOM IS NEW. It is tempting to skip the lookup
    // here, on the reasoning that a room the project does not have
    // cannot hold an existing drop, and that reasoning is wrong for the
    // key that matters: `fieldLabel` is unique PROJECT-WIDE (CR-113), so
    // a drop whose room changed between revisions is still the same
    // drop and the label is the thing that says so. Skipping would
    // duplicate it into the new room and leave the old one behind.
    final matched = _matchDrops(
      doc: doc,
      row: row,
      items: items,
      outlet: outlet,
      claimed: claimed,
    );
    claimed.addAll(matched);

    if (matched.isEmpty) {
      planned.add(
        CsvPlannedRow(
          row: row,
          action: CsvRowAction.create,
          drops: totalDrops,
          issues: const [],
          location: location,
          outlet: outlet,
          pathway: pathway,
        ),
      );
      continue;
    }

    // --- §5.3.5 what a match would actually change --------------------
    final rowIssues = <CsvCellIssue>[];
    final changes = matched
        .where((id) => _wouldChange(doc.links[id]!, row, pathway))
        .length;

    // A row that matched FEWER drops than it asks for is part update and
    // part create, and the count says so rather than rounding to one.
    if (matched.length < totalDrops) {
      rowIssues.add(
        CsvCellIssue(
          severity: CsvIssueSeverity.warning,
          message:
              'This row asks for $totalDrops drops and ${matched.length} '
              'already exist, so ${totalDrops - matched.length} will be '
              'created.',
        ),
      );
    }

    planned.add(
      CsvPlannedRow(
        row: row,
        action: changes > 0 ? CsvRowAction.update : CsvRowAction.unchanged,
        drops: matched.length,
        issues: List.unmodifiable(rowIssues),
        location: location,
        outlet: outlet,
        pathway: pathway,
        matchedLinkIds: List.unmodifiable(matched),
      ),
    );

    // The unmatched remainder of a partly-matched row is a create, and
    // it is counted as its own planned row so the three totals still add
    // up to the drops on the sheet.
    if (matched.length < totalDrops) {
      planned.add(
        CsvPlannedRow(
          row: row,
          action: CsvRowAction.create,
          drops: totalDrops - matched.length,
          issues: const [],
          location: location,
          outlet: outlet,
          pathway: pathway,
        ),
      );
    }
  }

  return CsvImportPlan(
    rows: List.unmodifiable(planned),
    newLocationNames: List.unmodifiable(newLocations),
    newMediaTokens: List.unmodifiable(newMedia),
    newPathwayNames: List.unmodifiable(newPathways),
    issues: List.unmodifiable(issues),
  );
}

/// §5.3.1: `Location.name` then `Location.code`, case- and
/// whitespace-insensitive.
Location? _matchLocation(RackDocument doc, String name) {
  final want = _squash(name);
  if (want.isEmpty) return null;
  for (final l in doc.locations.values) {
    if (_squash(l.name) == want) return l;
  }
  for (final l in doc.locations.values) {
    if (_squash(l.code) == want) return l;
  }
  return null;
}

/// §5.3.2: `(locationId, designation)`. Rows sharing both join one
/// `Outlet`.
Outlet? _matchOutlet(RackDocument doc, Uuid locationId, String? designation) {
  if (designation == null) return null;
  final want = _squash(designation);
  for (final o in doc.outlets.values) {
    if (o.locationId != locationId) continue;
    if (_squash(o.designation) == want) return o;
  }
  return null;
}

/// §5.3.3: by `Pathway.name`, project-wide.
Pathway? _matchPathway(RackDocument doc, String name) {
  final want = _squash(name);
  for (final p in doc.pathways.values) {
    if (_squash(p.name) == want) return p;
  }
  return null;
}

/// §5.3.4's two keys, in the order the ruling states them.
///
/// **`fieldLabel` WINS WHEN THE FILE SUPPLIES ONE**, and it is matched
/// project-wide because CR-113 makes it unique project-wide: a drop that
/// moved to another room between revisions is the same drop, and the
/// label is what says so. It also means a label match ignores the
/// four-tuple entirely, which is the point of having a stated identifier.
///
/// **OTHERWISE the tuple**, `(locationId, outletDesignation,
/// mediaTypeId, ordinal-within-group)`. The ordinal is what [claimed]
/// implements: drops are taken in a stable order and each row consumes
/// the ones no earlier row took, so the second `Living Room · WP-1 ·
/// Cat6` row updates the second such drop rather than fighting the first
/// row for the same one.
List<Uuid> _matchDrops({
  required RackDocument doc,
  required ResolvedCsvRow row,
  required List<ResolvedCsvItem> items,
  required Outlet? outlet,
  required Set<Uuid> claimed,
}) {
  if (row.fieldLabel case final label?) {
    final want = _squash(label);
    for (final link in _stable(doc)) {
      final origin = link.structureOrigin;
      if (origin == null) continue;
      if (claimed.contains(link.id)) continue;
      if (_squash(origin.fieldLabel) == want) return [link.id];
    }
    // A stated label that matches nothing is a NEW drop, not a failed
    // lookup. The sheet named a run this project has never seen.
    return const [];
  }

  if (outlet == null) return const [];

  final wantedMedia = <MediaTypeId>[];
  for (final item in items) {
    if (item.media case ResolvedMediaKnown(:final id)) {
      for (var n = 0; n < item.count; n++) {
        wantedMedia.add(id);
      }
    }
  }
  if (wantedMedia.isEmpty) return const [];

  final out = <Uuid>[];
  final taken = <Uuid>{};
  for (final media in wantedMedia) {
    for (final link in _stable(doc)) {
      if (claimed.contains(link.id) || taken.contains(link.id)) continue;
      final origin = link.structureOrigin;
      if (origin == null) continue;
      if (origin.outletId != outlet.id) continue;
      if (link.media != media) continue;
      taken.add(link.id);
      out.add(link.id);
      break;
    }
  }
  return out;
}

/// Would applying [row] to [link] change anything?
///
/// **AN EMPTY CSV CELL NEVER OVERWRITES** (§5.3.5: "never overwrites a
/// field the user has edited in-app unless the CSV supplies a non-empty
/// differing value"). That rule is what makes a sheet carrying only
/// lengths safe to re-import over a document somebody has been editing
/// all week: the columns it does not fill are not columns it clears.
///
/// It also means an "unchanged" row is one where every value the file
/// STATES already matches, rather than one where the two agree about
/// everything including the blanks.
bool _wouldChange(Link link, ResolvedCsvRow row, Pathway? pathway) {
  final origin = link.structureOrigin;
  if (row.routedLength != null && row.routedLength != link.routedLength) {
    return true;
  }
  if (row.roughInStatus != null && row.roughInStatus != link.roughInStatus) {
    return true;
  }
  if (row.notes != null && row.notes != link.notes) return true;
  // A `Bundle` naming a pathway THIS IMPORT WILL CREATE is a change too,
  // and reading `pathway == null` as "no pathway stated" misses it: the
  // link cannot already sit in a pathway the document does not hold. A
  // revised sheet that only moves runs between trunks would otherwise
  // report every row unchanged and then move them anyway.
  if (row.pathwayName != null &&
      (pathway == null || pathway.id != link.pathwayId)) {
    return true;
  }
  if (row.jacketColor != null && row.jacketColor != link.jacketColorId) {
    return true;
  }
  if (row.jacketColorPulled != null &&
      row.jacketColorPulled != link.jacketColorPulledId) {
    return true;
  }
  if (origin != null) {
    if (row.rackLabel != null && row.rackLabel != origin.rackLabel) return true;
    if (row.terminationField != null &&
        row.terminationField != origin.terminationField) {
      return true;
    }
    if (row.fieldLabel != null &&
        _squash(row.fieldLabel!) != _squash(origin.fieldLabel)) {
      return true;
    }
  }
  return false;
}

/// Links in a stable order.
///
/// **DETERMINISM IS LOAD-BEARING HERE AND NOT HOUSEKEEPING.** §5.3.4's
/// ordinal picks the Nth drop in a group, so the answer to "which drop
/// did row 12 update" depends on this order. `Map.values` is insertion
/// order, which two documents holding the same drops need not share, so
/// the chain ends in the id: `List.sort` is not stable in Dart and a
/// comparator that ties is a comparator that reorders.
List<Link> _stable(RackDocument doc) {
  return doc.links.values.toList()..sort((a, b) {
    final byOrder = a.order.v.compareTo(b.order.v);
    return byOrder != 0 ? byOrder : a.id.v.compareTo(b.id.v);
  });
}

/// §5.3's "case- and whitespace-insensitive", as DR-053 §11.52.4 reads it.
///
/// IT USED TO STRIP AND NOW IT COLLAPSES, which narrows this path. The old
/// body was `s.toLowerCase().replaceAll(RegExp(r'\s+'), '')`, so
/// `LivingRoom` matched `Living Room`; now it does not, and `Living  Room`
/// still does. The ruling took collapsing because stripping also makes two
/// names a person reads as distinct unrepresentable in one project, which
/// is a larger claim than §5.3.1 makes.
///
/// ONE FUNCTION FOR BOTH ENTRY PATHS, WHICH IS THE POINT OF THE RULING.
/// The typed line used to trim and lower-case only, so a double-spaced
/// room name created a second room from one path and matched the existing
/// one from the other. Keeping a second normaliser here would relocate
/// that disagreement rather than remove it.
///
/// THE THREE USES DR-053 DOES NOT NAME INHERIT THIS, and they are safe
/// because both sides of every comparison normalise the same way: a
/// pathway name, a field label and the label-collision map all compare
/// squashed against squashed, so the only inputs whose behaviour moves are
/// exactly the `AB` versus `A B` pairs the ruling decided.
String _squash(String s) => normaliseTypedName(s);
