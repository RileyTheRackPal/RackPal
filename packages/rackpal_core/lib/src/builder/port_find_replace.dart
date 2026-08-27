// `Ctrl+H` `Find & replace`, docs/06 §4.6: *"Scoped to labels, keys,
// designators or notes; regex opt-in."* M4-F8, board `#698`, DR-078
// §11.77.3.
//
// ═══════════════════════════════════════════════════════════════════════
// KEYS ARE THE DANGEROUS SCOPE, AND THE DANGER LEAVES THIS DOCUMENT
// ═══════════════════════════════════════════════════════════════════════
// `PortDef.key` is the template migration join (CR-051) and is `final`, so
// replacing across keys is a `RenamePortKeyCommand` per row rather than a
// field write. **A key that was already published when the builder opened
// may have another project's cables resolving through it.** Undo covers
// the open document completely and cannot reach that, which is why DR-078
// §11.77.3 puts a per-row impact list in front of this and refuses the
// lighter "replace all, Ctrl+Z if it looks wrong" story.
//
// So a published key's row carries a `note` saying so, and the rename
// records a `renamedFrom` alias for it (that is exactly what the alias is
// FOR). An unpublished key, invented in this session, records nothing:
// putting a working title in the file permanently would be noise in every
// future diff.
//
// ═══════════════════════════════════════════════════════════════════════
// REGEX IS OPT-IN, WHICH MEANS THE DEFAULT IS LITERAL
// ═══════════════════════════════════════════════════════════════════════
// §4.6's own word. An installer typing `HDMI (1)` into a replace box that
// was silently a regex gets a capture group and no match, and finds out on
// row forty. Literal is the default and the box says which mode it is in.
//
// A BAD PATTERN IS A REFUSAL, NOT A CRASH. `RegExp` throws on an
// unbalanced bracket, and this is a surface a person types into, so the
// throw is caught here and returned as a refusal a dialog can print.
//
// ═══════════════════════════════════════════════════════════════════════
// IT REPLACES EVERY OCCURRENCE IN A CELL, AND ONLY IN THE SELECTION
// ═══════════════════════════════════════════════════════════════════════
// `IN` to `OUT` over `IN 1 IN 2` gives `OUT 1 OUT 2`, which is what every
// find and replace anybody has used does. The SELECTION is the reach:
// §4.6's fourteen operations all act on the selection, and a dialog that
// quietly touched the whole template would be the one that does not.
import 'package:rackpal_core/src/builder/port_commands.dart';
import 'package:rackpal_core/src/builder/port_impact.dart';
import 'package:rackpal_core/src/commands/command.dart';
import 'package:rackpal_core/src/model/template.dart';
import 'package:rackpal_core/src/units/ids.dart' show PortKey;

/// Which text a find and replace reads and writes (docs/06 §4.6).
enum PortTextScope {
  label,
  key,
  designator,
  notes;

  /// What the dialog's scope control prints, matching the grid's own
  /// column headers so the two name the same thing.
  String get columnLabel => switch (this) {
    PortTextScope.label => 'LABEL',
    PortTextScope.key => 'KEY',
    PortTextScope.designator => 'DESIG',
    PortTextScope.notes => 'NOTES',
  };
}

/// Why a find and replace produced nothing.
enum PortFindReplaceRefusal {
  nothingSelected,

  /// The find box is empty. Replacing "nothing" with something would
  /// match at every character boundary, which is never what anybody meant.
  findIsEmpty,

  /// Regex mode with a pattern `RegExp` would not accept.
  patternIsNotValid,
}

/// One line of prose per refusal.
String portFindReplaceRefusalMessage(PortFindReplaceRefusal refusal) =>
    switch (refusal) {
      PortFindReplaceRefusal.nothingSelected =>
        'Select the ports to search first.',
      PortFindReplaceRefusal.findIsEmpty => 'Type what to find.',
      PortFindReplaceRefusal.patternIsNotValid =>
        'That is not a valid regular expression.',
    };

/// What a find and replace produced.
final class PortFindReplaceResult {
  const PortFindReplaceResult.commands(this.commands) : refusal = null;
  const PortFindReplaceResult.refused(PortFindReplaceRefusal this.refusal)
    : commands = const [];

  final List<Command<TemplateBody>> commands;
  final PortFindReplaceRefusal? refusal;

  bool get isRefused => refusal != null;
}

/// What the note says on a row whose key was already published.
const String kPublishedKeyNote =
    'published key: projects already using it join through renamedFrom';

/// What the note says on a row whose new key is taken.
const String kKeyCollisionNote = 'skipped: another port already has that key';

/// What the note says on a row whose new key would be empty.
const String kKeyEmptyNote = 'skipped: a port cannot have an empty key';

/// What the preview would do to each of [selectedInOrder], row by row.
///
/// [openedPortKeys] is the set of keys the template had when the builder
/// opened, which is what "published" means here and is the same set the
/// grid's own `KEY` cell consults. Ignored for every scope but
/// [PortTextScope.key].
///
/// Returns a refusal instead of rows when the inputs cannot produce any.
({List<PortImpactRow>? rows, PortFindReplaceRefusal? refusal})
previewPortFindReplace({
  required TemplateBody body,
  required List<String> selectedInOrder,
  required PortTextScope scope,
  required String find,
  required String replace,
  required Set<String> openedPortKeys,
  bool useRegex = false,
}) {
  if (find.isEmpty) {
    return (rows: null, refusal: PortFindReplaceRefusal.findIsEmpty);
  }
  final Pattern pattern;
  if (useRegex) {
    try {
      pattern = RegExp(find);
    } on FormatException {
      return (rows: null, refusal: PortFindReplaceRefusal.patternIsNotValid);
    }
  } else {
    pattern = find;
  }

  final byKey = {for (final port in body.ports) port.key.v: port};
  final rows = [
    for (final key in selectedInOrder)
      if (byKey[key] case final PortDef port) port,
  ];
  if (rows.isEmpty) {
    return (rows: null, refusal: PortFindReplaceRefusal.nothingSelected);
  }

  // EVERY KEY IN THE TEMPLATE, not only the selected ones: a rename
  // collides with a row nobody selected just as hard.
  final taken = {for (final port in body.ports) port.key.v};
  final minted = <String>{};

  return (
    rows: [
      for (final port in rows)
        () {
          final before = _read(port, scope) ?? '';
          final after = before.replaceAll(pattern, replace);
          return (
            key: port.key.v,
            before: before,
            after: after,
            note: scope == PortTextScope.key
                ? _keyNote(
                    port: port,
                    after: after,
                    changed: before != after,
                    taken: taken,
                    minted: minted,
                    openedPortKeys: openedPortKeys,
                  )
                : null,
          );
        }(),
    ],
    refusal: null,
  );
}

/// `Ctrl+H`: run the replacement the preview showed.
PortFindReplaceResult buildPortFindReplace({
  required TemplateBody body,
  required List<String> selectedInOrder,
  required PortTextScope scope,
  required String find,
  required String replace,
  required Set<String> openedPortKeys,
  bool useRegex = false,
}) {
  final preview = previewPortFindReplace(
    body: body,
    selectedInOrder: selectedInOrder,
    scope: scope,
    find: find,
    replace: replace,
    openedPortKeys: openedPortKeys,
    useRegex: useRegex,
  );
  if (preview.refusal case final PortFindReplaceRefusal refusal) {
    return PortFindReplaceResult.refused(refusal);
  }
  final rows = preview.rows!;
  final byKey = {for (final port in body.ports) port.key.v: port};

  return PortFindReplaceResult.commands([
    for (final row in rows)
      if (row.before != row.after)
        // A ROW THE PREVIEW MARKED AS SKIPPED IS SKIPPED HERE. The two
        // read the same note, so the list a person approved and the
        // commands that run cannot disagree about which rows moved.
        if (!_isSkipped(row))
          if (_command(byKey[row.key]!, scope, row.after, openedPortKeys)
              case final Command<TemplateBody> command)
            command,
  ]);
}

bool _isSkipped(PortImpactRow row) =>
    row.note == kKeyCollisionNote || row.note == kKeyEmptyNote;

String? _read(PortDef port, PortTextScope scope) => switch (scope) {
  PortTextScope.label => port.label,
  PortTextScope.key => port.key.v,
  PortTextScope.designator => port.designatorHint,
  PortTextScope.notes => port.notes,
};

Command<TemplateBody>? _command(
  PortDef port,
  PortTextScope scope,
  String after,
  Set<String> openedPortKeys,
) => switch (scope) {
  PortTextScope.label => SetPortFieldCommand<String>(
    port: port.key,
    field: PortDefField.label,
    from: port.label,
    to: after,
  ),
  // A CLEARED CELL IS AN UNKNOWN, NOT AN EMPTY STRING (G4). These two
  // columns are nullable, and replacing a designator hint away must leave
  // the port taking its designator from `PORT_SEQ` rather than pinning it
  // to the empty string.
  PortTextScope.designator => SetPortFieldCommand<String?>(
    port: port.key,
    field: PortDefField.designatorHint,
    from: port.designatorHint,
    to: after.isEmpty ? null : after,
  ),
  PortTextScope.notes => SetPortFieldCommand<String?>(
    port: port.key,
    field: PortDefField.notes,
    from: port.notes,
    to: after.isEmpty ? null : after,
  ),
  // THE ALIAS IS RECORDED ONLY FOR A KEY SOMEBODY ELSE MIGHT HOLD.
  // `RenamePortKeyCommand`'s own rule: a port invented ten seconds ago in
  // this session has never been in any project, so recording its working
  // title would be permanent noise in every future diff.
  PortTextScope.key => RenamePortKeyCommand(
    from: port.key,
    to: PortKey(after),
    recordAlias: openedPortKeys.contains(port.key.v),
  ),
};

String? _keyNote({
  required PortDef port,
  required String after,
  required bool changed,
  required Set<String> taken,
  required Set<String> minted,
  required Set<String> openedPortKeys,
}) {
  if (!changed) return null;
  if (after.isEmpty) return kKeyEmptyNote;
  // COLLIDES WITH A KEY THAT EXISTS, or with one an earlier row in this
  // same run is about to mint. `RenamePortKeyCommand` throws on either,
  // and a dialog must not hand it a command that will.
  if ((taken.contains(after) && after != port.key.v) ||
      minted.contains(after)) {
    return kKeyCollisionNote;
  }
  minted.add(after);
  return openedPortKeys.contains(port.key.v) ? kPublishedKeyNote : null;
}
