// DR-128 §11.127.5, §11.127.8, §11.127.9: `PWR-003`'s remedy.
//
// ═════════════════════════════════════════════════════════════════════
// THE ARTIFACT IS "THE FINDING STOPS FIRING"
// ═════════════════════════════════════════════════════════════════════
// A test that asserted "a device was added" would pass on every version
// of this that does not work, and there were two such versions while it
// was being written. Both added a device; neither moved the finding.
//
//   * `StagedPlacement` answers null from `hostRackOf`, so a staged
//     device is in no rack and `rulePwr003` never counts it.
//   * `OffRackPlacement`, which is what `buildPlaceFromCatalogCommand`
//     gives anything whose `side` is `none`, does the same.
//
// "A remedy chip that only explains has not remedied" (`#278`), one tier
// down. So every assertion below runs `rulePwr003` before and after.
import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

import '../validation/fixtures/fixture_docs.dart';

/// A rack wanting four outlets and offered [provided].
RackDocument _short({required int provided}) {
  final doc = fixtureDoc();
  fixturePlaceBody(
    doc,
    fixtureBody(power: PowerProfile(outletsConsumed: 4)),
    1,
    seq: 1,
    designator: 'AMP-1',
  );
  if (provided > 0) {
    fixturePlaceBody(
      doc,
      fixtureBody(power: PowerProfile(outletsProvided: provided)),
      3,
      seq: 2,
      designator: 'PDU-1',
    );
  }
  return doc;
}

/// Through `evaluateDocument`, not the predicate directly.
///
/// The predicate would answer the same today, and the entry point is what
/// the issues panel calls: it is where the project's severity override is
/// applied, and DR-125 §11.124.2 records that a rule's own severity being
/// DISCARDED there went unseen for a milestone. A remedy test that
/// bypassed it would be testing a path no user reaches.
List<Finding> _pwr003(RackDocument doc) =>
    evaluateDocument(doc, only: 'PWR-003');

void main() {
  group('the premise', () {
    test('PWR-003 fires on a rack that is two outlets short', () {
      expect(_pwr003(_short(provided: 2)), hasLength(1));
    });

    test('and the finding carries the remedy, which is what puts the '
        'button on the panel', () {
      expect(
        _pwr003(_short(provided: 2)).single.remedy,
        FindingRemedy.addRackPdu,
      );
    });

    test('no other tier-3 rule has one, because nobody designed one', () {
      // The restraint `SpringBackRemedy` states and this enum inherits.
      expect(FindingRemedy.values, hasLength(1));
    });
  });

  group('a rack that already has distribution gets the strip', () {
    late RackDocument doc;
    late DocumentController controller;

    setUp(() {
      doc = _short(provided: 2);
      controller = DocumentController(doc, clock: FixedClock(fixtureAt));
    });

    AddOutletsResult run({OutletSource? source}) {
      late AddOutletsResult result;
      controller.transact(LabelKey.addDevice, (tx) {
        result = addOutletsToRack(
          tx,
          doc: doc,
          rackId: kFixtureRackId,
          now: fixtureAt,
          actor: 'test',
          source: source,
        );
      });
      return result;
    }

    test('it picks the strip without asking, because the rack has a PDU', () {
      final result = run();
      expect(result, isA<AddOutletsDone>());
      expect((result as AddOutletsDone).source, OutletSource.powerStrip);
    });

    test('AND THE FINDING CLEARS, which is the whole point', () {
      expect(_pwr003(doc), hasLength(1));
      run();
      expect(
        _pwr003(doc),
        isEmpty,
        reason:
            'the strip was added but the rack still reads as short, so it '
            'did not land anywhere rulePwr003 counts',
      );
    });

    test('it gains FIVE, not six, because it eats an outlet to give six', () {
      expect((run() as AddOutletsDone).outletsGained, 5);
    });

    test('a shelf is added to stand it on, since the rack has none', () {
      final before = doc.devices.length;
      final done = run() as AddOutletsDone;
      expect(
        doc.devices.length,
        before + 2,
        reason: 'the strip and the shelf it sits on',
      );
      final strip = doc.devices[done.deviceId]!;
      final placement = strip.placement;
      expect(placement, isA<ShelfPlacement>());
      final host = doc.devices[(placement as ShelfPlacement).hostDeviceId]!;
      expect(bodyFor(host, doc.templates)!.isContainer, isTrue);
    });

    test('and one undo takes back the shelf, the strip and the finding', () {
      run();
      final after = doc.devices.length;
      controller.undoLast();
      expect(doc.devices, hasLength(after - 2));
      expect(_pwr003(doc), hasLength(1), reason: 'the finding comes back');
    });

    test('a second strip reuses the shelf rather than adding another', () {
      run();
      final shelves = doc.devices.values
          .where((d) => bodyFor(d, doc.templates)?.isContainer ?? false)
          .length;
      run();
      expect(
        doc.devices.values
            .where((d) => bodyFor(d, doc.templates)?.isContainer ?? false)
            .length,
        shelves,
      );
    });

    test('two strips on one shelf pack left to right, in order (AC-043)', () {
      final first = run() as AddOutletsDone;
      final second = run() as AddOutletsDone;
      final a = doc.devices[first.deviceId]!.placement as ShelfPlacement;
      final b = doc.devices[second.deviceId]!.placement as ShelfPlacement;
      expect(a.hostDeviceId, b.hostDeviceId);
      expect(b.order.v.compareTo(a.order.v), greaterThan(0));
      expect(
        a.lateralOffset,
        isNull,
        reason:
            'AC-043 defers free lateral positioning; the field stays '
            'in the format and the UI does not set it',
      );
    });
  });

  group('a rack with no power at all is ASKED, not guessed at', () {
    late RackDocument doc;
    late DocumentController controller;

    setUp(() {
      doc = _short(provided: 0);
      controller = DocumentController(doc, clock: FixedClock(fixtureAt));
    });

    AddOutletsResult run({OutletSource? source}) {
      late AddOutletsResult result;
      controller.transact(LabelKey.addDevice, (tx) {
        result = addOutletsToRack(
          tx,
          doc: doc,
          rackId: kFixtureRackId,
          now: fixtureAt,
          actor: 'test',
          source: source,
        );
      });
      return result;
    }

    test('it returns a question and changes nothing', () {
      final before = doc.devices.length;
      final result = run();
      expect(result, isA<AddOutletsChoice>());
      expect((result as AddOutletsChoice).question, contains('RK-1'));
      expect(doc.devices, hasLength(before));
    });

    test('answering "strip" places one, and the finding clears', () {
      expect(run(), isA<AddOutletsChoice>());
      final done = run(source: OutletSource.powerStrip);
      expect(done, isA<AddOutletsDone>());
      expect(_pwr003(doc), isEmpty);
    });

    test('answering "PDU" places one in a 0U channel, and it clears too', () {
      final done = run(source: OutletSource.rackPdu);
      expect(done, isA<AddOutletsDone>());
      final pdu = doc.devices[(done as AddOutletsDone).deviceId]!;
      expect(pdu.placement, isA<ZeroUPlacement>());
      expect(_pwr003(doc), isEmpty);
      expect(done.outletsGained, 23);
    });

    test('the PDU gets a channel to sit in, since the rack had none', () {
      expect(doc.racks[kFixtureRackId]!.zeroUChannels, isEmpty);
      run(source: OutletSource.rackPdu);
      final channels = doc.racks[kFixtureRackId]!.zeroUChannels;
      expect(channels, hasLength(1));
      expect(
        channels.single.side,
        ZeroUChannelSide.rearLeft,
        reason: 'a 0U PDU goes down the back where the cords are',
      );
      // 1-BASED, CR-025 (`#876`, DR-163). This asserted `heightU - 1`,
      // which pinned a sub-1 channel as intended behaviour: the only
      // producer in the product wrote `startU: 0` and cited CR-025, which
      // rules the opposite. A full-height channel on a 42 U rack runs
      // U 1 to U 42.
      expect(channels.single.startU, 1);
      expect(channels.single.endU, doc.racks[kFixtureRackId]!.heightU);
    });

    test('a second PDU reuses the channel rather than adding another', () {
      run(source: OutletSource.rackPdu);
      run(source: OutletSource.rackPdu);
      expect(doc.racks[kFixtureRackId]!.zeroUChannels, hasLength(1));
    });
  });

  group('what it refuses', () {
    test('a rack that has left the drawing', () {
      final doc = _short(provided: 2);
      final controller = DocumentController(doc, clock: FixedClock(fixtureAt));
      late AddOutletsResult result;
      controller.transact(LabelKey.addDevice, (tx) {
        result = addOutletsToRack(
          tx,
          doc: doc,
          rackId: const Uuid('no-such-rack'),
          now: fixtureAt,
          actor: 'test',
        );
      });
      expect(result, isA<AddOutletsRefused>());
    });
  });
}
