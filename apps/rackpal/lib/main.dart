import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:rackpal/src/session/app_services.dart';
import 'package:rackpal/src/session/app_shell.dart';
import 'package:rackpal/src/session/blank_document.dart';
import 'package:rackpal/src/session/window_chrome.dart';
import 'package:rackpal/src/storage/data_root.dart';
import 'package:rackpal/src/storage/io_file_store.dart';
import 'package:rackpal/src/storage/prefs_store.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_text/rackpal_text.dart';
import 'package:rackpal_ui/rackpal_ui.dart';
import 'package:screen_retriever/screen_retriever.dart';

// M1: the rack editor canvas plus the file lifecycle. The viewport
// skeleton hosts a real rack chassis and device bodies (docs/03 §7,
// CR-086), and as of this stage the SHELL owns the document: New / Open /
// Save / Save As, the dirty marker in the window title, close
// interception, the 30 s recovery snapshot and the startup recovery
// prompt (docs/03 §9). The one `TextMeasurer` (PdfFontMeasurer, CR-081)
// is still built once from the bundled Jost TTF and injected into the UI
// so on-screen layout matches the PDF backend.
//
// THE STRIP LIVES IN `src/session/app_shell.dart`, which is also where
// the document lives, because persistence is a property of the DOCUMENT
// and not of one tab.
//
// **THIS PARAGRAPH DESCRIBED A THREE-TAB STRIP WITH TWO INERT TABS UNTIL
// DR-159 §11.158.2**, and both halves had been false for milestones. It
// read that docs/05 §12 fixes the v1 strip at Rack / Schematic / Schedule
// and that the last two render `UnbuiltView`, "a panel whose first line
// is that the view is not built". M2-E built the schematic and its
// `UnbuiltView` is gone rather than softened; the schedule's went the
// same way; DR-091 §11.90.3 reordered the strip into job order and added
// Locations, Device Manager and Structured Wiring; `PLAN-E/5` added Plan.
//
// **THE NUMBER IS NOT WRITTEN HERE**, on the rule DR-159 §11.158.2
// states after this file, `rack_canvas_screen.dart` and the keymap
// registry all carried a tab count that went stale without moving.
// `ShellView.values` is the list and `app_shell.dart` builds the strip
// from it.
//
// `Ctrl+1` / `Ctrl+2` / `Ctrl+4` ARE BOUND NOW, as a complete group, and
// `Ctrl+3` is DELIBERATELY DEAD: docs/04 §8 line 456 and docs/10 :516
// reserve it for the interactive Rear Panel view (v1.1, CR-071) and
// forbid rebinding the Schedule onto it, because `Ctrl+n` is a view
// identity rather than an ordinal. Three activators for three tabs, with
// the fourth key held open, is the whole promise; it is not the partial
// keymap this comment used to describe. The FOUR file bindings —
// Ctrl+N / Ctrl+O / Ctrl+S / Ctrl+Shift+S — are the other complete
// group.
//
// STARTUP ORDER IS LOAD-BEARING and is explained in app_services.dart.
// The one rule with a measurement behind it: nothing here stats a recent
// file, because `exists` on a dead UNC path was measured at 1261 ms and
// the cold-start budget is 1.2 s.
//
// ==================================================================
// §12.1's PROGRAMMER-ERROR CHANNEL EXISTS, AND IT STARTS HERE
// ==================================================================
// The session layer throws `StateError` into it on purpose, twice —
// `DocumentStore.open returned a non-OpenError` and its save twin — as
// the honest way to say "this is our bug, not the user's file". Until
// this function installed the three handlers below, those throws landed
// in a discarded future and vanished. So did anything thrown by the four
// awaits before `runApp`, which is worse: a failure there means the
// process exits with a black window and no message at all.
Future<void> main() async {
  // ONE ZONE AROUND THE WHOLE APP, so an error from a callback with no
  // caller — a timer tick, a window event, an `unawaited` save — has
  // somewhere to go.
  await runZonedGuarded(_run, _reportFatal);
}

Future<void> _run() async {
  WidgetsFlutterBinding.ensureInitialized();

  // THE APPLICATION'S OWN LICENCE JOINS THE REGISTRY (DR-189 11.188.5).
  // Flutter collects every DEPENDENCY's licence automatically and
  // `showLicensePage` renders them; it knows nothing about ours, so
  // without this the page lists everyone but the program the person is
  // running. Lazily: `addLicense` takes a generator and the bundle read
  // happens on first open rather than on every launch.
  registerRackPalLicense(() => rootBundle.loadString('assets/LICENSE'));

  // Framework errors (build/layout/paint) and errors from futures the
  // engine is waiting on. Both default to printing in debug and to
  // silence in release; neither is a channel.
  FlutterError.onError = (details) =>
      _reportFatal(details.exception, details.stack ?? StackTrace.empty);
  PlatformDispatcher.instance.onError = (error, stack) {
    _reportFatal(error, stack);
    // Handled: an unhandled asynchronous error must not take the window
    // down while the user has unsaved work in it.
    return true;
  };

  final chrome = WindowManagerChrome(displayEnumerator: _enumerateDisplays);
  // BEFORE runApp. `setPreventClose(true)` — inside `initialize` — is the
  // one load-bearing API in the whole `window_manager` dependency:
  // without it the OS destroys the window and Flutter finds out
  // afterwards, and the three-button close prompt cannot exist at all.
  await chrome.initialize();

  final measurer = await _loadMeasurer();
  const fs = DartIoFileStore();

  // The ONE data-root resolution in the app. Both environment lookups are
  // injected here rather than read inside `resolveDataRoot`, because
  // `Platform.resolvedExecutable` under `flutter test` points at the test
  // runner — see data_root.dart.
  final dataRoot = await resolveDataRoot(
    fs: fs,
    executableDirectory: productionExecutableDirectory(),
    applicationSupportDirectory: productionApplicationSupportDirectory,
  );

  final navigatorKey = GlobalKey<NavigatorState>();

  final services = await buildAppServices(
    fs: fs,
    dataRoot: dataRoot,
    // THE FIRST FRAME IS THE START CARD (docs/04 §9), so this document is
    // what sits behind it until the user chooses — and it is a BLANK
    // PROJECT rather than the old demo seed, because whatever the user
    // picks replaces it and the one thing that must never happen is a
    // demo rack surviving into a document they then save. Picking `Blank
    // project` on the card runs `Ctrl+N`, which builds a fresh one
    // through the same function.
    initialDocument: buildBlankDocument(
      now: DateTime.now().toUtc(),
      appVersion: kAppVersion,
    ),
    chrome: chrome,
    prompts: NavigatorSessionPrompts(navigatorKey),
    context: p.context,
    // THE THIRD ENVIRONMENT LOOKUP, and it belongs here beside the other
    // two rather than as a `= true` default nobody overrode. It decides
    // which errno table classifies a failed save and whether MAX_PATH is
    // enforced, so defaulting it made a disk-full save on macOS read
    // "something went wrong that RackPal does not have a specific
    // explanation for" and refused any path over 259 characters on a
    // filesystem whose limit is 4096 bytes.
    //
    // `defaultTargetPlatform` rather than `Platform.isWindows`:
    // `storage_layering_test.dart` RULE 1 allows `dart:io` in exactly two
    // files and this is not one of them, and the two answers are the same
    // on desktop.
    isWindows: defaultTargetPlatform == TargetPlatform.windows,
  );

  // Geometry is restored BEFORE the window is shown, so the user never
  // watches it jump from a default position to the remembered one.
  await restoreWindowGeometry(chrome: chrome, prefs: services.prefs);

  runApp(
    RackPalApp(
      measurer: measurer,
      services: services,
      navigatorKey: navigatorKey,
      // Minted HERE and never inside `RackPalApp`, which is a
      // `StatelessWidget`: a key created in a build would be a new key on
      // every rebuild, and a new key on `AppShell` discards the shell's
      // `State` — the tab controller, the dismissed-warning record and the
      // start-card flag with it.
      shellKey: GlobalKey<AppShellState>(),
    ),
  );

  await chrome.show();
}

/// §12.1's programmer-error channel, at the one place it can be installed.
///
/// NO `print`, and not because of the lint: §12.4 forbids file paths,
/// client names and site addresses reaching a log, and an exception's
/// `toString` is exactly where a path ends up. `FlutterError.presentError`
/// is the framework's own sink — it is a no-op in release, and in debug it
/// prints the structured report a developer needs. When a crash reporter
/// lands (M2), this is the single function it hooks.
void _reportFatal(Object error, StackTrace stack) {
  FlutterError.presentError(
    FlutterErrorDetails(
      exception: error,
      stack: stack,
      library: 'rackpal',
      context: ErrorDescription('in the RackPal app zone'),
    ),
  );
}

/// Every display's work area, in the pure geometry type
/// `validateRestoredBounds` reasons in.
///
/// A failure here answers with an EMPTY LIST, which the caller treats
/// exactly like "the saved rectangle matches no display": centre the
/// window. That is deliberately the same conservative branch, because a
/// display list we could not read and a display that is not there are the
/// same amount of knowledge.
Future<List<WindowBounds>> _enumerateDisplays() async {
  try {
    final displays = await screenRetriever.getAllDisplays();
    return [
      for (final display in displays)
        WindowManagerChrome.displayBounds(
          visiblePosition: display.visiblePosition,
          visibleSize: display.visibleSize,
          size: display.size,
        ),
    ];
    // A display enumeration that throws is answered the same way as one
    // that comes back empty — see this function's own doc comment.
    // ignore: avoid_catches_without_on_clauses
  } catch (_) {
    return const [];
  }
}

/// Loads the bundled font bytes and builds the shared measurer. The PDF
/// backend needs SOME `PdfDocument` to construct a `PdfTtfFont`; the metrics
/// it reads are document-independent (CR-081, docs/08 §7.5).
Future<TextMeasurer> _loadMeasurer() async {
  const family = FontRef('Jost');
  final bytes = await rootBundle.load('assets/fonts/Jost-Regular.ttf');
  return PdfFontMeasurer.fromBytes(PdfDocument(), {
    family: bytes.buffer.asUint8List(),
  });
}

/// The app: the shell of docs/05 §12 over one document.
class RackPalApp extends StatelessWidget {
  /// Creates the app with the one shared [measurer] (CR-081) and the
  /// [services] the shell runs the file lifecycle through.
  const RackPalApp({
    required this.measurer,
    required this.services,
    required this.shellKey,
    this.navigatorKey,
    this.runStartupRecovery = true,
    this.showStartCard = true,
    super.key,
  });

  /// The single `TextMeasurer` every view measures through, so on-screen
  /// layout and the PDF backend can never disagree (CR-081).
  final TextMeasurer measurer;

  /// The document, the stores, the window and the prompts, wired once.
  ///
  /// REQUIRED, with no in-app default, on purpose. A "detached" fallback
  /// would be a second way the app can be wired that only tests ever
  /// take, and the storage layer is exactly where a second wiring rots
  /// unnoticed. Tests build these over `FakeFileStore`, which means they
  /// exercise the REAL shell against a fake disk rather than a shell that
  /// only exists under test.
  final AppServices services;

  /// Used by `NavigatorSessionPrompts` to reach a dialog context that
  /// survives the awaits a save runs across.
  final GlobalKey<NavigatorState>? navigatorKey;

  /// How `Ctrl+1..4` reaches the shell's `TabController`.
  ///
  /// REQUIRED, with no default, for the same reason [services] is: an
  /// optional key would make the view keymap silently inert in any wiring
  /// that forgot it, and "the shortcut does nothing" is precisely the
  /// failure mode `kFileShortcuts` was already written to prevent once.
  final GlobalKey<AppShellState> shellKey;

  /// Whether to run §9.4's recovery scan on the first frame. Off in the
  /// widget tests whose subject is something else, so they do not have to
  /// script an answer to a prompt they never wanted.
  final bool runStartupRecovery;

  /// Whether the first frame is docs/04 §9's start card. See
  /// `AppShell.showStartCard`.
  final bool showStartCard;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RackPal',
      navigatorKey: navigatorKey,
      // THE FILE AND VIEW BINDINGS GO HERE, above the app's root focus
      // scope, because the document is global. See `KeyScope.global`. The
      // defaults are merged rather than replaced: dropping them would
      // take Tab traversal, Enter-activates and Esc-dismisses with them.
      //
      // ONE CALL WHERE TWO CONST MAPS USED TO BE. `keymapShortcuts`
      // resolves the primary modifier for this platform — `Ctrl` here,
      // `Cmd` on macOS (debt D7) — so this is the only line in the app
      // that has to know a `MaterialApp` exists, and none that has to know
      // which key `Save` is on. It is memoised per (scope, platform), so
      // rebuilding this widget does not rebuild the map.
      shortcuts: {
        ...WidgetsApp.defaultShortcuts,
        ...keymapShortcuts(KeyScope.global),
      },
      actions: {
        ...WidgetsApp.defaultActions,
        ...buildFileActions(services.controller),
        ...buildViewActions(shellKey),
        // UNDO AND REDO ARE GLOBAL SINCE DR-159 §11.158.3, and were
        // handled in exactly one screen for five milestones. This is the
        // FALLBACK: `RackCanvasScreen` and `DeviceBuilderScreen` each
        // keep their own, and Flutter resolves an `Action` from the
        // focused context upward, so the nearer one wins where it
        // matters.
        ...buildUndoActions(shellKey),
        // DR-193 §11.192: `F7`/`F8`/`Shift+F8` from every view, with one
        // cursor. No screen keeps a nearer handler.
        ...buildValidationActions(shellKey),
      },
      // DR-090, both halves. Every value lives in `console_palette.dart`
      // in `rackpal_core`, where `contrast.dart` can check it; this call
      // site names no colour and no font, so there is nothing here to
      // drift from the ruling.
      theme: buildConsoleTheme(),
      home: AppShell(
        key: shellKey,
        services: services,
        measurer: measurer,
        runStartupRecovery: runStartupRecovery,
        showStartCard: showStartCard,
      ),
    );
  }
}
