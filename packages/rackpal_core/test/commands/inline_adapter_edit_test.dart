// DR-235 §11.234.2 (`#1001`): naming and removing a declared adapter.
//
// THE CASE THIS FILE EXISTS FOR is `two equal adapters`. An `InlineAdapter`
// has no id, two barrels on one long run are field-for-field equal, and a
// command that found its adapter by value would rename or remove the wrong
// one and undo onto the wrong one. Every case asserts the adapter INSTANCE.
import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

final _when = DateTime.utc(2026, 10, 4);

const _link = Uuid('lnk-a');

InlineAdapter _barrel() => InlineAdapter(
  fromConnector: const ConnectorTypeId('conn.f_type'),
  toConnector: const ConnectorTypeId('conn.bnc'),
  satisfiesRuleIds: ['CON-001'],
);

RackDocument _doc(List<InlineAdapter> adapters) {
  final doc = RackDocument(
    id: const Uuid('doc-adapters'),
    appVersion: 'test',
    createdAt: _when,
    modifiedAt: _when,
    meta: EntityMeta(createdAt: _when, updatedAt: _when, updatedBy: 'test'),
    registries: buildSeedRegistries(),
  );
  doc.links[_link] = Link(
    id: _link,
    designator: 'W001',
    media: const MediaTypeId('media.rg6'),
    order: const FracIndex('a0'),
    meta: EntityMeta(createdAt: _when, updatedAt: _when, updatedBy: 'test'),
    inlineAdapters: adapters,
  );
  return doc;
}

void main() {
  group('SetInlineAdapterModelCommand', () {
    test('names the part, trimmed, and undo restores the absence', () {
      final a = _barrel();
      final doc = _doc([a]);
      final command = SetInlineAdapterModelCommand(
        linkId: _link,
        index: 0,
        model: '  Belden F-to-BNC  ',
      );
      expect(command.apply(doc), isTrue);
      expect(a.model, 'Belden F-to-BNC');
      command.revert(doc);
      expect(a.model, isNull);
    });

    test('A BLANK MODEL IS NO MODEL (G4)', () {
      final a = _barrel()..model = 'Belden F-to-BNC';
      final doc = _doc([a]);
      expect(
        SetInlineAdapterModelCommand(
          linkId: _link,
          index: 0,
          model: '   ',
        ).apply(doc),
        isTrue,
      );
      expect(a.model, isNull, reason: 'absent, not an empty string');
    });

    test('the value it already has is no command', () {
      final doc = _doc([_barrel()..model = 'X']);
      expect(
        SetInlineAdapterModelCommand(
          linkId: _link,
          index: 0,
          model: 'X',
        ).apply(doc),
        isFalse,
      );
    });

    test('an index or a cable the document does not hold applies nothing', () {
      final doc = _doc([_barrel()]);
      expect(
        SetInlineAdapterModelCommand(
          linkId: _link,
          index: 1,
          model: 'X',
        ).apply(doc),
        isFalse,
      );
      expect(
        SetInlineAdapterModelCommand(
          linkId: const Uuid('gone'),
          index: 0,
          model: 'X',
        ).apply(doc),
        isFalse,
      );
    });

    test('TWO EQUAL ADAPTERS: the second is named, not the first', () {
      final first = _barrel();
      final second = _barrel();
      final doc = _doc([first, second]);
      SetInlineAdapterModelCommand(
        linkId: _link,
        index: 1,
        model: 'Second',
      ).apply(doc);
      expect(first.model, isNull);
      expect(second.model, 'Second');
    });
  });

  group('RemoveInlineAdapterCommand', () {
    test('TWO EQUAL ADAPTERS: removing the second keeps the first, and undo '
        'puts the same instance back where it was', () {
      final first = _barrel();
      final second = _barrel();
      final third = _barrel();
      final doc = _doc([first, second, third]);
      final command = RemoveInlineAdapterCommand(linkId: _link, index: 1);
      expect(command.apply(doc), isTrue);
      expect(doc.links[_link]!.inlineAdapters, [same(first), same(third)]);
      command.revert(doc);
      expect(doc.links[_link]!.inlineAdapters, [
        same(first),
        same(second),
        same(third),
      ]);
    });

    test('an index the document does not hold applies nothing', () {
      final doc = _doc([_barrel()]);
      expect(
        RemoveInlineAdapterCommand(linkId: _link, index: 3).apply(doc),
        isFalse,
      );
      expect(doc.links[_link]!.inlineAdapters, hasLength(1));
    });
  });

  group('adapterConnectorsLabel', () {
    test('names both connectors by their display names, source side first', () {
      final reg = buildSeedRegistries();
      final adapter = InlineAdapter(
        fromConnector: const ConnectorTypeId('conn.euroblock_3'),
        toConnector: const ConnectorTypeId('conn.xlr3'),
      );
      expect(adapterConnectorsLabel(reg, adapter), 'Euroblock 3-pole to XLR3');
    });

    test('AN UNKNOWN CONNECTOR PRINTS ITS ID, not a blank', () {
      final adapter = InlineAdapter(
        fromConnector: const ConnectorTypeId('conn.mystery'),
        toConnector: const ConnectorTypeId('conn.xlr3'),
      );
      expect(
        adapterConnectorsLabel(buildSeedRegistries(), adapter),
        'conn.mystery to XLR3',
      );
    });
  });
}
