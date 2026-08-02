// ONE REPOSITORY, ONE VERSION — and six places it is written down.
//
// ═════════════════════════════════════════════════════════════════════
// WHY THIS IS A GATE AND NOT A CONVENTION
// ═════════════════════════════════════════════════════════════════════
// Dart cannot read its own `pubspec.yaml` at compile time, so `kAppVersion`
// is a hand-kept copy of the app's declared version. It is not decorative:
// it lands in `RackDocument.appVersion` on every new document and in every
// recovery sidecar, so a release that forgot to bump it stamps the
// PREVIOUS version permanently into files the user keeps. Nothing about
// running the app would look wrong.
//
// The four library packages are unpublished and their `version:` is inert
// TODAY — which is exactly why they drift. They are gated with the app
// because "the repo is at 0.2.0" should be one fact, and a reader who
// finds `rackmate_core` at 0.1.0 beside an app at 0.2.0 has to work out
// which one is lying.
//
// ═════════════════════════════════════════════════════════════════════
// THE SCHEME IS ASSERTED TOO — docs/14 §14.0
// ═════════════════════════════════════════════════════════════════════
// `0.EPIC.TASK`. The leading `0` holds until the first public release, so
// a `1.` appearing here is either that release — a decision, not a typo —
// or somebody reaching for semver out of habit. Both are worth stopping
// for.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rackmate/src/session/app_services.dart';

/// The `version:` line of [pubspec], which is deliberately parsed with a
/// regex rather than a YAML library: a dependency added to read one line
/// is a dependency that has to be kept, and the line's shape is fixed.
String _versionOf(String pubspec) {
  final file = File(pubspec);
  expect(
    file.existsSync(),
    isTrue,
    reason: 'no $pubspec — did a package move?',
  );
  final match = RegExp(
    r'^version:\s*(\S+)\s*$',
    multiLine: true,
  ).firstMatch(file.readAsStringSync());
  expect(match, isNotNull, reason: '$pubspec declares no version');
  return match!.group(1)!;
}

void main() {
  // Relative to the package root, which is where `flutter test` runs.
  const app = 'pubspec.yaml';
  const packages = <String>[
    '../../packages/rackmate_core/pubspec.yaml',
    '../../packages/rackmate_export/pubspec.yaml',
    '../../packages/rackmate_text/pubspec.yaml',
    '../../packages/rackmate_ui/pubspec.yaml',
  ];

  test('kAppVersion matches the app pubspec — the copy that reaches a '
      'saved document', () {
    expect(
      kAppVersion,
      _versionOf(app),
      reason: 'a release that bumps one and not the other stamps the wrong '
          'version into every document and recovery sidecar it writes, '
          'permanently, and nothing about running it looks wrong',
    );
  });

  test('every workspace package carries the same version as the app', () {
    final appVersion = _versionOf(app);
    for (final pubspec in packages) {
      expect(_versionOf(pubspec), appVersion, reason: pubspec);
    }
  });

  test('the version follows docs/14 §14.0 — 0.EPIC.TASK', () {
    final parts = kAppVersion.split('.');
    expect(parts, hasLength(3), reason: 'three numbers, no build suffix');
    for (final part in parts) {
      expect(int.tryParse(part), isNotNull, reason: 'each part is a number');
    }
    expect(
      parts.first,
      '0',
      reason: 'the leading 0 holds until the first PUBLIC release. Changing '
          'it is a decision about the product, so it should arrive as a '
          'deliberate edit to this test and not as a version bump',
    );
  });
}
