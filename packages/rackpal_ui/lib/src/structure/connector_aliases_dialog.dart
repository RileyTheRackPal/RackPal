// Teaching a connector the word your crew uses (`#248`, RJ-012, CR-058).
//
// ═══════════════════════════════════════════════════════════════════════
// A VOCABULARY EDITOR, NOT A REGISTRY EDITOR
// ═══════════════════════════════════════════════════════════════════════
// RJ-012 ships connector ALIASES and rejects a connector-type editor in
// the same breath: connector types are catalog-updated, because a
// hand-rolled one carries footprints and pitches that the rear-panel
// layout and the schedule both read. So this surface can add a SPELLING
// and can never add, rename or remove a connector.
//
// Beside the media-type editor rather than in the builder, because
// `resolveConnectorToken` serves both: the Quick Add DSL and the TSV paste
// path in the builder, and drop lines in Structure. One place to teach the
// project a word, whichever surface you were typing it into.
//
// ── THE REFUSAL IS TESTED, NOT ONLY WRITTEN ────────────────────────────
// `refused_surfaces_test.dart` fails if a command that creates a connector
// type, a signal family, a colour scheme or a validation rule ever
// appears. This file's restraint is enforced somewhere a later chapter
// cannot miss it.
import 'package:flutter/material.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/src/theme/console_theme.dart';

/// What the dialog hands back: commands for the session's undo stack.
typedef ConnectorAliasEdit =
    void Function(List<Command<RackDocument>> commands);

/// The label on the control that opens this.
const String kConnectorAliasesLabel = 'Connector words...';

/// Opens the alias editor over [doc]'s connector registry.
Future<void> showConnectorAliasesDialog(
  BuildContext context, {
  required RackDocument doc,
  required ConnectorAliasEdit onEdit,
}) => showDialog<void>(
  context: context,
  builder: (context) => _AliasesDialog(doc: doc, onEdit: onEdit),
);

class _AliasesDialog extends StatefulWidget {
  const _AliasesDialog({required this.doc, required this.onEdit});

  final RackDocument doc;
  final ConnectorAliasEdit onEdit;

  @override
  State<_AliasesDialog> createState() => _AliasesDialogState();
}

class _AliasesDialogState extends State<_AliasesDialog> {
  final _search = TextEditingController();
  ConnectorTypeId? _open;
  final _word = TextEditingController();
  String? _refusal;

  @override
  void dispose() {
    _search.dispose();
    _word.dispose();
    super.dispose();
  }

  Registries get _reg => widget.doc.registries;

  void _add(ConnectorTypeDef def) {
    final word = _word.text.trim();
    if (word.isEmpty) return;

    // ═════════════════════════════════════════════════════════════════
    // REFUSED BEFORE IT IS STORED, AND THE REFUSAL NAMES THE OWNER
    // ═════════════════════════════════════════════════════════════════
    // `resolveConnectorToken` returns the FIRST match in map order, so
    // two connectors answering to one word resolve unpredictably: the
    // same typed token would mean different things in two documents with
    // the same registries. `connectorAliasConflict` is in core beside the
    // command, and it returns the OWNER rather than a bool so this can
    // say which connector already has the word. A rejection a person can
    // act on beats one they can only obey.
    final clash = connectorAliasConflict(_reg, def.id, word);
    if (clash != null) {
      setState(
        () => _refusal =
            '"$word" already means ${clash.displayName} '
            '(${clash.id.v}). One word, one connector.',
      );
      return;
    }
    if (def.aliases.any(
      (a) => normaliseMediaToken(a) == normaliseMediaToken(word),
    )) {
      setState(() => _refusal = '${def.displayName} already knows "$word".');
      return;
    }

    widget.onEdit([
      SetConnectorAliasesCommand(
        id: def.id,
        from: def.aliases,
        to: [...def.aliases, word],
      ),
    ]);
    _word.clear();
    setState(() => _refusal = null);
  }

  void _remove(ConnectorTypeDef def, String alias) => widget.onEdit([
    SetConnectorAliasesCommand(
      id: def.id,
      from: def.aliases,
      to: [
        for (final a in def.aliases)
          if (a != alias) a,
      ],
    ),
  ]);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final want = normaliseMediaToken(_search.text);
    final defs =
        _reg.connectorTypes.values.where((d) {
            if (want.isEmpty) return true;
            if (normaliseMediaToken(d.displayName).contains(want)) return true;
            if (normaliseMediaToken(d.id.v).contains(want)) return true;
            return d.aliases.any(
              (a) => normaliseMediaToken(a).contains(want),
            );
          }).toList()
          // TOTAL ORDER: `List.sort` is not stable, and two connectors
          // sharing a display name would otherwise swap between builds.
          ..sort((a, b) {
            final c = a.displayName.toLowerCase().compareTo(
              b.displayName.toLowerCase(),
            );
            return c != 0 ? c : a.id.v.compareTo(b.id.v);
          });

    return AlertDialog(
      title: const Text('Connector words'),
      content: SizedBox(
        width: 640,
        height: 460,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Teach the project the words your crew uses. Quick Add, '
              'pasted columns and drop lines all accept them. Connector '
              'types themselves come from the catalog and are not edited '
              'here.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Find a connector',
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: defs.length,
                itemBuilder: (context, i) {
                  final def = defs[i];
                  final open = def.id == _open;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ListTile(
                        dense: true,
                        selected: open,
                        onTap: () => setState(() {
                          _open = open ? null : def.id;
                          _word.clear();
                          _refusal = null;
                        }),
                        title: Text(def.displayName),
                        subtitle: Text(
                          def.aliases.isEmpty
                              ? '${def.id.v}  |  no words yet'
                              : '${def.id.v}  |  ${def.aliases.join(', ')}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                      if (open) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          child: Wrap(
                            spacing: 6,
                            children: [
                              for (final a in def.aliases)
                                InputChip(
                                  label: Text(a),
                                  onDeleted: () => _remove(def, a),
                                ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _word,
                                  onSubmitted: (_) => _add(def),
                                  decoration: InputDecoration(
                                    labelText: 'Add a word',
                                    isDense: true,
                                    errorText: _refusal,
                                    errorMaxLines: 3,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              FilledButton(
                                onPressed: () => _add(def),
                                child: const Text('Add'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
            if (defs.isEmpty)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'No connector matches "${_search.text}".',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: kConsoleEmphasis,
                  ),
                ),
              ),
          ],
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
