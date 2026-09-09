// PLAN-H/3: designator pills, the placement ring, and the leader
// (docs/15 §7, DR-150 §11.149).
//
// ═══════════════════════════════════════════════════════════════════════
// THE LOAD-BEARING CASES ARE THE ONES ABOUT CROWDING
// ═══════════════════════════════════════════════════════════════════════
// Placement on an empty plan is arithmetic and any implementation passes
// it. What decides whether a stranger can read the sheet is what happens
// when three drops sit on one wall: DR-150 §11.149.5 rules that a callout
// is NEVER dropped, so the failure mode is an overlap that is reported
// rather than a designator that is silently missing. Four cases below are
// about that and are marked.
import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

import 'sheet_test_support.dart';

/// The drawing area of an ANSI B landscape sheet, near enough: these cases
/// are about placement relative to a pin, not about the frame.
const DBox _area = DBox.fromLtwh(40, 40, 1100, 700);

CalloutSubject _at(
  double x,
  double y, {
  String id = 'a',
  String text = 'WP-1',
}) => CalloutSubject(entityId: Uuid(id), at: DPt(x, y), text: text);

PlanCalloutLayer _build(List<CalloutSubject> subjects, {DBox area = _area}) =>
    buildPlanCallouts(
      subjects: subjects,
      area: area,
      measurer: FakeMeasurer(),
    );

List<DBox> _pills(PlanCalloutLayer layer) =>
    layer.ops.whereType<OpRoundRect>().map((o) => o.r).toList();

void main() {
  group('one pill per subject', () {
    test('a pill, its text, and no leader when it sits close', () {
      final layer = _build([_at(500, 400)]);

      expect(_pills(layer), hasLength(1));
      expect(layer.ops.whereType<OpText>().single.text, 'WP-1');
      expect(
        layer.ops.whereType<OpLine>(),
        isEmpty,
        reason: 'inside the clearance, proximity does the pairing',
      );
      expect(layer.crowdedCount, 0);
      expect(layer.leaderCount, 0);
    });

    test('the pill is OPAQUE WHITE with a black outline, never a tint', () {
      // DR-150 §11.149.2. A translucent fill would be the wash the ruling
      // refused, and docs/08 row 9 forbids alpha in the document anyway.
      final pill = _build([_at(500, 400)]).ops.whereType<OpRoundRect>().single;

      expect(pill.fill?.argb, 0xFFFFFFFF);
      expect(pill.stroke?.argb, 0xFF000000);
      expect(
        (pill.fill!.argb >> 24) & 0xFF,
        255,
        reason: 'the knock-out is what makes it legible over line work',
      );
    });

    test('it is a stadium: the radius is half the height', () {
      final pill = _build([_at(500, 400)]).ops.whereType<OpRoundRect>().single;

      expect(pill.radii.rv, closeTo(pill.r.height / 2, 1e-9));
      expect(pill.radii.rh, closeTo(pill.r.height / 2, 1e-9));
    });

    test('the height comes from the TYPE SIZE, not from font metrics', () {
      // `wire_trace.dart`'s reason, taken deliberately: the two backends
      // agree on `sizePt` and on ascent/descent only up to their font
      // tables, so a pill measured from metrics is a different height on
      // paper than on screen.
      final pill = _build([_at(500, 400)]).ops.whereType<OpRoundRect>().single;

      expect(pill.r.height, closeTo(kCalloutTextPt + kCalloutPadPt * 2, 1e-9));
    });

    /// LOAD-BEARING. The near edge anchors, not the centre.
    test('the pill hangs OFF the pin and never covers it', () {
      final pin = _at(500, 400);
      final pill = _build([pin]).ops.whereType<OpRoundRect>().single;

      expect(
        pill.r.contains(pin.at),
        isFalse,
        reason: 'a pill centred on its anchor covers the thing it labels',
      );
    });
  });

  group('crowding', () {
    /// LOAD-BEARING. Three drops on one wall is the ordinary case on a
    /// rough-in, and it is what decides whether the sheet can be read.
    test('pills on neighbouring pins do not overlap each other', () {
      final layer = _build([
        _at(500, 400),
        _at(506, 400, id: 'b'),
        _at(512, 400, id: 'c'),
      ]);

      final boxes = _pills(layer);
      expect(boxes, hasLength(3));
      for (var i = 0; i < boxes.length; i++) {
        for (var j = i + 1; j < boxes.length; j++) {
          expect(
            boxes[i].intersects(boxes[j]),
            isFalse,
            reason: 'pill $i and pill $j collide',
          );
        }
      }
      expect(layer.crowdedCount, 0, reason: 'the ring found room');
    });

    /// THE RING'S CAPACITY, MEASURED RATHER THAN GUESSED.
    ///
    /// The first draft of this case used twelve coincident pins and
    /// asserted crowding; the ring solved all twelve, because four radii
    /// by eight directions is thirty-two slots. Probed instead: **twenty
    /// coincident pins all get a clear callout and crowding starts at
    /// twenty-four.** That is the number worth writing down, and it is
    /// well past any real wall.
    test('twenty coincident drops all get a clear callout', () {
      final layer = _build([
        for (var i = 0; i < 20; i++) _at(500, 400, id: 'p$i'),
      ]);

      expect(_pills(layer), hasLength(20));
      expect(layer.crowdedCount, 0);
    });

    /// LOAD-BEARING. A callout is never dropped (§11.149.5).
    test('past that, every designator still prints and the sheet SAYS how '
        'many overlap', () {
      final layer = _build([
        for (var i = 0; i < 24; i++) _at(500, 400, id: 'p$i'),
      ]);

      expect(
        _pills(layer),
        hasLength(24),
        reason: 'twenty-four pins, twenty-four designators, whatever it costs',
      );
      expect(
        layer.crowdedCount,
        greaterThan(0),
        reason: 'and the sheet reports what it could not place',
      );
    });

    test('the layout is deterministic: same subjects, same boxes', () {
      final subjects = [
        _at(500, 400),
        _at(506, 400, id: 'b'),
        _at(700, 300, id: 'c'),
      ];
      expect(_pills(_build(subjects)), _pills(_build(subjects)));
    });
  });

  group('the leader', () {
    /// LOAD-BEARING. docs/15 §7: a leader only when the pill cannot sit
    /// within its own pin's clearance.
    test('a displaced pill gets a leader; a close one does not', () {
      final crowded = _build([
        for (var i = 0; i < 12; i++) _at(500.0 + i, 400, id: 'p$i'),
      ]);
      expect(crowded.leaderCount, greaterThan(0));

      final lone = _build([_at(500, 400)]);
      expect(lone.leaderCount, 0);
      expect(lone.ops.whereType<OpLine>(), isEmpty);
    });

    test('the leader runs from the pin to the pill EDGE, not under it', () {
      final subjects = [
        for (var i = 0; i < 12; i++) _at(500.0 + i, 400, id: 'p$i'),
      ];
      final layer = _build(subjects);
      final lines = layer.ops.whereType<OpLine>().toList();
      expect(lines, isNotEmpty);

      for (final line in lines) {
        // The far end is on some pill's outline: clamped to its box, so it
        // touches an edge rather than reaching the centre.
        final onSomeEdge = _pills(layer).any(
          (box) =>
              (line.b.x - box.left).abs() < 1e-6 ||
              (line.b.x - box.right).abs() < 1e-6 ||
              (line.b.y - box.top).abs() < 1e-6 ||
              (line.b.y - box.bottom).abs() < 1e-6,
        );
        expect(onSomeEdge, isTrue, reason: 'leader ends at ${line.b}');
      }
    });
  });

  group('the drawing area', () {
    /// LOAD-BEARING. A callout under the title block is a callout nobody
    /// reads.
    test('a pin against the edge places its pill INSIDE the area', () {
      final layer = _build([_at(_area.left + 2, _area.top + 2)]);
      final pill = _pills(layer).single;

      expect(pill.left, greaterThanOrEqualTo(_area.left));
      expect(pill.top, greaterThanOrEqualTo(_area.top));
      expect(pill.right, lessThanOrEqualTo(_area.right));
      expect(pill.bottom, lessThanOrEqualTo(_area.bottom));
    });

    test('an area too small for any candidate still draws the callout', () {
      // The refusal of last resort. G4: an absent callout is a drop the
      // stranger cannot find.
      final layer = _build(
        [_at(50, 50)],
        area: const DBox.fromLtwh(49, 49, 2, 2),
      );
      expect(_pills(layer), hasLength(1));
      expect(layer.crowdedCount, 1);
    });
  });

  group('what a callout is worth over a screened underlay', () {
    /// The Dart half of DR-150 §11.149.4. `tools/pal1_check.py` is the
    /// gate and parses the screening constant out of `plan_image.dart`;
    /// this states the property the gate computes, in the package that
    /// draws the thing.
    test('the callout ink is opaque black, which is what the gate '
        'assumes', () {
      final pill = _build([_at(500, 400)]).ops.whereType<OpRoundRect>().single;
      final text = _build([_at(500, 400)]).ops.whereType<OpText>().single;

      expect(pill.stroke?.argb, 0xFF000000);
      expect(text.style.argb, 0xFF000000);
    });
  });
}
