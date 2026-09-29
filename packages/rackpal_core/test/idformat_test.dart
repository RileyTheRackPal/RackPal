import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

void main() {
  group('IdFormat — worked examples (docs/02-data-model.md §4.1)', () {
    test('device designator: {TYPE_PREFIX}{SEP}{SEQ}', () {
      const format = IdFormat('{TYPE_PREFIX}{SEP}{SEQ}');
      final result = format.render({
        'TYPE_PREFIX': 'MTX',
        'SEP': '-',
        'SEQ': 1,
      });
      expect(result, 'MTX-1');
    });

    test('port designator: J{PORT_SEQ:2}', () {
      const format = IdFormat('J{PORT_SEQ:2}');
      expect(format.render({'PORT_SEQ': 1}), 'J01');
    });

    test('link designator: W{SEQ:3}', () {
      const format = IdFormat('W{SEQ:3}');
      expect(format.render({'SEQ': 42}), 'W042');
    });

    test('net name: N{SEQ:3}', () {
      const format = IdFormat('N{SEQ:3}');
      expect(format.render({'SEQ': 12}), 'N012');
    });

    test('outlet field label: {ROOM_ABBR}-{SERVICE}-{SEQ}', () {
      const format = IdFormat('{ROOM_ABBR}-{SERVICE}-{SEQ}');
      final result = format.render({
        'ROOM_ABBR': 'LR',
        'SERVICE': 'TV',
        'SEQ': 1,
      });
      expect(result, 'LR-TV-1');
    });

    test('outlet rack label: {FLOOR}{SPACE}-{PANEL}{PORT:2}', () {
      const format = IdFormat('{FLOOR}{SPACE}-{PANEL}{PORT:2}');
      final result = format.render({
        'FLOOR': 1,
        'SPACE': 'A',
        'PANEL': 'A',
        'PORT': 12,
      });
      expect(result, '1A-A12');
    });
  });

  group('IdFormat — zero padding', () {
    test('pads shorter numbers with leading zeros', () {
      const format = IdFormat('{SEQ:4}');
      expect(format.render({'SEQ': 7}), '0007');
    });

    test('does not truncate a value already at or above the pad width', () {
      const format = IdFormat('{SEQ:2}');
      expect(format.render({'SEQ': 12345}), '12345');
    });
  });

  group('IdFormat — optional segments', () {
    test('renders the segment when every inner token has a value', () {
      const format = IdFormat('{SITE}[-{BUILDING}]');
      expect(format.render({'SITE': 'HQ', 'BUILDING': 'A'}), 'HQ-A');
    });

    test('omits the segment entirely when a token is absent', () {
      const format = IdFormat('{SITE}[-{BUILDING}]');
      expect(format.render({'SITE': 'HQ'}), 'HQ');
    });

    test('omits a nested optional independently of its parent', () {
      const format = IdFormat('{SITE}[-{BUILDING}[{FLOOR}]]');
      expect(
        format.render({'SITE': 'HQ', 'BUILDING': 'A'}),
        'HQ-A',
      );
      expect(
        format.render({'SITE': 'HQ', 'BUILDING': 'A', 'FLOOR': 2}),
        'HQ-A2',
      );
      expect(format.render({'SITE': 'HQ'}), 'HQ');
    });

    test('a required token with no value throws', () {
      const format = IdFormat('{SITE}-{BUILDING}');
      expect(
        () => format.render({'SITE': 'HQ'}),
        throwsA(isA<MissingTokenValueException>()),
      );
    });
  });

  group('IdFormat — filters', () {
    test('|upper uppercases the rendered value', () {
      const format = IdFormat('{DEVICE|upper}');
      expect(format.render({'DEVICE': 'amp1'}), 'AMP1');
    });

    test('|first n takes the first n characters', () {
      const format = IdFormat('{DEVICE|first 3}');
      expect(format.render({'DEVICE': 'Amplifier'}), 'Amp');
    });

    test('|first n is a no-op when n exceeds the value length', () {
      const format = IdFormat('{DEVICE|first 30}');
      expect(format.render({'DEVICE': 'Amp'}), 'Amp');
    });

    test('|nz omits a zero numeric value like a missing one', () {
      const format = IdFormat('W[{SEQ|nz}]');
      expect(format.render({'SEQ': 0}), 'W');
      expect(format.render({'SEQ': 5}), 'W5');
    });

    test('filters chain left to right', () {
      const format = IdFormat('{DEVICE|first 3|upper}');
      expect(format.render({'DEVICE': 'amplifier'}), 'AMP');
    });
  });

  group('IdFormat — literal braces', () {
    test('{{ and }} render as literal braces', () {
      const format = IdFormat('{{TYPE_PREFIX}}');
      // "{{" -> "{", then the literal text "TYPE_PREFIX", then "}}" -> "}".
      expect(format.render(const {}), '{TYPE_PREFIX}');
    });

    test('a literal-braces pattern round-trips through pattern', () {
      const format = IdFormat('{{fixed}}');
      expect(format.pattern, '{{fixed}}');
      expect(format.render(const {}), '{fixed}');
    });
  });

  group('IdFormat — token registry validation', () {
    test('flags a token name outside the canonical vocabulary', () {
      const format = IdFormat('{BOGUS}-{SEQ}');
      expect(format.unrecognisedTokens(), ['BOGUS']);
    });

    test('render throws for an unrecognised token', () {
      const format = IdFormat('{BOGUS}');
      expect(
        () => format.render(const {}),
        throwsA(isA<UnrecognisedTokenException>()),
      );
    });

    test('every canonical token name is individually recognised', () {
      for (final token in kIdFormatTokens) {
        final format = IdFormat('{$token}');
        expect(format.unrecognisedTokens(), isEmpty, reason: token);
      }
    });
  });
}
