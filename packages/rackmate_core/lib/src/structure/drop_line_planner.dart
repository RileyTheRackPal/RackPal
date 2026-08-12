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
import 'package:rackmate_core/src/commands/bind_endpoint_command.dart';
import 'package:rackmate_core/src/commands/command.dart';
import 'package:rackmate_core/src/commands/home_run_commands.dart'
    show AddHomeRunCommand, resolveRackLabel, usedFieldLabels, usedRackLabels;
import 'package:rackmate_core/src/commands/pathway_commands.dart';
import 'package:rackmate_core/src/commands/rack_commands.dart' show nextOrder;
import 'package:rackmate_core/src/commands/structure_commands.dart';
import 'package:rackmate_core/src/derived/structure_table.dart'
    show resolveTerminationToken, terminationTokens;
import 'package:rackmate_core/src/model/device_instance.dart';
import 'package:rackmate_core/src/model/entity_meta.dart';
import 'package:rackmate_core/src/model/enums.dart' show TerminationType;
import 'package:rackmate_core/src/model/link.dart' show RoughInStatus;
import 'package:rackmate_core/src/model/location.dart';
import 'package:rackmate_core/src/model/outlet.dart';
import 'package:rackmate_core/src/model/rack_document.dart';
import 'package:rackmate_core/src/model/registries.dart';
import 'package:rackmate_core/src/structure/drop_build.dart';
import 'package:rackmate_core/src/structure/drop_line_parser.dart';
import 'package:rackmate_core/src/units/ids.dart';

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
  final List<Command> commands;

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
  final pathwayCommands = <Command>[];
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
  final existing = _resolveOutlet(doc, line.outletDesignation);
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

  final commands = <Command>[];
  final Outlet plannedOutlet;
  final bool outletCreated;

  if (existing != null) {
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
  for (final i in cableIndices) {
    final token = line.items[i].terminationToken;
    if (token == null) continue;
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

  // --- the drops -----------------------------------------------------
  final template = _templateOf(doc, plannedOutlet);
  final built = buildDropsFor(
    doc: doc,
    location: location,
    outlet: plannedOutlet,
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
        warnings: [..._warningsFor(line, status), ...landing.warnings],
      );
  }
}

/// What `@panel=` produced: the binds, the labels they wrote, and anything
/// the user has to be told.
typedef _Landing = ({
  List<Command> commands,
  List<String> rackLabels,
  List<String> warnings,
  String? refusal,
});

const _Landing _noLanding = (
  commands: <Command>[],
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
  required List<Command> drops,
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

  final commands = <Command>[];
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
/// **DR-025 §11.24.3's chain, verbatim**: `shortTag`, then the id's own
/// tail, then `displayName`, which is [resolveMediaToken]'s widest-last
/// shape. `hbt`, `hdbaset` and `avoip` all land.
///
/// **AN UNRESOLVED VALUE ANSWERS NULL AND NOTHING CREATES A FAMILY**,
/// which is the OPPOSITE of RJ-012's rule for media and is already
/// ruled: docs/07 §3 says media types are user-extensible in v1 while
/// "signal families and connector types remain catalog-updated". A
/// family invented from a typo would have no domain, no colour, no dash
/// and no `acceptedFamilies`, which is a run the DRC and the palette
/// both cannot reason about.
///
/// **`aliases` IS NOT IN THE CHAIN, AND DR-025 IS WHY.** The ruling
/// names three steps and `SignalFamilyDef.aliases` is not among them.
/// That reads like an oversight next to [resolveMediaToken], where
/// aliases are the authority, and it is not: media aliases are the
/// user-extensible surface RJ-009 governs, and a signal family's are
/// catalog data serving the schematic. Widening this chain is a ruling.
///
/// Placed beside [resolveMediaToken] because two callers need it and
/// neither owns it: the CSV `signal` column (M3-F/6) and `@signal=`
/// (#587, unbuilt). Two copies would be two chances to disagree about
/// what `hbt` means.
SignalFamilyDef? resolveSignalFamilyToken(
  Registries registries,
  String token,
) {
  final want = normaliseMediaToken(token);
  if (want.isEmpty) return null;

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

/// Case- and space-insensitive, because a person typing sixty drops
/// types `living room` as often as `Living Room`. Falls back to the
/// location's `code`, so `LR: 4x Cat6` works once a code is set.
Location? _resolveLocation(RackDocument doc, String name) {
  final want = name.trim().toLowerCase();
  for (final l in doc.locations.values) {
    if (l.name.trim().toLowerCase() == want) return l;
  }
  for (final l in doc.locations.values) {
    if (l.code.trim().toLowerCase() == want) return l;
  }
  return null;
}

Outlet? _resolveOutlet(RackDocument doc, String? designation) {
  if (designation == null) return null;
  final want = designation.trim().toLowerCase();
  for (final o in doc.outlets.values) {
    if (o.designation.trim().toLowerCase() == want) return o;
  }
  return null;
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
