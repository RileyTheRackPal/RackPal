// `#226`, M4-K1: docs/06 §5's six-step rear-panel auto-layout.
//
// THE SEEDED CATALOG IS THE FIXTURE WHEREVER IT CAN BE. This algorithm's
// whole claim is "zero-authoring correct rear panel", and a body this
// file invented would prove the arithmetic rather than that the 48
// shipped archetypes lay out. Where a hand-built body appears it is
// because the seed has no example of the case, and the case says so.
//
// THE ONE ASSERTION THAT WOULD HAVE CAUGHT AC-032 BEING IGNORED is
// `nothing is drawn past the chassis`. 482.6 mm is the PANEL width
// including ears and 432 mm is the chassis; flowing across the former
// draws jacks out past the rails on the view that gets taped inside the
// rack door, and it would look entirely plausible.
import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

final Map<String, TemplateBody> _seed = buildSeedCatalog();
final Registries _registries = buildSeedRegistries();

RenderedPanel _panel(String seedId) => buildPanelGeometry(
  body: _seed[seedId]!,
  registries: _registries,
);

PortDef _port(
  String key,
  String connector, {
  String order = 'a0',
  String? bank,
  PanelPosition? position,
}) => PortDef(
  key: PortKey(key),
  label: key,
  connector: ConnectorTypeId(connector),
  signalFamily: const SignalFamilyId('net.ethernet'),
  face: Face.rear,
  order: FracIndex(order),
  bankKey: bank,
  position: position,
);

TemplateBody _body({
  int frontU = 1,
  Len? chassisWidth,
  List<PortDef> ports = const [],
  List<BankDef> banks = const [],
}) => TemplateBody(
  manufacturer: 'Generic',
  model: '',
  displayName: 'Fixture',
  frontU: frontU,
  side: OccupancySide.front,
  mountMethod: MountMethod.rackEars,
  chassisWidth: chassisWidth ?? const Len(432_000_000),
  ports: ports,
  banks: banks,
);

void main() {
  group('it runs on every shipped archetype', () {
    test('no seeded template throws, and none is silently empty', () {
      // "Auto-layout runs on every template rather than on the 14 of 45
      // an earlier reading of this pseudocode priced it at" (docs/06 §5,
      // DR-057 §11.56.4). This is that sentence as a test.
      var withSlots = 0;
      for (final entry in _seed.entries) {
        final panel = buildPanelGeometry(
          body: entry.value,
          registries: _registries,
        );
        expect(panel.width, kPanelWidth, reason: entry.key);
        if (panel.slots.isNotEmpty) withSlots++;
      }
      expect(
        withSlots,
        greaterThan(20),
        reason: 'most of the 48 archetypes declare ports and lay out',
      );
    });

    test('every port is accounted for: placed, no-cutout, or neither', () {
      // THE CONSERVATION LAW. A port that is neither drawn nor reported
      // has been silently dropped, which is the failure mode a layout
      // test that only checks coordinates cannot see.
      for (final entry in _seed.entries) {
        final body = entry.value;
        final panel = buildPanelGeometry(
          body: body,
          registries: _registries,
        );
        expect(
          panel.slots.length + panel.noCutout.length,
          body.ports.length,
          reason: '${entry.key} has ${body.ports.length} ports',
        );
      }
    });
  });

  group('AC-032: the flow wraps at the CHASSIS, not the panel', () {
    test('nothing is drawn past the chassis edge', () {
      // 482.6 is the panel INCLUDING EARS. Using it would put jacks past
      // the rails and would look perfectly reasonable on screen.
      const chassis = 432000000;
      final lead = (kPanelWidth.nm - chassis) ~/ 2;
      for (final entry in _seed.entries) {
        final panel = buildPanelGeometry(
          body: entry.value,
          registries: _registries,
        );
        for (final slot in panel.slots) {
          expect(
            slot.right.nm,
            lessThanOrEqualTo(lead + chassis),
            reason: '${entry.key}/${slot.portKey.v} runs past the chassis',
          );
          expect(slot.x.nm, greaterThanOrEqualTo(lead), reason: entry.key);
        }
      }
    });

    test('a narrower chassis wraps sooner', () {
      // The property stated as a comparison rather than as a coordinate,
      // so it survives any change to the gutter or the footprints.
      final ports = [
        for (var i = 0; i < 12; i++) _port('p$i', 'conn.rj45', order: 'a$i'),
      ];
      final wide = buildPanelGeometry(
        body: _body(frontU: 3, ports: ports),
        registries: _registries,
      );
      final narrow = buildPanelGeometry(
        body: _body(
          frontU: 3,
          chassisWidth: const Len(120_000_000),
          ports: [
            for (var i = 0; i < 12; i++)
              _port('p$i', 'conn.rj45', order: 'a$i'),
          ],
        ),
        registries: _registries,
      );
      int rows(RenderedPanel p) => p.slots.map((s) => s.y.nm).toSet().length;
      expect(rows(narrow), greaterThan(rows(wide)));
    });
  });

  group('step 2: pitch when stated, footprint when not (DR-057)', () {
    test('a connector with a pitch advances by it', () {
      // `conn.xlr3` carries a real pitch; the spacing between two of them
      // is that number and not the footprint plus this file's gutter.
      final def =
          _registries.connectorTypes[const ConnectorTypeId(
            'conn.xlr3',
          )];
      expect(def?.pitch, isNotNull, reason: 'the fixture needs a pitch');
      final panel = buildPanelGeometry(
        body: _body(
          frontU: 2,
          ports: [
            _port('a', 'conn.xlr3'),
            _port('b', 'conn.xlr3', order: 'a1'),
          ],
        ),
        registries: _registries,
      );
      expect(panel.slots, hasLength(2));
      expect(
        panel.slots[1].x.nm - panel.slots[0].x.nm,
        def!.pitch!.nm,
        reason: 'the advance IS the stated pitch',
      );
    });

    test('a connector with no pitch advances by footprint plus gutter', () {
      final ids = _registries.connectorTypes.values.where(
        (d) => d.pitch == null && d.footprintWidth != null,
      );
      expect(ids, isNotEmpty, reason: '29 of the 51 state no pitch');
      final def = ids.first;
      final panel = buildPanelGeometry(
        body: _body(
          frontU: 2,
          ports: [
            _port('a', def.id.v),
            _port('b', def.id.v, order: 'a1'),
          ],
        ),
        registries: _registries,
      );
      expect(
        panel.slots[1].x.nm - panel.slots[0].x.nm,
        def.footprintWidth!.nm + kPanelGutter.nm,
      );
    });
  });

  group('a connector with no cutout occupies no width', () {
    test('it is REPORTED, not silently dropped', () {
      // The four §5.1 kinds. A person looking at a 6-port device that
      // drew 4 jacks needs the difference between "two are missing" and
      // "two do not have a hole".
      final noFootprint = _registries.connectorTypes.values
          .where((d) => d.footprintWidth == null)
          .toList();
      expect(noFootprint, isNotEmpty, reason: '4 of the 51 have no cutout');
      final panel = buildPanelGeometry(
        body: _body(
          ports: [
            _port('drawn', 'conn.rj45'),
            _port('hidden', noFootprint.first.id.v, order: 'a1'),
          ],
        ),
        registries: _registries,
      );
      expect(panel.slots.map((s) => s.portKey.v), ['drawn']);
      expect(panel.noCutout.map((k) => k.v), ['hidden']);
    });

    test('an unknown connector id is treated as no-cutout, not a crash', () {
      // A hand-edited template can name a connector this build does not
      // ship. A layout that threw would take the whole preview down.
      final panel = buildPanelGeometry(
        body: _body(ports: [_port('x', 'conn.does_not_exist')]),
        registries: _registries,
      );
      expect(panel.slots, isEmpty);
      expect(panel.noCutout.map((k) => k.v), ['x']);
    });
  });

  group('step 1: banks in order, ports within a bank in order', () {
    test('a later bank lays out after an earlier one', () {
      final panel = buildPanelGeometry(
        body: _body(
          frontU: 3,
          banks: [
            BankDef(
              key: 'second',
              label: 'Second',
              abbr: 'SE',
              order: const FracIndex('b'),
            ),
            BankDef(
              key: 'first',
              label: 'First',
              abbr: 'FI',
              order: const FracIndex('a'),
            ),
          ],
          ports: [
            _port('z', 'conn.rj45', bank: 'second'),
            _port('a', 'conn.rj45', bank: 'first', order: 'a1'),
          ],
        ),
        registries: _registries,
      );
      // `a` is in the FIRST bank though its own order is later, so bank
      // order wins, which is step 1's whole content.
      expect(panel.slots.map((s) => s.portKey.v), ['a', 'z']);
    });

    test('a port whose bank the body does not declare sorts LAST', () {
      // The grid permits a free-string `bankKey`, and a layout that
      // dropped such a port would lose it with nothing said.
      final panel = buildPanelGeometry(
        body: _body(
          frontU: 3,
          banks: [
            BankDef(
              key: 'known',
              label: 'Known',
              abbr: 'KN',
              order: const FracIndex('a'),
            ),
          ],
          ports: [
            _port('orphan', 'conn.rj45', bank: 'nowhere'),
            _port('placed', 'conn.rj45', bank: 'known', order: 'a1'),
          ],
        ),
        registries: _registries,
      );
      expect(panel.slots.map((s) => s.portKey.v), ['placed', 'orphan']);
    });
  });

  group('the layout is DERIVED and deterministic (DR-105 §11.104.2)', () {
    test('two calls on one body return the same layout', () {
      final body = _seed['V03']!;
      final a = buildPanelGeometry(body: body, registries: _registries);
      final b = buildPanelGeometry(body: body, registries: _registries);
      expect(
        a.slots.map((s) => '${s.portKey.v}@${s.x.nm},${s.y.nm}'),
        b.slots.map((s) => '${s.portKey.v}@${s.x.nm},${s.y.nm}'),
      );
    });

    test('it writes NOTHING back to the body', () {
      // The whole of "derived": a template with no layout data still has
      // none after being laid out, which is docs/06 §5's non-negotiable.
      final body = _body(ports: [_port('a', 'conn.rj45')]);
      buildPanelGeometry(body: body, registries: _registries);
      expect(body.ports.single.position, isNull);
    });
  });

  group('a nudge overrides the flow, and says it did', () {
    test('an authored position wins and is flagged', () {
      final panel = buildPanelGeometry(
        body: _body(
          ports: [
            _port('auto', 'conn.rj45'),
            _port(
              'moved',
              'conn.rj45',
              order: 'a1',
              position: const PanelPosition(
                ruOffset: 0,
                xTwelfth: 3,
                xFineNm: Len(1_000_000),
                yFineNm: Len(2_000_000),
              ),
            ),
          ],
        ),
        registries: _registries,
      );
      final moved = panel.slots.firstWhere((s) => s.portKey.v == 'moved');
      final auto = panel.slots.firstWhere((s) => s.portKey.v == 'auto');
      expect(moved.nudged, isTrue);
      expect(auto.nudged, isFalse);
      expect(moved.y.nm, 2_000_000);

      // ═══════════════════════════════════════════════════════════════
      // THE X ASSERTION THAT WAS MISSING, AND WHAT IT COST
      // ═══════════════════════════════════════════════════════════════
      // This test pinned `y` and not `x`, so the meaning of `xTwelfth`
      // was unobservable: `#226` implemented it as a twelfth of a RACK
      // UNIT (3.70 mm) under a comment claiming the corpus said so. The
      // corpus declares the field and never says what the twelfth
      // measures, and all three of its worked examples carry
      // `xTwelfth: 0`.
      //
      // DR-106 §11.105.7 rules it a twelfth of the PANEL width, because
      // `ruOffset` + `yFineNm` is coarse plus fine vertically and the x
      // pair must mirror it. 482.6 / 12 = 40.216 mm.
      expect(
        moved.x.nm,
        3 * (kPanelWidth.nm ~/ 12) + 1_000_000,
        reason: 'a twelfth is 40.22mm of panel, not 3.70mm of rack unit',
      );
    });

    test('nudging one port does NOT move the others', () {
      // CR-071 frames the interaction as NUDGING rather than placing, so
      // the auto field must not re-flow under a hand that touched one
      // jack. A re-flowing layout would move every neighbour and read as
      // the drawing fighting back.
      List<int> xs(PanelPosition? nudge) => buildPanelGeometry(
        body: _body(
          frontU: 2,
          ports: [
            _port('a', 'conn.rj45'),
            _port('b', 'conn.rj45', order: 'a1'),
            _port('c', 'conn.rj45', order: 'a2', position: nudge),
          ],
        ),
        registries: _registries,
      ).slots.where((s) => s.portKey.v != 'c').map((s) => s.x.nm).toList();

      expect(
        xs(
          const PanelPosition(
            ruOffset: 1,
            xTwelfth: 0,
            xFineNm: Len.zero,
            yFineNm: Len.zero,
          ),
        ),
        xs(null),
      );
    });
  });

  group('the panel height and the fill readout', () {
    test('height is heightU RU less the inter-panel gap', () {
      expect(
        _panel('V03').height.nm,
        _seed['V03']!.frontU * kRackUnit.nm - kPanelHeightGap.nm,
      );
    });

    test('a field device has no panel and a zero fill', () {
      // `frontU: 0` is not a 0% full panel, it is no panel. The readout
      // must not divide by it.
      final panel = buildPanelGeometry(
        body: TemplateBody(
          manufacturer: 'Generic',
          model: '',
          displayName: 'Field',
          ports: [_port('a', 'conn.rj45')],
        ),
        registries: _registries,
      );
      expect(panel.height, Len.zero);
      expect(panel.fillPermille, 0);
    });

    test('fill rises with the number of cutouts', () {
      // A ratio asserted as a comparison, not a number: pinning a
      // percentage would pin the footprint table, which AC-050 owns.
      int fill(int n) => buildPanelGeometry(
        body: _body(
          frontU: 2,
          ports: [
            for (var i = 0; i < n; i++) _port('p$i', 'conn.rj45', order: 'a$i'),
          ],
        ),
        registries: _registries,
      ).fillPermille;
      expect(fill(8), greaterThan(fill(2)));
      expect(fill(0), 0);
    });

    test('a panel too short to hold its rows OVERFLOWS and says so', () {
      // Not a refusal. A device authored too short genuinely does not
      // fit, and that is a fact about the template worth showing.
      //
      // A `conn.iec_c14` FIXTURE, and the first draft used 48 RJ45s on
      // the assumption that "48 ports in 1U" must overflow. IT DOES NOT:
      // an RJ45 cutout is 10 mm tall, so 48 of them are two rows and 20
      // mm inside a 43.66 mm panel. The test was asserting a belief about
      // patch panels rather than a property of the layout.
      final panel = buildPanelGeometry(
        body: _body(
          ports: [
            for (var i = 0; i < 40; i++)
              _port(
                'p$i',
                'conn.iec_c14',
                order: 'a${i.toString().padLeft(3, '0')}',
              ),
          ],
        ),
        registries: _registries,
      );
      expect(panel.overflowed, isNotEmpty);
      expect(
        panel.slots,
        hasLength(40),
        reason: 'they are placed anyway, so the preview shows the overflow',
      );
    });

    test('EXACTLY TWO seeded archetypes overflow, and they are named', () {
      // MEASURED, NOT ASSUMED. The first draft of this case asserted that
      // NO shipped archetype overflows, which was a belief rather than a
      // reading: AC-050's gate is that every connector HAS a footprint,
      // not that every device fits its own panel.
      //
      // Two do. A03 is a 34-port 1U DSP whose second row of 24 mm
      // connectors lands 4 mm past a 43.66 mm panel, and N01 is the same
      // shape. Real hardware of that density packs tighter than this
      // file's uniform gutter, which is the honest reading: the layout is
      // a DRAWING and `kPanelGutter` is its choice, not a claim about the
      // metalwork.
      //
      // Pinned by NAME so a change to the footprint table, the gutter or
      // the wrap rule shows up here as a diff rather than as a silently
      // different picture.
      final overflowing = <String>[
        for (final entry in _seed.entries)
          if (buildPanelGeometry(
            body: entry.value,
            registries: _registries,
          ).overflowed.isNotEmpty)
            entry.key,
      ]..sort();
      expect(overflowing, ['A03', 'N01']);
    });

    test('an overflowing template still places every port', () {
      // The property that matters more than the count: overflow REPORTS,
      // it never drops. A person looking at A03 sees all 34 cutouts and
      // the one hanging past the edge, rather than 33 and no explanation.
      final panel = buildPanelGeometry(
        body: _seed['A03']!,
        registries: _registries,
      );
      expect(panel.slots, hasLength(_seed['A03']!.ports.length));
      expect(panel.overflowed, hasLength(1));
    });
  });
}
