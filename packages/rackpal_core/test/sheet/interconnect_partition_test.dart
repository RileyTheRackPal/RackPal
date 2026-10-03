// draw/sheet/interconnect_partition.dart — the exporter's domain partition
// (CR-073, DR-225 §11.224.2 and §11.224.3).
//
// Asserted against the drawing, because that is what the partition reads:
// every link a sheet claims is a link the full schematic labels in that
// domain, and every link the full schematic labels in a resolved domain is
// on exactly one sheet.

import 'dart:convert';
import 'dart:io';

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

import '../scene/schematic_test_document.dart';

RackDocument _starter(String name) =>
    (const JsonDocumentCodec().read(
              File(
                '../../apps/rackpal/assets/starters/$name.rppj',
              ).readAsBytesSync(),
            )
            as Ok<RackDocument>)
        .value;

Map<String, Object?> _json(RackDocument doc) =>
    (jsonDecode(utf8.decode(const JsonDocumentCodec().write(doc)))
            as Map<String, Object?>)['document']!
        as Map<String, Object?>;

void main() {
  group('interconnectPartitionsOf', () {
    test('one partition per domain the drawing uses, in the figure order '
        'VID, RF, AUD, DIG, NET, CTL, PWR, STR (§11.224.2)', () {
      final doc = buildSchematicTestDocument();
      final parts = interconnectPartitionsOf(
        buildSchematicScene(doc: doc, measurer: const FakeMeasurer()),
      ).partitions;

      // The fixture's three domains, ascending by id, come out in the
      // FIGURE's order instead: digital video, then digital audio, then
      // network. Ascending would put audio first, which is the filter
      // bar's order and the one the ruling did not take.
      expect(parts.map((p) => p.domain.v), <String>[
        'video.digital',
        'audio.digital',
        'net',
      ]);
    });

    test('every labelled link is on exactly one sheet, the one its own '
        'label resolved to', () {
      final doc = buildSchematicTestDocument();
      final full = buildSchematicScene(
        doc: doc,
        measurer: const FakeMeasurer(),
      );
      final parts = interconnectPartitionsOf(full).partitions;

      final sheetOf = <Uuid, SignalDomainId>{};
      for (final p in parts) {
        for (final id in p.linkIds) {
          expect(sheetOf.containsKey(id), isFalse, reason: '$id twice');
          sheetOf[id] = p.domain;
        }
      }
      for (final label in full.netLabels) {
        expect(sheetOf[label.linkId], label.style.domainId);
      }
      expect(sheetOf.keys.toSet(), {for (final l in full.netLabels) l.linkId});
    });

    test("a sheet's devices are exactly the devices its links land on "
        '(§11.224.3): never the rest of the project', () {
      final doc = buildSchematicTestDocument();
      final full = buildSchematicScene(
        doc: doc,
        measurer: const FakeMeasurer(),
      );
      for (final p in interconnectPartitionsOf(full).partitions) {
        final landed = {
          for (final l in full.netLabels)
            if (l.style.domainId == p.domain) Uuid(l.deviceId),
        };
        expect(p.deviceIds.toSet(), landed, reason: p.domain.v);
        expect(
          p.deviceIds.length,
          lessThan(full.symbols.length),
          reason: '${p.domain.v} drew every device on the schematic',
        );
      }
    });

    test('Whole House partitions into the two domains its wired home runs '
        'carry, and its twelve unattached runs are on none', () {
      final doc = _starter('whole_house');
      final full = buildSchematicScene(
        doc: doc,
        measurer: const FakeMeasurer(),
        expandedBanks: allBanksExpanded(doc),
      );
      final split = interconnectPartitionsOf(full);
      // RF, then Network, in the figure's order. NOT audio: all five of
      // Whole House's speaker runs are open at the rack, so none lands on
      // a drawn pin and Analog Audio prints no sheet.
      expect(split.partitions.map((p) => p.domain.v), <String>[
        'video.analog',
        'net',
      ]);

      final onSheets = {for (final p in split.partitions) ...p.linkIds};
      // A run with no device at either end has no pin to draw on, and it
      // is not lost: it is T6.20's (DR-220).
      for (final link in doc.links.values) {
        final onAPort =
            link.conductors.first.from is PortEndpoint ||
            link.conductors.first.to is PortEndpoint;
        expect(onSheets.contains(link.id), onAPort, reason: link.designator);
      }
      expect(split.unresolvedLinkIds, isEmpty);
    });
  });

  test("read off the CANVAS, with its banks collapsed, eleven of PP-1's "
      'twelve runs reach no sheet: the defect §11.224.7 rules around', () {
    // THE CONTROL for the test above. If bank collapse ever learns to
    // label every member, this fails, and the expansion in
    // `allBanksExpanded` can be reconsidered rather than kept by habit.
    final doc = _starter('whole_house');
    final canvas = buildSchematicScene(
      doc: doc,
      measurer: const FakeMeasurer(),
    );
    final onSheets = {
      for (final p in interconnectPartitionsOf(canvas).partitions) ...p.linkIds,
    };
    String? deviceAt(Endpoint end) => end is PortEndpoint
        ? doc.devices[doc.ports[end.portId]!.deviceId]!.designator
        : null;
    final pp1 = doc.links.values.where(
      (l) => deviceAt(l.conductors.first.to) == 'PP-1',
    );
    expect(pp1, hasLength(12));
    expect(pp1.where((l) => onSheets.contains(l.id)), hasLength(1));
  });

  test('banksWiredBy names the bank each cable lands in, and nothing else', () {
    final doc = _starter('whole_house');
    final all = interconnectPartitionsOf(
      buildSchematicScene(
        doc: doc,
        measurer: const FakeMeasurer(),
        expandedBanks: allBanksExpanded(doc),
      ),
    ).partitions;
    final net = all.firstWhere((p) => p.domain.v == 'net');
    final banks = banksWiredBy(doc, net.linkIds);
    final pp1 = doc.devices.values.firstWhere((d) => d.designator == 'PP-1');
    expect(banks[pp1.id], isNotEmpty);
    // A device none of these cables touch has no bank expanded for them.
    for (final id in banks.keys) {
      expect(net.deviceIds, contains(id));
    }
  });

  group('partitionDocument', () {
    test('differs from its source in devices and links ALONE, so a field '
        'added to RackDocument cannot be dropped from the view', () {
      final doc = _starter('whole_house');
      final full = buildSchematicScene(
        doc: doc,
        measurer: const FakeMeasurer(),
      );
      final part = interconnectPartitionsOf(full).partitions.first;
      final view = partitionDocument(doc, part);

      final a = _json(doc);
      final b = _json(view);
      expect(b.keys.toSet(), a.keys.toSet());
      for (final key in a.keys) {
        if (key == 'devices' || key == 'links') continue;
        expect(jsonEncode(b[key]), jsonEncode(a[key]), reason: key);
      }
      expect(view.devices.keys.toSet(), part.deviceIds.toSet());
      expect(view.links.keys.toSet(), part.linkIds.toSet());
    });
  });
}
