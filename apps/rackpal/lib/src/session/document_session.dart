// The one observable the window title, the File menu, the close prompt,
// the autosave timer and the recovery sidecar all read.
//
// ==================================================================
// WHY THE APP OWNS THE `DocumentController` NOW
// ==================================================================
// Until this stage the rack canvas built its own controller over a demo
// seed, and that was correct while the document existed only inside one
// tab. Save, autosave, the dirty marker and close interception are
// properties of THE DOCUMENT, not of the Rack tab — the Schematic and
// Schedule tabs share it, and closing the window while dirty must prompt
// whichever tab is on top. So the controller moved up and this class is
// where it lives.
//
// ==================================================================
// DIRTY IS `stateId != savedStateId`, NEVER DOCUMENT EQUALITY (CR-094)
// ==================================================================
// Document equality is O(document) per keystroke and gets subtly wrong
// the moment a float survives into the model. This class holds no dirty
// bit of its own: `isDirty` forwards to the controller, which is the only
// thing that moves either id. The one job this class has around dirtiness
// is REBROADCASTING — `DocumentController.changes` is a pure-Dart
// `SimpleNotifier` (core must not import Flutter), and widgets need a
// `Listenable`. This is the adapter, and it is the only place the two
// notification systems meet.
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:rackpal/src/storage/document_store.dart';
import 'package:rackpal/src/storage/recovery_store.dart'
    show kRecoverySlotSeparator;
import 'package:rackpal/src/storage/save_paths.dart';
import 'package:rackpal_core/rackpal_core.dart';

/// The app's own name, used when a document has none.
const String kUntitledDocumentName = 'Untitled';

/// `ProjectInfo.projectName`'s own default.
///
/// TREATED AS "NO NAME", not as a name. Core seeds every new document
/// with it so the field is never null; a window titled "Untitled Project"
/// for a file the user saved as `Smith.rackpal` would be strictly worse
/// than one titled "Smith". `document_session_test.dart` asserts this
/// constant still matches core's default, so a change there fails a test
/// rather than silently retitling every window.
const String kDefaultProjectName = 'Untitled Project';

/// What the OS window is called.
const String kAppName = 'RackPal';

/// A `savedStateId` no real document state can ever carry. See
/// [DocumentSession.markUnsavedRecovery].
const int kNeverSavedStateId = -1;

/// The key a recovery snapshot pair is filed under.
///
/// ==================================================================
/// WHY THE SESSION ID IS IN HERE, AND WHAT IT COST TO LEAVE IT OUT
/// ==================================================================
/// `RecoveryStore` (storage/recovery_store.dart) keys a pair on ONE
/// opaque string, which becomes the
/// file stem of `<key>.rackpal` and `<key>.json`. Handing it the document
/// id alone was a single mistake that produced three separate ways to lose
/// work, all of them silent:
///
///  1. A crash leaves a snapshot for `Smith` with twelve unsaved changes.
///     The user is offered it at launch and picks "Keep for later" — which
///     is documented as "it WILL be offered again next launch". They then
///     open `Smith.rackpal` to look at it and quit. `cleanShutdown`
///     deletes the snapshot for the id of the document that is open, which
///     is the SAME id, so the twelve changes are gone. No prompt, no dirty
///     flag, no report.
///  2. Same setup, but the user makes one edit first. The 30 s autosave
///     writes a snapshot for the same id, over the survivor. The crashed
///     session's unsaved work is replaced by the freshly-loaded saved
///     version — by the very mechanism that existed to protect it.
///  3. Two instances of the app on one file share the path, so each one's
///     autosave overwrites the other's safety net.
///
/// A snapshot does not belong to a DOCUMENT. It belongs to a SESSION's
/// work on a document, and the two are not the same thing: a survivor and
/// a live snapshot can describe the same document at two different states,
/// and both have to exist. Keying on the pair is not a guard bolted onto
/// each symptom — it makes all three unreachable, because the paths are
/// simply different files.
///
/// `RecoveryStore.sessionId` is minted per PROCESS, so a survivor from a
/// crashed run can never collide with anything a later run writes.
///
/// [kRecoverySlotSeparator] is declared in `storage/recovery_store.dart`
/// rather than here, because that store has to recognise its OWN slots:
/// the sidecar's `owner` field is rewritable and a concurrent launch used
/// to rewrite it on a live pair, after which the instance that wrote the
/// pair could never retire it. A slot is the file name and nobody can
/// rewrite it.
String recoverySlotFor({
  required String documentId,
  required String sessionId,
}) => '$documentId$kRecoverySlotSeparator$sessionId';

/// The display name for a document: its project name if it has one, else
/// the file stem, else "Untitled".
///
/// PURE, and used by the window title, the recents entry, the close
/// prompt and the recovery sidecar — one function so those four can never
/// disagree about what the user's project is called.
String displayNameFor({
  required String? projectName,
  required String? filePath,
  required p.Context context,
}) {
  final trimmed = projectName?.trim() ?? '';
  if (trimmed.isNotEmpty && trimmed != kDefaultProjectName) return trimmed;
  if (filePath != null && filePath.isNotEmpty) {
    final stem = context.basenameWithoutExtension(filePath);
    if (stem.isNotEmpty) return stem;
  }
  return kUntitledDocumentName;
}

/// The OS window title.
///
/// PURE, so the `*` rule is unit-tested without a window manager.
///
/// `*` RATHER THAN `●` — it is the Windows convention, and unlike a
/// bullet it is pronounceable, so a screen reader announces the dirty
/// state instead of skipping it or reading "black circle".
String windowTitleFor({
  required String displayName,
  required bool isDirty,
  required bool readOnly,
}) {
  final marker = isDirty ? '*' : '';
  final suffix = readOnly ? ' (read-only)' : '';
  return '$marker$displayName$suffix — $kAppName';
}

/// The suggested name when a read-only document is saved with Ctrl+S.
String copySuggestionFor(String displayName) =>
    '$displayName (copy)$kDocumentExtension';

/// The live document and everything the shell needs to know about it.
final class DocumentSession extends ChangeNotifier {
  DocumentSession({
    required DocumentController controller,
    required this.context,
    String? filePath,
    bool openReadOnly = false,
    FileBaseline? baseline,
    bool recoveryEnabled = true,
  }) : // THE FOUR IGNORES BELOW ARE ONE DECISION, NOT FOUR. Every one of
       // these fields is PRIVATE because nothing outside this class may
       // reassign it — `adopt`, `recordSave` and `setStatus` are the only
       // ways they move, and each of those has an invariant to keep.
       // `prefer_initializing_formals` would have them written as
       // `this._controller`, which makes the PARAMETER name private too:
       // `DocumentSession(_controller: c)` is not something a caller can
       // write. A private field with a public parameter is the correct
       // shape here and the lint has no way to know that.
       // ignore: prefer_initializing_formals
       _controller = controller,
       // See above.
       // ignore: prefer_initializing_formals
       _filePath = filePath,
       // See above.
       // ignore: prefer_initializing_formals
       _openReadOnly = openReadOnly,
       _baseline = baseline ?? FileBaseline.absent,
       // See above.
       // ignore: prefer_initializing_formals
       _recoveryEnabled = recoveryEnabled {
    _controller.changes.addListener(_onDocumentChanged);
  }

  final p.Context context;

  DocumentController _controller;
  String? _filePath;
  bool _openReadOnly;
  FileBaseline _baseline;
  bool _recoveryEnabled;
  String? _status;

  /// THE one mutation entry point for the current document.
  DocumentController get controller => _controller;

  RackDocument get document => _controller.doc;

  /// The document's own uuid — the stem of its recovery snapshot, and the
  /// reason two starter copies must never share one.
  String get documentId => document.id.v;

  /// Where the document lives, or null when it has never been saved.
  /// Null is what routes Ctrl+S to Save As.
  String? get filePath => _filePath;

  /// True when the file's `schemaVersion` was newer than this build's but
  /// its `minReaderVersion` was still satisfied.
  ///
  /// The document is FULLY EDITABLE and still autosaves to a recovery
  /// snapshot. The user is blocked from OVERWRITING, not from working.
  bool get openReadOnly => _openReadOnly;

  /// The (size, modified) the next save's external-change check compares
  /// against.
  FileBaseline get baseline => _baseline;

  /// False when the app cannot write to its data folder. Autosave never
  /// starts, recents and prefs are read-only-empty, and a persistent
  /// warning says so — documents still open and save normally, because
  /// those write to the user's chosen directory and not to the data root.
  bool get recoveryEnabled => _recoveryEnabled;

  /// The transient status line: "Saved.", "Saved. The backup copy could
  /// not be updated.", "Recovered from 14:32…".
  String? get status => _status;

  /// CR-094. Forwarded, never cached — a second copy of this bit is a
  /// second thing that can be wrong.
  bool get isDirty => _controller.isDirty;

  /// How many edits stand between disk and screen, or null when that is
  /// genuinely unknown. Null means the UI OMITS the count (G4).
  int? get editsSinceSave => _controller.editsSinceSave;

  /// True when Ctrl+S must route to Save As: no path yet, or a file this
  /// build may not overwrite.
  bool get requiresSaveAs => _filePath == null || _openReadOnly;

  String get displayName => displayNameFor(
    projectName: document.info.projectName,
    filePath: _filePath,
    context: context,
  );

  String get windowTitle => windowTitleFor(
    displayName: displayName,
    isDirty: isDirty,
    readOnly: _openReadOnly,
  );

  /// Replaces the current document wholesale — New, Open, and accepting a
  /// recovery snapshot all land here.
  ///
  /// v1 IS SINGLE-DOCUMENT, SINGLE-WINDOW (CR-119): no second window is
  /// created and no tab is added. The shell keys the canvas on the
  /// controller's identity, so this produces a fresh canvas `State`
  /// rather than one holding the previous document's derived caches.
  void adopt({
    required DocumentController controller,
    required String? filePath,
    required bool openReadOnly,
    required FileBaseline baseline,
    String? status,
  }) {
    _controller.changes.removeListener(_onDocumentChanged);
    _controller = controller;
    _controller.changes.addListener(_onDocumentChanged);
    _filePath = filePath;
    _openReadOnly = openReadOnly;
    _baseline = baseline;
    _status = status;
    notifyListeners();
  }

  /// Records a successful write. The controller's `markSavedAt` has
  /// ALREADY run inside `DocumentStore.save` with the state id that was
  /// actually serialized — this only records where it went.
  ///
  /// `openReadOnly` is cleared here on purpose: the bytes now on disk
  /// were written by THIS build at THIS schema version, so the file is no
  /// longer one this build only partly understands.
  void recordSave(SavedFile saved, {String? status}) {
    _filePath = saved.paths.target;
    _baseline = saved.baseline;
    _openReadOnly = false;
    _status = status;
    notifyListeners();
  }

  /// Marks the document dirty against a state it was never saved at.
  ///
  /// Used by recovery acceptance: a recovered snapshot has NOT been
  /// written to the user's file, so it must read dirty however clean a
  /// freshly-decoded controller thinks it is, or the close prompt would
  /// let it go silently — which is the exact loss the snapshot existed to
  /// prevent.
  ///
  /// [kNeverSavedStateId] IS SAFE AS A SENTINEL because `doc.stateId` is
  /// in-memory-only, starts at 0 for every freshly-decoded document, and
  /// is allocated strictly upward from there. No real state can ever
  /// carry it, so `isDirty` cannot be accidentally satisfied.
  ///
  /// `editsSinceSave` becomes NULL after this, and that is correct rather
  /// than a shortfall: a recovered document has no undo stack behind it,
  /// so the number of unsaved edits is genuinely unknown and the close
  /// prompt must omit it (G4). The recovery PROMPT still shows the count,
  /// because the sidecar recorded it at snapshot time and it was accurate
  /// then.
  void markUnsavedRecovery() {
    _controller.markSavedAt(kNeverSavedStateId);
    notifyListeners();
  }

  void setStatus(String? status) {
    if (_status == status) return;
    _status = status;
    notifyListeners();
  }

  /// Turns out-of-document persistence off for the session. See
  /// [recoveryEnabled].
  void disableRecovery() {
    if (!_recoveryEnabled) return;
    _recoveryEnabled = false;
    notifyListeners();
  }

  void _onDocumentChanged() => notifyListeners();

  @override
  void dispose() {
    _controller.changes.removeListener(_onDocumentChanged);
    super.dispose();
  }
}
