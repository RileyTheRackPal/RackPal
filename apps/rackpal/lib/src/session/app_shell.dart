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
import 'package:rackpal/src/session/app_services.dart';
import 'package:rackpal/src/session/csv_import_actions.dart';
import 'package:rackpal/src/session/device_builder_actions.dart';
import 'package:rackpal/src/session/document_session.dart';
import 'package:rackpal/src/session/drop_entry_actions.dart';
import 'package:rackpal/src/session/locations_actions.dart';
import 'package:rackpal/src/session/outlet_plate_actions.dart';
import 'package:rackpal/src/session/outlet_template_actions.dart';
import 'package:rackpal/src/session/pathway_actions.dart';
import 'package:rackpal/src/session/session_controller.dart';
import 'package:rackpal/src/session/session_prompts.dart';
import 'package:rackpal/src/session/starter_projects.dart';
import 'package:rackpal/src/session/structure_edit_actions.dart';
import 'package:rackpal/src/session/structure_matrix_actions.dart';
import 'package:rackpal/src/session/window_chrome.dart';
import 'package:rackpal/src/storage/library_shelf.dart';
import 'package:rackpal/src/storage/recents_store.dart';
import 'package:rackpal_core/rackpal_core.dart'
    show
        Err,
        LabelKey,
        LoadedLibrary,
        LocationRemovalPlan,
        RackDocument,
        TemplateBody,
        TemplateId,
        TextMeasurer,
        Uuid,
        addOutletRemoval,
        addStructureRemoval,
        addTemplateRemoval,
        buildPlaceableTemplates,
        buildRackPresets,
        copyTemplateBody,
        planOutletRemoval,
        planStructureRemoval,
        planTemplateRemoval,
        resolveLatestTemplate;
import 'package:rackpal_ui/rackpal_ui.dart';

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
///
/// DR-091 §11.90 REORDERED THE STRIP AND DELIBERATELY DID NOT RENUMBER
/// THE KEYS. The strip now runs in job order, Locations, Device Manager,
/// Rack, Structured Wiring, Schematic, Schedule, so every INDEX below
/// moved; every KEY is exactly what it was. `Ctrl+1` is still the Rack,
/// `Ctrl+2` still the Schematic, `Ctrl+4` still the Schedule.
///
/// That is §11.90.4 in one line of data: the view set is not final until
/// Plan lands (DR-029), and renumbering once against a settled set costs
/// one relearning where renumbering now costs two. This map being the
/// only place the two systems meet is what makes the deferral cheap.
///
/// PLAN IS ABSENT FROM THE STRIP, not present and empty. CR-071 does
/// exactly this for the Rear Panel: docs/05 §827 says the binding is an
/// unbound no-op and *"the tab is absent from the strip"*. A tab that
/// opens onto nothing is the untruth `shell_tabs_test.dart` already
/// names, pointing the other way.
const Map<int, int> kViewKeyToTabIndex = <int, int>{1: 2, 2: 4, 4: 6};

/// The strip, in DR-091 §11.90.3's order, and the group each view is in.
///
/// THE GROUPS ARE NOT DECORATION. Three tabs need no structure and six
/// do; the divider between them is what stops the strip reading as one
/// undifferentiated run, which is the thing the amendment set out to fix.
enum ShellView {
  locations('Locations', Icons.place_outlined, ShellViewGroup.project),
  deviceManager(
    'Device Manager',
    Icons.developer_board_outlined,
    ShellViewGroup.project,
  ),
  rack('Rack', Icons.dashboard_outlined, ShellViewGroup.design),
  structuredWiring(
    'Structured Wiring',
    Icons.lan_outlined,
    ShellViewGroup.design,
  ),
  schematic('Schematic', Icons.polyline_outlined, ShellViewGroup.design),
  // THE SEVENTH TAB, AND DR-091 HAS BEEN WAITING FOR IT. That ruling
  // keeps Plan out of the strip "until it is built, rather than adding a
  // seventh tab onto nothing"; PLAN-E/5 is the chapter that earns it, and
  // DR-143 §11.142.1 is why it could not have arrived one chapter sooner
  // (nothing could put a floorplan in a project at all).
  //
  // POSITION 6, AFTER THE SCHEMATIC, WHICH IS §11.90.3's OWN TABLE. The
  // job sentence there is "interconnect it, MARK WHERE IT PHYSICALLY
  // SITS, hand over the paperwork", so the plan comes after the wiring
  // and before the deliverable. A first draft of this line reasoned its
  // own job order and put Plan before the Schematic, which is a ruling
  // re-argued rather than read.
  plan('Plan', Icons.map_outlined, ShellViewGroup.design),
  schedule('Schedule', Icons.table_rows_outlined, ShellViewGroup.deliverable);

  const ShellView(this.label, this.icon, this.group);

  final String label;
  final IconData icon;
  final ShellViewGroup group;
}

/// What a view is FOR, which is what the strip's dividers separate.
enum ShellViewGroup { project, design, deliverable }

/// Where the Schematic sits in THIS milestone's strip.
///
/// READ OUT OF [kViewKeyToTabIndex] rather than written as `1`, because
/// that map is the file's own statement that the ordinal is a property of
/// the strip and not of the view. CR-105's chip and AC-048's coach mark
/// both need to name this tab; neither may hard-code a position that
/// CR-071's `Ctrl+3` Rear Panel will move in v1.1.
final int _kSchematicTabIndex = kViewKeyToTabIndex[2]!;

/// The Device Manager's ordinal in the view strip, door 2's destination.
///
/// READ OFF THE ENUM rather than written as `1`, for the same reason
/// `_kSchematicTabIndex` is read out of the map: the strip's order is
/// DR-091 §11.90.3's and a view inserted before this one must not silently
/// send door 2 to the Locations tab.
final int _kDeviceManagerTabIndex = ShellView.deviceManager.index;

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

/// The handlers for undo and redo, which are GLOBAL bindings since
/// DR-159 §11.158.3.
///
/// ═════════════════════════════════════════════════════════════════════
/// INSTALLED AT THE APP ROOT, AND THAT IS THE WHOLE FIX
/// ═════════════════════════════════════════════════════════════════════
/// `UndoIntent` and `RedoIntent` had exactly ONE handler in the entire
/// tree, inside `RackCanvasScreen`'s own `Shortcuts`, so `Ctrl+Z` did
/// nothing on six of the seven tabs. The intent was always right and only
/// the installation point was wrong: that handler's own comment says the
/// key is document-global, and this is `buildFileActions`' post-mortem
/// applied to the pair of keys it did not cover.
///
/// ═════════════════════════════════════════════════════════════════════
/// THIS IS THE FALLBACK, NOT THE ONLY HANDLER
/// ═════════════════════════════════════════════════════════════════════
/// Flutter resolves an `Action` from the FOCUSED context upward, so a
/// nearer one wins. Two screens keep their own on purpose (§11.158.4,
/// §11.158.5):
///
///   * `RackCanvasScreen`, because `undoLast` returns the selection as it
///     was and only that screen can restore it;
///   * `DeviceBuilderScreen`, because CR-106 gives it a second undo stack
///     and `Ctrl+Z` must reach THAT one while it is open.
///
/// So this runs for every surface that has neither, which is most of
/// them.
Map<Type, Action<Intent>> buildUndoActions(GlobalKey<AppShellState> shell) =>
    <Type, Action<Intent>>{
      UndoIntent: CallbackAction<UndoIntent>(
        onInvoke: (_) {
          shell.currentState?.undoFromShell();
          return null;
        },
      ),
      RedoIntent: CallbackAction<RedoIntent>(
        onInvoke: (_) {
          shell.currentState?.redoFromShell();
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

  /// Door 2's subject: the template the Device Manager is editing, or null
  /// for the blank draft it opens on (DR-099 §11.98).
  TemplateId? _editingTemplateId;

  /// Whether the Device Manager is authoring a NEW template rather than
  /// showing the browser (`#243`). See [_deviceManagerTab]'s three states.
  bool _authoringNew = false;

  /// The starred template ids (`#245`, DR-104 §11.103.4), held here so
  /// both the browser and the palette read one value.
  ///
  /// Seeded from `prefsStore.current` at startup and written back on
  /// every toggle. A DEGRADED SESSION HAS NO STORE, and then favourites
  /// work for the session and are not persisted, which is the same
  /// bargain the schematic coach mark already takes: the feature keeps
  /// working and the memory does not.
  Set<String> _favourites = const <String>{};

  /// Flips a star and persists it (`#245`).
  void _toggleFavourite(String templateId) {
    final store = _services.prefsStore;
    final next = store == null
        ? <String>{
            for (final id in _favourites)
              if (id != templateId) id,
            if (!_favourites.contains(templateId)) templateId,
          }
        : store.current.withFavouriteToggled(templateId).favouriteTemplateIds;
    setState(() => _favourites = next);
    if (store == null) return;
    // LOAD-MODIFY-WRITE THROUGH THE STORE'S OWN CACHE, for
    // `_dismissFilterCoachMark`'s reason: anything else can revert the
    // window geometry or `lastSaveDirectory`.
    unawaited(store.save(store.current.withFavouriteToggled(templateId)));
  }

  /// Whether the Device Manager's ONE draft has unsaved work, reported by
  /// the builder off its own session counter.
  ///
  /// THE SHELL CANNOT ASK, which is why this is pushed rather than pulled:
  /// `TemplateEditSession` is private to the builder's State and is
  /// `late final`, so loading another template means a new `key` and a
  /// destroyed State. Door 2 has to know BEFORE it swaps that key.
  bool _builderDirty = false;

  /// What the `IndexedStack` is showing. Mirrors `_tabController.index`,
  /// pushed by [_onTabChanged] rather than read during build, because a
  /// `TabController` notifies mid-animation and a body that swapped on
  /// the first tick would change under the animation.
  final MenuController _fileMenu = MenuController();

  /// CR-105's signpost, carried across the strip.
  ///
  /// THE SHELL OWNS IT BECAUSE THE SHELL IS THE ONLY THING THAT CAN. The
  /// elevation raises "show me this device"; only this class can change
  /// tabs; the schematic answers it. Neither tab may reach the other, and
  /// `rackpal_ui` deliberately contains no shell.
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
  /// Dismissing "RackPal cannot write to its data folder" must not also
  /// dismiss a DIFFERENT warning that arrives an hour later saying
  /// autosave has stopped — the user has not read that one. Keying the
  /// dismissal on the message is what makes a new fact reach them.
  String? _dismissedWarning;

  late bool _startCardVisible = widget.showStartCard;

  /// The shelf as last read (`#242`), in the two shapes the palette
  /// takes. Held rather than recomputed per build because
  /// `RackCanvasScreen` compares [_libraries] by IDENTITY to decide
  /// whether its palette memo is stale, so a list rebuilt every frame
  /// would rebuild the row list every frame with it.
  ///
  /// The undecoded `ShelfLibrary` list is deliberately NOT kept: nothing
  /// reads it, and a field held "in case" is a field that goes stale
  /// quietly. `LibraryIo.shelf()` returns it whenever somebody needs the
  /// typed faults again.
  List<LoadedLibrary> _libraries = const [];
  List<UnreadableLibrary> _unreadableLibraries = const [];

  AppServices get _services => widget.services;

  @override
  void initState() {
    super.initState();
    // ORDER IS NOT DEFAULT, and DR-091 §11.90.3 rules only the order.
    // The strip runs in JOB order, which teaches the workflow to someone
    // meeting it; the view a person LANDS on is a different question,
    // because most openings are a return to work in progress rather than
    // a first pass through a new site. Opening onto Locations every time
    // would make a returning user's first act a tab switch.
    //
    // So the app opens on the Rack, exactly as it did before the strip
    // was reordered. `kViewKeyToTabIndex[1]` rather than a literal: the
    // Rack's ordinal is a property of the strip, and this file already
    // refuses to hard-code the Schematic's for the same reason.
    _tabController = TabController(
      length: ShellView.values.length,
      initialIndex: kViewKeyToTabIndex[1]!,
      vsync: this,
    )..addListener(_onTabChanged);
    // THE SHELF IS READ ONCE AT STARTUP AND AFTER EVERY IMPORT, and
    // never on a build. It is filesystem work, the folder changes only
    // when this app or the user's file manager changes it, and a palette
    // that stats a directory on every frame is the shape this repository
    // already fixed once in `DocumentMemo`'s own header.
    unawaited(_reloadLibraryShelf());
    // Favourites are per USER, so they are read once at startup rather
    // than per document (DR-104 §11.103.4).
    _favourites =
        _services.prefsStore?.current.favouriteTemplateIds ?? const <String>{};
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
    _planImages.dispose();
    _planArm.dispose();
    _planSelection.dispose();
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

  /// The Device Builder's own undo stack, while that screen is showing
  /// (DR-159 §11.158.5). Null whenever it is not.
  ///
  /// **CLEARED HERE RATHER THAN REPORTED FROM `dispose`.** That screen
  /// cannot notify from `dispose` without throwing "setState() called
  /// when widget tree was locked", which its own comment records. It does
  /// not have to: this shell is what decides to stop showing it, so this
  /// shell is what clears the field, in the same `setState`.
  UndoTarget? _builderUndo;

  /// Whether the Device Manager tab is showing the EDITOR rather than the
  /// browser. The one place that question is asked, so the tab body and
  /// the undo routing cannot come to disagree about it.
  bool get _builderIsShowing => _editingTemplateId != null || _authoringNew;

  /// The stack the Edit menu describes and the shell's own `Ctrl+Z` acts
  /// on: the builder's while it is open, the document's otherwise.
  UndoTarget get activeUndoTarget {
    final builder = _builderUndo;
    if (_builderIsShowing && builder != null) return builder;
    final controller = _services.session.controller;
    return UndoTarget(
      canUndo: controller.undo.canUndo,
      canRedo: controller.undo.canRedo,
      undoLabelKey: controller.undo.undoLabelKey,
      redoLabelKey: controller.undo.redoLabelKey,
      undo: controller.undoLast,
      redo: controller.redoLast,
    );
  }

  /// `Ctrl+Z` arriving at the app root. Public so `buildUndoActions` can
  /// reach it through the shell key.
  ///
  /// ═══════════════════════════════════════════════════════════════════
  /// THERE IS NO TEXT-FIELD GUARD HERE, AND THAT IS DELIBERATE
  /// ═══════════════════════════════════════════════════════════════════
  /// `RackCanvasScreen` gates its own undo on `!_textFieldHasFocus` and
  /// has since M1. The first draft of this method copied it, and the copy
  /// was redundant AND harmful.
  ///
  /// **REDUNDANT**, because `DefaultTextEditingShortcuts` sits BELOW the
  /// app's own `Shortcuts` and therefore nearer any focused field: it
  /// maps `Ctrl+Z` to `UndoTextIntent`, `EditableText` handles it, and
  /// the key is consumed. By the time `UndoIntent` reaches this method,
  /// no text field claimed it, which is the same fact the guard was
  /// asking about and a more reliable way of asking.
  ///
  /// **HARMFUL**, because a field can decline on purpose. The Structured
  /// Wiring tab's `Add drops` box autofocuses and clears itself on every
  /// submit, so it forwards `Ctrl+Z` to the document while it is empty
  /// (DR-159 §11.158.8). A guard here would have caught that forward and
  /// thrown it away, leaving the key dead on the one tab whose primary
  /// verb is bulk data entry.
  void undoFromShell() => activeUndoTarget.undo();

  void redoFromShell() => activeUndoTarget.redo();

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

  /// `File ▸ Export device template…` (DR-101 §11.100.4).
  ///
  /// The chooser is passed in rather than reached for inside the action,
  /// so the sequence is testable against a scripted answer exactly as the
  /// save and close sequences are (`session_prompts.dart`).
  Future<void> _exportTemplate() async {
    await _services.templateIo.export(
      (rows) async => showExportTemplateChooser(context, templates: rows),
    );
  }

  /// `File ▸ Import device template…`.
  Future<void> _importTemplate() async {
    await _services.templateIo.import(
      (plan) async => showImportTemplateConfirm(context, plan: plan),
    );
  }

  /// `File ▸ Import floorplan…` (DR-143 §11.142, PLAN-E/5).
  ///
  /// ═══════════════════════════════════════════════════════════════════
  /// THE CALLER `PLAN-D` NEVER GOT
  /// ═══════════════════════════════════════════════════════════════════
  /// Every step of the import was built and tested at `PLAN-D` and had
  /// zero call sites in `lib/`, so `AddPlanUnderlayCommand` had no
  /// producer and no project could hold a floorplan at all. This method
  /// is that producer.
  ///
  /// CANCELLED AND REFUSED SAY DIFFERENT THINGS, and only one of them
  /// speaks. `null` is a closed dialog, from either the file picker or
  /// the PDF page grid, and a person who closed a grid has not hit an
  /// error. An `Err` is a file this product read and declined, and its
  /// own `toString` is written for a person: the caps say their numbers
  /// and `PdfHasNoLiftablePageError` says the page count.
  Future<void> _importFloorplan() async {
    final result = await _services.floorplanIo.import(
      pickPage: (pages, fileName) async {
        if (!mounted) return null;
        return pickPdfPage(context, pages: pages, fileName: fileName);
      },
    );
    if (result case Err(:final error)) _showRefusal('$error');
  }

  /// `File ▸ Export device library…` (`#240`).
  Future<void> _exportLibrary() async {
    await _services.libraryIo.export(
      (candidates) async => showExportLibrary(context, candidates: candidates),
    );
  }

  /// `File ▸ Import device library…`.
  Future<void> _importLibrary() async {
    final imported = await _services.libraryIo.import(
      (preview) async => showImportLibraryConfirm(context, preview: preview),
    );
    // THE PALETTE UPDATES WITHOUT A REOPEN, which is the whole point of
    // `#242` landing in the same milestone as `#240`. Until this line an
    // imported library sat on the shelf and nothing read it.
    if (imported) await _reloadLibraryShelf();
  }

  /// Re-reads the shelf into [_libraries] (`#242`, DR-102 §11.101.3).
  ///
  /// **A FRESH LIST EVERY TIME, and `RackCanvasScreen` depends on it**:
  /// its palette memo is keyed on the document, and it clears that memo
  /// when the `libraries` list is not IDENTICAL to the previous one. A
  /// mutated-in-place list would leave the palette showing what the shelf
  /// held before the import.
  Future<void> _reloadLibraryShelf() async {
    final shelf = await _services.libraryIo.shelf();
    if (!mounted) return;
    setState(() {
      _libraries = loadedLibrariesOf(shelf);
      _unreadableLibraries = [
        for (final entry in shelf)
          if (entry.fault case final fault?)
            UnreadableLibrary(
              id: entry.id,
              // THE ERROR OBJECT RENDERED HERE AND NOT IN THE SERVICE,
              // which keeps the typed fault available to anything else
              // that wants the numbers (DR-103 §11.102.7). `toString` on
              // these is written for a person: `NewerRmdaSchemaError`
              // says which version it is and which this build reads.
              reason: '$fault',
            ),
      ];
    });
  }

  Future<void> _openRecent(String path) async {
    if (await _services.controller.openPath(path)) _dismissStartCard();
  }

  /// Opens the project settings editor (`#805`, RJ-012, AC-054).
  ///
  /// The dialog builds commands; this decides which stack they land on,
  /// exactly as the batch inspector, the nudge canvas and the media-type
  /// editor do. Settings are a field of `RackDocument`, so they go on the
  /// DOCUMENT stack and are undoable, unlike a library operation
  /// (docs/03 §5.6).
  Future<void> _openProjectSettings() async {
    final session = _services.session;
    await showProjectSettingsDialog(
      context,
      doc: session.document,
      // FOR ONE SECTION ONLY (`#879`): a `RuleOverride` carries a reason,
      // an author and a date, and all three print on `T0.02`. Nothing
      // else in that dialog signs anything.
      clock: session.controller.clock,
      actor: session.controller.actor,
      onEdit: (commands) {
        if (commands.isEmpty) return;
        // NULL: THE FIRST CHILD NAMES IT, read after it has applied
        // (DR-156 §11.155.2). This passed `commands.first.label`, which is
        // the same intent evaluated a moment too early; no command here
        // decides its label from the document today, so this was the
        // defect's SHAPE without its symptom.
        session.controller.transact(null, (tx) {
          for (final command in commands) {
            tx.add(command);
          }
        });
      },
    );
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
            _AppMenuBar(
              controller: _fileMenu,
              recents: _recents,
              recentStates: _recentStates,
              onOpenMenu: _refreshRecents,
              onNew: _newDocument,
              onOpen: _openDocument,
              onSave: _save,
              onSaveAs: _saveAs,
              onExportPdf: _exportPdf,
              onExportTemplate: _exportTemplate,
              onImportTemplate: _importTemplate,
              onExportLibrary: _exportLibrary,
              onImportLibrary: _importLibrary,
              onImportFloorplan: _importFloorplan,
              onProjectSettings: _openProjectSettings,
              onOpenRecent: _openRecent,
              undoTarget: activeUndoTarget,
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
            // NO CONSTRUCTION GLYPH ON ANY TAB. The marker said which
            // view did nothing yet; the Schedule lost it at M2-B and the
            // Schematic at M2-E, because "a tab that works while still
            // wearing the 'not built' marker is the same class of untruth
            // as the panel this replaced, pointing the other way"
            // (shell_tabs_test.dart). DR-091 keeps that rule by keeping
            // PLAN OUT of the strip until it is built, rather than adding
            // a seventh tab onto nothing.
            : TabBar(
                controller: _tabController,
                tabs: [
                  for (final view in ShellView.values)
                    Tab(
                      icon: Icon(view.icon),
                      // THE DIVIDER IS DRAWN ON THE TAB, not between two
                      // of them, because `TabBar` takes a flat list and
                      // has nowhere to put a separator. A leading rule on
                      // the first tab of each group after the first is
                      // the same mark in the only place the widget
                      // offers.
                      text: view.label,
                    ),
                ],
                dividerColor: Theme.of(context).colorScheme.outline,
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
            // `TabBarView` is a `PageView` and takes page-scroll physics
            // by default, so a horizontal wheel or a two-finger sideways
            // trackpad swipe drags the whole view sideways. On a phone
            // that is the affordance; here it is a collision, because
            // BOTH canvases already claim exactly that gesture for
            // panning.
            //
            // AN IndexedStack WAS TRIED AT DR-091 AND REVERTED. It keeps
            // every child mounted, which is what the Device Manager's
            // draft wants, but mounting all six at once puts every hidden
            // view's text in front of every global finder in the suite.
            // The draft is kept by `AutomaticKeepAliveClientMixin` on the
            // one screen that needs it instead, which is the standard
            // mechanism and touches nothing else.
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _locationsTab(session),
              _deviceManagerTab(session),
              _rackTab(session),
              _structuredWiringTab(session),
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
              // POSITION 6, BEFORE THE SCHEDULE (DR-091 §11.90.3). Every
              // piece of this view was built and unreachable: the canvas
              // and its two gestures (PLAN-E/2), the arm mode and its
              // chip (PLAN-E/3), the strip and armCarrierDrag (PLAN-E/4),
              // and the importer that could put anything in it at all
              // (PLAN-D, DR-143). This line is what makes them true.
              _planTab(session),
              // here is gone rather than softened. Its copy said "no code
              // turns a Link into a row", which was true when it was
              // written and is false now that
              // `rackpal_core/derived/schedule.dart` exists — and the
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

  // ═══════════════════════════════════════════════════════════════════
  // THE THREE VIEWS DR-091 §11.90 PROMOTED
  // ═══════════════════════════════════════════════════════════════════
  // Each builds the SAME screen the dialog built, with the SAME actions.
  // What changes is the host, and the one difference a host makes is
  // whether there is anything to close: `onClose`/`onDone` is null here,
  // and each screen hides its dismissal control rather than offering a
  // button that would pop the application's own route.
  //
  // KEYED ON THE CONTROLLER, as the rack and schedule tabs are. Replacing
  // the document must reset a selection, a draft or an expanded tree,
  // because each of those is an answer about a document and a replacement
  // is a different one.

  Widget _locationsTab(DocumentSession session) => LocationsPanel(
    key: ValueKey(session.controller),
    doc: session.document,
    actions: buildLocationsPanelActions(
      controller: session.controller,
      confirmRemoval: _confirmLocationRemoval,
      onRefuse: _showRefusal,
    ),
  );

  Widget _structuredWiringTab(DocumentSession session) => StructureEditorScreen(
    key: ValueKey(session.controller),
    // A CALLBACK AND NOT A VALUE, for the reason the dialog gave: nine
    // drops committed by the first line change the document the second
    // must plan against, and a captured reference would offer labels the
    // first line just spent.
    currentDoc: () => session.document,
    actions: StructureEditorActions(
      dropEntry: buildDropEntryActions(controller: session.controller),
      onAddOutlet: (bodyId) => unawaited(_openOutletPicker(bodyId)),
      onPinOnPlan: _armPinFromDropTable,
      onEdit: buildStructureEditAction(controller: session.controller),
      onSetCount: buildStructureMatrixAction(controller: session.controller),
      onEditPathways: buildPathwayEditAction(controller: session.controller),
      onAddPathway: buildPathwayAddAction(controller: session.controller),
      onRemovePathway: buildPathwayRemoveAction(
        controller: session.controller,
      ),
      onImportCsv: (bodyId) => _runCsvImport(session, bodyId),
      onRunMediaTypeCommands: buildMediaTypeAction(
        controller: session.controller,
      ),
      onRemoveStructure: (bodyId) =>
          unawaited(_removeStructure(session, bodyId)),
      outlets: buildOutletsActions(
        controller: session.controller,
        onRemove: (outletId) => unawaited(_removeOutlet(session, outletId)),
      ),
    ),
  );

  /// Removes one wall plate, with the home runs that land on it (`#877`,
  /// DR-160 §11.159.2).
  ///
  /// **THE COUNTS AND THE REMOVAL READ ONE OBJECT**, which is
  /// `delete_location_dialog.dart`'s rule and `_removeTemplate`'s: a
  /// dialog that said "3 cables" and removed four would be worse than no
  /// dialog.
  ///
  /// **A BARE PLATE IS REMOVED WITH NO PROMPT AT ALL.**
  /// `confirmOutletRemoval` returns true without showing anything when the
  /// plan costs nothing (DR-013 §11.13.2), so the gesture stays one click
  /// in the case where a prompt would only teach somebody to click through
  /// prompts.
  Future<void> _removeOutlet(DocumentSession session, Uuid outletId) async {
    final controller = session.controller;
    final plan = planOutletRemoval(controller.doc, outletId);
    if (plan.isEmpty) return;
    // Read BEFORE the delete, obviously, but also before the
    // confirmation: the dialog is describing a document that still has
    // this plate in it.
    final designation = controller.doc.outlets[outletId]?.designation ?? '';

    final confirmed = await confirmOutletRemoval(
      context,
      plan: plan,
      designation: designation,
    );
    if (!confirmed || !mounted) return;

    // RE-PLANNED AFTER THE AWAIT, on `_removeTemplate`'s rule: the
    // document is not frozen while a dialog is open, and an undo from the
    // Edit menu could have moved it. The plan the person ANSWERED is the
    // one above; the plan that runs is this one.
    final live = planOutletRemoval(controller.doc, outletId);
    if (live.isEmpty) return;
    controller.transact(
      LabelKey.removeOutlet,
      (tx) => addOutletRemoval(tx, live),
    );
    setState(() {});
  }

  /// Removes a whole Structure body, with its plates and every home run
  /// out of it (`#877`, DR-160 §11.159.3).
  ///
  /// **THE LABEL IS `removeStructure` AND NOT `removeLink`**, on
  /// `_removeTemplate`'s reasoning (§11.159.7): what the person did was
  /// get rid of a panel, and the plates and cables are a consequence of
  /// it.
  Future<void> _removeStructure(DocumentSession session, Uuid bodyId) async {
    final controller = session.controller;
    final plan = planStructureRemoval(controller.doc, bodyId);
    if (plan.isEmpty) return;

    final confirmed = await confirmStructureRemoval(
      context,
      plan: plan,
      name: _structureName(controller.doc, bodyId),
    );
    if (!confirmed || !mounted) return;

    final live = planStructureRemoval(controller.doc, bodyId);
    if (live.isEmpty) return;
    controller.transact(
      LabelKey.removeStructure,
      (tx) => addStructureRemoval(tx, live),
    );
    setState(() {});
  }

  /// `STR-1 · Media Panel`, exactly as the editor header prints it.
  ///
  /// THE DESIGNATOR IS THE DEVICE'S, not the body's, which is
  /// `_EditorHeader._subtitle`'s rule: a `StructureBody` has none, so
  /// there is no second copy of it to go stale.
  static String _structureName(RackDocument doc, Uuid bodyId) {
    final body = doc.structures[bodyId];
    if (body == null) return 'this Structure';
    final designator = doc.devices[body.deviceId]?.designator ?? '';
    final title = body.title.trim();
    if (designator.isEmpty) return title.isEmpty ? 'this Structure' : title;
    return title.isEmpty ? designator : '$designator · $title';
  }

  /// The Device Manager. DR-091 §11.90.5 renamed it from `New device
  /// template`, because a tab names a place and that named an action.
  ///
  /// IT STARTS ON A BLANK BODY WITH `Generic` ALREADY IN IT (DR-056,
  /// §11.55), exactly as the dialog did: `Generic` is the trade's own
  /// token for *unspecified / by others*, so pre-filling it is the
  /// industry's spelling of an unknown rather than a fabricated value
  /// under G4. `model` stays blank by the same ruling.
  ///
  /// THE DRAFT LIVES AS LONG AS THE VIEW DOES, which is what the
  /// `IndexedStack` above buys and why it is there rather than a
  /// `TabBarView`.
  /// `Ctrl+2`: the browser, or the editor when one is open (`#243`,
  /// DR-104 §11.103.2).
  ///
  /// **THREE STATES, AND THE THIRD IS WHY A FLAG EXISTS.** Before `#243`
  /// this tab had two: `_editingTemplateId` set meant door 2's editor,
  /// and null meant a blank builder. Null now means the BROWSER, so
  /// "author a new one" needs a way to say so that is not "no template
  /// is selected". [_authoringNew] is that, and it is cleared whenever
  /// the browser is shown again.
  Widget _deviceManagerTab(DocumentSession session) {
    final doc = session.controller.doc;
    if (_editingTemplateId == null && !_authoringNew) {
      return DeviceBrowserScreen(
        // The same merged, source-tagged list the palette lists
        // (DR-102 §11.101.3), so the two surfaces cannot come to
        // disagree about what this project can place.
        templates: buildPlaceableTemplates(doc, libraries: _libraries),
        document: doc,
        registries: doc.registries,
        unreadableLibraries: _unreadableLibraries,
        favourites: _favourites,
        onToggleFavourite: _toggleFavourite,
        // LOAD-BEARING, not convenient. There is no menu route to
        // authoring a template: this tab was the only one, so the
        // browser either carries it or the capability is gone
        // (DR-104 §11.103.2's corrected clause).
        onNew: () => setState(() => _authoringNew = true),
        onEdit: _openTemplateForEditing,
        onRemove: (id) => unawaited(_removeTemplate(session, id)),
      );
    }
    // DOOR 2's SUBJECT, when one was asked for. `resolveLatestTemplate`
    // rather than the pinned version the device carries: door 2 edits THE
    // TEMPLATE, and editing anything but its newest version would fork
    // from a body somebody has already superseded.
    final editing = _editingTemplateId;
    final snapshot = editing == null
        ? null
        : resolveLatestTemplate(doc, editing.v);
    return DeviceBuilderScreen(
      measurer: widget.measurer,
      // KEYED ON THE CONTROLLER **AND** THE TEMPLATE, and the second half
      // is what makes door 2 work at all: `TemplateEditSession` is
      // `late final`, so handing this screen a different `template` on the
      // same `State` would be ignored and the user would arrive at the
      // Device Manager still looking at the old draft. A new key builds a
      // fresh State. That is also precisely why DR-099 §11.98.4 refuses on
      // a dirty draft: the swap destroys it.
      key: ValueKey((session.controller, editing)),
      template: snapshot == null
          ? TemplateBody(manufacturer: 'Generic', model: '', displayName: '')
          : copyTemplateBody(snapshot.body),
      onDirtyChanged: (dirty) {
        if (mounted) setState(() => _builderDirty = dirty);
      },
      // ITS OWN STACK, HANDED UP (DR-159 §11.158.5). The shell's global
      // `Ctrl+Z` and the Edit menu both act on whatever this reports
      // while the editor is showing, so the key reaches the template's
      // stack and the menu names a template act.
      onUndoTargetChanged: (target) {
        if (mounted) setState(() => _builderUndo = target);
      },
      // SAVE-AND-CLOSE RETURNS TO THE BROWSER (`#243`). The draft is
      // saved by definition on this path, so nothing is lost, and this
      // is also the first thing ever to clear `_editingTemplateId`:
      // before `#243` door 2 left the tab pinned to one template for the
      // rest of the session, because there was nowhere else for it to go.
      //
      // **THERE IS NO DISCARD-AND-RETURN ROUTE YET, AND THAT IS A GAP
      // RATHER THAN A DECISION.** Going back with a dirty draft is
      // exactly the case DR-091 §11.90.6 protects with `wantKeepAlive`:
      // the builder holds an edit SESSION, not a view, so swapping it
      // for the browser destroys the copy that makes closing without
      // saving a complete undo. It needs the refusal
      // `_openTemplateForEditing` already spells, and it is filed rather
      // than improvised here.
      onDone: () => setState(() {
        _editingTemplateId = null;
        _authoringNew = false;
      }),
      actions: buildDeviceBuilderActions(
        controller: session.controller,
        prefs: _services.prefsStore,
        // NON-NULL IS WHAT MAKES SAVE A FORK RATHER THAN A NEW TEMPLATE.
        // With `editing` set, `onSave` reuses the id and `nextTemplateVersion`
        // gives it `version + 1`; with it null the save mints a fresh id.
        editing: snapshot == null ? null : editing,
      ),
      // THE PROJECT'S OWN REGISTRIES AND FORMAT, so the port grid prints
      // `HDMI Type A` where the model holds `conn.hdmi_a` and previews the
      // designators THIS project would allocate (CR-042).
      registries: doc.registries,
      portDesignatorFormat: doc.settings.portDesignatorFormat,
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

  /// `Project ▸ Structured wiring…` — docs/07 §4's editor (M3-C/2,
  /// AC-048).
  ///
  /// THE LABEL IS CR-110'S OWN WORDS, not a paraphrase. That ruling says
  /// a `StructureBody` is created from `Project ▸ Structured wiring…` and
  /// docs/02 §6 and docs/07 §3 both repeat it; this shipped as
  /// `Structure…` for one commit and was corrected by reading the ruling
  /// rather than the neighbouring code.
  ///
  /// IT REPLACES TWO MENU ITEMS RATHER THAN JOINING THEM. `Add drops…`
  /// (M3-C/1) and `Add outlet…` (M3-C/5) each shipped with a comment
  /// saying it was on this menu only until the editor existed and would
  /// leave when it did. It exists, so they are gone: quick add is the bar
  /// across the top of the table and `Add outlet` is the button under it,
  /// which is where §4 draws both. Two routes to one surface is two
  /// things to keep true.
  ///
  /// `currentDoc` is a CALLBACK and not a value. Nine drops committed by
  /// the first line change the document the second line must plan
  /// against; a captured reference would offer labels the first line just
  /// spent.

  /// docs/06's Device Builder, from `Project ▸ New device template…`
  /// (M4-D, #175).
  ///
  /// STARTS FROM A BLANK BODY WITH `Generic` ALREADY IN IT (DR-056,
  /// §11.55): `Generic` is the trade's standard token for *unspecified /
  /// by others* in a manufacturer column, so pre-filling it is the
  /// industry's own spelling of what an unknown prints rather than a
  /// fabricated value under G4. `model` is NOT pre-filled, by the same
  /// ruling: no trade convention was offered for a model string, so an
  /// untouched one stays blank, prints an unknown and counts as one.
  ///
  /// NO `Duplicate & edit` ENTRY POINT YET. docs/06 §7.3 offers one from
  /// every catalog card, and that belongs with the library browser
  /// (M4-O, #186); this menu item is the one route that exists, and it
  /// authors a NEW template rather than forking a seeded one.

  /// docs/07 §5's import, from the editor's `Import CSV…` (M3-F/2).
  ///
  /// THE BODY COMES FROM THE EDITOR'S PICKER, the same #158 question
  /// `Add outlet` answers one method down: an import filed on the wrong
  /// Structure body puts sixty drops on the wrong sheet, and unlike a
  /// single outlet that is not something anybody notices row by row.
  Future<void> _runCsvImport(DocumentSession session, Uuid? bodyId) async {
    final refusal = await runCsvImport(
      context: context,
      controller: session.controller,
      // THE CONTROLLER'S OWN PICKER, not a second one. `Open` and
      // `Save As` already go through it, so an import that minted its
      // own would be the one dialog in the app whose flags nothing
      // gates (`file_dialog_flags_test.dart`).
      picker: _services.controller.picker,
      fs: _services.controller.fs,
      structureBodyId: bodyId,
    );
    if (refusal != null) _showRefusal(refusal);
  }

  /// The editor's `Add outlet` button — docs/07 §4.3's `+ Add outlet ▾`
  /// (M3-C/5, DR-024 §11.23.3).
  ///
  /// A SECOND DIALOG OVER THE EDITOR, which is what the picker already
  /// is: it plans against the live document, so opening it from inside a
  /// surface that also reads the live document costs nothing.
  ///
  /// `currentDoc` is a CALLBACK and not a value, for the same reason
  /// again: an outlet placed by the first click changes the document the
  /// second click must plan against.
  Future<void> _openOutletPicker([Uuid? structureBodyId]) async {
    final session = _services.session;
    await showOutletTemplatePicker(
      context,
      currentDoc: () => session.document,
      actions: buildOutletTemplateActions(
        controller: session.controller,
        structureBodyId: structureBodyId,
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

  /// Something worked, and what it did is worth a sentence (`PLAN-F/2`).
  ///
  /// The same surface as [_showRefusal] and a separate method, because
  /// the two are separate decisions: a later banner, log line or status
  /// row for successes changes this one and leaves refusals alone.
  void _showNotice(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // ══════════════════════════════════════════════════════════════════
  // THE PLAN TAB (PLAN-E/5, DR-143, DR-091)
  // ══════════════════════════════════════════════════════════════════

  /// Decoded underlay rasters, for as long as this shell is up.
  ///
  /// OWNED HERE BECAUSE THE BYTES ARE THE SESSION'S. `rackpal_ui` has no
  /// `FileStore` and must not grow one, and the container's members ride
  /// on `DocumentSession`; the cache is the one place they become
  /// `ui.Image`s. Same seam as `_libraries` two methods down.
  final PlanImageCache _planImages = PlanImageCache();

  /// Which members have been handed to [_planImages] already.
  ///
  /// A SET RATHER THAN A LENGTH CHECK. `PlanImageCache.load` is
  /// idempotent, but the decode is not free and this build method runs on
  /// every document change; without this an import would re-decode every
  /// plan in the project.
  final Set<String> _planImagesLoaded = <String>{};

  /// docs/15 §6's fast path, owned ABOVE the tabs.
  ///
  /// It has to outlive a tab switch by construction: the whole gesture is
  /// arm in the Structure editor, then click the plan, and a controller
  /// owned by either view would be disposed by the move between them
  /// (DR-141 §11.140.5).
  final PlanPinArmController _planArm = PlanPinArmController();

  /// Feeds the cache whatever the session is holding, once each.
  void _loadPlanImages(DocumentSession session) {
    for (final entry in session.members.entries) {
      if (!_planImagesLoaded.add(entry.key)) continue;
      unawaited(
        _planImages.load(entry.key, entry.value).then((_) {
          // A DECODE IS ASYNCHRONOUS AND THE CANVAS IS NOT. Without this
          // the first frame after an import draws with the resolver
          // returning null, which `FlutterDiagramCanvas` raises as
          // `MissingImageError`; the rebuild is what makes the plan
          // appear rather than the app report a missing member.
          if (mounted) setState(() {});
        }),
      );
    }
  }

  Widget _planTab(DocumentSession session) {
    _loadPlanImages(session);
    return PlanEditorScreen(
      // KEYED ON THE CONTROLLER'S IDENTITY, on `_rackTab`'s reason:
      // replacing the document must build a fresh `State`, and this one
      // holds a per-underlay viewport and canvas key that belong to the
      // document that made them.
      key: ValueKey(session.controller),
      controller: session.controller,
      images: _planImages.resolver,
      measurer: widget.measurer,
      selection: _planSelection,
      arm: _planArm,
      onRefuse: _showRefusal,
      // THE SAME CHANNEL AS A REFUSAL, WHICH IS THIS SHELL'S DECISION AND
      // NOT THE VIEW'S. `PlanEditorScreen` keeps the two callbacks apart
      // because they carry opposite news; what a host does with them is
      // its own business, and every transient notice in this window is a
      // snack bar today.
      onNotice: _showNotice,
    );
  }

  /// The Plan view's selection, separate from the two canvases.
  ///
  /// ITS OWN CONTROLLER because a pin and a rack device are not the same
  /// selection: selecting a speaker's pin on `Level 1` must not change
  /// what the elevation has highlighted, and CR-105's cross-view
  /// signposting is an explicit gesture rather than a shared set.
  final SelectionController _planSelection = SelectionController();

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
      // `#242`, DR-102 §11.101.3. The palette answers for the document
      // AND these; the shell reads the shelf because `rackpal_ui` has no
      // `FileStore` and must not grow one.
      libraries: _libraries,
      unreadableLibraries: _unreadableLibraries,
      // `#245`: the same per-user set the browser stars into, so the
      // two surfaces cannot show different favourites.
      favourites: _favourites,
      // CR-105, joined up. Supplying this callback is ALSO what makes the
      // chip appear at all (`RackCanvasScreen.onRevealInSchematic`): the
      // elevation refuses to draw a signpost nobody is listening to, and
      // this shell is the only listener that can exist.
      onRevealInSchematic: _revealInSchematic,
      // Door 2 (CR-054, DR-099). Routing is the shell's because the shell
      // owns the six-view stack and the Device Manager's single draft.
      onEditTemplate: _openTemplateForEditing,
    );
  }

  /// Door 2: open [templateId] in the Device Manager, which forks
  /// `version + 1` on save (DR-099 §11.98).
  ///
  /// REFUSES ON A DIRTY DRAFT rather than prompting to discard it
  /// (§11.98.4). The dialog offering "discard and open the other one" is
  /// the shape people dismiss by reflex, and a discarded draft has NO
  /// RECOVERY PATH: the session is an in-memory deep copy, so there is
  /// nothing for `Ctrl+Z` to reach and nothing on disk to reopen. A
  /// refusal costs a forgotten draft one extra step and can destroy
  /// nothing. The user is still TAKEN THERE, because "finish it first" is
  /// useless without showing them what "it" is.
  void _openTemplateForEditing(TemplateId templateId) {
    final refused = _builderDirty && _editingTemplateId != templateId;
    // `setState`, AND IT WAS MISSING. This assignment used to reach the
    // screen anyway because the Device Manager tab built
    // `DeviceBuilderScreen` unconditionally, so the tab switch below was
    // the rebuild. `#243` made the tab CHOOSE between the browser and
    // the builder on this very field, at which point a mutation nothing
    // notified left door 2 opening onto the browser. Exposed by
    // `door_two_test.dart`, which is the test that already existed for
    // exactly this routing.
    if (!refused) setState(() => _editingTemplateId = templateId);

    // THE SAME POST-FRAME HOP `_revealInSchematic` uses, for its reason: a
    // `PageView` settles to the nearest page when the pointer it is
    // watching lifts, and the menu tap that chose this door IS that
    // pointer. Switching inside it moves the index and the settle puts it
    // straight back.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      switchToTab(_kDeviceManagerTabIndex);
      if (refused) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Finish or discard this template first.'),
          ),
        );
      }
    });
  }

  /// Removes a template from THIS PROJECT, with the devices standing on
  /// it (`#871`, DR-158 §11.157).
  ///
  /// **THE COUNTS AND THE REMOVAL READ ONE OBJECT.** `planTemplateRemoval`
  /// is what the dialog counts and what `addTemplateRemoval` consumes,
  /// which is `delete_location_dialog.dart`'s rule: a dialog that said
  /// "3 devices" and removed four would be worse than no dialog.
  ///
  /// **ONE TRANSACTION, ONE UNDO** (§11.157.6), which is the same shape
  /// `_deleteSelection` uses for a multi-device delete. The label is
  /// `removeTemplateFromProject` and not `removeDevice`, because what the
  /// person did was get rid of a template and the devices are a
  /// consequence of it.
  Future<void> _removeTemplate(DocumentSession session, TemplateId id) async {
    final controller = session.controller;
    final plan = planTemplateRemoval(controller.doc, id);
    if (!plan.isRemovable) return;
    final name =
        resolveLatestTemplate(controller.doc, id.v)?.body.displayName ?? id.v;

    final confirmed = await confirmTemplateRemoval(
      context,
      plan: plan,
      name: name,
    );
    if (!confirmed || !mounted) return;

    // RE-PLANNED AFTER THE AWAIT, on `_deleteSelection`'s rule: the
    // document is not frozen while a dialog is open, and an undo from a
    // menu or a second window could have moved it. The plan the person
    // ANSWERED is the one above; the plan that runs is this one, and if
    // they disagree the honest thing is to remove what is actually there
    // rather than what was there a moment ago.
    final live = planTemplateRemoval(controller.doc, id);
    if (!live.isRemovable) return;
    controller.transact(
      LabelKey.removeTemplateFromProject,
      (tx) => addTemplateRemoval(tx, live),
    );
    setState(() {});
  }

  /// The elevation's chip, answered: park the request, then switch tabs.
  ///
  /// PARK FIRST, SWITCH SECOND, and the order is the whole of why this is
  /// two steps. `TabBarView` builds its pages lazily, so the schematic
  /// may not be mounted when the chip is clicked; the controller holds
  /// the request as STATE and the screen drains it on its first frame.
  /// Notifying after the switch would work too — and would break the
  /// first time Flutter changed when that page is built.
  /// docs/15 §6's secondary entry point: arm a drop here, click the plan
  /// there (DR-141 §11.140.4, moved from PLAN-E/3 by DR-143 §11.142.4).
  ///
  /// ═══════════════════════════════════════════════════════════════════
  /// THE SUBJECT IS AN OUTLET AND THE ROW IS A LINK
  /// ═══════════════════════════════════════════════════════════════════
  /// `armSubjectFor` does the join through `Link.structureOrigin`, and
  /// `armRefusalFor` is the same question asked for a sentence: a link
  /// with no structure origin is a cable running to no outlet and there
  /// is nothing to pin, which is refused BY NAME rather than by a menu
  /// item that quietly does nothing.
  void _armPinFromDropTable(Uuid linkId) {
    final doc = _services.session.document;
    final refusal = armRefusalFor(doc, linkId);
    if (refusal != null) {
      _showRefusal(refusal);
      return;
    }
    final outletId = armSubjectFor(doc, linkId)!;
    _planArm.arm(
      ArmedPin(
        outletId: outletId,
        // THE LABEL THE USER JUST READ, carried rather than re-derived:
        // the chip renders on a different tab from the table that armed
        // it, and passing the string is what stops the two disagreeing.
        label: doc.outlets[outletId]?.designation ?? outletId.v,
      ),
    );
    // DEFERRED PAST THE CLICK, for the reason `_revealInSchematic` below
    // spells out at length: `TabBarView` is a `PageView` and settles to
    // the nearest page when the pointer that asked goes up, so a switch
    // inside the gesture is undone by the settle. The ARM is set first
    // and unconditionally, so the plan has it whichever frame it builds
    // on.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) switchToTab(ShellView.plan.index);
    });
  }

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
/// The application's whole menu bar.
///
/// **NAMED `_FileMenu` UNTIL DR-159 §11.158.6**, which was accurate for
/// as long as `File` was the only menu there was. It now builds `File`
/// and `Edit`, and a class named after one of its two children is the
/// kind of name a reader trusts and should not.
final class _AppMenuBar extends StatelessWidget {
  const _AppMenuBar({
    required this.controller,
    required this.recents,
    required this.recentStates,
    required this.onOpenMenu,
    required this.onNew,
    required this.onOpen,
    required this.onSave,
    required this.onSaveAs,
    required this.onExportPdf,
    required this.onExportTemplate,
    required this.onImportTemplate,
    required this.onExportLibrary,
    required this.onImportLibrary,
    required this.onImportFloorplan,
    required this.onProjectSettings,
    required this.onOpenRecent,
    required this.undoTarget,
  });

  /// What `Edit` describes and acts on: the document's stack, or the
  /// Device Builder's while that screen is showing (DR-159 §11.158.5).
  final UndoTarget undoTarget;

  final MenuController controller;
  final List<RecentEntry> recents;
  final Map<String, RecentEntryState> recentStates;
  final Future<void> Function() onOpenMenu;
  final Future<void> Function() onNew;
  final Future<void> Function() onOpen;
  final Future<void> Function() onSave;
  final Future<void> Function() onSaveAs;
  final Future<void> Function() onExportPdf;
  final Future<void> Function() onExportTemplate;
  final Future<void> Function() onImportTemplate;
  final Future<void> Function() onExportLibrary;
  final Future<void> Function() onImportLibrary;

  /// `File ▸ Import floorplan…` (DR-143 §11.142).
  final Future<void> Function() onImportFloorplan;

  /// Opens the project settings editor (`#805`, RJ-012).
  final Future<void> Function() onProjectSettings;
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
            // DR-101 §11.100.4 puts the device-template pair HERE, beside
            // the other file operations, and not on a palette card:
            // Import belongs to no template, so a card menu would split
            // the pair across two surfaces. No `shortcut:` on either, for
            // the reason stated above Export PDF: RULE 14 holds the
            // global file group at exactly four bindings.
            MenuItemButton(
              onPressed: () => unawaited(onExportTemplate()),
              child: const Text('Export device template…'),
            ),
            MenuItemButton(
              onPressed: () => unawaited(onImportTemplate()),
              child: const Text('Import device template…'),
            ),
            // `#240`. The library pair sits beside the template pair for
            // DR-101 §11.100.4's reason applied one level up: an import
            // belongs to no library, so a browser-side control would
            // split the verbs, and a second `FilePicker` call site is
            // what RULE 7 forbids. Still no accelerators, for the eighth
            // time and the same reason.
            MenuItemButton(
              onPressed: () => unawaited(onExportLibrary()),
              child: const Text('Export device library…'),
            ),
            MenuItemButton(
              onPressed: () => unawaited(onImportLibrary()),
              child: const Text('Import device library…'),
            ),
            // ═════════════════════════════════════════════════════════
            // AND THE FLOORPLAN, WHICH IS THE IMPORT THAT HAD NO MENU
            // ═════════════════════════════════════════════════════════
            // `File` and not a `Plan` menu (DR-143 §11.142.4, the user's
            // call): it sits with the two imports already here, and a
            // second top-level menu holding one item is not worth the
            // strip. `plan_import_actions.dart`'s own header says
            // `Plan ▸ Import floorplan…`, which was a PLAN-D assumption
            // and is superseded rather than a decision anybody made.
            //
            // THIS ITEM IS THE PRODUCER THE WHOLE PLAN VIEW WAS MISSING.
            // Every step of the import was built, tested and reachable
            // from nothing, so `AddPlanUnderlayCommand` had no caller and
            // no project could hold a floorplan. No accelerator, for the
            // ninth time and the same reason as the eight above.
            MenuItemButton(
              onPressed: () => unawaited(onImportFloorplan()),
              child: const Text('Import floorplan…'),
            ),
            // ═════════════════════════════════════════════════════════
            // ON THE FILE MENU, BECAUSE SETTINGS LIVE IN THE FILE
            // ═════════════════════════════════════════════════════════
            // `ProjectSettings` is a field of `RackDocument`, so these
            // travel with the project and are undoable on its stack. That
            // is what makes File the right menu rather than an
            // application-preferences home: nothing here is a preference
            // about the app, and `displayUnits` is authoritative OVER any
            // app-level preference (CR-097).
            const Divider(),
            MenuItemButton(
              onPressed: () => unawaited(onProjectSettings()),
              child: const Text(kProjectSettingsLabel),
            ),
          ],
          child: const Text('File'),
        ),
        // ═══════════════════════════════════════════════════════════════
        // THE EDIT MENU, SPECIFIED AT M0 AND BUILT AT DR-159 §11.158.6
        // ═══════════════════════════════════════════════════════════════
        // docs/03 §13.3: "The Edit menu shows a localized 'Undo Move
        // device'; the log shows the stable enum name." `LabelKey` has
        // 101 values and many exist ONLY because of this menu —
        // `commitPortSort` is its own value because "Undo Reorder ports"
        // in front of somebody who has just been through a confirm dialog
        // names the wrong act. All of that reasoning was written against
        // a surface that did not exist.
        //
        // **A KEYBOARD-ONLY BINDING IS INVISIBLE**, which is why fixing
        // the key alone was refused: a person who does not already know
        // the chord has no way to learn the product has undo at all.
        SubmenuButton(
          menuChildren: [
            MenuItemButton(
              shortcut: keymapActivator(KeyBindingId.undo),
              // NULL DISABLES IT, which is the honest render of an empty
              // stack: a live row that does nothing teaches a person the
              // menu lies.
              onPressed: undoTarget.canUndo ? undoTarget.undo : null,
              child: Text(undoMenuLabel(undoTarget.undoLabelKey)),
            ),
            MenuItemButton(
              shortcut: keymapActivator(KeyBindingId.redo),
              onPressed: undoTarget.canRedo ? undoTarget.redo : null,
              child: Text(redoMenuLabel(undoTarget.redoLabelKey)),
            ),
          ],
          child: const Text('Edit'),
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
