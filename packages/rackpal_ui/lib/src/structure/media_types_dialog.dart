// The media-type editor (`#247`, RJ-012, DR-107 §11.106.1).
//
// ═══════════════════════════════════════════════════════════════════════
// IT OPENS FROM THE PICKER BECAUSE THAT IS WHERE THE PROBLEM IS SEEN
// ═══════════════════════════════════════════════════════════════════════
// RJ-012 ships this *"because users hit it"*, and what they hit is
// `csv_import_apply.dart`: an unmatched value in a Structure sheet CREATES
// a media type rather than rejecting the row (RJ-009), which is correct.
// The consequence is that a typo in row 40 becomes `media.cat_6e_riser`
// sitting one line below `media.cat6e` in the very dropdown they are using
// now, and the schedule prints two rows for one cable.
//
// So the entry point is `Manage media types...` at the foot of that
// dropdown, not a tab somewhere else: a person notices this while looking
// at the list, and the fix belongs where the noticing happens.
//
// ── WHAT THIS FILE DOES NOT DO ─────────────────────────────────────────
// RJ-012 rules a general registry authoring UI OUT of v1, and AC-011
// withdraws user-authored validation rules from every document: rules are
// Dart functions keyed by `ruleId`, and a UI for them would make the app
// an interpreter for user input. This edits media types. It is not the
// thin end of a registry editor and must not grow into one.
import 'package:flutter/material.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/src/theme/console_theme.dart';

/// What the dialog hands back: commands for the session's undo stack.
typedef MediaTypeEdit = void Function(List<Command<RackDocument>> commands);

/// The label on the picker row that opens this.
const String kManageMediaTypesLabel = 'Manage media types...';

/// Opens the editor over [doc]'s media registry.
Future<void> showMediaTypesDialog(
  BuildContext context, {
  required RackDocument doc,
  required MediaTypeEdit onEdit,
}) => showDialog<void>(
  context: context,
  builder: (context) => _MediaTypesDialog(doc: doc, onEdit: onEdit),
);

class _MediaTypesDialog extends StatefulWidget {
  const _MediaTypesDialog({required this.doc, required this.onEdit});

  final RackDocument doc;
  final MediaTypeEdit onEdit;

  @override
  State<_MediaTypesDialog> createState() => _MediaTypesDialogState();
}

class _MediaTypesDialogState extends State<_MediaTypesDialog> {
  MediaTypeId? _selected;

  Map<MediaTypeId, MediaTypeDef> get _types => widget.doc.registries.mediaTypes;

  /// How many places in the document name [id].
  ///
  /// ═══════════════════════════════════════════════════════════════════
  /// COUNTED FOR THE PERSON, NOT FOR THE COMMAND
  /// ═══════════════════════════════════════════════════════════════════
  /// `MergeMediaTypesCommand` finds its own references and does not need
  /// this. It exists so a merge can SAY what it is about to repoint before
  /// it does: folding one cable type into another rewrites real cable
  /// runs, and a confirmation that cannot name a number is asking for a
  /// signature on a blank page.
  ///
  /// It deliberately mirrors the command's five fields rather than
  /// serialising the document, because this runs on every build of a
  /// dialog and the command's own test is what proves the five are five.
  int _referenceCount(MediaTypeId id) {
    final doc = widget.doc;
    var n = 0;
    for (final link in doc.links.values) {
      if (link.media == id) n++;
    }
    for (final p in doc.pathways.values) {
      if (p.pathwayMedia == id) n++;
    }
    for (final t in doc.registries.outletTemplates.values) {
      for (final d in t.drops) {
        if (d.media == id) n++;
      }
    }
    for (final s in doc.registries.cableSpecs.values) {
      if (s.mediaTypeId == id) n++;
    }
    if (doc.settings.defaultNetworkMedia == id) n++;
    return n;
  }

  Future<void> _rename(MediaTypeDef def) async {
    final next = await showDialog<MediaTypeDef>(
      context: context,
      builder: (context) => _EditMediaTypeSheet(def: def),
    );
    if (next == null) return;
    widget.onEdit([EditMediaTypeCommand(from: def, to: next)]);
    setState(() {});
  }

  Future<void> _merge(MediaTypeDef loser) async {
    final winner = await showDialog<MediaTypeId>(
      context: context,
      builder: (context) => _MergeTargetSheet(
        loser: loser,
        candidates: [
          for (final d in _types.values)
            if (d.id != loser.id) d,
        ],
        countOf: _referenceCount,
      ),
    );
    if (winner == null) return;
    widget.onEdit([
      MergeMediaTypesCommand(winner: winner, loser: loser.id),
    ]);
    setState(() => _selected = null);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final defs = _types.values.toList()
      // TOTAL ORDER. `List.sort` is not stable in Dart, so the display
      // name alone would let two types with one spelling swap places
      // between builds; the id breaks it and is unique by construction.
      ..sort((a, b) {
        final c = a.displayName.toLowerCase().compareTo(
          b.displayName.toLowerCase(),
        );
        return c != 0 ? c : a.id.v.compareTo(b.id.v);
      });

    return AlertDialog(
      title: const Text('Media types'),
      content: SizedBox(
        width: 620,
        height: 420,
        child: defs.isEmpty
            ? Center(
                child: Text(
                  'This project has no media types yet. They arrive with a '
                  'Structure CSV import, or you can add one.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
              )
            : ListView.builder(
                itemCount: defs.length,
                itemBuilder: (context, i) {
                  final def = defs[i];
                  final uses = _referenceCount(def.id);
                  return ListTile(
                    dense: true,
                    selected: def.id == _selected,
                    onTap: () => setState(() => _selected = def.id),
                    title: Text(def.displayName),
                    subtitle: Text(
                      // THE ID IS SHOWN, and that is deliberate. It is
                      // what a person sees when they diff two `.rppj`
                      // files, and it is the only thing that distinguishes
                      // two types a typo made near-identical.
                      _subtitleFor(def, uses),
                      style: theme.textTheme.bodySmall,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          onPressed: () => _rename(def),
                          child: const Text('Edit'),
                        ),
                        TextButton(
                          // A MERGE NEEDS SOMETHING TO MERGE INTO.
                          onPressed: defs.length < 2 ? null : () => _merge(def),
                          child: const Text('Merge into...'),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

/// `media.cat6e  |  3 uses  |  C6`.
///
/// THE ID LEADS, and that is deliberate: it is what a person sees when
/// they diff two `.rppj` files, and with two types a typo made
/// near-identical it is the only thing that tells them apart.
String _subtitleFor(MediaTypeDef def, int uses) {
  final used = uses == 0 ? 'not used' : '$uses use${uses == 1 ? '' : 's'}';
  final tag = def.shortTag;
  return '${def.id.v}  |  $used${tag == null ? '' : '  |  $tag'}';
}

/// Edits one type's label. Never its id (DR-107; see
/// [EditMediaTypeCommand]).
class _EditMediaTypeSheet extends StatefulWidget {
  const _EditMediaTypeSheet({required this.def});

  final MediaTypeDef def;

  @override
  State<_EditMediaTypeSheet> createState() => _EditMediaTypeSheetState();
}

class _EditMediaTypeSheetState extends State<_EditMediaTypeSheet> {
  late final _name = TextEditingController(text: widget.def.displayName);
  late final _tag = TextEditingController(text: widget.def.shortTag ?? '');

  @override
  void dispose() {
    _name.dispose();
    _tag.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Edit media type'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _name,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _tag,
          decoration: const InputDecoration(
            labelText: 'Trade tag',
            // G4/CR-114: empty means UNKNOWN, and the helper says so
            // rather than letting a person think they have cleared it to
            // a known-blank.
            helperText: 'C6, RG6, 16/4. Leave empty if unknown.',
          ),
        ),
        const SizedBox(height: 16),
        Text(
          // THE ID IS SHOWN AND CANNOT BE EDITED, with the reason, because
          // a control that silently refuses is worse than one that
          // explains: `${widget.def.id.v}` is written into every cable run
          // that names this type.
          'Id: ${widget.def.id.v}\nFixed at creation, because it is written '
          'into every cable run that uses this type. To combine two types, '
          'use Merge.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          final name = _name.text.trim();
          if (name.isEmpty) return;
          final tag = _tag.text.trim();
          Navigator.of(context).pop(
            MediaTypeDef(
              id: widget.def.id,
              displayName: name,
              shortTag: tag.isEmpty ? null : tag,
              aliases: widget.def.aliases,
              maxRunLengthPassive: widget.def.maxRunLengthPassive,
              maxRunLengthActive: widget.def.maxRunLengthActive,
              jacketOptions: widget.def.jacketOptions,
              isPathwayOnly: widget.def.isPathwayOnly,
            ),
          );
        },
        child: const Text('Save'),
      ),
    ],
  );
}

/// Chooses what [loser] folds into, and says what that will repoint.
class _MergeTargetSheet extends StatefulWidget {
  const _MergeTargetSheet({
    required this.loser,
    required this.candidates,
    required this.countOf,
  });

  final MediaTypeDef loser;
  final List<MediaTypeDef> candidates;
  final int Function(MediaTypeId) countOf;

  @override
  State<_MergeTargetSheet> createState() => _MergeTargetSheetState();
}

class _MergeTargetSheetState extends State<_MergeTargetSheet> {
  MediaTypeId? _winner;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final moving = widget.countOf(widget.loser.id);
    return AlertDialog(
      title: Text('Merge "${widget.loser.displayName}" into'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  // A SELECTABLE TILE RATHER THAN A `RadioListTile`.
                  // `Radio.groupValue`/`onChanged` are deprecated in
                  // favour of a `RadioGroup` ancestor, and a list whose
                  // only job is "pick one of these" does not need either:
                  // the check mark says which, and the tap target is the
                  // whole row.
                  for (final d in widget.candidates)
                    ListTile(
                      dense: true,
                      selected: d.id == _winner,
                      leading: Icon(
                        d.id == _winner
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        size: 18,
                      ),
                      onTap: () => setState(() => _winner = d.id),
                      title: Text(d.displayName),
                      subtitle: Text(d.id.v, style: theme.textTheme.bodySmall),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              // NAMED BEFORE IT HAPPENS. A merge rewrites real cable runs,
              // and a confirmation that cannot say how many is asking for
              // a signature on a blank page. Undoable, and it says that
              // too, because the number is alarming on purpose.
              moving == 0
                  ? 'Nothing in this project uses '
                        '"${widget.loser.displayName}", so only the type '
                        'itself is removed.'
                  : 'This repoints $moving reference'
                        '${moving == 1 ? '' : 's'} to the type you pick, '
                        'then removes "${widget.loser.displayName}". Its '
                        'spellings move across, so re-importing the sheet '
                        'that created it will resolve rather than make it '
                        'again. One Ctrl+Z undoes all of it.',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: moving == 0 ? null : kConsoleEmphasis,
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
          onPressed: _winner == null
              ? null
              : () => Navigator.of(context).pop(_winner),
          child: const Text('Merge'),
        ),
      ],
    );
  }
}
