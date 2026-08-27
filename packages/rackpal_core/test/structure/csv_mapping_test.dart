// M3-F/6 (#652), docs/07 §5.1.
//
// ═══════════════════════════════════════════════════════════════════════
// THE MAPPING IS WHAT THE OPERATOR SEES, SO THE TESTS ARE ABOUT THEM
// ═══════════════════════════════════════════════════════════════════════
// Every case here is a spreadsheet somebody exported and a question the
// mapping sheet then has to ask about it: two columns fighting over one
// field, a required column nobody supplied, a blank header, a wide sheet
// with a quantity column that has nothing to multiply.
//
// The negative cases carry the weight. A mapping that quietly resolves a
// conflict, silently unclaims a target or writes two columns into one
// `unknown` key is a mapping that loses data without saying so, and each
// of those is a plausible implementation.
import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

final Registries _registries = buildSeedRegistries();

CsvTable _table(String text) {
  final read = readCsv(text);
  return switch (read) {
    CsvReadOk(:final table) => table,
    CsvReadRefused(:final message) => fail('refused: $message'),
  };
}

CsvMapping _guess(String text) {
  final table = _table(text);
  return CsvMapping.guess(
    table: table,
    detection: detectCsvShape(table, _registries),
    registries: _registries,
  );
}

void main() {
  group('the guess is #159 and nothing else', () {
    test('known headers map, unknown headers are kept', () {
      final m = _guess('Room,Cable Type,Length (ft),Widget\nA,Cat6,62,x\n');
      expect(m.assignments[0], const CsvColumnMapped(CsvColumnTarget.location));
      expect(m.assignments[1], const CsvColumnMapped(CsvColumnTarget.media));
      // The consequence #159 pinned, arriving where it actually bites.
      expect(m.assignments[2], const CsvColumnKept());
      expect(m.assignments[3], const CsvColumnKept());
      expect(m.keptColumns, [2, 3]);
    });

    test('the first column wins a contested target and the second is kept', () {
      // Not a silent overwrite. Guessing both onto one field would make
      // the second quietly win, which is what the sheet exists to
      // prevent.
      final m = _guess('Room,Cable Type,Notes,Comments\nA,Cat6,x,y\n');
      expect(m.assignments[2], const CsvColumnMapped(CsvColumnTarget.notes));
      expect(m.assignments[3], const CsvColumnKept());
      // A guess never produces a conflict; only an override can.
      expect(m.problems, isEmpty);
      expect(m.isComplete, isTrue);
    });
  });

  group('the operator can overrule it', () {
    test('an assignment replaces one column and touches no other', () {
      final m = _guess('Room,Widget\nA,x\n').withAssignment(
        1,
        const CsvColumnMapped(CsvColumnTarget.notes),
      );
      expect(m.assignments[0], const CsvColumnMapped(CsvColumnTarget.location));
      expect(m.columnFor(CsvColumnTarget.notes), 1);
    });

    test(
      'claiming a taken target REPORTS a conflict, never silently steals',
      () {
        // Demoting the previous holder would move a row of the sheet the
        // operator was not looking at.
        final m = _guess('Notes,Widget\na,b\n').withAssignment(
          1,
          const CsvColumnMapped(CsvColumnTarget.notes),
        );
        final problem = m.problems.singleWhere(
          (p) => p.kind == CsvMappingProblemKind.duplicateTarget,
        );
        expect(problem.columns, [0, 1]);
        expect(problem.blocks, isTrue);
        expect(m.isComplete, isFalse);
        // And nothing reads a contested target, rather than taking the
        // first of two.
        expect(m.columnFor(CsvColumnTarget.notes), isNull);
      },
    );

    test('the original mapping is unchanged by an override', () {
      final before = _guess('Room,Widget\nA,x\n');
      final after = before.withAssignment(
        1,
        const CsvColumnMapped(CsvColumnTarget.notes),
      );
      expect(before.assignments[1], const CsvColumnKept());
      expect(
        after.assignments[1],
        const CsvColumnMapped(CsvColumnTarget.notes),
      );
    });
  });

  group("§5.1's required columns", () {
    test('a long sheet needs a room and a cable', () {
      final m = _guess('Widget,Gadget\na,b\n');
      final missing = m.problems
          .where((p) => p.kind == CsvMappingProblemKind.missingRequired)
          .length;
      expect(missing, 2);
      expect(m.isComplete, isFalse);
    });

    test('a complete long sheet has nothing to report', () {
      expect(_guess('Room,Cable Type\nA,Cat6\n').isComplete, isTrue);
    });

    test('a wide sheet needs a room and NOT a media column', () {
      // The wide shape carries media in its headers, which is what makes
      // it a different shape rather than a different parser.
      final m = _guess('Room,Cat6,RG6\nA,4,2\n');
      expect(m.shape, CsvShape.wide);
      expect(m.requiredTargets, {CsvColumnTarget.location});
      expect(m.isComplete, isTrue);
    });
  });

  group('the wide shape names its cables', () {
    test('each count column carries the media id it resolved to', () {
      final m = _guess('Room,Cat6,RG6\nA,4,2\n');
      expect(m.mediaCountColumns.length, 2);
      expect(m.mediaCountColumns[0].column, 1);
      expect(m.mediaCountColumns[0].media, const MediaTypeId('media.cat6'));
      expect(m.mediaCountColumns[1].media, const MediaTypeId('media.rg6'));
    });

    test('a quantity column is reported and does NOT block', () {
      // The cells of the cable columns already carry the counts, so this
      // one has nothing to multiply. It is preserved, not obeyed.
      final m = _guess('Room,Qty,Cat6,RG6\nA,3,4,2\n');
      expect(m.shape, CsvShape.wide);
      final p = m.problems.single;
      expect(p.kind, CsvMappingProblemKind.quantityInWideShape);
      expect(p.blocks, isFalse);
      expect(m.isComplete, isTrue);
    });

    test('switching shape by hand redoes the guess for the cable columns', () {
      final table = _table('Room,Cat6,RG6\nA,4,2\n');
      final wide = CsvMapping.guess(
        table: table,
        detection: detectCsvShape(table, _registries),
        registries: _registries,
      );
      final long = wide.asShape(
        CsvShape.long,
        table: table,
        registries: _registries,
      );
      expect(long.shape, CsvShape.long);
      expect(long.mediaCountColumns, isEmpty);
      // And back again, without going through the detector.
      final again = long.asShape(
        CsvShape.wide,
        table: table,
        registries: _registries,
      );
      expect(again.mediaCountColumns.length, 2);
    });
  });

  group('every kept column gets a key, and no two get the same one', () {
    test('an ordinary sheet keys by its own headers', () {
      final m = _guess('Room,Widget,Gadget\nA,x,y\n');
      expect(m.unknownKeyFor(1), 'Widget');
      expect(m.unknownKeyFor(2), 'Gadget');
    });

    test('a repeated header disambiguates by column number', () {
      // Both would otherwise write one key and the second would win
      // silently.
      final m = _guess('Room,Widget,Widget\nA,x,y\n');
      expect(m.unknownKeyFor(1), 'Widget');
      expect(m.unknownKeyFor(2), 'Widget (3)');
    });

    test('a blank header is named rather than keyed as an empty string', () {
      final m = _guess('Room,,Gadget\nA,x,y\n');
      expect(m.unknownKeyFor(1), 'column 2');
    });
  });
}
