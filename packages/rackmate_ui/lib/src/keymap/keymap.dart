// THE KEYMAP REGISTRY — one declaration of every binding in the app.
//
// ══════════════════════════════════════════════════════════════════════
// WHY THIS FILE EXISTS: THREE DEBTS, ONE MECHANISM
// ══════════════════════════════════════════════════════════════════════
// It is not a tidy-up. Three separate obligations converge on exactly one
// missing thing — a single place where a binding is declared — and none of
// them can be discharged without it:
//
//   1. macOS debt D7 (docs/13 §2). Every binding hard-coded `Ctrl`. macOS
//      needs `Cmd`. DR-009 §11.9.2 pulled this into M2 because it is "the
//      only item that gets more expensive with every commit", and M2-E had
//      just added twelve more bindings while that sentence was being read.
//
//   2. M7's exit criterion: "no keybinding bound twice IN THE GENERATED
//      TABLE". The milestone board (§5.6) records that nothing generated a
//      table and there was no `Intent` registry — so the clause could not
//      be evaluated, let alone met.
//
//   3. CR-101 (canon:1528). The keymap "has ~18 collisions and no
//      arbitration document"; the two source design documents "collide on
//      at least 16 keys". Its ruling (canon:2508): "~40 bindings, one
//      arbitrated table, generated from one `Intent` registry."
//
// ══════════════════════════════════════════════════════════════════════
// WHY A DUPLICATE BINDING IS SILENT, AND THEREFORE NEEDS A TEST
// ══════════════════════════════════════════════════════════════════════
// `SingleActivator` DOES NOT OVERRIDE `operator ==`
// (flutter/lib/src/widgets/shortcuts.dart:436 — `with Diagnosticable,
// MenuSerializableShortcut implements ShortcutActivator`, and no equality
// anywhere in the class). Two activators built at runtime with identical
// trigger and modifiers are therefore DIFFERENT map keys, and a
// `Map<ShortcutActivator, Intent>` will happily hold both.
//
// `ShortcutManager` does not look a binding up by key: it groups by
// `trigger` and then walks the group asking each activator `accepts(...)`,
// taking the FIRST that says yes. So a key bound twice does not throw, does
// not warn and does not lose an entry — it silently runs whichever binding
// happens to be first in iteration order, and the other one is dead code
// that still reads as live in the source. That is precisely the failure
// mode CR-101 describes, and it is invisible to every behavioural test that
// only presses the key expecting the winner.
//
// [arbitrate] is the thing that makes it visible, and
// `keymap_arbitration_test.dart` is what makes it fail.
//
// ══════════════════════════════════════════════════════════════════════
// THE PRIMARY MODIFIER IS RESOLVED, NEVER HARD-CODED
// ══════════════════════════════════════════════════════════════════════
// [KeyBinding.primary] means "the platform's primary command modifier" —
// `Ctrl` on Windows and Linux, `Cmd` on macOS and iOS. It is resolved
// through `defaultTargetPlatform` and NOT through `Platform.isWindows`,
// for the reason `main.dart:132` already records for the third environment
// lookup: `storage_layering_test.dart` RULE 1 permits `dart:io` in exactly
// two files and no UI file is one of them. The same reasoning is why the
// storage layer's platform split is an injected flag rather than a runtime
// probe (docs/13 §1).
//
// Under `FLUTTER_TEST`, `defaultTargetPlatform` is `android`
// (flutter/lib/src/foundation/_platform_io.dart:30), so every existing
// widget test that presses `Ctrl` keeps passing unchanged, and a test that
// wants the macOS map asks for it explicitly via the [platform] parameter
// or `debugDefaultTargetPlatformOverride`.
//
// ══════════════════════════════════════════════════════════════════════
// WHAT THIS REGISTRY DOES NOT DECIDE
// ══════════════════════════════════════════════════════════════════════
// The arbitrated CHOICES are a ruling (canon §1.10 / docs/04 §8), not this
// file's to make. Nothing here rebinds anything: every entry below was
// extracted from the source it replaces, key for key and modifier for
// modifier. Where the extraction SURFACES a problem — a binding that is
// wrong for macOS, a scope that is narrower than its own doc comment
// claims — it is recorded in [KeyBinding.note] and reported, not fixed.
// A fix is a rebinding, and a rebinding is a decision.
//
// It also does not decide HOW a binding is handled. The registry says what
// a key MEANS (its `Intent`); each surface supplies the `Action`, with the
// focus gating that surface needs — see `_GatedAction` in
// `rack_canvas_screen.dart` for why every one of those is a real `Action`
// and not a `CallbackAction`.
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter/widgets.dart'
    show
        AxisDirection,
        Intent,
        ShortcutActivator,
        SingleActivator,
        VoidCallback,
        WidgetsApp;

/// Where a binding is installed, and therefore where it must be unique.
///
/// A SCOPE IS A `Shortcuts` SUBTREE, not a category. Flutter dispatches key
/// events LEAF -> ROOT, so "which scope" is the same question as "which
/// binding wins" — which is why the scope column is what arbitration is
/// computed over rather than a label for the reader.
enum KeyScope {
  /// Installed on `MaterialApp`, above the app's root focus scope.
  ///
  /// ABOVE THE WHOLE APP, not above the tab view, and that is a
  /// correctness requirement — see `app_shell.dart`'s `buildFileActions`
  /// doc for the post-mortem: a `Shortcuts` widget below the root focus
  /// scope only ever sees keys pressed while focus is inside its own
  /// subtree, so `Ctrl+S` worked on the Rack tab (whose canvas
  /// autofocuses) and silently did nothing on the other two.
  global,

  /// `RackCanvasScreen`'s `Shortcuts`, wrapping palette + canvas +
  /// inspector.
  rack,

  /// `SchematicCanvasScreen`'s `Shortcuts`.
  schematic,

  /// `StructureEditorScreen`'s `Shortcuts`, wrapping the drop table.
  ///
  /// ITS OWN SCOPE AND NOT `global`, because both of its bindings act on
  /// THE FOCUSED CELL and there is no honest answer to `Ctrl+D` outside a
  /// grid. A global row would have to decline everywhere else, which is
  /// how a key ends up meaning nothing in three places and something in
  /// one.
  structure,

  /// The DEVICE BUILDER's `Shortcuts` (M4-G).
  ///
  /// ITS OWN SCOPE, NOT `global`, and the reason is the same one
  /// `structure` gives: the binding acts on THE FOCUSED BAR and there is
  /// no honest answer to it anywhere else. It is also not `rack`: the
  /// builder is a full-window editor over a `TemplateBody` with its own
  /// undo stack (CR-106), so a scope shared with the document's canvas
  /// would say the two stacks were one thing.
  builder,

  /// The modal dialogs' `CallbackShortcuts`.
  ///
  /// One scope for all three (unsaved changes, recovery prompt, file
  /// error) because they bind the same key to the same meaning — see
  /// [KeyBindingId.dialogDismiss].
  dialog,
}

/// A stable name for one binding.
///
/// The enum, not the key, is the identifier: a menu accelerator and the
/// binding it advertises name the same VALUE, so the two cannot drift into
/// a menu that promises a key nothing listens for. That drift is what
/// `session_layering_test.dart` RULE 14 was written to catch by counting
/// activators in the source; with both halves reading from here it is
/// structurally impossible, and RULE 14 now asserts the structure instead.
enum KeyBindingId {
  // --- global ---------------------------------------------------------
  newDocument,
  openDocument,
  saveDocument,
  saveDocumentAs,
  switchViewRack,
  switchViewSchematic,
  switchViewSchedule,

  // --- rack -----------------------------------------------------------
  deleteSelection,
  deleteSelectionBackspace,
  undo,
  redo,
  redoAlternate,
  focusPaletteSearch,
  caretUp,
  caretDown,
  caretHome,
  caretEnd,
  caretPageUp,
  caretPageDown,
  rackCancel,
  rackSettings,
  newRack,
  applyCompaction,

  // --- schematic ------------------------------------------------------
  soloDomain1,
  soloDomain2,
  soloDomain3,
  soloDomain4,
  soloDomain5,
  soloDomain6,
  soloDomain7,
  soloDomain8,
  showAllDomains,
  focusSelection,
  schematicCancel,
  beginWire,
  commitWire,

  // --- builder (M4-G) -------------------------------------------------
  quickAddCommit,
  quickAddComplete,
  builderJumpToPorts,

  // --- builder (M4-F1) ------------------------------------------------
  // THE PORT GRID'S OWN FILLS, and they are separate ids from
  // `fillDown` rather than that row widened to a second scope.
  // `bindingFor` is a `firstWhere` over `id`, so two rows sharing one
  // would make it ambiguous, and the two are not the same act: the
  // Structure editor's copies from the cell ABOVE because that table has
  // no selection, and this one fills a RANGE (DR-061).
  builderFillDown,
  builderFillSeries,

  // --- builder (M4-F3) ------------------------------------------------
  builderCopyCells,
  builderPasteCells,

  // --- builder (M4-F4) ------------------------------------------------
  builderMoveRowUp,
  builderMoveRowDown,

  // --- builder (M4-F6, DR-078) -----------------------------------------
  builderDuplicateRows,

  // --- builder (M4-F7, DR-078) -----------------------------------------
  builderRenumber,
  commitWireChained,
  nextCandidatePin,
  previousCandidatePin,
  pinCaretUp,
  pinCaretDown,
  pinCaretLeft,
  pinCaretRight,
  extendPinSelectionUp,
  extendPinSelectionDown,
  deleteCable,
  deleteCableBackspace,

  // --- structure ------------------------------------------------------
  fillDown,
  pasteCells,

  // --- dialog ---------------------------------------------------------
  dialogDismiss,
}

// ══════════════════════════════════════════════════════════════════════
// THE INTENTS
// ══════════════════════════════════════════════════════════════════════
// PUBLIC AND SHARED, where they used to be private and per-file
// (`_DeleteIntent`, `_UndoIntent`, `_ArrowUpIntent`, … all inside
// `rack_canvas_screen.dart`; `_SoloDomainIntent` and three siblings inside
// `schematic_canvas_screen.dart`; four more inside `app_shell.dart`).
//
// The privacy was defensible per file and was exactly what made the
// registry impossible: an `Intent` a registry cannot name is a binding a
// table cannot list. CR-101 rules "one `Intent` registry", and this is it.
//
// Making them public does not widen who may HANDLE them — an `Actions` map
// is keyed by intent type and each surface still installs only its own —
// but it does mean a second surface COULD adopt one, which is what
// arbitration principle (b) ("a key means the same thing in every view or
// it means nothing") wants to be possible.

/// `New` — `Ctrl/Cmd+N`.
final class NewDocumentIntent extends Intent {
  const NewDocumentIntent();
}

/// `Open…` — `Ctrl/Cmd+O`.
final class OpenDocumentIntent extends Intent {
  const OpenDocumentIntent();
}

/// `Save` — `Ctrl/Cmd+S`.
final class SaveDocumentIntent extends Intent {
  const SaveDocumentIntent();
}

/// `Save As…` — `Ctrl/Cmd+Shift+S`.
final class SaveDocumentAsIntent extends Intent {
  const SaveDocumentAsIntent();
}

/// `Ctrl/Cmd+1` / `+2` / `+4` — switch to a view by IDENTITY.
///
/// CARRIES THE VIEW KEY AND NOTHING ELSE. It used to carry the tab INDEX
/// as well, resolved at the binding site; that field has moved to
/// `app_shell.dart`, which is the only place that knows what the v1 strip
/// renders. docs/04 §8 line 456 and docs/10 :516 rule that "`Ctrl+n` is a
/// view identity, not an ordinal", and a registry — which is shared,
/// permanent and platform-level — carrying an ordinal from one milestone's
/// tab strip was that conflation written down. The strip is three tabs and
/// the keys are 1, 2 and 4; the mapping between them belongs where the
/// strip is built.
final class SwitchViewIntent extends Intent {
  const SwitchViewIntent(this.viewKey);

  /// The digit in `Ctrl+n` — 1, 2 or 4. Never a tab index.
  final int viewKey;
}

/// Delete the current selection (`Del` / `Backspace`).
final class DeleteSelectionIntent extends Intent {
  const DeleteSelectionIntent();
}

/// Undo the last committed transaction (`Ctrl/Cmd+Z`).
final class UndoIntent extends Intent {
  const UndoIntent();
}

/// Redo the last undone transaction (`Ctrl/Cmd+Shift+Z`, `Ctrl+Y`).
final class RedoIntent extends Intent {
  const RedoIntent();
}

/// Focus the palette search field (`/`).
final class FocusPaletteSearchIntent extends Intent {
  const FocusPaletteSearchIntent();
}

/// Move the caret up 1U, or nudge the focused selection up 1U (`↑`).
final class CaretUpIntent extends Intent {
  const CaretUpIntent();
}

/// Move the caret down 1U, or nudge the focused selection down 1U (`↓`).
final class CaretDownIntent extends Intent {
  const CaretDownIntent();
}

/// Caret to U1, or nudge the focused selection to its lowest fitting
/// position (`Home`).
final class CaretHomeIntent extends Intent {
  const CaretHomeIntent();
}

/// Caret to the top U, or nudge the focused selection to its highest
/// fitting position (`End`).
final class CaretEndIntent extends Intent {
  const CaretEndIntent();
}

/// Move the caret up 10U, or nudge the focused selection up 10U (`PgUp`).
final class CaretPageUpIntent extends Intent {
  const CaretPageUpIntent();
}

/// Move the caret down 10U, or nudge the focused selection down 10U
/// (`PgDn`).
final class CaretPageDownIntent extends Intent {
  const CaretPageDownIntent();
}

/// Revert an in-flight move drag, cancel an open compaction preview, or
/// clear the selection (`Esc`, docs/04 §3.3 step 4, §3.6 and §8).
final class RackCancelIntent extends Intent {
  const RackCancelIntent();
}

/// Open the `RackInspector` (`Ctrl+Alt+U`, docs/04 §4 and §8's keymap).
final class RackSettingsIntent extends Intent {
  const RackSettingsIntent();
}

/// Open the New-rack dialog (`Ctrl+Alt+N`, docs/04 §8 and §9).
final class NewRackIntent extends Intent {
  const NewRackIntent();
}

/// Apply an open compaction preview (`Enter`, docs/04 §3.6).
final class ApplyCompactionIntent extends Intent {
  const ApplyCompactionIntent();
}

/// Solo one signal domain by its index in the filter bar (docs/05 §11.2).
final class SoloDomainIntent extends Intent {
  const SoloDomainIntent(this.index);

  /// 1-based, matching the chip labels — never a list offset.
  final int index;
}

/// Clear the domain filter (`` ` ``, docs/05 §11.2).
final class ShowAllDomainsIntent extends Intent {
  const ShowAllDomainsIntent();
}

/// Focus the selection on the sheet (`F`, docs/05 §11.4).
final class FocusSelectionIntent extends Intent {
  const FocusSelectionIntent();
}

/// Drop the focus set, then the selection (`Esc`, docs/05 §11.4).
final class SchematicCancelIntent extends Intent {
  const SchematicCancelIntent();
}

/// Begin a wire from the pin under the caret (`W`, docs/05 §7 and §14).
final class BeginWireIntent extends Intent {
  const BeginWireIntent();
}

/// Commit the wire in flight (`Enter`, docs/05 §7's keyboard path).
///
/// A SIBLING OF [ApplyCompactionIntent], NOT A REPLACEMENT FOR IT, and
/// DR-011.6 is why they are two types under ONE label. `Esc` already has
/// three intents and one label for the same reason: three surfaces handle
/// it, so three `Actions` maps need three keys, but it MEANS one thing and
/// [KeymapConflictKind.meaningDrift] is what holds that true.
///
/// The rejected alternative is the interesting one. Widening `meaningDrift`
/// to permit per-scope labels was the smaller edit and is the wrong one:
/// that rule exists to stop one key meaning two things, and A KEYBOARD-ONLY
/// USER CANNOT SEE A SCOPE BOUNDARY — which is precisely the population
/// docs/05's keyboard path is for.
final class CommitWireIntent extends Intent {
  const CommitWireIntent();
}

/// Run what is typed in Quick Add (`Enter`, docs/06 §4.1).
///
/// THE THIRD TYPE UNDER [CommitWireIntent]'s LABEL, and the pattern that
/// docstring describes applied once more: three surfaces handle this key
/// so three `Actions` maps need three keys, but it MEANS one thing and
/// [KeymapConflictKind.meaningDrift] is what holds that true.
///
/// It was drafted with a label of its own, on the argument that
/// committing a wire joins two pins that exist while this creates
/// sixteen ports that do not. **The gate refused it and was right.** The
/// reason is the one [CommitWireIntent] already states: a keyboard-only
/// user cannot see a scope boundary, so `Enter` gets one meaning across
/// the product or the keymap has lied to them. A typed Quick Add command
/// is in flight in exactly the sense a half-drawn wire is.
final class QuickAddCommitIntent extends Intent {
  const QuickAddCommitIntent();
}

/// Jump to the builder's PORTS section (`Ctrl+Enter`, docs/06 §9.1 step 5).
///
/// **BUILT AFTER THE DRILL, BECAUSE THE DRILL FOUND IT MISSING.** §9.1's
/// worked example spends step 5 on this chord, and the binding had never
/// existed: `KeyScope.builder` held the Quick Add commit and its
/// autocomplete and nothing else. The user timed the criterion at 93
/// seconds and reached for the MOUSE at exactly this step, which is the
/// one thing no test in this repository can report.
///
/// The rail was always reachable by `Tab`, deliberately (M4-D's
/// `FocusTraversalGroup` note), so this is not a missing route: it is
/// the difference between one chord and tabbing out of a form, across a
/// rail, to the right tile. On a criterion measured with a stopwatch
/// that difference is the whole point.
final class JumpToPortsIntent extends Intent {
  const JumpToPortsIntent();
}

/// Accept Quick Add's inline completion (`→`, docs/06 §4.1).
///
/// **ITS ACTION MUST BE DISABLED WHEN THERE IS NO COMPLETION, AND THAT
/// IS NOT AN OPTIMISATION.** Right-arrow MOVES THE CARET in a text
/// field. A `CallbackAction` consumes the key regardless of what its
/// body does, so a bar that bound it unconditionally would stop a user
/// walking through their own command, which is the exact failure
/// `keymap_arbitration_test.dart` demands a real `Action` with
/// `isActionEnabled` for. The schematic's two `Tab` rows are gated on a
/// wire being in flight for the same reason and it is the same argument.
final class QuickAddCompleteIntent extends Intent {
  const QuickAddCompleteIntent();
}

/// Move the pin caret to the next/previous candidate while a wire is in
/// flight (`Tab` / `Shift+Tab`, docs/05 §7).
///
/// GATED ON A WIRE BEING ARMED, and that is a decision worth recording
/// rather than a limitation. docs/05 §7 gives the keyboard route as "`Tab`
/// to a port, `W` to begin a wire, `Tab`/arrow to a candidate port"; a
/// schematic that owned bare `Tab` UNCONDITIONALLY would take it from focus
/// traversal, and the canvas autofocuses — so a keyboard-only user could
/// enter the sheet and never leave it. AC-058/D11 makes the keyboard route
/// a v1 requirement and M7's exit criterion is a screen-reader matrix; a
/// canvas that traps `Tab` fails both. So `Tab` cycles CANDIDATES while
/// armed and falls through to traversal when idle, and the ARROWS (below)
/// are what reach a pin in the first place.
final class NextCandidatePinIntent extends Intent {
  const NextCandidatePinIntent();
}

/// See [NextCandidatePinIntent].
final class PreviousCandidatePinIntent extends Intent {
  const PreviousCandidatePinIntent();
}

/// Move the pin caret one pin in [direction] (docs/05 §7's "`Tab`/arrow to
/// a candidate port").
///
/// GEOMETRIC, NOT ORDINAL. The caret goes to the nearest pin in the pressed
/// direction rather than to the next one in a flat list, because the user is
/// looking at a sheet and not at an ordering — and because the flat walk
/// already has a key (`Tab`, while armed). "Nearest in direction" is defined
/// in `schematic_canvas_screen.dart`, where the geometry is.
final class MovePinCaretIntent extends Intent {
  const MovePinCaretIntent(this.direction);

  final AxisDirection direction;
}

/// Grow or shrink the multi-draw pin selection by one place in the bank's
/// rank order (#93, docs/05:484's "N ports selected in one bank").
///
/// ORDINAL, WHERE [MovePinCaretIntent] IS GEOMETRIC, and the two are on
/// the same arrow keys one `Shift` apart — so the difference is worth
/// stating. A bare arrow moves a cursor over a PICTURE and "nearest in
/// direction" is the only meaning that matches what the user is looking
/// at. `Shift` extends a RANGE, and a range in this gesture is defined by
/// DR-012.2's rank (`PortDef.order` then `key`) because that is the order
/// `planMultiDraw` pairs sources against sinks in. A geometric extension
/// could select pins in an order the commit would then ignore, which is
/// exactly the "two orderings of one bank" defect `multi_draw.dart` is
/// written against.
///
/// ON A LEFT- OR RIGHT-EDGE BANK — which is where the seed catalog puts
/// essentially all of them — rank order runs down the edge, so the two
/// readings agree and `Shift+Down` does the obvious thing. On a top or
/// bottom edge they part company, and the LABEL is what is honest about
/// it: it promises the selection, not a direction on screen.
///
/// THE CORPUS SPECIFIES ONLY THE POINTER GESTURE. docs/05:484 is
/// "dragging to a target bank", and no keyboard route for multi-draw is
/// written down anywhere. This pair is added for parity rather than
/// transcribed, on the grounds that a gesture reachable only with a mouse
/// is an accessibility hole in the one gesture that saves the most time
/// (AC-058/D11, M7's criterion). `Shift+arrow` is the convention every
/// range selection in every application uses, and docs/04 §3.4's own
/// comment already reserves `Shift+↑↓` for "extend" in the rack — so this
/// takes a meaning that was already spoken for rather than inventing one.
final class ExtendPinSelectionIntent extends Intent {
  const ExtendPinSelectionIntent(this.step);

  /// +1 towards the end of the bank, -1 towards its start.
  final int step;
}

/// Copy the cell directly above the focused one into it (docs/07 §4.1's
/// grid operations, M3-C/2).
///
/// ONE CELL, because the drop table has no range selection. Excel's
/// `Ctrl+D` with a single cell selected does exactly this, so the key
/// keeps the meaning a person already has for it rather than acquiring a
/// RackMate-specific one that would have to be taught.
final class FillDownIntent extends Intent {
  const FillDownIntent();
}

/// Paste tab-separated cells into the grid from the focused cell
/// (docs/07 §4.1, and §5's spreadsheet entry path).
final class PasteCellsIntent extends Intent {
  const PasteCellsIntent();
}

/// Copy the top selected cell down the focused column of the DEVICE
/// BUILDER's port grid (docs/06 §4.6, M4-F1).
///
/// A RANGE, WHICH IS WHAT SEPARATES IT FROM [FillDownIntent]. The
/// Structure editor's table has no selection, so its `Ctrl+D` copies from
/// the cell directly above; DR-061 gave this grid a row range, so this one
/// fills from the top of it.
final class BuilderFillDownIntent extends Intent {
  const BuilderFillDownIntent();
}

/// Count down the focused column from the top selected cell (DR-062).
final class BuilderFillSeriesIntent extends Intent {
  const BuilderFillSeriesIntent();
}

/// Put the selected rows on the clipboard as TSV (M4-F3, docs/06 §4.6).
final class BuilderCopyCellsIntent extends Intent {
  const BuilderCopyCellsIntent();
}

/// Paste tab-separated cells into the port grid from the focused cell.
final class BuilderPasteCellsIntent extends Intent {
  const BuilderPasteCellsIntent();
}

/// Clone the selected rows below themselves (M4-F6, docs/06 §4.6).
final class BuilderDuplicateRowsIntent extends Intent {
  const BuilderDuplicateRowsIntent();
}

/// Re-apply a label pattern to the selection (M4-F7, docs/06 §4.6).
final class BuilderRenumberIntent extends Intent {
  const BuilderRenumberIntent();
}

/// Slide the selected rows one position through their bank (M4-F4).
///
/// ONE INTENT WITH A DIRECTION, not two classes. `Alt+Up` and `Alt+Down`
/// are the same act aimed two ways, which is the reading `LabelKey
/// .reorderPorts` takes and the one `ExtendPinSelectionIntent(1)` already
/// established one scope over.
final class BuilderMoveRowIntent extends Intent {
  const BuilderMoveRowIntent({required this.up});

  final bool up;
}

/// A single declared binding: what key, in what scope, meaning what.
final class KeyBinding {
  const KeyBinding({
    required this.id,
    required this.scope,
    required this.trigger,
    required this.intent,
    required this.label,
    required this.source,
    this.primary = false,
    this.shift = false,
    this.alt = false,
    this.note,
  });

  /// The stable name. Unique across the whole registry.
  final KeyBindingId id;

  /// The `Shortcuts` subtree this binding is installed in.
  final KeyScope scope;

  /// The key that triggers it, modifiers excluded.
  final LogicalKeyboardKey trigger;

  /// Whether the PLATFORM PRIMARY modifier is required — `Ctrl` on
  /// Windows and Linux, `Cmd` on macOS and iOS. This is the whole of
  /// macOS debt D7: it is a declaration, not a keystroke, and it resolves
  /// per platform in [activatorFor].
  final bool primary;

  /// Whether `Shift` is required.
  final bool shift;

  /// Whether `Alt` is required. On Windows `Ctrl+Alt` IS `AltGr` — see
  /// [KeyBindingId.rackSettings]'s note.
  final bool alt;

  /// What the key does. THE ARBITRATION KEY FOR PRINCIPLE (b): two
  /// bindings that resolve to the same chord in different scopes must
  /// carry the same label, because canon §1.10 rules that "a key means the
  /// same thing in every view or it means nothing".
  final String label;

  /// The intent dispatched. The registry says what a key MEANS; the
  /// surface supplies the `Action` that does it.
  final Intent intent;

  /// The ruling or specification that fixes this binding. Carried into the
  /// generated table so a reader can check a key against its authority
  /// without grepping.
  final String source;

  /// A caveat the extraction SURFACED and deliberately did not fix.
  ///
  /// A note is a report, not a to-do the code has quietly accepted: every
  /// one of these is a decision that belongs to a ruling. Rendered in the
  /// generated table so it cannot be lost.
  final String? note;

  /// This binding as Flutter sees it, on [platform].
  ///
  /// The ONE place `primary` becomes a keystroke. Everything else in the
  /// app — the maps, the menu accelerators, the arbitration, the generated
  /// table — goes through here, so there is exactly one answer to
  /// "`Ctrl` or `Cmd`?" and it is a function of the platform.
  SingleActivator activatorFor(TargetPlatform platform) {
    final meta = primary && _primaryIsMeta(platform);
    return SingleActivator(
      trigger,
      control: primary && !meta,
      shift: shift,
      alt: alt,
      meta: meta,
    );
  }

  /// The chord as a comparable value.
  ///
  /// EXISTS BECAUSE `SingleActivator` HAS NO `operator ==` (see the file
  /// header). Arbitration cannot ask a `Set<SingleActivator>` whether it
  /// already holds an equivalent chord — every instance is distinct — so
  /// it compares these records instead. A Dart record has structural
  /// equality, which is the property the activator is missing.
  ({LogicalKeyboardKey trigger, bool control, bool shift, bool alt, bool meta})
  chordOn(TargetPlatform platform) {
    final activator = activatorFor(platform);
    return (
      trigger: activator.trigger,
      control: activator.control,
      shift: activator.shift,
      alt: activator.alt,
      meta: activator.meta,
    );
  }

  /// The chord as a person reads it: `Cmd+Shift+S`, `Ctrl+Alt+U`, `Esc`.
  String renderChord(TargetPlatform platform) {
    final parts = <String>[
      if (primary) _primaryIsMeta(platform) ? 'Cmd' : 'Ctrl',
      if (alt) _primaryIsMeta(platform) ? 'Option' : 'Alt',
      if (shift) 'Shift',
      _renderTrigger(trigger),
    ];
    return parts.join('+');
  }
}

/// macOS and iOS use `Cmd`; everything else uses `Ctrl`.
///
/// iOS is included even though RackMate is a desktop app, because docs/09
/// M7 carries a tablet read-only clause (AC-056) and a table that silently
/// answered "Ctrl" for iOS would be wrong the day it lands rather than the
/// day somebody noticed.
bool _primaryIsMeta(TargetPlatform platform) =>
    platform == TargetPlatform.macOS || platform == TargetPlatform.iOS;

/// `keyLabel` is empty for every non-printable key, so `debugName` — the
/// framework's own English name — is what renders `Escape`, `Arrow Up` and
/// `Page Down`. The final fallback exists because both are nominally
/// optional; it has no known trigger in this registry and is here so the
/// generator cannot throw while producing a document about keys.
String _renderTrigger(LogicalKeyboardKey key) {
  final label = key.keyLabel;
  if (label.isNotEmpty) return label;
  return key.debugName ?? 'U+${key.keyId.toRadixString(16)}';
}

// ══════════════════════════════════════════════════════════════════════
// THE REGISTRY
// ══════════════════════════════════════════════════════════════════════
// EVERY BINDING IN THE APPLICATION, in one const list. Adding a key means
// adding a row here, and adding a row here is what the arbitration and the
// generated table read.
//
// It is 35 rows against docs/04 §8's "~40-binding table" — the table is
// not complete, and deliberately so: `main.dart`'s ruling is that a
// partial keymap reads as a whole one, so a GROUP lands only when it is
// complete. What has changed is that the incompleteness is now visible in
// one place instead of being distributed across six files.
const List<KeyBinding> kKeymap = <KeyBinding>[
  // ── global ───────────────────────────────────────────────────────────
  // The FILE group, complete at four. Installed on `MaterialApp` because
  // the document is global: see `KeyScope.global`.
  KeyBinding(
    id: KeyBindingId.newDocument,
    scope: KeyScope.global,
    trigger: LogicalKeyboardKey.keyN,
    primary: true,
    label: 'New document',
    intent: NewDocumentIntent(),
    source: 'docs/04 §8',
  ),
  KeyBinding(
    id: KeyBindingId.openDocument,
    scope: KeyScope.global,
    trigger: LogicalKeyboardKey.keyO,
    primary: true,
    label: 'Open document',
    intent: OpenDocumentIntent(),
    source: 'docs/04 §8',
  ),
  KeyBinding(
    id: KeyBindingId.saveDocument,
    scope: KeyScope.global,
    trigger: LogicalKeyboardKey.keyS,
    primary: true,
    label: 'Save',
    intent: SaveDocumentIntent(),
    source: 'docs/04 §8',
  ),
  KeyBinding(
    id: KeyBindingId.saveDocumentAs,
    scope: KeyScope.global,
    trigger: LogicalKeyboardKey.keyS,
    primary: true,
    shift: true,
    label: 'Save as',
    intent: SaveDocumentAsIntent(),
    source: 'docs/04 §8',
  ),
  // The VIEW group, complete at THREE, and that is a ruling rather than an
  // omission. docs/04 §8 line 456 and docs/10 :516: "`Ctrl+3` is reserved
  // for the Rear Panel view and is an unbound no-op until v1.1 (CR-071);
  // `Ctrl+4` is the Schedule in v1 and forever. Do not rebind the Schedule
  // to `Ctrl+3` — `Ctrl+n` is a view identity, not an ordinal."
  //
  // THERE IS NO `Ctrl+3` ROW BELOW, AND THAT IS THE POINT. The strip has
  // three tabs and the keys are 1, 2 and 4, which reads like an off-by-one
  // to anybody who has not read that ruling; `session_layering_test.dart`
  // RULE 14e is the test that stops the tidy-up. Binding Schedule to
  // `Ctrl+3` to close the gap would break the same muscle memory twice:
  // once now, and once in v1.1 when the Rear Panel takes its key back.
  KeyBinding(
    id: KeyBindingId.switchViewRack,
    scope: KeyScope.global,
    trigger: LogicalKeyboardKey.digit1,
    primary: true,
    label: 'Switch to the Rack view',
    intent: SwitchViewIntent(1),
    source: 'docs/04 §8 · CR-071',
  ),
  KeyBinding(
    id: KeyBindingId.switchViewSchematic,
    scope: KeyScope.global,
    trigger: LogicalKeyboardKey.digit2,
    primary: true,
    label: 'Switch to the Schematic view',
    intent: SwitchViewIntent(2),
    source: 'docs/04 §8 · CR-071',
  ),
  KeyBinding(
    id: KeyBindingId.switchViewSchedule,
    scope: KeyScope.global,
    trigger: LogicalKeyboardKey.digit4,
    primary: true,
    label: 'Switch to the Schedule view',
    intent: SwitchViewIntent(4),
    source: 'docs/04 §8 · CR-071',
    note:
        'digit 4, not 3, and forever. CR-071 reserves Ctrl+3 for the v1.1 '
        'Rear Panel view; Ctrl+n is a view identity, not an ordinal.',
  ),

  // ── rack ─────────────────────────────────────────────────────────────
  KeyBinding(
    id: KeyBindingId.deleteSelection,
    scope: KeyScope.rack,
    trigger: LogicalKeyboardKey.delete,
    label: 'Delete the selection',
    intent: DeleteSelectionIntent(),
    source: 'docs/04 §8',
  ),
  KeyBinding(
    id: KeyBindingId.deleteSelectionBackspace,
    scope: KeyScope.rack,
    trigger: LogicalKeyboardKey.backspace,
    label: 'Delete the selection',
    intent: DeleteSelectionIntent(),
    source: 'docs/04 §8',
  ),
  // UNDO AND REDO WERE THE HAND-ROLLED HALF OF D7, and the extraction
  // folds it in. The source carried FOUR entries here — `Ctrl+Z`,
  // `Cmd+Z`, `Ctrl+Shift+Z`, `Cmd+Shift+Z` — because somebody had already
  // anticipated macOS and paid for it in duplicate literals. `primary`
  // is the mechanism those literals were approximating, so two rows now
  // say what four said, and say it for every platform rather than two.
  //
  // WHAT THIS CHANGES ON WINDOWS, stated rather than buried: the literal
  // `meta:` entries also bound `Win+Z` and `Win+Shift+Z` there. No
  // document binds the Windows key — docs/04 §8's table has no `Win+`
  // chord — so those two were collateral of hard-coding `meta` for macOS,
  // and they are gone. Nothing else about the Windows keymap moves.
  KeyBinding(
    id: KeyBindingId.undo,
    scope: KeyScope.rack,
    trigger: LogicalKeyboardKey.keyZ,
    primary: true,
    label: 'Undo',
    intent: UndoIntent(),
    source: 'docs/03 §5',
    note:
        'SCOPED TO THE RACK TAB, while its own handler is gated on "no '
        'text field has focus" — which reads as document-global and is '
        'not. The Shortcuts subtree is RackCanvasScreen, so Ctrl+Z does '
        'nothing on the Schematic and Schedule tabs. That is the same '
        'failure app_shell.dart post-mortems for Ctrl+S; promoting it to '
        'KeyScope.global is a rebinding and belongs to a ruling.',
  ),
  KeyBinding(
    id: KeyBindingId.redo,
    scope: KeyScope.rack,
    trigger: LogicalKeyboardKey.keyZ,
    primary: true,
    shift: true,
    label: 'Redo',
    intent: RedoIntent(),
    source: 'docs/03 §5',
  ),
  KeyBinding(
    id: KeyBindingId.redoAlternate,
    scope: KeyScope.rack,
    trigger: LogicalKeyboardKey.keyY,
    primary: true,
    label: 'Redo',
    intent: RedoIntent(),
    source: 'docs/03 §5',
    note:
        'Ctrl+Y is the WINDOWS redo idiom and resolves to Cmd+Y on macOS, '
        'where redo is Cmd+Shift+Z and Cmd+Y is not a redo key in any '
        'Apple guideline. Left exactly as extracted: dropping it on macOS '
        'is a keymap decision, not a mechanism.',
  ),
  KeyBinding(
    id: KeyBindingId.focusPaletteSearch,
    scope: KeyScope.rack,
    trigger: LogicalKeyboardKey.slash,
    label: 'Focus the palette search field',
    intent: FocusPaletteSearchIntent(),
    source: 'docs/04 §3.2 · §8',
  ),
  // docs/04 §3.4: the insertion caret (no selection) / keyboard nudge (a
  // selection exists). Every activator here is BARE, and
  // `SingleActivator`'s exact-modifier match is the deferral mechanism for
  // the out-of-scope modified variants (`Shift+↑↓` extend, `Ctrl+↑↓` next
  // free, `Alt+↑↓` swap): they simply do not trigger these.
  // THE ↑/↓ LABELS ARE SHARED WITH THE SCHEMATIC'S PIN CARET (DR-011.6),
  // and the wording is the union `Esc` already models: one chord, one
  // meaning, stated as everything it does in the scopes that bind it. The
  // rack's "1U" figure moved into the note rather than being deleted —
  // canon §1.10 principle (b) is about MEANING, and "move the caret" is
  // the meaning in both views; the step size is a rack detail that would
  // simply be false on a sheet.
  //
  // The rejected alternative was widening `meaningDrift` to permit
  // per-scope labels. It is the smaller edit and the wrong one: the rule
  // exists to stop one key meaning two things, and a keyboard-only user
  // cannot see a scope boundary.
  KeyBinding(
    id: KeyBindingId.caretUp,
    scope: KeyScope.rack,
    trigger: LogicalKeyboardKey.arrowUp,
    label: 'Caret up · nudge the selection up',
    intent: CaretUpIntent(),
    source: 'docs/04 §3.4 · §8 · canon §11.11.6',
    note:
        'In the rack the step is 1U. Shared verbatim with the schematic '
        'pin caret so meaningDrift stays green — see DR-011.6.',
  ),
  KeyBinding(
    id: KeyBindingId.caretDown,
    scope: KeyScope.rack,
    trigger: LogicalKeyboardKey.arrowDown,
    label: 'Caret down · nudge the selection down',
    intent: CaretDownIntent(),
    source: 'docs/04 §3.4 · §8 · canon §11.11.6',
    note: 'In the rack the step is 1U. See caretUp.',
  ),
  KeyBinding(
    id: KeyBindingId.caretHome,
    scope: KeyScope.rack,
    trigger: LogicalKeyboardKey.home,
    label: 'Caret to U1 · nudge the selection to its lowest fit',
    intent: CaretHomeIntent(),
    source: 'docs/04 §3.4 · §8',
  ),
  KeyBinding(
    id: KeyBindingId.caretEnd,
    scope: KeyScope.rack,
    trigger: LogicalKeyboardKey.end,
    label: 'Caret to the top U · nudge the selection to its highest fit',
    intent: CaretEndIntent(),
    source: 'docs/04 §3.4 · §8',
  ),
  KeyBinding(
    id: KeyBindingId.caretPageUp,
    scope: KeyScope.rack,
    trigger: LogicalKeyboardKey.pageUp,
    label: 'Caret up 10U · nudge the selection up 10U',
    intent: CaretPageUpIntent(),
    source: 'docs/04 §3.4 · §8',
  ),
  KeyBinding(
    id: KeyBindingId.caretPageDown,
    scope: KeyScope.rack,
    trigger: LogicalKeyboardKey.pageDown,
    label: 'Caret down 10U · nudge the selection down 10U',
    intent: CaretPageDownIntent(),
    source: 'docs/04 §3.4 · §8',
  ),
  // THE LABEL IS SHARED WITH THE SCHEMATIC AND THE DIALOGS ON PURPOSE.
  // canon §1.10 principle (b): "a key means the same thing in every view
  // or it means nothing". `Esc` cancels what is in flight and then clears
  // — in the rack it reverts a drag, cancels a compaction preview and
  // deselects; on the sheet it drops focus and then the selection; in a
  // dialog it is Cancel. Three `Intent`s because three surfaces handle it,
  // ONE label because it is one meaning, and [KeymapConflictKind.
  // meaningDrift] is what fails if somebody changes one of them.
  KeyBinding(
    id: KeyBindingId.rackCancel,
    scope: KeyScope.rack,
    trigger: LogicalKeyboardKey.escape,
    label: 'Cancel · dismiss · clear the selection',
    intent: RackCancelIntent(),
    source: 'docs/04 §3.3 · §3.6 · §8',
  ),
  KeyBinding(
    id: KeyBindingId.rackSettings,
    scope: KeyScope.rack,
    trigger: LogicalKeyboardKey.keyU,
    primary: true,
    alt: true,
    label: 'Rack settings',
    intent: RackSettingsIntent(),
    source: 'docs/04 §4 · §8',
    note:
        'Ctrl+Alt is AltGr on Windows, so on layouts where AltGr+U is a '
        'printable character this eats it. docs/04 §8 accepts the '
        'collision when the canvas has focus and removes it where a '
        'character could be typed, by gating on "no text field has '
        'focus". The collision does NOT exist on macOS, where the chord '
        'resolves to Cmd+Option+U.',
  ),
  KeyBinding(
    id: KeyBindingId.newRack,
    scope: KeyScope.rack,
    trigger: LogicalKeyboardKey.keyN,
    primary: true,
    alt: true,
    label: 'New rack',
    intent: NewRackIntent(),
    source: 'docs/04 §8 · §9',
    note: 'The AltGr caveat on rackSettings applies to AltGr+N identically.',
  ),
  // Bound BARE, and therefore inside the same subtree as the palette
  // search box and the focusable palette rows. `_ApplyCompactionAction`
  // is a real `Action` whose `isActionEnabled` is false when no preview is
  // open, so the key falls through unhandled rather than being swallowed.
  //
  // `Ctrl+B` is deliberately ABSENT: §3.6/AC-045 keep it RESERVED AND
  // UNBOUND in v1.
  KeyBinding(
    id: KeyBindingId.applyCompaction,
    scope: KeyScope.rack,
    trigger: LogicalKeyboardKey.enter,
    label: 'Commit what is in flight',
    intent: ApplyCompactionIntent(),
    source: 'docs/04 §3.6 · canon §11.11.6',
    note:
        "The label is DR-011.6's retrofit: it used to read 'Apply the "
        "compaction preview', which the schematic's Enter (commit the "
        'wire) could not share, and meaningDrift compares labels across '
        'scopes. Here the thing in flight is the compaction preview; on '
        'the sheet it is the wire.',
  ),

  // ── schematic ────────────────────────────────────────────────────────
  // docs/05 §11.2 / §14: "`1`–`8` solo by index; `` ` `` shows all". BARE,
  // so any modifier combination falls through — there is no `Ctrl+1`
  // collision with the global view switch, because `SingleActivator`
  // matches modifiers exactly and [arbitrate] checks that it still does.
  KeyBinding(
    id: KeyBindingId.soloDomain1,
    scope: KeyScope.schematic,
    trigger: LogicalKeyboardKey.digit1,
    label: 'Solo domain 1',
    intent: SoloDomainIntent(1),
    source: 'docs/05 §11.2 · §14',
  ),
  KeyBinding(
    id: KeyBindingId.soloDomain2,
    scope: KeyScope.schematic,
    trigger: LogicalKeyboardKey.digit2,
    label: 'Solo domain 2',
    intent: SoloDomainIntent(2),
    source: 'docs/05 §11.2 · §14',
  ),
  KeyBinding(
    id: KeyBindingId.soloDomain3,
    scope: KeyScope.schematic,
    trigger: LogicalKeyboardKey.digit3,
    label: 'Solo domain 3',
    intent: SoloDomainIntent(3),
    source: 'docs/05 §11.2 · §14',
  ),
  KeyBinding(
    id: KeyBindingId.soloDomain4,
    scope: KeyScope.schematic,
    trigger: LogicalKeyboardKey.digit4,
    label: 'Solo domain 4',
    intent: SoloDomainIntent(4),
    source: 'docs/05 §11.2 · §14',
  ),
  KeyBinding(
    id: KeyBindingId.soloDomain5,
    scope: KeyScope.schematic,
    trigger: LogicalKeyboardKey.digit5,
    label: 'Solo domain 5',
    intent: SoloDomainIntent(5),
    source: 'docs/05 §11.2 · §14',
  ),
  KeyBinding(
    id: KeyBindingId.soloDomain6,
    scope: KeyScope.schematic,
    trigger: LogicalKeyboardKey.digit6,
    label: 'Solo domain 6',
    intent: SoloDomainIntent(6),
    source: 'docs/05 §11.2 · §14',
  ),
  KeyBinding(
    id: KeyBindingId.soloDomain7,
    scope: KeyScope.schematic,
    trigger: LogicalKeyboardKey.digit7,
    label: 'Solo domain 7',
    intent: SoloDomainIntent(7),
    source: 'docs/05 §11.2 · §14',
  ),
  KeyBinding(
    id: KeyBindingId.soloDomain8,
    scope: KeyScope.schematic,
    trigger: LogicalKeyboardKey.digit8,
    label: 'Solo domain 8',
    intent: SoloDomainIntent(8),
    source: 'docs/05 §11.2 · §14',
  ),
  KeyBinding(
    id: KeyBindingId.showAllDomains,
    scope: KeyScope.schematic,
    trigger: LogicalKeyboardKey.backquote,
    label: 'Show all domains',
    intent: ShowAllDomainsIntent(),
    source: 'docs/05 §11.2 · §14',
  ),
  KeyBinding(
    id: KeyBindingId.focusSelection,
    scope: KeyScope.schematic,
    trigger: LogicalKeyboardKey.keyF,
    label: 'Focus the selection',
    intent: FocusSelectionIntent(),
    source: 'docs/05 §11.4 · canon §1.10',
    note:
        'Shift+F (Isolate) is deliberately absent, and F is UNBOUND IN '
        'THE RACK — canon §1.10 principle (c) rules that unmodified '
        'letters are view-local and must not collide between views '
        'sharing the canvas. KeymapConflictKind.letterCollision is what '
        'keeps that true.',
  ),
  KeyBinding(
    id: KeyBindingId.schematicCancel,
    scope: KeyScope.schematic,
    trigger: LogicalKeyboardKey.escape,
    label: 'Cancel · dismiss · clear the selection',
    intent: SchematicCancelIntent(),
    source: 'docs/05 §11.4 · docs/04 §8',
    note:
        'M2-F adds a rung ABOVE the two it had: a wire in flight is what '
        'Esc cancels first (docs/05 §7). Same binding, same label, one '
        'more limb in the gate — which is exactly what layering a key '
        'means when only isActionEnabled can decline one.',
  ),

  // ── removing a cable (#96, the field's first finding) ─────────────────
  //
  // THE SAME CHORD, THE SAME INTENT AND THE SAME LABEL AS THE RACK'S, which
  // is not laziness but the rule: `KeymapConflictKind.meaningDrift` holds
  // canon §1.10 principle (b) — *"a key means the same thing in every
  // view"* — by failing on one chord carrying two labels across two scopes.
  // `Delete` means "delete the selection" on both canvases; WHAT is
  // selectable differs, and that is a property of the view rather than of
  // the key.
  //
  // TWO ROWS BECAUSE THE RACK HAS TWO. `Backspace` is the same meaning for
  // the keyboard that has no `Delete`, and a schematic that bound only
  // `Delete` would be the laptop user's cable that cannot be removed.
  //
  // `letterCollision` does not apply and is worth saying so nobody adds a
  // note claiming it does: that rule governs UNMODIFIED SINGLE LETTERS
  // carried between two canvases one tab apart, and neither of these is a
  // letter.
  KeyBinding(
    id: KeyBindingId.deleteCable,
    scope: KeyScope.schematic,
    trigger: LogicalKeyboardKey.delete,
    label: 'Delete the selection',
    intent: DeleteSelectionIntent(),
    source: 'docs/04 §8 · docs/05 §7',
  ),
  KeyBinding(
    id: KeyBindingId.deleteCableBackspace,
    scope: KeyScope.schematic,
    trigger: LogicalKeyboardKey.backspace,
    label: 'Delete the selection',
    intent: DeleteSelectionIntent(),
    source: 'docs/04 §8 · docs/05 §7',
  ),

  // ── the connect gesture's keyboard route (DR-011.6, docs/05 §7 · §14) ──
  //
  // BUILT AND DRIVEN FIRST, NOT LAST. DR-011's "the order that matters":
  // M1's equivalent clause was REFUTED by the user, who hit the time target
  // but needed a mouse, because each placement made the new device the sole
  // selection and the caret was consulted only when the selection was
  // empty — so back-to-back Enters used the caret once and then fell back.
  // The caret here is therefore AUTHORITATIVE once it exists and the
  // selection only seeds it, and a commit leaves it on the pin the user
  // just landed on so the next `W` starts from there.
  KeyBinding(
    id: KeyBindingId.beginWire,
    scope: KeyScope.schematic,
    trigger: LogicalKeyboardKey.keyW,
    label: 'Begin a wire from the pin under the caret',
    intent: BeginWireIntent(),
    source: 'docs/05 §7 · §14',
    note:
        'W is UNBOUND IN THE RACK, which KeymapConflictKind.letterCollision '
        'keeps true — canon §1.10 principle (c).',
  ),
  KeyBinding(
    id: KeyBindingId.quickAddCommit,
    scope: KeyScope.builder,
    trigger: LogicalKeyboardKey.enter,
    label: 'Commit what is in flight',
    intent: QuickAddCommitIntent(),
    source: 'docs/06 §4.1 · §9.1',
    note:
        'THE BINDING THE THIRTEEN-STEP PATH IS MADE OF. Each of docs/06 '
        "§9.1's steps 6 to 13 is one command and one Enter, and the "
        'criterion is a stopwatch, so this key is the difference between '
        'eight keystrokes and eight dialogs. '
        'THE THIRD INTENT UNDER THIS ONE LABEL, joining applyCompaction '
        "and commitWire under DR-011.6's rule, and it was very nearly "
        'given a label of its own. meaningDrift REFUSED IT, correctly: a '
        'keyboard-only user cannot see a scope boundary, so one key may '
        'wear one meaning across the product. The generalisation holds '
        'without straining, which is the test for whether a shared label '
        'is honest or a fudge: a Quick Add command typed and not yet run '
        'IS something in flight, exactly as a wire is and as a compaction '
        'preview is. Three surfaces, three Actions maps, three intent '
        'types, one meaning.',
  ),
  KeyBinding(
    id: KeyBindingId.builderJumpToPorts,
    scope: KeyScope.builder,
    trigger: LogicalKeyboardKey.enter,
    primary: true,
    label: 'Go to ports',
    intent: JumpToPortsIntent(),
    source: 'docs/06 §9.1 step 5',
    note:
        'THE DRILL FOUND THIS MISSING. §9.1 spends step 5 on Ctrl+Enter '
        'and the binding had never been built, so the 93-second run '
        'reached for the mouse there. `SingleActivator` matches '
        'modifiers EXACTLY, so this does not fire while the bare Enter '
        'above is committing a Quick Add command, and it shadows no '
        'framework default because WidgetsApp binds bare Enter only. '
        'It does NOT gate on the required fields being satisfied: '
        'AC-049 took the metadata form off the critical path, so a jump '
        'refused because a field is blank would reintroduce exactly the '
        'gate that ruling removed.',
  ),
  KeyBinding(
    id: KeyBindingId.builderFillDown,
    scope: KeyScope.builder,
    trigger: LogicalKeyboardKey.keyD,
    primary: true,
    label: 'Fill down',
    intent: BuilderFillDownIntent(),
    source: 'docs/06 §4.6',
    note:
        'THE SPREADSHEET KEY, AND HERE IT HAS A RANGE. Two rows rather '
        'than one widened row, because `bindingFor` is a `firstWhere` '
        'over the id and because the acts differ in reach: the Structure '
        "editor's table has no selection, so its `Ctrl+D` copies from "
        'the cell ABOVE, while DR-061 gave this grid a row range to fill '
        'from the top of. '
        'ONE LABEL ACROSS BOTH, AND `meaningDrift` INSISTED. It was '
        'written as "Fill down the selection" beside the structure '
        "row's \"Fill down from the cell above\", and arbitration "
        'refused the pair on sight. It was right: a keyboard-only user '
        'cannot see a scope boundary, so one chord wears one meaning '
        "across the product (DR-011.6's rule). The generalisation holds "
        'without straining, which is the test: both copy a value down a '
        'column, and the reach is a detail for the note rather than a '
        'second meaning. The scope-specific half now lives here, where '
        'the next implementer stands. '
        'IT SHADOWS NO FRAMEWORK DEFAULT. `Ctrl+D` is not a Flutter text '
        'editing binding on any platform this ships to, which matters '
        'because focus is almost always inside a cell `TextField` when '
        'it is pressed.',
  ),
  KeyBinding(
    id: KeyBindingId.builderFillSeries,
    scope: KeyScope.builder,
    trigger: LogicalKeyboardKey.keyD,
    primary: true,
    shift: true,
    label: 'Fill a series down the selection',
    intent: BuilderFillSeriesIntent(),
    source: 'docs/06 §4.6 · DR-062',
    note:
        'ITS OWN LABEL AND NOT A SHARE WITH FILL DOWN, because the two '
        'do different things to the same rows: one copies, one counts. '
        "`meaningDrift`'s test is whether the generalisation holds "
        'without straining, and "fill" alone would have to cover both, '
        'which is how a person presses the wrong one. '
        'THE SEQUENCE IS INFERRED FROM THE TOP CELL (DR-062), because '
        "docs/06 §4.6's \"the label pattern\" names an artifact that is "
        'stored nowhere in the tree.',
  ),
  KeyBinding(
    id: KeyBindingId.builderCopyCells,
    scope: KeyScope.builder,
    trigger: LogicalKeyboardKey.keyC,
    primary: true,
    label: 'Copy cells',
    intent: BuilderCopyCellsIntent(),
    source: 'docs/06 §4.6',
    note:
        'THE ESCAPE HATCH THAT MAKES THE GRID TRUSTWORTHY (`#210`). '
        'docs/06 §4 rests its whole case on integrators living in Excel, '
        'and a grid they cannot get their own rows OUT of is one they '
        'have to take on faith. A header row leads the clipboard so what '
        'lands in Excel is a sheet rather than eight anonymous columns. '
        'IT SHADOWS NO FRAMEWORK DEFAULT IN A CELL. Flutter binds '
        '`Ctrl+C` to copy inside a focused text field, and that is '
        'exactly where focus is when a person presses it here, so this '
        'Action is DISABLED while a text selection exists: copying two '
        'characters out of a label is what the key means then, and '
        'taking it would be the shadowing `frameworkShadowedBindings` '
        'exists to catch.',
  ),
  KeyBinding(
    id: KeyBindingId.builderPasteCells,
    scope: KeyScope.builder,
    trigger: LogicalKeyboardKey.keyV,
    primary: true,
    label: 'Paste cells',
    intent: BuilderPasteCellsIntent(),
    source: 'docs/06 §4.6',
    note:
        "ONE LABEL WITH THE STRUCTURE EDITOR'S ROW, which read \"Paste "
        'tab-separated cells from the caret" and now reads the same four '
        'words as this one. `meaningDrift` refuses two labels on one '
        'chord because a keyboard-only user cannot see a scope boundary, '
        'and it refused `fillDown` for the same reason one task ago. The '
        'two acts generalise without straining: both paste a block of '
        'cells from the caret into a grid. '
        'A PASTE DOES NOT CREATE ROWS, in either grid, and both say so '
        'by how much rather than truncating.',
  ),
  KeyBinding(
    id: KeyBindingId.builderMoveRowUp,
    scope: KeyScope.builder,
    trigger: LogicalKeyboardKey.arrowUp,
    alt: true,
    label: 'Move the selected rows up',
    intent: BuilderMoveRowIntent(up: true),
    source: 'docs/06 §4.6 · CR-027 · DR-064',
    note:
        'THE KEYBOARD HALF OF THE DRAG HANDLE, and the half a person on '
        'a laptop trackpad actually uses. `PortDef.order` is a '
        '`FracIndex`, so this writes the rows that move and nothing '
        'else: §4.6 rules that a reorder is not a renumber of the bank. '
        'IT STOPS AT THE BAND EDGE AND SAYS SO (DR-064). Crossing would '
        "have to rewrite the port's `bankKey`, and a structural edit "
        'delivered by an arrow key is how a jack ends up in the wrong '
        'bank on a printed panel. The Bank column is the way across, and '
        'the refusal names it. '
        'ALT AND NOT SHIFT, because Shift+Arrow is the range extension '
        'every grid on earth binds and this one will want it. Alt+Arrow '
        'is what a spreadsheet, an outliner and a task list all use for '
        'moving a row, so the chord is where a hand already goes.',
  ),
  KeyBinding(
    id: KeyBindingId.builderMoveRowDown,
    scope: KeyScope.builder,
    trigger: LogicalKeyboardKey.arrowDown,
    alt: true,
    label: 'Move the selected rows down',
    intent: BuilderMoveRowIntent(up: false),
    source: 'docs/06 §4.6 · CR-027 · DR-064',
    note: 'See builderMoveRowUp.',
  ),
  KeyBinding(
    id: KeyBindingId.builderDuplicateRows,
    scope: KeyScope.builder,
    trigger: LogicalKeyboardKey.keyJ,
    primary: true,
    label: 'Duplicate the selected rows',
    intent: BuilderDuplicateRowsIntent(),
    source: 'docs/06 §4.6 · DR-078 §11.77.1',
    note:
        'IT SHADOWS NO FRAMEWORK DEFAULT, and that was checked over '
        '`default_text_editing_shortcuts.dart` rather than recalled. '
        '`Ctrl+J` appears in no platform map, which matters because '
        'focus is almost always inside a cell `TextField` when a grid '
        'chord is pressed. Four of the five chords M4-F6 through F10 add '
        'passed that check; `Ctrl+T` did not, and DR-078 §11.77.1 takes '
        'it anyway '
        'with the cost recorded in docs/13 §3.6. '
        'THE ACT IS "BELOW THE SELECTION" AND THEREFORE MINTS `order`, '
        'so it refuses while a sort badge is showing, on the same ground '
        '§4.6 disables reorder there: the person is not looking at the '
        'declared order and "below" is a claim about it.',
  ),
  KeyBinding(
    id: KeyBindingId.builderRenumber,
    scope: KeyScope.builder,
    trigger: LogicalKeyboardKey.keyR,
    primary: true,
    label: 'Renumber the selected rows',
    intent: BuilderRenumberIntent(),
    source: 'docs/06 §4.6 · DR-078',
    note:
        'IT SHADOWS NO FRAMEWORK DEFAULT: `Ctrl+R` appears in no platform '
        'map of `default_text_editing_shortcuts.dart`, checked over the '
        'source rather than recalled. '
        'ITS OWN LABEL AND NOT A SHARE WITH `builderFillSeries`, because '
        'the two do different things to the same rows and meaningDrift '
        'tests whether the generalisation holds without straining. A fill '
        'series CONTINUES what the top cell already says (DR-062 infers '
        'the sequence); a renumber REPLACES it with a pattern somebody '
        'typed into a dialog. One counts on, one restates.',
  ),
  KeyBinding(
    id: KeyBindingId.quickAddComplete,
    scope: KeyScope.builder,
    trigger: LogicalKeyboardKey.arrowRight,
    label: 'Caret right',
    intent: QuickAddCompleteIntent(),
    source: 'docs/06 §4.1 · AC-050/A2.4',
    note:
        'AUTOCOMPLETE IS NOT OPTIONAL (AC-050/A2.4, board #216): the '
        'discoverability argument for shipping a DSL at all is void '
        "without it, and the population M4's exit criterion names is "
        '"a user who has seen the tool once", who does not know `hdbt` '
        'exists. '
        'IT IS NOT `Tab`, AND THIS GATE IS WHY. `Tab` was the design the '
        'user picked and meaningDrift refused it: the schematic already '
        'spends `Tab` on "next candidate pin for the wire in flight", '
        'and advancing THROUGH offers is close to the opposite of taking '
        'one, so no shared label was honest. Right-arrow is the accept '
        'in fish and zsh-autosuggestions, so it is a convention rather '
        'than an invention, and it shares a label with pinCaretRight '
        'WITHOUT STRAINING: the caret moves right, through the '
        'suggestion when one is showing. Settled by the user on '
        '2026-08-15 after the collision was put to them. '
        'GATED ON AN OFFER EXISTING AND ON THE CARET BEING AT THE END OF '
        'THE LINE, through a real Action whose isActionEnabled is false '
        'otherwise. Right-arrow MOVES THE CARET in a text field, so a '
        'binding that swallowed it would stop a user navigating their '
        'own command; what you can see is exactly what the key takes.',
  ),
  KeyBinding(
    id: KeyBindingId.commitWire,
    scope: KeyScope.schematic,
    trigger: LogicalKeyboardKey.enter,
    label: 'Commit what is in flight',
    intent: CommitWireIntent(),
    source: 'docs/05 §7 · canon §11.11.6',
    note:
        "ONE LABEL WITH THE RACK'S applyCompaction, per DR-011.6. Two "
        'intents because two surfaces handle it; one label because it is '
        'one meaning, and meaningDrift is what fails if either moves.',
  ),
  // CHAIN-DRAW NEEDS ITS OWN ROW, and that is a fact about
  // `SingleActivator` rather than a second meaning. It matches modifiers
  // EXACTLY, so the bare `Enter` above does not fire while `Shift` is
  // held — docs/05:483's "Shift held at commit" would simply do nothing
  // without this row. Same intent, same handler, same label; the screen
  // reads the live modifier to decide whether to re-arm.
  KeyBinding(
    id: KeyBindingId.commitWireChained,
    scope: KeyScope.schematic,
    trigger: LogicalKeyboardKey.enter,
    shift: true,
    label: 'Commit what is in flight',
    intent: CommitWireIntent(),
    source: 'docs/05 §7 · §14 · canon §11.12.1',
    note:
        'Shift+Enter is the keyboard half of chain-draw: commit, then '
        're-arm from the sink device’s matching output (DR-012.1). It '
        'carries the SAME label and intent as the bare Enter row, because '
        'it is the same meaning with a modifier that changes what happens '
        'after — not a second key.',
  ),
  KeyBinding(
    id: KeyBindingId.nextCandidatePin,
    scope: KeyScope.schematic,
    trigger: LogicalKeyboardKey.tab,
    label: 'Next candidate pin for the wire in flight',
    intent: NextCandidatePinIntent(),
    source: 'docs/05 §7',
    note:
        'GATED ON A WIRE BEING ARMED, so an idle sheet lets Tab do focus '
        'traversal. The canvas autofocuses; a schematic that owned bare '
        'Tab unconditionally would be a surface a keyboard-only user '
        'could enter and never leave, which fails the very requirement '
        '(AC-058/D11) this route exists to meet.',
  ),
  KeyBinding(
    id: KeyBindingId.previousCandidatePin,
    scope: KeyScope.schematic,
    trigger: LogicalKeyboardKey.tab,
    shift: true,
    label: 'Previous candidate pin for the wire in flight',
    intent: PreviousCandidatePinIntent(),
    source: 'docs/05 §7',
    note: 'See nextCandidatePin: armed only.',
  ),
  // THE ARROWS ARE HOW A PIN IS REACHED AT ALL, armed or not, and they are
  // geometric rather than ordinal — see [MovePinCaretIntent]. ↑/↓ carry the
  // rack caret rows' labels verbatim (DR-011.6); ←/→ are schematic-only and
  // so have no cross-scope label to match.
  KeyBinding(
    id: KeyBindingId.pinCaretUp,
    scope: KeyScope.schematic,
    trigger: LogicalKeyboardKey.arrowUp,
    label: 'Caret up · nudge the selection up',
    intent: MovePinCaretIntent(AxisDirection.up),
    source: 'docs/05 §7 · canon §11.11.6',
    note:
        'Shared label with the rack caret row. Nothing is nudged on the '
        'sheet — M2-F builds no symbol-move gesture (§11.11.7) — so the '
        "label is the union of the two scopes, exactly as Esc's is.",
  ),
  KeyBinding(
    id: KeyBindingId.pinCaretDown,
    scope: KeyScope.schematic,
    trigger: LogicalKeyboardKey.arrowDown,
    label: 'Caret down · nudge the selection down',
    intent: MovePinCaretIntent(AxisDirection.down),
    source: 'docs/05 §7 · canon §11.11.6',
    note: 'See pinCaretUp.',
  ),
  KeyBinding(
    id: KeyBindingId.pinCaretLeft,
    scope: KeyScope.schematic,
    trigger: LogicalKeyboardKey.arrowLeft,
    label: 'Caret to the pin on the left',
    intent: MovePinCaretIntent(AxisDirection.left),
    source: 'docs/05 §7',
  ),
  KeyBinding(
    id: KeyBindingId.pinCaretRight,
    scope: KeyScope.schematic,
    trigger: LogicalKeyboardKey.arrowRight,
    // ONE LABEL WITH THE BUILDER'S quickAddComplete, DR-011.6's shape
    // applied to a second key. The generalisation is honest: in the
    // schematic the caret moves to the pin on the right, in Quick Add
    // it moves right through a ghosted suggestion. meaningDrift is
    // what holds the two together, and it REFUSED the first draft of
    // this pair when the builder's row was `Tab`.
    label: 'Caret right',
    intent: MovePinCaretIntent(AxisDirection.right),
    source: 'docs/05 §7',
  ),
  // #93's SELECTION HALF. `Shift` is the last modifier this canvas has
  // spare — `Ctrl` is docs/05 §14's magnet suppressor and `Alt` is
  // DR-001's drawn-wire hover — which is why the selection is a
  // contiguous RUN and not an arbitrary set. `pin_selection.dart`'s
  // header carries that arithmetic.
  KeyBinding(
    id: KeyBindingId.extendPinSelectionDown,
    scope: KeyScope.schematic,
    trigger: LogicalKeyboardKey.arrowDown,
    shift: true,
    label: 'Extend the pin selection along the bank',
    intent: ExtendPinSelectionIntent(1),
    source: 'docs/05:484 · DR-012.2',
    note:
        'ORDINAL, not geometric — the bare arrow one Shift away is the '
        'geometric one. See ExtendPinSelectionIntent. The corpus writes '
        'multi-draw as a pointer gesture only; this pair is the keyboard '
        'route added for parity, on the chord docs/04 §3.4 already '
        'reserves for "extend".',
  ),
  KeyBinding(
    id: KeyBindingId.extendPinSelectionUp,
    scope: KeyScope.schematic,
    trigger: LogicalKeyboardKey.arrowUp,
    shift: true,
    label: 'Extend the pin selection along the bank',
    intent: ExtendPinSelectionIntent(-1),
    source: 'docs/05:484 · DR-012.2',
    note: 'See extendPinSelectionDown.',
  ),

  // ── dialog ───────────────────────────────────────────────────────────
  // ONE ROW FOR THREE DIALOGS. Each returns a different value — cancel,
  // keepForLater, the view's dismiss action id — but each returns the
  // CONSERVATIVE one, the answer that cannot lose work, and the key means
  // the same thing in all three. Their own comments already said so
  // ("Esc is Cancel, everywhere, always"); this is that sentence made
  // into one declaration instead of three.
  //
  // Bound through `CallbackShortcuts` rather than an `Intent`, because a
  // dialog's answer is a RETURN VALUE from `Navigator.pop` and not a
  // command dispatched into a subtree. [dialogDismissShortcut] is the seam
  // — the activator still comes from here, so the row is in the table and
  // arbitration sees it.
  // ── structure ────────────────────────────────────────────────────────
  // BOARD #148'S OWN LIST is "fill-down, tab order, paste", and only two
  // of the three are here. TAB ORDER IS NOT A BINDING in this app and
  // must not become one: every editable cell in the drop table is a real
  // focusable control, always, so Flutter's own traversal already walks
  // them in the order they are drawn. A `Tab` row here would shadow the
  // framework (see `frameworkShadowedBindings`) to reimplement what it
  // already does correctly.
  KeyBinding(
    id: KeyBindingId.fillDown,
    scope: KeyScope.structure,
    trigger: LogicalKeyboardKey.keyD,
    primary: true,
    label: 'Fill down',
    intent: FillDownIntent(),
    source: 'docs/07 §4.1',
    note:
        'The spreadsheet key, and the spreadsheet meaning for a single '
        'selected cell: copy what is directly above. There is no range '
        'selection in the table yet, so there is no range to fill. '
        'THE LABEL LOST ITS SECOND HALF when M4-F1 bound the same chord '
        'in the port grid: it read "Fill down from the cell above", and '
        '`meaningDrift` refuses two labels on one chord because a '
        'keyboard-only user cannot see a scope boundary. The reach is '
        "the note's business, not the label's. DR-061 §11.60.6 already "
        "records that this table's own selection question is open; when "
        "it is answered, this row and the builder's converge outright.",
  ),
  KeyBinding(
    id: KeyBindingId.pasteCells,
    scope: KeyScope.structure,
    trigger: LogicalKeyboardKey.keyV,
    primary: true,
    label: 'Paste cells',
    intent: PasteCellsIntent(),
    source: 'docs/07 §4.1 · §5',
    note:
        'SHADOWS NOTHING AND STEALS NOTHING: text fields handle paste '
        'through the framework, and this row only fires when the table '
        'has the focus. docs/07 §5 makes the contractor spreadsheet the '
        'ENTRY path, and a person with one open will try this before '
        'they find an importer.',
  ),
  KeyBinding(
    id: KeyBindingId.dialogDismiss,
    scope: KeyScope.dialog,
    trigger: LogicalKeyboardKey.escape,
    label: 'Cancel · dismiss · clear the selection',
    intent: DismissDialogIntent(),
    source: 'docs/04 §8',
    note:
        'Declared for the table and for arbitration; DISPATCHED as a '
        'callback. The intent is never handled by an Actions map — see '
        'dialogDismissShortcut.',
  ),
];

/// The dialog `Esc`, present so the registry has one row per binding.
///
/// NEVER HANDLED BY AN `Actions` MAP. The three dialogs pop a value rather
/// than dispatch a command, so they bind through [dialogDismissShortcut];
/// this type exists so the row can be declared in the same shape as every
/// other and appear in the generated table.
final class DismissDialogIntent extends Intent {
  const DismissDialogIntent();
}

// ══════════════════════════════════════════════════════════════════════
// TABLE GENERATION
// ══════════════════════════════════════════════════════════════════════

/// The bindings of one scope, in declaration order.
List<KeyBinding> keyBindingsIn(KeyScope scope) =>
    kKeymap.where((b) => b.scope == scope).toList(growable: false);

/// One binding by name.
KeyBinding keyBindingFor(KeyBindingId id) =>
    kKeymap.firstWhere((b) => b.id == id);

/// One binding's activator, resolved for the current platform.
///
/// The File menu's accelerators come through here, so the key a menu item
/// ADVERTISES and the key the app LISTENS FOR are the same declaration.
SingleActivator keymapActivator(KeyBindingId id, {TargetPlatform? platform}) =>
    keyBindingFor(id).activatorFor(platform ?? defaultTargetPlatform);

/// A whole scope as a `Shortcuts` map.
///
/// MEMOISED PER (scope, platform), and not for micro-optimisation.
/// `ShortcutManager`'s `shortcuts` setter diffs with `mapEquals`, and
/// because `SingleActivator` has no `operator ==` (see the file header)
/// two freshly-built maps NEVER compare equal — so a screen that rebuilt
/// this map each frame would rebuild the manager's trigger index and fire
/// `notifyListeners` on every frame of a drag. Returning the same instance
/// gives `mapEquals` its `identical` fast path. The value is a pure
/// function of its two arguments, so the cache cannot go stale.
Map<ShortcutActivator, Intent> keymapShortcuts(
  KeyScope scope, {
  TargetPlatform? platform,
}) {
  final resolved = platform ?? defaultTargetPlatform;
  return _shortcutCache.putIfAbsent(
    (scope, resolved),
    () =>
        Map<ShortcutActivator, Intent>.unmodifiable(<ShortcutActivator, Intent>{
          for (final binding in keyBindingsIn(scope))
            binding.activatorFor(resolved): binding.intent,
        }),
  );
}

final Map<(KeyScope, TargetPlatform), Map<ShortcutActivator, Intent>>
_shortcutCache = <(KeyScope, TargetPlatform), Map<ShortcutActivator, Intent>>{};

/// The dialog `Esc` binding, as `CallbackShortcuts` wants it.
///
/// The three dialogs each pass their own conservative answer — cancel,
/// keep-for-later, the view's dismiss action id — and none of them names a
/// key, so there is no longer a place for the three to drift apart.
Map<ShortcutActivator, VoidCallback> dialogDismissShortcut(
  VoidCallback onDismiss, {
  TargetPlatform? platform,
}) => <ShortcutActivator, VoidCallback>{
  keymapActivator(KeyBindingId.dialogDismiss, platform: platform): onDismiss,
};

/// docs/04 §8's table, generated.
///
/// "The complete ~40-binding table is generated from the single `Intent`
/// registry … so it cannot drift from the code" — docs/04 §8. This is that
/// generator. A build step that writes it to `build/keymap.md` is the
/// remaining half of the sentence and is not wired yet; what matters for
/// M7's clause is that the table is DERIVED, and that
/// `keymap_arbitration_test.dart` reads the same list it does.
String renderKeymapMarkdown(TargetPlatform platform) {
  final out = StringBuffer()
    ..writeln('# RackMate keymap — ${platform.name}')
    ..writeln()
    ..writeln('Generated from `kKeymap`. Do not edit by hand.')
    ..writeln();
  for (final scope in KeyScope.values) {
    final bindings = keyBindingsIn(scope);
    if (bindings.isEmpty) continue;
    out
      ..writeln('## ${scope.name}')
      ..writeln()
      ..writeln('| Key | Action | Source | Notes |')
      ..writeln('|---|---|---|---|');
    for (final binding in bindings) {
      // A `|` inside a note would end the cell and shift every column
      // after it, so the table would render as garbage rather than as a
      // wrong fact — escape it.
      final note = binding.note?.replaceAll('|', r'\|') ?? '';
      final chord = binding.renderChord(platform);
      // `` ` `` IS ITSELF A BINDING (show all domains, docs/05 §11.2), and
      // a backtick inside a single-backtick span closes it — the cell
      // would render as an empty code span rather than as the key. The
      // markdown escape is a doubled fence with padding spaces.
      final fence = chord.contains('`') ? '`` $chord ``' : '`$chord`';
      out.writeln('| $fence | ${binding.label} | ${binding.source} | $note |');
    }
    out.writeln();
  }
  return out.toString();
}

// ══════════════════════════════════════════════════════════════════════
// ARBITRATION
// ══════════════════════════════════════════════════════════════════════

/// The four ways a keymap can be wrong.
///
/// One per clause of the authority that rules it. A table that merely
/// LISTS bindings does not discharge M7's criterion — the criterion says
/// "no keybinding bound TWICE", which is a claim that has to be computed
/// and can fail.
enum KeymapConflictKind {
  /// Two bindings resolve to the same chord in the same scope.
  ///
  /// M7's exit clause, verbatim. Silent at runtime (see the file header),
  /// which is why it needs a test rather than a code review.
  duplicateInScope,

  /// A view-local binding uses a chord the global scope already owns.
  ///
  /// canon §1.10 principle (a): "view-switching and global-command keys
  /// win over every view-local meaning". Flutter dispatches LEAF -> ROOT,
  /// so the local binding would actually win — the principle would be
  /// inverted, and `Ctrl+S` on the rack tab would stop saving.
  shadowsGlobal,

  /// The same unmodified letter means different things in the rack and the
  /// schematic.
  ///
  /// canon §1.10 principle (c): "unmodified single letters are view-local
  /// tools and must not collide between views that share the canvas". The
  /// two canvases are one tab apart and a user carries the letter across.
  letterCollision,

  /// One chord, two scopes, two different labels.
  ///
  /// canon §1.10 principle (b): "a key means the same thing in every view
  /// or it means nothing". `Esc` is the only chord in this tree that
  /// crosses scopes, and it means cancel in all four places.
  meaningDrift,
}

/// One arbitration failure, in a form a test can print.
final class KeymapConflict {
  const KeymapConflict({
    required this.kind,
    required this.first,
    required this.second,
    required this.chord,
  });

  final KeymapConflictKind kind;
  final KeyBindingId first;
  final KeyBindingId second;
  final String chord;

  @override
  String toString() =>
      '${kind.name}: `$chord` — ${first.name} vs ${second.name}';
}

/// Arbitrate [bindings] for [platform].
///
/// TAKES THE LIST RATHER THAN READING [kKeymap], so the guard can be
/// pointed at a deliberately-broken registry and proved to fail. A rule
/// that has only ever been run against green input is a rule nobody has
/// tested — the same reasoning as `session_layering_test.dart` RULE 15b.
///
/// EVALUATED PER PLATFORM, because the conflicts are not the same on both:
/// `Ctrl+Z` and `Cmd+Z` are two chords on Windows and ONE on macOS, so a
/// registry that declared each separately would be correct here and broken
/// there. Running this over every `TargetPlatform` is what catches it.
List<KeymapConflict> arbitrate(
  List<KeyBinding> bindings,
  TargetPlatform platform,
) {
  final conflicts = <KeymapConflict>[];

  // (M7) Same chord, same scope.
  for (var i = 0; i < bindings.length; i++) {
    for (var j = i + 1; j < bindings.length; j++) {
      final a = bindings[i];
      final b = bindings[j];
      if (a.scope != b.scope) continue;
      if (a.chordOn(platform) != b.chordOn(platform)) continue;
      conflicts.add(
        KeymapConflict(
          kind: KeymapConflictKind.duplicateInScope,
          first: a.id,
          second: b.id,
          chord: a.renderChord(platform),
        ),
      );
    }
  }

  // (a) A local binding on a global chord.
  final globals = bindings.where((b) => b.scope == KeyScope.global);
  for (final global in globals) {
    for (final local in bindings) {
      if (local.scope == KeyScope.global) continue;
      if (local.chordOn(platform) != global.chordOn(platform)) continue;
      conflicts.add(
        KeymapConflict(
          kind: KeymapConflictKind.shadowsGlobal,
          first: global.id,
          second: local.id,
          chord: global.renderChord(platform),
        ),
      );
    }
  }

  // (c) Bare letters across the two canvas views.
  //
  // LETTERS ONLY, because that is what the principle says. `Esc` is bound
  // bare in both canvases and is not a violation: it is not a view-local
  // tool, it is the universal cancel, and clause (b) below is what holds
  // it honest instead.
  const canvasScopes = <KeyScope>{KeyScope.rack, KeyScope.schematic};
  final bareLetters = bindings.where(
    (b) =>
        canvasScopes.contains(b.scope) &&
        !b.primary &&
        !b.alt &&
        !b.shift &&
        _isLetter(b.trigger),
  );
  for (final a in bareLetters) {
    for (final b in bareLetters) {
      if (a.scope == b.scope) continue;
      if (a.trigger != b.trigger) continue;
      if (a.id.index > b.id.index) continue;
      conflicts.add(
        KeymapConflict(
          kind: KeymapConflictKind.letterCollision,
          first: a.id,
          second: b.id,
          chord: a.renderChord(platform),
        ),
      );
    }
  }

  // (b) One chord, one meaning, across scopes.
  for (var i = 0; i < bindings.length; i++) {
    for (var j = i + 1; j < bindings.length; j++) {
      final a = bindings[i];
      final b = bindings[j];
      if (a.scope == b.scope) continue;
      if (a.chordOn(platform) != b.chordOn(platform)) continue;
      if (a.label == b.label) continue;
      conflicts.add(
        KeymapConflict(
          kind: KeymapConflictKind.meaningDrift,
          first: a.id,
          second: b.id,
          chord: a.renderChord(platform),
        ),
      );
    }
  }

  return conflicts;
}

/// [kKeymap], arbitrated.
List<KeymapConflict> arbitrateKeymap(TargetPlatform platform) =>
    arbitrate(kKeymap, platform);

bool _isLetter(LogicalKeyboardKey key) {
  final label = key.keyLabel;
  if (label.length != 1) return false;
  final code = label.codeUnitAt(0);
  return code >= 0x41 && code <= 0x5A;
}

// ══════════════════════════════════════════════════════════════════════
// FRAMEWORK SHADOWING
// ══════════════════════════════════════════════════════════════════════

/// A registry binding that also exists in `WidgetsApp.defaultShortcuts`.
///
/// THIS IS A REPORT, NOT A CONFLICT, and the distinction is deliberate.
/// `WidgetsApp` installs `Enter` -> `ActivateIntent`, `Esc` ->
/// `DismissIntent`, the arrow keys -> `DirectionalFocusIntent` and the
/// page keys -> `ScrollIntent` AT THE ROOT. Every view-local binding on
/// one of those chords wins over the framework's, because dispatch is
/// LEAF -> ROOT — which is exactly what the rack canvas wants for its
/// caret keys and exactly why `_GatedAction` exists: an ungated binding
/// here does not merely shadow the framework, it takes `Backspace` away
/// from every text field in the subtree. For nine days it did.
///
/// So these are not failures to be removed; they are the set of places
/// where this app has deliberately taken a key off the framework, and the
/// value of listing them is that a NEW one cannot appear unnoticed.
/// `keymap_arbitration_test.dart` pins the list.
///
/// TAKES NO PLATFORM ARGUMENT ON PURPOSE. `WidgetsApp.defaultShortcuts` is
/// itself a function of `defaultTargetPlatform` (app.dart:1390 — Apple
/// platforms get a different map), and there is no way to ask it about a
/// platform other than the ambient one. Reading `defaultTargetPlatform`
/// for BOTH halves is the only way the two can be guaranteed to describe
/// the same machine; a caller that wants the macOS answer sets
/// `debugDefaultTargetPlatformOverride`, which is what the test does.
List<KeyBindingId> frameworkShadowedBindings() {
  final platform = defaultTargetPlatform;
  final defaults = WidgetsApp.defaultShortcuts.keys
      .whereType<SingleActivator>()
      .map(
        (a) => (
          trigger: a.trigger,
          control: a.control,
          shift: a.shift,
          alt: a.alt,
          meta: a.meta,
        ),
      )
      .toSet();
  return <KeyBindingId>[
    for (final binding in kKeymap)
      if (defaults.contains(binding.chordOn(platform))) binding.id,
  ];
}
