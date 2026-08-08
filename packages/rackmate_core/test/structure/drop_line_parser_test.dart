// M3-C/1, #147 — the drop DSL, docs/07 §4.3's command mode.
//
// THE FIRST GROUP IS THE ONE THAT MATTERS. docs/07 §4.3 prints four
// lines, and if this parser cannot read all four exactly as written then
// the entry surface the whole milestone rests on cannot type the
// corpus's own examples. They are asserted verbatim, character for
// character, before anything else is claimed.
//
// The rest exist because #147's own instruction is about a repeat loop
// that must not break: "60 drops in 15 minutes is ~15 seconds per drop
// INCLUDING thinking". A parser that refuses a line for a reason the
// person cannot act on costs more than one that is forgiving, so the
// refusals are tested for their SENTENCE and their CARET, not just for
// being refusals.
import 'package:rackmate_core/rackmate_core.dart';
import 'package:test/test.dart';

DropLineParsed _ok(String line) {
  final r = parseDropLine(line);
  expect(r, isA<DropLineParsed>(), reason: 'failed to parse: $line');
  return r as DropLineParsed;
}

DropLineMalformed _bad(String line) {
  final r = parseDropLine(line);
  expect(r, isA<DropLineMalformed>(), reason: 'unexpectedly parsed: $line');
  return r as DropLineMalformed;
}

/// `[(count, token), ...]`, which is what most assertions here care about.
List<(int, String)> _items(DropLineParsed p) => [
  for (final i in p.items) (i.count, i.mediaToken),
];

void main() {
  group("docs/07 §4.3's four lines, verbatim", () {
    test('line 1: four media, comma-separated, no modifiers', () {
      final p = _ok('Living Room: 4x Cat6, 2x RG6, 2x 16/4, 1x 22/4');

      expect(p.locationName, 'Living Room');
      expect(_items(p), [
        (4, 'Cat6'),
        (2, 'RG6'),
        (2, '16/4'),
        (1, '22/4'),
      ]);
      expect(p.dropCount, 9);
      expect(p.service, isNull);
      expect(p.status, isNull);
      expect(p.outletDesignation, isNull);
    });

    test('line 2: one media and a service', () {
      final p = _ok('Attic: 3x Cat6 @service=wifi-ap');

      expect(p.locationName, 'Attic');
      expect(_items(p), [(3, 'Cat6')]);
      expect(p.service, 'wifi-ap');
      expect(p.dropCount, 3);
    });

    test('line 3: two modifiers', () {
      final p = _ok('Exterior: 6x Cat6 @service=camera @status=planned');

      expect(p.locationName, 'Exterior');
      expect(p.service, 'camera');
      expect(p.status, 'planned');
      expect(p.dropCount, 6);
    });

    test('line 4: a plus separator and a QUOTED outlet designation', () {
      final p = _ok('Kitchen: 2x Cat6 + 1x RG6 @outlet="KIT-TV-1"');

      expect(p.locationName, 'Kitchen');
      expect(_items(p), [(2, 'Cat6'), (1, 'RG6')]);
      expect(p.outletDesignation, 'KIT-TV-1');
      expect(p.dropCount, 3);
    });
  });

  group('separators', () {
    test('a comma and a plus mean the same thing', () {
      // THE READING, ASSERTED. docs/07 uses both and never contrasts
      // them, and §4.3 gives the grouping job to `@outlet=` explicitly.
      // If `+` is ever ruled to group, this test is where it breaks and
      // the file header is where the reasoning is.
      expect(
        _items(_ok('Kitchen: 2x Cat6 + 1x RG6')),
        _items(_ok('Kitchen: 2x Cat6, 1x RG6')),
      );
    });

    test('a trailing separator is not an empty item', () {
      // Someone typing fast leaves one behind constantly.
      expect(_items(_ok('Attic: 3x Cat6,')), [(3, 'Cat6')]);
      expect(_items(_ok('Attic: 3x Cat6 + ')), [(3, 'Cat6')]);
    });
  });

  group('counts, aggressively (seed-devices §2.3)', () {
    test('4x, 4 x, 4X and 4× are all the same item', () {
      for (final form in const ['4x Cat6', '4 x Cat6', '4X Cat6', '4×Cat6']) {
        expect(_items(_ok('Attic: $form')), [(4, 'Cat6')], reason: form);
      }
    });

    test('a bare media token with no count is one drop', () {
      // Typing speed. `Attic: Cat6` is unambiguous and refusing it would
      // be pedantry in a surface whose entire purpose is entry rate.
      expect(_items(_ok('Attic: Cat6')), [(1, 'Cat6')]);
    });

    test('a media token may contain spaces, because real ones do', () {
      // docs/07 §5.1's own synonyms: `quad shield`, `cat6 utp`,
      // `spkr 16/2`, `single mode`.
      expect(_items(_ok('Attic: 2x quad shield')), [(2, 'quad shield')]);
      expect(_items(_ok('Attic: 1x single mode')), [(1, 'single mode')]);
    });

    test('the token keeps the spelling it was typed in', () {
      // Not lower-cased on the way in: the resolver folds case at the
      // point of comparison and needs the original for its refusal
      // sentence.
      expect(_items(_ok('Attic: 2x CAT6')), [(2, 'CAT6')]);
    });

    test('a large count parses rather than overflowing into a refusal', () {
      expect(_ok('Attic: 250x Cat6').dropCount, 250);
    });
  });

  group('modifiers', () {
    test('are case-insensitive in their NAME and exact in their VALUE', () {
      final p = _ok('Attic: 3x Cat6 @SERVICE=wifi-ap');
      expect(p.service, 'wifi-ap');
    });

    test('a quoted value may contain spaces and an at sign', () {
      // The reason the scanner tracks quotes at all.
      final p = _ok('Kitchen: 2x Cat6 @outlet="Kitchen island @ sink"');
      expect(p.outletDesignation, 'Kitchen island @ sink');
    });

    test('pathway is the conduit sense and is kept apart from outlet', () {
      // CR-016: `@outlet=` is the outlet sense of "bundle" and
      // `@pathway=` is the conduit sense. One line may carry both.
      final p = _ok('Attic: 3x Cat6 @outlet="ATT-1" @pathway="North chase"');
      expect(p.outletDesignation, 'ATT-1');
      expect(p.pathwayName, 'North chase');
    });

    test('a modifier this build does not know is KEPT, not dropped', () {
      // DR-019's forward-compat instinct on a text surface. The resolver
      // reports it; what it must never do is swallow it, because a
      // person who typed `@wall=north` and saw nine drops appear has
      // been told their input was understood.
      final p = _ok('Attic: 3x Cat6 @wall=north');
      expect(p.unknownModifiers, {'wall': 'north'});
      expect(p.service, isNull);
    });

    test('items stop at the first unquoted @', () {
      // The scanner boundary, stated as a claim: everything before the
      // first modifier is items and nothing after it is.
      final p = _ok('Attic: 3x Cat6, 2x RG6 @service=camera');
      expect(_items(p), [(3, 'Cat6'), (2, 'RG6')]);
      expect(p.service, 'camera');
    });
  });

  group('blank is not an error', () {
    test('empty, whitespace and a comment all read as blank', () {
      // A paste of six lines with a gap between two of them is a normal
      // thing a person does. Reporting "line 3: expected a location" for
      // it trains the user to ignore the error text.
      for (final line in const ['', '   ', '\t', '# rough-in, second floor']) {
        expect(parseDropLine(line), isA<DropLineBlank>(), reason: '"$line"');
      }
    });
  });

  group('refusals carry a sentence and a caret', () {
    test('no colon says what a line looks like', () {
      final e = _bad('Living Room 4x Cat6');
      expect(e.reason, contains('Room: 4x Cat6'));
      expect(e.reason, contains('no colon'));
    });

    test('no room before the colon points at column zero', () {
      final e = _bad(': 4x Cat6');
      expect(e.reason, contains('needs a room'));
      expect(e.column, 0);
    });

    test('a room with no drops names the room', () {
      final e = _bad('Living Room:');
      expect(e.reason, contains('Living Room'));
      expect(e.reason, contains('4x Cat6'));
    });

    test('a count with no cable suggests the fix using the count typed', () {
      // `Kitchen: 4` is a real half-finished line, and reading it as one
      // drop of a cable called "4" would fail two stages later with a
      // much worse sentence.
      final e = _bad('Kitchen: 4');
      expect(e.reason, contains('"4x Cat6"'));
    });

    test('a count of zero is refused rather than silently skipped', () {
      // Skipping it would produce eight drops from a line that asked for
      // nine and say nothing, which is docs/04 §3.4's forbidden case.
      final e = _bad('Kitchen: 0x Cat6');
      expect(e.reason, contains('zero'));
    });

    test('a count with no media after the x', () {
      expect(_bad('Kitchen: 4x').reason, contains('does not say what'));
    });

    test('an unterminated quote', () {
      expect(_bad('Kitchen: 2x Cat6 @outlet="KIT').reason, contains('closed'));
    });

    test('a modifier with no equals', () {
      expect(_bad('Kitchen: 2x Cat6 @service').reason, contains('"="'));
    });

    test('a modifier with no value', () {
      expect(_bad('Kitchen: 2x Cat6 @service=').reason, contains('no value'));
    });

    test('ONE BAD ITEM REFUSES THE WHOLE LINE', () {
      // The load-bearing one for a bulk surface. A line asking for nine
      // drops that quietly produces eight is worse than one that
      // produces none and says why: the person moves on and finds out at
      // the panel.
      final e = _bad('Living Room: 4x Cat6, 0x RG6, 2x 16/4');
      expect(e.reason, contains('zero'));
    });
  });

  group('the caret lands on the right character', () {
    test('on the offending item, not on the start of the line', () {
      const line = 'Living Room: 4x Cat6, 0x RG6';
      final e = _bad(line);
      expect(line.substring(e.column), startsWith('0x RG6'));
    });

    test('on the item even when the location name is long', () {
      const line = 'Primary Bedroom Closet: 2x Cat6, 4';
      final e = _bad(line);
      expect(line.substring(e.column), '4');
    });
  });

  group('parseDropLine is total', () {
    test('never throws, on anything', () {
      // A text surface takes whatever a keyboard produces, including a
      // paste of a PDF.
      for (final line in const [
        '::::',
        '@@@@',
        'a: @=',
        '4x',
        'x x x',
        ':',
        '+',
        ',,,,',
        'Room: ,,,',
        'Room: 2x Cat6 @a=1 @b=2 @c=3',
        '"',
        'Room: "',
      ]) {
        expect(() => parseDropLine(line), returnsNormally, reason: '"$line"');
      }
    });
  });
}
