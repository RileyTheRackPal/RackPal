// THE IMPORT SURFACE. Board M3-F/2 (#160) and M3-F/3 (#161), docs/07
// §5.1, §5.3.
//
// ═════════════════════════════════════════════════════════════════════
// ONE DIALOG, AND THE PREVIEW IS LIVE
// ═════════════════════════════════════════════════════════════════════
// Settled by the user on 2026-08-10, against a three-step wizard and
// against a preview-first surface. §5.1's column-mapping sheet and
// §5.3's preview grid are the same question at two altitudes, so they
// share a surface and the grid re-renders the instant a dropdown moves.
//
// The operator's real question about a mapping is "did that do what I
// meant", and only a grid that has already changed answers it. A wizard
// hides the consequence behind a Next button, which is where a person
// gives up and edits the spreadsheet in Excel instead.
//
// ═════════════════════════════════════════════════════════════════════
// NOTHING HERE DECIDES ANYTHING. IT RE-ASKS CORE ON EVERY BUILD
// ═════════════════════════════════════════════════════════════════════
// `resolveCsvRows` then `planCsvImport`, from scratch, every time the
// mapping or a tick box changes. That is deliberate and it is cheap: the
// ceiling is 50,000 rows and the ordinary case is sixty. What it buys is
// that the counts in the footer and the rows in the grid CANNOT disagree
// with each other or with what the commit will do, because all three
// come from one call against the same document.
//
// ═════════════════════════════════════════════════════════════════════
// M3-F/3's CONFIRM IS ARMED BY THE PLAN, NOT BY THE GESTURE
// ═════════════════════════════════════════════════════════════════════
// §5.3.5 wants an import-over-existing confirmation listing the counts,
// and DR-013's delete and the shrink modal are the same class: one
// gesture changes work the user cannot see all of. It fires when
// `plan.touchesExistingWork`, which is `updateCount > 0`.
//
// AN IMPORT THAT ONLY CREATES DOES NOT GET THE DIALOG. Creating sixty
// drops in an empty project is the ordinary February act, and a confirm
// on it would be the modal people learn to dismiss without reading,
// which is what makes the one that matters useless.
import 'package:flutter/material.dart';
import 'package:rackmate_core/rackmate_core.dart';

/// What the operator settled on, for the app to build commands from.
///
/// THE MAPPING AND THE TICK BOXES, NOT THE PLAN. The app re-derives the
/// plan from these against the live document, which is one more call and
/// removes the only way this surface could hand over a plan computed
/// against a document that has since moved.
@immutable
final class CsvImportChoice {
  const CsvImportChoice({
    required this.mapping,
    required this.declinedLocations,
    required this.declinedMediaTokens,
  });

  final CsvMapping mapping;
  final Set<String> declinedLocations;
  final Set<String> declinedMediaTokens;
}

/// Opens docs/07 §5's import surface over [table].
///
/// Returns the operator's choice, or null if they cancelled.
Future<CsvImportChoice?> showCsvImportDialog(
  BuildContext context, {
  required CsvTable table,
  required RackDocument Function() currentDoc,
  required String fileName,
}) => showDialog<CsvImportChoice>(
  context: context,
  builder: (context) => Dialog(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1100, maxHeight: 820),
      child: CsvImportView(
        table: table,
        currentDoc: currentDoc,
        fileName: fileName,
        onImport: (choice) => Navigator.of(context).pop(choice),
        onCancel: () => Navigator.of(context).pop(),
      ),
    ),
  ),
);

/// The dialog's body, as a widget a test can drive without a route.
class CsvImportView extends StatefulWidget {
  const CsvImportView({
    required this.table,
    required this.currentDoc,
    required this.fileName,
    required this.onImport,
    this.onCancel,
    super.key,
  });

  final CsvTable table;
  final RackDocument Function() currentDoc;

  /// Shown in the header so a person can see they picked the file they
  /// meant, which is the cheapest possible guard against importing last
  /// week's revision.
  final String fileName;

  final void Function(CsvImportChoice choice) onImport;
  final VoidCallback? onCancel;

  @override
  State<CsvImportView> createState() => _CsvImportViewState();
}

class _CsvImportViewState extends State<CsvImportView> {
  late CsvMapping _mapping;
  final Set<String> _declinedLocations = {};
  final Set<String> _declinedMedia = {};

  @override
  void initState() {
    super.initState();
    final registries = widget.currentDoc().registries;
    _mapping = CsvMapping.guess(
      table: widget.table,
      detection: detectCsvShape(widget.table, registries),
      registries: registries,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final doc = widget.currentDoc();
    final rows = resolveCsvRows(
      table: widget.table,
      mapping: _mapping,
      registries: doc.registries,
      settings: doc.settings,
    );
    final plan = planCsvImport(
      doc: doc,
      rows: rows,
      declinedLocations: _declinedLocations,
      declinedMediaTokens: _declinedMedia,
    );
    final problems = _mapping.problems;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(theme),
        const Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _shapeRow(theme, doc),
                const SizedBox(height: 16),
                _mappingSheet(theme),
                if (problems.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ...problems.map((p) => _problemLine(theme, p)),
                ],
                if (plan.newLocationNames.isNotEmpty ||
                    plan.newMediaTokens.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _willCreate(theme, plan),
                ],
                if (plan.issues.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ...plan.issues.map(
                    (i) => _issueLine(theme, i.message, i.severity),
                  ),
                ],
                const SizedBox(height: 16),
                _preview(theme, plan),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        _footer(theme, plan),
      ],
    );
  }

  Widget _header(ThemeData theme) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
    child: Row(
      children: [
        Text(kCsvImportTitle, style: theme.textTheme.titleMedium),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            widget.fileName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    ),
  );

  /// docs/07 §5: wide is OFFERED, so the detector's answer is a default
  /// with its reason beside it and not a verdict.
  Widget _shapeRow(ThemeData theme, RackDocument doc) {
    final detection = detectCsvShape(widget.table, doc.registries);
    return Row(
      children: [
        SegmentedButton<CsvShape>(
          segments: const [
            ButtonSegment(
              value: CsvShape.long,
              label: Text(kLongShapeLabel),
            ),
            ButtonSegment(
              value: CsvShape.wide,
              label: Text(kWideShapeLabel),
            ),
          ],
          selected: {_mapping.shape},
          onSelectionChanged: (s) => setState(() {
            _mapping = _mapping.asShape(
              s.single,
              table: widget.table,
              registries: doc.registries,
            );
          }),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            detection.reason,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  /// §5.1: "Every source header appears in a column-mapping sheet with
  /// RackMate's guess and a dropdown to correct it."
  ///
  /// EVERY HEADER, including the ones that mapped cleanly. Showing only
  /// the unmapped ones would hide a WRONG guess, which is the failure
  /// that costs most: an unmapped column asks a question, a
  /// mis-mapped one silently files a length as a quantity.
  Widget _mappingSheet(ThemeData theme) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(kMappingSheetTitle, style: theme.textTheme.titleSmall),
      const SizedBox(height: 8),
      for (var n = 0; n < _mapping.headers.length; n++)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              SizedBox(
                width: 220,
                child: Text(
                  _mapping.headers[n].isEmpty
                      ? '(column ${n + 1})'
                      : _mapping.headers[n],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: _targetDropdown(n)),
            ],
          ),
        ),
    ],
  );

  Widget _targetDropdown(int column) {
    final assignment = _mapping.assignments[column];
    // A wide sheet's cable column is not a target choice: the header
    // named the cable and changing that would mean renaming the column.
    // Shown as a fixed label so the row still appears, per §5.1's "every
    // source header".
    if (assignment case CsvColumnMediaCount(:final media)) {
      return Text(
        '$kMediaCountPrefix${media.v}',
        style: Theme.of(context).textTheme.bodyMedium,
      );
    }
    return DropdownButtonFormField<CsvColumnTarget?>(
      initialValue: assignment is CsvColumnMapped ? assignment.target : null,
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      items: [
        // THE ONLY NON-TARGET OPTION, and there is no "discard". §5.1 is
        // unconditional that user data is never discarded; see
        // `csv_mapping.dart`'s header for the whole argument.
        const DropdownMenuItem(child: Text(kKeepAsExtraLabel)),
        for (final target in CsvColumnTarget.values)
          DropdownMenuItem(value: target, child: Text(target.name)),
      ],
      onChanged: (target) => setState(() {
        _mapping = _mapping.withAssignment(
          column,
          target == null ? const CsvColumnKept() : CsvColumnMapped(target),
        );
      }),
    );
  }

  /// The user's 2026-08-10 decision: everything an import would invent,
  /// in ONE list, ticked, with unticking making its rows skip.
  Widget _willCreate(ThemeData theme, CsvImportPlan plan) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(kWillCreateTitle, style: theme.textTheme.titleSmall),
      for (final name in plan.newLocationNames)
        _createCheck(
          label: '$kRoomPrefix$name',
          value: !_declinedLocations.contains(name),
          onChanged: (on) => setState(() {
            on ? _declinedLocations.remove(name) : _declinedLocations.add(name);
          }),
        ),
      for (final token in plan.newMediaTokens)
        _createCheck(
          label: '$kCablePrefix$token',
          value: !_declinedMedia.contains(token),
          onChanged: (on) => setState(() {
            on ? _declinedMedia.remove(token) : _declinedMedia.add(token);
          }),
        ),
    ],
  );

  Widget _createCheck({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) => CheckboxListTile(
    dense: true,
    controlAffinity: ListTileControlAffinity.leading,
    contentPadding: EdgeInsets.zero,
    value: value,
    title: Text(label),
    onChanged: (v) => onChanged(v ?? false),
  );

  Widget _problemLine(ThemeData theme, CsvMappingProblem problem) => _issueLine(
    theme,
    problem.message,
    problem.blocks ? CsvIssueSeverity.error : CsvIssueSeverity.warning,
  );

  Widget _issueLine(
    ThemeData theme,
    String message,
    CsvIssueSeverity severity,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          severity == CsvIssueSeverity.error
              ? Icons.error_outline
              : Icons.warning_amber_outlined,
          size: 16,
          color: severity == CsvIssueSeverity.error
              ? theme.colorScheme.error
              : theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(message, style: theme.textTheme.bodySmall)),
      ],
    ),
  );

  /// §5.3's preview grid: the parsed result with per-row validation,
  /// before commit.
  ///
  /// **A SKIPPED ROW IS DRAWN, STRUCK THROUGH.** Omitting it would make
  /// four of sixty rows vanish with only a footer number to say so, and
  /// the whole reason this grid exists is that a person can see which
  /// ones.
  Widget _preview(ThemeData theme, CsvImportPlan plan) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(kPreviewTitle, style: theme.textTheme.titleSmall),
      const SizedBox(height: 8),
      // Wide content scrolls inside its own box rather than making the
      // dialog scroll sideways.
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 32,
          dataRowMinHeight: 30,
          dataRowMaxHeight: 46,
          columns: const [
            DataColumn(label: Text(kLineColumn)),
            DataColumn(label: Text(kRoomColumn)),
            DataColumn(label: Text(kOutletColumn)),
            DataColumn(label: Text(kCableColumn)),
            DataColumn(label: Text(kActionColumn)),
            DataColumn(label: Text(kNoteColumn)),
          ],
          rows: [
            for (final planned in plan.rows) _previewRow(theme, planned),
          ],
        ),
      ),
    ],
  );

  DataRow _previewRow(ThemeData theme, CsvPlannedRow planned) {
    final row = planned.row;
    final skipped = planned.action == CsvRowAction.skipped;
    final issues = [...row.issues, ...planned.issues];
    final style = skipped
        ? theme.textTheme.bodySmall?.copyWith(
            decoration: TextDecoration.lineThrough,
            color: theme.colorScheme.onSurfaceVariant,
          )
        : theme.textTheme.bodySmall;

    return DataRow(
      cells: [
        DataCell(Text('${row.source.line}', style: style)),
        DataCell(Text(row.locationName, style: style)),
        DataCell(Text(row.outletDesignation ?? '', style: style)),
        DataCell(Text(_cableSummary(planned), style: style)),
        DataCell(Text(_actionLabel(planned), style: style)),
        DataCell(
          issues.isEmpty
              ? const SizedBox.shrink()
              : Text(
                  issues.first.message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color:
                        issues.any(
                          (i) => i.severity == CsvIssueSeverity.error,
                        )
                        ? theme.colorScheme.error
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
        ),
      ],
    );
  }

  static String _cableSummary(CsvPlannedRow planned) => planned.row.items
      .map(
        (i) => switch (i.media) {
          ResolvedMediaKnown(:final id) => '${i.count}x ${id.v}',
          ResolvedMediaNew(:final token) => '${i.count}x $token',
        },
      )
      .join(', ');

  static String _actionLabel(CsvPlannedRow planned) => switch (planned.action) {
    CsvRowAction.create => '$kCreateWord ${planned.drops}',
    CsvRowAction.update => '$kUpdateWord ${planned.drops}',
    CsvRowAction.unchanged => kUnchangedWord,
    CsvRowAction.skipped => kSkippedWord,
  };

  Widget _footer(ThemeData theme, CsvImportPlan plan) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
    child: Row(
      children: [
        Expanded(
          child: Text(
            csvCountsSentence(plan),
            style: theme.textTheme.bodyMedium,
          ),
        ),
        if (widget.onCancel != null)
          TextButton(
            onPressed: widget.onCancel,
            child: const Text(kCancelLabel),
          ),
        const SizedBox(width: 8),
        FilledButton(
          // A BLOCKING MAPPING PROBLEM DISABLES THE BUTTON rather than
          // letting the press fail. §5.3's never-fail-fast is about
          // rows; a sheet with no room column has not said where
          // anything goes, and the fix is a dropdown already on screen.
          onPressed: _mapping.isComplete ? () => _import(plan) : null,
          child: const Text(kImportLabel),
        ),
      ],
    ),
  );

  Future<void> _import(CsvImportPlan plan) async {
    if (plan.touchesExistingWork) {
      final ok = await showCsvOverwriteConfirm(context, plan: plan);
      if (ok != true) return;
    }
    widget.onImport(
      CsvImportChoice(
        mapping: _mapping,
        declinedLocations: {..._declinedLocations},
        declinedMediaTokens: {..._declinedMedia},
      ),
    );
  }
}

/// §5.3.5's import-over-existing confirmation (M3-F/3, #161).
///
/// **THE COUNT IS STATED BEFORE ANYTHING IS WRITTEN**, which is the
/// task's own requirement and DR-013's rule for the same class of act:
/// one gesture changes work the user cannot see all of. The counts come
/// from the plan the grid behind this dialog is already showing, so the
/// number here and the rows there cannot disagree.
///
/// **UNDO RESTORES THEM**, because the whole import is one transaction
/// under `LabelKey.importCsv`. That is said in the dialog rather than
/// assumed, since a person deciding whether to risk it is deciding
/// exactly that.
Future<bool?> showCsvOverwriteConfirm(
  BuildContext context, {
  required CsvImportPlan plan,
}) => showDialog<bool>(
  context: context,
  builder: (context) => AlertDialog(
    title: const Text(kOverwriteTitle),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(csvOverwriteSentence(plan)),
        const SizedBox(height: 12),
        Text(csvCountsSentence(plan)),
        const SizedBox(height: 12),
        const Text(kUndoReassurance),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(false),
        child: const Text(kCancelLabel),
      ),
      FilledButton(
        onPressed: () => Navigator.of(context).pop(true),
        child: const Text(kOverwriteConfirmLabel),
      ),
    ],
  ),
);

/// `create 14 · update 38 · unchanged 9`, docs/07 §5.3.5's own wording.
///
/// SKIPPED IS APPENDED WHEN THERE IS ANY, and never omitted when there
/// is: a footer that added up to fifty-six on a sixty-row sheet, with no
/// line for the other four, is the silent discard G4 forbids.
String csvCountsSentence(CsvImportPlan plan) {
  final parts = [
    '$kCreateWord ${plan.createCount}',
    '$kUpdateWord ${plan.updateCount}',
    '$kUnchangedWord ${plan.unchangedCount}',
    if (plan.skippedRowCount > 0) '$kSkippedWord ${plan.skippedRowCount}',
  ];
  return parts.join(' · ');
}

/// The sentence naming what is at risk, in drops rather than rows.
String csvOverwriteSentence(CsvImportPlan plan) {
  final n = plan.updateCount;
  return n == 1
      ? 'This import changes 1 drop that is already in the project.'
      : 'This import changes $n drops that are already in the project.';
}

/// The Structure editor's toolbar entry (docs/07 §4).
const String kImportCsvLabel = 'Import CSV…';

/// See [kImportCsvLabel].
const String kCsvImportTitle = 'Import CSV';

/// See [kImportCsvLabel].
const String kMappingSheetTitle = 'Columns';

/// See [kImportCsvLabel].
const String kWillCreateTitle = 'Will create';

/// See [kImportCsvLabel].
const String kPreviewTitle = 'Preview';

/// See [kImportCsvLabel].
const String kKeepAsExtraLabel = 'Keep as extra data';

/// See [kImportCsvLabel].
const String kMediaCountPrefix = 'Cable count: ';

/// See [kImportCsvLabel].
const String kRoomPrefix = 'Room: ';

/// See [kImportCsvLabel].
const String kCablePrefix = 'Cable type: ';

/// See [kImportCsvLabel].
const String kLongShapeLabel = 'One row per drop';

/// See [kImportCsvLabel].
const String kWideShapeLabel = 'One row per room';

/// See [kImportCsvLabel].
const String kImportLabel = 'Import';

/// See [kImportCsvLabel].
const String kCancelLabel = 'Cancel';

/// See [kImportCsvLabel].
const String kOverwriteTitle = 'Import over existing drops?';

/// See [kImportCsvLabel].
const String kOverwriteConfirmLabel = 'Import';

/// See [kImportCsvLabel].
const String kUndoReassurance =
    'The whole import is one step, so Undo puts everything back.';

/// See [kImportCsvLabel].
const String kLineColumn = 'LINE';

/// See [kImportCsvLabel].
const String kRoomColumn = 'ROOM';

/// See [kImportCsvLabel].
const String kOutletColumn = 'OUTLET';

/// See [kImportCsvLabel].
const String kCableColumn = 'CABLE';

/// See [kImportCsvLabel].
const String kActionColumn = 'ACTION';

/// See [kImportCsvLabel].
const String kNoteColumn = 'NOTE';

/// See [kImportCsvLabel].
const String kCreateWord = 'create';

/// See [kImportCsvLabel].
const String kUpdateWord = 'update';

/// See [kImportCsvLabel].
const String kUnchangedWord = 'unchanged';

/// See [kImportCsvLabel].
const String kSkippedWord = 'skipped';
