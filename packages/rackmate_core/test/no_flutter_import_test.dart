import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('rackmate_core has no UI, no Flutter, and no PDF engine', () {
    final banned = RegExp(
      r'''import\s+['"](package:flutter/|dart:ui|package:pdf/)''',
    );
    for (final f in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      final hit = banned.firstMatch(f.readAsStringSync());
      expect(hit, isNull, reason: '${f.path} imports ${hit?.group(1)}');
    }
  });
}
