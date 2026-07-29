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
// app — see [kFileShortcuts] for why "above the whole app" and not
// "above the tab view" is a correctness requirement rather than a
// preference.
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
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rackmate/src/session/app_services.dart';
import 'package:rackmate/src/session/document_session.dart';
import 'package:rackmate/src/session/session_controller.dart';
import 'package:rackmate/src/session/session_prompts.dart';
import 'package:rackmate/src/session/starter_projects.dart';
import 'package:rackmate/src/session/window_chrome.dart';
import 'package:rackmate/src/storage/recents_store.dart';
import 'package:rackmate_core/rackmate_core.dart'
    show TextMeasurer, buildRackPresets;
import 'package:rackmate_ui/rackmate_ui.dart';

/// `Ctrl+N`.
final class NewDocumentIntent extends Intent {
  const NewDocumentIntent();
}

/// `Ctrl+O`.
final class OpenDocumentIntent extends Intent {
  const OpenDocumentIntent();
}

/// `Ctrl+S`.
final class SaveDocumentIntent extends Intent {
  const SaveDocumentIntent();
}

/// `Ctrl+Shift+S`.
final class SaveDocumentAsIntent extends Intent {
  const SaveDocumentAsIntent();
}

/// `Ctrl+1` / `Ctrl+2` / `Ctrl+4` — switch to a view by IDENTITY.
///
/// Carries the tab INDEX in the current strip, and [key] carries the
/// digit the user pressed. The two are deliberately separate: docs/04
/// §8's `Ctrl+n` names a view forever, while the index is whatever
/// position that view happens to occupy in the v1 strip. Conflating them
/// is exactly how the Schedule would drift onto `Ctrl+3` the first time
/// somebody counted the tabs.
final class SwitchViewIntent extends Intent {
  const SwitchViewIntent({required this.key, required this.tabIndex});

  /// The digit in `Ctrl+n` — 1, 2 or 4.
  final int key;

  /// Where that view sits in the v1 three-tab strip.
  final int tabIndex;
}

/// The four file bindings.
///
/// INSTALLED ON `MaterialApp`, NOT ON A WIDGET INSIDE IT, and that is a
/// correctness fix rather than a tidy-up. Flutter dispatches a key event
/// up the FOCUS chain: a `Shortcuts` widget below the app's root focus
/// scope only ever sees keys pressed while focus is inside its own
/// subtree. The rack canvas autofocuses, so Ctrl+S appeared to work — and
/// silently did nothing on the Schematic and Schedule tabs, where nothing
/// in the subtree holds focus. The document is global; its keys have to
/// be too.
const Map<ShortcutActivator, Intent>
kFileShortcuts = <ShortcutActivator, Intent>{
  SingleActivator(LogicalKeyboardKey.keyN, control: true): NewDocumentIntent(),
  SingleActivator(LogicalKeyboardKey.keyO, control: true): OpenDocumentIntent(),
  SingleActivator(LogicalKeyboardKey.keyS, control: true): SaveDocumentIntent(),
  SingleActivator(LogicalKeyboardKey.keyS, control: true, shift: true):
      SaveDocumentAsIntent(),
};

/// docs/04 §8's view switch, `Ctrl+1..4`, as the v1 strip renders it.
///
/// THREE ENTRIES, AND `Ctrl+3` IS NOT ONE OF THEM. See this file's header:
/// CR-071 reserves `Ctrl+3` for the interactive Rear Panel view, which is
/// v1.1, and docs/04 §8 line 456 forbids rebinding the Schedule onto it.
/// An entry for `Ctrl+3` here would either advertise a view that does not
/// exist or move the Schedule off the key it keeps "in v1 and forever".
const Map<ShortcutActivator, Intent>
kViewShortcuts = <ShortcutActivator, Intent>{
  SingleActivator(LogicalKeyboardKey.digit1, control: true): SwitchViewIntent(
    key: 1,
    tabIndex: 0,
  ),
  SingleActivator(LogicalKeyboardKey.digit2, control: true): SwitchViewIntent(
    key: 2,
    tabIndex: 1,
  ),
  SingleActivator(LogicalKeyboardKey.digit4, control: true): SwitchViewIntent(
    key: 4,
    tabIndex: 2,
  ),
};

/// The handler for [kViewShortcuts].
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
/// the other two — the exact bug [kFileShortcuts] documents.
Map<Type, Action<Intent>> buildViewActions(GlobalKey<AppShellState> shell) =>
    <Type, Action<Intent>>{
      SwitchViewIntent: CallbackAction<SwitchViewIntent>(
        onInvoke: (intent) {
          shell.currentState?.switchToTab(intent.tabIndex);
          return null;
        },
      ),
    };

/// The handlers for [kFileShortcuts], bound to one session.
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
    _tabController = TabController(length: 3, vsync: this);
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
    _tabController.dispose();
    super.dispose();
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
  /// [kFileShortcuts] is exactly four, `session_layering_test.dart` RULE
  /// 14 asserts it, and that rule exists so a fifth cannot arrive without
  /// the decision being taken again.
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
    );
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
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyN,
                control: true,
              ),
              onPressed: () => unawaited(onNew()),
              child: const Text('New'),
            ),
            MenuItemButton(
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyO,
                control: true,
              ),
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
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyS,
                control: true,
              ),
              onPressed: () => unawaited(onSave()),
              child: const Text('Save'),
            ),
            MenuItemButton(
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyS,
                control: true,
                shift: true,
              ),
              onPressed: () => unawaited(onSaveAs()),
              child: const Text('Save As…'),
            ),
            // NO `shortcut:` — and that is a decision, not an omission.
            // docs/08 §8.1 gives export `Ctrl+P`, but
            // `session_layering_test.dart` RULE 14 asserts exactly four
            // bindings and eight activators precisely so the file group
            // cannot grow a fifth member without that being re-taken.
            // Declaring one here would ALSO advertise a key nothing
            // listens for, which is the other half of what that rule
            // protects.
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
