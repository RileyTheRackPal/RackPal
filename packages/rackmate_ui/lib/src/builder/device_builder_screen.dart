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
// the batch inspector needs a grid selection, which is M4-E. **There is
// nothing to put in a 340px dock**, so it is not drawn.
//
// The Structure editor set this precedent explicitly: `#148` shipped with
// NO tab strip at all because one surface satisfied its ruling outright,
// and `#149` added the strip when there was a second thing to switch to.
// A pane that opens nothing is the `UnbuiltView` defect wearing a
// different hat.
//
// The section rail obeys the same rule. §3 lists seven sections; four
// exist (Identity, Physical, Power, Appearance) and three do not: Ports
// is M4-E, Panel Layout is M4-K, Notes & Publish is M4-P. The rail lists
// the four that work.
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
}) => showDialog<void>(
  context: context,
  builder: (context) => Dialog.fullscreen(
    child: DeviceBuilderScreen(
      template: template,
      actions: actions,
      onDone: () => Navigator.of(context).pop(),
    ),
  ),
);

/// The four sections that exist. See the file header for the three that
/// do not.
enum BuilderSection {
  identity('Identity'),
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
    this.onDone,
    super.key,
  });

  /// The template to edit. **Never mutated**: `TemplateEditSession`
  /// deep-copies it, which is what makes closing without saving a
  /// complete undo (CR-106, M4-A/4).
  final TemplateBody template;

  final DeviceBuilderActions actions;
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
            SizedBox(
              width: 200,
              child: _SectionRail(
                selected: _section,
                canSave: _canSave,
                onSelect: (s) => setState(() => _section = s),
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: switch (_section) {
                BuilderSection.identity => _IdentitySection(
                  body: _session.body,
                  onEdit: _run,
                ),
                // M4-D/3's three sections land here next. Rendering an
                // empty pane for them would be the control-that-does-
                // nothing this file's header refuses, so the rail does
                // not offer them until they exist.
                _ => const _NotYetSection(),
              },
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

class _NotYetSection extends StatelessWidget {
  const _NotYetSection();

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(24),
      child: Text('This section arrives with M4-D/3.'),
    ),
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
        hint: 'HDMI Matrix 16x16',
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
        hint: 'Generic',
        onChanged: (v) => onEdit(TemplateBodyField.manufacturer, v),
      ),
      _TextRow(
        label: 'Model',
        value: body.model,
        // NOT defaulted, unlike the manufacturer (DR-056 §11.55.5): no
        // trade convention was offered for a model string, and an
        // invented one would be the fabrication the manufacturer default
        // is careful not to be. Blank prints an unknown and counts as one.
        hint: 'left blank counts as unknown',
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
        hint: 'MTX — seeds MTX-1, MTX-2 (CR-041, CR-045)',
        onChanged: (v) => onEdit(TemplateBodyField.typePrefix, v),
      ),
      _IntRow(
        label: 'RU height (front)',
        required: true,
        value: body.frontU,
        // 0 IS A MEASURED ZERO, not an unknown: a 0U vertical PDU
        // occupies no rack units and says so. G4 cuts the other way here
        // than it does for weight, which is why this field is an `int`.
        hint: '0 is a real answer: a 0U device',
        onChanged: (v) => onEdit(TemplateBodyField.frontU, v),
      ),
      _TagsRow(
        value: body.tags,
        onChanged: (v) => onEdit(TemplateBodyField.tags, v),
      ),
      const SizedBox(height: 24),
      Text(
        'Everything outside this section is optional. A template saved '
        'with a name, a height and a prefix is not incomplete: it is a '
        'template (AC-049).',
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
    this.required = false,
  });

  final String label;
  final String value;
  final String? hint;
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
        helperText: widget.hint,
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
        helperText: 'Optional (AC-049). Suggests a prefix and a glyph.',
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
