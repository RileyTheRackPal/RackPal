// `Ctrl+R`, docs/06 §4.6: *"Re-applies a label pattern to the selection in
// current display order."* M4-F7, board `#697`.
//
// ═══════════════════════════════════════════════════════════════════════
// IT SHARES M4-H's ENGINE AND MUST NOT FORK IT
// ═══════════════════════════════════════════════════════════════════════
// `label_pattern.dart` already parses the six tokens, expands them per row
// and produces the designed parse errors with their repair chips. A second
// pattern parser living in a renumber dialog is the defect this project
// has a practice about, so this file takes a COMPILED `LabelPattern` and
// owns no grammar at all: the dialog parses, shows the failure where the
// person is typing, and only reaches here once there is something to run.
//
// ═══════════════════════════════════════════════════════════════════════
// WHY THIS IS NOT `Ctrl+Shift+D` WITH EXTRA STEPS
// ═══════════════════════════════════════════════════════════════════════
// `Fill series` (DR-062) INFERS a sequence from the top cell, because
// there is no stored pattern to re-apply. `Renumber…` takes a pattern the
// person types now. The two are different acts on the same rows: one
// continues what is there, one replaces it with something stated.
//
// ═══════════════════════════════════════════════════════════════════════
// "CURRENT DISPLAY ORDER" IS LOAD-BEARING, AND ONLY UNDER A SORT
// ═══════════════════════════════════════════════════════════════════════
// M4-F5's sort is view-only, so display order and declared order are the
// same thing until a sort badge is showing, and different while it is.
// §4.6 says DISPLAY order, so that is what this takes, and it does NOT
// refuse under a sort the way `Duplicate` does: duplicate mints `order`
// and is therefore a claim about the declared sequence, while renumber
// writes labels onto rows the person can see and point at. **The dialog
// says which order it is about** rather than this file guessing that the
// caller got it right.
//
// LABELS ONLY, NEVER KEYS. `PortDef.key` follows the label for ports
// created this session (M4-E2), and that rule lives in the grid's cell
// path where the session's `touched` set is. A bulk renumber that also
// rewrote keys would be `Find & replace`'s dangerous scope (M4-F8, CR-051)
// arriving by the back door, on a gesture whose dialog never mentioned it.
import 'package:rackpal_core/src/builder/label_pattern.dart';
import 'package:rackpal_core/src/builder/port_commands.dart';
import 'package:rackpal_core/src/builder/port_impact.dart';
import 'package:rackpal_core/src/commands/command.dart';
import 'package:rackpal_core/src/model/template.dart';

/// Why a renumber produced nothing.
enum PortRenumberRefusal {
  /// Nothing is selected, so there are no rows to number.
  nothingSelected,
}

/// One line of prose per refusal.
String portRenumberRefusalMessage(PortRenumberRefusal refusal) =>
    switch (refusal) {
      PortRenumberRefusal.nothingSelected =>
        'Select the ports to renumber first.',
    };

/// What a renumber produced.
final class PortRenumberResult {
  const PortRenumberResult.commands(this.commands) : refusal = null;
  const PortRenumberResult.refused(PortRenumberRefusal this.refusal)
    : commands = const [];

  final List<Command<TemplateBody>> commands;
  final PortRenumberRefusal? refusal;

  bool get isRefused => refusal != null;
}

/// What [pattern] would write over [selectedInOrder], row by row.
///
/// A PREVIEW, NOT A PLAN, and it shares `PortImpactRow` with the two
/// dialogs DR-078 §11.77.3 requires one of. Renumber is not one of those
/// two: it cannot lose a published key and it cannot overwrite a named
/// value. It shows a list anyway because a pattern is easy to get wrong
/// and cheap to show, and because a `{n}` seeded from the wrong start is
/// invisible until sixteen rows later.
///
/// NO ROW CARRIES A `note`. There is nothing a renumber does to a row
/// besides what the `after` column already says.
///
/// Pure, and the same walk [buildPortRenumber] makes, so the preview and
/// the write cannot disagree about what the third row gets.
List<PortImpactRow> previewPortRenumber({
  required TemplateBody body,
  required List<String> selectedInOrder,
  required LabelPattern pattern,
  int start = 1,
  int step = 1,
}) {
  final byKey = {for (final port in body.ports) port.key.v: port};
  final rows = [
    for (final key in selectedInOrder)
      if (byKey[key] case final PortDef port) port,
  ];
  final labels = pattern.expandAll(rows.length, start: start, step: step);
  return [
    for (var i = 0; i < rows.length; i++)
      (
        key: rows[i].key.v,
        before: rows[i].label,
        after: labels[i],
        note: null,
      ),
  ];
}

/// `Ctrl+R`: write [pattern] across [selectedInOrder].
///
/// [selectedInOrder] is the selection in DISPLAY order, which is the whole
/// of §4.6's phrase: under a view-only sort the person is numbering what
/// they can see.
///
/// [start] and [step] seed `{n}` and `{n@k}`, exactly as they do for a
/// Quick Add, so a person can renumber a bank from 9 without editing the
/// pattern to say so.
PortRenumberResult buildPortRenumber({
  required TemplateBody body,
  required List<String> selectedInOrder,
  required LabelPattern pattern,
  int start = 1,
  int step = 1,
}) {
  final preview = previewPortRenumber(
    body: body,
    selectedInOrder: selectedInOrder,
    pattern: pattern,
    start: start,
    step: step,
  );
  if (preview.isEmpty) {
    return const PortRenumberResult.refused(
      PortRenumberRefusal.nothingSelected,
    );
  }

  final byKey = {for (final port in body.ports) port.key.v: port};
  return PortRenumberResult.commands([
    for (final row in preview)
      // A ROW ALREADY HOLDING ITS NEW LABEL IS NOT WRITTEN. Renumbering a
      // bank that is already numbered that way is a no-op, and an undo
      // entry that changes nothing is one the user presses Ctrl+Z through
      // twice. Same guard, same reason, as `buildPortReorder`'s.
      if (row.before != row.after)
        SetPortFieldCommand<String>(
          port: byKey[row.key]!.key,
          field: PortDefField.label,
          from: row.before,
          to: row.after,
        ),
  ]);
}
