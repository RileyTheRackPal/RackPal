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
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:rackpal_pdfium/rackpal_pdfium.dart';
import 'package:test/test.dart';

/// The repository root, from the package directory tests run in.
const String kRepoRoot = '../..';

File get _pinFile => File('$kRepoRoot/third_party/pdfium/pdfium.pin.json');

/// The pin, read once. One release, one entry per platform's artifact.
final Map<String, dynamic> _pin =
    jsonDecode(_pinFile.readAsStringSync()) as Map<String, dynamic>;

Map<String, dynamic> get _platforms =>
    _pin['platforms'] as Map<String, dynamic>;

void main() {
  // THREE CASES PER PINNED PLATFORM, generated from the pin, so an artifact
  // added to the pin is checked by the same assertions on the day it
  // lands rather than when somebody remembers to write them. The tree is
  // the same on every OS, so every platform's binary is checked on every
  // OS, including the ones that cannot load it.
  group('the vendored binary', () {
    for (final MapEntry(key: platform, value: raw) in _platforms.entries) {
      final entry = raw as Map<String, dynamic>;
      final relative = 'third_party/pdfium/${entry['binary']}';
      final file = File('$kRepoRoot/$relative');

      test('$platform: is where the loader looks for it', () {
        expect(
          kVendoredPdfiumPaths.values,
          contains(relative),
          reason: 'the pin and pdfium_library.dart name different files',
        );
        expect(
          file.existsSync(),
          isTrue,
          reason:
              'pdfium is not vendored yet. It is placed by a person on '
              'purpose (CR-100): $kVendorCommand',
        );
      });

      test('$platform: matches the checksum it was pinned at', () {
        final expected = (entry['binarySha256'] as String).toLowerCase();
        final actual = sha256.convert(file.readAsBytesSync()).toString();

        expect(
          actual,
          expected,
          reason:
              'the binary in the tree is not the one recorded in '
              'pdfium.pin.json. Nobody reviews megabytes of opaque bytes '
              'in a diff, so this is the only thing that would notice.',
        );
      });

      test('$platform: its licences travel with it', () {
        // Beside the binary they cover, because two builds of one release
        // can compile in different third-party code. The LICENSE is the
        // packager's; licenses/ is pdfium's own and every library inside
        // it, which BSD-style terms require a binary distribution to carry.
        final dir = file.parent;
        final notices = Directory('${dir.path}/licenses');
        expect(
          File('${dir.path}/LICENSE').existsSync(),
          isTrue,
          reason: 'CR-100 says a vendored pdfium reopens DR-036 census',
        );
        expect(
          notices.existsSync() &&
              notices.listSync(recursive: true).whereType<File>().isNotEmpty,
          isTrue,
          reason:
              "the packager's LICENSE points at licenses/, and a pointer to "
              'notices that are not in the tree is not a licence',
        );
      });
    }

    test('every OS the loader looks for has a pinned binary', () {
      // The other direction of the per-platform pair: a path the loader
      // names with no pin entry is a binary nobody checks.
      final pinned = {
        for (final raw in _platforms.values)
          'third_party/pdfium/${(raw as Map<String, dynamic>)['binary']}',
      };
      expect(pinned, containsAll(kVendoredPdfiumPaths.values));
    });

    test('the macOS dylib carries an x86_64 and an arm64 slice', () {
      // THE ONLY CHECK ON THE ARM64 HALF THAT ANY CI HERE CAN MAKE. The
      // hosted macOS image is Intel (DR-255), so it loads the x86_64 slice
      // and never executes the other; an Apple Silicon Mac loads arm64.
      // A universal Mach-O starts with a big-endian fat header: magic
      // 0xCAFEBABE, a slice count, then 20 bytes per slice opening with
      // its CPU type. It reads the same on every OS, so Windows checks
      // the slice that macOS CI cannot run.
      final bytes = File(
        '$kRepoRoot/${kVendoredPdfiumPaths['macos']}',
      ).readAsBytesSync();
      final header = ByteData.sublistView(bytes);
      expect(header.getUint32(0), 0xCAFEBABE, reason: 'not a universal file');
      final count = header.getUint32(4);
      const names = {0x01000007: 'x86_64', 0x0100000C: 'arm64'};
      final slices = {
        for (var i = 0; i < count; i++)
          names[header.getUint32(8 + 20 * i)] ?? 'unknown',
      };
      expect(slices, {'x86_64', 'arm64'});
    });

    test('the pin names the release it came from', () {
      // A checksum with no provenance is a number. The tag is what makes
      // the binary re-obtainable by somebody who does not trust ours.
      expect(_pin['release'], isA<String>());
      expect((_pin['release']! as String).trim(), isNotEmpty);
      for (final raw in _platforms.values) {
        final entry = raw as Map<String, dynamic>;
        expect(entry['url'], contains('pdfium-binaries'));
        // One release for every platform, so each URL names the same tag.
        expect(
          entry['url'],
          contains((_pin['release']! as String).replaceAll('/', '%2F')),
        );
        expect(entry['archiveSha256'], isA<String>());
      }
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

    // One per OS, on the real filesystem, so this also proves the walk
    // terminates. Both files are in the tree on every OS, so the Windows
    // run walks to the dylib and the macOS run to the DLL as well.
    for (final MapEntry(key: os, value: relative)
        in kVendoredPdfiumPaths.entries) {
      test('$os: the repository copy is found by walking up', () {
        expect(
          pdfiumPath(
            environment: const {},
            operatingSystem: os,
          ).replaceAll(r'\', '/'),
          endsWith(relative),
        );
      });
    }

    test("on macOS the shipped copy is the bundle's, in Frameworks", () {
      // The executable is RackPal.app/Contents/MacOS/<name>, so the copy a
      // shipped app loads is one level up. Only the bundle's copy exists
      // here, so a loader that looked beside the executable, as Windows
      // does, finds nothing and fails the case.
      final found = pdfiumPath(
        environment: const {},
        operatingSystem: 'macos',
        exists: (path) => path
            .replaceAll(r'\', '/')
            .endsWith('/../Frameworks/libpdfium.dylib'),
      );
      expect(
        found.replaceAll(r'\', '/'),
        endsWith('Frameworks/libpdfium.dylib'),
      );
    });

    test('an OS with no vendored binary is told so by name', () {
      expect(
        () => pdfiumPath(
          environment: const {},
          operatingSystem: 'linux',
          exists: (_) => true,
        ),
        throwsA(
          isA<PdfiumUnavailable>().having(
            (e) => e.message,
            'message',
            allOf(contains('linux'), contains('windows and macos')),
          ),
        ),
      );
    });
  });
}
