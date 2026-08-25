// `Ctrl+G` `Group as set…`, docs/06 §4.6. M4-J2, board `#181` / `#224`,
// DR-086 §11.85.
//
// ═══════════════════════════════════════════════════════════════════════
// THE PREVIEW IS LIVE AND IT IS THE REASON THE KIND PICKER IS HERE
// ═══════════════════════════════════════════════════════════════════════
// Changing the kind changes which roles the selected rows get, and DR-086
// §11.85.3 rules that roles RUN OUT INTO BLANK rather than cycling. So a
// person grouping four rows sees the difference between a stereo pair
// (`L`, `R`, blank, blank) and a component set (`Y`, `Pb`, `Pr`, blank)
// before committing, in the same list `Renumber…`, `Find & replace`,
// `Change type…` and `Mirror bank…` already use. Fifth caller, one widget.
//
// ═══════════════════════════════════════════════════════════════════════
// `atomicConnect` IS HERE BECAUSE IT IS NOWHERE ELSE
// ═══════════════════════════════════════════════════════════════════════
// DR-011.2 made the flag load-bearing and `planAtomicConnect` reads it
// before any rule runs, because a set that has opted out is not
// model-illegal. It has had an editor on no surface in the product. It
// defaults ON, matching `PortSetDef`'s own default and all 17 seeded sets,
// and its subtitle says what turning it off costs rather than restating
// the field name.
import 'package:flutter/material.dart';
import 'package:rackmate_core/rackmate_core.dart';
import 'package:rackmate_ui/src/builder/port_impact_list.dart';

/// What `[Group]` returns.
typedef GroupAsSetChoice = ({
  String label,
  SetKind kind,
  bool atomicConnect,
});

/// Shows `Group as set…` and returns the choice, or null on cancel.
Future<GroupAsSetChoice?> showGroupAsSetDialog({
  required BuildContext context,
  required TemplateBody body,
  required Set<String> selectedKeys,
}) => showDialog<GroupAsSetChoice>(
  context: context,
  builder: (context) =>
      _GroupAsSetDialog(body: body, selectedKeys: selectedKeys),
);

class _GroupAsSetDialog extends StatefulWidget {
  const _GroupAsSetDialog({required this.body, required this.selectedKeys});

  final TemplateBody body;
  final Set<String> selectedKeys;

  @override
  State<_GroupAsSetDialog> createState() => _GroupAsSetDialogState();
}

class _GroupAsSetDialogState extends State<_GroupAsSetDialog> {
  final _label = TextEditingController();

  /// **NOTHING IS PRESELECTED AND THE FIRST KIND IS NOT A DEFAULT.** The
  /// kind decides the roles, and a stereo pair silently chosen for three
  /// component-video rows would write `L`, `R`, blank on `Y`, `Pb`, `Pr`
  /// hardware. `[Group]` stays off until a person picks.
  SetKind? _kind;

  bool _atomic = true;

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = _label.text.trim();
    final taken = label.isNotEmpty && portSetLabelIsTaken(widget.body, label);

    // PLANNED LIVE, AND THE IMPACT LIST IS THE PLAN'S OWN. The rows a
    // person approves are read off the commands that will run, which is
    // `port_impact.dart`'s rule: a preview that is a second implementation
    // of the write is a preview that can lie.
    final result = _kind == null
        ? null
        : buildGroupAsSet(
            body: widget.body,
            selectedKeys: widget.selectedKeys,
            // A PLACEHOLDER WHILE THE FIELD IS EMPTY, so the roles preview
            // before the name exists. `[Group]` is off until it does, so
            // this string can never reach the template.
            label: label.isEmpty ? '_' : label,
            kind: _kind!,
            atomicConnect: _atomic,
          );

    final ready = label.isNotEmpty && !taken && result != null;

    return AlertDialog(
      title: Text('Group ${widget.selectedKeys.length} ports as a set'),
      content: SizedBox(
        width: 520,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'A port set is the ELECTRICAL grouping: the members connect '
              'as one cable and carry the conductor roles. Banks are the '
              'presentation grouping and are a separate thing (CR-055).',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _label,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Name',
                hintText: 'Zone 1 speaker pair',
                errorText: taken
                    ? 'A port set with that name already exists.'
                    : null,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<SetKind>(
              initialValue: _kind,
              // MEASURED, NOT PRECAUTIONARY. Without it the longest row,
              // `Component video  ·  Y / Pb / Pr`, overflows the field by
              // 0.65 points and Flutter paints the striped bar over it: a
              // widget case caught it before anyone opened the dialog.
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Kind'),
              // THE VOCABULARY IS CORE'S. `setKindOptions` decides what is
              // offered and `portSetKindLabel` spells it, so this file
              // cannot become a second speller of either.
              items: [
                for (final kind in setKindOptions(null))
                  DropdownMenuItem<SetKind>(
                    value: kind,
                    child: Text(
                      '${portSetKindLabel(kind)}  ·  '
                      '${setRolesFor(kind).join(" / ")}',
                    ),
                  ),
              ],
              onChanged: (kind) => setState(() => _kind = kind),
            ),
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Connect as one cable'),
              subtitle: const Text(
                'On, one drag connects the whole set as a single cable. '
                'Off, each member is wired on its own.',
              ),
              value: _atomic,
              onChanged: (v) => setState(() => _atomic = v),
            ),
            const SizedBox(height: 8),
            if (result == null)
              Text(
                'Pick a kind to see which role each port will take.',
                style: theme.textTheme.bodySmall,
              )
            else ...[
              Text(
                portImpactSummary(result.impact),
                style: theme.textTheme.labelLarge,
              ),
              const SizedBox(height: 4),
              PortImpactList(rows: result.impact, maxHeight: 180),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: ready
              ? () => Navigator.of(context).pop((
                  label: label,
                  kind: _kind!,
                  atomicConnect: _atomic,
                ))
              : null,
          child: const Text('Group'),
        ),
      ],
    );
  }
}
