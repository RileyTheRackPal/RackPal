// M3-F/6 (#652), docs/07 §5.1, §5.2, DR-025 §11.24.
//
// ═══════════════════════════════════════════════════════════════════════
// WHAT THE ROW BECOMES, AND WHAT IT REFUSES TO BECOME
// ═══════════════════════════════════════════════════════════════════════
// Two rules are doing all the work here and they pull in opposite
// directions, which is why each has its own group.
//
// §5.3: import is never fail-fast, so an unreadable cell makes ONE FIELD
// unknown and the row still imports. G4: unknown is unknown, so that
// field is absent rather than zero, and a rollup counts it.
//
// The cases that earn their place are the ones a reasonable
// implementation gets wrong while passing every happy-path test: a bad
// quantity read as zero drops instead of one, an as-pulled colour
// promoted into the convention column, a colour word snapped to the
// nearest entry, and a signal family invented from a typo.
import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

final Registries _registries = buildSeedRegistries();

ProjectSettings _settings() => ProjectSettings(
  jacketColorConventions: {
    const JacketColorId('jc.blue'): const JacketColorDef(
      displayName: 'Blue',
      abbr: 'BLU',
      color: Rgb(0x1F, 0x5F, 0xA8),
    ),
    const JacketColorId('jc.yellow'): const JacketColorDef(
      displayName: 'Yellow',
      abbr: 'YEL',
      color: Rgb(0xEF, 0xC8, 0x1E),
    ),
  },
);

List<ResolvedCsvRow> _rows(String text, {ProjectSettings? settings}) {
  final read = readCsv(text);
  final table = switch (read) {
    CsvReadOk(:final table) => table,
    CsvReadRefused(:final message) => fail('refused: $message'),
  };
  return resolveCsvRows(
    table: table,
    mapping: CsvMapping.guess(
      table: table,
      detection: detectCsvShape(table, _registries),
      registries: _registries,
    ),
    registries: _registries,
    settings: settings ?? _settings(),
  );
}

ResolvedCsvRow _row(String text, {ProjectSettings? settings}) =>
    _rows(text, settings: settings).single;

void main() {
  group('the long shape', () {
    test('one row is one item of the quantity it states', () {
      final r = _row('Room,Cable Type,Qty\nLiving Room,Cat6,2\n');
      expect(r.locationName, 'Living Room');
      expect(r.items.single.count, 2);
      expect(
        r.items.single.media,
        isA<ResolvedMediaKnown>().having(
          (m) => m.id,
          'id',
          const MediaTypeId('media.cat6'),
        ),
      );
      expect(r.issues, isEmpty);
    });

    test('an absent quantity means one (§5.1)', () {
      expect(_row('Room,Cable Type\nA,Cat6\n').items.single.count, 1);
    });

    test('an UNREADABLE quantity also means one, and says so', () {
      // Not zero. A row that named a cable is a drop, and reading "two
      // or three" as zero would delete a run the sheet says exists.
      final r = _row('Room,Cable Type,Qty\nA,Cat6,two or three\n');
      expect(r.items.single.count, 1);
      expect(r.warningCount, 1);
      expect(r.hasError, isFalse);
    });

    test('an explicit zero creates nothing', () {
      expect(_row('Room,Cable Type,Qty\nA,Cat6,0\n').items, isEmpty);
    });

    test('RJ-012: an unknown cable is a NEW type, never a rejected row', () {
      final r = _row('Room,Cable Type\nA,Unobtainium 9\n');
      expect(
        r.items.single.media,
        isA<ResolvedMediaNew>().having(
          (m) => m.token,
          'token',
          'Unobtainium 9',
        ),
      );
      expect(r.hasError, isFalse);
    });

    test('a row naming no cable creates no drop and is not an error', () {
      final r = _row('Room,Cable Type\nA,\n');
      expect(r.items, isEmpty);
      expect(r.hasError, isFalse);
      expect(r.warningCount, 1);
    });
  });

  group('the wide shape', () {
    test('one row becomes one item per cable column', () {
      final r = _row('Room,Cat6,RG6\nLiving Room,4,2\n');
      expect(r.items.length, 2);
      expect(r.items[0].count, 4);
      expect(r.items[1].count, 2);
    });

    test('a blank cell is no drops, and so is a zero', () {
      // What a wide sheet means by leaving the speaker column empty.
      // `csv_reader` deliberately did not answer this; here is where it
      // is answered.
      //
      // Both fixtures carry a second row so the RG6 column holds a
      // number somewhere: an entirely blank column is evidence of
      // nothing and does not make a sheet wide, which is the reader's
      // rule and not this layer's.
      final blank = _rows('Room,Cat6,RG6\nA,4,\nB,1,2\n');
      expect(blank[0].items.single.count, 4);
      final zero = _rows('Room,Cat6,RG6\nA,4,0\nB,1,2\n');
      expect(zero[0].items.length, 1);
    });

    test('a row where every cable column is blank is still a row', () {
      final rows = _rows('Room,Cat6,RG6\nA,4,2\nB,,\n');
      expect(rows.length, 2);
      expect(rows[1].items, isEmpty);
      expect(rows[1].hasError, isFalse);
    });
  });

  group('the one thing that is an error', () {
    test('a row with no room cannot be placed', () {
      final r = _row('Room,Cable Type\n,Cat6\n');
      expect(r.hasError, isTrue);
      expect(r.issues.single.severity, CsvIssueSeverity.error);
    });

    test('and everything else is a warning that leaves a field unknown', () {
      final r = _row(
        'Room,Cable Type,Length,Status,Termination Field\n'
        'A,Cat6,sixty two,soon,welded\n',
      );
      expect(r.hasError, isFalse);
      expect(r.warningCount, 3);
      // G4: unknown, not zero and not a default.
      expect(r.routedLength, isNull);
      expect(r.roughInStatus, isNull);
      expect(r.terminationField, isNull);
      // The row still becomes a drop.
      expect(r.items.single.count, 1);
    });
  });

  group('words that name enum values', () {
    test('the §5.2 spelling `F barrel` reaches fBarrel', () {
      final r = _row('Room,Cable Type,Panel Port\nA,RG6,F barrel\n');
      expect(r.rackTermination, TerminationType.fBarrel);
      expect(r.issues, isEmpty);
    });

    test('status words are case-insensitive', () {
      expect(
        _row('Room,Cable Type,Status\nA,Cat6,PULLED\n').roughInStatus,
        RoughInStatus.pulled,
      );
    });

    test('the two termination ends resolve independently', () {
      final r = _row(
        'Room,Cable Type,Panel Port,Far End\nA,Cat6,punchdown,keystone\n',
      );
      expect(r.rackTermination, TerminationType.punchdown);
      expect(r.terminationField, TerminationType.keystone);
    });
  });

  group('DR-025: the family is stated deliberately or not at all', () {
    test('a `Use` column feeds the label chain and NEVER the family', () {
      // §11.24.4. Real pull lists put `Ethernet` here and it names a
      // template, not an electrical fact the DRC reads.
      final r = _row('Room,Cable Type,Use\nA,Cat6,HDBaseT\n');
      expect(r.serviceToken, 'HDBaseT');
      expect(r.signalFamily, isNull);
    });

    test("a `signal` column sets it, by all three of §11.24.3's ways in", () {
      SignalFamilyId? of(String cell) =>
          _row('Room,Cable Type,Signal\nA,Cat6,$cell\n').signalFamily;
      // shortTag, then the id's own tail. Both of DR-025's worked
      // examples for this family.
      expect(of('hbt'), const SignalFamilyId('video.hdbaset'));
      expect(of('hdbaset'), const SignalFamilyId('video.hdbaset'));
      expect(of('avoip'), const SignalFamilyId('video.avoip'));
    });

    test('an unresolved family REFUSES and never invents one', () {
      // The opposite of RJ-012's rule for media, and already ruled:
      // docs/07 §3 keeps families catalog-updated. A family from a typo
      // would have no domain, no colour and no dash.
      final r = _row('Room,Cable Type,Signal\nA,Cat6,hdbaset2\n');
      expect(r.signalFamily, isNull);
      expect(r.warningCount, 1);
      expect(r.hasError, isFalse);
    });
  });

  group("§5.1's two jacket columns", () {
    test('a convention word resolves by abbr or by name, either case', () {
      expect(
        _row('Room,Cable Type,Color\nA,Cat6,BLU\n').jacketColor,
        const JacketColorId('jc.blue'),
      );
      expect(
        _row('Room,Cable Type,Color\nA,Cat6,blue\n').jacketColor,
        const JacketColorId('jc.blue'),
      );
    });

    test('a word naming no entry is KEPT as a dangling id and counted', () {
      // Never dropped and never snapped to the nearest entry: the id is
      // the one record that a particular colour went in a particular
      // wall, and it must outlive the entry naming it.
      final r = _row('Room,Cable Type,Color\nA,Cat6,Chartreuse\n');
      expect(r.jacketColor, const JacketColorId('Chartreuse'));
      expect(r.warningCount, 1);
    });

    test('the two columns import independently', () {
      final r = _row(
        'Room,Cable Type,Color,As Pulled\nA,Cat6,BLU,YEL\n',
      );
      expect(r.jacketColor, const JacketColorId('jc.blue'));
      expect(r.jacketColorPulled, const JacketColorId('jc.yellow'));
    });

    test('an as-pulled colour alone is NOT promoted to the convention', () {
      // Promoting it would assert a purpose nobody stated (G4).
      final r = _row('Room,Cable Type,As Pulled\nA,Cat6,YEL\n');
      expect(r.jacketColor, isNull);
      expect(r.jacketColorPulled, const JacketColorId('jc.yellow'));
    });

    test(
      'an as-pulled colour EQUAL to the convention normalises to absent',
      () {
        // So an exceptions count can never be inflated by a no-op import.
        final r = _row('Room,Cable Type,Color,As Pulled\nA,Cat6,BLU,Blue\n');
        expect(r.jacketColor, const JacketColorId('jc.blue'));
        expect(r.jacketColorPulled, isNull);
      },
    );
  });

  group('nothing is discarded', () {
    test('an unmapped column lands in `unknown` under its header', () {
      final r = _row('Room,Cable Type,Reel\nA,Cat6,R-42\n');
      expect(r.unknown, {'Reel': 'R-42'});
    });

    test('an EMPTY cell writes no key at all', () {
      // G4 and CR-117 agree: an absent key is unknown, and writing `''`
      // would make a blank cell a stated fact.
      expect(_row('Room,Cable Type,Reel\nA,Cat6,\n').unknown, isEmpty);
    });

    test("a ragged row's overflow is kept, and flagged", () {
      final r = _row('Room,Cable Type\nA,Cat6,stray\n');
      expect(r.unknown, {'overflow 3': 'stray'});
      expect(r.warningCount, 1);
    });
  });

  group("docs/07 §5.2's worked example, resolved", () {
    // The seven rows the spec prints, read end to end. Anything that
    // silently changes the meaning of that file breaks here.
    List<ResolvedCsvRow> rows() => _rows(
      'Room,Outlet,Cable Type,Qty,Use,Bundle,Length,Panel Port,Status,Notes\n'
      'Living Room,WP-1,Cat6,2,Ethernet,LR-TV,62,PP-1 R01,pulled,\n'
      'Living Room,WP-1,Cat6,1,HDBaseT,LR-TV,62,,pulled,to TV\n'
      'Living Room,WP-1,RG6,2,CATV,LR-TV,62,F barrel,pulled,\n'
      'Living Room,CLG,16/4,2,Speaker,LR-AUD,48,,pulled,ceiling pair\n'
      'Attic,AP-1,Cat6,1,Ethernet,,88,PP-1 R14,terminated,AP over hall\n'
      'Exterior,CAM-1..6,Cat6,6,Camera,EXT-1,120,PP-2 R01,planned,soffit\n'
      'Office,,ENT,1,,,,,planned,pull string only\n',
    );

    test('all seven rows import and none is an error', () {
      final rs = rows();
      expect(rs.length, 7);
      expect(rs.every((r) => !r.hasError), isTrue);
    });

    test('the §5.2 sentence: row 2 is three drops sharing one outlet', () {
      final rs = rows();
      expect(rs[0].items.single.count, 2);
      expect(rs[1].items.single.count, 1);
      expect(rs[0].outletDesignation, 'WP-1');
      expect(rs[1].outletDesignation, 'WP-1');
    });

    test('the blank Panel Port is UNKNOWN, not a termination', () {
      expect(rows()[1].rackTermination, isNull);
      expect(rows()[2].rackTermination, TerminationType.fBarrel);
    });

    test('the pathway-only last row still resolves its media', () {
      // CR-109 makes this a `Pathway` rather than a drop, and that is
      // the planner's decision; this layer only says which media it is.
      final last = rows()[6];
      expect(
        last.items.single.media,
        isA<ResolvedMediaKnown>().having(
          (m) => m.id,
          'id',
          const MediaTypeId('media.conduit_ent'),
        ),
      );
      expect(last.outletDesignation, isNull);
      expect(last.roughInStatus, RoughInStatus.planned);
    });

    test('every Use value stays a token and sets no family', () {
      expect(rows().map((r) => r.serviceToken).toList(), [
        'Ethernet',
        'HDBaseT',
        'CATV',
        'Speaker',
        'Ethernet',
        'Camera',
        null,
      ]);
      expect(rows().every((r) => r.signalFamily == null), isTrue);
    });
  });
}
