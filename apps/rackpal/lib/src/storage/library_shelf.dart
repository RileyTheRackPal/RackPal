// Reading the shelf: every `.rpda` in the library directory, decoded
// (`#241`, DR-102 §11.101.3, DR-103 §11.102.7).
//
// ═══════════════════════════════════════════════════════════════════════
// THIS IS THE HALF `#238` DELIBERATELY DID NOT BUILD
// ═══════════════════════════════════════════════════════════════════════
// `library_directory.dart` lists what is on the shelf and parses nothing,
// and says so in terms: *"Listing what is on the shelf and decoding what
// is in a file are two jobs, and `#239` owns the second."* `#239` built
// the decoder. This is the join, and it is a separate file for the reason
// that split existed: `listLibraries` answers a filesystem question and
// must keep answering it for `#237`'s size cap and `#240`'s import, both
// of which want paths and facts rather than templates.
//
// ═══════════════════════════════════════════════════════════════════════
// EVERY `.rpda` ON THE SHELF IS LOADED, AND THAT IS A RULING
// ═══════════════════════════════════════════════════════════════════════
// DR-103 §11.102.9: *"It does not decide which libraries are loaded:
// every `.rpda` on the shelf is, because `#240`'s import is the only
// thing that puts one there and a per-project enable list is a preference
// nobody has asked for."* So there is no enable list, no manifest of
// manifests, and no state to get out of step with the folder. The folder
// IS the state, and a user who wants a library gone deletes the file.
//
// ═══════════════════════════════════════════════════════════════════════
// A LIBRARY THAT WILL NOT LOAD IS A ROW, NOT AN ABSENCE
// ═══════════════════════════════════════════════════════════════════════
// DR-103 §11.102.7 rules the case DR-102 §11.101.6 left open: a `.rpda`
// that fails to decode comes back as a [ShelfLibrary] with a null
// [ShelfLibrary.library] and a non-null [ShelfLibrary.fault], and `#242`
// draws it as a disabled chip naming the file.
//
// **THIS IS NOT AC-042 AND THE TWO MUST NOT BE COLLAPSED.** A hash
// mismatch is a warning and never a refusal: such a library loads, its
// templates are real, and `previewLibraryImport` badges them. What lands
// here instead is a file that yields NO templates at all: not JSON, a
// `.rpdx` handed to the wrong reader, a newer `schemaVersion`, or one
// over AC-058/D8's cap. There is nothing to badge, so the fault attaches
// to the library rather than to a template.
//
// **NOTHING HERE THROWS.** `readRmdaBytes` never throws by construction
// (CR-093) and both filesystem calls are wrapped, for
// `library_directory.dart`'s reason one level up: the palette must keep
// working, and a shelf is a directory somebody else can be writing to
// while this runs.
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:rackpal/src/storage/file_store.dart';
import 'package:rackpal/src/storage/import_guard.dart';
import 'package:rackpal/src/storage/library_directory.dart';
import 'package:rackpal_core/rackpal_core.dart';

/// One library on the shelf, after an attempt to read it.
///
/// **BOTH OUTCOMES IN ONE TYPE, rather than a list plus a list of
/// errors.** The chip row in `#242` renders these in one pass and a
/// broken library keeps its place in shelf order, which is what makes it
/// findable: a person looking for `shop-kit` finds `shop-kit`, greyed,
/// where they expected it, instead of finding nothing and a count.
final class ShelfLibrary {
  const ShelfLibrary({required this.file, this.library, this.fault})
    : assert(
        (library == null) != (fault == null),
        'exactly one of library/fault is set',
      );

  /// What the directory listing found: path, id, size, mtime.
  final LibraryFile file;

  /// The decoded library, or null when it would not decode.
  final LoadedLibrary? library;

  /// Why it would not decode, or null when it did.
  ///
  /// The codec's own error object, not a rendered string: it carries the
  /// schema versions in `NewerRmdaSchemaError` and the byte counts in
  /// `DocumentTooLargeError`, and a tooltip that wants to say *"this file
  /// is schemaVersion 2 and this build reads 1"* needs the numbers rather
  /// than a sentence somebody wrote in a service.
  final Object? fault;

  /// The shelf identity, which is the file's base name either way.
  String get id => file.id;

  bool get loaded => library != null;
}

/// Reads every library on the shelf. Never throws.
///
/// Returns an empty list for a session with no data root, an absent
/// library directory or an unreadable one, all three of which
/// `listLibraries` already answers as an empty shelf.
Future<List<ShelfLibrary>> loadLibraryShelf(
  FileStore fs,
  String dataRoot, {
  int maxBytes = kMaxDocumentBytes,
  p.Context? context,
}) async {
  final files = await listLibraries(fs, dataRoot, context: context);
  final out = <ShelfLibrary>[];
  for (final file in files) {
    out.add(await _load(fs, file, maxBytes: maxBytes));
  }
  return out;
}

/// The templates half of a shelf, for a caller that only wants the
/// palette's input.
///
/// **IN SHELF ORDER**, which `listLibraries` already sorts by id, so the
/// palette's chip order and its row order come from one sort rather than
/// two that can disagree.
List<LoadedLibrary> loadedLibrariesOf(List<ShelfLibrary> shelf) => [
  for (final entry in shelf) ?entry.library,
];

Future<ShelfLibrary> _load(
  FileStore fs,
  LibraryFile file, {
  required int maxBytes,
}) async {
  // THE CAP BEFORE THE READ, on `#237`'s rule: the allocation is the
  // thing being bounded, so a check that runs after `readBytes` has
  // already returned has bounded nothing. `listLibraries` handed us a
  // size a moment ago and this stats again deliberately, because a file
  // can grow between the two and the cheap re-stat is what makes the
  // bound about the bytes actually read.
  switch (await checkImportedFileSize(fs, file.path, maxBytes: maxBytes)) {
    case Err(:final error):
      return ShelfLibrary(file: file, fault: error);
    case Ok<void>():
      break;
  }

  final Uint8List bytes;
  try {
    bytes = await fs.readBytes(file.path);
    // `on Object`: the file can vanish, lock, or live on a share that
    // blinked, and none of those is a reason to take the palette down.
    // `library_directory.dart` takes the same position on `stat`.
  } on Object catch (e) {
    return ShelfLibrary(file: file, fault: e);
  }

  return switch (readRmdaBytes(bytes, limits: JsonLimits(maxBytes: maxBytes))) {
    Ok(:final value) => ShelfLibrary(
      file: file,
      library: LoadedLibrary(
        // THE SHELF'S ID, THE MANIFEST'S NAME, and the two are separate
        // facts (see `LoadedLibrary.id`). A chip keyed on the manifest
        // would merge two libraries that both call themselves `Shop
        // Kit`, which is the collapse DR-102 §11.101.4 refuses.
        id: file.id,
        name: value.name,
        templates: value.templates,
        signalFamilies: value.signalFamilies,
      ),
    ),
    Err(:final error) => ShelfLibrary(file: file, fault: error),
  };
}
