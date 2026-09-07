// The ACCEPTS column: the port grid's only list-valued cell (DR-081
// §11.80.2, built at DR-134 §11.133).
//
// ═════════════════════════════════════════════════════════════════════
// WHAT A LIST BREAKS THAT A SCALAR DOES NOT
// ═════════════════════════════════════════════════════════════════════
// Every defect this file guards is one shape: `==` on a `List` in Dart is
// IDENTITY. Four places compared readings with it and every one of them
// was wrong the moment a column held a set:
//
//   * `_set` in `port_fill.dart` skipped a write when `now == value`, so
//     a fill-down would have filed a command per row that changed
//     nothing, which is the undo entry M4-D shipped and had to be told
//     about.
//   * `summariseBatch` deduplicated with `contains`, so eight ports that
//     all accept nothing would have read as `Mixed (8 values)`.
//   * `port_grid.dart`'s cell setter had `_set`'s check inline.
//   * `port_commands_test.dart`'s alias census compared field readings,
//     and caught itself on the first run.
//
// `acceptedFamiliesEqual` is the one rule all of them now use, and this
// file is where it is pinned.
import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

final Registries _registries = buildSeedRegistries();

const SignalFamilyId _irEmitter = SignalFamilyId('ctl.ir_emitter');
const SignalFamilyId _ethernet = SignalFamilyId('net.ethernet');

PortDef _port({List<SignalFamilyId> accepts = const []}) => PortDef(
  key: const PortKey('p1'),
  label: 'P',
  order: const FracIndex('a0'),
  connector: const ConnectorTypeId('conn.rj45'),
  signalFamily: const SignalFamilyId('net.ethernet'),
  face: Face.rear,
  acceptedFamilies: [...accepts],
);

TemplateBody _body(List<PortDef> ports) => TemplateBody(
  manufacturer: 'Generic',
  model: 'M',
  displayName: 'Thing',
  category: 'test',
  frontU: 1,
  ports: ports,
);

void main() {
  group('the separator, measured over the real registries', () {
    test('no seeded family label contains a semicolon', () {
      // THE CLAIM `kAcceptedFamiliesSeparator`'s COMMENT MAKES, AS A
      // TEST. A comma is the obvious separator and is wrong: `AUD·Speaker,
      // constant-voltage 70 / 100 / 25 V` carries one. A catalogue entry
      // added later with a semicolon in its display name would make a
      // joined cell unparseable, and would fail here rather than in a
      // paste somebody does on site.
      final labels = signalFamilyCellOptions(_registries);
      expect(labels, isNotEmpty, reason: 'the parser found the registries');
      for (final label in labels) {
        expect(
          label.contains(';'),
          isFalse,
          reason: '$label would break an ACCEPTS cell round trip',
        );
      }
    });
  });

  group('what the cell prints', () {
    test('an empty list says own family only, and NOT the unknown dash', () {
      // G4 spends `—` on unknown. An untouched list is a statement: the
      // author added nothing to the port's own family (DR-081 §11.80.5).
      final text = acceptedFamiliesCellText(_registries, const []);
      expect(text, kAcceptsOwnFamilyOnly);
      expect(text, isNot(contains('—')));
    });

    test('the copy says WIDENS, because the getter does', () {
      // `ConnectTarget.acceptsFamily` is `signalFamily == f ||
      // acceptedFamilies.contains(f)`, so an empty list is the NARROWEST
      // state and not the loosest. DR-081's own prose calls it "this port
      // states no constraint", which would be the opposite of what the
      // port does if a cell printed it.
      expect(kAcceptsOwnFamilyOnly.toLowerCase(), isNot(contains('no ')));
      expect(kAcceptsOwnFamilyOnly.toLowerCase(), contains('only'));
    });

    test('one family prints the menu spelling, not the raw id', () {
      final text = acceptedFamiliesCellText(_registries, const [_irEmitter]);
      expect(text, isNot(_irEmitter.v));
      expect(signalFamilyCellOptions(_registries), contains(text));
    });

    test('the order the author ticked in does not change the cell', () {
      // The determinism invariant, on one cell: same template, same
      // display list. A `List` keeps insertion order and a set has none.
      expect(
        acceptedFamiliesCellText(_registries, const [_irEmitter, _ethernet]),
        acceptedFamiliesCellText(_registries, const [_ethernet, _irEmitter]),
      );
    });

    test('a family the registries do not hold prints its raw id', () {
      // `portFamilyText`'s third state, for its reason: a document naming
      // something the menu cannot offer has to stay visible and fixable.
      const ghost = SignalFamilyId('audio.not_a_real_family');
      expect(
        acceptedFamiliesCellText(_registries, const [ghost]),
        contains(ghost.v),
      );
    });
  });

  group('reading a cell back', () {
    test('every printed cell round-trips to the families it named', () {
      for (final families in <List<SignalFamilyId>>[
        const [],
        const [_irEmitter],
        const [_irEmitter, _ethernet],
      ]) {
        final text = acceptedFamiliesCellText(_registries, families);
        final back = resolveAcceptedFamiliesCell(_registries, text);
        expect(back, isNotNull, reason: text);
        expect(
          acceptedFamiliesEqual(back!, families),
          isTrue,
          reason: '$text resolved to $back',
        );
      }
    });

    test('the empty spelling reads back as an empty list, not as null', () {
      expect(
        resolveAcceptedFamiliesCell(_registries, kAcceptsOwnFamilyOnly),
        isEmpty,
      );
      expect(resolveAcceptedFamiliesCell(_registries, '   '), isEmpty);
    });

    test('ONE unresolvable member refuses the WHOLE cell', () {
      // ALL OR NOTHING, on `resolveSignalFamilyCell`'s precedent. That
      // function refuses rather than inventing a family (DR-025 §11.24.3),
      // and a list that dropped its bad members would do quietly what a
      // single cell will not do at all: the author would see a shorter
      // list where they should see an error.
      final good = acceptedFamiliesCellText(_registries, const [_irEmitter]);
      expect(
        resolveAcceptedFamiliesCell(_registries, '$good; Nonsense·Nothing'),
        isNull,
      );
    });

    test('a duplicate in the text collapses rather than doubling', () {
      final one = acceptedFamiliesCellText(_registries, const [_irEmitter]);
      expect(
        resolveAcceptedFamiliesCell(_registries, '$one; $one'),
        hasLength(1),
      );
    });
  });

  group('equality is by SET, which is what the field means', () {
    test('two orderings of the same families are the same value', () {
      expect(
        acceptedFamiliesEqual(
          const [_irEmitter, _ethernet],
          const [_ethernet, _irEmitter],
        ),
        isTrue,
      );
    });

    test('two separately built empty lists are equal, where == is not', () {
      final a = <SignalFamilyId>[];
      final b = <SignalFamilyId>[];
      expect(a == b, isFalse, reason: 'the trap this exists for');
      expect(acceptedFamiliesEqual(a, b), isTrue);
    });

    test('a different set is a different value', () {
      expect(
        acceptedFamiliesEqual(const [_irEmitter], const [_ethernet]),
        isFalse,
      );
      expect(
        acceptedFamiliesEqual(
          const [_irEmitter],
          const [_irEmitter, _ethernet],
        ),
        isFalse,
      );
    });
  });

  group('the column is plumbed like every other one', () {
    test('it has a header, a width, a pack and a fill', () {
      const id = PortColumnId.acceptedFamilies;
      expect(portColumnHeader(id), 'ACCEPTS');
      expect(portColumnWidth(id), greaterThan(0));
      expect(portColumnPack(id), PortColumnPack.advanced);
      expect(portColumnFill(id), isNotNull);
    });

    test('it is not numeric and offers no enum options', () {
      // The pair `port_batch_test` keeps apart: a column answering yes to
      // both would be a menu poured into a number field. This one answers
      // no to both and is drawn by its own cell, like CONNECTOR and
      // SIGNAL, whose sets also live in `Registries`.
      const id = PortColumnId.acceptedFamilies;
      expect(portColumnIsNumeric(id), isFalse);
      expect(portColumnOptions(id), isNull);
    });

    test('the batch dock prints the cell spelling, not a Dart toString', () {
      expect(
        portValueLabel(
          PortColumnId.acceptedFamilies,
          const [_irEmitter],
          _registries,
        ),
        acceptedFamiliesCellText(_registries, const [_irEmitter]),
      );
    });
  });

  group('a set that has not changed is not an edit', () {
    test('filling down an equal set produces NO command', () {
      // `_set`'s own rule: a transaction full of writes that changed
      // nothing is an undo entry that appears to do nothing when
      // reverted. With `==` on a `List` this produced one command per row.
      final fill = portColumnFill(PortColumnId.acceptedFamilies)!;
      final port = _port(accepts: const [_irEmitter]);
      final source = _port(accepts: const [_ethernet, _irEmitter]);
      expect(
        fill.copy(_port(accepts: const [_irEmitter, _ethernet]), source),
        isNull,
        reason: 'the same two families, ticked in the other order',
      );
      expect(fill.copy(source, port), isNotNull, reason: 'a real change');
    });

    test('a selection of ports that all accept nothing AGREES', () {
      // `summariseBatch` deduplicated with `contains`, so eight identical
      // empty lists read as eight distinct values and the dock offered a
      // `Mixed (8 values)` label with nothing ticked.
      final body = _body([
        for (var i = 0; i < 3; i++)
          PortDef(
            key: PortKey('p$i'),
            label: 'P$i',
            order: FracIndex('a$i'),
            connector: const ConnectorTypeId('conn.rj45'),
            signalFamily: const SignalFamilyId('net.ethernet'),
            face: Face.rear,
          ),
      ]);
      final summary = summariseBatch(
        body: body,
        column: PortColumnId.acceptedFamilies,
        portKeys: const ['p0', 'p1', 'p2'],
      );
      expect(summary, isA<BatchAgreed>());
      expect((summary as BatchAgreed).value, isEmpty);
    });

    test('ports that really disagree still report Mixed', () {
      // The half that makes the case above mean something.
      final body = _body([
        PortDef(
          key: const PortKey('p0'),
          label: 'P0',
          order: const FracIndex('a0'),
          connector: const ConnectorTypeId('conn.rj45'),
          signalFamily: const SignalFamilyId('net.ethernet'),
          face: Face.rear,
        ),
        PortDef(
          key: const PortKey('p1'),
          label: 'P1',
          order: const FracIndex('a1'),
          connector: const ConnectorTypeId('conn.rj45'),
          signalFamily: const SignalFamilyId('net.ethernet'),
          face: Face.rear,
          acceptedFamilies: const [_irEmitter],
        ),
      ]);
      expect(
        summariseBatch(
          body: body,
          column: PortColumnId.acceptedFamilies,
          portKeys: const ['p0', 'p1'],
        ),
        isA<BatchMixed>(),
      );
    });
  });

  group('the accessors copy, so two ports never share one list', () {
    test('the getter hands back a view nothing can write through', () {
      final port = _port(accepts: const [_irEmitter]);
      final read = PortDefField.acceptedFamilies.get(port);
      expect(() => read.add(_ethernet), throwsUnsupportedError);
      expect(port.acceptedFamilies, hasLength(1));
    });

    test('two ports set from ONE list do not alias', () {
      // The defect this prevents is silent: fill a column down eight rows
      // and then edit one, and all eight change.
      final source = <SignalFamilyId>[_irEmitter];
      final a = _port();
      final b = _port();
      PortDefField.acceptedFamilies.set(a, source);
      PortDefField.acceptedFamilies.set(b, source);
      a.acceptedFamilies.add(_ethernet);
      expect(b.acceptedFamilies, hasLength(1));
      expect(source, hasLength(1));
    });

    test('undo restores the set the command was given', () {
      // `SetPortFieldCommand` holds `from` for its revert. An aliased list
      // would make `from` follow `to` and undo restore what it undid.
      final port = _port(accepts: const [_irEmitter]);
      final body = _body([port]);
      final from = PortDefField.acceptedFamilies.get(port);
      final command = SetPortFieldCommand<List<SignalFamilyId>>(
        port: port.key,
        field: PortDefField.acceptedFamilies,
        from: from,
        to: const [_ethernet],
      )..apply(body);
      expect(body.ports.single.acceptedFamilies, const [_ethernet]);
      command.revert(body);
      expect(
        acceptedFamiliesEqual(
          body.ports.single.acceptedFamilies,
          const [_irEmitter],
        ),
        isTrue,
      );
    });
  });
}
