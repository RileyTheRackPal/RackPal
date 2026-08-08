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
// DR-023's CHAIN, IMPLEMENTED ONCE, IN [_serviceTagFor]
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
import 'package:rackmate_core/src/commands/command.dart';
import 'package:rackmate_core/src/commands/home_run_commands.dart';
import 'package:rackmate_core/src/commands/structure_commands.dart';
import 'package:rackmate_core/src/idformat/designator_allocator.dart';
import 'package:rackmate_core/src/model/conductor.dart';
import 'package:rackmate_core/src/model/entity_meta.dart';
import 'package:rackmate_core/src/model/enums.dart' show TerminationType;
import 'package:rackmate_core/src/model/link.dart' show RoughInStatus;
import 'package:rackmate_core/src/model/location.dart';
import 'package:rackmate_core/src/model/outlet.dart';
import 'package:rackmate_core/src/model/rack_document.dart';
import 'package:rackmate_core/src/model/registries.dart';
import 'package:rackmate_core/src/structure/drop_line_parser.dart';

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
    this.warnings = const [],
  });

  /// In application order: the outlet, if one is being created, then the
  /// drops. Apply them inside ONE transaction.
  final List<Command> commands;

  final int dropCount;

  /// The labels these drops will carry, in order — what a preview line
  /// shows before the user commits, and what the timing harness reads.
  final List<String> fieldLabels;

  final bool outletCreated;

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
}) {
  // --- the room ------------------------------------------------------
  final location = _resolveLocation(doc, line.locationName);
  if (location == null) return DropLinePlanNeedsLocation(line.locationName);

  // --- the Structure device the outlet hangs on ----------------------
  if (doc.structures.isEmpty) return const DropLinePlanNeedsStructure();
  if (doc.structures.length > 1 && line.outletDesignation == null) {
    // Choosing between them is board #158 (M3-E/3). Refused rather than
    // guessed, because filing sixty drops on the wrong Structure body
    // puts them on the wrong sheet.
    return const DropLinePlanRefused(
      'This project has more than one Structure device, so this line does '
      'not say which one these drops belong to. Name an existing outlet '
      'with @outlet="…" until picking one is supported.',
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

  // --- the outlet: joined, or created --------------------------------
  final existing = _resolveOutlet(doc, line.outletDesignation);
  if (line.outletDesignation != null && existing == null) {
    // Creating it is fine; what is not fine is creating it on a guessed
    // Structure body when there are several.
    if (doc.structures.length > 1) {
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
    final bodyId = doc.structures.keys.first;
    final add = AddOutletCommand(
      structureBodyId: bodyId,
      designation:
          line.outletDesignation ?? _outletDesignationFor(doc, location),
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

  // --- the drops -----------------------------------------------------
  final template = _templateOf(doc, plannedOutlet);
  final usedLabels = usedFieldLabels(doc, alsoUsed: alsoUsedLabels);
  final usedDesignators = {
    for (final l in doc.links.values) l.designator,
    ...alsoUsedDesignators,
  };
  final usedNetNames = {for (final n in doc.nets.values) n.name};

  final labels = <String>[];
  for (var i = 0; i < line.items.length; i++) {
    final item = line.items[i];
    final def = media[i];

    final serviceTag = _serviceTagFor(
      modifier: line.service,
      templates: doc.registries.outletTemplates,
      template: template,
      media: def,
    );
    if (serviceTag == null) {
      // DR-023 §11.22.4: the one hole in the chain, and it refuses.
      return DropLinePlanRefused(
        '"${item.mediaToken}" has no short tag, so these drops cannot be '
        'labelled. Give the line a @service=, or give that cable type a '
        'tag.',
        item.column,
      );
    }

    for (var n = 0; n < item.count; n++) {
      final allocated = allocateOutletFieldLabel(
        settings: doc.settings,
        values: {
          if (location.code.trim().isNotEmpty)
            'ROOM_ABBR': location.code.trim(),
          'SERVICE': serviceTag,
          if (location.floorNumber case final f?) 'FLOOR': f,
        },
        usedLabels: usedLabels,
      );
      if (allocated is LabelTokensMissing) {
        return DropLinePlanRefused(
          _missingTokenSentence(allocated, location),
          item.column,
        );
      }
      final label = (allocated as LabelAllocated).label;

      final designator = allocateLinkDesignator(
        settings: doc.settings,
        usedDesignators: usedDesignators,
      );
      final netName = allocateNetName(
        settings: doc.settings,
        usedNames: usedNetNames,
      );

      final built = buildAddHomeRunCommand(
        doc: doc,
        outletId: plannedOutlet.id,
        fieldLabel: label,
        designator: designator,
        netName: netName,
        media: def.id,
        // AC-018: the far end is unbound at rough-in, and the FIELD end
        // is the one that exists. `rackEnd` stays null.
        fieldEnd: PlaceEndpoint(
          description: location.name,
          locationId: location.id,
        ),
        terminationField: TerminationType.keystone,
        now: now,
        actor: actor,
        alsoUsedLabels: usedLabels,
        alsoUsedDesignators: usedDesignators,
        alsoOutlets: {plannedOutlet.id: plannedOutlet},
      );
      switch (built) {
        case AddHomeRunRefused(:final reason):
          return DropLinePlanRefused(reason, item.column);
        case AddHomeRunReady(:final command):
          commands.add(command);
          labels.add(label);
          usedLabels.add(label);
          usedDesignators.add(designator);
          usedNetNames.add(netName);
      }
    }
  }

  return DropLinePlanReady(
    commands: commands,
    dropCount: labels.length,
    fieldLabels: labels,
    outletCreated: outletCreated,
    warnings: _warningsFor(line, status),
  );
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
/// project that authored no template still has to produce a label, and
/// refusing would make the modifier useless until board #150 seeds the
/// six templates. `registries.outletTemplates` is `{}` in every document
/// today, so the literal arm is the ONLY arm currently reachable and the
/// corpus's `EXT-CAM-4` is not reproducible until #150 lands. Stated
/// here rather than discovered there.
String? _serviceTagFor({
  required String? modifier,
  required Map<String, OutletTemplate> templates,
  required OutletTemplate? template,
  required MediaTypeDef media,
}) {
  final typed = modifier?.trim() ?? '';
  if (typed.isNotEmpty) {
    final named = _resolveTemplate(templates, typed);
    if (named?.tag case final t? when t.trim().isNotEmpty) return t.trim();
    return typed.toUpperCase();
  }
  if (template?.tag case final t? when t.trim().isNotEmpty) return t.trim();
  return media.shortTag;
}

/// An `@service=` value → a template, by tag first and then by name.
///
/// TAG BEFORE NAME because the tag is the shorter, more deliberate
/// handle: someone typing fast writes `@service=tv`, and *TV location*
/// is what they mean.
OutletTemplate? _resolveTemplate(
  Map<String, OutletTemplate> templates,
  String token,
) {
  final want = token.trim().toLowerCase();
  for (final t in templates.values) {
    if (t.tag?.trim().toLowerCase() == want) return t;
  }
  for (final t in templates.values) {
    if (t.name.trim().toLowerCase() == want) return t;
  }
  return null;
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

/// `LR-1`, `LR-2`, … — an outlet designation for a line that named none.
///
/// NOT A LABEL AND NOT SUBJECT TO CR-045. `Outlet.designation` is the
/// plate's own name in the project tree; the two things CR-045 governs
/// are the drop's field and rack labels, and those go through the format
/// engine a few lines below. This only has to be unique and readable.
String _outletDesignationFor(RackDocument doc, Location location) {
  final code = location.code.trim();
  final stem = code.isNotEmpty ? code : location.name.trim();
  final used = {for (final o in doc.outlets.values) o.designation};
  for (var n = 1; ; n++) {
    final candidate = '$stem-$n';
    if (!used.contains(candidate)) return candidate;
  }
}

/// Turns `LabelTokensMissing` into a sentence naming the FIELD a person
/// has to fill, rather than the token a format string happens to use.
String _missingTokenSentence(LabelTokensMissing missing, Location location) {
  const fields = {
    'ROOM_ABBR': 'a short code',
    'FLOOR': 'a floor number',
    'SPACE': 'a space code',
  };
  final named = [
    for (final t in missing.tokens)
      if (fields[t] case final f?) f,
  ];
  if (named.isEmpty) {
    return 'The drop label pattern "${missing.pattern}" needs '
        '${missing.tokens.join(', ')}, which this line does not supply.';
  }
  return '${location.name} needs ${named.join(' and ')} before its drops can '
      'be labelled — the pattern is "${missing.pattern}".';
}
