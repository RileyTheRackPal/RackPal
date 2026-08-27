// `Ctrl+H` (M4-F8, `#698`, docs/06 §4.6, DR-078 §11.77.3).
//
// The task's own sentence is the second group: keys are the dangerous
// scope, because `PortDef.key` is the migration join (CR-051) and a key
// already published when the builder opened may have another project's
// cables resolving through it. Undo cannot reach those.

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

PortDef _port(
  String key, {
  String? label,
  String? designator,
  String? notes,
  String order = 'a1',
}) => PortDef(
  key: PortKey(key),
  label: label ?? key.toUpperCase(),
  connector: const ConnectorTypeId('conn.hdmi_a'),
  signalFamily: const SignalFamilyId('sig.hdmi'),
  face: Face.rear,
  position: kUnplacedPanelPosition,
  order: FracIndex(order),
  designatorHint: designator,
  notes: notes,
);

TemplateBody _body(List<PortDef> ports) => TemplateBody(
  manufacturer: 'Generic',
  model: '',
  displayName: 'Test',
  ports: ports,
);

TemplateBody _apply(TemplateBody body, PortFindReplaceResult result) {
  for (final command in result.commands) {
    command.apply(body);
  }
  return body;
}

List<PortImpactRow> _preview({
  required TemplateBody body,
  required List<String> selected,
  required PortTextScope scope,
  required String find,
  required String replace,
  Set<String> opened = const {},
  bool useRegex = false,
}) => previewPortFindReplace(
  body: body,
  selectedInOrder: selected,
  scope: scope,
  find: find,
  replace: replace,
  openedPortKeys: opened,
  useRegex: useRegex,
).rows!;

PortFindReplaceResult _run({
  required TemplateBody body,
  required List<String> selected,
  required PortTextScope scope,
  required String find,
  required String replace,
  Set<String> opened = const {},
  bool useRegex = false,
}) => buildPortFindReplace(
  body: body,
  selectedInOrder: selected,
  scope: scope,
  find: find,
  replace: replace,
  openedPortKeys: opened,
  useRegex: useRegex,
);

void main() {
  group('the four scopes', () {
    test('labels', () {
      final body = _body([
        _port('a', label: 'HDMI IN 1'),
        _port('b', label: 'HDMI IN 2', order: 'a2'),
      ]);
      _apply(
        body,
        _run(
          body: body,
          selected: ['a', 'b'],
          scope: PortTextScope.label,
          find: 'IN',
          replace: 'OUT',
        ),
      );
      expect(body.ports.map((p) => p.label), ['HDMI OUT 1', 'HDMI OUT 2']);
    });

    test('designators, and clearing one leaves an unknown not a blank', () {
      final body = _body([_port('a', designator: 'J01')]);
      _apply(
        body,
        _run(
          body: body,
          selected: ['a'],
          scope: PortTextScope.designator,
          find: 'J01',
          replace: '',
        ),
      );
      // G4: an emptied nullable cell is UNKNOWN, and the port goes back
      // to taking its designator from PORT_SEQ.
      expect(body.ports.single.designatorHint, isNull);
    });

    test('notes', () {
      final body = _body([_port('a', notes: 'check torque')]);
      _apply(
        body,
        _run(
          body: body,
          selected: ['a'],
          scope: PortTextScope.notes,
          find: 'torque',
          replace: 'tension',
        ),
      );
      expect(body.ports.single.notes, 'check tension');
    });

    test('a null cell reads as empty and matches nothing', () {
      final body = _body([_port('a')]);
      final rows = _preview(
        body: body,
        selected: ['a'],
        scope: PortTextScope.notes,
        find: 'x',
        replace: 'y',
      );
      expect(rows.single.before, isEmpty);
      expect(rows.single.after, isEmpty);
    });
  });

  group('keys are the dangerous scope', () {
    test('a key rename goes through RenamePortKeyCommand, not a write', () {
      final body = _body([_port('hdmi.in.1')]);
      final result = _run(
        body: body,
        selected: ['hdmi.in.1'],
        scope: PortTextScope.key,
        find: 'in',
        replace: 'out',
      );
      expect(result.commands.single, isA<RenamePortKeyCommand>());
      _apply(body, result);
      expect(body.ports.single.key.v, 'hdmi.out.1');
    });

    test('a PUBLISHED key records the alias, so migrations still join', () {
      final body = _body([_port('hdmi.in.1')]);
      _apply(
        body,
        _run(
          body: body,
          selected: ['hdmi.in.1'],
          scope: PortTextScope.key,
          find: 'in',
          replace: 'out',
          opened: {'hdmi.in.1'},
        ),
      );
      expect(
        body.ports.single.renamedFrom.map((k) => k.v),
        ['hdmi.in.1'],
      );
    });

    test('an UNPUBLISHED key records nothing, so a working title is not '
        'permanent noise', () {
      final body = _body([_port('hdmi.in.1')]);
      _apply(
        body,
        _run(
          body: body,
          selected: ['hdmi.in.1'],
          scope: PortTextScope.key,
          find: 'in',
          replace: 'out',
        ),
      );
      expect(body.ports.single.renamedFrom, isEmpty);
    });

    test('a published row says so in the preview', () {
      final body = _body([_port('hdmi.in.1')]);
      final rows = _preview(
        body: body,
        selected: ['hdmi.in.1'],
        scope: PortTextScope.key,
        find: 'in',
        replace: 'out',
        opened: {'hdmi.in.1'},
      );
      expect(rows.single.note, kPublishedKeyNote);
    });

    test('an unpublished row carries no note', () {
      final body = _body([_port('hdmi.in.1')]);
      final rows = _preview(
        body: body,
        selected: ['hdmi.in.1'],
        scope: PortTextScope.key,
        find: 'in',
        replace: 'out',
      );
      expect(rows.single.note, isNull);
    });
  });

  group('a rename that cannot run is skipped, not thrown', () {
    test('a collision with an existing key is skipped and says so', () {
      // `RenamePortKeyCommand` throws on a duplicate, so the plan must
      // never hand it one.
      final body = _body([
        _port('a.1'),
        _port('a.2', order: 'a2'),
      ]);
      final rows = _preview(
        body: body,
        selected: ['a.1'],
        scope: PortTextScope.key,
        find: '1',
        replace: '2',
      );
      expect(rows.single.note, kKeyCollisionNote);

      final result = _run(
        body: body,
        selected: ['a.1'],
        scope: PortTextScope.key,
        find: '1',
        replace: '2',
      );
      expect(result.commands, isEmpty);
      // And running it changes nothing rather than throwing.
      _apply(body, result);
      expect(body.ports.map((p) => p.key.v), ['a.1', 'a.2']);
    });

    test('two rows renaming to the SAME new key: the second is skipped', () {
      final body = _body([
        _port('in.a'),
        _port('in.b', order: 'a2'),
      ]);
      final rows = _preview(
        body: body,
        selected: ['in.a', 'in.b'],
        scope: PortTextScope.key,
        find: RegExp(r'\.[ab]').pattern,
        replace: '.x',
        useRegex: true,
      );
      expect(rows.first.note, isNull);
      expect(rows.last.note, kKeyCollisionNote);

      _apply(
        body,
        _run(
          body: body,
          selected: ['in.a', 'in.b'],
          scope: PortTextScope.key,
          find: r'\.[ab]',
          replace: '.x',
          useRegex: true,
        ),
      );
      expect(body.ports.map((p) => p.key.v), ['in.x', 'in.b']);
    });

    test('emptying a key is skipped, because a port must have one', () {
      final body = _body([_port('abc')]);
      final rows = _preview(
        body: body,
        selected: ['abc'],
        scope: PortTextScope.key,
        find: 'abc',
        replace: '',
      );
      expect(rows.single.note, kKeyEmptyNote);
      expect(
        _run(
          body: body,
          selected: ['abc'],
          scope: PortTextScope.key,
          find: 'abc',
          replace: '',
        ).commands,
        isEmpty,
      );
    });
  });

  group('regex is opt-in, so the default is literal', () {
    test('literal mode treats a pattern as characters', () {
      // The case #698 names: an installer typing `HDMI (1)` into a box
      // that was silently a regex gets a capture group and no match.
      final body = _body([_port('a', label: 'HDMI (1)')]);
      _apply(
        body,
        _run(
          body: body,
          selected: ['a'],
          scope: PortTextScope.label,
          find: 'HDMI (1)',
          replace: 'HDMI 1',
        ),
      );
      expect(body.ports.single.label, 'HDMI 1');
    });

    test('regex mode matches as a pattern once asked', () {
      final body = _body([_port('a', label: 'IN 007')]);
      _apply(
        body,
        _run(
          body: body,
          selected: ['a'],
          scope: PortTextScope.label,
          find: '0+',
          replace: '',
          useRegex: true,
        ),
      );
      expect(body.ports.single.label, 'IN 7');
    });

    test('an invalid pattern is a refusal, not an exception', () {
      final body = _body([_port('a')]);
      expect(
        _run(
          body: body,
          selected: ['a'],
          scope: PortTextScope.label,
          find: '[',
          replace: 'x',
          useRegex: true,
        ).refusal,
        PortFindReplaceRefusal.patternIsNotValid,
      );
    });

    test('the same invalid pattern is fine as a literal', () {
      final body = _body([_port('a', label: 'A [ B')]);
      _apply(
        body,
        _run(
          body: body,
          selected: ['a'],
          scope: PortTextScope.label,
          find: '[',
          replace: '(',
        ),
      );
      expect(body.ports.single.label, 'A ( B');
    });
  });

  group('reach', () {
    test('only the selection is touched', () {
      final body = _body([
        _port('a', label: 'IN 1'),
        _port('b', label: 'IN 2', order: 'a2'),
      ]);
      _apply(
        body,
        _run(
          body: body,
          selected: ['a'],
          scope: PortTextScope.label,
          find: 'IN',
          replace: 'OUT',
        ),
      );
      expect(body.ports.map((p) => p.label), ['OUT 1', 'IN 2']);
    });

    test('every occurrence in a cell is replaced', () {
      final body = _body([_port('a', label: 'IN 1 IN 2')]);
      _apply(
        body,
        _run(
          body: body,
          selected: ['a'],
          scope: PortTextScope.label,
          find: 'IN',
          replace: 'OUT',
        ),
      );
      expect(body.ports.single.label, 'OUT 1 OUT 2');
    });

    test('a row that matches nothing produces no command and still shows', () {
      final body = _body([_port('a', label: 'SPEAKER')]);
      final rows = _preview(
        body: body,
        selected: ['a'],
        scope: PortTextScope.label,
        find: 'IN',
        replace: 'OUT',
      );
      // IT STILL SHOWS. A search matching nothing has told the person the
      // most useful thing this dialog can tell them.
      expect(rows, hasLength(1));
      expect(rows.single.before, rows.single.after);
      expect(
        _run(
          body: body,
          selected: ['a'],
          scope: PortTextScope.label,
          find: 'IN',
          replace: 'OUT',
        ).commands,
        isEmpty,
      );
    });
  });

  group('refusals', () {
    test('an empty find box', () {
      expect(
        _run(
          body: _body([_port('a')]),
          selected: ['a'],
          scope: PortTextScope.label,
          find: '',
          replace: 'x',
        ).refusal,
        PortFindReplaceRefusal.findIsEmpty,
      );
    });

    test('nothing selected', () {
      expect(
        _run(
          body: _body([_port('a')]),
          selected: const [],
          scope: PortTextScope.label,
          find: 'A',
          replace: 'B',
        ).refusal,
        PortFindReplaceRefusal.nothingSelected,
      );
    });

    test('every refusal has a sentence', () {
      for (final refusal in PortFindReplaceRefusal.values) {
        expect(portFindReplaceRefusalMessage(refusal), isNotEmpty);
      }
    });

    test('every scope names a column the grid also shows', () {
      for (final scope in PortTextScope.values) {
        expect(scope.columnLabel, isNotEmpty);
      }
    });
  });

  group('undo', () {
    test('a key rename and its alias both come back', () {
      final body = _body([_port('hdmi.in.1')]);
      final result = _run(
        body: body,
        selected: ['hdmi.in.1'],
        scope: PortTextScope.key,
        find: 'in',
        replace: 'out',
        opened: {'hdmi.in.1'},
      );
      _apply(body, result);
      for (final command in result.commands.reversed) {
        command.revert(body);
      }
      expect(body.ports.single.key.v, 'hdmi.in.1');
      expect(body.ports.single.renamedFrom, isEmpty);
    });
  });
}
