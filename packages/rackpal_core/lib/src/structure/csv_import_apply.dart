// rackpal_core/src/structure/csv_import_apply.dart — pure Dart.
//
// THE PLAN, AS COMMANDS. Board M3-F/6 (#652), docs/07 §5.3.
//
// ═════════════════════════════════════════════════════════════════════
// ONE UNDO ENTRY FOR THE WHOLE IMPORT
// ═════════════════════════════════════════════════════════════════════
// §5.3: "the whole import is one undoable `Command`". So this returns a
// LIST the caller applies inside one `Transaction` under
// `LabelKey.importCsv`, and applies entirely or not at all. Sixty drops,
// four rooms and two cable types cost one Ctrl+Z, because undoing an
// import a row at a time is not undoing an import.
//
// ═════════════════════════════════════════════════════════════════════
// EVERYTHING IS BUILT AGAINST ONE UNMUTATED DOCUMENT
// ═════════════════════════════════════════════════════════════════════
// `drop_line_planner.dart` states the rule and the reason scales: a
// planner that applied as it went would leave forty of sixty drops
// behind when the forty-first refused. The reservations
// (`alsoUsedLabels`, `alsoUsedDesignators`, `alsoOutlets`) carry what
// earlier rows in THIS import have spent, so two rows cannot agree on a
// field label and never notice — which matters far more here than on a
// typed line, because sixty rows arrive at once and CR-113 makes the
// label unique project-wide.
//
// ═════════════════════════════════════════════════════════════════════
// AN ENTITY IS CREATED ONCE PER IMPORT, NOT ONCE PER ROW
// ═════════════════════════════════════════════════════════════════════
// Four rows naming `Attic` create one room. Three naming `Cat6e` create
// one media type. Six naming `LR-TV` create one pathway, and rows
// sharing `(room, plate)` create one outlet — which is §5.3.2's join
// rule doing double duty, since the same key that matches an EXISTING
// plate also decides that two new rows are one new plate.
import 'package:meta/meta.dart';
import 'package:rackpal_core/src/commands/command.dart';
import 'package:rackpal_core/src/commands/home_run_commands.dart';
import 'package:rackpal_core/src/commands/link_jacket_color_commands.dart';
import 'package:rackpal_core/src/commands/location_commands.dart';
import 'package:rackpal_core/src/commands/media_type_commands.dart';
import 'package:rackpal_core/src/commands/pathway_commands.dart';
import 'package:rackpal_core/src/commands/set_entity_property_command.dart';
import 'package:rackpal_core/src/commands/structure_commands.dart';
import 'package:rackpal_core/src/model/entity_meta.dart';
import 'package:rackpal_core/src/model/link.dart';
import 'package:rackpal_core/src/model/location.dart';
import 'package:rackpal_core/src/model/outlet.dart';
import 'package:rackpal_core/src/model/rack_document.dart';
import 'package:rackpal_core/src/model/registries.dart';
import 'package:rackpal_core/src/structure/csv_import_plan.dart';
import 'package:rackpal_core/src/structure/csv_row_resolve.dart';
import 'package:rackpal_core/src/structure/drop_build.dart';
import 'package:rackpal_core/src/structure/drop_line_planner.dart'
    show serviceTagFor;
import 'package:rackpal_core/src/units/ids.dart';

/// The outcome of [buildCsvImport].
sealed class CsvImportBuild {
  const CsvImportBuild();
}

/// Apply every command inside ONE transaction, or apply none of them.
@immutable
final class CsvImportReady extends CsvImportBuild {
  const CsvImportReady({
    required this.commands,
    required this.createdDrops,
    required this.updatedDrops,
    required this.warnings,
  });

  /// In application order: registry and entity creations first, then the
  /// drops, then the updates. The order is load-bearing, because a drop
  /// naming a room refers to a room that has to exist by then.
  final List<Command<RackDocument>> commands;

  final int createdDrops;
  final int updatedDrops;

  /// Rows that could not be built after all, each with a sentence.
  ///
  /// **A ROW THAT FAILS HERE DOES NOT FAIL THE IMPORT** (§5.3, never
  /// fail-fast). The commonest cause is a user-created media type with
  /// no `shortTag`, which DR-023's chain refuses to label; the other
  /// fifty-nine drops still land and the operator is told which one did
  /// not.
  final List<CsvCellIssue> warnings;
}

/// Nothing can be built, for a reason about the whole import.
@immutable
final class CsvImportRefused extends CsvImportBuild {
  const CsvImportRefused(this.reason);
  final String reason;
}

/// Turns [plan] into the commands that carry it out.
///
/// [structureBodyId] is the editor's current body. When the project has
/// exactly one Structure device it may be omitted; with several, naming
/// none is refused rather than guessed, for `planDropLine`'s reason
/// stated at sixty times the scale: filing an import on the wrong
/// Structure body puts every drop on the wrong sheet.
CsvImportBuild buildCsvImport({
  required RackDocument doc,
  required CsvImportPlan plan,
  required DateTime now,
  required String actor,
  Uuid? structureBodyId,
}) {
  if (doc.structures.isEmpty) {
    return const CsvImportRefused(
      'This project has no Structure device, so there is nowhere to hang '
      'these drops. Create one first.',
    );
  }
  final bodyId = structureBodyId ?? doc.structures.keys.single;
  if (!doc.structures.containsKey(bodyId)) {
    return const CsvImportRefused(
      'That Structure device is not in this project any more.',
    );
  }

  final creations = <Command<RackDocument>>[];
  final drops = <Command<RackDocument>>[];
  final updates = <Command<RackDocument>>[];
  final warnings = <CsvCellIssue>[];

  // Reservations, carried across every row in this import.
  final usedLabels = usedFieldLabels(doc);
  // THE ONE THIS IMPORTER NEVER HAD (DR-075 §11.74.2). Every origin field
  // was handed `usedLabels`, which is the FIELD-label scan, and the rack
  // label's uniqueness check reads a different parameter — so nothing
  // filled it and two rows of one sheet could write one label onto two
  // drops. Measured before it was fixed: a re-import naming `PP1-05` on
  // two rows produced two links carrying it.
  final usedRackLabelSet = usedRackLabels(doc);
  final usedDesignators = {for (final l in doc.links.values) l.designator};
  final usedNetNames = {for (final n in doc.nets.values) n.name};

  // --- rooms, once each ------------------------------------------------
  // Built as a real `Location` beside its command because `buildDropsFor`
  // reads `code`, `name` and `floorNumber` off the object to allocate a
  // label, and the document will not hold this room until the
  // transaction runs. The ids match because `AddLocationCommand` mints
  // in its constructor.
  final newLocations = <String, Location>{};
  for (final name in plan.newLocationNames) {
    if (!plan.rows.any(
      (r) => r.location == null && r.row.locationName == name && r.drops > 0,
    )) {
      // Declined, or every row that wanted it was skipped for another
      // reason. Creating it anyway would leave an empty room behind.
      continue;
    }
    final add = AddLocationCommand(
      name: name,
      // The rooms earlier in THIS import are not in `doc` yet, so
      // without the reservation `Living Room` and `Laundry Room` both
      // derive `LR` and the Pull Sheet merges two rooms' subtotals.
      code: deriveLocationCode(
        doc,
        name,
        alsoUsed: {for (final l in newLocations.values) l.code},
      ),
      order: nextLocationOrder(doc),
      now: now,
      actor: actor,
    );
    creations.add(add);
    newLocations[name] = Location(
      id: add.id,
      kind: add.kind,
      name: add.name,
      code: add.code,
      order: add.order,
      floorNumber: add.floorNumber,
      meta: EntityMeta(createdAt: now, updatedAt: now, updatedBy: actor),
    );
  }

  // --- RJ-012's cable types, once per id (DR-197) ----------------------
  //
  // ONE ADD PER TYPE, NOT PER SPELLING. Two spellings that derive one id
  // used to build two adds with that id before either applied; the second
  // overwrote the first until `#935` made it refuse. Grouping here makes
  // one add carrying every spelling the sheet used for that cable.
  final newMedia = <String, MediaTypeId>{};
  for (final type in plan.newMediaTypes) {
    // Only the spellings some row still draws on: a declined box leaves its
    // spelling in the list but takes its drops away.
    final used = [
      for (final token in type.spellings)
        if (plan.rows.any(
          (r) =>
              r.drops > 0 && r.row.items.any((i) => _isToken(i.media, token)),
        ))
          token,
    ];
    if (used.isEmpty) continue;
    final id = mediaTypeIdFor(doc, used.first);
    creations.add(
      AddMediaTypeCommand(
        id: id,
        displayName: used.first,
        // WITHOUT A TAG THE DROP CANNOT BE LABELLED and `buildDropsFor`
        // refuses it, which would make RJ-012's "never a rejected row"
        // reject every row naming an unrecognised cable.
        shortTag: mediaShortTagFor(used.first),
        // EVERY SPELLING BECOMES AN ALIAS, which is what makes a re-import
        // idempotent for exactly the rows RJ-012 serves: without it the
        // second pass finds no match for `Cat6e` again and mints
        // `media.cat6e_2`.
        aliases: used,
      ),
    );
    for (final token in used) {
      newMedia[token] = id;
    }
  }

  // --- pathways, once each ---------------------------------------------
  final newPathways = <String, Uuid>{};
  for (final name in plan.newPathwayNames) {
    final add = AddPathwayCommand(
      name: name,
      order: nextPathwayOrder(doc),
      now: now,
      actor: actor,
    );
    creations.add(add);
    newPathways[name] = add.id;
  }

  // --- outlets, once per (room, plate) ----------------------------------
  final newOutlets = <String, Outlet>{};
  var createdDrops = 0;
  var updatedDrops = 0;

  for (final planned in plan.rows) {
    switch (planned.action) {
      case CsvRowAction.skipped:
      case CsvRowAction.unchanged:
        continue;
      case CsvRowAction.update:
        final built = _buildUpdates(
          doc: doc,
          planned: planned,
          pathwayId:
              planned.pathway?.id ??
              (planned.row.pathwayName == null
                  ? null
                  : newPathways[planned.row.pathwayName]),
          now: now,
          actor: actor,
          usedLabels: usedLabels,
          usedRackLabels: usedRackLabelSet,
        );
        updates.addAll(built);
        updatedDrops += planned.drops;
        continue;
      case CsvRowAction.create:
        break;
    }

    final row = planned.row;
    final location = planned.location ?? newLocations[row.locationName];
    if (location == null) continue;

    final designation = row.outletDesignation?.trim();
    final key =
        '${location.id.v} '
        '${(designation ?? '').toLowerCase()}';
    var outlet = planned.outlet ?? newOutlets[key];
    if (outlet == null) {
      final add = AddOutletCommand(
        structureBodyId: bodyId,
        designation: designation == null || designation.isEmpty
            ? outletDesignationFor(
                doc,
                location,
                alsoUsed: {
                  for (final o in newOutlets.values) o.designation,
                },
              )
            : designation,
        order: nextOutletOrder(doc),
        locationId: location.id,
        now: now,
        actor: actor,
      );
      creations.add(add);
      outlet = Outlet(
        id: add.id,
        structureBodyId: bodyId,
        designation: add.designation,
        order: add.order,
        locationId: location.id,
        meta: EntityMeta(createdAt: now, updatedAt: now, updatedBy: actor),
      );
      newOutlets[key] = outlet;
    }

    final items = <PlannedDropItem>[];
    for (final item in row.items) {
      final id = switch (item.media) {
        ResolvedMediaKnown(:final id) => id,
        ResolvedMediaNew(:final token) => newMedia[token],
      };
      if (id == null) continue;
      final def = doc.registries.mediaTypes[id];
      items.add(
        PlannedDropItem(
          media:
              def ??
              // The type is being created in THIS transaction, so the
              // registry does not hold it yet. `buildDropsFor` reads
              // `displayName` and `shortTag` off the def, so it is
              // reconstructed to match what `AddMediaTypeCommand` writes.
              MediaTypeDef(
                id: id,
                displayName: _tokenFor(row, id, newMedia),
                shortTag: mediaShortTagFor(_tokenFor(row, id, newMedia)),
              ),
          count: item.count,
          token: _tokenFor(row, id, newMedia),
        ),
      );
    }
    if (items.isEmpty) continue;

    final built = buildDropsFor(
      doc: doc,
      location: location,
      outlet: outlet,
      items: items,
      serviceTag: (item) => serviceTagFor(
        // DR-025 §11.24.4: the `Use` column feeds the LABEL CHAIN, in
        // the slot `@service=` occupies on a typed line, and never the
        // signal family.
        modifier: row.serviceToken,
        templates: doc.registries.outletTemplates,
        template: null,
        media: item.media,
      ),
      // §5.3.3's `Bundle` column: every drop this row makes travels in
      // the pathway it names, whether that pathway already existed or is
      // being created in this same transaction.
      pathwayId:
          planned.pathway?.id ??
          (row.pathwayName == null ? null : newPathways[row.pathwayName]),
      now: now,
      actor: actor,
      usedLabels: usedLabels,
      usedDesignators: usedDesignators,
      usedNetNames: usedNetNames,
    );

    switch (built) {
      case DropBuildRefused(:final reason):
        warnings.add(
          CsvCellIssue(
            severity: CsvIssueSeverity.warning,
            message: 'Line ${row.source.line}: $reason',
          ),
        );
      case DropBuildOk(:final commands):
        drops.addAll(commands);
        createdDrops += planned.drops;
    }
  }

  return CsvImportReady(
    commands: List.unmodifiable([...creations, ...drops, ...updates]),
    createdDrops: createdDrops,
    updatedDrops: updatedDrops,
    warnings: List.unmodifiable(warnings),
  );
}

bool _isToken(ResolvedMedia media, String token) =>
    media is ResolvedMediaNew && media.token == token;

/// The spelling a row used for [id], for a type this import is minting.
String _tokenFor(
  ResolvedCsvRow row,
  MediaTypeId id,
  Map<String, MediaTypeId> newMedia,
) {
  for (final entry in newMedia.entries) {
    if (entry.value == id) return entry.key;
  }
  return id.v;
}

/// §5.3.5's field-by-field update, on every drop the row matched.
///
/// **AN EMPTY CSV CELL WRITES NOTHING**, which the plan already decided
/// and this repeats structurally: every arm is guarded on the value
/// being non-null, so a sheet carrying only lengths cannot clear a note
/// somebody typed in the app.
List<Command<RackDocument>> _buildUpdates({
  required RackDocument doc,
  required CsvPlannedRow planned,
  required Uuid? pathwayId,
  required DateTime now,
  required String actor,
  required Set<String> usedLabels,
  required Set<String> usedRackLabels,
}) {
  final row = planned.row;
  final out = <Command<RackDocument>>[];

  for (final linkId in planned.matchedLinkIds) {
    final link = doc.links[linkId];
    if (link == null) continue;

    void set<T>(EntityField<Link, T> field, T to) {
      final command = buildSetEntityProperty<Link, T>(
        doc: doc,
        id: linkId,
        field: field,
        to: to,
        now: now,
        actor: actor,
      );
      if (command != null) out.add(command);
    }

    if (row.routedLength != null && row.routedLength != link.routedLength) {
      set(LinkField.routedLength, row.routedLength);
    }
    if (row.roughInStatus case final status?
        when status != link.roughInStatus) {
      set(LinkField.roughInStatus, status);
    }
    if (row.notes != null && row.notes != link.notes) {
      set(LinkField.notes, row.notes);
    }
    if (row.jacketColor != null && row.jacketColor != link.jacketColorId) {
      out.add(
        SetLinkJacketColorCommand(
          linkId: linkId,
          conventionId: row.jacketColor,
        ),
      );
    }
    if (row.jacketColorPulled != null &&
        row.jacketColorPulled != link.jacketColorPulledId) {
      out.add(
        SetLinkPulledJacketColorCommand(
          linkId: linkId,
          pulledId: row.jacketColorPulled,
        ),
      );
    }

    final origin = link.structureOrigin;
    if (origin == null) continue;
    if (row.rackLabel != null && row.rackLabel != origin.rackLabel) {
      // NOT `_origin`, AND NOT `StructureOriginField.rackLabel` (DR-075
      // §11.74.1). A `rack_label` column is a person choosing an
      // identifier: they typed it into a spreadsheet instead of into the
      // cell, which is the same act reaching the same field through a
      // different door. So it locks, and a later move keeps it rather
      // than re-deriving it from the new position.
      final built = buildSetRackLabel(
        doc: doc,
        linkId: linkId,
        to: row.rackLabel,
        now: now,
        actor: actor,
        alsoUsedRackLabels: usedRackLabels,
      );
      if (built case SetRackLabelReady(:final command)) {
        out.add(command);
        // SPENT ON SUCCESS ONLY, and with the NORMALISED value the
        // command carries rather than the sheet's cell, so a second row
        // spelling it with a trailing space is caught by the same scan.
        if (command.rackLabel case final claimed?) usedRackLabels.add(claimed);
      }
      // A refusal is SKIPPED rather than reported, which is this
      // importer's existing contract for an origin field and not a new
      // decision (§11.74.3): `_origin` has always dropped a non-`Ready`
      // result and left the rest of the row to apply. It is recorded as a
      // known limitation against docs/04 §3.4 rather than defended.
    }
    if (row.terminationField != null &&
        row.terminationField != origin.terminationField) {
      _origin(
        out,
        doc: doc,
        linkId: linkId,
        field: StructureOriginField.terminationField,
        to: row.terminationField,
        now: now,
        actor: actor,
        usedLabels: usedLabels,
      );
    }
    // Re-filing a run under a different pathway is an ordinary revision
    // (`Bundle` changed between drafts) and had no command until this
    // task added `LinkField.pathwayId`. The plan counts it as a change,
    // so the applier has to be able to make it, or the confirm would
    // overstate what it was about to do.
    if (pathwayId != null && pathwayId != link.pathwayId) {
      set(LinkField.pathwayId, pathwayId);
    }
  }
  return out;
}

void _origin<T>(
  List<Command<RackDocument>> out, {
  required RackDocument doc,
  required Uuid linkId,
  required EntityField<Link, T> field,
  required T to,
  required DateTime now,
  required String actor,
  required Set<String> usedLabels,
}) {
  final result = buildSetStructureOriginProperty<T>(
    doc: doc,
    linkId: linkId,
    field: field,
    to: to,
    now: now,
    actor: actor,
    alsoUsedLabels: usedLabels,
  );
  if (result case SetStructureOriginReady(:final command)) out.add(command);
}
