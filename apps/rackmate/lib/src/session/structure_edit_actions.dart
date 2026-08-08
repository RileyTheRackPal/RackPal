// What a typed cell in the Structure table MEANS. Board M3-C/2 (#148),
// docs/07 §4.1, AC-013.
//
// ═════════════════════════════════════════════════════════════════════
// THE TABLE DECIDES NOTHING, WHICH IS WHY THIS FILE IS SEPARATE
// ═════════════════════════════════════════════════════════════════════
// `StructureEditorScreen` hands over a list of (drop, column, text) and
// takes back a sentence or null. It does not know that a blank rack label
// means null rather than `''`, that a field label must be unique
// project-wide (CR-113), or how a `RoughInStatus` is spelled on the wire.
// Every one of those is a rule with a document behind it, and a surface
// holding a second copy of a rule is how two answers to one question
// start.
//
// ═════════════════════════════════════════════════════════════════════
// BUILD EVERYTHING, THEN RUN EVERYTHING, OR RUN NOTHING
// ═════════════════════════════════════════════════════════════════════
// A batch is planned in full before a single command is applied. That is
// what makes it all-or-nothing, and all-or-nothing is what makes a
// refusal actionable: a fill-down that wrote nine of ten rows and then
// said "row 10 collides" leaves a person to work out which nine moved.
//
// It is also the only way `alsoUsedLabels` can do its job.
// `buildSetStructureOriginProperty` takes those sets precisely because a
// batch checked one edit at a time against an unmutated document would
// let two rows agree on a label while each looked fine on its own.
import 'package:rackmate_core/rackmate_core.dart';
import 'package:rackmate_ui/rackmate_ui.dart';

/// Wires the Structure table's cells to a live [DocumentController].
StructureEditFn buildStructureEditAction({
  required DocumentController controller,
}) => (edits) {
  if (edits.isEmpty) return null;

  final commands = <Command>[];

  // WHAT THIS BATCH HAS ALREADY SPENT. Seeded empty and grown as the
  // batch is planned, so edit five is checked against the four before it
  // as well as against the document.
  final claimedLabels = <String>{};
  final claimedRackLabels = <String>{};

  for (final edit in edits) {
    final refusal = switch (edit.column) {
      StructureColumnId.fieldLabel => _origin(
        controller: controller,
        edit: edit,
        field: StructureOriginField.fieldLabel,
        to: edit.value.trim(),
        claimedLabels: claimedLabels,
        claimedRackLabels: claimedRackLabels,
        into: commands,
      ),
      // BLANK MEANS NULL, and the builder is what says so: "clearing the
      // box means I do not know where this lands, and `''` would be a
      // third state the schedule has to guess about" (G4). It is passed
      // through untrimmed-of-meaning rather than normalised here, so
      // there is one place that decides.
      StructureColumnId.rackLabel => _origin(
        controller: controller,
        edit: edit,
        field: StructureOriginField.rackLabel,
        to: edit.value,
        claimedLabels: claimedLabels,
        claimedRackLabels: claimedRackLabels,
        into: commands,
      ),
      StructureColumnId.roughIn => _roughIn(
        controller: controller,
        edit: edit,
        into: commands,
      ),
      StructureColumnId.notes => _plain(
        controller: controller,
        edit: edit,
        field: LinkField.notes,
        // Empty is UNKNOWN and lands as an absent key, never as `''`.
        // Same rule as the rack label, applied where no builder exists to
        // apply it for us.
        to: edit.value.trim().isEmpty ? null : edit.value.trim(),
        into: commands,
      ),

      // ── the as-built seven (DR-020 §11.19.2(5), M3-J/3) ────────────
      // EVERY PARSE IS CORE'S. `parseLengthCell` and its two siblings
      // live beside `structureCell` because what they enforce is CR-001,
      // integer nanometres, and because a surface holding a parsing rule
      // is a second copy of that rule.
      StructureColumnId.terminatedLength => _parsed<Len>(
        controller: controller,
        edit: edit,
        field: LinkField.terminatedLength,
        parse: parseLengthCell(
          edit.value,
          controller.doc.settings.displayUnits,
        ),
        into: commands,
      ),
      StructureColumnId.spliceCount => _parsed<int>(
        controller: controller,
        edit: edit,
        field: LinkField.spliceCount,
        parse: parseCountCell(edit.value),
        into: commands,
      ),
      StructureColumnId.terminatedAt => _parsed<DateTime>(
        controller: controller,
        edit: edit,
        field: LinkField.terminatedAt,
        parse: parseDateCell(edit.value),
        into: commands,
      ),
      StructureColumnId.installedBy => _plain(
        controller: controller,
        edit: edit,
        field: LinkField.installedBy,
        to: edit.value.trim().isEmpty ? null : edit.value.trim(),
        into: commands,
      ),
      StructureColumnId.fieldTerm => _fieldTermination(
        controller: controller,
        edit: edit,
        into: commands,
      ),
      StructureColumnId.testResult => _testResult(
        controller: controller,
        edit: edit,
        into: commands,
      ),
      StructureColumnId.certificateId => _certificateId(
        controller: controller,
        edit: edit,
        into: commands,
      ),

      _ => 'That column cannot be typed into.',
    };
    if (refusal != null) return refusal;
  }

  if (commands.isEmpty) return null;

  // ONE TRANSACTION, ONE UNDO ENTRY. See [LabelKey.fillCells] for why the
  // label depends on how many cells the gesture touched.
  controller.transact(
    edits.length == 1 ? LabelKey.setEntityProperty : LabelKey.fillCells,
    (tx) {
      for (final c in commands) {
        tx.add(c);
      }
    },
  );
  return null;
};

/// The signature `StructureEditorActions.onEdit` wants.
typedef StructureEditFn = String? Function(List<StructureCellEdit> edits);

/// A `StructureOrigin` field, through the builder that can refuse.
///
/// THE CLAIMED SETS ARE UPDATED ON SUCCESS ONLY, and with the value the
/// builder was given rather than a value read back off the document,
/// because nothing has been applied yet: the whole batch is still a list
/// of unrun commands.
String? _origin<T>({
  required DocumentController controller,
  required StructureCellEdit edit,
  required EntityField<Link, T> field,
  required T to,
  required Set<String> claimedLabels,
  required Set<String> claimedRackLabels,
  required List<Command> into,
}) {
  final result = buildSetStructureOriginProperty<T>(
    doc: controller.doc,
    linkId: edit.linkId,
    field: field,
    to: to,
    now: controller.clock.nowUtc(),
    actor: controller.actor,
    alsoUsedLabels: claimedLabels,
    alsoUsedRackLabels: claimedRackLabels,
  );
  switch (result) {
    case SetStructureOriginRefused(:final reason):
      return reason;
    // NOTHING TO DO IS NOT A FAILURE, and telling the two apart is what
    // `SetStructureOriginResult`'s third arm exists for. A fill-down over
    // a column where three rows already hold the value must apply the
    // other seven, not refuse.
    case SetStructureOriginUnchanged():
      return null;
    case SetStructureOriginReady(:final command):
      into.add(command);
      final claimed = (to as Object?)?.toString().trim() ?? '';
      if (claimed.isNotEmpty) {
        if (identical(field, StructureOriginField.fieldLabel)) {
          claimedLabels.add(claimed);
        } else {
          claimedRackLabels.add(claimed);
        }
      }
      return null;
  }
}

/// `ROUGH-IN`, from the label the table showed back to the enum.
///
/// IT READS `roughInLabel`, NOT `.name`. The surface sends what it
/// displayed, so there is one vocabulary and `roughInLabel` is its only
/// speller; matching on `.name` would work today and break silently the
/// first time a label stops being the enum name uppercased.
String? _roughIn({
  required DocumentController controller,
  required StructureCellEdit edit,
  required List<Command> into,
}) {
  final wanted = edit.value.trim().toUpperCase();
  final status = RoughInStatus.values
      .where((s) => roughInLabel(s) == wanted)
      .firstOrNull;
  if (status == null) {
    return '"${edit.value}" is not a rough-in status. Use one of: '
        '${RoughInStatus.values.map(roughInLabel).join(', ')}.';
  }
  return _plain(
    controller: controller,
    edit: edit,
    field: LinkField.roughInStatus,
    to: status,
    into: into,
  );
}

/// A column core knows how to read, written through the generic table.
///
/// THE REFUSAL IS CORE'S SENTENCE, verbatim. It already names the value
/// and the format ("this column is whole feet, so type a number and
/// nothing else"), and re-wording it here would give the same rule two
/// voices.
String? _parsed<T>({
  required DocumentController controller,
  required StructureCellEdit edit,
  required EntityField<Link, T?> field,
  required CellParse<T> parse,
  required List<Command> into,
}) => switch (parse) {
  CellRefused<T>(:final reason) => reason,
  CellParsed<T>(:final value) => _plain<T?>(
    controller: controller,
    edit: edit,
    field: field,
    to: value,
    into: into,
  ),
};

/// `FIELD TERM`, from the label back to the enum.
///
/// THE UNKNOWN OPTION CLEARS IT, and that is why the field is nullable at
/// all: M3-J/1 made `StructureOrigin.terminationField` nullable because
/// `unterminated` is a DECISION (a coil left deliberately bare) and a
/// drop at rough-in has no answer. A control that could not go back to
/// unknown would make the second state unreachable once anybody guessed.
String? _fieldTermination({
  required DocumentController controller,
  required StructureCellEdit edit,
  required List<Command> into,
}) {
  final wanted = edit.value.trim().toUpperCase();
  TerminationType? value;
  if (wanted.isNotEmpty && wanted != kUnknownCell) {
    value = TerminationType.values
        .where((t) => terminationLabel(t) == wanted)
        .firstOrNull;
    if (value == null) {
      return '"${edit.value}" is not a termination. Use one of: '
          '${TerminationType.values.map(terminationLabel).join(', ')}.';
    }
  }
  final result = buildSetStructureOriginProperty<TerminationType?>(
    doc: controller.doc,
    linkId: edit.linkId,
    field: StructureOriginField.terminationField,
    to: value,
    now: controller.clock.nowUtc(),
    actor: controller.actor,
  );
  return switch (result) {
    SetStructureOriginRefused(:final reason) => reason,
    SetStructureOriginUnchanged() => null,
    SetStructureOriginReady(:final command) => () {
      into.add(command);
      return null;
    }(),
  };
}

/// `TEST`, as the three states the column shows.
///
/// THE WHOLE `TestResult` IS REPLACED, never mutated: the command
/// captures the previous VALUE to undo with, so reaching into the stored
/// object and flipping `pass` would leave undo restoring the new one.
///
/// CLEARING IT TO UNKNOWN DISCARDS THE CERTIFICATE with it, and that is
/// the honest reading rather than a shortcut: a certificate id is the
/// identifier OF a result, and keeping one for a result that no longer
/// exists would be a reference to nothing. Undo takes it back.
String? _testResult({
  required DocumentController controller,
  required StructureCellEdit edit,
  required List<Command> into,
}) {
  final link = controller.doc.links[edit.linkId];
  if (link == null) return 'That cable is not in this project.';
  final wanted = edit.value.trim().toUpperCase();

  final TestResult? next;
  if (wanted.isEmpty || wanted == kUnknownCell) {
    next = null;
  } else if (wanted == kTestPassCell || wanted == kTestFailCell) {
    final previous = link.test;
    next = TestResult(
      pass: wanted == kTestPassCell,
      // CARRIED, not dropped: a run that failed and was re-tested keeps
      // the certificate and the headroom the tester recorded, because
      // changing the verdict is not the same act as re-certifying.
      headroom: previous?.headroom,
      certificateId: previous?.certificateId,
    );
  } else {
    return '"${edit.value}" is not a test result. Use '
        '$kTestPassCell, $kTestFailCell, or clear it for not tested.';
  }

  // NOTHING TO DO IS CHECKED HERE AND NOT BY THE COMMAND BUILDER, because
  // `TestResult` has no `operator ==` (no def in this model does). Without
  // this, filling `PASS` down a column that is already all `PASS` would
  // build sixty commands that each replace an object with an equal one,
  // and cost an undo step that visibly changes nothing.
  if (_sameResult(link.test, next)) return null;

  return _plain<TestResult?>(
    controller: controller,
    edit: edit,
    field: LinkField.test,
    to: next,
    into: into,
  );
}

/// Value equality for a type that has none. See [_testResult].
bool _sameResult(TestResult? a, TestResult? b) {
  if (a == null || b == null) return a == null && b == null;
  return a.pass == b.pass &&
      a.headroom == b.headroom &&
      a.certificateId == b.certificateId;
}

/// `CERT ID`, which only exists once there is a result to identify.
///
/// IT REFUSES ON A CABLE WITH NO TEST RESULT rather than inventing one.
/// `TestResult` requires `pass`, so accepting a certificate here would
/// mean writing a verdict nobody gave, on the one column whose whole
/// purpose is to be evidence (G4).
String? _certificateId({
  required DocumentController controller,
  required StructureCellEdit edit,
  required List<Command> into,
}) {
  final link = controller.doc.links[edit.linkId];
  if (link == null) return 'That cable is not in this project.';
  final previous = link.test;
  final trimmed = edit.value.trim();
  if (previous == null) {
    if (trimmed.isEmpty) return null;
    return 'Record the test result first: a certificate identifies a '
        'result, and this cable does not have one yet.';
  }
  final next = TestResult(
    pass: previous.pass,
    headroom: previous.headroom,
    certificateId: trimmed.isEmpty ? null : trimmed,
  );
  if (_sameResult(previous, next)) return null;
  return _plain<TestResult?>(
    controller: controller,
    edit: edit,
    field: LinkField.test,
    to: next,
    into: into,
  );
}

/// An ordinary `Link` field, through the generic table.
///
/// `buildSetEntityProperty` RETURNS NULL FOR "nothing to do", which is
/// not a refusal; there is nothing to add and nothing to report.
String? _plain<T>({
  required DocumentController controller,
  required StructureCellEdit edit,
  required EntityField<Link, T> field,
  required T to,
  required List<Command> into,
}) {
  if (!controller.doc.links.containsKey(edit.linkId)) {
    return 'That cable is not in this project.';
  }
  final command = buildSetEntityProperty<Link, T>(
    doc: controller.doc,
    id: edit.linkId,
    field: field,
    to: to,
    now: controller.clock.nowUtc(),
    actor: controller.actor,
  );
  if (command != null) into.add(command);
  return null;
}
