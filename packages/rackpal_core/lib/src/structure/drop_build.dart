// THE PART BOTH ENTRY SURFACES SHARE. Extracted from
// `drop_line_planner.dart` by M3-C/5 (#151, DR-024), unchanged in
// behaviour.
//
// ═════════════════════════════════════════════════════════════════════
// WHY THIS FILE EXISTS
// ═════════════════════════════════════════════════════════════════════
// There are now two ways to make drops: a typed line (docs/07 §4.3's
// DSL, board #147) and a picked template (`+ Add outlet ▾`, board #151).
// They differ ONLY in where the list of `(media, count)` comes from and
// in how `{SERVICE}` is chosen. Everything after that — the label, the
// `W` number, the net name, the endpoint, the refusals — is one
// behaviour, and two copies of it would drift the way `StructureDrop`
// and `Link` were ruled to drift in CR-107: "the drop schedule says 78
// ft and the wiring schedule says 90 ft, and nobody knows which to bill
// against."
//
// NOT EXPORTED from `rackpal_core.dart`. Consumers call `planDropLine`
// or `planOutletFromTemplate`; this is the shared middle and has no
// standalone meaning.
//
// ═════════════════════════════════════════════════════════════════════
// IT MUTATES NOTHING, AND THAT IS THE WHOLE CONTRACT
// ═════════════════════════════════════════════════════════════════════
// [buildDropsFor] takes an `Outlet` that may not be in the document yet
// and returns commands nobody has applied. A gesture that refused on its
// seventh drop must leave six behind — so the three `used*` sets are the
// running reservation, and the caller applies the whole list or none of
// it.
import 'package:meta/meta.dart';
import 'package:rackpal_core/src/commands/command.dart';
import 'package:rackpal_core/src/commands/home_run_commands.dart';
import 'package:rackpal_core/src/idformat/designator_allocator.dart';
import 'package:rackpal_core/src/model/conductor.dart';
import 'package:rackpal_core/src/model/enums.dart' show TerminationType;
import 'package:rackpal_core/src/model/location.dart';
import 'package:rackpal_core/src/model/outlet.dart';
import 'package:rackpal_core/src/model/rack_document.dart';
import 'package:rackpal_core/src/model/registries.dart';
import 'package:rackpal_core/src/units/ids.dart';

/// One resolved media type and how many of it — the unit both entry
/// surfaces reduce to before any id is allocated.
@immutable
final class PlannedDropItem {
  const PlannedDropItem({
    required this.media,
    required this.count,
    this.column,
    this.token,
    this.termination,
    this.rackTermination,
  });

  final MediaTypeDef media;
  final int count;

  /// How this item's FIELD end is finished, when the surface said
  /// (DR-043 §11.42.2, DR-044 §11.43).
  ///
  /// **NULL IS STILL UNSPECIFIED AND IS STILL THE DEFAULT** (§11.42.1).
  /// A typed line with no `:termination` and a template that carries none
  /// both arrive here null, and `buildDropsFor` then omits the key
  /// entirely rather than writing a value nobody stated.
  final TerminationType? termination;

  /// How the RACK end is finished, when the surface said (DR-046).
  ///
  /// **NEVER INFERRED FROM [termination].** Nine Cat6 runs in ten do
  /// match at both ends, and copying on that basis is exactly what
  /// DR-046 exists to stop: a schedule cannot then tell a stated value
  /// from a guessed one. Only the drop line's second colon fills this
  /// today; a template carries no rack end (§11.45.6).
  final TerminationType? rackTermination;

  /// Where in the typed line this came from, so a refusal can point a
  /// caret at it. Null when the items were picked from a menu and there
  /// is no line to point into.
  final int? column;

  /// What the person actually typed, for a refusal that quotes them
  /// back. Falls back to the media's display name when there is no line.
  final String? token;

  String get spelling => token ?? media.displayName;
}

/// What [buildDropsFor] produced.
sealed class DropBuildOutcome {
  const DropBuildOutcome();
}

@immutable
final class DropBuildOk extends DropBuildOutcome {
  const DropBuildOk({required this.commands, required this.fieldLabels});

  /// In order, one per drop. Apply inside ONE transaction.
  final List<Command<RackDocument>> commands;
  final List<String> fieldLabels;
}

@immutable
final class DropBuildRefused extends DropBuildOutcome {
  const DropBuildRefused(this.reason, [this.column]);
  final String reason;
  final int? column;
}

/// Turns resolved items into home-run commands against [outlet].
///
/// [outlet] may be one the caller is about to create; it is passed to
/// `buildAddHomeRunCommand` through `alsoOutlets` so the lookup resolves
/// before the document has it. The three `used*` sets are updated in
/// place as ids are spent.
///
/// [serviceTag] is called once per item and returns the `{SERVICE}`
/// segment, or null to refuse — DR-023 §11.22.4's one hole, which is
/// reachable only for a user-created media type with no `shortTag`.
DropBuildOutcome buildDropsFor({
  required RackDocument doc,
  required Location location,

  /// The box these runs come out of, or NULL for a line carrying
  /// `@nobox` (DR-070 §11.69). A ceiling speaker has no low-voltage box,
  /// so it has no `Outlet`, and the caller creates none.
  required Outlet? outlet,
  required List<PlannedDropItem> items,
  required String? Function(PlannedDropItem item) serviceTag,
  required DateTime now,
  required String actor,
  required Set<String> usedLabels,
  required Set<String> usedDesignators,
  required Set<String> usedNetNames,

  /// Which Structure body owns these runs. Required only when `outlet` is
  /// null, since with a box the outlet is the authority.
  Uuid? structureBodyId,
  Uuid? pathwayId,

  /// The family every drop on this line carries, from `@signal=`
  /// (DR-025 §11.24.3). Null is the ordinary case and leaves
  /// `structure.undetermined`, which docs/07 §4.1 calls a first-class,
  /// encouraged state.
  SignalFamilyId? signalFamily,
}) {
  final commands = <Command<RackDocument>>[];
  final labels = <String>[];
  // THE FOURTH RUNNING RESERVATION (#691). The three below it are
  // sets of strings; this one is a list because `nextOrder` takes the
  // MAX and order is the thing being allocated, not a uniqueness
  // constraint.
  final usedOrders = <FracIndex>[];

  for (final item in items) {
    final tag = serviceTag(item);
    if (tag == null) {
      return DropBuildRefused(
        '"${item.spelling}" has no short tag, so these drops cannot be '
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
          'SERVICE': tag,
          if (location.floorNumber case final f?) 'FLOOR': f,
        },
        usedLabels: usedLabels,
      );
      if (allocated is LabelTokensMissing) {
        return DropBuildRefused(
          missingTokenSentence(allocated, location),
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
        outletId: outlet?.id,
        // WITHOUT A BOX THE BODY COMES FROM HERE, since there is no
        // outlet to read it off. `buildAddHomeRunCommand` refuses both
        // or neither, so exactly one of these two is non-null.
        structureBodyId: outlet == null ? structureBodyId : null,
        fieldLabel: label,
        designator: designator,
        netName: netName,
        media: item.media.id,
        // AC-018: the far end is unbound at rough-in, and the FIELD end
        // is the one that exists. `rackEnd` stays null.
        fieldEnd: PlaceEndpoint(
          description: location.name,
          locationId: location.id,
        ),
        terminationField: item.termination,
        terminationRack: item.rackTermination,
        // LINE-LEVEL, so every drop the line makes carries it. The
        // family is a fact about the run rather than about the item,
        // and `@signal=` is scanned off the end of the line for the
        // same reason `@panel=` is.
        signalFamily: signalFamily,
        // PASSED ONLY WHEN THE SURFACE SAID, AND NULL OTHERWISE.
        // `derived/schedule.dart` calls this field "what the trim-out
        // crew actually installs" and puts it on the Termination
        // Schedule, so a value nobody stated is a false line on a sheet
        // somebody buys hardware from.
        //
        // THIS COMMENT USED TO SAY "NOT PASSED AT ALL, which is the
        // point", and the reason it gave was that neither entry surface
        // could say how the wall end is finished. That was true and
        // stopped being true at DR-043: a template carries
        // `OutletDrop.termination` (DR-044 seeds all nine) and a typed
        // line carries `4x Cat6:punchdown`. What has NOT changed is the
        // default: no claim in, no key out.
        //
        // IT USED TO WRITE `unterminated`, and the comment that stood
        // here said outright it was "the nearest true value, not the
        // right one": the field was non-nullable, so a drop entered at
        // rough-in had to claim a decision weeks before anyone opened a
        // box of jacks. Writing `keystone` instead was worse — a keystone
        // jack for an RG6 run, which is an F barrel, and for a 16/4
        // speaker run, which is not a jack at all — but `unterminated` is
        // still a DECISION, the coil left deliberately bare, and on a
        // sheet somebody buys hardware from that is a different fact from
        // "not decided". M3-J made the field nullable (G4, CR-114), so
        // the key is now simply absent and the schedule prints `—`.
        // WHICH TRUNK THESE RUNS SHARE, when the caller knows.
        //
        // Null falls back to `outlet.pathwayId` inside
        // `buildAddHomeRunCommand`, which is how the typed line has
        // always worked: the plate carries the route and its drops
        // inherit it. A CSV `Bundle` column is the other case, a
        // GROUPING stated per row, and one plate's drops may sit in two
        // bundles, so it cannot go on the outlet without lying about
        // the ones it does not cover (docs/07 §5.1, §5.3.3).
        pathwayId: pathwayId,
        now: now,
        actor: actor,
        alsoUsedLabels: usedLabels,
        alsoUsedDesignators: usedDesignators,
        alsoUsedOrders: usedOrders,
        alsoOutlets: {if (outlet != null) outlet.id: outlet},
      );
      switch (built) {
        case AddHomeRunRefused(:final reason):
          return DropBuildRefused(reason, item.column);
        case AddHomeRunReady(:final command):
          commands.add(command);
          labels.add(label);
          usedLabels.add(label);
          usedDesignators.add(designator);
          usedNetNames.add(netName);
          usedOrders.add(command.order);
      }
    }
  }

  return DropBuildOk(commands: commands, fieldLabels: labels);
}

/// `LR-1`, `LR-2`, … — an outlet designation for a gesture that named
/// none.
///
/// NOT A LABEL AND NOT SUBJECT TO CR-045. `Outlet.designation` is the
/// plate's own name in the project tree; the two things CR-045 governs
/// are the drop's field and rack labels, and those go through the format
/// engine inside [buildDropsFor]. This only has to be unique and
/// readable.
String outletDesignationFor(
  RackDocument doc,
  Location location, {
  Set<String> alsoUsed = const {},
}) {
  final code = location.code.trim();
  final stem = code.isNotEmpty ? code : location.name.trim();
  final used = {for (final o in doc.outlets.values) o.designation, ...alsoUsed};
  for (var n = 1; ; n++) {
    final candidate = '$stem-$n';
    if (!used.contains(candidate)) return candidate;
  }
}

/// An `@service=` value or a template name → a template, by tag first
/// and then by name.
///
/// TAG BEFORE NAME because the tag is the shorter, more deliberate
/// handle: someone typing fast writes `@service=tv`, and *TV location*
/// is what they mean.
OutletTemplate? resolveOutletTemplate(
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

/// Turns `LabelTokensMissing` into a sentence naming the FIELD a person
/// has to fill, rather than the token a format string happens to use.
String missingTokenSentence(LabelTokensMissing missing, Location location) {
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
        '${missing.tokens.join(', ')}, which this gesture does not supply.';
  }
  return '${location.name} needs ${named.join(' and ')} before its drops can '
      'be labelled — the pattern is "${missing.pattern}".';
}
