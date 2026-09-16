// Regenerates `assets/starters/*.rppj`.
//
//     dart run tool/generate_starters.dart          # from apps/rackpal
//     dart run tool/generate_starters.dart --check  # CI-style, no writes
//
// THE ASSETS ARE CHECKED IN, and this only rebuilds them. That is the
// point: docs/04 §9 and AC-052 require the starters to be real files
// doing triple duty as goldens, perf fixtures and screenshot source, and
// a golden that is regenerated on every launch is not a golden.
// `test/starters/starter_assets_test.dart` runs the equivalent of
// `--check` on every CI run, so a stale asset is a test failure and never
// a surprise in a screenshot.
//
// THE ONE `dart:io` IN THIS DIRECTORY. `lib/src/storage/io_file_store
// .dart` is the app's only filesystem seam and a grep test enforces it;
// this file is build tooling, outside `lib/`, and never ships.
import 'dart:io';

import 'package:rackpal_core/rackpal_core.dart';

import 'starters/starter_sources.dart';

/// Where the generated assets live, relative to `apps/rackpal`.
const String kStarterAssetDir = 'assets/starters';

Future<void> main(List<String> args) async {
  final checkOnly = args.contains('--check');
  const codec = JsonDocumentCodec();
  final directory = Directory(kStarterAssetDir);
  if (!checkOnly) await directory.create(recursive: true);

  var stale = 0;
  for (final source in kStarterSources) {
    final bytes = codec.write(source.build());
    final file = File('$kStarterAssetDir/${source.fileName}');
    final existing = file.existsSync() ? file.readAsBytesSync() : null;
    if (existing != null && _sameBytes(existing, bytes)) {
      stdout.writeln('unchanged  ${source.fileName}  ${bytes.length} bytes');
      continue;
    }
    stale++;
    if (checkOnly) {
      stderr.writeln('STALE      ${source.fileName}');
      continue;
    }
    file.writeAsBytesSync(bytes);
    stdout.writeln('written    ${source.fileName}  ${bytes.length} bytes');
  }

  if (checkOnly && stale > 0) {
    stderr.writeln(
      '$stale starter asset(s) are out of date. Run '
      '`dart run tool/generate_starters.dart`.',
    );
    exitCode = 1;
  }
}

bool _sameBytes(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
