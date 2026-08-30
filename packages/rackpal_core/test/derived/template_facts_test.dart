// `#243`, DR-104 §11.103.6: the eight facts docs/06 §7.1's sidebar
// filters on.
//
// EVERY CASE RUNS AGAINST THE SEEDED CATALOG WHERE IT CAN. A chip is a
// promise about the 48 templates that ship, and a fixture this file
// invented would prove the predicate compiles rather than that it
// answers. Where a hand-built body is used it is because the seed has no
// example, and the case says so.
import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

import '../sheet/sheet_test_support.dart';

final Map<String, TemplateBody> _seed = buildSeedCatalog();

PlaceableTemplate _row(String id, TemplateBody body) => PlaceableTemplate(
  templateId: TemplateId(id),
  version: 1,
  contentHash: 'sha256:seed-$id',
  body: body,
  provenance: TemplateProvenance.seeded,
);

TemplateFacts _facts(String seedId, {RackDocument? doc}) =>
    buildTemplateFacts(_row(seedId, _seed[seedId]!), doc: doc);

RackDocument _doc() => RackDocument(
  id: const Uuid('doc-243'),
  appVersion: '0.4.0',
  createdAt: DateTime.utc(2026),
  modifiedAt: DateTime.utc(2026),
  meta: testMeta(),
);

void main() {
  group('RU height', () {
    test('a rack-mounted template reports its larger face', () {
      // V03, the 4U HDMI Matrix 16x16.
      expect(_facts('V03').ruHeight, _seed['V03']!.frontU);
      expect(_facts('V03').ruHeight, greaterThan(0));
    });

    test('a 0U occupant reports 0, which is a real answer', () {
      // P01, the 0U vertical PDU. The chip must offer 0U as a VALUE
      // rather than treating it as missing, which is what the palette's
      // own occupancy badge already does.
      expect(_facts('P01').ruHeight, 0);
    });
  });

  group('mount method', () {
    test('it is the body s own field, not a guess from the footprint', () {
      expect(_facts('V03').mountMethod, _seed['V03']!.mountMethod);
    });
  });

  group('has HDMI', () {
    test('an HDMI matrix has it', () {
      expect(_facts('V03').hasHdmi, isTrue);
    });

    test('a blank panel does not', () {
      // X01 has no ports at all, which is the case a predicate written
      // with `.first` or `.any` over an assumed non-empty list breaks on.
      expect(_facts('X01').hasHdmi, isFalse);
    });

    test('the connector spelling counts as well as the family', () {
      // Both readings are hits (see the file header): a port can carry
      // HDMI as its connector under a generic family, or as its family
      // under some other connector.
      final body = _seed['V03']!;
      expect(
        templateHasFamilyPrefix(body, 'video.hdmi') ||
            templateHasConnectorPrefix(body, 'conn.hdmi'),
        isTrue,
      );
    });

    test('a prefix spans the three HDMI versions', () {
      // `video.hdmi.1_4`, `.2_0` and `.2_1` are three ids and one
      // question, which is why the helper takes a prefix.
      expect(templateHasFamilyPrefix(_seed['V03']!, 'video.hdmi'), isTrue);
    });
  });

  group('has PoE, which is two questions', () {
    test('at least one seeded template answers yes', () {
      final withPoe = [
        for (final e in _seed.entries)
          if (buildTemplateFacts(_row(e.key, e.value)).hasPoe) e.key,
      ];
      expect(
        withPoe,
        isNotEmpty,
        reason: 'the seeded network switches model PoE somehow',
      );
    });

    test('a blank panel does not', () {
      expect(_facts('X01').hasPoe, isFalse);
    });

    test('role none is a measured negative and NOT a hit', () {
      // G4's distinction on a chip: a port that explicitly says it does
      // no PoE is not the same as a port that never said.
      final body = TemplateBody(
        manufacturer: 'Generic',
        model: '',
        displayName: 'Plain Switch',
        frontU: 1,
        ports: [
          PortDef(
            key: const PortKey('p1'),
            label: 'P1',
            order: const FracIndex('a0'),
            connector: const ConnectorTypeId('conn.rj45'),
            signalFamily: const SignalFamilyId('net.ethernet'),
            face: Face.rear,
            position: const PanelPosition(
              ruOffset: 0,
              xTwelfth: 0,
              xFineNm: Len.zero,
              yFineNm: Len.zero,
            ),
            poe: PoeSpec(role: PoeRole.none),
          ),
        ],
      );
      expect(buildTemplateFacts(_row('tpl.plain', body)).hasPoe, isFalse);
    });
  });

  group('passthrough and container', () {
    test('they read the body s own flags', () {
      for (final e in _seed.entries) {
        final f = buildTemplateFacts(_row(e.key, e.value));
        expect(f.isPassthrough, e.value.isPassthrough, reason: e.key);
        expect(f.isContainer, e.value.isContainer, reason: e.key);
      }
    });
  });

  group('used in this project', () {
    test('with no document it is zero, which is honest and not a claim', () {
      // A caller with no document has not established that nothing uses
      // the template; it has established that it cannot tell.
      expect(_facts('V03').usedInProject, 0);
      expect(_facts('V03').isUsedInProject, isFalse);
    });

    test('an unplaced template in a real document is still zero', () {
      final doc = _doc();
      doc.templates['V03@1'] = TemplateSnapshot(
        templateId: const TemplateId('V03'),
        version: 1,
        contentHash: 'sha256:seed-V03',
        capturedAt: DateTime.utc(2026),
        body: _seed['V03']!,
      );
      expect(_facts('V03', doc: doc).usedInProject, 0);
    });

    test('a placed one counts, and the predicate follows the count', () {
      final doc = _doc();
      doc.templates['V03@1'] = TemplateSnapshot(
        templateId: const TemplateId('V03'),
        version: 1,
        contentHash: 'sha256:seed-V03',
        capturedAt: DateTime.utc(2026),
        body: _seed['V03']!,
      );
      for (var i = 0; i < 3; i++) {
        doc.devices[Uuid('dev-$i')] = DeviceInstance(
          id: Uuid('dev-$i'),
          kind: DeviceKind.rackDevice,
          templateRef: const TemplateRef(
            templateId: TemplateId('V03'),
            version: 1,
            contentHash: 'sha256:seed-V03',
          ),
          designator: 'MTX-$i',
          name: 'Matrix',
          placement: const OffRackPlacement(),
          meta: testMeta(),
        );
      }
      final f = _facts('V03', doc: doc);
      // A COUNT, not a boolean, because a card can print "used 3 times"
      // where a chip only needs the predicate.
      expect(f.usedInProject, 3);
      expect(f.isUsedInProject, isTrue);
    });
  });

  group('drafts', () {
    test('no seeded template is a draft', () {
      for (final e in _seed.entries) {
        expect(
          buildTemplateFacts(_row(e.key, e.value)).isDraft,
          isFalse,
          reason: e.key,
        );
      }
    });

    test('it defers to isDraftTemplate rather than re-deciding', () {
      for (final e in _seed.entries) {
        expect(
          buildTemplateFacts(_row(e.key, e.value)).isDraft,
          isDraftTemplate(e.value),
          reason: e.key,
        );
      }
    });
  });
}
