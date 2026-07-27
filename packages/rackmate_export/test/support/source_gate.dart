// rackmate_export/test/support/source_gate.dart -- TEST SUPPORT ONLY.
//
// The source-level scanners this package's two gates stand on: which
// packages `lib/` may import, and whether anything anywhere calls `print`.
//
// ─────────────────────────────────────────────────────────────────────────
// WHY A DIRECTIVE SCANNER AND NOT A `RegExp("import ...")`
// ─────────────────────────────────────────────────────────────────────────
// The import gate in `symbol_layer_pdf_test.dart` used to be
// `RegExp(r"""import\s+['"]package:rackmate_ui/""")` — the exact naive
// pattern that `rackmate_core/test/no_flutter_import_test.dart`'s header
// documents at length as broken and replaced. Three legal Dart spellings
// walk straight past it, and each of them would re-admit the Flutter
// backend into a package whose whole reason for existing is that it is
// isolate-safe pure Dart:
//
//   1. `export 'package:rackmate_ui/rackmate_ui.dart';` in the barrel
//      re-exports rackmate_ui to EVERY consumer of rackmate_export, and
//      the keyword is not `import` so the pattern never looks.
//   2. `import 'stub.dart' if (dart.library.ui) 'package:rackmate_ui/…';`
//      puts the banned URI after `)`, not after `import` — and a
//      conditional import is precisely the spelling somebody reaches for
//      when they want a package to compile differently on the Flutter
//      target.
//   3. `import"package:rackmate_ui/rackmate_ui.dart";` is valid Dart with
//      no whitespace after the keyword, and `\s+` requires some.
//
// So this scans whole DIRECTIVES — `import`/`export` through the `;` that
// ends them — and looks for a banned URI anywhere inside one. Same shape,
// and deliberately the same shape, as the sibling gate in core: one
// pattern, proved against the spellings that defeated its predecessor.

import 'dart:io';

/// One `import`/`export` directive, from the keyword through its `;`.
///
/// `[^;]*` cannot run past the directive's own terminator, and `dotAll`
/// lets it span the line breaks a long conditional import is usually
/// wrapped across.
final RegExp _directive = RegExp(
  r'(?<![\w$])(?:import|export)\b[^;]*;',
  dotAll: true,
);

/// The package roots `rackmate_export` may never pull in, in any directive
/// form.
///
/// `package:rackmate_ui/` is the sibling rule (CR-086: the two backends are
/// siblings and neither may reach the other). `package:flutter/` and
/// `dart:ui` are the reason that rule exists — reaching rackmate_ui is only
/// bad because of what it drags in — so they are banned directly too,
/// which catches a Flutter dependency that arrives without going through
/// rackmate_ui at all.
const List<String> kBannedUriRoots = <String>[
  'package:rackmate_ui/',
  'package:flutter/',
  'dart:ui',
];

final RegExp _banned = RegExp(
  '''['"](${kBannedUriRoots.map(RegExp.escape).join('|')})''',
);

/// A call to `print` or `debugPrint`.
///
/// The lookbehind is what keeps `_printCall`, `sprint(` and `x.print(`
/// from matching — the same pattern the two shipped `no_print` gates use.
final RegExp _printCall = RegExp(r'(?<![\w.$])(print|debugPrint)\s*\(');

/// A call to `expect` — what makes a test a test.
final RegExp _expectCall = RegExp(r'(?<![\w.$])(expect|expectLater)\s*\(');

/// Strips `//` line comments and `/* */` block comments, so prose that
/// DESCRIBES a rule — this file's own header, or a test explaining which
/// spelling it rejects — is never mistaken for a violation.
String stripComments(String source) {
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
  for (final directive in _directive.allMatches(stripComments(source))) {
    for (final hit in _banned.allMatches(directive[0]!)) {
      hits.add(hit.group(1)!);
    }
  }
  return hits;
}

/// `true` when [source] calls `print`/`debugPrint` outside a comment.
bool callsPrint(String source) => _printCall.hasMatch(stripComments(source));

/// `true` when [source] contains at least one `expect`.
bool callsExpect(String source) => _expectCall.hasMatch(stripComments(source));

/// Every `.dart` file under [directoryPath], recursively.
///
/// Throws when the directory is missing rather than yielding nothing: a
/// gate that scanned zero files would pass while proving nothing, and every
/// caller here also asserts on the count it got back.
List<File> dartFilesUnder(String directoryPath) {
  final dir = Directory(directoryPath);
  if (!dir.existsSync()) {
    throw StateError(
      'no $directoryPath/ from ${Directory.current.path} — run this suite '
      'from the package root',
    );
  }
  return dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();
}
