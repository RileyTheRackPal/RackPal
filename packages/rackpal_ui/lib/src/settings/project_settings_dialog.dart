// Project settings (`#805`, RJ-012, AC-054, CR-097).
//
// ═══════════════════════════════════════════════════════════════════════
// THE SURFACE THAT DID NOT EXIST, AND WHAT ITS ABSENCE COST
// ═══════════════════════════════════════════════════════════════════════
// `ProjectSettings` shipped at M0 with 22 fields and no editor anywhere:
// no file in `rackpal_ui` or `apps/rackpal` referenced
// `familyColorOverrides`, and no command wrote any setting at all. That
// made RJ-012 unmeetable as written, because its third v1 surface is
// literally *"a per-family colour override row in settings"*.
//
// ── EIGHTEEN ROWS AND ONE LIST ─────────────────────────────────────────
// The 18 scalar settings are rows over `ProjectSettingFields`, so the
// dialog cannot disagree with the field table about what exists or what a
// setting is called: the LABEL lives on the field, beside the accessors,
// and both the row and the undo entry read it from there.
//
// The colour overrides are a list rather than a row, because a colour per
// signal family is not a field. The other three maps are filed rather than
// built: `ruleOverrides` is a signed exception carrying a reason, an
// author and a time (AC-011), so its editor is a form; the jacket
// convention expresses three distinct states its own doc comment argues;
// and the diversity factors are a `Permille` per category.
//
// ── WHAT THIS IS NOT ───────────────────────────────────────────────────
// RJ-012 rejects a general registry authoring UI and AC-011 withdraws
// user-authored validation rules. This edits a document's own settings. It
// is not a registry editor, and `refused_surfaces_test.dart` fails if one
// ever appears.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/src/theme/console_theme.dart';
import 'package:rackpal_ui/src/validation/rule_severity_dialog.dart';

/// What the dialog hands back: commands for the session's undo stack.
typedef ProjectSettingEdit =
    void Function(List<Command<RackDocument>> commands);

/// The settings list itself, so a test can scroll the right one.
const Key kProjectSettingsListKey = Key('project-settings-list');

/// The label on the control that opens this.
const String kProjectSettingsLabel = 'Project settings...';

/// Opens the settings editor over [doc].
///
/// [clock] and [actor] are here for ONE section: a `RuleOverride` carries
/// a reason, an author and a date, all three persisted and all three
/// printed on `T0.02` (`#879`). Nothing else in this dialog signs
/// anything, which is why they arrived late rather than at `#805`.
Future<void> showProjectSettingsDialog(
  BuildContext context, {
  required RackDocument doc,
  required ProjectSettingEdit onEdit,
  required Clock clock,
  required String actor,
}) => showDialog<void>(
  context: context,
  builder: (context) => _SettingsDialog(
    doc: doc,
    onEdit: onEdit,
    clock: clock,
    actor: actor,
  ),
);

class _SettingsDialog extends StatefulWidget {
  const _SettingsDialog({
    required this.doc,
    required this.onEdit,
    required this.clock,
    required this.actor,
  });

  final RackDocument doc;
  final ProjectSettingEdit onEdit;
  final Clock clock;
  final String actor;

  @override
  State<_SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<_SettingsDialog> {
  ProjectSettings get _s => widget.doc.settings;

  void _set<T>(ProjectSettingField<T> field, T value) {
    final was = field.get(_s);
    if (was == value) return;
    widget.onEdit([
      SetProjectSettingCommand<T>(field: field, from: was, to: value),
    ]);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Project settings'),
      content: SizedBox(
        width: 720,
        height: 560,
        child: ListView(
          // KEYED so a test can scroll THIS list rather than whichever
          // `Scrollable` happens to come first: `AlertDialog` wraps its
          // content in one of its own, and a finder that cannot say which
          // one scrolls the wrong thing and then taps nothing.
          key: kProjectSettingsListKey,
          children: [
            Text(
              'These live in the project file, so they travel with it. '
              'Every change is undoable.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            for (final f in ProjectSettingFields.all) _row(f),
            const Divider(height: 32),
            _FamilyColours(
              doc: widget.doc,
              onEdit: (commands) {
                widget.onEdit(commands);
                setState(() {});
              },
            ),
            const Divider(height: 32),
            _RuleSeverities(
              doc: widget.doc,
              clock: widget.clock,
              actor: widget.actor,
              onEdit: (commands) {
                widget.onEdit(commands);
                setState(() {});
              },
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

  /// One row, dispatched on the field's TYPE, with two exceptions that
  /// have to go first.
  ///
  /// ═══════════════════════════════════════════════════════════════════
  /// EXTENSION TYPES ERASE, SO TYPE DISPATCH CANNOT SEE THEM
  /// ═══════════════════════════════════════════════════════════════════
  /// `Permille` is `extension type const Permille(int v)` and
  /// `MediaTypeId` is `extension type const MediaTypeId(String v)`, so at
  /// RUNTIME a `ProjectSettingField<Permille>` IS a
  /// `ProjectSettingField<int>` and a `ProjectSettingField<MediaTypeId>`
  /// IS a `ProjectSettingField<String>`. The first draft put both in the
  /// switch below and the analyzer refused them as unreachable, which is
  /// the only reason this is a comment rather than two rows that never
  /// drew: reordering does not help, because whichever case comes first
  /// wins for BOTH.
  ///
  /// So these two dispatch on their key. Everything else dispatches on
  /// type, where the `default` arm is a visible refusal rather than a
  /// silent skip.
  Widget _row(ProjectSettingField<Object?> f) {
    if (f.key == ProjectSettingFields.cableWasteFactor.key) {
      const field = ProjectSettingFields.cableWasteFactor;
      return _IntRow(
        field: field,
        value: field.get(_s).v,
        suffix: 'per mille',
        onChanged: (v) => _set(field, Permille(v)),
      );
    }
    if (f.key == ProjectSettingFields.defaultNetworkMedia.key) {
      const field = ProjectSettingFields.defaultNetworkMedia;
      return _MediaRow(
        field: field,
        value: field.get(_s),
        options: widget.doc.registries.mediaTypes.values.toList(),
        onChanged: (v) => _set(field, v),
      );
    }
    return switch (f) {
      ProjectSettingField<UnitSystem>() => _EnumRow<UnitSystem>(
        field: f,
        value: f.get(_s),
        values: UnitSystem.values,
        nameOf: (v) => v == UnitSystem.imperial ? 'Imperial' : 'Metric',
        onChanged: (v) => _set(f, v),
      ),
      ProjectSettingField<RuNumbering>() => _EnumRow<RuNumbering>(
        field: f,
        value: f.get(_s),
        values: RuNumbering.values,
        nameOf: (v) => v == RuNumbering.bottomUpFromOne
            ? 'Bottom-up from 1'
            : 'Top-down from 1',
        onChanged: (v) => _set(f, v),
      ),
      ProjectSettingField<SheetNumbering>() => _EnumRow<SheetNumbering>(
        field: f,
        value: f.get(_s),
        values: SheetNumbering.values,
        nameOf: (v) => v.name,
        onChanged: (v) => _set(f, v),
      ),
      ProjectSettingField<CollisionPolicy>() => _EnumRow<CollisionPolicy>(
        field: f,
        value: f.get(_s),
        values: CollisionPolicy.values,
        nameOf: (v) => v.name,
        onChanged: (v) => _set(f, v),
      ),
      ProjectSettingField<bool>() => SwitchListTile(
        title: Text(f.label),
        subtitle: f.help == null ? null : Text(f.help!),
        value: f.get(_s),
        onChanged: (v) => _set(f, v),
      ),
      ProjectSettingField<IdFormat>() => _FormatRow(
        field: f,
        value: f.get(_s),
        onChanged: (v) => _set(f, v),
      ),
      ProjectSettingField<int>() => _IntRow(
        field: f,
        value: f.get(_s),
        onChanged: (v) => _set(f, v),
      ),
      ProjectSettingField<String>() => _StringRow(
        field: f,
        value: f.get(_s),
        onChanged: (v) => _set(f, v),
      ),
      _ => ListTile(
        title: Text(f.label),
        subtitle: Text(
          'No row for this setting type yet. It is in the field table and '
          'nothing draws it, which is the state that needs fixing.',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ),
    };
  }
}

// ── the row shapes ──────────────────────────────────────────────────────

class _EnumRow<T> extends StatelessWidget {
  const _EnumRow({
    required this.field,
    required this.value,
    required this.values,
    required this.nameOf,
    required this.onChanged,
  });

  final ProjectSettingField<Object?> field;
  final T value;
  final List<T> values;
  final String Function(T) nameOf;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => ListTile(
    title: Text(field.label),
    subtitle: field.help == null ? null : Text(field.help!),
    trailing: DropdownButton<T>(
      value: value,
      items: [
        for (final v in values)
          DropdownMenuItem(value: v, child: Text(nameOf(v))),
      ],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    ),
  );
}

/// An `IdFormat` row, which REFUSES a bad pattern rather than storing it.
///
/// ═══════════════════════════════════════════════════════════════════════
/// THE CONSTRUCTOR VALIDATES NOTHING, AND THE FIRST DRAFT ASSUMED IT DID
/// ═══════════════════════════════════════════════════════════════════════
/// `const IdFormat(this.pattern)` stores the string and checks none of it.
/// `IdFormatSyntaxException` comes from `_parsePattern`, which `render()`
/// calls, so a bad pattern is accepted here and throws LATER, when a
/// designator is minted. A `try` around the constructor is therefore a row
/// that looks like it validates and does not, and the failure surfaces one
/// screen away as a broken paste or import. The test caught it.
///
/// **So the parse is forced.** `requiredTokens()` runs `_parsePattern` and
/// throws on a syntax error, and `unrecognisedTokens()` reports token
/// NAMES the renderer does not know, which is a second class of fault the
/// syntax check does not see: `{NOPE}` parses perfectly and renders
/// nothing.
class _FormatRow extends StatefulWidget {
  const _FormatRow({
    required this.field,
    required this.value,
    required this.onChanged,
  });

  final ProjectSettingField<Object?> field;
  final IdFormat value;
  final ValueChanged<IdFormat> onChanged;

  @override
  State<_FormatRow> createState() => _FormatRowState();
}

class _FormatRowState extends State<_FormatRow> {
  late final _c = TextEditingController(text: widget.value.pattern);
  String? _error;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _commit() {
    final text = _c.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'A pattern cannot be empty.');
      return;
    }
    final next = IdFormat(text);
    // THE SAFE CHECK FIRST. `unrecognisedTokens()` is regex-based and
    // never throws; `requiredTokens()` runs the parser, which throws for a
    // malformed pattern AND for an unknown token NAME. Running the
    // throwing one first while catching only the syntax type let an
    // unknown token escape unhandled, straight out of a text field. The
    // codec's own test caught the identical mistake one package away.
    final unknown = next.unrecognisedTokens();
    if (unknown.isNotEmpty) {
      setState(
        () => _error =
            'Unknown token${unknown.length == 1 ? '' : 's'}: '
            '${unknown.join(', ')}.',
      );
      return;
    }
    try {
      // FORCES THE PARSE. The constructor does not.
      next.requiredTokens();
    } on IdFormatSyntaxException catch (e) {
      // THE PARSER'S OWN WORDS, not a paraphrase: it knows which token it
      // could not read and where, and a rewritten message would be a
      // second description of one fault.
      setState(() => _error = e.message);
      return;
    } on UnrecognisedTokenException catch (e) {
      setState(() => _error = '$e');
      return;
    }
    setState(() => _error = null);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) => ListTile(
    title: Text(widget.field.label),
    subtitle: TextField(
      controller: _c,
      onSubmitted: (_) => _commit(),
      onTapOutside: (_) => _commit(),
      decoration: InputDecoration(
        isDense: true,
        helperText: widget.field.help,
        errorText: _error,
        errorMaxLines: 3,
      ),
    ),
  );
}

class _IntRow extends StatefulWidget {
  const _IntRow({
    required this.field,
    required this.value,
    required this.onChanged,
    this.suffix,
  });

  final ProjectSettingField<Object?> field;
  final int value;
  final String? suffix;
  final ValueChanged<int> onChanged;

  @override
  State<_IntRow> createState() => _IntRowState();
}

class _IntRowState extends State<_IntRow> {
  late final _c = TextEditingController(text: '${widget.value}');
  String? _error;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _commit() {
    final n = int.tryParse(_c.text.trim());
    if (n == null) {
      setState(() => _error = 'Whole numbers only.');
      return;
    }
    if (n < 0) {
      setState(() => _error = 'Cannot be negative.');
      return;
    }
    setState(() => _error = null);
    widget.onChanged(n);
  }

  @override
  Widget build(BuildContext context) => ListTile(
    title: Text(widget.field.label),
    subtitle: TextField(
      controller: _c,
      keyboardType: TextInputType.number,
      onSubmitted: (_) => _commit(),
      onTapOutside: (_) => _commit(),
      decoration: InputDecoration(
        isDense: true,
        helperText: widget.field.help,
        suffixText: widget.suffix,
        errorText: _error,
      ),
    ),
  );
}

class _StringRow extends StatefulWidget {
  const _StringRow({
    required this.field,
    required this.value,
    required this.onChanged,
  });

  final ProjectSettingField<Object?> field;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<_StringRow> createState() => _StringRowState();
}

class _StringRowState extends State<_StringRow> {
  late final _c = TextEditingController(text: widget.value);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListTile(
    title: Text(widget.field.label),
    subtitle: TextField(
      controller: _c,
      // NO EMPTY-CHECK. The separator MAY be empty, which gives MTX1
      // rather than MTX-1, and its own help line says so; refusing it
      // would make a documented value unreachable.
      onSubmitted: (_) => widget.onChanged(_c.text),
      onTapOutside: (_) => widget.onChanged(_c.text),
      decoration: InputDecoration(isDense: true, helperText: widget.field.help),
    ),
  );
}

class _MediaRow extends StatelessWidget {
  const _MediaRow({
    required this.field,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final ProjectSettingField<Object?> field;
  final MediaTypeId value;
  final List<MediaTypeDef> options;
  final ValueChanged<MediaTypeId> onChanged;

  @override
  Widget build(BuildContext context) {
    // A DANGLING DEFAULT IS ADDED TO ITS OWN OPTION LIST rather than reset
    // to something else: `DropdownButton` throws when its value is absent
    // from its items, and a project whose default media type was merged
    // away must still open.
    final ids = {for (final d in options) d.id};
    return ListTile(
      title: Text(field.label),
      subtitle: field.help == null ? null : Text(field.help!),
      trailing: DropdownButton<MediaTypeId>(
        value: value,
        items: [
          if (!ids.contains(value))
            DropdownMenuItem(value: value, child: Text(value.v)),
          for (final d in options)
            DropdownMenuItem(value: d.id, child: Text(d.displayName)),
        ],
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }
}

// ── RJ-012's third surface ──────────────────────────────────────────────

/// The per-family colour override list (AC-054, RJ-012).
///
/// **CR-078 puts colour on the signal DOMAIN, never the family**, and this
/// does not change that: an override is a per-family EXCEPTION to the
/// domain's colour, which is exactly what AC-054 asked for and why it is a
/// list of exceptions rather than a colour per family.
class _FamilyColours extends StatelessWidget {
  const _FamilyColours({required this.doc, required this.onEdit});

  final RackDocument doc;
  final ProjectSettingEdit onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final overrides = doc.settings.familyColorOverrides;
    final families = doc.registries.signalFamilies.values.toList()
      // TOTAL ORDER: `List.sort` is not stable, and two families sharing a
      // display name would otherwise swap between builds.
      ..sort((a, b) {
        final c = a.displayName.toLowerCase().compareTo(
          b.displayName.toLowerCase(),
        );
        return c != 0 ? c : a.id.v.compareTo(b.id.v);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Signal colours', style: theme.textTheme.titleSmall),
        Text(
          'Colour comes from the signal DOMAIN. These are per-family '
          'exceptions to it, and clearing one returns that family to its '
          'domain colour.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        if (overrides.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No family is overridden. Every signal takes its domain '
              'colour.',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: kConsoleEmphasis,
              ),
            ),
          ),
        for (final fam in families)
          if (overrides.containsKey(fam.id))
            ListTile(
              dense: true,
              leading: _Swatch(rgb: overrides[fam.id]!),
              title: Text(fam.displayName),
              subtitle: Text(fam.id.v, style: theme.textTheme.bodySmall),
              trailing: TextButton(
                onPressed: () => onEdit([
                  SetFamilyColorOverrideCommand(
                    family: fam.id,
                    from: overrides[fam.id],
                    to: null,
                  ),
                ]),
                child: const Text('Clear'),
              ),
            ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Override a family colour'),
            onPressed: families.isEmpty
                ? null
                : () async {
                    final picked = await showDialog<SignalFamilyId>(
                      context: context,
                      builder: (context) => _FamilyPicker(
                        families: [
                          for (final f in families)
                            if (!overrides.containsKey(f.id)) f,
                        ],
                      ),
                    );
                    if (picked == null) return;
                    onEdit([
                      SetFamilyColorOverrideCommand(
                        family: picked,
                        from: null,
                        // A STARTING POINT, NOT A GUESS AT INTENT. The
                        // person picks the family here and recolours it
                        // from the swatch; seeding from the domain hue
                        // would create an override that reports as
                        // overridden while looking identical, which is the
                        // coincidence CR-078's reporting must not carry.
                        to: const Rgb(128, 128, 128),
                      ),
                    ]);
                  },
          ),
        ),
      ],
    );
  }
}

/// docs/05 §8's per-project rule severities (`#879`, CR-019, `#297`).
///
/// ═══════════════════════════════════════════════════════════════════
/// WHY HERE AND NOT ON THE FINDING THAT ANNOYED SOMEBODY
/// ═══════════════════════════════════════════════════════════════════
/// `evaluateRuleOverride`'s own words: *"An override is a standing
/// decision about a rule for the whole project."* The issues drawer
/// already offers a project-wide MUTE one click from a per-finding
/// acknowledgement, and putting a second project-wide hammer beside it
/// invites reaching for the bigger one. This dialog is where a reader
/// looks for what the project has decided, and its own header already
/// says these *"live in the project file, so they travel with it"*.
///
/// ═══════════════════════════════════════════════════════════════════
/// THE COMMAND, THE DIALOG AND THE MODEL WERE ALL BUILT ALREADY
/// ═══════════════════════════════════════════════════════════════════
/// `SetRuleOverrideCommand` shipped at M5-B3 with a real revert and
/// eight test constructions; `showRuleSeverityDialog` shipped with its
/// own suite; `RuleOverride` carries the reason, the author and the
/// date, all persisted. **None of it had a caller** (`#872`, `#879`).
class _RuleSeverities extends StatelessWidget {
  const _RuleSeverities({
    required this.doc,
    required this.clock,
    required this.actor,
    required this.onEdit,
  });

  final RackDocument doc;
  final Clock clock;
  final String actor;
  final ProjectSettingEdit onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final overrides = doc.settings.ruleOverrides;
    // CORE'S ANSWER, NOT A FILTER HERE. Tier 1 refuses the edit outright
    // and files no finding, so an override of one would sit in the file
    // forever meaning nothing; `overridableRules` is where that is
    // decided and where a test can read every rule rather than whichever
    // rows a virtualised list happened to build.
    final rules = overridableRules();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Rule severities', style: theme.textTheme.titleSmall),
        Text(
          'What a rule counts as in THIS project. Every override needs a '
          'reason, because it prints on sheet T0.02 for whoever reads the '
          'drawings, and clearing one returns that rule to its default.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        if (overrides.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No rule is overridden. Every rule counts as the catalogue '
              'says.',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: kConsoleEmphasis,
              ),
            ),
          ),
        for (final rule in rules)
          if (overrides.containsKey(rule.ruleId))
            _OverrideRow(
              rule: rule,
              current: overrides[rule.ruleId]!,
              onEdit: (to) => _write(rule.ruleId, overrides[rule.ruleId], to),
              onOpen: () => unawaited(_edit(context, rule)),
            ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            icon: const Icon(Icons.add, size: 18),
            label: const Text(kOverrideARule),
            onPressed: rules.every((r) => overrides.containsKey(r.ruleId))
                ? null
                : () => unawaited(_add(context, rules, overrides)),
          ),
        ),
      ],
    );
  }

  /// Picks a rule, then asks what it should count as.
  Future<void> _add(
    BuildContext context,
    List<RuleMeta> rules,
    Map<String, RuleOverride> overrides,
  ) async {
    final picked = await showDialog<RuleMeta>(
      context: context,
      builder: (context) => _RulePicker(
        rules: [
          for (final r in rules)
            if (!overrides.containsKey(r.ruleId)) r,
        ],
      ),
    );
    if (picked == null || !context.mounted) return;
    await _edit(context, picked);
  }

  /// Opens the severity control for [rule], pre-filled when it already
  /// has an override.
  Future<void> _edit(BuildContext context, RuleMeta rule) async {
    final current = doc.settings.ruleOverrides[rule.ruleId];
    final choice = await showRuleSeverityDialog(
      context: context,
      ruleId: rule.ruleId,
      current: current,
    );
    if (choice == null) return;
    _write(
      rule.ruleId,
      current,
      // NULL SEVERITY IS "use the default", which REMOVES the override
      // rather than recording one that agrees with it. The dialog's own
      // typedef draws that distinction and this is the half of it that
      // writes.
      choice.severity == null
          ? null
          : RuleOverride(
              severity: choice.severity!,
              reason: choice.reason,
              by: actor,
              at: clock.nowUtc(),
            ),
    );
  }

  void _write(String ruleId, RuleOverride? from, RuleOverride? to) =>
      onEdit([SetRuleOverrideCommand(ruleId: ruleId, from: from, to: to)]);
}

/// The label on the control that starts one. Spelled once so the section
/// and its tests agree.
const String kOverrideARule = "Override a rule's severity";

/// One standing decision, with the sentence that justifies it.
class _OverrideRow extends StatelessWidget {
  const _OverrideRow({
    required this.rule,
    required this.current,
    required this.onEdit,
    required this.onOpen,
  });

  final RuleMeta rule;

  /// NAMED `current` AND NOT `override`, which is not style: a field
  /// called `override` shadows the top-level `override` annotation
  /// inside its own class, so `@override` on `build` below stops
  /// resolving. The analyzer says "Undefined name 'override' used as an
  /// annotation", which names the symptom and not the cause.
  final RuleOverride current;
  final ValueChanged<RuleOverride?> onEdit;
  final VoidCallback onOpen;

  /// A stable handle for tests, per rule.
  static String keyFor(String ruleId) => 'rule-override-$ruleId';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      key: ValueKey(keyFor(rule.ruleId)),
      dense: true,
      title: Text('${rule.ruleId}  ${current.severity.name}'),
      // THE REASON IS THE SUBTITLE AND NOT A TOOLTIP. It is the whole
      // point of CR-019 replacing a bare severity map, and it is what
      // prints on the sheet; a reader of this list is exactly the person
      // who needs to see whether the decision still holds.
      subtitle: Text(current.reason, style: theme.textTheme.bodySmall),
      onTap: onOpen,
      trailing: TextButton(
        onPressed: () => onEdit(null),
        child: const Text('Clear'),
      ),
    );
  }
}

/// Which rule to override. Mirrors `_FamilyPicker` deliberately.
class _RulePicker extends StatelessWidget {
  const _RulePicker({required this.rules});

  final List<RuleMeta> rules;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Which rule'),
      content: SizedBox(
        width: 520,
        height: 420,
        child: ListView(
          children: [
            for (final rule in rules)
              ListTile(
                dense: true,
                title: Text(rule.ruleId),
                subtitle: Text(
                  rule.summary,
                  style: theme.textTheme.bodySmall,
                ),
                onTap: () => Navigator.of(context).pop(rule),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.rgb});

  final Rgb rgb;

  @override
  Widget build(BuildContext context) => Container(
    width: 24,
    height: 24,
    decoration: BoxDecoration(
      color: Color.fromARGB(rgb.a, rgb.r, rgb.g, rgb.b),
      // AN OUTLINE ALWAYS, because a near-white swatch is invisible on a
      // light surface, which `jacket_color_convention.dart` already
      // records as debt for the printed sheet.
      border: Border.all(color: Theme.of(context).colorScheme.outline),
      borderRadius: BorderRadius.circular(4),
    ),
  );
}

class _FamilyPicker extends StatelessWidget {
  const _FamilyPicker({required this.families});

  final List<SignalFamilyDef> families;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Which family'),
    content: SizedBox(
      width: 420,
      height: 400,
      child: families.isEmpty
          ? const Center(child: Text('Every family already has an override.'))
          : ListView(
              children: [
                for (final f in families)
                  ListTile(
                    dense: true,
                    title: Text(f.displayName),
                    subtitle: Text(
                      f.id.v,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    onTap: () => Navigator.of(context).pop(f.id),
                  ),
              ],
            ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
    ],
  );
}
