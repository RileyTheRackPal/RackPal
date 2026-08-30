// packages/rackpal_ui/lib/src/library/device_template_io_dialogs.dart
//
// The two dialogs `File ▸ Export device template…` and
// `File ▸ Import device template…` need (DR-101 §11.100, `#236`).
//
// ─────────────────────────────────────────────────────────────────────────
// WHY THE IMPORT CONFIRMATION EXISTS AT ALL, WHICH IS A PLATFORM FACT
// ─────────────────────────────────────────────────────────────────────────
// DR-101 §11.100.5 rules that the inert-data sentence goes "in the import
// dialog". **The native dialog cannot carry it.** `IFileDialog` has
// `SetOkButtonLabel` and `SetFileName` and no body text; adding any would
// mean `IFileDialogCustomize`, which is a slab of C++ for one sentence and
// has no `NSOpenPanel` equivalent for D2 to inherit. So the sentence needs
// an app-side dialog, and once there is one it is also where the collision
// question belongs.
//
// THE STEP EARNS ITS CLICK RATHER THAN BEING TOLERATED. It prints what was
// actually in the file, name and count and occupancy, BEFORE the file
// enters the document. That is the reassurance the sentence is for, aimed
// at the moment somebody is looking at a file a stranger emailed them, and
// the summary is a stronger answer than the sentence alone: a `.rmdx`
// claiming to be a 16x16 matrix and reporting `2 ports` is visible here and
// nowhere else.
//
// ─────────────────────────────────────────────────────────────────────────
// THESE WIDGETS DECIDE; THEY DO NOT MUTATE
// ─────────────────────────────────────────────────────────────────────────
// The same split `new_rack_dialog.dart` and `shrink_rack_dialog.dart` use.
// Each pops a value; `device_template_io_actions.dart` in the app is the
// one place that turns one into a command. `template_import.dart` in core
// already decided what the choices MEAN, so nothing here computes an id, a
// version or a collision.
import 'package:flutter/material.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/src/builder/archetype_dialogs.dart'
    show portsAcrossBanks;

/// What the import confirmation popped.
enum ImportTemplateChoice {
  /// Dismissed, escaped, or `Cancel`. Nothing enters the document.
  cancel,

  /// No collision: land it under the id and version the file carries.
  importIt,

  /// DR-101: keep the id, take `nextTemplateVersion`.
  newVersion,

  /// DR-101: take a suffixed id, land at version 1.
  separateTemplate,
}

/// The resolution [choice] means to `buildTemplateImport`, or null when
/// the id was free and none was owed.
///
/// **SPELLED ONCE, HERE**, because the mapping is the only place the
/// dialog's vocabulary and core's vocabulary touch, and two spellings of
/// it would be a button that quietly did the other thing.
TemplateImportResolution? resolutionFor(ImportTemplateChoice choice) =>
    switch (choice) {
      ImportTemplateChoice.cancel || ImportTemplateChoice.importIt => null,
      ImportTemplateChoice.newVersion => TemplateImportResolution.newVersion,
      ImportTemplateChoice.separateTemplate =>
        TemplateImportResolution.separateTemplate,
    };

/// `4U` / `0U` / `4U front, 2U rear`, as the summary line prints it.
///
/// **A DEVICE THAT MOUNTS IN NO RACK SAYS SO** rather than printing `0U`,
/// which in this product is a real and different claim: `OccupancySide`
/// carries `zeroUVertical` and `MountMethod` carries `notInRack`, and a
/// field device is the latter. Reading `0U` for "not in a rack" is the
/// kind of collapse G4 exists to refuse.
String occupancySummary(TemplateBody body) {
  if (body.mountMethod == MountMethod.notInRack) return 'Not rack-mounted';
  if (body.frontU == 0 && body.rearU == 0) return '0U';
  if (body.rearU == 0 || body.rearU == body.frontU) return '${body.frontU}U';
  if (body.frontU == 0) return '${body.rearU}U rear';
  return '${body.frontU}U front, ${body.rearU}U rear';
}

/// `68 ports across 6 banks · 4U`.
String templateSummaryLine(TemplateBody body) =>
    '${portsAcrossBanks(body.ports.length, body.banks.length)} · '
    '${occupancySummary(body)}';

/// AC-042's mismatch warning, verbatim.
///
/// **A WARNING AND NEVER A REFUSAL**, which is AC-042's whole ruling:
/// refusing to open a file because somebody hand-edited it is a data-loss
/// event dressed as a safety feature. The buttons are unchanged when this
/// shows; the sentence says what is known and lets the person decide.
///
/// It says EDITED rather than CORRUPT or TAMPERED. A hand-edited `.rmdx`
/// is a supported thing to have (`port_validation.dart` reasons about one
/// arriving), and the common cause is somebody fixing a label in a text
/// editor, not an attack.
const String kHashMismatchWarning =
    'This file has been edited since it was exported. That is allowed, and '
    'it is imported exactly as it reads; the note is here so a difference '
    'from the original is not a surprise later.';

/// The inert-data sentence, verbatim (DR-101 §11.100.5, docs/06 §7.3).
///
/// **A CONSTANT SO THE TEST ASSERTS THE SHIPPED STRING** rather than a
/// paraphrase of it. A `contains('no scripts')` would stay green over a
/// rewrite that dropped the second half.
const String kInertDataNotice =
    'A device template is data. It contains no scripts and nothing that '
    'runs.';

/// Picks a template to export, from what the project can place.
///
/// **A CHOOSER RATHER THAN THE SELECTION** (DR-101 §11.100.4 and the
/// user's call at `#236`): since M4-S, a template you authored and saved
/// sits in the project WITHOUT being placed anywhere, which is the state
/// every `Save & Close` leaves you in. Export exists to share what you
/// authored, so the case it must serve is exactly the one a
/// selection-based answer cannot reach.
Future<PlaceableTemplate?> showExportTemplateChooser(
  BuildContext context, {
  required List<PlaceableTemplate> templates,
}) => showDialog<PlaceableTemplate>(
  context: context,
  builder: (context) => _ExportChooserDialog(templates: templates),
);

/// Confirms an import, and asks DR-101's question when there is one.
Future<ImportTemplateChoice> showImportTemplateConfirm(
  BuildContext context, {
  required TemplateImportPlan plan,
}) async =>
    await showDialog<ImportTemplateChoice>(
      context: context,
      builder: (context) => _ImportConfirmDialog(plan: plan),
    ) ??
    // A DISMISSAL IS A CANCEL AND NEVER AN IMPORT. Barrier taps and
    // `Escape` both land here, and the only non-destructive reading of
    // "the user made the dialog go away" is that nothing entered the
    // document.
    ImportTemplateChoice.cancel;

class _ExportChooserDialog extends StatefulWidget {
  const _ExportChooserDialog({required this.templates});

  final List<PlaceableTemplate> templates;

  @override
  State<_ExportChooserDialog> createState() => _ExportChooserDialogState();
}

class _ExportChooserDialogState extends State<_ExportChooserDialog> {
  PlaceableTemplate? _chosen;

  @override
  void initState() {
    super.initState();
    // PRESELECTED WHEN THERE IS EXACTLY ONE, because a list of one with
    // nothing chosen is a dialog asking a question it already knows the
    // answer to. With two or more, nothing is preselected: a default
    // there would be this dialog choosing which device you meant.
    if (widget.templates.length == 1) _chosen = widget.templates.single;
  }

  @override
  Widget build(BuildContext context) {
    final empty = widget.templates.isEmpty;
    return AlertDialog(
      title: const Text('Export device template'),
      content: SizedBox(
        width: 420,
        child: empty
            // THE EMPTY CASE IS NOT REACHABLE FROM THE MENU TODAY and is
            // built anyway: `buildPlaceableTemplates` reads the seed too,
            // so a project always has rows. If that ever stops being
            // true, this says what to do instead of rendering a blank box.
            ? const Text(
                'This project has no device templates to export. Author '
                'one in the Device Builder first.',
              )
            : ListView.builder(
                shrinkWrap: true,
                itemCount: widget.templates.length,
                itemBuilder: (context, i) {
                  final row = widget.templates[i];
                  // `rowKey`, not `key`: `#241` made the document key
                  // nullable, and two nulls comparing equal would have
                  // made every library row read as the chosen one. This
                  // list holds document rows only, so the bug was not
                  // reachable from here; the identity is spelled the safe
                  // way regardless, because the day this list grows a
                  // library row is not the day to remember.
                  final chosen = row.rowKey == _chosen?.rowKey;
                  // A SELECTABLE ListTile RATHER THAN A RadioListTile,
                  // and the reason is mechanical: `groupValue` and
                  // `onChanged` are deprecated in favour of a
                  // `RadioGroup` ancestor, and this repository gates the
                  // analyzer info count at a pinned number, so a
                  // deprecation warning here is a failed build rather
                  // than a note. The whole row is the target either way.
                  return ListTile(
                    selected: chosen,
                    onTap: () => setState(() => _chosen = row),
                    leading: Icon(
                      chosen ? Icons.check_circle : Icons.circle_outlined,
                    ),
                    title: Text(row.body.displayName),
                    subtitle: Text(
                      // The version is printed because two rows can read
                      // identically otherwise, and because what leaves
                      // the machine is a specific version.
                      'v${row.version} · ${templateSummaryLine(row.body)}',
                    ),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _chosen == null
              ? null
              : () => Navigator.of(context).pop(_chosen),
          child: const Text('Export…'),
        ),
      ],
    );
  }
}

class _ImportConfirmDialog extends StatelessWidget {
  const _ImportConfirmDialog({required this.plan});

  final TemplateImportPlan plan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final body = plan.file.body;
    final collision = plan.collision;
    return AlertDialog(
      title: const Text('Import device template'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(body.displayName, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              templateSummaryLine(body),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Text(kInertDataNotice, style: theme.textTheme.bodySmall),
            // AC-042's warning, and the FIRST SURFACE `contentHash` has
            // ever had. Shown only for `hashMismatched`, which is true
            // for a file carrying a real hash that fails it and false for
            // one carrying no hash at all: a `.rmdx` written before
            // `#795` is UNKNOWN, not modified, and warning about it would
            // fire on every file this product wrote before today.
            if (plan.hashMismatched) ...[
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      kHashMismatchWarning,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
            if (collision != null) ...[
              const Divider(height: 24),
              Text(
                // THE INCUMBENT'S NAME, NOT THE INCOMING ONE. The id is a
                // slug of the display name, so two spellings collide
                // while reading differently, and printing the incoming
                // name here would show the user a string compared with
                // itself.
                'A device template named "${collision.incumbentDisplayName}" '
                'is already in this project '
                '(version ${collision.incumbentLatestVersion}).',
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(ImportTemplateChoice.cancel),
          child: const Text('Cancel'),
        ),
        if (collision == null)
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(ImportTemplateChoice.importIt),
            child: const Text('Import'),
          )
        else ...[
          // TWO BUTTONS AND NO DEFAULT AMONG THEM (DR-101 §11.100.3).
          // Neither is `FilledButton`, because there is no right answer
          // for the app to nominate: the whole ruling is that only the
          // person knows which case this is.
          TextButton(
            onPressed: () => Navigator.of(
              context,
            ).pop(ImportTemplateChoice.separateTemplate),
            child: const Text('Import as a separate template'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(ImportTemplateChoice.newVersion),
            child: const Text('Add as a new version of it'),
          ),
        ],
      ],
    );
  }
}
