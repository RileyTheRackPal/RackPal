// The composition root. Everything the shell needs, wired once.
//
// ==================================================================
// STARTUP ORDER, AND THE ONE THING THAT MUST NOT BE ON IT
// ==================================================================
//   1. resolve the data root                 (local, bounded)
//   2. load prefs.json                       (local, small)
//   3. restore the window geometry, then show the window
//   4. load recents.json — WITHOUT STATTING ANY ENTRY
//   5. scan the recovery directory           (local, a few small files)
//   6. first frame
//
// STEP 4 IS THE ONE WITH A MEASUREMENT BEHIND IT. `exists` on an
// unreachable UNC path took 1261 ms on the development machine and
// returned false without throwing. Ten dead entries is 12.6 seconds
// against a 1.2 s cold-start budget, so nothing here probes a recent
// file. The probe runs when the menu is opened, bounded, and removes
// nothing.
//
// Step 5 is safe to await, unlike step 4, because the data root is always
// local — app support, or the `data/` directory beside the executable.
// There is no network path in it to hang on.
//
// ==================================================================
// THE DEGRADED SESSION IS A FIRST-CLASS OUTCOME, NOT AN ERROR PATH
// ==================================================================
// A read-only USB stick in portable mode and a locked-down corporate
// profile produce the same thing: a `DataRootUnusable`. The app STARTS.
// Autosave never begins, recents and prefs are empty and read-only, and a
// persistent dismissible warning says so — because "never silently do
// nothing" applies hardest to the feature whose entire job is protecting
// unsaved work. Documents still open and save normally, since those write
// to the user's chosen directory and not to the data root.
//
// ==================================================================
// AND IT IS A LIVE VALUE, NOT A `final String?` READ ONCE
// ==================================================================
// The warning used to be computed once, during this function, from the
// data root's state at startup. Persistence does not only fail at
// startup: flip the write-protect switch on the stick, fill the volume,
// have an admin policy revoke write access, delete the folder — and every
// recovery snapshot from then on fails while the status bar shows
// nothing, because the one thing that could have noticed
// (`AutosaveOutcome.failed`) had no consumer anywhere in `lib/`. So the
// warning is a `ValueListenable` the shell rebuilds on, the autosave
// scheduler reports every outcome into it, and a `written` after a
// `failed` takes it back down again.
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:rackpal/src/session/autosave_scheduler.dart';
import 'package:rackpal/src/session/device_template_io_actions.dart';
import 'package:rackpal/src/session/document_session.dart';
import 'package:rackpal/src/session/export_controller.dart';
import 'package:rackpal/src/session/file_error_presenter.dart';
import 'package:rackpal/src/session/file_picker.dart';
import 'package:rackpal/src/session/library_io_actions.dart';
import 'package:rackpal/src/session/session_controller.dart';
import 'package:rackpal/src/session/session_prompts.dart';
import 'package:rackpal/src/session/starter_projects.dart';
import 'package:rackpal/src/session/timers.dart';
import 'package:rackpal/src/session/window_chrome.dart';
import 'package:rackpal/src/storage/atomic_writer.dart';
import 'package:rackpal/src/storage/data_root.dart';
import 'package:rackpal/src/storage/document_store.dart';
import 'package:rackpal/src/storage/file_store.dart';
import 'package:rackpal/src/storage/prefs_store.dart';
import 'package:rackpal/src/storage/recents_store.dart';
import 'package:rackpal/src/storage/recovery_store.dart';
import 'package:rackpal/src/storage/serialization.dart';
import 'package:rackpal/src/storage/snapshot_store.dart';
import 'package:rackpal_core/rackpal_core.dart';

/// This build's version, recorded in recovery sidecars and in new
/// documents.
///
/// ═══════════════════════════════════════════════════════════════════════
/// IT IS A SECOND TRANSCRIPTION OF `pubspec.yaml`, AND THAT IS GATED
/// ═══════════════════════════════════════════════════════════════════════
/// Dart cannot read its own `pubspec.yaml` at compile time, so a shipped
/// constant is the only way this string reaches a `RackDocument`. Two
/// copies of one fact is exactly the drift this project gates elsewhere
/// (`registry parity`, `palette parity`), and the failure here is quiet
/// and durable: every document and every recovery sidecar written by a
/// release would carry the PREVIOUS version number, permanently, in a
/// file a user keeps. `version_parity_test.dart` compares this against
/// every `pubspec.yaml` in the workspace.
///
/// THE SCHEME (docs/14 §14.0): `0.EPIC.TASK`. The leading `0` holds until
/// the first public release, the middle number is the milestone epic under
/// development, and the last increments per major task completed in it.
const String kAppVersion = '0.4.89';

/// Everything the shell is handed.
final class AppServices {
  AppServices({
    required this.session,
    required this.controller,
    required this.export,
    required this.templateIo,
    required this.libraryIo,
    required this.chrome,
    required this.autosave,
    required this.titleWriter,
    required this.prefs,
    required this.startupWarning,
    this.prefsStore,
  }) : degradedWarning = ValueNotifier<String?>(startupWarning);

  final DocumentSession session;
  final SessionController controller;

  /// `File ▸ Export PDF…`.
  ///
  /// A SIBLING OF [controller], NOT A METHOD ON IT. The two share the
  /// picker, the prompts and the writer, but nothing else: an export never
  /// touches the dirty flag, the recovery snapshot, the recents list or the
  /// baseline, and folding it into `SessionController` would put a
  /// deliverable's failure paths next to the document's own. The seam is
  /// also what lets the export be tested without a `DocumentStore`.
  final ExportController export;

  /// `File ▸ Export device template…` and `File ▸ Import device
  /// template…` (DR-101 §11.100).
  ///
  /// A SECOND SIBLING, for [export]'s reason: it shares the picker, the
  /// prompts and the writer and nothing else. Its own header says why an
  /// import touching the document is not an exception to that.
  final DeviceTemplateIo templateIo;

  /// `File ▸ Export device library…` and `File ▸ Import device library…`
  /// (`#240`).
  ///
  /// A third sibling, for [export]'s reason. Its `dataRoot` is null in
  /// the degraded session, which is the whole of that handling: import
  /// has nowhere to put a library and says so, while EXPORT is
  /// unaffected because it writes to the user's chosen directory.
  final LibraryIo libraryIo;

  final WindowChrome chrome;
  final AutosaveScheduler autosave;

  /// Null in the degraded session — there is nowhere to write geometry.
  ///
  /// Assigned after construction only because it needs the finished
  /// `AppServices` for nothing at all now — it is built here purely so the
  /// degraded branch stays one `if` rather than a nullable constructor
  /// argument threaded through every test.
  WindowGeometryRecorder? geometry;

  final WindowTitleWriter titleWriter;

  /// The prefs AS LOADED AT STARTUP, and nothing else.
  ///
  /// ==================================================================
  /// FINAL, AND THE `final` IS THE FIX
  /// ==================================================================
  /// This used to be mutable and was documented as "the live prefs, held
  /// so a geometry write does not clobber `lastSaveDirectory`". It had
  /// ZERO writers anywhere in `lib/`: the only assignment in the whole
  /// repository was one line in `window_chrome_test.dart`, which is why
  /// the suite was green while production reverted `lastSaveDirectory` to
  /// its startup value 500 ms after every window move.
  ///
  /// The live value now lives on [PrefsStore.current], where it cannot
  /// diverge from the file. This one is read exactly once, by
  /// [restoreWindowGeometry] in `main()`, before the window is shown.
  final AppPrefs prefs;

  /// The LIVE preferences, or null in the degraded session.
  ///
  /// NULL IS A REAL STATE AND NOT A TEST HOOK: a read-only USB stick or a
  /// locked-down profile produces a `DataRootUnusable`, there is no
  /// `prefs.json` to write, and the shell's answer is then to show
  /// AC-048's coach mark once per SESSION rather than once per user. That
  /// is the least-bad reading of DR-012.4 when the store it names does
  /// not exist — a session-scoped dismissal is not a nag, and refusing to
  /// teach the domain filter at all because a folder is read-only would
  /// be worse.
  ///
  /// It is the [PrefsStore] rather than an `AppPrefs` snapshot because
  /// `prefs.json` has several independent writers doing load-modify-write
  /// and only the store holds a cache that cannot go stale — the defect
  /// [prefs]'s own doc comment records.
  final PrefsStore? prefsStore;

  /// The persistent status-bar warning, or null when persistence is
  /// healthy RIGHT NOW.
  ///
  /// Set at startup for a `DataRootUnusable`, and set and cleared during
  /// the session by [reportAutosaveOutcome]. See the file header.
  final ValueNotifier<String?> degradedWarning;

  /// Folds an autosave outcome into [degradedWarning].
  ///
  /// A STARTUP WARNING IS NEVER OVERWRITTEN. A degraded session's autosave
  /// answers `disabled` and never fails, so this cannot fire there — but
  /// if it ever did, replacing "RackPal cannot write to its data folder"
  /// with "autosave has stopped working" would be a downgrade in
  /// information, and this reports the more specific fact.
  void reportAutosaveOutcome(AutosaveOutcome outcome) {
    if (startupWarning != null) return;
    switch (outcome) {
      case AutosaveOutcome.failed:
        degradedWarning.value = kAutosaveStoppedWarning;
      case AutosaveOutcome.written:
        // It came back. A stale warning about a folder that is writable
        // again is its own kind of lie, and one that teaches the user to
        // ignore the banner.
        if (degradedWarning.value == kAutosaveStoppedWarning) {
          degradedWarning.value = null;
        }
      case AutosaveOutcome.notDirty:
      case AutosaveOutcome.debounced:
      case AutosaveOutcome.busy:
      case AutosaveOutcome.disabled:
        // None of these is evidence either way: nothing was attempted.
        break;
    }
  }

  /// The warning the data root produced at startup, or null. Held so a
  /// mid-session autosave failure cannot overwrite it.
  final String? startupWarning;
}

/// Builds every service from a resolved data root.
///
/// PURE OF ENVIRONMENT LOOKUPS: the [FileStore], the [DataRoot], the
/// clock, the timer factories and the serializers all arrive as
/// arguments. That is what lets the whole startup sequence — including
/// the degraded branch — run against `FakeFileStore` with no disk, and
/// what stops a second `getApplicationSupportDirectory()` call site from
/// appearing here.
Future<AppServices> buildAppServices({
  required FileStore fs,
  required DataRoot dataRoot,
  required RackDocument initialDocument,
  required WindowChrome chrome,
  required SessionPrompts prompts,

  /// REQUIRED, not defaulted.
  ///
  /// It used to default to `true` and `main.dart` never passed it, so the
  /// Windows errno table and `kWindowsMaxPath` were applied on macOS and
  /// Linux: a disk-full save (ENOSPC 28) fell through the Windows switch
  /// to `StorageFailure.unknown` and reached the user as "something went
  /// wrong that RackPal does not have a specific explanation for"
  /// instead of "the disk is full", EACCES did the same, and any path
  /// over 259 characters was refused outright on filesystems whose real
  /// limit is 4096 bytes. A default is exactly how that stays wrong: it
  /// makes the correct wiring optional. Now the composition root has to
  /// say which platform it is on, and there is no second answer.
  required bool isWindows,
  FilePicker picker = const Win32FilePicker(),
  Clock clock = const SystemClock(),
  Serializer serializer = isolateSerializer,
  Deserializer deserializer = isolateDeserializer,
  TimerFactory timerFactory = productionTimerFactory,
  PeriodicTimerFactory periodicTimerFactory = productionPeriodicTimerFactory,
  Duration autosaveInterval = kAutosaveInterval,
  StarterAssetLoader starterLoader = loadStarterAssetFromBundle,
  ExportFontLoader exportFontLoader = loadExportFontsFromBundle,
  p.Context? context,
  String? recoverySessionId,
  Duration pathProbeTimeout = kSessionPathProbeTimeout,
  String appVersion = kAppVersion,
}) async {
  final ctx = context ?? p.context;
  final queue = SaveQueue();
  final writer = AtomicWriter(
    fs: fs,
    queue: queue,
    context: ctx,
    isWindows: isWindows,
  );

  // The data root is resolved BEFORE this function; what it decides here
  // is only whether the four out-of-document stores exist at all.
  final ready = dataRoot is DataRootReady ? dataRoot : null;
  final unusable = dataRoot is DataRootUnusable ? dataRoot : null;

  // `RecoveryStore` is built even in the degraded session, pointed at a
  // root that does not work, because `SessionController` calls
  // `recovery.delete` on every clean shutdown and a null there would mean
  // a null check on every one of those call sites.
  //
  // IT IS BUILT DISABLED, AND THAT IS NOT DECORATION. "Its writes fail
  // harmlessly" was the old note here and it was not true of all of them:
  // `beginSession` below ran unconditionally and CREATED
  // `<dataRoot>/sessions/` and a `.lease` file. In the branch where the
  // support directory could not even be NAMED, `attemptedPath` is `''`,
  // so that path was the relative string `sessions` and the file landed in
  // the process's current working directory — for an Explorer-launched
  // build, the install or portable folder. The one code path whose whole
  // premise is "we cannot write anywhere safe" was the one writing outside
  // the data root. See `RecoveryStore.enabled`.
  final recovery = RecoveryStore(
    fs: fs,
    writer: writer,
    dataRoot: ready?.path ?? unusable?.attemptedPath ?? '',
    context: ctx,
    enabled: ready != null,
    // Identifies THIS PROCESS, and is half of every recovery slot this
    // run writes. Injected only so a test can name the slot it is
    // asserting on; production mints a fresh uuid per launch, which is
    // what makes a survivor from a crashed run unable to collide with
    // anything this run does. See `recoverySlotFor`.
    sessionId: recoverySessionId,
  );

  // ANNOUNCE THIS PROCESS BEFORE ANYTHING SCANS. The lease is what lets a
  // CONCURRENT launch tell this session's live snapshot from a crashed
  // session's leftovers — without it, that launch claims this one's pair
  // and offers the user the chance to discard work being edited in
  // another window right now.
  //
  // CALLED UNCONDITIONALLY, DECIDED INSIDE. A degraded session has no
  // snapshot for anyone to mistake, so it takes no lease and creates no
  // directory — `RecoveryStore.enabled` is false and `beginSession`
  // returns after logging. The decision lives in the store rather than
  // behind an `if` here so there is one place that knows, and so this
  // composition root cannot drift from it.
  await recovery.beginSession();

  final stores = ready == null
      ? null
      : OutOfDocumentStores(
          recents: RecentsStore(
            fs: fs,
            writer: writer,
            dataRoot: ready.path,
            context: ctx,
          ),
          prefs: PrefsStore(
            fs: fs,
            writer: writer,
            dataRoot: ready.path,
            context: ctx,
          ),
          snapshots: SnapshotStore(
            fs: fs,
            writer: writer,
            dataRoot: ready.path,
            context: ctx,
          ),
          dataRootPath: ready.path,
          portable: ready.portable,
        );

  final session = DocumentSession(
    controller: DocumentController(initialDocument, clock: clock),
    context: ctx,
    recoveryEnabled: stores != null,
  );

  final store = DocumentStore(
    fs: fs,
    writer: writer,
    recovery: recovery,
    serializer: serializer,
    deserializer: deserializer,
    context: ctx,
    isWindows: isWindows,
  );

  // Assigned below, once `services` exists. The scheduler reports every
  // outcome into the live warning, and the warning lives on `AppServices`
  // — so one of the two has to be wired after the other is built.
  late final AppServices services;

  final autosave = AutosaveScheduler(
    session: session,
    store: store,
    recovery: recovery,
    appVersion: appVersion,
    clock: clock,
    periodicTimerFactory: periodicTimerFactory,
    interval: autosaveInterval,
    isQueueBusy: () => queue.busy,
    onOutcome: (outcome) => services.reportAutosaveOutcome(outcome),
  );

  final controller = SessionController(
    session: session,
    store: store,
    recovery: recovery,
    picker: picker,
    prompts: prompts,
    autosave: autosave,
    fs: fs,
    appVersion: appVersion,
    stores: stores,
    clock: clock,
    starterLoader: starterLoader,
    pathProbeTimeout: pathProbeTimeout,
    context: ctx,
  );

  final prefs = stores == null ? const AppPrefs() : await stores.prefs.load();
  controller.seedLastSaveDirectory(prefs.lastSaveDirectory);

  services = AppServices(
    session: session,
    controller: controller,
    export: ExportController(
      session: session,
      picker: picker,
      prompts: prompts,
      // THE SAME `AtomicWriter`, and therefore the same `SaveQueue`. An
      // export that interleaved with an autosave over the same directory
      // would be the interleaving the queue exists to make impossible.
      writer: writer,
      fontLoader: exportFontLoader,
      clock: clock,
      // The PDF dialog opens where the last document save did (§8.3's
      // "the same MRU behaviour as document Save As, for free").
      initialDirectory: controller.exportInitialDirectory,
      context: ctx,
    ),
    libraryIo: LibraryIo(
      session: session,
      picker: picker,
      writer: writer,
      fs: fs,
      prompts: prompts,
      // Null when the root is unusable, which is exactly the degraded
      // session: there is nowhere to keep a library.
      dataRoot: ready?.path,
      initialDirectory: controller.exportInitialDirectory,
      context: ctx,
    ),
    templateIo: DeviceTemplateIo(
      session: session,
      // THE SESSION'S OWN `DocumentController`, so an import lands on the
      // same undo stack as every other edit and `Ctrl+Z` puts it back.
      controller: session.controller,
      picker: picker,
      writer: writer,
      fs: fs,
      prompts: prompts,
      clock: clock,
      // Where the last document save went, for the PDF export's reason.
      initialDirectory: controller.exportInitialDirectory,
      context: ctx,
    ),
    chrome: chrome,
    autosave: autosave,
    titleWriter: WindowTitleWriter(chrome),
    prefs: prefs,
    prefsStore: stores?.prefs,
    startupWarning: unusable == null
        ? null
        : describeDegradedPersistence(portable: unusable.portable),
  );

  if (stores != null) {
    services.geometry = WindowGeometryRecorder(
      chrome: chrome,
      // The recorder reads `stores.prefs.current` for itself. It used to
      // be handed a `readPrefs` closure over `services.prefs`, a field
      // nothing in `lib/` ever re-assigned — see [AppServices.prefs].
      prefs: stores.prefs,
      timerFactory: timerFactory,
    );
  }
  return services;
}

/// Applies the remembered window geometry, or centres when it no longer
/// lands anywhere reachable.
///
/// THE `null` BRANCH IS THE POINT. A position saved on a monitor that has
/// since been unplugged would otherwise reopen the window at coordinates
/// the user cannot reach, and the only remedy a non-technical user has is
/// to delete a file they do not know exists.
Future<void> restoreWindowGeometry({
  required WindowChrome chrome,
  required AppPrefs prefs,
}) async {
  await chrome.setMinimumSize(kMinWindowWidth, kMinWindowHeight);

  final saved = prefs.window;
  if (saved == null) {
    await chrome.center();
    if (prefs.maximized) await chrome.maximize();
    return;
  }

  final displays = await chrome.displays();
  final validated = validateRestoredBounds(saved, displays);
  if (validated == null) {
    await chrome.center();
  } else {
    await chrome.setBounds(validated);
  }
  // The restore-down rect is applied FIRST and the maximise second, so
  // unmaximising puts the window back where the user had it rather than
  // at a default.
  if (prefs.maximized) await chrome.maximize();
}
