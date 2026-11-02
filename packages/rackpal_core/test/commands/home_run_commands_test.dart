// commands/home_run_commands.dart — board M3-A/2, AC-018.
//
// THE LOAD-BEARING TEST IN THIS FILE IS THE LAST GROUP. Everything above it
// checks the command in isolation; `AC-018 end to end` checks the thing the
// task is actually for — that a drop produced by this gesture reaches the
// schedule with its `W` number and its label, which is what "reachable by
// construction" has to mean. `70cb8d5` proved the schedule handles unbound
// ends in a file somebody hand-authored; this proves the app can now MAKE
// one.

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

final _now = DateTime.utc(2026, 8, 6);

EntityMeta _meta() =>
    EntityMeta(createdAt: _now, updatedAt: _now, updatedBy: 'test');

/// A project with one Structure body and one Outlet on it — the smallest
/// document a home run can be pulled from.
({RackDocument doc, Uuid bodyId, Uuid outletId, Uuid roomId}) _project() {
  final doc = RackDocument(
    id: const Uuid('doc-home-run'),
    appVersion: '0.1.0',
    createdAt: _now,
    modifiedAt: _now,
    meta: _meta(),
  );
  final structure = AddStructureCommand(
    title: 'Rough-In',
    designator: 'STR-1',
    now: _now,
    actor: 'test',
  )..apply(doc);
  final outlet = AddOutletCommand(
    structureBodyId: structure.bodyId,
    designation: 'GR-TV-1',
    order: nextOutletOrder(doc),
    now: _now,
    actor: 'test',
    wall: Wall.n,
    mountSurface: MountSurface.wall,
  )..apply(doc);

  // A ROOM, because a run with no outlet has nothing else to say which
  // room it is in and the builder refuses one that cannot.
  final room = AddLocationCommand(
    name: 'Living Room',
    code: 'LR',
    order: nextLocationOrder(doc),
    now: _now,
    actor: 'test',
  )..apply(doc);

  return (
    doc: doc,
    bodyId: structure.bodyId,
    outletId: outlet.id,
    roomId: room.id,
  );
}

AddHomeRunResult _build(
  RackDocument doc,
  Uuid outletId, {
  String fieldLabel = 'GR-DATA-1',
  String designator = 'W001',
  Endpoint? fieldEnd,
  Endpoint? rackEnd,
  String? rackLabel,
  Set<String> alsoUsedLabels = const {},
  Set<String> alsoUsedDesignators = const {},
}) => buildAddHomeRunCommand(
  doc: doc,
  outletId: outletId,
  fieldLabel: fieldLabel,
  designator: designator,
  netName: 'N001',
  media: const MediaTypeId('media.cat6_utp'),
  fieldEnd: fieldEnd ?? const PlaceEndpoint(description: 'Great Room TV wall'),
  terminationField: TerminationType.keystone,
  now: _now,
  actor: 'test',
  rackEnd: rackEnd,
  rackLabel: rackLabel,
  alsoUsedLabels: alsoUsedLabels,
  alsoUsedDesignators: alsoUsedDesignators,
);

AddHomeRunCommand _ready(AddHomeRunResult r) => (r as AddHomeRunReady).command;

String _refusal(AddHomeRunResult r) => (r as AddHomeRunRefused).reason;

void main() {
  group('the drop it produces', () {
    test('is one Link carrying a structureOrigin, not a new entity', () {
      // AC-019: the origin lives ON the Link, and the Outlet holds no
      // member list, so membership has exactly one source of truth.
      final p = _project();
      final cmd = _ready(_build(p.doc, p.outletId))..apply(p.doc);

      final link = p.doc.links[cmd.id]!;
      expect(link.structureOrigin!.outletId, p.outletId);
      expect(link.structureOrigin!.structureBodyId, p.bodyId);
      expect(link.structureOrigin!.fieldLabel, 'GR-DATA-1');
      expect(link.designator, 'W001');
    });

    test('puts the FIELD end first, the order the starter and the schedule '
        'both use', () {
      final p = _project();
      final cmd = _ready(_build(p.doc, p.outletId))..apply(p.doc);
      final conductor = p.doc.links[cmd.id]!.conductors.single;

      expect(conductor.from, isA<PlaceEndpoint>());
      expect(conductor.to, isA<OpenEndpoint>());
    });

    test('an unlanded rack end becomes an OpenEndpoint, not an error', () {
      // The half AC-018's exit criterion counts: a rough-in entered in
      // February has no patch panel to land on yet.
      final p = _project();
      final cmd = _ready(_build(p.doc, p.outletId))..apply(p.doc);

      expect(p.doc.links[cmd.id]!.conductors.single.to, isA<OpenEndpoint>());
    });

    test('a landed rack end is kept as given', () {
      final p = _project();
      const portId = Uuid('port-1');
      final cmd = _ready(
        _build(p.doc, p.outletId, rackEnd: const PortEndpoint(portId)),
      )..apply(p.doc);

      final to = p.doc.links[cmd.id]!.conductors.single.to;
      expect(to, isA<PortEndpoint>());
      expect((to as PortEndpoint).portId, portId);
    });

    test('it copies the outlet placement onto the origin', () {
      // What lets the Pull Sheet print a wall and a height for a run whose
      // far end has no device on it.
      final p = _project();
      final cmd = _ready(_build(p.doc, p.outletId))..apply(p.doc);
      final origin = p.doc.links[cmd.id]!.structureOrigin!;

      expect(origin.wall, Wall.n);
      expect(origin.mountSurface, MountSurface.wall);
    });

    test('a rack label that was never dressed stays NULL, not empty', () {
      // G4/CR-114: a run pulled but not yet dressed into a panel genuinely
      // has no rack label, and inventing one names a position nobody has
      // terminated.
      final p = _project();
      final cmd = _ready(_build(p.doc, p.outletId, rackLabel: '  '))
        ..apply(p.doc);

      expect(p.doc.links[cmd.id]!.structureOrigin!.rackLabel, isNull);
    });

    test('revert removes the link AND its implicit net', () {
      final p = _project();
      final cmd = _ready(_build(p.doc, p.outletId))..apply(p.doc);
      expect(p.doc.nets, hasLength(1));

      cmd.revert(p.doc);
      expect(p.doc.links, isEmpty);
      expect(p.doc.nets, isEmpty);
    });

    test('redo recreates the identical link and net ids', () {
      final p = _project();
      final cmd = _ready(_build(p.doc, p.outletId))..apply(p.doc);
      final linkId = cmd.id;
      final netId = cmd.netId;

      cmd
        ..revert(p.doc)
        ..apply(p.doc);

      expect(p.doc.links.keys, [linkId]);
      expect(p.doc.nets.keys, [netId]);
    });
  });

  group('it refuses rather than silently doing nothing (docs/04 §3.4)', () {
    test('a field end that is a live PORT', () {
      // A home run that lands on a port is an ordinary patch. Rewriting it
      // into one would file the cable on the wrong sheet.
      final p = _project();
      final r = _build(
        p.doc,
        p.outletId,
        fieldEnd: const PortEndpoint(Uuid('port-1')),
      );

      expect(r, isA<AddHomeRunRefused>());
      expect(_refusal(r), contains('cannot start at a port'));
    });

    test('a duplicate field label (CR-113 is project-wide)', () {
      final p = _project();
      _ready(_build(p.doc, p.outletId)).apply(p.doc);

      final r = _build(p.doc, p.outletId, designator: 'W002');
      expect(r, isA<AddHomeRunRefused>());
      expect(_refusal(r), contains('unique project-wide'));
    });

    test('a duplicate W number', () {
      final p = _project();
      _ready(_build(p.doc, p.outletId)).apply(p.doc);

      final r = _build(p.doc, p.outletId, fieldLabel: 'GR-DATA-2');
      expect(r, isA<AddHomeRunRefused>());
      expect(_refusal(r), contains('already a cable'));
    });

    test('an empty field label', () {
      final p = _project();
      final r = _build(p.doc, p.outletId, fieldLabel: '   ');
      expect(r, isA<AddHomeRunRefused>());
      expect(_refusal(r), contains('needs a field label'));
    });

    test('an outlet that is not in the project', () {
      final p = _project();
      final r = _build(p.doc, const Uuid('nope'));
      expect(r, isA<AddHomeRunRefused>());
      expect(_refusal(r), contains('not in this project'));
    });

    test('a collision against a SIBLING being built in the same gesture', () {
      // The reason `alsoUsed*` exists. Sixty drops entered in one sitting
      // are built against ONE unmutated document, so without a reservation
      // every one of them passes the document check and they collide on
      // apply. `allocateLinkDesignatorFor` carries the same parameter for
      // the same reason.
      final p = _project();

      expect(
        _build(p.doc, p.outletId, alsoUsedLabels: {'GR-DATA-1'}),
        isA<AddHomeRunRefused>(),
      );
      expect(
        _build(p.doc, p.outletId, alsoUsedDesignators: {'W001'}),
        isA<AddHomeRunRefused>(),
      );
    });
  });

  group(
    'AC-018 end to end: the gesture makes a drop the schedule can read',
    () {
      test('an unbound drop schedules, and carries its W number and label', () {
        // The property #141 exists for. Until this command there was no path
        // from a gesture to an unbound endpoint at all, so AC-018 was
        // unreachable BY CONSTRUCTION rather than broken.
        final p = _project();
        _ready(_build(p.doc, p.outletId)).apply(p.doc);

        final schedule = buildSchedule(p.doc);
        final row = schedule.rows.single;

        expect(row.designator, 'W001');
        expect(
          p.doc.links[row.linkId]!.structureOrigin!.fieldLabel,
          'GR-DATA-1',
        );
      });

      test('and it reaches the PULL SHEET, which is its sheet', () {
        final p = _project();
        _ready(_build(p.doc, p.outletId)).apply(p.doc);

        final pull = scheduleViewOf(p.doc, preset: SchedulePreset.pullSheet);
        final onSheet = [
          for (final group in pull.groups)
            for (final row in group.rows) row.designator,
        ];

        expect(onSheet, contains('W001'));
      });

      test(
        'fourteen drops with unbound far ends all survive, none collide',
        () {
          // The exit criterion's own number, in miniature: the batch path with
          // its reservations, then the schedule reading every one of them.
          final p = _project();
          final labels = <String>{};
          final designators = <String>{};

          for (var i = 1; i <= 14; i++) {
            final result = _build(
              p.doc,
              p.outletId,
              fieldLabel: 'GR-DATA-$i',
              designator: 'W${i.toString().padLeft(3, '0')}',
              alsoUsedLabels: labels,
              alsoUsedDesignators: designators,
            );
            expect(
              result,
              isA<AddHomeRunReady>(),
              reason: 'drop $i was refused',
            );
            final cmd = _ready(result)..apply(p.doc);
            labels.add(cmd.fieldLabel);
            designators.add(cmd.designator);
          }

          expect(buildSchedule(p.doc).rows, hasLength(14));
          expect(
            buildSchedule(p.doc).rows.map((r) => r.designator).toSet(),
            hasLength(14),
            reason:
                'two rows sharing a W number are two an installer cannot '
                'tell apart',
          );
        },
      );
    },
  );

  group('A RUN THAT COMES OUT OF NO BOX (DR-070, `#718`)', () {
    // Reported from real use: a ceiling speaker has no low-voltage box,
    // and every home run demanded an `Outlet`, so the Outlets page listed
    // a plate for a speaker that has none.

    AddHomeRunResult boxless(
      RackDocument doc,
      Uuid bodyId, {
      String fieldLabel = 'LR-SPK-L',
      Uuid? roomId,
      bool withRoom = true,
    }) => buildAddHomeRunCommand(
      doc: doc,
      structureBodyId: bodyId,
      fieldLabel: fieldLabel,
      designator: 'W900',
      netName: 'N900',
      media: const MediaTypeId('media.cat6_utp'),
      fieldEnd: PlaceEndpoint(
        description: 'Living Room ceiling',
        locationId: withRoom ? roomId : null,
      ),
      terminationField: TerminationType.bindingPost,
      now: _now,
      actor: 'test',
    );

    test('it is created, and says so with the FLAG and not the absence', () {
      final p = _project();
      _ready(boxless(p.doc, p.bodyId, roomId: p.roomId)).apply(p.doc);

      final origin = p.doc.links.values.single.structureOrigin!;
      expect(origin.outletId, isNull);
      expect(
        origin.boxless,
        isTrue,
        reason:
            'null alone is "nobody has said"; the flag is the person '
            'stating there is no box (G4)',
      );
      expect(
        origin.structureBodyId,
        p.bodyId,
        reason:
            'the body came from the caller, since there is no outlet '
            'to read it off',
      );
    });

    test('and its placement is UNKNOWN rather than defaulted', () {
      // The outlet is the authority on where a run sits, and a run with
      // no outlet has nobody to ask. Substituting a height would put a
      // number on a schedule nobody measured.
      final p = _project();
      _ready(boxless(p.doc, p.bodyId, roomId: p.roomId)).apply(p.doc);

      final origin = p.doc.links.values.single.structureOrigin!;
      expect(origin.wall, isNull);
      expect(origin.mountSurface, isNull);
      expect(origin.mountHeightAff, isNull);
    });

    test('a run WITH a box still carries the outlet"s placement', () {
      // The other direction, without which the case above is satisfied
      // by "never copy anything".
      final p = _project();
      _ready(_build(p.doc, p.outletId)).apply(p.doc);

      final origin = p.doc.links.values.single.structureOrigin!;
      expect(origin.outletId, p.outletId);
      expect(origin.boxless, isFalse);
      expect(origin.wall, Wall.n);
      expect(origin.mountSurface, MountSurface.wall);
    });

    test('naming NEITHER an outlet nor a body is refused', () {
      final p = _project();
      final refusal = buildAddHomeRunCommand(
        doc: p.doc,
        fieldLabel: 'LR-SPK-R',
        designator: 'W901',
        netName: 'N901',
        media: const MediaTypeId('media.cat6_utp'),
        fieldEnd: const PlaceEndpoint(description: 'ceiling'),
        now: _now,
        actor: 'test',
      );
      expect(_refusal(refusal), contains('exactly one'));
    });

    test('naming BOTH is refused too, rather than one quietly winning', () {
      // A caller that passed both would otherwise get the outlet's body
      // and never learn its own `structureBodyId` was ignored.
      final p = _project();
      final refusal = buildAddHomeRunCommand(
        doc: p.doc,
        outletId: p.outletId,
        structureBodyId: p.bodyId,
        fieldLabel: 'LR-SPK-R',
        designator: 'W901',
        netName: 'N901',
        media: const MediaTypeId('media.cat6_utp'),
        fieldEnd: const PlaceEndpoint(description: 'ceiling'),
        now: _now,
        actor: 'test',
      );
      expect(_refusal(refusal), contains('exactly one'));
    });

    test('a boxless run whose field end names NO ROOM is refused', () {
      // `buildScheduleEntry` reads a run's room as
      // `from.locationId ?? outlet?.locationId ?? to.locationId`, and its
      // own comment calls the last of those a trap: "a run's room is
      // where its drop is, not where its rack is". With a box the outlet
      // answers. Without one, a run carrying no location would sort
      // itself silently into the EQUIPMENT ROOM on the Pull Sheet the
      // installer walks the house with.
      final p = _project();
      final refusal = _refusal(boxless(p.doc, p.bodyId, withRoom: false));
      expect(refusal, contains('which room'));
      expect(p.doc.links, isEmpty);
    });

    test('a body this project does not carry is refused', () {
      final p = _project();
      expect(
        _refusal(
          boxless(
            p.doc,
            const Uuid('body-that-is-not-here'),
            roomId: p.roomId,
          ),
        ),
        contains('not in this project'),
      );
    });

    test('the field label is still unique project-wide (CR-113)', () {
      // Losing the outlet must not lose the invariant that goes with the
      // label, which is the one thing a boxless run shares with every
      // other drop.
      final p = _project();
      _ready(_build(p.doc, p.outletId, fieldLabel: 'LR-1')).apply(p.doc);
      expect(
        _refusal(
          boxless(p.doc, p.bodyId, roomId: p.roomId, fieldLabel: 'LR-1'),
        ),
        isNotEmpty,
      );
    });
  });
}
