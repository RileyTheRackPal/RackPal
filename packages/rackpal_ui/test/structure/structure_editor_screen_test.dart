// M3-C/2, #148 — the Structure editor in table mode.
//
// WHAT THESE GATE. The screen's whole design claim is that it renders a
// derivation and contains none, so the tests that matter are the ones
// that would catch it starting to decide things: a cell string that is
// not `structureCell`'s, a count that is the filtered view's rather than
// the table's, a control that does nothing.
//
// AND THE COPY IS A CLAIM ABOUT THIS BUILD. `kNoDropsDetail` tells its
// reader how to create a drop, which is the thing the Schedule tab's
// deleted panel got wrong in the direction that costs most. It names the
// field that is on screen directly above it, and the test below drives
// that exact instruction.
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rackpal_core/rackpal_core.dart';
import 'package:rackpal_ui/rackpal_ui.dart';

final DateTime _now = DateTime.utc(2026, 8, 8);

EntityMeta _meta() =>
    EntityMeta(createdAt: _now, updatedAt: _now, updatedBy: 't');

/// A project with a Structure body and the rooms named.
RackDocument _project({
  List<(String, String)> rooms = const [
    ('Living Room', 'LR'),
    ('Kitchen', 'KIT'),
  ],
  // A PROJECT WITH NO PANEL IS THE STATE EVERY NEW PROJECT IS IN, and
  // until `#877` nothing in this file needed one: every case here starts
  // from a body because every case here was about the table inside it.
  // A control that is absent until there is something to act on can only
  // be tested against the absence.
  bool withBody = true,
}) {
  final doc = RackDocument(
    id: const Uuid('doc-editor'),
    appVersion: '0.1.0',
    createdAt: _now,
    modifiedAt: _now,
    meta: _meta(),
  )..registries = buildSeedRegistries();

  if (withBody) {
    AddStructureCommand(
      title: 'Media Panel',
      designator: 'STR-1',
      now: _now,
      actor: 't',
    ).apply(doc);
  }

  for (final (name, code) in rooms) {
    AddLocationCommand(
      name: name,
      code: code,
      order: nextLocationOrder(doc),
      now: _now,
      actor: 't',
    ).apply(doc);
  }
  return doc;
}

/// The Whole House starter, for the Devices tab, which needs real
/// network-capable devices (NET-A/2c).
RackDocument _wholeHouse() =>
    (const JsonDocumentCodec().read(
              File(
                '../../apps/rackpal/assets/starters/whole_house.rppj',
              ).readAsBytesSync(),
            )
            as Ok<RackDocument>)
        .value;

/// What the app layer does, in the shape the app layer does it: re-plan
/// against its own clock and actor, apply, report.
final class _Harness {
  _Harness(this.doc);

  final RackDocument doc;
  int outletPickerOpened = 0;

  /// Every link the drop table's `Pin on plan` was asked to arm.
  final List<Uuid> armedOnPlan = [];

  /// Null makes the row menu ABSENT rather than inert, which is DR-091's
  /// rule at the size of one menu item and is what a host with no Plan
  /// view supplies.
  bool offerPinOnPlan = true;

  /// The Structure body the last `Add outlet` was opened on (#158).
  Uuid? outletPickerBody;

  /// Every batch of Devices-view edits (NET-A/2a), recorded and never
  /// refused: the parsing and the commands are the app's, and tested there.
  final List<List<NetworkCellEdit>> deviceEdits = [];

  /// Every Verified today the Devices batch bar asked for (NET-A/2c).
  final List<List<Uuid>> verifiedToday = [];

  String? editDevices(List<NetworkCellEdit> edits) {
    deviceEdits.add(edits);
    return null;
  }

  StructureEditorActions get actions => StructureEditorActions(
    onPinOnPlan: offerPinOnPlan ? armedOnPlan.add : null,
    dropEntry: DropEntryActions(
      onCommit: (line, {structureBodyId}) {
        final plan = planDropLine(
          doc: doc,
          structureBodyId: structureBodyId,
          line: line,
          now: _now,
          actor: 'committer',
        );
        if (plan is! DropLinePlanReady) return plan;
        for (final c in plan.commands) {
          c.apply(doc);
        }
        return plan;
      },
      onCreateLocation: (name) => AddLocationCommand(
        name: name,
        code: name.split(' ').map((w) => w[0]).join().toUpperCase(),
        order: nextLocationOrder(doc),
        now: _now,
        actor: 't',
      ).apply(doc),
      onCreateStructure: () {},
    ),
    // The harness records the BODY it was handed, not just the click,
    // because #158's whole point is that the picker's selection reaches
    // the gesture.
    onAddOutlet: (bodyId) {
      outletPickerOpened++;
      outletPickerBody = bodyId;
    },
    onEdit: edit,
    onSetCount: setCount,
    onEditPathways: editPathways,
    onAddPathway: addPathway,
    onRemovePathway: removePathway,
    onEditDevices: editDevices,
    onDevicesVerifiedToday: (ids) {
      verifiedToday.add(ids);
      return null;
    },
    onImportCsv: (bodyId) async {
      importCsvOpened++;
      importCsvBody = bodyId;
    },
    // APPLIED STRAIGHT TO [doc], like the outlet actions above: this
    // fixture has no controller, and the commands' own undo behaviour is
    // asserted in `media_type_merge_test.dart` where it can be without a
    // widget.
    onRunMediaTypeCommands: (commands) {
      for (final c in commands) {
        c.apply(doc);
      }
    },
    onRemoveStructure: removedStructures.add,
    outlets: outletsActions,
  );

  /// What the header's overflow menu asked for (`#877`, DR-160 §11.159).
  ///
  /// RECORDED RATHER THAN PERFORMED, like every other destructive gesture
  /// this harness sees: the confirmation and the transaction are the
  /// shell's, and `app_shell`'s own test is what proves they run.
  final List<Uuid> removedStructures = [];

  /// What the Outlets tab's trash icon asked for.
  final List<Uuid> removedOutlets = [];

  /// M3-H/2 (#167). The Outlets tab's five gestures, applied straight to
  /// [doc] the way every other callback in this harness is: the commands
  /// are core's and this file may not reach for a `DocumentController`.
  /// `outlets_view_test.dart` drives the tab itself; this exists so the
  /// editor's own tests can reach it.
  OutletsActions get outletsActions => OutletsActions(
    onRemove: removedOutlets.add,
    onAddGang: (outletId) {
      AddGangCommand(outletId: outletId).apply(doc);
      return null;
    },
    onRemoveGang: (outletId, gangIndex) {
      RemoveGangCommand(outletId: outletId, index: gangIndex).apply(doc);
      return null;
    },
    onSetStrap: (outletId, gangIndex, width, height) {
      SetStrapSizeCommand(
        outletId: outletId,
        index: gangIndex,
        width: width,
        height: height,
      ).apply(doc);
      return null;
    },
    onSetPassThrough: (outletId, gangIndex, style) {
      SetGangPassThroughCommand(
        outletId: outletId,
        index: gangIndex,
        style: style,
      ).apply(doc);
      return null;
    },
    onSetCell: (outletId, gangIndex, cellIndex, occupant) {
      SetCellOccupantCommand(
        outletId: outletId,
        gangIndex: gangIndex,
        cellIndex: cellIndex,
        occupant: occupant,
      ).apply(doc);
      return null;
    },
    onArrange: (outletId, plan) {
      final outlet = doc.outlets[outletId];
      if (outlet == null) return 'no such outlet';
      // BACK TO FRONT, the same hazard the app's own arrange documents:
      // gangs are addressed by position and removing gang 0 renumbers
      // every one after it.
      for (var i = outlet.gangs.length - 1; i >= 0; i--) {
        RemoveGangCommand(outletId: outletId, index: i).apply(doc);
      }
      for (final strap in plan.straps) {
        AddGangCommand(
          outletId: outletId,
          width: strap.width,
          height: strap.height,
        ).apply(doc);
      }
      for (final cell in plan.cells) {
        SetCellOccupantCommand(
          outletId: outletId,
          gangIndex: cell.gangIndex,
          cellIndex: cell.cellIndex,
          occupant: cell.occupant,
        ).apply(doc);
      }
      return null;
    },
  );

  /// M3-F/2 (#160). Recorded rather than acted on: the whole import flow
  /// is the app layer's, because it opens a native file dialog and reads
  /// a file, and neither exists in `rackpal_ui`. What this surface owes
  /// is that the control is there and hands over the body it is showing.
  int importCsvOpened = 0;

  /// The Structure body the last `Import CSV…` was opened on, which is
  /// the same #158 question `Add outlet` answers: an import filed on the
  /// wrong panel puts sixty drops on the wrong sheet.
  Uuid? importCsvBody;

  /// What `apps/rackpal`'s three pathway actions do, in the shape they
  /// do them. Mirrored for [edit]'s reason: `rackpal_ui` may not depend
  /// on the app, and the harness has to be driveable without a
  /// `DocumentController`. `pathways_view_test.dart` drives the tab
  /// itself; this exists so the editor's own tests can reach the tab.
  String? editPathways(List<PathwayCellEdit> edits) {
    for (final e in edits) {
      final Command<RackDocument>? command;
      switch (e.column) {
        // Spelled out per column for `edit`'s reason: `EntityField`'s
        // `set` is a typed closure, so `<Object?>` compiles and throws at
        // apply time.
        // THROUGH THE REFUSING BUILDER, matching the app's real path.
        // `buildSetEntityProperty` would write a duplicate designator
        // silently, and a harness that is laxer than the product tests
        // a product that does not exist (DR-026 §11.25.1).
        case PathwayColumnId.designator:
          final result = buildSetPathwayDesignator(
            doc: doc,
            pathwayId: e.pathwayId,
            to: e.value,
            now: _now,
            actor: 'editor',
          );
          if (result is SetPathwayDesignatorRefused) return result.reason;
          // Unchanged is not a refusal: nothing to push, nothing wrong.
          command = result is SetPathwayDesignatorReady ? result.command : null;
        case PathwayColumnId.name:
          command = buildSetEntityProperty<Pathway, String>(
            doc: doc,
            id: e.pathwayId,
            field: PathwayField.name,
            to: e.value.trim(),
            now: _now,
            actor: 'editor',
          );
        case PathwayColumnId.kind:
          final kind = PathwayKind.values
              .where((k) => pathwayKindLabel(k) == e.value.trim().toUpperCase())
              .firstOrNull;
          if (kind == null) return '"${e.value}" is not a pathway kind.';
          command = buildSetEntityProperty<Pathway, PathwayKind>(
            doc: doc,
            id: e.pathwayId,
            field: PathwayField.kind,
            to: kind,
            now: _now,
            actor: 'editor',
          );
        case PathwayColumnId.lineVoltage:
          command = buildSetEntityProperty<Pathway, bool>(
            doc: doc,
            id: e.pathwayId,
            field: PathwayField.containsLineVoltage,
            to: e.value.trim().toUpperCase() == kLineVoltageYesCell,
            now: _now,
            actor: 'editor',
          );
        case PathwayColumnId.media:
        case PathwayColumnId.nominalLength:
        case PathwayColumnId.notes:
        case PathwayColumnId.runs:
          return null;
      }
      if (command != null) command.apply(doc);
    }
    return null;
  }

  String? addPathway() {
    AddPathwayCommand(
      name: 'New pathway',
      order: nextPathwayOrder(doc),
      now: _now,
      actor: 'adder',
    ).apply(doc);
    return null;
  }

  String? removePathway(Uuid id) {
    RemovePathwayCommand(id: id, now: _now).apply(doc);
    return null;
  }

  /// What `apps/rackpal`'s `buildStructureMatrixAction` does, in the
  /// shape it does it: plan against the live document, refuse whole,
  /// then apply. Mirrored here for `edit`'s reason — `rackpal_ui` may
  /// not depend on the app, and the harness has to be driveable without
  /// a `DocumentController`.
  String? setCount(StructureMatrixEdit edit) {
    final plan = planMatrixCell(
      doc: doc,
      locationId: edit.locationId,
      media: edit.media,
      targetCount: edit.targetCount,
      structureBodyId: edit.structureBodyId,
      now: _now,
      actor: 'gridder',
    );
    switch (plan) {
      case MatrixCellRefused(:final reason):
        return reason;
      case MatrixCellUnchanged():
        return null;
      case MatrixCellNeedsStructure():
        return 'This project has no Structure device yet.';
      case MatrixCellReady(:final commands):
        for (final c in commands) {
          c.apply(doc);
        }
        return null;
    }
  }

  /// What `apps/rackpal`'s `buildStructureEditAction` does, in the
  /// shape it does it: plan the whole batch, refuse it whole, then
  /// apply. Mirrored here rather than imported because `rackpal_ui`
  /// may not depend on the app, and because the harness has to be
  /// driveable without a `DocumentController`.
  /// The size of every batch `onEdit` was handed, in order (M3-L/3).
  ///
  /// RECORDED BECAUSE "one undo entry" IS THE CLAIM. A batch bar that
  /// looped and called `onEdit` once per row would leave the document in
  /// exactly the same state and put twelve entries on the undo stack,
  /// and no assertion about the resulting cells could tell the
  /// difference. This is the only place that can.
  final List<int> batchSizes = <int>[];

  String? edit(List<StructureCellEdit> edits) {
    batchSizes.add(edits.length);
    final commands = <Command<RackDocument>>[];
    final claimedLabels = <String>{};

    for (final e in edits) {
      switch (e.column) {
        // THE TWO ARE SPELLED OUT RATHER THAN SHARING A BRANCH, and it
        // is not verbosity: `EntityField`'s `set` is a typed closure, so
        // building the command through `<Object?>` compiles and then
        // throws `(Link, String) => void is not a subtype of (Link,
        // Object?) => void` at apply time. The concrete type parameter is
        // what keeps the closure callable.
        case StructureColumnId.fieldLabel:
          final field = buildSetStructureOriginProperty<String>(
            doc: doc,
            linkId: e.linkId,
            field: StructureOriginField.fieldLabel,
            to: e.value.trim(),
            now: _now,
            actor: 'editor',
            alsoUsedLabels: claimedLabels,
          );
          switch (field) {
            case SetStructureOriginRefused(:final reason):
              return reason;
            case SetStructureOriginUnchanged():
              break;
            case SetStructureOriginReady(:final command):
              commands.add(command);
              claimedLabels.add(e.value.trim());
          }
        case StructureColumnId.rackLabel:
          final rack = buildSetStructureOriginProperty<String?>(
            doc: doc,
            linkId: e.linkId,
            field: StructureOriginField.rackLabel,
            to: e.value,
            now: _now,
            actor: 'editor',
          );
          switch (rack) {
            case SetStructureOriginRefused(:final reason):
              return reason;
            case SetStructureOriginUnchanged():
              break;
            case SetStructureOriginReady(:final command):
              commands.add(command);
          }
        case StructureColumnId.roughIn:
          final status = RoughInStatus.values
              .where((s) => roughInLabel(s) == e.value.trim().toUpperCase())
              .firstOrNull;
          if (status == null) return '"${e.value}" is not a rough-in status.';
          final c = buildSetEntityProperty<Link, RoughInStatus>(
            doc: doc,
            id: e.linkId,
            field: LinkField.roughInStatus,
            to: status,
            now: _now,
            actor: 'editor',
          );
          if (c != null) commands.add(c);
        // ADDED BY M3-L/3, and its absence was a harness gap rather than
        // a product one: `buildStructureEditAction` has always handled
        // this column and nothing here ever drove it, so the harness
        // refused a column the app applies. A harness stricter than the
        // product tests a product that does not exist.
        case StructureColumnId.fieldTerm:
          final value = e.value.trim();
          final termination = value == kUnknownCell || value.isEmpty
              ? null
              : TerminationType.values
                    .where(
                      (t) => terminationLabel(t) == value.toUpperCase(),
                    )
                    .firstOrNull;
          if (termination == null &&
              value != kUnknownCell &&
              value.isNotEmpty) {
            return '"${e.value}" is not a field termination.';
          }
          final result = buildSetStructureOriginProperty<TerminationType?>(
            doc: doc,
            linkId: e.linkId,
            field: StructureOriginField.terminationField,
            to: termination,
            now: _now,
            actor: 'editor',
          );
          if (result is SetStructureOriginRefused) return result.reason;
          if (result is SetStructureOriginReady) commands.add(result.command);
        // DR-046. THIS COMMENT USED TO SAY "the app has handled both ends
        // since this ruling" AND THAT WAS FALSE (`#711`). The app had an
        // arm for the field end only, so the rack column drew an enabled
        // dropdown and answered every pick with "That column cannot be
        // typed into." A harness MORE capable than the product tests a
        // product that does not exist just as surely as one that is
        // stricter, and this file's whole shape (a reimplementation of
        // `buildStructureEditAction`, which lives in `apps/rackpal` and
        // cannot be imported here) is what let the two drift for a whole
        // ruling. The real action is now driven by
        // `apps/rackpal/test/session/structure_editor_route_test.dart`,
        // which is the file that can reach it; what is asserted HERE is
        // the surface, and nothing about what the surface's answers mean.
        case StructureColumnId.rackTerm:
          final value = e.value.trim();
          final termination = value == kUnknownCell || value.isEmpty
              ? null
              : TerminationType.values
                    .where((t) => terminationLabel(t) == value.toUpperCase())
                    .firstOrNull;
          if (termination == null &&
              value != kUnknownCell &&
              value.isNotEmpty) {
            return '"${e.value}" is not a rack termination.';
          }
          final result = buildSetStructureOriginProperty<TerminationType?>(
            doc: doc,
            linkId: e.linkId,
            field: StructureOriginField.terminationRack,
            to: termination,
            now: _now,
            actor: 'editor',
          );
          if (result is SetStructureOriginRefused) return result.reason;
          if (result is SetStructureOriginReady) commands.add(result.command);
        // ADDED BY #587, and its absence is what made the picker's own
        // two cases fail while the app's passed. The comment four arms
        // up already said it: "a harness stricter than the product tests
        // a product that does not exist". The picker was built, the app
        // grew its arm, and this fell through to `case _` and returned
        // "That column cannot be typed into" on a column that now can be.
        case StructureColumnId.service:
          final family = resolveSignalFamilyCell(doc.registries, e.value);
          if (family == null) {
            return '"${e.value}" is not a signal family.';
          }
          final set = buildSetSignalFamily(
            doc: doc,
            linkId: e.linkId,
            family: family,
            now: _now,
            actor: 'editor',
          );
          switch (set) {
            case SetSignalFamilyRefused(:final reason):
              return reason;
            case SetSignalFamilyReady(:final command):
              commands.add(command);
          }
        // DR-180 §11.179.2, `#80`. ADDED WITH THE COLUMN, on the lesson
        // the two comments above record: this harness reimplements
        // `buildStructureEditAction`, and a column the product can write
        // and this one cannot is a surface test failing for a reason the
        // product does not have. The REFUSAL for a cable with no 8P8C end
        // is the app's and is driven in `structure_editor_route_test`;
        // what this arm buys is that a pick on a qualifying row reaches
        // the document, which is what the surface case asserts.
        case StructureColumnId.wiringStandard:
          final value = e.value.trim().toUpperCase();
          final standard = value == kUnknownCell || value.isEmpty
              ? null
              : WiringStandard.values
                    .where((w) => wiringStandardLabel(w) == value)
                    .firstOrNull;
          if (standard == null && value != kUnknownCell && value.isNotEmpty) {
            return '"${e.value}" is not a wiring standard.';
          }
          final wiring = buildSetEntityProperty<Link, WiringStandard?>(
            doc: doc,
            id: e.linkId,
            field: LinkField.wiringStandard,
            to: standard,
            now: _now,
            actor: 'editor',
          );
          if (wiring != null) commands.add(wiring);
        case StructureColumnId.notes:
          final c = buildSetEntityProperty<Link, String?>(
            doc: doc,
            id: e.linkId,
            field: LinkField.notes,
            to: e.value.trim().isEmpty ? null : e.value.trim(),
            now: _now,
            actor: 'editor',
          );
          if (c != null) commands.add(c);
        // DR-067, `#712`. The one column whose two answers are two
        // COMMANDS rather than two values. Mirrored here only far enough
        // to let the widget cases below drive the control; what the
        // answers MEAN is asserted against the real
        // `buildStructureEditAction` in
        // `apps/rackpal/test/session/structure_editor_route_test.dart`,
        // for the reason the `rackTerm` arm above now records at length.
        case StructureColumnId.linkClass:
          if (e.value.trim().toUpperCase() == kLinkClassAutoCell) {
            commands.add(ClearLinkClassOverrideCommand(linkId: e.linkId));
            break;
          }
          final klass = resolveLinkClassCell(e.value);
          if (klass == null) return '"${e.value}" is not a class.';
          commands.add(
            SetLinkClassCommand(linkId: e.linkId, linkClass: klass),
          );
        case _:
          return 'That column cannot be typed into.';
      }
    }
    for (final c in commands) {
      c.apply(doc);
    }
    return null;
  }
}

/// The drop count the STATUS BAR is showing, which is the table's own
/// count for the body currently selected.
///
/// READ OFF THE SCREEN rather than recomputed, because the question is
/// what the editor is showing and not what a builder would return if
/// asked the same thing twice.
int _visibleDropCount(WidgetTester tester) {
  final text = tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data)
      .whereType<String>()
      .firstWhere((d) => RegExp(r'^\d+ drops · ').hasMatch(d));
  return int.parse(RegExp(r'^(\d+) drops').firstMatch(text)!.group(1)!);
}

Future<void> _pump(WidgetTester tester, _Harness h) async {
  // A WINDOW, NOT A PHONE. The default 800×600 test surface is smaller
  // than any window this editor opens in: it is the Structured Wiring tab
  // of the main window (AC-048).
  //
  // FOUND BY M3-F/2, and the finding is about the tests rather than the
  // screen. These cases asserted that three drops are all visible at
  // 600 px, and that held only because the harness's header rendered
  // with NO BUTTON IN IT and collapsed to 24 px, while production's
  // carried one and was 48 px. Adding `Import CSV…` made the test header
  // match production and the gap became visible. Sizing the surface to a
  // real window fixes the representation rather than the assertion.
  //
  // (That button was `Done`, from the full-screen dialog this editor used
  // to open in. `#945` removed it: the tab never passed `onDone`, so it
  // could not appear, and the dialog opener was deleted as uncalled.)
  await tester.binding.setSurfaceSize(const Size(1200, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: StructureEditorScreen(
          actions: h.actions,
          currentDoc: () => h.doc,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Types one quick-add line and commits it, the way a person does.
///
/// SCOPED TO THE LOOP'S OWN FIELD. Every editable cell on either tab is
/// a real `TextField` (that is what buys the tab order), so an unscoped
/// `find.byType(TextField)` stops meaning the quick-add bar the moment
/// there is one drop or one room on screen.
Future<void> _addLine(WidgetTester tester, String line) async {
  await tester.enterText(
    find.descendant(
      of: find.byType(DropEntryLoop),
      matching: find.byType(TextField),
    ),
    line,
  );
  await tester.pumpAndSettle();
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();
}

/// The drops IN THE ORDER THE TABLE DRAWS THEM.
///
/// NOT `doc.links.values`, which is map insertion order and does NOT
/// match: `buildSchedule` sorts by `Link.order` then id, so the two
/// disagree the moment one line creates more than one drop. Every
/// assertion about "the row above" reads its order from here, because
/// reading it off anything but the table would be testing a different
/// table.
List<Link> _rows(_Harness h) => [
  for (final row in buildStructureTable(h.doc).groups.single.rows)
    h.doc.links[row.linkId]!,
];

/// The room called [name].
Uuid _roomId(_Harness h, String name) =>
    h.doc.locations.values.firstWhere((l) => l.name == name).id;

/// Switches to §4.2's grid the way a person does.
Future<void> _showMatrix(WidgetTester tester) async {
  await tester.tap(find.text(kMatrixTabLabel));
  await tester.pumpAndSettle();
}

/// The matrix the screen is drawing, with the same columns it seeds.
StructureMatrix _matrix(_Harness h) => buildStructureMatrix(
  h.doc,
  alsoColumns: kStructureMatrixSeedColumns.toSet(),
);

/// One grid cell, found the way the grid lays it out: the row keyed on
/// the room, then the Nth `TextField` in it.
///
/// A POSITIONAL FINDER AND NOT A KEY PER CELL, because the position is
/// the thing under test: a cell that wrote to the wrong column would be
/// invisible to a finder that asked for the column by name.
Finder _cell(_Harness h, Uuid locationId, MediaTypeId media) => find
    .descendant(
      of: find.byKey(ValueKey(locationId)),
      matching: find.byType(TextField),
    )
    .at(_matrix(h).columns.indexOf(media));

/// What a grid cell says on screen.
String _shows(WidgetTester tester, Finder cell) =>
    tester.widget<TextField>(cell).controller!.text;

/// Types [value] into a grid cell and commits it.
Future<void> _type(WidgetTester tester, Finder cell, String value) async {
  await tester.enterText(cell, value);
  await tester.pumpAndSettle();
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();
}

const MediaTypeId _cat6 = MediaTypeId('media.cat6');
const MediaTypeId _rg6 = MediaTypeId('media.rg6');

void main() {
  group('it shows the derivation, and nothing it computed itself', () {
    testWidgets('every visible cell is the string structureCell produced', (
      tester,
    ) async {
      final h = _Harness(_project());
      await _pump(tester, h);
      await _addLine(tester, 'Living Room: 2x Cat6, 1x RG6');

      final table = buildStructureTable(h.doc);
      expect(table.dropCount, 3);

      // THE GATE. Not "the screen shows LR-C6-1" — that would pass just
      // as well if the screen made the string up and happened to agree
      // today. Every default column of every row is looked up through
      // core and then found on screen.
      final units = h.doc.settings.displayUnits;
      for (final row in table.groups.single.rows) {
        for (final id in kStructureDefaultColumns) {
          final expected = structureCell(h.doc, row, id, units: units);
          expect(
            find.text(expected),
            findsWidgets,
            reason: '${structureColumnHeader(id)} is missing from the table',
          );
        }
      }
    });

    testWidgets('the band header carries the room, code and counts', (
      tester,
    ) async {
      final h = _Harness(_project());
      await _pump(tester, h);
      await _addLine(tester, 'Living Room: 2x Cat6');

      expect(find.text('LIVING ROOM (LR)'), findsOneWidget);
      expect(find.text('2 drops · 0 connected'), findsOneWidget);
    });

    testWidgets('a room with no drops has no band but is still in the tree', (
      tester,
    ) async {
      // The tree is what lists every room; a band per empty room would
      // push the drops off the screen in a project with forty of them.
      final h = _Harness(_project());
      await _pump(tester, h);
      await _addLine(tester, 'Living Room: 1x Cat6');

      expect(find.text('LIVING ROOM (LR)'), findsOneWidget);
      expect(find.text('KITCHEN (KIT)'), findsNothing);
      expect(find.text('Kitchen'), findsOneWidget);
    });
  });

  group('the status bar counts the TABLE, not the filtered view', () {
    testWidgets("it prints §4's five counts", (tester) async {
      final h = _Harness(_project());
      await _pump(tester, h);
      await _addLine(tester, 'Living Room: 2x Cat6 @outlet=WP-1');

      expect(
        find.textContaining('2 drops · 0 connected · 2 spare · 1 outlets'),
        findsOneWidget,
      );
    });

    testWidgets('a filter states what it hid and does not restate the total', (
      tester,
    ) async {
      // THE DEFECT THIS FORBIDS: reading "1 drop" off a screen filtered
      // to one media type and ordering cable for the house.
      final h = _Harness(_project());
      await _pump(tester, h);
      await _addLine(tester, 'Living Room: 2x Cat6, 1x RG6');

      await tester.tap(find.text('Unconnected only'));
      await tester.pumpAndSettle();
      // Nothing is landed, so nothing is hidden and the count is silent.
      expect(find.textContaining('hidden by filter'), findsNothing);
      // The WHOLE status line, because "3 drops" alone also matches the
      // band header one row up — and the point of this test is that the
      // status bar reports the body and not the view.
      expect(
        find.text('3 drops · 0 connected · 3 spare · 1 outlets · 0 pathways'),
        findsOneWidget,
      );
    });
  });

  group('the empty states are true of this build', () {
    testWidgets('an empty body says how to fill it, on this screen', (
      tester,
    ) async {
      final h = _Harness(_project());
      await _pump(tester, h);

      expect(find.text(kNoDropsHeadline), findsOneWidget);
      // The copy names the field above it. Following the instruction
      // literally is the test: if the instruction stops working, this
      // fails rather than the sentence quietly becoming false.
      expect(kNoDropsDetail, contains('Living Room: 4x Cat6'));
      await _addLine(tester, 'Living Room: 4x Cat6, 2x RG6');
      expect(find.text(kNoDropsHeadline), findsNothing);
      expect(buildStructureTable(h.doc).dropCount, 6);
    });

    testWidgets('all-hidden is a different sentence from none-exist', (
      tester,
    ) async {
      final h = _Harness(_project());
      await _pump(tester, h);
      await _addLine(tester, 'Living Room: 1x Cat6');

      await tester.tap(find.text('All rooms'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Living Room').last);
      await tester.pumpAndSettle();
      expect(find.text(kAllDropsFilteredHeadline), findsNothing);

      // Filtering to a media type nothing was pulled in is not reachable
      // from the menu (it offers only what is on the body), so the
      // connection filter is what empties the table.
      await tester.tap(find.text('Unconnected only'));
      await tester.pumpAndSettle();
      expect(find.text(kNoDropsHeadline), findsNothing);
    });
  });

  group('the left pane is a view, not an editor (CR-112)', () {
    testWidgets('it names where rooms are edited instead of offering it', (
      tester,
    ) async {
      final h = _Harness(_project());
      await _pump(tester, h);

      expect(find.text(kLocationsAreReadOnlyHere), findsOneWidget);
      // No control in the pane creates, renames or deletes a room.
      expect(find.widgetWithText(TextButton, 'Add room'), findsNothing);
    });

    testWidgets('every room is listed, with its code and drop count', (
      tester,
    ) async {
      final h = _Harness(_project());
      await _pump(tester, h);
      await _addLine(tester, 'Living Room: 3x Cat6');

      expect(find.text('Living Room'), findsOneWidget);
      expect(find.text('Kitchen'), findsOneWidget);
      expect(find.text('LR'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });
  });

  group('the optional columns are off until asked for', () {
    testWidgets('⚙ Columns adds one and the header appears', (tester) async {
      final h = _Harness(_project());
      await _pump(tester, h);
      await _addLine(tester, 'Living Room: 1x Cat6');

      expect(find.text('NOTES'), findsNothing);

      await tester.tap(find.text('Columns'));
      await tester.pumpAndSettle();
      // SCROLLED TO FIRST. The menu grew past one screen when M3-J/3
      // added the as-built group and two more columns, and a `tap` on an
      // item below the fold hits whatever is drawn there instead.
      await tester.ensureVisible(find.text('NOTES'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('NOTES'));
      await tester.pumpAndSettle();

      // THE MENU STAYS OPEN ON PURPOSE (`closeOnActivate: false`), so a
      // person can tick three columns in one visit — which means its own
      // `NOTES` item is still on screen beside the new column header.
      // Dismissing it is what leaves only the header to find.
      expect(find.text('NOTES'), findsNWidgets(2));
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      expect(find.text('NOTES'), findsOneWidget);
    });

    testWidgets('the as-built group is ONE switch, not seven ticks', (
      tester,
    ) async {
      // DR-020 §11.19.2(5) pictures somebody closing out sixty runs who
      // "needs one table with a length column they tab down". Making them
      // reach that table through seven menu entries would put the cost
      // back in a different place.
      final h = _Harness(_project());
      await _pump(tester, h);
      await _addLine(tester, 'Living Room: 1x Cat6');

      for (final id in kStructureAsBuiltColumns) {
        expect(find.text(structureColumnHeader(id)), findsNothing);
      }

      await tester.tap(find.text('Columns'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(kAsBuiltColumnsLabel));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();

      for (final id in kStructureAsBuiltColumns) {
        expect(
          find.text(structureColumnHeader(id)),
          findsOneWidget,
          reason: '${structureColumnHeader(id)} is in the as-built set',
        );
      }
      // And off again, because a switch that only goes one way is a trap
      // on a table this wide.
      await tester.tap(find.text('Columns'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(kAsBuiltColumnsLabel));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      expect(find.text('SPLICES'), findsNothing);
    });

    testWidgets('the eight defaults are all there before any menu is opened', (
      tester,
    ) async {
      final h = _Harness(_project());
      await _pump(tester, h);

      for (final id in kStructureDefaultColumns) {
        expect(
          find.text(structureColumnHeader(id)),
          findsOneWidget,
          reason: '${structureColumnHeader(id)} is a DEFAULT column',
        );
      }
    });
  });

  group('the header names the body it is editing (§7)', () {
    testWidgets('designator and title, from the device and the body', (
      tester,
    ) async {
      final h = _Harness(_project());
      await _pump(tester, h);
      expect(find.text('STR-1 · Media Panel'), findsOneWidget);
    });

    testWidgets('a project with no Structure device says so', (tester) async {
      final doc = RackDocument(
        id: const Uuid('doc-bare'),
        appVersion: '0.1.0',
        createdAt: _now,
        modifiedAt: _now,
        meta: _meta(),
      )..registries = buildSeedRegistries();
      await _pump(tester, _Harness(doc));

      expect(find.text('No Structure device yet'), findsOneWidget);
    });
  });

  group('the two buttons that are drawn both do something', () {
    testWidgets('Add outlet reaches the picker', (tester) async {
      final h = _Harness(_project());
      await _pump(tester, h);

      await tester.tap(find.widgetWithText(TextButton, 'Add outlet'));
      await tester.pumpAndSettle();
      expect(h.outletPickerOpened, 1);
    });

    testWidgets('and nothing unbuilt is offered', (tester) async {
      // `shell_tabs_test.dart`'s rule, applied here: no control that
      // does nothing. Each of these is a real §4 wireframe control whose
      // command does not exist yet.
      final h = _Harness(_project());
      await _pump(tester, h);

      for (final label in [
        // STILL ABSENT AFTER M3-E/1, and the distinction is the tab's
        // own scoping: `[ Pathways ]` LISTS AND EDITS the pathways that
        // exist and does not assign runs to them. Grouping needs a
        // command nothing has written, and the user's stated expectation
        // is that a pathway is set in the Plan view once somebody has
        // walked the run.
        'Group into pathway',
        'Renumber…',
        // `Import CSV…` LEFT THIS LIST AT M3-F/2 (#160), which is the
        // bookkeeping this test is for. `Export CSV` stays, and its
        // reason is now different from the other three: it is not
        // unbuilt-for-lack-of-a-command but UNRULED. docs/07 §5.3's
        // closing line promises the round trip and roadmap §2, the one
        // scope list, does not name it, so #653 asks for a ruling rather
        // than an afternoon.
        'Export CSV',
        // `Matrix` LEFT THIS LIST AT M3-C/3, `Pathways` at M3-E/1 and
        // `Outlets` at M3-H/2 (#167), which is the bookkeeping this test
        // is for: the day one is built the test says the others still
        // are not. THE TAB LIST IS NOW EMPTY and what remains here is
        // two button-bar controls plus one that is unruled rather than
        // unbuilt.
      ]) {
        expect(find.text(label), findsNothing, reason: '$label is unbuilt');
      }
    });
  });

  group('inline editing is the primary path (§4.1)', () {
    /// The cell holding [value], by what is in its box.
    ///
    /// BY CONTENT AND NOT BY POSITION, because position is what these
    /// tests are least sure of and least interested in: an index into
    /// the visible columns would silently point at a different cell the
    /// day an optional column is turned on.
    Finder cellHolding(String value) => find.byWidgetPredicate(
      (w) => w is TextField && w.controller?.text == value,
      description: 'a table cell reading "$value"',
    );

    testWidgets('typing a field label writes it through a Command', (
      tester,
    ) async {
      final h = _Harness(_project());
      await _pump(tester, h);
      await _addLine(tester, 'Living Room: 1x Cat6');

      final linkId = h.doc.links.values.single.id;
      final before = h.doc.links[linkId]!.structureOrigin!.fieldLabel;

      await tester.enterText(cellHolding(before), 'LR-1');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(h.doc.links[linkId]!.structureOrigin!.fieldLabel, 'LR-1');
      // And the table followed, because it re-derived rather than
      // caching what it drew. The CELL, not `find.text`: the quick-add
      // bar's "just added" tail says the old label too, which is correct
      // of it — it reports what that line produced at the time.
      expect(cellHolding('LR-1'), findsOneWidget);
    });

    testWidgets('a duplicate label is REFUSED, and the cell goes back', (
      tester,
    ) async {
      // CR-113: unique project-wide across all Structure bodies. The
      // defect this forbids is two rows an installer cannot tell apart,
      // written silently through the ordinary edit path.
      final h = _Harness(_project());
      await _pump(tester, h);
      await _addLine(tester, 'Living Room: 2x Cat6');

      final links = h.doc.links.values.toList();
      final first = links[0].structureOrigin!.fieldLabel;
      final second = links[1].structureOrigin!.fieldLabel;

      await tester.enterText(cellHolding(second), first);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(
        links[1].structureOrigin!.fieldLabel,
        second,
        reason: 'the write was refused, so the document did not move',
      );
      // THE SENTENCE IS ON SCREEN AND STAYS. A refusal that put the old
      // value back and said nothing would read as typing that vanished.
      expect(find.textContaining(first), findsWidgets);
      expect(find.textContaining('already'), findsWidgets);
    });

    testWidgets('ROUGH-IN is a dropdown over the five real values', (
      tester,
    ) async {
      final h = _Harness(_project());
      await _pump(tester, h);
      await _addLine(tester, 'Living Room: 1x Cat6');
      final linkId = h.doc.links.values.single.id;
      expect(h.doc.links[linkId]!.roughInStatus, RoughInStatus.planned);

      await tester.tap(find.text('PLANNED'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('PULLED').last);
      await tester.pumpAndSettle();

      expect(h.doc.links[linkId]!.roughInStatus, RoughInStatus.pulled);
    });

    testWidgets('a derived column is not typed into at all', (tester) async {
      // MEDIA names a registry entry. A text box that accepted `Cat6a`
      // into a `MediaTypeId` would be worse than a cell that cannot be
      // typed into, which is what `structureColumnIsEditable` says.
      final h = _Harness(_project());
      await _pump(tester, h);
      await _addLine(tester, 'Living Room: 1x Cat6');

      final editable = kStructureDefaultColumns
          .where(structureColumnIsEditable)
          .toList();
      // SIX SINCE DR-025's PICKER (#587). It used to assert FIVE and
      // said "both termination columns are defaults now, and both are
      // dropdowns rather than boxes", which was right at DR-046 and did
      // not say what would retire it. What retired it: `SERVICE` became
      // editable when `SetSignalFamilyCommand` gave it a command to sit
      // behind, so the column this case is NAMED for is no longer the
      // example it uses. **MEDIA still is**, and that is the assertion
      // that matters: a text box accepting `Cat6a` into a `MediaTypeId`
      // is worse than a cell that cannot be typed into.
      expect(editable, [
        StructureColumnId.fieldLabel,
        StructureColumnId.rackLabel,
        StructureColumnId.service,
        StructureColumnId.fieldTerm,
        StructureColumnId.rackTerm,
        StructureColumnId.roughIn,
      ]);
      expect(
        structureColumnIsEditable(StructureColumnId.media),
        isFalse,
        reason: 'MEDIA is the derived column this case is really about',
      );
      // UNCHANGED AT THREE, and that is the point of the picker: SERVICE
      // arrived as a DROPDOWN, so it added no text box. Two boxes on the
      // row plus the quick-add field above the table.
      expect(find.byType(TextField), findsNWidgets(3));
    });

    testWidgets('an empty NOTES box lands as unknown, never as an empty '
        'string (G4)', (tester) async {
      final h = _Harness(_project());
      await _pump(tester, h);
      await _addLine(tester, 'Living Room: 1x Cat6');
      final link = h.doc.links.values.single;

      expect(
        h.edit([
          StructureCellEdit(
            linkId: link.id,
            column: StructureColumnId.notes,
            value: 'coiled above the ceiling',
          ),
        ]),
        isNull,
      );
      expect(link.notes, 'coiled above the ceiling');

      expect(
        h.edit([
          StructureCellEdit(
            linkId: link.id,
            column: StructureColumnId.notes,
            value: '   ',
          ),
        ]),
        isNull,
      );
      expect(link.notes, isNull, reason: 'not the empty string');
    });

    testWidgets('a batch is ALL or NOTHING, and says which row stopped it', (
      tester,
    ) async {
      // This is the shape fill-down and paste both take. A batch that
      // wrote the good rows and reported the bad one would leave a
      // person to work out which rows moved.
      final h = _Harness(_project());
      await _pump(tester, h);
      await _addLine(tester, 'Living Room: 3x Cat6');
      final links = h.doc.links.values.toList();
      final before = links.map((l) => l.structureOrigin!.fieldLabel).toList();

      final refusal = h.edit([
        StructureCellEdit(
          linkId: links[0].id,
          column: StructureColumnId.fieldLabel,
          value: 'LR-A',
        ),
        StructureCellEdit(
          linkId: links[1].id,
          column: StructureColumnId.fieldLabel,
          // COLLIDES WITH THE EDIT ABOVE, not with the document. Only
          // `alsoUsedLabels` can see this, which is why the batch is
          // planned as a batch.
          value: 'LR-A',
        ),
      ]);

      expect(refusal, isNotNull);
      expect(
        links.map((l) => l.structureOrigin!.fieldLabel),
        before,
        reason: 'the first edit must not have been applied either',
      );
    });
  });

  group('the WIRING column (DR-180 §11.179, board `#80`)', () {
    // THE CASE THIS GROUP EXISTS FOR is the coax row. The column is
    // editable per COLUMN, and whether a standard is a fact about a given
    // cable is per ROW (§11.179.3). Get that wrong and the cell is an
    // enabled control whose every use the write path refuses, which is
    // `#711`'s defect drawn on purpose.

    /// Turns `WIRING` on the way a person does, through `⚙ Columns`.
    Future<void> showWiring(WidgetTester tester) async {
      await tester.tap(find.text('Columns'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('WIRING'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('WIRING'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
    }

    /// The `WIRING` menu, found by the pair of options no other column
    /// offers together.
    Finder wiringMenu() => find.byWidgetPredicate(
      (w) =>
          w is DropdownButton<String> &&
          (w.items ?? const <DropdownMenuItem<String>>[]).any(
            (i) => i.value == wiringStandardLabel(WiringStandard.t568a),
          ),
      description: 'the WIRING menu',
    );

    testWidgets('it is off until asked for, and a Cat6 drop then gets a '
        'real control', (tester) async {
      final h = _Harness(_project());
      await _pump(tester, h);
      await _addLine(tester, 'Living Room: 1x Cat6');
      expect(find.text('WIRING'), findsNothing);

      await showWiring(tester);
      expect(find.text('WIRING'), findsOneWidget, reason: 'the header');
      expect(wiringMenu(), findsOneWidget);
    });

    testWidgets('a COAX drop gets NO control and says so, rather than an '
        'enabled cell the write path would refuse', (tester) async {
      final h = _Harness(_project());
      await _pump(tester, h);
      await _addLine(tester, 'Living Room: 1x RG6');
      await showWiring(tester);

      expect(find.text('WIRING'), findsOneWidget, reason: 'the header');
      expect(wiringMenu(), findsNothing);
      expect(find.text(kNoRj45Cell), findsOneWidget);
    });

    testWidgets('picking one writes THIS cable and leaves the project '
        'setting alone', (tester) async {
      final h = _Harness(_project());
      await _pump(tester, h);
      await _addLine(tester, 'Living Room: 1x Cat6');
      await showWiring(tester);

      await tester.tap(wiringMenu());
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(wiringStandardLabel(WiringStandard.t568a)).last,
      );
      await tester.pumpAndSettle();

      expect(
        _rows(h).single.wiringStandard,
        WiringStandard.t568a,
        reason: 'the cable carries the exception',
      );
      expect(
        h.doc.settings.wiringStandard,
        isNull,
        reason: 'and the job was never told anything',
      );
    });
  });

  group('the CLASS column (DR-067 §11.66, board `#712`)', () {
    /// Turns `CLASS` on the way a person does, through `⚙ Columns`.
    Future<void> showClass(WidgetTester tester) async {
      await tester.tap(find.text('Columns'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('CLASS'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CLASS'));
      await tester.pumpAndSettle();
      // The menu stays open on purpose so three columns can be ticked in
      // one visit; dismiss it before reading the table underneath.
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
    }

    Finder pin() => find.byIcon(Icons.push_pin);
    Finder faintPin() => find.byIcon(Icons.push_pin_outlined);

    /// The `CLASS` menu, identified by the one option no other column
    /// offers rather than by its current value: the point of most of
    /// these cases is that the value changes.
    Finder classMenu() => find.byWidgetPredicate(
      (w) =>
          w is DropdownButton<String> &&
          (w.items ?? const <DropdownMenuItem<String>>[]).any(
            (i) => i.value == kLinkClassAutoCell,
          ),
      description: 'the CLASS menu',
    );

    /// Picks [label] the way a person does. THROUGH THE CONTROL, never
    /// by calling the harness: the screen's own `_edit` is what rebuilds
    /// the table, so an edit applied around the side of it changes the
    /// document and leaves the screen showing the previous answer.
    Future<void> pickClass(WidgetTester tester, String label) async {
      await tester.tap(classMenu());
      await tester.pumpAndSettle();
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
    }

    testWidgets('it is off until asked for, and then it is a real control', (
      tester,
    ) async {
      final h = _Harness(_project());
      await _pump(tester, h);
      await _addLine(tester, 'Living Room: 1x Cat6');
      expect(find.text('CLASS'), findsNothing);

      await showClass(tester);
      expect(find.text('CLASS'), findsOneWidget, reason: 'the header');
      // A DROPDOWN, NOT A TEXT BOX. The four classes are an enum, so
      // there is nothing to parse and nothing to typo.
      expect(classMenu(), findsOneWidget);
    });

    testWidgets('an unclassified run shows the classifier and wears no pin', (
      tester,
    ) async {
      final h = _Harness(_project());
      await _pump(tester, h);
      await _addLine(tester, 'Living Room: 1x Cat6');
      await showClass(tester);

      // A drop with a wall end and an open rack end is a field cable,
      // and nobody has said so: the cell reads it and stays unmarked.
      expect(find.text('FIELD CABLE'), findsOneWidget);
      expect(pin(), findsNothing);
      expect(faintPin(), findsNothing);
    });

    testWidgets('picking one pins it, and the pin names what the classifier '
        'still thinks', (tester) async {
      // DR-008 §11.8.2's visible-disagreement clause is a SENTENCE and
      // not a colour: "you set jumper; this now looks like a field
      // cable" is what keeps an override auditable after the document
      // moves under it, and a coloured glyph alone says none of it.
      final h = _Harness(_project());
      await _pump(tester, h);
      await _addLine(tester, 'Living Room: 1x Cat6');
      await showClass(tester);

      await pickClass(tester, linkClassLabel(LinkClass.jumper));

      expect(find.text('JUMPER'), findsWidgets);
      expect(h.doc.links.values.single.linkClassLocked, isTrue);
      expect(
        pin(),
        findsOneWidget,
        reason:
            'the classifier still reads this run as a field cable, so '
            'the mark is the filled pin',
      );

      final tip = tester.widget<Tooltip>(
        find.ancestor(of: pin(), matching: find.byType(Tooltip)),
      );
      // THE WHOLE SENTENCE. A green `contains` over a line reading
      // "1 ports" has shipped in this project before now.
      expect(
        tip.message,
        'Set by hand. The classifier now reads this as FIELD CABLE. '
        'Pick AUTO to let it decide again.',
      );
    });

    testWidgets('an override the classifier agrees with is marked more '
        'quietly, and still marked', (tester) async {
      final h = _Harness(_project());
      await _pump(tester, h);
      await _addLine(tester, 'Living Room: 1x Cat6');
      await showClass(tester);

      await pickClass(tester, linkClassLabel(LinkClass.fieldCable));

      expect(h.doc.links.values.single.linkClassLocked, isTrue);
      expect(faintPin(), findsOneWidget, reason: 'asserted, not disputed');
      expect(pin(), findsNothing);
      final tip = tester.widget<Tooltip>(
        find.ancestor(of: faintPin(), matching: find.byType(Tooltip)),
      );
      expect(
        tip.message,
        'Set by hand. Pick AUTO to let the classifier decide again.',
      );
    });

    testWidgets('AUTO takes the pin off and the classifier is heard again', (
      tester,
    ) async {
      final h = _Harness(_project());
      await _pump(tester, h);
      await _addLine(tester, 'Living Room: 1x Cat6');
      await showClass(tester);

      await pickClass(tester, linkClassLabel(LinkClass.jumper));
      expect(pin(), findsOneWidget);

      await pickClass(tester, kLinkClassAutoCell);

      expect(pin(), findsNothing);
      expect(faintPin(), findsNothing);
      expect(find.text('FIELD CABLE'), findsOneWidget);
      expect(h.doc.links.values.single.linkClassLocked, isFalse);
    });

    testWidgets('a run the classifier cannot read shows the dash and does '
        'not take the table down with it', (tester) async {
      // THE CRASH THIS COLUMN COULD HAVE INTRODUCED. `DropdownButton`
      // asserts that exactly one item carries its value, and the dash is
      // deliberately NOT one of this column's options: `AUTO` occupies
      // that slot and means something else entirely. An effective class
      // of nothing therefore renders as a hint over a null value, and a
      // cell that passed the dash straight through would take out the
      // whole editor for every document with a staged panel in it.
      final h = _Harness(_project());
      await _pump(tester, h);
      await _addLine(tester, 'Living Room: 1x Cat6');

      // Point the rack end at a port no device in this document owns,
      // which is what a deleted or staged panel leaves behind. Done
      // BEFORE the column is switched on, so turning it on is the only
      // rebuild and this never re-pumps a screen out from under itself:
      // `⚙ Columns` is a `setState` on the editor.
      final link = h.doc.links.values.single;
      final was = link.conductors.first;
      link.conductors[0] = Conductor(
        from: was.from,
        to: const PortEndpoint(Uuid('port-gone')),
        role: was.role,
        pairNumber: was.pairNumber,
        colorCode: was.colorCode,
      );

      await showClass(tester);

      expect(find.text('FIELD CABLE'), findsNothing);
      expect(
        find.text(kUnknownCell),
        findsWidgets,
        reason:
            'the classifier has failed to resolve an end, and G4 says '
            'that prints as unknown rather than as a guess',
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('the grid operations #148 names', () {
    Finder cellHolding(String value) => find.byWidgetPredicate(
      (w) => w is TextField && w.controller?.text == value,
      description: 'a table cell reading "$value"',
    );

    testWidgets('TAB ORDER IS THE WIDGET ORDER, with no binding for it', (
      tester,
    ) async {
      // The claim the design rests on: because every editable cell is a
      // real control rather than a label that becomes one, Flutter's own
      // traversal already walks them. If this fails, the cells stopped
      // being real controls and `kKeymap` owes a `Tab` row.
      final h = _Harness(_project());
      await _pump(tester, h);
      await _addLine(tester, 'Living Room: 2x Cat6');
      final labels = _rows(
        h,
      ).map((l) => l.structureOrigin!.fieldLabel).toList();

      await tester.tap(cellHolding(labels.first));
      await tester.pumpAndSettle();
      final first = primaryFocus;

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(primaryFocus, isNot(first));
      expect(primaryFocus?.hasFocus, isTrue);
    });

    testWidgets('Ctrl+D fills ROUGH-IN down, which is the gesture that '
        'earns the key', (tester) async {
      // "Everything from here down is pulled" is what a person does
      // walking a job, and a status is legal to repeat where a label is
      // not — see the refusal beside this.
      final h = _Harness(_project());
      await _pump(tester, h);
      await _addLine(tester, 'Living Room: 2x Cat6');
      final links = _rows(h);

      expect(
        h.edit([
          StructureCellEdit(
            linkId: links[0].id,
            column: StructureColumnId.roughIn,
            value: roughInLabel(RoughInStatus.pulled),
          ),
        ]),
        isNull,
      );
      await tester.pumpAndSettle();

      // The second row's status cell. Clicking it is what puts the caret
      // there; `Esc` closes the menu the click opened without choosing.
      await tester.tap(find.text(roughInLabel(RoughInStatus.planned)).last);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
      await tester.pumpAndSettle();

      expect(links[1].roughInStatus, RoughInStatus.pulled);
    });

    testWidgets('and it REFUSES to fill a rack label down (CR-113)', (
      tester,
    ) async {
      // THE CASE THAT LOOKS LIKE A BUG AND IS THE FEATURE. Rack labels
      // are unique where set, so filling one down would put two rows on
      // one panel position. The refusal comes from the same builder a
      // typed cell goes through, so the grid operation cannot route
      // around it — which is the whole reason `onEdit` takes a list of
      // edits rather than writing values itself.
      final h = _Harness(_project());
      await _pump(tester, h);
      await _addLine(tester, 'Living Room: 2x Cat6');
      final links = _rows(h);

      expect(
        h.edit([
          StructureCellEdit(
            linkId: links[0].id,
            column: StructureColumnId.rackLabel,
            value: 'PP1-01',
          ),
        ]),
        isNull,
      );
      await tester.pumpAndSettle();

      // Row two's rack-label cell is empty, so it cannot be found by
      // content: reach it from the label cell beside it, one `Tab` away.
      await tester.tap(cellHolding(links[1].structureOrigin!.fieldLabel));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
      await tester.pumpAndSettle();

      expect(links[1].structureOrigin!.rackLabel, isNull);
      expect(find.textContaining('unique where set'), findsOneWidget);
    });

    testWidgets('Ctrl+D on the first row says why it did nothing', (
      tester,
    ) async {
      // docs/04 §3.4: never silently do nothing. A grid operation that
      // declined without a reason is indistinguishable from an unbound
      // key.
      final h = _Harness(_project());
      await _pump(tester, h);
      await _addLine(tester, 'Living Room: 2x Cat6');
      final first = _rows(h).first.structureOrigin!.fieldLabel;

      await tester.tap(cellHolding(first));
      await tester.pumpAndSettle();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
      await tester.pumpAndSettle();

      expect(find.text(kNothingAboveToFill), findsOneWidget);
    });

    testWidgets('Ctrl+D with no caret says where to put one', (tester) async {
      final h = _Harness(_project());
      await _pump(tester, h);
      await _addLine(tester, 'Living Room: 1x Cat6');

      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
      await tester.pumpAndSettle();

      expect(find.text(kNoCaretForFill), findsOneWidget);
    });

    testWidgets('Ctrl+V pastes tab-separated cells from the caret', (
      tester,
    ) async {
      // docs/07 §5: the contractor's pull list arrives as a spreadsheet,
      // and a person with one open will try this before they go looking
      // for an importer.
      final h = _Harness(_project());
      await _pump(tester, h);
      await _addLine(tester, 'Living Room: 2x Cat6');
      final links = _rows(h);
      final first = links[0].structureOrigin!.fieldLabel;

      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async => call.method == 'Clipboard.getData'
            ? <String, dynamic>{'text': 'LR-A\tPP1-01\nLR-B\tPP1-02'}
            : null,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await tester.tap(cellHolding(first));
      await tester.pumpAndSettle();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
      await tester.pumpAndSettle();

      // TWO COLUMNS AND TWO ROWS, from one keystroke.
      expect(links[0].structureOrigin!.fieldLabel, 'LR-A');
      expect(links[0].structureOrigin!.rackLabel, 'PP1-01');
      expect(links[1].structureOrigin!.fieldLabel, 'LR-B');
      expect(links[1].structureOrigin!.rackLabel, 'PP1-02');
    });

    testWidgets('a paste taller than the table creates nothing and says so', (
      tester,
    ) async {
      // THE DEFECT THIS FORBIDS: inventing cables from a spreadsheet.
      // Each would need a room, a media type and a label nobody chose.
      final h = _Harness(_project());
      await _pump(tester, h);
      await _addLine(tester, 'Living Room: 1x Cat6');
      final before = h.doc.links.length;
      final first = _rows(h).first.structureOrigin!.fieldLabel;

      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async => call.method == 'Clipboard.getData'
            ? <String, dynamic>{'text': 'LR-A\nLR-B\nLR-C'}
            : null,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await tester.tap(cellHolding(first));
      await tester.pumpAndSettle();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
      await tester.pumpAndSettle();

      expect(h.doc.links, hasLength(before));
      expect(
        _rows(h).first.structureOrigin!.fieldLabel,
        first,
        reason: 'the rows that WOULD have fitted are not written either',
      );
      expect(find.text(kPasteOverruns(3, 1)), findsOneWidget);
    });
  });

  // ══════════════════════════════════════════════════════════════════
  // M3-C/3, #149 — THE MATRIX AS A TAB
  // ══════════════════════════════════════════════════════════════════

  group('THE TAB STRIP IS FOUR TABS, and the editor opens on the first', () {
    testWidgets('AC-048: it opens in table mode', (tester) async {
      final h = _Harness(_project());
      await _pump(tester, h);

      // The table's own header is on screen and the grid's TOTAL row is
      // not, which is the difference a person sees.
      expect(
        find.text(structureColumnHeader(StructureColumnId.media)),
        findsOneWidget,
      );
      expect(find.text(kMatrixTotalLabel), findsNothing);
    });

    testWidgets('four are offered, because four are built', (tester) async {
      // §4 draws four and the strip finally has four. `Pathways` joined
      // at M3-E/1 (#156) and `Outlets` at M3-H/2 (#167); until the
      // latter this case asserted `Outlets` was ABSENT, because a tab
      // that opens nothing is `UnbuiltView` in a different hat.
      final h = _Harness(_project());
      await _pump(tester, h);

      expect(find.text(kTableTabLabel), findsOneWidget);
      expect(find.text(kMatrixTabLabel), findsOneWidget);
      expect(find.text(kOutletsTabLabel), findsOneWidget);
      expect(find.text(kPathwaysTabLabel), findsOneWidget);
    });

    testWidgets('the Pathways tab opens a real surface', (tester) async {
      // The claim this asserts is the one the strip's own comment makes:
      // no tab here opens nothing. `PathwaysView` renders its own empty
      // state on a project with no pathways, which is a surface, not a
      // blank.
      final h = _Harness(_project());
      await _pump(tester, h);
      await tester.tap(find.text(kPathwaysTabLabel));
      await tester.pumpAndSettle();

      expect(find.byType(PathwaysView), findsOneWidget);
      expect(find.text(kAddPathwayLabel), findsOneWidget);
    });

    testWidgets('the Devices tab opens a real surface (NET-A/2a)', (
      tester,
    ) async {
      // A project with no network-capable device still gets a surface: the
      // view says so in words and points at Show all.
      final h = _Harness(_project());
      await _pump(tester, h);
      await tester.tap(find.text(kDevicesTabLabel));
      await tester.pumpAndSettle();

      expect(find.byType(DevicesView), findsOneWidget);
      expect(find.text(kShowAllDevicesLabel), findsOneWidget);
    });

    testWidgets('Ctrl+D on the Devices tab fills a cell from the row '
        'above (NET-A/2c), the table key with the table meaning', (
      tester,
    ) async {
      final doc = _wholeHouse();
      final rows = buildNetworkTable(doc);
      // THROUGH THE COMMAND: the field's setter is `@internal`, so a test in
      // another package writes it the way the product does.
      DocumentController(doc).run(
        buildSetEntityProperty(
          doc: doc,
          id: rows[0].deviceId,
          field: DeviceField.networkIp,
          to: '10.0.0.1',
          now: DateTime.utc(2026, 10, 3),
          actor: 'test',
        )!,
      );
      final h = _Harness(doc);
      await _pump(tester, h);
      await tester.tap(find.text(kDevicesTabLabel));
      await tester.pumpAndSettle();

      final second = find.descendant(
        of: find.byKey(ValueKey('${rows[1].deviceId.v}:ip')),
        matching: find.byType(TextField),
      );
      await tester.tap(second);
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      final sent = h.deviceEdits.last.single;
      expect(sent.deviceId, rows[1].deviceId);
      expect(sent.column, NetworkColumnId.ip);
      expect(sent.value, '10.0.0.1');
    });

    testWidgets('Ctrl+V on the Devices tab says where it works rather than '
        'doing nothing (docs/04 §3.4)', (tester) async {
      final h = _Harness(_project());
      await _pump(tester, h);
      await tester.tap(find.text(kDevicesTabLabel));
      await tester.pumpAndSettle();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(find.text(kPasteIsCableTableOnly), findsOneWidget);
    });

    testWidgets('Show all survives a trip to another view and back '
        '(NET-A/2b): the editor holds it, not the view', (tester) async {
      final h = _Harness(_project());
      await _pump(tester, h);
      await tester.tap(find.text(kDevicesTabLabel));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      await tester.tap(find.text(kPathwaysTabLabel));
      await tester.pumpAndSettle();
      await tester.tap(find.text(kDevicesTabLabel));
      await tester.pumpAndSettle();

      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    });

    testWidgets('the strip is in §4 order, and Pathways did not move', (
      tester,
    ) async {
      // THE PAYOFF OF HOLDING THE SLOT. `Pathways` shipped in third
      // POSITION while occupying §4's fourth SLOT, precisely so that
      // `Outlets` arriving would not move it under the hand of anybody
      // who had learned where it was. It did not.
      final h = _Harness(_project());
      await _pump(tester, h);

      final labels = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byType(SegmentedButton<StructureEditorTab>),
              matching: find.byType(Text),
            ),
          )
          .map((t) => t.data)
          .toList();
      // `Devices` (NET-A/2a, DR-226) arrived FIFTH, so the four before it
      // are still where a person learned them.
      expect(labels, [
        kTableTabLabel,
        kMatrixTabLabel,
        kOutletsTabLabel,
        kPathwaysTabLabel,
        kDevicesTabLabel,
      ]);
    });

    testWidgets('switching shows the grid and the table goes away', (
      tester,
    ) async {
      final h = _Harness(_project());
      await _pump(tester, h);
      await _showMatrix(tester);

      expect(find.text(kMatrixTotalLabel), findsOneWidget);
      expect(
        find.text(structureColumnHeader(StructureColumnId.media)),
        findsNothing,
      );
    });

    testWidgets('the repeat loop is NOT re-established on the second tab', (
      tester,
    ) async {
      // #149's whole instruction: "a matrix that is its own screen is a
      // second place the repeat loop has to be re-established". The same
      // widget sits above both tabs, so a line typed with the grid
      // showing lands in the grid.
      final h = _Harness(_project());
      await _pump(tester, h);
      await _showMatrix(tester);

      expect(find.byType(DropEntryLoop), findsOneWidget);
      await _addLine(tester, 'Living Room: 3x Cat6');

      expect(_shows(tester, _cell(h, _roomId(h, 'Living Room'), _cat6)), '3');
    });

    testWidgets('and the status bar counts the same drops on both tabs', (
      tester,
    ) async {
      // ONE STATUS BAR, one set of counts, whichever view is up. The
      // exact string rather than a substring, because the band header on
      // the table tab also says "3 drops" and this is about the bar.
      final h = _Harness(_project());
      await _pump(tester, h);
      await _addLine(tester, 'Living Room: 2x Cat6, 1x RG6');
      const summary =
          '3 drops · 0 connected · 3 spare · 1 outlets · '
          '0 pathways';
      expect(find.text(summary), findsOneWidget);

      await _showMatrix(tester);
      expect(find.text(summary), findsOneWidget);
    });

    testWidgets('Ctrl+D on the matrix says so rather than doing nothing', (
      tester,
    ) async {
      // The bindings act on a TABLE cell. Saying that is docs/04 §3.4;
      // printing "put the caret in a cell first" at somebody whose caret
      // is in a grid cell would be worse than an unbound key.
      final h = _Harness(_project());
      await _pump(tester, h);
      await _showMatrix(tester);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
      await tester.pumpAndSettle();

      expect(find.text(kGridKeysAreTableOnly), findsOneWidget);
    });
  });

  group('THE GRID SHOWS THE DERIVATION AND NOTHING IT COUNTED ITSELF', () {
    testWidgets('every cell is the number buildStructureMatrix produced', (
      tester,
    ) async {
      // The same gate the table has, in the grid's terms: not "the cell
      // says 4", but "every cell says whatever core says it says".
      final h = _Harness(_project());
      await _pump(tester, h);
      await _addLine(tester, 'Living Room: 4x Cat6, 2x RG6');
      await _addLine(tester, 'Kitchen: 1x Cat6');
      await _showMatrix(tester);

      final matrix = _matrix(h);
      expect(matrix.rows, hasLength(2));
      for (final row in matrix.rows) {
        for (var c = 0; c < matrix.columns.length; c++) {
          expect(
            _shows(tester, _cell(h, row.locationId!, matrix.columns[c])),
            '${row.counts[c]}',
            reason: '${row.title} by ${matrix.columns[c].v}',
          );
        }
      }
    });

    testWidgets('the grid total is the table drop count', (tester) async {
      final h = _Harness(_project());
      await _pump(tester, h);
      await _addLine(tester, 'Living Room: 4x Cat6, 2x RG6');
      await _showMatrix(tester);

      expect(_matrix(h).dropCount, buildStructureTable(h.doc).dropCount);
      expect(find.text(kMatrixTotalLabel), findsOneWidget);
    });

    testWidgets('an empty room is a row of zeroes, not a missing row', (
      tester,
    ) async {
      // The table omits an empty room and the grid must not: a `0` cell
      // is where a person types `2`.
      final h = _Harness(_project());
      await _pump(tester, h);
      await _addLine(tester, 'Living Room: 1x Cat6');
      await _showMatrix(tester);

      final kit = _roomId(h, 'Kitchen');
      expect(find.byKey(ValueKey(kit)), findsOneWidget);
      expect(_shows(tester, _cell(h, kit, _cat6)), '0');
    });
  });

  group('TYPING A CELL', () {
    testWidgets('0 to 2 creates two drops, and the table tab has them', (
      tester,
    ) async {
      final h = _Harness(_project());
      await _pump(tester, h);
      await _showMatrix(tester);

      await _type(tester, _cell(h, _roomId(h, 'Living Room'), _cat6), '2');

      expect(h.doc.links, hasLength(2));
      await tester.tap(find.text(kTableTabLabel));
      await tester.pumpAndSettle();
      expect(buildStructureTable(h.doc).groups.single.rows, hasLength(2));
    });

    testWidgets('lowering it deletes the highest-sequence spare runs', (
      tester,
    ) async {
      final h = _Harness(_project());
      await _pump(tester, h);
      await _addLine(tester, 'Living Room: 4x Cat6');
      final kept = _rows(h).take(2).map((l) => l.id).toList();
      await _showMatrix(tester);
      final lr = _roomId(h, 'Living Room');

      await _type(tester, _cell(h, lr, _cat6), '2');

      expect(h.doc.links.keys, unorderedEquals(kept));
      expect(_shows(tester, _cell(h, lr, _cat6)), '2');
    });

    testWidgets('a word is refused, the cell springs back and it says why', (
      tester,
    ) async {
      // CR-017's spring-back. A cell that kept the typed text would be
      // showing something no document holds.
      final h = _Harness(_project());
      await _pump(tester, h);
      await _addLine(tester, 'Living Room: 2x Cat6');
      await _showMatrix(tester);
      final lr = _roomId(h, 'Living Room');

      await _type(tester, _cell(h, lr, _cat6), 'two');

      expect(h.doc.links, hasLength(2));
      expect(_shows(tester, _cell(h, lr, _cat6)), '2');
      expect(
        find.textContaining('cannot hold fewer than no drops'),
        findsOneWidget,
      );
    });

    testWidgets('one column does not disturb the one beside it', (
      tester,
    ) async {
      final h = _Harness(_project());
      await _pump(tester, h);
      await _showMatrix(tester);
      final lr = _roomId(h, 'Living Room');

      await _type(tester, _cell(h, lr, _cat6), '4');
      await _type(tester, _cell(h, lr, _rg6), '2');

      expect(_shows(tester, _cell(h, lr, _cat6)), '4');
      expect(_shows(tester, _cell(h, lr, _rg6)), '2');
    });
  });

  group('THE COLUMNS AND THE EMPTY STATE', () {
    testWidgets('the grid opens on §4.2 nine columns, EMT among them', (
      tester,
    ) async {
      // THIS USED TO ASSERT EIGHT with conduit excluded, because the
      // ninth column creates a `Pathway` and nothing in the build could.
      // M3-E/1 built it, so the grid opens on the wireframe's own nine.
      final h = _Harness(_project());
      await _pump(tester, h);
      await _showMatrix(tester);

      expect(_matrix(h).columns, hasLength(9));
      expect(
        _matrix(h).columns.last,
        const MediaTypeId('media.conduit_emt'),
      );
    });

    testWidgets('and the EMT column is excluded from the Σ', (tester) async {
      // §4.2 in as many words: the cells are "tinted and excluded from
      // the Σ drop count (CR-109)". Conduit is not a cable, so a conduit
      // inside the Σ is one item of a total somebody orders cable from.
      final h = _Harness(_project());
      await _pump(tester, h);
      await _addLine(tester, 'Living Room: 2x Cat6');
      await _addLine(tester, 'Living Room: 1x ENT');
      await _showMatrix(tester);

      final row = _matrix(
        h,
      ).rows.firstWhere((r) => r.title == 'Living Room');
      expect(row.dropCount, 2);
      expect(row.pathwayCount, 1);
    });

    testWidgets('Media column is offered, and it is the only add path', (
      tester,
    ) async {
      final h = _Harness(_project());
      await _pump(tester, h);
      await _showMatrix(tester);

      expect(find.text(kAddMediaColumnLabel), findsOneWidget);
      // §4.2's wireframe also draws `+ Room`, and the loop above the
      // grid plus CR-112's panel are already two paths to that rule.
      expect(find.text('Room'), findsNothing);
    });

    testWidgets('a project with no rooms says so, and names the field', (
      tester,
    ) async {
      final h = _Harness(_project(rooms: const []));
      await _pump(tester, h);
      await _showMatrix(tester);

      expect(find.text(kNoRoomsHeadline), findsOneWidget);
      expect(find.text(kNoRoomsDetail), findsOneWidget);

      // AND THE INSTRUCTION IT GIVES IS ONE THIS SURFACE CARRIES OUT.
      // Two presses, not one: the room does not exist, so the first
      // `Enter` takes M3-C/1's offer to create it and the second commits
      // the line — which is the loop working, above a tab it knows
      // nothing about.
      await _addLine(tester, 'Attic: 2x Cat6');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.text(kNoRoomsHeadline), findsNothing);
      expect(h.doc.links, hasLength(2));
      expect(_shows(tester, _cell(h, _roomId(h, 'Attic'), _cat6)), '2');
    });
  });

  group('TWO STRUCTURE BODIES (M3-E/3, #158, CR-113)', () {
    /// Adds a second panel to an existing harness document.
    Uuid addSecondPanel(_Harness h) {
      final command = AddStructureCommand(
        title: 'Guest House Panel',
        designator: 'STR-2',
        now: _now,
        actor: 't',
      )..apply(h.doc);
      return command.bodyId;
    }

    testWidgets('no picker on a ONE-panel project', (tester) async {
      // The ordinary case gains no chrome. A dropdown with one entry is a
      // control that cannot be used and still has to be read past.
      final h = _Harness(_project());
      await _pump(tester, h);
      expect(find.byKey(kStructureBodyPickerKey), findsNothing);
      // The header still NAMES the body in its subtitle; what is absent
      // is the control. Asserting the text was absent would have been a
      // claim about the wrong widget, and it failed for that reason.
      expect(find.text('STR-1 · Media Panel'), findsOneWidget);
    });

    testWidgets('a picker appears the moment there are two', (tester) async {
      final h = _Harness(_project());
      addSecondPanel(h);
      await _pump(tester, h);

      expect(find.byKey(kStructureBodyPickerKey), findsOneWidget);
      // Opens on the FIRST body by designator order, never on "all".
      expect(find.text('STR-1 · Media Panel'), findsWidgets);
    });

    testWidgets("switching the picker changes which body's drops show", (
      tester,
    ) async {
      // DRIVEN THROUGH THE CONTROL rather than by calling the builder
      // with two different ids. The builder was always able to filter;
      // what did not exist was any way for a person to ask it to, and a
      // test that calls it directly would pass on the tree as it was
      // before this task.
      final h = _Harness(_project());
      await _pump(tester, h);
      await _addLine(tester, 'Living Room: 2x Cat6');
      expect(h.doc.links, hasLength(2));

      addSecondPanel(h);
      await _pump(tester, h);
      // STR-1 is selected, so its two drops are on screen.
      expect(find.text(kNoRoomsHeadline), findsNothing);
      expect(_visibleDropCount(tester), 2);

      await tester.tap(find.byKey(kStructureBodyPickerKey));
      await tester.pumpAndSettle();
      await tester.tap(find.text('STR-2 · Guest House Panel').last);
      await tester.pumpAndSettle();

      // STR-2 has no drops of its own. Before the picker existed the
      // table merged both bodies and would still have shown two.
      expect(_visibleDropCount(tester), 0);
    });

    testWidgets('Add outlet opens on the body the picker is showing', (
      tester,
    ) async {
      // THE ASSERTION THAT MATTERS. Before #158 this button reached a
      // planner that refused outright on a two-panel project, so the
      // gesture was dead. Now it carries the selection.
      final h = _Harness(_project());
      addSecondPanel(h);
      await _pump(tester, h);

      await tester.tap(find.text('Add outlet'));
      await tester.pumpAndSettle();

      expect(h.outletPickerOpened, 1);
      expect(
        h.outletPickerBody,
        defaultStructureBody(h.doc)!.id,
        reason: 'the picker opened on STR-1, so the outlet goes to STR-1',
      );
    });
  });

  group('multi-select and batch set (M3-L/3, DR-043)', () {
    /// Ticks one drop, by its id.
    ///
    /// BY ID AND NOT BY A LABEL SPELLING. The label a bare `2x Cat6`
    /// produces comes out of DR-023's fallback chain, so a test that
    /// hardcoded `LR-DATA-1` would be asserting that chain rather than
    /// the selection, and would break the day a media short tag changed.
    Future<void> tickId(WidgetTester tester, Uuid id) async {
      await tester.tap(find.byKey(ValueKey('select-${id.v}')));
      await tester.pumpAndSettle();
    }

    /// Picks a column and a value on the bar.
    ///
    /// USES `ROUGH-IN`, WHICH IS A DEFAULT COLUMN, and that is the point
    /// rather than a convenience: the bar offers the columns the TABLE is
    /// showing, so `FIELD TERM` is absent until somebody switches it on.
    /// One case below drives that path deliberately.
    Future<void> setColumn(
      WidgetTester tester,
      String column,
      String value,
    ) async {
      await tester.tap(find.byKey(const ValueKey('batch-column')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(column).last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('batch-value')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(value).last);
      await tester.pumpAndSettle();
    }

    testWidgets('the bar is absent until something is ticked', (tester) async {
      // A permanent strip of controls that do nothing on an empty
      // selection is the defect `shell_tabs_test.dart` gates.
      final h = _Harness(_project());
      await _pump(tester, h);
      await _addLine(tester, 'Living Room: 2x Cat6');
      expect(find.byKey(const ValueKey('batch-column')), findsNothing);

      await tickId(tester, _rows(h).first.id);
      expect(find.byKey(const ValueKey('batch-column')), findsOneWidget);
      expect(find.text('1 selected'), findsOneWidget);
    });

    testWidgets('ONE BATCH for the whole selection, not one call per row', (
      tester,
    ) async {
      final h = _Harness(_project());
      await _pump(tester, h);
      await _addLine(tester, 'Living Room: 3x Cat6');

      await tester.tap(find.byKey(const ValueKey('select-all')));
      await tester.pumpAndSettle();
      expect(find.text('3 selected'), findsOneWidget);

      h.batchSizes.clear();
      await setColumn(tester, 'ROUGH-IN', 'PULLED');

      // THE CLAIM IS ONE UNDO ENTRY. A loop calling onEdit per row leaves
      // the document identical and the undo stack three deep, and no
      // assertion about the cells could tell the difference.
      expect(h.batchSizes, [3]);
      expect(
        h.doc.links.values
            .where((l) => l.roughInStatus == RoughInStatus.pulled)
            .length,
        3,
      );
    });

    testWidgets('an OPTIONAL column is offered once it is switched on', (
      tester,
    ) async {
      // NOTES, not FIELD TERM: that column became a DEFAULT at DR-046,
      // so it is offered immediately and no longer drives this path.
      // The bar offers what the table shows, and this is the whole walk
      // a person makes to bulk-set something optional.
      //
      // IT ALSO EXERCISES THE TEXT-VALUE ARM, which no other case does:
      // a column with no closed set gets a box and commits on Enter
      // rather than on selection.
      final h = _Harness(_project());
      await _pump(tester, h);
      await _addLine(tester, 'Living Room: 2x Cat6');
      await tester.tap(find.byKey(const ValueKey('select-all')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('batch-column')));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(DropdownMenuItem<StructureColumnId>),
          matching: find.text(
            structureColumnHeader(StructureColumnId.notes),
          ),
        ),
        findsNothing,
        reason: 'not a default column, so the bar cannot set it yet',
      );
      await tester.tapAt(Offset.zero);
      await tester.pumpAndSettle();

      // The ⚙ Columns path a person walks, including the ensureVisible
      // the menu has needed since it grew past one screen at M3-J/3.
      await tester.tap(find.text('Columns'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('NOTES'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('NOTES'));
      await tester.pumpAndSettle();
      // The menu stays open on purpose, so it has to be dismissed.
      await tester.tapAt(Offset.zero);
      await tester.pumpAndSettle();

      h.batchSizes.clear();
      await tester.tap(find.byKey(const ValueKey('batch-column')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('NOTES').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('batch-value-text')),
        'pulled with the AV trunk',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(h.batchSizes, [2]);
      expect(
        h.doc.links.values.every(
          (l) => l.notes == 'pulled with the AV trunk',
        ),
        isTrue,
      );
    });

    testWidgets('A BATCH NEVER WRITES TO A ROW BEHIND A FILTER', (
      tester,
    ) async {
      // The one genuinely dangerous outcome on this surface, and the
      // user's own call on 2026-08-11: the button would look safe, the
      // undo entry would name a count matching nothing on screen, and it
      // would surface weeks later on a printed sheet.
      final h = _Harness(_project());
      await _pump(tester, h);
      await _addLine(tester, 'Living Room: 2x Cat6');
      await _addLine(tester, 'Kitchen: 2x Cat6');

      await tester.tap(find.byKey(const ValueKey('select-all')));
      await tester.pumpAndSettle();
      expect(find.text('4 selected'), findsOneWidget);

      await tester.tap(find.text('All rooms'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Living Room').last);
      await tester.pumpAndSettle();

      // The count SPLITS rather than shrinking silently.
      expect(find.text('2 selected'), findsOneWidget);
      expect(find.text('2 more ticked, off screen'), findsOneWidget);

      h.batchSizes.clear();
      await setColumn(tester, 'ROUGH-IN', 'PULLED');
      expect(h.batchSizes, [2]);

      // And the Kitchen's two are untouched.
      final livingRoom = _roomId(h, 'Living Room');
      for (final link in h.doc.links.values) {
        final room = h.doc.outlets[link.structureOrigin!.outletId]?.locationId;
        expect(
          link.roughInStatus,
          room == livingRoom ? RoughInStatus.pulled : RoughInStatus.planned,
          reason: link.structureOrigin!.fieldLabel,
        );
      }
    });

    testWidgets('the unique columns are not offered (CR-113)', (tester) async {
      // One value across N rows is refused by the builder on every row
      // after the first, so offering them is a control that does nothing.
      final h = _Harness(_project());
      await _pump(tester, h);
      await _addLine(tester, 'Living Room: 2x Cat6');
      await tickId(tester, _rows(h).first.id);

      await tester.tap(find.byKey(const ValueKey('batch-column')));
      await tester.pumpAndSettle();
      expect(
        find.text(structureColumnHeader(StructureColumnId.roughIn)),
        findsWidgets,
      );
      expect(
        find.descendant(
          of: find.byType(DropdownMenuItem<StructureColumnId>),
          matching: find.text(
            structureColumnHeader(StructureColumnId.fieldLabel),
          ),
        ),
        findsNothing,
      );
    });

    testWidgets('RACK TERM IS NOT SET BY FIELD TERM (DR-046)', (
      tester,
    ) async {
      // The defect this ruling removed: the two columns read one field,
      // so setting the wall end made the panel end claim the same thing.
      final h = _Harness(_project());
      await _pump(tester, h);
      await _addLine(tester, 'Living Room: 2x Cat6');

      await tester.tap(find.byKey(const ValueKey('select-all')));
      await tester.pumpAndSettle();
      await setColumn(tester, 'FIELD TERM', 'PUNCHDOWN');

      for (final l in h.doc.links.values) {
        expect(l.structureOrigin!.terminationField, TerminationType.punchdown);
        expect(
          l.structureOrigin!.terminationRack,
          isNull,
          reason: 'nothing infers the rack end from the field end',
        );
      }
    });

    testWidgets('"same as field" is a GESTURE, and writes real values', (
      tester,
    ) async {
      // Nine Cat6 runs in ten match at both ends. That convenience lives
      // in a button rather than in a default, so a schedule can still
      // tell a stated value from one the product assumed.
      final h = _Harness(_project());
      await _pump(tester, h);
      await _addLine(tester, 'Living Room: 2x Cat6');

      await tester.tap(find.byKey(const ValueKey('select-all')));
      await tester.pumpAndSettle();
      await setColumn(tester, 'FIELD TERM', 'PUNCHDOWN');

      h.batchSizes.clear();
      await tester.tap(find.byKey(const ValueKey('batch-same-as-field')));
      await tester.pumpAndSettle();

      // ONE batch, so one undo entry for the whole copy.
      expect(h.batchSizes, [2]);
      for (final l in h.doc.links.values) {
        expect(l.structureOrigin!.terminationRack, TerminationType.punchdown);
      }
    });

    testWidgets('it skips rows whose field end is unknown', (tester) async {
      // Copying "nobody has said" onto a second column asserts nothing
      // and would make the two agree for the wrong reason (G4).
      final h = _Harness(_project());
      await _pump(tester, h);
      await _addLine(tester, 'Living Room: 1x Cat6');

      await tester.tap(find.byKey(const ValueKey('select-all')));
      await tester.pumpAndSettle();
      h.batchSizes.clear();
      await tester.tap(find.byKey(const ValueKey('batch-same-as-field')));
      await tester.pumpAndSettle();

      expect(h.batchSizes, isEmpty);
      expect(find.textContaining('nothing to copy across'), findsOneWidget);
      expect(
        h.doc.links.values.single.structureOrigin!.terminationRack,
        isNull,
      );
    });

    testWidgets('clear selection puts the bar away', (tester) async {
      final h = _Harness(_project());
      await _pump(tester, h);
      await _addLine(tester, 'Living Room: 2x Cat6');
      await tickId(tester, _rows(h).first.id);
      expect(find.byKey(const ValueKey('batch-column')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('batch-clear')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('batch-column')), findsNothing);
    });

    testWidgets('a tick follows its DROP, not its row position', (
      tester,
    ) async {
      // The reason the checkbox is keyed on the link, like the row: a
      // filter change reshuffles the list, and a positional key would
      // hand row 1's tick to whatever cable is first afterwards.
      final h = _Harness(_project());
      await _pump(tester, h);
      await _addLine(tester, 'Living Room: 1x Cat6');
      await _addLine(tester, 'Kitchen: 1x Cat6');
      final kitchen = _roomId(h, 'Kitchen');
      final kitchenDrop = h.doc.links.values.firstWhere(
        (l) =>
            h.doc.outlets[l.structureOrigin!.outletId]?.locationId == kitchen,
      );
      await tickId(tester, kitchenDrop.id);
      expect(find.text('1 selected'), findsOneWidget);

      await tester.tap(find.text('All rooms'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kitchen').last);
      await tester.pumpAndSettle();
      // Still one selected and NOT off screen: the Kitchen drop is the
      // one visible now.
      expect(find.text('1 selected'), findsOneWidget);
      expect(find.textContaining('more ticked, off screen'), findsNothing);
    });
  });

  group('the SERVICE picker, both entry paths (DR-025 §11.24.5, #587)', () {
    /// Ticks one drop by id, and picks a column and value on the batch
    /// bar. LOCAL COPIES: the batch group above owns its own, and sharing
    /// them would couple two groups that ask different questions.
    Future<void> tick(WidgetTester tester, Uuid id) async {
      await tester.tap(find.byKey(ValueKey('select-${id.v}')));
      await tester.pumpAndSettle();
    }

    Future<void> setColumn(
      WidgetTester tester,
      String column,
      String value,
    ) async {
      await tester.tap(find.byKey(const ValueKey('batch-column')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(column).last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('batch-value')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(value).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text(value).last);
      await tester.pumpAndSettle();
    }

    /// Every family the document records, read off BOTH places §11.24.6
    /// stores it, so a half-write cannot pass as a success.
    ({Set<String> services, Set<String> nets}) families(RackDocument doc) => (
      services: {
        for (final l in doc.links.values)
          for (final svc in l.services) svc.signalFamily.v,
      },
      nets: {for (final n in doc.nets.values) n.signalFamily.v},
    );

    /// Opens the picker on one row's SERVICE cell.
    Future<void> openCell(WidgetTester tester, Uuid linkId) async {
      await tester.tap(find.byKey(ValueKey('service-${linkId.v}')));
      await tester.pumpAndSettle();
    }

    /// Clicks a row in the open panel.
    ///
    /// SCROLLS TO IT FIRST, and that is a fact about the product rather
    /// than test plumbing: the panel is a `SingleChildScrollView` capped
    /// at [kFamilyPickerMaxHeight], the groups run in domain-id order, and
    /// `video.digital` sorts LAST, so `VID·HDBaseT (5Play)` lays out some
    /// 1800 points below the fold. A person reaches it by typing in the
    /// filter box, which is the case below; a person who scrolls instead
    /// is doing this.
    Future<void> pick(WidgetTester tester, String label) async {
      await tester.ensureVisible(find.text(label).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
    }

    Future<void> filter(WidgetTester tester, String query) async {
      await tester.enterText(
        find.byKey(const ValueKey('service-filter')),
        query,
      );
      await tester.pumpAndSettle();
    }

    testWidgets('the labels this group types are the ones the catalog '
        'actually spells', (tester) async {
      // PINNED ONCE, HERE, AND DERIVED EVERYWHERE ELSE. The first draft
      // of this group typed `V·AV-over-IP` and `V·HDBaseT 5Play`, which
      // are the shapes canon §11.24.1's PROSE uses; the catalog spells
      // neither. Both cases failed for a reason that had nothing to do
      // with the picker. One test now owns the literal, so a respelling
      // breaks this and reads as what it is.
      final h = _Harness(_project());
      final r = h.doc.registries;
      String label(String id) => signalFamilyCellLabel(
        r.signalDomains[r.signalFamilies[SignalFamilyId(id)]!.domain]!,
        r.signalFamilies[SignalFamilyId(id)]!,
      );
      expect(label('video.hdbaset'), 'VID·HDBaseT (5Play)');
      expect(label('video.avoip'), 'VID·AV-over-IP (SDVoE / JPEG XS / NDI)');
      expect(label('structure.undetermined'), 'STR·Undetermined home run');
    });

    testWidgets('the precise path: one cell, one picked row', (tester) async {
      final h = _Harness(_project());
      await _pump(tester, h);
      await _addLine(tester, 'Living Room: 1x Cat6');
      expect(families(h.doc).services, {'structure.undetermined'});

      await openCell(tester, _rows(h).single.id);
      await pick(tester, 'VID·HDBaseT (5Play)');

      final after = families(h.doc);
      expect(after.services, {'video.hdbaset'});
      expect(
        after.nets,
        {'video.hdbaset'},
        reason:
            '§11.24.6: nothing reads the Net, so only naming it sees '
            'a half-write',
      );
    });

    testWidgets('the fast path: many rows, one value', (tester) async {
      final h = _Harness(_project());
      await _pump(tester, h);
      await _addLine(tester, 'Living Room: 3x Cat6');
      for (final row in _rows(h)) {
        await tick(tester, row.id);
      }

      await setColumn(
        tester,
        'SERVICE',
        'VID·AV-over-IP (SDVoE / JPEG XS / NDI)',
      );

      expect(families(h.doc).services, {'video.avoip'});
      expect(families(h.doc).nets, {'video.avoip'});
    });

    testWidgets('the filter NARROWS and never commits', (tester) async {
      // THE DISTINCTION #587 IS ABOUT. SERVICE was grouped with MEDIA as
      // "needs a picker, not a text box"; a box that committed what was
      // typed would put that straight back. Typing must change what is
      // VISIBLE and nothing else.
      final h = _Harness(_project());
      await _pump(tester, h);
      await _addLine(tester, 'Living Room: 1x Cat6');

      await openCell(tester, _rows(h).single.id);
      expect(find.text('VID·HDBaseT (5Play)'), findsOneWidget);
      expect(find.text('DIG·Dante'), findsOneWidget);

      // `hbt` is the shortTag `@signal=` already accepts, so the picker
      // and the DSL share one vocabulary rather than acquiring a second.
      await filter(tester, 'hbt');
      expect(find.text('VID·HDBaseT (5Play)'), findsOneWidget);
      expect(find.text('DIG·Dante'), findsNothing);
      expect(
        families(h.doc).services,
        {'structure.undetermined'},
        reason: 'typing a whole family name must still write nothing',
      );

      await pick(tester, 'VID·HDBaseT (5Play)');
      expect(families(h.doc).services, {'video.hdbaset'});
    });

    testWidgets('a filter matching nothing says so and offers nothing', (
      tester,
    ) async {
      final h = _Harness(_project());
      await _pump(tester, h);
      await _addLine(tester, 'Living Room: 1x Cat6');

      await openCell(tester, _rows(h).single.id);
      await filter(tester, 'zzz');
      expect(find.textContaining('No signal family matches'), findsOneWidget);
      expect(
        find.textContaining('cannot be created here'),
        findsOneWidget,
        reason: 'RJ-012 in the one place a user meets it',
      );
      expect(find.text('VID·HDBaseT (5Play)'), findsNothing);
    });

    testWidgets('the menu is grouped, with a header per domain', (
      tester,
    ) async {
      final h = _Harness(_project());
      await _pump(tester, h);
      await _addLine(tester, 'Living Room: 1x Cat6');

      await openCell(tester, _rows(h).single.id);
      // Ordered by domain id, which is `schematic_filter.dart`'s order,
      // so the same eight things are not in two orders in one product.
      final groups = signalFamilyCellGroups(h.doc.registries);
      expect(
        groups.map((g) => g.tagPrefix).take(3),
        [
          'AUD',
          'DIG',
          'CTL',
        ],
        reason: 'audio.analog, audio.digital, ctl',
      );
      expect(
        find.textContaining('VID  Digital Video'),
        findsOneWidget,
        reason: 'the header names the domain, not just its tag',
      );
    });

    testWidgets('SERVICE offers no unknown row, unlike FIELD TERM', (
      tester,
    ) async {
      // G4 drawing a real distinction: a termination is nullable because
      // nobody deciding is a genuine absence, and a Service always HAS a
      // family, so `structure.undetermined` is an ordinary choice.
      final h = _Harness(_project());
      await _pump(tester, h);
      final options = structureCellChoices(
        StructureColumnId.service,
        h.doc,
      );
      expect(options, isNotNull);
      expect(options, isNot(contains(kUnknownCell)));
      expect(
        structureCellChoices(StructureColumnId.fieldTerm, h.doc),
        contains(kUnknownCell),
      );
    });

    testWidgets('a family the registries do not hold costs one cell, not '
        'the table', (tester) async {
      // THE CRASH THIS COLUMN WOULD OTHERWISE HAVE INTRODUCED.
      // `DropdownButton` asserts exactly one item matches its value, and
      // `typeCell` prints a bare id when a `Service` names a family the
      // registries lack, which is a spelling no menu offers. The
      // enum-backed columns cannot reach it because the enum IS their
      // menu, so SERVICE is the first column where a document can say
      // something the control cannot represent.
      final h = _Harness(_project());
      await _pump(tester, h);
      await _addLine(tester, 'Living Room: 1x Cat6');
      final linkId = _rows(h).single.id;

      h.doc.registries.signalFamilies.remove(
        const SignalFamilyId('structure.undetermined'),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await _pump(tester, h);

      expect(tester.takeException(), isNull, reason: 'the table still builds');
      expect(
        find.byKey(ValueKey('service-${linkId.v}')),
        findsNothing,
        reason: 'no picker on a value the picker cannot offer',
      );
      expect(
        find.text('structure.undetermined'),
        findsOneWidget,
        reason: 'the stored id is shown rather than silently dropped',
      );
    });
  });

  group('the LANDS ON cell after DR-074 (`#724`)', () {
    /// A panel with [positions] rear punchdowns, so `freePanelPositions`
    /// has something to walk.
    void addPanel(RackDocument doc, {int positions = 2}) {
      const tplId = 'tpl.pp-ui';
      doc.templates['$tplId@1'] = TemplateSnapshot(
        templateId: const TemplateId(tplId),
        version: 1,
        contentHash: 'sha256:$tplId',
        capturedAt: _now,
        body: TemplateBody(
          manufacturer: 'Generic',
          model: 'PP-UI',
          displayName: 'Patch Panel',
          typePrefix: 'PP',
          ports: [
            for (var i = 1; i <= positions; i++)
              PortDef(
                key: PortKey('rear.$i'),
                label: i.toString().padLeft(2, '0'),
                connector: const ConnectorTypeId('conn.punchdown_110'),
                signalFamily: const SignalFamilyId('net.ethernet'),
                face: Face.rear,
                position: const PanelPosition(
                  ruOffset: 0,
                  xTwelfth: 0,
                  xFineNm: Len.zero,
                  yFineNm: Len.zero,
                ),
                order: FracIndex('a$i'),
              ),
          ],
        ),
      );
      doc.devices[const Uuid('dev-pp-ui')] = DeviceInstance(
        id: const Uuid('dev-pp-ui'),
        kind: DeviceKind.rackDevice,
        templateRef: const TemplateRef(
          templateId: TemplateId(tplId),
          version: 1,
          contentHash: 'sha256:$tplId',
        ),
        designator: 'PP-1',
        name: 'Patch Panel',
        placement: const OffRackPlacement(),
        meta: _meta(),
      );
    }

    /// Turns `LANDS ON` on, the way a person does. It is an OPTIONAL
    /// column (DR-071 §11.70), so without this the cell under test is not
    /// built at all and a finder would pass or fail for the wrong reason.
    Future<void> showLandsOn(WidgetTester tester) async {
      await tester.tap(find.text('Columns'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('LANDS ON'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('LANDS ON'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
    }

    /// Every option the `LANDS ON` menus on screen offer.
    ///
    /// READS THE ITEMS RATHER THAN TAPPING, because the row carries
    /// several dropdowns and picking one by position passes for the wrong
    /// column the next time a column is added.
    Set<String> landingOptions(WidgetTester tester) => {
      for (final menu in tester.widgetList<DropdownButton<String>>(
        find.byType(DropdownButton<String>),
      ))
        for (final item in menu.items ?? const <DropdownMenuItem<String>>[])
          if (item.value case final v?) v,
    };

    testWidgets('a LANDED row offers NOT LANDED, where it showed text', (
      tester,
    ) async {
      // DR-071 §11.70.3 drew a landed row as TEXT because every use of a
      // control there was refused. DR-074 §11.73.1 gives that row two
      // commands, so the control is back and this is what changed on
      // screen.
      final doc = _project();
      addPanel(doc);
      final h = _Harness(doc);
      await _pump(tester, h);
      await _addLine(tester, 'Living Room: 1x Cat6 @panel=PP-1');
      await tester.pumpAndSettle();
      expect(
        doc.links.values.single.conductors.first.to,
        isA<PortEndpoint>(),
        reason: 'the line landed it, so this row is the landed case',
      );

      await showLandsOn(tester);
      expect(landingOptions(tester), contains(kUnlandCell));
    });

    testWidgets('an UNLANDED row is offered no way to unland', (tester) async {
      final doc = _project();
      addPanel(doc);
      final h = _Harness(doc);
      await _pump(tester, h);
      await _addLine(tester, 'Living Room: 1x Cat6');
      await tester.pumpAndSettle();
      expect(
        doc.links.values.single.conductors.first.to,
        isNot(isA<PortEndpoint>()),
      );

      await showLandsOn(tester);
      final options = landingOptions(tester);
      expect(options, contains('PP-1'));
      expect(
        options,
        isNot(contains(kUnlandCell)),
        reason:
            'an option whose every use is refused is `#711` drawn on '
            'purpose',
      );
    });
  });

  group('PLAN-E/5: the drop table arms a pin (DR-141, DR-143)', () {
    testWidgets('A SECONDARY TAP ON A ROW ARMS THAT ROW, and no other', (
      tester,
    ) async {
      // The gesture PLAN-E/3 built and a gate refused as unreachable
      // (DR-141 §11.140.7). It is reachable now: the shell owns the arm
      // controller above the tabs and the Plan view is in the strip.
      final h = _Harness(_project());
      await _pump(tester, h);
      await _addLine(tester, 'Living Room: 2x Cat6');

      final table = buildStructureTable(h.doc);
      final wanted = table.groups.single.rows.last.linkId;

      await tester.tapAt(
        tester.getCenter(find.byKey(ValueKey(wanted))),
        buttons: kSecondaryButton,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(kPinOnPlanMenuLabel));
      await tester.pumpAndSettle();

      // THE ROW IT IS, not whichever row a bare finder reached first:
      // every row in this table renders the same column headers and a
      // `byType().first` would have located the wrong one and passed.
      expect(h.armedOnPlan, [wanted]);
    });

    testWidgets('is ABSENT, not inert, when the host offers no plan', (
      tester,
    ) async {
      // DR-091's rule at the size of one menu item. A row menu whose only
      // entry does nothing is the untruth that ruling keeps tabs out of
      // the strip to avoid.
      final h = _Harness(_project())..offerPinOnPlan = false;
      await _pump(tester, h);
      await _addLine(tester, 'Living Room: 2x Cat6');

      final table = buildStructureTable(h.doc);
      await tester.tapAt(
        tester.getCenter(
          find.byKey(ValueKey(table.groups.single.rows.last.linkId)),
        ),
        buttons: kSecondaryButton,
      );
      await tester.pumpAndSettle();

      expect(find.text(kPinOnPlanMenuLabel), findsNothing);
      expect(h.armedOnPlan, isEmpty);
    });
  });
  group('the header removes the whole Structure (`#877`, DR-160)', () {
    testWidgets('the menu is ABSENT until there is a body to remove', (
      tester,
    ) async {
      // DR-091's rule at the size of one item: a control with nothing to
      // act on is absent rather than present and inert. A blank project
      // has no Structure device and the quick-add loop offers to create
      // one.
      await _pump(tester, _Harness(_project(withBody: false)));
      expect(find.byKey(kStructureHeaderMenuKey), findsNothing);
      expect(
        find.text('No Structure device yet'),
        findsOneWidget,
        reason:
            'the header names the empty case rather than rendering '
            'blank, so the absence above is the control and not the tab',
      );

      // TWO FIXTURES AND NOT A GESTURE BETWEEN THEM. Creating a body from
      // here is the quick-add loop's two-press offer, which
      // `structure_removal_route_test.dart` drives against the real
      // session; what this case is about is the control, and the shortest
      // honest way to show it appears is to pump a project that has one.
      await _pump(tester, _Harness(_project()));
      expect(find.byKey(kStructureHeaderMenuKey), findsOneWidget);
    });

    testWidgets('and it asks the host for the body the editor is SHOWING', (
      tester,
    ) async {
      final h = _Harness(_project());
      await _pump(tester, h);
      await _addLine(tester, 'Living Room: 2x Cat6');

      await tester.tap(find.byKey(kStructureHeaderMenuKey));
      await tester.pumpAndSettle();
      await tester.tap(find.text(kRemoveStructureLabel));
      await tester.pumpAndSettle();

      expect(h.removedStructures, [h.doc.structures.keys.single]);
    });

    testWidgets('the editor itself removes NOTHING, which is the seam', (
      tester,
    ) async {
      // The confirmation and the transaction are the shell's, for the
      // reason `OutletsActions.onRemove` gives: a dialog needs a
      // `BuildContext` the session owns.
      final h = _Harness(_project());
      await _pump(tester, h);
      await _addLine(tester, 'Living Room: 2x Cat6');

      await tester.tap(find.byKey(kStructureHeaderMenuKey));
      await tester.pumpAndSettle();
      await tester.tap(find.text(kRemoveStructureLabel));
      await tester.pumpAndSettle();

      expect(h.doc.structures, hasLength(1));
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('IT IS A MENU AND NOT A FOURTH BUTTON IN THE ROW', (
      tester,
    ) async {
      // §11.159.6, settled by the user. The three text buttons beside it
      // are harmless and sit a few pixels away; the largest delete in the
      // product does not join that row. A test that only checked the
      // label would pass on either layout, so this asserts the label is
      // NOT in the tree until the menu is opened.
      final h = _Harness(_project());
      await _pump(tester, h);
      await _addLine(tester, 'Living Room: 2x Cat6');

      expect(find.text(kRemoveStructureLabel), findsNothing);

      await tester.tap(find.byKey(kStructureHeaderMenuKey));
      await tester.pumpAndSettle();
      expect(find.text(kRemoveStructureLabel), findsOneWidget);
    });
  });
}
