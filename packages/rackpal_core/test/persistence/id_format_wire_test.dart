// A designator pattern a file carries is validated ON DECODE.
//
// ═══════════════════════════════════════════════════════════════════════
// THE CONSTRUCTOR VALIDATES NOTHING, WHICH IS WHY THIS TEST EXISTS
// ═══════════════════════════════════════════════════════════════════════
// `const IdFormat(this.pattern)` stores the string and checks none of it.
// `IdFormatSyntaxException` comes from `_parsePattern`, which only
// `render()` calls. So the codec used to accept ANY string from a file: a
// hand-edited or corrupted `.rmpj` opened cleanly and then threw the first
// time a designator was minted, a whole subsystem away from the field that
// caused it.
//
// The fix follows `json_codec.dart`'s own stated convention rather than
// inventing one. That file's header says every enum but two decodes
// through the strict, throwing path, "which surfaces as a whole-document
// `Err` at the `read()` boundary rather than a silent guess". Substituting
// the default pattern for one an author did not write is exactly that
// guess, and G4 forbids fabricating a value nobody supplied.
import 'dart:convert';
import 'dart:typed_data';

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

const _codec = JsonDocumentCodec();

/// The refusal's own words.
///
/// NOT `Err.toString()`, which the first draft used and which prints
/// `Instance of 'Err<RackDocument>'`: the message is on `Err.error`, and a
/// test asserting against the wrapper checks nothing about what a person
/// would be shown.
String _why(Outcome<RackDocument> o) =>
    (o as Err<RackDocument>).error.toString();

RackDocument _doc() => RackDocument(
  id: const Uuid('doc-idformat'),
  appVersion: '0.4.93',
  createdAt: DateTime.utc(2026, 9),
  modifiedAt: DateTime.utc(2026, 9),
  meta: EntityMeta(
    createdAt: DateTime.utc(2026, 9),
    updatedAt: DateTime.utc(2026, 9),
    updatedBy: 'test',
  ),
);

/// The document's bytes with one settings pattern replaced by [pattern].
///
/// EDITS THE BYTES rather than building a document with a bad format,
/// because a bad format cannot be reached through the app any more: the
/// settings dialog refuses one, so a file is the only way in. That is the
/// path this test has to cover.
Uint8List _withPattern(String key, String pattern) {
  final tree =
      jsonDecode(utf8.decode(_codec.write(_doc()))) as Map<String, Object?>;
  final doc = tree['document']! as Map<String, Object?>;
  final settings = doc['settings']! as Map<String, Object?>;
  settings[key] = pattern;
  return Uint8List.fromList(utf8.encode(jsonEncode(tree)));
}

void main() {
  group('a good pattern still round-trips', () {
    test('the default settings survive a write and a read', () {
      final back = _codec.read(_codec.write(_doc()));
      expect(back, isA<Ok<RackDocument>>());
      expect(
        (back as Ok<RackDocument>).value.settings.portDesignatorFormat.pattern,
        'J{PORT_SEQ:2}',
      );
    });

    test('a pattern a person could legitimately write is accepted', () {
      final back = _codec.read(
        _withPattern('portDesignatorFormat', 'P{PORT_SEQ:3}'),
      );
      expect(back, isA<Ok<RackDocument>>());
    });
  });

  group('a pattern the renderer cannot use refuses the document', () {
    test('a SYNTAX error is an Err naming the field, not a document that '
        'opens and throws later', () {
      final back = _codec.read(
        _withPattern('portDesignatorFormat', 'J{UNCLOSED'),
      );
      expect(
        back,
        isA<Err<RackDocument>>(),
        reason:
            'accepting it would defer the failure to the first '
            'designator mint, a subsystem away from the cause',
      );
      expect(
        _why(back),
        contains('portDesignatorFormat'),
        reason:
            'the message must name WHICH pattern, because a project '
            'carries six and the reader has to know which to fix',
      );
    });

    test('an UNKNOWN TOKEN is refused too, which the syntax check alone '
        'does not catch: {NOPE} parses perfectly', () {
      // THE TWO CHECKS ARE NOT DISJOINT, which the first draft assumed.
      // `unrecognisedTokens()` is regex-based and never throws;
      // `requiredTokens()` runs the parser and throws
      // `UnrecognisedTokenException` for this very pattern. So the safe
      // reporter has to run first, or the named message never fires.
      expect(const IdFormat('{NOPE}').unrecognisedTokens(), ['NOPE']);
      expect(
        () => const IdFormat('{NOPE}').requiredTokens(),
        throwsA(isA<UnrecognisedTokenException>()),
      );

      final back = _codec.read(_withPattern('netNameFormat', 'N{NOPE}'));
      expect(back, isA<Err<RackDocument>>());
      expect(_why(back), contains('netNameFormat'));
    });

    test('every one of the six settings patterns is checked, not just the '
        'one somebody remembered', () {
      for (final key in [
        'deviceDesignatorFormat',
        'portDesignatorFormat',
        'linkDesignatorFormat',
        'netNameFormat',
        'outletFieldLabelFormat',
        'outletRackLabelFormat',
      ]) {
        expect(
          _codec.read(_withPattern(key, '{UNCLOSED')),
          isA<Err<RackDocument>>(),
          reason: '$key decodes without validation',
        );
      }
    });
  });
}
