// PLAN-K/1: the binary in the tree is the binary that was pinned
// (CR-100, DR-153 §11.152.3).
//
// ═══════════════════════════════════════════════════════════════════════
// WHAT A VENDORED BINARY NEEDS THAT A PACKAGE DEPENDENCY DOES NOT
// ═══════════════════════════════════════════════════════════════════════
// A pub dependency carries its own integrity check: the lockfile records a
// hash and `pub get` refuses a mismatch. **A committed DLL has nothing of
// the sort.** It is megabytes of opaque bytes that no reviewer reads and
// no diff shows, which is the cost CR-100 accepted to avoid a network
// fetch in a signed release, and this file is the compensating control:
// the pin records what was reviewed and the test says whether the tree
// still holds it.
//
// It cannot tell a good binary from a malicious one. What it tells you is
// that nobody swapped it after the day it was pinned, which is the
// question a supply chain actually asks.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:rackpal_pdfium/rackpal_pdfium.dart';
import 'package:test/test.dart';

/// The repository root, from the package directory tests run in.
const String kRepoRoot = '../..';

File get _pin => File('$kRepoRoot/third_party/pdfium/pdfium.pin.json');
File get _dll => File('$kRepoRoot/$kVendoredPdfiumPath');

void main() {
  group('the vendored binary', () {
    test('is where the loader looks for it', () {
      expect(
        _dll.existsSync(),
        isTrue,
        reason:
            'pdfium is not vendored yet. It is placed by a person on '
            'purpose (CR-100): $kVendorCommand',
      );
    });

    test('matches the checksum it was pinned at', () {
      final pin = jsonDecode(_pin.readAsStringSync()) as Map<String, dynamic>;
      final expected = (pin['dllSha256'] as String).toLowerCase();
      final actual = sha256.convert(_dll.readAsBytesSync()).toString();

      expect(
        actual,
        expected,
        reason:
            'the DLL in the tree is not the one recorded in '
            'pdfium.pin.json. Nobody reviews megabytes of opaque bytes '
            'in a diff, so this is the only thing that would notice.',
      );
    });

    test('the pin names the release it came from', () {
      final pin = jsonDecode(_pin.readAsStringSync()) as Map<String, dynamic>;
      // A checksum with no provenance is a number. The tag is what makes
      // the binary re-obtainable by somebody who does not trust ours.
      expect(pin['release'], isA<String>());
      expect((pin['release']! as String).trim(), isNotEmpty);
      expect(pin['url'], contains('pdfium-binaries'));
      expect(pin['archiveSha256'], isA<String>());
    });

    test('the licence travels with it', () {
      expect(
        File('$kRepoRoot/third_party/pdfium/LICENSE').existsSync(),
        isTrue,
        reason:
            'CR-100 says a vendored pdfium reopens DR-036 census, and a '
            'licence that is a URL somebody has to go and find is not in '
            'the tree',
      );
    });
  });

  group('finding it', () {
    test('an override that points nowhere is an error, not a fallback', () {
      expect(
        () => pdfiumPath(
          environment: const {kPdfiumPathVariable: 'C:/nowhere/pdfium.dll'},
          exists: (_) => false,
        ),
        throwsA(isA<PdfiumUnavailable>()),
      );
    });

    test('an override that points somewhere wins outright', () {
      expect(
        pdfiumPath(
          environment: const {kPdfiumPathVariable: 'C:/elsewhere/pdfium.dll'},
          exists: (path) => path == 'C:/elsewhere/pdfium.dll',
        ),
        'C:/elsewhere/pdfium.dll',
      );
    });

    test('with nothing anywhere, the message names the command', () {
      try {
        pdfiumPath(environment: const {}, exists: (_) => false);
        fail('a missing binary must not resolve to a path');
      } on PdfiumUnavailable catch (error) {
        expect(error.message, contains('vendor_pdfium.ps1'));
        expect(
          error.message,
          contains('CR-100'),
          reason: 'the reason it is not downloaded belongs in the message',
        );
      }
    });

    test('the repository copy is found by walking up from anywhere', () {
      // The real filesystem, so this also proves the walk terminates.
      expect(
        pdfiumPath(environment: const {}),
        endsWith('pdfium.dll'),
      );
    });
  });
}
