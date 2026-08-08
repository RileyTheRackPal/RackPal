// `+ Add outlet ▾`, as a surface. Board M3-C/5 (#151), DR-024 §11.23.3.
//
// ═══════════════════════════════════════════════════════════════════════
// PICK A ROOM, PICK A RECIPE, SEE THE LABELS, ADD
// ═══════════════════════════════════════════════════════════════════════
// docs/07 §4.3: *"instantiates an `OutletTemplate` in one action, TV
// location → 2 × Cat6 + 2 × RG6 as one `Outlet` with four `Link`s and
// four label pairs."* The one action is the button; everything above it
// exists so the person can see what the action will do.
//
// ═══════════════════════════════════════════════════════════════════════
// THE PREVIEW SHOWS LABELS, FOR THE SAME REASON THE DROP PANEL'S DOES
// ═══════════════════════════════════════════════════════════════════════
// "4 drops" is a number nobody can check. `LR-TV-1 … LR-TV-4` is what
// gets printed on cable, and CR-048 stores a designator ONCE at creation,
// so this is the last cheap moment there is. A wrong room here costs one
// click; a wrong room after Add costs a re-label.
//
// The recipe line under each template name is the second half of that:
// *2 × Cat6 · 2 × RG6 quad* is what will be pulled, in the trade's own
// words, so choosing between *TV location* and *Grade 2* does not require
// remembering what either contains.
//
// ═══════════════════════════════════════════════════════════════════════
// ONE COMMIT PATH, AND THE APP OWNS IT
// ═══════════════════════════════════════════════════════════════════════
// The panel plans a preview on every rebuild with a throwaway clock and
// the actor `preview`. Those values reach `EntityMeta.createdAt` and
// `.updatedBy` on every command a plan holds, so handing the preview's
// commands to the app would write the string `preview` onto real cable
// records — the defect M3-A/6 found in the drop panel and fixed the same
// way. `onCommit` therefore takes the CHOICE (a template and a room) and
// the app re-plans against its own clock and actor.
//
// NO COMMANDS RUN HERE. The panel takes the document and callbacks, the
// shape `LocationsPanel`, `RackInspectorPanel` and `DropEntryPanel`
// already use, so `rackmate_ui` stays free of the controller.
import 'package:flutter/material.dart';
import 'package:rackmate_core/rackmate_core.dart';

/// Opens the picker as a dialog.
///
/// A DIALOG AND NOT A MENU, for now and for a stated reason: board #148's
/// Structure editor is where `+ Add outlet ▾` lives permanently, in the
/// button bar under the drop table. Until that editor exists, a gesture
/// only a widget test drives has not been driven.
///
/// [currentDoc] is read on EVERY build rather than captured once, so the
/// second outlet is planned against the state the first one left. A
/// dialog holding one document reference would offer labels the previous
/// add just spent.
Future<void> showOutletTemplatePicker(
  BuildContext context, {
  required OutletTemplateActions actions,
  required RackDocument Function() currentDoc,
}) => showDialog<void>(
  context: context,
  builder: (context) => Dialog(
    child: SizedBox(
      width: 560,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: _OutletTemplateHost(actions: actions, currentDoc: currentDoc),
      ),
    ),
  ),
);

class _OutletTemplateHost extends StatefulWidget {
  const _OutletTemplateHost({required this.actions, required this.currentDoc});

  final OutletTemplateActions actions;
  final RackDocument Function() currentDoc;

  @override
  State<_OutletTemplateHost> createState() => _OutletTemplateHostState();
}

class _OutletTemplateHostState extends State<_OutletTemplateHost> {
  final List<String> _recent = [];

  @override
  Widget build(BuildContext context) => OutletTemplatePicker(
    doc: widget.currentDoc(),
    recent: _recent,
    actions: OutletTemplateActions(
      onCommit: (template, locationId) {
        final committed = widget.actions.onCommit(template, locationId);
        // The tail reports what the APP did, not what the preview
        // predicted, for the same reason `onCommit` takes the choice.
        if (committed is OutletTemplatePlanReady) {
          setState(() {
            _recent.insert(
              0,
              '${committed.outletDesignation}: '
              '${committed.fieldLabels.join(', ')}',
            );
          });
        }
        return committed;
      },
      onCreateStructure: () {
        widget.actions.onCreateStructure();
        setState(() {});
      },
    ),
  );
}

/// What the app does with a choice the picker has made.
@immutable
final class OutletTemplateActions {
  const OutletTemplateActions({
    required this.onCommit,
    required this.onCreateStructure,
  });

  /// Place one outlet, and report what actually happened.
  ///
  /// THE CHOICE CROSSES THIS BOUNDARY, NOT THE PREVIEW'S PLAN. See the
  /// file header: the preview is planned with a throwaway clock and the
  /// actor `preview`, and both reach `EntityMeta` on every command a plan
  /// holds. Re-planning app-side is free, because `planOutletFromTemplate`
  /// mutates nothing.
  final OutletTemplatePlan Function(OutletTemplate template, Uuid locationId)
  onCommit;

  /// The project has no Structure device to hang an outlet on. Creating
  /// it is the user's call and never this panel's.
  final VoidCallback onCreateStructure;
}

/// A room, the nine recipes, and what the chosen one will create.
class OutletTemplatePicker extends StatefulWidget {
  const OutletTemplatePicker({
    required this.doc,
    required this.actions,
    super.key,
    this.recent = const [],
  });

  final RackDocument doc;
  final OutletTemplateActions actions;

  /// What the last few adds produced, newest first, so the gesture has a
  /// visible tail when several outlets go in one after another.
  final List<String> recent;

  @override
  State<OutletTemplatePicker> createState() => _OutletTemplatePickerState();
}

class _OutletTemplatePickerState extends State<OutletTemplatePicker> {
  String? _templateId;
  Uuid? _locationId;

  List<OutletTemplate> get _templates =>
      offerableOutletTemplates(widget.doc.registries);

  /// The rooms, breadcrumbed, in the tree's own order (CR-047: *"the same
  /// tree flattened to breadcrumb strings"*).
  List<(Uuid, String)> get _rooms {
    final tree = LocationTree.of(widget.doc);
    final out = <(Uuid, String)>[];
    void walk(Uuid id) {
      final crumb = breadcrumbOf(widget.doc, tree, id);
      if (crumb != null) out.add((id, crumb));
      for (final child in tree.childrenOf(id)) {
        walk(child);
      }
    }

    for (final root in tree.roots) {
      walk(root);
    }
    return out;
  }

  OutletTemplate? get _selectedTemplate {
    final id = _templateId;
    if (id == null) return null;
    return widget.doc.registries.outletTemplates[id];
  }

  /// The preview. PLANNED, NOT GUESSED, and thrown away every build —
  /// `planOutletFromTemplate` mutates nothing, so this costs a list
  /// allocation and buys the exact labels.
  OutletTemplatePlan? get _plan {
    final template = _selectedTemplate;
    final locationId = _locationId;
    if (template == null || locationId == null) return null;
    return planOutletFromTemplate(
      doc: widget.doc,
      template: template,
      locationId: locationId,
      // PREVIEW VALUES, AND THEY NEVER REACH A DOCUMENT. See
      // `OutletTemplateActions.onCommit`.
      now: DateTime.now(),
      actor: 'preview',
    );
  }

  void _submit() {
    final template = _selectedTemplate;
    final locationId = _locationId;
    if (template == null || locationId == null) return;
    if (_plan case OutletTemplatePlanNeedsStructure()) {
      widget.actions.onCreateStructure();
      return;
    }
    widget.actions.onCommit(template, locationId);
    // NOT CLEARED. Placing four TV locations in four rooms is one room
    // change and one click each; resetting the recipe would make the
    // second one cost two.
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rooms = _rooms;
    // Default to the first room rather than to nothing: a picker whose
    // preview is blank until two choices are made shows nothing at the
    // moment it is most useful.
    _locationId ??= rooms.isEmpty ? null : rooms.first.$1;

    final plan = _plan;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Add outlet', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        if (rooms.isEmpty)
          Text(
            'This project has no rooms yet. Add one in Project ▸ Locations…',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          )
        else
          DropdownButtonFormField<Uuid>(
            initialValue: _locationId,
            decoration: const InputDecoration(
              labelText: 'Room',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final (id, crumb) in rooms)
                DropdownMenuItem(value: id, child: Text(crumb)),
            ],
            onChanged: (id) => setState(() => _locationId = id),
          ),
        const SizedBox(height: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 380),
          child: ListView(
            shrinkWrap: true,
            children: [
              // GROUPED BY WHETHER THE RECIPE CITES A STANDARD, not by
              // id. Nine rows do not fit, so the grades would otherwise
              // sit below the fold with nothing saying they are there;
              // and grouping on the property rather than on
              // `outlet.tia570d_*` is the same argument DR-024 §11.23.2
              // made about the stamp, applied to the list.
              for (final t in _templates)
                if (t.tia570Grade == null)
                  _TemplateRow(
                    template: t,
                    registries: widget.doc.registries,
                    selected: t.id == _templateId,
                    onTap: () => setState(() => _templateId = t.id),
                  ),
              if (_templates.any((t) => t.tia570Grade != null)) ...[
                const Divider(height: 16),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                  child: Text(
                    'Standards presets',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
              for (final t in _templates)
                if (t.tia570Grade != null)
                  _TemplateRow(
                    template: t,
                    registries: widget.doc.registries,
                    selected: t.id == _templateId,
                    onTap: () => setState(() => _templateId = t.id),
                  ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _Preview(plan: plan),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: plan == null ? null : _submit,
              child: Text(
                plan is OutletTemplatePlanNeedsStructure
                    ? 'Create Structure device'
                    : 'Add outlet',
              ),
            ),
          ],
        ),
        if (widget.recent.isNotEmpty) ...[
          const Divider(height: 24),
          Text('Just added', style: theme.textTheme.labelMedium),
          const SizedBox(height: 4),
          for (final line in widget.recent.take(5))
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(line, style: theme.textTheme.bodySmall),
            ),
        ],
      ],
    );
  }
}

/// One recipe: its name, its `{SERVICE}` tag, what it pulls, and the
/// standard it cites if it cites one.
class _TemplateRow extends StatelessWidget {
  const _TemplateRow({
    required this.template,
    required this.registries,
    required this.selected,
    required this.onTap,
  });

  final OutletTemplate template;
  final Registries registries;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      dense: true,
      selected: selected,
      onTap: onTap,
      title: Row(
        children: [
          Text(template.name),
          if (template.tag case final tag?) ...[
            const SizedBox(width: 8),
            // The `{SERVICE}` segment its drops will carry (DR-022). Shown
            // because it is the part that ends up on cable, and the part a
            // person cannot infer from "Ceiling speaker pair".
            Text(
              tag,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ],
      ),
      subtitle: Text(
        recipeSummary(template, registries),
        style: theme.textTheme.bodySmall,
      ),
      trailing: template.tia570Grade == null
          ? null
          : Text(
              // The citation, verbatim. CR-108 keeps it a standards TAG,
              // so it is displayed rather than interpreted.
              template.tia570Grade!,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
    );
  }
}

/// `2 × Cat6 · 2 × RG6 quad-shield` — what the recipe pulls, in the
/// registry's own display names.
///
/// A MEDIA ID THE DOCUMENT DOES NOT CARRY IS SHOWN RAW rather than
/// hidden. §6.2's rule for an unresolved id is that it "round-trips,
/// renders grey with the raw id as its tag, and never throws", and a row
/// that silently dropped a drop would understate what is about to be
/// pulled.
String recipeSummary(OutletTemplate template, Registries registries) {
  if (template.drops.isEmpty) return 'no drops';
  final parts = <String>[];
  for (final d in template.drops) {
    final name = registries.mediaTypes[d.media]?.displayName ?? d.media.v;
    parts.add('${d.count} × $name');
  }
  return parts.join(' · ');
}

/// The line above the button: what will happen, or why it will not.
class _Preview extends StatelessWidget {
  const _Preview({required this.plan});

  final OutletTemplatePlan? plan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    switch (plan) {
      case null:
        return Text(
          'Pick a recipe to see the labels it will create.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        );

      case OutletTemplatePlanReady(
        :final dropCount,
        :final fieldLabels,
        :final outletDesignation,
        :final tia570Grade,
      ):
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Outlet $outletDesignation · $dropCount '
              '${dropCount == 1 ? "drop" : "drops"}'
              '${tia570Grade == null ? "" : " · $tia570Grade"}',
              style: theme.textTheme.labelMedium,
            ),
            const SizedBox(height: 2),
            Text(
              fieldLabels.join(', '),
              style: theme.textTheme.bodySmall?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        );

      case OutletTemplatePlanNeedsStructure():
        // AN OFFER, NOT AN ERROR — the same shape the drop panel uses,
        // for the same reason: a blank project is always missing this and
        // it is one click away.
        return Text(
          'This project has no Structure device yet. The button creates one.',
          style: theme.textTheme.bodySmall?.copyWith(color: scheme.primary),
        );

      case OutletTemplatePlanRefused(:final reason):
        return Text(
          reason,
          style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
        );
    }
  }
}
