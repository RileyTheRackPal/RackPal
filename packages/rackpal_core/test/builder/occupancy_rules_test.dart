// What a template's occupancy fields imply about each other (DR-203,
// `#951`).
//
// THE SWEEP OVER THE SHIPPED CATALOG IS THE TEST THAT MATTERS. The
// derivation is only right if it is the trade's, and the seeded
// templates are the trade's answers written down: if any of them
// disagreed with `derivedOccupancy`, the builder would rewrite a real
// device the moment somebody touched its height.
import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

TemplateBody _body({
  MountMethod mount = MountMethod.rackEars,
  int front = 0,
  int rear = 0,
  OccupancySide side = OccupancySide.none,
  WidthClass width = WidthClass.full,
  int span = 12,
}) => TemplateBody(
  manufacturer: 'Generic',
  model: '',
  displayName: 'X',
  frontU: front,
  rearU: rear,
  side: side,
  mountMethod: mount,
  widthClass: width,
  nominalSpanTwelfths: span,
);

void main() {
  test('EVERY SEEDED TEMPLATE ALREADY SATISFIES THE DERIVATION', () {
    final disagreements = <String>[];
    buildSeedCatalog().forEach((id, body) {
      final d = derivedOccupancy(body);
      if (d.frontU != body.frontU ||
          d.rearU != body.rearU ||
          d.side != body.side ||
          d.nominalSpanTwelfths != body.nominalSpanTwelfths) {
        disagreements.add(
          '$id: stored ${body.frontU}/${body.rearU}/${body.side.name}/'
          '${body.nominalSpanTwelfths}, derived ${d.frontU}/${d.rearU}/'
          '${d.side.name}/${d.nominalSpanTwelfths}',
        );
      }
    });
    expect(disagreements, isEmpty);
    // Not vacuous: the catalog is the ~50 templates it ships.
    expect(buildSeedCatalog().length, greaterThan(40));
  });

  group('the side follows the heights on a rack mount', () {
    test('front and rear', () {
      expect(
        derivedOccupancy(_body(front: 2, rear: 2)).side,
        OccupancySide.both,
      );
    });
    test('front only', () {
      expect(derivedOccupancy(_body(front: 1)).side, OccupancySide.front);
    });
    test('rear only, the lacing bar of docs/06 §3.2', () {
      final d = derivedOccupancy(_body(mount: MountMethod.rearRail, rear: 1));
      expect(d.side, OccupancySide.rear);
    });
    test('and it REPLACES a side that no longer fits, not only a blank', () {
      // DR-157 §11.156.5 only ever filled `none`, which is why typing a
      // rear height after the front one left `Front only` standing.
      final d = derivedOccupancy(
        _body(front: 2, rear: 2, side: OccupancySide.front),
      );
      expect(d.side, OccupancySide.both);
    });
  });

  group('a mount that takes no rack units has no height', () {
    for (final mount in [
      MountMethod.hosted,
      MountMethod.sideMount,
      MountMethod.furniture,
      MountMethod.notInRack,
    ]) {
      test('${mount.name} zeroes the heights and sits nowhere in the rack', () {
        final d = derivedOccupancy(_body(mount: mount, front: 2, rear: 2));
        expect((d.frontU, d.rearU, d.side), (0, 0, OccupancySide.none));
      });
    }
    test('a 0U mount is vertical in the rear channel, with no second step', () {
      // `0U mount` did not light Save until `Occupies` said 0U too.
      final d = derivedOccupancy(_body(mount: MountMethod.zeroU));
      expect(d.side, OccupancySide.zeroUVertical);
    });
  });

  group('the span follows the width class', () {
    test('half is 6, whatever was there', () {
      final d = derivedOccupancy(_body(width: WidthClass.half));
      expect(d.nominalSpanTwelfths, 6);
    });
    test('a custom width keeps the span somebody typed', () {
      final d = derivedOccupancy(
        _body(width: WidthClass.customWidth, span: 5),
      );
      expect(d.nominalSpanTwelfths, 5);
    });
  });

  group('hasMeantOccupancy, AC-049 third fact', () {
    test('a rack mount needs a height, front OR rear', () {
      expect(hasMeantOccupancy(_body()), isFalse);
      expect(hasMeantOccupancy(_body(front: 1)), isTrue);
      expect(
        hasMeantOccupancy(_body(mount: MountMethod.rearRail, rear: 1)),
        isTrue,
      );
    });
    test('a hosted card means its zero by being hosted', () {
      expect(hasMeantOccupancy(_body(mount: MountMethod.hosted)), isTrue);
    });
  });
}
