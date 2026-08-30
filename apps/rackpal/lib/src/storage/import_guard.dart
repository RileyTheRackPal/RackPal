// AC-058/D8's size cap, asked BEFORE the bytes are read (`#237`).
//
// ═══════════════════════════════════════════════════════════════════════
// WHY THIS IS A FUNCTION AND NOT THREE COPIES OF FOUR LINES
// ═══════════════════════════════════════════════════════════════════════
// Three import paths need it: the CSV import, the `.rmdx` import, and the
// `.bak` sibling of a picked project. The first draft of `#237` wrote it
// inline at each, and the third copy is where the rule broke: two of them
// treated a stat that could not answer as "carry on" and the third let
// the failure escape, which turned a network hiccup into a broken
// backup-open on a path that had survived one for a milestone.
//
// ═══════════════════════════════════════════════════════════════════════
// A STAT THAT CANNOT ANSWER IS NOT A REFUSAL
// ═══════════════════════════════════════════════════════════════════════
// `null` (no such file) and a THROWN failure (an AV scanner holding the
// handle, a share that blinked) are the same answer here: **cannot
// tell**. Neither is evidence that the file is too big, and refusing on
// either would report a vanished or briefly-locked file as an enormous
// one, which is a false explanation the caller already has a better
// sentence for.
//
// That is G4's shape on a precondition: the unknown case does not get
// folded into either verdict. The read that follows then fails, or
// succeeds, on its own terms, and the in-memory cap in `checkJsonLimits`
// is still there behind it for every JSON path.
import 'package:rackpal/src/storage/file_store.dart';
import 'package:rackpal_core/rackpal_core.dart';

/// `Err(DocumentTooLargeError)` when [path] is measurably over the cap.
///
/// `Ok` when it is within the cap **or when its size cannot be
/// established**. See the header: those are different facts and only one
/// of them is a reason to refuse.
Future<Outcome<void>> checkImportedFileSize(
  FileStore fs,
  String path, {
  int maxBytes = kMaxDocumentBytes,
}) async {
  final FileFacts? facts;
  try {
    facts = await fs.stat(path);
    // `on Object`, not `on Exception`: `FileStore.stat` declares no typed
    // failure, so this catches the interface's whole contract rather than
    // one implementation's exception class. The same reasoning
    // `csv_import_actions.dart` already applies to `readBytes`.
  } on Object catch (_) {
    return const Ok<void>(null);
  }
  if (facts == null) return const Ok<void>(null);
  return checkImportSize(facts.size, limit: maxBytes);
}
