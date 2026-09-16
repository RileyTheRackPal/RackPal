// A device library as the PALETTE sees it: an identity, a name, and the
// templates it holds (`#241`, DR-102 §11.101.3).
//
// ═══════════════════════════════════════════════════════════════════════
// WHY THIS IS NOT `DeviceLibraryFile`
// ═══════════════════════════════════════════════════════════════════════
// `rmda_codec.dart` answers "what is in this file": a manifest name and
// an array of entries. It deliberately carries **no identity**, because a
// `.rpda` is a thing you email and the same pack can sit on two shelves
// under two names. `DeviceLibraryFile`'s own header says the manifest is
// one field on purpose.
//
// DR-102 §11.101.5 needs an ID: a provenance variant "carrying a
// library's id", and `#242`'s chips have to key off something stable
// across a rebuild. That id is the SHELF's, not the file's:
// `library_directory.dart` already derives one from the base name and
// already explains why it is spelled as a derived getter. So this type is
// the join, and it exists in `rackpal_core` rather than in the app
// because `buildPlaceableTemplates` takes it and `rackpal_core` cannot
// import the app.
//
// ═══════════════════════════════════════════════════════════════════════
// IT HOLDS ENTRIES, NOT BODIES, AND THAT IS `#239`'s READING PAYING OFF
// ═══════════════════════════════════════════════════════════════════════
// `rmda_codec.dart` records why a `.rpda` carries `{templateId, version,
// contentHash, body}` rather than DR-015's literal "array of
// `TemplateBody`", and one of its three reasons was this chapter:
// *"`#241`'s provenance and AC-042's hash. Neither has anything to attach
// to on a body alone."* A palette row needs the id to place with, the
// version to name, and the hash to write into the document on
// copy-on-place (DR-103 §11.102.2). A bare body has none of the three.
import 'package:meta/meta.dart';
import 'package:rackpal_core/src/library/rmdx_codec.dart'
    show DeviceTemplateFile;

/// One library that is loaded and offering templates to the palette.
@immutable
final class LoadedLibrary {
  const LoadedLibrary({
    required this.id,
    required this.name,
    required this.templates,
  });

  /// Stable across relaunches, unique across the shelf, and NOT the
  /// manifest's name.
  ///
  /// The app passes `LibraryFile.id`, the file's base name, which is
  /// unique because these are files in one directory. Two libraries may
  /// legitimately call themselves `Shop Kit` in their manifests; they
  /// cannot both be `shop-kit.rpda`. A chip keyed on the display name
  /// would merge them, which is precisely the collapse DR-102 §11.101.4
  /// refuses one level down.
  final String id;

  /// What the library calls itself: the manifest's one field, and what a
  /// chip and a badge show a person.
  final String name;

  final List<DeviceTemplateFile> templates;

  @override
  String toString() => 'LoadedLibrary($id, ${templates.length} templates)';
}
