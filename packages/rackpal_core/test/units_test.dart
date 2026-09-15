import 'package:rackpal_core/rackpal_core.dart';
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
      // A LITERAL ON PURPOSE, and it is the point of the case: pinning
      // the version to `kSchemaVersion` would assert nothing at all. A
      // bump has to be a deliberate edit HERE, with a sentence saying
      // what moved, so a format change cannot arrive as a silent
      // constant.
      //
      // 2, not 1: the encoder stopped writing an explicit
      // `"outletsProvided": 0` for an unauthored outlet count and started
      // omitting the key, which a v1 reader cannot survive.
      //
      // 3, not 2: `PortDef.position` became NULLABLE with null meaning
      // "the layout is automatic" (DR-105 §11.104.3), and the encoder
      // stopped writing the origin on every port. A v2 reader calls
      // `asJsonMap` on the absent key and throws, so `minReaderVersion`
      // moved with it. See `constants.dart` and `migrateV2ToV3`.
      //
      // 4, not 3: `PortDef.carriedProtocols` was DELETED (DR-134
      // §11.133.5). The encoder wrote it unconditionally, so every file
      // on disk loses one key per port and stops re-encoding byte for
      // byte, which is this format's stated trigger for an advance.
      //
      // AND `minReaderVersion` STAYS AT 3, WHICH IS WHY THESE ARE TWO
      // LINES AND NOT ONE. It is the first time the pair has diverged. A
      // v3 reader meets the absent key with `?? const <Object?>[]` and
      // reads `[]`, which is the only value the field ever held in any
      // file, so it loses nothing and refusing it would be wrong.
      // 5, not 4: THE PLAN MODEL, AND THE FIRST ADVANCE THIS FORMAT HAS
      // MADE FOR A REASON THAT IS NOT ABOUT BYTES MOVING (DR-136
      // §11.135.3). Every plan addition is an optional key absent from
      // every file on disk, and the `underlays` map is OMITTED when
      // empty precisely so that stays true, so every existing file
      // re-encodes with the same content and only this stamp changes.
      // The advance is owed because `minReaderVersion` became
      // CONDITIONAL and the stamp it writes needs a number this build
      // declares as current: a document carrying a pin stamps
      // `kPlanMinReaderVersion` 5, and a build declaring 4 while writing
      // that stamp would refuse its own file.
      //
      // AND `minReaderVersion` STILL STAYS AT 3, for a different reason
      // from v4's. There the absent key was survivable; here the keys
      // are simply not present in an ordinary document at all, so it
      // opens everywhere. The document that carries plan data is the one
      // that stamps 5, and it stamps it from its CONTENT.
      //
      // 6, not 5: `PowerProfile.outletsProvided` and `outletsConsumed` were
      // DELETED (DR-171 §11.170.3). Every starter loses both keys from
      // every template body, and the hashes that attested those bodies
      // are re-taken, so files stop re-encoding byte for byte. And
      // `minReaderVersion` STAYS AT 3 again: a reader since v2 meets the
      // absent keys as unknown and loses nothing.
      expect(kSchemaVersion, equals(6));
      expect(kMinReaderVersion, equals(3));
      expect(kPlanMinReaderVersion, equals(5));
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

    test('the unit-less value forms carry NO suffix, and are the exact '
        'numeric prefix of the suffixed ones', () {
      // docs/04 §5's chip strip renders `148/200 lb` — two masses, one
      // trailing unit — so it needs the number without the unit. These
      // must stay the exact numeric prefix of the suffixed forms, or the
      // strip and the inspector would disagree about the same mass.
      //
      // EVERY EXPECTATION HERE IS A LITERAL. The last two used to read
      // `expect(m.toPounds(...), '${m.toPoundsValue(...)} lb')`, which is
      // `expect(s, s)` against an implementation that is literally
      // `'${toPoundsValue(...)} lb'` — changing `Mass.ugPerPound` or the
      // 1e9 kilogram divisor moved both sides together. Spelling the answer
      // out is what makes the divisor a thing this test can disagree with.
      expect(
        const Mass(453_592_370).toPoundsValue(fractionDigits: 3),
        equals('1.000'),
      );
      expect(const Mass(1_000_000_000).toKilogramsValue(), equals('1.00'));

      // 90_718_474_000 µg is 200 lb exactly (200 * Mass.ugPerPound) and
      // 90.718474 kg.
      const twoHundredPounds = Mass(90_718_474_000);
      expect(
        twoHundredPounds.toPoundsValue(fractionDigits: 1),
        equals('200.0'),
      );
      expect(twoHundredPounds.toPounds(fractionDigits: 1), equals('200.0 lb'));
      expect(twoHundredPounds.toKilogramsValue(), equals('90.72'));
      expect(twoHundredPounds.toKilograms(), equals('90.72 kg'));
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
