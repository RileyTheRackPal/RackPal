// docs/08-pdf-export.md §3 — the wiring schedule's row model and its two
// projections.
//
// THE THREE THINGS THIS FILE EXISTS TO MAKE UNWRITABLE:
//
//  1. **A row read through `Link.linkClass`.** That field is inert unless
//     `linkClassLocked` (DR-008 §11.8.2), so reading it directly shows a
//     default nobody chose. A jumper is off the Pull Sheet by default, so
//     misreading the class silently deletes a real pull from the sheet an
//     installer works from — or invents one. The `effectiveLinkClassOf`
//     group below is the gate.
//  2. **An undetermined class defaulted into a category.** `null` is an
//     answer (G4). It is shown in its own band, counted, and its footage
//     is kept out of a room's subtotal.
//  3. **Two table builders.** §3.1 is explicit that the presets are "two
//     presets of one derivation". The `ONE DERIVATION` group asserts the
//     two views project the SAME row objects and that a column appearing
//     on both sheets prints the identical string on both.

import 'package:rackmate_core/rackmate_core.dart';
import 'package:test/test.dart';

final _when = DateTime.utc(2026, 7, 28);

EntityMeta _meta() =>
    EntityMeta(createdAt: _when, updatedAt: _when, updatedBy: 'test');

/// A document under construction, with one helper per entity so a test
/// can state its scenario in a handful of lines rather than forty.
final class _Doc {
  _Doc()
    : doc = RackDocument(
        id: const Uuid('doc-sched'),
        appVersion: 'test',
        createdAt: _when,
        modifiedAt: _when,
        meta: _meta(),
      );

  final RackDocument doc;
  int _seq = 0;

  Uuid _mint(String prefix) => Uuid('$prefix-${_seq++}');

  Uuid room(String name, {Len? estimatedRunLength, String code = 'RM'}) {
    final id = _mint('loc');
    doc.locations[id] = Location(
      id: id,
      kind: LocationKind.room,
      name: name,
      code: code,
      order: FracIndex('a$_seq'),
      meta: _meta(),
      estimatedRunLengthFromRack: estimatedRunLength,
    );
    return id;
  }

  Uuid rack(String designator, {Uuid? locationId}) {
    final id = _mint('rack');
    doc.racks[id] = Rack(
      id: id,
      name: designator,
      designator: designator,
      heightU: 42,
      order: FracIndex('a$_seq'),
      meta: _meta(),
      locationId: locationId,
    );
    return id;
  }

  Uuid pathway(String name) {
    final id = _mint('path');
    doc.pathways[id] = Pathway(
      id: id,
      name: name,
      order: FracIndex('a$_seq'),
      meta: _meta(),
    );
    return id;
  }

  Uuid outlet(
    String designation, {
    Uuid? locationId,
    Len? nominalRunLength,
    Uuid? pathwayId,
  }) {
    final id = _mint('outlet');
    doc.outlets[id] = Outlet(
      id: id,
      structureBodyId: const Uuid('structure-1'),
      designation: designation,
      order: FracIndex('a$_seq'),
      meta: _meta(),
      locationId: locationId,
      nominalRunLength: nominalRunLength,
      pathwayId: pathwayId,
    );
    return id;
  }

  Uuid device(
    String designator, {
    Uuid? rackId,
    int ruIndex = 1,
    Face face = Face.rear,
    Uuid? hostDeviceId,
    Uuid? locationId,
  }) {
    final id = _mint('dev');
    doc.devices[id] = DeviceInstance(
      id: id,
      kind: DeviceKind.rackDevice,
      templateRef: const TemplateRef(
        templateId: TemplateId('tpl.x'),
        version: 1,
        contentHash: 'sha256:tpl.x',
      ),
      designator: designator,
      name: designator,
      placement: switch ((rackId, hostDeviceId)) {
        (final Uuid rack, _) => RailPlacement(
          rackId: rack,
          ruIndex: ruIndex,
          face: face,
        ),
        (_, final Uuid host) => ShelfPlacement(
          hostDeviceId: host,
          order: const FracIndex('a0'),
        ),
        _ => const OffRackPlacement(),
      },
      locationId: locationId,
      meta: _meta(),
    );
    return id;
  }

  Uuid port(Uuid deviceId, String designator, {String? userLabel}) {
    final id = _mint('port');
    doc.ports[id] = Port(
      id: id,
      deviceId: deviceId,
      designator: designator,
      userLabel: userLabel,
    );
    return id;
  }
}

/// A `Link` on [d].
///
/// A FREE FUNCTION, not a method on the builder: a test that states
/// three cables in a row would otherwise read as a cascade on a builder
/// object, which puts the punctuation where the cables should be.
Uuid _link(
  _Doc d, {
  required String designator,
  Endpoint? from,
  Endpoint? to,
  LinkClass linkClass = LinkClass.fieldCable,
  bool linkClassLocked = false,
  String? fieldLabel,
  String? rackLabel,
  Uuid? outletId,
  Uuid? pathwayId,
  Len? cutLength,
  JacketColorId? jacketColorId,
  JacketColorId? jacketColorPulledId,
  MediaTypeId media = const MediaTypeId('media.cat6a_futp'),
  SignalFamilyId? signalFamily,
  List<Conductor>? conductors,
  JacketRating? jacket,
  CrossoverKind? crossover,
  RoughInStatus roughInStatus = RoughInStatus.planned,
  // NULLABLE FROM M3-J, so a home run can say "nobody has decided how
  // this wall end is finished" (G4, CR-114). Defaults to `keystone` so
  // every existing case in this file is unchanged.
  TerminationType? terminationField = TerminationType.keystone,
  int order = 0,
}) {
  final id = d._mint('link');
  d.doc.links[id] = Link(
    id: id,
    designator: designator,
    media: media,
    order: FracIndex('a${order.toString().padLeft(4, '0')}'),
    meta: _meta(),
    linkClass: linkClass,
    linkClassLocked: linkClassLocked,
    pathwayId: pathwayId,
    cutLength: cutLength,
    jacket: jacket,
    jacketColorId: jacketColorId,
    jacketColorPulledId: jacketColorPulledId,
    crossover: crossover,
    roughInStatus: roughInStatus,
    services: signalFamily == null
        ? null
        : [
            Service(
              id: 'svc-1',
              signalFamily: signalFamily,
              netId: const Uuid('net-1'),
            ),
          ],
    conductors:
        conductors ??
        (from == null || to == null ? null : [Conductor(from: from, to: to)]),
    structureOrigin: fieldLabel == null
        ? null
        : StructureOrigin(
            structureBodyId: const Uuid('structure-1'),
            outletId: outletId ?? const Uuid('outlet-none'),
            fieldLabel: fieldLabel,
            rackLabel: rackLabel,
            terminationField: terminationField,
          ),
  );
  return id;
}

ScheduleView _pull(
  RackDocument doc, {
  bool includeJumpersAndPowerCords = false,
  ScheduleSort? sort,
  ScheduleGrouping? grouping,
}) => scheduleViewOf(
  doc,
  preset: SchedulePreset.pullSheet,
  sort: sort,
  grouping: grouping,
  includeJumpersAndPowerCords: includeJumpersAndPowerCords,
);

ScheduleView _term(
  RackDocument doc, {
  bool includeJumpersAndPowerCords = false,
  ScheduleSort? sort,
  ScheduleGrouping? grouping,
}) => scheduleViewOf(
  doc,
  preset: SchedulePreset.terminationSchedule,
  sort: sort,
  grouping: grouping,
  includeJumpersAndPowerCords: includeJumpersAndPowerCords,
);

ScheduleEntry _rowFor(ScheduleView view, String designator) =>
    view.rows.firstWhere((r) => r.designator == designator);

void main() {
  // ═══════════════════════════════════════════════════════════════════
  // CR-105 / AC-035 — CORRECT AT ZERO ROWS
  // ═══════════════════════════════════════════════════════════════════
  group('populating live from an EMPTY project (CR-105, AC-035)', () {
    test('an empty document derives a schedule with no rows rather than '
        'refusing to derive one', () {
      final schedule = buildSchedule(_Doc().doc);
      expect(schedule.rowCount, 0);
      expect(schedule.rows, isEmpty);
    });

    test('both presets project an empty document and both say the '
        'DOCUMENT is empty, not that everything was filtered', () {
      final doc = _Doc().doc;
      for (final view in [_pull(doc), _term(doc)]) {
        expect(view.rowCount, 0);
        expect(view.groups, isEmpty);
        expect(view.isEmptyDocument, isTrue);
        expect(
          view.exclusions.total,
          0,
          reason:
              'nothing was hidden — a tab that blames a filter for an '
              'empty document sends the user hunting for a toggle',
        );
      }
    });

    test('an empty schedule footage is a MEASURED ZERO, not unknown', () {
      // `totals.dart` rule 1: null means "we do not know"; a rollup
      // nobody contributed to really is zero. A tab reading `— ft` on a
      // project with no cables would be claiming ignorance it does not
      // have.
      final view = _pull(_Doc().doc);
      expect(view.footage.value, Len.zero);
      expect(view.footage.isUnknown, isFalse);
      expect(view.footage.unknownCount, 0);
    });

    test('the column table exists before any data does', () {
      // The header row is the thing that makes an empty schedule
      // READABLE: it says what will appear, which is the whole reason
      // CR-105 wants this tab present from minute one.
      expect(_pull(_Doc().doc).columns, kPullSheetColumns);
      expect(_term(_Doc().doc).columns, kTerminationScheduleColumns);
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // §3.2 / §3.3 — THE COLUMN TABLES
  // ═══════════════════════════════════════════════════════════════════
  group('§3.2/§3.3 — the columns are the page they have to fit', () {
    test("the Pull Sheet's ten columns sum to exactly 510 pt", () {
      // §3.2: "Widths sum to exactly 510" — 612 − 54 − 36 − 12. A column
      // table that no longer fits its page is a defect the eye does not
      // catch until a sheet prints with a column off the edge.
      expect(kPullSheetColumns.length, 10);
      expect(
        kPullSheetColumns.fold<double>(0, (n, c) => n + c.widthPt),
        510,
      );
    });

    test("the Termination Schedule's twelve columns sum to exactly "
        '690 pt', () {
      expect(kTerminationScheduleColumns.length, 12);
      expect(
        kTerminationScheduleColumns.fold<double>(0, (n, c) => n + c.widthPt),
        690,
      );
    });

    test('LEN is right-aligned and SIGN-OFF is centred, per §3.2', () {
      final byId = {for (final c in kPullSheetColumns) c.id: c};
      expect(byId[ScheduleColumnId.length]!.align, ScheduleAlign.right);
      expect(byId[ScheduleColumnId.signOff]!.align, ScheduleAlign.centre);
    });

    test('no preset carries a bare STATUS header (CR-065)', () {
      // Three vocabularies were being flown under that one word:
      // LifecycleStatus, RoughInStatus and DRC state.
      for (final column in [
        ...kPullSheetColumns,
        ...kTerminationScheduleColumns,
      ]) {
        expect(column.header, isNot('STATUS'));
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // ONE DERIVATION, TWO VIEWS
  // ═══════════════════════════════════════════════════════════════════
  group('ONE derivation, two views (§3.1)', () {
    _Doc scenario() {
      final d = _Doc();
      final great = d.room('Great Room');
      final rack = d.rack('RK-1');
      final panel = d.device('PP-1', rackId: rack, ruIndex: 14);
      final port = d.port(panel, 'A03');
      final outlet = d.outlet('WP-1', locationId: great);
      _link(
        d,
        designator: 'W015',
        from: PlaceEndpoint(description: 'TV wall', locationId: great),
        to: PortEndpoint(port),
        fieldLabel: 'GR-TV-1',
        rackLabel: '1A-A03',
        outletId: outlet,
      );
      return d;
    }

    test('the two presets project the SAME ROW OBJECTS — there is one '
        'row model, not two', () {
      final schedule = buildSchedule(scenario().doc);
      final pull = buildScheduleView(
        schedule,
        preset: SchedulePreset.pullSheet,
      );
      final term = buildScheduleView(
        schedule,
        preset: SchedulePreset.terminationSchedule,
      );
      expect(
        identical(pull.rows.single, term.rows.single),
        isTrue,
        reason:
            'if these are ever two different objects, the two sheets can '
            'describe one cable two ways — and T6.10 and T6.11 '
            'disagreeing about a cable is a callback',
      );
    });

    test('a column on BOTH sheets prints the identical string on both', () {
      final doc = scenario().doc;
      final pull = _pull(doc);
      final term = _term(doc);
      final shared = kPullSheetColumns
          .map((c) => c.id)
          .toSet()
          .intersection(kTerminationScheduleColumns.map((c) => c.id).toSet());
      expect(
        shared,
        containsAll(<ScheduleColumnId>{
          ScheduleColumnId.cableId,
          ScheduleColumnId.type,
          ScheduleColumnId.fieldLabel,
          ScheduleColumnId.rackLabel,
          ScheduleColumnId.media,
        }),
      );
      for (final id in shared) {
        expect(
          pull.rows.single.cell(id, units: UnitSystem.imperial),
          term.rows.single.cell(id, units: UnitSystem.imperial),
          reason: '$id must be one string, computed once',
        );
      }
    });

    test('every column either preset names resolves to a cell', () {
      final doc = scenario().doc;
      final row = _pull(doc).rows.single;
      for (final column in [
        ...kPullSheetColumns,
        ...kTerminationScheduleColumns,
        kJacketColorColumn,
      ]) {
        expect(
          () => row.cell(column.id, units: UnitSystem.imperial),
          returnsNormally,
        );
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // DR-008 §11.8.2 — THE CLASS
  // ═══════════════════════════════════════════════════════════════════
  group('DR-008 §11.8.2 — the class comes from effectiveLinkClassOf', () {
    /// Two devices in ONE rack — the classifier says `jumper`.
    _Doc sameRack({
      LinkClass stored = LinkClass.fieldCable,
      bool locked = false,
    }) {
      final d = _Doc();
      final rack = d.rack('RK-1');
      final a = d.device('SW-1', rackId: rack, ruIndex: 20);
      final b = d.device('PP-1', rackId: rack, ruIndex: 14);
      _link(
        d,
        designator: 'W001',
        from: PortEndpoint(d.port(a, 'P11')),
        to: PortEndpoint(d.port(b, 'A11')),
        linkClass: stored,
        linkClassLocked: locked,
      );
      return d;
    }

    test("an UNLOCKED link's stored class is inert — the classifier "
        'decides whether it reaches the Pull Sheet', () {
      // The stored value says fieldCable and nobody put it there. The
      // classifier says jumper, because both ends are in one rack. If
      // this row reaches the Pull Sheet, the sheet is asserting a pull
      // through a wall for a patch cord.
      final view = _pull(sameRack().doc);
      expect(view.rowCount, 0);
      expect(view.exclusions.jumpers, 1);
    });

    test('a LOCKED class outranks the classifier, and keeps a real pull '
        'off the sheet only because a person said so', () {
      final d = _Doc();
      final a = d.rack('RK-1');
      final b = d.rack('RK-2');
      final da = d.device('SW-1', rackId: a);
      final db = d.device('SW-2', rackId: b);
      _link(
        d,
        designator: 'W001',
        from: PortEndpoint(d.port(da, 'P1')),
        to: PortEndpoint(d.port(db, 'P1')),
        linkClass: LinkClass.jumper,
        linkClassLocked: true,
      );
      final view = _pull(d.doc);
      expect(view.rowCount, 0, reason: "the user's jumper stands");
      expect(
        view.exclusions.jumpers,
        1,
        reason: 'and the exclusion is a number the tab can show',
      );
    });

    test('THE DISAGREEMENT IS ON THE ROW AND IN THE COUNT — §11.8.2 '
        'requires it stay visible', () {
      // Same shape as above, seen from the Termination Schedule (which
      // shows jumpers when the toggle is on). Without this, a person's
      // stale `jumper` keeps a real pull off T6.10 forever and nothing
      // anywhere can say the document stopped agreeing.
      final d = _Doc();
      final a = d.rack('RK-1');
      final b = d.rack('RK-2');
      final da = d.device('SW-1', rackId: a);
      final db = d.device('SW-2', rackId: b);
      _link(
        d,
        designator: 'W001',
        from: PortEndpoint(d.port(da, 'P1')),
        to: PortEndpoint(d.port(db, 'P1')),
        linkClass: LinkClass.jumper,
        linkClassLocked: true,
      );
      final view = _term(d.doc, includeJumpersAndPowerCords: true);
      final row = view.rows.single;
      expect(row.linkClass, LinkClass.jumper);
      expect(row.classDisagreement, LinkClass.fieldCable);
      expect(row.hasClassDisagreement, isTrue);
      expect(view.classDisagreementCount, 1);
      expect(
        row.derivedNotes,
        contains('CLASSED JUMPER · LOOKS LIKE FIELD CABLE'),
      );
    });

    test('agreement is not a disagreement', () {
      final view = _term(
        sameRack(stored: LinkClass.jumper, locked: true).doc,
        includeJumpersAndPowerCords: true,
      );
      expect(view.classDisagreementCount, 0);
      expect(view.rows.single.classDisagreement, isNull);
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // UNDETERMINED — COUNTED AND SHOWN, NEVER DEFAULTED (G4)
  // ═══════════════════════════════════════════════════════════════════
  group('an undetermined class is counted and shown, never defaulted', () {
    /// One resolvable rack end, one end naming a port that is not in the
    /// document — so `linkClassOf` refuses to classify.
    _Doc undetermined() {
      final d = _Doc();
      final rack = d.rack('RK-1');
      final sw = d.device('SW-1', rackId: rack, ruIndex: 20);
      _link(
        d,
        designator: 'W099',
        from: PortEndpoint(d.port(sw, 'P1')),
        to: const PortEndpoint(Uuid('ghost-port')),
        fieldLabel: 'GH-1',
      );
      return d;
    }

    test('it is NOT excluded from the Pull Sheet — hiding it deletes a '
        'pull nobody has ruled out', () {
      final view = _pull(undetermined().doc);
      expect(view.rowCount, 1);
      expect(view.rows.single.isClassUndetermined, isTrue);
      expect(view.undeterminedClassCount, 1);
      expect(view.exclusions.total, 0);
    });

    test('it lands in its OWN band, not inside a room', () {
      final view = _pull(undetermined().doc);
      expect(view.groups.single.title, kUndeterminedClassGroupTitle);
      expect(view.groups.single.isUndeterminedClass, isTrue);
    });

    test("its footage does NOT join a room's subtotal", () {
      // The reason the band exists. A room subtotal is what cable gets
      // ordered against; adding a run nobody has established is a pull
      // is the fabricated number G4 forbids.
      final d = _Doc();
      final great = d.room('Great Room');
      final rack = d.rack('RK-1');
      final sw = d.device('SW-1', rackId: rack);
      _link(
        d,
        designator: 'W001',
        from: PlaceEndpoint(description: 'TV wall', locationId: great),
        to: PortEndpoint(d.port(sw, 'P1')),
        cutLength: const Len(30 * 12 * Len.nmPerInch),
      );
      _link(
        d,
        designator: 'W002',
        from: PlaceEndpoint(description: 'TV wall', locationId: great),
        to: const PortEndpoint(Uuid('ghost')),
        cutLength: const Len(70 * 12 * Len.nmPerInch),
        order: 1,
      );

      final view = _pull(d.doc);
      final room = view.groups.firstWhere((g) => g.title == 'Great Room');
      expect(room.rowCount, 1);
      expect(room.footage.value, const Len(30 * 12 * Len.nmPerInch));
      final band = view.groups.firstWhere((g) => g.isUndeterminedClass);
      expect(band.footage.value, const Len(70 * 12 * Len.nmPerInch));
    });

    test('the row SAYS SO in its notes as well as in the count', () {
      final row = _pull(undetermined().doc).rows.single;
      expect(row.derivedNotes, contains(kUndeterminedClassGroupTitle));
      expect(
        row.cell(ScheduleColumnId.conductorNotes, units: UnitSystem.metric),
        contains(kUndeterminedClassGroupTitle),
      );
    });

    test('a link with NO CONDUCTORS is undetermined and still gets a '
        'row', () {
      final d = _Doc();
      _link(d, designator: 'W000');
      final schedule = buildSchedule(d.doc);
      expect(schedule.rowCount, 1);
      final row = schedule.rows.single;
      expect(row.isClassUndetermined, isTrue);
      expect(row.from.kind, ScheduleEndKind.none);
      expect(row.to.kind, ScheduleEndKind.none);
    });

    test('the classifier and this file agree about undetermined — one '
        'reading, not two', () {
      final d = undetermined();
      final link = d.doc.links.values.single;
      expect(effectiveLinkClassOf(d.doc, link), isNull);
      expect(buildSchedule(d.doc).rows.single.linkClass, isNull);
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // §3.1 — EXCLUSIONS ARE COUNTED, AND THEY RECONCILE
  // ═══════════════════════════════════════════════════════════════════
  group('§3.1 — jumpers and power cords are excluded by default (AC-026)', () {
    _Doc mixed() {
      final d = _Doc();
      final great = d.room('Great Room');
      final rack = d.rack('RK-1');
      final sw = d.device('SW-1', rackId: rack, ruIndex: 20);
      final pp = d.device('PP-1', rackId: rack, ruIndex: 14);
      // A real pull: field to rack.
      _link(
        d,
        designator: 'W001',
        from: PlaceEndpoint(description: 'TV wall', locationId: great),
        to: PortEndpoint(d.port(pp, 'A01')),
        fieldLabel: 'GR-TV-1',
        rackLabel: '1A-A01',
      );
      // A patch cord: both ends in RK-1.
      _link(
        d,
        designator: 'W002',
        from: PortEndpoint(d.port(sw, 'P11')),
        to: PortEndpoint(d.port(pp, 'A11')),
        order: 1,
      );
      // A power cord, asserted by a person.
      _link(
        d,
        designator: 'W003',
        from: PortEndpoint(d.port(sw, 'IEC')),
        to: PortEndpoint(d.port(pp, 'OUT1')),
        linkClass: LinkClass.powerCord,
        linkClassLocked: true,
        order: 2,
      );
      return d;
    }

    test('the Pull Sheet shows the pull and hides the two rack-internal '
        'runs', () {
      final view = _pull(mixed().doc);
      expect(view.rows.map((r) => r.designator), ['W001']);
      expect(view.exclusions.jumpers, 1);
      expect(view.exclusions.powerCords, 1);
    });

    test('the toggle brings them back (AC-026)', () {
      final view = _pull(mixed().doc, includeJumpersAndPowerCords: true);
      expect(view.rowCount, 3);
      expect(view.exclusions.total, 0);
    });

    test('ROWS IN MINUS ROWS OUT EQUALS THE EXCLUSION TOTAL — the '
        'invariant that makes "nothing was dropped" checkable', () {
      for (final view in [
        _pull(mixed().doc),
        _term(mixed().doc),
        _pull(mixed().doc, includeJumpersAndPowerCords: true),
        _term(mixed().doc, includeJumpersAndPowerCords: true),
      ]) {
        expect(
          view.sourceRowCount - view.rowCount,
          view.exclusions.total,
          reason:
              'a row that is neither shown nor counted has been silently '
              'deleted from the deliverable',
        );
      }
    });

    test('an INTERNAL link is off the Pull Sheet unconditionally, and '
        'counted separately from the toggle', () {
      final d = _Doc();
      final rack = d.rack('RK-1');
      final dev = d.device('MTX-1', rackId: rack);
      _link(
        d,
        designator: 'W010',
        from: PortEndpoint(d.port(dev, 'IN1')),
        to: PortEndpoint(d.port(dev, 'OUT1')),
        linkClass: LinkClass.internal,
        linkClassLocked: true,
      );
      final view = _pull(d.doc, includeJumpersAndPowerCords: true);
      expect(view.rowCount, 0);
      expect(view.exclusions.internal, 1);
      expect(
        _term(d.doc).rowCount,
        1,
        reason:
            '§3.1 gives the Termination Schedule every Link landing in a '
            'rack; nobody pulls an internal link but somebody may still '
            'have to land it',
      );
    });

    test('the Termination Schedule drops a cable that lands in no rack, '
        'and says how many', () {
      final d = _Doc();
      final great = d.room('Great Room');
      _link(
        d,
        designator: 'W020',
        from: PlaceEndpoint(description: 'beam 3', locationId: great),
        to: PlaceEndpoint(description: 'west wall', locationId: great),
      );
      final term = _term(d.doc);
      expect(term.rowCount, 0);
      expect(term.exclusions.notLandingInRack, 1);
      expect(
        _pull(d.doc).rowCount,
        1,
        reason:
            'a wall-to-wall run has no panel to terminate and is still '
            'very much a pull (see link_class_test: TWO FIELD ENDS DO '
            'NOT MAKE A JUMPER)',
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // BOTH LABELS ON BOTH ENDS (CR-044 / AC-047)
  // ═══════════════════════════════════════════════════════════════════
  group('both labels, on both ends and on both sheets', () {
    test('one row carries the field label AND the rack label on each '
        'preset', () {
      final d = _Doc();
      final great = d.room('Great Room');
      final rack = d.rack('RK-1');
      final pp = d.device('PP-1', rackId: rack, ruIndex: 14);
      _link(
        d,
        designator: 'W015',
        from: PlaceEndpoint(description: 'TV wall', locationId: great),
        to: PortEndpoint(d.port(pp, 'A03')),
        fieldLabel: 'GR-TV-1',
        rackLabel: '1A-A03',
      );
      for (final view in [_pull(d.doc), _term(d.doc)]) {
        final row = view.rows.single;
        expect(
          row.cell(ScheduleColumnId.fieldLabel, units: UnitSystem.imperial),
          'GR-TV-1',
        );
        expect(
          row.cell(ScheduleColumnId.rackLabel, units: UnitSystem.imperial),
          '1A-A03',
        );
        expect(view.missingFieldLabelCount, 0);
        expect(view.missingRackLabelCount, 0);
      }
    });

    test('a missing rack label prints the unknown marker, never a blank '
        'cell', () {
      // An empty cell reads as "nobody filled this in"; the em dash says
      // we do not know. `equipment_list.dart` learned this the hard way
      // with seventeen blank FACE cells.
      final d = _Doc();
      final great = d.room('Great Room');
      _link(
        d,
        designator: 'W041',
        from: PlaceEndpoint(description: 'ceiling L/R', locationId: great),
        to: const OpenEndpoint('coil in the J-hook'),
        fieldLabel: 'GR-CLG-1',
      );
      final view = _pull(d.doc);
      expect(
        view.rows.single.cell(
          ScheduleColumnId.rackLabel,
          units: UnitSystem.imperial,
        ),
        '—',
      );
      expect(view.missingRackLabelCount, 1);
      expect(view.missingFieldLabelCount, 0);
    });

    test('THE M2 EXIT CRITERION — 60 correctly-sorted rows with both '
        'labels on both ends and conductor colours where they exist', () {
      // The clause verbatim: "the schedule tab shows 60 correctly-sorted
      // rows with both labels on both ends and conductor colours where
      // they exist". Six rooms, ten drops each; every third drop is a
      // 16/2 speaker run with two coloured conductors.
      final d = _Doc();
      final rack = d.rack('RK-1');
      final pp = d.device('PP-1', rackId: rack, ruIndex: 14);
      final rooms = <Uuid>[
        for (final name in const [
          'Attic',
          'Great Room',
          'Kitchen',
          'Media Room',
          'Primary Bedroom',
          'Study',
        ])
          d.room(name),
      ];
      final pathways = [
        d.pathway('CD-1'),
        d.pathway('CD-2'),
        d.pathway('JH-2'),
      ];

      var n = 0;
      for (var r = 0; r < rooms.length; r++) {
        for (var i = 0; i < 10; i++) {
          n++;
          final speaker = n % 3 == 0;
          final outlet = d.outlet(
            'OUT-$n',
            locationId: rooms[r],
            nominalRunLength: const Len(40 * 12 * Len.nmPerInch),
          );
          _link(
            d,
            // Deliberately NOT in room order — the sort has to do the
            // work, and a `designator`-ordered input would hide a sort
            // that silently does nothing.
            designator: 'W${n.toString().padLeft(3, '0')}',
            from: PlaceEndpoint(
              description: 'drop $n',
              locationId: rooms[r],
            ),
            to: PortEndpoint(d.port(pp, 'A${n.toString().padLeft(2, '0')}')),
            fieldLabel: 'FL-$n',
            rackLabel: 'RL-$n',
            outletId: outlet,
            pathwayId: pathways[n % pathways.length],
            order: (n * 7) % 60,
            conductors: speaker
                ? [
                    Conductor(
                      from: PlaceEndpoint(description: 'drop $n'),
                      to: const OpenEndpoint('x'),
                      role: 'L+',
                      pairNumber: 1,
                      colorCode: 'red',
                    ),
                    Conductor(
                      from: PlaceEndpoint(description: 'drop $n'),
                      to: const OpenEndpoint('x'),
                      role: 'L-',
                      pairNumber: 1,
                      colorCode: 'black',
                    ),
                  ]
                : null,
          );
        }
      }

      final view = _pull(d.doc);
      expect(view.rowCount, 60);
      expect(view.undeterminedClassCount, 0);

      // BOTH LABELS, EVERY ROW.
      expect(view.missingFieldLabelCount, 0);
      expect(view.missingRackLabelCount, 0);

      // CORRECTLY SORTED: room bands in room order, and inside a band
      // the designators ascend.
      expect(view.groups.map((g) => g.title), [
        'Attic',
        'Great Room',
        'Kitchen',
        'Media Room',
        'Primary Bedroom',
        'Study',
      ]);
      for (final group in view.groups) {
        expect(group.rowCount, 10);
        final pathwaysSeen = group.rows.map((r) => r.pathwayName).toList();
        expect(
          pathwaysSeen,
          orderedEquals(List<String?>.from(pathwaysSeen)..sort()),
          reason: 'AC-025 sorts room THEN pathway',
        );
      }

      // CONDUCTOR COLOURS WHERE THEY EXIST — and counted where they do
      // not, so "where they exist" is a measured hedge rather than a
      // shrug.
      final speakerRow = _rowFor(view, 'W003');
      expect(speakerRow.conductors.map((c) => c.colorCode), ['red', 'black']);
      expect(
        speakerRow.cell(
          ScheduleColumnId.conductorNotes,
          units: UnitSystem.imperial,
        ),
        'L+ red · L- black',
      );
      expect(
        view.conductorColorUnknownCount,
        40,
        reason:
            'the forty single-conductor runs state no colour; the number '
            'is the honest form of "where they exist"',
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // ORIENTATION
  // ═══════════════════════════════════════════════════════════════════
  group('orientation — the field end is FROM whatever the file stored', () {
    test('a link stored RACK-FIRST still prints the room under FROM and '
        'the rack under TO', () {
      final d = _Doc();
      final great = d.room('Great Room');
      final rack = d.rack('RK-1');
      final pp = d.device('PP-1', rackId: rack, ruIndex: 14);
      _link(
        d,
        designator: 'W015',
        // Reversed on purpose: `atomicConnect` and a hand-edited file are
        // both free to store the ends either way round, and §3.2 reads
        // FROM — ROOM then TO — RACK.
        from: PortEndpoint(d.port(pp, 'A03')),
        to: PlaceEndpoint(description: 'TV wall', locationId: great),
        fieldLabel: 'GR-TV-1',
      );
      final row = _pull(d.doc).rows.single;
      expect(
        row.cell(ScheduleColumnId.fromRoomOutlet, units: UnitSystem.imperial),
        'Great Room / TV wall',
      );
      expect(
        row.cell(ScheduleColumnId.toRackRuFace, units: UnitSystem.imperial),
        'RK-1 / U14 / rear',
      );
      expect(row.roomName, 'Great Room');
    });

    test('the Termination Schedule reads the rack end as NEAR and the '
        'field end as FAR, from the same two ends', () {
      final d = _Doc();
      final great = d.room('Great Room');
      final rack = d.rack('RK-1');
      final pp = d.device('PP-1', rackId: rack, ruIndex: 14);
      _link(
        d,
        designator: 'W015',
        from: PlaceEndpoint(description: 'TV wall', locationId: great),
        to: PortEndpoint(d.port(pp, 'A03', userLabel: 'DATA')),
      );
      final row = _term(d.doc).rows.single;
      expect(
        row.cell(ScheduleColumnId.rackRuFace, units: UnitSystem.imperial),
        'RK-1 / U14 / rear',
      );
      expect(
        row.cell(ScheduleColumnId.device, units: UnitSystem.imperial),
        'PP-1',
      );
      expect(
        row.cell(ScheduleColumnId.port, units: UnitSystem.imperial),
        'A03 DATA',
      );
      expect(
        row.cell(ScheduleColumnId.farEnd, units: UnitSystem.imperial),
        'Great Room / TV wall',
      );
    });

    test('an OpenEndpoint far end prints — OPEN — and still carries its '
        'W number (AC-018)', () {
      final d = _Doc();
      final rack = d.rack('RK-1');
      final pp = d.device('PP-1', rackId: rack, ruIndex: 14);
      _link(
        d,
        designator: 'W044',
        from: const OpenEndpoint('coil above the ceiling'),
        to: PortEndpoint(d.port(pp, 'A12')),
      );
      final row = _term(d.doc).rows.single;
      expect(row.designator, 'W044');
      expect(
        row.cell(ScheduleColumnId.farEnd, units: UnitSystem.imperial),
        kOpenEndCell,
      );
    });

    test('a device on a rack SHELF resolves to the rack beneath it', () {
      // A one-hop `placement.rackId` read drops every shelf-mounted
      // device out of "lands in a rack" and takes its whole row off
      // T6.11.
      final d = _Doc();
      final rack = d.rack('RK-1');
      final shelf = d.device('SHF-1', rackId: rack, ruIndex: 8);
      final box = d.device('CTL-1', hostDeviceId: shelf);
      _link(
        d,
        designator: 'W061',
        from: const PlaceEndpoint(description: 'rack shelf'),
        to: PortEndpoint(d.port(box, 'IR3')),
      );
      final row = _term(d.doc).rows.single;
      expect(row.nearEnd.rackDesignator, 'RK-1');
      expect(row.landsInRack, isTrue);
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // §3.6 — SORT
  // ═══════════════════════════════════════════════════════════════════
  group('§3.6 — sort', () {
    test('ports sort the way a human reads them: A2 before A10', () {
      // §3.3's promise is that you terminate a panel top to bottom
      // without hunting. A lexicographic sort puts A10 between A1 and A2
      // and quietly breaks that promise on any hand-set or imported
      // designator.
      expect(compareDesignators('A2', 'A10'), lessThan(0));
      expect(compareDesignators('W9', 'W10'), lessThan(0));
      expect(compareDesignators('RK-2', 'RK-10'), lessThan(0));
      expect(compareDesignators('A10', 'A10'), 0);
      expect(
        compareDesignators('A09', 'A9'),
        isNot(0),
        reason:
            'two different strings must never compare equal, or the sort '
            'stops being total and §8.4 determinism goes with it',
      );
    });

    test('a very long digit run falls back to a string compare rather '
        'than overflowing', () {
      final long = 'W${'9' * 25}';
      final longer = 'W${'9' * 24}8';
      expect(() => compareDesignators(long, longer), returnsNormally);
      expect(compareDesignators(long, longer), isNot(0));
    });

    test('the Termination Schedule default is rack, then panel, then '
        'port', () {
      final d = _Doc();
      final rk1 = d.rack('RK-1');
      final rk2 = d.rack('RK-2');
      final ppA = d.device('PP-1', rackId: rk1, ruIndex: 14);
      final ppB = d.device('PP-2', rackId: rk1, ruIndex: 12);
      final sw2 = d.device('SW-9', rackId: rk2, ruIndex: 20);
      var order = 0;
      void run(String designator, Uuid device, String port) {
        _link(
          d,
          designator: designator,
          from: const PlaceEndpoint(description: 'field'),
          to: PortEndpoint(d.port(device, port)),
          order: order++,
        );
      }

      run('W005', sw2, 'P2');
      run('W004', ppB, 'A1');
      run('W003', ppA, 'A10');
      run('W002', ppA, 'A2');
      run('W001', ppA, 'A1');

      final view = _term(d.doc, grouping: ScheduleGrouping.none);
      expect(view.rows.map((r) => r.designator), [
        'W001',
        'W002',
        'W003',
        'W004',
        'W005',
      ]);
    });

    test('rows with no room sort LAST, not first', () {
      // Nulls first would put the rows nobody has finished describing at
      // the top of the sheet an installer works down.
      final d = _Doc();
      final zed = d.room('Zebra Room');
      _link(
        d,
        designator: 'W001',
        from: const PlaceEndpoint(description: 'somewhere'),
        to: const OpenEndpoint('coil'),
      );
      _link(
        d,
        designator: 'W002',
        from: PlaceEndpoint(description: 'wall', locationId: zed),
        to: const OpenEndpoint('coil'),
        order: 1,
      );
      final view = _pull(d.doc, grouping: ScheduleGrouping.none);
      expect(view.rows.map((r) => r.designator), ['W002', 'W001']);
    });

    test('cutLength descending still puts unknown lengths last', () {
      final d = _Doc();
      _link(
        d,
        designator: 'W001',
        from: const PlaceEndpoint(description: 'a'),
        to: const OpenEndpoint('x'),
      );
      _link(
        d,
        designator: 'W002',
        from: const PlaceEndpoint(description: 'b'),
        to: const OpenEndpoint('x'),
        cutLength: const Len(10 * 12 * Len.nmPerInch),
        order: 1,
      );
      _link(
        d,
        designator: 'W003',
        from: const PlaceEndpoint(description: 'c'),
        to: const OpenEndpoint('x'),
        cutLength: const Len(90 * 12 * Len.nmPerInch),
        order: 2,
      );
      final view = _pull(
        d.doc,
        sort: ScheduleSort.cutLengthDescending,
        grouping: ScheduleGrouping.none,
      );
      expect(view.rows.map((r) => r.designator), ['W003', 'W002', 'W001']);
    });

    test('every sort is TOTAL — two builds of one document produce the '
        'identical order (§8.4)', () {
      final d = _Doc();
      final rack = d.rack('RK-1');
      final pp = d.device('PP-1', rackId: rack, ruIndex: 14);
      for (var i = 0; i < 12; i++) {
        _link(
          d,
          // Every row deliberately shares a room, a pathway and a
          // designator prefix, so the primary keys tie and the tiebreaks
          // are the only thing deciding the order.
          designator: 'W001',
          from: const PlaceEndpoint(description: 'same place'),
          to: PortEndpoint(d.port(pp, 'A01')),
        );
      }
      for (final sort in ScheduleSort.values) {
        final a = _pull(d.doc, sort: sort).rows.map((r) => r.linkId.v);
        final b = _pull(d.doc, sort: sort).rows.map((r) => r.linkId.v);
        expect(a, orderedEquals(b.toList()), reason: '$sort is not stable');
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // §3.2 COLUMN 8 — LENGTH
  // ═══════════════════════════════════════════════════════════════════
  group('the termination cell, and what UNKNOWN outranks (M3-J)', () {
    // BOTH REQUIRED, both nullable. This group is about which of the two
    // wins, so a call that omitted one would hide the case it is testing
    // behind a default.
    ScheduleEntry rowWith({
      required TerminationType? origin,
      required TerminationType? intended,
    }) {
      final d = _Doc();
      final where = d.room('Kitchen');
      _link(
        d,
        designator: 'W042',
        from: PlaceEndpoint(
          description: 'wall plate',
          locationId: where,
          intendedTermination: intended,
        ),
        to: const OpenEndpoint('coil'),
        fieldLabel: 'KIT-TV-1',
        outletId: d.outlet('KIT-1', locationId: where),
        terminationField: origin,
      );
      return _pull(d.doc).rows.single;
    }

    test('the origin wins when it says something', () {
      // Unchanged: the origin is what the trim-out crew installs, and the
      // endpoint's field is an intent recorded at rough-in.
      expect(
        rowWith(
          origin: TerminationType.punchdown,
          intended: TerminationType.keystone,
        ).terminationType,
        TerminationType.punchdown,
      );
    });

    test('A NULL ORIGIN OUTRANKS NOTHING, and falls through to the intent', () {
      // The behaviour that changed. The field was non-nullable, so a home
      // run always answered and this fallthrough was unreachable for one.
      // Unknown is not a value to prefer over a stated intent.
      expect(
        rowWith(
          origin: null,
          intended: TerminationType.fBarrel,
        ).terminationType,
        TerminationType.fBarrel,
      );
    });

    test('and with neither, the cell is empty rather than guessed', () {
      // Never inferred from the connector: an F barrel and a keystone are
      // both RG6 terminations, and the model says which or it does not.
      expect(rowWith(origin: null, intended: null).terminationType, isNull);
    });

    test('`unterminated` is a DECISION and still reads as one', () {
      // The distinction the nullability bought: a coil left deliberately
      // bare is a fact somebody recorded, and it must not read the same
      // as a drop nobody has got to.
      expect(
        rowWith(
          origin: TerminationType.unterminated,
          intended: null,
        ).terminationType,
        TerminationType.unterminated,
      );
    });
  });

  group('§3.2 column 8 — the length, and what it is not', () {
    ScheduleEntry rowWith({
      Len? cutLength,
      Len? outletNominal,
      Len? roomEstimate,
    }) {
      final d = _Doc();
      final where = d.room('Kitchen', estimatedRunLength: roomEstimate);
      final outlet = d.outlet(
        'KIT-1',
        locationId: where,
        nominalRunLength: outletNominal,
      );
      _link(
        d,
        designator: 'W042',
        from: PlaceEndpoint(description: 'ceiling pair', locationId: where),
        to: const OpenEndpoint('coil'),
        fieldLabel: 'KIT-CLG-1',
        outletId: outlet,
        cutLength: cutLength,
      );
      return _pull(d.doc).rows.single;
    }

    test('a cut length is the measured figure and is not an estimate', () {
      final row = rowWith(cutLength: const Len(51 * 12 * Len.nmPerInch));
      expect(row.lengthSource, ScheduleLengthSource.cut);
      expect(row.lengthIsEstimated, isFalse);
      expect(row.lengthCell(UnitSystem.imperial), '51');
    });

    test("the outlet's nominal is used only when there is no cut length, "
        'and is flagged as an estimate (AC-024)', () {
      final row = rowWith(
        cutLength: const Len(51 * 12 * Len.nmPerInch),
        outletNominal: const Len(99 * 12 * Len.nmPerInch),
      );
      expect(row.lengthCell(UnitSystem.imperial), '51');

      final estimated = rowWith(
        outletNominal: const Len(99 * 12 * Len.nmPerInch),
      );
      expect(estimated.lengthSource, ScheduleLengthSource.outletNominal);
      expect(
        estimated.lengthIsEstimated,
        isTrue,
        reason: 'AC-024: tagged as an estimate so nobody bills off it',
      );
    });

    test("the room's estimate is the LAST resort", () {
      final row = rowWith(roomEstimate: const Len(62 * 12 * Len.nmPerInch));
      expect(row.lengthSource, ScheduleLengthSource.roomEstimate);
      expect(row.lengthIsEstimated, isTrue);
      expect(row.lengthCell(UnitSystem.imperial), '62');
    });

    test('no length at all prints the unknown marker and is COUNTED', () {
      final row = rowWith();
      expect(row.lengthSource, ScheduleLengthSource.none);
      expect(row.lengthCell(UnitSystem.imperial), '—');
      expect(row.cell(ScheduleColumnId.length, units: UnitSystem.metric), '—');
    });

    test('metric and imperial read the same stored integer (CR-097, '
        'CR-001)', () {
      final row = rowWith(cutLength: const Len(100 * Len.nmPerMillimetre * 10));
      expect(row.lengthCell(UnitSystem.metric), '1');
      expect(row.lengthCell(UnitSystem.imperial), '3');
    });

    test('a subtotal nothing known contributed to is UNKNOWN, not zero — '
        'and it says how many rows it could not see', () {
      final d = _Doc();
      final where = d.room('Kitchen');
      for (var i = 0; i < 3; i++) {
        _link(
          d,
          designator: 'W00$i',
          from: PlaceEndpoint(description: 'drop', locationId: where),
          to: const OpenEndpoint('coil'),
          order: i,
        );
      }
      final view = _pull(d.doc);
      expect(view.footage.isUnknown, isTrue);
      expect(view.footage.value, isNull);
      expect(view.footage.unknownCount, 3);
      expect(view.footage.knownCount, 0);
    });

    test('a subtotal with SOME known lengths sums those and counts the '
        'rest', () {
      final d = _Doc();
      final where = d.room('Kitchen');
      _link(
        d,
        designator: 'W001',
        from: PlaceEndpoint(description: 'a', locationId: where),
        to: const OpenEndpoint('coil'),
        cutLength: const Len(40 * 12 * Len.nmPerInch),
      );
      _link(
        d,
        designator: 'W002',
        from: PlaceEndpoint(description: 'b', locationId: where),
        to: const OpenEndpoint('coil'),
        order: 1,
      );
      final view = _pull(d.doc);
      expect(view.footage.value, const Len(40 * 12 * Len.nmPerInch));
      expect(view.footage.knownCount, 1);
      expect(
        view.footage.unknownCount,
        1,
        reason:
            'a subtotal without its unknown count is a number that is '
            'quietly wrong by an unstated amount (totals.dart rule 2)',
      );
    });

    test('the estimated count is stated separately from the total — '
        "§3.8's `3 estimated (italic)`", () {
      final d = _Doc();
      final where = d.room('Kitchen');
      final outlet = d.outlet(
        'K-1',
        locationId: where,
        nominalRunLength: const Len(50 * 12 * Len.nmPerInch),
      );
      _link(
        d,
        designator: 'W001',
        from: PlaceEndpoint(description: 'a', locationId: where),
        to: const OpenEndpoint('coil'),
        outletId: outlet,
        fieldLabel: 'K-1',
      );
      _link(
        d,
        designator: 'W002',
        from: PlaceEndpoint(description: 'b', locationId: where),
        to: const OpenEndpoint('coil'),
        cutLength: const Len(30 * 12 * Len.nmPerInch),
        order: 1,
      );
      final view = _pull(d.doc);
      expect(view.estimatedCount, 1);
      expect(view.groups.single.estimatedCount, 1);
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // JACKET COLOUR — CR-121, AND THE PROMISE docs/01:621 CARRIED
  // ═══════════════════════════════════════════════════════════════════
  group('the jacket-colour cell (§3.1, CR-121)', () {
    const blue = JacketColorId('jc.blue');
    const yellow = JacketColorId('jc.yellow');

    ScheduleView viewWith({
      JacketColorId? conventionId,
      JacketColorId? pulledId,
      bool seedConvention = true,
    }) {
      final d = _Doc();
      if (seedConvention) {
        d.doc.settings.jacketColorConventions.addAll({
          blue: const JacketColorDef(
            displayName: 'Blue',
            abbr: 'BLU',
            color: Rgb(0x00, 0x72, 0xB2),
            meaning: 'Control',
          ),
          yellow: const JacketColorDef(
            displayName: 'Yellow',
            abbr: 'YEL',
            color: Rgb(0xE6, 0x9F, 0x00),
          ),
        });
      }
      _link(
        d,
        designator: 'W001',
        from: const PlaceEndpoint(description: 'wall'),
        to: const OpenEndpoint('coil'),
        jacketColorId: conventionId,
        jacketColorPulledId: pulledId,
      );
      return _pull(d.doc);
    }

    test('the convention colour prints its ABBREVIATION, which survives '
        'greyscale and a photocopy', () {
      final view = viewWith(conventionId: blue);
      expect(view.rows.single.jacketColorCell, 'BLU');
      expect(view.jacket.recorded, 1);
      expect(view.jacket.exceptions, 0);
    });

    test('A RUN PULLED OFF-CONVENTION PRINTS BOTH TOKENS, never one', () {
      // §3.1, in so many words: "A run pulled in the wrong colour prints
      // both tokens — BLU→YEL at this column's width — never one." One
      // token is the failure: it reads either as a correct blue run or
      // as a yellow convention, and both are false.
      final view = viewWith(conventionId: blue, pulledId: yellow);
      expect(view.rows.single.jacketColorCell, 'BLU→YEL');
      expect(view.jacket.exceptions, 1);
      expect(view.rows.single.derivedNotes, contains('PULLED OFF-CONVENTION'));
    });

    test('a DANGLING id prints ? and is counted — deleting a convention '
        'entry must not destroy the record of what was pulled', () {
      final view = viewWith(
        conventionId: blue,
        pulledId: yellow,
        seedConvention: false,
      );
      expect(view.rows.single.jacketColorCell, '?→?');
      expect(view.jacket.unknownEntries, 1);
      expect(view.jacket.exceptions, 1);
    });

    test('nobody having said prints the unknown marker and is counted, '
        'not treated as an error', () {
      final view = viewWith();
      expect(view.rows.single.jacketColorCell, '—');
      expect(view.jacket.unrecorded, 1);
      expect(view.jacket.recorded, 0);
      expect(view.jacket.exceptions, 0);
    });

    test('an override EQUAL to the convention is not an exception', () {
      // The write path normalises this away; a hand-edited file or a CSV
      // import can still carry it, and reporting it would inflate the
      // exception count with rows reading BLU→BLU.
      final view = viewWith(conventionId: blue, pulledId: blue);
      expect(view.rows.single.jacketColorCell, 'BLU');
      expect(view.jacket.exceptions, 0);
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // NOTHING IS SILENTLY DROPPED
  // ═══════════════════════════════════════════════════════════════════
  group('nothing is silently dropped', () {
    test('buildSchedule emits exactly one row per Link, always', () {
      final d = _Doc();
      final rack = d.rack('RK-1');
      final dev = d.device('SW-1', rackId: rack);
      _link(d, designator: 'W001'); // no conductors
      _link(
        d,
        designator: 'W002',
        from: const PortEndpoint(Uuid('ghost')),
        to: const OpenEndpoint('coil'),
        order: 1,
      );
      _link(
        d,
        designator: 'W003',
        from: PortEndpoint(d.port(dev, 'P1')),
        to: const PlaceEndpoint(description: 'wall'),
        order: 2,
      );
      final schedule = buildSchedule(d.doc);
      expect(schedule.rowCount, d.doc.links.length);
      expect(schedule.rows.map((r) => r.designator), [
        'W001',
        'W002',
        'W003',
      ]);
    });

    test('an unresolved port end is UNRESOLVED, not "not in a rack" — '
        'they are different facts', () {
      final d = _Doc();
      _link(
        d,
        designator: 'W002',
        from: const PortEndpoint(Uuid('ghost')),
        to: const OpenEndpoint('coil'),
      );
      final row = buildSchedule(d.doc).rows.single;
      expect(row.from.kind, ScheduleEndKind.unresolvedPort);
      expect(
        row.from.locationCell,
        '—',
        reason:
            'the honest answer is that this document cannot say where '
            'that end is — not that it is outside the racks',
      );
    });

    test('a port on an OFF-RACK device is unracked, and says so by name', () {
      final d = _Doc();
      final staged = d.device('AMP-9');
      _link(
        d,
        designator: 'W003',
        from: PortEndpoint(d.port(staged, 'CH1')),
        to: const OpenEndpoint('coil'),
      );
      final row = buildSchedule(d.doc).rows.single;
      expect(row.from.kind, ScheduleEndKind.unrackedPort);
      expect(row.from.locationCell, 'AMP-9');
      expect(row.landsInRack, isFalse);
    });

    test('document order is deterministic and does not depend on map '
        'iteration (§8.4)', () {
      final d = _Doc();
      _link(d, designator: 'W900', order: 9);
      _link(d, designator: 'W100', order: 1);
      _link(d, designator: 'W500', order: 5);
      expect(buildSchedule(d.doc).rows.map((r) => r.designator), [
        'W100',
        'W500',
        'W900',
      ]);
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // THE TYPE, MEDIA AND TERM CELLS
  // ═══════════════════════════════════════════════════════════════════
  group('the registry-backed cells count what they cannot resolve', () {
    test('an unresolved signal family prints its RAW ID and is counted — '
        'never an abbreviation this file invented', () {
      final d = _Doc();
      _link(
        d,
        designator: 'W001',
        from: const PlaceEndpoint(description: 'wall'),
        to: const OpenEndpoint('coil'),
        signalFamily: const SignalFamilyId('video.hdmi'),
      );
      final view = _pull(d.doc);
      expect(view.rows.single.typeCell, 'video.hdmi');
      expect(
        view.unresolvedSignalFamilyCount,
        1,
        reason:
            'no registries.json ships yet, so this is every row in every '
            'document today — counted rather than papered over',
      );
    });

    test('a resolved domain and family print tagPrefix·displayName', () {
      final d = _Doc();
      const family = SignalFamilyId('video.hdmi');
      const domain = SignalDomainId('vid');
      d.doc.registries.signalDomains[domain] = const SignalDomainDef(
        id: domain,
        displayName: 'Video',
        tagPrefix: 'VID',
        color: Rgb(0x00, 0x72, 0xB2),
        colorDark: Rgb(0x00, 0x72, 0xB2),
        dashPattern: [],
        lineWeightPermille: 1000,
        glyph: '▲',
        glyphAlt: '△',
      );
      d.doc.registries.signalFamilies[family] = const SignalFamilyDef(
        id: family,
        displayName: 'HDMI',
        domain: domain,
        defaultConnector: ConnectorTypeId('conn.hdmi_a'),
        defaultDirection: PortDirection.bidirectional,
        defaultTopology: PortTopology.p2p,
      );
      _link(
        d,
        designator: 'W001',
        from: const PlaceEndpoint(description: 'wall'),
        to: const OpenEndpoint('coil'),
        signalFamily: family,
      );
      final view = _pull(d.doc);
      expect(view.rows.single.typeCell, 'VID·HDMI');
      expect(view.unresolvedSignalFamilyCount, 0);
    });

    test('the MEDIA cell prints the registry name plus the NEC fire '
        'rating, which is not a colour', () {
      final d = _Doc();
      const cat6a = MediaTypeId('media.cat6a_futp');
      d.doc.registries.mediaTypes[cat6a] = const MediaTypeDef(
        id: cat6a,
        displayName: 'Cat6A F/UTP',
      );
      _link(
        d,
        designator: 'W001',
        from: const PlaceEndpoint(description: 'wall'),
        to: const OpenEndpoint('coil'),
        jacket: JacketRating.cmr,
      );
      expect(_pull(d.doc).rows.single.mediaCell, 'Cat6A F/UTP CMR');
    });

    test('an unresolved media id prints the id and is counted', () {
      final d = _Doc();
      _link(
        d,
        designator: 'W001',
        from: const PlaceEndpoint(description: 'wall'),
        to: const OpenEndpoint('coil'),
      );
      final view = _pull(d.doc);
      expect(view.rows.single.mediaCell, 'media.cat6a_futp');
      expect(view.unresolvedMediaCount, 1);
    });

    test('the TERM cell is the termination the model STATES plus the '
        'punch position — never a guessed T568A/B', () {
      final d = _Doc();
      final rack = d.rack('RK-1');
      final pp = d.device('PP-1', rackId: rack, ruIndex: 14);
      _link(
        d,
        designator: 'W001',
        from: const PlaceEndpoint(description: 'wall'),
        to: PortEndpoint(d.port(pp, 'A03')),
        fieldLabel: 'GR-1',
      );
      final row = _term(d.doc).rows.single;
      expect(row.terminationType, TerminationType.keystone);
      expect(
        row.cell(ScheduleColumnId.term, units: UnitSystem.imperial),
        'KEYSTONE A03',
      );
    });

    test("a PlaceEndpoint's intended termination is used when there is no "
        'home-run origin', () {
      final d = _Doc();
      _link(
        d,
        designator: 'W001',
        from: const PlaceEndpoint(
          description: 'wall',
          intendedTermination: TerminationType.fBarrel,
        ),
        to: const OpenEndpoint('coil'),
      );
      expect(
        _pull(d.doc).rows.single.terminationCell,
        'F BARREL',
      );
    });

    test('a null-modem crossover becomes a note, because the model '
        'states it', () {
      final d = _Doc();
      _link(
        d,
        designator: 'W055',
        from: const PlaceEndpoint(description: 'projector'),
        to: const OpenEndpoint('coil'),
        crossover: CrossoverKind.nullModem,
      );
      expect(_pull(d.doc).rows.single.derivedNotes, contains('NULL-MODEM'));
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // §3.6 — GROUPING
  // ═══════════════════════════════════════════════════════════════════
  group('§3.6 — grouping', () {
    test('rows with no room fall into a NAMED band rather than '
        'disappearing', () {
      final d = _Doc();
      final great = d.room('Great Room');
      _link(
        d,
        designator: 'W001',
        from: PlaceEndpoint(description: 'wall', locationId: great),
        to: const OpenEndpoint('coil'),
      );
      _link(
        d,
        designator: 'W002',
        from: const PlaceEndpoint(description: 'somewhere'),
        to: const OpenEndpoint('coil'),
        order: 1,
      );
      final view = _pull(d.doc);
      expect(view.groups.map((g) => g.title), [
        'Great Room',
        kUngroupedTitle,
      ]);
      expect(view.rowCount, 2);
    });

    test('grouping none still produces ONE band, so a renderer has one '
        'shape to draw', () {
      final d = _Doc();
      _link(
        d,
        designator: 'W001',
        from: const PlaceEndpoint(description: 'wall'),
        to: const OpenEndpoint('coil'),
      );
      final view = _pull(d.doc, grouping: ScheduleGrouping.none);
      expect(view.groups.single.title, kAllRunsTitle);
    });

    test('every row of the view is in exactly one band', () {
      final d = _Doc();
      final rooms = [d.room('A'), d.room('B')];
      for (var i = 0; i < 6; i++) {
        _link(
          d,
          designator: 'W00$i',
          from: PlaceEndpoint(description: 'x', locationId: rooms[i % 2]),
          to: const OpenEndpoint('coil'),
          order: i,
        );
      }
      _link(
        d,
        designator: 'W099',
        from: const PortEndpoint(Uuid('ghost')),
        to: const PortEndpoint(Uuid('ghost2')),
        order: 9,
      );
      final view = _pull(d.doc);
      final ids = view.groups.expand((g) => g.rows).map((r) => r.linkId.v);
      expect(ids.toSet().length, ids.length, reason: 'no row appears twice');
      expect(view.rowCount, 7);
    });

    test('the undetermined band is LAST, whatever the grouping', () {
      final d = _Doc();
      final great = d.room('Zulu Room');
      _link(
        d,
        designator: 'W001',
        from: PlaceEndpoint(description: 'wall', locationId: great),
        to: const OpenEndpoint('coil'),
      );
      _link(
        d,
        designator: 'W002',
        from: const PortEndpoint(Uuid('ghost')),
        to: const PortEndpoint(Uuid('ghost2')),
        order: 1,
      );
      for (final grouping in ScheduleGrouping.values) {
        final view = _pull(d.doc, grouping: grouping);
        expect(view.groups.last.title, kUndeterminedClassGroupTitle);
      }
    });
  });
}
