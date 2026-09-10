// THE VENDORED BINARY REACHES THE PACKAGED APP (DR-153 §11.152.3).
//
// ═══════════════════════════════════════════════════════════════════════
// WHY THIS CANNOT BE LEFT TO SOMEBODY NOTICING
// ═══════════════════════════════════════════════════════════════════════
// `rackpal_pdfium` finds its library in three places, in order: an
// environment override, BESIDE THE EXECUTABLE, and the repository copy at
// `third_party/pdfium/win-x64/`.
//
// **The third arm hides the absence of the second.** A developer running
// `flutter run` from inside the working tree walks up and finds the
// committed DLL, so every local build works with no install rule at all,
// and the first failure would be on somebody else's machine holding a
// packaged copy that cannot open a PDF. That is the worst shape a defect
// can have in this product: it appears only where nobody is looking.
//
// pdfium is not a Flutter plugin and not a native asset, so neither
// `PLUGIN_BUNDLED_LIBRARIES` nor the native-assets directory carries it.
// The rule is one `install(FILES ...)` in `windows/CMakeLists.txt` and
// this file is the reason the next person cannot delete it quietly.
//
// ═══════════════════════════════════════════════════════════════════════
// A SOURCE GATE, AND ITS LIMIT IS STATED
// ═══════════════════════════════════════════════════════════════════════
// The same family as `gitattributes_byte_exactness_test.dart`, and the
// same honesty about scope: it reads the CMake file and the working tree,
// so it proves the RULE IS PRESENT AND POINTS AT A REAL FILE. It does not
// prove CMake obeyed it. The build gate does that, by building.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The repository root, from the package directory tests run in.
const String kRepoRoot = '../..';

/// Where the loader looks, and where the install rule must point.
const String kVendoredPath = 'third_party/pdfium/win-x64/pdfium.dll';

void main() {
  group('pdfium is installed beside the executable', () {
    late String cmake;

    setUpAll(() {
      cmake = File('windows/CMakeLists.txt').readAsStringSync();
    });

    test('the Windows build names the vendored DLL', () {
      expect(
        cmake,
        contains(kVendoredPath),
        reason:
            'nothing else in this file carries pdfium: it is not a plugin '
            'and not a native asset',
      );
    });

    test('and installs it into the bundle, not merely mentions it', () {
      // A `set()` with no `install()` is a variable nobody reads, which is
      // exactly what a half-finished edit leaves behind.
      expect(
        cmake,
        contains(r'install(FILES "${PDFIUM_DLL}"'),
        reason: 'the file has to be COPIED, not just located',
      );
      expect(cmake, contains(r'DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"'));
    });

    test(
      'a missing binary fails the build rather than shipping without it',
      () {
        // An installable app that cannot open a PDF is the quieter failure,
        // and the message names the command that fixes it.
        expect(cmake, contains('FATAL_ERROR'));
        expect(cmake, contains('vendor_pdfium.ps1'));
      },
    );

    test('the path it names is where the binary actually is', () {
      // The rule and the tree agreeing is the whole point: a path that is
      // subtly wrong installs nothing and fails at FATAL_ERROR instead,
      // which is loud but is a different failure from the one under test.
      expect(
        File('$kRepoRoot/$kVendoredPath').existsSync(),
        isTrue,
        reason:
            'pdfium is not vendored. It is committed rather than downloaded '
            '(CR-100) and placed by a person: '
            'pwsh -File tools/vendor_pdfium.ps1 -Release <tag> -Bootstrap',
      );
    });
  });
}
