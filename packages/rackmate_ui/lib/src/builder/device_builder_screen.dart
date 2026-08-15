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
import 'package:flutter/material.dart';
import 'package:rackmate_core/rackmate_core.dart';
import 'package:rackmate_ui/src/builder/port_grid.dart';

/// What the app does when the builder asks for something.
///
/// CALLBACKS AND NOT A CONTROLLER, the shape `StructureEditorActions` and
/// `DropEntryActions` already use, so `rackmate_ui` stays free of the
/// session layer.
@immutable
final class DeviceBuilderActions {
  const DeviceBuilderActions({required this.onSave});

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

/// Opens the builder over [template].
///
/// A FULL-WINDOW SURFACE, NOT A FLOATING CARD. docs/06 §2: *"a modal
/// cannot host a 68-row virtualised grid"*. `Dialog.fullscreen` is how
/// `showStructureEditor` says the same thing, and the grid it is being
/// sized for is M4-E's.
Future<void> showDeviceBuilder(
  BuildContext context, {
  required TemplateBody template,
  required DeviceBuilderActions actions,
  Registries? registries,
  IdFormat portDesignatorFormat = const IdFormat('J{PORT_SEQ:2}'),
}) => showDialog<void>(
  context: context,
  builder: (context) => Dialog.fullscreen(
    child: DeviceBuilderScreen(
      template: template,
      actions: actions,
      registries: registries,
      portDesignatorFormat: portDesignatorFormat,
      onDone: () => Navigator.of(context).pop(),
    ),
  ),
);

/// The four sections that exist. See the file header for the three that
/// do not.
enum BuilderSection {
  identity('Identity'),

  /// docs/06 §2 puts PORTS here, second, and it is the product: the I/O
  /// editor is what the exit criterion is measured on, and the metadata
  /// form is what a user fills in once.
  ports('Ports'),
  physical('Physical'),
  power('Power'),
  appearance('Appearance');

  const BuilderSection(this.label);

  final String label;
}

/// docs/06 §2's editor, in the shape M4-D actually builds.
class DeviceBuilderScreen extends StatefulWidget {
  const DeviceBuilderScreen({
    required this.template,
    required this.actions,
    this.registries,
    this.portDesignatorFormat = const IdFormat('J{PORT_SEQ:2}'),
    this.onDone,
    super.key,
  });

  /// The template to edit. **Never mutated**: `TemplateEditSession`
  /// deep-copies it, which is what makes closing without saving a
  /// complete undo (CR-106, M4-A/4).
  final TemplateBody template;

  final DeviceBuilderActions actions;

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

  @override
  State<DeviceBuilderScreen> createState() => _DeviceBuilderScreenState();
}

class _DeviceBuilderScreenState extends State<DeviceBuilderScreen> {
  late final TemplateEditSession _session = TemplateEditSession(
    widget.template,
  );

  /// The body as it was when the window opened, for the change class.
  /// A COPY, because `_session.body` is the live one and diffing a thing
  /// against itself always answers "unchanged".
  late final TemplateBody _opened = copyTemplateBody(widget.template);

  BuilderSection _section = BuilderSection.identity;
  String? _refusal;

  @override
  void dispose() {
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
  /// So a zero height must be MEANT, and the model already has the
  /// spelling for meaning it: docs/06 §3.2 writes a 0U PDU as
  /// `{front: 0, rear: 0, side: zeroUVertical}`. That is the one
  /// combination in which `0` is a measured zero rather than an untouched
  /// default, which is G4's own distinction applied to occupancy.
  bool get _canSave {
    final b = _session.body;
    return b.displayName.trim().isNotEmpty &&
        (b.typePrefix ?? '').trim().isNotEmpty &&
        (b.frontU > 0 || b.side == OccupancySide.zeroUVertical);
  }

  TemplateChangeReport get _report =>
      classifyTemplateChange(_opened, _session.body);

  /// Runs one field write and repaints, unless it would write the value
  /// already
  /// there. The guard is not an optimisation: an undo entry that changes
  /// nothing is one the user has to press Ctrl+Z through twice.
  void _run<T>(TemplateField<T> field, T value) {
    if (field.get(_session.body) == value) return;
    setState(() {
      _session.run(
        SetTemplateFieldCommand<T>(
          field: field,
          from: field.get(_session.body),
          to: value,
        ),
      );
      _refusal = null;
    });
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

  @override
  Widget build(BuildContext context) => Column(
    children: [
      _Header(
        session: _session,
        report: _report,
        canSave: _canSave,
        onUndo: _session.undo.canUndo
            ? () => setState(_session.undoLast)
            : null,
        onRedo: _session.undo.canRedo
            ? () => setState(_session.redoLast)
            : null,
        onSave: _canSave ? () => _save(close: false) : null,
        onSaveAndClose: _canSave ? () => _save(close: true) : null,
        onClose: widget.onDone,
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
                  selected: _section,
                  canSave: _canSave,
                  onSelect: (s) => setState(() => _section = s),
                ),
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: FocusTraversalGroup(
                child: switch (_section) {
                  BuilderSection.identity => _IdentitySection(
                    body: _session.body,
                    onEdit: _run,
                  ),
                  BuilderSection.ports => PortGrid(
                    body: _session.body,
                    registries: widget.registries ?? Registries(),
                    portDesignatorFormat: widget.portDesignatorFormat,
                    actions: PortGridActions(
                      run: _runCommand,
                      transact: _transact,
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
          ],
        ),
      ),
    ],
  );
}

class _Header extends StatelessWidget {
  const _Header({
    required this.session,
    required this.report,
    required this.canSave,
    required this.onUndo,
    required this.onRedo,
    required this.onSave,
    required this.onSaveAndClose,
    required this.onClose,
  });

  final TemplateEditSession session;
  final TemplateChangeReport report;
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
              name.isEmpty ? 'Untitled device' : name,
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
              _ChangeClassChip(report: report),
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
                message: canSave
                    ? 'Save'
                    : 'Needs a name, a designator prefix, and an RU height '
                          'above 0 (or a 0U mount on the Physical section)',
                child: FilledButton(
                  onPressed: onSave,
                  child: const Text('Save'),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonal(
                onPressed: onSaveAndClose,
                child: const Text('Save & Close'),
              ),
              const SizedBox(width: 8),
              TextButton(onPressed: onClose, child: const Text('Close')),
            ],
          ),
        ],
      ),
    );
  }
}

/// docs/06 §7.2's verdict, beside the button it is about.
class _ChangeClassChip extends StatelessWidget {
  const _ChangeClassChip({required this.report});

  final TemplateChangeReport report;

  @override
  Widget build(BuildContext context) {
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
    return Tooltip(
      message: reasons,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(label),
      ),
    );
  }
}

class _SectionRail extends StatelessWidget {
  const _SectionRail({
    required this.selected,
    required this.canSave,
    required this.onSelect,
  });

  final BuilderSection selected;
  final bool canSave;
  final ValueChanged<BuilderSection> onSelect;

  @override
  Widget build(BuildContext context) => ListView(
    children: [
      for (final s in BuilderSection.values)
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
    ],
  );
}

/// docs/06 §3.2. Occupancy is a struct, never a scalar (CR-036).
class _PhysicalSection extends StatelessWidget {
  const _PhysicalSection({required this.body, required this.onEdit});

  final TemplateBody body;
  final void Function<T>(TemplateField<T> field, T value) onEdit;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      const _SectionNote(
        'Where a device sits takes more than one number. A 2U patch '
        'panel fills 2U front and back; a rear lacing bar takes nothing '
        'at the front and 1U behind; a 0U PDU takes no rack units at '
        'all and mounts vertically.',
      ),
      _IntRow(
        label: 'RU height (rear)',
        value: body.rearU,
        hint:
            'How much it takes up behind the rails. A front-only '
            'device is 0.',
        onChanged: (v) => onEdit(TemplateBodyField.rearU, v),
      ),
      _EnumRow<OccupancySide>(
        label: 'Occupies',
        value: body.side,
        values: OccupancySide.values,
        nameOf: _occupancyLabel,
        onChanged: (v) => onEdit(TemplateBodyField.side, v),
      ),
      _EnumRow<MountMethod>(
        label: 'Mount method',
        value: body.mountMethod,
        values: MountMethod.values,
        nameOf: _mountLabel,
        onChanged: (v) => onEdit(TemplateBodyField.mountMethod, v),
      ),
      _EnumRow<WidthClass>(
        label: 'Width class',
        value: body.widthClass,
        values: WidthClass.values,
        nameOf: _widthLabel,
        onChanged: (v) => onEdit(TemplateBodyField.widthClass, v),
      ),
      _IntRow(
        label: 'Width in twelfths of a rack',
        value: body.nominalSpanTwelfths,
        // HALF-RACK IS A CLASS PLUS A SPAN, never "0.5 rack width"
        // (CR-030), because 9.5 / 10 / 10.4 / 10.5 in all ship and a
        // fraction cannot tell them apart.
        hint:
            '12 is full width, 6 is half. Half-rack gear is not all one '
            'width, which is why this sits alongside the width class '
            'rather than instead of it.',
        onChanged: (v) => onEdit(TemplateBodyField.nominalSpanTwelfths, v),
      ),
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
      _MassRow(
        label: 'Weight',
        value: body.weight,
        hint: 'Kilograms. Leave blank if you do not know.',
        onChanged: (v) => onEdit(TemplateBodyField.weight, v),
      ),
      _MassRow(
        label: 'Max unsupported mass',
        value: body.maxUnsupportedMass,
        hint:
            'Kilograms. Heavier than this and the device needs rear '
            'support, which the drawing will call out.',
        onChanged: (v) => onEdit(TemplateBodyField.maxUnsupportedMass, v),
      ),
      _IntRow(
        label: 'Clearance above (U)',
        value: body.requiresClearanceAboveU,
        onChanged: (v) => onEdit(TemplateBodyField.requiresClearanceAboveU, v),
      ),
      _IntRow(
        label: 'Clearance below (U)',
        value: body.requiresClearanceBelowU,
        onChanged: (v) => onEdit(TemplateBodyField.requiresClearanceBelowU, v),
      ),
      _EnumRow<ThermalClass>(
        label: 'Thermal class',
        value: body.thermalClass,
        values: ThermalClass.values,
        nameOf: _thermalLabel,
        onChanged: (v) => onEdit(TemplateBodyField.thermalClass, v),
      ),
      SwitchListTile(
        title: const Text('Passthrough'),
        subtitle: const Text(
          'A patch panel or plate: front and rear ports pair up. The '
          'pairing itself is set in the port grid.',
        ),
        value: body.isPassthrough,
        onChanged: (v) => onEdit(TemplateBodyField.isPassthrough, v),
      ),
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

  /// A small fixed set, not a full picker. The value is an `Rgb` on the
  /// model and a wheel would invite a hue nobody checked against the
  /// greyscale gate; these are the eight Okabe-Ito hues the palette
  /// already ships, which PAL-1 has already cleared.
  static const _swatches = <Rgb>[
    Rgb(0x00, 0x00, 0x00),
    Rgb(0xE6, 0x9F, 0x00),
    Rgb(0x56, 0xB4, 0xE9),
    Rgb(0x00, 0x9E, 0x73),
    Rgb(0xF0, 0xE4, 0x42),
    Rgb(0x00, 0x72, 0xB2),
    Rgb(0xD5, 0x5E, 0x00),
    Rgb(0xCC, 0x79, 0xA7),
  ];

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
            for (final c in _swatches)
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
          onChanged: (v) => onEdit(TemplateBodyField.glyph, v),
        ),
        const _SectionNote(
          'The marks are not drawn on anything yet. Choosing one now '
          'means it is already set when they start appearing on '
          'elevations.',
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
  const _IdentitySection({required this.body, required this.onEdit});

  final TemplateBody body;
  final void Function<T>(TemplateField<T> field, T value) onEdit;

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
      _IntRow(
        label: 'RU height (front)',
        required: true,
        value: body.frontU,
        // 0 IS A MEASURED ZERO, not an unknown: a 0U vertical PDU
        // occupies no rack units and says so. G4 cuts the other way here
        // than it does for weight, which is why this field is an `int`.
        hint:
            'How many rack units the front of the device takes up. '
            'Use 0 only for gear that mounts vertically in the rear '
            'channel rather than on the rails.',
        onChanged: (v) => onEdit(TemplateBodyField.frontU, v),
      ),
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
  });

  final String label;
  final T value;
  final List<T> values;
  final String Function(T) nameOf;
  final ValueChanged<T> onChanged;

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
          DropdownMenuItem<T>(value: v, child: Text(nameOf(v))),
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
