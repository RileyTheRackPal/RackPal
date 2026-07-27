// draw/sheet/revision_block.dart — section 5.3.
//
// The load-bearing assertions here are about what the block does when
// there is NO history, because that is the normal case in this build: no
// `RevisionEntry` generator exists. An exporter that fabricates
// `A · today · Initial issue` would be inventing project history, and an
// exporter that draws eight blank rows would be printing a form nobody
// filled in.

import 'dart:io';

import 'package:rackmate_core/rackmate_core.dart';
import 'package:test/test.dart';

import 'sheet_test_support.dart';

DBox boxFor(List<RevisionEntry> revisions) => SheetLayout.resolve(
  geometry: const SheetGeometry(SheetSize.ansiBPortrait),
  revisionRowCount: revisionBodyRowCount(revisions),
).revisionBlockBox!;

List<DiagramOp> build(List<RevisionEntry> revisions) => buildRevisionBlockLayer(
  box: boxFor(revisions),
  revisions: revisions,
  measurer: FakeMeasurer(),
).ops;

void main() {
  group('row counting', () {
    test('an empty list still needs one body row', () {
      expect(revisionBodyRowCount(const <RevisionEntry>[]), 1);
    });

    test('one to eight entries need exactly that many rows', () {
      for (var n = 1; n <= 8; n++) {
        final entries = <RevisionEntry>[
          for (var i = 0; i < n; i++) testRevision('R$i', i + 1),
        ];
        expect(revisionBodyRowCount(entries), n, reason: '$n entries');
      }
    });

    test('above eight, the newest eight plus one overflow row', () {
      final entries = <RevisionEntry>[
        for (var i = 0; i < 12; i++) testRevision('R$i', i + 1),
      ];
      expect(revisionBodyRowCount(entries), 9);
    });

    test('the maximum visible is the eight the doc names', () {
      expect(kMaxVisibleRevisions, 8);
      expect(kRevisionRowHeight, 13.0);
    });
  });

  group('with no revisions at all', () {
    final ops = build(const <RevisionEntry>[]);

    test('prints one sentence, not a blank grid', () {
      final texts = textsOf(ops);
      expect(texts, contains(kNoRevisionsText));
      expect(
        texts.where((t) => t == kNoRevisionsText),
        hasLength(1),
        reason: 'exactly one, not one per empty row',
      );
    });

    test('emits only the column header plus that one sentence', () {
      expect(textsOf(ops), <String>[
        'REV',
        'DATE',
        'DESCRIPTION',
        'BY',
        kNoRevisionsText,
      ]);
    });

    test('fabricates nothing that looks like history', () {
      final joined = textsOf(ops).join(' ');
      expect(joined, isNot(contains('Initial issue')));
      // No date is invented for a revision that does not exist.
      expect(joined, isNot(matches(RegExp(r'\d{4}-\d{2}-\d{2}'))));
    });
  });

  group('with real entries', () {
    final entries = <RevisionEntry>[
      testRevision('A', 1, description: 'Issued for review'),
      testRevision('B', 8, description: 'Added SW-2'),
      testRevision('C', 18, description: 'Added AMP-2, 4 runs to Zone 3'),
    ];
    final ops = build(entries);

    test('draws every entry with its four fields', () {
      final texts = textsOf(ops);
      for (final entry in entries) {
        expect(texts, contains(entry.revision));
        expect(texts, contains(entry.description));
      }
      expect(texts, contains('2026-07-18'));
      expect(texts.where((t) => t == 'JS'), hasLength(3));
    });

    test('stacks UPWARD: the header is lowest, the newest entry highest', () {
      double yOf(String text) =>
          textOps(ops).firstWhere((o) => o.text == text).at.y;

      final header = yOf('REV');
      final oldest = yOf('A');
      final middle = yOf('B');
      final newest = yOf('C');

      expect(newest, lessThan(middle));
      expect(middle, lessThan(oldest));
      expect(oldest, lessThan(header));
    });

    test('the newest label is what the REV field of the title block '
        'resolves from', () {
      expect(newestRevisionLabel(entries), 'C');
      expect(newestRevisionLabel(const <RevisionEntry>[]), isNull);
    });

    test('order comes from the DATE, not the list order it arrived in', () {
      final shuffled = <RevisionEntry>[entries[2], entries[0], entries[1]];
      expect(newestRevisionLabel(shuffled), 'C');
      expect(
        visibleRevisions(shuffled).map((e) => e.revision),
        <String>['A', 'B', 'C'],
      );
    });
  });

  group('overflow above eight entries', () {
    final entries = <RevisionEntry>[
      for (var i = 1; i <= 12; i++)
        testRevision('R${i.toString().padLeft(2, '0')}', i),
    ];
    final ops = build(entries);
    final texts = textsOf(ops);

    test('shows the NEWEST eight', () {
      for (var i = 5; i <= 12; i++) {
        expect(texts, contains('R${i.toString().padLeft(2, '0')}'));
      }
    });

    test('drops the oldest four from the grid', () {
      for (var i = 1; i <= 4; i++) {
        expect(texts, isNot(contains('R${i.toString().padLeft(2, '0')}')));
      }
    });

    test('says how many are hidden, and points at the project file rather '
        'than at a sheet that is not in this set', () {
      expect(texts, contains('+4 EARLIER REVISIONS — SEE PROJECT FILE'));
      // T0.00 is an M6 sheet. The wording in section 5.3 would point a
      // reader at a sheet the file does not contain.
      expect(texts.join(' '), isNot(contains('T0.00')));
    });

    test('singular wording for exactly one hidden revision', () {
      expect(overflowRevisionText(1), startsWith('+1 EARLIER REVISION —'));
      expect(overflowRevisionText(2), startsWith('+2 EARLIER REVISIONS —'));
    });
  });

  group('structural invariants', () {
    for (final count in <int>[0, 1, 3, 8, 12]) {
      final entries = <RevisionEntry>[
        for (var i = 1; i <= count; i++) testRevision('R$i', i),
      ];
      final box = boxFor(entries);
      final layer = buildRevisionBlockLayer(
        box: box,
        revisions: entries,
        measurer: FakeMeasurer(),
      );

      test('$count entries: no empty text op is ever emitted', () {
        expect(textsOf(layer.ops).where((t) => t.isEmpty), isEmpty);
      });

      test('$count entries: all ink stays inside the block', () {
        final ink = inkBoundsOf(layer.ops, measurer: FakeMeasurer())!;
        final allowed = box.inflate(1);
        expect(ink.left, greaterThanOrEqualTo(allowed.left));
        expect(ink.right, lessThanOrEqualTo(allowed.right));
        expect(ink.top, greaterThanOrEqualTo(allowed.top));
        expect(ink.bottom, lessThanOrEqualTo(allowed.bottom));
      });

      test('$count entries: every row band is 13 pt', () {
        expect(box.height, (revisionBodyRowCount(entries) + 1) * 13.0);
      });
    }

    test('a description too long for its column is truncated, not run '
        'over', () {
      final entries = <RevisionEntry>[
        testRevision('A', 1, description: 'X' * 400),
      ];
      final layer = buildRevisionBlockLayer(
        box: boxFor(entries),
        revisions: entries,
        measurer: FakeMeasurer(),
      );
      final drawn = textsOf(layer.ops).firstWhere((t) => t.startsWith('X'));

      expect(drawn.length, lessThan(400));
      expect(drawn, endsWith(kEllipsis));
    });
  });

  group('CR-094: the sync cursor is never used as revision history', () {
    test('revision_block.dart never mentions RackDocument.sequence', () {
      // `RackDocument.sequence` is the strictly-monotonic sync cursor and
      // is explicitly never called "revision". Backfilling a revision block
      // from a transaction counter would produce a number that looks like
      // history and is not — so the ban is asserted against the source
      // rather than left to reviewer memory.
      final source = File(
        'lib/src/draw/sheet/revision_block.dart',
      ).readAsStringSync();
      final code = source
          .split('\n')
          .where((line) => !line.trimLeft().startsWith('//'))
          .join('\n');

      expect(code, isNot(contains('sequence')));
    });
  });
}
