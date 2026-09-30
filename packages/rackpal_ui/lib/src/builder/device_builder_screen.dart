// THE DEVICE BUILDER'S SHELL AND ITS METADATA FORM. Board #199 and #200,
// M4-D/1 and M4-D/2, docs/06 §2 and §3, AC-049.
//
// ═════════════════════════════════════════════════════════════════════
// THE GOVERNING RULING IS THAT THE FORM IS NOT THE PRODUCT
// ═════════════════════════════════════════════════════════════════════
// AC-049 accepted the critique's diagnosis in full: the port grid was
// never the barrier. **Twelve physical fields and six power fields
// standing in front of it were**, most of which the user does not know
// and half of which are absent from the spec sheet in their hand, so the
// result was a guess (which G4 forbids) or a stall. Three required
// fields, then ports, then done. **A template saved with three fields is
// not incomplete; it is a template**, and every control on this screen
// has to keep saying so.
//
// That is why `_canSave` reads exactly three values and why nothing else
// on any section can turn Save off. A fourth condition creeping in here
// is how this screen becomes the thing AC-049 deleted.
//
// ═════════════════════════════════════════════════════════════════════
// TWO PANES, THOUGH §2 DRAWS THREE, AND THAT IS THE HOUSE RULE
// ═════════════════════════════════════════════════════════════════════
// `shell_tabs_test.dart` holds one line over every surface in this app:
// nothing fabricates a device, a port label or a control that does
// nothing. §2's right dock is three live previews (rack strip, symbol,
// rear panel) and a batch inspector; the previews are M4-K (`#182`) and
// the batch inspector is M4-F2 (`#209`). **There is nothing to put in a
// 340px dock**, so it is not drawn. M4-E has since given the grid its
// row selection, so the dock now waits on the inspector rather than on
// anything to select.
//
// The Structure editor set this precedent explicitly: `#148` shipped with
// NO tab strip at all because one surface satisfied its ruling outright,
// and `#149` added the strip when there was a second thing to switch to.
// A pane that opens nothing is the `UnbuiltView` defect wearing a
// different hat.
//
// The section rail obeys the same rule. §3 lists seven sections; five
// exist (Identity, Ports, Physical, Power, Appearance) and two do not:
// Panel Layout is M4-K, Notes & Publish is M4-P. The rail lists the five
// that work.
//
// ═════════════════════════════════════════════════════════════════════
// THE CHANGE CLASS IS IN THE HEADER, WHERE "BEFORE SAVE" MEANS SOMETHING
// ═════════════════════════════════════════════════════════════════════
// docs/06 §7.2: the class is *"computed from the diff and shown
// prominently before save"*. M4-C built `classifyTemplateChange` and left
// it with no surface; the header beside `[Save]` is the one place a
// person is looking at the moment the sentence is about. It is NOT in
// §2's right dock, because that dock does not exist yet and because a
// verdict about saving belongs next to the button that saves.
//
// **AND IT IS ONLY THERE WHEN IT IS ABOUT SOMEBODY** (DR-202 §11.201.2,
// `#950`). The class answers what an edit means for devices already
// placed, so it is measured against the version they stand on and drawn
// only when some do. A new template has none and shows none.
//
// ═════════════════════════════════════════════════════════════════════
// NO KEYMAP ROWS
// ═════════════════════════════════════════════════════════════════════
// Every control here is a real input, so Flutter's own traversal already
// makes tab order the widget order. `structure_editor_screen.dart` states
// the reasoning: an unnecessary `kKeymap` row is a real cost against M7's
// generated table and `arbitrate()` on every platform. Undo and redo are
// buttons rather than bindings for the same reason, and because the
// builder's stack is NOT the document's (CR-106): binding `Ctrl+Z` here
// would need a scope this screen does not yet have.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/src/builder/bank_dialogs.dart';
import 'package:rackpal_ui/src/builder/bank_tree.dart';
import 'package:rackpal_ui/src/builder/batch_inspector.dart';
import 'package:rackpal_ui/src/builder/panel_canvas.dart';
import 'package:rackpal_ui/src/builder/port_grid.dart';
import 'package:rackpal_ui/src/builder/preview_dock.dart';
import 'package:rackpal_ui/src/draw/device_glyph_mark.dart';
import 'package:rackpal_ui/src/keymap/keymap.dart';
import 'package:rackpal_ui/src/menu/undo_target.dart';
import 'package:rackpal_ui/src/shell/unsaved_changes_dialog.dart';

/// What the app does when the builder asks for something.
///
/// CALLBACKS AND NOT A CONTROLLER, the shape `StructureEditorActions` and
/// `DropEntryActions` already use, so `rackpal_ui` stays free of the
/// session layer.
@immutable
final class DeviceBuilderActions {
  const DeviceBuilderActions({
    required this.onSave,
    this.rememberedPacks = _nothingRemembered,
    this.onPacksRemembered = _rememberNothing,
    this.placedBaseline = _nothingPlaced,
  });

  /// The body devices already placed from this template resolve to, which
  /// version that is, and how many stand on it; null when none do (DR-202
  /// §11.201.2).
  ///
  /// **THE CHANGE CLASS IS A VERDICT ABOUT THESE DEVICES AND NOTHING
  /// ELSE.** It compared against the body the window opened with until
  /// `#950`, so a brand-new template read `Breaking` the moment it had a
  /// height: breaking relative to a blank, for devices that could not
  /// exist. With no placed baseline there is nobody to warn, and the chip
  /// is not drawn.
  ///
  /// A CALL AND NOT A VALUE, read on every build, because the answer moves
  /// under an open window: a first Save gives a new template an id, and a
  /// device placed from the palette meanwhile gives it a baseline.
  final PlacedTemplateBaseline? Function() placedBaseline;

  /// Which column packs this device CATEGORY was last left showing
  /// (docs/06 §4.5).
  ///
  /// **NOT NULLABLE, AND THE FIRST DRAFT WAS.** It carried a doc comment
  /// explaining that null meant "nobody is remembering" while an empty
  /// set meant "this category was left with everything closed" — a
  /// distinction nothing downstream could act on, because the screen
  /// folded null to empty on the way past. A stated difference the code
  /// does not make is worse than no difference: the next person builds on
  /// it. A degraded session (no writable data folder) supplies the
  /// default below and remembers nothing, which is the same behaviour
  /// with one fewer state to reason about.
  final Set<PortColumnPack> Function(String category) rememberedPacks;

  final void Function(String category, Set<PortColumnPack> packs)
  onPacksRemembered;

  /// Persists the body handed to it and returns a refusal sentence, or
  /// null on success.
  ///
  /// **Takes the body rather than the session**, so the app layer never
  /// holds a handle it could mutate behind the editor's back. The editor
  /// hands over a copy it has finished with; what the app does with it
  /// (today, a snapshot in `RackDocument.templates`) is not this file's
  /// business.
  final String? Function(TemplateBody body) onSave;
}

/// A caller that keeps no preferences: the grid still auto-reveals.
Set<PortColumnPack> _nothingRemembered(String category) =>
    const <PortColumnPack>{};

void _rememberNothing(String category, Set<PortColumnPack> packs) {}

/// A caller with no document: nothing is placed, so no verdict is shown.
PlacedTemplateBaseline? _nothingPlaced() => null;

/// What [DeviceBuilderActions.placedBaseline] answers.
typedef PlacedTemplateBaseline = ({TemplateBody body, int version, int count});

/// What an unnamed template is called wherever a name is shown: the header,
/// and the close prompt (DR-190).
const String kUntitledDevice = 'Untitled device';

/// Why `Save` is unavailable: AC-049's three facts, in the words the
/// disabled button's tooltip and the close prompt's refusal both use.
const String kBuilderSaveNeeds =
    'Needs a name, a designator prefix, and a rack height above 0 (unless '
    'it mounts without taking rack units)';

/// The four sections that exist. See the file header for the three that
/// do not.
enum BuilderSection {
  identity('Identity'),

  /// docs/06 §2 puts PORTS here, second, and it is the product: the I/O
  /// editor is what the exit criterion is measured on, and the metadata
  /// form is what a user fills in once.
  ports('Ports'),

  /// CR-071's rear-panel nudge canvas (`#227`), ruled a section of its own
  /// by DR-106 §11.105.2 rather than a corner of the dock: the drawing is
  /// 482.6 mm wide and the dock is 340 px.
  ///
  /// AFTER PORTS, because it is derived FROM the ports and a person
  /// arrives here having just authored them.
  panel('Panel'),
  physical('Physical'),
  power('Power'),
  appearance('Appearance');

  const BuilderSection(this.label);

  final String label;
}

/// The sections a body of this shape shows (AC-031, DR-107 §11.106.2).
///
/// **`Panel` goes for a field device, because a field device has no
/// panel.** `T2.02` is `Rack Elevation: Rear`, one per `Rack`, and a
/// device that is not in a rack never appears on it, so its connector
/// field has no sheet to live on. DR-107 §11.106.4 ruled the opposite in
/// its first draft and was withdrawn before it was built.
///
/// **`Power` and `Appearance` stay.** A display draws power and carries a
/// glyph, and AC-031's removals are all rack geometry plus thermal class.
/// `Physical` stays too, stripped to the two rows that survive: see
/// `_PhysicalSection._inRack`.
///
/// A PURE FUNCTION over the body, so a test asserts the rule without
/// pumping a widget, and so the rail cannot disagree with the pane about
/// which sections exist.
List<BuilderSection> visibleSections(TemplateBody body) =>
    body.mountMethod == MountMethod.notInRack
    ? const [
        BuilderSection.identity,
        BuilderSection.ports,
        BuilderSection.physical,
        BuilderSection.power,
        BuilderSection.appearance,
      ]
    : BuilderSection.values;

/// docs/06 §2's editor, in the shape M4-D actually builds.
class DeviceBuilderScreen extends StatefulWidget {
  const DeviceBuilderScreen({
    required this.template,
    required this.actions,
    required this.measurer,
    this.registries,
    this.portDesignatorFormat = const IdFormat('J{PORT_SEQ:2}'),
    this.onDone,
    this.onDirtyChanged,
    this.onUndoTargetChanged,
    this.undoDepth = kDefaultUndoDepth,
    super.key,
  });

  /// The template to edit. **Never mutated**: `TemplateEditSession`
  /// deep-copies it, which is what makes closing without saving a
  /// complete undo (CR-106, M4-A/4).
  final TemplateBody template;

  final DeviceBuilderActions actions;

  /// The one shared `TextMeasurer` (CR-081), for the right dock's three
  /// previews.
  ///
  /// REQUIRED, exactly as `RackCanvasScreen` takes it, and not defaulted to
  /// a stub. Every preview here is drawn by a real scene builder that
  /// measures text to decide what fits: a stub measurer would lay every
  /// label out wrong AND STILL RENDER, which is the failure mode that
  /// costs a person their afternoon rather than their next thirty seconds.
  final TextMeasurer measurer;

  /// The project's registries, so the port grid can print `HDMI Type A`
  /// where the model holds `conn.hdmi_a`.
  ///
  /// NULLABLE, AND AN EMPTY SET IS NOT THE SAME THING AS ABSENT. A caller
  /// with no document in hand passes nothing and every port shows its raw
  /// ids, which is honest; passing empty registries would say the project
  /// declares no connectors at all.
  final Registries? registries;

  /// The project's port designator format (CR-042), so the DESIG column
  /// previews what THIS project would allocate.
  final IdFormat portDesignatorFormat;

  final VoidCallback? onDone;

  /// Reports whether this window's draft differs from its last save point.
  ///
  /// FOR DR-099 §11.98.4's GUARD, and it exists because the shell cannot ask.
  /// The session is private to the State and `TemplateEditSession` is
  /// `late final`, so handing this screen a different template does NOT
  /// reopen it: loading another template means a new `key`, which destroys
  /// the State and the draft with it. Door 2 therefore has to know BEFORE
  /// it swaps the key, and a discarded draft has no recovery path, because
  /// the session is an in-memory deep copy with nothing for `Ctrl+Z` to
  /// reach and nothing on disk to reopen.
  ///
  /// Driven off `TemplateEditSession.changes`, the session's own counter,
  /// rather than sampled during `build`: the notifier is bumped for every
  /// commit, undo, redo AND save-point move, which is exactly the set of
  /// events that can flip `isDirty`.
  final ValueChanged<bool>? onDirtyChanged;

  /// Hands this window's OWN undo stack up to the shell, so the global
  /// `Ctrl+Z` acts on it while the builder is open (DR-159 §11.158.5).
  ///
  /// **THE CLOSURES INSIDE IT ARE THIS SCREEN'S OWN METHODS**, which is
  /// the whole point: handing up the `TemplateEditSession` would let the
  /// shell call `undoLast` without this screen's `setState`, and the
  /// window would not repaint. Pressing the key from anywhere therefore
  /// goes through exactly the path the toolbar button does.
  ///
  /// Reported on the same notification `onDirtyChanged` uses, and NOT
  /// from `dispose`, for the reason that method's comment gives. The
  /// shell clears it itself when it stops showing this screen, which it
  /// knows because it is what decided to.
  final ValueChanged<UndoTarget?>? onUndoTargetChanged;

  /// How many steps this window's undo keeps: the per-machine depth the
  /// document uses too (DR-172). A new value reaches an open window
  /// through `didUpdateWidget`, because the depth takes effect
  /// immediately.
  final int undoDepth;

  @override
  State<DeviceBuilderScreen> createState() => _DeviceBuilderScreenState();
}

class _DeviceBuilderScreenState extends State<DeviceBuilderScreen>
    with AutomaticKeepAliveClientMixin {
  late final TemplateEditSession _session = TemplateEditSession(
    widget.template,
    undoDepth: widget.undoDepth,
  );

  /// The body as it was when the window opened, for the port keys it had
  /// already published. A COPY, because `_session.body` is the live one.
  ///
  /// **IT IS NO LONGER THE CHANGE CLASS'S BASELINE** (DR-202 §11.201.2).
  /// It was, and for a new template that made the baseline a blank, so the
  /// chip read `Breaking` for devices that could not exist. The baseline
  /// is now [DeviceBuilderActions.placedBaseline].
  late final TemplateBody _opened = copyTemplateBody(widget.template);

  @override
  void didUpdateWidget(DeviceBuilderScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // DR-172: a depth changed in Preferences takes effect now, on the
    // draft that is open, and not at the next template.
    if (widget.undoDepth != oldWidget.undoDepth) {
      _session.resizeUndo(widget.undoDepth);
    }
  }

  BuilderSection _section = BuilderSection.identity;
  String? _refusal;

  /// [_section], or `Ports` when the body has stopped having that section.
  ///
  /// ═══════════════════════════════════════════════════════════════════
  /// A SECTION CAN VANISH UNDER A PERSON WHO IS STANDING IN IT
  /// ═══════════════════════════════════════════════════════════════════
  /// `Mount method` lives in `Physical`, and setting it to `notInRack`
  /// removes `Panel` (AC-031, DR-107 §11.106.2). Nothing stops somebody
  /// opening `Panel` first, going back, and changing it: the rail would
  /// then show five tiles with none selected while the pane still drew a
  /// nudge canvas for a device that has no panel.
  ///
  /// RESOLVED ON READ rather than by patching `_section` inside the edit
  /// callback. The mount method is written through the ordinary command
  /// path and is undoable, so a `Ctrl+Z` can put `Panel` back; a fix that
  /// mutated `_section` on the way past would have to be undone too, and
  /// would not be.
  ///
  /// FALLS BACK TO `Ports`, not `Identity`: a person who was looking at
  /// the panel was thinking about connectors, and Ports is where those
  /// are.
  BuilderSection get _liveSection =>
      visibleSections(_session.body).contains(_section)
      ? _section
      : BuilderSection.ports;

  /// Port keys the author has typed by hand, for the whole life of this
  /// window. See `PortGrid.keyTouched`: it lives here rather than in the
  /// grid because the rail rebuilds the grid, so a set kept there was
  /// discarded by a trip to the Physical section and a deliberately
  /// chosen key quietly went back to following its label.
  final _keyTouched = <String>{};

  /// The last value handed to [DeviceBuilderScreen.onDirtyChanged]. Null
  /// until the first report, so a window that opens clean still announces
  /// itself and the shell never has to assume.
  bool? _reportedDirty;

  /// The last value handed to [DeviceBuilderScreen.onUndoTargetChanged].
  UndoTarget? _reportedUndo;

  @override
  void initState() {
    super.initState();
    _session.changes.addListener(_reportUp);
    // ANNOUNCE THE OPENING STATE, once the frame this screen was built in
    // has finished. A fresh window is clean and the shell's flag may be
    // stale from a window that just closed dirty. The undo target is
    // announced on the same frame and for the same reason: an EMPTY
    // stack is a fact the shell has to hear, or its Edit menu offers to
    // take back whatever the last window was holding.
    WidgetsBinding.instance.addPostFrameCallback((_) => _reportUp());
  }

  /// Named `_reportUp` because it reports UP, to the shell; the change
  /// class this screen shows is [_verdict].
  void _reportUp() {
    _reportDirty();
    _reportUndo();
  }

  void _reportDirty() {
    final dirty = _session.isDirty;
    if (dirty == _reportedDirty) return;
    _reportedDirty = dirty;
    widget.onDirtyChanged?.call(dirty);
  }

  void _reportUndo() {
    final report = widget.onUndoTargetChanged;
    if (report == null) return;
    final target = UndoTarget(
      canUndo: _session.undo.canUndo,
      canRedo: _session.undo.canRedo,
      undoLabelKey: _session.undo.undoLabelKey,
      redoLabelKey: _session.undo.redoLabelKey,
      // THIS SCREEN'S OWN METHODS, not the session's. See the field doc.
      undo: () => setState(_session.undoLast),
      redo: () => setState(_session.redoLast),
    );
    // `UndoTarget`'s equality deliberately ignores the closures, which
    // are freshly allocated here every time; without that this guard
    // would never hold and the shell would rebuild on every keystroke.
    if (target == _reportedUndo) return;
    _reportedUndo = target;
    report(target);
  }

  @override
  void dispose() {
    _session.changes.removeListener(_reportUp);
    // NOTHING IS REPORTED FROM HERE, and the first draft did report
    // `false`. `dispose` runs while the tree is being finalised, so a
    // listener that calls `setState` (which the shell's does, because the
    // flag drives a guard) throws "setState() called when widget tree was
    // locked". The notification was redundant anyway: this screen is
    // disposed when its key changes, the replacement is inflated in the
    // same build, and that one announces its own clean state on its first
    // frame. A stale `true` cannot outlive the frame it was set in.
    _session.close();
    super.dispose();
  }

  /// AC-049's three, and NOTHING ELSE MAY JOIN THEM. See the file header.
  ///
  /// **The RU-height clause is not `frontU >= 0`, and the first draft of
  /// this getter was.** `frontU` is a non-nullable `int` defaulting to
  /// `0`, so it can never be ABSENT the way a name can, and a gate that
  /// only rejects negatives is a gate that always passes. AC-049 wants
  /// the user to have supplied three facts; a default silently supplying
  /// one of them is the stall it exists to prevent, wearing a different
  /// hat. A brand-new template would save as a 0U device, which for a
  /// rack-mount box is both wrong and invisible on an elevation.
  ///
  /// So a zero height must be MEANT, and the model has TWO spellings for
  /// meaning it. docs/06 §3.2 writes a 0U PDU as
  /// `{front: 0, rear: 0, side: zeroUVertical}`, and AC-031's field
  /// devices are `{front: 0, rear: 0, side: none, notInRack}`. In both,
  /// `0` is a measured zero rather than an untouched default, which is
  /// G4's own distinction applied to occupancy.
  ///
  /// **THE SECOND SPELLING WAS MISSING, AND IT BLOCKED A WHOLE DEVICE
  /// CLASS** (`#246`, DR-107 §11.106.2). Every one of AC-031's 18 shipped
  /// field templates is `notInRack` with zero occupancy, so `Save` was
  /// disabled for all of them and stayed disabled whatever the person
  /// typed. The 18 ship in the seed catalog and nobody could author a
  /// nineteenth. It went unseen because a rack device cannot reach the
  /// state and the field-device path had no test.
  ///
  /// **This is not a fourth fact joining AC-049's three.** It is the same
  /// third fact, occupancy, with the second of its two honest spellings
  /// admitted: choosing `notInRack` means a zero as deliberately as
  /// choosing `zeroUVertical` does. Nothing else may join the list.
  ///
  /// **AND THE SAME HOLE WAS STILL OPEN FOR THREE MORE MOUNTS** (`#951`,
  /// DR-203 §11.202.5). A hosted card (the seeded AVR is one), a
  /// side-mounted and an in-furniture device all take no rack units, and
  /// none could be saved; neither could docs/06 §3.2's own rear lacing
  /// bar, `{front: 0, rear: 1}`, because the check read the front height
  /// alone. `hasMeantOccupancy` states the third fact once: a rack mount
  /// means it with a height, front or rear, and every other mount means a
  /// zero by being chosen.
  bool get _canSave {
    final b = _session.body;
    return b.displayName.trim().isNotEmpty &&
        (b.typePrefix ?? '').trim().isNotEmpty &&
        hasMeantOccupancy(b);
  }

  /// The change class against the body placed devices resolve to, or null
  /// when nothing is placed and there is nobody for a verdict to be about.
  _Verdict? get _verdict {
    final base = widget.actions.placedBaseline();
    if (base == null) return null;
    return (
      report: classifyTemplateChange(base.body, _session.body),
      version: base.version,
      count: base.count,
    );
  }

  /// Runs one field write and repaints, unless it would write the value
  /// already
  /// there. The guard is not an optimisation: an undo entry that changes
  /// nothing is one the user has to press Ctrl+Z through twice.
  void _run<T>(TemplateField<T> field, T value) {
    if (field.get(_session.body) == value) return;
    setState(() {
      // ONE UNDO ENTRY, because typing a height and the side it implies is
      // one act to the person who typed it. Null names the entry after the
      // field write, which is the act they performed (DR-156 §11.155.2).
      _session.transact(null, (tx) {
        tx.add(
          SetTemplateFieldCommand<T>(
            field: field,
            from: field.get(_session.body),
            to: value,
          ),
        );
        if (field.key == TemplateBodyField.rearU.key) _rearFollows = false;
        if (field.key == TemplateBodyField.frontU.key &&
            _rearFollows &&
            mountTakesRackUnits(_session.body.mountMethod)) {
          _write(tx, TemplateBodyField.rearU, _session.body.frontU);
        }
        if (_occupancyKeys.contains(field.key)) _writeDerived(tx);
      });
      _refusal = null;
    });
  }

  /// The four fields a person states about occupancy; editing any of them
  /// re-derives the other three (DR-203 §11.202.2).
  static final Set<String> _occupancyKeys = {
    TemplateBodyField.frontU.key,
    TemplateBodyField.rearU.key,
    TemplateBodyField.mountMethod.key,
    TemplateBodyField.widthClass.key,
  };

  /// Whether the rear height is still following the front one (DR-203
  /// §11.202.3). **21 of the 25 seeded rack-ear devices take the same RU
  /// front and rear**, so the common case typed its height twice. True
  /// while the two agree as opened, which a new template's `0 / 0` does,
  /// and false from the first keystroke in the rear box: somebody who
  /// typed a rear height meant it.
  late bool _rearFollows = widget.template.rearU == widget.template.frontU;

  void _write<T>(TxnScope<TemplateBody> tx, TemplateField<T> field, T to) {
    final from = field.get(_session.body);
    if (from == to) return;
    tx.add(SetTemplateFieldCommand<T>(field: field, from: from, to: to));
  }

  /// Writes what the mount, heights and width imply, inside the edit's own
  /// transaction, so one `Ctrl+Z` takes back the edit and its consequence.
  ///
  /// ═══════════════════════════════════════════════════════════════════
  /// IT WAS `_impliedSide`, AND IT ONLY EVER FILLED A BLANK
  /// ═══════════════════════════════════════════════════════════════════
  /// DR-157 §11.156.5 (`#869`) derived the side from a typed front height,
  /// because a form that never asked for `side` authored a body placement
  /// routed off-rack. A save gate was tried first and rightly broke
  /// AC-049's three-fields case: typing a height IS saying where it
  /// mounts. It filled `none` and nothing else, so a person who typed a
  /// rear height afterwards kept `Front only`, and corrected it on a
  /// second section. That is the double entry `#951` reported.
  ///
  /// **Occupies is now never asked at all** (DR-203 §11.202.2): it is
  /// shown, and re-derived from every occupancy edit by
  /// `derivedOccupancy`, which the whole seeded catalog already satisfies.
  /// Editing a name does not re-derive, so a hand-written file whose side
  /// disagrees is left as written until somebody touches its occupancy.
  void _writeDerived(TxnScope<TemplateBody> tx) {
    final d = derivedOccupancy(_session.body);
    _write(tx, TemplateBodyField.frontU, d.frontU);
    _write(tx, TemplateBodyField.rearU, d.rearU);
    _write(tx, TemplateBodyField.side, d.side);
    _write(tx, TemplateBodyField.nominalSpanTwelfths, d.nominalSpanTwelfths);
  }

  /// Runs one command that is not a field write, and repaints.
  ///
  /// NO EQUALITY GUARD, unlike [_run]. That guard exists because a text
  /// box can write the value already in it on every rebuild; a port
  /// command is a structural change somebody asked for, and there is no
  /// "already added" to compare against.
  void _runCommand(Command<TemplateBody> command) =>
      setState(() => _session.run(command));

  /// Several commands as ONE undo entry, for a gesture that touches more
  /// than one port.
  void _transact(
    LabelKey label,
    void Function(TxnScope<TemplateBody> tx) body,
  ) => setState(() => _session.transact(label, body));

  void _save({required bool close}) {
    final refusal = widget.actions.onSave(copyTemplateBody(_session.body));
    setState(() => _refusal = refusal);
    if (refusal != null) return;
    _session.markSaved();
    if (close) widget.onDone?.call();
  }

  /// `Close`, which ASKS FIRST when there is anything to lose (DR-190
  /// §11.189).
  ///
  /// It called `onDone` directly until then, and `onDone` unmounts this
  /// screen, so a dirty draft went with it: the session is an in-memory
  /// copy nothing else holds. The prompt is the project's own close
  /// prompt (docs/03 §9.5) with its rules unchanged, because leaving is
  /// the act here, which is the difference from DR-099 §11.98.4's refusal
  /// on door 2.
  Future<void> _close() async {
    final done = widget.onDone;
    if (done == null) return;
    if (!_session.isDirty) {
      done();
      return;
    }
    final name = _session.body.displayName.trim();
    final choice = await showUnsavedChangesDialog(
      context,
      documentName: name.isEmpty ? kUntitledDevice : name,
      editCount: _session.editsSinceSave,
    );
    if (!mounted) return;
    switch (choice) {
      case UnsavedChangesChoice.save:
        // SAVE OBEYS THE SAVE BUTTON'S RULE (§11.189.2). A draft the
        // button would refuse is refused here too, in the same band, and
        // nothing closes: closing after a failed save is the silent
        // discard this method exists to stop.
        if (!_canSave) {
          setState(() => _refusal = 'Not saved. $kBuilderSaveNeeds.');
          return;
        }
        _save(close: true);
      case UnsavedChangesChoice.dontSave:
        done();
      case UnsavedChangesChoice.cancel:
        break;
    }
  }

  /// What the port grid last reported about its selection, or null when
  /// fewer than two rows are selected (M4-F2).
  PortBatchContext? _batch;

  /// Whether docs/06 §6's previews take their pane (`#802`).
  ///
  /// SESSION STATE, NOT A SETTING, and deliberately not persisted. It is
  /// the same shape as the column-pack override the grid already carries:
  /// a choice about this look at this template, which a person makes by
  /// reaching for room and unmakes when they want the previews back. A
  /// remembered value would mean opening the builder on a wide monitor
  /// and finding the previews gone because of a laptop three weeks ago.
  ///
  /// IT DEFAULTS TO SHOWN. `#228` built these previews and CR-086 is the
  /// reason they matter: a symbol that cannot print is not a symbol, and
  /// the dock is where a person sees the one they are authoring.
  bool _previewsShown = true;

  // ═══════════════════════════════════════════════════════════════════
  // docs/06 §2's BANK TREE, AND THE FOUR ACTIONS BEHIND IT
  // ═══════════════════════════════════════════════════════════════════
  // The tree is mounted PERMANENTLY, under the section list, because a
  // bank count is a fact about the template in the way the section list
  // is: a rail that grew and shrank as a person moved down the sections
  // would move the tile under their cursor. Clicking a bank switches to
  // Ports, so the tree is never navigation into a section a person is not
  // in.

  /// The bank the tree last had clicked, for its own highlight.
  ({String? key})? _bankSelected;

  /// The jump handed to the grid, and the nonce that makes a repeat click
  /// on one bank scroll a second time.
  ({String? bankKey, int nonce})? _bankJump;
  int _jumpNonce = 0;

  void _selectBank(String? bankKey) => setState(() {
    _section = BuilderSection.ports;
    _bankSelected = (key: bankKey);
    _bankJump = (bankKey: bankKey, nonce: ++_jumpNonce);
  });

  BankDef? _bank(String key) =>
      _session.body.banks.where((b) => b.key == key).firstOrNull;

  Future<void> _createBank() async {
    final choice = await showBankNameDialog(
      context: context,
      body: _session.body,
    );
    if (choice == null || !mounted) return;
    // THE KEY COMES FROM QUICK ADD'S GENERATOR (DR-085 §11.84.5), so the
    // vocabulary has one derivation and not a second one here.
    _runCommand(
      AddBankCommand(
        BankDef(
          key: uniqueBankKey(_session.body, choice.label),
          label: choice.label,
          abbr: choice.abbr,
          order: nextOrder(_session.body.banks.map((b) => b.order)),
        ),
      ),
    );
  }

  Future<void> _renameBank(String bankKey) async {
    final bank = _bank(bankKey);
    if (bank == null) return;
    final choice = await showBankNameDialog(
      context: context,
      body: _session.body,
      bank: bank,
    );
    if (choice == null || !mounted) return;
    if (choice.label == bank.label && choice.abbr == bank.abbr) return;
    _runCommand(
      RenameBankCommand(
        bankKey,
        toLabel: choice.label,
        toAbbr: choice.abbr,
      ),
    );
  }

  /// No confirm: CR-055 makes a bank presentation, so this keeps every
  /// port and lands them in `Not in a bank`, in front of the person, one
  /// `Ctrl+Z` from where they were. See `bank_tree.dart`'s header.
  void _removeBank(String bankKey) {
    if (_bank(bankKey) == null) return;
    _runCommand(RemoveBankCommand(bankKey));
    if (_bankSelected?.key == bankKey) {
      setState(() => _bankSelected = null);
    }
  }

  Future<void> _mirrorBank(String bankKey) async {
    final source = _bank(bankKey);
    if (source == null) return;
    final choice = await showMirrorBankDialog(
      context: context,
      body: _session.body,
      source: source,
    );
    if (choice == null || !mounted) return;
    final plan = planMirrorBank(
      _session.body,
      sourceBankKey: bankKey,
      label: choice.label,
      abbr: choice.abbr,
    );
    // ONE TRANSACTION, so a mirrored sixteen-port bank is one Ctrl+Z.
    _transact(LabelKey.mirrorBank, (tx) {
      for (final command in mirrorBankCommands(plan)) {
        tx.add(command);
      }
    });
    _selectBank(plan.bank.key);
  }

  late final _bankActions = BankActions(
    onCreate: _createBank,
    onRename: _renameBank,
    onRemove: _removeBank,
    onMirror: _mirrorBank,
  );

  // ═════════════════════════════════════════════════════════════════════
  // THE DRAFT OUTLIVES A TAB SWITCH (DR-091 §11.90.6)
  // ═════════════════════════════════════════════════════════════════════
  // This screen holds an EDIT SESSION, not a view of the document: the
  // template is never mutated, `TemplateEditSession` deep-copies it, and
  // that copy is what makes closing without saving a complete undo.
  //
  // As a dialog that discard is a decision a person takes by pressing
  // Close. As a view in the strip it would happen on `Ctrl+2`, which is
  // not a decision about anything, so the state has to survive being
  // scrolled out of a `TabBarView`. Nothing else in the strip needs this:
  // the other five are views OF the document and rebuild from it.
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    // Required by the mixin, and its whole effect.
    super.build(context);
    return _buildScreen(context);
  }

  Widget _buildScreen(BuildContext context) => Shortcuts(
    // THE BUILDER'S SCOPE IS INSTALLED AT THE SCREEN, not only around
    // Quick Add, because `Ctrl+Enter` has to work while focus is in the
    // METADATA FORM: docs/06 §9.1 spends step 5 on it, from the
    // designator prefix. The bar re-declares the same map lower down,
    // which is harmless -- the nearer `Shortcuts` wins for the keys it
    // has an enabled `Action` for, and this one only handles the jump.
    shortcuts: keymapShortcuts(
      KeyScope.builder,
      platform: Theme.of(context).platform,
    ),
    child: Actions(
      actions: <Type, Action<Intent>>{
        // THE BUILDER'S OWN STACK, AND NEAREST-ACTION-WINS IS THE
        // ROUTING (DR-159 §11.158.5). `Ctrl+Z` is a global binding since
        // that ruling; Flutter resolves the `Action` from the focused
        // context upward, so while focus is anywhere inside this screen
        // these two win over the shell's fallback and the template's
        // stack is what moves.
        //
        // The shell ALSO declines while this screen is showing, because
        // focus can legitimately be nowhere and the fallback would then
        // undo something in the project behind the window.
        UndoIntent: CallbackAction<UndoIntent>(
          onInvoke: (_) {
            if (_session.undo.canUndo) setState(_session.undoLast);
            return null;
          },
        ),
        RedoIntent: CallbackAction<RedoIntent>(
          onInvoke: (_) {
            if (_session.undo.canRedo) setState(_session.redoLast);
            return null;
          },
        ),
        JumpToPortsIntent: CallbackAction<JumpToPortsIntent>(
          onInvoke: (_) {
            // NOT GATED ON THE REQUIRED FIELDS. AC-049 took the metadata
            // form off the critical path; a jump refused because a field
            // is blank would put the gate back that ruling removed.
            setState(() => _section = BuilderSection.ports);
            return null;
          },
        ),
      },
      child: _body(context),
    ),
  );

  Widget _body(BuildContext context) => Column(
    children: [
      _Header(
        session: _session,
        verdict: _verdict,
        canSave: _canSave,
        onUndo: _session.undo.canUndo
            ? () => setState(_session.undoLast)
            : null,
        onRedo: _session.undo.canRedo
            ? () => setState(_session.redoLast)
            : null,
        onSave: _canSave ? () => _save(close: false) : null,
        onSaveAndClose: _canSave ? () => _save(close: true) : null,
        onClose: widget.onDone == null ? null : () => unawaited(_close()),
      ),
      if (_refusal != null)
        Container(
          width: double.infinity,
          color: Theme.of(context).colorScheme.errorContainer,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            _refusal!,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
          ),
        ),
      const Divider(height: 1),
      Expanded(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ═══════════════════════════════════════════════════════════
            // TWO TRAVERSAL GROUPS, AND WITHOUT THEM TAB IS UNUSABLE
            // ═══════════════════════════════════════════════════════════
            // Flutter's default is `ReadingOrderTraversalPolicy`, which
            // orders focus by GEOMETRY: top to bottom, left to right,
            // across the whole subtree. The rail's tiles and the form's
            // fields are two columns of roughly the same pitch, so
            // reading order INTERLEAVES them. Measured, before the fix:
            //
            //   Display name -> RAIL TILE -> RAIL TILE -> Manufacturer
            //
            // which is what a user reported, and it is worse than it
            // looks. A `ListTile` fires its `onTap` on Enter or Space, so
            // somebody tabbing toward the designator prefix and typing
            // without watching lands on a rail tile and CHANGES SECTION.
            // The field they meant to fill then reads as broken, which is
            // exactly how it was reported: "this doesn't appear to work
            // at all".
            //
            // A `FocusTraversalGroup` makes each pane a unit, so Tab
            // finishes the form before it leaves the form. The rail stays
            // reachable, deliberately: keyboard-only operation is M7's
            // criterion and M1's drill already proved that removing a
            // stop is how a surface becomes unusable without a mouse.
            // What changes is the ORDER, not the reachability.
            FocusTraversalGroup(
              child: SizedBox(
                width: 200,
                child: _SectionRail(
                  selected: _liveSection,
                  canSave: _canSave,
                  onSelect: (s) => setState(() => _section = s),
                  body: _session.body,
                  bankActions: _bankActions,
                  bankSelected: _bankSelected,
                  onSelectBank: _selectBank,
                ),
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: FocusTraversalGroup(
                child: switch (_liveSection) {
                  BuilderSection.identity => _IdentitySection(
                    body: _session.body,
                    registries: widget.registries,
                    onEdit: _run,
                  ),
                  BuilderSection.ports => PortGrid(
                    body: _session.body,
                    registries: widget.registries ?? Registries(),
                    // FROM `_opened`, WHICH IS THE TEMPLATE AS IT ARRIVED.
                    // A port already in it has a PUBLISHED key: some
                    // project may join its cables through that string
                    // (CR-051), so renaming it records the old name and
                    // typing a label never moves it.
                    openedPortKeys: {
                      for (final port in _opened.ports) port.key.v,
                    },
                    keyTouched: _keyTouched,
                    onKeyTouched: (was, now) => _keyTouched.addAll([was, now]),
                    // PER CATEGORY, keyed on the body's CURRENT category
                    // rather than the one it opened with: change a
                    // template from Distribution to Network and the
                    // columns a person keeps for network gear are the
                    // ones they should get.
                    remembered: widget.actions.rememberedPacks(
                      _session.body.category,
                    ),
                    onPacksRemembered: (packs) => widget.actions
                        .onPacksRemembered(_session.body.category, packs),
                    portDesignatorFormat: widget.portDesignatorFormat,
                    actions: PortGridActions(
                      run: _runCommand,
                      transact: _transact,
                    ),
                    onBatchContext: (batch) {
                      if (_batch == batch) return;
                      setState(() => _batch = batch);
                    },
                    bankActions: _bankActions,
                    bankJump: _bankJump,
                    // THE TOGGLE LIVES ON THE GRID'S TOOLBAR, not on the
                    // dock, because a control that is only reachable while
                    // the dock is drawn cannot bring it back.
                    previewsShown: _previewsShown,
                    onTogglePreviews: () =>
                        setState(() => _previewsShown = !_previewsShown),
                  ),
                  BuilderSection.panel => PanelCanvasSection(
                    body: _session.body,
                    registries: widget.registries ?? Registries(),
                    measurer: widget.measurer,
                    // ONE TRANSACTION PER GESTURE, so aligning eight
                    // cutouts is one `Ctrl+Z`, the discipline the batch
                    // inspector already follows. `panel_arrange.dart`
                    // builds the commands in core; this closure only
                    // decides which stack they land on.
                    onEdit: (commands) => _transact(
                      LabelKey.setPortProperty,
                      (TxnScope<TemplateBody> tx) {
                        for (final command in commands) {
                          tx.add(command);
                        }
                      },
                    ),
                  ),
                  BuilderSection.physical => _PhysicalSection(
                    body: _session.body,
                    onEdit: _run,
                  ),
                  BuilderSection.power => _PowerSection(
                    body: _session.body,
                    onEdit: _run,
                  ),
                  BuilderSection.appearance => _AppearanceSection(
                    body: _session.body,
                    onEdit: _run,
                  ),
                },
              ),
            ),
            // ═══════════════════════════════════════════════════════════
            // docs/06 §2's RIGHT DOCK, NOW IN BOTH ITS STATES
            // ═══════════════════════════════════════════════════════════
            // §2 says the dock "swaps to a batch inspector when more than
            // one grid row is selected", and SWAPS is the operative word:
            // the previews are the resting state and the inspector takes
            // the pane while a batch is live. `#228` builds the previews,
            // so the old note here -- "there is nothing to put in a 340px
            // dock, so it is not drawn" -- is discharged rather than
            // deleted, and DR-105 §11.104.7 quotes it as the condition it
            // was ending.
            //
            // STILL GATED ON THE SECTION, for the reason that gating was
            // introduced: a pane about ports beside a field about weight
            // is worse than no pane. `_batch` survives a trip to Physical
            // and back, deliberately, so the selection is still there when
            // the person returns.
            if (_liveSection == BuilderSection.ports) ...[
              if (_batch case final PortBatchContext batch) ...[
                const VerticalDivider(width: 1),
                _batchInspector(batch),
              ] else if (_previewsShown) ...[
                // ═══════════════════════════════════════════════════════
                // NO THRESHOLD ANY MORE, AND THAT IS `#803`'s DOING
                // ═══════════════════════════════════════════════════════
                // `kPreviewDockMinWindow` existed because the port grid's
                // archetype bar was a `Row` with a hard natural width of
                // about 637, and nothing else in the grid had one: the
                // grid scrolls its own columns. The bar alone set the
                // floor under the whole window, and the dock was held off
                // until that floor was cleared.
                //
                // It was also held off 23 px too early. The constant said
                // 1180 and the layout did not fit until 1203, measured;
                // its own doc comment called the number "MEASURED, NOT
                // CHOSEN" and the arithmetic had stopped one term short.
                // That band sits above `kMinWindowWidth`, so it was the
                // one part of this a person could actually reach.
                //
                // With both bars wrapping the dock fits at 1000, the
                // narrowest window the app will open, so the geometry no
                // longer decides this and a constant pretending to
                // measure it would be fiction. What is left is a
                // PREFERENCE, and a preference belongs to the person: the
                // grid toolbar carries the toggle, which is the surface
                // that stays visible when the dock is not.
                //
                // THE SILENT FAILURE `#802` WAS FILED FOR IS GONE BY
                // CONSTRUCTION rather than by explanation. Nothing
                // vanishes on its own any more, so there is no
                // disappearance left to explain.
                const VerticalDivider(width: 1),
                BuilderPreviewDock(
                  body: _session.body,
                  registries: widget.registries ?? Registries(),
                  measurer: widget.measurer,
                ),
              ],
            ],
          ],
        ),
      ),
    ],
  );

  /// The dock's OTHER state (docs/06 §2), lifted out of the tree when the
  /// previews joined it so the `if` above reads as the swap it is.
  Widget _batchInspector(PortBatchContext batch) => BatchInspector(
    body: _session.body,
    registries: widget.registries ?? Registries(),
    context_: batch,
    // THE DOCK WRITES THROUGH THE SESSION, in ONE transaction per field,
    // so setting a value across eight rows is one `Ctrl+Z` (M4-F11).
    // `buildBatchWrite` builds the commands in core; this closure only
    // decides which stack they land on, which is the same division the
    // grid's own edits use.
    onWrite: (column, value) =>
        _transact(LabelKey.setPortProperty, (TxnScope<TemplateBody> tx) {
          for (final command in buildBatchWrite(
            body: _session.body,
            column: column,
            portKeys: batch.portKeys,
            value: value,
          )) {
            tx.add(command);
          }
        }),
  );
}

class _Header extends StatelessWidget {
  const _Header({
    required this.session,
    required this.verdict,
    required this.canSave,
    required this.onUndo,
    required this.onRedo,
    required this.onSave,
    required this.onSaveAndClose,
    required this.onClose,
  });

  final TemplateEditSession session;

  /// Null when nothing is placed from this template (DR-202 §11.201.2).
  final _Verdict? verdict;
  final bool canSave;
  final VoidCallback? onUndo;
  final VoidCallback? onRedo;
  final VoidCallback? onSave;
  final VoidCallback? onSaveAndClose;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final name = session.body.displayName.trim();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      // A `Wrap` AND NOT A `Row`, because a `Row` here overflowed by 18px
      // the first time a test pumped it. The app enforces a 1000x720
      // minimum window (`kMinWindowWidth`), so no user reaches the width
      // that broke it — but a header that throws a layout assertion below
      // some threshold is a header nobody may safely add a control to,
      // and this one is going to gain a `[Duplicate]` and a
      // `[Submit to community catalog]` before M4 is out. Wrapping to a
      // second line is the correct degradation for a toolbar.
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 8,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Text(
              // An unnamed template says so rather than showing a blank
              // where a name goes; `displayName` is one of the three the
              // ruling requires, so this state is the FIRST thing a new
              // template is in and it must not read as a rendering bug.
              name.isEmpty ? kUntitledDevice : name,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontStyle: name.isEmpty ? FontStyle.italic : null,
              ),
            ),
          ),
          // ONE WRAP CHILD, so the controls travel together: a wrap that
          // could leave `[Save]` on line one and `[Save & Close]` on line
          // two would separate two buttons whose difference is the whole
          // question the user is answering.
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (session.isDirty)
                const Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: Text('Unsaved'),
                ),
              // DERIVED, NOT A TOGGLE (AC-049, M4-D/4). There is no
              // control here because there is nothing to control: the
              // chip appears when the body has no ports and no category,
              // and it leaves the moment either arrives. A checkbox
              // would let somebody mark a finished template incomplete,
              // which is the idea AC-049 exists to delete.
              if (isDraftTemplate(session.body))
                const Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: Tooltip(
                    message:
                        'No ports and no category yet. Not a warning: '
                        'a template with three fields is finished.',
                    child: Chip(label: Text('Draft')),
                  ),
                ),
              if (verdict case final v?) _ChangeClassChip(verdict: v),
              const SizedBox(width: 12),
              IconButton(
                onPressed: onUndo,
                icon: const Icon(Icons.undo),
                tooltip: 'Undo',
              ),
              IconButton(
                onPressed: onRedo,
                icon: const Icon(Icons.redo),
                tooltip: 'Redo',
              ),
              const SizedBox(width: 8),
              // DISABLED RATHER THAN ABSENT, and the tooltip says what is
              // missing. A button that vanishes teaches nothing; a
              // disabled one with a reason is the only thing on this
              // screen that ever explains AC-049's rule to the person
              // hitting it.
              Tooltip(
                message: canSave ? 'Save' : kBuilderSaveNeeds,
                child: FilledButton(
                  onPressed: onSave,
                  child: const Text('Save'),
                ),
              ),
              // BOTH CONTROLS ARE CONDITIONAL, because DR-091 §11.90 hosts
              // this screen in the view strip as well as in a dialog and a
              // tab has nothing to close. `Save` alone is the whole footer
              // there, which is the honest shape: the draft is committed or
              // it is not, and leaving the view is not a decision about it.
              if (onClose != null) ...[
                const SizedBox(width: 8),
                FilledButton.tonal(
                  onPressed: onSaveAndClose,
                  child: const Text('Save & Close'),
                ),
                const SizedBox(width: 8),
                TextButton(onPressed: onClose, child: const Text('Close')),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// The change class, the version it was measured against, and how many
/// devices stand on that version.
typedef _Verdict = ({TemplateChangeReport report, int version, int count});

/// docs/06 §7.2's verdict, beside the button it is about.
///
/// **IT SAYS WHO IT IS ABOUT** (DR-202 §11.201.2). `Breaking` alone read
/// as a property of the edit, and on a new template it was a property of
/// nothing. `Breaking · 4 placed` is a statement about four devices, and
/// the tooltip names the version they resolve to.
class _ChangeClassChip extends StatelessWidget {
  const _ChangeClassChip({required this.verdict});

  final _Verdict verdict;

  @override
  Widget build(BuildContext context) {
    final report = verdict.report;
    if (report.isUnchanged) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final (label, background) = switch (report.changeClass) {
      TemplateChangeClass.safe => ('Safe', scheme.surfaceContainerHighest),
      TemplateChangeClass.additive => ('Additive', scheme.secondaryContainer),
      TemplateChangeClass.breaking => ('Breaking', scheme.errorContainer),
    };
    // The REASONS, not only the verdict. A label reading "Breaking" with
    // nothing under it is a verdict nobody can act on, which is why
    // `TemplateChangeReport` carries `decidingChanges` at all.
    final reasons = report.decidingChanges
        .take(6)
        .map((c) => '${c.kind.name}: ${c.path}')
        .join('\n');
    final devices = verdict.count == 1
        ? '1 placed device uses'
        : '${verdict.count} placed devices use';
    return Tooltip(
      message: 'Compared with v${verdict.version}, which $devices.\n$reasons',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text('$label · ${verdict.count} placed'),
      ),
    );
  }
}

class _SectionRail extends StatelessWidget {
  const _SectionRail({
    required this.selected,
    required this.canSave,
    required this.onSelect,
    required this.body,
    required this.bankActions,
    required this.bankSelected,
    required this.onSelectBank,
  });

  final BuilderSection selected;
  final bool canSave;
  final ValueChanged<BuilderSection> onSelect;

  final TemplateBody body;
  final BankActions bankActions;
  final ({String? key})? bankSelected;
  final ValueChanged<String?> onSelectBank;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      // THE SECTION LIST DOES NOT SCROLL AND THE TREE DOES. Five tiles
      // fit any window this app opens in; a bank list does not, and
      // putting both in one scroller would let a template with nine banks
      // push `Identity` off the top, which is the one tile that can be
      // blocking a save.
      for (final s in visibleSections(body))
        ListTile(
          dense: true,
          selected: s == selected,
          // ONE MARKER, ON ONE SECTION. Only Identity can block a save,
          // so only Identity gets a state. Putting a tick beside Physical
          // would say a section can be complete or incomplete, which is
          // exactly the incomplete-template idea AC-049 exists to delete.
          leading: s == BuilderSection.identity
              ? Icon(
                  canSave ? Icons.check_circle_outline : Icons.error_outline,
                  size: 18,
                )
              : const SizedBox(width: 18),
          title: Text(s.label),
          onTap: () => onSelect(s),
        ),
      Expanded(
        child: BankTree(
          body: body,
          actions: bankActions,
          selected: bankSelected,
          onSelect: onSelectBank,
        ),
      ),
    ],
  );
}

/// docs/06 §3.2. Occupancy is a struct, never a scalar (CR-036).
class _PhysicalSection extends StatelessWidget {
  const _PhysicalSection({required this.body, required this.onEdit});

  final TemplateBody body;
  final void Function<T>(TemplateField<T> field, T value) onEdit;

  /// ═══════════════════════════════════════════════════════════════════
  /// AC-031's STRIPPED FORM IS FEWER ROWS, NOT GREYED-OUT ONES
  /// ═══════════════════════════════════════════════════════════════════
  /// *"no RU, no rack depth, no thermal class"*. Every row here but one is
  /// a statement about living in a rack, and they go together: fit,
  /// depth, load, clearance, thermal, and the `Container` switch, which
  /// describes a shelf.
  ///
  /// **ONE STAYS.** `Weight`, because a speaker has one and nothing about
  /// weight is rack geometry. `Mount method` stayed too while it lived
  /// here, so a person was never stranded; since DR-203 it is on Identity
  /// with the rest of the occupancy, and so are the heights, `Occupies`
  /// and the width. `Passthrough` went to the port grid's toolbar, beside
  /// the pairing it enables (§11.202.6).
  ///
  /// A GETTER RATHER THAN A LOCAL, so `build` keeps its expression body:
  /// converting it to a block meant managing a closing brace by hand in a
  /// 2000-line file, which mangled this file twice before it was written
  /// this way.
  bool get _inRack => body.mountMethod != MountMethod.notInRack;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      _SectionNote(
        _inRack
            ? 'How big it is and how it mounts are on Identity. These are '
                  'the fit, load and heat figures a drawing checks against; '
                  'leave any you do not know blank.'
            : 'A field device is not in the rack, so it has no rack '
                  'geometry to state. Change How it mounts on Identity to '
                  'bring the rack fields back.',
      ),
      if (_inRack)
        _LenRow(
          label: 'Body depth',
          value: body.bodyDepth,
          // UNKNOWN, NOT ZERO (G4, CR-114). An empty box stays unknown,
          // serialises as an absent key, and every rollup that reads it
          // reports its unknown count instead of inventing a total.
          hint:
              'Millimetres. Leave blank if you do not know: nothing will '
              'be guessed for you.',
          onChanged: (v) => onEdit(TemplateBodyField.bodyDepth, v),
        ),
      if (_inRack)
        _LenRow(
          label: 'Chassis width',
          value: body.chassisWidth,
          // 432, NOT 482.6 (AC-032). 482.6 is the PANEL width including
          // ears; flowing connectors across it draws jacks out past the
          // rails, on the one view that gets taped inside the rack door.
          hint:
              'Millimetres, and 432 for a standard full-width chassis. '
              '482.6 is the panel width including the rack ears, which is '
              'a different measurement.',
          onChanged: (v) => onEdit(
            TemplateBodyField.chassisWidth,
            v ?? const Len(432_000_000),
          ),
        ),
      // Any device may sit on a shelf (DR-204 §11.203.2), so rack gear
      // states its shelf width here; shelf and hosted mounts state it in
      // Size and mounting instead, and are not asked twice.
      if (_inRack && !_sitsOnAShelf(body.mountMethod))
        _ShelfWidthRow(body: body, onEdit: onEdit),
      _MassRow(
        label: 'Weight',
        value: body.weight,
        hint: 'Kilograms. Leave blank if you do not know.',
        onChanged: (v) => onEdit(TemplateBodyField.weight, v),
      ),
      if (_inRack)
        _MassRow(
          label: 'Max unsupported mass',
          value: body.maxUnsupportedMass,
          hint:
              'Kilograms. Heavier than this and the device needs rear '
              'support, which the drawing will call out.',
          onChanged: (v) => onEdit(TemplateBodyField.maxUnsupportedMass, v),
        ),
      if (_inRack)
        _IntRow(
          label: 'Clearance above (U)',
          value: body.requiresClearanceAboveU,
          onChanged: (v) =>
              onEdit(TemplateBodyField.requiresClearanceAboveU, v),
        ),
      if (_inRack)
        _IntRow(
          label: 'Clearance below (U)',
          value: body.requiresClearanceBelowU,
          onChanged: (v) =>
              onEdit(TemplateBodyField.requiresClearanceBelowU, v),
        ),
      if (_inRack)
        _EnumRow<ThermalClass>(
          label: 'Thermal class',
          value: body.thermalClass,
          values: ThermalClass.values,
          nameOf: _thermalLabel,
          onChanged: (v) => onEdit(TemplateBodyField.thermalClass, v),
        ),
      if (_inRack)
        SwitchListTile(
          title: const Text('Container'),
          subtitle: const Text('A shelf or drawer that holds other devices.'),
          value: body.isContainer,
          onChanged: (v) => onEdit(TemplateBodyField.isContainer, v),
        ),
    ],
  );
}

/// docs/06 §3.3.
class _PowerSection extends StatelessWidget {
  const _PowerSection({required this.body, required this.onEdit});

  final TemplateBody body;
  final void Function<T>(TemplateField<T> field, T value) onEdit;

  @override
  Widget build(BuildContext context) {
    final typical = body.power.typicalWatts;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const _SectionNote(
          'Every field here is optional and nothing is guessed for '
          'you. Typical draw in particular is never worked out from the '
          'nameplate: a made-up number that reaches a circuit-loading '
          'calculation is worse than a blank one.',
        ),
        _NullableIntRow(
          label: 'Nameplate watts',
          value: body.power.nameplateWatts,
          hint: 'What the label says',
          onChanged: (v) => onEdit(TemplateBodyField.nameplateWatts, v),
        ),
        _NullableIntRow(
          label: 'Typical watts',
          value: typical,
          // THE HINT IS THE WHOLE POINT OF AC-039. It tells the user the
          // relationship without applying it, because the moment the form
          // applies it the number stops being sourced and starts being
          // invented, and nothing downstream can tell the difference.
          hint:
              'Typical draw is usually 30 to 70 percent of the '
              'nameplate. It is deliberately not filled in for you: put '
              'in a figure you have a source for, or leave it blank.',
          onChanged: (v) => onEdit(TemplateBodyField.typicalWatts, v),
        ),
        _NullableIntRow(
          label: 'Standby watts',
          value: body.power.standbyWatts,
          onChanged: (v) => onEdit(TemplateBodyField.standbyWatts, v),
        ),
        _NullableIntRow(
          label: 'Nominal volts',
          value: body.power.nominalVolts,
          onChanged: (v) => onEdit(TemplateBodyField.nominalVolts, v),
        ),
        _NullableIntRow(
          label: 'Apparent VA',
          value: body.power.apparentVA,
          // LOADING IS COMPUTED IN VA, NOT WATTS (CR-056, AC-020): a
          // linear-supply amplifier at PF 0.65 under-reports current by
          // 35% on exactly the gear where it matters.
          hint:
              'Circuit loading is worked out in VA rather than watts, '
              'because a low power factor makes watts understate the '
              'current the breaker actually sees.',
          onChanged: (v) => onEdit(TemplateBodyField.apparentVA, v),
        ),
        _NullableIntRow(
          label: 'Power factor (permille)',
          value: body.power.powerFactor,
          // PERMILLE, because CR-001 admits no floating point in the
          // persisted model, here or anywhere else.
          hint: 'Whole numbers only: enter 650 for a power factor of 0.65.',
          onChanged: (v) => onEdit(TemplateBodyField.powerFactor, v),
        ),
        _NullableIntRow(
          label: 'PoE budget watts',
          value: body.power.poeBudgetWatts,
          hint: 'Total PoE this device can supply across all its ports.',
          onChanged: (v) => onEdit(TemplateBodyField.poeBudgetWatts, v),
        ),
        _EnumRow<PlugType?>(
          label: 'Inlet plug',
          value: body.power.inletPlug,
          values: const [null, ...PlugType.values],
          nameOf: _plugLabel,
          onChanged: (v) => onEdit(TemplateBodyField.inletPlug, v),
        ),
        SwitchListTile(
          title: const Text('Continuous load'),
          value: body.power.isContinuousLoad,
          onChanged: (v) => onEdit(TemplateBodyField.isContinuousLoad, v),
        ),
        const SizedBox(height: 8),
        // DERIVED, NEVER STORED (CR-005). Shown as a reading rather than
        // as a field, because a box holding heat would be a second source
        // of truth for a number that is arithmetic.
        ListTile(
          dense: true,
          title: const Text('Heat (BTU/hr)'),
          subtitle: Text(
            typical == null
                ? 'Unknown until typical watts is filled in. It is '
                      'worked out from the watts rather than stored, so '
                      'the two can never disagree.'
                : '${wattsToBtuPerHour(typical).toStringAsFixed(1)}, '
                      'worked out from typical watts',
          ),
        ),
        _NullableIntRow(
          label: 'BTU/hr override',
          value: body.power.btuPerHourOverride,
          hint:
              'Only for a manufacturer figure that disagrees with the '
              'number above.',
          onChanged: (v) => onEdit(TemplateBodyField.btuPerHourOverride, v),
        ),
        const SizedBox(height: 16),
        // READ-ONLY AND COUNTED FROM PORTS (docs/06 §3.3), so there is no
        // box: a typed count could disagree with the ports beside it, and
        // one of the two would be printed. Counting them needs the port
        // grid, which is M4-E.
        const _SectionNote(
          'Outlets provided and consumed are counted from the device '
          'port list rather than typed here. The port list is not built '
          'yet.',
        ),
      ],
    );
  }
}

/// docs/06 §3.4.
class _AppearanceSection extends StatelessWidget {
  const _AppearanceSection({required this.body, required this.onEdit});

  final TemplateBody body;
  final void Function<T>(TemplateField<T> field, T value) onEdit;

  @override
  Widget build(BuildContext context) {
    final resolved = effectiveGlyph(body.glyph, body.category);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const _SectionNote(
          'Colour is never the only thing telling devices apart. It '
          'disappears in greyscale and on a photocopy, which is how an '
          'elevation usually reaches a job site, so a device carries a '
          'mark as well.',
        ),
        const Text('Accent colour'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final c in kDeviceAccentSwatches)
              InkWell(
                onTap: () => onEdit(TemplateBodyField.accentColor, c),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Color.fromARGB(c.a, c.r, c.g, c.b),
                    border: Border.all(
                      width: body.accentColor == c ? 3 : 1,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ),
              ),
            TextButton(
              onPressed: () => onEdit(TemplateBodyField.accentColor, null),
              child: const Text('Clear'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _EnumRow<DeviceGlyph?>(
          label: 'Mark',
          value: body.glyph,
          // NULL IS AN OPTION AND IT IS FIRST, because it is the
          // DIFFERENT thing from `none`: null inherits the category's
          // default and `none` draws nothing on purpose. Collapsing them
          // would take away the only way to say "draw no mark".
          values: const [null, ...DeviceGlyph.values],
          nameOf: (v) =>
              v == null ? 'from category (${resolved.name})' : v.name,
          // THE PICKER DRAWS THE MARK THROUGH THE ELEVATION'S OWN
          // GEOMETRY (CR-086), never a look-alike: `DeviceGlyphMark`
          // replays the same `DiagramOp` the sheet emits. `null` shows
          // the category's resolved mark, because that is what choosing
          // it would draw.
          leadingOf: (v) => DeviceGlyphMark(glyph: v ?? resolved),
          onChanged: (v) => onEdit(TemplateBodyField.glyph, v),
        ),
        const _SectionNote(
          'Both appear on the rack elevation. Leaving the mark on the '
          'category default is a good answer; change it when the '
          'category picture is wrong for this device, the way a screen '
          'on a stand is wrong for a speaker.',
        ),
      ],
    );
  }
}

class _SectionNote extends StatelessWidget {
  const _SectionNote(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Text(text, style: Theme.of(context).textTheme.bodySmall),
  );
}

/// docs/06 §3.1.
class _IdentitySection extends StatelessWidget {
  const _IdentitySection({
    required this.body,
    required this.onEdit,
    this.registries,
  });

  final TemplateBody body;
  final void Function<T>(TemplateField<T> field, T value) onEdit;

  /// The project's registries, for the signal-domain picker.
  ///
  /// **NULLABLE BECAUSE THE SCREEN'S IS** (see `DeviceBuilderScreen
  /// .registries`, whose own comment refuses to substitute an empty set:
  /// *"passing empty registries would say the project has none"*). The
  /// picker says which fact is missing rather than showing eight options
  /// it made up.
  final Registries? registries;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      _TextRow(
        label: 'Display name',
        required: true,
        value: body.displayName,
        // AN EXAMPLE IS A PLACEHOLDER, NEVER A HELPER LINE. Under a
        // FILLED field, "HDMI Matrix 16x16" sitting below "Pro Max 24
        // PoE" reads as a second value rather than as a suggestion, and
        // that is how it was reported. `example` shows inside the box
        // only while it is empty; `hint` is guidance that stays true
        // once there is a value.
        example: 'HDMI Matrix 16x16',
        onChanged: (v) => onEdit(TemplateBodyField.displayName, v),
      ),
      _TextRow(
        label: 'Manufacturer',
        value: body.manufacturer,
        // PRE-FILLED WITH `Generic` BY THE CALLER, not defaulted here
        // (DR-056 §11.55). `Generic` is the trade's standard token for
        // "unspecified / by others" in a manufacturer column, so it is
        // the industry's own spelling of what an unknown prints, not a
        // fabricated value under G4.
        example: 'Generic',
        onChanged: (v) => onEdit(TemplateBodyField.manufacturer, v),
      ),
      _TextRow(
        label: 'Model',
        value: body.model,
        // NOT defaulted, unlike the manufacturer (DR-056 §11.55.5): no
        // trade convention was offered for a model string, and an
        // invented one would be the fabrication the manufacturer default
        // is careful not to be. Blank prints an unknown and counts as one.
        hint: 'Leave blank if you do not know it.',
        example: 'DTP CrossPoint 84',
        onChanged: (v) => onEdit(TemplateBodyField.model, v),
      ),
      _CategoryRow(
        value: body.category,
        onChanged: (v) {
          onEdit(TemplateBodyField.category, v);
          // AUTO-SUGGEST, NEVER OVERWRITE (docs/06 §3.1). A prefix the
          // user typed is a decision; filling an EMPTY one from the
          // category is a suggestion. Replacing a typed value because a
          // category changed is how a designator format silently moves
          // under a project that has already printed labels.
          if ((body.typePrefix ?? '').trim().isEmpty) {
            final suggestion = _prefixForCategory(v);
            if (suggestion != null) {
              onEdit(TemplateBodyField.typePrefix, suggestion);
            }
          }
        },
      ),
      _PrimaryDomainRow(
        value: body.primaryDomain,
        registries: registries,
        onChanged: (v) => onEdit(TemplateBodyField.primaryDomain, v),
      ),
      _TextRow(
        label: 'Designator prefix',
        required: true,
        value: body.typePrefix ?? '',
        // THE MOST CRYPTIC LINE ON THE SCREEN, AND IT WAS REPORTED AS
        // ONE. It read "MTX -- seeds MTX-1, MTX-2 (CR-041, CR-045)":
        // "seeds" is our word rather than the trade's, and a ruling id
        // on screen tells a user nothing they can act on. What this
        // field decides is the tag printed beside the device on every
        // sheet, so the helper says that in one sentence.
        hint:
            'Two to four letters. Each device you place is numbered '
            'from it, so MTX gives MTX-1, MTX-2, MTX-3 on the drawings.',
        example: 'MTX',
        onChanged: (v) => onEdit(TemplateBodyField.typePrefix, v),
      ),
      _SizeAndMounting(body: body, onEdit: onEdit),
      _TagsRow(
        value: body.tags,
        onChanged: (v) => onEdit(TemplateBodyField.tags, v),
      ),
      const SizedBox(height: 24),
      Text(
        'Everything outside this section is optional. A template with '
        'just a name, a height and a prefix is not half-finished: it is '
        'a template, and it will place and print like any other.',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      const SizedBox(height: 8),
      // THE LIMIT, SAID OUT LOUD. Saving writes a snapshot into THIS
      // project (docs/06 §7.1's per-project embedded snapshots), because
      // the user library directory is M4-N's and does not exist. A user
      // who expects a shared library and finds out by opening a second
      // job has been misled by silence; one sentence is cheaper than
      // that.
      Text(
        'Saving stores this template in the current project, so it '
        'travels with this file. A shared library you can reuse across '
        'jobs is not built yet.',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ],
  );
}

/// How big the device is and how it mounts, in one place (DR-203
/// §11.202.1, `#951`).
///
/// ═════════════════════════════════════════════════════════════════════
/// THREE QUESTIONS ASKED, THREE ANSWERS SHOWN
/// ═════════════════════════════════════════════════════════════════════
/// A person says how it mounts, how tall it is front and rear, and how
/// wide. `Occupies` and the span in twelfths are READ here, not asked:
/// `derivedOccupancy` writes them on every occupancy edit. Front height
/// sat on Identity and rear height, `Occupies`, mount and width sat on
/// Physical until `#951`, so one fact about a 2U amplifier was typed on
/// two sections and corrected on a third row. The user chose this block
/// from a mockup on 2026-09-29.
///
/// **ON IDENTITY, because the height is one of AC-049's three.** A
/// required fact on the second section is a required fact a person does
/// not see until Save refuses.
///
/// A mount that takes no rack units shows no height and no width at all,
/// rather than greyed rows: `derivedOccupancy` zeroes the heights, so a
/// box there could only ever show a number that is about to be replaced.
class _SizeAndMounting extends StatelessWidget {
  const _SizeAndMounting({required this.body, required this.onEdit});

  final TemplateBody body;
  final void Function<T>(TemplateField<T> field, T value) onEdit;

  @override
  Widget build(BuildContext context) {
    final rack = mountTakesRackUnits(body.mountMethod);
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text('Size and mounting', style: theme.textTheme.titleSmall),
          ),
          _EnumRow<MountMethod>(
            // KEYED ON THE VALUE so an undo that changes it redraws the
            // picker: `DropdownButtonFormField` reads `initialValue` once.
            key: ValueKey(body.mountMethod),
            label: 'How it mounts',
            value: body.mountMethod,
            values: MountMethod.values,
            nameOf: _mountLabel,
            onChanged: (v) => onEdit(TemplateBodyField.mountMethod, v),
          ),
          if (rack)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _IntRow(
                    label: 'RU height (front)',
                    required: true,
                    value: body.frontU,
                    // 0 IS A MEASURED ZERO, not an unknown (G4 cuts the
                    // other way here than for weight): a rear lacing bar
                    // takes nothing at the front.
                    hint: 'Rack units on the front rails.',
                    onChanged: (v) => onEdit(TemplateBodyField.frontU, v),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _IntRow(
                    label: 'RU height (rear)',
                    value: body.rearU,
                    hint:
                        'Follows the front until you type here. Use 0 for '
                        'a front-only device.',
                    onChanged: (v) => onEdit(TemplateBodyField.rearU, v),
                  ),
                ),
              ],
            ),
          if (rack)
            _EnumRow<WidthClass>(
              key: ValueKey(body.widthClass),
              label: 'Width',
              value: body.widthClass,
              values: WidthClass.values,
              nameOf: _widthLabel,
              onChanged: (v) => onEdit(TemplateBodyField.widthClass, v),
            ),
          if (rack && body.widthClass == WidthClass.customWidth)
            _IntRow(
              label: 'Width in twelfths of a rack',
              value: body.nominalSpanTwelfths,
              // HALF-RACK IS A CLASS PLUS A SPAN (CR-030), because 9.5 /
              // 10 / 10.4 / 10.5 in all ship. The named classes carry
              // their span; only a custom width has one to type.
              hint: '12 is full width, 6 is half.',
              onChanged: (v) =>
                  onEdit(TemplateBodyField.nominalSpanTwelfths, v),
            ),
          // WHERE A SHELF-SITTING DEVICE STATES ITS SIZE (DR-204 §11.203.3).
          // It has no rack height, so the one dimension the rack editor
          // needs from it goes where the height would have been.
          if (_sitsOnAShelf(body.mountMethod))
            _ShelfWidthRow(body: body, onEdit: onEdit),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'Occupies: ',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  // THE STORED SIDE, not a fresh derivation: this is a
                  // reading of the file, and a hand-written body that
                  // disagrees should be seen disagreeing.
                  TextSpan(text: _occupancyLabel(body.side)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The mounts whose device is normally set on a shelf.
bool _sitsOnAShelf(MountMethod m) =>
    m == MountMethod.shelf || m == MountMethod.hosted;

/// `TemplateBody.shelfWidth` (DR-204 §11.203.3): blank is UNKNOWN (G4).
class _ShelfWidthRow extends StatelessWidget {
  const _ShelfWidthRow({required this.body, required this.onEdit});

  final TemplateBody body;
  final void Function<T>(TemplateField<T> field, T value) onEdit;

  @override
  Widget build(BuildContext context) => _LenRow(
    label: 'Width on a shelf',
    value: body.shelfWidth,
    // NOT THE CHASSIS WIDTH, which is a 432 mm default on every template
    // and describes a rack panel. This one is only ever what somebody
    // typed, so the rack editor can draw it at true width or say it does
    // not know.
    hint:
        'Millimetres, for when it sits on a shelf. Leave blank if you do '
        'not know: the rack editor will show it as unknown.',
    onChanged: (v) => onEdit(TemplateBodyField.shelfWidth, v),
  );
}

/// The first two or three letters of the category's own words, which is
/// what the seeded catalog's own prefixes look like (`MTX`, `SW`, `PP`).
///
/// A SUGGESTION AND NOT A TABLE, deliberately. A lookup keyed on the nine
/// categories would be a tenth thing to keep in step with
/// `kCatalogCategoryOrder`, and it would still be wrong for most
/// templates: the catalog's 48 carry ~40 distinct prefixes across those
/// nine categories, so no per-category constant is right more than once.
/// This fills an empty box with something plausible and typing over it is
/// one keystroke.
String? _prefixForCategory(String category) {
  final word = category
      .split(RegExp('[^A-Za-z]+'))
      .firstWhere(
        (w) => w.isNotEmpty,
        orElse: () => '',
      );
  if (word.length < 2) return null;
  return word.substring(0, word.length < 3 ? 2 : 3).toUpperCase();
}

class _TextRow extends StatefulWidget {
  const _TextRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.hint,
    this.example,
    this.required = false,
  });

  final String label;
  final String value;

  /// Guidance that stays true once the field has a value. Sits BELOW the
  /// box, permanently.
  final String? hint;

  /// A sample value, shown INSIDE the box and only while it is empty.
  ///
  /// **The two are not interchangeable, and confusing them is what got
  /// reported.** `HDMI Matrix 16x16` was a helper line, so it went on
  /// sitting under `Pro Max 24 PoE` after the user had typed a name, and
  /// read as a second value rather than as a suggestion. An example is
  /// only useful while there is nothing there, which is exactly what
  /// `hintText` does and `helperText` does not.
  final String? example;

  final bool required;
  final ValueChanged<String> onChanged;

  @override
  State<_TextRow> createState() => _TextRowState();
}

class _TextRowState extends State<_TextRow> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// PULLS THE MODEL BACK INTO THE BOX, and without it undo is a button
  /// that appears to do nothing.
  ///
  /// A `TextEditingController` seeded once in `initState` never hears
  /// about a change it did not cause, so `Undo` would revert
  /// `TemplateBody.displayName` while the field kept showing the text the
  /// user typed. The model and the screen would disagree, silently, and
  /// the next keystroke would write the stale text straight back over the
  /// restored value.
  ///
  /// Guarded on inequality so ordinary typing is untouched: `onChanged`
  /// updates the model, the parent rebuilds, and this sees a value that
  /// already matches. Only an out-of-band change (undo, redo, or the
  /// category auto-suggesting a prefix) gets past the guard, which is
  /// also what keeps the caret where it was.
  @override
  void didUpdateWidget(_TextRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextField(
      controller: _controller,
      decoration: InputDecoration(
        labelText: widget.required ? '${widget.label} *' : widget.label,
        hintText: widget.example,
        helperText: widget.hint,
        // Three lines, because several hints are a full sentence and a
        // clipped explanation is worse than none. `helperMaxLines` above
        // 1 is what stops "Two to four letters. Each device you place is
        // numbered from it…" ending at "Two to four lette…".
        helperMaxLines: 3,
        border: const OutlineInputBorder(),
      ),
      onChanged: widget.onChanged,
    ),
  );
}

class _IntRow extends StatefulWidget {
  const _IntRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.hint,
    this.required = false,
  });

  final String label;
  final int value;
  final String? hint;
  final bool required;
  final ValueChanged<int> onChanged;

  @override
  State<_IntRow> createState() => _IntRowState();
}

class _IntRowState extends State<_IntRow> {
  late final TextEditingController _controller = TextEditingController(
    text: '${widget.value}',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// See `_TextRowState.didUpdateWidget`. Compared on the PARSED value
  /// rather than on the string, so that a box reading `007` is not
  /// rewritten to `7` under the caret while somebody is still typing.
  @override
  void didUpdateWidget(_IntRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (int.tryParse(_controller.text.trim()) != widget.value) {
      final text = '${widget.value}';
      _controller.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextField(
      controller: _controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: widget.required ? '${widget.label} *' : widget.label,
        helperText: widget.hint,
        helperMaxLines: 3,
        border: const OutlineInputBorder(),
      ),
      // UNPARSEABLE TEXT IS IGNORED, NOT COERCED TO ZERO. `int.tryParse`
      // returning null means the box currently holds something that is
      // not a number (it is empty, or mid-edit); writing 0 for it would
      // record a MEASURED zero-U device, which is a real and different
      // claim. The model keeps its last good value until the box holds a
      // number again.
      onChanged: (t) {
        final parsed = int.tryParse(t.trim());
        if (parsed != null) widget.onChanged(parsed);
      },
    ),
  );
}

/// A nullable integer, where BLANK MEANS UNKNOWN and never zero.
///
/// This is G4 as a text box. `_IntRow` keeps its last good value when the
/// text stops parsing, because its field cannot be absent; this one does
/// the opposite and writes null, because an emptied box is the user
/// saying they do not know. The two look identical on screen and mean
/// opposite things, which is why they are separate widgets rather than
/// one with a flag.
class _NullableIntRow extends StatefulWidget {
  const _NullableIntRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.hint,
  });

  final String label;
  final int? value;
  final String? hint;
  final ValueChanged<int?> onChanged;

  @override
  State<_NullableIntRow> createState() => _NullableIntRowState();
}

class _NullableIntRowState extends State<_NullableIntRow> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value?.toString() ?? '',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_NullableIntRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (int.tryParse(_controller.text.trim()) != widget.value) {
      final text = widget.value?.toString() ?? '';
      _controller.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextField(
      controller: _controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: widget.label,
        helperText: widget.hint,
        helperMaxLines: 3,
        border: const OutlineInputBorder(),
      ),
      onChanged: (t) {
        final trimmed = t.trim();
        if (trimmed.isEmpty) {
          widget.onChanged(null);
          return;
        }
        final parsed = int.tryParse(trimmed);
        // Half-typed junk is ignored rather than written as null: the
        // user is mid-keystroke, not declaring an unknown.
        if (parsed != null) widget.onChanged(parsed);
      },
    ),
  );
}

/// Millimetres in, nanometres out (CR-001).
///
/// **The box takes mm because a spec sheet is written in mm**, and
/// `Len.fromMillimetres` is the one conversion site, named for the reason
/// its own doc gives: the seed catalog once carried nine hand-rolled
/// copies of this and of the mass one, and the mass copies were wrong by
/// 1000x for as long as nobody could review a literal against its unit.
/// **No `double` ever reaches the model**; the conversion rounds to an
/// exact integer count of nanometres here and nothing downstream sees a
/// millimetre again.
class _LenRow extends StatefulWidget {
  const _LenRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.hint,
  });

  final String label;
  final Len? value;
  final String? hint;
  final ValueChanged<Len?> onChanged;

  @override
  State<_LenRow> createState() => _LenRowState();
}

class _LenRowState extends State<_LenRow> {
  static String _mm(Len? v) =>
      v == null ? '' : (v.nm / Len.nmPerMillimetre).toStringAsFixed(1);

  late final TextEditingController _controller = TextEditingController(
    text: _mm(widget.value),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_LenRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    final shown = double.tryParse(_controller.text.trim());
    final want = widget.value == null
        ? null
        : widget.value!.nm / Len.nmPerMillimetre;
    if (shown != want) {
      final text = _mm(widget.value);
      _controller.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextField(
      controller: _controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: widget.label,
        helperText: widget.hint,
        helperMaxLines: 3,
        border: const OutlineInputBorder(),
      ),
      onChanged: (t) {
        final trimmed = t.trim();
        if (trimmed.isEmpty) {
          widget.onChanged(null);
          return;
        }
        final parsed = double.tryParse(trimmed);
        if (parsed != null) widget.onChanged(Len.fromMillimetres(parsed));
      },
    ),
  );
}

/// Kilograms in, micrograms out (CR-003). See `_LenRow` for the reasoning.
class _MassRow extends StatefulWidget {
  const _MassRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.hint,
  });

  final String label;
  final Mass? value;
  final String? hint;
  final ValueChanged<Mass?> onChanged;

  @override
  State<_MassRow> createState() => _MassRowState();
}

class _MassRowState extends State<_MassRow> {
  static const int _ugPerKilogram = 1_000_000_000;

  static String _kg(Mass? v) =>
      v == null ? '' : (v.ug / _ugPerKilogram).toStringAsFixed(2);

  late final TextEditingController _controller = TextEditingController(
    text: _kg(widget.value),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_MassRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    final shown = double.tryParse(_controller.text.trim());
    final want = widget.value == null
        ? null
        : widget.value!.ug / _ugPerKilogram;
    if (shown != want) {
      final text = _kg(widget.value);
      _controller.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextField(
      controller: _controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: widget.label,
        helperText: widget.hint,
        helperMaxLines: 3,
        border: const OutlineInputBorder(),
      ),
      onChanged: (t) {
        final trimmed = t.trim();
        if (trimmed.isEmpty) {
          widget.onChanged(null);
          return;
        }
        final parsed = double.tryParse(trimmed);
        if (parsed != null) widget.onChanged(Mass.fromKilograms(parsed));
      },
    ),
  );
}

// ═════════════════════════════════════════════════════════════════════
// WHAT THE DROPDOWNS SAY, AND WHY IT IS NOT `.name`
// ═════════════════════════════════════════════════════════════════════
// The first build put the raw enum identifier in front of the user, so
// the mount-method menu offered `rackEars`, `notInRack` and `zeroU`, and
// occupancy offered `zeroUVertical`. Those are Dart spellings of trade
// facts, not the trade's own words, and they land in the same complaint
// the designator prefix did: a control whose wording nobody outside this
// repository can read.
//
// The tables below are the trade's spelling. They are per-value and
// hand-written rather than a `camelCase` splitter, because "0U" is not
// "zero u", "C14" is not "c14" and "NEMA 5-15P" is not "nema515p": the
// cases that matter are exactly the ones an algorithm gets wrong.
String _occupancyLabel(OccupancySide v) => switch (v) {
  OccupancySide.front => 'Front only',
  OccupancySide.rear => 'Rear only',
  OccupancySide.both => 'Front and rear',
  OccupancySide.zeroUVertical => '0U, vertical in the rear channel',
  OccupancySide.none => 'Does not sit in the rack',
};

String _mountLabel(MountMethod v) => switch (v) {
  MountMethod.rackEars => 'Rack ears',
  MountMethod.shelf => 'On a shelf',
  MountMethod.zeroU => '0U mount',
  MountMethod.sideMount => 'Side mounted',
  MountMethod.rearRail => 'Rear rail',
  MountMethod.furniture => 'In furniture',
  MountMethod.hosted => 'Hosted in another device',
  MountMethod.notInRack => 'Not in a rack',
};

String _widthLabel(WidthClass v) => switch (v) {
  WidthClass.full => 'Full width',
  WidthClass.half => 'Half rack',
  WidthClass.third => 'Third rack',
  WidthClass.quarter => 'Quarter rack',
  WidthClass.customWidth => 'Custom width',
};

String _thermalLabel(ThermalClass v) => switch (v) {
  ThermalClass.passive => 'Passive, no fan',
  ThermalClass.lowHeat => 'Runs cool',
  ThermalClass.highHeat => 'Runs hot',
  ThermalClass.activeCooled => 'Fan cooled',
};

String _plugLabel(PlugType? v) => switch (v) {
  null => 'Unknown',
  PlugType.c14 => 'IEC C14',
  PlugType.c20 => 'IEC C20',
  PlugType.nema515p => 'NEMA 5-15P',
  PlugType.hardwired => 'Hardwired',
  PlugType.wallWart => 'External power brick',
};

/// A closed set: nothing to parse and nothing to typo.
class _EnumRow<T> extends StatelessWidget {
  const _EnumRow({
    required this.label,
    required this.value,
    required this.values,
    required this.nameOf,
    required this.onChanged,
    this.leadingOf,
    super.key,
  });

  final String label;
  final T value;
  final List<T> values;
  final String Function(T) nameOf;
  final ValueChanged<T> onChanged;

  /// An optional mark drawn beside each option, so a picker whose values
  /// ARE pictures shows the picture (#756). Null for every other row.
  final Widget Function(T)? leadingOf;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: DropdownButtonFormField<T>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: [
        for (final v in values)
          DropdownMenuItem<T>(
            value: v,
            child: leadingOf == null
                ? Text(nameOf(v))
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      leadingOf!(v),
                      const SizedBox(width: 8),
                      Text(nameOf(v)),
                    ],
                  ),
          ),
      ],
      onChanged: (v) {
        if (v is T) onChanged(v);
      },
    ),
  );
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: DropdownButtonFormField<String>(
      // READS `kCatalogCategoryOrder`, the constant the palette groups
      // by, and does not restate it (DR-059 §11.58.6). docs/06 §3.1 spent
      // four milestones spelling eight categories against a catalog
      // shipping nine, which is what a second list produces.
      initialValue: value.isEmpty ? null : value,
      decoration: const InputDecoration(
        labelText: 'Category',
        helperText: 'Optional. Suggests a designator prefix and a mark.',
        border: OutlineInputBorder(),
      ),
      items: [
        for (final c in kCatalogCategoryOrder)
          DropdownMenuItem(value: c, child: Text(c)),
      ],
      onChanged: (v) => onChanged(v ?? ''),
    ),
  );
}

/// The signal-domain picker's handle, public so a case can drive the
/// control the product shows rather than one it rebuilt.
const Key kPrimaryDomainFieldKey = ValueKey('template-primary-domain');

/// Which of the eight signal domains this device mostly IS (`#899`,
/// DR-169 §11.168.5).
///
/// ═══════════════════════════════════════════════════════════════════════
/// WHY THIS IS TYPED AND NOT DERIVED FROM THE PORT LIST
/// ═══════════════════════════════════════════════════════════════════════
/// The port list answers *what can be plugged into this*. It does not
/// answer *what is it*, and the census that settled the question is on
/// the model field: of 51 seeded templates only 13 have ports in a single
/// domain, because nearly everything has a power lead and a control port,
/// and a television reads as video, audio and network at once.
///
/// **NOT SET IS AN OPTION AND IT IS FIRST** (G4). An unknown domain draws
/// the neutral mark on a plan; it is not "general" and not the first
/// domain in some order.
class _PrimaryDomainRow extends StatelessWidget {
  const _PrimaryDomainRow({
    required this.value,
    required this.onChanged,
    this.registries,
  });

  final SignalDomainId? value;
  final Registries? registries;
  final ValueChanged<SignalDomainId?> onChanged;

  @override
  Widget build(BuildContext context) {
    final domains = registries?.signalDomains.values.toList() ?? const [];
    if (domains.isEmpty) {
      // SAYS WHICH FACT IS MISSING, rather than offering a made-up list
      // or a control that silently does nothing (docs/04 §3.4).
      return const Padding(
        padding: EdgeInsets.only(bottom: 16),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: 'Signal domain',
            helperText:
                'The project registries were not supplied, so the '
                'domains cannot be listed here.',
            border: OutlineInputBorder(),
            enabled: false,
          ),
          child: Text('Not available'),
        ),
      );
    }
    // A TOTAL ORDER, because `Map` iteration is insertion order and a
    // reopened file enumerates differently: the picker must not reshuffle
    // between sessions.
    domains.sort((a, b) => a.id.v.compareTo(b.id.v));
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        key: kPrimaryDomainFieldKey,
        initialValue: value?.v,
        decoration: const InputDecoration(
          labelText: 'Signal domain',
          helperText:
              'Optional. Colours this device on a floorplan, and '
              'is what it mostly IS rather than everything it carries.',
          border: OutlineInputBorder(),
        ),
        items: [
          // NO `value:`, WHICH IS THE NULL OPTION. Writing `value: null`
          // says the same thing and is an analyzer info against an exact
          // pin; the name of the item is what carries the meaning.
          const DropdownMenuItem(child: Text('Not set')),
          for (final d in domains)
            DropdownMenuItem(value: d.id.v, child: Text(d.displayName)),
        ],
        onChanged: (v) => onChanged(v == null ? null : SignalDomainId(v)),
      ),
    );
  }
}

class _TagsRow extends StatefulWidget {
  const _TagsRow({required this.value, required this.onChanged});

  final List<String> value;
  final ValueChanged<List<String>> onChanged;

  @override
  State<_TagsRow> createState() => _TagsRowState();
}

class _TagsRowState extends State<_TagsRow> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _add() {
    final tag = _controller.text.trim().toLowerCase();
    // A DUPLICATE IS DROPPED SILENTLY rather than refused. The user's
    // intent ("this template is tagged hdbaset") is already satisfied,
    // and an error for an action whose goal is already met is noise.
    if (tag.isEmpty || widget.value.contains(tag)) {
      _controller.clear();
      return;
    }
    widget.onChanged([...widget.value, tag]);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          decoration: const InputDecoration(
            labelText: 'Tags',
            helperText: 'Enter to add. Searched by the library browser.',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => _add(),
        ),
        if (widget.value.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              spacing: 6,
              children: [
                for (final tag in widget.value)
                  InputChip(
                    label: Text(tag),
                    onDeleted: () => widget.onChanged(
                      [...widget.value]..remove(tag),
                    ),
                  ),
              ],
            ),
          ),
      ],
    ),
  );
}
