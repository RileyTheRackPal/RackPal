// packages/rackmate_core/lib/src/commands/media_type_commands.dart —
// pure Dart. Board M3-F/6 (#652), RJ-012, RJ-009, docs/07 §5.1.
//
// ═════════════════════════════════════════════════════════════════════
// A RULE THAT SHIPPED WITH NO WAY TO OBEY IT
// ═════════════════════════════════════════════════════════════════════
// docs/07 §5.1 is explicit about what an import does with a cable it
// does not recognise: "An unmatched value creates a new media type with
// a confirmation chip; it is never a rejected row." RJ-009 says the same
// thing from the other side, that a shop may add its own.
//
// **Nothing in `lib/` had ever written `registries.mediaTypes`.** The
// only writers anywhere in the repository were test fixtures assigning
// into the map directly. So the registry was seed-only in practice, an
// import had no way to honour RJ-012 except by rejecting the row it
// forbids rejecting, and `pathway_commands.dart`'s opening finding
// repeats itself one entity over: an entity the model carries, the codec
// round-trips and four readers consume, which no gesture could create.
//
// This file is the minimum M3-F needs. It is NOT M4-P2's media-type
// editor: there is no rename, no delete and no edit, because nothing
// asks for them yet and a command with no caller is a promise about an
// unbuilt feature.
//
// ═════════════════════════════════════════════════════════════════════
// WHY DELETE IS ABSENT AND IS NOT SIMPLY "NOT NEEDED YET"
// ═════════════════════════════════════════════════════════════════════
// Removing a media type would strand every `Link.media` naming it, and
// `Link.media` is non-nullable. That is a cascade with a real design
// question behind it (does the link go, or does the id dangle the way
// `JacketColorId` deliberately does?), and DR-021 shows what settling
// one properly costs. Undoing this command is safe because it is
// bounded: revert removes the type only if this command is what put it
// there.
import 'package:rackmate_core/src/commands/command.dart';
import 'package:rackmate_core/src/commands/label_key.dart';
import 'package:rackmate_core/src/model/rack_document.dart';
import 'package:rackmate_core/src/model/registries.dart';
import 'package:rackmate_core/src/units/ids.dart';

/// A `media.*` id for a type a person named, unique within [doc].
///
/// **THE ID IS DERIVED FROM THE SPELLING, NOT MINTED AS A UUID**, and
/// that is the opposite of every entity id in this model. A registry key
/// is not an entity id: it is written into `Link.media` on every drop,
/// printed by `registry_wire_test`'s round trip, and read by a human
/// diffing two `.rmpj` files. `media.cat6e` tells that reader what the
/// cable is; `media.9f3c-...` tells them to go and look it up.
///
/// The suffix is the four transforms `normaliseCsvHeader` uses plus one:
/// anything outside `a-z0-9_` becomes `_`, because `16/4` and `RG6 Quad`
/// are both legal trade names and neither is a legal id tail. Collisions
/// with an existing key get a numeric suffix rather than overwriting,
/// since two shops' `Cat6e` may be genuinely different cables.
MediaTypeId mediaTypeIdFor(RackDocument doc, String spelling) {
  final slug = spelling
      .toLowerCase()
      .replaceAll(RegExp('[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  final base = slug.isEmpty ? 'type' : slug;
  var candidate = MediaTypeId('media.$base');
  var n = 2;
  while (doc.registries.mediaTypes.containsKey(candidate)) {
    candidate = MediaTypeId('media.${base}_$n');
    n++;
  }
  return candidate;
}

/// The trade tag for a type created from the spelling [spelling].
///
/// **WITHOUT THIS, RJ-012 CANNOT BE HONOURED, AND THE TEST THAT FOUND IT
/// IS THE FIRST THING THAT COULD.** DR-023's label chain ends at
/// `MediaTypeDef.shortTag`, and `buildDropsFor` REFUSES a drop whose
/// chain produces nothing rather than printing `media.cat6e` on a wall
/// plate. DR-023 §11.22.4 names that hole and says it is "reachable only
/// for a user-created media type with no `shortTag`"; M3-F/6 is what
/// made it reachable, because every type RJ-012 mints was one. The
/// result was that "never a rejected row" rejected every row naming an
/// unrecognised cable, unless the sheet happened to carry a `Use`
/// column.
///
/// **THE SPELLING IS THE TAG, AND THIS IS NOT A GUESS.** `shortTag`'s
/// own doc calls it "the trade name an installer writes on a pull list",
/// and a CSV cell reading `Cat6e` is literally an installer writing a
/// trade name on a pull list. G4 forbids inventing a fact; this copies
/// one the operator stated.
///
/// **NOT TRUNCATED.** Canon's tags are short (`C6`, `RG6`, `16/4`) and
/// it is tempting to cap this at some length, but every cap is a number
/// nobody chose: `Unobtainium` clipped to `UNOBTA` is a label segment
/// that means nothing, where the full word at least reads. A long tag
/// makes a long label, which is visible in the preview grid and fixable
/// by editing the type.
String mediaShortTagFor(String spelling) {
  final cleaned = spelling.trim().toUpperCase().replaceAll(
    RegExp(r'\s+'),
    '',
  );
  return cleaned.isEmpty ? 'TYPE' : cleaned;
}

/// Adds one [MediaTypeDef] to the document's registry (RJ-012, RJ-009).
final class AddMediaTypeCommand extends Command {
  AddMediaTypeCommand({
    required this.id,
    required this.displayName,
    this.shortTag,
    this.aliases = const [],
  });

  /// Minted by [mediaTypeIdFor] in the CALLER, never in [apply] — the
  /// `Command` contract, so redo recreates the identical key and every
  /// `Link.media` stacked on it still resolves.
  final MediaTypeId id;

  /// AS THE SHEET SPELLED IT. A contractor who wrote `Cat6e` gets
  /// `Cat6e` in the dropdown, not a title-cased guess at what they meant;
  /// the spelling is the only evidence of what the cable is.
  final String displayName;

  /// Null and UNKNOWN, not empty (G4, CR-114). An imported type has no
  /// trade tag because nobody supplied one, and a schedule falls back
  /// rather than printing `''`.
  final String? shortTag;

  /// **SEEDED WITH THE SPELLING THAT CREATED IT**, so re-importing the
  /// same sheet resolves the type instead of inventing a second one.
  /// Without this the import would not be idempotent (§5.3) for exactly
  /// the rows RJ-012 exists to serve: the second pass would find no
  /// match for `Cat6e` again and mint `media.cat6e_2`.
  final List<String> aliases;

  @override
  LabelKey get label => LabelKey.addMediaType;

  /// `structure` because a cable type is part of how the building is put
  /// together, `meta` because its name prints in the schedule's `TYPE`
  /// cell for every run of it.
  @override
  EpochMask get touches => EpochMask.structure | EpochMask.meta;

  /// EMPTY, and deliberately. `affects` names ENTITIES a selection can
  /// hold; a registry key is not one, and returning a `Uuid` cast from
  /// `id` would make selection code think a media type is selectable.
  @override
  Iterable<Uuid> get affects => const [];

  @override
  void apply(RackDocument doc) {
    doc.registries.mediaTypes[id] = MediaTypeDef(
      id: id,
      displayName: displayName,
      shortTag: shortTag,
      aliases: aliases,
    );
  }

  @override
  void revert(RackDocument doc) {
    doc.registries.mediaTypes.remove(id);
  }
}
