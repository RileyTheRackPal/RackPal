import 'package:rackmate_core/rackmate_core.dart';
import 'package:test/test.dart';

void main() {
  group('Len — nanometre exactness (AC-001)', () {
    test('1/32 inch inter-panel clearance is exact', () {
      const thirtySecond = Len(793_750);
      expect(thirtySecond.nm, equals(793750));

      final summed = Len.sum(List.filled(32, thirtySecond));
      expect(summed, equals(const Len(25_400_000)));
      expect(summed.nm, equals(Len.nmPerInch));
    });

    test('zero accumulated error across a 45U rack stack', () {
      final summed = Len.sum(List.filled(45, kRackUnit));
      expect(summed, equals(const Len(44_450_000 * 45)));
      expect(summed.nm, equals(44_450_000 * 45));
    });

    test('arithmetic operators are exact integer math', () {
      const a = Len(1000);
      const b = Len(500);
      expect((a + b).nm, 1500);
      expect((a - b).nm, 500);
      expect((-a).nm, -1000);
      expect((a * 3).nm, 3000);
      expect(b < a, isTrue);
      expect(a >= b, isTrue);
    });
  });

  group('Mass', () {
    test('1 lb is exactly 453 592 370 ug', () {
      const pound = Mass(453_592_370);
      expect(pound.ug, equals(Mass.ugPerPound));
    });

    test('Mass.sum is exact', () {
      final total = Mass.sum([
        const Mass(100),
        const Mass(200),
        const Mass(300),
      ]);
      expect(total, equals(const Mass(600)));
    });
  });

  group('Permille', () {
    test('arithmetic', () {
      const a = Permille(650);
      const b = Permille(350);
      expect(a + b, equals(Permille.whole));
      expect((a - b).v, 300);
      expect(a > b, isTrue);
      expect(b < a, isTrue);
    });

    test('toFraction is display-only', () {
      expect(const Permille(650).toFraction(), closeTo(0.65, 1e-9));
    });
  });

  group('Pt', () {
    test('equality and arithmetic', () {
      const p1 = Pt(1, 2);
      const p2 = Pt(1, 2);
      const p3 = Pt(3, 4);
      expect(p1, equals(p2));
      expect(p1.hashCode, equals(p2.hashCode));
      expect(p1 + p3, equals(const Pt(4, 6)));
      expect(p3 - p1, equals(const Pt(2, 2)));
    });
  });

  group('Box', () {
    test('fromCorners normalises order', () {
      final box = Box.fromCorners(const Pt(5, 5), const Pt(0, 0));
      expect(box.gx0, 0);
      expect(box.gy0, 0);
      expect(box.gx1, 5);
      expect(box.gy1, 5);
      expect(box.width, 5);
      expect(box.height, 5);
    });

    test('contains', () {
      const box = Box.fromLtwh(0, 0, 10, 10);
      expect(box.contains(const Pt(5, 5)), isTrue);
      expect(box.contains(const Pt(11, 5)), isFalse);
    });

    test('inflate grows symmetrically', () {
      const box = Box.fromLtwh(0, 0, 10, 10);
      final inflated = box.inflate(2);
      expect(inflated, equals(const Box.fromLtwh(-2, -2, 14, 14)));
    });

    test('union', () {
      const a = Box.fromLtwh(0, 0, 5, 5);
      const b = Box.fromLtwh(3, 3, 5, 5);
      expect(a.union(b), equals(const Box.fromLtwh(0, 0, 8, 8)));
    });
  });

  group('Rgb', () {
    test('hex round-trip, opaque', () {
      const color = Rgb(0x1A, 0x2B, 0x3C);
      expect(color.toHex(), equals('#1A2B3C'));
      expect(Rgb.fromHex('#1A2B3C'), equals(color));
    });

    test('hex round-trip, alpha-aware', () {
      const color = Rgb(0x1A, 0x2B, 0x3C, a: 0x80);
      expect(color.toHexArgb(), equals('#801A2B3C'));
      expect(Rgb.fromHex('#801A2B3C'), equals(color));
    });
  });

  group('Constants (docs/02-data-model.md §3.1)', () {
    test('kRackUnit and kGridUnit match spec', () {
      expect(kRackUnit, equals(const Len(44_450_000)));
      expect(kGridUnit, equals(const Len(2_500_000)));
      expect(kPinPitch, equals(2));
      expect(kBankCollapseThreshold, equals(8));
      expect(kMaxRackHeightU, equals(60));
      expect(kSchemaVersion, equals(1));
    });
  });

  group('UnitFormatter', () {
    test('Len.toMillimeters', () {
      expect(kGridUnit.toMillimeters(fractionDigits: 1), equals('2.5 mm'));
    });

    test('Len.toFeetInches exact inch', () {
      expect(const Len(25_400_000).toFeetInches(), equals("0' 1\""));
    });

    test('Mass.toPounds exact at 1 lb', () {
      expect(
        const Mass(453_592_370).toPounds(fractionDigits: 3),
        equals('1.000 lb'),
      );
    });

    test('UnitFormatter static entry points delegate to the extensions', () {
      expect(
        UnitFormatter.lenToMillimeters(kGridUnit, fractionDigits: 1),
        equals(kGridUnit.toMillimeters(fractionDigits: 1)),
      );
      expect(
        UnitFormatter.massToPounds(const Mass(453_592_370)),
        equals(const Mass(453_592_370).toPounds()),
      );
    });
  });
}
