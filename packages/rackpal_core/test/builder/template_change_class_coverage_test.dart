// THE GATE UNDER `builder/template_change_class.dart` (board #197,
// M4-C/2).
//
// The change class is only as honest as the table it reads. A field added
// to `TemplateBody` or `PortDef` and wired through the codec, but never
// given a class, is a field whose edits classify as nothing — and the
// default that would sit there is `safe`, which is the one wrong answer
// that costs somebody a job. So the table is not maintained by memory: it
// is compared, key for key, against the codec's own encoders.
//
// A MECHANICAL GREP, NOT A PARSER, in `internal_setter_grep_test.dart`'s
// tradition. It matches the three forms `json_codec.dart` actually uses to
// emit a key, and it is deliberately narrow, because a false positive here
// is a flaky gate and a false negative is caught by the direction that
// matters: the codec is the SOURCE, so anything it emits must be claimed.
//
// It asserts BOTH directions. A class left behind for a field the codec no
// longer writes is dead weight that makes the table look more complete
// than it is, which is how the next person concludes it is maintained.
import 'dart:io';

import 'package:rackpal_core/rackpal_core.dart';
import 'package:test/test.dart';

/// The three shapes `json_codec.dart` writes a key in:
///
///   `'frontU': b.frontU,`                  a map literal entry
///   `putIfNotNull(json, 'weightUg', ...)`  the conditional helper
///   `json['accentColor'] = ...`            an explicit if-block
/// Anchored on `{` or `,` as well as a line break, because a short
/// encoder puts its whole map on one line (`_encodePanelGraphic` writes
/// `{'id': p.id, 'kind': p.kind}`) and a line-start anchor sees only the
/// first key of such a line — or none.
final _mapLiteralKey = RegExp(r"(?:^|\n|[{,])\s*'([A-Za-z][A-Za-z0-9]*)':");
final _putIfNotNullKey = RegExp(
  r"putIfNotNull\(\s*json,\s*'([A-Za-z][A-Za-z0-9]*)'",
);
final _explicitAssignKey = RegExp(r"json\['([A-Za-z][A-Za-z0-9]*)'\]\s*=");

/// Reads the body of `JsonMap <name>(` up to its closing brace.
///
/// The terminator is a line that is exactly `}` OR exactly `};`, because
/// these encoders come in both shapes: `_encodeTemplateBody` has a block
/// body and `_encodeBankDef` is a one-expression arrow returning a map
/// literal. Stopping only at `}` runs an arrow-bodied encoder straight
/// into the next function, and the first version of this test did exactly
/// that: `_encodeBankDef` "emitted" `frontKey` and `geometryRef` and the
/// gate failed for a reason that had nothing to do with the table.
List<String> _encoderBody(String source, String name) {
  final lines = source.split('\n');
  final start = lines.indexWhere((l) => l.startsWith('JsonMap $name('));
  expect(
    start,
    isNot(-1),
    reason:
        'encoder "$name" is gone from json_codec.dart — either it was '
        'renamed (update this test) or the field group it wrote no longer '
        'reaches a file (drop its table)',
  );
  final end = lines.indexWhere(
    (l) => l == '}' || l == '};',
    start,
  );
  expect(end, isNot(-1), reason: 'unterminated encoder "$name"');
  return lines.sublist(start, end + 1);
}

Set<String> _keysEmittedBy(String source, String name) {
  // Comment lines go FIRST, then the rest is rejoined and matched as one
  // blob rather than line by line. `dart format` wraps a long
  // `putIfNotNull(json, 'containerWeightCapacityUg', ...)` across four
  // lines, and a per-line matcher misses every call it does that to.
  //
  // This is the SECOND time this repo has been bitten by exactly that:
  // M4-B counted 44 seeded connectors with `grep -c "_c('conn"` against a
  // registry that ships 49, because the grep could not see a multi-line
  // call either. Census the field, not the pattern that happens to match
  // most of it.
  final body = _encoderBody(
    source,
    name,
  ).where((l) => !l.trimLeft().startsWith('//')).join('\n');

  return {
    for (final m in _mapLiteralKey.allMatches(body)) m.group(1)!,
    for (final m in _putIfNotNullKey.allMatches(body)) m.group(1)!,
    for (final m in _explicitAssignKey.allMatches(body)) m.group(1)!,
  };
}

void main() {
  final codec = File(
    'lib/src/persistence/json_codec.dart',
  ).readAsStringSync();

  group('every field that reaches a template file has a change class', () {
    for (final entry in templateChangeClassifiedKeys.entries) {
      final encoder = entry.key;
      final classified = entry.value;

      test(encoder, () {
        final emitted = _keysEmittedBy(codec, encoder);

        expect(
          emitted,
          isNotEmpty,
          reason:
              'the grep found no keys in $encoder at all — the codec '
              'changed shape and this gate is now asserting nothing',
        );
        expect(
          emitted.difference(classified),
          isEmpty,
          reason:
              'these keys reach a file with NO change class, so an edit '
              'to them would classify as safe by default — add them to '
              'the table in builder/template_change_class.dart',
        );
        expect(
          classified.difference(emitted),
          isEmpty,
          reason:
              'these have a change class but the codec no longer writes '
              'them, so the table claims a completeness it does not have',
        );
      });
    }
  });

  test('the grep can see a key the table has not claimed, so the gate is '
      'capable of failing', () {
    // Watched fail per `assert the artifact, not the mechanism`: a
    // coverage test that cannot fail is a coverage test that passed
    // because it looked at nothing.
    final emitted = _keysEmittedBy(codec, '_encodeTemplateBody');
    final sabotaged = {...emitted}..remove('frontU');

    expect(emitted.difference(sabotaged), {'frontU'});
  });
}
