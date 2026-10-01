// File ▸ Sheet set… (`#969` DR-209 §11.208, `#312` DR-210 §11.209).
//
// ═══════════════════════════════════════════════════════════════════════
// WHAT THE DRAWING SET'S FRONT PAGES PRINT, AND NOTHING ELSE
// ═══════════════════════════════════════════════════════════════════════
// Project settings is modelling defaults: units, RU numbering, designator
// formats. This is deliverable prose, the words a client reads in the
// title block, on the cover and on T0.01. The user chose a dialog of its
// own over a section at the foot of Project settings, and the fact that
// priced it was that NOTHING wrote `ProjectInfo`: the title block every
// sheet prints had no editor until `#312` put it here.
//
// ── THE TITLE BLOCK, GROUPED AS PRINTED (§11.209.2) ─────────────────────
// Project, Client and site, Integrator, Sign-off, from
// `ProjectInfoFields.groups`, then the cover's scope paragraph, then the
// legend. A field commits when it is left, like a legend row.
//
// ── ROWS, NOT A TEXT BOX (§11.208.3) ────────────────────────────────────
// One row per abbreviation and one per note, each removable, with an add
// control per list. Nothing is parsed, so there is no malformed line.
//
// ── DRAFTS, AND WHEN ONE BECOMES A COMMAND ─────────────────────────────
// The rows are local drafts over `ProjectInfo`. A draft reaches the
// document when a field is submitted, loses focus or is tapped away from,
// when a row is removed, and when the dialog closes: one command each, so
// every edit is one undo step. `Add` makes an empty draft and no command,
// since an empty row is not something the author wrote and the command
// would drop it anyway.
//
// **AN UNEDITED PROJECT STAYS UNEDITED.** The seed shows as ordinary rows,
// and a commit whose rows still equal what the document already prints
// sends nothing, so clicking into a field and out again does not freeze
// today's seed into the file.
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:rackpal_core/rackpal_core.dart';

/// What the dialog hands back: commands for the document's undo stack.
typedef SheetSetEdit = void Function(List<Command<RackDocument>> commands);

/// The label on the File menu item that opens this.
const String kSheetSetLabel = 'Sheet set…';

/// The dialog's list, so a test can scroll THIS one (`AlertDialog` wraps
/// its content in a `Scrollable` of its own).
const Key kSheetSetListKey = Key('sheet-set-list');

/// `+ Add abbreviation`.
const Key kAddAbbreviationKey = Key('sheet-set-add-abbreviation');

/// `+ Add note`.
const Key kAddNoteKey = Key('sheet-set-add-note');

/// `Restore defaults`, for both lists at once.
const Key kRestoreLegendDefaultsKey = Key('sheet-set-restore-legend');

/// The abbreviation field on row [row], counted from 0.
Key abbreviationFieldKey(int row) => Key('sheet-set-abbr-$row');

/// The meaning field on row [row].
Key meaningFieldKey(int row) => Key('sheet-set-meaning-$row');

/// The remove control on abbreviation row [row].
Key removeAbbreviationKey(int row) => Key('sheet-set-abbr-remove-$row');

/// The field on note [row].
Key noteFieldKey(int row) => Key('sheet-set-note-$row');

/// The remove control on note [row].
Key removeNoteKey(int row) => Key('sheet-set-note-remove-$row');

/// The text field for one title-block or cover field (`#312`).
Key projectInfoFieldKey(ProjectInfoField field) =>
    Key('sheet-set-info-${field.key}');

/// What a cleared project name says (DR-210 §11.209.4).
const String kProjectNameRequired =
    'A project needs a name: it heads every sheet.';

/// Opens the sheet set editor over [doc].
Future<void> showSheetSetDialog(
  BuildContext context, {
  required RackDocument doc,
  required SheetSetEdit onEdit,
}) => showDialog<void>(
  context: context,
  builder: (context) => _SheetSetDialog(doc: doc, onEdit: onEdit),
);

/// One editable row: its own controllers and focus nodes, and an id that
/// stays with it when a row above is removed.
final class _Draft {
  _Draft(this.id, List<String> texts, VoidCallback onBlur)
    : controllers = [for (final t in texts) TextEditingController(text: t)],
      focus = [for (final _ in texts) FocusNode()] {
    for (final f in focus) {
      f.addListener(() {
        if (!f.hasFocus) onBlur();
      });
    }
  }

  final int id;
  final List<TextEditingController> controllers;
  final List<FocusNode> focus;

  void dispose() {
    for (final c in controllers) {
      c.dispose();
    }
    for (final f in focus) {
      f.dispose();
    }
  }
}

class _SheetSetDialog extends StatefulWidget {
  const _SheetSetDialog({required this.doc, required this.onEdit});

  final RackDocument doc;
  final SheetSetEdit onEdit;

  @override
  State<_SheetSetDialog> createState() => _SheetSetDialogState();
}

class _SheetSetDialogState extends State<_SheetSetDialog> {
  ProjectInfo get _info => widget.doc.info;

  var _nextId = 0;
  final _abbreviations = <_Draft>[];
  final _notes = <_Draft>[];

  @override
  void initState() {
    super.initState();
    _loadDrafts();
  }

  @override
  void dispose() {
    _clearDrafts();
    _disposeInfo();
    super.dispose();
  }

  void _clearDrafts() {
    for (final d in [..._abbreviations, ..._notes]) {
      d.dispose();
    }
    _abbreviations.clear();
    _notes.clear();
  }

  /// Rows from what the document prints: its own lists, or the seed.
  void _loadDrafts() {
    for (final r in _info.legendAbbreviations ?? kLegendAbbreviations) {
      _abbreviations.add(
        _Draft(_nextId++, [r.abbreviation, r.meaning], _commit),
      );
    }
    for (final n in _info.legendNotes ?? kLegendGeneralNotes) {
      _notes.add(_Draft(_nextId++, [n], _commit));
    }
  }

  List<LegendAbbreviation> get _draftAbbreviations => [
    for (final d in _abbreviations)
      LegendAbbreviation(d.controllers[0].text, d.controllers[1].text),
  ].where((r) => !r.isBlank).toList();

  List<String> get _draftNotes => [
    for (final d in _notes) d.controllers[0].text,
  ].where((n) => n.trim().isNotEmpty).toList();

  /// Sends one command if the rows differ from what the document prints,
  /// and nothing otherwise. A list that did not change keeps whatever the
  /// document held, null included, so editing a note does not freeze the
  /// seeded abbreviations.
  void _commit() {
    if (!mounted) return;
    final abbreviations = _draftAbbreviations;
    final notes = _draftNotes;
    final abbreviationsChanged = !listEquals(
      abbreviations,
      _info.legendAbbreviations ?? kLegendAbbreviations,
    );
    final notesChanged = !listEquals(
      notes,
      _info.legendNotes ?? kLegendGeneralNotes,
    );
    if (!abbreviationsChanged && !notesChanged) return;
    widget.onEdit([
      SetLegendNotesCommand.to(
        _info,
        abbreviations: abbreviationsChanged
            ? abbreviations
            : _info.legendAbbreviations,
        notes: notesChanged ? notes : _info.legendNotes,
      ),
    ]);
    setState(() {});
  }

  void _addAbbreviation() {
    final draft = _Draft(_nextId++, ['', ''], _commit);
    setState(() => _abbreviations.add(draft));
    draft.focus[0].requestFocus();
  }

  void _addNote() {
    final draft = _Draft(_nextId++, [''], _commit);
    setState(() => _notes.add(draft));
    draft.focus[0].requestFocus();
  }

  void _remove(List<_Draft> list, _Draft draft) {
    setState(() => list.remove(draft));
    _commit();
    // AFTER the commit and after this frame, since its focus listener may
    // still fire as the field leaves the tree.
    WidgetsBinding.instance.addPostFrameCallback((_) => draft.dispose());
  }

  void _restoreDefaults() {
    widget.onEdit([
      SetLegendNotesCommand.to(_info, abbreviations: null, notes: null),
    ]);
    final old = [..._abbreviations, ..._notes];
    setState(() {
      _abbreviations.clear();
      _notes.clear();
      _loadDrafts();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final d in old) {
        d.dispose();
      }
    });
  }

  bool get _isSeeded =>
      _info.legendAbbreviations == null && _info.legendNotes == null;

  // ── the title block and the cover (#312, DR-210) ─────────────────────

  late final Map<ProjectInfoField, TextEditingController> _infoText = {
    for (final f in ProjectInfoFields.all)
      f: TextEditingController(text: f.get(_info) ?? ''),
  };

  late final Map<ProjectInfoField, FocusNode> _infoFocus = {
    for (final f in ProjectInfoFields.all)
      f: FocusNode()
        ..addListener(() {
          if (!(_infoFocus[f]?.hasFocus ?? true)) _commitInfo();
        }),
  };

  /// The refusal on screen, for the one field that may not be blank.
  String? _nameError;

  void _disposeInfo() {
    for (final c in _infoText.values) {
      c.dispose();
    }
    for (final f in _infoFocus.values) {
      f.dispose();
    }
  }

  /// One command per field whose text differs from what the document
  /// holds, compared as the command will store it (trimmed, blank as
  /// null), so clicking in and out of a field sends nothing.
  ///
  /// **A BLANK PROJECT NAME IS REFUSED HERE, WITH A REASON** (§11.209.4):
  /// the field gets its stored name back and says why.
  void _commitInfo() {
    if (!mounted) return;
    final commands = <Command<RackDocument>>[];
    for (final MapEntry(key: field, value: text) in _infoText.entries) {
      final cmd = SetProjectInfoCommand.to(_info, field, text.text);
      if (cmd.stored == field.get(_info)) continue;
      if (field.required && cmd.stored == null) {
        text.text = field.get(_info) ?? '';
        setState(() => _nameError = kProjectNameRequired);
        continue;
      }
      commands.add(cmd);
    }
    if (commands.isEmpty) return;
    widget.onEdit(commands);
    setState(() => _nameError = null);
  }

  Widget _infoRow(ProjectInfoField f) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(f.label),
          ),
        ),
        Expanded(
          child: TextField(
            key: projectInfoFieldKey(f),
            controller: _infoText[f],
            focusNode: _infoFocus[f],
            // THE SCOPE WRAPS ON SCREEN AND ENTER STILL SAVES, as a legend
            // note does: it is one paragraph on the cover.
            maxLines: f.multiline ? null : 1,
            minLines: f.multiline ? 3 : 1,
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _commitInfo(),
            onTapOutside: (_) => _commitInfo(),
            decoration: InputDecoration(
              isDense: true,
              errorText: f.required ? _nameError : null,
              errorMaxLines: 2,
            ),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final caption = theme.textTheme.bodySmall;
    final tagPrefixes =
        widget.doc.registries.signalDomains.values
            .map((d) => d.tagPrefix)
            .toSet()
            .toList()
          ..sort();
    return PopScope<void>(
      // A FIELD STILL BEING TYPED IN IS SAVED ON CLOSE, by `Esc` or by the
      // button: neither moves focus first, so without this the last edit
      // would vanish with the dialog.
      onPopInvokedWithResult: (didPop, _) {
        _commitInfo();
        _commit();
      },
      child: AlertDialog(
        title: const Text('Sheet set'),
        content: SizedBox(
          width: 640,
          height: 600,
          child: ListView(
            key: kSheetSetListKey,
            children: [
              Text(
                'What the drawing set prints on its front pages. These live '
                'in the project file, and every change can be undone.',
                style: caption,
              ),
              const SizedBox(height: 16),
              // ── the title block, grouped as printed (§11.209.2) ──────
              Text('Title block', style: theme.textTheme.titleSmall),
              Text(
                'Printed on every sheet. Approved by prints on the cover.',
                style: caption,
              ),
              for (final (group, fields) in ProjectInfoFields.groups) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 4),
                  child: Text(group, style: theme.textTheme.labelLarge),
                ),
                for (final f in fields) _infoRow(f),
              ],
              const Divider(height: 32),
              // ── the cover (T0.00) ──────────────────────────────────────
              Text('Cover (T0.00)', style: theme.textTheme.titleSmall),
              Text(
                'One paragraph saying what the job is. Leave it empty and '
                'the cover prints no scope at all.',
                style: caption,
              ),
              const SizedBox(height: 8),
              _infoRow(ProjectInfoFields.scopeNarrative),
              const Divider(height: 32),
              Text(
                'Legend (T0.01): abbreviations',
                style: theme.textTheme.titleSmall,
              ),
              Text(
                _info.legendAbbreviations == null
                    ? 'The standard list. Changing any row makes it this '
                          "project's own."
                    : "This project's own list.",
                style: caption,
              ),
              const SizedBox(height: 8),
              for (final (i, d) in _abbreviations.indexed)
                _abbreviationRow(i, d),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: kAddAbbreviationKey,
                  onPressed: _addAbbreviation,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add abbreviation'),
                ),
              ),
              Text(
                'The legend also lists the signal tag prefixes '
                "(${tagPrefixes.join(', ')}), from the project's signal "
                'types. Those are not edited here.',
                style: caption,
              ),
              const Divider(height: 32),
              Text(
                'Legend (T0.01): general notes',
                style: theme.textTheme.titleSmall,
              ),
              Text(
                _info.legendNotes == null
                    ? 'The standard notes. Changing any note makes them this '
                          "project's own."
                    : "This project's own notes.",
                style: caption,
              ),
              const SizedBox(height: 8),
              for (final (i, d) in _notes.indexed) _noteRow(i, d),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: kAddNoteKey,
                  onPressed: _addNote,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add note'),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            key: kRestoreLegendDefaultsKey,
            // DISABLED WHILE SEEDED: there is nothing to restore, and a
            // live button that does nothing teaches a person the dialog
            // lies.
            onPressed: _isSeeded ? null : _restoreDefaults,
            child: const Text('Restore defaults'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _abbreviationRow(int row, _Draft d) => Padding(
    key: ValueKey(d.id),
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      children: [
        SizedBox(
          width: 120,
          child: TextField(
            key: abbreviationFieldKey(row),
            controller: d.controllers[0],
            focusNode: d.focus[0],
            onSubmitted: (_) => _commit(),
            onTapOutside: (_) => _commit(),
            decoration: const InputDecoration(
              isDense: true,
              hintText: 'Abbreviation',
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            key: meaningFieldKey(row),
            controller: d.controllers[1],
            focusNode: d.focus[1],
            onSubmitted: (_) => _commit(),
            onTapOutside: (_) => _commit(),
            decoration: const InputDecoration(
              isDense: true,
              hintText: 'Meaning',
            ),
          ),
        ),
        IconButton(
          key: removeAbbreviationKey(row),
          tooltip: 'Remove',
          icon: const Icon(Icons.close, size: 18),
          onPressed: () => _remove(_abbreviations, d),
        ),
      ],
    ),
  );

  Widget _noteRow(int row, _Draft d) => Padding(
    key: ValueKey(d.id),
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // UNNUMBERED, because the legend prints them unnumbered: a number
        // here would promise the sheet something it does not print.
        Expanded(
          child: TextField(
            key: noteFieldKey(row),
            controller: d.controllers[0],
            focusNode: d.focus[0],
            // WRAPS ON SCREEN, BUT ENTER STILL SAVES: a note is one
            // paragraph on the sheet, and the legend wraps it there.
            maxLines: null,
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _commit(),
            onTapOutside: (_) => _commit(),
            decoration: const InputDecoration(
              isDense: true,
              hintText: 'Note',
            ),
          ),
        ),
        IconButton(
          key: removeNoteKey(row),
          tooltip: 'Remove',
          icon: const Icon(Icons.close, size: 18),
          onPressed: () => _remove(_notes, d),
        ),
      ],
    ),
  );
}
