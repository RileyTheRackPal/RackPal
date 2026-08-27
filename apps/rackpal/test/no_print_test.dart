// A source-level gate: no `print` in the shipped app shell.
//
// The sibling of `packages/rackpal_ui/test/no_print_test.dart`; see that
// file's header for why an INFO-level lint was not enough. Two of the eight
// `print` calls this stage removed were in `apps/rackpal/lib/main.dart`,
// one of them dumping `BoxConstraints` on every build.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _printCall = RegExp(r'(?<![\w.$])(print|debugPrint)\s*\(');

String _stripComments(String source) {
  final withoutBlocks = source.replaceAll(
    RegExp(r'/\*.*?\*/', dotAll: true),
    '',
  );
  return withoutBlocks
      .split('\n')
      .map((line) {
        final i = line.indexOf('//');
        return i == -1 ? line : line.substring(0, i);
      })
      .join('\n');
}

void main() {
  test('no print() survives anywhere in apps/rackpal/lib', () {
    final lib = Directory('lib');
    expect(
      lib.existsSync(),
      isTrue,
      reason: 'run from the app root, where lib/ is',
    );

    final offenders = <String>[];
    var scanned = 0;
    for (final entity in lib.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      scanned++;
      final lines = _stripComments(entity.readAsStringSync()).split('\n');
      for (var i = 0; i < lines.length; i++) {
        if (_printCall.hasMatch(lines[i])) {
          offenders.add('${entity.path}:${i + 1}: ${lines[i].trim()}');
        }
      }
    }

    expect(scanned, greaterThan(0));
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}
