// THE purity gate: `rackmate_core` is pure Dart — no Flutter, no `dart:ui`,
// no PDF engine (D1, CR-083, docs/03-architecture.md §3.1). Every other
// boundary in this project stands on it: `rackmate_export` may replay the
// shared drawing IR precisely because the IR carries no Flutter, and
// `rackmate_ui` and `rackmate_export` can stay siblings for the same reason.
//
// WHAT THE EARLIER VERSION OF THIS FILE MISSED. It matched
// `import\s+['"](package:flutter/|dart:ui|package:pdf/)` — a URI that
// IMMEDIATELY follows the `import` keyword — and three legal Dart spellings
// walked straight past it:
//
//   1. A conditional import puts the banned URI after `)`, not after
//      `import`:
//          import 'stub.dart' if (dart.library.ui) 'package:flutter/…';
//      That is the standard way a package compiles differently on the
//      Flutter target, so it is exactly the spelling that would be reached
//      for — and it would have compiled Flutter into core silently.
//   2. `export` was never checked at all. `export 'package:pdf/pdf.dart';`
//      in the public barrel would re-export the PDF engine to every
//      consumer of `rackmate_core`.
//   3. `\s+` requires whitespace, but `import"package:flutter/material.dart";`
//      is valid Dart.
//
// So this scans whole DIRECTIVES — `import`/`export` through their
// terminating `;` — and looks for a banned URI anywhere inside one. It also
// counts what it scanned, the vacuity guard its two sibling gates
// (`rackmate_ui/test/no_print_test.dart`, `apps/rackmate/test/
// no_print_test.dart`) already carry: a run that found no files would
// otherwise pass while proving nothing.

import 'dart:io';

import 'package:test/test.dart';

/// One `import`/`export` directive, from the keyword through its `;`.
///
/// `[^;]*` cannot run past the directive's own terminator, and `dotAll`
/// lets it span the line breaks a long conditional import is usually
/// wrapped across.
final _directive = RegExp(
  r'(?<![\w$])(?:import|export)\b[^;]*;',
  dotAll: true,
);

/// A banned URI anywhere inside a directive — after `import`, after a
/// conditional `if (…)`, or after `export`.
final _banned = RegExp(
  '''['"](package:flutter/|dart:ui|package:pdf/)''',
);

/// Strips `//` line comments and `/* */` block comments, so prose that
/// DESCRIBES the rule — this file's own header, or `symbol_hit_test.dart`
/// explaining which Flutter name it renamed away from — is never mistaken
/// for a violation. Same helper, same reason, as the `no_print` gates.
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

/// Every banned URI [source] pulls in, in any directive form.
List<String> bannedUris(String source) {
  final hits = <String>[];
  for (final directive in _directive.allMatches(_stripComments(source))) {
    for (final hit in _banned.allMatches(directive[0]!)) {
      hits.add(hit.group(1)!);
    }
  }
  return hits;
}

void main() {
  test('rackmate_core has no UI, no Flutter, and no PDF engine', () {
    final lib = Directory('lib');
    expect(
      lib.existsSync(),
      isTrue,
      reason: 'run from the package root, where lib/ is',
    );

    final offenders = <String>[];
    var scanned = 0;
    for (final f in lib
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      scanned++;
      for (final uri in bannedUris(f.readAsStringSync())) {
        offenders.add('${f.path} pulls in $uri');
      }
    }

    // Guards the guard: a scan that found no files would pass vacuously.
    expect(scanned, greaterThan(10));
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  // The gate is only as good as its pattern, so the pattern itself is
  // tested against the spellings that defeated the previous one. These are
  // strings, not files — the point is what the matcher does, and a fixture
  // file containing a real Flutter import could not live under `lib/`.
  group('the pattern catches every legal spelling', () {
    test('a plain import', () {
      expect(
        bannedUris("import 'package:flutter/material.dart';"),
        ['package:flutter/'],
      );
    });

    test('a CONDITIONAL import, where the banned URI follows `)` and not '
        '`import`', () {
      expect(
        bannedUris(
          "import 'stub.dart' "
          "if (dart.library.ui) 'package:flutter/foundation.dart';",
        ),
        ['package:flutter/'],
      );
    });

    test('a conditional import wrapped across lines', () {
      expect(
        bannedUris('''
import 'src/stub.dart'
    if (dart.library.io) 'dart:ui'
    show Color;
'''),
        ['dart:ui'],
      );
    });

    test('an EXPORT — the barrel is a re-export surface', () {
      expect(bannedUris("export 'package:pdf/pdf.dart';"), ['package:pdf/']);
      expect(
        bannedUris("export 'package:flutter/widgets.dart' show Widget;"),
        ['package:flutter/'],
      );
    });

    test('no whitespace after the keyword', () {
      expect(
        bannedUris('import"package:flutter/material.dart";'),
        ['package:flutter/'],
      );
    });

    test('a deferred import', () {
      expect(
        bannedUris("import 'dart:ui' deferred as ui;"),
        ['dart:ui'],
      );
    });

    test('all three banned roots, and every one reported', () {
      expect(
        bannedUris('''
import 'package:flutter/material.dart';
import 'dart:ui';
export 'package:pdf/pdf.dart';
'''),
        ['package:flutter/', 'dart:ui', 'package:pdf/'],
      );
    });
  });

  group('the pattern does not cry wolf', () {
    test('the permitted imports are permitted', () {
      expect(
        bannedUris('''
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:meta/meta.dart';
import 'package:collection/collection.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:rackmate_core/src/draw/ops.dart';
'''),
        isEmpty,
      );
    });

    test('a COMMENT naming a banned package is prose, not an import', () {
      expect(
        bannedUris("""
// `HitTestResult` is also a 'package:flutter/rendering.dart' export.
/* import 'package:pdf/pdf.dart'; would be a violation. */
import 'dart:math' as math;
"""),
        isEmpty,
      );
    });

    test('an identifier containing the keyword is not a directive', () {
      expect(
        bannedUris("final reimport = 'package:flutter/material.dart';"),
        isEmpty,
      );
    });
  });
}
