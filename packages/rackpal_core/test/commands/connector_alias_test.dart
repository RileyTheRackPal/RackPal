// Connector aliases (`#248`, RJ-012, CR-058, DR-107).
//
// ═══════════════════════════════════════════════════════════════════════
// THE FIRST TEST IS THE ONE THAT SAYS THE CHAPTER WAS SMALL
// ═══════════════════════════════════════════════════════════════════════
// `resolveConnectorToken` already resolved a typed token by ALIAS before
// this chapter started, so the Quick Add DSL, the TSV paste path and the
// archetype expander all honoured aliases. What did not exist was any way
// to add one. So the test that matters is not "the command writes a list"
// but "a word a person adds is a word the DSL then accepts", end to end.
import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

const _rj45 = ConnectorTypeId('conn.rj45');
const _xlr = ConnectorTypeId('conn.xlr3');

RackDocument _doc() {
  final doc = RackDocument(
    id: const Uuid('doc-alias'),
    appVersion: '0.4.90',
    createdAt: DateTime.utc(2026, 8, 31),
    modifiedAt: DateTime.utc(2026, 8, 31),
    meta: EntityMeta(
      createdAt: DateTime.utc(2026, 8, 31),
      updatedAt: DateTime.utc(2026, 8, 31),
      updatedBy: 'test',
    ),
  );
  final seed = buildSeedRegistries();
  for (final e in seed.connectorTypes.entries) {
    doc.registries.connectorTypes[e.key] = e.value;
  }
  return doc;
}

List<String> _aliasesOf(RackDocument doc, ConnectorTypeId id) =>
    doc.registries.connectorTypes[id]!.aliases;

void main() {
  group('an added alias is a word the resolver then accepts', () {
    test('the DSL does not know "ethernet" until somebody teaches it, and '
        'does the moment they do', () {
      final doc = _doc();
      expect(
        resolveConnectorToken(doc.registries, 'ethernet'),
        isNull,
        reason:
            'the seed catalog does not ship this spelling; if it starts '
            'to, this test is measuring nothing and needs another word',
      );

      SetConnectorAliasesCommand(
        id: _rj45,
        from: _aliasesOf(doc, _rj45),
        to: [..._aliasesOf(doc, _rj45), 'ethernet'],
      ).apply(doc);

      expect(resolveConnectorToken(doc.registries, 'ethernet')?.id, _rj45);
    });

    test('and the resolver normalises, so case and punctuation do not have '
        'to match what was typed in', () {
      final doc = _doc();
      SetConnectorAliasesCommand(
        id: _rj45,
        from: _aliasesOf(doc, _rj45),
        to: [..._aliasesOf(doc, _rj45), 'Ethernet Jack'],
      ).apply(doc);
      expect(resolveConnectorToken(doc.registries, 'ethernet jack')?.id, _rj45);
      expect(resolveConnectorToken(doc.registries, 'ETHERNET-JACK')?.id, _rj45);
    });

    test(
      'undo restores the list that was there, not merely what was added',
      () {
        final doc = _doc();
        final before = [..._aliasesOf(doc, _rj45)];
        expect(before, isNotEmpty, reason: 'RJ45 ships with trade spellings');

        SetConnectorAliasesCommand(
            id: _rj45,
            from: before,
            to: const ['ethernet'],
          )
          ..apply(doc)
          ..revert(doc);

        expect(_aliasesOf(doc, _rj45), before);
      },
    );

    test('a connector the document does not hold is left alone rather than '
        'invented', () {
      final doc = _doc();
      const ghost = ConnectorTypeId('conn.not_a_real_connector');
      SetConnectorAliasesCommand(
        id: ghost,
        from: const [],
        to: const ['whatever'],
      ).apply(doc);
      expect(doc.registries.connectorTypes.containsKey(ghost), isFalse);
    });

    test('the def is REPLACED, not mutated, because the seeded ones are '
        'const and mutating a const list throws', () {
      final doc = _doc();
      final was = doc.registries.connectorTypes[_rj45];
      SetConnectorAliasesCommand(
        id: _rj45,
        from: _aliasesOf(doc, _rj45),
        to: const ['ethernet'],
      ).apply(doc);
      expect(identical(doc.registries.connectorTypes[_rj45], was), isFalse);
      // And nothing else about the connector moved.
      expect(
        doc.registries.connectorTypes[_rj45]!.displayName,
        was!.displayName,
      );
      expect(
        doc.registries.connectorTypes[_rj45]!.footprintWidth,
        was.footprintWidth,
      );
      expect(doc.registries.connectorTypes[_rj45]!.pitch, was.pitch);
    });
  });

  group('a colliding alias is refused, and the refusal names the owner', () {
    test('a word another connector already answers to is a conflict', () {
      final doc = _doc();
      // Whatever RJ45 ships with, XLR3 must not be allowed to take.
      final taken = _aliasesOf(doc, _rj45).first;
      final owner = connectorAliasConflict(doc.registries, _xlr, taken);
      expect(owner?.id, _rj45);
    });

    test('the id TAIL counts too, because the resolver falls back to it', () {
      final doc = _doc();
      expect(connectorAliasConflict(doc.registries, _xlr, 'rj45')?.id, _rj45);
    });

    test('a connector may keep its own spellings without conflicting with '
        'itself', () {
      final doc = _doc();
      final mine = _aliasesOf(doc, _rj45).first;
      expect(connectorAliasConflict(doc.registries, _rj45, mine), isNull);
    });

    test('a free word is free', () {
      final doc = _doc();
      expect(connectorAliasConflict(doc.registries, _xlr, 'ethernet'), isNull);
    });

    test('WHY A COLLISION MUST BE REFUSED RATHER THAN STORED: the resolver '
        'returns the FIRST match in map order, so two owners of one word '
        'resolve unpredictably', () {
      final doc = _doc();
      // Teach XLR3 a word RJ45 already answers to, bypassing the check the
      // editor makes, and the token becomes ambiguous.
      final taken = _aliasesOf(doc, _rj45).first;
      SetConnectorAliasesCommand(
        id: _xlr,
        from: _aliasesOf(doc, _xlr),
        to: [..._aliasesOf(doc, _xlr), taken],
      ).apply(doc);

      final owners = {
        for (final d in doc.registries.connectorTypes.values)
          if (d.aliases.any(
            (a) => normaliseMediaToken(a) == normaliseMediaToken(taken),
          ))
            d.id,
      };
      expect(
        owners,
        hasLength(2),
        reason:
            'the state the editor exists to prevent is reachable by the '
            'command alone, which is why the check lives beside it',
      );
    });
  });

  // #947. `_write` rebuilt the def field by field and left `matesWith` out,
  // so an alias edit emptied what the connector mates with and the mating
  // rule went quiet for it. Compared as the SAVED FORM minus `aliases`, so
  // the next field added to `ConnectorTypeDef` and forgotten in `_write`
  // fails here too, rather than a list of the fields this test knew about.
  group('an alias edit changes the aliases and NOTHING ELSE', () {
    Map<String, Object?> savedDef(RackDocument doc, ConnectorTypeId id) {
      final tree = const JsonDocumentCodec().encodeToJsonTree(doc);
      final document = tree['document']! as Map<String, Object?>;
      final registries = document['registries']! as Map<String, Object?>;
      final connectors = registries['connectors']! as Map<String, Object?>;
      return Map.of(connectors[id.v]! as Map<String, Object?>)
        ..remove('aliases');
    }

    test('what an XLR mates with survives adding a word for it', () {
      final doc = _doc();
      expect(
        doc.registries.connectorTypes[_xlr]!.matesWith,
        isNotEmpty,
        reason: 'the premise: a seeded connector that mates with something',
      );
      final before = savedDef(doc, _xlr);

      SetConnectorAliasesCommand(
        id: _xlr,
        from: _aliasesOf(doc, _xlr),
        to: [..._aliasesOf(doc, _xlr), 'mic cable end'],
      ).apply(doc);

      expect(_aliasesOf(doc, _xlr), contains('mic cable end'));
      expect(savedDef(doc, _xlr), before);
    });

    test('and so does its undo', () {
      final doc = _doc();
      final before = savedDef(doc, _xlr);
      SetConnectorAliasesCommand(
          id: _xlr,
          from: _aliasesOf(doc, _xlr),
          to: [..._aliasesOf(doc, _xlr), 'mic cable end'],
        )
        ..apply(doc)
        ..revert(doc);
      expect(savedDef(doc, _xlr), before);
    });
  });
}
