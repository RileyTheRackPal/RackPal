// M3-F/1 (#159), docs/07 §5.1, RJ-004.
//
// ═══════════════════════════════════════════════════════════════════════
// THE CAP IS THE DELIVERABLE, SO THE GATE IS THE TEST THAT MATTERS
// ═══════════════════════════════════════════════════════════════════════
// The roadmap names CSV synonym mapping as M3's scope hazard: "an
// INFINITE-TAIL feature; cap it at the shipped synonym table". A test
// that only checked the table's own entries would pass on a matcher that
// had grown edit distance, stemming or a learning step underneath it.
//
// So the load-bearing case here is the NEGATIVE one: a matcher must
// answer null for every plausible header outside the table, including
// the ones a fuzzy matcher would obviously "get right". Each of those is
// a feature request this project has already declined, and the test is
// what makes declining it stick.
import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

void main() {
  group('the table matches what docs/07 §5.1 says it matches', () {
    test('the four transforms, one at a time and all at once', () {
      // Case, space, underscore, hyphen. §5.1's whole normalisation.
      expect(matchCsvHeader('Room'), CsvColumnTarget.location);
      expect(matchCsvHeader('CABLE TYPE'), CsvColumnTarget.media);
      expect(matchCsvHeader('cable_type'), CsvColumnTarget.media);
      expect(matchCsvHeader('cable-type'), CsvColumnTarget.media);
      expect(matchCsvHeader('  Cable_Type  '.trim()), CsvColumnTarget.media);
      expect(matchCsvHeader('WALL_PLATE-ID'), CsvColumnTarget.outlet);
    });

    test("docs/07 §5.2's own example header row, column by column", () {
      // The spec's worked example is the closest thing to a real pull
      // list in the corpus, so it is the fixture with the most claim on
      // being right.
      const header = [
        'Room',
        'Outlet',
        'Cable Type',
        'Qty',
        'Use',
        'Bundle',
        'Length (ft)',
        'Panel Port',
        'Status',
        'Notes',
      ];
      expect(header.map(matchCsvHeader).toList(), <CsvColumnTarget?>[
        CsvColumnTarget.location,
        CsvColumnTarget.outlet,
        CsvColumnTarget.media,
        CsvColumnTarget.qty,
        CsvColumnTarget.service,
        CsvColumnTarget.pathway,
        // `Length (ft)` DOES NOT MATCH, and that is the design rather
        // than a miss. Parentheses are not one of §5.1's four transforms,
        // and stripping a parenthesised unit is a guess that `(ft)` is
        // decoration. It routes to the manual assign step (M3-F/2), which
        // is one click and is not silent (G4).
        null,
        CsvColumnTarget.rackTermination,
        CsvColumnTarget.roughInStatus,
        CsvColumnTarget.notes,
      ]);
    });

    test('the two jacket columns are DIFFERENT targets', () {
      // §5.1: they import independently, and an as-pulled value is never
      // promoted into the convention column, because that would assert a
      // purpose nobody stated (G4).
      expect(matchCsvHeader('Jacket Color'), CsvColumnTarget.jacketColor);
      expect(matchCsvHeader('colour'), CsvColumnTarget.jacketColor);
      expect(
        matchCsvHeader('as_pulled'),
        CsvColumnTarget.jacketColorPulled,
      );
      expect(
        matchCsvHeader('Actual Color'),
        CsvColumnTarget.jacketColorPulled,
      );
    });

    test('`#` survives normalisation, because none of the four transforms '
        'touch it', () {
      expect(matchCsvHeader('#'), CsvColumnTarget.fieldLabel);
    });

    test('the table is stored already-normalised, so no entry can be '
        'unreachable', () {
      // A key with a capital or a hyphen in it would never be looked up,
      // and would look correct in a diff forever.
      for (final key in kCsvHeaderSynonyms.keys) {
        expect(
          normaliseCsvHeader(key),
          key,
          reason: '"$key" is not in normalised form, so nothing can match it',
        );
      }
    });
  });

  group('THE CAP: everything outside the table answers null', () {
    test('a header nobody has heard of', () {
      expect(matchCsvHeader('Sprocket Alignment'), isNull);
      expect(matchCsvHeader(''), isNull);
    });

    test('NO FUZZY MATCHING: near-misses of real entries are refused', () {
      // Each of these is one edit away from a table entry and a fuzzy
      // matcher would answer for all of them. Answering is the failure.
      const nearMisses = [
        'rooms', // plural of `room`
        'locations', // plural of `location`
        'roomm', // transposition
        'labl', // deletion
        'quantityy', // insertion
        'jaket', // deletion inside `jacket`
        'pathwayss',
        'cabl', // prefix of `cable`
        'note s', // normalises to `notes`? no: space is stripped -> `notes`
      ];
      for (final header in nearMisses.take(nearMisses.length - 1)) {
        expect(
          matchCsvHeader(header),
          isNull,
          reason: '"$header" is outside the table and must not be guessed at',
        );
      }
      // The last one is deliberately NOT a near miss: `note s` normalises
      // to `notes`, which IS in the table. Kept in the list to make the
      // point that normalisation is not matching, and that the four
      // transforms are exactly why this one is legitimate.
      expect(matchCsvHeader('note s'), CsvColumnTarget.notes);
    });

    test('NO SUBSTRING MATCHING: a header CONTAINING an entry is refused', () {
      // The other obvious cheap heuristic, and the one that produces the
      // worst failures: `Cable Length Notes` contains `cable`, `length`
      // and `notes`, and any substring matcher would pick one of the
      // three by an ordering nobody chose.
      expect(matchCsvHeader('Cable Length Notes'), isNull);
      expect(matchCsvHeader('Room Number'), isNull);
      expect(matchCsvHeader('Outlet Type Code'), isNull);
    });

    test('MEDIA TOKENS ARE NOT COLUMN HEADERS, and this table must not '
        'answer for one', () {
      // `MediaTypeDef.aliases` carries `cat6`, `rg6`, `16/4` and the rest
      // as DOCUMENT data (DR-010, RJ-009). Answering for them here would
      // be a second hard-coded copy that goes stale the first time a shop
      // adds a media type, and it would confuse "which column is this"
      // with "which cable is this cell".
      for (final token in ['cat6', 'rg6', '16/4', 'os2', 'c6a']) {
        expect(
          matchCsvHeader(token),
          isNull,
          reason: '"$token" is a media alias and belongs to the registry',
        );
      }
    });

    test('every canonical target is reachable, so no enum value is dead', () {
      // The mirror of the cap: the table must not have gaps either. A
      // target with no synonym is a column the mapping sheet offers and
      // nothing ever guesses.
      final reachable = kCsvHeaderSynonyms.values.toSet();
      for (final target in CsvColumnTarget.values) {
        expect(
          reachable,
          contains(target),
          reason: '$target has no header synonym, so nothing can map to it',
        );
      }
    });
  });

  test('the long shape requires a location and a media column', () {
    // §5.1's `Req.` column. Media is required in the LONG shape only:
    // the wide shape carries media in its headers, which is what makes it
    // a different shape rather than a different parser.
    expect(kRequiredLongShapeTargets, {
      CsvColumnTarget.location,
      CsvColumnTarget.media,
    });
  });
}
