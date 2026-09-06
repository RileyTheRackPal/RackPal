// DR-128 §11.127.2: `CON-001`'s remedy, and the writer `InlineAdapter`
// never had.
//
// ═════════════════════════════════════════════════════════════════════
// THE ARTIFACT IS "THE RULE GOES QUIET", NOT "A FIELD GOT SET"
// ═════════════════════════════════════════════════════════════════════
// House style: assert the artifact, not the mechanism. A test that
// checked `link.inlineAdapters.length == 1` would pass on an adapter
// carrying the wrong connectors, the wrong rule id, or a rule id nothing
// reads, and every one of those is the defect DR-128 exists to fix. So
// the assertions run `evaluateSpringBack` before and after and require
// the chip to disappear.
//
// That also makes this file fail if `_adapterSatisfies` is ever changed
// to read a different field, which a mechanism test would not.
import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

import '../validation/fixtures/spring_back_scenarios.dart';

/// Two pins whose connectors do not mate, so `CON-001` fires.
RackDocument _mismatchedDoc() => springBackPair(
  springBackPort('p', 'audio.line_unbal', connector: 'conn.xlr3'),
  springBackPort(
    'p',
    'audio.line_unbal',
    dir: PortDirection.sink,
    connector: 'conn.rca',
  ),
);

ConnectTarget _a(RackDocument doc) =>
    resolveConnectTarget(doc, deviceId: springBackA, portKey: 'p')!;
ConnectTarget _b(RackDocument doc) =>
    resolveConnectTarget(doc, deviceId: springBackB, portKey: 'p')!;

/// A cable between the two pins, so there is something to declare on.
Uuid _linkThem(RackDocument doc) {
  final built = buildSplitConnectCommands(
    doc: doc,
    from: _a(doc),
    to: _b(doc),
    media: const MediaTypeId('media.22_2'),
    now: springBackWhen,
    actor: 'test',
  );
  final ready = built as SplitConnectReady;
  for (final c in ready.commands) {
    c.apply(doc);
  }
  return ready.connect.id;
}

void main() {
  group('CON-001 fires, and declaring the adapter is what clears it', () {
    test('the rule fires on the bare cable, so the test is not vacuous', () {
      final doc = _mismatchedDoc();
      final linkId = _linkThem(doc);
      final verdict = evaluateSpringBack(
        doc,
        _a(doc),
        _b(doc),
        ontoLink: linkId,
      );
      expect(verdict, isA<SpringBackChip>());
      expect(
        (verdict as SpringBackChip).rule,
        SpringBackRule.connectorsDoNotMate,
      );
    });

    test('and goes quiet once the adapter is declared', () {
      final doc = _mismatchedDoc();
      final linkId = _linkThem(doc);
      final built = buildDeclareAdapterCommand(
        doc: doc,
        linkId: linkId,
        from: _a(doc),
        to: _b(doc),
        ruleId: 'CON-001',
      );
      expect(built, isA<DeclareAdapterReady>());
      (built as DeclareAdapterReady).command.apply(doc);

      expect(
        evaluateSpringBack(doc, _a(doc), _b(doc), ontoLink: linkId),
        isA<SpringBackClear>(),
        reason:
            'CON-001 says "declaring the adapter clears it", and until '
            'DR-128 nothing could declare one',
      );
    });

    test('undo puts the rule back, which is the same assertion reversed', () {
      final doc = _mismatchedDoc();
      final linkId = _linkThem(doc);
      final built = buildDeclareAdapterCommand(
        doc: doc,
        linkId: linkId,
        from: _a(doc),
        to: _b(doc),
        ruleId: 'CON-001',
      );
      (built as DeclareAdapterReady).command
        ..apply(doc)
        ..revert(doc);
      expect(doc.links[linkId]!.inlineAdapters, isEmpty);
      expect(
        evaluateSpringBack(doc, _a(doc), _b(doc), ontoLink: linkId),
        isA<SpringBackChip>(),
      );
    });
  });

  group('what it takes from the pins, and what it refuses', () {
    test('both connectors are prefilled from the two ends that failed', () {
      final doc = _mismatchedDoc();
      final linkId = _linkThem(doc);
      final cmd =
          (buildDeclareAdapterCommand(
                    doc: doc,
                    linkId: linkId,
                    from: _a(doc),
                    to: _b(doc),
                    ruleId: 'CON-001',
                  )
                  as DeclareAdapterReady)
              .command;
      expect(cmd.fromConnector.v, 'conn.xlr3');
      expect(cmd.toConnector.v, 'conn.rca');
    });

    test('an absent model stays absent rather than becoming a blank string, '
        'because unknown is not the empty answer (G4/CR-114)', () {
      final doc = _mismatchedDoc();
      final linkId = _linkThem(doc);
      for (final given in [null, '', '   ']) {
        final cmd =
            (buildDeclareAdapterCommand(
                      doc: doc,
                      linkId: linkId,
                      from: _a(doc),
                      to: _b(doc),
                      ruleId: 'CON-001',
                      model: given,
                    )
                    as DeclareAdapterReady)
                .command;
        expect(cmd.model, isNull, reason: 'given ${given.runtimeType} $given');
      }
    });

    test('a model that was typed is kept, and trimmed', () {
      final doc = _mismatchedDoc();
      final linkId = _linkThem(doc);
      final cmd =
          (buildDeclareAdapterCommand(
                    doc: doc,
                    linkId: linkId,
                    from: _a(doc),
                    to: _b(doc),
                    ruleId: 'CON-001',
                    model: '  Neutrik NA2MPMF  ',
                  )
                  as DeclareAdapterReady)
              .command;
      expect(cmd.model, 'Neutrik NA2MPMF');
    });

    test('a rule no adapter can answer for is refused, so an adapter cannot '
        'claim to have made a rack lighter', () {
      final doc = _mismatchedDoc();
      final linkId = _linkThem(doc);
      final built = buildDeclareAdapterCommand(
        doc: doc,
        linkId: linkId,
        from: _a(doc),
        to: _b(doc),
        ruleId: 'RCK-003',
      );
      expect(built, isA<DeclareAdapterRefused>());
      expect((built as DeclareAdapterRefused).message, contains('RCK-003'));
    });

    test('the satisfiable set is exactly the rules that READ the field', () {
      // A census, not a list: `_adapterSatisfies` is called from two
      // predicates and the constant must not drift past them.
      expect(kAdapterSatisfiableRuleIds, {'CON-001', 'SIG-002'});
    });

    test('two ends that already mate are refused, because the chip is a '
        'frame old and an override can make them agree in between', () {
      final doc = springBackPair(
        springBackPort('p', 'audio.line_unbal', connector: 'conn.rca'),
        springBackPort(
          'p',
          'audio.line_unbal',
          dir: PortDirection.sink,
          connector: 'conn.rca',
        ),
      );
      final linkId = _linkThem(doc);
      final built = buildDeclareAdapterCommand(
        doc: doc,
        linkId: linkId,
        from: _a(doc),
        to: _b(doc),
        ruleId: 'CON-001',
      );
      expect(built, isA<DeclareAdapterRefused>());
      expect((built as DeclareAdapterRefused).message, contains('already fit'));
    });

    test('pressing the button twice does not put two barrels in the BOM', () {
      final doc = _mismatchedDoc();
      final linkId = _linkThem(doc);
      (buildDeclareAdapterCommand(
                doc: doc,
                linkId: linkId,
                from: _a(doc),
                to: _b(doc),
                ruleId: 'CON-001',
              )
              as DeclareAdapterReady)
          .command
          .apply(doc);
      final second = buildDeclareAdapterCommand(
        doc: doc,
        linkId: linkId,
        from: _a(doc),
        to: _b(doc),
        ruleId: 'CON-001',
      );
      expect(second, isA<DeclareAdapterRefused>());
      expect(doc.links[linkId]!.inlineAdapters, hasLength(1));
    });

    test('a cable deleted between the chip and the button is refused, not '
        'crashed on', () {
      final doc = _mismatchedDoc();
      final linkId = _linkThem(doc);
      final from = _a(doc);
      final to = _b(doc);
      doc.links.remove(linkId);
      final built = buildDeclareAdapterCommand(
        doc: doc,
        linkId: linkId,
        from: from,
        to: to,
        ruleId: 'CON-001',
      );
      expect(built, isA<DeclareAdapterRefused>());
    });
  });

  group('undoing what was never applied, and the identity revert', () {
    test('revert before apply throws rather than silently doing nothing', () {
      final doc = _mismatchedDoc();
      final linkId = _linkThem(doc);
      final cmd = DeclareInlineAdapterCommand(
        linkId: linkId,
        fromConnector: const ConnectorTypeId('conn.xlr3'),
        toConnector: const ConnectorTypeId('conn.rca'),
        satisfiesRuleIds: const ['CON-001'],
      );
      expect(() => cmd.revert(doc), throwsStateError);
    });

    test('revert removes ITS OWN adapter when an identical one sits beside '
        'it, which value equality would get wrong', () {
      // Two barrels on one long run is an ordinary thing, and
      // `List.remove` takes the first `==` match.
      final doc = _mismatchedDoc();
      final linkId = _linkThem(doc);
      final twin = InlineAdapter(
        fromConnector: const ConnectorTypeId('conn.xlr3'),
        toConnector: const ConnectorTypeId('conn.rca'),
        satisfiesRuleIds: ['CON-001'],
      );
      doc.links[linkId]!.inlineAdapters.add(twin);

      final cmd = DeclareInlineAdapterCommand(
        linkId: linkId,
        fromConnector: const ConnectorTypeId('conn.xlr3'),
        toConnector: const ConnectorTypeId('conn.rca'),
        satisfiesRuleIds: const ['CON-001'],
      )..apply(doc);
      expect(doc.links[linkId]!.inlineAdapters, hasLength(2));
      cmd.revert(doc);

      final left = doc.links[linkId]!.inlineAdapters;
      expect(left, hasLength(1));
      expect(
        identical(left.single, twin),
        isTrue,
        reason:
            'the one that survived must be the one this command did '
            'not add',
      );
    });
  });
}
