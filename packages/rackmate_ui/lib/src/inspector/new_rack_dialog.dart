// packages/rackmate_ui/lib/src/inspector/new_rack_dialog.dart
//
// docs/04-rack-editor.md §9's New-rack dialog: "**New rack** is three fields
// — Name, Preset, Height — and `Enter` commits."
//
// WHY IT EXISTS NOW. `apps/rackmate/lib/src/session/blank_document.dart`'s
// header has said since it was written that this dialog "DOES NOT EXIST YET"
// and that a blank project therefore has to be HANDED a 42U rack, and
// `docs/12-milestone-board.md` §3.2 MARKED M1's exit clause 2 — "a user …
// creates a 42U rack" — NOT BUILT for exactly that reason: a criterion that
// says a user *creates* a rack is not met by giving them one. That row is
// DEMONSTRATED as of this file's arrival, on the test named there; past
// tense on purpose, because a header asserting in the present that the
// board still says NOT BUILT would reverse the moment it stopped.
//
// THE THREE FIELDS AND NOTHING ELSE. §9 removes the `Location` combobox
// explicitly (AC-048: "an empty required-looking dropdown on field two of
// the very first dialog was the first cliff in the corpus"), and everything
// else on `Rack` — RU numbering, mirroring, doors, 0U channels — keeps its
// own constructor default rather than being asked about or invented (G4).
// All of it is editable afterwards from the rack inspector.
//
// THE DEFAULT ROW IS WHAT `Ctrl+N` ALREADY SEEDS, which is the promise
// blank_document.dart's header made: "When the New-rack dialog lands, this
// becomes its default row and the seeding moves there." So the dialog opens
// on **no preset** at **42U** — a plain `Rack` at
// [NewRackDialog.defaultHeightU] — and produces the same shape of rack the
// blank project has always contained. A test in `apps/rackmate` pins the
// two constants together so they cannot drift apart.
//
// PRESET AND HEIGHT ARE TWO FIELDS, so they can disagree, and the dialog
// lets them. Picking a preset REWRITES the height box to that archetype's
// height (that is what picking "Wall box 6U / 12 in" means), but typing a
// different number afterwards wins — §9 lists them separately, and a Height
// field that silently snapped back to the preset would be a control that
// does nothing. The rack then reads "Custom" in the inspector's preset
// dropdown, because `matchingPresetId` compares `heightU` too; it never
// claims to be an archetype it is not.
//
// THIS WIDGET DECIDES; IT DOES NOT MUTATE — the same split
// `shrink_rack_dialog.dart` uses. It pops a [NewRackRequest]; [showNewRack]
// is the ONE place that turns one into a command and runs it, shared by the
// rack canvas (`Ctrl+Alt+N`, docs/04 §8) and by the app shell's rack-less
// panel, so "how a rack gets created" cannot drift into two answers.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:rackmate_core/rackmate_core.dart';

/// What the dialog pops: the three fields, unvalidated against the document
/// (that is [buildAddRackCommand]'s job).
@immutable
final class NewRackRequest {
  const NewRackRequest({
    required this.name,
    required this.heightU,
    this.preset,
  });

  final String name;
  final int heightU;

  /// Null means "no preset" — every archetype fact keeps `Rack`'s own
  /// default. NOT a preset whose values happen to match the defaults: the
  /// document must not record an archetype the user never chose.
  final RackPreset? preset;
}

/// The outcome of [showNewRack], stated rather than collapsed into a
/// nullable, because "the user cancelled" and "the document refused" want
/// different responses from the caller and docs/04 §3.4 forbids the second
/// one being silent.
sealed class NewRackOutcome {
  const NewRackOutcome();
}

/// The rack exists: [command] has already been run through the controller.
final class NewRackCreated extends NewRackOutcome {
  const NewRackCreated(this.command);
  final AddRackCommand command;
}

/// Cancel, `Esc`, or a barrier tap. No command, no mutation, nothing to say.
final class NewRackCancelled extends NewRackOutcome {
  const NewRackCancelled();
}

/// [buildAddRackCommand] declined. Unreachable through the dialog's own
/// validation today (it disables Create for both refusable inputs), and
/// handled anyway rather than assumed impossible — the caller reports
/// [reason] on the status line.
final class NewRackRefused extends NewRackOutcome {
  const NewRackRefused(this.reason);
  final String reason;
}

/// Opens docs/04 §9's dialog and, on commit, runs the resulting
/// [AddRackCommand] through [controller] — the ONE rack-creation path in the
/// app (see the file header).
Future<NewRackOutcome> showNewRack({
  required BuildContext context,
  required DocumentController controller,
  required Map<String, RackPreset> presets,
}) async {
  final request = await showDialog<NewRackRequest>(
    context: context,
    builder: (_) => NewRackDialog(doc: controller.doc, presets: presets),
  );
  if (request == null || !context.mounted) return const NewRackCancelled();

  final result = buildAddRackCommand(
    doc: controller.doc,
    name: request.name,
    heightU: request.heightU,
    now: controller.clock.nowUtc(),
    actor: controller.actor,
    preset: request.preset,
  );
  return switch (result) {
    AddRackReady(:final command) => () {
      controller.run(command);
      return NewRackCreated(command);
    }(),
    AddRackRefused(:final reason) => NewRackRefused(reason),
  };
}

/// docs/04 §9's three-field dialog. Pops a [NewRackRequest] on commit, or
/// null on Cancel/`Esc`.
class NewRackDialog extends StatefulWidget {
  const NewRackDialog({
    required this.doc,
    required this.presets,
    super.key,
  });

  /// Read-only here: the dialog uses it for the name it proposes and for
  /// the designator it PREVIEWS. The designator that is actually stored is
  /// allocated by `buildAddRackCommand` at commit time against the document
  /// as it stands then (docs/04 §7, CR-048).
  final RackDocument doc;

  /// `buildRackPresets()`'s result, injected rather than built here for the
  /// same reason `RackInspectorPanel` takes it injected: a test wants to
  /// pump this against two presets, not eleven.
  final Map<String, RackPreset> presets;

  /// The height the dialog opens on — 42U, matching what a blank project's
  /// seeded rack has always been (see the file header).
  static const int defaultHeightU = 42;

  @override
  State<NewRackDialog> createState() => _NewRackDialogState();
}

class _NewRackDialogState extends State<NewRackDialog> {
  late final TextEditingController _name = TextEditingController(
    text: 'Rack ${widget.doc.racks.length + 1}',
  );
  late final TextEditingController _height = TextEditingController(
    text: '${NewRackDialog.defaultHeightU}',
  );
  final FocusNode _nameFocus = FocusNode(debugLabel: 'newRackName');
  String? _presetId;

  @override
  void initState() {
    super.initState();
    // Both boxes drive the Create button's enabled state, so the button
    // cannot advertise a commit the fields would refuse.
    _name.addListener(_onFieldChanged);
    _height.addListener(_onFieldChanged);
  }

  @override
  void dispose() {
    _name
      ..removeListener(_onFieldChanged)
      ..dispose();
    _height
      ..removeListener(_onFieldChanged)
      ..dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  void _onFieldChanged() => setState(() {});

  int? get _parsedHeight => int.tryParse(_height.text.trim());

  /// Exactly the two conditions `buildAddRackCommand` refuses on, asked here
  /// so the button is disabled rather than pressable-and-refused. Every
  /// OTHER way a creation could fail still reaches the refusal path.
  bool get _canCommit {
    final h = _parsedHeight;
    return _name.text.trim().isNotEmpty &&
        h != null &&
        h >= 1 &&
        h <= kMaxRackHeightU;
  }

  /// What the height box says is wrong, or null. Shown as the field's own
  /// error text — a disabled Create with no stated reason is the silent
  /// refusal §3.4 forbids, wearing a different hat.
  String? get _heightError {
    final text = _height.text.trim();
    if (text.isEmpty) return 'Required';
    final h = int.tryParse(text);
    if (h == null) return 'Whole numbers only';
    if (h < 1 || h > kMaxRackHeightU) return '1–${kMaxRackHeightU}U (CR-038)';
    return null;
  }

  void _pickPreset(String? id) {
    setState(() {
      _presetId = id;
      final preset = id == null ? null : widget.presets[id];
      // Picking an archetype means picking its height. Typing over it
      // afterwards still wins — see the file header.
      if (preset != null) _height.text = '${preset.heightU}';
    });
  }

  void _commit() {
    if (!_canCommit) return;
    Navigator.of(context).pop(
      NewRackRequest(
        name: _name.text.trim(),
        heightU: _parsedHeight!,
        preset: _presetId == null ? null : widget.presets[_presetId],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // A PREVIEW, and labelled as one. The stored designator is allocated at
    // commit time, so showing it here as a fact would be a promise this
    // dialog cannot keep if the document changes underneath it.
    final proposedDesignator = allocateRackDesignator(doc: widget.doc);

    return AlertDialog(
      title: Text('New rack', style: theme.textTheme.titleMedium),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _name,
              focusNode: _nameFocus,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Name',
                isDense: true,
                border: const OutlineInputBorder(),
                errorText: _name.text.trim().isEmpty ? 'Required' : null,
              ),
              onSubmitted: (_) => _commit(),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: _presetId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Preset',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              items: [
                // "No preset" is a real choice, not an empty state: it is
                // what the blank project's own rack is, and it is what the
                // dialog opens on.
                const DropdownMenuItem<String?>(
                  child: Text('No preset (custom)'),
                ),
                for (final entry in widget.presets.entries)
                  DropdownMenuItem<String?>(
                    value: entry.key,
                    child: Text(
                      entry.value.displayName,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: _pickPreset,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _height,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'Height (U)',
                isDense: true,
                border: const OutlineInputBorder(),
                errorText: _heightError,
              ),
              onSubmitted: (_) => _commit(),
            ),
            const SizedBox(height: 12),
            Text(
              'Will be created as $proposedDesignator. '
              'Location, RU numbering and rear mirroring are set afterwards '
              'from the rack inspector (docs/04 §9, AC-048).',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _canCommit ? _commit : null,
          child: const Text('Create'),
        ),
      ],
    );
  }
}
