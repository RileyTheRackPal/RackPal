// THE REPEAT-ENTRY LOOP. Board M3-C/1 (#147), DR-023, docs/07 §4.3.
//
// One parsed line plus one document becomes N commands or one sentence.
// `parseDropLine` did the text; this does the resolution, the labels and
// the refusals, and it does all of it against an UNMUTATED document.
//
// ═════════════════════════════════════════════════════════════════════
// EVERYTHING IS BUILT AGAINST ONE UNMUTATED DOCUMENT, ON PURPOSE
// ═════════════════════════════════════════════════════════════════════
// `Living Room: 4x Cat6, 2x RG6, 2x 16/4, 1x 22/4` is NINE drops, one
// outlet and one undo entry. If the planner applied as it went, a line
// that refused on its seventh drop would leave six behind and a document
// the user did not ask for.
//
// So the whole line is planned first and applied never: the sibling
// reservations (`alsoUsedLabels`, `alsoUsedDesignators`, `alsoOutlets`)
// carry what the previous drops in THIS line have spent, and the caller
// applies the resulting `Transaction` or applies nothing. That is also
// why nine drops cost one undo, which is what a person means by "undo
// that line".
//
// ═════════════════════════════════════════════════════════════════════
// DR-023's CHAIN, IMPLEMENTED ONCE, IN [serviceTagFor]
// ═════════════════════════════════════════════════════════════════════
// `@service=`, else the `OutletTemplate.tag`, else the media's
// `shortTag`. There is no fourth step and no placeholder. A media type
// with no `shortTag` — possible only for a user-created type from an
// RJ-009 import — REFUSES rather than printing `media.cat6` on a label.
//
// ═════════════════════════════════════════════════════════════════════
// THE TWO OUTCOMES THAT ARE NOT REFUSALS, AND WHY THEY EXIST
// ═════════════════════════════════════════════════════════════════════
// A missing room and a missing Structure device are the two things a
// blank project is always missing, and both are one keystroke to fix.
// Returning them as REFUSALS would make the surface print an error for
// the most ordinary thing that can happen on line one; returning them as
// distinct outcomes lets it print an offer instead ("Create Attic?
// [Enter]"). Nothing is created behind the user's back either way —
// docs/04 §3.4 forbids the silent version in both directions.
import 'package:meta/meta.dart';
import 'package:rackpal_core/src/commands/bind_endpoint_command.dart';
import 'package:rackpal_core/src/commands/command.dart';
import 'package:rackpal_core/src/commands/home_run_commands.dart'
    show AddHomeRunCommand, resolveRackLabel, usedFieldLabels, usedRackLabels;
import 'package:rackpal_core/src/commands/pathway_commands.dart';
import 'package:rackpal_core/src/commands/rack_commands.dart' show nextOrder;
import 'package:rackpal_core/src/commands/structure_commands.dart';
import 'package:rackpal_core/src/derived/schedule.dart' show kUngroupedTitle;
import 'package:rackpal_core/src/derived/structure_table.dart'
    show resolveTerminationToken, terminationTokens;
import 'package:rackpal_core/src/model/device_instance.dart';
import 'package:rackpal_core/src/model/entity_meta.dart';
import 'package:rackpal_core/src/model/enums.dart' show TerminationType;
import 'package:rackpal_core/src/model/link.dart' show RoughInStatus;
import 'package:rackpal_core/src/model/location.dart';
import 'package:rackpal_core/src/model/outlet.dart';
import 'package:rackpal_core/src/model/rack_document.dart';
import 'package:rackpal_core/src/model/registries.dart';
import 'package:rackpal_core/src/structure/drop_build.dart';
import 'package:rackpal_core/src/structure/drop_line_parser.dart';
import 'package:rackpal_core/src/units/ids.dart';

/// The outcome of [planDropLine].
sealed class DropLinePlan {
  const DropLinePlan();
}

/// N drops, ready to apply as one undo entry.
@immutable
final class DropLinePlanReady extends DropLinePlan {
  const DropLinePlanReady({
    required this.commands,
    required this.dropCount,
    required this.fieldLabels,
    required this.outletCreated,
    this.pathwayNames = const [],
    this.rackLabels = const [],
    this.warnings = const [],
  });

  /// In application order: the outlet, if one is being created, then the
  /// drops. Apply them inside ONE transaction.
  final List<Command<RackDocument>> commands;

  /// DROPS ONLY. A pathway is not a drop and docs/07 §4.2 excludes it
  /// from the Σ drop count in so many words; [pathwayNames] is the other
  /// half (CR-109, DR-032).
  final int dropCount;

  /// The labels these drops will carry, in order — what a preview line
  /// shows before the user commits, and what the timing harness reads.
  final List<String> fieldLabels;

  /// The pathways this line creates, in order, named per DR-032
  /// §11.31.1. Empty for every line that names no conduit, which is
  /// almost all of them.
  final List<String> pathwayNames;

  /// False when the line was conduit only, because a conduit terminates
  /// at no outlet (CR-109: "never a `Link` and never a `Port`").
  final bool outletCreated;

  /// The rack labels `@panel=` allocated, in order (DR-040 §11.39.2).
  ///
  /// EMPTY IS TWO DIFFERENT FACTS AND THE CALLER MUST NOT CONFLATE THEM:
  /// the line named no panel, or it named one whose location cannot render
  /// the pattern yet (§11.39.5). [warnings] carries the second, which is
  /// why an empty list here is never on its own a reason to say nothing.
  final List<String> rackLabels;

  /// Things the surface should SAY but which do not stop the line, e.g.
  /// a modifier this build does not understand. Never silent.
  final List<String> warnings;
}

/// The line cannot be turned into drops, and here is one sentence saying
/// why. [column] points into the ORIGINAL line where one is known.
@immutable
final class DropLinePlanRefused extends DropLinePlan {
  const DropLinePlanRefused(this.reason, [this.column]);
  final String reason;
  final int? column;
}

/// The room does not exist yet. Not an error: an offer.
@immutable
final class DropLinePlanNeedsLocation extends DropLinePlan {
  const DropLinePlanNeedsLocation(this.locationName);
  final String locationName;
}

/// The project has no Structure device to hang an outlet on.
@immutable
final class DropLinePlanNeedsStructure extends DropLinePlan {
  const DropLinePlanNeedsStructure();
}

/// Plans one line's worth of drops against [doc], mutating nothing.
///
/// [alsoUsedLabels] and [alsoUsedDesignators] let a CALLER plan several
/// lines against one document before applying any of them, which is what
/// a pasted block of six rooms is.
DropLinePlan planDropLine({
  required RackDocument doc,
  required DropLineParsed line,
  required DateTime now,
  required String actor,
  Set<String> alsoUsedLabels = const {},
  Set<String> alsoUsedDesignators = const {},
  Set<String> alsoUsedRackLabels = const {},
  Uuid? structureBodyId,
}) {
  // --- the room ------------------------------------------------------
  final location = _resolveLocation(doc, line.locationName);
  if (location == null) return DropLinePlanNeedsLocation(line.locationName);

  // --- the Structure device the outlet hangs on ----------------------
  // [structureBodyId] IS THE EDITOR'S CURRENT BODY (M3-E/3, #158). The
  // refusal below used to be unconditional above one body and named this
  // task as what would retire it; it is retired, and what survives is the
  // narrower case where a caller genuinely said nothing.
  if (doc.structures.isEmpty) return const DropLinePlanNeedsStructure();
  if (structureBodyId != null && !doc.structures.containsKey(structureBodyId)) {
    return const DropLinePlanRefused(
      'That Structure device is not in this project any more.',
    );
  }
  if (structureBodyId == null &&
      doc.structures.length > 1 &&
      line.outletDesignation == null) {
    // Still refused rather than guessed: filing sixty drops on the wrong
    // Structure body puts them on the wrong sheet, and a caller that
    // named neither a body nor an outlet has not said which panel.
    return const DropLinePlanRefused(
      'This project has more than one Structure device, so this line does '
      'not say which one these drops belong to. Choose one in the editor, '
      'or name an existing outlet with @outlet="…".',
    );
  }

  // --- @status= ------------------------------------------------------
  RoughInStatus? status;
  if (line.status case final raw?) {
    status = _resolveStatus(raw);
    if (status == null) {
      return DropLinePlanRefused(
        '"$raw" is not a rough-in status. Use one of: '
        '${RoughInStatus.values.map((s) => s.name).join(', ')}.',
      );
    }
  }

  // --- the media, all of them, before anything is allocated ----------
  final media = <MediaTypeDef>[];
  for (final item in line.items) {
    final def = resolveMediaToken(doc.registries, item.mediaToken);
    if (def == null) {
      return DropLinePlanRefused(
        '"${item.mediaToken}" is not a cable this project knows. Try its '
        'trade name (Cat6, RG6, 16/4) or add the type first.',
        item.column,
      );
    }
    media.add(def);
  }

  // --- conduit is not a cable (CR-109, DR-032) ------------------------
  // Partitioned BEFORE the outlet, because a line that names only
  // conduit must not create one: a pathway terminates at no outlet and
  // CR-109 says "never a `Link` and never a `Port`". An outlet minted
  // here would be a real entity on the Structure body with no drop on
  // it, which the Σ drop count and the outlet rollup would both then
  // have to explain.
  final cableIndices = <int>[];
  final pathwayCommands = <Command<RackDocument>>[];
  final pathwayNames = <String>[];

  // Grown as the line is planned, because `nextPathwayOrder` reads the
  // DOCUMENT and cannot see commands that have not been applied yet. Two
  // conduits on one line would otherwise be allocated the same order,
  // which makes their list position depend on map iteration (§8.4).
  final plannedOrders = [for (final p in doc.pathways.values) p.order];
  for (var i = 0; i < line.items.length; i++) {
    if (!media[i].isPathwayOnly) {
      cableIndices.add(i);
      continue;
    }
    final item = line.items[i];
    for (var n = 0; n < item.count; n++) {
      // DR-032 §11.31.1: the location and the medium AS TYPED, with a
      // 1-based index only when the count exceeds one. A description,
      // never `PW-LR-1`, which is the allocated series DR-026 §11.25.1
      // refused for the designator and which this must not reintroduce
      // through the name.
      final name = item.count == 1
          ? '${location.name} ${item.mediaToken}'
          : '${location.name} ${item.mediaToken} ${n + 1}';
      final order = nextOrder(plannedOrders);
      plannedOrders.add(order);
      pathwayNames.add(name);
      pathwayCommands.add(
        AddPathwayCommand(
          name: name,
          order: order,
          now: now,
          actor: actor,
          // DR-035 §11.34.2. The NAME is a description and cannot be
          // read back; these two are the facts, and without them the
          // matrix cell that creates the same entity could never count
          // its own pathways. `toLocationId` stays null: nobody has said
          // where the other end lands (G4).
          pathwayMedia: media[i].id,
          fromLocationId: location.id,
        ),
      );
    }
  }

  // A CONDUIT-ONLY LINE IS COMPLETE HERE. No outlet, no drops, no field
  // labels; `dropCount` is 0 and the pathways are the whole result.
  if (cableIndices.isEmpty) {
    return DropLinePlanReady(
      commands: pathwayCommands,
      dropCount: 0,
      fieldLabels: const [],
      outletCreated: false,
      pathwayNames: pathwayNames,
      warnings: _warningsFor(line, status),
    );
  }

  // --- the outlet: joined, or created --------------------------------
  final outletLookup = _resolveOutlet(
    doc,
    location.id,
    line.outletDesignation,
  );
  final existing = outletLookup.match;
  if (line.outletDesignation != null && existing == null) {
    // Creating it is fine; what is not fine is creating it on a GUESSED
    // Structure body when there are several. A named body is not a guess.
    if (structureBodyId == null && doc.structures.length > 1) {
      return DropLinePlanRefused(
        'No outlet is called "${line.outletDesignation}", and this project '
        'has more than one Structure device to create it on.',
      );
    }
  }

  final commands = <Command<RackDocument>>[];
  final Outlet? plannedOutlet;
  final bool outletCreated;

  // ═══════════════════════════════════════════════════════════════════
  // `@nobox` MAKES NO OUTLET AT ALL (DR-070 §11.69)
  // ═══════════════════════════════════════════════════════════════════
  // A ceiling speaker has no low-voltage box, and this planner's job up
  // to here has been "find the box or make one". A line carrying the
  // flag skips both: no `AddOutletCommand` is emitted, and the runs name
  // the Structure body directly.
  //
  // `@outlet=` AND `@nobox` TOGETHER ARE REFUSED rather than silently
  // ranked, because the line states two incompatible things and the
  // person meant one of them.
  if (line.noBox) {
    if (line.outletDesignation != null) {
      return const DropLinePlanRefused(
        '@nobox says these runs come out of no box, and @outlet= names '
        'one. Use one or the other.',
      );
    }
    plannedOutlet = null;
    outletCreated = false;
  } else if (existing != null) {
    plannedOutlet = existing;
    outletCreated = false;
  } else {
    // The named body, else the only one. `keys.first` was safe before
    // only because every path reaching here had already refused above one
    // body; it is now reached with several, so the fallback goes through
    // `defaultStructureBody` and the choice is deterministic rather than
    // whatever the map iterated first.
    final bodyId =
        structureBodyId ??
        defaultStructureBody(doc)?.id ??
        doc.structures.keys.first;
    final add = AddOutletCommand(
      structureBodyId: bodyId,
      designation:
          line.outletDesignation ?? outletDesignationFor(doc, location),
      order: nextOutletOrder(doc),
      now: now,
      actor: actor,
      locationId: location.id,
    );
    commands.add(add);
    outletCreated = true;
    // The outlet the drops will name, before it is in the document. See
    // `alsoOutlets` in `buildAddHomeRunCommand`.
    plannedOutlet = Outlet(
      id: add.id,
      structureBodyId: bodyId,
      designation: add.designation,
      order: add.order,
      meta: EntityMeta(createdAt: now, updatedAt: now, updatedBy: actor),
      locationId: location.id,
    );
  }

  // --- the terminations the line named (DR-043 §11.42.3) --------------
  //
  // RESOLVED BEFORE ANY COMMAND IS BUILT, so a mistyped termination
  // refuses the WHOLE line with a caret on the token rather than
  // creating three drops and then giving up on the fourth. That is
  // `buildDropsFor`'s own contract read one stage earlier: a gesture
  // that refused on its seventh drop must leave six behind, and a line
  // that cannot be parsed leaves none.
  final terminations = <int, TerminationType?>{};
  final rackTerminations = <int, TerminationType?>{};
  for (final i in cableIndices) {
    final token = line.items[i].terminationToken;
    if (token != null) {
      final resolved = resolveTerminationToken(token);
      if (resolved == null) {
        return DropLinePlanRefused(
          '"$token" is not a field termination. Try one of: '
          '${terminationTokens().join(', ')}.',
          line.items[i].terminationColumn,
        );
      }
      terminations[i] = resolved;
    }
    // THE SECOND COLON, RESOLVED THE SAME WAY AND REFUSED THE SAME WAY
    // (DR-046 §11.45.3). One vocabulary for both ends: a termination is
    // a termination, and the end it is on is which colon it followed.
    final rackToken = line.items[i].rackTerminationToken;
    if (rackToken != null) {
      final resolved = resolveTerminationToken(rackToken);
      if (resolved == null) {
        return DropLinePlanRefused(
          '"$rackToken" is not a rack termination. Try one of: '
          '${terminationTokens().join(', ')}.',
          line.items[i].rackTerminationColumn,
        );
      }
      rackTerminations[i] = resolved;
    }
  }

  // --- @signal=, the family (DR-025 §11.24.3) -------------------------
  // AN UNRESOLVED VALUE REFUSES AND NEVER INVENTS A FAMILY, which is the
  // OPPOSITE of RJ-012's rule for media and is already ruled: docs/07 §3
  // makes media types user-extensible in v1 and keeps signal families
  // catalog-updated. A family invented from a typo would have no domain,
  // no colour, no dash and no `acceptedFamilies`, which is a run the DRC
  // and the palette both cannot reason about.
  SignalFamilyId? signalFamily;
  if (line.signal case final token? when token.trim().isNotEmpty) {
    final def = resolveSignalFamilyToken(doc.registries, token);
    if (def == null) {
      return DropLinePlanRefused(
        'No signal family is called "$token". '
        'Try a short tag like "hbt" or "avoip", or leave it off: a drop '
        'with no family is a first-class state and the SERVICE column '
        'can set it later.',
      );
    }
    signalFamily = def.id;
  }

  // --- the drops -----------------------------------------------------
  final template = plannedOutlet == null
      ? null
      : _templateOf(doc, plannedOutlet);
  final built = buildDropsFor(
    doc: doc,
    location: location,
    outlet: plannedOutlet,
    // ONLY WHEN THERE IS NO OUTLET, because with one the outlet is the
    // authority on which body owns the run and passing both is refused.
    // Resolved the same way the outlet path resolves it: the editor's
    // current body, else the default, else the only one.
    structureBodyId: plannedOutlet != null
        ? null
        : structureBodyId ??
              defaultStructureBody(doc)?.id ??
              doc.structures.keys.first,
    signalFamily: signalFamily,
    // THE CABLE ITEMS ONLY. Conduit was partitioned out above and has
    // already become `AddPathwayCommand`s.
    items: [
      for (final i in cableIndices)
        PlannedDropItem(
          media: media[i],
          count: line.items[i].count,
          column: line.items[i].column,
          token: line.items[i].mediaToken,
          termination: terminations[i],
          rackTermination: rackTerminations[i],
        ),
    ],
    serviceTag: (item) => serviceTagFor(
      modifier: line.service,
      templates: doc.registries.outletTemplates,
      template: template,
      media: item.media,
    ),
    now: now,
    actor: actor,
    usedLabels: usedFieldLabels(doc, alsoUsed: alsoUsedLabels),
    usedDesignators: {
      for (final l in doc.links.values) l.designator,
      ...alsoUsedDesignators,
    },
    usedNetNames: {for (final n in doc.nets.values) n.name},
  );

  switch (built) {
    case DropBuildRefused(:final reason, :final column):
      return DropLinePlanRefused(reason, column);
    case DropBuildOk(commands: final drops, :final fieldLabels):
      final landing = _landDrops(
        doc: doc,
        line: line,
        drops: drops,
        alsoUsedRackLabels: alsoUsedRackLabels,
        now: now,
        actor: actor,
      );
      if (landing.refusal case final r?) return DropLinePlanRefused(r);

      return DropLinePlanReady(
        // The outlet first when one is being created, then the drops,
        // then the pathways. Order matters only for the outlet, which
        // the drops name; the pathways reference nothing on this line.
        //
        // THE BINDS COME LAST AND MUST. Each names a `Link` by the id its
        // `AddHomeRunCommand` minted in ITS constructor, and that link is
        // not in the document until the drop ahead of it has applied.
        commands: [
          ...commands,
          ...drops,
          ...landing.commands,
          ...pathwayCommands,
        ],
        dropCount: fieldLabels.length,
        fieldLabels: fieldLabels,
        outletCreated: outletCreated,
        pathwayNames: pathwayNames,
        rackLabels: landing.rackLabels,
        warnings: [
          // FIRST, because it is about what this line just did rather than
          // about how it was written. DR-053 §11.52.3.
          if (outletLookup.elsewhere case final other?)
            _sameNameElsewhere(
              designation: line.outletDesignation!,
              here: location.name,
              other: other,
            ),
          ..._warningsFor(line, status),
          ...landing.warnings,
        ],
      );
  }
}

/// What `@panel=` produced: the binds, the labels they wrote, and anything
/// the user has to be told.
typedef _Landing = ({
  List<Command<RackDocument>> commands,
  List<String> rackLabels,
  List<String> warnings,
  String? refusal,
});

const _Landing _noLanding = (
  commands: <Command<RackDocument>>[],
  rackLabels: <String>[],
  warnings: <String>[],
  refusal: null,
);

/// Lands every drop on this line on the next free position of `@panel=`
/// (DR-040 §11.39.2 clause 2).
///
/// IT REFUSES RATHER THAN CREATING A PANEL. `@panel=PP-9` on a project with
/// no `PP-9` is a typo far more often than it is an intention, and a
/// gesture that invented a twenty-four-port device out of a typo would put
/// hardware nobody chose on the equipment list. Same rule
/// `buildAddHomeRunCommand` follows for an outlet it cannot resolve.
///
/// IT ALSO REFUSES WHEN THE PANEL IS TOO SMALL, and says by how much.
/// Landing four of six drops silently would leave two rows on the Pull
/// Sheet that look identical to a deliberate rough-in coil.
_Landing _landDrops({
  required RackDocument doc,
  required DropLineParsed line,
  required List<Command<RackDocument>> drops,
  required Set<String> alsoUsedRackLabels,
  required DateTime now,
  required String actor,
}) {
  final wanted = line.panelDesignator?.trim();
  if (wanted == null || wanted.isEmpty) return _noLanding;

  final panel = _resolvePanel(doc, wanted);
  if (panel == null) {
    return (
      commands: const [],
      rackLabels: const [],
      warnings: const [],
      refusal:
          'No device in this project is called "$wanted", so there is '
          'nothing to land these drops on.',
    );
  }

  final homeRuns = [
    for (final c in drops)
      if (c is AddHomeRunCommand) c,
  ];
  final free = freePanelPositions(doc, panelDeviceId: panel.id);
  if (free.length < homeRuns.length) {
    return (
      commands: const [],
      rackLabels: const [],
      warnings: const [],
      refusal:
          '${panel.designator} has ${free.length} free position(s) and this '
          'line needs ${homeRuns.length}. Nothing was landed.',
    );
  }

  final commands = <Command<RackDocument>>[];
  final labels = <String>[];
  final warnings = <String>[];
  // ONE SCAN, EXTENDED AS IT GOES. Ten drops from one line are planned
  // against ONE unmutated document, so a label spent by drop 3 has to be
  // visible to drop 4 or two of them come out identical (CR-113).
  final spent = usedRackLabels(doc, alsoUsed: alsoUsedRackLabels);

  for (var i = 0; i < homeRuns.length; i++) {
    final position = free[i];
    final resolved = resolveRackLabel(
      doc: doc,
      panelDeviceId: panel.id,
      // THE NUMBER ON THE PART, not the designator this product
      // allocated (DR-040 §11.39.8).
      portDesignator: position.positionToken,
      usedRackLabels: spent,
    );
    if (resolved.note case final n? when !warnings.contains(n)) {
      // ONCE PER LINE, not once per drop. Six drops onto a panel with no
      // floor number is one fact about one room, and printing it six times
      // is how a user learns to stop reading warnings.
      warnings.add(n);
    }
    if (resolved.label case final l?) {
      spent.add(l);
      labels.add(l);
    }
    commands.add(
      BindEndpointCommand(
        linkId: homeRuns[i].id,
        port: position.port,
        rackLabel: resolved.label,
        now: now,
        actor: actor,
      ),
    );
  }

  return (
    commands: commands,
    rackLabels: labels,
    warnings: warnings,
    refusal: null,
  );
}

/// The device `@panel=` names, matched on designator, case-insensitively.
///
/// DESIGNATOR AND NOT NAME, unlike `_resolveLocation`'s two-way match. A
/// designator is the identifier printed on the rack and on every schedule
/// (CR-042); a device NAME is free text that two panels can share, and a
/// gesture that landed on "whichever Patch Panel matched first" would put
/// the drop in a different rack depending on map order.
DeviceInstance? _resolvePanel(RackDocument doc, String designator) {
  final want = designator.trim().toLowerCase();
  for (final d in doc.devices.values) {
    if (d.designator.trim().toLowerCase() == want) return d;
  }
  return null;
}

/// What the line asked for that this build did not do.
///
/// SAID, NEVER SWALLOWED. Somebody who typed `@status=planned` and
/// watched six drops appear has been told their input was understood;
/// three of the four modifiers docs/07 §4.3 shows are parsed and not yet
/// applied, and each says so on the line that produced the drops.
List<String> _warningsFor(DropLineParsed line, RoughInStatus? status) {
  final out = <String>[];
  for (final e in line.unknownModifiers.entries) {
    out.add(
      'This build does not understand @${e.key}, so "${e.value}" was not '
      'applied.',
    );
  }
  if (line.pathwayName case final p?) {
    out.add(
      'Pathways are not created from a drop line yet, so "$p" was not '
      'applied.',
    );
  }
  if (status != null) {
    out.add(
      'Rough-in status is not set from a drop line yet, so '
      '"${status.name}" was not applied.',
    );
  }
  return out;
}

// ─────────────────────────────────────────────────────────────────────
// RESOLUTION
// ─────────────────────────────────────────────────────────────────────

/// docs/07 §5.1's own normalisation, one function so the DSL and a later
/// CSV import cannot disagree: case-, space-, underscore- and
/// hyphen-insensitive.
String normaliseMediaToken(String s) =>
    s.toLowerCase().replaceAll(RegExp(r'[\s_-]'), '');

/// A media token → a registry entry, or null.
///
/// FOUR WAYS IN, WIDEST LAST. `aliases` is the authority (docs/07 §5.1),
/// then `shortTag`, then the id's own tail, then `displayName`. The tail
/// is what makes `Cat6` resolve at all: canon's tag for `media.cat6` is
/// `C6`, and nothing in the synonym block would match the word the
/// corpus's own worked line actually types — except that the block DOES
/// list `cat6`. The tail is kept anyway because a user-created type from
/// an RJ-009 import has no aliases and no tag, and its id is all it has.
MediaTypeDef? resolveMediaToken(Registries registries, String token) {
  final want = normaliseMediaToken(token);
  if (want.isEmpty) return null;

  for (final d in registries.mediaTypes.values) {
    for (final a in d.aliases) {
      if (normaliseMediaToken(a) == want) return d;
    }
  }
  for (final d in registries.mediaTypes.values) {
    if (d.shortTag case final t? when normaliseMediaToken(t) == want) return d;
  }
  for (final d in registries.mediaTypes.values) {
    final tail = d.id.v.contains('.') ? d.id.v.split('.').last : d.id.v;
    if (normaliseMediaToken(tail) == want) return d;
  }
  for (final d in registries.mediaTypes.values) {
    if (normaliseMediaToken(d.displayName) == want) return d;
  }
  return null;
}

/// A signal-family token → a registry entry, or null.
///
/// **DR-060 §11.59.4's chain**: `aliases`, then `shortTag`, then the id's
/// own tail, then `displayName`. That is [resolveMediaToken]'s shape
/// exactly, aliases first and widest last. `hbt`, `hdbaset` and `avoip`
/// land on the later steps, as they did before aliases existed.
///
/// **AN UNRESOLVED VALUE ANSWERS NULL AND NOTHING CREATES A FAMILY**,
/// which is the OPPOSITE of RJ-012's rule for media and is already
/// ruled: docs/07 §3 says media types are user-extensible in v1 while
/// "signal families and connector types remain catalog-updated". A
/// family invented from a typo would have no domain, no colour, no dash
/// and no `acceptedFamilies`, which is a run the DRC and the palette
/// both cannot reason about.
///
/// **`aliases` JOINED THE CHAIN AT DR-060 §11.59.4, AND THE RULING IS
/// WHAT THIS DOCSTRING USED TO ASK FOR.** It said, correctly, that
/// DR-025 named three steps, that `SignalFamilyDef.aliases` was not
/// among them, and that widening the chain was a ruling rather than a
/// patch. The ruling exists now: Quick Add's DSL types `hdbt`, which is
/// docs/06 §4.1's own spelling and matched no step of the three, and the
/// list it needed had been empty on all 55 families since M0. The old
/// distinction still holds and is why aliases are seeded SPARSELY here
/// but authored freely on media: media aliases are the user-extensible
/// surface RJ-009 governs, a family's are catalog data.
///
/// Placed beside [resolveMediaToken] because two callers need it and
/// neither owns it: the CSV `signal` column (M3-F/6) and `@signal=`
/// (#587). Two copies would be two chances to disagree about what `hbt`
/// means, **which is exactly why Quick Add widened this instead of
/// growing its own** (DR-060 §11.59.3). Both callers inherit the step.
///
/// THREE CALLERS NOW, AND THE THIRD IS NOT A COPY. The SERVICE picker's
/// filter box also has to understand `hbt`, but it FILTERS where this
/// RESOLVES: `@signal=hdb` must refuse, and typing `hdb` into the box
/// must show HDBaseT. `SignalFamilyCellOption.searchKey` is built from
/// the same four fields this walks, so the two agree about the
/// vocabulary while disagreeing about how much of a token counts.
SignalFamilyDef? resolveSignalFamilyToken(
  Registries registries,
  String token,
) {
  final want = normaliseMediaToken(token);
  if (want.isEmpty) return null;

  for (final d in registries.signalFamilies.values) {
    for (final a in d.aliases) {
      if (normaliseMediaToken(a) == want) return d;
    }
  }
  for (final d in registries.signalFamilies.values) {
    if (d.shortTag case final t? when normaliseMediaToken(t) == want) return d;
  }
  for (final d in registries.signalFamilies.values) {
    final tail = d.id.v.contains('.') ? d.id.v.split('.').last : d.id.v;
    if (normaliseMediaToken(tail) == want) return d;
  }
  for (final d in registries.signalFamilies.values) {
    if (normaliseMediaToken(d.displayName) == want) return d;
  }
  return null;
}

/// A connector token → a registry entry, or null. DR-060 §11.59.4's
/// other half.
///
/// **TWO STEPS, NOT FOUR**, and the missing two are deliberate.
/// `displayName` is not walked because connector display names are
/// authored for a table cell rather than for typing (`RJ45 (8P8C)`,
/// `3.5 mm stereo (TRS)`, `XLR 3-pin`), so a `displayName` step would
/// match almost nothing and would occasionally match something absurd.
/// There is no `shortTag` on `ConnectorTypeDef` at all.
///
/// **THIS IS IN THIS FILE DESPITE ITS NAME, AND THE SIBLING FUNCTIONS
/// ARE WHY.** [resolveMediaToken] and [resolveSignalFamilyToken] already
/// live here, and their own docstring gives the rule: token resolution
/// gets one home, because two copies are two chances to disagree. A
/// connector resolver in the builder and a family resolver in structure
/// would be exactly the split that rule forbids, one registry apart. The
/// trio has outgrown a file called `drop_line_planner`; moving all three
/// is a rename, not a Quick Add task, and is left as one.
ConnectorTypeDef? resolveConnectorToken(Registries registries, String token) {
  final want = normaliseMediaToken(token);
  if (want.isEmpty) return null;

  for (final d in registries.connectorTypes.values) {
    for (final a in d.aliases) {
      if (normaliseMediaToken(a) == want) return d;
    }
  }
  for (final d in registries.connectorTypes.values) {
    final tail = d.id.v.contains('.') ? d.id.v.split('.').last : d.id.v;
    if (normaliseMediaToken(tail) == want) return d;
  }
  return null;
}

/// DR-023 §11.22.1's chain, and the only place it is written down in
/// code. Null means "nothing in the chain had anything", which is a
/// refusal and never a default.
///
/// ═════════════════════════════════════════════════════════════════════
/// STEP 1 RESOLVES THROUGH A TEMPLATE BEFORE IT FALLS BACK TO LITERAL
/// ═════════════════════════════════════════════════════════════════════
/// DR-023's own worked example is `Exterior: 6x Cat6 @service=camera` →
/// `EXT-CAM-4`, and `CAMERA` is not `CAM`. The modifier names the same
/// kind of thing step 2 does — an `OutletTemplate` — and differs only in
/// HOW that template is chosen: typed on this line, rather than carried
/// by the outlet. So `camera` is looked up by tag and then by name, and
/// what reaches the label is the template's `tag`.
///
/// THE LITERAL FALLBACK IS NOT A CONSOLATION PRIZE. `@service=poe` on a
/// project that authored no template such as that still has to produce a
/// label, and refusing would make the modifier useless for any word the
/// nine seeded templates do not cover.
///
/// THIS COMMENT USED TO SAY THE OTHER ARM WAS UNREACHABLE. Until M3-C/4
/// (`5abb8b3`) `registries.outletTemplates` was `{}` in every document,
/// so the literal arm was the only one that could fire and `EXT-CAM-4`
/// was not reproducible. Nine templates ship now and the corpus's own
/// label comes out of a blank project.
String? serviceTagFor({
  required String? modifier,
  required Map<String, OutletTemplate> templates,
  required OutletTemplate? template,
  required MediaTypeDef media,
}) {
  final typed = modifier?.trim() ?? '';
  if (typed.isNotEmpty) {
    final named = resolveOutletTemplate(templates, typed);
    if (named?.tag case final t? when t.trim().isNotEmpty) return t.trim();
    return typed.toUpperCase();
  }
  if (template?.tag case final t? when t.trim().isNotEmpty) return t.trim();
  return media.shortTag;
}

/// What the surface says when a designation is in use in another room.
///
/// It reports what happened and does not ask a question, because the line
/// has already been planned and DR-053 §11.52.3 makes this a note rather
/// than a refusal. Naming BOTH rooms is the point: the reader is deciding
/// whether they meant the other one, and a sentence that omits either
/// half cannot help them do that.
String _sameNameElsewhere({
  required String designation,
  required String here,
  required String other,
}) =>
    '"$designation" also exists in $other. '
    'Created a new one in $here.';

/// docs/07 §5.3's normal form for a name typed on either entry path.
///
/// Case-folded, trimmed, and **internal whitespace runs collapsed to one
/// space** (DR-053 §11.52.4). `Living  Room` matches `Living Room`;
/// `LivingRoom` does not.
///
/// THE COMMENT ON [_resolveLocation] CLAIMED THIS BEFORE THE CODE DID. It
/// said "case- and space-insensitive" while the body only trimmed and
/// lower-cased, so a double space created a second room from a typed line
/// and matched the existing one from a CSV import, which is two entry
/// paths disagreeing about whether two rooms are one room.
///
/// Collapsing rather than STRIPPING is the ruled reading: stripping would
/// also make two names a person reads as distinct unrepresentable in one
/// project, which is a larger claim than §5.3.1 makes.
String normaliseTypedName(String s) =>
    s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

/// Case- and space-insensitive, because a person typing sixty drops
/// types `living room` as often as `Living Room`. Falls back to the
/// location's `code`, so `LR: 4x Cat6` works once a code is set.
Location? _resolveLocation(RackDocument doc, String name) {
  final want = normaliseTypedName(name);
  for (final l in doc.locations.values) {
    if (normaliseTypedName(l.name) == want) return l;
  }
  for (final l in doc.locations.values) {
    if (normaliseTypedName(l.code) == want) return l;
  }
  return null;
}

/// The outlet [designation] names **in [locationId]**, and what to say
/// when that designation is in use somewhere else.
///
/// KEYED ON `(locationId, designation)`, WHICH IS WHAT docs/07 §5.3.2 HAS
/// ALWAYS SAID (DR-053 §11.52.2). This matched on designation alone,
/// project-wide, until `2c82f04`: `Attic: 2x Cat6 @outlet="WP-1"` on a
/// project with a Living Room `WP-1` hung the attic's drops on the LIVING
/// ROOM's plate, and nothing refused, because as far as the planner was
/// concerned the outlet resolved. Those drops then carried the wrong room
/// on the Pull Sheet, in the per-room footage subtotals and in the
/// schematic's room grouping.
///
/// The argument was already in this file, forty lines along and about a
/// different entity: [_resolvePanel] refuses to match a device by NAME
/// because a gesture landing on "whichever matched first" depends on map
/// order. `doc.outlets` is a map too.
///
/// `elsewhere` IS A NOTE AND NEVER A REFUSAL (§11.52.3). Two rooms with a
/// `WP-1` is ordinary residential work, so refusing is wrong; silence is
/// wrong for a narrower reason, that a mistyped room name and a genuine
/// second plate produce the identical outcome, so this is the only moment
/// the product can say anything useful. Deterministic by location name
/// then outlet id, because it is a sentence a user reads and a test pins.
({Outlet? match, String? elsewhere}) _resolveOutlet(
  RackDocument doc,
  Uuid locationId,
  String? designation,
) {
  if (designation == null) return (match: null, elsewhere: null);
  final want = normaliseTypedName(designation);
  final others = <Outlet>[];
  for (final o in doc.outlets.values) {
    if (normaliseTypedName(o.designation) != want) continue;
    if (o.locationId == locationId) return (match: o, elsewhere: null);
    others.add(o);
  }
  if (others.isEmpty) return (match: null, elsewhere: null);
  others.sort((a, b) {
    final an = doc.locations[a.locationId]?.name ?? '';
    final bn = doc.locations[b.locationId]?.name ?? '';
    final byName = an.compareTo(bn);
    // TOTAL, so the sentence does not depend on map order either. Two
    // outlets in one room can share neither designation nor id, but a
    // roomless pair both compare '' on the first limb.
    return byName != 0 ? byName : a.id.v.compareTo(b.id.v);
  });
  final where = doc.locations[others.first.locationId]?.name;
  return (
    match: null,
    // `NO ROOM RECORDED` rather than a second spelling of the same fact:
    // `schedule.dart` has printed that string since M2-B, and DR-021's
    // cascade makes a roomless outlet an ordinary undoable state.
    elsewhere: where == null || where.trim().isEmpty ? kUngroupedTitle : where,
  );
}

OutletTemplate? _templateOf(RackDocument doc, Outlet outlet) {
  final id = outlet.outletTemplateId;
  if (id == null) return null;
  return doc.registries.outletTemplates[id];
}

RoughInStatus? _resolveStatus(String raw) {
  final want = raw.trim().toLowerCase();
  for (final s in RoughInStatus.values) {
    if (s.name.toLowerCase() == want) return s;
  }
  return null;
}
