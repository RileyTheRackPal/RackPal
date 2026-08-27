// ignore_for_file: cascade_invocations, an apply/revert pair with
// assertions BETWEEN the two calls is the shape most of these tests take;
// collapsing the pair into a cascade would delete the intermediate
// assertion.
//
// Editing a drop after it exists — board M3-A/8, CR-113, AC-019.
//
// =====================================================================
// THE PROPERTY THIS FILE IS FOR
// =====================================================================
// `buildAddHomeRunCommand` refuses to CREATE a drop whose field label is
// already spent. Until M3-A/8 nothing stopped the same collision arriving
// the other way — by renaming an existing drop onto another's label —
// because nothing could rename one at all. The bug that would have shipped
// if the edit path had been built as a plain accessor-table row is two
// rows an installer cannot tell apart, written silently, through the
// ordinary edit path.
//
// So the load-bearing group is `it refuses`, and the case that matters
// most inside it is `renaming a drop onto ITS OWN label`: the scan has to
// exclude the link being edited, or every rename refuses itself and the
// feature is unusable in the other direction.
import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

final _now = DateTime.utc(2026, 8, 6);
final _later = DateTime.utc(2026, 8, 7);

EntityMeta _meta() =>
    EntityMeta(createdAt: _now, updatedAt: _now, updatedBy: 'seed');

/// A project with one Structure body, one Outlet, and TWO home runs — two
/// because every uniqueness question in this file needs a second drop to
/// collide with.
({RackDocument doc, Uuid outletId, Uuid linkA, Uuid linkB}) _project() {
  final doc = RackDocument(
    id: const Uuid('doc-origin-edit'),
    appVersion: '0.1.0',
    createdAt: _now,
    modifiedAt: _now,
    meta: _meta(),
  );
  final structure = AddStructureCommand(
    title: 'Rough-In',
    designator: 'STR-1',
    now: _now,
    actor: 'seed',
  )..apply(doc);
  final outlet = AddOutletCommand(
    structureBodyId: structure.bodyId,
    designation: 'GR-TV-1',
    order: nextOutletOrder(doc),
    now: _now,
    actor: 'seed',
  )..apply(doc);

  AddHomeRunCommand drop(String label, String designator, String? rackLabel) =>
      (buildAddHomeRunCommand(
                doc: doc,
                outletId: outlet.id,
                fieldLabel: label,
                designator: designator,
                netName: designator,
                media: const MediaTypeId('media.cat6_utp'),
                fieldEnd: const PlaceEndpoint(description: 'Great Room'),
                terminationField: TerminationType.keystone,
                rackLabel: rackLabel,
                now: _now,
                actor: 'seed',
              )
              as AddHomeRunReady)
          .command
        ..apply(doc);

  final a = drop('GR-DATA-1', 'W001', 'PP1-01');
  final b = drop('GR-DATA-2', 'W002', 'PP1-02');

  return (doc: doc, outletId: outlet.id, linkA: a.id, linkB: b.id);
}

SetStructureOriginResult _set<T>(
  RackDocument doc,
  Uuid linkId,
  EntityField<Link, T> field,
  T to, {
  Set<String> alsoUsedLabels = const {},
  Set<String> alsoUsedRackLabels = const {},
}) => buildSetStructureOriginProperty<T>(
  doc: doc,
  linkId: linkId,
  field: field,
  to: to,
  now: _later,
  actor: 'tester',
  alsoUsedLabels: alsoUsedLabels,
  alsoUsedRackLabels: alsoUsedRackLabels,
);

SetEntityPropertyCommand<Link, T> _ready<T>(SetStructureOriginResult r) =>
    (r as SetStructureOriginReady<T>).command;

String _refusal(SetStructureOriginResult r) =>
    (r as SetStructureOriginRefused).reason;

StructureOrigin _origin(RackDocument doc, Uuid linkId) =>
    doc.links[linkId]!.structureOrigin!;

void main() {
  group('the edit it produces', () {
    test('writes the label and reverts it exactly', () {
      final p = _project();
      final cmd = _ready<String>(
        _set(p.doc, p.linkA, StructureOriginField.fieldLabel, 'GR-DATA-9'),
      );

      cmd.apply(p.doc);
      expect(_origin(p.doc, p.linkA).fieldLabel, 'GR-DATA-9');

      cmd.revert(p.doc);
      expect(_origin(p.doc, p.linkA).fieldLabel, 'GR-DATA-1');
    });

    test('touches the LINK, because that is where the origin lives '
        '(AC-019)', () {
      // The reason the table is `EntityField<Link, T>`: a `StructureOrigin`
      // has no id and no `EntityMeta` of its own, so the revision that
      // moves is its link's, and undo has to put THAT back.
      final p = _project();
      final before = p.doc.links[p.linkA]!.meta.localRevision;
      final cmd = _ready<String>(
        _set(p.doc, p.linkA, StructureOriginField.fieldLabel, 'GR-DATA-9'),
      );

      cmd.apply(p.doc);
      expect(p.doc.links[p.linkA]!.meta.localRevision, before + 1);
      expect(p.doc.links[p.linkA]!.meta.updatedBy, 'tester');

      cmd.revert(p.doc);
      expect(
        p.doc.links[p.linkA]!.meta.localRevision,
        before,
        reason: 'a revision left one higher is what breaks CR-117',
      );
    });

    test('reaches the SCHEDULE, which is the surface the label is for', () {
      final p = _project();
      _ready<String>(
        _set(p.doc, p.linkA, StructureOriginField.fieldLabel, 'GR-DATA-9'),
      ).apply(p.doc);

      final row = buildSchedule(
        p.doc,
      ).rows.singleWhere((r) => r.linkId == p.linkA);
      expect(row.fieldLabel, 'GR-DATA-9');
    });

    test('the non-label fields go through the same builder', () {
      final p = _project();
      _ready<Wall?>(
        _set(p.doc, p.linkA, StructureOriginField.wall, Wall.s),
      ).apply(p.doc);
      _ready<TerminationType?>(
        _set(
          p.doc,
          p.linkA,
          StructureOriginField.terminationField,
          TerminationType.punchdown,
        ),
      ).apply(p.doc);

      expect(_origin(p.doc, p.linkA).wall, Wall.s);
      expect(
        _origin(p.doc, p.linkA).terminationField,
        TerminationType.punchdown,
      );
    });

    test('a blank rack label becomes NULL, not an empty string', () {
      // G4/CR-114: clearing the box means "I do not know where this
      // lands", and `''` would be a third state the schedule has to guess
      // about.
      final p = _project();
      _ready<String?>(
        _set(p.doc, p.linkA, StructureOriginField.rackLabel, '   '),
      ).apply(p.doc);

      expect(_origin(p.doc, p.linkA).rackLabel, isNull);
    });

    test('a field label is TRIMMED before it is written', () {
      final p = _project();
      _ready<String>(
        _set(p.doc, p.linkA, StructureOriginField.fieldLabel, '  GR-DATA-9 '),
      ).apply(p.doc);

      expect(_origin(p.doc, p.linkA).fieldLabel, 'GR-DATA-9');
    });

    test('CR-117: the bytes come back exactly', () {
      const codec = JsonDocumentCodec();
      final p = _project();
      final before = codec.write(p.doc);
      final cmd = _ready<String>(
        _set(p.doc, p.linkA, StructureOriginField.fieldLabel, 'GR-DATA-9'),
      )..apply(p.doc);
      expect(codec.write(p.doc), isNot(orderedEquals(before)));

      cmd.revert(p.doc);
      expect(codec.write(p.doc), orderedEquals(before));
    });

    test('clearing a rack label leaves NO key behind', () {
      const codec = JsonDocumentCodec();
      final p = _project();
      _ready<String?>(
        _set(p.doc, p.linkA, StructureOriginField.rackLabel, null),
      ).apply(p.doc);
      _ready<String?>(
        _set(p.doc, p.linkB, StructureOriginField.rackLabel, null),
      ).apply(p.doc);

      expect(
        String.fromCharCodes(codec.write(p.doc)),
        isNot(contains('rackLabel')),
        reason: 'unknown serializes as an absent key, never a null one',
      );
    });
  });

  group('it refuses rather than silently breaking CR-113', () {
    test('renaming a drop onto ANOTHER drop label', () {
      final p = _project();
      final r = _set(
        p.doc,
        p.linkA,
        StructureOriginField.fieldLabel,
        'GR-DATA-2',
      );

      expect(r, isA<SetStructureOriginRefused>());
      expect(_refusal(r), contains('unique project-wide'));
      expect(
        _origin(p.doc, p.linkA).fieldLabel,
        'GR-DATA-1',
        reason: 'a refusal must not have written anything',
      );
    });

    test('renaming a drop onto ITS OWN label is UNCHANGED, not refused', () {
      // The case that makes the feature usable in the other direction: a
      // scan that counted a link against itself would refuse every rename.
      final p = _project();

      expect(
        _set(p.doc, p.linkA, StructureOriginField.fieldLabel, 'GR-DATA-1'),
        isA<SetStructureOriginUnchanged>(),
      );
    });

    test('a rename that only changes surrounding whitespace is UNCHANGED', () {
      // Trimming happens BEFORE the no-op check, so " GR-DATA-1 " is the
      // label it already has rather than a new one that collides with
      // itself.
      final p = _project();

      expect(
        _set(p.doc, p.linkA, StructureOriginField.fieldLabel, ' GR-DATA-1 '),
        isA<SetStructureOriginUnchanged>(),
      );
    });

    test('an empty field label', () {
      final p = _project();
      final r = _set(p.doc, p.linkA, StructureOriginField.fieldLabel, '   ');

      expect(r, isA<SetStructureOriginRefused>());
      expect(_refusal(r), contains('needs a field label'));
    });

    test('a rack label already used at the panel', () {
      final p = _project();
      final r = _set(
        p.doc,
        p.linkA,
        StructureOriginField.rackLabel,
        'PP1-02',
      );

      expect(r, isA<SetStructureOriginRefused>());
      expect(_refusal(r), contains('already used at the panel'));
    });

    test('a link that is not a home run at all', () {
      final p = _project();
      final ordinary = AddLinkCommand(
        designator: 'W900',
        netName: 'N900',
        media: const MediaTypeId('media.cat6_utp'),
        order: nextLinkOrder(p.doc),
        now: _now,
        actor: 'seed',
      )..apply(p.doc);

      final r = _set(
        p.doc,
        ordinary.id,
        StructureOriginField.fieldLabel,
        'GR-DATA-9',
      );

      expect(r, isA<SetStructureOriginRefused>());
      expect(_refusal(r), contains('not a home run'));
    });

    test('a link that is not in the project', () {
      final p = _project();
      final r = _set(
        p.doc,
        const Uuid('nope'),
        StructureOriginField.fieldLabel,
        'GR-DATA-9',
      );

      expect(r, isA<SetStructureOriginRefused>());
      expect(_refusal(r), contains('not in this project'));
    });

    test('a collision against a SIBLING being edited in the same gesture', () {
      // The reason `alsoUsed*` exists on the edit path too. A bulk relabel
      // is built against ONE unmutated document, so without a reservation
      // every row passes the document check and they collide on apply.
      final p = _project();

      expect(
        _set(
          p.doc,
          p.linkA,
          StructureOriginField.fieldLabel,
          'GR-DATA-7',
          alsoUsedLabels: {'GR-DATA-7'},
        ),
        isA<SetStructureOriginRefused>(),
      );
      expect(
        _set(
          p.doc,
          p.linkA,
          StructureOriginField.rackLabel,
          'PP1-07',
          alsoUsedRackLabels: {'PP1-07'},
        ),
        isA<SetStructureOriginRefused>(),
      );
    });
  });

  group('one uniqueness scan, shared by the create and the edit path', () {
    test('usedFieldLabels sees every drop, and skips the excepted one', () {
      final p = _project();

      expect(usedFieldLabels(p.doc), {'GR-DATA-1', 'GR-DATA-2'});
      expect(usedFieldLabels(p.doc, exceptLinkId: p.linkA), {'GR-DATA-2'});
      expect(usedFieldLabels(p.doc, alsoUsed: {'GR-DATA-3'}), hasLength(3));
    });

    test('usedRackLabels holds only the drops that HAVE one', () {
      // An absent rack label is unknown (G4), not a value competing for
      // uniqueness — so clearing one must free it for another drop.
      final p = _project();
      expect(usedRackLabels(p.doc), {'PP1-01', 'PP1-02'});

      _ready<String?>(
        _set(p.doc, p.linkA, StructureOriginField.rackLabel, null),
      ).apply(p.doc);

      expect(usedRackLabels(p.doc), {'PP1-02'});
      expect(
        _set(p.doc, p.linkB, StructureOriginField.rackLabel, 'PP1-01'),
        isA<SetStructureOriginReady<String?>>(),
        reason: 'the freed label must be available again',
      );
    });

    test('the CREATE path still refuses what the EDIT path refuses', () {
      // Both now go through the same scan; this is the case that would
      // notice if one of them stopped.
      final p = _project();

      expect(
        buildAddHomeRunCommand(
          doc: p.doc,
          outletId: p.outletId,
          fieldLabel: 'GR-DATA-2',
          designator: 'W003',
          netName: 'N003',
          media: const MediaTypeId('media.cat6_utp'),
          fieldEnd: const PlaceEndpoint(description: 'Great Room'),
          terminationField: TerminationType.keystone,
          now: _now,
          actor: 'seed',
        ),
        isA<AddHomeRunRefused>(),
      );
    });
  });

  group('the wall-end termination is UNKNOWABLE, and says so (M3-J)', () {
    test('a home run can carry no termination at all', () {
      // Non-nullable until M3-J, so `unterminated` was the only way to
      // say "not a keystone" and `_terminationOf`'s "then nothing" arm
      // was unreachable for a home run. Null is unknown (G4, CR-114);
      // `unterminated` is the coil somebody deliberately left bare.
      final p = _project();
      _ready<TerminationType?>(
        _set(p.doc, p.linkA, StructureOriginField.terminationField, null),
      ).apply(p.doc);

      expect(_origin(p.doc, p.linkA).terminationField, isNull);
    });

    test('and the key is ABSENT on the wire rather than written null', () {
      // G4's serialization rule (CR-114): unknown is an absent key, never
      // an explicit `null`.
      final p = _project();
      _ready<TerminationType?>(
        _set(p.doc, p.linkA, StructureOriginField.terminationField, null),
      ).apply(p.doc);

      final tree = const JsonDocumentCodec().encodeToJsonTree(p.doc);
      final links =
          (tree['document']! as Map<String, Object?>)['links']!
              as Map<String, Object?>;
      final origin =
          (links[p.linkA.v]! as Map<String, Object?>)['structureOrigin']!
              as Map<String, Object?>;

      expect(origin.containsKey('terminationField'), isFalse);
      expect(origin['fieldLabel'], isNotNull);
    });

    test('a set one still writes, so CR-117 holds for every file so far', () {
      // The key was UNCONDITIONAL before this change, so every document
      // ever written carries it. Reading yields the value and writing
      // writes it back: no existing file moves a byte.
      final p = _project();
      final tree = const JsonDocumentCodec().encodeToJsonTree(p.doc);
      final links =
          (tree['document']! as Map<String, Object?>)['links']!
              as Map<String, Object?>;
      final origin =
          (links[p.linkA.v]! as Map<String, Object?>)['structureOrigin']!
              as Map<String, Object?>;

      expect(origin['terminationField'], 'keystone');
    });
  });

  group('the table itself', () {
    test('every key is unique and namespaced away from a Link field', () {
      // The rows are `EntityField<Link, T>`, so an unprefixed `wall` key
      // would share a merge key with a future `LinkField.wall` on the same
      // link id and collapse two unrelated edits into one undo entry.
      final keys = [for (final f in StructureOriginField.all) f.key];

      expect(keys.toSet(), hasLength(keys.length));
      for (final key in keys) {
        expect(key, startsWith('origin.'), reason: key);
      }
      for (final f in LinkField.all) {
        expect(keys, isNot(contains(f.key)));
      }
    });

    test('every row declares wires AND meta', () {
      for (final f in StructureOriginField.all) {
        expect(f.touches.has(EpochMask.wires), isTrue, reason: f.key);
        expect(f.touches.has(EpochMask.meta), isTrue, reason: f.key);
      }
    });

    test('a row driven against a non-home-run link names itself', () {
      // The table's `get`/`set` are reachable without the builder, so they
      // carry their own guard rather than a bare `!`.
      final p = _project();
      final ordinary = AddLinkCommand(
        designator: 'W900',
        netName: 'N900',
        media: const MediaTypeId('media.cat6_utp'),
        order: nextLinkOrder(p.doc),
        now: _now,
        actor: 'seed',
      )..apply(p.doc);

      expect(
        () => StructureOriginField.fieldLabel.get(p.doc.links[ordinary.id]!),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('not a home run'),
          ),
        ),
      );
    });
  });
}
