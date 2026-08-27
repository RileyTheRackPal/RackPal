// `#224` (M4-J2) — `Group as set…`, `Ungroup`, and DR-086's closed roles.
//
// ═════════════════════════════════════════════════════════════════════
// THE CASE THIS FILE EXISTS FOR IS `roles run out, they do not cycle`
// ═════════════════════════════════════════════════════════════════════
// Grouping four rows as a stereo pair must give `L`, `R`, blank, blank.
// Cycling reads better in a diff and writes two members claiming one
// role, which `planAtomicConnect` then pairs by position onto two
// different pins while the ROLE column says they are the same thing. A
// test that grouped exactly two rows would never see the difference.
import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

PortDef _port(
  String key, {
  required String order,
  String? set,
  String? role,
}) => PortDef(
  key: PortKey(key),
  label: key.toUpperCase(),
  connector: const ConnectorTypeId('conn.rca'),
  signalFamily: const SignalFamilyId('audio.line_unbal'),
  face: Face.rear,
  position: kUnplacedPanelPosition,
  order: FracIndex(order),
  setKey: set,
  setRole: role,
);

TemplateBody _body() => TemplateBody(
  manufacturer: 'Generic',
  model: 'M',
  displayName: 'Set probe',
  frontU: 1,
  ports: [
    _port('a', order: 'a0000'),
    _port('b', order: 'a0001'),
    _port('c', order: 'a0002'),
    _port('d', order: 'a0003'),
  ],
);

void applyAll(List<Command<TemplateBody>> commands, TemplateBody body) {
  for (final command in commands) {
    command.apply(body);
  }
}

void main() {
  group('DR-086 §11.85.2: a set is made FROM rows', () {
    test('two rows become a set, and every member is written', () {
      final body = _body();
      final result = buildGroupAsSet(
        body: body,
        selectedKeys: {'a', 'b'},
        label: 'Front pair',
        kind: SetKind.stereoPair,
      );

      expect(result.isRefused, isFalse);
      applyAll(result.commands, body);

      expect(body.portSets.single.label, 'Front pair');
      expect(body.portSets.single.kind, SetKind.stereoPair);
      expect(body.ports[0].setKey, body.portSets.single.key);
      expect(body.ports[0].setRole, 'L');
      expect(body.ports[1].setRole, 'R');
      expect(body.ports[2].setKey, isNull);
    });

    test('THE SET LEADS, so no port ever names a set that is not there', () {
      final body = _body();
      final result = buildGroupAsSet(
        body: body,
        selectedKeys: {'a', 'b'},
        label: 'Front pair',
        kind: SetKind.stereoPair,
      );

      expect(result.commands.first, isA<AddPortSetCommand>());
    });

    test('ONE ROW IS REFUSED, because a set of one connects to nothing '
        'atomically and degrades to a single conductor with no error', () {
      final result = buildGroupAsSet(
        body: _body(),
        selectedKeys: {'a'},
        label: 'Lonely',
        kind: SetKind.stereoPair,
      );

      expect(result.refusal, GroupAsSetRefusal.needsTwoRows);
      expect(result.commands, isEmpty);
      expect(
        groupAsSetRefusalMessage(result.refusal!),
        contains('at least two ports'),
      );
    });

    test('IT REFUSES UNDER A SORT, because roles go on in DECLARED order '
        'and the person is looking at another one', () {
      final result = buildGroupAsSet(
        body: _body(),
        selectedKeys: {'a', 'b'},
        label: 'Front pair',
        kind: SetKind.stereoPair,
        viewIsSorted: true,
      );

      expect(result.refusal, GroupAsSetRefusal.theViewIsSorted);
    });

    test('a duplicate label is refused, not suffixed', () {
      final body = _body();
      applyAll(
        buildGroupAsSet(
          body: body,
          selectedKeys: {'a', 'b'},
          label: 'Front pair',
          kind: SetKind.stereoPair,
        ).commands,
        body,
      );

      final second = buildGroupAsSet(
        body: body,
        selectedKeys: {'c', 'd'},
        label: 'front PAIR',
        kind: SetKind.stereoPair,
      );
      expect(second.refusal, GroupAsSetRefusal.labelIsTaken);
    });

    test('THE ORDER IS DERIVED, NOT TAKEN ON FAITH: a selection handed in '
        'any order still takes roles in the declared one', () {
      final body = _body();
      // `d` before `c` in the set literal, and `d` is declared later.
      final result = buildGroupAsSet(
        body: body,
        selectedKeys: {'d', 'c'},
        label: 'Rear pair',
        kind: SetKind.stereoPair,
      );
      applyAll(result.commands, body);

      expect(body.ports[2].setRole, 'L', reason: 'c is declared first');
      expect(body.ports[3].setRole, 'R');
    });
  });

  group('DR-086 §11.85.3: roles are closed, and they run out into blank', () {
    test('the three authorable kinds, spelled as the seed spells them', () {
      expect(setRolesFor(SetKind.stereoPair), ['L', 'R']);
      expect(setRolesFor(SetKind.speakerPair), ['+', '-']);
      expect(setRolesFor(SetKind.componentVideo), ['Y', 'Pb', 'Pr']);
    });

    test('THE HYPHEN IS ASCII, because planAtomicConnect compares roles by '
        'string equality against the seeded catalog', () {
      final minus = setRolesFor(SetKind.speakerPair).last;
      expect(minus.codeUnits, [0x2D]);

      // The other half of the claim: the seed really does spell it that
      // way, so this is a join and not a preference.
      final seeded = buildSeedCatalog().values
          .expand((b) => b.ports)
          .map((p) => p.setRole)
          .whereType<String>()
          .toSet();
      expect(seeded, isNotEmpty, reason: 'the scan must reach real ports');
      expect(seeded, containsAll(<String>['L', 'R', '+', '-']));
      expect(
        seeded.difference({'L', 'R', '+', '-'}),
        isEmpty,
        reason:
            'a seeded role outside the closed list would warn on every '
            'connect to it',
      );
    });

    test('FOUR ROWS AS A STEREO PAIR GIVE L, R, BLANK, BLANK. They do not '
        'cycle, which would give two members one role', () {
      final body = _body();
      final result = buildGroupAsSet(
        body: body,
        selectedKeys: {'a', 'b', 'c', 'd'},
        label: 'Wide',
        kind: SetKind.stereoPair,
      );
      applyAll(result.commands, body);

      expect(
        body.ports.map((p) => p.setRole).toList(),
        ['L', 'R', null, null],
      );
    });

    test('and the preview NAMES every row it left blank', () {
      final result = buildGroupAsSet(
        body: _body(),
        selectedKeys: {'a', 'b', 'c', 'd'},
        label: 'Wide',
        kind: SetKind.stereoPair,
      );

      expect(result.impact.length, 4);
      expect(result.impact[0].note, isNull);
      expect(result.impact[2].note, contains('so it gets none'));
      expect(result.impact[3].note, contains('member 4'));
      expect(portImpactNoteCount(result.impact), 2);
    });

    test('a row leaving another set is named in its own row', () {
      final body = _body();
      applyAll(
        buildGroupAsSet(
          body: body,
          selectedKeys: {'a', 'b'},
          label: 'First pair',
          kind: SetKind.stereoPair,
        ).commands,
        body,
      );

      final moved = buildGroupAsSet(
        body: body,
        selectedKeys: {'b', 'c'},
        label: 'Second pair',
        kind: SetKind.stereoPair,
      );
      expect(
        moved.impact.singleWhere((r) => r.key == 'b').note,
        contains('Leaves "First pair"'),
      );
    });

    test('THE PREVIEW IS THE WRITE: every impact row after-value is what '
        'the commands actually set', () {
      final body = _body();
      final result = buildGroupAsSet(
        body: body,
        selectedKeys: {'a', 'b', 'c'},
        label: 'Component',
        kind: SetKind.componentVideo,
      );
      applyAll(result.commands, body);

      for (final row in result.impact) {
        final port = body.ports.singleWhere((p) => p.key.v == row.key);
        expect(port.setRole ?? '', row.after);
      }
    });
  });

  group('DR-086 §11.85.4: balancedPair is kept and not offered', () {
    test('the picker offers three kinds and not four', () {
      expect(kAuthorableSetKinds, hasLength(3));
      expect(kAuthorableSetKinds, isNot(contains(SetKind.balancedPair)));
    });

    test('A SET THAT ALREADY CARRIES IT SEES IT OFFERED, so opening a '
        'dialog cannot silently retype a seeded value', () {
      expect(setKindOptions(null), kAuthorableSetKinds);
      expect(setKindOptions(SetKind.stereoPair), kAuthorableSetKinds);
      expect(
        setKindOptions(SetKind.balancedPair),
        contains(
          SetKind.balancedPair,
        ),
      );
      expect(setKindOptions(SetKind.balancedPair), hasLength(4));
    });

    test(
      'the seeded catalog still holds one, which is why the value stays',
      () {
        final kinds = buildSeedCatalog().values
            .expand((b) => b.portSets)
            .map((s) => s.kind)
            .toSet();
        expect(kinds, contains(SetKind.balancedPair));
        expect(
          kinds,
          isNot(contains(SetKind.componentVideo)),
          reason:
              'componentVideo is authored zero times, which is what made '
              'the picker question worth asking',
        );
      },
    );
  });

  group('Ungroup', () {
    test('takes the ports out and SWEEPS THE SET IT EMPTIES', () {
      final body = _body();
      applyAll(
        buildGroupAsSet(
          body: body,
          selectedKeys: {'a', 'b'},
          label: 'Front pair',
          kind: SetKind.stereoPair,
        ).commands,
        body,
      );

      final commands = buildUngroupPortSets(
        body: body,
        selectedKeys: {'a', 'b'},
      );
      applyAll(commands, body);

      expect(body.portSets, isEmpty);
      expect(body.ports.every((p) => p.setKey == null), isTrue);
      expect(body.ports.every((p) => p.setRole == null), isTrue);
    });

    test('A SET THAT STILL HAS A MEMBER SURVIVES, and the member that left '
        'is the only one written', () {
      final body = _body();
      applyAll(
        buildGroupAsSet(
          body: body,
          selectedKeys: {'a', 'b', 'c'},
          label: 'Component',
          kind: SetKind.componentVideo,
        ).commands,
        body,
      );

      applyAll(
        buildUngroupPortSets(body: body, selectedKeys: {'c'}),
        body,
      );

      expect(body.portSets, hasLength(1));
      expect(body.ports[0].setRole, 'Y');
      expect(body.ports[2].setKey, isNull);
    });

    test('reverted backwards, the body is exactly what it was', () {
      final body = _body();
      applyAll(
        buildGroupAsSet(
          body: body,
          selectedKeys: {'a', 'b'},
          label: 'Front pair',
          kind: SetKind.stereoPair,
        ).commands,
        body,
      );
      final setKey = body.portSets.single.key;

      final commands = buildUngroupPortSets(
        body: body,
        selectedKeys: {'a', 'b'},
      );
      applyAll(commands, body);
      for (final command in commands.reversed) {
        command.revert(body);
      }

      expect(body.portSets.single.key, setKey);
      expect(body.ports[0].setRole, 'L');
      expect(body.ports[1].setRole, 'R');
    });

    test('a selection in no set produces nothing to do', () {
      expect(
        buildUngroupPortSets(body: _body(), selectedKeys: {'a', 'b'}),
        isEmpty,
      );
    });
  });

  group('a set of one is a notice, not an error', () {
    test('the survivor of a delete carries it, on the SET column', () {
      final body = _body();
      applyAll(
        buildGroupAsSet(
          body: body,
          selectedKeys: {'a', 'b'},
          label: 'Front pair',
          kind: SetKind.stereoPair,
        ).commands,
        body,
      );
      RemovePortCommand(const PortKey('b')).apply(body);

      // KEYED BY THE STRING, because `validatePorts` returns
      // `Map<String, ...>`. The first draft looked this up with a
      // `PortKey` and PASSED, which is not the vacuity it looks like:
      // `PortKey` is an `extension type` over `String` (`ids.dart:37`),
      // so at runtime it IS the key. The analyzer's
      // COLLECTION_METHODS_UNRELATED_TYPE is a static complaint about a
      // no-op, and it is obeyed anyway because warnings are gated at zero
      // and the next reader should not have to know any of the above.
      final issues = validatePorts(body)['a'] ?? <PortIssue>[];
      final notice = issues.singleWhere(
        (i) => i.column == PortColumnId.portSet,
      );
      expect(notice.severity, PortIssueSeverity.notice);
      expect(notice.message, contains('Front pair'));
    });

    test('AND A WHOLE SET DOES NOT, or every stereo pair in the catalog '
        'would light up', () {
      final body = _body();
      applyAll(
        buildGroupAsSet(
          body: body,
          selectedKeys: {'a', 'b'},
          label: 'Front pair',
          kind: SetKind.stereoPair,
        ).commands,
        body,
      );

      final issues = validatePorts(body);
      expect(
        issues.values
            .expand((l) => l)
            .where((i) => i.column == PortColumnId.portSet),
        isEmpty,
      );
    });
  });
}
