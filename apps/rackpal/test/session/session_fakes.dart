// The session layer's test doubles, and one helper that wires a whole
// `AppServices` over them.
//
// THE POINT OF ALL OF THIS is that the REAL shell — the real
// `SessionController`, the real `AppShell`, the real dialogs, the real
// `Shortcuts`/`Actions` — runs in a widget test against a FAKE disk, a
// FAKE window and a FAKE file dialog. Nothing here is a stand-in for
// production code; every fake replaces something the test process
// genuinely cannot have (a filesystem it may write to, a native modal, a
// desktop window, wall-clock time).
//
// NOTHING SLEEPS. Both timer factories are manual and are advanced by
// hand, so "autosave fires after 30 s" is one function call rather than
// thirty seconds.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart' show GlobalKey, NavigatorState;
import 'package:path/path.dart' as p;
import 'package:rackpal/main.dart';
import 'package:rackpal/src/session/app_services.dart';
import 'package:rackpal/src/session/app_shell.dart';
import 'package:rackpal/src/session/document_session.dart';
import 'package:rackpal/src/session/export_controller.dart';
import 'package:rackpal/src/session/file_picker.dart';
import 'package:rackpal/src/session/session_controller.dart';
import 'package:rackpal/src/session/session_prompts.dart';
import 'package:rackpal/src/session/starter_projects.dart';
import 'package:rackpal/src/session/timers.dart';
import 'package:rackpal/src/session/window_chrome.dart';
import 'package:rackpal/src/storage/data_root.dart';
import 'package:rackpal/src/storage/prefs_store.dart';
import 'package:rackpal/src/storage/serialization.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

import '../storage/fake_file_store.dart';

/// The data root every fake session writes under.
const String kTestDataRoot = r'C:\data';

/// The folder the fake save dialog hands paths back in.
const String kTestJobsDir = r'C:\jobs';

/// The recovery session id every fake session runs under.
///
/// FIXED, so a test can name the slot it is asserting on:
/// `recovery/<docId>~sess-a.rmpj`. Production mints a fresh uuid per
/// launch — see `recoverySlotFor`.
const String kTestSessionId = 'sess-a';

/// `<kTestDataRoot>/recovery`.
const String kTestRecoveryDir = r'C:\data\recovery';

/// The recovery slot [kTestSessionId] files [documentId] under.
String testSlot(String documentId) =>
    recoverySlotFor(documentId: documentId, sessionId: kTestSessionId);

/// The snapshot path for a document in the default fake session.
String testSnapshotPath(String documentId, {String? sessionId}) =>
    '$kTestRecoveryDir\\'
    '${recoverySlotFor(
      documentId: documentId,
      sessionId: sessionId ?? kTestSessionId,
    )}.rmpj';

/// The sidecar path for a document in the default fake session.
String testSidecarPath(String documentId, {String? sessionId}) =>
    '$kTestRecoveryDir\\'
    '${recoverySlotFor(
      documentId: documentId,
      sessionId: sessionId ?? kTestSessionId,
    )}.json';

/// Reads a starter project from the package's own `assets/` directory.
///
/// THE REAL FILES, not a stub. `flutter test` runs with `apps/rackpal`
/// as the working directory, so the checked-in bytes are right there —
/// and a session test that opens a starter should open the one that
/// ships, not a fixture that agrees with it today.
///
/// `dart:io` rather than `rootBundle` only because `FakeFileStore` is
/// what the rest of the session is wired to; `starter_assets_test.dart`
/// exercises the production `rootBundle` loader for real.
///
/// SYNCHRONOUS READ, DELIBERATELY. `testWidgets` runs its body inside
/// `FakeAsync`, where a real asynchronous file read never completes — the
/// completion arrives on the real event loop, which the fake clock does
/// not pump. `readAsBytesSync` inside an `async` function completes on a
/// MICROTASK, which `pumpAndSettle` does drain. Without this the four
/// "picking a starter opens it" tests hang and then fail with the start
/// card still on screen.
Future<Uint8List> loadStarterAssetFromDisk(String assetPath) async =>
    File(assetPath).readAsBytesSync();

/// The [ExportFontLoader] for tests: the REAL bundled TTF, off disk.
///
/// The real bytes rather than a stub, because every measurement the
/// exporter makes goes through them (CR-081) — a fake font would make
/// every layout assertion about a font that does not ship.
Future<Map<FontRef, Uint8List>> loadExportFontsFromDisk() async =>
    <FontRef, Uint8List>{
      kExportFont: File(kExportFontAsset).readAsBytesSync(),
    };

// --- Timers ------------------------------------------------------------

/// A [CancellableTimer] that fires only when a test says so.
final class ManualTimer implements CancellableTimer {
  ManualTimer(this.duration, this.callback, this._owner);

  final Duration duration;
  final void Function() callback;
  final ManualTimers _owner;
  bool cancelled = false;

  @override
  void cancel() {
    cancelled = true;
    _owner._timers.remove(this);
  }
}

/// Collects every timer scheduled through it, so a test can fire them.
final class ManualTimers {
  final List<ManualTimer> _timers = [];

  /// Live timers, in creation order.
  List<ManualTimer> get pending => List.unmodifiable(_timers);

  CancellableTimer oneShot(Duration duration, void Function() callback) {
    final timer = ManualTimer(duration, callback, this);
    _timers.add(timer);
    return timer;
  }

  /// Periodic timers stay scheduled after firing, matching
  /// `Timer.periodic`.
  CancellableTimer periodic(Duration duration, void Function() callback) {
    final timer = ManualTimer(duration, callback, this);
    _timers.add(timer);
    return timer;
  }

  /// Fires every pending one-shot timer once and removes it; periodic
  /// timers are left scheduled.
  void fireAll({bool keepPeriodic = false}) {
    for (final timer in List<ManualTimer>.of(_timers)) {
      if (timer.cancelled) continue;
      if (!keepPeriodic) _timers.remove(timer);
      timer.callback();
    }
  }

  /// Fires the timers without removing them — for the periodic ones.
  void tick() {
    for (final timer in List<ManualTimer>.of(_timers)) {
      if (!timer.cancelled) timer.callback();
    }
  }
}

// --- Clock -------------------------------------------------------------

/// A clock a test moves by hand, so a debounce window is a fact rather
/// than a race.
final class MutableClock implements Clock {
  MutableClock([DateTime? start])
    : _now = start ?? DateTime.utc(2026, 7, 26, 14, 32, 11);

  DateTime _now;

  void advance(Duration by) => _now = _now.add(by);

  @override
  DateTime nowUtc() => _now;
}

// --- File picker -------------------------------------------------------

/// A scripted [FilePicker]. Null in the queue means "the user cancelled",
/// which is the branch most easily got wrong.
final class FakeFilePicker implements FilePicker {
  FakeFilePicker({List<String?>? openPaths, List<String?>? savePaths})
    : _openPaths = List.of(openPaths ?? const []),
      _savePaths = List.of(savePaths ?? const []);

  final List<String?> _openPaths;
  final List<String?> _savePaths;

  int openCalls = 0;
  int saveCalls = 0;
  final List<String?> suggestedNames = [];

  /// Every `initialDirectory` handed to a dialog, in order.
  ///
  /// RECORDED because that argument is the one the native Windows dialog
  /// blocks the platform thread on: a UNC value goes into
  /// `SHCreateItemFromParsingName`, which waits out the network timeout
  /// before any window appears. What the app must never do is pass a
  /// stored absolute path it has not checked.
  final List<String?> initialDirectories = [];

  /// Every `type` handed to a dialog, in order.
  ///
  /// RECORDED for D13's reason: the filter is the whole of M3-F/4, and a
  /// caller that forgot to ask for `csv` opens a dialog showing no CSV
  /// files at all, which looks like a broken import rather than a wrong
  /// argument.
  final List<FileDialogType> dialogTypes = [];

  @override
  Future<String?> pickOpen({
    String? initialDirectory,
    FileDialogType type = FileDialogType.project,
  }) async {
    openCalls++;
    initialDirectories.add(initialDirectory);
    dialogTypes.add(type);
    return _openPaths.isEmpty ? null : _openPaths.removeAt(0);
  }

  @override
  Future<String?> pickSave({
    String? suggestedName,
    String? initialDirectory,
    FileDialogType type = FileDialogType.project,
  }) async {
    saveCalls++;
    suggestedNames.add(suggestedName);
    initialDirectories.add(initialDirectory);
    dialogTypes.add(type);
    return _savePaths.isEmpty ? null : _savePaths.removeAt(0);
  }
}

// --- Prompts -----------------------------------------------------------

/// A scripted [SessionPrompts] that records every question it was asked.
///
/// Used by the `SessionController` tests, where the interesting thing is
/// the BRANCH taken rather than the dialog rendered. The dialogs
/// themselves are driven with real taps and real key events in
/// `rackpal_ui`'s own suite and in `app_shell_test.dart`.
final class ScriptedPrompts implements SessionPrompts {
  ScriptedPrompts({
    List<UnsavedChangesChoice>? discardChoices,
    List<String>? errorActions,
    List<RecoveryChoice>? recoveryChoices,
  }) : _discardChoices = List.of(discardChoices ?? const []),
       _errorActions = List.of(errorActions ?? const []),
       _recoveryChoices = List.of(recoveryChoices ?? const []);

  final List<UnsavedChangesChoice> _discardChoices;
  final List<String> _errorActions;
  final List<RecoveryChoice> _recoveryChoices;

  /// Every close prompt shown, as (name, editCount).
  final List<({String name, int? editCount})> discardPrompts = [];

  /// Every error view shown. The presenter's copy is asserted from here.
  final List<FileErrorView> errors = [];

  /// Every recovery prompt shown.
  final List<({String name, DateTime savedAt, int? count})> recoveries = [];

  /// Runs INSIDE [confirmRecovery], before the answer is returned.
  ///
  /// The window between the scan and the read is where a snapshot really
  /// does disappear — an AV scanner takes the handle, a permissions change
  /// lands, the stick is pulled — and a modal dialog is exactly how long
  /// that window is. This is the only way a test can be in it.
  Future<void> Function()? onBeforeRecoveryAnswer;

  @override
  Future<UnsavedChangesChoice> confirmDiscard({
    required String documentName,
    int? editCount,
  }) async {
    discardPrompts.add((name: documentName, editCount: editCount));
    // An exhausted script means Cancel, the answer that cannot lose work
    // — so a test that forgot to script a prompt fails by not proceeding
    // rather than by silently discarding a document.
    return _discardChoices.isEmpty
        ? UnsavedChangesChoice.cancel
        : _discardChoices.removeAt(0);
  }

  /// Runs INSIDE [showFileError], before the answer is returned.
  ///
  /// Same purpose as [onBeforeRecoveryAnswer]: a modal dialog is a long
  /// window, and the interesting failures happen inside it.
  Future<void> Function()? onBeforeErrorAnswer;

  @override
  Future<String> showFileError(FileErrorView view) async {
    errors.add(view);
    await onBeforeErrorAnswer?.call();
    return _errorActions.isEmpty
        ? view.dismissActionId
        : _errorActions.removeAt(0);
  }

  @override
  Future<RecoveryChoice> confirmRecovery({
    required String documentName,
    required DateTime savedAt,
    int? unsavedEditCount,
  }) async {
    recoveries.add((
      name: documentName,
      savedAt: savedAt,
      count: unsavedEditCount,
    ));
    await onBeforeRecoveryAnswer?.call();
    return _recoveryChoices.isEmpty
        ? RecoveryChoice.keepForLater
        : _recoveryChoices.removeAt(0);
  }
}

// --- Window ------------------------------------------------------------

/// A [WindowChrome] that records instead of talking to a desktop.
final class FakeWindowChrome implements WindowChrome {
  FakeWindowChrome({
    this.displayList = const [
      WindowBounds(left: 0, top: 0, width: 1920, height: 1080),
    ],
    WindowBounds? initialBounds,
    this.maximized = false,
  }) : _bounds =
           initialBounds ??
           const WindowBounds(left: 100, top: 100, width: 1280, height: 800);

  final List<WindowBounds> displayList;
  WindowBounds _bounds;
  bool maximized;

  WindowChromeListener? handler;

  /// True once `initialize()` has run. The assertion that
  /// `setPreventClose(true)` really happened lives on [preventClose].
  bool initialized = false;

  /// Every title actually pushed to the platform.
  final List<String> titles = [];
  final List<WindowBounds> appliedBounds = [];
  bool? preventClose;
  ({double width, double height})? minimumSize;
  int centerCalls = 0;
  int maximizeCalls = 0;
  int destroyCalls = 0;
  int showCalls = 0;

  @override
  Future<void> initialize() async {
    initialized = true;
    await setPreventClose(prevent: true);
  }

  @override
  void setHandler(WindowChromeListener? handler) => this.handler = handler;

  @override
  Future<void> setTitle(String title) async => titles.add(title);

  @override
  Future<void> setPreventClose({required bool prevent}) async =>
      preventClose = prevent;

  @override
  Future<void> setMinimumSize(double width, double height) async =>
      minimumSize = (width: width, height: height);

  @override
  Future<WindowBounds> bounds() async => _bounds;

  @override
  Future<void> setBounds(WindowBounds bounds) async {
    _bounds = bounds;
    appliedBounds.add(bounds);
  }

  @override
  Future<void> center() async => centerCalls++;

  @override
  Future<bool> isMaximized() async => maximized;

  @override
  Future<void> maximize() async {
    maximizeCalls++;
    maximized = true;
  }

  @override
  Future<List<WindowBounds>> displays() async => displayList;

  @override
  Future<void> show() async => showCalls++;

  @override
  Future<void> destroy() async => destroyCalls++;

  /// Simulates the OS close request that `setPreventClose(true)` turns
  /// into a question.
  Future<void> requestClose() async =>
      handler?.onWindowCloseRequested() ?? Future<void>.value();

  void blur() => handler?.onWindowBlurred();

  void moveOrResize() => handler?.onWindowGeometryChanged();
}

// --- The whole wiring --------------------------------------------------

/// Everything a session test needs, kept together so a test body reads as
/// the scenario rather than as the setup.
final class TestSession {
  TestSession({
    required this.services,
    required this.fs,
    required this.picker,
    required this.prompts,
    required this.chrome,
    required this.clock,
    required this.timers,
    required this.periodicTimers,
    required this.context,
    required this.navigatorKey,
  });

  final AppServices services;
  final FakeFileStore fs;
  final FakeFilePicker picker;
  final ScriptedPrompts prompts;
  final FakeWindowChrome chrome;
  final MutableClock clock;
  final ManualTimers timers;
  final ManualTimers periodicTimers;
  final p.Context context;
  final GlobalKey<NavigatorState> navigatorKey;
}

/// Wires a complete [AppServices] over the fakes.
///
/// WINDOWS-SHAPED PATHS ON EVERY PLATFORM: the injected
/// `p.Context(style: p.Style.windows)` is what lets a test assert
/// `C:\jobs\Smith.rmpj.tmp` on a Linux CI runner.
///
/// `inlineSerializer`/`inlineDeserializer` rather than the isolate pair:
/// spawning an isolate per save across a widget suite is slow and flaky,
/// and none of these tests is about isolates. `serialization_test.dart`
/// exercises the real isolate path once and asserts byte-identical
/// output — that is the "the isolate really works" proof, and it costs
/// one spawn instead of forty.
Future<TestSession> buildTestSession({
  RackDocument? document,
  FakeFileStore? fs,
  List<String?> openPaths = const [],
  List<String?> savePaths = const [],
  ScriptedPrompts? prompts,
  FakeWindowChrome? chrome,
  DataRoot? dataRoot,
  MutableClock? clock,
  StarterAssetLoader? starterLoader,
  ExportFontLoader? exportFontLoader,
  Serializer? serializer,
  Duration pathProbeTimeout = kSessionPathProbeTimeout,
  String recoverySessionId = kTestSessionId,
  bool useRealDialogs = false,
}) async {
  final context = p.Context(style: p.Style.windows);
  final navigatorKey = GlobalKey<NavigatorState>();
  final store =
      fs ??
      FakeFileStore(
        initialDirectories: {kTestDataRoot, kTestJobsDir, 'C:'},
      );
  final picker = FakeFilePicker(openPaths: openPaths, savePaths: savePaths);
  final scripted = prompts ?? ScriptedPrompts();
  final window = chrome ?? FakeWindowChrome();
  final theClock = clock ?? MutableClock();
  final oneShot = ManualTimers();
  final periodic = ManualTimers();

  // THE REAL DIALOGS, OVER A FAKE DISK, is what the widget tests want:
  // the `Shortcuts`/`Actions` pair, the File menu, the three-button
  // prompt and the recovery prompt are all the ones that ship. The
  // controller-level tests want the scripted prompt instead, because
  // their subject is the BRANCH taken and not the dialog rendered.
  final sessionPrompts = useRealDialogs
      ? NavigatorSessionPrompts(navigatorKey)
      : scripted;

  final services = await buildAppServices(
    fs: store,
    dataRoot: dataRoot ?? const DataRootReady(kTestDataRoot, portable: false),
    initialDocument:
        document ??
        RackDocument(
          id: const Uuid('test-doc'),
          appVersion: kAppVersion,
          createdAt: DateTime.utc(2026),
          modifiedAt: DateTime.utc(2026),
          meta: EntityMeta(
            createdAt: DateTime.utc(2026),
            updatedAt: DateTime.utc(2026),
            updatedBy: 'test',
          ),
        ),
    chrome: window,
    prompts: sessionPrompts,
    picker: picker,
    clock: theClock,
    serializer: serializer ?? inlineSerializer,
    deserializer: inlineDeserializer,
    timerFactory: oneShot.oneShot,
    periodicTimerFactory: periodic.periodic,
    starterLoader: starterLoader ?? loadStarterAssetFromDisk,
    exportFontLoader: exportFontLoader ?? loadExportFontsFromDisk,
    context: context,
    // The fakes speak Windows paths on every platform, so the Windows
    // errno table and MAX_PATH are the ones under test.
    isWindows: true,
    recoverySessionId: recoverySessionId,
    pathProbeTimeout: pathProbeTimeout,
  );

  // The SHELL is what installs the window handler in production. These
  // controller-level tests never mount a widget, so the same wiring is
  // done here — which keeps `chrome.requestClose()` meaning exactly what
  // the OS close button means, in both kinds of test.
  window.setHandler(_ControllerOnlyWindowHandler(services));

  return TestSession(
    services: services,
    fs: store,
    picker: picker,
    prompts: scripted,
    chrome: window,
    clock: theClock,
    timers: oneShot,
    periodicTimers: periodic,
    context: context,
    navigatorKey: navigatorKey,
  );
}

/// Stands in for `AppShell`'s own `WindowChromeListener` in the tests
/// that exercise the controller without a widget tree.
final class _ControllerOnlyWindowHandler implements WindowChromeListener {
  _ControllerOnlyWindowHandler(this.services);

  final AppServices services;

  @override
  Future<void> onWindowCloseRequested() => services.controller.requestClose(
    destroy: services.chrome.destroy,
  );

  @override
  void onWindowBlurred() => services.autosave.onWindowBlurred();

  @override
  void onWindowGeometryChanged() => services.geometry?.onGeometryChanged();
}

/// Builds a `RackPalApp` over a fake session, for the widget tests whose
/// subject is the shell rather than the storage underneath it.
///
/// TWO DEFAULTS THAT DIFFER FROM PRODUCTION, both for the same reason —
/// a test about the editor should not have to script its way past a
/// surface it is not testing:
///
///   * the document is the demo seed, so the canvas has something in it;
///   * `showStartCard` is FALSE, so the first frame is the editor.
///
/// `start_card_test.dart` passes `showStartCard: true` and is the test
/// that exercises what a user actually sees at launch.
Future<({RackPalApp app, TestSession session})> buildTestApp(
  TextMeasurer measurer, {
  RackDocument? document,
  List<String?> openPaths = const [],
  List<String?> savePaths = const [],
  ScriptedPrompts? prompts,
  FakeFileStore? fs,
  StarterAssetLoader? starterLoader,
  bool runStartupRecovery = false,
  bool showStartCard = false,

  /// Forwarded so a widget test can mount the app over a data root that
  /// does NOT work — the degraded session, where there is no `prefs.json`
  /// to record a coach mark in. It was reachable at the controller level
  /// and not at the widget level, which is exactly the half where
  /// DR-012.4's "no store" branch lives.
  DataRoot? dataRoot,
}) async {
  final session = await buildTestSession(
    document: document ?? buildDemoRackDocument(),
    fs: fs,
    openPaths: openPaths,
    savePaths: savePaths,
    prompts: prompts,
    starterLoader: starterLoader,
    dataRoot: dataRoot,
    useRealDialogs: true,
  );
  return (
    app: RackPalApp(
      measurer: measurer,
      services: session.services,
      navigatorKey: session.navigatorKey,
      // The REAL wiring, not a stub: `Ctrl+1..4` resolves through this key
      // in a test exactly as it does in `main`, so a broken view keymap is
      // a red suite rather than something only a human notices.
      shellKey: GlobalKey<AppShellState>(),
      runStartupRecovery: runStartupRecovery,
      showStartCard: showStartCard,
    ),
    session: session,
  );
}
