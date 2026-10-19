// WHAT ACTUALLY SHIPS IN THE WINDOWS BUILD.
//
// The dependency graph decides the contents of the portable ZIP, and
// nothing in this repository used to look at it: a repo-wide grep for
// `generated_plugins`, `dartjni` or `FLUTTER_FFI` across every `.dart`
// file returned nothing at all.
//
// So `dartjni.dll` — an ANDROID JNI BRIDGE — sat in
// `build/windows/x64/runner/Release/` beside `rackpal.exe`, pulled in by
// `file_selector_android` and `path_provider_android`, which came along
// for the ride with the two umbrella packages. This app had no `android/`,
// `ios/`, `macos/` or `linux/` directory (macOS arrived later, at D1 under
// DR-256, and Android never has). That DLL could never be loaded,
// it added weight to a ZIP meant to be copied onto a USB stick, and it was
// one more unsigned native binary for an enterprise allowlist to refuse.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('no Android implementation package is in the Windows dependency '
      'graph', () {
    final lock = File('../../pubspec.lock').readAsStringSync();
    final android = RegExp(
      r'^  (\w*_android):',
      multiLine: true,
    ).allMatches(lock).map((m) => m[1]).toList();

    expect(
      android,
      isEmpty,
      reason:
          'a Windows-only app resolved $android. Depend on the platform '
          'implementation directly (path_provider_windows) rather than on '
          'the umbrella package, which endorses every platform at once.',
    );
  });

  test('the JNI packages are gone, and so is the FFI plugin they '
      'register', () {
    final lock = File('../../pubspec.lock').readAsStringSync();
    for (final package in ['jni', 'jni_flutter', 'jni_util']) {
      expect(
        RegExp('^  $package:', multiLine: true).hasMatch(lock),
        isFalse,
        reason:
            '$package is back. It arrives transitively through an Android '
            'implementation package and puts dartjni.dll in the Windows '
            'Release output.',
      );
    }
  });

  test('generated_plugins.cmake registers no FFI plugin at all', () {
    // GENERATED, AND THAT IS THE POINT: it is rewritten from the
    // dependency graph on every build, so editing it fixes nothing and
    // reading it is the honest way to see what the graph produced. If this
    // fails, the fix is in the pubspec, never in the .cmake.
    final generated = File(
      'windows/flutter/generated_plugins.cmake',
    ).readAsStringSync();
    final ffi = RegExp(
      r'list\(APPEND FLUTTER_FFI_PLUGIN_LIST([\s\S]*?)\)',
    ).firstMatch(generated);
    expect(ffi, isNotNull, reason: 'the generated file changed shape');
    expect(
      ffi![1]!.trim(),
      isEmpty,
      reason:
          'FLUTTER_FFI_PLUGIN_LIST holds "${ffi[1]!.trim()}". Every entry '
          'here becomes a native library copied beside rackpal.exe.',
    );
  });

  test('the plugins that DO ship are the two the app actually uses', () {
    // A positive assertion, so this file cannot pass by the graph
    // collapsing to nothing. `window_manager` carries `setPreventClose`,
    // without which the three-button close prompt cannot exist;
    // `screen_retriever_windows` is its own dependency and supplies the
    // display list `validateRestoredBounds` needs.
    //
    // `file_selector_windows` is DELIBERATELY not on this list: RackPal
    // drives IFileDialog from its own runner so it can set
    // FOS_DONTADDTORECENT.
    final generated = File(
      'windows/flutter/generated_plugins.cmake',
    ).readAsStringSync();
    final plugins = RegExp(
      r'list\(APPEND FLUTTER_PLUGIN_LIST([\s\S]*?)\)',
    ).firstMatch(generated);
    expect(plugins, isNotNull);
    expect(
      plugins![1]!.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty),
      unorderedEquals(<String>['screen_retriever_windows', 'window_manager']),
    );
  });
}
