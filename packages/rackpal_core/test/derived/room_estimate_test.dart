// LEN-A/3: plan geometry fills the room estimate (`#859`, DR-050 §11.49).
//
// ═══════════════════════════════════════════════════════════════════════
// THE LOAD-BEARING CASES ARE THE ONES THAT PICK THE WRONG RACK
// ═══════════════════════════════════════════════════════════════════════
// `plan_length_test.dart` says the same thing about its own four, and the
// shape is identical here: every arithmetic case below passes against a
// derivation that measures from the NEAREST pinned rack, or from any
// pinned rack, or from the farthest one. The cases under "the datum" are
// the ones that tell those apart, and they are marked.
//
// The decoy rack is placed on the OPPOSITE side of correct in each, so no
// single wrong rule survives both.
//
// ═══════════════════════════════════════════════════════════════════════
// AND ONE CASE IS ABOUT WHAT A REFUSAL WOULD HAVE COST
// ═══════════════════════════════════════════════════════════════════════
// A room whose runs land in two racks returns the LARGER figure rather
// than null, because `_lengthOf` falls through to `planLowerBound` and
// then `none`, and `_isQuantity` is false for both: a refused estimate
// means every run in that room buys zero wire in the takeoff. Against a
// trade that quotes conservatively, a silent zero is the worst available
// direction of error.
import 'dart:io';

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

import 'fixtures/plan_doc.dart';

/// A square room whose farthest corner from (0, 0) is exactly 500 pixels
/// away: 400 by 300 is a 3-4-5, so the figure is a round 180 inches at
/// `kUsableScale`'s 0.36 in per pixel.
const _square = <PxPt>[
  PxPt(100, 100),
  PxPt(400, 100),
  PxPt(400, 300),
  PxPt(100, 300),
];

/// Wires one run from a device in [rackId] to a drop in [roomId].
/// The default label is deliberately NOT one the cases below pass, so a
/// case naming its runs reads as naming them rather than as repeating a
/// default.
void _run(PlanDoc d, Uuid rackId, Uuid roomId, {String label = 'RUN-1'}) {
  final dev = d.rackDevice('PP-1', rackId);
  final out = d.outlet('WP-1', locationId: roomId);
  d.link(
    from: PortEndpoint(d.port(dev, 'J01')),
    to: PlaceEndpoint(locationId: roomId, description: 'TV wall'),
    outletId: out,
    fieldLabel: label,
  );
}

void main() {
  group('the figure: farthest corner plus rise', () {
    test('the most distant vertex, rounded once', () {
      final d = PlanDoc()..underlay();
      final room = d.room('Great Room', outline: _square);
      final rk = d.rack('RK-1', pin: planPin(0, 0));
      _run(d, rk, room);

      // 400 by 300 pixels is 500, at 0.36 in per pixel.
      expect(roomEstimateFor(d.doc, d.doc.locations[room]!), inches(180));
    });

    test('NOT the nearest vertex, and not the centre', () {
      // The corner at (100, 100) is 141 px away and the centroid is about
      // 269. A derivation measuring either would return 51 or 97 inches.
      final d = PlanDoc()..underlay();
      final room = d.room('Great Room', outline: _square);
      final rk = d.rack('RK-1', pin: planPin(0, 0));
      _run(d, rk, room);

      final answer = roomEstimateFor(d.doc, d.doc.locations[room]!)!;
      expect(answer.nm, greaterThan(inches(100).nm));
    });

    test('plus riseAllowance where one is set', () {
      final d = PlanDoc()..underlay();
      final room = d.room(
        'Great Room',
        outline: _square,
        riseAllowance: inches(96),
      );
      final rk = d.rack('RK-1', pin: planPin(0, 0));
      _run(d, rk, room);

      expect(roomEstimateFor(d.doc, d.doc.locations[room]!), inches(276));
    });

    test('and NOT when none is set, which is the control for the case '
        'above', () {
      final d = PlanDoc()..underlay();
      final room = d.room('Great Room', outline: _square);
      final rk = d.rack('RK-1', pin: planPin(0, 0));
      _run(d, rk, room);

      expect(roomEstimateFor(d.doc, d.doc.locations[room]!), inches(180));
    });
  });

  group('the datum is the rack this room’s runs land in', () {
    test('LOAD-BEARING: not the nearest pinned rack', () {
      // The decoy sits ON the room's near corner and the datum is far.
      // A nearest-rack derivation returns a much smaller figure.
      final d = PlanDoc()..underlay();
      final room = d.room('Great Room', outline: _square);
      d.rack('RK-DECOY', pin: planPin(100, 100));
      final datum = d.rack('RK-1', pin: planPin(0, 0));
      _run(d, datum, room);

      expect(roomEstimateFor(d.doc, d.doc.locations[room]!), inches(180));
    });

    test('LOAD-BEARING: not ANY pinned rack, and not the farthest', () {
      // The decoy is now FARTHER than the datum, so a rule that took the
      // largest over all pinned racks returns more than 180.
      final d = PlanDoc()..underlay();
      final room = d.room('Great Room', outline: _square);
      d.rack('RK-DECOY', pin: planPin(-2000, -2000));
      final datum = d.rack('RK-1', pin: planPin(0, 0));
      _run(d, datum, room);

      expect(roomEstimateFor(d.doc, d.doc.locations[room]!), inches(180));
    });

    test('a run belonging to ANOTHER room names no datum here', () {
      final d = PlanDoc()..underlay();
      final room = d.room('Great Room', outline: _square);
      final elsewhere = d.room('Study');
      final rk = d.rack('RK-1', pin: planPin(0, 0));
      _run(d, rk, elsewhere, label: 'ST-1');

      expect(roomEstimateFor(d.doc, d.doc.locations[room]!), isNull);
    });

    test('a JUMPER names no datum, because both its ends are in racks', () {
      // `planLowerBoundOf`'s condition, and it excludes the jumper, the
      // sub-feed and the field-to-field run without naming any of them.
      final d = PlanDoc()..underlay();
      final room = d.room('Great Room', outline: _square);
      final rk = d.rack('RK-1', pin: planPin(0, 0));
      final a = d.rackDevice('PP-1', rk);
      final b = d.rackDevice('SW-1', rk);
      d.link(
        from: PortEndpoint(d.port(a, 'J01')),
        to: PortEndpoint(d.port(b, 'J02')),
      );

      expect(roomEstimateFor(d.doc, d.doc.locations[room]!), isNull);
    });
  });

  group('two head ends over-estimate rather than refuse', () {
    test('the LARGER figure, because a refusal buys zero wire', () {
      // Both racks serve this room. The far one gives 180 inches and the
      // near one much less; the answer is the far one.
      //
      // A REFUSAL HERE WOULD NOT BE CAUTIOUS, IT WOULD BE SILENT.
      // `_lengthOf` falls through to `planLowerBound` and then `none`,
      // and `_isQuantity` is false for both, so every run in this room
      // would contribute nothing at all to the takeoff.
      final d = PlanDoc()..underlay();
      final room = d.room('Great Room', outline: _square);
      final near = d.rack('RK-NEAR', pin: planPin(100, 100));
      final far = d.rack('RK-FAR', pin: planPin(0, 0));
      _run(d, near, room, label: 'GR-1');
      _run(d, far, room, label: 'GR-2');

      expect(roomEstimateFor(d.doc, d.doc.locations[room]!), inches(180));
    });

    test('and it is a figure rather than a null, stated separately', () {
      // Said on its own because the case above would also pass if the
      // derivation returned null and `inches(180)` were null too.
      final d = PlanDoc()..underlay();
      final room = d.room('Great Room', outline: _square);
      final near = d.rack('RK-NEAR', pin: planPin(100, 100));
      final far = d.rack('RK-FAR', pin: planPin(0, 0));
      _run(d, near, room, label: 'GR-1');
      _run(d, far, room, label: 'GR-2');

      expect(roomEstimateFor(d.doc, d.doc.locations[room]!), isNotNull);
    });
  });

  group('the refusals, which mirror planLowerBoundOf', () {
    test('no outline at all', () {
      final d = PlanDoc()..underlay();
      final room = d.room('Great Room');
      final rk = d.rack('RK-1', pin: planPin(0, 0));
      _run(d, rk, room);

      expect(roomEstimateFor(d.doc, d.doc.locations[room]!), isNull);
    });

    test('an outline that is not a shape', () {
      final d = PlanDoc()..underlay();
      final room = d.room(
        'Great Room',
        outline: const [PxPt(100, 100), PxPt(400, 100)],
      );
      final rk = d.rack('RK-1', pin: planPin(0, 0));
      _run(d, rk, room);

      expect(roomEstimateFor(d.doc, d.doc.locations[room]!), isNull);
    });

    test('an underlay with no calibration, and one whose two points '
        'coincide', () {
      for (final scale in <PlanScale?>[null, kDegenerateScale]) {
        final d = PlanDoc()..underlay(scale: scale);
        final room = d.room('Great Room', outline: _square);
        final rk = d.rack('RK-1', pin: planPin(0, 0));
        _run(d, rk, room);

        expect(
          roomEstimateFor(d.doc, d.doc.locations[room]!),
          isNull,
          reason: scale == null ? 'uncalibrated' : 'degenerate',
        );
      }
    });

    test('no run to this room at all', () {
      final d = PlanDoc()..underlay();
      final room = d.room('Great Room', outline: _square);
      d.rack('RK-1', pin: planPin(0, 0));

      expect(roomEstimateFor(d.doc, d.doc.locations[room]!), isNull);
    });

    test('the datum rack carries no pin', () {
      final d = PlanDoc()..underlay();
      final room = d.room('Great Room', outline: _square);
      final rk = d.rack('RK-1');
      _run(d, rk, room);

      expect(roomEstimateFor(d.doc, d.doc.locations[room]!), isNull);
    });

    test('THE BASEMENT HEAD END: the datum is pinned on a DIFFERENT plan, '
        'and two plans are two unrelated pixel spaces', () {
      // The common whole-house shape, and it still refuses. The
      // horizontal offset between two floors is not a thing anybody has
      // recorded, so there is no measured quantity to be conservative
      // with. `riseAllowance` covers the vertical drop a plan cannot see;
      // nothing covers the horizontal one.
      final d = PlanDoc()
        ..underlay()
        ..underlay(id: kPlanUl2);
      final room = d.room('Great Room', outline: _square);
      final rk = d.rack('RK-1', pin: planPin(0, 0, on: kPlanUl2));
      _run(d, rk, room);

      expect(roomEstimateFor(d.doc, d.doc.locations[room]!), isNull);
    });

    test('an outline naming an underlay this document no longer holds '
        '(CR-093)', () {
      final d = PlanDoc()..underlay();
      final room = d.room('Great Room', outline: _square, outlineOn: kPlanUl2);
      final rk = d.rack('RK-1', pin: planPin(0, 0));
      _run(d, rk, room);

      expect(roomEstimateFor(d.doc, d.doc.locations[room]!), isNull);
    });
  });

  group('what this derivation is NOT', () {
    test('it adds no margin and no routing factor (DR-020, §11.49.4)', () {
      // The trade quotes several hundred feet over actual, and that
      // margin is the estimator's. A derivation that folded one in would
      // be `routingFactor` returning under another name, which DR-050
      // §11.49.4 says is "still deleted and still not to be re-argued
      // from".
      //
      // Asserted as an EXACT equality rather than a range: any multiplier
      // at all makes this fail, which a `greaterThan` would not.
      final d = PlanDoc()..underlay();
      final room = d.room('Great Room', outline: _square);
      final rk = d.rack('RK-1', pin: planPin(0, 0));
      _run(d, rk, room);

      expect(
        roomEstimateFor(d.doc, d.doc.locations[room]!)!.nm,
        inches(180).nm,
      );
    });

    test('IT HAS NO PRODUCTION CALLER YET, AND `#861` IS WHAT RETIRES '
        'THIS CASE', () {
      // ═══════════════════════════════════════════════════════════════
      // A DERIVATION NOBODY CALLS IS A FAILURE THIS PROJECT HAS SHIPPED
      // ═══════════════════════════════════════════════════════════════
      // `PdfImageResolver` was a typedef with ZERO production call sites
      // from PLAN-A until PLAN-H, `PortDef.bus.maxTapWatts` was declared
      // on zero of 727 seeded ports, and `riseAllowance` was named by two
      // rulings and a design document and written by nothing until
      // PLAN-C. `roomEstimateFor` is in that state right now, on purpose:
      // `LEN-A/5` owns the write path and the editor.
      //
      // So the absence is ASSERTED rather than left to be discovered.
      // When `#861` wires it up this case fails, and whoever lands it
      // deletes the case rather than wondering whether the scan was
      // supposed to find something.
      final lib = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList();
      expect(lib.length, greaterThan(50), reason: 'the scan found nothing');

      // A CALL, NOT A MENTION. The first version of this scan matched
      // `contains('roomEstimateFor')` and failed on a COMMENT in
      // `schedule.dart` that names the function to explain why the room
      // rule was extracted. A gate that cannot tell a call from a
      // sentence about one reports the wrong thing on its first run.
      bool callsIt(File f) {
        for (final line in f.readAsLinesSync()) {
          final code = line.trimLeft();
          if (code.startsWith('//') || code.startsWith('*')) continue;
          if (code.contains('roomEstimateFor(')) return true;
        }
        return false;
      }

      final callers = <String>[
        for (final f in lib)
          if (!f.path.endsWith('room_estimate.dart') && callsIt(f)) f.path,
      ];
      expect(
        callers,
        isEmpty,
        reason:
            '`#861` has wired roomEstimateFor up. Delete this case and '
            'assert the write path instead',
      );
    });

    test('it is not gated on LocationKind, because the field is not', () {
      // A person who drew an outline on a zone meant it. Refusing by kind
      // would be inventing a rule DR-050 does not state.
      final d = PlanDoc()..underlay();
      final room = d.room('Open plan', outline: _square);
      d.doc.locations[room]!.kind = LocationKind.zone;
      final rk = d.rack('RK-1', pin: planPin(0, 0));
      _run(d, rk, room);

      expect(roomEstimateFor(d.doc, d.doc.locations[room]!), inches(180));
    });
  });
}
