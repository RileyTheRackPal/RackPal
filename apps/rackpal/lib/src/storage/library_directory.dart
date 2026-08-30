// The writable user library directory, and what is in it (`#238`,
// AC-050/A8.2, docs/06 §7.1).
//
// ═══════════════════════════════════════════════════════════════════════
// THE THIRD STORAGE LOCATION, WHICH HAS NEVER EXISTED
// ═══════════════════════════════════════════════════════════════════════
// docs/06 §7.1 names three: *"the app catalog directory (seeded,
// read-only) plus the user library directory (writable), plus per-project
// embedded snapshots."* Two were built at M0 and M1. **This is the third**,
// and canon A8.2 accepted that its absence was an oversight rather than a
// deferral, which is why `#238` is a chapter and not an amendment.
//
// Its absence is what `device_builder_actions.dart` has been apologising
// for since M4-D: a template authored in the builder travels with the
// project file and does not appear in another job. That sentence stops
// being the whole story when this directory has something in it.
//
// ═══════════════════════════════════════════════════════════════════════
// IT IS A DIRECTORY UNDER THE DATA ROOT, AND THAT SETTLES PORTABLE MODE
// ═══════════════════════════════════════════════════════════════════════
// `resolveDataRoot` already answers "where does out-of-document state
// live" once, at startup, for both the portable and the installed case,
// and every other store takes the answer as a constructor argument. This
// one does the same and inherits both properties for free: a portable
// build keeps its libraries on the stick in `RackPalData\`, and an
// installed build keeps them in app-support.
//
// **THE DEGRADED SESSION IS THE INTERESTING CASE AND IT IS NOT AN ERROR.**
// `DataRootUnusable` means the app started with out-of-document
// persistence disabled: a read-only stick, a locked-down profile. Every
// other store is simply absent then, and so is this one. The palette must
// still work, because `buildPlaceableTemplates` reads the DOCUMENT and
// the seed, neither of which lives here (DR-102 §11.101.3). So a session
// with no library directory has no libraries and full function otherwise,
// and nothing in this file reports that as a failure.
//
// ═══════════════════════════════════════════════════════════════════════
// WHAT THIS FILE DELIBERATELY DOES NOT DO
// ═══════════════════════════════════════════════════════════════════════
// It does not PARSE anything. Listing what is on the shelf and decoding
// what is in a file are two jobs, and `#239` owns the second: the `.rmda`
// codec does not exist yet, so a service that tried to hand back parsed
// libraries would either be blocked on it or would invent a second
// decoder. It answers with paths and the facts `stat` gives, which is
// exactly what `#240`'s import and `#237`'s size cap need to decide
// anything.
import 'package:path/path.dart' as p;
import 'package:rackpal/src/storage/file_store.dart';

/// The directory, under the data root, that holds user libraries.
///
/// **SINGULAR AND FLAT.** DR-015 §11.15.3 makes a library ONE file, so
/// there is nothing for a per-library subdirectory to contain and a
/// nested layout would only make the enumeration recursive. If a library
/// ever grows a sidecar, this is the comment that was wrong.
const String kLibraryDirName = 'libraries';

/// The extension a device library carries (DR-015).
const String kLibraryExtension = '.rmda';

/// One library file on the shelf, before anything has read it.
///
/// **NO `TemplateBody` HERE, AND THAT IS THE SPLIT `#239` OWNS.** Parsing
/// is the codec's job and the codec does not exist. What a caller can do
/// with this is decide whether to read it, which is all `#240` needs and
/// all `#237`'s size cap can act on.
final class LibraryFile {
  const LibraryFile({
    required this.path,
    required this.id,
    required this.sizeBytes,
    required this.modified,
  });

  final String path;

  /// The file's base name without its extension.
  ///
  /// **THE FILE NAME IS THE LIBRARY'S IDENTITY UNTIL `#239` READS ONE.**
  /// A `.rmda` carries a manifest and the manifest will carry a name, so
  /// this is a placeholder for exactly as long as nothing can open the
  /// file. It is spelled as a derived getter rather than stored so that
  /// the day the manifest lands, the compiler shows every reader.
  final String id;

  final int sizeBytes;
  final DateTime modified;

  @override
  String toString() => 'LibraryFile($id, $sizeBytes bytes)';
}

/// Where libraries live for a given data root.
String libraryDirectoryPath(String dataRoot, {p.Context? context}) =>
    (context ?? p.context).join(dataRoot, kLibraryDirName);

/// Lists the libraries on the shelf. Never throws.
///
/// **AN ABSENT DIRECTORY IS AN EMPTY SHELF, NOT A FAILURE.** It does not
/// exist until somebody imports a library, and creating it eagerly at
/// startup would put an empty folder on a user's USB stick to record that
/// they have never used a feature. `#240`'s import creates it on the way
/// past, which is the first moment there is anything to put in it.
///
/// **A DIRECTORY THAT CANNOT BE READ IS ALSO AN EMPTY SHELF**, for
/// `DataRootUnusable`'s reason one level down: the palette must keep
/// working, and it reads the document and the seed rather than this. A
/// session with an unreadable library folder has no libraries and full
/// function otherwise.
///
/// **SORTED BY ID**, because the palette's order must not depend on the
/// filesystem's enumeration order. `buildPlaceableTemplates` already ends
/// its own sort on a unique id for the same reason, and a list whose
/// order changes between launches is the kind of thing nobody reports and
/// everybody notices.
Future<List<LibraryFile>> listLibraries(
  FileStore fs,
  String dataRoot, {
  p.Context? context,
}) async {
  final ctx = context ?? p.context;
  final dir = libraryDirectoryPath(dataRoot, context: ctx);
  final List<String> entries;
  try {
    entries = await fs.listDirectory(dir);
  } on Object catch (_) {
    return const <LibraryFile>[];
  }

  final found = <LibraryFile>[];
  for (final entry in entries) {
    // CASE-INSENSITIVE, because Windows is and a library named `.RMDA`
    // by a spreadsheet-minded person is the same file. The comparison is
    // on the extension only; the id keeps the name's own casing, which
    // is what the user typed and what they will look for.
    if (ctx.extension(entry).toLowerCase() != kLibraryExtension) continue;
    final facts = await _statOrNull(fs, entry);
    if (facts == null) continue;
    found.add(
      LibraryFile(
        path: entry,
        id: ctx.basenameWithoutExtension(entry),
        sizeBytes: facts.size,
        modified: facts.modified,
      ),
    );
  }
  found.sort((a, b) => a.id.compareTo(b.id));
  return found;
}

/// `stat`, with both of its "cannot tell" answers collapsed to null.
///
/// A file that vanished between the listing and the stat is one row
/// absent, not a crash: this is a projection of a directory somebody else
/// can be writing to, and `placeable_templates.dart` takes the same
/// position on a missing snapshot for the same reason.
Future<FileFacts?> _statOrNull(FileStore fs, String path) async {
  try {
    return await fs.stat(path);
  } on Object catch (_) {
    return null;
  }
}
