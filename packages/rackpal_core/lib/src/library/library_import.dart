// What importing a `.rmda` MEANS, and what an export puts in one
// (`#240`, DR-015 §11.15.3, AC-042).
//
// ═══════════════════════════════════════════════════════════════════════
// THE DECISION IS HERE AND THE DIALOG IS NOT
// ═══════════════════════════════════════════════════════════════════════
// `template_import.dart`'s split, one level up: this answers "what is in
// this file and what is wrong with it", the dialog shows a person, and
// the app copies bytes. Every branch below is testable without pumping a
// widget.
//
// ═══════════════════════════════════════════════════════════════════════
// A MISMATCH IS A BADGE AND NEVER A REFUSAL, WHICH IS WHY IT IS COUNTED
// ═══════════════════════════════════════════════════════════════════════
// `#240` states it: *"An archive whose hashes do not match imports WITH A
// BADGE, it does not refuse (AC-042)."* So the verdict is not a gate on
// the import; it is a FACT ABOUT THE FILE that travels beside it, and
// what the surface needs is a count and the names, not a boolean.
//
// **The tri-state comes with it** (`#795`). `templateHashMatches` answers
// `null` for anything that is not a real digest, which is every `.rmda`
// written before `#795` existed and every hand-authored one. Those are
// UNKNOWN, not mismatched, and counting them as mismatched would badge
// every library anybody made this week.
import 'package:rackpal_core/src/derived/placeable_templates.dart';
import 'package:rackpal_core/src/library/rmda_codec.dart';
import 'package:rackpal_core/src/library/rmdx_codec.dart';
import 'package:rackpal_core/src/library/template_hash.dart';
import 'package:rackpal_core/src/model/rack_document.dart';

/// What a `.rmda` holds, and what is wrong with it, before anything is
/// copied anywhere.
final class LibraryImportPreview {
  const LibraryImportPreview({
    required this.name,
    required this.templateCount,
    required this.mismatched,
    required this.unverifiable,
  });

  final String name;
  final int templateCount;

  /// Display names of templates whose body does not match the hash the
  /// file claims for it: **edited since export**.
  ///
  /// **NAMES RATHER THAN A COUNT**, because a badge saying "3 templates
  /// were edited" invites the question this list answers and the caller
  /// already has to render something. A count is `.length`.
  final List<String> mismatched;

  /// How many templates carry no verifiable hash at all.
  ///
  /// **NOT MISMATCHED, AND THE SEPARATION IS THE POINT** (G4, `#795`).
  /// Every `.rmda` written before the hash was real carries placeholders,
  /// and reporting those as edited would badge every library made this
  /// week. It is surfaced as its own number so a caller that wants to say
  /// "this file predates hashing" can, without inferring it.
  final int unverifiable;

  bool get hasMismatch => mismatched.isNotEmpty;
}

/// Reads [file] and reports what importing it would bring in.
LibraryImportPreview previewLibraryImport(DeviceLibraryFile file) {
  final mismatched = <String>[];
  var unverifiable = 0;
  for (final t in file.templates) {
    switch (templateHashMatches(t.body, t.contentHash)) {
      case false:
        mismatched.add(t.body.displayName);
      case null:
        unverifiable++;
      case true:
        break;
    }
  }
  return LibraryImportPreview(
    name: file.name,
    templateCount: file.templates.length,
    mismatched: mismatched,
    unverifiable: unverifiable,
  );
}

/// The templates a library export offers, newest version of each.
///
/// **PROJECT-AUTHORED ONLY, AND EXCLUDING THE SEED IS CORRECTNESS RATHER
/// THAN A FILTER.** Every install already ships the 48 archetypes, so
/// packing them makes a large file whose contents the recipient already
/// has, under ids that would then collide with their own copies on
/// import. `TemplateProvenance` already separates the two sets and
/// `buildPlaceableTemplates` already tags every row, so this is a
/// projection of an existing answer rather than a new rule.
///
/// **NEWEST VERSION OF EACH**, inherited from `buildPlaceableTemplates`
/// for its stated reason: a person packing a kit means the templates as
/// they stand, and CR-050 keeps every earlier version resolvable in the
/// projects that placed them.
List<DeviceTemplateFile> exportableLibraryTemplates(RackDocument doc) {
  final rows = buildPlaceableTemplates(doc).where((r) => r.isProjectAuthored);
  final out = <DeviceTemplateFile>[];
  for (final row in rows) {
    final snapshot = doc.templates[row.key];
    // Unreachable: `buildPlaceableTemplates` read the same map a moment
    // ago. Skipped rather than asserted for that file's own reason, a
    // projection that throws on a hand-edited document takes the export
    // down with it.
    if (snapshot == null) continue;
    out.add(DeviceTemplateFile.fromSnapshot(snapshot));
  }
  return out;
}
