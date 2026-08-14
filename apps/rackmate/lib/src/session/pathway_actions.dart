// What the Pathways tab's gestures MEAN, in commands. Board M3-E/1
// (#156), docs/07 §4, CR-016, DR-031, DR-032.
//
// ═════════════════════════════════════════════════════════════════════
// A SIBLING OF `structure_edit_actions.dart`, NOT A BRANCH OF IT
// ═════════════════════════════════════════════════════════════════════
// The two tabs edit different ENTITIES. A `StructureCellEdit` carries a
// `Link`'s id and a `PathwayCellEdit` carries a `Pathway`'s, and both are
// `Uuid`. Folding them into one callback would put two entity types
// behind one identifier and leave this file to work out which it had been
// handed from the column — which is the mistake that only shows up on the
// day somebody adds a column to the wrong enum.
//
// ═════════════════════════════════════════════════════════════════════
// THE VOCABULARY IS CORE'S, READ BACK THE WAY IT WAS WRITTEN
// ═════════════════════════════════════════════════════════════════════
// `KIND` matches on `pathwayKindLabel` and not on `.name`, which is
// `_roughIn`'s rule in the sibling file: the surface sends what it
// DISPLAYED, so core's speller stays the only one. Matching `.name` would
// work today and break silently the first time a label stops being the
// enum name uppercased — `directBury` already prints `DIRECT BURY`, so
// that day has in fact already happened.
//
// ═════════════════════════════════════════════════════════════════════
// NO CODE RULE IS IMPLEMENTED HERE, AND THAT IS DELIBERATE
// ═════════════════════════════════════════════════════════════════════
// `containsLineVoltage` and `kind` are what M5's `CODE-001` and
// `CODE-002` read (NEC 800.154). Setting a pathway to `plenumSpace` with
// line voltage in it is accepted without a word, because canon §5 says a
// rule not listed does not exist and a tier-2 rule built here as a
// tier-1 refusal would make the product unable to draw a mistake (G2,
// CR-017). M5 is where it fires; this is where the fact is entered.
import 'package:rackmate_core/rackmate_core.dart';
import 'package:rackmate_ui/rackmate_ui.dart';

/// The signature `StructureEditorActions.onEditPathways` wants.
typedef PathwayEditFn = String? Function(List<PathwayCellEdit> edits);

/// The signature `StructureEditorActions.onAddPathway` wants.
typedef PathwayAddFn = String? Function();

/// The signature `StructureEditorActions.onRemovePathway` wants.
typedef PathwayRemoveFn = String? Function(Uuid id);

/// Wires the Pathways tab's cells to a live [DocumentController].
///
/// BUILD EVERYTHING, THEN RUN EVERYTHING, OR RUN NOTHING —
/// `buildStructureEditAction`'s rule, kept even though nothing sends more
/// than one edit today. A batch planned in full before anything is
/// applied is what makes a refusal actionable, and adopting the shape now
/// costs nothing where retrofitting it later means revisiting every arm.
PathwayEditFn buildPathwayEditAction({
  required DocumentController controller,
}) => (edits) {
  if (edits.isEmpty) return null;

  final commands = <Command<RackDocument>>[];
  for (final edit in edits) {
    if (!controller.doc.pathways.containsKey(edit.pathwayId)) {
      return 'That pathway is not in this project.';
    }
    final refusal = switch (edit.column) {
      PathwayColumnId.designator => _designator(
        controller: controller,
        edit: edit,
        into: commands,
      ),
      PathwayColumnId.name => _name(
        controller: controller,
        edit: edit,
        into: commands,
      ),
      PathwayColumnId.kind => _kind(
        controller: controller,
        edit: edit,
        into: commands,
      ),
      PathwayColumnId.lineVoltage => _lineVoltage(
        controller: controller,
        edit: edit,
        into: commands,
      ),
      PathwayColumnId.media => _media(
        controller: controller,
        edit: edit,
        into: commands,
      ),
      PathwayColumnId.nominalLength => _parsed<Len>(
        controller: controller,
        edit: edit,
        field: PathwayField.nominalLength,
        parse: parseLengthCell(
          edit.value,
          controller.doc.settings.displayUnits,
        ),
        into: commands,
      ),
      PathwayColumnId.notes => _plain<String?>(
        controller: controller,
        edit: edit,
        field: PathwayField.notes,
        // Empty is UNKNOWN and lands as an absent key, never as `''`
        // (G4, CR-114). Same rule the drop table's notes column takes.
        to: edit.value.trim().isEmpty ? null : edit.value.trim(),
        into: commands,
      ),
      // The derived column. `pathwayColumnIsEditable` already refuses to
      // render a control over it, so this arm is reachable only from a
      // caller that built an edit by hand.
      PathwayColumnId.runs => kRunsIsDerived,
    };
    if (refusal != null) return refusal;
  }

  if (commands.isEmpty) return null;
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

/// Wires `+ Add pathway` to [controller].
///
/// IT NAMES THE PATHWAY AND DOES NOT ASK. `Pathway.name` is required, so
/// something has to supply one, and a dialog before the row exists is a
/// modal in front of a list a person is scanning. The placeholder is
/// visibly a placeholder and the NAME cell is the first thing in the row,
/// already focusable and already editable — which is `AddLocationCommand`'s
/// shape for a new room.
///
/// **NOT DR-032'S NAME, AND THE DIFFERENCE IS THE INPUT.** §11.31.1 names
/// a pathway from the location and the medium the user TYPED; this gesture
/// has neither, because the person clicked a button on a list. Inventing
/// `Living Room ENT` here would put a room and a conduit type into a
/// record where nobody stated either.
PathwayAddFn buildPathwayAddAction({
  required DocumentController controller,
}) => () {
  controller.transact(LabelKey.addPathway, (tx) {
    tx.add(
      AddPathwayCommand(
        name: kNewPathwayName,
        order: nextPathwayOrder(controller.doc),
        now: controller.clock.nowUtc(),
        actor: controller.actor,
      ),
    );
  });
  return null;
};

/// Wires the row's delete to [controller].
///
/// NOT A CASCADE, and the command is where that is decided:
/// `RemovePathwayCommand` clears `Link.pathwayId` on every run through
/// the pathway rather than deleting the cable, because a cable whose
/// conduit is gone is still a cable — it is a run whose route nobody has
/// recorded, which is the state every drop in this product was in until
/// `bcb1b31`.
///
/// NO CONFIRMATION DIALOG, and that is the undo stack being trusted. The
/// tooltip states the consequence and the run count before the click, the
/// whole act is one transaction, and `Ctrl+Z` restores the pathway AND
/// every `pathwayId` it cleared. A dialog would buy a second click and
/// would not buy a stronger guarantee than that.
PathwayRemoveFn buildPathwayRemoveAction({
  required DocumentController controller,
}) => (id) {
  if (!controller.doc.pathways.containsKey(id)) {
    return 'That pathway is not in this project.';
  }
  controller.transact(LabelKey.removePathway, (tx) {
    tx.add(RemovePathwayCommand(id: id, now: controller.clock.nowUtc()));
  });
  return null;
};

/// `PATHWAY`, which is a required field and so cannot be cleared.
///
/// IT REFUSES A BLANK rather than storing `''`. Every other text column in
/// this product treats empty as UNKNOWN, and that reading is unavailable
/// here: `Pathway.name` is non-nullable, so there is no absent state to
/// land in, and an empty name would print as the unknown dash in the
/// Pull Sheet's `PATH` column on every run through it — indistinguishable
/// from a cable nobody routed (G4).
/// `DESIGNATOR`, through the ONE builder that can refuse.
///
/// NOT `_plain`, and this is the whole point of the arm. DR-026 §11.25.1
/// makes the designator unique where set, project-wide, and `_plain`
/// drives `buildSetEntityProperty`, which writes the value and returns
/// with no way to decline. Two trunks called `T1` on one Pull Sheet is
/// the defect the column exists to prevent, and it would arrive silently
/// through the ordinary edit path.
///
/// `buildSetPathwayDesignator` also owns the blank-is-null rule, so this
/// arm passes `edit.value` through untouched rather than trimming here
/// and disagreeing with core about what an empty box means.
String? _designator({
  required DocumentController controller,
  required PathwayCellEdit edit,
  required List<Command<RackDocument>> into,
}) {
  final result = buildSetPathwayDesignator(
    doc: controller.doc,
    pathwayId: edit.pathwayId,
    to: edit.value,
    now: controller.clock.nowUtc(),
    actor: controller.actor,
  );
  return switch (result) {
    SetPathwayDesignatorReady(:final command) => () {
      into.add(command);
      return null;
    }(),
    // Nothing to do is not a refusal; docs/04 §3.4 is about telling those
    // two apart, and collapsing them here would put a false error in
    // front of somebody who retyped a value.
    SetPathwayDesignatorUnchanged() => null,
    SetPathwayDesignatorRefused(:final reason) => reason,
  };
}

String? _name({
  required DocumentController controller,
  required PathwayCellEdit edit,
  required List<Command<RackDocument>> into,
}) {
  final trimmed = edit.value.trim();
  if (trimmed.isEmpty) return kPathwayNeedsAName;
  return _plain<String>(
    controller: controller,
    edit: edit,
    field: PathwayField.name,
    to: trimmed,
    into: into,
  );
}

/// `KIND`, from the label the tab showed back to the enum (DR-031).
String? _kind({
  required DocumentController controller,
  required PathwayCellEdit edit,
  required List<Command<RackDocument>> into,
}) {
  final wanted = edit.value.trim().toUpperCase();
  final kind = PathwayKind.values
      .where((k) => pathwayKindLabel(k) == wanted)
      .firstOrNull;
  if (kind == null) {
    return '"${edit.value}" is not a pathway kind. Use one of: '
        '${PathwayKind.values.map(pathwayKindLabel).join(', ')}.';
  }
  return _plain<PathwayKind>(
    controller: controller,
    edit: edit,
    field: PathwayField.kind,
    to: kind,
    into: into,
  );
}

/// `LINE VOLTAGE`, as the two words the cell prints.
///
/// TWO OPTIONS AND NOT THREE. `containsLineVoltage` is a `bool` and not a
/// `bool?`, which is a real asymmetry against G4 and is the model's
/// choice rather than this file's: `false` means "no line voltage
/// declared", and an M5 rule that fired on unknown would fire on every
/// pathway nobody had answered for. `Pathway.containsLineVoltage` records
/// what widening it would take.
String? _lineVoltage({
  required DocumentController controller,
  required PathwayCellEdit edit,
  required List<Command<RackDocument>> into,
}) {
  final wanted = edit.value.trim().toUpperCase();
  final bool value;
  if (wanted == kLineVoltageYesCell) {
    value = true;
  } else if (wanted == kLineVoltageNoCell) {
    value = false;
  } else {
    return '"${edit.value}" is not an answer for line voltage. Use '
        '$kLineVoltageYesCell or $kLineVoltageNoCell.';
  }
  return _plain<bool>(
    controller: controller,
    edit: edit,
    field: PathwayField.containsLineVoltage,
    to: value,
    into: into,
  );
}

/// `MEDIA`, from the registry's `displayName` back to the id (CR-109).
///
/// IT RESOLVES AGAINST `isPathwayOnly` TYPES ONLY, which is the whole
/// point of the flag: accepting `Cat6` here would record that a conduit
/// is a cable, and CR-109's rejected alternative is exactly *"conduit as
/// a connectable drop like any other"*.
///
/// THE UNKNOWN DASH CLEARS IT. Nobody has to say which conduit a pathway
/// is, and a control that could not go back to unknown would make that
/// state unreachable after the first guess (G4).
///
/// A DANGLING ID IS LEFT WHERE IT IS. The tab adds an unresolvable stored
/// id to its own option list so the document can be read; selecting it
/// again is a no-op, and `buildSetEntityProperty` returns null for
/// nothing-to-do rather than refusing.
String? _media({
  required DocumentController controller,
  required PathwayCellEdit edit,
  required List<Command<RackDocument>> into,
}) {
  final wanted = edit.value.trim();
  if (wanted.isEmpty || wanted == kUnknownCell) {
    return _plain<MediaTypeId?>(
      controller: controller,
      edit: edit,
      field: PathwayField.pathwayMedia,
      to: null,
      into: into,
    );
  }

  final registry = controller.doc.registries.mediaTypes;
  final match = registry.values
      .where((d) => d.isPathwayOnly && d.displayName == wanted)
      .firstOrNull;
  if (match == null) {
    // The dangling case: the label IS the stored id, because that is what
    // `pathwayCell` printed when the registry could not resolve it.
    if (controller.doc.pathways[edit.pathwayId]?.pathwayMedia?.v == wanted) {
      return null;
    }
    return '"$wanted" is not a pathway medium this project carries. A '
        'pathway is a conduit, a J-hook run or a tray, so only media '
        'marked as pathway-only can go in this column.';
  }
  return _plain<MediaTypeId?>(
    controller: controller,
    edit: edit,
    field: PathwayField.pathwayMedia,
    to: match.id,
    into: into,
  );
}

/// A column core knows how to read. THE REFUSAL IS CORE'S SENTENCE,
/// verbatim: it already names the value and the format, and re-wording it
/// here would give one rule two voices.
String? _parsed<T>({
  required DocumentController controller,
  required PathwayCellEdit edit,
  required EntityField<Pathway, T?> field,
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

/// An ordinary `Pathway` field, through the generic accessor table.
///
/// `buildSetEntityProperty` RETURNS NULL FOR "nothing to do", which is not
/// a refusal: there is nothing to add and nothing to report.
String? _plain<T>({
  required DocumentController controller,
  required PathwayCellEdit edit,
  required EntityField<Pathway, T> field,
  required T to,
  required List<Command<RackDocument>> into,
}) {
  final command = buildSetEntityProperty<Pathway, T>(
    doc: controller.doc,
    id: edit.pathwayId,
    field: field,
    to: to,
    now: controller.clock.nowUtc(),
    actor: controller.actor,
  );
  if (command != null) into.add(command);
  return null;
}

/// What a new pathway is called until somebody names it.
///
/// VISIBLY A PLACEHOLDER. `Pathway 1` would read as an allocated series
/// and is the shape DR-026 §11.25.1 refused for the designator; this is a
/// sentence nobody will mistake for a record.
const String kNewPathwayName = 'New pathway';

/// Why a blank `PATHWAY` cell is refused.
const String kPathwayNeedsAName =
    'A pathway needs a name: it prints in the PATH column of every run '
    'through it, and a blank one reads as a cable nobody routed.';

/// Why `RUNS` cannot be typed into.
const String kRunsIsDerived =
    'RUNS counts the cables routed through this pathway, so there is '
    'nothing to type: route a cable to change it.';
