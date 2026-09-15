// DR-173 (#112): a matrix's de-embedded zone audio is a stereo pair per
// zone, an L and an R balanced 3-pin block in one atomic set, so one drag
// lands both as a single cable and a second drag elsewhere splits them
// (DR-014). V02 de-embeds to S/PDIF, which is stereo on one connector, and
// stays one port per output.
import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

void main() {
  final catalog = buildSeedCatalog();

  for (final (id, zones) in [('V01', 8), ('V03', 16)]) {
    group('$id zone audio is $zones stereo pairs (DR-173)', () {
      final body = catalog[id]!;
      final zonePorts = body.ports.where((p) => p.bankKey == 'audOut').toList();

      test('every zone is an L and an R balanced 3-pin block', () {
        expect(zonePorts, hasLength(zones * 2));
        for (var i = 1; i <= zones; i++) {
          for (final role in ['L', 'R']) {
            final key = 'aud.out.$i.${role.toLowerCase()}';
            final port = zonePorts.singleWhere((p) => p.key.v == key);
            expect(port.connector.v, 'conn.euroblock_3', reason: key);
            expect(port.signalFamily.v, 'audio.line_bal', reason: key);
            expect(port.direction, PortDirection.source, reason: key);
            expect(port.balanced, isTrue, reason: key);
            expect(port.setKey, 'zone$i', reason: key);
            expect(port.setRole, role, reason: key);
            // UNPADDED ON PURPOSE (DR-173 §11.172.4): the label grammar
            // refuses a padded grouped counter.
            expect(port.label, 'AUD OUT $i $role', reason: key);
          }
        }
      });

      test('each pair is an atomic stereo set, so one drag is one cable', () {
        final sets = {for (final s in body.portSets) s.key: s};
        for (var i = 1; i <= zones; i++) {
          final set = sets['zone$i'];
          expect(set, isNotNull, reason: 'zone$i');
          expect(set!.kind, SetKind.stereoPair, reason: 'zone$i');
          expect(set.atomicConnect, isTrue, reason: 'zone$i');
        }
      });
    });
  }

  test('V02 de-embeds to S/PDIF, stereo on one connector, and stays one '
      'port per output', () {
    final spdif = catalog['V02']!.ports
        .where((p) => p.bankKey == 'deembed')
        .toList();
    expect(spdif, hasLength(4));
    expect(spdif.every((p) => p.setKey == null), isTrue);
    expect(
      spdif.every((p) => p.signalFamily.v == 'audio.spdif_coax'),
      isTrue,
    );
  });
}
