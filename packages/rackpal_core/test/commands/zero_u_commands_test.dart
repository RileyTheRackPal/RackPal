// ignore_for_file: cascade_invocations, an apply/revert pair with
// assertions BETWEEN the two calls is the shape most of these tests take;
// collapsing the pair into a cascade would delete the intermediate
// assertion.
//
// 0U channels and their occupants (`#270`, M5-C, CR-031, AC-044).
//
// ═══════════════════════════════════════════════════════════════════════
// THE CHAIN, AND WHY EVERY LINK OF IT WAS MISSING
// ═══════════════════════════════════════════════════════════════════════
// `PLC-003` refuses a `ZeroUPlacement` whose channel does not resolve or
// whose offset falls outside it. Nothing could produce either state:
// `Rack.zeroUChannels` had no writer, no preset seeded one, and nothing
// outside the codec built a `ZeroUPlacement`. So the rule needed a
// channel to exist before an occupant could name one, and the tests that
// matter are the ones where a command is rejected.
import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

const _codec = JsonDocumentCodec();
final _now = DateTime.utc(2026, 9, 2, 18);
const _rackId = Uuid('rk-1');
const _pdu = Uuid('dev-pdu');

EntityMeta _meta() =>
    EntityMeta(createdAt: _now, updatedAt: _now, updatedBy: 'test');

/// A 12U rack, with `P01`'s shape as the seed catalog declares it:
/// `frontU: 0, rearU: 0, side: zeroUVertical`.
RackDocument _doc({bool withChannel = true}) {
  final doc = RackDocument(
    id: const Uuid('doc-zero-u'),
    appVersion: '0.5.21',
    createdAt: _now,
    modifiedAt: _now,
    meta: _meta(),
  );
  doc.racks[_rackId] = Rack(
    id: _rackId,
    name: 'Test Rack',
    designator: 'RK-1',
    heightU: 12,
    order: const FracIndex('a0'),
    zeroUChannels: withChannel
        ? [
            ZeroUChannel(
              id: 'ch-left',
              side: ZeroUChannelSide.rearLeft,
              startU: 1,
              endU: 12,
            ),
          ]
        : null,
    meta: _meta(),
  );
  doc.templates[catalogTemplateKey('P01')] = TemplateSnapshot(
    templateId: const TemplateId('P01'),
    version: 1,
    contentHash: 'sha256:p01',
    body: TemplateBody(
      manufacturer: 'Test',
      model: 'pdu-0u',
      displayName: '0U PDU',
      typePrefix: 'PDU',
      side: OccupancySide.zeroUVertical,
      mountMethod: MountMethod.zeroU,
    ),
    capturedAt: _now,
  );
  return doc;
}

void _mountPdu(RackDocument doc, {Len offset = Len.zero, Len? span}) {
  doc.devices[_pdu] = DeviceInstance(
    id: _pdu,
    kind: DeviceKind.rackDevice,
    templateRef: const TemplateRef(
      templateId: TemplateId('P01'),
      version: 1,
      contentHash: 'sha256:p01',
    ),
    designator: 'PDU-1',
    name: '0U PDU',
    placement: ZeroUPlacement(
      rackId: _rackId,
      channelId: 'ch-left',
      offsetFromChannelStart: offset,
      spanAlongChannel: span,
      orientation: ZeroUOrientation.vertical,
    ),
    meta: _meta(),
  );
}

void main() {
  group('channels, which had to exist first', () {
    test('one is added, and it lands where the codec can see it', () {
      final doc = _doc(withChannel: false);
      final planned = planAddZeroUChannel(
        doc: doc,
        rackId: _rackId,
        id: 'ch-right',
        side: ZeroUChannelSide.rearRight,
        startU: 2,
        endU: 10,
        name: 'Rear right',
      );
      expect(planned, isA<ZeroUReady>());
      (planned as ZeroUReady).command.apply(doc);
      final channel = doc.racks[_rackId]!.zeroUChannels.single;
      expect(channel.id, 'ch-right');
      expect(channel.startU, 2);
      expect(channel.endU, 10);
    });

    test('a channel that runs off the top of the rack is refused, and it '
        'carries NO rule id because no catalogue rule covers it', () {
      final planned = planAddZeroUChannel(
        doc: _doc(withChannel: false),
        rackId: _rackId,
        id: 'ch-tall',
        side: ZeroUChannelSide.frontLeft,
        startU: 1,
        endU: 40,
      );
      expect(planned, isA<ZeroURefused>());
      final refused = planned as ZeroURefused;
      expect(refused.ruleId, isNull);
      expect(refused.reason, contains('RK-1'));
      expect(refused.reason, endsWith('.'));
    });

    test('an inverted channel is refused, because it runs bottom to top', () {
      expect(
        planAddZeroUChannel(
          doc: _doc(withChannel: false),
          rackId: _rackId,
          id: 'ch-upside-down',
          side: ZeroUChannelSide.frontLeft,
          startU: 9,
          endU: 3,
        ),
        isA<ZeroURefused>(),
      );
    });

    test('a duplicate id is refused, so an occupant naming one can never '
        'mean two things', () {
      expect(
        planAddZeroUChannel(
          doc: _doc(),
          rackId: _rackId,
          id: 'ch-left',
          side: ZeroUChannelSide.frontLeft,
          startU: 1,
          endU: 4,
        ),
        isA<ZeroURefused>(),
      );
    });

    test('apply, revert, apply lands on identical bytes (CR-117)', () {
      final doc = _doc(withChannel: false);
      final before = _codec.write(doc);
      final cmd =
          (planAddZeroUChannel(
                    doc: doc,
                    rackId: _rackId,
                    id: 'ch-right',
                    side: ZeroUChannelSide.rearRight,
                    startU: 2,
                    endU: 10,
                  )
                  as ZeroUReady)
              .command;
      cmd.apply(doc);
      final applied = _codec.write(doc);
      cmd.revert(doc);
      expect(_codec.write(doc), before);
      cmd.apply(doc);
      expect(_codec.write(doc), applied);
    });
  });

  group('removing a channel', () {
    test('is REFUSED while something is mounted in it, rather than '
        'leaving a device pointing at nothing', () {
      final doc = _doc();
      _mountPdu(doc);
      final planned = planRemoveZeroUChannel(
        doc: doc,
        rackId: _rackId,
        id: 'ch-left',
      );
      expect(planned, isA<ZeroURefused>());
      expect((planned as ZeroURefused).reason, contains('PDU-1'));
    });

    test('and succeeds once it is empty, putting the channel back at its '
        'own index on revert so the bytes match', () {
      final doc = _doc();
      final extra = planAddZeroUChannel(
        doc: doc,
        rackId: _rackId,
        id: 'ch-right',
        side: ZeroUChannelSide.rearRight,
        startU: 1,
        endU: 12,
      );
      (extra as ZeroUReady).command.apply(doc);
      final before = _codec.write(doc);

      // The FIRST of two, so a revert that appended would reorder the
      // list and change the bytes without changing the meaning.
      final cmd =
          (planRemoveZeroUChannel(doc: doc, rackId: _rackId, id: 'ch-left')
                  as ZeroUReady)
              .command;
      cmd.apply(doc);
      expect(doc.racks[_rackId]!.zeroUChannels.single.id, 'ch-right');
      cmd.revert(doc);
      expect(_codec.write(doc), before);
    });
  });

  group('PLC-003 can finally fire, on the way in and on the way along', () {
    test('KNOWN-BAD: creating an occupant past the end of the channel is '
        'refused, citing the rule', () {
      final doc = _doc();
      final result = buildPlaceFromCatalogCommand(
        doc: doc,
        catalogId: 'P01',
        targetRack: doc.racks[_rackId]!,
        now: _now,
        actor: 'test',
        zeroU: (
          channelId: 'ch-left',
          offsetFromChannelStart: kRackUnit * 13,
          orientation: ZeroUOrientation.vertical,
        ),
      );
      expect(result, isA<CatalogPlacementFailed>());
      expect((result as CatalogPlacementFailed).ruleId, 'PLC-003');
    });

    test('NEAR-MISS: the far end of the channel is inside it, and the '
        'command builds', () {
      final doc = _doc();
      final result = buildPlaceFromCatalogCommand(
        doc: doc,
        catalogId: 'P01',
        targetRack: doc.racks[_rackId]!,
        now: _now,
        actor: 'test',
        zeroU: (
          channelId: 'ch-left',
          offsetFromChannelStart: kRackUnit * 12,
          orientation: ZeroUOrientation.vertical,
        ),
      );
      expect(result, isA<CatalogPlacementReady>());
      (result as CatalogPlacementReady).command.apply(doc);
      final placed = doc.devices.values.single;
      expect(placed.placement, isA<ZeroUPlacement>());
      expect(placed.designator, startsWith('PDU'));
    });

    test('KNOWN-BAD: a channel the rack does not have is refused', () {
      final doc = _doc();
      final result = buildPlaceFromCatalogCommand(
        doc: doc,
        catalogId: 'P01',
        targetRack: doc.racks[_rackId]!,
        now: _now,
        actor: 'test',
        zeroU: (
          channelId: 'ch-nope',
          offsetFromChannelStart: Len.zero,
          orientation: ZeroUOrientation.vertical,
        ),
      );
      expect(result, isA<CatalogPlacementFailed>());
      expect((result as CatalogPlacementFailed).ruleId, 'PLC-003');
    });

    test('WITHOUT a target it still refuses with the sentence that names '
        'this path, because a palette double-click means no channel', () {
      final doc = _doc();
      final result = buildPlaceFromCatalogCommand(
        doc: doc,
        catalogId: 'P01',
        targetRack: doc.racks[_rackId]!,
        now: _now,
        actor: 'test',
      );
      expect(result, isA<CatalogPlacementFailed>());
      final failed = result as CatalogPlacementFailed;
      expect(failed.reason, contains('AC-044'));
      expect(failed.ruleId, isNull);
    });

    test('KNOWN-BAD: sliding an existing occupant past the end is '
        'refused, which is the edit AC-044 asks for', () {
      final doc = _doc();
      _mountPdu(doc);
      final planned = planSetZeroUPosition(
        doc: doc,
        id: _pdu,
        channelId: 'ch-left',
        offsetFromChannelStart: kRackUnit * 20,
        now: _now,
        actor: 'test',
      );
      expect(planned, isA<ZeroURefused>());
      expect((planned as ZeroURefused).ruleId, 'PLC-003');
    });

    test('NEAR-MISS: sliding it to a legal offset writes, and reverts to '
        'identical bytes (CR-117)', () {
      final doc = _doc();
      _mountPdu(doc);
      final before = _codec.write(doc);
      final cmd =
          (planSetZeroUPosition(
                    doc: doc,
                    id: _pdu,
                    channelId: 'ch-left',
                    offsetFromChannelStart: kRackUnit * 4,
                    now: _now,
                    actor: 'test',
                  )
                  as ZeroUReady)
              .command;
      cmd.apply(doc);
      final applied = _codec.write(doc);
      expect(
        (doc.devices[_pdu]!.placement as ZeroUPlacement).offsetFromChannelStart,
        kRackUnit * 4,
      );
      cmd.revert(doc);
      expect(_codec.write(doc), before);
      cmd.apply(doc);
      expect(_codec.write(doc), applied);
    });

    test('a rail-placed device has no 0U position to set', () {
      final doc = _doc();
      doc.devices[_pdu] = DeviceInstance(
        id: _pdu,
        kind: DeviceKind.rackDevice,
        templateRef: const TemplateRef(
          templateId: TemplateId('P01'),
          version: 1,
          contentHash: 'sha256:p01',
        ),
        designator: 'PDU-1',
        name: '0U PDU',
        placement: const RailPlacement(
          rackId: _rackId,
          ruIndex: 1,
          face: Face.front,
        ),
        meta: _meta(),
      );
      final planned = planSetZeroUPosition(
        doc: doc,
        id: _pdu,
        channelId: 'ch-left',
        offsetFromChannelStart: Len.zero,
        now: _now,
        actor: 'test',
      );
      expect(planned, isA<ZeroURefused>());
      expect((planned as ZeroURefused).ruleId, isNull);
    });
  });

  group('the occupant walk both surfaces share', () {
    test('finds what is in the channel and nothing that is not', () {
      final doc = _doc();
      _mountPdu(doc);
      expect(
        occupantsOfZeroUChannel(doc, _rackId, 'ch-left').single.designator,
        'PDU-1',
      );
      expect(occupantsOfZeroUChannel(doc, _rackId, 'ch-right'), isEmpty);
      expect(
        occupantsOfZeroUChannel(doc, const Uuid('rk-other'), 'ch-left'),
        isEmpty,
      );
    });
  });

  group('the span AC-044 named and `#876` could not build (DR-166)', () {
    test('SETTING IT WRITES A LENGTH, and one undo takes it back', () {
      final doc = _doc();
      _mountPdu(doc);
      final planned = planSetZeroUSpan(
        doc: doc,
        id: _pdu,
        span: kRackUnit * 6,
        now: _now,
        actor: 'tester',
      );

      final command = (planned as ZeroUReady).command..apply(doc);
      expect(
        (doc.devices[_pdu]!.placement as ZeroUPlacement).spanAlongChannel,
        kRackUnit * 6,
      );

      command.revert(doc);
      expect(
        (doc.devices[_pdu]!.placement as ZeroUPlacement).spanAlongChannel,
        isNull,
        reason:
            'it was unknown before, and undo restores the unknown '
            'rather than a zero',
      );
    });

    test('CLEARING IT IS AN EDIT, not a refusal (G4)', () {
      // Somebody who does not know how long a PDU is has to be able to
      // say so, and every document written before `#883` is in exactly
      // that state.
      final doc = _doc();
      _mountPdu(doc, span: kRackUnit * 6);
      final planned = planSetZeroUSpan(
        doc: doc,
        id: _pdu,
        span: null,
        now: _now,
        actor: 'tester',
      );

      (planned as ZeroUReady).command.apply(doc);
      expect(
        (doc.devices[_pdu]!.placement as ZeroUPlacement).spanAlongChannel,
        isNull,
      );
    });

    test('A SPAN THAT RUNS OFF THE END IS REFUSED BY `PLC-003` ITSELF, '
        'not by a second rule beside it', () {
      // §11.165.3. The channel is U 1 to 12, so 13 U starting at its near
      // end hangs a unit off the top.
      final doc = _doc();
      _mountPdu(doc);
      final planned = planSetZeroUSpan(
        doc: doc,
        id: _pdu,
        span: kRackUnit * 13,
        now: _now,
        actor: 'tester',
      );

      expect(planned, isA<ZeroURefused>());
      expect((planned as ZeroURefused).ruleId, 'PLC-003');
    });

    test('and a span of nothing is refused in WORDS, with the way out', () {
      final doc = _doc();
      _mountPdu(doc);
      final planned = planSetZeroUSpan(
        doc: doc,
        id: _pdu,
        span: Len.zero,
        now: _now,
        actor: 'tester',
      );

      expect(planned, isA<ZeroURefused>());
      expect((planned as ZeroURefused).reason, contains('unknown'));
      expect(
        planned.ruleId,
        isNull,
        reason:
            'no rule in docs/02 §5 covers it, and inventing an id '
            'would put a rule in the product no fixture pair covers',
      );
    });

    test('MOVING AN OCCUPANT KEEPS ITS SPAN, which a rebuilt placement '
        'silently erases', () {
      // The one-line defect a new field on a rebuilt object always
      // invites: `planSetZeroUPosition` constructs a fresh
      // `ZeroUPlacement`, and a field it forgets to copy is gone with no
      // sign that anything happened.
      final doc = _doc();
      _mountPdu(doc, span: kRackUnit * 6);
      final planned = planSetZeroUPosition(
        doc: doc,
        id: _pdu,
        channelId: 'ch-left',
        offsetFromChannelStart: kRackUnit * 2,
        now: _now,
        actor: 'tester',
      );

      (planned as ZeroUReady).command.apply(doc);
      final p = doc.devices[_pdu]!.placement as ZeroUPlacement;
      expect(p.offsetFromChannelStart, kRackUnit * 2);
      expect(p.spanAlongChannel, kRackUnit * 6);
    });
  });
}
