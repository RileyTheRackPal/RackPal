// The app shell: the three-tab strip, the File menu, the four file
// keybindings, and the window wiring.
//
// ==================================================================
// PERSISTENCE IS WIRED HERE AND NOT IN A TAB
// ==================================================================
// The document is global; the tabs are views of it. Ctrl+S must save from
// the Schedule tab, the dirty marker must be right whichever tab is on
// top, and closing the window while dirty must prompt regardless of where
// focus is. So the `WindowChromeListener` and the autosave timer live
// above the `TabBarView`, and the four file bindings live above the whole
// app — see `KeyScope.global` for why "above the whole app" and not
// "above the tab view" is a correctness requirement rather than a
// preference.
//
// ==================================================================
// THE KEYS ARE NOT DECLARED IN THIS FILE ANY MORE (macOS debt D7)
// ==================================================================
// Eleven `SingleActivator` literals used to live here — four in
// `kFileShortcuts`, the same four again on the File menu items so the
// accelerators would render, and three in `kViewShortcuts` — and every
// one of them hard-coded `control: true`. macOS needs `Cmd`.
//
// They are seven rows in `kKeymap` now, under `KeyScope.global`, and the
// primary modifier resolves per platform through `defaultTargetPlatform`.
// SEVEN AND NOT ELEVEN because the menu no longer declares a second copy:
// `MenuItemButton.shortcut` reads the same registry row the binding does,
// so a menu that advertises a key nothing listens for is no longer a thing
// this file can express. That was half of what
// `session_layering_test.dart` RULE 14 was written to catch by counting
// activators; the rule now asserts the structure that makes it impossible,
// and still pins the group at exactly seven so it cannot quietly grow.
//
// ==================================================================
// TWO COMPLETE BINDING GROUPS
// ==================================================================
// The FILE group — Ctrl+N, Ctrl+O, Ctrl+S, Ctrl+Shift+S — and the VIEW
// group, `Ctrl+1..4`. The rest of docs/04 §8's ~40-binding table stays
// UNBOUND, on the ruling recorded in this app's `main.dart`: a partial
// keymap reads as a whole one, so a group lands only when it is complete.
//
// THE VIEW GROUP IS COMPLETE AT THREE ACTIVATORS, and that is a ruling
// rather than an omission. docs/04 §8 (line 456) and docs/10 (:516):
// "`Ctrl+3` is reserved for the Rear Panel view and is an unbound no-op
// until v1.1 (CR-071); `Ctrl+4` is the Schedule in v1 and forever. Do not
// rebind the Schedule to `Ctrl+3` — `Ctrl+n` is a view identity, not an
// ordinal." So the strip is three tabs and the keys are 1, 2 and 4, with
// 3 deliberately dead. Binding Schedule to `Ctrl+3` to close the gap
// would break muscle memory twice: once now and once in v1.1.
//
// The absence now lives in the registry (there is no `Ctrl+3` row) and
// the ordinal lives in [kViewKeyToTabIndex]. RULE 14e checks both.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:rackmate/src/session/app_services.dart';
import 'package:rackmate/src/session/document_session.dart';
import 'package:rackmate/src/session/locations_actions.dart';
import 'package:rackmate/src/session/session_controller.dart';
import 'package:rackmate/src/session/session_prompts.dart';
import 'package:rackmate/src/session/starter_projects.dart';
import 'package:rackmate/src/session/window_chrome.dart';
import 'package:rackmate/src/storage/recents_store.dart';
import 'package:rackmate_core/rackmate_core.dart'
    show LocationRemovalPlan, TextMeasurer, Uuid, buildRackPresets;
import 'package:rackmate_ui/rackmate_ui.dart';

/// Which tab of the v1 strip each `Ctrl/Cmd+n` view identity renders as.
///
/// THE ORDINAL LIVES HERE AND NOWHERE ELSE, and that placement is the
/// ruling rather than a convenience. docs/04 §8 line 456 and docs/10 :516:
/// "`Ctrl+n` is a view identity, not an ordinal." The identity is
/// permanent and belongs in the keymap registry; the index is whatever
/// position that view happens to occupy in the strip THIS milestone
/// renders, and it belongs in the file that builds the strip. They used to
/// travel together inside `SwitchViewIntent`, which meant a shared,
/// platform-level registry would have carried one milestone's tab order —
/// the conflation the ruling forbids, written into the one place it would
/// outlive every strip.
///
/// THREE ENTRIES, AND `4` MAPS TO INDEX 2. That is not an off-by-one: the
/// strip is Rack · Schematic · Schedule and CR-071 reserves `Ctrl+3` for
/// the v1.1 Rear Panel, so the Schedule is the third TAB and the fourth
/// KEY, permanently. See this file's header, and
/// `session_layering_test.dart` RULE 14e — the test that exists to stop
/// the tidy-up.
const Map<int, int> kViewKeyToTabIndex = <int, int>{1: 0, 2: 1, 4: 2};

/// Where the Schematic sits in THIS milestone's strip.
///
/// READ OUT OF [kViewKeyToTabIndex] rather than written as `1`, because
/// that map is the file's own statement that the ordinal is a property of
/// the strip and not of the view. CR-105's chip and AC-048's coach mark
/// both need to name this tab; neither may hard-code a position that
/// CR-071's `Ctrl+3` Rear Panel will move in v1.1.
final int _kSchematicTabIndex = kViewKeyToTabIndex[2]!;

/// The handler for the registry's view-switch bindings.
///
/// Takes the shell's `GlobalKey` rather than a `TabController`, because
/// the controller belongs to a `State` that does not exist when the app's
/// action map is built. [AppShellState] is already public for exactly
/// this kind of reach — see its own doc.
///
/// INSTALLED AT THE APP ROOT, beside [buildFileActions] and for the same
/// reason: `ShortcutManager` resolves an intent by looking up from the
/// FOCUSED context, and on the Schedule tab nothing in the subtree need
/// hold focus. An `Actions` widget inside the shell would therefore work
/// on the Rack tab (whose canvas autofocuses) and silently do nothing on
/// the other two — the exact bug `KeyScope.global` documents.
Map<Type, Action<Intent>> buildViewActions(GlobalKey<AppShellState> shell) =>
    <Type, Action<Intent>>{
      SwitchViewIntent: CallbackAction<SwitchViewIntent>(
        onInvoke: (intent) {
          // An UNMAPPED view key does nothing, and does it silently. The
          // registry may name a view this build does not render — that is
          // exactly what `Ctrl+3` will be when the Rear Panel lands in the
          // registry ahead of the tab — and "switch to a view that is not
          // in the strip" has no honest answer but to decline.
          final index = kViewKeyToTabIndex[intent.viewKey];
          if (index != null) shell.currentState?.switchToTab(index);
          return null;
        },
      ),
    };

/// The handlers for the registry's four file bindings, bound to one
/// session.
Map<Type, Action<Intent>> buildFileActions(SessionController controller) =>
    <Type, Action<Intent>>{
      NewDocumentIntent: CallbackAction<NewDocumentIntent>(
        onInvoke: (_) => controller.newDocument(),
      ),
      OpenDocumentIntent: CallbackAction<OpenDocumentIntent>(
        onInvoke: (_) => controller.openDocument(),
      ),
      SaveDocumentIntent: CallbackAction<SaveDocumentIntent>(
        onInvoke: (_) => controller.save(),
      ),
      SaveDocumentAsIntent: CallbackAction<SaveDocumentAsIntent>(
        onInvoke: (_) => controller.saveAs(),
      ),
    };

/// The shell over one document.
final class AppShell extends StatefulWidget {
  const AppShell({
    required this.services,
    required this.measurer,
    this.runStartupRecovery = true,
    this.showStartCard = true,
    super.key,
  });

  final AppServices services;

  /// The shared `TextMeasurer` (CR-081).
  final TextMeasurer measurer;

  /// Whether to run §9.4's startup scan on the first frame. Off in tests
  /// that are about something else, so they do not have to script a
  /// recovery prompt they never wanted.
  final bool runStartupRecovery;

  /// Whether the first frame is docs/04 §9's start card rather than the
  /// editor.
  ///
  /// TRUE IN PRODUCTION. §9: "First launch shows a start card, not an
  /// empty canvas". The flag exists because the widget tests whose
  /// subject is the editor should not have to dismiss a card first — the
  /// same reasoning, and the same default-on shape, as
  /// [runStartupRecovery].
  ///
  /// It is DISMISSED, never re-shown: once the user has chosen a
  /// document the shell is the editor for the rest of the session, and
  /// `Ctrl+N` produces a blank project rather than putting the card
  /// back. v1 is single-document (CR-119), so "no document is open" is
  /// not a state the app can return to.
  final bool showStartCard;

  @override
  State<AppShell> createState() => AppShellState();
}

/// PUBLIC so widget tests can reach the shell's state for the handful of
/// assertions that are about the shell itself — the window title it
/// computed, whether the close handler ran — rather than about a widget
/// it rendered.
final class AppShellState extends State<AppShell>
    with SingleTickerProviderStateMixin
    implements WindowChromeListener {
  late final TabController _tabController;
  final MenuController _fileMenu = MenuController();
  final MenuController _projectMenu = MenuController();

  /// CR-105's signpost, carried across the strip.
  ///
  /// THE SHELL OWNS IT BECAUSE THE SHELL IS THE ONLY THING THAT CAN. The
  /// elevation raises "show me this device"; only this class can change
  /// tabs; the schematic answers it. Neither tab may reach the other, and
  /// `rackmate_ui` deliberately contains no shell.
  final SchematicRevealController _reveal = SchematicRevealController();

  /// Whether AC-048's coach mark should be showing on the Schematic tab.
  ///
  /// ══════════════════════════════════════════════════════════════════
  /// "FIRST" IS DECIDED HERE, AND PERSISTED IN APP-SUPPORT PREFS
  /// ══════════════════════════════════════════════════════════════════
  /// DR-012.4 (canon §11.12.4). docs/04:468 gives the trigger — "it is
  /// taught the first time the Schematic is opened rather than discovered
  /// later" — and this class is where "the Schematic is opened" exists as
  /// an event at all: it is the tab controller changing to index 1.
  ///
  /// Held as state rather than read from the store on every build so the
  /// mark cannot flicker back while the dismissal write is in flight.
  bool _showFilterCoachMark = false;

  List<RecentEntry> _recents = const [];
  Map<String, RecentEntryState> _recentStates = const {};

  /// The warning text the user dismissed, not a bare bool.
  ///
  /// Dismissing "RackMate cannot write to its data folder" must not also
  /// dismiss a DIFFERENT warning that arrives an hour later saying
  /// autosave has stopped — the user has not read that one. Keying the
  /// dismissal on the message is what makes a new fact reach them.
  String? _dismissedWarning;

  late bool _startCardVisible = widget.showStartCard;

  AppServices get _services => widget.services;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this)
      ..addListener(_onTabChanged);
    _services.session.addListener(_onSessionChanged);
    // Persistence can fail at any point in the session, not only at
    // startup — see app_services.dart's header.
    _services.degradedWarning.addListener(_onWarningChanged);
    _services.controller.onDocumentReplaced = _onDocumentReplaced;
    _services.controller.onCleanShutdown = _flushPendingWrites;
    _services.chrome.setHandler(this);
    _services.autosave.start();
    // The title is pushed on the first frame rather than waiting for the
    // first edit, so a window that opens onto an untitled document is
    // still named.
    unawaited(_services.titleWriter.apply(_services.session.windowTitle));
    unawaited(_startup());
  }

  @override
  void dispose() {
    _services.chrome.setHandler(null);
    _services.session.removeListener(_onSessionChanged);
    _services.degradedWarning.removeListener(_onWarningChanged);
    _services.autosave.stop();
    _services.geometry?.cancel();
    _tabController
      ..removeListener(_onTabChanged)
      ..dispose();
    _reveal.dispose();
    super.dispose();
  }

  /// docs/04:468's trigger for AC-048's third coach mark.
  ///
  /// THE INDEX, NOT THE JOURNEY. docs/09:259 calls it "the coach mark at
  /// the first rack→schematic switch" and docs/04:468 calls it "the first
  /// time the Schematic is opened"; the second is implemented, because
  /// the app opens on the Rack tab so every first arrival here came from
  /// it anyway, and because what a user experiences is the sheet
  /// appearing, not which tab they left.
  ///
  /// NOT ON A SHEET WITH NOTHING TO FILTER. The mark teaches how to SEE
  /// wires; a document with no cables has none to see, and spending a
  /// once-per-user hint on an empty sheet spends it where it cannot mean
  /// anything. The Schematic's own `kNoLinksDetail` is what speaks there.
  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    if (_tabController.index != _kSchematicTabIndex) return;
    if (_showFilterCoachMark) return;
    if (_services.session.document.links.isEmpty) return;
    final store = _services.prefsStore;
    // A degraded session has no store: show it once per session, which is
    // not a nag, rather than not at all. See `AppServices.prefsStore`.
    if (store != null &&
        store.current.hasSeenCoachMark(kCoachMarkSchematicFilter)) {
      return;
    }
    setState(() => _showFilterCoachMark = true);
  }

  /// Records AC-048's mark as seen — from its `Got it` button, or from the
  /// user filtering a domain without reading it.
  void _dismissFilterCoachMark() {
    if (!_showFilterCoachMark) return;
    setState(() => _showFilterCoachMark = false);
    final store = _services.prefsStore;
    if (store == null) return;
    // LOAD-MODIFY-WRITE THROUGH THE STORE'S OWN CACHE, exactly as
    // `WindowGeometryRecorder` does, so this cannot revert
    // `lastSaveDirectory` or the window geometry — the defect
    // `AppServices.prefs` documents at length.
    unawaited(
      store.save(store.current.withCoachMarkSeen(kCoachMarkSchematicFilter)),
    );
  }

  Future<void> _startup() async {
    // RECENTS FIRST AND WITHOUT A PROBE. See app_services.dart's header
    // for the 1261 ms measurement this ordering exists because of.
    final recents = await _services.controller.loadRecents();
    if (!mounted) return;
    setState(() => _recents = recents);

    if (widget.runStartupRecovery) {
      // A RECOVERED DOCUMENT DISMISSES THE START CARD. The user did not
      // ask to start anything: they asked to get their work back, and
      // then being shown a menu of new projects on top of it would read
      // as though the recovery had not happened.
      final recovered = await _services.controller.runStartupRecovery();
      if (recovered && mounted) setState(() => _startCardVisible = false);
    }
  }

  void _onSessionChanged() {
    // The title is recomputed on every change notification and DIFFED
    // inside the writer, so a 60 Hz drag does not become 60 platform
    // channel calls.
    unawaited(_services.titleWriter.apply(_services.session.windowTitle));
    setState(() {});
  }

  void _onDocumentReplaced() {
    if (!mounted) return;
    setState(() {});
  }

  void _onWarningChanged() {
    if (!mounted) return;
    setState(() {
      // A DISMISSAL COVERS ONE OCCURRENCE, NOT THE REST OF THE SESSION.
      // The warning going away means the condition it described is over;
      // if it comes back, that is news again. Leaving the dismissal
      // standing would mean a user who dismissed "autosave has stopped
      // working" once is never told the second time — and the second time
      // is the one that costs them the work.
      if (_services.degradedWarning.value == null) _dismissedWarning = null;
    });
  }

  Future<void> _flushPendingWrites() async {
    await _services.geometry?.flush();
  }

  /// docs/04 §8's `Ctrl+1..4`, landed. Public because the app's action map
  /// is built above this `State` — see [buildViewActions].
  ///
  /// A NO-OP WHILE THE START CARD IS UP, and that is the same ruling the
  /// hidden tab strip is built on: the three tabs are views of a document
  /// and the user has not chosen one yet, so switching between them would
  /// mean switching between views of a document nobody asked for.
  void switchToTab(int index) {
    if (_startCardVisible) return;
    if (index < 0 || index >= _tabController.length) return;
    _tabController.animateTo(index);
  }

  // --- WindowChromeListener ---------------------------------------------

  @override
  Future<void> onWindowCloseRequested() =>
      _services.controller.requestClose(destroy: _services.chrome.destroy);

  @override
  void onWindowBlurred() => _services.autosave.onWindowBlurred();

  @override
  void onWindowGeometryChanged() => _services.geometry?.onGeometryChanged();

  // --- Actions ----------------------------------------------------------

  Future<void> _newDocument() async {
    if (await _services.controller.newDocument()) _dismissStartCard();
  }

  Future<void> _openDocument() async {
    if (await _services.controller.openDocument()) _dismissStartCard();
  }

  /// docs/04 §9's `Blank project`.
  ///
  /// It runs `Ctrl+N`'s handler rather than a second one: "blank" is the
  /// same operation whichever surface asks for it, and a start card with
  /// its own quietly-different New would be the first place the two
  /// drifted.
  Future<void> _blankProject() async {
    if (await _services.controller.newDocument()) _dismissStartCard();
  }

  Future<void> _openStarter(String id) async {
    final starter = kStarterProjects.firstWhere((s) => s.id == id);
    if (await _services.controller.openStarter(starter)) _dismissStartCard();
  }

  /// Only ever called after an operation that SUCCEEDED. A cancelled
  /// file dialog or a starter that failed to load must leave the card up
  /// — dropping the user onto an editor they did not ask for would be
  /// the shell deciding on their behalf.
  void _dismissStartCard() {
    if (!mounted || !_startCardVisible) return;
    setState(() => _startCardVisible = false);
  }

  Future<void> _save() async {
    await _services.controller.save();
  }

  Future<void> _saveAs() async {
    await _services.controller.saveAs();
  }

  /// docs/08 §8.1's export, as ONE menu entry.
  ///
  /// §8.1's full `Ctrl+P` dialog — presets, the sheet checklist, palette,
  /// live preview — is not built this stage, and neither is the binding:
  /// the registry's global scope is exactly four file bindings,
  /// `session_layering_test.dart` RULE 14 asserts it, and that rule exists
  /// so a fifth cannot arrive without the decision being taken again.
  Future<void> _exportPdf() async {
    await _services.export.exportPdf();
  }

  Future<void> _openRecent(String path) async {
    if (await _services.controller.openPath(path)) _dismissStartCard();
  }

  /// Runs the bounded probe when the File menu opens. NEVER at startup,
  /// and it removes nothing — a slow share is not a broken entry.
  Future<void> _refreshRecents() async {
    final entries = await _services.controller.loadRecents();
    if (!mounted) return;
    setState(() {
      _recents = entries;
      _recentStates = {
        for (final e in entries) e.path: RecentEntryState.checking,
      };
    });
    final probed = await _services.controller.probeRecents(entries);
    if (!mounted) return;
    setState(() => _recentStates = probed);
  }

  // --- Build ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final session = _services.session;
    final warning = _services.degradedWarning.value;
    final status = session.status;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 8,
        title: Row(
          children: [
            _FileMenu(
              controller: _fileMenu,
              recents: _recents,
              recentStates: _recentStates,
              onOpenMenu: _refreshRecents,
              onNew: _newDocument,
              onOpen: _openDocument,
              onSave: _save,
              onSaveAs: _saveAs,
              onExportPdf: _exportPdf,
              onOpenRecent: _openRecent,
            ),
            _ProjectMenu(
              controller: _projectMenu,
              onLocations: () => unawaited(_openLocations()),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                // The IN-APP title carries the same `*` the OS window
                // title does, from the same function, so the two can
                // never disagree about whether there is unsaved work.
                session.windowTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
        // NO TAB STRIP OVER THE START CARD. The three tabs are views of
        // a document, and while the card is up the user has not chosen
        // one — a strip whose tabs switch between three views of a
        // document nobody asked for would be the same lie the Schedule
        // tab was rescued from.
        bottom: _startCardVisible
            ? null
            : TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(icon: Icon(Icons.dashboard_outlined), text: 'Rack'),
                  // NO CONSTRUCTION GLYPH ON ANY TAB NOW. The marker said
                  // which view did nothing yet; the Schedule lost it at
                  // M2-B and the Schematic loses it at M2-E, because "a
                  // tab that works while still wearing the 'not built'
                  // marker is the same class of untruth as the panel this
                  // replaced, pointing the other way"
                  // (shell_tabs_test.dart). The tab TEXT stays exactly as
                  // docs/05 §12 spells it.
                  Tab(icon: Icon(Icons.polyline_outlined), text: 'Schematic'),
                  Tab(icon: Icon(Icons.table_rows_outlined), text: 'Schedule'),
                ],
              ),
      ),
      body: _startCardVisible
          ? StartCard(
              starters: [
                for (final starter in kStarterProjects)
                  StarterEntry(
                    id: starter.id,
                    title: starter.title,
                    summary: starter.summary,
                    detail: starter.detail,
                  ),
              ],
              onBlank: () => unawaited(_blankProject()),
              onStarter: (id) => unawaited(_openStarter(id)),
              onOpen: () => unawaited(_openDocument()),
            )
          : _editor(session, warning: warning, status: status),
    );
  }

  Widget _editor(
    DocumentSession session, {
    required String? warning,
    required String? status,
  }) {
    return Column(
      children: [
        if (session.openReadOnly)
          ReadOnlyBanner(onSaveCopy: () => unawaited(_saveAs())),
        if (warning != null && warning != _dismissedWarning)
          ShellWarningBanner(
            message: warning,
            onDismiss: () => setState(() => _dismissedWarning = warning),
          ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            // ═════════════════════════════════════════════════════════
            // THE VIEW IS NOT A THING YOU SCROLL TO — #96, from the field
            // ═════════════════════════════════════════════════════════
            // `TabBarView` is a `PageView` and takes page-scroll physics by
            // default, so a horizontal wheel or a two-finger sideways
            // trackpad swipe drags the whole view sideways. On a phone that
            // is the affordance; here it is a collision, because BOTH
            // canvases already claim exactly that gesture for panning —
            // `CanvasIntentDetector._onPointerSignal` pans by the full
            // scroll delta, `dx` included, and `_onPanZoomUpdate` does the
            // same for a native trackpad pan.
            //
            // So one sideways scroll moved the sheet AND dragged the page,
            // which then settled back to the nearest tab: the "jumps around
            // erratically" the user reported. Nothing was ever designed to
            // switch views this way — the affordance is the tab bar and
            // `Ctrl+1/2/4` (CR-071), and canon §1.10 principle (a) makes
            // view-switching a GLOBAL command rather than a canvas gesture.
            //
            // THIS DOES NOT DISABLE PROGRAMMATIC SWITCHING.
            // `TabController.animateTo` is unaffected, so the tab bar, the
            // keymap and `switchToTab` all still work — see
            // `.okf/practices/defer-past-the-gesture.md` for the separate
            // hazard of switching mid-click, which this neither fixes nor
            // reintroduces.
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _rackTab(session),
              // THE SCHEMATIC IS BUILT NOW (M2-E), and the `UnbuiltView`
              // that stood here is gone rather than softened — the same
              // move, for the same reason, as the Schedule's one tab over.
              //
              // ITS COPY WAS READ BEFORE IT WAS REPLACED, and four of its
              // five clauses had become false: a sheet IS laid out (M2-C's
              // Sugiyama phases 0–3), symbols ARE placed on it, net labels
              // ARE drawn (M2-D, DR-001's default render) and a wire IS
              // routed once a domain is soloed, hovered with `Alt`, or
              // focused. Its own summary — "The gap is the view, not the
              // data" — was the sentence that expired first.
              //
              // THE ONE CLAUSE THAT IS STILL TRUE was carried across
              // rather than dropped: "nothing in this build creates a
              // connection, so a document edited here holds zero Links".
              // It now lives on the sheet itself as
              // `kNoLinksHeadline`/`kNoLinksDetail`, where the reader who
              // needs it is, and `unbuilt_copy_accuracy_test.dart` still
              // proves it against the source of both UI packages and this
              // app rather than against a comment.
              SchematicCanvasScreen(
                // KEYED ON THE CONTROLLER'S IDENTITY, as both siblings
                // are: replacing the document must reset the domain
                // filter, the selection, the focus scope and the framed
                // viewport, because every one of them is an answer about
                // a document and this is a different one.
                key: ValueKey(session.controller),
                measurer: widget.measurer,
                controller: session.controller,
                reveal: _reveal,
                showFilterCoachMark: _showFilterCoachMark,
                onDismissFilterCoachMark: _dismissFilterCoachMark,
              ),
              // THE SCHEDULE IS BUILT NOW, and the panel that used to sit
              // here is gone rather than softened. Its copy said "no code
              // turns a Link into a row", which was true when it was
              // written and is false now that
              // `rackmate_core/derived/schedule.dart` exists — and the
              // one panel in the app whose entire purpose is accuracy
              // about what exists must not be the last thing to hear.
              //
              // What survives is the sentence it was defending: a table
              // with no rows must not read as "you have not wired
              // anything". `ScheduleScreen`'s zero-row state says the
              // DOCUMENT holds no cables and names the missing gesture —
              // see `kNoCablesDetail`.
              ScheduleScreen(
                // KEYED ON THE CONTROLLER'S IDENTITY, as the rack tab is:
                // replacing the document must reset the preset and the
                // filter, because those are answers about a document and
                // this is a different one.
                key: ValueKey(session.controller),
                document: session.document,
              ),
            ],
          ),
        ),
        if (status != null) ShellStatusLine(message: status),
      ],
    );
  }

  /// docs/04 §9's New-rack dialog, opened from the rack-less panel.
  ///
  /// The SAME `showNewRack` the rack canvas's `Ctrl+Alt+N` calls, so there
  /// is one rack-creation path in the app rather than two that can drift.
  /// The shell needs no follow-up of its own: creating a rack makes
  /// `racks.isEmpty` false, the session's own change notification rebuilds
  /// this subtree, and `_rackTab` then returns the canvas — which opens on
  /// `racks.keys.first`, the rack that was just created.
  Future<void> _newRackFromEmptyPanel(DocumentSession session) async {
    final outcome = await showNewRack(
      context: context,
      controller: session.controller,
      presets: buildRackPresets(),
    );
    if (!mounted) return;
    // Cancel is nothing at all. A refusal is not: it must not vanish.
    if (outcome case NewRackRefused(:final reason)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(reason)));
    }
  }

  /// `Project ▸ Locations…` (CR-112).
  ///
  /// PROJECT-LEVEL, which is the whole ruling: a project with racks and no
  /// Structure device must still be able to say which room a rack is in,
  /// so this hangs off the menu bar rather than off either editor.
  Future<void> _openLocations() async {
    final session = _services.session;
    await showLocationsPanel(
      context,
      doc: session.document,
      actions: buildLocationsPanelActions(
        controller: session.controller,
        confirmRemoval: _confirmLocationRemoval,
        onRefuse: _showRefusal,
      ),
    );
  }

  /// DR-021 §11.20.3's confirmation, or an immediate yes when the plan
  /// costs nothing. The `BuildContext` is why this is here rather than in
  /// `locations_actions.dart`.
  Future<bool> _confirmLocationRemoval(
    LocationRemovalPlan plan,
    String name,
  ) async {
    if (!mounted) return false;
    return confirmLocationRemoval(context, plan: plan, name: name);
  }

  /// A refusal must not vanish, the rule `_newRackFromEmptyPanel` already
  /// states: the sentence names both nodes and is the only thing that
  /// tells the user which two are the problem.
  void _showRefusal(String reason) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(reason)));
  }

  Widget _rackTab(DocumentSession session) {
    // A document with no racks is REACHABLE the moment the app can open a
    // file, and `RackCanvasScreen` reads `racks.values.first` while
    // building its state. An honest panel beats a crash on a valid file.
    if (session.document.racks.isEmpty) {
      return NoRacksView(
        documentName: session.displayName,
        onNewRack: () => unawaited(_newRackFromEmptyPanel(session)),
      );
    }
    return RackCanvasScreen(
      // KEYED ON THE CONTROLLER'S IDENTITY. Replacing the document must
      // build a fresh `State`: the screen's controller, rack, geometry
      // cache and scene are all `late final` or derived, and reusing the
      // old `State` would leave every one of them pointing at the
      // previous document.
      key: ValueKey(session.controller),
      measurer: widget.measurer,
      controller: session.controller,
      // CR-105, joined up. Supplying this callback is ALSO what makes the
      // chip appear at all (`RackCanvasScreen.onRevealInSchematic`): the
      // elevation refuses to draw a signpost nobody is listening to, and
      // this shell is the only listener that can exist.
      onRevealInSchematic: _revealInSchematic,
    );
  }

  /// The elevation's chip, answered: park the request, then switch tabs.
  ///
  /// PARK FIRST, SWITCH SECOND, and the order is the whole of why this is
  /// two steps. `TabBarView` builds its pages lazily, so the schematic
  /// may not be mounted when the chip is clicked; the controller holds
  /// the request as STATE and the screen drains it on its first frame.
  /// Notifying after the switch would work too — and would break the
  /// first time Flutter changed when that page is built.
  void _revealInSchematic(Uuid deviceId) {
    _reveal.reveal(deviceId);
    // ═════════════════════════════════════════════════════════════════
    // THE SWITCH IS DEFERRED PAST THE CLICK THAT ASKED FOR IT
    // ═════════════════════════════════════════════════════════════════
    // `TabBarView` is a `PageView`, and a `PageView` SETTLES TO THE
    // NEAREST PAGE when the pointer it is watching goes up. The click on
    // the chip is that pointer: switching inside it moves
    // `TabController.index` to 1 while the page position is still at 0,
    // and the settle then puts page 0 straight back into the controller.
    // Measured: `index` read 1 the instant `switchToTab` returned and 0
    // once the frame settled, so a user would have seen the Schematic
    // flash and the Rack come back.
    //
    // One post-frame hop puts the switch after the gesture has resolved.
    // The reveal request is parked FIRST and unconditionally, so the
    // schematic gets it whichever frame it is built on.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) switchToTab(_kSchematicTabIndex);
    });
  }
}

/// The File menu. `MenuItemButton`'s `shortcut` renders the accelerator
/// text, so the menu and the bindings are declared from the same place
/// and cannot drift apart into a menu that advertises a key nothing
/// listens for.
final class _FileMenu extends StatelessWidget {
  const _FileMenu({
    required this.controller,
    required this.recents,
    required this.recentStates,
    required this.onOpenMenu,
    required this.onNew,
    required this.onOpen,
    required this.onSave,
    required this.onSaveAs,
    required this.onExportPdf,
    required this.onOpenRecent,
  });

  final MenuController controller;
  final List<RecentEntry> recents;
  final Map<String, RecentEntryState> recentStates;
  final Future<void> Function() onOpenMenu;
  final Future<void> Function() onNew;
  final Future<void> Function() onOpen;
  final Future<void> Function() onSave;
  final Future<void> Function() onSaveAs;
  final Future<void> Function() onExportPdf;
  final Future<void> Function(String path) onOpenRecent;

  @override
  Widget build(BuildContext context) {
    return MenuBar(
      children: [
        SubmenuButton(
          controller: controller,
          onOpen: () => unawaited(onOpenMenu()),
          menuChildren: [
            MenuItemButton(
              shortcut: keymapActivator(KeyBindingId.newDocument),
              onPressed: () => unawaited(onNew()),
              child: const Text('New'),
            ),
            MenuItemButton(
              shortcut: keymapActivator(KeyBindingId.openDocument),
              onPressed: () => unawaited(onOpen()),
              child: const Text('Open…'),
            ),
            SubmenuButton(
              menuChildren: buildRecentFilesMenuItems(
                entries: [
                  for (final entry in recents)
                    RecentEntryView(
                      id: entry.path,
                      displayName: entry.displayName,
                      subtitle: entry.path,
                      status: switch (recentStates[entry.path]) {
                        RecentEntryState.ok => RecentEntryStatus.ok,
                        RecentEntryState.unreachable =>
                          RecentEntryStatus.unreachable,
                        // A `null` state is an entry the probe has not
                        // reported on yet — the same thing `checking`
                        // means, and rendered the same way.
                        RecentEntryState.checking ||
                        null => RecentEntryStatus.checking,
                      },
                    ),
                ],
                onOpen: (path) => unawaited(onOpenRecent(path)),
              ),
              child: const Text('Open Recent'),
            ),
            MenuItemButton(
              shortcut: keymapActivator(KeyBindingId.saveDocument),
              onPressed: () => unawaited(onSave()),
              child: const Text('Save'),
            ),
            MenuItemButton(
              shortcut: keymapActivator(KeyBindingId.saveDocumentAs),
              onPressed: () => unawaited(onSaveAs()),
              child: const Text('Save As…'),
            ),
            // NO `shortcut:` — and that is a decision, not an omission.
            // docs/08 §8.1 gives export `Ctrl+P`, but
            // `session_layering_test.dart` RULE 14 asserts the global
            // group at exactly four file bindings precisely so it cannot
            // grow a fifth member without that being re-taken.
            //
            // THE OTHER HALF OF WHAT THAT RULE PROTECTED is now
            // structural: a `shortcut:` here would have to name a
            // `KeyBindingId`, and naming one that is not bound is not
            // possible — the registry row IS the binding. What is left to
            // assert is that this item still has no accelerator at all,
            // which is a count RULE 14 keeps.
            MenuItemButton(
              onPressed: () => unawaited(onExportPdf()),
              child: const Text('Export PDF…'),
            ),
          ],
          child: const Text('File'),
        ),
      ],
    );
  }
}

/// The Project menu.
///
/// A SECOND TOP-LEVEL MENU, and the first thing to need one. `Project ▸
/// Locations…` is CR-112's own spelling, and CR-110 already owes this menu
/// a second entry (`Project ▸ Structured wiring…`), so the menu is where
/// the corpus put it rather than where one item happened to land.
///
/// NO `shortcut:` ON THE ITEM, and deliberately: an accelerator would have
/// to name a `KeyBindingId`, which means a row in `kKeymap` and a place in
/// M7's generated table and in `arbitrate()`'s four conflict checks across
/// every platform. A panel opened once per project does not earn that, and
/// `session_layering_test.dart` RULE 14 counts the global bindings for
/// exactly this reason.
final class _ProjectMenu extends StatelessWidget {
  const _ProjectMenu({required this.controller, required this.onLocations});

  final MenuController controller;
  final VoidCallback onLocations;

  @override
  Widget build(BuildContext context) => MenuBar(
    children: [
      SubmenuButton(
        controller: controller,
        menuChildren: [
          MenuItemButton(
            onPressed: onLocations,
            child: const Text('Locations…'),
          ),
        ],
        child: const Text('Project'),
      ),
    ],
  );
}

/// The production [SessionPrompts]: the real dialogs, over a navigator.
///
/// It holds a `GlobalKey<NavigatorState>` rather than a `BuildContext`
/// because these are awaited across whole save operations, and a context
/// captured before an await can be unmounted by the time the dialog is
/// asked for.
final class NavigatorSessionPrompts implements SessionPrompts {
  const NavigatorSessionPrompts(this.navigatorKey);

  final GlobalKey<NavigatorState> navigatorKey;

  BuildContext? get _context => navigatorKey.currentContext;

  @override
  Future<UnsavedChangesChoice> confirmDiscard({
    required String documentName,
    int? editCount,
  }) async {
    final context = _context;
    // NO NAVIGATOR MEANS NO PROMPT, AND NO PROMPT MEANS DO NOT DISCARD.
    // The conservative answer is the only one that cannot lose work.
    if (context == null) return UnsavedChangesChoice.cancel;
    return showUnsavedChangesDialog(
      context,
      documentName: documentName,
      editCount: editCount,
    );
  }

  @override
  Future<String> showFileError(FileErrorView view) async {
    final context = _context;
    if (context == null) return view.dismissActionId;
    return showFileErrorDialog(context, view);
  }

  @override
  Future<RecoveryChoice> confirmRecovery({
    required String documentName,
    required DateTime savedAt,
    int? unsavedEditCount,
  }) async {
    final context = _context;
    // Leaving the snapshot on disk is the answer that cannot lose data.
    if (context == null) return RecoveryChoice.keepForLater;
    return showRecoveryPromptDialog(
      context,
      documentName: documentName,
      savedAt: savedAt,
      unsavedEditCount: unsavedEditCount,
    );
  }
}
