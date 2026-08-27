// #93 / DR-012.2 — multi-draw: N ports in one bank onto a target bank,
// N `Link`s, one undo entry.
//
// ═══════════════════════════════════════════════════════════════════════
// THE FIRST GROUP IS THE ONE M2-F TAUGHT US TO WRITE
// ═══════════════════════════════════════════════════════════════════════
// DR-012 found the same trap three times: a `PortDef` field that looks
// purpose-built for a gesture — `acceptedFamilies`, `channelIndex`,
// `maxConnections` — declared, round-tripping, and populated on NONE of
// the 727 seed ports, so every rule reading it did nothing on every real
// document. `atomicConnect` had a milder version: 34 of 257 ports carry a
// `setKey`, so the set gesture is reachable but rare.
//
// `bankKey` is the opposite and group 1 measures it rather than assuming
// it. If it ever stops being true, multi-draw becomes unreachable from the
// shipped catalog and these tests say so instead of passing on fixtures
// invented here.
//
// ═══════════════════════════════════════════════════════════════════════
// AND THE COUNT THAT MATTERS IS `Link`s, NOT `Conductor`s
// ═══════════════════════════════════════════════════════════════════════
// DR-012.2 keeps multi-draw at N `Link`s where `atomicConnect` is one
// `Link` with N `Conductor`s. Eight cables an installer pulls separately
// is a different bill of materials from one cable with eight conductors,
// and the two specs sit one line apart in docs/05. Every assertion below
// that counts links is counting that.

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

final _when = DateTime.utc(2026, 8, 2);
EntityMeta _meta() =>
    EntityMeta(createdAt: _when, updatedAt: _when, updatedBy: 'test');

const _pos = PanelPosition(
  ruOffset: 0,
  xTwelfth: 0,
  xFineNm: Len.zero,
  yFineNm: Len.zero,
);

const _mtx = Uuid('dev-mtx');
const _amp = Uuid('dev-amp');

PortDef _port(
  String key, {
  required String bank,
  required String order,
  int maxConnections = 1,
  String family = 'audio.analog.balanced',
}) => PortDef(
  key: PortKey(key),
  label: key,
  connector: const ConnectorTypeId('conn.xlr3'),
  signalFamily: SignalFamilyId(family),
  face: Face.rear,
  position: _pos,
  order: FracIndex(order),
  bankKey: bank,
  maxConnections: maxConnections,
);

/// Two banks of [n] ports each, `out` and `in`.
///
/// THE `order` VALUES ARE DELIBERATELY NOT THE KEY ORDER. `out.1` carries
/// `a9`, `out.2` carries `a8` and so on, so a rank that sorted on the key
/// would pair them backwards and every ordering assertion below would fail
/// — which is the whole point of DR-012.2 naming `PortDef.order` FIRST.
TemplateBody _body(String model, int n, {int maxConnections = 1}) =>
    TemplateBody(
      manufacturer: 'Demo',
      model: model,
      displayName: model,
      banks: [
        BankDef(
          key: 'out',
          label: 'Outputs',
          abbr: 'OUT',
          order: const FracIndex('a0'),
        ),
        BankDef(
          key: 'in',
          label: 'Inputs',
          abbr: 'IN',
          order: const FracIndex('a1'),
        ),
      ],
      ports: [
        for (var i = 1; i <= n; i++)
          _port(
            'out.$i',
            bank: 'out',
            order: 'a${10 - i}',
            maxConnections: maxConnections,
          ),
        for (var i = 1; i <= n; i++)
          _port(
            'in.$i',
            bank: 'in',
            order: 'b${10 - i}',
            maxConnections: maxConnections,
          ),
      ],
    );

void _addDevice(
  RackDocument doc,
  Uuid id,
  String designator,
  TemplateBody body,
) {
  final tpl = 'tpl.${id.v}';
  doc.templates['$tpl@1'] = TemplateSnapshot(
    templateId: TemplateId(tpl),
    version: 1,
    contentHash: 'sha256:$tpl',
    capturedAt: _when,
    body: body,
  );
  doc.devices[id] = DeviceInstance(
    id: id,
    kind: DeviceKind.rackDevice,
    templateRef: TemplateRef(
      templateId: TemplateId(tpl),
      version: 1,
      contentHash: 'sha256:$tpl',
    ),
    designator: designator,
    name: designator,
    placement: const OffRackPlacement(),
    meta: _meta(),
  );
}

RackDocument _doc({int sources = 4, int sinks = 4, int maxConnections = 1}) {
  final doc = RackDocument(
    id: const Uuid('doc-md'),
    appVersion: '0.1.0',
    createdAt: _when,
    modifiedAt: _when,
    meta: _meta(),
  );
  _addDevice(doc, _mtx, 'MTX-1', _body('MTX', sources));
  _addDevice(
    doc,
    _amp,
    'AMP-1',
    _body('AMP', sinks, maxConnections: maxConnections),
  );
  return doc;
}

/// Plans MTX-1's whole `out` bank onto AMP-1's `in` bank.
MultiDrawPlan _plan(RackDocument doc, {Iterable<String>? only}) =>
    planMultiDraw(
      doc,
      fromDeviceId: _mtx,
      fromBankKey: 'out',
      sources:
          only ??
          portsInBank(
            doc,
            deviceId: _mtx,
            bankKey: 'out',
          ).map((t) => t.def.key.v),
      toDeviceId: _amp,
      toBankKey: 'in',
    );

List<Command<RackDocument>> _commands(RackDocument doc, MultiDrawPlan plan) =>
    buildMultiDrawCommands(
      doc: doc,
      plan: plan,
      media: kUnstatedMedia,
      now: _when,
      actor: 'test',
    );

void main() {
  group('1 — the gesture is REACHABLE from the shipped catalog', () {
    final catalog = buildSeedCatalog();

    test('every seed port carries a bankKey — the opposite of DR-012s three '
        'empty fields', () {
      var total = 0;
      var banked = 0;
      for (final body in catalog.values) {
        for (final p in body.ports) {
          total++;
          if (p.bankKey != null) banked++;
        }
      }
      expect(total, greaterThan(700));
      expect(
        banked,
        total,
        reason:
            'a gesture keyed on a field no shipped template populates is '
            'a gesture no user can reach — the trap DR-012 found three times',
      );
    });

    test('the catalog holds banks worth dragging, and A01 is docs/05s own '
        'demo moment', () {
      final big = <String, int>{};
      for (final entry in catalog.entries) {
        final counts = <String, int>{};
        for (final p in entry.value.ports) {
          final b = p.bankKey;
          if (b != null) counts[b] = (counts[b] ?? 0) + 1;
        }
        for (final c in counts.entries) {
          if (c.value >= 4) big['${entry.key}/${c.key}'] = c.value;
        }
      }
      expect(
        big.length,
        greaterThanOrEqualTo(50),
        reason:
            'multi-draw is only worth building if real templates have '
            'banks big enough for it',
      );
      // "wire the 8x8 matrix to eight zone amps" — the amplifier that
      // makes that sentence concrete.
      expect(big['A01/srcIn'], greaterThanOrEqualTo(8));
      expect(big['A01/zoneOut'], greaterThanOrEqualTo(8));
    });
  });

  group('2 — rank is PortDef.order then key (DR-012.2)', () {
    test('pairs come out in ORDER order, which is not key order here', () {
      final plan = _plan(_doc());
      expect(plan.pairs, hasLength(4));
      expect(
        plan.pairs.map((p) => p.from.def.key.v),
        // `order` runs a9, a8, a7, a6 for out.1..out.4, so rank REVERSES
        // the key order — a sort on the key alone would give out.1 first.
        ['out.4', 'out.3', 'out.2', 'out.1'],
      );
      expect(
        plan.pairs.map((p) => p.to.def.key.v),
        ['in.4', 'in.3', 'in.2', 'in.1'],
      );
    });

    test('portsInBank returns only that bank, in the same order', () {
      final doc = _doc();
      expect(
        portsInBank(doc, deviceId: _mtx, bankKey: 'out').map(
          (t) => t.def.key.v,
        ),
        ['out.4', 'out.3', 'out.2', 'out.1'],
      );
      expect(
        portsInBank(doc, deviceId: _mtx, bankKey: 'in').map((t) => t.def.key.v),
        ['in.4', 'in.3', 'in.2', 'in.1'],
      );
      expect(portsInBank(doc, deviceId: _mtx, bankKey: 'nope'), isEmpty);
    });

    test('a selection smaller than the bank pairs only what was selected', () {
      final doc = _doc();
      final plan = _plan(doc, only: ['out.1', 'out.3']);
      expect(plan.pairs, hasLength(2));
      expect(plan.pairs.map((p) => p.from.def.key.v), ['out.3', 'out.1']);
      // Rank order still, and the sinks are the FIRST two by rank rather
      // than the ones whose names happen to match.
      expect(plan.pairs.map((p) => p.to.def.key.v), ['in.4', 'in.3']);
    });

    test('a source outside the named bank is dropped, not paired', () {
      // "N ports selected in ONE bank" is the gesture's precondition; a
      // caller that got it wrong should produce a smaller plan, not a
      // wrong one.
      final doc = _doc();
      final plan = _plan(doc, only: ['out.1', 'in.1']);
      expect(plan.pairs, hasLength(1));
      expect(plan.pairs.single.from.def.key.v, 'out.1');
    });
  });

  group('3 — N Links, one undo entry', () {
    test('it makes N cables, each with ONE conductor — not one cable with '
        'N', () {
      final doc = _doc();
      final commands = _commands(doc, _plan(doc));
      expect(commands, hasLength(4));
      for (final c in commands) {
        c.apply(doc);
      }

      expect(
        doc.links,
        hasLength(4),
        reason:
            'DR-012.2: multi-draw is N Links. One Link with N '
            'Conductors is atomicConnect, and the pull sheet counts rows',
      );
      for (final link in doc.links.values) {
        expect(link.conductors, hasLength(1));
      }
    });

    test('EVERY LINK GETS ITS OWN DESIGNATOR AND NET NAME — the defect a '
        'naive builder ships', () {
      // All four commands are built against an UNMUTATED document, so
      // every allocator sees the same `doc.links` and the same `doc.nets`.
      // Without `ConnectAllocations` all four would be `W001`/`N001`, and
      // link designators are PROJECT-WIDE unique: four schedule rows an
      // installer cannot tell apart.
      final doc = _doc();
      final commands = _commands(doc, _plan(doc));
      for (final c in commands) {
        c.apply(doc);
      }

      final designators = doc.links.values.map((l) => l.designator).toSet();
      expect(designators, hasLength(4));
      final nets = doc.nets.values.map((n) => n.name).toSet();
      expect(nets, hasLength(4));
      final orders = doc.links.values.map((l) => l.order.v).toSet();
      expect(orders, hasLength(4), reason: 'and four distinct sort indices');
    });

    test('AND EVERY PORT ON ONE DEVICE GETS ITS OWN J-NUMBER', () {
      // The per-device half of the same defect (CR-042: a port designator
      // is unique within its device). Four pairs land four ports on MTX-1
      // and four on AMP-1.
      final doc = _doc();
      for (final c in _commands(doc, _plan(doc))) {
        c.apply(doc);
      }

      for (final device in [_mtx, _amp]) {
        final onDevice = doc.ports.values.where((p) => p.deviceId == device);
        expect(onDevice, hasLength(4));
        expect(
          onDevice.map((p) => p.designator).toSet(),
          hasLength(4),
          reason:
              'two jacks on one box sharing a J-number is a wrong '
              'identifier on a termination schedule (G4)',
        );
      }
    });

    test('undo removes every cable AND every port it created', () {
      final doc = _doc();
      final before = const JsonDocumentCodec().write(doc);
      final commands = _commands(doc, _plan(doc));
      for (final c in commands) {
        c.apply(doc);
      }
      expect(doc.links, hasLength(4));
      expect(doc.ports, hasLength(8));

      // Reverse order, which is what `Transaction.revert` does.
      for (final c in commands.reversed) {
        c.revert(doc);
      }
      expect(doc.links, isEmpty);
      expect(doc.ports, isEmpty);
      expect(doc.nets, isEmpty);
      expect(
        const JsonDocumentCodec().write(doc),
        before,
        reason:
            'delete-then-undo must be a lossless round trip, and '
            'CR-117 is the gate that can see it',
      );
    });
  });

  group('4 — connect what fits, and mint nothing for the rest', () {
    test('four sources onto two free sinks makes TWO cables and reports '
        'two', () {
      final doc = _doc(sinks: 2);
      final plan = _plan(doc);
      expect(plan.pairs, hasLength(2));
      expect(plan.unpaired, hasLength(2));
      expect(plan.linkCount, 2);

      for (final c in _commands(doc, plan)) {
        c.apply(doc);
      }
      expect(
        doc.links,
        hasLength(2),
        reason:
            'a surplus source mints NOTHING — a Link with an open end '
            'is a whole cable pulled to nowhere, which is the shape DR-013 '
            'calls debris',
      );
    });

    test(
      'the reason names the device and the bank, never just "no target"',
      () {
        final plan = _plan(_doc(sinks: 1));
        expect(plan.unpaired, hasLength(3));
        for (final u in plan.unpaired) {
          expect(u.reason, contains('MTX-1'));
          expect(
            u.reason,
            anyOf(contains('Inputs'), contains('TOP-')),
            reason:
                'either the bank the user was aiming at, or the rule that '
                'refused — a bare "no target" sends them hunting',
          );
        }
      },
    );

    test('a bank whose jacks are all FULL reports the rule, not "no jack"', () {
      // The distinction the reason exists for: a user told "no free jack"
      // about a bank that is not full would go looking for space they
      // already have.
      final doc = _doc();
      // Fill every AMP-1 input from somewhere else first.
      for (var i = 1; i <= 4; i++) {
        final built = buildConnectPortsCommand(
          doc: doc,
          from: resolveConnectTarget(doc, deviceId: _mtx, portKey: 'in.$i')!,
          to: resolveConnectTarget(doc, deviceId: _amp, portKey: 'in.$i')!,
          media: kUnstatedMedia,
          now: _when,
          actor: 'test',
        );
        (built as ConnectPortsReady).command.apply(doc);
      }

      final plan = _plan(doc);
      expect(plan.pairs, isEmpty);
      expect(plan.unpaired, hasLength(4));
      expect(plan.unpaired.first.reason, contains('TOP-003'));
    });

    test('nothing to pair builds no command at all', () {
      final doc = _doc();
      final empty = planMultiDraw(
        doc,
        fromDeviceId: _mtx,
        fromBankKey: 'out',
        sources: const [],
        toDeviceId: _amp,
        toBankKey: 'in',
      );
      expect(empty.isEmpty, isTrue);
      expect(_commands(doc, empty), isEmpty);
    });
  });

  group('5 — one cable per jack', () {
    test('a sink that could take two is still used once', () {
      // `effectiveMaxConnections` would allow a second cable on the same
      // jack. A BULK gesture that quietly stacked them is not what "wire
      // the matrix to the amps" means; the pin-to-pin gesture is still
      // there for the deliberate case.
      final doc = _doc(sinks: 2, maxConnections: 4);
      final plan = _plan(doc);
      expect(plan.pairs, hasLength(2));
      expect(
        plan.pairs.map((p) => p.to.def.key.v).toSet(),
        hasLength(2),
        reason:
            'two cables onto one jack in one drag is a surprise, not a '
            'feature',
      );
      expect(plan.unpaired, hasLength(2));
    });
  });
}
