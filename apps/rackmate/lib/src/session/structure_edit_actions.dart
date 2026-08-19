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

  final commands = <Command<RackDocument>>[];

  // WHAT THIS BATCH HAS ALREADY SPENT. Seeded empty and grown as the
  // batch is planned, so edit five is checked against the four before it
  // as well as against the document.
  final claimedLabels = <String>{};
  final claimedRackLabels = <String>{};

  // THE FOURTH RUNNING RESERVATION, and the one that makes `LANDS ON`
  // batchable (DR-071 §11.70.2). Landing forty-six drops on PP-1 is ONE
  // value across forty-six rows and forty-six DIFFERENT positions, so
  // each edit has to see the holes its siblings took. `@panel=` already
  // works this way through `freePanelPositions(alsoClaimed:)`; this is
  // the same reservation on the same walk.
  final claimedPorts = <Uuid>{};

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
      //
      // AND IT IS THE ONE ORIGIN FIELD THAT DOES NOT GO THROUGH `_origin`
      // (DR-074 §11.73.2). This cell is the only write path allowed to say
      // a PERSON named the hole, so it runs `SetRackLabelCommand`, which
      // carries the lock beside the label in one undo entry.
      StructureColumnId.rackLabel => _rackLabel(
        controller: controller,
        edit: edit,
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
      StructureColumnId.fieldTerm => _termination(
        controller: controller,
        edit: edit,
        field: StructureOriginField.terminationField,
        end: 'field',
        into: commands,
      ),
      // THE RACK END, WHICH THIS SWITCH DID NOT HAVE (`#711`). DR-046
      // §11.45.4 split one termination field into two, and four of the
      // five places that had to know were updated: the column is
      // editable, it is in the default eight, it offers the full menu,
      // and `StructureOriginField.terminationRack` exists. This arm did
      // not, so every pick fell to the catch-all below and the enabled
      // dropdown refused itself on every line, with a sentence written
      // for a text box.
      StructureColumnId.rackTerm => _termination(
        controller: controller,
        edit: edit,
        field: StructureOriginField.terminationRack,
        end: 'rack',
        into: commands,
      ),
      StructureColumnId.testResult => _testResult(
        controller: controller,
        edit: edit,
        into: commands,
      ),
      StructureColumnId.service => _signalFamily(
        controller: controller,
        edit: edit,
        into: commands,
      ),
      StructureColumnId.certificateId => _certificateId(
        controller: controller,
        edit: edit,
        into: commands,
      ),
      StructureColumnId.linkClass => _linkClass(
        controller: controller,
        edit: edit,
        into: commands,
      ),
      StructureColumnId.landing => _landing(
        controller: controller,
        edit: edit,
        claimedPorts: claimedPorts,
        claimedRackLabels: claimedRackLabels,
        into: commands,
      ),

      // ── the other two lengths (AC-024, M3-D/2) ─────────────────────
      // THE SAME PARSER THE AS-BUILT LENGTH USES, deliberately. Three
      // columns that each decided what `62.5` means would be three
      // rules; this is one rule read three times, and the refusal a
      // person sees is identical whichever of the three they typed in.
      StructureColumnId.routedLength => _parsed<Len>(
        controller: controller,
        edit: edit,
        field: LinkField.routedLength,
        parse: parseLengthCell(
          edit.value,
          controller.doc.settings.displayUnits,
        ),
        into: commands,
      ),
      StructureColumnId.cutLength => _parsed<Len>(
        controller: controller,
        edit: edit,
        field: LinkField.cutLength,
        parse: parseLengthCell(
          edit.value,
          controller.doc.settings.displayUnits,
        ),
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
  required List<Command<RackDocument>> into,
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

/// `RACK LBL`: the one cell that records WHO named the hole (DR-074
/// §11.73.2).
///
/// Every other `StructureOrigin` field goes through [_origin] and its
/// generic command. This one does not, because it writes a second piece of
/// state: `rackLabelLocked`, which is what makes a person's label survive
/// a move while an allocated one is re-derived. `SetEntityPropertyCommand`
/// writes exactly one declared field, so the pair needs its own command,
/// which is `SetLinkClassCommand`'s precedent for the same shape.
///
/// THE CLAIMED SET IS FED THE NORMALISED VALUE, not `edit.value`, so a
/// batch whose second row types the same label with a trailing space is
/// caught by the same scan rather than by the file.
String? _rackLabel({
  required DocumentController controller,
  required StructureCellEdit edit,
  required Set<String> claimedRackLabels,
  required List<Command<RackDocument>> into,
}) {
  final result = buildSetRackLabel(
    doc: controller.doc,
    linkId: edit.linkId,
    to: edit.value,
    now: controller.clock.nowUtc(),
    actor: controller.actor,
    alsoUsedRackLabels: claimedRackLabels,
  );
  switch (result) {
    case SetRackLabelRefused(:final reason):
      return reason;
    // NOTHING TO DO IS NOT A FAILURE — see [_origin].
    case SetRackLabelUnchanged():
      return null;
    case SetRackLabelReady(:final command):
      into.add(command);
      if (command.rackLabel case final claimed?) {
        claimedRackLabels.add(claimed);
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
  required List<Command<RackDocument>> into,
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
  required List<Command<RackDocument>> into,
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

/// `FIELD TERM` or `RACK TERM`, from the label back to the enum.
///
/// ONE ARM FOR BOTH ENDS, which is DR-046 §11.45.4's own words: "a
/// termination is a termination; the end it is on is which column it sits
/// in". `structureCellChoices` already offers the two columns the
/// identical menu for that reason, and this is the same statement on the
/// write side. Two copies is how the rack end came to have a dropdown, a
/// menu, an editable flag and a field with nothing behind it (`#711`).
///
/// THE UNKNOWN OPTION CLEARS IT, and that is why the field is nullable at
/// all: M3-J/1 made `StructureOrigin.terminationField` nullable because
/// `unterminated` is a DECISION (a coil left deliberately bare) and a
/// drop at rough-in has no answer. A control that could not go back to
/// unknown would make the second state unreachable once anybody guessed.
///
/// [end] is the word the refusal uses, so a person who typed into the
/// wrong column is told which one answered.
String? _termination({
  required DocumentController controller,
  required StructureCellEdit edit,
  required EntityField<Link, TerminationType?> field,
  required String end,
  required List<Command<RackDocument>> into,
}) {
  final wanted = edit.value.trim().toUpperCase();
  TerminationType? value;
  if (wanted.isNotEmpty && wanted != kUnknownCell) {
    value = TerminationType.values
        .where((t) => terminationLabel(t) == wanted)
        .firstOrNull;
    if (value == null) {
      return '"${edit.value}" is not a $end termination. Use one of: '
          '${TerminationType.values.map(terminationLabel).join(', ')}.';
    }
  }
  final result = buildSetStructureOriginProperty<TerminationType?>(
    doc: controller.doc,
    linkId: edit.linkId,
    field: field,
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

/// `SERVICE`, the signal family (DR-025 §11.24.5, board #587).
///
/// **IT RESOLVES THROUGH CORE AND SPELLS NOTHING ITSELF.**
/// `resolveSignalFamilyCell` is the inverse of the function that built
/// the menu, so the picker, the cell and this arm cannot disagree about
/// what `VID·HDBaseT (5Play)` means. The neighbouring termination arm
/// compares against `terminationLabel` for the same reason.
///
/// That spelling is worth getting right in a comment: this file's first
/// draft wrote `V·HDBaseT 5Play`, which is the shape canon §11.24.1's
/// PROSE uses and which the catalog spells nowhere. The tests that
/// hardcoded it failed for a reason that had nothing to do with the
/// picker.
///
/// **NO EMPTY-CLEARS-IT BRANCH, unlike the termination arms.** A
/// `Service` always has a family and `structure.undetermined` is an
/// ordinary row in the menu, so there is nothing to clear TO: an empty
/// string is a refusal rather than a null write (G4 draws the line at
/// whether an absence is a real state, and here it is not).
///
/// **THE REFUSAL LISTS NOTHING.** Its neighbour can name all nine
/// terminations in a sentence; there are 55 families, and a refusal that
/// printed them would be a wall a person scrolls past. The picker is the
/// list, which is why this column is a closed set rather than a text box.
String? _signalFamily({
  required DocumentController controller,
  required StructureCellEdit edit,
  required List<Command<RackDocument>> into,
}) {
  final family = resolveSignalFamilyCell(
    controller.doc.registries,
    edit.value,
  );
  if (family == null) {
    return '"${edit.value}" is not a signal family. Choose one from the '
        'list; families come from the catalog and cannot be created here.';
  }
  final result = buildSetSignalFamily(
    doc: controller.doc,
    linkId: edit.linkId,
    family: family,
    now: controller.clock.nowUtc(),
    actor: controller.actor,
  );
  return switch (result) {
    SetSignalFamilyRefused(:final reason) => reason,
    SetSignalFamilyReady(:final command) => () {
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
  required List<Command<RackDocument>> into,
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
  required List<Command<RackDocument>> into,
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

/// `CLASS`, which is the only column here whose two answers are two
/// different COMMANDS rather than two values (DR-067 §11.66, DR-008
/// §11.8.2).
///
/// `AUTO` is not a class and never lands in `Link.linkClass`. It drops
/// the pin and hands the run back to the classifier, which is
/// `ClearLinkClassOverrideCommand`'s whole job; folding it into the
/// setter as a nullable would give one gesture two opposite meanings, and
/// `link_class_commands.dart`'s header says why the two are separate.
///
/// NEITHER ARM CONSULTS THE CLASSIFIER, deliberately. An assertion that
/// happens to agree with the classifier today is still an assertion, and
/// quietly declining to pin it because it matches would drop the person's
/// word the next time the document moved. That is the same reason
/// `SetLinkClassCommand` sets both fields rather than one.
///
/// NOTHING TO DO IS CHECKED HERE, because neither command builder does
/// it: setting a class a link already holds AND is already pinned to
/// would otherwise cost an undo step that changes nothing, which is the
/// state a fill-down over an already-classified column lands in.
String? _linkClass({
  required DocumentController controller,
  required StructureCellEdit edit,
  required List<Command<RackDocument>> into,
}) {
  final link = controller.doc.links[edit.linkId];
  if (link == null) return 'That cable is not in this project.';
  final wanted = edit.value.trim().toUpperCase();

  if (wanted == kLinkClassAutoCell) {
    if (!link.linkClassLocked) return null;
    into.add(ClearLinkClassOverrideCommand(linkId: edit.linkId));
    return null;
  }

  final value = resolveLinkClassCell(edit.value);
  if (value == null) {
    return '"${edit.value}" is not a class. Use one of: '
        '$kLinkClassAutoCell, '
        '${LinkClass.values.map(linkClassLabel).join(', ')}.';
  }
  if (link.linkClassLocked && link.linkClass == value) return null;
  into.add(SetLinkClassCommand(linkId: edit.linkId, linkClass: value));
  return null;
}

/// `LANDS ON`: punch this drop down onto the next free position of the
/// panel named by [StructureCellEdit.value] (DR-071 §11.70).
///
/// THE VALUE IS A PANEL AND THE COMMAND NEEDS A POSITION, which is what
/// makes this the one column whose cell is a GESTURE rather than a value.
/// `@panel=` has allocated positions this way since M3-K/2 and this is
/// the same allocation reached by pointer: which hole a drop goes in is
/// the product's job, and a person landing forty-six of them should not
/// have to type forty-six numbers.
///
/// THE RACK LABEL RIDES WITH THE BIND, through `resolveRackLabel`, for
/// DR-040 §11.39.3's reason: the label is DERIVED from the position, so
/// the moment the position is known is the only moment it can be
/// allocated. A label that cannot render does not undo the punchdown
/// (§11.39.5) — the pin is a physical fact and the name is not.
String? _landing({
  required DocumentController controller,
  required StructureCellEdit edit,
  required Set<Uuid> claimedPorts,
  required Set<String> claimedRackLabels,
  required List<Command<RackDocument>> into,
}) {
  final wanted = edit.value.trim();
  if (wanted.isEmpty) {
    // NOT AN UNLAND. DR-040 §11.39.6 leaves moving a drop off a jack it
    // is punched into unruled, so an empty value is a person clearing a
    // box rather than an instruction this can carry out.
    return 'Clearing this cell would unland the drop, and moving a drop '
        'off a port is not something this can do yet.';
  }

  final doc = controller.doc;
  final panel = doc.devices.values
      .where((d) => d.designator.trim().toLowerCase() == wanted.toLowerCase())
      .firstOrNull;
  if (panel == null) {
    return 'No device in this project is called "$wanted".';
  }

  final free = freePanelPositions(
    doc,
    panelDeviceId: panel.id,
    alsoClaimed: claimedPorts,
  );
  if (free.isEmpty) {
    // NAMES THE PANEL AND THE SHORTFALL, because the person is looking
    // at a selection of rows and needs to know whether to pick a bigger
    // panel or land fewer of them.
    return '${panel.designator} has no free position left, so that drop '
        'was not landed. Nothing in this batch was applied.';
  }

  final position = free.first;
  final resolved = resolveRackLabel(
    doc: doc,
    panelDeviceId: panel.id,
    // THE NUMBER ON THE PART, not the designator this product allocated
    // (DR-040 §11.39.8).
    portDesignator: position.positionToken,
    usedRackLabels: usedRackLabels(doc, alsoUsed: claimedRackLabels),
  );

  final built = buildBindEndpointCommand(
    doc: doc,
    linkId: edit.linkId,
    port: position.port,
    rackLabel: resolved.label,
    usedRackLabels: usedRackLabels(doc, alsoUsed: claimedRackLabels),
    now: controller.clock.nowUtc(),
    actor: controller.actor,
  );
  switch (built) {
    case BindEndpointRefused(:final reason):
      return reason;
    case BindEndpointReady(:final command):
      into.add(command);
      claimedPorts.add(position.port.portId);
      if (resolved.label case final l?) claimedRackLabels.add(l);
      return null;
  }
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
  required List<Command<RackDocument>> into,
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
