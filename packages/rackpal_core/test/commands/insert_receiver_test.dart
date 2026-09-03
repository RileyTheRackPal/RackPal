// M5-D `#278` — `SIG-001`'s remedy, driven through a real transaction.
//
// THE POINT OF THESE TESTS IS THE UNDO ENTRY. Three commands run: the
// snapshot, the device, the cable. `[ Insert HDBaseT receiver ]` is worth
// nothing if undoing it leaves an orphan receiver behind, and worth less
// than nothing if it leaves a cable pointing at a device that is gone.
// docs/05 §5 asks for ONE undo step and that is the assertion that cannot
// be made by calling the planner and looking at what it returned.

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

void main() {
  late RackDocument doc;
  late DocumentController controller;
  final at = DateTime.utc(2026, 9, 3, 12);

  /// A document holding one rack and one HDBaseT source, placed the way
  /// the app places things rather than hand-built.
  ///
  /// USES THE REAL PLACEMENT PATH so the fixture cannot drift from what a
  /// user's document looks like. V05 is the Presentation Switcher, which
  /// §3.1 gives an `HDBT OUT`; the receiver has to land on THAT, not on
  /// some port a fixture invented.
  RackDocument build() {
    final d = RackDocument(
      id: const Uuid('0190e0bb-0000-7000-8000-000000000000'),
      appVersion: '0.5.28',
      createdAt: at,
      modifiedAt: at,
      meta: EntityMeta(createdAt: at, updatedAt: at, updatedBy: 'test'),
      info: ProjectInfo(projectName: 'REMEDY FIXTURE'),
      registries: buildSeedRegistries(),
    );
    const rackId = Uuid('0190e0bb-0000-7000-8000-000000000fff');
    d.racks[rackId] = Rack(
      id: rackId,
      name: 'HEAD END',
      designator: 'RK-1',
      heightU: 12,
      order: const FracIndex('a0'),
      meta: EntityMeta(createdAt: at, updatedAt: at, updatedBy: 'test'),
    );
    final catalog = buildSeedCatalog();
    d.templates[templateKey('V05', 1)] = TemplateSnapshot(
      templateId: const TemplateId('V05'),
      version: 1,
      contentHash: 'sha256:seed-V05',
      body: catalog['V05']!,
      capturedAt: at,
    );
    final placed = buildPlaceFromCatalogCommand(
      doc: d,
      catalogId: 'V05',
      targetRack: d.racks[rackId]!,
      now: at,
      actor: 'test',
    );
    (placed as CatalogPlacementReady).command.apply(d);
    return d;
  }

  setUp(() {
    doc = build();
    controller = DocumentController(doc, clock: FixedClock(at));
  });

  /// The HDBaseT source on the placed switcher.
  ConnectTarget hdbaseTSource() {
    final device = doc.devices.values.first;
    final body = bodyFor(device, doc.templates)!;
    final port = body.ports.firstWhere(
      (p) =>
          p.signalFamily.v == 'video.hdbaset' &&
          p.direction == PortDirection.source,
    );
    return resolveConnectTarget(
      doc,
      deviceId: device.id,
      portKey: port.key.v,
    )!;
  }

  /// Runs the remedy the way the screen will.
  InsertReceiverResult run() {
    late InsertReceiverResult result;
    controller.transact(LabelKey.connectPorts, (tx) {
      result = insertHdbasetReceiver(
        tx,
        doc: doc,
        from: hdbaseTSource(),
        now: at,
        actor: 'test',
      );
    });
    return result;
  }

  group('the premise', () {
    test('the fixture holds one device and no cables', () {
      expect(doc.devices, hasLength(1));
      expect(doc.links, isEmpty);
    });

    test('and that device really does carry an HDBaseT SOURCE', () {
      // Without this the whole suite could pass against a fixture that
      // never triggers `SIG-001` at all.
      expect(hdbaseTSource().def.signalFamily.v, 'video.hdbaset');
      expect(hdbaseTSource().def.direction, PortDirection.source);
    });
  });

  group('what the remedy does', () {
    test('it mints a receiver and lands the run on it', () {
      final result = run();
      expect(result, isA<InsertReceiverDone>());
      final done = result as InsertReceiverDone;

      expect(doc.devices, hasLength(2));
      final rx = doc.devices[done.receiverId]!;
      expect(rx.designator, done.receiverDesignator);
      expect(
        rx.designator,
        startsWith('RX'),
        reason: "the receiver allocates under the role's own prefix",
      );
      expect(
        rx.placement,
        isA<OffRackPlacement>(),
        reason: '§540: the receiver lives at the display end of the run',
      );
    });

    test('the cable lands on the HDBaseT INPUT, not on some other port', () {
      // The remedy inserting a device the cable cannot reach would be a
      // success message over a broken design.
      run();
      expect(doc.links, hasLength(1));
      final link = doc.links.values.single;
      final ends = [
        for (final c in link.conductors) ...[c.from, c.to],
      ].whereType<PortEndpoint>().map((e) => doc.ports[e.portId]!).toList();
      final landed = ends.firstWhere(
        (p) => p.deviceId != doc.devices.values.first.id,
      );
      final rxBody = bodyFor(doc.devices[landed.deviceId]!, doc.templates)!;
      final def = rxBody.ports.firstWhere(
        (d) => d.key == landed.templatePortKey,
      );
      expect(def.signalFamily.v, 'video.hdbaset');
      expect(def.direction, PortDirection.sink);
    });

    test('the receiver HDMI end is left OPEN — DR-115 §11.114.3', () {
      // The ruling, asserted. The second link is unbuildable because
      // `SIG-001`'s target is an Ethernet jack by construction, so the
      // finished state of the remedy is one cable and an open HDMI out.
      final done = run() as InsertReceiverDone;
      final rxBody = bodyFor(doc.devices[done.receiverId]!, doc.templates)!;
      final hdmiOut = rxBody.ports.firstWhere(
        (p) =>
            p.signalFamily.v == 'video.hdmi.2_0' &&
            p.direction == PortDirection.source,
      );
      final portId = derivePortId(done.receiverId, hdmiOut.key);
      expect(
        portConductorCount(doc, portId),
        0,
        reason: 'nothing is wired to it, and that is the finished state',
      );
    });

    test('the template snapshot is IN the document, so the body resolves', () {
      // `AddDeviceCommand` never writes `doc.templates` (its own revert
      // comment says so), so without the snapshot command the receiver
      // would be a device whose `TemplateRef` resolves to nothing and
      // which draws as an unknown body.
      final done = run() as InsertReceiverDone;
      final rx = doc.devices[done.receiverId]!;
      expect(rx.templateRef.templateId.v, 'V06:receiver');
      expect(
        bodyFor(rx, doc.templates),
        isNotNull,
        reason: 'a device whose template does not resolve draws as unknown',
      );
    });
  });

  group('ONE undo entry (CR-015, docs/05 §5)', () {
    test('undo takes back the cable, the device AND the snapshot', () {
      run();
      expect(doc.devices, hasLength(2));
      expect(doc.links, hasLength(1));
      expect(doc.templates, hasLength(2));

      controller.undoLast();

      expect(
        doc.links,
        isEmpty,
        reason: 'the cable goes back with the gesture that made it',
      );
      expect(
        doc.devices,
        hasLength(1),
        reason: 'an orphan receiver is worse than no remedy at all',
      );
      expect(
        doc.templates,
        hasLength(1),
        reason:
            "and the snapshot too, or undo leaves the project's "
            'template list growing by one per undone remedy',
      );
    });

    test('it is ONE entry, not three', () {
      // The assertion that cannot be made by inspecting the planner's
      // return value. Three `run` calls would need three undos.
      run();
      controller.undoLast();
      expect(doc.devices, hasLength(1));
      expect(
        controller.undo.canUndo,
        isFalse,
        reason:
            'one gesture, one entry — a second undo here would mean '
            'the remedy shipped as three separate acts',
      );
    });

    test('redo puts all three back', () {
      final done = run() as InsertReceiverDone;
      controller
        ..undoLast()
        ..redoLast();
      expect(doc.devices, hasLength(2));
      expect(doc.links, hasLength(1));
      expect(doc.devices.containsKey(done.receiverId), isTrue);
    });
  });

  group('refusals write nothing', () {
    test('a source that does not carry HDBaseT is refused', () {
      // A chip is computed one frame before the button is pressed, and
      // the document can move in between. Landing an HDMI run on an
      // HDBaseT inlet because nobody re-checked would be the remedy
      // creating the defect it exists to remove.
      final device = doc.devices.values.first;
      final body = bodyFor(device, doc.templates)!;
      final hdmi = body.ports.firstWhere(
        (p) =>
            p.signalFamily.v == 'video.hdmi.2_0' &&
            p.direction == PortDirection.source,
      );
      final from = resolveConnectTarget(
        doc,
        deviceId: device.id,
        portKey: hdmi.key.v,
      )!;

      late InsertReceiverResult result;
      controller.transact(LabelKey.connectPorts, (tx) {
        result = insertHdbasetReceiver(
          tx,
          doc: doc,
          from: from,
          now: at,
          actor: 'test',
        );
      });

      expect(result, isA<InsertReceiverRefused>());
      expect(doc.devices, hasLength(1), reason: 'no receiver was minted');
      expect(doc.links, isEmpty);
      expect(
        doc.templates,
        hasLength(1),
        reason:
            'and no snapshot was written either — every check that '
            'can fail runs before the first tx.add',
      );
    });

    test('a refusal names a reason a person can act on', () {
      final device = doc.devices.values.first;
      final body = bodyFor(device, doc.templates)!;
      final hdmi = body.ports.firstWhere(
        (p) => p.signalFamily.v == 'video.hdmi.2_0',
      );
      late InsertReceiverResult result;
      controller.transact(LabelKey.connectPorts, (tx) {
        result = insertHdbasetReceiver(
          tx,
          doc: doc,
          from: resolveConnectTarget(
            doc,
            deviceId: device.id,
            portKey: hdmi.key.v,
          )!,
          now: at,
          actor: 'test',
        );
      });
      final refused = result as InsertReceiverRefused;
      expect(refused.reason, contains('HDBaseT'));
      expect(refused.reason, isNot(contains('null')));
    });
  });

  group('twice in one project', () {
    test('a SECOND remedy on the same full source is refused by TIER 1', () {
      // NOT A DEFECT, AND THE FIRST DRAFT OF THIS SUITE ASSUMED IT WAS.
      // That draft ran the remedy twice from one pin and expected two
      // receivers; `maxConnections` defaults to 1, so the switcher's
      // `HDBT OUT` is full the moment the first cable lands and `TOP-003`
      // refuses the second. The rule is right: one output drives one run.
      run();
      final second = run();
      expect(second, isA<InsertReceiverRefused>());
      expect(
        (second as InsertReceiverRefused).reason,
        startsWith('TOP-'),
        reason:
            'a tier-1 refusal keeps its id, like every other on this '
            'path (DR-011.5)',
      );
      expect(
        doc.devices,
        hasLength(2),
        reason:
            'and the refused attempt minted NOTHING — the checks that '
            'can fail all run before the first tx.add, but this one '
            'cannot, so the transaction is what has to be clean',
      );
      expect(doc.links, hasLength(1));
    });

    test('two different sources each get their own receiver', () {
      // The real "twice" case. `nextTemplateVersion` is asked per insert
      // rather than assumed to be 1, and the designator allocator sees
      // the first receiver, so neither collides.
      run();

      // A second switcher, placed the same way as the first.
      final placed = buildPlaceFromCatalogCommand(
        doc: doc,
        catalogId: 'V05',
        targetRack: doc.racks.values.first,
        now: at,
        actor: 'test',
      );
      (placed as CatalogPlacementReady).command.apply(doc);
      final second = doc.devices[placed.command.id]!;
      final body = bodyFor(second, doc.templates)!;
      final out = body.ports.firstWhere(
        (p) =>
            p.signalFamily.v == 'video.hdbaset' &&
            p.direction == PortDirection.source,
      );

      late InsertReceiverResult result;
      controller.transact(LabelKey.connectPorts, (tx) {
        result = insertHdbasetReceiver(
          tx,
          doc: doc,
          from: resolveConnectTarget(
            doc,
            deviceId: second.id,
            portKey: out.key.v,
          )!,
          now: at,
          actor: 'test',
        );
      });

      final done = result as InsertReceiverDone;
      final receivers = doc.devices.values
          .where((d) => d.templateRef.templateId.v == 'V06:receiver')
          .toList();
      expect(receivers, hasLength(2));
      expect(
        receivers.map((d) => d.designator).toSet(),
        hasLength(2),
        reason:
            'two devices sharing a designator is a wrong identifier on '
            'a termination schedule (G4)',
      );
      expect(done.receiverId, isIn(receivers.map((d) => d.id)));
      expect(doc.links, hasLength(2));
    });
  });
}
